local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local vec3xMat3 = mjm.vec3xMat3
--local mat3Identity = mjm.mat3Identity
local mat3GetRow = mjm.mat3GetRow
--local cross = mjm.cross
local dot = mjm.dot
local length2 = mjm.length2
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3Rotate = mjm.mat3Rotate
local mat3Inverse = mjm.mat3Inverse
local mat3LookAtInverse = mjm.mat3LookAtInverse

local gameObject = mjrequire "common/gameObject"
local action = mjrequire "common/action"
local serverSeat = mjrequire "server/objects/serverSeat"

local sapienObjectSnapping = {}

local serverGOM = nil

local function seatSnapFunction(object, sapien, orderState, actionTypeIndex)
    --mj:log("seatSnapFunction:", object.sharedState, " sapien:", sapien.uniqueID, " orderState:", orderState)
    local seatNodeIndex = sapien.sharedState.seatNodeIndex
    if seatNodeIndex then
        local seatNodes = serverSeat:getSeatNodes(object)
        if not seatNodes then
            return {
                pos = object.pos,
                rotation = sapien.rotation
            }
        end
        local seatNode = seatNodes[seatNodeIndex]
        local seatPos = seatNode.seatPos

        local rotation = sapien.rotation
        local restrictedDirections = seatNode.restrictedDirections

        if restrictedDirections then
            local closestDir = nil
            local closestDp = -1

            local sapienLookDir = mat3GetRow(rotation, 2)
            if orderState.context and orderState.context.restNearObjectID and orderState.context.restNearObjectID ~= object.uniqueID then
                local interestingObject = serverGOM:getObjectWithID(orderState.context.restNearObjectID)
                if interestingObject then
                    local interestingObjectNormalized = normalize(interestingObject.pos)
                    local seatObjectNormalized = normalize(object.pos)
                    sapienLookDir = normalize(interestingObjectNormalized - seatObjectNormalized)
                end
            end

            for i,dir in ipairs(restrictedDirections) do
                local dp = dot(dir, sapienLookDir)
                if dp > closestDp then
                    closestDir = dir
                    closestDp = dp
                end
            end

            if closestDir then
               -- mj:log("seatSnapFunction closestDir:", closestDir)
                rotation = createUpAlignedRotationMatrix(object.normalizedPos, closestDir)
            end
        end

        return {
            pos = seatPos,
            rotation = rotation
        }
    end

    return {
        pos = object.pos,
        rotation = sapien.rotation
    }
end

local minDistanceVecLength2 = mj:mToP(0.01) * mj:mToP(0.01)

local function offsetByDistance(sapien, object, offsetDistance, useObjectMatrix)
    local direction = nil
    local distanceVec = object.normalizedPos - sapien.normalizedPos
    local distanceVecLength2 = length2(distanceVec)
    if useObjectMatrix then
        direction = -mat3GetRow(object.rotation, 2)
    else
        if distanceVecLength2 > minDistanceVecLength2 then
            local distance = math.sqrt(distanceVecLength2)
            direction = distanceVec / distance
        else
            direction = mat3GetRow(sapien.rotation, 2)
        end
    end
    local rotation = mat3LookAtInverse(direction, sapien.normalizedPos)
    return {
        pos = object.pos - direction * offsetDistance,
        rotation = rotation,
        offsetToWalkableHeight = true,
    }
end

local floraFunctionsByActionTypeIndex = {
    [action.types.chop.index] = function(object, sapien, orderState, actionTypeIndex)
        return offsetByDistance(sapien, object, mj:mToP(1.2), false)
    end,
    [action.types.gather.index] = function(object, sapien, orderState, actionTypeIndex)
        return offsetByDistance(sapien, object, mj:mToP(1.2), false)
    end,
    [action.types.gatherBush.index] = function(object, sapien, orderState, actionTypeIndex)
        return offsetByDistance(sapien, object, mj:mToP(1.1), false)
    end
}

local function floraSnapFunction(object, sapien, orderState, actionTypeIndex)
    local funcByAction = floraFunctionsByActionTypeIndex[actionTypeIndex]
    if funcByAction then
        return funcByAction(object, sapien, orderState, actionTypeIndex)
    end
    return nil
end


sapienObjectSnapping.snapObjectFunctions = {
    [gameObject.types.campfire.index] = function(object, sapien, orderState, actionTypeIndex)
        return offsetByDistance(sapien, object, mj:mToP(1.2), false)
        --[[return {
            pos = object.pos + vec3xMat3(vec3(0.0, 0.0, mj:mToP(1.2)), mat3Inverse(object.rotation)),
            rotation = mat3Rotate(object.rotation, math.pi, vec3(0.0, 1.0, 0.0)),
            offsetToWalkableHeight = true,
        }]]
    end,
    [gameObject.types.brickKiln.index] = function(object, sapien, orderState, actionTypeIndex)
        return offsetByDistance(sapien, object, mj:mToP(1.5), true)
    end,
    [gameObject.types.hayBed.index] = function(object, sapien, orderState, actionTypeIndex) -- also used for woolskinBed, see below
        if actionTypeIndex == action.types.sleep.index then
            local placeholderOffset = serverGOM:getOffsetForPlaceholderInObject(object.uniqueID, "sleep_box")
            return {
                pos = object.pos + placeholderOffset,
                rotation = object.rotation
            }
        elseif actionTypeIndex == action.types.sit.index then
            return seatSnapFunction(object, sapien, orderState, actionTypeIndex)
            --[[local placeholderOffset = serverGOM:getOffsetForPlaceholderInObject(object.uniqueID, "sit_box")
            
            local rotation = object.rotation

            if orderState.context and orderState.context.restNearObjectID and orderState.context.restNearObjectID ~= object.uniqueID then
                local interestingObject = serverGOM:getObjectWithID(orderState.context.restNearObjectID)
                if interestingObject then
                    local interestingObjectNormalized = normalize(interestingObject.pos)
                    local seatObjectNormalized = normalize(object.pos)
                    local direction = normalize(interestingObjectNormalized - seatObjectNormalized)
                    rotation = mat3LookAtInverse(direction, seatObjectNormalized)
                    --mj:log("setting rotation towards interesting object")
                end
            end

            return {
                pos = object.pos + placeholderOffset,
                rotation = rotation
            }]]
        end
        mj:warn("no sapienObjectSnapping implemented for action type:", action.types[actionTypeIndex].key)
        return nil
    end,
    [gameObject.types.craftArea.index] = function(object, sapien, actionTypeIndex)
        return {
            pos = object.pos + vec3xMat3(vec3(0.0, mj:mToP(0.05), mj:mToP(0.3)), mat3Inverse(object.rotation)),
            rotation = mat3Rotate(object.rotation, math.pi, vec3(0.0, 1.0, 0.0))
        }
    end,
    [gameObject.types.deadMammoth.index] = function(object, sapien, actionTypeIndex)
        return {
            pos = object.pos + vec3xMat3(vec3(mj:mToP(1.6), 0.0, 0.0), mat3Inverse(object.rotation)),
            rotation = mat3Rotate(object.rotation, -math.pi * 0.5, vec3(0.0, 1.0, 0.0)),
            offsetToWalkableHeight = true,
        }
    end,
    [gameObject.types.temporaryCraftArea.index] = function(object, sapien, actionTypeIndex)
        --mj:log("sapienObjectSnapping temporaryCraftArea object.rotation:", object.rotation, " pos:", object.pos)
        return {
            pos = object.pos + mat3GetRow(object.rotation, 2) * mj:mToP(0.7),
            rotation = mat3Rotate(object.rotation, math.pi, vec3(0.0, 1.0, 0.0))
        }
    end,
    --[[[gameObject.types.deadAlpaca.index] = function(object, sapien, actionTypeIndex) --these should all get turned into temporary craft areas
        return {
            pos = object.pos + vec3xMat3(vec3(0.0, 0.0, mj:mToP(0.5)), mat3Inverse(object.rotation)),
            rotation = sapien.rotation,
            offsetToWalkableHeight = true,
        }
    end,
    [gameObject.types.deadChicken.index] = function(object, sapien, actionTypeIndex)
        return {
            pos = object.pos + vec3xMat3(vec3(0.0, 0.0, mj:mToP(0.5)), mat3Inverse(object.rotation)),
            rotation = sapien.rotation,
            offsetToWalkableHeight = true,
        }
    end,
    [gameObject.types.swordfishDead.index] = function(object, sapien, actionTypeIndex)
        return {
            pos = object.pos + vec3xMat3(vec3(0.0, 0.0, mj:mToP(0.5)), mat3Inverse(object.rotation)),
            rotation = sapien.rotation,
            offsetToWalkableHeight = true,
        }
    end,]]
}

sapienObjectSnapping.snapObjectFunctions[gameObject.types.build_campfire.index] = sapienObjectSnapping.snapObjectFunctions[gameObject.types.campfire.index]
sapienObjectSnapping.snapObjectFunctions[gameObject.types.build_brickKiln.index] = sapienObjectSnapping.snapObjectFunctions[gameObject.types.brickKiln.index]
sapienObjectSnapping.snapObjectFunctions[gameObject.types.woolskinBed.index] = sapienObjectSnapping.snapObjectFunctions[gameObject.types.hayBed.index]


--[[local logTypeSnapFunction = function(object, sapien, orderState, actionTypeIndex)

    local rotation = object.rotation
    local xAxis = mat3GetRow(object.rotation, 0)
    local worldUp = normalize(object.pos)
    local forward = normalize(cross(worldUp, xAxis))

    if orderState.context and orderState.context.restNearObjectID and orderState.context.restNearObjectID ~= object.uniqueID then
        local interestingObject = serverGOM:getObjectWithID(orderState.context.restNearObjectID)
        if interestingObject then
            local interestingObjectNormalized = normalize(interestingObject.pos)
            local seatObjectNormalized = normalize(object.pos)
            local direction = normalize(interestingObjectNormalized - seatObjectNormalized)

            if dot(direction,forward) < 0.0 then
                forward = -forward
            end
            --mj:log("setting rotation towards interesting object")
        end
    end
    
    rotation = mat3LookAtInverse(forward, worldUp)

    mj:log("snap to log:", object.uniqueID, " sapien:", sapien.uniqueID, " rotation:", rotation, " xAxis:", xAxis, " worldUp:", worldUp, " forward:", forward)

    return {
        pos = object.pos + worldUp * mj:mToP(0.15),
        rotation = rotation
    }
end]]

function sapienObjectSnapping:getSnapInfo(object, sapien, orderState, actionTypeIndex)
    if sapienObjectSnapping.snapObjectFunctions[object.objectTypeIndex] then
        return sapienObjectSnapping.snapObjectFunctions[object.objectTypeIndex](object, sapien, orderState, actionTypeIndex)
    end
end


function sapienObjectSnapping:init(serverGOM_)
    serverGOM = serverGOM_

    for i,gameObjectTypeIndex in ipairs(gameObject.seatTypes) do
        if not sapienObjectSnapping.snapObjectFunctions[gameObjectTypeIndex] then
            sapienObjectSnapping.snapObjectFunctions[gameObjectTypeIndex] = seatSnapFunction
        end
    end
    
    for i,gameObjectTypeIndex in ipairs(gameObject.floraTypes) do
        if not sapienObjectSnapping.snapObjectFunctions[gameObjectTypeIndex] then
            sapienObjectSnapping.snapObjectFunctions[gameObjectTypeIndex] = floraSnapFunction
        end
    end
end

return sapienObjectSnapping