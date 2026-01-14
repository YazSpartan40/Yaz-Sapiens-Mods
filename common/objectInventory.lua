
local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local typeMaps = mjrequire "common/typeMaps"

local objectInventory = {}

objectInventory.locations = typeMaps:createMap("objectInventory", {
    {
        key = "availableResource",
    },
    {
        key = "inUseResource",
    },
    {
        key = "tool",
    },
})


local function getMatchInfo(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    if not objectState.inventories then
        return nil
    end
    local inventory = objectState.inventories[inventoryLocation]
    
    if inventory and inventory.countsByObjectType then
        local objects = inventory.objects
        for i = #objects, 1, -1 do
            local thisObjectInfo = objects[i]
            local match = false
            if objectTypeIndexOrNil then
                match = (thisObjectInfo.objectTypeIndex == objectTypeIndexOrNil)
            elseif resourceTypeOrGroupIndexOrNil then
                match = resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndexOrNil, gameObject.types[thisObjectInfo.objectTypeIndex].resourceTypeIndex)
            else
                match = true
            end

            if match then
                return {
                    objectInfo = thisObjectInfo,
                    inventory = inventory,
                    inventoryIndex = i,
                }
            end
        end
    end
    return nil
end

local function getMatchWithRemoval(shouldRemove, objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    local matchInfo = getMatchInfo(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    if matchInfo then
        if shouldRemove then
            local newCount = matchInfo.inventory.countsByObjectType[matchInfo.objectInfo.objectTypeIndex] - 1
            if newCount == 0 then
                objectState:remove("inventories", inventoryLocation, "countsByObjectType", matchInfo.objectInfo.objectTypeIndex)
            else
                objectState:set("inventories", inventoryLocation, "countsByObjectType", matchInfo.objectInfo.objectTypeIndex, newCount)
            end
            objectState:removeFromArray("inventories", inventoryLocation, "objects", matchInfo.inventoryIndex)
        end
        return matchInfo.objectInfo
    end
    return nil
end

function objectInventory:removeAndGetInfo(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    return getMatchWithRemoval(true, objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
end


function objectInventory:getNextMatch(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    return getMatchWithRemoval(false, objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
end

function objectInventory:changeInventoryObjectState(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil, ...)
    local matchInfo = getMatchInfo(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    if matchInfo then
        --mj:log("objectInventory:changeInventoryObjectState prevState:", objectState)
        objectState:set("inventories", inventoryLocation, "objects", matchInfo.inventoryIndex, ...)
        --mj:log("objectInventory:changeInventoryObjectState newState:", objectState)
    end
end

function objectInventory:getMatchCount(objectState, inventoryLocation, objectTypeIndexOrNil, resourceTypeOrGroupIndexOrNil)
    if objectState.inventories then
        local inventory = objectState.inventories[inventoryLocation]
        
        if inventory and inventory.countsByObjectType then
            if objectTypeIndexOrNil then
                return inventory.countsByObjectType[objectTypeIndexOrNil] or 0
            end

            local matchCount = 0
            for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
                if resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndexOrNil, gameObject.types[objectTypeIndex].resourceTypeIndex) then
                    matchCount = matchCount + count
                end
            end
            return matchCount
        end
    end
    return 0
end

function objectInventory:getTotalCount(objectState, inventoryLocation)
    if objectState.inventories then
        local inventory = objectState.inventories[inventoryLocation]
        
        if inventory and inventory.objects then
            return #inventory.objects
        end
    end

    return 0
end

function objectInventory:moveNextResourceFromAvailableToInUse(objectState, requiredResources)
    --mj:log("objectInventory:moveNextResourceFromAvailableToInUse")
    local inventories = objectState.inventories
    if not inventories then
        mj:warn("no inventories in build object:", objectState, " requiredResources:", requiredResources)
        return
    end

    local availableResourceInventory = inventories[objectInventory.locations.availableResource.index]
    
    if availableResourceInventory and availableResourceInventory.countsByObjectType then
        local availableResourceObjects = availableResourceInventory.objects
        
        for r,resourceInfo in ipairs(requiredResources) do
            local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group

            for i = #availableResourceObjects, 1, -1 do
                local thisObjectInfo = availableResourceObjects[i]
                local match = resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndex, gameObject.types[thisObjectInfo.objectTypeIndex].resourceTypeIndex)

                if match then
                    
                    local newCountByObjectType = availableResourceInventory.countsByObjectType[thisObjectInfo.objectTypeIndex] - 1
                    if newCountByObjectType == 0 then
                        objectState:remove("inventories", objectInventory.locations.availableResource.index, "countsByObjectType", thisObjectInfo.objectTypeIndex)
                    else
                        objectState:set("inventories", objectInventory.locations.availableResource.index, "countsByObjectType", thisObjectInfo.objectTypeIndex, newCountByObjectType)
                    end

                    objectState:removeFromArray("inventories", objectInventory.locations.availableResource.index, "objects", i)
                    
                    local inUseResourceInventory = objectState.inventories[objectInventory.locations.inUseResource.index]
                    local newCount = 1
                    if inUseResourceInventory and inUseResourceInventory.countsByObjectType and inUseResourceInventory.countsByObjectType[thisObjectInfo.objectTypeIndex] then
                        newCount = inUseResourceInventory.countsByObjectType[thisObjectInfo.objectTypeIndex] + 1
                    end

                    local newIndex = 1
                    if inUseResourceInventory and inUseResourceInventory.objects then
                        newIndex = #inUseResourceInventory.objects + 1
                    end

                    objectState:set("inventories", objectInventory.locations.inUseResource.index, "countsByObjectType", thisObjectInfo.objectTypeIndex, newCount)
                    objectState:set("inventories", objectInventory.locations.inUseResource.index, "objects", newIndex, thisObjectInfo)

                    return thisObjectInfo
                end
            end
        end
    end
    return nil
end

function objectInventory:moveNextResourceFromInUseToAvailable(objectState, requiredResources)
    local inUseInventory = objectState.inventories[objectInventory.locations.inUseResource.index]
    
    if inUseInventory and inUseInventory.countsByObjectType then
        local inUseResourceObjects = inUseInventory.objects
        
        for r=#requiredResources,1,-1 do
            local resourceInfo = requiredResources[r]
            local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group

            for i = #inUseResourceObjects, 1, -1 do
                local thisObjectInfo = inUseResourceObjects[i]
                local match = resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndex, gameObject.types[thisObjectInfo.objectTypeIndex].resourceTypeIndex)

                if match then
                    
                    local newCountByObjectType = inUseInventory.countsByObjectType[thisObjectInfo.objectTypeIndex] - 1
                    if newCountByObjectType == 0 then
                        objectState:remove("inventories", objectInventory.locations.inUseResource.index, "countsByObjectType", thisObjectInfo.objectTypeIndex)
                    else
                        objectState:set("inventories", objectInventory.locations.inUseResource.index, "countsByObjectType", thisObjectInfo.objectTypeIndex, newCountByObjectType)
                    end

                    objectState:removeFromArray("inventories", objectInventory.locations.inUseResource.index, "objects", i)
                    
                    local availableInventory = objectState.inventories[objectInventory.locations.availableResource.index]
                    local newCount = 1
                    if availableInventory and availableInventory.countsByObjectType and availableInventory.countsByObjectType[thisObjectInfo.objectTypeIndex] then
                        newCount = availableInventory.countsByObjectType[thisObjectInfo.objectTypeIndex] + 1
                    end

                    local newIndex = 1
                    if availableInventory and availableInventory.objects then
                        newIndex = #availableInventory.objects + 1
                    end

                    objectState:set("inventories", objectInventory.locations.availableResource.index, "countsByObjectType", thisObjectInfo.objectTypeIndex, newCount)
                    objectState:set("inventories", objectInventory.locations.availableResource.index, "objects", newIndex, thisObjectInfo)

                    return thisObjectInfo
                end
            end
        end
    end
    return nil
end

return objectInventory