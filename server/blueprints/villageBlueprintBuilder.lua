local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
--local dot = mjm.dot

local villageBlueprintBuilder = {}


local function constructMedicineNodesArray(nodeConstructionInfo)
    local resultNodeArray = {}
    for i,subInfo in ipairs(nodeConstructionInfo) do
        local node = {
            type = "group",
            minCount = subInfo.minPlantCount or 4,
            maxCount = subInfo.minPlantCount or 8,
            randomOffsetUseRoadsideDistribution = true,
            randomOffsetMinDistance = 4.0,
            randomOffsetMaxDistance = 12.0,
            
            subNode = {
                type = "flora",
                constructableType = subInfo.constructableType,
                randomOffsetMinDistance = 0.0,
                randomOffsetMaxDistance = 5.0,
                rotationYRandom = math.pi * 2.0,
            },

            maxRetries = 2,
            completionSuccessRequiredCount = 2,
            completionNodes = {
                {
                    type = "constructable",
                    maxRetries = 2,
                    randomOffsetMinDistance = 0.0,
                    randomOffsetMaxDistance = 16.0,
                    rotationYRandom = math.pi * 2.0,
        
                    constructableType = "storageArea",
                    completionNodes = {
                        {
                            type = "fillStorage",
                            minCount = 2,
                            maxCount = 8,
                            objectType = subInfo.objectType,
                        }
                    }
                },
            }
        }
        table.insert(resultNodeArray, node)
    end
    return resultNodeArray
end

local medicineNode = {
    type = "randomChoice",
    randomChoices = {
        {
            weight = 0.25, --injury
            nodes = constructMedicineNodesArray({
                {
                    constructableType = "plant_poppyPlant", 
                    objectType = "poppyFlower",
                },
                {
                    constructableType = "plant_turmericPlant", 
                    objectType = "turmericRoot",
                },
                {
                    constructableType = "plant_marigoldPlant", 
                    objectType = "marigoldFlower",
                },
            })
        },
        {
            weight = 0.25, --burn
            nodes = constructMedicineNodesArray({
                {
                    constructableType = "plant_elderberryTree", 
                    objectType = "elderberry",
                    minPlantCount = 2,
                    maxPlantCount = 4,
                },
                {
                    constructableType = "plant_aloePlant", 
                    objectType = "aloeLeaf",
                },
                {
                    constructableType = "plant_marigoldPlant", 
                    objectType = "marigoldFlower",
                },
            })
        },
        {
            weight = 0.25, --food poisoning
            nodes = constructMedicineNodesArray({
                {
                    constructableType = "plant_gingerPlant", 
                    objectType = "gingerRoot",
                },
                {
                    constructableType = "plant_garlicPlant", 
                    objectType = "garlic",
                },
                {
                    constructableType = "plant_turmericPlant", 
                    objectType = "turmericRoot",
                },
            })
        },
        {
            weight = 0.25, --virus
            nodes = constructMedicineNodesArray({
                {
                    constructableType = "plant_echinaceaPlant", 
                    objectType = "echinaceaFlower",
                },
                {
                    constructableType = "plant_garlicPlant", 
                    objectType = "garlic",
                },
                {
                    constructableType = "plant_elderberryTree", 
                    objectType = "elderberry",
                    minPlantCount = 2,
                    maxPlantCount = 4,
                },
            })
        },
    }
}

local bedsInSmallHutNode = {
    type = "grid",
    gridWidth = 5,
    gridDepth = 1,
    gridCellSize = vec2(0.7,2.0),
    pos = vec3(0.0,0.0,-1.0),

    cellNode = {
        type = "constructable",
        constructableType = "hayBed",
        rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
    },
}

local storageAreasInSmallHutNode = {
    type = "grid",
    gridWidth = 2,
    gridDepth = 2,
    gridCellSize = vec2(2.0,2.0),

    cellNode = {
        type = "constructable",
        constructableType = "storageArea",
    },
}

local thatchRoofOnLogsNode = {
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
            constructableType = "place_log",
            ignoreCollisions = true,
            pos = vec3(-2.0,1.0,2.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
        },
        {
            type = "constructable",
            constructableType = "place_log",
            ignoreCollisions = true,
            pos = vec3(2.0,1.0,2.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
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
local thatchHutNode = {
    type = "group",
    subNodes = {
        {
            type = "constructable",
            constructableType = "thatchWall",
            ignoreCollisions = true,
            pos = vec3(0.0,0.0,-2.0),
            rotation = mat3Identity,
        },
        {
            type = "constructable",
            constructableType = "thatchWallLargeWindow",
            ignoreCollisions = true,
            pos = vec3(0.0,0.0,2.0),
            rotation = mat3Identity,
        },
        {
            type = "constructable",
            constructableType = "thatchWallDoor",
            ignoreCollisions = true,
            pos = vec3(-2.0,0.0,0.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
        },
        {
            type = "constructable",
            constructableType = "thatchRoofEnd",
            ignoreCollisions = true,
            pos = vec3(-2.0,2.0,0.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
        },
        {
            type = "constructable",
            constructableType = "thatchWallLargeWindow",
            ignoreCollisions = true,
            pos = vec3(2.0,0.0,0.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
        },
        {
            type = "constructable",
            constructableType = "thatchRoofEnd",
            ignoreCollisions = true,
            pos = vec3(2.0,2.0,0.0),
            rotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
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

local thatchHutWithBedsNodeAdditional = {
    type = "group",
    randomOffsetMinDistance = 6.0,
    randomOffsetMaxDistance = 15.0,
    levelTerrainRadius = 8.0,
    rotationYRandom = math.pi,
    maxRetries = 4,

    subNodes = {
        thatchHutNode,
    },
    completionNodes = {
        bedsInSmallHutNode
    }
}

local thatchHutWithBedsNode = {
    type = "group",

    randomOffsetUseRoadsideDistribution = true,
    maxRetries = 4,
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 8.0,
    radialPathDistanceMin = 2.0,
    radialPathDistanceMax = 4.0,
    increaseRandomOffsetEachRetry = true,
    levelTerrainRadius = 8.0,

    subNodes = {
        thatchHutNode,
    },
    completionNodes = {
        bedsInSmallHutNode,
        thatchHutWithBedsNodeAdditional,
        thatchHutWithBedsNodeAdditional
    }
}

local thatchHutWithStorageNode = {
    type = "group",
    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 6.0,
    randomOffsetMaxDistance = 15.0,
    levelTerrainRadius = 8.0,
    maxRetries = 2,

    subNodes = {
        thatchRoofOnLogsNode,
    },
    completionNodes = {
        storageAreasInSmallHutNode
    }
}

local gardenPlantNode = {
    type = "flora",

    randomOffsetMinDistance = 0.0,
    randomOffsetMaxDistance = 30.0,

    constructableTypeWeights = {
        ["plant_appleTree"] = 1.0,
        ["plant_orangeTree"] = 1.0,
        ["plant_peachTree"] = 1.0,
        ["plant_elderberryTree"] = 1.0,
        ["plant_raspberryBush"] = 1.0,
        ["plant_gooseberryBush"] = 1.0,
        ["plant_flaxPlant"] = 1.0,
        ["plant_wheatPlant"] = 1.0,
    },
    constructableTypeMaxDifferentTypesInGroup = 3,
    
    rotationYRandom = math.pi * 2.0,
}

local gardenNode = {
    type = "group",
    subNode = gardenPlantNode,
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 16.0,
    minCount = 8,
    maxCount = 30,
}

local wheatPlantNode = {
    type = "flora",
    constructableType = "plant_wheatPlant",
    rotationYRandom = math.pi * 2.0,
}

local wheatFarmNode = {
    type = "grid",

    randomOffsetUseRoadsideDistribution = true,
    randomOffsetMinDistance = 6.0,
    randomOffsetMaxDistance = 8.0,
    maxRetries = 2,
    rotationYRandom = 0.3,
    
    gridMinWidth = 1,
    gridMaxWidth = 4,
    gridMinDepth = 10,
    gridMaxDepth = 15,
    gridCellSize = vec2(2.6,0.8),

    cellNode = wheatPlantNode,
}


local flaxPlantNode = {
    type = "flora",
    constructableType = "plant_flaxPlant",
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 8.0,
    rotationYRandom = math.pi * 2.0,
}

local flaxFarmNode = {
    type = "group",
    subNode = flaxPlantNode,
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 8.0,
    minCount = 8,
    maxCount = 30,
}


local hayBedAroundCenterNode = {
    type = "constructable",
    maxRetries = 4,
    randomOffsetMinDistance = 3.0,
    randomOffsetMaxDistance = 3.2,

    constructableType = "hayBed",
    rotationYSetRadialOffsetFromParant = true,
    rotationYRandom = math.pi * 0.1,
}


local hayBedsAroundCenterNode = {
    type = "group",
    subNode = hayBedAroundCenterNode,
    minCount = 4,
    maxCount = 8,
}


local forestryBirchNode = {
    type = "flora",

    randomOffsetMinDistance = 0.0,
    randomOffsetMaxDistance = 20.0,

    constructableTypeWeights = {
        ["plant_birch1"] = 1.0,
        ["plant_birch2"] = 1.0,
        ["plant_birch3"] = 1.0,
        ["plant_birch4"] = 1.0,
    },
    rotationYRandom = math.pi * 2.0,
}
local forestryPineNode = {
    type = "flora",

    randomOffsetMinDistance = 0.0,
    randomOffsetMaxDistance = 20.0,

    constructableTypeWeights = {
        ["plant_pine1"] = 1.0,
        ["plant_pine2"] = 1.0,
        ["plant_pine3"] = 1.0,
        ["plant_pine4"] = 1.0,
        ["plant_pineBig1"] = 0.01,
    },
    rotationYRandom = math.pi * 2.0,
}

local forestryAspenNode = {
    type = "flora",

    randomOffsetMinDistance = 0.0,
    randomOffsetMaxDistance = 20.0,

    constructableTypeWeights = {
        ["plant_aspen1"] = 1.0,
        ["plant_aspen2"] = 1.0,
        ["plant_aspen3"] = 1.0,
        ["plant_aspenBig1"] = 0.01,
    },
    rotationYRandom = math.pi * 2.0,
}

--[[
["plant_willow1"] = 1.0,
["plant_willow2"] = 1.0,
["plant_bamboo1"] = 1.0,
["plant_bamboo2"] = 1.0,
]]

local forestryPineScatterNode = {
    type = "group",
    subNode = forestryPineNode,
    minCount = 1,
    maxCount = 20,
}
local forestryBirchScatterNode = {
    type = "group",
    subNode = forestryBirchNode,
    minCount = 1,
    maxCount = 20,
}
local forestryAspenScatterNode = {
    type = "group",
    subNode = forestryAspenNode,
    minCount = 1,
    maxCount = 20,
}

local forestryFloraRandomChoiceNode = {
    type = "randomChoice",
    randomChoices = {
        {
            weight = 0.33,
            nodes = {
                forestryPineScatterNode
            }
        },
        {
            weight = 0.33,
            nodes = {
                forestryBirchScatterNode
            }
        },
        {
            weight = 0.33,
            nodes = {
                forestryAspenScatterNode
            }
        }
    }
}


local storageAreaSubNode = {
    type = "constructable",
    constructableType = "storageArea",
}

local storageNode = {
    type = "grid",
    randomOffsetUseRoadsideDistribution = true,
    maxRetries = 4,
    randomOffsetMinDistance = 2.0,
    randomOffsetMaxDistance = 8.0,
    radialPathDistanceMin = 2.0,
    radialPathDistanceMax = 4.0,
    increaseRandomOffsetEachRetry = true,
    levelTerrainRadius = 8.0,
    rotationYRandom = 0.3,
    
    gridWidth = 2,
    gridDepth = 2,
    gridCellSize = vec2(2.0,2.0),

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

local campfireNode = {
    type = "group",
    subNodes = {
        {
            type = "gatherResources",
            minGatherCount = 4,
            maxGatherCount = 20,
            gatherResourceType = "rock",
            completionSuccessRequiredCount = 4,
            outputAssignmentWeights = {
                storageArea = 0.9,
                sapien = 0.1,
            },
        },
        {
            type = "gatherResources",
            minGatherCount = 4,
            maxGatherCount = 20,
            gatherResourceType = "branch",
            completionSuccessRequiredCount = 4,
            outputAssignmentWeights = {
                storageArea = 0.95,
                sapien = 0.05,
            },
        },
        {
            type = "discovery",
            researchType = "fire",
            assignToSapiensFraction = 0.2,
        },
        {
            type = "constructable",
            maxRetries = 4,
            randomOffsetMinDistance = 0.0,
            randomOffsetMaxDistance = 3.0,

            constructableType = "campfire",
            rotationYRandom = math.pi * 0.1,

            completionNodes = {
                hayBedsAroundCenterNode,
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
                {
                    type = "clearVerts",
                    randomOffsetMinDistance = 4.0,
                    randomOffsetMaxDistance = 8.0,
        
                    minClearRadius = 4.0,
                    maxClearRadius = 8.0,
                    outputEvolveChance = 0.8,
                    outputAssignmentWeights = {
                        storageArea = 0.8,
                        sapien = 0.1,
                        output = 0.1,
                    },
                },
            }
        },
    }
}

local thatchBuildingDiscoveryNode = {
    type = "discovery",
    researchType = "thatchBuilding",
    assignToSapiensFraction = 0.15,
}



function villageBlueprintBuilder:buildBlueprint(additionalNodes)

    local radialPathNodes = {
        storageNode,
        thatchHutWithBedsNode,
        thatchHutWithStorageNode,
        gardenNode,
        storageNode,
        thatchHutWithStorageNode,
        thatchHutWithBedsNode,
        forestryFloraRandomChoiceNode,
        wheatFarmNode,
        medicineNode,
        flaxFarmNode,
        thatchHutWithStorageNode,
    }

    for i,node in ipairs(additionalNodes) do
        table.insert(radialPathNodes, node)
    end


    local radialPathsNode = {
        type = "radialPaths",
        nodes = radialPathNodes
    }

    return {
        nodes = {
            thatchBuildingDiscoveryNode,
            campfireNode,
            radialPathsNode,
        }
    }
end

return villageBlueprintBuilder