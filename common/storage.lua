local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
--local vec2 = mjm.vec2
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local mat3GetRow = mjm.mat3GetRow
--local max = mjm.max
local typeMaps = mjrequire "common/typeMaps"
local resource = mjrequire "common/resource"
local rng = mjrequire "common/randomNumberGenerator"
local locale = mjrequire "common/locale"
local storage = {}

local gameObjectTypeIndexMap = typeMaps.types.gameObject

local toolDistributions = {}

local randomSeed = 4325543

local function setupDistribution(areaSize, storageSize, storageOffset, allowOversized)
    
    local halfSize = areaSize * 0.5

    local maxX = math.floor((areaSize.x + 0.01) / storageSize.x)
    local maxY = math.floor((areaSize.y + 0.01) / storageSize.y)
    local maxZ = math.floor((areaSize.z + 0.01) / storageSize.z)

    
    if allowOversized then
        maxX = math.max(1,maxX)
        maxY = math.max(1,maxY)
        maxZ = math.max(1,maxZ)
    end

    if maxX <= 0 or maxY <= 0 or maxZ <= 0 then
       -- mj:log("storage area is too small")
        return nil
    end

    local orderedPositions = {}
    local positionsByWeights = {}
    local weights = {}

    local minWidth = math.min(storageSize.x, storageSize.z)

    for y=1,maxY do
        for x=1,maxX do
            for z=1,maxZ do
                local pos = storageOffset + vec3(
                    -halfSize.x + (areaSize.x / maxX) * (0.5 + x - 1) + ((y % 2) * minWidth * 0.3),
                    storageSize.y * 0.5 + storageSize.y * (y - 1),
                    -halfSize.z + (areaSize.z / maxZ) * (0.5 + z - 1) + ((y % 2) * minWidth * 0.3)
                )

                local xWeight = math.min(x, maxX - x + 1) * 2
                local yWeight = y * -3
                local zWeight = math.min(z, maxZ - z + 1) * 2

                local combinedWeight = -math.floor(xWeight + yWeight + zWeight) + rng:integerForSeed(randomSeed, 3)
                randomSeed = randomSeed + 1

                if not positionsByWeights[combinedWeight] then
                    positionsByWeights[combinedWeight] = {}
                    table.insert(weights, combinedWeight)
                end

                table.insert(positionsByWeights[combinedWeight], pos)
            end
        end
    end

    table.sort(weights)

    for i,weight in ipairs(weights) do
        local posArray = positionsByWeights[weight]
        --mj:log("weight:" .. weight, " has:", #posArray)
        for j,pos in ipairs(posArray) do
            table.insert(orderedPositions, pos)
        end
    end

    return orderedPositions
end

local toolAreaSize = vec3(1.8,1.0,0.3)

local function setupStaticToolDistribution()

    local areaSize = toolAreaSize
    local storageSize = vec3(0.18,1.0,0.06)
    local storageOffset = vec3(-0.02,0.1,0.0)
    
    --[[if areaDistributionInfo.offset then
        storageOffset = storageOffset + areaDistributionInfo.offset
    end]]

    local orderedPositions = setupDistribution(areaSize, storageSize, storageOffset, true)
    toolDistributions = orderedPositions
    --mj:log("toolDistributions:", toolDistributions)
end

setupStaticToolDistribution()

storage.carryTypes = mj:enum {
	"standard",
	"small",
	"high",
	"highSmall",
	"highMedium",
}

storage.stackTypes = mj:enum {
	"standard",
	"vertical",
}

storage.whitelistTypes = mj:enum {
    "toolRack"
}

storage.areaDistributions = mj:indexed {
    {
        key = "2x2",
        size = vec3(2.0,1.5,2.0),
    },
    {
        key = "1x1",
        size = vec3(1.0,1.0,1.0),
    },
    {
        key = "4x4",
        size = vec3(4.0,1.5,4.0),
    },
    {
        key = "shelf",
        size = vec3(2.0,0.41,0.35),
    },
    {
        key = "toolRack",
        size = toolAreaSize,
        whitelistType = storage.whitelistTypes.toolRack,
        staticDistributions = toolDistributions,
        rotationOverrideFunction = function(uniqueID, seed)
            local randomValue = rng:valueForUniqueID(uniqueID, seed) - 0.5
            local randomValueB = rng:valueForUniqueID(uniqueID, seed + 67) - 0.5
            local rotation = mat3Rotate(mat3Identity, math.pi * 0.5 + randomValue * 0.1, vec3(0.0,0.0,1.0))
            rotation = mat3Rotate(rotation, math.pi * 0.5 + randomValueB * 0.5, vec3(1.0,0.0,0.0))
            --local yRot = randomValue * 0.3 - 0.15
            --local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
            --rotation = mat3Rotate(rotation, yRot, vec3(1.0,0.0,0.0))
            return rotation
        end,
    },
    {
        key = "sled",
        size = vec3(2.0,0.5,0.8),
        offset = vec3(0.0,0.3,0.0),
        allowOversized = true,
    },
    {
        key = "canoe",
        size = vec3(1.0,0.5,0.5),
        offset = vec3(0.5,0.0,0.0),
        allowOversized = true,
    },
}


local function randomXRotation(uniqueID, seed)
    local randomValue = rng:valueForUniqueID(uniqueID, seed)
    return mat3Rotate(mat3Identity, randomValue * 0.05 + 0.1, vec3(0.0,0.0,1.0))
end

storage.types = typeMaps:createMap("storage", {
    {
        key = "hayGrass",
        name = locale:get("storage_hayGrass"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.hay,
        resources = {
            resource.types.grass.index,
            resource.types.hay.index,
            resource.types.hayRotten.index,
        },
		storageBox = {
			size =  vec3(0.7, 0.15, 0.2),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.4 - 0.2, vec3(0.0,1.0,0.0))
				rotation = mat3Rotate(rotation, randomValue * 0.01 + 0.02, vec3(0.0,0.0,1.0))
				return rotation
			end,
		},
        maxCarryCount = 3,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
        
        carryTypesByCounts = {
            storage.carryTypes.highMedium,
            storage.carryTypes.high,
        },
        carryOffset = vec3(0.0,0.04,0.1),
		windBlowAwayHighChance = true,
    },
    {
        key = "branch",
        name = locale:get("storage_branch"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.birchBranch,
        resources = {
            resource.types.branch.index,
            resource.types.burntBranch.index,
            resource.types.branchRotten.index,
        },
        storageBox = {
            size =  vec3(2.0, 0.1, 0.1),
            carryRotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.1 - 0.05
                if randomValue > 0.5 then
                    yRot = 3.141 + (randomValue - 0.5) * 0.1 - 0.05
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.1 - 0.05
                if randomValue > 0.5 then
                    yRot = 3.141 + (randomValue - 0.5) * 0.1 - 0.05
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,0.9,0.0)),
        },
        maxCarryCount = 3,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 1,
		--carryType = storage.carryTypes.high,
        carryTypesByCounts = {
            storage.carryTypes.highSmall,
            storage.carryTypes.highSmall,
            storage.carryTypes.highMedium,
            storage.carryTypes.high,
        },
		carryOffset = vec3(0.0,0.0,0.0),
		--carryRotation = mat3Rotate(mat3Identity, -0.1, vec3(0.0, 0.0, 1.0)),
		windBlowAwayModerateChance = true,
    },
    {
        key = "log",
        name = locale:get("storage_log"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.birchLog,
        resources = {
            resource.types.log.index,
        },
        storageBox = {
            size =  vec3(2.0, 0.22, 0.22),
            carryRotationFunction = randomXRotation,
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = (randomValue * 0.2 - 0.1) * 0.5
                if randomValue > 0.5 then
                    yRot = 3.141 + ((randomValue - 0.5) * 0.2 - 0.1) * 0.5
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,1.0,0.0)),
        },
		carryType = storage.carryTypes.high,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(0.0,0.08,0.1),--vec3(0.12,0.14,0.1),
		--carryRotation = mat3Rotate(mat3Identity, 0.15, vec3(0.0, 0.0, 1.0)),
    },
    {
        key = "rock",
        name = locale:get("storage_rock"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.rock,
        resources = {
            resource.types.rock.index,
            resource.types.rockSoft.index,
        },
        storageBox = {
            size =  vec3(0.3, 0.2, 0.3),
            offset =  vec3(0.0, -0.1, 0.0),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 1.0 - 0.5, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.02,0.1,0.07),
        carryRotation = mat3Rotate(mat3Identity, 1.2, vec3(0.0, 0.0, 1.0)),
    },
    {
        key = "rockSmall",
        name = locale:get("storage_rockSmall"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.rockSmall,
        resources = {
            resource.types.rockSmall.index,
            resource.types.rockSmallSoft.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            offset =  vec3(0.0, -0.0, 0.0),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 1.0 - 0.5, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
    },
    {
        key = "flint",
        name = locale:get("storage_flint"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.flint,
        resources = {
            resource.types.flint.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            offset =  vec3(0.0, -0.0, 0.0),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 1.0 - 0.5, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
    },
    {
        key = "clay",
        name = locale:get("storage_clay"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.clay,
        resources = {
            resource.types.clay.index,
        },
		storageBox = {
			size =  vec3(0.3, 0.3, 0.3),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "copperOre",
        name = locale:get("storage_copperOre"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.copperOre,
        resources = {
            resource.types.copperOre.index,
        },
		storageBox = {
			size =  vec3(0.2, 0.2, 0.2),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 1.0 - 0.5, vec3(1.0,0.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "tinOre",
        name = locale:get("storage_tinOre"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.tinOre,
        resources = {
            resource.types.tinOre.index,
        },
		storageBox = {
			size =  vec3(0.2, 0.2, 0.2),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "manure",
        name = locale:get("storage_manure"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.manure,
        resources = {
            resource.types.manure.index,
            resource.types.manureRotten.index,
        },
		storageBox = {
			size =  vec3(0.2, 0.2, 0.2),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "rottenGoo",
        name = locale:get("storage_rottenGoo"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.rottenGoo,
        resources = {
            resource.types.rottenGoo.index,
        },
		storageBox = {
			size =  vec3(0.2, 0.2, 0.2),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "compost",
        name = locale:get("storage_compost"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.compost,
        resources = {
            resource.types.compost.index,
            resource.types.compostRotten.index,
        },
		storageBox = {
			size =  vec3(0.3, 0.3, 0.3),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "apple",
        name = locale:get("storage_apple"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.apple,
        resources = {
            resource.types.apple.index,
            resource.types.appleRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "elderberry",
        name = locale:get("storage_elderberry"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.elderberry,
        resources = {
            resource.types.elderberry.index,
            resource.types.elderberryRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "orange",
        name = locale:get("storage_orange"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.orange,
        resources = {
            resource.types.orange.index,
            resource.types.orangeRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "peach",
        name = locale:get("storage_peach"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.peach,
        resources = {
            resource.types.peach.index,
            resource.types.peachRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "banana",
        name = locale:get("storage_banana"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.banana,
        resources = {
            resource.types.banana.index,
            resource.types.bananaRotten.index,
        },
        storageBox = {
            size =  vec3(0.3, 0.08, 0.08),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, -math.pi * 0.5 + (randomValue) * 0.25, vec3(0.0,0.0,1.0))
                rotation = mat3Rotate(rotation, (randomValue - 0.5) * 0.5, vec3(1.0,0.0,0.0))
                --rotation = mat3Rotate(rotation, (randomValue - 0.5) * 0.5, vec3(0.0,1.0,0.0))
                --local randomValue = rng:valueForUniqueID(uniqueID, seed)
                --local rotation = mat3Rotate(mat3Identity, randomValue * 0.2, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 0.2, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.03,0.0),
        carryRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0, 0.0, 1.0)),
		windBlowAwayModerateChance = true,
    },
    {
        key = "coconut",
        name = locale:get("storage_coconut"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.coconut,
        resources = {
            resource.types.coconut.index,
            resource.types.coconutRotten.index,
        },
        storageBox = {
			size =  vec3(0.2, 0.2, 0.2),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
        },
		carryOffset = vec3(-0.0,0.12,0.07),
        maxCarryCountForRunning = 0,
    },
    {
        key = "dirt",
        name = locale:get("storage_dirt"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.dirt,
        resources = {
            resource.types.dirt.index,
        },
		storageBox = {
			size =  vec3(0.3, 0.3, 0.3),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "raspberry",
        name = locale:get("storage_raspberry"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.raspberry,
        resources = {
            resource.types.raspberry.index,
            resource.types.raspberryRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "gooseberry",
        name = locale:get("storage_gooseberry"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.gooseberry,
        resources = {
            resource.types.gooseberry.index,
            resource.types.gooseberryRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "pumpkin",
        name = locale:get("storage_pumpkin"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.pumpkin,
        resources = {
            resource.types.pumpkin.index,
            resource.types.pumpkinRotten.index,
            resource.types.pumpkinCooked.index,
        },
		storageBox = {
			size =  vec3(0.3, 0.3, 0.3),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.05,0.13,0.1),
        maxCarryCountForRunning = 0,
        carryRotation = mat3Rotate(mat3Identity, 1.2, vec3(0.0, 0.0, 1.0)),
    },
    {
        key = "pineCone",
        name = locale:get("storage_pineCone"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.pineCone,
        resources = {
            resource.types.pineCone.index,
            resource.types.pineConeRotten.index,
        },
        storageBox = {
            size =  vec3(0.1, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		windBlowAwayModerateChance = true,
		carryOffset = vec3(0.0,0.01,0.0),
    },
    {
        key = "pineConeBig",
        name = locale:get("storage_pineConeBig"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.pineConeBig,
        resources = {
            resource.types.pineConeBig.index,
            resource.types.pineConeBigRotten.index,
        },
		storageBox = {
			size =  vec3(0.25, 0.25, 0.25),
			rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountForRunning = 0,
    },
    {
        key = "beetroot",
        name = locale:get("storage_beetroot"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.beetroot,
        resources = {
            resource.types.beetroot.index,
            resource.types.beetrootRotten.index,
            resource.types.beetrootCooked.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
    },
    {
        key = "gingerRoot",
        name = locale:get("storage_gingerRoot"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.gingerRoot,
        resources = {
            resource.types.gingerRoot.index,
            resource.types.gingerRootRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "turmericRoot",
        name = locale:get("storage_turmericRoot"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.turmericRoot,
        resources = {
            resource.types.turmericRoot.index,
            resource.types.turmericRootRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "garlic",
        name = locale:get("storage_garlic"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.garlic,
        resources = {
            resource.types.garlic.index,
            resource.types.garlicRotten.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "wheat",
        name = locale:get("storage_wheat"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.wheat,
        resources = {
            resource.types.wheat.index,
            resource.types.wheatRotten.index,
        },
		storageBox = {
			size =  vec3(0.7, 0.1, 0.1),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.4 - 0.2, vec3(0.0,1.0,0.0))
				rotation = mat3Rotate(rotation, randomValue * 0.01 + 0.02, vec3(0.0,0.0,1.0))
				return rotation
			end,
		},
        maxCarryCount = 3,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
        carryTypesByCounts = {
            storage.carryTypes.highMedium,
            storage.carryTypes.high,
        },
        carryOffset = vec3(0.0,0.04,0.1),
		windBlowAwayHighChance = true,
    },
    {
        key = "flax",
        name = locale:get("storage_flax"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.flax,
        resources = {
            resource.types.flax.index,
            resource.types.flaxDried.index,
            resource.types.flaxRotten.index,
        },
		storageBox = {
			size =  vec3(0.7, 0.1, 0.1),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.4 - 0.2, vec3(0.0,1.0,0.0))
				rotation = mat3Rotate(rotation, randomValue * 0.01 + 0.02, vec3(0.0,0.0,1.0))
				return rotation
			end,
		},
        maxCarryCount = 3,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
        carryTypesByCounts = {
            storage.carryTypes.highMedium,
            storage.carryTypes.high,
        },
        carryOffset = vec3(0.0,0.04,0.1),
		windBlowAwayHighChance = true,
    },
    {
        key = "seed",
        name = locale:get("storage_seed"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.beetrootSeed,
        resources = {
            resource.types.birchSeed.index,
            resource.types.aspenSeed.index,
            resource.types.willowSeed.index,
            resource.types.beetrootSeed.index,
            resource.types.sunflowerSeed.index,
            resource.types.flaxSeed.index,
            resource.types.bambooSeed.index,
            resource.types.aspenBigSeed.index,
            
            resource.types.birchSeedRotten.index,
            resource.types.aspenSeedRotten.index,
            resource.types.willowSeedRotten.index,
            resource.types.beetrootSeedRotten.index,
            resource.types.sunflowerSeedRotten.index,
            resource.types.flaxSeedRotten.index,
            resource.types.bambooSeedRotten.index,
            resource.types.aspenBigSeedRotten.index,
        },
        storageBox = {
            size =  vec3(0.08, 0.08, 0.08),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayHighChance = true,
    },
    {
        key = "flower",
        name = locale:get("storage_flower"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.poppyFlower,
        resources = {
            resource.types.poppyFlower.index,
            resource.types.marigoldFlower.index,
            resource.types.echinaceaFlower.index,

            resource.types.poppyFlowerRotten.index,
            resource.types.marigoldFlowerRotten.index,
            resource.types.echinaceaFlowerRotten.index,
        },
        storageBox = {
            size =  vec3(0.08, 0.08, 0.08),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
	    carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi, vec3(1.0, 0.0, 0.0)), math.pi * -1.2, vec3(0.0, 1.0, 0.0)),
		windBlowAwayHighChance = true,
    },
    {
        key = "aloeLeaf",
        name = locale:get("storage_aloeLeaf"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.aloeLeaf,
        resources = {
            resource.types.aloeLeaf.index,

            resource.types.aloeLeafRotten.index,
        },
        storageBox = {
            size =  vec3(0.08, 0.08, 0.08),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "sand",
        name = locale:get("storage_sand"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.sand,
        resources = {
            resource.types.sand.index,
        },
		storageBox = {
			size =  vec3(0.3, 0.3, 0.3),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "deadChicken",
        name = locale:get("storage_deadChicken"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.deadChicken,
        resources = {
            resource.types.deadChicken.index,
            resource.types.deadChickenRotten.index,
        },
        storageBox = {
            size =  vec3(0.22, 0.22, 0.22),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountForRunning = 0,
    },
    {
        key = "deadAlpaca",
        name = locale:get("storage_deadAlpaca"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.deadAlpaca,
        resources = {
            resource.types.deadAlpaca.index,
        },
        storageBox = {
            size =  vec3(1.5, 0.4, 0.4),
            --offset =  vec3(0.0, -0.1, -0.5),
            rotationFunction = function(uniqueID, seed)
                --[[local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = math.pi * 0.5
                if rng:boolForUniqueID(uniqueID, seed + 32) then
                    yRot = yRot + math.pi
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(0.0,0.0,1.0))
                return rotation]]

                
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = (randomValue * 0.2 - 0.1) * 0.5
                if randomValue > 0.5 then
                    yRot = 3.141 + ((randomValue - 0.5) * 0.2 - 0.1) * 0.5
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation

                
				--[[local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local xRot = randomValue * 6.282
                local rotation = mat3Rotate(mat3Identity, xRot, vec3(1.0,0.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation]]

            end,
            carryRotationFunction = function(uniqueID, index)
                local rotation = mat3Identity
                rotation = mat3Rotate(rotation, -1.0, vec3(0.0,0.0,1.0))
                --rotation = mat3Rotate(rotation, math.pi * 0.5, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, math.pi * -0.5, vec3(0.0,0.0,1.0))
                return rotation
            end,
        },
        --carryOffset = vec3(0.3,-0.05,0.05),
        
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryType = storage.carryTypes.high,
		carryOffset = vec3(0.2,-0.2,0.1),
    },
    {
        key = "chickenMeat",
        name = locale:get("storage_chickenMeat"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.chickenMeat,
        resources = {
            resource.types.chickenMeat.index,
            resource.types.chickenMeatCooked.index,
        },
        storageBox = {
            size =  vec3(0.15, 0.15, 0.15),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
    },
    {
        key = "alpacaMeat",
        name = locale:get("storage_alpacaMeat"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.alpacaMeatLeg,
        resources = {
            resource.types.alpacaMeat.index,
            resource.types.alpacaMeatCooked.index,
        },
        storageBox = {
			size =  vec3(0.9, 0.15, 0.33),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.4 - 0.2, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, -randomValue * 0.2 - 0.4, vec3(1.0,0.0,0.0))
				return rotation
			end,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 1,
		carryOffset = vec3(-0.0,0.05,0.06),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "mammothMeat",
        name = locale:get("storage_mammothMeat"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.mammothMeatTBone,
        resources = {
            resource.types.mammothMeat.index,
            resource.types.mammothMeatCooked.index,
        },
        storageBox = {
			size =  vec3(0.9, 0.2, 0.33),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.4 - 0.2, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, -randomValue * 0.2 - 0.4, vec3(1.0,0.0,0.0))
				return rotation
			end,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 1,
		carryOffset = vec3(-0.04,0.09,0.1),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "fish",
        name = locale:get("storage_fish"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.fishFilletCooked,
        resources = {
            resource.types.fish.index,
            resource.types.fishCooked.index,
        },
        storageBox = {
			size =  vec3(0.9, 0.15, 0.33),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.4 - 0.2, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, -randomValue * 0.2 + 1.0, vec3(1.0,0.0,0.0))
				return rotation
			end,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 1,
		carryOffset = vec3(-0.0,0.05,0.06),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "swordfishDead",
        name = locale:get("storage_swordfishDead"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.swordfishDead,
        resources = {
            resource.types.swordfishDead.index,
        },
        storageBox = {
            size =  vec3(2.0, 0.6, 0.4),
            --offset =  vec3(0.0, -0.1, -0.5),
            rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.1 - 0.05
                if rng:boolForUniqueID(uniqueID, seed + 32) then
                    yRot = yRot + math.pi
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
            carryRotationFunction = function(uniqueID, index)
                local rotation = mat3Identity
                rotation = mat3Rotate(rotation, math.pi, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, 0.55, vec3(0.0,0.0,1.0))
               -- rotation = mat3Rotate(rotation, math.pi * -0.5, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        --carryOffset = vec3(0.3,-0.05,0.05),
        
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryType = storage.carryTypes.high,
		carryOffset = vec3(1.5,-0.9,0.2),
    },
    {
        key = "spear",
        name = locale:get("storage_spear"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneSpear,
        resources = {
            resource.types.stoneSpear.index,
            resource.types.flintSpear.index,
            resource.types.boneSpear.index,
            resource.types.bronzeSpear.index,
        },
        storageBox = {
            size =  vec3(2.0, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.1 - 0.05
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, 0.05, vec3(0.0,1.0,1.0))
                rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,0.95,0.0)),
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 2,
        carryTypesByCounts = {
            storage.carryTypes.highSmall,
            storage.carryTypes.highSmall,
            storage.carryTypes.highMedium,
        },
		carryOffset = vec3(0.0,0.0,0.04),

        whitelistTypes = {[storage.whitelistTypes.toolRack] = true},
    },
    {
        key = "pickaxe",
        name = locale:get("storage_pickaxe"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stonePickaxe,
        resources = {
            resource.types.stonePickaxe.index,
            resource.types.flintPickaxe.index,
            resource.types.bronzePickaxe.index,
        },
        storageBox = {
            size =  vec3(1.0, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.3 - 0.15
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, yRot, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,0.45,0.0)),
        },
        maxCarryCount = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.0,0.0),
	    carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi, vec3(1.0, 0.0, 0.0)), math.pi * -1.2, vec3(0.0, 1.0, 0.0)),

        whitelistTypes = {[storage.whitelistTypes.toolRack] = true},
    },
    {
        key = "hatchet",
        name = locale:get("storage_hatchet"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneHatchet,
        resources = {
            resource.types.stoneHatchet.index,
            resource.types.flintHatchet.index,
            resource.types.bronzeHatchet.index,
        },
        storageBox = {
            size =  vec3(1.0, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.3 - 0.15
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, yRot, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,0.45,0.0)),
        },
        maxCarryCount = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.0,0.0),
	    carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi, vec3(1.0, 0.0, 0.0)), math.pi * -1.2, vec3(0.0, 1.0, 0.0)),
        
        whitelistTypes = {[storage.whitelistTypes.toolRack] = true},
    },
    {
        key = "hammer",
        name = locale:get("storage_hammer"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneHammer,
        resources = {
            resource.types.stoneHammer.index,
            resource.types.bronzeHammer.index,
        },
        storageBox = {
            size =  vec3(0.8, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.3 - 0.15
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, yRot, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,0.45,0.0)),
        },
        maxCarryCount = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.0,0.0),
	    carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi, vec3(1.0, 0.0, 0.0)), math.pi * -1.2, vec3(0.0, 1.0, 0.0)),

        whitelistTypes = {[storage.whitelistTypes.toolRack] = true},
    },
    {
        key = "woodenPole",
        name = locale:get("storage_woodenPole"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.birchWoodenPole,
        resources = {
            resource.types.woodenPole.index,
        },
        storageBox = {
            size =  vec3(2.0, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = randomValue * 0.4 - 0.2
                if randomValue > 0.5 then
                    yRot = 3.141 + (randomValue - 0.5) * 0.4
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,1.0,0.0)),
        },
        maxCarryCount = 6,
        maxCarryCountLimitedAbility = 3,
        maxCarryCountForRunning = 2,
		carryType = storage.carryTypes.high,
		carryOffset = vec3(0.0,0.04,0.0),
		--carryRotation = mat3Rotate(mat3Identity, -0.1, vec3(0.0, 0.0, 1.0)),
    },
    {
        key = "spearHead",
        name = locale:get("storage_spearHead"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneSpearHead,
        resources = {
            resource.types.stoneSpearHead.index,
            resource.types.flintSpearHead.index,
            resource.types.boneSpearHead.index,
            resource.types.bronzeSpearHead.index,
        },
        storageBox = {
            size =  vec3(0.2, 0.05, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
        carryRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "axeHead",
        name = locale:get("storage_axeHead"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneAxeHead,
        resources = {
            resource.types.stoneAxeHeadSoft.index,
            resource.types.stoneAxeHead.index,
            resource.types.flintAxeHead.index,
            resource.types.bronzeAxeHead.index,
        },
        storageBox = {
            size =  vec3(0.15, 0.1, 0.15),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
        carryRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "pickaxeHead",
        name = locale:get("storage_pickaxeHead"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stonePickaxeHead,
        resources = {
            resource.types.stonePickaxeHead.index,
            resource.types.flintPickaxeHead.index,
            resource.types.bronzePickaxeHead.index,
        },
        storageBox = {
            size =  vec3(0.2, 0.05, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
        --carryRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "knife",
        name = locale:get("storage_knife"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneKnife,
        resources = {
            resource.types.stoneKnife.index,
            resource.types.flintKnife.index,
            resource.types.boneKnife.index,
            resource.types.bronzeKnife.index,
        },
        storageBox = {
            
            size =  vec3(0.2, 0.05, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,-0.005,0.0),
        carryRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "hammerHead",
        name = locale:get("storage_hammerHead"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneHammerHead,
        resources = {
            resource.types.stoneHammerHead.index,
            resource.types.bronzeHammerHead.index,
        },
        storageBox = {
            size =  vec3(0.15, 0.1, 0.15),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
        carryRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "chisel",
        name = locale:get("storage_chisel"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneChisel,
        resources = {
            resource.types.stoneChisel.index,
            resource.types.bronzeChisel.index,
        },
        storageBox = {
            
            size =  vec3(0.2, 0.05, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,-0.005,0.0),
        carryRotation = mat3Rotate(mat3Identity, math.pi, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "splitLog",
        name = locale:get("storage_splitLog"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.birchSplitLog,
        resources = {
            resource.types.splitLog.index,
        },
        storageBox = {
            size =  vec3(2.0, 0.12, 0.35),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = (randomValue - 0.5) * 0.2
                if randomValue > 0.5 then
                    yRot = 3.141 + (randomValue - 0.5) * 0.2
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,0.9,0.0)),
        },
        maxCarryCount = 3,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.high,
		carryOffset = vec3(0.0,0.04,0.1),
        carryStackType = storage.stackTypes.vertical,
		windBlowAwayModerateChance = true,
		--carryRotation = mat3Rotate(mat3Identity, -0.1, vec3(0.0, 0.0, 1.0)),
    },
    {
        key = "woolskin",
        name = locale:get("storage_woolskin"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.alpacaWoolskin,
        resources = {
            resource.types.woolskin.index,
        },
        storageBox = {
            size =  vec3(0.65, 0.25, 0.25),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },

        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 1,
		carryOffset = vec3(-0.05,0.1,0.09),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
		windBlowAwayModerateChance = true,
    },
    {
        key = "urn",
        name = locale:get("storage_urn"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.firedUrn,
        resources = {
            resource.types.unfiredUrnWet.index,
            resource.types.unfiredUrnDry.index,
            resource.types.unfiredUrnHulledWheat.index,
            resource.types.unfiredUrnHulledWheatRotten.index,
            resource.types.unfiredUrnFlour.index,
            resource.types.unfiredUrnFlourRotten.index,
            
            resource.types.firedUrn.index,
            resource.types.firedUrnHulledWheat.index,
            resource.types.firedUrnHulledWheatRotten.index,
            resource.types.firedUrnFlour.index,
            resource.types.firedUrnFlourRotten.index,
            
        },
        storageBox = {
            size =  vec3(0.3, 0.86, 0.3),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
            placeObjectOffset = mj:mToP(vec3(0.0,0.4,0.0)),
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
		carryOffset = vec3(0.35,-0.01,-0.01),
		--carryOffset = vec3(0.18,-0.1,0.1),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi * 0.4, vec3(0.0, 0.0, 1.0)), math.pi * 0.1, vec3(1.0, 0.0, 0.0)),
        maxCarryCountForRunning = 0,
    },
    {
        key = "bowl",
        name = locale:get("storage_bowl"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.firedBowl,
        resources = {
            resource.types.unfiredBowlWet.index,
            resource.types.unfiredBowlDry.index,
            
            resource.types.firedBowl.index,
            
            resource.types.unfiredBowlInjuryMedicine.index,
            resource.types.unfiredBowlBurnMedicine.index,
            resource.types.unfiredBowlFoodPoisoningMedicine.index,
            resource.types.unfiredBowlVirusMedicine.index,
            
            resource.types.firedBowlInjuryMedicine.index,
            resource.types.firedBowlBurnMedicine.index,
            resource.types.firedBowlFoodPoisoningMedicine.index,
            resource.types.firedBowlVirusMedicine.index,
            
            resource.types.unfiredBowlMedicineRotten.index,
            resource.types.firedBowlMedicineRotten.index,
            
        },
        storageBox = {
            size =  vec3(0.24, 0.1, 0.24),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
            placeObjectOffset = mj:mToP(vec3(0.0,0.4,0.0)),
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        --carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi * 0.4, vec3(0.0, 0.0, 1.0)), math.pi * 0.1, vec3(1.0, 0.0, 0.0)),
        carryRotation = mat3Rotate(mat3Identity, 1.2, vec3(0.0, 0.0, 1.0)),
		carryOffset = vec3(0.1,0.1,0.0),
    },
    {
        key = "crucible",
        name = locale:get("storage_crucible"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.crucibleDry,
        resources = {
            resource.types.crucibleWet.index,
            resource.types.crucibleDry.index,
            
        },
        storageBox = {
            size =  vec3(0.24, 0.3, 0.24),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
            placeObjectOffset = mj:mToP(vec3(0.0,0.4,0.0)),
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        --carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi * 0.4, vec3(0.0, 0.0, 1.0)), math.pi * 0.1, vec3(1.0, 0.0, 0.0)),
        carryRotation = mat3Rotate(mat3Identity, 1.2, vec3(0.0, 0.0, 1.0)),
		carryOffset = vec3(0.1,0.1,0.0),
    },
    {
        key = "quernstone",
        name = locale:get("storage_quernstone"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.quernstone,
        resources = {
            resource.types.quernstone.index,
        },
        storageBox = {
            size =  vec3(0.4, 0.2, 0.4),
            offset =  vec3(0.0, 0.0, 0.0),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                return rotation
            end,
        },
        
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.02,0.1,0.07),
        carryRotation = mat3Rotate(mat3Identity, 1.2, vec3(0.0, 0.0, 1.0)),
    },
    {
        key = "breadDough",
        name = locale:get("storage_breadDough"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.breadDough,
        resources = {
            resource.types.breadDough.index,
            resource.types.breadDoughRotten.index,
        },
		storageBox = {
			size =  vec3(0.3, 0.3, 0.3),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
				return rotation
			end,
		},
		carryOffset = vec3(-0.02,0.1,0.07),
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
    },
    {
        key = "flatbread",
        name = locale:get("storage_flatbread"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.flatbread,
        resources = {
            resource.types.flatbread.index,
            resource.types.flatbreadRotten.index,
        },
        storageBox = {
            size =  vec3(0.25, 0.1, 0.25),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 0.6, vec3(1.0,0.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(0.0,1.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
        carryStackType = storage.stackTypes.vertical,
		carryOffset = vec3(0.08,0.08,0.02),
		windBlowAwayModerateChance = true,
    },
    {
        key = "brick",
        name = locale:get("storage_brick"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.firedBrick_sand,
        resources = {
            resource.types.mudBrickWet.index,
            resource.types.mudBrickDry.index,
            resource.types.firedBrick.index,
        },
        storageBox = {
            size =  vec3(0.5, 0.2, 0.2),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.02,0.15,0.04),
        carryRotation = mat3Rotate(mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)), 0.3, vec3(1.0,0.0,0.0)),
    },
    {
        key = "tile",
        name = locale:get("storage_tile"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.firedTile,
        resources = {
            resource.types.mudTileWet.index,
            resource.types.mudTileDry.index,
            resource.types.firedTile.index,
        },
        storageBox = {
            size =  vec3(0.4, 0.1, 0.4),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(0.04,0.1,0.04),
        carryRotation = mat3Rotate(mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)), 0.3, vec3(1.0,0.0,0.0)),
    },
    {
        key = "flaxTwine",
        name = locale:get("storage_flaxTwine"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.flaxTwine,
        resources = {
            resource.types.flaxTwine.index,
        },
        storageBox = {
            size =  vec3(0.12, 0.12, 0.12),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
                rotation = mat3Rotate(rotation, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,0.01,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "bone",
        name = locale:get("storage_bone"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.bone,
        resources = {
            resource.types.bone.index,
        },
        storageBox = {
            size =  vec3(0.3, 0.1, 0.1),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(1.0,0.0,0.0))
                return rotation
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(0.0,-0.005,0.0),
		windBlowAwayModerateChance = true,
    },
    {
        key = "boneFlute",
        name = locale:get("storage_boneFlute"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.boneFlute,
        resources = {
            resource.types.boneFlute.index,
        },
        storageBox = {
            size =  vec3(0.2, 0.02, 0.08),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local rotation = mat3Rotate(mat3Identity, (randomValue - 0.5) * 0.2, vec3(0.0,1.0,0.0))
                
                randomValue = rng:valueForUniqueID(uniqueID, seed)
                rotation = mat3Rotate(rotation, (randomValue * 0.2), vec3(0.0,0.0,1.0))
                return rotation
            end,
            carryRotationFunction = function(uniqueID, index)
                return mat3Rotate(mat3Identity, math.pi, vec3(0.0,1.0,0.0))
            end,
        },
        maxCarryCount = 4,
        maxCarryCountLimitedAbility = 2,
        maxCarryCountForRunning = 1,
		carryType = storage.carryTypes.small,
		carryOffset = vec3(-0.04,0.00,0.00),
		windBlowAwayModerateChance = true,
    },
    {
        key = "logDrum",
        name = locale:get("storage_logDrum"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.logDrum,
        resources = {
            resource.types.logDrum.index,
        },
        storageBox = {
            size =  vec3(0.9, 0.22, 0.22),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = (randomValue * 0.2 - 0.1) * 0.5
                if randomValue > 0.5 then
                    yRot = 3.141 + ((randomValue - 0.5) * 0.2 - 0.1) * 0.5
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectOffset = mj:mToP(vec3(0.0,0.1,0.0)),
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.02,0.15,0.04),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "balafon",
        name = locale:get("storage_balafon"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.balafon,
        resources = {
            resource.types.balafon.index,
        },
        storageBox = {
            size =  vec3(0.6, 0.15, 0.3),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
                local yRot = (randomValue * 0.2 - 0.1) * 0.5
                if randomValue > 0.5 then
                    yRot = 3.141 + ((randomValue - 0.5) * 0.2 - 0.1) * 0.5
                end
                local rotation = mat3Rotate(mat3Identity, yRot, vec3(0.0,1.0,0.0))
                --rotation = mat3Rotate(rotation, randomValue * 6.242, vec3(1.0,0.0,0.0))
                return rotation
            end,
            placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
            placeObjectOffset = mj:mToP(vec3(0.0,1.0,0.0)),
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.0,0.05,0.06),
        carryRotation = mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)),
    },
    {
        key = "ingot",
        name = locale:get("storage_ingot"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.bronzeIngot,
        resources = {
            resource.types.bronzeIngot.index,
        },
        storageBox = {
            size =  vec3(0.5, 0.15, 0.2),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.02,0.15,0.04),
        carryRotation = mat3Rotate(mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)), 0.3, vec3(1.0,0.0,0.0)),
    },
    {
        key = "stoneBlock",
        name = locale:get("storage_stoneBlock"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneBlock,
        resources = {
            resource.types.stoneBlockSoft.index,
            resource.types.stoneBlockHard.index,
        },
        storageBox = {
            size =  vec3(0.5, 0.2, 0.2),
            rotationFunction = function(uniqueID, seed)
                local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 0.2 - 0.1, vec3(0.0,1.0,0.0))
                return rotation
            end,
            dontRotateToFitBelowSurface = true,
        },
        maxCarryCount = 1,
        maxCarryCountLimitedAbility = 1,
        maxCarryCountForRunning = 0,
		carryOffset = vec3(-0.02,0.15,0.04),
        carryRotation = mat3Rotate(mat3Rotate(mat3Rotate(mat3Identity, 1.0, vec3(0.0, 0.0, 1.0)), -0.5, vec3(0.0, 1.0, 0.0)), 0.3, vec3(1.0,0.0,0.0)),
    },
})

---------------------------------- NOTE: when adding new types above: The order in the "resources" array here for each storage type is used to derive the order when displayed in the UI. 
---------------------------------- So simpler/earlier forms should be at the top of the resource list.

storage.typesByResource = {}

--local storageAreaSize = vec2(2.0,2.0)
--local storageAreaHalfSize = storageAreaSize * 0.5

randomSeed = 4325543
local function setupDistributionForStorageTypeAndAreaInfo(storageType, areaDistributionInfo)
    if areaDistributionInfo.staticDistributions then
        storageType.distributions[areaDistributionInfo.index] = areaDistributionInfo.staticDistributions
    else
        local storageSize = vec3(0.2,0.2,0.2)
        local storageOffset = vec3(0.0,0.0,0.0)
        local storageBox = storageType.storageBox
        if storageBox then
            if storageBox.size then
                storageSize = storageBox.size
            end     
            if storageBox.offset then
                storageOffset = storageBox.offset
            end
        end

        if areaDistributionInfo.offset then
            storageOffset = storageOffset + areaDistributionInfo.offset
        end

        local distribution = setupDistribution(areaDistributionInfo.size, storageSize, storageOffset, areaDistributionInfo.allowOversized)
        storageType.distributions[areaDistributionInfo.index] = distribution
    end
end

local function setupDistributions(storageType)

    storageType.distributions = {}

    for i,areaDistributionInfo in ipairs(storage.areaDistributions) do
        if (not areaDistributionInfo.whitelistType) or (storageType.whitelistTypes and storageType.whitelistTypes[areaDistributionInfo.whitelistType]) then
            setupDistributionForStorageTypeAndAreaInfo(storageType, areaDistributionInfo)
        end
    end
end

function storage:resourceTypesCanBeStoredToegether(typeA, typeB)
    if typeA == typeB then
        return true
    elseif storage.typesByResource[typeA] == storage.typesByResource[typeB] then
        return true
    end
    return false
end

function storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex)
    return storage.typesByResource[resourceTypeIndex]
end

function storage:maxCarryCountForResourceType(resourceTypeIndex)
    --[[if limitedAbility then
        local maxCarryCount = storage.types[storage.typesByResource[resourceTypeIndex] ].maxCarryCountLimitedAbility
        if maxCarryCount then
            return maxCarryCount
        end
    end]]
    local maxCarryCount = storage.types[storage.typesByResource[resourceTypeIndex]].maxCarryCount
    if maxCarryCount then
        return maxCarryCount
    end
    return 1
end

function storage:canRunWithCarriedResource(resourceTypeIndex, count)
    if resourceTypeIndex then
        local storageType = storage.types[storage.typesByResource[resourceTypeIndex]]
        if storageType.maxCarryCountForRunning then
            return count <= storageType.maxCarryCountForRunning
        end
    end
    return true
end

function storage:carryPlacementInfoForResourceTypeAtIndex(uniqueID, resourceTypeIndex, carryIndex, totalCarryCount)
    local storageType = storage.types[storage.typesByResource[resourceTypeIndex]]
    local baseOffset = storageType.carryOffset or vec3(0.0,0.0,0.0)

    local rotation = nil
    local rotationFunc = storageType.storageBox.carryRotationFunction
    if rotationFunc then
        rotation = rotationFunc(uniqueID, carryIndex)
    else
        rotation = storageType.carryRotation
    end

    local carryType = storageType.carryType
    if storageType.carryTypesByCounts then
        carryType = storageType.carryTypesByCounts[totalCarryCount]
        --mj:log("uniqueID:", uniqueID, " totalCarryCount:", totalCarryCount, " carryType:", carryType)
        if not carryType then
            carryType = storageType.carryTypesByCounts[#storageType.carryTypesByCounts]
        end
    end

    local carryOffset = nil
    if carryIndex > 1 then
        if carryType == storage.carryTypes.standard or (not carryType) then
            if storageType.carryStackType == storage.stackTypes.vertical then
                local upVec = nil
                if storageType.carryRotation then
                    upVec = mat3GetRow(storageType.carryRotation, 1)
                else
                    upVec = vec3(0.0,1.0,0.0)
                end
                carryOffset = upVec * storageType.storageBox.size.y * 0.8 * (carryIndex - 1)
            else
                carryOffset = vec3(((carryIndex - 1) % 2) * 0.1,0.05 * (carryIndex - 1), 0.0)
            end
        elseif carryType == storage.carryTypes.small then
            local offsetZ = 0.0
            local offseyY = 0.0
            if carryIndex > 3 then
                offsetZ = offsetZ + 0.2
                offseyY = 1.0
            end
            local alongArmOffset = (((carryIndex - 1) % 3) + offsetZ)
            carryOffset = vec3(0.0, (offseyY + alongArmOffset * 0.2) * 0.8 * storageType.storageBox.size.y, alongArmOffset * 0.8 * storageType.storageBox.size.z)
        else
            if storageType.carryStackType == storage.stackTypes.vertical then
                carryOffset = vec3(0.0, storageType.storageBox.size.y * 0.8 * (carryIndex - 1), 0.0)
            else
                carryOffset = vec3(rng:valueForUniqueID(uniqueID, 2356 + carryIndex) * 0.1,storageType.storageBox.size.y * 0.5 * (carryIndex - 1), (((carryIndex - 1) % 2) - 0.5) * 0.7 * storageType.storageBox.size.z)
            end
        end
    end

    local combinedOffset = baseOffset
    if carryOffset then
        combinedOffset = combinedOffset + carryOffset
    end

    return {
        offset = combinedOffset,
        --rotation = storageType.carryRotation,
        rotation = rotation,
    }
end

function storage:carryTypeForResourceType(resourceTypeIndex, totalCarryCount)
    local storageType = storage.types[storage.typesByResource[resourceTypeIndex]]
    if not storageType then
        mj:error("no storage type for resource:", resourceTypeIndex, " - ", resource.types[resourceTypeIndex].name)
        return storage.carryTypes.standard
    end
    
    local carryType = storageType.carryType
    if storageType.carryTypesByCounts then
        carryType = storageType.carryTypesByCounts[totalCarryCount]
        if not carryType then
            carryType = storageType.carryTypesByCounts[#storageType.carryTypesByCounts]
        end
    end

    return carryType or storage.carryTypes.standard
end


function storage:getStorageBoxForResourceType(resourceTypeIndex)
    --mj:log("storage:getStorageBoxForResourceType:", resourceTypeIndex)
    return storage.types[storage.typesByResource[resourceTypeIndex]].storageBox
end

function storage:maxItemsForStorageType(storageTypeIndex, storageAreaDistributionTypeIndex)
    local distributions = storage.types[storageTypeIndex].distributions[storageAreaDistributionTypeIndex]
    --mj:log("maxItems storage.types[storageTypeIndex]:", storage.types[storageTypeIndex], "\ndistributions:", distributions)
    if distributions then
        return #distributions
    end
    return 0

end

function storage:maxItemsForResourceType(resourceTypeIndex, storageAreaDistributionTypeIndex)
    --mj:log("storage:maxItemsForResourceType:", resourceTypeIndex)
    local distributions = storage.types[storage.typesByResource[resourceTypeIndex]].distributions[storageAreaDistributionTypeIndex]
    if distributions then
        return #distributions
    end
    return 0
end

function storage:getPosition(resourceTypeIndex, storageAreaDistributionTypeIndex, objectIndex)
    local storageType = storage.types[storage.typesByResource[resourceTypeIndex]]
    --local maxItems = storage:maxItemsForResourceType(resourceTypeIndex, storageAreaDistributionTypeIndex)
    local distributions = storageType.distributions[storageAreaDistributionTypeIndex]

    if not distributions then
        mj:error("Attempting to get position for stored item with no distribution for storageAreaDistributionTypeIndex:",storageAreaDistributionTypeIndex, " storageType:", storageType)
        return vec3(0.0,0.0,0.0)
    end

    if objectIndex > #distributions then
        mj:error("Attempting to get position for stored item beyond max items allowed.")
        return vec3(0.0,0.0,0.0)
    end

    return distributions[objectIndex]
end

function storage:mjInit()

    storage.validTypes = typeMaps:createValidTypesArray("storage", storage.types)
    storage.alphabeticallyOrderedTypes = {}
    storage.alphabeticallyOrderedObjectTypesByStorageType = {}

    for i,storageType in ipairs(storage.validTypes) do
        for j,resourceTypeIndex in ipairs(storageType.resources) do
            storage.typesByResource[resourceTypeIndex] = storageType.index
        end

        if storageType.windBlowAwayHighChance then
            storageType.windDestructableChanceIndex = 1
        elseif storageType.windBlowAwayModerateChance then
            storageType.windDestructableChanceIndex = 2
        elseif storageType.windBlowAwayLowChance then
            storageType.windDestructableChanceIndex = 3
        end

        setupDistributions(storageType)
        
        table.insert(storage.alphabeticallyOrderedTypes, storageType)
    end

    
    local function sortByName(a,b)
        return a.name < b.name
    end

    table.sort(storage.alphabeticallyOrderedTypes, sortByName)

end

return storage