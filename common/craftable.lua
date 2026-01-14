local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local mat3Inverse = mjm.mat3Inverse

local resource = mjrequire "common/resource"
local tool = mjrequire "common/tool"
--local order = mjrequire "common/order"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local constructable = mjrequire "common/constructable"
local action = mjrequire "common/action"
local actionSequence = mjrequire "common/actionSequence"
local locale = mjrequire "common/locale"
local craftAreaGroup = mjrequire "common/craftAreaGroup"
local pathFinding = mjrequire "common/pathFinding"
local snapGroup = mjrequire "common/snapGroups/snapGroup"
local seat = mjrequire "common/seat"

local gameObject = nil

--local typeMaps = mjrequire "common/typeMaps"
--local typeIndexMap = typeMaps.types.craftable

local craftable = {
   -- types = {},
}

local actionSequenceRepeatCountSlowerCompletion = 7
local actionSequenceRepeatCountSmelting = 31
local actionSequenceRepeatCountFastestCompletion = 1

local flintSpeedMultiplier = 1.2
local flintDamageMultiplier = 1.2
local flintDurabilityMultiplier = 2.0

local bronzeSpeedMultiplier = 1.4
local bronzeDamageMultiplier = 1.4
local bronzeDurabilityMultiplier = 4.0

local rock = mjrequire "common/rock"
local rockTypes = rock.validTypes

craftable.cookingStickRotationOffset = mat3Inverse(mat3Rotate(mat3Identity, math.pi * 0.25, vec3(0.0,1.0,0.0)))
craftable.cookingStickRotation = mat3Rotate(mat3Identity, -math.pi + math.pi * 0.25, vec3(0.0,1.0,0.0))


function craftable:createStandardBuildSequence(actionSequenceTypeIndex, requiredToolIndex, repeatCountOrNil)
    return {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
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
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
            actionSequenceTypeIndex = actionSequenceTypeIndex,
            requiredToolIndex = requiredToolIndex, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
            disallowCompletionWithoutSkill = true,
            repeatCount = repeatCountOrNil or actionSequenceRepeatCountSlowerCompletion,
        },
    }
end

craftable.researchBuildSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.inspect.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
    },
}

craftable.researchPlantSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
    },
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
            placeholderKey = "mound",
            modelName = "plantHole"
        },
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.inspect.index,
        disallowCompletionWithoutSkill = true,
        subModelAddition = {
            placeholderKey = "mound",
            modelName = "plantHole"
        },
    },
}

craftable.threshingSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
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
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.thresh.index,
        disallowCompletionWithoutSkill = true,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
    },
}

craftable.grindingSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.grind.index,
        requiredToolIndex = tool.types.grinding.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
        disallowCompletionWithoutSkill = true,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
    },
}

craftable.kneedingSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.potteryCraft.index,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
        -- no disallowCompletionWithoutSkill, as kneeding only needs the task assigned. Baking the result requires the skill is learned
    },
}

craftable.smithingSequence = {
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearIncorrectResources.index,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index
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
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.smithHammer.index,
        requiredToolIndex = tool.types.hammering.index,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
        resourcePositionOverrides = {
            resource_1 = "resource_store"
        }
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.inspect.index,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.smithHammer.index,
        requiredToolIndex = tool.types.hammering.index,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
        resourcePositionOverrides = {
            resource_1 = "resource_store"
        }
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.inspect.index,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
    },
    {
        constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
        actionSequenceTypeIndex = actionSequence.types.smithHammer.index,
        requiredToolIndex = tool.types.hammering.index,
        repeatCount = actionSequenceRepeatCountSlowerCompletion,
        resourcePositionOverrides = {
            resource_1 = "resource_store"
        },
        disallowCompletionWithoutSkill = true,
    },
}

function craftable:addCraftable(key, info)

    local constructableTypeIndex = constructable:addConstructable(key, info)

    if (not info.hasNoOutput) then
        if (not info.outputDisplayCounts) then
            info.outputDisplayCounts = {}
            info.outputDisplayCount = 1

            

            local outputObjectInfo = info.outputObjectInfo
            if outputObjectInfo then
                local function addFromObjectTypesArray(objectTypesArray)
                    --mj:log("objectTypesArray:", objectTypesArray)
                    for i,gameObjectTypeIndex in ipairs(objectTypesArray) do
                        if not gameObject.types[gameObjectTypeIndex] then
                            mj:error("missing gameObject.types[", gameObjectTypeIndex, "]:", gameObject.types[gameObjectTypeIndex])
                        end
                        local resourceTypeIndex = gameObject.types[gameObjectTypeIndex].resourceTypeIndex
                        local found = false
                        for j, outputDisplayCountInfo in ipairs(info.outputDisplayCounts) do
                            if outputDisplayCountInfo.type == resourceTypeIndex then
                                outputDisplayCountInfo.count = outputDisplayCountInfo.count + 1
                                info.outputDisplayCount = math.max(info.outputDisplayCount, outputDisplayCountInfo.count)
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(info.outputDisplayCounts, {
                                type = resourceTypeIndex,
                                count = 1
                            })
                        end
                    end
                end
                if outputObjectInfo.objectTypesArray then
                    addFromObjectTypesArray(outputObjectInfo.objectTypesArray)
                elseif outputObjectInfo.outputArraysByResourceObjectType then --NOTE this could cause issues, if the output gives a different resource type for a different input resource type, then outputDisplayCounts should be set manually in the info before getting here
                    -- for now though, we will assume that the output resources are always the same and just take any one.
                    local inputResourceObjectTypeIndex = next(outputObjectInfo.outputArraysByResourceObjectType)
                    addFromObjectTypesArray(outputObjectInfo.outputArraysByResourceObjectType[inputResourceObjectTypeIndex])
                end
            else
                local gameObjectType = gameObject.types[key]
                --mj:log("adding basic craftable with key:", key, " gameObjectType:", gameObjectType)
                if (not gameObjectType) or (not gameObjectType.resourceTypeIndex) then
                    mj:error("didn't find expected resourceTypeIndex:", info, " gameObjectType:", gameObjectType)
                end
                table.insert(info.outputDisplayCounts, {
                    type = gameObjectType.resourceTypeIndex,
                    count = 1
                })
            end
        end

        --[[if not info.maintainQuantityOutputResources then
            if info.outputDisplayCounts then

                if #info.outputDisplayCounts ~= 1 then
                    mj:warn("assuming all displayed outputs should be maintained:", key, " outputs:", info.outputDisplayCounts)
                end

                info.maintainQuantityOutputResources = info.outputDisplayCounts
            end
        end]]
    end

    return constructableTypeIndex
end

function craftable:load(gameObject_, flora)
    gameObject = gameObject_

    --[[

        key = "rock",
        objectTypeKey = "rock",
        smallObjectTypeKey = "rockSmall",
        largeObjectTypeKey = "rockLarge",
        stoneBlockTypeKey = "stoneBlock"
    ]]

    local function createRockFinalObjectInfos(baseKey, softRockOrFalseForHardOrNilForAll, addLegacyObjects)
        local result = {}
        for i, rockType in ipairs(rockTypes) do
            if softRockOrFalseForHardOrNilForAll == nil or (softRockOrFalseForHardOrNilForAll == true and (rockType.isSoftRock)) or (softRockOrFalseForHardOrNilForAll == false and (not rockType.isSoftRock)) or
            (addLegacyObjects and rockType.key == "limestone") then
                result[gameObject.types[rockType.smallObjectTypeKey].index] = {
                    key = baseKey .. rockType.craftablePostfix,
                    modelName = baseKey .. rockType.modelNamePostfix,
                }
            end
        end
        return result
    end
    

    local function createSmallRockOutputArraysByResourceObjectType(baseKey, softRockOrFalseForHardOrNilForAll, addLegacyObjects)
        local result = {}
        for i, rockType in ipairs(rockTypes) do
            if softRockOrFalseForHardOrNilForAll == nil or (softRockOrFalseForHardOrNilForAll == true and (rockType.isSoftRock)) or (softRockOrFalseForHardOrNilForAll == false and (not rockType.isSoftRock)) or
            (addLegacyObjects and rockType.key == "limestone")  then
                result[gameObject.types[rockType.smallObjectTypeKey].index] = {
                    gameObject.typeIndexMap[baseKey .. rockType.craftablePostfix],
                }
            end
        end
        return result
    end

    local function createStandardRockOutputArraysByResourceObjectType(baseKey, softRockOrFalseOrNil)
        local result = {}
        for i, rockType in ipairs(rockTypes) do
            if softRockOrFalseOrNil == nil or (softRockOrFalseOrNil == true and (rockType.isSoftRock)) or (softRockOrFalseOrNil == false and (not rockType.isSoftRock)) then
                result[gameObject.types[rockType.objectTypeKey].index] = {
                    gameObject.typeIndexMap[baseKey .. rockType.craftablePostfix],
                }
            end
        end
        return result
    end

    
    local function createStoneBlockFinalObjectInfos(baseKey, softRockOrFalseOrNil)
        local result = {}
        for i, rockType in ipairs(rockTypes) do
            if softRockOrFalseOrNil == nil or (softRockOrFalseOrNil == true and (rockType.isSoftRock)) or (softRockOrFalseOrNil == false and (not rockType.isSoftRock)) then
                result[gameObject.types[rockType.smallObjectTypeKey].index] = {
                    key = baseKey .. rockType.craftablePostfix,
                    modelName = baseKey .. rockType.craftablePostfix,
                }
            end
        end
        return result
    end

    local function createStoneBlockOutputArraysByResourceObjectType(baseKey, softRockOrFalseOrNil)
        local result = {}
        for i, rockType in ipairs(rockTypes) do
            if softRockOrFalseOrNil == nil or (softRockOrFalseOrNil == true and (rockType.isSoftRock)) or (softRockOrFalseOrNil == false and (not rockType.isSoftRock)) then
                local gameObjectTypeIndex = gameObject.typeIndexMap[baseKey .. rockType.craftablePostfix]
                result[gameObject.types[rockType.stoneBlockTypeKey].index] = {
                    gameObjectTypeIndex,
                    gameObjectTypeIndex,
                }
            end
        end
        return result
    end

    local stoneSpearHeadFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stoneSpearHead", false, true)
    local stoneSpearHeadOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stoneSpearHead", false, true)

    craftable:addCraftable("stoneSpearHead", {
        name = locale:get("craftable_stoneSpearHead"),
        plural = locale:get("craftable_stoneSpearHead_plural"),
        summary = locale:get("craftable_stoneSpearHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stoneSpearHead.index,
            finalObjectInfosByResourceObjectType = stoneSpearHeadFinalObjectInfosByResourceObjectType,
        },
        
        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneSpearHeadOutputArraysByResourceObjectType
        },


        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmall.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })


    craftable:addCraftable("flintSpearHead", {
        name = locale:get("craftable_flintSpearHead"),
        plural = locale:get("craftable_flintSpearHead_plural"),
        summary = locale:get("craftable_flintSpearHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.flintSpearHead.index,
            modelName = "flintSpearHead",
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.flintKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.flint.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })

    
    craftable:addCraftable("boneSpearHead", {
        name = locale:get("craftable_boneSpearHead"),
        plural = locale:get("craftable_boneSpearHead_plural"),
        summary = locale:get("craftable_boneSpearHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.boneSpearHead.index,
            modelName = "boneSpearHead",
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.scrapeWood.index, tool.types.carving.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.boneCarving.index,
        },
        requiredResources = {
            {
                type = resource.types.bone.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.carving.index,
        },
    })

    
    craftable:addCraftable("bronzeSpearHead", {
        name = locale:get("craftable_bronzeSpearHead"),
        plural = locale:get("craftable_bronzeSpearHead_plural"),
        summary = locale:get("craftable_bronzeSpearHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.bronzeSpearHead.index,
            modelName = "bronzeSpearHead",
        },

        buildSequence = craftable.smithingSequence,
        inProgressBuildModel = "craftSmith",
        
        skills = {
            required = skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeIngot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 30.0,
                }
            },
        },
        requiredTools = {
            tool.types.hammering.index,
        },
        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
    })

    
    local stonePickaxeHeadFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stonePickaxeHead", false, true)
    local stonePickaxeHeadOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stonePickaxeHead", false, true)

    craftable:addCraftable("stonePickaxeHead", {
        name = locale:get("craftable_stonePickaxeHead"),
        plural = locale:get("craftable_stonePickaxeHead_plural"),
        summary = locale:get("craftable_stonePickaxeHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stonePickaxeHead.index,
            finalObjectInfosByResourceObjectType = stonePickaxeHeadFinalObjectInfosByResourceObjectType,
        },
        
        outputObjectInfo = {
            outputArraysByResourceObjectType = stonePickaxeHeadOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmall.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })
    

    craftable:addCraftable("flintPickaxeHead", {
        name = locale:get("craftable_flintPickaxeHead"),
        plural = locale:get("craftable_flintPickaxeHead_plural"),
        summary = locale:get("craftable_flintPickaxeHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.flintPickaxeHead.index,
            modelName = "flintPickaxeHead",
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.flintKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.flint.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })


    craftable:addCraftable("bronzePickaxeHead", {
        name = locale:get("craftable_bronzePickaxeHead"),
        plural = locale:get("craftable_bronzePickaxeHead_plural"),
        summary = locale:get("craftable_bronzePickaxeHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            modelName = "bronzePickaxeHead",
            resourceTypeIndex = resource.types.bronzePickaxeHead.index,
        },

        buildSequence = craftable.smithingSequence,
        inProgressBuildModel = "craftSmith",
        
        skills = {
            required = skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeIngot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 30.0,
                }
            },
        },
        requiredTools = {
            tool.types.hammering.index,
        },
        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
    })

    local stoneKnifeFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stoneKnife", false, true)
    local stoneKnifeOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stoneKnife", false, true)

    craftable:addCraftable("stoneKnife", {
        name = locale:get("craftable_stoneKnife"),
        plural = locale:get("craftable_stoneKnife_plural"),
        summary = locale:get("craftable_stoneKnife_summary"),
        iconGameObjectType = gameObject.typeIndexMap.stoneKnife,
        classification = constructable.classifications.craft.index,
        
        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stoneKnife.index,
            finalObjectInfosByResourceObjectType = stoneKnifeFinalObjectInfosByResourceObjectType,
            toolUsages = {
                [tool.types.carving.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
                [tool.types.butcher.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
                [tool.types.weaponKnife.index] = {
                    [tool.propertyTypes.damage.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneKnifeOutputArraysByResourceObjectType
        },
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmall.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        }
        
    })

    
    local stoneChiselFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stoneChisel", false, false)
    local stoneChiselOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stoneChisel", false, false)

    craftable:addCraftable("stoneChisel", {
        name = locale:get("craftable_stoneChisel"),
        plural = locale:get("craftable_stoneChisel_plural"),
        summary = locale:get("craftable_stoneChisel_summary"),
        iconGameObjectType = gameObject.typeIndexMap.stoneChisel,
        classification = constructable.classifications.craft.index,
        
        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stoneChisel.index,
            finalObjectInfosByResourceObjectType = stoneChiselFinalObjectInfosByResourceObjectType,
            toolUsages = {
                [tool.types.carving.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
                [tool.types.softChiselling.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneChiselOutputArraysByResourceObjectType
        },
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmall.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        }
        
    })

    local rockSmallSoftOutputArraysByResourceObjectType = {}
    local rockSmallHardOutputArraysByResourceObjectType = {}

    for i, rockType in ipairs(rockTypes) do
        local softArray = {}
        local hardArray = {}

        local outputObjectType = gameObject.typeIndexMap[rockType.smallObjectTypeKey]
        for j=1,2 do
            if rockType.isSoftRock then
                table.insert(softArray, outputObjectType)
            else
                table.insert(hardArray, outputObjectType)
            end
        end
        if next(softArray) then
            rockSmallSoftOutputArraysByResourceObjectType[gameObject.types[rockType.objectTypeKey].index] = softArray
        end
        if next(hardArray) then
            rockSmallHardOutputArraysByResourceObjectType[gameObject.types[rockType.objectTypeKey].index] = hardArray
        end
    end
    
    craftable:addCraftable("rockSmallSoft", {
        name = locale:get("craftable_rockSmallSoft"),
        plural = locale:get("craftable_rockSmallSoft_plural"),
        summary = locale:get("craftable_rockSmallSoft_summary"),
        iconGameObjectType = gameObject.typeIndexMap.limestoneRockSmall,
        classification = constructable.classifications.craft.index,
        omitFromDiscoveryUI = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = rockSmallSoftOutputArraysByResourceObjectType
        },
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knapCrude.index, tool.types.knappingCrude.index, actionSequenceRepeatCountFastestCompletion),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSoft.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knappingCrude.index,
        }
        
    })

    craftable:addCraftable("rockSmall", {
        name = locale:get("craftable_rockSmall"),
        plural = locale:get("craftable_rockSmall_plural"),
        summary = locale:get("craftable_rockSmall_summary"),
        iconGameObjectType = gameObject.typeIndexMap.rockSmall,
        classification = constructable.classifications.craft.index,

        outputObjectInfo = {
            outputArraysByResourceObjectType = rockSmallHardOutputArraysByResourceObjectType
        },
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knapCrude.index, tool.types.knappingCrude.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rock.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knappingCrude.index,
        }
        
    })

    
    
    craftable:addCraftable("flintKnife", {
        name = locale:get("craftable_flintKnife"),
        plural = locale:get("craftable_flintKnife_plural"),
        summary = locale:get("craftable_flintKnife_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.flintKnife.index,
            modelName = "flintKnife",
            toolUsages = {
                [tool.types.carving.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
                [tool.types.butcher.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
                [tool.types.weaponKnife.index] = {
                    [tool.propertyTypes.damage.index] = flintDamageMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.flintKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.flint.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })

    
    craftable:addCraftable("boneKnife", {
        name = locale:get("craftable_boneKnife"),
        plural = locale:get("craftable_boneKnife_plural"),
        summary = locale:get("craftable_boneKnife_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.boneKnife.index,
            modelName = "boneKnife",
            toolUsages = {
                [tool.types.carving.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
                [tool.types.butcher.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
                [tool.types.weaponKnife.index] = {
                    [tool.propertyTypes.damage.index] = flintDamageMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.scrapeWood.index, tool.types.carving.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.boneCarving.index,
        },
        requiredResources = {
            {
                type = resource.types.bone.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.carving.index,
        },
    })

    
    
    craftable:addCraftable("bronzeKnife", {
        name = locale:get("craftable_bronzeKnife"),
        plural = locale:get("craftable_bronzeKnife_plural"),
        summary = locale:get("craftable_bronzeKnife_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.bronzeKnife.index,
            modelName = "bronzeKnife",
            toolUsages = {
                [tool.types.carving.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
                [tool.types.butcher.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
                [tool.types.weaponKnife.index] = {
                    [tool.propertyTypes.damage.index] = bronzeDamageMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable.smithingSequence,
        inProgressBuildModel = "craftSmith",
        
        skills = {
            required = skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeIngot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 30.0,
                }
            },
        },
        requiredTools = {
            tool.types.hammering.index,
        },
        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
    })

    
    craftable:addCraftable("bronzeChisel", {
        name = locale:get("craftable_bronzeChisel"),
        plural = locale:get("craftable_bronzeChisel_plural"),
        summary = locale:get("craftable_bronzeChisel_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.bronzeChisel.index,
            modelName = "bronzeChisel",
            toolUsages = {
                [tool.types.softChiselling.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
                [tool.types.hardChiselling.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
                [tool.types.carving.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable.smithingSequence,
        inProgressBuildModel = "craftSmith",
        
        skills = {
            required = skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeIngot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 30.0,
                }
            },
        },
        requiredTools = {
            tool.types.hammering.index,
        },
        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
    })
    
    craftable:addCraftable("boneFlute", {
        name = locale:get("craftable_boneFlute"),
        plural = locale:get("craftable_boneFlute_plural"),
        summary = locale:get("craftable_boneFlute_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.boneFlute.index,
            modelName = "boneFlute",
            isMusicalInstrument = true,
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.scrapeWood.index, tool.types.carving.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.boneCarving.index,
        },
        requiredResources = {
            {
                type = resource.types.bone.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.carving.index,
        },
    })

    
    craftable:addCraftable("logDrum", {
        name = locale:get("craftable_logDrum"),
        plural = locale:get("craftable_logDrum_plural"),
        summary = locale:get("craftable_logDrum_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        constructableResearchClueText = locale:get("craftable_logDrum_researchClueText"),
        researchRequiredForCraftableVisibilityDiscoverySkillTypeIndexes = {
            skill.types.woodWorking.index,
        },

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.logDrum.index,
            modelName = "logDrum",
            isMusicalInstrument = true,
            preservesConstructionObjects = true,
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.scrapeWood.index, tool.types.carving.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.woodWorking.index,
        },
        requiredResources = {
            {
                type = resource.types.log.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.carving.index,
        },
    })
    craftable:addCraftable("balafon", {
        name = locale:get("craftable_balafon"),
        plural = locale:get("craftable_balafon_plural"),
        summary = locale:get("craftable_balafon_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        researchRequiredForCraftableVisibilityDiscoverySkillTypeIndexes = {
            skill.types.woodWorking.index,
        },

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.balafon.index,
            modelName = "balafon",
            isMusicalInstrument = true,
            preservesConstructionObjects = true,
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "balafonBuild",
        
        skills = {
            required = skill.types.woodWorking.index,
        },
        requiredResources = {
            {
                type = resource.types.pumpkin.index,
                count = 3,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 2,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    local woodenPoleFinalObjectInfosByResourceObjectType = {}
    local woodenPoleOutputArraysByResourceObjectType = {}
    local splitLogFinalObjectInfosByResourceObjectType = {}
    local splitLogOutputArraysByResourceObjectType = {}

    for i,baseKey in ipairs(flora.branchTypeBaseKeys) do
        local branchKey = baseKey .. "Branch"
        local gameObjectTypeIndex = gameObject.typeIndexMap[branchKey]

        local shaftKey = baseKey .. "WoodenPole"
        woodenPoleFinalObjectInfosByResourceObjectType[gameObjectTypeIndex] = {
            key = shaftKey,
            modelName = "woodenPoleLong_" .. baseKey,
        }
        woodenPoleOutputArraysByResourceObjectType[gameObjectTypeIndex] = {
            gameObject.typeIndexMap[shaftKey],
        }
    end
    

    for i,baseKey in ipairs(flora.logTypeBaseKeys) do
        local logKey = baseKey .. "Log"
        local logGameObjectTypeIndex = gameObject.typeIndexMap[logKey]

        local splitLogKey = baseKey .. "SplitLog"
        splitLogFinalObjectInfosByResourceObjectType[logGameObjectTypeIndex] = {
            key = splitLogKey,
            modelName = splitLogKey,
        }
        splitLogOutputArraysByResourceObjectType[logGameObjectTypeIndex] = {
            gameObject.typeIndexMap[splitLogKey],
            gameObject.typeIndexMap[splitLogKey],
            gameObject.typeIndexMap[splitLogKey],
            gameObject.typeIndexMap[splitLogKey],
        }
    end

    --mj:log("splitLogObjectTypesByResourceObjectType:", splitLogObjectTypesByResourceObjectType)

    craftable:addCraftable("woodenPole", { --woodenPole is a deprecated item, but is added here to support alpha worlds
        name = locale:get("craftable_woodenPole"),
        plural = locale:get("craftable_woodenPole_plural"),
        summary = locale:get("craftable_woodenPole_summary"),
        iconGameObjectType = gameObject.typeIndexMap.birchWoodenPole,
        classification = constructable.classifications.craft.index,
        omitFromDiscoveryUI = true,
        deprecated = true,
        
        addGameObjectInfo = {
            resourceTypeIndex = resource.types.woodenPole.index,
            finalObjectInfosByResourceObjectType = woodenPoleFinalObjectInfosByResourceObjectType,
            femaleSnapPoints = snapGroup.femalePoints.horizontalColumnFemaleSnapPoints,
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = woodenPoleOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.scrapeWood.index, tool.types.carving.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.woodWorking.index,
        },
        requiredResources = {
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.carving.index,
        },
        
    })

    craftable:addCraftable("stoneSpear", {
        name = locale:get("craftable_stoneSpear"),
        plural = locale:get("craftable_stoneSpear_plural"),
        summary = locale:get("craftable_stoneSpear_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "stoneSpear",
            resourceTypeIndex = resource.types.stoneSpear.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.weaponSpear.index] = {
                    [tool.propertyTypes.damage.index] = 2.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "stoneSpearBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.stoneSpearHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    craftable:addCraftable("flintSpear", {
        name = locale:get("craftable_flintSpear"),
        plural = locale:get("craftable_flintSpear_plural"),
        summary = locale:get("craftable_flintSpear_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "flintSpear",
            resourceTypeIndex = resource.types.flintSpear.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.weaponSpear.index] = {
                    [tool.propertyTypes.damage.index] = 2.0 * flintDamageMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "flintSpearBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.flintSpearHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    
    craftable:addCraftable("boneSpear", {
        name = locale:get("craftable_boneSpear"),
        plural = locale:get("craftable_boneSpear_plural"),
        summary = locale:get("craftable_boneSpear_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "boneSpear",
            resourceTypeIndex = resource.types.boneSpear.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.weaponSpear.index] = {
                    [tool.propertyTypes.damage.index] = 2.0 * flintDamageMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "boneSpearBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.boneSpearHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    craftable:addCraftable("bronzeSpear", {
        name = locale:get("craftable_bronzeSpear"),
        plural = locale:get("craftable_bronzeSpear_plural"),
        summary = locale:get("craftable_bronzeSpear_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "bronzeSpear",
            resourceTypeIndex = resource.types.bronzeSpear.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.weaponSpear.index] = {
                    [tool.propertyTypes.damage.index] = 2.0 * bronzeDamageMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "bronzeSpearBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeSpearHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 5.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    craftable:addCraftable("stonePickaxe", {
        name = locale:get("craftable_stonePickaxe"),
        plural = locale:get("craftable_stonePickaxe_plural"),
        summary = locale:get("craftable_stonePickaxe_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "stonePickaxe",
            resourceTypeIndex = resource.types.stonePickaxe.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = 2.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
                [tool.types.mine.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "stonePickaxeBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.stonePickaxeHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    craftable:addCraftable("flintPickaxe", {
        name = locale:get("craftable_flintPickaxe"),
        plural = locale:get("craftable_flintPickaxe_plural"),
        summary = locale:get("craftable_flintPickaxe_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "flintPickaxe",
            resourceTypeIndex = resource.types.flintPickaxe.index,
            preservesConstructionObjects = true,

            toolUsages = {
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = 2.0 * flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
                [tool.types.mine.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "flintPickaxeBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.flintPickaxeHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    craftable:addCraftable("bronzePickaxe", {
        name = locale:get("craftable_bronzePickaxe"),
        plural = locale:get("craftable_bronzePickaxe_plural"),
        summary = locale:get("craftable_bronzePickaxe_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "bronzePickaxe",
            resourceTypeIndex = resource.types.bronzePickaxe.index,
            preservesConstructionObjects = true,

            toolUsages = {
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = 2.0 * bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
                [tool.types.mine.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "bronzePickaxeBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzePickaxeHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    craftable:addCraftable("stoneHatchet", {
        name = locale:get("craftable_stoneHatchet"),
        plural = locale:get("craftable_stoneHatchet_plural"),
        summary = locale:get("craftable_stoneHatchet_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "stoneHatchet",
            resourceTypeIndex = resource.types.stoneHatchet.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = 2.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "stoneHatchetBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.stoneAxeHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })
    

    craftable:addCraftable("flintHatchet", {
        name = locale:get("craftable_flintHatchet"),
        plural = locale:get("craftable_flintHatchet_plural"),
        summary = locale:get("craftable_flintHatchet_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "flintHatchet",
            resourceTypeIndex = resource.types.flintHatchet.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = 2.0 * flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = 1.0 * flintDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "flintHatchetBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.flintAxeHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })
    
    craftable:addCraftable("bronzeHatchet", {
        name = locale:get("craftable_bronzeHatchet"),
        plural = locale:get("craftable_bronzeHatchet_plural"),
        summary = locale:get("craftable_bronzeHatchet_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "bronzeHatchet",
            resourceTypeIndex = resource.types.bronzeHatchet.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = 2.0 * bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "bronzeHatchetBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeAxeHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    
    local stoneAxeHeadFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stoneAxeHead", false, false)
    local stoneAxeHeadOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stoneAxeHead", false, false)

    craftable:addCraftable("stoneAxeHead", {
        name = locale:get("craftable_stoneAxeHead"),
        plural = locale:get("craftable_stoneAxeHead_plural"),
        nameGeneric = locale:get("craftable_stoneAxeHeadGeneric"),
        pluralGeneric = locale:get("craftable_stoneAxeHeadGeneric_plural"),
        summary = locale:get("craftable_stoneAxeHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stoneAxeHead.index,
            finalObjectInfosByResourceObjectType = stoneAxeHeadFinalObjectInfosByResourceObjectType,
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneAxeHeadOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmall.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })


    
    local stoneAxeHeadSoftFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stoneAxeHead", true, false)
    local stoneAxeHeadSoftOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stoneAxeHead", true, false)

    craftable:addCraftable("stoneAxeHeadSoft", {
        name = locale:get("craftable_stoneAxeHeadSoft"),
        plural = locale:get("craftable_stoneAxeHeadSoft_plural"),
        summary = locale:get("craftable_stoneAxeHeadSoft_summary"),
        classification = constructable.classifications.craft.index,
        iconGameObjectType = gameObject.typeIndexMap.stoneAxeHead_limestone,
        omitFromDiscoveryUI = true,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stoneAxeHeadSoft.index,
            finalObjectInfosByResourceObjectType = stoneAxeHeadSoftFinalObjectInfosByResourceObjectType,
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 0.5,
                },
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 0.5,
                },
            },
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneAxeHeadSoftOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index, actionSequenceRepeatCountFastestCompletion),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmallSoft.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })
    

    craftable:addCraftable("flintAxeHead", {
        name = locale:get("craftable_flintAxeHead"),
        plural = locale:get("craftable_flintAxeHead_plural"),
        summary = locale:get("craftable_flintAxeHead_summary"),
        addGameObjectInfo = {
            modelName = "flintAxeHead",
            resourceTypeIndex = resource.types.flintAxeHead.index,
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = flintSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = flintDurabilityMultiplier,
                },
            },
        },
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",
        classification = constructable.classifications.craft.index,
        
        skills = {
            required =  skill.types.flintKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.flint.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },
    })

    craftable:addCraftable("bronzeAxeHead", {
        name = locale:get("craftable_bronzeAxeHead"),
        plural = locale:get("craftable_bronzeAxeHead_plural"),
        summary = locale:get("craftable_bronzeAxeHead_summary"),
        addGameObjectInfo = {
            modelName = "bronzeAxeHead",
            resourceTypeIndex = resource.types.bronzeAxeHead.index,
            toolUsages = {
                [tool.types.treeChop.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
                [tool.types.dig.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable.smithingSequence,
        inProgressBuildModel = "craftSmith",
        classification = constructable.classifications.craft.index,
        
        skills = {
            required =  skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeIngot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 30.0,
                }
            },
        },
        requiredTools = {
            tool.types.hammering.index,
        },
        
        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
    })

    local stoneHammerHeadFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("stoneHammerHead", false, false)
    local stoneHammerHeadOutputArraysByResourceObjectType = createSmallRockOutputArraysByResourceObjectType("stoneHammerHead", false, false)
    
    craftable:addCraftable("stoneHammerHead", {
        name = locale:get("craftable_stoneHammerHead"),
        plural = locale:get("craftable_stoneHammerHead_plural"),
        summary = locale:get("craftable_stoneHammerHead_summary"),
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.stoneHammerHead.index,
            finalObjectInfosByResourceObjectType = stoneHammerHeadFinalObjectInfosByResourceObjectType,
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneHammerHeadOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                type = resource.types.rockSmall.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        },

        
        disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,
    })

    
    craftable:addCraftable("bronzeHammerHead", {
        name = locale:get("craftable_bronzeHammerHead"),
        plural = locale:get("craftable_bronzeHammerHead_plural"),
        summary = locale:get("craftable_bronzeHammerHead_summary"),
        addGameObjectInfo = {
            modelName = "bronzeHammerHead",
            resourceTypeIndex = resource.types.bronzeHammerHead.index,
        },

        buildSequence = craftable.smithingSequence,
        inProgressBuildModel = "craftSmith",
        classification = constructable.classifications.craft.index,
        
        skills = {
            required =  skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeIngot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 30.0,
                }
            },
        },
        requiredTools = {
            tool.types.hammering.index,
        },
        
        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
    })

    
    craftable:addCraftable("stoneHammer", {
        name = locale:get("craftable_stoneHammer"),
        plural = locale:get("craftable_stoneHammer_plural"),
        summary = locale:get("craftable_stoneHammer_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

        addGameObjectInfo = {
            modelName = "stoneHammer",
            resourceTypeIndex = resource.types.stoneHammer.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.hammering.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "stoneHammerBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.stoneHammerHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })

    
    craftable:addCraftable("bronzeHammer", {
        name = locale:get("craftable_bronzeHammer"),
        plural = locale:get("craftable_bronzeHammer_plural"),
        summary = locale:get("craftable_bronzeHammer_summary"),
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,

        addGameObjectInfo = {
            modelName = "bronzeHammer",
            resourceTypeIndex = resource.types.bronzeHammer.index,
            preservesConstructionObjects = true,
            
            toolUsages = {
                [tool.types.hammering.index] = {
                    [tool.propertyTypes.speed.index] = bronzeSpeedMultiplier,
                    [tool.propertyTypes.durability.index] = bronzeDurabilityMultiplier,
                },
            },
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
        inProgressBuildModel = "bronzeHammerBuild",

        skills = {
            required = skill.types.toolAssembly.index,
        },
        requiredResources = {
            {
                type = resource.types.bronzeHammerHead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.branch.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.flaxTwine.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            }
        },
    })
        
    craftable:addCraftable("splitLog", {
        name = locale:get("craftable_splitLog"),
        plural = locale:get("craftable_splitLog_plural"),
        summary = locale:get("craftable_splitLog_summary"),
        iconGameObjectType = gameObject.typeIndexMap.birchSplitLog,
        classification = constructable.classifications.craft.index,

        addGameObjectInfo = {
            resourceTypeIndex = resource.types.splitLog.index,
            placedVariantPathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
            finalObjectInfosByResourceObjectType = splitLogFinalObjectInfosByResourceObjectType,
            seatTypeIndex = seat.types.bench.index,
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = splitLogOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.scrapeWood.index, tool.types.carving.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.woodWorking.index,
        },
        requiredResources = {
            {
                type = resource.types.log.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.carving.index,
        },
    })
    

    craftable:addCraftable("butcherChicken", {
        name = locale:get("craftable_butcherChicken"),
        plural = locale:get("craftable_butcherChicken_plural"),
        summary = locale:get("craftable_butcherChicken_summary"),
        actionText = locale:get("order_butcher"),
        actionInProgressText = locale:get("order_butcher_inProgress"),
        actionObjectName = locale:get("object_chicken"),
        actionObjectNamePlural = locale:get("object_chicken_plural"),
        iconGameObjectType = gameObject.typeIndexMap.chickenMeat,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.chickenMeat,
                gameObject.typeIndexMap.chickenMeat,
                gameObject.typeIndexMap.chickenMeatBreast,
                gameObject.typeIndexMap.chickenMeatBreast,
            }
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.butcher.index, tool.types.butcher.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.butchery.index,
        },
        requiredResources = {
            {
                type = resource.types.deadChicken.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.butcher.index,
        }
    })
    
    local function createAlpacaButcherOutputArray(woolskinGameObjectTypeIndex)
        return {
            gameObject.typeIndexMap.alpacaMeatLeg,
            gameObject.typeIndexMap.alpacaMeatLeg,
            gameObject.typeIndexMap.alpacaMeatLeg,
            gameObject.typeIndexMap.alpacaMeatLeg,
            gameObject.typeIndexMap.alpacaMeatRack,
            gameObject.typeIndexMap.alpacaMeatRack,

            woolskinGameObjectTypeIndex,
            woolskinGameObjectTypeIndex,
            woolskinGameObjectTypeIndex,
            woolskinGameObjectTypeIndex,
        }
    end

    craftable:addCraftable("butcherAlpaca", {
        name = locale:get("craftable_butcherAlpaca"),
        plural = locale:get("craftable_butcherAlpaca_plural"),
        summary = locale:get("craftable_butcherAlpaca_summary"),
        actionText = locale:get("order_butcher"),
        actionInProgressText = locale:get("order_butcher_inProgress"),
        actionObjectName = locale:get("object_alpaca"),
        actionObjectNamePlural = locale:get("object_alpaca_plural"),
        iconGameObjectType = gameObject.typeIndexMap.alpacaMeatLeg,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = {
                [gameObject.typeIndexMap.deadAlpaca] = createAlpacaButcherOutputArray(gameObject.typeIndexMap.alpacaWoolskin),
                [gameObject.typeIndexMap.deadAlpaca_white] = createAlpacaButcherOutputArray(gameObject.typeIndexMap.alpacaWoolskin_white),
                [gameObject.typeIndexMap.deadAlpaca_black] = createAlpacaButcherOutputArray(gameObject.typeIndexMap.alpacaWoolskin_black),
                [gameObject.typeIndexMap.deadAlpaca_red] = createAlpacaButcherOutputArray(gameObject.typeIndexMap.alpacaWoolskin_red),
                [gameObject.typeIndexMap.deadAlpaca_yellow] = createAlpacaButcherOutputArray(gameObject.typeIndexMap.alpacaWoolskin_yellow),
                [gameObject.typeIndexMap.deadAlpaca_cream] = createAlpacaButcherOutputArray(gameObject.typeIndexMap.alpacaWoolskin_cream),
            }
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.butcher.index, tool.types.butcher.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.butchery.index,
        },
        requiredResources = {
            {
                type = resource.types.deadAlpaca.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.butcher.index,
        },
    })

    
    

    craftable:addCraftable("fishFillet", {
        name = locale:get("craftable_fishFillet"),
        plural = locale:get("craftable_fishFillet_plural"),
        summary = locale:get("craftable_fishFillet_summary"),
        actionText = locale:get("order_butcher"),
        actionInProgressText = locale:get("order_butcher_inProgress"),
        actionObjectName = locale:get("object_swordfish"), --should just use a generic "large fish" if more are added
        actionObjectNamePlural = locale:get("object_swordfish_plural"),
        iconGameObjectType = gameObject.typeIndexMap.fishFillet,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        
        outputDisplayCounts = {
            {
                type = resource.types.fish.index,
                objectType = gameObject.typeIndexMap.fishFillet,
                count = 10
            },
            {
                type = resource.types.bone.index,
                objectType = gameObject.typeIndexMap.fishBones,
                count = 3
            },
        },

        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,
                gameObject.typeIndexMap.fishFillet,

                gameObject.typeIndexMap.fishBones,
                gameObject.typeIndexMap.fishBones,
                gameObject.typeIndexMap.fishBones,
            }
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.butcher.index, tool.types.butcher.index),
        inProgressBuildModel = "craftSimple",
        
        skills = {
            required = skill.types.butchery.index,
        },
        requiredResources = {
            {
                type = resource.types.swordfishDead.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.butcher.index,
        },
    })
    

    craftable:addCraftable("cookedChicken", {
        name = locale:get("craftable_cookedChicken"),
        plural = locale:get("craftable_cookedChicken_plural"),
        summary = locale:get("craftable_cookedChicken_summary"),
        iconGameObjectType = gameObject.typeIndexMap.chickenMeatCooked,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = {
                [gameObject.typeIndexMap.chickenMeat] = {
                    gameObject.typeIndexMap.chickenMeatCooked,
                },
                [gameObject.typeIndexMap.chickenMeatBreast] = {
                    gameObject.typeIndexMap.chickenMeatBreastCooked,
                },
            }
        },
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.campfireCooking.index,
        },

        requiredResources = {
            {
                type = resource.types.chickenMeat.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        attachResourceToHandIndex = 1,
        attachResourceOffset = vec3xMat3(vec3(-0.7,0.1,0.02), craftable.cookingStickRotationOffset),
        attachResourceRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    craftable:addCraftable("cookedAlpaca", {
        name = locale:get("craftable_cookedAlpaca"),
        plural = locale:get("craftable_cookedAlpaca_plural"),
        summary = locale:get("craftable_cookedAlpaca_summary"),
        iconGameObjectType = gameObject.typeIndexMap.alpacaMeatRackCooked,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = {
                [gameObject.typeIndexMap.alpacaMeatLeg] = {
                    gameObject.typeIndexMap.alpacaMeatLegCooked,
                },
                [gameObject.typeIndexMap.alpacaMeatRack] = {
                    gameObject.typeIndexMap.alpacaMeatRackCooked,
                },
            }
        },
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.campfireCooking.index,
        },

        requiredResources = {
            {
                type = resource.types.alpacaMeat.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        attachResourceToHandIndex = 1,
        attachResourceOffset = vec3xMat3(vec3(-0.7,0.1,0.02), craftable.cookingStickRotationOffset),
        attachResourceRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    craftable:addCraftable("cookedMammoth", {
        name = locale:get("craftable_cookedMammoth"),
        plural = locale:get("craftable_cookedMammoth_plural"),
        summary = locale:get("craftable_cookedMammoth_summary"),
        iconGameObjectType = gameObject.typeIndexMap.mammothMeatTBoneCooked,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = {
                [gameObject.typeIndexMap.mammothMeat] = {
                    gameObject.typeIndexMap.mammothMeatCooked,
                },
                [gameObject.typeIndexMap.mammothMeatTBone] = {
                    gameObject.typeIndexMap.mammothMeatTBoneCooked,
                },
            }
        },
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.campfireCooking.index,
        },

        requiredResources = {
            {
                type = resource.types.mammothMeat.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        attachResourceToHandIndex = 1,
        attachResourceOffset = vec3xMat3(vec3(-0.7,0.1,0.02), craftable.cookingStickRotationOffset),
        attachResourceRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    craftable:addCraftable("campfireRoastedPumpkin", {
        name = locale:get("craftable_campfireRoastedPumpkin"),
        plural = locale:get("craftable_campfireRoastedPumpkin_plural"),
        summary = locale:get("craftable_campfireRoastedPumpkin_summary"),
        iconGameObjectType = gameObject.typeIndexMap.pumpkinCooked,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.pumpkinCooked,
            }
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.campfireCooking.index,
        },

        requiredResources = {
            {
                type = resource.types.pumpkin.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        attachResourceToHandIndex = 1,
        attachResourceOffset = vec3xMat3(vec3(-0.7,0.1,0.02), craftable.cookingStickRotationOffset),
        attachResourceRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    craftable:addCraftable("campfireRoastedBeetroot", {
        name = locale:get("craftable_campfireRoastedBeetroot"),
        plural = locale:get("craftable_campfireRoastedBeetroot_plural"),
        summary = locale:get("craftable_campfireRoastedBeetroot_summary"),
        iconGameObjectType = gameObject.typeIndexMap.beetrootCooked,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.beetrootCooked,
            }
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.campfireCooking.index,
        },

        requiredResources = {
            {
                type = resource.types.beetroot.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        attachResourceToHandIndex = 1,
        attachResourceOffset = vec3xMat3(vec3(-0.7,0.1,0.02), craftable.cookingStickRotationOffset),
        attachResourceRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    

    craftable:addCraftable("cookedFish", {
        name = locale:get("craftable_cookedFish"),
        plural = locale:get("craftable_cookedFish_plural"),
        summary = locale:get("craftable_cookedFish_summary"),
        iconGameObjectType = gameObject.typeIndexMap.fishFilletCooked,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = {
                [gameObject.typeIndexMap.catfishDead] = {
                    gameObject.typeIndexMap.catfishCooked,
                },
                [gameObject.typeIndexMap.coelacanthDead] = {
                    gameObject.typeIndexMap.coelacanthCooked,
                },
                [gameObject.typeIndexMap.flagellipinnaDead] = {
                    gameObject.typeIndexMap.flagellipinnaCooked,
                },
                [gameObject.typeIndexMap.polypterusDead] = {
                    gameObject.typeIndexMap.polypterusCooked,
                },
                [gameObject.typeIndexMap.redfishDead] = {
                    gameObject.typeIndexMap.redfishCooked,
                },
                [gameObject.typeIndexMap.tropicalfishDead] = {
                    gameObject.typeIndexMap.tropicalfishCooked,
                },
                [gameObject.typeIndexMap.fishFillet] = {
                    gameObject.typeIndexMap.fishFilletCooked,
                },
            }
        },
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.campfireCooking.index,
        },

        requiredResources = {
            {
                type = resource.types.fish.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        attachResourceToHandIndex = 1,
        attachResourceOffset = vec3xMat3(vec3(-0.7,0.1,0.02), craftable.cookingStickRotationOffset),
        attachResourceRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })
    
    
    
    craftable:addCraftable("firedUrn", {
        name = locale:get("craftable_firedUrn"),
        plural = locale:get("craftable_firedUrn_plural"),
        summary = locale:get("craftable_firedUrn_summary"),
        iconGameObjectType = gameObject.typeIndexMap["firedUrn"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.potteryFiring.index,
        },
        requiredResources = {
            {
                type = resource.types.unfiredUrnDry.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
        
        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })
    
    craftable:addCraftable("firedBowl", {
        name = locale:get("craftable_firedBowl"),
        plural = locale:get("craftable_firedBowl_plural"),
        summary = locale:get("craftable_firedBowl_summary"),
        iconGameObjectType = gameObject.typeIndexMap["firedBowl"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.potteryFiring.index,
        },
        requiredResources = {
            {
                type = resource.types.unfiredBowlDry.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
        
        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })
    
    craftable:addCraftable("flaxTwine", {
        name = locale:get("craftable_flaxTwine"),
        plural = locale:get("craftable_flaxTwine_plural"),
        summary = locale:get("craftable_flaxTwine_summary"),
        iconGameObjectType = gameObject.typeIndexMap["flaxTwine"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.spinCraft.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.spinning.index,
        },
        requiredResources = {
            {
                type = resource.types.flaxDried.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })

    
    craftable:addCraftable("unfiredUrnWet", {
        name = locale:get("craftable_unfiredUrnWet"),
        plural = locale:get("craftable_unfiredUrnWet_plural"),
        summary = locale:get("craftable_unfiredUrnWet_summary"),
        iconGameObjectType = gameObject.typeIndexMap["unfiredUrnDry"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.potteryCraft.index, nil),
        inProgressBuildModel = "craftSimple",

        outputDisplayCounts = {
            {
                type = resource.types.unfiredUrnDry.index,
                count = 1
            }
        },

        skills = {
            required = skill.types.pottery.index,
        },
        requiredResources = {
            {
                type = resource.types.clay.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })

    
    
    craftable:addCraftable("unfiredBowlWet", {
        name = locale:get("craftable_unfiredBowlWet"),
        plural = locale:get("craftable_unfiredBowlWet_plural"),
        summary = locale:get("craftable_unfiredBowlWet_summary"),
        iconGameObjectType = gameObject.typeIndexMap["unfiredBowlDry"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.potteryCraft.index, nil),
        inProgressBuildModel = "craftSimple",
        
        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.unfiredBowlWet,
                gameObject.typeIndexMap.unfiredBowlWet,
            }
        },

        outputDisplayCounts = {
            {
                type = resource.types.unfiredBowlDry.index,
                count = 2
            }
        },

        skills = {
            required = skill.types.pottery.index,
        },
        requiredResources = {
            {
                type = resource.types.clay.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })

    
    
    
    craftable:addCraftable("crucibleWet", {
        name = locale:get("craftable_crucibleWet"),
        plural = locale:get("craftable_crucibleWet_plural"),
        summary = locale:get("craftable_crucibleWet_summary"),
        iconGameObjectType = gameObject.typeIndexMap["crucibleDry"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.potteryCraft.index, nil),
        inProgressBuildModel = "craftSimple",
        
        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.crucibleWet,
            }
        },

        outputDisplayCounts = {
            {
                type = resource.types.crucibleDry.index,
                count = 1
            }
        },

        skills = {
            required = skill.types.pottery.index,
        },
        requiredResources = {
            {
                type = resource.types.clay.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })
    
    local hulledWheatOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredUrnDry.index] = {
            gameObject.typeIndexMap.unfiredUrnHulledWheat,
        },
        [gameObject.types.firedUrn.index] = {
            gameObject.typeIndexMap.firedUrnHulledWheat,
        },
    }

    craftable:addCraftable("hulledWheat", {
        name = locale:get("craftable_hulledWheat"),
        plural = locale:get("craftable_hulledWheat_plural"),
        summary = locale:get("craftable_hulledWheat_summary"),
        iconGameObjectType = gameObject.typeIndexMap.firedUrnHulledWheat,
        classification = constructable.classifications.craft.index,
        disallowsLimitedAbilitySapiens = true,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = hulledWheatOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                group = resource.groups.urnHulledWheat.index,
                count = 1
            }
        },

        buildSequence = craftable.threshingSequence,
        inProgressBuildModel = "craftThreshing",

        skills = {
            required = skill.types.threshing.index,
        },

        requiredResources = {
            {
                type = resource.types.wheat.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                group = resource.groups.container.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        
        attachResourceToHandIndex = 1,
        --attachResourceOffset = vec3(0.0,0.0,0.0),
        attachResourceOffset = vec3(-0.1,0.2,0.1),
        attachResourceRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi + 0.6, vec3(0.0,1.0,0.0)), 0.8, vec3(0.0,0.0,1.0)),
        --attachResourceRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0,1.0,0.0)),
    })

    
    local quernstoneFinalObjectInfosByResourceObjectType = createRockFinalObjectInfos("quernstone", nil, false)
    local quernstoneOutputArraysByResourceObjectType = createStandardRockOutputArraysByResourceObjectType("quernstone", nil, false)

    craftable:addCraftable("quernstone", {
        name = locale:get("craftable_quernstone"),
        plural = locale:get("craftable_quernstone_plural"),
        summary = locale:get("craftable_quernstone_summary"),
        iconGameObjectType = gameObject.typeIndexMap.quernstone,
        classification = constructable.classifications.craft.index,
    
        addGameObjectInfo = {
            resourceTypeIndex = resource.types.quernstone.index,
            finalObjectInfosByResourceObjectType = quernstoneFinalObjectInfosByResourceObjectType,
            toolUsages = {
                [tool.types.grinding.index] = {
                    [tool.propertyTypes.speed.index] = 1.0,
                    [tool.propertyTypes.durability.index] = 1.0,
                },
            },
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = quernstoneOutputArraysByResourceObjectType
        },
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",

        disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,

        skills = {
            required = skill.types.rockKnapping.index,
        },
        requiredResources = {
            {
                group = resource.groups.rockAny.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.knapping.index,
        }
        
    })

    
    local flourOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredUrnHulledWheat.index] = {
            gameObject.typeIndexMap.unfiredUrnFlour,
        },
        [gameObject.types.firedUrnHulledWheat.index] = {
            gameObject.typeIndexMap.firedUrnFlour,
        },
    }
    
    craftable:addCraftable("flour", {
        name = locale:get("craftable_flour"),
        plural = locale:get("craftable_flour_plural"),
        summary = locale:get("craftable_flour_summary"),
        iconGameObjectType = gameObject.typeIndexMap.firedUrnFlour,
        classification = constructable.classifications.craft.index,
        placeBuildObjectsInFinalLocationsOnDropOff = true,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = flourOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                group = resource.groups.urnFlour.index,
                count = 1
            }
        },

        buildSequence = craftable.grindingSequence,
        inProgressBuildModel = "craftGrinding",

        skills = {
            required = skill.types.grinding.index,
        },

        requiredResources = {
            {
                group = resource.groups.urnHulledWheat.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.grinding.index,
        },

        dontPickUpRequiredTool = true,
        
        
        temporaryToolObjectType = gameObject.typeIndexMap.rockSmall,
        temporaryToolOffset = vec3(0.0,0.01,0.0),
        temporaryToolRotation = mat3Identity,

        --[[attachResourceToHandIndex = 1,
        attachResourceOffset = vec3(-0.1,0.2,0.1),
        attachResourceRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi + 0.6, vec3(0.0,1.0,0.0)), 0.8, vec3(0.0,0.0,1.0)),]]
    })

    
    local breadDoughOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredUrnFlour.index] = {
            gameObject.typeIndexMap.breadDough,
            gameObject.typeIndexMap.unfiredUrnDry,
        },
        [gameObject.types.firedUrnFlour.index] = {
            gameObject.typeIndexMap.breadDough,
            gameObject.typeIndexMap.firedUrn,
        },
    }

    craftable:addCraftable("breadDough", {
        name = locale:get("craftable_breadDough"),
        plural = locale:get("craftable_breadDough_plural"),
        summary = locale:get("craftable_breadDough_summary"),
        iconGameObjectType = gameObject.typeIndexMap.breadDough,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = breadDoughOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                type = resource.types.breadDough.index,
                count = 1
            }
        },
        
        buildSequence = craftable.kneedingSequence,
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.baking.index,
        },
        requiredResources = {
            {
                group = resource.groups.urnFlour.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        
    })

    
    craftable:addCraftable("flatbread", {
        name = locale:get("craftable_flatbread"),
        plural = locale:get("craftable_flatbread_plural"),
        summary = locale:get("craftable_flatbread_summary"),
        iconGameObjectType = gameObject.typeIndexMap.flatbread,
        classification = constructable.classifications.craft.index,
        isFoodPreperation = true,

        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.flatbread,
                gameObject.typeIndexMap.flatbread,
                gameObject.typeIndexMap.flatbread,
                gameObject.typeIndexMap.flatbread,
                gameObject.typeIndexMap.flatbread,
            }
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "campfireRockCooking",

        skills = {
            required = skill.types.baking.index,
        },

        requiredResources = {
            {
                type = resource.types.breadDough.index,
                count = 1,
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.campfire.index,
        },

        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    
    craftable:addCraftable("thatchResearch", {
        name = locale:get("craftable_thatchResearch"),
        plural = locale:get("craftable_thatchResearch_plural"),
        summary = locale:get("craftable_thatchResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        --disallowsLimitedAbilitySapiens = true,
        
        buildSequence = craftable.researchBuildSequence,
        inProgressBuildModel = "thatchResearch",

        requiredResources = {
            {
                type = resource.types.branch.index,
                count = 2,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
            {
                type = resource.types.hay.index,
                count = 1,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
    })

    craftable:addCraftable("mudBrickBuildingResearch", {
        name = locale:get("craftable_mudBrickBuildingResearch"),
        plural = locale:get("craftable_mudBrickBuildingResearch_plural"),
        summary = locale:get("craftable_mudBrickBuildingResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        --disallowsLimitedAbilitySapiens = true,
        
        buildSequence = craftable.researchBuildSequence,
        inProgressBuildModel = "mudBrickBuildingResearch",

        requiredResources = {
            {
                type = resource.types.mudBrickDry.index,
                count = 2,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
    })
    
    craftable:addCraftable("brickBuildingResearch", {
        name = locale:get("craftable_mudBrickBuildingResearch"),
        plural = locale:get("craftable_mudBrickBuildingResearch_plural"),
        summary = locale:get("craftable_mudBrickBuildingResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        --disallowsLimitedAbilitySapiens = true,
        
        buildSequence = craftable.researchBuildSequence,
        inProgressBuildModel = "brickBuildingResearch",

        requiredResources = {
            {
                type = resource.types.firedBrick.index,
                count = 2,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
    })


    craftable:addCraftable("stoneBlockBuildingResearch", {
        name = locale:get("craftable_mudBrickBuildingResearch"),
        plural = locale:get("craftable_mudBrickBuildingResearch_plural"),
        summary = locale:get("craftable_mudBrickBuildingResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        --disallowsLimitedAbilitySapiens = true,
        
        buildSequence = craftable.researchBuildSequence,
        inProgressBuildModel = "stoneBlockBuildingResearch",

        requiredResources = {
            {
                group = resource.groups.stoneBlockAny.index,
                count = 2,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
    })
    
    
    craftable:addCraftable("woodBuildingResearch", {
        name = locale:get("craftable_woodBuildingResearch"),
        plural = locale:get("craftable_woodBuildingResearch_plural"),
        summary = locale:get("craftable_woodBuildingResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        
        buildSequence = craftable.researchBuildSequence,
        inProgressBuildModel = "woodBuildingResearch",

        requiredResources = {
            {
                type = resource.types.splitLog.index,
                count = 4,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
    })

    craftable:addCraftable("tilingResearch", {
        name = locale:get("craftable_tilingResearch"),
        plural = locale:get("craftable_tilingResearch_plural"),
        summary = locale:get("craftable_tilingResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        
        buildSequence = craftable.researchBuildSequence,
        inProgressBuildModel = "tilingResearch",

        requiredResources = {
            {
                type = resource.types.firedTile.index,
                count = 2,
                restoreOnCompletion = true,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
    })
    
    craftable:addCraftable("plantingResearch", {
        name = locale:get("craftable_plantingResearch"),
        plural = locale:get("craftable_plantingResearch_plural"),
        summary = locale:get("craftable_plantingResearch_summary"),
        hasNoOutput = true,
        classification = constructable.classifications.research.index,
        disallowsLimitedAbilitySapiens = true,
        
        buildSequence = craftable.researchPlantSequence,
        inProgressBuildModel = "plantingResearch",

        requiredResources = {
            {
                group = resource.groups.seed.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.patDown.index,
                    duration = 15.0,
                    durationWithoutSkill = 15.0,
                },
            },
        },
        requiredTools = {
            tool.types.dig.index,
        },

    })
    
    local mudBrickOutputArraysByResourceObjectType = {
        [gameObject.types.sand.index] = {
            gameObject.typeIndexMap.mudBrickWet_sand,
            gameObject.typeIndexMap.mudBrickWet_sand,
        },
        [gameObject.types.riverSand.index] = {
            gameObject.typeIndexMap.mudBrickWet_riverSand,
            gameObject.typeIndexMap.mudBrickWet_riverSand,
        },
        [gameObject.types.redSand.index] = {
            gameObject.typeIndexMap.mudBrickWet_redSand,
            gameObject.typeIndexMap.mudBrickWet_redSand,
        },
        [gameObject.types.hay.index] = {
            gameObject.typeIndexMap.mudBrickWet_hay,
            gameObject.typeIndexMap.mudBrickWet_hay,
        },
    }
    
    craftable:addCraftable("mudBrickWet", {
        name = locale:get("craftable_mudBrickWet"),
        plural = locale:get("craftable_mudBrickWet_plural"),
        summary = locale:get("craftable_mudBrickWet_summary"),
        iconGameObjectType = gameObject.typeIndexMap["mudBrickDry_sand"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.potteryCraft.index, nil),
        inProgressBuildModel = "craftMudBrick",
        
        outputObjectInfo = {
            outputArraysByResourceObjectType = mudBrickOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                type = resource.types.mudBrickDry.index,
                count = 2
            }
        },
        
        skills = {
            required = skill.types.pottery.index,
        },
        requiredResources = {
            {
                type = resource.types.clay.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                group = resource.groups.brickBinder.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })
    
    
    craftable:addCraftable("mudTileWet", {
        name = locale:get("craftable_mudTileWet"),
        plural = locale:get("craftable_mudTileWet_plural"),
        summary = locale:get("craftable_mudTileWet_summary"),
        iconGameObjectType = gameObject.typeIndexMap["mudTileDry"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.potteryCraft.index, nil),
        inProgressBuildModel = "craftSimple",
        
        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.mudTileWet,
                gameObject.typeIndexMap.mudTileWet,
            }
        },

        outputDisplayCounts = {
            {
                type = resource.types.mudTileDry.index,
                count = 2
            }
        },
        
        disabledUntilAdditionalResearchDiscovered = research.typeIndexMap.pottery,
        
        skills = {
            required = skill.types.pottery.index,
        },
        requiredResources = {
            {
                type = resource.types.clay.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })
    
    
    craftable:addCraftable("firedTile", {
        name = locale:get("craftable_firedTile"),
        plural = locale:get("craftable_firedTile_plural"),
        summary = locale:get("craftable_firedTile_summary"),
        iconGameObjectType = gameObject.typeIndexMap["firedTile"],
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.potteryFiring.index,
        },
        requiredResources = {
            {
                type = resource.types.mudTileDry.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
        
        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    local stoneTileSoftFinalObjectInfosByResourceObjectType = createStoneBlockFinalObjectInfos("stoneTile", true)
    local stoneTileSoftOutputArraysByResourceObjectType = createStoneBlockOutputArraysByResourceObjectType("stoneTile", true)
    
    craftable:addCraftable("stoneTileSoft", {
        name = locale:get("craftable_stoneTileSoft"),
        plural = locale:get("craftable_stoneTileSoft_plural"),
        summary = locale:get("craftable_stoneTileSoft_summary"),
        iconGameObjectType = gameObject.typeIndexMap["stoneTile_limestone"],
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        
        addGameObjectInfo = {
            resourceTypeIndex = resource.types.firedTile.index,
            finalObjectInfosByResourceObjectType = stoneTileSoftFinalObjectInfosByResourceObjectType,
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneTileSoftOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.chiselStone.index, tool.types.softChiselling.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.chiselStone.index,
        },
        requiredResources = {
            {
                type = resource.types.stoneBlockSoft.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.softChiselling.index,
        },
    })

    
    local stoneTileHardFinalObjectInfosByResourceObjectType = createStoneBlockFinalObjectInfos("stoneTile", false)
    local stoneTileHardOutputArraysByResourceObjectType = createStoneBlockOutputArraysByResourceObjectType("stoneTile", false)
    
    craftable:addCraftable("stoneTileHard", {
        name = locale:get("craftable_stoneTileHard"),
        plural = locale:get("craftable_stoneTileHard_plural"),
        nameGeneric = locale:get("craftable_stoneTileGeneric"),
        pluralGeneric = locale:get("craftable_stoneTileGeneric_plural"),
        summary = locale:get("craftable_stoneTileHard_summary"),
        iconGameObjectType = gameObject.typeIndexMap["stoneTile"],
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        
        addGameObjectInfo = {
            resourceTypeIndex = resource.types.firedTile.index,
            finalObjectInfosByResourceObjectType = stoneTileHardFinalObjectInfosByResourceObjectType,
        },

        outputObjectInfo = {
            outputArraysByResourceObjectType = stoneTileHardOutputArraysByResourceObjectType
        },

        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.knap.index, tool.types.knapping.index),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.chiselStone.index,
        },
        requiredResources = {
            {
                type = resource.types.stoneBlockHard.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.hardChiselling.index,
        },
    })
    

    local firedBrickOutputArraysByResourceObjectType = {
        [gameObject.types.mudBrickDry_sand.index] = {
            gameObject.typeIndexMap.firedBrick_sand,
        },
        [gameObject.types.mudBrickDry_riverSand.index] = {
            gameObject.typeIndexMap.firedBrick_riverSand,
        },
        [gameObject.types.mudBrickDry_redSand.index] = {
            gameObject.typeIndexMap.firedBrick_redSand,
        },
        [gameObject.types.mudBrickDry_hay.index] = {
            gameObject.typeIndexMap.firedBrick_hay,
        },
    }
    
    craftable:addCraftable("firedBrick", {
        name = locale:get("craftable_firedBrick"),
        plural = locale:get("craftable_firedBrick_plural"),
        summary = locale:get("craftable_firedBrick_summary"),
        iconGameObjectType = gameObject.typeIndexMap["firedBrick_sand"],
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.fireStickCook.index, nil),
        inProgressBuildModel = "craftSimple",

        outputObjectInfo = {
            outputArraysByResourceObjectType = firedBrickOutputArraysByResourceObjectType
        },

        skills = {
            required = skill.types.potteryFiring.index,
        },
        requiredResources = {
            {
                type = resource.types.mudBrickDry.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },
        
        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    
    local injuryMedicineOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredBowlDry.index] = {
            gameObject.typeIndexMap.unfiredBowlInjuryMedicine,
        },
        [gameObject.types.firedBowl.index] = {
            gameObject.typeIndexMap.firedBowlInjuryMedicine,
        },
    }
    
    craftable:addCraftable("injuryMedicine", {
        name = locale:get("craftable_injuryMedicine"),
        plural = locale:get("craftable_injuryMedicine_plural"),
        summary = locale:get("craftable_injuryMedicine_summary"),
        iconGameObjectType = gameObject.typeIndexMap.firedBowlInjuryMedicine,
        classification = constructable.classifications.craft.index,
        placeBuildObjectsInFinalLocationsOnDropOff = true,
        disabledUntilCraftableResearched = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = injuryMedicineOutputArraysByResourceObjectType
        },


        outputDisplayCounts = {
            {
                group = resource.groups.injuryMedicine.index,
                count = 1
            }
        },

        buildSequence = craftable.grindingSequence,
        inProgressBuildModel = "craftMedicine",

        skills = {
            required = skill.types.medicine.index,
        },

        requiredResources = {
            {
                group = resource.groups.bowl.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.poppyFlower.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.marigoldFlower.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.turmericRoot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.grinding.index,
        },

        dontPickUpRequiredTool = true,
        
        temporaryToolObjectType = gameObject.typeIndexMap.rockSmall,
        temporaryToolOffset = vec3(0.0,0.01,0.0),
        temporaryToolRotation = mat3Identity,
    })

    local burnMedicineOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredBowlDry.index] = {
            gameObject.typeIndexMap.unfiredBowlBurnMedicine,
        },
        [gameObject.types.firedBowl.index] = {
            gameObject.typeIndexMap.firedBowlBurnMedicine,
        },
    }
    
    craftable:addCraftable("burnMedicine", {
        name = locale:get("craftable_burnMedicine"),
        plural = locale:get("craftable_burnMedicine_plural"),
        summary = locale:get("craftable_burnMedicine_summary"),
        iconGameObjectType = gameObject.typeIndexMap.firedBowlBurnMedicine,
        classification = constructable.classifications.craft.index,
        placeBuildObjectsInFinalLocationsOnDropOff = true,
        disabledUntilCraftableResearched = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = burnMedicineOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                group = resource.groups.burnMedicine.index,
                count = 1
            }
        },

        buildSequence = craftable.grindingSequence,
        inProgressBuildModel = "craftMedicine",

        skills = {
            required = skill.types.medicine.index,
        },

        requiredResources = {
            {
                group = resource.groups.bowl.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.aloeLeaf.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.elderberry.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.marigoldFlower.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.grinding.index,
        },

        dontPickUpRequiredTool = true,
        
        temporaryToolObjectType = gameObject.typeIndexMap.rockSmall,
        temporaryToolOffset = vec3(0.0,0.01,0.0),
        temporaryToolRotation = mat3Identity,
    })

    local foodPoisoningMedicineOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredBowlDry.index] = {
            gameObject.typeIndexMap.unfiredBowlFoodPoisoningMedicine,
        },
        [gameObject.types.firedBowl.index] = {
            gameObject.typeIndexMap.firedBowlFoodPoisoningMedicine,
        },
    }
    
    craftable:addCraftable("foodPoisoningMedicine", {
        name = locale:get("craftable_foodPoisoningMedicine"),
        plural = locale:get("craftable_foodPoisoningMedicine_plural"),
        summary = locale:get("craftable_foodPoisoningMedicine_summary"),
        iconGameObjectType = gameObject.typeIndexMap.firedBowlFoodPoisoningMedicine,
        classification = constructable.classifications.craft.index,
        placeBuildObjectsInFinalLocationsOnDropOff = true,
        disabledUntilCraftableResearched = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = foodPoisoningMedicineOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                group = resource.groups.foodPoisoningMedicine.index,
                count = 1
            }
        },

        buildSequence = craftable.grindingSequence,
        inProgressBuildModel = "craftMedicine",

        skills = {
            required = skill.types.medicine.index,
        },

        requiredResources = {
            {
                group = resource.groups.bowl.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.gingerRoot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.turmericRoot.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.garlic.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.grinding.index,
        },

        dontPickUpRequiredTool = true,
        
        temporaryToolObjectType = gameObject.typeIndexMap.rockSmall,
        temporaryToolOffset = vec3(0.0,0.01,0.0),
        temporaryToolRotation = mat3Identity,
    })

    local virusMedicineOutputArraysByResourceObjectType = {
        [gameObject.types.unfiredBowlDry.index] = {
            gameObject.typeIndexMap.unfiredBowlVirusMedicine,
        },
        [gameObject.types.firedBowl.index] = {
            gameObject.typeIndexMap.firedBowlVirusMedicine,
        },
    }
    
    craftable:addCraftable("virusMedicine", {
        name = locale:get("craftable_virusMedicine"),
        plural = locale:get("craftable_virusMedicine_plural"),
        summary = locale:get("craftable_virusMedicine_summary"),
        iconGameObjectType = gameObject.typeIndexMap.firedBowlVirusMedicine,
        classification = constructable.classifications.craft.index,
        placeBuildObjectsInFinalLocationsOnDropOff = true,
        disabledUntilCraftableResearched = true,

        outputObjectInfo = {
            outputArraysByResourceObjectType = virusMedicineOutputArraysByResourceObjectType
        },

        outputDisplayCounts = {
            {
                group = resource.groups.virusMedicine.index,
                count = 1
            }
        },

        buildSequence = craftable.grindingSequence,
        inProgressBuildModel = "craftMedicine",

        skills = {
            required = skill.types.medicine.index,
        },

        requiredResources = {
            {
                group = resource.groups.bowl.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.echinaceaFlower.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.garlic.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.elderberry.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        requiredTools = {
            tool.types.grinding.index,
        },

        dontPickUpRequiredTool = true,
        
        temporaryToolObjectType = gameObject.typeIndexMap.rockSmall,
        temporaryToolOffset = vec3(0.0,0.01,0.0),
        temporaryToolRotation = mat3Identity,
    })

    
    
    
    craftable:addCraftable("bronzeIngot", {
        name = locale:get("craftable_bronzeIngot"),
        plural = locale:get("craftable_bronzeIngot_plural"),
        summary = locale:get("craftable_bronzeIngot_summary"),
        iconGameObjectType = gameObject.typeIndexMap["bronzeIngot"],
        classification = constructable.classifications.craft.index,
        disabledUntilCraftableResearched = true,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.smeltMetal.index, tool.types.crucible.index, actionSequenceRepeatCountSmelting),
        inProgressBuildModel = "craftCrucible",
        
        outputObjectInfo = {
            objectTypesArray = {
                gameObject.typeIndexMap.bronzeIngot,
                gameObject.typeIndexMap.bronzeIngot,
                gameObject.typeIndexMap.bronzeIngot,
            }
        },

        skills = {
            required = skill.types.blacksmithing.index,
        },
        requiredResources = {
            {
                type = resource.types.copperOre.index,
                count = 2,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
            {
                type = resource.types.tinOre.index,
                count = 1,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
        
        requiredTools = {
            tool.types.crucible.index,
        },

        requiredCraftAreaGroups = {
            craftAreaGroup.types.kiln.index,
        },

        
        dontPickUpRequiredTool = true,
        
        temporaryToolObjectType = gameObject.typeIndexMap.stick,
        temporaryToolOffset = vec3xMat3(vec3(-0.35,0.0,0.0), craftable.cookingStickRotationOffset),
        temporaryToolRotation = craftable.cookingStickRotation,
    })

    
    craftable:addCraftable("compost", { --only added for the compost research, this cannot be crafted, use a compost bin instead
        name = locale:get("object_compost"),
        plural = locale:get("object_compost"),
        summary = locale:get("object_compost"),
        iconGameObjectType = gameObject.typeIndexMap["compost"],
        classification = constructable.classifications.craft.index,
        
        buildSequence = craftable:createStandardBuildSequence(actionSequence.types.potteryCraft.index, nil),
        inProgressBuildModel = "craftSimple",

        skills = {
            required = skill.types.gathering.index,
        },
        requiredResources = {
            {
                group = resource.groups.compostable.index,
                count = 6,
                afterAction = {
                    actionTypeIndex = action.types.inspect.index,
                    duration = 1.0,
                    durationWithoutSkill = 15.0,
                }
            },
        },
    })

end


return craftable