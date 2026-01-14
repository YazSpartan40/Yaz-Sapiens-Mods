local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
--local vec3 = mjm.vec3

local wheatStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "wheat",
}

local firedUrnHulledWheatStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedUrnHulledWheat",
}

local firedUrnFlourStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedUrnFlour",
}

local firedUrnStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "firedUrn",
}



local breadDoughStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "breadDough",
}

local flatbreadStorageAreaNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
    restrictContentsResourceType = "flatbread",
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
        randomOffsetMinDistance = 4.0,
        randomOffsetMaxDistance = 12.0,
        radialPathDistanceMin = 6.0,
        radialPathDistanceMax = 8.0,
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

local wheatPlantNode = {
    type = "flora",
    constructableType = "plant_wheatPlant",
    rotationYRandom = math.pi * 2.0,
}

local wheatFarmNode = {
    type = "grid",
    radialPathFollowParent = true,

    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 8.0,
    randomOffsetMaxDistance = 10.0,
    radialPathDistanceMin = 20.0,
    radialPathDistanceMax = 30.0,
    maxRetries = 2,
    rotationYRandom = 0.3,
    
    gridMinWidth = 3,
    gridMaxWidth = 12,
    gridMinDepth = 12,
    gridMaxDepth = 18,
    gridCellSize = vec2(2.6,0.9),

    cellNode = wheatPlantNode,
}

local campfireNode = {
    type = "constructable",
    maxRetries = 8,
    radialPathFollowParent = true,
    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 4.0,
    randomOffsetMaxDistance = 20.0,
    radialPathDistanceMin = 6.0,
    radialPathDistanceMax = 8.0,
    increaseRandomOffsetEachRetry = true,

    constructableType = "campfire",
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


local rockKnappingDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "rockKnapping",
    assignToSapiensFraction = 0.5,
}

local threshingDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "threshing",
    assignToSapiensFraction = 0.5,
}

local grindingDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "grinding",
    assignToSapiensFraction = 0.5,
}

local bakingDiscoveryNode = {
    type = "discovery",
    radialPathSkip = true,
    researchType = "baking",
    assignToSapiensFraction = 0.5,
}


return {
    nodes = {
        craftAreaGridNode,
        createThatchHutNodeWithContentsNode(wheatStorageAreaNode),
        createThatchHutNodeWithContentsNode(firedUrnHulledWheatStorageAreaNode),
        createThatchHutNodeWithContentsNode(firedUrnFlourStorageAreaNode),
        wheatFarmNode,
        wheatFarmNode,
        wheatFarmNode,
        
        craftAreaGridNode,
        campfireNode,
        createThatchHutNodeWithContentsNode(firedUrnStorageAreaNode),
        createThatchHutNodeWithContentsNode(breadDoughStorageAreaNode),
        createThatchHutNodeWithContentsNode(flatbreadStorageAreaNode),
        campfireNode,
        wheatFarmNode,
        rockKnappingDiscoveryNode,
        threshingDiscoveryNode,
        grindingDiscoveryNode,
        bakingDiscoveryNode,
        
    }
}