local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local normalize = mjm.normalize
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local mat3Inverse = mjm.mat3Inverse

local locale = mjrequire "common/locale"

--local order = mjrequire "common/order"
local model = mjrequire "common/model"
local physics = mjrequire "common/physics"
local snapGroup = mjrequire "common/snapGroups/snapGroup"
local resource = mjrequire "common/resource"
local storage = mjrequire "common/storage"
local action = mjrequire "common/action"
local seat = mjrequire "common/seat"
local rng = mjrequire "common/randomNumberGenerator"
local sapienConstants = mjrequire "common/sapienConstants"
local selectionGroup = mjrequire "common/selectionGroup"
local craftAreaGroup = mjrequire "common/craftAreaGroup"
local pathFinding = mjrequire "common/pathFinding"
local rock = mjrequire "common/rock"
local compostBin = mjrequire "common/compostBin"
local notification = mjrequire "common/notification"
local storageSettings = mjrequire "common/storageSettings"
local objectSpawner = mjrequire "common/objectSpawner"
--local skill = mjrequire "common/skill"

local buildable = mjrequire "common/buildable"
local constructable = mjrequire "common/constructable"
local craftable = mjrequire "common/craftable"
local harvestable = mjrequire "common/harvestable"
local flora = mjrequire "common/flora"
local tool = mjrequire "common/tool"
local mob = mjrequire "common/mob/mob"
local terrainTypes = mjrequire "common/terrainTypes"
local pathBuildable = mjrequire "common/pathBuildable"
local research = mjrequire "common/research"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local sapienModelComposite = mjrequire "common/modelComposites/sapien"
local skillLearning = mjrequire "common/skillLearning"

local typeMaps = mjrequire "common/typeMaps"

local gameObject = {
	types = {}
}

mj.gameObject = gameObject --for mj to log info about game objects

--mj:log("game object file parsed")

gameObject.typeIndexMap = typeMaps.types.gameObject

local anchorTypeIndexMap = typeMaps.types.anchor


function gameObject:getCompositeModelInfo(object)
	if object.compositeModelInfo then
		return object.compositeModelInfo --this occurs with mainThreadGeometry, it is set in the object table passed in to gameObject:modelIndexForGameObjectAndLevel
	end
	local gameObjectType = object.objectTypeIndex
	local modelComposite = gameObject.types[gameObjectType].modelComposite
	if modelComposite then
		local compositeInfo = modelComposite:generate(object)
		return compositeInfo
	end
	return nil
end

local modelFunctionContext = {
	seasonFraction = 0.0,
	worldTime = 0.0,
	yearLength = 100.0,
	localTribeID = nil, --only available on logic, main threads
	tribeRelationsSettings = nil --only available on main thread
}

function gameObject:setYearLength(yearLength)
	modelFunctionContext.yearLength = yearLength
end

function gameObject:setLocalTribeID(localTribeID)
	modelFunctionContext.localTribeID = localTribeID
end

function gameObject:setTribeRelationsSettings(tribeRelationsSettings)
	modelFunctionContext.tribeRelationsSettings = tribeRelationsSettings
end

function gameObject:updateSeasonFraction(seasonFraction, worldTime)
	--mj:error("gameObject:updateSeasonFraction:", worldTime)
	modelFunctionContext.seasonFraction = seasonFraction
	modelFunctionContext.worldTime = worldTime
end

function gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(objectTypeIndex, subdivLevel)
	local modelLevel = model:modelLevelForSubdivLevel(subdivLevel)
	local gameObjectType = gameObject.types[objectTypeIndex]
	return gameObjectType.modelIndexesByDetail[modelLevel]
end

function gameObject:modelIndexForGameObjectAndLevel(object, subdivLevel, terrainVariations)
	local compositeInfo = gameObject:getCompositeModelInfo(object)
	local modelResult = nil
	if compositeInfo then
		modelResult = model:getModelIndexForCompositeModel(compositeInfo)
	else
		local gameObjectType = gameObject.types[object.objectTypeIndex]
		if gameObjectType.modelFunction then
			local modelLevel = model:modelLevelForSubdivLevel(subdivLevel)
			modelResult = gameObjectType.modelFunction(object, modelLevel, modelFunctionContext, terrainVariations)
		else
			modelResult = gameObject:simpleModelIndexForGameObjectTypeAndSubdivLevel(object.objectTypeIndex, subdivLevel)
		end
	end

	--[[if not modelResult then
		mj:log("no modelIndexForGameObjectAndLevel. gameObjectType:", gameObject.types[object.objectTypeIndex])
	end]]

	return modelResult
end

function gameObject:gameObjectForType(gameObjectType)
    return gameObject.types[gameObjectType]
end

function gameObject:addGameObject(key, objectType)
	local index = gameObject.typeIndexMap[key]
	if not index then
		mj:log("ERROR: attempt to add object type that isn't in typeIndexMap:", key)
	else
		if gameObject.types[key] then
			mj:log("WARNING: overwriting object type:", key)
			mj:log(debug.traceback())
		end

		objectType.key = key
		objectType.index = index
		gameObject.types[key] = objectType
		gameObject.types[index] = objectType

		--mj:log("addGameObject:", key, " index:", index)
	end
	return index
end

function gameObject:addGameObjectsFromTable(objectTable)
	for key,objectType in pairs(objectTable) do
		gameObject:addGameObject(key,objectType)
	end
end

local function bedNameFunction(object, default)
	if object.sharedState.assignedBedSapienName then
		return locale:get("ui_objectBelongingToSapien", {sapienName = object.sharedState.assignedBedSapienName, objectName = default})
	end
	return default
end


local markerPositions = {
	wall4x2 = {
		{ 
			localOffset = vec3(0.0, mj:mToP(1.5), mj:mToP(0.2))
		},
		{ 
			localOffset = vec3(0.0, mj:mToP(1.5), mj:mToP(-0.2))
		}
	},
	wall4x1 = {
		{ 
			localOffset = vec3(0.0, mj:mToP(0.75), mj:mToP(0.2))
		},
		{ 
			localOffset = vec3(0.0, mj:mToP(0.75), mj:mToP(-0.2))
		}
	},
}

local function storageIconOverrideFunction(object)
	local result = {}
	local sharedState = object.sharedState
	if sharedState then
		local function getStorageTypeIndex()
			if sharedState.contentsStorageTypeIndex then
				return sharedState.contentsStorageTypeIndex
			end
			
			if modelFunctionContext.localTribeID and sharedState.settingsByTribe then
				local tribeIDToUse = storageSettings:getSettingsTribeIDToUse(sharedState, modelFunctionContext.localTribeID, modelFunctionContext.tribeRelationsSettings)
				local tribeSettings = sharedState.settingsByTribe[tribeIDToUse]
				if tribeSettings then
					local restrictStorageTypeIndex = tribeSettings.restrictStorageTypeIndex
					if restrictStorageTypeIndex then
						return restrictStorageTypeIndex
					end
				end
			end
			return 0
		end

		if sharedState.firstObjectTypeIndex then
			result.object = {
				objectTypeIndex = sharedState.firstObjectTypeIndex
			}
		elseif sharedState.inventory and #sharedState.inventory.objects > 0 then
			--sendInfo.firstObjectTypeIndex = sharedState.inventory.objects[1].objectTypeIndex
			result.object = {
				objectTypeIndex = sharedState.inventory.objects[1].objectTypeIndex
			}
		else
			local storageTypeIndex = getStorageTypeIndex()
			if storageTypeIndex > 0 then
				result.object = {
					objectTypeIndex = storage.types[storageTypeIndex].displayGameObjectTypeIndex
				}
			end
		end
	end

	if not result.object then
		local gameObjectType = gameObject.types[object.objectTypeIndex]
		if gameObjectType.iconOverrideIconModelName then
			result.iconModelName =  gameObjectType.iconOverrideIconModelName
		else
			result.object = {
				objectTypeIndex = object.objectTypeIndex
			}
		end
	end

	return result
end

local function storageNameFunction(object, default)
	local storageTypeIndex = object.sharedState.contentsStorageTypeIndex
	
	if (not storageTypeIndex) and modelFunctionContext.localTribeID then
		local tribeSettings = object.sharedState.settingsByTribe and object.sharedState.settingsByTribe[modelFunctionContext.localTribeID]
		if tribeSettings then
			storageTypeIndex = tribeSettings.restrictStorageTypeIndex
		end
	end

	if storageTypeIndex and storageTypeIndex > 0 then --restrictStorageTypeIndex can be zero or -1 as a marker for something
		local count = 0
		local inventory = object.sharedState.inventory
		if inventory then
			if inventory.objects then
				count = #inventory.objects
			end
		end

		if count > 0 then
			return default .. " - " .. storage.types[storageTypeIndex].name .. " (" .. mj:tostring(count) .. ")"
		else
			return default .. " - " .. storage.types[storageTypeIndex].name
		end
	end
	return default
end

local function storageIconGameObjectTypeFunction(object, default)
	local inventory = object.sharedState.inventory
	if inventory then
		if inventory.objects and #inventory.objects > 0 then
			return inventory.objects[1].objectTypeIndex
		end
	end
	
	local storageTypeIndex = object.sharedState.contentsStorageTypeIndex
	
	if (not storageTypeIndex) and modelFunctionContext.localTribeID then
		local tribeSettings = object.sharedState.settingsByTribe and object.sharedState.settingsByTribe[modelFunctionContext.localTribeID]
		if tribeSettings then
			storageTypeIndex = tribeSettings.restrictStorageTypeIndex
		end
	end

	
	if storageTypeIndex then
		return storage.types[storageTypeIndex].displayGameObjectTypeIndex
	end

	return default
end

local function haulObjectMarkerNameFunction(object, default)
	local nameToUse = object.sharedState.haulObjectName
	if not nameToUse then
		local haulObjectTypeIndex = object.sharedState.haulObjectTypeIndex or gameObject.types.sled.index
		nameToUse = gameObject.types[haulObjectTypeIndex].name
	end
	return locale:get("plan_haulObject_inProgress") .. " " .. nameToUse
end


local gameObjectsTable = {
	
	plan_move = {
		hasPhysics = false,
		ignoreBuildRay = true,
		renderTypeOverride = RENDER_TYPE_NONE,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.4), 0.0)
			}
		},
	},
	
	haulObjectDestinationMarker = {
		hasPhysics = false,
		ignoreBuildRay = true,
		renderTypeOverride = RENDER_TYPE_NONE,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.4), 0.0)
			}
		},
		anchorType = anchorTypeIndexMap.haulObjectDestinationMarker,
		nameFunction = haulObjectMarkerNameFunction,
		iconOverrideIconModelName = "icon_destinationPin",
	},

	terrainModificationProxy = {
		modelName = "craftSimple",
		scale = 1.0,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.4), 0.0)
			}
		},
	},

	

	flint = {
		modelName = "flint",
		scale = 1.0,
		scarcityValue = 20,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.flint.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
		toolUsages = {
			[tool.types.weaponBasic.index] = {
				[tool.propertyTypes.damage.index] = 0.3,
				[tool.propertyTypes.durability.index] = 2.0,
			},
		},
	},
	clay = {
		modelName = "clay",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.clay.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	copperOre = {
		modelName = "copperOre",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.copperOre.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	tinOre = {
		modelName = "tinOre",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.tinOre.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	sapien = {
		modelComposite = sapienModelComposite,
		scale = 1.0,
		hasPhysics = false,
		ignoreBuildRay = true,
		excludeFromClientCache = true,
		projectileAimHeightOffsetMeters = 1.4,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, rng:valueForUniqueID(object.uniqueID, 3232) - 0.5, normalize(vec3(0.0, 1.0, 0.0))) 
		end,
		objectViewCameraOffsetFunction = function(object)
			local zOffset = 0.1
			if object.sharedState.lifeStageIndex ==  sapienConstants.lifeStages.child.index then
				zOffset = 0.13
			end
			return vec3(0.0,(rng:valueForUniqueID(object.uniqueID, 3233) - 0.5) * 0.1,zOffset)
		end,
		objectViewOffsetFunction = function(object)
			if object.sharedState.lifeStageIndex ==  sapienConstants.lifeStages.child.index then
				return vec3(0.0,0.85,0.0)
			else
				return vec3(0.0,1.4,0.0)
			end
		end,
		followCamOffsetFunction = function(object)
			if object.sharedState.lifeStageIndex ==  sapienConstants.lifeStages.child.index then
				return vec2(6.0,0.6)
			else
				return vec2(6.0,1.0)
			end
		end,
		sapienLookAtOffsetFunction = function(object)
			local sitting = false
			local actionModifiers = object.sharedState.actionModifiers
			if actionModifiers and actionModifiers[action.modifierTypes.sit.index] then
				sitting = true
			end
			return vec3(0.0, sapienConstants:getEyeHight(object.sharedState.lifeStageIndex, sitting), 0.0)
		end,
		markerPositions = {
			{
				worldOffset = vec3(0,mj:mToP(0.2),0), 
				boneOffset = vec3(0,mj:mToP(0.2),0)
			}
		},
	},
	stick = { --not able to be used in game, just a proxy for the model when used as a tool when crafting
		modelName = "stick",
		scale = 1.0,
	},
	paddle = { --not able to be used in game, just a proxy for the model when used as a tool when rowing
		modelName = "paddle",
		scale = 1.0,
	},
	drumStick = { --not able to be used in game, just a proxy for the model when used as a tool when crafting
		modelName = "drumStick",
		scale = 1.0,
	},
	burntBranch = {
		modelName = "burntBranch",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.burntBranch.index,
		isBurntObject = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	branchRotten = {
		modelName = "rottenBranch",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.branchRotten.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	campfire = {
		modelName = "campfire",
		scale = 1.0,
		isCraftArea = true,
		ignoreBuildRay = true,
		craftAreaGroupTypeIndex = craftAreaGroup.types.campfire.index,
		hasPhysics = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		preventGrassAndSnow = true,
		disallowAnyCollisionsOnPlacement = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		sapienLookAtOffset = vec3(0.0,mj:mToP(0.5),0.0),
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		temperatureInfluenceRadius2 = mj:mToP(20.0) * mj:mToP(20.0), --just having this isn't enough, must also be added to objectSet on load. Max of 20m
	},
	build_campfire = {
		modelName = "campfire",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		preventGrassAndSnow = true,
		ignoreBuildRay = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		}
	},
	brickKiln = {
		modelName = "brickKiln",
		scale = 1.0,
		isCraftArea = true,
		ignoreBuildRay = true,
		craftAreaGroupTypeIndex = craftAreaGroup.types.kiln.index,
		hasPhysics = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		preventGrassAndSnow = true,
		disallowAnyCollisionsOnPlacement = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		sapienLookAtOffset = vec3(0.0,mj:mToP(0.5),0.0),
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		temperatureInfluenceRadius2 = mj:mToP(20.0) * mj:mToP(20.0), --just having this isn't enough, must also be added to objectSet on load. Max of 20m
	},
	build_brickKiln = {
		modelName = "brickKiln",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		preventGrassAndSnow = true,
		ignoreBuildRay = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		}
	},
	torch = {
		modelName = "torch",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		ignoreBuildRay = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		sapienLookAtOffset = vec3(0.0,mj:mToP(0.5),0.0),
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(2.0), 0.0)
			}
		},
	},
	build_torch = {
		modelName = "torch",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		ignoreBuildRay = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(2.0), 0.0)
			}
		},
	},
	dirt = {
		modelName = "dirt",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.dirt.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	richDirt = {
		modelName = "richDirt",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.dirt.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	poorDirt = {
		modelName = "poorDirt",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.dirt.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	sand = {
		modelName = "sand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.sand.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	riverSand = {
		modelName = "riverSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.sand.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	redSand = {
		modelName = "redSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.sand.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},

	dirtFoundation1x1 = {
		modelName = "dirtFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_dirtFoundation1x1 = {
		modelName = "dirtFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	dirtFoundation2x2 = {
		modelName = "dirtFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_dirtFoundation2x2 = {
		modelName = "dirtFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	thatchWall = {
		modelName = "thatchWall",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_thatchWall = {
		modelName = "thatchWall",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	thatchWallDoor = {
		modelName = "thatchWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_thatchWallDoor = {
		modelName = "thatchWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	thatchWallLargeWindow = {
		modelName = "thatchWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_thatchWallLargeWindow= {
		modelName = "thatchWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	thatchRoof = {
		modelName = "thatchRoof",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoof = {
		modelName = "thatchRoof",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofSlope = {
		modelName = "thatchRoofSlope",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSlopeFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofSlope = {
		modelName = "thatchRoofSlope",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSlopeFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofSmallCorner = {
		modelName = "thatchRoofSmallCorner",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofSmallCorner = {
		modelName = "thatchRoofSmallCorner",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofSmallCornerInside = {
		modelName = "thatchRoofSmallCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallInnerCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofSmallCornerInside = {
		modelName = "thatchRoofSmallCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallInnerCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofTriangle = {
		modelName = "thatchRoofTriangle",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofTriangle = {
		modelName = "thatchRoofTriangle",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	thatchRoofInvertedTriangle = {
		modelName = "thatchRoofInvertedTriangle",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofInvertedTriangleFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofInvertedTriangle = {
		modelName = "thatchRoofInvertedTriangle",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofInvertedTriangleFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofLarge = {
		modelName = "thatchRoofLarge",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.largeRoofFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofLarge = {
		modelName = "thatchRoofLarge",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.largeRoofFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofLargeCorner = {
		modelName = "thatchRoofLargeCorner",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.largeRoofCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofLargeCorner = {
		modelName = "thatchRoofLargeCorner",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.largeRoofCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	thatchRoofLargeCornerInside = {
		modelName = "thatchRoofLargeCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.largeRoofCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_thatchRoofLargeCornerInside = {
		modelName = "thatchRoofLargeCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.largeRoofCornerFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	thatchRoofEnd = {
		modelName = "thatchRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_thatchRoofEnd = {
		modelName = "thatchRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	thatchWall4x1 = {
		modelName = "thatchWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		isPathFindingCollider = true,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_thatchWall4x1 = {
		modelName = "thatchWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	thatchWall2x2 = {
		modelName = "thatchWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		isPathFindingCollider = true,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_thatchWall2x2 = {
		modelName = "thatchWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},

	thatchWall2x1 = {
		modelName = "thatchWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		isPathFindingCollider = true,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_thatchWall2x1 = {
		modelName = "thatchWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		windDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	splitLogFloor1x1 = {
		modelName = "splitLogFloor1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_splitLogFloor1x1 = {
		modelName = "splitLogFloor1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floor1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	splitLogFloor = {
		modelName = "splitLogFloor2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_splitLogFloor = {
		modelName = "splitLogFloor2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floor2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	splitLogFloor4x4 = {
		modelName = "splitLogFloor4x4",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		decalBlockRadius2 = mj:mToP(4.4) * mj:mToP(4.4),
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor4x4FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_splitLogFloor4x4 = {
		modelName = "splitLogFloor4x4",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.floor4x4FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	splitLogFloorTri2 = {
		modelName = "splitLogFloorTri2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floorTri2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_splitLogFloorTri2 = {
		modelName = "splitLogFloorTri2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floorTri2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	splitLogWall = {
		modelName = "splitLogWall",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_splitLogWall = {
		modelName = "splitLogWall",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	splitLogWallDoor = {
		modelName = "splitLogWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_splitLogWallDoor = {
		modelName = "splitLogWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	splitLogWallLargeWindow = {
		modelName = "splitLogWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_splitLogWallLargeWindow = {
		modelName = "splitLogWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	
	splitLogWall4x1 = {
		modelName = "splitLogWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_splitLogWall4x1 = {
		modelName = "splitLogWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	splitLogWall2x2 = {
		modelName = "splitLogWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_splitLogWall2x2 = {
		modelName = "splitLogWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},

	splitLogWall2x1 = {
		modelName = "splitLogWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_splitLogWall2x1 = {
		modelName = "splitLogWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	
	splitLogRoofEnd = {
		modelName = "splitLogRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_splitLogRoofEnd = {
		modelName = "splitLogRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	splitLogSteps = {
		modelName = "splitLogSteps",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.path.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.steps1p5FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_splitLogSteps = {
		modelName = "splitLogSteps",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.steps1p5FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	
	splitLogSteps2x2 = {
		modelName = "splitLogSteps2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.path.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.steps2HalfFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_splitLogSteps2x2 = {
		modelName = "splitLogSteps2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.steps2HalfFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	splitLogRoof = {
		modelName = "splitLogRoof",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_splitLogRoof = {
		modelName = "splitLogRoof",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	splitLogRoofSlope = {
		modelName = "splitLogRoofSlope",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSlopeFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_splitLogRoofSlope = {
		modelName = "splitLogRoofSlope",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSlopeFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	splitLogRoofSmallCorner = {
		modelName = "splitLogRoofSmallCorner",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_splitLogRoofSmallCorner = {
		modelName = "splitLogRoofSmallCorner",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	splitLogRoofSmallCornerInside = {
		modelName = "splitLogRoofSmallCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallInnerCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_splitLogRoofSmallCornerInside = {
		modelName = "splitLogRoofSmallCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallInnerCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	splitLogRoofTriangle = {
		modelName = "splitLogRoofTriangle",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_splitLogRoofTriangle = {
		modelName = "splitLogRoofTriangle",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	splitLogRoofInvertedTriangle = {
		modelName = "splitLogRoofInvertedTriangle",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofInvertedTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_splitLogRoofInvertedTriangle = {
		modelName = "splitLogRoofInvertedTriangle",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofInvertedTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},

	dirtWall = {
		modelName = "dirtWall",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		isPathFindingCollider = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_dirtWall = {
		modelName = "dirtWall",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	dirtWallDoor = {
		modelName = "dirtWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_dirtWallDoor = {
		modelName = "dirtWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	dirtRoof = {
		modelName = "dirtRoof",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_dirtRoof = {
		modelName = "dirtRoof",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.5,-0.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	hay = {
		modelName = "hay",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.hay.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	hayRotten = {
		modelName = "hayRotten",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.hayRotten.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	hayBed = {
		modelName = "hayBed",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		ignoreBuildRay = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
		seatTypeIndex = seat.types.bed.index,
		isBed = true,
		nameFunction = bedNameFunction,
		displayCoveredStatus = true,
		disallowAnyCollisionsOnPlacement = true,
		bedComfort = 1.0,
		decalBlockRadius2 = mj:mToP(1.2) * mj:mToP(1.2),
		windDestructableLowChance = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	build_hayBed = {
		modelName = "hayBed",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBed = true,
		inProgressWalkable = true,
		displayCoveredStatus = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		windDestructableLowChance = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	woolskinBed = {
		modelName = "woolskinBed",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		ignoreBuildRay = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
		seatTypeIndex = seat.types.bed.index,
		isBed = true,
		nameFunction = bedNameFunction,
		isWarmBed = true,
		displayCoveredStatus = true,
		disallowAnyCollisionsOnPlacement = true,
		bedComfort = 1.0,
		decalBlockRadius2 = mj:mToP(1.2) * mj:mToP(1.2),
		windDestructableLowChance = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	build_woolskinBed = {
		modelName = "woolskinBed",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBed = true,
		inProgressWalkable = true,
		displayCoveredStatus = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		windDestructableLowChance = true,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	grass = {
		modelName = "greenHay",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.grass.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, vec3(0.0, 1.0, 0.0))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	flaxDried = {
		modelName = "flaxDried",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.flaxDried.index,

		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, vec3(0.0, 1.0, 0.0))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	build_craftArea = {
		modelName = "craftArea",
		scale = 1.0,
		hasPhysics = true,
		preventGrassAndSnow = true,
		inProgressWalkable = true,
		--ignoreBuildRay = true,
		femaleSnapPoints = snapGroup.femalePoints.onFloor2x2FemaleSnapPoints,
		iconOverrideIconModelName = "icon_craft",
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	craftArea = {
		modelName = "craftArea",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		preventGrassAndSnow = true,
		--renderTypeOverride = RENDER_TYPE_STATIC_TRANSPARENT_BUILD,
		isCraftArea = true,
		craftAreaGroupTypeIndex = craftAreaGroup.types.standard.index,
		isInvalidRainCover = true,
		disallowAnyCollisionsOnPlacement = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor2x2FemaleSnapPoints,
		iconOverrideIconModelName = "icon_craft",
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	build_storageArea = {
		modelName = "storageArea",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		preventGrassAndSnow = true,
		displayCoveredStatus = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor2x2FemaleSnapPoints,
		iconOverrideIconModelName = "icon_store",
		isInProgressBuildObject = true,
		buildRequiresNoResources = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	storageArea = {
		modelName = "storageArea",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions["2x2"].index,
		storageAreaShiftObjectsToGroundLevel = true,
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor2x2FemaleSnapPoints,
		iconIsUniquePerObject = true,
		iconOverrideIconModelName = "icon_store",
		iconOverrideFunction = storageIconOverrideFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		nameFunction = storageNameFunction,
		buildRequiresNoResources = true,
	},
	build_storageArea1x1 = {
		modelName = "storageArea1x1",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		preventGrassAndSnow = true,
		displayCoveredStatus = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor1x1FemaleSnapPoints,
		iconOverrideIconModelName = "icon_storeSmall",
		isInProgressBuildObject = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		buildRequiresNoResources = true,
	},
	storageArea1x1 = {
		modelName = "storageArea1x1",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions["1x1"].index,
		storageAreaShiftObjectsToGroundLevel = true,
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor1x1FemaleSnapPoints,
		iconIsUniquePerObject = true,
		iconOverrideIconModelName = "icon_storeSmall",
		iconOverrideFunction = storageIconOverrideFunction,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		buildRequiresNoResources = true,
	},
	build_storageArea4x4 = {
		modelName = "storageArea4x4",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		preventGrassAndSnow = true,
		displayCoveredStatus = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor4x4FemaleSnapPoints,
		iconOverrideIconModelName = "icon_storeLarge",
		isInProgressBuildObject = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		buildRequiresNoResources = true,
	},
	storageArea4x4 = {
		modelName = "storageArea4x4",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions["4x4"].index,
		storageAreaShiftObjectsToGroundLevel = true,
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor4x4FemaleSnapPoints,
		iconIsUniquePerObject = true,
		iconOverrideIconModelName = "icon_storeLarge",
		iconOverrideFunction = storageIconOverrideFunction,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		buildRequiresNoResources = true,
	},
	build_compostBin = {
		modelName = "compostBin",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		preventGrassAndSnow = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor2x2FemaleSnapPoints,
		--iconOverrideIconModelName = "icon_plant",
		isInProgressBuildObject = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	compostBin = {
		modelName = "compostBin",
		scale = 1.0,
		hasPhysics = true,
		--ignoreBuildRay = true,
		isBuiltObject = true,
		--isStorageArea = true,
		isInvalidRainCover = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.onFloor2x2FemaleSnapPoints,
		--iconOverrideIconModelName = "icon_plant", --todo show compost
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		extraStatusTextFunction = function(object, default)
			return compostBin:getCompostUIInfoText(object)
		end,
	},
	temporaryCraftArea = {
		modelName = "temporaryCraftArea",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isCraftArea = true,
		isInvalidRainCover = true,
		iconOverrideIconModelName = "icon_craft",
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	deadChicken = {
		modelName = "chickenDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.deadChicken.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	deadChickenRotten = {
		modelName = "chickenDeadRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.deadChickenRotten.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	chickenMeat = {
		modelName = "chickenMeat",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.chickenMeat.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	chickenMeatBreast = {
		modelName = "chickenMeatBreast",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.chickenMeat.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	chickenMeatCooked = {
		modelName = "chickenMeatCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.chickenMeatCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	chickenMeatBreastCooked = {
		modelName = "chickenMeatBreastCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.chickenMeatCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	pumpkinCooked = {
		modelName = "pumpkinCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.pumpkinCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	beetrootCooked = {
		modelName = "beetrootCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.beetrootCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	deadAlpaca = {
		modelName = "alpacaDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.deadAlpaca.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	alpacaMeatLeg = {
		modelName = "alpacaMeatLeg",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.alpacaMeat.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	alpacaMeatRack = {
		modelName = "alpacaMeatRack",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.alpacaMeat.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	alpacaMeatLegCooked = {
		modelName = "alpacaMeatLegCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.alpacaMeatCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	alpacaMeatRackCooked = {
		modelName = "alpacaMeatRackCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.alpacaMeatCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	alpacaWoolskin = {
		modelName = "alpacaWoolskin",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.woolskin.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	catfishDead = {
		modelName = "catfishDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
			gameObject.typeIndexMap.fishBones,
		},
        foodPortionCount = 6, --overrides resource.lua value
	},
	catfishCooked = {
		modelName = "catfishCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
			gameObject.typeIndexMap.fishBones,
		},
        foodPortionCount = 6, --overrides resource.lua value
	},
	coelacanthDead = {
		modelName = "coelacanthDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	coelacanthCooked = {
		modelName = "coelacanthCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	flagellipinnaDead = {
		modelName = "flagellipinnaDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	flagellipinnaCooked = {
		modelName = "flagellipinnaCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	polypterusDead = {
		modelName = "polypterusDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	polypterusCooked = {
		modelName = "polypterusCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	redfishDead = {
		modelName = "redfishDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	redfishCooked = {
		modelName = "redfishCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	tropicalfishDead = {
		modelName = "tropicalfishDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	tropicalfishCooked = {
		modelName = "tropicalfishCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.fishBones,
		},
	},
	swordfishDead = {
		modelName = "swordfishDead",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.swordfishDead.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	fishFillet = {
		modelName = "fillet",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fish.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	fishFilletCooked = {
		modelName = "filletCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.fishCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	bone = {
		modelName = "bone",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.bone.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	fishBones = {
		modelName = "fishBones",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.bone.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	deadMammoth = {
		modelName = "mammothDead",
		harvestableTypeIndex = harvestable.typeIndexMap.mammoth,
		scale = 1.0,
		hasPhysics = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(3.0), 0.0)
			}
		},
	},
	mammothMeat = {
		modelName = "mammothMeat",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.mammothMeat.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	mammothMeatTBone = {
		modelName = "mammothMeatTBone",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.mammothMeat.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	mammothMeatCooked= {
		modelName = "mammothMeatCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.mammothMeatCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	mammothMeatTBoneCooked = {
		modelName = "mammothMeatTBoneCooked",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.mammothMeatCooked.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		eatByProducts = {
			gameObject.typeIndexMap.bone,
		},
	},
	mammothWoolskin = {
		modelName = "mammothWoolskin",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.woolskin.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},

	unfiredUrnWet = {
		modelName = "unfiredUrnWet",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.unfiredUrnWet.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	unfiredUrnDry = {
		modelName = "unfiredUrn",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.unfiredUrnDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	firedUrn = {
		modelName = "firedUrn",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedUrn.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	unfiredUrnHulledWheat = {
		modelName = "unfiredUrnWheat",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.unfiredUrnHulledWheat.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	unfiredUrnHulledWheatRotten = {
		modelName = "unfiredUrnWheatRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.unfiredUrnHulledWheatRotten.index,
		compostByProducts = {
			gameObject.typeIndexMap.unfiredUrnDry,
		},
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	firedUrnHulledWheat = {
		modelName = "firedUrnWheat",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedUrnHulledWheat.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	firedUrnHulledWheatRotten = {
		modelName = "firedUrnWheatRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.firedUrnHulledWheatRotten.index,
		compostByProducts = {
			gameObject.typeIndexMap.firedUrn,
		},
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	unfiredUrnFlour = {
		modelName = "unfiredUrnFlour",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.unfiredUrnFlour.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	unfiredUrnFlourRotten = {
		modelName = "unfiredUrnFlourRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.unfiredUrnFlourRotten.index,
		compostByProducts = {
			gameObject.typeIndexMap.unfiredUrnDry,
		},
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	firedUrnFlour = {
		modelName = "firedUrnFlour",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedUrnFlour.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	firedUrnFlourRotten = {
		modelName = "firedUrnFlourRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.firedUrnFlourRotten.index,
		compostByProducts = {
			gameObject.typeIndexMap.firedUrn,
		},
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},


	unfiredBowlWet = {
		modelName = "unfiredBowlWet",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.unfiredBowlWet.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	unfiredBowlDry = {
		modelName = "unfiredBowl",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.unfiredBowlDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	
	firedBowl = {
		modelName = "firedBowl",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedBowl.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	
	unfiredBowlInjuryMedicine = {
		modelName = "unfiredBowlInjuryMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.unfiredBowlInjuryMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.unfiredBowlDry,
		},
	},
	unfiredBowlBurnMedicine = {
		modelName = "unfiredBowlBurnMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.unfiredBowlBurnMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.unfiredBowlDry,
		},
	},
	unfiredBowlFoodPoisoningMedicine = {
		modelName = "unfiredBowlFoodPoisoningMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.unfiredBowlFoodPoisoningMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.unfiredBowlDry,
		},
	},
	unfiredBowlVirusMedicine = {
		modelName = "unfiredBowlVirusMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.unfiredBowlVirusMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.unfiredBowlDry,
		},
	},

	firedBowlInjuryMedicine = {
		modelName = "firedBowlInjuryMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.firedBowlInjuryMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.firedBowl,
		},
	},
	firedBowlBurnMedicine = {
		modelName = "firedBowlBurnMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.firedBowlBurnMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.firedBowl,
		},
	},
	firedBowlFoodPoisoningMedicine = {
		modelName = "firedBowlFoodPoisoningMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.firedBowlFoodPoisoningMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.firedBowl,
		},
	},
	firedBowlVirusMedicine = {
		modelName = "firedBowlVirusMedicine",
		scale = 1.0,
		hasPhysics = true,
		isMedicine = true,
		
		resourceTypeIndex = resource.types.firedBowlVirusMedicine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		usageByProducts = {
			gameObject.typeIndexMap.firedBowl,
		},
	},

	unfiredBowlMedicineRotten = {
		modelName = "unfiredBowlMedicineRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.unfiredBowlMedicineRotten.index,
		compostByProducts = {
			gameObject.typeIndexMap.unfiredBowlDry,
		},
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	firedBowlMedicineRotten = {
		modelName = "firedBowlMedicineRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.firedBowlMedicineRotten.index,
		compostByProducts = {
			gameObject.typeIndexMap.firedBowl,
		},
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},

	


	crucibleWet = {
		modelName = "unfiredCrucibleWet",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.crucibleWet.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
	},
	crucibleDry = {
		modelName = "unfiredCrucible",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.crucibleDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.3), 0.0)
			}
		},
		
		toolUsages = {
			[tool.types.crucible.index] = {
				[tool.propertyTypes.speed.index] = 1.0,
				[tool.propertyTypes.durability.index] = 1.0,
			},
		},
	},
	
	splitLogBench = {
		modelName = "splitLogBench",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		seatTypeIndex = seat.types.bench.index,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
		isBuiltObject = true,
		isPathFindingCollider = true,
		sapienLookAtOffset = vec3(0.0,mj:mToP(0.5),0.0),
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
	},
	build_splitLogBench = {
		modelName = "splitLogBench",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBuildObject = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		}
	},

	
	splitLogShelf = {
		modelName = "splitLogShelf",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions.shelf.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
		
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		iconIsUniquePerObject = true,
		iconOverrideFunction = storageIconOverrideFunction,
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
	},
	build_splitLogShelf = {
		modelName = "splitLogShelf",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		}
	},

	
	splitLogToolRack = {
		modelName = "splitLogToolRack",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions.toolRack.index,
		storageAreaWhitelistType = storage.whitelistTypes.toolRack,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		},
		
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		femaleSnapPoints = snapGroup.femalePoints.toolRackFemaleSnapPoints,
		iconIsUniquePerObject = true,
		iconOverrideFunction = storageIconOverrideFunction,
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
	},
	build_splitLogToolRack = {
		modelName = "splitLogToolRack",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		femaleSnapPoints = snapGroup.femalePoints.toolRackFemaleSnapPoints,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			}
		}
	},

	

	
	sled = {
		modelName = "sled",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		excludeFromClientCache = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions.sled.index,
		isMoveableStorage = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), 0.0)
			}
		},

		additionalSelectionGroupTypeIndexes = {
			selectionGroup.types.allSleds.index
		},
		
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		iconIsUniquePerObject = true,
		iconOverrideFunction = storageIconOverrideFunction,
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		keepLoadedOnClient = true,
	},
	build_sled = {
		modelName = "sled",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		}
	},

	coveredSled = {
		modelName = "coveredSled",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		excludeFromClientCache = true,
		isStorageArea = true,
		alwaysTreatAsCoveredInside = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions.sled.index,
		isMoveableStorage = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), 0.0)
			}
		},

		additionalSelectionGroupTypeIndexes = {
			selectionGroup.types.allSleds.index
		},
		
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		iconIsUniquePerObject = true,
		iconOverrideFunction = storageIconOverrideFunction,
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		keepLoadedOnClient = true,
	},
	build_coveredSled = {
		modelName = "coveredSled",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		}
	},


	canoe = {
		modelName = "canoe",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		excludeFromClientCache = true,
		isStorageArea = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions.canoe.index,
		isMoveableStorage = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), 0.0)
			}
		},

		additionalSelectionGroupTypeIndexes = {
			selectionGroup.types.allCanoes.index
		},
		
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		iconIsUniquePerObject = true,
		iconOverrideFunction = storageIconOverrideFunction,
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		keepLoadedOnClient = true,
		rideWaterPathFindingDifficulty = pathFinding.pathNodeDifficulties.rideCanoe.index,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
		seatTypeIndex = seat.types.canoe.index,
	},
	build_canoe = {
		modelName = "canoe",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		}
	},

	coveredCanoe = {
		modelName = "coveredCanoe",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isBuiltObject = true,
		isPathFindingCollider = true,
		disallowAnyCollisionsOnPlacement = true,
		excludeFromClientCache = true,
		isStorageArea = true,
		alwaysTreatAsCoveredInside = true,
		storageAreaDistributionTypeIndex = storage.areaDistributions.canoe.index,
		isMoveableStorage = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), 0.0)
			}
		},

		additionalSelectionGroupTypeIndexes = {
			selectionGroup.types.allCanoes.index
		},
		
		displayCoveredStatus = true,
		isInvalidRainCover = true,
		allowsPathsThroughWithDifficultyOverride = pathFinding.pathNodeDifficulties.careful.index,
		iconIsUniquePerObject = true,
		iconOverrideFunction = storageIconOverrideFunction,
		nameFunction = storageNameFunction,
		iconGameObjectTypeFunction = storageIconGameObjectTypeFunction,
		keepLoadedOnClient = true,
		rideWaterPathFindingDifficulty = pathFinding.pathNodeDifficulties.rideCanoe.index,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.careful.index,
		seatTypeIndex = seat.types.canoe.index,
	},
	build_coveredCanoe = {
		modelName = "coveredCanoe",
		scale = 1.0,
		hasPhysics = true,
		ignoreBuildRay = true,
		isInProgressBuildObject = true,
		disallowAnyCollisionsOnPlacement = true,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		}
	},
	
	flaxTwine = {
		modelName = "flaxTwine",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.flaxTwine.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},

	breadDough = {
		modelName = "breadDough",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.breadDough.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	breadDoughRotten = {
		modelName = "breadDoughRotten",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.breadDoughRotten.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	flatbread = {
		modelName = "flatbread",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.flatbread.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	flatbreadRotten = {
		modelName = "flatbreadRotten",
		scale = 1.0,
		hasPhysics = true,
		resourceTypeIndex = resource.types.flatbreadRotten.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.1, vec3(1.0, 0.0, 0.0))
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	
	manure = {
		modelName = "manure",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.manure.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	manureRotten = {
		modelName = "manureRotten",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.manureRotten.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	compost = {
		modelName = "compost",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.compost.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	compostRotten = {
		modelName = "compostRotten",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.compostRotten.index,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.8, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewCameraOffsetFunction = function(object)
			return vec3(0.0,0.5,1.5)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},
	
	rottenGoo = {
		modelName = "rottenGoo",
		scale = 1.0,
		hasPhysics = true,
		allowsAnyInitialRotation = true,
		resourceTypeIndex = resource.types.rottenGoo.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			}
		},
	},

	mudBrickWet_sand = {
		modelName = "mudBrickWet_sand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickWet.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickWet_hay = {
		modelName = "mudBrickWet_hay",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickWet.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickWet_riverSand = {
		modelName = "mudBrickWet_riverSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickWet.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickWet_redSand = {
		modelName = "mudBrickWet_redSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickWet.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickDry_sand = {
		modelName = "mudBrickDry_sand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickDry_hay = {
		modelName = "mudBrickDry_hay",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickDry_riverSand = {
		modelName = "mudBrickDry_riverSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickDry_redSand = {
		modelName = "mudBrickDry_redSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudBrickDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudBrickWall = {
		modelName = "mudBrickWall",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_mudBrickWall = {
		modelName = "mudBrickWall",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	mudBrickWallDoor = {
		modelName = "mudBrickWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_mudBrickWallDoor = {
		modelName = "mudBrickWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	mudBrickWallLargeWindow = {
		modelName = "mudBrickWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_mudBrickWallLargeWindow = {
		modelName = "mudBrickWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	mudBrickRoofEnd = {
		modelName = "mudBrickRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_mudBrickRoofEnd = {
		modelName = "mudBrickRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	mudBrickWall4x1 = {
		modelName = "mudBrickWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_mudBrickWall4x1 = {
		modelName = "mudBrickWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	mudBrickWall2x2 = {
		modelName = "mudBrickWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_mudBrickWall2x2 = {
		modelName = "mudBrickWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	mudBrickWall2x1 = {
		modelName = "mudBrickWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_mudBrickWall2x1 = {
		modelName = "mudBrickWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	mudBrickColumn = {
		modelName = "mudBrickColumn",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		femaleSnapPoints = snapGroup.femalePoints.verticalColumnFemaleSnapPoints,
		isPathFindingCollider = true,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), mj:mToP(0.2))
			}
		},
	},
	build_mudBrickColumn = {
		modelName = "mudBrickColumn",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		femaleSnapPoints = snapGroup.femalePoints.verticalColumnFemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), mj:mToP(0.2))
			}
		},
	},
	mudBrickFloor1x1 = {
		modelName = "mudBrickFloor1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor1x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_mudBrickFloor1x1 = {
		modelName = "mudBrickFloor1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floor1x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	mudBrickFloor2x2 = {
		modelName = "mudBrickFloor2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_mudBrickFloor2x2 = {
		modelName = "mudBrickFloor2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floor2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	mudBrickFloor4x4 = {
		modelName = "mudBrickFloor4x4",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		decalBlockRadius2 = mj:mToP(4.4) * mj:mToP(4.4),
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor4x4FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_mudBrickFloor4x4 = {
		modelName = "mudBrickFloor4x4",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.floor4x4FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	mudBrickFloorTri2 = {
		modelName = "mudBrickFloorTri2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floorTri2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_mudBrickFloorTri2 = {
		modelName = "mudBrickFloorTri2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floorTri2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	mudBrickFoundation1x1 = {
		modelName = "mudBrickFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_mudBrickFoundation1x1 = {
		modelName = "mudBrickFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	mudBrickFoundation2x2 = {
		modelName = "mudBrickFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_mudBrickFoundation2x2 = {
		modelName = "mudBrickFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		rainDestructableLowChance = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	
	stoneBlockWall = {
		modelName = "stoneBlockWall",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_stoneBlockWall = {
		modelName = "stoneBlockWall",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	stoneBlockWallDoor = {
		modelName = "stoneBlockWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_stoneBlockWallDoor = {
		modelName = "stoneBlockWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},

	stoneBlockWallLargeWindow = {
		modelName = "stoneBlockWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_stoneBlockWallLargeWindow = {
		modelName = "stoneBlockWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	stoneBlockRoofEnd = {
		modelName = "stoneBlockRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_stoneBlockRoofEnd = {
		modelName = "stoneBlockRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	stoneBlockWall4x1 = {
		modelName = "stoneBlockWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_stoneBlockWall4x1 = {
		modelName = "stoneBlockWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	stoneBlockWall2x2 = {
		modelName = "stoneBlockWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_stoneBlockWall2x2 = {
		modelName = "stoneBlockWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},

	stoneBlockWall2x1 = {
		modelName = "stoneBlockWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_stoneBlockWall2x1 = {
		modelName = "stoneBlockWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},

	stoneBlockFoundation1x1 = {
		modelName = "stoneBlockFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_stoneBlockFoundation1x1 = {
		modelName = "stoneBlockFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	stoneBlockFoundation2x2 = {
		modelName = "stoneBlockFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_stoneBlockFoundation2x2 = {
		modelName = "stoneBlockFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	stoneBlockColumn = {
		modelName = "stoneBlockColumn",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		femaleSnapPoints = snapGroup.femalePoints.verticalColumnFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), mj:mToP(0.2))
			}
		},
	},
	build_stoneBlockColumn = {
		modelName = "stoneBlockColumn",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		femaleSnapPoints = snapGroup.femalePoints.verticalColumnFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(1.0), mj:mToP(0.2))
			}
		},
	},
	
	brickWall = {
		modelName = "brickWall",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_brickWall = {
		modelName = "brickWall",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	brickWallDoor = {
		modelName = "brickWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_brickWallDoor = {
		modelName = "brickWallDoor",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	brickWallLargeWindow = {
		modelName = "brickWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_brickWallLargeWindow = {
		modelName = "brickWallLargeWindow",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.standardWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	brickRoofEnd = {
		modelName = "brickRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_brickRoofEnd = {
		modelName = "brickRoofEnd",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofEndWallFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	brickWall4x1 = {
		modelName = "brickWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_brickWall4x1 = {
		modelName = "brickWall4x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.shortWall4x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	
	brickWall2x2 = {
		modelName = "brickWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},
	build_brickWall2x2 = {
		modelName = "brickWall2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x2,
	},

	brickWall2x1 = {
		modelName = "brickWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		isPathFindingCollider = true,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},
	build_brickWall2x1 = {
		modelName = "brickWall2x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.wall2x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(-0.5,0.0,1.0)
		end,
		markerPositions = markerPositions.wall4x1,
	},

	brickFoundation1x1 = {
		modelName = "brickFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_brickFoundation1x1 = {
		modelName = "brickFoundation1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	brickFoundation2x2 = {
		modelName = "brickFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_brickFoundation2x2 = {
		modelName = "brickFoundation2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.foundation2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},

	tileFloor1x1 = {
		modelName = "tileFloor1x1",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_tileFloor1x1 = {
		modelName = "tileFloor1x1",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floor1x1FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	tileFloor2x2 = {
		modelName = "tileFloor2x2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_tileFloor2x2 = {
		modelName = "tileFloor2x2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floor2x2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	tileFloor4x4 = {
		modelName = "tileFloor4x4",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		decalBlockRadius2 = mj:mToP(4.4) * mj:mToP(4.4),
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floor4x4FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_tileFloor4x4 = {
		modelName = "tileFloor4x4",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.floor4x4FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	tileFloorTri2 = {
		modelName = "tileFloorTri2",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		pathFindingDifficulty = pathFinding.pathNodeDifficulties.fastPath.index,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.floorTri2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	build_tileFloorTri2 = {
		modelName = "tileFloorTri2",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		inProgressWalkable = true,
		preventGrassAndSnow = true,
		decalBlockRadius2 = mj:mToP(2.2) * mj:mToP(2.2),
		femaleSnapPoints = snapGroup.femalePoints.floorTri2FemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.2), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.2), 0.0)
			}
		},
	},
	tileRoof = {
		modelName = "tileRoof",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_tileRoof = {
		modelName = "tileRoof",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	tileRoofSlope = {
		modelName = "tileRoofSlope",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSlopeFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_tileRoofSlope = {
		modelName = "tileRoofSlope",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSlopeFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	tileRoofSmallCorner = {
		modelName = "tileRoofSmallCorner",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_tileRoofSmallCorner = {
		modelName = "tileRoofSmallCorner",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	tileRoofSmallCornerInside = {
		modelName = "tileRoofSmallCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallInnerCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_tileRoofSmallCornerInside = {
		modelName = "tileRoofSmallCornerInside",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofSmallInnerCornerFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	tileRoofTriangle = {
		modelName = "tileRoofTriangle",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_tileRoofTriangle = {
		modelName = "tileRoofTriangle",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},

	
	tileRoofInvertedTriangle = {
		modelName = "tileRoofInvertedTriangle",
		scale = 1.0,
		hasPhysics = true,
		isBuiltObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		isPathFindingCollider = true,
		blocksRain = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	build_tileRoofInvertedTriangle = {
		modelName = "tileRoofInvertedTriangle",
		scale = 1.0,
		hasPhysics = true,
		isInProgressBuildObject = true,
		preventShiftOnTerrainSurfaceModification = true,
		preventGrassAndSnow = true,
		femaleSnapPoints = snapGroup.femalePoints.roofTriangleFemaleSnapPoints,
		objectViewRotationFunction = function(object) 
			return mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))
		end,
		objectViewOffsetFunction = function(object)
			return vec3(0.5,-1.5,1.0)--vec3xMat3(vec3(-0.5,-1.5,1.0), mat3Inverse(mat3Rotate(mat3Identity, 0.5, normalize(vec3(0.0, 1.0, 0.0)))))
		end,
		markerPositions = {
			{ 
				localOffset = vec3(0.0, mj:mToP(0.8), 0.0)
			},
			{ 
				localOffset = vec3(0.0, mj:mToP(-0.8), 0.0)
			}
		},
	},
	
	mudTileWet = {
		modelName = "mudTileWet",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudTileWet.index,
		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	mudTileDry = {
		modelName = "mudTileDry",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.mudTileDry.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	firedTile = {
		modelName = "firedTile",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedTile.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	firedBrick_sand = {
		modelName = "firedBrick_sand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedBrick.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	firedBrick_hay = {
		modelName = "firedBrick_hay",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedBrick.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	firedBrick_riverSand = {
		modelName = "firedBrick_riverSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedBrick.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	firedBrick_redSand = {
		modelName = "firedBrick_redSand",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.firedBrick.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
	
	
	bronzeIngot = {
		modelName = "bronzeIngot",
		scale = 1.0,
		hasPhysics = true,
		
		resourceTypeIndex = resource.types.bronzeIngot.index,

		markerPositions = {
			{ 
				worldOffset = vec3(0.0, mj:mToP(0.6), 0.0)
			}
		},
	},
}

gameObject.gameObjectsTable = gameObjectsTable

local function addPlaceableObjects(baseGameObjectType)
	--mj:log("addPlaceableObjects:", baseObject.key)
	local placeTypeName = "place_" .. baseGameObjectType.key
	local placedTypeName = "placed_" ..baseGameObjectType.key

	local resourceType = resource.types[baseGameObjectType.resourceTypeIndex]
	gameObject:addGameObjectsFromTable({
		[placeTypeName] = {
			name = resourceType.name,
			plural = resourceType.plural,
			modelName = baseGameObjectType.modelName,
			scale = baseGameObjectType.scale,
			hasPhysics = true,
			isInProgressBuildObject = true,
			inProgressWalkable = (baseGameObjectType.placedVariantPathFindingDifficulty ~= nil),
			--isNonPlaceCollider = true,
			markerPositions = baseGameObjectType.markerPositions,
			femaleSnapPoints = baseGameObjectType.femaleSnapPoints or baseGameObjectType.placedFemaleSnapPoints,
		},
		[placedTypeName] = {
			name = baseGameObjectType.name,
			plural = baseGameObjectType.plural,
			modelName = baseGameObjectType.modelName,
			scale = baseGameObjectType.scale,
			hasPhysics = true,
			isBuiltObject = true,
			isPathFindingCollider = true,
			blocksRain = true,
			--isNonPlaceCollider = true,
			isPlacedObject = true,
			placeBaseObjectTypeIndex = baseGameObjectType.index,
			pathFindingDifficulty = baseGameObjectType.placedVariantPathFindingDifficulty,
			seatTypeIndex = baseGameObjectType.seatTypeIndex,
			markerPositions = baseGameObjectType.markerPositions,
			femaleSnapPoints = baseGameObjectType.femaleSnapPoints or baseGameObjectType.placedFemaleSnapPoints,
		},
	})

end

function gameObject:getSapienLookAtPointForObject(object)
    if object then
        local pos = object.pos
        local sapienLookAtOffset = gameObject.types[object.objectTypeIndex].sapienLookAtOffset
        if sapienLookAtOffset then
            local rotatedOffset = vec3xMat3(sapienLookAtOffset, mat3Inverse(object.rotation))
            pos = pos + rotatedOffset
		else
			local sapienLookAtOffsetFunction = gameObject.types[object.objectTypeIndex].sapienLookAtOffsetFunction
			if sapienLookAtOffsetFunction then
				local functionResult = sapienLookAtOffsetFunction(object)
                local rotatedOffset = vec3xMat3(functionResult, mat3Inverse(object.rotation))
				pos = pos + rotatedOffset
			end
		end
        return pos
    end

    return nil
end

function gameObject:getObjectTypesForResourceTypeOrGroup(resourceGroupOrTypeIndex) --could possibly return duplicates
	if resource.groups[resourceGroupOrTypeIndex] then
		local gameObjectTypeIndexes = {}
		for k,resourceTypeIndex in ipairs(resource.groups[resourceGroupOrTypeIndex].resourceTypes) do
			gameObjectTypeIndexes = mj:concatTables(gameObjectTypeIndexes, gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex])
		end
		return gameObjectTypeIndexes
	end
	return gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceGroupOrTypeIndex]
end

function gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, resourceObjectTypeBlackListOrNil, resourceObjectTypeWhiteListOrNil)
    local gameObjectTypeIndexes = nil

    if resourceInfo then
        if resourceInfo.group then
            gameObjectTypeIndexes = {}
            for k,resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                gameObjectTypeIndexes = mj:concatTables(gameObjectTypeIndexes, gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex])
            end
        else
            gameObjectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceInfo.type]
        end
    end
	
	if not next(gameObjectTypeIndexes) then
		return nil
	end
    
    local allowedGameObjectTypes = {}

	if resourceObjectTypeBlackListOrNil or resourceObjectTypeWhiteListOrNil then
		for i, objectTypeIndex in ipairs(gameObjectTypeIndexes) do
			if (not resourceObjectTypeBlackListOrNil) or (not resourceObjectTypeBlackListOrNil[objectTypeIndex]) then
				if (not resourceObjectTypeWhiteListOrNil) or (resourceObjectTypeWhiteListOrNil[objectTypeIndex]) then
					table.insert(allowedGameObjectTypes, objectTypeIndex)
				end
			end
		end
	else
		allowedGameObjectTypes = gameObjectTypeIndexes
	end

	if not next(allowedGameObjectTypes) then
		return nil
	end
    
    local function sortByName(a,b)
		local typeA = gameObject.types[a]
		local typeB = gameObject.types[b]
		if typeA.scarcityValue ~= typeB.scarcityValue then
			if typeA.scarcityValue == nil then
				return true
			elseif typeB.scarcityValue == nil then
				return false
			end
			return typeA.scarcityValue < typeB.scarcityValue
		end
        return typeA.plural < typeB.plural
    end

    table.sort(allowedGameObjectTypes, sortByName)

    return allowedGameObjectTypes
end

function gameObject:gameObjectTypesSharingResourceTypesWithGameObjectType(objectTypeIndex)
	local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
	if resourceTypeIndex then
		return gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
	end
	return {objectTypeIndex}
end

function gameObject:objectIsTypeOfTool(objectTypeIndex, requiredToolTypeIndex)
	local toolUsages = gameObject.types[objectTypeIndex].toolUsages
	if toolUsages then
		return toolUsages[requiredToolTypeIndex] ~= nil
	end
	return false
end

function resource:getFoodPortionCount(objectTypeIndex)
	local gameObjectType = gameObject.types[objectTypeIndex]
	return gameObjectType.foodPortionCount or resource.types[gameObjectType.resourceTypeIndex].foodPortionCount
end

function gameObject:getDefaultBlockLists(fuel)
    local blockLists = {
		eatFoodList = {},
		fuelLists = {},
	}
	local eatFoodList = blockLists.eatFoodList
	local fuelLists = blockLists.fuelLists
    
    for i,resourceType in ipairs(resource.validTypes) do
        if resourceType.defaultToEatingDisabled then
			local resourceObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceType.index]
			for j,objectTypeIndex in ipairs(resourceObjectTypes) do
				eatFoodList[objectTypeIndex] = true
			end
        end

		if resourceType.defaultToFuelDisabled then
			
			local fuelGroups = fuel.fuelGroupsByFuelResourceTypes[resourceType.index]
			if fuelGroups then
				local resourceObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceType.index]
				for j,fuelGroup in ipairs(fuelGroups) do
					for k,resourceObjectTypeIndex in ipairs(resourceObjectTypes) do
						local fuelBlockList = fuelLists[fuelGroup.index]
						if not fuelBlockList then
							fuelBlockList = {}
							fuelLists[fuelGroup.index] = fuelBlockList
						end
						fuelBlockList[resourceObjectTypeIndex] = true
					end
				end
			end
		end
    end

	return blockLists

end

function gameObject:getDisplayName(object)
	local gameObjectType = gameObject.types[object.objectTypeIndex]

	local name = gameObjectType.name
	if object.sharedState and object.sharedState.name then
		name = object.sharedState.name
	end

	if gameObjectType.nameFunction then
		return gameObjectType.nameFunction(object, name)
	end

	return name
end

function gameObject:getShortDisplayName(object)
	local gameObjectType = gameObject.types[object.objectTypeIndex]

	local name = gameObjectType.name

	if object.sharedState and object.sharedState.name then
		name = object.sharedState.name
	end

	return name
end


function gameObject:addGameObjects()

	for key,gameObjectAdditionInfo in pairs(gameObjectsTable) do
		if not (gameObjectAdditionInfo.name and gameObjectAdditionInfo.plural) then
			local nameKey = "object_" .. key
			local pluralKey = nameKey .. "_plural"
			gameObjectAdditionInfo.name = gameObjectAdditionInfo.name or locale:get(nameKey) or "NO NAME"
			gameObjectAdditionInfo.plural = gameObjectAdditionInfo.plural or locale:get(pluralKey) or "NO NAME"
		end

	end

	gameObject:addGameObjectsFromTable(gameObjectsTable)
	harvestable:load(gameObject)
	rock:addGameObjects(gameObject)
	flora:load(gameObject)
	compostBin:load(gameObject)
	mob:load(gameObject)
	constructable:load(gameObject)
	craftable:load(gameObject, flora)
	notification:load(gameObject, mob)
	pathBuildable:load(gameObject)
	terrainTypes:load(gameObject, buildable)
	research:load(gameObject, constructable, flora)
	skillLearning:load(gameObject)
end

function gameObject:mjInit()
	gameObject:addGameObjects()

	local placeableTypes = {}
	for k,objectTypeIndex in pairs(gameObject.typeIndexMap) do
		local gameObjectType = gameObject.types[objectTypeIndex]
		if gameObjectType and gameObjectType.resourceTypeIndex then
			table.insert(placeableTypes, gameObjectType)
		end

		if not gameObjectType then
			mj:warn("no game object type set for:", k)
		end
	end

	for k,gameObjectType in ipairs(placeableTypes) do
		addPlaceableObjects(gameObjectType)
	end

	for i,resourceType in ipairs(resource.validTypes) do
		buildable:addInfoForPlaceableResource(resourceType, gameObject.types[resourceType.displayGameObjectTypeIndex].modelName, gameObject.types[resourceType.displayGameObjectTypeIndex].key)
	end

	constructable:finalize()

	-- NOTE: No game object types to be added after this point
	--mj:log("No game object types to be added after this point")

	gameObject.validTypes = typeMaps:createValidTypesArray("gameObject", gameObject.types)

	gameObject.gameObjectTypeIndexesByResourceTypeIndex = {}
	gameObject.gameObjectTypeIndexesByToolTypeIndex = {}
	gameObject.inProgressBuildObjectTypes = {}
	gameObject.builtObjectTypes = {}
	gameObject.preservesConstructionObjectsObjectTypes = {}
	gameObject.foodObjectTypes = {}
	gameObject.floraTypes = {}
	gameObject.bedTypes = {}
	gameObject.inProgressBedTypes = {}
	gameObject.craftAreaTypes = {}
	gameObject.seatTypes = {}
	gameObject.burntObjectTypes = {}
	gameObject.placedObjectTypes = {}
	gameObject.pathFindingColliderTypes = {}
	gameObject.pathBuildableTypes = {}
	gameObject.pathInProgressBuildBuildableTypes = {}
	gameObject.clothingTypesByInventoryLocations = {}
	gameObject.musicalInstrumentObjectTypes = {}
	gameObject.medicineObjectTypes = {}
	gameObject.compostableObjectTypes = {}
	gameObject.storageAreaTypes = {}
	gameObject.moveableStorageAreaTypes = {}
	gameObject.automaticAnchorTypes = {}
	gameObject.foodCropTypes = {}
	gameObject.blocksRainTypes = {}
	gameObject.dontCacheObjectTypes = {}

	gameObject.windDestructableHighChanceTypes = {}
	gameObject.windDestructableModerateChanceTypes = {}
	gameObject.windDestructableLowChanceTypes = {}
	gameObject.rainDestructableLowChanceTypes = {}

	for i,gameObjectType in ipairs(gameObject.validTypes) do
		
		
		if gameObjectType.floraTypeIndex then
			table.insert(gameObject.floraTypes, gameObjectType.index)
		end

		if gameObjectType.isPathObject then
			table.insert(gameObject.pathBuildableTypes, gameObjectType.index)
		end
		if gameObjectType.isPathBuildObject then
			table.insert(gameObject.pathInProgressBuildBuildableTypes, gameObjectType.index)
		end
		
		if gameObjectType.isStorageArea then
			table.insert(gameObject.storageAreaTypes, gameObjectType.index)
			if gameObjectType.isMoveableStorage then
				table.insert(gameObject.moveableStorageAreaTypes, gameObjectType.index)
			end
		end

		if gameObjectType.isStorageArea or 
			gameObjectType.isCraftArea or
			gameObjectType.resourceTypeIndex or
			gameObjectType.index == gameObject.types.sapien.index then
				gameObjectType.mayOfferResources = true
		end


		if gameObjectType.isInProgressBuildObject then
			table.insert(gameObject.inProgressBuildObjectTypes, gameObjectType.index)
			table.insert(gameObject.preservesConstructionObjectsObjectTypes, gameObjectType.index)
		elseif gameObjectType.isBuiltObject then
			table.insert(gameObject.builtObjectTypes, gameObjectType.index)
			table.insert(gameObject.preservesConstructionObjectsObjectTypes, gameObjectType.index)
		elseif gameObjectType.preservesConstructionObjects then
			table.insert(gameObject.preservesConstructionObjectsObjectTypes, gameObjectType.index)
		end

		if gameObjectType.isMusicalInstrument then
			table.insert(gameObject.musicalInstrumentObjectTypes, gameObjectType.index)
		end
		

		if gameObjectType.isPlacedObject then
			table.insert(gameObject.placedObjectTypes, gameObjectType.index)
		end


		if gameObjectType.isPathFindingCollider then
			table.insert(gameObject.pathFindingColliderTypes, gameObjectType.index)
		end

		if gameObjectType.resourceTypeIndex then
			if not gameObject.gameObjectTypeIndexesByResourceTypeIndex[gameObjectType.resourceTypeIndex] then
				gameObject.gameObjectTypeIndexesByResourceTypeIndex[gameObjectType.resourceTypeIndex] = {}
			end

			table.insert(gameObject.gameObjectTypeIndexesByResourceTypeIndex[gameObjectType.resourceTypeIndex], gameObjectType.index)

			local resourceType = resource.types[gameObjectType.resourceTypeIndex]

			if resourceType.foodValue then
				table.insert(gameObject.foodObjectTypes, gameObjectType.index)
			end

			if resourceType.clothingInventoryLocation then
				local clothingTypesByThisLocation = gameObject.clothingTypesByInventoryLocations[resourceType.clothingInventoryLocation]
				if not clothingTypesByThisLocation then
					clothingTypesByThisLocation = {}
					gameObject.clothingTypesByInventoryLocations[resourceType.clothingInventoryLocation] = clothingTypesByThisLocation
				end
				table.insert(clothingTypesByThisLocation, gameObjectType.index)
			end

			if resourceType.compostValue then
				table.insert(gameObject.compostableObjectTypes, gameObjectType.index)
			end
			
			if gameObjectType.toolUsages then
				resourceType.isTool = true
			end
		end

		if gameObjectType.baseSelectionGroupTypeIndex then
			selectionGroup:addObjectTypeToGroups(gameObjectType.index, {gameObjectType.baseSelectionGroupTypeIndex})
		end
		
		if gameObjectType.additionalSelectionGroupTypeIndexes then
			selectionGroup:addObjectTypeToGroups(gameObjectType.index, gameObjectType.additionalSelectionGroupTypeIndexes)
		end
		
		if gameObjectType.toolUsages then
			for toolTypeIndex,toolUsageInfo in pairs(gameObjectType.toolUsages) do
				if not gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex] then
					gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex] = {}
				end

				table.insert(gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex], gameObjectType.index)
			end
		end

		
		if gameObjectType.isBed then
			table.insert(gameObject.bedTypes, gameObjectType.index)
		end
		if gameObjectType.isInProgressBed then
			table.insert(gameObject.inProgressBedTypes, gameObjectType.index)
		end
		if gameObjectType.isCraftArea then
			table.insert(gameObject.craftAreaTypes, gameObjectType.index)
		end

		if gameObjectType.windDestructableHighChance then
			table.insert(gameObject.windDestructableHighChanceTypes, gameObjectType.index)
		end
		if gameObjectType.windDestructableModerateChance then
			table.insert(gameObject.windDestructableModerateChanceTypes, gameObjectType.index)
		end
		if gameObjectType.windDestructableLowChance then
			table.insert(gameObject.windDestructableLowChanceTypes, gameObjectType.index)
		end

		if gameObjectType.rainDestructableLowChance then
			table.insert(gameObject.rainDestructableLowChanceTypes, gameObjectType.index)
		end

		if gameObjectType.seatTypeIndex then
			table.insert(gameObject.seatTypes, gameObjectType.index)
		end
		
		if gameObjectType.isBurntObject then
			table.insert(gameObject.burntObjectTypes, gameObjectType.index)
		end
		
		if gameObjectType.isMedicine then
			table.insert(gameObject.medicineObjectTypes, gameObjectType.index)
		end

		if gameObjectType.anchorType then
			table.insert(gameObject.automaticAnchorTypes, gameObjectType.index)
		end

		if gameObjectType.floraTypeIndex then
			if flora.types[gameObjectType.floraTypeIndex].isFoodCrop then
				table.insert(gameObject.foodCropTypes, gameObjectType.index)
			end
		end

		if gameObjectType.blocksRain then
			table.insert(gameObject.blocksRainTypes, gameObjectType.index)
		end

		if gameObjectType.excludeFromClientCache then
			table.insert(gameObject.dontCacheObjectTypes, gameObjectType.index)
		end

	end

	for i,gameObjectType in ipairs(gameObject.validTypes) do
		if gameObjectType.modelName then
			gameObjectType.modelIndex = model:modelIndexForModelNameAndDetailLevel(gameObjectType.modelName, 1)
			if not gameObjectType.modelIndex then
				mj:error("No game object model found:", gameObjectType.modelName, " for object:", gameObjectType.name)
			end
			gameObjectType.modelIndexesByDetail = {
				gameObjectType.modelIndex,
				model:modelIndexForModelNameAndDetailLevel(gameObjectType.modelName, 2),
				model:modelIndexForModelNameAndDetailLevel(gameObjectType.modelName, 3),
				model:modelIndexForModelNameAndDetailLevel(gameObjectType.modelName, 4)
			}
		else
			gameObjectType.modelIndexesByDetail = {}
		end
	end

	physics:setGameObject(gameObject)
	
	constructable:createGameObjectTypeIndexMap(gameObject.gameObjectTypeIndexesByResourceTypeIndex)
	
    --mj:log("gameObject finished loading")

	--[[local function printLocaleTypes()
		local result = {}
		for i,gameObjectType in ipairs(gameObject.validTypes) do
			local localeKey = "object_" .. gameObjectType.key
			local localeKeyPlural = "object_" .. gameObjectType.key .. "Plural"
			table.insert(result,  {
				key = localeKey,
				value = gameObjectType.name
			})
			table.insert(result,  {
				key = localeKeyPlural,
				value = gameObjectType.plural
			})
		end

		mj:log(result)
	end

	printLocaleTypes()]]

	modelPlaceholder:init(gameObject)
	sapienModelComposite:init(gameObject)
	objectSpawner:init(gameObject)
	mob:setupVariants(skillLearning)
	selectionGroup:addMobVariants(gameObject, mob)
end

function gameObject:stringForObjectTypeAndCount(typeIndex, count)
    local gameObjectType = gameObject.types[typeIndex]
    if count == 1 then
        return string.format("%d %s", count, gameObjectType.name)
    end

    return string.format("%d %s", count, gameObjectType.plural)
end

return gameObject