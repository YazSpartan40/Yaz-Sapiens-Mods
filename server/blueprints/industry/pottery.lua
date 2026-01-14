local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate


local forestryPineNode = {
    type = "flora",
    maxRetries = 4,
    randomOffsetMinDistance = 0.0,
    randomOffsetMaxDistance = 80.0,

    constructableTypeWeights = {
        ["plant_pine1"] = 1.0,
        ["plant_pine2"] = 1.0,
        ["plant_pine3"] = 1.0,
        ["plant_pine4"] = 1.0,
    },
    rotationYRandom = math.pi * 2.0,
}

local forestryPineScatterNode = {
    type = "group",
    subNode = forestryPineNode,
    minCount = 20,
    maxCount = 30,
}

local mudBrickDryStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "mudBrickDry",
}

local firedUrnStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedUrn",
}

local firedBowlStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedBowl",
}

local firedBrickStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedBrick",
}

local firedTileStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedTile",
}

local thatchHutNode = {
    type = "group",
    subNodes = {
        {
            type = "constructable",
            constructableType = "place_log",
            ignoreCollisions = true,
            pos = vec3(-2.0,1.0,-2.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
        },
        {
            type = "constructable",
            constructableType = "place_log",
            ignoreCollisions = true,
            pos = vec3(2.0,1.0,-2.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
        },
        {
            type = "constructable",
            constructableType = "thatchWall",
            ignoreCollisions = true,
            pos = vec3(0.0,0.0,2.0),
            rotation = mat3Identity,
        },
        {
            type = "constructable",
            constructableType = "thatchRoof",
            ignoreCollisions = true,
            pos = vec3(0.0,2.0,0.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
        },
    }
}



local function createThatchHutNodeWithContentsNode(contentsNode)
    return {
        type = "group",
        radialPathFollowParent = true,
        randomOffsetUseRoadsideDistribution = true,
        randomOffsetMinDistance = 2.0,
        randomOffsetMaxDistance = 8.0,
        radialPathDistanceMin = 2.0,
        radialPathDistanceMax = 4.0,
        increaseRandomOffsetEachRetry = true,
        levelTerrainRadius = 8.0,
        maxRetries = 16,
        rotationYRandom = math.pi * 2.0,
    
        subNodes = {
            thatchHutNode,
        },
        completionNodes = {
            contentsNode
        }
    }
end

local craftAreaSubNode = {
    type = "constructable",
    constructableType = "craftArea",
}

local craftAreaGridNode = {
    type = "grid",
    maxRetries = 8,
    --radialPathFollowParent = true,
    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 8.0,
    radialPathDistanceMin = 2.0,
    radialPathDistanceMax = 4.0,
    increaseRandomOffsetEachRetry = true,
    rotationYRandom = 0.3,
    levelTerrainRadius = 8.0,
    completionSuccessRequiredCount = 2,
    
    gridWidth = 2,
    gridDepth = 2,
    gridCellSize = vec2(2.0,2.0),

    cellNode = craftAreaSubNode,
}


local kilnNode = {
    type = "constructable",
    maxRetries = 8,
    radialPathFollowParent = true,
    randomOffsetUseRoadsideDistribution = true,
    increaseRandomOffsetEachRetry = true,
    randomOffsetMinDistance = 4.0,
    randomOffsetMaxDistance = 20.0,
    radialPathDistanceMin = 2.0,
    radialPathDistanceMax = 4.0,

    constructableType = "brickKiln",
    rotationYRandom = math.pi * 0.1,

    completionNodes = {
        {
            type = "addFuel",
        },
        {
            type = "lightObject",
        },
        {
            type = "clearVerts",
            randomOffsetMinDistance = 0.0,
            randomOffsetMaxDistance = 4.0,

            minClearRadius = 8.0,
            maxClearRadius = 16.0,
            outputEvolveChance = 0.8,
            outputAssignmentWeights = {
                storageArea = 0.8,
                sapien = 0.1,
                output = 0.1,
            },
        },
    }
}

local function constructAndFillStorageNode(objectType)
    return {
        type = "constructable",
        radialPathFollowParent = true,
        randomOffsetUseRoadsideDistribution = true,
        increaseRandomOffsetEachRetry = true,
        maxRetries = 8,
        randomOffsetMinDistance = 4.0,
        randomOffsetMaxDistance = 8.0,
        rotationYRandom = math.pi * 2.0,
        levelTerrainRadius = 4.0,

        constructableType = "storageArea4x4",
        completionNodes = {
            {
                type = "fillStorage",
                minCount = 100,
                maxCount = 150,
                objectType = objectType,
            }
        }
    }
end

local function constructQuarryNode(fillObjectType)
    return {
        type = "resourceQuarry",
        fillObjectType = fillObjectType,
        quarryRadius = 40.0,
        quarryDepth = 12.0,

        radialPathDistanceMin = 65.0,
        radialPathDistanceMax = 80.0,
        
        randomOffsetMinDistance = 30.0,
        randomOffsetMaxDistance = 40.0,
        randomOffsetUseRoadEndDistribution = true,
        radialPathFollowParent = true,
        completionNodes = {
            {
                type = "constructable",
                maxRetries = 8,
                randomOffsetMinDistance = 20.0,
                randomOffsetMaxDistance = 30.0,
                rotationYRandom = math.pi * 2.0,

                constructableType = "storageArea4x4",
                completionNodes = {
                    {
                        type = "fillStorage",
                        minCount = 60,
                        maxCount = 70,
                        objectType = "flintAxeHead",
                    },
                }
            }
        }
    }
end

--local handAxeNode = constructAndFillStorageNode("stoneAxeHead")
local clayStorageNode = constructAndFillStorageNode("clay")
local clayQuarryNode = constructQuarryNode("clay")



local potteryDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "pottery",
    assignToSapiensFraction = 0.75,
}

local potteryFiringDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "potteryFiring",
    assignToSapiensFraction = 0.5,
}

local diggingDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "digging",
    assignToSapiensFraction = 0.4,
}

return {
    nodes = {
        potteryDiscoveryNode,
        potteryFiringDiscoveryNode,
        diggingDiscoveryNode,
        craftAreaGridNode,
        createThatchHutNodeWithContentsNode(mudBrickDryStorageAreaNode),
        createThatchHutNodeWithContentsNode(firedUrnStorageAreaNode),
        kilnNode,
        kilnNode,
        forestryPineScatterNode,
        craftAreaGridNode,
        craftAreaGridNode,
        createThatchHutNodeWithContentsNode(firedBowlStorageAreaNode),
        createThatchHutNodeWithContentsNode(firedBrickStorageAreaNode),
        createThatchHutNodeWithContentsNode(firedTileStorageAreaNode),
        kilnNode,
        kilnNode,
        clayStorageNode,
        --handAxeNode,
        clayQuarryNode,
    }
}