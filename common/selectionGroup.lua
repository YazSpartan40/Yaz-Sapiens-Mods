local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local selectionGroup = {
}

function selectionGroup:addGroup(key, readableName, plural, descriptivePluralOrNil)
    if selectionGroup.types[key] then
        mj:error("Attempt to overwrite selectionGroup type:", key)
        return selectionGroup.types[key].index
    end

    typeMaps:insert("selectionGroup", selectionGroup.types, {
        key = key,
        readableName = readableName,
        plural = plural,
        descriptivePlural = descriptivePluralOrNil or plural,
        objectTypeIndexes = {}
    })

    return selectionGroup.types[key].index

end

function selectionGroup:addObjectTypeToGroups(objectTypeIndex, selectionGroupTypeIndexes)
    for i,groupTypeIndex in ipairs(selectionGroupTypeIndexes) do
        local selectionGroupType = selectionGroup.types[groupTypeIndex]
        if not selectionGroupType.objectTypeIndexes then
            selectionGroupType.objectTypeIndexes = {}
        end
        local found = false
        for j, existingObjectTypeIndex in ipairs(selectionGroupType.objectTypeIndexes) do
            if existingObjectTypeIndex == objectTypeIndex then
                found = true
                break
            end
        end
        if not found then
            table.insert(selectionGroupType.objectTypeIndexes, objectTypeIndex)
        end
    end
end

function selectionGroup:addMobVariants(gameObject, mob)
	for i,mobType in ipairs(mob.validTypes) do
		--table.insert(mob.gameObjectIndexes, mobType.gameObjectTypeIndex)
		
		if mobType.variants then
            local selectionGroupIndex = selectionGroup:addGroup(mobType.key, mobType.name, mobType.plural, nil)
            local baseGameObjectType = gameObject.types[mobType.gameObjectTypeIndex]
            baseGameObjectType.additionalSelectionGroupTypeIndexes = baseGameObjectType.additionalSelectionGroupTypeIndexes or {}
            table.insert(baseGameObjectType.additionalSelectionGroupTypeIndexes, selectionGroupIndex)

            selectionGroup:addObjectTypeToGroups(mobType.gameObjectTypeIndex, {
                selectionGroupIndex
            })
			for k,variantInfo in ipairs(mobType.variants) do
                local variantGameObjectType = gameObject.types[variantInfo.gameObjectTypeIndex]
                variantGameObjectType.additionalSelectionGroupTypeIndexes = variantGameObjectType.additionalSelectionGroupTypeIndexes or {}
                table.insert(variantGameObjectType.additionalSelectionGroupTypeIndexes, selectionGroupIndex)
                selectionGroup:addObjectTypeToGroups(variantInfo.gameObjectTypeIndex, {
                    selectionGroupIndex
                })
            end
        end
    end
end

function selectionGroup:getGroupObjectTypesForSelectionGroupIndex(selectionGroupTypeIndex)
    local selectionGroupType = selectionGroup.types[selectionGroupTypeIndex]
    return selectionGroupType.objectTypeIndexes or {}
end

selectionGroup.types = typeMaps:createMap("selectionGroup", {
    {
        key = "allSleds",
        readableName = locale:get("selectionGroup_sled_objectName"),
        plural = locale:get("selectionGroup_sled_plural"),
        descriptivePlural = locale:get("selectionGroup_sled_descriptive"),
    },
    {
        key = "allCanoes",
        readableName = locale:get("selectionGroup_canoe_objectName"),
        plural = locale:get("selectionGroup_canoe_plural"),
        descriptivePlural = locale:get("selectionGroup_canoe_descriptive"),
    },
    {
        key = "allPineTrees",
        readableName = locale:get("flora_pine"),
        plural = locale:get("flora_pine_plural"),
        descriptivePlural = locale:get("flora_pine_plural"),
    },
    {
        key = "allBirchTrees",
        readableName = locale:get("flora_birch"),
        plural = locale:get("flora_birch_plural"),
        descriptivePlural = locale:get("flora_birch_plural"),
    },
    {
        key = "allAspenTrees",
        readableName = locale:get("flora_aspen"),
        plural = locale:get("flora_aspen_plural"),
        descriptivePlural = locale:get("flora_aspen_plural"),
    },
    {
        key = "allWillowTrees",
        readableName = locale:get("flora_willow"),
        plural = locale:get("flora_willow_plural"),
        descriptivePlural = locale:get("flora_willow_plural"),
    },
    {
        key = "allBambooTrees",
        readableName = locale:get("flora_bamboo"),
        plural = locale:get("flora_bamboo_plural"),
        descriptivePlural = locale:get("flora_bamboo_plural"),
    },
})
	
selectionGroup:addGroup("allBranches", locale:get("selectionGroup_branch_objectName"), locale:get("selectionGroup_branch_plural"), locale:get("selectionGroup_branch_descriptive"))
selectionGroup:addGroup("allLogs", locale:get("selectionGroup_log_objectName"), locale:get("selectionGroup_log_plural"), locale:get("selectionGroup_log_descriptive"))

selectionGroup:addGroup("allPlants", locale:get("selectionGroup_plant_objectName"), locale:get("selectionGroup_plant_plural"), locale:get("selectionGroup_plant_descriptive"))
selectionGroup:addGroup("allTrees", locale:get("selectionGroup_tree_objectName"), locale:get("selectionGroup_tree_plural"), locale:get("selectionGroup_tree_descriptive"))

selectionGroup:addGroup("allRocks", locale:get("selectionGroup_rock_objectName"), locale:get("selectionGroup_rock_plural"), locale:get("selectionGroup_rock_descriptive"))
selectionGroup:addGroup("allSmallRocks", locale:get("selectionGroup_smallRock_objectName"), locale:get("selectionGroup_smallRock_plural"), locale:get("selectionGroup_smallRock_descriptive"))
selectionGroup:addGroup("allRockBlocks", locale:get("selectionGroup_stoneBlock_objectName"), locale:get("selectionGroup_stoneBlock_plural"), locale:get("selectionGroup_stoneBlock_descriptive"))

return selectionGroup