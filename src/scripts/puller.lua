--
-- Puller
--
-- @author TyKonKet
-- @date 13/04/2017
Puller = {};
source(g_currentModDirectory .. "scripts/pullerEvents.lua");

function Puller.prerequisitesPresent(specializations)
    return true;
end

function Puller:preLoad(savegame)
    self.getAttachmentsSaveNodes = Utils.overwrittenFunction(self.getAttachmentsSaveNodes, Puller.getAttachmentsSaveNodes);
    self.loadAttachmentFromNodes = Utils.overwrittenFunction(self.loadAttachmentFromNodes, Puller.loadAttachmentFromNodes);
    self.canBeGrabbed = Puller.canBeGrabbed;
end

function Puller:load(savegame)
    self.isGrabbable = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.grabbable#isGrabbable"), false);
    self.isGrabbableOnlyIfDetach = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.grabbable#isGrabbableOnlyIfDetach"), false);
    self.attachPoint = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.puller#index"));
    self.attachPointCollision = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.puller#rootNode"));
    self.attachRadius = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.puller#attachRadius"), 1);
    self.isAttached = false;
    self.joint = {};
    self.inRangeVehicle = nil;
end

function Puller:getAttachmentsSaveNodes(superFunc, nodeIdent, vehiclesToId)
    local nodes = "";
    if superFunc ~= nil then
        nodes = superFunc(self, nodeIdent, vehiclesToId);
    end
    local id = vehiclesToId[self];
    if id ~= nil and self.joint ~= nil then
        local object = self.joint.object;
        if object ~= nil and vehiclesToId[object] ~= nil and self.joint.attacherJointId ~= nil then
            nodes = nodes .. nodeIdent .. '<attachment id0="' .. id .. '" id1="' .. vehiclesToId[object] .. '" jointId="' .. self.joint.attacherJointId .. '" type="towbar" />\n';            
        end
    end
    return nodes;
end

function Puller:loadAttachmentFromNodes(superFunc, xmlFile, key, idsToVehicle)
    if superFunc ~= nil then
        superFunc(self, xmlFile, key, idsToVehicle);
    end
    local type = getXMLString(xmlFile, key .. "#type");
    if type == "towbar" then
        local id1 = getXMLString(xmlFile, key .. "#id1");
        local jointId = getXMLInt(xmlFile, key .. "#jointId");
        if id1 ~= nil and jointId ~= nil then
            local vehicle1 = idsToVehicle[id1];
            if vehicle1 ~= nil then
                Puller.onAttachObject(self, vehicle1, jointId, true);
            end
        end
    end
end

function Puller:delete()
end

function Puller:mouseEvent(posX, posY, isDown, isUp, button)
end

function Puller:keyEvent(unicode, sym, modifier, isDown)
end

function Puller:readStream(streamId, connection)
    if streamReadBool(streamId) then
        local jointId = streamReadInt32(streamId);
        local object = readNetworkNodeObject(streamId);
        Puller.onAttachObject(self, object, jointId, true);
    end
end

function Puller:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isAttached);
    if self.isAttached then
        streamWriteInt32(streamId, self.joint.attacherJointId);
        writeNetworkNodeObject(streamId, self.joint.object);
    end
end

function Puller:update(dt)
    if self:getIsActiveForInput() then
        if self.inRangeVehicle ~= nil then
            if not self.isAttached then
                if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA2) then
                    Puller.onAttachObject(self, self.inRangeVehicle.vehicle, self.inRangeVehicle.index);
                    SoundUtil.playSample(self.sampleAttach, 1, 0, nil);
                end
            end
        else
            if self.isAttached then
                if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA2) then
                    Puller.onDetachObject(self);
                    SoundUtil.playSample(self.sampleAttach, 1, 0, nil);
                end
            end
        end
    end
end

function Puller:updateTick(dt)
    if self:getIsActiveForInput() and not self.isAttached then
        self.inRangeVehicle = nil;
        local x, y, z = getWorldTranslation(self.attachPoint);
        for k, v in pairs(g_currentMission.vehicles) do
            local vx, vy, vz = getWorldTranslation(v.rootNode);
            if Utils.vector3Length(x - vx, y - vy, z - vz) <= 50 then
                for index, joint in pairs(v.attacherJoints) do
                    if joint.jointType == AttacherJoints.JOINTTYPE_TRAILER or joint.jointType == AttacherJoints.JOINTTYPE_TRAILERLOW then
                        local x1, y1, z1 = getWorldTranslation(joint.jointTransform);
                        local distance = Utils.vector3Length(x - x1, y - y1, z - z1);
                        if distance <= self.attachRadius then
                            self.inRangeVehicle = {};
                            self.inRangeVehicle.vehicle = v;
                            self.inRangeVehicle.index = index;
                            break;
                        end
                    end
                end
                if v.attacherJoint ~= nil and self.inRangeVehicle == nil then
                    if v.attacherJoint.jointType == AttacherJoints.JOINTTYPE_TRAILER or v.attacherJoint.jointType == AttacherJoints.JOINTTYPE_TRAILERLOW then
                        local x1, y1, z1 = getWorldTranslation(v.attacherJoint.node);
                        local distance = Utils.vector3Length(x - x1, y - y1, z - z1);
                        if distance <= self.attachRadius then
                            self.inRangeVehicle = {};
                            self.inRangeVehicle.vehicle = v;
                            self.inRangeVehicle.index = 0;
                            break;
                        end
                    end
                end
            end
        end
    end
end

function Puller:onAttachObject(object, jointId, noEventSend)
    PullerAttachEvent.sendEvent(self, object, jointId, noEventSend);
    self.joint.object = object;
    if object.isBroken == true then
        object.isBroken = false;
    end
    if self.isServer then
        local objectAttacherJoint = nil;
        if jointId == 0 then
            objectAttacherJoint = object.attacherJoint;
        else
            objectAttacherJoint = object.attacherJoints[jointId];
        end
        local constr = JointConstructor:new();
        constr:setActors(self.attachPointCollision, objectAttacherJoint.rootNode);
        constr:setJointTransforms(self.attachPoint, Utils.getNoNil(objectAttacherJoint.jointTransform, objectAttacherJoint.node));
        for i = 1, 3 do
            constr:setTranslationLimit(i - 1, true, 0, 0);
            constr:setRotationLimit(i - 1, -0.35, 0.35);
            constr:setEnableCollision(false);
        end
        self.joint.index = constr:finalize();
        if not object.isControlled and object.motor ~= nil and object.wheels ~= nil then
            for k, wheel in pairs(object.wheels) do
                setWheelShapeProps(wheel.node, wheel.wheelShape, 0, 0, 0, wheel.rotationDamping);
            end
        end
        self.joint.attacherJointId = jointId;
    end
    object.forceIsActive = true;
    self.isAttached = true;
    self.inRangeVehicle = nil;
end

function Puller:onDetachObject(noEventSend)
    PullerDetachEvent.sendEvent(self, noEventSend);
    if self.isServer then
        removeJoint(self.joint.index);
        if not self.joint.object.isControlled and self.joint.object.motor ~= nil and self.joint.object.wheels ~= nil then
            for k, wheel in pairs(self.joint.object.wheels) do
                setWheelShapeProps(wheel.node, wheel.wheelShape, 0, self.joint.object.motor.brakeForce, 0, wheel.rotationDamping);
            end
        end
    end
    self.joint.object.forceIsActive = false;
    self.joint = nil;
    self.joint = {};
    self.isAttached = false;
end

function Puller:draw()
    if self.inRangeVehicle ~= nil then
        g_currentMission:addHelpButtonText(g_i18n:getText("PULLER_ATTACH"), InputBinding.IMPLEMENT_EXTRA2);
        g_currentMission:enableHudIcon("attach", 10);
    elseif self.inRangeVehicle == nil and self.isAttached then
        g_currentMission:addHelpButtonText(g_i18n:getText("PULLER_DETACH"), InputBinding.IMPLEMENT_EXTRA2);
    end
end

function Puller:canBeGrabbed()
    if self.isGrabbable then
        if self.isGrabbableOnlyIfDetach then
            if not self.isAttached and self.attacherVehicle == nil then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

function Player:pickUpObjectRaycastCallback(hitObjectId, x, y, z, distance)
    if distance > 0.5 and distance <= Player.MAX_PICKABLE_OBJECT_DISTANCE then
        if hitObjectId ~= g_currentMission.terrainDetailId and Player.PICKED_UP_OBJECTS[hitObjectId] ~= true then
            if getRigidBodyType(hitObjectId) == "Dynamic" then
                local object = g_currentMission:getNodeObject(hitObjectId);
                if (object ~= nil and object.dynamicMountObject == nil) or g_currentMission.nodeToVehicle[hitObjectId] == nil or (g_currentMission.nodeToVehicle[hitObjectId].canBeGrabbed ~= nil and g_currentMission.nodeToVehicle[hitObjectId]:canBeGrabbed()) then
                    self.lastFoundObject = hitObjectId;
                    self.lastFoundObjectMass = getMass(hitObjectId);
                    self.lastFoundObjectHitPoint = {x, y, z};
                    return false;
                end
            end
        end
    end
    return true;
end
