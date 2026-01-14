
local mjm = mjrequire "common/mjm"
local pointIsLeftOfLine = mjm.pointIsLeftOfLine
local terrainTypesModule = mjrequire "common/terrainTypes"

--local rng = mjrequire "common/randomNumberGenerator"

local bridge = nil

local terrain = {}

--[[
triangles are subdivided like this:

 parentSubdivisionIndex
    b         0 ab-b-bc (top),
  ab  bc      1 ab-bc-ca (center),
 a  ca  c     2 a-ab-ca, (bottom left)
              3 ca-bc-c (bottom right)


triangleIDs and transient object unique IDs are 64bit unsigned integers, like so:

 tri id
 child object id |               subdiv heirachy                  | level | macro index
   00000000      | 1110001010001011001011000110010101011111101000 | 10110 |    00100

Lua doesn't support 64 bit integers, so they are encoded as a string using sprintf(buffer, "%" PRIx64, v );
and back again for the engine using std::stoull(stringValue.substr(0, 16), 0, 16);

ids can freely be treated as strings in Lua, but you must not modify them.

the macro index is the initial icosahedron triangle index (each has a unique id from 0-19), the level stores how many subdivisions have occured. 
Then 2 bits are used for each parentSubdivisionIndex for each level. 8 bits are reserved for 256 transient object ids per triangle
]]


function terrain:setBridge(bridge_)
	bridge = bridge_
end

function terrain:getLoadedTerrainPointAtPoint(point) -- returns an interpolated position within the highest detail currently loaded
	return bridge:getLoadedTerrainPointAtPoint(point)
end

function terrain:getHighestDetailTerrainPointAtPoint(point) -- generates a temp high detail triangle if needed, to return an accurate interpolated position for the highest detail
	return bridge:getHighestDetailTerrainPointAtPoint(point)
end


function terrain:getHighestDetailTerrainNormalAtPoint(point) --as above, generates a temp high detail triangle if needed, so the normal is correct for the highest detail
	return bridge:getTerrainNormalAtPoint(point)
end

function terrain:getRawTerrainDataAtNormalizedPoint(normalizedPoint) --returns a raw value from the SPHeight mod that may not match the rendered result exactly. Altitude is stored in x (0.0 is sea level) and river distance is stored in y
	return bridge:getRawTerrainDataAtNormalizedPoint(normalizedPoint)
end

function terrain:getRiverDistanceAndValueAtNormalizedPoint(normalizedPoint) --vec2 with river distance and river value in x/y. this is faster than a full terrain height lookup, useful for finding nearby rivers
	return bridge:getRiverDistanceAndValueAtNormalizedPoint(normalizedPoint)
end

function terrain:getCloseRiverPointToPoint(normalizedPoint) --returns the closest normalized point on a river, or near to it maybe if I got the math wrong 
	return bridge:getCloseRiverPointToPoint(normalizedPoint)
end

function terrain:getBiomeTagsForNormalizedPoint(normalizedPoint) -- doesn't look up the terrain, instead generates a temporary terrain vertex at this point and uses it to query biomes, so quite expensive
	return bridge:getBiomeTagsForNormalizedPoint(normalizedPoint)
end

function terrain:getRainfallForNormalizedPoint(normalizedPoint)
	return bridge:getRainfallForNormalizedPoint(normalizedPoint)
end

function terrain:getFaceForPoint(point)
	return bridge:getFaceForPoint(point)
end

function terrain:getFaceIDForNormalizedPointAtLevel(point, subdivLevel) --the returned faceID may not actually be a loaded triangle.
	return bridge:getFaceIDForNormalizedPointAtLevel(point, subdivLevel)
end

function terrain:getFacesInArea(a,b,c,d) -- must be given in a clockwise order
	return bridge:getFacesInArea(a,b,c,d)
end

function terrain:retrieveTrianglesWithinRadius(pos, radius, maxLevel) --not perfectly accurate, it only checks if normalized terrain vertices are inside the circle relative to this pos normalized
	if pos and radius then
		return bridge:retrieveTrianglesWithinRadius(pos, radius, maxLevel)
	end
end

function terrain:getFaceForPointWithStartFace(point, startFace, maxLevel) --an optimization if startFace is likely to be close to the end result
return bridge:getFaceForPointWithStartFace(point, startFace, maxLevel)
end

function terrain:terrainTriangleIsFlatAtPoint(point)
	return bridge:terrainFaceIsFlat(bridge:getFaceForPoint(point))
end

function terrain:getFaceWithID(triID)
	return bridge:getFaceWithID(triID)
end

function terrain:getVertWithID(vertID)
	return bridge:getVertWithID(vertID)
end

function terrain:getVertsForMultiSelectAroundID(vertID)
	return bridge:getVertsForMultiSelectAroundID(vertID)
end

function terrain:getVertsForMultiSelectAroundPosition(position)
	return bridge:getVertsForMultiSelectAroundPosition(position)
end

function terrain:getVertIDsWithinRadiusOfVertID(vertID, normalizedPos, radius) --faster than getVertIDsWithinRadiusOfNormalizedPos
	return bridge:getVertIDsWithinRadiusOfVertID(vertID, normalizedPos, radius)
end

function terrain:getVertIDsWithinRadiusOfNormalizedPos(normalizedPos, radius) --slower than getVertIDsWithinRadiusOfVertID
	return bridge:getVertIDsWithinRadiusOfNormalizedPos(normalizedPos, radius)
end

function terrain:getNormalizedCenterForFaceID(triID)
	return bridge:getNormalizedCenterForFaceID(triID)
end

function terrain:getClosestVertIDToPos(position)
	return bridge:getClosestVertIDToPos(position)
end

function terrain:closeVertIDWithinRadiusOfTypes(requiresTerrainBaseTypeIndexes, pos, radius) --returns vertID of first found matching vert, or nil if not found. Roughly closest, not perfect.
	return bridge:closeVertIDWithinRadiusOfTypes(requiresTerrainBaseTypeIndexes, pos, radius)
end

function terrain:closeVertIDWithinRadiusNextToWater(pos, radius) --returns vertID of first found matching vert, or nil if not found. Roughly closest, not perfect.
	return bridge:closeVertIDWithinRadiusNextToWater(pos, radius)
end

function terrain:getVertIDsOfTypesWithinRadius(requiresTerrainBaseTypeIndexes, pos, radius, maxResultCountOrNil) --result will be roughly ordered by distance, but not perfect
	return bridge:getVertIDsOfTypesWithinRadius(requiresTerrainBaseTypeIndexes, pos, radius, maxResultCountOrNil or 0)
end


function terrain:getVertClosestToPointInFace(triID, pointNormal)
	local face = terrain:getFaceWithID(triID)
    if not face then
        mj:warn("face not found in terrain:getVertClosestToPointInFace:" .. mj:tostring(triID))
        return nil
    end

    local verts = { face:getVert(0), face:getVert(1), face:getVert(2)}
    local vertPositions = { verts[1].pos, verts[2].pos, verts[3].pos}

	local closestVertIndex = 1

	local bcCenter = vertPositions[2] + (vertPositions[3] - vertPositions[2]) * 0.5
	if pointIsLeftOfLine(pointNormal, vertPositions[1], bcCenter) then
		local abCenter = vertPositions[1] + (vertPositions[2] - vertPositions[1]) * 0.5
		if pointIsLeftOfLine(pointNormal, vertPositions[3], abCenter) then
			closestVertIndex = 1
		else
			closestVertIndex = 2
		end
	else
		local acCenter = vertPositions[1] + (vertPositions[3] - vertPositions[1]) * 0.5
		if pointIsLeftOfLine(pointNormal, vertPositions[2], acCenter) then
			closestVertIndex = 3
		else
			closestVertIndex = 1
		end
	end

	return verts[closestVertIndex]
end

function terrain:getBiomeTagsForVertWithID(vertID)
	return bridge:getBiomeTagsForVertWithID(vertID)
end

function terrain:getFacesSharingVert(vertID)
	return bridge:getFacesSharingVert(vertID)
end

function terrain:vertNeedsClearedForBuildingPlacement(vertID)
    return (terrain:outputsForClearAtVertex(vertID) ~= nil)
end

function terrain:getNeighborVertsForVert(vertID)
	return bridge:getNeighborVertsForVert(vertID) --returns verts, not vertIDS
end

function terrain:printDebugInfo()
	bridge:printDebugInfo()
end

function terrain:getBaseTemperaturesForPoint(point)
	return bridge:getBaseTemperaturesForPoint(point)
end

function terrain:outputsForClearAtVertex(vertID)
    local vert = bridge:getVertWithID(vertID)
	local terrainTypeIndex = vert.baseType
	local variations = vert:getVariations()

	local outputs = {}
	local foundOutput = false

	local function addOutput(outputInfo)
		table.insert(outputs, outputInfo.objectKeyName)
		foundOutput = true
	end

	local clearOutputs = terrainTypesModule.baseTypes[terrainTypeIndex].clearOutputs
	if clearOutputs then
		for i,outputInfo in ipairs(clearOutputs) do
			addOutput(outputInfo)
		end
	end

	if variations then
		for variationTypeIndex,v in pairs(variations) do
			local variationOutputs = terrainTypesModule.variations[variationTypeIndex].clearOutputs
			if variationOutputs then
				for i,outputInfo in ipairs(variationOutputs) do
					addOutput(outputInfo)
				end
			end
		end
	end

	if foundOutput then
		return outputs
	end
	return nil
end

return terrain