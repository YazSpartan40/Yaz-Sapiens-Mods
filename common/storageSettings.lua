local storageSettings = {}

function storageSettings:getSettingsTribeIDToUse(storageAreaSharedState, localTribeID, tribeRelationsSettings)
    if (not tribeRelationsSettings) then
        return localTribeID
    end

    local bestTribeID = nil
    if tribeRelationsSettings and next(tribeRelationsSettings) and storageAreaSharedState.settingsByTribe then
        for tribeID,settings in pairs(storageAreaSharedState.settingsByTribe) do
            local isAlly = (tribeID == localTribeID) or (tribeRelationsSettings[tribeID] and tribeRelationsSettings[tribeID].storageAlly)
            if isAlly then
                if tribeID == storageAreaSharedState.tribeID then
                    return tribeID
                end
                if not bestTribeID or bestTribeID < tribeID then
                    bestTribeID = tribeID
                end
            end
        end
    end

    if bestTribeID then
        return bestTribeID
    end

    return localTribeID
end

return storageSettings