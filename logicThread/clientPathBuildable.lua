local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local mix = mjm.mix
local cross = mjm.cross
local length = mjm.length
local length2 = mjm.length2
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local mat3Inverse = mjm.mat3Inverse

local gameObject = mjrequire "common/gameObject"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local pathBuildable = mjrequire "common/pathBuildable"
local model = mjrequire "common/model"
local resource = mjrequire "common/resource"
local constructable = mjrequire "common/constructable"
local terrain = mjrequire "common/terrain"
local rng = mjrequire "common/randomNumberGenerator"

local clientConstruction = mjrequire "logicThread/clientConstruction"

local clientPathBuildable = {}

local clientGOM = nil

local objectsNeedingUpdate = {}

local pathTestOffsets = pathBuildable.pathTestOffsets


clientPathBuildable.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    objectsNeedingUpdate[object.uniqueID] = true
end

clientPathBuildable.objectWasLoaded = function(object, pos, rotation, scale)
    objectsNeedingUpdate[object.uniqueID] = true
    clientGOM:addObjectToSet(object, clientGOM.objectSets.pathSnappables)
end

clientPathBuildable.objectSnapMatrix = function(object, pos, rotation)
    objectsNeedingUpdate[object.uniqueID] = true
end


clientPathBuildable.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        objectsNeedingUpdate[object.uniqueID] = true
        local clientState = clientGOM:getClientState(object)
        if clientState.otherObjectConnectionsToThisNode then
            for otherID,v in pairs(clientState.otherObjectConnectionsToThisNode) do
                objectsNeedingUpdate[otherID] = true
            end
        end
    end
end

function clientPathBuildable:updateBuiltObjectSubModels(object)
    local gameObjectType = gameObject.types[object.objectTypeIndex]

    clientGOM:removeAllSubmodels(object.uniqueID)

    local createIfNil = false
    local constructionObjects = clientGOM:getSharedState(object, createIfNil, "constructionObjects")
    if constructionObjects then

        local constructableTypeIndex = object.sharedState.constructionConstructableTypeIndex
        
        if constructableTypeIndex and constructable.types[constructableTypeIndex] then
            local placeholderContext = {
                buildComplete = true,
                subdivLevel = object.subdivLevel,
            }

            local constructableType = constructable.types[constructableTypeIndex]
            local requiredResources = constructableType.requiredResources

            
            local finalCountersByResourceTypeOrGroup = {}
            local usedObjects = {}

            for i=1,#requiredResources do
                local groupIndex = i
                local resourceInfo = requiredResources[groupIndex]
                
                local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group
                local requiredCount = resourceInfo.count

                

                if not finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] then
                    finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = 1
                end
                
                local resourceKey = resource:placheolderKeyForGroupOrResource(resourceTypeOrGroupIndex)
                resourceKey = modelPlaceholder:resourceRemapForModelIndexAndResourceKey(object.modelIndex, resourceKey) or resourceKey
                
                for storageCounter=1,requiredCount do

                    local finalIndexIdentifier = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]
                    
                    local finalKeyBase = resourceKey .. "_"
                    local mainFinalKey = finalKeyBase .. finalIndexIdentifier
                    
                    
                    if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, mainFinalKey) then
                        finalKeyBase = "resource_"
                    end

                    mainFinalKey = finalKeyBase .. finalIndexIdentifier

                    local mainPlaceHolderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, mainFinalKey)

                    if mainPlaceHolderInfo then
                        local finalCount = 1
                        if mainPlaceHolderInfo.additionalIndexCount and mainPlaceHolderInfo.additionalIndexCount > 0 then
                            finalCount = 1 + mainPlaceHolderInfo.additionalIndexCount
                        end

                        finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + finalCount

                        local foundObjectInfo = nil

                        for j,objectInfo in ipairs(constructionObjects) do
                            if not usedObjects[j] then
                                if resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndex, gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex) then
                                    usedObjects[j] = true
                                    foundObjectInfo = objectInfo
                                    break
                                end
                            end
                        end

                        for finalIndex=1,finalCount do
                            local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1
                            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, finalKey)
                            if placeholderInfo and (placeholderInfo.defaultModelIndex or placeholderInfo.placeholderModelIndexForObjectTypeFunction) and (not placeholderInfo.hiddenOnBuildComplete) then
                                local modelIndexToUse = nil
                                if foundObjectInfo then
                                    modelIndexToUse = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, foundObjectInfo.objectTypeIndex, placeholderContext)
                                end
                                
                                if not modelIndexToUse then
                                    modelIndexToUse = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
                                end

                                if modelIndexToUse then
                                    local subModelTransform = clientGOM:getSubModelTransform(object, finalKey)

                                    local offsetPosition = terrain:getLoadedTerrainPointAtPoint(object.pos)
                                    local objectLocalOffsetMeters = subModelTransform.offsetMeters
                                    objectLocalOffsetMeters = objectLocalOffsetMeters + mj:pToM(vec3xMat3(offsetPosition - object.pos, object.rotation))

                                    clientGOM:setSubModelForKey(object.uniqueID,
                                        finalKey,
                                        nil,
                                        modelIndexToUse,
                                        placeholderInfo.scale or 1.0,
                                        RENDER_TYPE_STATIC,
                                        objectLocalOffsetMeters,
                                        subModelTransform.rotation,
                                        false,
                                        modelPlaceholder:getSubModelInfos(foundObjectInfo, object.subdivLevel)
                                    )
                                end
                            end
                        end
                    end

                end
            end
        end
    end

    local clientState = clientGOM:getClientState(object)
    clientState.subModelInfos = {}
    clientState.nodesToOtherObjects = {}
    --if not clientState.subModelInfos then

        local subModelMinDistances = {
            mj:mToP(1.51),
            mj:mToP(2.0),
            mj:mToP(2.5),
            mj:mToP(2.75)
        }

        local maxDistanceWithSlightTollerance = pathBuildable.maxDistanceBetweenPathNodes + mj:mToP(0.001)
        
        local addSubModelsMaxDistance2 = maxDistanceWithSlightTollerance * maxDistanceWithSlightTollerance
        local subModelRightOffset = mj:mToP(0.3)


        local closePathObjectSets = clientGOM:getGameObjectsInSetsWithinNormalizedRadiusOfPos({clientGOM.objectSets.pathSnappables}, normalize(object.pos), maxDistanceWithSlightTollerance)
        local closePathObjects = closePathObjectSets[clientGOM.objectSets.pathSnappables]
        --mj:log("add nodes for object:", object.uniqueID, " closePathObjects:", closePathObjects)
        if closePathObjects then

            local function addConnectingSubModels(addedNodes, snapObjectPos, nodePos, nodePosNormal, objectDirectionVector, objectDirectionVectorLength, snapObjectIDOrNil)

                if objectDirectionVectorLength > subModelMinDistances[1] and objectDirectionVectorLength < pathBuildable.maxDistanceBetweenPathNodes then

                    local function offsetPathSubObjectsToTerrain()
                        for i,subModelUpdatedInfo in ipairs(addedNodes) do
                            local maxSubModelAltitude = nil
                            for j=1,4 do
                                local rotatedOffset = vec3xMat3(pathTestOffsets[j] * subModelUpdatedInfo.scale * 0.3, mat3Inverse(object.rotation * subModelUpdatedInfo.rotation))
                                local finalPosition = subModelUpdatedInfo.pos + rotatedOffset

                                local offsetPosition = terrain:getLoadedTerrainPointAtPoint(finalPosition)
                                local terrainAltitude = length(offsetPosition) - 1.0

                                if ((not maxSubModelAltitude) or terrainAltitude > maxSubModelAltitude) then
                                    maxSubModelAltitude = terrainAltitude
                                end
                            end
                            
                    
                            if maxSubModelAltitude then
                                local subObjectPosLength = length(subModelUpdatedInfo.pos)
                                subModelUpdatedInfo.pos = (subModelUpdatedInfo.pos / subObjectPosLength) * (maxSubModelAltitude + 1.0)
                            end
                        end
                    end

                    local distanceFraction = (objectDirectionVectorLength - subModelMinDistances[1]) / (pathBuildable.maxDistanceBetweenPathNodes - subModelMinDistances[1])
                    local midPointA = mix(snapObjectPos, nodePos, 0.5 + 0.25 * distanceFraction)
                    local directionNormal = objectDirectionVector / objectDirectionVectorLength
                    local rightVector = normalize(cross(nodePosNormal, directionNormal))

                    local directionMultiplier = 1.0
                    if rng:boolForSeed(923) then
                        directionMultiplier = -1.0
                    end


                    table.insert(addedNodes, {
                        pos = midPointA - rightVector * subModelRightOffset * (1.2 - 0.6 * distanceFraction) * directionMultiplier,
                        scale = 1.0,
                        rotation = mat3Rotate(mat3Identity, rng:valueForSeed(279) * math.pi * 2.0, vec3(0.0,1.0,0.0)),
                    })
                    

                    if objectDirectionVectorLength > subModelMinDistances[2] then
                        local distanceFractionB = (objectDirectionVectorLength - subModelMinDistances[2]) / (pathBuildable.maxDistanceBetweenPathNodes - subModelMinDistances[2])
                        local midPointB = mix(snapObjectPos, nodePos, 0.5 - 0.2 * distanceFractionB)
                        table.insert(addedNodes, {
                            pos = midPointB + rightVector * subModelRightOffset * (1.0 - 0.4 * distanceFractionB) * directionMultiplier,
                            scale = 1.1,
                            rotation = mat3Rotate(mat3Identity, rng:valueForSeed(346) * math.pi * 2.0, vec3(0.0,1.0,0.0)),
                        })
                        if objectDirectionVectorLength > subModelMinDistances[3] then
                            local distanceFractionC = (objectDirectionVectorLength - subModelMinDistances[3]) / (pathBuildable.maxDistanceBetweenPathNodes - subModelMinDistances[3])
                            local midPointC = mix(snapObjectPos, nodePos, 0.3 + 0.12 * distanceFractionC)
                            table.insert(addedNodes, {
                                pos = midPointC - rightVector * subModelRightOffset * (1.2 - 0.4 * distanceFractionC) * directionMultiplier,
                                scale = 1.3,
                                rotation = mat3Rotate(mat3Identity, rng:valueForSeed(791) * math.pi * 2.0, vec3(0.0,1.0,0.0)),
                            })
                            if objectDirectionVectorLength > subModelMinDistances[4] then
                                local midPointD = mix(snapObjectPos, nodePos, 0.6)-- + 0.2 * distanceFractionD)
                                table.insert(addedNodes, {
                                    pos = midPointD + rightVector * subModelRightOffset * 0.7 * directionMultiplier,
                                    scale = 1.25,
                                    rotation = mat3Rotate(mat3Identity, rng:valueForSeed(3454) * math.pi * 2.0, vec3(0.0,1.0,0.0)),
                                })
                            end
                        end
                    end

                    offsetPathSubObjectsToTerrain()
                end
            end

            local nodeInfo = {}
            for j,objectInfo in ipairs(closePathObjects) do
                if objectInfo.objectID ~= object.uniqueID then --and objectInfo.distance2 < minDistance2 then
                    if objectInfo.objectID < object.uniqueID then
                        local otherClientState = clientGOM.clientStates[objectInfo.objectID]
                        if otherClientState and (not (otherClientState.nodesToOtherObjects and otherClientState.nodesToOtherObjects[object.uniqueID])) then
                            --mj:log("set needs update:", objectInfo.objectID)
                            objectsNeedingUpdate[objectInfo.objectID] = true
                        end
                    else
                        --mj:log("add node a:", object.uniqueID, " => ", objectInfo.objectID)
                        local otherPathObject = clientGOM:getObjectWithID(objectInfo.objectID)
                        if otherPathObject then
                            local nodeNormal = normalize(object.pos)
                            local objectNormal = normalize(otherPathObject.pos)
                            local objectDirectionVector = nodeNormal - objectNormal
                            local objectDirectionVectorLength2 = length2(objectDirectionVector)

                            if objectDirectionVectorLength2 < addSubModelsMaxDistance2 then
                                --mj:log("add node b:", object.uniqueID, " => ", objectInfo.objectID)
                                local snapNodePos = otherPathObject.pos
                                addConnectingSubModels(nodeInfo, snapNodePos, object.pos, nodeNormal, objectDirectionVector, math.sqrt(objectDirectionVectorLength2), otherPathObject.uniqueID)
                                clientState.nodesToOtherObjects[otherPathObject.uniqueID] = true

                                local otherClientState = clientGOM:getClientState(otherPathObject)
                                if not otherClientState.otherObjectConnectionsToThisNode then
                                    otherClientState.otherObjectConnectionsToThisNode = {}
                                end
                                otherClientState.otherObjectConnectionsToThisNode[object.uniqueID] = true
                            end
                        end
                    end
                end
            end


            if nodeInfo and nodeInfo[1] then
                for j,info in ipairs(nodeInfo) do
                    local saveInfo = {
                        objectLocalOffsetMeters = mj:pToM(vec3xMat3(info.pos - object.pos, object.rotation)),
                        rotation = info.rotation,
                        scale = info.scale,
                    }

                    table.insert(clientState.subModelInfos, saveInfo)
                end
            end

            
        
        
        local subModelInfos = clientState.subModelInfos
        if subModelInfos then
            for i, subModelInfo in ipairs(subModelInfos) do
                
                local constructableTypeIndex = object.sharedState.constructionConstructableTypeIndex
                local constructableType = constructable.types[constructableTypeIndex]
                if constructableType then
                    local modelName = constructableType.defaultSubModelName

                    if constructionObjects then
                        for j=1,#constructionObjects do
                            local inventoryObjectInfo = constructionObjects[j]
                            local foundModelName = constructableType.subModelNameByObjectTypeIndexFunction(inventoryObjectInfo.objectTypeIndex)
                            if foundModelName then
                                modelName = foundModelName
                                break
                            end
                        end
                    end

                    local modelIndex = model:modelIndexForModelNameAndDetailLevel(modelName, model:modelLevelForSubdivLevel(object.subdivLevel))
                    if not modelIndex then
                        mj:error("Attempt to load missing sub model:", modelName)
                        modelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.defaultSubModelName, 1)
                    end
                    
            
                    local placeholderIdentifierToUse = "sub_" .. mj:tostring(i)
                    clientGOM:setSubModelForKey(object.uniqueID,
                        placeholderIdentifierToUse,
                        nil,
                        modelIndex,
                        subModelInfo.scale,
                        RENDER_TYPE_STATIC,
                        subModelInfo.objectLocalOffsetMeters,
                        subModelInfo.rotation,
                        true,
                        nil
                        )
                end
            end
        end
    end

    clientGOM:setTransparentBuildObject(object.uniqueID, gameObjectType.isInProgressBuildObject)
    if gameObjectType.isInProgressBuildObject then
        clientConstruction:updatePlaceholdersForCraftOrBuild(object)
    end

end

function clientPathBuildable:update()
    local objectsNeedingUpdateCopy = mj:cloneTable(objectsNeedingUpdate)
    objectsNeedingUpdate = {} --reset frist, as updateBuiltObjectSubModels can add new objects
    for objectID,v in pairs(objectsNeedingUpdateCopy) do
        local object = clientGOM:getObjectWithID(objectID)
        if object then
            clientPathBuildable:updateBuiltObjectSubModels(object)
        end
    end
end


function clientPathBuildable:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientPathBuildable