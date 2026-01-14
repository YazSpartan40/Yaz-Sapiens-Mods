local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local cross = mjm.cross
local length2 = mjm.length2

--local mjs = mjrequire "common/mjs"
--local order = mjrequire "common/order"
local gameConstants = mjrequire "common/gameConstants"
local evolvingObject = mjrequire "common/evolvingObject"
local sapienConstants = mjrequire "common/sapienConstants"
local gameObject = mjrequire "common/gameObject"
local fuel = mjrequire "common/fuel"
local planHelper = mjrequire "common/planHelper"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local mapModes = mjrequire "common/mapModes"
local profiler = mjrequire "common/profiler"
local statistics = mjrequire "common/statistics"
local mood = mjrequire "common/mood"
local rng = mjrequire "common/randomNumberGenerator"
local weather = mjrequire "common/weather"
local desire = mjrequire "common/desire"
local resource = mjrequire "common/resource"
local destination = mjrequire "common/destination"
local constructable = mjrequire "common/constructable"
local storage = mjrequire "common/storage"
local mob = mjrequire "common/mob/mob"
local worldConfig = mjrequire "common/worldConfig"

local server = mjrequire "server/server"
local serverGOM = mjrequire "server/serverGOM"
local serverSapien = mjrequire "server/serverSapien"
local planManager = mjrequire "server/planManager"
local serverTerrain = mjrequire "server/serverTerrain"
local serverTribe = mjrequire "server/serverTribe"
local serverDestination = mjrequire "server/serverDestination"
local serverMobGroup = mjrequire "server/serverMobGroup"
local serverStoryEvents = mjrequire "server/serverStoryEvents"
local serverNomadTribe = mjrequire "server/serverNomadTribe"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverStorageArea = mjrequire "server/serverStorageArea"
local serverLogistics = mjrequire "server/serverLogistics"
local serverEvolvingTerrain = mjrequire "server/serverEvolvingTerrain"
local serverTribeAIPlayer = mjrequire "server/serverTribeAIPlayer"
local serverSapienSkills = mjrequire "server/serverSapienSkills"
local pathCreator = mjrequire "server/pathCreator"
local serverStatistics = mjrequire "server/serverStatistics"
local serverNotifications = mjrequire "server/serverNotifications"
local serverFuel = mjrequire "server/serverFuel"
local serverTutorialState = mjrequire "server/serverTutorialState"
--local serverSapienAI = mjrequire "server/sapienAI/ai"
local serverWeather = mjrequire "server/serverWeather"
local serverCompostBin = mjrequire "server/objects/serverCompostBin"
local serverCraftArea = mjrequire "server/serverCraftArea"
local nameLists = mjrequire "common/nameLists"
local notification = mjrequire "common/notification"
--local serverSeat = mjrequire "server/objects/serverSeat"

local serverMob = mjrequire "server/objects/serverMob"
local serverFlora = mjrequire "server/objects/serverFlora"
local serverWorldSettings = mjrequire "server/serverWorldSettings"

local currentIsSpeedingThroughNight = false
local autoSpeedUpRestoreSpeed = nil

local serverWorld = {
	resources = {},
}

local bridge = nil

local playersDatabase = nil
local worldDatabase = nil
local creationWorldTime = nil

local playerClientIDsByTribeIDs = nil
local playerInfos = nil

local clientStates = {}

serverWorld.transientClientStates = {}
serverWorld.connectedClientIDSet = {}
serverWorld.connectedClientCount = 0
serverWorld.speedMultiplierIndexByClientID = {}


serverWorld.recentPlayerTribeListMaxSize = 100
serverWorld.recentPlayerTribeList = nil

local followerCountsByTribe = {}
local babyCountsByTribe = {}
local sleepingSapienCount = 0

local serverLoadFastForwardDisableThreshold = 1.0
local throttleSpeedDueToServerLoad = false

local function setTimeFromSunRotation(sunRotation)
	local remainder = sunRotation % (math.pi * 2.0)
	local timeRotation = bridge.worldTime * bridge.sunRotationSpeed
	local timeRemainder = timeRotation % (math.pi * 2.0)
	local timeBase =  timeRotation - timeRemainder

	if remainder > timeRemainder then
		bridge.worldTime = (timeBase + remainder) / bridge.sunRotationSpeed
	else
		bridge.worldTime = (timeBase + (math.pi * 2.0) + remainder) / bridge.sunRotationSpeed
	end

	return bridge.worldTime
end

function serverWorld:getCheatsEnabled(clientID)
	if serverWorldSettings:get("cheatsEnabled") then
		return true
	end

	local clientState = clientStates[clientID]
	if clientState then
		local playerID = clientState.playerID
		if playerID then
			if bridge.hostPlayerID == playerID then
				return true
			end
		end
	end

	return false
end


local function startProfile(clientID)
	if serverWorld:getCheatsEnabled(clientID) then
		profiler:start(10.0, function(resultString)
			server:callClientFunction(
				"serverProfileResult",
				clientID,
				resultString
			)
		end)
	end
end

local function setSunriseAtPointNormal(posNormal)
	
	local seasonRotation = math.sin(bridge.worldTime * serverWorld.yearSpeed * math.pi * 2.0)
	local sunTilt = 0.41 * seasonRotation

	local playerXYZ = posNormal
	local latitude = math.asin(posNormal.y)
	local longitude = 0
	if math.abs(playerXYZ.x) + math.abs(playerXYZ.z) > 0.0000001 then
		longitude = math.atan2(playerXYZ.z, playerXYZ.x)
	end

	local hourAngleBase = math.acos(-math.tan(latitude) * math.tan(-sunTilt))

	if not mj:isNan(hourAngleBase) then
		local sunRotation = hourAngleBase + longitude + math.pi * 0.5
		sunRotation = sunRotation + 0.25
		setTimeFromSunRotation(sunRotation)
		--local timeOfDayFraction = serverWorld:getTimeOfDayFraction(posNormal)
		--mj:log("setSunriseAtPointNormal result timeOfDayFraction:", timeOfDayFraction)
	end
end

local function clientRequestAddMoveOrder(clientID, orderData)
	--mj:log("clientRequestAddMoveOrder:", orderData)
	if orderData and orderData.sapienIDs and orderData.moveToPos then
		serverTerrain:updatePlayerAnchor(clientID)
		for i, sapienID in ipairs(orderData.sapienIDs) do
			local sapien = serverGOM:getObjectWithID(sapienID)
			if sapien and sapien.sharedState then
			
				if not serverGOM:clientHasOwnershipPermissions(clientID, sapien) then
					mj:log("attempt to queue move order for non-owned sapien:", sapienID, " by client:", clientID)
					return
				end
				--local orderTypeIndex = orderData.orderTypeIndex
				--if orderTypeIndex == order.types.moveTo.index then
					serverSapien:addMoveOrder(sapien, orderData.moveToPos, orderData.addWaitOrder, orderData.moveToObjectID, orderData.assignBed)
				--end

				--mj:log("add move order:", sapienID)
			--else
				--mj:log("sapien not found with sapienID:", sapienID)
			end
		end
	end
end

local function clientRequestAddWaitOrder(clientID, orderData)
	if orderData and orderData.sapienIDs then
		serverTerrain:updatePlayerAnchor(clientID)
		for i, sapienID in ipairs(orderData.sapienIDs) do
			local sapien = serverGOM:getObjectWithID(sapienID)
			if sapien and sapien.sharedState then
				if not serverGOM:clientHasOwnershipPermissions(clientID, sapien) then
					mj:log("attempt to queue wait order for non-owned sapien:", sapienID, " by client:", clientID)
					return
				end
				
				serverSapien:addWaitOrder(sapien)
			end
		end
	end
end

local function clientRequestCancelWaitOrder(clientID, orderData)
	if orderData and orderData.sapienIDs then
		serverTerrain:updatePlayerAnchor(clientID)
		for i, sapienID in ipairs(orderData.sapienIDs) do
			local sapien = serverGOM:getObjectWithID(sapienID)
			if sapien and sapien.sharedState then
				if not serverGOM:clientHasOwnershipPermissions(clientID, sapien) then
					mj:log("attempt to cancel wait order for non-owned sapien:", sapienID, " by client:", clientID)
					return
				end
				
				serverSapien:cancelWaitOrder(sapien)
			end
		end
	end
end

--[[local function clientRequestAddObjectMoveOrder(clientID, orderData)
	--mj:log("clientRequestAddMoveOrder:", orderData)
	if orderData and orderData.objectIDs and orderData.moveToPos then
		
	end
end]]

local function clientCancelSapienOrders(clientID, userData)
	if userData then
		local sapienIDs = userData.sapienIDs
		serverTerrain:updatePlayerAnchor(clientID)
		for i, sapienID in ipairs(sapienIDs) do
			local sapien = serverGOM:getObjectWithID(sapienID)
			if sapien and sapien.sharedState then
				
				if not serverGOM:clientHasOwnershipPermissions(clientID, sapien) then
					mj:log("attempt to cancel order for non-owned sapien:", sapienID, " by client:" .. mj:tostring(clientID))
					return
				end
				

				if userData.planTypeIndex then
					serverSapien:cancelOrdersMatchingPlanTypeIndex(sapien, userData.planTypeIndex)
				else
					serverSapien:cancelWaitOrder(sapien)
					serverSapien:cancelAllOrders(sapien, false, true)
					local tribeID = clientStates[clientID].privateShared.tribeID
					planManager:cancelAllPlansForObject(tribeID, sapienID)
					local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
					unsavedState.preventUnnecessaryAutomaticOrderTimer = math.max(unsavedState.preventUnnecessaryAutomaticOrderTimer or 0.0, 2.0)
					
					serverSapien:dropHeldInventoryImmediately(sapien)
				end
			end
		end
	end
end

local function cancelAll(clientID, userData)
	if userData then
		serverTerrain:updatePlayerAnchor(clientID)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			local objectIDs = userData.objectIDs
			if objectIDs then
				for i, objectID in ipairs(objectIDs) do
					local object = serverGOM:getObjectWithID(objectID)
					if object and object.sharedState then
						if object.objectTypeIndex == gameObject.types.sapien.index and object.sharedState.tribeID == tribeID then
							local sharedState = object.sharedState
							if sharedState.orderQueue and sharedState.orderQueue[1] then
								serverSapien:cancelAllOrders(object, false, true)
							else
								serverSapien:cancelWaitOrder(object)
							end
						end
						planManager:cancelAllPlansForObject(tribeID, objectID)
					end
				end
			end
			local vertIDs = userData.vertIDs
			if vertIDs then
				for i, vertID in ipairs(vertIDs) do
					planManager:cancelAllPlansForVert(tribeID, vertID)
				end
			end
		end
	end
end

local function multipleClientsConnected()
	return serverWorld.connectedClientCount > 1
end



local function updateSpeed(newSpeedIndex)
	local newSpeed = bridge.speedMultiplier
	if newSpeedIndex then
		if newSpeedIndex == 2 then
			if currentIsSpeedingThroughNight then
				newSpeed = gameConstants.ultraSpeed
			else
				newSpeed = gameConstants.fastSpeed
			end
		elseif newSpeedIndex == 1 then
			newSpeed = gameConstants.playSpeed
		elseif newSpeedIndex == 9 then
			newSpeed = gameConstants.slowMotionSpeed
		else
			newSpeed = gameConstants.pauseSpeed
		end
	else
		newSpeed = gameConstants.playSpeed
	end
	
	bridge:setSpeedMultiplier(newSpeed, newSpeedIndex)
end


local function updateClientSeenListForResourceAddition(tribeID, objectTypeIndex)
	--mj:log("updateClientSeenListForResourceAddition:",objectTypeIndex)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	if clientID and clientStates[clientID] then
		local privateSharedState = clientStates[clientID].privateShared

		if privateSharedState then
			if (not privateSharedState.seenResourceObjectTypes[objectTypeIndex]) then
				privateSharedState.seenResourceObjectTypes[objectTypeIndex] = true

				local typesToSend = {objectTypeIndex}
				local toType = objectTypeIndex

				for i=1,4 do --sanity counter
					local evolution = evolvingObject.evolutions[toType]
					toType = evolution and evolution.toType
					if toType then
						if (not privateSharedState.seenResourceObjectTypes[toType]) then
							table.insert(typesToSend, toType)
							privateSharedState.seenResourceObjectTypes[toType] = true
						end
						
					else
						break
					end
				end

				if serverWorld.connectedClientIDSet[clientID] then
					server:callClientFunction(
						"seenResourceObjectTypesAdded",
						clientID,
						typesToSend
					)
				end

				serverWorld:saveClientState(clientID)
			end
		end
	end

	local destinationState = serverDestination.loadedPlayerOrAITribeDestinationStatesByID[tribeID]
	if destinationState and destinationState.seenResourceObjectTypes then
		if not destinationState.seenResourceObjectTypes[objectTypeIndex] then
			destinationState.seenResourceObjectTypes[objectTypeIndex] = true
			local toType = objectTypeIndex
			for i=1,4 do --sanity counter
				local evolution = evolvingObject.evolutions[toType]
				toType = evolution and evolution.toType
				if toType then
					destinationState.seenResourceObjectTypes[toType] = true
				else
					break
				end
			end
			serverDestination:saveDestinationState(destinationState.destinationID)
		end
	end

end


local function clientRequestSelectStartTribe(clientID, tribeID)
	local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
	if privateSharedState and (not privateSharedState.tribeID) then
		
		local playerOwned = serverWorld:getTribeIsOwnedByPlayer(tribeID, clientID)
		local previousClientID = playerClientIDsByTribeIDs[tribeID]
		local destinationState = serverTribe:clientRequestSelectStartTribe(clientID, tribeID, playerOwned)

		--mj:log("destinationState:", destinationState)
		
		if destinationState then
			if playerOwned or destinationState.failedTribe then --destinationState.failedTribe slightly dubious maybe
				serverWorld:loadClientStateIfNeededForSapienTribeID(tribeID)
				local existingPrivateSharedState = serverWorld:getPrivateSharedClientState(previousClientID)
				if existingPrivateSharedState then
					--mj:log("existingPrivateSharedState:", existingPrivateSharedState)
					serverWorld:setPrivateSharedClientState(clientID, existingPrivateSharedState)
					privateSharedState = existingPrivateSharedState
				end
				--serverWorld:addPlayerControlledTribe(tribeID, clientID)
				--[[playersDatabase:setDataForKey(clientState, clientID)
                playersDatabase:removeDataForKey(otherID)
                playerInfo = clientState

                local worldDatabase = bridge:loadServerDatabase(worldID, "world")
                if worldDatabase then
                    local playerClientIDsByTribeIDs = worldDatabase:dataForKey("tribeList")
                    if playerClientIDsByTribeIDs then
                        for tribeID,otherClientID in pairs(playerClientIDsByTribeIDs) do
                            if otherClientID == otherID then
                                playerClientIDsByTribeIDs[tribeID] = clientID
                                local playerInfos = {
                                    [playerID] = {
                                        tribeIDs = {
                                            [tribeID] = true,
                                        },
                                        playerName = "player",
                                    }
                                }
                                mj:log("setting playerInfos:", playerInfos)
                                worldDatabase:setDataForKey(playerInfos, "playerInfos")
                            end
                        end
                        worldDatabase:setDataForKey(playerClientIDsByTribeIDs, "tribeList")
                    end
                end]]

			else
				local tribeCenter = destinationState.normalizedPos
				privateSharedState.initialTribeCenter = tribeCenter
			end

			privateSharedState.tribeID = destinationState.tribeID
			privateSharedState.tribeName = destinationState.name
			
			if destinationState.seenResourceObjectTypes then
				if not privateSharedState.seenResourceObjectTypes then
					privateSharedState.seenResourceObjectTypes = {}
				end
				for k,v in pairs(destinationState.seenResourceObjectTypes) do
					privateSharedState.seenResourceObjectTypes[k] = v
				end
			end


			if destinationState.craftableDiscoveries then
				for k,v in pairs(destinationState.craftableDiscoveries) do
					if v.complete then
						privateSharedState.craftableDiscoveries[k] = v
					end
				end
			end
			if destinationState.discoveries then
				for k,v in pairs(destinationState.discoveries) do
					if v.complete then
						privateSharedState.discoveries[k] = v
					end
				end
			end

			planHelper:setDiscoveriesForTribeID(destinationState.tribeID, privateSharedState.discoveries, privateSharedState.craftableDiscoveries)
			planManager:sortPlansForNewlyLoadedTribeID(destinationState.tribeID, followerCountsByTribe[tribeID] or 0)

			if not playerOwned then
				local foundExistingTribe = false
				for existingTribeID,existingClientID in pairs(playerClientIDsByTribeIDs) do
					if existingTribeID ~= destinationState.tribeID then
						foundExistingTribe = true
						break
					end
				end
				
				if not foundExistingTribe then 

					local timeOfDayFraction = serverWorld:getTimeOfDayFraction(destinationState.normalizedPos)
					if timeOfDayFraction < 0.2 or timeOfDayFraction > 0.6 then
						setSunriseAtPointNormal(destinationState.normalizedPos)
					end

					creationWorldTime = serverWorld:getWorldTime()
					weather:setCreationWorldTime(creationWorldTime)
					bridge:setCreationWorldTime(creationWorldTime)
					worldDatabase:setDataForKey(creationWorldTime, "creationWorldTime")
					mj:log("setting creation world time:", creationWorldTime)
					server:callClientFunction(
						"creationWorldTimeChanged",
						clientID,
						creationWorldTime
					)
					
				end
			end

			if (not multipleClientsConnected()) then
				updateSpeed(1)
			end
			

			serverGOM:callFunctionForAllSapiensInTribe(destinationState.tribeID, function(sapien)
				if not playerOwned then
					serverSapien:resetSleepForPlayerTribeStart(sapien)
				end
				serverSapien:updateAnchor(sapien) --not sure if needed?

				local inventories = sapien.sharedState.inventories
				if inventories then
					for storageLocationTypeIndex,inventory in pairs(inventories) do
						for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
							if count > 0 then
								updateClientSeenListForResourceAddition(tribeID, objectTypeIndex)
							end
						end
					end
				end
			end)

			serverWorld:saveClientState(clientID)
			serverSapienSkills:updateTribeAllowedTaskLists(privateSharedState.tribeID)
			serverStoryEvents:connectedClientTribeLoaded(privateSharedState.tribeID)

			if not playerOwned then
				serverMobGroup:spawnMigratingMobGroupsForInitialTribeSelection(privateSharedState.tribeID)
			end
			
			
			serverStatistics:setValueForToday(destinationState.tribeID, statistics.types.population.index, followerCountsByTribe[tribeID] + (babyCountsByTribe[tribeID] or 0))
			
			server:callClientFunction(
				"privateSharedClientStateChanged",
				clientID,
				clientStates[clientID].privateShared
			)

			serverDestination:sendDestinationUpdateToAllClients(destinationState)

			return destinationState
		end
	end
	return nil
end


local function clientSetSkillPriority(clientID, orderData)
	if orderData  then
		if orderData.sapienID and orderData.skillTypeIndex and orderData.priority then
			local sapien = serverGOM:getObjectWithID(orderData.sapienID)
			if sapien and sapien.sharedState then
			
				if not serverGOM:clientHasOwnershipPermissions(clientID, sapien) then
					mj:log("attempt to setSkillPriority for non-owned sapien:", orderData.sapienID, " by client:", clientID)
					return
				end

				serverSapien:setSkillPriority(sapien, orderData.skillTypeIndex, orderData.priority)
			else
				mj:log("sapien not found with sapienID:", orderData.sapienID)
			end
		end
	end
end

local function clientMoveAllBetweenSkillPriorities(clientID, orderData)
	if orderData and orderData.skillTypeIndex and orderData.priorityLevelFrom then
		local tribeID = serverWorld:tribeIDForClientID(clientID)
		serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function (objectID) 
			local object = serverGOM:getObjectWithID(objectID)
			if object then
				local state = object.sharedState
				if state and state.tribeID == tribeID then
					if skill:priorityLevel(object, orderData.skillTypeIndex) == orderData.priorityLevelFrom then
						if orderData.priorityLevelTo == 0 or skill:getAssignedRolesCount(object) < skill.maxRoles then
							serverSapien:setSkillPriority(object, orderData.skillTypeIndex, orderData.priorityLevelTo)
						end
					end
				end
			end
		end)
	end
end


local function updateClientData(clientID, pos, dir, mapMode)
	server:updateClientData(clientID, pos, dir, mapMode)
end

local function changeObjectName(clientID, userData)
	local newName = userData.newName
	local objectID = userData.objectID
	if objectID and newName and newName ~= "" then
		serverTerrain:updatePlayerAnchor(clientID)
		serverGOM:changeObjectNameIfAllowed(clientID, objectID, newName)
	end
end


local function doSpeedVoteForConnectedPlayers()
	if throttleSpeedDueToServerLoad and (not currentIsSpeedingThroughNight) then
		updateSpeed(1)
		return 
	end

	local playCount = 0
	local ffCount = 0
	for cID,speedMultiplierIndex in pairs(serverWorld.speedMultiplierIndexByClientID) do
		if speedMultiplierIndex == 2 then
			ffCount = ffCount + 1
		else
			playCount = playCount + 1
		end
	end
	
	if ffCount > playCount then
		updateSpeed(2)
	else
		updateSpeed(1)
	end
end

local function updateClientSpeedPreference(clientID, newSpeed)
	serverWorld.speedMultiplierIndexByClientID[clientID] = newSpeed
	if not multipleClientsConnected() then
		updateSpeed(newSpeed)
	else
		doSpeedVoteForConnectedPlayers()
	end
end


local function setClientPaused(clientID, userData)
	autoSpeedUpRestoreSpeed = nil
	if userData then
		updateClientSpeedPreference(clientID, 0)
	else
		updateClientSpeedPreference(clientID, 1)
	end
end

local restoreSpeedForTemporaryPause = nil

local function setTemporaryPausedIfNonMultiplayer(clientID)
	if not multipleClientsConnected() then
		autoSpeedUpRestoreSpeed = nil
		restoreSpeedForTemporaryPause = bridge.speedMultiplierIndex
		updateClientSpeedPreference(clientID, 0)
	end
end

local function resumeAfterTemporaryPause(clientID)
	if not multipleClientsConnected() then
		updateClientSpeedPreference(clientID, restoreSpeedForTemporaryPause or 1)
	end
end

local function setFastForward(clientID, userData)
	autoSpeedUpRestoreSpeed = nil
	if userData then
		updateClientSpeedPreference(clientID, 2)
	else
		updateClientSpeedPreference(clientID, 1)
	end
end

local function setClientSlowMotion(clientID, userData)
	autoSpeedUpRestoreSpeed = nil
	if userData then
		updateClientSpeedPreference(clientID, 9)
	else
		updateClientSpeedPreference(clientID, 1)
	end
end

function serverWorld:getClientTransientState(clientID)
	return serverWorld.transientClientStates[clientID]
end

function serverWorld:clientConnected(clientID) --serverWorld:loadClientState is called before this, so clientStates has a valid entry at this point
	if not serverWorld.connectedClientIDSet[clientID] then
		serverWorld.connectedClientIDSet[clientID] = true

		local clientState = clientStates[clientID]
		if clientState then
			updateClientData(clientID, clientState.public.pos, clientState.public.dir, clientState.public.mapMode)
		end

		serverWorld.connectedClientCount = serverWorld.connectedClientCount + 1
		updateClientSpeedPreference(clientID, 1)

		serverWorld.transientClientStates[clientID] = {}

		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		if privateSharedState and privateSharedState.initialTribeCenter then
			local resourcesToAssign = serverResourceManager:getAllResourceObjectTypesForTribe(privateSharedState.tribeID)
			for i,objectTypeIndex in ipairs(resourcesToAssign) do
				privateSharedState.seenResourceObjectTypes[objectTypeIndex] = true
			end
			
			serverWorld:saveClientState(clientID)
		end
	end

	local tribeID = serverWorld:tribeIDForClientID(clientID)

    mj:log("client connected: ", mj:tostring(server.namesByClientIDs[clientID]), " clientID:", mj:tostring(clientID), " tribeID:", tribeID)

	if not tribeID then
		setTemporaryPausedIfNonMultiplayer(clientID)
	else
		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		if not privateSharedState.tribeName then
			privateSharedState.tribeName = nameLists:generateTribeName(tribeID, 3634)
		end

		local destinationState = serverDestination:getDestinationState(tribeID)
		if destinationState then
			destinationState.clientDisconnectWorldTime = nil
			serverDestination:ensureLoaded(destinationState)
			serverDestination:saveDestinationState(destinationState.destinationID)
			serverDestination:sendPlayerOnlineStatusChangedToAllClients(destinationState, true)
			serverWorld:updateRecentPlayerTribeListForConnection(tribeID, clientID)
			serverResourceManager:addTribe(destinationState)
		end
	end

	--[[if tribeID then
		serverNotifications:clientConnected(clientID, tribeID)
	end]]


	
	server:callClientFunction(
		"creationWorldTimeChanged",
		clientID,
		creationWorldTime
	)

	server:callClientFunction(
		"speedThrottleChanged",
		clientID,
		throttleSpeedDueToServerLoad
	)
	
	serverWeather:clientConnected(clientID)
	
	serverDestination:sendRecentClientDestinations(clientID)
end

function serverWorld:clientDisconnected(clientID)
	--mj:log("serverWorld:clientDisconnected:", clientID)
	if serverWorld.connectedClientIDSet[clientID] then
		local tribeID = serverWorld:tribeIDForClientID(clientID)
		serverWorld.connectedClientIDSet[clientID] = nil
		serverWorld.speedMultiplierIndexByClientID[clientID] = nil
		serverWorld.transientClientStates[clientID] = {}
		serverWorld.connectedClientCount = serverWorld.connectedClientCount - 1
		if tribeID then
			serverStoryEvents:clientDisconnectedOrFailed(tribeID)

			local destinationState = serverDestination:getDestinationState(tribeID)
			if destinationState then
				destinationState.clientDisconnectWorldTime = serverWorld:getWorldTime()
				--mj:log("serverWorld:clientDisconnected set clientDisconnectWorldTime:", destinationState.clientDisconnectWorldTime)
				serverDestination:loadAndHibernateSingleDestination(destinationState.destinationID, true)
				serverDestination:saveDestinationState(destinationState.destinationID)
				serverDestination:sendPlayerOnlineStatusChangedToAllClients(destinationState, false)
			end
		end

		doSpeedVoteForConnectedPlayers() -- note: we are relying on this to set speed to 1 when last player disconnects
	end
end

function serverWorld:pauseIfNoPlayerTribesLoaded()
	if serverWorld.connectedClientCount <= 0 and bridge.speedMultiplierIndex ~= 0 then

		local foundSimulatingSapiens = false
		for tribeID,sapienCount in pairs(serverGOM.loadedSapienCountsByTribe) do
			if sapienCount > 0 then
				local destinationState = serverDestination:getDestinationState(tribeID)
				if destinationState and destinationState.clientID then
					foundSimulatingSapiens = true
					break
				end
			end
		end
		if not foundSimulatingSapiens then
			mj:log("pausing simulation, as any player tribes are hibernating.")
			updateSpeed(0)
		end
	end
end

--[[function serverWorld:migrateOwner(fromClientID, toClientID)
	if playersDatabase:hasKey(fromClientID) then
		local clientState = playersDatabase:dataForKey(fromClientID)
		playersDatabase:setDataForKey(clientState, toClientID)
		playersDatabase:removeDataForKey(fromClientID)
	end
end]]

function serverWorld:getDefaultDiscoveries()
	return {
		[research.types.gathering.index] = { complete = true },
		[research.types.basicBuilding.index] = { complete = true },
		[research.types.researching.index] = { complete = true },
		[research.types.diplomacy.index] = { complete = true },
		[research.types.handToHandCombat.index] = { complete = true },
	}
end

local function resetClientState(clientID, spawnPos, tribeFailPosition)
	local clientState = clientStates[clientID]

	local failPositions = nil
	if clientState.privateShared then
		failPositions = clientState.privateShared.failPositions
	end

	clientState.public = {}

	clientState.privateShared = {
		skills = {},
		seenResourceObjectTypes = {},
		discoveries = serverWorld:getDefaultDiscoveries(),
		craftableDiscoveries = {},
		discoveriesMigrated = true,
	}

	clientState.private = {
		seenTribes = {}
	}

	if failPositions or tribeFailPosition then
		if not failPositions then
			failPositions = {}
		end
		if tribeFailPosition then
			table.insert(failPositions, tribeFailPosition)
		end
		clientState.privateShared.failPositions = failPositions
	end


	clientState.public.pos = spawnPos
	clientState.public.dir = normalize(cross(normalize(clientState.public.pos), vec3(1.0, 0.0, 0.0)));
	clientState.public.mapMode = mapModes.regional
	playersDatabase:setDataForKey(clientState, clientID)

	--mj:log("resetClientState done")
end

local function migrateClientState_0_6_2(clientID, clientState)
	local privateSharedState = clientState.privateShared
	if not privateSharedState.discoveries[research.types.handToHandCombat.index] then
		privateSharedState.discoveries[research.types.handToHandCombat.index] = { complete = true }
	end
end

local function migrateClientState_b21(clientID, clientState)
	local privateSharedState = clientState.privateShared
	if not privateSharedState.craftableDiscoveries then
		privateSharedState.craftableDiscoveries = {}

		local seenResourceObjectTypes = privateSharedState.seenResourceObjectTypes
		
		for i,constructableType in ipairs(constructable.validTypes) do
			if constructableType.disabledUntilCraftableResearched then
				local foundInEarlierVersion = false
				local outputObjectInfo = constructableType.outputObjectInfo
				if outputObjectInfo then
					if outputObjectInfo.objectTypesArray then
						for j,objectTypeIndex in ipairs(outputObjectInfo.objectTypesArray) do
							if seenResourceObjectTypes[objectTypeIndex] then
								foundInEarlierVersion = true
								break
							end
						end
					elseif outputObjectInfo.outputArraysByResourceObjectType then
						for resourceObjectTypeIndex,objectTypesArray in pairs(outputObjectInfo.outputArraysByResourceObjectType) do
							for j,objectTypeIndex in ipairs(objectTypesArray) do
								if seenResourceObjectTypes[objectTypeIndex] then
									foundInEarlierVersion = true
									break
								end
							end
						end
					end
				else
					local gameObjectTypeKeyOrIndex = constructableType.key
					local craftedObjectTypeIndex = gameObject.types[gameObjectTypeKeyOrIndex].index
					 
					if seenResourceObjectTypes[craftedObjectTypeIndex] then
						foundInEarlierVersion = true
					end
				end
				
				if foundInEarlierVersion then
					privateSharedState.craftableDiscoveries[constructableType.index] = {
						complete = true
					}
				end
			end
		end

		--disable eating of raw meat, to match new default in b21
		local resourcesToDisableEating = {
			resource.types.chickenMeat.index,
			resource.types.alpacaMeat.index,
			resource.types.mammothMeat.index,
			
			resource.types.gingerRoot.index,
			resource.types.turmericRoot.index,
			resource.types.garlic.index,
		}

		local resourceBlockLists = serverWorld:getResourceBlockLists(clientID)
		local eatFoodList = resourceBlockLists.eatFoodList
		if not eatFoodList then
			eatFoodList = {}
			resourceBlockLists.eatFoodList = eatFoodList
		end
		for i, resourceTypeIndex in ipairs(resourcesToDisableEating) do
			local resourceObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
			for j,objectTypeIndex in ipairs(resourceObjectTypes) do
				eatFoodList[objectTypeIndex] = true
			end
		end
	end
end

local function migrateClientState_0_4_0(clientID, clientState)
	local privateSharedState = clientState.privateShared
	if not privateSharedState.discoveriesMigrated then
		mj:log("migrating discoveries to 0.4")
		local newDiscoveries = {}
		for skillTypeIndex,discoveryInfo in pairs(privateSharedState.discoveries) do
			local researchType = research.researchTypesBySkillType[skillTypeIndex]
			if not researchType then
				mj:error("no research type for skill:", skill.types[skillTypeIndex])
			else
				newDiscoveries[researchType.index] = discoveryInfo
			end
		end
		
		privateSharedState.discoveries = newDiscoveries
		privateSharedState.discoveriesMigrated = true
		mj:log("migration complete")
	end
	--mj:log("privateSharedState.discoveries:", privateSharedState.discoveries)
end

function serverWorld:getSpawnPosNearAnyEstablishedTribes()
	if next(serverWorld.validOwnerTribeIDs) then
		local allCenters = {}
		for tribeID,v in pairs(serverWorld.validOwnerTribeIDs) do
			local destinationState = serverDestination:getDestinationState(tribeID)
			if destinationState and destinationState.clientID and destinationState.tribeCenters then
				for i,centerInfo in ipairs(destinationState.tribeCenters) do
					table.insert(allCenters, centerInfo)
				end
			end
		end
		if allCenters[1] then
			return allCenters[rng:randomInteger(#allCenters) + 1].normalizedPos --todo use current player list to derive a location, or allow server config for spawn location
		end
	end
	return server:getSpawnPos()
end

local function getOrCreatePlayerInfo(playerID)
	local playerInfo = playerInfos[playerID]
	if not playerInfo then
		playerInfo = {
			tribeIDs = {}
		}
		playerInfos[playerID] = playerInfo
	end
	return playerInfo
end

local function savePlayerInfos()
	worldDatabase:setDataForKey(playerInfos, "playerInfos")
end

local function assignTribeToPlayer(tribeID, clientID)
	local clientState = clientStates[clientID]
	if clientState then
		local playerID = clientState.playerID
		if playerID then
			local playerInfo = getOrCreatePlayerInfo(playerID)
			playerInfo.tribeIDs[tribeID] = true
			savePlayerInfos()
		end
	end
end

function serverWorld:getTribeIsOwnedByPlayer(tribeID, clientID)
	--mj:log("serverWorld:getTribeIsOwnedByPlayer:", tribeID, " clientID:", clientID)
	if serverWorld.validOwnerTribeIDs[tribeID] then
		--mj:log("a")
		local clientState = clientStates[clientID]
		if clientState then
			--mj:log("b")
			local playerID = clientState.playerID
			if playerID then
				--mj:log("c:", playerInfos)
				local playerInfo = playerInfos[playerID]
				if playerInfo then
					--mj:log("d:", playerInfo)
					return playerInfo.tribeIDs[tribeID] or false
				end
			end
		end
	end
	return false
end

local function sanitizeAndSavePlayerName(playerID, playerName_)
	--mj:log("sanitizeAndSavePlayerName playerID:", playerID, " name:", playerName_)
	local playerName = playerName_ or "player"
	playerName = string.sub(playerName,1,16)
	local playerInfo = getOrCreatePlayerInfo(playerID)
	playerInfo.playerName = playerName
	savePlayerInfos()
end

function serverWorld:loadClientState(clientID, playerID, playerName) --clientID is unique per player per tribe. playerID is unique per player, probably Steam ID

	--mj:log("serverWorld:loadClientState clientID:", clientID, " playerID:", playerID, " playerName:", playerName)
	--mj:log("bridge.hostPlayerID:", bridge.hostPlayerID)

	local tribeID = nil
	local clientState = nil
	if playersDatabase:hasKey(clientID) then
		clientState = playersDatabase:dataForKey(clientID)
		clientStates[clientID] = clientState
		migrateClientState_b21(clientID, clientState)
		migrateClientState_0_4_0(clientID, clientState)
		migrateClientState_0_6_2(clientID, clientState)

		tribeID = clientState.privateShared and clientState.privateShared.tribeID

		if not clientState.playerID then
			clientState.playerID = playerID
			if tribeID then
				assignTribeToPlayer(tribeID, clientID)
			end
		elseif playerID and clientState.playerID ~= playerID then
			mj:error("something went wrong in serverWorld:loadClientState, existing playerID:", clientState.playerID, " doesn't match incoming:", playerID) --world might have been migrated from somewhere else?
			clientState.playerID = playerID
			if tribeID then
				assignTribeToPlayer(tribeID, clientID)
			end
		end
	else
		clientState = {
			playerID = playerID,
		}
		clientStates[clientID] = clientState
	end

	if playerID and playerName then
		sanitizeAndSavePlayerName(playerID, playerName)
	end

	if not tribeID then
		local spawnPos = serverWorld:getSpawnPosNearAnyEstablishedTribes()

		if next(serverWorld.validOwnerTribeIDs) then
			serverTribe:createPlayerSelectionTribesIfNeededNearLocation(spawnPos)
		end
		resetClientState(clientID, spawnPos, nil)
	end

	if clientState.public.pos and mj:isNan(clientState.public.pos.x) then
		clientState.public.pos = server:getSpawnPos()
		clientState.public.dir = normalize(cross(normalize(clientState.public.pos), vec3(1.0, 0.0, 0.0)));
		clientState.public.mapMode = mapModes.regional
	end
	

	--mj:log("clientState:", clientState)

	--mj:log("clientState.public:", clientState.public)

	if serverWorld.connectedClientIDSet[clientID] then
		updateClientData(clientID, clientState.public.pos, clientState.public.dir, clientState.public.mapMode)
	end
	
	if clientState.privateShared.logisticsRoutes then
		serverLogistics:loadClientTribe(clientState.privateShared.tribeID, clientState.privateShared.logisticsRoutes)
	end

	--[[local relationships = serverWorld:getAllTribeRelationsSettings(uiClientTribeID)
	if relationships[userData.tribeID] and relationships[userData.tribeID].storageAlly then
		local otherClientID = serverWorld:clientIDForTribeID(userData.tribeID)]]


	--[[for relationship do 
		if storageAlly then
			serverLogistics:loadClientTribe(allyClientState.privateShared.tribeID, allyClientState.privateShared.logisticsRoutes)
		end
	end]]


	if tribeID then
		planHelper:setDiscoveriesForTribeID(tribeID, clientState.privateShared.discoveries, clientState.privateShared.craftableDiscoveries)
        serverSapienSkills:updateTribeAllowedTaskLists(tribeID)
	end


	serverWorld.transientClientStates[clientID] = {}


	local tribeRelationsSettings = clientState.privateShared.tribeRelationsSettings
	if tribeRelationsSettings then
		for allyTribeID, allyInfo in pairs(tribeRelationsSettings) do
			if allyInfo.storageAlly then
				serverWorld:loadClientStateIfNeededForSapienTribeID(allyTribeID)
				local allyClientID = serverWorld:clientIDForTribeID(allyTribeID)
				local allyPrivateSharedState = serverWorld:getPrivateSharedClientState(allyClientID)
				if allyPrivateSharedState.tribeID then
					serverLogistics:loadClientTribe(allyPrivateSharedState.tribeID, allyPrivateSharedState.logisticsRoutes)
				end
			end
		end
	end

	return clientState
end


function serverWorld:getPlayerIDForClient(clientID)
	local clientState = clientStates[clientID]
	if not clientState then
		clientState = playersDatabase:dataForKey(clientID)
	end

	return clientState and clientState.playerID
end

function serverWorld:getPlayerNameForClient(clientID)
	local playerID = serverWorld:getPlayerIDForClient(clientID)
	if playerID then
		local playerInfo = playerInfos[playerID]
		if playerInfo then
			return playerInfo.playerName
		end
	end
	return "player"
end

function serverWorld:loadClientStateIfNeededForSapienTribeID(tribeID)
	local clientID = playerClientIDsByTribeIDs[tribeID]
	if clientID and (not clientStates[clientID]) and clientID ~= mj.serverClientID then
		serverWorld:loadClientState(clientID, nil)
	end
end

function serverWorld:getPrivateSharedClientState(clientID)
	local clientState = clientStates[clientID]
	if clientState then
		return clientState.privateShared
	end
	return nil
end

function serverWorld:getPrivateClientState(clientID)
	local clientState = clientStates[clientID]
	if clientState then
		return clientState.private
	end
	return nil
end

function serverWorld:getPublicClientState(clientID)
	local clientState = clientStates[clientID]
	if clientState then
		return clientState.public
	end
	return nil
end

function serverWorld:getClientStates()
	return clientStates
end

function serverWorld:getInitialWorldDataForClientConnection(clientID)
	return {
		public = clientStates[clientID].public,
		privateShared = clientStates[clientID].privateShared,
		welcomeMessage = worldConfig.configData.welcomeMessage,
		gameConstantsConfig = worldConfig:getClientGameConstantsConfig(),
	}
end

function serverWorld:clientIDForTribeID(tribeID)
	return playerClientIDsByTribeIDs[tribeID]
end

function serverWorld:tribeIDForClientID(clientID)
	local clientState = clientStates[clientID]
	if clientState then
		return clientState.privateShared.tribeID
	end
	return nil
end

function serverWorld:saveClientState(clientID)
	playersDatabase:setDataForKey(clientStates[clientID], clientID)
end

function serverWorld:setPrivateSharedClientState(clientID, privateShared)
	clientStates[clientID].privateShared = privateShared
	serverWorld:saveClientState(clientID)
end

function serverWorld:updateRecentPlayerTribeListForConnection(tribeID, clientID)
	table.insert(serverWorld.recentPlayerTribeList, 1, {
		tribeID = tribeID,
		clientID = clientID,
	})
	for i,recentPlayerInfo in ipairs(serverWorld.recentPlayerTribeList) do
		if i > 1 and recentPlayerInfo.tribeID == tribeID and recentPlayerInfo.clientID == clientID then
			table.remove(serverWorld.recentPlayerTribeList, i)
			break
		end
	end
	if #serverWorld.recentPlayerTribeList > serverWorld.recentPlayerTribeListMaxSize then
		table.remove(serverWorld.recentPlayerTribeList)
	end

	worldDatabase:setDataForKey(serverWorld.recentPlayerTribeList, "recentPlayerTribeList")
end

function serverWorld:addPlayerControlledTribe(tribeID, clientID)
	playerClientIDsByTribeIDs[tribeID] = clientID
	worldDatabase:setDataForKey(playerClientIDsByTribeIDs, "tribeList")
	assignTribeToPlayer(tribeID, clientID)
	serverWorld:updateRecentPlayerTribeListForConnection(tribeID, clientID)
end

function serverWorld:clientWithTribeIDHasSeenTribeID(clientTribeID, otherTribeID)
	--mj:log("serverWorld:clientWithTribeIDHasSeenTribeID clientTribeID:", clientTribeID, " otherTribeID:", otherTribeID)
	if clientTribeID == otherTribeID then
		return true
	end
	local clientID = playerClientIDsByTribeIDs[clientTribeID]
	--mj:log("clientID:", clientID)
	if clientID then
	--	mj:log("clientStates[clientID]:", clientStates[clientID])
		local clientState = clientStates[clientID]
		if clientState then
			local seenTribes = clientState.private.seenTribes
			if seenTribes and seenTribes[otherTribeID] then
				return true
			end
			return false
		end
	end
	return true
end

function serverWorld:addTribeToSeenList(clientTribeID, otherTribeID) --also sets the seen time
	--mj:log("serverWorld:addTribeToSeenList:", clientTribeID, " otherTribeID:", otherTribeID)
	local clientID = playerClientIDsByTribeIDs[clientTribeID]
	if clientID then
		--mj:log("clientID:", clientID)
		local clientState = clientStates[clientID]
		--mj:log("clientState:", clientState)
		if clientState then
			--mj:log("clientState.private.seenTribes[otherTribeID] = true")
			clientState.private.seenTribes[otherTribeID] = serverWorld:getWorldTime() --WARNING! we used to set this to true. saved world state may have true values in seenTribes 
			serverWorld:saveClientState(clientID)
		end
	end
end

function serverWorld:getLastSeenNotificationSentTime(clientTribeID, otherTribeID)
	local clientID = playerClientIDsByTribeIDs[clientTribeID]
	if clientID then
		--mj:log("clientID:", clientID)
		local clientState = clientStates[clientID]
		--mj:log("clientState:", clientState)
		if clientState then
			local seenTribeValue = clientState.private.seenTribes[otherTribeID]
			if type(seenTribeValue) == "number" then
				return seenTribeValue
			end
		end
	end
	return 0
end

--[[function serverWorld:addObjectTypeIndexToSeenResourceList(objectTypeIndex, clientID)
	local privateSharedState = clientStates[clientID].privateShared
	if privateSharedState and not privateSharedState.seenResourceObjectTypes[objectTypeIndex] then
		privateSharedState.seenResourceObjectTypes[objectTypeIndex] = true
		serverWorld:saveClientState(clientID)
	end
end]]


local clientTribeIDsNeedingPlanChangeNotifcations = {}

function serverWorld:notifyClientOfPlanCountChange(tribeID, queuedCount, maxPlanCount)
	clientTribeIDsNeedingPlanChangeNotifcations[tribeID] = {
		queuedCount = queuedCount,
		maxPlanCount = maxPlanCount,
	}
end

function serverWorld:seenResourceObjectTypesForTribe(tribeID)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	if clientID and clientID ~= mj.serverClientID then
		local clientState = clientStates[clientID]
		if clientState then
			return clientState.privateShared.seenResourceObjectTypes
		end
	else
		local destinationState = serverDestination.loadedPlayerOrAITribeDestinationStatesByID[tribeID]
		if destinationState then
			return destinationState.seenResourceObjectTypes
		end
	end


	return nil
end

serverResourceManager:setUpdateClientSeenListFunction(updateClientSeenListForResourceAddition)

function serverWorld:terrainFinishedLoadingForClient(clientID)

	mj:log("serverWorld:terrainFinishedLoadingForClient a")
	local privateSharedState = clientStates[clientID].privateShared
	local tribeID = privateSharedState.tribeID
	if tribeID then
		local destinationState = serverDestination:getDestinationState(tribeID, false)
		serverDestination:ensureLoaded(destinationState)
		serverWorld:updateFollowerCount(tribeID) --can cause a tribe fail, which is why we grab a new privateSharedState below
		serverGOM:sendInitialClientFollowersList(tribeID)
		privateSharedState = clientStates[clientID].privateShared
		tribeID = privateSharedState.tribeID
		mj:log("serverWorld:terrainFinishedLoadingForClient b")
	end

	if tribeID then
        serverSapienSkills:updateTribeAllowedTaskLists(tribeID)
		serverStoryEvents:connectedClientTribeLoaded(tribeID)
		planHelper:setDiscoveriesForTribeID(tribeID, privateSharedState.discoveries, privateSharedState.craftableDiscoveries)
		planManager:sortPlansForNewlyLoadedTribeID(tribeID, followerCountsByTribe[tribeID] or 0)
		--mj:log("clientFollowerCount:", followerCountsByTribe[tribeID])
	else
		server:callClientFunction(
			"initialFollowersList",
			clientID,
			{}
		)
	end
	--serverTribe:sendTribes(clientID)
	--mj:error("send b:", clientStates[clientID])
	--m:log("clientID:", clientID, " tribeID:", tribeID)
	server:callClientFunction(
		"privateSharedClientStateChanged",
		clientID,
		privateSharedState
	)
	server:callClientFunction(
		"validOwnerTribeIDsChanged",
		clientID,
		serverWorld.validOwnerTribeIDs
	)
	
end

function serverWorld:startDiscoveryForTribe(tribeID, researchTypeIndex, planObjectID)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local privateSharedState = clientStates[clientID].privateShared
	local discoveryInfo = privateSharedState.discoveries[researchTypeIndex]
	local complete = false
	if discoveryInfo then
		complete = discoveryInfo.complete
	end

	if (not complete) then
		if not privateSharedState.discoveries[researchTypeIndex] then
			privateSharedState.discoveries[researchTypeIndex] = {
				assigned = true,
				planObjectID = planObjectID,
			}
		else
			privateSharedState.discoveries[researchTypeIndex].assigned = true
			privateSharedState.discoveries[researchTypeIndex].planObjectID = planObjectID
		end
		server:callClientFunction(
			"discoveriesChanged",
			clientID,
			privateSharedState.discoveries
		)
		serverWorld:saveClientState(clientID)
	end
end

function serverWorld:startCraftableDiscoveryForTribe(tribeID, discoveryCraftableTypeIndex, planObjectID)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local privateSharedState = clientStates[clientID].privateShared
	local discoveryInfo = privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex]
	local complete = false
	if discoveryInfo then
		complete = discoveryInfo.complete
	end

	if (not complete) then
		if not privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] then
			privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] = {}
		end
		server:callClientFunction(
			"craftableDiscoveriesChanged",
			clientID,
			privateSharedState.craftableDiscoveries
		)
		serverWorld:saveClientState(clientID)
	end
end

function serverWorld:getPlanObjectIDForCraftableDiscoveryForTribe(tribeID, discoveryCraftableTypeIndex)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return nil
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] then
			return privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].planObjectID
		end
	end
	return nil
end

function serverWorld:cancelDiscoveryPlanForTribe(tribeID, researchTypeIndex)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if privateSharedState.discoveries[researchTypeIndex] and (not privateSharedState.discoveries[researchTypeIndex].complete) then
			privateSharedState.discoveries[researchTypeIndex].assigned = nil
			server:callClientFunction(
				"discoveriesChanged",
				clientID,
				privateSharedState.discoveries
			)
			serverWorld:saveClientState(clientID)
		end
	end
end

function serverWorld:cancelCraftableDiscoveryPlanForTribe(tribeID, discoveryCraftableTypeIndex)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] and (not privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].complete) then
			privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].assigned = nil
			server:callClientFunction(
				"craftableDiscoveriesChanged",
				clientID,
				privateSharedState.craftableDiscoveries
			)
			serverWorld:saveClientState(clientID)
		end
	end
end

function serverWorld:removeDiscoveryOrCraftableDiscoveryPlanForTribe(tribeID, researchTypeIndex, discoveryCraftableTypeIndexOrNil)
	if discoveryCraftableTypeIndexOrNil and serverWorld:discoveryIsCompleteForTribe(tribeID, researchTypeIndex) then
		serverWorld:cancelCraftableDiscoveryPlanForTribe(tribeID, discoveryCraftableTypeIndexOrNil)
	else
		serverWorld:cancelDiscoveryPlanForTribe(tribeID, researchTypeIndex)
	end
end

function serverWorld:completeAllDiscoveriesCheat(clientID) -- this is a cheat function
	local clientState = clientStates[clientID]
	if clientState then
		local tribeID = serverWorld:tribeIDForClientID(clientID)
		local privateSharedState = clientState.privateShared

		local foundCraftableDiscovery = false
		local foundDiscovery = false
		for i,researchType in ipairs(research.validTypes) do

			if (not privateSharedState.discoveries[researchType.index])  or (not privateSharedState.discoveries[researchType.index].complete) then
				privateSharedState.discoveries[researchType.index] = {
					complete = true
				}
				foundDiscovery = true
			end
			planManager:cancelResearchPlansForDiscoveryResearchCompletion(tribeID, researchType.index)

			local craftableDiscoveries = privateSharedState.craftableDiscoveries
			if not craftableDiscoveries then
				craftableDiscoveries = {}
				privateSharedState.craftableDiscoveries = craftableDiscoveries
			end

			if researchType.constructableTypeIndexesByBaseResourceTypeIndex then
				for resourceTypeIndex,researchConstructableTypeIndex in pairs(researchType.constructableTypeIndexesByBaseResourceTypeIndex) do
					local constructableType = constructable.types[researchConstructableTypeIndex]
					if constructableType.disabledUntilCraftableResearched then
						if (not craftableDiscoveries[researchConstructableTypeIndex]) or (not craftableDiscoveries[researchConstructableTypeIndex].complete) then
							craftableDiscoveries[researchConstructableTypeIndex] = {
								complete = true
							}
							foundCraftableDiscovery = true
							planManager:updateResearchPlansForCraftableDiscoveryResearchCompletion(tribeID, researchConstructableTypeIndex)
						end
					end
				end
			elseif researchType.constructableTypeIndexArraysByBaseResourceTypeIndex then
				for resourceTypeIndex,researchConstructableTypeIndexArrays in pairs(researchType.constructableTypeIndexArraysByBaseResourceTypeIndex) do
					for j, researchConstructableTypeIndex in ipairs(researchConstructableTypeIndexArrays) do
						local constructableType = constructable.types[researchConstructableTypeIndex]
						if constructableType.disabledUntilCraftableResearched then
							if (not craftableDiscoveries[researchConstructableTypeIndex]) or (not craftableDiscoveries[researchConstructableTypeIndex].complete) then
								craftableDiscoveries[researchConstructableTypeIndex] = {
									complete = true
								}
								foundCraftableDiscovery = true
								planManager:updateResearchPlansForCraftableDiscoveryResearchCompletion(tribeID, researchConstructableTypeIndex)
							end
						end
					end
				end
			end
		end

		if foundDiscovery then
			server:callClientFunction(
				"discoveriesChanged",
				clientID,
				privateSharedState.discoveries
			)
		end

		if foundCraftableDiscovery then
			server:callClientFunction(
				"craftableDiscoveriesChanged",
				clientID,
				privateSharedState.craftableDiscoveries
			)
		end

		serverWorld:saveClientState(clientID)
	
		planHelper:updateCompletedSkillsForDiscoveriesChange(tribeID)

	end
end
function serverWorld:completeDiscoveryForTribe(tribeID, researchTypeIndex, discoveryCraftableTypeIndexToComplete)

	--mj:debug("serverWorld:completeDiscoveryForTribe:", researchTypeIndex, " discoveryCraftableTypeIndexToComplete:", discoveryCraftableTypeIndexToComplete)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared

		if (not privateSharedState.discoveries[researchTypeIndex])  or (not privateSharedState.discoveries[researchTypeIndex].complete) then
			privateSharedState.discoveries[researchTypeIndex] = {
				complete = true
			}

			if discoveryCraftableTypeIndexToComplete then
				serverWorld:completeCraftableDiscoveryForTribe(tribeID, discoveryCraftableTypeIndexToComplete)
			end
			
			serverWorld:saveClientState(clientID)
			planHelper:updateCompletedSkillsForDiscoveriesChange(tribeID)

			--each sapien in the tribe, if researching currently, roll the dice to give them the skill
			local craftableDiscoveriesChanged = false
			serverGOM:callFunctionForAllSapiensInTribe(tribeID, function(sapien)
				local orderState = sapien.sharedState.orderQueue and sapien.sharedState.orderQueue[1]
				if orderState and orderState.context and orderState.context.researchTypeIndex == researchTypeIndex then
					local skillFractionComplete = rng:randomValue() + 0.3
					--mj:log("assigning skills for other researching sapien:", sapien.uniqueID, " skillFractionComplete:", skillFractionComplete)
					if skillFractionComplete >= 1.0 then
						serverSapienSkills:completeSapienSkillsForResearchCompletion(sapien, researchTypeIndex)
					else
						serverSapienSkills:givePartialSkillForResearchCompletion(sapien, researchTypeIndex, skillFractionComplete)
					end

					-- partially complete the other discoveryCraftableTypeIndex for this research
					if discoveryCraftableTypeIndexToComplete then
						local thisSapienDiscoveryCraftableTypeIndex = orderState.context.discoveryCraftableTypeIndex
						if (not thisSapienDiscoveryCraftableTypeIndex) then
							local orderObject = serverGOM:getObjectWithID(orderState.objectID)
							if orderObject and orderObject.sharedState then --bit of an ambulance, hopefully we should always have this set in the orderContext now
								local planStates = orderObject.sharedState.planStates and orderObject.sharedState.planStates[tribeID]
								if planStates then
									for i,planState in ipairs(planStates) do
										if planState.researchTypeIndex == researchTypeIndex then
											thisSapienDiscoveryCraftableTypeIndex = planState.constructableTypeIndex
											break
										end
									end
								end
							end
						end

						if thisSapienDiscoveryCraftableTypeIndex and thisSapienDiscoveryCraftableTypeIndex ~= discoveryCraftableTypeIndexToComplete then

							local craftableDiscoveries = privateSharedState.craftableDiscoveries
							if not craftableDiscoveries then
								craftableDiscoveries = {}
								privateSharedState.craftableDiscoveries = craftableDiscoveries
							end

							if not privateSharedState.craftableDiscoveries[thisSapienDiscoveryCraftableTypeIndex] then
								privateSharedState.craftableDiscoveries[thisSapienDiscoveryCraftableTypeIndex] = {
									fractionComplete = mjm.clamp(rng:randomValue(), 0.01, 0.99),
								}
							else
								local currentFraction = privateSharedState.craftableDiscoveries[thisSapienDiscoveryCraftableTypeIndex].fractionComplete or 0.0
								privateSharedState.craftableDiscoveries[thisSapienDiscoveryCraftableTypeIndex].fractionComplete = currentFraction + mjm.clamp((1.0 - currentFraction) * rng:randomValue(), 0.01, 0.99)
							end

							--mj:log("added to other discovery:", craftableDiscoveries)
							craftableDiscoveriesChanged = true
						end
					end
				end
			end)
			
			server:callClientFunction(
				"discoveriesChanged",
				clientID,
				privateSharedState.discoveries
			)

			if craftableDiscoveriesChanged then
				server:callClientFunction(
					"craftableDiscoveriesChanged",
					clientID,
					privateSharedState.craftableDiscoveries
				)
			end


		end
	else
		local destinationState = serverDestination:getDestinationState(tribeID)
		if destinationState then
			if not destinationState.discoveries then
				destinationState.discoveries = {}
			end
			destinationState.discoveries[researchTypeIndex] = {
				complete = true
			}

			if discoveryCraftableTypeIndexToComplete then
				serverWorld:completeCraftableDiscoveryForTribe(tribeID, discoveryCraftableTypeIndexToComplete)
			end

			serverDestination:saveDestinationState(tribeID)
			planHelper:updateCompletedSkillsForDiscoveriesChange(tribeID)
		end
	end
	
	if discoveryCraftableTypeIndexToComplete and constructable.types[discoveryCraftableTypeIndexToComplete].disabledUntilCraftableResearched then
		--mj:log("calling planManager:updateResearchPlansForCraftableDiscoveryResearchCompletion")
		planManager:updateResearchPlansForCraftableDiscoveryResearchCompletion(tribeID, discoveryCraftableTypeIndexToComplete)
	else
		--mj:log("calling planManager:cancelResearchPlansForDiscoveryResearchCompletion")
		planManager:cancelResearchPlansForDiscoveryResearchCompletion(tribeID, researchTypeIndex)
	end

	--maybe?
	local constructableTypeIndex = research.types[researchTypeIndex].constructableTypeIndex
	if constructableTypeIndex then
		planManager:updateResearchPlansForCraftableDiscoveryResearchCompletion(tribeID, constructableTypeIndex)
	end
end

function serverWorld:completeCraftableDiscoveryForTribe(tribeID, discoveryCraftableTypeIndex)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if (not privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex])  or (not privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].complete) then
			privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] = {
				complete = true
			}
			server:callClientFunction(
				"craftableDiscoveriesChanged",
				clientID,
				privateSharedState.craftableDiscoveries
			)
			serverWorld:saveClientState(clientID)
		end
	else
		local destinationState = serverDestination:getDestinationState(tribeID)
		if destinationState then
			if not destinationState.craftableDiscoveries then
				destinationState.craftableDiscoveries = {}
			end
			destinationState.craftableDiscoveries[discoveryCraftableTypeIndex] = {
				complete = true
			}
			serverDestination:saveDestinationState(tribeID)
		end
	end

	planManager:updateResearchPlansForCraftableDiscoveryResearchCompletion(tribeID, discoveryCraftableTypeIndex)
end

function serverWorld:discoveryIsCompleteForTribe(tribeID, researchTypeIndex)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		return privateSharedState.discoveries[researchTypeIndex] and privateSharedState.discoveries[researchTypeIndex].complete
	end
	return false
end


function serverWorld:craftableDiscoveryIsCompleteForTribe(tribeID, discoveryCraftableTypeIndex)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return false
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		return privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] and privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].complete
	end
	return false
end

function serverWorld:increaseDiscoveryForRecruitedSkill(recruitedSapien, tribeID, skillTypeIndex, newDiscoveryFraction)
	mj:log("serverWorld:increaseDiscoveryForRecruitedSkill:", skillTypeIndex, " newDiscoveryFraction:", newDiscoveryFraction)
	local researchType = research.researchTypesBySkillType[skillTypeIndex]
	if not researchType then
		return
	end
	local researchTypeIndex = researchType.index
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared

		local changed = false
		if not privateSharedState.discoveries[researchType.index] then
			privateSharedState.discoveries[researchTypeIndex] = {
				fractionComplete = newDiscoveryFraction,
			}
			changed = true
		elseif (not privateSharedState.discoveries[researchTypeIndex].complete) and privateSharedState.discoveries[researchTypeIndex].fractionComplete and newDiscoveryFraction > privateSharedState.discoveries[researchTypeIndex].fractionComplete then
			privateSharedState.discoveries[researchTypeIndex].fractionComplete = newDiscoveryFraction
			changed = true
		end
		

		if changed then
			mj:log("serverWorld:increaseDiscoveryForRecruitedSkill success")
			server:callClientFunction( --todo optimize this, just send through the updated fraction
				"discoveriesChanged",
				clientID,
				privateSharedState.discoveries
			)
			
			serverGOM:sendNotificationForObject(recruitedSapien, notification.types.recruitmentIncreasedDiscovery.index, {
				skillTypeIndex = skillTypeIndex,
				researchTypeIndex = researchTypeIndex,
			}, tribeID)

			serverWorld:saveClientState(clientID)
		end
	end
end

function serverWorld:incrementDiscovery(tribeID, researchTypeIndex, discoveryCraftableTypeIndexToComplete, combinedIncrement)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if not privateSharedState.discoveries[researchTypeIndex] then
			privateSharedState.discoveries[researchTypeIndex] = {
				fractionComplete = combinedIncrement,
			}
		else
			local currentFraction = privateSharedState.discoveries[researchTypeIndex].fractionComplete or 0.0
			
			--mj:log("serverWorld:incrementDiscovery currentFraction + combinedIncrement:", currentFraction + combinedIncrement, " skillTypeIndex:", skillTypeIndex)
			privateSharedState.discoveries[researchTypeIndex].fractionComplete = currentFraction + combinedIncrement
			if privateSharedState.discoveries[researchTypeIndex].fractionComplete >= 1.0 then
				serverWorld:completeDiscoveryForTribe(tribeID, researchTypeIndex, discoveryCraftableTypeIndexToComplete)
				return true
			end
		end
		
		server:callClientFunction( --todo optimize this, just send through the updated fraction
			"discoveriesChanged",
			clientID,
			privateSharedState.discoveries
		)
		serverWorld:saveClientState(clientID)
	end
	return false
end



function serverWorld:incrementDiscovery(tribeID, researchTypeIndex, discoveryCraftableTypeIndexToComplete, combinedIncrement)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if not privateSharedState.discoveries[researchTypeIndex] then
			privateSharedState.discoveries[researchTypeIndex] = {
				fractionComplete = combinedIncrement,
			}
		else
			local currentFraction = privateSharedState.discoveries[researchTypeIndex].fractionComplete or 0.0
			
			--mj:log("serverWorld:incrementDiscovery currentFraction + combinedIncrement:", currentFraction + combinedIncrement, " skillTypeIndex:", skillTypeIndex)
			privateSharedState.discoveries[researchTypeIndex].fractionComplete = currentFraction + combinedIncrement
			if privateSharedState.discoveries[researchTypeIndex].fractionComplete >= 1.0 then
				serverWorld:completeDiscoveryForTribe(tribeID, researchTypeIndex, discoveryCraftableTypeIndexToComplete)
				return true
			end
		end
		
		server:callClientFunction( --todo optimize this, just send through the updated fraction
			"discoveriesChanged",
			clientID,
			privateSharedState.discoveries
		)
		serverWorld:saveClientState(clientID)
	end
	return false
end


function serverWorld:incrementCraftableDiscovery(tribeID, discoveryCraftableTypeIndex, combinedIncrement)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return false
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if not privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] then
			privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] = {
				fractionComplete = combinedIncrement,
			}
		else
			local currentFraction = privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].fractionComplete or 0.0
			
			--mj:log("serverWorld:incrementCraftableDiscovery currentFraction:", currentFraction, " currentFraction + combinedIncrement:", currentFraction + combinedIncrement, " discoveryCraftableTypeIndex:", discoveryCraftableTypeIndex)
			privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].fractionComplete = currentFraction + combinedIncrement
			if privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].fractionComplete >= 1.0 then
				serverWorld:completeCraftableDiscoveryForTribe(tribeID, discoveryCraftableTypeIndex)
				--mj:log("complete discovery")
				return true
			end
		end
		
		server:callClientFunction( --todo optimize this, just send through the updated fraction
			"craftableDiscoveriesChanged",
			clientID,
			privateSharedState.craftableDiscoveries
		)
		serverWorld:saveClientState(clientID)
	end
	return false
end


function serverWorld:discoveryIncrementWouldComplete(tribeID, researchTypeIndex, combinedIncrement)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared

		local currentFraction = 0.0
		if privateSharedState.discoveries[researchTypeIndex] then
			currentFraction = privateSharedState.discoveries[researchTypeIndex].fractionComplete or 0.0
		end

		--mj:log("serverWorld:discoveryIncrementWouldComplete currentFraction + combinedIncrement:", currentFraction + combinedIncrement, " skillTypeIndex:", skillTypeIndex)
		
		if currentFraction + combinedIncrement >= 1.0 then
			return true
		end
	end
	return false
end

function serverWorld:craftableDiscoveryIncrementWouldComplete(tribeID, discoveryCraftableTypeIndex, combinedIncrement)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return false
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared

		local currentFraction = 0.0
		if privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] then
			currentFraction = privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].fractionComplete or 0.0
		end

		--mj:log("serverWorld:discoveryIncrementWouldComplete currentFraction + combinedIncrement:", currentFraction + combinedIncrement, " skillTypeIndex:", skillTypeIndex)
		
		if currentFraction + combinedIncrement >= 1.0 then
			return true
		end
	end
	return false
end

function serverWorld:discoveryCompletionFraction(tribeID, researchTypeIndex)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if privateSharedState.discoveries[researchTypeIndex] then
			return privateSharedState.discoveries[researchTypeIndex].fractionComplete or 0.0
		end
	end
	return 0.0
end


function serverWorld:craftableDiscoveryCompletionFraction(tribeID, discoveryCraftableTypeIndex)
	if (not discoveryCraftableTypeIndex) or (not constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched) then
		return 0.0
	end
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		if privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex] then
			return privateSharedState.craftableDiscoveries[discoveryCraftableTypeIndex].fractionComplete or 0.0
		end
	end
	return 0.0
end

local skillPriorityListChangedByTribeID = nil

function serverWorld:skillPrioritiesOrLimitedAbilityChanged(tribeID)
    if not skillPriorityListChangedByTribeID then
        skillPriorityListChangedByTribeID = {}
    end
    skillPriorityListChangedByTribeID[tribeID] = true
end


function serverWorld:getResourceBlockLists(clientID)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		local resourceBlockLists = privateSharedState.resourceBlockLists
		if not resourceBlockLists then
			resourceBlockLists = gameObject:getDefaultBlockLists(fuel)
			privateSharedState.resourceBlockLists = resourceBlockLists
			server:callClientFunction(
				"privateSharedClientStateChanged",
				clientID,
				clientStates[clientID].privateShared
			)
		end
		return resourceBlockLists
	end
	return nil
end

function serverWorld:getResourceBlockListsForTribe(tribeID)
	return serverWorld:getResourceBlockLists(serverWorld:clientIDForTribeID(tribeID))
end

function serverWorld:getResourceBlockListForConstructableTypeIndex(tribeID, constructableTypeIndex, appendBlocklistOrNil)
	if not constructableTypeIndex then
		return appendBlocklistOrNil
	end
	local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
	if resourceBlockLists then
		local foundTribeBlockList = nil
		local constructableLists = resourceBlockLists.constructableLists
		if constructableLists then
			local constructableBlockList = constructableLists[constructableTypeIndex]
			if constructableBlockList and next(constructableBlockList) then
				foundTribeBlockList = constructableBlockList
			end
		end
		
		if foundTribeBlockList and next(foundTribeBlockList) then
			if appendBlocklistOrNil and next(appendBlocklistOrNil) then
				local result = mj:cloneTable(foundTribeBlockList)
				for k,v in pairs(appendBlocklistOrNil) do
					result[k] = v
				end
				return result
			end
			return foundTribeBlockList
		end
	end

	return appendBlocklistOrNil
end

function serverWorld:getNonBlockedFoodObjectTypes(tribeID)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	local transientState = serverWorld.transientClientStates[clientID]
	if transientState then
		if transientState.nonBlockedFoodObjectTypes then
			return transientState.nonBlockedFoodObjectTypes
		end

		local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
        if resourceBlockLists then
			local eatFoodBlockList = resourceBlockLists.eatFoodList
			if eatFoodBlockList and next(eatFoodBlockList) then
				local allowedList = {}
				transientState.nonBlockedFoodObjectTypes = allowedList
				for i, foodObjectTypeIndex in ipairs(gameObject.foodObjectTypes) do
					if not eatFoodBlockList[foodObjectTypeIndex] then
						table.insert(allowedList, foodObjectTypeIndex)
					end
				end
				return allowedList
			end
		end

		transientState.nonBlockedFoodObjectTypes = gameObject.foodObjectTypes
	end
	return gameObject.foodObjectTypes
end



function serverWorld:getNonBlockedClothingTypesForInventoryLocations(tribeID, allowedLocations)

	local wearClothingBlockList = {}
	local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
	if resourceBlockLists and resourceBlockLists.wearClothingList then
		wearClothingBlockList = resourceBlockLists.wearClothingList
	end

	
	local result = {}
	for i, allowedLocation in ipairs(allowedLocations) do
		local clothingTypesByLocation = gameObject.clothingTypesByInventoryLocations[allowedLocation]
		if clothingTypesByLocation then
			for j,clothingObjectTypeIndex in ipairs(clothingTypesByLocation) do
				if not wearClothingBlockList[clothingObjectTypeIndex] then
					table.insert(result, clothingObjectTypeIndex)
				end
			end
		end
	end

	return result
end

function serverWorld:getNonBlockedMedicineTypes(tribeID) --no caching here, seems less necessary than food
	local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
	if resourceBlockLists then
		local medicineList = resourceBlockLists.medicineList
		if medicineList and next(medicineList) then
			local allowedList = {}
			for i,objectTypeIndex in ipairs(gameObject.medicineObjectTypes) do
				if not medicineList[objectTypeIndex] then
					table.insert(allowedList, objectTypeIndex)
				end
			end
			return allowedList
		end
	end
	return gameObject.medicineObjectTypes
end

function serverWorld:getResourceBlockListForMedicineTreatment(tribeID, appendBlocklistOrNil)
	local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
	if resourceBlockLists then
		local medicineList = resourceBlockLists.medicineList
		
		if medicineList and next(medicineList) then
			if appendBlocklistOrNil and next(appendBlocklistOrNil) then
				local result = mj:cloneTable(medicineList)
				for k,v in pairs(appendBlocklistOrNil) do
					result[k] = v
				end
				return result
			end
			return medicineList
		end
	end

	return appendBlocklistOrNil
end



function serverWorld:getResourceBlockListForFuel(tribeID, fuelGroupIndex, appendBlocklistOrNil)
	if fuelGroupIndex then
		local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
		if resourceBlockLists then
			local fuelBlockLists = resourceBlockLists.fuelLists
			if fuelBlockLists then
				local fuelBlockList = fuelBlockLists[fuelGroupIndex]
				
				if fuelBlockList and next(fuelBlockList) then
					if appendBlocklistOrNil and next(appendBlocklistOrNil) then
						local result = mj:cloneTable(fuelBlockList)
						for k,v in pairs(appendBlocklistOrNil) do
							result[k] = v
						end
						return result
					end
					return fuelBlockList
				end
			end
		end
	end

	return appendBlocklistOrNil
end


local function clientUpdate(clientID, userData)
	--mj:log("clientUpdate:", userData)
	local clientState = clientStates[clientID]
	if clientState then
		local privateSharedState = clientState.privateShared
		
		clientState.public.pos = userData.pos 
		clientState.public.dir = userData.dir
		if clientState.privateShared.tribeID then
			clientState.public.mapMode = userData.mapMode
		else
			clientState.public.mapMode = mapModes.regional
		end

		local posToUseForTerrain = userData.pos

		if not privateSharedState.tribeID then
			clientState.public.pos = userData.mapPos 
			posToUseForTerrain = userData.mapPos
		elseif userData.mapMode and userData.mapMode ~= 0 then
			posToUseForTerrain = userData.mapPos
		end

		serverDestination:queueSendDestinationInfoForClient(clientID, posToUseForTerrain, userData.mapMode)

		--mj:log("serverTerrain:getHasRemovedTransientObjectsNearPos(pos):", serverTerrain:getHasRemovedTransientObjectsNearPos(posToUseForTerrain))

		--mj:log("clientID:", clientID, "setting client state:", clientState)

		playersDatabase:setDataForKey(clientState, clientID)

		--mj:log("updateClientData")
		updateClientData(clientID, posToUseForTerrain, userData.dir, userData.mapMode)
	end
	
end

local function maxFollowerNeeds(clientID, sapienIDs) --this is a cheat function
	--mjs:printDebug()
	serverSapien:maxFollowerNeeds(sapienIDs)
end

local function changeStorageAreaConfig(clientID, userData)
	local object = serverGOM:getObjectWithID(userData.storageAreaObjectID)
	if object then
		local tribeID = serverWorld:tribeIDForClientID(clientID)
		serverStorageArea:changeStorageAreaConfig(object, userData, tribeID)
	else
		mj:warn("Failed to changeStorageAreaConfig")
	end

end

local function clientRequestUnloadedObject(clientID, userData)
	local object = serverGOM:getObjectWithID(userData.objectID)
    if object then
		serverGOM:setAlwaysSendToClientForObjectWithID(userData.objectID, clientID, true)
		return object
	else
        mj:warn("Object not loaded in clientRequestUnloadedObject:", userData.objectID, " :", serverGOM.allObjects[userData.objectID])
    end
end

local function updateResourceBlockLists(clientID, userData)

	local changedResourceTypes = {}
	

	local resourceBlockLists = serverWorld:getResourceBlockLists(clientID)

	local foodChanges = userData.food
	local foundFoodChange = false
	if foodChanges and next(foodChanges) then
		local eatFoodList = resourceBlockLists.eatFoodList
		if not eatFoodList then
			eatFoodList = {}
			resourceBlockLists.eatFoodList = eatFoodList
		end
		for objectTypeIndex,newValue in pairs(foodChanges) do
			if newValue then
				if not eatFoodList[objectTypeIndex] then
					eatFoodList[objectTypeIndex] = true
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
					foundFoodChange = true
				end
			else
				if eatFoodList[objectTypeIndex] then
					eatFoodList[objectTypeIndex] = nil
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
					foundFoodChange = true
				end
			end
		end
	end

	if foundFoodChange then
		local transientState = serverWorld.transientClientStates[clientID]
		if transientState then
			transientState.nonBlockedFoodObjectTypes = nil
		end
	end

	local checkForClothingToRemove = false
	local clothingChanges = userData.clothing
	if clothingChanges and next(clothingChanges) then
		local wearClothingList = resourceBlockLists.wearClothingList
		if not wearClothingList then
			wearClothingList = {}
			resourceBlockLists.wearClothingList = wearClothingList
		end
		for objectTypeIndex,newValue in pairs(clothingChanges) do
			if newValue then
				if not wearClothingList[objectTypeIndex] then
					wearClothingList[objectTypeIndex] = true
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
					checkForClothingToRemove = true
				end
			else
				if wearClothingList[objectTypeIndex] then
					wearClothingList[objectTypeIndex] = nil
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
				end
			end
		end
	end

	if checkForClothingToRemove then
		serverSapien:checkAllSapiensForClothingDropDueToResourceWearPermissionChange(serverWorld:tribeIDForClientID(clientID), resourceBlockLists.wearClothingList)
	end
	
	local medicineChanges = userData.medicine
	if medicineChanges and next(medicineChanges) then
		local medicineList = resourceBlockLists.medicineList
		if not medicineList then
			medicineList = {}
			resourceBlockLists.medicineList = medicineList
		end
		for objectTypeIndex,newValue in pairs(medicineChanges) do
			if newValue then
				if not medicineList[objectTypeIndex] then
					medicineList[objectTypeIndex] = true
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
				end
			else
				if medicineList[objectTypeIndex] then
					medicineList[objectTypeIndex] = nil
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
				end
			end
		end
	end
	

	local toolChanges = userData.tools
	if toolChanges and next(toolChanges) then
		local toolBlockList = resourceBlockLists.toolBlockList
		if not toolBlockList then
			toolBlockList = {}
			resourceBlockLists.toolBlockList = toolBlockList
		end
		for objectTypeIndex,newValue in pairs(toolChanges) do
			if newValue then
				if not toolBlockList[objectTypeIndex] then
					toolBlockList[objectTypeIndex] = true
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
				end
			else
				if toolBlockList[objectTypeIndex] then
					toolBlockList[objectTypeIndex] = nil
					local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
					changedResourceTypes[resourceTypeIndex] = true
				end
			end
		end
	end

	local fuelChanges = userData.fuel
	if fuelChanges and next(fuelChanges) then
		local fuelLists = resourceBlockLists.fuelLists
		if not fuelLists then
			fuelLists = {}
			resourceBlockLists.fuelLists = fuelLists
		end

		for fuelGroupIndex,changes in pairs(fuelChanges) do
			local fuelList = fuelLists[fuelGroupIndex]
			if not fuelList then
				fuelList = {}
				fuelLists[fuelGroupIndex] = fuelList
			end

			for objectTypeIndex,newValue in pairs(changes) do
				if newValue then
					if not fuelList[objectTypeIndex] then
						fuelList[objectTypeIndex] = true
						local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
						changedResourceTypes[resourceTypeIndex] = true
					end
				else
					if fuelList[objectTypeIndex] then
						fuelList[objectTypeIndex] = nil
						local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
						changedResourceTypes[resourceTypeIndex] = true
					end
				end
			end
		end
	end
	

	local constructableChanges = userData.constructables
	if constructableChanges and next(constructableChanges) then
		local constructableLists = resourceBlockLists.constructableLists
		if not constructableLists then
			constructableLists = {}
			resourceBlockLists.constructableLists = constructableLists
		end

		for construtableTypeIndex,changes in pairs(constructableChanges) do
			local constructableList = constructableLists[construtableTypeIndex]
			if not constructableList then
				constructableList = {}
				constructableLists[construtableTypeIndex] = constructableList
			end

			for objectTypeIndex,newValue in pairs(changes) do
				if newValue then
					if not constructableList[objectTypeIndex] then
						constructableList[objectTypeIndex] = true
						local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
						changedResourceTypes[resourceTypeIndex] = true
					end
				else
					if constructableList[objectTypeIndex] then
						constructableList[objectTypeIndex] = nil
						local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
						changedResourceTypes[resourceTypeIndex] = true
					end
				end
			end
		end
	end

	serverWorld:saveClientState(clientID)
	serverResourceManager:callCallbacksForChangedResourceTypeIndexes(changedResourceTypes)
end

local function setLogisticsRouteDestinations(clientID, routeID, fromStorageAreaObjectID, toStorageAreaObjectID)
	if not (fromStorageAreaObjectID or toStorageAreaObjectID) then
		return {
			success = false
		}
	end

	local privateSharedState = clientStates[clientID].privateShared
	local logisticsRoutes = privateSharedState.logisticsRoutes
	if logisticsRoutes then
		local routes = logisticsRoutes.routes
		local routeInfo = routes[routeID]
		if routeInfo then

			serverTerrain:updatePlayerAnchor(clientID)

			if fromStorageAreaObjectID then
				routeInfo.from = fromStorageAreaObjectID
				local fromObject = serverGOM:getObjectWithID(fromStorageAreaObjectID)
				if fromObject then
					routeInfo.fromPos = fromObject.pos
				elseif not routeInfo.fromPos then
					fromObject = serverGOM:getObjectWithID(fromStorageAreaObjectID)
					return {
						success = false
					}
				end
			end

			if toStorageAreaObjectID then
				routeInfo.to = toStorageAreaObjectID
				local toObject = serverGOM:getObjectWithID(toStorageAreaObjectID)
				if toObject then
					routeInfo.toPos = toObject.pos
				elseif not routeInfo.toPos then
					toObject = serverGOM:getObjectWithID(toStorageAreaObjectID)
					return {
						success = false
					}
				end
			end

			serverWorld:saveClientState(clientID)
			
			if routeInfo.from and routeInfo.to then
				serverLogistics:logisticsRouteDestinationAdded(privateSharedState.tribeID, routeID, routeInfo.from, routeInfo.to)
			end

			local result = {
				success = true,
				routeID = routeID,
				routeInfo = routeInfo,
			}
			
			return result
		end
	end
	return {
		success = false
	}
end
--[[
local function removeLogisticsRouteDestination(clientID, userData)
	local privateSharedState = clientStates[clientID].privateShared
	local logisticsRoutes = privateSharedState.logisticsRoutes
	if logisticsRoutes then
		local routes = logisticsRoutes.routes
		local routeInfo = routes[userData.routeID]
		if routeInfo then
			local destinations = routeInfo.destinations
			if destinations and destinations[userData.destinationIndex] then
				local destinationInfo = destinations[userData.destinationIndex]
				if destinationInfo.uniqueID == userData.destinationObjectID then
					local previousObjectID = nil
					if userData.destinationIndex > 1 then
						previousObjectID = destinations[userData.destinationIndex - 1].uniqueID
					end
					local nextObjectID = nil
					if userData.destinationIndex < #destinations then
						nextObjectID = destinations[userData.destinationIndex + 1].uniqueID
					end
					
					table.remove(destinations, userData.destinationIndex)

					serverWorld:saveClientState(clientID)
					serverLogistics:logisticsRouteDestinationRemoved(privateSharedState.tribeID, userData.routeID, previousObjectID, nextObjectID, userData.destinationObjectID, userData.destinationIndex)
					
					return {
						success = true,
						routeInfo = routeInfo,
					}
				end
			end
		end
	end
	return {
		success = false
	}
end]]

local function changeLogisticsRouteConfig(uiClientID, userData)
	serverTerrain:updatePlayerAnchor(uiClientID)
	local clientStatesForUIClientID = clientStates[uiClientID]
	if not clientStatesForUIClientID then
		return false
	end

	local uiClientTribeID = clientStatesForUIClientID.privateShared.tribeID
	if not uiClientTribeID then
		return false
	end

	local clientStatesToUse = nil
	local clientIDToUse = nil

	if uiClientTribeID == userData.tribeID then
		clientStatesToUse = clientStatesForUIClientID
		clientIDToUse = uiClientID
	else
		local relationships = serverWorld:getAllTribeRelationsSettings(uiClientTribeID)
		if relationships and relationships[userData.tribeID] and relationships[userData.tribeID].storageAlly then
			local otherClientID = serverWorld:clientIDForTribeID(userData.tribeID)
			if otherClientID then
				clientStatesToUse = clientStates[otherClientID]
				clientIDToUse = otherClientID
			end
		end
	end

	if not clientStatesToUse then
		return false
	end

	local logisticsRoutes = clientStatesToUse.privateShared.logisticsRoutes
	if logisticsRoutes then
		if userData.routeID then
			if userData.name then
				if type(userData.name) ~= "string" or string.len(userData.name) == 0 or string.len(userData.name) >= 50 then
					return false
				end
			end
			
			if userData.maxSapiens ~= nil then
				if type(userData.maxSapiens) ~= "number" then
					return false
				end
			end

			local foundValid = false

			if userData.name then
				logisticsRoutes.routes[userData.routeID].name = userData.name
				foundValid = true
			end
			
			if userData.returnToStartEnabled ~= nil then
				logisticsRoutes.routes[userData.routeID].returnToStartEnabled = userData.returnToStartEnabled
				foundValid = true
			end

			if userData.removeRouteWhenComplete ~= nil then
				logisticsRoutes.routes[userData.routeID].removeRouteWhenComplete = userData.removeRouteWhenComplete
				foundValid = true
			end

			if userData.maxSapiens ~= nil then
				local maxSapiens = math.floor(mjm.clamp(userData.maxSapiens, 0, 100))
				local route = logisticsRoutes.routes[userData.routeID]
				route.maxSapiens = maxSapiens
				serverLogistics:updateMaintenceRequiredForRoute(route)
				foundValid = true
			end

			if userData.disabled ~= nil then
				local route = logisticsRoutes.routes[userData.routeID]
				if route.disabled ~= userData.disabled then
					route.disabled = userData.disabled
					serverLogistics:updateMaintenceRequiredForRoute(route)
					if route.disabled then
						serverLogistics:routeWasDisabled(userData.tribeID, userData.routeID)
					end
				end
				foundValid = true
			end

			serverWorld:saveClientState(clientIDToUse)
			return foundValid
		end
	end
	return false
end

local function clientRequestChangeAllowItemUse(clientID, userData)
	if userData.objectIDs then
		for i, objectID in ipairs(userData.objectIDs) do
			local object = serverGOM:getObjectWithID(objectID)
			if object then
				serverGOM:setAllowItemUse(object, userData.allowItemUse)
			else
				mj:warn("Failed to allow item use")
			end
		end
	end
end

local function clientSetAutoRoleAssignmentEnabled(clientID, userData)
	local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
	if privateSharedState then
		privateSharedState.autoRoleAssignmentDisabled = (not userData)
		serverWorld:saveClientState(clientID)
	end
end

local function clientSetTribeName(clientID, userData)
	if userData and type(userData == "string") then
		local stringLength = string.len(userData)
		if stringLength > 0 then
			if stringLength > 40 then
				userData = string.sub(userData, 1, 40)
			end

			local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
			if privateSharedState and privateSharedState.tribeID then
				privateSharedState.tribeName = userData
				serverWorld:saveClientState(clientID)

				local destinationState = serverDestination:getDestinationState(privateSharedState.tribeID)
				destinationState.name = userData
				serverDestination:saveDestinationState(destinationState.destinationID)
				serverDestination:sendDestinationUpdateToAllClients(destinationState)
			end
		end
	end
end

local lastAssignmentTimes = {}

function serverWorld:getAutoRoleAssignmentIsAllowedForRole(tribeID, skillTypeIndex, sapienOrNil)
	if serverTribeAIPlayer:getIsAIPlayerTribe(tribeID) then
		return true
	end
	
	if serverWorld:getAutoRoleAssignmentEnabled(tribeID) then
		local lastAssignmnetTimesBySkillTypeIndex = lastAssignmentTimes[tribeID]
		local lastAssignmentTime = lastAssignmnetTimesBySkillTypeIndex and lastAssignmentTimes[tribeID][skillTypeIndex]
		if lastAssignmentTime then
			local timeDifference = serverWorld:getWorldTime() - lastAssignmentTime
			if timeDifference > gameConstants.delayBetweenAutoRoleAssignmentsForEachSkill then
				local allowAssignmentDueToPriority = timeDifference > (gameConstants.delayBetweenAutoRoleAssignmentsForEachSkill * 2.0)
				if not allowAssignmentDueToPriority then
					if sapienOrNil then
						if skill:hasSkill(sapienOrNil, skillTypeIndex) then
							allowAssignmentDueToPriority = true
						end
					end
				end
				if allowAssignmentDueToPriority then
					--lastAssignmnetTimesBySkillTypeIndex[skillTypeIndex] = serverWorld:getWorldTime()
					if timeDifference < gameConstants.delayBetweenAutoRoleAssignmentsForEachSkill * 2.1 then -- we are looking for a period of repeated tries, so return false it's been a while.
						return true
					else
						lastAssignmnetTimesBySkillTypeIndex[skillTypeIndex] = serverWorld:getWorldTime()
					end
				end
			end
		else
			if not lastAssignmnetTimesBySkillTypeIndex then
				lastAssignmnetTimesBySkillTypeIndex = {}
				lastAssignmentTimes[tribeID] = lastAssignmnetTimesBySkillTypeIndex
			end
			lastAssignmnetTimesBySkillTypeIndex[skillTypeIndex] = serverWorld:getWorldTime() --set an initial delay, or everything gets assigned at the start
		end
	end
	return false
end

function serverWorld:addDelayTimerForAutoRoleAssignment(tribeID, skillTypeIndex)
	local lastAssignmnetTimesBySkillTypeIndex = lastAssignmentTimes[tribeID]
	if not lastAssignmnetTimesBySkillTypeIndex then
		lastAssignmnetTimesBySkillTypeIndex = {}
		lastAssignmentTimes[tribeID] = lastAssignmnetTimesBySkillTypeIndex
	end
	lastAssignmnetTimesBySkillTypeIndex[skillTypeIndex] = serverWorld:getWorldTime()
end

function serverWorld:getAutoRoleAssignmentEnabled(tribeID)
	local clientID = serverWorld:clientIDForTribeID(tribeID)
	if clientID then
		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		if privateSharedState then
			return (not privateSharedState.autoRoleAssignmentDisabled)
		end
	end
	return true
end

local function getStatistics(clientID, userData)
	local tribeID = serverWorld:tribeIDForClientID(clientID)
	return serverStatistics:getValues(tribeID, userData.statisticsTypeIndexes, userData.startIndex)
end

local function getResourceObjectCounts(clientID, userData)
	local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
	if privateSharedState then
		local tribeID = serverWorld:tribeIDForClientID(clientID)
		return serverResourceManager:getResourceObjectCounts(tribeID)
	end
	return {}
end

local function addSeenResourceObjectTypesForClientInteraction(clientID, userData)
	local tribeID = serverWorld:tribeIDForClientID(clientID)
	if tribeID then
		for objectTypeIndex,v in pairs(userData) do
			updateClientSeenListForResourceAddition(tribeID, objectTypeIndex)
		end
	end
end

function serverWorld:getDatabase(databaseName, createIfDoesntExit)
	return bridge:getDatabase(databaseName, createIfDoesntExit)
end

function serverWorld:getWorldTime()
	return bridge.worldTime
end

function serverWorld:getWorldSaveDirPath(appendPathOrNil)
	return bridge:getWorldSaveDirPath(appendPathOrNil)
end

function serverWorld:getDayLength()
	return (math.pi * 2.0) / bridge.sunRotationSpeed
end

function serverWorld:getSunRotationSpeed()
	return bridge.sunRotationSpeed
end

local function getSanitizedObjectInfoForUIRoute(objectID, tribeID)
	local object = serverGOM:getObjectWithID(objectID)
	if not object then
		mj:error("object not loaded for getSanitizedObjectInfoForUIRoute:", objectID)
		return nil
	end
	local sharedState = object.sharedState

	local function getStorageTypeIndex()
		if sharedState.contentsStorageTypeIndex then
			return sharedState.contentsStorageTypeIndex
		end
		if sharedState.settingsByTribe then
			local tribeSettings = serverStorageArea:getTribeSettings(sharedState, tribeID)
			if tribeSettings then
				local restrictStorageTypeIndex = tribeSettings.restrictStorageTypeIndex
				if restrictStorageTypeIndex then
					return restrictStorageTypeIndex
				end
			end
		end
		return 0
	end
	local storageTypeIndex = getStorageTypeIndex()

	local displayObjectTypeIndex = object.objectTypeIndex
	if sharedState.firstObjectTypeIndex then
		displayObjectTypeIndex = sharedState.firstObjectTypeIndex
	elseif sharedState.inventory and #sharedState.inventory.objects > 0 then
		displayObjectTypeIndex = sharedState.inventory.objects[1].objectTypeIndex
	else
		if storageTypeIndex > 0 then
			displayObjectTypeIndex = storage.types[storageTypeIndex].displayGameObjectTypeIndex
		end
	end

	local storedCount = 0
	if sharedState.inventory then
		storedCount = #sharedState.inventory.objects 
	end

	local result = {
		uniqueID = object.uniqueID,
		objectTypeIndex = object.objectTypeIndex,
		displayObjectTypeIndex = displayObjectTypeIndex,
		storedCount = storedCount,
		name = sharedState.name,
		pos = object.pos,
	}

	if storageTypeIndex > 0 then
		result.contentsStorageTypeIndex = storageTypeIndex
	end

	return result
end

local function getUIRoutesForStorageArea(uiClientID, storageAreaObjectID)
	local uiClientTribeID = serverWorld:tribeIDForClientID(uiClientID)
	if not uiClientTribeID then
		return nil
	end

	local receiveRoutes = nil
	local sendRoutes = nil

	local function addRoutesForClient(clientID, tribeID)
		if clientID and tribeID then
			serverWorld:loadClientStateIfNeededForSapienTribeID(tribeID)
			local logisticsRoutes = clientStates[clientID].privateShared.logisticsRoutes
			if logisticsRoutes then
				for routeID,route in pairs(logisticsRoutes.routes) do
					if route.from and route.to then
						if route.from == storageAreaObjectID then
							local otherObjectInfo = getSanitizedObjectInfoForUIRoute(route.to, tribeID)
							if otherObjectInfo then
								if not sendRoutes then
									sendRoutes = {}
								end
			
								table.insert(sendRoutes,{
									routeID = routeID,
									tribeID = tribeID,
									otherObjectInfo = otherObjectInfo,
									disabled = route.disabled,
								})
							end
						elseif route.to == storageAreaObjectID then
							local otherObjectInfo = getSanitizedObjectInfoForUIRoute(route.from, tribeID)
							if otherObjectInfo then
								if not receiveRoutes then
									receiveRoutes = {}
								end
			
								table.insert(receiveRoutes,{
									routeID = routeID,
									tribeID = tribeID,
									otherObjectInfo = otherObjectInfo,
									disabled = route.disabled,
								})
							end
						end
					end
				end
			end
		end
	end

	addRoutesForClient(uiClientID, uiClientTribeID)

	local relationships = serverWorld:getAllTribeRelationsSettings(uiClientTribeID)
	if relationships then
		for tribeID,settings in pairs(relationships) do
			if settings.storageAlly then
				addRoutesForClient(serverWorld:clientIDForTribeID(tribeID), tribeID)
			end
		end
	end

	local function sortByID(a,b)
		if a.routeID == b.routeID then
			return a.tribeID < b.tribeID
		end
		return a.routeID < b.routeID
	end

	if receiveRoutes or sendRoutes then
		if receiveRoutes then
			table.sort(receiveRoutes, sortByID)
		end
		if sendRoutes then
			table.sort(sendRoutes, sortByID)
		end
		return {
			receiveRoutes = receiveRoutes,
			sendRoutes = sendRoutes,
		}
	end

	return nil
end

local function createLogisticsRoute(clientID, userData)
	serverTerrain:updatePlayerAnchor(clientID)
	local logisticsRoutes = clientStates[clientID].privateShared.logisticsRoutes
	if not logisticsRoutes then
		logisticsRoutes = {
			routeIDCounter = 0,
			version = serverLogistics.logisticsRoutesDataVersion,
			routes = {}
		}
		clientStates[clientID].privateShared.logisticsRoutes = logisticsRoutes
	end
	local newRouteID = logisticsRoutes.routeIDCounter + 1
	logisticsRoutes.routeIDCounter = newRouteID
	local routeInfo = {}
	logisticsRoutes.routes[newRouteID] = routeInfo
	

	local addResult = setLogisticsRouteDestinations(clientID, newRouteID, userData.fromStorageAreaObjectID, userData.toStorageAreaObjectID)
	return addResult
end


function serverWorld:removeLogisticsRoute(uiClientID, uiRouteRemoveInfo)
	serverTerrain:updatePlayerAnchor(uiClientID)

	local clientStatesForUIClientID = clientStates[uiClientID]
	if not clientStatesForUIClientID then
		return false
	end

	local uiClientTribeID = clientStatesForUIClientID.privateShared.tribeID
	if not uiClientTribeID then
		return false
	end

	local clientStatesToUse = nil
	local clientIDToUse = nil

	if uiClientTribeID == uiRouteRemoveInfo.tribeID then
		clientStatesToUse = clientStatesForUIClientID
		clientIDToUse = uiClientID
	else
		local relationships = serverWorld:getAllTribeRelationsSettings(uiClientTribeID)
		if relationships and relationships[uiRouteRemoveInfo.tribeID] and relationships[uiRouteRemoveInfo.tribeID].storageAlly then
			serverWorld:loadClientStateIfNeededForSapienTribeID(uiRouteRemoveInfo.tribeID)
			local otherClientID = serverWorld:clientIDForTribeID(uiRouteRemoveInfo.tribeID)
			if otherClientID then
				clientStatesToUse = clientStates[otherClientID]
				clientIDToUse = otherClientID
			end
		end
	end

	if not clientStatesToUse then
		return false
	end

	local logisticsRoutes = clientStatesToUse.privateShared.logisticsRoutes
	if logisticsRoutes then
		local removedRouteInfo = logisticsRoutes.routes[uiRouteRemoveInfo.routeID]
		if removedRouteInfo then
			logisticsRoutes.routes[uiRouteRemoveInfo.routeID] = nil
			serverLogistics:routeWasRemoved(uiRouteRemoveInfo.tribeID, uiRouteRemoveInfo.routeID, removedRouteInfo)
			serverWorld:saveClientState(clientIDToUse)
			return true
		end
	end

	return false

end

function serverWorld:getLogisticsRoute(tribeID, routeID)
	serverWorld:loadClientStateIfNeededForSapienTribeID(tribeID)
    local clientID = serverWorld:clientIDForTribeID(tribeID)
	if not clientID then
		return nil
	end
	local clientStatesForID = clientStates[clientID]
	if not clientStatesForID then
		return nil
	end
	local logisticsRoutes = clientStatesForID.privateShared.logisticsRoutes
	if logisticsRoutes then
		return logisticsRoutes.routes[routeID]
	end
	return nil
end

local function recalculateStorageAvailibilitiesForAllyChange(tribeID)
	serverStorageArea:updateAllStorageAreaAvailabilityInfosForRelationsSettingsChange(tribeID)
	local destinationState = serverDestination:getDestinationState(tribeID)
	serverResourceManager:recalculateForTribe(destinationState)
end

local function clientChangeTribeRelationsSetting(clientID, changeInfo)
	--mj:log("clientChangeTribeRelationsSetting:", changeInfo, " clientID:", clientID)
	if clientID and changeInfo and changeInfo.tribeID and changeInfo.key then
		serverWorld:loadClientStateIfNeededForSapienTribeID(changeInfo.tribeID)
		--mj:log("b")
		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		if privateSharedState then
			--mj:log("c")
			if not privateSharedState.tribeRelationsSettings then
				privateSharedState.tribeRelationsSettings = {}
			end
			if not privateSharedState.tribeRelationsSettings[changeInfo.tribeID] then
				privateSharedState.tribeRelationsSettings[changeInfo.tribeID] = {}
			end
			local changed = false
			if changeInfo.value then
				if privateSharedState.tribeRelationsSettings[changeInfo.tribeID][changeInfo.key] ~= changeInfo.value then
					privateSharedState.tribeRelationsSettings[changeInfo.tribeID][changeInfo.key] = changeInfo.value
					changed = true
				end
			else
				if privateSharedState.tribeRelationsSettings[changeInfo.tribeID][changeInfo.key] then
					privateSharedState.tribeRelationsSettings[changeInfo.tribeID][changeInfo.key] = nil
					changed = true
				end
			end

			--mj:log("clientChangeTribeRelationsSetting changed:", changed, " changeInfo.key:", changeInfo.key)

			if changed then
				if changeInfo.key == "allowBedUse" then
					serverWorld:updateAvailableBedCountStats()
				elseif changeInfo.key == "treatAsThreat" then
					serverTribe:updateSapienProximityCallbacks()
					planManager:updateAllThreatProximityObjectsForRecruitOrRelationshipSettingChange(changeInfo.tribeID)
				elseif changeInfo.key == "allowItemUse" then
					local clientTribeID = serverWorld:tribeIDForClientID(clientID)

					local foundAllyPrivateSharedState = nil
					
					local otherTribeDestinationState = serverDestination:getDestinationState(changeInfo.tribeID)
					if otherTribeDestinationState and otherTribeDestinationState.clientID then
						serverWorld:loadClientStateIfNeededForSapienTribeID(changeInfo.tribeID)
						local otherTribeClientPrivateSharedState = serverWorld:getPrivateSharedClientState(otherTribeDestinationState.clientID)
						if otherTribeClientPrivateSharedState then
							local relationshipSettings = otherTribeClientPrivateSharedState.tribeRelationsSettings and otherTribeClientPrivateSharedState.tribeRelationsSettings[clientTribeID]
							if relationshipSettings and relationshipSettings.allowItemUse then
								foundAllyPrivateSharedState = otherTribeClientPrivateSharedState
							end
						end
					end

					local newAllyValue = changeInfo.value
					if not foundAllyPrivateSharedState then
						newAllyValue = false
					end
						

					local previousStorageAlly = privateSharedState.tribeRelationsSettings[changeInfo.tribeID].storageAlly

					if (previousStorageAlly and (not newAllyValue)) then
						privateSharedState.tribeRelationsSettings[changeInfo.tribeID].storageAlly = nil

						if foundAllyPrivateSharedState then
							foundAllyPrivateSharedState.tribeRelationsSettings[clientTribeID].storageAlly = nil
							server:callClientFunction("tribeRelationsSettingsChanged", otherTribeDestinationState.clientID, {
								tribeID = clientTribeID,
								tribeRelationsSettings = foundAllyPrivateSharedState.tribeRelationsSettings[clientTribeID]
							})
							recalculateStorageAvailibilitiesForAllyChange(changeInfo.tribeID)
						end

						recalculateStorageAvailibilitiesForAllyChange(clientTribeID)

					elseif ((not previousStorageAlly) and newAllyValue) then
						privateSharedState.tribeRelationsSettings[changeInfo.tribeID].storageAlly = true
						foundAllyPrivateSharedState.tribeRelationsSettings[clientTribeID].storageAlly = true

						server:callClientFunction("tribeRelationsSettingsChanged", otherTribeDestinationState.clientID, {
							tribeID = clientTribeID,
							tribeRelationsSettings = foundAllyPrivateSharedState.tribeRelationsSettings[clientTribeID]
						})

						recalculateStorageAvailibilitiesForAllyChange(clientTribeID)
						recalculateStorageAvailibilitiesForAllyChange(changeInfo.tribeID)
					end

					server:callClientFunction("tribeRelationsSettingsChanged", clientID, {
						tribeID = changeInfo.tribeID,
						tribeRelationsSettings = privateSharedState.tribeRelationsSettings[changeInfo.tribeID]
					})
				end

				--serverResourceManager:callCallbacksForChangedResourceTypeIndexes(changedResourceTypes)
				serverWorld:saveClientState(clientID)
			end
		end
	end
end

local function clientRequestDestinationInfoForClientTribeSelection(clientID, destinationID)
	local destinationState = serverDestination:getDestinationState(destinationID)
	if destinationState then
		return {
			creationSapienStates = serverTribe:getOrCreateCreationSapienStatesForClientInspection(destinationID),
			biomeTags = destinationState.biomeTags
		}
	end
end

local function clientAcceptQuest(clientID, changeInfo)
	if clientID and changeInfo and changeInfo.destinationID and changeInfo.questState then
		local tribeID = clientStates[clientID].privateShared.tribeID
		if not tribeID then
			return nil
		end
		return serverTribe:clientAcceptQuest(tribeID, changeInfo.destinationID, changeInfo.questState)
	end
end

local function clientBuyTradeOffer(clientID, changeInfo)
	mj:log("clientBuyTradeOffer")
	if clientID and changeInfo and changeInfo.destinationID and changeInfo.offerInfo then
		local tribeID = clientStates[clientID].privateShared.tribeID
		if not tribeID then
			return nil
		end
		return serverTribe:clientPurchaseTradeOffer(tribeID, changeInfo.destinationID, changeInfo.offerInfo)
	end
end

local function clientChangeHibernationOnExitDuration(clientID, changeKey)
	if clientID and changeKey then
		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		if privateSharedState then
			privateSharedState.hibernationDurationKey = changeKey
			serverWorld:saveClientState(clientID)
		end
	end
end


function serverWorld:getTimeOfDayFraction(worldPos)
	if not worldPos then
		mj:error("serverWorld:getTimeOfDayFraction requires worldPos")
		return nil
	end
	return bridge:getTimeOfDayFraction(worldPos)
end

function serverWorld:getYearLength()
	return 1.0 / serverWorld.yearSpeed
end

function serverWorld:getSunDot(normalizedPos)
	return bridge:getSunDot(normalizedPos)
end

function serverWorld:getHasDaylight(normalizedPos)
	return bridge:getSunDot(normalizedPos) > -0.1
end

function serverWorld:getStatsIndex()
	local dayLength = (math.pi * 2) / bridge.sunRotationSpeed
	return math.floor((bridge.worldTime / dayLength) * 8.0) + 1
end

function serverWorld:getYearIndex()
	local yearLength = serverWorld:getYearLength()
	return math.floor(bridge.worldTime / yearLength) + 1
end

function serverWorld:getTimeUntilNextSeasonChange(offsetFractionOrNil)
    local offsetFraction = 1.0 - 0.125
    if offsetFractionOrNil then
        offsetFraction = offsetFraction - offsetFractionOrNil
	end
	local worldTime = bridge.worldTime
    local seasonBase = serverWorld.yearSpeed * worldTime + offsetFraction
    local remainderFraction = 0.25 - math.fmod(seasonBase, 0.25)
    return remainderFraction / serverWorld.yearSpeed
end

function serverWorld:getSeasonFraction() -- 0.0 is spring in north, 0.25 summer, 0.5 is autumn, 0.75 winter. Offset by 0.5 for south
    return math.fmod(serverWorld.yearSpeed * bridge.worldTime, 1.0)
end

function serverWorld:getTimeUntilNextSeasonOfType(seasonIndex, currentSeasonIndex, offsetFractionOrNil)
	local offsetFraction = 1.0 - 0.125
    if offsetFractionOrNil then
        offsetFraction = offsetFraction - offsetFractionOrNil
	end
	local worldTime = bridge.worldTime
    local seasonBase = serverWorld.yearSpeed * worldTime + offsetFraction
	local remainderFraction = 0.25 - math.fmod(seasonBase, 0.25)

	if seasonIndex <= currentSeasonIndex then
		seasonIndex = seasonIndex + 4
	end

	remainderFraction = remainderFraction + 0.25 * ((seasonIndex - 1) - currentSeasonIndex)

	--mj:log("serverWorld:getTimeUntilNextSeasonOfType seasonIndex:", seasonIndex, " offsetFractionOrNil:", offsetFractionOrNil, " currentSeasonLocationIndex:", currentSeasonIndex, " offsetFraction:", 0.25 * (seasonIndex - currentSeasonIndex))
	return remainderFraction / serverWorld.yearSpeed
	
end

function serverWorld:addCallbackTimerForWorldTime(worldTime, callback)
	--mj:log("adding callback for time:", worldTime)
	return bridge:addCallbackTimerForWorldTime(worldTime, callback)
end

function serverWorld:removeCallbackTimer(timerID) --untested
	bridge:removeCallbackTimer(timerID)
end

local statsTypeByAgeType = {
	[sapienConstants.lifeStages.child.index] = statistics.types.populationChild.index,
	[sapienConstants.lifeStages.adult.index] = statistics.types.populationAdult.index,
	[sapienConstants.lifeStages.elder.index] = statistics.types.populationElder.index,

}

function serverWorld:updatePopulationStatistics(clientID, tribeIDOrNil)
	local tribeID = tribeIDOrNil or serverWorld:tribeIDForClientID(clientID)
	if not tribeID then
		return
	end
	local destinationState = serverDestination:getDestinationState(tribeID, true)
	if (not destinationState) or (destinationState.loadState == destination.loadStates.hibernating) then
		return
	end
	local populationsByAgeType = {
		[sapienConstants.lifeStages.child.index] = 0,
		[sapienConstants.lifeStages.adult.index] = 0,
		[sapienConstants.lifeStages.elder.index] = 0,
	}

	local pregnantCount = 0
	local babyCount = 0

	local positionTotal = vec3(0.0,0.0,0.0)
	local positionCount = 0


	serverGOM:callFunctionForAllSapiensInTribe(tribeID, function(sapien)
		positionTotal = positionTotal + sapien.pos
		positionCount = positionCount + 1

		populationsByAgeType[sapien.sharedState.lifeStageIndex] = populationsByAgeType[sapien.sharedState.lifeStageIndex] + 1
		if sapien.sharedState.pregnant then
			pregnantCount = pregnantCount + 1
		elseif sapien.sharedState.hasBaby then
			babyCount = babyCount + 1
		end
	end)

	if clientID and clientStates[clientID] and positionCount > 0  then
		local averagePosition = positionTotal / positionCount
		clientStates[clientID].private.averageTribePosition = normalize(averagePosition)
		serverWorld:saveClientState(clientID)
	end

	for lifeStageIndex, count in pairs(populationsByAgeType) do
		serverStatistics:setValueForToday(tribeID, statsTypeByAgeType[lifeStageIndex], count)
	end
	
	serverStatistics:setValueForToday(tribeID, statistics.types.populationPregnant.index, pregnantCount)
	serverStatistics:setValueForToday(tribeID, statistics.types.populationBaby.index, babyCount)
end

function serverWorld:tribeFailed(clientID, tribeID)

	if not clientID then
		mj:warn("serverWorld:tribeFailed unimplimented for non-player tribes")
		return
	end

	--if --todo check if destination state has hibernating sapiens or pop count above 0, and return

	mj:log("serverWorld:tribeFailed clientID:", clientID, " tribeID:", tribeID)
	local clientState = clientStates[clientID]
	local newLocation = clientState.private.averageTribePosition or clientState.public.pos
	local failPosition = serverTerrain:getHighestDetailTerrainPointAtPoint(newLocation)
	resetClientState(clientID, newLocation, failPosition)
	serverWorld.transientClientStates[clientID] = {}
	

	server:callClientFunction(
		"resetDueToTribeFail",
		clientID,
		{
			public = clientState.public,
			privateShared = clientState.privateShared,
			resetPoint = newLocation
		}
	)
	--mj:log("resetDueToTribeFail call done")

	--mj:log("client state:", clientStates[clientID])
	
	serverStoryEvents:clientDisconnectedOrFailed(tribeID)
	serverTribe:updateDestinationStateForTribeFail(tribeID)
	serverTribe:createPlayerSelectionTribesIfNeededNearLocation(newLocation)
	serverDestination:loadAndSendDestinationsToClientForPos(clientID, newLocation, mapModes.regional)
end

function serverWorld:updateFollowerCount(tribeID)
	local destinationState = serverDestination:getDestinationState(tribeID)
	if destinationState.hibernatingSapienStates then
		return
	end

    local count = 0
    serverGOM:callFunctionForAllSapiensInTribe(tribeID, function (sapienID) 
        count = count + 1
    end)

	--[[if count <= 0 then
		mj:debug("setting zero follower count for tribeID:", tribeID)
	end]]

	--mj:debug("serverWorld:updateFollowerCount:", tribeID, " count:", count)

	if (count ~= followerCountsByTribe[tribeID]) then
		followerCountsByTribe[tribeID] = count
		
		serverStatistics:setValueForToday(tribeID, statistics.types.population.index, count + (babyCountsByTribe[tribeID] or 0))
		planManager:updatePlansForFollowerCountChange(tribeID, count)
		
		local clientID = serverWorld:clientIDForTribeID(tribeID)
		serverWorld:updatePopulationStatistics(clientID, tribeID)

		if count <= 0 then
			serverWorld:tribeFailed(clientID, tribeID)
		end
	end
end

function serverWorld:saveAndSendLogisticsChange(clientID)
	server:callClientFunction(
		"logisticsRoutesChanged",
		clientID,
		clientStates[clientID].privateShared.logisticsRoutes
	)
	serverWorld:saveClientState(clientID)
end

function serverWorld:addToBabyCount(tribeID, countToAddOrRemove)
	if not tribeID then
		return
	end
	local newCount = (babyCountsByTribe[tribeID] or 0) + countToAddOrRemove
	babyCountsByTribe[tribeID] = newCount
	
	serverStatistics:setValueForToday(tribeID, statistics.types.population.index, (followerCountsByTribe[tribeID] or 0) + (babyCountsByTribe[tribeID] or 0))
	serverWorld:updatePopulationStatistics(serverWorld:clientIDForTribeID(tribeID), tribeID)
end

local sleepingSapiens = {}

function serverWorld:setSapienSleeping(sapien, isSleeping)
	local wasSleeping = (sleepingSapiens[sapien.uniqueID] ~= nil)
	if wasSleeping ~= isSleeping then
		if isSleeping then
			sleepingSapiens[sapien.uniqueID] = true
			sleepingSapienCount = sleepingSapienCount + 1
		else
			sleepingSapiens[sapien.uniqueID] = nil
			sleepingSapienCount = sleepingSapienCount - 1
		end
	end 
end

local function transientObjectsWereInspected(clientID, userData) --only called for objectTypes that have notifyServerOnTransientInspection set, eg. trees that only fruit every 10 years
	serverTerrain:updatePlayerAnchor(clientID)
	serverGOM:transientObjectsWereInspected(userData.objectIDs)
end


--[[local function debugCheckConnectedPathObjects()
	for objectID,object in pairs(serverGOM.allObjects) do
		--if gameObject.types[object.objectTypeIndex].pathFindingDifficulty and gameObject.types[object.objectTypeIndex].isPathFindingCollider then
		if object.objectTypeIndex == gameObject.types.splitLogSteps2x2.index then
			if not pathCreator:debugGetHasConnections(objectID) then
				mj:log("NO connections:", objectID, " - ", object.objectTypeIndex)
			end
		end
	end
end]]

function serverWorld:setDebugObject(clientID, newObjectID)
	serverGOM:printDebugInfo()

	--debugCheckConnectedPathObjects()

	mj.debugObject = newObjectID
	mj:log("Object ID:", newObjectID, " is now set as the target for detailed logging.")
	mj:log("Current world time:", serverWorld:getWorldTime())
	local object = serverGOM:getObjectWithID(newObjectID)
	if not object then
		local vert = serverTerrain:getVertWithID(newObjectID)
		if vert then
            serverGOM:setDebugObject(nil)
			mj:log("Debug object is vert with no plan object associated")
			mj:log("vert info:", serverTerrain:retrieveVertInfo(newObjectID))
			local modifications = vert:getModifications()
			mj:log("modifications:", modifications)

			mj:log("vert private state:", serverTerrain:getPrivateLuaStateForVertex(vert))
		else
			mj:warn("Debug object not found")
		end
	else
		serverGOM:setDebugObject(newObjectID)
		local tribeID = object.sharedState and object.sharedState.tribeID
		if tribeID then
			local objectClientID = serverWorld:clientIDForTribeID(tribeID)
			local playerName = nil
			local playerID = nil
			if objectClientID then 
				playerID = serverWorld:getPlayerIDForClient(objectClientID)
				playerName = serverWorld:getPlayerNameForClient(objectClientID)
			end
			mj:log("Debug object placed by tribe:", tribeID, " client:", objectClientID, " playerID:", playerID,  " name:", playerName)
		end
		mj:log("Debug object pos:", object.pos)
		mj:log("Debug object altitude:", mj:pToM(mjm.length(object.pos) - 1.0))
		mj:log("Debug object type:", object.objectTypeIndex)
		mj:log("Debug object renderType:", object.renderType)
		mj:log("Debug object rotation:", object.rotation)
		
		local terrainPoint = serverTerrain:getHighestDetailTerrainPointAtPoint(object.pos)
		mj:log("debug object height above terrain:", mj:pToM(mjm.length(object.pos) - mjm.length(terrainPoint)))
		pathCreator:setDebugObject(newObjectID)

		if object.sharedState and object.sharedState.vertID then
			mj:log("vert info:", serverTerrain:retrieveVertInfo(object.sharedState.vertID))
			local vert = serverTerrain:getVertWithID(object.sharedState.vertID)
			local modifications = vert:getModifications()
			mj:log("modifications:", modifications)

			mj:log("vert private state:", serverTerrain:getPrivateLuaStateForVertex(vert))

		end

		
		mj:log("Debug object shared state:", object.sharedState)
		mj:log("Debug object private state:", object.privateState)
		--mj:log("Debug object lazy private state:", object.lazyPrivateState)
		mj:log("Debug object unsaved state:", object.temporaryPrivateState)

		serverStorageArea:debugLog(newObjectID)

		if object.objectTypeIndex == gameObject.types.sapien.index then
			--mj:log("Debug object ai state:", serverSapienAI.aiStates[object.uniqueID]) --logs all the closeThreatPotentialSapiens which is annoying
			
			mj:log("sleep desire:", desire:getSleep(object, serverWorld:getTimeOfDayFraction(object.pos)))
			mj:log("wake desire:", desire:getWake(object, serverWorld:getTimeOfDayFraction(object.pos)))

			mj:log("tribe destination state:\n", serverDestination:getDestinationState(object.sharedState.tribeID))
		end

		local covered = serverGOM:doCoveredTestForObject(object)
		mj:log("Debug object test result covered:", covered)

		--[[if object.sharedState and gameObject.types[object.objectTypeIndex].seatTypeIndex then
			serverSeat:removeSeatNodes(object)
			mj:log("recreated seat state:", object.sharedState)
		end]]

		--[[if object.sharedState and gameObject.types[object.objectTypeIndex].isStorageArea then
			serverLogistics:updateMaintenceRequiredForConnectedObjects(object.uniqueID)
			mj:log("recreated after serverLogistics update:", object.sharedState)
		end]]

		--serverGOM:preventFutureTransientObjectsNearObject(object.uniqueID)

		if clientID then
			local debugConnections = pathCreator:getDebugConnectionsForObject(newObjectID)
			server:callClientFunction("setPathDebugConnections", clientID, debugConnections)
		end

		--serverWeather:destroyConstructedObject(object) --todo remove this!

		--[[local research = mjrequire "common/research"
		local notification = mjrequire "common/notification"
		local researchTypeIndex = research.types.digging.index
		local researchingSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex
		serverGOM:sendNotificationForObject(object, notification.types.discovery.index, {
			skillTypeIndex = researchingSkillTypeIndex,
			researchTypeIndex = researchTypeIndex,
		}, sharedState.tribeID)]]

		--serverGOM:testAndUpdateCoveredStatusIfNeeded(object)

	end
end

local debugAnchorsClientID = nil
local function sendDebugAnchors()
	local debugAnchors = {}
	for objectID,anchorObject in pairs(serverGOM.allObjects) do
		if serverGOM:objectWithIDHasAnchor(objectID) then
			table.insert(debugAnchors, {
				objectID = objectID,
				pos = anchorObject.pos,
				anchorStatesByTribe = anchorObject.privateState.anchorStatesByTribe,
			})
		end
	end

	server:callClientFunction("setDebugAnchors", debugAnchorsClientID, debugAnchors)
end

function serverWorld:setDebugObjectPath(tribeID, pathInfo)
	if tribeID then
		local clientID = serverWorld:clientIDForTribeID(tribeID)
		if clientID then
			mj:log("send through path:", pathInfo)
			server:callClientFunction("setPathDebugPath", clientID, pathInfo)
		end
		--
	end
end

local function wakeTribeDebug(clientID, userData)
	if serverWorld:getCheatsEnabled(clientID) then
		serverDestination:wakeTribeDebug(userData)
	end
end


local function registerNetFunctions()
	

	server:registerNetFunction("setTimeFromSunRotation", function(clientID, userData)
		if serverWorld:getCheatsEnabled(clientID) then
			return setTimeFromSunRotation(userData.rotation)
		end
	end)

	server:registerNetFunction("addMoveOrder", clientRequestAddMoveOrder)
	server:registerNetFunction("addWaitOrder", clientRequestAddWaitOrder)
	server:registerNetFunction("cancelWaitOrder", clientRequestCancelWaitOrder)
	--server:registerNetFunction("addObjectMoveOrder", clientRequestAddObjectMoveOrder)

	
	server:registerNetFunction("wakeTribe", wakeTribeDebug)
	
	
	server:registerNetFunction("addPlans", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			return planManager:addPlans(tribeID, userData)
		end
		return false
	end)
	server:registerNetFunction("addPathPlacementPlans", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			return planManager:addPathPlacementPlans(tribeID, userData)
		end
		return nil
	end)
	server:registerNetFunction("assignSapienToPlan", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			planManager:assignSapienToPlan(tribeID, userData)
		end
	end)

	server:registerNetFunction("cancelPlans", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			planManager:cancelPlans(tribeID, userData)
		end
	end)

	server:registerNetFunction("prioritizePlans", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			planManager:prioritizePlans(tribeID, userData)
		end
	end)

	server:registerNetFunction("deprioritizePlans", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			planManager:deprioritizePlans(tribeID, userData)
		end
	end)

	server:registerNetFunction("togglePlanPrioritization", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			planManager:togglePlanPrioritization(tribeID, userData)
		end
	end)
	
	
	server:registerNetFunction("checkPlanAvailability", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			return planManager:checkPlanAvailability(tribeID, userData)
		end
		return nil
	end)

	
	server:registerNetFunction("modifyFillObjectTypeIndexForAnyPlans", function(clientID, userData)
		local tribeID = clientStates[clientID].privateShared.tribeID
		if tribeID then
			serverTerrain:updatePlayerAnchor(clientID)
			planManager:modifyFillObjectTypeIndexForAnyPlans(tribeID, userData)
		end
		return nil
	end)

	server:registerNetFunction("cancelSapienOrders", clientCancelSapienOrders)
	server:registerNetFunction("clientUpdate", clientUpdate)
	server:registerNetFunction("cancelAll", cancelAll)

	server:registerNetFunction("transientObjectsWereInspected", transientObjectsWereInspected)
	

	--server:registerNetFunction("getTribeInfo", getTribeInfo)
	server:registerNetFunction("selectStartTribe", clientRequestSelectStartTribe)

	server:registerNetFunction("setSkillPriority", clientSetSkillPriority)
	server:registerNetFunction("moveAllBetweenSkillPriorities", clientMoveAllBetweenSkillPriorities)



	server:registerNetFunction("changeObjectName", changeObjectName)

	server:registerNetFunction("maxFollowerNeeds", maxFollowerNeeds)
	
	server:registerNetFunction("startProfile", startProfile)

	
	server:registerNetFunction("getRelationships", function(clientID, sapienID)
		return serverGOM:getRelationshipsForClientRequest(sapienID)
	end)
	
	server:registerNetFunction("updateResourceBlockLists", updateResourceBlockLists)
	
	server:registerNetFunction("setPaused", setClientPaused)
	server:registerNetFunction("setTemporaryPausedIfNonMultiplayer", setTemporaryPausedIfNonMultiplayer)
	server:registerNetFunction("resumeAfterTemporaryPause", resumeAfterTemporaryPause)
	
	
	server:registerNetFunction("setFastForward", setFastForward)
	server:registerNetFunction("setSlowMotion", setClientSlowMotion)

	
    server:registerNetFunction("changeDebugObject", function(clientID, newObjectID)
		if serverWorld:getCheatsEnabled(clientID) then
			serverTerrain:updatePlayerAnchor(clientID)
			serverWorld:setDebugObject(clientID, newObjectID)
		end
	end)

	server:registerNetFunction("cheatButtonClicked", function(clientID, objectIDs)
		if serverWorld:getCheatsEnabled(clientID) then
			serverTerrain:updatePlayerAnchor(clientID)
			for i,objectID in ipairs(objectIDs) do
				--serverGOM:removeGameObject(objectID)
				local object = serverGOM:getObjectWithID(objectID)
				if object then
					local objectType = gameObject.types[object.objectTypeIndex]
					if objectType.floraTypeIndex then
						serverFlora:growSaplingImmediately(object)
						serverFlora:refillInventory(object, object.sharedState, true, true)
						serverGOM:saveObject(object.uniqueID)
					end

					if objectType.index == gameObject.types.compostBin.index then
						serverCompostBin:cheatClicked(object)
					end
					--serverGOM:testAndUpdateCoveredStatusIfNeeded(object)
					--serverGOM:debugToggleCovered(object)
					
					local unsavedState = serverGOM:getUnsavedPrivateState(object)
					unsavedState.agroMobRunAwayDirection = normalize(cross(object.normalizedPos, vec3(0.0,1.0,0.0)))
				end
			end
		end
	end)

	server:registerNetFunction("spawnCheat", function(clientID, info)
		if serverWorld:getCheatsEnabled(clientID) then
			if info and info.objectTypeIndexOrName and info.pos then
				serverTerrain:updatePlayerAnchor(clientID)
				local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
				if privateSharedState and privateSharedState.tribeID then
					local quantity = info.quantity or 1
					quantity = math.min(quantity, 100)
					local spawnPos = info.pos
					--[[if mj.debugObject then
						local object = serverGOM:getObjectWithID(mj.debugObject)
						if object then
							spawnPos = object.pos
						end
					end]]
					for i = 1, quantity do
						serverGOM:spawnObject(info.objectTypeIndexOrName, spawnPos, info.rotation, privateSharedState.tribeID)
					end
				end
			end
		end
	end)

	server:registerNetFunction("buildCheat", function(clientID, info)
		if serverWorld:getCheatsEnabled(clientID) then
			serverWorld.completionCheatEnabled = true
		end
	end)

	server:registerNetFunction("researchCheat", function(clientID, info)
		if serverWorld:getCheatsEnabled(clientID) then
			serverWorld:completeAllDiscoveriesCheat(clientID)
		end
	end)
	
	server:registerNetFunction("toggleDebugAnchors", function(clientID)
		if serverWorld:getCheatsEnabled(clientID) then
			if debugAnchorsClientID then
				server:callClientFunction("setDebugAnchors", debugAnchorsClientID, nil)
			end

			if debugAnchorsClientID ~= clientID then
				debugAnchorsClientID = clientID
				sendDebugAnchors()
			else
				debugAnchorsClientID = nil
			end
		end
	end)
	
	
	server:registerNetFunction("createLogisticsRoute", createLogisticsRoute)
	server:registerNetFunction("removeLogisticsRoute", function(clientID, removeInfo)
		return serverWorld:removeLogisticsRoute(clientID, removeInfo)
	end)
	server:registerNetFunction("getUIRoutesForStorageArea", getUIRoutesForStorageArea)
	server:registerNetFunction("addLogisticsRouteDestination", function(clientID, routeInfo)
		return setLogisticsRouteDestinations(clientID, routeInfo.routeID, routeInfo.from, routeInfo.to)
	end)
	--server:registerNetFunction("removeLogisticsRouteDestination", removeLogisticsRouteDestination)
	server:registerNetFunction("changeLogisticsRouteConfig", changeLogisticsRouteConfig)

	server:registerNetFunction("resetTutorial", function(clientID, info)
		serverTutorialState:reset(clientID)
	end)
	

	server:registerNetFunction("changeStorageAreaConfig", changeStorageAreaConfig)
	
	server:registerNetFunction("changeAllowItemUse", clientRequestChangeAllowItemUse)

	server:registerNetFunction("setAutoRoleAssignmentEnabled", clientSetAutoRoleAssignmentEnabled)
	server:registerNetFunction("setTribeName", clientSetTribeName)
	
	
	server:registerNetFunction("getStatistics", getStatistics)
	
	server:registerNetFunction("getNotifications", function(clientID, userData_)
		local userData = userData_ or {}
		if userData.globalNotifications then
			return serverNotifications:getNotifications(nil, userData.startIndexOffset)
		end

		local tribeID = serverWorld:tribeIDForClientID(clientID)
		return serverNotifications:getNotifications(tribeID, userData.startIndexOffset)
	end)
	
	server:registerNetFunction("getResourceObjectCounts", getResourceObjectCounts)
	server:registerNetFunction("addSeenResourceObjectTypesForClientInteraction", addSeenResourceObjectTypesForClientInteraction)

	

	server:registerNetFunction("requestUnloadedObject", clientRequestUnloadedObject)

	server:registerNetFunction("getTribeSapienInfos", function(clientID, userData_)
		local clientTribeID = serverWorld:tribeIDForClientID(clientID)
		return serverTribe:getSapienInfosForUIRequest(userData_.tribeID, clientTribeID, userData_.generateRelationshipIfMissing)
	end)


	server:registerNetFunction("changeTribeRelationsSetting", clientChangeTribeRelationsSetting)

	server:registerNetFunction("getDestinationInfoForClientTribeSelection", clientRequestDestinationInfoForClientTribeSelection)

	server:registerNetFunction("acceptQuest", clientAcceptQuest)
	server:registerNetFunction("buyTradeOffer", clientBuyTradeOffer)

	
	server:registerNetFunction("changeHibernationOnExitDuration", clientChangeHibernationOnExitDuration)
	
	--server:registerNetFunction("getOwnedTribes", getOwnedTribes)
	
	server:registerNetFunction("changeWorldSetting", function(clientID, userData)
		local clientState = clientStates[clientID]
		if clientState then
			local playerID = clientState.playerID
			if playerID then
				if bridge.hostPlayerID == playerID then
					serverWorldSettings:set(userData.key, userData.value)
				end
			end
		end
	end)

	server:registerNetFunction("getWorldSettings", function(clientID)
		return serverWorldSettings:getAll()
	end)


	server:registerNetFunction("debugPing", function(clientID)
		return "p"
	end)
	
end

function serverWorld:addValidOwnerTribe(tribeID)
	if not serverWorld.validOwnerTribeIDs[tribeID] then
		serverWorld.validOwnerTribeIDs[tribeID] = true
		worldDatabase:setDataForKey(serverWorld.validOwnerTribeIDs, "validOwnerTribeIDs")

		server:callClientFunctionForAllClients(
			"validOwnerTribeIDsChanged",
			serverWorld.validOwnerTribeIDs
		)
	end
end

--[[function serverWorld:removeValidOwnerTribe(tribeID) --todo

end]]

function serverWorld:tribeIsValidOwner(tribeID)
	return serverWorld.validOwnerTribeIDs[tribeID]
end

function serverWorld:getTribeRelationsSettings(objectTribeID, sapienTribeID)
	local clientID = serverWorld:clientIDForTribeID(sapienTribeID)
	if clientID then
		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		if privateSharedState and privateSharedState.tribeRelationsSettings then
			return privateSharedState.tribeRelationsSettings[objectTribeID]
		end
	end
	return nil
end

function serverWorld:getAllTribeRelationsSettings(sapienTribeID)
	local clientID = serverWorld:clientIDForTribeID(sapienTribeID)
	if clientID then
		local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
		return privateSharedState and privateSharedState.tribeRelationsSettings
	end
	return nil
end

local debugAnchorCounter = 0

function serverWorld:setBridge(bridge_, isNewWorldCreation)
	bridge = bridge_

	rng:initRandomSeed(math.floor(bridge.worldTime))
	
    serverWorld.yearSpeed = bridge.yearSpeed

	mj:log("Loading world. worldTime:", bridge.worldTime, " yearLength: ", serverWorld:getYearLength())

	--mj:log("disableTribeSpawns:", serverWorldSettings:get("disableTribeSpawns"))

	local initObjects = {
		gameObject = gameObject,
		serverWorld = serverWorld,
		serverGOM = serverGOM,
		serverSapien = serverSapien,
		serverTribeAIPlayer = serverTribeAIPlayer,
		serverDestination = serverDestination,
	}

	server:setServerWorld(serverWorld)
	serverGOM:setServerWorld(serverWorld, serverTribe, serverTribeAIPlayer, serverDestination)
	serverTerrain:setServerGOM(serverGOM, planManager)
	pathCreator:init(initObjects)
	serverStatistics:init(serverWorld)
	serverNotifications:init(serverWorld)
	serverFuel:init(serverWorld, planManager)
	serverTutorialState:init(server, serverWorld, clientStates)

	playersDatabase = bridge:getDatabase("players", true)
	worldDatabase = bridge:getDatabase("world", true)
	serverWorld.worldDatabase = worldDatabase
	creationWorldTime = worldDatabase:dataForKey("creationWorldTime") or 0.0

	weather:setCreationWorldTime(creationWorldTime)
	weather:update(bridge.worldTime)
	
	playerClientIDsByTribeIDs = worldDatabase:dataForKey("tribeList")
	if not playerClientIDsByTribeIDs then
		playerClientIDsByTribeIDs = {}
	end

	serverWorld.recentPlayerTribeList = worldDatabase:dataForKey("recentPlayerTribeList")
	if not serverWorld.recentPlayerTribeList then --migration/init
		serverWorld.recentPlayerTribeList = {}
		if next(playerClientIDsByTribeIDs) then
			local count = 0
			for tribeID,clientD in pairs(playerClientIDsByTribeIDs) do
				table.insert(serverWorld.recentPlayerTribeList, {
					tribeID = tribeID,
					clientD = clientD,
				})
				count = count + 1
				if count >= serverWorld.recentPlayerTribeListMaxSize then
					break
				end
			end
		end
		worldDatabase:setDataForKey(serverWorld.recentPlayerTribeList, "recentPlayerTribeList")
	end

	playerInfos = worldDatabase:dataForKey("playerInfos")
	if not playerInfos then
		playerInfos = {}
	end


	serverWorld.validOwnerTribeIDs = worldDatabase:dataForKey("validOwnerTribeIDs")

	if not serverWorld.validOwnerTribeIDs then --migrate to 0.5, but this may be a new world too
		serverWorld.validOwnerTribeIDs = {}
		for tribeID,clientID in pairs(playerClientIDsByTribeIDs) do
			if clientID ~= mj.serverClientID then
				if playersDatabase:hasKey(clientID) then
					local clientState = playersDatabase:dataForKey(clientID)
					if clientState and clientState.privateShared.tribeID == tribeID then
						serverWorld.validOwnerTribeIDs[tribeID] = true
					end
				end
			end
		end
	end

	
	registerNetFunctions()
	

	serverDestination:init(server, serverWorld, serverGOM, serverTerrain, serverWorld.transientClientStates)
	serverTribe:init(server, serverWorld, serverGOM, serverSapien, serverTerrain, serverDestination, serverCraftArea)
	serverMobGroup:init(serverGOM, serverTerrain, serverMob)

	serverNomadTribe:setServerSapien(serverSapien)
	serverNomadTribe:init(serverWorld, serverGOM, serverTribe, planManager, serverTerrain, playerClientIDsByTribeIDs)
	
	serverStoryEvents:init(serverWorld, serverGOM, serverTribe, serverNomadTribe, serverMobGroup, serverTerrain, serverWeather, serverDestination)

	serverEvolvingTerrain:init(serverWorld, serverGOM, serverTerrain, planManager)
end
--local debugLogCounter = 1

local function updateHappinessStatistics()

	local statsByTribeID = {}
	for tribeID,clientID in pairs(playerClientIDsByTribeIDs) do
		statsByTribeID[tribeID] = {
			count = 0,
			happinessSum = 0,
			loyaltySum = 0,
			skillSum = 0,
		}
	end

	serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function (sapienID) 
		local sapien = serverGOM:getObjectWithID(sapienID)
        if sapien then
			local stats = statsByTribeID[sapien.sharedState.tribeID]
			if stats then
				stats.count = stats.count + 1
				stats.happinessSum = stats.happinessSum + mood:getMood(sapien, mood.types.happySad.index) - 1
				stats.loyaltySum = stats.loyaltySum + mood:getMood(sapien, mood.types.loyalty.index) - 1
				stats.skillSum = stats.skillSum + skill:getSkilledCount(sapien)
			end
		end
    end)

	for tribeID,stats in pairs(statsByTribeID) do
		if stats.count > 0 then
			serverStatistics:setValueForToday(tribeID, statistics.types.averageHappiness.index, ((stats.happinessSum / stats.count) / 5) * 100.0)
			serverStatistics:setValueForToday(tribeID, statistics.types.averageLoyalty.index, ((stats.loyaltySum / stats.count) / 5) * 100.0)
			serverStatistics:setValueForToday(tribeID, statistics.types.averageSkill.index, (stats.skillSum / stats.count))
		else
			serverStatistics:setValueForToday(tribeID, statistics.types.averageHappiness.index, 0)
			serverStatistics:setValueForToday(tribeID, statistics.types.averageLoyalty.index, 0)
			serverStatistics:setValueForToday(tribeID, statistics.types.averageSkill.index, 0)
		end
	end
end


function serverWorld:updateAvailableBedCountStats()
        
	serverWorld.bedCountsByTribeID = {}
	for tribeID,clientID in pairs(playerClientIDsByTribeIDs) do
		serverWorld.bedCountsByTribeID[tribeID] = 0
	end

	serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.beds, function (bedID) 
		local bed = serverGOM:getObjectWithID(bedID)
		if bed then
			if not serverGOM:objectIsInaccessible(bed) then
				local bedTribeID = bed.sharedState.tribeID
				
				for tribeID,count in pairs(serverWorld.bedCountsByTribeID) do
					local valid = true
					if bedTribeID ~= tribeID then
						if serverWorld:tribeIsValidOwner(bedTribeID) then
							local relationshipSettings = serverWorld:getTribeRelationsSettings(bedTribeID, tribeID)
							if not (relationshipSettings and relationshipSettings.allowBedUse) then
								valid = false
							end
						end
					end

					if valid then
						serverWorld.bedCountsByTribeID[tribeID] = count + 1
					end
				end
			end
		end
	end)
	
	for tribeID,count in pairs(serverWorld.bedCountsByTribeID) do
		serverStatistics:setValueForToday(tribeID, statistics.types.bedCount.index, count)
	end
	serverWorld.needsToUpdateBedCounts = false
end

serverWorld.needsToUpdateBedCounts = false

local function updateAvailableBedCountStatsIfNeeded()
    if serverWorld.needsToUpdateBedCounts then
        serverWorld:updateAvailableBedCountStats()
    end
end


local hasSentLiveClients = false
local function sendLatestClientPublicData()
	if multipleClientsConnected() then
		for clientID,v in pairs(serverWorld.connectedClientIDSet) do
			local sendData = {}

			for theirClientID,w in pairs(serverWorld.connectedClientIDSet) do
				if theirClientID ~= clientID then
					sendData[theirClientID] = serverWorld:getPublicClientState(theirClientID)
				end
			end
			if next(sendData) then
				server:callClientFunction(
					"otherClientDataUpdate",
					clientID,
					sendData
				)
				hasSentLiveClients = true
			end
		end
	else
		if gameConstants.debugShowAvatar then
			for clientID,v in pairs(serverWorld.connectedClientIDSet) do
				local publicData = serverWorld:getPublicClientState(clientID)
				local dataToSend = {
					dir = publicData.dir
				}

				local normalizedDir = normalize(normalize(publicData.pos - publicData.dir) - normalize(publicData.pos))
				dataToSend.pos = publicData.pos + normalizedDir * mj:mToP(4.0)
				server:callClientFunction(
					"otherClientDataUpdate",
					clientID,
					{[clientID]=dataToSend}
				)
			end
		else
			if hasSentLiveClients then
				for clientID,v in pairs(serverWorld.connectedClientIDSet) do
					server:callClientFunction(
						"otherClientDataUpdate",
						clientID,
						nil
					)
				end
				hasSentLiveClients = false
			end
		end
	end
end

function serverWorld:sapienLoaded(sapien)
	if serverSapien:isSleeping(sapien) then
		serverWorld:setSapienSleeping(sapien, true)
	end
end

function serverWorld:sapienUnLoaded(sapien)
	serverWorld:setSapienSleeping(sapien, false)
end

function serverWorld:getDebugStatsArray()

	local playerSapienCount = 0
	local nomadSapienCount = 0
	local aiTribeSapienCount = 0

	for tribeID,sapienCount in pairs(serverGOM.loadedSapienCountsByTribe) do
		local destinationState = serverDestination:getDestinationState(tribeID)
		if destinationState and destinationState.clientID then
			playerSapienCount = playerSapienCount + sapienCount
		elseif serverTribeAIPlayer:getIsAIPlayerTribe(tribeID) then
			aiTribeSapienCount = aiTribeSapienCount + sapienCount
		else
			nomadSapienCount = nomadSapienCount + sapienCount
		end
	end

	return {
		{
			title = "connected players",
			value = mj:tostring(serverWorld.connectedClientCount),
		},
		{
			title = "server load",
			value = math.floor((serverWorld.loadIndicator or 0.1) * 10),
		},
		{
			title = "player saps",
			value = mj:tostring(playerSapienCount),
		},
		{
			title = "ai tribe saps",
			value = mj:tostring(aiTribeSapienCount),
		},
		{
			title = "nomad saps",
			value = mj:tostring(nomadSapienCount),
		},
		{
			title = "total sapiens",
			value = mj:tostring(serverGOM.totalLoadedSapienCount),
		},
	}

end

function serverWorld:getPlayerSapienCount()
	local count = 0
	for clientID,v in pairs(server.connectedClientsSet) do
		local tribeID = serverWorld:tribeIDForClientID(clientID)
		count = count + (serverGOM.loadedSapienCountsByTribe[tribeID] or 0)
	end
	return count
end

function serverWorld:sendDebugUIStats()
--serverGOM.loadedSapienCountsByTribe = {}
--serverGOM.totalLoadedSapienCount = 0

	local statsArray = serverWorld:getDebugStatsArray()

	local debugStatsString = nil
	for i,info in ipairs(statsArray) do
		if debugStatsString then
			debugStatsString = debugStatsString .. " | " .. info.title .. ":" .. info.value
		else
			debugStatsString = info.title .. ":" .. info.value
		end
	end

	debugStatsString = debugStatsString .. "\n"
	local first = true
	for mobTypeIndex,count in pairs (serverMob.loadedCountsByMobTypeIndex) do
		if not first then
			debugStatsString = debugStatsString .. " | " 
		end
		debugStatsString = debugStatsString .. mob.types[mobTypeIndex].name .. ":" .. mj:tostring(count)
		first = false
	end

	for clientID,v in pairs(server.connectedClientsSet) do
		local playerName = serverWorld:getPlayerNameForClient(clientID)
		debugStatsString = debugStatsString .. "\n" .. (playerName or clientID)
	end
	

	server:callClientFunctionForAllClients(
		"updateServerDebugStats",
		debugStatsString
	)
end

local statsUpdateCounter = 0
local debugUIStatsDelayCounter = 0.0

--local debugCounter = 0

local function setThrottleSpeedDueToServerLoad(newThrottleSpeedDueToServerLoad)
	if newThrottleSpeedDueToServerLoad ~= throttleSpeedDueToServerLoad then
		throttleSpeedDueToServerLoad = newThrottleSpeedDueToServerLoad
		doSpeedVoteForConnectedPlayers()
		server:callClientFunctionForAllClients(
			"speedThrottleChanged",
			newThrottleSpeedDueToServerLoad
		)
	end
end

--local debugToggleTiemr = 0.0
--local debugToggleValue = false

function serverWorld:update(dt, worldTime, speedMultiplier)

	serverWorld.loadIndicator = (serverWorld.loadIndicator or 0.1) * 0.99 + dt * 0.01

	if serverWorld.loadIndicator > serverLoadFastForwardDisableThreshold * 1.05 then
		setThrottleSpeedDueToServerLoad(true)
	elseif serverWorld.loadIndicator < serverLoadFastForwardDisableThreshold * 0.95 then
		setThrottleSpeedDueToServerLoad(false)
	end

	--[[debugToggleTiemr = debugToggleTiemr + dt
	if debugToggleTiemr > 10.0 then
		debugToggleTiemr = 0.0
		setThrottleSpeedDueToServerLoad(debugToggleValue) --todo remove this and uncomment above
		debugToggleValue = not debugToggleValue
	end]]

	serverDestination:update(dt)
	serverStorageArea:callAnyInitialCallbacks()

	

	--[[if mj.debugObject then
		debugCounter = debugCounter + 1
		if debugCounter > 100 then
			debugCounter = 0
			local object = serverGOM:getObjectWithID(mj.debugObject)
			object.sharedState:set("debugCounter", (object.sharedState.debugCounter or 0) + 1) 
			mj:log("setting debug counter:", object.sharedState.debugCounter)
		end
	end]]

	sendLatestClientPublicData()

	if debugAnchorsClientID then
		debugAnchorCounter = debugAnchorCounter + 1
		if debugAnchorCounter > 10 then
			debugAnchorCounter = 0
			sendDebugAnchors()
		end
	end

	if speedMultiplier < 0.0001 then
		serverDestination:saveDestinationStates()
		return
	end

	serverResourceManager:update()

	------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------- NOTE - everything below won't be run if the game is paused -------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------------------------------

    if skillPriorityListChangedByTribeID then
        for tribeID,v in pairs(skillPriorityListChangedByTribeID) do
			serverSapienSkills:updateTribeAllowedTaskLists(tribeID)
				
			local clientID = serverWorld:clientIDForTribeID(tribeID)
			if clientID then
				server:callClientFunction(
					"skillPriorityListChanged",
					clientID
				)
			end

        end
        skillPriorityListChangedByTribeID = nil
	end

	serverWeather:update(worldTime)
	weather:update(worldTime)
	serverSapienSkills:update()
	serverTribeAIPlayer:update(dt, worldTime, speedMultiplier)


	--[[debugLogCounter = debugLogCounter + 1
	if debugLogCounter > 50 then
		debugLogCounter = 1
		mj:log("sleepingSapienCount:", sleepingSapienCount, " totalClientFollowerCount:", totalClientFollowerCount)
	end]]
	
	local speedMultiplierIndex = bridge.speedMultiplierIndex
	local totalSapienCount = serverGOM.totalLoadedSapienCount

	local thresholdMet = false
	if totalSapienCount > 0 then
		if sleepingSapienCount == totalSapienCount then
			thresholdMet = true
		elseif totalSapienCount - sleepingSapienCount < (0.1 * totalSapienCount) then
			thresholdMet = true
		end
	end

	if thresholdMet then
		if not currentIsSpeedingThroughNight then
			currentIsSpeedingThroughNight = true
			autoSpeedUpRestoreSpeed = speedMultiplierIndex
			updateSpeed(2)
		end
	elseif sleepingSapienCount < totalSapienCount or totalSapienCount == 0 then
		if currentIsSpeedingThroughNight then
			currentIsSpeedingThroughNight = false
			--mj:log("stop currentIsSpeedingThroughNight")
			--mj:log("speedMultiplierIndex:", speedMultiplierIndex)
			--mj:log("autoSpeedUpRestoreSpeed:", autoSpeedUpRestoreSpeed)
			if autoSpeedUpRestoreSpeed ~= nil then
				updateSpeed(autoSpeedUpRestoreSpeed)
			elseif speedMultiplierIndex >= 2 then
				updateSpeed(2)
			end
			autoSpeedUpRestoreSpeed = nil
		end
	end
	
	serverStoryEvents:update(dt, worldTime, speedMultiplier)

	statsUpdateCounter = statsUpdateCounter + dt
	if statsUpdateCounter > 10.0 then
		statsUpdateCounter = 0.0
		updateHappinessStatistics()
	end
	updateAvailableBedCountStatsIfNeeded()

	if gameConstants.sendServerStatsTextDelay then
		debugUIStatsDelayCounter = debugUIStatsDelayCounter + dt
		if debugUIStatsDelayCounter >= gameConstants.sendServerStatsTextDelay then
			debugUIStatsDelayCounter = 0.0
			serverWorld:sendDebugUIStats()
		end
	end

	for tribeID,info in pairs(clientTribeIDsNeedingPlanChangeNotifcations) do
		local clientID = playerClientIDsByTribeIDs[tribeID]
		if server.connectedClientsSet[clientID] then
			server:callClientFunction(
				"orderCountsChanged",
				clientID,
				{
					currentOrderCount = info.queuedCount, 
					maxOrderCount = info.maxPlanCount,
				}
			)
		end
	end
	clientTribeIDsNeedingPlanChangeNotifcations = {}

	planManager:update(dt)
	serverDestination:saveDestinationStates()
end

function serverWorld:distance2FromClosestPlayer(objectNormalizedPos)
	return bridge:distance2FromClosestPlayer(objectNormalizedPos)
end

function serverWorld:getWindDirection(normalizedPos)
	return bridge:getWindDirection(normalizedPos)
end

local closeDistance2 = mj:mToP(15000.0) * mj:mToP(15000.0)

function serverWorld:findSpawnPosition(initialSpawnPosition)
	local found = false
	local spawnPos = normalize(initialSpawnPosition)
	while not found do
		serverTerrain:loadAreaAtLevels(spawnPos, mj.SUBDIVISIONS - 14, mj.SUBDIVISIONS - 12)
		local tribeInfos = serverDestination:findNearByTribesToCheckForSpawnVailidityForPos(spawnPos)
		if tribeInfos then
			if tribeInfos[3] then
				local compareCenter = nil
				local compareFoundCount = 0
				for i,tribeInfo in ipairs(tribeInfos) do
					if compareCenter then
						for j=i + 1,#tribeInfos do
							local distance2 = length2(tribeInfos[j].normalizedPos - compareCenter)
							if distance2 < closeDistance2 then
								compareFoundCount = compareFoundCount + 1
								if compareFoundCount >= 2 then
									return normalize(compareCenter + tribeInfos[j].normalizedPos)
								end
							end
						end
					else
						compareCenter = tribeInfo.normalizedPos
						compareFoundCount = 0
					end
				end
			end
		end
		mj:warn("no tribe cluster found near spawn location. Trying again")
		local randomVec = rng:randomVec()
		spawnPos = normalize(spawnPos + vec3(0.1 * randomVec.x,mj:mToP(1000.0) * randomVec.y,0.1 * randomVec.z))
	end
end

--[[local function checkForIncorrectlyFailedTribe(clientID, clientState)
	local tribeID = clientState.privateShared.tribeID
	if tribeID then
		local currentDestinationState = serverDestination:getDestinationState(tribeID, true)
		--mj:log("checkForIncorrectlyFailedTribe:", currentDestinationState)
		if currentDestinationState.population == 0 and (not (currentDestinationState.hibernatingSapienStates and currentDestinationState.hibernatingSapienStates[1]) ) then
			mj:warn("Found no population for connecting tribe, checking if it was incorrectly marked as failed.")
			serverDestination.destinationsByIDDatabase:callFunctionForAllKeys(function(destinationID,destinationState)
				if destinationState.clientID == clientID then
					mj:log("found matching destination state:", destinationState)
				end
				if destinationState.failedTribe then
					mj:log("found destinationState.failedTribe:", destinationState)
				end
			end)
		end
	end
end]]

function serverWorld:getSessionInfoForConnectingClient(clientID)
	
	local clientState = clientStates[clientID]
	if not clientState then
		clientState = playersDatabase:dataForKey(clientID)
	end

	if clientState then
		--checkForIncorrectlyFailedTribe(clientID, clientState)
		local tribeID = clientState.privateShared.tribeID
		if tribeID then
			local destinationState = serverDestination:getDestinationState(tribeID, true)

			local currentWorldTime = serverWorld:getWorldTime()
			local hibernationTime = ((destinationState.loadState == destination.loadStates.hibernating) and destinationState.hibernationTime)
			if hibernationTime then
				hibernationTime = currentWorldTime - hibernationTime
			end

			local detailedSessionInfo = {
				tribeID = tribeID,
				tribeName = clientState.privateShared.tribeName,
				population = (destinationState and destinationState.population) or 0,
				disconnectWorldTimeDelta = currentWorldTime - (destinationState.clientDisconnectWorldTime or 0),
				loadState = destinationState.loadState,
				hibernationTimeDelta = hibernationTime,
			}
			
			return detailedSessionInfo
		end
	end

	return nil
end

function serverWorld:getPlayerNomadReputation(clientTribeID)
	local clientID = playerClientIDsByTribeIDs[clientTribeID]
	--mj:log("clientID:", clientID)
	if clientID then
	--	mj:log("clientStates[clientID]:", clientStates[clientID])
		local clientState = clientStates[clientID]
		if clientState then
			local reputation = clientState.private.nomadReputation
			if reputation then
				return reputation
			end
		end
	end

	return 45
end

function serverWorld:addToPlayerNomadReputation(clientTribeID, offset)
	local clientID = playerClientIDsByTribeIDs[clientTribeID]
	if clientID and offset ~= 0 then
		local clientState = clientStates[clientID]
		if clientState then
			local reputation = clientState.private.nomadReputation
			reputation = (reputation or 50) + offset
			reputation = mjm.clamp(reputation, 0, 100)
			clientState.private.nomadReputation = reputation
			serverWorld:saveClientState(clientID)
			mj:log("addToPlayerNomadReputation:", clientTribeID, " offset:", offset, " new reputation:", reputation)
		end
	end

	return 45
end

return serverWorld