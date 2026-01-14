local mjm = mjrequire "common/mjm"
local normalize = mjm.normalize
local dot = mjm.dot
local vec3 = mjm.vec3
local length = mjm.length
--local length2 = mjm.length2
local mat3LookAtInverse = mjm.mat3LookAtInverse
local mat3GetRow = mjm.mat3GetRow

local gameObject = mjrequire "common/gameObject"
local order = mjrequire "common/order"
local plan = mjrequire "common/plan"
local action = mjrequire "common/action"
local worldHelper = mjrequire "common/worldHelper"
local actionSequence = mjrequire "common/actionSequence"
local rng = mjrequire "common/randomNumberGenerator"
local physicsSets = mjrequire "common/physicsSets"
local resource = mjrequire "common/resource"
local pathFinding = mjrequire "common/pathFinding"
local statusEffect = mjrequire "common/statusEffect"
local gameConstants = mjrequire "common/gameConstants"
--local storage = mjrequire "common/storage"
--local tool = mjrequire "common/tool"
--local physics = mjrequire "common/physics"
--local constructable = mjrequire "common/constructable"
local skill = mjrequire "common/skill"
local sapienInventory = mjrequire "common/sapienInventory"
--local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
local desire = mjrequire "common/desire"
local need = mjrequire "common/need"
local mood = mjrequire "common/mood"
local sapienConstants = mjrequire "common/sapienConstants"
local research = mjrequire "common/research"
local lookAtIntents = mjrequire "common/lookAtIntents"

--local pathCreator = mjrequire "server/pathCreator"
--local serverSapienInventory = mjrequire "server/serverSapienInventory"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverWeather = mjrequire "server/serverWeather"

local findOrderLookAround = mjrequire "server/sapienAI/findOrderLookAround"
local startOrderAI = mjrequire "server/sapienAI/startOrderAI"
local lookAI = mjrequire "server/sapienAI/lookAI"


local serverSapienAI = nil
local serverGOM = nil
local serverWorld = nil
--local serverTribe = nil
local serverSapien = nil
local planManager = nil


local findOrderAI = {}



    
function findOrderAI:updateLookAtPosAndTurnAndFaceIfNeeded(sapien, pos, objectID, shouldSendTurnOrder)

    local sapienNormal = normalize(sapien.pos)
    local normalizedLookAtPos = normalize(pos)
    local distance = length(normalizedLookAtPos - sapienNormal)
    if distance > mj:mToP(0.5) then
        local direction = (normalizedLookAtPos - sapienNormal) / distance
        local currentDirection = mat3GetRow(sapien.rotation, 2)
        serverSapien:setLookAt(sapien, objectID, pos)
        if shouldSendTurnOrder and dot(direction, currentDirection) < 0.3 then
            if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                if serverSapienAI:addOrderIfAble(sapien, order.types.turn.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
                    local rotation = mat3LookAtInverse(direction, sapienNormal)
                    if mj:isNan(rotation.m0) then
                        mj:error("rotation is nan")
                        error()
                    end
                    if mjm.dot(mat3GetRow(rotation, 1), sapien.normalizedPos) < 0.99 then
                        mj:error("rotation is not up orientated. up:", mat3GetRow(rotation, 1), " sapien.normalizedPos:", sapien.normalizedPos, " direction:", direction)
                        error()
                    end
                    serverGOM:setRotation(sapien.uniqueID, rotation)
                    serverSapien:saveState(sapien)
                end
            end
        end
    end
end

function findOrderAI:addStatusEffectInfo(statusEffects, lookAroundInfo)
    if statusEffects then
        lookAroundInfo.isUnconcious = statusEffects[statusEffect.types.unconscious.index] ~= nil
    end
end


function findOrderAI:createLookAroundInfo(sapien, priorityObjectIDOrNil)
    local sharedState = sapien.sharedState
    local pathStuckLastAttemptTime = sharedState.pathStuckLastAttemptTime
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

        priorityObjectID = sharedState.haulingObjectID or priorityObjectIDOrNil or aiState.recentPlanObjectID or sharedState.lookAtObjectID,
        
        cantDoMostWorkDueToEffects = statusEffect:cantDoMostWorkDueToEffects(sharedState.statusEffects),

        hasActiveOrder = sharedState.orderQueue[1] ~= nil,

    }

    --[[if not lookAroundInfo.priorityObjectID then
        if lookAroundInfo.aiState.queuedPlanAnnouncementToLookAt then
            lookAroundInfo.priorityObjectID = lookAroundInfo.aiState.queuedPlanAnnouncementToLookAt.objectID
            lookAroundInfo.aiState.queuedPlanAnnouncementToLookAt = nil
        end
    end]]

    findOrderAI:addStatusEffectInfo(sharedState.statusEffects, lookAroundInfo)

    lookAroundInfo.cooldowns = mj:getOrCreate(lookAroundInfo.aiState, "cooldowns")

    lookAroundInfo.hasHeldObject = lookAroundInfo.heldObjectCount > 0

    if lookAroundInfo.hasHeldObject then
        local lastHeldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
        lookAroundInfo.lastHeldObjectInfo = lastHeldObjectInfo
        lookAroundInfo.heldObjectTypeIndex = lastHeldObjectInfo.objectTypeIndex
        
        if lastHeldObjectInfo.orderContext then
            lookAroundInfo.pickedUpObjectOrderTypeIndex = lastHeldObjectInfo.orderContext.orderTypeIndex
            lookAroundInfo.pickedUpObjectPlanState = lastHeldObjectInfo.orderContext.planState
            lookAroundInfo.pickedUpObjectPlanObjectID = lastHeldObjectInfo.orderContext.planObjectID
            lookAroundInfo.pickedUpObjectStorageAreaTransferInfo = lastHeldObjectInfo.orderContext.storageAreaTransferInfo
        end
    end
    
    local sapienViewDir = mat3GetRow(sapien.rotation, 2)

    lookAroundInfo.sapienViewDir = sapienViewDir
    lookAroundInfo.gazeEnd = sapien.pos + sapienViewDir * mj:mToP(500.0)

    return lookAroundInfo
end

function findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, doEvenWhenMildDesire, completeActionIfAble)
    --disabled--mj:objectLog(sapien.uniqueID, "checkShouldDoSelfActionWithInventory doEvenWhenMildDesire:", doEvenWhenMildDesire, " lookAroundInfo.hasHeldObject:", lookAroundInfo.hasHeldObject)
    if lookAroundInfo.hasHeldObject then

        --disabled--mj:objectLog(sapien.uniqueID, " lastHeldObjectInfo:", lookAroundInfo.lastHeldObjectInfo)

        
        local function getCanDoWork()
            local canDoWork = true
            if lookAroundInfo.isStuck or sapien.sharedState.waitOrderSet or lookAroundInfo.isUnconcious then
                canDoWork = false
            elseif lookAroundInfo.sleepDesire >= desire.levels.strong then
                canDoWork = false
            elseif lookAroundInfo.foodDesire >= desire.levels.strong then
                canDoWork = false
            end
            return canDoWork
        end

        local hasExistingPlanForHeldObject = false
        local orderContext = lookAroundInfo.lastHeldObjectInfo.orderContext
        if orderContext and orderContext.planState then
            local planTypeIndex = orderContext.planState.planTypeIndex


            if planTypeIndex == plan.types.research.index and orderContext.planState.researchTypeIndex then
                if skill:isAllowedToDoTasks(sapien, skill.types.researching.index) then
                    if getCanDoWork() then
                        local researchType = research.types[orderContext.planState.researchTypeIndex]
                        if researchType.heldObjectOrderTypeIndex then
                            if completeActionIfAble then
                                return serverSapienAI:addOrderToPlayHeldItem(sapien, sapienInventory.locations.held.index, orderContext) --todo this assumes too much
                            end
                            return true
                        end
                    end
                end
            end
            
            if planTypeIndex == plan.types.playInstrument.index then
                if skill:isAllowedToDoTasks(sapien, skill.types.flutePlaying.index) then
                    if getCanDoWork() then
                        if completeActionIfAble then
                            return serverSapienAI:addOrderToPlayHeldItem(sapien, sapienInventory.locations.held.index, orderContext)
                        end
                        return true
                    end
                end
            end

            if planTypeIndex ~= plan.types.storeObject.index then
                --disabled--mj:objectLog(sapien.uniqueID, "checkShouldDoSelfActionWithInventory held object plan:", planTypeIndex)
                hasExistingPlanForHeldObject = true
            end
        end

        
        --disabled--mj:objectLog(sapien.uniqueID, " lookAroundInfo.musicDesire:", lookAroundInfo.musicDesire)
        if lookAroundInfo.musicDesire >= desire.levels.moderate then
            --disabled--mj:objectLog(sapien.uniqueID, " music desire moderate or above")
            if getCanDoWork() then
           -- if lookAroundInfo.restDesire <= desire.levels.mild then
                ----disabled--mj:objectLog(sapien.uniqueID, " restDesire <= desire.levels.mild")
                local musicalInstrumentSkillTypeIndex = resource.types[gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex].musicalInstrumentSkillTypeIndex
                if musicalInstrumentSkillTypeIndex then
                    --disabled--mj:objectLog(sapien.uniqueID, "musicalInstrumentSkillTypeIndex")
                    if skill:isAllowedToDoTasks(sapien, musicalInstrumentSkillTypeIndex) then
                        --disabled--mj:objectLog(sapien.uniqueID, "isAllowedToDoTasks")
                        if completeActionIfAble then
                            return serverSapienAI:addOrderToPlayHeldItem(sapien, sapienInventory.locations.held.index, orderContext)
                        end
                        return true
                    end
                end
            end
            --end
        end

        if lookAroundInfo.foodDesire >= desire.levels.mild then
            local foodValue = resource.types[gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex].foodValue
            if foodValue then

                if hasExistingPlanForHeldObject then
                    return false
                end
                
                --disabled--mj:objectLog(sapien.uniqueID, "checkShouldDoSelfActionWithInventory returning true")
                if completeActionIfAble then
                    if serverSapienAI:addOrderToEatHeldItem(sapien) then
                        return true
                    end
                    return false
                end
                return true
            end
        end
        
        local sharedState = sapien.sharedState
        if sharedState.statusEffects[statusEffect.types.veryCold.index] or sharedState.statusEffects[statusEffect.types.cold.index] then
            local clothingInventoryLocation = resource.types[gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex].clothingInventoryLocation
            if clothingInventoryLocation then
                if hasExistingPlanForHeldObject then
                    return false
                end
                
                if sapienInventory:objectCount(sapien, clothingInventoryLocation) ~= 0 then
                    return false
                end

                if completeActionIfAble then
                    return serverSapienAI:addOrderToPutOnHeldItem(sapien, clothingInventoryLocation)
                end
                return true
            end
        end
    else
        local sharedState = sapien.sharedState
        if sharedState.statusEffects[statusEffect.types.veryHot.index] or sharedState.statusEffects[statusEffect.types.hot.index] then
            local hasCloak = sapienInventory:objectCount(sapien, sapienInventory.locations.torso.index) ~= 0

            if hasCloak then
                if completeActionIfAble then
                    return serverSapienAI:addOrderToRemoveClothingItem(sapien, sapienInventory.locations.torso.index)
                end
                return true
            end
        end
    end
    return false
end



function findOrderAI:getResourceInfoForFetch(sapien, maxLookDistanceMetersOrNil, fetchObjectTypeIndexes, allowGather)
    local maxLookDistance2 = nil
    if maxLookDistanceMetersOrNil then
        maxLookDistance2 = mj:mToP(maxLookDistanceMetersOrNil) * mj:mToP(maxLookDistanceMetersOrNil)
    end
    local allowStockpiles = true
    -- vvv commented out 10/25, probably not necessary, why can't nomads use storage areas again?
   --[[ if sapien.sharedState.nomad then
        local tribeState = serverTribe:getTribeState(sapien.sharedState.tribeID)
        if tribeState and tribeState.nomadState.tribeBehaviorTypeIndex ~= nomadTribeBehavior.types.foodRaid.index then
            allowStockpiles = false
        end
    end]]
    local resourceInfo = serverResourceManager:findResourceForSapien(sapien, fetchObjectTypeIndexes, {
        allowStockpiles = allowStockpiles,
        allowGather = allowGather,
        maxDistance2 = maxLookDistance2,
        takePriorityOverStoreOrders = true,
    })

    --disabled--mj:objectLog(sapien.uniqueID, "finalizeFetchOrder resourceInfo:", resourceInfo)
    
    if resourceInfo then
        if (not maxLookDistance2) or resourceInfo.distance2 < maxLookDistance2 then
            return resourceInfo
        end
    end
    return nil
end

local function addAutomaticNearbyFoodGatherPlanIfNeeded(sapien, privateState)
    --mj:log("addAutomaticNearbyFoodGatherPlanIfNeeded:", sapien.uniqueID, " privateState.addFoodGatherOrderDelayTimer:", privateState.addFoodGatherOrderDelayTimer)
    if (not privateState.addFoodGatherOrderDelayTimer) or (serverWorld:getWorldTime() > privateState.addFoodGatherOrderDelayTimer) then
        local foodDesire = desire:getDesire(sapien, need.types.food.index, false)
        --mj:log("foodDesire:", foodDesire)
        if foodDesire >= desire.levels.severe then
            privateState.addFoodGatherOrderDelayTimer = serverWorld:getWorldTime() + 30.0 + rng:randomValue() * 30.0
            local radius =  mj:mToP(20.0)

            local closeGatherableFood = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.aiTribeGatherableFood, sapien.pos, radius)
            --mj:log("closeGatherableFood:", closeGatherableFood)
            if closeGatherableFood and #closeGatherableFood > 0 then
                local randomInfo = closeGatherableFood[rng:randomInteger(#closeGatherableFood) + 1]
                local gatherObjectTypeIndex = nil
                local object = serverGOM:getObjectWithID(randomInfo.objectID)
                local sharedState = object.sharedState
                if (not sharedState.tribeID) or sharedState.tribeID == sapien.sharedState.tribeID then
                    local inventory = sharedState.inventory
                    if inventory then
                        local countsByObjectType = inventory.countsByObjectType
                        if countsByObjectType then
                            local gatherableTypes = gameObject.types[object.objectTypeIndex].gatherableTypes
                            if gatherableTypes then
                                for j,objectTypeIndex in ipairs(gatherableTypes) do
                                    if countsByObjectType[objectTypeIndex] and countsByObjectType[objectTypeIndex] > 0 then
                                        local resourceType = resource.types[gameObject.types[objectTypeIndex].resourceTypeIndex]
                                        local eatingBlocked = false
                                        local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(sapien.sharedState.tribeID)
                                        if resourceBlockLists then
                                            local eatFoodBlockList = resourceBlockLists.eatFoodList
                                            if eatFoodBlockList and eatFoodBlockList[objectTypeIndex] then
                                                eatingBlocked = true
                                            end
                                        end
                                        if resourceType.foodValue and (not eatingBlocked) then
                                            gatherObjectTypeIndex = objectTypeIndex
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    --mj:log("gatherObjectTypeIndex:", gatherObjectTypeIndex)
                    if gatherObjectTypeIndex then
                        planManager:addPlans(sapien.sharedState.tribeID, {
                            planTypeIndex = plan.types.gather.index,
                            objectTypeIndex = gatherObjectTypeIndex,
                            objectOrVertIDs = {randomInfo.objectID},
                            frontOfTheQueue = true, --prioritize/topOfTheQueue is not yet supported on creation like this for all plan types, but works for gather plans here
                            supressStoreOrders = true, --this is currently only supported by plans that get added via addPlanState()
                        })
                        return true
                    end
                end
            end
        end
    end
    return false
end

function findOrderAI:resourceInfoAndIntentIfShouldGatherSelfRequiredItem(sapien, lookAroundInfo)
    --disabled--mj:objectLog(sapien.uniqueID, "check shouldGatherSelfRequiredItem to eat/wear/use")--, lookAroundInfo)
    
    if lookAroundInfo.isStuck or sapien.sharedState.waitOrderSet then
        return nil
    end

        
    local sharedState = sapien.sharedState

    if lookAroundInfo.foodDesire >= desire.levels.mild then

        local maxLookDistanceMeters = nil
        local allowGather = false
        local findFood = false
        if lookAroundInfo.foodDesire >= desire.levels.severe then
            maxLookDistanceMeters = nil
            findFood = true
        elseif lookAroundInfo.foodDesire >= desire.levels.strong then
            maxLookDistanceMeters = 100.0
            findFood = true
        elseif lookAroundInfo.foodDesire >= desire.levels.moderate then
            maxLookDistanceMeters = 50.0
            findFood = true
        else
            if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                if lookAroundInfo.aiState.lastAteTime and serverWorld:getWorldTime() - lookAroundInfo.aiState.lastAteTime < 30.0 then --lets call this a meal
                    findFood = true
                    maxLookDistanceMeters = 20.0
                end
            end
        end

        if findFood then
            --mj:log("find food:", sapien.uniqueID)
            --disabled--mj:objectLog(sapien.uniqueID, "findFood maxLookDistanceMeters:", maxLookDistanceMeters)
            local foodTypeIndexes = serverWorld:getNonBlockedFoodObjectTypes(sapien.sharedState.tribeID)

            local resourceInfo = findOrderAI:getResourceInfoForFetch(sapien, maxLookDistanceMeters, foodTypeIndexes, allowGather)
            if resourceInfo then
                return {
                    resourceInfo = resourceInfo,
                    lookAtIntent = lookAtIntents.types.eat.index,
                }
            end

            addAutomaticNearbyFoodGatherPlanIfNeeded(sapien, sapien.privateState)
        end
    end
    
    if lookAroundInfo.sleepDesire < desire.levels.strong then

        if sharedState.statusEffects[statusEffect.types.veryCold.index] or sharedState.statusEffects[statusEffect.types.cold.index] then
            local maxLookDistanceMeters = 200.0
            if sharedState.statusEffects[statusEffect.types.veryCold.index] then
                maxLookDistanceMeters = nil
            end
            --disabled--mj:objectLog(sapien.uniqueID, "findClothing maxLookDistanceMeters:", maxLookDistanceMeters)

            local allowedLocations = {}

            if sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.torso.index) == nil then
                table.insert(allowedLocations, sapienInventory.locations.torso.index)
            end

            if allowedLocations[1] then
                
                local clothingTypeIndexes = serverWorld:getNonBlockedClothingTypesForInventoryLocations(sapien.sharedState.tribeID, allowedLocations)
                if not (clothingTypeIndexes and next(clothingTypeIndexes)) then
                    return nil
                end

                local resourceInfo = findOrderAI:getResourceInfoForFetch(sapien, maxLookDistanceMeters, clothingTypeIndexes, true)
                if resourceInfo then
                    --disabled--mj:objectLog(sapien.uniqueID, "resourceInfo:", resourceInfo)
                    return {
                        resourceInfo = resourceInfo,
                        lookAtIntent = lookAtIntents.types.putOnClothing.index,
                    }
                end
            end
        end
    end
    return nil
end


--[[local function resourceInfoAndIntentIfShouldGatherSelfRecreationItem(sapien, lookAroundInfo)
    --disabled--mj:objectLog(sapien.uniqueID, "check resourceInfoAndIntentIfShouldGatherSelfRecreationItem")
    
    if lookAroundInfo.isStuck or sapien.sharedState.waitOrderSet then
        return nil
    end

    if lookAroundInfo.sleepDesire < desire.levels.strong then
        if skill:isAllowedToDoTasks(sapien, skill.types.flutePlaying.index) then
            local maxLookDistanceMeters = 50.0
            local allowGather = false

            local objectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resource.types.boneFlute.index] --todo probably need an instrument.lua, to access object types by skill
            local resourceInfo = getResourceInfoForFetch(maxLookDistanceMeters, objectTypeIndexes, allowGather)
            if resourceInfo then
                return {
                    resourceInfo = resourceInfo,
                    lookAtIntent = lookAtIntents.types.play.index,
                }
            end
        end
    end
    return nil
end]]

function findOrderAI:checkDropObjectBeforeLooking(sapien, lookAroundInfo)
    if lookAroundInfo.hasHeldObject then
        if not sapien.sharedState.manualAssignedPlanObject then
            local resourceTypeIndex = gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex
            local allowsCarry = serverSapienAI:checkNeedsAllowObjectTypeToBeCarried(resourceTypeIndex, lookAroundInfo.foodDesire, lookAroundInfo.restDesire, lookAroundInfo.sleepDesire, lookAroundInfo.happySadMood)
            if not allowsCarry then
                return true
            end
        end
    end
    return false
end


function findOrderAI:findMultitask(sapien)
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:findMultitask")
    local sharedState = sapien.sharedState
    local orderState = sharedState.orderQueue[1]
    if orderState and sharedState.actionState then
        --local orderTypeIndex = orderState.orderTypeIndex
        --local orderTypeInfo = order.types[orderTypeIndex]
        
        local actionState = sharedState.actionState
        local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
        local currentActionTypeIndex = activeSequence.actions[actionState.progressIndex]

        if currentActionTypeIndex and (not action.types[currentActionTypeIndex].preventMultitask) then
            
            if action.types[currentActionTypeIndex].allowMoreFrequentMultitasks or rng:randomInteger(4) == 1 then
                local lookAroundInfo = findOrderAI:createLookAroundInfo(sapien, nil)
                local lookAroundResult = findOrderLookAround:lookAroundForMultitask(sapien, lookAroundInfo, orderState, currentActionTypeIndex)
                ----disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:findMultitask - lookAroundResult:", lookAroundResult)
                if lookAroundResult and lookAroundResult.bestObjectInfo then
                    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:findMultitask - lookAroundResult.bestObjectInfo, intent:", lookAroundResult.bestObjectInfo.lookAtIntent)

                    return lookAroundResult.bestObjectInfo
                end
            end
        end
    end
    return nil
end

local function autoExtendIntentMatches(currentOrderObjectID, lookAtObjectID, currentOrderTypeIndex, lookAtIntent)

    if (not lookAtIntent) or (not lookAtObjectID) then
        return true
    end

    if not currentOrderObjectID then
        if currentOrderTypeIndex == order.types.sit.index then
            if lookAtIntent == lookAtIntents.types.restNear.index or 
            lookAtIntent == lookAtIntents.types.social.index then
                return true
            end
        end
    else
        if currentOrderTypeIndex == order.types.sit.index then
            if lookAtIntent == lookAtIntents.types.restOn.index and lookAtObjectID == currentOrderObjectID then
                return true
            end
            if lookAtIntent == lookAtIntents.types.restNear.index then
                return true
            end
        else
            if lookAtObjectID == currentOrderObjectID then
                return true
            end
        end
    end

    return false
end

--[[

        local sharedState = sapien.sharedState
        local orderState = sharedState.orderQueue[1]
        if orderState then
            --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:canAutoExtendCurrentOrder has orderState:", orderState)
            if orderState.objectID and orderState.context and orderState.context.planTypeIndex then
                local orderObject = serverGOM:getObjectWithID(orderState.objectID)
                if orderObject then
                    local planState = planManager:getPlanStateForObjectForSapienForPlanType(orderObject, sapien, orderState.context.planTypeIndex)
                    if planState then
                        --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:canAutoExtendCurrentOrder found planState:", planState)
                        local orderAssignInfo = createOrderAssignInfo(sapien, orderObject, planState, orderState.context.planTypeIndex)
                        local orderInfo = createOrderInfo(sapien, orderObject, orderAssignInfo)
                        --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:canAutoExtendCurrentOrder generated orderInfo:", orderInfo)
                        if (not orderInfo) or orderInfo.orderTypeIndex ~= orderState.orderTypeIndex then
                            --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:canAutoExtendCurrentOrder returning false")
                            return false
                        end
                    else
                        return false
                    end
                else
                    return false
                end
            end
        end
        return true
]]

function findOrderAI:checkAutoExtendCurrentOrder(sapien)
    local sharedState = sapien.sharedState
    local orderState = sharedState.orderQueue[1]
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder orderState:", orderState)
    if orderState then

        if orderState.orderTypeIndex == order.types.pickupObject.index then --todo make this more general
            local planObjectID = orderState.context and orderState.context.planObjectID
            if planObjectID and planObjectID ~= orderState.objectID then
                return {
                    canExtend = true,
                    shouldActOnLookAtObject = serverGOM:getObjectWithID(planObjectID)
                } 
            end
        end

        local currentOrderTypeIndex = orderState.orderTypeIndex
        local currentOrderTypeInfo = order.types[currentOrderTypeIndex]
        --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder currentOrderTypeInfo:", currentOrderTypeInfo)
        if currentOrderTypeInfo.autoExtend or currentOrderTypeInfo.autoExtendReplaceOrder then
            --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder - currentOrderTypeInfo.autoExtend")

            local currentOrderObjectID = orderState.objectID
            local lookAroundInfo = findOrderAI:createLookAroundInfo(sapien, currentOrderObjectID)

            local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
            if findOrderAI:doHighPrioritySelfPlansIfNeeded(sapien, lookAroundInfo, unsavedState) then
                return nil
            end

            if findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, true, false) then
                if currentOrderTypeIndex == order.types.playInstrument.index then --bit of a hack, may cause problems eg if there is an edible instrument added
                    return {
                        canExtend = true,
                        replaceOrder = currentOrderTypeInfo.autoExtendReplaceOrder
                    }
                end
                return nil
            end
            
            if currentOrderTypeIndex == order.types.playInstrument.index then
                if lookAroundInfo.musicDesire == desire.levels.none then
                    return nil
                end
            end

            local orderContext = orderState.context
            if sharedState.manualAssignedPlanObject and (sharedState.manualAssignedPlanObject == orderState.objectID or (orderContext and sharedState.manualAssignedPlanObject == orderContext.planObjectID)) then
                return {
                    canExtend = true,
                    replaceOrder = currentOrderTypeInfo.autoExtendReplaceOrder
                } 
            end

            local autoExtendCheckDelayCount = currentOrderTypeInfo.autoExtendCheckDelayCount or 8

            unsavedState.autoCheckDelayCounter = (unsavedState.autoCheckDelayCounter or 0) + 1
            if unsavedState.autoCheckDelayCounter < autoExtendCheckDelayCount then
                return {
                    canExtend = true,
                }
            end

            unsavedState.autoCheckDelayCounter = 0

            if not unsavedState.preventUnnecessaryAutomaticOrderTimer and (not lookAroundInfo.isUnconcious) then
                local resourceInfoAnIntent = findOrderAI:resourceInfoAndIntentIfShouldGatherSelfRequiredItem(sapien, lookAroundInfo)
                if resourceInfoAnIntent then
                    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder - not extended due to selfRequiredItem (food/clothing):", resourceInfoAnIntent)
                    return nil
                end
                
                if statusEffect:hasEffect(sharedState, statusEffect.types.veryCold.index) then --alow them to move to a warmer place
                    if currentOrderTypeIndex ~= order.types.light.index then
                        local allObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.temperatureIncreasers, sapien.pos, serverSapienAI.maxWarmthSeakDistance)
                        for i,info in ipairs(allObjectInfos) do
                            if info.distance2 < serverSapienAI.maxWarmthSeakDistance then
                                --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder - not extended due to being very cold, and warm place near by")
                                return nil
                            end
                        end
                    end
                end
            end

            if lookAroundInfo.sleepDesire >= desire.levels.strong then
                --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder - not extended due to sleepDesire:", lookAroundInfo.sleepDesire)
                return nil
            end

            if currentOrderTypeIndex == order.types.sit.index then
                if ((sapien.privateState.gettingWetTimer ~= nil) or serverWeather:getIsDamagingWindStormOccuring()) and (not sharedState.covered) then
                    return nil
                end
            end

            if not currentOrderTypeInfo.allowCancellationDueToNewIncomingLookedAtOrder then
                if lookAroundInfo.cantDoMostWorkDueToEffects then
                    return nil
                end
                return {
                    canExtend = true,
                    replaceOrder = currentOrderTypeInfo.autoExtendReplaceOrder
                }
            end

            local lookAroundResult = findOrderLookAround:lookAroundForAutoExtend(sapien, lookAroundInfo, orderState, currentOrderTypeInfo.allowCancellationDueToNewIncomingLookedAtOrder)
            ----disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:canAutoExtendCurrentOrder - lookAroundResult:", lookAroundResult)

            local lookAtObjectID = nil
            local lookAtIntent = nil
            if lookAroundResult and lookAroundResult.bestObjectInfo then
                lookAtObjectID = lookAroundResult.bestObjectInfo.uniqueID
                lookAtIntent = lookAroundResult.bestObjectInfo.lookAtIntent
            end
    
            if findOrderAI:doLowPrioritySelfPlansIfNeeded(sapien, lookAroundInfo, unsavedState, lookAroundResult) then
                return nil
            end
            
            if autoExtendIntentMatches(currentOrderObjectID, lookAtObjectID, currentOrderTypeIndex, lookAtIntent) then
                return {
                    canExtend = true,
                    replaceOrder = currentOrderTypeInfo.autoExtendReplaceOrder
                }
            end
            
            return {
                canExtend = false,
                bestResult = lookAroundResult
            }

            --[[if (not lookAroundResult) and (not orderObjectID) then
                return true
            end]]
        end
    end
    return nil
end

function findOrderAI:checkForMatchingHeldObjectDisposalForCurrentOrder(sapien)
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:checkForMatchingHeldObjectDisposalForCurrentOrder")

    local sharedState = sapien.sharedState
    local orderState = sharedState.orderQueue[1]
    if orderState then
        local currentOrderObjectID = orderState.objectID
        if currentOrderObjectID then
            local lookAroundInfo = findOrderAI:createLookAroundInfo(sapien, currentOrderObjectID)
            local lookAroundResult = findOrderLookAround:getResultForHeldObjectDisposal(sapien, lookAroundInfo)
            --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:checkForMatchingHeldObjectDisposalForCurrentOrder lookAroundResult:", lookAroundResult)
            --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:checkForMatchingHeldObjectDisposalForCurrentOrder currentOrderObjectID:", currentOrderObjectID)
            if lookAroundResult and lookAroundResult.bestObjectInfo then
                return lookAroundResult.bestObjectInfo.uniqueID == currentOrderObjectID
            end
        end
    end
    return true
end

function findOrderAI:doHighPrioritySelfPlansIfNeeded(sapien, lookAroundInfo, unsavedState)
    if not unsavedState.preventUnnecessaryAutomaticOrderTimer and (not lookAroundInfo.isUnconcious) and (not sapien.sharedState.manualAssignedPlanObject) then
        local resourceInfoAnIntent = findOrderAI:resourceInfoAndIntentIfShouldGatherSelfRequiredItem(sapien, lookAroundInfo)
        if resourceInfoAnIntent then
            if not lookAroundInfo.hasHeldObject then
                --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doHighPrioritySelfPlansIfNeeded not hasHeldObject serverSapienAI: SelfRequiredItem.resourceInfo:", resourceInfoAnIntent)
            
                if serverSapienAI:addOrderToFetchResource(sapien, resourceInfoAnIntent.resourceInfo, 1, nil, nil, resourceInfoAnIntent.lookAtIntent) then
                    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doHighPrioritySelfPlansIfNeeded serverSapienAI:addOrderToFetchResource for use on self (eat/put on/etc):", resourceInfoAnIntent)
                    return true
                end
            else
                if findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, true, true) then
                    return true
                end
                --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doHighPrioritySelfPlansIfNeeded hasHeldObject, adding drop order serverSapienAI: foodCheckResult.resourceInfo:", resourceInfoAnIntent)
                if serverSapienAI:addOrderIfAble(sapien, order.types.dropObject.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
                    return true
                end
            end
        end

        
        if statusEffect:hasEffect(sapien.sharedState, statusEffect.types.veryCold.index) then
            if serverSapienAI:addOrderToMoveNearWarmth(sapien) then
                --mj:log("addOrderToMoveNearLight success:", sapien.uniqueID)
                --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doHighPrioritySelfPlansIfNeeded added addOrderToMoveNearWarmth")
                return true
            end
        end
    end
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doHighPrioritySelfPlansIfNeeded returning false")
    return false
end

function findOrderAI:doLowPrioritySelfPlansIfNeeded(sapien, lookAroundInfo, unsavedState, lookAroundResult)

    local aiState = lookAroundInfo.aiState
    if aiState.closestThreatSapien and aiState.closestThreatSapienDistance < gameConstants.lowPrioritySelfPlanThreatDistance then
        --disabled--mj:objectLog(sapien.uniqueID, "returning early from findOrderAI:doLowPrioritySelfPlansIfNeeded due to threat proximity")
        return
    end

    if not unsavedState.preventUnnecessaryAutomaticOrderTimer then

        
        local function alreadyMovingOrDoingOrder(orderTypeIndexOrNil)
            local orderState = sapien.sharedState.orderQueue[1]
            --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded orderState:", orderState)
            if orderState then
                if orderTypeIndexOrNil and orderState.orderTypeIndex == orderTypeIndexOrNil then
                    return true
                end
                if orderState.context and orderState.context.moveToMotivation then
                    return true
                end
            end
            return false
        end

        if lookAroundInfo.sleepDesire >= desire.levels.strong and not lookAroundInfo.hasHeldObject then
            if (not lookAroundResult.bestObjectInfo) or lookAroundResult.bestObjectInfo.lookAtIntent ~= lookAtIntents.types.sleep.index then
                if not alreadyMovingOrDoingOrder(order.types.sleep.index) then
                    if serverSapienAI:addOrderToFindPlaceOnGroundToSleep(sapien, nil) then
                        --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded addOrderToFindPlaceOnGroundToSleep due to sleep need")
                        return true
                    end
                    if serverSapienAI:addOrderIfAble(sapien, order.types.sleep.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
                        --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded serverSapienAI:addOrderIfAble(sapien, order.types.sleep.index)")
                        return true
                    end
                end
                mj:log("attempt to sleep but failed")
            end
        end
  
        if statusEffect:hasEffect(sapien.sharedState, statusEffect.types.inDarkness.index) then
            --mj:log("inDarkness:", sapien.uniqueID)
            if ((not lookAroundResult.bestObjectInfo) or 
            lookAroundResult.bestObjectInfo.lookAtIntent == lookAtIntents.types.social.index or 
            lookAroundResult.bestObjectInfo.lookAtIntent == lookAtIntents.types.restNear.index or 
            lookAroundResult.bestObjectInfo.lookAtIntent == lookAtIntents.types.restOn.index) then
                -- mj:log("calling addOrderToMoveNearLight:", sapien.uniqueID)
                if not alreadyMovingOrDoingOrder(nil) then
                    if serverSapienAI:addOrderToMoveNearLight(sapien) then
                        --mj:log("addOrderToMoveNearLight success:", sapien.uniqueID)
                        --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded added addOrderToMoveNearLight")
                        return true
                    end
                end
            end
        end

        --[[mj:log("a")
        if (not lookAroundResult.bestObjectInfo) and lookAroundInfo.restDesire < desire.levels.moderate and (not lookAroundInfo.hasHeldObject) then
            mj:log("b")
            local resourceInfoAnIntent = resourceInfoAndIntentIfShouldGatherSelfRecreationItem(sapien, lookAroundInfo)
            if resourceInfoAnIntent then
                mj:log("c")
                if serverSapienAI:addOrderToFetchResource(sapien, resourceInfoAnIntent.resourceInfo, 1, nil, nil, resourceInfoAnIntent.lookAtIntent) then
                    mj:log("d")
                    --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:addOrderToFetchResource for recreation:", resourceInfoAnIntent)
                    return true
                end
            end
        end]]

        --if not covered and getting wet, move. Even if sitting. But only to a covered location
        
        if (not lookAroundResult.bestObjectInfo) and (not lookAroundInfo.hasHeldObject) and (not lookAroundResult.generalMoveDirection) then --and (sharedState.resting or lookAroundInfo.restDesire >= desire.levels.moderate) -- check for rest need was removed in beta 6. Let's just sit
            if ((sapien.privateState.gettingWetTimer ~= nil) or serverWeather:getIsDamagingWindStormOccuring()) and (not sapien.sharedState.covered) then
                if not alreadyMovingOrDoingOrder(nil) then
                    if serverSapienAI:addOrderToFindPlaceNearByToSit(sapien, sapien.pos, nil, true, true) then
                        --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded added order to sit somewhere dry due to doing nothing important, and getting wet")
                        return true
                    end
                end
            end
            if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                if not alreadyMovingOrDoingOrder(order.types.sit.index) then
                    if lookAI:checkIsTooColdAndBusyWarmingUp(sapien) then
                        local cancelCurrentOrders = true
                        local orderContext = nil
                        --disabled--mj:objectLog("findOrderAI:doLowPrioritySelfPlansIfNeeded add sit order")
                        serverSapien:addOrder(sapien, order.types.sit.index, nil, nil, orderContext, cancelCurrentOrders)
                    else
                        if serverSapienAI:addOrderToFindPlaceNearByToSit(sapien, sapien.pos, nil, false, true) then
                            --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded added OrderToFindPlaceNearByToSit due to doing nothing important")
                            return true
                        end
                    end
                end
            end
        end
    end
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:doLowPrioritySelfPlansIfNeeded returning false")
    return false
end

--[[function findOrderAI:checkAutoAssignRoleForNearbyPlansWithTooDistantState(sapien) --started this, probably not right solution
    local allClosePlanObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.plans, sapien.pos, mj:mToP(20.0))
end]]

function findOrderAI:checkPlans(sapien, dt)
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:checkPlans")
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    if unsavedState.waitingForPathID then
        return nil
    end

    if unsavedState.preventUnnecessaryAutomaticOrderTimer then
        local newCounter = unsavedState.preventUnnecessaryAutomaticOrderTimer - dt
        if newCounter <= 0 then
            unsavedState.preventUnnecessaryAutomaticOrderTimer = nil
        else
            unsavedState.preventUnnecessaryAutomaticOrderTimer = newCounter
        end
    end


    local lookAroundInfo = findOrderAI:createLookAroundInfo(sapien, nil)

    if findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, false, true) then
        return nil
    end

    local sharedState = sapien.sharedState

    
    if unsavedState.preventUnnecessaryAutomaticOrderTimer and (not lookAroundInfo.isUnconcious) then --todo if this works out, remove the check elsewhere
        --disabled--mj:objectLog(sapien.uniqueID, "unsavedState.preventUnnecessaryAutomaticOrderTimer is set. exiting early from checkPlans")
        findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, true, true)
        return nil
    end

    local aiState = lookAroundInfo.aiState

    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:infrequentUpdate a")
    
    if findOrderAI:checkDropObjectBeforeLooking(sapien, lookAroundInfo) then
        if serverSapienAI:addOrderIfAble(sapien, order.types.dropObject.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
            return nil
        end
    end
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:infrequentUpdate b")
    
    local preventSleepDueToManualObject = false
    if sharedState.manualAssignedPlanObject and sharedState.manualAssignedPlanObjectPreventSleepUntilTime then
        if sharedState.manualAssignedPlanObjectPreventSleepUntilTime > serverWorld:getWorldTime() then
            preventSleepDueToManualObject = true
        else
            sharedState:remove("manualAssignedPlanObjectPreventSleepUntilTime")
        end
    end

    if (not preventSleepDueToManualObject) then
        if findOrderAI:doHighPrioritySelfPlansIfNeeded(sapien, lookAroundInfo, unsavedState) then
            return nil
        end
        --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:infrequentUpdate c")
        
        if lookAroundInfo.sleepDesire >= desire.levels.strong then
            if lookAroundInfo.hasHeldObject then
                if serverSapienAI:addOrderIfAble(sapien, order.types.dropObject.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
                    --disabled--mj:objectLog(sapien.uniqueID, "dropping object due to sleep need")
                    return nil
                end
            end
        end
    end
    

    if lookAroundInfo.isStuck or sharedState.waitOrderSet or lookAroundInfo.isUnconcious then
        if lookAroundInfo.sleepDesire >= desire.levels.strong and not lookAroundInfo.hasHeldObject then
            if serverSapienAI:addOrderIfAble(sapien, order.types.sleep.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
                --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:addOrderIfAble(sapien, order.types.sleep.index)")
                return nil
            end
        end
        if findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, true, true) then
            return nil
        end
        --disabled--mj:objectLog(sapien.uniqueID, "lookAroundInfo.isStuck or waitOrderSet. returning from checkPlans")
        return nil
    end
    
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:infrequentUpdate d")

    if aiState.currentLookAtObjectInfo then
        --disabled--mj:objectLog(sapien.uniqueID, "calling startOrderAI:actOnLookAtObject")-- due to aiState.currentLookAtObjectInfo:", aiState.currentLookAtObjectInfo)
        if startOrderAI:actOnLookAtObject(sapien) then
            return nil
        end

        aiState.currentLookAtObjectInfo = nil
        return nil
    end


    local lookAroundResult = findOrderLookAround:lookAround(sapien, lookAroundInfo)
    --disabled--mj:objectLog(sapien.uniqueID, "unsavedState.preventUnnecessaryAutomaticOrderTimer:", unsavedState.preventUnnecessaryAutomaticOrderTimer)

    if sharedState.manualAssignedPlanObject then --findOrderLookAround needs to sort this out in the next pass. Probably dropped some shit.
        if sharedState.fleeing then
            sharedState:remove("manualAssignedPlanObject")
        end
        
        if (not lookAroundResult.bestObjectInfo) then
            return nil
        end
    end
    
    if ((not lookAroundResult.bestObjectInfo) or lookAroundResult.bestObjectInfo.lookAtIntent ~= lookAtIntents.types.sleep.index) then
        --disabled--mj:objectLog(sapien.uniqueID, "lookAroundInfo.sleepDesire:", lookAroundInfo.sleepDesire)
        if serverSapienAI:addOrderToReturnCloseToHomePosIfNeeded(sapien, lookAroundInfo.sleepDesire) then
            --disabled--mj:objectLog(sapien.uniqueID, "added addOrderToReturnCloseToHomePos due to distance from home pos and strong sleep desire")
            return nil
        end
    end

    --findOrderAI:checkAutoAssignRoleForNearbyPlansWithTooDistantState(sapien)

    if ((not lookAroundResult.bestObjectInfo) or 
        lookAroundResult.bestObjectInfo.lookAtIntent == lookAtIntents.types.social.index or 
        lookAroundResult.bestObjectInfo.lookAtIntent == lookAtIntents.types.restNear.index or 
        lookAroundResult.bestObjectInfo.lookAtIntent == lookAtIntents.types.restOn.index) then
        if findOrderAI:checkShouldDoSelfActionWithInventory(sapien, lookAroundInfo, true, true) then
            return nil
        end
    end
    
    if (not preventSleepDueToManualObject) then
        if findOrderAI:doLowPrioritySelfPlansIfNeeded(sapien, lookAroundInfo, unsavedState, lookAroundResult) then
            return nil
        end
    end

    return lookAroundResult
end

function findOrderAI:actOnLookAtResult(sapien, lookAroundResult, dt)
    
    local lookAroundInfo = findOrderAI:createLookAroundInfo(sapien, nil)
    local aiState = lookAroundInfo.aiState
    
    local function turnAndFace(pos, objectID)
        if objectID ~= sapien.uniqueID then
            serverSapien:setLookAt(sapien, objectID, pos)
            if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                if serverSapienAI:addOrderIfAble(sapien, order.types.turn.index, nil, nil, pathFinding.proximityTypes.goalPos, nil) then
                    local sapienNormal = normalize(sapien.pos)
                    local objectPosNormal = normalize(pos)
                    local objectVec = objectPosNormal - sapienNormal
                    local objectDistance = length(objectVec)
                    if objectDistance > mj:mToP(0.2)  then
                        local rotation = mat3LookAtInverse(objectVec / objectDistance, sapienNormal)
                        if not mj:isNan(rotation.m0) then
                            if mjm.dot(mat3GetRow(rotation, 1), sapien.normalizedPos) < 0.99 then
                                mj:error("rotation is not up orientated")
                                error()
                            end
                            serverGOM:setRotation(sapien.uniqueID, rotation)
                            serverSapien:saveState(sapien)
                        end
                    end
                end
            end
        end
    end

    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:infrequentUpdate e")

    if lookAroundResult and lookAroundResult.bestObjectInfo then
        --disabled--mj:objectLog(sapien.uniqueID, "bestObjectInfo result from findOrderLookAround:lookAround type:", lookAroundResult.bestObjectInfo.lookAtIntent, " lookAroundResult.bestObjectInfo.uniqueID:", lookAroundResult.bestObjectInfo.uniqueID)
        local newLookAtID = lookAroundResult.bestObjectInfo.uniqueID

        aiState.currentLookAtObjectInfo = lookAroundResult.bestObjectInfo

        lookAroundInfo.cooldowns["look_" .. newLookAtID] = lookAI.lookAwayCooldown
        --disabled--mj:objectLog(sapien.uniqueID, "set cooldown:", lookAI.lookAwayCooldown)

        local lookAtPos = gameObject:getSapienLookAtPointForObject(lookAroundResult.bestObjectInfo.object)

        findOrderAI:updateLookAtPosAndTurnAndFaceIfNeeded(sapien, lookAtPos, lookAroundResult.bestObjectInfo.uniqueID, lookAroundResult.bestObjectInfo.object.objectTypeIndex == gameObject.types.sapien.index)
        
    elseif lookAroundResult and lookAroundResult.generalMoveDirection then
        --disabled--mj:objectLog(sapien.uniqueID, "generalMoveDirection  heursitic:", lookAroundResult.heuristic, " should be 1.0:", length(lookAroundResult.generalMoveDirection))
        --disabled--mj:objectLog(sapien.uniqueID, "DAVE  dot close to zero:", dot(lookAroundResult.generalMoveDirection, sapien.normalizedPos))
        local moveToDir = normalize(lookAroundResult.generalMoveDirection + (rng:vec() * 0.25))
        local randomDistance = rng:randomValue() * 30.0 + 20.0
        local moveToPos = sapien.pos + moveToDir * mj:mToP(randomDistance)
        local clampToSeaLevel = true
        moveToPos = worldHelper:getBelowSurfacePos(moveToPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
        --mj:log("moveToPos distance:", mj:pToM(length(moveToPos - sapien.pos)), " randomDistance:", randomDistance)
        local orderContext = nil--{planTypeIndex = plan.types.moveTo.index}
        local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, moveToPos)
        serverSapien:addOrder(sapien, order.types.moveTo.index, pathInfo, nil, orderContext, false)
    else
        --disabled--mj:objectLog(sapien.uniqueID, "not lookAroundResult.bestObjectInfo. lookAroundResult:", lookAroundResult)

        if lookAroundInfo.hasHeldObject then
            serverSapienAI:addOrderToDisposeOfHeldItem(sapien) 
        else
            if lookAroundInfo.sleepDesire < desire.levels.strong then
                if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                    if not lookAroundInfo.cooldowns["random_turn"] then
                        lookAroundInfo.cooldowns["random_turn"] = lookAI.randomTurnCooldown
                        local randomDir = rng:vec()
                        local lookAtNormalized = normalize(sapien.pos + randomDir * mj:mToP(100.0))
                        turnAndFace(sapien.pos + normalize(lookAtNormalized - normalize(sapien.pos)) * mj:mToP(100.0), nil)
                    end
                end
            end
        end
    end

    serverSapien:saveState(sapien)
end

function findOrderAI:focusOnPlanObjectAfterCompletingOrder(sapien, planObject)
    --[[local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    aiState.currentLookAtObjectInfo = {
        lookAtIntent = lookAtIntents.types.work.index,
        uniqueID = planObject.uniqueID,
        object = planObject,
        pos = planObject.pos
    }]]
    
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderAI:focusOnPlanObjectAfterCompletingOrder:", planObject.uniqueID)--, " traceback:", debug.traceback())

    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    aiState.recentPlanObjectID = planObject.uniqueID

    --findOrderAI:updateLookAtPosAndTurnAndFaceIfNeeded(sapien, planObject.pos, planObject.uniqueID, false) --commented out 11/25, as it causes issues looking at defense orders
    serverSapien:saveState(sapien)
end

function findOrderAI:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    --serverTribe = initObjects.serverTribe
    serverSapien = initObjects.serverSapien
    serverSapienAI = initObjects.serverSapienAI
    planManager = initObjects.planManager

    findOrderLookAround:init(initObjects)
    startOrderAI:init(initObjects)
    lookAI:init(initObjects)
end

return findOrderAI