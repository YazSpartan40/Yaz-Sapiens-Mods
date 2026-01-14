local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

local buildable = mjrequire "common/buildable"
local resource = mjrequire "common/resource"
local material = mjrequire "common/material"
local skill = mjrequire "common/skill"
--local model = mjrequire "common/model"
local locale = mjrequire "common/locale"
local pathFinding = mjrequire "common/pathFinding"

local gameObject = nil

local pathBuildable = {}

local decalBlockRadius = mj:mToP(1.2)
local decalBlockRadius2 = decalBlockRadius * decalBlockRadius


pathBuildable.maxDistanceBetweenPathNodes = mj:mToP(4.0) --note this is also hard coded in the pathfinding. if it's changed here, the pathfinding results won't match the connections that you see.

pathBuildable.pathTestOffsets = {
    mj:mToP(vec3(0.45,0.0,0.0)),
    mj:mToP(vec3(-0.45,0.0,0.0)),
    mj:mToP(vec3(0.0,0.0,0.45)),
    mj:mToP(vec3(0.0,0.0,-0.45)),
}


local function addObjectsForPathType(keyBase, 
	modelKeyBase, 
	requiredResourceTypeIndex, 
	requiredResourceGroupIndex, 
	requiredResourceCount, 
	materialTypesByObjectType, 
	defaultGameObjectType, 
	requiredSkilTypeIndex,
	pathFindingDifficultyOrNil)

    local baseObjectKey = "path_" .. keyBase
	local nodeModelName = "pathNode_" .. modelKeyBase
	local subModelNameByObjectTypeIndexFunction = function(objectTypeIndex)
		return "pathNode_" .. gameObject.types[objectTypeIndex].key .. "_small"
	end


	local defaultSubModelName = nodeModelName .. "_small"
    
    local buildObjectKey = "build_" .. baseObjectKey

    local name = locale:get(baseObjectKey)
    local plural = locale:get(baseObjectKey .. "_plural")
	local summary = locale:get("buildable_genericPath_summary")

	local function iconOverrideMaterialRemapTableFunction(resourceObjectTypeBlackListOrNil, resourceObjectTypeWhiteListOrNil)
		local allowedObjectTypes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource({type = requiredResourceTypeIndex, group = requiredResourceGroupIndex}, resourceObjectTypeBlackListOrNil, resourceObjectTypeWhiteListOrNil)
		if allowedObjectTypes then
			for i, allowedType in ipairs(allowedObjectTypes) do
				if allowedType == defaultGameObjectType then
					return {
						default = materialTypesByObjectType[defaultGameObjectType]
					}
				end
			end
			return {
				default = materialTypesByObjectType[allowedObjectTypes[1]]
			}
		else
			return {
				default = materialTypesByObjectType[defaultGameObjectType]
			}
		end
	end

	--mj:log("adding path model:", nodeModelName)

	gameObject:addGameObjectsFromTable({
		[baseObjectKey] = {
			name = name,
			plural = plural,
			modelName = nodeModelName,
			scale = 1.0,
			hasPhysics = true,
			ignoreBuildRay = true,
			isBuiltObject = true,
			pathFindingDifficulty = pathFindingDifficultyOrNil or pathFinding.pathNodeDifficulties.path.index,
			isPathObject = true,
			isNonPlaceCollider = true,
			isPathFindingCollider = true,
			isPathSnappable = true,
			decalBlockRadius2 = decalBlockRadius2,
			iconOverrideIconModelName = "icon_path",
			iconOverrideMaterialRemapTableFunction = iconOverrideMaterialRemapTableFunction,
			markerPositions = {
				{ 
					worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
				}
			},
		},
		[buildObjectKey] = {
			name = name,
			plural = plural,
			modelName = nodeModelName,
			scale = 1.0,
			hasPhysics = false,
			ignoreBuildRay = true,
			isInProgressBuildObject = true,
			inProgressWalkable = true,
			isPathBuildObject = true,
			isNonPlaceCollider = true,
			isPathSnappable = true,
			iconOverrideIconModelName = "icon_path",
			iconOverrideMaterialRemapTableFunction = iconOverrideMaterialRemapTableFunction,
			markerPositions = {
				{ 
					worldOffset = vec3(0.0, mj:mToP(0.2), 0.0)
				}
			},
		},
    })
    
    buildable:addInfoForPathObject(baseObjectKey, name, plural, summary, nodeModelName, defaultSubModelName, subModelNameByObjectTypeIndexFunction, requiredResourceTypeIndex, requiredResourceGroupIndex, requiredResourceCount, requiredSkilTypeIndex)
end

function pathBuildable:load(gameObject_)
    gameObject = gameObject_

	-- to add new path types, add here, model.lua pathNode remap models, and modelPlaceholder remaps, localizations for path_name and path_name_plural, and pathUI itemList. Also need to create a pathNode model

    addObjectsForPathType("dirt", "dirt", resource.types.dirt.index, nil, 1, {
		[gameObject.types.dirt.index] = material.types.dirt.index,
		[gameObject.types.richDirt.index] = material.types.richDirt.index,
		[gameObject.types.poorDirt.index] = material.types.poorDirt.index,
	}, gameObject.types.dirt.index, skill.types.digging.index, pathFinding.pathNodeDifficulties.slowPath.index)

    addObjectsForPathType("sand", "sand", resource.types.sand.index, nil, 1, {
		[gameObject.types.sand.index] = material.types.sand.index,
		[gameObject.types.riverSand.index] = material.types.riverSand.index,
		[gameObject.types.redSand.index] = material.types.redSand.index,
	}, gameObject.types.sand.index, skill.types.digging.index, pathFinding.pathNodeDifficulties.slowPath.index)

    addObjectsForPathType("rock", "rock", nil, resource.groups.rockAny.index, 1, {
		[gameObject.types.rock.index] = material.types.rock.index,
		[gameObject.types.limestoneRock.index] = material.types.limestone.index,
		[gameObject.types.sandstoneYellowRock.index] = material.types.sandstoneYellowRock.index,
		[gameObject.types.sandstoneRedRock.index] = material.types.sandstoneRedRock.index,
		[gameObject.types.sandstoneOrangeRock.index] = material.types.sandstoneOrangeRock.index,
		[gameObject.types.sandstoneBlueRock.index] = material.types.sandstoneBlueRock.index,
		[gameObject.types.redRock.index] = material.types.redRock.index,
		[gameObject.types.greenRock.index] = material.types.greenRock.index,
		[gameObject.types.graniteRock.index] = material.types.graniteRock.index,
		[gameObject.types.marbleRock.index] = material.types.marbleRock.index,
		[gameObject.types.lapisRock.index] = material.types.lapisRock.index,
	}, gameObject.types.rock.index, skill.types.digging.index, pathFinding.pathNodeDifficulties.path.index)

    addObjectsForPathType("clay", "clay", resource.types.clay.index, nil, 1, {
		[gameObject.types.clay.index] = material.types.clay.index,
	}, gameObject.types.clay.index, skill.types.digging.index, pathFinding.pathNodeDifficulties.slowPath.index)

    addObjectsForPathType("tile", "firedTile", resource.types.firedTile.index, nil, 1, {
		[gameObject.types.firedTile.index] = material.types.terracotta.index,
		
        [gameObject.types.stoneTile.index] = material.types.rock.index,
        [gameObject.types.stoneTile_limestone.index] = material.types.limestone.index,
        [gameObject.types.stoneTile_sandstoneYellowRock.index] = material.types.sandstoneYellowRock.index,
        [gameObject.types.stoneTile_sandstoneRedRock.index] = material.types.sandstoneRedRock.index,
        [gameObject.types.stoneTile_sandstoneOrangeRock.index] = material.types.sandstoneOrangeRock.index,
        [gameObject.types.stoneTile_sandstoneBlueRock.index] = material.types.sandstoneBlueRock.index,
        [gameObject.types.stoneTile_redRock.index] = material.types.redRock.index,
        [gameObject.types.stoneTile_greenRock.index] = material.types.greenRock.index,
        [gameObject.types.stoneTile_graniteRock.index] = material.types.graniteRock.index,
        [gameObject.types.stoneTile_marbleRock.index] = material.types.marbleRock.index,
        [gameObject.types.stoneTile_lapisRock.index] = material.types.lapisRock.index,

	}, gameObject.types.firedTile.index, skill.types.tiling.index, pathFinding.pathNodeDifficulties.fastPath.index)
end

pathBuildable.addObjectsForPathType = addObjectsForPathType

return pathBuildable