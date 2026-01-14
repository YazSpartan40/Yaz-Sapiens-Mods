local typeMaps = mjrequire "common/typeMaps"

local destination = {}

destination.types = typeMaps:createMap( "destination", {
    {
        key = "staticTribe",
    },
    {
        key = "nomadTribe",
    },
    {
        key = "playerSelectionSeedTribe",
    },
    {
        key = "abandondedVillage",
    },
    {
        key = "abandondedMine",
    },
})


destination.loadStates = mj:enum {
    "seed",
    "loaded",
    "hibernating",
    "complete" --deprecated, don't use
}

return destination
