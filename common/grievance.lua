
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local grievance = {}


grievance.types = typeMaps:createMap("grievance", {
    { --added when items are removed from storage areas
        key = "resourcesTaken",
        name = locale:get("grievance_resourcesTaken"),
        thresholdMin = 1, --below this 0% chance of triggering. Time between updates is gameConstants.tribeAIPlayerTimeBetweenUpdates, default 30s
        thresholdMax = 20, --above this 100% chance of triggering. Also used as a favorPenalty multiplier, eg if 80 grievances and 20 thresholdMax, 80/20 = 4 * favorPenalty
        favorPenalty = 5,
    },
    { --added when a sapien first sleeps in a bed
        key = "bedsUsed",
        name = locale:get("grievance_bedsUsed"),
        thresholdMin = 1,
        thresholdMax = 10,
        favorPenalty = 5,
        onlyAddWhenNotTrading = true,
    },
    { --every time a single item is taken away, moved out of place, or destroyed. eg. a thatch hut deconstruction would cause 10 grievances for stacking the hay and branches + 10 for removing them all
        key = "objectsDestroyed",
        name = locale:get("grievance_objectsDestroyed"),
        thresholdMin = 1,
        thresholdMax = 10,
        favorPenalty = 5,
    },
    { --every time a single item is taken to a building site or moved into place within some distance (100m?) of tribe center
        key = "objectsBuilt",
        name = locale:get("grievance_objectsBuilt"),
        thresholdMin = 1,
        thresholdMax = 10,
        favorPenalty = 5,
        onlyAddWhenNotTrading = true,
    },
    { --every time a craft is completed (1 grievance even if multiple outputs in 1 craft) at craft areas, campfires, kilns etc.
        key = "craftAreasUsed",
        name = locale:get("grievance_craftAreasUsed"),
        thresholdMin = 1,
        thresholdMax = 10,
        favorPenalty = 5,
        onlyAddWhenNotTrading = true,
    },
    { --every time we recruit one of their sapiens.
        key = "sapienRecruited",
        name = locale:get("grievance_sapienRecruited"),
        thresholdMin = 1,
        thresholdMax = 1, --always
        favorPenalty = 10,
    },
    { --every time we banish one of their sapiens.
        key = "sapienBanished",
        name = locale:get("grievance_sapienBanished"),
        thresholdMin = 1,
        thresholdMax = 1, --always
        favorPenalty = 10,
    },
    { --every time we successfully hit one of their sapiens in an attack
        key = "sapienAttacked",
        name = locale:get("grievance_sapienAttacked"),
        thresholdMin = 1,
        thresholdMax = 2,
        favorPenalty = 5,
    },
    { --called occasionally when we have high favor with this tribe, but low favor with nomads
        key = "nomadsMistreated",
        name = locale:get("grievance_nomadsMistreated"),
        thresholdMin = 1,
        thresholdMax = 1,
        favorPenalty = 5,
    },
    {
        key = "questFailure", --maybe?
    },
})

return grievance