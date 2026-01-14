
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local cross = mjm.cross
local clamp = mjm.clamp
local length = mjm.length
local length2 = mjm.length2
--local vec3xMat3 = mjm.vec3xMat3
local mat3LookAtInverse = mjm.mat3LookAtInverse
--local mat3Inverse = mjm.mat3Inverse
local mat3GetRow = mjm.mat3GetRow

local gameObject = mjrequire "common/gameObject"
local rng = mjrequire "common/randomNumberGenerator"
local plan = mjrequire "common/plan"
local action = mjrequire "common/action"
local need = mjrequire "common/need"
local actionSequence = mjrequire "common/actionSequence"
local order = mjrequire "common/order"
local worldHelper = mjrequire "common/worldHelper"
local storage = mjrequire "common/storage"
local resource = mjrequire "common/resource"
local statusEffect = mjrequire "common/statusEffect"
local pathFinding = mjrequire "common/pathFinding"
--local physics = mjrequire "common/physics"
local sapienInventory = mjrequire "common/sapienInventory"
local skill = mjrequire "common/skill"
local constructable = mjrequire "common/constructable"
local sapienConstants = mjrequire "common/sapienConstants"
local notification = mjrequire "common/notification"
local sapienTrait = mjrequire "common/sapienTrait"
local physicsSets = mjrequire "common/physicsSets"
local gameConstants = mjrequire "common/gameConstants"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
local desire = mjrequire "common/desire"
local mood = mjrequire "common/mood"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
local social = mjrequire "common/social"
local statistics = mjrequire "common/statistics"
local weather = mjrequire "common/weather"
local research = mjrequire "common/research"
local grievance = mjrequire "common/grievance"
local lookAtIntents = mjrequire "common/lookAtIntents"
local mob = mjrequire "common/mob/mob"
local destination = mjrequire "common/destination"
local planHelper = mjrequire "common/planHelper"

local planManager = mjrequire "server/planManager"
local nameLists = mjrequire "common/nameLists"
local pathCreator = mjrequire "server/pathCreator"
local terrain = mjrequire "server/serverTerrain"
local anchor = mjrequire "server/anchor"
local serverCraftArea = mjrequire "server/serverCraftArea"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverSapienAI = mjrequire "server/sapienAI/ai"
local multitask = mjrequire "server/sapienAI/multitask"
local serverSapienSkills = mjrequire "server/serverSapienSkills"
local serverNomadTribe = mjrequire "server/serverNomadTribe"
local serverSapienInventory = mjrequire "server/serverSapienInventory"
local sapienObjectSnapping = mjrequire "server/sapienObjectSnapping"
local findOrderAI = mjrequire "server/sapienAI/findOrderAI"
local serverStatistics = mjrequire "server/serverStatistics"
local serverLogistics = mjrequire "server/serverLogistics"
local serverTutorialState = mjrequire "server/serverTutorialState"
local serverSeat = mjrequire "server/objects/serverSeat"
local serverStatusEffects = mjrequire "server/serverStatusEffects"
local lookAI = mjrequire "server/sapienAI/lookAI"
local serverWeather = mjrequire "server/serverWeather"
--local serverNotifications = mjrequire "server/serverNotifications"
local serverTribeAIPlayer = mjrequire "server/serverTribeAIPlayer"
local startOrderAI = mjrequire "server/sapienAI/startOrderAI"
local serverWorldSettings = mjrequire "server/serverWorldSettings"

local serverSapien = {
    serverSapienAI = serverSapienAI --hack as passing these through is a pain
}

local serverGOM = nil
local serverWorld = nil
local serverTribe = nil
local serverStorageArea = nil
local serverDestination = nil

serverSapien.sapienSaveStateVersion = 5

serverSapien.startNextActionResult = mj:enum {
    "normal",
    "done",
    "cancel",
    "autoExtended"
}

serverSapien.privateTransientStates = {}

serverSapien.pregnancySpeed = nil
serverSapien.pregnancyDelaySpeed = nil
serverSapien.infantAgeSpeed = nil
serverSapien.ageSpeedsByLifeStage = {}

local pathIDCounter = 0

local loadDebugSapienID = nil--"1ff9ab5"

local function validateAction(sapien, actionState, activeSequence, orderState, orderObject)
    --disabled--mj:objectLog(sapien.uniqueID, "validateAction")
    local newActionTypeIndex = activeSequence.actions[actionState.progressIndex]
    if newActionTypeIndex == action.types.place.index or newActionTypeIndex == action.types.throwProjectile.index or newActionTypeIndex == action.types.placeMultiFromHeld.index then
        --disabled--mj:objectLog(sapien.uniqueID, "validateAction - is place type")
        if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) == 0 then
            return false
        end
        if not findOrderAI:checkForMatchingHeldObjectDisposalForCurrentOrder(sapien) then
            --disabled--mj:objectLog(sapien.uniqueID, "checkForMatchingHeldObjectDisposalForCurrentOrder returned false")
            return false
        end
    end
    return true
end

function serverSapien:actionSequenceTypeIndexForOrder(sapien, orderObject, orderState)
    
    local orderTypeIndex = orderState.orderTypeIndex

    local function assignPickupActionSequence()
        if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
            return actionSequence.types.pickupMultiObject.index
        else
            return actionSequence.types.pickupObject.index
        end
    end

    local function assignDeliverActionSequence()
        if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 1 then
            return actionSequence.types.deliverMultiObject.index
        else
            return actionSequence.types.deliverObject.index
        end
    end

    local function assignPlayInstrumentActionSequence()
        local heldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
        if heldObjectInfo then
            if heldObjectInfo.objectTypeIndex == gameObject.types.logDrum.index then
                return actionSequence.types.playDrum.index
            elseif heldObjectInfo.objectTypeIndex == gameObject.types.balafon.index then
                return actionSequence.types.playBalafon.index
            end
        end
        
        return actionSequence.types.playFlute.index
    end

    local function assignGatherActionSequence()
        if orderObject then
            if gameObject.types[orderObject.objectTypeIndex].useBushGatherAnimation then
                return actionSequence.types.gatherBush.index
            end
        end
        return actionSequence.types.gather.index
    end

    local function assignBuildSequenceActionSequence()
        if not orderObject then
            return nil
        end
        local orderObjectState = orderObject.sharedState

        local constructableType = constructable.types[orderObjectState.inProgressConstructableTypeIndex]

        if not constructableType then
            local planState = planManager:getPlanSateForConstructionObject(orderObject, sapien.sharedState.tribeID)
            if planState then
                constructableType = constructable.types[planState.constructableTypeIndex]
            end

            if not constructableType then
                mj:warn("no inProgressConstructableTypeIndex in assignGatherActionSequence:", orderObjectState)
                return nil
            end
        end

      --  mj:log("orderObjectState:", orderObjectState, " orderObject type:", gameObject.types[orderObject.objectTypeIndex].key)


        
        local orderContext = orderState.context
        local planTypeIndex = nil
        if orderContext then
            planTypeIndex = orderContext.planTypeIndex
        end

        serverGOM:updateBuildSequenceIndex(orderObject, sapien, planTypeIndex, constructableType)
        local buildSequenceIndex = orderObject.sharedState.buildSequenceIndex

        local currentBuildSequenceInfo = constructableType.buildSequence[buildSequenceIndex]
        if currentBuildSequenceInfo then
            if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.actionSequence.index then
                return currentBuildSequenceInfo.actionSequenceTypeIndex
            elseif currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.moveComponents.index then
                return actionSequence.types.inspect.index
            else
                mj:error("no actionSequence in assignBuildSequenceActionSequence:", currentBuildSequenceInfo)
                mj:log("constructable.sequenceType:", constructable.sequenceTypes[currentBuildSequenceInfo.constructableSequenceTypeIndex])
                mj:log("constructableType:", constructableType.key)
                mj:log("objectID:", orderObject.uniqueID)
            end
        else
            mj:error("currentBuildSequenceInfo.constructableSequenceTypeIndex ~= constructable.sequenceTypes.actionSequence.index in assignBuildSequenceActionSequence")
        end
        return nil
    end

    local function assignSocialActionSequence()
        local socialInteractionInfo = orderState.context.socialInteractionInfo

        if socialInteractionInfo.gestureTypeIndex then
            return social.gestures[socialInteractionInfo.gestureTypeIndex].actionSequenceTypeIndex
        else
            return actionSequence.types.turn.index
        end
    end

    local function assignTakeOffClothingActionSequence()
        local orderContext = orderState.context
        if orderContext.inventoryLocation == sapienInventory.locations.torso.index then
            return actionSequence.types.takeOffTorsoClothing.index
        end
        mj:error("no valid inventory location found in assignTakeOffClothingActionSequence. orderContext:", orderContext)
        return nil
    end

    local function assignPutOnClothingActionSequence()
        local orderContext = orderState.context
        if orderContext.inventoryLocation == sapienInventory.locations.torso.index then
            return actionSequence.types.putOnTorsoClothing.index
        end
        mj:error("no valid inventory location found in assignPutOnClothingActionSequence. orderContext:", orderContext)
        return nil
    end

    local function assignGiveMedicineToSelfActionSequence()
        local orderContext = orderState.context
        --mj:log("assignGiveMedicineToSelfActionSequence orderContext:", orderContext)
        local isTopicalMedicine = resource.types[gameObject.types[orderContext.medicineObjectTypeIndex].resourceTypeIndex].isTopicalMedicine
        if isTopicalMedicine then
            return actionSequence.types.selfApplyTopicalMedicine.index
        end
        return actionSequence.types.selfApplyOralMedicine.index
    end

    local function assignGiveMedicineToOtherSapienActionSequence()
        local orderContext = orderState.context
        local isTopicalMedicine = resource.types[gameObject.types[orderContext.medicineObjectTypeIndex].resourceTypeIndex].isTopicalMedicine
        if isTopicalMedicine then
            return actionSequence.types.otherApplyTopicalMedicine.index
        end
        return actionSequence.types.otherApplyOralMedicine.index
    end


    local function assignHaulDragObjectActionSequence()
        --[[if orderObject and sapien.sharedState.seatObjectID == orderObject.uniqueID then
            return actionSequence.types.haulRideObject.index
        end]]
        return actionSequence.types.haulDragObject.index
    end

    local simpleTypeMap = {
        [order.types.moveTo.index] = actionSequence.types.moveTo.index,
        [order.types.moveToLogistics.index] = actionSequence.types.moveTo.index,
        [order.types.haulMoveToObject.index] = actionSequence.types.moveTo.index,
        --[order.types.haulDragObject.index] = actionSequence.types.haulDragObject.index,
        [order.types.flee.index] = actionSequence.types.flee.index,
        [order.types.chop.index] = actionSequence.types.chop.index,
        [order.types.butcher.index] = actionSequence.types.butcher.index,
        [order.types.pullOut.index] = actionSequence.types.pullOut.index,
        [order.types.eat.index] = actionSequence.types.eat.index,
        ---[order.types.playInstrument.index] = actionSequence.types.playFlute.index,
        --[order.types.gather.index] = actionSequence.types.gather.index,
        [order.types.dig.index] = actionSequence.types.dig.index,
        [order.types.mine.index] = actionSequence.types.mine.index,
        [order.types.clear.index] = actionSequence.types.clear.index,
        [order.types.dropObject.index] = actionSequence.types.dropObject.index,
        [order.types.sleep.index] = actionSequence.types.sleep.index,
        [order.types.sit.index] = actionSequence.types.sit.index,
        [order.types.turn.index] = actionSequence.types.turn.index,
        [order.types.fall.index] = actionSequence.types.fall.index,
        [order.types.buildMoveComponent.index] = actionSequence.types.buildMoveComponent.index,
        [order.types.light.index] = actionSequence.types.light.index,
        [order.types.throwProjectile.index] = actionSequence.types.throwProjectile.index,
        [order.types.extinguish.index] = actionSequence.types.extinguish.index,
        [order.types.destroyContents.index] = actionSequence.types.destroyContents.index,
        [order.types.recruit.index] = actionSequence.types.recruit.index,
        [order.types.banish.index] = actionSequence.types.banish.index,
        [order.types.fight.index] = actionSequence.types.fight.index,
        [order.types.defend.index] = actionSequence.types.defend.index,
        [order.types.greet.index] = actionSequence.types.greet.index,
        [order.types.chiselStone.index] = actionSequence.types.chiselStone.index,
    }

    local functionTypeMap = {
        [order.types.pickupObject.index] = assignPickupActionSequence,
        [order.types.removeObject.index] = assignPickupActionSequence,
        [order.types.storeObject.index] = assignPickupActionSequence,
        [order.types.transferObject.index] = assignPickupActionSequence,
        [order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index] = assignPickupActionSequence,
        --[order.types.take.index] = assignPickupActionSequence,

        
        [order.types.playInstrument.index] = assignPlayInstrumentActionSequence,

        [order.types.gather.index] = assignGatherActionSequence,

        [order.types.deliverObjectToConstructionObject.index] = assignDeliverActionSequence,
        [order.types.deliverFuel.index] = assignDeliverActionSequence,
        [order.types.deliverPlanObjectForCraftingOrResearchElsewhere.index] = assignDeliverActionSequence,
        [order.types.deliverObjectToStorage.index] = assignDeliverActionSequence,
        [order.types.deliverObjectTransfer.index] = assignDeliverActionSequence,
        [order.types.deliverToCompost.index] = assignDeliverActionSequence,
        [order.types.disposeOfObject.index] = assignDeliverActionSequence,
        
        [order.types.social.index] = assignSocialActionSequence,

        [order.types.buildActionSequence.index] = assignBuildSequenceActionSequence,
        
        [order.types.takeOffClothing.index] = assignTakeOffClothingActionSequence,
        [order.types.putOnClothing.index] = assignPutOnClothingActionSequence,
        [order.types.giveMedicineToSelf.index] = assignGiveMedicineToSelfActionSequence,
        [order.types.giveMedicineToOtherSapien.index] = assignGiveMedicineToOtherSapienActionSequence,

        [order.types.haulDragObject.index] = assignHaulDragObjectActionSequence,
        [order.types.haulRideObject.index] = assignHaulDragObjectActionSequence,
    }

    local func = functionTypeMap[orderTypeIndex]
    if func then
        return func()
    end

    return simpleTypeMap[orderTypeIndex]
end

function serverSapien:createActionStateForOrder(sapien, orderObject, orderState)

    local actionSequenceTypeIndex = serverSapien:actionSequenceTypeIndexForOrder(sapien, orderObject, orderState)

    if not actionSequenceTypeIndex then
        mj:warn("No actionSequenceTypeIndex assignment for order type:", order.types[orderState.orderTypeIndex])
        return nil
    end

    return {
        sequenceTypeIndex = actionSequenceTypeIndex,
        progressIndex = 1,
        pathNodeIndex = 1,
    }
end

local function startCurrentAction(sapien)
    local result = serverSapien.startNextActionResult.normal
    local actionState = sapien.sharedState.actionState
    local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
    
    --disabled--mj:objectLog(sapien.uniqueID, "startCurrentAction. actionState:", actionState, " traceback: ", debug.traceback())

    if actionState.progressIndex <= #activeSequence.actions then
        local orderQueue = sapien.sharedState.orderQueue
        local orderState = orderQueue[1]

        local orderObject = nil
        if orderState.objectID then
            orderObject = serverGOM:getObjectWithID(orderState.objectID)
        end

        if not validateAction(sapien, actionState, activeSequence, orderState, orderObject) then
            result = serverSapien.startNextActionResult.cancel
        else
            sapien.privateState.actionStateTimer = 0.0

            serverGOM:testAndUpdateCoveredStatusIfNeeded(sapien)
            
            if activeSequence.assignModifierTypeIndex then
                if activeSequence.assignedTriggerIndex == actionState.progressIndex then
                    if activeSequence.assignModifierTypeIndex == action.modifierTypes.sit.index and orderObject and gameObject.types[orderObject.objectTypeIndex].seatTypeIndex then
                        
                        local seatObjectTypeIndex = orderObject.objectTypeIndex

                        sapien.sharedState:set("actionModifiers", activeSequence.assignModifierTypeIndex, {
                            seatObjectTypeIndex = seatObjectTypeIndex,
                        })
                        
                        if not serverSeat:assignToSapien(orderObject, sapien, nil) then
                            return serverSapien.startNextActionResult.cancel
                        end
                    --[[else
                        serverSeat:removeAnyNodeAssignmentForSapien(sapien)
                        sapien.sharedState:set("actionModifiers", activeSequence.assignModifierTypeIndex, {})
                        --disabled--mj:objectLog(sapien.uniqueID, "assigning modifier activeSequence.assignModifierTypeIndex:", activeSequence.assignModifierTypeIndex)]]
                    end
                end
            end

            --mj:log("startCurrentAction actionState.path:", actionState.path)

            local rideObject = nil

            if actionState.path then
                local nodes = actionState.path.nodes
                local newNode = nodes[actionState.pathNodeIndex]
                if newNode then
                    if newNode.rideObjectID then
                        rideObject = serverGOM:getObjectWithID(newNode.rideObjectID)
                        if rideObject then
                            --mj:log("calling serverSeat:assignToSapien:", newNode.rideObjectID)
                            if not serverSeat:assignToSapien(rideObject, sapien, nil) then
                                return serverSapien.startNextActionResult.cancel
                            end
                        else
                            return serverSapien.startNextActionResult.cancel
                        end
                    end
                end

                if (not rideObject) then 
                    if (not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index)) then
                        serverSeat:removeAnyNodeAssignmentForSapien(sapien)
                    end
                end
            end


            if activeSequence.assignedTriggerIndex == actionState.progressIndex then
                if orderState.orderTypeIndex == order.types.sleep.index then
                    serverWorld:setSapienSleeping(sapien, true)
                    if orderObject and gameObject.types[orderObject.objectTypeIndex].isBed then 
                        serverSapien:assignBed(sapien, orderObject.uniqueID)
                    end
                end
                
                if orderState.orderTypeIndex == order.types.playInstrument.index and skill:hasSkill(sapien, skill.types.flutePlaying.index) then
                    serverGOM:addObjectToSet(sapien, serverGOM.objectSets.musicPlayers)
                end

                --[[if orderState.orderTypeIndex == order.types.haul.index then
                    if not orderState.context.moveToPos then
                        mj:error("no move to pos")
                    end

                    local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, orderState.context.moveToPos)
                    serverSapien:updateCurrentOrderPathInfo(sapien, pathInfo)
                end]]

            end

            if orderObject then
            
                anchor:setSapienOrderObjectAnchor(sapien.uniqueID, orderObject.uniqueID)
               -- if activeSequence.assignedTriggerIndex == actionState.progressIndex then
                    --mj:log("activeSequence.assignedTriggerIndex == actionState.progressIndex:", cancel)
                    --[[local cancel = serverSapien:assignOrderObject(sapien, orderObject, orderState)
                    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:assignOrderObject:", not cancel)
                    if cancel then
                        result = serverSapien.startNextActionResult.cancel
                    end]]
               -- end
                
                if activeSequence.snapToOrderObjectIndex == actionState.progressIndex then

                    local snapInfo = sapienObjectSnapping:getSnapInfo(orderObject, sapien, orderState, activeSequence.actions[actionState.progressIndex])

                    if snapInfo then

                        local posToUse = snapInfo.pos
                        if not posToUse then
                            posToUse = orderObject.pos
                        end

                        if snapInfo.offsetToWalkableHeight then
                            local clampToSeaLevel = true
                            posToUse = worldHelper:getBelowSurfacePos(posToUse, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                        end

                        serverGOM:setPos(sapien.uniqueID, posToUse, false)
                        serverSapien:removeLookAt(sapien)

                        if snapInfo.rotation then
                            if mj:isNan(snapInfo.rotation.m0) then
                                mj:error("rotation is nan")
                                error()
                            end
                            if mjm.dot(mat3GetRow(snapInfo.rotation, 1), sapien.normalizedPos) < 0.99 then
                                mj:error("snap rotation is not up orientated")
                                mj:log("snap object id:", orderObject.uniqueID)
                                snapInfo.rotation = sapien.rotation
                            end
                            serverGOM:setRotation(sapien.uniqueID, snapInfo.rotation)
                        end

                        --disabled--mj:objectLog(sapien.uniqueID, "snap to object:", orderObject.uniqueID, " due to activeSequence.snapToOrderObjectIndex")

                        serverGOM:sendSnapObjectMatrix(sapien.uniqueID, true)
                    end
                end
            end
        end
   --else

        --this all needs sorting out probably. While fighting, they get to follow through, can't just stay there. But cancelling here gives everyone ADHD vvv
       -- --disabled--mj:objectLog(sapien.uniqueID, "returning cancel due to being beyond end of action sequence")
       -- return serverSapien.startNextActionResult.cancel

        -- and doing this sticks everyone trying to pick up or deliver things vvvvv
       -- --disabled--mj:objectLog(sapien.uniqueID, "resetting to initial assigned progress index")
       -- sapien.sharedState:set("actionState", "progressIndex", activeSequence.assignedTriggerIndex)
    end

    return result
end

function serverSapien:startNextAction(sapien)

    local orderQueue = sapien.sharedState.orderQueue
    local result = serverSapien.startNextActionResult.done
    if orderQueue and orderQueue[1] then
        local actionState = sapien.sharedState.actionState
        if actionState then
            --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:startNextAction")
            sapien.sharedState:set("actionState", "progressIndex", actionState.progressIndex + 1)
            return startCurrentAction(sapien)        
        end
    end
    return result
end


--[[function serverSapien:terrainModifiedBelow(sapien)
    local shiftedPos = worldHelper:getBelowSurfacePos(sapien.pos, 1.0, physicsSets.walkable)
    if length(shiftedPos - sapien.pos) > mj:mToP(0.01) then
        serverGOM:setPos(sapien.uniqueID, shiftedPos)
        
        --disabled--mj:objectLog(sapien.uniqueID, "snap to terrain due to shifted below")

        serverGOM:sendNotificationForObject(sapien, notification.types.snapPosition.index, nil, sapien.sharedState.tribeID)
        serverSapien:saveState(sapien)
    end
end]]

local function removeInventory(sapien, shouldDropObjects)
    if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
        local objectInfo = serverSapienInventory:removeObject(sapien, sapienInventory.locations.held.index) --remove whether or not we want to create the drop, as this will unassign any plan objects
            
        if shouldDropObjects then
            if objectInfo then
                local offsetPos = sapien.pos + mat3GetRow(sapien.rotation, 2) * mj:mToP(0.3)
                local dropPosNormal = normalize(offsetPos)

                local sapienPosLength = length(sapien.pos)
                local clampToSeaLevel = true
                local shiftedPos = worldHelper:getBelowSurfacePos(dropPosNormal * sapienPosLength, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                local shiftedPosLength = length(shiftedPos)
                local finalDropPos = dropPosNormal * (shiftedPosLength + mj:mToP(1.0))

                serverGOM:dropObject(objectInfo, finalDropPos, sapien.sharedState.tribeID, false)
            end
        end
    end
end

local terrainLoadRequestCountersByObjectID = {}

function serverSapien:checkObjectLoadedAndLoadIfNot(sapien, objectID, objectPos, giveUpCount, giveUpFunction)
    local object = serverGOM:getObjectWithID(objectID)
    if not object then
        if not terrainLoadRequestCountersByObjectID[objectID] then
            --disabled--mj:objectLog(sapien.uniqueID, "load area:", objectPos)
            --mj:log(debug.traceback())
            terrain:loadArea(objectPos)
            terrainLoadRequestCountersByObjectID[objectID] = 1
        else
            terrainLoadRequestCountersByObjectID[objectID] = terrainLoadRequestCountersByObjectID[objectID] + 1
            if terrainLoadRequestCountersByObjectID[objectID] > giveUpCount then
                terrainLoadRequestCountersByObjectID[objectID] = nil
                --disabled--mj:objectLog(sapien.uniqueID, "Giving up loading order object after ", giveUpCount, " checks")
                giveUpFunction()
            end
        end
    else
        terrainLoadRequestCountersByObjectID[objectID] = nil
    end
    return object
end


function serverSapien:removeAssignedStatusFromObjectIfBelongingToSapien(objectID, sapien, orderState, removePlanObjectState)
    
    if objectID then
        local orderObjectReloaded = serverGOM:getObjectWithID(objectID)
        if orderObjectReloaded then
            local orderObjectState = orderObjectReloaded.sharedState
            if orderObjectState then
                if orderObjectState.assignedSapienIDs and orderObjectState.assignedSapienIDs[sapien.uniqueID] then
                    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:removeAssignedStatusFromObjectIfBelongingToSapien removed:", objectID)
                    --[[if sapien.uniqueID == mj.debugObject then
                        mj:debug("backtrace for removeAssignedStatusFromObjectIfBelongingToSapien")
                    end]]
                    orderObjectState:remove("assignedSapienIDs", sapien.uniqueID)
                    if not next(orderObjectState.assignedSapienIDs) then
                        orderObjectState:remove("assignedSapienIDs")
                    end
                    if gameObject.types[orderObjectReloaded.objectTypeIndex].isCraftArea then
                        serverCraftArea:updateInUseStateForCraftArea(orderObjectReloaded)
                    end
                end
            end
        end
    end

    if removePlanObjectState and orderState and orderState.context and orderState.context.planObjectID then
        if not serverSapienInventory:heldObjectIsForPlanObjectWithID(sapien, orderState.context.planObjectID) then
            local planObjectReloaded = serverGOM:getObjectWithID(orderState.context.planObjectID)
            if planObjectReloaded then
                local planObjectState = planObjectReloaded.sharedState
                if planObjectState then
                    if planObjectState.assignedSapienIDs and planObjectState.assignedSapienIDs[sapien.uniqueID] then
                        --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:removeAssignedStatusFromObjectIfBelongingToSapien remove plan object:", orderState.context.planObjectID)
                        planObjectState:remove("assignedSapienIDs", sapien.uniqueID)
                        if not next(planObjectState.assignedSapienIDs) then
                            planObjectState:remove("assignedSapienIDs")
                        end
                        if gameObject.types[planObjectReloaded.objectTypeIndex].isCraftArea then
                            serverCraftArea:updateInUseStateForCraftArea(planObjectReloaded)
                        end
                    end
                end
            end
        end
    end
end

function serverSapien:removeAssignedStatusForInventoryRemoval(sapien, planObjectID)
    local orderState = sapien.sharedState.orderQueue[1]

    if orderState and orderState.context and orderState.context.planObjectID == planObjectID then
        return
    end
    
    local planObjectReloaded = serverGOM:getObjectWithID(planObjectID)
    if planObjectReloaded then
        local planObjectState = planObjectReloaded.sharedState
        if planObjectState then
            if planObjectState.assignedSapienIDs and planObjectState.assignedSapienIDs[sapien.uniqueID] then
                --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:removeAssignedStatusForInventoryRemoval removed:", planObjectID)
                planObjectState:remove("assignedSapienIDs", sapien.uniqueID)
                if not next(planObjectState.assignedSapienIDs) then
                    planObjectState:remove("assignedSapienIDs")
                end
                if gameObject.types[planObjectReloaded.objectTypeIndex].isCraftArea then
                    serverCraftArea:updateInUseStateForCraftArea(planObjectReloaded)
                end
            end
        end
    end
end

function serverSapien:cancelOrderAtQueueIndex(sapien, orderIndex, removeHeldObjectOrderContext)
    --disabled--mj:objectLog(sapien.uniqueID, "cancelOrderAtQueueIndex:", orderIndex, " traceback:", debug.traceback())
    --mj:log(debug.traceback())
    local sharedState = sapien.sharedState
    --mj:log(sapienState)
    local orderState = sharedState.orderQueue[orderIndex]
    if orderState then
        sharedState:removeFromArray("orderQueue", orderIndex)
        
       -- table.remove(sapienState.orderQueue, orderIndex)

        if orderState.objectID then
            local removePlanObjectState = true
            serverSapien:removeAssignedStatusFromObjectIfBelongingToSapien(orderState.objectID, sapien, orderState, removePlanObjectState)

            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            if orderObject then
                local unsavedState = serverGOM:getUnsavedPrivateState(orderObject)
                unsavedState.requiredObjectInfoResourceInfo = nil
                
                --serverGOM:removeAnchorForObjectWithID(orderState.objectID) --todo this probably removes too early if multiple plans are queued up

                --[[if orderState.extraData.requiresAvailableResource and sapienState.actionState then --todo remove anchor for item you are going to pick up.
                    local goingToPickUpObjectID = sapienState.actionState.resourceObjectID
                    serverGOM:removeAnchorForObjectWithID(goingToPickUpObjectID)
                end]]

                if orderState.orderTypeIndex == order.types.moveTo.index then
                    serverGOM:removeTemporaryGameObjectForOrderCompleteIfNeeded(orderObject)
                end
        
            end
        end
        
       --if orderState.orderTypeIndex == order.types.haulDragObject.index then
            serverSapien:setHaulDragingObject(sapien, nil)
        --end

        serverSapien:clearAllAssignedObjectIDs(sapien)

        local aiState = serverSapienAI.aiStates[sapien.uniqueID]
        if aiState then
            aiState.currentLookAtObjectInfo = nil --added 29/4/22 to reset, as sometimes sapiens could get stuck looking at a campfire, failing to use it due to getting cancelled here due to other sapiens fetching wood. If this causes issues, move it further up the chain to be more specific
        end

        if orderState.orderTypeIndex == order.types.sleep.index then
            if orderIndex == 1 and sharedState.activeOrder then
                serverWorld:setSapienSleeping(sapien, false)
            end
        elseif orderState.orderTypeIndex == order.types.playInstrument.index then
            serverGOM:removeObjectFromSet(sapien, serverGOM.objectSets.musicPlayers)
        end
    end
    

    if removeHeldObjectOrderContext then
        serverSapienInventory:removeOrderContexts(sapien, sapienInventory.locations.held.index)
    end

    if orderIndex == 1 then
        if sharedState.activeOrder then
            --mj:log("remove action state:", sapien.uniqueID)
            sharedState:remove("actionState")
            sharedState:remove("activeOrder")
            multitask:orderEnded(sapien)
        end
        local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
        unsavedState.waitingForPathID = nil
        
    
        if sapien.privateState.logisticsInfo then
            sapien.privateState.logisticsInfo = nil
            serverLogistics:setSapienRouteAssignment(sapien.uniqueID, sapien.sharedState.tribeID, nil)
        end
    end

    --serverSapien:saveState(sapien)
end

local minDistanceToTakeAssignmentFromOtherSapien = mj:mToP(10.0)
local minDistanceToTakeAssignmentFromOtherSapien2 = minDistanceToTakeAssignmentFromOtherSapien * minDistanceToTakeAssignmentFromOtherSapien

function serverSapien:getInfoForPlanObjectSapienAssignment(object, sapien, planTypeIndex) --new API for plan objects specifically
    local planObjectSapienAssignmentInfo = {
        available = true,
    }
    
    --disabled--mj:objectLog(object.uniqueID, "serverSapien:getInfoForPlanObjectSapienAssignment object:", object.uniqueID, " planTypeIndex:", planTypeIndex)
    
    planObjectSapienAssignmentInfo.assignedSapienID = serverSapien:objectIsAssignedToOtherSapien(object, sapien.sharedState.tribeID, sapien, {planTypeIndex}, true)
    if planObjectSapienAssignmentInfo.assignedSapienID then
        if sapien.sharedState.manualAssignedPlanObject == object.uniqueID then
            return planObjectSapienAssignmentInfo
        end

        local assignedSapien = serverGOM:getObjectWithID(planObjectSapienAssignmentInfo.assignedSapienID)
        if assignedSapien then
            local myHeldObjectRequired = serverSapienInventory:heldObjectIsForPlanObjectWithID(sapien, object.uniqueID)
            local assignedHeldObjectRequired = serverSapienInventory:heldObjectIsForPlanObjectWithID(assignedSapien, object.uniqueID)
            
            --disabled--mj:objectLog(object.uniqueID, "assignedSapien myHeldObjectRequired:", myHeldObjectRequired, " assignedHeldObjectRequired:", assignedHeldObjectRequired)

            local function getIAmCloser()
                local assignedSapienLength2 = length2(assignedSapien.pos - object.pos)
                if assignedSapienLength2 > minDistanceToTakeAssignmentFromOtherSapien2 then
                    local myLength2 = length2(sapien.pos - object.pos)
                    return myLength2 < assignedSapienLength2 * 0.7 --I'm a fair bit closer
                end

            end

            if myHeldObjectRequired then
                if assignedHeldObjectRequired then
                    if getIAmCloser() then
                        --disabled--mj:objectLog(object.uniqueID, "returning closer a")
                        return planObjectSapienAssignmentInfo
                    end
                else
                    --disabled--mj:objectLog(object.uniqueID, "returning myHeldObjectRequired and not assignedHeldObjectRequired")
                    return planObjectSapienAssignmentInfo
                end
            else
                if not assignedHeldObjectRequired then
                    if getIAmCloser() then
                        --disabled--mj:objectLog(object.uniqueID, "returning closer b")
                        return planObjectSapienAssignmentInfo
                    end
                end
            end
        end
        
        --disabled--mj:objectLog(object.uniqueID, "returning unavailable")
        planObjectSapienAssignmentInfo.available = false
    end

    return planObjectSapienAssignmentInfo
end

function serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(planObjectSapienAssignmentInfo)
    if planObjectSapienAssignmentInfo and planObjectSapienAssignmentInfo.assignedSapienID then
        local otherSapien = serverGOM:getObjectWithID(planObjectSapienAssignmentInfo.assignedSapienID)
        if otherSapien then
            serverSapien:cancelAllOrders(otherSapien, false, true)
        end
    end
end

function serverSapien:seatIsAssignedToOtherSapien(object, seatNodeIndex, sapienOrNilForAny)
    if serverSapien:objectIsAssignedToOtherSapien(object, nil, sapienOrNilForAny, nil, true) then
        return true
    end

    if seatNodeIndex then
        local seatNodes = serverSeat:getSeatNodes(object)
        if seatNodes then
            local nodeState = object.sharedState.seatNodes[seatNodeIndex]
            if nodeState and nodeState.sapienID and ((not sapienOrNilForAny) or (nodeState.sapienID ~= sapienOrNilForAny.uniqueID)) then
                ----disabled--mj:objectLog(sapien.uniqueID, "serverSapien:assiobjectIsAssignedToOtherSapiengnOrderObject returnning cancel c. orderObjectState:", orderObjectState)
                return nodeState.sapienID
            end
        end
    end
end

function serverSapien:objectIsAssignedToOtherSapien(object, tribeIDOrNilToSkipSomeChecks, sapienOrNilForAny, matchPlanTypeIndexArrayOrNilForAny, objectIsPlanObject)
    local orderObjectState = object.sharedState
    if orderObjectState and orderObjectState.assignedSapienIDs then
        if objectIsPlanObject and matchPlanTypeIndexArrayOrNilForAny then
            for i,matchPlanTypeIndex in ipairs(matchPlanTypeIndexArrayOrNilForAny) do
                local maxPlanAssignCount = plan.types[matchPlanTypeIndex].maxAssignCount or 1
                
                if maxPlanAssignCount == 1 then
                    local gameObjectType = gameObject.types[object.objectTypeIndex]
                    if gameObjectType.isStorageArea then
                        if tribeIDOrNilToSkipSomeChecks and (matchPlanTypeIndex == plan.types.removeObject.index or matchPlanTypeIndex == plan.types.transferObject.index) then
                            maxPlanAssignCount = math.min(serverStorageArea:availableTransferCount(object.uniqueID, tribeIDOrNilToSkipSomeChecks), 4)
                        end
                    end
                end

                local foundCount = 0
                local firstFoundSapienID = nil
                for otherSapienID,assignedPlanTypeIndexOrTrue in pairs(orderObjectState.assignedSapienIDs) do
                    if ((not sapienOrNilForAny) or otherSapienID ~= sapienOrNilForAny.uniqueID) and (assignedPlanTypeIndexOrTrue == true or assignedPlanTypeIndexOrTrue == matchPlanTypeIndex) then
                        firstFoundSapienID = firstFoundSapienID or otherSapienID
                        foundCount = foundCount + 1
                    end
                end

                if foundCount >= maxPlanAssignCount then
                    return firstFoundSapienID
                end
            end
        else
            local maxPlanAssignCount = 1

            local gameObjectType = gameObject.types[object.objectTypeIndex]
            if gameObjectType.isStorageArea then
                maxPlanAssignCount = 4
            end

            local foundCount = 0
            local firstFoundSapienID = nil
            for otherSapienID,assignedPlanTypeIndexOrTrue in pairs(orderObjectState.assignedSapienIDs) do
                if ((not sapienOrNilForAny) or otherSapienID ~= sapienOrNilForAny.uniqueID) then
                    firstFoundSapienID = firstFoundSapienID or otherSapienID
                    foundCount = foundCount + 1
                end
            end

            if foundCount >= maxPlanAssignCount then
                return firstFoundSapienID
            end
        end
    end

    return nil
end


--[[
function serverSapien:objectIsAssignedToOtherSapien(object, tribeIDOrNilToSkipSomeChecks, sapienOrNilForAny, matchPlanTypeIndexArrayOrNilForAny, objectIsPlanObject)

    local maxAllowedAssignedCount = 1
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if gameObjectType.isStorageArea then --todo maybe check storage area max too
        if objectIsPlanObject and matchPlanTypeIndexArrayOrNilForAny then
            local found = false
            for i,matchPlanTypeIndex in ipairs(matchPlanTypeIndexArrayOrNilForAny) do
                local thisAllowCount = plan.types[matchPlanTypeIndex].multipleSapiensMaxAssignCountOnStorageAreas
                if thisAllowCount then
                    if not found then
                        maxAllowedAssignedCount = thisAllowCount
                    else
                        maxAllowedAssignedCount = math.min(maxAllowedAssignedCount, thisAllowCount)
                    end
                    
                    if tribeIDOrNilToSkipSomeChecks and (matchPlanTypeIndex == plan.types.removeObject.index or matchPlanTypeIndex == plan.types.transferObject.index) then
                        maxAllowedAssignedCount = math.min(serverStorageArea:availableTransferCount(object.uniqueID, tribeIDOrNilToSkipSomeChecks), 4)
                    end

                    found = true
                end
            end
        else
            if tribeIDOrNilToSkipSomeChecks then
                maxAllowedAssignedCount = math.min(serverStorageArea:availableTransferCount(object.uniqueID, tribeIDOrNilToSkipSomeChecks), 4)
            else
                maxAllowedAssignedCount = 4
            end
        end
    elseif object.objectTypeIndex == gameObject.types.sapien.index then
        maxAllowedAssignedCount = 3
    elseif gameObjectType.mobTypeIndex then --todo this won't be sufficient if other plans are added to mobs
        local mobType = mob.types[gameObjectType.mobTypeIndex]
        if mobType.maxHunterAssignCount then
            maxAllowedAssignedCount = mobType.maxHunterAssignCount
        else
            maxAllowedAssignedCount = 4
        end
    end

    
    --disabled--mj:objectLog(object.uniqueID, "serverSapien:objectIsAssignedToOtherSapien maxAllowedAssignedCount:", maxAllowedAssignedCount, " matchPlanTypeIndexArrayOrNilForAny:", matchPlanTypeIndexArrayOrNilForAny)

    local orderObjectState = object.sharedState
    if orderObjectState and orderObjectState.assignedSapienIDs then


        local function doCheck(checkPlanTypeIndexOrNil)
            local foundCountsByPlanType = {}
            local checkPlanTypeIndex = checkPlanTypeIndexOrNil or true
            for otherSapienID,assignedPlanTypeIndexOrTrue in pairs(orderObjectState.assignedSapienIDs) do
                if (not sapienOrNilForAny) or (otherSapienID ~= sapienOrNilForAny.uniqueID) then



                    local skipDueToPickupOrder = false

                    if not skipDueToPickupOrder then
                        local foundProblem = false

                        local function incrementFoundCount(incrementPlanTypeIndex)
                            
                            local foundCount = foundCountsByPlanType[incrementPlanTypeIndex] or 0
                            

                            foundCount = foundCount + 1
                            foundCountsByPlanType[incrementPlanTypeIndex] = foundCount

                            if foundCount < maxAllowedAssignedCount then
                                return true
                            end
                            return false
                        end

                    -- --disabled--mj:objectLog(sapienOrNilForAny.uniqueID, " in doCheck. checkPlanTypeIndex:", checkPlanTypeIndex, " assignedPlanTypeIndexOrTrue:", assignedPlanTypeIndexOrTrue)

                        if checkPlanTypeIndex ~= assignedPlanTypeIndexOrTrue then--and assignedPlanTypeIndexOrTrue ~= true and checkPlanTypeIndex ~= true then


                            --order.pickupObject
                            --if checkPlanTypeIndex ~= plan.types.haulObject.index then
                                if checkPlanTypeIndexOrNil then
                                    local thisMatchAllowsSimultaneous = false
                                    local planTypeA = plan.types[assignedPlanTypeIndexOrTrue]
                                    local planTypeB = plan.types[checkPlanTypeIndex]
                                    if planTypeA and planTypeB then
                                        if planTypeA.allowOtherPlanTypesToBeAssignedSimultaneously and planTypeA.allowOtherPlanTypesToBeAssignedSimultaneously[checkPlanTypeIndex] then
                                            if planTypeB.allowOtherPlanTypesToBeAssignedSimultaneously and planTypeB.allowOtherPlanTypesToBeAssignedSimultaneously[assignedPlanTypeIndexOrTrue] then
                                                thisMatchAllowsSimultaneous = true
                                            end
                                        end
                                    end

                                    if not thisMatchAllowsSimultaneous then
                                        if assignedPlanTypeIndexOrTrue ~= true then
                                            foundProblem = true
                                        end
                                    end
                                else
                                    if not incrementFoundCount(true) then
                                        foundProblem = true
                                    end
                                end
                            --end
                        else
                            if not incrementFoundCount(assignedPlanTypeIndexOrTrue) then
                                foundProblem = true
                            end
                        -- --disabled--mj:objectLog(sapienOrNilForAny.uniqueID, "checkPlanTypeIndex == assignedPlanTypeIndexOrTrue foundCount:", foundCount, " maxAllowedAssignedCount:", maxAllowedAssignedCount)
                        end


                        if foundProblem then
                            return otherSapienID
                        end
                    end
                end
            end
        end

        if matchPlanTypeIndexArrayOrNilForAny and matchPlanTypeIndexArrayOrNilForAny[1] then
            for i,matchPlanTypeIndex in ipairs(matchPlanTypeIndexArrayOrNilForAny) do
                local otherSapienID = doCheck(matchPlanTypeIndex)
                if otherSapienID then
                    return otherSapienID
                end
            end
        else
            local otherSapienID = doCheck(nil)
            if otherSapienID then
                return otherSapienID
            end
        end
    end

    return nil
end]]

function serverSapien:cancelAllOrders(sapien, cancelSleepOrdersEvenIfUnconcious, removeManualAssignedPlanObject)
    local sharedState = sapien.sharedState
    local orderQueue = sharedState.orderQueue
    local allOrdersHaveBeenCancelled = true
    if orderQueue then
       -- mj:log("serverSapien:cancelAllOrders A", sapien.uniqueID)
        for i =#orderQueue,1,-1 do
            --mj:log("serverSapien:cancelOrder:", i)
            
            local orderState = sharedState.orderQueue[i]
            local skip = false
            

            if orderState.orderTypeIndex == order.types.fall.index then
                skip = true
            end

            if not cancelSleepOrdersEvenIfUnconcious then
                if sharedState.statusEffects[statusEffect.types.unconscious.index] then
                    if orderState.orderTypeIndex == order.types.sleep.index then
                        skip = true
                    end
                end
            end

            if skip then
                allOrdersHaveBeenCancelled = false
            else
                local removeHeldObjectOrderContext = true
                -- mj:log("serverSapien:cancelOrderAtQueueIndex:", i)

                local function addCooldownsForObject(objectID)
                    local cooldowns = serverSapienAI.aiStates[sapien.uniqueID].cooldowns
                    if not cooldowns then
                        cooldowns = {}
                        serverSapienAI.aiStates[sapien.uniqueID].cooldowns = cooldowns
                    end
                    
                    cooldowns["plan_" .. objectID] = 30.0
                    cooldowns["m_" .. objectID] = 30.0
                        
                end

                if orderState.context and orderState.context.planObjectID then --these cooldowns are added to help prevent issues with campfires, where everyone keeps trying to add fuel, but gets cancelled by closer people
                    addCooldownsForObject(orderState.context.planObjectID)
                end
                if orderState.objectID then
                    addCooldownsForObject(orderState.objectID)
                end

                serverSapien:cancelOrderAtQueueIndex(sapien, i, removeHeldObjectOrderContext)

                --disabled--mj:objectLog(sapien.uniqueID, " cancelled all orders. cooldowns:", serverSapienAI.aiStates[sapien.uniqueID].cooldowns)
            end
        end
    end
    
    if removeManualAssignedPlanObject then
        local manualAssignedPlanObject = sharedState.manualAssignedPlanObject
        if manualAssignedPlanObject then
            sharedState:remove("manualAssignedPlanObject")
            local object = serverGOM:getObjectWithID(manualAssignedPlanObject)
            if object then
                planManager:removeManualAssignmentsForPlanObjectForSapien(object, sapien)
            end
        end
    end

    return allOrdersHaveBeenCancelled
end

function serverSapien:cancelOrdersMatchingPlanTypeIndex(sapien, planTypeIndex)
    local sharedState = sapien.sharedState
    local orderQueue = sharedState.orderQueue
    local found = false
    if orderQueue then
        --mj:log("cancelOrderWithNPCOrderID" .. mj:tostring(orderID))
        for i =#orderQueue,1,-1 do
            local orderState = orderQueue[i]
            local orderContext = orderState.context
            if orderContext then
                if orderContext.planTypeIndex == planTypeIndex then
                    local removeHeldObjectOrderContext = true
                    serverSapien:cancelOrderAtQueueIndex(sapien, i, removeHeldObjectOrderContext)
                    found = true
                end
            end
        end
    end
    return found
end

function serverSapien:getMaxCarryCount(sapien, resourceTypeIndex)
    if not serverSapienAI:checkNeedsAllowObjectTypeToBeCarried(resourceTypeIndex, 
    desire:getDesire(sapien, need.types.food.index, false), 
    desire:getDesire(sapien, need.types.rest.index, true), 
    desire:getCachedSleep(sapien, sapien.temporaryPrivateState, function() 
        return serverWorld:getTimeOfDayFraction(sapien.pos) 
    end), 
    mood:getMood(sapien, mood.types.happySad.index)) then
        return 0
    end
    return storage:maxCarryCountForResourceType(resourceTypeIndex)
end


function serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, orderObject, context, cancelCurrentOrders)
   -- if orderObject then
    --    mj:log("serverSapien:addOrder", sapien.uniqueID, " - ", orderObject.uniqueID)
   -- end
    --mj:log("serverSapien:addOrder:", sapien.uniqueID, " orderType:", order.types[orderTypeIndex].name)
   -- mj:log(debug.traceback())
   
   
    if sapien.uniqueID == mj.debugObject then
        if not serverSapien.privateTransientStates[sapien.uniqueID] then
            serverSapien.privateTransientStates[sapien.uniqueID] = {}
        end
        serverSapien.privateTransientStates[sapien.uniqueID].addOrderTraceback = debug.traceback()
        --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:addOrder:", order.types[orderTypeIndex].key, " (", orderTypeIndex, ")")
        --disabled--mj:objectLog(sapien.uniqueID, serverSapien.privateTransientStates[sapien.uniqueID].addOrderTraceback)
    end

    local sapienState = sapien.sharedState
    if not cancelCurrentOrders and #sapienState.orderQueue > 2 then
        mj:error("ignoring serverSapien:addOrder due to long order queue:", sapien.uniqueID, " orderType:", order.types[orderTypeIndex].name)
        mj:log(debug.traceback())
        return
    end

    local orderState = order:createOrder(orderTypeIndex, sapien, pathInfo, orderObject, context)

    if not sapienState.orderIDCounter then
        sapienState:set("orderIDCounter", 1)
    end

    orderState.sapienOrderID = sapienState.orderIDCounter
    
    sapienState:set("orderIDCounter", sapienState.orderIDCounter + 1)

    if cancelCurrentOrders then
        serverSapien:cancelAllOrders(sapien, false, false)
    end

    if order.types[orderState.orderTypeIndex].standingOrder then
        local standingOrderAddIndex = 1
        if sapienState.standingOrders then
            standingOrderAddIndex = #sapienState.standingOrders + 1
        end
        sapienState:set("standingOrders", standingOrderAddIndex, orderState)
    else
       --[[ if cancelCurrentOrders then
            local insertIndex = 1
            if sapienState.activeOrder then
                insertIndex = 2
            end

            local replaced = false
            if sapienState.orderQueue[insertIndex] then
                local currentFrontOfQueueOrder = sapienState.orderQueue[insertIndex]
                if currentFrontOfQueueOrder.orderTypeIndex == orderState.orderTypeIndex then -- if we already have a move or dispose order at the front of the queue, replace it. Avoids accidentally queuing up a million drop object orders if something goes wrong
                    --sapienState.orderQueue[insertIndex] = orderState
                    sapienState:set("orderQueue", insertIndex, orderState)

                    replaced = true
                end
            end

            if not replaced then
                for i=#sapienState.orderQueue,insertIndex,-1 do
                    sapienState:set("orderQueue", i + 1, sapienState.orderQueue[i])
                end
                sapienState:set("orderQueue", insertIndex, orderState)
                --table.insert(sapienState.orderQueue, insertIndex, orderState)
            end
        else]]
            local insertIndex = 1
            if sapienState.orderQueue then
                insertIndex = #sapienState.orderQueue + 1
            end
            sapienState:set("orderQueue", insertIndex, orderState)
        --end
    end

    if sapienState.haulingObjectID and ((not orderObject) or orderObject.uniqueID ~= sapienState.haulingObjectID) then
        serverSapien:setHaulDragingObject(sapien, nil)
    end

    sapien.privateState.iteratePlansStartIndex = nil --we found something to do, so next time, start at the highest priority orders again
    serverSapien:saveState(sapien)
end

function serverSapien:addOrderCreatingObject(sapien, orderTypeIndex, gameObjectTypeIndex, pathInfo, objectPos, objectSharedState, incomingOrderContext)
    local gameObjectType = gameObject.types[gameObjectTypeIndex]
    local objectID = serverGOM:createGameObject({
        objectTypeIndex = gameObjectTypeIndex,
        addLevel = mj.SUBDIVISIONS - 3,
        pos = objectPos,
        rotation = mj:getNorthFacingFlatRotationForPoint(objectPos),
        velocity = vec3(0.0,0.0,0.0),
        scale = gameObjectType.scale,
        renderType = gameObjectType.renderTypeOverride or RENDER_TYPE_STATIC,
        hasPhysics = gameObjectType.hasPhysics,
        sharedState = objectSharedState,
        privateState = {
            removeWhenOrderComplete = true,
        },
    })

    local orderContext = incomingOrderContext or {}
    orderContext.planObjectID = orderContext.planObjectID or objectID

    if objectID then
        local object = serverGOM:getObjectWithID(objectID)
        serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, object, orderContext, false)
    end
    return objectID
end

--[[function serverSapien:updateCurrentOrderPathInfo(sapien, pathInfo)
    local sharedState = sapien.sharedState
    if sharedState.orderQueue[1] then
        sharedState:set("orderState", 1, "pathInfo", pathInfo)
    end
end]]


function serverSapien:assignBed(sapien, bedObjectID)
    local bed = serverGOM:getObjectWithID(bedObjectID)
    if bed and gameObject.types[bed.objectTypeIndex].isBed then

        serverSeat:removeSeatNodes(bed) --not as drastic as it sounds, the nodes will get recreated, this is just to kick everyone out of my bed

        local bedTribeID = bed.sharedState.tribeID
        local sapienTribeID = sapien.sharedState.tribeID

        if bedTribeID ~= sapienTribeID and serverWorld:tribeIsValidOwner(bedTribeID) then
            serverTribeAIPlayer:addGrievanceIfNeededForBedUsed(bedTribeID, sapien.sharedState.tribeID)
            return
        end

        if sapien.sharedState.assignedBedID then
            local prevBed = serverGOM:getObjectWithID(sapien.sharedState.assignedBedID)
            if not prevBed then
                terrain:loadArea(sapien.sharedState.assignedBedPos)
                prevBed = serverGOM:getObjectWithID(sapien.sharedState.assignedBedID)
            end
            if prevBed then
                prevBed.sharedState:remove("assignedBedSapienID")
                prevBed.sharedState:remove("assignedBedSapienName")
            end

            sapien.sharedState:remove("assignedBedID")
            sapien.sharedState:remove("assignedBedPos")
        end

        if bed.sharedState.assignedBedSapienID and bed.sharedState.assignedBedSapienID ~= sapien.uniqueID then
            local assignedSapien = serverGOM:getObjectWithID(bed.sharedState.assignedBedSapienID)
            if assignedSapien and assignedSapien.assignedBedPos then
                assignedSapien.sharedState:set("homePos", assignedSapien.assignedBedPos)
                assignedSapien.sharedState:remove("assignedBedID")
                assignedSapien.sharedState:remove("assignedBedPos")
            end
        end

        sapien.sharedState:set("assignedBedID", bedObjectID)
        sapien.sharedState:set("assignedBedPos", bed.pos)
        bed.sharedState:set("assignedBedSapienID", sapien.uniqueID)
        bed.sharedState:set("assignedBedSapienName", sapien.sharedState.name)
    end
end

function serverSapien:addMoveOrder(sapien, rawMoveToPos, addWaitOrderWhenDone, moveToObjectID, assignBed)
    
    serverSapien:cancelAllOrders(sapien, false, false)
    if not addWaitOrderWhenDone then
        serverSapien:cancelWaitOrder(sapien)
    end

    if assignBed and moveToObjectID then
        serverSapien:assignBed(sapien, moveToObjectID)
    end

    local moveToPos = worldHelper:getSantizedMoveToPos(rawMoveToPos)

    if not moveToPos then
        return false
    end

    --[[local movePosLength2 = length2(moveToPos)
    if movePosLength2 < 1.0 then
        moveToPos = moveToPos / math.sqrt(movePosLength2)
    end]]
    local planTypeIndex = plan.types.moveTo.index
    if addWaitOrderWhenDone then
        planTypeIndex = plan.types.moveAndWait.index
    end
    local objectSharedState = {
        planStates = {
            [sapien.sharedState.tribeID] = {
                {
                    planTypeIndex = planTypeIndex,
                    sapienID = sapien.uniqueID,
                    canComplete = true,
                },
            }
        }
    }
    local orderContext = {
        planTypeIndex = planTypeIndex,
        moveToObjectID = moveToObjectID,
    }

    
    local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, moveToPos)

    --mj:log("serverSapien:addMoveOrder pathInfo:", pathInfo)
    

    serverSapien:addOrderCreatingObject(sapien, order.types.moveTo.index, gameObject.types.plan_move.index, pathInfo, moveToPos, objectSharedState, orderContext)
    return true
end

function serverSapien:addWaitOrder(sapien)
    serverSapien:cancelAllOrders(sapien, false, false)
    sapien.sharedState:set("waitOrderSet", true)
end

function serverSapien:cancelWaitOrder(sapien)
    sapien.sharedState:remove("waitOrderSet")
end

function serverSapien:seatMoved(sapien, seatObject, seatNodeWorldPos)
    if seatNodeWorldPos then
        serverGOM:setPos(sapien.uniqueID, seatNodeWorldPos, false)
    else
        if serverSapien:cancelAllOrders(sapien, true, false) then
            local clampToSeaLevel = true
            local fallPos = worldHelper:getBelowSurfacePos(sapien.pos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
            local orderContext = {
                targetPos = fallPos,
                startPos = sapien.pos
            }
            serverSapien:addOrder(sapien, order.types.fall.index, nil, nil, orderContext, false)
        end
    end
end

function serverSapien:getOrderStatusUserDataForNotification(sapien)
    local orderState = sapien.sharedState.orderQueue[1]
    if not orderState then
        return nil
    end

    local heldObjectTypeIndex = nil
    local heldObjectName = nil
    local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)
    if heldObjectCount > 0 then
        local objectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
        heldObjectTypeIndex = objectInfo.objectTypeIndex
        heldObjectName = objectInfo.name
    end

    local function createOrderStatusObjectInfo(object)
        if object and object.sharedState then
            return {
                objectTypeIndex = object.objectTypeIndex,
                sharedState = {
                    inProgressConstructableTypeIndex = object.sharedState.inProgressConstructableTypeIndex, --todo may need to send through the planState's one
                    name = object.sharedState.name,
                }
            }
        end
        return nil
    end

    local orderObjectInfo = nil
    if orderState.objectID then
        orderObjectInfo = createOrderStatusObjectInfo(serverGOM:getObjectWithID(orderState.objectID))
    end
    
    local planObjectInfo = nil
    local orderContext = orderState.context
    if orderContext and orderContext.planObjectID and orderContext.planTypeIndex then
        planObjectInfo = createOrderStatusObjectInfo(serverGOM:getObjectWithID(orderContext.planObjectID))
    end

    return {
        orderState = orderState,
        heldObjectCount = heldObjectCount,
        heldObjectTypeIndex = heldObjectTypeIndex,
        heldObjectName = heldObjectName,
        orderObjectInfo = orderObjectInfo,
        planObjectInfo = planObjectInfo,
    }
end

function serverSapien:fallAndGetInjured(sapien, 
    directionFromAttackerToSapien, 
    options_) --todo pass through an options dict for everything instead

    if not serverSapien:cancelAllOrders(sapien, true, false) then
        return
    end

    local options = options_ or {}

    local fallDistanceMeters = 4.0
    if options.attackMobType then
        fallDistanceMeters = 8.0
    end

    local fallPos = sapien.pos + directionFromAttackerToSapien * mj:mToP(fallDistanceMeters)

    local clampToSeaLevel = true
    fallPos = worldHelper:getBelowSurfacePos(fallPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
    local orderContext = {
        targetPos = fallPos,
        startPos = sapien.pos
    }
    removeInventory(sapien, true)
    --mj:log("add fall order:", sapien.uniqueID, " current actionState:", sapien.sharedState.actionState)
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    if unsavedState.waitingForPathID then
        mj:error("unsavedState.waitingForPathID")
        error()
    end

    if sapien.sharedState.actionState then
        mj:error("sapien.sharedState.actionState")
        error()
    end

    if (not statusEffect:hasEffect(sapien.sharedState, statusEffect.types.majorInjury.index)) and (not statusEffect:hasEffect(sapien.sharedState, statusEffect.types.criticalInjury.index)) then
        local notificationContext = {}

        if options.attackMobType then
            notificationContext.mobTypeIndex = options.attackMobType.index
        end

        if options.hitByFlyingObjectTypeIndex then
            notificationContext.hitByFlyingObjectTypeIndex = options.hitByFlyingObjectTypeIndex
        end

        if options.hitBySapien then
            local destinationState = serverDestination:getDestinationState(options.hitBySapien.sharedState.tribeID)
            notificationContext.hitBySapienTribeName = destinationState and destinationState.name
        end

        local randomChance = rng:randomInteger(20)
        if randomChance < 12 or (not options.allowMajorInjuries) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorInjury.index, sapienConstants.injuryDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.minorInjury.index, notificationContext, sapien.sharedState.tribeID)
        elseif randomChance < 18 or options.preventCriticalInjuries then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorInjury.index, sapienConstants.injuryDuration)
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.unconscious.index, 10.0)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorInjury.index, notificationContext, sapien.sharedState.tribeID)
        else
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.criticalInjury.index, sapienConstants.injuryDuration)
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.unconscious.index, 30.0)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalInjury.index, notificationContext, sapien.sharedState.tribeID)
        end
        planManager:addStandardPlan(sapien.sharedState.tribeID, plan.types.treatInjury.index, sapien.uniqueID, nil, nil, nil, nil, nil, nil)
    end

    serverSapien:addOrder(sapien, order.types.fall.index, nil, nil, orderContext, false)

end


function serverSapien:assignAttackPlansIfNeededForDefensePlan(sapien, objectToAttack, attackPlanTypeIndex)
    if not planManager:hasPlanForObjectSapienAndType(sapien, objectToAttack, attackPlanTypeIndex) then
        planManager:addPlans(sapien.sharedState.tribeID, {
            planTypeIndex = attackPlanTypeIndex,
            objectOrVertIDs = {objectToAttack.uniqueID},
        })
    end
    planManager:assignSapienToPlan(sapien.sharedState.tribeID, {
        sapienID = sapien.uniqueID,
        planObjectID = objectToAttack.uniqueID,
        planTypeIndex = attackPlanTypeIndex,
    })
    --disabled--mj:objectLog(sapien.uniqueID, "set assignAttackPlansIfNeededForDefensePlan")
    mj:conflictLog(sapien, objectToAttack, "is now attacking")
end

function serverSapien:assignAttackPlansIfNeeded(sapien, objectToAttack) --don't call this for player owned sapiens, it is assumed AI/nomad only.
    if not planManager:hasPlanForObjectSapienAndType(sapien, objectToAttack, plan.types.attack_handToHand.index) then
        --disabled--mj:objectLog(sapien.uniqueID, "added plans")
        planManager:addPlans(sapien.sharedState.tribeID, {
            planTypeIndex = plan.types.attack_handToHand.index,
            objectOrVertIDs = {objectToAttack.uniqueID},
        })
        planManager:addPlans(sapien.sharedState.tribeID, {
            planTypeIndex = plan.types.attack_throwRock.index,
            objectOrVertIDs = {objectToAttack.uniqueID},
        })
        planManager:addPlans(sapien.sharedState.tribeID, {
            planTypeIndex = plan.types.attack_throwSpear.index,
            objectOrVertIDs = {objectToAttack.uniqueID},
        })
    end

    --todo they are all experts in all types of attacks?

    serverSapien:setSkillPriority(sapien, skill.types.handToHandCombat.index, 1)
    serverSapienSkills:completeSkill(sapien, skill.types.handToHandCombat.index)
    serverSapien:setSkillPriority(sapien, skill.types.basicHunting.index, 1)
    serverSapienSkills:completeSkill(sapien, skill.types.basicHunting.index)
    serverSapien:setSkillPriority(sapien, skill.types.spearHunting.index, 1)
    serverSapienSkills:completeSkill(sapien, skill.types.spearHunting.index)

    planManager:assignSapienToPlan(sapien.sharedState.tribeID, {
        sapienID = sapien.uniqueID,
        planObjectID = objectToAttack.uniqueID,
        planTypeIndex = plan.types.attack_handToHand.index,
    })
    --sharedState:set("attackTargetObject", objectToAttack.uniqueID)

    --disabled--mj:objectLog(sapien.uniqueID, "set attackTargetObject")
    mj:conflictLog(sapien, objectToAttack, "is now attacking")
    
end

function serverSapien:doRecruitOrBanishResponseIfNeeded(sapien, banishingOrRecruitingObject, planTypeIndex) --this happens after 1 second, when they react 'notice' that they are being banished or recurited. returns true if we should cancel this action
    
    local sharedState = sapien.sharedState
    if sharedState.statusEffects[statusEffect.types.unconscious.index] then
        return true
    end

    if serverSapien:isFightingThisObjectOrCloser(sapien, banishingOrRecruitingObject) then
        --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:isFightingThisObjectOrCloser returned true")
        return false
    end

    if serverSapien:getIsFalling(sapien) then
        return false
    end

    if not serverSapien:cancelAllOrders(sapien, false, true) then
        return false
    end

    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:cancelAllOrders called")

    local shouldSendTurnOrder = true
    findOrderAI:updateLookAtPosAndTurnAndFaceIfNeeded(sapien, banishingOrRecruitingObject.pos, banishingOrRecruitingObject.uniqueID, shouldSendTurnOrder)
    
    local gameDifficultyMode = serverWorldSettings:get("gameDifficulty")
    local isPeaceful = gameDifficultyMode == "peaceful"

    if sharedState.nomad then
        if (not nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].isRaid) then
            serverSapien:dropHeldInventoryImmediately(sapien)
        end

        local aiState = serverSapienAI.aiStates[sapien.uniqueID]
        aiState.lastRecruitOrBanishNoticedTime = serverWorld:getWorldTime()

        if isPeaceful or sapienConstants:getHasLimitedGeneralAbility(sharedState, false) or (not nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].isRaid) then
            return false
        else
            local fightChance = 0.2
            --todo use courage trait
            local fight = rng:randomChance(fightChance)
            if fight then
                serverSapien:assignAttackPlansIfNeeded(sapien, banishingOrRecruitingObject)
                return false
            end
        end
    else --todo ai tribes, maybe a multiplayer setting also?
        return false
    end

    return false

end

function serverSapien:getIsFalling(sapien)
    local orderState = sapien.sharedState.orderQueue[1]
    return orderState and orderState.orderTypeIndex == order.types.fall.index
end

function serverSapien:doFightOrFlightResponseIfNeeded(sapien, attackingObject, isDirectAttack) --returns true if they are unconicous or decided to run away. Called when the sapien notices each attack action or close threat. attackingObject could be a mob or other sapien
    local sharedState = sapien.sharedState
    if (not isDirectAttack) and sharedState.nomad then --nomads are not going to run away or attack unless provoked for now
        return false
    end
    
    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:doFightOrFlightResponseIfNeeded")

    local gameDifficultyMode = serverWorldSettings:get("gameDifficulty")
    local isPeaceful = gameDifficultyMode == "peaceful"

    if sharedState.statusEffects[statusEffect.types.unconscious.index] then
        return true
    end

    if serverSapien:isFightingThisObjectOrCloser(sapien, attackingObject) then
        --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:isFightingThisObjectOrCloser returned true")
        return false
    end

    if serverSapien:getIsFalling(sapien) then
        return false
    end

    if not serverSapien:cancelAllOrders(sapien, false, true) then
        return false
    end

    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:cancelAllOrders called")

    --TODO don't drop if it is useable as a weapon or defense bonus
    serverSapien:dropHeldInventoryImmediately(sapien)


    if sharedState.nomad then
        --disabled--mj:objectLog(sapien.uniqueID, "is nomad")
        --todo if we are too far away from the attacker and have no ranged weapon, run away

        local flee = false
        if isPeaceful or sapienConstants:getHasLimitedGeneralAbility(sharedState, false) then
            flee = true
            mj:conflictLog(sapien, attackingObject, "is fleeing from", " due to limited ability or peaceful game mode")
        else
            local fleeChance = nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].fleeChance or 0.5
            flee = rng:randomChance(fleeChance)
            if flee then
                mj:conflictLog(sapien, attackingObject, "is fleeing from", " due to fleeChance:", fleeChance)
            else
                mj:conflictLog(sapien, attackingObject, "is not fleeing from", " due to fleeChance:", fleeChance)
            end
        end


        if flee then
            --disabled--mj:objectLog(sapien.uniqueID, "fleeing")
            sharedState:set("fleeing", true)
            mj:debug("fleeing")
            sharedState:remove("manualAssignedPlanObject")
            return true
        end

        serverSapien:assignAttackPlansIfNeeded(sapien, attackingObject)

        --todo send a shout! HELP

        serverGOM:callFunctionForAllSapiensInTribe(sharedState.tribeID, function(otherSapien)
            if otherSapien.uniqueID ~= sapien.uniqueID then
                if (not otherSapien.sharedState.fleeing) and (not serverSapien:isFightingThisObjectOrCloser(otherSapien, attackingObject)) then
                    serverSapien:assignAttackPlansIfNeeded(otherSapien, attackingObject)
                end
            end
        end)
    else
        if isPeaceful then
            serverSapienAI:addOrderToFlee(sapien, normalize(sapien.pos - attackingObject.pos))
        else
            local destinationState = serverDestination:getDestinationState(sharedState.tribeID)
            if destinationState.clientID then
                if isDirectAttack then
                    if not sapien.privateState.underAttackLastSentNotificationWorldTime or (serverWorld:getWorldTime() - sapien.privateState.underAttackLastSentNotificationWorldTime > 200) then
                        sapien.privateState.underAttackLastSentNotificationWorldTime = serverWorld:getWorldTime()
                        local notificationContext = {}
                        serverGOM:sendNotificationForObject(sapien, notification.types.sapienUnderAttack.index, notificationContext, sapien.sharedState.tribeID)
                    end
                end

                local attackPlanIndex = planManager:getAttackPlanForSapien(sapien, attackingObject)
                
                if attackPlanIndex then
                    planManager:assignSapienToPlan(sharedState.tribeID, {
                        sapienID = sapien.uniqueID,
                        planObjectID = attackingObject.uniqueID,
                        planTypeIndex = attackPlanIndex,
                    })
                    --disabled--mj:objectLog(sapien.uniqueID, "set attackTargetObject")
                    mj:conflictLog(sapien, attackingObject, "is now attacking")
                else
                    serverSapienAI:addOrderToFlee(sapien, normalize(sapien.pos - attackingObject.pos))
                    mj:conflictLog(sapien, attackingObject, "is fleeing from")
                    
                    if not sapien.privateState.fleeingLastSentNotificationWorldTime or (serverWorld:getWorldTime() - sapien.privateState.fleeingLastSentNotificationWorldTime > 200) then
                        sapien.privateState.fleeingLastSentNotificationWorldTime = serverWorld:getWorldTime()
                        local notificationContext = {}
                        serverGOM:sendNotificationForObject(sapien, notification.types.sapienFleeing.index, notificationContext, sapien.sharedState.tribeID)
                    end

                    return true
                end

            else --sapien is from an ai tribe
                
                --todo if we are too far away from the attacker and have no ranged weapon, run away

                local flee = false
                if isPeaceful or sapienConstants:getHasLimitedGeneralAbility(sharedState, false) then
                    flee = true
                    mj:conflictLog(sapien, attackingObject, "is fleeing from", " due to limited ability or peaceful game mode")
                else
                    local fleeChance = 0.5
                    flee = rng:randomChance(fleeChance)
                    if flee then
                        mj:conflictLog(sapien, attackingObject, "is fleeing from", " due to fleeChance:", fleeChance)
                    else
                        mj:conflictLog(sapien, attackingObject, "is not fleeing from", " due to fleeChance:", fleeChance)
                    end
                end


                if flee then
                    serverSapienAI:addOrderToFlee(sapien, normalize(sapien.pos - attackingObject.pos))
                    return true
                end

                serverSapien:assignAttackPlansIfNeeded(sapien, attackingObject)
            end
        end
    end
    
    return false
end

function serverSapien:getIsThreatening(sapien) --called by mobs and other sapiens
    local sharedState = sapien.sharedState

    if sharedState.hasBaby or sharedState.pregnant or sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then
        return false
    end

    if sharedState.statusEffects[statusEffect.types.unconscious.index] then
        return false
    end

    --mj:log("sharedState:", sharedState)
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderTypeIndex = sharedState.orderQueue[1].orderTypeIndex
        if orderTypeIndex == order.types.sleep.index or
        orderTypeIndex == order.types.fall.index then
            return false
        end
    end

    if sapien.sharedState.seatObjectID then
        return false
    end
    
    if sapien.sharedState.actionModifiers and sapien.sharedState.actionModifiers[action.modifierTypes.sit.index] then
        return false
    end

    return true
end

function serverSapien:getOtherSapienThreatLevel(sapien, otherSapien) --currently only returns 0 or 1
    if serverSapien:getIsThreatening(otherSapien) then
        if serverTribe:getOtherTribeIsThreatening(sapien.sharedState.tribeID, otherSapien.sharedState.tribeID) then
            return 1
        end
    end

    return 0
end

local maxGoalDistanceChangeBeforeShouldRecalculatePath2 = mj:mToP(2.0) * mj:mToP(2.0)

--two conflicting use cases
-- a) goal pos for butchering a mammoth is offset from the object maybe, takes priority
-- b) goal pos for hunting has moved, object takes priority

-- note initialObjectPos added 0.7

function serverSapien:needsToRecalculatePathDueToGoalObjectMovement(sapien) --todo this could increase the distance threshold for recalculations for long paths
    local orderState = sapien.sharedState.orderQueue[1]
    local pathInfo = orderState.pathInfo

    --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:needsToRecalculatePathDueToGoalObjectMovement pathInfo:", pathInfo)
    
    if pathInfo and pathInfo.goalObjectIDOrNil and pathInfo.initialObjectPos then
        local goalObject = serverGOM:getObjectWithID(pathInfo.goalObjectIDOrNil)
        if not goalObject then
            return false --handle elsewhere
        end
        local newDistance2 = length2(pathInfo.initialObjectPos - goalObject.pos)
        
        --disabled--mj:objectLog(sapien.uniqueID, "object has moved::", mj:pToM(math.sqrt(newDistance2)))
        if newDistance2 > maxGoalDistanceChangeBeforeShouldRecalculatePath2 then
            return true
        end
    end

    return false
end

function serverSapien:getGoalPosInfoForPathInfo(pathInfo, sapien)
    --mj:log("getGoalPosInfoForPathInfo:", pathInfo)
    local result = {
        goalPos = nil,
        shouldCancel = nil
    }
    if pathInfo then
        if pathInfo.goalPosOrNil then
            result.goalPos = pathInfo.goalPosOrNil
        elseif pathInfo.goalObjectIDOrNil then
            local goalObject = serverGOM:getObjectWithID(pathInfo.goalObjectIDOrNil)
            if not goalObject then
                result.shouldCancel = true
                return result
            end
            result.goalPos = goalObject.pos
        end

        --[[if pathInfo.goalObjectIDOrNil then
            local goalObject = serverGOM:getObjectWithID(pathInfo.goalObjectIDOrNil)
        elseif pathInfo.goalPosOrNil then
            result.goalPos = pathInfo.goalPosOrNil
        else
            result.shouldCancel = true
        end]]

        

       --[[ if pathInfo.goalPosOrNil then -- 10/25 goalPosOrNil became the priority instead of goalObjectIDOrNil, and got rid of cancelling when object moves
            result.goalPos = pathInfo.goalPosOrNil
        elseif pathInfo.goalObjectIDOrNil then
            local goalObject = serverGOM:getObjectWithID(pathInfo.goalObjectIDOrNil)
            if not goalObject then
                result.shouldCancel = true
                return result
            else]]
                --[[if pathInfo.goalPosOrNil then
                    local newDistance2 = length2(pathInfo.goalPosOrNil - goalObject.pos)
                    if newDistance2 > maxGoalDistanceChangeBeforeShouldCancel2 then
                        result.shouldCancel = true
                        return result
                    end
                end]]

                --[[result.goalPos = goalObject.pos
            end
        end]]
    else
        result.shouldCancel = true --added 19/6/21, slightly dubious, but added to fix bad state.
    end
    return result
end


local function doCancel(sapien)
    --disabled--mj:objectLog(sapien.uniqueID, "doCancel")
    local removeHeldObjectOrderContext = false
    serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
end

local function checkPathValidAndGetInfo(sapienID, orderObjectID, orderTypeIndex, prevActionStateSequenceTypeIndex, pathID, createdPathInfo)
    local sapien = serverGOM:getObjectWithID(sapienID)
    if not sapien then
        return nil
    end
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    if unsavedState.waitingForPathID ~= pathID then
        return nil
    end

    unsavedState.waitingForPathID = nil
    
    local sharedState = sapien.sharedState
    
    local orderQueue = sharedState.orderQueue
    if not orderQueue then
        return nil
    end

    local orderState = orderQueue[1]
    if not orderState or orderState.orderTypeIndex ~= orderTypeIndex or orderState.objectID ~= orderObjectID then
        return nil
    end

    local orderObject = nil
    if orderObjectID then
        orderObject = serverGOM:getObjectWithID(orderObjectID)
        if not orderObject then
            --disabled--mj:objectLog(sapien.uniqueID, "doCancel b")
            doCancel(sapien)
            return nil
        end
    end

    local actionStateToAssign = serverSapien:createActionStateForOrder(sapien, orderObject, orderState)

    if not actionStateToAssign or actionStateToAssign.sequenceTypeIndex ~= prevActionStateSequenceTypeIndex then
        doCancel(sapien)
        return nil
    end

    --disabled--mj:objectLog(sapienID, "pathCreator:createdPathInfo:", createdPathInfo)
    

    if createdPathInfo.inaccessible then
        mj:warn(sapienID, ": inaccessible path doCancel:", orderObjectID)
        if orderObject then
            serverGOM:setInaccessible(orderObject)
        end
        doCancel(sapien)
        return nil
    end
    
    local seatNodeIndex = nil
    local planTypeIndex = nil
    if orderState and orderState.context then
        seatNodeIndex = orderState.context.seatNodeIndex
        planTypeIndex = orderState.context.planTypeIndex
    end

    local planObjectID = nil
    if orderState and orderState.context then
        planObjectID = orderState.context.planObjectID
    end

    local isAssigned = false
    if orderObject and planTypeIndex then
        if planObjectID == orderObject.uniqueID then
            local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
            if not planObjectSapienAssignmentInfo.available then
                isAssigned = true
            end
        else
            if seatNodeIndex then
                isAssigned = serverSapien:seatIsAssignedToOtherSapien(orderObject, seatNodeIndex, sapien)
            end

            if not isAssigned then
                isAssigned = serverSapien:objectIsAssignedToOtherSapien(orderObject, sapien.sharedState.tribeID, sapien, {planTypeIndex}, false)
            end
        end
    end
    --disabled--mj:objectLog(sapienID, "isAssigned:", isAssigned)

    if (not isAssigned) and planObjectID then
        if (not orderObject) or planObjectID ~= orderObject.uniqueID then
            local planObjectReloaded = serverGOM:getObjectWithID(planObjectID)
            if planObjectReloaded and planTypeIndex then

                local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(planObjectReloaded, sapien, planTypeIndex)
                if not planObjectSapienAssignmentInfo.available then
                    isAssigned = true
                end

                --isAssigned = serverSapien:objectIsAssignedToOtherSapien(planObjectReloaded, sapien.sharedState.tribeID, nil, sapien, {planTypeIndex}, true)
                --disabled--mj:objectLog(sapienID, "plan object isAssigned:", isAssigned)
            end
        end
    end

    --[[if isAssigned then
        if sapien.sharedState.manualAssignedPlanObject == planObjectID then
        end
    end]]

    if isAssigned then
        --disabled--mj:objectLog(sapien.uniqueID, "doCancel isAssigned")
        doCancel(sapien)
        return nil
    end
    return {
        sapien = sapien,
        actionStateToAssign = actionStateToAssign,
        orderObject = orderObject,
        orderState = orderState,
    }
end

local requestedPathUpdatesBySapienID = {}


local function pathUpdateReceived(sapienID, orderObjectID, orderTypeIndex, prevActionStateSequenceTypeIndex, pathID, createdPathInfo)
    requestedPathUpdatesBySapienID[sapienID] = nil
    local completionInfo = checkPathValidAndGetInfo(sapienID, orderObjectID, orderTypeIndex, prevActionStateSequenceTypeIndex, pathID, createdPathInfo)

    if completionInfo then
        local sapien = completionInfo.sapien
        local sharedState = sapien.sharedState
        if createdPathInfo.noMovementRequired then
            mj:warn("createdPathInfo.noMovementRequired in serverSapien:requestPathUpdateIfNotRequested, which is puzzling and I don't know what to do")
        else
            if createdPathInfo.valid then
                sharedState:set("actionState", "path", createdPathInfo)
                sharedState:set("actionState", "pathNodeIndex", math.min(2, #createdPathInfo.nodes))
                --actionState.pathNodeIndex = 1
            -- mj:log("updated path received and added:", sapienID, " incomingNodes:", incomingNodes)
            else
                if createdPathInfo.complete then
                    mj:error("no path, cancelling action:", sapienID)
                    doCancel(sapien)
                else
                    mj:warn("no path, will try again soon:", sapienID, " createdPathInfo:", createdPathInfo)
                    if createdPathInfo.goalPos then
                        terrain:loadArea(normalize(createdPathInfo.goalPos)) --might help stop hunters getting stuck
                    end
                    
                end
            end
        end
    else
        mj:warn("path update came back when sapien no longer wanted it:", sapienID)
    end
end

function serverSapien:requestPathUpdateIfNotRequested(sapien)

   -- mj:log("serverSapien:requestPathUpdateIfNotRequested:", sapien.uniqueID)
   -- mj:log(debug.traceback())
    local sapienID = sapien.uniqueID

    if not requestedPathUpdatesBySapienID[sapienID] then


        --mj:log("requesting path")
        requestedPathUpdatesBySapienID[sapienID] = true
        local sharedState = sapien.sharedState
        local actionState = sharedState.actionState
        local incompletePathInfo = actionState.path
        --local nodes = pathInfo.nodes

        local orderState = sharedState.orderQueue[1]
        local orderStatePathCreationInfo = orderState.pathInfo

        if orderStatePathCreationInfo and orderStatePathCreationInfo.goalObjectIDOrNil and orderStatePathCreationInfo.initialObjectPos then
            local goalObject = serverGOM:getObjectWithID(orderStatePathCreationInfo.goalObjectIDOrNil)
            if goalObject and orderStatePathCreationInfo.initialObjectPos.x ~= goalObject.pos.x then

                local moveToPos = goalObject.pos
                
                if goalObject.objectTypeIndex == gameObject.types.sapien.index then --this code should be kept the same as in ai.lua addOrderForOrderInfo
                    if orderState.context and (orderState.context.planTypeIndex == plan.types.banish.index or orderState.context.planTypeIndex == plan.types.recruit.index) then --todo this is what, social plan? get in front of sapien's face
                        --disabled--mj:objectLog(sapien.uniqueID, "offsetting updated path in front of other sapien due to social plan")
                        local moveToDir = mat3GetRow(goalObject.rotation, 2)
                        local newMoveToPos = goalObject.pos + moveToDir * mj:mToP(6.0) --this number is very sensitive, < 4m is probably impossible for an elder to recruit an average sapien if they are walking
                        local clampToSeaLevel = true
                        moveToPos = worldHelper:getBelowSurfacePos(newMoveToPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                    end 
                end

                sharedState:set("orderQueue", 1, "pathInfo", "goalPosOrNil", moveToPos)
                sharedState:set("orderQueue", 1, "pathInfo", "initialObjectPos", goalObject.pos)
                --disabled--mj:objectLog(sapienID, "updating pathInfo in orderState:", moveToPos)
            end
        end



        local goalPosInfo = serverSapien:getGoalPosInfoForPathInfo(orderStatePathCreationInfo, sapien)
        
        --disabled--mj:objectLog(sapienID, "incompletePathInfo:", incompletePathInfo, " goalPosInfo:", goalPosInfo)

        if not incompletePathInfo.complete then
            if incompletePathInfo.nodes and incompletePathInfo.nodes[1] then
                local incompleteStartPos = incompletePathInfo.startPos or incompletePathInfo.nodes[1].pos
                if goalPosInfo.goalPos then
                    terrain:loadArea(normalize(goalPosInfo.goalPos))
                    local goalDistance2 = length2(goalPosInfo.goalPos - sapien.pos)
                    local prevGoalDistance2 = length2(goalPosInfo.goalPos - incompleteStartPos)
                    --disabled--mj:objectLog(sapienID, "goalDistance2:", goalDistance2, " prevGoalDistance2:", prevGoalDistance2)
                    if goalDistance2 > prevGoalDistance2 then
                        goalPosInfo.shouldCancel = true
                        --disabled--mj:objectLog(sapienID, "getting further away from goal, it is probably inaccessible goalDistance:", mj:pToM(math.sqrt(goalDistance2)), " prevGoalDistance:")
                        if orderState.objectID then
                            local object = serverGOM:getObjectWithID(orderState.objectID)
                            if object then
                                serverGOM:setInaccessible(object)
                            end
                        end
                    end
                end
            end
        end
        
        ----disabled--mj:objectLog(sapienID, "incompletePath goalPosInfo:", goalPosInfo)
        ----disabled--mj:objectLog(sapienID, "incompletePath goalPosInfo updated goalPos altitude difference:", mj:pToM(length(goalPosInfo.goalPos) - length(incompletePathInfo.goalPos)))

        if goalPosInfo.shouldCancel then
            local removeHeldObjectOrderContext = false
            serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
        else
            --disabled--mj:objectLog(sapienID, "requesting updated path")
            
            pathIDCounter = pathIDCounter + 1
            local pathID = pathIDCounter
            local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
            unsavedState.waitingForPathID = pathID
            
            local orderObjectID = orderState.objectID
            local orderTypeIndex = orderState.orderTypeIndex
            local sequenceTypeIndex = actionState.sequenceTypeIndex

            pathCreator:getPath(sapienID, orderObjectID, sapien.pos, goalPosInfo.goalPos or incompletePathInfo.goalPos, orderStatePathCreationInfo.proximityType, orderStatePathCreationInfo.proximityDistance, orderStatePathCreationInfo.options, function(createdPathInfo)
                pathUpdateReceived(sapienID, orderObjectID, orderTypeIndex, sequenceTypeIndex, pathID, createdPathInfo)
            end)
        end
    end
end


local function assignActionState(sapien, orderObject, orderState, actionStateToAssign)

    local sharedState = sapien.sharedState

    sharedState:set("activeOrder",  true)
    
    if sharedState.pathStuckLastAttemptTime then
        serverGOM:removeObjectFromSet(sapien, serverGOM.objectSets.pathingCollisionObservers)
        sharedState:remove("pathStuckLastAttemptTime")
        sharedState:remove("isStuck")
    end
    
    if orderObject then
        anchor:setSapienOrderObjectAnchor(sapien.uniqueID, orderObject.uniqueID)
    end

    --tutorial hooks
    if actionStateToAssign.sequenceTypeIndex then
        if actionSequence.types[actionStateToAssign.sequenceTypeIndex].countsAsPlayingMusicalInstrumentForTutorial then
            serverTutorialState:musicPlayActionSequenceStarted(sapien.sharedState.tribeID)
        end
    end

    ----disabled--mj:objectLog(sapienReloaded.uniqueID, "assignActionState:", actionStateToAssign)
    sharedState:set("actionState", actionStateToAssign)
    if not order.types[orderState.orderTypeIndex].canDoWhileSitting then
        
        if sharedState.actionModifiers and sharedState.actionModifiers[action.modifierTypes.sit.index] then
            serverSeat:removeAnyNodeAssignmentForSapien(sapien)
            sharedState:remove("actionModifiers", action.modifierTypes.sit.index)
        end
    end
    sharedState:remove("actionModifiers", action.modifierTypes.crouch.index)
    sharedState:remove("actionModifiers", action.modifierTypes.run.index)
end



local function pathReceived(sapienID, orderObjectID, orderTypeIndex, prevActionStateSequenceTypeIndex, pathID, createdPathInfo)
    local completionInfo = checkPathValidAndGetInfo(sapienID, orderObjectID, orderTypeIndex, prevActionStateSequenceTypeIndex, pathID, createdPathInfo)

    if completionInfo then
        local sapien = completionInfo.sapien
        local orderObject = completionInfo.orderObject
        local actionStateToAssign = completionInfo.actionStateToAssign
        local orderState = completionInfo.orderState

        if createdPathInfo.noMovementRequired then
            --disabled--mj:objectLog(sapien.uniqueID, "createdPathInfo.noMovementRequired")
            actionStateToAssign.path = nil
            assignActionState(sapien, orderObject, orderState, actionStateToAssign)
            local result = serverSapien:startNextAction(sapien)
            if result == serverSapien.startNextActionResult.done or result == serverSapien.startNextActionResult.cancel  then
                --disabled--mj:objectLog(sapien.uniqueID, "doCancel d")
                doCancel(sapien)
                return
            end
        else
            if createdPathInfo.valid then
                --mj:log("createdPathInfo:", createdPathInfo)
                --disabled--mj:objectLog(sapien.uniqueID, "createdPathInfo.valid")
                actionStateToAssign.path = createdPathInfo
                assignActionState(sapien, orderObject, orderState, actionStateToAssign)
                startCurrentAction(sapien)
            else
                if createdPathInfo.complete and (not createdPathInfo.inaccessible) then --inaccessible means the object isn't connected to the path network. The sapien is probably fine.
                    --mj:error("Sapien ", sapienID, " is stuck with no valid path.")
                    local clampToSeaLevel = true
                    local shiftedPos = worldHelper:getBelowSurfacePos(sapien.pos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                    if length(shiftedPos - sapien.pos) > mj:mToP(0.01) then
                        serverGOM:setPos(sapien.uniqueID, shiftedPos, false)
                        serverGOM:sendSnapObjectMatrix(sapien.uniqueID, true)
                        serverSapien:saveState(sapien)
                        --mj:log("shifted down")
                    else
                        if createdPathInfo.goalPos then
                            terrain:loadArea(normalize(createdPathInfo.goalPos)) --might help stop hunters getting stuck
                        end

                        if sapien.sharedState.pathStuckLastAttemptTime then
                            local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)
                            if heldObjectCount > 0 then
                                serverSapien:dropHeldInventoryImmediately(sapien) --might help stop hunters getting stuck
                            else
                                sapien.sharedState:set("isStuck", true)
                            end
                        end

                        serverSapienAI:resetAIState(sapien.uniqueID)
                        --aiState.recentPlanObjectID = nil
                        sapien.sharedState:remove("lookAtObjectID")

                        sapien.sharedState:set("pathStuckLastAttemptTime", serverWorld:getWorldTime())
                        serverGOM:addObjectToSet(sapien, serverGOM.objectSets.pathingCollisionObservers)
                        --mj:log("already at ground level")
                    end
                end
                --disabled--mj:objectLog(sapien.uniqueID, "doCancel f")
                doCancel(sapien) --todo maybe check for path.complete?
                return
            end
        end
    end
end

function serverSapien:startNextOrder(sapien)
    

    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:startNextOrder")
    local sapienState = sapien.sharedState
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)

    if not sapienState.activeOrder and not unsavedState.waitingForPathID then
        local orderQueue = sapienState.orderQueue
        if orderQueue then
            local orderState = orderQueue[1]

            if orderState then
                local requiresObjectLoaded = orderState.objectID ~= nil
                local orderObject = nil
                local orderObjectState = nil

                if requiresObjectLoaded then
                    orderObject = serverSapien:checkObjectLoadedAndLoadIfNot(sapien, orderState.objectID, orderState.pos, 3, function()
                        mj:warn("cancelling order due to inability to load order object:",orderState.objectID, " for sapien:", sapien.uniqueID, " order type:", order.types[orderState.orderTypeIndex].name)
                        local removeHeldObjectOrderContext = false
                        serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
                    end)
                    if orderObject then
                        orderObjectState = orderObject.sharedState
                        
                        local cancel = serverSapien:assignOrderObject(sapien, orderObject, orderState)
                        if cancel then
                            --disabled--mj:objectLog(sapien.uniqueID, "cancelling due to serverSapien:assignOrderObject returning cancel. Probably now assigned to closer sapien. orderState:", orderState)
                            local removeHeldObjectOrderContext = false
                            serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
                            return
                        end
                    end
                end
                --mj:log("startOrder:",  order.types[orderState.orderTypeIndex].name, " orderState.objectID:", orderState.objectID, " requiresObjectLoaded:", requiresObjectLoaded, " orderObjectState:", orderObjectState)

                if (not requiresObjectLoaded) or orderObjectState then
                    --disabled--mj:objectLog(sapien.uniqueID, "calling createActionStateForOrder")

                    local actionStateToAssign = serverSapien:createActionStateForOrder(sapien, orderObject, orderState)
                    if actionStateToAssign then

                        --disabled--mj:objectLog(sapien.uniqueID, "actionStateToAssign ok")
                        local orderObjectID = nil
                        if orderObject then
                            orderObjectID = orderObject.uniqueID
                        end
                        
                        local activeSequence = actionSequence.types[actionStateToAssign.sequenceTypeIndex]
                        local currentActionTypeIndex = activeSequence.actions[actionStateToAssign.progressIndex]
                        if action.types[currentActionTypeIndex].isMovementAction then
                            local pathInfo = orderState.pathInfo
                            if not pathInfo then
                                assignActionState(sapien, orderObject, orderState, actionStateToAssign)
                                local result = serverSapien:startNextAction(sapien)
                                if result == serverSapien.startNextActionResult.done or result == serverSapien.startNextActionResult.cancel then
                                    --disabled--mj:objectLog(sapien.uniqueID, "doCancel m")
                                    doCancel(sapien)
                                end
                            else
                                local sapienID = sapien.uniqueID
                                local goalPosInfo = serverSapien:getGoalPosInfoForPathInfo(pathInfo, sapien)
                                if goalPosInfo.shouldCancel then
                                    --disabled--mj:objectLog(sapien.uniqueID, "doCancel a pathInfo:", pathInfo)
                                    doCancel(sapien)
                                else
                                    local goalPos = goalPosInfo.goalPos
                                    --disabled--mj:objectLog(sapien.uniqueID, "goalPosInfo.goalPos:", goalPosInfo.goalPos)
                                    if goalPos then
                                        pathIDCounter = pathIDCounter + 1
                                        local pathID = pathIDCounter
                                        unsavedState.waitingForPathID = pathID
                                        requestedPathUpdatesBySapienID[sapienID] = nil
                                        --disabled--mj:objectLog(sapien.uniqueID, "pathCreator:getPath")
                                        local orderTypeIndex = orderState.orderTypeIndex
                                        local sequenceTypeIndex = actionStateToAssign.sequenceTypeIndex
                                        pathCreator:getPath(sapienID, orderObjectID, sapien.pos, goalPos, pathInfo.proximityType, pathInfo.proximityDistance, pathInfo.options, function(createdPathInfo)
                                            pathReceived(sapienID, orderObjectID, orderTypeIndex, sequenceTypeIndex, pathID, createdPathInfo)
                                        end)
                                    else
                                        --disabled--mj:objectLog(sapien.uniqueID, "no goalPos")
                                        assignActionState(sapien, orderObject, orderState, actionStateToAssign)
                                        local result = serverSapien:startNextAction(sapien)
                                        if result == serverSapien.startNextActionResult.done or result == serverSapien.startNextActionResult.cancel then
                                            --disabled--mj:objectLog(sapien.uniqueID, "doCancel h")
                                            doCancel(sapien)
                                        end
                                    end
                                end
                            end

                        else
                            assignActionState(sapien, orderObject, orderState, actionStateToAssign)
                            local result = startCurrentAction(sapien) --previously we didn't start the action here, and that caused the timer to never be reset, amongst other potential issues
                            if result == serverSapien.startNextActionResult.done or result == serverSapien.startNextActionResult.cancel then
                                --disabled--mj:objectLog(sapien.uniqueID, "doCancel j")
                                doCancel(sapien)
                            end
                        end

                        if not sapien.privateState.logisticsInfo then
                            if orderState.context and orderState.context.storageAreaTransferInfo then
                                local storageAreaTransferInfo = orderState.context.storageAreaTransferInfo
                                if not serverLogistics:setSapienRouteAssignment(sapien.uniqueID, storageAreaTransferInfo.routeTribeID or sapien.sharedState.tribeID, storageAreaTransferInfo.routeID) then
                                    --disabled--mj:objectLog(sapien.uniqueID, "doCancel k")
                                    doCancel(sapien)
                                else
                                    local sapienLogisticsInfo = {
                                        routeID = storageAreaTransferInfo.routeID,
                                        tribeID = storageAreaTransferInfo.routeTribeID or sapien.sharedState.tribeID,
                                    }
                                    --disabled--mj:objectLog(sapien.uniqueID, "add sapienLogisticsInfo:", sapienLogisticsInfo)
                                    sapien.privateState.logisticsInfo = sapienLogisticsInfo
                                end
                            end
                        end

                        -- todo maybe cancel and remove logisticsInfo here in certain cases?
                            
               --[[ orderContext = {
                    storageAreaTransferInfo = storageAreaTransferInfo,]]
                       -- end

                        --[[
local sapienLogisticsInfo = {
                            routeID = heldObjectStorageAreaTransferInfo.routeID,
                            lastDestinationObjectID = heldObjectStorageAreaTransferInfo.destinationObjectID,
                            lastDestinationIndex = heldObjectStorageAreaTransferInfo.destinationIndex
                        }
                        --disabled--mj:objectLog(sapien.uniqueID, "add sapienLogisticsInfo:", sapienLogisticsInfo)
                        sapien.privateState.logisticsInfo = sapienLogisticsInfo
                        if not serverLogistics:setSapienRouteAssignment(sapien.uniqueID, sapien.sharedState.tribeID, heldObjectStorageAreaTransferInfo.routeID) then
                            sapien.privateState.logisticsInfo = nil
                        end
                        ]]

                        

                       --[[ if orderState.context and orderState.context.storageAreaTransferInfo and orderState.context.storageAreaTransferInfo.routeID then
                            if not serverLogistics:setSapienRouteAssignment(sapien.uniqueID, sapien.sharedState.tribeID, orderState.context.storageAreaTransferInfo.routeID) then
                                --disabled--mj:objectLog(sapien.uniqueID, "doCancel k")
                                doCancel(sapien)
                            end
                        elseif not sapien.privateState.logisticsInfo then
                            serverLogistics:setSapienRouteAssignment(sapien.uniqueID, sapien.sharedState.tribeID, nil)
                        end]]

                    else
                        local removeHeldObjectOrderContext = false
                        serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
                    end
                end
            end
        end
    end
end

function serverSapien:dropHeldInventoryImmediately(sapien)
    while sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 do
        local objectInfo = serverSapienInventory:removeObject(sapien, sapienInventory.locations.held.index)
        if objectInfo then
            --disabled--mj:objectLog(sapien.uniqueID, "dropping held objects")
            local offsetPos = sapien.pos + mat3GetRow(sapien.rotation, 2) * mj:mToP(0.1)
            local dropPosNormal = normalize(offsetPos)
            local sapienPosLength = length(sapien.pos)
            local clampToSeaLevel = true
            local shiftedPos = worldHelper:getBelowSurfacePos(dropPosNormal * sapienPosLength, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
            local shiftedPosLength = length(shiftedPos)
            local finalDropPos = dropPosNormal * (shiftedPosLength + mj:mToP(1.0))

            serverGOM:dropObject(objectInfo, finalDropPos, sapien.sharedState.tribeID, true)
        else
            break
        end
    end
end

function serverSapien:removeSapien(sapien, notifyClient, dropInventory)
    local sapienID = sapien.uniqueID
    --mj:log("removing sapien:", sapienID)
    serverWorld:setSapienSleeping(sapien, false)
    local removeHeldObjectOrderContext = false
    serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
    removeInventory(sapien, dropInventory)

    if sapien.sharedState.manualAssignedPlanObject then
        local priorityObject = serverGOM:getObjectWithID(sapien.sharedState.manualAssignedPlanObject)
        if priorityObject then
            planManager:removeManualAssignmentsForPlanObjectForSapien(priorityObject,sapien)
        end
    end

    if sapien.sharedState.hasBaby then
        serverWorld:addToBabyCount(sapien.sharedState.tribeID, -1)
    end

    serverSeat:removeAnyNodeAssignmentForSapien(sapien)

    
    if sapien.sharedState.assignedBedID then
        local prevBed = serverGOM:getObjectWithID(sapien.sharedState.assignedBedID)
        if not prevBed then
            terrain:loadArea(sapien.sharedState.assignedBedPos)
            prevBed = serverGOM:getObjectWithID(sapien.sharedState.assignedBedID)
        end
        if prevBed then
            prevBed.sharedState:remove("assignedBedSapienID")
            prevBed.sharedState:remove("assignedBedSapienName")
        end

        sapien.sharedState:remove("assignedBedID")
        sapien.sharedState:remove("assignedBedPos")
    end

    anchor:removeSapienOrderObjectAnchor(sapienID)
    local tribeID = sapien.sharedState.tribeID
    serverGOM:removeGameObject(sapienID)
    serverTribe:recalculatePopulation(tribeID)
    serverGOM:sendFollowersListsForSapienCountChange(tribeID)
    serverWorld:updateFollowerCount(tribeID)
end

function serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
    local relationships = sapien.lazyPrivateState.relationships
    local potentiallyUpset = {}
    for otherSapienID, info in pairs(relationships) do
        local otherSapien = serverGOM:getObjectWithID(otherSapienID)
        if otherSapien then
            if info.familyRelationshipType then
                serverStatusEffects:setTimedEffect(otherSapien.sharedState, statusEffect.types.familyDiedShortTerm.index, 500.0)
            else 
                local bondLong = info.bond.long
                if bondLong > 0.9 then
                    serverStatusEffects:setTimedEffect(otherSapien.sharedState, statusEffect.types.familyDiedShortTerm.index, 500.0)
                elseif bondLong > 0.3 then --assumes some reciprocal bond as a bit of an optimization. Should be OK?
                    potentiallyUpset[otherSapienID] = true
                end
            end
        end
    end

    for upsetSapienID, v in pairs(potentiallyUpset) do
        local upsetSapien = serverGOM:getObjectWithID(upsetSapienID)
        local upsetRelationships = upsetSapien.lazyPrivateState.relationships
        local relationshipInfo = upsetRelationships[sapien.uniqueID]
        if relationshipInfo and relationshipInfo.bond.long > 0.5 then
            serverStatusEffects:setTimedEffect(upsetSapien.sharedState, statusEffect.types.acquaintanceDied.index, 2000.0)
        end
    end
end

local infrequentUpdateRandomWaits = {}
local infrequentUpdateTimers = {}
local infrequentUpdateLongerWaitCounters = {}

local longWaitCount = 30.0


local minNomadExitDistance2 = mj:mToP(50.0) * mj:mToP(50.0)

local function leaveTribe(sapien, banishedByTribeIDOrNil)
    local sharedState = sapien.sharedState
    local previousTribeID = sharedState.tribeID

    local leavingSapiensArray = {}
    local leavingSapienIDsArray = {}
    local leavingSapienIDsSet = {}
    
    local potentiallyUpsetThatOthersAreLeavingSet = {}

    local function addToLeavers(leavingSapien)
        if not leavingSapienIDsSet[leavingSapien.uniqueID] then
            leavingSapienIDsSet[leavingSapien.uniqueID] = true
            table.insert(leavingSapiensArray, leavingSapien)
            table.insert(leavingSapienIDsArray, leavingSapien.uniqueID)

            local relationships = sapien.lazyPrivateState.relationships
            for otherSapienID, info in pairs(relationships) do
                local otherSapien = serverGOM:getObjectWithID(otherSapienID)
                if otherSapien then
                    local otherSapienSharedState = otherSapien.sharedState
                    if otherSapienSharedState.tribeID == previousTribeID then
                        if info.familyRelationshipType then
                            if sharedState.lifeStageIndex >= sapienConstants.lifeStages.adult.index then
                                if info.familyRelationshipType == sapienConstants.familyRelationshipTypes.biologicalChild and otherSapienSharedState.lifeStageIndex < sapienConstants.lifeStages.adult.index then
                                    addToLeavers(otherSapien)
                                end
                            else
                                if info.familyRelationshipType == sapienConstants.familyRelationshipTypes.mother or info.familyRelationshipType == sapienConstants.familyRelationshipTypes.father then
                                    addToLeavers(otherSapien)
                                end
                            end
                        else 
                            local bondLong = info.bond.long
                            if bondLong > 0.9 then
                                addToLeavers(otherSapien)
                            elseif bondLong > 0.3 then --assumes some reciprocal bond as a bit of an optimization. Should be OK?
                                potentiallyUpsetThatOthersAreLeavingSet[otherSapienID] = true
                            end
                        end
                    end
                end
            end

            if leavingSapien.sharedState.nomad then
                serverGOM:callFunctionForAllSapiensInTribe(previousTribeID, function(otherSapien)
                    addToLeavers(otherSapien)
                end)
            end

        end
    end

    addToLeavers(sapien)

    for upsetSapienID, v in pairs(potentiallyUpsetThatOthersAreLeavingSet) do
        if not leavingSapienIDsSet[upsetSapienID] then
            local upsetSapien = serverGOM:getObjectWithID(upsetSapienID)
            if upsetSapien then
                local relationships = upsetSapien.lazyPrivateState.relationships
                for otherSapienID, v_ in pairs(leavingSapienIDsSet) do
                    local relationshipInfo = relationships[otherSapienID]
                    if relationshipInfo and relationshipInfo.bond.long > 0.5 then
                        serverStatusEffects:setTimedEffect(sharedState, statusEffect.types.acquaintanceLeft.index, 1000.0)
                        break
                    end
                end
            end
        end
    end

    
    for i,leavingSapien in ipairs(leavingSapiensArray) do
        serverStatistics:recordEvent(leavingSapien.sharedState.tribeID, statistics.types.leave.index)
    end
    
    
    local success = serverNomadTribe:createLeavingTribe(previousTribeID, leavingSapiensArray, banishedByTribeIDOrNil)

    if not success then
        mj:error("serverNomadTribe:createLeavingTribe failed")
        for i,leavingSapien in ipairs(leavingSapiensArray) do
            serverSapien:removeSapien(leavingSapien, false, false)
        end
    end

    --serverGOM:clientFollowersRemoved(previousTribeID, leavingSapienIDsArray)

    serverTribe:recalculatePopulation(previousTribeID)
    serverGOM:sendFollowersListsForSapienCountChange(previousTribeID)
    serverWorld:updateFollowerCount(previousTribeID)

    --mj:log("leavingSapiensArray:", leavingSapiensArray)

    if banishedByTribeIDOrNil and banishedByTribeIDOrNil ~= previousTribeID then
        local destinationState = serverDestination:getDestinationState(banishedByTribeIDOrNil)
        for i,leavingSapien in ipairs(leavingSapiensArray) do
            serverGOM:sendNotificationForObject(leavingSapien, notification.types.banished.index, {
                tribeName = destinationState and destinationState.name,
            }, previousTribeID)
        end
    else
        for i,leavingSapien in ipairs(leavingSapiensArray) do
            serverGOM:sendNotificationForObject(leavingSapien, notification.types.left.index, nil, previousTribeID)
        end
    end
end

local function checkLoyalty(sapien, dt)
    local sharedState = sapien.sharedState
    if not sharedState.nomad then
        local loyalty = mood:getMood(sapien, mood.types.loyalty.index)
        if loyalty == mood.levels.severeNegative then
            if not sharedState.leaveTimer then
                sharedState:set("leaveTimer", dt)
                --mj:log("wants to leave:", sapien.uniqueID)
                serverGOM:sendNotificationForObject(sapien, notification.types.lowLoyalty.index, nil, sapien.sharedState.tribeID)
            else
                local newLeaveTimer = sharedState.leaveTimer + dt
                if newLeaveTimer > 1440.0 then
                    leaveTribe(sapien, nil)
                else
                    sharedState:set("leaveTimer", newLeaveTimer)
                end
            end
        elseif sharedState.leaveTimer and loyalty >= mood.levels.moderateNegative then
            --mj:log("no longer wants to leave:", sapien.uniqueID)
            sharedState:remove("leaveTimer")
        end
    end
end

function serverSapien:updateLight(sapien)
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    if serverWorld:getHasDaylight(sapien.normalizedPos) then
        unsavedState.inDarkness = nil
    else
        if not serverGOM:getIsCloseToLightSource(sapien.pos) then
            unsavedState.inDarkness = true
        else
            unsavedState.inDarkness = nil
        end
    end
end

function serverSapien:doUpdateTemperature(sapien)
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    local closeObjectOffset = serverGOM:getCloseObjectTemperatureOffset(sapien.pos)

    local isWetOrStormy = (sapien.sharedState.statusEffects[statusEffect.types.wet.index] ~= nil) or serverWeather:getIsDamagingWindStormOccuring()
    
    local temperatureZoneIndex = weather:getTemperatureZoneIndex(unsavedState.temperatureZones, serverWorld:getWorldTime(), serverWorld:getTimeOfDayFraction(sapien.pos), serverWorld.yearSpeed, sapien.pos, sapien.sharedState.covered, isWetOrStormy, closeObjectOffset)

    
    local hasCloakOrWarmBed = false
    local inventories = sapien.sharedState.inventories
    if inventories then
        local torsoInventory = inventories[sapienInventory.locations.torso.index]
        if torsoInventory then
            for i, gameObjectTypeIndex in ipairs(gameObject.clothingTypesByInventoryLocations[sapienInventory.locations.torso.index]) do
                local cloakCount = torsoInventory.countsByObjectType[gameObjectTypeIndex] or 0
                if cloakCount > 0 then
                    hasCloakOrWarmBed = true
                end
            end
        end
    end

    if not hasCloakOrWarmBed then
        local sharedState = sapien.sharedState
        if sharedState.activeOrder then
            local orderState = sharedState.orderQueue[1]
            if orderState then
                local orderTypeIndex = orderState.orderTypeIndex
                if orderTypeIndex == order.types.sleep.index then
                    local actionState = sapien.sharedState.actionState
                    if actionState then
                        local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
                        if actionState.progressIndex >= activeSequence.assignedTriggerIndex then
                            if orderState.objectID then
                                local orderObject = serverGOM:getObjectWithID(orderState.objectID)
                                if orderObject then
                                    if gameObject.types[orderObject.objectTypeIndex].isWarmBed then
                                        --mj:log("warm bed found")
                                        hasCloakOrWarmBed = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if hasCloakOrWarmBed then
        if temperatureZoneIndex < weather.temperatureZones.moderate.index then
            temperatureZoneIndex = weather.temperatureZones.moderate.index
        elseif temperatureZoneIndex > weather.temperatureZones.moderate.index then
            temperatureZoneIndex = math.min(temperatureZoneIndex + 1, #weather.temperatureZones)
        end
    end

    sapien.sharedState:set("temperatureZoneIndex", temperatureZoneIndex)
    unsavedState.temperatureDirty = nil
end

function serverSapien:updateTemperature(sapien)
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    unsavedState.temperatureDirty = true
    if not sapien.sharedState.temperatureZoneIndex then
        serverSapien:doUpdateTemperature(sapien)
    end
end


local function updateTemperatureZones(sapien)
    local vertID = serverGOM:getCloseTerrainVertID(sapien.uniqueID)
    local biomeTags = terrain:getBiomeTagsForVertWithID(vertID)
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    unsavedState.temperatureZones = weather:getTemperatureZones(biomeTags)
    serverSapien:updateTemperature(sapien)
end

local function longWaitInfrequentUpdate(sapien, dt)
    local sharedState = sapien.sharedState

    updateTemperatureZones(sapien)

    serverSapien:updateLight(sapien)

    if statusEffect:hasEffect(sharedState, statusEffect.types.majorVirus.index) or
    statusEffect:hasEffect(sharedState, statusEffect.types.criticalVirus.index) then
        if rng:randomBool() then
            local closeSapiens = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.sapiens, sapien.pos, mj:mToP(5.0))
            if closeSapiens then
                for i,info in ipairs(closeSapiens) do
                    if i == 1 or rng:randomBool() then
                        local otherSapien = serverGOM:getObjectWithID(info.objectID)
                        if otherSapien then
                            serverSapien:spreadVirus(sapien, otherSapien)
                        end
                    end
                end
            end
        end
    end

    if sharedState.nomad then
        local destinationState = serverTribe:getTribeState(sharedState.tribeID)
        local worldTime = serverWorld:getWorldTime()
        local goalTime = destinationState.nomadState.goalTime
        if worldTime > goalTime or sharedState.fleeing then
            local exitDistance2 = length2(sapien.normalizedPos - normalize(destinationState.nomadState.exitPos))
            if exitDistance2 < minNomadExitDistance2 then
                serverSapien:removeSapien(sapien, false, false)
                return
            else
                if worldTime > goalTime + 1000.0 then
                    serverSapien:removeSapien(sapien, false, false)
                    return
                end
            end
        end
    else
        checkLoyalty(sapien, dt)
    end

    if sharedState.pregnant then
        sharedState:set("pregnancyOrBabyTimer", sharedState.pregnancyOrBabyTimer + dt * serverSapien.pregnancySpeed)
        if sharedState.pregnancyOrBabyTimer > 1.0 and (not serverSapien:isSleeping(sapien)) then
            local tribeID = sapien.sharedState.tribeID
            --mj:log("hasBaby:", sapien.uniqueID)
            sharedState:remove("pregnant")
            sharedState:set("hasBaby", true)
            serverWorld:addToBabyCount(tribeID, 1)
            serverStatistics:recordEvent(tribeID, statistics.types.birth.index)
            sharedState:set("babyIsFemale", rng:randomBool())
            sharedState:set("pregnancyOrBabyTimer", 0.0)
            serverTribe:recalculatePopulation(tribeID)
            serverGOM:sendNotificationForObject(sapien, notification.types.babyBorn.index, {
                babyIsFemale = sharedState.babyIsFemale,
            }, tribeID)
            serverStatusEffects:setTimedEffect(sharedState, statusEffect.types.hadChild.index, 1000.0)
            if sharedState.pregnancyFatherInfo and sharedState.pregnancyFatherInfo.fatherID then
                local father = serverGOM:getObjectWithID(sharedState.pregnancyFatherInfo.fatherID)
                if father then
                    serverStatusEffects:setTimedEffect(father.sharedState, statusEffect.types.hadChild.index, 1000.0)
                end
            end
            serverWorld:skillPrioritiesOrLimitedAbilityChanged(sapien.sharedState.tribeID)
        end
    elseif sharedState.hasBaby then
        sharedState:set("pregnancyOrBabyTimer", sharedState.pregnancyOrBabyTimer + dt * serverSapien.infantAgeSpeed)
        if sharedState.pregnancyOrBabyTimer > 1.0 and (not serverSapien:isSleeping(sapien)) then
            --mj:log("babyGrew:", sapien.uniqueID)
            sharedState:remove("hasBaby")
            sharedState:remove("pregnancyOrBabyTimer")
            serverWorld:addToBabyCount(sapien.sharedState.tribeID, -1)
            local childSapienID = serverSapien:createChildFromMother(sapien)
            if childSapienID then
                local childSapien = serverGOM:getObjectWithID(childSapienID)
                serverGOM:sendNotificationForObject(sapien, notification.types.babyGrew.index, {
                    childName = childSapien.sharedState.name
                }, sapien.sharedState.tribeID)
            end

            sharedState:remove("pregnancyFatherInfo")
            sharedState:remove("babyIsFemale")
            planManager:updateProximityForAbilityChange(sapien.uniqueID)
            serverWorld:skillPrioritiesOrLimitedAbilityChanged(sapien.sharedState.tribeID)
        end
    else
        local function checkCanGetPregnant()
            
            --mj:log("checkCanGetPregnant:", sapien.uniqueID)
            
            if not sharedState.isFemale then
                return nil
            end

            if sharedState.pathStuckLastAttemptTime then
                return nil
            end

            if sharedState.nomad then
                return nil
            end
            
            if sharedState.lifeStageIndex ~= sapienConstants.lifeStages.adult.index then
                return nil
            end
            
            if sharedState.ageFraction > sapienConstants.maxPregnancyLifeStageFraction then
                return nil
            end

            if not serverTribe:tribeAllowsPopulationGrowth(sharedState.tribeID) then
                return nil
            end

            local loyalty = mood:getMood(sapien, mood.types.loyalty.index)

            if loyalty < mood.levels.mildNegative then 
                return nil
            end

            local foodDesire = desire:getDesire(sapien, need.types.food.index, false)
            if foodDesire >= desire.levels.strong then
                return nil
            end
            
            local currentTribePopulation = math.max((serverTribe:getPopulation(sharedState.tribeID) or 0), 0)

            local populationCap = serverWorldSettings:get("populationCap")
            if not populationCap then
                populationCap = gameConstants.populationLimitPerTribeSoftCap
            end
            if currentTribePopulation >= populationCap then
                return nil
            end

            local foodCount = serverStorageArea.foodCountsByTribeID[sharedState.tribeID]
            --mj:log("foodCount:", foodCount)
            if (not foodCount) or foodCount < 5 then
                return nil
            end

            local foodCountFraction = clamp(foodCount / (currentTribePopulation + 1), 0.0, 1.0)
            --mj:log("foodCountFraction:", foodCountFraction)
            
            if not sharedState.pregnancyOrBabyTimer then
                sharedState:set("pregnancyOrBabyTimer", 0.0)
            end

            local tribeSoftCapStart = math.max(gameConstants.populationLimitPerTribeSoftCap * 0.8, 10)
            local tribeSoftCapEnd = math.max(gameConstants.populationLimitPerTribeSoftCap * 1.2, tribeSoftCapStart + 1)

            local supressFraction = mjm.reverseLinearInterpolate(currentTribePopulation, tribeSoftCapStart, tribeSoftCapEnd)
            supressFraction = clamp(supressFraction, 0.0, 1.0)
            --mj:log("pregnancy check tribeFraction:", supressFraction)

            if currentTribePopulation > 10 then
                local globalSoftCapStart = math.max(gameConstants.populationLimitGlobalSoftCap * 0.8, 10)
                local globalSoftCapEnd = math.max(gameConstants.populationLimitGlobalSoftCap * 1.2, globalSoftCapStart + 1)

                local currentGlobalPopulation = math.max((serverWorld:getPlayerSapienCount() or 0), 0)
                local globalFraction = mjm.reverseLinearInterpolate(currentGlobalPopulation, globalSoftCapStart, globalSoftCapEnd)
                globalFraction = clamp(globalFraction, 0.0, 1.0)

                supressFraction = math.max(supressFraction, globalFraction)
                --mj:log("pregnancy check tribeFraction:", globalFraction)
            end

            local populationMultiplier = 1.0 - math.min(supressFraction, 1.0)
            --mj:log("pregnancy check populationMultiplier:", populationMultiplier)

            sharedState:set("pregnancyOrBabyTimer", sharedState.pregnancyOrBabyTimer + dt * serverSapien.pregnancyDelaySpeed * foodCountFraction * populationMultiplier)

            if sharedState.pregnancyOrBabyTimer < 1.0 then
                return nil
            end

            local bestFitScore = 0.1
            local bestFitFather = nil
            
            --mj:log("preg test 1:", sapien.uniqueID)

            local worldTime = serverWorld:getWorldTime()
            local relationships = sapien.lazyPrivateState.relationships
            for otherSapienID, info in pairs(relationships) do
                --mj:log("worldTime - info.seen:", worldTime - info.seen)
                --mj:log("info.familyRelationshipType:", info.familyRelationshipType)
                if (not info.familyRelationshipType) and info.seen and (worldTime - info.seen < 300.0) then
                    --mj:log("preg test 2:", sapien.uniqueID)
                    local score = info.bond.short + info.mood.short
                    if score > bestFitScore then
                        local otherSapien = serverGOM:getObjectWithID(otherSapienID)
                        if otherSapien then
                            --mj:log("preg test 3:", sapien.uniqueID)
                            local otherSapienSharedState = otherSapien.sharedState
                            if (not otherSapienSharedState.isFemale) and otherSapienSharedState.lifeStageIndex >= sapienConstants.lifeStages.adult.index then
                                --mj:log("preg test 4:", sapien.uniqueID)
                                bestFitScore = score
                                bestFitFather = otherSapien
                            end
                        end
                    end
                end
            end

            if not bestFitFather then
                sharedState:set("pregnancyOrBabyTimer", rng:randomValue())
            end

            return bestFitFather

        end

        local bestFitFather = checkCanGetPregnant()

        if bestFitFather then
            sharedState:set("pregnant", true)
            sharedState:set("pregnancyOrBabyTimer", 0.0)
            sharedState:set("pregnancyFatherInfo", {
                skinColorFraction = bestFitFather.sharedState.skinColorFraction,
                hairColorGene = bestFitFather.sharedState.hairColorGene,
                eyeColorGene = bestFitFather.sharedState.eyeColorGene,
                fatherID = bestFitFather.uniqueID
            })
            --mj:log("becamePregnant:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.becamePregnant.index, nil, sapien.sharedState.tribeID)

            serverWorld:skillPrioritiesOrLimitedAbilityChanged(sapien.sharedState.tribeID)
            planManager:updateProximityForAbilityChange(sapien.uniqueID)
        end
    end

    local ageRate = serverSapien.ageSpeedsByLifeStage[sharedState.lifeStageIndex]-- * 4.0
    sharedState:set("ageFraction", sharedState.ageFraction + dt * ageRate)
    if sharedState.ageFraction > 1.0 then
        --mj:log("aged up:", sapien.uniqueID)
        if sharedState.lifeStageIndex >= sapienConstants.lifeStages.elder.index then
            --mj:log("died of old age:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
                deathReasonKey = "deathReason_oldAge"
            }, sapien.sharedState.tribeID)
            
            serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
            serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
            serverSapien:removeSapien(sapien, true, true)
            return
        end
        
        sharedState:set("lifeStageIndex", sharedState.lifeStageIndex + 1)
        local clientID = serverWorld:clientIDForTribeID(sapien.sharedState.tribeID)
        if clientID then
            serverWorld:updatePopulationStatistics(clientID, sapien.sharedState.tribeID)
        end
        serverWorld:skillPrioritiesOrLimitedAbilityChanged(sapien.sharedState.tribeID)
        sharedState:set("ageFraction", 0.0)

        serverGOM:sendNotificationForObject(sapien, notification.types.agedUp.index, {
            lifeStageIndex = sharedState.lifeStageIndex,
        }, sapien.sharedState.tribeID)
        planManager:updateProximityForAbilityChange(sapien.uniqueID)
    end

end




local makeWetPosLength = 1.0 - mj:mToP(0.05)
local makeWetPosLength2 = makeWetPosLength * makeWetPosLength

local function infrequentUpdate(sapien, dt)
    
    local isOwnedByOfflinePlayer = not serverSapien:getOwnerPlayerIsOnline(sapien)

    serverSapienAI:infrequentUpdate(sapien, dt, isOwnedByOfflinePlayer) 
    serverSapien:updateRelationshipScores(sapien, dt)

    local privateState = sapien.privateState
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    local sharedState = sapien.sharedState
    
    desire:updateCachedDesires(sapien, unsavedState, serverWorld:getTimeOfDayFraction(sapien.pos))
    --addAutomaticNearbyFoodGatherPlanIfNeeded(sapien, privateState, dt)

    if unsavedState.inDarkness and (not serverSapien:isSleeping(sapien)) then
        serverStatusEffects:addEffect(sharedState, statusEffect.types.inDarkness.index)
    else
        serverStatusEffects:removeEffect(sharedState, statusEffect.types.inDarkness.index)
    end

    if sharedState.initialSleepDelay then
        local newSleepDelay = sharedState.initialSleepDelay - dt
        if newSleepDelay > 0.0 then
            sharedState:set("initialSleepDelay", newSleepDelay)
        else
            sharedState:remove("initialSleepDelay")
        end
    end


    --disabled--mj:objectLog(sapien.uniqueID, "pos altitude:", mj:pToM(length(sapien.pos) - 1.0), " makeWet:", mj:pToM(makeWetPosLength - 1.0))

    local function getGettingWetFraction()
        if (not sapien.sharedState.seatObjectID) and length2(sapien.pos) < makeWetPosLength2 then
            return 10.0
        end

        if not sharedState.covered then
            local rainfallValues = terrain:getRainfallForNormalizedPoint(sapien.normalizedPos)
            local currentRainfall = weather:getRainfall(rainfallValues, sapien.normalizedPos, serverWorld:getWorldTime(), serverWorld.yearSpeed)
            local rainSnow = weather:getRainSnowCombinedPrecipitation(currentRainfall)
            if rainSnow > 0.3 then
                local snowFraction = weather:getSnowFraction(sapien.normalizedPos, serverWorld:getWorldTime(), serverWorld.yearSpeed, serverWorld:getTimeOfDayFraction(sapien.normalizedPos))
                if snowFraction < 0.5 then
                    return rainSnow
                end
            end
        end
        return -1
    end

    local gettingWetFraction = getGettingWetFraction()

    if gettingWetFraction > 0.0 then
        privateState.gettingWetTimer = (privateState.gettingWetTimer or 0.0) + dt * gettingWetFraction
        if privateState.gettingWetTimer >= sapienConstants.wetDuration then
            privateState.dryingTimer = 0.0
            if not statusEffect:hasEffect(sharedState, statusEffect.types.wet.index) then
                serverStatusEffects:addEffect(sharedState, statusEffect.types.wet.index)
                serverSapien:updateTemperature(sapien)
            end
        end
    else
        privateState.gettingWetTimer = nil
        
        if privateState.dryingTimer then
            local temperatureZoneIndex = sharedState.temperatureZoneIndex or weather.temperatureZones.moderate.index

            local dryMultipleiersByTemperatureZoneIndex = {
                [weather.temperatureZones.veryCold.index] = 0.125,
                [weather.temperatureZones.cold.index] = 0.25,
                [weather.temperatureZones.moderate.index] = 1.0,
                [weather.temperatureZones.hot.index] = 4.0,
                [weather.temperatureZones.veryHot.index] = 8.0,
            }
            local dryMultipler = dryMultipleiersByTemperatureZoneIndex[temperatureZoneIndex]

            privateState.dryingTimer = privateState.dryingTimer + dt * dryMultipler
            if privateState.dryingTimer >= sapienConstants.dryDuration then
                privateState.dryingTimer = nil
                serverStatusEffects:removeEffect(sharedState, statusEffect.types.wet.index)
                serverSapien:updateTemperature(sapien)
            end
        end
    end

    if unsavedState.temperatureDirty then
        serverSapien:doUpdateTemperature(sapien)
    end
    
    local currentTemperatureZoneIndex = sharedState.temperatureZoneIndex or weather.temperatureZones.moderate.index

    local statusEffectsByTemperatureZoneIndex = {
        [weather.temperatureZones.veryCold.index] = statusEffect.types.veryCold.index,
        [weather.temperatureZones.cold.index] = statusEffect.types.cold.index,
        [weather.temperatureZones.hot.index] = statusEffect.types.hot.index,
        [weather.temperatureZones.veryHot.index] = statusEffect.types.veryHot.index,
    }


    local currentStatusEffects = sharedState.statusEffects
    local currentStatusTemperatureZoneIndex = weather.temperatureZones.moderate.index
    local currentStatusEffectTypeIndex = nil

    for temperatureZoneIndex, statusEffectTypeIndex in pairs(statusEffectsByTemperatureZoneIndex) do
        if currentStatusEffects[statusEffectTypeIndex] then
            currentStatusTemperatureZoneIndex = temperatureZoneIndex
            currentStatusEffectTypeIndex = statusEffectTypeIndex
            break
        end
    end

    if currentStatusTemperatureZoneIndex ~= currentTemperatureZoneIndex then
        if currentStatusTemperatureZoneIndex < currentTemperatureZoneIndex then
            sapien.privateState.coolingTimer = nil
            local warmingTimer = (sapien.privateState.warmingTimer or 0.0) + dt
            if warmingTimer > 60.0 then
                sapien.privateState.warmingTimer = nil
                if currentStatusEffectTypeIndex then
                    if statusEffect:hasEffect(sharedState, statusEffect.types.hypothermia.index) then
                        serverStatusEffects:removeEffect(sharedState, statusEffect.types.hypothermia.index)
                        serverGOM:sendNotificationForObject(sapien, notification.types.hypothermiaRemoved.index, nil, sapien.sharedState.tribeID)
                    end
                    serverStatusEffects:removeEffect(sharedState, currentStatusEffectTypeIndex)
                end
                local newStatusTemperatureZoneIndex = currentStatusTemperatureZoneIndex + 1
                if statusEffectsByTemperatureZoneIndex[newStatusTemperatureZoneIndex] then
                    serverStatusEffects:addEffect(sharedState, statusEffectsByTemperatureZoneIndex[newStatusTemperatureZoneIndex])
                end
            else
                sapien.privateState.warmingTimer = warmingTimer
            end
        else
            sapien.privateState.warmingTimer = nil
            local coolingTimer = (sapien.privateState.coolingTimer or 0.0) + dt
            if coolingTimer > 60.0 then
                sapien.privateState.coolingTimer = nil
                if currentStatusEffectTypeIndex then
                    serverStatusEffects:removeEffect(sharedState, currentStatusEffectTypeIndex)
                end
                local newStatusTemperatureZoneIndex = currentStatusTemperatureZoneIndex - 1
                local statusEffectToAdd = statusEffectsByTemperatureZoneIndex[newStatusTemperatureZoneIndex]
                if statusEffectToAdd then
                    if statusEffectToAdd == statusEffect.types.veryCold.index then
                        serverStatusEffects:setTimedEffect(sharedState, statusEffectToAdd, sapienConstants.timeToDevelopHypothermiaWhenVeryCold)
                    else
                        serverStatusEffects:addEffect(sharedState, statusEffectToAdd)
                    end
                end
            else
                sapien.privateState.coolingTimer = coolingTimer
            end
        end
    end



    --serverSapienSkills:update(sapien, dt)
end



function serverSapien:completeOrder(sapien)
    
    local sharedState = sapien.sharedState
    local orderState = sharedState.orderQueue[1]

    
    if orderState then
        --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:completeOrder. orderState.objectID:", orderState.objectID, " traceback:", debug.traceback())
        --[[mj:callFunctionIfDebugObject(sapien.uniqueID, function()
            mj:error("completion trace")
        end)]]

        local removePlanObjectState = true
        serverSapien:removeAssignedStatusFromObjectIfBelongingToSapien(orderState.objectID, sapien, orderState, removePlanObjectState)
        serverSapien:clearAllAssignedObjectIDs(sapien)

        
        if orderState.objectID then
            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            if orderObject then
                local unsavedState = serverGOM:getUnsavedPrivateState(orderObject)
                unsavedState.requiredObjectInfoResourceInfo = nil
        
                --[[--disabled--mj:objectLog(sapien.uniqueID, "orderState.orderTypeIndex == order.types.moveToLogistics:", orderState.orderTypeIndex == order.types.moveToLogistics.index, " sapien.privateState.logisticsInfo:", sapien.privateState.logisticsInfo)
                if orderState.orderTypeIndex == order.types.moveToLogistics.index and sapien.privateState.logisticsInfo then
                    local logisticsInfo = sapien.privateState.logisticsInfo
                end]]
            end
        end

        if orderState.orderTypeIndex == order.types.sleep.index then
            serverWorld:setSapienSleeping(sapien, false)
        elseif orderState.orderTypeIndex == order.types.playInstrument.index then
            serverGOM:removeObjectFromSet(sapien, serverGOM.objectSets.musicPlayers)
        end

        --[[if orderState.orderTypeIndex == order.types.moveTo.index then --this isn't really necessary, but when you are moving sapiens around, a short wait might be useful? --commented out as it is triggered by internal move orders eg. nomads moving towards targets
            local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
            unsavedState.preventUnnecessaryAutomaticOrderTimer = math.max(unsavedState.preventUnnecessaryAutomaticOrderTimer or 0.0, 2.0)
        end]]
    end


    sharedState:remove("actionState")
    sharedState:remove("activeOrder")

    if sharedState.orderQueue[1] then
        local orderQueueClone = mj:cloneTable(sharedState.orderQueue)
        table.remove(orderQueueClone, 1)
        sharedState:set("orderQueue", orderQueueClone)
    end


    multitask:orderEnded(sapien)
    
    if orderState and orderState.context then
        if orderState.context.planObjectID then
            if desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos)) < desire.levels.strong and desire:getDesire(sapien, need.types.food.index, false) < desire.levels.strong and (not sharedState.resting) then
                local planObject = serverGOM:getObjectWithID(orderState.context.planObjectID)
                if planObject then
                    serverSapienAI:focusOnPlanObjectAfterCompletingOrder(sapien, planObject)
                end
            end
        end

        if orderState.context.planTypeIndex == plan.types.moveAndWait.index then
            sapien.sharedState:set("waitOrderSet", true)
        end

        
        if orderState.context.moveToObjectID then
            local moveToObject = serverGOM:getObjectWithID(orderState.context.moveToObjectID)
            if moveToObject and sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) == 0 then
                local orderAdded = false
                if gameObject.types[moveToObject.objectTypeIndex].isBed then
                    local wakeDesire = desire:getWake(sapien, serverWorld:getTimeOfDayFraction(sapien.pos))
                    if wakeDesire < desire.levels.moderate then
                        local aiState = serverSapienAI.aiStates[sapien.uniqueID]
                        if serverSapienAI:addOrderIfAble(sapien, order.types.sleep.index, orderState.context.moveToObjectID, nil, pathFinding.proximityTypes.reachable, gameConstants.standardPathProximityDistance) then
                            aiState.currentLookAtObjectInfo = nil
                            orderAdded = true
                        end
                    end
                end
                if not orderAdded then
                    --mj:log("hi")
                    if gameObject.types[moveToObject.objectTypeIndex].seatTypeIndex then
                        local seatNodeIndex = serverSeat:getAvailableNodeIndex(sapien, moveToObject, true)
                        --mj:log("seatNodeIndex:", seatNodeIndex)
                        if seatNodeIndex then
                            local orderContext = {
                                seatNodeIndex = seatNodeIndex,
                            }

                            local aiState = serverSapienAI.aiStates[sapien.uniqueID]
                            --mj:log("b")
                            if serverSapienAI:addOrderIfAble(sapien, order.types.sit.index, orderState.context.moveToObjectID, orderContext, pathFinding.proximityTypes.reachable, gameConstants.standardPathProximityDistance) then
                                --mj:log("c")
                                aiState.currentLookAtObjectInfo = nil
                                orderAdded = true
                            end
                        end
                    end
                end
            end
        end
    end

end

function serverSapien:checkPlans(sapien, dt, speedMultiplier)
    
    local orderState = nil
    local orderQueue = sapien.sharedState.orderQueue
    if orderQueue then
        orderState = orderQueue[1]
    end

    if not orderState then
        return {
            result = findOrderAI:checkPlans(sapien, dt),
            didCheck = true,
        }
    else
        local actionState = sapien.sharedState.actionState
        ----disabled--mj:objectLog(sapien.uniqueID, "serverSapien:checkPlans with orderState:", orderState, " actionState:", actionState)
        if actionState then
            local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
            if actionState.progressIndex > #activeSequence.actions then
                local checkResult = serverSapienAI:checkAutoExtendCurrentOrder(sapien)
                if checkResult then
                    if checkResult.canExtend then
                        local orderObject = nil
                        if orderState.objectID then
                            orderObject = serverGOM:getObjectWithID(orderState.objectID)
                        end

                        if checkResult.replaceOrder then
                            serverSapien:completeOrder(sapien)

                            local aiState = serverSapienAI.aiStates[sapien.uniqueID]
                            aiState.currentLookAtObjectInfo = {
                                lookAtIntent = lookAtIntents.types.work.index,
                                uniqueID = orderObject.uniqueID,
                                object = orderObject,
                                pos = orderObject.pos,
                                planTypeIndex = orderState.context.planTypeIndex,
                                assignObjectID = orderObject.uniqueID,
                                assignObjectDistance = length(orderObject.pos - sapien.pos),
                            }
            
                            --mj:log("replaceOrder in serverSapien:checkPlans")
                            startOrderAI:actOnLookAtObject(sapien) --WATCH out for this, a bit dangerous if stuff is added below
                        elseif checkResult.shouldActOnLookAtObject then
                            serverSapien:completeOrder(sapien)
                            
                            local aiState = serverSapienAI.aiStates[sapien.uniqueID]
                            aiState.currentLookAtObjectInfo = {
                                lookAtIntent = lookAtIntents.types.work.index,
                                uniqueID = checkResult.shouldActOnLookAtObject.uniqueID,
                                object = checkResult.shouldActOnLookAtObject,
                                pos = checkResult.shouldActOnLookAtObject.pos,
                                planTypeIndex = orderState.context.planTypeIndex,
                                assignObjectID = checkResult.shouldActOnLookAtObject.uniqueID,
                                assignObjectDistance = length(checkResult.shouldActOnLookAtObject.pos - sapien.pos),
                            }
                            startOrderAI:actOnLookAtObject(sapien) --WATCH out for this, a bit dangerous if stuff is added below
                        else
                            local newActionSequence = serverSapien:createActionStateForOrder(sapien, orderObject, orderState)

                            if newActionSequence and actionState.sequenceTypeIndex == newActionSequence.sequenceTypeIndex then
                                sapien.sharedState:set("actionState", "progressIndex", #activeSequence.actions)
                                sapien.privateState.actionStateTimer = 0.0
                                --disabled--mj:objectLog(sapien.uniqueID, "order auto extended.")
                            end
                        end
                    else
                        return {
                            result = checkResult.bestResult,
                            didCheck = true,
                        }
                    end
                else
                    serverSapien:completeOrder(sapien)
                    return {
                        result = findOrderAI:checkPlans(sapien, dt),
                        didCheck = true,
                    }
                end
                return {
                    didCheck = true,
                }
            else
                if orderState.orderTypeIndex == order.types.sit.index then
                    local checkResult = serverSapienAI:checkAutoExtendCurrentOrder(sapien)
                    if checkResult then
                        if not checkResult.canExtend then
                            return {
                                result = checkResult.bestResult,
                                didCheck = true,
                            }
                        end
                    end
                    return {
                        didCheck = true,
                    }
                end
            end
        end
    end

    return nil
end

function serverSapien:update(sapien, dt, speedMultiplier, bestPlanInfo)
    local orderQueue = sapien.sharedState.orderQueue

    if bestPlanInfo and bestPlanInfo.heuristic > lookAI.minHeuristic then
        if orderQueue and orderQueue[1] then
            local orderState = orderQueue[1]
            if order.types[orderState.orderTypeIndex].allowCancellationDueToNewIncomingLookedAtOrder then
                serverSapien:completeOrder(sapien)
            else
                bestPlanInfo = nil
            end
        end
    end


    if (not (orderQueue and orderQueue[1])) then
        local aiState = serverSapienAI.aiStates[sapien.uniqueID]
        if aiState.currentLookAtObjectInfo then
            --disabled--mj:objectLog(sapien.uniqueID, "calling startOrderAI:actOnLookAtObject in serverSapien:update")
            if startOrderAI:actOnLookAtObject(sapien) then
                serverSapien:startNextOrder(sapien) --added 11/25, a little scary
            end
            aiState.currentLookAtObjectInfo = nil
        end
    end
    
    serverSapien:frequentUpdate(sapien, dt, speedMultiplier, bestPlanInfo) --32% CPU
    
    local sapienID = sapien.uniqueID
    infrequentUpdateTimers[sapienID] = infrequentUpdateTimers[sapienID] + dt * speedMultiplier
    if infrequentUpdateTimers[sapienID] > infrequentUpdateRandomWaits[sapienID] then
        infrequentUpdate(sapien, infrequentUpdateTimers[sapienID]) --watch out, this may remove the sapien --22% CPU
        if serverGOM:getObjectWithID(sapienID) then
            infrequentUpdateLongerWaitCounters[sapienID] = infrequentUpdateLongerWaitCounters[sapienID] + infrequentUpdateTimers[sapienID]
            infrequentUpdateTimers[sapienID] = 0.0
            infrequentUpdateRandomWaits[sapienID] = 0.3 + rng:randomValue() * 0.5

            if infrequentUpdateLongerWaitCounters[sapienID] > longWaitCount then
                longWaitInfrequentUpdate(sapien,infrequentUpdateLongerWaitCounters[sapienID] )
                infrequentUpdateLongerWaitCounters[sapienID] = 0.0
            end
        end
    end

    
end

function serverSapien:frequentUpdate(sapien, dt, speedMultiplier, bestPlanInfo)
    serverSapienAI:frequentUpdate(sapien, dt, speedMultiplier, bestPlanInfo) --29%
    if speedMultiplier > 0.001 then
        serverSapien:startNextOrder(sapien) --2%
    end
end

function serverSapien:updateAnchor(sapien)
    anchor:addAnchor(sapien.uniqueID, anchor.types.sapien.index, sapien.sharedState.tribeID)
    serverGOM:setAlwaysSendToOwnerClientForObjectWithID(sapien.uniqueID, true)
end

function serverSapien:initSpawnedSapien(sapien, tribeID)
    sapien.sharedState:set("tribeID", tribeID)
    serverSapien:updateAnchor(sapien)
    serverSapien:saveState(sapien)
end

function serverSapien:isIdle(sapien)
    return (not sapien.sharedState.activeOrder)
end

function serverSapien:isSleeping(sapien)
    local sharedState = sapien.sharedState
    --mj:log("sharedState:", sharedState)
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderTypeIndex = sharedState.orderQueue[1].orderTypeIndex
        if orderTypeIndex == order.types.sleep.index then
            local actionState = sapien.sharedState.actionState
            if actionState then
                local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
                if actionState.progressIndex >= activeSequence.assignedTriggerIndex then
                    return true
                end
            end
        end
    end
    return false
end

function serverSapien:isRetrievingFood(sapien)
    local sharedState = sapien.sharedState
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderState = sharedState.orderQueue[1]
        local orderTypeIndex = orderState.orderTypeIndex
        if orderTypeIndex == order.types.gather.index or orderTypeIndex == order.types.pickupObject.index then
            local objectTypeIndex = orderState.context.objectTypeIndex
            if objectTypeIndex then
                local gameObjectType = gameObject.types[objectTypeIndex]
                if resource.types[gameObjectType.resourceTypeIndex].foodValue then
                    local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(sapien.sharedState.tribeID)
                    if resourceBlockLists then
                        local eatFoodBlockList = resourceBlockLists.eatFoodList
                        if eatFoodBlockList and eatFoodBlockList[objectTypeIndex] then
                            return false
                        end
                    end
                    
                    return true
                end
            end
        end
    end
    return false
end

function serverSapien:isFightingThisObjectOrCloser(sapien, otherObject)
    local sharedState = sapien.sharedState
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderState = sharedState.orderQueue[1]
        local orderContext = orderState.context
        if orderContext and orderContext.planTypeIndex and orderContext.planObjectID then
            local isAttackPlan = plan.types[orderContext.planTypeIndex].isAttackPlan or (orderContext.researchTypeIndex and research.types[orderContext.researchTypeIndex].isAttackPlan)
            if isAttackPlan then
                if orderContext.planObjectID == otherObject.uniqueID then
                    return true
                end

                local planObject = serverGOM:getObjectWithID(orderContext.planObjectID)
                if planObject and length2(planObject.pos - sapien.pos) < length2(otherObject.pos - sapien.pos) then
                    return true
                end
            end
        end
    end
    return false
end

function serverSapien:runOrJogMofifierTypeDueToPlan(sapien)
    local sharedState = sapien.sharedState
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderState = sharedState.orderQueue[1]
        
        if order.types[orderState.orderTypeIndex].shouldRunWherePossible then
            return action.modifierTypes.run.index
        end

        local orderContext = orderState.context
        if orderContext then
            if orderContext.planTypeIndex then
                if plan.types[orderContext.planTypeIndex].shouldRunWherePossible then
                    return action.modifierTypes.run.index
                end
                if orderContext.researchTypeIndex and research.types[orderContext.researchTypeIndex].shouldRunWherePossibleWhileResearching then
                    return action.modifierTypes.run.index
                end
                if plan.types[orderContext.planTypeIndex].shouldJogWherePossible then
                    return action.modifierTypes.jog.index
                end
            end
            
            if orderContext.lookAtIntent == lookAtIntents.types.putOnClothing.index then
                return action.modifierTypes.run.index
            end
        end

    end
    return nil
end

function serverSapien:clearAndSetNewAssignedObjectID(sapien, newOrderObjectID, indexForNewAssignmentType) --this is an ambulance. Something somewhere is not removing the assigned status
    local assignedObjectIDs = sapien.privateState.assignedObjectIDs
    if not assignedObjectIDs then
        assignedObjectIDs = {}
        sapien.privateState.assignedObjectIDs = assignedObjectIDs
    end
    local prevAssignedID = assignedObjectIDs[indexForNewAssignmentType]
    if prevAssignedID then
        local prevObject = serverGOM:getObjectWithID(prevAssignedID)
        if prevObject then
            local prevObjectState = prevObject.sharedState
            if prevObjectState then
                prevObjectState:remove("assignedSapienIDs", sapien.uniqueID)
                if not next(prevObjectState.assignedSapienIDs) then
                    prevObjectState:remove("assignedSapienIDs")
                end
            end
        end
    end
    assignedObjectIDs[indexForNewAssignmentType] = newOrderObjectID
end

function serverSapien:clearAllAssignedObjectIDs(sapien)
    local assignedObjectIDs = sapien.privateState.assignedObjectIDs
    if assignedObjectIDs then
        for i = 1,2 do
            local prevAssignedID = assignedObjectIDs[i]
            if prevAssignedID then
                local prevObject = serverGOM:getObjectWithID(prevAssignedID)
                if prevObject then
                    local prevObjectState = prevObject.sharedState
                    if prevObjectState then
                        prevObjectState:remove("assignedSapienIDs", sapien.uniqueID)
                        if not next(prevObjectState.assignedSapienIDs) then
                            prevObjectState:remove("assignedSapienIDs")
                        end
                    end
                end
            end
        end
    end
    sapien.privateState.assignedObjectIDs = nil
end

function serverSapien:assignOrderObject(sapien, orderObject, orderState) --returns true if it failed and we should cancel :(
    --mj:debug("serverSapien:assignOrderObject")
    --disabled--mj:objectLog(sapien.uniqueID, "assignOrderObject:", orderObject, " orderState:", orderState)
    
    
    local cooldowns = serverSapienAI.aiStates[sapien.uniqueID].cooldowns
    if cooldowns then
        cooldowns["plan_" .. orderObject.uniqueID] = nil
        cooldowns["m_" .. orderObject.uniqueID] = nil
    end
    
    local planTypeIndex = nil
    local setPlanTypeIndexValue = true
    if orderState.context and orderState.context.planTypeIndex then
        planTypeIndex = orderState.context.planTypeIndex
        setPlanTypeIndexValue = planTypeIndex
    end

    local planObject = nil
    if orderState.context and orderState.context.planObjectID and orderState.context.planObjectID ~= orderObject.uniqueID then
        planObject = serverGOM:getObjectWithID(orderState.context.planObjectID)
    end

    local storageAreaTransferInfo = orderState.context and orderState.context.storageAreaTransferInfo
    if storageAreaTransferInfo then
        if storageAreaTransferInfo.routeID then
            local maxReached = serverLogistics:sapienAssignedCountHasReachedMaxForRoute(storageAreaTransferInfo.routeTribeID or sapien.sharedState.tribeID, storageAreaTransferInfo.routeID, sapien.uniqueID)
            if maxReached then
                --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. serverLogistics:sapienAssignedCountHasReachedMaxForRoute returned true")
                return true
            end
        else
            --disabled--mj:objectLog(sapien.uniqueID, "has storageAreaTransferInfo with no route, calling serverSapien:objectIsAssignedToOtherSapien")
            if serverSapien:objectIsAssignedToOtherSapien(orderObject, sapien.sharedState.tribeID, sapien, {plan.types.transferObject.index}, true) then
                --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. orderObject objectIsAssignedToOtherSapien not compatible with storageAreaTransferInfo:", storageAreaTransferInfo)
                return true
            end
        end
    end

    if planTypeIndex then

       --[[ local planInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
        if not planInfo.available then
            --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. orderObject objectIsAssignedToOtherSapien not compatible with planTypeIndex:", planTypeIndex)
            return true
        end]]

        if planObject then
            if (not plan.types[planTypeIndex].allowLimitlessAssignedForDelivery) then
                --[[if serverSapien:objectIsAssignedToOtherSapien(planObject, sapien.sharedState.tribeID, nil, sapien, {planTypeIndex}, true) then
                    --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. planObject objectIsAssignedToOtherSapien not compatible with planTypeIndex:", planTypeIndex)
                    return true
                end]]

                local planInfo = serverSapien:getInfoForPlanObjectSapienAssignment(planObject, sapien, planTypeIndex)
                if not planInfo.available then
                    --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. planObject objectIsAssignedToOtherSapien not compatible with planTypeIndex:", planTypeIndex)
                    return true
                end
            end
        end
    end

    
    local orderObjectState = orderObject.sharedState

    if orderState.context and orderState.context.seatNodeIndex and orderObjectState and orderObjectState.seatNodes then
        --orderObjectState:set("seatNodes", orderState.context.seatNodeIndex, "assignedSapienID", sapien.uniqueID)
        if not serverSeat:assignToSapien(orderObject, sapien, orderState.context.seatNodeIndex) then
            return true
        end
    end
    
    if cooldowns and planObject and planObject.uniqueID ~= orderObject.uniqueID then
        cooldowns["plan_" .. planObject.uniqueID] = nil
        cooldowns["m_" .. planObject.uniqueID] = nil
    end

    --[[local skipOrderObjectSet = false
    --below had not been functioning correctly until 8/23, all storage areas were always skipped.
    if gameObject.types[orderObject.objectTypeIndex].isStorageArea then
        if orderState.orderTypeIndex ~= order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index and 
        orderState.orderTypeIndex ~= order.types.haulDragObject.index and 
        orderState.orderTypeIndex ~= order.types.haulMoveToObject.index and 
        orderState.orderTypeIndex ~= order.types.removeObject.index then
           -- if (not orderState.context) or (not orderState.context.storageAreaTransferInfo) then
                --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject. skipOrderObjectSet due to orderState:", orderState)
                skipOrderObjectSet = true
           -- end
        end
    end]]

    --if not skipOrderObjectSet then
        if not orderObjectState then
            serverGOM:createSharedState(orderObject)
            orderObjectState = orderObject.sharedState
            gameObjectSharedState:setupState(orderObject, orderObjectState)
        end
        
        if not (orderState.context and orderState.context.seatNodeIndex) then
            --mj:log("assign object:", orderObject.uniqueID, " to sapien:", sapien.uniqueID)
            serverSapien:clearAndSetNewAssignedObjectID(sapien, orderObject.uniqueID, 1)
            orderObjectState:set("assignedSapienIDs", sapien.uniqueID, setPlanTypeIndexValue)

            if gameObject.types[orderObject.objectTypeIndex].isCraftArea then
                serverCraftArea:updateInUseStateForCraftArea(orderObject)
            end
        end
    --end
    
    if planObject then

        local planObjectState = planObject.sharedState
        if not planObjectState then
            serverGOM:createSharedState(planObject)
            planObjectState = planObject.sharedState
            gameObjectSharedState:setupState(planObject, planObjectState)
        end
        --mj:log("assign PLAN object:", planObject.uniqueID, " to sapien:", sapien.uniqueID)
        serverSapien:clearAndSetNewAssignedObjectID(sapien, planObject.uniqueID, 2)
        planObjectState:set("assignedSapienIDs", sapien.uniqueID, setPlanTypeIndexValue)
        
        if gameObject.types[planObject.objectTypeIndex].isCraftArea then
            serverCraftArea:updateInUseStateForCraftArea(planObject)
        end

    end

    return false
end

function serverSapien:offsetSapienOwnershipOfObject(sapien, objectID, offsetMultiplier)
    local ownershipState = sapien.lazyPrivateState.ownershipState
    if not ownershipState or not ownershipState.objects then
        ownershipState = {
            objects = {}
        }
        sapien.lazyPrivateState.ownershipState = ownershipState
    end

    local objects = ownershipState.objects

    if objects[objectID] then
        objects[objectID] = objects[objectID] + offsetMultiplier * 0.1
        objects[objectID] = clamp(objects[objectID], -1.0, 1.0)
    else
        objects[objectID] = offsetMultiplier * 0.1
    end
    serverGOM:saveLazyPrivateStateForObjectWithID(sapien.uniqueID)
end

function serverSapien:getSapienOwnershipOfObject(sapien, objectID)

    local object = serverGOM:getObjectWithID(objectID)
    if object then
        if object.sharedState.assignedBedSapienID then
            if object.sharedState.assignedBedSapienID == sapien.uniqueID then
                return 10.0
            else
                return -1.0
            end
        end
    end

    
    if sapien.lazyPrivateState.ownershipState then
        local objects = sapien.lazyPrivateState.ownershipState.objects
        if objects and objects[objectID] then
            return objects[objectID]
        end
    end
    return 0.0
end

function serverSapien:saveState(sapien)
    serverGOM:saveObject(sapien.uniqueID)
end

function serverSapien:setLookAt(sapien, lookAtObjectID, lookAtPos)
    mj:objectLogTraceback(sapien.uniqueID, "serverSapien:setLookAt:", lookAtObjectID, " lookAtPos:", lookAtPos)
    ----disabled--mj:objectLog(sapien.uniqueID, "setting look at:", lookAtObjectID)
    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    aiState.recentPlanObjectID = lookAtObjectID
    sapien.sharedState:set("lookAtObjectID", lookAtObjectID)
    sapien.sharedState:set("lookAtPoint", lookAtPos)

    --[[

    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    local lookAroundInfo = {
        aiState = aiState,
        isStuck = (pathStuckLastAttemptTime and sharedState.isStuck and (serverWorld:getWorldTime() - pathStuckLastAttemptTime < sapienConstants.pathStuckDelayBetweenRetryAttempts)),
        
        sleepDesire = desire:getCachedSleep(sapien, sapien.temporaryPrivateState, function() 
            return serverWorld:getTimeOfDayFraction(sapien.pos) 
        end),
        restDesire = desire:getDesire(sapien, need.types.rest.index, true),
        musicDesire = desire:getDesire(sapien, need.types.music.index, true),
        happySadMood = mood:getMood(sapien, mood.types.happySad.index),
        foodDesire = desire:getDesire(sapien, need.types.food.index, false),
        
        heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index),

        priorityObjectID = (priorityObjectIDOrNil or aiState.recentPlanObjectID) or sharedState.lookAtObjectID,
    ]]
    
    serverSapienAI:startLookAt(sapien)
    serverSapien:saveState(sapien)
end

function serverSapien:removeLookAt(sapien)
    sapien.sharedState:remove("lookAtObjectID")
    sapien.sharedState:remove("lookAtPoint")
    serverSapien:saveState(sapien)
end

function serverSapien:announce(objectID, restrictTribeID)
    serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function(sapienID)
        local sapien = serverGOM:getObjectWithID(sapienID)
        if sapien then
            if (not restrictTribeID) or restrictTribeID == sapien.sharedState.tribeID then
                serverSapienAI:announce(sapien, objectID)
            end
        end
    end)
end

local function getInitialSleepStateValue(sapienPos)
    local timeOfDayFraction = serverWorld:getTimeOfDayFraction(sapienPos)
    local sleepNeed = math.max(mjm.smoothStep(0.25,0.0, timeOfDayFraction), mjm.smoothStep(0.35,0.825, timeOfDayFraction)) * 0.8

    --mj:log("creating sapien with sleep need:", sleepNeed, " at timeOfDayFraction:", timeOfDayFraction)

    return sleepNeed
end

function serverSapien:resetSleepForPlayerTribeStart(sapien)
    sapien.sharedState:set("needs", need.types.sleep.index, getInitialSleepStateValue(sapien.pos))
    sapien.sharedState:set("initialSleepDelay", serverWorld:getDayLength() * 0.25)
end

local function createTraitState(baseUniqueID, randomSeed)
    local traitCount = #sapienTrait.validTypes
    local traitCountToAdd = rng:integerForUniqueID(baseUniqueID, 2326 + randomSeed, 2) + 1
    local addedTraitIndexes = {}
    local traitState = {}
    for i=1,traitCountToAdd do
        local randomTraitIndex = rng:integerForUniqueID(baseUniqueID, 542723 + randomSeed + i, traitCount) + 1
        while addedTraitIndexes[randomTraitIndex] do
            randomTraitIndex = randomTraitIndex + 1
            if randomTraitIndex > traitCount then
                randomTraitIndex = 1
            end
        end
        addedTraitIndexes[randomTraitIndex] = true
        local sapienTraitType = sapienTrait.validTypes[randomTraitIndex]
        local traitTypeState = {
            traitTypeIndex = sapienTraitType.index
        }
        if sapienTraitType.opposite then
            if rng:boolForUniqueID(baseUniqueID, 21542 + randomSeed) then
                traitTypeState.opposite = true
            end
        end
        table.insert(traitState, traitTypeState)
    end
    
    table.sort(traitState, function(a, b) return a.traitTypeIndex < b.traitTypeIndex end) --this is a bit weird, I guess just for some consistency?

    return traitState
end

local function createSapienStates(tribeID, baseUniqueID, randomSeed, lifeStageIndex, extraSharedState, initialRoles)

    local isFemale = nil
    if extraSharedState then
        isFemale = extraSharedState.isFemale
    end
    if isFemale == nil then
        isFemale = rng:boolForUniqueID(baseUniqueID, 1298 + randomSeed)
    end

    local name = nameLists:generateName(baseUniqueID, 35 + randomSeed, isFemale)

    local sharedState = {
        name = name,
        tribeID = tribeID,
        isFemale = isFemale,
        lifeStageIndex = lifeStageIndex,
        needs = {
            [need.types.food.index] = rng:valueForUniqueID(baseUniqueID, 452 + randomSeed) * 0.2,
            [need.types.sleep.index] = rng:valueForUniqueID(baseUniqueID, 454 + randomSeed) * 0.1,
            [need.types.rest.index] = rng:valueForUniqueID(baseUniqueID, 455 + randomSeed) * 0.2,
            [need.types.exhaustion.index] = 0,
            [need.types.warmth.index] = 0,
            [need.types.music.index] = 0,
        },
        moods = {
            [mood.types.confidentScared.index]  = rng:valueForUniqueID(baseUniqueID, 552 + randomSeed) * 0.4  - 0.1,
            [mood.types.loyalty.index]  = rng:valueForUniqueID(baseUniqueID, 552 + randomSeed) * 1.0 + 3.0,
        },
        skillState = {},
        skillPriorities = {},
        statusEffects = {},
        orderQueue = {},
    }

    for skillTypeIndex,v in pairs(skill.defaultSkills) do
        sharedState.skillState[skillTypeIndex] = { complete = true, fractionComplete = 1.0}
    end
    
    local assignedRoleCount = 0
    if initialRoles then
        for i,skillTypeIndex in ipairs(initialRoles) do
            sharedState.skillPriorities[skillTypeIndex] = 1
            assignedRoleCount = assignedRoleCount + 1
            if assignedRoleCount >= skill.maxRoles then
                break
            end
        end
    end

    

    local privateState = {
        version = serverSapien.sapienSaveStateVersion,
    }

    local lazyPrivateState = {
        relationships = {},
    }

    if extraSharedState then
        for k,v in pairs(extraSharedState) do
            sharedState[k] = v
        end
    end

    local traitState = createTraitState(baseUniqueID, randomSeed)
    sharedState.traits = traitState

    for i,info in ipairs(traitState) do
        local traitTypeIndex = info.traitTypeIndex
        local skillInfluences = sapienTrait.types[traitTypeIndex].skillInfluences
        if skillInfluences then
            for skillTypeIndex,value in pairs(skillInfluences) do
                if skill.types[skillTypeIndex].startLearned then
                    local traitValue = value
                    if info.opposite then
                        traitValue = -traitValue
                    end
                    if traitValue > 0.9 then
                        if assignedRoleCount < skill.maxRoles and sharedState.skillPriorities[skillTypeIndex] == nil then
                            sharedState.skillPriorities[skillTypeIndex] = 1
                            assignedRoleCount = assignedRoleCount + 1

                            if sharedState.skillState[skillTypeIndex] or rng:randomChance(0.5) then --if we are doubling up, another trait has positive influence for this skill, then make it 100% pass
                                sharedState.skillState[skillTypeIndex] = { complete = true, fractionComplete = 1.0}
                            else
                                local randomValue = rng:randomValue() * 0.8 + 0.1
                                sharedState.skillState[skillTypeIndex] = { fractionComplete = randomValue}
                            end
                        end
                    elseif traitValue < -0.9 then
                        if sharedState.skillPriorities[skillTypeIndex] then
                            assignedRoleCount = assignedRoleCount - 1
                            sharedState.skillPriorities[skillTypeIndex] = nil
                        end
                    end
                end
            end
        end

       --[[ if not info.opposite then
            local startLearnedChances = sapienTrait.types[traitTypeIndex].startLearnedChances
            if startLearnedChances then
                for skillTypeIndex,value in pairs(startLearnedChances) do
                    if sharedState.skillState[skillTypeIndex] or rng:randomChance(value) then --if we are doubling up, another trait has startLearnedChance for this skill, then make it 100% pass
                        sharedState.skillState[skillTypeIndex] = { complete = true, fractionComplete = 1.0}
                        if assignedRoleCount < skill.maxRoles and sharedState.skillPriorities[skillTypeIndex] == nil then
                            sharedState.skillPriorities[skillTypeIndex] = 1
                            assignedRoleCount = assignedRoleCount + 1
                        end
                    else
                        local randomValue = rng:randomValue() * 0.8 + 0.1
                        sharedState.skillState[skillTypeIndex] = { fractionComplete = randomValue}
                    end
                end
            end
        end]]
    end
    
    local optimistTrait = sapienTrait:getTraitValue(traitState, sapienTrait.types.optimist.index)
    if optimistTrait ~= nil then
        if optimistTrait > 0 then
            sharedState.statusEffects[statusEffect.types.optimist.index] = {}
        else
            sharedState.statusEffects[statusEffect.types.pessimist.index] = {}
        end
    end

    sharedState.moods[mood.types.happySad.index] = 3

    return {
        sharedState = sharedState,
        privateState = privateState,
        lazyPrivateState = lazyPrivateState,
    }
end

function serverSapien:createSapienObjectAtPos(sapienID, states, tribeID, pos, rotationOrNil)
    local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(pos)
    local sharedState = states.sharedState
    local privateState = states.privateState
    local lazyPrivateState = states.lazyPrivateState

    sharedState.needs[need.types.sleep.index] = getInitialSleepStateValue(shiftedPos)

    local worldTime = serverWorld:getWorldTime()

    for otherSapienID,relationshipInfo in pairs(lazyPrivateState.relationships) do
        relationshipInfo.seen = worldTime
    end

    local rotation = rotationOrNil
    if not rotation then -- < 0.5.0.14
        local posNormal = normalize(pos)
        local randomVecNormlaized = normalize(rng:randomVec())
        local randomVecPerp = normalize(cross(randomVecNormlaized, posNormal))
        rotation = mat3LookAtInverse(-randomVecPerp, posNormal)
    end

    local createdSapienID = serverGOM:createGameObjectWithID(sapienID, {
            objectTypeIndex = gameObject.types.sapien.index,
            addLevel = mj.SUBDIVISIONS - 3,
            pos = shiftedPos,
            rotation = rotation,
            velocity = vec3(0.0,0.0,0.0),
            scale = gameObject.types.sapien.scale,
            renderType = RENDER_TYPE_DYNAMIC,
            hasPhysics = gameObject.types.sapien.hasPhysics,
            sharedState = sharedState,
            privateState = privateState,
            lazyPrivateState = lazyPrivateState
        }
    )

    if createdSapienID then
        local sapienObject = serverGOM:getObjectWithID(createdSapienID)
        serverSapien:initSpawnedSapien(sapienObject, tribeID)
    end

    return createdSapienID
end

function serverSapien:createSapienObject(sapienID, states, tribeID,tribeCenter,randomSeed)
    local randomVecNormlaized = normalize(rng:vecForUniqueID(sapienID, 46 + randomSeed))
    local randomVecPerp = normalize(cross(randomVecNormlaized, tribeCenter))
    local offsetDistance = mj:mToP(5.0 + 10.0 * rng:valueForUniqueID(sapienID, 122 + randomSeed))
    local randomPos = tribeCenter + normalize(randomVecPerp) * offsetDistance
    local rotation = mat3LookAtInverse(-randomVecPerp, tribeCenter)
    local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(randomPos)
    local sharedState = states.sharedState
    local privateState = states.privateState
    local lazyPrivateState = states.lazyPrivateState

    sharedState.needs[need.types.sleep.index] = getInitialSleepStateValue(shiftedPos)

    local worldTime = serverWorld:getWorldTime()

    for otherSapienID,relationshipInfo in pairs(lazyPrivateState.relationships) do
        relationshipInfo.seen = worldTime
    end

    local createdSapienID = serverGOM:createGameObjectWithID(sapienID, {
            objectTypeIndex = gameObject.types.sapien.index,
            addLevel = mj.SUBDIVISIONS - 3,
            pos = shiftedPos,
            rotation = rotation,
            velocity = vec3(0.0,0.0,0.0),
            scale = gameObject.types.sapien.scale,
            renderType = RENDER_TYPE_DYNAMIC,
            hasPhysics = gameObject.types.sapien.hasPhysics,
            sharedState = sharedState,
            privateState = privateState,
            lazyPrivateState = lazyPrivateState
        }
    )

    if createdSapienID then
        local sapienObject = serverGOM:getObjectWithID(createdSapienID)
        serverSapien:initSpawnedSapien(sapienObject, tribeID)
    end

    return createdSapienID
end

local availableCloakObjectTypes = {
    gameObject.types.mammothWoolskin.index,
    gameObject.types.alpacaWoolskin.index,
    gameObject.types.alpacaWoolskin_white.index,
    gameObject.types.alpacaWoolskin_black.index,
    gameObject.types.alpacaWoolskin_red.index,
    gameObject.types.alpacaWoolskin_yellow.index,
    gameObject.types.alpacaWoolskin_cream.index,
}

function serverSapien:createInitialTribeSpawnSapienStates(triFaceUniqueID, randomSeed, lifeStageIndex, extraState, initialRoles, temperatureZones, isNomad, tribeCenterNormalized)
    if not extraState then
        extraState = {}
    end

    extraState.ageFraction = rng:valueForUniqueID(triFaceUniqueID, 128 + randomSeed) * 0.8

    local temperatureZoneIndex = temperatureZones[2] --worst case if not a nomad, otherwise get current zone index
    --mj:log("serverSapien:createInitialTribeSpawnSapienStates temperatureZoneIndex:", temperatureZoneIndex)
    if isNomad then
        temperatureZoneIndex = weather:getTemperatureZoneIndex(temperatureZones, serverWorld:getWorldTime(), serverWorld:getTimeOfDayFraction(tribeCenterNormalized), serverWorld.yearSpeed, tribeCenterNormalized, false, false, 0)
    end

    
    if temperatureZoneIndex <= weather.temperatureZones.cold.index then
        local inventories = extraState.inventories
        if not extraState.inventories then
            inventories = {}
            extraState.inventories = inventories
        end

        local cloakObjectTypeIndex = nil
        if rng:integerForUniqueID(triFaceUniqueID, 274522 + randomSeed, 8) == 1 then --rarely use randomSeed, otherwise use the same seed for most of the sapiens in the tribe
            cloakObjectTypeIndex = availableCloakObjectTypes[rng:integerForUniqueID(triFaceUniqueID, 235435 + randomSeed, #availableCloakObjectTypes) + 1]
        else
            cloakObjectTypeIndex = availableCloakObjectTypes[rng:integerForUniqueID(triFaceUniqueID, 235435, #availableCloakObjectTypes) + 1]
        end

        --[[local cloakObjectTypeIndex = gameObject.types.alpacaWoolskin.index
        if rng:boolForUniqueID(triFaceUniqueID, 32822 + randomSeed) then
            cloakObjectTypeIndex = gameObject.types.mammothWoolskin.index
        end
        
        if rng:integerForUniqueID(triFaceUniqueID, 12539 + randomSeed, 8) == 1 then
            cloakObjectTypeIndex = gameObject.types.alpacaWoolskin_white.index
        end]]
        
        local torsoInventory = {
            countsByObjectType = {
                [cloakObjectTypeIndex] = 1
            },
            objects = {
                {
                    objectTypeIndex = cloakObjectTypeIndex
                }
            },
        }
        inventories[sapienInventory.locations.torso.index] = torsoInventory
    end


    return createSapienStates(triFaceUniqueID, triFaceUniqueID, randomSeed, lifeStageIndex, extraState, initialRoles)
end

function serverSapien:createChildFromMother(motherSapien)

    local motherSharedState = motherSapien.sharedState

    local skinColorFraction = motherSharedState.skinColorFraction
    local hairColorGene = motherSharedState.hairColorGene
    local eyeColorGene = motherSharedState.eyeColorGene

    local randomSeed = rng:getRandomSeed()

    local fatherID = nil

    local pregnancyFatherInfo = motherSharedState.pregnancyFatherInfo
    if pregnancyFatherInfo then
        local mix = rng:integerForUniqueID(motherSapien.uniqueID, 9265 + randomSeed, 3)
        if mix == 1 then
            skinColorFraction = pregnancyFatherInfo.skinColorFraction
        elseif mix == 2 then
            skinColorFraction = skinColorFraction * 0.5 + pregnancyFatherInfo.skinColorFraction * 0.5
        end

        if rng:boolForUniqueID(motherSapien.uniqueID, 21894 + randomSeed) then
            hairColorGene = pregnancyFatherInfo.hairColorGene
        end

        if rng:boolForUniqueID(motherSapien.uniqueID, 923256 + randomSeed) then
            eyeColorGene = pregnancyFatherInfo.eyeColorGene
        end

        fatherID = pregnancyFatherInfo.fatherID
    end

    local isFemale = motherSharedState.babyIsFemale

    local extraState = {
        tribeID = motherSharedState.tribeID,
        skinColorFraction = skinColorFraction,
        hairColorGene = hairColorGene,
        eyeColorGene = eyeColorGene,
        ageFraction = 0.0,
        isFemale = isFemale,
        nomad = motherSharedState.nomad,
        tribeBehaviorTypeIndex = motherSharedState.tribeBehaviorTypeIndex,
        nomadState = motherSharedState.nomadState,
    }
    
    local childSapienID = serverGOM:reserveUniqueID()

    local initialRoles = {}
    for skillTypeIndex,priority in pairs(motherSharedState.skillPriorities) do
        table.insert(initialRoles, skillTypeIndex)
    end

    local childSapienInfoStates = createSapienStates(motherSharedState.tribeID, childSapienID, randomSeed, sapienConstants.lifeStages.child.index, extraState, initialRoles)
    
    local offsetDirection = mat3GetRow(motherSapien.rotation, 2)
   -- mj:log("serverSapien:createChildFromMother offsetDirection:", offsetDirection)
    local spawnPoint = motherSapien.pos + offsetDirection * mj:mToP(1.0)
    local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(spawnPoint)

    childSapienInfoStates.sharedState.needs[need.types.sleep.index] = getInitialSleepStateValue(shiftedPos)

    local createdSapienID = serverGOM:createGameObjectWithID(childSapienID, 
        {
            objectTypeIndex = gameObject.types.sapien.index,
            addLevel = mj.SUBDIVISIONS - 3,
            pos = shiftedPos,
            rotation = motherSapien.rotation,
            velocity = vec3(0.0,0.0,0.0),
            scale = gameObject.types.sapien.scale,
            renderType = RENDER_TYPE_DYNAMIC,
            hasPhysics = gameObject.types.sapien.hasPhysics,
            sharedState = childSapienInfoStates.sharedState,
            privateState = childSapienInfoStates.privateState,
            lazyPrivateState = childSapienInfoStates.lazyPrivateState,
        }
    )

    if not createdSapienID then
        mj:error("Problem creating child sapien :(")
        return nil
    end

    local childSapien = serverGOM:getObjectWithID(childSapienID)
    local childSapienLazyPrivateState = childSapien.lazyPrivateState

    local function generateRandomRelationship(familyRelationshipType)
        local longTermMood = clamp(rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) * 0.6 + 0.4, 0.0, 1.0)
        return {
            mood = {
                short = clamp(longTermMood + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = longTermMood,
            },
            bond = {
                short = clamp(rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) * 0.4 + 0.6, 0.0, 1.0),
                long = clamp(longTermMood * 0.5 + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) * 0.2 + 0.8) * 0.5, 0.0, 1.0),
            },
            familyRelationshipType = familyRelationshipType,
        }
    end

    local childRelationships = childSapienLazyPrivateState.relationships
    childRelationships[motherSapien.uniqueID] = generateRandomRelationship(sapienConstants.familyRelationshipTypes.mother)

    local motherRelationships = motherSapien.lazyPrivateState.relationships
    motherRelationships[childSapienID] = generateRandomRelationship(sapienConstants.familyRelationshipTypes.biologicalChild)

    
    local function assignVariationOfMotherRelationshipForChild(otherSapienID, motherRelationshipInfo, otherSapienLazyPrivateState)
        local variation = {
            mood = {
                short = clamp(motherRelationshipInfo.mood.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.8, 0.0, 1.0),
                long = clamp(motherRelationshipInfo.mood.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
            },
            bond = {
                short = clamp(motherRelationshipInfo.bond.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = clamp(motherRelationshipInfo.bond.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
            },
        }

        if otherSapienID == fatherID then
            variation.familyRelationshipType = sapienConstants.familyRelationshipTypes.father
        end

        childRelationships[otherSapienID] =  variation
    end
    
    local function assignVariationOfChildRelationshipForOtherSapien(otherSapienID, motherRelationshipInfo, childRelationshipInfo, otherSapienLazyPrivateState)
        local variation = {
            mood = {
                short = clamp(childRelationshipInfo.mood.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = clamp(childRelationshipInfo.mood.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
            },
            bond = {
                short = clamp(childRelationshipInfo.bond.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = clamp(childRelationshipInfo.bond.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
            },
        }


        if motherRelationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.biologicalChild then
            variation.familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
            childRelationships[otherSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
        end

        if otherSapienID == fatherID then
            variation.familyRelationshipType = sapienConstants.familyRelationshipTypes.biologicalChild
        end
            
        otherSapienLazyPrivateState.relationships[childSapienID] = variation
    end

    local rCounter = 0
    for otherSapienID,motherRelationshipInfo in pairs(motherRelationships) do -- create child relationships according to mother relationships
        if otherSapienID ~= childSapienID then
            local otherSapien = serverGOM:getObjectWithID(otherSapienID)
            if otherSapien then

                local otherSapienLazyPrivateState = otherSapien.lazyPrivateState
                assignVariationOfMotherRelationshipForChild(otherSapienID, motherRelationshipInfo, otherSapienLazyPrivateState)
                assignVariationOfChildRelationshipForOtherSapien(otherSapienID, motherRelationshipInfo, childRelationships[otherSapienID], otherSapienLazyPrivateState)
                
                serverGOM:saveObject(otherSapienID)
            end
            rCounter = rCounter + 1
        end
    end
    
    local fatherRelationships = nil
    if fatherID then
        local fatherSapien = serverGOM:getObjectWithID(fatherID)
        if fatherSapien and fatherSapien.lazyPrivateState then
            fatherRelationships = fatherSapien.lazyPrivateState.relationships
        end
    end

    if fatherRelationships then
        for otherSapienID,fatherRelationshipInfo in pairs(fatherRelationships) do
            if otherSapienID ~= childSapienID then
                local otherSapien = serverGOM:getObjectWithID(otherSapienID)
                if otherSapien then
                    if fatherRelationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.biologicalChild then
                        if childRelationships[otherSapienID] and otherSapien.lazyPrivateState.relationships[childSapienID] then
                            otherSapien.lazyPrivateState.relationships[childSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
                            childRelationships[otherSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
                        end
                    end
                end
            end
        end
    end

    
    serverGOM:saveObject(motherSapien.uniqueID)
    serverGOM:saveObject(childSapienID)
    
    if motherSharedState.tribeID then
        serverWorld:updateFollowerCount(motherSharedState.tribeID)
        serverGOM:sendFollowersListsForSapienCountChange(motherSharedState.tribeID)
    end

    

    return childSapienID
end

local function changeTribeForRecruitCompletion(sapien, tribeID)
    local sharedState = sapien.sharedState
    if sharedState.tribeID ~= tribeID then
        local previousTribeID = sharedState.tribeID
        planManager:removeAllPlanStatesForObject(sapien, sharedState, nil)
        local removeHeldObjectOrderContext = false
        serverSapien:cancelOrderAtQueueIndex(sapien, 1, removeHeldObjectOrderContext)
        sharedState:set("tribeID", tribeID)
        sharedState:remove("nomad")
        sharedState:remove("tribeBehaviorTypeIndex")

        serverGOM:sapienTribeChanged(sapien, previousTribeID, tribeID)
        serverGOM:sendFollowersListsForSapienCountChange(previousTribeID)
        serverGOM:sendFollowersListsForSapienCountChange(tribeID)

        --serverGOM:clientFollowersAdded(tribeID, {sapien.uniqueID})
        serverGOM:sendNotificationForObject(sapien, notification.types.recruited.index, nil, sapien.sharedState.tribeID)

        local destinationState = serverDestination:getDestinationState(tribeID)
        serverGOM:sendNotificationForObject(sapien, notification.types.recruitedTakenByOtherTribe.index, {
            tribeName = destinationState and destinationState.name,
        }, previousTribeID)
        

        serverStatistics:recordEvent(tribeID, statistics.types.recruit.index)
        serverTutorialState:nomadWasRecruited(tribeID)
        serverGOM:setAlwaysSendToOwnerClientForObjectWithID(sapien.uniqueID, true)
        --serverGOM:addObjectToSet(sapien, serverGOM.objectSets.playerSapiens)
        --serverGOM:removeObjectFromSet(sapien, serverGOM.objectSets.nomads)

        if serverSapien:isSleeping(sapien) then
            serverWorld:setSapienSleeping(sapien, true)
        end

        if ((statusEffect:hasEffect(sharedState, statusEffect.types.minorVirus.index)) or
        (statusEffect:hasEffect(sharedState, statusEffect.types.majorVirus.index)) or
        (statusEffect:hasEffect(sharedState, statusEffect.types.criticalVirus.index))) and
        (not statusEffect:hasEffect(sharedState, statusEffect.types.virusTreated.index)) then
            planManager:addStandardPlan(sharedState.tribeID, plan.types.treatVirus.index, sapien.uniqueID, nil, nil, nil, nil, nil, nil)
        end

        
        for skillTypeIndex,v in pairs(sharedState.skillPriorities) do
            if v == 1 then
                serverGOM:addObjectToSet(sapien, skill.types[skillTypeIndex].sapienSetIndex)
            end
        end

        for skillTypeIndex, skillState in pairs(sharedState.skillState) do
            if skillState.fractionComplete > 0.2 then
                local unlockDiscoveryPartialCompletion = mjm.clamp(skillState.fractionComplete, 0.2, 0.8)
                serverWorld:increaseDiscoveryForRecruitedSkill(sapien, tribeID, skillTypeIndex, unlockDiscoveryPartialCompletion)
            end
        end

    end
end


function serverSapien:recruitComplete(sapienIncoming, tribeID)
    local sharedState = sapienIncoming.sharedState
    local otherTribeID = sharedState.tribeID
    if otherTribeID ~= tribeID then
        if sharedState.nomad then
            local recruitChanceOffset = nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].recruitChanceOffset
            if recruitChanceOffset and (recruitChanceOffset < 0) then
                serverWorld:addToPlayerNomadReputation(tribeID, 5)
            end
            
            serverGOM:callFunctionForAllSapiensInTribe(otherTribeID, function(otherSapien)
                changeTribeForRecruitCompletion(otherSapien, tribeID)
            end)
        else
            changeTribeForRecruitCompletion(sapienIncoming, tribeID)
            --todo recruit friends too
            serverTribeAIPlayer:addGrievanceIfNeeded(otherTribeID, tribeID, grievance.types.sapienRecruited.index, 1, nil)
            serverTribeAIPlayer:preventSpawnTopUps(otherTribeID)
        end


        serverTribe:recalculatePopulation(otherTribeID)
        serverTribe:recalculatePopulation(tribeID)
        serverWorld:updateFollowerCount(otherTribeID)
        serverWorld:updateFollowerCount(tribeID)

        planManager:updateAllThreatProximityObjectsForRecruitOrRelationshipSettingChange(tribeID)
    end
end


function serverSapien:banishComplete(sapienIncoming, banishingTribeID)
    local sharedState = sapienIncoming.sharedState
    local oldTribeID = sharedState.tribeID
    serverTribeAIPlayer:addGrievanceIfNeeded(oldTribeID, banishingTribeID, grievance.types.sapienBanished.index, 1, nil)
    serverTribeAIPlayer:preventSpawnTopUps(oldTribeID)
    if not sharedState.nomad then --it seems reasonable to ask any vistor to leave without consequence
        serverWorld:addToPlayerNomadReputation(banishingTribeID, -2) --always set for non nomads, they have become a nomad now, they gonna be dragging your name
    end
    serverSapien:dropHeldInventoryImmediately(sapienIncoming)
    leaveTribe(sapienIncoming, banishingTribeID)
    serverTribe:recalculatePopulation(oldTribeID)
    serverWorld:updateFollowerCount(oldTribeID)
    
    local otherDestinationState = serverDestination:getDestinationState(oldTribeID)
    local banishingDestinationState = serverDestination:getDestinationState(banishingTribeID)
    if otherDestinationState.clientID and oldTribeID ~= banishingTribeID then
        serverGOM:sendNotificationForObject(sapienIncoming, notification.types.banishedByOtherTribe.index, {
            tribeName = banishingDestinationState and banishingDestinationState.name,
        }, oldTribeID)
    end
end

function serverSapien:maxFollowerNeeds(sapienIDs)

    -- to make them leave
    --[[for i,sapienID in ipairs(sapienIDs) do
        local sapien = serverGOM:getObjectWithID(sapienID)
        if sapien then
            local loyaltyMoodValue = -1.0
            sapien.sharedState:set("moods", mood.types.loyalty.index, loyaltyMoodValue)
            sapien.sharedState:set("leaveTimer", 1441.0)
            leaveTribe(sapien)
        end
    end]]

    

    for i,sapienID in ipairs(sapienIDs) do


        local sapien = serverGOM:getObjectWithID(sapienID)
        if sapien then

            local destinationState = serverDestination:getDestinationState(sapien.sharedState.tribeID)
            serverDestination.unloadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex](destinationState)
            serverDestination.hibernatingLoadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex](destinationState)
            
            --serverGOM:sendNotificationForObject(sapien, notification.types.lowLoyalty.index, nil, sapien.sharedState.tribeID) --debug

            local sharedState = sapien.sharedState

            if sharedState and sharedState.needs then

                --to max:
                for j,needType in ipairs(need.validTypes) do
                    sharedState:set("needs", needType.index, 0.0)
                end
                for j,moodType in ipairs(mood.validTypes) do
                    sharedState:set("moods", moodType.index, 5)
                end
                
                --to make rest exhausted:
                --sharedState:set("needs", need.types.rest.index, 1.0)

                --to make hungry:
                --sharedState:set("needs", need.types.food.index, 1.0)

                --to make sleepy tired:
                --sharedState:set("needs", need.types.sleep.index, 1.0)

                -- to leave:
                --[[local loyaltyMoodValue = -1.0
                for j,needType in ipairs(need.validTypes) do
                    sharedState:set("needs", needType.index, 1.0)
                end
                for j,moodType in ipairs(mood.validTypes) do
                    sharedState:set("moods", moodType.index, 0)
                end
                sharedState:set("moods", mood.types.loyalty.index, loyaltyMoodValue)
                sharedState:set("leaveTimer", 1441.0)]]

                -- to age up:
                --[[if sharedState.lifeStageIndex < sapienConstants.lifeStages.elder.index then
                    sharedState:set("lifeStageIndex", sharedState.lifeStageIndex + 1)
                    local clientID = serverWorld:clientIDForTribeID(sapien.sharedState.tribeID)
                    if clientID then
                        serverWorld:updatePopulationStatistics(clientID, sapien.sharedState.tribeID)
                    end
                    serverWorld:skillPrioritiesOrLimitedAbilityChanged(sapien.sharedState.tribeID)
                    sharedState:set("ageFraction", 0.0)

                    serverGOM:sendNotificationForObject(sapien, notification.types.agedUp.index, {
                        lifeStageIndex = sharedState.lifeStageIndex,
                    }, sapien.sharedState.tribeID)
                    planManager:updateProximityForAbilityChange(sapien.uniqueID)
                end]]

                -- to injure:
                serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorInjury.index, sapienConstants.injuryDuration)
                planManager:addStandardPlan(sapien.sharedState.tribeID, plan.types.treatInjury.index, sapien.uniqueID, nil, nil, nil, nil, nil, nil)
                serverGOM:sendNotificationForObject(sapien, notification.types.minorInjury.index, serverSapien:getOrderStatusUserDataForNotification(sapien), sapien.sharedState.tribeID)
                local interactionInfo = social:getExclamation(sapien, social.interactions.ouchMinor.index, nil)
                if interactionInfo then
                    serverGOM:sendNotificationForObject(sapien, notification.types.social.index, interactionInfo, sapien.sharedState.tribeID)
                end

            end
           -- sharedState:set("statusEffects", {})

            --serverTutorialState:sapienGotFoodPoisoningDueToContamination(sapien.sharedState.tribeID)

           -- serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.exhausted.index, sapienConstants.burnDuration)
            --serverStatusEffects:setTimedEffect(sharedState, statusEffect.types.majorVirus.index, sapienConstants.virusDuration)
           
           --serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.veryHungry.index, sapienConstants.hungryDurationUntilEscalation)

        end
    end
end

function serverSapien:getRelationshipInfo(sapien, otherSapienID)
    local lazyPrivateState = sapien.lazyPrivateState
    return lazyPrivateState.relationships[otherSapienID]
end

function serverSapien:getAndCreateRelationshipInfoIfNeeded(sapien, otherSapienID)
    local lazyPrivateState = sapien.lazyPrivateState
    local relationshipInfo = lazyPrivateState.relationships[otherSapienID]
    if not relationshipInfo then
        relationshipInfo = {
            bond = {
                long = 0.0,
                short = 0.05
            },
            mood = {
                long = 0.5,
                short = 0.5 --could depend on personality, and on what the other sapien is doing
            }
        }

        lazyPrivateState.relationships[otherSapienID] = relationshipInfo
        serverGOM:saveLazyPrivateStateForObjectWithID(sapien.uniqueID)
    end
    return relationshipInfo
end

function serverSapien:updateLastSeenRelationshipInfo(sapien, otherSapienID)
    local relationshipInfo = serverSapien:getAndCreateRelationshipInfoIfNeeded(sapien, otherSapienID)

    local worldTime = serverWorld:getWorldTime()
    relationshipInfo.seen = worldTime

    serverSapien:saveState(sapien)
end

function serverSapien:addToBondAndMood(sapien, otherSapienID, bondScoreOffset, moodScoreOffset)
    local relationshipInfo = serverSapien:getAndCreateRelationshipInfoIfNeeded(sapien, otherSapienID)

    local worldTime = serverWorld:getWorldTime()
    relationshipInfo.seen = worldTime

    relationshipInfo.bond.short = relationshipInfo.bond.short + bondScoreOffset
    relationshipInfo.bond.short = clamp(relationshipInfo.bond.short, 0.0, 1.0)
    relationshipInfo.mood.short = relationshipInfo.mood.short + moodScoreOffset
    relationshipInfo.mood.short = clamp(relationshipInfo.mood.short, 0.0, 1.0)

    serverGOM:saveLazyPrivateStateForObjectWithID(sapien.uniqueID)
end

function serverSapien:updateRelationshipScores(sapien, dt)
    local lazyPrivateState = sapien.lazyPrivateState
    local relationships = lazyPrivateState.relationships
    if relationships then
        for otherSapienID, relationshipInfo in pairs(relationships) do
            relationshipInfo.bond.short = relationshipInfo.bond.short - dt * 0.0001
            if relationshipInfo.mood.short < 0.5 then
                relationshipInfo.mood.short = relationshipInfo.mood.short + dt * 0.0001
            else
                relationshipInfo.mood.short = relationshipInfo.mood.short - dt * 0.0001
            end
            relationshipInfo.bond.short = clamp(relationshipInfo.bond.short, 0.0, 1.0)
            relationshipInfo.mood.short = clamp(relationshipInfo.mood.short, 0.0, 1.0)

            relationshipInfo.bond.long = relationshipInfo.bond.long + (relationshipInfo.bond.short - relationshipInfo.bond.long) * dt * 0.0001
            relationshipInfo.mood.long = relationshipInfo.mood.long + (relationshipInfo.mood.short - relationshipInfo.mood.long) * dt * 0.0001
        end
        
        serverGOM:saveLazyPrivateStateForObjectWithID(sapien.uniqueID)
    end
end

function serverSapien:setSkillPriority(sapien, skillTypeIndex, priority)
    if priority == 1 then
        sapien.sharedState:set("skillPriorities", skillTypeIndex, priority)
        serverGOM:addObjectToSet(sapien, skill.types[skillTypeIndex].sapienSetIndex)
    else
        sapien.sharedState:remove("skillPriorities", skillTypeIndex)
        serverGOM:removeObjectFromSet(sapien, skill.types[skillTypeIndex].sapienSetIndex)
    end
    
    serverWorld:skillPrioritiesOrLimitedAbilityChanged(sapien.sharedState.tribeID)
end

local agroMobRunAwayProximityDistanceDefault = mj:mToP(10.0)
local agroMobRunAwayProximityDistanceCourageous = mj:mToP(5.0)
local agroMobRunAwayProximityDistanceFearful = mj:mToP(20.0)

function serverSapien:closeMobAgroTriggered(sapienID, mobObject, mobDistance, directionFromMob)
    local sapien = serverGOM:getObjectWithID(sapienID)
    local courageousTrait = sapienTrait:getTraitValue(sapien.sharedState.traits, sapienTrait.types.courageous.index)
    local triggerDistance = agroMobRunAwayProximityDistanceDefault
    if courageousTrait then
        if courageousTrait == 1 then
            triggerDistance = agroMobRunAwayProximityDistanceCourageous
        elseif courageousTrait == -1 then
            triggerDistance = agroMobRunAwayProximityDistanceFearful
        end
    end
    if mobDistance < triggerDistance then
        if sapien then
            local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
            unsavedState.agroMobRunAwayDirection = directionFromMob
            unsavedState.agroMobRunAwayMobID = mobObject.uniqueID
        end
    end
end

function serverSapien:hostileMobProximityChanged(sapienID, mobObject, newIsClose)
    --untested, decided not to use, but probably useful at some point
    --[[local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    local closeMobs = unsavedState.closeMobs
    if not closeMobs then
        closeMobs = {}
        unsavedState.closeMobs = closeMobs
    end

    if newIsClose then
        closeMobs[mobObject.uniqueID] = true
    else
        closeMobs[mobObject.uniqueID] = nil
    end]]
end

function serverSapien:spreadVirus(fromSapien, toSapien)
    local fromSharedState = fromSapien.sharedState
    local hasMinorVirus = statusEffect:hasEffect(fromSharedState, statusEffect.types.minorVirus.index)
    if hasMinorVirus or
    statusEffect:hasEffect(fromSharedState, statusEffect.types.majorVirus.index) or
    statusEffect:hasEffect(fromSharedState, statusEffect.types.criticalVirus.index) then
        local toSharedState = toSapien.sharedState
        local immunityInfluence = sapienTrait:getInfluence(toSharedState.traits, sapienTrait.influenceTypes.immunity.index)

        local allowSpread = true
        if hasMinorVirus then
            if immunityInfluence > -0.5 and (immunityInfluence > 0.5 or rng:randomInteger(2) ~= 1) then -- always spread minor infections to weak immunity trait, never to strong, otherwise 50/50 chance
                allowSpread = false
            end
        elseif immunityInfluence > 0.5 and rng:randomInteger(4) ~= 1 then -- 1 in 4 chance of spreading major/critical infections to strong immunity
            allowSpread = false
        end

        if allowSpread and 
        (not statusEffect:hasEffect(toSharedState, statusEffect.types.incubatingVirus.index)) and
        (not statusEffect:hasEffect(toSharedState, statusEffect.types.minorVirus.index)) and
        (not statusEffect:hasEffect(toSharedState, statusEffect.types.majorVirus.index)) and
        (not statusEffect:hasEffect(toSharedState, statusEffect.types.criticalVirus.index)) and
        (not statusEffect:hasEffect(toSharedState, statusEffect.types.virusImmunity.index))
        then
            mj:log("virus spread from:", fromSapien.uniqueID, " to:", toSapien.uniqueID)
            serverStatusEffects:setTimedEffect(toSharedState, statusEffect.types.incubatingVirus.index, sapienConstants.virusIncubationDuration)
        end
    end
end

function serverSapien:setHaulDragingObject(sapien, object)
    local incomingID = nil
    if object then
        incomingID = object.uniqueID
    end

    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:setHaulDragingObject:", incomingID)
    --mj:error("serverSapien:setHaulDragingObject")

    if incomingID ~= sapien.sharedState.haulingObjectID then
        if sapien.sharedState.haulingObjectID then
            local oldObject = serverGOM:getObjectWithID(sapien.sharedState.haulingObjectID)
            if oldObject then
                oldObject.sharedState:remove("haulingSapienID")
            end
        end
        
        if incomingID then
            sapien.sharedState:set("haulingObjectID", incomingID)
            object.sharedState:set("haulingSapienID", sapien.uniqueID)
        else
            sapien.sharedState:remove("haulingObjectID")
        end
    end

end

function serverSapien:checkAllSapiensForClothingDropDueToResourceWearPermissionChange(tribeID, wearClothingBlockList)
    if tribeID and wearClothingBlockList and next(wearClothingBlockList) then
        serverGOM:callFunctionForAllSapiensInTribe(tribeID, function(sapien)
            local torsoInventory = sapienInventory:getObjects(sapien, sapienInventory.locations.torso.index)
            if torsoInventory then
                for i,objectInfo in ipairs(torsoInventory) do
                    if wearClothingBlockList[objectInfo.objectTypeIndex] then
                        serverSapienAI:addOrderToRemoveClothingItem(sapien, sapienInventory.locations.torso.index)
                    end
                end
            end
        end)
    end
end


function serverSapien:autoAssignToRole(sapien, assignSkillTypeIndex)
    --mj:debug("autoAssign attempt:", sapien.uniqueID, " - ", assignSkillTypeIndex)
    if (not assignSkillTypeIndex) then
        mj:error("autoAssignToRole missing assignSkillTypeIndex:", assignSkillTypeIndex, " sapien:", sapien.uniqueID, " sharedState:", sapien.sharedState)
        return false
    end
    --disabled--mj:objectLog(sapien.uniqueID, "serverSapien:autoAssignToRole:", assignSkillTypeIndex)
    local researchType = research.researchTypesBySkillType[assignSkillTypeIndex]
    if researchType and (not serverWorld:discoveryIsCompleteForTribe(sapien.sharedState.tribeID, researchType.index)) then
       -- mj:log("incomplete:", researchType.index)
        if serverTribeAIPlayer:getIsAIPlayerTribe(sapien.sharedState.tribeID) then
            serverSapienSkills:completeResearchImmediately(sapien, researchType.index, nil)
            local incompleteCraftableIndexes = research:getAllIncompleteRequiredConstructableTypeIndexes(researchType.index, planHelper.craftableDiscoveriesByTribeID[sapien.sharedState.tribeID])
            --mj:log("incompleteCraftableIndexes:", incompleteCraftableIndexes)
            if incompleteCraftableIndexes then
                for i,incompleteCraftableIndex in ipairs(incompleteCraftableIndexes) do
                    --mj:log("YAY! completing:", incompleteCraftableIndex)
                    serverSapienSkills:completeResearchImmediately(sapien, researchType.index, incompleteCraftableIndex)
                end
            end
        else
            --mj:log("research not complete:", researchType.index)
            return false
        end
    end
    local sharedState = sapien.sharedState

    local assignedCount = skill:getAssignedRolesCount(sapien)
    if assignedCount >= skill.maxRoles then
        local skillsWithLowestLearnFraction = nil
        local lowestLearnFraction = 1.1

        for skillTypeIndex,v in pairs(sharedState.skillPriorities) do
            if v == 1 then
                local learnFraction = skill:fractionLearned(sapien, skillTypeIndex)
                if learnFraction < lowestLearnFraction then
                    skillsWithLowestLearnFraction = {
                        skillTypeIndex
                    }
                    lowestLearnFraction = learnFraction
                elseif learnFraction == lowestLearnFraction then
                    table.insert(skillsWithLowestLearnFraction, skillTypeIndex)
                end
            end
        end

        --mj:log("sapien " .. sapien.uniqueID .. "assigned 6 roles. Needs to unassign. sapien sharedState.skillPriorities:", sharedState.skillPrioritie, " skillsWithLowestLearnFraction:", skillsWithLowestLearnFraction)

        --mj:log("skillsWithLowestLearnFraction:", skillsWithLowestLearnFraction)

        if skillsWithLowestLearnFraction then
            local unassignSkillTypeIndex = skillsWithLowestLearnFraction[rng:randomInteger(#skillsWithLowestLearnFraction) + 1]
            --mj:log("auto role assignment:", sapien.uniqueID, " has been unassigned:", skill.types[unassignSkillTypeIndex].key)
            serverSapien:setSkillPriority(sapien, unassignSkillTypeIndex, 0)
        end
    end

    assignedCount = skill:getAssignedRolesCount(sapien)
    if assignedCount >= skill.maxRoles then --this is OK, and can happen. Sometimes, unassaigning can immediately get reassigned back again by plan objects. We'll just try again later.
        --error()
        mj:log("assignedCount >= skill.maxRoles")
        return false
    end

    serverSapien:setSkillPriority(sapien, assignSkillTypeIndex, 1)
    --mj:log("auto role assignment:", sapien.uniqueID, " has been assigned:", skill.types[assignSkillTypeIndex].key)

    serverWorld:addDelayTimerForAutoRoleAssignment(sapien.sharedState.tribeID, assignSkillTypeIndex)

    serverGOM:sendNotificationForObject(sapien, notification.types.autoRoleAssign.index, {
        skillTypeIndex = assignSkillTypeIndex
    }, sharedState.tribeID)

    return true
end


function serverSapien:getOwnerPlayerIsOnline(sapien)
    --mj:log("sapien.sharedState.tribeID:", sapien.sharedState.tribeID)
    --mj:log("clientID:", serverWorld:clientIDForTribeID(sapien.sharedState.tribeID))
    --mj:log("serverWorld.connectedClientIDSet:", serverWorld.connectedClientIDSet)
    return serverWorld.connectedClientIDSet[serverWorld:clientIDForTribeID(sapien.sharedState.tribeID)] ~= nil
end

function serverSapien:init(serverGOM_, serverWorld_, serverTribe_, serverDestination_, serverStorageArea_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    serverTribe = serverTribe_
    serverDestination = serverDestination_
    serverStorageArea = serverStorageArea_

   --[[ mj:log("female names:")
    for i = 1, 50 do
        local name = nameLists:generateName("a2b", 35 + i, true)
        mj:log(name)
    end
    mj:log("male names:")
    for i = 1, 50 do
        local name = nameLists:generateName("a2b", 1256 + i, false)
        mj:log(name)
    end]]

    serverGOM:addObjectLoadedFunctionForTypes({gameObject.typeIndexMap.sapien}, function(sapien)

        if loadDebugSapienID and sapien.uniqueID == loadDebugSapienID then
            serverWorld:setDebugObject(nil, loadDebugSapienID)
        end

        local sharedState = sapien.sharedState

        local destinationState = serverDestination:getDestinationState(sharedState.tribeID)
        if destinationState and destinationState.loadState == destination.loadStates.hibernating then --ambulance
            mj:warn("Preventing hibernating sapien from loading. This should stop happening in the future.")
            serverGOM:removeGameObject(sapien.uniqueID)
            return
        end

        local setKey = "tribe_" .. sharedState.tribeID
        if not serverGOM.objectSets[setKey] then
            serverGOM.objectSets[setKey] = serverGOM:createObjectSet(setKey)
        end
        serverGOM:addObjectToSet(sapien, serverGOM.objectSets[setKey])

        serverWorld:loadClientStateIfNeededForSapienTribeID(sharedState.tribeID)
        serverSapienSkills:updateTribeAllowedTaskListsForSapienLoaded(sapien)

        local function migrateState()
            if (not sapien.privateState.version) or sapien.privateState.version < serverSapien.sapienSaveStateVersion then
                if not sapien.privateState.version then -- <a29
                    local assignedRolesCount = skill:getAssignedRolesCount(sapien)
                    if assignedRolesCount > skill.maxRoles then
                        sharedState:set("skillPriorities", {})
                    end
                end
                
                if sapien.privateState.version < 2 then -- <a33
                    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
                    if unsavedState.temperatureZones[2] == weather.temperatureZones.veryCold.index then
                        serverSapienInventory:addObjectFromInventory(sapien, {objectTypeIndex = gameObject.types.alpacaWoolskin.index}, sapienInventory.locations.torso.index, nil)
                        serverSapien:updateTemperature(sapien)
                    end 
                end
        
                if sapien.privateState.version < 3 then -- <a43
                    sharedState:set("needs", need.types.music.index, 0)
                end

                if sapien.privateState.version < 4 then -- b21
                    local traitState = sharedState.traits
                    if traitState and #traitState < 2 then
                        if rng:randomInteger(4) == 1 then
                            local sapienTraitType = sapienTrait.types.immune
                            local traitTypeState = {
                                traitTypeIndex = sapienTraitType.index
                            }
                            if sapienTraitType.opposite then
                                if rng:randomBool() then
                                    traitTypeState.opposite = true
                                end
                            end
                            table.insert(traitState, traitTypeState)
                        end
                    end

                    
                    serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.virusImmunity.index, rng:randomValue() * (57600 * 2.0)) --give them all some immunity to ease into it
                end

                
        
                if sapien.privateState.version < 5 then -- <0.4
                    local existingBrickBuildingSkillState = sharedState.skillState[skill.types.brickBuilding.index]
                    if existingBrickBuildingSkillState then
                        local maxFraction = existingBrickBuildingSkillState.fractionComplete
                        local complete = existingBrickBuildingSkillState.complete
                        if sharedState.skillState[skill.types.mudBrickBuilding.index] then
                            local existingFraction = sharedState.skillState[skill.types.mudBrickBuilding.index].fractionComplete
                            local existingComplete = sharedState.skillState[skill.types.mudBrickBuilding.index].complete
                            if existingComplete then
                                existingFraction = 1.0
                            end
                            if not existingFraction then
                                existingFraction = 0.0
                            end

                            complete = complete or existingComplete
                            maxFraction = math.max(maxFraction, existingFraction)
                        end
                        sharedState:set("skillState", skill.types.mudBrickBuilding.index, "fractionComplete", maxFraction)
                        sharedState:set("skillState", skill.types.mudBrickBuilding.index, "complete", complete)

                        sharedState:remove("skillState", skill.types.brickBuilding.index)
                    end

                    if sharedState.skillPriorities[skill.types.brickBuilding.index] then
                        sharedState:remove("skillPriorities", skill.types.brickBuilding.index)
                        sharedState:set("skillPriorities", skill.types.mudBrickBuilding.index, 1)
                    end
                end
        
                sapien.privateState.version = serverSapien.sapienSaveStateVersion
            end
        end

        updateTemperatureZones(sapien)
        migrateState()


        local orderQueue = sharedState.orderQueue
        if orderQueue then
            local orderState = orderQueue[1]
            if orderState and orderState.orderTypeIndex == order.types.playInstrument.index and skill:hasSkill(sapien, skill.types.flutePlaying.index) then
                local actionState = sharedState.actionState
                if actionState and actionState.sequenceTypeIndex then
                    local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
                    if activeSequence.assignedTriggerIndex == actionState.progressIndex then
                        serverGOM:addObjectToSet(sapien, serverGOM.objectSets.musicPlayers)
                    end
                end
            end
        end
        
       

        local lazyPrivateState = sapien.lazyPrivateState
        if not lazyPrivateState then
            serverGOM:createLazyPrivateState(sapien)
            lazyPrivateState = sapien.lazyPrivateState
        end

        if not lazyPrivateState.conversations then
            lazyPrivateState.conversations = {}
        end
        if not lazyPrivateState.relationships then
            lazyPrivateState.relationships = {}
        end
        if not lazyPrivateState.ownershipState then
            lazyPrivateState.ownershipState = {}
        end

        serverGOM:addObjectToSet(sapien, serverGOM.objectSets.sapiens)
        serverGOM:addObjectToSet(sapien, serverGOM.objectSets.interestingToLookAt)
        serverGOM:addObjectToSet(sapien, serverGOM.objectSets.coveredStatusObservers)

        --[[if sharedState.nomad then
            serverGOM:addObjectToSet(sapien, serverGOM.objectSets.nomads)
        else
            serverGOM:addObjectToSet(sapien, serverGOM.objectSets.playerSapiens)
        end]]

        if sharedState.hasBaby then
            serverWorld:addToBabyCount(sharedState.tribeID, 1)
        end

        serverSapienAI:sapienLoaded(sapien)
        serverWorld:sapienLoaded(sapien)

        infrequentUpdateRandomWaits[sapien.uniqueID] = 0.5 + rng:randomValue()
        infrequentUpdateTimers[sapien.uniqueID] = 0.0
        infrequentUpdateLongerWaitCounters[sapien.uniqueID] = 0

        if not sharedState.nomad then
            for skillTypeIndex,v in pairs(sharedState.skillPriorities) do
                if v == 1 then
                    --mj:log("adding sapien object to set:", skill.types[skillTypeIndex].sapienSetIndex)
                    serverGOM:addObjectToSet(sapien, skill.types[skillTypeIndex].sapienSetIndex)
                end
            end
        end
        
        if sapien.privateState.logisticsInfo then
            serverLogistics:setSapienRouteAssignment(sapien.uniqueID, sapien.privateState.logisticsInfo.tribeID or sharedState.tribeID, sapien.privateState.logisticsInfo.routeID)
        end
        
        serverSapien:updateAnchor(sapien)
        
        return false
    end)

    serverGOM:addObjectUnloadedFunctionForTypes({gameObject.typeIndexMap.sapien}, function(sapien)
        serverSapienAI:sapienUnloaded(sapien)
        serverWorld:sapienUnLoaded(sapien)
        infrequentUpdateTimers[sapien.uniqueID] = nil
        infrequentUpdateRandomWaits[sapien.uniqueID] = nil
        infrequentUpdateLongerWaitCounters[sapien.uniqueID] = nil
        anchor:anchorObjectUnloaded(sapien.uniqueID)
    end)

    serverGOM:addObjectCoveredStatusChangedFunctionForType(gameObject.typeIndexMap.sapien, function(sapien)
        serverSapien:updateTemperature(sapien)
    end)

    local initObjects = {
        serverSapien = serverSapien,
        serverSapienAI = serverSapienAI,
        serverGOM = serverGOM, 
        serverWorld = serverWorld, 
        serverTribe = serverTribe_, 
        serverDestination = serverDestination,
        serverWeather = serverWeather,
        serverStorageArea = serverStorageArea,
        findOrderAI = findOrderAI,
        planManager = planManager,
    }

    serverSapienAI:init(initObjects)
    serverSapienInventory:init(initObjects)
    serverResourceManager:init(initObjects)

    local dayLength = serverWorld:getDayLength()
    serverSapien.pregnancySpeed = (1.0 / (dayLength * sapienConstants.pregnancyDurationDays))
    serverSapien.infantAgeSpeed = (1.0 / (dayLength * sapienConstants.infantDurationDays))
    serverSapien.pregnancyDelaySpeed = (1.0 / (dayLength * sapienConstants.minTimeBetweenPregnancyDays))

    for lifeStageIndex,lifeStageInfo in ipairs(sapienConstants.lifeStages) do
        serverSapien.ageSpeedsByLifeStage[lifeStageIndex] = (1.0 / (dayLength * lifeStageInfo.duration))
    end

    serverStatusEffects:init(serverGOM, serverSapien, planManager)
end

return serverSapien