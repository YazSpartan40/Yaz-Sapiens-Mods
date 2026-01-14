local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
--local vec3 = mjm.vec3


local storageAreaSubNode = {
    type = "constructable",
    constructableType = "storageArea",
}

local storageGridNode = {
    type = "grid",
    radialPathFollowParent = true,
    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 3.0,
    randomOffsetMaxDistance = 16.0,
    maxRetries = 2,
    rotationYRandom = 0.3,
    
    gridWidth = 2,
    gridDepth = 2,
    gridCellSize = vec2(2.0,2.0),

    cellNode = storageAreaSubNode,

    completionSuccessRequiredCount = 2,
    completionNodes = {
        {
            type = "clearVerts",
            randomOffsetMinDistance = 0.0,
            randomOffsetMaxDistance = 2.0,

            minClearRadius = 6.0,
            maxClearRadius = 8.0,
            outputEvolveChance = 0.8,
            outputAssignmentWeights = {
                storageArea = 0.8,
                sapien = 0.1,
                output = 0.1,
            },
        },
    }
}

local craftAreaSubNode = {
    type = "constructable",
    constructableType = "craftArea",
}

local craftAreaGridNode = {
    type = "grid",
    maxRetries = 8,
    --radialPathFollowParent = true,
    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 4.0,
    randomOffsetMaxDistance = 12.0,
    radialPathDistanceMin = 6.0,
    radialPathDistanceMax = 8.0,
    increaseRandomOffsetEachRetry = true,
    rotationYRandom = 0.3,
    levelTerrainRadius = 8.0,
    completionSuccessRequiredCount = 2,
    
    gridWidth = 2,
    gridDepth = 2,
    gridCellSize = vec2(2.0,2.0),

    cellNode = craftAreaSubNode,
}

local storageAndCraftGridNode = {
    type = "group",
    maxRetries = 3,
    completionSuccessRequiredCount = 2,
    subNodes = {
        craftAreaGridNode,
        craftAreaGridNode,
        craftAreaGridNode,
    },
    completionNodes = {
        storageGridNode,
        storageGridNode
    }
}

local gatherSmallRocksNode = {
    type = "gatherResources",
    radialPathSkip = true,
    minGatherCount = 4,
    maxGatherCount = 20,
    gatherResourceType = "rockSmall",
    radialPathFollowParent = true,
    outputAssignmentWeights = {
        storageArea = 0.9,
        sapien = 0.1,
    },
}

local gatherRocksNode = {
    type = "gatherResources",
    radialPathSkip = true,
    minGatherCount = 4,
    maxGatherCount = 20,
    gatherResourceType = "rock",
    outputAssignmentWeights = {
        storageArea = 0.9,
        sapien = 0.1,
    },
}


local flaxPlantNode = {
    type = "flora",
    constructableType = "plant_flaxPlant",
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 20.0,
    rotationYRandom = math.pi * 2.0,
}

local flaxFarmNode = {
    type = "group",
    subNode = flaxPlantNode,
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 8.0,
    minCount = 20,
    maxCount = 40,
}

local function constructQuarryNode(fillObjectType)
    return {
        type = "resourceQuarry",
        fillObjectType = fillObjectType,
        quarryRadius = 20.0,
        quarryDepth = 8.0,
    
        completionNodes = {
            {
                type = "constructable",
                maxRetries = 8,
                randomOffsetMinDistance = 20.0,
                randomOffsetMaxDistance = 24.0,
                rotationYRandom = math.pi * 2.0,
    
                constructableType = "storageArea4x4",
                completionNodes = {
                    {
                        type = "fillStorage",
                        minCount = 200,
                        maxCount = 400,
                        objectType = fillObjectType,
                    }
                }
            },
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
                        minCount = 40,
                        maxCount = 50,
                        objectType = "stonePickaxe",
                    }
                }
            },
        }
    }
end


local lapisQuarryNode = constructQuarryNode("lapisRock")
local marbleRockQuarryNode = constructQuarryNode("marbleRock")
local graniteRockQuarryNode = constructQuarryNode("graniteRock")
local redRockQuarryNode = constructQuarryNode("redRock")
local greenRockQuarryNode = constructQuarryNode("greenRock")

local quarryRandomChoiceNode = {
    type = "randomChoice",
    radialPathDistanceMin = 65.0,
    radialPathDistanceMax = 80.0,
    
    randomOffsetMinDistance = 20.0,
    randomOffsetMaxDistance = 30.0,
    randomOffsetUseRoadEndDistribution = true,

    randomChoices = {
        {
            weight = 1.0,
            nodes = {
                lapisQuarryNode
            }
        },
        {
            weight = 1.0,
            nodes = {
                marbleRockQuarryNode
            }
        },
        {
            weight = 1.0,
            nodes = {
                graniteRockQuarryNode
            }
        },
        {
            weight = 1.0,
            nodes = {
                redRockQuarryNode
            }
        },
        {
            weight = 1.0,
            nodes = {
                greenRockQuarryNode
            }
        }
    },
    
}

local rockKnappingDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "rockKnapping",
    assignToSapiensFraction = 0.75,
}

local spinningDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "spinning",
    assignToSapiensFraction = 0.5,
}

local toolAssemblyDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "toolAssembly",
    assignToSapiensFraction = 0.5,
}


return {
    nodes = {
        rockKnappingDiscoveryNode,
        spinningDiscoveryNode,
        toolAssemblyDiscoveryNode,

        storageAndCraftGridNode,
        storageAndCraftGridNode,
        flaxFarmNode,
        storageAndCraftGridNode,
        gatherRocksNode,
        gatherSmallRocksNode,
        quarryRandomChoiceNode,
    }
}