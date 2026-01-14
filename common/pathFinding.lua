local pathFinding = {}

local proximityTypes = mj:enum { --can't be modified, hard coded in engine
    "reachable",
    "goalPos",
    "lineOfSight",
    "reachableWithoutFinalCollisionTest",
    "reachableWithoutFinalCollisionOrVerticalTests",
}


local pathfindingSapienStates = mj:enum { --not implemented
    "cantSwim",
    "boat"
}

-- NOTE this should be roughly ordered low difficulty to high difficulty, as in some rare situations eg when colliding with multiple objects, the higher index is what is used
local pathNodeDifficulties = mj:indexed {
    {
        key = "rideCanoe",
        difficulty = 0.5,
    },
    {
        key = "fastPath",
        difficulty = 0.6,
    },
    {
        key = "path",
        difficulty = 0.7,
    },
    {
        key = "slowPath",
        difficulty = 0.8,
    },
    {
        key = "dirtRock",
        difficulty = 1.1,
    },
    {
        key = "sand",
        difficulty = 1.4,
    },
    {
        key = "grass",
        difficulty = 1.4,
    },
    {
        key = "snow",
        difficulty = 1.5,
    },
    {
        key = "careful",
        difficulty = 2.0,
    },
    {
        key = "shallowWater",
        difficulty = 3.0,
        allowWaterFastMovement = true,
       -- enterDifficulty = 50.0, --not implemented
        --[[difficultiesBySapienState = { --not implemented
            [pathfindingSapienStates.cantSwim] = -1,
            [pathfindingSapienStates.boat] = 0.1,
        }]]
    },
    {
        key = "deepWater",
        difficulty = 3.0,
        allowWaterFastMovement = true,
    },
    {
        key = "foliage",
        difficulty = 6.0,
    },
    {
        key = "climb",
        difficulty = 10.0,
    },
}

pathFinding.pathfindingSapienStates = pathfindingSapienStates
pathFinding.pathNodeDifficulties = pathNodeDifficulties
pathFinding.proximityTypes = proximityTypes

return pathFinding