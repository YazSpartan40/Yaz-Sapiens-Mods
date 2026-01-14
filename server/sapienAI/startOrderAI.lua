
local mjm = mjrequire "common/mjm"
local length2 = mjm.length2
local normalize = mjm.normalize
--local dot = mjm.dot
--local vec3 = mjm.vec3
local length = mjm.length
local mat3LookAtInverse = mjm.mat3LookAtInverse
--local mat3GetRow = mjm.mat3GetRow

local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"
local order = mjrequire "common/order"
local action = mjrequire "common/action"
local notification = mjrequire "common/notification"
local pathFinding = mjrequire "common/pathFinding"
local gameConstants = mjrequire "common/gameConstants"
local fuel = mjrequire "common/fuel"
local sapienConstants = mjrequire "common/sapienConstants"
local sapienTrait = mjrequire "common/sapienTrait"
--local worldHelper = mjrequire "common/worldHelper"
--local actionSequence = mjrequire "common/actionSequence"
--local rng = mjrequire "common/randomNumberGenerator"
local resource = mjrequire "common/resource"
--local storage = mjrequire "common/storage"
local sapienInventory = mjrequire "common/sapienInventory"
local desire = mjrequire "common/desire"
local objectInventory = mjrequire "common/objectInventory"
--local mood = mjrequire "common/mood"
local need = mjrequire "common/need"
local maintenance = mjrequire "common/maintenance"
local lookAtIntents = mjrequire "common/lookAtIntents"

local planManager = mjrequire "server/planManager"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverStorageArea = mjrequire "server/serverStorageArea"
local serverSeat = mjrequire "server/objects/serverSeat"
local serverFuel = mjrequire "server/serverFuel"
local serverCompostBin = mjrequire "server/objects/serverCompostBin"

local lookAI = mjrequire "server/sapienAI/lookAI"
local conversation = mjrequire "server/sapienAI/conversation"


local serverSapienAI = nil
local serverGOM = nil
local serverWorld = nil
--local serverTribe = nil
local serverSapien = nil

local startOrderAI = {}


local makeWetPosLength = 1.0 - mj:mToP(0.05)
local makeWetPosLength2 = makeWetPosLength * makeWetPosLength

function startOrderAI:actOnLookAtObject(sapien)
    --disabled--mj:objectLog(sapien.uniqueID, "startOrderAI:actOnLookAtObject")

    --local sharedState = sapien.sharedState
    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    local cooldowns = mj:getOrCreate(aiState, "cooldowns")

    local currentLookAtObjectInfo = aiState.currentLookAtObjectInfo
    
    local lookAtObject = serverGOM:getObjectWithID(currentLookAtObjectInfo.uniqueID)
    if not lookAtObject then
        aiState.currentLookAtObjectInfo = nil
        return false
    end

    local sleepDesire = desire:getCachedSleep(sapien, sapien.temporaryPrivateState, function() 
        return serverWorld:getTimeOfDayFraction(sapien.pos) 
    end)
    local restDesire = desire:getDesire(sapien, need.types.rest.index, true)
    --local happySadMood = mood:getMood(sapien, mood.types.happySad.index)

    local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)
    local hasHeldObject = heldObjectCount > 0
    local lastHeldObjectInfo = nil
    local heldObjectTypeIndex = nil
    local pickedUpObjectOrderTypeIndex = nil

    if hasHeldObject then
        lastHeldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
        heldObjectTypeIndex = lastHeldObjectInfo.objectTypeIndex
        
        local orderContext = lastHeldObjectInfo.orderContext
        if orderContext then
            pickedUpObjectOrderTypeIndex = orderContext.orderTypeIndex
        end
    end
    
    --disabled--mj:objectLog(sapien.uniqueID, "startOrderAI:actOnLookAtObject pickedUpObjectOrderTypeIndex:", pickedUpObjectOrderTypeIndex, " lastHeldObjectInfo:", lastHeldObjectInfo)
    
    local function startSocial()

        local otherSapien = lookAtObject
        if otherSapien then


            
            --[[local relationshipInfo = serverSapien:getRelationshipInfo(sapien, aiState.currentLookAtObjectInfo.uniqueID)
            local bondMax = 0.0
            if relationshipInfo then
                bondMax = math.max(relationshipInfo.bond.short, relationshipInfo.bond.long)
            end

            if bondMax < 0.1 then

            end]] --todo
            
            if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
                return false
            end

            --if sleepDesire < desire.levels.strong then
                --local otherObjectAIState = serverSapienAI.aiStates[aiState.currentLookAtObjectInfo.uniqueID]
                --if otherObjectAIState and otherObjectAIState.currentLookAtObjectInfo and otherObjectAIState.currentLookAtObjectInfo.uniqueID == sapien.uniqueID then
                    if (not serverSapien:isSleeping(otherSapien)) then
                        local cooldownKey = "social_" .. otherSapien.uniqueID
                        if cooldowns[cooldownKey] then
                            return false
                        end
                        cooldowns[cooldownKey] = lookAI.socialCooldown

                        local socialInteractionInfo = conversation:getNextInteractionInfo(sapien, otherSapien)

                        if socialInteractionInfo then

                            local sapienNormal = normalize(sapien.pos)
                            local viewVec = normalize(otherSapien.pos) - sapienNormal
                            local viewVecLength = length(viewVec)
                            if viewVecLength > mj:mToP(0.2) then
                                local rotation = mat3LookAtInverse(viewVec / viewVecLength, sapienNormal)

                                local context = {
                                    socialInteractionInfo = socialInteractionInfo,
                                }

                                if serverSapienAI:addOrderIfAble(sapien, order.types.social.index, otherSapien.uniqueID, context, pathFinding.proximityTypes.reachableWithoutFinalCollisionTest, nil) then

                                    if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                                        serverGOM:setRotation(sapien.uniqueID, rotation)
                                    end

                                    serverSapien:addToBondAndMood(sapien, otherSapien.uniqueID, 0.2, 0.2)
                                    
                                    local otherSapienAIState = serverSapienAI.aiStates[otherSapien.uniqueID]
                                    otherSapienAIState.socialTimer = 0.0

                                    serverGOM:sendNotificationForObject(sapien, notification.types.social.index, socialInteractionInfo, sapien.sharedState.tribeID)
                                    conversation:voiceStarted(sapien)

                                    if socialInteractionInfo.spreadsVirus then
                                        if viewVecLength < mj:mToP(5.0) then
                                            serverSapien:spreadVirus(sapien, otherSapien)
                                        end
                                    end

                                    serverSapien:saveState(sapien)
                                    return true
                                end
                            end
                        end
                    end
                --end
            --end
        end
        return false
    end

    --all we need to to here is watch, point, shout, wave, or run. We are looking for something to do, but won't attack here

    --[[
    fleeThreatDistanceClose = mj:mToP(5.0), --Distance that idle sapiens will start reacting to threats. Normal sapiens will run away at this distance, courageous will notice
    fleeThreatDistanceMid = mj:mToP(15.0), --fearful run away, normal notice, courageous ignore
    fleeThreatDistanceFar = mj:mToP(50.0), --fearful notice, normal ignore, courageous ignore
    ]]
   

    local function doCaution()
        local otherSapien = lookAtObject
        if otherSapien then
            local awarenessDistance2 = nil
            local runDistance2 = nil

            local preventElders = false
            local courageousTrait = sapienTrait:getTraitValue(sapien.sharedState.traits, sapienTrait.types.courageous.index)
            
            if (courageousTrait and (courageousTrait < 0)) or sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, preventElders) then
                awarenessDistance2 = gameConstants.fleeThreatDistanceFar * gameConstants.fleeThreatDistanceFar
                runDistance2 = gameConstants.fleeThreatDistanceMid * gameConstants.fleeThreatDistanceMid
            elseif (courageousTrait and (courageousTrait > 0)) then
                awarenessDistance2 = gameConstants.fleeThreatDistanceClose * gameConstants.fleeThreatDistanceClose
            else
                awarenessDistance2 = gameConstants.fleeThreatDistanceMid * gameConstants.fleeThreatDistanceMid
                runDistance2 = gameConstants.fleeThreatDistanceClose * gameConstants.fleeThreatDistanceClose
            end

            local otherSapienDistance2 = length2(sapien.pos - otherSapien.pos)
            if runDistance2 and otherSapienDistance2 < runDistance2 then
                serverSapien:dropHeldInventoryImmediately(sapien)
                serverSapienAI:addOrderToReturnCloseToHomePosDueToThreat(sapien, otherSapien.pos)
            elseif otherSapienDistance2 < awarenessDistance2 then
                serverSapien:dropHeldInventoryImmediately(sapien) --todo don't drop weapons
                startSocial()
            end
        end

        return false
    end

    if not hasHeldObject then
        if currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.social.index or currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.interest.index then
            if sapien.sharedState.resting or restDesire >= desire.levels.moderate then
                if not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index) then
                    if serverSapienAI:addOrderToFindPlaceNearByToSit(sapien, sapien.pos, nil, false, true) then
                        --disabled--mj:objectLog(sapien.uniqueID, "added OrderToFindPlaceNearByToSit due to rest desire while doing nothing important")
                        return true
                    end
                end
            end
        end
    end
    
    
    if currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.raidTarget.index then
        if lookAtObject then
            if heldObjectTypeIndex then
                --disabled--mj:objectLog(sapien.uniqueID, "in raid actOnLookAtObject() has heldObjectTypeIndex")
                local resourceTypeIndex = gameObject.types[heldObjectTypeIndex].resourceTypeIndex
                if serverSapien:getMaxCarryCount(sapien, resourceTypeIndex) <= heldObjectCount then
                    --disabled--mj:objectLog(sapien.uniqueID, "returning false due to carrying too much")
                    aiState.currentLookAtObjectInfo = nil
                    return false
                end 
            end

            local resourceInfo = serverResourceManager:getResourceInfoForObjectWithID(currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.resourceObjectTypeIndex)

            if not resourceInfo then
                --disabled--mj:objectLog(sapien.uniqueID, "no resourceInfo for raid")
                aiState.currentLookAtObjectInfo = nil
                return false
            end

            --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:addOrderToFetchResource for raid")
            serverSapienAI:addOrderToFetchResource(sapien, resourceInfo, 4, nil, nil, currentLookAtObjectInfo.lookAtIntent)
            return true
        end
    elseif currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.caution.index then
        if doCaution() then
            aiState.currentLookAtObjectInfo = nil
            return true
        end
    elseif currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.social.index then
        if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
            if serverSapienAI:addOrderToDisposeOfHeldItem(sapien) then
                return true
            end
        end

        if startSocial() then
            aiState.currentLookAtObjectInfo = nil
            return true
        end
    elseif currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.work.index then -- note: this can happen for any object, don't assume it has been checked for valid skills or anything
        --disabled--mj:objectLog(sapien.uniqueID, "looking at work object:", currentLookAtObjectInfo.uniqueID)
        if heldObjectTypeIndex then
            --disabled--mj:objectLog(sapien.uniqueID, "heldObjectTypeIndex:", heldObjectTypeIndex)

            local heldObjectResourceTypeIndex = gameObject.types[heldObjectTypeIndex].resourceTypeIndex
            
            local heldObjectStorageAreaTransferInfo = nil
            if lastHeldObjectInfo.orderContext then
                heldObjectStorageAreaTransferInfo = lastHeldObjectInfo.orderContext.storageAreaTransferInfo
            end
            --disabled--mj:objectLog(sapien.uniqueID, "heldObjectStorageAreaTransferInfo:", heldObjectStorageAreaTransferInfo)

            if pickedUpObjectOrderTypeIndex ~= order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index then
                local maintenanceTypeIndexes = maintenance:maintenanceTypeIndexesForObjectTypeIndex(lookAtObject.objectTypeIndex)
                if maintenanceTypeIndexes then
                    for j, maintenanceTypeIndex in ipairs(maintenanceTypeIndexes) do
                        local maintenanceType = maintenance.types[maintenanceTypeIndex]
                        if maintenance:maintenanceIsRequiredOfType(sapien.sharedState.tribeID, lookAtObject, maintenanceTypeIndex, sapien.uniqueID) then
                            if maintenanceType.planTypeIndex == plan.types.addFuel.index then
                                if serverGOM:objectTypeIndexIsRequiredForMaintenanceObject(lookAtObject, heldObjectTypeIndex, sapien.sharedState.tribeID) then
                                    local cooldownKey = "maintain_" .. aiState.currentLookAtObjectInfo.uniqueID
                                    if serverSapienAI:addOrderToDeliverHeldItemFuel(sapien, lookAtObject, heldObjectTypeIndex, maintenanceType.planTypeIndex) then
                                        aiState.currentLookAtObjectInfo = nil
                                        cooldowns[cooldownKey] = nil
                                        return true
                                    end
                                    cooldowns[cooldownKey] = lookAI.planCooldown
                                end
                            elseif maintenanceType.planTypeIndex == plan.types.deliverToCompost.index then
                                if serverGOM:objectTypeIndexIsRequiredForMaintenanceObject(lookAtObject, heldObjectTypeIndex, sapien.sharedState.tribeID) then
                                    
                                    local cooldownKey = "maintain_" .. aiState.currentLookAtObjectInfo.uniqueID

                                    local maxCarryCount = serverSapien:getMaxCarryCount(sapien, heldObjectResourceTypeIndex)
                                    if maxCarryCount > 1 then
                                        if heldObjectCount < maxCarryCount then
                                            if serverSapienAI:addOrderForMaintenanceIfAble(sapien, lookAtObject, maintenanceType.planTypeIndex, maintenanceType.index) then
                                                --disabled--mj:objectLog(sapien.uniqueID, "maintenance serverSapienAI:addOrderForPlanStateIfAble success")
                                                aiState.currentLookAtObjectInfo = nil
                                                cooldowns[cooldownKey] = nil
                                                return true
                                            end
                                        end
                                    end
                                    
                                    if serverSapienAI:addOrderToDeliverHeldItemToCompost(sapien, lookAtObject, heldObjectTypeIndex, maintenanceType.planTypeIndex) then
                                        aiState.currentLookAtObjectInfo = nil
                                        cooldowns[cooldownKey] = nil
                                        return true
                                    end
                                    cooldowns[cooldownKey] = lookAI.planCooldown
                                end
                            elseif maintenanceType.planTypeIndex == plan.types.transferObject.index then
                                --disabled--mj:objectLog(sapien.uniqueID, "maintenanceType.planTypeIndex == plan.types.transferObject.index")
                                if heldObjectStorageAreaTransferInfo then
                                    
                                    local maxCarryCount = serverSapien:getMaxCarryCount(sapien, heldObjectResourceTypeIndex)
                                    if maxCarryCount > 1 then
                                        if heldObjectCount < maxCarryCount then
                                            --disabled--mj:objectLog(sapien.uniqueID, "heldObjectCount < maxCarryCount")
                                            local nextTransferInfo = serverStorageArea:storageAreaTransferInfoIfRequiresPickup(sapien.sharedState.tribeID, lookAtObject, sapien.uniqueID)
                                            --local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(currentLookAtObjectInfo.uniqueID, objectTypeIndex, tribeID)
                                            if nextTransferInfo and 
                                            nextTransferInfo.resourceTypeIndex == heldObjectResourceTypeIndex and 
                                            nextTransferInfo.destinationObjectID == heldObjectStorageAreaTransferInfo.destinationObjectID and 
                                            ((not nextTransferInfo.destinationCapacity) or (nextTransferInfo.destinationCapacity > heldObjectCount)) then
                                                
                                                --disabled--mj:objectLog(sapien.uniqueID, "adding order to pick up more items for storage transfer")
                                                local cooldownKey = "m_" .. aiState.currentLookAtObjectInfo.uniqueID
                                                
                                                if serverSapienAI:addOrderForMaintenanceIfAble(sapien, lookAtObject, maintenanceType.planTypeIndex, maintenanceType.index) then
                                                    --disabled--mj:objectLog(sapien.uniqueID, "maintenance serverSapienAI:addOrderForPlanStateIfAble success")
                                                    aiState.currentLookAtObjectInfo = nil
                                                    cooldowns[cooldownKey] = nil
                                                    return true
                                                end
                                                cooldowns[cooldownKey] = lookAI.planCooldown
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if heldObjectStorageAreaTransferInfo then
                    --disabled--mj:objectLog(sapien.uniqueID, "heldObjectStorageAreaTransferInfo")
                    if gameObject.types[lookAtObject.objectTypeIndex].isStorageArea then
                        --disabled--mj:objectLog(sapien.uniqueID, "a")
                        local maxCarryCount = serverSapien:getMaxCarryCount(sapien, heldObjectResourceTypeIndex)
                        if maxCarryCount > 1 then
                            --disabled--mj:objectLog(sapien.uniqueID, "b")
                            if heldObjectCount < maxCarryCount then
                                --disabled--mj:objectLog(sapien.uniqueID, "c")
                                local nextTransferInfo = serverStorageArea:storageAreaTransferInfoIfRequiresPickup(sapien.sharedState.tribeID, lookAtObject, sapien.uniqueID)
                                --disabled--mj:objectLog(sapien.uniqueID, "d:", nextTransferInfo)
                                if nextTransferInfo and 
                                nextTransferInfo.resourceTypeIndex == heldObjectResourceTypeIndex and 
                                nextTransferInfo.destinationObjectID == heldObjectStorageAreaTransferInfo.destinationObjectID and 
                                ((not nextTransferInfo.destinationCapacity) or (nextTransferInfo.destinationCapacity > heldObjectCount)) then
                                    local cooldownKey = "m_" .. aiState.currentLookAtObjectInfo.uniqueID
                                    --disabled--mj:objectLog(sapien.uniqueID, "e")
                                    if serverSapienAI:addOrderForStorageAreaItemTransferPickupIfAble(sapien, lookAtObject, plan.types.transferObject.index) then
                                        --disabled--mj:objectLog(sapien.uniqueID, "addOrderForStorageAreaItemPickupIfAble success")
                                        aiState.currentLookAtObjectInfo = nil
                                        cooldowns[cooldownKey] = nil
                                        return true
                                    end
                                    
                                    cooldowns[cooldownKey] = lookAI.planCooldown
                                end
                            end
                        end
                    end
                end
            end


            if currentLookAtObjectInfo.isCraftingHeldObjectElsewhere then
                
                local heldObjectPlanState = nil
                if lastHeldObjectInfo.orderContext then
                    heldObjectPlanState = lastHeldObjectInfo.orderContext.planState
                end
                if serverSapienAI:addOrderToDeliverPlanObjectForCraftingElsewhere(sapien, lookAtObject, heldObjectTypeIndex, heldObjectPlanState) then
                    return true
                end
            elseif pickedUpObjectOrderTypeIndex == order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index then
                if serverSapienAI:addOrderToDisposeOfHeldItem(sapien) then
                    return true
                end
            elseif currentLookAtObjectInfo.isStorage then
                
                local options = nil
                if heldObjectStorageAreaTransferInfo then
                    if currentLookAtObjectInfo.uniqueID ~= heldObjectStorageAreaTransferInfo.destinationObjectID then
                        return false -- we need to do something here, or we will go on to deliver it to the source storage area again
                    end
                    options = {
                        allowTradeRequestsMatchingResourceTypeIndex = heldObjectStorageAreaTransferInfo.resourceTypeIndex,
                        allowQuestsMatchingResourceTypeIndex = heldObjectStorageAreaTransferInfo.resourceTypeIndex,
                    }
                end


                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(currentLookAtObjectInfo.uniqueID, heldObjectTypeIndex, sapien.sharedState.tribeID, options)

                if matchInfo then
                    --[[local maxCarryCount = serverSapien:getMaxCarryCount(sapien, resourceTypeIndex)
                    if maxCarryCount > 1 then
                        if heldObjectCount < maxCarryCount then
                            local closestStoreObjectPlanInfo = nil
                            local allPlanObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.plans, sapien.pos, mj:mToP(500.0)) --5000M?! ARGH
                            for i,objectInfo in ipairs(allPlanObjectInfos) do
                                local planObject = objectInfo.object
                                if not serverGOM:objectIsInaccessible(planObject) then
                                    if gameObject.types[planObject.objectTypeIndex].resourceTypeIndex == resourceTypeIndex then
                                        local planStates = planManager:getPlanStatesForObjectForSapien(planObject, sapien)
                                        if planStates then
                                            for j,otherPlanState in ipairs(planStates) do
                                                if otherPlanState.planTypeIndex == plan.types.storeObject.index then
                                                    if not serverSapien:objectIsAssignedToOtherSapien(planObject, sapien.sharedState.tribeID, nil, sapien) then
                                                        if not closestStoreObjectPlanInfo or objectInfo.distance2 < closestStoreObjectPlanInfo.distance2 then
                                                            closestStoreObjectPlanInfo = objectInfo
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
        
                            if closestStoreObjectPlanInfo then
                                local lookAtObjectDistance2 = length2(lookAtObject.pos - sapien.pos)
                                if closestStoreObjectPlanInfo.distance2 < lookAtObjectDistance2 then
                                    --mj:log("b:", sapien.uniqueID)
                                    if serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, closestStoreObjectPlanInfo.object.uniqueID, plan.types.storeObject.index) then
                                        -- mj:log("add order to pick up other item:", sapien.uniqueID)
                                        return true
                                    end
                                end
                            end
                        end
                    end]] -- commented out  23/3 if this needs to be reinstated, it at least needs to take transferInfo into account, not lok in that case. also reduce distance massively

                    if serverSapienAI:addOrderToTakeHeldItemToStorage(sapien, lookAtObject, heldObjectTypeIndex, (heldObjectStorageAreaTransferInfo ~= nil)) then
                        --mj:log("addOrderToTakeHeldItemToStorage:", sapien.uniqueID)
                        return true
                    else
                        local cooldownKey = "m_" .. currentLookAtObjectInfo.uniqueID
                        cooldowns[cooldownKey] = lookAI.planCooldown
                    end
                end
            elseif (currentLookAtObjectInfo.planTypeIndex == plan.types.storeObject.index and ((not pickedUpObjectOrderTypeIndex) or pickedUpObjectOrderTypeIndex == order.types.storeObject.index))
            or (currentLookAtObjectInfo.planTypeIndex == plan.types.transferObject.index and pickedUpObjectOrderTypeIndex == order.types.transferObject.index) then
                --disabled--mj:objectLog(sapien.uniqueID, "looking at object that has store plan, whilke holding another object:", currentLookAtObjectInfo)
                
                local maxCarryCount = serverSapien:getMaxCarryCount(sapien, heldObjectResourceTypeIndex)
                if maxCarryCount > heldObjectCount then
                    local thisObjectResourceTypeIndex = gameObject.types[lookAtObject.objectTypeIndex].resourceTypeIndex
                    if thisObjectResourceTypeIndex == heldObjectResourceTypeIndex then
                        if serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.planTypeIndex) then
                            --disabled--mj:objectLog(sapien.uniqueID, "added order to store looked at object")
                            -- mj:log("add order to pick up other item:", sapien.uniqueID)
                            return true
                        end
                    end
                end
                --disabled--mj:objectLog(sapien.uniqueID, "failed to add order to store looked at object")
                return false
            else
                --disabled--mj:objectLog(sapien.uniqueID, "looking at plan object, object not specifically required. currentLookAtObjectInfo:", currentLookAtObjectInfo)

                local planState = planManager:getPlanStateForObjectForSapienForPlanType(lookAtObject, sapien, currentLookAtObjectInfo.planTypeIndex)
                if planState then
                    
                    if currentLookAtObjectInfo.planTypeIndex == plan.types.treatInjury.index or
                    currentLookAtObjectInfo.planTypeIndex == plan.types.treatBurn.index or
                    currentLookAtObjectInfo.planTypeIndex == plan.types.treatFoodPoisoning.index or
                    currentLookAtObjectInfo.planTypeIndex == plan.types.treatVirus.index then
                        if currentLookAtObjectInfo.uniqueID == sapien.uniqueID then
                            if serverSapienAI:addOrderToSelfApplyMedicineWithHeldItem(sapien, currentLookAtObjectInfo.planTypeIndex) then
                                return true
                            end
                        else
                            if serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.planTypeIndex) then
                                return true
                            end
                        end
                    end
                    
                    local function getRequiredResourceCount()
                        if planState.requiredResources then
                            local inventoryLocation = serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(lookAtObject, heldObjectTypeIndex, planState, sapien.sharedState.tribeID)
                            if inventoryLocation == objectInventory.locations.availableResource.index then
                                for k,resourceInfo in ipairs(planState.requiredResources) do
                                    if resourceInfo.count > 0 then
                                        local match = false
                                        if resourceInfo.objectTypeIndex then
                                            if resourceInfo.objectTypeIndex == heldObjectTypeIndex then
                                                match = true
                                            end
                                        else
                                            if resource:groupOrResourceMatchesResource(resourceInfo.type or resourceInfo.group, gameObject.types[heldObjectTypeIndex].resourceTypeIndex) then
                                                match = true
                                            end
                                        end

                                        if match then
                                            return resourceInfo.count
                                        end
                                    end
                                end
                            end
                        end
                        return 0
                    end
                    

                    local matchingRequiredResourceCount = getRequiredResourceCount()
                    
                    --disabled--mj:objectLog(sapien.uniqueID, "looking at plan, has planState:", planState, " heldObjectTypeIndex:", heldObjectTypeIndex, " matchingRequiredResourceCount:", matchingRequiredResourceCount)

                    if matchingRequiredResourceCount > 1 then
                        local maxCarryCount = serverSapien:getMaxCarryCount(sapien, heldObjectResourceTypeIndex)
                        if maxCarryCount > 1 then
                            if heldObjectCount < maxCarryCount and heldObjectCount < matchingRequiredResourceCount then
                                local gameObjectTypes = gameObject:gameObjectTypesSharingResourceTypesWithGameObjectType(heldObjectTypeIndex)

                                if currentLookAtObjectInfo.planTypeIndex == plan.types.addFuel.index or currentLookAtObjectInfo.planTypeIndex == plan.types.light.index then
                                    local fuelObjectTypes = serverFuel:requiredFuelObjectTypesArrayForObject(lookAtObject, sapien.sharedState.tribeID)
                                    local combined = {}
                                    for i,gameObjectType in ipairs(gameObjectTypes) do
                                        for j, fuelObjectType in ipairs(fuelObjectTypes) do
                                            if fuelObjectType == gameObjectType then
                                                table.insert(combined, fuelObjectType)
                                            end
                                        end
                                    end
                                    gameObjectTypes = combined
                                elseif currentLookAtObjectInfo.planTypeIndex == plan.types.deliverToCompost.index then
                                    local requiredObjectTypes = serverCompostBin:requiredCompostObjectTypesArrayForObject(lookAtObject, sapien.sharedState.tribeID)
                                    local combined = {}
                                    for i,gameObjectType in ipairs(gameObjectTypes) do
                                        for j, requiredObjectType in ipairs(requiredObjectTypes) do
                                            if requiredObjectType == gameObjectType then
                                                table.insert(combined, requiredObjectType)
                                            end
                                        end
                                    end
                                    gameObjectTypes = combined
                                else
                                    local restrictedResourceObjectTypes = lookAtObject.sharedState.restrictedResourceObjectTypes
                                    
                                    if planState.constructableTypeIndex then
                                        restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(sapien.sharedState.tribeID, planState.constructableTypeIndex, restrictedResourceObjectTypes)
                                    elseif plan.types[planState.planTypeIndex].isMedicineTreatment then
                                        restrictedResourceObjectTypes = serverWorld:getResourceBlockListForMedicineTreatment(sapien.sharedState.tribeID, restrictedResourceObjectTypes)
                                    elseif planState.planTypeIndex == plan.types.light.index then
                                        local fuelGroup = fuel.groupsByObjectTypeIndex[lookAtObject.objectTypeIndex]
                                        if fuelGroup then
                                            restrictedResourceObjectTypes = serverWorld:getResourceBlockListForFuel(sapien.sharedState.tribeID, fuelGroup.index, restrictedResourceObjectTypes)
                                        end
                                    end

                                    if restrictedResourceObjectTypes then
                                        local allowedObjectTypes = {}
                                        for i,objectTypeIndex in ipairs(gameObjectTypes) do
                                            if not restrictedResourceObjectTypes[objectTypeIndex] then
                                                table.insert(allowedObjectTypes, objectTypeIndex)
                                            end
                                        end
                                        gameObjectTypes = allowedObjectTypes
                                    end 
                                end

                                if next(gameObjectTypes) then
                                    local resourceInfo = serverResourceManager:findResourceForSapien(sapien, gameObjectTypes, {
                                        allowStockpiles = true,
                                        allowGather = false,
                                        takePriorityOverStoreOrders = true,
                                    })
                                    --disabled--mj:objectLog(sapien.uniqueID, "resourceInfo:", resourceInfo, " gameObjectTypes:", gameObjectTypes)
                                    if resourceInfo then
                                        -- mj:log("building found b:", sapien.uniqueID)
                                        local lookAtObjectDistance2 = length2(lookAtObject.pos - sapien.pos)
                                        if resourceInfo.distance2 < lookAtObjectDistance2 then
                                            if serverSapienAI:addOrderToFetchResource(sapien, resourceInfo, matchingRequiredResourceCount, currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.planTypeIndex, currentLookAtObjectInfo.lookAtIntent) then
                                                return true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    --disabled--mj:objectLog(sapien.uniqueID, " currentLookAtObjectInfo:", currentLookAtObjectInfo)


                    
                    local inventoryLocation = serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(lookAtObject, heldObjectTypeIndex, planState, sapien.sharedState.tribeID)
                    local isRequiredTool = inventoryLocation and (inventoryLocation == objectInventory.locations.tool.index)
                    
                    if isRequiredTool then
                        if serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.planTypeIndex) then
                    --      mj:log("bestUseLocationInfo.isRequiredTool b:", sapien.uniqueID)
                            return true
                        end
                    else
                        if matchingRequiredResourceCount > 0 then
                            --disabled--mj:objectLog(sapien.uniqueID, "matchingRequiredResourceCount > 0, calling serverSapienAI:addOrderToTakeHeldItemToCraftAreaOrBuildingSite")
                            if serverSapienAI:addOrderToTakeHeldItemToCraftAreaOrBuildingSite(sapien, lookAtObject, heldObjectTypeIndex, currentLookAtObjectInfo.planTypeIndex, planState) then
                                return true
                            end
                        end
                    end

                    local dontDropDueToStoreObjectOrderWithSameAsCarried = false
                    if currentLookAtObjectInfo.planTypeIndex == plan.types.storeObject.index then
                        if pickedUpObjectOrderTypeIndex ~= order.types.transferObject.index then
                            if gameObject.types[lookAtObject.objectTypeIndex].resourceTypeIndex == gameObject.types[heldObjectTypeIndex].resourceTypeIndex then
                                dontDropDueToStoreObjectOrderWithSameAsCarried = true
                                local maxCarryCount =  serverSapien:getMaxCarryCount(sapien, gameObject.types[heldObjectTypeIndex].resourceTypeIndex)
                                if maxCarryCount > heldObjectCount then
                                    if serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.planTypeIndex) then
                                        --disabled--mj:objectLog(sapien.uniqueID, "add order to pick up matching item with store order")
                                        return true
                                    end
                                end
                            end
                        end
                    end
                    
                    if (not dontDropDueToStoreObjectOrderWithSameAsCarried) then

                        if serverSapienAI:addOrderToDisposeOfHeldItem(sapien) then
                            --disabled--mj:objectLog(sapien.uniqueID, "dropped item in startOrderAI due to not needing for plan:", planState)
                            return true
                        end

                        --[[ if serverSapienAI:addOrderIfAble(sapien, order.types.dropObject.index, nil, nil) then
                            --disabled--mj:objectLog(sapien.uniqueID, "dropped item in startOrderAI due to not needing for plan.")
                            return true
                        end]]
                    end
                end
                    
                local cooldownKey = "plan_" .. currentLookAtObjectInfo.uniqueID
                cooldowns[cooldownKey] = lookAI.planCooldown
            end
        else --no held object
            
            if currentLookAtObjectInfo.isLogisticsRouteDestination then
                local orderContext = nil
                if serverSapienAI:addOrderIfAble(sapien, order.types.moveToLogistics.index, currentLookAtObjectInfo.uniqueID, orderContext, pathFinding.proximityTypes.reachableWithoutFinalCollisionTest, nil) then
                    return true
                end
            else
                local planStates = planManager:getPlanStatesForObjectForSapien(lookAtObject, sapien)
                if planStates then
                    --disabled--mj:objectLog(sapien.uniqueID, "can do tasks, has available plan states, and skillOffset met. Calling serverSapienAI:addOrderForPlanObjectIDIfAble")
                    local cooldownKey = "plan_" .. aiState.currentLookAtObjectInfo.uniqueID

                    if serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, aiState.currentLookAtObjectInfo.uniqueID, nil) then
                        --disabled--mj:objectLog(sapien.uniqueID, "addOrderForPlanObjectIDIfAble success")
                -- mj:log(debug.traceback())
                        aiState.currentLookAtObjectInfo = nil
                        cooldowns[cooldownKey] = nil
                        return true
                    end
                -- mj:log("addOrderForPlanObjectIDIfAble fail. Added cooldown (", sapien.uniqueID, ")")
                    cooldowns[cooldownKey] = lookAI.planCooldown
                else
                    --disabled--mj:objectLog(sapien.uniqueID, "no planStates found in getPlanStatesForObjectForSapien")
                end

                local maintenanceTypeIndexes = maintenance:maintenanceTypeIndexesForObjectTypeIndex(lookAtObject.objectTypeIndex)
                if maintenanceTypeIndexes then
                    for j, maintenanceTypeIndex in ipairs(maintenanceTypeIndexes) do
                        local maintenanceType = maintenance.types[maintenanceTypeIndex]
                        if maintenance:maintenanceIsRequiredOfType(sapien.sharedState.tribeID, lookAtObject, maintenanceTypeIndex, sapien.uniqueID) then
                            --disabled--mj:objectLog(sapien.uniqueID, "maintenance:maintenanceIsRequiredOfType:", maintenanceTypeIndex)
                            --disabled--mj:objectLog(lookAtObject.uniqueID, "maintenance:maintenanceIsRequiredOfType:", maintenanceTypeIndex)
                            
                            local cooldownKey = "m_" .. aiState.currentLookAtObjectInfo.uniqueID

                                if serverSapienAI:addOrderForMaintenanceIfAble(sapien, lookAtObject, maintenanceType.planTypeIndex, maintenanceTypeIndex) then
                                    --disabled--mj:objectLog(sapien.uniqueID, "maintenance serverSapienAI:addOrderForPlanStateIfAble success")
                                    --disabled--mj:objectLog(lookAtObject.uniqueID, "maintenance serverSapienAI:addOrderForPlanStateIfAble success sapien.uniqueID:", sapien.uniqueID)
                                    aiState.currentLookAtObjectInfo = nil
                                    cooldowns[cooldownKey] = nil
                                    return true
                                end
                            cooldowns[cooldownKey] = lookAI.planCooldown
                        end
                    end
                end
            end
        end
    elseif aiState.currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.sleep.index then
        if sleepDesire >= desire.levels.moderate then
            
            if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
                if serverSapienAI:addOrderToDisposeOfHeldItem(sapien) then
                    return true
                end
                return false
            end

            local cooldownKey = "sleep_" .. aiState.currentLookAtObjectInfo.uniqueID
            if serverSapienAI:addOrderIfAble(sapien, order.types.sleep.index, aiState.currentLookAtObjectInfo.uniqueID, nil, pathFinding.proximityTypes.reachable, gameConstants.standardPathProximityDistance) then
                aiState.currentLookAtObjectInfo = nil
                return true
            end
            cooldowns[cooldownKey] = lookAI.planCooldown
        end
    elseif currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.restOn.index or currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.restNear.index then
        --disabled--mj:objectLog(sapien.uniqueID, "currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.restOn.index or currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.restNear.index")
        if (not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index)) or 
        (currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.restOn.index and (not sapien.sharedState.seatObjectID))then 
            --disabled--mj:objectLog(sapien.uniqueID, "rest b")
            if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
                if serverSapienAI:addOrderToDisposeOfHeldItem(sapien) then
                    return true
                end
                return false
            end

            --disabled--mj:objectLog(sapien.uniqueID, "rest c")
            
            if currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.restOn.index then
                --disabled--mj:objectLog(sapien.uniqueID, "rest d")
                
                local allowRidableObjects = false
                if sapien.sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index or length2(sapien.pos) < makeWetPosLength2 then
                    allowRidableObjects = true
                end

                local seatNodeIndex = serverSeat:getAvailableNodeIndex(sapien, lookAtObject, allowRidableObjects)
                if seatNodeIndex then
                    --disabled--mj:objectLog(sapien.uniqueID, "rest e")
                    local restNearObjectIDOrNil = currentLookAtObjectInfo.restNearObjectID

                    local orderContext = {
                        seatNodeIndex = seatNodeIndex,
                        restNearObjectID = restNearObjectIDOrNil
                    }

                    if serverSapienAI:addOrderIfAble(sapien, order.types.sit.index, currentLookAtObjectInfo.uniqueID, orderContext, pathFinding.proximityTypes.reachable, gameConstants.standardPathProximityDistance) then
                        --disabled--mj:objectLog(sapien.uniqueID, "rest f")
                        aiState.currentLookAtObjectInfo = nil
                        return true
                    end
                end
            else
                local orderContext = {
                    restNearObjectID = currentLookAtObjectInfo.uniqueID
                }
                
                if serverSapienAI:addOrderToFindPlaceNearByToSit(sapien, currentLookAtObjectInfo.pos, orderContext, false, true) then
                    aiState.currentLookAtObjectInfo = nil
                    return true
                end
            end
            
        end
    elseif currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.play.index then
        if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
            return false
        end
        
        --mj:log("currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.play.index currentLookAtObjectInfo:", currentLookAtObjectInfo)

        local resourceInfo = serverResourceManager:getResourceInfoForObjectWithID(currentLookAtObjectInfo.uniqueID, currentLookAtObjectInfo.resourceObjectTypeIndex)

        if not resourceInfo then
            --disabled--mj:objectLog(sapien.uniqueID, "no resourceInfo for currentLookAtObjectInfo.lookAtIntent == lookAtIntents.types.play.index")
            aiState.currentLookAtObjectInfo = nil
            return false
        end

        if serverSapienAI:addOrderToFetchResource(sapien, resourceInfo, 1, nil, nil, currentLookAtObjectInfo.lookAtIntent) then
            aiState.currentLookAtObjectInfo = nil
            return true
        end
    end

    aiState.currentLookAtObjectInfo = nil --added 22-10-20, dubious
    return false
end



function startOrderAI:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    --serverTribe = serverTribe_
    serverSapien = initObjects.serverSapien
    serverSapienAI = initObjects.serverSapienAI
end


return startOrderAI