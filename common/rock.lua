local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

local resource = mjrequire "common/resource"
local pathFinding = mjrequire "common/pathFinding"
local harvestable = mjrequire "common/harvestable"
local tool = mjrequire "common/tool"


local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"
local selectionGroup = mjrequire "common/selectionGroup"

local rock = {}

rock.types = typeMaps:createMap("rock", {
    {
        key = "rock",
        objectTypeKey = "rock",
        smallObjectTypeKey = "rockSmall",
        largeObjectTypeKey = "rockLarge",
        stoneBlockTypeKey = "stoneBlock",
        craftablePostfix = "",
        modelNamePostfix = "_rock1",
    },
    {
        key = "limestone",
        isSoftRock = true,
        objectTypeKey = "limestoneRock",
        smallObjectTypeKey = "limestoneRockSmall",
        largeObjectTypeKey = "limestoneRockLarge",
        stoneBlockTypeKey = "limestoneRockBlock",
        craftablePostfix = "_limestone",
        modelNamePostfix = "_limestone",
    },
    {
        key = "sandstoneYellowRock",
        isSoftRock = true,
        objectTypeKey = "sandstoneYellowRock",
        smallObjectTypeKey = "sandstoneYellowRockSmall",
        largeObjectTypeKey = "sandstoneYellowRockLarge",
        stoneBlockTypeKey = "sandstoneYellowRockBlock",
        craftablePostfix = "_sandstoneYellowRock",
        modelNamePostfix = "_sandstoneYellowRock",
    },
    {
        key = "sandstoneRedRock",
        isSoftRock = true,
        objectTypeKey = "sandstoneRedRock",
        smallObjectTypeKey = "sandstoneRedRockSmall",
        largeObjectTypeKey = "sandstoneRedRockLarge",
        stoneBlockTypeKey = "sandstoneRedRockBlock",
        craftablePostfix = "_sandstoneRedRock",
        modelNamePostfix = "_sandstoneRedRock",
    },
    {
        key = "sandstoneOrangeRock",
        isSoftRock = true,
        objectTypeKey = "sandstoneOrangeRock",
        smallObjectTypeKey = "sandstoneOrangeRockSmall",
        largeObjectTypeKey = "sandstoneOrangeRockLarge",
        stoneBlockTypeKey = "sandstoneOrangeRockBlock",
        craftablePostfix = "_sandstoneOrangeRock",
        modelNamePostfix = "_sandstoneOrangeRock",
    },
    {
        key = "sandstoneBlueRock",
        isSoftRock = true,
        objectTypeKey = "sandstoneBlueRock",
        smallObjectTypeKey = "sandstoneBlueRockSmall",
        largeObjectTypeKey = "sandstoneBlueRockLarge",
        stoneBlockTypeKey = "sandstoneBlueRockBlock",
        craftablePostfix = "_sandstoneBlueRock",
        modelNamePostfix = "_sandstoneBlueRock",
    },
    {
        key = "redRock",
        objectTypeKey = "redRock",
        smallObjectTypeKey = "redRockSmall",
        largeObjectTypeKey = "redRockLarge",
        stoneBlockTypeKey = "redRockBlock",
        craftablePostfix = "_redRock",
        modelNamePostfix = "_redRock",
    },
    {
        key = "greenRock",
        objectTypeKey = "greenRock",
        smallObjectTypeKey = "greenRockSmall",
        largeObjectTypeKey = "greenRockLarge",
        stoneBlockTypeKey = "greenRockBlock",
        craftablePostfix = "_greenRock",
        modelNamePostfix = "_greenRock",
    },
    {
        key = "graniteRock",
        objectTypeKey = "graniteRock",
        smallObjectTypeKey = "graniteRockSmall",
        largeObjectTypeKey = "graniteRockLarge",
        stoneBlockTypeKey = "graniteRockBlock",
        craftablePostfix = "_graniteRock",
        modelNamePostfix = "_graniteRock",
    },
    {
        key = "marbleRock",
        objectTypeKey = "marbleRock",
        smallObjectTypeKey = "marbleRockSmall",
        largeObjectTypeKey = "marbleRockLarge",
        stoneBlockTypeKey = "marbleRockBlock",
        craftablePostfix = "_marbleRock",
        modelNamePostfix = "_marbleRock",
    },
    {
        key = "lapisRock",
        objectTypeKey = "lapisRock",
        smallObjectTypeKey = "lapisRockSmall",
        largeObjectTypeKey = "lapisRockLarge",
        stoneBlockTypeKey = "lapisRockBlock",
        craftablePostfix = "_lapisRock",
        modelNamePostfix = "_lapisRock",
    },
})

function rock:mjInit()
    rock.validTypes = typeMaps:createValidTypesArray("rock", rock.types)

    rock.allRocksSelectionGroupTypeIndex = selectionGroup.types.allRocks.index
    rock.allSmallRocksSelectionGroupTypeIndex = selectionGroup.types.allSmallRocks.index
    rock.allRockBlocksSelectionGroupTypeIndex = selectionGroup.types.allRockBlocks.index

end


local softRockToolUsages = {
    [tool.types.knappingCrude.index] = {
        [tool.propertyTypes.speed.index] = 1.0,
        [tool.propertyTypes.durability.index] = 0.5,
    },
}

local hardRockToolUsages = {
    [tool.types.knappingCrude.index] = {
        [tool.propertyTypes.speed.index] = 1.0,
        [tool.propertyTypes.durability.index] = 1.0,
    },
}

local softRockSmallToolUsages = {
    [tool.types.weaponBasic.index] = {
        [tool.propertyTypes.damage.index] = 0.2,
        [tool.propertyTypes.durability.index] = 0.5,
    },
    [tool.types.knapping.index] = {
        [tool.propertyTypes.speed.index] = 1.0,
        [tool.propertyTypes.durability.index] = 0.5,
    },
    [tool.types.knappingCrude.index] = {
        [tool.propertyTypes.speed.index] = 1.0,
        [tool.propertyTypes.durability.index] = 0.5,
    },
}

local hardRockSmallToolUsages = {
    [tool.types.weaponBasic.index] = {
        [tool.propertyTypes.damage.index] = 0.2,
        [tool.propertyTypes.durability.index] = 1.0,
    },
    [tool.types.knapping.index] = {
        [tool.propertyTypes.speed.index] = 1.0,
        [tool.propertyTypes.durability.index] = 1.0,
    },
    [tool.types.knappingCrude.index] = {
        [tool.propertyTypes.speed.index] = 1.0,
        [tool.propertyTypes.durability.index] = 1.0,
    },
}

function rock:addGameObjects(gameObject)
    local gameObjectsTable = {
        rock = {
            modelName = "rock1",
            rockTypeIndex = rock.types.rock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rock.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        rockSmall = {
            modelName = "rockSmall",
            rockTypeIndex = rock.types.rock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmall.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        rockLarge = {
            modelName = "rockLarge",
            rockTypeIndex = rock.types.rock.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        stoneBlock = {
            modelName = "stoneBlock",
            rockTypeIndex = rock.types.rock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockHard.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        limestoneRock = {
            modelName = "limestoneRock",
            rockTypeIndex = rock.types.limestone.index,
            scale = 1.0,
            scarcityValue = 2,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        limestoneRockSmall = {
            modelName = "limestoneRockSmall",
            rockTypeIndex = rock.types.limestone.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 2,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmallSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        limestoneRockLarge = {
            modelName = "limestoneRockLarge",
            rockTypeIndex = rock.types.limestone.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            scarcityValue = 2,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        limestoneRockBlock = {
            modelName = "limestoneRockBlock",
            rockTypeIndex = rock.types.limestone.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        sandstoneYellowRock = {
            modelName = "sandstoneYellowRock",
            rockTypeIndex = rock.types.sandstoneYellowRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 10,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        sandstoneYellowRockSmall = {
            modelName = "sandstoneYellowRockSmall",
            rockTypeIndex = rock.types.sandstoneYellowRock.index,
            scale = 1.0,
            scarcityValue = 10,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmallSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        sandstoneYellowRockLarge = {
            modelName = "sandstoneYellowRockLarge",
            rockTypeIndex = rock.types.sandstoneYellowRock.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            scarcityValue = 10,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        sandstoneYellowRockBlock = {
            modelName = "sandstoneYellowRockBlock",
            rockTypeIndex = rock.types.sandstoneYellowRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        
        sandstoneRedRock = {
            modelName = "sandstoneRedRock",
            rockTypeIndex = rock.types.sandstoneRedRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 10,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        sandstoneRedRockSmall = {
            modelName = "sandstoneRedRockSmall",
            rockTypeIndex = rock.types.sandstoneRedRock.index,
            scale = 1.0,
            scarcityValue = 10,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmallSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        sandstoneRedRockLarge = {
            modelName = "sandstoneRedRockLarge",
            rockTypeIndex = rock.types.sandstoneRedRock.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            scarcityValue = 10,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        sandstoneRedRockBlock = {
            modelName = "sandstoneRedRockBlock",
            rockTypeIndex = rock.types.sandstoneRedRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        
        sandstoneOrangeRock = {
            modelName = "sandstoneOrangeRock",
            rockTypeIndex = rock.types.sandstoneOrangeRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 10,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        sandstoneOrangeRockSmall = {
            modelName = "sandstoneOrangeRockSmall",
            rockTypeIndex = rock.types.sandstoneOrangeRock.index,
            scale = 1.0,
            scarcityValue = 10,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmallSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        sandstoneOrangeRockLarge = {
            modelName = "sandstoneOrangeRockLarge",
            rockTypeIndex = rock.types.sandstoneOrangeRock.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            scarcityValue = 10,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        sandstoneOrangeRockBlock = {
            modelName = "sandstoneOrangeRockBlock",
            rockTypeIndex = rock.types.sandstoneOrangeRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        
        sandstoneBlueRock = {
            modelName = "sandstoneBlueRock",
            rockTypeIndex = rock.types.sandstoneBlueRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 10,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        sandstoneBlueRockSmall = {
            modelName = "sandstoneBlueRockSmall",
            rockTypeIndex = rock.types.sandstoneBlueRock.index,
            scale = 1.0,
            scarcityValue = 10,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmallSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = softRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        sandstoneBlueRockLarge = {
            modelName = "sandstoneBlueRockLarge",
            rockTypeIndex = rock.types.sandstoneBlueRock.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            scarcityValue = 10,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        sandstoneBlueRockBlock = {
            modelName = "sandstoneBlueRockBlock",
            rockTypeIndex = rock.types.sandstoneBlueRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockSoft.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },
        
        redRock = {
            modelName = "redRock",
            rockTypeIndex = rock.types.redRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 10,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rock.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        redRockSmall = {
            modelName = "redRockSmall",
            rockTypeIndex = rock.types.redRock.index,
            scale = 1.0,
            scarcityValue = 10,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmall.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        redRockLarge = {
            modelName = "redRockLarge",
            rockTypeIndex = rock.types.redRock.index,
            scale = 0.6,
            randomMaxScale = 1.5,
            scarcityValue = 10,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        redRockBlock = {
            modelName = "redRockBlock",
            rockTypeIndex = rock.types.redRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockHard.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        greenRock = {
            modelName = "greenRock",
            rockTypeIndex = rock.types.greenRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 20,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rock.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        greenRockSmall = {
            modelName = "greenRockSmall",
            rockTypeIndex = rock.types.greenRock.index,
            scale = 1.0,
            scarcityValue = 20,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmall.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        greenRockLarge = {
            modelName = "greenRockLarge",
            rockTypeIndex = rock.types.greenRock.index,
            scale = 0.6,
            scarcityValue = 20,
            randomMaxScale = 1.5,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        greenRockBlock = {
            modelName = "greenRockBlock",
            rockTypeIndex = rock.types.greenRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockHard.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        

        graniteRock = {
            modelName = "graniteRock",
            rockTypeIndex = rock.types.graniteRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 20,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rock.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        graniteRockSmall = {
            modelName = "graniteRockSmall",
            rockTypeIndex = rock.types.graniteRock.index,
            scale = 1.0,
            scarcityValue = 20,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmall.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        graniteRockLarge = {
            modelName = "graniteRockLarge",
            rockTypeIndex = rock.types.graniteRock.index,
            scale = 0.6,
            scarcityValue = 20,
            randomMaxScale = 1.5,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        graniteRockBlock = {
            modelName = "graniteRockBlock",
            rockTypeIndex = rock.types.graniteRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockHard.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },

        
        marbleRock = {
            modelName = "marbleRock",
            rockTypeIndex = rock.types.marbleRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 20,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rock.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },
        },
        marbleRockSmall = {
            modelName = "marbleRockSmall",
            rockTypeIndex = rock.types.marbleRock.index,
            scale = 1.0,
            scarcityValue = 20,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmall.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        marbleRockLarge = {
            modelName = "marbleRockLarge",
            rockTypeIndex = rock.types.marbleRock.index,
            scale = 0.6,
            scarcityValue = 20,
            randomMaxScale = 1.5,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        marbleRockBlock = {
            modelName = "marbleRockBlock",
            rockTypeIndex = rock.types.marbleRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockHard.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },
        
        lapisRock = {
            modelName = "lapisRock",
            rockTypeIndex = rock.types.lapisRock.index,
            scale = 1.0,
            hasPhysics = true,
            scarcityValue = 20,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rock.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allRocksSelectionGroupTypeIndex
            },

            --tradeBatchSize = 20,
            --tradeValue = 8,
        },
        lapisRockSmall = {
            modelName = "lapisRockSmall",
            rockTypeIndex = rock.types.lapisRock.index,
            scale = 1.0,
            scarcityValue = 20,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.rockSmall.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            toolUsages = hardRockSmallToolUsages,
            additionalSelectionGroupTypeIndexes = {
                rock.allSmallRocksSelectionGroupTypeIndex
            },
        },
        lapisRockLarge = {
            modelName = "lapisRockLarge",
            rockTypeIndex = rock.types.lapisRock.index,
            scale = 0.6,
            scarcityValue = 20,
            randomMaxScale = 1.5,
            randomShiftDownMin = -1.0,
            randomShiftUpMax = 0.5,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            pathFindingDifficulty = pathFinding.pathNodeDifficulties.climb.index,
            isPathFindingCollider = true,
            blocksRain = true,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(1.8), 0.0)
                }
            },
        },
        lapisRockBlock = {
            modelName = "lapisRockBlock",
            rockTypeIndex = rock.types.lapisRock.index,
            scale = 1.0,
            hasPhysics = true,
            allowsAnyInitialRotation = true,
            resourceTypeIndex = resource.types.stoneBlockHard.index,
            markerPositions = {
                { 
                    worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
                }
            },
            additionalSelectionGroupTypeIndexes = {
                rock.allRockBlocksSelectionGroupTypeIndex
            },
        },
    }

    for key,gameObjectAdditionInfo in pairs(gameObjectsTable) do
        local nameKey = "object_" .. key
        local pluralKey = nameKey .. "_plural"
        gameObjectAdditionInfo.name = locale:get(nameKey) or "NO NAME"
        gameObjectAdditionInfo.plural = locale:get(pluralKey) or "NO NAME"

    end

    gameObject:addGameObjectsFromTable(gameObjectsTable)

    
    for i, rockType in ipairs(rock.validTypes) do
        harvestable:addHarvestable(rockType.largeObjectTypeKey, {
            gameObject.typeIndexMap[rockType.objectTypeKey],
            gameObject.typeIndexMap[rockType.smallObjectTypeKey],
        }, 6, 4)
        harvestable:addHarvestable(rockType.largeObjectTypeKey .. "_chisel", {
            gameObject.typeIndexMap[rockType.stoneBlockTypeKey],
        }, 3, 2)
    end

end

function rock:getLargeRockHarvestableTypeIndex(rockTypeIndex, isChisel)
    if isChisel then
        return harvestable.types[rock.types[rockTypeIndex].largeObjectTypeKey .. "_chisel"].index
    else
        return harvestable.types[rock.types[rockTypeIndex].largeObjectTypeKey].index
    end
end

return rock