
local model = mjrequire "common/model"
local resource = mjrequire "common/resource"
--local gameObject = mjrequire "common/gameObject"
local flora = mjrequire "common/flora"
local rock = mjrequire "common/rock"
--local worldHelper = mjrequire "common/worldHelper"

local gameObject = nil

local modelPlaceholder = {}

local storageDisplayStatusTypes = {"allowAll","removeAll","destroyAll","allowNone","allowTakeOnly", "allowGiveOnly"}

function modelPlaceholder:addModel(modelName, remapTables, resourceRemaps)
    local modelIndex = model:modelIndexForName(modelName)

    local placeholderInfos = {}
    modelPlaceholder.placeholderInfosByModelIndex[modelIndex] = placeholderInfos

    local placeholderKeys = {}
    modelPlaceholder.placeholderKeysByModelIndex[modelIndex] = placeholderKeys

    if resourceRemaps then
        modelPlaceholder.resourceRemapsByModelIndex[modelIndex] = resourceRemaps
    end

    for ri,remapTable in ipairs(remapTables) do
        local subModelIndex = model:modelIndexForName(remapTable.defaultModelName)
        local modelIndexesByDetailLevel = {
            subModelIndex,
            model:modelIndexForModelNameAndDetailLevel(remapTable.defaultModelName, 2),
            model:modelIndexForModelNameAndDetailLevel(remapTable.defaultModelName, 3),
            model:modelIndexForModelNameAndDetailLevel(remapTable.defaultModelName, 4),
        }
        if remapTable.multiCount then
            local additionalIndexCount = 1 + (remapTable.additionalIndexCount or 0)
            local keyIndex = 1 + (remapTable.indexOffset or 0)
            for i=1,remapTable.multiCount do
                for j=1,additionalIndexCount do
                    local key = remapTable.multiKeyBase .. "_" .. keyIndex
                    local additionalIndexCountToUse = remapTable.additionalIndexCount
                    if j ~= 1 then
                        additionalIndexCountToUse = nil
                    end
                    table.insert(placeholderKeys, key)
                    placeholderInfos[key] = {
                        defaultModelIndex = subModelIndex,
                        defaultModelIndexesByDetailLevel = modelIndexesByDetailLevel,
                        resourceTypeIndex = remapTable.resourceTypeIndex,
                        resourceGroupIndex = remapTable.resourceGroupIndex,
                        additionalIndexCount = additionalIndexCountToUse,
                        scale = remapTable.scale,
                        hiddenOnBuildComplete = remapTable.hiddenOnBuildComplete,
                        defaultModelShouldOverrideResourceObject = remapTable.defaultModelShouldOverrideResourceObject,
                        placeholderModelIndexForObjectTypeFunction = remapTable.placeholderModelIndexForObjectTypeFunction,
                        offsetToWalkableHeight = remapTable.offsetToWalkableHeight,
                        rotateToWalkableRotation = remapTable.rotateToWalkableRotation,
                        offsetToStorageBoxWalkableHeight = remapTable.offsetToStorageBoxWalkableHeight,
                        addModelFileYOffsetToWalkableHeight = remapTable.addModelFileYOffsetToWalkableHeight,
                    }
                    
                    keyIndex = keyIndex + 1
                end
            end
        else
            table.insert(placeholderKeys, remapTable.key)
            placeholderInfos[remapTable.key] = {
                defaultModelIndex = subModelIndex,
                defaultModelIndexesByDetailLevel = modelIndexesByDetailLevel,
                resourceTypeIndex = remapTable.resourceTypeIndex,
                resourceGroupIndex = remapTable.resourceGroupIndex,
                additionalIndexCount = remapTable.additionalIndexCount,
                scale = remapTable.scale,
                hiddenOnBuildComplete = remapTable.hiddenOnBuildComplete,
                defaultModelShouldOverrideResourceObject = remapTable.defaultModelShouldOverrideResourceObject,
                placeholderModelIndexForObjectTypeFunction = remapTable.placeholderModelIndexForObjectTypeFunction,
                offsetToWalkableHeight = remapTable.offsetToWalkableHeight,
                rotateToWalkableRotation = remapTable.rotateToWalkableRotation,
                offsetToStorageBoxWalkableHeight = remapTable.offsetToStorageBoxWalkableHeight,
                addModelFileYOffsetToWalkableHeight = remapTable.addModelFileYOffsetToWalkableHeight,
            }
        end
    end

end

function modelPlaceholder:addCloneIndex(existingIndex, cloneIndex)
    if not modelPlaceholder.placeholderInfosByModelIndex[cloneIndex] then
        modelPlaceholder.placeholderInfosByModelIndex[cloneIndex] = modelPlaceholder.placeholderInfosByModelIndex[existingIndex]
        modelPlaceholder.placeholderKeysByModelIndex[cloneIndex] = modelPlaceholder.placeholderKeysByModelIndex[existingIndex]
    end
end

function modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, remaps, placeholderContext)
    if remaps then
        local remap = remaps[model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
        if remap then
            return remap
        end
    end
    return placeholderInfo.defaultModelIndex
end


function modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndex, placeholderKey)
    local placeholderInfo = modelPlaceholder.placeholderInfosByModelIndex[modelIndex]
    if placeholderInfo then
        return placeholderInfo[placeholderKey]
    end
    return nil
end

function modelPlaceholder:resourceRemapForModelIndexAndResourceKey(modelIndex, resourceKey)
    local resourceRemap = modelPlaceholder.resourceRemapsByModelIndex[modelIndex]
    if resourceRemap then
        return resourceRemap[resourceKey]
    end

    return nil
end

function modelPlaceholder:modelHasPlaceholderKey(modelIndex, placeholderKey)
    return (modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndex, placeholderKey) ~= nil)
end

function modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, objectTypeIndex, placeholderContext)
    local subdivLevel = 1
    if placeholderContext and placeholderContext.subdivLevel then
        subdivLevel = placeholderContext.subdivLevel
    end
    if placeholderInfo.defaultModelShouldOverrideResourceObject then
        return placeholderInfo.defaultModelIndexesByDetailLevel[model:modelLevelForSubdivLevel(subdivLevel)]
    end
    if placeholderInfo.placeholderModelIndexForObjectTypeFunction then
        return placeholderInfo.placeholderModelIndexForObjectTypeFunction(placeholderInfo, objectTypeIndex, placeholderContext)
    end

    return gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, subdivLevel)
end

function modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes(placeholderInfo, resourceObjectTypeBlackListOrNil, resourceObjectTypeWhiteListOrNil, placeholderContext)
    if (not resourceObjectTypeBlackListOrNil) and (not resourceObjectTypeWhiteListOrNil) then
        return modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext or {
            subdivLevel = mj.SUBDIVISIONS - 1
        })
    end
    local resourceInfo = {}
   -- mj:log("modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes placeholderInfo:", placeholderInfo)

    if placeholderInfo.resourceTypeIndex then
        resourceInfo.type = placeholderInfo.resourceTypeIndex
    elseif placeholderInfo.resourceGroupIndex then
        resourceInfo.group = placeholderInfo.resourceGroupIndex
    else
        return modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext or {
            subdivLevel = mj.SUBDIVISIONS - 1
        })
    end

    --mj:log("modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes resourceInfo:", resourceInfo)

    local orderedAvailableObjects = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, resourceObjectTypeBlackListOrNil, resourceObjectTypeWhiteListOrNil)
    --mj:log("modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes orderedAvailableObjects:", orderedAvailableObjects)
    if orderedAvailableObjects then
        return modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, orderedAvailableObjects[1], placeholderContext or {
            subdivLevel = mj.SUBDIVISIONS - 1
        })
    end
    return modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext or {
        subdivLevel = mj.SUBDIVISIONS - 1
    })
end

function modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
    local subdivLevel = 1
    if placeholderContext and placeholderContext.subdivLevel then
        subdivLevel = placeholderContext.subdivLevel
    end
    return placeholderInfo.defaultModelIndexesByDetailLevel[model:modelLevelForSubdivLevel(subdivLevel)]
end

function modelPlaceholder:placeholderKeysForModelIndex(modelIndex)
    return modelPlaceholder.placeholderKeysByModelIndex[modelIndex]
end


function modelPlaceholder:getSubModelInfos(objectInfo, subdivLevel)
    local subModelSubModelInfos = nil

    if objectInfo then
        local gameObjectType = gameObject.types[objectInfo.objectTypeIndex]
        
        local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(gameObjectType.modelIndex)

        if placeholderKeys then
            local constructionObjects = objectInfo.constructionObjects
            local foundResourceCounts = {}
            local placeholderContext = {
                buildComplete = true,
                subdivLevel = subdivLevel,
            }
            for i,key in pairs(placeholderKeys) do
                local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(gameObjectType.modelIndex, key)
                if placeholderInfo.defaultModelIndex then
                    local modelIndex = model:modelIndexForDetailedModelIndexAndDetailLevel(placeholderInfo.defaultModelIndex, model:modelLevelForSubdivLevel(subdivLevel))
                    --mj:log("modelIndexForDetailedModelIndexAndDetailLevel. modelIndex:", modelIndex, " placeholderInfo.defaultModelIndex:", placeholderInfo.defaultModelIndex)
                    local foundSubObjectInfo = nil
                    local resourceTypeOrGroupIndex = placeholderInfo.resourceTypeIndex or placeholderInfo.resourceGroupIndex
                    if constructionObjects and resourceTypeOrGroupIndex then
                        local resourceCounter = 0
                        for j,subObjectInfo in ipairs(constructionObjects) do
                            if resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndex, gameObject.types[subObjectInfo.objectTypeIndex].resourceTypeIndex) then
                                resourceCounter = resourceCounter + 1
                                if not foundResourceCounts[resourceTypeOrGroupIndex] or resourceCounter > foundResourceCounts[resourceTypeOrGroupIndex] then
                                    foundResourceCounts[resourceTypeOrGroupIndex] = resourceCounter
                                    modelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, subObjectInfo.objectTypeIndex, placeholderContext)
                                    foundSubObjectInfo = subObjectInfo
                                    break
                                end
                            end
                        end
                    end
                    if not subModelSubModelInfos then
                        subModelSubModelInfos = {}
                    end
                    subModelSubModelInfos[#subModelSubModelInfos + 1] = {
                        key = key,
                        modelIndex = modelIndex,
                        subModels = modelPlaceholder:getSubModelInfos(foundSubObjectInfo, subdivLevel),
                    }
                end
            end
        end
    end

    return subModelSubModelInfos
end

function modelPlaceholder:getRemaps(key)
    return {
        model:modelIndexForModelNameAndDetailLevel(key, 1),
        model:modelIndexForModelNameAndDetailLevel(key, 2),
        model:modelIndexForModelNameAndDetailLevel(key, 3),
        model:modelIndexForModelNameAndDetailLevel(key, 4)
    }
end


function modelPlaceholder:initRemaps()
    modelPlaceholder.placeholderInfosByModelIndex = {}
    modelPlaceholder.placeholderKeysByModelIndex = {}
    modelPlaceholder.resourceRemapsByModelIndex = {}

    modelPlaceholder.burntFuelRemaps = {
        [gameObject.types.pineCone.index] = modelPlaceholder:getRemaps("pineConeBurnt"),
        [gameObject.types.pineConeBig.index] = modelPlaceholder:getRemaps("pineConeBurnt"),
        [gameObject.types.hay.index] = modelPlaceholder:getRemaps("burntHay"),
    }

    modelPlaceholder.longBranchRemaps = {}
    modelPlaceholder.halfBranchRemaps = {}
    modelPlaceholder.shortPoleBranchRemaps = {}
    modelPlaceholder.standardLengthPoleBranchRemaps = {}
    modelPlaceholder.balafonRemaps = {}

    for i,baseKey in ipairs(flora.branchTypeBaseKeys) do
        local baseGameObjectTypeIndex = gameObject.types[baseKey .. "Branch"].index

        modelPlaceholder.longBranchRemaps[baseGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "BranchLong")
        modelPlaceholder.halfBranchRemaps[baseGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "BranchHalf")
        modelPlaceholder.standardLengthPoleBranchRemaps[baseGameObjectTypeIndex] = modelPlaceholder:getRemaps("woodenPole_" .. baseKey)
        modelPlaceholder.shortPoleBranchRemaps[baseGameObjectTypeIndex] = modelPlaceholder:getRemaps("woodenPoleShort_" .. baseKey)
        
        modelPlaceholder.burntFuelRemaps[baseGameObjectTypeIndex] = modelPlaceholder:getRemaps("birchBranchBurnt")
        
        modelPlaceholder.balafonRemaps[baseGameObjectTypeIndex] = modelPlaceholder:getRemaps("balafon_" .. baseKey)
    end

    modelPlaceholder.longSplitLogRemaps = {}
    modelPlaceholder.longSplitLogAngleCutRemaps = {}
    modelPlaceholder.splitLog3Remaps = {}
    modelPlaceholder.splitLog075Remaps = {}
    modelPlaceholder.splitLog075AngleCutRemaps = {}
    modelPlaceholder.splitLog2x1GradRemaps = {}
    modelPlaceholder.splitLog2x1GradAngleCutRemaps = {}
    modelPlaceholder.splitLog2x2GradRemaps = {}
    modelPlaceholder.splitLog2x2GradAngleCutRemaps = {}
    modelPlaceholder.splitLog05Remaps = {}
    modelPlaceholder.splitLog05AngleCutRemaps = {}
    modelPlaceholder.shortLogRemaps = {}
    modelPlaceholder.log4Remaps = {}
    modelPlaceholder.log3Remaps = {}
    modelPlaceholder.halfLogRemaps = {}

    modelPlaceholder.splitLogNotchedRackRemapsByStatus = {}

    modelPlaceholder.splitLogFloor4x4FullLowRemaps = {}
    modelPlaceholder.splitLogFloor2x2FullLowRemaps = {}
    modelPlaceholder.splitLogFloor1x1FullLowRemaps = {}
    modelPlaceholder.splitLogFloorTri2LowContentRemaps = {}

    modelPlaceholder.logDrumRemaps = {}
    modelPlaceholder.canoeRemaps = {}
    modelPlaceholder.canoeRemapsByStatus = {}

    
    modelPlaceholder.splitLogSingleCutLeft1Remaps = {}
    modelPlaceholder.splitLogSingleCutRight1Remaps = {}
    modelPlaceholder.splitLogSingleCutLeft2Remaps = {}
    modelPlaceholder.splitLogSingleCutRight2Remaps = {}
    modelPlaceholder.splitLogSingleCutLeft3Remaps = {}
    modelPlaceholder.splitLogSingleCutRight3Remaps = {}
    modelPlaceholder.splitLogSingleCutLeft4Remaps = {}
    modelPlaceholder.splitLogSingleCutRight4Remaps = {}
    modelPlaceholder.splitLogSingleCutLeft5Remaps = {}
    modelPlaceholder.splitLogSingleCutRight5Remaps = {}
    modelPlaceholder.splitLogSingleCutLeftSmallShelfRemapsByStatus = {}

    modelPlaceholder.splitLogRoofSmallCornerLeftLowContentRemaps = {}
    modelPlaceholder.splitLogRoofSmallCornerRightLowContentRemaps = {}
    modelPlaceholder.splitLogRoofLowContentRemaps = {}
    modelPlaceholder.splitLogRoofSlopeLowContentRemaps = {}
    modelPlaceholder.splitLogRoofEndLowContentRemaps = {}
    modelPlaceholder.splitLogRoofTriangleLowContentRemaps = {}

    
    modelPlaceholder.splitLogTriFloorSection1Remaps = {}
    modelPlaceholder.splitLogTriFloorSection2Remaps = {}
    

    for i,baseKey in ipairs(flora.logTypeBaseKeys) do
        local baseSplitLogGameObjectTypeIndex = gameObject.types[baseKey .. "SplitLog"].index
        local baseLogGameObjectTypeIndex = gameObject.types[baseKey .. "Log"].index

        modelPlaceholder.longSplitLogRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogLong")
        modelPlaceholder.longSplitLogAngleCutRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogLongAngleCut")
        modelPlaceholder.splitLog3Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog3")
        modelPlaceholder.splitLog075Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog075")
        modelPlaceholder.splitLog075AngleCutRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog075AngleCut")
        modelPlaceholder.splitLog2x1GradRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog2x1Grad")
        modelPlaceholder.splitLog2x1GradAngleCutRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog2x1GradAngleCut")
        modelPlaceholder.splitLog2x2GradRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog2x2Grad")
        modelPlaceholder.splitLog2x2GradAngleCutRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog2x2GradAngleCut")
        modelPlaceholder.splitLog05Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog05")
        modelPlaceholder.splitLog05AngleCutRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLog05AngleCut")
       -- modelPlaceholder.splitLogNotchedRackRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogNotchedRack")
        modelPlaceholder.splitLogFloor4x4FullLowRemaps[baseSplitLogGameObjectTypeIndex] = model:modelIndexForName("splitLogFloor4x4FullLow_" .. baseKey)
        modelPlaceholder.splitLogFloor2x2FullLowRemaps[baseSplitLogGameObjectTypeIndex] = model:modelIndexForName("splitLogFloor2x2FullLow_" .. baseKey)
        modelPlaceholder.splitLogFloor1x1FullLowRemaps[baseSplitLogGameObjectTypeIndex] = model:modelIndexForName("splitLogFloor1x1FullLow_" .. baseKey)
        modelPlaceholder.splitLogFloorTri2LowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogFloorTri2LowContent")

        for j,statusType in ipairs(storageDisplayStatusTypes) do
            if not modelPlaceholder.splitLogNotchedRackRemapsByStatus[statusType] then
                modelPlaceholder.splitLogNotchedRackRemapsByStatus[statusType] = {}
            end
            modelPlaceholder.splitLogNotchedRackRemapsByStatus[statusType][baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogNotchedRack_" .. statusType)

            if not modelPlaceholder.splitLogSingleCutLeftSmallShelfRemapsByStatus[statusType] then
                modelPlaceholder.splitLogSingleCutLeftSmallShelfRemapsByStatus[statusType] = {}
            end
            modelPlaceholder.splitLogSingleCutLeftSmallShelfRemapsByStatus[statusType][baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeftSmallShelf_" .. statusType)


            if not modelPlaceholder.canoeRemapsByStatus[statusType] then
                modelPlaceholder.canoeRemapsByStatus[statusType] = {}
            end
            modelPlaceholder.canoeRemapsByStatus[statusType][baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps("canoe_" .. baseKey .. "_" .. statusType)
        end

        modelPlaceholder.splitLogSingleCutLeft1Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeft1")
        modelPlaceholder.splitLogSingleCutRight1Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutRight1")
        modelPlaceholder.splitLogSingleCutLeft2Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeft2")
        modelPlaceholder.splitLogSingleCutRight2Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutRight2")
        modelPlaceholder.splitLogSingleCutLeft3Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeft3")
        modelPlaceholder.splitLogSingleCutRight3Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutRight3")
        modelPlaceholder.splitLogSingleCutLeft4Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeft4")
        modelPlaceholder.splitLogSingleCutRight4Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutRight4")
        modelPlaceholder.splitLogSingleCutLeft5Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeft5")
        modelPlaceholder.splitLogSingleCutRight5Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutRight5")

        --modelPlaceholder.splitLogSingleCutLeftSmallShelfRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogSingleAngleCutLeftSmallShelf")
        
        modelPlaceholder.splitLogRoofSmallCornerLeftLowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogRoofSmallCornerLeftLowContent")
        modelPlaceholder.splitLogRoofSmallCornerRightLowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogRoofSmallCornerRightLowContent")
        modelPlaceholder.splitLogRoofLowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogRoofLowContent")
        modelPlaceholder.splitLogRoofSlopeLowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogRoofSlopeLowContent")
        modelPlaceholder.splitLogRoofEndLowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogRoofEndLowContent")
        modelPlaceholder.splitLogRoofTriangleLowContentRemaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogRoofTriangleLowContent")

        modelPlaceholder.splitLogTriFloorSection1Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogTriFloorSection1")
        modelPlaceholder.splitLogTriFloorSection2Remaps[baseSplitLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "SplitLogTriFloorSection2")

        modelPlaceholder.shortLogRemaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "LogShort")
        modelPlaceholder.log4Remaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "Log4")
        modelPlaceholder.log3Remaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "Log3")
        modelPlaceholder.halfLogRemaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps(baseKey .. "LogHalf")
        
        modelPlaceholder.burntFuelRemaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps("birchBranchBurnt")
        
        modelPlaceholder.logDrumRemaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps("logDrum_" .. baseKey)
        modelPlaceholder.canoeRemaps[baseLogGameObjectTypeIndex] = modelPlaceholder:getRemaps("canoe_" .. baseKey)
        
    end

    modelPlaceholder.hayTorchOverrides = modelPlaceholder:getRemaps("hayTorch")


    modelPlaceholder.rockPathRemaps_1 = {
        [gameObject.types.rock.index] = modelPlaceholder:getRemaps("pathNode_rock_1"),
        [gameObject.types.limestoneRock.index] = modelPlaceholder:getRemaps("pathNode_limestoneRock_1"),
        [gameObject.types.sandstoneYellowRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneYellowRock_1"),
        [gameObject.types.sandstoneRedRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneRedRock_1"),
        [gameObject.types.sandstoneOrangeRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneOrangeRock_1"),
        [gameObject.types.sandstoneBlueRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneBlueRock_1"),
        [gameObject.types.redRock.index] = modelPlaceholder:getRemaps("pathNode_redRock_1"),
        [gameObject.types.greenRock.index] = modelPlaceholder:getRemaps("pathNode_greenRock_1"),
        [gameObject.types.graniteRock.index] = modelPlaceholder:getRemaps("pathNode_graniteRock_1"),
        [gameObject.types.marbleRock.index] = modelPlaceholder:getRemaps("pathNode_marbleRock_1"),
        [gameObject.types.lapisRock.index] = modelPlaceholder:getRemaps("pathNode_lapisRock_1"),
    }
    modelPlaceholder.rockPathRemaps_2 = {
        [gameObject.types.rock.index] = modelPlaceholder:getRemaps("pathNode_rock_2"),
        [gameObject.types.limestoneRock.index] = modelPlaceholder:getRemaps("pathNode_limestoneRock_2"),
        [gameObject.types.sandstoneYellowRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneYellowRock_2"),
        [gameObject.types.sandstoneRedRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneRedRock_2"),
        [gameObject.types.sandstoneOrangeRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneOrangeRock_2"),
        [gameObject.types.sandstoneBlueRock.index] = modelPlaceholder:getRemaps("pathNode_sandstoneBlueRock_2"),
        [gameObject.types.redRock.index] = modelPlaceholder:getRemaps("pathNode_redRock_2"),
        [gameObject.types.greenRock.index] = modelPlaceholder:getRemaps("pathNode_greenRock_2"),
        [gameObject.types.graniteRock.index] = modelPlaceholder:getRemaps("pathNode_graniteRock_2"),
        [gameObject.types.marbleRock.index] = modelPlaceholder:getRemaps("pathNode_marbleRock_2"),
        [gameObject.types.lapisRock.index] = modelPlaceholder:getRemaps("pathNode_lapisRock_2"),
    }


    modelPlaceholder.dirtPathRemaps_1 = {
        [gameObject.types.dirt.index] = modelPlaceholder:getRemaps("pathNode_dirt_1"),
        [gameObject.types.richDirt.index] = modelPlaceholder:getRemaps("pathNode_richDirt_1"),
        [gameObject.types.poorDirt.index] = modelPlaceholder:getRemaps("pathNode_poorDirt_1"),
    }

    modelPlaceholder.sandPathRemaps_1 = {
        [gameObject.types.sand.index] = model:modelIndexForName("pathNode_sand_1"),
        [gameObject.types.riverSand.index] = model:modelIndexForName("pathNode_riverSand_1"),
        [gameObject.types.redSand.index] = model:modelIndexForName("pathNode_redSand_1"),
    }

    modelPlaceholder.clayPathRemaps_1 = {
        [gameObject.types.clay.index] = model:modelIndexForName("pathNode_clay_1"),
    }

    modelPlaceholder.dirtFoundation1x1ContentRemaps = {
        [gameObject.types.dirt.index] = model:modelIndexForName("dirtFoundation1x1Content"),
        [gameObject.types.richDirt.index] = model:modelIndexForName("dirtFoundation1x1Content_richDirt"),
        [gameObject.types.poorDirt.index] = model:modelIndexForName("dirtFoundation1x1Content_poorDirt"),
    }
    modelPlaceholder.dirtFoundation1x1ContentLowRemaps = {
        [gameObject.types.dirt.index] = model:modelIndexForName("dirtFoundation1x1Content_low"),
        [gameObject.types.richDirt.index] = model:modelIndexForName("dirtFoundation1x1Content_low_richDirt"),
        [gameObject.types.poorDirt.index] = model:modelIndexForName("dirtFoundation1x1Content_low_poorDirt"),
    }

    modelPlaceholder.dirtFoundation2x2ContentRemaps = {
        [gameObject.types.dirt.index] = model:modelIndexForName("dirtFoundation2x2Content"),
        [gameObject.types.richDirt.index] = model:modelIndexForName("dirtFoundation2x2Content_richDirt"),
        [gameObject.types.poorDirt.index] = model:modelIndexForName("dirtFoundation2x2Content_poorDirt"),
    }
    modelPlaceholder.dirtFoundation2x2ContentLowRemaps = {
        [gameObject.types.dirt.index] = model:modelIndexForName("dirtFoundation2x2Content_low"),
        [gameObject.types.richDirt.index] = model:modelIndexForName("dirtFoundation2x2Content_low_richDirt"),
        [gameObject.types.poorDirt.index] = model:modelIndexForName("dirtFoundation2x2Content_low_poorDirt"),
    }

    modelPlaceholder.woolskinBedRemaps_1 = {
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("woolskinBed_woolskinMammoth_1"),
    }
    modelPlaceholder.woolskinBedRemaps_2 = {
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("woolskinBed_woolskinMammoth_2"),
    }
    modelPlaceholder.woolskinBedRemaps_3 = {
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("woolskinBed_woolskinMammoth_3"),
    }

    modelPlaceholder.coveredSledEmptyWoolskinRemaps = {
        [gameObject.types.alpacaWoolskin.index] = modelPlaceholder:getRemaps("coveredSledEmptyWoolskin"),
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("coveredSledEmptyWoolskinMammoth"),
    }
    
    modelPlaceholder.coveredSledHalfFullWoolskinRemaps = {
        [gameObject.types.alpacaWoolskin.index] = modelPlaceholder:getRemaps("coveredSledHalfFullWoolskin"),
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("coveredSledHalfFullWoolskinMammoth"),
    }
    
    modelPlaceholder.coveredSledFullWoolskinRemaps = {
        [gameObject.types.alpacaWoolskin.index] = modelPlaceholder:getRemaps("coveredSledFullWoolskin"),
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("coveredSledFullWoolskinMammoth"),
    }

    modelPlaceholder.coveredCanoeEmptyWoolskinRemaps = {
        [gameObject.types.alpacaWoolskin.index] = modelPlaceholder:getRemaps("coveredCanoeEmptyWoolskin"),
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("coveredCanoeEmptyWoolskinMammoth"),
    }
    
    modelPlaceholder.coveredCanoeHalfFullWoolskinRemaps = {
        [gameObject.types.alpacaWoolskin.index] = modelPlaceholder:getRemaps("coveredCanoeHalfFullWoolskin"),
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("coveredCanoeHalfFullWoolskinMammoth"),
    }
    
    modelPlaceholder.coveredCanoeFullWoolskinRemaps = {
        [gameObject.types.alpacaWoolskin.index] = modelPlaceholder:getRemaps("coveredCanoeFullWoolskin"),
        [gameObject.types.mammothWoolskin.index] = modelPlaceholder:getRemaps("coveredCanoeFullWoolskinMammoth"),
    }


    modelPlaceholder.craftAreaRockRemaps = {
        [gameObject.types.rock.index] = model:modelIndexForName("craftArea_rock1"),
        [gameObject.types.limestoneRock.index] = model:modelIndexForName("craftArea_limestoneRock"),
        [gameObject.types.sandstoneYellowRock.index] = model:modelIndexForName("craftArea_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRock.index] = model:modelIndexForName("craftArea_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRock.index] = model:modelIndexForName("craftArea_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRock.index] = model:modelIndexForName("craftArea_sandstoneBlueRock"),
        [gameObject.types.redRock.index] = model:modelIndexForName("craftArea_redRock"),
        [gameObject.types.greenRock.index] = model:modelIndexForName("craftArea_greenRock"),
        [gameObject.types.graniteRock.index] = model:modelIndexForName("craftArea_graniteRock"),
        [gameObject.types.marbleRock.index] = model:modelIndexForName("craftArea_marbleRock"),
        [gameObject.types.lapisRock.index] = model:modelIndexForName("craftArea_lapisRock"),
    }
    
    modelPlaceholder.craftAreaRockRemapsLow = {
        [gameObject.types.rock.index] = model:modelIndexForName("craftArea_rock1_low"),
        [gameObject.types.limestoneRock.index] = model:modelIndexForName("craftArea_low_limestoneRock"),
        [gameObject.types.sandstoneYellowRock.index] = model:modelIndexForName("craftArea_low_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRock.index] = model:modelIndexForName("craftArea_low_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRock.index] = model:modelIndexForName("craftArea_low_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRock.index] = model:modelIndexForName("craftArea_low_sandstoneBlueRock"),
        [gameObject.types.redRock.index] = model:modelIndexForName("craftArea_low_redRock"),
        [gameObject.types.greenRock.index] = model:modelIndexForName("craftArea_low_greenRock"),
        [gameObject.types.graniteRock.index] = model:modelIndexForName("craftArea_low_graniteRock"),
        [gameObject.types.marbleRock.index] = model:modelIndexForName("craftArea_low_marbleRock"),
        [gameObject.types.lapisRock.index] = model:modelIndexForName("craftArea_low_lapisRock"),
    }



    modelPlaceholder.mudBrickKilnSectionRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = modelPlaceholder:getRemaps("mudBrickKilnSection_sand"),
        [gameObject.types.mudBrickDry_hay.index] = modelPlaceholder:getRemaps("mudBrickKilnSection_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = modelPlaceholder:getRemaps("mudBrickKilnSection_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = modelPlaceholder:getRemaps("mudBrickKilnSection_redSand"),
    }

    modelPlaceholder.mudBrickKilnSectionWithOpeningRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionWithOpening_sand"),
        [gameObject.types.mudBrickDry_hay.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionWithOpening_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionWithOpening_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionWithOpening_redSand"),
    }

    modelPlaceholder.mudBrickKilnSectionTopRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionTop_sand"),
        [gameObject.types.mudBrickDry_hay.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionTop_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionTop_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = modelPlaceholder:getRemaps("mudBrickKilnSectionTop_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSection_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSection_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSection_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSection_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionRoofEnd1Remaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd1_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd1_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd1_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd1_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionRoofEnd2Remaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd2_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd2_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd2_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionRoofEnd2_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionRoofEndLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionRoofEndLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionRoofEndLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionRoofEndLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionRoofEndLow_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionFullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionFullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionFullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionFullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionFullLow_redSand"),
    }

    modelPlaceholder.mudBrickWallSection4x1FullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSection4x1FullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSection4x1FullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSection4x1FullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSection4x1FullLow_redSand"),
    }

    modelPlaceholder.mudBrickWallSection2x2FullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSection2x2FullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSection2x2FullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSection2x2FullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSection2x2FullLow_redSand"),
    }

    modelPlaceholder.mudBrickWallSection2x1FullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSection2x1FullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSection2x1FullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSection2x1FullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSection2x1FullLow_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionWindowFullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionWindowFullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionWindowFullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionWindowFullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionWindowFullLow_redSand"),
    }
    modelPlaceholder.mudBrickWallSectionDoorFullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionDoorFullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionDoorFullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionDoorFullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionDoorFullLow_redSand"),
    }

    modelPlaceholder.mudBrickWallColumnRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallColumn_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallColumn_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallColumn_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallColumn_redSand"),
    }

    modelPlaceholder.mudBrickWallSection075Remaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSection_075_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSection_075_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSection_075_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSection_075_redSand"),
    }

    modelPlaceholder.mudBrickWallSectionSingleHighRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionSingleHigh_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionSingleHigh_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionSingleHigh_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionSingleHigh_redSand"),
    }

    modelPlaceholder.mudBrickWallDoorTopRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickWallSectionDoorTop_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickWallSectionDoorTop_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickWallSectionDoorTop_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickWallSectionDoorTop_redSand"),
    }

    modelPlaceholder.mudBrickColumnTopRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickColumnTop_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickColumnTop_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickColumnTop_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickColumnTop_redSand"),
    }
    modelPlaceholder.mudBrickColumnBottomRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickColumnBottom_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickColumnBottom_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickColumnBottom_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickColumnBottom_redSand"),
    }
    modelPlaceholder.mudBrickColumnFullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickColumnFullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickColumnFullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickColumnFullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickColumnFullLow_redSand"),
    }

    modelPlaceholder.mudBrickFloorSection1x1Remaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFloorSection1x1_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFloorSection1x1_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFloorSection1x1_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFloorSection1x1_redSand"),
    }

    modelPlaceholder.mudBrickFloorSection2x1Remaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFloorSection2x1_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFloorSection2x1_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFloorSection2x1_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFloorSection2x1_redSand"),
    }

    modelPlaceholder.mudBrickFloorTriSection2Remaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFloorTriSection2_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFloorTriSection2_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFloorTriSection2_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFloorTriSection2_redSand"),
    }

    modelPlaceholder.mudBrickFloorSection4x4FullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFloorSection4x4FullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFloorSection4x4FullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFloorSection4x4FullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFloorSection4x4FullLow_redSand"),
    }

    modelPlaceholder.mudBrickFloorSection2x2FullLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFloorSection2x2FullLow_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFloorSection2x2FullLow_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFloorSection2x2FullLow_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFloorSection2x2FullLow_redSand"),
    }

    modelPlaceholder.mudBrickFloorTri2LowContentRemaps = {
        [gameObject.types.mudBrickDry_sand.index] =         model:modelIndexForName("mudBrickFloorTri2LowContent_sand"),
        [gameObject.types.mudBrickDry_hay.index] =          model:modelIndexForName("mudBrickFloorTri2LowContent_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] =    model:modelIndexForName("mudBrickFloorTri2LowContent_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] =      model:modelIndexForName("mudBrickFloorTri2LowContent_redSand"),
    }

    modelPlaceholder.mudBrickFoundation1x1ContentRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFoundation1x1Content_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFoundation1x1Content_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFoundation1x1Content_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFoundation1x1Content_redSand"),
    }
    modelPlaceholder.mudBrickFoundation1x1ContentLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFoundation1x1Content_low_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFoundation1x1Content_low_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFoundation1x1Content_low_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFoundation1x1Content_low_redSand"),
    }

    modelPlaceholder.mudBrickFoundation2x2ContentRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFoundation2x2Content_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFoundation2x2Content_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFoundation2x2Content_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFoundation2x2Content_redSand"),
    }
    modelPlaceholder.mudBrickFoundation2x2ContentLowRemaps = {
        [gameObject.types.mudBrickDry_sand.index] = model:modelIndexForName("mudBrickFoundation2x2Content_low_sand"),
        [gameObject.types.mudBrickDry_hay.index] = model:modelIndexForName("mudBrickFoundation2x2Content_low_hay"),
        [gameObject.types.mudBrickDry_riverSand.index] = model:modelIndexForName("mudBrickFoundation2x2Content_low_riverSand"),
        [gameObject.types.mudBrickDry_redSand.index] = model:modelIndexForName("mudBrickFoundation2x2Content_low_redSand"),
    }

    modelPlaceholder.stoneBlockWallSectionRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallSection"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_lapisRock"),
    }
    
    modelPlaceholder.stoneBlockWallSectionRoofEnd1Remaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd1_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSectionRoofEnd2Remaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEnd2_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSectionRoofEndLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSectionRoofEndLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSectionRoofEndLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEndLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSectionRoofEndLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionRoofEndLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSectionRoofEndLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSectionRoofEndLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionRoofEndLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSectionRoofEndLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSectionRoofEndLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionRoofEndLow_lapisRock"),
    }
    

    modelPlaceholder.stoneBlockColumnTopRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockColumnTop"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockColumnTop_lapisRock"),
    }

    modelPlaceholder.stoneBlockColumnBottomRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockColumnBottom"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockColumnBottom_lapisRock"),
    }

    modelPlaceholder.stoneBlockColumnFullLowRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockColumnFullLow_lapisRock"),
    }

    
    modelPlaceholder.stoneBlockWallSection075Remaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallSection_075"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallSection_075_lapisRock"),
    }
    
    modelPlaceholder.stoneBlockWallDoorTopRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorTop_lapisRock"),
    }
    

    modelPlaceholder.stoneBlockWallColumnRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallColumn"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallColumn_lapisRock"),
    }

    modelPlaceholder.stoneBlockWallSectionSingleHighRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionSingleHigh_lapisRock"),
    }

    
    modelPlaceholder.stoneBlockWallSectionFullLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSectionFullLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSectionFullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionFullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSectionFullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionFullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSectionFullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSectionFullLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionFullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSectionFullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSectionFullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionFullLow_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSection4x1FullLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSection4x1FullLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSection4x1FullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSection4x1FullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSection4x1FullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSection4x1FullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSection4x1FullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSection4x1FullLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSection4x1FullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSection4x1FullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSection4x1FullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSection4x1FullLow_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSection2x2FullLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSection2x2FullLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSection2x2FullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSection2x2FullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSection2x2FullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSection2x2FullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSection2x2FullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSection2x2FullLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSection2x2FullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSection2x2FullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSection2x2FullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSection2x2FullLow_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSection2x1FullLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSection2x1FullLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSection2x1FullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSection2x1FullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSection2x1FullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSection2x1FullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSection2x1FullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSection2x1FullLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSection2x1FullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSection2x1FullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSection2x1FullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSection2x1FullLow_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSectionWindowFullLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSectionWindowFullLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSectionWindowFullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionWindowFullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSectionWindowFullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionWindowFullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSectionWindowFullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSectionWindowFullLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionWindowFullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSectionWindowFullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSectionWindowFullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionWindowFullLow_lapisRock"),
    }
    modelPlaceholder.stoneBlockWallSectionDoorFullLowRemaps = {
        [gameObject.types.stoneBlock.index] =               model:modelIndexForName("stoneBlockWallSectionDoorFullLow"),
        [gameObject.types.limestoneRockBlock.index] =       model:modelIndexForName("stoneBlockWallSectionDoorFullLow_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorFullLow_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] =    model:modelIndexForName("stoneBlockWallSectionDoorFullLow_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockWallSectionDoorFullLow_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] =   model:modelIndexForName("stoneBlockWallSectionDoorFullLow_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] =             model:modelIndexForName("stoneBlockWallSectionDoorFullLow_redRock"),
        [gameObject.types.greenRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionDoorFullLow_greenRock"),
        [gameObject.types.graniteRockBlock.index] =         model:modelIndexForName("stoneBlockWallSectionDoorFullLow_graniteRock"),
        [gameObject.types.marbleRockBlock.index] =          model:modelIndexForName("stoneBlockWallSectionDoorFullLow_marbleRock"),
        [gameObject.types.lapisRockBlock.index] =           model:modelIndexForName("stoneBlockWallSectionDoorFullLow_lapisRock"),
    }
    

    modelPlaceholder.stoneBlockFoundation1x1ContentRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_lapisRock"),
    }
    modelPlaceholder.stoneBlockFoundation1x1ContentLowRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockFoundation1x1Content_low_lapisRock"),
    }
    modelPlaceholder.stoneBlockFoundation2x2ContentRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_lapisRock"),
    }
    modelPlaceholder.stoneBlockFoundation2x2ContentLowRemaps = {
        [gameObject.types.stoneBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low"),
        [gameObject.types.limestoneRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_limestoneRock"),
        [gameObject.types.sandstoneYellowRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_sandstoneYellowRock"),
        [gameObject.types.sandstoneRedRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_sandstoneRedRock"),
        [gameObject.types.sandstoneOrangeRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_sandstoneOrangeRock"),
        [gameObject.types.sandstoneBlueRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_sandstoneBlueRock"),
        [gameObject.types.redRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_redRock"),
        [gameObject.types.greenRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_greenRock"),
        [gameObject.types.graniteRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_graniteRock"),
        [gameObject.types.marbleRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_marbleRock"),
        [gameObject.types.lapisRockBlock.index] = model:modelIndexForName("stoneBlockFoundation2x2Content_low_lapisRock"),
    }

    modelPlaceholder.brickWallSectionRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSection_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSection_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSection_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSection_redSand"),
    }

    modelPlaceholder.brickWallSection075Remaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSection_075_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSection_075_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSection_075_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSection_075_redSand"),
    }

    modelPlaceholder.brickWallDoorTopRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionDoorTop_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionDoorTop_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionDoorTop_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionDoorTop_redSand"),
    }


    modelPlaceholder.brickWallColumnRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallColumn_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallColumn_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallColumn_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallColumn_redSand"),
    }

    modelPlaceholder.brickWallSectionSingleHighRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionSingleHigh_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionSingleHigh_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionSingleHigh_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionSingleHigh_redSand"),
    }



    modelPlaceholder.brickWallSectionFullLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionFullLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionFullLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionFullLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionFullLow_redSand"),
    }

    modelPlaceholder.brickWallSection4x1FullLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSection4x1FullLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSection4x1FullLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSection4x1FullLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSection4x1FullLow_redSand"),
    }

    modelPlaceholder.brickWallSection2x2FullLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSection2x2FullLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSection2x2FullLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSection2x2FullLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSection2x2FullLow_redSand"),
    }

    modelPlaceholder.brickWallSection2x1FullLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSection2x1FullLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSection2x1FullLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSection2x1FullLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSection2x1FullLow_redSand"),
    }

    modelPlaceholder.brickWallSectionWindowFullLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionWindowFullLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionWindowFullLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionWindowFullLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionWindowFullLow_redSand"),
    }
    modelPlaceholder.brickWallSectionDoorFullLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionDoorFullLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionDoorFullLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionDoorFullLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionDoorFullLow_redSand"),
    }

    modelPlaceholder.brickWallSectionRoofEnd1Remaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionRoofEnd1_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionRoofEnd1_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionRoofEnd1_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionRoofEnd1_redSand"),
    }

    modelPlaceholder.brickWallSectionRoofEnd2Remaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionRoofEnd2_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionRoofEnd2_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionRoofEnd2_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionRoofEnd2_redSand"),
    }

    modelPlaceholder.brickWallSectionRoofEndLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickWallSectionRoofEndLow_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickWallSectionRoofEndLow_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickWallSectionRoofEndLow_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickWallSectionRoofEndLow_redSand"),
    }


    modelPlaceholder.brickFoundation1x1ContentRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickFoundation1x1Content_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickFoundation1x1Content_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickFoundation1x1Content_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickFoundation1x1Content_redSand"),
    }
    modelPlaceholder.brickFoundation1x1ContentLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickFoundation1x1Content_low_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickFoundation1x1Content_low_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickFoundation1x1Content_low_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickFoundation1x1Content_low_redSand"),
    }

    modelPlaceholder.brickFoundation2x2ContentRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickFoundation2x2Content_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickFoundation2x2Content_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickFoundation2x2Content_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickFoundation2x2Content_redSand"),
    }
    modelPlaceholder.brickFoundation2x2ContentLowRemaps = {
        [gameObject.types.firedBrick_sand.index] = model:modelIndexForName("brickFoundation2x2Content_low_sand"),
        [gameObject.types.firedBrick_hay.index] = model:modelIndexForName("brickFoundation2x2Content_low_hay"),
        [gameObject.types.firedBrick_riverSand.index] = model:modelIndexForName("brickFoundation2x2Content_low_riverSand"),
        [gameObject.types.firedBrick_redSand.index] = model:modelIndexForName("brickFoundation2x2Content_low_redSand"),
    }
    
    modelPlaceholder.tileRoofSection4Remaps = {}
    modelPlaceholder.tileRoofSection2Remaps = {}
    modelPlaceholder.tileRoofLowContentRemaps = {}
    modelPlaceholder.tileRoofSlopeLowContentRemaps = {}
    modelPlaceholder.tileRoofSmallCornerSection1Remaps = {}
    modelPlaceholder.tileRoofSmallCornerSection2Remaps = {}
    modelPlaceholder.tileRoofSmallCornerLowContentRemaps = {}
    modelPlaceholder.tileRoofSmallInnerCornerSection1Remaps = {}
    modelPlaceholder.tileRoofSmallInnerCornerSection2Remaps = {}
    modelPlaceholder.tileRoofTriangleSectionRemaps = {}
    modelPlaceholder.tileRoofInvertedTriangleSectionRemaps = {}
    modelPlaceholder.tileFloorSection1x1Remaps = {}
    modelPlaceholder.tileFloorSection2x1Remaps = {}
    modelPlaceholder.tileFloorTriSection2Remaps = {}
    modelPlaceholder.tilePathRemaps_1 = {}
    modelPlaceholder.tilePathRemaps_2 = {}
    modelPlaceholder.tileFloorSection4x4FullLowRemaps = {}
    modelPlaceholder.tileFloorSection2x2FullLowRemaps = {}
    modelPlaceholder.tileFloorTri2LowContentRemaps = {}

    local tileRemapModelKeysByObjectKeys = { 
        firedTile = "firedTile",
        stoneTile = "stoneTile",
    }

    local tileRemapsByModelNameBases = {
        tileRoofSection4 = modelPlaceholder.tileRoofSection4Remaps,
        tileRoofSection2 = modelPlaceholder.tileRoofSection2Remaps,
        tileRoofLowContent = modelPlaceholder.tileRoofLowContentRemaps,
        tileRoofSlopeLowContent = modelPlaceholder.tileRoofSlopeLowContentRemaps,
        tileRoofSmallCornerSection1 = modelPlaceholder.tileRoofSmallCornerSection1Remaps,
        tileRoofSmallCornerSection2 = modelPlaceholder.tileRoofSmallCornerSection2Remaps,
        tileRoofSmallCornerLowContent = modelPlaceholder.tileRoofSmallCornerLowContentRemaps,
        tileRoofSmallInnerCornerSection1 = modelPlaceholder.tileRoofSmallInnerCornerSection1Remaps,
        tileRoofSmallInnerCornerSection2 = modelPlaceholder.tileRoofSmallInnerCornerSection2Remaps,
        tileRoofTriangleSection = modelPlaceholder.tileRoofTriangleSectionRemaps,
        tileRoofInvertedTriangleSection = modelPlaceholder.tileRoofInvertedTriangleSectionRemaps,
        tileFloorSection1x1 = modelPlaceholder.tileFloorSection1x1Remaps,
        tileFloorSection2x1 = modelPlaceholder.tileFloorSection2x1Remaps,
        tileFloorTriSection2 = modelPlaceholder.tileFloorTriSection2Remaps,
        tileFloorSection4x4FullLow = modelPlaceholder.tileFloorSection4x4FullLowRemaps,
        tileFloorSection2x2FullLow = modelPlaceholder.tileFloorSection2x2FullLowRemaps,
        tileFloorTri2LowContent = modelPlaceholder.tileFloorTri2LowContentRemaps,
    }

    for i, rockType in ipairs(rock.validTypes) do
        if rockType.craftablePostfix ~= "" then
            tileRemapModelKeysByObjectKeys["stoneTile" .. rockType.craftablePostfix] = "stoneTile_" .. rockType.objectTypeKey
        end
    end

    for modelNameBase, tileRemaps in pairs(tileRemapsByModelNameBases) do
        for objectKey,remapModelKey in pairs(tileRemapModelKeysByObjectKeys) do
            tileRemaps[gameObject.types[objectKey].index] = model:modelIndexForName(modelNameBase .. "_" .. remapModelKey)
        end
    end

    
    for objectKey,remapModelKey in pairs(tileRemapModelKeysByObjectKeys) do
        modelPlaceholder.tilePathRemaps_1[gameObject.types[objectKey].index] = modelPlaceholder:getRemaps("pathNode_" .. remapModelKey .. "_1")
        modelPlaceholder.tilePathRemaps_2[gameObject.types[objectKey].index] = modelPlaceholder:getRemaps("pathNode_" .. remapModelKey .. "_2")
    end

end


function modelPlaceholder:addModels()
    modelPlaceholder:addModel("campfire", {
        { 
            multiKeyBase = "rockAny",
            multiCount = 6, 
            defaultModelName = "rock1",
            resourceGroupIndex = resource.groups.rockAny.index,
            offsetToWalkableHeight = true,
        },
        {
            key = "rockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        { 
            multiKeyBase = "branch",
            multiCount = 6, 
            defaultModelName = "branch",
            offsetToWalkableHeight = true,
            rotateToWalkableRotation = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete and (not placeholderContext.hasFuel) and modelPlaceholder.burntFuelRemaps[objectTypeIndex] then
                    return modelPlaceholder.burntFuelRemaps[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
                end
                
                if placeholderContext.subdivLevel then
                    return gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, placeholderContext.subdivLevel)
                end
                
                return gameObject.types[objectTypeIndex].modelIndex
            end
        },
        { 
            key = "ash",
            defaultModelName = "campfireAsh",
            offsetToWalkableHeight = true,
            rotateToWalkableRotation = true,
        },
    })

    modelPlaceholder:addModel("campfire_low", {
        { 
            multiKeyBase = "rockAny",
            multiCount = 6, 
            defaultModelName = "rock1",
            resourceGroupIndex = resource.groups.rockAny.index,
            offsetToWalkableHeight = true,
        },
        {
            key = "rockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        { 
            multiKeyBase = "branch",
            multiCount = 6, 
            defaultModelName = "branch",
            offsetToWalkableHeight = true,
            rotateToWalkableRotation = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete and (not placeholderContext.hasFuel) and modelPlaceholder.burntFuelRemaps[objectTypeIndex] then
                    return modelPlaceholder.burntFuelRemaps[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
                end
                
                if placeholderContext.subdivLevel then
                    return gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, placeholderContext.subdivLevel)
                end
                
                return gameObject.types[objectTypeIndex].modelIndex
            end
        },
    })



    modelPlaceholder:addModel("brickKiln", {
        { 
            key = "mudBrickDry_1",
            defaultModelName = "mudBrickKilnSection_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.mudBrickKilnSectionRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "mudBrickDry_2",
            defaultModelName = "mudBrickKilnSectionWithOpening_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.mudBrickKilnSectionWithOpeningRemaps[objectTypeIndex], placeholderContext)--mudBrickKilnSectionWithOpeningRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "mudBrickDry_3",
            defaultModelName = "mudBrickKilnSection_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.mudBrickKilnSectionRemaps[objectTypeIndex], placeholderContext)--mudBrickKilnSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "mudBrickDry_4",
            defaultModelName = "mudBrickKilnSection_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.mudBrickKilnSectionRemaps[objectTypeIndex], placeholderContext)--mudBrickKilnSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "mudBrickDry_5",
            defaultModelName = "mudBrickKilnSectionTop_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.mudBrickKilnSectionTopRemaps[objectTypeIndex], placeholderContext)--mudBrickKilnSectionTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "mudBrickDry_6",
            defaultModelName = "mudBrickKilnSectionTop_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.mudBrickKilnSectionTopRemaps[objectTypeIndex], placeholderContext)--mudBrickKilnSectionTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        { 
            multiKeyBase = "branch",
            multiCount = 10, 
            defaultModelName = "branch",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete and (not placeholderContext.hasFuel) and modelPlaceholder.burntFuelRemaps[objectTypeIndex] then
                    return modelPlaceholder.burntFuelRemaps[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
                end

                if modelPlaceholder.halfLogRemaps[objectTypeIndex] then
                    return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfLogRemaps[objectTypeIndex], placeholderContext)
                end

                if modelPlaceholder.halfBranchRemaps[objectTypeIndex] then
                    return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfBranchRemaps[objectTypeIndex], placeholderContext)
                end
                
                if placeholderContext.subdivLevel then
                    return gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, placeholderContext.subdivLevel)
                end
                
                return gameObject.types[objectTypeIndex].modelIndex
            end
        },
        { 
            key = "ash",
            defaultModelName = "campfireAsh",
        },
    })


    modelPlaceholder:addModel("hayBed", {
        { 
            key = "hay_1",
            defaultModelName = "hayBed_hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            offsetToWalkableHeight = true,
        },
        { 
            key = "hay_2",
            defaultModelName = "hayBed_hay_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            offsetToWalkableHeight = true,
        },
        { 
            key = "hay_3",
            defaultModelName = "hayBed_hay_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            offsetToWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })



    modelPlaceholder:addModel("hayBed_low", {
        { 
            key = "hay_1",
            defaultModelName = "hayBed_hay_1_low",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            offsetToWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("woolskinBed", {
        { 
            key = "woolskin_1",
            defaultModelName = "woolskinBed_woolskin_1",
            resourceTypeIndex = resource.types.woolskin.index,
            offsetToWalkableHeight = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.woolskinBedRemaps_1[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "woolskin_2",
            defaultModelName = "woolskinBed_woolskin_2",
            resourceTypeIndex = resource.types.woolskin.index,
            offsetToWalkableHeight = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.woolskinBedRemaps_2[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "woolskin_3",
            defaultModelName = "woolskinBed_woolskin_3",
            resourceTypeIndex = resource.types.woolskin.index,
            offsetToWalkableHeight = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.woolskinBedRemaps_3[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "woolskin_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("woolskinBed_low", {
        { 
            key = "woolskin_1",
            defaultModelName = "woolskinBed_woolskin_1_low",
            resourceTypeIndex = resource.types.woolskin.index,
            offsetToWalkableHeight = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.woolskinBedRemaps_1[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "woolskin_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("thatchResearch", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branch",
            resourceTypeIndex = resource.types.branch.index,
        },
        { 
            key = "hay_1",
            additionalIndexCount = 1, 
            defaultModelName = "thatchWide_075",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        { 
            key = "hay_2",
            defaultModelName = "thatchWide_075",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })



    modelPlaceholder:addModel("mudBrickBuildingResearch", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 2, 
            defaultModelName = "mudBrickWallSection_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickBuildingResearch", {
        { 
            multiKeyBase = "firedBrick",
            multiCount = 2, 
            defaultModelName = "brickWallSection_sand",
            resourceTypeIndex = resource.types.firedBrick.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("stoneBlockBuildingResearch", {
        { 
            multiKeyBase = "stoneBlockAny",
            multiCount = 2, 
            defaultModelName = "stoneBlockWallSection",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tilingResearch", {
        { 
            multiKeyBase = "firedTile",
            multiCount = 2, 
            defaultModelName = "tileFloorSection2x1_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorSection2x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("woodBuildingResearch", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 4, 
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("craftSimple", {
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_2",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_3",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_4",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_5",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_6",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_7",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_8",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    


    modelPlaceholder:addModel("craftCrucible", {
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
        },
        {
            key = "resource_2",
        },
        {
            key = "resource_3",
        },
        {
            key = "resource_4",
        },
        {
            key = "resource_5",
        },
        {
            key = "resource_6",
        },
        {
            key = "resource_7",
        },
        {
            key = "resource_8",
        },
        {
            key = "tool",
        },
    })

    

    modelPlaceholder:addModel("craftSmith", {
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
        },
        {
            key = "resource_2",
        },
        {
            key = "resource_3",
        },
        {
            key = "resource_4",
        },
        {
            key = "resource_5",
        },
        {
            key = "resource_6",
        },
        {
            key = "resource_7",
        },
        {
            key = "resource_8",
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    --[[modelPlaceholder:addModel("craftSimpleAlpaca", {
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_2",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_3",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })]]

    modelPlaceholder:addModel("campfireRockCooking", {
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            multiKeyBase = "resource",
            multiCount = 1,
            additionalIndexCount = 4,
            defaultModelName = "flatbread",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("craftMudBrick", {
        {
            key = "clay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "clay_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "brickBinder_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "brickBinder_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneSpearBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "stoneSpearHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "stoneSpearHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("flintSpearBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "flintSpearHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flintSpearHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("boneSpearBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "boneSpearHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "boneSpearHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    modelPlaceholder:addModel("bronzeSpearBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "stoneSpearHead_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzeIngot.index,
        },
        {
            key = "stoneSpearHead_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzeIngot.index,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    },
    {
        bronzeSpearHead = "stoneSpearHead"
    })

    modelPlaceholder:addModel("stonePickaxeBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "stonePickaxeHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "stonePickaxeHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("flintPickaxeBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "flintPickaxeHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flintPickaxeHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("bronzePickaxeBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "stonePickaxeHead_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzePickaxeHead.index,
        },
        {
            key = "stonePickaxeHead_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzePickaxeHead.index,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    },
    {
        bronzePickaxeHead = "stonePickaxeHead"
    })

    modelPlaceholder:addModel("stoneHatchetBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "stoneAxeHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "stoneAxeHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("bronzeHatchetBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "stoneAxeHead_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzeAxeHead.index,
        },
        {
            key = "stoneAxeHead_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzeAxeHead.index,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    },
    {
        bronzeAxeHead = "stoneAxeHead"
    })

    modelPlaceholder:addModel("flintHatchetBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "flintAxeHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flintAxeHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneHammerBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "stoneHammerHead_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "stoneHammerHead_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    modelPlaceholder:addModel("bronzeHammerBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "stoneHammerHead_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzeHammerHead.index,
        },
        {
            key = "stoneHammerHead_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.bronzeHammerHead.index,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    },
    {
        bronzeHammerHead = "stoneHammerHead"
    })

    modelPlaceholder:addModel("balafonBuild", {
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "branch_2",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.branch.index,
        },
        {
            key = "pumpkin_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.pumpkin.index,
        },
        {
            key = "pumpkin_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.pumpkin.index,
        },
        {
            key = "pumpkin_2",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.pumpkin.index,
        },
        {
            key = "pumpkin_3",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.pumpkin.index,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_1",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("craftThreshing", {
        {
            key = "container_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceGroupIndex = resource.groups.container.index,
        },
        {
            key = "wheat_store",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.wheat.index,
        },
        {
            key = "container_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceGroupIndex = resource.groups.container.index,
        },
        {
            key = "wheat_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceTypeIndex = resource.types.wheat.index,
        },
    })


    modelPlaceholder:addModel("craftGrinding", {
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
            resourceGroupIndex = resource.groups.urnHulledWheat.index,
            --resourceTypeIndex = resource.types.unfiredUrnHulledWheat.index,
        },
    })
    


    modelPlaceholder:addModel("craftMedicine", {
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
            addModelFileYOffsetToWalkableHeight = true,
        },
        {
            key = "resource_2",
            offsetToStorageBoxWalkableHeight = true,
            addModelFileYOffsetToWalkableHeight = true,
        },
        {
            key = "resource_3",
            offsetToStorageBoxWalkableHeight = true,
            addModelFileYOffsetToWalkableHeight = true,
        },
        {
            key = "resource_4",
            offsetToStorageBoxWalkableHeight = true,
            addModelFileYOffsetToWalkableHeight = true,
        },
        --[[{
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_2",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_3",
            offsetToStorageBoxWalkableHeight = true,
        },]]
    })



    modelPlaceholder:addModel("plantingResearch", {
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "mound",
            offsetToWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("thatchWall", {
        { 
            multiKeyBase = "branch",
            multiCount = 5, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "hay",
            multiCount = 6, 
            defaultModelName = "thatchWide",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("thatchWallDoor", {
        { 
            multiKeyBase = "branch",
            multiCount = 4, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            indexOffset = 4,
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "hay",
            multiCount = 6, 
            defaultModelName = "thatchWide_075",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("thatchWallLargeWindow", {
        { 
            multiKeyBase = "branch",
            multiCount = 5, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            defaultModelName = "thatchSectionTall_100",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchSectionTall_100",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_5",
            defaultModelName = "thatchWideShorter",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_6",
            defaultModelName = "thatchWideShorter",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },

        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })



    modelPlaceholder:addModel("thatchWall4x1", {
        { 
            multiKeyBase = "branch",
            multiCount = 3, 
            defaultModelName = "branch",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "hay_1",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        { 
            key = "hay_2",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        { 
            key = "hay_3",
            additionalIndexCount = 1,
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        { 
            key = "hay_4",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("thatchWall2x2", {
        { 
            multiKeyBase = "branch",
            multiCount = 3, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "hay",
            multiCount = 3, 
            defaultModelName = "thatchWide",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    


    modelPlaceholder:addModel("thatchWall2x1", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branch",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "hay_1",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        { 
            key = "hay_2",
            defaultModelName = "thatchWideShort",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    

    modelPlaceholder:addModel("thatchRoof", {
        { 
            multiKeyBase = "branch",
            multiCount = 4, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "hay",
            multiCount = 8, 
            defaultModelName = "thatchWideTaller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    modelPlaceholder:addModel("thatchRoof_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "hay_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("thatchRoofSlope", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "hay",
            multiCount = 2, 
            additionalIndexCount = 1, 
            defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    


    modelPlaceholder:addModel("thatchRoofSlope_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofSlopeLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    modelPlaceholder:addModel("thatchRoofSmallCorner", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            additionalIndexCount = 1,
            defaultModelName = "thatchSmallCorner_1",
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchSmallCorner_1",
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            additionalIndexCount = 1,
            defaultModelName = "thatchSmallCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchSmallCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_5",
            additionalIndexCount = 3,
            defaultModelName = "thatchSmallCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_6",
            defaultModelName = "thatchSmallCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_7",
            defaultModelName = "thatchSmallCorner_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_8",
            defaultModelName = "thatchSmallCorner_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("thatchRoofSmallCorner_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofSmallCornerLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "hay_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofSmallCornerLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("thatchRoofSmallCornerInside", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            additionalIndexCount = 1,
            defaultModelName = "thatchSmallInnerCorner_4",
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchSmallInnerCorner_4",
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            additionalIndexCount = 1,
            defaultModelName = "thatchSmallInnerCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchSmallInnerCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_5",
            additionalIndexCount = 3,
            defaultModelName = "thatchSmallInnerCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_6",
            defaultModelName = "thatchSmallInnerCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_7",
            defaultModelName = "thatchSmallInnerCorner_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_8",
            defaultModelName = "thatchSmallInnerCorner_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    
    modelPlaceholder:addModel("thatchRoofSmallCornerInside_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofSmallCornerInsideLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "hay_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofSmallCornerInsideLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("thatchRoofTriangle", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            defaultModelName = "thatchTriangle_1",
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchTriangle_2",
            additionalIndexCount = 2,
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            defaultModelName = "thatchTriangle_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchTriangle_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("thatchRoofTriangle_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofTriangleLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("thatchRoofInvertedTriangle", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            defaultModelName = "thatchInvertedTriangle_1",
            additionalIndexCount = 2,
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchInvertedTriangle_2",
            --defaultModelName = "thatch2Taller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            defaultModelName = "thatchInvertedTriangle_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchInvertedTriangle_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    
    modelPlaceholder:addModel("thatchRoofInvertedTriangle_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofInvertedTriangleLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("thatchRoofLarge", {
        { 
            multiKeyBase = "branch",
            multiCount = 6, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "hay",
            multiCount = 8, 
            defaultModelName = "thatchWideTaller",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    
    modelPlaceholder:addModel("thatchRoofLarge_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLargeLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("thatchRoofLargeCorner", {
        { 
            multiKeyBase = "branch",
            multiCount = 9, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            defaultModelName = "thatchCorner_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchCorner_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            defaultModelName = "thatchCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_5",
            defaultModelName = "thatchCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_6",
            defaultModelName = "thatchCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_7",
            defaultModelName = "thatchCorner_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_8",
            defaultModelName = "thatchCorner_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_9",
            defaultModelName = "thatchCorner_5",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_10",
            defaultModelName = "thatchCorner_5",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_11",
            defaultModelName = "thatchCorner_6",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_12",
            defaultModelName = "thatchCorner_6",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_13",
            defaultModelName = "thatchCorner_7",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 3,
        },
        {
            key = "hay_14",
            defaultModelName = "thatchCorner_7",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_15",
            defaultModelName = "thatchCorner_8",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_16",
            defaultModelName = "thatchCorner_8",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("thatchRoofLargeCorner_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLargeCornerLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "hay_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLargeCornerLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("thatchRoofLargeCornerInside", {
        { 
            multiKeyBase = "branch",
            multiCount = 9, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            defaultModelName = "thatchInnerCorner_8",
            resourceTypeIndex = resource.types.hay.index,
            additionalIndexCount = 3,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_2",
            defaultModelName = "thatchInnerCorner_8",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_3",
            defaultModelName = "thatchInnerCorner_7",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_4",
            defaultModelName = "thatchInnerCorner_7",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_5",
            defaultModelName = "thatchInnerCorner_6",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_6",
            defaultModelName = "thatchInnerCorner_6",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_7",
            defaultModelName = "thatchInnerCorner_5",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_8",
            defaultModelName = "thatchInnerCorner_5",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_9",
            defaultModelName = "thatchInnerCorner_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_10",
            defaultModelName = "thatchInnerCorner_4",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_11",
            defaultModelName = "thatchInnerCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
            additionalIndexCount = 1,
        },
        {
            key = "hay_12",
            defaultModelName = "thatchInnerCorner_3",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_13",
            defaultModelName = "thatchInnerCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_14",
            defaultModelName = "thatchInnerCorner_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_15",
            defaultModelName = "thatchInnerCorner_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "hay_16",
            defaultModelName = "thatchInnerCorner_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelShouldOverrideResourceObject = true,
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("thatchRoofLargeCornerInside_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLargeCornerInsideLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "hay_2",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchRoofLargeCornerInsideLowContent",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("thatchRoofEnd", {
        { 
            multiKeyBase = "branch",
            multiCount = 2, 
            defaultModelName = "branchLong",
            resourceTypeIndex = resource.types.branch.index,
            hiddenOnBuildComplete = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "hay_1",
            defaultModelName = "thatchEndSegmentBottom",
            resourceTypeIndex = resource.types.hay.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "hay_2",
            defaultModelName = "thatchEndSegmentMiddle",
            resourceTypeIndex = resource.types.hay.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "hay_3",
            defaultModelName = "thatchEndSegmentTop",
            resourceTypeIndex = resource.types.hay.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })



    modelPlaceholder:addModel("thatchRoofEnd_low", {
        { 
            key = "hay_1",
            resourceTypeIndex = resource.types.hay.index,
            defaultModelName = "thatchEndLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogFloor1x1", {
        { 
            key = "splitLog_1",
            additionalIndexCount = 2, 
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index, 
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index, 
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index, 
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogFloor1x1_low", {
        { 
            key = "splitLog_1",
            resourceTypeIndex = resource.types.splitLog.index,
            defaultModelName = "splitLogFloor1x1FullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.splitLogFloor1x1FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogFloor2x2", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 3,
            additionalIndexCount = 1, 
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogFloor2x2_low", {
        { 
            key = "splitLog_1",
            resourceTypeIndex = resource.types.splitLog.index,
            defaultModelName = "splitLogFloor2x2FullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.splitLogFloor2x2FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogFloor4x4", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 12,
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogFloor4x4_low", {
        { 
            key = "splitLog_1",
            resourceTypeIndex = resource.types.splitLog.index,
            defaultModelName = "splitLogFloor4x4FullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.splitLogFloor4x4FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogFloorTri2", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogTriFloorSection1",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogTriFloorSection1Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogTriFloorSection2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogTriFloorSection2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    
    modelPlaceholder:addModel("splitLogFloorTri2_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogFloorTri2LowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogFloorTri2LowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogWall", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 6, 
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog",
            resourceTypeIndex = resource.types.log.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogWall4x1", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 3, 
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "log_1",
            additionalIndexCount = 1,
            defaultModelName = "birchLogHalf",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "log_2",
            defaultModelName = "birchLogHalf",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogWall2x2", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLog",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_6",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog",
            resourceTypeIndex = resource.types.log.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogWall2x1", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_2",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "log_1",
            additionalIndexCount = 1,
            defaultModelName = "birchLogHalf",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "log_2",
            defaultModelName = "birchLogHalf",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.halfLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    modelPlaceholder:addModel("splitLogWallDoor", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 5,
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog075",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog075Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_11",
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog",
            resourceTypeIndex = resource.types.log.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogWallLargeWindow", {
        {
            key = "splitLog_1",
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_2",
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_3",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_4",
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_5",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_6",
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_7",
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_8",
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog",
            resourceTypeIndex = resource.types.log.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogRoofEnd", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogLongAngleCut",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogAngleCutRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLog2x2GradAngleCut",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradAngleCutRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog2x1GradAngleCut",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x1GradAngleCutRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_4",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog075AngleCut",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog075AngleCutRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLog05AngleCut",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05AngleCutRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog3",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log3Remaps[objectTypeIndex], placeholderContext)
            end 
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogRoofEnd_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofEndLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofEndLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogSteps", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 2, 
            defaultModelName = "birchSplitLogLong",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_3",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_4",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_5",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_6",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_7",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_8",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_9",
            additionalIndexCount = 2,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_10",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_11",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("splitLogSteps2x2", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 2, 
            defaultModelName = "birchSplitLog2x1Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x1GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_3",
            additionalIndexCount = 2,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_4",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_5",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_6",
            additionalIndexCount = 2,
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_7",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_8",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })



    modelPlaceholder:addModel("splitLogRoof", {
        { 
            multiKeyBase = "log",
            multiCount = 5, 
            defaultModelName = "birchLog4",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log4Remaps[objectTypeIndex], placeholderContext)
            end 
        },
        { 
            multiKeyBase = "splitLog",
            multiCount = 10, 
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog2x2Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    

    modelPlaceholder:addModel("splitLogRoof_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogRoofLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogRoofSlope", {
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog4",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog2x2Grad",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLog2x2Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog2x2Grad",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLog2x2Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLog2x2Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x2GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogRoofSlope_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofSlopeLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofSlopeLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogRoofSmallCorner", {
        { 
            multiKeyBase = "log",
            multiCount = 3, 
            defaultModelName = "birchLog4",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogSingleAngleCutLeft1",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft1Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight1",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight1Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLogSingleAngleCutLeft2",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLogSingleAngleCutRight2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLogSingleAngleCutLeft3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_6",
            defaultModelName = "birchSplitLogSingleAngleCutRight3",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_7",
            defaultModelName = "birchSplitLogSingleAngleCutLeft4",
            additionalIndexCount = 3,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_8",
            defaultModelName = "birchSplitLogSingleAngleCutRight4",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_9",
            defaultModelName = "birchSplitLogSingleAngleCutLeft5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_10",
            defaultModelName = "birchSplitLogSingleAngleCutRight5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogRoofSmallCorner_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofSmallCornerLeftLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofSmallCornerLeftLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogRoofSmallCornerRightLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofSmallCornerRightLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogRoofSmallCornerInside", {
        { 
            multiKeyBase = "log",
            multiCount = 3, 
            defaultModelName = "birchLog4",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogSingleAngleCutLeft1",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft1Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight1",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight1Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLogSingleAngleCutLeft2",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLogSingleAngleCutRight2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLogSingleAngleCutLeft3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_6",
            defaultModelName = "birchSplitLogSingleAngleCutRight3",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_7",
            defaultModelName = "birchSplitLogSingleAngleCutLeft4",
            additionalIndexCount = 3,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_8",
            defaultModelName = "birchSplitLogSingleAngleCutRight4",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_9",
            defaultModelName = "birchSplitLogSingleAngleCutLeft5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_10",
            defaultModelName = "birchSplitLogSingleAngleCutRight5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogRoofSmallCornerInside_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofSmallCornerLeftLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofSmallCornerLeftLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogRoofSmallCornerRightLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofSmallCornerRightLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("splitLogRoofTriangle", {
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog4",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog2x1Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x1GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLogSingleAngleCutRight5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLogSingleAngleCutLeft3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLogSingleAngleCutLeft5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    
    modelPlaceholder:addModel("splitLogRoofTriangle_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofTriangleLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofTriangleLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogRoofInvertedTriangle", {
        { 
            multiKeyBase = "log",
            multiCount = 2, 
            defaultModelName = "birchLog4",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.log4Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog2x1Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x1GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLogSingleAngleCutRight5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLogSingleAngleCutLeft3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLogSingleAngleCutLeft5",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft5Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("splitLogRoofInvertedTriangle_low", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogRoofTriangleLowContent",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogRoofTriangleLowContentRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickWall", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 6, 
            defaultModelName = "mudBrickWallSection_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickWallDoor", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 5,
            defaultModelName = "mudBrickWallSection_075_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSection075Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_6",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection_075_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSection075Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_7",
            defaultModelName = "mudBrickWallSectionDoorTop_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallDoorTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickWallLargeWindow", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_2",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallColumn_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallColumnRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_4",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallColumn_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallColumnRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_5",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_6",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickWall_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionFullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickWallLargeWindow_low", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionWindowFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionWindowFullLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickRoofEnd", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 2, 
            defaultModelName = "mudBrickWallSectionRoofEnd1_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRoofEnd1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_3",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionRoofEnd2_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRoofEnd2Remaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickRoofEnd_low", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionRoofEndLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRoofEndLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickWallDoor_low", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionDoorFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionDoorFullLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickWall4x1_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection4x1FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSection4x1FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickWall2x2_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection2x2FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSection2x2FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickWall2x1_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection2x1FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSection2x1FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickWall4x1", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_2",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_4",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickWall2x2", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 3, 
            defaultModelName = "mudBrickWallSection_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickWall2x1", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_2",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickColumn", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickColumnBottom_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickColumnBottomRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_2",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickColumnTop_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickColumnTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickColumn_low", {
        {
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickColumnFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickColumnFullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickFloor1x1", {
        { 
            key = "mudBrickDry_1",
            defaultModelName = "mudBrickFloorSection1x1_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorSection1x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFloor2x2", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 2, 
            defaultModelName = "mudBrickFloorSection2x1_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorSection2x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFloor2x2_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickFloorSection2x2FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorSection2x2FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFloor4x4", {
        { 
            multiKeyBase = "mudBrickDry",
            multiCount = 8,
            defaultModelName = "mudBrickFloorSection2x1_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorSection2x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFloor4x4_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickFloorSection4x4FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorSection4x4FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("mudBrickFloorTri2", {
        { 
            key = "mudBrickDry_1",
            defaultModelName = "mudBrickFloorTriSection2_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorTriSection2Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFloorTri2_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickFloorTri2LowContent_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFloorTri2LowContentRemaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFoundation1x1", {
        { 
            key = "mudBrickDry_1",
            defaultModelName = "mudBrickFoundation1x1Content_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFoundation1x1ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFoundation1x1_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickFoundation1x1Content_low_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFoundation1x1ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFoundation2x2", {
        { 
            key = "mudBrickDry_1",
            defaultModelName = "mudBrickFoundation2x2Content_sand",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFoundation2x2ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("mudBrickFoundation2x2_low", {
        { 
            key = "mudBrickDry_1",
            resourceTypeIndex = resource.types.mudBrickDry.index,
            defaultModelName = "mudBrickFoundation2x2Content_low_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.mudBrickFoundation2x2ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "mudBrickDry_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWall", {
        { 
            multiKeyBase = "stoneBlockAny",
            multiCount = 6, 
            defaultModelName = "stoneBlockWallSection",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("stoneBlockWall_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionFullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionFullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWallDoor", {
        { 
            multiKeyBase = "stoneBlockAny",
            multiCount = 5,
            defaultModelName = "stoneBlockWallSection_075",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSection075Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_6",
            additionalIndexCount = 1,
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection_075",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSection075Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_7",
            defaultModelName = "stoneBlockWallSectionDoorTop",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallDoorTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWallDoor_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionDoorFullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionDoorFullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    

    modelPlaceholder:addModel("stoneBlockWallLargeWindow", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_2",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_3",
            additionalIndexCount = 1,
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallColumn",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallColumnRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_4",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallColumn",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallColumnRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_5",
            additionalIndexCount = 1,
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionSingleHigh",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_6",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionSingleHigh",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("stoneBlockWallLargeWindow_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionWindowFullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionWindowFullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("stoneBlockRoofEnd", {
        { 
            multiKeyBase = "stoneBlockAny",
            multiCount = 2, 
            defaultModelName = "stoneBlockWallSectionRoofEnd1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRoofEnd1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_3",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionRoofEnd2",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRoofEnd2Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockRoofEnd_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionRoofEndLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRoofEndLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWall4x1", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_2",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_3",
            additionalIndexCount = 1,
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionSingleHigh",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_4",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionSingleHigh",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWall4x1_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection4x1FullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSection4x1FullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    

    modelPlaceholder:addModel("stoneBlockWall2x2", {
        { 
            multiKeyBase = "stoneBlockAny",
            multiCount = 3, 
            defaultModelName = "stoneBlockWallSection",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWall2x2_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection2x2FullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSection2x2FullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    

    modelPlaceholder:addModel("stoneBlockWall2x1", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_2",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSectionSingleHigh",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockWall2x1_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockWallSection2x1FullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockWallSection2x1FullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockColumn", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockColumnBottom",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockColumnBottomRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_2",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockColumnTop",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockColumnTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("stoneBlockColumn_low", {
        {
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockColumnFullLow",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockColumnFullLowRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockFoundation1x1", {
        { 
            key = "stoneBlockAny_1",
            defaultModelName = "stoneBlockFoundation1x1Content",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockFoundation1x1ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockFoundation1x1_low", {
        { 
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockFoundation1x1Content_low",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockFoundation1x1ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockFoundation2x2", {
        { 
            key = "stoneBlockAny_1",
            defaultModelName = "stoneBlockFoundation2x2Content",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockFoundation2x2ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("stoneBlockFoundation2x2_low", {
        { 
            key = "stoneBlockAny_1",
            resourceGroupIndex = resource.groups.stoneBlockAny.index,
            defaultModelName = "stoneBlockFoundation2x2Content_low",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.stoneBlockFoundation2x2ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "stoneBlockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWall", {
        { 
            multiKeyBase = "firedBrick",
            multiCount = 6, 
            defaultModelName = "brickWallSection_sand",
            resourceTypeIndex = resource.types.firedBrick.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickWallDoor", {
        { 
            multiKeyBase = "firedBrick",
            multiCount = 5,
            defaultModelName = "brickWallSection_075_sand",
            resourceTypeIndex = resource.types.firedBrick.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSection075Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_6",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection_075_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSection075Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_7",
            defaultModelName = "brickWallSectionDoorTop_sand",
            resourceTypeIndex = resource.types.firedBrick.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallDoorTopRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWallLargeWindow", {
        {
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_2",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallColumn_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallColumnRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_4",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallColumn_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallColumnRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_5",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_6",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    modelPlaceholder:addModel("brickRoofEnd", {
        { 
            multiKeyBase = "firedBrick",
            multiCount = 2, 
            defaultModelName = "brickWallSectionRoofEnd1_sand",
            resourceTypeIndex = resource.types.firedBrick.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRoofEnd1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_3",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionRoofEnd2_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRoofEnd2Remaps[objectTypeIndex]
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("brickRoofEnd_low", {
        {
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionRoofEndLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRoofEndLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWall4x1", {
        {
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_2",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_3",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_4",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })



    modelPlaceholder:addModel("brickWall2x2", {
        { 
            multiKeyBase = "firedBrick",
            multiCount = 3, 
            defaultModelName = "brickWallSection_sand",
            resourceTypeIndex = resource.types.firedBrick.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickWall2x1", {
        {
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_2",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionSingleHigh_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionSingleHighRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWall_low", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionFullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWallLargeWindow_low", {
        {
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionWindowFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionWindowFullLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWallDoor_low", {
        {
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSectionDoorFullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSectionDoorFullLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("brickWall4x1_low", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection4x1FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSection4x1FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickWall2x2_low", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection2x2FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSection2x2FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickWall2x1_low", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickWallSection2x1FullLow_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickWallSection2x1FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickFoundation1x1", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickFoundation1x1Content_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickFoundation1x1ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickFoundation1x1_low", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickFoundation1x1Content_low_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickFoundation1x1ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickFoundation2x2", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickFoundation2x2Content_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickFoundation2x2ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("brickFoundation2x2_low", {
        { 
            key = "firedBrick_1",
            resourceTypeIndex = resource.types.firedBrick.index,
            defaultModelName = "brickFoundation2x2Content_low_sand",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.brickFoundation2x2ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "firedBrick_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tileFloor1x1", {
        { 
            key = "firedTile_1",
            defaultModelName = "tileFloorSection1x1_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorSection1x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tileFloor2x2", {
        { 
            multiKeyBase = "firedTile",
            multiCount = 2, 
            defaultModelName = "tileFloorSection2x1_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorSection2x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tileFloor2x2_low", {
        { 
            key = "firedTile_1",
            resourceTypeIndex = resource.types.firedTile.index,
            defaultModelName = "tileFloorSection2x2FullLow_firedTile",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorSection2x2FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tileFloor4x4", {
        { 
            multiKeyBase = "firedTile",
            multiCount = 8,
            defaultModelName = "tileFloorSection2x1_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorSection2x1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tileFloor4x4_low", {
        { 
            key = "firedTile_1",
            resourceTypeIndex = resource.types.firedTile.index,
            defaultModelName = "tileFloorSection4x4FullLow_firedTile",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorSection4x4FullLowRemaps[objectTypeIndex]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("tileFloorTri2", {
        { 
            key = "firedTile_1",
            resourceTypeIndex = resource.types.firedTile.index,
            defaultModelName = "tileFloorTriSection2_firedTile",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorTriSection2Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("tileFloorTri2_low", {
        { 
            key = "firedTile_1",
            resourceTypeIndex = resource.types.firedTile.index,
            defaultModelName = "tileFloorTri2LowContent_firedTile",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileFloorTri2LowContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("tileRoof", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 4, 
            defaultModelName = "birchSplitLog3",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog3Remaps[objectTypeIndex], placeholderContext)
            end 
        },
        { 
            key = "splitLog_5",
            resourceTypeIndex = resource.types.splitLog.index,
            defaultModelName = "birchSplitLogLong",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.longSplitLogRemaps[objectTypeIndex], placeholderContext)
            end 
        },
        { 
            multiKeyBase = "firedTile",
            multiCount = 8, 
            defaultModelName = "tileRoofSection4_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSection4Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("tileRoof_low", {
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofLowContent_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofLowContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "firedTile_2",
            defaultModelName = "tileRoofLowContent_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofLowContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("tileRoofSlope", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog3",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog3Remaps[objectTypeIndex], placeholderContext)
            end 
        },
        { 
            key = "splitLog_2",
            additionalIndexCount = 1,
            defaultModelName = "birchSplitLog3",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog3Remaps[objectTypeIndex], placeholderContext)
            end 
        },
        { 
            key = "splitLog_3",
            resourceTypeIndex = resource.types.splitLog.index,
            defaultModelName = "birchSplitLog",
        },
        { 
            multiKeyBase = "firedTile",
            multiCount = 2, 
            additionalIndexCount = 1,
            defaultModelName = "tileRoofSection2_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSection2Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("tileRoofSlope_low", {
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofSlopeLowContent_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSlopeLowContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("tileRoofSmallCorner", {
        { 
            multiKeyBase = "splitLog",
            multiCount = 3, 
            defaultModelName = "birchSplitLog3",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog3Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofSmallCornerSection1_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSmallCornerSection1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "firedTile_2",
            defaultModelName = "tileRoofSmallCornerSection2_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSmallCornerSection2Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("tileRoofSmallCorner_low", {
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofSmallCornerLowContent_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSmallCornerLowContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "firedTile_2",
            defaultModelName = "tileRoofSmallCornerLowContent_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSmallCornerLowContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    
    modelPlaceholder:addModel("tileRoofSmallCornerInside", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogSingleAngleCutLeft2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofSmallInnerCornerSection1_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSmallInnerCornerSection1Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        { 
            key = "firedTile_2",
            defaultModelName = "tileRoofSmallInnerCornerSection2_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofSmallInnerCornerSection2Remaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("tileRoofTriangle", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog2x1Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x1GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
       --[[ { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight2Remaps[objectTypeIndex], placeholderContext)
            end
        },]]
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofTriangleSection_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofTriangleSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("tileRoofInvertedTriangle", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog2x1Grad",
            resourceTypeIndex = resource.types.splitLog.index,
            additionalIndexCount = 1,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog2x1GradRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            resourceTypeIndex = resource.types.splitLog.index,
            defaultModelName = "birchSplitLog",
        },
        { 
            key = "firedTile_1",
            defaultModelName = "tileRoofInvertedTriangleSection_firedTile",
            resourceTypeIndex = resource.types.firedTile.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tileRoofInvertedTriangleSectionRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("appleTree", {
        { 
            multiKeyBase = "apple",
            multiCount = 6, 
            defaultModelName = "appleHangingFruit",
            resourceTypeIndex = resource.types.apple.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("appleTreeWinter", {
        { 
            multiKeyBase = "apple",
            multiCount = 6, 
            defaultModelName = "appleHangingFruitWinter",
            resourceTypeIndex = resource.types.apple.index,
            scale = 1.0,
        },
    })

    
    modelPlaceholder:addModel("elderberryTree", {
        { 
            multiKeyBase = "elderberry",
            multiCount = 6, 
            defaultModelName = "elderberryHangingFruit",
            resourceTypeIndex = resource.types.elderberry.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("elderberryTreeWinter", {
        { 
            multiKeyBase = "elderberry",
            multiCount = 6, 
            defaultModelName = "elderberryHangingFruitWinter",
            resourceTypeIndex = resource.types.elderberry.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("orangeTree", {
        { 
            multiKeyBase = "orange",
            multiCount = 10, 
            defaultModelName = "orangeHangingFruit",
            resourceTypeIndex = resource.types.orange.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("peachTree", {
        { 
            multiKeyBase = "peach",
            multiCount = 7, 
            defaultModelName = "peachHangingFruit",
            resourceTypeIndex = resource.types.peach.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("peachTreeWinter", {
        { 
            multiKeyBase = "peach",
            multiCount = 7, 
            defaultModelName = "peachHangingFruitWinter",
            resourceTypeIndex = resource.types.peach.index,
            scale = 1.0,
        },
    })


    modelPlaceholder:addModel("bananaTree", {
        { 
            multiKeyBase = "banana",
            multiCount = 3, 
            defaultModelName = "bananaHangingFruit",
            resourceTypeIndex = resource.types.banana.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("coconutTree", {
        { 
            multiKeyBase = "coconut",
            multiCount = 3, 
            defaultModelName = "coconutHangingFruit",
            resourceTypeIndex = resource.types.coconut.index,
            scale = 1.0,
        },
    })

    modelPlaceholder:addModel("raspberryBush", {
        { 
            multiKeyBase = "raspberry",
            multiCount = 6, 
            defaultModelName = "raspberryHangingFruit",
            resourceTypeIndex = resource.types.raspberry.index,
        },
    })

    modelPlaceholder:addModel("gooseberryBush", {
        { 
            multiKeyBase = "gooseberry",
            multiCount = 6, 
            defaultModelName = "gooseberryHangingFruit",
            resourceTypeIndex = resource.types.gooseberry.index,
        },
    })

    modelPlaceholder:addModel("pumpkinPlant", {
        { 
            multiKeyBase = "pumpkin",
            multiCount = 1, 
            defaultModelName = "pumpkinHangingFruit",
            resourceTypeIndex = resource.types.pumpkin.index,
        },
    })

    modelPlaceholder:addModel("wheatPlantCluster", {
        { 
            multiKeyBase = "wheatPlant",
            multiCount = 10, 
            defaultModelName = "wheatPlant",
            scale = 1.0,
            offsetToWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("wheatPlantSaplingCluster", {
        { 
            multiKeyBase = "wheatPlant",
            multiCount = 10, 
            defaultModelName = "wheatPlantSapling",
            scale = 1.0,
            offsetToWalkableHeight = true,
        },
        {
            key = "resource_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_1",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_2",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "resource_3",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("storageArea", {
        { 
            multiKeyBase = "peg",
            multiCount = 4, 
            defaultModelName = "storageAreaPeg",
            offsetToWalkableHeight = true,
        },
    })
    modelPlaceholder:addModel("storageArea1x1", {
        { 
            multiKeyBase = "peg",
            multiCount = 4, 
            defaultModelName = "storageAreaSmallPeg",
            offsetToWalkableHeight = true,
        },
    })
    modelPlaceholder:addModel("storageArea4x4", {
        { 
            multiKeyBase = "peg",
            multiCount = 4, 
            defaultModelName = "storageAreaLargePeg",
            offsetToWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("craftArea", {
        { 
            key = "rock_1",
            defaultModelName = "craftArea_rock1",
            resourceTypeIndex = resource.types.rock.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.craftAreaRockRemaps[objectTypeIndex]
            end
        },
    })
    
    modelPlaceholder:addModel("craftArea_low", {
        { 
            key = "rock_1",
            defaultModelName = "craftArea_rock1_low",
            resourceTypeIndex = resource.types.rock.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.craftAreaRockRemapsLow[objectTypeIndex]
            end
        },
    })

    modelPlaceholder:addModel("compostBin", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_5",
            defaultModelName = "birchSplitLog",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_6",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    

    modelPlaceholder:addModel("balafon", {
        { 
            key = "branch_1",
            defaultModelName = "balafon_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.balafonRemaps[objectTypeIndex], placeholderContext)
            end
        },
    })

    modelPlaceholder:addModel("logDrum", {
        { 
            key = "log_1",
            defaultModelName = "logDrum_birch",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.logDrumRemaps[objectTypeIndex], placeholderContext)
            end
        },
    })

    modelPlaceholder:addModel("stoneSpear", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPole_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.standardLengthPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        { 
            key = "stoneSpearHead_1",
            defaultModelName = "stoneSpearHead_rock1",
            resourceTypeIndex = resource.types.stoneSpearHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("flintSpear", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPole_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.standardLengthPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        { 
            key = "flintSpearHead_1",
            defaultModelName = "flintSpearHead",
            resourceTypeIndex = resource.types.flintSpearHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("boneSpear", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPole_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.standardLengthPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        { 
            key = "boneSpearHead_1",
            defaultModelName = "boneSpearHead",
            resourceTypeIndex = resource.types.boneSpearHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    
    modelPlaceholder:addModel("bronzeSpear", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPole_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.standardLengthPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        { 
            key = "stoneSpearHead_1",
            defaultModelName = "bronzeSpearHead",
            resourceTypeIndex = resource.types.bronzeSpearHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    },
    {
        bronzeSpearHead = "stoneSpearHead"
    })

    --[[
        
        { 
            key = "branch_1",
            defaultModelName = "woodenPole_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.standardLengthPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        { 
            key = "stoneSpearHead_1",
            defaultModelName = "stoneSpearHead_rock1",
            resourceTypeIndex = resource.types.stoneSpearHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    ]]

    modelPlaceholder:addModel("stonePickaxe", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "stonePickaxeHead_1",
            defaultModelName = "stonePickaxeHead_rock1",
            resourceTypeIndex = resource.types.stonePickaxeHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("flintPickaxe", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "flintPickaxeHead_1",
            defaultModelName = "flintPickaxeHead",
            resourceTypeIndex = resource.types.flintPickaxeHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("bronzePickaxe", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "stonePickaxeHead_1",
            defaultModelName = "bronzePickaxeHead",
            resourceTypeIndex = resource.types.bronzePickaxeHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    },
    {
        bronzePickaxeHead = "stonePickaxeHead"
    })

    modelPlaceholder:addModel("stoneHatchet", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "stoneAxeHead_1",
            defaultModelName = "stoneAxeHead_rock1",
            resourceTypeIndex = resource.types.stoneAxeHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("flintHatchet", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "flintAxeHead_1",
            defaultModelName = "flintAxeHead",
            resourceTypeIndex = resource.types.flintAxeHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })
    

    modelPlaceholder:addModel("bronzeHatchet", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "stoneAxeHead_1",
            defaultModelName = "bronzeAxeHead",
            resourceTypeIndex = resource.types.bronzeAxeHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    },
    {
        bronzeAxeHead = "stoneAxeHead"
    })

    modelPlaceholder:addModel("stoneHammer", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "stoneHammerHead_1",
            defaultModelName = "stoneHammerHead_rock1",
            resourceTypeIndex = resource.types.stoneHammerHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    })

    modelPlaceholder:addModel("bronzeHammer", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPoleShort_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "stoneHammerHead_1",
            defaultModelName = "bronzeHammerHead",
            resourceTypeIndex = resource.types.bronzeHammerHead.index,
        },
        { 
            key = "flaxTwine_1",
            defaultModelName = "flaxTwineBinding",
            resourceTypeIndex = resource.types.flaxTwine.index,
            defaultModelShouldOverrideResourceObject = true,
        },
    },
    {
        bronzeHammerHead = "stoneHammerHead"
    })

    modelPlaceholder:addModel("torch", {
        { 
            key = "branch_1",
            defaultModelName = "woodenPole_birch",
            resourceTypeIndex = resource.types.branch.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.standardLengthPoleBranchRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        { 
            key = "hay_1",
            defaultModelName = "hayTorch",
            resourceTypeIndex = resource.types.hay.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext and placeholderContext.buildComplete and (not placeholderContext.hasFuel) and modelPlaceholder.burntFuelRemaps[objectTypeIndex] then
                    return modelPlaceholder.burntFuelRemaps[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
                end
                return modelPlaceholder.hayTorchOverrides[model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]-- or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "branch_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "hay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("dirtFoundation1x1", {
        { 
            key = "dirt_1",
            defaultModelName = "dirtFoundation1x1Content",
            resourceTypeIndex = resource.types.dirt.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.dirtFoundation1x1ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "dirt_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("dirtFoundation1x1_low", {
        { 
            key = "dirt_1",
            resourceTypeIndex = resource.types.dirt.index,
            defaultModelName = "dirtFoundation1x1Content_low",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.dirtFoundation1x1ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "dirt_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("dirtFoundation2x2", {
        { 
            key = "dirt_1",
            defaultModelName = "dirtFoundation2x2Content",
            resourceTypeIndex = resource.types.dirt.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.dirtFoundation2x2ContentRemaps[objectTypeIndex] or placeholderInfo.defaultModelIndex
            end
        },
        {
            key = "dirt_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("dirtFoundation2x2_low", {
        { 
            key = "dirt_1",
            resourceTypeIndex = resource.types.dirt.index,
            defaultModelName = "dirtFoundation2x2Content_low",
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.dirtFoundation2x2ContentLowRemaps[objectTypeIndex]
            end
        },
        {
            key = "dirt_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("pathNode_rock", {
        { 
            key = "rockAny_1",
            defaultModelName = "pathNode_rock_1",
            resourceGroupIndex = resource.groups.rockAny.index,
            additionalIndexCount = 1,
            --defaultModelShouldOverrideResourceObject = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.rockPathRemaps_1[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
            end
        },
        { 
            key = "rockAny_2",
            defaultModelName = "pathNode_rock_2",
            resourceGroupIndex = resource.groups.rockAny.index,
            --defaultModelShouldOverrideResourceObject = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.rockPathRemaps_2[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
            end
        },
        {
            key = "rockAny_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("pathNode_dirt", {
        { 
            key = "dirt_1",
            defaultModelName = "pathNode_dirt_1",
            resourceTypeIndex = resource.types.dirt.index,
            --defaultModelShouldOverrideResourceObject = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.dirtPathRemaps_1[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
            end
        },
        {
            key = "dirt_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("pathNode_sand", {
        { 
            key = "sand_1",
            defaultModelName = "pathNode_sand_1",
            resourceTypeIndex = resource.types.sand.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.sandPathRemaps_1[objectTypeIndex]
            end
        },
        {
            key = "sand_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("pathNode_clay", {
        { 
            key = "clay_1",
            defaultModelName = "pathNode_clay_1",
            resourceTypeIndex = resource.types.clay.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.clayPathRemaps_1[objectTypeIndex]
            end
        },
        {
            key = "clay_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })


    modelPlaceholder:addModel("pathNode_firedTile", {
        { 
            key = "firedTile_1",
            defaultModelName = "pathNode_firedTile_1",
            additionalIndexCount = 1,
            resourceTypeIndex = resource.types.firedTile.index,
            --defaultModelShouldOverrideResourceObject = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tilePathRemaps_1[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
            end
        },
        { 
            key = "firedTile_2",
            defaultModelName = "pathNode_firedTile_2",
            resourceTypeIndex = resource.types.firedTile.index,
            --defaultModelShouldOverrideResourceObject = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder.tilePathRemaps_2[objectTypeIndex][model:modelLevelForSubdivLevel(placeholderContext.subdivLevel)]
            end
        },
        {
            key = "firedTile_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "tool",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    modelPlaceholder:addModel("splitLogBench", {
        { 
            key = "log_1",
            defaultModelName = "birchLogShort",
            resourceTypeIndex = resource.types.log.index,
            additionalIndexCount = 1,
            --offsetToWalkableHeight = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "log_2",
            defaultModelName = "birchLogShort",
            resourceTypeIndex = resource.types.log.index,
            --offsetToWalkableHeight = true,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.shortLogRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
            --offsetToWalkableHeight = true,
            --rotateToWalkableRotation = true,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    
    modelPlaceholder:addModel("splitLogShelf", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
            additionalIndexCount = 2,
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutLeftSmallShelf",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                local splitLogSingleCutLeftSmallShelfRemaps = modelPlaceholder.splitLogSingleCutLeftSmallShelfRemapsByStatus[(placeholderContext and placeholderContext.storageStatusKey) or "allowAll"]
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, splitLogSingleCutLeftSmallShelfRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLogSingleAngleCutLeftSmallShelf",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                local splitLogSingleCutLeftSmallShelfRemaps = modelPlaceholder.splitLogSingleCutLeftSmallShelfRemapsByStatus[(placeholderContext and placeholderContext.storageStatusKey) or "allowAll"]
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, splitLogSingleCutLeftSmallShelfRemaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })
    

    
    modelPlaceholder:addModel("splitLogToolRack", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogNotchedRack",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                local splitLogNotchedRackRemaps = modelPlaceholder.splitLogNotchedRackRemapsByStatus[(placeholderContext and placeholderContext.storageStatusKey) or "allowAll"]
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, splitLogNotchedRackRemaps[objectTypeIndex], placeholderContext)
            end,
        },
        {
            key = "splitLog_2",
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_3",
            defaultModelName = "birchSplitLog05",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLog05Remaps[objectTypeIndex], placeholderContext)
            end
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
    })

    

    
    modelPlaceholder:addModel("sled", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogSingleAngleCutLeft2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "flaxTwine_1",
            --defaultModelName = "flaxTwine",
            resourceTypeIndex = resource.types.flaxTwine.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        { 
            multiKeyBase = "peg",
            multiCount = 2, 
            defaultModelName = "storageAreaSmallPeg",
        },
    })

    
    modelPlaceholder:addModel("coveredSled", {
        { 
            key = "splitLog_1",
            defaultModelName = "birchSplitLogSingleAngleCutLeft2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutLeft2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_2",
            defaultModelName = "birchSplitLogSingleAngleCutRight2",
            resourceTypeIndex = resource.types.splitLog.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.splitLogSingleCutRight2Remaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "splitLog_3",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "splitLog_4",
            defaultModelName = "birchSplitLog",
            resourceTypeIndex = resource.types.splitLog.index,
        },
        { 
            key = "woolskin_1",
            defaultModelName = "coveredSledEmptyWoolskin",
            resourceTypeIndex = resource.types.woolskin.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext.contentsHalfFull or placeholderContext.contentsFull then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.coveredSledEmptyWoolskinRemaps[objectTypeIndex], placeholderContext)
            end

        },
        { 
            key = "woolskin_2",
            resourceTypeIndex = resource.types.woolskin.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext.contentsFull then
                    return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.coveredSledFullWoolskinRemaps[objectTypeIndex], placeholderContext)
                elseif placeholderContext.contentsHalfFull then
                    return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.coveredSledHalfFullWoolskinRemaps[objectTypeIndex], placeholderContext)
                end
                return nil
            end
        },
        { 
            key = "woolskin_3",
            resourceTypeIndex = resource.types.woolskin.index,
            hiddenOnBuildComplete = true,
        },
        { 
            key = "flaxTwine_1",
            --defaultModelName = "flaxTwine",
            resourceTypeIndex = resource.types.flaxTwine.index,
        },
        {
            key = "splitLog_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "woolskin_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        { 
            multiKeyBase = "peg",
            multiCount = 2, 
            defaultModelName = "storageAreaSmallPeg",
        },
    })

    modelPlaceholder:addModel("canoe", {
        { 
            key = "log_1",
            defaultModelName = "canoe",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                local canoeRemaps = modelPlaceholder.canoeRemapsByStatus[(placeholderContext and placeholderContext.storageStatusKey) or "allowAll"]
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, canoeRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "flaxTwine_1",
            --defaultModelName = "flaxTwine",
            resourceTypeIndex = resource.types.flaxTwine.index,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "seatNode_1",
        },
    })
    
    modelPlaceholder:addModel("coveredCanoe", {
        { 
            key = "log_1",
            defaultModelName = "canoe",
            resourceTypeIndex = resource.types.log.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                local canoeRemaps = modelPlaceholder.canoeRemapsByStatus[(placeholderContext and placeholderContext.storageStatusKey) or "allowAll"]
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, canoeRemaps[objectTypeIndex], placeholderContext)
            end
        },
        { 
            key = "woolskin_1",
            defaultModelName = "coveredCanoeEmptyWoolskin",
            resourceTypeIndex = resource.types.woolskin.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext.contentsHalfFull or placeholderContext.contentsFull then
                    return nil
                end
                return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.coveredCanoeEmptyWoolskinRemaps[objectTypeIndex], placeholderContext)
            end

        },
        { 
            key = "woolskin_2",
            resourceTypeIndex = resource.types.woolskin.index,
            placeholderModelIndexForObjectTypeFunction = function(placeholderInfo, objectTypeIndex, placeholderContext)
                if placeholderContext.contentsFull then
                    return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.coveredCanoeFullWoolskinRemaps[objectTypeIndex], placeholderContext)
                elseif placeholderContext.contentsHalfFull then
                    return modelPlaceholder:getModelIndexForStandardRemaps(placeholderInfo, modelPlaceholder.coveredCanoeHalfFullWoolskinRemaps[objectTypeIndex], placeholderContext)
                end
                return nil
            end
        },
        { 
            key = "woolskin_3",
            resourceTypeIndex = resource.types.woolskin.index,
            hiddenOnBuildComplete = true,
        },
        { 
            key = "flaxTwine_1",
            --defaultModelName = "flaxTwine",
            resourceTypeIndex = resource.types.flaxTwine.index,
        },
        {
            key = "log_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "woolskin_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "flaxTwine_store",
            offsetToStorageBoxWalkableHeight = true,
        },
        {
            key = "seatNode_1",
        },
    })



end

function modelPlaceholder:init(gameObject_)
    --mj:log("modelPlaceholder init")
    gameObject = gameObject_
    modelPlaceholder:initRemaps()
    modelPlaceholder:addModels()
    
    local cloneParentsByClone = model.clones
    for cloneIndex,parentIndex in pairs(cloneParentsByClone) do
        modelPlaceholder:addCloneIndex(parentIndex, cloneIndex)
    end
end


function modelPlaceholder:mjInit() --initialization has been moved to init to avoid a circular loop requiring gameObject
end


return modelPlaceholder