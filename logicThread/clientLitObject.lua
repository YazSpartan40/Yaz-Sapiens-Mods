local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
--local normalize = mjm.normalize
local length = mjm.length

--local gameObject = mjrequire "common/gameObject"
--local resource = mjrequire "common/resource"
--local modelPlaceholder = mjrequire "common/modelPlaceholder"

local logic = mjrequire "logicThread/logic"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"

local clientLitObject = {}

local clientGOM = nil


clientLitObject.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    clientLitObject:updateFireEffects(object)
end

clientLitObject.objectWasLoaded = function(object, pos, rotation, scale)
    clientLitObject:updateFireEffects(object)
end

clientLitObject.objectSnapMatrix = function(object, pos, rotation)
    local clientState = clientGOM:getClientState(object)
    if clientState.emitterID then
        particleManagerInterface:removeEmitter(clientState.emitterID)
        clientState.emitterID = nil
    end
    if clientState.lightAdded then
        logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
        clientState.lightAdded = false
    end
    clientLitObject:updateFireEffects(object)
end

function clientLitObject:updateFireEffects(object)
    local clientState = clientGOM:getClientState(object)
    if object.sharedState.isLit then
        local emitterType = particleManagerInterface.emitterTypes.torchLarge
        
        local fuelState = object.sharedState.fuelState
        local fuelCount = 0
        if fuelState then
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel > 0.0 then
                    fuelCount = fuelCount + 1
                end
            end
            if fuelCount <= 1 then
                emitterType = particleManagerInterface.emitterTypes.torchSmall
            end
        end

        if (not clientState.emitterID) or (clientState.emitterType ~= emitterType)then
            if clientState.emitterID then
                particleManagerInterface:removeEmitter(clientState.emitterID)
            end
            local emitterID = particleManagerInterface:addEmitter(emitterType, object.pos, object.rotation, nil, object.sharedState.covered)
            clientState.emitterID = emitterID
            clientState.emitterType = emitterType
            --mj:log("add emitter:", clientState.emitterID)
        end

        if (not clientState.lightAdded) or (clientState.lightFuelCount ~= fuelCount) then
            if clientState.lightAdded then
                logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
            end
            local lengthObjectPos = length(object.pos)
            logic:callMainThreadFunction("addLightForObject", {
                uniqueID = object.uniqueID, 
                pos = object.pos / lengthObjectPos * (lengthObjectPos + mj:mToP(0.3)), 
                color = vec3(4.0,1.0,0.1) * 0.03
            })
            clientState.lightAdded = true
            clientState.lightFuelCount = fuelCount
        end
    else
        if clientState.emitterID then
            particleManagerInterface:removeEmitter(clientState.emitterID)
            clientState.emitterID = nil
        end
        if clientState.lightAdded then
            logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
            clientState.lightAdded = false
        end
    end
end



function clientLitObject:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientLitObject