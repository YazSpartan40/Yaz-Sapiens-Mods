
local typeMaps = mjrequire "common/typeMaps"

local sapienInventory = {}

sapienInventory.locations = typeMaps:createMap("sapienInventory", {
    {
        key = "held",
    },
    {
        key = "belt",
    },
    {
        key = "back",
    },
    {
        key = "head",
    },
    {
        key = "torso",
    },
    {
        key = "legs",
    },
    {
        key = "feet",
    },
})

function sapienInventory:objectCount(sapien, storageLocationTypeIndex)
    local inventories = sapien.sharedState.inventories
    if inventories then
        local inventory = inventories[storageLocationTypeIndex]
        if inventory and inventory.objects then
            return #inventory.objects
        end
    end
    return 0
end

function sapienInventory:lastObjectInfo(sapien, storageLocationTypeIndex)
    local inventories = sapien.sharedState.inventories
    if inventories then
        local inventory = inventories[storageLocationTypeIndex]
        if inventory and inventory.objects and inventory.objects[1] then
            return inventory.objects[#inventory.objects]
        end
    end
    return nil
end

function sapienInventory:getObjects(sapien, storageLocationTypeIndex)
    local inventories = sapien.sharedState.inventories
    if inventories then
        local inventory = inventories[storageLocationTypeIndex]
        if inventory and inventory.objects then
            return inventory.objects
        end
    end
    return nil
end

return sapienInventory