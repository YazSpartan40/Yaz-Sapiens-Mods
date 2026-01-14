local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"
local planHelper = mjrequire "common/planHelper"
--local storage = mjrequire "common/storage"
local objectInventory = mjrequire "common/objectInventory"
--local order = mjrequire "common/order"
local research = mjrequire "common/research"
local constructable = mjrequire "common/constructable"
local resource = mjrequire "common/resource"
local anchor = mjrequire "server/anchor"
local serverTutorialState = mjrequire "server/serverTutorialState"
local serverTribeAIPlayer = mjrequire "server/serverTribeAIPlayer"

local serverResourceManager = mjrequire "server/serverResourceManager"

local serverCraftArea = {}

local serverGOM = nil
local serverWorld = nil
--local serverStorageArea = nil
local planManager = nil
local serverSapien = nil
--local serverTribeAIPlayer = nil


local availablityChangeCallbackInfosByGroupTypeIndex = {}
local availablityChangeGroupTypesByObjectID = {}
local craftAreasByGroupTypes = {}


local defaultMaxDistance2 = serverResourceManager.storageResourceMaxDistance2


local craftCompleteFunctionsByConstructableType = {
    [constructable.types.splitLog.index] = function(tribeID)
        serverTutorialState:setSplitLogComplete(tribeID)
    end,
    [constructable.types.stonePickaxe.index] = function(tribeID)
        serverTutorialState:setCraftPickAxeComplete(tribeID)
    end,
    [constructable.types.stoneSpear.index] = function(tribeID)
        serverTutorialState:setCraftSpearComplete(tribeID)
    end,
    [constructable.types.stoneHatchet.index] = function(tribeID)
        serverTutorialState:setCraftHatchetComplete(tribeID)
    end,
    [constructable.types.cookedChicken.index] = function(tribeID)
        serverTutorialState:setCraftedCookedMeatComplete(tribeID)
    end
}

craftCompleteFunctionsByConstructableType[constructable.types.flintPickaxe.index] = craftCompleteFunctionsByConstructableType[constructable.types.stonePickaxe.index]
craftCompleteFunctionsByConstructableType[constructable.types.bronzePickaxe.index] = craftCompleteFunctionsByConstructableType[constructable.types.stonePickaxe.index]

craftCompleteFunctionsByConstructableType[constructable.types.flintSpear.index] = craftCompleteFunctionsByConstructableType[constructable.types.stoneSpear.index]
craftCompleteFunctionsByConstructableType[constructable.types.boneSpear.index] = craftCompleteFunctionsByConstructableType[constructable.types.stoneSpear.index]
craftCompleteFunctionsByConstructableType[constructable.types.bronzeSpear.index] = craftCompleteFunctionsByConstructableType[constructable.types.stoneSpear.index]

craftCompleteFunctionsByConstructableType[constructable.types.flintHatchet.index] = craftCompleteFunctionsByConstructableType[constructable.types.stoneHatchet.index]
craftCompleteFunctionsByConstructableType[constructable.types.bronzeHatchet.index] = craftCompleteFunctionsByConstructableType[constructable.types.stoneHatchet.index]

craftCompleteFunctionsByConstructableType[constructable.types.cookedAlpaca.index] = craftCompleteFunctionsByConstructableType[constructable.types.cookedChicken.index]
craftCompleteFunctionsByConstructableType[constructable.types.cookedMammoth.index] = craftCompleteFunctionsByConstructableType[constructable.types.cookedChicken.index]
craftCompleteFunctionsByConstructableType[constructable.types.cookedFish.index] = craftCompleteFunctionsByConstructableType[constructable.types.cookedChicken.index]

local function callCallbacksForCraftAreaAvailabilityChange(tribeID, craftAreaInfo, isNewlyAvailableOrNilForUnavailable)
    local function doCheck(groupTypeIndex, callbackInfos)
        if craftAreasByGroupTypes[groupTypeIndex] and craftAreasByGroupTypes[groupTypeIndex][craftAreaInfo.craftArea.uniqueID] then
            for objectID,callbackInfo in pairs(callbackInfos) do
                local callbackDistance2 = length2(callbackInfo.pos - craftAreaInfo.pos)
                if callbackDistance2 < defaultMaxDistance2 then
                    callbackInfo.func(tribeID, objectID, groupTypeIndex, isNewlyAvailableOrNilForUnavailable, craftAreaInfo.pos)
                end
            end
        end
    end

    for groupTypeIndex,callbackInfos in pairs(availablityChangeCallbackInfosByGroupTypeIndex) do
        doCheck(groupTypeIndex, callbackInfos)
    end
end

function serverCraftArea:removeObjectFromCraftAreaWithObjectTypeIndex(craftAreaObjectID, objectTypeIndex, inventoryLocationOrNil)
    local storageObject = serverGOM:getObjectWithID(craftAreaObjectID)

    local objectInfo = nil

    local placesToCheck = nil
    if inventoryLocationOrNil then
        placesToCheck = {inventoryLocationOrNil}
    else
        placesToCheck = {
            objectInventory.locations.availableResource.index,
            objectInventory.locations.tool.index,
        }
    end
    
    local objectState = storageObject.sharedState

    if objectState.inventories then
        for i,inventoryLocation in ipairs(placesToCheck) do
            --local inventory = inventories[inventoryLocation]
            objectInfo = objectInventory:removeAndGetInfo(objectState, inventoryLocation, objectTypeIndex, nil)

            if objectInfo then
                serverGOM:saveObject(storageObject.uniqueID)
                serverResourceManager:updateResourcesForObject(storageObject)
                return objectInfo
            end
        end
    end
    return nil
end

function serverCraftArea:planWasCancelledForCraftObject(object, planTypeIndex, tribeID)
    --mj:log("serverCraftArea:planWasCancelledForCraftObject")
    if planTypeIndex == plan.types.craft.index or planTypeIndex == plan.types.research.index then
        --mj:log("serverGOM:dropInventory")
        serverGOM:dropInventory(object, tribeID, nil, nil, nil)
        
        object.sharedState:remove("buildSequenceIndex")
        object.sharedState:remove("buildSequenceRepeatCounters")
        
        serverResourceManager:updateResourcesForObject(object)
        serverCraftArea:updateInUseStateForCraftArea(object)
    end
end

function serverCraftArea:createCraftedObjectInfos(constructableTypeIndex, tribeID)
    local constructableType = constructable.types[constructableTypeIndex]
    if not constructableType.hasNoOutput then

        local outputObjectInfo = constructableType.outputObjectInfo
        local requiredResources = constructableType.requiredResources
        -- mj:log("outputObjectInfo:", outputObjectInfo)
        local results = {}
        local constructionObjects = {}

        local whiteListTypes = serverWorld:seenResourceObjectTypesForTribe(tribeID)

        for i, resourceInfo in ipairs(requiredResources) do
                local objectTypeIndex = nil
                if resourceInfo.objectTypeIndex then
                    objectTypeIndex = resourceInfo.objectTypeIndex
                else

                    local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, nil, whiteListTypes)
                    if availableObjectTypeIndexes and availableObjectTypeIndexes[1] then
                        objectTypeIndex = availableObjectTypeIndexes[1]
                    else
                        if resourceInfo.type then
                            objectTypeIndex = resource.types[resourceInfo.type].displayGameObjectTypeIndex
                        else
                            objectTypeIndex = resource.groups[resourceInfo.group].displayGameObjectTypeIndex
                        end
                    end
                end
        
                if objectTypeIndex then
                    for j=1,resourceInfo.count do
                        table.insert(constructionObjects, {
                            objectTypeIndex = objectTypeIndex,
                        })
                    end
                end
        end

        local function addObject(objectTypeIndex)
            local objectInfo = {
                objectTypeIndex = objectTypeIndex,
                sharedState = {
                    constructionObjects = constructionObjects,
                    constructionConstructableTypeIndex = constructableTypeIndex,
                }
            }
            table.insert(results, objectInfo)
        end

        if outputObjectInfo then
            local objectTypesArray = outputObjectInfo.objectTypesArray

            if outputObjectInfo.outputArraysByResourceObjectType then
                for i, constructionObject in ipairs(constructionObjects) do
                    objectTypesArray = outputObjectInfo.outputArraysByResourceObjectType[constructionObject.objectTypeIndex] --first to match wins
                    if objectTypesArray then
                        break
                    end
                end
            end

           -- mj:log("objectTypesArray:", objectTypesArray)
            
            if objectTypesArray then
                for i,objectTypeIndex in ipairs(objectTypesArray) do
                    --mj:log("createOutput:", objectTypeIndex)
                    addObject(objectTypeIndex)
                end
            end
        else
            local gameObjectTypeKeyOrIndex = constructableType.key
            local craftedObjectTypeIndex = gameObject.types[gameObjectTypeKeyOrIndex].index
           -- mj:log("createOutput craftedObjectTypeIndex:", craftedObjectTypeIndex)
           addObject(craftedObjectTypeIndex)
        end

        if results[1] then
            return results
        end
    end
    return nil
end

function serverCraftArea:completeCraft(orderObject, planTypeIndex, tribeID, sapienOrNil)
    --mj:error("complete craft")
    local orderObjectState = orderObject.sharedState

    --[[if serverGOM:anythingIsRequiredForBuildObjectOrCraftArea(orderObject, nil) then
        mj:warn("serverCraftArea:completeCraft called on object that still requires something:", orderObject.uniqueID)
        planManager:removePlanStateForObject(orderObject, planTypeIndex, orderObjectState.tribeID)
        return
    end]]
    
    local foundPlanState = nil
    local foundPlanStateIndex = nil
    local planStatesForTribeID = planManager:getPlanStatesForObject(orderObject, tribeID)
    if planStatesForTribeID then
        for i,thisPlanState in ipairs(planStatesForTribeID) do
            if thisPlanState.planTypeIndex == planTypeIndex then
                foundPlanState = thisPlanState
                foundPlanStateIndex = i
                break
            end
        end
    end

    if not foundPlanState then
        mj:warn("no plan state found for complete craft:", orderObject.uniqueID, " tribeID:", tribeID, " orderObjectState:", orderObjectState)
        return
    end

    local constructableTypeIndex = foundPlanState.constructableTypeIndex
    if not constructableTypeIndex then
        mj:warn("no constructableTypeIndex found for complete craft:", orderObject.uniqueID, " tribeID:", tribeID, " orderObjectState:", orderObjectState)
    end
    
    local constructableType = constructable.types[constructableTypeIndex]

    local requiredResources = constructableType.requiredResources
    local inventories = orderObjectState.inventories
    
    --orderObjectState:remove("craftInProgress")
    orderObjectState:remove("buildSequenceIndex")
    orderObjectState:remove("buildSequenceRepeatCounters")

    local constructionObjects = {}
    local planOrderIndex = foundPlanState.planOrderIndex or foundPlanState.planID
    local planPriorityOffset = foundPlanState.priorityOffset
    local manuallyPrioritized = foundPlanState.manuallyPrioritized

    
    local function restoreResource(objectInfo)
        serverGOM:createOutput(orderObject.pos, nil, objectInfo.objectTypeIndex, {constructionObjects = objectInfo.constructionObjects}, tribeID, plan.types.storeObject.index, {
            planOrderIndex = planOrderIndex,
            planPriorityOffset = planPriorityOffset,
            manuallyPrioritized = manuallyPrioritized,
        })
    end

    for i, resourceInfo in ipairs(requiredResources) do
        for j=1,resourceInfo.count do

            local function searchInventory(location)
                local inventory = inventories and inventories[location]
                if inventory and inventory.objects and next(inventory.objects) then
                    local countsByObjectType = inventory.countsByObjectType
                    local objects = inventory.objects
                    for k = #objects, 1, -1 do
                        local objectInfo = objects[k]
                        if resourceInfo.objectTypeIndex then
                            if resourceInfo.objectTypeIndex == objectInfo.objectTypeIndex then
                                table.insert(constructionObjects, objectInfo)

                                if resourceInfo.restoreOnCompletion then
                                    restoreResource(objectInfo)
                                end
                                
                                orderObjectState:removeFromArray("inventories", location, "objects", k)
                                
                                local newCountByObjectType = countsByObjectType[objectInfo.objectTypeIndex] - 1
                                if newCountByObjectType == 0 then
                                    orderObjectState:remove("inventories", location, "countsByObjectType", objectInfo.objectTypeIndex)
                                else
                                    orderObjectState:set("inventories", location, "countsByObjectType", objectInfo.objectTypeIndex, newCountByObjectType)
                                end

                                return true
                            end
                        else
                            local resourceTypeIndex = gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex
                            if resource:groupOrResourceMatchesResource(resourceInfo.type or resourceInfo.group, resourceTypeIndex) then
                                table.insert(constructionObjects, objectInfo)

                                if resourceInfo.restoreOnCompletion then
                                    restoreResource(objectInfo)
                                end
                                
                                orderObjectState:removeFromArray("inventories", location, "objects", k)

                                local newCountByObjectType = countsByObjectType[objectInfo.objectTypeIndex] - 1
                                if newCountByObjectType == 0 then
                                    orderObjectState:remove("inventories", location, "countsByObjectType", objectInfo.objectTypeIndex)
                                else
                                    orderObjectState:set("inventories", location, "countsByObjectType", objectInfo.objectTypeIndex, newCountByObjectType)
                                end
                                
                                return true
                            end
                        end
                    end
                end
                return false
            end

            local found = searchInventory(objectInventory.locations.inUseResource.index)
            if not found then
                found = searchInventory(objectInventory.locations.availableResource.index)
            end

            if not found then
                mj:error("serverCraftArea:completeCraft unable to find matching resource object:", orderObject.uniqueID, " resourceInfo:", resourceInfo)
                planManager:removePlanStateForObject(orderObject, planTypeIndex, nil, nil, tribeID)
                serverCraftArea:planWasCancelledForCraftObject(orderObject, planTypeIndex, tribeID)
                return
            end
        end
    end

    

    
    local assignResearchOrderType = nil
    if planTypeIndex == plan.types.research.index then
       -- mj:log("foundPlanState and planTypeIndex == plan.types.research.index")
        local researchTypeIndex = foundPlanState.researchTypeIndex
        if researchTypeIndex then
           -- mj:log("researchTypeIndex:", researchTypeIndex)
            if not serverWorld:discoveryIsCompleteForTribe(tribeID, researchTypeIndex) then
                --mj:log("assignResearchOrderType:", research.types[researchTypeIndex])
                assignResearchOrderType = research.types[researchTypeIndex]
            end
        end
    end

    if foundPlanState.craftCount == -1 or foundPlanState.craftCount > foundPlanState.currentCraftIndex or foundPlanState.shouldMaintainSetQuantity then
        orderObjectState:set("planStates", tribeID, foundPlanStateIndex, "currentCraftIndex", foundPlanState.currentCraftIndex + 1)

        local requiredItems = serverGOM:getRequiredItemsNotInInventory(orderObject, foundPlanState, constructableType.requiredTools, constructableType.requiredResources, constructableType.index)
        planManager:updateRequiredResourcesForPlan(tribeID, foundPlanState, orderObject, requiredItems)

    else
        planManager:removePlanStateForObject(orderObject, planTypeIndex, nil, nil, tribeID)
        serverCraftArea:updateInUseStateForCraftArea(orderObject)
        serverGOM:dropInventory(orderObject, tribeID, planOrderIndex, planPriorityOffset, manuallyPrioritized)
        orderObject.sharedState:remove("buildSequenceIndex")
        orderObject.sharedState:remove("buildSequenceRepeatCounters")
    end
    
    if not constructableType.hasNoOutput then
        local function createOutput(craftedObjectTypeIndex)

            local orderContext = nil
                
            local createObjectSharedState = {
                constructionObjects = constructionObjects,
                orderContext = orderContext,
                constructionConstructableTypeIndex = constructableTypeIndex,
            }

            local planTypeIndexToAssign = plan.types.storeObject.index
            local addPlanContext = {
                planOrderIndex = planOrderIndex,
                planPriorityOffset = planPriorityOffset,
                manuallyPrioritized = manuallyPrioritized,
            }

            if assignResearchOrderType and (assignResearchOrderType.constructableTypeIndexesByBaseResourceTypeIndex or assignResearchOrderType.constructableTypeIndexArraysByBaseResourceTypeIndex) then
                local craftedResourceTypeIndex = gameObject.types[craftedObjectTypeIndex].resourceTypeIndex

                local complete = serverWorld:discoveryIsCompleteForTribe(tribeID, assignResearchOrderType.index)
                local typeToConstruct = research:getBestConstructableIndexForResearch(assignResearchOrderType.index, craftedResourceTypeIndex, planHelper:getCraftableDiscoveriesForTribeID(tribeID), complete)
                if typeToConstruct then
                   -- mj:log("typeToConstruct:", typeToConstruct)
                    planTypeIndexToAssign = plan.types.research.index
                    addPlanContext.researchTypeIndex = assignResearchOrderType.index
                    assignResearchOrderType = nil
                end
            end



            local lastOutputID = serverGOM:createOutput(orderObject.pos, nil, craftedObjectTypeIndex, createObjectSharedState, tribeID, planTypeIndexToAssign, addPlanContext)

            if lastOutputID and sapienOrNil then
                local lastOutputObject = serverGOM:getObjectWithID(lastOutputID)
                if lastOutputObject then
                    serverSapien:setLookAt(sapienOrNil, lastOutputID, lastOutputObject.pos)
                end
            end
        end
        
        local completionFunction = craftCompleteFunctionsByConstructableType[constructableType.index]
        if completionFunction then
            completionFunction(tribeID)
        end

        local outputObjectInfo = constructableType.outputObjectInfo
       -- mj:log("outputObjectInfo:", outputObjectInfo)
        if outputObjectInfo then
            local objectTypesArray = outputObjectInfo.objectTypesArray

            if outputObjectInfo.outputArraysByResourceObjectType then
                for i, constructionObject in ipairs(constructionObjects) do
                    objectTypesArray = outputObjectInfo.outputArraysByResourceObjectType[constructionObject.objectTypeIndex] --first to match wins
                    if objectTypesArray then
                        break
                    end
                end
            end

           -- mj:log("objectTypesArray:", objectTypesArray)
            
            if objectTypesArray then
                for i,objectTypeIndex in ipairs(objectTypesArray) do
                    --mj:log("createOutput:", objectTypeIndex)
                    createOutput(objectTypeIndex)
                end
            end
        else
            local gameObjectTypeKeyOrIndex = constructableType.key
            local craftedObjectTypeIndex = gameObject.types[gameObjectTypeKeyOrIndex].index
           -- mj:log("createOutput craftedObjectTypeIndex:", craftedObjectTypeIndex)
            createOutput(craftedObjectTypeIndex)
        end
    end
    
    serverTribeAIPlayer:addGrievanceIfNeededForCraftAreaUsed(orderObject.sharedState.tribeID, tribeID, orderObject.objectTypeIndex)

    serverResourceManager:updateResourcesForObject(orderObject)

    serverGOM:removeIfTemporaryCraftAreaAndDropInventoryIfNeeded(orderObject, tribeID, planOrderIndex, planPriorityOffset, manuallyPrioritized)
end

function serverCraftArea:getInUse(craftArea, ignoreSapienOrNil, tribeIDOrNilToSkipSomeChecks)
    
    local craftAreaGroupTypeIndex = gameObject.types[craftArea.objectTypeIndex].craftAreaGroupTypeIndex
    if craftAreasByGroupTypes[craftAreaGroupTypeIndex] then
        local craftAreaInfo = craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID]
        if craftAreaInfo then
            if not craftAreaInfo.inUse then
                return false
            end
        end
    end

    --todo it may now be OK to remove the additional checks below, need to try and test

    local sharedState = craftArea.sharedState
    local planStatesByTribeID = sharedState.planStates
    if planStatesByTribeID then
        for tribeID,planStates in pairs(planStatesByTribeID) do
            for i,thisPlanState in ipairs(planStates) do
                if thisPlanState.planTypeIndex == plan.types.craft.index or thisPlanState.planTypeIndex == plan.types.research.index then
                    return true
                end
            end
        end
    end

    if serverSapien:objectIsAssignedToOtherSapien(craftArea, tribeIDOrNilToSkipSomeChecks, ignoreSapienOrNil, {
        plan.types.craft.index,
        plan.types.research.index,
    }, true) then
        return true
    end
    return false
end

function serverCraftArea:updateInUseStateForCraftArea(craftArea)
    --mj:log("serverCraftArea:updateInUseStateForCraftArea:", craftArea.uniqueID)
    local craftAreaGroupTypeIndex = gameObject.types[craftArea.objectTypeIndex].craftAreaGroupTypeIndex
    if craftAreasByGroupTypes[craftAreaGroupTypeIndex] then
        local craftAreaInfo = craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID]
        if craftAreaInfo then
           -- mj:log("craftAreaInfo:", craftAreaInfo)
            local inUse = nil
            local sharedState = craftArea.sharedState
            local planStatesByTribeID = sharedState.planStates
            if planStatesByTribeID then
                for tribeID,planStates in pairs(planStatesByTribeID) do
                    for i,thisPlanState in ipairs(planStates) do
                        if thisPlanState.planTypeIndex == plan.types.craft.index or thisPlanState.planTypeIndex == plan.types.research.index then
                            inUse = true
                            break
                        end
                    end
                end
            end

            if not inUse then
                if serverSapien:objectIsAssignedToOtherSapien(craftArea, nil, nil, {
                    plan.types.craft.index,
                    plan.types.research.index,
                }, true) then
                    inUse = true
                end
            end
            if not inUse or (inUse ~= craftAreaInfo.inUse) then
               -- mj:log("inUse ~= craftAreaInfo.inUse")
                craftAreaInfo.inUse = inUse
                callCallbacksForCraftAreaAvailabilityChange(craftArea.sharedState.tribeID, craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID], inUse)
            end
        end
    end
end

function serverCraftArea:addCraftArea(craftArea)
    --mj:log("serverCraftArea:addCraftArea")
    local craftAreaGroupTypeIndex = gameObject.types[craftArea.objectTypeIndex].craftAreaGroupTypeIndex
    if not craftAreasByGroupTypes[craftAreaGroupTypeIndex] then
        craftAreasByGroupTypes[craftAreaGroupTypeIndex] = {}
    end

   -- mj:log("current status:", craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID])
    craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID] = {
        tribeID = craftArea.sharedState.tribeID,
        pos = craftArea.pos,
        craftArea = craftArea,
    }
    serverCraftArea:updateInUseStateForCraftArea(craftArea)
end

function serverCraftArea:removeCraftArea(craftArea)
    local craftAreaGroupTypeIndex = gameObject.types[craftArea.objectTypeIndex].craftAreaGroupTypeIndex
    if craftAreasByGroupTypes[craftAreaGroupTypeIndex] then

        if craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID] then
            if craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID].inUse then
                callCallbacksForCraftAreaAvailabilityChange(craftArea.sharedState.tribeID, craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID], nil)
            end
            
            craftAreasByGroupTypes[craftAreaGroupTypeIndex][craftArea.uniqueID] = nil
        end
    end
end

function serverCraftArea:anyCraftAreaAvailable(tribeID, requiresCraftAreaGroupTypeIndexes, planObjectPos, planTypeIndex)
    --mj:log("serverCraftArea:anyCraftAreaAvailable requiresCraftAreaGroupTypeIndexes:", requiresCraftAreaGroupTypeIndexes, " planObjectPos:", planObjectPos)
    for i,groupTypeIndex in ipairs(requiresCraftAreaGroupTypeIndexes) do
        --mj:log("craftAreasByGroupTypes:", craftAreasByGroupTypes, " groupTypeIndex:", groupTypeIndex)
        if craftAreasByGroupTypes[groupTypeIndex] then
            for objectID, info in pairs(craftAreasByGroupTypes[groupTypeIndex]) do
                --mj:log("serverCraftArea:anyCraftAreaAvailable info:", info)
                if (not info.inUse) then
                    if length2(planObjectPos - info.pos) < defaultMaxDistance2 then
                        return true
                    end
                end
            end
        end
    end
    return nil
end

function serverCraftArea:getAllCraftAreasAvailable(sapien, requiresCraftAreaGroupTypeIndexes)

    --local tribeID = sapien.sharedState.tribeID
    --mj:log("serverCraftArea:getAllCraftAreasAvailable requiresCraftAreaGroupTypeIndexes:", requiresCraftAreaGroupTypeIndexes, " planObjectPos:", planObjectPos)
    local result = {}
    local found = false
    for i,groupTypeIndex in ipairs(requiresCraftAreaGroupTypeIndexes) do
        --mj:log("craftAreasByGroupTypes:", craftAreasByGroupTypes, " groupTypeIndex:", groupTypeIndex)
        if craftAreasByGroupTypes[groupTypeIndex] then
            for objectID, info in pairs(craftAreasByGroupTypes[groupTypeIndex]) do
                --mj:log("serverCraftArea:getAllCraftAreasAvailable info:", info)
                if (not serverCraftArea:getInUse(info.craftArea, sapien, sapien.sharedState.tribeID)) then
                    local distance = length2(sapien.pos - info.pos)
                    if distance < defaultMaxDistance2 then
                        table.insert(result, {
                            distance = distance,
                            object = info.craftArea,
                        })
                        found = true
                    end
                end
            end
        end
    end
    if found then
        return result
    end
    return nil
end

function serverCraftArea:getFirstAvailableCraftAreaForPos(pos, requiresCraftAreaGroupTypeIndexes, restrictTribeIDOrNil)
    for i,groupTypeIndex in ipairs(requiresCraftAreaGroupTypeIndexes) do
        if craftAreasByGroupTypes[groupTypeIndex] then
            for objectID, info in pairs(craftAreasByGroupTypes[groupTypeIndex]) do
                if (not restrictTribeIDOrNil) or (restrictTribeIDOrNil == info.craftArea.sharedState.tribeID) then
                    if (not serverCraftArea:getInUse(info.craftArea, nil, nil)) then
                        local distance2 = length2(pos - info.pos)
                        if distance2 < defaultMaxDistance2 then
                            return info.craftArea
                        end
                    end
                end
            end
        end
    end
    return nil
end

function serverCraftArea:addCallbackForAvailabilityChange(objectID, requiredCraftAreaGroupTypeIndexes, objectPos, func)

    -- mj:log("serverCraftArea:addCallbackForAvailabilityChange:", objectID, " func:", func)
    for i, groupTypeIndex in ipairs(requiredCraftAreaGroupTypeIndexes) do
        local callbackInfos = availablityChangeCallbackInfosByGroupTypeIndex[groupTypeIndex]
        if not callbackInfos then
            callbackInfos = {}
            availablityChangeCallbackInfosByGroupTypeIndex[groupTypeIndex] = callbackInfos
        end

        callbackInfos[objectID] = {
            pos = objectPos,
            func = func,
        }

        if not availablityChangeGroupTypesByObjectID[objectID] then
            availablityChangeGroupTypesByObjectID[objectID] = {}
        end

        availablityChangeGroupTypesByObjectID[objectID][groupTypeIndex] = true
    end
end

function serverCraftArea:removeAllCallbacksForAvailabilityChange(objectID)

    if availablityChangeGroupTypesByObjectID[objectID] then
        for groupTypeIndex, trueFalse in pairs(availablityChangeGroupTypesByObjectID[objectID]) do
            local callbackInfos = availablityChangeCallbackInfosByGroupTypeIndex[groupTypeIndex]
            if callbackInfos then
                callbackInfos[objectID] = nil
            end
        end
        availablityChangeGroupTypesByObjectID[objectID] = nil
    end
end

function serverCraftArea:startCraftWithDeliveredPlanObject(craftAreaObject, objectInfo, sapien)

    local researchTypeIndex = nil
    local discoveryCraftableTypeIndex = nil
    local constructableTypeIndex = nil
    local planTypeIndex = plan.types.craft.index
    local tribeID = sapien.sharedState.tribeID

    if objectInfo.orderContext and objectInfo.orderContext.planState then
        local deliverObjectPlanState = objectInfo.orderContext.planState
        researchTypeIndex = deliverObjectPlanState.researchTypeIndex
        if researchTypeIndex then
            local researchType = research.types[researchTypeIndex]
            if researchType.constructableTypeIndex or researchType.constructableTypeIndexesByBaseResourceTypeIndex or researchType.constructableTypeIndexArraysByBaseResourceTypeIndex then
                constructableTypeIndex = researchType.constructableTypeIndex
                if researchType.constructableTypeIndexesByBaseResourceTypeIndex or researchType.constructableTypeIndexArraysByBaseResourceTypeIndex then
                    local complete = serverWorld:discoveryIsCompleteForTribe(tribeID, researchTypeIndex)
                    constructableTypeIndex = research:getBestConstructableIndexForResearch(researchType.index, gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex, planHelper:getCraftableDiscoveriesForTribeID(tribeID), complete)
                end
            end
            planTypeIndex = plan.types.research.index
            discoveryCraftableTypeIndex = deliverObjectPlanState.discoveryCraftableTypeIndex
        else
            constructableTypeIndex = deliverObjectPlanState.constructableTypeIndex
        end
    else
        mj:error("no plan state in startCraftWithDeliveredPlanObject")
        return false
    end

    if serverCraftArea:getInUse(craftAreaObject, sapien, sapien.sharedState.tribeID) then
        return false
    end

    mj:log("adding craft plan")

    local restrictedResourceObjectTypes = objectInfo.restrictedResourceObjectTypes
    local restrictedToolObjectTypes = objectInfo.restrictedToolObjectTypes

    local objectInfoToAdd = serverGOM:stripObjectInfoForAdditionToInventory(objectInfo)

    local added = planManager:addCraftPlan(tribeID, planTypeIndex, craftAreaObject.uniqueID, nil, constructableTypeIndex, 1, researchTypeIndex, discoveryCraftableTypeIndex, restrictedResourceObjectTypes, restrictedToolObjectTypes, nil, nil, nil, false)
    if not added then
        return false
    end
    --craftAreaObject.sharedState:set("inProgressConstructableTypeIndex", constructableTypeIndex)
    serverGOM:addConstructionObjectComponent(craftAreaObject, objectInfoToAdd, tribeID)

    return true
end

function serverCraftArea:init(serverGOM_, serverWorld_, serverSapien_, planManager_, serverStorageArea_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    planManager = planManager_
    serverSapien = serverSapien_
    --serverStorageArea = serverStorageArea_

    serverGOM:addObjectLoadedFunctionForType(gameObject.types.craftArea.index,function(object) --only the default craft area. Other objects  eg. serverCampfire need to do this themselves also
        --serverGOM:addObjectToSet(object, serverGOM.objectSets.logistics)
        serverCraftArea:addCraftArea(object)
        anchor:addAnchor(object.uniqueID, anchor.types.craftArea.index, object.sharedState.tribeID)
        return false
    end)


    serverGOM:addObjectUnloadedFunctionForType(gameObject.types.craftArea.index, function(object)
        serverCraftArea:removeCraftArea(object)
        anchor:anchorObjectUnloaded(object.uniqueID)
    end)
    
   --[[ serverGOM:addObjectLoadedFunctionForType(gameObject.types.storageArea.index,function(object)
        
        local objects = serverGOM:getSharedState(object, false, "inventory", "objects")
        if objects then
            for i,objectInfo in ipairs(objects) do
                addCallbackForEvolutionIfNeeded(object.uniqueID, objectInfo)
            end
        end
    end)]]
end

return serverCraftArea