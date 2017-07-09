--
-- Configurable
--
-- @author TyKonKet
-- @date 09/07/2017
Configurable = {};
function Configurable.prerequisitesPresent(specializations)
    return true;
end

function Configurable:load(savegame)
end

function Configurable:delete()
end

function Configurable:mouseEvent(posX, posY, isDown, isUp, button)
end

function Configurable:keyEvent(unicode, sym, modifier, isDown)
end

function Configurable:readStream(streamId, connection)
end

function Configurable:writeStream(streamId, connection)
end

function Configurable:update(dt)
end

function Configurable:updateTick(dt)
end

function Configurable:draw()
end

ConfigurationUtil.registerConfigurationType("length", g_i18n:getText("configuration_length"), nil, nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION);