local typeMaps = mjrequire "common/typeMaps"
local skill = mjrequire "common/skill"
local locale = mjrequire "common/locale"

local sapienTrait = {
    validTypes = {},
    

    hungerInfluenceOnHungerIncrement = 0.5,
    sleepInfluenceOnGradualSleepNeedIncrease = 0.2,
    allSkillsInfluenceOnSkillLearningIncrement = 0.5,
    sleepInfluenceOnSleepNeedWhileSleepingDecrement = -0.1,
    happySadInfluenceOnMoodIncrement = 0.3,
    loyaltyInfluenceOnMoodIncrement = 0.2, --increases at dt * (1.0 + increment), decreases at dt * (1.0 - increment)
    musicalInfluenceOnMusicIncrement = 0.2,
}

sapienTrait.influenceTypes = typeMaps:createMap("sapienTraitInfluence", {
    {
        key = "allSkills"
    },
    {
        key = "rest"
    },
    {
        key = "hunger"
    },
    {
        key = "happySadMood"
    },
    {
        key = "loyaltyMood"
    },
    {
        key = "sleep"
    },
    {
        key = "musical"
    },
    {
        key = "immunity"
    },
})

sapienTrait.types = typeMaps:createMap("sapienTrait", {
    {
        key = "charismatic",
        name = locale:get("sapienTrait_charismatic"),
        opposite = locale:get("sapienTrait_charismatic_opposite"),
        skillInfluences = {
            [skill.types.diplomacy.index] = 1,
        },
        icon = "icon_tribe2",
    },
    {
        key = "loyal",
        name = locale:get("sapienTrait_loyal"),
        opposite = locale:get("sapienTrait_loyal_opposite"),
        influences = {
            [sapienTrait.influenceTypes.loyaltyMood.index] = 1,
        },
        icon = "icon_tribe",
    },
    {
        key = "courageous",
        name = locale:get("sapienTrait_courageous"),
        opposite = locale:get("sapienTrait_courageous_opposite"),
        skillInfluences = {
            [skill.types.basicHunting.index] = 1,
            [skill.types.spearHunting.index] = 1,
            [skill.types.handToHandCombat.index] = 1,
        },
        icon = "icon_spear",
    },
    {
        key = "strong",
        name = locale:get("sapienTrait_strong"),
        skillInfluences = {
            [skill.types.basicHunting.index] = 1,
            [skill.types.spearHunting.index] = 1,
            [skill.types.treeFelling.index] = 1,
            [skill.types.digging.index] = 1,
            [skill.types.mulching.index] = 1,
            [skill.types.mining.index] = 1,
            [skill.types.planting.index] = 1,
            [skill.types.threshing.index] = 1,

            [skill.types.handToHandCombat.index] = 1,
        },
        icon = "icon_axe",
    },
    {
        key = "focused", --normal jobs
        name = locale:get("sapienTrait_focused"),
        skillInfluences = {
            [skill.types.gathering.index] = 1,
            [skill.types.fireLighting.index] = 1,
            [skill.types.spinning.index] = 1,
            [skill.types.butchery.index] = 1,
            [skill.types.grinding.index] = 1,
            [skill.types.chiselStone.index] = 1,

            [skill.types.campfireCooking.index] = 1,
            [skill.types.baking.index] = 1,
        },
        icon = "icon_clear",
    },
    {
        key = "logical", --engineering
        name = locale:get("sapienTrait_logical"),
        skillInfluences = {
            [skill.types.researching.index] = 1,
            [skill.types.medicine.index] = 1,

            [skill.types.basicBuilding.index] = 1,
            [skill.types.woodBuilding.index] = 1,
            [skill.types.thatchBuilding.index] = 1,
            [skill.types.mudBrickBuilding.index] = 1,
            --[skill.types.brickBuilding.index] = 1, --deprecated 0.4
            [skill.types.tiling.index] = 1,
            [skill.types.blacksmithing.index] = 1,
        },
        icon = "icon_hammer",
    },
    {
        key = "creative", --crafting
        name = locale:get("sapienTrait_creative"),
        skillInfluences = {
            [skill.types.rockKnapping.index] = 1,
            [skill.types.flintKnapping.index] = 1,
            [skill.types.boneCarving.index] = 1,
            [skill.types.woodWorking.index] = 1,
            [skill.types.pottery.index] = 1,
            [skill.types.potteryFiring.index] = 1,
            [skill.types.toolAssembly.index] = 1,
            
            [skill.types.flutePlaying.index] = 1,
        },
        icon = "icon_pottery",
    },
    {
        key = "clever", --advanced and research
        name = locale:get("sapienTrait_clever"),
        opposite = locale:get("sapienTrait_clever_opposite"),
        influences = {
            [sapienTrait.influenceTypes.allSkills.index] = 1,
        },
        skillInfluences = {
            [skill.types.researching.index] = 1,
            [skill.types.medicine.index] = 1,
        },
        icon = "icon_idea",
    },
    {
        key = "lazy",
        name = locale:get("sapienTrait_lazy"),
        opposite = locale:get("sapienTrait_lazy_opposite"),
        influences = {
            [sapienTrait.influenceTypes.rest.index] = 1,
        },
        icon = "icon_sit",
    },
    {
        key = "longSleeper",
        name = locale:get("sapienTrait_longSleeper"),
        opposite = locale:get("sapienTrait_longSleeper_opposite"),
        influences = {
            [sapienTrait.influenceTypes.sleep.index] = 1,
        },
        icon = "icon_bed",
    },
    {
        key = "glutton",
        name = locale:get("sapienTrait_glutton"),
        opposite = locale:get("sapienTrait_glutton_opposite"),
        influences = {
            [sapienTrait.influenceTypes.hunger.index] = 1,
        },
        icon = "icon_food",
    },
    {
        key = "optimist",
        name = locale:get("sapienTrait_optimist"),
        opposite = locale:get("sapienTrait_optimist_opposite"),
        influences = {
            [sapienTrait.influenceTypes.happySadMood.index] = 1,
        },
        icon = "icon_hand",
    },
    {
        key = "musical",
        name = locale:get("sapienTrait_musical"),
        opposite = locale:get("sapienTrait_musical_opposite"),
        influences = {
            [sapienTrait.influenceTypes.musical.index] = 1,
        },
        skillInfluences = {
            [skill.types.flutePlaying.index] = 1,
        },
        icon = "icon_music",
    },
    {
        key = "immune",
        name = locale:get("sapienTrait_immune"),
        opposite = locale:get("sapienTrait_immune_opposite"),
        influences = {
            [sapienTrait.influenceTypes.immunity.index] = 1,
        },
        skillInfluences = {
            [skill.types.medicine.index] = 1,
        },
        icon = "icon_injury",
    },
})


sapienTrait.validTypes = typeMaps:createValidTypesArray("sapienTrait", sapienTrait.types)

--[[function sapienTrait:getTraitMultiplierValueForTraiTypeIndex(traitState, sapienTraitTypeIndex)
    for i,traitInfo in ipairs(traitState) do
        if traitInfo.traitTypeIndex == sapienTraitTypeIndex then
            if traitInfo.opposite then
                return -1
            else
                return 1
            end
        end
    end
    return 0
end]]

function sapienTrait:getInfluence(traitState, influenceTypeIndex)
    local influence = 0
    for i,traitInfo in ipairs(traitState) do
        local traitType = sapienTrait.types[traitInfo.traitTypeIndex]
        if traitType.influences then
            local thisInfluence = traitType.influences[influenceTypeIndex]
            if thisInfluence then
                if traitInfo.opposite then
                    influence = influence - thisInfluence
                else
                    influence = influence + thisInfluence
                end
            end
        end
    end
    return influence
end

function sapienTrait:getSkillInfluence(traitState, skillTypeIndex)
    local influence = 0
    for i,traitInfo in ipairs(traitState) do
        local traitType = sapienTrait.types[traitInfo.traitTypeIndex]
        local skillInfluences = traitType.skillInfluences
        if skillInfluences then
            for thisSkillTypeIndex,skillInfluence in pairs(skillInfluences) do
                if thisSkillTypeIndex == skillTypeIndex then
                    if traitInfo.opposite then
                        influence = influence - skillInfluence
                    else
                        influence = influence + skillInfluence
                    end
                end
            end
        end
    end
    return influence
end

function sapienTrait:getSkillInfluenceWithTraitsList(traitState, skillTypeIndex)
    local influence = 0
    local positiveTraits = {}
    local negativeTraits = {}
    for i,traitInfo in ipairs(traitState) do
        local traitType = sapienTrait.types[traitInfo.traitTypeIndex]
        local skillInfluences = traitType.skillInfluences
        if skillInfluences then
            for thisSkillTypeIndex,skillInfluence in pairs(skillInfluences) do
                if thisSkillTypeIndex == skillTypeIndex then
                    if traitInfo.opposite then
                        influence = influence - skillInfluence
                        if skillInfluence < 0 then
                            table.insert(positiveTraits, traitInfo)
                        else
                            table.insert(negativeTraits, traitInfo)
                        end
                    else
                        influence = influence + skillInfluence
                        if skillInfluence > 0 then
                            table.insert(positiveTraits, traitInfo)
                        else
                            table.insert(negativeTraits, traitInfo)
                        end
                    end
                end
            end
        end
    end
    return {
        influence = influence,
        positiveTraits = positiveTraits,
        negativeTraits = negativeTraits,
    }
end

function sapienTrait:getTraitValue(traitState, traitTypeIndex)
    for i,traitInfo in ipairs(traitState) do
        if traitInfo.traitTypeIndex == traitTypeIndex then
            if traitInfo.opposite then
                return -1
            else
                return 1
            end
        end
    end
    return nil
end

return sapienTrait