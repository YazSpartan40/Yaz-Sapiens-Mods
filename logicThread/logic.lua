local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local length2 = mjm.length2
local normalize = mjm.normalize
--local cross = mjm.cross
local pointIsLeftOfLine = mjm.pointIsLeftOfLine

local terrain = mjrequire "logicThread/clientTerrain"
local clientDestination = mjrequire "logicThread/clientDestination"
local clientObjectNotifications = mjrequire "logicThread/clientObjectNotifications"
local physics = mjrequire "common/physics"
local worldHelper = mjrequire "common/worldHelper"
local physicsSets = mjrequire "common/physicsSets"
local profiler = mjrequire "common/profiler"
local weather = mjrequire "common/weather"
local model = mjrequire "common/model"
local gameConstants = mjrequire "common/gameConstants"

local particleEffects = mjrequire "logicThread/particleEffects"
local logicAudio = mjrequire "logicThread/logicAudio"
local playerAvatars = mjrequire "logicThread/playerAvatars"
--local gameObject = mjrequire "common/gameObject"

local logic = {
    playerPos = vec3(0.0,1.0,0.0),
    worldTime = nil,
    yearSpeed = 0.0,
    sunRotationSpeed = 0.0,
    tribeID = nil,
    renderDistance = -1,
    speedMultiplier = 1.0,
    validOwnerTribeIDs = {},
}

local bridge = nil

local clientGOM = nil
local clientSapien = nil
local serverPrivateSharedClientState = nil

local timeSinceLastServerUpdateSent = 0.0

function logic:setClientGOM(clientGOM_, clientSapien_)
    clientGOM = clientGOM_
    clientSapien = clientSapien_
    terrain:setLogic(logic, clientGOM)
    clientGOM:setTerrain(terrain)
    particleEffects:setLogic(logic)
end

local hiddenVerts = {}

local function setDecalsHiddenForVerts(newHiddenvertIDs)
    local hiddenVertsToUnhide = mj:cloneTable(hiddenVerts)
    for i,vertID in ipairs(newHiddenvertIDs) do
        if not hiddenVerts[vertID] then
            hiddenVerts[vertID] = true
            local vert = terrain:getVertWithID(vertID)
            terrain:setDecalsHiddenForVert(vert, true)
        end

        hiddenVertsToUnhide[vertID] = nil
    end

    for vertID, value in pairs(hiddenVertsToUnhide) do
        local vert = terrain:getVertWithID(vertID)
        if vert then
            terrain:setDecalsHiddenForVert(vert, false)
        end
        hiddenVerts[vertID] = nil
    end
end

local function unhideAllDecals()
    for vertID, value in pairs(hiddenVerts) do
        local vert = terrain:getVertWithID(vertID)
        if vert then
            terrain:setDecalsHiddenForVert(vert, false)
        end
    end

    hiddenVerts = {}
end

local function serializeFaces(terrainFaces)
    local result = {}
    for i,neighborFace in ipairs(terrainFaces) do

        local neighborVerts = { neighborFace:getVert(0), neighborFace:getVert(1), neighborFace:getVert(2)}

        result[i] = {
            uniqueID = neighborFace.uniqueID,
            level = neighborFace.level,
            verts = {
                {
                    uniqueID = neighborVerts[1].uniqueID,
                    pos = neighborVerts[1].pos,
                },
                {
                    uniqueID = neighborVerts[2].uniqueID,
                    pos = neighborVerts[2].pos,
                },
                {
                    uniqueID = neighborVerts[3].uniqueID,
                    pos = neighborVerts[3].pos,
                }
            }
        }
    end
    return result
end

local function retrieveTriangle(triangleID, closeVertexPos, retrieveClosestVertexNeighbors)

    local face = terrain:getFaceWithID(triangleID)
    if not face then
        mj:log("face not found:" .. mj:tostring(triangleID))
        return nil
    end
    local sendFace = {}

    local verts = { face:getVert(0), face:getVert(1), face:getVert(2)}
    local vertPositions = { verts[1].pos, verts[2].pos, verts[3].pos}

    sendFace.uniqueID = triangleID

    sendFace.verts = {
        {
            uniqueID = verts[1].uniqueID,
            pos = vertPositions[1],
        },
        {
            uniqueID = verts[2].uniqueID,
            pos = vertPositions[2],
        },
        {
            uniqueID = verts[3].uniqueID,
            pos = vertPositions[3],
        }
    }

    if closeVertexPos then
        local bcCenter = vertPositions[2] + (vertPositions[3] - vertPositions[2]) * 0.5
        if pointIsLeftOfLine(closeVertexPos, vertPositions[1], bcCenter) then
            local abCenter = vertPositions[1] + (vertPositions[2] - vertPositions[1]) * 0.5
            if pointIsLeftOfLine(closeVertexPos, vertPositions[3], abCenter) then
                sendFace.closestVertIndex = 1
            else
                sendFace.closestVertIndex = 2
            end
        else
            local acCenter = vertPositions[1] + (vertPositions[3] - vertPositions[1]) * 0.5
            if pointIsLeftOfLine(closeVertexPos, vertPositions[2], acCenter) then
                sendFace.closestVertIndex = 3
            else
                sendFace.closestVertIndex = 1
            end
        end

        if retrieveClosestVertexNeighbors then
            local neighborFaces = terrain:getFacesSharingVert(verts[sendFace.closestVertIndex].uniqueID)
            sendFace.neighborFaces = serializeFaces(neighborFaces)
        end
    end

    return sendFace
end

local function retrieveTerrainVertInfo(vertID)
    return terrain:retrieveVertInfo(vertID)
end


function logic:setAnimationIndexForObject(objectID, animationGroupIndex, newAnimationTypeIndex, speedMultiplier) --NOTE totally fine to call this with the same animation type index and a new speedMultiplier
    --mj:debug("logic:setAnimationIndexForObject:", objectID, " animationGroupIndex:", animationGroupIndex, " newAnimationTypeIndex:", newAnimationTypeIndex)
    bridge:setAnimationIndexForObject(objectID, animationGroupIndex, newAnimationTypeIndex, speedMultiplier)
end


-- called by engine

local playerPos = nil
local normalizedPlayerPos = nil
local playerDir = nil
local mapPos = nil
local mapMode = nil


local function startProfile()
	profiler:start(10.0)
end

function logic:setBridge(bridge_, serverPrivateSharedClientState_)

    bridge = bridge_

    serverPrivateSharedClientState = serverPrivateSharedClientState_
    if serverPrivateSharedClientState.gameConstantsConfig then
        for k,v in pairs(serverPrivateSharedClientState.gameConstantsConfig) do
            mj:log("overriding local game constant with server value:", k, "=>", v)
            gameConstants[k] = v
        end
    end

    clientDestination:setLogic(logic)
    logicAudio:setLogic(logic)
    playerAvatars:init(logic)

    logic.worldTime = bridge.worldTime
    logic.yearSpeed = bridge.yearSpeed
    logic.sunRotationSpeed = bridge.sunRotationSpeed
    
    -- LOCAL --

    bridge:registerLogicThreadLocalFunction("rayTest", function(userData)
        return physics:rayTest(userData.rayStart, userData.rayEnd, userData.physicsSetIndexOrNil)
    end)

    bridge:registerLogicThreadLocalFunction("retrieveObject", function(uniqueID)
        return clientGOM:retrieveObjectInfo(uniqueID, false)
    end)

    bridge:registerLogicThreadLocalFunction("requestUnloadedObjectFromServer", function(objectID)
        clientGOM:requestUnloadedObjectFromServer(objectID)
    end)


    bridge:registerLogicThreadLocalFunction("setLookAtObjectID", function(uniqueID)
        clientGOM:setLookAtObjectID(uniqueID)
    end)

    bridge:registerLogicThreadLocalFunction("showObjectsForBuildModeStart", function(uniqueID)
        clientGOM:showObjectsForBuildModeStart()
    end)

    bridge:registerLogicThreadLocalFunction("hideObjectsForBuildModeEnd", function(uniqueID)
        clientGOM:hideObjectsForBuildModeEnd()
    end)

    bridge:registerLogicThreadLocalFunction("retrieveObjects", function(uniqueIDs)
        return clientGOM:retrieveObjectInfos(uniqueIDs)
    end)

    bridge:registerLogicThreadLocalFunction("setDecalsHiddenForVerts", function(vertIDs)
        setDecalsHiddenForVerts(vertIDs)
    end)

    bridge:registerLogicThreadLocalFunction("unhideAllDecals", function()
        unhideAllDecals()
    end)

    bridge:registerLogicThreadLocalFunction("worldPlaySoundComplete", function(completionCallbackID)
        logicAudio:worldPlaySoundComplete(completionCallbackID)
    end)

    --[[bridge:registerLogicThreadLocalFunction("getVertsInBox", function(userData)
        return getVertsInBox(userData.min, userData.max, userData.pos, userData.rotation)
    end)]]

    bridge:registerLogicThreadLocalFunction("hasAnyFollowers", function()
        return clientSapien:hasAnyFollowers()
    end)
    
    bridge:registerLogicThreadLocalFunction("retrieveTrianglesWithinRadius", function(userData)
        if not userData.pos then
            mj:log("no position supplied to retrieveTrianglesWithinRadius")
            return nil
        end
        if not userData.radius then
            mj:log("no radius supplied to retrieveTrianglesWithinRadius")
            return nil
        end
        return serializeFaces(terrain:retrieveTrianglesWithinRadius(userData.pos,userData.radius, 99))
    end)

    --[[bridge:registerLogicThreadLocalFunction("retrieveInfoForBuildUI", function(userData)
        return {
            faces = serializeFaces(terrain:retrieveTrianglesWithinRadius(userData.triGetPos,userData.triGetRadius)),
            verts = getVertsInBox(userData.placementMin, userData.placementMax, userData.placementPos, userData.placementRotation)
        }
    end)]]

    bridge:registerLogicThreadLocalFunction("retrieveTriangle", function(userData)
        return retrieveTriangle(userData.triangleID, userData.closeVertexPos, userData.retrieveClosestVertexNeighbors)
    end)

    bridge:registerLogicThreadLocalFunction("retrieveTerrainVertInfo", function(vertID)
        return retrieveTerrainVertInfo(vertID)
    end)

    
    bridge:registerLogicThreadLocalFunction("getHighestDetailTerrainPointAtPoint", function(point)
        return terrain:getHighestDetailTerrainPointAtPoint(point)
    end)


    bridge:registerLogicThreadLocalFunction("getBiomeTagsForVertWithID", function(userData)
        return terrain:getBiomeTagsForVertWithID(userData)
    end)
    

    bridge:registerLogicThreadLocalFunction("registerServerStateChangeMainThreadNotificationsForObjects", function(uniqueIDs)
        clientGOM:registerServerStateChangeMainThreadNotificationsForObjects(uniqueIDs)
    end)

    bridge:registerLogicThreadLocalFunction("deregisterServerStateChangeMainThreadNotificationsForObjects", function(uniqueIDs)
        clientGOM:deregisterServerStateChangeMainThreadNotificationsForObjects(uniqueIDs)
    end)
    

    bridge:registerLogicThreadLocalFunction("registerServerStateChangeMainThreadNotificationsForVerts", function(uniqueIDs)
        terrain:registerServerStateChangeMainThreadNotificationsForVerts(uniqueIDs)
    end)

    bridge:registerLogicThreadLocalFunction("deregisterServerStateChangeMainThreadNotificationsForVerts", function(uniqueIDs)
        terrain:deregisterServerStateChangeMainThreadNotificationsForVerts(uniqueIDs)
    end)

    bridge:registerLogicThreadLocalFunction("hideObject", function(uniqueID)
        clientGOM:setObjectHidden(uniqueID, true)
    end)

    bridge:registerLogicThreadLocalFunction("unHideObject", function(uniqueID)
        clientGOM:setObjectHidden(uniqueID, false)
    end)
    
    bridge:registerLogicThreadLocalFunction("setSelectionHightlightForObjects", function(userData)
        if not userData then
            clientGOM:clearAllSelectionHighlights()
        else
            clientGOM:setSelectionHightlightForObjects(userData.objectIDs, userData.brightness)
        end
    end)

    
    bridge:registerLogicThreadLocalFunction("setWarningColorForObjects", function(userData)
        if not userData then
            clientGOM:clearAllWarningColors()
        else
            clientGOM:setWarningColorForObjects(userData.objectIDs, userData.value)
        end
    end)
    
    bridge:registerLogicThreadLocalFunction("getGameObjectIDsWithinRadiusOfPos", function(userData)
        --mj:log("userData:", userData)
        return clientGOM:getGameObjectIDsOfTypesWithinRadiusOfPos(userData.types, userData.pos, userData.radius, userData.tribeRestrictInfo)
    end)
    
    bridge:registerLogicThreadLocalFunction("getGameObjectsOfTypesWithinRadiusOfPos", function(userData)
        --mj:log("userData:", userData)
        return clientGOM:getGameObjectINFOsOfTypesWithinRadiusOfPos(userData.types, userData.pos, userData.radius, userData.tribeRestrictInfo)
    end)

    
    bridge:registerLogicThreadLocalFunction("getVertsForMultiSelectAroundID", function(vertID)
        return terrain:getVertsForMultiSelectAroundID(vertID)
    end)
    
    bridge:registerLogicThreadLocalFunction("getVertsForMultiSelectAroundPosition", function(position)
        return terrain:getVertsForMultiSelectAroundPosition(position)
    end)

    
    
    bridge:registerLogicThreadLocalFunction("getGameObjectsForIDs", function(objectIDs)
        return clientGOM:getGameObjectINFOsForIDs(objectIDs)
    end)
    bridge:registerLogicThreadLocalFunction("getVertInfosForIDs", function(vertIDs)
        return terrain:getVertINFOsForIDs(vertIDs)
    end)

    bridge:registerLogicThreadLocalFunction("setUIHiddenDueToInactivity", function(uIHiddenDueToInactivity)
        clientGOM:setUIHiddenDueToInactivity(uIHiddenDueToInactivity)
    end)
    

    

    local notifiedLogicOfPlayerPosReceived = false

    bridge:registerLogicThreadLocalFunction("updatePlayerPos", function(info)
        playerPos = info.playerPos
        normalizedPlayerPos = normalize(playerPos)
        playerDir = info.playerDir
        --mj:log("info.mapMode:", info.mapMode)
        mapPos = info.mapPos or playerPos
        mapMode = info.mapMode
        if not notifiedLogicOfPlayerPosReceived then
            bridge:loadTerrain()
            notifiedLogicOfPlayerPosReceived = true
        end
    end)
    
    bridge:registerLogicThreadLocalFunction("setPlayerInfoForTerrain", function(info)
        terrain:setPlayerInfo(info.playerPos, info.playerHeightAboveTerrain)
        return terrain:getObjectInfluencedMaxPlayerCameraHeightAboveTerrain(normalize(info.playerPos))
    end)

    bridge:registerLogicThreadLocalFunction("setGrassDensity", function(newValue)
        terrain:setGrassDensity(newValue)
    end)

    bridge:registerLogicThreadLocalFunction("getWalkableOffsets", function(requestsByID)
        local result = {}
        for key,info in pairs(requestsByID) do
            local inPos = info.basePos
            local clampToSeaLevel = false
            local offsetPosition = worldHelper:getBelowSurfacePos(inPos, 1.0, physicsSets.walkableOrInProgressWalkable, nil, clampToSeaLevel)
            local offset = offsetPosition - inPos

            local thisResult = {
                offset = offset,
            }

            if info.requiresRotation then
                thisResult.up = worldHelper:getWalkableUpVector(info.basePos)
            end
            
            result[key] = thisResult
        end

        return result
    end)

    bridge:registerLogicThreadLocalFunction("getPathPlacementOffsets", function(requestsByID)
        local result = {}
        for key,inPos in pairs(requestsByID) do
            local offsetPosition = terrain:getHighestDetailTerrainPointAtPoint(inPos)
            local offset = offsetPosition - inPos

            local thisResult = {
                offset = offset,
            }
            
            result[key] = thisResult
        end

        return result
    end)

    

    

    bridge:registerLogicThreadLocalFunction("changeDebugObject", function(newObjectID)
        mj.debugObject = newObjectID
        mj:log("Object ID:", newObjectID, " is now set as the target for detailed logging.")
        local object = clientGOM:getObjectWithID(newObjectID)
        if not object then
            mj:warn("Debug object not found")
        else
            mj:log("Debug object pos:", object.pos)
            mj:log("Debug object altitude:", mj:pToM(mjm.length(object.pos) - 1.0))
            mj:log("Debug object type:", object.objectTypeIndex)
            mj:log("Debug object subdivLevel:", object.subdivLevel)
            mj:log("Debug object renderType:", object.renderType)
            mj:log("Debug object rotation:", object.rotation)
            mj:log("Debug object state:", object.sharedState)
            mj:log("Debug object clientState:", clientGOM.clientStates[object.uniqueID])

            clientGOM:setDebugObject(newObjectID)

            --debug talk animation
            logic:callMainThreadFunction("playSapienTalkAnimation", {
                uniqueID = object.uniqueID,
                phraseDuration = 5.0,
            })

            --make them attempt to look close to straight down
            --[[local clientState = clientGOM.clientStates[object.uniqueID]
            if clientState then
                local rotationMatrix = mjm.mat3LookAtInverse(normalize(-object.normalizedPos + vec3(0.01,0.0,0.0)), object.normalizedPos)
                
                clientState.nextHeadRotationInfo = {
                    rotationMatrix = rotationMatrix,
                }
            end]]
        end
    end)

	bridge:registerLogicThreadLocalFunction("startProfile", startProfile)
    

    -- NET --

    bridge:registerLogicThreadNetFunction("initialFollowersList", function(followerInfos)
        --mj:log("initialFollowersList received")
        clientSapien:initialFollowersListReceived(followerInfos)
    end)
    
    bridge:registerLogicThreadNetFunction("followersAdded", function(addedInfos)
        clientSapien:followersAdded(addedInfos)
    end)
    
    bridge:registerLogicThreadNetFunction("objectNotification", function(notificationInfo)
        --mj:log("objectNotification:", notificationInfo)
        clientObjectNotifications:notificationReceivedFromServer(notificationInfo)
    end)

    bridge:registerLogicThreadNetFunction("tribeNotification", function(notificationInfo)
        logic:callMainThreadFunction("displayUINotification", notificationInfo)
    end)

    
    
    bridge:registerLogicThreadNetFunction("followersRemoved", function(removedIDs)
        clientSapien:followersRemoved(removedIDs)
    end)

    bridge:registerLogicThreadNetFunction("skillPriorityListChanged", function()
        clientSapien:skillPriorityListChanged()
    end)

    bridge:registerLogicThreadNetFunction("privateSharedClientStateChanged", function(serverPrivateSharedClientState__)
        serverPrivateSharedClientState = serverPrivateSharedClientState__
       -- mj:log("privateSharedClientStateChanged:", serverPrivateSharedClientState.tribeID)
        local prevTribeID = logic.tribeID
        logic.tribeID = serverPrivateSharedClientState.tribeID
        if logic.tribeID then
		    logic.validOwnerTribeIDs[logic.tribeID] = true
        end
        logic.discoveries = serverPrivateSharedClientState.discoveries
        --mj:log("privateSharedClientStateChanged with tribeID:", logic.tribeID)
        bridge:callMainThreadFunction("serverPrivateSharedClientStateChanged", serverPrivateSharedClientState)
        if prevTribeID ~= logic.tribeID then
            clientGOM:updatePlanObjectsForTribeSelection()
        end
    end)


    bridge:registerLogicThreadNetFunction("validOwnerTribeIDsChanged", function(validOwnerTribeIDs)
        logic.validOwnerTribeIDs = validOwnerTribeIDs
        bridge:callMainThreadFunction("validOwnerTribeIDsChanged", validOwnerTribeIDs)
    end)

    bridge:registerLogicThreadNetFunction("updateServerDebugStats", function(statsString)
        bridge:callMainThreadFunction("updateServerDebugStats", statsString)
    end)

    bridge:registerLogicThreadNetFunction("creationWorldTimeChanged", function(creationWorldTime)
        weather:setCreationWorldTime(creationWorldTime)
        bridge:callMainThreadFunction("creationWorldTimeChanged", creationWorldTime)
    end)

    bridge:registerLogicThreadNetFunction("serverProfileResult", function(resultString)
        mj:log(resultString)
    end)

    bridge:registerLogicThreadNetFunction("discoveriesChanged", function(discoveries)
        serverPrivateSharedClientState.discoveries = discoveries
        logic.discoveries = discoveries
        bridge:callMainThreadFunction("serverDiscoveriesChanged", discoveries)
    end)
    
    bridge:registerLogicThreadNetFunction("craftableDiscoveriesChanged", function(craftableDiscoveries)
        serverPrivateSharedClientState.craftableDiscoveries = craftableDiscoveries
        --logic.craftableDiscoveries = craftableDiscoveries --we don't need this for anything yet
        bridge:callMainThreadFunction("serverCraftableDiscoveriesChanged", craftableDiscoveries)
    end)

    bridge:registerLogicThreadNetFunction("logisticsRoutesChanged", function(logisticsRoutes)
        bridge:callMainThreadFunction("serverLogisticsRoutesChanged", logisticsRoutes)
    end)

    bridge:registerLogicThreadNetFunction("tribeRelationsSettingsChanged", function(tribeRelationsSettingsInfo)
        if not serverPrivateSharedClientState.tribeRelationsSettings then
            serverPrivateSharedClientState.tribeRelationsSettings = {}
        end
		serverPrivateSharedClientState.tribeRelationsSettings[tribeRelationsSettingsInfo.tribeID] = tribeRelationsSettingsInfo.tribeRelationsSettings
        bridge:callMainThreadFunction("serverTribeRelationsSettingsChanged", tribeRelationsSettingsInfo)
    end)

    bridge:registerLogicThreadNetFunction("seenResourceObjectTypesAdded", function(objectTypeIndexes)
        bridge:callMainThreadFunction("seenResourceObjectTypesAdded", objectTypeIndexes)
    end)
    
    bridge:registerLogicThreadNetFunction("addDestinationInfos", function(destinationInfos)
        clientDestination:addDestinationInfos(destinationInfos)
    end)

    bridge:registerLogicThreadNetFunction("updateDestination", function(destinationInfo)
        clientDestination:updateDestination(destinationInfo)
    end)
    
    bridge:registerLogicThreadNetFunction("updateDestinationTribeCenters", function(tribeCenterInfos)
        clientDestination:updateDestinationTribeCenters(tribeCenterInfos)
    end)

    bridge:registerLogicThreadNetFunction("updateDestinationRelationship", function(relationshipInfo)
        clientDestination:updateDestinationRelationship(relationshipInfo)
    end)

    bridge:registerLogicThreadNetFunction("updateDestinationTradeables", function(info)
        clientDestination:updateDestinationTradeables(info)
    end)

    bridge:registerLogicThreadNetFunction("updateDestinationPlayerOnlineStatus", function(info)
        clientDestination:updateDestinationPlayerOnlineStatus(info)
    end)
    
    

    bridge:registerLogicThreadNetFunction("tutorialStateChanged", function(info)
        bridge:callMainThreadFunction("tutorialStateChanged", info)
    end)
    
    
    bridge:registerLogicThreadNetFunction("chatMessageReceived", function(info)
        bridge:callMainThreadFunction("chatMessageReceived", info)
    end)

    bridge:registerLogicThreadNetFunction("clientStateChange", function(info)
        bridge:callMainThreadFunction("clientStateChange", info)
    end)

    
    bridge:registerLogicThreadNetFunction("setPathDebugConnections", function(debugConnections)
        bridge:callMainThreadFunction("setPathDebugConnections", debugConnections)
    end)

    bridge:registerLogicThreadNetFunction("setPathDebugPath", function(debugConnections)
        bridge:callMainThreadFunction("setPathDebugPath", debugConnections)
    end)

    bridge:registerLogicThreadNetFunction("setDebugAnchors", function(debugAnchors)
        bridge:callMainThreadFunction("setDebugAnchors", debugAnchors)
    end)

    
    
    bridge:registerLogicThreadNetFunction("orderCountsChanged", function(userData)
        bridge:callMainThreadFunction("orderCountsChanged", userData)
    end)
    
    
    bridge:registerLogicThreadNetFunction("resetDueToTribeFail", function(resetInfo)
        mj:log("resetDueToTribeFail resetInfo:", resetInfo)
        serverPrivateSharedClientState = resetInfo.privateShared
       -- local publicState = resetInfo.public

        logic.tribeID = serverPrivateSharedClientState.tribeID
        if logic.tribeID then
		    logic.validOwnerTribeIDs[logic.tribeID] = true
        end
        logic.discoveries = serverPrivateSharedClientState.discoveries

        resetInfo.resetTeleportPoint = terrain:getHighestDetailTerrainPointAtPoint(resetInfo.resetPoint)

        clientDestination:reset()
        clientGOM:updatePlanObjectsForTribeSelection()
        
        bridge:callMainThreadFunction("resetDueToTribeFail", resetInfo)
        mj:log("resetDueToTribeFail called")
    end)

    

    bridge:registerLogicThreadNetFunction("serverWeatherChanged", function(serverWeatherInfo)
        --mj:log("serverWeatherChanged:", serverWeatherInfo)
        weather:setServerWeatherInfo(serverWeatherInfo)
        bridge:callMainThreadFunction("serverWeatherChanged", serverWeatherInfo)
    end)


    bridge:registerLogicThreadNetFunction("otherClientDataUpdate", function(otherClientData)
        playerAvatars:otherClientDataUpdate(otherClientData)
    end)
    

    bridge:registerLogicThreadNetFunction("speedThrottleChanged", function(newIsThrottled)
        bridge:callMainThreadFunction("speedThrottleChanged", newIsThrottled)
    end)

end

--[[local function calculateTemperature(pos)
    local baseTemperatures = terrain:getBaseTemperaturesForPoint(pos)
    local meterologicalOffsetFromSolstice = 0.15
    local seasonMixFraction = (math.sin((logic.yearSpeed * logic.worldTime - meterologicalOffsetFromSolstice) * math.pi * 2.0) + 1.0) * 0.5
    local seasonalTemperature = mjm.mix(baseTemperatures.x, baseTemperatures.y, seasonMixFraction)
    mj:log("baseTemperatures:", baseTemperatures, " seasonMixFraction:", seasonMixFraction, " seasonalTemperature:", seasonalTemperature)
    return seasonalTemperature
end]]

local lastSentToUITemperatureIndex = nil

local lastPlayerStatsCovered = false
local lastPlayerStatsUpdatePos = nil
local updatePlayerStatsMoveDistanceThreshold = mj:mToP(0.2) * mj:mToP(0.2)

local coveredTestRayLength = mj:mToP(100.0)
local coveredTestRayStartOffsetLength = mj:mToP(-0.2)

local function doCoveredTest()
    local rayDirection = normalizedPlayerPos
    local rayStart = playerPos + rayDirection * coveredTestRayStartOffsetLength
    local rayEnd = rayStart + rayDirection * coveredTestRayLength

    local rayResult = physics:rayTest(rayStart, rayEnd, physicsSets.blocksRain, nil)

    if rayResult and rayResult.hasHitObject then
        return true
    end
    return false
end

function logic:updateLocationStats()
    local playerPosToUse = playerPos
    if mapMode then
        playerPosToUse = mapPos
    end
    local isCovered = lastPlayerStatsCovered
    if mapMode then
        isCovered = false
    else
        if (not lastPlayerStatsUpdatePos or length2(lastPlayerStatsUpdatePos - playerPosToUse) > updatePlayerStatsMoveDistanceThreshold) then
            lastPlayerStatsUpdatePos = playerPosToUse
            isCovered = doCoveredTest()
            lastPlayerStatsCovered = isCovered
        end
    end
    local closeObjectOffset = 0
    if (not mapMode) then
        closeObjectOffset = clientGOM:getCloseObjectTemperatureOffset(playerPosToUse)
    end
    local biomeTags = terrain:getBiomeTagsForNormalizedPoint(normalize(playerPosToUse))
    local temperatureZoneIndex = weather:getTemperatureZoneIndex(weather:getTemperatureZones(biomeTags), logic.worldTime, logic.timeOfDayFraction, logic.yearSpeed, playerPosToUse, isCovered, false, closeObjectOffset)

    if lastSentToUITemperatureIndex ~= temperatureZoneIndex then
        lastSentToUITemperatureIndex = temperatureZoneIndex
        bridge:callMainThreadFunction("playerTemperatureZoneChanged", temperatureZoneIndex)
    end
end

local lastSentCloudCover = nil
local lastSentCombinedSnow = nil
local lastSentWindStrength = nil

function logic:update(dt, speedMultiplier, playerPosIncoming, playerDirIncoming, mapModeIncoming, renderDistanceIncoming)
    if not playerPos then 
        playerPos = playerPosIncoming
        normalizedPlayerPos = normalize(playerPos)
        mapPos = playerPosIncoming
        playerDir = playerDirIncoming
        mapMode = mapModeIncoming
    end
    logic.playerPos = playerPos
    logic.playerDir = playerDirIncoming
    logic.speedMultiplier = speedMultiplier
    logic.worldTime = bridge.worldTime
    logic.timeOfDayFraction = bridge:getTimeOfDayFraction(playerPosIncoming)
    timeSinceLastServerUpdateSent = timeSinceLastServerUpdateSent + dt

    if renderDistanceIncoming ~= logic.renderDistance then
        logic.renderDistance = renderDistanceIncoming
        model:renderDistanceChanged(logic.renderDistance)
    end

    weather:update(logic.worldTime)

    local rainfallValues = terrain:getRainfallForNormalizedPoint(normalizedPlayerPos)
    local currentRainfall = weather:getRainfall(rainfallValues, normalizedPlayerPos, logic.worldTime, logic.yearSpeed)
    local cloudCover = weather:getCloudCover(currentRainfall) --send to main thread for rendering
    local rainSnow = weather:getRainSnowCombinedPrecipitation(currentRainfall)
    local windStrength = weather:getWindStrength()
    
    logic:updateLocationStats()
    local snowFraction = weather:getSnowFraction(normalizedPlayerPos, logic.worldTime, logic.yearSpeed, logic.timeOfDayFraction) or 0.0

    local windFraction = mjm.clamp(windStrength / 16.0, 0.0, 1.0)

    --mj:log("windStrength:", windStrength, " windFraction:", windFraction)

    particleEffects:update(playerPos, dt, speedMultiplier, rainSnow, snowFraction, windFraction)

    local function checkChanged(lastSentValue, newValue)
        return (not lastSentValue) or 
        (not mjm.approxEqualEpsilon(lastSentValue, newValue, 0.01)) or 
        (newValue < 0.0001 and lastSentValue >= 0.0001) or 
        (newValue > 0.9999 and lastSentValue <= 0.9999)
    end

    local combinedSnowValue = rainSnow * snowFraction
    if checkChanged(lastSentCloudCover, cloudCover) or checkChanged(lastSentCombinedSnow, combinedSnowValue) or checkChanged(lastSentWindStrength, windStrength) then
        --mj:log("cloudCover changed:", cloudCover)
        bridge:callMainThreadFunction("playerWeatherChanged", {
            cloudCover = cloudCover,
            combinedSnow = combinedSnowValue,
            windStrength = windStrength,
        })
        lastSentCloudCover = cloudCover
        lastSentCombinedSnow = combinedSnowValue
        lastSentWindStrength = windStrength
    end


    --local temperature = calculateTemperature(playerPos)
   -- mj:log("temperature:", temperature)

    --mj:log("logic.timeOfDayFraction:", logic.timeOfDayFraction)

        
    if timeSinceLastServerUpdateSent > 0.2 then
        bridge:callUnreliableServerFunction(
            "clientUpdate",
            {
                pos = playerPos,
                mapPos = mapPos,
                dir = playerDir,
                mapMode = mapMode,
            }
        )
        timeSinceLastServerUpdateSent = 0.0
    end

    playerAvatars:update(dt)
end

function logic:callMainThreadFunction(functionName, userData, callback)
    bridge:callMainThreadFunction(functionName, userData, callback)
end

function logic:callServerFunction(functionName, userData, callback)
    bridge:callServerFunction(functionName, userData, callback)
end

function logic:callUnreliableServerFunction(functionName, userData, callback)
    bridge:callUnreliableServerFunction(functionName, userData, callback)
end

function logic:getTimeUntilNextSeasonChange(offsetFractionOrNil)
    local offsetFraction = 1.0 - 0.125
    if offsetFractionOrNil then
        offsetFraction = offsetFraction - offsetFractionOrNil
    end
    local seasonBase = logic.yearSpeed * logic.worldTime + offsetFraction
    local remainderFraction = 0.25 - math.fmod(seasonBase, 0.25)
    return remainderFraction / logic.yearSpeed
end


function logic:discoveryInfoForResearchTypeIndex(researchTypeIndex)
    return logic.discoveries[researchTypeIndex]
end

function logic:getSeasonFraction() -- 0.0 is spring equinox in north, 0.25 longest day, 0.5 is autumn, 0.75 winter. Offset by 0.5 for south.
    return math.fmod(logic.yearSpeed * logic.worldTime, 1.0)
end

function logic:getYearLength()
	return 1.0 / logic.yearSpeed
end

function logic:getYearIndex()
	local yearLength = logic:getYearLength()
	return math.floor(logic.worldTime / yearLength) + 1
end

function logic:getTribeRelationsSettings()
    return serverPrivateSharedClientState.tribeRelationsSettings
end


function logic:tribeIsValidOwner(tribeID)
	return logic.validOwnerTribeIDs[tribeID]
end

return logic