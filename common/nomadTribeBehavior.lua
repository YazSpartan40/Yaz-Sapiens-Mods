
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local nomadTribeBehavior = {

}

nomadTribeBehavior.types = typeMaps:createMap("nomadTribeBehavior", {
    {
        key = "foodRaid",
        name = locale:get("nomadTribeBehavior_foodRaid_name"),
        recruitChanceOffset = -1,
        ignoreNeeds = true,  --todo this is not good enough, need some kind of adrenaline/stress based system or something. In particular if this sapien is trapped, they will never sleep
        preventLimitedAbility = true,
        isRaid = true, --affects behavior in findOrderLookAround, and whether these sapiens are treated as threats and run away from
        fleeChance = 0.3, --affects behavior in serverSapien:doFightOrFlightResponseIfNeeded when attacked, default 0.5 (50:50)
        maxSpawnCount = 2,
    },
    {
        key = "opportunisticThief",
        name = locale:get("nomadTribeBehavior_opportunisticThief_name"),
        recruitChanceOffset = -1,
        ignoreNeeds = true,
        isRaid = true,
        fleeChance = 0.9,
        maxSpawnCount = 2,
    },
    {
        key = "armedThief",
        name = locale:get("nomadTribeBehavior_armedThief_name"),
        recruitChanceOffset = -2, --can't recruit
        banishChanceOffset = -1,
        ignoreNeeds = true,
        preventLimitedAbility = true,
        isRaid = true,
        fleeChance = 0.1,
        maxSpawnCount = 4,
    },
    {
        key = "friendlyVisit",
        name = locale:get("nomadTribeBehavior_friendlyVisit_name"),
        banishChanceOffset = 1,
        fleeChance = 1,
        maxSpawnCount = 2,
    },
    {
        key = "cautiousVisit",
        name = locale:get("nomadTribeBehavior_cautiousVisit_name"),
        recruitChanceOffset = -1,
        banishChanceOffset = 1,
        fleeChance = 0.3,
        maxSpawnCount = 2,
    },
    {
        key = "join",
        name = locale:get("nomadTribeBehavior_join_name"),
        recruitChanceOffset = 1,
        banishChanceOffset = 1,
        fleeChance = 1,
        maxSpawnCount = 2,
    },
    {
        key = "passThrough",
        name = locale:get("nomadTribeBehavior_passThrough_name"),
        banishChanceOffset = 1,
        fleeChance = 0.8,
        maxSpawnCount = 4,
    },
    {
        key = "leave",
        name = locale:get("nomadTribeBehavior_leave_name"),
        recruitChanceOffset = -1,
        banishChanceOffset = -2, --they are already leaving, no point, make it impossible
        fleeChance = 0.5, -- maybe we are angry because we had to leave
    },
})


nomadTribeBehavior.validTypes = typeMaps:createValidTypesArray("nomadTribeBehavior", nomadTribeBehavior.types)

return nomadTribeBehavior