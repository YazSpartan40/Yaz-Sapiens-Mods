local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local locale = mjrequire "common/locale"
--local statusEffect = mjrequire "common/statusEffect"


local dayLength = 2880.0
local yearLength = dayLength * 8

local sapienConstants = {
    pregnancyDurationDays = 1.0,
    infantDurationDays = 1.0,
    minTimeBetweenPregnancyDays = 4.1,
    maxPregnancyLifeStageFraction = 0.7,
    generalInjuryRisk = 0.0003,
    burnRiskMultiplier = 0.25,
    injuryDuration = dayLength,
    burnDuration = dayLength,
    foodPoisoningDuration = dayLength,
    virusIncubationDuration = 200.0,
    virusDuration = dayLength * 2.0,
    virusInNomadTribeChance = 0.4,
    minPopulationForVirusIntroduction = 20,
    foodPoisoningImmunityDuration = dayLength * 4.0,
    virusImmunityDuration = yearLength * 2, --Strong immunity trait will double this, weak will halve it
    hungryDurationUntilEscalation = dayLength * 0.5, --how long from hungry until very hungry, then again until starvation
    starvationDuration = dayLength, --time until death from starvation
    timeToDevelopHypothermiaWhenVeryCold = dayLength * 0.5,
    timeToDieFromHypothermia = dayLength,
    wetDuration = 20.0, --how long it takes to get the wet status effect in full rain
    dryDuration = 60.0, --how long it takes to dry out
    hungerIncrementMultiplier = 0.5,--higher values mean sapiens will get hungry faster
    musicNeedIncrementMultiplier = 0.5,

    pathStuckDelayBetweenRetryAttempts = 10.0, --checks immediately if the world changes as well
}


local baseWalkSpeed = mj:mToP(2.0)
local pregnantSpeedMultiplier = 1.0

local lifeStages = mj:indexed {
    {
        key = "child",
        name = locale:get("lifeStages_child"),
        duration = 10.0,
        speedMultiplier = 1.1,
        animationSpeedExtraMultiplier = 1.5,
        eyeHeight = mj:mToP(0.9),
        sittingEyeHeight = mj:mToP(0.6),
    },
    {
        key = "adult",
        name = locale:get("lifeStages_adult"),
        duration = 50.0,
        speedMultiplier = 1.5,
        animationSpeedExtraMultiplier = 1.0,
        eyeHeight = mj:mToP(1.5),
        sittingEyeHeight = mj:mToP(0.8),
    },
    {
        key = "elder",
        name = locale:get("lifeStages_elder"),
        duration = 10.0,
        speedMultiplier = 1.0,
        animationSpeedExtraMultiplier = 1.0,
        eyeHeight = mj:mToP(1.5),
        sittingEyeHeight = mj:mToP(0.8),
    },
}

local familyRelationshipTypes = mj:enum {
    "mother",
    "father",
    "sibling",
    "biologicalChild",
}

sapienConstants.lifeStages = lifeStages
sapienConstants.familyRelationshipTypes = familyRelationshipTypes

function sapienConstants:getAnimationSpeedMultiplier(sharedState)
    if sharedState.pregnant or sharedState.hasBaby then
        return pregnantSpeedMultiplier
    end
    return lifeStages[sharedState.lifeStageIndex].speedMultiplier * lifeStages[sharedState.lifeStageIndex].animationSpeedExtraMultiplier
end

function sapienConstants:getWalkSpeed(sharedState)
    if sharedState.pregnant or sharedState.hasBaby then
        return baseWalkSpeed * pregnantSpeedMultiplier
    end
    return baseWalkSpeed * lifeStages[sharedState.lifeStageIndex].speedMultiplier
end

function sapienConstants:getEyeHight(lifeStageIndex, sitting)
    if sitting then
        return lifeStages[lifeStageIndex].sittingEyeHeight
    end
    return lifeStages[lifeStageIndex].eyeHeight
end

function sapienConstants:getAgeValue(sharedState)
    local age = 0.0
    for stageIndex=1,sharedState.lifeStageIndex - 1 do
        age = age + lifeStages[stageIndex].duration
    end

    age = age + lifeStages[sharedState.lifeStageIndex].duration * sharedState.ageFraction
    
    return age
end

function sapienConstants:getAgeDescription(sharedState)
    local ageDays = math.floor(sapienConstants:getAgeValue(sharedState)) + 5
    return string.format("%d, %s", ageDays, sapienConstants.lifeStages[sharedState.lifeStageIndex].name)
end

function sapienConstants:getHasLimitedGeneralAbility(sharedState, preventElders) --NOTE! If you add any new state to check here, it is important to call serverWorld:skillPrioritiesOrLimitedAbilityChanged(tribeID) elsewhere whenever that state changes
    if sharedState.pregnant or 
    sharedState.hasBaby or 
    sharedState.lifeStageIndex == lifeStages.child.index then --or sharedState.lifeStageIndex ~= lifeStages.adult.index then
        return true
    end

    if preventElders and sharedState.lifeStageIndex == lifeStages.elder.index then
        return true
    end

    return false
end

function sapienConstants:getHasLimitedCarryingCapacity(sharedState)
    if sharedState.pregnant or 
    sharedState.hasBaby or 
    sharedState.lifeStageIndex ~=  lifeStages.adult.index then
        return true
    end
end

function sapienConstants:getAnimationGroupKey(sharedState)
    if sharedState.lifeStageIndex == lifeStages.child.index then
        if sharedState.isFemale then
            return "girlSapien"
        else
            return "boySapien"
        end
    else
        if sharedState.isFemale then
            return "femaleSapien"
        else
            return "maleSapien"
        end
    end
end


local posOffsetInfoAdult = {
    {
        worldOffset = vec3(0,mj:mToP(0.2),0), 
        boneOffset = vec3(0,mj:mToP(0.2),0)
    }
}
local posOffsetInfoChild = {
    {
        worldOffset = vec3(0,mj:mToP(0.2),0), 
        boneOffset = vec3(0,mj:mToP(0.1),0)
    }
}

function sapienConstants:getSapienMarkerOffsetInfo(sharedState)
    if sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then
        return posOffsetInfoChild
    end
        
    return posOffsetInfoAdult
end


return sapienConstants