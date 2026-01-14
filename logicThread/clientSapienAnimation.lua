
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local cross = mjm.cross
local approxEqual = mjm.approxEqual
local dot = mjm.dot
local length = mjm.length
local length2 = mjm.length2
local mat3LookAtInverse = mjm.mat3LookAtInverse
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3Slerp = mjm.mat3Slerp
local mat3Rotate = mjm.mat3Rotate
local mat3GetRow = mjm.mat3GetRow
local vec3xMat3 = mjm.vec3xMat3
local mat3Inverse = mjm.mat3Inverse
local mat3Identity = mjm.mat3Identity

local gameObject = mjrequire "common/gameObject"
local action = mjrequire "common/action"
local storage = mjrequire "common/storage"
local animationGroups = mjrequire "common/animationGroups"
local actionSequence = mjrequire "common/actionSequence"
local constructable = mjrequire "common/constructable"
local order = mjrequire 'common/order'
local sapienConstants = mjrequire 'common/sapienConstants'
--local notification = mjrequire 'common/notification'
local rng = mjrequire "common/randomNumberGenerator"
local social = mjrequire "common/social"
local physicsSets = mjrequire "common/physicsSets"
local physics = mjrequire "common/physics"
local worldHelper = mjrequire "common/worldHelper"
local model = mjrequire "common/model"
local seat = mjrequire "common/seat"

local clientObjectAnimation = mjrequire "logicThread/clientObjectAnimation"
local clientConstruction = mjrequire "logicThread/clientConstruction"
--local clientBuildableObject = mjrequire "logicThread/clientBuildableObject"
local clientCraftArea = mjrequire "logicThread/clientCraftArea"
local clientSapienInventory = mjrequire "logicThread/clientSapienInventory"
local terrain = mjrequire "logicThread/clientTerrain"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local logic = mjrequire "logicThread/logic"

local clientSapienAnimation = {}

local clientGOM = nil
local clientSapien = nil

clientSapienAnimation.debugServerState = false

local debugAnimationActionTypeIndex = action.types.fightFollowThrough.index

local buildMoveComponentAnimationProgression = mj:enum {
    "moveToBeforeAction",
    "beforeAction",
    "moveToPickup",
    "pickup",
    "standAfterPickup",
    "moveToDropOff",
    "place",
    "afterAction",
    "wait",
}

local clientPlantAnimationProgression = mj:enum {
    "moveToDig",
    "dig",
}

local function resetGoalMatrix(sapien, clientState)
    clientState.goalTimer = nil
    clientState.goalRotation = nil
    clientState.goalPos = nil
    clientState.pos = sapien.pos
end

local function updateMatrix(sapien, dt, speedMultiplier, clientState)
    if clientState.goalTimer then
        clientState.goalTimer = clientState.goalTimer - dt
        if clientState.goalTimer < 0.0 then
            resetGoalMatrix(sapien, clientState)
        else
    
            local newRotation = clientState.rotation or sapien.rotation
            --local prevRotation = newRotation
            if clientState.goalRotation then
                local rotationFraction = mjm.clamp(dt * 6.0 * speedMultiplier, 0.0, 1.0)
                --[[newRotation = mat3Slerp(newRotation, clientState.goalRotation, rotationFraction)
                clientState.rotation = newRotation]]
                local dp = dot(mat3GetRow(newRotation, 2), mat3GetRow(clientState.goalRotation, 2))
                if dp > 0.999 then
                    newRotation = clientState.goalRotation
                else
                    
                    if dp < -0.999 then
                        dp = -0.999
                    end

                    local angle = math.acos(dp)
                    if dot(mat3GetRow(newRotation, 0), mat3GetRow(clientState.goalRotation, 2)) < 0.0 then
                        angle = -angle
                    end
                    clientState.rotationalVelocity = (clientState.rotationalVelocity or 0.0) + (angle - (clientState.rotationalVelocity or 0.0)) * rotationFraction
                    newRotation = mat3Rotate(newRotation, clientState.rotationalVelocity * rotationFraction, mjm.vec3(0.0,1.0,0.0))
                end
            else
                clientState.rotationalVelocity = 0.0
            end

            local newPos = clientState.pos or sapien.pos
            if clientState.goalPos then
                local posFraction = mjm.clamp(dt * 16.0 * speedMultiplier, 0.0, 1.0)
                newPos = mjm.mix(newPos, clientState.goalPos, posFraction)
            end

            if clientSapienAnimation.debugServerState then
                newRotation = sapien.rotation
                newPos = sapien.pos
            end
            clientState.pos = newPos
            
            --[[if mj:isNan(newRotation.m0) then
                mj:error("rotation is nan")
                mj:log("sapien.rotation:", sapien.rotation)
                mj:log("clientState.rotation:", clientState.rotation)
                mj:log("clientState.goalRotation:", clientState.goalRotation)
                error()
            end]]

            ----disabled--mj:objectLog(sapien.uniqueID, "updateMatrix:", newPos)
            clientGOM:updateMatrix(sapien.uniqueID, newPos, newRotation)
        end
    else
        clientState.rotationalVelocity = 0.0
    end
end

local function setNewPos(sapien, clientState, newPos)

    if mj:isNan(newPos.x) then
        mj:error("newPos is nan. clientState.goalPos:", clientState.goalPos, " sapien.pos:", sapien.pos)
        error()
    end
    clientState.goalPos = newPos
    --clientState.pos = newPos
    clientState.goalTimer = 1.0
end

local function setNewRotationMatrixFromDirection(sapien, clientState, normalizedPos)
    local dp = dot(clientState.directionNormal, normalizedPos)
    if dp > -0.9 and dp < 0.9 then
        local rotation = createUpAlignedRotationMatrix(normalizedPos, clientState.directionNormal)
        if mj:isNan(rotation.m0) then
            clientState.directionNormal = normalize(cross(normalizedPos, mjm.vec3(0.0,1.0,0.0)))
            rotation = createUpAlignedRotationMatrix(normalizedPos, clientState.directionNormal)
        end
        
        clientState.goalRotation = rotation
        clientState.goalTimer = 1.0
    end
end

local minSapienDistanceFromMoveToPos = mj:mToP(0.3)
local offsetSapienDistanceFromMoveToPos = mj:mToP(0.6)
local minSapienDistanceFromMoveToPos2 = minSapienDistanceFromMoveToPos * minSapienDistanceFromMoveToPos

local heightToCheckForSwimming = 1.0 + mj:mToP(0.05) --server clamps to sea level, so any nodes at sea level may actually be below. -- changed 6/5/22 down from 0.1
local heightToCheckForSwimming2 = heightToCheckForSwimming * heightToCheckForSwimming

local heightToStartSwimming = 1.0 - mj:mToP(1.01)
local heightToStartSwimming2 = heightToStartSwimming * heightToStartSwimming

local swimmingHeight = 1.0 - mj:mToP(1.01)

--local heightToStartWading = 1.0 - mj:mToP(0.1)
--local heightToStartWading2 = heightToStartWading * heightToStartWading

local maxDistanceToShiftDown = mj:mToP(0.5)
local maxDistanceToShiftDown2 = maxDistanceToShiftDown * maxDistanceToShiftDown


local function getPosInfoAtCorrectHeight(sapien, startPos, forceOffset)
    ----disabled--mj:objectLog(sapien.uniqueID, " getPosInfoAtCorrectHeight:", mj:pToM(length(startPos) - 1.0))
    local incomingPosLength2 = length2(startPos)
    if forceOffset or incomingPosLength2 < heightToCheckForSwimming2 then
        local terrainPos = terrain:getLoadedTerrainPointAtPoint(startPos)
        local terrainLength2 = length2(terrainPos)
        local incomingPosLength = math.sqrt(incomingPosLength2)
        local incomingPosNormal = startPos / incomingPosLength

        local belowPos = terrainPos

        if incomingPosLength2 > terrainLength2 then
            belowPos = startPos
            local rayResult =  physics:rayTest(incomingPosNormal * (incomingPosLength + mj:mToP(0.8)), terrainPos, physicsSets.walkable, nil)
            ----disabled--mj:objectLog(sapien.uniqueID, " rayResult:", rayResult)
            if rayResult.hasHitObject then
                if length2(rayResult.objectCollisionPoint - startPos) < maxDistanceToShiftDown2 then
                    belowPos = rayResult.objectCollisionPoint
                end
            elseif length2(terrainPos - startPos) < maxDistanceToShiftDown2 or incomingPosLength2 < heightToCheckForSwimming2 then
                belowPos = terrainPos
            end
        end
        
        local belowLength2 = length2(belowPos)

        if belowLength2 < heightToStartSwimming2 then
            if sapien.sharedState.seatObjectID then
                return {
                    pos = incomingPosNormal,
                }
            else
                return {
                    pos = incomingPosNormal * swimmingHeight,
                    swimming = true,
                }
            end
        else
            if sapien.sharedState.seatObjectID and belowLength2 < 1.0 then
                return {
                    pos = incomingPosNormal,
                }
            end
            return {
                pos = belowPos, --changed to startPos to fix bug sitting on seats at sea level
                --pos = startPos,
            }
        end
    end
    return {
        pos = startPos,
    }
end

local function updateMoveToPos(sapien, clientState, incomingMoveToPos, checkForCloseSapiens)
    
    if sapien.sharedState.seatObjectID then
        local seatPos = incomingMoveToPos
        if length2(seatPos) < 1.0 then --hack to help ensure boats stay on the surface
            seatPos = normalize(seatPos)
        end

        clientState.moveToPosAvoidingObstacles = seatPos
        clientState.moveToPosIsSwimming = false
        clientState.moveToPosAvoidingObstaclesBasePos = seatPos
        return
    end

    ----disabled--mj:objectLog(sapien.uniqueID, "updateMoveToPos a:", incomingMoveToPos)
    if clientState.moveToPosAvoidingObstacles and approxEqual(clientState.moveToPosAvoidingObstaclesBasePos.x, incomingMoveToPos.x) and approxEqual(clientState.moveToPosAvoidingObstaclesBasePos.y, incomingMoveToPos.y) then
        return clientState.moveToPosAvoidingObstacles
    end
    ----disabled--mj:objectLog(sapien.uniqueID, "updateMoveToPos b")


    local offsetMoveToPosInfo = getPosInfoAtCorrectHeight(sapien, incomingMoveToPos, false)
    
    --[[if sapien.uniqueID == "13a735" then
        mj:log("incomingMoveToPos:", incomingMoveToPos)
        mj:log("offsetMoveToPosInfo:", offsetMoveToPosInfo)
    end]]

    local offsetMoveToPos = offsetMoveToPosInfo.pos
    clientState.moveToPosAvoidingObstacles = offsetMoveToPos
    clientState.moveToPosIsSwimming = offsetMoveToPosInfo.swimming

    if checkForCloseSapiens then
        local actionState = sapien.sharedState.actionState
        if actionState and actionState.sequenceTypeIndex then
            local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
            if activeSequence.snapToOrderObjectIndex then
                checkForCloseSapiens = false
            end
        end 
    end

    if checkForCloseSapiens then
        local closeSapienIDs = clientGOM:getGameObjectsOfTypesWithinRadiusOfPos({sapien.objectTypeIndex}, offsetMoveToPos, mj:mToP(8.0))
        local offsetRightOrLeft = nil

        for i=1,6 do
            local tooCloseSapienPos = nil

            for j,closeSapienID in ipairs(closeSapienIDs) do
                if closeSapienID ~= sapien.uniqueID then
                    local closeSapien = clientGOM:getObjectWithID(closeSapienID)
                    if closeSapien then
                        if length2(closeSapien.pos - clientState.moveToPosAvoidingObstacles) < minSapienDistanceFromMoveToPos2 then
                            tooCloseSapienPos = closeSapien.pos
                            break
                        end
                    end
                end
            end 

            if tooCloseSapienPos then
                local sapienPos = clientState.goalPos or sapien.pos
                local routeVec = clientState.moveToPosAvoidingObstacles - sapienPos + rng:randomVec() * mj:mToP(0.1)
                local routeVecLength = length(routeVec)
                if routeVecLength > 0.0 then
                    local routeVecNormal = routeVec / routeVecLength
                    local rightVec = cross(sapien.normalizedPos, -routeVecNormal)
                    local offsetDirection = rightVec

                    if not offsetRightOrLeft then
                        local tooClosePosDirectionVec = tooCloseSapienPos - clientState.moveToPosAvoidingObstacles
                        if dot(rightVec, tooClosePosDirectionVec) > 0 then
                            offsetRightOrLeft = -1.0
                        else
                            offsetRightOrLeft = 1.0
                        end
                    end

                    --disabled--mj:objectLog(sapien.uniqueID, "getMoveToPosAvoidingOthers avoiding close sapien")

                    clientState.moveToPosAvoidingObstacles = clientState.moveToPosAvoidingObstacles + offsetDirection * offsetRightOrLeft * offsetSapienDistanceFromMoveToPos
                end
                
            else
                --disabled--mj:objectLog(sapien.uniqueID, "getMoveToPosAvoidingOthers none near by:", debug.traceback())
                break
            end
        end
    end

    clientState.moveToPosAvoidingObstaclesBasePos = incomingMoveToPos

end

local emitterThresholdPosLength = 1.0 - mj:mToP(0.1)

local function updateWaterEmitters(sapien, clientState)
    
    local actionState = sapien.sharedState.actionState
    local isCausingRipples = clientState.swimming
    if not isCausingRipples and actionState then
        local isInWater = length2(clientState.goalPos or sapien.pos) < emitterThresholdPosLength
        if isInWater then
            local actionSequenceActions = actionSequence.types[actionState.sequenceTypeIndex].actions
            local actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]
            if action.types[actionTypeIndex].isMovementAction then
                isCausingRipples = true
            end
        end
    end

    if isCausingRipples then
        local swimPos = clientState.goalPos or sapien.pos
        if clientState.swimming and clientState.directionNormal and actionState and actionState.sequenceTypeIndex then
            local actionSequenceActions = actionSequence.types[actionState.sequenceTypeIndex].actions
            local actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]

            if action.types[actionTypeIndex].isMovementAction then
                swimPos = swimPos + clientState.directionNormal * mj:mToP(0.75)
            end
        end

        if not clientState.swimmingEmitterID then
            local emitterType = particleManagerInterface.emitterTypes.waterRipples
            clientState.swimmingEmitterID = particleManagerInterface:addEmitter(emitterType, swimPos, sapien.rotation, nil, false)
        else
            particleManagerInterface:updateEmitter(clientState.swimmingEmitterID, swimPos, sapien.rotation, nil, false)
        end
    else
        if clientState.swimmingEmitterID then
            particleManagerInterface:removeEmitter(clientState.swimmingEmitterID)
            clientState.swimmingEmitterID = nil
        end
    end 
end

local function updateSwimState(sapien, clientState, newPos)
    local modifiedPos = newPos
    if ((clientState.moveToPosIsSwimming)  and (not clientState.swimming)) or  ((not clientState.moveToPosIsSwimming)  and (clientState.swimming)) then
        local posInfo = getPosInfoAtCorrectHeight(sapien, newPos, false)
        modifiedPos = posInfo.pos
        clientState.swimming = posInfo.swimming
    end
    return modifiedPos
end

--local nextNodeInfluenceDistanceMax = mj:mToP(2.0)
--local nextNodeInfluenceDistanceMax2 = nextNodeInfluenceDistanceMax * nextNodeInfluenceDistanceMax

local minDistanceToMove = mj:mToP(0.1)
local minDistanceToMove2 = minDistanceToMove * minDistanceToMove

local minDistanceFromCameraToCheckHeightAccurately = mj:mToP(20.0)
local minDistanceFromCameraToCheckHeightAccurately2 = minDistanceFromCameraToCheckHeightAccurately * minDistanceFromCameraToCheckHeightAccurately

local function updateHaulingObjectPos(sapien, dt, speedMultiplier, clientState)
    local sharedState = sapien.sharedState
    if sharedState.haulingObjectID and (not sharedState.seatObjectID) then
        local haulingObject = clientGOM:getObjectWithID(sharedState.haulingObjectID)
        if haulingObject then
            local distanceMeters = 2.0
            local sapienPosToUse = clientState.pos or sapien.pos
            local distanceVec = haulingObject.pos - sapienPosToUse
            local len = length(distanceVec)
            if len > mj:mToP(distanceMeters) then
                local directionNormal = distanceVec / len
                local newHaulObjectPos = sapienPosToUse + directionNormal * mj:mToP(distanceMeters)
                local sledRight = mat3GetRow(haulingObject.rotation, 0)
                local directionDot = dot(sledRight, directionNormal)
                local newRotation = haulingObject.rotation

                local clampedToSeaLevel = true
                local newHaulObjectPosLength = length(newHaulObjectPos)
                if newHaulObjectPosLength > 1.0 then
                    clampedToSeaLevel = false
                else
                    newHaulObjectPos = newHaulObjectPos / newHaulObjectPosLength
                end

                if directionDot < 0.99 then
                    local leftVector = normalize(cross(haulingObject.normalizedPos, directionNormal))
                    local frontPos = sapienPosToUse + directionNormal * mj:mToP(distanceMeters * 0.5)
                    local terrrainNormal = haulingObject.normalizedPos
                    if not clampedToSeaLevel then
                        terrrainNormal = worldHelper:getWalkableUpVector(normalize(frontPos))
                    end
                    local goalRotation = mat3LookAtInverse(leftVector, terrrainNormal)
                    local dp = dot(mat3GetRow(goalRotation, 0), mat3GetRow(haulingObject.rotation, 0))
                    if dp < -0.9 or dp > 0.999 then
                        newRotation = goalRotation
                    else
                        newRotation = mat3Slerp(newRotation, goalRotation, math.min(dt * speedMultiplier * 4.0, 1.0))
                    end
                    --local goalRotation = mat3Rotate(goalRightRotation, math.pi * 0.5, vec3(0.0,1.0,0.0))

                end

                clientGOM:setDynamicRenderOverride(haulingObject.uniqueID, true)
                clientGOM:updateMatrix(haulingObject.uniqueID, newHaulObjectPos, newRotation)

                local sapienPointWorld = sapienPosToUse + vec3xMat3(mj:mToP(vec3(-0.09,1.125,0.4)), mat3Inverse(sapien.rotation))

                local sledPointOffsetMeters = vec3(0.9,0.3,0.0)
                if haulingObject.objectTypeIndex == gameObject.types.canoe.index or haulingObject.objectTypeIndex == gameObject.types.coveredCanoe.index then
                    sledPointOffsetMeters = vec3(1.27,0.21,0.0)
                end

                local sledPointWorld = haulingObject.pos + vec3xMat3(mj:mToP(sledPointOffsetMeters), mat3Inverse(newRotation))

                local midPointWorld = (sapienPointWorld + sledPointWorld) * 0.5
                local midPointRelativeToSledRopeStart = midPointWorld - sledPointWorld
                local midPointRelativeToSledRopeStartMeters = vec3xMat3(mj:pToM(midPointRelativeToSledRopeStart), newRotation)

                local midPointRelativeToSledOrigin = midPointWorld - haulingObject.pos
                local midPointRelativeToSledOriginMeters = vec3xMat3(mj:pToM(midPointRelativeToSledOrigin), newRotation)

                local midPointLengthMeters = length(midPointRelativeToSledRopeStartMeters)
                local rotationLocal = mjm.mat3LookAtInverse(midPointRelativeToSledRopeStartMeters / midPointLengthMeters,vec3(0.0,1.0,0.0))
                local fullLengthMeters = midPointLengthMeters

                local haulingObjectClientState = clientGOM:getClientState(haulingObject)
                if haulingObjectClientState.currentHaulingSapienID ~= sapien.uniqueID then
                   -- mj:log("add object")
                    clientState.currentHaulingObjectID = haulingObject.uniqueID
                    haulingObjectClientState.currentHaulingSapienID = sapien.uniqueID
                    clientGOM:setDynamicRenderOverride(haulingObject.uniqueID, true)

                    local connectorModelIndex = model:modelIndexForName("ropeSegment")
                    mj:log("add rope for haulingObject")

                    clientGOM:setSubModelForKey(haulingObject.uniqueID,
                    "rope",
                    nil,
                    connectorModelIndex,
                    vec3(1.0,1.0,fullLengthMeters),
                    RENDER_TYPE_DYNAMIC,
                    midPointRelativeToSledOriginMeters,
                    rotationLocal,
                    false,
                    nil)

                    if not clientState.ropeModelsAdded then
                        mj:log("add rope for sap")
                        clientState.ropeModelsAdded = true

                        clientGOM:setSubModelForKey(sapien.uniqueID,
                        "haulRope1",
                        "rightShoulderObject",
                        connectorModelIndex,
                        vec3(1.0,1.0,0.07),
                        RENDER_TYPE_DYNAMIC,
                        vec3(0.0,0.0,0.05),
                        mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)),
                        false,
                        nil
                        )

                        clientGOM:setSubModelForKey(sapien.uniqueID,
                        "haulRope2",
                        "rightShoulderObject",
                        connectorModelIndex,
                        vec3(1.0,1.0,0.25),
                        RENDER_TYPE_DYNAMIC,
                        vec3(-0.23,-0.18,0.0501),
                        mat3Rotate(mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,1.0,0.0)), math.pi * 0.75, vec3(1.0,0.0,0.0)),
                        false,
                        nil
                        )
                    end

                else
                    --mj:log("update object:", midPointRelativeToSledOriginMeters, " fullLengthMeters:", fullLengthMeters, " rotationLocal:", rotationLocal)
                    clientGOM:setSubModelTransform(haulingObject.uniqueID, "rope", midPointRelativeToSledOriginMeters, vec3(1.0,1.0,fullLengthMeters), rotationLocal)
                end
            end
        end
    end
end

function clientSapienAnimation:updateMove(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, sequenceTypeIndex)
    if clientState.pathDone then
        return false
    end
    local pathRoute = actionState.path.nodes

    local currentPos = clientState.goalPos or sapien.pos
    local seatObject = sapien.sharedState.seatObjectID and clientGOM:getObjectWithID(sapien.sharedState.seatObjectID)
    if seatObject then
        currentPos = seatObject.pos
    end

    if mj:isNan(currentPos.x) then
        mj:error("newPos is nan. clientState.goalPos:", clientState.goalPos, " sapien.pos:", sapien.pos)
        error()
    end

    --local newPosNormal = normalize(newPos)

    local sharedState = sapien.sharedState
    
    local pathNodeIndex = actionState.pathNodeIndex
    if clientState.pathNodeIndex then
        pathNodeIndex = clientState.pathNodeIndex
    end

    local node = pathRoute[pathNodeIndex]
    local difficultySpeedMultiplier = 1.0 / node.difficulty
    clientState.animationSpeedMultiplier = difficultySpeedMultiplier

    --clientState.rampUpTimer = (clientState.rampUpTimer or 0.0) + (dt * speedMultiplier) * 2.0
    --clientState.rampUpTimer = math.min(clientState.rampUpTimer, 1.0)


    local walkDistanceToUse = sapienConstants:getWalkSpeed(sharedState) * difficultySpeedMultiplier * action:combinedMoveSpeedMultiplier(actionTypeIndex, sharedState.actionModifiers) * dt * speedMultiplier-- * clientState.rampUpTimer



    updateMoveToPos(sapien, clientState, node.pos, pathNodeIndex == #pathRoute)
    local moveToPos = clientState.moveToPosAvoidingObstacles

   -- --disabled--mj:objectLog(sapien.uniqueID, "a:", pathNodeIndex)
    if clientState.nodeDistance > 0 then
        ----disabled--mj:objectLog(sapien.uniqueID, "b:", clientState.nodeTravelDistance / clientState.nodeDistance)
        local nextNodePos = nil
        if clientState.pathNodeIndex < #pathRoute then
            nextNodePos = pathRoute[clientState.pathNodeIndex + 1].pos
        end
        if nextNodePos then
           -- --disabled--mj:objectLog(sapien.uniqueID, "nextNodePos d:", mj:pToM(length(nextNodePos - moveToPos)))
            moveToPos = mjm.mix(moveToPos, nextNodePos, mjm.smoothStep(0.0,1.0,mjm.clamp(clientState.nodeTravelDistance / clientState.nodeDistance, 0.0, 1.0)) * 0.67)
        end
    end

    local routeVec = moveToPos - currentPos
    local distance2 = length2(routeVec)
    if mj:isNan(moveToPos.x) then
        mj:error("moveToPos is nan. sapien.pos:", sapien.pos, " clientState:", clientState, " node.pos:", node.pos)
        error()
    end

    --mj:log("clientSapienAnimation:updateMove:", sapien.uniqueID, " pos:", moveToPos)

    local newPos = currentPos
    ----disabled--mj:objectLog(sapien.uniqueID, "newPos a:", mj:pToM(length(newPos) - 1.0))

    local function moveTowards(distanceRemainingToTravel)
        
        ----disabled--mj:objectLog(sapien.uniqueID, "moveTowards:", mj:pToM(math.sqrt(distance2)))
        if distance2 > minDistanceToMove2 then
            local moveVec = moveToPos - currentPos
            local moveVecLength = length(moveVec)
            local directionNormal = moveVec / moveVecLength
            local movement = directionNormal * distanceRemainingToTravel
            if mj:isNan(movement.x) then
                mj:error("movement is nan. moveToPos:", moveToPos, " currentPos:", currentPos, " distanceRemainingToTravel:", distanceRemainingToTravel, " node.pos:", node.pos)
                error()
            end

            ----disabled--mj:objectLog(sapien.uniqueID, "moveTowards moveVecLength:", mj:pToM(moveVecLength))
            
            if moveVecLength > mj:mToP(0.05) then
                local faceDirection = directionNormal
                --disabled--mj:objectLog(sapien.uniqueID, "setting clientState.directionNormal in moveTowards:", faceDirection)
                clientState.directionNormal = faceDirection
            end

            newPos = newPos + movement
        else
            if pathNodeIndex == #pathRoute then
                newPos = moveToPos
                clientState.nodeDistance = 0.0
                clientState.nodeTravelDistance = 0.0
                
                clientState.pathDone = true
                clientState.rampUpTimer = nil
            else
                newPos = moveToPos
                clientState.nodeDistance = 0.0
                clientState.nodeTravelDistance = 0.0
            end
            --newPos = moveToPos
        end
       -- --disabled--mj:objectLog(sapien.uniqueID, "newPos b:", mj:pToM(length(newPos) - 1.0))

        --newPos = worldHelper:getBelowSurfacePos(newPos, 1.0, physicsSets.walkable)
        ----disabled--mj:objectLog(sapien.uniqueID, "getBelowSurfacePos a:", mj:pToM(length(newPos) - 1.0))
        if mj:isNan(newPos.x) then
            mj:error("newPos is nan. moveToPos:", moveToPos, " newPos:", newPos, " distanceRemainingToTravel:", distanceRemainingToTravel, " node.pos:", node.pos)
            error()
        end
    end


    if clientState.nodeTravelDistance + walkDistanceToUse >= clientState.nodeDistance then
        if pathNodeIndex < #pathRoute then
            local distanceRemainingToTravel = clientState.nodeTravelDistance + walkDistanceToUse - clientState.nodeDistance

            pathNodeIndex = pathNodeIndex + 1
            clientState.pathNodeIndex = pathNodeIndex
            

            --disabled--mj:objectLog(sapien.uniqueID, "reset b")
            clientState.nodeTravelDistance = 0.0
            clientState.nodeDistance = length(pathRoute[pathNodeIndex].pos - pathRoute[pathNodeIndex - 1].pos)
            clientState.lastReaclculatedNodeIndex = pathNodeIndex
            
            ----disabled--mj:objectLog(sapien.uniqueID, "distanceRemainingToTravel:", mj:pToM(distanceRemainingToTravel), " pathNodeIndex:", pathNodeIndex)
            updateMoveToPos(sapien, clientState, pathRoute[pathNodeIndex].pos, pathNodeIndex == #pathRoute)
            moveToPos = clientState.moveToPosAvoidingObstacles
            routeVec = moveToPos - newPos
            distance2 = length2(routeVec)

            if distanceRemainingToTravel > 0.0 and walkDistanceToUse > 0.0 then
                
                clientState.nodeTravelDistance = clientState.nodeTravelDistance + distanceRemainingToTravel
                moveTowards(distanceRemainingToTravel)
            end
        else
            --disabled--mj:objectLog(sapien.uniqueID, "standard")
            newPos = moveToPos
            --disabled--mj:objectLog(sapien.uniqueID, "newPos c:", mj:pToM(length(newPos) - 1.0))
            clientState.nodeDistance = 0.0
            clientState.pathDone = true
            clientState.rampUpTimer = nil
        end
    elseif walkDistanceToUse > 0.0 then
        local distanceFromNode = length(clientState.moveToPosAvoidingObstacles - newPos)
        local desiredDistanceFromNode = clientState.nodeDistance - clientState.nodeTravelDistance
        --disabled--mj:objectLog(sapien.uniqueID, "distanceFromNode:", mj:pToM(distanceFromNode), " desiredDistanceFromNode:", mj:pToM(desiredDistanceFromNode))
        local errorDistance = math.max(desiredDistanceFromNode - distanceFromNode, 0.0)
        local walkDistanceToUseWithErrorCorrection = walkDistanceToUse - (errorDistance / mj:mToP(4.0)) * walkDistanceToUse
        
        clientState.nodeTravelDistance = clientState.nodeTravelDistance + walkDistanceToUse

        if walkDistanceToUseWithErrorCorrection > 0.0 then
            moveTowards(walkDistanceToUseWithErrorCorrection)
            if length2(newPos - logic.playerPos) < minDistanceFromCameraToCheckHeightAccurately2 then
                if not approxEqual(length2(newPos), length2(moveToPos)) then
                    newPos = getPosInfoAtCorrectHeight(sapien, newPos, true).pos --could be optimized further
                    --disabled--mj:objectLog(sapien.uniqueID, "newPos d:", mj:pToM(length(newPos) - 1.0))
                end
            end
        end
    end

    local moveableSeatObject = false
    if seatObject then
        local seatTypeIndex = gameObject.types[seatObject.objectTypeIndex].seatTypeIndex
        if seatTypeIndex and seat.types[seatTypeIndex].dynamic and pathRoute[pathNodeIndex].rideObjectID then --really just a way to only teleport canoes around, and not beds if we have a bug
            moveableSeatObject = true
        end
    end

    if moveableSeatObject then

        --clientState.moveableSeatObjectVelocity = (clientState.moveableSeatObjectVelocity or vec3(0.0,0.0,0.0)) * (1.0 - math.min(dt * speedMultiplier * 0.2, 1.0)) + (newPos - currentPos)
        --newPos = normalize(newPos + clientState.moveableSeatObjectVelocity * math.min(dt * speedMultiplier * 0.1, 1.0))

        local seatRotation = seatObject.baseRotation or seatObject.rotation

        if clientState.directionNormal then
            local leftVec = normalize(cross(seatObject.normalizedPos, clientState.directionNormal))
            local desiredSeatRotation = createUpAlignedRotationMatrix(seatObject.normalizedPos, -leftVec)
            seatRotation = mat3Slerp(seatRotation, desiredSeatRotation, math.min(dt * speedMultiplier * 1.0, 1.0))
        end

        --local dp = dot(clientState.directionNormal, seatObject.normalizedPos)
       -- if dp > -0.9 and dp < 0.9 then
       --     rotation = createUpAlignedRotationMatrix(seatObject.normalizedPos, clientState.directionNormal)
       -- end
        --[[if clientState.moveableSeatObjectVelocity then
            local leftVec = normalize(cross(seatObject.normalizedPos, clientState.moveableSeatObjectVelocity))
            local desiredSeatRotation = createUpAlignedRotationMatrix(seatObject.normalizedPos, -leftVec)
            seatRotation = mat3Slerp(seatRotation, desiredSeatRotation, math.min(dt * speedMultiplier * 0.2, 1.0))
            --local dp = dot(clientState.directionNormal, seatObject.normalizedPos)
           -- if dp > -0.9 and dp < 0.9 then
           --     rotation = createUpAlignedRotationMatrix(seatObject.normalizedPos, clientState.directionNormal)
           -- end
        end]]

        ----disabled--mj:objectLog(sapien.uniqueID, "seatObject updateMatrix:", mj:pToM(length(newPos) - 1.0))

        clientGOM:setDynamicRenderOverride(seatObject.uniqueID, true)
        clientGOM:updateMatrix(seatObject.uniqueID, newPos, seatRotation)

        local subModelTransform = clientGOM:getSubModelTransform(seatObject, "seatNode_1")
        clientState.goalRotation = seatObject.rotation * subModelTransform.rotation
        --mj:log("subModelTransform:", subModelTransform, " seatRotation:", seatRotation, " clientState.goalRotation:", clientState.goalRotation)
        clientState.goalTimer = 1.0


        local offset = vec3xMat3(mj:mToP(subModelTransform.offsetMeters), mat3Inverse(seatObject.rotation))
        setNewPos(sapien, clientState, newPos + offset)

        --clientState.pos = clientState.pos + ((newPos + offset) - clientState.pos) * math.min(dt * speedMultiplier * 1.0, 1.0)
        clientState.pos = newPos + offset
        
        clientGOM:updateMatrix(sapien.uniqueID, clientState.pos, clientState.goalRotation)
    else
        clientState.moveableSeatObjectVelocity = nil
        newPos = updateSwimState(sapien, clientState, newPos)

        local normalizedPos = normalize(newPos)
        
        setNewRotationMatrixFromDirection(sapien, clientState, normalizedPos)
        setNewPos(sapien, clientState, newPos)

        --updateWaterEmitters(sapien, clientState)
                
        clientSapien:notifyMainThreadOfFollowerPosChange(sapien.uniqueID, newPos)
    end

    return true

end

local function updateFall(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, sequenceTypeIndex)
    local sharedState = sapien.sharedState
    local orderState = nil
    local orderContext = nil

    if sharedState.orderQueue and sharedState.orderQueue[1] then
        orderState = sharedState.orderQueue[1]
        orderContext = orderState.context
    end

    if orderContext then
        local fallTimer = clientState.fallTimer
        if not fallTimer then
            fallTimer = 0.0
            clientState.fallStartPos = clientState.goalPos or sapien.pos
        end
        fallTimer = fallTimer + dt * speedMultiplier
        clientState.fallTimer = fallTimer

        local fallTargetPos = orderContext.targetPos
        local mixFraction = mjm.clamp(fallTimer, 0.0, 1.0)
        local newPos = mjm.mix(clientState.fallStartPos, fallTargetPos, mixFraction)
        --newPos = worldHelper:getBelowSurfacePos(newPos, 1.0, physicsSets.walkable)
       -- --disabled--mj:objectLog(sapien.uniqueID, "getBelowSurfacePos c:", mj:pToM(length(newPos) - 1.0))
        local heightOffset = math.sin(mixFraction * math.pi) * mj:mToP(2.0)
        newPos = newPos + sapien.normalizedPos * heightOffset
        setNewPos(sapien, clientState, newPos)
    end
end

local function moveToPos(sapien, clientState, normalizedMoveToPos, dt,  speedMultiplier)
    local newPos = clientState.goalPos or sapien.pos
    local newPosNormal = normalize(newPos)
    local walkDistanceToUse = sapienConstants:getWalkSpeed(sapien.sharedState) * dt * speedMultiplier
    local done = false

    local routeVec = normalizedMoveToPos - newPosNormal
    local distance2 = length2(routeVec)
    if distance2 < walkDistanceToUse * walkDistanceToUse or distance2 < mj:mToP(0.1) then
        newPosNormal = normalizedMoveToPos
        --newPos = worldHelper:getBelowSurfacePos(newPosNormal * length(newPos), 1.0, physicsSets.walkable)
        ----disabled--mj:objectLog(sapien.uniqueID, "getBelowSurfacePos d:", mj:pToM(length(newPos) - 1.0))
        done = true
    else
        local directionNormal = routeVec / math.sqrt(distance2)
        local movement = directionNormal * walkDistanceToUse
        newPosNormal = normalize(newPosNormal + movement)
        newPos = newPosNormal * length(newPos)--newPos = worldHelper:getBelowSurfacePos(newPosNormal * length(newPos), physicsSets.walkable)
        clientState.directionNormal = directionNormal
        --disabled--mj:objectLog(sapien.uniqueID, "setting clientState.directionNormal in moveToPos:", directionNormal)
    end

    setNewRotationMatrixFromDirection(sapien, clientState, newPosNormal)
    setNewPos(sapien, clientState, newPos)
            
    clientSapien:notifyMainThreadOfFollowerPosChange(sapien.uniqueID, newPos)

    return not done
end

local function getWalkLocation(sapien, objectPos, minDistance)
    local routeVec = objectPos - sapien.pos
    local routeLength = length(routeVec)
    if routeLength > minDistance then
        local directionNormal = routeVec / routeLength
        local shoterRouteVec = directionNormal * (routeLength - minDistance)
        local goalPos =  sapien.pos + shoterRouteVec
        return normalize(goalPos)
    end
    return nil
end

local function getConstructableTypeIndex(craftOrBuildObject)
    local constructableTypeIndex = craftOrBuildObject.sharedState.inProgressConstructableTypeIndex
    if constructableTypeIndex then
        return constructableTypeIndex
    end

    local planStates = craftOrBuildObject.sharedState.planStates
    if planStates then
        for tribeID,planStatesForTribe in pairs(planStates) do
            for j,planState in ipairs(planStatesForTribe) do
                if planState.constructableTypeIndex then 
                    return planState.constructableTypeIndex
                end
            end
        end
    end

    return nil
end

local function getBuildObjectClientState(buildObjectID)
    local buildObject = clientGOM:getObjectWithID(buildObjectID)
    if buildObject then
        local constructableTypeIndex = getConstructableTypeIndex(buildObject)
        if constructableTypeIndex then
            return clientGOM:getClientState(buildObject)
        end
    end
    return nil
end

local function updateMoveComponentAnimation(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, sequenceTypeIndex)
    local sharedState = sapien.sharedState
    local orderState = nil
    local orderContext = nil

    if sharedState.orderQueue and sharedState.orderQueue[1] then
        orderState = sharedState.orderQueue[1]
        orderContext = orderState.context
    end

    --mj:log("updateMoveComponentAnimation:", sapien.uniqueID, " orderState:", orderState)
    
    if orderContext then
        
        local normalizedSapienPos = normalize(clientState.goalPos or sapien.pos)

        if (not clientState.buildAnimationInfo) or (clientState.buildAnimationInfo.pickupPlaceholderKey ~= orderContext.pickupPlaceholderKey) then
            if orderContext.pickupPlaceholderKey then
                local pickupWalkToPos = getWalkLocation(sapien, orderContext.pickupPos, mj:mToP(0.5))
                if pickupWalkToPos then
                    clientState.buildAnimationInfo = {
                        pickupPlaceholderKey = orderContext.pickupPlaceholderKey,
                        progression = buildMoveComponentAnimationProgression.moveToPickup,
                        pickupWalkToPos = pickupWalkToPos,
                        timer = 0.0,
                    }
                else
                    clientState.buildAnimationInfo = {
                        pickupPlaceholderKey = orderContext.pickupPlaceholderKey,
                        progression = buildMoveComponentAnimationProgression.pickup,
                        timer = 0.0,
                    }
                end
            else
                clientState.buildAnimationInfo = {
                    pickupPlaceholderKey = orderContext.pickupPlaceholderKey,
                    progression = buildMoveComponentAnimationProgression.wait,
                    timer = 0.0,
                }
            end
        end


        local buildAnimationInfo = clientState.buildAnimationInfo

        if buildAnimationInfo.progression == buildMoveComponentAnimationProgression.moveToPickup then
            if not moveToPos(sapien, clientState, buildAnimationInfo.pickupWalkToPos, dt,  speedMultiplier) then
                local rotation = mat3LookAtInverse(normalize(normalize(orderContext.pickupPos) - normalizedSapienPos ), normalizedSapienPos)
                if not mj:isNan(rotation.m0) then
                    clientState.directionNormal = mat3GetRow(rotation, 2)
                end
                buildAnimationInfo.progression = buildMoveComponentAnimationProgression.pickup
                buildAnimationInfo.timer = 0.0
            end
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.pickup then
            buildAnimationInfo.timer = buildAnimationInfo.timer + dt * speedMultiplier
            if buildAnimationInfo.timer > 0.5 then
                local buildObjectClientState = getBuildObjectClientState(orderContext.planObjectID)
                if buildObjectClientState then
                    local moveGameObjectInfo = buildObjectClientState.moveObjectGameObjectInfo
                    if moveGameObjectInfo then
                        clientConstruction:hideStoreBuildObjectMoveModelIndex(orderContext.planObjectID)
                        --clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, action.types.pickupMultiAddToHeld.index, {moveGameObjectInfo}, nil)
                        buildAnimationInfo.assignedMoveObjectInfo = moveGameObjectInfo
                    end
                end
                local dropOffWalkToPos = getWalkLocation(sapien, orderContext.dropOffPos, mj:mToP(0.5))
                if dropOffWalkToPos then
                    buildAnimationInfo.progression = buildMoveComponentAnimationProgression.moveToDropOff
                    buildAnimationInfo.dropOffWalkToPos = dropOffWalkToPos
                    clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, action.types.idle.index, {buildAnimationInfo.assignedMoveObjectInfo}, nil)
                else
                    local rotation = mat3LookAtInverse(normalize(normalize(orderContext.dropOffPos) - normalizedSapienPos ), normalizedSapienPos)
                    if not mj:isNan(rotation.m0) then
                        clientState.directionNormal = mat3GetRow(rotation, 2)
                    end
                    buildAnimationInfo.progression = buildMoveComponentAnimationProgression.standAfterPickup
                    buildAnimationInfo.timer = 0.0
                    clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, action.types.moveTo.index, {buildAnimationInfo.assignedMoveObjectInfo}, nil)
                end
            end
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.standAfterPickup then
            buildAnimationInfo.timer = buildAnimationInfo.timer + dt * speedMultiplier
            if buildAnimationInfo.timer > 0.5 then
                buildAnimationInfo.progression = buildMoveComponentAnimationProgression.place
                buildAnimationInfo.timer = 0.0
                clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, action.types.place.index, {buildAnimationInfo.assignedMoveObjectInfo}, nil)
            end
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.moveToDropOff then
            if not moveToPos(sapien, clientState, buildAnimationInfo.dropOffWalkToPos, dt,  speedMultiplier) then
                local rotation = mat3LookAtInverse(normalize(normalize(orderContext.dropOffPos) - normalizedSapienPos ), normalizedSapienPos)
                if not mj:isNan(rotation.m0) then
                    clientState.directionNormal = mat3GetRow(rotation, 2)
                end
                buildAnimationInfo.progression = buildMoveComponentAnimationProgression.place
                buildAnimationInfo.timer = 0.0
                clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, action.types.place.index, {buildAnimationInfo.assignedMoveObjectInfo}, nil)
            end
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.place then
            buildAnimationInfo.timer = buildAnimationInfo.timer + dt * speedMultiplier
            if buildAnimationInfo.timer > 0.8 then
                if buildAnimationInfo.assignedMoveObjectInfo then
                    clientConstruction:showFinalLocationBuildObjectMoveModelIndex(orderContext.planObjectID)
                    clientSapienInventory:removeHeldObjectOverrides(sapien, clientState)
                    buildAnimationInfo.assignedMoveObjectInfo = nil
                    
                    local buildObjectClientState = getBuildObjectClientState(orderContext.planObjectID)
                    if buildObjectClientState and buildObjectClientState.moveObjectAfterAction then
                        buildAnimationInfo.progression = buildMoveComponentAnimationProgression.afterAction
                        buildAnimationInfo.afterAction = buildObjectClientState.moveObjectAfterAction
                    else
                        buildAnimationInfo.progression = buildMoveComponentAnimationProgression.wait
                    end
                end
            end
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.afterAction then
            buildAnimationInfo.timer = buildAnimationInfo.timer + dt * speedMultiplier
            --todo stay here until you are allowed to move the next item

        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.wait then
            buildAnimationInfo.timer = buildAnimationInfo.timer + dt * speedMultiplier
        end
        
        setNewRotationMatrixFromDirection(sapien, clientState, normalizedSapienPos)
    end

end

local function updateHeldObjectAction(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, sequenceTypeIndex)
    if not clientState.craftingFocusObjectID then
        
        local orderContext = nil
        local sapienSharedState = sapien.sharedState

        if sapienSharedState.orderQueue and sapienSharedState.orderQueue[1] then
            orderContext = sapienSharedState.orderQueue[1].context
        end

        if orderContext then
            
            local orderObject = clientGOM:getObjectWithID(orderContext.planObjectID)
            if orderObject then
                clientState.craftingFocusObjectID = orderContext.planObjectID
            
                local constructableTypeIndex = getConstructableTypeIndex(orderObject)
                local constructableType = constructable.types[constructableTypeIndex]

                if constructableType then
                    local handObjectInfos = {}
                    local placementInfos = {}
                    local foundCount = 0

                    if constructableType.requiredTools and (not constructableType.dontPickUpRequiredTool) then
                        
                        local toolGameObjectInfo = clientCraftArea:getInUseToolGameObjectInfo(orderContext.planObjectID)
                        if toolGameObjectInfo then
                            foundCount = foundCount + 1
                            handObjectInfos[foundCount] = toolGameObjectInfo
                            clientConstruction:setToolHidden(orderObject, true)
                        end
                    end

                    if constructableType.attachResourceToHandIndex then
                        local inUseResources = clientCraftArea:getInUseResourceGameObjectInfos(clientState.craftingFocusObjectID)

                        if inUseResources and inUseResources[constructableType.attachResourceToHandIndex] then
                            foundCount = foundCount + 1
                            handObjectInfos[foundCount] = inUseResources[constructableType.attachResourceToHandIndex]
                            local placementInfo = {
                                offset = constructableType.attachResourceOffset,
                                rotation = constructableType.attachResourceRotation,
                            }
                            placementInfos[foundCount] = placementInfo
                            clientConstruction:setResourceHiddenIndex(orderObject, constructableType.attachResourceToHandIndex)
                            clientState.hiddenInUseResourceIndex = constructableType.attachResourceToHandIndex
                        end
                    end

                    if constructableType.temporaryToolObjectType then
                        --mj:log("constructableType.temporaryToolObjectType")
                        foundCount = foundCount + 1
                        handObjectInfos[foundCount] = {
                            objectTypeIndex = constructableType.temporaryToolObjectType,
                        }
                        local placementInfo = {
                            offset = constructableType.temporaryToolOffset,
                            rotation = constructableType.temporaryToolRotation,
                        }
                        placementInfos[foundCount] = placementInfo
                    end

                    if foundCount > 0 then
                        clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, actionTypeIndex, handObjectInfos, placementInfos)
                    end
               -- else
                    --mj:log("non craft area orderContext:", orderContext)
                end
            end
            
        end
    end
end




local function updateThrow(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, sequenceTypeIndex)
    
    local sharedState = sapien.sharedState

    if sharedState.orderQueue and sharedState.orderQueue[1] then
        local orderContext = sharedState.orderQueue[1].context
        if orderContext then
            local targetObject = clientGOM:getObjectWithID(orderContext.planObjectID)
            if targetObject then
                local directionNormal = normalize(normalize(targetObject.pos) - sapien.normalizedPos)
                clientState.directionNormal = directionNormal
                setNewRotationMatrixFromDirection(sapien, clientState, sapien.normalizedPos)
            end
        end
    end
end


local function updateTurnOrWave(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, sequenceTypeIndex) --also recruit, defend

   -- mj:debug("updateTurnOrWave:", sapien.uniqueID)
    
    local actionModifiers = sapien.sharedState.actionModifiers
    if sapien.sharedState.seatObjectID or (actionModifiers and actionModifiers[action.modifierTypes.sit.index]) then
        return
    end
    
    local posToUse = clientState.goalPos or sapien.pos
    local normalizedSapienPos = normalize(posToUse)

    local sapienEyePos = (posToUse + normalizedSapienPos * sapienConstants:getEyeHight(sapien.sharedState.lifeStageIndex, false))
    local serverLookAtPos = clientSapien:getLookAtPoint(clientState.serverLookAtPoint, clientState.serverLookAtObjectID, sapienEyePos, clientState.directionNormal)
    if serverLookAtPos then
        local normalizedLookAtPos = normalize(serverLookAtPos)
        local lookVec = normalizedLookAtPos - normalizedSapienPos
        local lookLength = length(lookVec)
        if lookLength > 0.0 then
            local dp = dot(clientState.directionNormal, normalizedSapienPos)
            if dp < 0.6 then
                clientState.directionNormal = lookVec / lookLength
                setNewRotationMatrixFromDirection(sapien, clientState, normalizedSapienPos)
                --mj:log(sapien.uniqueID, " setting clientState.directionNormal in updateTurnOrWave:", clientState.directionNormal)
            end
        end
    end
end 


local function snapToPos(sapien, clientState, pos, rotation)
    --disabled--mj:objectLog(sapien.uniqueID, "snapToPos:", pos, " rot:", rotation, " previousPos:", sapien.pos, " posHeightDifference:", mj:pToM(length(pos) - length(sapien.pos)))
	--[[if sapien.uniqueID == mj.debugObject then
        mj:error("snap")
    end]]
    if mj:isNan(rotation.m0) then
        mj:error("rotation is nan")
        error()
    end
    
    local sharedState = sapien.sharedState
    local actionState = sharedState.actionState
    if actionState and actionState.path and actionState.pathNodeIndex then
        --local nodes = actionState.path.nodes
        clientState.pathNodeIndex = actionState.pathNodeIndex
        --clientState.nodeDistance = mjm.length(nodes[clientState.pathNodeIndex].pos - sapien.pos)
        clientState.nodeDistance = 0.0
        clientState.nodeTravelDistance = 0.0
        clientState.lastReaclculatedNodeIndex = clientState.pathNodeIndex
        clientState.pathDone = nil
    end

    clientGOM:updateMatrix(sapien.uniqueID, pos, rotation)
    resetGoalMatrix(sapien, clientState)
    clientSapien:notifyMainThreadOfFollowerPosChange(sapien.uniqueID, pos)
end

function clientSapienAnimation:snapToServerPos(sapien, clientState, pos, rotation)
    updateMoveToPos(sapien, clientState, pos)
    local newPos = clientState.moveToPosAvoidingObstacles
    newPos = updateSwimState(sapien, clientState, newPos)
    snapToPos(sapien, clientState, newPos, rotation)
end

local function removeAnyHaulingObjectDecorations(sapien, clientState)
    --mj:log("removeAnyHaulingObjectDecorations")
    if clientState.currentHaulingObjectID then
        --mj:log("removeAnyHaulingObjectDecorations b")
        local haulingObjectClientState = clientGOM.clientStates[clientState.currentHaulingObjectID]
        if (not haulingObjectClientState) or haulingObjectClientState.currentHaulingSapienID == sapien.uniqueID then
            --mj:log("removeAnyHaulingObjectDecorations remove rope from object")
            if haulingObjectClientState then
                haulingObjectClientState.currentHaulingSapienID = nil
            end
            clientGOM:removeSubModelForKey(clientState.currentHaulingObjectID, "rope")
            --clientGOM:setDynamicRenderOverride(clientState.currentHaulingObjectID, false)
            --mj:log("correctly removed rope model")
        end

        clientState.currentHaulingObjectID = nil
    end

    if clientState.ropeModelsAdded then
        --mj:log("removeAnyHaulingObjectDecorations remove rope from sap")
        clientState.ropeModelsAdded = nil
        clientGOM:removeSubModelForKey(sapien.uniqueID, "haulRope1")
        clientGOM:removeSubModelForKey(sapien.uniqueID, "haulRope2")
    end
    
end


local snapDistanceMax2Moving = mj:mToP(10.0) * mj:mToP(10.0)
--local snapDistanceMax2Still = mj:mToP(0.5) * mj:mToP(0.5)


local animationInfosByAnimationGroupTypeKey = {}
local updateFunctionsByActionSequenceType = {}
local actionFinishedFunctionsByActionSequenceType = {}


function clientSapienAnimation:serverUpdate(sapien, sharedState, clientState, sequenceTypeIndex, actionTypeIndex, serverPos, serverRotation)

    --[[if notifications then
        for i,notificationInfo in ipairs(notifications) do 
            if notificationInfo.notificationTypeIndex == notification.types.snapPosition.index then
                updateMoveToPos(sapien, clientState, serverPos)
                local newPos = clientState.moveToPosAvoidingObstacles
                newPos = updateSwimState(sapien, clientState, newPos)
                snapToPos(sapien, clientState, newPos, serverRotation)
            end
        end
    end]]


    if clientState.currentActionSequenceTypeIndex ~= sequenceTypeIndex then
        --mj:log("clientState.currentActionSequenceTypeIndex:", clientState.currentActionSequenceTypeIndex, " ~= sequenceTypeIndex:", sequenceTypeIndex)
        if clientState.currentActionSequenceTypeIndex then
            local actionFinishedFunction = actionFinishedFunctionsByActionSequenceType[clientState.currentActionSequenceTypeIndex]
            if actionFinishedFunction then
                actionFinishedFunction(sapien, clientState)
            end
        else
            local actionFinishedFunction = actionFinishedFunctionsByActionSequenceType[actionSequence.types.idle.index]
            if actionFinishedFunction then
                actionFinishedFunction(sapien, clientState)
            end
        end

        --snapToPos(sapien, clientState, serverPos, serverRotation)
        clientState.currentActionSequenceTypeIndex = sequenceTypeIndex
    end
    
    --[[if sequenceTypeIndex then
        if not clientSapienAnimation.debugServerState then
            local posDistance2 = length2(sapien.pos - serverPos)
            if actionTypeIndex == action.types.moveTo.index then
                if posDistance2 > snapDistanceMax2Moving then
                    snapToPos(sapien, clientState, serverPos, serverRotation)
                end
            else
                if posDistance2 > snapDistanceMax2Still then
                    snapToPos(sapien, clientState, serverPos, serverRotation)
                end
            end
        else
            snapToPos(sapien, clientState, serverPos, serverRotation)
        end
    end]]

    if sequenceTypeIndex then
        if not clientSapienAnimation.debugServerState then
            if action.types[actionTypeIndex].isMovementAction then
                local posDistance2 = length2(sapien.pos - serverPos)
            
                if posDistance2 > snapDistanceMax2Moving then
                    snapToPos(sapien, clientState, serverPos, serverRotation)
                end
           -- elseif clientState.prevActionTypeIndex == action.types.moveTo.index then
                --snapToPos(sapien, clientState, serverPos, serverRotation)
            end
        else
            snapToPos(sapien, clientState, serverPos, serverRotation)
        end
    end

    if (not sharedState.haulingObjectID) or sharedState.seatObjectID then
        removeAnyHaulingObjectDecorations(sapien, clientState)
    end
end

local clientSapienAnimationCarryTypes = mj:enum {
    "none",
    "smallSingle",
    "smallMulti",
    "high",
    "highSmall",
    "single",
    "highMedium",
}

function clientSapienAnimation:sapienLoaded(sapien, clientState, pos, rotation, scale)
    local actionState = sapien.sharedState.actionState
    
    if (not actionState) or (not actionState.sequenceTypeIndex) or (not actionSequence.types[actionState.sequenceTypeIndex].snapToOrderObjectIndex) then
        updateMoveToPos(sapien, clientState, pos)
        
        local newPos = clientState.moveToPosAvoidingObstacles
        newPos = updateSwimState(sapien, clientState, newPos)

        
        --[[if sapien.uniqueID == "13a735" then
            mj:log("newPos:", newPos)
            mj:log("pos:", pos)
            mj:log("clientState.moveToPosAvoidingObstacles:", clientState.moveToPosAvoidingObstacles)
        end]]

       -- local normalizedPos = normalize(newPos)
       -- setNewRotationMatrixFromDirection(sapien, clientState, normalizedPos) --commented out 5/5/22 as it causes sitting sapiens to rotate to invalid positions on world reload. Could limit to seated sapiens.

        setNewPos(sapien, clientState, newPos)
        
        clientState.pos = newPos
        clientGOM:updateMatrix(sapien.uniqueID, newPos, sapien.rotation)
        
        updateWaterEmitters(sapien, clientState)
    end
end

function clientSapienAnimation:sapienUnLoaded(sapien, clientState)
    removeAnyHaulingObjectDecorations(sapien, clientState)
end

local function updatePaddle(sapien, clientState, actionTypeIndex) --the API that adds held objects for crafting should probably to be rewritten to support this, but for now, let's just call this hacky function
    local function shouldHavePaddle()
        return sapien.sharedState.seatObjectID and (actionTypeIndex == action.types.moveTo.index or actionTypeIndex == action.types.dragObject.index)
    end
    
    if not clientState.paddleHeldObjectAdded then
        if shouldHavePaddle() then --todo we don't want a paddle when riding horses
            clientState.paddleHeldObjectAdded = true
            local placementInfos = {
                {
                    offset = vec3(0.0,0.0,0.0),
                    rotation = mat3Rotate(mat3Identity, -math.pi * 0.5, vec3(1.0,0.0,0.0)),
                    placeholderKey = "leftHandObject",
                }
            }
            local handObjectInfos = {
                {
                    objectTypeIndex = gameObject.types.paddle.index,
                }
            }

            clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, actionTypeIndex, handObjectInfos, placementInfos)

        end
    elseif clientState.paddleHeldObjectAdded then
        if not shouldHavePaddle() then
            clientState.paddleHeldObjectAdded = false
            clientSapienInventory:removeHeldObjectOverrides(sapien, clientState)
        end
    end
end

function clientSapienAnimation:update(sapien, dt, speedMultiplier, clientState)
    local actionState = sapien.sharedState.actionState
    local actionTypeIndex = nil

    local sapienMoved = false
    
    if actionState and actionState.sequenceTypeIndex then
        local actionSequenceActions = actionSequence.types[actionState.sequenceTypeIndex].actions
        actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]

        if action.types[actionTypeIndex].isMovementAction then
            sapienMoved = clientSapienAnimation:updateMove(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, actionState.sequenceTypeIndex)
        else
            clientState.animationSpeedMultiplier = 1.0
            local updateFunction = updateFunctionsByActionSequenceType[actionState.sequenceTypeIndex]
            if updateFunction then
                updateFunction(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, actionState.sequenceTypeIndex)
            end
        end
    else
        clientState.animationSpeedMultiplier = 1.0
        local updateFunction = updateFunctionsByActionSequenceType[actionSequence.types.idle.index]
        if updateFunction then
            updateFunction(sapien, dt, speedMultiplier, actionState, clientState, actionTypeIndex, actionSequence.types.idle.index)
        end
    end

    updatePaddle(sapien, clientState, actionTypeIndex)
    
    updateWaterEmitters(sapien, clientState)

    local animationGroupKey = sapienConstants:getAnimationGroupKey(sapien.sharedState)
    local animationInfo = animationInfosByAnimationGroupTypeKey[animationGroupKey]

    --mj:log("animationGroupKey:", animationGroupKey)
    --mj:log("animationInfo:", animationInfo)

    local newAnimationIndex = nil
    local animationSpeedMultiplier = clientState.animationSpeedMultiplier or 1.0

    local function getClientSapienAnimationCarryType()
        if clientState.heldObjectInfos then
            if clientState.carryType == storage.carryTypes.small then
                if #clientState.heldObjectInfos == 1 then
                    return clientSapienAnimationCarryTypes.smallSingle
                else
                    return clientSapienAnimationCarryTypes.smallMulti
                end
            else
                if clientState.carryType == storage.carryTypes.high then
                    return clientSapienAnimationCarryTypes.high
                elseif clientState.carryType == storage.carryTypes.highSmall then
                    return clientSapienAnimationCarryTypes.highSmall
                elseif clientState.carryType == storage.carryTypes.highMedium then
                    return clientSapienAnimationCarryTypes.highMedium
                else
                    return clientSapienAnimationCarryTypes.single
                end
            end
        else
            return clientSapienAnimationCarryTypes.none
        end
    end

    local function setAnimationFromActionType(actionTypeIndexToUse_)
        local actionTypeIndexToUse = actionTypeIndexToUse_ or action.types.idle.index
        local animationsByCarryType = nil

        if actionTypeIndexToUse == action.types.moveTo.index then
           -- --disabled--mj:objectLog(sapien.uniqueID, "moveTo")
            if clientState.pathDone or clientState.nodeDistance == 0.0 then
                ----disabled--mj:objectLog(sapien.uniqueID, "pathDone")
                actionTypeIndexToUse = action.types.idle.index
            elseif (not actionState) or (not actionState.path) or (not actionState.path.nodes) or #actionState.path.nodes == 0 then
                actionTypeIndexToUse = action.types.idle.index
            end

       -- elseif actionTypeIndexToUse == action.types.idle.index then
            ----disabled--mj:objectLog(sapien.uniqueID, "not moveTo")
            
            --[[if (not clientState.pathDone) and actionState and actionState.path and actionState.path.nodes and #actionState.path.nodes > 0 and clientState.nodeDistance > 0.0 then --this causes running on the spot issues when crafting at campfires
                actionTypeIndexToUse = action.types.moveTo.index
            end]]
        end

        if sapien.sharedState.seatObjectID then
            if actionTypeIndexToUse ~= action.types.moveTo.index and actionTypeIndexToUse ~= action.types.dragObject.index then
                actionTypeIndexToUse = action.types.idle.index
            end
            clientState.swimming = false
        end

        local clientSapienAnimationCarryType = getClientSapienAnimationCarryType()

        local complexFunc = nil
        if clientState.swimming then
            --mj:log("swimming:", actionTypeIndexToUse)
            complexFunc = animationInfo.swimComplexAnimationsByActionType[actionTypeIndexToUse]
        else
            --mj:log("not swimming:", actionTypeIndexToUse)
            complexFunc = animationInfo.complexAnimationsByActionType[actionTypeIndexToUse]
        end

        if complexFunc then
            animationsByCarryType = complexFunc(sapien, clientState, dt, speedMultiplier, actionTypeIndexToUse, clientSapienAnimationCarryType)
            --mj:log("complexFunc:", animationsByCarryType)
        else
            if clientState.swimming then
                animationsByCarryType = animationInfo.swimAnimationsByCarryTypeByActionType[actionTypeIndexToUse]
                if not animationsByCarryType then
                    animationsByCarryType = animationInfo.swimAnimationsByCarryTypeByActionType[action.types.idle.index]
                end
            else
                animationsByCarryType = animationInfo.animationsByCarryTypeByActionType[actionTypeIndexToUse]
                if not animationsByCarryType then
                    animationsByCarryType = animationInfo.animationsByCarryTypeByActionType[action.types.idle.index]
                end
            end
        end
        
        newAnimationIndex = animationsByCarryType[clientSapienAnimationCarryType]
        if not newAnimationIndex then
            newAnimationIndex = animationsByCarryType[clientSapienAnimationCarryTypes.none]
        end
        ----disabled--mj:objectLog(sapien.uniqueID, "newAnimationIndex:", newAnimationIndex)
        
        if clientState.swimming then
            animationSpeedMultiplier = 1.0 / 3.0
        end
    end
    
    --local animations = animationGroups.groups[animationGroupIndex].animations
   -- newAnimationIndex = animationIndexesByKey.swim

    if debugAnimationActionTypeIndex and sapien.sharedState.waitOrderSet then
        actionTypeIndex = debugAnimationActionTypeIndex
    end
    
    if clientState.buildAnimationInfo then
        local buildAnimationInfo = clientState.buildAnimationInfo
        if buildAnimationInfo.progression == buildMoveComponentAnimationProgression.moveToPickup then
            setAnimationFromActionType(action.types.moveTo.index)
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.pickup then
            setAnimationFromActionType(action.types.pickup.index)
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.standAfterPickup then
            setAnimationFromActionType(action.types.idle.index)
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.moveToDropOff then
            setAnimationFromActionType(action.types.moveTo.index)
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.place then
            setAnimationFromActionType(action.types.place.index)
        elseif buildAnimationInfo.progression == buildMoveComponentAnimationProgression.afterAction then
            setAnimationFromActionType(buildAnimationInfo.afterAction.actionTypeIndex)
        else
            setAnimationFromActionType(action.types.idle.index)
        end
    elseif clientState.plantAnimationInfo then
        local plantAnimationInfo = clientState.plantAnimationInfo
        if plantAnimationInfo.progression == clientPlantAnimationProgression.moveToDig then
            setAnimationFromActionType(action.types.moveTo.index)
        elseif plantAnimationInfo.progression == clientPlantAnimationProgression.dig then
            setAnimationFromActionType(action.types.dig.index)
        end
    else
        setAnimationFromActionType(actionTypeIndex)
    end

    local moveableSeatObject = false
    local seatObject = sapien.sharedState.seatObjectID and clientGOM:getObjectWithID(sapien.sharedState.seatObjectID)
    if seatObject then
        local seatTypeIndex = gameObject.types[seatObject.objectTypeIndex].seatTypeIndex
        if seatTypeIndex and seat.types[seatTypeIndex].dynamic then
            moveableSeatObject = true
        end
    end

    if moveableSeatObject then
        local seatRotation = seatObject.baseRotation or seatObject.rotation
        if clientState.directionNormal then
            local leftVec = normalize(cross(seatObject.normalizedPos, clientState.directionNormal))
            local desiredSeatRotation = createUpAlignedRotationMatrix(seatObject.normalizedPos, -leftVec)
            seatRotation = mat3Slerp(seatRotation, desiredSeatRotation, math.min(dt * speedMultiplier * 0.1, 1.0))
            --[[local dp = dot(clientState.directionNormal, seatObject.normalizedPos)
            if dp > -0.9 and dp < 0.9 then
                rotation = createUpAlignedRotationMatrix(seatObject.normalizedPos, clientState.directionNormal)
            end]]
        end

        local subModelTransform = clientGOM:getSubModelTransform(seatObject, "seatNode_1")
        clientState.goalRotation = seatObject.rotation * subModelTransform.rotation
        --mj:log("subModelTransform:", subModelTransform, " seatRotation:", seatRotation, " clientState.goalRotation:", clientState.goalRotation)
        clientState.goalTimer = 1.0

        local offset = vec3xMat3(mj:mToP(subModelTransform.offsetMeters), mat3Inverse(seatObject.rotation))

        local newPos = seatObject.pos + offset
        setNewPos(sapien, clientState, newPos)
        clientState.pos = newPos
        clientGOM:updateMatrix(sapien.uniqueID, clientState.pos, clientState.goalRotation)
    end

    updateMatrix(sapien, dt, speedMultiplier, clientState)

    if sapienMoved then --we jump through hoops to do this down here after updateMatrix so that the sapien's pos is up to date for the sled offset
        updateHaulingObjectPos(sapien, dt, speedMultiplier, clientState)
    end

    if not newAnimationIndex then
        mj:error("no newAnimationIndex. clientState:", clientState)
    end

    --mj:log("animationGroups:", animationGroups)
    --mj:log("animationGroupKey:", animationGroupKey)

    clientObjectAnimation:changeAnimation(sapien, newAnimationIndex, animationGroups.groups[animationGroupKey].index, sapienConstants:getAnimationSpeedMultiplier(sapien.sharedState) * animationSpeedMultiplier)
end

function clientSapienAnimation:init(clientGOM_, clientSapien_)
    clientGOM = clientGOM_
    clientSapien = clientSapien_


    local sapienAnimationGroups = {
        "girlSapien",
        "boySapien",
        "femaleSapien",
        "maleSapien",
    }

    --mj:log("sapienAnimationGroups:", sapienAnimationGroups)

    for i, animationGroupKey in ipairs(sapienAnimationGroups) do
        local animationInfo = {}
        animationInfosByAnimationGroupTypeKey[animationGroupKey] = animationInfo
        --mj:log("animationGroupKey:", animationGroupKey)
        --mj:log("animationGroups:", animationGroups)
        local animationTables = animationGroups.groups[animationGroupKey].animations
        local animationIndexesByKey = {}
        for j,v in ipairs(animationTables) do
            animationIndexesByKey[v.key] = j
        end

        --mj:log("animationIndexesByKey:", animationIndexesByKey)

--        animationInfo.animations = animations

        local standIdleAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.stand,
            [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey.stand,
            [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.smallCarry,
            [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.highCarry,
            [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.highSmallCarry,
            [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.highMediumCarry,
            [clientSapienAnimationCarryTypes.single] = animationIndexesByKey.standCarry,
        }
        local sneakIdleAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.sneakStand,
            [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey.sneakStand,
            [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.sneakStandSmallCarry,
            [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.sneakStandHighCarry,
            [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.sneakStandHighSmallCarry,
            [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.sneakStandHighMediumCarry,
            [clientSapienAnimationCarryTypes.single] = animationIndexesByKey.sneakStandCarry,
        }
        
        local treadWaterAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.treadWater,
            [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey.treadWater,
            [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.treadWaterSmallCarry,
            [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.treadWaterHighCarry,
            [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.treadWaterHighSmallCarry,
            [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.treadWaterHighMediumCarry,
            [clientSapienAnimationCarryTypes.single] = animationIndexesByKey.treadWaterCarry,
        }

        local sitIdleAnimationsArrayByCarryType = {}
        local sitWaveAnimationsArrayByCarryType = {}

        
        local sitAnimations = mj:enum {
            "sitFocus",
            "sit1",
            "sit2",
            "sit3",
            "sit4",
            "sitLowSeat1",
        }

        local sitGroundAnimations = {
            sitAnimations.sitFocus,
            sitAnimations.sit1,
            sitAnimations.sit2,
            sitAnimations.sit3,
            sitAnimations.sit4
        }

        local sitAnimationsCrossLegged = {
            sitAnimations.sitFocus,
            sitAnimations.sit2,
            sitAnimations.sit3,
        }

        local sitAnimationsLowSeat = {
            sitAnimations.sitLowSeat1,
        }

        for j,sitAnimationName in ipairs(sitAnimations) do

            sitIdleAnimationsArrayByCarryType[j] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey[sitAnimationName],
                [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey[sitAnimationName],
                [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey[sitAnimationName],
                [clientSapienAnimationCarryTypes.high] = animationIndexesByKey[sitAnimationName],
                [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey[sitAnimationName],
                [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey[sitAnimationName],
                [clientSapienAnimationCarryTypes.single] = animationIndexesByKey[sitAnimationName],
            }

            sitWaveAnimationsArrayByCarryType[j] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey[sitAnimationName .. "Wave"],
            }

        end
        

        local crouchIdleAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.crouchSmallCarrySingle,
            [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey.crouchSmallCarrySingle,
            [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.crouchSmallCarryMulti,
            [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.crouchHighCarry,
            [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.crouchHighSmallCarry,
            [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.crouchHighMediumCarry,
            [clientSapienAnimationCarryTypes.single] = animationIndexesByKey.crouchSingleCarry,
        }

        
        local function getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)

            local function resetAnimationtimer()
                clientState.randomAnimationChangeTimer = 10.0 + 10.0 * rng:randomValue()
            end

            if not clientState.randomAnimationChangeTimer then
                clientState.currentSitAnimationIndex = nil
                resetAnimationtimer()
            else
                clientState.randomAnimationChangeTimer = clientState.randomAnimationChangeTimer - dt * speedMultiplier
                if clientState.randomAnimationChangeTimer < 0.0 then
                    clientState.currentSitAnimationIndex = nil
                    resetAnimationtimer()
                end
            end

            local availableSitAnimations = sitGroundAnimations

            if sapien.sharedState.seatObjectID and sapien.sharedState.seatNodeTypeIndex and seat.nodeTypes[sapien.sharedState.seatNodeTypeIndex] then
                if seat.nodeTypes[sapien.sharedState.seatNodeTypeIndex].isFlatSurface then
                    availableSitAnimations = sitAnimationsCrossLegged
                else
                    availableSitAnimations = sitAnimationsLowSeat
                end
            end

            --local actionModifiers = sapien.sharedState.actionModifiers

            --[[if actionModifiers then
                local sitInfo = actionModifiers[action.modifierTypes.sit.index]
                if sitInfo then
                    if sitInfo.seatObjectTypeIndex then
                        if sitInfo.seatObjectTypeIndex == gameObject.types.hayBed.index or sitInfo.seatObjectTypeIndex == gameObject.types.woolskinBed.index then
                            availableSitAnimations = sitAnimationsCrossLegged
                        else
                            availableSitAnimations = sitAnimationsLowSeat
                        end
                    end
                end
            end]]
            
           -- local actionModifiers = sapien.sharedState.actionModifiers
            --mj:log("actionModifiers:", sapien.uniqueID, ":", actionModifiers)

            if not clientState.currentSitAnimationIndex or clientState.currentSitAnimationIndex > #availableSitAnimations then
                clientState.currentSitAnimationIndex = rng:randomInteger(#availableSitAnimations) + 1
            end

            local addWave = (actionTypeIndex == action.types.wave.index)
            if not addWave then
                local multitaskState = sapien.sharedState.multitaskState
                if multitaskState and multitaskState.orderMultitaskTypeIndex == order.multitaskTypes.social.index then
                    local context = multitaskState.context
                    if context then
                        local socialInteractionInfo = context.socialInteractionInfo
                        if socialInteractionInfo then
                            if socialInteractionInfo.gestureTypeIndex == social.gestures.wave.index then
                                addWave = true
                            end
                        end
                    end
                    ----disabled--mj:objectLog(sapien.uniqueID, "adding wave animation due to multitask")
                end
            end

            if addWave then
                return sitWaveAnimationsArrayByCarryType[availableSitAnimations[clientState.currentSitAnimationIndex]]
            end

            return sitIdleAnimationsArrayByCarryType[availableSitAnimations[clientState.currentSitAnimationIndex]]
        end
        
        local function getCrouchIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
            return crouchIdleAnimationsByCarryType
        end

        local function getStandIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)

            if sapien.sharedState.seatObjectID then
                return getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
            end

            local actionModifiers = sapien.sharedState.actionModifiers
            if actionModifiers then
                if actionModifiers[action.modifierTypes.sit.index] then
                    return getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
                elseif actionModifiers[action.modifierTypes.crouch.index] then
                    return getCrouchIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
                end
                if actionModifiers[action.modifierTypes.sneak.index] then
                    return sneakIdleAnimationsByCarryType
                end
            end
            return standIdleAnimationsByCarryType
        end

        
        local walkAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.walk,
            [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey.walk,
            [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.walkSmallCarry,
            [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.walkHighCarry,
            [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.walkHighSmallCarry,
            [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.walkHighMediumCarry,
            [clientSapienAnimationCarryTypes.single] = animationIndexesByKey.walkCarry,
        }

        local swimAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.swim,
            [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey.swim,
            [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.swimSmallCarry,
            [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.swimHighCarry,
            [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.swimHighSmallCarry,
            [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.swimHighMediumCarry,
            [clientSapienAnimationCarryTypes.single] = animationIndexesByKey.swimCarry,
        }

        
        local walkWaveAnimationsByCarryType = {
            [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.walkWave,
        }


        animationInfo.animationsByCarryTypeByActionType = {
            [action.types.chop.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.chop,
            },
            [action.types.takeOffTorsoClothing.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.takeOffTorsoClothing,
            },
            [action.types.putOnTorsoClothing.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.putOnTorsoClothing,
            },
            [action.types.selfApplyOralMedicine.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.applyMedicine,
            },
            [action.types.selfApplyTopicalMedicine.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.applyMedicine,
            },
            [action.types.otherApplyOralMedicine.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.applyMedicine,
            },
            [action.types.otherApplyTopicalMedicine.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.applyMedicine,
            },
            [action.types.pullOut.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.pullWeeds,
            },
            [action.types.dig.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.crouchDig,
            },
            [action.types.mine.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.mine,
            },
            [action.types.clear.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.pullWeeds,
            },
            --[[[action.types.sleep.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.sleep,
            },]]
            [action.types.gather.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.reachUp,
            },
            [action.types.gatherBush.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.gatherBush,
            },
            [action.types.fall.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.fall,
            },
            [action.types.eat.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.eat,
            },
            [action.types.playFlute.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.playFlute,
            },
            [action.types.playDrum.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.playDrum,
            },
            [action.types.playBalafon.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.playBalafon,
            },
            [action.types.pickup.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.pickup,
            },
            [action.types.place.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.place,
            },
            [action.types.light.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.light,
            },
            [action.types.knap.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.knap,
            },
            --[[[action.types.knapCrude.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.knapCrude,
            },]]
            [action.types.grind.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.grind,
            },
            [action.types.patDown.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.patDown,
            },
            [action.types.inspect.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.standInspect,
            },
            [action.types.scrapeWood.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.scrapeWood,
            },
            [action.types.extinguish.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.kick,
            },
            [action.types.destroyContents.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.kick,
            },
            [action.types.butcher.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.butcher,
            },
            [action.types.pickupMultiCrouch.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.pickupSmallCarry,
                [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.pickupSmallCarry,
                [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.pickupHighCarry,
                [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.pickupHighSmallCarry,
                [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.pickupHighMediumCarry,
            },
            [action.types.pickupMultiAddToHeld.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.addToSmallCarry,
                [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.addToSmallCarry,
                [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.addToHighCarry,
                [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.addToHighSmallCarry,
                [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.addToHighMediumCarry,
            },
            [action.types.placeMultiCrouch.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.placeCrouchSmallCarry,
                [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.placeCrouchSmallCarry,
                [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.placeCrouchHighCarry,
                [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.placeCrouchHighSmallCarry,
                [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.placeCrouchHighMediumCarry,
            },
            [action.types.placeMultiFromHeld.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.removeFromSmallCarry,
                [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey.removeFromSmallCarry,
                [clientSapienAnimationCarryTypes.high] = animationIndexesByKey.removeFromHighCarry,
                [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey.removeFromHighSmallCarry,
                [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey.removeFromHighMediumCarry,
            },
            [action.types.fireStickCook.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.fireStickCook,
            },
            [action.types.smeltMetal.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.fireStickCook,
            },
            [action.types.recruit.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.wave,
            },
            [action.types.greet.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.wave,
            },
            [action.types.banish.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.kick, --todo
            },
            [action.types.fight.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.fightStance, --todo
            },
            [action.types.fightFollowThrough.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.punch, --todo
            },
           --[[ [action.types.defend.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.fightStance, --todo
            },]]
            [action.types.potteryCraft.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.pottery,
            },
            [action.types.toolAssembly.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.toolAssembly,
            },
            [action.types.spinCraft.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.toolAssembly,
            },
            [action.types.thresh.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.thresh,
            },
            [action.types.smithHammer.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.smithHammer,
            },
            [action.types.chiselStone.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.chisel,
            },
            [action.types.dragObject.index] = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.dragObjectWalk,
            },
        }
        

        animationInfo.swimAnimationsByCarryTypeByActionType = mj:cloneTable(animationInfo.animationsByCarryTypeByActionType)
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.idle.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.recruit.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.banish.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.fight.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.defend.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.greet.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.inspect.index] = treadWaterAnimationsByCarryType
        animationInfo.swimAnimationsByCarryTypeByActionType[action.types.turn.index] = treadWaterAnimationsByCarryType
        

        local walkRunVariantsInPriorityOrder = {}
        local function addWalkOrRunVariant(baseName)

            local smallCarryAnimationName = baseName .. "SmallCarry"
            local highCarryAnimationName = baseName .. "HighCarry"
            local highSmallCarryAnimationName = baseName .. "HighSmallCarry"
            local highMediumCarryAnimationName = baseName .. "HighMediumCarry"
            local carryAnimationName = baseName .. "Carry"
            local waveAnimationName = baseName .. "Wave"

            local actionModifierTypeIndex = action.modifierTypes[baseName].index

           --[[ local test = {
                [clientSapienAnimationCarryTypes.none] = animationIndexesByKey[baseName],
                [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey[baseName],
                [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey[smallCarryAnimationName],
            }
            mj:log("addWalkOrRunVariant:", baseName, " test:", test)]]

           table.insert(walkRunVariantsInPriorityOrder, {
                actionModifierTypeIndex = actionModifierTypeIndex,
                animationsByCarryType = {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey[baseName],
                    [clientSapienAnimationCarryTypes.smallSingle] = animationIndexesByKey[baseName],
                    [clientSapienAnimationCarryTypes.smallMulti] = animationIndexesByKey[smallCarryAnimationName],
                    [clientSapienAnimationCarryTypes.high] = animationIndexesByKey[highCarryAnimationName],
                    [clientSapienAnimationCarryTypes.highSmall] = animationIndexesByKey[highSmallCarryAnimationName],
                    [clientSapienAnimationCarryTypes.highMedium] = animationIndexesByKey[highMediumCarryAnimationName],
                    [clientSapienAnimationCarryTypes.single] = animationIndexesByKey[carryAnimationName],
                },
                waveAnimationsByCarryType = {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey[waveAnimationName],
                }
            })
        end

        addWalkOrRunVariant("sneak")
        addWalkOrRunVariant("jog")
        addWalkOrRunVariant("run")
        addWalkOrRunVariant("slowWalk")
        addWalkOrRunVariant("sadWalk")
        --addWalkOrRunVariant("dragObjectWalk")
        

        animationInfo.complexAnimationsByActionType = {
            
            [action.types.sit.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                return getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
            end,
            
            [action.types.wave.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)

                if sapien.sharedState.seatObjectID or action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                    return getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
                end

                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.wave,
                }
            end,

            [action.types.sleep.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)

                if clientState.sleepRandomIndex then
                    clientState.sleepRandomIndexTimer = clientState.sleepRandomIndexTimer - dt * speedMultiplier
                    if clientState.sleepRandomIndexTimer <= 0 then
                        clientState.sleepRandomIndex = nil
                    end
                end

                if not clientState.sleepRandomIndex then
                    clientState.sleepRandomIndex = rng:integerForUniqueID(sapien.uniqueID, 6367 + math.floor(logic.worldTime), 4)
                    clientState.sleepRandomIndexTimer = 1.5 + rng:randomValue() * 120.0
                end

                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey[string.format("sleep%d", clientState.sleepRandomIndex + 1)]
                }
            end,

            [action.types.idle.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)

                local actionModifiers = sapien.sharedState.actionModifiers
                if actionModifiers then
                    if sapien.sharedState.seatObjectID or actionModifiers[action.modifierTypes.sit.index] then
                        return getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
                    elseif actionModifiers[action.modifierTypes.crouch.index] then
                        return getCrouchIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
                    end
                end

                return getStandIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
            end,

            
            [action.types.turn.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                if sapien.sharedState.seatObjectID or action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                    return getSitIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
                end
                return getStandIdleAnimationsByCarryType(sapien, clientState, dt, speedMultiplier, actionTypeIndex)
            end,
            
            [action.types.throwProjectile.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.throwAim,
                }
            end,
            
            [action.types.throwProjectileFollowThrough.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.throw,
                }
            end,
            
           --[[ [action.types.fightFollowThrough.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.throw,
                }
            end,]]

            
            [action.types.moveTo.index]  = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                --mj:log("in move to")
                if sapien.sharedState.seatObjectID then --todo currently we can assume rowing, but will need to differentiate when we ride mammoths
                    --mj:log("return a")
                    return {
                        [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.row,
                    }
                end
                
                local useWaveVarient = false
                if clientSapienAnimationCarryType == clientSapienAnimationCarryTypes.none then
                    local multitaskState = sapien.sharedState.multitaskState
                    if multitaskState and multitaskState.orderMultitaskTypeIndex == order.multitaskTypes.social.index then
                        local context = multitaskState.context
                        if context then
                            local socialInteractionInfo = context.socialInteractionInfo
                            if socialInteractionInfo then
                                if socialInteractionInfo.gestureTypeIndex == social.gestures.wave.index then
                                    useWaveVarient = true
                                end
                            end
                        end
                        ----disabled--mj:objectLog(sapien.uniqueID, "adding moveTo wave animation due to multitask")
                    end
                end

                local actionModifiers = sapien.sharedState.actionModifiers
                if actionModifiers then
                    for j,variant in ipairs(walkRunVariantsInPriorityOrder) do
                        if actionModifiers[variant.actionModifierTypeIndex] then
                            if useWaveVarient then
                                --mj:log("variant.waveAnimationsByCarryType:", variant.waveAnimationsByCarryType)
                                return variant.waveAnimationsByCarryType
                            end
                            --mj:log("variant.animationsByCarryType:", variant.animationsByCarryType)
                            return variant.animationsByCarryType
                        end
                    end
                end

                if useWaveVarient then
                    --mj:log("return walkWaveAnimationsByCarryType:", walkWaveAnimationsByCarryType)
                    return walkWaveAnimationsByCarryType
                end

                --mj:log("return walkAnimationsByCarryType:", walkAnimationsByCarryType)
                return walkAnimationsByCarryType
            end,
            
            
            [action.types.dragObject.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                if sapien.sharedState.seatObjectID then --todo currently we can assume rowing, but will need to differentiate when we ride mammoths
                    return {
                        [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.row,
                    }
                end

                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.dragObjectWalk,
                }
            end,
            
            [action.types.flee.index]  = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                local actionModifiers = sapien.sharedState.actionModifiers
                if actionModifiers then
                    for j,variant in ipairs(walkRunVariantsInPriorityOrder) do
                        if actionModifiers[variant.actionModifierTypeIndex] then
                            return variant.animationsByCarryType
                        end
                    end
                end

                return walkAnimationsByCarryType
            end,

            
            [action.types.knapCrude.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                if clientSapienAnimationCarryType == clientSapienAnimationCarryTypes.smallSingle or clientSapienAnimationCarryType == clientSapienAnimationCarryTypes.smallMulti then
                    return {
                        [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.knap,
                    }
                end
                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.knapCrude,
                }
            end,

            [action.types.defend.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                local newDefendAnimation = animationIndexesByKey.crouchLow
                local newDefendCarryAnimation = animationIndexesByKey.crouchLow

                if clientState.serverLookAtObjectID and clientState.serverLookAtPoint then
                    local lookAtVec = clientState.serverLookAtPoint - sapien.pos
                    local lookAtVecLength = length(lookAtVec)
                    if lookAtVecLength > mj:mToP(5.0) then
                        local lookAtVecNormal = lookAtVec / lookAtVecLength
                        if dot(lookAtVecNormal, mat3GetRow(sapien.rotation, 2)) > 0.7 then
                            newDefendAnimation = animationIndexesByKey.look

                            local crouchRange = mj:mToP(80.0)
                            if lookAtVecLength < crouchRange then
                                local crouchNoVisorHandRange = mj:mToP(50.0)
                                if lookAtVecLength < crouchNoVisorHandRange then
                                    newDefendAnimation = animationIndexesByKey.crouchLow
                                else
                                    newDefendAnimation = animationIndexesByKey.crouchLook
                                end
                                newDefendCarryAnimation = animationIndexesByKey.crouchLow
                            end
                        end
                    end
                end

                return {
                        [clientSapienAnimationCarryTypes.none] = newDefendAnimation,
                        [clientSapienAnimationCarryTypes.high] = newDefendCarryAnimation,
                        [clientSapienAnimationCarryTypes.highSmall] = newDefendCarryAnimation,
                        [clientSapienAnimationCarryTypes.highMedium] = newDefendCarryAnimation,
                    }

            end,
        }

        animationInfo.swimComplexAnimationsByActionType = {
            [action.types.moveTo.index]  = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType)
                return swimAnimationsByCarryType
            end,
            
            [action.types.dragObject.index] = function(sapien, clientState, dt, speedMultiplier, actionTypeIndex, clientSapienAnimationCarryType) --this probably only happens very rarely, lets just walk like Jesus
                return {
                    [clientSapienAnimationCarryTypes.none] = animationIndexesByKey.dragObjectWalk,
                }
            end,
        }

        updateFunctionsByActionSequenceType[actionSequence.types.buildMoveComponent.index] = updateMoveComponentAnimation

        updateFunctionsByActionSequenceType[actionSequence.types.throwProjectile.index] = updateThrow

        updateFunctionsByActionSequenceType[actionSequence.types.fall.index] = updateFall

        updateFunctionsByActionSequenceType[actionSequence.types.wave.index] = updateTurnOrWave
        updateFunctionsByActionSequenceType[actionSequence.types.turn.index] = updateTurnOrWave
        updateFunctionsByActionSequenceType[actionSequence.types.recruit.index] = updateTurnOrWave
        updateFunctionsByActionSequenceType[actionSequence.types.defend.index] = updateTurnOrWave

        actionFinishedFunctionsByActionSequenceType[actionSequence.types.buildMoveComponent.index] = function(sapien, clientState)
            if clientState.buildAnimationInfo then
                clientState.buildAnimationInfo = nil
                clientSapienInventory:removeHeldObjectOverrides(sapien, clientState)
            end
        end

        actionFinishedFunctionsByActionSequenceType[actionSequence.types.fall.index] = function(sapien, clientState)
            clientState.fallTimer = nil
        end
        

        local function heldObjectActionFinished(sapien, clientState)
            if clientState.craftingFocusObjectID then
                clientSapienInventory:removeHeldObjectOverrides(sapien, clientState)
                local craftFocusObject = clientGOM:getObjectWithID(clientState.craftingFocusObjectID)
                if craftFocusObject then
                    clientConstruction:setToolHidden(craftFocusObject, false)
                end
                clientState.craftingFocusObjectID = nil

                if clientState.hiddenInUseResourceIndex then
                    if craftFocusObject then
                        clientConstruction:setResourceHiddenIndex(craftFocusObject, nil)
                    end
                    clientState.hiddenInUseResourceIndex = nil
                end
            end
        end

        local heldObjectActionSequenceTypes = {
            actionSequence.types.knap.index,
            actionSequence.types.knapCrude.index,
            actionSequence.types.grind.index,
            actionSequence.types.scrapeWood.index,
            actionSequence.types.butcher.index,
            actionSequence.types.fireStickCook.index,
            actionSequence.types.smeltMetal.index,
            actionSequence.types.dig.index,
            actionSequence.types.mine.index,
            actionSequence.types.chop.index,
            actionSequence.types.thresh.index,
            actionSequence.types.selfApplyOralMedicine.index,
            actionSequence.types.selfApplyTopicalMedicine.index,
            actionSequence.types.otherApplyOralMedicine.index,
            actionSequence.types.otherApplyTopicalMedicine.index,
            actionSequence.types.smithHammer.index,
            actionSequence.types.chiselStone.index,
        }

        for j,craftActionSequenceType in ipairs(heldObjectActionSequenceTypes) do
            updateFunctionsByActionSequenceType[craftActionSequenceType] = updateHeldObjectAction
            actionFinishedFunctionsByActionSequenceType[craftActionSequenceType] = heldObjectActionFinished
        end
    end
end

return clientSapienAnimation