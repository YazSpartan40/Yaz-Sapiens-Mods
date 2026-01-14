local typeMaps = mjrequire "common/typeMaps"

local lookAtIntents = {}

lookAtIntents.types = typeMaps:createMap( "lookAtIntents", {
    {
        key = "social",
    },
    {
        key = "work",
    },
    {
        key = "interest",
    },
    {
        key = "sleep",
    },
    {
        key = "raidTarget",
    },
    {
        key = "restOn",
    },
    {
        key = "restNear",
    },
    {
        key = "eat",
    },
    {
        key = "putOnClothing",
    },
    {
        key = "play",
    },
    {
        key = "caution",
    },
})

return lookAtIntents
