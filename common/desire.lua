local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
local sapienConstants = mjrequire "common/sapienConstants"
local need = mjrequire "common/need"
local locale = mjrequire "common/locale"
local statusEffect = mjrequire "common/statusEffect"
local sapienTrait = mjrequire "common/sapienTrait"
local rng = mjrequire "common/randomNumberGenerator"

local desire = {
    levels = mj:enum {
        "none",
        "mild",
        "moderate",
        "strong",
        "severe",
    }
}

desire.names = {
    [desire.levels.none] =      locale:get("desire_names_none"),
    [desire.levels.mild] =      locale:get("desire_names_mild"),
    [desire.levels.moderate] =  locale:get("desire_names_moderate"),
    [desire.levels.strong] =    locale:get("desire_names_strong"),
    [desire.levels.severe] =    locale:get("desire_names_severe"),
}

desire.sleepDescriptions = {
    [desire.levels.none] =      locale:get("desire_sleepDescriptions_none"),
    [desire.levels.mild] =      locale:get("desire_sleepDescriptions_mild"),
    [desire.levels.moderate] =  locale:get("desire_sleepDescriptions_moderate"),
    [desire.levels.strong] =    locale:get("desire_sleepDescriptions_strong"),
    [desire.levels.severe] =    locale:get("desire_sleepDescriptions_severe"),
}

desire.foodDescriptions = {
    [desire.levels.none] =      locale:get("desire_foodDescriptions_none"),
    [desire.levels.mild] =      locale:get("desire_foodDescriptions_mild"),
    [desire.levels.moderate] =  locale:get("desire_foodDescriptions_moderate"),
    [desire.levels.strong] =    locale:get("desire_foodDescriptions_strong"),
    [desire.levels.severe] =    locale:get("desire_foodDescriptions_severe"),
}

desire.restDescriptions = {
    [desire.levels.none] =      locale:get("desire_restDescriptions_none"),
    [desire.levels.mild] =      locale:get("desire_restDescriptions_mild"),
    [desire.levels.moderate] =  locale:get("desire_restDescriptions_moderate"),
    [desire.levels.strong] =    locale:get("desire_restDescriptions_strong"),
    [desire.levels.severe] =    locale:get("desire_restDescriptions_severe"),
}

desire.colors = {
    [desire.levels.none] = vec4(0.6,0.9,1.0,1.0),
    [desire.levels.mild] = vec4(0.4,1.0,0.4,1.0),
    [desire.levels.moderate] = vec4(1.0,1.0,0.4,1.0),
    [desire.levels.strong] = vec4(1.0,0.7,0.4,1.0),
    [desire.levels.severe] = vec4(1.0,0.4,0.4,1.0),
}

local function ignoringNeeds(sapien)
    local sharedState = sapien.sharedState
    if sharedState.nomad and nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].ignoreNeeds then
        return true
    end
end


function desire:getIntValue(desireLevelTypeIndex)
    return desireLevelTypeIndex - 1
end

local function statusEffectsAllowConstantSleep(statusEffects)
    
    for statusEffectTypeIndex,v in pairs(statusEffects) do
        if statusEffect.types[statusEffectTypeIndex].requiresConstantSleep or statusEffect.types[statusEffectTypeIndex].allowsConstantSleep then
            return true
        end
    end
    return false
end

function desire:getSleep(sapien, timeOfDayFraction)
    if ignoringNeeds(sapien) then
        --mj:log("ignoringNeeds")
        return desire.levels.none
    end
    
    local sharedState = sapien.sharedState
    if sharedState.initialSleepDelay then
        return desire.levels.none
    end

    local statusEffects = sharedState.statusEffects
    if statusEffect:statusEffectsDemandSleep(statusEffects) then
        return desire.levels.severe
    end

    if desire:getWake(sapien, timeOfDayFraction) ~= desire.levels.none then
        return desire.levels.none
    end

    local sleepNeed = sharedState.needs[need.types.sleep.index] + rng:valueForUniqueID(sapien.uniqueID, 9011) * 0.002
    
    --local traitState = sharedState.traits
    --local sleepTraitInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.sleep.index) --disabled as we'll just do this in the morning
    --sleepNeed = sleepNeed + 0.01 * sleepTraitInfluence

    for statusEffectTypeIndex,v in pairs(statusEffects) do
        local sleepNeedOffset = statusEffect.types[statusEffectTypeIndex].sleepNeedOffset
        if sleepNeedOffset then
            sleepNeed = sleepNeed + sleepNeedOffset
        end
    end

    --mj:log("sleepNeed:", sleepNeed)
    if sleepNeed > 0.99 then
        -- mj:log("sleep severe:", sapien.uniqueID)
        return desire.levels.severe
    elseif sleepNeed > 0.9 then
        return desire.levels.strong
    else --if sleepNeed > 0.5 then
        local timeOfDayAdditionalDesire = 0.0
        if not sapien.sharedState.manualAssignedPlanObject then
            timeOfDayAdditionalDesire = math.max(mjm.smoothStep(0.25,0.125, timeOfDayFraction), mjm.smoothStep(0.85,0.95, timeOfDayFraction)) -- desire increases from 9pmish, peaks from 11pm to 3am, tails off until 6am
        end
        local combinedDesire = (math.max(sleepNeed,0.5) - 0.5) * 2.0 + timeOfDayAdditionalDesire * 2.0
        --mj:log("sleep combinedDesire:", sapien.uniqueID, ": ", combinedDesire, " (", timeOfDayAdditionalDesire, " - ", timeOfDayFraction, ")")
        if combinedDesire > 0.9 then
            return desire.levels.strong
        elseif combinedDesire > 0.8 then
            return desire.levels.moderate
        elseif combinedDesire > 0.5 then
            return desire.levels.mild
        end
    end
    return desire.levels.none
end

function desire:updateCachedDesires(sapien, unsavedState, timeOfDayFraction)
    unsavedState.sleepDesire = desire:getSleep(sapien, timeOfDayFraction)
end

function desire:getCachedSleep(sapien, unsavedState, timeOfDayFractionFunc)
    if unsavedState and unsavedState.sleepDesire then
        return unsavedState.sleepDesire
    end
    return desire:getSleep(sapien, timeOfDayFractionFunc())
end

function desire:getWake(sapien, timeOfDayFraction)
    local sharedState = sapien.sharedState
    local statusEffects = sharedState.statusEffects
    if statusEffectsAllowConstantSleep(statusEffects) then
        return desire.levels.none
    end

    if sharedState.needs[need.types.sleep.index] > 0.8 then
        return desire.levels.none
    end
    
    local wakeNeed = 1.0 - sharedState.needs[need.types.sleep.index]
    local timeOfDayAdditionalDesire = 0


    if timeOfDayFraction <= 0.7 then
        local youngAndOldMorningOffset = 0.0
        
        local traitState = sharedState.traits
        local sleepTraitInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.sleep.index)

        if sharedState.lifeStageIndex ~= sapienConstants.lifeStages.adult.index then
            youngAndOldMorningOffset = 0.005
        end

        local sleepNeedTraitOffset = -0.02 * sleepTraitInfluence

        timeOfDayAdditionalDesire = mjm.smoothStep(0.17,0.3, timeOfDayFraction + youngAndOldMorningOffset + sleepNeedTraitOffset) -- increases from 4am to 7-8amish, at max all day until 9pm
    else
        timeOfDayAdditionalDesire = mjm.smoothStep(0.875,0.7, timeOfDayFraction) -- tails off from 6pmish until 9pm. Minimum desire to wake up from 9pm - 4am
    end

    local combinedStatusEffectWakeNeedOffset = 0.0
    local ignoreAllWakeNeedOffsetsFound = false
    
    for statusEffectTypeIndex,v in pairs(statusEffects) do
        if statusEffect.types[statusEffectTypeIndex].ignoreAllWakeNeedOffsets then --starving sapiens gonna get up and look for food
            ignoreAllWakeNeedOffsetsFound = true
            break
        end
        local wakeNeedOffset = statusEffect.types[statusEffectTypeIndex].wakeNeedOffset
        if wakeNeedOffset then
            combinedStatusEffectWakeNeedOffset = combinedStatusEffectWakeNeedOffset + wakeNeedOffset
        end
    end

    if (not ignoreAllWakeNeedOffsetsFound) then
        timeOfDayAdditionalDesire = timeOfDayAdditionalDesire + combinedStatusEffectWakeNeedOffset
    end

    local combinedDesire = wakeNeed * 0.4 + timeOfDayAdditionalDesire * 0.6 + (rng:valueForUniqueID(sapien.uniqueID, 9012) - 0.5) * 0.01

    
    --mj:log("wake desire:", sapien.uniqueID, " :", combinedDesire, " (", timeOfDayAdditionalDesire, " - ", timeOfDayFraction, ")", " wakeNeed:", wakeNeed)

    if combinedDesire > 0.6 then
        return desire.levels.strong
    end
    return desire.levels.none
end


function desire:getDesire(sapien, needTypeIndex, checkOverrides)
    
    local sharedState = sapien.sharedState
    if checkOverrides then
        if statusEffect:hasPositiveOverride(sharedState) then
            return desire.levels.none
        end
    end

    if ignoringNeeds(sapien) then
        return desire.levels.none
    end
    if needTypeIndex == need.types.sleep.index then
        mj:error("use getSleep/getWake for sleep desire")
        return nil
    end


    local thisNeed = sharedState.needs[needTypeIndex] or 0

    
    --[[if needTypeIndex == need.types.rest.index then
        local statusEffects = sharedState.statusEffects
        for statusEffectTypeIndex,v in pairs(statusEffects) do
            local sleepNeedOffset = statusEffect.types[statusEffectTypeIndex].sleepNeedOffset --just use sleep offset for rest
            if sleepNeedOffset then
                thisNeed = thisNeed + sleepNeedOffset
            end
        end
    end]]

    if thisNeed > 0.99 then
        return desire.levels.severe
    elseif thisNeed > 0.9 then
        return desire.levels.strong
    elseif thisNeed > 0.6 then
        return desire.levels.moderate
    elseif thisNeed > 0.3 then
        return desire.levels.mild
    end
    return desire.levels.none
end

return desire