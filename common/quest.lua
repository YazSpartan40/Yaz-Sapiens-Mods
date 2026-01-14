local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local quest = {
    --for testing:
    --regenerationTime = 60,
    --completionTimeLimitDefault = 300,

    regenerationTime = 3600 + 120, --3600 day length, 57600 year length, 
    completionTimeLimitDefault = 3600 * 4 + 60,
    failureOrCompletionDelayBeforeNewQuest = 60.0, --wait a minute so you get a chance to see what happened
}

quest.types = typeMaps:createMap( "quest", {
    {
        key = "resource",
        name = locale:get("quest_resource"),
        completionTimeLimit = quest.completionTimeLimitDefault,
    },
    --[[{
        key = "knowledge",
        name = locale:get("quest_knowledge"),
        completionTimeLimit = quest.completionTimeLimitDefault,
    },
    {
        key = "findSapien",
        name = locale:get("quest_sapien"),
        completionTimeLimit = quest.completionTimeLimitDefault,
    },
    {
        key = "treatSick",
        name = locale:get("quest_treatSick"),
        completionTimeLimit = quest.completionTimeLimitDefault,
    },
    {
        key = "repairBuilding",
        name = locale:get("quest_repairBuilding"),
        completionTimeLimit = quest.completionTimeLimitDefault,
    },
    {
        key = "huntMob",
        name = locale:get("quest_huntMob"),
        completionTimeLimit = quest.completionTimeLimitDefault,
    },]]
})

quest.motivationTypes = typeMaps:createMap( "questMotivation", {
    {
        key = "craftable",
        storyLocaleKey = "quest_motivation_story_craftable",
    },
})

return quest