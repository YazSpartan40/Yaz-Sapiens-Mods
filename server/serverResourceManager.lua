
local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local resource = mjrequire "common/resource"
local gameObject = mjrequire "common/gameObject"
local sapienInventory = mjrequire "common/sapienInventory"
local objectInventory = mjrequire "common/objectInventory"
local plan = mjrequire "common/plan"

local serverGOM = nil
local serverSapien = nil
local serverStorageArea = nil
--local serverSapienAI = nil

local serverResourceManager = {}

--local resourcesByObjectTypeThenObjectID = {}
--local objectTypesByObjectID = {}

local trackingTribes = {}

--local resourcesByTribeThenCenterThenObjectTypeThenObjectID = {}
local removeInfosByObjectID = {}

local allResourceObjects = {}

local defaultLooseResourceMaxDistanceMeters = 75.0
local looseResourceMaxDistance = mj:mToP(defaultLooseResourceMaxDistanceMeters)
local defaultLooseResourceMaxDistance2 = looseResourceMaxDistance * looseResourceMaxDistance

local defaultStorageResourceMaxDistanceMeters = 400.0
local storageResourceMaxDistance = mj:mToP(defaultStorageResourceMaxDistanceMeters)
local defaultStorageResourceMaxDistance2 = storageResourceMaxDistance * storageResourceMaxDistance

serverResourceManager.looseResourceMaxDistance = looseResourceMaxDistance
serverResourceManager.looseResourceMaxDistance2 = defaultLooseResourceMaxDistance2

serverResourceManager.storageResourceMaxDistance = storageResourceMaxDistance
serverResourceManager.storageResourceMaxDistance2 = defaultStorageResourceMaxDistance2

local increasedCallbackDistanceToAllowForMerge = mj:mToP(defaultStorageResourceMaxDistanceMeters + 100.0)
local increasedCallbackDistanceToAllowForMerge2 = increasedCallbackDistanceToAllowForMerge * increasedCallbackDistanceToAllowForMerge

local maxDistanceFromTribeCentersToAdd = mj:mToP(1000.0)
local maxDistanceFromTribeCentersToAdd2 = maxDistanceFromTribeCentersToAdd * maxDistanceFromTribeCentersToAdd

local availablityChangeCallbackObjectIDsByResourceTypeIndex = {}
local availablityChangeCallbackInfosByObjectID = {}

local storageAreaAvailablityChangeCallbackInfosByObjectID = {}

serverResourceManager.providerTypes = mj:enum {
    "standard",
    "gatherRequired", --gatherRequired is not used, trees etc don't add themselves anymore. Left here in case that should be a thing again in the future, it could be fixed up to work again easily
    "storageArea",
    "heldBySapien",
    "craftArea",
    "looseWithStorePlan",
}

local updateClientSeenListFunction = nil

function serverResourceManager:setUpdateClientSeenListFunction(func)
    updateClientSeenListFunction = func
end

function serverResourceManager:setCallbackForResourceAvailabilityChange(objectID, resourceTypeIndexes, pos, func)
    if availablityChangeCallbackInfosByObjectID[objectID] then
        local oldResourceTypeIndexes = availablityChangeCallbackInfosByObjectID[objectID].resourceTypeIndexes
        for i,resourceTypeIndex in ipairs(oldResourceTypeIndexes) do
            availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex][objectID] = nil
        end
    end

    availablityChangeCallbackInfosByObjectID[objectID] = {
        pos = pos,
        func = func,
        resourceTypeIndexes = resourceTypeIndexes,
    }
    
    for i,resourceTypeIndex in ipairs(resourceTypeIndexes) do
        if not availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex] then
            availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex] = {}
        end
        availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex][objectID] = true
    end
end


function serverResourceManager:removeCallbackForResourceAvailabilityChange(objectID)
    if availablityChangeCallbackInfosByObjectID[objectID] then
        local oldResourceTypeIndexes = availablityChangeCallbackInfosByObjectID[objectID].resourceTypeIndexes
        for i,resourceTypeIndex in ipairs(oldResourceTypeIndexes) do
            availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex][objectID] = nil
        end
        availablityChangeCallbackInfosByObjectID[objectID] = nil
    end
end

function serverResourceManager:setCallbackForStorageAreaResourceAvailabilityChange(objectID, func)
    storageAreaAvailablityChangeCallbackInfosByObjectID[objectID] = {
        func = func,
    }
end

function serverResourceManager:removeCallbackForStorageAreaResourceAvailabilityChange(objectID)
    storageAreaAvailablityChangeCallbackInfosByObjectID[objectID] = nil
end

local queuedResourceAvailabilityChanges = {}
local minAddDistance2 = mj:mToP(100.0) * mj:mToP(100.0)

local function callCallbacksForResourceAvailabilityChangeNow(resourceTypeIndex, resourcePos)
    local callbackObjectIDs = availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex]
    --local debugCount = 0
    if callbackObjectIDs then
        for objectID,trueFalse in pairs(callbackObjectIDs) do
            local callbackInfo = availablityChangeCallbackInfosByObjectID[objectID]
            --debugCount = debugCount + 1
            if length2(callbackInfo.pos - resourcePos) < increasedCallbackDistanceToAllowForMerge2 then
                callbackInfo.func(objectID)
               -- mj:log("calling callback for:", objectID)
            end
        end
    end
  --if debugCount > 0 then
        --mj:log("callCallbacksForResourceAvailabilityChange type:", resourceTypeIndex, " count:", debugCount)
  --  end
end

local function queueResourceAvailabilityChange(resourceTypeIndex, resourcePos)
    local positions = queuedResourceAvailabilityChanges[resourceTypeIndex]
    if not positions then
        positions = {}
        queuedResourceAvailabilityChanges[resourceTypeIndex] = positions
    end

    for i,exisitingPos in ipairs(positions) do
        if length2(exisitingPos - resourcePos) < minAddDistance2 then
            --mj:log("existing found in queueResourceAvailabilityChange:", resourceTypeIndex)
            return
        end
    end

    table.insert(positions, resourcePos)
end

local function callQueuedResourceCallbacks()
    --mj:log("callQueuedResourceCallbacks")
    for resourceTypeIndex, positionsArray in pairs(queuedResourceAvailabilityChanges) do
        for i,resourcePos in ipairs(positionsArray) do
            callCallbacksForResourceAvailabilityChangeNow(resourceTypeIndex, resourcePos)
        end
    end
    queuedResourceAvailabilityChanges = {}
end


function serverResourceManager:update()
    callQueuedResourceCallbacks()
end

local function callCallbackForObjectTypeAdded(tribeID, objectTypeIndex)
    updateClientSeenListFunction(tribeID, objectTypeIndex)
end

local function callCallbacksForStorageAreaResourceAvailibilityChanged(objectID)
    local callbackInfo = storageAreaAvailablityChangeCallbackInfosByObjectID[objectID]
    if callbackInfo then
        callbackInfo.func(objectID)
    end
end

function serverResourceManager:callCallbacksForChangedResourceTypeIndexes(resourceTypeIndexes)
    for resourceTypeIndex,v in pairs(resourceTypeIndexes) do
        local callbackObjectIDs = availablityChangeCallbackObjectIDsByResourceTypeIndex[resourceTypeIndex]
        if callbackObjectIDs then
            for objectID,trueFalse in pairs(callbackObjectIDs) do
                local callbackInfo = availablityChangeCallbackInfosByObjectID[objectID]
                callbackInfo.func(objectID)
            end
        end
    end
end

function serverResourceManager:storageAreaAllowItemUseChanged(storageAreaObject)
    local resourceTypeIndexes = serverStorageArea:getStoredResourceTypeIndexesSet(storageAreaObject)
    if resourceTypeIndexes then
        serverResourceManager:callCallbacksForChangedResourceTypeIndexes(resourceTypeIndexes)
    end
end

local function matchesAllowPlanQueuedObjects(objectID, tribeID)
    local resourceObject = serverGOM:getObjectWithID(objectID)
    if resourceObject and resourceObject.sharedState then
        local planStatesByTribeID = resourceObject.sharedState.planStates
        if planStatesByTribeID then
            if planStatesByTribeID[tribeID] then
                for j,thisPlanState in ipairs(planStatesByTribeID[tribeID]) do
                    if plan.types[thisPlanState.planTypeIndex].preventsResourceUseInOtherPlans then
                        return false
                    end
                end
            end
        end
    end
    return true
end

local function hasTribePermissions(resourceState, objectID, tribeID, objectTypeIndex)
    if resourceState.providerType == serverResourceManager.providerTypes.storageArea then
        if not serverStorageArea:storageAreaHasObjectAvailable(objectID, objectTypeIndex, tribeID) then
            return false
        end
    end
    return true
end

function serverResourceManager:addAnyResourceForObject(object, suppressChangeCallbacks, restrictTribeIDOrNil)
    --mj:log("serverResourceManager:addAnyResourceForObject:", object.uniqueID, " type:", object.objectTypeIndex, " restrictTribeIDOrNil:", restrictTribeIDOrNil, " suppressChangeCallbacks:", suppressChangeCallbacks)
    if serverGOM:objectIsInaccessible(object) then
        return
    end

    local sharedState = serverGOM:getSharedState(object, true)

    local callbackResourceTypes = {}
    
    local maxDistance2 = serverResourceManager.looseResourceMaxDistance2
    if gameObject.types[object.objectTypeIndex].isStorageArea or gameObject.types[object.objectTypeIndex].isCraftArea or object.objectTypeIndex == gameObject.types.sapien.index then
        maxDistance2 = serverResourceManager.storageResourceMaxDistance2
    end

    local resourceAdded = false

    local function addResource(objectTypeIndex, providerType, countToAdd, hasPlanQueued)
        if objectTypeIndex and gameObject.types[objectTypeIndex].resourceTypeIndex and countToAdd > 0 then
            resourceAdded = true
            local resourceState = {
                object = object,
                count = countToAdd,
                providerType = providerType,
                maxDistance2 = maxDistance2,
            }

            -- note the storage heirachy:
            -- trackingTribes[tribeID].centers[i].resourcesByObjectTypeThenObjectID[objectTypeIndex][object.uniqueID] = resourceState
            -- remove info:
            -- removeInfosByObjectID[object.uniqueID][tribeID][objectTypeIndex]

            local function doTribe(tribeID, trackingInfo)
                --mj:log("doTribe:", tribeID)
                local hasFoundValidTribePermissions = false 
                for i,centerInfo in ipairs(trackingInfo.centers) do
                    if length2(centerInfo.pos - object.pos) < maxDistanceFromTribeCentersToAdd2 then
                        if not hasFoundValidTribePermissions then
                            hasFoundValidTribePermissions = hasTribePermissions(resourceState, object.uniqueID, tribeID, objectTypeIndex)
                        end
                        if not hasFoundValidTribePermissions then
                            --mj:log("not hasFoundValidTribePermissions:", resourceState)
                            break
                        end

                        local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                        local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                        if not resourcesByObjectID then
                            resourcesByObjectID = {}
                            resourcesByObjectTypeThenObjectID[objectTypeIndex] = resourcesByObjectID
                        end
                        resourcesByObjectID[object.uniqueID] = resourceState

                        local removeInfo = removeInfosByObjectID[object.uniqueID]
                        if not removeInfo then
                            removeInfo = {}
                            removeInfosByObjectID[object.uniqueID] = removeInfo
                        end

                        local removeObjectTypeIndexes = removeInfo[tribeID]
                        if not removeObjectTypeIndexes then
                            removeObjectTypeIndexes = {}
                            removeInfo[tribeID] = removeObjectTypeIndexes
                        end

                        removeObjectTypeIndexes[objectTypeIndex] = true
                        --mj:log("suppressChangeCallbacks:", suppressChangeCallbacks)
                        if not suppressChangeCallbacks then
                            callCallbackForObjectTypeAdded(tribeID, objectTypeIndex)
                        end
                    end
                end
            end

            if restrictTribeIDOrNil then
                doTribe(restrictTribeIDOrNil, trackingTribes[restrictTribeIDOrNil])
            else
                for tribeID, trackingInfo in pairs(trackingTribes) do
                    doTribe(tribeID, trackingInfo)
                end
            end

            local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
            callbackResourceTypes[resourceTypeIndex] = true
            
        end
    end
    
    --if gameObject.types[object.objectTypeIndex].gatherableTypes then
        --[[local revertToSeedlingGatherResourceCounts = gameObject.types[object.objectTypeIndex].revertToSeedlingGatherResourceCounts
        if revertToSeedlingGatherResourceCounts then
            for i,objectTypeIndex in ipairs(gameObject.types[object.objectTypeIndex].gatherableTypes) do
                addResource(objectTypeIndex, serverResourceManager.providerTypes.gatherRequired, revertToSeedlingGatherResourceCounts[objectTypeIndex])
            end
        else
            if sharedState.inventory then
                local countsByObjectType = sharedState.inventory.countsByObjectType
                for i,objectTypeIndex in ipairs(gameObject.types[object.objectTypeIndex].gatherableTypes) do
                    if countsByObjectType[objectTypeIndex] and countsByObjectType[objectTypeIndex] > 0 then
                        addResource(objectTypeIndex, serverResourceManager.providerTypes.gatherRequired, countsByObjectType[objectTypeIndex])
                    end
                end
            end
        end]]
        


    if gameObject.types[object.objectTypeIndex].isStorageArea then
        if sharedState.inventory and sharedState.inventory.countsByObjectType then
            local countsByObjectType = sharedState.inventory.countsByObjectType
            for objectTypeIndex, count in pairs(countsByObjectType) do
                addResource(objectTypeIndex, serverResourceManager.providerTypes.storageArea, count)
            end
        end
    elseif gameObject.types[object.objectTypeIndex].isCraftArea then --or gameObject.types[object.objectTypeIndex].isInProgressBuildObject then --maybe add this later
        local foundPlan = false

        local planStatesByTribeID = sharedState.planStates
        if planStatesByTribeID then
            for tribeID,planStates in pairs(planStatesByTribeID) do
                if planStates[1] then
                    foundPlan = true
                    break
                end
            end
        end

        if not foundPlan then
            local inventories = sharedState.inventories
            if inventories then
                local availableResourcesInventory = inventories[objectInventory.locations.availableResource.index]
                if availableResourcesInventory and availableResourcesInventory.countsByObjectType then
                    local countsByObjectType = availableResourcesInventory.countsByObjectType
                    for objectTypeIndex, count in pairs(countsByObjectType) do
                        addResource(objectTypeIndex, serverResourceManager.providerTypes.craftArea, count)
                    end
                end
                local toolsInventory = inventories[objectInventory.locations.tool.index]
                if toolsInventory and toolsInventory.countsByObjectType then
                    local countsByObjectType = toolsInventory.countsByObjectType
                    for objectTypeIndex, count in pairs(countsByObjectType) do
                        addResource(objectTypeIndex, serverResourceManager.providerTypes.craftArea, count)
                    end
                end
            end
        end
    elseif object.objectTypeIndex == gameObject.types.sapien.index then
        local inventories = sharedState.inventories
        if inventories then
            local inventory = inventories[sapienInventory.locations.held.index]
            if inventory and inventory.countsByObjectType then
                local countsByObjectType = inventory.countsByObjectType
                for objectTypeIndex, count in pairs(countsByObjectType) do
                    addResource(objectTypeIndex, serverResourceManager.providerTypes.heldBySapien, count)
                end
            end
        end
    else
        local foundPlan = false

        local planStatesByTribeID = sharedState.planStates
        if planStatesByTribeID then
            for tribeID,planStates in pairs(planStatesByTribeID) do
                if planStates[1] and planStates[1].planTypeIndex == plan.types.storeObject.index then
                    foundPlan = true
                    break
                end
            end
        end
        if foundPlan then
            addResource(object.objectTypeIndex, serverResourceManager.providerTypes.looseWithStorePlan, 1)
        else
            addResource(object.objectTypeIndex, serverResourceManager.providerTypes.standard, 1)
        end
    end

    if resourceAdded then
        allResourceObjects[object.uniqueID] = object
    end
    
    if not suppressChangeCallbacks then
        for resourceTypeIndex,truFalse in pairs(callbackResourceTypes) do
            queueResourceAvailabilityChange(resourceTypeIndex, object.pos)
        end
        
        if gameObject.types[object.objectTypeIndex].isStorageArea then
            callCallbacksForStorageAreaResourceAvailibilityChanged(object.uniqueID)
        end
    end
end

--trackingTribes[tribeID].centers[i].resourcesByObjectTypeThenObjectID[objectTypeIndex][object.uniqueID] = resourceState
-- removeInfosByObjectID[object.uniqueID][tribeID][objectTypeIndex] = true

function serverResourceManager:removeAnyResourceForObject(object, suppressChangeCallbacks, restrictTribeIDOrNil)
    if not allResourceObjects[object.uniqueID] then
        return
    end
    --mj:log("serverResourceManager:removeAnyResourceForObject:", object.uniqueID, " type:", object.objectTypeIndex, " restrictTribeIDOrNil:", restrictTribeIDOrNil, " suppressChangeCallbacks:", suppressChangeCallbacks)

    local callbackResourceMaxDistancesByTypes = {}
    local removeInfo = removeInfosByObjectID[object.uniqueID]
    if removeInfo then

        local function doTribe(tribeID, removeObjectTypeIndexes)
            if removeObjectTypeIndexes then
                local trackingInfo = trackingTribes[tribeID]
                if trackingInfo then
                    for i,centerInfo in ipairs(trackingInfo.centers) do
                        local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                        for objectTypeIndex,v in pairs(removeObjectTypeIndexes) do
                            local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                            if resourcesByObjectID then
                                local resourceState = resourcesByObjectID[object.uniqueID]
                                if resourceState then
                                    callbackResourceMaxDistancesByTypes[objectTypeIndex] = resourceState.maxDistance2
                                    resourcesByObjectTypeThenObjectID[objectTypeIndex][object.uniqueID] = nil
                                end
                            end
                        end
                    end
                end
            end
        end
        

        if restrictTribeIDOrNil then
            doTribe(restrictTribeIDOrNil, removeInfo[restrictTribeIDOrNil])
        else
            for tribeID,removeObjectTypeIndexes in pairs(removeInfo) do
                doTribe(tribeID, removeObjectTypeIndexes)
            end
        end
        
        if not suppressChangeCallbacks then
            for objectTypeIndex,maxDistance2 in pairs(callbackResourceMaxDistancesByTypes) do
                local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                queueResourceAvailabilityChange(resourceTypeIndex, object.pos)
            end

            if gameObject.types[object.objectTypeIndex].isStorageArea then
                callCallbacksForStorageAreaResourceAvailibilityChanged(object.uniqueID)
            end
        end
    end
    
    if not restrictTribeIDOrNil then
        allResourceObjects[object.uniqueID] = nil
        removeInfosByObjectID[object.uniqueID] = nil
    end
end

function serverResourceManager:updateResourcesForObject(object, restrictTribeIDOrNil)
    --mj:objectLogTraceback(object.uniqueID, "serverResourceManager:updateResourcesForObject tribe:", restrictTribeIDOrNil)
   -- mj:log("serverResourceManager:updateResourcesForObject:", object.uniqueID)

    local oldStates = {}
    local removeInfo = removeInfosByObjectID[object.uniqueID]
    if removeInfo then
        local function doTribe(tribeID,removeObjectTypeIndexes)
            local trackingInfo = trackingTribes[tribeID]
            if trackingInfo then
                for i,centerInfo in ipairs(trackingInfo.centers) do
                    local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                    for objectTypeIndex,v in pairs(removeObjectTypeIndexes) do
                        local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                        if resourcesByObjectID then
                            local resourceState = resourcesByObjectID[object.uniqueID]
                            if resourceState then
                                table.insert(oldStates, {
                                    tribeID = tribeID,
                                    centerIndex = i,
                                    objectTypeIndex = objectTypeIndex,
                                    resourceState = resourceState,
                                })
                            end
                        end
                    end
                end
            end
        end
        if restrictTribeIDOrNil then
            doTribe(restrictTribeIDOrNil,removeInfo[restrictTribeIDOrNil])
        else
            for tribeID,removeObjectTypeIndexes in pairs(removeInfo) do
                doTribe(tribeID,removeObjectTypeIndexes)
            end
        end
    end

    serverResourceManager:removeAnyResourceForObject(object, true, restrictTribeIDOrNil)
    serverResourceManager:addAnyResourceForObject(object, true, restrictTribeIDOrNil)

    local addedOrChangedDistancesByResourceType = {}

    removeInfo = removeInfosByObjectID[object.uniqueID]
    if removeInfo then

        local function doTribe(tribeID,removeObjectTypeIndexes)
            local trackingInfo = trackingTribes[tribeID]
            if trackingInfo then
                for i,centerInfo in ipairs(trackingInfo.centers) do
                    local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                    for objectTypeIndex,v in pairs(removeObjectTypeIndexes) do
                        local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                        if resourcesByObjectID then
                            local resourceState = resourcesByObjectID[object.uniqueID]
                            if resourceState then
                                local foundInOldState = false
                                for j,oldStateInfo in ipairs(oldStates) do
                                    if oldStateInfo.tribeID == tribeID and
                                    oldStateInfo.centerIndex == i and
                                    oldStateInfo.objectTypeIndex == objectTypeIndex and
                                    oldStateInfo.resourceState.count == resourceState.count then
                                        foundInOldState = true

                                        --mj:log("serverResourceManager:updateResourcesForObject foundInOldState:", objectTypeIndex)
                                        ----disabled--mj:objectLog(object.uniqueID, "serverResourceManager:updateResourcesForObject foundInOldState:", objectTypeIndex, " tribeID:", tribeID)
                                        table.remove(oldStates, j)
                                        break
                                    end
                                end
                                if not foundInOldState then
                                    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                                    addedOrChangedDistancesByResourceType[resourceTypeIndex] = resourceState.maxDistance2
                                    ----disabled--mj:objectLog(object.uniqueID, "serverResourceManager:updateResourcesForObject not foundInOldState, calling callback for addition:", objectTypeIndex, " tribeID:", tribeID)
                                    callCallbackForObjectTypeAdded(tribeID, objectTypeIndex)
                                end
                            end
                        end
                    end
                end
            end
        end

        if restrictTribeIDOrNil then
            doTribe(restrictTribeIDOrNil,removeInfo[restrictTribeIDOrNil])
        else
            for tribeID,removeObjectTypeIndexes in pairs(removeInfo) do
                doTribe(tribeID,removeObjectTypeIndexes)
            end
        end
    end

    local removedDistancesByResourceType = nil

    for j,oldStateInfo in ipairs(oldStates) do
        local resourceTypeIndex = gameObject.types[oldStateInfo.objectTypeIndex].resourceTypeIndex
        addedOrChangedDistancesByResourceType[resourceTypeIndex] = oldStateInfo.resourceState.maxDistance2
    end

    if removedDistancesByResourceType then
        for objectTypeIndex,maxDistance2 in pairs(removedDistancesByResourceType) do
            local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
            --mj:log("serverResourceManager:updateResourcesForObject queue resource availability change for removed type:", resourceTypeIndex)
            queueResourceAvailabilityChange(resourceTypeIndex, object.pos)
        end
    end
    
    if addedOrChangedDistancesByResourceType then
        for resourceTypeIndex,maxDistance2 in pairs(addedOrChangedDistancesByResourceType) do
            --mj:log("serverResourceManager:updateResourcesForObject queue resource availability change for added or changed type:", resourceTypeIndex)
            queueResourceAvailabilityChange(resourceTypeIndex, object.pos)
        end
    end
        
    if removedDistancesByResourceType or addedOrChangedDistancesByResourceType then
        if gameObject.types[object.objectTypeIndex].isStorageArea then
            callCallbacksForStorageAreaResourceAvailibilityChanged(object.uniqueID)
        end
    end

    --[[local oldResourceCountsAndDistances = {}

    local objectTypes = objectTypesByObjectID[object.uniqueID]
    if objectTypes then
        for objectTypeIndex,trueFalse in pairs(objectTypes) do
            if trueFalse then
                local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                if resourcesByObjectID and resourcesByObjectID[object.uniqueID] then
                    oldResourceCountsAndDistances[objectTypeIndex] = {
                        count = resourcesByObjectID[object.uniqueID].count,
                        maxDistance2 = resourcesByObjectID[object.uniqueID].maxDistance2
                    }
                end
            end
        end
    end

    serverResourceManager:removeAnyResourceForObject(object, true)
    serverResourceManager:addAnyResourceForObject(object, true)

    local removedDistancesByType = nil
    local addedOrChgangedDistancesByType = nil
    

    local newObjectTypes = objectTypesByObjectID[object.uniqueID]

    for objectTypeIndex,oldCountAndDistance in pairs(oldResourceCountsAndDistances) do
        if not newObjectTypes or not newObjectTypes[objectTypeIndex] then
            if not removedDistancesByType then
                removedDistancesByType = {}
            end
            removedDistancesByType[objectTypeIndex] = oldCountAndDistance.maxDistance2
            break
        end
    end

    if newObjectTypes then
        for objectTypeIndex,trueFalse in pairs(newObjectTypes) do
            if trueFalse then
                local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                if resourcesByObjectID and resourcesByObjectID[object.uniqueID] then
                    if (not oldResourceCountsAndDistances[objectTypeIndex]) or resourcesByObjectID[object.uniqueID].count ~= oldResourceCountsAndDistances[objectTypeIndex].count or (not approxEqual(resourcesByObjectID[object.uniqueID].maxDistance2, oldResourceCountsAndDistances[objectTypeIndex].maxDistance2)) then
                        if not addedOrChangedDistancesByType then
                            addedOrChangedDistancesByType = {}
                        end
                        local maxDistance2 = resourcesByObjectID[object.uniqueID].maxDistance2
                        if oldResourceCountsAndDistances[objectTypeIndex] then
                            maxDistance2 = math.max(maxDistance2, oldResourceCountsAndDistances[objectTypeIndex].maxDistance2)
                        end
                        addedOrChangedDistancesByType[objectTypeIndex] = maxDistance2
                    end
                end
            end
        end
    end]]

end

local extraDistanceHackToDiscourageGather = mj:mToP(10.0) * mj:mToP(10.0)


--trackingTribes[tribeID].centers[i].resourcesByObjectTypeThenObjectID[objectTypeIndex][object.uniqueID] = resourceState

-- options: allowStockpiles, allowGather, allowHeld, maxCount, maxDistance2, onlyStockpiles, ignoreObjectIDs (set)
function serverResourceManager:distanceOrderedObjectsForResourceinTypesArray(objectTypesArray, pos, options, tribeIDOrNilForAny)
    --mj:log("serverResourceManager:distanceOrderedObjectsForResourceinTypesArray:", objectTypesArray)
    

    local result = {}
    local function doTribe(tribeID, trackingInfo)
        local dupeCheck = {}
        for i,objectTypeIndex in ipairs(objectTypesArray) do
            if not dupeCheck[objectTypeIndex] then
                dupeCheck[objectTypeIndex] = true

                local matchesObjectTypeConstraints = true
                if options.foodValueAffectsHeuristic then
                    local foodValue = resource.types[gameObject.types[objectTypeIndex].resourceTypeIndex].foodValue
                    if (not foodValue) or foodValue < 0.15 then --little hack, exclude seeds for food raiders
                        matchesObjectTypeConstraints = false
                    end
                end

                if matchesObjectTypeConstraints then
                    for j,centerInfo in ipairs(trackingInfo.centers) do
                        local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                        local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                        if resourcesByObjectID then
                            for objectID,resourceState in pairs(resourcesByObjectID) do
                                if (not options.ignoreObjectIDs) or (not options.ignoreObjectIDs[objectID]) then
                                    local function matchesStockpileConstraints()
                                        if resourceState.providerType == serverResourceManager.providerTypes.storageArea then
                                            if (options.allowStockpiles or options.onlyStockpiles) then

                                                if options.minStockpileCount then
                                                    return resourceState.count >= options.minStockpileCount
                                                else
                                                    return true
                                                end
                                            else
                                                return false
                                            end
                                        else
                                            return (not options.onlyStockpiles)
                                        end
                                    end

                                    if matchesStockpileConstraints() and 
                                    (options.allowGather or (resourceState.providerType ~= serverResourceManager.providerTypes.gatherRequired)) and 
                                    (options.allowHeld or (resourceState.providerType ~= serverResourceManager.providerTypes.heldBySapien)) and 
                                    (resourceState.count > 1 or matchesAllowPlanQueuedObjects(objectID, tribeID)) then
                                        local resourcePos = resourceState.object.pos
                                        local thisDistance2 = length2(pos - resourcePos)
                                        local thisDistanceWeight = thisDistance2

                                        local maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                                        if options.maxDistance2 then
                                            maxDistance2ToUse = options.maxDistance2
                                        else
                                            if resourceState.providerType == serverResourceManager.providerTypes.storageArea or 
                                            resourceState.providerType == serverResourceManager.providerTypes.craftArea or 
                                            resourceState.providerType == serverResourceManager.providerTypes.looseWithStorePlan or 
                                            resourceState.providerType == serverResourceManager.providerTypes.heldBySapien then
                                                maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                                            else
                                                maxDistance2ToUse = serverResourceManager.looseResourceMaxDistance2
                                            end
                                        end
                
                                        
                                        if resourceState.providerType == serverResourceManager.providerTypes.gatherRequired then
                                            thisDistanceWeight = thisDistanceWeight + extraDistanceHackToDiscourageGather
                                        end
                                        
                                        if options.goalObjectPos then
                                            if thisDistanceWeight > maxDistance2ToUse then
                                                thisDistance2 = length2(options.goalObjectPos - resourcePos)
                                                thisDistanceWeight = thisDistance2
                                                if resourceState.providerType == serverResourceManager.providerTypes.gatherRequired then
                                                    thisDistanceWeight = thisDistanceWeight + extraDistanceHackToDiscourageGather
                                                end
                                            end
                                        end
                                        
                                        if options.foodValueAffectsHeuristic then
                                            mj:log("debug thisDistanceWeight:", thisDistanceWeight, "distance meters:", math.floor(mj:pToM(math.sqrt(thisDistance2)))) 
                                        end
                                        
                                        --mj:log("serverResourceManager:distanceOrderedObjectsForResourceinTypesArray thisDistance:", mj:pToM(math.sqrt(thisDistance2)), " maxDistance:", mj:pToM(math.sqrt(maxDistance2ToUse)))
                                        if thisDistanceWeight < maxDistance2ToUse then
                                            local ignore = false
                                            if options.disallowAssignedExceptSapienID then
                                            -- mj:log("disallowAssignedExceptSapienID")
                                                --[[if resourceState.providerType == serverResourceManager.providerTypes.standard or 
                                                resourceState.providerType == serverResourceManager.providerTypes.looseWithStorePlan or
                                                resourceState.providerType == serverResourceManager.providerTypes.gatherRequired then]]
                                                    local resourceObjectID = objectID
                                                    local resourceObject = serverGOM:getObjectWithID(resourceObjectID)
                                                    local sapien = serverGOM:getObjectWithID(options.disallowAssignedExceptSapienID)
                                                    if resourceObject and sapien then
                                                        local assigned = false

                                                    --mj:log("disallowAssignedExceptSapienID b")
                                                        if serverSapien:objectIsAssignedToOtherSapien(resourceObject, sapien.sharedState.tribeID, sapien, nil, false) then
                                                            --mj:log("disallowAssignedExceptSapienID c")
                                                            if options.takePriorityOverStoreOrders and resourceState.providerType == serverResourceManager.providerTypes.looseWithStorePlan then
                                                                local orderObjectState = resourceObject.sharedState
                                                                if orderObjectState and orderObjectState.assignedSapienIDs then
                                                                    for otherSapienID,planTypeIndexOrTrue in pairs(orderObjectState.assignedSapienIDs) do
                                                                        if otherSapienID ~= options.disallowAssignedExceptSapienID then
                                                                            if (planTypeIndexOrTrue == true) or (planTypeIndexOrTrue == plan.types.storeObject.index) then
                                                                                local otherSapien = serverGOM:getObjectWithID(otherSapienID)
                                                                                if otherSapien then
                                                                                    --make sure sapien is planning to store the object
                                                                                    if not serverSapien:cancelOrdersMatchingPlanTypeIndex(sapien, plan.types.storeObject.index) then
                                                                                        assigned = true
                                                                                        break
                                                                                    end
                                                                                    --serverSapien:cancelAllOrders(otherSapien, false, false)
                                                                                end
                                                                            else
                                                                                assigned = true
                                                                                break
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                            else
                                                                assigned = true
                                                            end
                                                        end

                                                        if assigned then
                                                            ignore = true
                                                        end
                                                    end
                                            --end
                                            end
                                            if not ignore then
                                                local insertIndex = #result + 1
                                                for otherIndex,other in ipairs(result) do
                                                    if other.distanceWeight > thisDistanceWeight then
                                                        insertIndex = otherIndex
                                                        break
                                                    end
                                                    if options.maxCount and otherIndex >= options.maxCount then
                                                        insertIndex = options.maxCount + 1
                                                        break
                                                    end
                                                end
                                                if not options.maxCount or insertIndex <= options.maxCount then
                                                    table.insert(result, insertIndex, {
                                                        distanceWeight = thisDistanceWeight,
                                                        distance2 = thisDistance2,
                                                        pos = resourcePos,
                                                        objectID = objectID,
                                                        objectTypeIndex = objectTypeIndex,
                                                        providerType = resourceState.providerType,
                                                        count = resourceState.count,
                                                    } )
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
    end
    
    if tribeIDOrNilForAny then
        local trackingInfo = trackingTribes[tribeIDOrNilForAny]
        if trackingInfo then
            doTribe(tribeIDOrNilForAny, trackingInfo)
        end
    else
        for tribeID, trackingInfo in pairs(trackingTribes) do
            doTribe(tribeID, trackingInfo)
        end
    end

    return result
end

function serverResourceManager:getValueOrderedValuableResources(pos, optionsOrNil)
    local options = optionsOrNil or {}
    local result = {}
    
    local function doTribe(tribeID, trackingInfo)
        for j,centerInfo in ipairs(trackingInfo.centers) do
            local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
            for objectTypeIndex, resourcesByObjectID in pairs(resourcesByObjectTypeThenObjectID) do
                local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                local resourceType = resource.types[resourceTypeIndex]
                local perItemValue = (resourceType.tradeValue or 1) / (resourceType.tradeBatchSize or 1)

                for objectID,resourceState in pairs(resourcesByObjectID) do
                    if (not options.ignoreObjectIDs) or (not options.ignoreObjectIDs[objectID]) then

                    local function getMatchesPerItemValueConstraints()
                        if resourceState.providerType == serverResourceManager.providerTypes.storageArea then
                            if (not options.minStoredPerItemValue) or perItemValue >= options.minStoredPerItemValue then
                                return true
                            end
                        else
                            if (not options.minLoosePerItemValue) or perItemValue >= options.minLoosePerItemValue then
                                return true
                            end
                        end
                    end
                    
                    local function matchesStockpileConstraints()
                        if resourceState.providerType == serverResourceManager.providerTypes.storageArea then
                            if (options.allowStockpiles or options.onlyStockpiles) then

                                if options.minStockpileCount then
                                    return resourceState.count >= options.minStockpileCount
                                else
                                    return true
                                end
                            else
                                return false
                            end
                        else
                            return (not options.onlyStockpiles)
                        end
                    end
                        
                    if getMatchesPerItemValueConstraints() then
                            if matchesStockpileConstraints() and 
                            (options.allowGather or (resourceState.providerType ~= serverResourceManager.providerTypes.gatherRequired)) and 
                            (options.allowHeld or (resourceState.providerType ~= serverResourceManager.providerTypes.heldBySapien)) then
                                local resourcePos = resourceState.object.pos
                                local thisDistance2 = length2(pos - resourcePos)

                                local maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                                if options.maxDistance2 then
                                    maxDistance2ToUse = options.maxDistance2
                                else
                                    if resourceState.providerType == serverResourceManager.providerTypes.storageArea or 
                                    resourceState.providerType == serverResourceManager.providerTypes.craftArea or 
                                    resourceState.providerType == serverResourceManager.providerTypes.looseWithStorePlan or 
                                    resourceState.providerType == serverResourceManager.providerTypes.heldBySapien then
                                        maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                                    else
                                        maxDistance2ToUse = serverResourceManager.looseResourceMaxDistance2
                                    end
                                end
                                
                                if thisDistance2 < maxDistance2ToUse then
                                    local insertIndex = #result + 1
                                    for otherIndex,other in ipairs(result) do
                                        if other.perItemValue < perItemValue then
                                            insertIndex = otherIndex
                                            break
                                        end
                                    end
                                    table.insert(result, insertIndex, {
                                        perItemValue = perItemValue,
                                        distance2 = thisDistance2,
                                        pos = resourcePos,
                                        objectID = objectID,
                                        objectTypeIndex = objectTypeIndex,
                                        providerType = resourceState.providerType,
                                        count = resourceState.count,
                                    } )
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    for tribeID, trackingInfo in pairs(trackingTribes) do
        doTribe(tribeID, trackingInfo)
    end

    return result
end


function serverResourceManager:anyResourceIsAvailable(objectTypesArray, pos, allowHeld, tribeID)
    --mj:log("serverResourceManager:anyResourceIsAvailable a")
    local trackingInfo = trackingTribes[tribeID]
    if not trackingInfo then
        --mj:log("serverResourceManager:anyResourceIsAvailable b returning false")
        return false
    end

    local dupeCheck = {}
    for i,objectTypeIndex in ipairs(objectTypesArray) do
        if not dupeCheck[objectTypeIndex] then
            dupeCheck[objectTypeIndex] = true
            for k,centerInfo in ipairs(trackingInfo.centers) do
                local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                if resourcesByObjectID then
                    for objectID,resourceState in pairs(resourcesByObjectID) do
                        if allowHeld or (resourceState.providerType ~= serverResourceManager.providerTypes.heldBySapien) then
                            if (resourceState.count > 1 or matchesAllowPlanQueuedObjects(objectID, tribeID)) then
                                --mj:log("found resource with id:", resourceState.object.uniqueID, " state:", resourceState)

                                local resourcePos = resourceState.object.pos
                                local thisDistance2 = length2(pos - resourcePos)
                                
                                local maxDistance2ToUse = nil
                                if resourceState.providerType == serverResourceManager.providerTypes.storageArea or 
                                resourceState.providerType == serverResourceManager.providerTypes.craftArea or 
                                resourceState.providerType == serverResourceManager.providerTypes.heldBySapien then
                                    maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                                else
                                    maxDistance2ToUse = serverResourceManager.looseResourceMaxDistance2
                                end
                                
                                --mj:log("serverResourceManager:anyResourceIsAvailable thisDistance:", mj:pToM(math.sqrt(thisDistance2)), " maxDistance:", mj:pToM(math.sqrt(maxDistance2ToUse)), " id:", resourceState.object.uniqueID)

                                if thisDistance2 < maxDistance2ToUse then
                                    return true
                                end
                            end
                        end
                    end
                end
            end

        end
    end
    return nil
end

function serverResourceManager:countOfResourcesNearPos(resourceTypeOrGroupIndex, pos, allowHeld, tribeID, thresholdBreakCountOrNil, foundObjectTypeCountsOrNil) --used for maintenace orders
    local trackingInfo = trackingTribes[tribeID]
    if not trackingInfo then
        return 0
    end

    local allObjectTypes = nil
    local resourceGroup = resource.groups[resourceTypeOrGroupIndex]
    if resourceGroup then
        allObjectTypes = {}
        local allObjectsHash = {}
        for j,resourceTypeIndex in ipairs(resourceGroup.resourceTypes) do
            local objectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
            for k, objectTypeIndex in ipairs(objectTypeIndexes) do
                if not allObjectsHash[objectTypeIndex] then
                    allObjectsHash[objectTypeIndex] = true
                    table.insert(allObjectTypes, objectTypeIndex)
                end
            end
        end
    else
        allObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeOrGroupIndex]
    end
    
    local foundCount = 0
    for j,objectTypeIndex in ipairs(allObjectTypes) do
        for k,centerInfo in ipairs(trackingInfo.centers) do
            local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
            local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
            if resourcesByObjectID then
                for objectID,resourceState in pairs(resourcesByObjectID) do
                    if allowHeld or (resourceState.providerType ~= serverResourceManager.providerTypes.heldBySapien) then
                        if (resourceState.count > 1 or matchesAllowPlanQueuedObjects(objectID, tribeID)) then
                            --mj:log("found resource with id:", resourceState.object.uniqueID, " state:", resourceState)
                            local resourcePos = resourceState.object.pos
                            local thisDistance2 = length2(pos - resourcePos)
                            
                            local maxDistance2ToUse = nil
                            if resourceState.providerType == serverResourceManager.providerTypes.storageArea or 
                            resourceState.providerType == serverResourceManager.providerTypes.craftArea or 
                            resourceState.providerType == serverResourceManager.providerTypes.heldBySapien then
                                maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                            else
                                maxDistance2ToUse = serverResourceManager.looseResourceMaxDistance2
                            end
                            
                            --mj:log("serverResourceManager:anyResourceIsAvailable thisDistance:", mj:pToM(math.sqrt(thisDistance2)), " maxDistance:", mj:pToM(math.sqrt(maxDistance2ToUse)), " id:", resourceState.object.uniqueID)

                            if thisDistance2 < maxDistance2ToUse then
                                foundCount = foundCount + resourceState.count
                                if foundObjectTypeCountsOrNil then
                                    foundObjectTypeCountsOrNil[objectTypeIndex] = (foundObjectTypeCountsOrNil[objectTypeIndex] or 0) + resourceState.count
                                end

                                if thresholdBreakCountOrNil and foundCount >= thresholdBreakCountOrNil then
                                    return foundCount
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return foundCount
end

function serverResourceManager:allRequiredResourcesAreAvailable(requiredResources, pos, allowHeld, restrictedObjectTypes, returnedMissingResourceArrayOrNil, tribeID)
    if (not requiredResources) or (not requiredResources[1]) then
        return true
    end

    local trackingInfo = trackingTribes[tribeID]
    if not trackingInfo then
        --mj:error("no tracking info for tribe:", tribeID)
        return false
    end

    local allFound = true

    for i, resourceInfo in ipairs(requiredResources) do
        local foundCount = 0
        local allObjectTypes = nil
        if resourceInfo.objectTypeIndex then
            allObjectTypes = {resourceInfo.objectTypeIndex}
        elseif resourceInfo.group then
            allObjectTypes = {}
            local allObjectsHash = {}
            for j,resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                local objectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
                for k, objectTypeIndex in ipairs(objectTypeIndexes) do
                    if not allObjectsHash[objectTypeIndex] then
                        allObjectsHash[objectTypeIndex] = true
                        table.insert(allObjectTypes, objectTypeIndex)
                    end
                end
            end
        else
            allObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceInfo.type]
        end

        for j,objectTypeIndex in ipairs(allObjectTypes) do
            if not restrictedObjectTypes or not restrictedObjectTypes[objectTypeIndex] then
                for k,centerInfo in ipairs(trackingInfo.centers) do
                    local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                    local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                    if resourcesByObjectID then
                        for objectID,resourceState in pairs(resourcesByObjectID) do
                            if allowHeld or (resourceState.providerType ~= serverResourceManager.providerTypes.heldBySapien) then
                                local resourcePos = resourceState.object.pos
                                local thisDistance2 = length2(pos - resourcePos)
                                
                                local maxDistance2ToUse = nil
                                if resourceState.providerType == serverResourceManager.providerTypes.storageArea or 
                                resourceState.providerType == serverResourceManager.providerTypes.craftArea or 
                                resourceState.providerType == serverResourceManager.providerTypes.heldBySapien then
                                    maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                                else
                                    maxDistance2ToUse = serverResourceManager.looseResourceMaxDistance2
                                end

                                --mj:log("serverResourceManager:allRequiredResourcesAreAvailable thisDistance:", mj:pToM(math.sqrt(thisDistance2)), " maxDistance:", mj:pToM(math.sqrt(maxDistance2ToUse)), " id:", resourceState.object.uniqueID)

                                if thisDistance2 < maxDistance2ToUse then
                                    local availableCount = resourceState.count
                                    if not matchesAllowPlanQueuedObjects(objectID, tribeID) then
                                        availableCount = availableCount - 1
                                    end
                                    if availableCount > 0 then
                                        foundCount = foundCount + resourceState.count
                                        
                                        
                                        if foundCount >= resourceInfo.count then
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if foundCount >= resourceInfo.count then
                            break
                        end
                    end
                end

                if foundCount >= resourceInfo.count then
                    break
                end
            end
        end

        if foundCount < resourceInfo.count then
            allFound = false
            if not returnedMissingResourceArrayOrNil then
                return false
            end

            if returnedMissingResourceArrayOrNil then
                local missingInfo = {
                    objectTypeIndex = resourceInfo.objectTypeIndex,
                    type = resourceInfo.type,
                    group = resourceInfo.group,
                    missingCount = resourceInfo.count - foundCount,
                    requiredCount = resourceInfo.count,
                }
                table.insert(returnedMissingResourceArrayOrNil, missingInfo)
            end
        end
    end

    return allFound
end


function serverResourceManager:findResourceForSapien(sapien, objectTypesArray, options)
    options.maxCount = 1
    options.disallowAssignedExceptSapienID = sapien.uniqueID

    local objectTypesAbleToBeCarried = {}
    for i,objectTypeIndex in ipairs(objectTypesArray) do

        if options.restrictToCarryWithObjectTypeIndex then
            if gameObject.types[options.restrictToCarryWithObjectTypeIndex].resourceTypeIndex == gameObject.types[objectTypeIndex].resourceTypeIndex then
                table.insert(objectTypesAbleToBeCarried, objectTypeIndex)
            end
        else
        --if serverSapien:getMaxCarryCount(sapien, gameObject.types[objectTypeIndex].resourceTypeIndex) > 0 then
            table.insert(objectTypesAbleToBeCarried, objectTypeIndex)
        --end
        end
    end
    
    local nearestResources = serverResourceManager:distanceOrderedObjectsForResourceinTypesArray(objectTypesAbleToBeCarried, sapien.pos, options, sapien.sharedState.tribeID) 
    
    --mj:log("findResourceForSapien:", sapien.uniqueID, " result:", nearestResources)
    if nearestResources then
        return nearestResources[1]--note maxCount of 1 is sent in options above, this is not as silly as it loooks
    end
    return nil
end

function serverResourceManager:getAllResourceObjectTypesForTribe(tribeID) --used to set seen resource types
    local result = {}
    local trackingInfo = trackingTribes[tribeID]
    if trackingInfo then
        local foundTypes = {}
        for j,centerInfo in ipairs(trackingInfo.centers) do
            local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
            for objectTypeIndex,resourcesByObjectID in pairs(resourcesByObjectTypeThenObjectID) do
                if not foundTypes[objectTypeIndex] then
                    foundTypes[objectTypeIndex] = true
                    table.insert(result, objectTypeIndex)
                end
            end
        end
    end
    return result
    --[[local result = {}
    local dupeCheck = {}
    for objectTypeIndex,resourcesByObjectID in pairs(resourcesByObjectTypeThenObjectID) do
        if not dupeCheck[objectTypeIndex] then
            for objectID,resourceState in pairs(resourcesByObjectID) do
                local resourcePos = resourceState.object.pos
                local thisDistance2 = length2(pos - resourcePos)
                
                local maxDistance2ToUse = nil
                if resourceState.providerType == serverResourceManager.providerTypes.storageArea or
                 resourceState.providerType == serverResourceManager.providerTypes.craftArea or 
                 resourceState.providerType == serverResourceManager.providerTypes.heldBySapien then
                    maxDistance2ToUse = serverResourceManager.storageResourceMaxDistance2
                else
                    maxDistance2ToUse = serverResourceManager.looseResourceMaxDistance2
                end

                if thisDistance2 < maxDistance2ToUse then
                    dupeCheck[objectTypeIndex] = true
                    table.insert(result, objectTypeIndex)
                    break
                end
            end
        end
    end
    --mj:log("getAllResourceObjectTypesNearPos result:", result)
    return result]]
end

function serverResourceManager:getResourceInfoForObjectWithID(objectUniqueID, restrictResourceObjectTypeIndexOrNil)

    local resourceObject = allResourceObjects[objectUniqueID]
    if not resourceObject then
        return nil
    end
    
    local result = {
        pos = resourceObject.pos,
        objectID = objectUniqueID,
        objectTypeIndex = nil,
        providerType = serverResourceManager.providerTypes.standard,
        count = 0,
    }

    if gameObject.types[resourceObject.objectTypeIndex].isStorageArea then
        if resourceObject.sharedState.inventory and resourceObject.sharedState.inventory.countsByObjectType then
            local countsByObjectType = resourceObject.sharedState.inventory.countsByObjectType
            for thisObjectTypeIndex, count in pairs(countsByObjectType) do
                if count > 0 then
                    if (not restrictResourceObjectTypeIndexOrNil) or restrictResourceObjectTypeIndexOrNil == thisObjectTypeIndex then
                        result.providerType = serverResourceManager.providerTypes.storageArea
                        result.count = count
                        result.objectTypeIndex = thisObjectTypeIndex
                        return result
                    end
                end
            end
        end
        return nil
    end

    if (not restrictResourceObjectTypeIndexOrNil) or restrictResourceObjectTypeIndexOrNil == resourceObject.objectTypeIndex then
        result.objectTypeIndex = resourceObject.objectTypeIndex
        result.count = 1
        return result
    end
        
    --[[local removeInfo = removeInfosByObjectID[uniqueID]
    if removeInfo then
        local trackingInfo = trackingTribes[tribeID]
        if trackingInfo then
            local removeObjectTypeIndexes = removeInfo[tribeID]
            if removeObjectTypeIndexes then
                for i,centerInfo in ipairs(trackingInfo.centers) do
                    local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                    for objectTypeIndex,v in pairs(removeObjectTypeIndexes) do
                        local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                        if resourcesByObjectID then
                            local resourceState = resourcesByObjectID[uniqueID]
                            if resourceState then
                                return {
                                    pos = resourceState.object.pos,
                                    objectID = uniqueID,
                                    objectTypeIndex = objectTypeIndex,
                                    providerType = resourceState.providerType,
                                    count = resourceState.count,
                                }
                            end
                        end
                    end
                end
            end
        end
    end]]

    --[[local objectTypes = objectTypesByObjectID[uniqueID]
    if objectTypes then
        for objectTypeIndex,trueFalse in pairs(objectTypes) do
            if trueFalse and ((not resourceObjectTypeIndexOrNil) or (objectTypeIndex == resourceObjectTypeIndexOrNil)) then
                local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                if resourcesByObjectID and resourcesByObjectID[uniqueID] then
                    local resourceState = resourcesByObjectID[uniqueID]
                    if resourceObjectTypeIndexOrNil or resourceState.count > 0 then
                        return {
                            pos = resourceState.object.pos,
                            objectID = uniqueID,
                            objectTypeIndex = objectTypeIndex,
                            providerType = resourceState.providerType,
                            count = resourceState.count,
                        }
                    end
                end
            end
        end
    end]]
   -- return nil
end


function serverResourceManager:addTribe(destinationState)
    --mj:debug("serverResourceManager:addTribe:", destinationState.name, " tribeID:", destinationState.destinationID)

    if not trackingTribes[destinationState.destinationID] then
        local tribeCenters = destinationState.tribeCenters
        if tribeCenters and tribeCenters[1] then
            local centers = {}
            trackingTribes[destinationState.destinationID] = {
                centers = centers
            }

            for i,destinationCenterInfo in ipairs(tribeCenters) do
                centers[i] = {
                    pos = destinationCenterInfo.pos,
                    resourcesByObjectTypeThenObjectID = {},
                }
            end

            for objectID,object in pairs(allResourceObjects) do
                serverResourceManager:addAnyResourceForObject(object, false, destinationState.destinationID)
            end
        else
            mj:error("no tribe centers in:", destinationState)
        end
    end
end

--trackingTribes[tribeID].centers[i].resourcesByObjectTypeThenObjectID[objectTypeIndex][object.uniqueID] = resourceState
-- removeInfosByObjectID[object.uniqueID][tribeID][objectTypeIndex] = true

function serverResourceManager:recalculateForTribe(destinationState)

    --mj:log("serverResourceManager:recalculateForTribe:", destinationState.destinationID)
    local tribeID = destinationState.destinationID
    local trackingInfo = trackingTribes[tribeID]
    if trackingInfo then

        local tribeCenters = destinationState.tribeCenters
        if tribeCenters and tribeCenters[1] then
            local oldTrackingInfoCenterCount = #trackingInfo.centers

            for i,destinationCenterInfo in ipairs(tribeCenters) do
                if trackingInfo.centers[i] then
                    trackingInfo.centers[i].pos = destinationCenterInfo.pos
                else
                    trackingInfo.centers[i] = {
                        pos = destinationCenterInfo.pos,
                        resourcesByObjectTypeThenObjectID = {},
                    }
                end
            end

            for i=#tribeCenters + 1,oldTrackingInfoCenterCount do
                trackingInfo.centers[i] = nil
            end

            local recalculatedExistingObjects = {}

            for objectID,objectTypesByTribe in pairs(removeInfosByObjectID) do
                local objectTypes = objectTypesByTribe[tribeID]
                if objectTypes then
                    for objectTypeIndex,v in pairs(objectTypes) do
                        for i,centerInfo in ipairs(trackingInfo.centers) do
                            --mj:log("centerInfo:", centerInfo)
                            local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
                            local resourcesByObjectID = resourcesByObjectTypeThenObjectID[objectTypeIndex]
                            if resourcesByObjectID then
                                local resourceState = resourcesByObjectID[objectID]
                                if resourceState then
                                    local object = allResourceObjects[objectID]
                                    recalculatedExistingObjects[objectID] = true
                                    --mj:log("calling updateResourcesForObject:", objectID)
                                    serverResourceManager:updateResourcesForObject(object, destinationState.destinationID)
                                end
                            end
                        end

                    end
                end
            end

            for objectID,object in pairs(allResourceObjects) do
                if not recalculatedExistingObjects[objectID] then
                    --mj:log("calling addAnyResourceForObject:", objectID)
                    serverResourceManager:addAnyResourceForObject(object, false, destinationState.destinationID)
                end
            end
        end
    end
end

function serverResourceManager:removeTribe(tribeID)
    --mj:log("serverResourceManager:removeTribe:", tribeID)
    if trackingTribes[tribeID] then
        for objectID,tribeIDs in pairs(removeInfosByObjectID) do
            tribeIDs[tribeID] = nil
        end
        trackingTribes[tribeID] = nil
    end
end

function serverResourceManager:getResourceObjectCounts(tribeID)
    local infosByObjectTypeIndex = {}
    local trackingInfo = trackingTribes[tribeID]
    if trackingInfo then
        for i,centerInfo in ipairs(trackingInfo.centers) do
            local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
            for objectTypeIndex,resourcesByObjectID in pairs(resourcesByObjectTypeThenObjectID) do
                for objectID,resourceState in pairs(resourcesByObjectID) do
                    if resourceState.providerType == serverResourceManager.providerTypes.storageArea and resourceState.count > 0 then
                        local thisObjectTypeInfo = infosByObjectTypeIndex[objectTypeIndex]
                        if not (thisObjectTypeInfo and thisObjectTypeInfo.storageAreas[objectID]) then
                            if not thisObjectTypeInfo then
                                thisObjectTypeInfo = {
                                    count = 0,
                                    storageAreas = {}
                                }
                                infosByObjectTypeIndex[objectTypeIndex] = thisObjectTypeInfo
                            end

                            thisObjectTypeInfo.count = thisObjectTypeInfo.count + resourceState.count
                            thisObjectTypeInfo.storageAreas[objectID] = {
                                count = resourceState.count,
                                pos = resourceState.object.pos
                            }
                        end
                    end
                end
            end
        end
    end
    --mj:log("infosByObjectTypeIndex:", infosByObjectTypeIndex)
    return infosByObjectTypeIndex
end

function serverResourceManager:callFunctionForEachResourceObject(tribeID, restrictProviderTypeOrNil, func)
    local trackingInfo = trackingTribes[tribeID]
    if trackingInfo then
        for i,centerInfo in ipairs(trackingInfo.centers) do
            local resourcesByObjectTypeThenObjectID = centerInfo.resourcesByObjectTypeThenObjectID
            for objectTypeIndex,resourcesByObjectID in pairs(resourcesByObjectTypeThenObjectID) do
                for objectID,resourceState in pairs(resourcesByObjectID) do
                    if resourceState.providerType == restrictProviderTypeOrNil and resourceState.count > 0 then
                        func(resourceState.object, objectTypeIndex, resourceState.count)
                    end
                end
            end
        end
    end
end


function serverResourceManager:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverSapien = initObjects.serverSapien
    serverStorageArea = initObjects.serverStorageArea
    --serverSapienAI = serverSapienAI_
end

return serverResourceManager