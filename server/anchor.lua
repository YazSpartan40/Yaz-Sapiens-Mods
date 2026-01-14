local typeMaps = mjrequire "common/typeMaps"
local destination = mjrequire "common/destination"

local anchor = {}

local serverGOM = nil
local serverDestination = nil
local serverWorld = nil

local maxPriority = 10000

anchor.types = typeMaps:createMap("anchor", {
    {
        key = "sapien",
        priority = 1,
        padded = true,
        alwaysValidForAllTribes = true,
        anchorLevel = mj.SUBDIVISIONS - 4,
        subdivLevel = mj.SUBDIVISIONS - 1,
        anchorLevelB = mj.SUBDIVISIONS - 8,
        subdivLevelB = mj.SUBDIVISIONS - 3,
    },
    {
        key = "mob",
        priority = 4,
        padded = true,
        anchorLevel = mj.SUBDIVISIONS - 3,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
    {
        key = "sapienOrderObject",
        priority = 5,
        anchorLevel = mj.SUBDIVISIONS - 1,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
    {
        key = "planObject",
        priority = 10,
        anchorLevel = mj.SUBDIVISIONS - 1,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
    {
        key = "storageArea",
        priority = 15,
        anchorLevel = mj.SUBDIVISIONS - 1,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
    {
        key = "haulObjectDestinationMarker",
        priority = 15,
        anchorLevel = mj.SUBDIVISIONS - 1,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
    {
        key = "craftArea",
        priority = 15,
        anchorLevel = mj.SUBDIVISIONS - 1,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
    {
        key = "logisticsDestination",
        priority = 15,
        anchorLevel = mj.SUBDIVISIONS - 1,
        subdivLevel = mj.SUBDIVISIONS - 1,
    },
})

local function removeAnchorStateIfNeeded(objectID)
    local object = serverGOM:getObjectWithID(objectID)
    if object then
        local privateState = object.privateState
        if privateState and privateState.anchorStatesByTribe then
            local foundAnchor = false
            for tribeID,tribeAnchorState in pairs(privateState.anchorStatesByTribe) do
                if (not tribeAnchorState.anchors) or not next(tribeAnchorState.anchors) then
                    privateState.anchorStatesByTribe[tribeID] = nil
                else
                    foundAnchor = true
                end
            end
            if not foundAnchor then
                privateState.anchorStatesByTribe = nil
                privateState.privateAnchorState = nil
                serverGOM:saveObject(objectID)
            end
        end
    end
end

local function getOrCreateAnchorStates(objectID, tribeIDOrNil)
    local object = serverGOM:getObjectWithID(objectID)
    if object then

        local privateState = serverGOM:getPrivateState(object)

        local privateAnchorState = privateState.privateAnchorState
        if not privateAnchorState then
            privateAnchorState = {}
            privateState.privateAnchorState = privateAnchorState
        end

        local anchorStatesByTribe = privateState.anchorStatesByTribe
        if not anchorStatesByTribe then
            anchorStatesByTribe = {}
            privateState.anchorStatesByTribe = anchorStatesByTribe
        end

        local tribeKey = tribeIDOrNil or "all" 
        local tribeAnchorState = anchorStatesByTribe[tribeKey]
        if not tribeAnchorState then
            tribeAnchorState = {
                anchors = {}
            }
            anchorStatesByTribe[tribeKey] = tribeAnchorState
        end

        local legacyAnchorState = privateState.anchorState --legacy migration to 0.5
        if legacyAnchorState then
            tribeAnchorState.anchors = legacyAnchorState.anchors
            tribeAnchorState.sapienOrderAnchorsBySapienID = legacyAnchorState.sapienOrderAnchorsBySapienID

            privateAnchorState.currentAnchorTypeIndex = legacyAnchorState.currentAnchorTypeIndex

            privateState.anchorState = nil
            serverGOM:saveObject(objectID)
        end

        return {
            anchorStatesByTribe = anchorStatesByTribe,
            privateAnchorState = privateAnchorState,
            tribeAnchorState = tribeAnchorState,
        }
    end
    return nil
end

local loadedAnchorObjectIDsByTribeIDs = {}

local function getIsValidAnchorTribe(tribeID, anchorType)
    if tribeID == "all" or anchorType.alwaysValidForAllTribes then
        return true
    end
    local destinationState = serverDestination:getDestinationState(tribeID)
    if not destinationState then
        return false
    end
    return (serverWorld:tribeIsValidOwner(destinationState.destinationID) or destinationState.nomad) and
    (destinationState.loadState == destination.loadStates.loaded)
end


local function updateAnchor(objectID, anchorStates)
    local newPriorityAnchorTypeIndex = nil
    local newBestPriority = maxPriority
    for tribeID, anchorState in pairs(anchorStates.anchorStatesByTribe) do
        for anchorTypeIndex,v in pairs(anchorState.anchors) do
            local anchorType = anchor.types[anchorTypeIndex]
            if anchorType.priority < newBestPriority then
                if getIsValidAnchorTribe(tribeID, anchorType) then
                    newBestPriority = anchorType.priority
                    newPriorityAnchorTypeIndex = anchorTypeIndex
                end
            end
        end
    end

    --mj:log("updateAnchor:", objectID, " newPriorityAnchorTypeIndex:", newPriorityAnchorTypeIndex, " current:",anchorStates.privateAnchorState.currentAnchorTypeIndex)

    if newPriorityAnchorTypeIndex ~= anchorStates.privateAnchorState.currentAnchorTypeIndex then
        anchorStates.privateAnchorState.currentAnchorTypeIndex = newPriorityAnchorTypeIndex

        local anchorType = anchor.types[anchorStates.privateAnchorState.currentAnchorTypeIndex]

        if newPriorityAnchorTypeIndex then
            --mj:log("serverGOM:setAnchorForObjectWithID:",objectID, " anchorType:", anchorType.key)
            serverGOM:setAnchorForObjectWithID(objectID, anchorType.padded or false, anchorType.anchorLevel, anchorType.subdivLevel, anchorType.anchorLevelB, anchorType.subdivLevelB)
        else
            --mj:log("removeAnchorForObjectWithID:",objectID)
            serverGOM:removeAnchorForObjectWithID(objectID)
        end
    end
end

function anchor:addAnchor(objectID, anchorTypeIndex, tribeIDOrNil) --this is assumed to be called on object load for all objects that have anchors, to populate anchorObjectIDsByTribeID and unload anchors when a tribe is hibernated
    local anchorStates = getOrCreateAnchorStates(objectID, tribeIDOrNil)
    --mj:log("addAnchor:", objectID, " states:", anchorStates)
    if anchorStates then
        if (not anchorStates.tribeAnchorState.anchors[anchorTypeIndex]) then
            anchorStates.tribeAnchorState.anchors[anchorTypeIndex] = true
        end

        if tribeIDOrNil then
            local anchorObjectIDsByTribeID = loadedAnchorObjectIDsByTribeIDs[tribeIDOrNil]
            if not anchorObjectIDsByTribeID then 
                anchorObjectIDsByTribeID = {}
                loadedAnchorObjectIDsByTribeIDs[tribeIDOrNil] = anchorObjectIDsByTribeID
            end
            anchorObjectIDsByTribeID[objectID] = true
        end
        updateAnchor(objectID, anchorStates)
        serverGOM:saveObject(objectID)
    end
end


function anchor:removeAnchor(objectID, anchorTypeIndex, tribeIDOrNil)
    local anchorStates = getOrCreateAnchorStates(objectID, tribeIDOrNil)
    if anchorStates and anchorStates.tribeAnchorState.anchors[anchorTypeIndex] then
        anchorStates.tribeAnchorState.anchors[anchorTypeIndex] = nil
        if tribeIDOrNil then
            if not next(anchorStates.tribeAnchorState.anchors) then
                local anchorObjectIDsByTribeID = loadedAnchorObjectIDsByTribeIDs[tribeIDOrNil]
                if anchorObjectIDsByTribeID then 
                    anchorObjectIDsByTribeID[objectID] = nil
                end
            end
        end
        updateAnchor(objectID, anchorStates)
        removeAnchorStateIfNeeded(objectID)
        serverGOM:saveObject(objectID)
    end
end


function anchor:setSapienOrderObjectAnchor(sapienID, objectID)
    local sapien = serverGOM:getObjectWithID(sapienID)
    local currentAnchorObjectID = sapien.privateState.currentAnchorObjectID
    if objectID ~= currentAnchorObjectID then
        if currentAnchorObjectID then
            anchor:removeSapienOrderObjectAnchor(sapienID)
        end

        local anchorStates = getOrCreateAnchorStates(objectID, sapien.sharedState.tribeID)
        if anchorStates then
            local sapienOrderAnchorsBySapienID = anchorStates.tribeAnchorState.sapienOrderAnchorsBySapienID
            if not anchorStates.tribeAnchorState.sapienOrderAnchorsBySapienID then
                sapienOrderAnchorsBySapienID = {}
                anchorStates.tribeAnchorState.sapienOrderAnchorsBySapienID = sapienOrderAnchorsBySapienID
                anchorStates.tribeAnchorState.anchors[anchor.types.sapienOrderObject.index] = true

                local anchorObjectIDsByTribeID = loadedAnchorObjectIDsByTribeIDs[sapien.sharedState.tribeID]
                if not anchorObjectIDsByTribeID then 
                    anchorObjectIDsByTribeID = {}
                    loadedAnchorObjectIDsByTribeIDs[sapien.sharedState.tribeID] = anchorObjectIDsByTribeID
                end
                anchorObjectIDsByTribeID[objectID] = true

                updateAnchor(objectID, anchorStates)
                serverGOM:saveObject(objectID)
            end
            if not sapienOrderAnchorsBySapienID[sapienID] then
                sapienOrderAnchorsBySapienID[sapienID] = true
                serverGOM:saveObject(objectID)
            end
        end

        sapien.privateState.currentAnchorObjectID = objectID
        serverGOM:saveObject(sapienID)
    end
end

function anchor:removeSapienOrderObjectAnchor(sapienID)
    local sapien = serverGOM:getObjectWithID(sapienID)
    if sapien then
        local currentAnchorObjectID = sapien.privateState.currentAnchorObjectID
        if currentAnchorObjectID then
            local anchorStates = getOrCreateAnchorStates(currentAnchorObjectID, sapien.sharedState.tribeID)
            if anchorStates then
                local sapienOrderAnchorsBySapienID = anchorStates.tribeAnchorState.sapienOrderAnchorsBySapienID
                if sapienOrderAnchorsBySapienID and sapienOrderAnchorsBySapienID[sapienID] then
                    sapienOrderAnchorsBySapienID[sapienID] = nil
                    if not next(sapienOrderAnchorsBySapienID) then
                        anchorStates.tribeAnchorState.sapienOrderAnchorsBySapienID = nil
                        anchor:removeAnchor(currentAnchorObjectID, anchor.types.sapienOrderObject.index, sapien.sharedState.tribeID)
                    end
                    serverGOM:saveObject(currentAnchorObjectID)
                end
            end
        end
        sapien.privateState.currentAnchorObjectID = nil
        serverGOM:saveObject(sapienID)
    end
end


function anchor:updateAnchorsForTribeLoadStateChange(tribeID)
    local anchorObjectIDsByTribeID = loadedAnchorObjectIDsByTribeIDs[tribeID]
    if anchorObjectIDsByTribeID then 
        for objectID,v in pairs(anchorObjectIDsByTribeID) do
            local anchorStates = getOrCreateAnchorStates(objectID, tribeID)
            if anchorStates then
                updateAnchor(objectID, anchorStates)
            end
        end
    end
    
end

function anchor:anchorObjectUnloaded(objectID)
    for tribeID,objectIDs in pairs(loadedAnchorObjectIDsByTribeIDs) do
        objectIDs[objectID] = nil
    end
end

function anchor:init(serverGOM_, serverWorld_, serverDestination_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    serverDestination = serverDestination_
end

return anchor