
--local gameObject = mjrequire "common/gameObject"
local logic = mjrequire "logicThread/logic"
local animationGroups = mjrequire "common/animationGroups"

local clientObjectAnimation = {}

local clientGOM = nil


function clientObjectAnimation:changeAnimation(object, newAnimationTypeIndex, animationGroupIndex, speedMultiplier)
    local clientState = clientGOM.clientStates[object.uniqueID]
    clientState.animationSent = true
    if clientState.animationTypeIndex ~= newAnimationTypeIndex or clientState.animationGroupIndex ~= animationGroupIndex or clientState.currentAnimationSpeedMultiplier ~= speedMultiplier  then
        if mj.debugObject == object.uniqueID then
            
            local animationGroup = animationGroups.groups[animationGroupIndex]
            local animations = animationGroup.animations
    
            mj:debug("newAnimation:", animations[newAnimationTypeIndex].key, " speedMultiplier:", speedMultiplier)
        end
        
        --disabled--mj:objectLog(object.uniqueID, "clientObjectAnimation:changeAnimation group:", animationGroupIndex, " newAnimationTypeIndex:", newAnimationTypeIndex)
        clientState.animationGroupIndex = animationGroupIndex
        clientState.animationTypeIndex = newAnimationTypeIndex
        clientState.currentAnimationSpeedMultiplier = speedMultiplier

        logic:setAnimationIndexForObject(object.uniqueID, animationGroupIndex, newAnimationTypeIndex, speedMultiplier)
    end
end

function clientObjectAnimation:changeAnimationSpeed(object, speedMultiplier)
    local clientState = clientGOM.clientStates[object.uniqueID]
    if clientState.animationSent and clientState.currentAnimationSpeedMultiplier ~= speedMultiplier then
        clientState.currentAnimationSpeedMultiplier = speedMultiplier
        logic:setAnimationIndexForObject(object.uniqueID, clientState.animationGroupIndex, clientState.animationTypeIndex, speedMultiplier)
    end
end

function clientObjectAnimation:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientObjectAnimation