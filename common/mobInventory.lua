
local typeMaps = mjrequire "common/typeMaps"

local mobInventory = {}

mobInventory.locations = typeMaps:createMap("mobInventory", {
    {
        key = "embeded",
    },
})


function mobInventory:getObjects(mobObject, storageLocationTypeIndex)
    local inventories = mobObject.sharedState.inventories
    if inventories then
        local inventory = inventories[storageLocationTypeIndex]
        if inventory and inventory.objects then
            return inventory.objects
        end
    end
    return nil
end


return mobInventory