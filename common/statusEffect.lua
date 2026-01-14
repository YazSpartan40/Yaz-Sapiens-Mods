
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"
local medicine = mjrequire "common/medicine"
local plan = mjrequire "common/plan"

local statusEffect = {}


local typeIndexMap = typeMaps.types.statusEffect
statusEffect.typeIndexMap = typeIndexMap

statusEffect.types = typeMaps:createMap( "statusEffect", {
    {
        key = "justAte",
        name = locale:get("statusEffect_justAte_name"),
        description = locale:get("statusEffect_justAte_description"),
        icon = "icon_food",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "goodSleep",
        name = locale:get("statusEffect_goodSleep_name"),
        description = locale:get("statusEffect_goodSleep_description"),
        icon = "icon_bed",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "learnedSkill",
        name = locale:get("statusEffect_learnedSkill_name"),
        description = locale:get("statusEffect_learnedSkill_description"),
        icon = "icon_idea",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "wellRested",
        name = locale:get("statusEffect_wellRested_name"),
        description = locale:get("statusEffect_wellRested_description"),
        icon = "icon_sit",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "hadChild",
        name = locale:get("statusEffect_hadChild_name"),
        description = locale:get("statusEffect_hadChild_description"),
        icon = "icon_tribe",
        impact = 4,
        affectsLoyalty = true,
    },
    {
        key = "optimist",
        name = locale:get("statusEffect_optimist_name"),
        description = locale:get("statusEffect_optimist_description"),
        icon = "icon_hand",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "injuryTreated",
        name = locale:get("statusEffect_injuryTreated_name"),
        description = locale:get("statusEffect_injuryTreated_description"),
        icon = "icon_injury",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "burnTreated",
        name = locale:get("statusEffect_burnTreated_name"),
        description = locale:get("statusEffect_burnTreated_description"),
        icon = "icon_burn",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "foodPoisoningTreated",
        name = locale:get("statusEffect_foodPoisoningTreated_name"),
        description = locale:get("statusEffect_foodPoisoningTreated_description"),
        icon = "icon_foodPoisoning",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "virusTreated",
        name = locale:get("statusEffect_virusTreated_name"),
        description = locale:get("statusEffect_virusTreated_description"),
        icon = "icon_virus",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "foodPoisoningImmunity",
        name = locale:get("statusEffect_foodPoisoningTreated_name"), --not currently displayed anywhere, so just use treatment text for now
        description = locale:get("statusEffect_foodPoisoningTreated_description"),
        icon = "icon_foodPoisoning",
        impact = 0,
    },
    {
        key = "virusImmunity",
        name = locale:get("statusEffect_virusTreated_name"), --not currently displayed anywhere, so just use treatment text for now
        description = locale:get("statusEffect_virusTreated_description"),
        icon = "icon_virus",
        impact = 0,
    },

    --negative
    
    {
        key = "hungry",
        name = locale:get("statusEffect_hungry_name"),
        description = locale:get("statusEffect_hungry_description"),
        icon = "icon_food",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "veryHungry",
        name = locale:get("statusEffect_veryHungry_name"),
        description = locale:get("statusEffect_veryHungry_description"),
        icon = "icon_food",
        impact = -4,
        affectsLoyalty = true,
        ignoreAllWakeNeedOffsets = true,
        replaces = {
            typeIndexMap.hungry,
        },
    },
    {
        key = "starving",
        name = locale:get("statusEffect_starving_name"),
        description = locale:get("statusEffect_starving_description"),
        icon = "icon_food",
        impact = -8,
        affectsLoyalty = true,
        ignoreAllWakeNeedOffsets = true,
        replaces = {
            typeIndexMap.veryHungry,
            typeIndexMap.hungry,
        },
    },
    {
        key = "sleptOnGround",
        name = locale:get("statusEffect_sleptOnGround_name"),
        description = locale:get("statusEffect_sleptOnGround_description"),
        icon = "icon_bed",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "sleptOutside",
        name = locale:get("statusEffect_sleptOutside_name"),
        description = locale:get("statusEffect_sleptOutside_description"),
        icon = "icon_bed",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "tired",
        name = locale:get("statusEffect_tired_name"),
        description = locale:get("statusEffect_tired_description"),
        icon = "icon_bed",
        impact = -1,
    },
    {
        key = "overworked",
        name = locale:get("statusEffect_overworked_name"),
        description = locale:get("statusEffect_overworked_description"),
        icon = "icon_sit",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "exhausted",
        name = locale:get("statusEffect_exhausted_name"),
        description = locale:get("statusEffect_exhausted_description"),
        icon = "icon_sit",
        impact = -4,
        affectsLoyalty = true,
        preventsMostWork = true,
    },
    {
        key = "exhaustedSleep",
        name = locale:get("statusEffect_exhaustedSleep_name"),
        description = locale:get("statusEffect_exhaustedSleep_description"),
        icon = "icon_bed",
        impact = -4,
        preventsMostWork = true,
    },
    {
        key = "acquaintanceDied",
        name = locale:get("statusEffect_acquaintanceDied_name"),
        description = locale:get("statusEffect_acquaintanceDied_description"),
        icon = "icon_tribe",
        impact = -1,
    },
    {
        key = "acquaintanceLeft",
        name = locale:get("statusEffect_acquaintanceLeft_name"),
        description = locale:get("statusEffect_acquaintanceLeft_description"),
        icon = "icon_tribe",
        impact = -1,
    },
    {
        key = "familyDiedShortTerm",
        name = locale:get("statusEffect_familyDied_name"),
        description = locale:get("statusEffect_familyDied_description"),
        icon = "icon_tribe",
        impact = -4,
        replaces = {
            typeIndexMap.familyDiedLongTerm,
        }
    },
    {
        key = "familyDiedLongTerm",
        name = locale:get("statusEffect_familyDied_name"),
        description = locale:get("statusEffect_familyDied_description"),
        icon = "icon_tribe",
        impact = -1,
    },
    {
        key = "pessimist",
        name = locale:get("statusEffect_pessimist_name"),
        description = locale:get("statusEffect_pessimist_description"),
        icon = "icon_hand",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "minorInjury",
        name = locale:get("statusEffect_minorInjury_name"),
        description = locale:get("statusEffect_minorInjury_description"),
        icon = "icon_injury",
        impact = -1,
        sleepNeedOffset = 0.2,
        wakeNeedOffset = -0.5,
        requiredMedicineTypeIndex = medicine.types.injury.index,
    },
    {
        key = "majorInjury",
        name = locale:get("statusEffect_majorInjury_name"),
        description = locale:get("statusEffect_majorInjury_description"),
        icon = "icon_injury",
        impact = -4,
        replaces = {
            typeIndexMap.minorInjury,
        },
        allowsConstantSleep = true,
        sleepNeedOffset = 0.85,
        requiredMedicineTypeIndex = medicine.types.injury.index,
    },
    {
        key = "criticalInjury",
        name = locale:get("statusEffect_criticalInjury_name"),
        description = locale:get("statusEffect_criticalInjury_description"),
        icon = "icon_injury",
        impact = -8,
        replaces = {
            typeIndexMap.minorInjury,
            typeIndexMap.majorInjury,
        },
        requiresConstantSleep = true,
        requiredMedicineTypeIndex = medicine.types.injury.index,
    },
    {
        key = "unconscious",
        name = locale:get("statusEffect_unconscious_name"),
        description = locale:get("statusEffect_unconscious_description"),
        icon = "icon_injury",
        impact = -4,
        requiresConstantSleep = true,
        disallowsCriticalPlanCompletion = true,
    },
    {
        key = "cold",
        name = locale:get("statusEffect_cold_name"),
        description = locale:get("statusEffect_cold_description"),
        icon = "icon_snow",
        impact = -1,
        replaces = {
            typeIndexMap.veryCold,
            typeIndexMap.hot,
            typeIndexMap.veryHot,
        },
        affectsLoyalty = true,
    },
    {
        key = "veryCold",
        name = locale:get("statusEffect_veryCold_name"),
        description = locale:get("statusEffect_veryCold_description"),
        icon = "icon_snow",
        impact = -4,
        replaces = {
            typeIndexMap.cold,
            typeIndexMap.hot,
            typeIndexMap.veryHot,
        },
        affectsLoyalty = true,
    },
    {
        key = "hypothermia",
        name = locale:get("statusEffect_hypothermia_name"),
        description = locale:get("statusEffect_hypothermia_description"),
        icon = "icon_snow",
        impact = -8,
        affectsLoyalty = true,
        sleepNeedOffset = 0.4,
        wakeNeedOffset = -0.5,
    },
    { 
        key = "hot",
        name = locale:get("statusEffect_hot_name"),
        description = locale:get("statusEffect_hot_description"),
        icon = "icon_fire",
        impact = 0, --hot and very hot are not currently displayed, as there is no way for the player to prevent or fix this
        replaces = {
            typeIndexMap.veryCold,
            typeIndexMap.cold,
            typeIndexMap.veryHot,
        },
    },
    {
        key = "veryHot",
        name = locale:get("statusEffect_veryHot_name"),
        description = locale:get("statusEffect_veryHot_description"),
        icon = "icon_fire",
        impact = 0, --hot and very hot are not currently displayed, as there is no way for the player to prevent or fix this
        replaces = {
            typeIndexMap.cold,
            typeIndexMap.hot,
            typeIndexMap.veryCold,
        },
    },
    {
        key = "wet",
        name = locale:get("statusEffect_wet_name"),
        description = locale:get("statusEffect_wet_description"),
        icon = "icon_wet",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "wantsMusic",
        name = locale:get("statusEffect_wantsMusic_name"),
        description = locale:get("statusEffect_wantsMusic_description"),
        icon = "icon_music",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "enjoyedMusic",
        name = locale:get("statusEffect_enjoyedMusic_name"),
        description = locale:get("statusEffect_enjoyedMusic_description"),
        icon = "icon_music",
        impact = 1,
        affectsLoyalty = true,
    },
    {
        key = "inDarkness",
        name = locale:get("statusEffect_inDarkness_name"),
        description = locale:get("statusEffect_inDarkness_description"),
        icon = "icon_dark",
        impact = -1,
        affectsLoyalty = true,
    },
    {
        key = "minorBurn",
        name = locale:get("statusEffect_minorBurn_name"),
        description = locale:get("statusEffect_minorBurn_description"),
        icon = "icon_burn",
        impact = -1,
        sleepNeedOffset = 0.2,
        wakeNeedOffset = -0.5,
        requiredMedicineTypeIndex = medicine.types.burn.index,
    },
    {
        key = "majorBurn",
        name = locale:get("statusEffect_majorBurn_name"),
        description = locale:get("statusEffect_majorBurn_description"),
        icon = "icon_burn",
        impact = -4,
        replaces = {
            typeIndexMap.minorBurn,
        },
        allowsConstantSleep = true,
        sleepNeedOffset = 0.85,
        requiredMedicineTypeIndex = medicine.types.burn.index,
    },
    {
        key = "criticalBurn",
        name = locale:get("statusEffect_criticalBurn_name"),
        description = locale:get("statusEffect_criticalBurn_description"),
        icon = "icon_burn",
        impact = -8,
        replaces = {
            typeIndexMap.minorBurn,
            typeIndexMap.majorBurn,
        },
        requiresConstantSleep = true,
        requiredMedicineTypeIndex = medicine.types.burn.index,
    },
    {
        key = "minorFoodPoisoning",
        name = locale:get("statusEffect_minorFoodPoisoning_name"),
        description = locale:get("statusEffect_minorFoodPoisoning_description"),
        icon = "icon_foodPoisoning",
        impact = -1,
        sleepNeedOffset = 0.2,
        wakeNeedOffset = -0.5,
        requiredMedicineTypeIndex = medicine.types.foodPoisoning.index,
    },
    {
        key = "majorFoodPoisoning",
        name = locale:get("statusEffect_majorFoodPoisoning_name"),
        description = locale:get("statusEffect_majorFoodPoisoning_description"),
        icon = "icon_foodPoisoning",
        impact = -4,
        replaces = {
            typeIndexMap.minorFoodPoisoning,
        },
        allowsConstantSleep = true,
        sleepNeedOffset = 0.85,
        requiredMedicineTypeIndex = medicine.types.foodPoisoning.index,
    },
    {
        key = "criticalFoodPoisoning",
        name = locale:get("statusEffect_criticalFoodPoisoning_name"),
        description = locale:get("statusEffect_criticalFoodPoisoning_description"),
        icon = "icon_foodPoisoning",
        impact = -8,
        replaces = {
            typeIndexMap.minorFoodPoisoning,
            typeIndexMap.majorFoodPoisoning,
        },
        requiresConstantSleep = true,
        requiredMedicineTypeIndex = medicine.types.foodPoisoning.index,
    },
    {
        key = "incubatingVirus",
        name = locale:get("statusEffect_minorVirus_name"),
        description = locale:get("statusEffect_minorVirus_description"),
        icon = "icon_virus",
        impact = 0,
    },
    {
        key = "minorVirus",
        name = locale:get("statusEffect_minorVirus_name"),
        description = locale:get("statusEffect_minorVirus_description"),
        icon = "icon_virus",
        impact = -1,
        replaces = {
            typeIndexMap.incubatingVirus,
        },
        sleepNeedOffset = 0.2,
        wakeNeedOffset = -0.5,
        requiredMedicineTypeIndex = medicine.types.virus.index,
    },
    {
        key = "majorVirus",
        name = locale:get("statusEffect_majorVirus_name"),
        description = locale:get("statusEffect_majorVirus_description"),
        icon = "icon_virus",
        impact = -4,
        replaces = {
            typeIndexMap.incubatingVirus,
            typeIndexMap.minorVirus,
        },
        allowsConstantSleep = true,
        sleepNeedOffset = 0.85,
        requiredMedicineTypeIndex = medicine.types.virus.index,
    },
    {
        key = "criticalVirus",
        name = locale:get("statusEffect_criticalVirus_name"),
        description = locale:get("statusEffect_criticalVirus_description"),
        icon = "icon_virus",
        impact = -8,
        replaces = {
            typeIndexMap.incubatingVirus,
            typeIndexMap.minorVirus,
            typeIndexMap.majorVirus,
        },
        requiresConstantSleep = true,
        requiredMedicineTypeIndex = medicine.types.virus.index,
    },

    --- NOTE! When adding new effects, don't forget to add to the display order list below, or it won't show in the UI
})

-- used for UI render order, and AI priority order. strong effects must come first.

local orderedPositiveEffects = {
    statusEffect.types.hadChild.index,

    statusEffect.types.justAte.index,
    statusEffect.types.goodSleep.index,
    statusEffect.types.enjoyedMusic.index,
    statusEffect.types.learnedSkill.index,
    statusEffect.types.wellRested.index,
    statusEffect.types.optimist.index,
    
    statusEffect.types.injuryTreated.index,
    statusEffect.types.burnTreated.index,
    statusEffect.types.foodPoisoningTreated.index,
    statusEffect.types.virusTreated.index,
}


local orderedNegativeEffects = {
    statusEffect.types.criticalInjury.index,
    statusEffect.types.criticalBurn.index,
    statusEffect.types.criticalFoodPoisoning.index,
    statusEffect.types.criticalVirus.index,
    statusEffect.types.starving.index,
    statusEffect.types.hypothermia.index,
    statusEffect.types.majorInjury.index,
    statusEffect.types.majorBurn.index,
    statusEffect.types.majorFoodPoisoning.index,
    statusEffect.types.majorVirus.index,
    statusEffect.types.veryHungry.index,
    statusEffect.types.veryCold.index,
    statusEffect.types.unconscious.index,
    statusEffect.types.familyDiedShortTerm.index,
    statusEffect.types.exhaustedSleep.index,
    statusEffect.types.exhausted.index,
    --statusEffect.types.veryHot.index,

    statusEffect.types.minorInjury.index,
    statusEffect.types.minorBurn.index,
    statusEffect.types.minorFoodPoisoning.index,
    statusEffect.types.minorVirus.index,
    statusEffect.types.familyDiedLongTerm.index,
    statusEffect.types.acquaintanceDied.index,
    statusEffect.types.acquaintanceLeft.index,
    statusEffect.types.hungry.index,
    statusEffect.types.tired.index,
    statusEffect.types.overworked.index,
    statusEffect.types.sleptOnGround.index,
    statusEffect.types.sleptOutside.index,
    statusEffect.types.wantsMusic.index,
    statusEffect.types.pessimist.index,
    statusEffect.types.cold.index,
    --statusEffect.types.hot.index,
    statusEffect.types.wet.index,
    statusEffect.types.inDarkness.index,
}

statusEffect.orderedPositiveEffects = orderedPositiveEffects
statusEffect.orderedNegativeEffects = orderedNegativeEffects

function statusEffect:hasEffect(sharedState, statusEffectTypeIndex)
    return sharedState.statusEffects[statusEffectTypeIndex] ~= nil
end


function statusEffect:hasPositiveOverride(sharedState)
    local found = false
    for statusEffectTypeIndex,v in pairs(sharedState.statusEffects) do
        local impact = statusEffect.types[statusEffectTypeIndex].impact
        if impact < -1 then
            return false
        elseif impact > 1 then
            found = true
        end
    end
    return found
end

function statusEffect:statusEffectsDemandSleep(statusEffects)
    for statusEffectTypeIndex,v in pairs(statusEffects) do
        if statusEffect.types[statusEffectTypeIndex].requiresConstantSleep then
            return true
        end
    end
    return false
end

function statusEffect:cantDoMostWorkDueToEffects(statusEffects)
    for statusEffectTypeIndex,v in pairs(statusEffects) do
        local statusEffectType = statusEffect.types[statusEffectTypeIndex]
        if statusEffectType.requiresConstantSleep or statusEffectType.allowsConstantSleep or statusEffectType.preventsMostWork then
            return true
        end
    end
    return false
end


function statusEffect:canDoPlanTypeDespiteMostWorkDisabled(statusEffects, planTypeIndex)
    for statusEffectTypeIndex,v in pairs(statusEffects) do
        local statusEffectType = statusEffect.types[statusEffectTypeIndex]
        if statusEffectType.requiresConstantSleep or statusEffectType.allowsConstantSleep then
            if (statusEffectType.disallowsCriticalPlanCompletion) or (not plan.types[planTypeIndex].allowsDespiteStatusEffectSleepRequirements) then
                return false
            end
        end
    end
    return true
end

function statusEffect:mjInit()
    for i, statusEffectTypeIndex in ipairs(statusEffect.orderedPositiveEffects) do
        statusEffect.types[statusEffectTypeIndex].priority = i
    end
    for i, statusEffectTypeIndex in ipairs(statusEffect.orderedNegativeEffects) do
        statusEffect.types[statusEffectTypeIndex].priority = i
    end
end


return statusEffect