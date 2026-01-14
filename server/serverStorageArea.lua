local mjm = mjrequire "common/mjm"
local length2 = mjm.length2
local normalize = mjm.normalize

local gameObject = mjrequire "common/gameObject"
local storage = mjrequire "common/storage"
local resource = mjrequire "common/resource"
local statistics = mjrequire "common/statistics"
local maintenance = mjrequire "common/maintenance"
local plan = mjrequire "common/plan"
local rng = mjrequire "common/randomNumberGenerator"
local evolvingObject = mjrequire "common/evolvingObject"
local storageSettings = mjrequire "common/storageSettings"
--local timer = mjrequire "common/timer"
--local destination = mjrequire "common/destination"

local serverResourceManager = mjrequire "server/serverResourceManager"
local serverEvolvingObject = mjrequire "server/serverEvolvingObject"
local serverLogistics = mjrequire "server/serverLogistics"
local serverStatistics = mjrequire "server/serverStatistics"
local anchor = mjrequire "server/anchor"
local serverTutorialState = mjrequire "server/serverTutorialState"
local serverWeather = mjrequire "server/serverWeather"

local serverStorageArea = {}

local storageAreas = {}
local storageAreasByTribeID = {}

serverStorageArea.storageAreas = storageAreas
serverStorageArea.storageAreasByTribeID = storageAreasByTribeID

local serverWorld = nil
local serverGOM = nil
local planManager = nil
local serverSapien = nil
local serverTribe = nil
local serverTribeAIPlayer = nil
local serverDestination = nil

serverStorageArea.resourceCountsByTribeID = {}
serverStorageArea.foodCountsByTribeID = {}

--[[local availablityChangeCallbackInfos = {}
local availablityChangeStorageTypesByObjectID = {}
local availablityChangeCallbackInfosByObjectID = {}]]

local availabilityChangeInfosByTribeID = {}

local callbackInfosRequiringCallObjectIDsSetsByTribeID = {}

function serverStorageArea:getTribeSettings(storageObjectSharedState, sapienTribeID)
    if not storageObjectSharedState.settingsByTribe then
        return nil
    end
    
    local tribeRelationsSettings = serverWorld:getAllTribeRelationsSettings(sapienTribeID)
    local tribeIDToUse = storageSettings:getSettingsTribeIDToUse(storageObjectSharedState, sapienTribeID, tribeRelationsSettings)
    return storageObjectSharedState.settingsByTribe[tribeIDToUse]
end

local function objectTypeMatchesRestrictedAllowedType(tribeID, storageObjectSharedState, objectTypeIndex)
    local tribeSettings = serverStorageArea:getTribeSettings(storageObjectSharedState, tribeID) or {}
    local restrictStorageTypeIndex = tribeSettings.restrictStorageTypeIndex
    if storageObjectSharedState.contentsStorageTypeIndex and 
    restrictStorageTypeIndex and 
    restrictStorageTypeIndex > 0 and 
    restrictStorageTypeIndex ~= storageObjectSharedState.contentsStorageTypeIndex then
        return false
    end
    if restrictStorageTypeIndex and restrictStorageTypeIndex ~= 0 then
        local storageTypeIndex = storage.typesByResource[gameObject.types[objectTypeIndex].resourceTypeIndex]
        if storageTypeIndex == restrictStorageTypeIndex then
            if tribeSettings.restrictedObjectTypeIndexes and 
            tribeSettings.restrictedObjectTypeIndexes[objectTypeIndex] then
                return false
            end
            return true
        end
    end 
    return false
end

local function objectTypeIndexIsRestricted(tribeID, storageObjectSharedState, objectTypeIndex)
    local tribeSettings = serverStorageArea:getTribeSettings(storageObjectSharedState, tribeID) or {}
    local restrictStorageTypeIndex = tribeSettings.restrictStorageTypeIndex
    if storageObjectSharedState.contentsStorageTypeIndex and 
    restrictStorageTypeIndex and 
    restrictStorageTypeIndex > 0 and 
    restrictStorageTypeIndex ~= storageObjectSharedState.contentsStorageTypeIndex then
        return true
    end
    if restrictStorageTypeIndex and restrictStorageTypeIndex ~= 0 then
        local storageTypeIndex = storage.typesByResource[gameObject.types[objectTypeIndex].resourceTypeIndex]
        if storageTypeIndex ~= restrictStorageTypeIndex then
            return true
        else
            if tribeSettings.restrictedObjectTypeIndexes and 
            tribeSettings.restrictedObjectTypeIndexes[objectTypeIndex] then
                return true
            end
        end
    end 
    return false
end

function serverStorageArea:getMaxItemsForContentsType(storageObject) --convenience function, UNTESTED as not actually used after implementing, but should work and is a good idea
    local contentsStorageTypeIndex = storageObject.sharedState.contentsStorageTypeIndex
    if contentsStorageTypeIndex then
        return storage:maxItemsForStorageType(contentsStorageTypeIndex, gameObject.types[storageObject.objectTypeIndex].storageAreaDistributionTypeIndex)
    end
    return -1
end

local function generateAvailabilityInfo(storageObject, tribeID) --generate info on whether the storage area is available for delivery drop off
   -- mj:error("generateAvailabilityInfo:", storageObject.uniqueID, " tribeID:", tribeID)
    ----disabled--mj:objectLog(storageObject.uniqueID, "generateAvailabilityInfo tribeID:", tribeID)
    local info = {
        available = true
    }

    if not storageObject then
        info.available = false
        --mj:log("false a")
        return info
    end

    if serverGOM:objectIsInaccessible(storageObject) then
        info.available = false
        --mj:log("false b")
        return info
    end

    local sharedState = storageObject.sharedState
    local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}

    local restrictStorageTypeIndex = tribeSettings.restrictStorageTypeIndex
    if restrictStorageTypeIndex == -1 or tribeSettings.removeAllItems or tribeSettings.removeAllDueToDeconstruct then
        info.available = false
        --mj:log("false c")
        return info
    end

    if tribeSettings.maxQuantityFraction and tribeSettings.maxQuantityFraction < 0.00005 then
        info.available = false
        --mj:log("false d")
        return info
    end

    if restrictStorageTypeIndex then
        if restrictStorageTypeIndex ~= 0 then
            if sharedState.contentsStorageTypeIndex and sharedState.contentsStorageTypeIndex ~= restrictStorageTypeIndex then
                info.available = false
                --mj:log("false e")
                return info
            end

            info.storageTypeIndex = restrictStorageTypeIndex

            if tribeSettings.restrictedObjectTypeIndexes then
                local objectTypeBlackList = {}
                for restrictedObjectTypeIndex,v in pairs(tribeSettings.restrictedObjectTypeIndexes) do
                    if storage:storageTypeIndexForResourceTypeIndex(gameObject.types[restrictedObjectTypeIndex].resourceTypeIndex) == info.storageTypeIndex then
                        objectTypeBlackList[restrictedObjectTypeIndex] = true
                    end
                end
                if next(objectTypeBlackList) then
                    info.objectTypeBlackList = objectTypeBlackList
                end
            end
        end
    elseif sharedState.tribeID ~= tribeID and serverWorld:tribeIsValidOwner(sharedState.tribeID) then
        --local realtionsSettings = serverWorld:getTribeRelationsSettings(sharedState.tribeID, tribeID)
        --if not (realtionsSettings and realtionsSettings.allowStoringInStorageAreas) then --todo

        local isStorageAlly = false

        local tribeRelationsSettings = serverWorld:getTribeRelationsSettings(sharedState.tribeID, tribeID)
        if tribeRelationsSettings then
            isStorageAlly = tribeRelationsSettings.storageAlly
        end

        if not isStorageAlly then
            local hasValidTradeRequest = false
            if sharedState.tradeRequest then
                local destinationState = serverDestination:getDestinationState(sharedState.tribeID)
                local relationship = destinationState and destinationState.relationships and destinationState.relationships[tribeID]

                if relationship then
                    if not (sharedState.tradeRequest.tradeLimitReached or relationship.favorIsBelowTradingThreshold) then
                        hasValidTradeRequest = true
                    else
                        local tradeRequestDeliveries = relationship.tradeRequestDeliveries
                        if tradeRequestDeliveries and tradeRequestDeliveries[sharedState.tradeRequest.resourceTypeIndex] and tradeRequestDeliveries[sharedState.tradeRequest.resourceTypeIndex] > 0 then
                            hasValidTradeRequest = true
                        end
                    end
                end
            end

            if (not hasValidTradeRequest) then
                if sharedState.quest and sharedState.quest.tribeID == tribeID then
                    local destinationState = serverDestination:getDestinationState(sharedState.tribeID)
                    local relationship = destinationState and destinationState.relationships and destinationState.relationships[tribeID]
                    if relationship then
                        local questState = relationship.questState
                        if questState then
                            if not (questState.complete or questState.failed) then
                                hasValidTradeRequest = true
                            end
                        end
                    end
                end
            end


            if (not hasValidTradeRequest) then
                info.available = false
                --mj:log("false f")
                return info
            end
        end
        --end
    end
    
    local objects = nil
    if sharedState.inventory then
        objects = sharedState.inventory.objects
    end
    if objects and #objects > 0 then
        local resourceTypeIndex = gameObject.types[objects[1].objectTypeIndex].resourceTypeIndex
        local contentsStorageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex)
        local storageMaxItems = storage:maxItemsForStorageType(contentsStorageTypeIndex, gameObject.types[storageObject.objectTypeIndex].storageAreaDistributionTypeIndex)
        if #objects < storageMaxItems then
            if info.storageTypeIndex and (info.storageTypeIndex ~= contentsStorageTypeIndex) then
                info.available = false
                --mj:log("false g")
            else
                info.storageTypeIndex = contentsStorageTypeIndex
                
                if tribeSettings.maxQuantityFraction and tribeSettings.maxQuantityFraction < 0.9995 then
                    local maxItems = math.floor(tribeSettings.maxQuantityFraction * storageMaxItems)
                    maxItems = mjm.clamp(maxItems, 1, storageMaxItems)
                    if #objects >= maxItems then
                        info.available = false
                        --mj:log("false h")
                    end
                end
            end
        else
            info.available = false
            --mj:log("false i")
        end
    end

    return info
end

local function getAvailabilityInfo(objectID, storageAreaInfo, tribeID)
    --mj:log("getAvailabilityInfo:", objectID)
    if not storageAreaInfo.availabilityInfosByTribeID then
        storageAreaInfo.availabilityInfosByTribeID = {}
    end
    if not storageAreaInfo.availabilityInfosByTribeID[tribeID] then
        local storageObject = serverGOM:getObjectWithID(objectID)
        local info = generateAvailabilityInfo(storageObject, tribeID)
        --mj:log("generateAvailabilityInfo:", info)
        storageAreaInfo.availabilityInfosByTribeID[tribeID] = info
        --serverLogistics:updateMaintenceRequiredForConnectedObjects(storageObject.uniqueID)
        return info
    end
    return storageAreaInfo.availabilityInfosByTribeID[tribeID]
end

local function findAnyStorageAreaAvailableForObjectType(tribeID, objectTypeIndex, searchPos, maxDistance2)
    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
    for objectID, storageAreaInfo in pairs(storageAreas) do
        local availabilityInfo = getAvailabilityInfo(objectID, storageAreaInfo, tribeID)
        if availabilityInfo.available then
            local storageObject = serverGOM:getObjectWithID(objectID)
            if storageObject and length2(searchPos - storageObject.pos) < maxDistance2 then
                if not objectTypeIndexIsRestricted(tribeID, storageObject.sharedState, objectTypeIndex) then
                    local emptyFound = true
                    local inventory = storageObject.sharedState.inventory
                    if inventory and inventory.countsByObjectType then
                        local countsByObjectType = inventory.countsByObjectType
                        for containedObjectTypeIndex,count in pairs(countsByObjectType) do
                            if count > 0 then
                                emptyFound = false
                                local inventoryResourceType = gameObject.types[containedObjectTypeIndex].resourceTypeIndex
                                if storage:resourceTypesCanBeStoredToegether(inventoryResourceType, resourceTypeIndex) then
                                    local maxItems = storage:maxItemsForResourceType(resourceTypeIndex, gameObject.types[storageObject.objectTypeIndex].storageAreaDistributionTypeIndex)
                                    if #inventory.objects < maxItems then
                                        --mj:log("found matching storage area:", objectID, " for object type:", objectTypeIndex)
                                        return objectID
                                    end
                                end
                            end
                        end
                    end
                    if emptyFound then
                        if storageObject.sharedState then
                            if storageObject.sharedState.tradeRequest or storageObject.sharedState.quest or storageObject.sharedState.tradeOffer then
                                emptyFound = false
                            end
                        end
                        --mj:log("found empty storage area:", objectID, " for object type:", objectTypeIndex)
                        
                        if emptyFound then
                            return objectID
                        end
                    end
                end
            end
        end
    end
    return false
end

function serverStorageArea:getTotalStorageAreaCount(tribeID)
    local count = 0
    for objectID, info in pairs(storageAreas) do
        if info.tribeID == tribeID then
            count = count + 1
        end
    end
    return count
end


--[[local function checkForInitialAvailability(callbackInfo)
    local matchID = availablityChangeCallbackInfos[storageTypeIndex] and availablityChangeCallbackInfos[storageTypeIndex][objectID] and findAnyStorageAreaAvailableForObjectType(tribeID, objectTypeIndex, pos, callbackInfo.maxDistance2)
    
    if objectID == "2e0bf5" then
        mj:log("serverStorageArea:setCallbackForStorageAvailabilityChange:", hasPrioritizedOrManuallyAssignedPlan, " matchID:", matchID)
    end

    if matchID then
        callbackInfo.availableStorageAreaID = matchID
        local newStorageAreaInfo = storageAreas[matchID]
        if not newStorageAreaInfo.assignedCallbackObjectIDs[objectID] then
            newStorageAreaInfo.assignedCallbackObjectIDs[objectID] = {}
        end
        newStorageAreaInfo.assignedCallbackObjectIDs[objectID][tribeID] = true
    else
        callbackInfo.available = false
        callbackInfo.func(tribeID, objectID, callbackInfo.objectTypeIndex, callbackInfo.available)
    end
end]]

function serverStorageArea:setCallbackForStorageAvailabilityChange(tribeID, objectID, objectTypeIndex, pos, initialAvailability, hasPrioritizedOrManuallyAssignedPlan, func)

    if availabilityChangeInfosByTribeID[tribeID] then
        serverStorageArea:removeAllCallbacksForStorageAvailabilityChange(objectID, tribeID)
    end

    local storageTypeIndex = storage.typesByResource[gameObject.types[objectTypeIndex].resourceTypeIndex]

    local tribeInfo = availabilityChangeInfosByTribeID[tribeID]
    if not tribeInfo then
        tribeInfo = {
            availablityChangeCallbackInfos = {},
            availablityChangeCallbackInfosByObjectID = {},
            availablityChangeStorageTypesByObjectID = {},
        }
        availabilityChangeInfosByTribeID[tribeID] = tribeInfo
    end

    local availablityChangeCallbackInfos = tribeInfo.availablityChangeCallbackInfos
    local availablityChangeCallbackInfosByObjectID = tribeInfo.availablityChangeCallbackInfosByObjectID
    local availablityChangeStorageTypesByObjectID = tribeInfo.availablityChangeStorageTypesByObjectID

    
    --mj:log("serverStorageArea:setCallbackForStorageAvailabilityChange:", objectID, " initialAvailability:", initialAvailability)
    local callbackInfos = availablityChangeCallbackInfos[storageTypeIndex]
    if not callbackInfos then
        callbackInfos = {}
        availablityChangeCallbackInfos[storageTypeIndex] = callbackInfos
    end

    local maxDistance2 = serverResourceManager.storageResourceMaxDistance2
    if hasPrioritizedOrManuallyAssignedPlan then
        maxDistance2 = planManager.maxAssignedOrPrioritizedPlanDistance2
    end

    local callbackInfo = {
        pos = pos,
        func = func,
        objectTypeIndex = objectTypeIndex,
        available = initialAvailability,
        maxDistance2 = maxDistance2,
    }

    availablityChangeCallbackInfosByObjectID[objectID] = callbackInfo
    callbackInfos[objectID] = callbackInfo

    if not availablityChangeStorageTypesByObjectID[objectID] then
        availablityChangeStorageTypesByObjectID[objectID] = {}
    end

    availablityChangeStorageTypesByObjectID[objectID][storageTypeIndex] = true
    

    local callbackInfosRequiringCallObjectIDsSet = callbackInfosRequiringCallObjectIDsSetsByTribeID[tribeID]
    if not callbackInfosRequiringCallObjectIDsSet then
        callbackInfosRequiringCallObjectIDsSet = {}
        callbackInfosRequiringCallObjectIDsSetsByTribeID[tribeID] = callbackInfosRequiringCallObjectIDsSet
    end
    callbackInfosRequiringCallObjectIDsSet[objectID] = true


    --if initialAvailability then 
    --    timer:addCallbackTimer(0.01, doDelayedCheckForInitialAvailability) --there is an issue where storage areas may be loaded after the object. This helps ensure storage areas are loaded. To fix properly, availableStorageAreaID etc could be saved with object
    --end
    
end

function serverStorageArea:callAnyInitialCallbacks()
    for tribeID,objectsSet in pairs(callbackInfosRequiringCallObjectIDsSetsByTribeID) do
        local tribeInfo = availabilityChangeInfosByTribeID[tribeID]
        if tribeInfo then
            local availablityChangeCallbackInfosByObjectID = tribeInfo.availablityChangeCallbackInfosByObjectID
            for objectID,v in pairs(objectsSet) do
                local callbackInfo = availablityChangeCallbackInfosByObjectID[objectID]
                if callbackInfo then
                    local newMatch = findAnyStorageAreaAvailableForObjectType(tribeID, callbackInfo.objectTypeIndex, callbackInfo.pos, callbackInfo.maxDistance2)
                    if newMatch then
                        --mj:log("found match:", newMatch, " for object:", callbackInfo.objectTypeIndex)
                        callbackInfo.availableStorageAreaID = newMatch
                        callbackInfo.available = true
                        local newStorageAreaInfo = storageAreas[newMatch]
                        if not newStorageAreaInfo.assignedCallbackObjectIDs[objectID] then
                            newStorageAreaInfo.assignedCallbackObjectIDs[objectID] = {}
                        end
                        newStorageAreaInfo.assignedCallbackObjectIDs[objectID][tribeID] = true
                    else
                        if callbackInfo.availableStorageAreaID then
                            local oldStorageAreaInfo = storageAreas[callbackInfo.availableStorageAreaID]
                            if oldStorageAreaInfo then
                                if oldStorageAreaInfo.assignedCallbackObjectIDs[objectID] then
                                    oldStorageAreaInfo.assignedCallbackObjectIDs[objectID][tribeID] = nil
                                    if not next(oldStorageAreaInfo.assignedCallbackObjectIDs[objectID]) then
                                        oldStorageAreaInfo.assignedCallbackObjectIDs[objectID] = nil
                                    end
                                end
                            end
                            callbackInfo.availableStorageAreaID = nil
                            callbackInfo.available = false
                        end
                    end
                    callbackInfo.func(tribeID, objectID, callbackInfo.objectTypeIndex, callbackInfo.available)
                end
            end
        end
    end
    callbackInfosRequiringCallObjectIDsSetsByTribeID = {}
end

function serverStorageArea:removeAllCallbacksForStorageAvailabilityChange(objectID, tribeIDOrNilForAll)
    -- mj:log("serverStorageArea:removeAllCallbacksForStorageAvailabilityChange:", objectID)

    local function removeForTribeInfo(tribeID, tribeInfo)
        if tribeInfo and tribeInfo.availablityChangeStorageTypesByObjectID[objectID] then
            for storageTypeIndex, trueFalse in pairs(tribeInfo.availablityChangeStorageTypesByObjectID[objectID]) do
                local callbackInfos = tribeInfo.availablityChangeCallbackInfos[storageTypeIndex]
                if callbackInfos then
                    local callbackInfo = callbackInfos[objectID]
                    if callbackInfo then
                        local storageAreaInfo = storageAreas[callbackInfo.availableStorageAreaID]
                        if storageAreaInfo and storageAreaInfo.assignedCallbackObjectIDs[objectID] then
                            storageAreaInfo.assignedCallbackObjectIDs[objectID][tribeID] = nil
                            if not next(storageAreaInfo.assignedCallbackObjectIDs[objectID]) then
                                storageAreaInfo.assignedCallbackObjectIDs[objectID] = nil
                            end
                        end
                        callbackInfos[objectID] = nil
                    end
                end
            end
    
            tribeInfo.availablityChangeStorageTypesByObjectID[objectID] = nil
            tribeInfo.availablityChangeCallbackInfosByObjectID[objectID] = nil

            --mj:error("serverStorageArea:removeAllCallbacksForStorageAvailabilityChange:", objectID)
            --[[
            for storageAreaObjectID, storageAreaInfo in pairs(storageAreas) do
                if storageAreaInfo.assignedCallbackObjectIDs[objectID] then
                    if storageAreaInfo.assignedCallbackObjectIDs[objectID][tribeID] then
                        mj:error("maybe should have been removed:")
                        error()
                    end
                end
            end]]
        end
    end

    if tribeIDOrNilForAll then
        removeForTribeInfo(tribeIDOrNilForAll, availabilityChangeInfosByTribeID[tribeIDOrNilForAll])
    else
        for tribeID,tribeInfo in pairs(availabilityChangeInfosByTribeID) do
            removeForTribeInfo(tribeID, tribeInfo)
        end
    end
end




local function callCallbacksForAnyAvailabilityChange(object, storageAreaInfo, newAvailabilityInfo, oldAvailabilityInfo, tribeID)

    --mj:log("callCallbacksForAnyAvailabilityChange a")
    local availabilityChangeInfo = availabilityChangeInfosByTribeID[tribeID]
    if not availabilityChangeInfo then
        return
    end

    --mj:log("callCallbacksForAnyAvailabilityChange b")

    local function findNewMatchOrCallUnavailableCallback(callbackObjectID, callbackInfo)
        --mj:log("findNewMatchOrCallUnavailableCallback:", callbackObjectID)
        
        if callbackInfo.availableStorageAreaID then
            local oldStorageAreaInfo = storageAreas[callbackInfo.availableStorageAreaID]
            if oldStorageAreaInfo then
                if oldStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] then
                    oldStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID][tribeID] = nil
                    if not next(oldStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID]) then
                        oldStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] = nil
                    end
                end
            end
            callbackInfo.availableStorageAreaID = nil
            callbackInfo.available = false
        end

        local newMatch = findAnyStorageAreaAvailableForObjectType(tribeID, callbackInfo.objectTypeIndex, callbackInfo.pos, callbackInfo.maxDistance2)

        --mj:log("newMatch:", newMatch)

        if newMatch then
            callbackInfo.availableStorageAreaID = newMatch
            callbackInfo.available = true
            local newStorageAreaInfo = storageAreas[newMatch]
            if not newStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] then
                newStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] = {}
            end
            newStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID][tribeID] = true
        else

            --todo remove this debug
            --[[local availablityChangeCallbackInfosByObjectIDReloaded = availabilityChangeInfosByTribeID[tribeID].availablityChangeCallbackInfosByObjectID
            if not availablityChangeCallbackInfosByObjectIDReloaded[callbackObjectID] then
                mj:error("lost availablityChangeCallbackInfosByObjectID in findNewMatchOrCallUnavailableCallback A")
                error()
            end]]

            callbackInfo.func(tribeID, callbackObjectID, callbackInfo.objectTypeIndex, callbackInfo.available)

            --todo remove this debug
            --[[availablityChangeCallbackInfosByObjectIDReloaded = availabilityChangeInfosByTribeID[tribeID].availablityChangeCallbackInfosByObjectID
            if not availablityChangeCallbackInfosByObjectIDReloaded[callbackObjectID] then
                mj:error("lost availablityChangeCallbackInfosByObjectID in findNewMatchOrCallUnavailableCallback B")
                error()
            end]]
        end
    end

    local function makeNewlyAvailableIfCloseEnough(callbackObjectID, callbackInfo)
        local callbackDistance2 = length2(callbackInfo.pos - object.pos)
        if callbackDistance2 < callbackInfo.maxDistance2 then
            if callbackInfo.availableStorageAreaID then
                local oldStorageAreaInfo = storageAreas[callbackInfo.availableStorageAreaID]
                if oldStorageAreaInfo then
                    if oldStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] then
                        oldStorageAreaInfo.assignedCallbackObjectIDs[callbackObjectID][tribeID] = nil
                        if not next(storageAreaInfo.assignedCallbackObjectIDs[callbackObjectID]) then
                            storageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] = nil
                        end
                    end
                end
            end

            callbackInfo.available = true
            callbackInfo.availableStorageAreaID = object.uniqueID
            if not storageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] then
                storageAreaInfo.assignedCallbackObjectIDs[callbackObjectID] = {}
            end
            storageAreaInfo.assignedCallbackObjectIDs[callbackObjectID][tribeID] = true
            callbackInfo.func(tribeID, callbackObjectID, callbackInfo.objectTypeIndex, callbackInfo.available)
        end
    end

    local function markAvailableToMatchingObjects()
        if newAvailabilityInfo.storageTypeIndex then
            --mark all unavailable and with an object type matching newAvailabilityInfo.storageTypeIndex and not on newAvailabilityInfo.objectTypeBlackList near by as available
            local objectTypeBlackList = newAvailabilityInfo.objectTypeBlackList or {}
            
            local callbacks = availabilityChangeInfo.availablityChangeCallbackInfos[newAvailabilityInfo.storageTypeIndex]
            if callbacks then
                for callbackObjectID,callbackInfo in pairs(callbacks) do
                    if not callbackInfo.available and not objectTypeBlackList[callbackInfo.objectTypeIndex] then
                        makeNewlyAvailableIfCloseEnough(callbackObjectID, callbackInfo, tribeID)
                    end
                end
            end
        else
            --mark all unavailable near by as available
            for storageTypeIndex, callbacks in pairs(availabilityChangeInfo.availablityChangeCallbackInfos) do
                for callbackObjectID,callbackInfo in pairs(callbacks) do
                    if not callbackInfo.available then
                        makeNewlyAvailableIfCloseEnough(callbackObjectID, callbackInfo, tribeID)
                    end
                end
            end
        end
    end

    local changed = false

    if newAvailabilityInfo.available ~= oldAvailabilityInfo.available then
        --mj:log("newAvailabilityInfo.available:", newAvailabilityInfo.available)
        changed = true
        if newAvailabilityInfo.available then
            markAvailableToMatchingObjects()
        else
            --mark all available that were referencing this storage area as unavailable (if no other valid location found)
            --mj:log("storageAreaInfo.assignedCallbackObjectIDs:", storageAreaInfo.assignedCallbackObjectIDs)
            for callbackObjectID,tribeIDs in pairs(storageAreaInfo.assignedCallbackObjectIDs) do
                for otherTribeID,v in pairs(tribeIDs) do
                    local tribeInfo = availabilityChangeInfosByTribeID[otherTribeID]
                    if tribeInfo then
                        local callbackInfo = tribeInfo.availablityChangeCallbackInfosByObjectID[callbackObjectID]
                        if callbackInfo then
                            findNewMatchOrCallUnavailableCallback(callbackObjectID, callbackInfo, otherTribeID)
                        end
                    end
                end
            end
            storageAreaInfo.assignedCallbackObjectIDs = {}
        end
    else
        if newAvailabilityInfo.storageTypeIndex ~= oldAvailabilityInfo.storageTypeIndex then
            changed = true
            --mark all available that were referencing this storage area and that dont require the new storageTypeIndex as unavailable  (if no other valid location found)
            if newAvailabilityInfo.storageTypeIndex and newAvailabilityInfo.storageTypeIndex > 0 then
                for callbackObjectID,tribeIDs in pairs(storageAreaInfo.assignedCallbackObjectIDs) do
                    for otherTribeID,v in pairs(tribeIDs) do
                        local tribeInfo = availabilityChangeInfosByTribeID[otherTribeID]
                        if tribeInfo then
                            local callbackInfo = tribeInfo.availablityChangeCallbackInfosByObjectID[callbackObjectID]
                            
                            if callbackInfo then
                                local requiredStorageTypeIndex = storage.typesByResource[gameObject.types[callbackInfo.objectTypeIndex].resourceTypeIndex]
                                if requiredStorageTypeIndex ~= newAvailabilityInfo.storageTypeIndex then
                                    findNewMatchOrCallUnavailableCallback(callbackObjectID, callbackInfo, otherTribeID)
                                end
                            end
                        end
                    end
                end
            end

            markAvailableToMatchingObjects()
        elseif newAvailabilityInfo.storageTypeIndex then
            if newAvailabilityInfo.objectTypeBlackList or oldAvailabilityInfo.objectTypeBlackList then
                local newAvailabilityInfoBlackList = newAvailabilityInfo.objectTypeBlackList or {}
                local oldAvailabilityInfoBlackList = oldAvailabilityInfo.objectTypeBlackList or {}

                for objectTypeIndex,value in pairs(newAvailabilityInfoBlackList) do
                    if value and (not oldAvailabilityInfo[objectTypeIndex]) then
                        changed = true
                        --mark all available that were referencing this storage area and that are of type objectTypeIndex as unavailable (if no other valid location found)
                        for callbackObjectID,tribeIDs in pairs(storageAreaInfo.assignedCallbackObjectIDs) do

                            for otherTribeID,v in pairs(tribeIDs) do
                                local tribeInfo = availabilityChangeInfosByTribeID[otherTribeID]
                                if tribeInfo then
                                    local callbackInfo = tribeInfo.availablityChangeCallbackInfosByObjectID[callbackObjectID]
                                    if callbackInfo and callbackInfo.objectTypeIndex == objectTypeIndex then
                                        findNewMatchOrCallUnavailableCallback(callbackObjectID, callbackInfo, otherTribeID)
                                    end
                                end
                            end
                        end
                    end
                end
                for objectTypeIndex,value in pairs(oldAvailabilityInfoBlackList) do
                    if value and (not newAvailabilityInfoBlackList[objectTypeIndex]) then
                        changed = true
                        --mark all unavailable with an object type matching objectTypeIndex near by as available
                        local callbacks = availabilityChangeInfo.availablityChangeCallbackInfos[newAvailabilityInfo.storageTypeIndex]
                        if callbacks then
                            for callbackObjectID,callbackInfo in pairs(callbacks) do
                                if not callbackInfo.available and callbackInfo.objectTypeIndex == objectTypeIndex then
                                    makeNewlyAvailableIfCloseEnough(callbackObjectID, callbackInfo, tribeID)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return changed
end

local function doChecksForAvailibilityChange(storageObject, storageAreaInfo)
    local anyChanged = false
    if storageAreaInfo.availabilityInfosByTribeID then
       for tribeID,availabilityInfo in pairs(storageAreaInfo.availabilityInfosByTribeID) do
            local newAvailibilityInfo = generateAvailabilityInfo(storageObject, tribeID)
            --mj:log("doChecksForAvailibilityChange storageObject:", storageObject.uniqueID, " tribe:", tribeID, " old:", availabilityInfo, " new:", newAvailibilityInfo)
            storageAreaInfo.availabilityInfosByTribeID[tribeID] = newAvailibilityInfo
            local thisChanged = callCallbacksForAnyAvailabilityChange(storageObject, storageAreaInfo, newAvailibilityInfo, availabilityInfo, tribeID)
            if thisChanged then
                anyChanged = true
            end
       end
    end

    if anyChanged then
        serverLogistics:updateMaintenceRequiredForConnectedObjects(storageObject.uniqueID) -- must be after storageAreaInfo.availabilityInfo is set
    end
end

function serverStorageArea:updateAllStorageAreaAvailabilityInfosForRelationsSettingsChange(tribeID)
    --mj:log("updating all storage areas:", tribeID)
    for objectID, storageAreaInfo in pairs(storageAreas) do

        local storageObject = serverGOM:getObjectWithID(objectID)

        if not storageAreaInfo.availabilityInfosByTribeID then
            storageAreaInfo.availabilityInfosByTribeID = {}
        end

        local oldAvailabilityInfo = storageAreaInfo.availabilityInfosByTribeID[tribeID]
        local newAvailibilityInfo = generateAvailabilityInfo(storageObject, tribeID)

       -- mj:log("newAvailibilityInfo objectID:", objectID, " info:", newAvailibilityInfo)

        if oldAvailabilityInfo then
            storageAreaInfo.availabilityInfosByTribeID[tribeID] = newAvailibilityInfo
            local changed = callCallbacksForAnyAvailabilityChange(storageObject, storageAreaInfo, newAvailibilityInfo, oldAvailabilityInfo, tribeID)

            if changed then
                --mj:log("changed")
                serverLogistics:updateMaintenceRequiredForConnectedObjects(storageObject.uniqueID)
            end
        else
            storageAreaInfo.availabilityInfosByTribeID[tribeID] = newAvailibilityInfo
        end
    end
end

function serverStorageArea:getObjectTypeIndexMatchingResourceType(storageObject, validResourceTypeIndexSet, restrictedObjectTypeIndexes)
    local inventory = storageObject.sharedState.inventory
    if inventory.countsByObjectType then
        for inventoryObjectTypeIndex, count in pairs(inventory.countsByObjectType) do
            if not restrictedObjectTypeIndexes or not restrictedObjectTypeIndexes[inventoryObjectTypeIndex] then
                if count > 0 then
                    local inventoryResourceTypeIndex = gameObject.types[inventoryObjectTypeIndex].resourceTypeIndex
                    if validResourceTypeIndexSet[inventoryResourceTypeIndex] then
                        return inventoryObjectTypeIndex
                    end
                end
            end
        end
    end
    return nil
end

function serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(storageAreaID, objectTypeIndex, tribeID, optionsOrNil)
    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
    local storageAreaInfo = storageAreas[storageAreaID]
    if storageAreaInfo then
        local availabilityInfo = getAvailabilityInfo(storageAreaID, storageAreaInfo, tribeID)
        --mj:log("availabilityInfo:", availabilityInfo, " storageAreaID:",storageAreaID, " storageAreaInfo:", storageAreaInfo, " tribeID:", tribeID)
        if availabilityInfo.available then
            local storageObject = serverGOM:getObjectWithID(storageAreaID)
            if storageObject then
                local allowTradeRequestsMatchingResourceTypeIndex = optionsOrNil and optionsOrNil.allowTradeRequestsMatchingResourceTypeIndex
                local allowQuestsMatchingResourceTypeIndex = optionsOrNil and optionsOrNil.allowQuestsMatchingResourceTypeIndex
                if storageObject.sharedState then
                    local tradeRequest = storageObject.sharedState.tradeRequest
                    if tradeRequest then
                        if tradeRequest.resourceTypeIndex ~= allowTradeRequestsMatchingResourceTypeIndex then
                            return nil
                        end
                    end
                    
                    local questState = storageObject.sharedState.quest
                    if questState then
                        if questState.resourceTypeIndex ~= allowQuestsMatchingResourceTypeIndex then
                            return nil
                        end
                    end
                end
                

                if not objectTypeIndexIsRestricted(tribeID, storageObject.sharedState, objectTypeIndex) then
                    --mj:log("dave a")
                    local maxItems = storage:maxItemsForResourceType(resourceTypeIndex, gameObject.types[storageObject.objectTypeIndex].storageAreaDistributionTypeIndex)
                    if maxItems == 0 then
                        return nil
                    end
                    --mj:log("dave b")
                    --mj:log("in serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType:", storageAreaID,  " maxItems:", maxItems)
                    local matchFound = false
                    local matchingContentsFound = false
                    local emptyFound = true
                    local inventory = storageObject.sharedState.inventory
                    if inventory and inventory.countsByObjectType then
                        if inventory.objects then
                            local storedCount = #inventory.objects
                            if storedCount >= maxItems then
                                --mj:log("dave c")
                                --mj:log("in serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType:", storageAreaID, " storedCount > maxItems. storedCount:", storedCount)
                                return nil
                            end
                            --mj:log("in serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType:", storageAreaID, " storedCount < maxItems. storedCount:", storedCount)
                        end

                        local countsByObjectType = inventory.countsByObjectType
                        for currentObjectTypeIndex,count in pairs(countsByObjectType) do
                            if count > 0 then
                                emptyFound = false
                                local inventoryResourceType = gameObject.types[currentObjectTypeIndex].resourceTypeIndex
                                if storage:resourceTypesCanBeStoredToegether(inventoryResourceType, resourceTypeIndex) then
                                    matchFound = true
                                    matchingContentsFound = true
                                    break
                                end
                            end
                        end
                    end
                    if not matchFound then
                        if objectTypeMatchesRestrictedAllowedType(tribeID, storageObject.sharedState, objectTypeIndex) then
                            matchFound = true
                        end
                    end
                    if emptyFound or matchFound then
                    -- mj:log("match:", emptyFound, " - ", matchFound, " object:", storageObject)
                        return {
                            matchFound = matchFound,
                            matchingContentsFound = matchingContentsFound,
                            object = storageObject,
                            maxItems = maxItems,
                        }
                    end
                end
            end
        end
    end
    return nil
end

function serverStorageArea:storageAreaRemainingAllowedItemsCount(storageAreaObjectID, objectTypeIndex, tribeID)
    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local availabilityInfo = getAvailabilityInfo(storageAreaObjectID, storageAreaInfo, tribeID)
        if availabilityInfo.available then
            local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
            if storageObject then
                local sharedState = storageObject.sharedState
                if not objectTypeIndexIsRestricted(tribeID, sharedState, objectTypeIndex) then
                    
                    local maxItems = storage:maxItemsForResourceType(resourceTypeIndex, gameObject.types[storageObject.objectTypeIndex].storageAreaDistributionTypeIndex)
                    if maxItems == 0 then
                        return nil
                    end

                    local matchFound = false
                    local emptyFound = true
                    local inventory = sharedState.inventory
                    local storedCount = 0
                    if inventory and inventory.countsByObjectType then
                        if inventory.objects then
                            storedCount = #inventory.objects
                        end
                        if storedCount >= maxItems then
                            return nil
                        end
                        local countsByObjectType = inventory.countsByObjectType
                        for currentObjectTypeIndex,count in pairs(countsByObjectType) do
                            if count > 0 then
                                emptyFound = false
                                local inventoryResourceType = gameObject.types[currentObjectTypeIndex].resourceTypeIndex
                                if storage:resourceTypesCanBeStoredToegether(inventoryResourceType, resourceTypeIndex) then
                                    matchFound = true
                                    break
                                end
                            end
                        end
                    end
                    if not matchFound then
                        if objectTypeMatchesRestrictedAllowedType(tribeID, sharedState, objectTypeIndex) then
                            matchFound = true
                        end
                    end
                    if emptyFound or matchFound then
                        local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
                        if tribeSettings.maxQuantityFraction and tribeSettings.maxQuantityFraction < 0.9995 then
                            local restrictedMaxItems = math.floor(tribeSettings.maxQuantityFraction * maxItems)
                            maxItems = mjm.clamp(restrictedMaxItems, 1, maxItems)
                        end

                        return maxItems - storedCount
                    end
                end
            end
        end
    end
    return nil
end

function serverStorageArea:storageAreaIsAvailableForObjectType(tribeID, objectTypeIndex, searchPos, maxDistance2OrNil)
    for objectID, info in pairs(storageAreas) do
        local object = serverGOM:getObjectWithID(objectID)
        if object and length2(searchPos - object.pos) < (maxDistance2OrNil or serverResourceManager.storageResourceMaxDistance2) then
            local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(objectID, objectTypeIndex, tribeID)
            if matchInfo then
                return true
            end
        end
    end
    
    return false
end

function serverStorageArea:bestStorageAreaForObjectType(tribeID, objectTypeIndex, searchPosOrNil, optionsOrNil) --if searchPosOrNil is not provided, it will only check storage areas that were created by the given tribe ID, otherwise we check every storage area in the world
    --mj:log("serverStorageArea:bestStorageAreaForObjectType:", objectTypeIndex)
    local bestResult = nil
    local bestHeuristic = -100000
    local excludeStorageAreaIDOrNil = optionsOrNil and optionsOrNil.excludeStorageAreaID
    local maxDistance2 = ((optionsOrNil and optionsOrNil.maxDistance2) or serverResourceManager.storageResourceMaxDistance2)
    for objectID, info in pairs(storageAreas) do
        if objectID ~= excludeStorageAreaIDOrNil then
            local object = serverGOM:getObjectWithID(objectID)
            local distance2 = searchPosOrNil and object and length2(searchPosOrNil - object.pos)
            if (not searchPosOrNil) or distance2 < maxDistance2 then
                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(objectID, objectTypeIndex, tribeID, optionsOrNil)
                if matchInfo and matchInfo.object and (searchPosOrNil or matchInfo.object.sharedState.tribeID == tribeID) then
                    local distance = 0.0
                    if searchPosOrNil then
                        distance = math.sqrt(distance2)
                    end
                    local heuristic = mj:pToM(serverResourceManager.storageResourceMaxDistance) - mj:pToM(distance) + 1.0
                    if matchInfo.matchFound then
                        heuristic = heuristic + 50.0
                        if matchInfo.matchingContentsFound then
                            heuristic = heuristic + 10.0
                        end
                    end

                    --mj:log("found match:", matchInfo, " heuristic:", heuristic)

                    local evolution = evolvingObject.evolutions[objectTypeIndex]
                    if evolution then
                        if evolution.storageCoveredPriority == "covered" then
                            if matchInfo.object.sharedState.covered then
                                heuristic = heuristic + 40.0
                            end
                        elseif evolution.storageCoveredPriority == "uncovered" then
                            if not matchInfo.object.sharedState.covered then
                                heuristic = heuristic + 40.0
                            end
                        end
                    end

                    local storageAreaWhitelistType = gameObject.types[matchInfo.object.objectTypeIndex].storageAreaWhitelistType
                    if storageAreaWhitelistType then
                        local incomingObjectStorageTypeIndex = storage.typesByResource[gameObject.types[objectTypeIndex].resourceTypeIndex]
                        local incomingObjectStorageType = storage.types[incomingObjectStorageTypeIndex]

                        if (incomingObjectStorageType.whitelistTypes and incomingObjectStorageType.whitelistTypes[storageAreaWhitelistType]) then
                            heuristic = heuristic + 40.0
                        end
                    end

                    if heuristic > bestHeuristic then
                        matchInfo.distanceForOptimization = distance
                        bestHeuristic = heuristic
                        bestResult = matchInfo
                    end
                end
            end
        end
    end
    
    return bestResult
end

function serverStorageArea:getAllowItemUse(storageAreaSharedState, sapienTribeID, tribeSettings)
    --mj:log("getAllowItemUse sapienTribeID:", sapienTribeID, " storageAreaSharedState:", storageAreaSharedState)
    if tribeSettings then
        if tribeSettings.removeAllItems or tribeSettings.removeAllDueToDeconstruct then
            --mj:log("a")
            return true
        end


        if tribeSettings.disallowItemUse then
            --mj:log("b")
            return false
        end

        if tribeSettings.disallowItemUse ~= nil then
            --mj:log("c")
            return true
        end
    end

    local storageAreaTribeID = storageAreaSharedState.tribeID

    if storageAreaTribeID == sapienTribeID then
       -- mj:log("d")
        return true
    end


    if storageAreaSharedState.tradeOffer then
        local destinationState = serverDestination:getDestinationState(storageAreaTribeID)
        --mj:log("destinationState:", destinationState, " storageAreaSharedState:", storageAreaSharedState)
        local relationship = destinationState and destinationState.relationships and destinationState.relationships[sapienTribeID]
        if relationship then
            if storageAreaSharedState.tradeOffer.resourceTypeIndex then
                local tradeOfferPurchases = relationship.tradeOfferPurchases
                if tradeOfferPurchases and tradeOfferPurchases[storageAreaSharedState.tradeOffer.resourceTypeIndex] and tradeOfferPurchases[storageAreaSharedState.tradeOffer.resourceTypeIndex] > 0 then
                    return true
                end
            elseif storageAreaSharedState.tradeOffer.objectTypeIndex then
                local tradeOfferObjectTypePurchases = relationship.tradeOfferObjectTypePurchases 
                if tradeOfferObjectTypePurchases and tradeOfferObjectTypePurchases[storageAreaSharedState.tradeOffer.objectTypeIndex] and tradeOfferObjectTypePurchases[storageAreaSharedState.tradeOffer.objectTypeIndex] > 0 then
                    return true
                end
            end

        end
    end

    local tribeRelationsSettings = serverWorld:getTribeRelationsSettings(storageAreaTribeID, sapienTribeID)
    if tribeRelationsSettings then
        --mj:log("e")
        return tribeRelationsSettings.storageAlly
    end

    if serverWorld:tribeIsValidOwner(storageAreaTribeID) then
        --mj:log("f")
        return false
    end
    --mj:log("g")
    return true
end

function serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, objectTypeIndex, count)
    local tribeID = storageObject.sharedState.tribeID
    local resourceCounts = serverStorageArea.resourceCountsByTribeID[tribeID]
    if not resourceCounts then
        resourceCounts = {}
        serverStorageArea.resourceCountsByTribeID[tribeID] = resourceCounts
    end

    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
    local oldCount = resourceCounts[resourceTypeIndex] or 0
    local newCount = oldCount + count
    resourceCounts[resourceTypeIndex] = newCount

    local statsKey = "r_" .. resource.types[resourceTypeIndex].key
    serverStatistics:setValueForToday(tribeID, statistics.types[statsKey].index, newCount)
    serverTutorialState:checkForTutorialNotificationDueToAddition(tribeID, resourceTypeIndex, newCount)

    if resource.types[resourceTypeIndex].foodValue then
        local foodCount = serverStorageArea.foodCountsByTribeID[tribeID]
        if not foodCount then
            foodCount = 0
        end
        local newFoodCount = foodCount + count
        serverStorageArea.foodCountsByTribeID[tribeID] = newFoodCount

        serverStatistics:setValueForToday(tribeID, statistics.types.foodCount.index, newFoodCount)
        serverTutorialState:checkForTutorialNotificationDueToFoodAddition(tribeID, newFoodCount)
    end
end

local function updateBlowAwaySetsDueToCoveredStatusChange(storageAreaObjectID)
    --mj:log("updateBlowAwaySetsDueToCoveredStatusChange")
    local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
    if storageObject then
        local contentsStorageTypeIndex = storageObject.sharedState.contentsStorageTypeIndex
        local storageType = storage.types[contentsStorageTypeIndex]
        
        if storageType and storageType.windDestructableChanceIndex then
            
            --mj:log("storageType.windDestructableChanceIndex:", storageType.windDestructableChanceIndex)
            local set = serverWeather.windDamageLevelSets[storageType.windDestructableChanceIndex]
            if set then
                if storageObject.sharedState.covered then
                    serverGOM:removeObjectFromSet(storageObject, set)
                else
                    serverGOM:addObjectToSet(storageObject, set)
                end
            end
        end
    end
end

local function setContentsStorageTypeIndex(storageObject, newContentsStorageTypeIndex)

    local oldContentsStorageTypeIndex = storageObject.sharedState.contentsStorageTypeIndex
    if oldContentsStorageTypeIndex ~= newContentsStorageTypeIndex then
        local oldBlowAwayChance = nil
        local newBlowAwayChance = nil
        if oldContentsStorageTypeIndex then
            oldBlowAwayChance = storage.types[oldContentsStorageTypeIndex].windDestructableChanceIndex
        end

        if newContentsStorageTypeIndex then
            newBlowAwayChance = storage.types[newContentsStorageTypeIndex].windDestructableChanceIndex
        end
        
        if oldBlowAwayChance ~= newBlowAwayChance then
            local removeSet = serverWeather.windDamageLevelSets[oldBlowAwayChance]
            if removeSet then
                serverGOM:removeObjectFromSet(storageObject, removeSet)
            end
            
            if not storageObject.sharedState.covered then
                local addSet = serverWeather.windDamageLevelSets[newBlowAwayChance]
                if addSet then
                    serverGOM:addObjectToSet(storageObject, addSet)
                end
            end
        end
    end

    if newContentsStorageTypeIndex then
        storageObject.sharedState:set("contentsStorageTypeIndex", newContentsStorageTypeIndex)
    else
        storageObject.sharedState:remove("contentsStorageTypeIndex")
    end
end

function serverStorageArea:removeObjectAtIndex(storageAreaObjectID, index)
    local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
    if storageObject then
        local storageAreaInfo = storageAreas[storageAreaObjectID]
        if storageAreaInfo then
            local sharedState = storageObject.sharedState
            local inventory = sharedState.inventory
            if inventory then
                local objects = inventory.objects

                if objects and #objects >= index then
                    
                    local thisObjectInfo = objects[index]

                    --[[if not inventory.countsByObjectType[thisObjectInfo.objectTypeIndex] then --todo remove this, crash in 0.5.0.0
                        mj:error("missing inventory.countsByObjectType[thisObjectInfo.objectTypeIndex]:", thisObjectInfo.objectTypeIndex)
                        mj:log("storageAreaObjectID:", storageAreaObjectID, "sharedState:", sharedState, " thisObjectInfo:", thisObjectInfo)
                        error()
                    end]]

                    local newCount = inventory.countsByObjectType[thisObjectInfo.objectTypeIndex] - 1
                    if newCount == 0 then
                        sharedState:remove("inventory", "countsByObjectType", thisObjectInfo.objectTypeIndex)
                    else
                        sharedState:set("inventory", "countsByObjectType", thisObjectInfo.objectTypeIndex, newCount)
                    end

                    sharedState:removeFromArray("inventory", "objects", index)


                   --[[if (not inventory.objects) or #inventory.objects == 0 then
                        callCallbacksForResourceAreaAvailabilityChange(storageObject, changeTypes.becameEmpty)
                    elseif wasFull then
                        callCallbacksForResourceAreaAvailabilityChange(storageObject, changeTypes.becameAvailableForDeliveries)
                    end]]
                    

                    if (not inventory.objects) or #inventory.objects == 0 then
                        setContentsStorageTypeIndex(storageObject, nil)
                        --serverLogistics:updateLogisticsRoutesForStorageAreaBecomingEmpty(storageObject.uniqueID)
                    end
                    
                    doChecksForAvailibilityChange(storageObject, storageAreaInfo)
                    serverResourceManager:updateResourcesForObject(storageObject)
                    serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, thisObjectInfo.objectTypeIndex, -1)

                    return thisObjectInfo
                end
            end
        end
    end
    return nil
end


function serverStorageArea:availableTransferCountsByObjectType(storageAreaObjectID, tribeID) -- assumes not limited ability
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
        local sharedState = storageObject.sharedState

        local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
        if not serverStorageArea:getAllowItemUse(sharedState, tribeID, tribeSettings) then
            return nil
        end
        
        local inventory = sharedState.inventory
        if inventory then
            local result = {}
            for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
                if count > 0 then
                    result[objectTypeIndex] = math.ceil(count / storage:maxCarryCountForResourceType(gameObject.types[objectTypeIndex].resourceTypeIndex))
                end
            end
            if not next(result) then
                return nil
            end
            return result
        end
    end
    return nil
end

function serverStorageArea:availableTransferCount(storageAreaObjectID, tribeID) -- assumes not limited ability
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
        local sharedState = storageObject.sharedState

        local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
        if not serverStorageArea:getAllowItemUse(sharedState, tribeID, tribeSettings) then
            return 0
        end
        
        local inventory = sharedState.inventory
        if inventory then
            local objectCount = #inventory.objects
            if objectCount > 0 then
                local firstObjectTypeIndex = inventory.objects[1].objectTypeIndex
                return math.ceil(objectCount / storage:maxCarryCountForResourceType(gameObject.types[firstObjectTypeIndex].resourceTypeIndex)), firstObjectTypeIndex
            end
        end
    end
    return 0
end

function serverStorageArea:availableObjectCount(storageAreaObjectID, objectTypeIndex, tribeIDOrNilToIgnorePermissions)
    if objectTypeIndex then
        local storageAreaInfo = storageAreas[storageAreaObjectID]
        if storageAreaInfo then
            local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
            local sharedState = storageObject.sharedState

            if tribeIDOrNilToIgnorePermissions then
                local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeIDOrNilToIgnorePermissions) or {}
                if not serverStorageArea:getAllowItemUse(sharedState, tribeIDOrNilToIgnorePermissions, tribeSettings) then
                    return 0
                end
            end
            
            local inventory = sharedState.inventory
            if inventory and inventory.countsByObjectType and inventory.countsByObjectType[objectTypeIndex] then
                return inventory.countsByObjectType[objectTypeIndex]
            end
        end
    end
    return 0
end

function serverStorageArea:storageAreaHasObjectAvailable(storageAreaObjectID, objectTypeIndex, tribeIDOrNilToIgnorePermissions)
    return serverStorageArea:availableObjectCount(storageAreaObjectID, objectTypeIndex, tribeIDOrNilToIgnorePermissions) > 0
end


function serverStorageArea:storageAreaHasAnyObjectAvailableForTribe(storageAreaObjectID, tribeIDOrNilToIgnorePermissions)
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
        local sharedState = storageObject.sharedState

        if tribeIDOrNilToIgnorePermissions then
            local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeIDOrNilToIgnorePermissions) or {}
            if not serverStorageArea:getAllowItemUse(sharedState, tribeIDOrNilToIgnorePermissions, tribeSettings) then
                return false
            end
        end
        
        local inventory = sharedState.inventory
        if inventory and inventory.countsByObjectType then
            for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
                if count > 0 then
                    return true
                end
            end
        end
    end
    return false
end

function serverStorageArea:availableCountsByObjectType(storageAreaObjectID, tribeID)

    ----disabled--mj:objectLog(storageAreaObjectID, "serverStorageArea:availableCountsByObjectType A")
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        ----disabled--mj:objectLog(storageAreaObjectID, "serverStorageArea:availableCountsByObjectType B")
        local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
        local sharedState = storageObject.sharedState

        local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
        --mj:log("tribeSettings:", tribeSettings, " tribeID:", tribeID)
        if not serverStorageArea:getAllowItemUse(sharedState, tribeID, tribeSettings) then
            --disabled--mj:objectLog(storageAreaObjectID, " storageAreaTribeID == sapienTribeID:", sharedState.tribeID == tribeID, "serverStorageArea:availableCountsByObjectType C:", tribeSettings, " tribeID:", tribeID)
            return nil
        end
        
        local inventory = sharedState.inventory
        if inventory then
            return inventory.countsByObjectType
        end
    end
    ----disabled--mj:objectLog(storageAreaObjectID, "serverStorageArea:availableCountsByObjectType D")
    return nil
end


function serverStorageArea:storedResourceCount(storageAreaObjectID, resourceTypeIndex)
    if resourceTypeIndex then
        local storageAreaInfo = storageAreas[storageAreaObjectID]
        if storageAreaInfo then
            local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
            local sharedState = storageObject.sharedState
            
            local inventory = sharedState.inventory
            if inventory and inventory.countsByObjectType then
                local total = 0
                for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
                    if gameObject.types[objectTypeIndex].resourceTypeIndex == resourceTypeIndex then
                        total = total + count
                    end
                end
                return total
            end
        end
    end
    return 0
end


function serverStorageArea:storedObjectTypeCount(storageAreaObjectID, objectTypeIndex)
    if objectTypeIndex then
        local storageAreaInfo = storageAreas[storageAreaObjectID]
        if storageAreaInfo then
            local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
            local sharedState = storageObject.sharedState
            
            local inventory = sharedState.inventory
            if inventory and inventory.countsByObjectType then
                return inventory.countsByObjectType[objectTypeIndex] or 0
            end
        end
    end
    return 0
end

function serverStorageArea:removeObjectFromStorageArea(storageAreaObjectID, objectTypeIndexOrNil, checkAllowedUseTribeIDOrNil) --checkAllowedUseTribeIDOrNil is always given if a sapien is removing an item, and is the sapiens tribeID
    
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
        local sharedState = storageObject.sharedState
        
        if checkAllowedUseTribeIDOrNil then
            local tribeSettings = serverStorageArea:getTribeSettings(sharedState, checkAllowedUseTribeIDOrNil) or {}
            if not serverStorageArea:getAllowItemUse(sharedState, checkAllowedUseTribeIDOrNil, tribeSettings) then
                return nil
            end
        end

        local inventory = sharedState.inventory

        local objects = nil
        if inventory then
            objects = inventory.objects
        end

        if not objects or #objects == 0 then
            return nil
        end

        local objectTypeIndex = objectTypeIndexOrNil
        if not objectTypeIndex then
            objectTypeIndex = objects[#objects].objectTypeIndex
        end
        local objectInfo = nil

        if inventory and inventory.countsByObjectType and inventory.countsByObjectType[objectTypeIndex] then
            if inventory.countsByObjectType[objectTypeIndex] > 0 then

                local foundIndex = nil
                for i = #objects, 1, -1 do
                    local thisObjectInfo = objects[i]
                    if thisObjectInfo.objectTypeIndex == objectTypeIndex then
                        if not objectInfo or (objectInfo.fractionDegraded and thisObjectInfo.fractionDegraded and thisObjectInfo.fractionDegraded > objectInfo.fractionDegraded) then
                            foundIndex = i
                            objectInfo = thisObjectInfo
                        end
                    end
                end

                if foundIndex then

                    local newCount = inventory.countsByObjectType[objectTypeIndex] - 1

                    if newCount == 0 then
                        sharedState:remove("inventory", "countsByObjectType", objectTypeIndex)
                    else
                        sharedState:set("inventory", "countsByObjectType", objectTypeIndex, newCount)
                    end

                    sharedState:removeFromArray("inventory", "objects", foundIndex)
                end
            end
        end


        if objectInfo then
            if (not inventory.objects) or #inventory.objects == 0 then
                
                local storageTypeIndex = sharedState.contentsStorageTypeIndex
                if storageTypeIndex then
                    local storageType = storage.types[storageTypeIndex]
                    if storageType.windDestructableChanceIndex then
                        local set = serverWeather.windDamageLevelSets[storageType.windDestructableChanceIndex]
                        if set then
                            serverGOM:removeObjectFromSet(storageObject, set)
                        end
                    end
                end

                setContentsStorageTypeIndex(storageObject, nil)
                --serverLogistics:updateLogisticsRoutesForStorageAreaBecomingEmpty(storageObject.uniqueID)
                
            end

            doChecksForAvailibilityChange(storageObject, storageAreaInfo)
            
            serverResourceManager:updateResourcesForObject(storageObject)
            serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, objectTypeIndex, -1)



            local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
            
            if checkAllowedUseTribeIDOrNil then
                local wasTradeOfferPickup = false
                if storageObject.sharedState.tradeOffer then
                    local offerResourceTypeIndex = storageObject.sharedState.tradeOffer.resourceTypeIndex
                    local offerObjectTypeIndex = storageObject.sharedState.tradeOffer.objectTypeIndex
                    if offerResourceTypeIndex == resourceTypeIndex or offerObjectTypeIndex == objectTypeIndex then
                        wasTradeOfferPickup = serverTribe:completeTradeOfferPickup(storageObject, storageObject.sharedState.tribeID, checkAllowedUseTribeIDOrNil, resourceTypeIndex, objectTypeIndex)
                    end
                end

                if not wasTradeOfferPickup then
                    serverTribeAIPlayer:addGrievanceIfNeededForResourceTaken(storageObject.sharedState.tribeID, 
                    checkAllowedUseTribeIDOrNil, 
                    resourceTypeIndex,
                    objectTypeIndex,
                    1)
                end
            end

            local resourceType = resource.types[resourceTypeIndex]
            if resourceType.foodValue and (not resourceType.foodPoisoningChance) then
                if inventory.countsByObjectType then
                    for otherObjectTypeIndex,otherCount in pairs(inventory.countsByObjectType) do
                        if otherObjectTypeIndex ~= objectTypeIndex then
                            local otherResourceTypeIndex = gameObject.types[otherObjectTypeIndex].resourceTypeIndex
                            local otherResourceType = resource.types[otherResourceTypeIndex]
                            if otherResourceType.foodPoisoningChance then
                                objectInfo.contaminationResourceTypeIndex = otherResourceTypeIndex
                                break
                            end
                        end
                    end
                end 
            end

            return objectInfo
        end
    end
    return nil
end

function serverStorageArea:destroyObjectInStorageArea(storageAreaObjectID)
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
        local sharedState = storageObject.sharedState

        local inventory = sharedState.inventory

        local objects = nil
        if inventory then
            objects = inventory.objects
        end

        if not objects or #objects == 0 then
            return
        end

        local objectTypeIndex = objects[#objects].objectTypeIndex
        local removedObject = false
        local foundObjectInfo = nil

        if inventory and inventory.countsByObjectType and inventory.countsByObjectType[objectTypeIndex] then
            if inventory.countsByObjectType[objectTypeIndex] > 0 then

                local foundIndex = nil
                for i = #objects, 1, -1 do
                    local thisObjectInfo = objects[i]
                    if thisObjectInfo.objectTypeIndex == objectTypeIndex then
                        if not foundObjectInfo or (foundObjectInfo.fractionDegraded and thisObjectInfo.fractionDegraded and thisObjectInfo.fractionDegraded > foundObjectInfo.fractionDegraded) then
                            foundIndex = i
                            foundObjectInfo = thisObjectInfo
                        end
                    end
                end

                if foundIndex then
                    local newCount = inventory.countsByObjectType[objectTypeIndex] - 1

                    if newCount == 0 then
                        sharedState:remove("inventory", "countsByObjectType", objectTypeIndex)
                    else
                        sharedState:set("inventory", "countsByObjectType", objectTypeIndex, newCount)
                    end

                    sharedState:removeFromArray("inventory", "objects", foundIndex)
                    removedObject = true
                end
            end
        end


        if removedObject then
            if (not inventory.objects) or #inventory.objects == 0 then
                setContentsStorageTypeIndex(storageObject, nil)
                --serverLogistics:updateLogisticsRoutesForStorageAreaBecomingEmpty(storageObject.uniqueID)
            end

            doChecksForAvailibilityChange(storageObject, storageAreaInfo)
            serverStorageArea:updateMaintenanceRequired(storageObject)
            
            serverResourceManager:updateResourcesForObject(storageObject)
            serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, objectTypeIndex, -1)
            return foundObjectInfo
        end
    end
    return nil
end

function serverStorageArea:addObjectToStorageArea(storageAreaObjectID, objectInfo, clientTribeID)
    local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
    local sharedState = storageObject.sharedState
    local storageAreaInfo = storageAreas[storageAreaObjectID]
    if storageAreaInfo then
        local inventory = sharedState.inventory

        local objectTypeIndex = objectInfo.objectTypeIndex
        local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex

        if not resourceTypeIndex then
            --mj:warn("attempting to add object that has no resource type to storage area:", storageAreaObjectID, " of object type index:" .. objectInfo.objectTypeIndex)
            return false
        end
        
        if objectTypeIndexIsRestricted(clientTribeID, sharedState, objectTypeIndex) then
            --mj:warn("attempting to add object that is a restricted type to storage area:", storageAreaObjectID, " of object type index:" .. objectInfo.objectTypeIndex)
            return false
        end

        local availabilityInfo = getAvailabilityInfo(storageAreaObjectID, storageAreaInfo, clientTribeID)
        if not availabilityInfo.available then
            --mj:warn("attempting to add object to storage area that is unavailable:", storageAreaObjectID, " of object type index:" .. objectInfo.objectTypeIndex)
            return false
        end

        if inventory and inventory.countsByObjectType then
            for storedObjectTypeIndex,storedCount in pairs(inventory.countsByObjectType) do
                local inventoryResourceType = gameObject.types[storedObjectTypeIndex].resourceTypeIndex
                if (not storage:resourceTypesCanBeStoredToegether(inventoryResourceType, resourceTypeIndex)) and storedCount > 0 then
                    --mj:warn("attempting to add object to storage area:", storageAreaObjectID, " with differing resource type")
                    return false
                end
            end
        end


        local newIndex = 1
        if inventory and inventory.objects then
            newIndex = #inventory.objects + 1
        end

        local maxItems = storage:maxItemsForResourceType(resourceTypeIndex, gameObject.types[storageObject.objectTypeIndex].storageAreaDistributionTypeIndex)

        if newIndex > maxItems then
            --mj:warn("attempting to add object to full storage area:", storageAreaObjectID)
            return false
        end


        local newCount = 1
        if inventory and inventory.countsByObjectType and inventory.countsByObjectType[objectTypeIndex] then
            newCount = inventory.countsByObjectType[objectTypeIndex] + 1
        end

        objectInfo.orderContext = nil

        sharedState:set("inventory", "countsByObjectType", objectTypeIndex, newCount)
        sharedState:set("inventory", "objects", newIndex, objectInfo)

        local storageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex)
        if storageTypeIndex ~= sharedState.contentsStorageTypeIndex then
            setContentsStorageTypeIndex(storageObject, storageTypeIndex)
        end

        
        serverEvolvingObject:addCallbackForStorageAreaIfNeeded(storageAreaObjectID)

        --countsByObjectType[objectTypeIndex] = newCount
        --serverEvolvingObject:addCallbackForObjectWithinStorageAreaIfNeeded(storageAreaObjectID, objectInfo, newIndex)
        --table.insert(objects, objectInfo)

        --inventory.objects = objects
        --inventory.countsByObjectType = countsByObjectType


        --sharedState.inventory = inventory
        --serverGOM:saveObject(storageAreaObjectID)
        serverResourceManager:updateResourcesForObject(storageObject)
        serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, objectTypeIndex, 1)
        

       -- mj:log("serverStorageArea:addObjectToStorageArea")
        if storageObject.sharedState.tradeRequest then
            --mj:log("has tradeRequest")
            local requestedResourceTypeIndex = storageObject.sharedState.tradeRequest.resourceTypeIndex
            if requestedResourceTypeIndex == resourceTypeIndex then
                --mj:log("requestedResourceTypeIndex == resourceTypeIndex")
                serverTribe:completeTradeRequestDelivery(storageObject, storageObject.sharedState.tribeID, clientTribeID, resourceTypeIndex)
            end
        end

        if storageObject.sharedState.quest and storageObject.sharedState.quest.tribeID == clientTribeID then
            --mj:log("has quest")
            local requestedResourceTypeIndex = storageObject.sharedState.quest.resourceTypeIndex
            if requestedResourceTypeIndex == resourceTypeIndex then
                --mj:log("requestedResourceTypeIndex == resourceTypeIndex")
                serverTribe:completeQuestDelivery(storageObject, storageObject.sharedState.tribeID, clientTribeID, resourceTypeIndex)
            end
        end
        
        doChecksForAvailibilityChange(storageObject, storageAreaInfo)

        if newCount == 1 then
            --mj:log("new object added to storage area, updating serverLogistics")
            serverLogistics:updateMaintenceRequiredForConnectedObjects(storageObject.uniqueID)
        end

    else
        mj:warn("storageArea not loaded")
        return false
    end
    return true
end


local function requiresRemovalDueToRemoveAllItemsOrder(tribeID, storageObject)
    local sharedState = storageObject.sharedState
    local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
    if tribeSettings.removeAllItems then
        local inventory = sharedState.inventory
        if inventory and inventory.objects and #inventory.objects > 0 then
            return true
        end
    end
    return false
end

local function requiresItemDestruction(tribeID, storageObject)
    local sharedState = storageObject.sharedState
    local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
    if tribeSettings.destroyAllItems then
        local inventory = sharedState.inventory
        if inventory and inventory.objects and #inventory.objects > 0 then
            return true
        end
    end
    return false
end

function serverStorageArea:updateMaintenanceRequired(storageObject)
    --mj:log("updateMaintenanceRequired:", storageObject.uniqueID)
    --disabled--mj:objectLog(storageObject.uniqueID, "serverStorageArea:updateMaintenanceRequired")
    for tribeID,v in pairs(serverWorld.validOwnerTribeIDs) do --todo optimize out tribes with no possible interest in this storage area
        --[[if storageObject.uniqueID == mj.debugObject then
            mj:log("check tribe:", tribeID, " storage tribe:", storageObject.sharedState.tribeID)
        end]]
        if requiresRemovalDueToRemoveAllItemsOrder(tribeID, storageObject) or 
        serverLogistics:objectRequiresPickup(tribeID, storageObject, nil, nil, nil) or 
        serverLogistics:getDestinationIfObjectRequiresHaul(tribeID, storageObject) or
        requiresItemDestruction(tribeID, storageObject) then
            --[[if storageObject.uniqueID == mj.debugObject then
                mj:log("check tribe pass")
            end]]
            if not (storageObject.sharedState.requiresMaintenanceByTribe and storageObject.sharedState.requiresMaintenanceByTribe[tribeID]) then
                --mj:log("set required:", storageObject.uniqueID)
                serverGOM:addObjectToSet(storageObject, serverGOM.objectSets.maintenance)
                storageObject.sharedState:set("requiresMaintenanceByTribe", tribeID, true)
                --disabled--mj:objectLog(storageObject.uniqueID, "serverStorageArea:updateMaintenanceRequired requiresMaintenance:true")
            end
        else
            --[[if storageObject.uniqueID == mj.debugObject then
                mj:log("check tribe fail")
            end]]
            if storageObject.sharedState.requiresMaintenanceByTribe and storageObject.sharedState.requiresMaintenanceByTribe[tribeID] then
                --mj:log("set not required:", storageObject.uniqueID)
                storageObject.sharedState:remove("requiresMaintenanceByTribe", tribeID)
                if not next(storageObject.sharedState.requiresMaintenanceByTribe) then
                    storageObject.sharedState:remove("requiresMaintenanceByTribe")
                    serverGOM:removeObjectFromSet(storageObject, serverGOM.objectSets.maintenance)
                end
                --disabled--mj:objectLog(storageObject.uniqueID, "serverStorageArea:updateMaintenanceRequired requiresMaintenance:false")
            end
        end
    end
end

function serverStorageArea:blowAwayItems(storageObject, windDirection, maxCount)
    local sharedState = storageObject.sharedState
    
    local storageTypeIndex = sharedState.contentsStorageTypeIndex
    if storageTypeIndex then
        local storageType = storage.types[storageTypeIndex]
        if storageType.windDestructableChanceIndex then
            local inventory = sharedState.inventory
            if inventory and inventory.objects and #inventory.objects > 0 then
                --mj:log("blow away items:", storageObject.uniqueID)
                local startPos = storageObject.pos + storageObject.normalizedPos * mj:mToP(1.0)

                local count = 1
                if maxCount > 1 then
                    count = rng:randomInteger(maxCount) + 1
                    count = math.min(count, #inventory.objects)
                end
                for i=1,count do
                    local objectInfo = serverStorageArea:removeObjectFromStorageArea(storageObject.uniqueID, nil, nil)
                    if objectInfo then
                        local flyDirection = normalize(windDirection + rng:randomVec() * 0.5 + storageObject.normalizedPos * 0.25)
                        local flyVelocity = flyDirection * mj:mToP(10.0) * (0.5 + rng:randomValue())

                        local resourceType = resource.types[gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex]

                        if resourceType.impactCausesInjury or resourceType.impactCausesMajorInjury then
                            --mj:log("impactCausesInjury")
                            local halfSecondLocation = startPos + flyVelocity * 0.5
                            local closeSapiens = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.sapiens, halfSecondLocation, mj:mToP(10.0))
                            if closeSapiens and #closeSapiens > 0 then
                                --mj:log("found close sapiens:", #closeSapiens)
                                local randomSapienInfo = closeSapiens[rng:randomInteger(#closeSapiens) + 1]
                                local targetSapien = serverGOM:getObjectWithID(randomSapienInfo.objectID)
                                if targetSapien and (not targetSapien.sharedState.covered) then
                                    flyVelocity = (targetSapien.pos - startPos) * 2.0
                                    
                                    --mj:log("serverSapien:fallAndGetInjured:", targetSapien.uniqueID)
                                    
                                    local options = {
                                        preventMajorInjuries = (not resourceType.impactCausesMajorInjury),
                                        hitByFlyingObjectTypeIndex = objectInfo.objectTypeIndex,
                                    }
                                    serverSapien:fallAndGetInjured(targetSapien, flyDirection, options)
                                end
                            end
                        end
                            

                        local thrownObjectID = serverGOM:throwObjectWithVelocity(objectInfo, startPos, flyVelocity)
                        planManager:addStandardPlan(sharedState.tribeID, plan.types.storeObject.index, thrownObjectID, nil, nil, nil, nil, nil, nil)
                    end
                end
            end
        end
    end

end

function serverStorageArea:changeStorageAreaConfig(storageObject, userData, changerTribeID)
    --mj:log("serverStorageArea:changeStorageAreaConfig:", userData)

    

    local storageAreaInfo = storageAreas[storageObject.uniqueID]
    if storageAreaInfo then

        local sharedState = storageObject.sharedState
        local tribeRelationsSettings = serverWorld:getAllTribeRelationsSettings(changerTribeID)
        local tribeIDToUse = storageSettings:getSettingsTribeIDToUse(sharedState, changerTribeID, tribeRelationsSettings)
        if tribeIDToUse ~= userData.settingsTribeID then --error there is no settingsTribeID
            mj:error("Attempt to change settings for storage area belonging to another tribe when not allied. tribeIDToUse:", tribeIDToUse, " userData:", userData, " tribeRelationsSettings:", tribeRelationsSettings)
            return
        end

        local previousSettings = sharedState.settingsByTribe[tribeIDToUse] or {}

        local availibilityForUseChanged = false
        local deliveryRestrictionsChanged = false
        local removeAllItemsChanged = false
        local destroyAllItemsChanged = false

        local function changeAllowUse(newAllowUse)
            local defaultAllowUse = false
            if sharedState.tribeID == changerTribeID or (not serverWorld:tribeIsValidOwner(sharedState.tribeID)) then
                defaultAllowUse = true
            else
                if tribeRelationsSettings and tribeRelationsSettings[sharedState.tribeID] then
                    defaultAllowUse = tribeRelationsSettings[sharedState.tribeID].storageAlly
                end
            end

            --mj:log("changeAllowUse newAllowUse:", newAllowUse, " defaultAllowUse:", defaultAllowUse)

            if (defaultAllowUse == true) == (newAllowUse == true) then
                --mj:log("remove")
                sharedState:remove("settingsByTribe", tribeIDToUse, "disallowItemUse")
            else
                --mj:log("set")
                sharedState:set("settingsByTribe", tribeIDToUse, "disallowItemUse", (not newAllowUse))
            end
        end

        local function changeRestrictStorageTypeIndex(newIndex)
            local defaultIndex = -1
            if sharedState.tribeID == changerTribeID or (not serverWorld:tribeIsValidOwner(sharedState.tribeID)) then
                defaultIndex = nil
            else
                if tribeRelationsSettings and tribeRelationsSettings[sharedState.tribeID] and tribeRelationsSettings[sharedState.tribeID].storageAlly then
                    defaultIndex = nil
                end
            end

            if newIndex ~= defaultIndex then
                --mj:log("setting restrictStorageTypeIndex:", newIndex )
                sharedState:set("settingsByTribe", tribeIDToUse, "restrictStorageTypeIndex", newIndex)
            else
                --mj:log("removing restrictStorageTypeIndex" )
                sharedState:remove("settingsByTribe", tribeIDToUse, "restrictStorageTypeIndex")
            end
        end

        if userData.disallowItemUse ~= nil then
            --mj:log("userData.disallowItemUse ~= nil")
            if userData.disallowItemUse then
                if not previousSettings.disallowItemUse then
                    changeAllowUse(false)
                    availibilityForUseChanged = true
                end
            else
                --mj:log("userData.disallowItemUse:", userData.disallowItemUse, " previousSettings.disallowItemUse:", previousSettings.disallowItemUse)
                if previousSettings.disallowItemUse or previousSettings.disallowItemUse == nil then
                    changeAllowUse(true)
                    availibilityForUseChanged = true
                end
            end
        end
        
        if userData.removeAllItems ~= nil then
            if userData.removeAllItems then
                if not previousSettings.removeAllItems then
                    sharedState:set("settingsByTribe", tribeIDToUse, "removeAllItems", true)
                    deliveryRestrictionsChanged = true
                    availibilityForUseChanged = true
                    removeAllItemsChanged = true
                end
            else
                if previousSettings.removeAllItems then
                    sharedState:remove("settingsByTribe", tribeIDToUse, "removeAllItems")
                    deliveryRestrictionsChanged = true
                    availibilityForUseChanged = true
                    removeAllItemsChanged = true
                end
            end
        end
        
        if userData.destroyAllItems ~= nil then
            if userData.destroyAllItems then
                if not previousSettings.destroyAllItems then
                    sharedState:set("settingsByTribe", tribeIDToUse, "destroyAllItems", true)
                    destroyAllItemsChanged = true
                end
            else
                if previousSettings.destroyAllItems then
                    sharedState:remove("settingsByTribe", tribeIDToUse, "destroyAllItems")
                    destroyAllItemsChanged = true
                end
            end
        end

        if userData.restrictStorageTypeIndex ~= nil then
            local restrictStorageTypeIndex = previousSettings.restrictStorageTypeIndex
            if userData.restrictStorageTypeIndex ~= restrictStorageTypeIndex then
                changeRestrictStorageTypeIndex(userData.restrictStorageTypeIndex)
               --- if userData.restrictStorageTypeIndex then
                    --sharedState:set("settingsByTribe", tribeIDToUse, "restrictStorageTypeIndex", userData.restrictStorageTypeIndex)
              --  else
                    --sharedState:remove("settingsByTribe", tribeIDToUse, "restrictStorageTypeIndex")
              --  end
                deliveryRestrictionsChanged = true
            end
        end

        if userData.modifyRestrictObjectTypeIndexes ~= nil then
            local isRestricted = userData.restrictionValue
            local gameObjectTypeIndexes = userData.modifyRestrictObjectTypeIndexes
            
            if isRestricted then
                for i, gameObjectTypeIndex in ipairs(gameObjectTypeIndexes) do
                    if (not previousSettings.restrictedObjectTypeIndexes) or (not previousSettings.restrictedObjectTypeIndexes[gameObjectTypeIndex]) then
                        sharedState:set("settingsByTribe", tribeIDToUse, "restrictedObjectTypeIndexes", gameObjectTypeIndex, true)
                        deliveryRestrictionsChanged = true
                    end
                end
            else
                if sharedState.settingsByTribe[tribeIDToUse].restrictedObjectTypeIndexes then
                    for i, gameObjectTypeIndex in ipairs(gameObjectTypeIndexes) do
                        if previousSettings.restrictedObjectTypeIndexes and previousSettings.restrictedObjectTypeIndexes[gameObjectTypeIndex] then
                            sharedState:remove("settingsByTribe", tribeIDToUse, "restrictedObjectTypeIndexes", gameObjectTypeIndex)
                            deliveryRestrictionsChanged = true
                        end
                    end
                end
            end
        end

        if userData.maxQuantityFraction ~= nil then
            if userData.maxQuantityFraction ~= previousSettings.maxQuantityFraction then
                sharedState:set("settingsByTribe", tribeIDToUse, "maxQuantityFraction", userData.maxQuantityFraction)
                deliveryRestrictionsChanged = true
            end
        end

        if deliveryRestrictionsChanged or availibilityForUseChanged or removeAllItemsChanged or destroyAllItemsChanged then
            serverLogistics:updateMaintenceRequiredForConnectedObjects(storageObject.uniqueID)

            if deliveryRestrictionsChanged then
                getAvailabilityInfo(storageObject.uniqueID, storageAreaInfo, changerTribeID) --ensures availability info exists for this tribe, so that doChecksForAvailibilityChange can find it
                --mj:log("deliveryRestrictionsChanged objectID:", storageObject.uniqueID, " info:", info)
                doChecksForAvailibilityChange(storageObject, storageAreaInfo)
            end

            if availibilityForUseChanged then
                serverResourceManager:updateResourcesForObject(storageObject)
                serverResourceManager:storageAreaAllowItemUseChanged(storageObject)
                planManager:storageAreaAllowItemUseChanged(storageObject)
            end

            if destroyAllItemsChanged then
                serverStorageArea:updateMaintenanceRequired(storageObject)
            end
        end
        
    end
end

local function getRestrictedObjectTypesForSingleResourceOrObjectType(restrictStorageTypeIndex, allowOnlyResourceTypeIndex, allowOnlyObjectTypeIndex)
    local resultObjects = {}
    local checkedObjectTypesSet = {}

    local allowedObjectTypes = {}

    local addTypeWithAnyEvolutions = nil

    addTypeWithAnyEvolutions = function(toType)
        if not allowedObjectTypes[toType] then
            allowedObjectTypes[toType] = true
            local fromTypes = evolvingObject.fromTypesByToTypes[toType]
            if fromTypes then
                for fromType,v in pairs(fromTypes) do
                    addTypeWithAnyEvolutions(fromType)
                end
            end
        end
    end

    if allowOnlyResourceTypeIndex then
        local gameObjectsTypesForResource = gameObject.gameObjectTypeIndexesByResourceTypeIndex[allowOnlyResourceTypeIndex]
        for j,gameObjectTypeIndex in ipairs(gameObjectsTypesForResource) do
            addTypeWithAnyEvolutions(gameObjectTypeIndex)
        end
    else
        addTypeWithAnyEvolutions(allowOnlyObjectTypeIndex)
    end


    
    local allAllowedResourceTypes = storage.types[restrictStorageTypeIndex].resources
    for i,resourceTypeIndex in ipairs(allAllowedResourceTypes) do
        local gameObjectsTypesForResource = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
        for j,gameObjectTypeIndex in ipairs(gameObjectsTypesForResource) do
            if not checkedObjectTypesSet[gameObjectTypeIndex] then
                checkedObjectTypesSet[gameObjectTypeIndex] = true
                if not allowedObjectTypes[gameObjectTypeIndex] then
                    table.insert(resultObjects, gameObjectTypeIndex)
                end
            end
        end
    end

    if next(resultObjects) then
        return resultObjects
    end
    return nil
end

function serverStorageArea:restrictStorageAreaConfig(tribeID, storageObject, resourceTypeIndex, objectTypeIndex) --caled by AI tribe player on tradeable init. Provide either resourceTypeIndex or objectTypeIndex not both.
    local restrictStorageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex or gameObject.types[objectTypeIndex].resourceTypeIndex)
    --mj:log("restrictStorageAreaConfig resourceTypeIndex:", resourceTypeIndex, " objectTypeIndex:", objectTypeIndex, " restrictStorageTypeIndex:", restrictStorageTypeIndex)
    local modifyRestrictObjectTypeIndexes = getRestrictedObjectTypesForSingleResourceOrObjectType(restrictStorageTypeIndex, resourceTypeIndex, objectTypeIndex)

    serverStorageArea:changeStorageAreaConfig(storageObject, {
        storageAreaObjectID = storageObject.uniqueID,
        restrictStorageTypeIndex = restrictStorageTypeIndex,
        settingsTribeID = tribeID,

        modifyRestrictObjectTypeIndexes = modifyRestrictObjectTypeIndexes,
        restrictionValue = true,

    }, tribeID)

    serverStorageArea:doChecksForAvailibilityChange(storageObject)
end

function serverStorageArea:requiresMaintenanceDestroyItems(tribeID, storageObject, sapienIDOrNilForAny)
    return requiresItemDestruction(tribeID, storageObject)
end

function serverStorageArea:requiresMaintenanceTransfer(tribeID, storageObject, sapienIDOrNilForAny)
   -- mj:log("serverStorageArea:requiresPickup:", storageObject.uniqueID)
    
    if requiresRemovalDueToRemoveAllItemsOrder(tribeID, storageObject) then
        return true
    end

    return serverLogistics:objectRequiresPickup(tribeID, storageObject, nil, nil, sapienIDOrNilForAny)
end


function serverStorageArea:requiresMaintenanceHaul(tribeID, storageObject, sapienIDOrNilForAny)
     return serverLogistics:getDestinationIfObjectRequiresHaul(tribeID, storageObject) ~= nil
 end

function serverStorageArea:storageAreaTransferInfoIfRequiresPickup(tribeID, storageObject, sapienIDOrNil)
    
   -- mj:log("serverStorageArea:storageAreaTransferInfoIfRequiresPickup:", storageObject.uniqueID)

    local transferInfo = serverLogistics:transferInfoIfRequiresPickupOrHaul(tribeID, storageObject, sapienIDOrNil)
    if transferInfo then
        return transferInfo
    end

    local sharedState = storageObject.sharedState
    local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID) or {}
    if tribeSettings.removeAllItems or tribeSettings.removeAllDueToDeconstruct then
      --  mj:log("serverStorageArea:storageAreaTransferInfoIfRequiresPickup removeAllItems")
        local inventory = storageObject.sharedState.inventory
        if inventory and inventory.objects and #inventory.objects > 0 then
            local objectTypeIndex = inventory.objects[#inventory.objects].objectTypeIndex
            local matchInfo = serverStorageArea:bestStorageAreaForObjectType(sharedState.tribeID, objectTypeIndex, storageObject.pos, {
                excludeStorageAreaID = storageObject.uniqueID
            })
            if matchInfo and matchInfo.object.uniqueID ~= storageObject.uniqueID then
              --  mj:log("serverStorageArea:storageAreaTransferInfoIfRequiresPickup matchInfo")
                return {
                    sourceObjectID = storageObject.uniqueID,
                    destinationCapacity = matchInfo.maxItems,
                    destinationObjectID = matchInfo.object.uniqueID,
                    resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex,
                }
            end
          --  mj:log("serverStorageArea:storageAreaTransferInfoIfRequiresPickup nope")
            return {
                sourceObjectID = storageObject.uniqueID,
                resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex,
            }
        end
    end

    return nil
end

function serverStorageArea:quickFirstResourceTypeIndexToSeeIfCanCarryForRequiredPickup(storageObject)
    local inventory = storageObject and storageObject.sharedState.inventory
    if inventory and inventory.objects and #inventory.objects > 0 then
        local objectTypeIndex = inventory.objects[#inventory.objects].objectTypeIndex
        return gameObject.types[objectTypeIndex].resourceTypeIndex
    end
    return nil
end

function serverStorageArea:doChecksForAvailibilityChange(storageObject)
    local storageAreaInfo = storageObject and storageAreas[storageObject.uniqueID]
    if storageAreaInfo then
        doChecksForAvailibilityChange(storageObject, storageAreaInfo)
    end
end

function serverStorageArea:debugLog(storageObjectID)
    local storageAreaInfo = storageAreas[storageObjectID]
    if storageAreaInfo then
        mj:log("storageAreaInfo:", storageAreaInfo)
    end
end

function serverStorageArea:getStoredResourceTypeIndexesSet(storageObject)
    local inventory = storageObject and storageObject.sharedState.inventory
    if inventory and inventory.countsByObjectType then
        local resourceTypeIndexes = {}
        for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
            if count > 0 then
                resourceTypeIndexes[gameObject.types[objectTypeIndex].resourceTypeIndex] = true
            end
        end

        if next(resourceTypeIndexes) then
            return resourceTypeIndexes
        end
    end
    return nil
end

function serverStorageArea:init(serverGOM_, serverWorld_, planManager_, serverSapien_, serverTribe_, serverTribeAIPlayer_, serverDestination_)
    
    --mj:log("serverStorageArea:init")

    serverGOM = serverGOM_
    planManager = planManager_
    serverSapien = serverSapien_
    serverWorld = serverWorld_
    serverTribe = serverTribe_
    serverTribeAIPlayer = serverTribeAIPlayer_
    serverDestination = serverDestination_

    maintenance:setServerStorageArea(serverStorageArea)

    local function storageAreaLoaded(object)
        local tribeID = object.sharedState.tribeID

        if not storageAreasByTribeID[tribeID] then
            storageAreasByTribeID[tribeID] = {}
        end

        local storageAreaInfo = {
            tribeID = tribeID,
            assignedCallbackObjectIDs = {},
        }

        storageAreas[object.uniqueID] = storageAreaInfo
        storageAreasByTribeID[tribeID][object.uniqueID] = storageAreaInfo


        serverGOM:addObjectToSet(object, serverGOM.objectSets.coveredStatusObservers)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.logistics)

        if not object.sharedState.settingsByTribe then --new or < 0.5
            object.sharedState:set("requiresMaintenanceByTribe", {})
            object.sharedState:set("settingsByTribe", {})

            if object.sharedState.requiresMaintenance then --migrate to 0.5
                object.sharedState:set("requiresMaintenanceByTribe", tribeID, true)
                object.sharedState:remove("requiresMaintenance")
            end

            if object.sharedState.removeAllItems then --migrate to 0.5
                object.sharedState:set("settingsByTribe", tribeID, "removeAllItems", true)
                object.sharedState:remove("removeAllItems")
            end

            if object.sharedState.disallowItemUse then --migrate to 0.5
                object.sharedState:set("settingsByTribe", tribeID, "disallowItemUse", true)
                object.sharedState:remove("disallowItemUse")
            end

            if object.sharedState.restrictStorageTypeIndex then --migrate to 0.5
                object.sharedState:set("settingsByTribe", tribeID, "restrictStorageTypeIndex", object.sharedState.restrictStorageTypeIndex)
                object.sharedState:remove("restrictStorageTypeIndex")
            end

            if object.sharedState.restrictedObjectTypeIndexes then --migrate to 0.5
                object.sharedState:set("settingsByTribe", tribeID, "restrictedObjectTypeIndexes", object.sharedState.restrictedObjectTypeIndexes)
                object.sharedState:remove("restrictedObjectTypeIndexes")
            end

            if object.sharedState.maxQuantityFraction then --migrate to 0.5
                object.sharedState:set("settingsByTribe", tribeID, "maxQuantityFraction", object.sharedState.maxQuantityFraction)
                object.sharedState:remove("maxQuantityFraction")
            end
            
            if object.sharedState.removeAllDueToDeconstruct then --migrate to 0.5
                object.sharedState:set("settingsByTribe", tribeID, "removeAllDueToDeconstruct", object.sharedState.removeAllDueToDeconstruct)
                object.sharedState:remove("removeAllDueToDeconstruct")
            end
        end


        --storageAreaInfo.availabilityInfo = generateAvailabilityInfo(object)
        
        anchor:addAnchor(object.uniqueID, anchor.types.storageArea.index, object.sharedState.tribeID)


        local inventory = object.sharedState.inventory

        --[[if inventory and inventory.objects and inventory.objects[1] then --todo remove this, just for 0.5.0.0 worlds that got corrupted
            local countsByObjectType = {}
            for i,objectInfo in ipairs(inventory.objects) do
                countsByObjectType[objectInfo.objectTypeIndex] = (countsByObjectType[objectInfo.objectTypeIndex] or 0) + 1
            end
            object.sharedState:set("inventory", "countsByObjectType", countsByObjectType)
        end]]

        serverEvolvingObject:addCallbackForStorageAreaIfNeeded(object.uniqueID)
        --callCallbacksForAnyAvailabilityChange(object, storageAreaInfo, storageAreaInfo.availabilityInfo, { available = false }, nil)

        --local newAvailabilityInfo = getAvailabilityInfo(object.uniqueID, storageAreaInfo, tribeID) --calls generateAvailabilityInfo and assigns
        --callCallbacksForAnyAvailabilityChange(object, storageAreaInfo, newAvailabilityInfo, { available = false }, tribeID)

        
        if object.sharedState.requiresMaintenanceByTribe and next(object.sharedState.requiresMaintenanceByTribe) then
            serverGOM:addObjectToSet(object, serverGOM.objectSets.maintenance)
        end


        if inventory and inventory.countsByObjectType then
            if not object.sharedState.covered then
                local storageTypeIndex = object.sharedState.contentsStorageTypeIndex
                if storageTypeIndex then
                    local storageType = storage.types[storageTypeIndex]
                    if storageType.windDestructableChanceIndex then
                        local set = serverWeather.windDamageLevelSets[storageType.windDestructableChanceIndex]
                        if set then
                            serverGOM:addObjectToSet(object, set)
                        end
                    end
                end
            end
            local countsByObjectType = inventory.countsByObjectType
            for containedObjectTypeIndex,count in pairs(countsByObjectType) do
                if count > 0 then
                    
                    local resourceCounts = serverStorageArea.resourceCountsByTribeID[tribeID]
                    if not resourceCounts then
                        resourceCounts = {}
                        serverStorageArea.resourceCountsByTribeID[tribeID] = resourceCounts
                    end

                    local resourceTypeIndex = gameObject.types[containedObjectTypeIndex].resourceTypeIndex
                    local oldCount = resourceCounts[resourceTypeIndex] or 0
                    local newCount = oldCount + count
                    resourceCounts[resourceTypeIndex] = newCount

                    local statsKey = "r_" .. resource.types[resourceTypeIndex].key
                    serverStatistics:setValueForToday(tribeID, statistics.types[statsKey].index, newCount)
                    serverTutorialState:checkForTutorialNotificationDueToAddition(tribeID, resourceTypeIndex, newCount)
                    
                    if resource.types[resourceTypeIndex].foodValue then
                        local foodCount = serverStorageArea.foodCountsByTribeID[tribeID]
                        if not foodCount then
                            foodCount = 0
                        end
                        local newFoodCount = foodCount + count
                        serverStorageArea.foodCountsByTribeID[tribeID] = newFoodCount
                        serverStatistics:setValueForToday(tribeID, statistics.types.foodCount.index, newFoodCount)
                        serverTutorialState:checkForTutorialNotificationDueToFoodAddition(tribeID, newFoodCount)
                    end
                end
            end
        end
        return false
    end

    local function storageAreaUnloaded(object)
        --mj:log("unloaded storage area")
        local storageAreaInfo = storageAreas[object.uniqueID]
        if storageAreaInfo then
            --mj:log("callCallbacksForAnyAvailabilityChange")

            --mj:log("unloaded. storageAreaInfo.availabilityInfosByTribeID:", storageAreaInfo.availabilityInfosByTribeID)

            if storageAreaInfo.availabilityInfosByTribeID then
                for tribeID,availabilityInfo in pairs(storageAreaInfo.availabilityInfosByTribeID) do
                    local newAvailibilityInfo = { available = false }
                    storageAreaInfo.availabilityInfosByTribeID[tribeID] = newAvailibilityInfo
                    --mj:log("calling callbacks tribeID:", tribeID)
                    callCallbacksForAnyAvailabilityChange(object, storageAreaInfo, newAvailibilityInfo, availabilityInfo, tribeID)
                end
            end

            storageAreas[object.uniqueID] = nil
            storageAreasByTribeID[object.sharedState.tribeID][object.uniqueID] = nil
        end
        anchor:anchorObjectUnloaded(object.uniqueID)
    end

    
    local function storageAreaCoveredStatusChanged(object)
        --mj:log("covered status changed callback being called for storage area object:", object.uniqueID)
        serverEvolvingObject:coveredStatusChangedForStorageArea(object.uniqueID)
        updateBlowAwaySetsDueToCoveredStatusChange(object.uniqueID)
    end

   -- mj:log("gameObject.storageAreaTypes:", gameObject.storageAreaTypes)
    
    for i,gameObjectTypeIndex in ipairs(gameObject.storageAreaTypes) do
        serverGOM:addObjectLoadedFunctionForType(gameObjectTypeIndex, storageAreaLoaded)
        serverGOM:addObjectUnloadedFunctionForType(gameObjectTypeIndex, storageAreaUnloaded)
        serverGOM:addObjectCoveredStatusChangedFunctionForType(gameObjectTypeIndex, storageAreaCoveredStatusChanged)
    end

end

function serverStorageArea:finalizeObjectCreation(object)
    local storageAreaInfo = storageAreas[object.uniqueID]
    for tribeID,v in pairs(serverWorld.validOwnerTribeIDs) do
        local newAvailabilityInfo = getAvailabilityInfo(object.uniqueID, storageAreaInfo, tribeID)
        callCallbacksForAnyAvailabilityChange(object, storageAreaInfo, newAvailabilityInfo, { available = false }, tribeID)
    end
end


return serverStorageArea