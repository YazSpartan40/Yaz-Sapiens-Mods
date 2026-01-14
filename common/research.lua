--local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
--local vec3xMat3 = mjm.vec3xMat3
--local mat3Identity = mjm.mat3Identity
--local mat3Rotate = mjm.mat3Rotate
--local mat3Inverse = mjm.mat3Inverse

local resource = mjrequire "common/resource"
local tool = mjrequire "common/tool"
local order = mjrequire "common/order"
local skill = mjrequire "common/skill"
local plan = mjrequire "common/plan"
--local actionSequence = mjrequire "common/actionSequence"
local locale = mjrequire "common/locale"

local typeMaps = mjrequire "common/typeMaps"
local typeIndexMap = typeMaps.types.researchable

local constructable = nil

local research = {
    types = {},
    researchTypesByResourceType = {},
    researchTypesBySkillType = {},
    typeIndexMap = typeIndexMap
}

 --0.5.0.0
--[[local phaseAResearchSpeed = 1.0/8.0
local phaseBResearchSpeed = 1.0/12.0
local phaseCResearchSpeed = 1.0/16.0
local phaseDResearchSpeed = 1.0/20.0
local phaseEResearchSpeed = 1.0/24.0]]

 --0.5.0.4
local phaseAResearchSpeed = 1.0/2.0
local phaseBResearchSpeed = 1.0/4.0
local phaseCResearchSpeed = 1.0/6.0
local phaseDResearchSpeed = 1.0/8.0
local phaseEResearchSpeed = 1.0/10.0


function research:updateDerivedInfo(researchType)


    if researchType.skillTypeIndex then
        if not researchType.name then
            researchType.name = skill.types[researchType.skillTypeIndex].name
        end
        if not researchType.icon then
            researchType.icon = skill.types[researchType.skillTypeIndex].icon
        end
    else
        if not researchType.name then
            researchType.name = locale:get("research_" .. researchType.key .. "_name")
        end
    end

    if not (researchType.description or researchType.noDescription) then
        researchType.description = locale:get("research_" .. researchType.key .. "_description")
    end

    local clueKey = "research_" .. researchType.key .. "_clueText"
    if locale:hasLocalization(clueKey) then
        researchType.clueText = locale:get(clueKey)
    end

    if researchType.skillTypeIndex then
        research.researchTypesBySkillType[researchType.skillTypeIndex] = researchType
    end

    if researchType.resourceTypeIndexes then
        for i,resourceTypeIndex in ipairs(researchType.resourceTypeIndexes) do
            if not research.researchTypesByResourceType[resourceTypeIndex] then
                research.researchTypesByResourceType[resourceTypeIndex] = {}
            end
            table.insert(research.researchTypesByResourceType[resourceTypeIndex], researchType)
        end
    end
end

function research:addResearch(key, info)
    local index = typeIndexMap[key]
    if research.types[key] then
        mj:log("WARNING: overwriting research type:", key)
    end

    info.key = key
    info.index = index
    research.types[key] = info
    research.types[index] = info

    research:updateDerivedInfo(info)

    return index
end

function research:load(gameObject, constructable_, flora)

    constructable = constructable_

    
    research:addResearch("gathering", {
        skillTypeIndex = skill.types.gathering.index,
        noDescription = true, --not needed, as the research is already unlocked, so no description is ever displayed
    })
    
    research:addResearch("basicBuilding", {
        skillTypeIndex = skill.types.basicBuilding.index,
        noDescription = true,
    })
    
    research:addResearch("researching", {
        skillTypeIndex = skill.types.researching.index,
        noDescription = true,
    })
    
    research:addResearch("diplomacy", {
        skillTypeIndex = skill.types.diplomacy.index,
        noDescription = true,
    })
    
    research:addResearch("handToHandCombat", {
        skillTypeIndex = skill.types.handToHandCombat.index,
        noDescription = true,
    })

    -------------------------------------------------------------------------------------------
    --------------------------------------- PHASE A -------------------------------------------
    -------------------------------------------------------------------------------------------

    research:addResearch("fire", {
        skillTypeIndex = skill.types.fireLighting.index,
        resourceTypeIndexes = {resource.types.branch.index},
        orderTypeIndex = order.types.light.index,
        allowResearchEvenWhenDark = true,
        initialResearchSpeedLearnMultiplier = phaseAResearchSpeed,
    })

    research:addResearch("thatchBuilding", {
        skillTypeIndex = skill.types.thatchBuilding.index,
        constructableTypeIndex = constructable.types.thatchResearch.index,
        resourceTypeIndexes = {resource.types.hay.index},
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseAResearchSpeed,
    })

    research:addResearch("rockKnapping", {
        skillTypeIndex = skill.types.rockKnapping.index,
        --constructableTypeIndex = constructable.types.stoneAxeHead.index,
        --resourceTypeIndexes = {resource.types.rockSmall.index},
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.rockSmallSoft.index] = constructable.types.stoneAxeHeadSoft.index,
            [resource.types.rockSmall.index] = constructable.types.stoneAxeHead.index,
            [resource.types.rockSoft.index] = constructable.types.rockSmallSoft.index,
            [resource.types.rock.index] = constructable.types.rockSmall.index,
        },
        resourceTypeIndexes = {
            resource.types.rockSmallSoft.index,
            resource.types.rockSmall.index,
            resource.types.rockSoft.index,
            resource.types.rock.index,
        },
        initialResearchSpeedLearnMultiplier = phaseAResearchSpeed,
    })

    research:addResearch("basicHunting", { --rockThrowing
        skillTypeIndex = skill.types.basicHunting.index,
        requiredToolTypeIndex = tool.types.weaponBasic.index,
        orderTypeIndex = order.types.throwProjectile.index,
        disallowsLimitedAbilitySapiens = true,
        shouldRunWherePossibleWhileResearching = true,
        initialResearchSpeedLearnMultiplier = phaseAResearchSpeed,
        allowCompletionNearThreats = true,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.hunt.index,
            plan.types.attack_throwRock.index,
        },
        isDestructive = true,
    })

    -------------------------------------------------------------------------------------------
    --------------------------------------- PHASE B -------------------------------------------
    -------------------------------------------------------------------------------------------

    research:addResearch("spinning", {
        skillTypeIndex = skill.types.spinning.index,
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.flaxDried.index] = constructable.types.flaxTwine.index,
        },
        resourceTypeIndexes = {
            resource.types.flaxDried.index,
        },
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
    })


    research:addResearch("butchery", {
        skillTypeIndex = skill.types.butchery.index,
        requiredToolTypeIndex = tool.types.butcher.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.deadChicken.index] = constructable.types.butcherChicken.index,
            [resource.types.deadAlpaca.index] = constructable.types.butcherAlpaca.index,
            [resource.types.swordfishDead.index] = constructable.types.fishFillet.index,
        },
        resourceTypeIndexes = {
            resource.types.deadChicken.index,
            resource.types.deadAlpaca.index,
            resource.types.swordfishDead.index,
        },
        orderTypeIndexesByBaseObjectTypeIndex = {
            [gameObject.types.deadMammoth.index] = order.types.butcher.index,
        },
        additionalUnlocksToShowInBreakthroughUI = {
            {
                iconObjectTypeIndex = gameObject.types.mammothMeatTBone.index,
                text = locale:get("research_unlock_butcherMammoth"),
            }
        },
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.butcher.index,
        }
    })

    research:addResearch("digging", {
        skillTypeIndex = skill.types.digging.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        requiredToolTypeIndex = tool.types.dig.index,
        orderTypeIndex = order.types.dig.index,
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.dig.index,
        }
    })

    research:addResearch("flintKnapping", {
        skillTypeIndex = skill.types.flintKnapping.index,
        constructableTypeIndex = constructable.types.flintAxeHead.index,
        resourceTypeIndexes = {resource.types.flint.index},
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
    })

    research:addResearch("chiselStone", {
        skillTypeIndex = skill.types.chiselStone.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.stoneBlockSoft.index] = constructable.types.stoneTileSoft.index,
            [resource.types.stoneBlockHard.index] = constructable.types.stoneTileHard.index,
        },
        resourceTypeIndexes = {
            resource.types.stoneBlockSoft.index, 
            resource.types.stoneBlockHard.index, 
        },
        requiredToolTypeIndex = tool.types.softChiselling.index, --planHelper will override this for hard stone
        orderTypeIndex = order.types.chiselStone.index,
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.chiselStone.index,
        }
    })
    
    research:addResearch("treeFelling", {
        skillTypeIndex = skill.types.treeFelling.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        requiredToolTypeIndex = tool.types.treeChop.index,
        orderTypeIndex = order.types.chop.index,
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.chop.index,
        },
        isDestructive = true,
    })

    research:addResearch("boneCarving", {
        skillTypeIndex = skill.types.boneCarving.index,
        constructableTypeIndex = constructable.types.boneKnife.index,
        resourceTypeIndexes = {resource.types.bone.index},
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
    })

    research:addResearch("spearHunting", {
        skillTypeIndex = skill.types.spearHunting.index,
        requiredToolTypeIndex = tool.types.weaponSpear.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.toolAssembly.index,
        },
        orderTypeIndex = order.types.throwProjectile.index,
        disallowsLimitedAbilitySapiens = true,
        shouldRunWherePossibleWhileResearching = true,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.hunt_throwSpear.index,
            plan.types.attack_throwSpear.index,
        },
        initialResearchSpeedLearnMultiplier = phaseBResearchSpeed,
        allowCompletionNearThreats = true,
        isDestructive = true,
    })

    research:addResearch("campfireCooking", {
        skillTypeIndex = skill.types.campfireCooking.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.fireLighting.index,
        },
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.chickenMeat.index] = constructable.types.cookedChicken.index,
            [resource.types.alpacaMeat.index] = constructable.types.cookedAlpaca.index,
            [resource.types.mammothMeat.index] = constructable.types.cookedMammoth.index,
            [resource.types.pumpkin.index] = constructable.types.campfireRoastedPumpkin.index,
            [resource.types.beetroot.index] = constructable.types.campfireRoastedBeetroot.index,
            [resource.types.fish.index] = constructable.types.cookedFish.index,
        },
        resourceTypeIndexes = {
            resource.types.chickenMeat.index,
            resource.types.alpacaMeat.index,
            resource.types.mammothMeat.index,
            resource.types.pumpkin.index,
            resource.types.beetroot.index,
            resource.types.fish.index,
        },
        initialResearchSpeedLearnMultiplier = 0.5, --special case
    })

    -------------------------------------------------------------------------------------------
    --------------------------------------- PHASE C -------------------------------------------
    -------------------------------------------------------------------------------------------
    



    research:addResearch("toolAssembly", {
        skillTypeIndex = skill.types.toolAssembly.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.spinning.index,
        },
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.stoneSpearHead.index] = constructable.types.stoneSpear.index,
            [resource.types.flintSpearHead.index] = constructable.types.flintSpear.index,
            [resource.types.boneSpearHead.index] = constructable.types.boneSpear.index,
            [resource.types.bronzeSpearHead.index] = constructable.types.bronzeSpear.index,
            [resource.types.stonePickaxeHead.index] = constructable.types.stonePickaxe.index,
            [resource.types.flintPickaxeHead.index] = constructable.types.flintPickaxe.index,
            [resource.types.stoneAxeHead.index] = constructable.types.stoneHatchet.index,
            [resource.types.flintAxeHead.index] = constructable.types.flintHatchet.index,
            [resource.types.stoneHammerHead.index] = constructable.types.stoneHammer.index,
            [resource.types.bronzeAxeHead.index] = constructable.types.bronzeHatchet.index,
            [resource.types.bronzePickaxeHead.index] = constructable.types.bronzePickaxe.index,
            [resource.types.bronzeHammerHead.index] = constructable.types.bronzeHammer.index,
        },
        resourceTypeIndexes = {
            resource.types.stoneSpearHead.index, 
            resource.types.flintSpearHead.index, 
            resource.types.boneSpearHead.index, 
            resource.types.bronzeSpearHead.index, 
            resource.types.stonePickaxeHead.index, 
            resource.types.flintPickaxeHead.index, 
            resource.types.stoneAxeHead.index, 
            resource.types.flintAxeHead.index, 
            resource.types.stoneHammerHead.index, 
            resource.types.bronzeAxeHead.index, 
            resource.types.bronzePickaxeHead.index, 
            resource.types.bronzeHammerHead.index, 
        },
        initialResearchSpeedLearnMultiplier = phaseCResearchSpeed,
    })

    research:addResearch("planting", {
        skillTypeIndex = skill.types.planting.index,
        resourceTypeIndexes = flora.seedResourceTypeIndexes,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.digging.index,
        },
        constructableTypeIndex = constructable.types.plantingResearch.index,
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseCResearchSpeed,
       -- orderTypeIndex = order.types.dig.index,
    })

    research:addResearch("pottery", {
        skillTypeIndex = skill.types.pottery.index,
        constructableTypeIndex = constructable.types.unfiredUrnWet.index,
        resourceTypeIndexes = {resource.types.clay.index},
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.digging.index,
        },
        initialResearchSpeedLearnMultiplier = phaseCResearchSpeed,
    })

    
    research:addResearch("tiling", {
        skillTypeIndex = skill.types.tiling.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.chiselStone.index,
        },
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.firedTile.index] = constructable.types.tilingResearch.index,
        },
        resourceTypeIndexes = {resource.types.firedTile.index},
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseCResearchSpeed,
    })
    
    research:addResearch("woodWorking", {
        skillTypeIndex = skill.types.woodWorking.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.rockKnapping.index,
        },
        constructableTypeIndexArraysByBaseResourceTypeIndex = { -- the order matters, first non-discovered constructable type will be used
            [resource.types.log.index] = {constructable.types.splitLog.index, constructable.types.logDrum.index, constructable.types.canoe.index},
            [resource.types.pumpkin.index] = {constructable.types.balafon.index},
        },
        resourceTypeIndexes = {resource.types.log.index, resource.types.pumpkin.index},
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseCResearchSpeed,
    })


    -------------------------------------------------------------------------------------------
    --------------------------------------- PHASE D -------------------------------------------
    -------------------------------------------------------------------------------------------


    
    research:addResearch("mining", {
        skillTypeIndex = skill.types.mining.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.toolAssembly.index,
        },
        requiredToolTypeIndex = tool.types.mine.index,
        orderTypeIndex = order.types.mine.index,
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.mine.index,
        }
    })


    research:addResearch("mulching", {
        skillTypeIndex = skill.types.mulching.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.planting.index,
        },

        --requiredToolTypeIndex = tool.types.dig.index,
        
        resourceTypeIndexes = {
            resource.types.manure.index,
            resource.types.compost.index,
        },
        
        constructableTypeIndex = constructable.types.fertilize.index,

        --orderTypeIndex = order.types.pickupObject.index,
        --heldObjectOrderTypeIndex = order.types.fertilize.index,
        
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
    })

    research:addResearch("composting", {
        constructableTypeIndex = constructable.types.compost.index,
        resourceTypeIndexes = resource.groups.compostable.resourceTypes,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
        icon = "icon_mulch",
    })

    research:addResearch("medicine", {
        skillTypeIndex = skill.types.medicine.index,
        
        constructableTypeIndexArraysByBaseResourceTypeIndex = { -- the order matters, first non-discovered constructable type will be used
            [resource.types.poppyFlower.index] = {constructable.types.injuryMedicine.index},
            [resource.types.marigoldFlower.index] = {constructable.types.injuryMedicine.index, constructable.types.burnMedicine.index},
            [resource.types.turmericRoot.index] = {constructable.types.injuryMedicine.index, constructable.types.foodPoisoningMedicine.index},
            
            [resource.types.gingerRoot.index] = {constructable.types.foodPoisoningMedicine.index},
            --[resource.types.turmericRoot.index] = constructable.types.foodPoisoningMedicine.index,
            [resource.types.garlic.index] = {constructable.types.foodPoisoningMedicine.index},
            
            [resource.types.aloeLeaf.index] = {constructable.types.burnMedicine.index},
            [resource.types.elderberry.index] = {constructable.types.burnMedicine.index, constructable.types.virusMedicine.index},
            --[resource.types.marigoldFlower.index] = constructable.types.burnMedicine.index,
            
            [resource.types.garlic.index] = {constructable.types.virusMedicine.index},
            --[resource.types.elderberry.index] = {constructable.types.virusMedicine.index},
            [resource.types.echinaceaFlower.index] = {constructable.types.virusMedicine.index},

        },
        resourceTypeIndexes = {
            resource.types.poppyFlower.index,
            resource.types.marigoldFlower.index,
            resource.types.turmericRoot.index,
            resource.types.gingerRoot.index,
            resource.types.garlic.index,
            resource.types.aloeLeaf.index,
            resource.types.elderberry.index,
            resource.types.echinaceaFlower.index,
        },

        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.pottery.index,
        },
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
    })

    research:addResearch("threshing", {
        skillTypeIndex = skill.types.threshing.index,
        constructableTypeIndex = constructable.types.hulledWheat.index,
        resourceTypeIndexes = {resource.types.wheat.index},
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.pottery.index,
        },
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
    })

    research:addResearch("mudBrickBuilding", { --mudBrickBuilding is actually masonry
        skillTypeIndex = skill.types.mudBrickBuilding.index,
        --constructableTypeIndex = constructable.types.mudBrickBuildingResearch.index,
        --resourceTypeIndexes = {resource.types.mudBrickDry.index},
        
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.mudBrickDry.index] = constructable.types.mudBrickBuildingResearch.index,
            [resource.types.firedBrick.index] = constructable.types.brickBuildingResearch.index,
            [resource.types.stoneBlockSoft.index] = constructable.types.stoneBlockBuildingResearch.index,
            [resource.types.stoneBlockHard.index] = constructable.types.stoneBlockBuildingResearch.index,
        },
        resourceTypeIndexes = {
            resource.types.mudBrickDry.index, 
            resource.types.firedBrick.index,
            resource.types.stoneBlockSoft.index,
            resource.types.stoneBlockHard.index,
        },
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
    })

    
    research:addResearch("woodBuilding", {
        skillTypeIndex = skill.types.woodBuilding.index,
        constructableTypeIndex = constructable.types.woodBuildingResearch.index,
        resourceTypeIndexes = {resource.types.splitLog.index},
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
    })

    research:addResearch("flutePlaying", {
        skillTypeIndex = skill.types.flutePlaying.index,
        resourceTypeIndexes = {
            resource.types.boneFlute.index, 
            resource.types.logDrum.index, 
            resource.types.balafon.index, 
        },
        orderTypeIndex = order.types.pickupObject.index,
        heldObjectOrderTypeIndex = order.types.playInstrument.index,
        initialResearchSpeedLearnMultiplier = phaseDResearchSpeed,
        researchCompleteAddPlanTypeIndexes = {
            plan.types.playInstrument.index,
        }
    })

    
    -------------------------------------------------------------------------------------------
    --------------------------------------- PHASE E -------------------------------------------
    -------------------------------------------------------------------------------------------
    
    research:addResearch("grinding", {
        skillTypeIndex = skill.types.grinding.index,
        constructableTypeIndex = constructable.types.flour.index,
        resourceTypeIndexes = {
            resource.types.unfiredUrnHulledWheat.index,
            resource.types.firedUrnHulledWheat.index
        },
        initialResearchSpeedLearnMultiplier = phaseEResearchSpeed,
    })

    
    research:addResearch("potteryFiring", {
        skillTypeIndex = skill.types.potteryFiring.index,
        
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.unfiredUrnDry.index] = constructable.types.firedUrn.index,
            [resource.types.mudTileDry.index] = constructable.types.firedTile.index,
            [resource.types.mudBrickDry.index] = constructable.types.firedBrick.index,
            [resource.types.unfiredBowlDry.index] = constructable.types.firedBowl.index,
        },
        resourceTypeIndexes = {
            resource.types.unfiredUrnDry.index,
            resource.types.mudTileDry.index,
            resource.types.mudBrickDry.index,
            resource.types.unfiredBowlDry.index,
        },

        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.mudBrickBuilding.index,
        },
        initialResearchSpeedLearnMultiplier = phaseEResearchSpeed,
    })
    
    
    research:addResearch("blacksmithing", {
        skillTypeIndex = skill.types.blacksmithing.index,
        requiredToolTypeIndex = tool.types.crucible.index,
        
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.copperOre.index] = constructable.types.bronzeIngot.index,
            [resource.types.tinOre.index] = constructable.types.bronzeIngot.index,
        },
        resourceTypeIndexes = {
            resource.types.copperOre.index,
            resource.types.tinOre.index,
        },

        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.pottery.index,
        },
        initialResearchSpeedLearnMultiplier = phaseEResearchSpeed,
    })
    

    research:addResearch("baking", {
        skillTypeIndex = skill.types.baking.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.pottery.index,
            skill.types.grinding.index,
        },
        constructableTypeIndexesByBaseResourceTypeIndex = {
            [resource.types.unfiredUrnFlour.index] = constructable.types.breadDough.index, --it's important that the craftable doesn't have disallowCompletionWithoutSkill for two step research like this
            [resource.types.firedUrnFlour.index] = constructable.types.breadDough.index,
            [resource.types.breadDough.index] = constructable.types.flatbread.index,
        },
        completeDiscoveryOnlyAllowConstructableTypes = {
            [constructable.types.flatbread.index] = true,
        },
        resourceTypeIndexes = {
            resource.types.unfiredUrnFlour.index,
            resource.types.firedUrnFlour.index,
            resource.types.breadDough.index
        },
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = phaseEResearchSpeed * 2.0,
    })
    
    research:addResearch("brickBuilding", { --deprecated 0.4
        skillTypeIndex = skill.types.brickBuilding.index,
        researchRequiredForVisibilityDiscoverySkillTypeIndexes = {
            skill.types.potteryFiring.index,
        },
        constructableTypeIndex = constructable.types.brickBuildingResearch.index,
        --resourceTypeIndexes = {resource.types.firedBrick.index},
        disallowsLimitedAbilitySapiens = true,
        initialResearchSpeedLearnMultiplier = 1.0,
    })

    --NOTE when adding new types, the order here matters, the first added research type that is available will be the one chosen if there are multiple options for a given resource
    
    research:finalize()
end

function research:finalize()
    research.validTypes = typeMaps:createValidTypesArray("researchable", research.types)
end

--complete = craftableDiscoveriesByTribeID[tribeID] and craftableDiscoveriesByTribeID[tribeID][discoveryCraftableTypeIndex] and craftableDiscoveriesByTribeID[tribeID][discoveryCraftableTypeIndex].complete

function research:getIncompleteDiscoveryCraftableTypeIndexForResearchAndResourceType(researchTypeIndex, resourceTypeIndex, craftableDiscoveries, baseDiscoveryComplete)
    local researchType = research.types[researchTypeIndex]
    if researchType.constructableTypeIndexesByBaseResourceTypeIndex then
        local researchConstructableTypeIndex = researchType.constructableTypeIndexesByBaseResourceTypeIndex[resourceTypeIndex]
        if researchConstructableTypeIndex then
            local constructableType = constructable.types[researchConstructableTypeIndex]
            if constructableType.disabledUntilCraftableResearched then
                if (not craftableDiscoveries) or (not craftableDiscoveries[researchConstructableTypeIndex]) or (not craftableDiscoveries[researchConstructableTypeIndex].complete) then
                    return researchConstructableTypeIndex
                end
            end
        end
    elseif researchType.constructableTypeIndexArraysByBaseResourceTypeIndex then
        local researchConstructableTypeIndexArrays = researchType.constructableTypeIndexArraysByBaseResourceTypeIndex[resourceTypeIndex]
        if researchConstructableTypeIndexArrays then
            for i, researchConstructableTypeIndex in ipairs(researchConstructableTypeIndexArrays) do
                local constructableType = constructable.types[researchConstructableTypeIndex]
                if constructableType.disabledUntilCraftableResearched then
                    if (not craftableDiscoveries) or (not craftableDiscoveries[researchConstructableTypeIndex]) or (not craftableDiscoveries[researchConstructableTypeIndex].complete) then
                        return researchConstructableTypeIndex
                    end
                elseif (not baseDiscoveryComplete) then
                    return researchConstructableTypeIndex
                end
            end
        end
    end

    return nil
end

function research:getBestConstructableIndexForResearch(researchTypeIndex, resourceTypeIndex, craftableDiscoveries, baseDiscoveryComplete)
    local researchType = research.types[researchTypeIndex]
    if researchType.constructableTypeIndexesByBaseResourceTypeIndex then
        return researchType.constructableTypeIndexesByBaseResourceTypeIndex[resourceTypeIndex]
    elseif researchType.constructableTypeIndexArraysByBaseResourceTypeIndex then
        local constructableTypeIndexArray = researchType.constructableTypeIndexArraysByBaseResourceTypeIndex[resourceTypeIndex]
        if constructableTypeIndexArray then
            for i, researchConstructableTypeIndex in ipairs(constructableTypeIndexArray) do
                local constructableType = constructable.types[researchConstructableTypeIndex]
                if constructableType.disabledUntilCraftableResearched then
                    if (not craftableDiscoveries) or (not craftableDiscoveries[researchConstructableTypeIndex]) or (not craftableDiscoveries[researchConstructableTypeIndex].complete) then
                        return researchConstructableTypeIndex
                    end
                elseif (not baseDiscoveryComplete) then
                    return constructableTypeIndexArray[1]
                end
            end

            return constructableTypeIndexArray[1]
        end
    end
    return nil
end

function research:getAllIncompleteRequiredConstructableTypeIndexes(researchTypeIndex, craftableDiscoveries)
    local incompleteIndexes = {}
    local checkedTypesSet = {}
    local researchType = research.types[researchTypeIndex]

    local function addConstructable(constructableTypeIndex)
        if not checkedTypesSet[constructableTypeIndex] then
            checkedTypesSet[constructableTypeIndex] = true
            local constructableType = constructable.types[constructableTypeIndex]
            if constructableType.disabledUntilCraftableResearched then
                if (not craftableDiscoveries) or (not craftableDiscoveries[constructableTypeIndex]) or (not craftableDiscoveries[constructableTypeIndex].complete) then
                    table.insert(incompleteIndexes, constructableTypeIndex)
                end
            end
        end
    end

    if researchType.constructableTypeIndexesByBaseResourceTypeIndex then
        for resourceTypeIndex,constructableTypeIndex in pairs(researchType.constructableTypeIndexesByBaseResourceTypeIndex) do
            addConstructable(constructableTypeIndex)
        end
    elseif researchType.constructableTypeIndexArraysByBaseResourceTypeIndex then
        for resourceTypeIndex,constructableTypeIndexArray in pairs(researchType.constructableTypeIndexArraysByBaseResourceTypeIndex) do
            for i, constructableTypeIndex in ipairs(constructableTypeIndexArray) do
                addConstructable(constructableTypeIndex)
            end
        end
    end

    if next(incompleteIndexes) then
        return incompleteIndexes
    end
    return nil
end

return research