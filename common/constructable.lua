local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

local typeMaps = mjrequire "common/typeMaps"
local model = mjrequire "common/model"
local resource = mjrequire "common/resource"
local skill = mjrequire "common/skill"
local locale = mjrequire "common/locale"

local gameObject = nil

local constructable = {
    types = {},
    validTypes = {},
    orderedPlaceTypeIndexesForDisplayInPlaceUI = {},
    variations = {}
}

local typeIndexMap = typeMaps.types.constructable

constructable.sequenceTypes = typeMaps:createMap("constructableSequence", {
    {
        key = "clearObjects",
        optionalFallbackSkill = skill.types.gathering.index,
        skipOnDestruction = true,
    },
    {
        key = "clearTerrain",
        optionalFallbackSkill = skill.types.gathering.index,
        skipOnDestruction = true,
    },
    {
        key = "actionSequence",
        skipOnDestruction = true,
    },
    {
        key = "clearIncorrectResources",
        optionalFallbackSkill = skill.types.gathering.index,
    },
    {
        key = "bringResources",
        optionalFallbackSkill = skill.types.gathering.index,
    },
    {
        key = "bringTools",
        --optionalFallbackSkill = skill.types.gathering.index,
    },
    {
        key = "moveComponents",
    },
})

constructable.classifications = typeMaps:createMap("constructableClassification", {
    {
        key = "build",
        name = locale:get("constructable_classification_build"),
        actionName = locale:get("constructable_classification_build_action"),
        icon = "icon_hammer",
    },
    {
        key = "plant",
        name = locale:get("constructable_classification_plant"),
        actionName = locale:get("constructable_classification_plant_action"),
        icon = "icon_plant",
    },
    {
        key = "craft",
        name = locale:get("constructable_classification_craft"),
        actionName = locale:get("constructable_classification_craft_action"),
        icon = "icon_craft",
        disallowClonePlan = true,
    },
    {
        key = "path",
        name = locale:get("constructable_classification_path"),
        actionName = locale:get("constructable_classification_path_action"),
        icon = "icon_path",
    },
    {
        key = "place",
        name = locale:get("constructable_classification_place"),
        actionName = locale:get("constructable_classification_place_action"),
        icon = "icon_hand",
    },
    {
        key = "fill",
        name = locale:get("constructable_classification_fill"),
        actionName = locale:get("constructable_classification_fill_action"),
        icon = "icon_hand",
    },
    {
        key = "research",
        name = locale:get("constructable_classification_research"),
        actionName = locale:get("constructable_classification_research_action"),
        icon = "icon_idea",
        disallowClonePlan = true,
    },
    {
        key = "fertilize",
        name = locale:get("constructable_classification_fertilize"),
        actionName = locale:get("constructable_classification_fertilize_action"),
        icon = "icon_mulch",
    },
})

constructable.rebuildGroups = typeMaps:createMap("constructableRebuildGroups", {
    {
        key = "bed",
    },
    {
        key = "roof",
    },
    {
        key = "roofSlope",
    },
    {
        key = "roofSmallCorner",
    },
    {
        key = "roofSmallCornerInside",
    },
    {
        key = "roofTriangle",
    },
    {
        key = "roofInvertedTriangle",
    },
    {
        key = "roofLarge",
    },
    {
        key = "roofLargeCorner",
    },
    {
        key = "roofLargeCornerInside",
    },
    {
        key = "wall4x2",
    },
    {
        key = "wallRoofEnd",
    },
    {
        key = "wall4x1",
    },
    {
        key = "wall2x2",
    },
    {
        key = "wall2x1",
    },
    {
        key = "floor1x1",
    },
    {
        key = "floor2x2",
    },
    {
        key = "floor4x4",
    },
    {
        key = "floorTri2",
    },
    {
        key = "bench",
    },
    {
        key = "steps",
    },
    {
        key = "steps2x2",
    },
    {
        key = "column",
    },
    {
        key = "path",
    },
    {
        key = "compostBin",
    },
    {
        key = "craftArea",
    },
    {
        key = "campfire",
    },
    {
        key = "kiln",
    },
    {
        key = "torch",
    },
    {
        key = "shelf",
    },
    {
        key = "toolRack",
    },
    {
        key = "sled",
    },
    {
        key = "canoe",
    },
    {
        key = "foundation1x1",
    },
    {
        key = "foundation2x2",
    },
})

function constructable:addConstructable(key, info)
	local index = typeIndexMap[key]
    if constructable.types[key] then
        mj:log("WARNING: overwriting constructable type:", key)
    end

    info.key = key
    info.index = index
    constructable.types[key] = info
    constructable.types[index] = info

    if info.isPlaceType and (not info.disallowsDecorationPlacing) then
        table.insert(constructable.orderedPlaceTypeIndexesForDisplayInPlaceUI, info.index)
    end

    if not info.classification then
        mj:error("Missing constructable classification for added constructable:", key)
    end

    if info.addGameObjectInfo then
        if not info.iconGameObjectType then
            info.iconGameObjectType = gameObject.typeIndexMap[key]
            if not info.iconGameObjectType then
                mj:error("addCraftable: not gameObject for:", key)
            end
        end

        local addGameObjectInfo = info.addGameObjectInfo
        
        if addGameObjectInfo.finalObjectInfosByResourceObjectType then
            for resourceObjectType,finalObjectInfo in pairs(addGameObjectInfo.finalObjectInfosByResourceObjectType) do
                local nameKey = "object_" .. finalObjectInfo.key
                local pluralKey = nameKey .. "_plural"
                local name = locale:get(nameKey) or ""
                local plural = locale:get(pluralKey) or ""

                local objectTypeIndex = gameObject:addGameObject( finalObjectInfo.key, {
                    name = name,
                    plural = plural,
                    modelName = finalObjectInfo.modelName,
                    scale = 1.0,
                    hasPhysics = true,
                    resourceTypeIndex = addGameObjectInfo.resourceTypeIndex,
                    pathFindingDifficulty = addGameObjectInfo.pathFindingDifficulty,
                    toolUsages = addGameObjectInfo.toolUsages,
                    isBuiltObject = addGameObjectInfo.isBuiltObject,
                    preservesConstructionObjects = addGameObjectInfo.preservesConstructionObjects,
                    femaleSnapPoints = addGameObjectInfo.femaleSnapPoints,
                    isMusicalInstrument = addGameObjectInfo.isMusicalInstrument,
                    seatTypeIndex = addGameObjectInfo.seatTypeIndex,
                    markerPositions = {
                        { 
                            worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                        }
                    },
                })

                finalObjectInfo.objectTypeIndex = objectTypeIndex
            end
        else
            gameObject:addGameObject( key, {
                name = info.name,
                plural = info.plural,
                modelName = addGameObjectInfo.modelName,
                scale = 1.0,
                hasPhysics = true,
                resourceTypeIndex = addGameObjectInfo.resourceTypeIndex,
                pathFindingDifficulty = addGameObjectInfo.pathFindingDifficulty,
                toolUsages = addGameObjectInfo.toolUsages,
                isBuiltObject = addGameObjectInfo.isBuiltObject,
                preservesConstructionObjects = addGameObjectInfo.preservesConstructionObjects,
                femaleSnapPoints = addGameObjectInfo.femaleSnapPoints,
                isMusicalInstrument = addGameObjectInfo.isMusicalInstrument,
                seatTypeIndex = addGameObjectInfo.seatTypeIndex,
                markerPositions = addGameObjectInfo.markerPositions or {
                    { 
                        worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                    }
                },
            })
        end
    end

    info.addGameObjectInfo = nil

	return index
end

function constructable:load(gameObject_)
    gameObject = gameObject_

    
end

function constructable:finalize()
    
    constructable.validTypes = typeMaps:createValidTypesArray("constructable", constructable.types)

    constructable.typesByRebuildGroup = {}
    
    for i,constructableType in ipairs(constructable.validTypes) do
        if constructableType.modelName then
            constructableType.modelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.modelName, 1)
        end

        if constructableType.rebuildGroupIndex then
            if not constructable.typesByRebuildGroup[constructableType.rebuildGroupIndex] then
                constructable.typesByRebuildGroup[constructableType.rebuildGroupIndex] = {}
            end
            table.insert(constructable.typesByRebuildGroup[constructableType.rebuildGroupIndex], constructableType.index)
        end
    
        if constructableType.requiredResources then
            constructableType.requiredResourceTotalCount = 0
            constructableType.requiredResourceCountsByResourceGroupOrType = {}
            for j,resourceInfo in ipairs(constructableType.requiredResources) do
                constructableType.requiredResourceTotalCount = constructableType.requiredResourceTotalCount + resourceInfo.count
                local groupOrTypeIndex = resourceInfo.type or resourceInfo.group
                if not constructableType.requiredResourceCountsByResourceGroupOrType[groupOrTypeIndex] then
                    constructableType.requiredResourceCountsByResourceGroupOrType[groupOrTypeIndex] = resourceInfo.count
                else
                    constructableType.requiredResourceCountsByResourceGroupOrType[groupOrTypeIndex] = constructableType.requiredResourceCountsByResourceGroupOrType[groupOrTypeIndex] + resourceInfo.count
                end
            end
        else
            constructableType.requiredResourceTotalCount = 0
        end

        if constructableType.variations then
            if constructableType.variations[1] ~= constructableType.index then
                table.insert(constructableType.variations, 1, constructableType.index)
            end
            constructable:addVariations(constructableType.variations)
        end
    end

    local function sortPlaceType(a,b)
        return constructable.types[a].name < constructable.types[b].name
    end

    table.sort(constructable.orderedPlaceTypeIndexesForDisplayInPlaceUI, sortPlaceType)

    --mj:log("constructable:finalize complete")
end

function constructable:createGameObjectTypeIndexMap(gameObjectTypeIndexesByResourceTypeIndex) -- gameObjectTypeIndexesByResourceTypeIndex isn't ready when finalize is called above
    local constructablesByResourceObjectTypeIndexes = {}
    
    for i,constructableType in ipairs(constructable.validTypes) do
    
        if constructableType.requiredResources and (not constructableType.disallowsDecorationPlacing) then
            for j,resourceInfo in ipairs(constructableType.requiredResources) do
                local function addConstructableForResourceType(resourceTypeIndex, requiredObjectTypeIndex)
                    local gameObjectsTypesForResource = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
                    for k,gameObjectTypeIndex in ipairs(gameObjectsTypesForResource) do
                        if (not requiredObjectTypeIndex) or (requiredObjectTypeIndex == gameObjectTypeIndex) then
                            if not constructablesByResourceObjectTypeIndexes[gameObjectTypeIndex] then
                                constructablesByResourceObjectTypeIndexes[gameObjectTypeIndex] = {}
                            end
                            table.insert(constructablesByResourceObjectTypeIndexes[gameObjectTypeIndex], constructableType.index)
                        end
                    end
                end
                if resourceInfo.type then
                    addConstructableForResourceType(resourceInfo.type, resourceInfo.objectTypeIndex)
                else
                    for k, resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                        addConstructableForResourceType(resourceTypeIndex, nil)
                    end
                end
            end
        else
            constructableType.requiredResourceTotalCount = 0
        end
    end

    constructable.constructablesByResourceObjectTypeIndexes = constructablesByResourceObjectTypeIndexes
end

function constructable:addVariations(constructableTypeIndexes)
    local baseConstructableTypeIndex = constructableTypeIndexes[1]
    constructable.variations[baseConstructableTypeIndex] = constructableTypeIndexes

    for i, constructableTypeIndex in ipairs(constructableTypeIndexes) do
        if i ~= 1 then
            constructable.types[constructableTypeIndex].isVariationOfConstructableTypeIndex = baseConstructableTypeIndex
        end
    end
end

function constructable:getConstructableTypeIndexForCloneOrRebuild(objectInfo)
    local constructableTypeIndexToUse = nil
    local sharedState = objectInfo.sharedState
    if sharedState then
        if sharedState.constructionConstructableTypeIndex then
            constructableTypeIndexToUse = sharedState.constructionConstructableTypeIndex
        elseif sharedState.inProgressConstructableTypeIndex then
            constructableTypeIndexToUse = sharedState.inProgressConstructableTypeIndex
        end
        
        local constructableType = constructable.types[constructableTypeIndexToUse]
        if (not constructableType) or constructable.classifications[constructableType.classification].disallowClonePlan then
            constructableTypeIndexToUse = nil
        end
    end

    local baseObjectType = gameObject.types[objectInfo.objectTypeIndex]

    if not constructableTypeIndexToUse then
        if baseObjectType.placeBaseObjectTypeIndex then
            local placeBaseObjectType = gameObject.types[baseObjectType.placeBaseObjectTypeIndex]
            local placeBaseResourceType = resource.types[placeBaseObjectType.resourceTypeIndex]
            local placeTypeName = "place_" .. placeBaseResourceType.key
            if constructable.types[placeTypeName] then
                constructableTypeIndexToUse = constructable.types[placeTypeName].index
            end
        end
    end

    if not constructableTypeIndexToUse then
        local plantKey = "plant_" .. baseObjectType.key
        if constructable.types[plantKey] then
            constructableTypeIndexToUse = constructable.types[plantKey].index
        end
    end
    
    if not constructableTypeIndexToUse and baseObjectType.resourceTypeIndex then
        local placeBaseResourceType = resource.types[baseObjectType.resourceTypeIndex]
        local placeTypeName = "place_" .. placeBaseResourceType.key
        if constructable.types[placeTypeName] then
            constructableTypeIndexToUse = constructable.types[placeTypeName].index
        end
    end

    return constructableTypeIndexToUse
end


local objectTypeFunctionsByClassification = {}

local function getDefaultIconType(constructableType)
    if not constructableType.iconGameObjectType then
        return gameObject.types[constructableType.inProgressGameObjectTypeKey].index
    end
    return constructableType.iconGameObjectType
end

objectTypeFunctionsByClassification[constructable.classifications.craft.index] = function(constructableType, objectTypesBlackListOrNil, objectTypesWhiteListOrNil)
    local outputObjectInfo = constructableType.outputObjectInfo
    if outputObjectInfo then
        local outputArraysByResourceObjectType = outputObjectInfo.outputArraysByResourceObjectType
        if outputArraysByResourceObjectType then
            local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(constructableType.requiredResources[1], objectTypesBlackListOrNil, objectTypesWhiteListOrNil)
            if availableObjectTypeIndexes then
                for i,objectTypeIndex in ipairs(availableObjectTypeIndexes) do
                    if (not objectTypesBlackListOrNil) or (not objectTypesBlackListOrNil[objectTypeIndex]) then
                        if (not objectTypesWhiteListOrNil) or (objectTypesWhiteListOrNil[objectTypeIndex]) then
                            local outputArray = outputArraysByResourceObjectType[objectTypeIndex]
                            if outputArray then
                                return outputArray[1]
                            end
                        end
                    end
                end
            end
        end
    end

    return getDefaultIconType(constructableType)
end

objectTypeFunctionsByClassification[constructable.classifications.place.index] = function(constructableType, objectTypesBlackListOrNil, objectTypesWhiteListOrNil)
    local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(constructableType.requiredResources[1], objectTypesBlackListOrNil, objectTypesWhiteListOrNil)
    if availableObjectTypeIndexes then
        return availableObjectTypeIndexes[1]
    end
    return getDefaultIconType(constructableType)
end

function constructable:getDisplayGameObjectType(constructableTypeIndex, objectTypesBlackListOrNil, objectTypesWhiteListOrNil)
    local constructableType = constructable.types[constructableTypeIndex]

    local classificationFunction = objectTypeFunctionsByClassification[constructableType.classification]
    if classificationFunction then
        
        if (not objectTypesBlackListOrNil) and (not objectTypesWhiteListOrNil) then
            return getDefaultIconType(constructableType)
        end
        return classificationFunction(constructableType, objectTypesBlackListOrNil, objectTypesWhiteListOrNil)
    end

   return getDefaultIconType(constructableType)
end

return constructable