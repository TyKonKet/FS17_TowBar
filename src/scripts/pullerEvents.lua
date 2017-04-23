--
-- Puller Events
--
-- @author TyKonKet
-- @date 13/04/2017
PullerAttachEvent = {};
PullerAttachEvent_mt = Class(PullerAttachEvent, Event);

InitEventClass(PullerAttachEvent, "PullerAttachEvent");

function PullerAttachEvent:emptyNew()
    local self = Event:new(PullerAttachEvent_mt);
    return self;
end

function PullerAttachEvent:new(vehicle, object, jointId)
    local self = PullerAttachEvent:emptyNew()
    self.vehicle = vehicle;
    self.object = object;
    self.jointId = jointId;
    return self;
end

function PullerAttachEvent:readStream(streamId, connection)
    self.vehicle = readNetworkNodeObject(streamId);
    self.object = readNetworkNodeObject(streamId);
    self.jointId = streamReadInt32(streamId);
    self:run(connection);
end

function PullerAttachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle);
    writeNetworkNodeObject(streamId, self.object);
    streamWriteInt32(streamId, self.jointId);
end

function PullerAttachEvent:run(connection)
    Puller.onAttachObject(self.vehicle, self.object, self.jointId, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(PullerAttachEvent:new(self.vehicle, self.object, self.jointId), nil, connection, self.vehicle);
    end
end

function PullerAttachEvent.sendEvent(vehicle, object, jointId, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PullerAttachEvent:new(vehicle, object, jointId), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(PullerAttachEvent:new(vehicle, object, jointId));
        end
    end

end

PullerDetachEvent = {};
PullerDetachEvent_mt = Class(PullerDetachEvent, Event);

InitEventClass(PullerDetachEvent, "PullerDetachEvent");

function PullerDetachEvent:emptyNew()
    local self = Event:new(PullerDetachEvent_mt);
    return self;
end

function PullerDetachEvent:new(vehicle)
    local self = PullerDetachEvent:emptyNew()
    self.vehicle = vehicle;
    return self;
end

function PullerDetachEvent:readStream(streamId, connection)
    self.vehicle = readNetworkNodeObject(streamId);
    self:run(connection);
end

function PullerDetachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle);
end

function PullerDetachEvent:run(connection)
    Puller.onDetachObject(self.vehicle, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(PullerDetachEvent:new(self.vehicle), nil, connection, self.vehicle);
    end
end

function PullerDetachEvent.sendEvent(vehicle, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PullerDetachEvent:new(vehicle), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(PullerDetachEvent:new(vehicle));
        end
    end

end
