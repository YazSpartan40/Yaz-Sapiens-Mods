local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3GetRow = mjm.mat3GetRow
local mat3Inverse = mjm.mat3Inverse
--local mat3Rotate = mjm.mat3Rotate
local length2 = mjm.length2

local model = mjrequire "common/model"
local gameObject = mjrequire "common/gameObject"
local storage = mjrequire "common/storage"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local worldHelper = mjrequire "common/worldHelper"
local physicsSets = mjrequire "common/physicsSets"
local storageSettings = mjrequire "common/storageSettings"
local clientBuiltObject = mjrequire "logicThread/clientBuiltObject"
local logic = mjrequire "logicThread/logic"

local clientStorageArea = {}

local clientGOM = nil

clientStorageArea.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    --mj:log("incomingServerStateDelta:", incomingServerStateDelta)
   --mj:log("clientStorageArea.serverUpdate:", object.uniqueID, " pos:", pos, " object pos:", object.pos)
    --object.pos = pos
    --object.rotation = rotation
    --clientGOM:updateMatrix(object.uniqueID, pos, rotation)
    if incomingServerStateDelta then--and (incomingServerStateDelta.inventory or incomingServerStateDelta.settingsByTribe) then --this optimization is causing an issue as incomingServerStateDelta.inventory doesn't contain anything if everything has been removed, leaving it looking non-empty
        clientStorageArea:updateStorageAreaSubModels(object)
    end
end

clientStorageArea.objectWasLoaded = function(object, pos, rotation, scale)
    clientStorageArea:updateStorageAreaSubModels(object)
end

clientStorageArea.objectSnapMatrix = function(object, pos, rotation)
    clientStorageArea:updateStorageAreaSubModels(object)
end

clientStorageArea.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientStorageArea:updateStorageAreaSubModels(object)
    end
end


local function getTransform(object, objectTypeIndex, totalObjectCount, flatLocalHeightOffset)
    local cacheKey = string.format("%d_%d", objectTypeIndex, totalObjectCount)
    local clientState = clientGOM:getClientState(object)
    local cachedTransforms = clientState.cachedSubmodelTransforms
    if not cachedTransforms then
        cachedTransforms = {}
        clientState.cachedSubmodelTransforms = cachedTransforms
    end
    local subModelTransform = nil

    --if object.subdivLevel < mj.SUBDIVISIONS - 1 then --only use the cached value if we're at a lower detail level. Otherwise recalculate, as the environment might have changed
        subModelTransform = cachedTransforms[cacheKey]
    --end

    if not subModelTransform then
        
        local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
        local storageBox = storage:getStorageBoxForResourceType(resourceTypeIndex)
        local rotationFunction = nil
        if storageBox then
            rotationFunction = storageBox.rotationFunction
        end

        local storageAreaDistributionTypeIndex = gameObject.types[object.objectTypeIndex].storageAreaDistributionTypeIndex
        local areaDistributionInfo = storage.areaDistributions[storageAreaDistributionTypeIndex]
        if areaDistributionInfo.rotationOverrideFunction then
            rotationFunction = areaDistributionInfo.rotationOverrideFunction
        end
        
        local rotationMatrix = mat3Identity
        if rotationFunction then
            rotationMatrix = rotationFunction(object.uniqueID, totalObjectCount)
        end

        local localStorageOffsetMeters = storage:getPosition(resourceTypeIndex, storageAreaDistributionTypeIndex, totalObjectCount + 1)
        local localStorageOffset = mj:mToP(localStorageOffsetMeters)
        
        local worldPosition = object.pos + vec3xMat3(localStorageOffset, mjm.mat3Inverse(object.rotation))
        local localOffsetMeters = vec3(localStorageOffsetMeters.x, localStorageOffsetMeters.y, localStorageOffsetMeters.z)
        if flatLocalHeightOffset then
            localOffsetMeters = localOffsetMeters + mj:pToM(vec3(0.0,flatLocalHeightOffset, 0.0))-- + vec3(0.0,localStorageOffsetMeters.y,0.0)
        else
            local clampToSeaLevel = false
            local offsetPosition = worldHelper:getBelowSurfacePos(worldPosition, 0.3, physicsSets.walkableOrInProgressWalkable, nil, clampToSeaLevel)
            local worldOffset = offsetPosition - vec3(worldPosition)
            local localOffset = vec3xMat3(worldOffset, (object.rotation))
            localOffsetMeters = localOffsetMeters + mj:pToM(vec3(0.0,localOffset.y, 0.0)) + vec3(0.0,localStorageOffsetMeters.y,0.0)
        end

        if (not flatLocalHeightOffset) and ((not storageBox) or (not storageBox.dontRotateToFitBelowSurface)) then
            local upVector = worldHelper:getWalkableUpVector(worldPosition)
            rotationMatrix = mat3Inverse(object.rotation) * createUpAlignedRotationMatrix(upVector, mat3GetRow(object.rotation, 2)) * rotationMatrix
        end

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


local pegModelIndexesByStorageObjectTypeIndex = {
    [gameObject.types.storageArea.index] = {
        allowAll =      model:modelIndexForName("storageAreaPeg_allowAll"),
        removeAll =     model:modelIndexForName("storageAreaPeg_removeAll"),
        destroyAll =    model:modelIndexForName("storageAreaPeg_destroyAll"),
        allowNone =     model:modelIndexForName("storageAreaPeg_allowNone"),
        allowTakeOnly = model:modelIndexForName("storageAreaPeg_allowTakeOnly"),
        allowGiveOnly = model:modelIndexForName("storageAreaPeg_allowGiveOnly"),
    },
    [gameObject.types.storageArea1x1.index] = {
        allowAll =      model:modelIndexForName("storageAreaSmallPeg_allowAll"),
        removeAll =     model:modelIndexForName("storageAreaSmallPeg_removeAll"),
        destroyAll =    model:modelIndexForName("storageAreaSmallPeg_destroyAll"),
        allowNone =     model:modelIndexForName("storageAreaSmallPeg_allowNone"),
        allowTakeOnly = model:modelIndexForName("storageAreaSmallPeg_allowTakeOnly"),
        allowGiveOnly = model:modelIndexForName("storageAreaSmallPeg_allowGiveOnly"),
    },
    [gameObject.types.storageArea4x4.index] = {
        allowAll =      model:modelIndexForName("storageAreaLargePeg_allowAll"),
        removeAll =     model:modelIndexForName("storageAreaLargePeg_removeAll"),
        destroyAll =    model:modelIndexForName("storageAreaLargePeg_destroyAll"),
        allowNone =     model:modelIndexForName("storageAreaLargePeg_allowNone"),
        allowTakeOnly = model:modelIndexForName("storageAreaLargePeg_allowTakeOnly"),
        allowGiveOnly = model:modelIndexForName("storageAreaLargePeg_allowGiveOnly"),
    },
}

local sledStatusMarkerModelIndexes = {
    allowAll =      model:modelIndexForName("sledRail_allowAll"),
    removeAll =     model:modelIndexForName("sledRail_removeAll"),
    destroyAll =    model:modelIndexForName("sledRail_destroyAll"),
    allowNone =     model:modelIndexForName("sledRail_allowNone"),
    allowTakeOnly = model:modelIndexForName("sledRail_allowTakeOnly"),
    allowGiveOnly = model:modelIndexForName("sledRail_allowGiveOnly"),
}

function clientStorageArea:getStorageStatusKey(object)
    local tribeRelationsSettings = logic:getTribeRelationsSettings()
    local settingsTribeIDToUse = storageSettings:getSettingsTribeIDToUse(object.sharedState, logic.tribeID, tribeRelationsSettings)

    local storageAreaSettings = object.sharedState.settingsByTribe and object.sharedState.settingsByTribe[settingsTribeIDToUse]

    if storageAreaSettings then
        if storageAreaSettings.destroyAllItems then
            return "destroyAll"
        end

        if storageAreaSettings.removeAllItems then
            return "removeAll"
        end
    end

    local globalSettingsIDToUse = settingsTribeIDToUse
    if settingsTribeIDToUse == logic.tribeID then
        globalSettingsIDToUse = object.sharedState.tribeID
    end

    local globalTribeSettings = tribeRelationsSettings and tribeRelationsSettings[globalSettingsIDToUse]

    --mj:log("updateStorageAreaSubModels:", object.uniqueID, " settingsTribeIDToUse:", settingsTribeIDToUse, " storage area owner tribe:", object.sharedState.tribeID, " globalTribeSettings:", globalTribeSettings, " tribeRelationsSettings:", tribeRelationsSettings)

    local allowUse = false
    local allowStore = false

    if storageAreaSettings and (storageAreaSettings.disallowItemUse ~= nil) then
        allowUse = (not storageAreaSettings.disallowItemUse)
    elseif logic.tribeID == object.sharedState.tribeID or (not logic:tribeIsValidOwner(object.sharedState.tribeID)) then
        allowUse = true
    elseif globalTribeSettings and globalTribeSettings.storageAlly then
        allowUse = true
    end

    if storageAreaSettings and (storageAreaSettings.restrictStorageTypeIndex ~= nil) then
        allowStore = (storageAreaSettings.restrictStorageTypeIndex ~= -1)
    elseif logic.tribeID == object.sharedState.tribeID or (not logic:tribeIsValidOwner(object.sharedState.tribeID)) then
        allowStore = true
    elseif globalTribeSettings and globalTribeSettings.storageAlly then
        allowStore = true
    end

    if allowUse then
        if allowStore then
            return "allowAll"
        else
            return "allowTakeOnly"
        end
    end

    if allowStore then
        return "allowGiveOnly"
    end

    return "allowNone"
end

function clientStorageArea:updateStorageAreaSubModels(object)

    --disabled--mj:objectLog(object.uniqueID, "updateStorageAreaSubModels")
    
    local sharedState = object.sharedState
    local inventory = sharedState and sharedState.inventory
    local isCoveredSledOrCanoe = (object.objectTypeIndex == gameObject.types.coveredSled.index or object.objectTypeIndex == gameObject.types.coveredCanoe.index)

    local displayContentsHalfFull = nil
    local displayContentsFull = nil

    if isCoveredSledOrCanoe and inventory then
        local inventoryCount = (inventory.objects and #inventory.objects) or 0
        if inventoryCount > 0 then
            --todo check for max inventory
            local resourceTypeIndex = gameObject.types[inventory.objects[1].objectTypeIndex].resourceTypeIndex
            local contentsStorageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex)
            local storageMaxItems = storage:maxItemsForStorageType(contentsStorageTypeIndex, gameObject.types[object.objectTypeIndex].storageAreaDistributionTypeIndex)
            if inventoryCount >= storageMaxItems then
                displayContentsFull = true
            else
                displayContentsHalfFull = true
            end
        end
    end

    local options = { 
        additionalPlaceholderContext = {
            contentsHalfFull = displayContentsHalfFull,
            contentsFull = displayContentsFull,
        },
        preserveSubModelKeys = { "rope" }
    }

    local storageStatusKey = clientStorageArea:getStorageStatusKey(object)
    options.additionalPlaceholderContext.storageStatusKey = clientStorageArea:getStorageStatusKey(object)

    clientBuiltObject:updateBuiltObjectSubModels(object, options) --this calls removeAllSubObjects, but excludes "rope" as that's added dynamically in the sapien animation

    local isFlat = true

    local pegModelIndexes = pegModelIndexesByStorageObjectTypeIndex[object.objectTypeIndex]
    if pegModelIndexes then
        if object.subdivLevel >= mj.SUBDIVISIONS - 1 then
            local pegModelIndex = pegModelIndexes[storageStatusKey]
            if pegModelIndex then
                local prevAltitude = nil
                for i=1,4 do 
                    local placeholderName = "peg_" .. mj:tostring(i)

                    local subModelTransform = clientGOM:getSubModelTransform(object, placeholderName)

                    if isFlat then
                        local altitude2 = length2(subModelTransform.offsetMeters)
                        if prevAltitude then
                            if math.abs(prevAltitude - altitude2) > 0.001 then
                                isFlat = false
                            end
                        end
                        prevAltitude = altitude2
                    end

                    clientGOM:setSubModelForKey(object.uniqueID,
                        placeholderName,
                        nil,
                        pegModelIndex,
                        1.0,
                        RENDER_TYPE_STATIC,
                        subModelTransform.offsetMeters,
                        subModelTransform.rotation,
                        false,
                        nil
                    )
                end
            end
        end
    end

    if object.objectTypeIndex == gameObject.types.sled.index or object.objectTypeIndex == gameObject.types.coveredSled.index then
        --statusMarkerModelIndexes
        local markerModelIndex = sledStatusMarkerModelIndexes[storageStatusKey]
        if markerModelIndex then
            for i=1,2 do 
                local placeholderName = "peg_" .. mj:tostring(i)
                local subModelTransform = clientGOM:getSubModelTransform(object, placeholderName)
                clientGOM:setSubModelForKey(object.uniqueID,
                    placeholderName,
                    nil,
                    markerModelIndex,
                    1.0,
                    RENDER_TYPE_STATIC,
                    subModelTransform.offsetMeters,
                    subModelTransform.rotation,
                    false,
                    nil
                )
            end
        end
    end

        
    if inventory then
        local totalObjectCount = 0
        
        local flatLocalHeightOffset = mj:mToP(0.07)
        local firstObjectAdditionalOffsetMeters = nil
        local additionalOffsetMeters = vec3(0.0,0.0,0.0)

        if object.objectTypeIndex == gameObject.types.coveredSled.index then
            if displayContentsFull then
                additionalOffsetMeters = vec3(0.0,0.25,0.0)
                firstObjectAdditionalOffsetMeters = vec3(0.0,0.35,0.0)
            else
                additionalOffsetMeters = vec3(0.25,0.0,0.0)
            end
        elseif object.objectTypeIndex == gameObject.types.coveredCanoe.index then
            if displayContentsFull then
                additionalOffsetMeters = vec3(-0.1,0.35,0.0)
                firstObjectAdditionalOffsetMeters = vec3(0.0,0.35,0.0)
            else
                additionalOffsetMeters = vec3(-0.125,0.0,0.0)
            end
        elseif gameObject.types[object.objectTypeIndex].storageAreaShiftObjectsToGroundLevel then
            if isFlat then
                local clampToSeaLevel = false
                local offsetPosition = worldHelper:getBelowSurfacePos(object.pos, 0.3, physicsSets.walkableOrInProgressWalkable, nil, clampToSeaLevel)
                local worldOffset = offsetPosition - vec3(object.pos)
                local localOffset = vec3xMat3(worldOffset, (object.rotation))
                flatLocalHeightOffset = localOffset.y
            else
                flatLocalHeightOffset = nil
            end
        end

        for i, objectInfo in ipairs(sharedState.inventory.objects) do
            local objectTypeIndex = objectInfo.objectTypeIndex
            
            local modelIndex = gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, object.subdivLevel)
            if modelIndex then
                local transform = getTransform(object, objectTypeIndex, totalObjectCount, flatLocalHeightOffset)
                --[[local rotation = transform.rotation
                if displayContentsFull then
                    rotation = mat3Rotate(rotation, 0.2, vec3(0.0,0.0,1.0))
                end]]
                
                local key = "s_" .. mj:tostring(totalObjectCount)
                clientGOM:setSubModelForKey(object.uniqueID,
                    key,
                    nil,
                    modelIndex,
                    1.0,
                    RENDER_TYPE_STATIC,
                    transform.offsetMeters + ((i == 1 and firstObjectAdditionalOffsetMeters) or additionalOffsetMeters),
                    transform.rotation,
                    false,
                    modelPlaceholder:getSubModelInfos(objectInfo, object.subdivLevel)
                    )

                totalObjectCount = totalObjectCount + 1
            end

            if isCoveredSledOrCanoe and totalObjectCount >= 3 then
                if displayContentsFull or totalObjectCount >= 5 then
                    break
                end
            end
        end
    end
end

function clientStorageArea:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientStorageArea