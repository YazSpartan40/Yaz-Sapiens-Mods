local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local normalize = mjm.normalize
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate

local model = mjrequire "common/model"
local rng = mjrequire "common/randomNumberGenerator"

--local order = mjrequire "common/order"
local resource = mjrequire "common/resource"
local buildable = mjrequire "common/buildable"
local constructable = mjrequire "common/constructable"
local typeMaps = mjrequire "common/typeMaps"
local seat = mjrequire "common/seat"
--local skill = mjrequire "common/skill"
local selectionGroup = mjrequire "common/selectionGroup"
--local plan = mjrequire "common/plan"
--local tool = mjrequire "common/tool"
local worldHelper = mjrequire "common/worldHelper"
local gameConstants = mjrequire "common/gameConstants"
local pathFinding = mjrequire "common/pathFinding"
local snapGroup = mjrequire "common/snapGroups/snapGroup"

local locale = mjrequire "common/locale"

local terrainTypesModule = mjrequire "common/terrainTypes"
local terrainVariationTypes = terrainTypesModule.variations
local terrainBaseTypes = terrainTypesModule.baseTypes

local addedSeedResourceTypeIndexes = {}

local flora = {
	types = {},
	seedResourceTypeIndexes = {},
	floraObjectTypesByGatherableResourceTypes = {}, --implemented 0.5, but not needed after all, untested
	logTypeBaseKeys = {
		"birch",
		"aspen",
		"pine",
		"willow",
		"coconut",
		"apple",
		"orange",
		"peach",
		"elderberry",
	},
	branchTypeBaseKeys = {
		"birch",
		"aspen",
		"pine",
		"willow",
		"bamboo",
		"apple",
		"orange",
		"peach",
		"elderberry",
	},
	growthPhases = mj:enum {
		"dirt",
		"sprout",
		"sapling",
		"mature"
	},
}


flora.soilQualities = mj:enum {
    "poor",
    "normal",
    "rich",
	"veryPoor",
	"invalid",
	"unknown"
}

flora.mediumTypes = {
	[terrainBaseTypes.dirt.index] = {
		soilQuality = flora.soilQualities.normal,
	},
	[terrainBaseTypes.richDirt.index] = {
		soilQuality = flora.soilQualities.rich,
	},
	[terrainBaseTypes.poorDirt.index] = {
		soilQuality = flora.soilQualities.poor,
	},
	[terrainBaseTypes.clay.index] = {
		soilQuality = flora.soilQualities.veryPoor,
	},
	[terrainBaseTypes.beachSand.index] = {
		soilQuality = flora.soilQualities.veryPoor,
	},
	[terrainBaseTypes.riverSand.index] = {
		soilQuality = flora.soilQualities.veryPoor,
	}, 
	[terrainBaseTypes.desertSand.index] = {
		soilQuality = flora.soilQualities.veryPoor,
	},
	[terrainBaseTypes.desertRedSand.index] = {
		soilQuality = flora.soilQualities.veryPoor,
	}
}

local typeIndexMap = typeMaps.types.flora

local seasons = gameConstants.seasons

local gameObject = nil

local resourceGroups = nil


local treeMarkerPositions = {
	{ 
		worldOffset = vec3(0.0, mj:mToP(1.5), mj:mToP(0.8))
	}
}

local bushMarkerPositions = {
	{ 
		worldOffset = vec3(0.0, mj:mToP(0.8), mj:mToP(1.2))
	}
}

local tallPlantMarkerPositions = {
	{ 
		worldOffset = vec3(0.0, mj:mToP(0.8), mj:mToP(0.2))
	}
}

local tinyPlantMarkerPositions = {
	{ 
		worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
	}
}

local treeFollowCamOffset = vec2(8.0,4.0)

function flora:createInventory(resourceGroup, addSeasonalItems, addFruitItems)
	local inventory = {
		countsByObjectType = {},
		objects = {}
	}
	if resourceGroup.baseInventory then
		for gameObjectTypeIndex, count in pairs(resourceGroup.baseInventory) do
			inventory.countsByObjectType[gameObjectTypeIndex] = count
			for i=1,count do
				table.insert(inventory.objects, {
					objectTypeIndex = gameObjectTypeIndex,
				})
			end
		end
	end

	
	local function addItems(resourceGroupItems)
		for gameObjectTypeIndex, count in pairs(resourceGroupItems) do
			local currentCount = inventory.countsByObjectType[gameObjectTypeIndex] or 0
			if currentCount < count then
				for i = currentCount + 1,count do
					table.insert(inventory.objects, {
						objectTypeIndex = gameObjectTypeIndex,
					})
				end
				inventory.countsByObjectType[gameObjectTypeIndex] = count
			end
		end
	end

	if addSeasonalItems and resourceGroup.seasonalReplenish then
		addItems(resourceGroup.seasonalReplenish)
	end
	
	if addFruitItems and resourceGroup.fruitReplenish then
		addItems(resourceGroup.fruitReplenish)
	end

	return inventory
end

local function getClientModelFunction(treeKey, standardModelName, hasSeasonalModels, hasSnowVarient, isSapling)
	local namesBySeason = {
		standardModelName,
		standardModelName,
		standardModelName,
		standardModelName
	}
	if hasSeasonalModels then
		namesBySeason[1] = standardModelName .. "Spring"
		namesBySeason[3] = standardModelName .. "Autumn"
		namesBySeason[4] = standardModelName .. "Winter"
	end
	local snowVarient = nil
	if hasSnowVarient then
		snowVarient = standardModelName .. "Snow"
	end
	
	if isSapling then
		return function(floraObject, level, modelFunctionContext, terrainVariations)
			local growthPhase = flora:getGrowthPhase(floraObject, modelFunctionContext.worldTime,  modelFunctionContext.yearLength)
			if growthPhase < flora.growthPhases.sprout then
				local moundModelIndex = model:modelIndexForModelNameAndDetailLevel(treeKey.. "Mound", level)
				if moundModelIndex then
					return moundModelIndex
				end
				return model:modelIndexForModelNameAndDetailLevel("plantHole", level)
			end
			if snowVarient then-- and seasonIndex == 4 then
				if terrainVariations and terrainVariations[terrainVariationTypes.snow.index] then
					local modelIndex = model:modelIndexForModelNameAndDetailLevel(snowVarient, level)
					if modelIndex then
						return modelIndex
					end
				end
			end
			local seasonIndex = worldHelper:seasonIndexForSeasonFraction(floraObject.pos.y, modelFunctionContext.seasonFraction - 0.1 * rng:valueForUniqueID(floraObject.uniqueID, 32987), floraObject.uniqueID)
			--seasonIndex = 2
			local modelIndex = model:modelIndexForModelNameAndDetailLevel(namesBySeason[seasonIndex], level)
			if not modelIndex then
				mj:warn("no seasonal variant found:", namesBySeason[seasonIndex])
				modelIndex = model:modelIndexForModelNameAndDetailLevel(standardModelName, level)
			end
			return modelIndex
		end
	else
		return function(floraObject, level, modelFunctionContext, terrainVariations)
			if snowVarient then -- and seasonIndex == 4 then
				if terrainVariations and terrainVariations[terrainVariationTypes.snow.index] then
					local modelIndex = model:modelIndexForModelNameAndDetailLevel(snowVarient, level)
					if modelIndex then
						return modelIndex
					end
				end
			end
			local seasonIndex = worldHelper:seasonIndexForSeasonFraction(floraObject.pos.y, modelFunctionContext.seasonFraction - 0.1 * rng:valueForUniqueID(floraObject.uniqueID, 32987), floraObject.uniqueID)
			--seasonIndex = 2
			return model:modelIndexForModelNameAndDetailLevel(namesBySeason[seasonIndex], level)
		end
	end
end


local function addPlantableObjects(baseObject, saplingBaseKey, floraInfo)--seedResourceTypeIndex, saplingClientModelFunction, saplingNameOrNil, saplingPluralOrNil, saplingModelNameOrNil)
	local plantTypeKey = "plant_" .. baseObject.key
	local saplingTypeKey = "sapling_" ..baseObject.key

	floraInfo.plantGameObjectTypeKey = plantTypeKey
	floraInfo.saplingGameObjectTypeKey = saplingTypeKey

	if not floraInfo.summary then
		mj:error("no summary for flora info:", floraInfo)
	end

	--[[floraInfo.seedResourceTypeIndex, 
	floraInfo.saplingClientModelFunction, 
	floraInfo.saplingName, 
	floraInfo.saplingPlural]]

	local saplingModelName = floraInfo.saplingModelName or saplingBaseKey 

	--mj:log("addPlantableObjects:", baseObject, " seedResourceTypeIndex:", floraInfo.seedResourceTypeIndex, " saplingModelName:", saplingModelName, " floraInfo.saplingModelName:", floraInfo.saplingModelName, " saplingBaseKey:", saplingBaseKey)

	local treeOrPlantSelectionGroupTypeIndex = selectionGroup.types.allPlants.index
	if floraInfo.requiresAxeToChop then
		treeOrPlantSelectionGroupTypeIndex = selectionGroup.types.allTrees.index
	end
	
	gameObject:addGameObjectsFromTable({
		[plantTypeKey] = {
			name = baseObject.name,
			plural = baseObject.plural,
			modelName = saplingModelName,--baseObject.modelName,
			scale = baseObject.scale,
			hasPhysics = false,
			ignoreBuildRay = true,
			isInProgressBuildObject = true,
			disallowAnyCollisionsOnPlacement = true,
			--isPlantableInProgressBuildObject = true,
			isNonPlaceCollider = true,
			markerPositions = baseObject.markerPositions,
			additionalSelectionGroupTypeIndexes = {treeOrPlantSelectionGroupTypeIndex},
		},
		[saplingTypeKey] = {
			name = floraInfo.saplingName or baseObject.name,
			plural = floraInfo.saplingPlural or baseObject.plural,
			modelName = saplingModelName,
			scale = baseObject.scale,
			hasPhysics = true,
			ignoreBuildRay = true,
			floraTypeIndex = baseObject.floraTypeIndex,
			clientModelFunction = floraInfo.saplingClientModelFunction,
			disallowAnyCollisionsOnPlacement = true,
			isSapling = true,
			markerPositions = {
				{ 
					worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
				}
			},
			additionalSelectionGroupTypeIndexes = {treeOrPlantSelectionGroupTypeIndex},
		},
	})

	local inProgressModelName = saplingModelName
	if floraInfo.useCraftSimple then
		inProgressModelName = "craftSimple"
	end

	floraInfo.constructableTypeIndex = buildable:addInfoForPlantableObject(baseObject, floraInfo.summary or baseObject.name, floraInfo.seedResourceTypeIndex, flora.mediumTypes, inProgressModelName)
end

local function treeInitialTransientStateFunction(
	uniqueID, 
	objectTypeIndex,
	scale,
	pos)

	local state = {
	}

	local floraType = flora.types[gameObject.types[objectTypeIndex].key]

	local addSeasonalItems = true
	local addFruitItems = true

	if floraType.fruitFrequencyInYears and floraType.fruitFrequencyInYears > 1 then
		addFruitItems = (rng:integerForUniqueID(uniqueID, 82221, floraType.fruitFrequencyInYears) == 1)
	end

	state.inventory = flora:createInventory(floraType.resourceGroup, addSeasonalItems, addFruitItems)

	return state
end

local function addFlora(key, floraInfo)
	


	local index = typeIndexMap[key]
	if not index then
		mj:log("ERROR: attempt to add flora type that isn't in typeIndexMap:", key)
	else
		if flora.types[key] then
			mj:log("WARNING: overwriting flora type:", key)
		end

		floraInfo.key = key
		floraInfo.index = index
		flora.types[key] = floraInfo
		flora.types[index] = floraInfo

		if not floraInfo.fruitSeason then
			floraInfo.fruitSeason = seasons.summer --so branches grow back. This will probably need to be more complex
		end

		local gameObjectInfo = {
			name = floraInfo.name,
			plural = floraInfo.plural,
			modelName = floraInfo.modelName,
			clientModelFunction = floraInfo.clientModelFunction,
			disallowAnyCollisionsOnPlacement = true,
			scale = 1.0,
			floraTypeIndex = index,
			objectViewCameraOffsetFunction = function(object)
				return vec3(0.0,0.0,1.0)
			end,
			--[[objectViewOffsetFunction = function(object)
				return vec3(0.0,0.0,0.0)
			end,]]

			markerPositions = floraInfo.markerPositions,
			isPathFindingCollider = floraInfo.isPathFindingCollider,
			allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.foliage.index,
			playBirdSounds = floraInfo.playBirdSounds,
		}

		if floraInfo.fruitFrequencyInYears then
			gameObjectInfo.notifyServerOnTransientInspection = true
		end

		if floraInfo.interactable or floraInfo.requiresAxeToChop then
			if floraInfo.addToPhysics or floraInfo.requiresAxeToChop then
				gameObjectInfo.hasPhysics = true
				gameObjectInfo.ignoreBuildRay = true
			end
			gameObjectInfo.initialTransientStateFunction = treeInitialTransientStateFunction
			
			local resourceGroup = floraInfo.resourceGroup
			gameObjectInfo.gatherableTypes = resourceGroup.gatherableTypes
			gameObjectInfo.gatherKeepMinQuantity = resourceGroup.gatherKeepMinQuantity
			if not floraInfo.requiresAxeToChop then --might not be good enough, but will do for now
				gameObjectInfo.useBushGatherAnimation = true
			end
			gameObjectInfo.revertToSeedlingGatherResourceCounts = resourceGroup.revertToSeedlingGatherResourceCounts

		end

		if floraInfo.followCamOffset then
			gameObjectInfo.followCamOffsetFunction = function(object)
				return floraInfo.followCamOffset
			end
		end
		
		if floraInfo.speciesSelectionGroupTypeIndex then
			gameObjectInfo.baseSelectionGroupTypeIndex = floraInfo.speciesSelectionGroupTypeIndex
		end

		local treeOrPlantSelectionGroupTypeIndex = selectionGroup.types.allPlants.index
		if floraInfo.requiresAxeToChop then
			treeOrPlantSelectionGroupTypeIndex = selectionGroup.types.allTrees.index
		end

		gameObjectInfo.additionalSelectionGroupTypeIndexes = {
			treeOrPlantSelectionGroupTypeIndex
		}

		local gameObjectTypeIndex = gameObject:addGameObject(key, gameObjectInfo)
		floraInfo.gameObjectTypeIndex = gameObjectTypeIndex

		if floraInfo.resourceGroup then
			local function addGatherableTypes(gatherableObjectTypeIndex)
				local typesByResource = flora.floraObjectTypesByGatherableResourceTypes[gameObject.types[gatherableObjectTypeIndex].resourceTypeIndex]
				local found = false
				if not typesByResource then
					typesByResource = {}
					flora.floraObjectTypesByGatherableResourceTypes[gameObject.types[gatherableObjectTypeIndex].resourceTypeIndex] = typesByResource
				else
					for i,existingObjectTypeIndex in ipairs(typesByResource) do
						if existingObjectTypeIndex == gameObjectTypeIndex then
							found = true
							break
						end
					end
				end
				if not found then
					table.insert(typesByResource, gameObjectTypeIndex)
				end
			end

			if floraInfo.resourceGroup.gatherableTypes then
				for i,gatherableObjectTypeIndex in ipairs(floraInfo.resourceGroup.gatherableTypes) do
					addGatherableTypes(gatherableObjectTypeIndex)
				end
			end
			if floraInfo.resourceGroup.revertToSeedlingGatherResourceCounts then
				for gatherableObjectTypeIndex,v in pairs(floraInfo.resourceGroup.revertToSeedlingGatherResourceCounts) do
					addGatherableTypes(gatherableObjectTypeIndex)
				end
			end
		end

		if floraInfo.seedResourceTypeIndex then
			local gameObjectType = gameObject.types[gameObjectTypeIndex]
			local saplingBaseKey = floraInfo.saplingBaseKey or gameObjectType.key .. "Sapling"
			addPlantableObjects(gameObjectType, saplingBaseKey, floraInfo)
			if not addedSeedResourceTypeIndexes[floraInfo.seedResourceTypeIndex] then
				addedSeedResourceTypeIndexes[floraInfo.seedResourceTypeIndex] = true
				table.insert(flora.seedResourceTypeIndexes, floraInfo.seedResourceTypeIndex)
			end
		end
	end
end

local function addBranchObjects(baseKey)
	local branchLocaleKey = "branch_" .. baseKey
	local branchLocaleKeyPlural = branchLocaleKey .. "_plural"
	
	local branchKey = baseKey .. "Branch"
	local branchInfo = {
        name = locale:get(branchLocaleKey),
        plural = locale:get(branchLocaleKeyPlural),
		modelName = (baseKey .. "Branch"),
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.branch.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), mj:mToP(0.2))
			}
		},
		placedFemaleSnapPoints = snapGroup.femalePoints.horizontalColumnFemaleSnapPoints,
	}
	
	branchInfo.additionalSelectionGroupTypeIndexes = {
		selectionGroup.types.allBranches.index
	}

	gameObject:addGameObject(branchKey, branchInfo)
end

local function addLogObjects(baseKey)
	local logLocaleKey = "log_" .. baseKey
	local logLocaleKeyPlural = logLocaleKey .. "_plural"
	
	local logKey = baseKey .. "Log"
	local logInfo = {
		name = locale:get(logLocaleKey),
		plural = locale:get(logLocaleKeyPlural),
		modelName = baseKey .. "Log",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.log.index,
		seatTypeIndex = seat.types.log.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 1.0, normalize(vec3(0.0, 0.0, 1.0))) 
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.0,1.3)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), mj:mToP(0.2))
			}
		},
		
		placedFemaleSnapPoints = snapGroup.femalePoints.horizontalColumnFemaleSnapPoints,
	}
	
	logInfo.additionalSelectionGroupTypeIndexes = {
		selectionGroup.types.allLogs.index
	}

	gameObject:addGameObject(logKey, logInfo)
end


local function addFruit(key, modelNameOrNil)

	local fruitLocaleKey = "fruit_" .. key
	local fruitLocaleKeyPlural = fruitLocaleKey .. "_plural"
	local rottenFruitLocaleKey = fruitLocaleKey .. "_rotten"
	local rottenFruitLocaleKeyPlural = rottenFruitLocaleKey .. "_plural"

	local modelName = modelNameOrNil or key
	local modelNameRotten = modelName .. "Rotten"
	
	local info = {
		name = locale:get(fruitLocaleKey),
		plural = locale:get(fruitLocaleKeyPlural),
		modelName = modelName,
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types[key].index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	}

	gameObject:addGameObject(key,info)
	
	local rottenKey = key .. "Rotten"
	local rottenInfo = {
		name = locale:get(rottenFruitLocaleKey),
		plural = locale:get(rottenFruitLocaleKeyPlural),
		modelName = modelNameRotten,
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types[rottenKey].index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	}

	gameObject:addGameObject(rottenKey,rottenInfo)
end


local function addFruits()
	addFruit("raspberry", nil)
	addFruit("gooseberry", nil)
	addFruit("pumpkin", nil)
	
	addFruit("beetroot", nil)
	addFruit("beetrootSeed", "genericSeeds")

	addFruit("sunflowerSeed", "sunflowerSeeds")

	addFruit("wheat", nil)
	addFruit("flax", nil)
	addFruit("flaxSeed", "flaxSeeds")
	addFruit("poppyFlower", nil)
	addFruit("echinaceaFlower", nil)
	addFruit("marigoldFlower", nil)
	addFruit("aloeLeaf", nil)
	addFruit("gingerRoot", nil)
	addFruit("turmericRoot", nil)
	addFruit("garlic", nil)
end

function flora:load(gameObject_)
	gameObject = gameObject_

	addFruits()
		
	resourceGroups = {
		defaultPlaceholder = {
			baseInventory = {
				[gameObject.typeIndexMap.birchBranch] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.birchBranch,
			},
		},
		willow = {
			baseInventory = {
				[gameObject.typeIndexMap.willowBranch] = 6,
				[gameObject.typeIndexMap.willowLog] = 3,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.willowBranch] = 6,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.willowSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.willowSeed,
				gameObject.typeIndexMap.willowBranch,
			},
		},
		birch = {
			baseInventory = {
				[gameObject.typeIndexMap.birchBranch] = 6,
				[gameObject.typeIndexMap.birchLog] = 3,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.birchBranch] = 6,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.birchSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.birchSeed,
				gameObject.typeIndexMap.birchBranch,
			},
		},
		aspen = {
			baseInventory = {
				[gameObject.typeIndexMap.aspenBranch] = 6,
				[gameObject.typeIndexMap.aspenLog] = 3,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.aspenBranch] = 6,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.aspenSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.aspenSeed,
				gameObject.typeIndexMap.aspenBranch,
			},
		},
		aspenBig = {
			baseInventory = {
				[gameObject.typeIndexMap.aspenBranch] = 10,
				[gameObject.typeIndexMap.aspenLog] = 20,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.aspenBranch] = 10,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.aspenBigSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.aspenBigSeed,
				gameObject.typeIndexMap.aspenBranch,
			},
		},
		bamboo = {
			baseInventory = {
				[gameObject.typeIndexMap.bambooBranch] = 4,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.bambooBranch] = 4, --note seasonalReplenish will replenish up to this value. So if you have harvested 2 and 2 are left, it will replenish to this value (4)
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.bambooSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.bambooSeed,
				gameObject.typeIndexMap.bambooBranch,
			},
			gatherKeepMinQuantity = { --this will be left in the inventory when gathering, only drops when object is chopped down
				[gameObject.typeIndexMap.bambooBranch] = 2,
			}
		},
		coconutTree = {
			baseInventory = {
				[gameObject.typeIndexMap.coconutLog] = 4,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.coconut] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.coconut,
			},
		},
		appleTree = {
			baseInventory = {
				[gameObject.typeIndexMap.appleBranch] = 2,
				[gameObject.typeIndexMap.appleLog] = 2,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.appleBranch] = 2,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.apple] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.apple,
				gameObject.typeIndexMap.appleBranch,
			},
		},
		elderberryTree = {
			baseInventory = {
				[gameObject.typeIndexMap.elderberryBranch] = 2,
				[gameObject.typeIndexMap.elderberryLog] = 2,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.elderberryBranch] = 2,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.elderberry] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.elderberry,
				gameObject.typeIndexMap.elderberryBranch,
			},
		},
		orangeTree = {
			baseInventory = {
				[gameObject.typeIndexMap.orangeBranch] = 2,
				[gameObject.typeIndexMap.orangeLog] = 2,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.orangeBranch] = 2,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.orange] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.orange,
				gameObject.typeIndexMap.orangeBranch,
			},
		},
		peachTree = {
			baseInventory = {
				[gameObject.typeIndexMap.peachBranch] = 2,
				[gameObject.typeIndexMap.peachLog] = 2,
			},
			seasonalReplenish = {
				[gameObject.typeIndexMap.peachBranch] = 2,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.peach] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.peach,
				gameObject.typeIndexMap.peachBranch,
			},
		},
		bananaTree = {
			fruitReplenish = {
				[gameObject.typeIndexMap.banana] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.banana,
			},
		},

		----PLANTS----

		raspberryBush = {
			baseInventory = {
				[gameObject.typeIndexMap.pineBranch] = 1,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.raspberry] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.raspberry,
			},
		},
		gooseberryBush = {
			baseInventory = {
				[gameObject.typeIndexMap.pineBranch] = 1,
			},
			fruitReplenish = {
				[gameObject.typeIndexMap.gooseberry] = 6,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.gooseberry,
			},
		},
		pumpkinPlant = {
			baseInventory = {},
			fruitReplenish = {
				[gameObject.typeIndexMap.pumpkin] = 1,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.pumpkin,
			},
		},
		beetrootPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.beetroot] = 1,
				[gameObject.typeIndexMap.beetrootSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.beetroot, --first is what is displayed
				gameObject.typeIndexMap.beetrootSeed,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.beetroot] = 1,
				[gameObject.typeIndexMap.beetrootSeed] = 1,
			}
		},
		gingerPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.gingerRoot] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.gingerRoot,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.gingerRoot] = 1,
			}
		},
		turmericPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.turmericRoot] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.turmericRoot,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.turmericRoot] = 1,
			}
		},
		garlicPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.garlic] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.garlic,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.garlic] = 1,
			}
		},
		sunflowerPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.sunflowerSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.sunflowerSeed,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.sunflowerSeed] = 1,
			},
		},
		generic = {
			baseInventory = {
				[gameObject.typeIndexMap.birchBranch] = 1,
			},
		},
		wheatPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.wheat] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.wheat,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.wheat] = 1,
			},
		},
		flaxPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.flax] = 1,
				[gameObject.typeIndexMap.flaxSeed] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.flax,
				gameObject.typeIndexMap.flaxSeed,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.flax] = 1,
				[gameObject.typeIndexMap.flaxSeed] = 1,
			},
		},
		poppyPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.poppyFlower] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.poppyFlower,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.poppyFlower] = 1,
			},
		},
		echinaceaPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.echinaceaFlower] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.echinaceaFlower,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.echinaceaFlower] = 1,
			},
		},
		marigoldPlant = {
			baseInventory = {
				[gameObject.typeIndexMap.marigoldFlower] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.marigoldFlower,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.marigoldFlower] = 1,
			},
		},
		aloePlant = {
			baseInventory = {
				[gameObject.typeIndexMap.aloeLeaf] = 2,
			},
			gatherableTypes = {
				gameObject.typeIndexMap.aloeLeaf,
			},
			revertToSeedlingGatherResourceCounts = {
				[gameObject.typeIndexMap.aloeLeaf] = 1,
			},
		},
	}



	for i,baseKey in ipairs(flora.logTypeBaseKeys) do
		addLogObjects(baseKey)
	end
	for i,baseKey in ipairs(flora.branchTypeBaseKeys) do
		addBranchObjects(baseKey)
	end


	local floraTypesToAdd = {

		
		----PLANTS----

		raspberryBush = {
			name = locale:get("flora_raspberryBush"),
			plural = locale:get("flora_raspberryBush_plural"),
			summary = locale:get("flora_raspberryBush_summary"),
			modelName = "raspberryBush",
			resourceGroup = resourceGroups.raspberryBush,
			markerPositions = bushMarkerPositions,
			interactable = true,
			addToPhysics = true,
			fruitSeason = seasons.autumn,
			seedResourceTypeIndex = resource.types.raspberry.index,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		gooseberryBush = {
			name = locale:get("flora_gooseberryBush"),
			plural = locale:get("flora_gooseberryBush_plural"),
			summary = locale:get("flora_gooseberryBush_summary"),
			modelName = "gooseberryBush",
			resourceGroup = resourceGroups.gooseberryBush,
			markerPositions = bushMarkerPositions,
			interactable = true,
			addToPhysics = true,
			fruitSeason = seasons.summer,
			seedResourceTypeIndex = resource.types.gooseberry.index,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		shrub = {
			name = locale:get("flora_shrub"),
			plural = locale:get("flora_shrub_plural"),
			summary = locale:get("flora_shrub_summary"),
			modelName = "shrub",
			resourceGroup = resourceGroups.generic,
			markerPositions = bushMarkerPositions,
			interactable = true,
			addToPhysics = true,
			useCraftSimple = true,
		},
		sunflower = {
			name = locale:get("flora_sunflower"),
			plural = locale:get("flora_sunflower_plural"),
			summary = locale:get("flora_sunflower_summary"),
			saplingName = locale:get("flora_sunflowerSapling"),
			saplingPlural = locale:get("flora_sunflowerSapling_plural"),
			modelName = "sunflower",
			resourceGroup = resourceGroups.sunflowerPlant,
			markerPositions = tallPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.sunflowerSeed.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		beetrootPlant = {
			name = locale:get("flora_beetrootPlant"),
			plural = locale:get("flora_beetrootPlant_plural"),
			summary = locale:get("flora_beetrootPlant_summary"),
			saplingName = locale:get("flora_beetrootPlantSapling"),
			saplingPlural = locale:get("flora_beetrootPlantSapling_plural"),
			modelName = "beetrootPlant",
			resourceGroup = resourceGroups.beetrootPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.beetrootSeed.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		gingerPlant = {
			name = locale:get("flora_gingerPlant"),
			plural = locale:get("flora_gingerPlant_plural"),
			summary = locale:get("flora_gingerPlant_summary"),
			saplingName = locale:get("flora_gingerPlantSapling"),
			saplingPlural = locale:get("flora_gingerPlantSapling_plural"),
			modelName = "gingerPlant",
			resourceGroup = resourceGroups.gingerPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.gingerRoot.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		turmericPlant = {
			name = locale:get("flora_turmericPlant"),
			plural = locale:get("flora_turmericPlant_plural"),
			summary = locale:get("flora_turmericPlant_summary"),
			saplingName = locale:get("flora_turmericPlantSapling"),
			saplingPlural = locale:get("flora_turmericPlantSapling_plural"),
			modelName = "turmericPlant",
			resourceGroup = resourceGroups.turmericPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.turmericRoot.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		garlicPlant = {
			name = locale:get("flora_garlicPlant"),
			plural = locale:get("flora_garlicPlant_plural"),
			summary = locale:get("flora_garlicPlant_summary"),
			saplingName = locale:get("flora_garlicPlantSapling"),
			saplingPlural = locale:get("flora_garlicPlantSapling_plural"),
			modelName = "garlicPlant",
			resourceGroup = resourceGroups.garlicPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.garlic.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		pumpkinPlant = {
			name = locale:get("flora_pumpkinPlant"),
			plural = locale:get("flora_pumpkinPlant_plural"),
			summary = locale:get("flora_pumpkinPlant_summary"),
			modelName = "pumpkinPlant",
			resourceGroup = resourceGroups.pumpkinPlant,
			markerPositions = bushMarkerPositions,
			interactable = true,
			addToPhysics = true,
			fruitSeason = seasons.summer,
			seedResourceTypeIndex = resource.types.pumpkin.index,
			useCraftSimple = true,
			isFoodCrop = true,
		},
		wheatPlant = {
			name = locale:get("flora_wheatPlant"),
			plural = locale:get("flora_wheatPlant_plural"),
			summary = locale:get("flora_wheatPlant_summary"),
			saplingName = locale:get("flora_wheatPlantSapling"),
			saplingPlural = locale:get("flora_wheatPlantSapling_plural"),
			modelName = "wheatPlantCluster",
			saplingModelName = "wheatPlantSaplingCluster",
			resourceGroup = resourceGroups.wheatPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.wheat.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
		},
		flaxPlant = {
			name = locale:get("flora_flaxPlant"),
			plural = locale:get("flora_flaxPlant_plural"),
			summary = locale:get("flora_flaxPlant_summary"),
			saplingName = locale:get("flora_flaxPlantSapling"),
			saplingPlural = locale:get("flora_flaxPlantSapling_plural"),
			modelName = "flaxPlant",
			resourceGroup = resourceGroups.flaxPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.flaxSeed.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
		},
		flower1 = {
			name = locale:get("flora_flower1"),
			plural = locale:get("flora_flower1_plural"),
			summary = locale:get("flora_flower1_summary"),
			modelName = "flower1",
			markerPositions = tinyPlantMarkerPositions,
			useCraftSimple = true,
		},
		poppyPlant = {
			name = locale:get("flora_poppyPlant"),
			plural = locale:get("flora_poppyPlant_plural"),
			summary = locale:get("flora_poppyPlant_summary"),
			saplingName = locale:get("flora_poppyPlantSapling"),
			saplingPlural = locale:get("flora_poppyPlantSapling_plural"),
			modelName = "poppyPlant",
			resourceGroup = resourceGroups.poppyPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.poppyFlower.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
		},
		echinaceaPlant = {
			name = locale:get("flora_echinaceaPlant"),
			plural = locale:get("flora_echinaceaPlant_plural"),
			summary = locale:get("flora_echinaceaPlant_summary"),
			saplingName = locale:get("flora_echinaceaPlantSapling"),
			saplingPlural = locale:get("flora_echinaceaPlantSapling_plural"),
			modelName = "echinaceaPlant",
			resourceGroup = resourceGroups.echinaceaPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.echinaceaFlower.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
		},
		marigoldPlant = {
			name = locale:get("flora_marigoldPlant"),
			plural = locale:get("flora_marigoldPlant_plural"),
			summary = locale:get("flora_marigoldPlant_summary"),
			saplingName = locale:get("flora_marigoldPlantSapling"),
			saplingPlural = locale:get("flora_marigoldPlantSapling_plural"),
			modelName = "marigoldPlant",
			resourceGroup = resourceGroups.marigoldPlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.marigoldFlower.index,
			maturityDurationDays = 3,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
		},
		aloePlant = {
			name = locale:get("flora_aloePlant"),
			plural = locale:get("flora_aloePlant_plural"),
			summary = locale:get("flora_aloePlant_summary"),
			saplingName = locale:get("flora_aloePlantSapling"),
			saplingPlural = locale:get("flora_aloePlantSapling_plural"),
			modelName = "aloePlant",
			resourceGroup = resourceGroups.aloePlant,
			markerPositions = tinyPlantMarkerPositions,
			seedResourceTypeIndex = resource.types.aloeLeaf.index,
			maturityDurationDays = 6,
			fruitImmediatelyWhenMature = true,
			interactable = true,
			useCraftSimple = true,
		},

		--- TREES ---
		
		cactus = {
			name = locale:get("flora_cactus"),
			plural = locale:get("flora_cactus_plural"),
			summary = locale:get("flora_cactus_summary"),
			saplingName = locale:get("flora_cactus_sapling"),
			saplingPlural = locale:get("flora_cactus_sapling_plural"),
			modelName = "cactus",
			resourceGroup = resourceGroups.defaultPlaceholder,
			requiresAxeToChop = true,
			markerPositions = treeMarkerPositions,
			useCraftSimple = true,
		},
		palm = {
			name = locale:get("flora_palm"),
			plural = locale:get("flora_palm_plural"),
			summary = locale:get("flora_palm_summary"),
			saplingName = locale:get("flora_palm_sapling"),
			saplingPlural = locale:get("flora_palm_sapling_plural"),
			modelName = "palm",
			resourceGroup = resourceGroups.defaultPlaceholder,
			requiresAxeToChop = true,
			markerPositions = treeMarkerPositions,
			useCraftSimple = true,
		},
	}
	

	local variationInfos = {
		birch = {
			count = 4,
			fruitSeason = seasons.summer,
			seed = "birchSeed",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allBirchTrees.index,
		},
		aspen = {
			count = 3,
			fruitSeason = seasons.summer,
			seed = "aspenSeed",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allAspenTrees.index,
		},
		willow = {
			count = 2,
			fruitSeason = seasons.summer,
			seed = "willowSeed",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allWillowTrees.index,
		},
		pine = {
			count = 4,
			fruitSeason = seasons.summer,
			seed = "pineCone",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allPineTrees.index,
		},
		pineBig = {
			count = 1,
			fruitSeason = seasons.summer,
			seed = "pineConeBig",
			branchBaseTypeKey = "pine",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allPineTrees.index,
		},
		aspenBig = {
			count = 1,
			fruitSeason = seasons.summer,
			seed = "aspenBigSeed",
			branchBaseTypeKey = "aspen",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allAspenTrees.index,
		},
		bamboo = {
			count = 2,
			fruitSeason = seasons.summer,
			seed = "bambooSeed",
			speciesSelectionGroupTypeIndex = selectionGroup.types.allBambooTrees.index,
		},
	}
	
	local function addDeciduousWithSeed(treeKey, fruitFrequencyInYearsOrNil)

		local variationInfo = variationInfos[treeKey]
		local seedKey = variationInfo.seed
		local variationCount = variationInfo.count
		
		addFruit(seedKey, nil)

		--local branchBaseTypeKey = variationInfo.branchBaseTypeKey or treeKey
		
		--local branchKey = branchBaseTypeKey .. "Branch"
		--local logKey = branchBaseTypeKey .. "Log"

		if not resourceGroups[treeKey] then
			mj:error("missing resourceGroup for:", treeKey)
			error()
		end
		
		local localeKey = "flora_" .. treeKey
		local localeKeyPlural = localeKey .. "_plural"
		local saplingLocaleKey = localeKey .. "_sapling"
		local saplingLocaleKeyPlural = saplingLocaleKey .. "_plural"

		local treeName = locale:get(localeKey)
		local treeNamePlural = locale:get(localeKeyPlural)
		
		local saplingKey = treeKey .. "Sapling"
		local saplingName = locale:get(saplingLocaleKey)
		local saplingPlural = locale:get(saplingLocaleKeyPlural)


		for i=1,variationCount do
			local modelName = treeKey .. mj:tostring(i)
			local resourceGroup = resourceGroups[modelName]
			if not resourceGroup then
				resourceGroup = resourceGroups[treeKey]
			end
			local treeInfo = {
				name = treeName,
				plural = treeNamePlural,
				modelName = modelName,
				resourceGroup = resourceGroup,
				requiresAxeToChop = true,
				markerPositions = treeMarkerPositions,
				followCamOffset = treeFollowCamOffset,
				clientModelFunction = getClientModelFunction(treeKey, modelName, true, false, false),
				seedResourceTypeIndex = resource.types[seedKey].index,
				saplingBaseKey = saplingKey,
				saplingClientModelFunction = getClientModelFunction(treeKey, saplingKey, true, false, true),
				saplingName = saplingName,
				saplingPlural = saplingPlural,
				fruitSeason = variationInfo.fruitSeason,
				speciesSelectionGroupTypeIndex = variationInfo.speciesSelectionGroupTypeIndex,
				isPathFindingCollider = true,
				useCraftSimple = true,
				playBirdSounds = true,
				fruitFrequencyInYears = fruitFrequencyInYearsOrNil,
				summary = locale:get(localeKey .. "_summary")
			}
			floraTypesToAdd[modelName] = treeInfo
		end
	end
	
	
	local function addEvergreen(treeKey, fruitFrequencyInYearsOrNil, maturityDurationDays, resourceCounts, isPathFindingCollider)
		
		local variationInfo = variationInfos[treeKey]
		local seedKey = variationInfo.seed
		local variationCount = variationInfo.count

		addFruit(seedKey, nil)
		
		local branchBaseTypeKey = variationInfo.branchBaseTypeKey or treeKey
		
		local localeKey = "flora_" .. treeKey
		local localeKeyPlural = localeKey .. "_plural"
		local saplingLocaleKey = localeKey .. "_sapling"
		local saplingLocaleKeyPlural = saplingLocaleKey .. "_plural"

		local treeName = locale:get(localeKey)
		local treeNamePlural = locale:get(localeKeyPlural)
		
		local saplingKey = treeKey .. "Sapling"
		local saplingName = locale:get(saplingLocaleKey)
		local saplingPlural = locale:get(saplingLocaleKeyPlural)
		
		local branchKey = branchBaseTypeKey .. "Branch"
		local logKey = branchBaseTypeKey .. "Log"
	

		for i=1,variationCount do
			local modelName = treeKey .. mj:tostring(i)
			local resourceGroup = nil
			if resourceCounts then
				resourceGroup = {
					baseInventory = {},
					seasonalReplenish = {
						[gameObject.typeIndexMap[branchKey]] = resourceCounts[i].branch,
					},
					fruitReplenish = {
						[gameObject.typeIndexMap[seedKey]] = resourceCounts[i].seed,
					},
					gatherableTypes = {
						gameObject.typeIndexMap[seedKey],
						gameObject.typeIndexMap[branchKey],
					},
				}

				if resourceCounts[i].log and resourceCounts[i].log > 0 then
					resourceGroup.baseInventory[gameObject.typeIndexMap[logKey]] = resourceCounts[i].log
				end

				resourceGroups[modelName] = resourceGroup
			else
				resourceGroup = resourceGroups[modelName]
				if not resourceGroup then
					resourceGroup = resourceGroups[treeKey]
				end
			end

			--[[if (not fruitFrequencyInYearsOrNil) or (fruitFrequencyInYearsOrNil == 1) then
				resourceGroup.baseInventory[gameObject.typeIndexMap[seedKey] ] = 4
			end]]
			

			local treeInfo = {
				name = treeName,
				plural = treeNamePlural,
				modelName = modelName,
				resourceGroup = resourceGroup,
				requiresAxeToChop = true,
				markerPositions = treeMarkerPositions,
				followCamOffset = treeFollowCamOffset,
				clientModelFunction = getClientModelFunction(treeKey, modelName, false, true, false),
				seedResourceTypeIndex = resource.types[seedKey].index,
				saplingBaseKey = saplingKey,
				saplingClientModelFunction = getClientModelFunction(treeKey, saplingKey, false, true, true),
				saplingName = saplingName,
				saplingPlural = saplingPlural,
				fruitSeason = variationInfo.fruitSeason,
				speciesSelectionGroupTypeIndex = variationInfo.speciesSelectionGroupTypeIndex,
				isPathFindingCollider = isPathFindingCollider,
				useCraftSimple = true,
				fruitFrequencyInYears = fruitFrequencyInYearsOrNil,
				maturityDurationDays = maturityDurationDays,
				playBirdSounds = true,
				summary = locale:get(localeKey .. "_summary")
			}
			floraTypesToAdd[modelName] = treeInfo
		end
	end

	local function addSimpleFruitTreeType(fruitKey, fruitSeason, generateSeasonalVariations, maturityDurationDaysOrNil)
		local treeKey = fruitKey .. "Tree"

		addFruit(fruitKey, nil)
		
		
		local localeKey = "flora_" .. treeKey
		local localeKeyPlural = localeKey .. "_plural"
		local saplingLocaleKey = localeKey .. "_sapling"
		local saplingLocaleKeyPlural = saplingLocaleKey .. "_plural"

		local treeName = locale:get(localeKey)
		local treeNamePlural = locale:get(localeKeyPlural)

		if not resourceGroups[treeKey] then
			mj:error("no resource group defined for tree type:", treeKey)
			error()
		end

		local treeInfo = {
			name = treeName,
			plural = treeNamePlural,
			resourceGroup = resourceGroups[treeKey],
			requiresAxeToChop = true,
			markerPositions = treeMarkerPositions,
			followCamOffset = treeFollowCamOffset, 
			fruitSeason = fruitSeason,
			seedResourceTypeIndex = resource.types[fruitKey].index,
			saplingName = locale:get(saplingLocaleKey),
			saplingPlural = locale:get(saplingLocaleKeyPlural),
			isPathFindingCollider = false,
			useCraftSimple = true,
			isFoodCrop = true,
			maturityDurationDays = maturityDurationDaysOrNil,
			playBirdSounds = true,
			summary = locale:get(localeKey .. "_summary")
		}

		treeInfo.modelName = treeKey
		local saplingKey = treeKey .. "Sapling"
		if generateSeasonalVariations then
			treeInfo.clientModelFunction = getClientModelFunction(treeKey, treeKey, true, false, false)
			treeInfo.saplingClientModelFunction = getClientModelFunction(treeKey, saplingKey, true, false, true)
		else
			treeInfo.saplingClientModelFunction = getClientModelFunction(treeKey, saplingKey, false, false, true)
		end

		floraTypesToAdd[treeKey] = treeInfo
	end
	

	addSimpleFruitTreeType("apple", seasons.summer, true, nil)
	addSimpleFruitTreeType("elderberry", seasons.autumn, true, nil)

	addSimpleFruitTreeType("orange", seasons.winter, false, nil)
	addSimpleFruitTreeType("peach", seasons.summer, true, nil)
	
	addSimpleFruitTreeType("banana", seasons.autumn, false, 8)
	addSimpleFruitTreeType("coconut", seasons.winter, false, 8)

	addDeciduousWithSeed("birch", nil)
	addDeciduousWithSeed("aspen", nil)
	addDeciduousWithSeed("willow", nil)
	
	addDeciduousWithSeed("aspenBig", 5)

	addEvergreen("pine", nil, nil, {
		{
			branch = 3,
			log = 4,
			seed = 2,
		},
		{
			branch = 3,
			log = 4,
			seed = 2,
		},
		{
			branch = 2,
			log = 6,
			seed = 2,
		},
		{
			branch = 4,
			log = 2,
			seed = 2,
		},
	}, true)
	

	addEvergreen("pineBig", 5, 16, {
		{
			branch = 10,
			log = 20,
			seed = 2,
		},
	}, true)

	
	addEvergreen("bamboo", nil, 2, nil, false)


	for gameObjectTypeKey, info in pairs(floraTypesToAdd) do
		addFlora(gameObjectTypeKey, info)
	end

	for treeKey,variationInfo in pairs(variationInfos) do
		local constructableTypeIndexes = {}
		for i=1,variationInfo.count do
			local typeKey = treeKey .. mj:tostring(i)
			local floraInfo = flora.types[typeKey]
			local constructableTypeIndex = floraInfo.constructableTypeIndex
			table.insert(constructableTypeIndexes, constructableTypeIndex)
		end
		
		local baseConstructableTypeIndex = constructableTypeIndexes[1]
		constructable.types[baseConstructableTypeIndex].variationsAllowRandom = true

		constructable:addVariations(constructableTypeIndexes)
	end


	resource:setSeedResourceTypeIndexes(flora.seedResourceTypeIndexes)

end

function flora:getGrowthPhase(floraObject, worldTime, yearLength)
	local matureTime = floraObject.sharedState.matureTime
	if not matureTime then
		return flora.growthPhases.dirt
	end
	local matureFraction = 1.0 - ((matureTime - worldTime) / yearLength)
	--mj:log("getGrowthPhase:", floraObject.uniqueID, " matureFraction:", matureFraction, " matureTime:", matureTime, " worldTime:", worldTime)
	if (matureFraction < 0.25) then
		return flora.growthPhases.dirt
	elseif matureFraction < 0.75 then
		return flora.growthPhases.sprout
	elseif matureFraction < 1.0 then
		return flora.growthPhases.sapling
	else
		return flora.growthPhases.mature
	end
end


function flora:requiresAxeToChop(floraObject)
	--mj:log("floraObject:", floraObject, " gameObject.types[floraObject.objectTypeIndex]:", gameObject.types[floraObject.objectTypeIndex] )
	--mj:log("flora.types[gameObject.types[floraObject.objectTypeIndex].floraTypeIndex]:", floraTypes[gameObject.types[floraObject.objectTypeIndex].floraTypeIndex])
	return flora.types[gameObject.types[floraObject.objectTypeIndex].floraTypeIndex].requiresAxeToChop
end

function flora:isFoodCrop(object)
	local floraTypeIndex = gameObject.types[object.objectTypeIndex].floraTypeIndex
	if floraTypeIndex then
		return flora.types[floraTypeIndex].isFoodCrop
	end
	return false
end

return flora