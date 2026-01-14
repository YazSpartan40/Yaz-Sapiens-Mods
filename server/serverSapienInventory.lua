
--local gameObject = mjrequire "common/gameObject"

local serverResourceManager = mjrequire "server/serverResourceManager"
--local storage = mjrequire "common/storage"
local plan = mjrequire "common/plan"
--local research = mjrequire "common/research"
local sapienInventory = mjrequire "common/sapienInventory"
local serverSapienInventory = {}


local serverGOM = nil
local serverSapien = nil
local serverWorld = nil

local function addObjectInfo(sapien, objectInfo, addLocationTypeIndex)
    local sharedState = sapien.sharedState

    local inventories = sharedState.inventories or {}

    local incomingInventory = inventories[addLocationTypeIndex] or {}
    local incomingObjects = incomingInventory.objects or {}
    local incomingCountsByObjectType = incomingInventory.countsByObjectType or {}

    local objectTypeIndex = objectInfo.objectTypeIndex

   --[[ for storedObjectTypeIndex,storedCount in pairs(incomingCountsByObjectType) do
        if storedCount > 0 then
            local currentResourceTypeIndex = gameObject.types[storedObjectTypeIndex].resourceTypeIndex
            local currentCarryType = storage:carryTypeForResourceType(currentResourceTypeIndex)
            local incomingResourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
            local incomingCarryType = storage:carryTypeForResourceType(incomingResourceTypeIndex)
            if incomingCarryType ~= currentCarryType then
                mj:error("Attempting to add object with different carry type than existing to sapien inventory:", sapien.uniqueID) --todo

                sharedState:remove("inventories", addLocationTypeIndex) --todo quick dirty fix to sort out a meat problem
                return
            end
            break
        end
    end]]

    local newCount = (incomingCountsByObjectType[objectTypeIndex] or 0) + 1
    sharedState:set("inventories", addLocationTypeIndex, "countsByObjectType", objectTypeIndex, newCount)
    sharedState:set("inventories", addLocationTypeIndex, "objects", #incomingObjects + 1, objectInfo)


    --[[if not countsByObjectType[objectTypeIndex] then
        countsByObjectType[objectTypeIndex] = 0
    end

    countsByObjectType[objectTypeIndex] = countsByObjectType[objectTypeIndex] + 1

    table.insert(objects, objectInfo)

    inventory.objects = objects
    inventory.countsByObjectType = countsByObjectType

    inventories[addLocationTypeIndex] = inventory
    sharedState.inventories = inventories]]

    
    serverResourceManager:updateResourcesForObject(sapien)


   -- mj:log("added object to inventory:", sharedState.inventories)
    --serverGOM:saveObject(sapien.uniqueID)
end


function serverSapienInventory:removeOrderContexts(sapien, locationTypeIndex)
    local sharedState = sapien.sharedState
    local inventories = sharedState.inventories

    if inventories then
        local inventory = inventories[locationTypeIndex]
        if inventory then
            local objects = inventory.objects
            if objects then
                for i,objectInfo in ipairs(objects) do
                    local orderContext = objectInfo.orderContext
                    if orderContext then
                        if orderContext.planState and orderContext.planState.planTypeIndex == plan.types.research.index then
                            serverWorld:removeDiscoveryOrCraftableDiscoveryPlanForTribe(sharedState.tribeID, orderContext.planState.researchTypeIndex, orderContext.planState.discoveryCraftableTypeIndex)
                        end

                        sharedState:remove("inventories", locationTypeIndex, "objects", i, "orderContext")
                    end
                end
            end
        end
    end
end

function serverSapienInventory:removeObject(sapien, locationTypeIndex)
    local sharedState = sapien.sharedState
    local inventories = sharedState.inventories

    if inventories then
        local inventory = inventories[locationTypeIndex]
        if inventory then
            local objects = inventory.objects
            
            if objects and objects[1] then
                local objectInfo = objects[#objects]
                
                local objectTypeIndex = objectInfo.objectTypeIndex

                local newCountByObjectType = inventory.countsByObjectType[objectTypeIndex] - 1
                if newCountByObjectType == 0 then
                    sharedState:remove("inventories", locationTypeIndex, "countsByObjectType", objectTypeIndex)
                else
                    sharedState:set("inventories", locationTypeIndex, "countsByObjectType", objectTypeIndex, newCountByObjectType)
                end

                sharedState:remove("inventories", locationTypeIndex, "objects", #objects)

                --table.remove(objects, 1)
                
               -- mj:log("removing object from inventory:", sharedState.inventories)
                --mj:log("removing objectInfo:", objectInfo)
              --  mj:log("current countsByThisResourse:", inventory.countsByObjectType[objectTypeIndex])

                --inventory.countsByObjectType[objectTypeIndex] = inventory.countsByObjectType[objectTypeIndex] - 1
                
                serverResourceManager:updateResourcesForObject(sapien)

                
                local orderContext = objectInfo.orderContext
                if orderContext and orderContext.planObjectID then 
                    serverSapien:removeAssignedStatusForInventoryRemoval(sapien, orderContext.planObjectID)
                end

                
                if orderContext and orderContext.planState and orderContext.planState.planTypeIndex == plan.types.research.index then
                    serverWorld:removeDiscoveryOrCraftableDiscoveryPlanForTribe(sharedState.tribeID, orderContext.planState.researchTypeIndex, orderContext.planState.discoveryCraftableTypeIndex)
                end

                sapien.privateState.iteratePlansStartIndex = nil --hack, bute we'll reset this here, as previous looks would have been for held object disposal

                return objectInfo
            end
        end
    end

    return nil
end

function serverSapienInventory:heldObjectIsForPlanObjectWithID(sapien, planObjectID)
    local sharedState = sapien.sharedState
    local inventories = sharedState.inventories

    if inventories then
        local inventory = inventories[sapienInventory.locations.held.index]
        if inventory then
            local objects = inventory.objects
            if objects then
                for i, objectInfo in ipairs(objects) do
                    local orderContext = objectInfo.orderContext
                    if orderContext then 
                        if planObjectID == orderContext.planObjectID then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function serverSapienInventory:changeLastObjectState(sapien, storageLocationTypeIndex, ...)
    local inventories = sapien.sharedState.inventories
    if inventories then
        local inventory = inventories[storageLocationTypeIndex]
        if inventory and inventory.objects and inventory.objects[1] then
            sapien.sharedState:set("inventories", storageLocationTypeIndex, "objects", #inventory.objects, ...)
        end
    end
end

function serverSapienInventory:addObject(sapien, addObject, addLocationTypeIndex, objectOrderContext)
    local objectInfo = serverGOM:getStateForAdditionToInventory(addObject)
    objectInfo.orderContext = mj:cloneTable(objectOrderContext)
    --disabled--mj:objectLog(sapien.uniqueID, "serverSapienInventory:addObject:", objectOrderContext)
    addObjectInfo(sapien, objectInfo, addLocationTypeIndex)
    sapien.privateState.iteratePlansStartIndex = nil
end

function serverSapienInventory:addObjectFromInventory(sapien, objectInfo, addLocationTypeIndex, objectOrderContext)
    objectInfo.orderContext = mj:cloneTable(objectOrderContext)
    --disabled--mj:objectLog(sapien.uniqueID, "serverSapienInventory:addObjectFromInventory:", objectOrderContext)
    addObjectInfo(sapien, objectInfo, addLocationTypeIndex)
    sapien.privateState.iteratePlansStartIndex = nil
end


function serverSapienInventory:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverSapien = initObjects.serverSapien
    serverWorld = initObjects.serverWorld
end

return serverSapienInventory