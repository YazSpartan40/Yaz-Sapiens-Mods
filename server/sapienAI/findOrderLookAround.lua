local mjm = mjrequire "common/mjm"
local normalize = mjm.normalize
--local dot = mjm.dot
--local vec3 = mjm.vec3
local length = mjm.length
local length2 = mjm.length2
--local mat3LookAtInverse = mjm.mat3LookAtInverse
--local mat3GetRow = mjm.mat3GetRow

local gameObject = mjrequire "common/gameObject"
local order = mjrequire "common/order"
local plan = mjrequire "common/plan"
local action = mjrequire "common/action"
local rng = mjrequire "common/randomNumberGenerator"
local resource = mjrequire "common/resource"
local constructable = mjrequire "common/constructable"
local skill = mjrequire "common/skill"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
local desire = mjrequire "common/desire"
local statusEffect = mjrequire "common/statusEffect"
local research = mjrequire "common/research"
local sapienConstants = mjrequire "common/sapienConstants"
local maintenance = mjrequire "common/maintenance"
local lookAtIntents = mjrequire "common/lookAtIntents"
local objectInventory = mjrequire "common/objectInventory"
local evolvingObject = mjrequire "common/evolvingObject"
local tool = mjrequire "common/tool"
local gameConstants = mjrequire "common/gameConstants"
local sapienTrait = mjrequire "common/sapienTrait"

local planManager = mjrequire "server/planManager"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverStorageArea = mjrequire "server/serverStorageArea"
local serverCraftArea = mjrequire "server/serverCraftArea"
local terrain = mjrequire "server/serverTerrain"
local serverSeat = mjrequire "server/objects/serverSeat"
local serverLogistics = mjrequire "server/serverLogistics"
local serverFuel = mjrequire "server/serverFuel"
local serverCompostBin = mjrequire "server/objects/serverCompostBin"
--local serverTutorialState = mjrequire "server/serverTutorialState"

local lookAI = mjrequire "server/sapienAI/lookAI"

local findOrderLookAround = {}

--local serverSapienInventory = mjrequire "server/serverSapienInventory"

local serverSapienAI = nil
local serverGOM = nil
local serverWorld = nil
local serverTribe = nil
local serverSapien = nil

local lookWeightCurrentlyLookingAtObjectSoDontSwitch = 1.0


local lookWeightOffsetByType = { --additional offset, higher = looked at more
    [lookAtIntents.types.social.index] = 10.0,
    [lookAtIntents.types.caution.index] = 120.0,
    [lookAtIntents.types.work.index] = 100.0,
    [lookAtIntents.types.raidTarget.index] = 40.0,
    [lookAtIntents.types.interest.index] = -10.0,
    [lookAtIntents.types.sleep.index] = 0.0,
    [lookAtIntents.types.restOn.index] = 5.0,
    [lookAtIntents.types.restNear.index] = 0.0,
    [lookAtIntents.types.play.index] = 0.0,
}

local lookWeightAlreadySeenByType = { -- higher = avoid staring at the same object more
    [lookAtIntents.types.social.index] = 2.0,
    [lookAtIntents.types.work.index] = 0.1,
    [lookAtIntents.types.raidTarget.index] = 0.5,
    [lookAtIntents.types.caution.index] = 2.0,
    [lookAtIntents.types.interest.index] = 0.2,
    [lookAtIntents.types.sleep.index] = 0.5,
    [lookAtIntents.types.restOn.index] = 0.1,
    [lookAtIntents.types.restNear.index] = 0.1,
    [lookAtIntents.types.play.index] = 0.1,
}

local lookWeightCloseObjectByType = { -- higher = dont look at far away objects
    [lookAtIntents.types.social.index] = 80.0,
    [lookAtIntents.types.work.index] = 1.0,
    [lookAtIntents.types.raidTarget.index] = 8.0,
    [lookAtIntents.types.caution.index] = 1.0,
    [lookAtIntents.types.interest.index] = 80.0,
    [lookAtIntents.types.sleep.index] = 8.0,
    [lookAtIntents.types.restOn.index] = 8.0,
    [lookAtIntents.types.restNear.index] = 80.0,
    [lookAtIntents.types.play.index] = 80.0,
}

local function lookHeuristic(sapien, lookAroundInfo, distance, uniqueID, lookAtIntent, allowLongDistance)
    local alreadySeenWeight = 0.0
    
    local alreadySeenCooldown = lookAroundInfo.cooldowns["look_" .. uniqueID]
    if alreadySeenCooldown then
        alreadySeenWeight = -alreadySeenCooldown / lookAI.lookAwayCooldown * lookWeightAlreadySeenByType[lookAtIntent] * 100.0
        --disabled--mj:objectLog(sapien.uniqueID, "alreadySeenCooldown:", alreadySeenCooldown, " alreadySeenWeight:", alreadySeenWeight, " object:", uniqueID)
    end

    local currentlyLookAtWeight = 0.0
    if lookAroundInfo.aiState.currentLookAtObjectInfo and lookAroundInfo.aiState.currentLookAtObjectInfo.uniqueID == uniqueID then
        currentlyLookAtWeight = lookWeightCurrentlyLookingAtObjectSoDontSwitch
    end

    local contexturalOffset = 0.0
    local moodDesireOffset = 0.0

    local maxDistance = 400.0
    local distanceMultiplierDueToRestOrSleepOrPrioritization = 1.0

    if lookAtIntent == lookAtIntents.types.work.index then
        if (not sapien.sharedState.manualAssignedPlanObject) then
            local sleepOrRestDesire = lookAroundInfo.sleepDesire
            if lookAroundInfo.restDesire > sleepOrRestDesire then
                sleepOrRestDesire = lookAroundInfo.restDesire
            end
            if sleepOrRestDesire >= desire.levels.moderate then
                moodDesireOffset = -40.0
                distanceMultiplierDueToRestOrSleepOrPrioritization = 5.0
                if sleepOrRestDesire >= desire.levels.strong then
                    moodDesireOffset = -100.0
                    distanceMultiplierDueToRestOrSleepOrPrioritization = 20.0
                end
            end
        end

        if lookAroundInfo.aiState.recentPlanObjectID == uniqueID then
            contexturalOffset = contexturalOffset + 10.0
        end

        if allowLongDistance then
            maxDistance = mj:pToM(planManager.maxAssignedOrPrioritizedPlanDistance)
            distanceMultiplierDueToRestOrSleepOrPrioritization = 0.01
        end
    end
    
    if lookAtIntent == lookAtIntents.types.sleep.index then
        maxDistance = 600.0
        if lookAroundInfo.sleepDesire >= desire.levels.moderate then
            contexturalOffset = contexturalOffset + 20.0
        end
        if lookAroundInfo.sleepDesire >= desire.levels.strong then
            contexturalOffset = contexturalOffset + 20.0
        end
    end

    if lookAtIntent == lookAtIntents.types.social.index then
        maxDistance = 100.0
        local relationshipInfo = serverSapien:getRelationshipInfo(sapien, uniqueID)
        if not relationshipInfo then
            contexturalOffset = contexturalOffset + 20.0
        else
            local bondMax = math.max(relationshipInfo.bond.short, relationshipInfo.bond.long)
            if bondMax < 0.1 then
                contexturalOffset = contexturalOffset + 20.0 * (1.0 - bondMax / 0.1)
            else
                contexturalOffset = contexturalOffset + 10.0 * bondMax
            end
        end
    end

    local priorityObjectOffset = 0.0
    if lookAroundInfo.priorityObjectID then
        maxDistance = 1000.0
        if uniqueID == lookAroundInfo.priorityObjectID then
            priorityObjectOffset = 10.0
        end
    end

    local ownershipOffset = 0.0
    if uniqueID then
        ownershipOffset = serverSapien:getSapienOwnershipOfObject(sapien, uniqueID) * 10.0
    end

    local distanceHeuristic = distance * distanceMultiplierDueToRestOrSleepOrPrioritization

    if distanceHeuristic > maxDistance then
        return lookAI.minHeuristic
    end

    local distanceWeight = -(distanceHeuristic / mj:mToP(100.0)) * lookWeightCloseObjectByType[lookAtIntent]

    local randomOffset = rng:valueForUniqueID(uniqueID, distance * 10000000)


    local combinedHeursitic = distanceWeight + alreadySeenWeight + currentlyLookAtWeight + lookWeightOffsetByType[lookAtIntent] + contexturalOffset + moodDesireOffset + priorityObjectOffset + ownershipOffset + randomOffset * 0.05

    --[[--disabled--mj:objectLog(sapien.uniqueID, "combinedHeursitic:", combinedHeursitic, " distanceWeight:", distanceWeight, " alreadySeenWeight:", alreadySeenWeight
    , " currentlyLookAtWeight:", currentlyLookAtWeight, " lookWeightOffsetByType[lookAtIntent]:", lookWeightOffsetByType[lookAtIntent], " contexturalOffset:", contexturalOffset, " moodDesireOffset:", moodDesireOffset
    , " priorityObjectOffset:", priorityObjectOffset, " ownershipOffset:", ownershipOffset)]]

    return combinedHeursitic
end


local function checkSleep(sapien, lookAroundInfo, previousBestResult)
    if previousBestResult.heuristic > lookAI.minHeuristic then
        return previousBestResult
    end

    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }
    
    local function checkBed(info)
        
        if serverGOM:objectIsInaccessible(info.object) then
            return nil
        end

        local bedTribeID = info.object.sharedState.tribeID
        if bedTribeID ~= sapien.sharedState.tribeID then
            if serverWorld:tribeIsValidOwner(bedTribeID) then
                local relationshipSettings = serverWorld:getTribeRelationsSettings(bedTribeID, sapien.sharedState.tribeID)
                if not (relationshipSettings and relationshipSettings.allowBedUse) then
                    return nil
                end
            end
        end
            

        local cooldownKey = "sleep_" .. info.object.uniqueID
        if not lookAroundInfo.cooldowns[cooldownKey] then
            if not serverSapien:objectIsAssignedToOtherSapien(info.object, sapien.sharedState.tribeID, sapien, nil, true) then
                serverSapien:offsetSapienOwnershipOfObject(sapien, info.object.uniqueID, 0.1)
                local distance = info.distance or math.sqrt(info.distance2)
                local heuristic = lookHeuristic(sapien, lookAroundInfo, distance, info.object.uniqueID, lookAtIntents.types.sleep.index, false)

                if info.object.sharedState.covered then
                    heuristic = heuristic + 2.0
                end

                if gameObject.types[info.object.objectTypeIndex].isWarmBed then
                    heuristic = heuristic + 2.0
                end

                if heuristic > bestResult.heuristic and heuristic > previousBestResult.heuristic then
                    local newBestResult = {
                        heuristic = heuristic,
                        bestObjectInfo = {
                            lookAtIntent = lookAtIntents.types.sleep.index,
                            uniqueID = info.object.uniqueID,
                            object = info.object,
                            pos = info.object.pos,
                            assignObjectID = info.object.uniqueID,
                            assignObjectDistance = distance,
                        }
                    }
                    return newBestResult
                end
            else
                serverSapien:offsetSapienOwnershipOfObject(sapien, info.object.uniqueID, -1.0)
            end
        end
        return nil
    end

    if lookAroundInfo.sleepDesire >= desire.levels.moderate and (not sapien.sharedState.nomad) then
        --disabled--mj:objectLog(sapien.uniqueID, "looking for beds")
        if not lookAroundInfo.hasHeldObject then
            local maxDistanceMeters = 100.0

            local allBedInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.beds, sapien.pos, mj:mToP(maxDistanceMeters))
            for i,info in ipairs(allBedInfos) do
                info.object = serverGOM:getObjectWithID(info.objectID)
                if info.object then
                    local newBestResult = checkBed(info)
                    if newBestResult then
                        --disabled--mj:objectLog(sapien.uniqueID, "found bed:", newBestResult)
                        bestResult = newBestResult
                    end
                end
            end
        end
    end
    
    if bestResult.heuristic > previousBestResult.heuristic then
        return bestResult
    else
        return previousBestResult
    end
end


local function testWorkObject(sapien, lookAroundInfo, bestResult, object, distance2, planTypeIndex, matchesRequiredHeldObject, maintenanceTypeIndexOrNil, planStateOrNil)
    --disabled--mj:objectLog(sapien.uniqueID, "testWorkObject:", object.uniqueID, " matchesRequiredHeldObject:", matchesRequiredHeldObject)

    if planStateOrNil then
        if planStateOrNil.manualAssignedSapien then
            if sapien.uniqueID ~= planStateOrNil.manualAssignedSapien then
                return
            end
        end
    end

    if planTypeIndex == plan.types.clear.index then
        local vertID = object.sharedState.vertID
        if vertID then
            if not terrain:vertCanBeCleared(vertID) then
                planManager:removePlanStateFromTerrainVertForTerrainModification(vertID, plan.types.clear.index, sapien.sharedState.tribeID, nil)
                return
            end
        end
    elseif planTypeIndex == plan.types.fertilize.index then
        local vertID = object.sharedState.vertID
        if vertID then
            if not terrain:vertCanBeFertilized(vertID) then
                planManager:removePlanStateFromTerrainVertForTerrainModification(vertID, plan.types.fertilize.index, sapien.sharedState.tribeID, nil)
                return
            end
        end
    end

    if serverGOM:objectIsInaccessible(object) then
        --disabled--mj:objectLog(sapien.uniqueID, "objectIsInaccessible")
        return
    end


    if planTypeIndex == plan.types.storeObject.index or planTypeIndex == plan.types.transferObject.index then
        local resourceTypeIndex = nil
        if gameObject.types[object.objectTypeIndex].isStorageArea then
            resourceTypeIndex = serverStorageArea:quickFirstResourceTypeIndexToSeeIfCanCarryForRequiredPickup(object) --bit of a hack, but should work out OK. This is checked later anyway, it's just an optimization.
        else
            resourceTypeIndex = gameObject.types[object.objectTypeIndex].resourceTypeIndex
        end
        if not resourceTypeIndex then
            return
        end
        if serverSapien:getMaxCarryCount(sapien, resourceTypeIndex) <= 0 then
            return
        end
    end

    --[[if planTypeIndex == plan.types.transferObject.index then
        if gameObject.types[object.objectTypeIndex].isStorageArea then
            --mj:log("hi hi:", object.uniqueID, " planStateOrNil:", planStateOrNil, " maintenanceTypeIndexOrNil:", maintenanceTypeIndexOrNil)


            local nextTransferInfo = serverStorageArea:storageAreaTransferInfoIfRequiresPickup(sapien.sharedState.tribeID, object, sapien.uniqueID)
            if nextTransferInfo then
                --mj:log("nextTransferInfo:", nextTransferInfo)
                if serverLogistics:sapienAssignedCountHasReachedMaxForRoute(sapien.sharedState.tribeID, nextTransferInfo.routeID, sapien.uniqueID) then
                    return
                end
                --local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(sourceObject, sapien, plan.types.transferObject.index)
                --if planObjectSapienAssignmentInfo.available then
                --end
            else
                return
            end
        end
    end]]

   --[[ if planTypeIndex == plan.types.hunt.index or planTypeIndex == plan.types.dig.index or planTypeIndex == plan.types.chop.index or planTypeIndex == plan.types.mine.index then
        if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
            return nil
        end
    end]]


    if planTypeIndex == plan.types.haulObject.index then

        if not object.sharedState.waterRideable then
            if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, true) then
                return
            end
        end
    end

    if planStateOrNil then
        local constructableTypeIndex = planStateOrNil.constructableTypeIndex
        if constructableTypeIndex then
            local constructableType = constructable.types[constructableTypeIndex]
            if constructableType.disallowsLimitedAbilitySapiens then
                if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
                    return
                end
            end
        end

        if planTypeIndex == plan.types.research.index then
            local researchTypeIndex = planStateOrNil.researchTypeIndex
            if research.types[researchTypeIndex].disallowsLimitedAbilitySapiens then
                if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
                    return
                end
            end
        end
    end

    local objectDistance = 0.0
    if distance2 > 0.0 then
        objectDistance = math.sqrt(distance2)
    end
    
    --local heuristic = serverSapienAI:buildSiteOrStorageHeuristic(dotProduct, objectDistance)
    local heuristic = nil
    if sapien.sharedState.manualAssignedPlanObject == object.uniqueID then
        heuristic = 100.0
    else
        heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, object.uniqueID, lookAtIntents.types.work.index, planStateOrNil and planStateOrNil.manuallyPrioritized)
    end
    
    if matchesRequiredHeldObject and planTypeIndex ~= plan.types.storeObject.index and planTypeIndex ~= plan.types.transferObject.index then
        heuristic = heuristic + 2.0
    end
    
    if (planTypeIndex == plan.types.transferObject.index or planTypeIndex == plan.types.haulObject.index) and sapien.privateState.logisticsInfo then
        heuristic = heuristic + 2.0

    end

    local priorityOffset = 0.0
    if planTypeIndex then
        local planPriorityOffset = plan.types[planTypeIndex].priorityOffset
        if planPriorityOffset then
            priorityOffset = planPriorityOffset
        end
    end

    if planStateOrNil and planStateOrNil.manuallyPrioritized then
        priorityOffset = priorityOffset + 10.0
    end

    heuristic = heuristic + priorityOffset

    
    local skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, maintenanceTypeIndexOrNil, planStateOrNil, true)

    --disabled--mj:objectLog(sapien.uniqueID, "skillOffset:", skillOffset)
    if skillOffset > lookAI.minHeuristic then

        local function addDistance(resourceDistance)
            objectDistance = objectDistance + resourceDistance
            heuristic = heuristic - (resourceDistance / mj:mToP(100.0))
            return true
        end

        local function addResourceInfoDistance(resourceInfo)
            local resourceDistance = math.sqrt(resourceInfo.distance2)
            if not addDistance(resourceDistance) then
                return nil
            end
        end

        local function getResourceInfo(objectTypes) --this used to cache the found resource info as an optimization
            
            local resourceInfo = nil
            if not objectTypes or not objectTypes[1] then
                return nil
            end

            --[[local unsavedState = serverGOM:getUnsavedPrivateState(object)
            if unsavedState.requiredObjectInfoResourceInfo then
                local requiredObjectInfoResourceInfo = unsavedState.requiredObjectInfoResourceInfo
                local cachedResourceInfo = requiredObjectInfoResourceInfo.resourceInfo
                if requiredObjectInfoResourceInfo.firstObjectType ~= objectTypes[1] then
                    unsavedState.requiredObjectInfoResourceInfo = nil
                elseif not serverResourceManager:getResourceInfoForObjectWithID() then
                    unsavedState.requiredObjectInfoResourceInfo = nil
                else
                    resourceInfo = cachedResourceInfo
                end
            end

            if not unsavedState.requiredObjectInfoResourceInfo then]]
                resourceInfo = serverResourceManager:findResourceForSapien(sapien, objectTypes, {
                    allowStockpiles = true,
                    allowGather = true,
                    goalObjectPos = object.pos,
                    takePriorityOverStoreOrders = true,
                })
                --[[ if not resourceInfo then
                    return nil
                end]]
                --[[unsavedState.requiredObjectInfoResourceInfo = {
                    resourceInfo = resourceInfo,
                    firstObjectType = objectTypes[1],
                }]]
            -- end
            return resourceInfo
        end

        ----disabled--mj:objectLog(sapien.uniqueID, "dave a")

        if maintenanceTypeIndexOrNil and (not matchesRequiredHeldObject) then
            local maintenanceType = maintenance.types[maintenanceTypeIndexOrNil]
            if maintenanceType.planTypeIndex == plan.types.addFuel.index then
                local fuelObjectTypes = serverFuel:requiredFuelObjectTypesArrayForObject(object, sapien.sharedState.tribeID)
                local resourceInfo = getResourceInfo(fuelObjectTypes)
                if not resourceInfo then
                    return
                end
                addResourceInfoDistance(resourceInfo)
            elseif maintenanceType.planTypeIndex == plan.types.deliverToCompost.index then
                local compostObjectTypes = serverCompostBin:requiredCompostObjectTypesArrayForObject(object, sapien.sharedState.tribeID)
                local resourceInfo = getResourceInfo(compostObjectTypes)
                if not resourceInfo then
                    return
                end
                addResourceInfoDistance(resourceInfo)
            end
        end
        
        if planStateOrNil and (not matchesRequiredHeldObject) then
            local constructableTypeIndex = planStateOrNil.constructableTypeIndex
            local constructableType = constructable.types[constructableTypeIndex]
            if constructableType then
                local requiredObjectInfo = serverSapienAI:getRequiredObjectInfoForSapienForConstructableOrder(sapien, object, planStateOrNil)
                --disabled--mj:objectLog(sapien.uniqueID, "found constructableType requiredObjectInfo:", requiredObjectInfo)
                if requiredObjectInfo then
                    local resourceInfo = getResourceInfo(requiredObjectInfo.objectTypes)
                    --disabled--mj:objectLog(sapien.uniqueID, "resourceInfo:", resourceInfo)
                    if not resourceInfo then
                        return
                    end
                    addResourceInfoDistance(resourceInfo)
                end
            else
                if planStateOrNil.requiredTools then
                    local toolGameObjectTypes = planManager:getGameObjectTypeIndexesForRequiredTools(planStateOrNil.requiredTools, object, planStateOrNil)
                    local resourceInfo = getResourceInfo(toolGameObjectTypes)
                    if not resourceInfo then
                        return
                    end
                    addResourceInfoDistance(resourceInfo)
                end
            end
        end

        local function getStorageMatchInfo(isPrioritized)
            local options = nil
            if lookAroundInfo.pickedUpObjectStorageAreaTransferInfo then
                options = {
                    allowTradeRequestsMatchingResourceTypeIndex = lookAroundInfo.pickedUpObjectStorageAreaTransferInfo.resourceTypeIndex,
                    allowQuestsMatchingResourceTypeIndex = lookAroundInfo.pickedUpObjectStorageAreaTransferInfo.resourceTypeIndex,
                }
            end

            if isPrioritized or (lookAroundInfo.pickedUpObjectPlanState and lookAroundInfo.pickedUpObjectPlanState.manuallyPrioritized) then
                if not options then
                    options = {}
                end
                options.maxDistance2 = planManager.maxAssignedOrPrioritizedPlanDistance2
            end

            local unsavedState = serverGOM:getUnsavedPrivateState(object)
            if unsavedState.cachedStorageMatchInfo then
                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(unsavedState.cachedStorageMatchInfo.object.uniqueID, object.objectTypeIndex, sapien.sharedState.tribeID, options)
                unsavedState.cachedStorageMatchInfo = matchInfo
                if matchInfo then
                    return matchInfo
                end
            end
            if not unsavedState.cachedStorageMatchInfo then
                local matchInfo = serverStorageArea:bestStorageAreaForObjectType(sapien.sharedState.tribeID, object.objectTypeIndex, object.pos, options)
                if matchInfo then
                    unsavedState.cachedStorageMatchInfo = matchInfo
                end
                return matchInfo
            end
        end

        if planTypeIndex == plan.types.storeObject.index then
            heuristic = heuristic + 0.1 --try to clean up the place, it's getting messy around here
            --disabled--mj:objectLog(sapien.uniqueID, "planTypeIndex == plan.types.storeObject.index increase:", heuristic, " object:", object.uniqueID)

            local evolution = evolvingObject.evolutions[object.objectTypeIndex]
            if evolution and evolution.categoryIndex ~= evolvingObject.categories.dry.index then -- bit of a hack, primary purpose is to prioritize storing alpaca carcass over the spears used to hunt it
                heuristic = heuristic + 0.1
            end

            local isPrioritized = (planStateOrNil and (planStateOrNil.manuallyPrioritized or planStateOrNil.manualAssignedSapien))

            local matchInfo = getStorageMatchInfo(isPrioritized)
            if not matchInfo then
                return
            end
            local storageObject = matchInfo.object
            if (not isPrioritized) then
                local storageDistance = matchInfo.distanceForOptimization or length(storageObject.pos - object.pos)
                if not addDistance(storageDistance) then
                    return nil
                end
            end
            --disabled--mj:objectLog(sapien.uniqueID, "planTypeIndex == plan.types.storeObject.index after distance added:", heuristic, " object:", object.uniqueID)
        end
        
        if planTypeIndex == plan.types.gather.index or planTypeIndex == plan.types.storeObject.index then --prioritize food
            local resourceTypeIndex = gameObject.types[object.objectTypeIndex].resourceTypeIndex

            if resourceTypeIndex and resource.types[resourceTypeIndex].foodValue then
                heuristic = heuristic + 1.0
                --disabled--mj:objectLog(sapien.uniqueID, "resourceTypeIndex is food:", heuristic, " object:", object.uniqueID)
            elseif planStateOrNil then
                local objectTypeIndex = planStateOrNil.objectTypeIndex
                if objectTypeIndex then
                    resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                    if resourceTypeIndex and resource.types[resourceTypeIndex].foodValue then
                        heuristic = heuristic + 1.0
                        --disabled--mj:objectLog(sapien.uniqueID, "planStateOrNil.objectTypeIndex is food:", heuristic, " object:", object.uniqueID)
                    end
                end
            end
        end
        
        if planTypeIndex == plan.types.butcher.index then --prioritize food
            heuristic = heuristic + 1.0
        end

        if planStateOrNil then --prioritize food
            local constructableTypeIndex = planStateOrNil.constructableTypeIndex
            local constructableType = constructable.types[constructableTypeIndex]
            if constructableType and constructableType.isFoodPreperation then
                heuristic = heuristic + 1.0
            end
        end

        heuristic = heuristic + skillOffset

        --disabled--mj:objectLog(sapien.uniqueID, "testWorkObject heuristic:", heuristic, " bestResult.heuristic:", bestResult.heuristic )
        if heuristic > bestResult.heuristic then

            local planObjectID = nil
            if planTypeIndex == plan.types.haulObject.index then
                planObjectID = object.uniqueID
            end

            local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, object, {
                planTypeIndex = planTypeIndex,
                planObjectID = planObjectID,
            }, planStateOrNil)

            if planObjectSapienAssignmentInfo.available then
            -- if not serverSapienAI:otherSapienIsInViewAndHeadingTowardsAndCloser(sapien.uniqueID, object, nil) then
                --disabled--mj:objectLog(sapien.uniqueID, "heuristic > bestResult.heuristic:", heuristic, " for object:", object.uniqueID)
                --mj:log("testPlanObject heuristic is best:", heuristic)
                bestResult.heuristic = heuristic
                bestResult.bestObjectInfo = {
                    lookAtIntent = lookAtIntents.types.work.index,
                    uniqueID = object.uniqueID,
                    object = object,
                    pos = object.pos,
                    planTypeIndex = planTypeIndex,
                    assignObjectID = object.uniqueID,
                    assignObjectDistance = objectDistance,
                }
            end
        end
    end
end

local function testLogistics(sapien, bestResult, lookAroundInfo, previousBestResult)

    if lookAroundInfo.cantDoMostWorkDueToEffects then
        return
    end
    --[[local sapienLogisticsInfo = {
        routeID = storageAreaTransferInfo.routeID,
        lastDestinationObjectID = storageAreaTransferInfo.destinationObjectID,
        lastDestinationIndex = storageAreaTransferInfo.destinationIndex
    }]]
    --disabled--mj:objectLog(sapien.uniqueID, "testLogistics")

    local function exitLogisticsRoute()
        sapien.privateState.logisticsInfo = nil
        serverLogistics:setSapienRouteAssignment(sapien.uniqueID, sapien.sharedState.tribeID, nil)
    end
    
    if not lookAroundInfo.heldObjectTypeIndex then
        local logisticsInfo = sapien.privateState.logisticsInfo
        if not logisticsInfo then
            return
        end

        --note: unclear whether the rest of the code in this function is needed anymore, or even works

        --[[if serverLogistics:sapienAssignedCountHasReachedMaxForRoute(sapien.sharedState.tribeID, logisticsInfo.routeID, sapien.uniqueID) then
            exitLogisticsRoute()
            return
        end]]


        --[[local prevDestinationObject = nil
        if logisticsInfo.lastDestinationObjectID then
            prevDestinationObject = serverGOM:getObjectWithID(logisticsInfo.lastDestinationObjectID)
        end
        
        if prevDestinationObject and not serverGOM:objectIsInaccessible(prevDestinationObject) then
            --disabled--mj:objectLog(sapien.uniqueID, "prevDestinationObject and not serverGOM:objectIsInaccessible(prevDestinationObject)")
            
            local haulDestinationObject = serverLogistics:getDestinationIfObjectRequiresHaul(sapien.sharedState.tribeID, prevDestinationObject) --getting this when shouldnt
            if haulDestinationObject then
                --disabled--mj:objectLog(sapien.uniqueID, "got serverLogistics haulDestinationObject")
                --disabled--mj:objectLog(prevDestinationObject.uniqueID, "got serverLogistics haulDestinationObject A")
                testWorkObject(sapien, 
                lookAroundInfo, 
                bestResult, 
                prevDestinationObject, 
                length2(sapien.pos - prevDestinationObject.pos), 
                plan.types.haulObject.index, 
                false, 
                maintenance.types.storageTransferHaul.index, 
                nil)
            end
        end

        if bestResult.heuristic > lookAI.minHeuristic then
            --disabled--mj:objectLog(sapien.uniqueID, "prevDestinationObject found result")
            return
        end]]

        exitLogisticsRoute()
    end

end

local function heldObjectIsRequiredInfoForPlanState(sapien, planObject, planState, heldObjectTypeIndex)

    local inventoryLocation = serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(planObject, heldObjectTypeIndex, planState, sapien.sharedState.tribeID)
    
    --disabled--mj:objectLog(sapien.uniqueID, "heldObjectIsRequiredInfoForPlanState heldObjectTypeIndex:", heldObjectTypeIndex, " inventoryLocation:",  inventoryLocation, " planState:", planState)

    if inventoryLocation then
        if inventoryLocation == objectInventory.locations.tool.index then
            return {
                isTool = true
            }
        elseif inventoryLocation == objectInventory.locations.availableResource.index then
            return {}
        end
    end

    return nil
end


local function testMaintenance(sapien, bestResult, lookAroundInfo, previousBestResult)
    if sapien.sharedState.manualAssignedPlanObject or lookAroundInfo.cantDoMostWorkDueToEffects then
        return
    end

    --disabled--mj:objectLog(sapien.uniqueID, "testMaintenance")

    local allMaintenanceObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.maintenance, sapien.pos, mj:mToP(400.0))
    for i,objectInfo in ipairs(allMaintenanceObjectInfos) do
        
        local object = serverGOM:getObjectWithID(objectInfo.objectID)
        ----disabled--mj:objectLog(object.uniqueID, "testMaintenance")
        
        if object and not serverGOM:objectIsInaccessible(object) then
            if not lookAroundInfo.heldObjectTypeIndex or serverGOM:objectTypeIndexIsRequiredForMaintenanceObject(object, lookAroundInfo.heldObjectTypeIndex, sapien.sharedState.tribeID) then
             --disabled--mj:objectLog(sapien.uniqueID, "checking maintenance object:", object.uniqueID)
                local cooldownKey = "m_" .. object.uniqueID --very bad as objects that dont have a plan will add a cooldown
                if not lookAroundInfo.cooldowns[cooldownKey] then
                -- --disabled--mj:objectLog(sapien.uniqueID, "no cooldown")
                    local maintenanceTypeIndexes = maintenance:maintenanceTypeIndexesForObjectTypeIndex(object.objectTypeIndex)
                    for j, maintenanceTypeIndex in ipairs(maintenanceTypeIndexes) do
                     --disabled--mj:objectLog(object.uniqueID, "test maintenanceTypeIndex:", maintenanceTypeIndex)
                        local maintenanceType = maintenance.types[maintenanceTypeIndex]
                        local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(object, sapien, maintenanceType.planTypeIndex)
                        --disabled--mj:objectLog(object.uniqueID, "planObjectSapienAssignmentInfo:", planObjectSapienAssignmentInfo)
                        local available = planObjectSapienAssignmentInfo.available
                        --[[if available then
                            if planObjectSapienAssignmentInfo.assignedSapienID then
                                -- in this case we are going to one object, while the plan object is another, so assigning here might incorrectly unassign a sapien that is closer to the pickup location. This needs to be handled better, ideally comparing distance to the pickup location.
                                if maintenanceType.planTypeIndex == plan.types.addFuel.index or maintenanceType.planTypeIndex == plan.types.deliverToCompost.index then
                                    available = false
                                end
                            end
                        end]]

                        if available then
                            if maintenance:maintenanceIsRequiredOfType(sapien.sharedState.tribeID, object, maintenanceTypeIndex, sapien.uniqueID) then
                                --disabled--mj:objectLog(object.uniqueID, "maintenance:maintenanceIsRequiredOfType:", maintenanceTypeIndex, " lookAroundInfo:", lookAroundInfo, " maintenanceType.planTypeIndex:", maintenanceType.planTypeIndex)
                                --disabled--mj:objectLog(sapien.uniqueID, "maintenance:maintenanceIsRequiredOfType:", maintenanceTypeIndex, " lookAroundInfo:", lookAroundInfo, " maintenanceType.planTypeIndex:", maintenanceType.planTypeIndex)
                                local matchesRequiredHeldObject = (lookAroundInfo.heldObjectTypeIndex ~= nil)
                                if maintenanceType.planTypeIndex == plan.types.addFuel.index or 
                                maintenanceType.planTypeIndex == plan.types.deliverToCompost.index or
                                maintenanceType.planTypeIndex == plan.types.destroyContents.index or
                                maintenanceType.planTypeIndex == plan.types.transferObject.index or
                                maintenanceType.planTypeIndex == plan.types.haulObject.index then
                                --  --disabled--mj:objectLog(sapien.uniqueID, "maintenanceType.planTypeIndex == plan.types.addFuel.index")
                                    --disabled--mj:objectLog(object.uniqueID, "testMaintenance win, testWorkObject called")
                                    testWorkObject(sapien, lookAroundInfo, bestResult, object, objectInfo.distance2, maintenanceType.planTypeIndex, matchesRequiredHeldObject, maintenanceTypeIndex, nil)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function testPlans(sapien, bestResult, lookAroundInfo, previousBestResult)
    --disabled--mj:objectLog(sapien.uniqueID, "testPlans")
    --local searchRadiusToUse = planManager.maxPlanDistance--sapien.privateState.searchRadiusToUse or mj:mToP(200.0)
    --local searchRadiusToUse2 = searchRadiusToUse * searchRadiusToUse

    local goodEnoughSearchRadiusToUseClose = mj:mToP(20.0)
    local goodEnoughSearchRadiusToUseFar = mj:mToP(80.0)

   -- local allPlanObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.plans, sapien.pos, mj:mToP(searchRadiusToUse))
    --local debugAccessibleCOunt = 0
    --local debugHasPlanStatesCOunt = 0
    --local debugCooldownCOunt = 0
   -- local debugAssignedCOunt = 0
    --for i,objectInfo in ipairs(allPlanObjectInfos) do
    local i = 0

    local function testPlanObject(planObject)
        if not planObject then
            return false
        end

        i = i + 1
        if i > 6 then
            --disabled--mj:objectLog(sapien.uniqueID, "i > 6")
            return false
        end

        if i > 1 and bestResult.heuristic > lookAI.minHeuristic and bestResult.assignObjectDistance then
            if bestResult.assignObjectDistance < goodEnoughSearchRadiusToUseFar then
                if i > 3 or bestResult.assignObjectDistance < goodEnoughSearchRadiusToUseClose then
                    --disabled--mj:objectLog(sapien.uniqueID, "found best result from first 10 test:", bestResult)
                    return false
                end
            end
        end

        ----disabled--mj:objectLog(planObject.uniqueID, "testing by sapien:", sapien.uniqueID)

        if not serverGOM:objectIsInaccessible(planObject) then
            --debugAccessibleCOunt = debugAccessibleCOunt + 1
            local cooldownKey = "plan_" .. planObject.uniqueID
            local planStates = planManager:getPlanStatesForObjectForSapien(planObject, sapien) -- this calls serverSapien:objectIsAssignedToOtherSapien
            --disabled--mj:objectLog(sapien.uniqueID, "test planObject:", planObject.uniqueID, " has planStates:", planStates ~= nil)

            if planStates then
                --debugHasPlanStatesCOunt = debugHasPlanStatesCOunt + 1
                -- mj:log("planStates")
                if not lookAroundInfo.cooldowns[cooldownKey] or sapien.sharedState.manualAssignedPlanObject == planObject.uniqueID then
                    --disabled--mj:objectLog(sapien.uniqueID, "no lookAroundInfo.cooldowns[cooldownKey]:", planObject.uniqueID)
                    --debugCooldownCOunt = debugCooldownCOunt + 1
                    local hasHeldObject = (lookAroundInfo.heldObjectTypeIndex ~= nil)
                    local distance2 = length2(planObject.pos - sapien.pos)
                    for j,planState in ipairs(planStates) do
                        local maxDistance2 = planManager.maxPlanDistance2
                        if planState.manuallyPrioritized or sapien.uniqueID == planState.manualAssignedSapien then
                            maxDistance2 = planManager.maxAssignedOrPrioritizedPlanDistance2
                        end
                        if distance2 < maxDistance2 then
                        --disabled--mj:objectLog(sapien.uniqueID, "planState:", planState)
                            if (not lookAroundInfo.cantDoMostWorkDueToEffects) or statusEffect:canDoPlanTypeDespiteMostWorkDisabled(sapien.sharedState.statusEffects, planState.planTypeIndex) then
                                local matchesHeldObjectIfPresent = true
                                if hasHeldObject then
                                    local requiredInfo = heldObjectIsRequiredInfoForPlanState(sapien, planObject, planState, lookAroundInfo.heldObjectTypeIndex)
                                    --disabled--mj:objectLog(sapien.uniqueID, "requiredInfo:", requiredInfo)
                                    
                                    if requiredInfo then
                                        matchesHeldObjectIfPresent = true
                                    else
                                        matchesHeldObjectIfPresent = false
                                    end
                                end
                                if matchesHeldObjectIfPresent then
                                    --disabled--mj:objectLog(sapien.uniqueID, "matchesHeldObjectIfPresent calling testWorkObject planState:", planState)
                                    testWorkObject(sapien, lookAroundInfo, bestResult, planObject, distance2, planState.planTypeIndex, hasHeldObject, nil, planState)
                                end
                            end
                        end
                    end
                end
            --[[elseif mj.debugObject then
                if serverSapien:objectIsAssignedToOtherSapien(planObject, sapien.sharedState.tribeID, nil, sapien) then
                    debugAssignedCOunt = debugAssignedCOunt + 1
                end]]
            else
                i = i - 1 --lets not count objects that have no valid plan states
                lookAroundInfo.cooldowns[cooldownKey] = lookAI.planCooldown
            end
        end

        return true
    end

    local foundPriorityResult = false

    if sapien.sharedState.manualAssignedPlanObject then
        --disabled--mj:objectLog(sapien.uniqueID, "manualAssignedPlanObject")
        local priorityObject = serverGOM:getObjectWithID(sapien.sharedState.manualAssignedPlanObject)
        if priorityObject then
            --disabled--mj:objectLog(sapien.uniqueID, "priorityObject")
            testPlanObject(priorityObject)
            foundPriorityResult = bestResult.heuristic > previousBestResult.heuristic
            --disabled--mj:objectLog(sapien.uniqueID, "foundPriorityResult:", foundPriorityResult, " heuristic:", bestResult.heuristic)
        end
        if not foundPriorityResult then
            if lookAroundInfo.heldObjectTypeIndex ~= nil then
                --[[--disabled--mj:objectLog(sapien.uniqueID, "calling serverSapien:dropHeldInventoryImmediately") --commented out 4/5/22, might cause issues. They were dropping an object, then needing to remove it to use manually assigned campfire, then dropping again
                serverSapien:dropHeldInventoryImmediately(sapien)
                return]]
                serverSapienAI:addOrderToDisposeOfHeldItem(sapien)
                return
            else
                --disabled--mj:objectLog(sapien.uniqueID, "removing manualAssignedPlanObject")
                sapien.sharedState:remove("manualAssignedPlanObject")
                if priorityObject then
                    planManager:removeManualAssignmentsForPlanObjectForSapien(priorityObject,sapien)
                end
            end
        end
        return
    end

    if lookAroundInfo.cantDoMostWorkDueToEffects then
        return
    end

    if not foundPriorityResult and lookAroundInfo.priorityObjectID then
        local priorityObject = serverGOM:getObjectWithID(lookAroundInfo.priorityObjectID)
        if priorityObject then
            testPlanObject(priorityObject)
            foundPriorityResult = bestResult.heuristic > previousBestResult.heuristic
        end
    end

    
    if not foundPriorityResult then
        testMaintenance(sapien, bestResult, lookAroundInfo, previousBestResult)
        --disabled--mj:objectLog(sapien.uniqueID, "after testMaintenance bestResult:", bestResult)
    end


    if not foundPriorityResult then
        planManager:iteratePlans(sapien.sharedState.tribeID, testPlanObject, sapien)
    --else
        ----disabled--mj:objectLog(sapien.uniqueID, "using foundPriorityResult. bestResult:", bestResult)
    end

    --disabled--mj:objectLog(sapien.uniqueID, "after iteratePlans bestResult:", bestResult)

    --disabled--mj:objectLog(sapien.uniqueID, "checked planInfo count:", i)
    ----disabled--mj:objectLog(sapien.uniqueID, "accessibleCOunt:", debugAccessibleCOunt, " hasPlanStatesCOunt:", debugHasPlanStatesCOunt, " no cooldownCOunt:", debugCooldownCOunt, " assignedCOunt:", debugAssignedCOunt)
end

local function checkWork(sapien, lookAroundInfo, previousBestResult)
    if lookAroundInfo.isStuck then
        --disabled--mj:objectLog(sapien.uniqueID, "checkWork lookAroundInfo.isStuck")
        return previousBestResult
    end
    --disabled--mj:objectLog(sapien.uniqueID, "checkWork")
    if previousBestResult.heuristic > lookAI.minHeuristic then
        return previousBestResult
    end
    
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

    
    if sapien.sharedState.resting and (not sapien.sharedState.manualAssignedPlanObject) then
        return previousBestResult
    end
    
    if sapien.privateState.logisticsInfo and (not lookAroundInfo.cantDoMostWorkDueToEffects) then
        testLogistics(sapien, bestResult, lookAroundInfo, previousBestResult)
        if bestResult.heuristic > previousBestResult.heuristic and bestResult.heuristic > lookAI.minHeuristic  then
            return bestResult
        end
    end

    testPlans(sapien, bestResult, lookAroundInfo, previousBestResult)
    

    if bestResult.heuristic > previousBestResult.heuristic then
        return bestResult
    else
        return previousBestResult
    end
end

local function checkHeldObjectDisposal(sapien, lookAroundInfo, previousBestResult, allowWorkPlans)

    --disabled--mj:objectLog(sapien.uniqueID, "checkHeldObjectDisposal")

    local sharedState = sapien.sharedState
    
   --[[ if statusEffect:cantDoMostWorkDueToEffects(sharedState.statusEffects) then
        --disabled--mj:objectLog(sapien.uniqueID, "returning no work in lookAround due to status effects")
        return previousBestResult
    end]]
    
    if lookAI:checkIsTooColdAndBusyWarmingUp(sapien) then
        return previousBestResult
    end
    
    if (not lookAroundInfo.hasHeldObject) then
        return previousBestResult
    end
    
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

    local hasManualAssignedPlanObject = (sharedState.manualAssignedPlanObject ~= nil)
    --[[if sapien.sharedState.manualAssignedPlanObject then
        local priorityObject = serverGOM:getObjectWithID(sapien.sharedState.manualAssignedPlanObject)
        if priorityObject then
            testPlanObject(priorityObject)
            foundPriorityResult = bestResult.heuristic > previousBestResult.heuristic
        end
        if not foundPriorityResult then
            sapien.sharedState:remove("manualAssignedPlanObject")
            if priorityObject then
                planManager:removeManualAssignmentsForPlanObjectForSapien(priorityObject,sapien)
            end
        end
    end]]


    local function testPlanObjectForDisposal(planObjectID)
        if not (lookAroundInfo.cooldowns["plan_" .. planObjectID] or lookAroundInfo.cooldowns["m_" .. planObjectID]) then --required, cooldowns must be respected, they might be due to a cancel command
            local planObject = serverGOM:getObjectWithID(planObjectID)
            if planObject then
                --disabled--mj:objectLog(sapien.uniqueID, "planObject loaded")
                local planStates = planManager:getPlanStatesForObjectForSapien(planObject, sapien) -- this calls serverSapien:objectIsAssignedToOtherSapien
                if planStates then
                    --disabled--mj:objectLog(sapien.uniqueID, "planStates:", planStates)
                    for j,planState in ipairs(planStates) do
                        local foundPlanObjectInfo = heldObjectIsRequiredInfoForPlanState(sapien, planObject, planState, lookAroundInfo.heldObjectTypeIndex)
                        if foundPlanObjectInfo then
                            --disabled--mj:objectLog(sapien.uniqueID, "foundPlanObjectInfo:", foundPlanObjectInfo, " lookAroundInfo.cantDoMostWorkDueToEffects:", lookAroundInfo.cantDoMostWorkDueToEffects, " statusEffect:canDoPlanTypeDespiteMostWorkDisabled(sapien.sharedState.statusEffects, planState.planTypeIndex):", statusEffect:canDoPlanTypeDespiteMostWorkDisabled(sapien.sharedState.statusEffects, planState.planTypeIndex))
                            if (not lookAroundInfo.cantDoMostWorkDueToEffects) or statusEffect:canDoPlanTypeDespiteMostWorkDisabled(sapien.sharedState.statusEffects, planState.planTypeIndex) then
                                local distance2 = length2(planObject.pos - sapien.pos)
                                testWorkObject(sapien, lookAroundInfo, bestResult, planObject, distance2, planState.planTypeIndex, true, nil, planState)
                                break
                            end
                        end
                    end
                end
                --disabled--mj:objectLog(sapien.uniqueID, "bestResult.heuristic:", bestResult.heuristic)

                if (not lookAroundInfo.cantDoMostWorkDueToEffects) then
                    if bestResult.heuristic <= lookAI.minHeuristic then
                        local maintenanceTypeIndexes = maintenance:maintenanceTypeIndexesForObjectTypeIndex(planObject.objectTypeIndex)
                        if maintenanceTypeIndexes then
                            if serverGOM:objectTypeIndexIsRequiredForMaintenanceObject(planObject, lookAroundInfo.heldObjectTypeIndex, sapien.sharedState.tribeID) then
                                for j, maintenanceTypeIndex in ipairs(maintenanceTypeIndexes) do
                                    if maintenance:maintenanceIsRequiredOfType(sapien.sharedState.tribeID, planObject, maintenanceTypeIndex, sapien.uniqueID) then
                                        local distance2 = length2(planObject.pos - sapien.pos)
                                        --testWorkObject(planObject, distance2, plan.types.addFuel.index, true, maintenanceTypeIndex, nil)
                                        testWorkObject(sapien, lookAroundInfo, bestResult, planObject, distance2, maintenance.types[maintenanceTypeIndex].planTypeIndex, true, maintenanceTypeIndex, nil)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not hasManualAssignedPlanObject then
        local pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder = (lookAroundInfo.pickedUpObjectOrderTypeIndex == order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index)
        if pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder then
            --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder")
            local heldItemPlanState = lookAroundInfo.pickedUpObjectPlanState
            if heldItemPlanState then
                if heldItemPlanState.requiresCraftAreaGroupTypeIndexes or heldItemPlanState.requiresTerrainBaseTypeIndexes or heldItemPlanState.requiresShallowWater then
                    if (not lookAroundInfo.cantDoMostWorkDueToEffects) or statusEffect:canDoPlanTypeDespiteMostWorkDisabled(sapien.sharedState.statusEffects, heldItemPlanState.planTypeIndex) then
                        --disabled--mj:objectLog(sapien.uniqueID, "heldItemPlanState.requiresCraftAreaGroupTypeIndexes or requiresTerrainBaseTypeIndexes")
                        if heldItemPlanState.requiresShallowWater then
                            local suitableTerrainVertID = heldItemPlanState.suitableTerrainVertID or terrain:closeVertIDWithinRadiusNextToWater(sapien.pos, serverResourceManager.storageResourceMaxDistance)
                            if suitableTerrainVertID then
                                local vert = terrain:getVertWithID(suitableTerrainVertID)
                                if vert then
                                    local planObjectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
                                    local objectDistance = length(vert.pos - sapien.pos)
                                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, suitableTerrainVertID, lookAtIntents.types.work.index, false) + 200.0
                                    --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder (requiresShallowWater) heuristic:", heuristic, " bestResult.heuristic:", bestResult.heuristic)
                                    if heuristic > bestResult.heuristic then
                                        local planObject = serverGOM:getObjectWithID(planObjectID)
                                        --mj:log("storage heuristic is best:", heuristic)
                                        bestResult.heuristic = heuristic
                                        bestResult.bestObjectInfo = {
                                            lookAtIntent = lookAtIntents.types.work.index,
                                            uniqueID = planObject.uniqueID,
                                            object = planObject,
                                            pos = planObject.pos,
                                            isCraftingHeldObjectElsewhere = true,
                                        }
                                    end
                                end
                            end
                        elseif heldItemPlanState.requiresCraftAreaGroupTypeIndexes then
                            local craftAreas = serverCraftArea:getAllCraftAreasAvailable(sapien, heldItemPlanState.requiresCraftAreaGroupTypeIndexes)
                            if craftAreas then
                                --disabled--mj:objectLog(sapien.uniqueID, "found some craft areas")
                                for i,craftAreaInfo in ipairs(craftAreas) do
                                    local craftArea = craftAreaInfo.object
                                    if not serverGOM:objectIsInaccessible(craftArea) then
                                        local cooldownKey = "plan_" .. craftArea.uniqueID
                                        if not lookAroundInfo.cooldowns[cooldownKey] then
                                            local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, craftArea, nil, heldItemPlanState)
                                            if planObjectSapienAssignmentInfo.available then
                                                local objectDistance = length(craftArea.pos - sapien.pos)
                                                local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, craftArea.uniqueID, lookAtIntents.types.work.index, false) + 200.0
                                                --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder heuristic:", heuristic, " bestResult.heuristic:", bestResult.heuristic)
                                                if heuristic > bestResult.heuristic then
                                                    --mj:log("storage heuristic is best:", heuristic)
                                                    bestResult.heuristic = heuristic
                                                    bestResult.bestObjectInfo = {
                                                        lookAtIntent = lookAtIntents.types.work.index,
                                                        uniqueID = craftArea.uniqueID,
                                                        object = craftArea,
                                                        pos = craftArea.pos,
                                                        isCraftingHeldObjectElsewhere = true,
                                                        assignObjectID = craftArea.uniqueID,
                                                        assignObjectDistance = objectDistance,
                                                    }
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            local function testVertID(vertID)
                                --disabled--mj:objectLog(sapien.uniqueID, "testVertID:", vertID)
                                local cooldownKey = "plan_" .. vertID
                                if not lookAroundInfo.cooldowns[cooldownKey] then
                                    --disabled--mj:objectLog(sapien.uniqueID, "testVertID b")
                                    local vert = terrain:getVertWithID(vertID)
                                    if vert then
                                        --mj:log("distance from baseVert to offsetVert is:", mj:pToM(mjm.length(vert.pos) - mjm.length(vert.basePos)))

                                        --local planObjectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
                                        local planObjectID = terrain:getObjectIDForTerrainModificationForVertex(vert) --first just check for existing
                                        if planObjectID then
                                            testPlanObjectForDisposal(planObjectID) --first check against existing plans, maybe we are holding an object for a vert that already has a plan state

                                            --disabled--mj:objectLog(sapien.uniqueID, "bestResult:", bestResult)
                                            if bestResult.heuristic > previousBestResult.heuristic and bestResult.bestObjectInfo and bestResult.bestObjectInfo.uniqueID == planObjectID then
                                                --disabled--mj:objectLog(sapien.uniqueID, "bestResult win")
                                                return true
                                            end
                                        else
                                            planObjectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
                                        end
                                        
                                        --disabled--mj:objectLog(sapien.uniqueID, "testVertID planObjectID:", planObjectID, " vertID:", vertID)
                                        local planObject = serverGOM:getObjectWithID(planObjectID)
                                        if planObject and (not serverGOM:objectIsInaccessible(planObject)) then
                                            --disabled--mj:objectLog(sapien.uniqueID, "testVertID c")
                                            local planObjectSapienAssignmentInfo = nil
                                            if planObject then
                                                planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, planObject, nil, heldItemPlanState)
                                            end

                                            if (not planObjectSapienAssignmentInfo) or planObjectSapienAssignmentInfo.available then
                                                --disabled--mj:objectLog(sapien.uniqueID, "testVertID d")
                                                local objectDistance = length(vert.pos - sapien.pos)
                                                --if (not planObject) then
                                                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, vertID, lookAtIntents.types.work.index, false) + 200.0
                                                    --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder (terrain vert) heuristic:", heuristic, " bestResult.heuristic:", bestResult.heuristic)
                                                    if heuristic > bestResult.heuristic then
                                                        if not planObject then
                                                            planObjectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
                                                            planObject = serverGOM:getObjectWithID(planObjectID)
                                                        end
                                                        --mj:log("storage heuristic is best:", heuristic)
                                                        bestResult.heuristic = heuristic
                                                        bestResult.bestObjectInfo = {
                                                            lookAtIntent = lookAtIntents.types.work.index,
                                                            uniqueID = planObject.uniqueID,
                                                            object = planObject,
                                                            pos = planObject.pos,
                                                            isCraftingHeldObjectElsewhere = true,
                                                            assignObjectID = planObject.uniqueID,
                                                            assignObjectDistance = objectDistance,
                                                        }
                                                        return true
                                                    end
                                               -- end
                                            end
                                        end


                                        --[[local planObject = nil
                                        if planObjectID then
                                            planObject = serverGOM:getObjectWithID(planObjectID)
                                        end
                                        if planObject and (not serverGOM:objectIsInaccessible(planObject)) then]]



                                            --[[--disabled--mj:objectLog(sapien.uniqueID, "testVertID c")
                                            local planObjectSapienAssignmentInfo = nil
                                            if planObject then
                                                planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, planObject, nil, heldItemPlanState)
                                            end

                                            if (not planObjectSapienAssignmentInfo) or planObjectSapienAssignmentInfo.available then
                                                --disabled--mj:objectLog(sapien.uniqueID, "testVertID d")
                                                local objectDistance = length(vert.pos - sapien.pos)
                                                --if (not planObject) then
                                                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, vertID, lookAtIntents.types.work.index, false) + 200.0
                                                    --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemHadpickupPlanObjectForCraftingElsewhereOrder (terrain vert) heuristic:", heuristic, " bestResult.heuristic:", bestResult.heuristic)
                                                    if heuristic > bestResult.heuristic then
                                                        if not planObject then
                                                            planObjectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
                                                            planObject = serverGOM:getObjectWithID(planObjectID)
                                                        end
                                                        --mj:log("storage heuristic is best:", heuristic)
                                                        bestResult.heuristic = heuristic
                                                        bestResult.bestObjectInfo = {
                                                            lookAtIntent = lookAtIntents.types.work.index,
                                                            uniqueID = planObject.uniqueID,
                                                            object = planObject,
                                                            pos = planObject.pos,
                                                            isCraftingHeldObjectElsewhere = true,
                                                            assignObjectID = planObject.uniqueID,
                                                            assignObjectDistance = objectDistance,
                                                        }
                                                        return true
                                                    end
                                               -- end
                                            end]]
                                        --end
                                    end
                                end
                                return false
                            end

                            if heldItemPlanState.suitableTerrainVertPos then
                                terrain:loadArea(heldItemPlanState.suitableTerrainVertPos)
                            end

                            local found = false
                            if heldItemPlanState.requiresTerrainBaseTypeIndexes and heldItemPlanState.suitableTerrainVertID then
                                found = testVertID(heldItemPlanState.suitableTerrainVertID)
                            end
                            if not found then
                                local vertIDs = terrain:getVertIDsOfTypesWithinRadius(heldItemPlanState.requiresTerrainBaseTypeIndexes, sapien.pos, serverResourceManager.storageResourceMaxDistance, 10)
                                --mj:log("vertIDs:", vertIDs)
                                if vertIDs then
                                    for i,vertID in ipairs(vertIDs) do
                                        if testVertID(vertID) then
                                            found = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local pickedUpItemStorageAreaTransferInfo = lookAroundInfo.pickedUpObjectStorageAreaTransferInfo



    if not hasManualAssignedPlanObject and pickedUpItemStorageAreaTransferInfo then
        if (not lookAroundInfo.cantDoMostWorkDueToEffects) then
            if pickedUpItemStorageAreaTransferInfo.sourceObjectID then
                local maxCarryCount = serverSapien:getMaxCarryCount(sapien, pickedUpItemStorageAreaTransferInfo.resourceTypeIndex)
                if maxCarryCount > lookAroundInfo.heldObjectCount then
                    local sourceObject = serverGOM:getObjectWithID(pickedUpItemStorageAreaTransferInfo.sourceObjectID)
                    if sourceObject then
                        local nextTransferInfo = serverStorageArea:storageAreaTransferInfoIfRequiresPickup(sharedState.tribeID, sourceObject, sapien.uniqueID)
                        --local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(currentLookAtObjectInfo.uniqueID, objectTypeIndex, tribeID)
                        if nextTransferInfo and 
                        nextTransferInfo.resourceTypeIndex == pickedUpItemStorageAreaTransferInfo.resourceTypeIndex and 
                        nextTransferInfo.destinationObjectID == pickedUpItemStorageAreaTransferInfo.destinationObjectID and 
                        ((not nextTransferInfo.destinationCapacity) or (nextTransferInfo.destinationCapacity > lookAroundInfo.heldObjectCount)) then
                            
                            local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(sourceObject, sapien, plan.types.transferObject.index)
                            if planObjectSapienAssignmentInfo.available then
                                --disabled--mj:objectLog(sapien.uniqueID, "adding heuristic to pick up more items for storage transfer")

                                local objectDistance = length(sourceObject.pos - sapien.pos)

                                objectDistance = math.min(objectDistance, mj:mToP(1000.0))
                                local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, sourceObject.uniqueID, lookAtIntents.types.work.index, false) + 200.0
                                if heuristic > bestResult.heuristic then
                                    --mj:log("storage heuristic is best:", heuristic)
                                    bestResult.heuristic = heuristic
                                    bestResult.bestObjectInfo = {
                                        lookAtIntent = lookAtIntents.types.work.index,
                                        uniqueID = sourceObject.uniqueID,
                                        object = sourceObject,
                                        pos = sourceObject.pos,
                                        isStorage = true,
                                    }
                                end
                            end
                        end
                    end
                end
            end
            if pickedUpItemStorageAreaTransferInfo.destinationObjectID then
                --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemStorageAreaTransferInfo.destinationObjectID:", pickedUpItemStorageAreaTransferInfo.destinationObjectID)
                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(pickedUpItemStorageAreaTransferInfo.destinationObjectID, 
                lookAroundInfo.heldObjectTypeIndex, 
                sharedState.tribeID,
                {
                    allowTradeRequestsMatchingResourceTypeIndex = pickedUpItemStorageAreaTransferInfo.resourceTypeIndex,
                    allowQuestsMatchingResourceTypeIndex = pickedUpItemStorageAreaTransferInfo.resourceTypeIndex,
                })
                if matchInfo then
                    local storageObject = matchInfo.object 
                    
                    local objectDistance = length(storageObject.pos - sapien.pos)

                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, storageObject.uniqueID, lookAtIntents.types.work.index, true) + 200.0
                    --disabled--mj:objectLog(sapien.uniqueID, "pickedUpItemStorageAreaTransferInfo.destinationObjectID, heuristic:", heuristic, " id:", storageObject.uniqueID)
                    if heuristic > bestResult.heuristic then
                        --mj:log("storage heuristic is best:", heuristic)
                        bestResult.heuristic = heuristic
                        bestResult.bestObjectInfo = {
                            lookAtIntent = lookAtIntents.types.work.index,
                            uniqueID = storageObject.uniqueID,
                            object = storageObject,
                            pos = storageObject.pos,
                            isStorage = true,
                        }
                    end
                end
            end
        end
    else

        
        local heldObjectType = gameObject.types[lookAroundInfo.heldObjectTypeIndex]
        local toolUsages = heldObjectType.toolUsages
        --disabled--mj:objectLog(sapien.uniqueID, "toolUsages:", toolUsages)
        if toolUsages and (toolUsages[tool.types.weaponSpear.index] or toolUsages[tool.types.weaponBasic.index]) then
            --disabled--mj:objectLog(sapien.uniqueID, "getting mobs")
            local mobs = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.mobs, sapien.pos, mj:mToP(100.0)) --could create a subset for performance
            for i,info in ipairs(mobs) do
                --disabled--mj:objectLog(sapien.uniqueID, "test mob:", info.objectID)
                testPlanObjectForDisposal(info.objectID)
            end
        end

        --disabled--mj:objectLog(sapien.uniqueID, "checkHeldObjectDisposal no storage transfer info. lookAroundInfo:", lookAroundInfo)
        if lookAroundInfo.pickedUpObjectPlanObjectID and ((not hasManualAssignedPlanObject) or sapien.sharedState.manualAssignedPlanObject == lookAroundInfo.pickedUpObjectPlanObjectID) then
            --disabled--mj:objectLog(sapien.uniqueID, "lookAroundInfo.pickedUpObjectPlanObjectID:", lookAroundInfo.pickedUpObjectPlanObjectID)
            testPlanObjectForDisposal(lookAroundInfo.pickedUpObjectPlanObjectID)
        end
        
        if bestResult.heuristic <= lookAI.minHeuristic then
            if (not lookAroundInfo.cantDoMostWorkDueToEffects) then
                --disabled--mj:objectLog(sapien.uniqueID, "checkHeldObjectDisposal testMaintenance and testPlans")
                testPlans(sapien, bestResult, lookAroundInfo, previousBestResult)
            end
        end

        
        ----disabled--mj:objectLog(sapien.uniqueID, "before checking for multi pickup. hasManualAssignedPlanObject:",hasManualAssignedPlanObject, " bestResult:", bestResult)

        if not hasManualAssignedPlanObject and bestResult.heuristic <= lookAI.minHeuristic and (not lookAroundInfo.cantDoMostWorkDueToEffects) then

            --[[if lookAroundInfo.foodDesire >= desire.levels.mild then --commented out for 0.3.0, this causes issues where they won't pick up multiple items for no good reason, unlcear what it is trying to solve.
                local foodValue = resource.types[gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex].foodValue
                if foodValue then
                    return previousBestResult
                end
            end]]

            --disabled--mj:objectLog(sapien.uniqueID, "checkHeldObjectDisposal no plans found. testing other near by objects lookAroundInfo:", lookAroundInfo)
            local foundCloseMatchingResource = false
            local heldObjectResourceTypeIndex = gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex
            local maxCarryCount = serverSapien:getMaxCarryCount(sapien, heldObjectResourceTypeIndex)
            if maxCarryCount > lookAroundInfo.heldObjectCount then
                ----disabled--mj:objectLog(sapien.uniqueID, "a")
                if (not lookAroundInfo.pickedUpObjectOrderTypeIndex) or lookAroundInfo.pickedUpObjectOrderTypeIndex == order.types.storeObject.index then
                    local nearByPlanObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.plans, sapien.pos, mj:mToP(19.0))
                    for i,objectInfo in ipairs(nearByPlanObjectInfos) do
                        ----disabled--mj:objectLog(sapien.uniqueID, "b:", objectInfo.objectID)
                        local planObject = serverGOM:getObjectWithID(objectInfo.objectID)
                        if planObject then
                            local thisObjectResourceTypeIndex = gameObject.types[planObject.objectTypeIndex].resourceTypeIndex
                            if thisObjectResourceTypeIndex == heldObjectResourceTypeIndex then
                                ----disabled--mj:objectLog(sapien.uniqueID, "c")
                                if not serverGOM:objectIsInaccessible(planObject) then
                                    local assigned = false
                                    local orderObjectState = planObject.sharedState
                                    if orderObjectState and orderObjectState.assignedSapienIDs then
                                        for otherSapienID,planTypeIndexOrTrue in pairs(orderObjectState.assignedSapienIDs) do
                                            if otherSapienID ~= sapien.uniqueID then
                                                if (planTypeIndexOrTrue == true) or (planTypeIndexOrTrue == plan.types.storeObject.index) then
                                                    local otherSapien = serverGOM:getObjectWithID(otherSapienID)
                                                    if otherSapien then
                                                        if length2(otherSapien.pos - planObject.pos) > length2(planObject.pos - sapien.pos) then
                                                            if not serverSapien:cancelOrdersMatchingPlanTypeIndex(sapien, plan.types.storeObject.index) then
                                                                --disabled--mj:objectLog(sapien.uniqueID, "another sapien was assigned to store this object, but I'm closer, so I win")
                                                                assigned = true
                                                                break
                                                            end
                                                        end
                                                    end
                                                else
                                                    assigned = true
                                                    break
                                                end
                                            end
                                        end
                                    end

                                    if not assigned then
                                        local planStates = planManager:getPlanStatesForObjectForSapien(planObject, sapien) -- this calls serverSapien:objectIsAssignedToOtherSapien
                                        if planStates then
                                            ----disabled--mj:objectLog(sapien.uniqueID, "d")
                                            for j,planState in ipairs(planStates) do
                                                if planState.planTypeIndex == plan.types.storeObject.index then
                                                    ----disabled--mj:objectLog(sapien.uniqueID, "e")

                                                    local objectDistance = length(planObject.pos - sapien.pos)
                                                    ----disabled--mj:objectLog(sapien.uniqueID, "f")
                                                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, planObject.uniqueID, lookAtIntents.types.work.index, false)
                                                    
                                                    if heuristic > bestResult.heuristic then
                                                        ----disabled--mj:objectLog(sapien.uniqueID, "g")
                                                        foundCloseMatchingResource = true
                                                        --mj:log("storage heuristic is best:", heuristic)
                                                        bestResult.heuristic = heuristic
                                                        bestResult.bestObjectInfo = {
                                                            lookAtIntent = lookAtIntents.types.work.index,
                                                            uniqueID = planObject.uniqueID,
                                                            object = planObject,
                                                            pos = planObject.pos,
                                                            planTypeIndex = planState.planTypeIndex,
                                                            assignObjectID = planObject.uniqueID,
                                                            assignObjectDistance = objectDistance,
                                                        }
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if not foundCloseMatchingResource then
                --disabled--mj:objectLog(sapien.uniqueID, "CALLING serverStorageArea:bestStorageAreaForObjectType")
                local options = nil
                if (lookAroundInfo.pickedUpObjectPlanState and lookAroundInfo.pickedUpObjectPlanState.manuallyPrioritized) then
                    if not options then
                        options = {}
                    end
                    options.maxDistance2 = planManager.maxAssignedOrPrioritizedPlanDistance2
                end
                
                local matchInfo = serverStorageArea:bestStorageAreaForObjectType(sapien.sharedState.tribeID, lookAroundInfo.heldObjectTypeIndex, sapien.pos, options)
                if matchInfo then
                    local storageObject = matchInfo.object
                                
                    local objectDistance = matchInfo.distanceForOptimization or length(storageObject.pos - sapien.pos)
                    
                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, storageObject.uniqueID, lookAtIntents.types.work.index, false)

                    --disabled--mj:objectLog(sapien.uniqueID, "adding heuristic for storage area:", storageObject.uniqueID, " heuristic:", heuristic)

                    if heuristic > bestResult.heuristic then
                        --mj:log("storage heuristic is best:", heuristic)
                        bestResult.heuristic = heuristic
                        bestResult.bestObjectInfo = {
                            lookAtIntent = lookAtIntents.types.work.index,
                            uniqueID = storageObject.uniqueID,
                            object = storageObject,
                            pos = storageObject.pos,
                            isStorage = true,
                        }
                    end
                end
            end
        end
    end

    if (not previousBestResult) or (bestResult.heuristic > previousBestResult.heuristic) then
        --disabled--mj:objectLog(sapien.uniqueID, "checkHeldObjectDisposal bestResult.heuristic > previousBestResult.heuristic")
        return bestResult
    else
        return previousBestResult
    end
end

local function checkSocial(sapien, lookAroundInfo, previousBestResult)
    ----disabled--mj:objectLog(sapien.uniqueID, "checkSocial previousBestResult:", previousBestResult)
    
    if previousBestResult.heuristic > lookAI.minHeuristic then --added 24/2/21. May cause social to happen less, but they wouldn't sit on seats.
        return previousBestResult
    end

    if lookAroundInfo.aiState.socialTimer > serverSapienAI.socialLength then
        return previousBestResult
    end

    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

   -- local sapiensInGaze = serverGOM:findObjectsInDirectionInSet(sapien.pos, lookAroundInfo.gazeEnd, serverGOM.objectSets.sapiens)
   local sapiensInGaze = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.sapiens, sapien.pos, mj:mToP(10.0))
    for i,info in ipairs(sapiensInGaze) do
        if info.objectID ~= sapien.uniqueID then
            local otherSapien = serverGOM:getObjectWithID(info.objectID)
            if otherSapien then
                if not serverSapien:isSleeping(otherSapien) then
                    serverSapien:updateLastSeenRelationshipInfo(sapien, otherSapien.uniqueID)
                    --serverSapien:addToBondAndMood(sapien, otherSapien.uniqueID, 0.1, 0.1)

                    local objectDistance = math.sqrt(info.distance2)

                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, otherSapien.uniqueID, lookAtIntents.types.social.index, false)
                -- --disabled--mj:objectLog(sapien.uniqueID, "checkSocial lookHeuristic for:", otherSapien.uniqueID, " is:", heuristic)
                    if heuristic > bestResult.heuristic then
                        bestResult.heuristic = heuristic
                        -- mj:log("sapien H:", bestH)
                        
                        bestResult.bestObjectInfo = {
                            lookAtIntent = lookAtIntents.types.social.index,
                            uniqueID = otherSapien.uniqueID,
                            object = otherSapien,
                            pos = otherSapien.pos
                        }
                    end
                end
            end
        end
    end

    if bestResult.heuristic > previousBestResult.heuristic then
        return bestResult
    else
        return previousBestResult
    end
end

local function checkRecreation(sapien, lookAroundInfo, previousBestResult)
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

    if not getCanDoWork() then
        return previousBestResult
    end

    --disabled--mj:objectLog(sapien.uniqueID, "checkRecreation")
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }
    
        

    if lookAroundInfo.musicDesire > desire.levels.moderate then
        --disabled--mj:objectLog(sapien.uniqueID, "lookAroundInfo.musicDesire >= desire.levels.moderate")
       -- if lookAroundInfo.restDesire <= desire.levels.mild or (not previousBestResult) or (previousBestResult.heuristic <= lookAI.minHeuristic) then
           -- --disabled--mj:objectLog(sapien.uniqueID, "checkRecreation lookAroundInfo.restDesire <= desire.levels.mild or (not previousBestResult) or (previousBestResult.heuristic <= lookAI.minHeuristic)")

            local objectTypeIndexes = nil
            if skill:isAllowedToDoTasks(sapien, skill.types.flutePlaying.index) then
                --disabled--mj:objectLog(sapien.uniqueID, "skill:isAllowedToDoTasks(sapien, skill.types.flutePlaying.index)")
                objectTypeIndexes = gameObject.musicalInstrumentObjectTypes
            end

            if objectTypeIndexes then
                local resourceInfo = serverResourceManager:findResourceForSapien(sapien, objectTypeIndexes, {
                    allowStockpiles = true,
                    allowGather = true,
                    maxDistance2 = mj:mToP(50.0) * mj:mToP(50.0),
                    takePriorityOverStoreOrders = true,
                })
                --disabled--mj:objectLog(sapien.uniqueID, "checkRecreation resourceInfo:", resourceInfo, " prev bestResult:", bestResult)

                if resourceInfo then
                    local resourceObject = serverGOM:getObjectWithID(resourceInfo.objectID)
                    if resourceObject then
                        local objectDistance = math.sqrt(resourceInfo.distance2)
                        local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, resourceInfo.objectID, lookAtIntents.types.play.index, false) + 50.0
                        if lookAroundInfo.musicDesire > desire.levels.strong then
                            heuristic = heuristic + 100.0
                        end
                        --disabled--mj:objectLog(sapien.uniqueID, "checkRecreation heuristic:", heuristic)
                        if heuristic > bestResult.heuristic then
                            bestResult.heuristic = heuristic
                            --disabled--mj:objectLog(sapien.uniqueID, "checkRecreation heuristic is best")
                            
                            bestResult.bestObjectInfo = {
                                lookAtIntent = lookAtIntents.types.play.index,
                                uniqueID = resourceInfo.objectID,
                                object = resourceObject,
                                pos = resourceObject.pos,
                                resourceObjectTypeIndex = resourceInfo.objectTypeIndex,
                                --assignObjectID = resourceObject.uniqueID,
                                --assignObjectDistance = objectDistance,
                            }
                        end
                    end
                end
            end
      --  end
    end

    if bestResult.heuristic > previousBestResult.heuristic then
      --  mj:log(sapien.uniqueID, ": checkRecreation has best heuristic:", bestResult.heuristic)
        --disabled--mj:objectLog(sapien.uniqueID, "checkRecreation has best heuristic:", bestResult.heuristic)
        return bestResult
    else
       -- --disabled--mj:objectLog(sapien.uniqueID, "previousBestResult wins over checkRecreation:", previousBestResult, " incoming checkRecreation:", bestResult.heuristic)
       -- mj:log(sapien.uniqueID, ": previousBestResult wins over checkRecreation:", previousBestResult, " incoming checkRecreation:", bestResult.heuristic)
        return previousBestResult
    end
end

local function checkCaution(sapien, lookAroundInfo, previousBestResult)
    ----disabled--mj:objectLog(sapien.uniqueID, "checkSocial previousBestResult:", previousBestResult)

    local closestThreatSapien = lookAroundInfo.aiState.closestThreatSapien

    if not closestThreatSapien then
        return previousBestResult
    end

    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

    serverSapien:updateLastSeenRelationshipInfo(sapien, closestThreatSapien.uniqueID)
    --serverSapien:addToBondAndMood(sapien, otherSapien.uniqueID, 0.1, 0.1)

    --[[
    fleeThreatDistanceClose = mj:mToP(5.0), --Distance that idle sapiens will start reacting to threats. Normal sapiens will run away at this distance, courageous will notice
    fleeThreatDistanceMid = mj:mToP(15.0), --fearful run away, normal notice, courageous ignore
    fleeThreatDistanceFar = mj:mToP(50.0), --fearful notice, normal ignore, courageous ignore
    ]]


    local objectDistance2 = length2(closestThreatSapien.pos - sapien.pos)
    
    local awarenessDistance2 = nil

    local preventElders = false
    local courageousTrait = sapienTrait:getTraitValue(sapien.sharedState.traits, sapienTrait.types.courageous.index)

    if (courageousTrait and (courageousTrait < 0)) or sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, preventElders) then
        awarenessDistance2 = gameConstants.fleeThreatDistanceFar * gameConstants.fleeThreatDistanceFar
    elseif (courageousTrait and (courageousTrait > 0)) then
        awarenessDistance2 = gameConstants.fleeThreatDistanceClose * gameConstants.fleeThreatDistanceClose
    else
        awarenessDistance2 = gameConstants.fleeThreatDistanceMid * gameConstants.fleeThreatDistanceMid
    end

    if objectDistance2 < awarenessDistance2 then
        local heuristic = lookHeuristic(sapien, lookAroundInfo, math.sqrt(objectDistance2), closestThreatSapien.uniqueID, lookAtIntents.types.caution.index, false)
        --disabled--mj:objectLog(sapien.uniqueID, "checkCaution lookHeuristic for:", closestThreatSapien.uniqueID, " is:", heuristic)
        if heuristic > bestResult.heuristic then
            bestResult.heuristic = heuristic
            -- mj:log("sapien H:", bestH)
            
            bestResult.bestObjectInfo = {
                lookAtIntent = lookAtIntents.types.caution.index,
                uniqueID = closestThreatSapien.uniqueID,
                object = closestThreatSapien,
                pos = closestThreatSapien.pos
            }
        end
    end

    if bestResult.heuristic > previousBestResult.heuristic then
        return bestResult
    else
        return previousBestResult
    end
end

local makeWetPosLength = 1.0 - mj:mToP(0.05)
local makeWetPosLength2 = makeWetPosLength * makeWetPosLength

local function checkRest(sapien, lookAroundInfo, previousBestResult)
    
    --[[if lookAroundInfo.hasHeldObject then
        return previousBestResult
    end]]

    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

    if sapien.sharedState.resting or lookAroundInfo.restDesire >= desire.levels.mild or (not previousBestResult) or (previousBestResult.heuristic <= lookAI.minHeuristic) then
        --local gazeEndToUse = sapien.pos + mjm.normalize(lookAroundInfo.gazeEnd - sapien.pos) * mj:mToP(20.0)
        if (not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index)) or (not sapien.sharedState.seatObjectID) then
            --local seatsInGaze = serverGOM:findObjectsInDirectionInSet(sapien.pos, gazeEndToUse, serverGOM.objectSets.seats) 
            
            local seatsInGaze = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.seats, sapien.pos, mj:mToP(19.0))
            ----disabled--mj:objectLog(sapien.uniqueID, "seatsInGaze count:", #seatsInGaze)
            for i,info in ipairs(seatsInGaze) do

                local object = serverGOM:getObjectWithID(info.objectID)
                if object and 
                serverGOM:getObjectHasLight(object) and 
                (object.sharedState.covered or (not sapien.sharedState.covered))
                then

                        local allowRidableObjects = false
                        if sapien.sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index or length2(sapien.pos) < makeWetPosLength2 then
                            allowRidableObjects = true
                        end

                        local nodeIndex = serverSeat:getAvailableNodeIndex(sapien, object, allowRidableObjects)
                        ----disabled--mj:objectLog(sapien.uniqueID, "seat good:", info.objectID, " nodeIndex:", nodeIndex)
                        
                        if nodeIndex and (not serverSapien:seatIsAssignedToOtherSapien(object, nodeIndex, sapien)) then
                        -- --disabled--mj:objectLog(sapien.uniqueID, "found nodeIndex")
                            local objectDistance = math.sqrt(info.distance2)
                            local intent = lookAtIntents.types.restOn.index
                            local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, object.uniqueID, intent, false)

                            if lookAroundInfo.restDesire >= desire.levels.mild then
                                heuristic = heuristic + (lookAroundInfo.restDesire - 1) * 2.0 --lookAroundInfo.restDesire ranges from 2 = mild to 5 = severe. this aims for range 2.0-8.0
                            end

                            ----disabled--mj:objectLog(sapien.uniqueID, "found seat heuristic:", heuristic, " lookAroundInfo:", lookAroundInfo, " objectDistance:", objectDistance, " seat object:", object.uniqueID)

                            local closestInterestingObjectID = nil

                            local interestingNearBy = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.interestingToLookAt, object.pos, mj:mToP(10.0))
                            if interestingNearBy then

                                local bestInterestingHeursitic = lookAI.minHeuristic - 1.0
                                local bestInterestingObjectID = nil

                                for j,interestingInfo in ipairs(interestingNearBy) do
                                    if interestingInfo.objectID ~= sapien.uniqueID and interestingInfo.distance2 > 0.0 then
                                        interestingInfo.object = serverGOM:getObjectWithID(interestingInfo.objectID)
                                        if interestingInfo.object then
                                            local interestingHeursitic = lookHeuristic(sapien, lookAroundInfo, math.sqrt(interestingInfo.distance2), interestingInfo.object.uniqueID, lookAtIntents.types.restNear.index, false)
                                            ----disabled--mj:objectLog(sapien.uniqueID, "restOn interestingNearBy interestingHeursitic:", interestingHeursitic)

                                            if serverGOM:setContainsObjectWithID(serverGOM.objectSets.litCampfires, interestingInfo.object.uniqueID) then
                                                interestingHeursitic = interestingHeursitic + 10.0
                                            end
                                            
                                            if interestingHeursitic > bestInterestingHeursitic then
                                                bestInterestingHeursitic = interestingHeursitic
                                                bestInterestingObjectID = interestingInfo.object.uniqueID
                                            end
                                        end
                                    end
                                end

                                if bestInterestingObjectID then
                                -- --disabled--mj:objectLog(sapien.uniqueID, "restOn bestInterestingObjectID:", bestInterestingObjectID, " interestingHeursitic:", bestInterestingHeursitic, " total:", heuristic + bestInterestingHeursitic)
                                    closestInterestingObjectID = bestInterestingObjectID
                                    heuristic = heuristic + bestInterestingHeursitic
                                end
                            end

                            if object.sharedState.covered then
                                heuristic = heuristic + 2.0
                            end

                            --mj:log("includeing bestInterestingHeursitic:", heuristic, " prev best:", bestResult.heuristic)
                            
                            if heuristic > bestResult.heuristic then
                                bestResult.heuristic = heuristic
                                
                                bestResult.bestObjectInfo = {
                                    lookAtIntent = intent,
                                    uniqueID = object.uniqueID,
                                    restNearObjectID = closestInterestingObjectID,
                                    object = object,
                                    pos = object.pos,
                                    assignObjectID = object.uniqueID,
                                    assignObjectDistance = objectDistance,
                                }
                            end
                        end
                end
            end
           --[[ if (not action:hasModifier(sapien.sharedState.actionModifiers, action.modifierTypes.sit.index)) then --comented out beta 6 as with rain, it causes them to sit by outside interesting objects too often over inside places. Needs more complexity if it's going to happen again.
                local interestingObjectsInGaze = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.interestingToLookAt, sapien.pos, mj:mToP(19.0))
            -- local interestingObjectsInGaze = serverGOM:findObjectsInDirectionInSet(sapien.pos, gazeEndToUse, serverGOM.objectSets.interestingToLookAt) 
                for i,info in ipairs(interestingObjectsInGaze) do
                    if info.objectID ~= sapien.uniqueID then
                        
                        info.object = serverGOM:getObjectWithID(info.objectID)
                        if info.object then
                            local objectDistance = math.sqrt(info.distance2)

                            local intent = lookAtIntents.types.restNear.index
                            local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, info.object.uniqueID, intent)
                            
                            if serverGOM:setContainsObjectWithID(serverGOM.objectSets.litCampfires, info.object.uniqueID) then
                                heuristic = heuristic + 2.0
                            end

                        --  --disabled--mj:objectLog(sapien.uniqueID, "basic rest:", heuristic, " prev best:", bestResult.heuristic)

                            if heuristic > bestResult.heuristic then
                                bestResult.heuristic = heuristic
                                
                                bestResult.bestObjectInfo = {
                                    lookAtIntent = intent,
                                    uniqueID = info.object.uniqueID,
                                    object = info.object,
                                    pos = info.object.pos
                                }
                            end
                        end
                    end
                end
            end]]
        end
    end

    if bestResult.heuristic > previousBestResult.heuristic then
       -- mj:log(sapien.uniqueID, ": checkRest has best heuristic:", bestResult.heuristic)
       -- --disabled--mj:objectLog(sapien.uniqueID, "checkRest has best heuristic:", bestResult.heuristic)
        return bestResult
    else
     --   --disabled--mj:objectLog(sapien.uniqueID, "previousBestResult wins over rest:", previousBestResult, " incoming rest:", bestResult.heuristic)
        --mj:log(sapien.uniqueID, ": previousBestResult wins over rest:", previousBestResult, " incoming rest:", bestResult.heuristic)
        return previousBestResult
    end
end
--[[
local function checkInterest(sapien, lookAroundInfo, previousBestResult)

    if previousBestResult.heuristic > lookAI.minHeuristic then
        return previousBestResult
    end
    
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

    local interestingObjectsInGaze = serverGOM:findObjectsInDirectionInSet(sapien.pos, lookAroundInfo.gazeEnd, serverGOM.objectSets.interestingToLookAt)
    for i,info in ipairs(interestingObjectsInGaze) do
        if info.object.uniqueID ~= sapien.uniqueID then
            local heuristic = lookHeuristic(sapien, lookAroundInfo, info.dot, info.distance, info.object.uniqueID, lookAtIntents.types.interest.index)

            if heuristic > bestResult.heuristic then
                bestResult.heuristic = heuristic
            -- mj:log("interesting H:", bestH)
                
                bestResult.bestObjectInfo = {
                    lookAtIntent = lookAtIntents.types.interest.index,
                    uniqueID = info.object.uniqueID,
                    object = info.object,
                    pos = info.object.pos
                }
            end
        end
    end

    if bestResult.heuristic > previousBestResult.heuristic then
        return bestResult
    else
        return previousBestResult
    end
end]]


local function lookAroundNomad(sapien, lookAroundInfo, previousBestResult)
    
    --[[if previousBestResult.heuristic > lookAI.minHeuristic then
        return previousBestResult
    end]]

    local sharedState = sapien.sharedState
    local generalMoveHeuristic = lookAI.minHeuristic
    local tribeState = serverTribe:getTribeState(sharedState.tribeID)
    if not tribeState then
        return previousBestResult
    end
    serverTribe:updateNomadTribeExitState(tribeState)

    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0
    }

    --[[if lookAroundInfo.priorityObjectID then
        local priorityObject = serverGOM:getObjectWithID(lookAroundInfo.priorityObjectID)
        if priorityObject and priorityObject.objectTypeIndex == gameObject.types.sapien.index then
            if serverSapien:sapienIsCommandingAttentionOfOtherSapien(priorityObject, sapien) then

            end
        end
    end]]
    
    if (not nomadTribeBehavior.types[tribeState.nomadState.tribeBehaviorTypeIndex].isRaid) and (not sharedState.fleeing) then
        bestResult = checkSleep(sapien, lookAroundInfo, bestResult)
    end

    local timePressureRampUpDuraction = 600.0

    local worldTime = serverWorld:getWorldTime()
    local goalTime = tribeState.nomadState.goalTime

    local function updateMoveHeuristic(moveFinishTime, moveEndPos)
        local moveTimePressure = math.max((timePressureRampUpDuraction - (moveFinishTime - worldTime)) / timePressureRampUpDuraction, 0.0) * 50.0
        local moveEndVec = normalize(moveEndPos) - sapien.normalizedPos
        local moveEndDistance = length(moveEndVec)
        local distancePressure = moveEndDistance / mj:mToP(100.0)
        generalMoveHeuristic = lookAI.minHeuristic + (moveTimePressure * distancePressure)
        if sharedState.fleeing then
            generalMoveHeuristic = 100
        end 
         --disabled--mj:objectLog(sapien.uniqueID, "updateMoveHeuristic:", generalMoveHeuristic, " moveTimePressure:", moveTimePressure, " distancePressure:", distancePressure)
        bestResult.heuristic = generalMoveHeuristic
        bestResult.generalMoveDirection = moveEndVec / moveEndDistance
    end


    local function findRaidTarget(maxSearchDistance2)
        --disabled--mj:objectLog(sapien.uniqueID, "findRaidTarget")
        local foundRaidTarget = false

        local objectTypes = nil
        if lookAroundInfo.heldObjectTypeIndex then
            objectTypes = gameObject:gameObjectTypesSharingResourceTypesWithGameObjectType(lookAroundInfo.heldObjectTypeIndex)
        else
            objectTypes = gameObject.foodObjectTypes
        end

        local resourceInfos = nil
        if tribeState.nomadState.tribeBehaviorTypeIndex == nomadTribeBehavior.types.foodRaid.index then
            local options = {
                onlyStockpiles = true,
                minStockpileCount = 3,
                maxDistance2 = maxSearchDistance2
            }
            resourceInfos = serverResourceManager:distanceOrderedObjectsForResourceinTypesArray(objectTypes, sapien.pos, options, nil)

        else
            local options = {
                maxDistance2 = maxSearchDistance2,
                allowStockpiles = true,
                minStoredPerItemValue = 0.3,
                minLoosePerItemValue = 0.5,
            }
            resourceInfos = serverResourceManager:getValueOrderedValuableResources(sapien.pos, options)
        end

        if resourceInfos and resourceInfos[1] then
            --mj:log(sapien.uniqueID, " raid target found:", resourceInfos)
            for i,resourceInfo in ipairs(resourceInfos) do
                if (not lookAroundInfo.heldObjectTypeIndex) or (gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex == gameObject.types[resourceInfo.objectTypeIndex].resourceTypeIndex) then
                    local objectDistance = length(resourceInfo.pos - sapien.pos)

                    local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, resourceInfo.objectID, lookAtIntents.types.raidTarget.index, false) + 50.0

                    if resourceInfo.perItemValue then --only set by getValueOrderedValuableResources, not distanceOrderedObjectsForResourceinTypesArray
                        heuristic = heuristic + resourceInfo.perItemValue --should walk about 100m further per 1 extra value
                    end

                    if heuristic > bestResult.heuristic then
                        --disabled--mj:objectLog(sapien.uniqueID, "raid target heuristic is best:", heuristic, " resourceInfo.perItemValue:", resourceInfo.perItemValue, " distance:", math.floor(mj:pToM(objectDistance)), "m")
                        local storageObject = serverGOM:getObjectWithID(resourceInfo.objectID)
                        bestResult.heuristic = heuristic
                        bestResult.bestObjectInfo = {
                            lookAtIntent = lookAtIntents.types.raidTarget.index,
                            uniqueID = resourceInfo.objectID,
                            object = storageObject,
                            pos = storageObject.pos,
                            isStorage = true,
                            resourceObjectTypeIndex = resourceInfo.objectTypeIndex
                        }
                        foundRaidTarget = true
                    end
                end
            end
        end
        return foundRaidTarget
    end

    

    if sharedState.lookAtObjectID then --check if we are being recruited etc
        if (not lookAroundInfo.aiState.lastRecruitOrBanishNoticedTime) or ((serverWorld:getWorldTime() - lookAroundInfo.aiState.lastRecruitOrBanishNoticedTime) < 10) then
            local otherSapien = serverGOM:getObjectWithID(lookAroundInfo.priorityObjectID)
            if otherSapien and otherSapien.objectTypeIndex == gameObject.types.sapien.index then
                local objectDistance = length(otherSapien.pos - sapien.pos)
                local heuristic = lookHeuristic(sapien, lookAroundInfo, objectDistance, otherSapien.uniqueID, lookAtIntents.types.social.index, false) + 100
                if heuristic > previousBestResult.heuristic then
                    bestResult.heuristic = heuristic
                    bestResult.bestObjectInfo = {
                        lookAtIntent = lookAtIntents.types.social.index,
                        uniqueID = otherSapien.uniqueID,
                        object = otherSapien,
                        pos = otherSapien.pos
                    }
                end
            end
        else
            lookAroundInfo.aiState.lastRecruitOrBanishNoticedTime = nil
        end
    end
    

    if sharedState.manualAssignedPlanObject then
        bestResult = checkWork(sapien, lookAroundInfo, bestResult)
        if bestResult.heuristic > previousBestResult.heuristic then
            return bestResult
        end
    end

    if nomadTribeBehavior.types[tribeState.nomadState.tribeBehaviorTypeIndex].isRaid then
        --disabled--mj:objectLog(sapien.uniqueID, "isRaid")

        local function exitRaid()
            --disabled--mj:objectLog(sapien.uniqueID, "raid exit")
            --mj:debug("raid exit:", sharedState)
            local moveEndVec = normalize(tribeState.nomadState.exitPos) - sapien.normalizedPos
            local moveEndDistance = length(moveEndVec)
            generalMoveHeuristic = lookAI.minHeuristic + 20.0
            bestResult.heuristic = generalMoveHeuristic
            bestResult.generalMoveDirection = moveEndVec / moveEndDistance
            if not sharedState.fleeing then
                sharedState:set("fleeing", true)
                mj:debug("fleeing")
            end
            sharedState:remove("manualAssignedPlanObject")
        end

        if sharedState.fleeing or tribeState.exiting then
            --disabled--mj:objectLog(sapien.uniqueID, "exiting due to already fleeing or exitTime")
            exitRaid()
        else 
            local moveEndVec = normalize(tribeState.nomadState.goalPos) - sapien.normalizedPos
            local moveEndDistance = length(moveEndVec)
            
            if lookAroundInfo.hasHeldObject then
                --disabled--mj:objectLog(sapien.uniqueID, "hasHeldObject")
                local resourceTypeIndex = gameObject.types[lookAroundInfo.heldObjectTypeIndex].resourceTypeIndex
                if serverSapien:getMaxCarryCount(sapien, resourceTypeIndex) > lookAroundInfo.heldObjectCount then
                    if not findRaidTarget(mj:mToP(10.0) * mj:mToP(10.0)) then
                        --disabled--mj:objectLog(sapien.uniqueID, "no raid target found (carrying object)")
                        exitRaid()
                    end
                else
                    --disabled--mj:objectLog(sapien.uniqueID, "carry limit reached")
                    exitRaid()
                end
            else
                if moveEndDistance < mj:mToP(50.0) then
                    local maxDistanceMeters = 150.0
                    if tribeState.nomadState.tribeBehaviorTypeIndex == nomadTribeBehavior.types.opportunisticThief.index then
                        maxDistanceMeters = 60.0
                    end

                    if not findRaidTarget(mj:mToP(maxDistanceMeters) * mj:mToP(maxDistanceMeters)) then
                        --disabled--mj:objectLog(sapien.uniqueID, "no raid target found (not carrying object)")
                        exitRaid()
                    end
                else
                    --disabled--mj:objectLog(sapien.uniqueID, "raid move toward goal - distance:", mj:pToM(moveEndDistance))
                    generalMoveHeuristic = lookAI.minHeuristic + 10.0
                    bestResult.heuristic = generalMoveHeuristic
                    bestResult.generalMoveDirection = moveEndVec / moveEndDistance
                end
            end
        end
    else
        if sharedState.fleeing or tribeState.exiting then
            updateMoveHeuristic(tribeState.nomadState.exitTime, tribeState.nomadState.exitPos)
        else
            updateMoveHeuristic(goalTime, tribeState.nomadState.goalPos)

            
            bestResult = checkSocial(sapien, lookAroundInfo, bestResult)
        end
    end

    --disabled--mj:objectLog(sapien.uniqueID, "nomad bestResult.heuristic:", bestResult.heuristic, " previousBestResult.heuristic:", previousBestResult.heuristic)
    if bestResult.heuristic > previousBestResult.heuristic then
        return bestResult
    else
        return previousBestResult
    end
end


local function lookAround(sapien, lookAroundInfo, allowWorkPlans)
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0,
    }

    local sharedState = sapien.sharedState

    local preventSleepDueToManualObject = false
    if sharedState.manualAssignedPlanObject and sharedState.manualAssignedPlanObjectPreventSleepUntilTime then
        if sharedState.manualAssignedPlanObjectPreventSleepUntilTime > serverWorld:getWorldTime() then
            preventSleepDueToManualObject = true
        else
            sharedState:remove("manualAssignedPlanObjectPreventSleepUntilTime")
        end
    end

    
    --if not foundPriorityResult and lookAroundInfo.priorityObjectID then
        --local priorityObject = serverGOM:getObjectWithID(lookAroundInfo.priorityObjectID)
       -- if priorityObject then

    if sharedState.nomad then
        return lookAroundNomad(sapien, lookAroundInfo, bestResult)
    end
    
    if not preventSleepDueToManualObject then
        bestResult = checkSleep(sapien, lookAroundInfo, bestResult)
    end

    if not preventSleepDueToManualObject then
        if lookAI:checkIsTooColdAndBusyWarmingUp(sapien) then
            --disabled--mj:objectLog(sapien.uniqueID, "lookAround is too cold and warming up")
            return bestResult
        end
    end

    if allowWorkPlans then
        --disabled--mj:objectLog(sapien.uniqueID, "checking work plans")
        --local requiresUseOfHeldItem = false
        if lookAroundInfo.hasHeldObject then
            sapien.privateState.iteratePlansStartIndex = nil
            bestResult = checkHeldObjectDisposal(sapien, lookAroundInfo, bestResult, allowWorkPlans)
        -- --disabled--mj:objectLog(sapien.uniqueID, "checkHeldObjectDisposal bestResult:", bestResult)
        elseif (not lookAroundInfo.cantDoMostWorkDueToEffects) or (sharedState.manualAssignedPlanObject) then
            bestResult = checkWork(sapien, lookAroundInfo, bestResult)
        end
    end
    
    if not preventSleepDueToManualObject then
        bestResult = checkCaution(sapien, lookAroundInfo, bestResult)
    end

    
    --[[if lookAroundInfo.cantDoMostWorkDueToEffects then
        --disabled--mj:objectLog(sapien.uniqueID, "returning no work in lookAround due to status effects")
        return bestResult
    end]]

    if (not sharedState.manualAssignedPlanObject) or sharedState.resting then
        if not lookAroundInfo.hasHeldObject then
            bestResult = checkRest(sapien, lookAroundInfo, bestResult)
            bestResult = checkRecreation(sapien, lookAroundInfo, bestResult)
            bestResult = checkSocial(sapien, lookAroundInfo, bestResult)
        end
    end
    --bestResult = checkInterest(sapien, lookAroundInfo, bestResult)
    
    --disabled--mj:objectLog(sapien.uniqueID, "final bestResult:", bestResult.heuristic)

    return bestResult
end


function findOrderLookAround:lookAroundForMultitask(sapien, lookAroundInfo, orderState, currentActionTypeIndex)
    
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0,
    }

    bestResult = checkSocial(sapien, lookAroundInfo, bestResult)
    --bestResult = checkInterest(sapien, lookAroundInfo, bestResult)

    return bestResult
end

function findOrderLookAround:lookAroundForAutoExtend(sapien, lookAroundInfo, orderState, allowWorkToInterrupt)
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderLookAround:lookAroundForAutoExtend allowWorkToInterrupt:", allowWorkToInterrupt)
    return lookAround(sapien, lookAroundInfo, allowWorkToInterrupt)
end

function findOrderLookAround:getResultForHeldObjectDisposal(sapien, lookAroundInfo)
    local bestResult = {
        heuristic = lookAI.minHeuristic - 1.0,
    }
    
    if sapien.sharedState.nomad then
        return bestResult
    end
    
    sapien.privateState.iteratePlansStartIndex = nil
    bestResult = checkHeldObjectDisposal(sapien, lookAroundInfo, bestResult, nil, true)

    return bestResult
end


function findOrderLookAround:lookAround(sapien, lookAroundInfo)
    --disabled--mj:objectLog(sapien.uniqueID, "findOrderLookAround:lookAround")
    return lookAround(sapien, lookAroundInfo, true)
end


function findOrderLookAround:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    serverTribe = initObjects.serverTribe
    serverSapien = initObjects.serverSapien
    serverSapienAI = initObjects.serverSapienAI
end


return findOrderLookAround