
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local need = {}


need.types = typeMaps:createMap( "need", {
    {
        key = "sleep",
        name = locale:get("need_sleep"),
    },
    {
        key = "warmth",
        name = locale:get("need_warmth"),
    },
    {
        key = "food",
        name = locale:get("need_food"),
    },
    {
        key = "rest",
        name = locale:get("need_rest"),
    },
    {
        key = "starvation", --deprecated
        name = "starvation (deprecated)",
    },
    {
        key = "exhaustion",
        name = locale:get("need_exhaustion"),
    },
    {
        key = "music",
        name = locale:get("need_music"),
    },
})

need.validTypes = typeMaps:createValidTypesArray("need", need.types)

return need
