local mjm = mjrequire "common/mjm"
local terrainSuper = mjrequire "common/terrain"

local clientDestination = mjrequire "logicThread/clientDestination"
--local gameConstants = mjrequire "common/gameConstants"
--local terrainDecal = mjrequire "common/terrainDecal"

local terrain = setmetatable({}, {__index=terrainSuper})

local bridge = nil
local clientGOM = nil
local logic = nil

local currentRegisteredServerUpdateNotificationVertIDs = {}

local function retrieveVertInfoForVert(vert)

    local sharedState = vert:getSharedState()

    if sharedState and not next(sharedState) then
        sharedState = nil
    end

    local vertInfo = {
        uniqueID = vert.uniqueID,
        pos = vert.pos,
        baseType = vert.baseType,
        variations = vert:getVariations(),
        sharedState = sharedState,
        material = vert.material,
        altitude = vert.altitude
    }

    if sharedState and sharedState.modificationObjectID then
        vertInfo.planObjectInfo = clientGOM:retrieveObjectInfo(sharedState.modificationObjectID, false)
        if not vertInfo.planObjectInfo.found then
            vertInfo.planObjectInfo = nil
        end
    end

    return vertInfo
end

function terrain:retrieveVertInfo(vertID)
    local vert = terrain:getVertWithID(vertID)

    if not vert then
        return nil
    end
    
    return retrieveVertInfoForVert(vert)
end

function terrain:getVertINFOsForIDs(vertIDs)
    local result = {}
    for i, vertID in ipairs(vertIDs) do
        local vertInfo = terrain:retrieveVertInfo(vertID)
        if vertInfo then
            table.insert(result, vertInfo)
        end
    end
    return result
end

function terrain:setBridge(bridge_)
    bridge = bridge_
    terrainSuper:setBridge(bridge)
    clientDestination:setTerrain(terrain)

    bridge.modifiedVertReceivedFromServerFunction = function(vert)
        if currentRegisteredServerUpdateNotificationVertIDs[vert.uniqueID] then
            logic:callMainThreadFunction("registeredVertServerStateChanged", retrieveVertInfoForVert(vert))
        end

        if vert.offset ~= 0 then
            clientGOM:updateObjectsForModifiedOffsetVertReceivedFromServer(vert)
        end
    end
end

function terrain:setLogic(logic_, clientGOM_)
    logic = logic_
    clientGOM = clientGOM_
end

function terrain:setDecalsHiddenForVert(vert, hidden)
	bridge:setDecalsHiddenForVert(vert, hidden)
end

function terrain:setPlayerInfo(playerPos, playerHeightAboveTerrain)
    
    bridge:setPlayerInfo(playerPos, playerHeightAboveTerrain)
end

function terrain:setGrassDensity(newValue)
    newValue = mjm.clamp(newValue, 0.0, 15.0)
    local multiplier = math.pow(2.0, (newValue - 5.0) * 0.25)
    bridge:setDecalQuantityMultiplier(multiplier * 1.5)
end



function terrain:registerServerStateChangeMainThreadNotificationsForVerts(uniqueIDs)
    for i, uniqueID in ipairs(uniqueIDs) do
        
        currentRegisteredServerUpdateNotificationVertIDs[uniqueID] = true
    end
end

function terrain:deregisterServerStateChangeMainThreadNotificationsForVerts(uniqueIDs)
    for i, uniqueID in ipairs(uniqueIDs) do
        currentRegisteredServerUpdateNotificationVertIDs[uniqueID] = nil
    end
end

function terrain:objectChanged(object)
    if object.sharedState and object.sharedState.vertID then
        local vertID = object.sharedState.vertID
        if currentRegisteredServerUpdateNotificationVertIDs[vertID] then
            local vert = terrain:getVertWithID(vertID)
            if vert then
                logic:callMainThreadFunction("registeredVertServerStateChanged", retrieveVertInfoForVert(vert))
            end
        end
    end
end

function terrain:getObjectInfluencedMaxPlayerCameraHeightAboveTerrain(normalizedCameraPos)
    return bridge:getObjectInfluencedMaxPlayerCameraHeightAboveTerrain(normalizedCameraPos)
end

return terrain