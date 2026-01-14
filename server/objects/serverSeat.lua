local mjm = mjrequire "common/mjm"
local normalize = mjm.normalize
local cross = mjm.cross
local length2 = mjm.length2
local vec3 = mjm.vec3
local dot = mjm.dot
local mat3GetRow = mjm.mat3GetRow
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local vec3xMat3 = mjm.vec3xMat3
local mat3Inverse = mjm.mat3Inverse
local mat3LookAtInverse = mjm.mat3LookAtInverse

local gameObject = mjrequire "common/gameObject"
local seat = mjrequire "common/seat"
local physics = mjrequire "common/physics"
local physicsSets = mjrequire "common/physicsSets"
local worldHelper = mjrequire "common/worldHelper"
local sapienConstants = mjrequire "common/sapienConstants"
--local order = mjrequire "common/order"

local serverGOM = nil
local serverWorld = nil
local serverSapien = nil

local serverSeat = {}

local clearSeatRayTestLength = mj:mToP(0.6)
local sitDirectionRayTestOffset = mj:mToP(vec3(0.0,0.1, 0.4))
local sitDirectionRayTestMinDistance = mj:mToP(0.15)

local sitDirectionRayTestLength = mj:mToP(0.6)

local sitDirectionRayTestMinDistance2 = sitDirectionRayTestMinDistance * sitDirectionRayTestMinDistance

local function doRayTest(seatObject, seatType, seatNode, seatNodeIndex)
    --mj:log("doRayTest:", seatObject.uniqueID, " seatNodeIndex:", seatNodeIndex)

    local seatObjectSharedState = seatObject.sharedState

    local seatPos = nil


    local rayDirection = -seatObject.normalizedPos
    local rayStart = seatNode.nodePos - rayDirection * clearSeatRayTestLength
    local rayEnd = seatNode.nodePos

    local rayResult = physics:rayTest(rayStart, rayEnd, nil, nil)

    

    --mj:log("rayResult:", rayResult)

    if rayResult and rayResult.hasHitObject and rayResult.objectID == seatObject.uniqueID then

        local reverseResult = physics:rayTest(rayEnd - rayDirection * mj:mToP(0.1), rayStart, nil, nil)
        --mj:log("reverseResult:", reverseResult)
        if (not reverseResult) or (not reverseResult.hasHitObject) or reverseResult.objectID == seatObject.uniqueID then

            local seatTypeNodeInfo = seatType.nodes[seatNode.nodeTypeNodeSubIndex]
            local seatNodeType = seat.nodeTypes[seatTypeNodeInfo.nodeTypeIndex]
            
            --[[if seatTypeNodeInfo.nodeTypeIndex == seat.nodeTypes.yZCircle.index then
                mj:log("rayResult:", rayResult)
                mj:log("seat altitude:", mj:pToM(mjm.length(seatObject.pos) - 1.0))
                mj:log("seat node altitude:", mj:pToM(mjm.length(seatNode.nodePos) - 1.0))
                mj:log("objectCollisionPoint altitude:", mj:pToM(mjm.length(rayResult.objectCollisionPoint) - 1.0))
            end]]

            if seatNodeType.isFlatSurface then
                seatPos = rayResult.objectCollisionPoint
                seatObjectSharedState:remove("seatNodes", seatNodeIndex, "restrictedDirections")
            else
                local restrictedDirections = {}
                local sitDirectionMatrices = seatNodeType.sitDirectionMatrices


                local nodeRotationLocal = serverGOM:getPlaceholderRotationForModel(seatObject.modelIndex, seatTypeNodeInfo.placeholderKey)
                local rotationWorld = seatObject.rotation * nodeRotationLocal
                local nodeXWorld = mat3GetRow(rotationWorld, 0)
              --mj:log("nodeXWorld:", nodeXWorld)

                local directionVec = normalize(cross(seatObject.normalizedPos, -nodeXWorld)) --X maybe shouldn't be negated?
                local baseSitDirectionMatrixWorld = createUpAlignedRotationMatrix(seatObject.normalizedPos, directionVec)
              --mj:log("baseSitDirectionMatrixWorld:", baseSitDirectionMatrixWorld, " seatObject.normalizedPos:", seatObject.normalizedPos)

                for i,localMat in ipairs(sitDirectionMatrices) do
                    local worldMat = baseSitDirectionMatrixWorld * localMat
                  --mj:log("worldMat:", worldMat)


                    local kneePosOffset = vec3xMat3(sitDirectionRayTestOffset, mat3Inverse(worldMat))
                    local kneePosWorld = rayResult.objectCollisionPoint + kneePosOffset

                    
                    local kneeRayTestStart = rayResult.objectCollisionPoint + seatObject.normalizedPos * mj:mToP(0.1)
                    local kneeRayResult = physics:rayTest(kneeRayTestStart, kneePosWorld, nil, seatObject.uniqueID)
                    --mj:log("kneeRayResult:", kneeRayResult)

                    if not kneeRayResult.hasHitObject and not kneeRayResult.hasHitTerrain then
                        local kneeRayResultReverse = physics:rayTest(kneePosWorld, kneeRayTestStart, nil, seatObject.uniqueID)
                        --mj:log("kneeRayResultReverse:", kneeRayResultReverse)
                        if not kneeRayResultReverse.hasHitObject and not kneeRayResultReverse.hasHitTerrain then
                            local groundRayTestEnd = kneePosWorld - seatObject.normalizedPos * sitDirectionRayTestLength
                            
                            local groundRayResult = physics:rayTest(kneePosWorld, groundRayTestEnd, physicsSets.walkable, seatObject.uniqueID)
                            if groundRayResult and groundRayResult.hasHitObject or groundRayResult.hasHitTerrain then
                                local groundCollisionPoint =  groundRayResult.objectCollisionPoint
                            -- mj:log("hit object:", groundRayResult.objectID )
                                if groundRayResult.hasHitTerrain then
                                   --mj:log("hit ground:", mj:pToM(mjm.length(groundRayResult.terrainCollisionPoint - kneePosWorld)) )
                                    groundCollisionPoint = groundRayResult.terrainCollisionPoint
                                end
                                if length2(groundCollisionPoint - kneePosWorld) > sitDirectionRayTestMinDistance2 then
                                    local sitDirection = mat3GetRow(worldMat,2)
                                   --mj:log("found ground. sitDirection:", sitDirection)
                                    table.insert(restrictedDirections, sitDirection)
                                --else
                                    --mj:log("sitDirectionRayTestMinDistance2 too close:", groundRayResult)
                                end
                            --else
                                --mj:log("no groundRayResult:", groundRayResult)
                            end
                        --else
                            --mj:log("no kneeRayResultReverse:", kneeRayResultReverse)
                        end
                    --else
                        --mj:log("kneeRay hit:", kneeRayResult)
                    end
                end

                if next(restrictedDirections) then
                   --mj:log("success!")
                    seatPos = rayResult.objectCollisionPoint
                    
                    --[[if seatTypeNodeInfo.nodeTypeIndex == seat.nodeTypes.yZCircle.index then
                        mj:log("final seatPos altitude:", mj:pToM(mjm.length(seatPos) - 1.0))
                    end]]

                    seatObjectSharedState:set("seatNodes", seatNodeIndex, "restrictedDirections", restrictedDirections)
                end
            end
        end
    end

    if seatPos then
        seatObjectSharedState:set("seatNodes", seatNodeIndex, "seatPos", seatPos)
        --serverGOM:getLocalOffsetForPlaceholderInModel(modelIndex, placeholderKey)
    else
        seatObjectSharedState:remove("seatNodes", seatNodeIndex, "seatPos")
    end
end
--[[
function serverSeat:removeInvalidAssignedStatus(seatObject, ignoreSapien) --ambulance at the bottom of the cliff, assigned status is unreliable due to a bug, hopefully now fixed in b20.
    local seatObjectSharedState = seatObject.sharedState

    --mj:log("serverSeat:removeInvalidAssignedStatus:", seatObject.uniqueID)
    
    local sharedStateSeatNodes = seatObjectSharedState.seatNodes
    if sharedStateSeatNodes then
        for i,seatNode in ipairs(sharedStateSeatNodes) do
            --mj:log("check node:", seatNode)
            if seatNode.assignedSapienID and ((not ignoreSapien) or seatNode.assignedSapienID ~= ignoreSapien.uniqueID) then 
                local assignedSapien = serverGOM:getObjectWithID(seatNode.assignedSapienID)
                local remove = false
                if (not assignedSapien) then
                    --mj:log("couldn't load assigned sapien:", assignedSapien)
                    remove = true
                else
                   -- mj:log("assignedSapien.sharedState:", assignedSapien.sharedState)
                    local foundAssignedSeat = false
                    if assignedSapien.sharedState.actionModifiers then
                        for modifierTypeIndex,modifierInfo in pairs(assignedSapien.sharedState.actionModifiers) do
                            --mj:log("modifierInfo.seatObjectID:", modifierInfo.seatObjectID)
                            if modifierInfo.seatObjectID == seatObject.uniqueID then
                                foundAssignedSeat = true
                                break
                            end
                        end
                    end
                    
                    if not foundAssignedSeat and assignedSapien.sharedState.orderQueue then
                        local orderState = assignedSapien.sharedState.orderQueue[1]
                        if orderState and orderState.orderTypeIndex == order.types.sit.index then
                           -- mj:log("orderState.objectID:", orderState.objectID)
                            if orderState.objectID == seatObject.uniqueID then
                                foundAssignedSeat = true
                            end
                        end
                    end

                    if not foundAssignedSeat then
                        --mj:log("remove assigned status:seatObject.uniqueID")
                        remove = true
                    end
                    
                end

                if remove then
                    seatObjectSharedState:remove("seatNodes", i, "assignedSapienID")
                end
            end
        end
    end
end]]

--[[
function serverSeat:seatIsUsableBySapien(seatObject, sapien)
    if (not serverGOM:objectIsInaccessible(seatObject)) and 
    serverGOM:getObjectHasLight(seatObject) and 
    (seatObject.sharedState.covered or (not sapien.sharedState.covered)) then
        
        local seatTribeID = seatObject.sharedState.tribeID
        if seatTribeID and seatTribeID ~= sapien.sharedState.tribeID then
            if serverWorld:tribeIsValidOwner(seatTribeID) then
                local relationshipSettings = serverWorld:getTribeRelationsSettings(seatTribeID, sapien.sharedState.tribeID)
                if not (relationshipSettings and relationshipSettings.allowBedUse) then
                    return false
                end
            end
        end


        local seatType = seat.types[seatTypeIndex]
    end
end
]]

function serverSeat:getAvailableNodeIndex(sapien, seatObject, allowRidableObjects)
    if serverGOM:objectIsInaccessible(seatObject) then
        return nil
    end

    local seatTypeIndex = gameObject.types[seatObject.objectTypeIndex].seatTypeIndex
    if not seatTypeIndex then
        mj:error("serverSeat:getAvailableNodeIndex called for non seat object:", seatObject.uniqueID)
        return nil
    end

    if seatObject.dynamicPhysics then
        return nil
    end

    local seatType = seat.types[seatTypeIndex]

    if (not allowRidableObjects) and seatType.isRidableObject then
        return nil
    end
    
    local seatTribeID = seatObject.sharedState.tribeID
    if seatTribeID and seatTribeID ~= sapien.sharedState.tribeID then
        if serverWorld:tribeIsValidOwner(seatTribeID) then
            local relationshipSettings = serverWorld:getTribeRelationsSettings(seatTribeID, sapien.sharedState.tribeID)
            if not (relationshipSettings and relationshipSettings.allowBedUse) then
                return nil
            end
        end
    end


    local seatObjectSharedState = seatObject.sharedState



    if seatType.onlyAllowAdultsWhenWaterRidable then
        if not seatObject.sharedState.waterRideable then
            local isChild = sapien.sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index
            if not isChild then
                return nil
            end
        end
    end

    --mj:log("serverSeat:getAvailableNodeIndex:", seatObject.uniqueID)

    local sharedStateSeatNodes = seatObjectSharedState.seatNodes
    if not sharedStateSeatNodes then
        local nodes = seatType.nodes

        sharedStateSeatNodes = {}

        for i, nodeInfo in ipairs(nodes) do
            local nodeRotationLocal = serverGOM:getPlaceholderRotationForModel(seatObject.modelIndex, nodeInfo.placeholderKey)
            if not nodeRotationLocal then
                mj:error("serverSeat:getAvailableNodeIndex placeholder not found:", nodeInfo.placeholderKey)
                error()
            else

                local rotationWorld = seatObject.rotation * nodeRotationLocal
                local flatEnough = false

                if nodeInfo.nodeTypeIndex == seat.nodeTypes.yZCircle.index then
                    local rotationX = mat3GetRow(rotationWorld, 0)
                    if math.abs(dot(rotationX, seatObject.normalizedPos)) < (1.0 - seat.minWorldUpDotProduct) then
                        flatEnough = true
                    end
                elseif seat.nodeTypes[nodeInfo.nodeTypeIndex].allowYFlip then
                    local rotationUp = mat3GetRow(rotationWorld, 1)
                    if dot(rotationUp, seatObject.normalizedPos) > seat.minWorldUpDotProduct then
                        flatEnough = true
                    elseif dot(rotationUp, seatObject.normalizedPos) < -seat.minWorldUpDotProduct then
                        flatEnough = true
                    end
                else
                    local rotationUp = mat3GetRow(rotationWorld, 1)
                   -- mj:log("found node, with node rotation:", nodeRotationLocal, " seatObject.rotation:", seatObject.rotation)
                   -- mj:log("rotationUp:", rotationUp, " worldUp:", seatObject.normalizedPos)
                    if dot(rotationUp, seatObject.normalizedPos) > seat.minWorldUpDotProduct then
                        flatEnough = true
                    end
                end

                if flatEnough then
                    local nodePositionOffset = serverGOM:getOffsetForPlaceholderInObject(seatObject.uniqueID, nodeInfo.placeholderKey)
                    local nodePositionWorld = seatObject.pos + nodePositionOffset
                    table.insert(sharedStateSeatNodes, {
                        nodePos = nodePositionWorld,
                        nodeTypeNodeSubIndex = i,
                    })
                end
            end
        end

        seatObjectSharedState:set("seatNodes", sharedStateSeatNodes)
    end

    local closestNodeDistance2 = 99.0
    local closestNodeIndex = nil
    if sharedStateSeatNodes then

        for i,seatNode in ipairs(sharedStateSeatNodes) do
            if seatNode.sapienID == sapien.uniqueID then
                return i
            end

               -- if seatNode.dirty then
                    --mj:log("dirty:", seatObject.uniqueID)

            if seatType.dynamic then
                seatObjectSharedState:set("seatNodes", i, "seatPos", seatNode.nodePos)
            else
                doRayTest(seatObject, seatType, seatNode, i)
            end
                --end
           -- end

            if seatNode.seatPos then
                local function isFree()
                    if (not seatNode.sapienID) then
                        return true
                    end
                    local sittingSapien = serverGOM:getObjectWithID(seatNode.sapienID)
                    if (not sittingSapien) then
                        return true
                    end

                    if sittingSapien.sharedState.seatObjectID ~= seatObject.uniqueID then
                        seatObjectSharedState:remove("seatNodes", i, "sapienID")
                        return true
                    end

                    return false
                end
                if isFree() then
            -- mj:log("found node")
                    local thisDistance2 = length2(seatNode.seatPos - sapien.pos)
                    if thisDistance2 < closestNodeDistance2 then
                        closestNodeDistance2 = thisDistance2
                        closestNodeIndex = i
                    end
                end
            end
            
        end
    end

   -- mj:log("serverSeat:getAvailableNodeIndex:", seatObject.uniqueID, " closestNodeIndex:", closestNodeIndex)

    return closestNodeIndex

end

function serverSeat:removeSeatNodes(object) --called when an object is no longer a valid seat, or changes in a way where everyone should get booted off --- seat nodes will get recreated again automatically as needed
    local seatObjectSharedState = object.sharedState
    local sharedStateSeatNodes = seatObjectSharedState.seatNodes
    if sharedStateSeatNodes then
        --serverSeat:removeInvalidAssignedStatus(object, nil)

        for i,seatNode in ipairs(sharedStateSeatNodes) do
            --mj:log("pre node alitude:", mj:pToM(mjm.length(seatNode.nodePos) - 1.0))
            --mj:log("pre seat alitude:", mj:pToM(mjm.length(seatNode.seatPos) - 1.0))
            if seatNode.sapienID then
                local sapien = serverGOM:getObjectWithID(seatNode.sapienID)
                if sapien then
                    serverSapien:seatMoved(sapien, object, nil)
                end
            end
        end
        
        seatObjectSharedState:remove("seatNodes")

    end
end


function serverSeat:init(serverGOM_, serverWorld_, serverSapien_)
    serverGOM = serverGOM_
    serverSapien = serverSapien_
    serverWorld = serverWorld_
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.seatTypes, function(seatObject)
        serverGOM:addObjectToSet(seatObject, serverGOM.objectSets.seats)
        serverGOM:addObjectToSet(seatObject, serverGOM.objectSets.coveredStatusObservers)
        return false
    end)
    
end

function serverSeat:getSeatNodes(object)
    return object.sharedState.seatNodes
end

function serverSeat:assignToSapien(seatObject, sapien, seatNodeIndexOrNil) --returns the seat node index if we succeeded, or nil if it failed

    --mj:debug("serverSeat:assignToSapien sapien:", sapien.uniqueID, " seat:", seatObject.uniqueID)
    local seatSharedState = seatObject.sharedState

    --mj:log("sapien assigned seat from distance:", mj:pToM(mjm.length(sapien.pos - seatObject.pos)))
    --[[local debugLength = mjm.length(sapien.pos - seatObject.pos)
    if debugLength > mj:mToP(10.0) then
        mj:error("sapien assigned seat from distance:", debugLength)
    end]]

    local function doAssign(seatNode, seatNodeIndex)
        seatSharedState:set("seatNodes", seatNodeIndex, "sapienID", sapien.uniqueID)
        sapien.sharedState:set("seatObjectID", seatObject.uniqueID)
        sapien.sharedState:set("seatNodeIndex", seatNodeIndex)
        local seatTypeIndex = gameObject.types[seatObject.objectTypeIndex].seatTypeIndex
        local seatType = seat.types[seatTypeIndex]
        local seatNodeTypeIndex = seatType.nodes[seatNode.nodeTypeNodeSubIndex].nodeTypeIndex
        sapien.sharedState:set("seatNodeTypeIndex", seatNodeTypeIndex)
    end

    local seatNodes = seatSharedState and seatSharedState.seatNodes
    if seatNodes then
        if seatNodeIndexOrNil then
            local seatNode = seatNodes[seatNodeIndexOrNil]
            if seatNode and (not seatNode.sapienID) or (seatNode.sapienID == sapien.uniqueID) then
                if (not seatNode.sapienID) then
                    doAssign(seatNode, seatNodeIndexOrNil)
                end

                return seatNodeIndexOrNil
            end
            return nil
        end
        for i, seatNode in ipairs(seatNodes) do
            if seatNode.sapienID == sapien.uniqueID then
                return i
            end
            if not seatNode.sapienID then
                doAssign(seatNode, i)
                return i
            end
        end
    end
    return nil
end


function serverSeat:removeNodeAssignmentForSapien(seatObject, sapien)
    --mj:debug("serverSapien:removeAssignedStatusFromAnySeatObjectDueToNoLongerSitting sapien:", sapien.uniqueID, " seat:", seatObject.uniqueID)
    local sharedState = seatObject.sharedState
    local seatNodes = sharedState and sharedState.seatNodes
    if seatNodes then
        for i, seatNode in ipairs(seatNodes) do
            if seatNode.sapienID == sapien.uniqueID then
                sharedState:remove("seatNodes", i, "sapienID")
            end
        end
    end
    sapien.sharedState:remove("seatObjectID")
end

function serverSeat:removeAnyNodeAssignmentForSapien(sapien)
    if sapien.sharedState.seatObjectID then
        local seatObject = serverGOM:getObjectWithID(sapien.sharedState.seatObjectID)
        if seatObject then
            serverSeat:removeNodeAssignmentForSapien(seatObject, sapien)
        end
        sapien.sharedState:remove("seatObjectID")
    end
end

function serverSeat:updateNodesForSeatObjectPosChange(seatObject) --note this does not rayCast again, it is only needed to be used with "dynamic" set in seat.lua for now, but support could be added
    local seatTypeIndex = gameObject.types[seatObject.objectTypeIndex].seatTypeIndex
    if seatTypeIndex then
        local sharedState = seatObject.sharedState
        if sharedState then
            local sharedStateSeatNodes = sharedState.seatNodes
            if sharedStateSeatNodes then
                local seatType = seat.types[seatTypeIndex]
                local nodes = seatType.nodes
                for i,seatNode in ipairs(sharedStateSeatNodes) do
                    local nodeInfo = nodes[i]
                    if nodeInfo then
                        local nodePositionOffset = serverGOM:getOffsetForPlaceholderInObject(seatObject.uniqueID, nodeInfo.placeholderKey)
                        local nodePositionWorld = seatObject.pos + nodePositionOffset
                        sharedState:set("seatNodes", i, "nodePos", nodePositionWorld)
                        sharedState:set("seatNodes", i, "seatPos", nodePositionWorld)

                        if seatNode.sapienID then
                            local sapien = serverGOM:getObjectWithID(seatNode.sapienID)
                            if sapien then
                                if sapien.sharedState.seatObjectID == seatObject.uniqueID then
                                    serverGOM:setPos(seatNode.sapienID, nodePositionWorld)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function serverSeat:updateTransformForSeatObjectForRidingSapien(sapien)
    local seatObjectID = sapien.sharedState.seatObjectID
    if seatObjectID then
        local seatObject = serverGOM:getObjectWithID(seatObjectID)
        if seatObject then
            local seatTypeIndex = gameObject.types[seatObject.objectTypeIndex].seatTypeIndex
            if seat.types[seatTypeIndex].dynamic then

                local clampToSeaLevel = true
                local newSeatObjectPos = worldHelper:getBelowSurfacePos(sapien.pos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)

                serverGOM:setPos(seatObjectID, newSeatObjectPos, true)
                --mj:log("set seat pos altitude:", mj:pToM(mjm.length(sapien.pos) - 1.0))
                serverGOM:setRotation(seatObjectID, mat3LookAtInverse(-mat3GetRow(sapien.rotation, 0), sapien.normalizedPos))
            end
        end
    end
end

return serverSeat