local mjm = mjrequire "common/mjm"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
local typeMaps = mjrequire "common/typeMaps"
local moodColors = mjrequire "common/moodColors"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"

local mood = {
    levels = mj:enum {
        "severeNegative",
        "moderateNegative",
        "mildNegative",
        "mildPositive",
        "moderatePositive",
        "severePositive",
    }
}

mood.types = typeMaps:createMap( "mood", {
    {
        key = "happySad",
        name = locale:get("mood_happySad_name"),
        descriptions = {
            [mood.levels.severeNegative] =      locale:get("mood_happySad_severeNegative"),
            [mood.levels.moderateNegative] =    locale:get("mood_happySad_moderateNegative"),
            [mood.levels.mildNegative] =        locale:get("mood_happySad_mildNegative"),
            [mood.levels.mildPositive] =        locale:get("mood_happySad_mildPositive"),
            [mood.levels.moderatePositive] =    locale:get("mood_happySad_moderatePositive"),
            [mood.levels.severePositive] =      locale:get("mood_happySad_severePositive"),
        },
    },
    {
        key = "confidentScared",
        name = locale:get("mood_confidentScared_name"),
        descriptions = {
            [mood.levels.severeNegative] =      locale:get("mood_confidentScared_severeNegative"),
            [mood.levels.moderateNegative] =    locale:get("mood_confidentScared_moderateNegative"),
            [mood.levels.mildNegative] =        locale:get("mood_confidentScared_mildNegative"),
            [mood.levels.mildPositive] =        locale:get("mood_confidentScared_mildPositive"),
            [mood.levels.moderatePositive] =    locale:get("mood_confidentScared_moderatePositive"),
            [mood.levels.severePositive] =      locale:get("mood_confidentScared_severePositive"),
        },
    },
    {
        key = "loyalty",
        name = locale:get("mood_loyalty_name"),
        descriptions = {
            [mood.levels.severeNegative] =      locale:get("mood_loyalty_severeNegative"),
            [mood.levels.moderateNegative] =    locale:get("mood_loyalty_moderateNegative"),
            [mood.levels.mildNegative] =        locale:get("mood_loyalty_mildNegative"),
            [mood.levels.mildPositive] =        locale:get("mood_loyalty_mildPositive"),
            [mood.levels.moderatePositive] =    locale:get("mood_loyalty_moderatePositive"),
            [mood.levels.severePositive] =      locale:get("mood_loyalty_severePositive"),
        },
    },
})

mood.colors = {
    [mood.levels.severeNegative] = moodColors.severeNegative,
    [mood.levels.moderateNegative] = moodColors.moderateNegative,
    [mood.levels.mildNegative] = moodColors.mildNegative,
    [mood.levels.mildPositive] = moodColors.mildPositive,
    [mood.levels.moderatePositive] = moodColors.moderatePositive,
    [mood.levels.severePositive] = moodColors.severePositive,
}

mood.materials = {
    [mood.levels.severeNegative] = material.types.mood_severeNegative.index,
    [mood.levels.moderateNegative] = material.types.mood_moderateNegative.index,
    [mood.levels.mildNegative] = material.types.mood_mildNegative.index,
    [mood.levels.mildPositive] = material.types.mood_mildPositive.index,
    [mood.levels.moderatePositive] = material.types.mood_moderatePositive.index,
    [mood.levels.severePositive] = material.types.mood_severePositive.index,
}

mood.uiBackgroundMaterials = {
    [mood.levels.severeNegative] = material.types.mood_uiBackground_severeNegative.index,
    [mood.levels.moderateNegative] = material.types.mood_uiBackground_moderateNegative.index,
    [mood.levels.mildNegative] = material.types.mood_uiBackground_mildNegative.index,
    [mood.levels.mildPositive] = material.types.mood_uiBackground_mildPositive.index,
    [mood.levels.moderatePositive] = material.types.mood_uiBackground_moderatePositive.index,
    [mood.levels.severePositive] = material.types.mood_uiBackground_severePositive.index,
}


mood.validTypes = typeMaps:createValidTypesArray("mood", mood.types)

local function ignoringMood(sapien)
    local sharedState = sapien.sharedState
    if sharedState.nomad and nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].ignoreNeeds then
        return true
    end
end

function mood:getStarCount(sapien, moodTypeIndex)
    return mood:getMood(sapien, moodTypeIndex) - 1
end

function mood:getMood(sapien, moodTypeIndex)
    if ignoringMood(sapien) then
        return mood.levels.mildPositive
    end

    local moodValue = sapien.sharedState.moods[moodTypeIndex]
    if not moodValue then
        return mood.levels.mildPositive
    end
    return mjm.clamp(math.floor(moodValue) + 1, 1, 6)

    --[[local moodValue = sapien.sharedState.moods[moodTypeIndex]
    if moodValue >= 0.5 then
        if moodValue > 0.75 then
            if moodValue > 0.95 then
                return mood.levels.severePositive
            else
                return mood.levels.moderatePositive
            end
        else
            return mood.levels.mildPositive
        end
    else
        if moodValue < 0.25 then
            if moodValue < 0.05 then
                return mood.levels.severeNegative
            else
                return mood.levels.moderateNegative
            end
        else
            return mood.levels.mildNegative
        end
    end]]
end

function mood:getRawMoodValue(sapien, moodTypeIndex)
    if ignoringMood(sapien) then
        return mood.levels.mildPositive - 1
    end
    return sapien.sharedState.moods[moodTypeIndex]
end

return mood