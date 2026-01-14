
local gameObject = mjrequire "common/gameObject"
--local locale = mjrequire "common/locale"
local storage = mjrequire "common/storage"
--local constructable = mjrequire "common/constructable"

local logisticsUIHelper = {}


function logisticsUIHelper:getLogisticsObjectNameText(objectName, objectTypeIndex, contentsCount, contentsStorageTypeIndex)
    local result = nil

    if objectName then
        result = objectName
    else
        result = gameObject.types[objectTypeIndex].name
    end

    local objectCountToDisplay = 0
    if contentsStorageTypeIndex and contentsStorageTypeIndex > 0 then
        result = result .. " - " .. storage.types[contentsStorageTypeIndex].name

        if contentsCount and contentsCount > 0 then
            objectCountToDisplay = contentsCount or 0
        end
    end

    result = result .. " (" .. mj:tostring(objectCountToDisplay) .. ")"
    return result
end
--[[
function logisticsUIHelper:getLogisticsObjectNameTextFromInfo(objectInfo, tribeID) --legacy
    local baseName = ""
    if objectInfo.name then
        baseName = baseName .. " " .. objectInfo.name
    end

    local function getStorageTypeIndex()
        if objectInfo.contentsStorageTypeIndex then
            return objectInfo.contentsStorageTypeIndex
        end
        if objectInfo.settingsByTribe then
            local tribeSettings = objectInfo.settingsByTribe[tribeID]
            if tribeSettings then
                local restrictStorageTypeIndex = tribeSettings.restrictStorageTypeIndex
                if restrictStorageTypeIndex and restrictStorageTypeIndex > 0 then
                    return restrictStorageTypeIndex
                end
            end
        end
        return 0
    end

    local storageTypeIndex = getStorageTypeIndex()

    if storageTypeIndex > 0 then
        local count = 0
        if objectInfo.objectCount then
            count = objectInfo.objectCount
        end

        if count > 0 then
            return baseName .. storage.types[storageTypeIndex].name .. " (" .. mj:tostring(count) .. ")"
        end

        return baseName .. storage.types[storageTypeIndex].name .. " (" .. locale:get("misc_Empty") .. ")"
    end
        
    return baseName .. "(" .. locale:get("misc_Empty") .. ")"
end]]

return logisticsUIHelper