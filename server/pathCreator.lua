
local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local physicsSets = mjrequire "common/physicsSets"
local pathFinding = mjrequire "common/pathFinding"
local actionSequence = mjrequire "common/actionSequence"
local worldHelper = mjrequire "common/worldHelper"
local sapienObjectSnapping = mjrequire "server/sapienObjectSnapping"
local serverSeat = mjrequire "server/objects/serverSeat"


local pathCreator = {}

local bridge = nil
local gameObject = nil
local serverWorld = nil
local serverGOM = nil
local serverSapien = nil


local function createPathInfo(path, startPos, goalPos, skipFirstNode)
    local pathInfo = {
        startPos = startPos,
        goalPos = goalPos
    }

    if path then
        pathInfo.valid = path.valid
        pathInfo.complete = path.complete
        pathInfo.inaccessible = path.inaccessible
        if pathInfo.valid then
            local nodes = {}
            local startIndex = 1
            if skipFirstNode and path.nodeCount > 1 then 
                startIndex = 2
            end
            for i=startIndex,path.nodeCount do
                local node = path:getNode(i - 1)
                local rideObjectID = nil
                if node.rideObjectID and node.rideObjectID ~= "0" then
                    rideObjectID = node.rideObjectID
                end
                table.insert(nodes, {
                    pos = node.pos,
                    difficulty = node.difficulty,
                    rideObjectID = rideObjectID,
                })
            end
            pathInfo.nodes = nodes
        end
    else
        pathInfo.noMovementRequired = true
    end
    return pathInfo
end

local minDistanceToAddFinalSnapNode = mj:mToP(0.3)
local minDistanceToAddFinalSnapNode2 = minDistanceToAddFinalSnapNode * minDistanceToAddFinalSnapNode

local function addFinalSnapNodeIfNeeded(sapien, pathInfo)
    ----disabled--mj:objectLog(sapien.uniqueID, "addFinalSnapNodeIfNeeded a")
    if sapien and pathInfo then
        ----disabled--mj:objectLog(sapien.uniqueID, "addFinalSnapNodeIfNeeded b")
        local orderQueue = sapien.sharedState.orderQueue
        local orderState = orderQueue[1]
        if orderState and orderState.objectID then
            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            ----disabled--mj:objectLog(sapien.uniqueID, "addFinalSnapNodeIfNeeded g")
            if orderObject then
                local actionSequenceTypeIndex = serverSapien:actionSequenceTypeIndexForOrder(sapien, orderObject, orderState)
                local activeSequence = actionSequence.types[actionSequenceTypeIndex]
                if activeSequence and activeSequence.snapToOrderObjectIndex then
                    if orderState.objectID ~= sapien.sharedState.seatObjectID then --dont add a snap node if we are already sitting on the destination object
                        local snapInfo = sapienObjectSnapping:getSnapInfo(orderObject, sapien, orderState, activeSequence.actions[activeSequence.snapToOrderObjectIndex])

                        if snapInfo then
                            ----disabled--mj:objectLog(sapien.uniqueID, "addFinalSnapNodeIfNeeded h")

                            local posToUse = snapInfo.pos
                            if not posToUse then
                                posToUse = orderObject.pos
                            end

                            if snapInfo.offsetToWalkableHeight then
                                local clampToSeaLevel = true
                                posToUse = worldHelper:getBelowSurfacePos(posToUse, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                            end

                            local lastPathPos = sapien.pos

                            if pathInfo.nodes and pathInfo.nodes[1] then
                                lastPathPos = pathInfo.nodes[#pathInfo.nodes].pos
                            end

                            if length2(posToUse - lastPathPos) > minDistanceToAddFinalSnapNode2 then
                                if not pathInfo.nodes then
                                    pathInfo.nodes = {}
                                    pathInfo.noMovementRequired = false
                                    pathInfo.valid = true
                                    pathInfo.complete = true
                                end

                                table.insert(pathInfo.nodes, {
                                    pos = posToUse,
                                    difficulty = 1.0
                                })

                                pathInfo.goalPos = posToUse
                            end

                            --serverGOM:setPos(sapien.uniqueID, posToUse, false)
                        end
                    end
                end
            end
        end
    end
end

--local twentyCM = mj:mToP(0.2)

local function updateOptionsForRideableObjects(sapienUniqueID, startPos, optionsOrNil)
    local result = optionsOrNil
    local objects = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.waterRideableObjects, startPos, mj:mToP(100.0))
    local sapien = serverGOM:getObjectWithID(sapienUniqueID)

    local function getWaterRideableObjectInfo(objectID)
        local object = serverGOM:getObjectWithID(objectID)
        if object and (not serverGOM:objectIsInaccessible(object)) then 

            if object.objectTypeIndex == gameObject.types.canoe.index or object.objectTypeIndex == gameObject.types.coveredCanoe.index then
                --disabled--mj:objectLog(sapienUniqueID, "getWaterRideableObjectInfo:", objectID)
                local useAllowed = true
                local seatTribeID = object.sharedState.tribeID
                if seatTribeID and seatTribeID ~= sapien.sharedState.tribeID then
                    if serverWorld:tribeIsValidOwner(seatTribeID) then
                        local relationshipSettings = serverWorld:getTribeRelationsSettings(seatTribeID, sapien.sharedState.tribeID)
                        if not (relationshipSettings and relationshipSettings.allowBedUse) then
                            useAllowed = false
                        end
                    end
                end

                if useAllowed then
                    local nodeIndex = serverSeat:getAvailableNodeIndex(sapien, object, true)
                    --disabled--mj:objectLog(sapienUniqueID, "nodeIndex:", nodeIndex)
                    ----disabled--mj:objectLog(sapien.uniqueID, "seat good:", info.objectID, " nodeIndex:", nodeIndex)
                    if nodeIndex and (not serverSapien:seatIsAssignedToOtherSapien(object, nodeIndex, sapien)) then
                        return gameObject.types[object.objectTypeIndex].rideWaterPathFindingDifficulty
                    end
                end
            end
        end
        return nil
    end

    local function addWaterRidableObject(objectID)
        --disabled--mj:objectLog(sapienUniqueID, "addWaterRidableObject:", objectID)
        local rideWaterPathFindingDifficulty = getWaterRideableObjectInfo(objectID)
        if rideWaterPathFindingDifficulty then
            if not result then
                result = {}
            end
            if not result.availableWaterRides then
                result.availableWaterRides = {}
            end
            result.availableWaterRides[objectID] = rideWaterPathFindingDifficulty
            return true
        end
        return false
    end

    if objects and objects[1] then
        for j,objectInfo in ipairs(objects) do
            addWaterRidableObject(objectInfo.objectID)
        end
    end

    if result and sapien.sharedState.seatObjectID and result.availableWaterRides and result.availableWaterRides[sapien.sharedState.seatObjectID] then
        result.rideObjectID = sapien.sharedState.seatObjectID
    end

    if sapien.sharedState.haulingObjectID then
        if addWaterRidableObject(sapien.sharedState.haulingObjectID) then
            result.ridableHaulingObjectID = sapien.sharedState.haulingObjectID
        end
    end

    --disabled--mj:objectLog(sapienUniqueID, "updateOptionsForRideableObjects result:", result)

    return result
end

function pathCreator:getPath(objectUniqueID, goalObjectIDOrNil, startPos, goalPos, proximityType, proximityDistanceOrNil, optionsOrNil, callbackFunc)
    --disabled--mj:objectLog(objectUniqueID, "path requested of length:", mj:pToM(mjm.length(goalPos - startPos)), " proximityType:", pathFinding.proximityTypes[proximityType], " proximityDistanceOrNil:", proximityDistanceOrNil)

    --mj:log("proximityType:", proximityType)

    if not proximityType then
        mj:warn("no proximity type given for getPath for sapien:", objectUniqueID)
        proximityType = pathFinding.proximityTypes.reachable
    end
    
    --mj:log(debug.traceback())
    --mj:log("path requested:", objectUniqueID)
    local proximityDistance = proximityDistanceOrNil
    if not proximityDistance or proximityDistance == 0 then
        proximityDistance = mj:mToP(2.5)
    end

    optionsOrNil = updateOptionsForRideableObjects(objectUniqueID, startPos, optionsOrNil)

    bridge:getPath(objectUniqueID, goalObjectIDOrNil or 0, startPos, goalPos, proximityType, proximityDistance, optionsOrNil, function(path)

       --[[ if path.complete and (not path.valid) then
            mj:warn("no path in pathCreator:getPath")
        end]]


        local pathInfo = createPathInfo(path, startPos, goalPos, true)
        --disabled--mj:objectLog(objectUniqueID, "got path with options:", optionsOrNil, " pathInfo:", pathInfo)
        
        local sapien = serverGOM:getObjectWithID(objectUniqueID)
        addFinalSnapNodeIfNeeded(sapien, pathInfo)

        if mj.debugObject == objectUniqueID and sapien then
            serverWorld:setDebugObjectPath(sapien.sharedState.tribeID, pathInfo)
        end
        

       --[[ if not path.complete then
            local nodeCount = 0
            if pathInfo.nodes then
                nodeCount = #pathInfo.nodes
            end
            mj:log("incomplete path for:", objectUniqueID, " node count:", nodeCount)
        end]]

        
        --[[if path.valid then
            mj:log("getPath got valid path complete:", pathInfo.complete, " for object:", objectUniqueID, " node count:", #pathInfo.nodes)
        else
            mj:log("getPath got invalid path complete:", pathInfo.complete, " for object:", objectUniqueID)
        end]]
    
        callbackFunc(pathInfo)
    end)

    --[[if path and path.nodeCount >= 1 then
        --disabled--mj:objectLog("path count:", path.nodeCount, " minDistance:", minDistance, " startPos:", startPos, " goalPos:", goalPos, " first nodePos:", path:getNode(0).pos, " last nodePos:", path:getNode(path.nodeCount - 1).pos)
        --disabled--mj:objectLog("minDistance meters:", mj:pToM(minDistance), " start-goal distance meters:",  mj:pToM(length(startPos - goalPos)))
    end]]

end

function pathCreator:setDebugObject(objectID)
    bridge:setDebugObject(objectID)
end

function pathCreator:getDebugConnectionsForObject(objectID)
    return bridge:getDebugConnectionsForObject(objectID)
end

function pathCreator:debugGetHasConnections(objectID)
    return bridge:debugGetHasConnections(objectID)
end

function pathCreator:pathFindingCylinderTest(startGroundPos, endGroundPos, radius, yOffset, ignoreObjectIDOrNil) --returns true if collision found
    return bridge:pathFindingCylinderTest({
        startGroundPos = startGroundPos,
        endGroundPos = endGroundPos,
        radius = radius,
        yOffset = yOffset,
        ignoreObjectID = ignoreObjectIDOrNil,
    })
end

function pathCreator:setBridge(bridge_)
    bridge = bridge_
    bridge:setPathColliderPhysicsSet(physicsSets.pathColliders)
    bridge:setWalkablePhysicsSet(physicsSets.walkable)
    bridge:setRoadObjectsPhysicsSet(physicsSets.roadsAndPaths)

    bridge:setPathNodeDifficulties(pathFinding.pathNodeDifficulties)

    local pathDifficultyIndexesByObjectType = {}
    local allowsPathsThroughWithOverrideDifficultyIndexesByObjectType = {}
    for i,gameObjectType in ipairs(gameObject.validTypes) do
        if gameObjectType.pathFindingDifficulty ~= nil then
            pathDifficultyIndexesByObjectType[gameObjectType.index] = gameObjectType.pathFindingDifficulty
        end

        if gameObjectType.allowsPathsThroughWithDifficultyOverride ~= nil then
            allowsPathsThroughWithOverrideDifficultyIndexesByObjectType[gameObjectType.index] = gameObjectType.allowsPathsThroughWithDifficultyOverride
        end
    end

    bridge:setPathDifficultyIndexesByObjectType(pathDifficultyIndexesByObjectType, allowsPathsThroughWithOverrideDifficultyIndexesByObjectType)

    --setPathDifficultyIndexesByObjectType
end

function pathCreator:init(initObjects)
    gameObject = initObjects.gameObject
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    serverSapien = initObjects.serverSapien
end

return pathCreator