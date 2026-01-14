local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local rng = mjrequire "common/randomNumberGenerator"
--local length2 = mjm.length2

--local model = mjrequire "common/model"
local resource = mjrequire "common/resource"
local gameObject = mjrequire "common/gameObject"
local storage = mjrequire "common/storage"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local worldHelper = mjrequire "common/worldHelper"
local physicsSets = mjrequire "common/physicsSets"
local clientConstruction = mjrequire "logicThread/clientConstruction"

local clientCompostBin = {}

local clientGOM = nil

clientCompostBin.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    clientCompostBin:updateSubModels(object)
end

clientCompostBin.objectWasLoaded = function(object, pos, rotation, scale)
    clientCompostBin:updateSubModels(object)
end


clientCompostBin.objectSnapMatrix = function(object, pos, rotation)
    clientCompostBin:updateSubModels(object)
end

clientCompostBin.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientCompostBin:updateSubModels(object)
    end
end


local function getTransform(object, objectTypeIndex, totalObjectCount, flatLocalHeightOffset)
    local cacheKey = string.format("%d", totalObjectCount)
    local clientState = clientGOM:getClientState(object)
    local cachedTransforms = clientState.cachedSubmodelTransforms
    if not cachedTransforms then
        cachedTransforms = {}
        clientState.cachedSubmodelTransforms = cachedTransforms
    end
    local subModelTransform = cachedTransforms[cacheKey]

    if not subModelTransform then
        
        local randomValue = rng:valueForSeed(3241 + totalObjectCount)
        local rotationMatrix = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
        randomValue = rng:valueForSeed(9872 + totalObjectCount)
        rotationMatrix = mat3Rotate(rotationMatrix, randomValue * 6.282, vec3(1.0,0.0,0.0))

        local localStorageOffsetMeters = storage:getPosition(resource.types.apple.index, storage.areaDistributions["2x2"].index, totalObjectCount + 1)
        local localStorageOffset = mj:mToP(localStorageOffsetMeters)
        
        local worldPosition = object.pos + vec3xMat3(localStorageOffset, mjm.mat3Inverse(object.rotation))
        local localOffsetMeters = vec3(localStorageOffsetMeters.x, localStorageOffsetMeters.y, localStorageOffsetMeters.z)
        if flatLocalHeightOffset then
            localOffsetMeters = localOffsetMeters + mj:pToM(vec3(0.0,flatLocalHeightOffset, 0.0))
        else
            local clampToSeaLevel = false
            local offsetPosition = worldHelper:getBelowSurfacePos(worldPosition, 0.3, physicsSets.walkableOrInProgressWalkable, nil, clampToSeaLevel)
            local worldOffset = offsetPosition - vec3(worldPosition)
            local localOffset = vec3xMat3(worldOffset, (object.rotation))
            localOffsetMeters = localOffsetMeters + mj:pToM(vec3(0.0,localOffset.y, 0.0)) + vec3(0.0,localStorageOffsetMeters.y,0.0)
        end

        localOffsetMeters = localOffsetMeters - vec3(0.0,0.05 * randomValue, 0.0)

        subModelTransform = {
            offsetMeters = localOffsetMeters,
            rotation = rotationMatrix,
        }

        if object.subdivLevel == mj.SUBDIVISIONS - 1 then
            cachedTransforms[cacheKey] = subModelTransform
        end
    end
    return subModelTransform
end

function clientCompostBin:updateSubModels(object)
    
    clientGOM:removeAllSubmodels(object.uniqueID)
    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(object.modelIndex)
    if not placeholderKeys then --probably using lowest model, everything hidden
        return
    end
        
    local sharedState = object.sharedState
    local constructionObjects = sharedState.constructionObjects

    local foundResourceCounts = {}
    local placeholderContext = {
        buildComplete = true,
        subdivLevel = object.subdivLevel,
    }

    local additionalIndexBaseInfo = nil
    local additionalIndexModelIndex = nil
    local additionalIndexRemainingCount = 0
    
    for i,key in ipairs(placeholderKeys) do
        local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key)
        --mj:log("key:", key)
        --mj:log("placeholderInfo:", placeholderInfo)

        local modelIndex = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
        if modelIndex then
            local foundObjectInfo = nil
            if placeholderInfo.resourceTypeIndex then
                if additionalIndexRemainingCount > 0 then
                    additionalIndexRemainingCount = additionalIndexRemainingCount - 1
                    foundObjectInfo = additionalIndexBaseInfo
                    modelIndex = additionalIndexModelIndex
                else
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

                                    if placeholderInfo.additionalIndexCount then
                                        additionalIndexBaseInfo = foundObjectInfo
                                        additionalIndexRemainingCount = placeholderInfo.additionalIndexCount
                                        additionalIndexModelIndex = modelIndex
                                    end
                                    
                                    --mj:log("modelIndex B:", modelIndex, " objectTypeIndex:", objectInfo.objectTypeIndex)
                                    break
                                end
                            end
                        end
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

    if sharedState and sharedState.inventory then
        local totalObjectCount = 0

        for i, objectInfo in ipairs(sharedState.inventory.objects) do
            local objectTypeIndex = objectInfo.objectTypeIndex
            local modelIndex = gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, object.subdivLevel)
            if modelIndex then

            
                local transform = getTransform(object, objectTypeIndex, totalObjectCount, nil)
                
                local key = "s_" .. mj:tostring(totalObjectCount)
                clientGOM:setSubModelForKey(object.uniqueID,
                    key,
                    nil,
                    modelIndex,
                    1.0,
                    RENDER_TYPE_STATIC,
                    transform.offsetMeters,
                    transform.rotation,
                    false,
                    modelPlaceholder:getSubModelInfos(objectInfo, object.subdivLevel)
                    )

                totalObjectCount = totalObjectCount + 1
            end
        end
    end
    
    
    if sharedState and sharedState.inventories then
        --mj:log("campfire clientConstruction:updatePlaceholdersForCraftOrBuild:", object.uniqueID)
        clientConstruction:updatePlaceholdersForCraftOrBuild(object)
    end

end

function clientCompostBin:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientCompostBin