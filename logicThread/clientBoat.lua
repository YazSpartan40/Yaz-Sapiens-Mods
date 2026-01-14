local mjm = mjrequire "common/mjm"
local mat3Identity = mjm.mat3Identity
local vec3 = mjm.vec3
--local normalize = mjm.normalize
local mat3Rotate = mjm.mat3Rotate
local mat3GetRow = mjm.mat3GetRow
local rng = mjrequire "common/randomNumberGenerator"

--local gameObject = mjrequire "common/gameObject"
--local resource = mjrequire "common/resource"
--local modelPlaceholder = mjrequire "common/modelPlaceholder"

--local logic = mjrequire "logicThread/logic"
--local logicAudio = mjrequire "logicThread/logicAudio"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
--local clientConstruction = mjrequire "logicThread/clientConstruction"
--local resource = mjrequire "common/resource"

local clientBoat = {}

local clientGOM = nil

local function updateWaterEmitters(object, clientState)
    local isCausingRipples = clientState.waterRotating
    if isCausingRipples then
        local swimPos = object.pos + mat3GetRow(object.rotation, 0) * (rng:randomValue() - 0.5) * mj:mToP(2.0)
        --[[if clientState.swimming and clientState.directionNormal and actionState and actionState.sequenceTypeIndex then
            local actionSequenceActions = actionSequence.types[actionState.sequenceTypeIndex].actions
            local actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]

            if action.types[actionTypeIndex].isMovementAction then
                swimPos = swimPos + clientState.directionNormal * mj:mToP(0.75)
            end
        end]]

        if not clientState.swimmingEmitterID then
            local emitterType = particleManagerInterface.emitterTypes.waterRipples
            clientState.swimmingEmitterID = particleManagerInterface:addEmitter(emitterType, swimPos, object.baseRotation or object.rotation, nil, false)
        else
            particleManagerInterface:updateEmitter(clientState.swimmingEmitterID, swimPos, object.baseRotation or object.rotation, nil, false)
        end
    else
        if clientState.swimmingEmitterID then
            particleManagerInterface:removeEmitter(clientState.swimmingEmitterID)
            clientState.swimmingEmitterID = nil
        end
    end 
end

function clientBoat:visibleObjectUpdate(object, dt, speedMultiplier)
    local clientState = clientGOM:getClientState(object)
    if object.sharedState.waterRideable then
        clientState.waterRotating = true

        clientState.rotationOffsetX = (clientState.rotationOffsetX or rng:randomValue()) + dt * speedMultiplier * 1.9373
        clientState.rotationOffsetZ = (clientState.rotationOffsetZ or rng:randomValue()) + dt * speedMultiplier
        local xRotation = math.sin(clientState.rotationOffsetX) * 0.1
        local zRotation = math.sin(clientState.rotationOffsetZ) * 0.02

        local rotation = mat3Rotate(mat3Identity, xRotation, vec3(1.0,0.0,0.0))
        rotation = mat3Rotate(rotation, zRotation, vec3(0.0,0.0,1.0))

        local offset = mat3GetRow(rotation, 1) * math.sin(clientState.rotationOffsetZ * 1.1) * mj:mToP(0.1)

        clientGOM:setAnimationTransform(object.uniqueID, offset, rotation)
        updateWaterEmitters(object, clientState)
    else
        if clientState.waterRotating then
            clientState.waterRotating = false
            clientGOM:setAnimationTransform(object.uniqueID, nil, nil)
            updateWaterEmitters(object, clientState)
        end
    end
end



clientBoat.objectWasLoaded = function(object, pos, rotation, scale)
    clientGOM:addObjectToSet(object, clientGOM.objectSets.boats)
end

--[[clientBoat.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    clientGOM:setCovered(object.uniqueID, object.sharedState.covered)
end]]

--[[clientBoat.objectWasLoaded = function(object, pos, rotation, scale)
    clientGOM:setCovered(object.uniqueID, object.sharedState.covered)
end]]

--[[clientBoat.objectSnapMatrix = function(object, pos, rotation)
end]]

--[[clientBoat.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientBoat:updateSubModels(object)
    end
end]]

function clientBoat:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientBoat