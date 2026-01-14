local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local dot = mjm.dot
local mat3Identity = mjm.mat3Identity

local controller = mjrequire "mainThread/controller"
local logicInterface = mjrequire "mainThread/logicInterface"
local localPlayer = mjrequire "mainThread/localPlayer"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local animationManager = mjrequire "mainThread/animationManager"
local gameUI = mjrequire "mainThread/ui/gameUI"
local timeControls = mjrequire "mainThread/ui/timeControls"
local audio = mjrequire "mainThread/audio"
local physicsSets = mjrequire "common/physicsSets"
local gameObject = mjrequire "common/gameObject"
local fuel = mjrequire "common/fuel"
local planHelper = mjrequire "common/planHelper"
local typeMaps = mjrequire "common/typeMaps"
local evolvingObject = mjrequire "common/evolvingObject"
local research = mjrequire "common/research"
local profiler = mjrequire "common/profiler"
local weather = mjrequire "common/weather"
local gameConstants = mjrequire "common/gameConstants"
local compostBin = mjrequire "common/compostBin"
local musicPlayer = mjrequire "mainThread/musicPlayer"
local playerSapiens = mjrequire "mainThread/playerSapiens"
local mainThreadDestination = mjrequire "mainThread/mainThreadDestination"
local connectionTest = mjrequire "mainThread/connectionTest"
local hubUIUtilities = mjrequire "mainThread/ui/hubUIUtilities"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"
--local constructable = mjrequire "common/constructable"
--local resource = mjrequire "common/resource"

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local uiObjectManager = mjrequire "mainThread/uiObjectManager"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
--local tutorialUI = mjrequire "mainThread/ui/tutorialUI"

local world = {
	isVR = false,
	hasUsedMultiselect = false,
	validOwnerTribeIDs = {}
}

local bridge = nil
local serverClientState = nil
local clientWorldSettingsDatabase = nil

local constructableRestrictedObjectTypes = {}
local clientWorldSettings = {} --for general stuff, don't let this get toooo big

local hasQueuedResearchPlan = false
local hasLoadedCraftOrStorageArea = false
local hasUsedTasksUI = false

local detailedSessionInfoVersion = 1

local timeBetweenMainMenuInfoSaves = 31.27
local saveForMainMenuTimer = timeBetweenMainMenuInfoSaves

local function getMidday()
	if bridge.globalTimeZone then
		return math.pi * 1.5
	else
		local playerXZ = world:getRealPlayerHeadPos()
		playerXZ.y = 0
		local playerNormal = normalize(playerXZ)
		local sunRotation = math.acos(dot(playerNormal, vec3(0.0,0.0,1.0)))
		if dot(playerNormal, vec3(1.0,0.0,0.0)) > 0.0 then
			sunRotation = -sunRotation
		end
		return sunRotation
	end
end

local function setTimeFromSunRotation(sunRotation)
	logicInterface:callServerFunction("setTimeFromSunRotation", {
		rotation = sunRotation
	})
end

function world:setMidnight(offset)
	local sunRotation = getMidday() + math.pi
	if offset then
		sunRotation =sunRotation + offset
	end
	setTimeFromSunRotation(sunRotation)
end

function world:setMidday(offset)
	local sunRotation = getMidday()
	if offset then
		sunRotation =sunRotation + offset
	end
	setTimeFromSunRotation(sunRotation)
end

function world:setSunset(offset)
	--[[local sunRotation = getMidday() + math.pi * 0.5
	if offset then
		sunRotation =sunRotation + offset
	end
	setTimeFromSunRotation(sunRotation)]]
	
	local seasonRotation = math.sin(bridge.worldTime * world.yearSpeed * math.pi * 2.0)
	local sunTilt = 0.41 * seasonRotation

	local playerXYZ = normalize(world:getRealPlayerHeadPos())
	local latitude = math.asin(playerXYZ.y)
	local longitude = 0
	if math.abs(playerXYZ.x) + math.abs(playerXYZ.z) > 0.0000001 then
		longitude = math.atan2(playerXYZ.z, playerXYZ.x)
	end

	local hourAngleBase = -math.acos(-math.tan(latitude) * math.tan(-sunTilt))

	if not mj:isNan(hourAngleBase) then
		local sunRotation = hourAngleBase + longitude + math.pi * 0.5
		if offset then
			sunRotation = sunRotation + offset
		end
		setTimeFromSunRotation(sunRotation)
	end
end


function world:setSunriseForNormalizedPosition(normalizedPos, offset)
	
	local seasonRotation = math.sin(bridge.worldTime * world.yearSpeed * math.pi * 2.0)
	local sunTilt = 0.41 * seasonRotation

	local playerXYZ = normalizedPos
	local latitude = math.asin(playerXYZ.y)
	local longitude = 0
	if math.abs(playerXYZ.x) + math.abs(playerXYZ.z) > 0.0000001 then
		longitude = math.atan2(playerXYZ.z, playerXYZ.x)
	end

	local hourAngleBase = math.acos(-math.tan(latitude) * math.tan(-sunTilt))

	if not mj:isNan(hourAngleBase) then
		local sunRotation = hourAngleBase + longitude + math.pi * 0.5
		if offset then
			sunRotation = sunRotation + offset
		end
		setTimeFromSunRotation(sunRotation)
	end
end

function world:setSunrise(offset)
	world:setSunriseForNormalizedPosition(normalize(world:getRealPlayerHeadPos()), offset)
end


function world:setSunRotationOverride(sunRotation) --changes where sun is rendered mostly just visually, influences some time-of-day functions, but it's only client-side so should be safe enough
	bridge:setSunRotationOverride(sunRotation)
end


function world:setMiddayVisualOnly(offsetOrNil)
	local sunRotation = getMidday()
	if offsetOrNil then
		sunRotation = sunRotation + offsetOrNil
	end
	world:setSunRotationOverride(sunRotation)
end

function world:exportDebugImage()
	bridge:exportDebugImage()
end

--[[function ed()
	world:exportDebugImage()
end]]

function setSunrise(offset)
	world:setSunrise(offset)
end

function setSunset(offset)
	world:setSunset(offset)
end

function printType(typeIndex)
	typeMaps:printType(typeIndex)
end

function tp(objectID)
	if type(objectID) ~= "string" then
		mj:log("tp ID must be a string, did you forget the quotes?")
		return
	end
	gameUI:debugTeleport(mj:tostring(objectID))
end

function wakeTribe(tribeID) --debug function
	logicInterface:callServerFunction("wakeTribe", tribeID)
end

function setDebugObject(objectIDToUse)
	logicInterface:callServerFunction("changeDebugObject", objectIDToUse)
end

function spawn(objectTypeIndexOrName, quantityOrNil) -- cheat
	local objectType = gameObject.types[objectTypeIndexOrName]
	if not objectType then
		mj:log("no object type found with that name or id")
		return
	end

	logicInterface:callServerFunction("spawnCheat", {
		objectTypeIndexOrName = objectTypeIndexOrName,
		pos = localPlayer:getNormalModePos(),
		rotation = localPlayer:getNormalModeRotation(),
		quantity = quantityOrNil,
	})

end

function buildCheat() -- cheat
	logicInterface:callServerFunction("buildCheat")
end

function researchCheat() -- cheat
	logicInterface:callServerFunction("researchCheat")
end

function world:getServerClientState()
	return serverClientState
end

function world:getMainThreadTerrainAltitude(pos)
	return bridge:getMainThreadTerrainAltitude(pos)
end

function world:objectIsLoaded(objectID) --is loaded in main thread geometry, ready to be tested against in the below methods
	return bridge:objectIsLoaded(objectID)
end

function world:rayTest(rayStart, rayEnd, additionalWorldObjectPrimitiveKeyBaseOrNil, physicsSetIndexOrNil, collideWithSeaLevel)
	return bridge:rayTest(rayStart, rayEnd, additionalWorldObjectPrimitiveKeyBaseOrNil, physicsSetIndexOrNil, collideWithSeaLevel)
end

-- boxTest and modelTest construct a temporary physics world, and can test either a box or the box and sphere primitives within a model file against the world geometry near by.
-- They are heavy weight and slow. They can use the mesh for the world objects they test against (slowest) or the static geometry, or a supplied primitive base (eg. "placeCollide").

--the results returned by boxTest are ordered by distance from pos
function world:boxTest(pos, rotation, halfSize, physicsSetIndexOrNil, collideWithModelPrimitivesBaseOrNil)
	return bridge:boxTest(pos, rotation, halfSize, physicsSetIndexOrNil, collideWithModelPrimitivesBaseOrNil)
end


-- the results returned by modelTest are ordered by distance from pos
function world:modelTest(pos, rotation, scale, modelIndex, testModelPrimitivesKeyBase, collideWithModelPrimitivesBaseOrNil, testTerrain, useMeshForWorldObjects, physicsSetIndexOrNil)
	return bridge:modelTest(pos, rotation, scale, modelIndex, testModelPrimitivesKeyBase, collideWithModelPrimitivesBaseOrNil, testTerrain, useMeshForWorldObjects, physicsSetIndexOrNil)
end

-- for multiple tests with the same model, but different positions, use multi-test. Calling startMultiModelTest sets up a bunch of state for subsequent multModelTest calls. 
-- WARNING calling either of the above boxTest/modelTest (but not rayTest, that's fine and faster) methods will reset that state, causing multiModelTest to fail until the next call to startMultiModelTest

function world:startMultiModelTest(pos, scale, modelIndex, collideWithModelPrimitivesBaseOrNil, testTerrain, useMeshForWorldObjects, physicsSetIndexOrNil, otherModelInfosOrNil)
	bridge:startMultiModelTest(pos, scale, modelIndex, collideWithModelPrimitivesBaseOrNil, testTerrain, useMeshForWorldObjects, physicsSetIndexOrNil, otherModelInfosOrNil)
end

function world:multiModelTest(pos, rotation, testModelPrimitivesKeyBase)
	return bridge:multiModelTest(pos, rotation, testModelPrimitivesKeyBase)
end

function world:modelToModelTest(testModelInfo, --doesn't actually test against the world, just tests one model with one or more other models
otherModelInfos,
testModelPrimitivesKeyBase,
collideWithModelPrimitivesBaseOrNil,
physicsSetIndexOrNil)

	return bridge:modelToModelTest(testModelInfo, 
	otherModelInfos,
	testModelPrimitivesKeyBase,
	collideWithModelPrimitivesBaseOrNil,
	physicsSetIndexOrNil)
end

function world:rayToModelTest(rayStart, --doesn't actually test against the world, just tests a ray agains one or more models. Currently only tests against collideWithModelPrimitivesBase, not model faces
rayEnd,
otherModelInfos,
collideWithModelPrimitivesBase,
physicsSetIndexOrNil)
	
	return bridge:rayToModelTest(rayStart, 
	rayEnd,
	otherModelInfos,
	collideWithModelPrimitivesBase,
	physicsSetIndexOrNil)
end

function world:objectCentersRadiusTest(pos, radius, physicsSetIndexOrNil)
	return bridge:objectCentersRadiusTest(pos, radius, physicsSetIndexOrNil)
end

function world:retrieveTrianglesWithinRadius(pos, radius)
	return bridge:retrieveTrianglesWithinRadius(pos, radius)
end

function world:doSlopeCheckForBuildModel(pos, rotation, scale, modelIndex, attachableObjectTypeSetIndex)
	return bridge:doSlopeCheckForBuildModel(pos, rotation, scale, modelIndex, attachableObjectTypeSetIndex)
end

function world:getVertsAffectedByBuildModel(pos, rotation, scale, modelIndex, minAltitude)
	return bridge:getVertsAffectedByBuildModel(pos, rotation, scale, modelIndex, minAltitude)
end

function world:setObjectTypesForPhysicsSet(setIndex, gameObjectTypes)
	bridge:setObjectTypesForMainThreadPhysicsSet(setIndex, gameObjectTypes)
end

function world:getMainThreadDynamicObjectInfo(objectID)
	return bridge:getDynamicObjectInfo(objectID)
end

function world:getPointerRayStart()
	return bridge:getPointerRayStart()
end

function world:getPointerRayStartForPlayerAtPosition(pos)
	return bridge:getPointerRayStartForPlayerAtPosition(pos)
end

function world:getRayDirectionForScreenFraction(screenFraction)
	return bridge:getRayDirectionForScreenFraction(screenFraction)
end

function world:getPointerRayDirection()
	return bridge:getPointerRayDirection()
end

function world:getPointerRayStartUISpace()
	return bridge:getPointerRayStartUISpace()
end

function world:getPointerRayDirectionUISpace()
	return bridge:getPointerRayDirectionUISpace()
end

function world:getPointerLocalZRotation()
	return bridge:getPointerLocalZRotation()
end

function world:getTeleportRayStart()
	return bridge:getTeleportRayStart()
end

function world:getTeleportRayDirection()
	return bridge:getTeleportRayDirection()
end

function world:getRealPlayerLookDirection()
	return bridge:getRealPlayerLookDirection()
end

function world:getRealPlayerHeadPos()
	return bridge:getRealPlayerHeadPos()
end

function world:getHeadOffset()
	return bridge:getHeadOffset()
end

function world:getHeadDirectionUISpace()
	return bridge:getHeadDirectionUISpace()
end

function world:getHeadPositionUISpace()
	return bridge:getHeadPositionUISpace()
end

function world:setPointerLengthMeters(pointerLengthMeters)
	bridge.pointerLengthMeters = pointerLengthMeters
end

function world:setPointerIntersection(pointerIntersection)
	bridge.pointerIntersection = pointerIntersection
end


function world:setTeleportPos(teleportPos)
	bridge.teleportPos = teleportPos
end

function world:setTeleportIntersection(teleportIntersection)
	bridge.teleportIntersection = teleportIntersection
end


function world:setPointerActive(newActive)
	bridge.pointerActive = newActive
end
function world:getPointerActive()
	return bridge.pointerActive
end

function world:setTeleportActive(newActive)
	bridge.teleportActive = newActive
end

function world:getTeleportActive()
	return bridge.teleportActive
end

function world:getWorldTime()
	return bridge.worldTime
end

function world:getSpeedMultiplier()
	return bridge.speedMultiplier
end

function world:getSpeedMultiplierIndex()
	return bridge.speedMultiplierIndex
end

function world:getDayLength()
	return (math.pi * 2.0) / world.sunRotationSpeed
end

function world:getSunRotationSpeed()
	return world.sunRotationSpeed
end

function world:getYearLength()
	return 1.0 / world.yearSpeed
end

function world:getStatsIndex()
	local dayLength = (math.pi * 2) / world.sunRotationSpeed
	return math.floor((bridge.worldTime / dayLength) * 8.0) + 1
end

function world:getYearIndex()
	local yearLength = world:getYearLength()
	return math.floor(bridge.worldTime / yearLength) + 1
end

function world:getStatsFrameLength()
	local dayLength = (math.pi * 2) / world.sunRotationSpeed
	return dayLength / 8.0
end

function world:getTimeOfDayFraction(worldLocationOrNil)
	local worldLocation = worldLocationOrNil or world:getRealPlayerHeadPos()
	return bridge:getTimeOfDayFraction(worldLocation)
end

function world:playerTemperatureZoneChanged(newTemperatureZoneIndex)
	gameUI:playerTemperatureZoneChanged(newTemperatureZoneIndex)
end

function world:getTribeAge() --todo use our destinationState's assignedToClientWorldTime
	return world:getWorldTime() - (world.creationWorldTime or 0)
end

local cloudCoverGoal = nil
local cloudCover = nil
local cloudHiddenDueToMapMode = false
local windStrength = 0.1
local windStrengthGoal = 0.1

function world:playerWeatherChanged(weatherInfo)
	cloudCoverGoal = mjm.clamp(weatherInfo.cloudCover, 0.0, 1.0)
	if (not cloudCover) and (not cloudHiddenDueToMapMode) then
		cloudCover = cloudCoverGoal
	end

	windStrengthGoal = weatherInfo.windStrength
	--mj:log("windStrengthGoal:", windStrengthGoal)
	
	musicPlayer:setSnowing(weatherInfo.combinedSnow > 0.1)
	--bridge.cloudCover = mjm.clamp(newCloudCover, 0.0, 1.0)
end

function world:update(dt)
	saveForMainMenuTimer = saveForMainMenuTimer - dt
	if saveForMainMenuTimer < 0.0 then
		world:doSaveDetailedInfoForMainMenu()
	end
	local dtWithSpeedMultiplierApplied = dt * world:getSpeedMultiplier()

	if cloudHiddenDueToMapMode then
		bridge.cloudCover = 0.0
		cloudCover = 0.0
	else
		if cloudCoverGoal then
			cloudCover = cloudCover + (cloudCoverGoal - cloudCover) * math.min(dtWithSpeedMultiplierApplied, 1.0)
		end
		bridge.cloudCover = cloudCover
	end

	windStrength = windStrength + (windStrengthGoal - windStrength) * math.min(dtWithSpeedMultiplierApplied, 1.0)
	bridge.windStrength = windStrength
	
    audio:update(dt)
    weather:update(world:getWorldTime())
	animationManager:update(dtWithSpeedMultiplierApplied)
end

function world:orderCountsChanged(currentOrderCount, maxOrderCount)
	gameUI:updateOrdersText(currentOrderCount, maxOrderCount)
	tutorialUI:orderCountsChanged(currentOrderCount, maxOrderCount)
	hubUIUtilities:orderCountsChanged(currentOrderCount, maxOrderCount)
end

function world:setMapMode(newMapMode)
	--mj:log("world:setMapMode:", newMapMode)
	if newMapMode then 
		cloudHiddenDueToMapMode = true
	else
		cloudHiddenDueToMapMode = false
	end
    bridge:setMapMode(newMapMode)
end

local isTemporaryPauseForPopup = false
function world:setPaused()
	isTemporaryPauseForPopup = false
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex ~= 0 then
		logicInterface:callServerFunction("setPaused", true)
	end
end


function world:isPaused()
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	return speedMultiplierIndex == 0
end

function world:startTemporaryPauseForPopup()
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	local wasPaused = (speedMultiplierIndex == 0)
	if not wasPaused then
		isTemporaryPauseForPopup = true
		logicInterface:callServerFunction("setTemporaryPausedIfNonMultiplayer")
	end
end

function world:endTemporaryPauseForPopup()
	if isTemporaryPauseForPopup then
		logicInterface:callServerFunction("resumeAfterTemporaryPause", false)
	end
	isTemporaryPauseForPopup = false
end

function world:setPlay()
	isTemporaryPauseForPopup = false
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex ~= 1 then
		logicInterface:callServerFunction("setPaused", false)
		logicInterface:callServerFunction("setFastForward", false)
		logicInterface:callServerFunction("setSlowMotion", false)
		timeControls:updateLocalSpeedPreference(1)
	end
end

function world:setFastForward()
	isTemporaryPauseForPopup = false
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex ~= 2 then
		logicInterface:callServerFunction("setFastForward", true)
		timeControls:updateLocalSpeedPreference(2)
	end
end

function world:toggleFast()
	isTemporaryPauseForPopup = false
	tutorialUI:playerToggledFastForward()
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex ~= 2 then
		logicInterface:callServerFunction("setFastForward", true)
		timeControls:updateLocalSpeedPreference(2)
	else
		logicInterface:callServerFunction("setFastForward", false)
		timeControls:updateLocalSpeedPreference(1)
	end
end

function world:toggleSlowMotion()
	isTemporaryPauseForPopup = false
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex ~= 9 then
		logicInterface:callServerFunction("setSlowMotion", true)
		timeControls:updateLocalSpeedPreference(0)
	else
		logicInterface:callServerFunction("setSlowMotion", false)
		timeControls:updateLocalSpeedPreference(0)
	end
end

function world:togglePause()
	isTemporaryPauseForPopup = false
	tutorialUI:playerToggledPause()
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex ~= 0 then
		logicInterface:callServerFunction("setPaused", true)
		timeControls:updateLocalSpeedPreference(0)
	else
		logicInterface:callServerFunction("setPaused", false)
		timeControls:updateLocalSpeedPreference(1)
	end
end

function world:increaseSpeed()
	isTemporaryPauseForPopup = false
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex == 0 then
		world:setPlay()
	elseif speedMultiplierIndex == 1 then
		world:setFastForward()
	end
end

function world:decreaseSpeed()
	isTemporaryPauseForPopup = false
	local speedMultiplierIndex = timeControls:getLocalSpeedPreference()
	if speedMultiplierIndex >= 2 then
		world:setPlay()
	elseif speedMultiplierIndex == 1 then
		world:setPaused()
	end
end


local speedMultiplierChangedListeners = {}

local function speedMultiplierChanged(newSpeedMultiplier, newSpeedMultiplierIndex)
	for i,func in ipairs(speedMultiplierChangedListeners) do
		func(newSpeedMultiplier, newSpeedMultiplierIndex)
	end
	audio:setSpeedMultiplier(newSpeedMultiplier)
end

local fillConstructableTypeIndex = nil

function world:hasSelectedTribeID()
	return serverClientState.privateShared.tribeID ~= nil
end

function world:getTribeID()
	return serverClientState.privateShared.tribeID
end

function world:getTribeName()
	return serverClientState.privateShared.tribeName
end

function world:setTribeName(tribeName)
	serverClientState.privateShared.tribeName = tribeName
	local info = mainThreadDestination.destinationInfosByID[serverClientState.privateShared.tribeID]
	if info then
		info.name = tribeName
	end
	logicInterface:callServerFunction("setTribeName", tribeName)
	world:doSaveDetailedInfoForMainMenu()
end

function world:getAutoRoleAssignmentEnabled()
	return (not serverClientState.privateShared.autoRoleAssignmentDisabled)
end

function world:setAutoRoleAssignmentEnabled(newEnabled)
	serverClientState.privateShared.autoRoleAssignmentDisabled = (not newEnabled)
	logicInterface:callServerFunction("setAutoRoleAssignmentEnabled", newEnabled)
end

function world:setDisableTransparantBuildObjectRender(disableTransparantBuildObjectRender)
	bridge:setDisableTransparantBuildObjectRender(disableTransparantBuildObjectRender)
end

function world:queueSaveForMainMenu()
	saveForMainMenuTimer = -1.0
end

function world:doSaveDetailedInfoForMainMenu()

    local function sanitizeSharedState(sharedState)
        local sharedStateCopy = mj:cloneTable(sharedState)
        sharedStateCopy.orderQueue = {}
        sharedStateCopy.actionState = nil
        sharedStateCopy.activeOrder = nil
        sharedStateCopy.actionModifiers = nil
        --mj:log("sanitizeSharedState sharedState:", sharedStateCopy)
        return sharedStateCopy
    end

	local sapienInfos = nil

	local followerInfos = playerSapiens:getFollowerInfos()
	if followerInfos and next(followerInfos) then
		sapienInfos = {}
		for sapienID, info in pairs(followerInfos) do
			local saveInfo = {
				uniqueID = sapienID,
				sharedState = sanitizeSharedState(info.sharedState)
			}
			sapienInfos[sapienID] = saveInfo
		end
	end

	local detailedSessionInfo = controller:getDetailedWorldSessionInfoForCurrentWorld() or {}

	detailedSessionInfo.tribeID = world:getTribeID()
	detailedSessionInfo.tribeName = world:getTribeName()
	detailedSessionInfo.population = playerSapiens:getPopulationCountIncludingBabies()
	detailedSessionInfo.sapienInfos = sapienInfos
	detailedSessionInfo.version = detailedSessionInfoVersion
	
	controller:saveDetailedWorldSessionInfoForCurrentWorld(detailedSessionInfo)

	saveForMainMenuTimer = timeBetweenMainMenuInfoSaves
end

function world:getIsOnlineClient()
	return bridge.isOnlineClient
end

function world:setBridge(bridge_, serverClientState_, isVR_)
	--mj:log("world:setBridge a")
	bridge = bridge_
	world.isVR = isVR_
	serverClientState = serverClientState_
	if serverClientState.gameConstantsConfig then
		for k,v in pairs(serverClientState.gameConstantsConfig) do
			mj:log("overriding local game constant with server value:", k, "=>", v)
			gameConstants[k] = v
		end
	end
	clientWorldSettingsDatabase = bridge.clientWorldSettingsDatabase
	audio:setSpeedMultiplier(bridge.speedMultiplier)
	
    world.yearSpeed = bridge.yearSpeed
	world.sunRotationSpeed = bridge.sunRotationSpeed
	world.localPlayer = localPlayer
	--mj:log("world:setBridge b")

	controller:setIsOnlineClient(bridge.isOnlineClient)

    gameObject:setYearLength(1.0 / world.yearSpeed)
    gameObject:setLocalTribeID(world.tribeID)

	fillConstructableTypeIndex = clientWorldSettingsDatabase:dataForKey("fillConstructableTypeIndex")

	local discoveries = serverClientState.privateShared.discoveries
	if discoveries then
		local function checkResearch(researchTypeIndex)
			return discoveries[researchTypeIndex] and (discoveries[researchTypeIndex].complete or discoveries[researchTypeIndex].fractionComplete)
		end
		if checkResearch(research.types.rockKnapping.index) then
			hasQueuedResearchPlan = true
		elseif checkResearch(research.types.fire.index) then
			hasQueuedResearchPlan = true
		end
	end

	--mj:log("world:setBridge c")
	
	if not clientWorldSettingsDatabase:dataForKey("hasCheckedForTutorialSkip") then
		clientWorldSettingsDatabase:setDataForKey(true, "hasCheckedForTutorialSkip")
		if not clientGameSettings.values.enableTutorialForNewWorlds then
			clientWorldSettingsDatabase:setDataForKey(true, "tutorialSkipped")
		end
    end


	local savedConstructableRestrictedObjectTypes = clientWorldSettingsDatabase:dataForKey("constructableRestrictedObjectTypes")
	if savedConstructableRestrictedObjectTypes then
		constructableRestrictedObjectTypes = savedConstructableRestrictedObjectTypes
	end
	
	local savedClientWorldSettings = clientWorldSettingsDatabase:dataForKey("clientWorldSettings")
	if savedClientWorldSettings then
		clientWorldSettings = savedClientWorldSettings
	end
	--mj:log("world:setBridge d")
	
	mainThreadDestination:init(world)
	gameUI:init(controller, world)
	connectionTest:init(world, logicInterface)
	logicInterface:init(world, localPlayer)
	localPlayer:init(world, gameUI)
	--mj:log("world:setBridge e")
	animationManager:setWorld(world)
	--mj:log("world:setBridge f")
	planHelper:init(world, nil)
	evolvingObject:init(world:getDayLength(), world:getYearLength())
	compostBin:setDayLength(world:getDayLength(), function()
		return world:getWorldTime()
	end)

	physicsSets:init(world, gameObject)
	--mj:log("world:setBridge g")

	clientGameSettings:addObserver("renderDistance", function(newValue)
		bridge.renderDistance = newValue
	end)

	clientGameSettings:addObserver("grassDistance", function(newValue)
		bridge.decalRenderDistance = newValue
	end)

	clientGameSettings:addObserver("grassDensity", function(newValue)
		logicInterface:callLogicThreadFunction("setGrassDensity", newValue)
	end)
	logicInterface:callLogicThreadFunction("setGrassDensity", clientGameSettings.values.grassDensity)
	
	--mj:log("world:setBridge h")

	clientGameSettings:addObserver("ssao", function(newValue)
		bridge.ssaoEnabled = newValue
	end)

	clientGameSettings:addObserver("contourAlpha", function(newValue)
		bridge.contourAlpha = newValue
	end)
	bridge.contourAlpha = clientGameSettings.values.contourAlpha
	

	
	clientGameSettings:addObserver("highQualityWater", function(newValue)
		bridge.highQualityWater = newValue
	end)
	
	clientGameSettings:addObserver("brightness", function(newValue)
		bridge.brightness = newValue
	end)
	
	clientGameSettings:addObserver("animatedObjectsCount", function(newValue)
		bridge.animatedObjectsCount = newValue
	end)
	
	
	bridge.speedMultiplierChangedFunction = speedMultiplierChanged
	bridge:setCloseBoundingRadiusDistanceForBonedObjects(mj:mToP(10.0))
	--mj:log("world:setBridge done")

	--world:setSunrise()

	--bridge.dataDisplay = 8
end

function world:addSpeedChangeListener(listenerFunc)
	table.insert(speedMultiplierChangedListeners, listenerFunc)
end

function world:serverPrivateSharedClientStateChanged(serverPrivateSharedClientState)
	serverClientState.privateShared = serverPrivateSharedClientState
	--mj:error("world:serverPrivateSharedClientStateChanged:", serverPrivateSharedClientState)
	world.tribeID = serverPrivateSharedClientState.tribeID
	if world.tribeID then
		world.validOwnerTribeIDs[world.tribeID] = true
		gameObject:setLocalTribeID(world.tribeID)
		tutorialUI:worldTribeIDReceived(world.tribeID)
		gameObject:setTribeRelationsSettings(serverPrivateSharedClientState.tribeRelationsSettings)
		planHelper:setDiscoveriesForTribeID(world.tribeID, serverPrivateSharedClientState.discoveries, serverPrivateSharedClientState.craftableDiscoveries)
	end
end


function world:creationWorldTimeChanged(creationWorldTime)
	world.creationWorldTime = creationWorldTime
	weather:setCreationWorldTime(creationWorldTime)
end

function world:validOwnerTribeIDsChanged(validOwnerTribeIDs)
	world.validOwnerTribeIDs = validOwnerTribeIDs
end

function world:tribeIsValidOwner(tribeID)
	return world.validOwnerTribeIDs[tribeID]
end

function world:resetDueToTribeFail(info)
	mj:log("resetDueToTribeFail:", info)
	serverClientState.privateShared = info.privateShared
	world.tribeID = serverClientState.privateShared.tribeID
	if world.tribeID then --does this ever happen?
		world.validOwnerTribeIDs[world.tribeID] = true
		gameObject:setLocalTribeID(world.tribeID)
		tutorialUI:worldTribeIDReceived(world.tribeID)
	end
	
	gameUI:setupForTribeFailReset(serverClientState.privateShared.failPositions)
	
	localPlayer:teleportToPos(info.resetTeleportPoint, true)
	--localPlayer:setMapMode(mapModes.global, true)
	localPlayer:zoomOutToMapForTribeFail()

	audio:playUISound("audio/sounds/events/disaster1.wav")

	mj:log("resetDueToTribeFail done world:hasSelectedTribeID():", world:hasSelectedTribeID())
	world:queueSaveForMainMenu()
	gameObject:setTribeRelationsSettings(serverClientState.privateShared.tribeRelationsSettings)
end

function world:serverDiscoveriesChanged(discoveries)
	if world.tribeID then
		serverClientState.privateShared.discoveries = discoveries
		planHelper:setDiscoveriesForTribeID(world.tribeID, discoveries, serverClientState.privateShared.craftableDiscoveries)
	end
end

function world:serverCraftableDiscoveriesChanged(craftableDiscoveries)
	if world.tribeID then
		serverClientState.privateShared.craftableDiscoveries = craftableDiscoveries
		planHelper:setDiscoveriesForTribeID(world.tribeID, serverClientState.privateShared.discoveries, craftableDiscoveries)
	end
end

function world:serverLogisticsRoutesChanged(logisticsRoutes)
	if world.tribeID then
		serverClientState.privateShared.logisticsRoutes = logisticsRoutes
	end
end

function world:serverTribeRelationsSettingsChanged(tribeRelationsSettingsInfo)
	if world.tribeID then
		serverClientState.privateShared.tribeRelationsSettings[tribeRelationsSettingsInfo.tribeID] = tribeRelationsSettingsInfo.tribeRelationsSettings
		gameObject:setTribeRelationsSettings(serverClientState.privateShared.tribeRelationsSettings)
		tribeRelationsUI:updateDueToTribeRelationsSettingsChange(tribeRelationsSettingsInfo.tribeID)
	end
end

function world:serverWeatherChanged(serverWeatherInfo)
	weather:setServerWeatherInfo(serverWeatherInfo)
end

function world:speedThrottleChanged(newIsThrottled)
	timeControls:setFastForwardDisabledByServer(newIsThrottled)
end

function world:getFailPositions()
	return serverClientState.privateShared.failPositions
end

function world:serverAssignedTribe(tribeID)
	world.tribeID = tribeID
	world.validOwnerTribeIDs[world.tribeID] = true
    gameObject:setLocalTribeID(world.tribeID)
	tutorialUI:worldTribeIDReceived(world.tribeID)
	planHelper:setDiscoveriesForTribeID(world.tribeID, serverClientState.privateShared.discoveries, serverClientState.privateShared.craftableDiscoveries)
	world:queueSaveForMainMenu()
	controller:removeAnySavedTribeNotMatchingCurrentClientID(tribeID)
	controller:incrementCurrentWorldSessionIndexForTribeLoad()
end

function world:seenResourceObjectTypesAdded(objectTypeIndexes)
	--mj:log("seenResourceObjectTypeAdded:", objectTypeIndex)
	for i,objectTypeIndex in ipairs(objectTypeIndexes) do
		serverClientState.privateShared.seenResourceObjectTypes[objectTypeIndex] = true
	end
end

function world:getResourceObjectCountsFromServer(callback)
	logicInterface:callServerFunction("getResourceObjectCounts", nil, callback)
end

function world:addSeenResourceObjectTypesForClientInteraction(objectTypeIndexSet)
	local typesToSend = nil
	local seenResourceObjectTypes = serverClientState.privateShared.seenResourceObjectTypes

	local function checkObjectType(objectTypeIndex)
		if not seenResourceObjectTypes[objectTypeIndex] then
			seenResourceObjectTypes[objectTypeIndex] = true
			if not typesToSend then
				typesToSend = {}
			end
			table.insert(typesToSend, objectTypeIndex)
		end
	end

	for objectTypeIndex,v in pairs(objectTypeIndexSet) do
		checkObjectType(objectTypeIndex)
		local toType = objectTypeIndex

		for i=1,4 do --sanity counter
			local evolution = evolvingObject.evolutions[toType]
			toType = evolution and evolution.toType
			if toType then
				checkObjectType(toType)
			else
				break
			end
		end
	end

	if typesToSend then
		logicInterface:callServerFunction("addSeenResourceObjectTypesForClientInteraction", typesToSend) --server function not implemented
	end
end

function world:getLogisticsRoutes()
	local logisticsRoutes = serverClientState.privateShared.logisticsRoutes
	if not logisticsRoutes then
		logisticsRoutes = {
			routes = {},
			routeIDCounter = 0,
		}
		serverClientState.privateShared.logisticsRoutes = logisticsRoutes
	end
	return logisticsRoutes
end

function world:tribeHasSeenResource(resourceTypeIndex)
	--mj:log("world:tribeHasSeenResource:", resourceTypeIndex)
	local seenResourceObjectTypes = serverClientState.privateShared.seenResourceObjectTypes
	--mj:log("seenResourceObjectTypes:", seenResourceObjectTypes)
	local resourceObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
	for i,objectTypeIndex in ipairs(resourceObjectTypes) do
		if seenResourceObjectTypes[objectTypeIndex] then
			--mj:log("return true:", objectTypeIndex)
			return true
		end
	end
	return false
end

function world:tribeHasMadeDiscovery(researchTypeIndex)
	local discoveries = serverClientState.privateShared.discoveries
	return discoveries[researchTypeIndex] and discoveries[researchTypeIndex].complete
end

function world:discoveryInfoForResearchTypeIndex(researchTypeIndex)
	local discoveries = serverClientState.privateShared.discoveries
	return discoveries[researchTypeIndex]
end

function world:discoveryInfoForCraftable(discoveryCraftableTypeIndex)
	local craftableDiscoveries = serverClientState.privateShared.craftableDiscoveries
	return craftableDiscoveries[discoveryCraftableTypeIndex]
end

function world:tribeHasDiscoveredCraftable(constructableTypeIndex)
	local craftableDiscoveries = serverClientState.privateShared.craftableDiscoveries
	return craftableDiscoveries[constructableTypeIndex] and craftableDiscoveries[constructableTypeIndex].complete
end

function world:tribeHasSeenResourceObjectTypeIndex(objectTypeIndex)
	return serverClientState.privateShared.seenResourceObjectTypes[objectTypeIndex]
end

function world:getSeenResourceObjectTypes()
	return serverClientState.privateShared.seenResourceObjectTypes
end

function world:getTutorialServerClientState()
	return serverClientState.privateShared.tutorial
end

function world:getResourceBlockLists()
	local resourceBlockLists = serverClientState.privateShared.resourceBlockLists
	if not resourceBlockLists then
		resourceBlockLists = gameObject:getDefaultBlockLists(fuel)
		serverClientState.privateShared.resourceBlockLists = resourceBlockLists
	end
	return resourceBlockLists
end

function world:tribeHasSeenToolTypeIndex(toolTypeIndex)
	local toolObjectTypeIndexes = gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex]
	for j, objectTypeIndex in ipairs(toolObjectTypeIndexes) do
		if world:tribeHasSeenResourceObjectTypeIndex(objectTypeIndex) then
			return true
		end
	end
	return false
end

function world:getOrCreateTribeRelationsSettings(tribeID)
	local tribeRelationsSettings = serverClientState.privateShared.tribeRelationsSettings
	if not tribeRelationsSettings then
		tribeRelationsSettings = {}
		serverClientState.privateShared.tribeRelationsSettings = tribeRelationsSettings
	end
	if not tribeRelationsSettings[tribeID] then
		tribeRelationsSettings[tribeID] = {}
	end
	return tribeRelationsSettings[tribeID]
end

function world:getTerrainFillConstructableTypeIndex()
	return fillConstructableTypeIndex
end

function world:setTerrainFillConstructableTypeIndex(newFillTypeIndex)
	fillConstructableTypeIndex = newFillTypeIndex
	clientWorldSettingsDatabase:setDataForKey(newFillTypeIndex, "fillConstructableTypeIndex")
end

function world:setHasQueuedResearchPlan(hasQueuedResearchPlan_)
	hasQueuedResearchPlan = hasQueuedResearchPlan_
end

function world:getHasQueuedResearchPlan()
	return hasQueuedResearchPlan
end

function world:getHasLoadedCraftOrStorageArea()
	return hasLoadedCraftOrStorageArea
end

function world:setHasLoadedCraftOrStorageArea()
	hasLoadedCraftOrStorageArea = true
end

function world:getHasUsedTasksUI()
	return hasUsedTasksUI
end

function world:setHasUsedTasksUI()
	hasUsedTasksUI = true
end

function world:getClientWorldSetting(key)
	return clientWorldSettings[key]
end

function world:setClientWorldSetting(key, value)
	if clientWorldSettings[key] ~= value or type(value) == "table" then
		clientWorldSettings[key] = value
		clientWorldSettingsDatabase:setDataForKey(clientWorldSettings, "clientWorldSettings")
	end
end

function world:getConstructableRestrictedObjectTypes(constructableTypeIndex, isTool)
	if not constructableRestrictedObjectTypes[constructableTypeIndex] then
		return nil
	end
	
	local toolOrResourceTypeIndex = 1
	if isTool then
		toolOrResourceTypeIndex = 2
	end

	return constructableRestrictedObjectTypes[constructableTypeIndex][toolOrResourceTypeIndex]
end

function world:changeConstructableRestrictedObjectType(constructableTypeIndex, objectTypeIndex, isTool, newIsRestricted)
	local restrictedObjectTypesByResourceOrTool = constructableRestrictedObjectTypes[constructableTypeIndex]
	if not restrictedObjectTypesByResourceOrTool then
		if not newIsRestricted then
			return
		end
		restrictedObjectTypesByResourceOrTool = {}
		constructableRestrictedObjectTypes[constructableTypeIndex] = restrictedObjectTypesByResourceOrTool
	end

	local toolOrResourceTypeIndex = 1
	if isTool then
		toolOrResourceTypeIndex = 2
	end

	local restrictedObjectTypes = restrictedObjectTypesByResourceOrTool[toolOrResourceTypeIndex]
	if not restrictedObjectTypes then
		if not newIsRestricted then
			return
		end
		restrictedObjectTypes = {}
		restrictedObjectTypesByResourceOrTool[toolOrResourceTypeIndex] = restrictedObjectTypes
	end

	if newIsRestricted then
		restrictedObjectTypes[objectTypeIndex] = true
	else
		restrictedObjectTypes[objectTypeIndex] = nil
		if not next(restrictedObjectTypes) then
			restrictedObjectTypesByResourceOrTool[toolOrResourceTypeIndex] = nil
			local otherType = 2
			if isTool then 
				otherType = 1
			end
			if not restrictedObjectTypesByResourceOrTool[otherType] then
				constructableRestrictedObjectTypes[constructableTypeIndex] = nil
			end
		end
	end

	clientWorldSettingsDatabase:setDataForKey(constructableRestrictedObjectTypes, "constructableRestrictedObjectTypes")
end

function world:getWelcomeMessage()
	return serverClientState.welcomeMessage
end

function world:getWorldName()
	return bridge.worldName
end

function world:startServerProfile()
	logicInterface:callServerFunction("startProfile")
end

function world:toggleDebugAnchors()
	logicInterface:callServerFunction("toggleDebugAnchors")
end

function world:startLogicProfile()
	logicInterface:callLogicThreadFunction("startProfile")
end

function world:startMainThreadProfile()
	profiler:start(10.0)
end

function world:getClientWorldSettingsDatabase()
	return clientWorldSettingsDatabase
end

function world:logDebug()
	bridge:logDebug()
end

function world:getWorldSavePath(fileName)
	return bridge:getWorldSavePath(fileName)
end

function logDebug()
	world:logDebug()
end

function world:disconnectFromServer()
	bridge:disconnectFromServer()
end

local debugObjectIDs = {}

function world:setPathDebugConnections(debugConnections)

	for i,debugObjectID in ipairs(debugObjectIDs) do
		uiObjectManager:removeUIModel(debugObjectID)
	end
	debugObjectIDs = {}

	local modelIndex = model:modelIndexForName("debugSphere")
	local connectorModelIndex = model:modelIndexForName("debugConnector")

	local heightOffset = mj:mToP(0.2)

	if debugConnections then
		--mj:log("debugConnections:", debugConnections)
		if debugConnections.objectNodes then
			for i,nodePos in ipairs(debugConnections.objectNodes) do
				local buildObjectID = uiObjectManager:addUIModel(
					modelIndex,
					vec3(1.0,1.0,1.0),
					nodePos + normalize(nodePos) * heightOffset,
					mat3Identity,
					material.types.paleGreen.index
				)
				table.insert(debugObjectIDs, buildObjectID)
			end
		end
		if debugConnections.verts then
			for i,nodePos in ipairs(debugConnections.verts) do
				local buildObjectID = uiObjectManager:addUIModel(
					modelIndex,
					vec3(1.0,1.0,1.0),
					nodePos + normalize(nodePos) * heightOffset,
					mat3Identity,
					material.types.paleBlue.index
				)
				table.insert(debugObjectIDs, buildObjectID)
			end
		end
		if debugConnections.faces then
			for i,nodePos in ipairs(debugConnections.faces) do
				local buildObjectID = uiObjectManager:addUIModel(
					modelIndex,
					vec3(1.0,1.0,1.0),
					nodePos + normalize(nodePos) * heightOffset,
					mat3Identity,
					material.types.paleBlue.index
				)
				table.insert(debugObjectIDs, buildObjectID)
			end
		end
		if debugConnections.objects then
			for i,nodeInfo in ipairs(debugConnections.objects) do
				local nodePos = nodeInfo.pos
				local closeToGround = nodeInfo.closeToGround
				local materialIndex = material.types.paleMagenta.index
				if closeToGround then
					materialIndex = material.types.charcoal.index
				end

				local buildObjectID = uiObjectManager:addUIModel(
					modelIndex,
					vec3(1.0,1.0,1.0),
					nodePos + normalize(nodePos) * heightOffset,
					mat3Identity,
					materialIndex
				)
				table.insert(debugObjectIDs, buildObjectID)
			end
		end

		if debugConnections.connections then
			for i,connectionInfo in ipairs(debugConnections.connections) do
				local midPoint = (connectionInfo[1] + connectionInfo[2]) * 0.5
				local distanceVec = connectionInfo[2] - connectionInfo[1]
				local distance = mjm.length(distanceVec)
				local rotation = mjm.mat3LookAtInverse(distanceVec / distance,normalize(midPoint))
				local buildObjectID = uiObjectManager:addUIModel(
					connectorModelIndex,
					vec3(1.0,1.0,mj:pToM(distance)),
					midPoint + normalize(midPoint) * heightOffset,
					rotation,
					material.types.paleGrey.index
				)
				table.insert(debugObjectIDs, buildObjectID)
			end
		end
	end
end


function world:setPathDebugPath(pathInfo)
	mj:log("world:setPathDebugPath:", pathInfo)
	
	for i,debugObjectID in ipairs(debugObjectIDs) do
		uiObjectManager:removeUIModel(debugObjectID)
	end
	debugObjectIDs = {}
	

	local modelIndex = model:modelIndexForName("debugSphere")
	local connectorModelIndex = model:modelIndexForName("debugConnector")

	local heightOffset = mj:mToP(0.2)

	if pathInfo and pathInfo.nodes then
		local prevNodePos = nil
		for i,nodeInfo in ipairs(pathInfo.nodes) do
			local thisPos = nodeInfo.pos
			local buildObjectID = uiObjectManager:addUIModel(
				modelIndex,
				vec3(1.0,1.0,1.0),
				thisPos + normalize(thisPos) * heightOffset,
				mat3Identity,
				material.types.paleBlue.index
			)
			mj:log("add node")
			table.insert(debugObjectIDs, buildObjectID)

			if prevNodePos then
				local midPoint = (prevNodePos + thisPos) * 0.5
				local distanceVec = thisPos - prevNodePos
				local distance = mjm.length(distanceVec)
				local rotation = mjm.mat3LookAtInverse(distanceVec / distance,normalize(midPoint))
				local connectionBuildObjectID = uiObjectManager:addUIModel(
					connectorModelIndex,
					vec3(1.0,1.0,mj:pToM(distance)),
					midPoint + normalize(midPoint) * heightOffset,
					rotation,
					material.types.paleGrey.index
				)
				table.insert(debugObjectIDs, connectionBuildObjectID)
			end

			prevNodePos = thisPos
		end
	end

end

return world