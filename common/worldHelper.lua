local mjm = mjrequire "common/mjm"
local length = mjm.length
local length2 = mjm.length2
local normalize = mjm.normalize
--local dot = mjm.dot
--local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Inverse = mjm.mat3Inverse
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3GetRow = mjm.mat3GetRow

local terrain = mjrequire "common/terrain"
local physics = mjrequire "common/physics"
local physicsSets = mjrequire "common/physicsSets"
local rng = mjrequire "common/randomNumberGenerator"
local storage = mjrequire "common/storage"

local worldHelper = {}

local gom = nil
local modelPlaceholder = nil

function worldHelper:getBelowSurfacePos(startPos, yStartOffsetMeters, physicsSetOrNil, ignoreObjectIDOrNil, clampToSeaLevel, returnUpVector)
    --local terrainPos = terrain:getLoadedTerrainPointAtPoint(startPos) switched to highest detail to help prevent submodels from being placed at lower detail offsets. There are other better solutions maybe

	local terrainPos = terrain:getHighestDetailTerrainPointAtPoint(startPos)
	local terrainLength2 = length2(terrainPos)
    local wasClampedToSeaLevel = false
	if clampToSeaLevel then
		if terrainLength2 < 1.0 then
            if terrainLength2 < 1.0 - mj:mToP(0.001) then --we have lowest terrain at sea level, actual sea level is slightly lower
                wasClampedToSeaLevel = true
            end
			terrainPos = terrainPos / math.sqrt(terrainLength2)
			terrainLength2 = 1.0
		end
	end

    
    local posLength2 = length2(startPos)
	if posLength2 > terrainLength2 then
		local posLength = math.sqrt(posLength2)
		local posNormal = startPos / posLength
		local rayResult =  physics:rayTest(posNormal * (posLength + mj:mToP(yStartOffsetMeters)), terrainPos, physicsSetOrNil, ignoreObjectIDOrNil)

		if rayResult.hasHitObject then
            if returnUpVector then
                return rayResult.objectCollisionPoint, posNormal, wasClampedToSeaLevel
            end
			return rayResult.objectCollisionPoint, wasClampedToSeaLevel
		end
	end

    if returnUpVector then
        return terrainPos, worldHelper:getWalkableUpVector(startPos), wasClampedToSeaLevel
    end

    return terrainPos, wasClampedToSeaLevel
end

function worldHelper:getWalkableUpVector(startPos) --todo this needs to cast a ray
    return terrain:getHighestDetailTerrainNormalAtPoint(startPos)
end


local maxRayHitDistanceFromDesriedPosition = mj:mToP(0.2)
local maxRayHitDistanceFromDesriedPosition2 = maxRayHitDistanceFromDesriedPosition * maxRayHitDistanceFromDesriedPosition

local seaLevelClampHeight = 1.0 - mj:mToP(0.1)
local seaLevelClampHeight2 = seaLevelClampHeight * seaLevelClampHeight

local seaLevelShiftHeightWhenNoTerrainFound = 1.0 + mj:mToP(0.1)
local seaLevelShiftHeightWhenNoTerrainFound2 = seaLevelShiftHeightWhenNoTerrainFound * seaLevelShiftHeightWhenNoTerrainFound

function worldHelper:getSantizedMoveToPos(moveToPos)
    local moveToPosNormal = normalize(moveToPos)

    local canMove = false
    local rayStart = moveToPos + moveToPosNormal * mj:mToP(1.5)
    local rayEnd = moveToPos - moveToPosNormal * mj:mToP(1.2)
    local rayResult = physics:rayTest(rayStart, rayEnd, physicsSets.walkable, nil)

    if rayResult.hasHitTerrain or rayResult.hasHitObject then
        if rayResult.hasHitObject and length2(rayResult.objectCollisionPoint - moveToPos) > maxRayHitDistanceFromDesriedPosition2 then
            canMove = false
        else
            local newMovePoint = rayResult.terrainCollisionPoint
            if rayResult.hasHitObject then
                newMovePoint = rayResult.objectCollisionPoint
            end
            canMove = true
            local moveToPointLength2 = length2(newMovePoint)
            if moveToPointLength2 < seaLevelClampHeight2 then
                moveToPos = moveToPosNormal * seaLevelClampHeight
            end
        end
    else
        
        local moveToPointLength2 = length2(moveToPos)
        if moveToPointLength2 < seaLevelShiftHeightWhenNoTerrainFound2 then
            canMove = true
            moveToPos = moveToPosNormal * seaLevelClampHeight
        else
            canMove = false
        end

    end

    if canMove then
        return moveToPos
    end

    return nil
end


function worldHelper:seasonIndexForSeasonFraction(posY, seasonFraction, randomSeed)
	if posY < (rng:valueForUniqueID(randomSeed, 23534) - 0.5) * 0.05 then
		seasonFraction = seasonFraction + 0.5
	end
	seasonFraction = math.fmod(seasonFraction + 1.0, 1.0)
	if seasonFraction < 0.125 then
		return 1 --spring
	elseif seasonFraction < 0.375 then
		return 2 --summer
	elseif seasonFraction < 0.625 then
		return 3 --autumn
	elseif seasonFraction < 0.875 then
		return 4 --winter
	end
	return 1 --spring
end

local maxSubModelOffsetDistance = mj:mToP(0.8)
local maxSubModelOffsetDistance2 = maxSubModelOffsetDistance * maxSubModelOffsetDistance

function worldHelper:getSubModelTransformForModel(modelIndex, pos, rotation, scale, placeholderName, parentObjectIDOrNil, resourceTypeIndexOrNil)
    
    local object = nil
    local cachedTransforms = nil

    local result = {
        offsetMeters = vec3(0.0,0.0,0.0),
        rotation = mat3Identity,
    }

    local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndex, placeholderName)

    if not placeholderInfo then
        return result
    end
    

    local function setDefaultOffset()
        result.offsetMeters = gom:getLocalOffsetForPlaceholderInModel(modelIndex, placeholderName)
    end

    local placeholderRotation = gom:getPlaceholderRotationForModel(modelIndex, placeholderName)
    
    local function setDefaultRotation()
        result.rotation = placeholderRotation
    end

    --[[if parentObjectIDOrNil then
        --disabled--mj:objectLog(parentObjectIDOrNil, "worldHelper:getSubModelTransformForModel placeholderName:", placeholderName, " placeholderInfo:", placeholderInfo, " resourceTypeIndexOrNil:", resourceTypeIndexOrNil)
    end]]
    
    if placeholderInfo.offsetToWalkableHeight or placeholderInfo.rotateToWalkableRotation or placeholderInfo.offsetToStorageBoxWalkableHeight then
        
        setDefaultOffset()

        local storageOffsetMeters = vec3(0.0,0.0,0.0)

        if placeholderInfo.offsetToStorageBoxWalkableHeight and resourceTypeIndexOrNil then
            local storageBox = storage:getStorageBoxForResourceType(resourceTypeIndexOrNil)
            if storageBox then
                local storageOffsetBase = storageBox.offset or vec3(0.0,0.0,0.0)
                local storageSize = storageBox.size or vec3(0.0,0.0,0.0)
                local rotatedStorageBox = vec3xMat3(storageSize, mat3Inverse(placeholderRotation)) --maybe should be inverse
                storageOffsetMeters = storageOffsetBase + vec3(0.0, math.abs(rotatedStorageBox.y) * 0.5, 0.0)
                
                --[[if parentObjectIDOrNil == "308b5" then
                    mj:log("result.offsetMeters:", result.offsetMeters)
                    mj:log("localStorageOffsetMeters:", localStorageOffsetMeters)
                end]]
            end
        end
        
        if placeholderInfo.offsetToWalkableHeight or placeholderInfo.offsetToStorageBoxWalkableHeight then
            local objectRotationInverse = mat3Inverse(rotation)
            local additionalYOffset = 0.0
            if placeholderInfo.addModelFileYOffsetToWalkableHeight then
                additionalYOffset = result.offsetMeters.y
            end
            local worldSpaceOffsetMeters = vec3xMat3(result.offsetMeters + storageOffsetMeters, objectRotationInverse)

            local worldPosition = pos + mj:mToP(worldSpaceOffsetMeters)
            local clampToSeaLevel = false
            local ignoreObjectID = parentObjectIDOrNil
            if placeholderInfo.offsetToStorageBoxWalkableHeight then
                ignoreObjectID = nil
            end
            local offsetPosition = worldHelper:getBelowSurfacePos(worldPosition, 0.3, physicsSets.walkableOrInProgressWalkable, ignoreObjectID, clampToSeaLevel)
            if length2(offsetPosition - worldPosition) < maxSubModelOffsetDistance2 then
                local offsetWorldMeters = mj:pToM(offsetPosition - pos)
                local offsetLocalMeters = vec3xMat3(offsetWorldMeters, rotation)
                result.offsetMeters = offsetLocalMeters + storageOffsetMeters + vec3(0.0,additionalYOffset,0.0)
            end
            
            if placeholderInfo.rotateToWalkableRotation then
                --mj:log("placeholderInfo.rotateToWalkableRotation")
                local upVector = worldHelper:getWalkableUpVector(worldPosition)
                result.rotation = mat3Inverse(rotation) * createUpAlignedRotationMatrix(upVector, mat3GetRow(rotation, 2)) * gom:getPlaceholderRotationForModel(modelIndex, placeholderName)
            else
                setDefaultRotation()
            end
        else
            setDefaultRotation()
        end
    else
        setDefaultOffset()
        setDefaultRotation()
    end

    if object and object.subdivLevel == mj.SUBDIVISIONS - 1 then
        if not cachedTransforms[modelIndex] then
            cachedTransforms[modelIndex] = {}
        end
        cachedTransforms[modelIndex][placeholderName] = result
    end
    return result
end

function worldHelper:setGOM(gom_, modelPlaceholder_)
	gom = gom_
	modelPlaceholder = modelPlaceholder_
end


return worldHelper