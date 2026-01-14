local gameConstants = {

    pauseSpeed = 0.0,
    playSpeed = 1.0,
    fastSpeed = 3.0,
    ultraSpeed = 64.0,
    slowMotionSpeed = 0.1,

    showDebugMenu = true,
    sendServerStatsTextDelay = 0.5, --server info can be sent to clients periodically, for display in the debug UI. Comment out or set this to nil to disable.
    --showCheatButtons = true,


    --debugConstantWindStorm = true,
    --alwaysFineWeather = true,
    --debugInfiniteGather = true,
    --debugCreateCloseTribeCount = 1,
    --debugAllowTradesWithNoFavor = true,
    --debugShowAvatar = true,
    --debugAllowPlayersToTakeOverAITribes = true, -- for initial tribe selection. May be buggy or stop working in future update.
    --debugSingleIndustryTypeKey = "bronze", --all new AI tribes will spawn with this type of industry eg. "rockTools" "flour" or "pottery"

    maxPlayerFlyHeightMeters = 100.0,
    speedIncreaseFactorAtMaxHeight = 500000.0,

    allowedPlansPerFollower = 5,

    tutorial_grassClearCount = 5,
    tutorial_storageAreaPlaceCount = 6,
    tutorial_storeHayCount = 8,
    tutorial_storeBranchCount = 8,
    tutorial_multiselectCount = 4,
    tutorial_bedPlaceCount = 4,
    tutorial_bedBuiltCount = 4,
    tutorial_craftAreaBuiltCount = 4,
    tutorial_craftHandAxeCount = 4,
    tutorial_craftKnifeCount = 4,
    tutorial_storeFoodCount = 10,
    tutorial_foodCropPlantCount = 10,
    tutorial_pathBuildCount = 10,
    tutorial_storeFlaxCount = 4,
    tutorial_storeTwineCount = 4,

    standardPathProximityDistance = mj:mToP(1.2),
    buildPathProximityDistance = mj:mToP(2.5),
    
    fireWarmthRadius = mj:mToP(9.0),
    maxTerrainSteepness = mj:mToP(5.9),

    harvestCountForSoilFertilityDegredation = 20,

    compostBinValueSumRequiredForOutput = 10,
    compostBinMaxItemCount = 1000,
    compostTimeUntilCompostGeneratedDays = 1,
    
    windStormDuration = 2880 * 0.25,
    windStormPeakDuration = 2880 * 0.25 * 0.5,
    --windStormDuration = 1.0,--2880 * 0.25,
    --windStormPeakDuration = 1.0,--2880 * 0.25 * 0.5,

    windStormStrengthAtPeak = 16.0, --this is actually assumed to be 16.0 in a number of places, changing it will likely break things

    -- if object is given "windDestructableLowChance" then this is how likely per object, eg 0.001 is 1/1000 chance of destruction per second, or an average of one destruction event per object per 1000 seconds during the wind event peak
    -- for storage areas, this is per storage area, not per item in the storage area. 
    -- High chance is used for light objects in storage areas, moderate for heavier objects in storage areas and flora destruction, low is used for thatch building destruction
    windAffectedCallbackHighChancePerSecond = 0.01,
    windAffectedCallbackModerateChancePerSecond = 0.0005,
    windAffectedCallbackLowChancePerSecond = 0.0002,
    
    minRainfallForRainDamage = 50.0, --this is approximately an annual rainfall figure in mm. Any object in a location that receieves annual rainfall below this won't ever receive any rain damage

    rainAffectedCallbackLowChancePerSecond = 0.00001, --mud bricks deteriate at this rate when it is raining

    tribeRelationshipScoreThresholds = {
        severeNegative = 5,
        moderateNegative = 25,
        mildNegative = 45,
        mildPositive = 65,
        moderatePositive = 85,
    },

    tribeAIPlayerTimeBetweenUpdates = 30.0, --could increase to optimize, but some things (eg grievances) would need rebalancing
    tribeAIMinimumFavorForTrading = 50,

    aiTribeMaxPopulation = 16, --doesn't affect initial tribe creation, only limits growth/decline
    aiTribeMinPopulation = 5, --doesn't affect initial tribe creation, only limits growth/decline

    --hibernateTribeAfterClientDisconnectDelay = 2880, -- tribes will stay loaded for this long (worldTime) after a player disconnects
    disconnectDelayThreshold = 60.0, -- time in seconds. If a ping from client->server and back (on the game's queue) takes longer than this, the client will disconnect from the server.

    delayBetweenAutoRoleAssignmentsForEachSkill = 40.0, --auto role assignment will only be allowed for already skilled sapiens after this period, any idle sapiens after this period * 2.0, and then reset again after this period * 2.1

    populationLimitPerTribeSoftCap = 150, --for a player controller tribe, birth rate reduces until at around this level the population won't grow any further.
    populationLimitGlobalSoftCap = 300, --As the global population of player controlled loaded sapiens gets closer to this level, birth rate decreases globally
    
    minPopulationForVirusIntroduction = 30,
    minPopulationForRaids = 15,

    logisticsRouteMaxSapiens = 4,


    fireMobRepelDistance = mj:mToP(100.0),

    fleeThreatDistanceFar = mj:mToP(50.0), --fearful notice, normal ignore, courageous ignore
    fleeThreatDistanceMid = mj:mToP(15.0), --fearful run away, normal notice, courageous ignore
    fleeThreatDistanceClose = mj:mToP(5.0), --Distance that idle sapiens will start reacting to threats. Normal sapiens will run away at this distance, courageous will notice

    planNoCompleteThreatDistance = mj:mToP(20.0),
    lowPrioritySelfPlanThreatDistance = mj:mToP(50.0), --Won't do low priority automatic orders within this distance eg. sleep when not exhausted, change clothes, sit etc

    stopWorkThreatDistanceFar = mj:mToP(20.0), --distance from a threat where active sapiens will stop work on any non-essential orders. should be <= planNoCompleteThreatDistance
    stopWorkThreatDistanceMid = mj:mToP(10.0),
    stopWorkThreatDistanceClose = mj:mToP(3.0),

    logChat = false,
}

gameConstants.showInConfigFileKeys = { --All keys can be overrideen in config.lua, but these ones will be always added to the config file to make it clearer that they can be changed
    pauseSpeed = "",
    playSpeed = "",
    fastSpeed = "",
    ultraSpeed = "",

    enabledMods = "To enable mods, supply a list of mod directory names here. Place the mod contents in the mods directory next to this config file. eg. enabledMods = {\"modDir1\",\"modDir2\"}",

    showDebugMenu = "",
    sendServerStatsTextDelay = "Server info can be sent to clients periodically, for display in the debug UI. Comment out or set this to nil to disable.",
    maxPlayerFlyHeightMeters = "Making this any higher causes more issues with the terrain failing to load to the correct detail around the player",
    speedIncreaseFactorAtMaxHeight = "",
    allowedPlansPerFollower = "",
    fireWarmthRadius = "In pre-render units (meters / 8388608.0)",
    maxTerrainSteepness = "Max height difference between hex centers in pre-render units",

    compostBinValueSumRequiredForOutput = "",
    compostBinMaxItemCount = "",
    compostTimeUntilCompostGeneratedDays = "",

    windStormDuration = "",
    windStormPeakDuration = "",
    windAffectedCallbackHighChancePerSecond = "If object is given \"windDestructableHighChance\" then this is how likely per object, eg 0.001 is 1/1000 chance of destruction per second, or an average of one destruction event per object per 1000 seconds during the wind event peak. For storage areas, this is per storage area, not per item in the storage area. High chance is used for light objects in storage areas, moderate for heavier objects in storage areas and flora destruction, low is used for thatch building destruction",
    windAffectedCallbackModerateChancePerSecond = "",
    windAffectedCallbackLowChancePerSecond = "",
    minRainfallForRainDamage = "This is approximately an annual rainfall figure in mm. Any object in a location that receieves annual rainfall below this won't ever receive any rain damage",
    rainAffectedCallbackLowChancePerSecond = "",

    tribeRelationshipScoreThresholds = "",
    tribeAIMinimumFavorForTrading = "",
    aiTribeMaxPopulation = "Doesn't affect initial tribe creation, only limits growth/decline",
    aiTribeMinPopulation = "Doesn't affect initial tribe creation, only limits growth/decline",

    --hibernateTribeAfterClientDisconnectDelay = "Tribes will stay loaded for this long (worldTime) after a player disconnects",
    disconnectDelayThreshold = "Time in seconds. If a ping from client->server and back (on the game's queue) takes longer than this, the client will disconnect from the server.",
    delayBetweenAutoRoleAssignmentsForEachSkill = "Auto role assignment will only be allowed again after this cooldown period per skill type, per tribe",
    populationLimitPerTribeSoftCap = "For a player controller tribe, birth rate reduces until at around this level the population won't grow any further.",
    populationLimitGlobalSoftCap = "As the global population of player controlled loaded sapiens gets closer to this level, birth rate decreases globally",

    fireMobRepelDistance = "Campfires repel mobs up to this distance away in pre-render units (meters / 8388608.0)",
    logChat = "Set to true to enable server-side logging of all chat messages",
    
    fleeThreatDistanceFar = "Distance that idle sapiens will start reacting to threats. Fearful notice at this distance, normal ignore, courageous ignore",
    fleeThreatDistanceMid = "Fearful run away, normal notice, courageous ignore",
    fleeThreatDistanceClose = "Normal sapiens will run away at this distance, courageous will notice",

    planNoCompleteThreatDistance = "Plans will be marked unable to complete if they are within this distance of a threat",
    lowPrioritySelfPlanThreatDistance = "Won't do low priority automatic orders within this distance eg. sleep when not exhausted, change clothes, sit etc",

    stopWorkThreatDistanceFar = "Distance from a threat where fearful active sapiens will stop work on any non-essential orders. should be <= planNoCompleteThreatDistance",
    stopWorkThreatDistanceMid = "normal sapiens",
    stopWorkThreatDistanceClose = "courageous sapiens",
}


gameConstants.seasons = {
    ["spring"] = 1,
    ["summer"] = 2,
    ["autumn"] = 3,
    ["winter"] = 4,
}

return gameConstants
