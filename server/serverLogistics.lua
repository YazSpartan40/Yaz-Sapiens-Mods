local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local gameObject = mjrequire "common/gameObject"
local gameConstants = mjrequire "common/gameConstants"
local anchor = mjrequire "server/anchor"


local serverLogistics = {}
serverLogistics.minDistanceToUnloadSleds2 = mj:mToP(4.0) * mj:mToP(4.0)

local serverWorld = nil
local serverSapien = nil
local serverGOM = nil
local serverStorageArea = nil
--local serverCraftArea = nil

local routeSegmentDestinationsBySourceObjectIDThenTribeID = {}
local routeSegmentSourceObjectsByDestinationObjects = {}
local routeAssignmentCountsByTribeID = {}
local routeAssignmentSapienIDsByTribeID = {}
local routeAssignmentsBySapienID = {}

local function getRouteAssignmentKey(tribeID, routeID)
    return string.format("%s_%d", tribeID or "x", routeID or 0)
end

local function updateMaintenceRequired(sourceObjectID)
    local sourceObject = serverGOM:getObjectWithID(sourceObjectID)
    if sourceObject then
        if gameObject.types[sourceObject.objectTypeIndex].isStorageArea then
            --mj:log("updateMaintenceRequired:", sourceObjectID)
            serverStorageArea:updateMaintenanceRequired(sourceObject)
        end
    end
end

local function getAllStorageAllyTribeDestinationInfos(sapienTribeID, storageAreaTribeID, destinationsByTribeID)
    local result = {}
    if destinationsByTribeID then
        for tribeID,destinationInfos in pairs(destinationsByTribeID) do
            if tribeID == sapienTribeID then
                for i,destinationInfo in ipairs(destinationInfos) do
                    if not result[tribeID] then
                        result[tribeID] = {}
                    end
                    table.insert(result[tribeID], destinationInfo)
                end
            else
                local globalTribeSettings = serverWorld:getTribeRelationsSettings(tribeID, sapienTribeID)
                --mj:log("globalTribeSettings:", globalTribeSettings)
                if globalTribeSettings and globalTribeSettings.storageAlly then
                    for i,destinationInfo in ipairs(destinationInfos) do
                        if not result[tribeID] then
                            result[tribeID] = {}
                        end
                        table.insert(result[tribeID], destinationInfo)
                    end
                end
            end
        end
    end

    --mj:log("getAllStorageAllyTribeDestinationInfos:", result)
    return result
end

local function addPair(tribeID, routeID, sourceObjectID, destinationObjectID)
    local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[sourceObjectID]
    if not destinationsBySourceID then
        destinationsBySourceID = {}
        routeSegmentDestinationsBySourceObjectIDThenTribeID[sourceObjectID] = destinationsBySourceID
    end
    local destinationsByTribeID = destinationsBySourceID[tribeID]
    if not destinationsByTribeID then
        destinationsByTribeID = {}
        destinationsBySourceID[tribeID] = destinationsByTribeID
    end

    local destinationInfoToAdd = {
        routeID = routeID,
        destinationID = destinationObjectID
    }
    table.insert(destinationsByTribeID, destinationInfoToAdd)

    local routeSegmentSourceObjects = routeSegmentSourceObjectsByDestinationObjects[destinationObjectID]
    if not routeSegmentSourceObjects then
        routeSegmentSourceObjects = {}
        routeSegmentSourceObjectsByDestinationObjects[destinationObjectID] = routeSegmentSourceObjects
    end
    table.insert(routeSegmentSourceObjects, sourceObjectID)

end

local function removePair(tribeID, routeID, sourceObjectID, destinationObjectID)
    local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[sourceObjectID]
    if destinationsBySourceID then
        local destinationsByTribeID = destinationsBySourceID[tribeID]
        if destinationsByTribeID then
            for i,destinationInfo in ipairs(destinationsByTribeID) do
                if destinationInfo.routeID == routeID and destinationInfo.destinationID == destinationObjectID then
                    table.remove(destinationsByTribeID, i)
                    if not destinationsByTribeID[1] then
                        destinationsBySourceID[tribeID] = nil
                        if not next(destinationsBySourceID) then
                            routeSegmentDestinationsBySourceObjectIDThenTribeID[sourceObjectID] = nil
                        end
                    end
                    break
                end
            end
        end
    end

    local routeSegmentSourceObjects = routeSegmentSourceObjectsByDestinationObjects[destinationObjectID]
    if routeSegmentSourceObjects then
        for i,foundSourceObjectID in ipairs(routeSegmentSourceObjects) do
            if foundSourceObjectID == sourceObjectID then
                table.remove(routeSegmentSourceObjects, i)
                if not routeSegmentSourceObjects[1] then
                    routeSegmentSourceObjectsByDestinationObjects[destinationObjectID] = nil
                end
                break
            end
        end
    end
end

--[[
############################## legacy data example ##############################

9.997742:logisticsRoutesData:{
    routeIDCounter = 20,
    routes = {
        [7] = {
            name = Route 7,
            destinations = {
                [1] = {
                    uniqueID = 4f4b5,
                },
                [2] = {
                    uniqueID = 2122d5,
                },
                [3] = {
                    uniqueID = 218eb5,
                },
                [4] = {
                    uniqueID = 1cdb0f5,
                },
            },
        },
        [10] = {
            name = Route 10,
            destinations = {
            },
        },
        [17] = {
            name = Route 17,
            destinations = {
                [1] = {
                    uniqueID = 1cdb115,
                },
                [2] = {
                    uniqueID = 1cdb015,
                },
            },
        },
    },
}
]]

serverLogistics.logisticsRoutesDataVersion = 2

local checkedForLoadTribes = {}

function serverLogistics:loadClientTribe(tribeID, logisticsRoutesData)
    --mj:log("loadClientTribe:", tribeID, " logisticsRoutesData:", logisticsRoutesData)
    if not checkedForLoadTribes[tribeID] then
        checkedForLoadTribes[tribeID] = true
        if logisticsRoutesData and logisticsRoutesData.routes then
            
            if (not logisticsRoutesData.version) or (logisticsRoutesData.version < serverLogistics.logisticsRoutesDataVersion) then
                logisticsRoutesData.version = serverLogistics.logisticsRoutesDataVersion
                local newRoutes = {}
                for routeID,routeInfo in pairs(logisticsRoutesData.routes) do
                    local destinations = routeInfo.destinations
                    if destinations and destinations[1] and destinations[2] then
                        for i=1,#destinations - 1 do
                            local newRouteID = logisticsRoutesData.routeIDCounter + 1
                            logisticsRoutesData.routeIDCounter = newRouteID
                            newRoutes[newRouteID] = {
                                from = destinations[i].uniqueID,
                                to = destinations[i+1].uniqueID
                            }
                            anchor:addAnchor(newRoutes[newRouteID].from, anchor.types.logisticsDestination.index, tribeID)
                            anchor:addAnchor(newRoutes[newRouteID].to, anchor.types.logisticsDestination.index, tribeID)
                        end
                    end
                end
                logisticsRoutesData.routes = newRoutes
                --mj:log("migrated routes to logisticsRoutesDataVersion:", serverLogistics.logisticsRoutesDataVersion)
            end


            for routeID,routeInfo in pairs(logisticsRoutesData.routes) do
                if routeInfo.from and routeInfo.to then
                    --mj:log("add pair tribeID:", tribeID, " from:", routeInfo.from, " -> ", routeInfo.to)
                    addPair(tribeID, routeID, routeInfo.from, routeInfo.to)
                else
                    --mj:log("bad route, setting to nil:", routeInfo)
                    logisticsRoutesData.routes[routeID] = nil
                end
            end
        end
    end
    --mj:log("serverLogistics:clientStateLoaded:", routeSegmentDestinationsBySourceObjectIDThenTribeID)
end

local function removeAnchorForObjectIfNeeded(tribeID, objectID, logisticsRoutesData)
    if logisticsRoutesData and logisticsRoutesData.routes then
        local found = false
        for routeID,routeInfo in pairs(logisticsRoutesData.routes) do
            if routeInfo.from == objectID or routeInfo.to == objectID then
                found = true
                break
            end
        end

        if not found then
            anchor:removeAnchor(objectID, anchor.types.logisticsDestination.index, tribeID)
        end
    end
end

function serverLogistics:logisticsRouteDestinationAdded(tribeID, routeID, sourceObjectID, destinationObjectID)
    if sourceObjectID and destinationObjectID and sourceObjectID ~= destinationObjectID then
        addPair(tribeID, routeID, sourceObjectID, destinationObjectID)
        anchor:addAnchor(sourceObjectID, anchor.types.logisticsDestination.index, tribeID)
        anchor:addAnchor(destinationObjectID, anchor.types.logisticsDestination.index, tribeID)
        updateMaintenceRequired(sourceObjectID)
        updateMaintenceRequired(destinationObjectID)
    end
end

function serverLogistics:updateRoutesForStorageAreaRemoval(removedObjectID) --very brute force, could be slow, optimized
    local clientStates = serverWorld:getClientStates()
    for clientID,clientState in pairs(clientStates) do
        local clientStateChanged = false
        local privateSharedState = clientState.privateShared
        if privateSharedState then
            local logisticsRoutes = privateSharedState.logisticsRoutes
            if logisticsRoutes then
                local routes = logisticsRoutes.routes
                if routes then
                    for routeID,routeInfo in pairs(routes) do
                        if routeInfo.from == removedObjectID or routeInfo.to == removedObjectID then
                            --mj:debug("serverLogistics:updateRoutesForStorageAreaRemoval:", routeInfo)
                            routes[routeID] = nil
                            clientStateChanged = true
                            removePair(privateSharedState.tribeID, routeID, routeInfo.from, routeInfo.to)
                            updateMaintenceRequired(routeInfo.from)
                            updateMaintenceRequired(routeInfo.to)
                        end
                    end
                end
            end
        end
        if clientStateChanged then
            serverWorld:saveAndSendLogisticsChange(clientID)
        end
    end
end

function serverLogistics:updateMaintenceRequiredForConnectedObjects(sourceObjectID)
    
    --mj:log("serverLogistics:updateMaintenceRequiredForConnectedObjects:", sourceObjectID)
    updateMaintenceRequired(sourceObjectID)
    local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[sourceObjectID]
    if destinationsBySourceID then
        for tribeID, destinationsByTribeID in pairs(destinationsBySourceID) do
            for i,destinationInfo in ipairs(destinationsByTribeID) do
                updateMaintenceRequired(destinationInfo.destinationID)
            end
        end
    end

    local routeSegmentSourceObjects = routeSegmentSourceObjectsByDestinationObjects[sourceObjectID]
    if routeSegmentSourceObjects then
        for i,foundSourceObjectID in ipairs(routeSegmentSourceObjects) do
            updateMaintenceRequired(foundSourceObjectID)
        end
    end
end

function serverLogistics:updateMaintenceRequiredForRoute(route)
    updateMaintenceRequired(route.from)
    updateMaintenceRequired(route.to)
end

function serverLogistics:updateMaintenceRequiredForRouteID(tribeID, routeID)
    local logisticsRoute = serverWorld:getLogisticsRoute(tribeID, routeID)
    if logisticsRoute then
        serverLogistics:updateMaintenceRequiredForRoute(logisticsRoute)
    end
end

function serverLogistics:routeWasRemoved(tribeID, routeID, removedRouteInfo)
    removePair(tribeID, routeID, removedRouteInfo.from, removedRouteInfo.to)
    updateMaintenceRequired(removedRouteInfo.from)
    updateMaintenceRequired(removedRouteInfo.to)

    for sapienID,assignedRouteInfo in pairs(routeAssignmentsBySapienID) do
        if assignedRouteInfo.tribeID == tribeID and assignedRouteInfo.routeID == routeID then
            local sapien = serverGOM:getObjectWithID(sapienID)
            if sapien then
                serverSapien:cancelAllOrders(sapien, false, false)
            end
        end
    end

    local clientID = serverWorld:clientIDForTribeID(tribeID)
    if clientID then
        local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
        removeAnchorForObjectIfNeeded(tribeID, removedRouteInfo.from, privateSharedState.logisticsRoutes)
        removeAnchorForObjectIfNeeded(tribeID, removedRouteInfo.to, privateSharedState.logisticsRoutes)
    end

    --mj:log("after routeSegmentDestinationsBySourceObjectIDThenTribeID:", routeSegmentDestinationsBySourceObjectIDThenTribeID)
   -- mj:log("after routeSegmentSourceObjectsByDestinationObjects:", routeSegmentSourceObjectsByDestinationObjects)
    --serverLogistics:updateMaintenceRequiredForRoute(removedRouteInfo)
end

function serverLogistics:routeWasDisabled(tribeID, routeID)
    for sapienID,assignedRouteInfo in pairs(routeAssignmentsBySapienID) do
        if assignedRouteInfo.tribeID == tribeID and assignedRouteInfo.routeID == routeID then
            local sapien = serverGOM:getObjectWithID(sapienID)
            if sapien then
                serverSapien:cancelAllOrders(sapien, false, false)
            end
        end
    end
end


local maxDistanceFromSourceThatWeWillTurnBackToPickupMore = mj:mToP(20.0)
local maxDistanceFromSourceThatWeWillTurnBackToPickupMore2 = maxDistanceFromSourceThatWeWillTurnBackToPickupMore * maxDistanceFromSourceThatWeWillTurnBackToPickupMore

--todo should probably check if the object has a manual haul/move order and return no
function serverLogistics:getDestinationIfObjectRequiresHaul(tribeID, object) --haul means moving a storage area eg. sled, canoe, pack animal
    if gameObject.types[object.objectTypeIndex].isMoveableStorage then

        local routeSegmentSourceObjects = routeSegmentSourceObjectsByDestinationObjects[object.uniqueID]

        local objectNonEmpty = false
        local haulObjectCountsByObjectType = serverStorageArea:availableCountsByObjectType(object.uniqueID, tribeID)
        
        if haulObjectCountsByObjectType then
            for t,count in pairs(haulObjectCountsByObjectType) do
                if count > 0 then
                    objectNonEmpty = true
                    break
                end
            end
        end
        --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul haulObjectCountsByObjectType:", haulObjectCountsByObjectType, " objectNonEmpty:", objectNonEmpty)
        

        local function getSourceObjectIfMoreToPickUp()
            if routeSegmentSourceObjects then
                --disabled--mj:objectLog(object.uniqueID, "routeSegmentSourceObjects:", routeSegmentSourceObjects)
                for i,foundSourceObjectID in ipairs(routeSegmentSourceObjects) do
                    local validSource = false
                    local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[foundSourceObjectID]
                    if destinationsBySourceID then
                        local validDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, destinationsBySourceID)
                        for routeTribeID, destinations in pairs(validDestinationsBySourceID) do
                            for j,destinationInfo in ipairs(destinations) do
                                if destinationInfo.destinationID == object.uniqueID then
                                    validSource = true
                                    break
                                end
                            end
                        end
                    end

                    if validSource then
                        local sourceObject = serverGOM:getObjectWithID(foundSourceObjectID)
                        --disabled--mj:objectLog(object.uniqueID, "validSource:", sourceObject)
                        if sourceObject and (not gameObject.types[sourceObject.objectTypeIndex].isMoveableStorage) then --don't drag sleds both ways if two in a row, take the source to the destination only.
                            local sourceObjectCountsByObjectType = serverStorageArea:availableCountsByObjectType(sourceObject.uniqueID, tribeID)
                            if sourceObjectCountsByObjectType then
                                --disabled--mj:objectLog(object.uniqueID, "sourceObjectCountsByObjectType:", sourceObjectCountsByObjectType)
                                for sourceObjectTypeIndex,count in pairs(sourceObjectCountsByObjectType) do
                                    if count > 0 then
                                        local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(object.uniqueID, sourceObjectTypeIndex, tribeID)
                                        if matchInfo then
                                            
                                            local sledHasDestinations = false
                                            local foundDestinationForThisObjectTypeIndexMaxItems = 0
                                            local sledDestinationsBySourceIDThenTribeID = routeSegmentDestinationsBySourceObjectIDThenTribeID[object.uniqueID]
                                            if sledDestinationsBySourceIDThenTribeID then
                                                local validDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, sledDestinationsBySourceIDThenTribeID)
                                                for routeTribeID, sledDestinationsByTribeID in pairs(validDestinationsBySourceID) do
                                                    if next(sledDestinationsByTribeID) then
                                                        sledHasDestinations = true
                                                        local inventoryResourceTypeIndex = gameObject.types[sourceObjectTypeIndex].resourceTypeIndex
                                                        for j,sledDestinationInfo in ipairs(sledDestinationsByTribeID) do
                                                            local sledDestinationMatchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(sledDestinationInfo.destinationID, sourceObjectTypeIndex, tribeID, {
                                                                allowTradeRequestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                                allowQuestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                            })
                                                            if sledDestinationMatchInfo then
                                                                foundDestinationForThisObjectTypeIndexMaxItems = foundDestinationForThisObjectTypeIndexMaxItems + sledDestinationMatchInfo.maxItems
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            if (not sledHasDestinations) or (sledHasDestinations and foundDestinationForThisObjectTypeIndexMaxItems > 0) then
                                                return sourceObject
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return nil
        end
        
        local sourceObjectIfRequiresPickup = getSourceObjectIfMoreToPickUp()

        if objectNonEmpty then

            local distance2ToRequiresPickupSourceObject = nil
            if sourceObjectIfRequiresPickup then
                distance2ToRequiresPickupSourceObject = length2(object.pos - sourceObjectIfRequiresPickup.pos)
            end

            local closestDestinationObject = nil
            local closestDestinationObjectDistance2 = 99

            local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[object.uniqueID]
            if destinationsBySourceID then
                local validDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, destinationsBySourceID)
                for routeTribeID, destinations in pairs(validDestinationsBySourceID) do
                    for i,destinationInfo in ipairs(destinations) do
                        local destinationObject = serverGOM:getObjectWithID(destinationInfo.destinationID)
                        if destinationObject then
                            for sledContentsObjectTypeIndex,sledContentsObjectCount in pairs(haulObjectCountsByObjectType) do
                                if sledContentsObjectCount > 0 then
                                    local inventoryResourceTypeIndex = gameObject.types[sledContentsObjectTypeIndex].resourceTypeIndex
                                    local destinationMatchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(destinationInfo.destinationID, sledContentsObjectTypeIndex, tribeID, {
                                        allowTradeRequestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                        allowQuestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                    })

                                    ----disabled--mj:objectLog(object.uniqueID, "destinationMatchInfo:", destinationMatchInfo)

                                    if destinationMatchInfo then
                                        local destinationDistance2 = length2(object.pos - destinationObject.pos)
                                        if destinationDistance2 < closestDestinationObjectDistance2 then
                                            closestDestinationObject = destinationObject
                                            closestDestinationObjectDistance2 = destinationDistance2
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                    
            end
                    
            if closestDestinationObject then

                if closestDestinationObjectDistance2 > serverLogistics.minDistanceToUnloadSleds2 then
                    if (not distance2ToRequiresPickupSourceObject) or distance2ToRequiresPickupSourceObject > maxDistanceFromSourceThatWeWillTurnBackToPickupMore2 then
                        --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul returning closestDestinationObject:", closestDestinationObject.uniqueID)
                        return closestDestinationObject
                    elseif distance2ToRequiresPickupSourceObject > serverLogistics.minDistanceToUnloadSleds2 then
                        --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul (non empty) returning  sourceObject as destination")
                        return sourceObjectIfRequiresPickup
                    end
                end

                --return destinationObject
            elseif sourceObjectIfRequiresPickup then
                if length2(object.pos - sourceObjectIfRequiresPickup.pos) > serverLogistics.minDistanceToUnloadSleds2 then
                    --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul (non empty) returning  sourceObject as destination")
                    return sourceObjectIfRequiresPickup
                end
            end
            

            --[[--disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul returning (non empty) sourceObject as destination:", sourceObjectIfRequiresPickup)
            if sourceObjectIfRequiresPickup and distance2ToRequiresPickupSourceObject > serverLogistics.minDistanceToUnloadSleds2 then
                return sourceObjectIfRequiresPickup
            end]]
        else
            --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul haul object is empty")
            if sourceObjectIfRequiresPickup then
                if length2(object.pos - sourceObjectIfRequiresPickup.pos) > serverLogistics.minDistanceToUnloadSleds2 then
                    --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul (empty) returning  sourceObject as destination")
                    return sourceObjectIfRequiresPickup
                end
            end
        end 
    end
    --disabled--mj:objectLog(object.uniqueID, "serverLogistics:getDestinationIfObjectRequiresHaul returning nil")
    return nil
end

function serverLogistics:objectRequiresPickup(tribeID, object, restrictRouteIDOrNil, sapienIDOrNilForAny)
    ----disabled--mj:objectLog(object.uniqueID, "in serverLogistics:objectRequiresPickup tribeID:", tribeID, " object:", object.uniqueID)
    if gameObject.types[object.objectTypeIndex].isStorageArea then
        local countsByObjectType = serverStorageArea:availableCountsByObjectType(object.uniqueID, tribeID)
        --disabled--mj:objectLog(object.uniqueID, "countsByObjectType:", countsByObjectType)
        if countsByObjectType then
            local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[object.uniqueID]
            if destinationsBySourceID then
                local validDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, destinationsBySourceID)
                --disabled--mj:objectLog(object.uniqueID, "destinationsBySourceID:", destinationsBySourceID, " validDestinationsBySourceID:", validDestinationsBySourceID)
                for routeTribeID, destinations in pairs(validDestinationsBySourceID) do
                    for i,destinationInfo in ipairs(destinations) do
                        if (not restrictRouteIDOrNil) or destinationInfo.routeID == restrictRouteIDOrNil then
                            --disabled--mj:objectLog(object.uniqueID, "destinationInfo.destinationIndex:", destinationInfo.destinationIndex)
                            for objectTypeIndex,count in pairs(countsByObjectType) do
                                if count > 0 then
                                    local aboveMaxLimit = false
                                    --if sapienIDOrNilForAny then
                                       -- aboveMaxLimit = serverLogistics:sapienAssignedCountHasReachedMaxForRoute(tribeID, destinationInfo.routeID, sapienIDOrNilForAny)
                                        ----disabled--mj:objectLog(object.uniqueID, "aboveMaxLimit:", aboveMaxLimit)
                                    --end
                                    if (not aboveMaxLimit) then

                                        local destinationObject = serverGOM:getObjectWithID(destinationInfo.destinationID)
                                        if destinationObject then
                                            local requiresHaul = false

                                            if gameObject.types[object.objectTypeIndex].isMoveableStorage or gameObject.types[destinationObject.objectTypeIndex].isMoveableStorage then
                                                if length2(object.pos - destinationObject.pos) > serverLogistics.minDistanceToUnloadSleds2 then
                                                    requiresHaul = true
                                                else
                                                    if gameObject.types[object.objectTypeIndex].isMoveableStorage then
                                                        requiresHaul = serverLogistics:getDestinationIfObjectRequiresHaul(tribeID, object) ~= nil
                                                    end
                                                    if not requiresHaul then
                                                        if gameObject.types[destinationObject.objectTypeIndex].isMoveableStorage then
                                                            requiresHaul = serverLogistics:getDestinationIfObjectRequiresHaul(tribeID, destinationObject) ~= nil
                                                        end
                                                    end
                                                end
                                            end
                                            --[[if gameObject.types[object.objectTypeIndex].isMoveableStorage then
                                                requiresHaul = true
                                                local destinationObject = serverGOM:getObjectWithID(destinationInfo.destinationID)
                                                if destinationObject then
                                                    if length2(object.pos - destinationObject.pos) <= serverLogistics.minDistanceToUnloadSleds2 then
                                                        requiresHaul = false
                                                    end
                                                end
                                            end]]

                                           --disabled--mj:objectLog(object.uniqueID, "serverLogistics:objectRequiresPickup requiresHaul:", requiresHaul)
                                            
                                            if (not requiresHaul) then
                                                local inventoryResourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                                                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(destinationInfo.destinationID, objectTypeIndex, tribeID, {
                                                    allowTradeRequestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                    allowQuestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                })
                                                --disabled--mj:objectLog(object.uniqueID, "matchInfo:", matchInfo, " destinationInfo.destinationID:", destinationInfo.destinationID, " objectTypeIndex:", objectTypeIndex)
                                                if matchInfo then
                                                    if gameObject.types[destinationObject.objectTypeIndex].isMoveableStorage then
                                                        local sledHasDestinations = false
                                                        local foundDestinationForThisObjectTypeIndexMaxItems = 0
                                                        local sledDestinationsBySourceIDThenTribeID = routeSegmentDestinationsBySourceObjectIDThenTribeID[destinationObject.uniqueID]
                                                        if sledDestinationsBySourceIDThenTribeID then
                                                            local sledValidDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, sledDestinationsBySourceIDThenTribeID)
                                                            for sledTribeID, sledDestinationsByTribeID in pairs(sledValidDestinationsBySourceID) do
                                                                if next(sledDestinationsByTribeID) then
                                                                    sledHasDestinations = true
                                                                    for j,sledDestinationInfo in ipairs(sledDestinationsByTribeID) do
                                                                        local sledDestinationMatchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(sledDestinationInfo.destinationID, objectTypeIndex, tribeID, {
                                                                            allowTradeRequestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                                            allowQuestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                                        })
                                                                        if sledDestinationMatchInfo then
                                                                            foundDestinationForThisObjectTypeIndexMaxItems = foundDestinationForThisObjectTypeIndexMaxItems + sledDestinationMatchInfo.maxItems
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                        if sledHasDestinations then
                                                            if foundDestinationForThisObjectTypeIndexMaxItems == 0 then
                                                                ----disabled--mj:objectLog(object.uniqueID, "return false a")
                                                                return false
                                                            end
                                                        end
                                                    end

                                                    ----disabled--mj:objectLog(object.uniqueID, "return true")
                                                    return true
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    ----disabled--mj:objectLog(object.uniqueID, "return false")
    return false
end

function serverLogistics:transferInfoIfRequiresPickupOrHaul(tribeID, object, sapienIDOrNil)
    --disabled--mj:objectLog(object.uniqueID, "in serverLogistics:transferInfoIfRequiresPickupOrHaul tribeID:", tribeID)
    if gameObject.types[object.objectTypeIndex].isStorageArea then
        local countsByObjectType = serverStorageArea:availableCountsByObjectType(object.uniqueID,tribeID)
        if countsByObjectType then
            ----disabled--mj:objectLog(object.uniqueID, "countsByObjectType:", countsByObjectType)

            local destinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[object.uniqueID]
            if destinationsBySourceID then
                local validDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, destinationsBySourceID)
                for routeTribeID, destinations in pairs(validDestinationsBySourceID) do
                    for i,destinationInfo in ipairs(destinations) do
                        for objectTypeIndex,count in pairs(countsByObjectType) do
                            if count > 0 then
                                local inventoryResourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(destinationInfo.destinationID, objectTypeIndex, tribeID, {
                                    allowTradeRequestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                    allowQuestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                })
                                if matchInfo then
                                    --if is sled, check if it has any destinations, if so, only allow those which the destinations want
                                    local destinationObject = serverGOM:getObjectWithID(destinationInfo.destinationID)
                                    if gameObject.types[destinationObject.objectTypeIndex].isMoveableStorage then
                                        local sledHasDestinations = false
                                        local foundDestinationForThisObjectTypeIndexMaxItems = 0

                                        local sledDestinationsBySourceIDThenTribeID = routeSegmentDestinationsBySourceObjectIDThenTribeID[destinationObject.uniqueID]
                                        if sledDestinationsBySourceIDThenTribeID then
                                            local sledValidDestinationsBySourceID = getAllStorageAllyTribeDestinationInfos(tribeID, object.sharedState.tribeID, sledDestinationsBySourceIDThenTribeID)
                                            for sledTribeID, sledDestinationsByTribeID in pairs(sledValidDestinationsBySourceID) do
                                                if next(sledDestinationsByTribeID) then
                                        -- local sledDestinationsBySourceID = routeSegmentDestinationsBySourceObjectIDThenTribeID[destinationObject.uniqueID]
                                            --if sledDestinationsBySourceID then
                                                --local sledDestinationsByTribeID = sledDestinationsBySourceID[tribeID]
                                                --if sledDestinationsByTribeID and next(sledDestinationsByTribeID) then
                                                    sledHasDestinations = true
                                                    for j,sledDestinationInfo in ipairs(sledDestinationsByTribeID) do
                                                        local sledDestinationMatchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(sledDestinationInfo.destinationID, objectTypeIndex, tribeID, {
                                                            allowTradeRequestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                            allowQuestsMatchingResourceTypeIndex = inventoryResourceTypeIndex,
                                                        })
                                                        if sledDestinationMatchInfo then
                                                            foundDestinationForThisObjectTypeIndexMaxItems = foundDestinationForThisObjectTypeIndexMaxItems + sledDestinationMatchInfo.maxItems
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        if sledHasDestinations then
                                            if foundDestinationForThisObjectTypeIndexMaxItems == 0 then
                                                matchInfo = nil
                                            else
                                                matchInfo.maxItems = math.min(matchInfo.maxItems, foundDestinationForThisObjectTypeIndexMaxItems)
                                            end
                                        end

                                    end
                                    ----disabled--mj:objectLog(object.uniqueID, "matchInfo:", matchInfo)

                                    --disabled--mj:objectLog(object.uniqueID, "matchInfo:", matchInfo)
                                    if matchInfo then
                                        return {
                                            sourceObjectID = object.uniqueID,
                                            destinationCapacity = matchInfo.maxItems,
                                            destinationObjectID = destinationInfo.destinationID,
                                            resourceTypeIndex = inventoryResourceTypeIndex,
                                            objectTypeIndex = objectTypeIndex,
                                            routeID = destinationInfo.routeID,
                                            routeTribeID = routeTribeID,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function serverLogistics:setSapienRouteAssignment(sapienID, routeOwnerTribeID, routeIDOrNil)
    local currentAssignmentRouteInfo = routeAssignmentsBySapienID[sapienID]
    if (not currentAssignmentRouteInfo) or (not routeIDOrNil) or (currentAssignmentRouteInfo.key ~= getRouteAssignmentKey(routeOwnerTribeID, routeIDOrNil)) then
       -- mj:error("serverLogistics:setSapienRouteAssignment:", sapienID, " routeIDOrNil:", routeIDOrNil)

        if currentAssignmentRouteInfo then
            local prevRouteAssignmentCounts = routeAssignmentCountsByTribeID[currentAssignmentRouteInfo.tribeID]
            local prevRouteAssignmentSapienIDs = routeAssignmentSapienIDsByTribeID[currentAssignmentRouteInfo.tribeID]
            if prevRouteAssignmentCounts then
                prevRouteAssignmentCounts[currentAssignmentRouteInfo.routeID] = prevRouteAssignmentCounts[currentAssignmentRouteInfo.routeID] - 1
                if prevRouteAssignmentSapienIDs and prevRouteAssignmentSapienIDs[currentAssignmentRouteInfo.routeID] then
                    prevRouteAssignmentSapienIDs[currentAssignmentRouteInfo.routeID][sapienID] = nil
                end
                --mj:log("removed routeAssignmentCounts[currentAssignmentRouteID]:", routeAssignmentCounts[currentAssignmentRouteID])
                serverLogistics:updateMaintenceRequiredForRouteID(currentAssignmentRouteInfo.tribeID, currentAssignmentRouteInfo.routeID)
            end
        end


        if routeIDOrNil then
            local routeAssignmentCounts = routeAssignmentCountsByTribeID[routeOwnerTribeID]
            local routeAssignmentSapienIDs = routeAssignmentSapienIDsByTribeID[routeOwnerTribeID]
            if not routeAssignmentCounts then
                routeAssignmentCounts = {}
                routeAssignmentCountsByTribeID[routeOwnerTribeID] = routeAssignmentCounts
            end
            if not routeAssignmentSapienIDs then
                routeAssignmentSapienIDs = {}
                routeAssignmentSapienIDsByTribeID[routeOwnerTribeID] = routeAssignmentSapienIDs
            end

            local logisticsRoute = serverWorld:getLogisticsRoute(routeOwnerTribeID, routeIDOrNil)
            if (not logisticsRoute) or logisticsRoute.disabled then
                routeAssignmentsBySapienID[sapienID] = nil
                return false
            end
            local maxSapiens = gameConstants.logisticsRouteMaxSapiens
            local currentCount = routeAssignmentCounts[routeIDOrNil] or 0
            --mj:log("maxSapiens:", maxSapiens, " currentCount:", currentCount)
            if maxSapiens and (currentCount >= maxSapiens) then
                --mj:log("return false:", sapienID)
                routeAssignmentsBySapienID[sapienID] = nil
                return false
            end
            routeAssignmentCounts[routeIDOrNil] = currentCount + 1
            if not routeAssignmentSapienIDs[routeIDOrNil] then
                routeAssignmentSapienIDs[routeIDOrNil] = {}
            end
            routeAssignmentSapienIDs[routeIDOrNil][sapienID] = true
            --mj:log("added routeAssignmentCounts[routeIDOrNil]:", routeAssignmentCounts[routeIDOrNil])
            routeAssignmentsBySapienID[sapienID] = {
                tribeID = routeOwnerTribeID,
                routeID = routeIDOrNil,
                key = getRouteAssignmentKey(routeOwnerTribeID, routeIDOrNil)
            }
            
            serverLogistics:updateMaintenceRequiredForRouteID(routeOwnerTribeID, routeIDOrNil)
        else
            routeAssignmentsBySapienID[sapienID] = nil
            --[[if currentAssignmentRouteID then --this is needed to support removeRouteWhenComplete
                serverLogistics:updateLogisticsRoutesForSapienBecomingUnassigned(tribeID, currentAssignmentRouteID)
            end]]
        end

    end
    return true
end

function serverLogistics:getSapienCountAssignedToRoute(tribeID, routeID)
    local routeAssignmentCounts = routeAssignmentCountsByTribeID[tribeID]
    if routeAssignmentCounts then
        return routeAssignmentCounts[routeID] or 0
    end
    return 0
end

--[[function serverLogistics:getSapienCountAssignedToPickupForRoute(tribeID, routeID, pickupObjectID)
    local routeAssignmentSapienIDs = routeAssignmentSapienIDsByTribeID[tribeID]
    local count = 0
    if routeAssignmentSapienIDs then
        local thisRouteAssignedIDs = routeAssignmentSapienIDs[routeID]
        if thisRouteAssignedIDs then
            for sapienID, tf in pairs(thisRouteAssignedIDs) do
                local sapien = serverGOM:getObjectWithID(sapienID)
                if sapien then
                    local orderState = sapien.sharedState.orderQueue[1]
                    if orderState and orderState.context and orderState.objectID == pickupObjectID then
                        local storageAreaTransferInfo = orderState.context.storageAreaTransferInfo
                        if storageAreaTransferInfo and storageAreaTransferInfo.sourceObjectID == pickupObjectID then
                            count = count + 1
                        end
                    end]]
                    --[[local logisticsInfo = sapien.privateState.logisticsInfo
                    if logisticsInfo then
                        mj:log("logisticsInfo:", logisticsInfo, " pickupObjectID:", pickupObjectID)
                        if logisticsInfo.lastDestinationObjectID == pickupObjectID then
                            count = count + 1
                        end
                    end]]
                --[[end
            end
        end
    end
    return count
end]]

function serverLogistics:callFunctionForAllSapiensOnRoute(tribeID, routeID, func)
    local routeAssignmentSapienIDs = routeAssignmentSapienIDsByTribeID[tribeID]
    if routeAssignmentSapienIDs then
        local thisRouteAssignedIDs = routeAssignmentSapienIDs[routeID]
        if thisRouteAssignedIDs then
            for sapienID, tf in pairs(thisRouteAssignedIDs) do
                local sapien = serverGOM:getObjectWithID(sapienID)
                if sapien then
                    if func(sapien) then
                        return
                    end
                end
            end
        end
    end
end


function serverLogistics:sapienAssignedCountHasReachedMaxForRoute(tribeID, routeID, sapienIDOrNil)
    --mj:log("sapienAssignedCountHasReachedMaxForRoute:", routeID)

    local logisticsRoute = serverWorld:getLogisticsRoute(tribeID, routeID)
    if (not logisticsRoute) or logisticsRoute.disabled then
        return true
    end
    
    local routeAssignedCount = serverLogistics:getSapienCountAssignedToRoute(tribeID, routeID)
    --mj:log("getSapienCountAssignedToRoute:", routeID, " routeAssignedCount:", routeAssignedCount, " logisticsRoute:", logisticsRoute)


    -- maxSapiens no longer supported
    --[[local maxSapiens = logisticsRoute.maxSapiens or 100
    if maxSapiens <= 0 then
        return true
    end]]

    local maxStoredItemTransferCount = 0
    local availableTransferCountsByObjectType = serverStorageArea:availableTransferCountsByObjectType(logisticsRoute.from, tribeID)
    --local storedItemTransferCount, storedItemObjectTypeIndex = serverStorageArea:availableTransferCount(logisticsRoute.from, tribeID)

    --mj:log("availableTransferCountsByObjectType:", availableTransferCountsByObjectType)

    local totalFoundCount = 0
    local highestNonZeroSpaceAvailable = 0
    if availableTransferCountsByObjectType then
        for objectTypeIndex,count in pairs(availableTransferCountsByObjectType) do
            --mj:log("storedItemTransferCount:", objectTypeIndex, " count:", count)
            local destinationRemainingAvailableCount = serverStorageArea:storageAreaRemainingAllowedItemsCount(logisticsRoute.to, objectTypeIndex, tribeID)
            if destinationRemainingAvailableCount and destinationRemainingAvailableCount > 0 then
                highestNonZeroSpaceAvailable = math.max(highestNonZeroSpaceAvailable, destinationRemainingAvailableCount)
                totalFoundCount = totalFoundCount + count
                --mj:log("highestNonZeroSpaceAvailable:", highestNonZeroSpaceAvailable, " destinationRemainingAvailableCount:", destinationRemainingAvailableCount, " count:", count, " totalFoundCount:", totalFoundCount)
            end
        end
    end

    maxStoredItemTransferCount = math.min(totalFoundCount, highestNonZeroSpaceAvailable)

    maxStoredItemTransferCount = math.min(maxStoredItemTransferCount, gameConstants.logisticsRouteMaxSapiens) --set a sanity max

    local maxSapiens = maxStoredItemTransferCount

    if maxSapiens <= 0 then
        --mj:log("sapienAssignedCountHasReachedMaxForRoute returning true (maxSapiens <= 0)")
        return true
    end

    if not sapienIDOrNil then
        return false
    end

    local assignmentInfo = routeAssignmentsBySapienID[sapienIDOrNil]
    local currentAssignedRouteMatches = ((assignmentInfo and assignmentInfo.key) == getRouteAssignmentKey(tribeID, routeID))
    
    if currentAssignedRouteMatches then
        if (routeAssignedCount - 1) >= maxSapiens then
            --mj:log("sapienAssignedCountHasReachedMaxForRoute returning true (routeAssignedCount - 1) >= maxSapiens")
            return true
        end
    elseif routeAssignedCount >= maxSapiens then
        --mj:log("sapienAssignedCountHasReachedMaxForRoute returning true routeAssignedCount >= maxSapiens")
        return true
    end

    return false
end

function serverLogistics:init(serverGOM_, serverWorld_, serverSapien_, serverStorageArea_, serverCraftArea_)
    serverWorld = serverWorld_
    serverSapien = serverSapien_
    serverGOM = serverGOM_
    serverStorageArea = serverStorageArea_
    --serverCraftArea = serverCraftArea_
end

return serverLogistics