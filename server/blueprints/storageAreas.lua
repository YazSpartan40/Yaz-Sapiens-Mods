local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
--local vec3 = mjm.vec3

--local constructable = mjrequire "common/constructable"
--local gameObject = mjrequire "common/gameObject"
--local research = mjrequire "common/research"
--local resource = mjrequire "common/resource"



local storageAreaSubNode = {
    type = "constructable",
    constructableType = "storageArea4x4",
}

local storageNode = {
    type = "grid",
    randomOffsetMinDistance = 20.0,
    randomOffsetMaxDistance = 55.0,
    maxRetries = 10,
    rotationYRandom = math.pi * 2.0,
    
    gridWidth = 2,
    gridDepth = 1,
    gridCellSize = vec2(4.0,4.0),

    cellNode = storageAreaSubNode,

    completionSuccessRequiredCount = 1,
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

local storageAreasBlueprint = {
    nodes = {
        storageNode
        --[[{
            type = "constructable",
            maxRetries = 100,
            layoutCenterOffsetMinDistanceMeters = 20.0,
            layoutCenterOffsetMaxDistanceMeters = 55.0,
            layout = "grid",
            layoutGridWidth = 2,
            layoutGridDepth = 2,
            layoutGridCellSize = vec2(2.0,2.0),

            constructableType = "storageArea",

            completionSuccessRequiredCount = 1,
            completionNodesMaxCallCount = 1,
            completionNodes = {
                {
                    type = "clearVerts",
                    count = 1,
                    layout = "radial",
                    layoutCenterPos = "parentPos",
                    layoutMinDistanceMeters = 0.0,
                    layoutMaxDistanceMeters = 2.0,

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
        },]]
    }
}

return storageAreasBlueprint