local mjm = mjrequire "common/mjm"
local length = mjm.length

local locale = mjrequire "common/locale"

local material = mjrequire "common/material"
local terrainDecal = mjrequire "common/terrainDecal"
local gameConstants = mjrequire "common/gameConstants"
local pathFinding = mjrequire "common/pathFinding"
local resource = mjrequire "common/resource"

local typeMaps = mjrequire "common/typeMaps"

local terrainTypes = {}

local function createStandardOutputs(objectKeyName, countOrNil)
	local result = {}
	local count = countOrNil or 1
	for i=1,count do
		table.insert(result, {
			objectKeyName = objectKeyName,
			allowsOutputWhenVertexHasBeenFilled = true
		})
	end
	return result
end

local function createRandomExtraOutputForSoil()
	return {
		{
			objectKeyName = "rockSmall",
			chanceFraction = 0.1,
			allowsOutputWhenVertexHasBeenFilled = false,
		},
	}
end


local grassOutputs = createStandardOutputs("grass", 2)
local hayOutputs = createStandardOutputs("hay", 2)

local pathNodeDifficulties = pathFinding.pathNodeDifficulties

terrainTypes.baseTypes = typeMaps:createMap("terrainBase", {
	{
		key = "rock",
		name = locale:get("terrain_rock"),
		material = material.types.terrain_rock.index,
		digOutputs = createStandardOutputs("rock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "rock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("stoneBlock", 2)
	},
	{
		key = "beachSand",
		name = locale:get("terrain_beachSand"),
		material = material.types.terrain_sand.index,
		digOutputs = createStandardOutputs("sand"),
		fillObjectTypeKey = "sand",
		pathDifficultyIndex = pathNodeDifficulties.sand.index,
		reduceSpawn = true,
		fertilizedTerrainTypeKey = "dirt",
	},
	{
		key = "riverSand",
		name = locale:get("terrain_riverSand"),
		material = material.types.terrain_riverSand.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.gravelGrass.index,
		digOutputs = createStandardOutputs("riverSand"),
		fillObjectTypeKey = "riverSand",
		pathDifficultyIndex = pathNodeDifficulties.sand.index,
		reduceSpawn = true,
		fertilizedTerrainTypeKey = "dirt",
	},
	{
		key = "desertSand",
		name = locale:get("terrain_desertSand"),
		material = material.types.terrain_sand.index,
		digOutputs = createStandardOutputs("sand"),
		pathDifficultyIndex = pathNodeDifficulties.sand.index,
		reduceSpawn = true,
		fertilizedTerrainTypeKey = "dirt",
	},
	{
		key = "ice",
		name = locale:get("terrain_ice"),
		material = material.types.snow.index,
		digOutputs = createStandardOutputs("dirt"),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		reduceSpawn = true,
	},
	{
		key = "desertRedSand",
		name = locale:get("terrain_desertRedSand"),
		material = material.types.terrain_desertRedSand.index,
		digOutputs = createStandardOutputs("redSand"),
		fillObjectTypeKey = "redSand",
		pathDifficultyIndex = pathNodeDifficulties.sand.index,
		reduceSpawn = true,
		fertilizedTerrainTypeKey = "dirt",
	},
	{
		key = "redRock",
		name = locale:get("terrain_redRock"),
		material = material.types.terrain_redRock.index,
		digOutputs = createStandardOutputs("redRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "redRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("redRockBlock", 2)
	},
	{
		key = "greenRock",
		name = locale:get("terrain_greenRock"),
		material = material.types.terrain_greenRock.index,
		digOutputs = createStandardOutputs("greenRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "greenRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("greenRockBlock", 2)
	},
	{
		key = "graniteRock",
		name = locale:get("terrain_graniteRock"),
		material = material.types.terrain_graniteRock.index,
		digOutputs = createStandardOutputs("graniteRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "graniteRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("graniteRockBlock", 2)
	},
	{
		key = "marbleRock",
		name = locale:get("terrain_marbleRock"),
		material = material.types.terrain_marbleRock.index,
		digOutputs = createStandardOutputs("marbleRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "marbleRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("marbleRockBlock", 2)
	},
	{
		key = "lapisRock",
		name = locale:get("terrain_lapisRock"),
		material = material.types.terrain_lapisRock.index,
		digOutputs = createStandardOutputs("lapisRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "lapisRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("lapisRockBlock", 2)
	},
	{
		key = "dirt",
		name = locale:get("terrain_dirt"),
		material = material.types.terrain_dirt.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.dirtGrass.index,
		digOutputs = createStandardOutputs("dirt"),
		randomExtraOutputs = createRandomExtraOutputForSoil(),
		fillObjectTypeKey = "dirt",
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fertilizedTerrainTypeKey = "richDirt",
		defertilizedTerrainTypeKey = "poorDirt",
	},
	{
		key = "richDirt",
		name = locale:get("terrain_richDirt"),
		material = material.types.terrain_richDirt.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.dirtGrass.index,
		digOutputs = createStandardOutputs("richDirt"),
		randomExtraOutputs = createRandomExtraOutputForSoil(),
		fillObjectTypeKey = "richDirt",
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		defertilizedTerrainTypeKey = "dirt",
	},
	{
		key = "poorDirt",
		name = locale:get("terrain_poorDirt"),
		material = material.types.terrain_poorDirt.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.dirtGrass.index,
		digOutputs = createStandardOutputs("poorDirt"),
		randomExtraOutputs = createRandomExtraOutputForSoil(),
		fillObjectTypeKey = "poorDirt",
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fertilizedTerrainTypeKey = "dirt",
	},
	{
		key = "limestone",
		name = locale:get("terrain_limestone"),
		material = material.types.terrain_limestone.index,
		digOutputs = createStandardOutputs("limestoneRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "limestoneRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("limestoneRockBlock", 2),
		isSoftRock = true, --allows rock chisels
	},
	{
		key = "clay",
		name = locale:get("terrain_clay"),
		material = material.types.terrain_clay.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.dirtGrass.index,
		digOutputs = createStandardOutputs("clay"),
		fillObjectTypeKey = "clay",
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		disableSpawn = true,
	},
	{
		key = "copperOre",
		name = locale:get("terrain_copperOre"),
		material = material.types.terrain_copperOre.index,
		digOutputs = createStandardOutputs("copperOre", 3),
		fillObjectTypeKey = "copperOre",
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		requiresMining = true,
		disableSpawn = true,
	},
	{
		key = "tinOre",
		name = locale:get("terrain_tinOre"),
		material = material.types.terrain_tinOre.index,
		digOutputs = createStandardOutputs("tinOre", 3),
		fillObjectTypeKey = "tinOre",
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		requiresMining = true,
		disableSpawn = true,
	},
	{
		key = "sandstoneYellowRock",
		name = locale:get("terrain_sandstoneYellowRock"),
		material = material.types.terrain_sandstoneYellowRock.index,
		digOutputs = createStandardOutputs("sandstoneYellowRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "sandstoneYellowRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("sandstoneYellowRockBlock", 2),
		isSoftRock = true, --allows rock chisels
	},
	{
		key = "sandstoneRedRock",
		name = locale:get("terrain_sandstoneRedRock"),
		material = material.types.terrain_sandstoneRedRock.index,
		digOutputs = createStandardOutputs("sandstoneRedRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "sandstoneRedRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("sandstoneRedRockBlock", 2),
		isSoftRock = true, --allows rock chisels
	},
	{
		key = "sandstoneOrangeRock",
		name = locale:get("terrain_sandstoneOrangeRock"),
		material = material.types.terrain_sandstoneOrangeRock.index,
		digOutputs = createStandardOutputs("sandstoneOrangeRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "sandstoneOrangeRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("sandstoneOrangeRockBlock", 2),
		isSoftRock = true, --allows rock chisels
	},
	{
		key = "sandstoneBlueRock",
		name = locale:get("terrain_sandstoneBlueRock"),
		material = material.types.terrain_sandstoneBlueRock.index,
		digOutputs = createStandardOutputs("sandstoneBlueRock", 3),
		pathDifficultyIndex = pathNodeDifficulties.dirtRock.index,
		fillObjectTypeKey = "sandstoneBlueRock",
		requiresMining = true,
		disableSpawn = true,
		chiselOutputs = createStandardOutputs("sandstoneBlueRockBlock", 2),
		isSoftRock = true, --allows rock chisels
	},
})

terrainTypes.variations = typeMaps:createMap("terrainVariations", {
	{
		key = "snow",
		name = locale:get("terrainVariations_snow"),
		material = material.types.snow.index,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.snow.index,
	},
	{
		key = "grassSnow",
		name = locale:get("terrainVariations_grassSnow"),
		material = material.types.grassSnowTerrain.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.grassSnow.index,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.snow.index,
		containsGrassOrHay = true,
	},
	{
		key = "temperateGrassWinter",
		name = locale:get("terrainVariations_grass"),
		material = material.types.temperateGrassWinter.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.grassWinter.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "temperateGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.temperateGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.grass.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "temperateGrassPlentiful",
		name = locale:get("terrainVariations_grass"),
		material = material.types.temperateGrassRich.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.grassDense.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "taigaGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.taigaGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.grass.index,
		digOutputs = hayOutputs,
		clearOutputs = hayOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "mediterraneanGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.mediterraneanGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.mediterraneanGrass.index,
		digOutputs = hayOutputs,
		clearOutputs = hayOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "mediterraneanGrassPlentiful",
		name = locale:get("terrainVariations_grass"),
		material = material.types.mediterraneanGrassPlentiful.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.mediterraneanGrassPlentiful.index,
		digOutputs = hayOutputs,
		clearOutputs = hayOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "steppeGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.steppeGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.steppeGrass.index,
		digOutputs = hayOutputs,
		clearOutputs = hayOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "tropicalRainforestGrassPlentiful",
		name = locale:get("terrainVariations_grass"),
		material = material.types.tropicalRainforestGrassRich.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.tropicalGrassDense.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "tropicalRainforestGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.tropicalRainforestGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.tropicalGrass.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "savannaGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.savannaGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.savannaGrassPlentiful.index,
		digOutputs = hayOutputs,
		clearOutputs = hayOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "savannaGrassPlentiful",
		name = locale:get("terrainVariations_grass"),
		material = material.types.savannaGrassPlentiful.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.savannaGrassPlentiful.index,
		digOutputs = hayOutputs,
		clearOutputs = hayOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "tundraGrass",
		name = locale:get("terrainVariations_grass"),
		material = material.types.tundraGrass.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.tundraGrass.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "tundraGrassPlentiful",
		name = locale:get("terrainVariations_grass"),
		material = material.types.tundraGrassPlentiful.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.tundraGrass.index,
		digOutputs = grassOutputs,
		clearOutputs = grassOutputs,
		canBeCleared = true,
		pathDifficultyIndex = pathNodeDifficulties.grass.index,
		containsGrassOrHay = true,
	},
	{
		key = "flint",
		name = locale:get("terrainVariations_flint"),
		digOutputs = {
			{
				objectKeyName = "flint",
				allowsOutputWhenVertexHasBeenFilled = false
			}
		},
	},
	{
		key = "clay",
		name = locale:get("terrainVariations_clay"),
	},
	{
		key = "limestone",
		name = locale:get("terrainVariations_limestone"),
	},
	{
		key = "redRock",
		name = locale:get("terrainVariations_redRock"),
	},
	{
		key = "sandstoneYellowRock",
		name = locale:get("terrainVariations_sandstoneYellowRock"),
	},
	{
		key = "sandstoneRedRock",
		name = locale:get("terrainVariations_sandstoneRedRock"),
	},
	{
		key = "sandstoneOrangeRock",
		name = locale:get("terrainVariations_sandstoneOrangeRock"),
	},
	{
		key = "sandstoneBlueRock",
		name = locale:get("terrainVariations_sandstoneBlueRock"),
	},
	{
		key = "greenRock",
		name = locale:get("terrainVariations_greenRock"),
	},
	{
		key = "graniteRock",
		name = locale:get("terrainVariations_graniteRock"),
	},
	{
		key = "marbleRock",
		name = locale:get("terrainVariations_marbleRock"),
	},
	{
		key = "lapisRock",
		name = locale:get("terrainVariations_lapisRock"),
	},
	{
		key = "shallowWater",
		name = locale:get("terrainVariations_shallowWater"),
		pathDifficultyIndex = pathNodeDifficulties.shallowWater.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.oceanGravel.index,
	},
	{
		key = "deepWater",
		name = locale:get("terrainVariations_deepWater"),
		pathDifficultyIndex = pathNodeDifficulties.deepWater.index,
		decalGroupTypeIndex = terrainDecal.groupTypes.oceanGravel.index,
	},
	{
		key = "copperOre",
		name = locale:get("terrainVariations_copperOre"),
	},
	{
		key = "tinOre",
		name = locale:get("terrainVariations_tinOre"),
	},
})

terrainTypes.modifications = typeMaps:createMap("terrainModifications", {
	{
		key = "snowRemoved",
		restoreSeason = gameConstants.seasons.winter,
	},
	{
		key = "vegetationRemoved",
		restoreSeason = gameConstants.seasons.summer,
	},
	{
		key = "vegetationAdded", --not implemeted, left here just in case it's stored somewhere
	},
	{
		key = "preventGrassAndSnow",
	},
})


terrainTypes.baseTypesArray = typeMaps:createValidTypesArray("terrainBase", terrainTypes.baseTypes)
terrainTypes.variationsArray = typeMaps:createValidTypesArray("terrainVariations", terrainTypes.variations)
terrainTypes.modificationsArray = typeMaps:createValidTypesArray("terrainModifications", terrainTypes.modifications)

--mj:log("terrainTypes.baseTypesArray:", terrainTypes.baseTypesArray)

terrainTypes.fertilizableTypesArray = {}
terrainTypes.fertilizableTypesSet = {}

function terrainTypes:load(gameObject, buildable)
	--mj:log("setting game object type indexes in terraintypes.lua")
	for i,baseType in ipairs(terrainTypes.baseTypesArray) do
		if baseType.fillObjectTypeKey then
			baseType.fillObjectTypeIndex = gameObject.typeIndexMap[baseType.fillObjectTypeKey] --this is used by the biome mod
		end

		if baseType.fertilizedTerrainTypeKey then
			table.insert(terrainTypes.fertilizableTypesArray, baseType.index)
			terrainTypes.fertilizableTypesSet[baseType.index] = true
		end
	end
	
	buildable:addInfoForFillResource(resource.types.dirt.index, 1)
	buildable:addInfoForFillResource(resource.types.sand.index, 1)
	buildable:addInfoForFillResource(resource.types.clay.index, 1)
	buildable:addInfoForFillResource(resource.types.copperOre.index, 3)
	buildable:addInfoForFillResource(resource.types.tinOre.index, 3)
	buildable:addInfoForFillResource(resource.types.rock.index, 3)
end

--[[
function terrainTypes:getLookAtName(vertInfo)

	
    local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]
    --local variations = vertInfo.variations
    --mj:log("vertInfo:", vertInfo)
    local altitudeMeters = mj:pToM(length(vertInfo.pos) - 1.0) - 0.5
	local altitudeMetersRounded = nil
	if altitudeMeters > 0 then
		altitudeMetersRounded = math.floor(altitudeMeters + 1.0)
	else
		altitudeMetersRounded = math.ceil(altitudeMeters)
	end
    local altitudeText = string.format(" %dm ", altitudeMetersRounded)

	local name = (terrainBaseType.name or "Terrain") .. altitudeText
	return name
end]]

function terrainTypes:getMultiLookAtName(vertInfos, isForMultiSelectUI)
	if vertInfos then
		local countsByBaseType = {}
		local orderedNames = {}
		for uniqueID, vertInfo in pairs(vertInfos) do
			local baseType = vertInfo.baseType
			if not countsByBaseType[baseType] then
				countsByBaseType[baseType] = 1
				table.insert(orderedNames, {
					baseType = baseType,
					name = terrainTypes.baseTypes[baseType].name
				})
			else
				countsByBaseType[baseType] = countsByBaseType[baseType] + 1
			end
		end

		if orderedNames[1] then
			local function sortByCount(a,b)
				return countsByBaseType[a.baseType] > countsByBaseType[b.baseType]
			end
			table.sort(orderedNames, sortByCount)
			local result = ""
			local first = true
			local hasMultipleLines = false
			for i, typeInfo in ipairs(orderedNames) do
				if not first then
					hasMultipleLines = true
					if isForMultiSelectUI then
						result = result .. "\n"
					else
						result = result .. ", "
					end
				end
				first = false
				result = result .. string.format("%d %s", countsByBaseType[typeInfo.baseType], typeInfo.name)
			end
			return result, hasMultipleLines
		end
	end

	return "Terrain"
end

function terrainTypes:getLookAtName(vertInfo)

	
    local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]
    --local variations = vertInfo.variations
    --mj:log("vertInfo:", vertInfo)
    local altitudeMeters = mj:pToM(length(vertInfo.pos) - 1.0) - 0.5
	local altitudeMetersRounded = nil
	if altitudeMeters > 0 then
		altitudeMetersRounded = math.floor(altitudeMeters + 1.0)
	else
		altitudeMetersRounded = math.ceil(altitudeMeters)
	end
    local altitudeText = string.format(" %dm ", altitudeMetersRounded)

	local baseName = nil
	if terrainBaseType then
		baseName = (terrainBaseType.name or locale:get("ui_name_terrain"))
	else
		mj:error("no terrainBaseType in terrainTypes:getLookAtName for vert:", vertInfo)
		baseName = locale:get("ui_name_terrain")
	end

	local name = baseName .. altitudeText
	--[[if variations then
		local hasPrev = false
		for variationTypeIndex, v in pairs(variations) do
			local variationName = terrainTypes.variations[variationTypeIndex].name
			if hasPrev then
				name = name .. "/"
			else
				name = name .. ": "
			end
			name = name .. variationName
			hasPrev = true
		end
	end]]
	return name
end

return terrainTypes