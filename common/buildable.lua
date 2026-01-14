--local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3


local locale = mjrequire "common/locale"
local resource = mjrequire "common/resource"
local terrainTypesModule = mjrequire "common/terrainTypes"
--local order = mjrequire "common/order"
local snapGroup = mjrequire "common/snapGroups/snapGroup"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local plan = mjrequire "common/plan"
local tool = mjrequire "common/tool"
local action = mjrequire "common/action"
local actionSequence = mjrequire "common/actionSequence"
local typeMaps = mjrequire "common/typeMaps"

local constructable = mjrequire "common/constructable"


local constructableTypeIndexMap = typeMaps.types.constructable

local buildable = {
    minSeaLevelPosLengthNoUnderwater = 1.0 - mj:mToP(0.1),
    minSeaLevelPosLengthDefault = 1.0 - mj:mToP(2.1),
}

buildable.minSeaLevelPosLengthNoUnderwater2 = buildable.minSeaLevelPosLengthNoUnderwater * buildable.minSeaLevelPosLengthNoUnderwater
buildable.minSeaLevelPosLengthDefault2 = buildable.minSeaLevelPosLengthDefault * buildable.minSeaLevelPosLengthDefault

buildable.bringOnlySequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
}


buildable.bringAndMoveSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
    },
}

buildable.clearObjectsSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
    },
}

buildable.clearObjectsAndTerrainSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearTerrain.index
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
    },
}

buildable.plantSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.dig.index,
        requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
        subModelAddition = {
            modelName = "plantHole"
        },
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.dig.index,
        requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
        disallowCompletionWithoutSkill = true,
        subModelAddition = {
            modelName = "plantHole"
        },
    },
}


buildable.carveCanoeSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.scrapeWood.index,
        requiredToolIndex = tool.types.carving.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.scrapeWood.index,
        requiredToolIndex = tool.types.carving.index,
    },
}



buildable.fillSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearTerrain.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
   --[[ {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.dig.index,
        requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
    },]]
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.dig.index,
        requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
        disallowCompletionWithoutSkill = true,
    },
}


buildable.clearAndBringSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearTerrain.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
}


buildable.pathSequence = buildable.fillSequence



function buildable:addBuildable(key, buildableInfo)
	return constructable:addConstructable(key, buildableInfo)
end


buildable:addBuildable("craftArea", {
    modelName = "craftArea",
    inProgressGameObjectTypeKey = "build_craftArea",
    finalGameObjectTypeKey = "craftArea",
    name = locale:get("buildable_craftArea"),
    plural = locale:get("buildable_craftArea_plural"),
    summary = locale:get("buildable_craftArea_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.craftArea.index,

    skills = {
        required = skill.types.basicBuilding.index,
    },

    allowYTranslation = true,
    noBuildUnderWater = true,
    checkObjectCollisions = true,
    
    requiredResources = {
        {
            type = resource.types.rock.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.patDown.index,
            }
        }
    },

    placeBuildObjectsInFinalLocationsOnDropOff = true,

    requiresSlopeCheck = true,

    buildSequence = buildable.clearAndBringSequence,

    maleSnapPoints = snapGroup.malePoints.onFloor2x2MaleSnapPoints,
    snapToWalkableHeight = true,
})

buildable:addBuildable("storageArea", {
    modelName = "storageArea",
    inProgressGameObjectTypeKey = "build_storageArea",
    finalGameObjectTypeKey = "storageArea",
    name = locale:get("buildable_storageArea"),
    variationGroupName = locale:get("buildableVariationGroup_storageArea"),
    plural = locale:get("buildable_storageArea_plural"),
    summary = locale:get("buildable_storageArea_summary"),
    classification = constructable.classifications.build.index,
    
    allowYTranslation = false,
    noBuildUnderWater = true,
    requiresSlopeCheck = true,
    checkObjectCollisions = true,

    skills = {
        required = skill.types.basicBuilding.index,
    },

    --buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.onFloor2x2MaleSnapPoints,
    snapToWalkableHeight = true,
    
    variations = {
        constructableTypeIndexMap.storageArea1x1,
        constructableTypeIndexMap.storageArea4x4,
    },
})


buildable:addBuildable("storageArea1x1", {
    modelName = "storageArea1x1",
    inProgressGameObjectTypeKey = "build_storageArea1x1",
    finalGameObjectTypeKey = "storageArea1x1",
    name = locale:get("buildable_storageArea1x1"),
    plural = locale:get("buildable_storageArea1x1_plural"),
    summary = locale:get("buildable_storageArea1x1_summary"),
    classification = constructable.classifications.build.index,
    
    allowYTranslation = false,
    noBuildUnderWater = true,
    requiresSlopeCheck = true,
    checkObjectCollisions = true,

    skills = {
        required = skill.types.basicBuilding.index,
    },

    --buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.onFloor1x1MaleSnapPoints,
    snapToWalkableHeight = true,
})


buildable:addBuildable("storageArea4x4", {
    modelName = "storageArea4x4",
    inProgressGameObjectTypeKey = "build_storageArea4x4",
    finalGameObjectTypeKey = "storageArea4x4",
    name = locale:get("buildable_storageArea4x4"),
    plural = locale:get("buildable_storageArea4x4_plural"),
    summary = locale:get("buildable_storageArea4x4_summary"),
    classification = constructable.classifications.build.index,
    
    allowYTranslation = false,
    noBuildUnderWater = true,
    requiresSlopeCheck = true,
    checkObjectCollisions = true,

    skills = {
        required = skill.types.basicBuilding.index,
    },

    --buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.onFloor4x4MaleSnapPoints,
    snapToWalkableHeight = true,
})

buildable:addBuildable("campfire", {
    modelName = "campfire",
    inProgressGameObjectTypeKey = "build_campfire",
    finalGameObjectTypeKey = "campfire",
    name = locale:get("buildable_campfire"),
    plural = locale:get("buildable_campfire_plural"),
    summary = locale:get("buildable_campfire_summary"),
    buildCompletionPlanIndex = plan.types.light.index,
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.campfire.index,
    allowYTranslation = false,
    noBuildUnderWater = true,
    requiresSlopeCheck = true,
    allowBuildEvenWhenDark = true,
    checkObjectCollisions = true,
    
    skills = {
        required = skill.types.fireLighting.index,
    },

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    requiredResources = {
        {
            group = resource.groups.rockAny.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.patDown.index,
            }
        }
    }
})


buildable:addBuildable("brickKiln", {
    modelName = "brickKiln",
    inProgressGameObjectTypeKey = "build_brickKiln",
    finalGameObjectTypeKey = "brickKiln",
    name = locale:get("buildable_brickKiln"),
    plural = locale:get("buildable_brickKiln_plural"),
    summary = locale:get("buildable_brickKiln_summary"),
    buildCompletionPlanIndex = plan.types.light.index,
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.kiln.index,
    allowYTranslation = false,
    noBuildUnderWater = true,
    requiresSlopeCheck = true,
    allowBuildEvenWhenDark = true,
    checkObjectCollisions = true,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,
    
    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.patDown.index,
                duration = 20.0,
            }
        }
    },
})


buildable:addBuildable("compostBin", {
    modelName = "compostBin",
    inProgressGameObjectTypeKey = "build_compostBin",
    finalGameObjectTypeKey = "compostBin",
    name = locale:get("buildable_compostBin"),
    plural = locale:get("buildable_compostBin_plural"),
    summary = locale:get("buildable_compostBin_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.compostBin.index,
    countsAsSplitLogWallForTutorial = true,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.composting,
    
    allowYTranslation = false,
    noBuildUnderWater = true,
    requiresSlopeCheck = true,
    checkObjectCollisions = true,

    skills = {
        required = skill.types.woodBuilding.index,
    },

    snapToWalkableHeight = true, --not sure on this
    
    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.onFloor2x2MaleSnapPoints,
    
    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("torch", {
    modelName = "torch",
    inProgressGameObjectTypeKey = "build_torch",
    finalGameObjectTypeKey = "torch",
    name = locale:get("buildable_torch"),
    plural = locale:get("buildable_torch_plural"),
    summary = locale:get("buildable_torch_summary"),
    buildCompletionPlanIndex = plan.types.light.index,
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.torch.index,
    allowBuildEvenWhenDark = true,

    
    maleSnapPoints = snapGroup.malePoints.verticalColumnMaleSnapPoints,

    skills = {
        required = skill.types.fireLighting.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,
    noBuildUnderWater = true,

    buildSequence = buildable.bringAndMoveSequence,
   -- placeBuildObjectsInFinalLocationsOnDropOff = true,
    
    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("hayBed", {
    modelName = "hayBed",
    inProgressGameObjectTypeKey = "build_hayBed",
    finalGameObjectTypeKey = "hayBed",
    name = locale:get("buildable_hayBed"),
    variationGroupName = locale:get("buildableVariationGroup_bed"),
    plural = locale:get("buildable_hayBed_plural"),
    summary = locale:get("buildable_hayBed_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.bed.index,
    allowBuildEvenWhenDark = true,
    
    skills = {
        required = skill.types.basicBuilding.index,
    },

    requiresSlopeCheck = true,
    allowYTranslation = false,
    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.clearObjectsSequence,

    requiredResources = {
        {
            type = resource.types.hay.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.patDown.index,
                duration = 5.0,
            }
        },
    },
    variations = {
        constructableTypeIndexMap.woolskinBed,
    },
})


buildable:addBuildable("woolskinBed", {
    modelName = "woolskinBed",
    inProgressGameObjectTypeKey = "build_woolskinBed",
    finalGameObjectTypeKey = "woolskinBed",
    name = locale:get("buildable_woolskinBed"),
    plural = locale:get("buildable_woolskinBed_plural"),
    summary = locale:get("buildable_woolskinBed_summary"),
    classification = constructable.classifications.build.index,
    allowBuildEvenWhenDark = true,
    rebuildGroupIndex = constructable.rebuildGroups.bed.index,
    
    skills = {
        required = skill.types.basicBuilding.index,
    },

    requiresSlopeCheck = true,
    allowYTranslation = false,
    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.clearObjectsSequence,

    requiredResources = {
        {
            type = resource.types.woolskin.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.patDown.index,
                duration = 5.0,
            }
        },
    }
})


buildable:addBuildable("dirtFoundation1x1", {
    modelName = "dirtFoundation1x1",
    inProgressGameObjectTypeKey = "build_dirtFoundation1x1",
    finalGameObjectTypeKey = "dirtFoundation1x1",
    name = locale:get("buildable_dirtFoundation1x1"),
    plural = locale:get("buildable_dirtFoundation1x1_plural"),
    summary = locale:get("buildable_dirtFoundation1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation1x1.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.digging,

    skills = {
        required = skill.types.basicBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation1x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.dirt.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("dirtFoundation2x2", {
    modelName = "dirtFoundation2x2",
    inProgressGameObjectTypeKey = "build_dirtFoundation2x2",
    finalGameObjectTypeKey = "dirtFoundation2x2",
    name = locale:get("buildable_dirtFoundation2x2"),
    plural = locale:get("buildable_dirtFoundation2x2_plural"),
    summary = locale:get("buildable_dirtFoundation2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation2x2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.digging,

    skills = {
        required = skill.types.basicBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.dirt.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variationGroupName = locale:get("buildableVariationGroup_dirtFoundation"),
    variations = {
        constructableTypeIndexMap.dirtFoundation1x1,
    },
})

buildable:addBuildable("thatchRoof", {
    modelName = "thatchRoof",
    inProgressGameObjectTypeKey = "build_thatchRoof",
    finalGameObjectTypeKey = "thatchRoof",
    name = locale:get("buildable_thatchRoof"),
    plural = locale:get("buildable_thatchRoof_plural"),
    summary = locale:get("buildable_thatchRoof_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roof.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 8,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.thatchRoofSlope,
        constructableTypeIndexMap.thatchRoofSmallCorner,
        constructableTypeIndexMap.thatchRoofSmallCornerInside,
        constructableTypeIndexMap.thatchRoofTriangle,
        constructableTypeIndexMap.thatchRoofInvertedTriangle,
        constructableTypeIndexMap.thatchRoofLarge,
        constructableTypeIndexMap.thatchRoofLargeCorner,
        constructableTypeIndexMap.thatchRoofLargeCornerInside,
    },
})



buildable:addBuildable("thatchRoofSlope", {
    modelName = "thatchRoofSlope",
    inProgressGameObjectTypeKey = "build_thatchRoofSlope",
    finalGameObjectTypeKey = "thatchRoofSlope",
    name = locale:get("buildable_thatchRoofSlope"),
    plural = locale:get("buildable_thatchRoofSlope_plural"),
    summary = locale:get("buildable_thatchRoofSlope_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSlope.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSlopeMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})



buildable:addBuildable("thatchRoofSmallCorner", {
    modelName = "thatchRoofSmallCorner",
    inProgressGameObjectTypeKey = "build_thatchRoofSmallCorner",
    finalGameObjectTypeKey = "thatchRoofSmallCorner",
    name = locale:get("buildable_thatchRoofSmallCorner"),
    plural = locale:get("buildable_thatchRoofSmallCorner_plural"),
    summary = locale:get("buildable_thatchRoofSmallCorner_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSmallCorner.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSmallCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchRoofSmallCornerInside", {
    modelName = "thatchRoofSmallCornerInside",
    inProgressGameObjectTypeKey = "build_thatchRoofSmallCornerInside",
    finalGameObjectTypeKey = "thatchRoofSmallCornerInside",
    name = locale:get("buildable_thatchRoofSmallCornerInside"),
    plural = locale:get("buildable_thatchRoofSmallCornerInside_plural"),
    summary = locale:get("buildable_thatchRoofSmallCornerInside_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSmallCornerInside.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSmallInnerCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchRoofTriangle", {
    modelName = "thatchRoofTriangle",
    inProgressGameObjectTypeKey = "build_thatchRoofTriangle",
    finalGameObjectTypeKey = "thatchRoofTriangle",
    name = locale:get("buildable_thatchRoofTriangle"),
    plural = locale:get("buildable_thatchRoofTriangle_plural"),
    summary = locale:get("buildable_thatchRoofTriangle_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofTriangle.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofTriangleMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchRoofInvertedTriangle", {
    modelName = "thatchRoofInvertedTriangle",
    inProgressGameObjectTypeKey = "build_thatchRoofInvertedTriangle",
    finalGameObjectTypeKey = "thatchRoofInvertedTriangle",
    name = locale:get("buildable_thatchRoofInvertedTriangle"),
    plural = locale:get("buildable_thatchRoofInvertedTriangle_plural"),
    summary = locale:get("buildable_thatchRoofInvertedTriangle_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofInvertedTriangle.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofInvertedTriangleMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("thatchRoofLarge", {
    modelName = "thatchRoofLarge",
    inProgressGameObjectTypeKey = "build_thatchRoofLarge",
    finalGameObjectTypeKey = "thatchRoofLarge",
    name = locale:get("buildable_thatchRoofLarge"),
    plural = locale:get("buildable_thatchRoofLarge_plural"),
    summary = locale:get("buildable_thatchRoofLarge_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofLarge.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofLargeMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 8,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("thatchRoofLargeCorner", {
    modelName = "thatchRoofLargeCorner",
    inProgressGameObjectTypeKey = "build_thatchRoofLargeCorner",
    finalGameObjectTypeKey = "thatchRoofLargeCorner",
    name = locale:get("buildable_thatchRoofLargeCorner"),
    plural = locale:get("buildable_thatchRoofLargeCorner_plural"),
    summary = locale:get("buildable_thatchRoofLargeCorner_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofLargeCorner.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofLargeCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 9,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 9,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchRoofLargeCornerInside", {
    modelName = "thatchRoofLargeCornerInside",
    inProgressGameObjectTypeKey = "build_thatchRoofLargeCornerInside",
    finalGameObjectTypeKey = "thatchRoofLargeCornerInside",
    name = locale:get("buildable_thatchRoofLargeCornerInside"),
    plural = locale:get("buildable_thatchRoofLargeCornerInside_plural"),
    summary = locale:get("buildable_thatchRoofLargeCornerInside_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofLargeCornerInside.index,
    countsAsThatchRoofForTutorial = true,
    
    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofLargeInnerCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 9,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 9,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("thatchWall", {
    modelName = "thatchWall",
    inProgressGameObjectTypeKey = "build_thatchWall",
    finalGameObjectTypeKey = "thatchWall",
    name = locale:get("buildable_thatchWall"),
    plural = locale:get("buildable_thatchWall_plural"),
    summary = locale:get("buildable_thatchWall_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 5,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    variations = {
        constructableTypeIndexMap.thatchWallDoor,
        constructableTypeIndexMap.thatchWallLargeWindow,
        constructableTypeIndexMap.thatchWall4x1,
        constructableTypeIndexMap.thatchWall2x2,
        constructableTypeIndexMap.thatchWall2x1,
        constructableTypeIndexMap.thatchRoofEnd,
    },
})

buildable:addBuildable("thatchWallDoor", {
    modelName = "thatchWallDoor",
    inProgressGameObjectTypeKey = "build_thatchWallDoor",
    finalGameObjectTypeKey = "thatchWallDoor",
    name = locale:get("buildable_thatchWallDoor"),
    plural = locale:get("buildable_thatchWallDoor_plural"),
    summary = locale:get("buildable_thatchWallDoor_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchWallLargeWindow", {
    modelName = "thatchWallLargeWindow",
    inProgressGameObjectTypeKey = "build_thatchWallLargeWindow",
    finalGameObjectTypeKey = "thatchWallLargeWindow",
    name = locale:get("buildable_thatchWallLargeWindow"),
    plural = locale:get("buildable_thatchWallLargeWindow_plural"),
    summary = locale:get("buildable_thatchWallLargeWindow_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 5,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("thatchRoofEnd", {
    modelName = "thatchRoofEnd",
    inProgressGameObjectTypeKey = "build_thatchRoofEnd",
    finalGameObjectTypeKey = "thatchRoofEnd",
    name = locale:get("buildable_thatchRoofEnd"),
    plural = locale:get("buildable_thatchRoofEnd_plural"),
    summary = locale:get("buildable_thatchRoofEnd_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wallRoofEnd.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.roofEndWallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("thatchWall4x1", {
    modelName = "thatchWall4x1",
    inProgressGameObjectTypeKey = "build_thatchWall4x1",
    finalGameObjectTypeKey = "thatchWall4x1",
    name = locale:get("buildable_thatchWall4x1"),
    plural = locale:get("buildable_thatchWall4x1_plural"),
    summary = locale:get("buildable_thatchWall4x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x1.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall4x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchWall2x2", {
    modelName = "thatchWall2x2",
    inProgressGameObjectTypeKey = "build_thatchWall2x2",
    finalGameObjectTypeKey = "thatchWall2x2",
    name = locale:get("buildable_thatchWall2x2"),
    plural = locale:get("buildable_thatchWall2x2_plural"),
    summary = locale:get("buildable_thatchWall2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x2.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("thatchWall2x1", {
    modelName = "thatchWall2x1",
    inProgressGameObjectTypeKey = "build_thatchWall2x1",
    finalGameObjectTypeKey = "thatchWall2x1",
    name = locale:get("buildable_thatchWall2x1"),
    plural = locale:get("buildable_thatchWall2x1_plural"),
    summary = locale:get("buildable_thatchWall2x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x1.index,

    skills = {
        required = skill.types.thatchBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.branch.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.hay.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("splitLogFloor1x1", {
    modelName = "splitLogFloor1x1",
    inProgressGameObjectTypeKey = "build_splitLogFloor1x1",
    finalGameObjectTypeKey = "splitLogFloor1x1",
    name = locale:get("buildable_splitLogFloor1x1"),
    plural = locale:get("buildable_splitLogFloor1x1_plural"),
    summary = locale:get("buildable_splitLogFloor1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor1x1.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor1x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("splitLogFloor", {
    modelName = "splitLogFloor2x2",
    inProgressGameObjectTypeKey = "build_splitLogFloor",
    finalGameObjectTypeKey = "splitLogFloor",
    name = locale:get("buildable_splitLogFloor"),
    variationGroupName = locale:get("buildableVariationGroup_splitLogFloor"),
    plural = locale:get("buildable_splitLogFloor_plural"),
    summary = locale:get("buildable_splitLogFloor_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor2x2.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.splitLogFloor4x4,
        constructableTypeIndexMap.splitLogFloorTri2,
        constructableTypeIndexMap.splitLogFloor1x1,
    },
})

buildable:addBuildable("splitLogFloor4x4", {
    modelName = "splitLogFloor4x4",
    inProgressGameObjectTypeKey = "build_splitLogFloor4x4",
    finalGameObjectTypeKey = "splitLogFloor4x4",
    name = locale:get("buildable_splitLogFloor4x4"),
    plural = locale:get("buildable_splitLogFloor4x4_plural"),
    summary = locale:get("buildable_splitLogFloor4x4_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor4x4.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor4x4MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 12,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogFloorTri2", {
    modelName = "splitLogFloorTri2",
    inProgressGameObjectTypeKey = "build_splitLogFloorTri2",
    finalGameObjectTypeKey = "splitLogFloorTri2",
    name = locale:get("buildable_splitLogFloorTri2"),
    plural = locale:get("buildable_splitLogFloorTri2_plural"),
    summary = locale:get("buildable_splitLogFloorTri2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floorTri2.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floorTri2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("splitLogWall", {
    modelName = "splitLogWall",
    inProgressGameObjectTypeKey = "build_splitLogWall",
    finalGameObjectTypeKey = "splitLogWall",
    name = locale:get("buildable_splitLogWall"),
    plural = locale:get("buildable_splitLogWall_plural"),
    summary = locale:get("buildable_splitLogWall_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.splitLogWallDoor,
        constructableTypeIndexMap.splitLogWallLargeWindow,
        constructableTypeIndexMap.splitLogWall4x1,
        constructableTypeIndexMap.splitLogWall2x2,
        constructableTypeIndexMap.splitLogWall2x1,
        constructableTypeIndexMap.splitLogRoofEnd,
    },
})

buildable:addBuildable("splitLogWall4x1", {
    modelName = "splitLogWall4x1",
    inProgressGameObjectTypeKey = "build_splitLogWall4x1",
    finalGameObjectTypeKey = "splitLogWall4x1",
    name = locale:get("buildable_splitLogWall4x1"),
    plural = locale:get("buildable_splitLogWall4x1_plural"),
    summary = locale:get("buildable_splitLogWall4x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x1.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall4x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("splitLogWall2x2", {
    modelName = "splitLogWall2x2",
    inProgressGameObjectTypeKey = "build_splitLogWall2x2",
    finalGameObjectTypeKey = "splitLogWall2x2",
    name = locale:get("buildable_splitLogWall2x2"),
    plural = locale:get("buildable_splitLogWall2x2_plural"),
    summary = locale:get("buildable_splitLogWall2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x2.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogWall2x1", {
    modelName = "splitLogWall2x1",
    inProgressGameObjectTypeKey = "build_splitLogWall2x1",
    finalGameObjectTypeKey = "splitLogWall2x1",
    name = locale:get("buildable_splitLogWall2x1"),
    plural = locale:get("buildable_splitLogWall2x1_plural"),
    summary = locale:get("buildable_splitLogWall2x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x1.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("splitLogWallDoor", {
    modelName = "splitLogWallDoor",
    inProgressGameObjectTypeKey = "build_splitLogWallDoor",
    finalGameObjectTypeKey = "splitLogWallDoor",
    name = locale:get("buildable_splitLogWallDoor"),
    plural = locale:get("buildable_splitLogWallDoor_plural"),
    summary = locale:get("buildable_splitLogWallDoor_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogWallLargeWindow", {
    modelName = "splitLogWallLargeWindow",
    inProgressGameObjectTypeKey = "build_splitLogWallLargeWindow",
    finalGameObjectTypeKey = "splitLogWallLargeWindow",
    name = locale:get("buildable_splitLogWallLargeWindow"),
    plural = locale:get("buildable_splitLogWallLargeWindow_plural"),
    summary = locale:get("buildable_splitLogWallLargeWindow_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,
    countsAsSplitLogWallForTutorial = true,

    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogRoofEnd", {
    modelName = "splitLogRoofEnd",
    inProgressGameObjectTypeKey = "build_splitLogRoofEnd",
    finalGameObjectTypeKey = "splitLogRoofEnd",
    name = locale:get("buildable_splitLogRoofEnd"),
    plural = locale:get("buildable_splitLogRoofEnd_plural"),
    summary = locale:get("buildable_splitLogRoofEnd_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wallRoofEnd.index,
    countsAsSplitLogWallForTutorial = true,

    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.roofEndWallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("splitLogBench", {
    modelName = "splitLogBench",
    inProgressGameObjectTypeKey = "build_splitLogBench",
    finalGameObjectTypeKey = "splitLogBench",
    name = locale:get("buildable_splitLogBench"),
    plural = locale:get("buildable_splitLogBench_plural"),
    summary = locale:get("buildable_splitLogBench_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.bench.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    requiresSlopeCheck = true,
    allowYTranslation = true,
    noBuildUnderWater = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
            }
        }
    }
})


buildable:addBuildable("splitLogShelf", {
    modelName = "splitLogShelf",
    inProgressGameObjectTypeKey = "build_splitLogShelf",
    finalGameObjectTypeKey = "splitLogShelf",
    name = locale:get("buildable_splitLogShelf"),
    plural = locale:get("buildable_splitLogShelf_plural"),
    summary = locale:get("buildable_splitLogShelf_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.shelf.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.shelfMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
            }
        }
    }
})

buildable:addBuildable("splitLogToolRack", {
    modelName = "splitLogToolRack",
    inProgressGameObjectTypeKey = "build_splitLogToolRack",
    finalGameObjectTypeKey = "splitLogToolRack",
    name = locale:get("buildable_splitLogToolRack"),
    plural = locale:get("buildable_splitLogToolRack_plural"),
    summary = locale:get("buildable_splitLogToolRack_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.toolRack.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.toolRackMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("sled", {
    modelName = "sled",
    inProgressGameObjectTypeKey = "build_sled",
    finalGameObjectTypeKey = "sled",
    name = locale:get("buildable_sled"),
    plural = locale:get("buildable_sled_plural"),
    summary = locale:get("buildable_sled_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.sled.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.flaxTwine.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        }
    },

    variations = {
        constructableTypeIndexMap.coveredSled,
    },
})

buildable:addBuildable("coveredSled", {
    modelName = "coveredSled",
    inProgressGameObjectTypeKey = "build_coveredSled",
    finalGameObjectTypeKey = "coveredSled",
    name = locale:get("buildable_coveredSled"),
    plural = locale:get("buildable_coveredSled_plural"),
    summary = locale:get("buildable_coveredSled_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.sled.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.woolskin.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.flaxTwine.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        }
    }
})


buildable:addBuildable("canoe", {
    modelName = "canoe",
    inProgressGameObjectTypeKey = "build_canoe",
    finalGameObjectTypeKey = "canoe",
    name = locale:get("buildable_canoe"),
    plural = locale:get("buildable_canoe_plural"),
    summary = locale:get("buildable_canoe_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.canoe.index,
    disabledUntilCraftableResearched = true,
    constructableResearchClueText = locale:get("buildable_canoe_researchClueText"),
    
    skills = {
        required = skill.types.woodWorking.index,
    },

    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.carveCanoeSequence,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.flaxTwine.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        }
    },

    variations = {
        constructableTypeIndexMap.coveredCanoe,
    },

    requiredTools = {
        tool.types.carving.index,
    },
    
    requiresShallowWaterToResearch = true,
})


buildable:addBuildable("coveredCanoe", {
    modelName = "coveredCanoe",
    inProgressGameObjectTypeKey = "build_coveredCanoe",
    finalGameObjectTypeKey = "coveredCanoe",
    name = locale:get("buildable_coveredCanoe"),
    plural = locale:get("buildable_coveredCanoe_plural"),
    summary = locale:get("buildable_coveredCanoe_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.canoe.index,
    --disabledUntilCraftableResearched = true, --hmmm, this probably needs to actually wait until the standard canoe is built or something
    constructableResearchClueText = locale:get("buildable_canoe_researchClueText"),
    
    skills = {
        required = skill.types.woodWorking.index,
    },

    noBuildUnderWater = true,
    checkObjectCollisions = true,

    buildSequence = buildable.carveCanoeSequence,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.woolskin.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.flaxTwine.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        }
    },

    requiredTools = {
        tool.types.carving.index,
    },
})

buildable:addBuildable("splitLogSteps", {
    modelName = "splitLogSteps",
    inProgressGameObjectTypeKey = "build_splitLogSteps",
    finalGameObjectTypeKey = "splitLogSteps",
    name = locale:get("buildable_splitLogSteps"),
    plural = locale:get("buildable_splitLogSteps_plural"),
    summary = locale:get("buildable_splitLogSteps_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.steps.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.steps1p5MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})


buildable:addBuildable("splitLogSteps2x2", {
    modelName = "splitLogSteps2x2",
    inProgressGameObjectTypeKey = "build_splitLogSteps2x2",
    finalGameObjectTypeKey = "splitLogSteps2x2",
    name = locale:get("buildable_splitLogSteps2x2"),
    variationGroupName = locale:get("buildableVariationGroup_splitLogSteps"),
    plural = locale:get("buildable_splitLogSteps2x2_plural"),
    summary = locale:get("buildable_splitLogSteps2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.steps2x2.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.steps2HalfMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    variations = {
        constructableTypeIndexMap.splitLogSteps,
    },
})

buildable:addBuildable("splitLogRoof", {
    modelName = "splitLogRoof",
    inProgressGameObjectTypeKey = "build_splitLogRoof",
    finalGameObjectTypeKey = "splitLogRoof",
    name = locale:get("buildable_splitLogRoof"),
    plural = locale:get("buildable_splitLogRoof_plural"),
    summary = locale:get("buildable_splitLogRoof_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roof.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 5,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 10,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.splitLogRoofSlope,
        constructableTypeIndexMap.splitLogRoofSmallCorner,
        constructableTypeIndexMap.splitLogRoofSmallCornerInside,
        constructableTypeIndexMap.splitLogRoofTriangle,
        constructableTypeIndexMap.splitLogRoofInvertedTriangle,
    },
})


buildable:addBuildable("splitLogRoofSlope", {
    modelName = "splitLogRoofSlope",
    inProgressGameObjectTypeKey = "build_splitLogRoofSlope",
    finalGameObjectTypeKey = "splitLogRoofSlope",
    name = locale:get("buildable_splitLogRoofSlope"),
    plural = locale:get("buildable_splitLogRoofSlope_plural"),
    summary = locale:get("buildable_splitLogRoofSlope_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSlope.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSlopeMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogRoofSmallCorner", {
    modelName = "splitLogRoofSmallCorner",
    inProgressGameObjectTypeKey = "build_splitLogRoofSmallCorner",
    finalGameObjectTypeKey = "splitLogRoofSmallCorner",
    name = locale:get("buildable_splitLogRoofSmallCorner"),
    plural = locale:get("buildable_splitLogRoofSmallCorner_plural"),
    summary = locale:get("buildable_splitLogRoofSmallCorner_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSmallCorner.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSmallCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 5,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogRoofSmallCornerInside", {
    modelName = "splitLogRoofSmallCornerInside",
    inProgressGameObjectTypeKey = "build_splitLogRoofSmallCornerInside",
    finalGameObjectTypeKey = "splitLogRoofSmallCornerInside",
    name = locale:get("buildable_splitLogRoofSmallCornerInside"),
    plural = locale:get("buildable_splitLogRoofSmallCornerInside_plural"),
    summary = locale:get("buildable_splitLogRoofSmallCornerInside_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSmallCornerInside.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSmallInnerCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 5,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogRoofTriangle", {
    modelName = "splitLogRoofTriangle",
    inProgressGameObjectTypeKey = "build_splitLogRoofTriangle",
    finalGameObjectTypeKey = "splitLogRoofTriangle",
    name = locale:get("buildable_splitLogRoofTriangle"),
    plural = locale:get("buildable_splitLogRoofTriangle_plural"),
    summary = locale:get("buildable_splitLogRoofTriangle_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofTriangle.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofTriangleMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("splitLogRoofInvertedTriangle", {
    modelName = "splitLogRoofInvertedTriangle",
    inProgressGameObjectTypeKey = "build_splitLogRoofInvertedTriangle",
    finalGameObjectTypeKey = "splitLogRoofInvertedTriangle",
    name = locale:get("buildable_splitLogRoofInvertedTriangle"),
    plural = locale:get("buildable_splitLogRoofInvertedTriangle_plural"),
    summary = locale:get("buildable_splitLogRoofInvertedTriangle_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofInvertedTriangle.index,
    countsAsSplitLogWallForTutorial = true,
    
    skills = {
        required = skill.types.woodBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofInvertedTriangleMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.log.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickWall", {
    modelName = "mudBrickWall",
    inProgressGameObjectTypeKey = "build_mudBrickWall",
    finalGameObjectTypeKey = "mudBrickWall",
    name = locale:get("buildable_mudBrickWall"),
    plural = locale:get("buildable_mudBrickWall_plural"),
    summary = locale:get("buildable_mudBrickWall_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.mudBrickWallDoor,
        constructableTypeIndexMap.mudBrickWallLargeWindow,
        constructableTypeIndexMap.mudBrickWall4x1,
        constructableTypeIndexMap.mudBrickWall2x2,
        constructableTypeIndexMap.mudBrickWall2x1,
        constructableTypeIndexMap.mudBrickRoofEnd,
    },
})

buildable:addBuildable("mudBrickWallDoor", {
    modelName = "mudBrickWallDoor",
    inProgressGameObjectTypeKey = "build_mudBrickWallDoor",
    finalGameObjectTypeKey = "mudBrickWallDoor",
    name = locale:get("buildable_mudBrickWallDoor"),
    plural = locale:get("buildable_mudBrickWallDoor_plural"),
    summary = locale:get("buildable_mudBrickWallDoor_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("mudBrickWallLargeWindow", {
    modelName = "mudBrickWallLargeWindow",
    inProgressGameObjectTypeKey = "build_mudBrickWallLargeWindow",
    finalGameObjectTypeKey = "mudBrickWallLargeWindow",
    name = locale:get("buildable_mudBrickWallLargeWindow"),
    plural = locale:get("buildable_mudBrickWallLargeWindow_plural"),
    summary = locale:get("buildable_mudBrickWallLargeWindow_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickRoofEnd", {
    modelName = "mudBrickRoofEnd",
    inProgressGameObjectTypeKey = "build_mudBrickRoofEnd",
    finalGameObjectTypeKey = "mudBrickRoofEnd",
    name = locale:get("buildable_mudBrickRoofEnd"),
    plural = locale:get("buildable_mudBrickRoofEnd_plural"),
    summary = locale:get("buildable_mudBrickRoofEnd_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wallRoofEnd.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.roofEndWallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickWall4x1", {
    modelName = "mudBrickWall4x1",
    inProgressGameObjectTypeKey = "build_mudBrickWall4x1",
    finalGameObjectTypeKey = "mudBrickWall4x1",
    name = locale:get("buildable_mudBrickWall4x1"),
    plural = locale:get("buildable_mudBrickWall4x1_plural"),
    summary = locale:get("buildable_mudBrickWall4x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x1.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall4x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickWall2x2", {
    modelName = "mudBrickWall2x2",
    inProgressGameObjectTypeKey = "build_mudBrickWall2x2",
    finalGameObjectTypeKey = "mudBrickWall2x2",
    name = locale:get("buildable_mudBrickWall2x2"),
    plural = locale:get("buildable_mudBrickWall2x2_plural"),
    summary = locale:get("buildable_mudBrickWall2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickWall2x1", {
    modelName = "mudBrickWall2x1",
    inProgressGameObjectTypeKey = "build_mudBrickWall2x1",
    finalGameObjectTypeKey = "mudBrickWall2x1",
    name = locale:get("buildable_mudBrickWall2x1"),
    plural = locale:get("buildable_mudBrickWall2x1_plural"),
    summary = locale:get("buildable_mudBrickWall2x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x1.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickColumn", {
    modelName = "mudBrickColumn",
    inProgressGameObjectTypeKey = "build_mudBrickColumn",
    finalGameObjectTypeKey = "mudBrickColumn",
    name = locale:get("buildable_mudBrickColumn"),
    plural = locale:get("buildable_mudBrickColumn_plural"),
    summary = locale:get("buildable_mudBrickColumn_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.column.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.verticalColumnMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("stoneBlockColumn", {
    modelName = "stoneBlockColumn",
    inProgressGameObjectTypeKey = "build_stoneBlockColumn",
    finalGameObjectTypeKey = "stoneBlockColumn",
    name = locale:get("buildable_stoneBlockColumn"),
    plural = locale:get("buildable_stoneBlockColumn_plural"),
    summary = locale:get("buildable_stoneBlockColumn_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.column.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.verticalColumnMaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickFloor1x1", {
    modelName = "mudBrickFloor1x1",
    inProgressGameObjectTypeKey = "build_mudBrickFloor1x1",
    finalGameObjectTypeKey = "mudBrickFloor1x1",
    name = locale:get("buildable_mudBrickFloor1x1"),
    variationGroupName = locale:get("buildableVariationGroup_mudBrickFloor"),
    plural = locale:get("buildable_mudBrickFloor1x1_plural"),
    summary = locale:get("buildable_mudBrickFloor1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor1x1.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor1x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("mudBrickFloor2x2", {
    modelName = "mudBrickFloor2x2",
    inProgressGameObjectTypeKey = "build_mudBrickFloor2x2",
    finalGameObjectTypeKey = "mudBrickFloor2x2",
    name = locale:get("buildable_mudBrickFloor2x2"),
    variationGroupName = locale:get("buildableVariationGroup_mudBrickFloor"),
    plural = locale:get("buildable_mudBrickFloor2x2_plural"),
    summary = locale:get("buildable_mudBrickFloor2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor2x2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.mudBrickFloor4x4,
        constructableTypeIndexMap.mudBrickFloorTri2,
        constructableTypeIndexMap.mudBrickFloor1x1,
    },
})


buildable:addBuildable("mudBrickFloor4x4", {
    modelName = "mudBrickFloor4x4",
    inProgressGameObjectTypeKey = "build_mudBrickFloor4x4",
    finalGameObjectTypeKey = "mudBrickFloor4x4",
    name = locale:get("buildable_mudBrickFloor4x4"),
    plural = locale:get("buildable_mudBrickFloor4x4_plural"),
    summary = locale:get("buildable_mudBrickFloor4x4_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor4x4.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor4x4MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 8,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})



buildable:addBuildable("mudBrickFloorTri2", {
    modelName = "mudBrickFloorTri2",
    inProgressGameObjectTypeKey = "build_mudBrickFloorTri2",
    finalGameObjectTypeKey = "mudBrickFloorTri2",
    name = locale:get("buildable_mudBrickFloorTri2"),
    plural = locale:get("buildable_mudBrickFloorTri2_plural"),
    summary = locale:get("buildable_mudBrickFloorTri2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floorTri2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floorTri2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("mudBrickFoundation1x1", {
    modelName = "mudBrickFoundation1x1",
    inProgressGameObjectTypeKey = "build_mudBrickFoundation1x1",
    finalGameObjectTypeKey = "mudBrickFoundation1x1",
    name = locale:get("buildable_mudBrickFoundation1x1"),
    plural = locale:get("buildable_mudBrickFoundation1x1_plural"),
    summary = locale:get("buildable_mudBrickFoundation1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation1x1.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation1x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("mudBrickFoundation2x2", {
    modelName = "mudBrickFoundation2x2",
    inProgressGameObjectTypeKey = "build_mudBrickFoundation2x2",
    finalGameObjectTypeKey = "mudBrickFoundation2x2",
    name = locale:get("buildable_mudBrickFoundation2x2"),
    plural = locale:get("buildable_mudBrickFoundation2x2_plural"),
    summary = locale:get("buildable_mudBrickFoundation2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation2x2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.mudBrickDry.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variationGroupName = locale:get("buildableVariationGroup_mudBrickFoundation"),
    variations = {
        constructableTypeIndexMap.mudBrickFoundation1x1,
    },
})

buildable:addBuildable("stoneBlockWall", {
    modelName = "stoneBlockWall",
    inProgressGameObjectTypeKey = "build_stoneBlockWall",
    finalGameObjectTypeKey = "stoneBlockWall",
    name = locale:get("buildable_stoneBlockWall"),
    plural = locale:get("buildable_stoneBlockWall_plural"),
    summary = locale:get("buildable_stoneBlockWall_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.stoneBlockWallDoor,
        constructableTypeIndexMap.stoneBlockWallLargeWindow,
        constructableTypeIndexMap.stoneBlockWall4x1,
        constructableTypeIndexMap.stoneBlockWall2x2,
        constructableTypeIndexMap.stoneBlockWall2x1,
        constructableTypeIndexMap.stoneBlockRoofEnd,
    },
})


buildable:addBuildable("stoneBlockWallDoor", {
    modelName = "stoneBlockWallDoor",
    inProgressGameObjectTypeKey = "build_stoneBlockWallDoor",
    finalGameObjectTypeKey = "stoneBlockWallDoor",
    name = locale:get("buildable_stoneBlockWallDoor"),
    plural = locale:get("buildable_stoneBlockWallDoor_plural"),
    summary = locale:get("buildable_stoneBlockWallDoor_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("stoneBlockWallLargeWindow", {
    modelName = "stoneBlockWallLargeWindow",
    inProgressGameObjectTypeKey = "build_stoneBlockWallLargeWindow",
    finalGameObjectTypeKey = "stoneBlockWallLargeWindow",
    name = locale:get("buildable_stoneBlockWallLargeWindow"),
    plural = locale:get("buildable_stoneBlockWallLargeWindow_plural"),
    summary = locale:get("buildable_stoneBlockWallLargeWindow_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("stoneBlockRoofEnd", {
    modelName = "stoneBlockRoofEnd",
    inProgressGameObjectTypeKey = "build_stoneBlockRoofEnd",
    finalGameObjectTypeKey = "stoneBlockRoofEnd",
    name = locale:get("buildable_stoneBlockRoofEnd"),
    plural = locale:get("buildable_stoneBlockRoofEnd_plural"),
    summary = locale:get("buildable_stoneBlockRoofEnd_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wallRoofEnd.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.roofEndWallMaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("stoneBlockWall4x1", {
    modelName = "stoneBlockWall4x1",
    inProgressGameObjectTypeKey = "build_stoneBlockWall4x1",
    finalGameObjectTypeKey = "stoneBlockWall4x1",
    name = locale:get("buildable_stoneBlockWall4x1"),
    plural = locale:get("buildable_stoneBlockWall4x1_plural"),
    summary = locale:get("buildable_stoneBlockWall4x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x1.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall4x1MaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("stoneBlockWall2x2", {
    modelName = "stoneBlockWall2x2",
    inProgressGameObjectTypeKey = "build_stoneBlockWall2x2",
    finalGameObjectTypeKey = "stoneBlockWall2x2",
    name = locale:get("buildable_stoneBlockWall2x2"),
    plural = locale:get("buildable_stoneBlockWall2x2_plural"),
    summary = locale:get("buildable_stoneBlockWall2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x2MaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("stoneBlockWall2x1", {
    modelName = "stoneBlockWall2x1",
    inProgressGameObjectTypeKey = "build_stoneBlockWall2x1",
    finalGameObjectTypeKey = "stoneBlockWall2x1",
    name = locale:get("buildable_stoneBlockWall2x1"),
    plural = locale:get("buildable_stoneBlockWall2x1_plural"),
    summary = locale:get("buildable_stoneBlockWall2x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x1.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x1MaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("stoneBlockFoundation1x1", {
    modelName = "stoneBlockFoundation1x1",
    inProgressGameObjectTypeKey = "build_stoneBlockFoundation1x1",
    finalGameObjectTypeKey = "stoneBlockFoundation1x1",
    name = locale:get("buildable_stoneBlockFoundation1x1"),
    plural = locale:get("buildable_stoneBlockFoundation1x1_plural"),
    summary = locale:get("buildable_stoneBlockFoundation1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation1x1.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation1x1MaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("stoneBlockFoundation2x2", {
    modelName = "stoneBlockFoundation2x2",
    inProgressGameObjectTypeKey = "build_stoneBlockFoundation2x2",
    finalGameObjectTypeKey = "stoneBlockFoundation2x2",
    name = locale:get("buildable_stoneBlockFoundation2x2"),
    plural = locale:get("buildable_stoneBlockFoundation2x2_plural"),
    summary = locale:get("buildable_stoneBlockFoundation2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation2x2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.chiselStone,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation2x2MaleSnapPoints,

    requiredResources = {
        {
            group = resource.groups.stoneBlockAny.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variationGroupName = locale:get("buildableVariationGroup_stoneBlockFoundation"),
    variations = {
        constructableTypeIndexMap.stoneBlockFoundation1x1,
    },
})

buildable:addBuildable("brickWall", {
    modelName = "brickWall",
    inProgressGameObjectTypeKey = "build_brickWall",
    finalGameObjectTypeKey = "brickWall",
    name = locale:get("buildable_brickWall"),
    plural = locale:get("buildable_brickWall_plural"),
    summary = locale:get("buildable_brickWall_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },

    variations = {
        constructableTypeIndexMap.brickWallDoor,
        constructableTypeIndexMap.brickWallLargeWindow,
        constructableTypeIndexMap.brickWall4x1,
        constructableTypeIndexMap.brickWall2x2,
        constructableTypeIndexMap.brickWall2x1,
        constructableTypeIndexMap.brickRoofEnd,
    },
})


buildable:addBuildable("brickWallDoor", {
    modelName = "brickWallDoor",
    inProgressGameObjectTypeKey = "build_brickWallDoor",
    finalGameObjectTypeKey = "brickWallDoor",
    name = locale:get("buildable_brickWallDoor"),
    plural = locale:get("buildable_brickWallDoor_plural"),
    summary = locale:get("buildable_brickWallDoor_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})



buildable:addBuildable("brickWallLargeWindow", {
    modelName = "brickWallLargeWindow",
    inProgressGameObjectTypeKey = "build_brickWallLargeWindow",
    finalGameObjectTypeKey = "brickWallLargeWindow",
    name = locale:get("buildable_brickWallLargeWindow"),
    plural = locale:get("buildable_brickWallLargeWindow_plural"),
    summary = locale:get("buildable_brickWallLargeWindow_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wallMaleSnapPoints,
    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 6,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("brickRoofEnd", {
    modelName = "brickRoofEnd",
    inProgressGameObjectTypeKey = "build_brickRoofEnd",
    finalGameObjectTypeKey = "brickRoofEnd",
    name = locale:get("buildable_brickRoofEnd"),
    plural = locale:get("buildable_brickRoofEnd_plural"),
    summary = locale:get("buildable_brickRoofEnd_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wallRoofEnd.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.roofEndWallMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("brickWall4x1", {
    modelName = "brickWall4x1",
    inProgressGameObjectTypeKey = "build_brickWall4x1",
    finalGameObjectTypeKey = "brickWall4x1",
    name = locale:get("buildable_brickWall4x1"),
    plural = locale:get("buildable_brickWall4x1_plural"),
    summary = locale:get("buildable_brickWall4x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall4x1.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall4x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("brickWall2x2", {
    modelName = "brickWall2x2",
    inProgressGameObjectTypeKey = "build_brickWall2x2",
    finalGameObjectTypeKey = "brickWall2x2",
    name = locale:get("buildable_brickWall2x2"),
    plural = locale:get("buildable_brickWall2x2_plural"),
    summary = locale:get("buildable_brickWall2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x2.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("brickWall2x1", {
    modelName = "brickWall2x1",
    inProgressGameObjectTypeKey = "build_brickWall2x1",
    finalGameObjectTypeKey = "brickWall2x1",
    name = locale:get("buildable_brickWall2x1"),
    plural = locale:get("buildable_brickWall2x1_plural"),
    summary = locale:get("buildable_brickWall2x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.wall2x1.index,

    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,

    maleSnapPoints = snapGroup.malePoints.wall2x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("brickFoundation1x1", {
    modelName = "brickFoundation1x1",
    inProgressGameObjectTypeKey = "build_brickFoundation1x1",
    finalGameObjectTypeKey = "brickFoundation1x1",
    name = locale:get("buildable_brickFoundation1x1"),
    plural = locale:get("buildable_brickFoundation1x1_plural"),
    summary = locale:get("buildable_brickFoundation1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation1x1.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation1x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("brickFoundation2x2", {
    modelName = "brickFoundation2x2",
    inProgressGameObjectTypeKey = "build_brickFoundation2x2",
    finalGameObjectTypeKey = "brickFoundation2x2",
    name = locale:get("buildable_brickFoundation2x2"),
    plural = locale:get("buildable_brickFoundation2x2_plural"),
    summary = locale:get("buildable_brickFoundation2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.foundation2x2.index,
    
    disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.potteryFiring,

    skills = {
        required = skill.types.mudBrickBuilding.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.foundation2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedBrick.index,
            count = 4,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variationGroupName = locale:get("buildableVariationGroup_brickFoundation"),
    variations = {
        constructableTypeIndexMap.brickFoundation1x1,
    },
})

buildable:addBuildable("tileFloor1x1", {
    modelName = "tileFloor1x1",
    inProgressGameObjectTypeKey = "build_tileFloor1x1",
    finalGameObjectTypeKey = "tileFloor1x1",
    name = locale:get("buildable_tileFloor1x1"),
    plural = locale:get("buildable_tileFloor1x1_plural"),
    summary = locale:get("buildable_tileFloor1x1_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor1x1.index,
    
    skills = {
        required = skill.types.tiling.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor1x1MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedTile.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
})

buildable:addBuildable("tileFloor2x2", {
    modelName = "tileFloor2x2",
    inProgressGameObjectTypeKey = "build_tileFloor2x2",
    finalGameObjectTypeKey = "tileFloor2x2",
    name = locale:get("buildable_tileFloor2x2"),
    plural = locale:get("buildable_tileFloor2x2_plural"),
    summary = locale:get("buildable_tileFloor2x2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor2x2.index,
    
    skills = {
        required = skill.types.tiling.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor2x2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedTile.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variationGroupName = locale:get("buildableVariationGroup_tileFloor"),
    variations = {
        constructableTypeIndexMap.tileFloor4x4,
        constructableTypeIndexMap.tileFloorTri2,
        constructableTypeIndexMap.tileFloor1x1,
    },
})


buildable:addBuildable("tileFloor4x4", {
    modelName = "tileFloor4x4",
    inProgressGameObjectTypeKey = "build_tileFloor4x4",
    finalGameObjectTypeKey = "tileFloor4x4",
    name = locale:get("buildable_tileFloor4x4"),
    plural = locale:get("buildable_tileFloor4x4_plural"),
    summary = locale:get("buildable_tileFloor4x4_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floor4x4.index,
    
    skills = {
        required = skill.types.tiling.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floor4x4MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedTile.index,
            count = 8,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("tileFloorTri2", {
    modelName = "tileFloorTri2",
    inProgressGameObjectTypeKey = "build_tileFloorTri2",
    finalGameObjectTypeKey = "tileFloorTri2",
    name = locale:get("buildable_tileFloorTri2"),
    plural = locale:get("buildable_tileFloorTri2_plural"),
    summary = locale:get("buildable_tileFloorTri2_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.floorTri2.index,
    
    skills = {
        required = skill.types.tiling.index,
    },

    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    maleSnapPoints = snapGroup.malePoints.floorTri2MaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.firedTile.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("tileRoof", {
    modelName = "tileRoof",
    inProgressGameObjectTypeKey = "build_tileRoof",
    finalGameObjectTypeKey = "tileRoof",
    name = locale:get("buildable_tileRoof"),
    plural = locale:get("buildable_tileRoof_plural"),
    summary = locale:get("buildable_tileRoof_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roof.index,
    
    skills = {
        required = skill.types.tiling.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 5,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.firedTile.index,
            count = 8,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    
    variations = {
        constructableTypeIndexMap.tileRoofSlope,
        constructableTypeIndexMap.tileRoofSmallCorner,
        constructableTypeIndexMap.tileRoofSmallCornerInside,
        constructableTypeIndexMap.tileRoofTriangle,
        constructableTypeIndexMap.tileRoofInvertedTriangle,
    },
})


buildable:addBuildable("tileRoofSlope", {
    modelName = "tileRoofSlope",
    inProgressGameObjectTypeKey = "build_tileRoofSlope",
    finalGameObjectTypeKey = "tileRoofSlope",
    name = locale:get("buildable_tileRoofSlope"),
    plural = locale:get("buildable_tileRoofSlope_plural"),
    summary = locale:get("buildable_tileRoofSlope_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSlope.index,
    
    skills = {
        required = skill.types.tiling.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSlopeMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.firedTile.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("tileRoofSmallCorner", {
    modelName = "tileRoofSmallCorner",
    inProgressGameObjectTypeKey = "build_tileRoofSmallCorner",
    finalGameObjectTypeKey = "tileRoofSmallCorner",
    name = locale:get("buildable_tileRoofSmallCorner"),
    plural = locale:get("buildable_tileRoofSmallCorner_plural"),
    summary = locale:get("buildable_tileRoofSmallCorner_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSmallCorner.index,
    
    skills = {
        required = skill.types.tiling.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSmallCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 3,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.firedTile.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("tileRoofSmallCornerInside", {
    modelName = "tileRoofSmallCornerInside",
    inProgressGameObjectTypeKey = "build_tileRoofSmallCornerInside",
    finalGameObjectTypeKey = "tileRoofSmallCornerInside",
    name = locale:get("buildable_tileRoofSmallCornerInside"),
    plural = locale:get("buildable_tileRoofSmallCornerInside_plural"),
    summary = locale:get("buildable_tileRoofSmallCornerInside_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofSmallCornerInside.index,
    
    skills = {
        required = skill.types.tiling.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofSmallInnerCornerMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.firedTile.index,
            count = 2,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("tileRoofTriangle", {
    modelName = "tileRoofTriangle",
    inProgressGameObjectTypeKey = "build_tileRoofTriangle",
    finalGameObjectTypeKey = "tileRoofTriangle",
    name = locale:get("buildable_tileRoofTriangle"),
    plural = locale:get("buildable_tileRoofTriangle_plural"),
    summary = locale:get("buildable_tileRoofTriangle_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofTriangle.index,
    
    skills = {
        required = skill.types.tiling.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofTriangleMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.firedTile.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})


buildable:addBuildable("tileRoofInvertedTriangle", {
    modelName = "tileRoofInvertedTriangle",
    inProgressGameObjectTypeKey = "build_tileRoofInvertedTriangle",
    finalGameObjectTypeKey = "tileRoofInvertedTriangle",
    name = locale:get("buildable_tileRoofInvertedTriangle"),
    plural = locale:get("buildable_tileRoofInvertedTriangle_plural"),
    summary = locale:get("buildable_tileRoofInvertedTriangle_summary"),
    classification = constructable.classifications.build.index,
    rebuildGroupIndex = constructable.rebuildGroups.roofInvertedTriangle.index,
    
    skills = {
        required = skill.types.tiling.index,
    },
    
    allowYTranslation = true,
    allowXZRotation = true,

    buildSequence = buildable.clearObjectsAndTerrainSequence,
    
    maleSnapPoints = snapGroup.malePoints.roofInvertedTriangleMaleSnapPoints,

    requiredResources = {
        {
            type = resource.types.splitLog.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
        {
            type = resource.types.firedTile.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    }
})

buildable:addBuildable("fertilize", {
    inProgressBuildModel = "craftSimple",

    name = locale:get("buildable_fertilize"),
    plural = locale:get("buildable_fertilize_plural"),
    summary = locale:get("buildable_fertilize_summary"),
    planTypeIndex = plan.types.fertilize.index,
    classification = constructable.classifications.fertilize.index,

    iconGameObjectType = resource.types.manure.displayGameObjectTypeIndex,
    
    skills = {
        required = skill.types.mulching.index,
    },
    
    disallowsLimitedAbilitySapiens = true,
    omitFromDiscoveryUI = true,
    
    buildSequence = buildable.fillSequence,

    requiredResources = {
        {
            group = resource.groups.fertilizer.index,
            count = 1,
            afterAction = {
                actionTypeIndex = action.types.inspect.index,
                durationWithoutSkill = 10.0,
            }
        },
    },
    requiredTools = {
        tool.types.dig.index,
    },

    requiredTerrainTypes = terrainTypesModule.fertilizableTypesArray,
})

function buildable:addInfoForPlaceableResource(baseResourceType, defaultModelName, defaultGameObjectTypeKey)
    local buildableKey = "place_" .. baseResourceType.key
    if not constructable.types[buildableKey] then
        buildable:addBuildable(buildableKey,{
            name = locale:get("misc_decorate_with", {name = baseResourceType.name}),
            plural = baseResourceType.plural,
            modelName = defaultModelName,
            inProgressGameObjectTypeKey = "place_" .. defaultGameObjectTypeKey,
            finalGameObjectTypeKey = "placed_" .. defaultGameObjectTypeKey,
            summary = locale:get("misc_place_object_summary"),
            classification = constructable.classifications.place.index,
    
            noClearOrderRequired = true,
            isPlaceType = true,
            disallowsDecorationPlacing = baseResourceType.disallowsDecorationPlacing,
            allowXZRotation = true,
            allowYTranslation = true,
            
            buildSequence = buildable.bringOnlySequence,
            placeBuildObjectsInFinalLocationsOnDropOff = true,
            placeResourceTypeIndex = baseResourceType.index,
            
            skills = {
                required = skill.types.basicBuilding.index,
            },
    
            requiredResources = {
                {
                    type = baseResourceType.index,
                    --objectTypeIndex = baseObjectType.index,
                    count = 1,
                },
            },

            maleSnapPoints = baseResourceType.placeBuildableMaleSnapPoints,
        })
    end
end

function buildable:addInfoForPlantableObject(baseObjectType, summary, seedResourceTypeIndex, mediumTypes, inProgressModelName)

    
    --[[buildSequence = {
        {
            buildSequenceTypeIndex = "clearObjects",
        },
        {
            buildSequenceTypeIndex = "actionSequence",
            actionSequenceTypeIndex = actionSequence.types.dig.index,
            duration = 10.0,
            requireToolIndex = tool.types.dig.index,
        },
        {
            buildSequenceTypeIndex = "moveComponents",
        },
    },]]

    local buildableKey = "plant_" .. baseObjectType.key
    if not constructable.types[buildableKey] then
        buildable:addBuildable(buildableKey,{
            name = baseObjectType.name,
            plural = baseObjectType.plural,
            modelName = baseObjectType.modelName,
            iconGameObjectType = baseObjectType.index,--resourceType.displayGameObjectTypeIndex,
            --placeholderOverrideModelName = "craftSimple",
            inProgressBuildModel = inProgressModelName,
            inProgressGameObjectTypeKey = "plant_" .. baseObjectType.key,
            finalGameObjectTypeKey = "sapling_" .. baseObjectType.key,
            summary = summary,
            randomInitialYRotation = true,
            planTypeIndex = plan.types.plant.index,
            classification = constructable.classifications.plant.index,

            disallowsLimitedAbilitySapiens = true,
            checkObjectCollisions = true,
            
            buildSequence = buildable.plantSequence,
            
            requiredMediumTypes = mediumTypes,

            skills = {
                required = skill.types.planting.index,
            },
    
            requiredResources = {
                {
                    type = seedResourceTypeIndex,
                    --objectTypeIndex = baseObjectType.index,
                    count = 1,
                    afterAction = {
                        actionTypeIndex = action.types.patDown.index,
                        duration = 5.0,
                        durationWithoutSkill = 15.0,
                    }
                },
            },
            requiredTools = {
                tool.types.dig.index,
            },
        })
    end

    return constructable.types[buildableKey].index
end

function buildable:addInfoForFillResource(resourceTypeIndex, requiredResourceCount)
    local resourceType = resource.types[resourceTypeIndex]
    local buildableKey = "fill_" .. resourceType.key
    local requiredSkillTypeIndex = skill.types.digging.index
    local requiredToolTypeIndex = tool.types.dig.index

    if not constructable.types[buildableKey] then
        buildable:addBuildable(buildableKey,{
            name = resourceType.plural,
            plural = resourceType.plural,
            --modelName = objectType.modelName,
            inProgressBuildModel = "craftSimple",
           -- placeholderOverrideModelName = "craftSimple",
            summary = locale:get("fill_summary", { resourceTypeNamePlural = resourceType.plural, requiredResourceCount = requiredResourceCount}),
            planTypeIndex = plan.types.fill.index,
            classification = constructable.classifications.fill.index,
            
            iconGameObjectType = resourceType.displayGameObjectTypeIndex,

            disallowsLimitedAbilitySapiens = true,
            omitFromDiscoveryUI = true,
            
            buildSequence = buildable.fillSequence,
            

            skills = {
                required = requiredSkillTypeIndex,
            },

            requiredResources = {
                {
                    type = resourceTypeIndex,
                    count = requiredResourceCount,
                },
            },
            requiredTools = {
                requiredToolTypeIndex,
            },
        })
    end
end



function buildable:addInfoForPathObject(baseObjectKey, 
    name, 
    plural, 
    summary,
    modelName, 
    defaultSubModelName, 
    subModelNameByObjectTypeIndexFunction, 
    requiredResourceTypeIndex,
    requiredResourceGroupIndex,
    requiredResourceCount,
    requiredSkillTypeIndex) -- Either requiredResourceTypeIndex or requiredResourceGroupIndex should be nil

    local buildableKey = baseObjectKey
    if not constructable.types[buildableKey] then
        buildable:addBuildable(buildableKey,{
            name = name,
            plural = plural,
            modelName = modelName,
            defaultSubModelName = defaultSubModelName,
            subModelNameByObjectTypeIndexFunction = subModelNameByObjectTypeIndexFunction,
            inProgressGameObjectTypeKey = "build_" .. baseObjectKey,
            finalGameObjectTypeKey = baseObjectKey,
            summary = summary,
            classification = constructable.classifications.path.index,
            rebuildGroupIndex = constructable.rebuildGroups.path.index,
            randomInitialYRotation = true,
            planTypeIndex = plan.types.buildPath.index,
            offsetModelToFitTerrain = true,
            
            buildSequence = buildable.pathSequence,

            disallowsLimitedAbilitySapiens = true,
            
            isPathType = true,
            --offsetToWalkableHeightTestRadius = 1.0,
            
            skills = {
                required = requiredSkillTypeIndex,--skill.types.digging.index,
            },
    
    
            requiredResources = {
                {
                    type = requiredResourceTypeIndex,
                    group = requiredResourceGroupIndex,
                    --objectTypeIndex = baseObjectType.index,
                    count = requiredResourceCount,
                    afterAction = {
                        actionTypeIndex = action.types.patDown.index,
                    }
                },
            },
            requiredTools = {
                tool.types.dig.index,
            },
        })
    end
end



return buildable