
--local notification = mjrequire "common/notification"

local serverNotifications = {}

local serverWorld = nil
local database = nil


function serverNotifications:getSapienSaveSharedStateForNotification(sapien)
    local sharedState = sapien.sharedState
    return {
        isFemale = sharedState.isFemale,
        skinColorFraction = sharedState.skinColorFraction,
        hairColorGene = sharedState.hairColorGene,
        eyeColorGene = sharedState.eyeColorGene,
        lifeStageIndex = sharedState.lifeStageIndex,
        pregnant = sharedState.pregnant,
        hasBaby = sharedState.hasBaby,
    }
end

function serverNotifications:saveNotification(object, notificationTypeIndex, userData, objectSaveData, tribeIDOrNil)
    local saveData = {
        time = serverWorld:getWorldTime(),
        notificationTypeIndex = notificationTypeIndex,
        userData = userData,
        objectSaveData = objectSaveData,
    }

    local tribeIDKey = tribeIDOrNil or "x"
    local countKey = string.format("%s_count", tribeIDKey)
    
    local currentCount = database:dataForKey(countKey) or 0
    local newCount = currentCount + 1
    local dataKey = string.format("%s_%d", tribeIDKey, newCount)

    database:setDataForKey(newCount, countKey)
    database:setDataForKey(saveData, dataKey)

    --mj:log("serverNotifications:saveNotification newCount:", newCount, " countKey:", countKey)
    --mj:log("serverNotifications:saveNotification saveData:", saveData, " dataKey:", dataKey)
    return saveData
end

function serverNotifications:getNotifications(tribeIDOrNil, startIndexOffsetOrNil)
    local tribeIDKey = tribeIDOrNil or "x"
    local countKey = string.format("%s_count", tribeIDKey)
    local currentCount = database:dataForKey(countKey) or 0

    local startIndexOffset = math.max((startIndexOffsetOrNil or 0), 0)
    local endIndex = currentCount - startIndexOffset
    --mj:log("serverNotifications:getNotifications endIndex:", endIndex, " currentCount:", currentCount, " countKey:", countKey)
    if endIndex > 0 then
        local countToUse = math.min(100, endIndex)
        local startIndex = endIndex - countToUse + 1
        local result = {}
        for i=startIndex,endIndex do
            local dataKey = string.format("%s_%d", tribeIDKey, i)
            local saveData = database:dataForKey(dataKey)
            table.insert(result, saveData)
        end
        --mj:log("serverNotifications:getNotifications startIndex:", startIndex, " result:", result)
        return result
    end


    return {}
end

function serverNotifications:init(serverWorld_)
    serverWorld = serverWorld_
    database = serverWorld:getDatabase("notifications", true)
    --loadCurrentBucketInfo(nil)
end

return serverNotifications