local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
--local normalize = mjm.normalize
local length = mjm.length
local mat3GetRow = mjm.mat3GetRow

local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local model = mjrequire "common/model"
local modelPlaceholder = mjrequire "common/modelPlaceholder"

local logic = mjrequire "logicThread/logic"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"

local clientTorch = {}

local clientGOM = nil


clientTorch.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    clientTorch:updateFireEffects(object)
    clientTorch:updateSubModels(object)
    clientGOM:setCovered(object.uniqueID, object.sharedState.covered)
end

clientTorch.objectWasLoaded = function(object, pos, rotation, scale)
    clientTorch:updateFireEffects(object)
    clientTorch:updateSubModels(object)
    clientGOM:setCovered(object.uniqueID, object.sharedState.covered)
end

clientTorch.objectSnapMatrix = function(object, pos, rotation)
    local clientState = clientGOM:getClientState(object)
    if clientState.emitterID then
        particleManagerInterface:removeEmitter(clientState.emitterID)
        clientState.emitterID = nil
    end
    if clientState.lightAdded then
        logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
        clientState.lightAdded = false
    end
    clientTorch:updateFireEffects(object)
    clientTorch:updateSubModels(object)
end

clientTorch.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientTorch:updateSubModels(object)
    end
end

function clientTorch:updateFireEffects(object)
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
            local emitterID = particleManagerInterface:addEmitter(emitterType, object.pos + mat3GetRow(object.rotation, 1) * mj:mToP(1.4), object.rotation, nil, object.sharedState.covered)
            clientState.emitterID = emitterID
            clientState.emitterType = emitterType
            --mj:log("add emitter:", clientState.emitterID)
        end

        if (not clientState.lightAdded) or (clientState.lightFuelCount ~= fuelCount) then
            if clientState.lightAdded then
                logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
            end
            logic:callMainThreadFunction("addLightForObject", {
                uniqueID = object.uniqueID, 
                pos = object.normalizedPos * (length(object.pos) + mj:mToP(1.8)), 
                color = vec3(4.0,1.0,0.1) * 0.1
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


function clientTorch:updateSubModels(object)
    --mj:log("clientCampfire:updateSubModels:", object.uniqueID)
    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(object.modelIndex)
    local sharedState = object.sharedState
    local constructionObjects = sharedState.constructionObjects
    
    local fuelState = sharedState.fuelState
    local fuelIndex = 1

    local foundResourceCounts = {}
    local placeholderContext = {
        buildComplete = true,
        hasFuel = true,
        subdivLevel = object.subdivLevel,
    }

    for i,key in pairs(placeholderKeys) do
        local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key)
        --mj:log("key:", key)
       -- mj:log("placeholderInfo:", placeholderInfo)

        --local modelIndex = placeholderInfo.defaultModelIndex
        if placeholderInfo.defaultModelIndex then
            
            local modelIndex = model:modelIndexForDetailedModelIndexAndDetailLevel(placeholderInfo.defaultModelIndex, model:modelLevelForSubdivLevel(object.subdivLevel))
            local foundObjectInfo = nil
            if placeholderInfo.resourceTypeIndex then
                local resourceTypeIndex = placeholderInfo.resourceTypeIndex
                local resourceCounter = 0

                if constructionObjects then
                    for j,objectInfo in ipairs(constructionObjects) do
                        if gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex == resourceTypeIndex then
                            resourceCounter = resourceCounter + 1
                            if not foundResourceCounts[resourceTypeIndex] or resourceCounter > foundResourceCounts[resourceTypeIndex] then
                                foundResourceCounts[resourceTypeIndex] = resourceCounter
                                modelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, objectInfo.objectTypeIndex, placeholderContext)
                                foundObjectInfo = objectInfo
                                break
                            end
                        end
                    end
                end

                if not foundObjectInfo then
                    local objectTypeIndex = resource.types[resourceTypeIndex].displayGameObjectTypeIndex
                    foundObjectInfo = {
                        objectTypeIndex = objectTypeIndex,
                    }
                    modelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, objectTypeIndex, placeholderContext)
                end
            else
                if fuelState then
                    local fuelInfo = fuelState[fuelIndex]
                    if fuelInfo then
                        mj:log("fuelInfo", fuelInfo)
                        if fuelInfo.objectTypeIndex then
                            local objectTypeIndex = fuelInfo.objectTypeIndex
                            local hasFuel = (fuelInfo.fuel > 0.0)

                            local fuelPlacholderContext = {
                                buildComplete = true,
                                hasFuel = hasFuel,
                                subdivLevel = object.subdivLevel,
                            }
                            
                            modelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, objectTypeIndex, fuelPlacholderContext)
                            --mj:log("modelIndex A:", modelIndex, " objectTypeIndex:", objectTypeIndex)
                            foundObjectInfo = {
                                objectTypeIndex = objectTypeIndex,
                            }
                        else
                            modelIndex = nil
                        end

                        fuelIndex = fuelIndex + 1

                    end
                end
            end

            if modelIndex then
                local subModelTransform = clientGOM:getSubModelTransform(object, key)

                clientGOM:setSubModelForKey(object.uniqueID,
                    key,
                    nil,
                    modelIndex,
                    placeholderInfo.scale or 1.0,
                    RENDER_TYPE_STATIC,
                    subModelTransform.offsetMeters,
                    subModelTransform.rotation,
                    false,
                    modelPlaceholder:getSubModelInfos(foundObjectInfo, object.subdivLevel)
                    )
            else
                clientGOM:removeSubModelForKey(object.uniqueID, key)
            end
        else
            clientGOM:removeSubModelForKey(object.uniqueID, key)
        end
    end
end

function clientTorch:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientTorch