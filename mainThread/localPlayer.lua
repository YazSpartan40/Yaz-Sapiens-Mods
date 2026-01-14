

--local bit = mjrequire("bit")
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local mat3 = mjm.mat3
local normalize = mjm.normalize
local cross = mjm.cross
local dot = mjm.dot
local length = mjm.length
local length2 = mjm.length2
local mat3LookAtInverse = mjm.mat3LookAtInverse
local mat3Rotate = mjm.mat3Rotate
local mat3GetRow = mjm.mat3GetRow
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Slerp = mjm.mat3Slerp
local mix = mjm.mix
local length2D = mjm.length2D
local approxEqual = mjm.approxEqual
--local dot = mjm.dot

local mapModes = mjrequire "common/mapModes"
local physicsSets = mjrequire "common/physicsSets"
local gameObject = mjrequire "common/gameObject"
local gameConstants = mjrequire "common/gameConstants"
--local order = mjrequire "common/order"

local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
local logicInterface = mjrequire "mainThread/logicInterface"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local playerSapiens = mjrequire "mainThread/playerSapiens"
local tribeSelectionUI = mjrequire "mainThread/ui/tribeSelectionUI"
local mapModeUI = mjrequire "mainThread/ui/mapModeUI"
local audio = mjrequire "mainThread/audio"
local cinematicCamera = mjrequire "mainThread/cinematicCamera"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"

local buildModeInteractUI = mjrequire "mainThread/ui/buildModeInteractUI"
local sapienMoveUI = mjrequire "mainThread/ui/sapienMoveUI"
local objectMoveUI = mjrequire "mainThread/ui/objectMoveUI"
local warningNoticeUI = mjrequire "mainThread/ui/warningNoticeUI"
local storageLogisticsDestinationsUI = mjrequire "mainThread/ui/storageLogisticsDestinationsUI"
local changeAssignedSapienUI = mjrequire "mainThread/ui/changeAssignedSapienUI"
local interestMarkersUI = mjrequire "mainThread/ui/interestMarkersUI"

local pointAndClickCamera = mjrequire "mainThread/pointAndClickCamera"

local baseMovementSpeedHorizontal = 0.000015

local cinematicMapModeCameraRotationTimer = nil
local zoomGoalInfo = nil
--local mouseWheelGoalPos = nil
--local mouseWheelGoalTargetObjectPos = nil
--local mouseWheelGoalTargetObjectScreenOffset = nil
local cinematicTribeSelectionTransitionTimer = nil
local cinematicTribeSelectionTransitionTimerDuration = 10.0


local hasZoomedWithTribeSlectionUIVisible = false
local tribeSlectionUIVisible = false

local lastForwardKeyDownTimer = nil
local isDoubleTapForward = false
local isNearSapienDistanceBoundary = false

local rayCastDistance = mj:mToP(200.0)
--local maxLookAtTerrainCrowFliesDistance2 = mj:mToP(50.0) * mj:mToP(50.0)
local maxLookAtTerrainCrowFliesDistance2 = mj:mToP(180.0) * mj:mToP(180.0)

local controllerZoomValue = nil
local controllerIsZooming = false

local objectInfluencedHeightAboveTerrain = 0.0

local mouseWheelZoomSensitivitySetting = 1.0

local function getInterpolatedCamera(posA, posB, rotA, rotB, fractionToUse)
    local result = {}

	local aAltitude = length(posA)
	local cAltitude = length(posB)
	local posANormal = posA / aAltitude
	local posBNormal = posB / cAltitude

	local altitudeDistance = length(posANormal - posBNormal)
	local simpleDistance = length(posA - posB)

	local altitudeMid = aAltitude + (cAltitude - aAltitude) * 0.5 + altitudeDistance * 0.5

	local ab = mix(aAltitude, altitudeMid, fractionToUse)
	local bc = mix(altitudeMid, cAltitude, fractionToUse)

	local altitudeToUse = mix(ab, bc, fractionToUse)

	local surfaceMidPoint = normalize(posANormal + (posBNormal - posANormal) * 0.5)
	local midPointDirection = mat3GetRow(rotA,2)
	local midPointRight = -normalize(cross(surfaceMidPoint, midPointDirection))
	
	local midOffsetPoint = posA + ((midPointDirection + midPointRight * 1.0) * (simpleDistance * 0.6 + mj:mToP(50.0)))
	
	local pab = mix(posA, midOffsetPoint, fractionToUse)
	local pbc = mix(midOffsetPoint, posB, fractionToUse)

	local pToUse = mix(pab, pbc, fractionToUse)


   -- local altitudeToUse = mix(aAltitude, mix(altitudeMid,cAltitude, bcFraction), abFraction)

    result.pos = normalize(pToUse) * altitudeToUse
	--mj:log("d:", mj:pToM(length(bridge.pos) - 1.0), " normalModePos:", normalModePos, " mapModePos:", mapModePos, " mapModeInterpolationFraction:", mapModeInterpolationFraction)
	--bridge.rotationMatrix = mapModeRotation--mjm.mat3Slerp(normalModeRotation, mapModeRotation, mapModeInterpolationFraction)
	local upVector = normalize(mix(posANormal, mat3GetRow(rotB,1) , fractionToUse))
	local lookPosEnd = (posA + midPointDirection * mj:mToP(-50.0))
	local lookPosStart = posBNormal
	local lookPos = mix(lookPosEnd, lookPosStart, fractionToUse)

	result.rotation = mat3LookAtInverse(normalize(result.pos - lookPos), upVector)

    return result
end

local initialSetupComplete = false
local controllerInputDipInitialPos = nil
local controllerInputDipMinMagnitude = nil
local controllerInputReset = false

local renderDebugPhysicsLookAtObject = false --takes extra CPU, and requires debug option is turned on in settings too.

local world = nil
local gameUI = nil

local normalModeHeightAtPlayerPos = 0.0
local mapModeHeightAtPlayerPos = 0.0

local playerHeightMeters = 1.5
local defaultPlayerHeight = mj:mToP(playerHeightMeters)
local minPlayerHeightSlow = mj:mToP(0.2)
local onGroundPlayerHeight = defaultPlayerHeight
local desiredOnGroundPlayerHeight = onGroundPlayerHeight
local zoomWheelSpeed = mj:mToP(1.0)

local flyingPlayerDesiredHeight = 0.0
local flyingPlayerHeight = 0.0
local speedInfluencingSmoothedHeight = 0.0
local rayTestedGroundHeightIncludingWalkableObjects = nil

local mapModeBaseDesiredHeight = nil
local mapModeBaseHeight = nil

local mapModeZoomBetweenLevelsSpeed = 4.0


local lockCameraMode = false
local lockCameraLookAtPos = nil

local hasZoomedMap = false
local hasMovedMap = false

local hasZoomedNormal = false
local hasMovedNormal = false

--local foundMainThreadPlayerPositionTerrain = false

local mapModeInterpolationFraction = 0.0
local mapModeScrollWheelEventDelay = 0.0

local hasSetPlayerPosOnWorldLoad = false

local cinematicMapModeCameraZoomGoalLevel = nil


local yawPitchAcceleration = vec2(0.0,0.0)
local yawPitchVelocity = vec2(0.0,0.0)
local predictedTargetYawPitch = vec2(0.0,0.0)
local mostRecentMouseOffset = vec2(0.0,0.0)

local localPlayer = {
    lookAtID = nil,
    lookAtIsUI = false,
    lookAtMeshType = MeshTypeUndefined,
    lookAtPosition = vec3(0.0,0.0,0.0),
    lookAtPositionMainThread = vec3(0.0,0.0,0.0),
    retrievedLookAtObject = nil,

    mapMovementSpeedHorizontal = 20.0,
}

local minPlayerHeightMap = mj:mToP(400.0)
local maxPlayerHeightMap = mj:mToP(8000000.0)
local mapModeHeights = {
    [mapModes.global] = maxPlayerHeightMap,
    [mapModes.continental] = mj:mToP(1500000.0), --2
    [mapModes.national] = mj:mToP(150000.0), --3
    [mapModes.regional] = mj:mToP(40000.0), --4
    [mapModes.localized] = mj:mToP(5000.0), --5
    [mapModes.close] = mj:mToP(1500.0),
    [mapModes.closest] = minPlayerHeightMap,
}

--mj:log("mapModes.continental:", mapModes.continental)
--mj:log("mapModes.national:", mapModes.national)
--mj:log("mapModes.regional:", mapModes.regional)

local bridge = nil


local MOUSE_MOVE_MULTIPLIER_BASE = 0.001
local mouseSensitivityMultiplier = MOUSE_MOVE_MULTIPLIER_BASE
local controllerLookSensitivityMultiplier = MOUSE_MOVE_MULTIPLIER_BASE
local controllerZoomSensitivityMultiplier = 1.0

local invertMouseWheelZoom = false
local invertControllerLookY = false
local enableDoubleTapForFastMovement = false


local function getMapModePlayerHeight()
    if world and world.isVR then
        return mapModeBaseHeight * 2.0
    else
        return mapModeBaseHeight
    end
end

local function getMapMovementSpeed()
    return (mapModeBaseHeight - mapModeHeightAtPlayerPos) * localPlayer.mapMovementSpeedHorizontal
end


logPlayer = function()
    mj:log("player pos:" .. mj:tostring(bridge.pos) .. " altitude:" .. mj:tostring(mj:pToM(length(bridge.pos) - 1.0)))
end

local movementState = nil
--local mouseHidden = false

local preventGroundSnappingDueToSlow = false


local function resetMovementState()
    movementState = {
        forward = false,
        back = false,
        left = false,
        right = false,
        slow = false,
        fast = false,
    
        controllerMovement = vec2(0.0,0.0),
        controllerLookX = 0,
        controllerLookY = 0,
        controllerLeftTrigger = 0,
        controllerRightTrigger = 0,
    }
end
resetMovementState()

local mouseDown = false

local mapModePos = nil
local mapModeRotation = nil
local mapModeVel = vec3(0.0,0.0,0.0)
local mapModeHeightAboveTerrain = 0.0
local mapModeHeightAboveTerrainForTerrainDetailInfo = 0.0
--local mapZoomOffsetStartPos = nil
--local mapZoomUpVector = nil

local normalModePos = nil
local normalModeRotation = nil
local normalModeVel = vec3(0.0,0.0,0.0)
local normalModeHeightAboveTerrain = 0.0
local prevNormalModeHeightAtPlayerPos = nil

local followCamObjectOrVertID = nil
local followCamObjectIsTerrain = false
local followCamObjectLookAtPos = nil
local followCamObjectLookAtPosSmoothed = nil
--local followCamObjectLookPredictiveOffset = nil
local lastFollowCamObjectLookAtPos = nil
local followCamPositionOffsetDistance = nil
local followCamOffsetDistanceAndHeight = nil

local followTeleportDistance = mj:mToP(50.0)

local function canEscapeMapMode()
    return playerSapiens:hasFollowers()
end

function localPlayer:getIsFollowCamMode()
    return (followCamObjectOrVertID ~= nil)
end

local maxPlayerHeight = nil
local speedIncreaseFactorAtMaxHeight = nil

function localPlayer:setMaxPlayerHeight(maxPlayerHeight_)
    maxPlayerHeight = maxPlayerHeight_
end
function localPlayer:setSpeedIncreaseFactorAtMaxHeight(speedIncreaseFactorAtMaxHeight_)
    speedIncreaseFactorAtMaxHeight = speedIncreaseFactorAtMaxHeight_
end

localPlayer:setMaxPlayerHeight(mj:mToP(gameConstants.maxPlayerFlyHeightMeters))
localPlayer:setSpeedIncreaseFactorAtMaxHeight(gameConstants.speedIncreaseFactorAtMaxHeight)



local function notifyOfMapModeDetailChange()
    if world then
        world:setMapMode(localPlayer.mapMode)
    end
    interestMarkersUI:mapModeChanged(localPlayer.mapMode)
end


function localPlayer:setMapMode(newMapModeOrNil, shouldSnap)
    --mj:log("localPlayer:setMapMode:", newMapModeOrNil)
    if newMapModeOrNil == 0 then
        mj:error("newMapModeOrNil == 0")
        newMapModeOrNil = nil
    end
    --mj:log("localPlayer:setMapMode:", newMapModeOrNil, " shouldSnap:", shouldSnap)
    --mj:log(debug.traceback())
    local isTransitionBetweenMapLevels = (localPlayer.mapMode and newMapModeOrNil)
    if newMapModeOrNil ~= localPlayer.mapMode then
        if newMapModeOrNil or canEscapeMapMode() then
            if not isTransitionBetweenMapLevels then
                normalModeVel = vec3(0.0,0.0,0.0)
                mapModeVel = vec3(0.0,0.0,0.0)
                if not mapModeBaseDesiredHeight then
                    if playerSapiens:hasFollowers() then
                        mapModeBaseDesiredHeight = minPlayerHeightMap
                    else
                        mapModeBaseDesiredHeight = mj:mToP(20000.0)
                    end
                    mapModeBaseHeight = mapModeBaseDesiredHeight
                else
                    mapModeBaseDesiredHeight = minPlayerHeightMap
                    mapModeBaseHeight = mapModeBaseDesiredHeight
                end
                
            end
            localPlayer.mapMode = newMapModeOrNil
            --[[if localPlayer.mapMode and world then
                local newHeight = getMapModePlayerHeight()
                mapModeHeightAboveTerrain = newHeight - mapModeHeightAtPlayerPos
                logicInterface:callLogicThreadFunction("setPlayerInfoForTerrain", {playerPos = mapModePos, playerHeightAboveTerrain = mapModeHeightAboveTerrain})
            end]]
            notifyOfMapModeDetailChange()

            if newMapModeOrNil then
                
                if not isTransitionBetweenMapLevels then
                    mouseDown = false
                    mapModePos = normalize(normalModePos) * (1.0 + getMapModePlayerHeight())
                    zoomGoalInfo = nil
                   -- mj:log("not transition:", normalize(normalModePos))
                   --[[ mj:log("setting map mode pos. altitude:", mj:pToM(getMapModePlayerHeight()))
                    mj:log("mapModeBaseDesiredHeight:", mj:pToM(mapModeBaseDesiredHeight))
                    mj:log("mapModeBaseHeight:", mj:pToM(mapModeBaseHeight))]]
                end
        
                local playerPosNormal = normalize(mapModePos)
                local right = normalize(cross(playerPosNormal, vec3(0.0,-1.0,0.0)))
                local upVec = cross(playerPosNormal, right)
        
                mapModeRotation = mat3(
                    right.x,right.y,right.z,
                    upVec.x, upVec.y, upVec.z,
                    playerPosNormal.x,playerPosNormal.y,playerPosNormal.z
                )

                if shouldSnap then
                    bridge.rotationMatrix = mapModeRotation
                    
                    mapModeBaseDesiredHeight = mapModeHeights[localPlayer.mapMode]
                    mapModeBaseDesiredHeight = mjm.clamp(mapModeBaseDesiredHeight, mapModeBaseDesiredHeight + mapModeHeightAtPlayerPos, maxPlayerHeightMap)
                    mapModeBaseHeight = mapModeBaseDesiredHeight
                    mapModePos = playerPosNormal * (1.0 + mapModeBaseHeight)
                    --mj:log("mapModePos b:", normalize(mapModePos))

                    if world then
                        logicInterface:callLogicThreadFunction("updatePlayerPos", {
                            playerPos = normalModePos,
                            playerDir = mat3GetRow(normalModeRotation, 2),
                            mapPos = mapModePos,
                            mapMode = localPlayer.mapMode,
                        })
                    end
                    mapModeInterpolationFraction = 1.1
                end
                mapModeUI:show()
            else

                if shouldSnap then
                    bridge.pos = normalModePos
                    bridge.rotationMatrix = normalModeRotation
                    mapModeInterpolationFraction = -0.1
                end
                mapModeUI:hide()
            end
            
            --mapZoomOffsetStartPos = mapModePos - mat3GetRow(mapModeRotation, 1) * getMapModePlayerHeight()
           -- mapZoomUpVector = normalize(mapModePos)

            if not isTransitionBetweenMapLevels then
                bridge:snapPos() --hmm not sure why this is here?
            end
        end
    end
end

local function toggleMapMode()
    tutorialUI:playerToggledMap()
    if localPlayer.mapMode then
        localPlayer:setMapMode(nil, false)
    else
        localPlayer:setMapMode(mapModes.closest, false)
    end
end

local function updateLookAtObjectUI()
    if localPlayer.retrievedLookAtObject then
        gameUI:updateLookAtObjectUI(localPlayer.retrievedLookAtObject, false)
    elseif localPlayer.retrievedLookAtTerrainVert or localPlayer.mainThreadLookAtTerrainVert then
        if localPlayer.retrievedLookAtTerrainVert and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert.uniqueID == localPlayer.mainThreadLookAtTerrainVert.uniqueID then
            gameUI:updateLookAtObjectUI(localPlayer.retrievedLookAtTerrainVert, true)
        elseif localPlayer.mainThreadLookAtTerrainVert then
            gameUI:updateLookAtObjectUI(localPlayer.mainThreadLookAtTerrainVert, true)
        else
            gameUI:updateLookAtObjectUI(nil, nil)
        end
    else
        gameUI:updateLookAtObjectUI(nil, nil)
    end
end


--gameUI:pointAndClickModeHasHiddenMouseForMoveControl

local function retrievedObjectOrTerrainCallback(retrievedObjectResponse, isTerrain)
    if isTerrain and retrievedObjectResponse then
        --mj:log("isTerrain retrievedObjectOrTerrainCallback:", retrievedObjectResponse)
        localPlayer.retrievedLookAtTerrainVert = retrievedObjectResponse
        localPlayer.retrievedLookAtObject = nil
    elseif (not isTerrain) and retrievedObjectResponse and retrievedObjectResponse.found and localPlayer.lookAtID == retrievedObjectResponse.uniqueID then
        --mj:log("localPlayer.lookAtID == retrievedObjectResponse.uniqueID retrievedObjectOrTerrainCallback:", retrievedObjectResponse)
        localPlayer.retrievedLookAtObject = retrievedObjectResponse
        localPlayer.retrievedLookAtTerrainVert = nil
    else
        --mj:log("set localPlayer.retrievedLookAtObject nil")
        localPlayer.retrievedLookAtObject = nil
        localPlayer.retrievedLookAtTerrainVert = nil
    end

    updateLookAtObjectUI()
end

local currentlyRegisteredForStateChangesObjectID = nil
local currentlyRegisteredForStateChangesVertID = nil

local function deregisterStateChanges()
    --mj:log("deregisterStateChanges:", currentlyRegisteredForStateChangesObjectID)
    if currentlyRegisteredForStateChangesObjectID then
        logicInterface:deregisterFunctionForObjectStateChanges({currentlyRegisteredForStateChangesObjectID}, logicInterface.stateChangeRegistrationGroups.playerLookAt)
        currentlyRegisteredForStateChangesObjectID = nil
    end
    if currentlyRegisteredForStateChangesVertID then
       -- mj:log("deregister:", currentlyRegisteredForStateChangesVertID)
        logicInterface:deregisterFunctionForVertStateChanges({currentlyRegisteredForStateChangesVertID}, logicInterface.stateChangeRegistrationGroups.playerLookAt)
        currentlyRegisteredForStateChangesVertID = nil
    end
end

local function registerStateChanges()
    if localPlayer.lookAtID and localPlayer.lookAtMeshType == MeshTypeGameObject then
        local idToRegister = localPlayer.lookAtID
       -- mj:log("idToRegister:", idToRegister, " currentlyRegisteredForStateChangesObjectID:", currentlyRegisteredForStateChangesObjectID)
        if currentlyRegisteredForStateChangesObjectID ~= idToRegister or currentlyRegisteredForStateChangesVertID then
            deregisterStateChanges()

            if currentlyRegisteredForStateChangesObjectID ~= idToRegister then
                if idToRegister then
                    -- mj:log("register object:", idToRegister)
                    logicInterface:registerFunctionForObjectStateChanges({idToRegister}, logicInterface.stateChangeRegistrationGroups.playerLookAt, function (retrievedObjectResponse)
                       -- mj:log("callback")
                        retrievedObjectOrTerrainCallback(retrievedObjectResponse, false)
                    end,
                    function(removedObjectID)
                        retrievedObjectOrTerrainCallback(nil, false)
                        if followCamObjectOrVertID == removedObjectID then
                            localPlayer:stopFollowingObject()
                        end
                        currentlyRegisteredForStateChangesObjectID = nil
                    end)
                end
        
                currentlyRegisteredForStateChangesObjectID = idToRegister
            end
            
        end
    else
        local terrainVert = localPlayer.retrievedLookAtTerrainVert or localPlayer.mainThreadLookAtTerrainVert
        if terrainVert then
            local idToRegister = terrainVert.uniqueID
            if currentlyRegisteredForStateChangesVertID ~= idToRegister or currentlyRegisteredForStateChangesObjectID then
                deregisterStateChanges()

                if currentlyRegisteredForStateChangesVertID ~= idToRegister then
                    if idToRegister then
                    -- mj:log("register:", idToRegister)
                        logicInterface:registerFunctionForVertStateChanges({idToRegister}, logicInterface.stateChangeRegistrationGroups.playerLookAt, function (retrievedVertResponse)
                            retrievedObjectOrTerrainCallback(retrievedVertResponse, true)
                        end)
                    end
            
                    currentlyRegisteredForStateChangesVertID = idToRegister
                end
                
            end
        end
    end
--logicInterface:registerFunctionForVertStateChanges
    --mj:log("registerStateChanges:", idToRegister)
end

local markerLookAtID = nil
local markerLookAtVertID = nil
local markerLookAtPos = nil

local cursorLookAtID = nil
local cursorLookAtTerrainVertID = nil
local cursorLookAtTerrainMinLevel = nil
local cursorLookAtPos = nil
local cursorMeshType = nil

local function retrieveLatestInfoForLookAt()
    --mj:log("retrieveLatestInfoForLookAt:", localPlayer.lookAtID)
    if localPlayer.lookAtID and localPlayer.lookAtMeshType == MeshTypeGameObject then
        localPlayer.mainThreadLookAtTerrainVert = nil
        logicInterface:callLogicThreadFunction("retrieveObject", localPlayer.lookAtID, function(retrievedObjectResponse) retrievedObjectOrTerrainCallback(retrievedObjectResponse, false) end)
        logicInterface:callLogicThreadFunction("setLookAtObjectID", localPlayer.lookAtID)
        registerStateChanges()
    elseif localPlayer.lookAtID and ((localPlayer.lookAtIsUI and markerLookAtVertID) or cursorLookAtTerrainMinLevel >= mj.SUBDIVISIONS - 1) then
        local vertIDToUse = markerLookAtVertID
        if not (localPlayer.lookAtIsUI and markerLookAtVertID) then
            vertIDToUse = cursorLookAtTerrainVertID
        end
        localPlayer.mainThreadLookAtTerrainVert = {uniqueID = vertIDToUse}
        localPlayer.retrievedLookAtObject = nil
        logicInterface:callLogicThreadFunction("retrieveTerrainVertInfo", vertIDToUse, function(retrievedObjectResponse) retrievedObjectOrTerrainCallback(retrievedObjectResponse, true) end)
        logicInterface:callLogicThreadFunction("setLookAtObjectID", nil)
        registerStateChanges()
    else
        localPlayer.mainThreadLookAtTerrainVert = nil
        retrievedObjectOrTerrainCallback(nil)
        logicInterface:callLogicThreadFunction("setLookAtObjectID", nil)
    end
end

local function updateLookAtObject()

    if gameUI:pointAndClickModeHasHiddenMouseForMoveControl() then 
        return
    end

    --mj:debug("updateLookAtObject")

    if followCamObjectOrVertID then
        localPlayer.lookAtIsUI = false
        localPlayer.lookAtID = followCamObjectOrVertID
        if followCamObjectIsTerrain then
            localPlayer.lookAtMeshType = MeshTypeTerrain --todo
        else
            localPlayer.lookAtMeshType = MeshTypeGameObject --todo
        end
        registerStateChanges()
        logicInterface:callLogicThreadFunction("setLookAtObjectID", nil)
        return
    end
    local closestID = markerLookAtID
    local closestPos = markerLookAtPos
    local closestMeshtype = MeshTypeGameObject
    local lookAtIsUI = true

    if markerLookAtID and markerLookAtVertID then
        closestID = markerLookAtVertID
        closestMeshtype = MeshTypeTerrain
    end

    local transparentMarkers = false
    local markerIsCloserOrTransparent = false
    
    if (markerLookAtID ~= nil) then
        --mj:log("markerLookAtID ~= nil")
        if transparentMarkers or (not cursorLookAtID)then
            --mj:log("transparentMarkers or (not cursorLookAtID)")
            markerIsCloserOrTransparent = true
        else
            local markerDistance2 = length2(markerLookAtPos - normalModePos) --todo map mode
            local cusorDistance2 = length2(cursorLookAtPos - normalModePos)
           -- mj:log("markerDistance:", mj:pToM(math.sqrt(markerDistance2)), " cusorDistance:", mj:pToM(math.sqrt(cusorDistance2)))
            if cusorDistance2 > markerDistance2 then
                markerIsCloserOrTransparent = true
            end
        end
    end
    
    if cursorLookAtID and not markerIsCloserOrTransparent then
        closestID = cursorLookAtID
        closestPos = cursorLookAtPos
        closestMeshtype = cursorMeshType
        lookAtIsUI = false
    end

    if closestPos then
        localPlayer.lookAtPosition = closestPos
    end
    
    if closestID ~= localPlayer.lookAtID or closestMeshtype ~= localPlayer.lookAtMeshType or localPlayer.lookAtIsUI ~= lookAtIsUI then
        --mj:log("closestID:", closestID, " markerLookAtID:", markerLookAtID, " cursorLookAtID:", cursorLookAtID)
        if closestID then
            localPlayer.lookAtIsUI = lookAtIsUI
            localPlayer.lookAtID = closestID
            localPlayer.lookAtMeshType = closestMeshtype
            registerStateChanges()
        else
            --mj:log("updateLookAtObject NIL")
            localPlayer.lookAtID = nil
            deregisterStateChanges()
        end
        
        retrieveLatestInfoForLookAt()
    elseif closestMeshtype == MeshTypeTerrain then
        retrieveLatestInfoForLookAt()
    end
end

function localPlayer:markerLookAtStarted(uniqueID, lookAtPosition, vertID)
   --mj:log("localPlayer:markerLookAtStarted:",uniqueID, " vertID:",vertID )
    markerLookAtID = uniqueID
    markerLookAtVertID = vertID
    markerLookAtPos = lookAtPosition
    updateLookAtObject()
end

function localPlayer:markerLookAtEnded(uniqueID)
    --mj:log("localPlayer:markerLookAtEnded:",uniqueID )
    if markerLookAtID == uniqueID then
        markerLookAtID = nil
        markerLookAtPos = nil
        markerLookAtVertID = nil
        updateLookAtObject()
    end
end

function localPlayer:markerClick(uniqueID, buttonIndex)
    --[[if markerLookAtID == uniqueID then
        gameUI:interact(uniqueID)
    end]]
    if localPlayer.lookAtID then
        if buttonIndex == 0 then
           --[[ if localPlayer.retrievedLookAtObject then
                gameUI:selectMulti(localPlayer.retrievedLookAtObject)
            end]]
       --else
            gameUI:interact(localPlayer.lookAtID, true)
        elseif buttonIndex == 1 then
            gameUI:rightClick()
        end
    end
end

function localPlayer:getLookAtPoint()
    if markerLookAtPos then
        return markerLookAtPos
    end
    if cursorLookAtID then
        return cursorLookAtPos
    end
    return nil
end


function localPlayer:calculatePointAndClickRotationCenter()
    local rayTestStartPos = world:getPointerRayStart()
    --mj:log("localPlayer:calculatePointAndClickRotationCenter rayTestStartPos:", rayTestStartPos)
    local screenRayDirection = -mat3GetRow(normalModeRotation, 2)
    local rayTestEndPos = rayTestStartPos + screenRayDirection * math.min(mj:mToP(1000.0), normalModeHeightAboveTerrain * 2.0 + mj:mToP(2.0))

    local collideWithSeaLevel = true
    local physicsSet = physicsSets.walkable

    local rayResult = world:rayTest(rayTestStartPos, rayTestEndPos, "lookAt", physicsSet, collideWithSeaLevel)

    if rayResult.hasHitObject then
        return rayResult.objectCollisionPoint
    elseif rayResult.hasHitTerrain then
        return rayResult.terrainCollisionPoint
    end
    
    --mj:log("localPlayer:calculatePointAndClickRotationCenter rayTestEndPos:", rayTestEndPos, "distance:", mj:pToM(length(rayTestEndPos - rayTestStartPos)))
    return rayTestEndPos
end

function localPlayer:getNormalModePos()
    return normalModePos
end

function localPlayer:getNormalModeRotation()
    return normalModeRotation
end

local function teleport(posToTeleportTo, setToNorth)
    local offsetTeleportPoint = posToTeleportTo - (world:getHeadOffset())

    
    local posHeight = length(posToTeleportTo)
    local normalized = normalize(offsetTeleportPoint)
    local height = posHeight + onGroundPlayerHeight
    offsetTeleportPoint = normalized * height

    normalModePos = offsetTeleportPoint
    audio:setPlayerPos(normalModePos)
    normalModeVel = vec3(0.0,0.0,0.0)
    normalModeHeightAboveTerrain = onGroundPlayerHeight --todo this only works if the teportation point is on the ground. Need to figure out what to do if it's on some other walkable surface
    normalModeHeightAtPlayerPos = math.max(length(posToTeleportTo) - 1.0, 0.0)
    prevNormalModeHeightAtPlayerPos = nil

    if setToNorth then
        local up = normalize(normalModePos)
        local right = -cross(up, vec3(0.0,1.0,0.0))
        local newDirection = cross(up, right)
        normalModeRotation = mat3LookAtInverse(-newDirection, up)
    end
end

function localPlayer:teleportToPos(posToTeleportTo, setToNorth)
    teleport(posToTeleportTo, setToNorth)
end

function localPlayer:teleportToLookAtPos(pos)
    local tpDistance = mj:mToP(2.0)
    local posToTeleportTo = pos + mat3GetRow(normalModeRotation, 2) * tpDistance

    teleport(posToTeleportTo, false)
end

function localPlayer:teleportToObject(uniqueID, pos)
    localPlayer:teleportToLookAtPos(pos)
end


function localPlayer:isFollowingObject()
    return (followCamObjectOrVertID ~= nil)
end

function localPlayer:getFollowingObjectID()
    return followCamObjectOrVertID
end

function localPlayer:isMovingDueToControls()
    return movementState.forward or movementState.back or movementState.left or movementState.right or 
    (movementState.controllerMovement and not approxEqual(movementState.controllerMovement.x, 0.0) and not approxEqual(movementState.controllerMovement.y, 0.0))
end

local followCamDesiredOffsetRotation = nil
local followCamStopWhenClose = false

function localPlayer:followObject(objectInfo, isTerrain, pos, maintainDirection, stopWhenClose)
    if not pos then
        mj:warn("localPlayer:followObject no pos. objectInfo:", objectInfo)
        return
    end
    --mj:log("localPlayer:followObject:", objectInfo)
    followCamStopWhenClose = stopWhenClose
    if followCamObjectOrVertID ~= objectInfo.uniqueID then
        --mj:log("localPlayer:followObject:", pos)
        local normalizedObjectPos = normalize(pos)
        followCamObjectOrVertID = objectInfo.uniqueID
        followCamObjectIsTerrain = isTerrain

        followCamOffsetDistanceAndHeight = mj:mToP(vec2(6.0,0.0))
        if not isTerrain and objectInfo.objectTypeIndex then
            local gameObjectType = gameObject.types[objectInfo.objectTypeIndex]
            if gameObjectType.followCamOffsetFunction then
                followCamOffsetDistanceAndHeight = mj:mToP(gameObjectType.followCamOffsetFunction(objectInfo))
            end
        end

        followCamObjectLookAtPos = pos + normalizedObjectPos * followCamOffsetDistanceAndHeight.y
        lastFollowCamObjectLookAtPos = followCamObjectLookAtPos
        followCamObjectLookAtPosSmoothed = followCamObjectLookAtPos
        followCamPositionOffsetDistance = vec3(0.0,0.0,0.0)
        if maintainDirection then
            followCamDesiredOffsetRotation = normalModeRotation
        else
            followCamDesiredOffsetRotation = nil
        end
        --followCamObjectLookPredictiveOffset = vec3(0.0,0.0,0.0)
        flyingPlayerDesiredHeight = 0.0

        local followMinDistance = followCamOffsetDistanceAndHeight.x

        local normalizedNormalModePos = normalize(normalModePos)
        local directionVec = normalizedObjectPos - normalizedNormalModePos
        local playerDistance = length(directionVec)
        if playerDistance > followMinDistance then
            local positionDirectionNormal = directionVec / playerDistance


            local posHeight = length(pos)
            
            local teleportPos = normalizedObjectPos - positionDirectionNormal * followMinDistance
            local teleportPosNormal = normalize(teleportPos)
            local offsetPoint = teleportPosNormal * posHeight
            
            if followCamDesiredOffsetRotation then
                local up = normalizedNormalModePos
                local right = mat3GetRow(followCamDesiredOffsetRotation, 0)
                local lookDirectionNormal = normalize(cross(up, right))
                local offsetPos = normalizedObjectPos - lookDirectionNormal * followMinDistance
                local offsetPosNormal = normalize(offsetPos)
                offsetPoint = offsetPosNormal * posHeight
            end

            if playerDistance > followTeleportDistance then
                local offsetPointNormal = normalize(normalizedObjectPos - positionDirectionNormal * followTeleportDistance)
                logicInterface:callLogicThreadFunction("getHighestDetailTerrainPointAtPoint", offsetPointNormal, function(terrainPoint)
                    localPlayer:teleportToPos(terrainPoint, false)
                    followCamPositionOffsetDistance = followCamPositionOffsetDistance + (offsetPoint - normalModePos)
                end) 
            else
                followCamPositionOffsetDistance = followCamPositionOffsetDistance + (offsetPoint - normalModePos)
            end
        end
        
        logicInterface:callLogicThreadFunction("setLookAtObjectID", nil)
        gameUI:updateUIHidden()
    end

end

function localPlayer:stopFollowingObject()
    if followCamObjectOrVertID then
        followCamObjectOrVertID = nil
        followCamObjectLookAtPos = nil
        lastFollowCamObjectLookAtPos = nil

        local normalizedPos = normalize(normalModePos)
        local zBase = -normalize(cross(normalizedPos, mat3GetRow(normalModeRotation, 0)))
        local dp = mjm.dot(zBase, mat3GetRow(normalModeRotation, 2))
        predictedTargetYawPitch.y = math.acos(dp)
        if mjm.dot(normalizedPos, mat3GetRow(normalModeRotation, 2)) < 0.0 then
            predictedTargetYawPitch.y = -predictedTargetYawPitch.y
        end

        if predictedTargetYawPitch.y > math.pi * 0.49 then
            predictedTargetYawPitch.y = math.pi * 0.49
        elseif predictedTargetYawPitch.y < -math.pi * 0.49 then
            predictedTargetYawPitch.y = -math.pi * 0.49
        end


        mostRecentMouseOffset = vec2(0.0,0.0)

        gameUI:updateUIHidden()
    end
end

function localPlayer:lookAt(pos)
    local newDirection = normalize(pos - normalModePos)
    normalModeRotation = mat3LookAtInverse(-newDirection, normalize(normalModePos))
end

local function getLatLong(rotationMatrix, sphereRadius2, rayOrigin, rayDir)

    local intersectionDistance = mjm.raySphereIntersectionDistance(rayOrigin, rayDir, vec3(0.0,0.0,0.0), sphereRadius2)
    if intersectionDistance then
        local worldPoint = rayOrigin + rayDir * intersectionDistance
        local localPoint = normalize(vec3xMat3(worldPoint, rotationMatrix))
        return vec2(-math.asin(localPoint.y), math.asin(localPoint.x))
    end
    return nil
end

local function updateGoalPosForWheelEvent(currentMapMode, newMapMode)
    
    local initialMatrix = mapModeRotation
    local sphereRadius2 = (1.0 + mapModeHeightAtPlayerPos) * (1.0 + mapModeHeightAtPlayerPos)

    local initialLatLong = getLatLong(initialMatrix, sphereRadius2, world:getPointerRayStart(), world:getPointerRayDirection())

    if not initialLatLong then
        return
    end

    
    local zoomEndHeight = mapModeHeights[newMapMode]
    zoomEndHeight = mjm.clamp(zoomEndHeight, minPlayerHeightMap + mapModeHeightAtPlayerPos, maxPlayerHeightMap)
    local newHeight = zoomEndHeight
    if world and world.isVR then
        newHeight = newHeight * 2.0
    end

    local finalMapModePos = normalize(mapModePos) * (1.0 + newHeight)

    local finalLatLong = getLatLong(initialMatrix, sphereRadius2, world:getPointerRayStartForPlayerAtPosition(finalMapModePos), world:getPointerRayDirection())
    if not finalLatLong then
        return
    end

    local difference = finalLatLong - initialLatLong

    local positionRotationMatrixX = mat3Rotate(mat3Identity, difference.x, mat3GetRow(initialMatrix, 0))
    local positionRotationMatrix = mat3Rotate(positionRotationMatrixX, difference.y, mat3GetRow(initialMatrix, 1))

    local goalPos = normalize(vec3xMat3(mapModePos, positionRotationMatrix))
    
    zoomGoalInfo = {
        startHeight = getMapModePlayerHeight(),
        endHeight = newHeight,
        startPos = mapModePos,
        goalPos = goalPos,
    }

    --getLatLong(rotationMatrix, sphereRadius2)
end

local prevScrollDirection = nil

local function doMouseWheelZoom(scrollChangeY, wasController)
    if not gameUI then
        return
    end
    if scrollChangeY == 0 then
        return
    end

    if localPlayer.mapMode then
        hasZoomedMap = true
    else
        hasZoomedNormal = true
    end
    
    if cinematicMapModeCameraZoomGoalLevel then
        return
    end
    
   --mj:log("mouseWheel:", scrollChangeY)
    -- if (not shiftDown) then
    local rateMultiplier = 1.0
    if movementState.fast or isDoubleTapForward then
        rateMultiplier = 4.0
    elseif movementState.slow then
        rateMultiplier = 0.05
    end
    local newScrollDirection = 1
    if scrollChangeY < 0 then
        newScrollDirection = -1
    end
    if localPlayer.mapMode then
        if mapModeScrollWheelEventDelay <= 0.0 or prevScrollDirection ~= newScrollDirection then
            mapModeScrollWheelEventDelay = 0.8
            prevScrollDirection = newScrollDirection
            if scrollChangeY < 0 then
                if localPlayer.mapMode > mapModes.global then
                    local newMapMode = localPlayer.mapMode - 1
                    --[[if not playerSapiens:hasFollowers() and newMapMode == mapModes.localized then
                        newMapMode = mapModes.regional
                    end]]

                    updateGoalPosForWheelEvent(localPlayer.mapMode, newMapMode)
                    localPlayer.mapMode = newMapMode
                    notifyOfMapModeDetailChange()
                    
                    if not playerSapiens:hasFollowers() then
                        if localPlayer.mapMode <= mapModes.regional then
                            tribeSelectionUI:hide(true)
                        end
                    end
                    if tribeSlectionUIVisible then
                        hasZoomedWithTribeSlectionUIVisible = true
                    end
                end
            else
                local closestZoom = mapModes.closest
                --[[if (not playerSapiens:hasFollowers()) and tribeSelectionUI:hidden() then
                    closestZoom = mapModes.localized
                end]]
                if localPlayer.mapMode < closestZoom then
                    updateGoalPosForWheelEvent(localPlayer.mapMode, localPlayer.mapMode + 1)
                    localPlayer.mapMode = localPlayer.mapMode + 1
                    notifyOfMapModeDetailChange()

                    if tribeSlectionUIVisible then
                        hasZoomedWithTribeSlectionUIVisible = true
                    end
                end
            end
        end
        --mapModeBaseDesiredHeight = mapModeBaseDesiredHeight - pos.y * rateMultiplier * zoomWheelSpeed * (0.5 + (mapModeBaseDesiredHeight / mj:mToP(1000000.0)) * 10000.0 * scrollWheelFactor)
    else
        if eventManager:mouseHidden() or (pointAndClickCamera.enabled and gameUI:shouldAllowPlayerMovement()) then
            if movementState.slow and flyingPlayerDesiredHeight <= 0.0 and scrollChangeY > 0 then
                desiredOnGroundPlayerHeight = desiredOnGroundPlayerHeight - scrollChangeY * rateMultiplier * zoomWheelSpeed
                desiredOnGroundPlayerHeight = mjm.max(desiredOnGroundPlayerHeight, minPlayerHeightSlow)
            elseif scrollChangeY < 0 and desiredOnGroundPlayerHeight < defaultPlayerHeight then
                desiredOnGroundPlayerHeight = desiredOnGroundPlayerHeight - scrollChangeY * rateMultiplier * zoomWheelSpeed
                desiredOnGroundPlayerHeight = mjm.min(desiredOnGroundPlayerHeight, defaultPlayerHeight)
            end
            local scrollChangeAmount = scrollChangeY * rateMultiplier * zoomWheelSpeed
            if (not movementState.slow) and (not wasController) and (not pointAndClickCamera.enabled) then
                if scrollChangeAmount > 0.0 then
                    scrollChangeAmount = math.max(scrollChangeAmount, mj:mToP(2.0))
                else
                    scrollChangeAmount = math.min(scrollChangeAmount, -mj:mToP(2.0))
                end
                preventGroundSnappingDueToSlow = false
            end
            flyingPlayerDesiredHeight = flyingPlayerDesiredHeight - scrollChangeAmount
            flyingPlayerDesiredHeight = mjm.clamp(flyingPlayerDesiredHeight, 0.0, maxPlayerHeight + objectInfluencedHeightAboveTerrain)
        end
    end
--end
end
--local shiftDown = false

function localPlayer:updateMovementState()
    movementState.forward = (movementState.forwardKey or pointAndClickCamera.forwardMovement or (pointAndClickCamera.panMouseDown and pointAndClickCamera.forwardBackMovementAnalog > 0.0)) 
    movementState.back = (movementState.backKey or pointAndClickCamera.backMovement or (pointAndClickCamera.panMouseDown and pointAndClickCamera.forwardBackMovementAnalog < 0.0))  
    movementState.left = (movementState.leftKey or pointAndClickCamera.leftMovement or (pointAndClickCamera.panMouseDown and pointAndClickCamera.leftRightMovementAnalog < 0.0))
    movementState.right = (movementState.rightKey or pointAndClickCamera.rightMovement or (pointAndClickCamera.panMouseDown and pointAndClickCamera.leftRightMovementAnalog > 0.0))  
end

local keyMap = {
	[keyMapping:getMappingIndex("movement", "forward")] = function(isDown, isRepeat)
        if isRepeat then
            return false
        end
        movementState.forwardKey = isDown
        localPlayer:updateMovementState()
        
        if isDown then
            localPlayer:stopFollowingObject()
        end

        if (not movementState.slow) and isDown and enableDoubleTapForFastMovement then
            if lastForwardKeyDownTimer then
                isDoubleTapForward = true
            else
                lastForwardKeyDownTimer = 0.0
            end
        else
            isDoubleTapForward = false
        end
        return true 
    end,
	[keyMapping:getMappingIndex("movement", "back")] = function(isDown, isRepeat) 
        if isRepeat then
            return false
        end
        movementState.backKey = isDown
        localPlayer:updateMovementState()
        if isDown then
            localPlayer:stopFollowingObject()
        end
        return true 
    end,
	[keyMapping:getMappingIndex("movement", "left")] = function(isDown, isRepeat) 
        if isRepeat then
            return false
        end
        movementState.leftKey = isDown 
        localPlayer:updateMovementState()
        if isDown then
            localPlayer:stopFollowingObject()
        end
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "right")] = function(isDown, isRepeat)
        if isRepeat then
            return false
        end
        movementState.rightKey = isDown 
        localPlayer:updateMovementState()
        if isDown then
            localPlayer:stopFollowingObject()
        end
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "zoomIn")] = function(isDown, isRepeat)
        if isDown then
            mj:log("zoomIn")
            doMouseWheelZoom(1.0, false)
        end
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "zoomOut")] = function(isDown, isRepeat)
        if isDown then
            mj:log("zoomOut")
            doMouseWheelZoom(-1.0, false)
        end
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "rotateLeft")] = function(isDown, isRepeat)
        local direction = 0
        if isDown then
            direction = -1
        end
        pointAndClickCamera:updateKeyRotation(direction)
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "rotateRight")] = function(isDown, isRepeat)
        local direction = 0
        if isDown then
            direction = 1
        end
        pointAndClickCamera:updateKeyRotation(direction)
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "rotateForward")] = function(isDown, isRepeat)
        local direction = 0
        if isDown then
            direction = -1
        end
        pointAndClickCamera:updateKeyForwardBackRotation(direction)
        return true 
    end,
    [keyMapping:getMappingIndex("movement", "rotateBack")] = function(isDown, isRepeat)
        local direction = 0
        if isDown then
            direction = 1
        end
        pointAndClickCamera:updateKeyForwardBackRotation(direction)
        return true 
    end,

    [keyMapping:getMappingIndex("movement", "slow")] = function(isDown, isRepeat) 
        if isRepeat then
            return false
        end
       -- mj:log("movementState.slow:", isDown)
        movementState.slow = isDown 
        if movementState.slow then
            movementState.fast = false
            isDoubleTapForward = false
            preventGroundSnappingDueToSlow = true
        end
        return false 
    end,

    [keyMapping:getMappingIndex("movement", "fast")] = function(isDown, isRepeat) 
        if isRepeat then
            return false
        end
        movementState.fast = isDown 
        return false 
    end,
    
    [keyMapping:getMappingIndex("debug", "lockCamera")] = function(isDown, isRepeat) 
        --[[if lockCameraMode and not isDown then 
            if not lockCameraLookAtPos then
                lockCameraLookAtPos = cursorLookAtPos
            end
            return true 
        end]]

        
        --[[local closestZoom = mapModes.regional --zoom in on p press
        if localPlayer.mapMode < closestZoom then
            updateGoalPosForWheelEvent(localPlayer.mapMode, closestZoom)
            localPlayer.mapMode = closestZoom
            notifyOfMapModeDetailChange()
        end]]

    end,
    
    [keyMapping:getMappingIndex("game", "toggleMap")] = function(isDown, isRepeat) 
        if isRepeat then
            return false
        end
        if not gameUI:hasUIPanelDisplayed() then
            if not isDown then 
                toggleMapMode()
                return true 
            end
        end
    end,
    
}
keyMap[keyMapping:getMappingIndex("movement", "forwardAlt")] = keyMap[keyMapping:getMappingIndex("movement", "forward")]
keyMap[keyMapping:getMappingIndex("movement", "backAlt")] = keyMap[keyMapping:getMappingIndex("movement", "back")]
keyMap[keyMapping:getMappingIndex("movement", "leftAlt")] = keyMap[keyMapping:getMappingIndex("movement", "left")]
keyMap[keyMapping:getMappingIndex("movement", "rightAlt")] = keyMap[keyMapping:getMappingIndex("movement", "right")]

local function keyChanged(isDown, mapIndexes, isRepeat)
    if not gameUI then
        return false
    end
    for i,mapIndex in ipairs(mapIndexes) do
        if keyMap[mapIndex]  then
            if keyMap[mapIndex](isDown, isRepeat) then
                return true
            end
        end
    end
    return false
end


local prevYaw = 0.0


local function mouseMoved(pos, relativeMovement, dt)
    if not gameUI then
        return false
    end
    gameUI:mouseMoved(pos, relativeMovement, dt)
    if pointAndClickCamera.enabled then
        if not buildModeInteractUI:shouldOwnMouseMoveControl() then
            pointAndClickCamera:mouseMoved(pos, relativeMovement, dt)
        end
    end

    if eventManager:mouseHidden() and (not world.isVR) then
        if not buildModeInteractUI:shouldOwnMouseMoveControl() then
            local xOffset = mouseSensitivityMultiplier * relativeMovement.x
            if clientGameSettings.values.invertMouseLookX then
                xOffset = -xOffset
            end
            mostRecentMouseOffset.x = xOffset
            local yOffset = mouseSensitivityMultiplier * relativeMovement.y
            if clientGameSettings.values.invertMouseLookY then
                yOffset = -yOffset
            end
            mostRecentMouseOffset.y = yOffset
            return true
        end
    end
    return false
end

function localPlayer:tribeSelectionUIBecameVisible()
    tribeSlectionUIVisible = true
end

function localPlayer:tribeSelectionUIWasHidden()
    tribeSlectionUIVisible = false
    if not hasZoomedWithTribeSlectionUIVisible then
        if (not localPlayer.mapMode) or (localPlayer.mapMode > mapModes.regional) then
            localPlayer:setMapMode(mapModes.regional, false)
        end
    end
end


local function mouseWheel(position, scrollChangeBase, modKey)
    if not gameUI then
        return false
    end
    local scrollChangeY = scrollChangeBase.y
    if invertMouseWheelZoom then
        scrollChangeY = -scrollChangeY
    end
    local multiplier = mouseWheelZoomSensitivitySetting
    if pointAndClickCamera.enabled then
        multiplier = multiplier * 2.0
    end
    doMouseWheelZoom(scrollChangeY * multiplier, false)
end

local mouseDownLatLong = nil
local mouseDownRotationMatrix
local mouseDownSphereRadius2 = nil

local mapZoomInSpeed = 0.3
local mapZoomInSpeedCinematic = 0.05
local mapZoomOutSpeed = 2.0



local function updateBridge(dt)
    

    if cinematicTribeSelectionTransitionTimer then
        cinematicTribeSelectionTransitionTimer = cinematicTribeSelectionTransitionTimer - dt
        if cinematicTribeSelectionTransitionTimer <= 0.0 then
            cinematicTribeSelectionTransitionTimer = nil
        end
    end

    if localPlayer.mapMode then
        --mj:log("mapMode setPlayerInfoForTerrain: playerPos:",mapModePos, " playerHeightAboveTerrain:", mapModeHeightAboveTerrain)
        bridge.approximateHeightAboveTerrain = mapModeHeightAboveTerrain
        logicInterface:callLogicThreadFunction("setPlayerInfoForTerrain", {playerPos = mapModePos, playerHeightAboveTerrain = mapModeHeightAboveTerrainForTerrainDetailInfo})

        if mapModeInterpolationFraction < 1.0 then
            mapModeInterpolationFraction = mapModeInterpolationFraction + (1.01 - mapModeInterpolationFraction) * dt * mapZoomOutSpeed
        end
        
        if mapModeInterpolationFraction >= 1.0 then
            mapModeInterpolationFraction = 1.0
            bridge.pos = mapModePos
            bridge.rotationMatrix = mapModeRotation
        end
    else
        --mj:log("NON mapMode setPlayerInfoForTerrain: playerPos:",normalModePos, " playerHeightAboveTerrain:", normalModeHeightAboveTerrain)
        bridge.approximateHeightAboveTerrain = normalModeHeightAboveTerrain
        logicInterface:callLogicThreadFunction("setPlayerInfoForTerrain", {playerPos = normalModePos, playerHeightAboveTerrain = normalModeHeightAboveTerrain}, function(objectInfluencedHeightAboveTerrain_)
            objectInfluencedHeightAboveTerrain = math.max(objectInfluencedHeightAboveTerrain_ - mj:mToP(4.0), 0.0)
            if (not localPlayer.mapMode) and eventManager:mouseHidden() then
                flyingPlayerDesiredHeight = mjm.clamp(flyingPlayerDesiredHeight, 0.0, maxPlayerHeight + objectInfluencedHeightAboveTerrain)
            end
        end)
        
        
        if mapModeInterpolationFraction > 0.0 then
            local mapZoomInSpeedToUse = mapZoomInSpeed
            if cinematicTribeSelectionTransitionTimer then
                mapZoomInSpeedToUse = mjm.mix(mapZoomInSpeed, mapZoomInSpeedCinematic, cinematicTribeSelectionTransitionTimer / cinematicTribeSelectionTransitionTimerDuration)
            end
            mapModeInterpolationFraction = mapModeInterpolationFraction - dt * mapZoomInSpeedToUse
        end
        
        if mapModeInterpolationFraction <= 0.0 then
            mapModeInterpolationFraction = 0.0
            bridge.pos = normalModePos
            --mj:log("c:", mj:pToM(length(bridge.pos) - 1.0))
            bridge.rotationMatrix = normalModeRotation
            --mj:log("setPos:", normalModePos)
            --mj:log("setRotation:", normalModeRotation)
        end
        
    end


    if (mapModeInterpolationFraction > 0.0 or mapModeInterpolationFraction < 1.0) and mapModeRotation and mapModePos then
        local mapModePosToUse = mix(mapModePos, mapModePos - mat3GetRow(mapModeRotation, 1) * getMapModePlayerHeight() * 4.0, 1.0 - mapModeInterpolationFraction)
        --local factor = math.pow(mapModeInterpolationFraction, 0.7)
        local fractionToUse = math.pow(mapModeInterpolationFraction, 3.0)

        local cameraResult = getInterpolatedCamera(normalModePos, mapModePosToUse, normalModeRotation, mapModeRotation, fractionToUse)

        bridge.pos = cameraResult.pos
        bridge.rotationMatrix = cameraResult.rotation
        bridge.approximateHeightAboveTerrain = mix(normalModeHeightAboveTerrain, mapModeHeightAboveTerrain, fractionToUse)

        --[[local aAltitude = length(normalModePos)
        local cAltitude = length(mapModePosToUse)
        local normalModePosNormal = normalModePos / aAltitude
        local mapModePosNormal = mapModePosToUse / cAltitude

        local altitudeDistance = length(normalModePosNormal - mapModePosNormal)
        local simpleDistance = length(normalModePos - mapModePosToUse)

        local altitudeMid = aAltitude + (cAltitude - aAltitude) * 0.5 + altitudeDistance * 0.5

        local ab = mix(aAltitude, altitudeMid, fractionToUse)
        local bc = mix(altitudeMid, cAltitude, fractionToUse)

        local altitudeToUse = mix(ab, bc, fractionToUse)

        --local midOffsetPoint = normalModePos + mat3GetRow(normalModeRotation,2) * altitudeDistance * 0.5 + (mix(normalModePos, mapModePosToUse, 0.5) + mat3GetRow(normalModeRotation,2) * (mj:mToP(1000.0))) * 0.5

        local surfaceMidPoint = normalize(normalModePosNormal + (mapModePosNormal - normalModePosNormal) * 0.5)
        local midPointDirection = mat3GetRow(normalModeRotation,2)
        local midPointRight = -normalize(cross(surfaceMidPoint, midPointDirection))
        
        local midOffsetPoint = normalModePos + ((mat3GetRow(normalModeRotation,2) + midPointRight * 1.0) * (simpleDistance * 0.6 + mj:mToP(50.0)))
        
        local pab = mix(normalModePos, midOffsetPoint, fractionToUse)
        local pbc = mix(midOffsetPoint, mapModePosToUse, fractionToUse)

        local pToUse = mix(pab, pbc, fractionToUse)


       -- local altitudeToUse = mix(aAltitude, mix(altitudeMid,cAltitude, bcFraction), abFraction)

        bridge.pos = normalize(pToUse) * altitudeToUse
        --mj:log("d:", mj:pToM(length(bridge.pos) - 1.0), " normalModePos:", normalModePos, " mapModePos:", mapModePos, " mapModeInterpolationFraction:", mapModeInterpolationFraction)
        --bridge.rotationMatrix = mapModeRotation--mjm.mat3Slerp(normalModeRotation, mapModeRotation, mapModeInterpolationFraction)
        local upVector = normalize(mix(normalize(normalModePos), mat3GetRow(mapModeRotation,1) , fractionToUse))
        local lookPosEnd = (normalModePos + mat3GetRow(normalModeRotation,2) * mj:mToP(-50.0))
        local lookPosStart = normalize(mapModePos)
        local lookPos = mix(lookPosEnd, lookPosStart, fractionToUse)
        local midRotation = mat3LookAtInverse(normalize(bridge.pos - lookPos), upVector)
        bridge.rotationMatrix = midRotation]]

    end

    if cinematicMapModeCameraRotationTimer then
        local fraction = cinematicMapModeCameraRotationTimer

        local cinematicMapModeCameraOffsetRotation = mjm.mat3Rotate(mapModeRotation, 0.8, vec3(0.0,1.0,0.0))

        local mapModeRotatedPosToUse = mat3GetRow(cinematicMapModeCameraOffsetRotation, 2) * (1.0 + getMapModePlayerHeight()) * 2.0
        local fractionToUse = math.pow(fraction, 0.1)

        local interpolatedPos = mix(mapModeRotatedPosToUse, mapModePos, mjm.smoothStep(0.0,1.0,fractionToUse))

        local rotationToUse = mat3LookAtInverse(normalize(interpolatedPos), vec3(0.0,1.0,0.0))

        bridge.pos = interpolatedPos
        bridge.rotationMatrix = rotationToUse
    end
    

    logicInterface:callLogicThreadFunction("updatePlayerPos", {
        playerPos = normalModePos,
        playerDir = mat3GetRow(normalModeRotation, 2),
        mapPos = mapModePos or normalModePos,
        mapMode = localPlayer.mapMode,
    })

end


local function updateMapMode(dt)
    --dt = dt * 0.1
    local playerPosNormal = normalize(mapModePos)
    
    logicInterface:rayTest(mapModePos, playerPosNormal, physicsSets.walkableOrInProgressWalkable, function (rayCollsionResponse)
        if rayCollsionResponse.hasHitObject then
            mapModeHeightAtPlayerPos = math.max(length(rayCollsionResponse.objectCollisionPoint) - 1.0, 0.0)
        elseif rayCollsionResponse.hasHitTerrain then
            mapModeHeightAtPlayerPos = math.max(length(rayCollsionResponse.terrainCollisionPoint) - 1.0, 0.0)
        else
            local testResult = world:getMainThreadTerrainAltitude(playerPosNormal)
            if testResult.hasHit then
                mapModeHeightAtPlayerPos = math.max(testResult.terrainAltitude, 0.0)
            else
                return mj:mToP(10000.0)
            end
        end
    end)
    local mapModeToUse = cinematicMapModeCameraZoomGoalLevel or localPlayer.mapMode
    mapModeBaseDesiredHeight = mapModeHeights[mapModeToUse]

    local zoomSpeedToUse = mapModeZoomBetweenLevelsSpeed
    if cinematicMapModeCameraZoomGoalLevel then
        zoomSpeedToUse = zoomSpeedToUse * 0.5
    end

    mapModeBaseDesiredHeight = mjm.clamp(mapModeBaseDesiredHeight, mapModeBaseDesiredHeight + mapModeHeightAtPlayerPos, maxPlayerHeightMap)
    mapModeBaseHeight = mapModeBaseHeight + (mapModeBaseDesiredHeight - mapModeBaseHeight) * math.min(dt * zoomSpeedToUse, 1.0)

    

    local newHeight = getMapModePlayerHeight()
    mapModeHeightAboveTerrain = newHeight - mapModeHeightAtPlayerPos
    mapModeHeightAboveTerrainForTerrainDetailInfo = mapModeHeights[mapModeToUse]

    mapModePos = playerPosNormal * (1.0 + newHeight)
    --mj:log("mapModePos c:", normalize(mapModePos))

    
    if cinematicMapModeCameraZoomGoalLevel then
        mapModeToUse = mapModes.continental
        for mapMode,name in ipairs(mapModes) do
            if mapModeHeightAboveTerrain > mapModeHeights[mapMode] then
                mapModeToUse = mapMode
                break
            end
        end
        mapModeToUse = math.min(mapModeToUse, mapModes.regional)
        if mapModeToUse ~= localPlayer.mapMode then
            localPlayer:setMapMode(mapModeToUse, false)
        end
    end

    if cinematicMapModeCameraRotationTimer then
        local transitionSpeed = 0.5
        if cinematicMapModeCameraZoomGoalLevel == mapModes.global then
            transitionSpeed = 0.02
        end
        cinematicMapModeCameraRotationTimer = cinematicMapModeCameraRotationTimer + dt * transitionSpeed
        if cinematicMapModeCameraRotationTimer >= 1.0 then
            cinematicMapModeCameraRotationTimer = nil
        end
    end

        
    local right = normalize(cross(playerPosNormal, -mat3GetRow(mapModeRotation, 1)))
    local upVec = cross(playerPosNormal, right)
    
    --[[mapModeRotation = mat3(
        right.x,right.y,right.z,
        upVec.x, upVec.y, upVec.z,
        playerPosNormal.x,playerPosNormal.y,playerPosNormal.z
    )]]

    local damping = dt * 16.0
    local clamped = mjm.clamp(1.0 - damping, 0.0, 1.0)
    mapModeVel = mapModeVel * clamped
    --bridge.rotationMatrix = mapModeRotation

    if mouseDown and (not cinematicMapModeCameraZoomGoalLevel) then
        zoomGoalInfo = nil
        if not mouseDownLatLong then
            mouseDownRotationMatrix = mapModeRotation
            mouseDownSphereRadius2 = (1.0 + mapModeHeightAtPlayerPos) * (1.0 + mapModeHeightAtPlayerPos)
            mouseDownLatLong = getLatLong(mouseDownRotationMatrix, mouseDownSphereRadius2, world:getPointerRayStart(), world:getPointerRayDirection())
        else
            local newLatLong = getLatLong(mouseDownRotationMatrix, mouseDownSphereRadius2, world:getPointerRayStart(), world:getPointerRayDirection())
            if newLatLong then
                local difference = newLatLong - mouseDownLatLong

                local positionRotationMatrixX = mat3Rotate(mat3Identity, difference.x, mat3GetRow(mouseDownRotationMatrix, 0))
                local positionRotationMatrix = mat3Rotate(positionRotationMatrixX, difference.y, mat3GetRow(mouseDownRotationMatrix, 1))

                local newNormalizedGoalPos = normalize(vec3xMat3(mapModePos, positionRotationMatrix))
                
                if localPlayer.mapMode == mapModes.global then

                    local dotPole = dot(newNormalizedGoalPos, vec3(0.0,1.0,0.0))
                    local angle = math.acos(dotPole)
                    if angle < (math.pi * 0.04) then
                        local angleToUse = -(math.pi * 0.04 - angle)
                        local rotation = mjm.mat3Rotate(mat3Identity, angleToUse, mat3GetRow(mouseDownRotationMatrix, 0))
                        newNormalizedGoalPos = normalize(vec3xMat3(newNormalizedGoalPos, rotation))
                        mouseDownRotationMatrix = mapModeRotation
                        mouseDownLatLong = getLatLong(mouseDownRotationMatrix, mouseDownSphereRadius2, world:getPointerRayStart(), world:getPointerRayDirection())
                    elseif angle > math.pi - math.pi * 0.04 then
                        local angleToUse = angle - math.pi + math.pi * 0.04
                        local rotation = mjm.mat3Rotate(mat3Identity, angleToUse, mat3GetRow(mouseDownRotationMatrix, 0))
                        newNormalizedGoalPos = normalize(vec3xMat3(newNormalizedGoalPos, rotation))
                        mouseDownRotationMatrix = mapModeRotation
                        mouseDownLatLong = getLatLong(mouseDownRotationMatrix, mouseDownSphereRadius2, world:getPointerRayStart(), world:getPointerRayDirection())
                    end
                end

                local newGoalPos = newNormalizedGoalPos * (1.0 + getMapModePlayerHeight())
                mapModeVel = (newGoalPos - mapModePos) * 10.0

                hasMovedMap = true
            end
        end
    else

        mouseDownLatLong = nil
        local movementDirection = vec3(0.0,0.0,0.0)
        local isMovingKeyboard = false

        if not cinematicMapModeCameraZoomGoalLevel then
            
            if movementState.forward then
                if localPlayer.mapMode > mapModes.global or dot(playerPosNormal, vec3(0.0,1.0,0.0)) < 0.99 then
                    movementDirection = upVec
                    isMovingKeyboard = true
                end
            elseif movementState.back then
                if localPlayer.mapMode > mapModes.global or dot(playerPosNormal, vec3(0.0,1.0,0.0)) > -0.99 then
                    movementDirection = -upVec
                    isMovingKeyboard = true
                end
            end

            if movementState.left then
                movementDirection = movementDirection - mat3GetRow(mapModeRotation, 0)
                isMovingKeyboard = true
            elseif movementState.right then
                movementDirection = movementDirection + mat3GetRow(mapModeRotation, 0)
                isMovingKeyboard = true
            end
        end


        if isMovingKeyboard then
            hasMovedMap = true
            zoomGoalInfo = nil
            movementDirection = normalize(movementDirection)
            local accel = getMapMovementSpeed() * dt
            mapModeVel = mapModeVel + movementDirection * accel
        else
            if movementState.controllerMovement and (not cinematicMapModeCameraZoomGoalLevel) then
                if not approxEqual(movementState.controllerMovement.x, 0.0) or not approxEqual(movementState.controllerMovement.y, 0.0) then
                    hasMovedMap = true
                    zoomGoalInfo = nil
                    movementDirection = movementDirection + upVec * movementState.controllerMovement.y
                    movementDirection = movementDirection + mat3GetRow(mapModeRotation, 0) * movementState.controllerMovement.x
                    local accel = getMapMovementSpeed() * dt
                    mapModeVel = mapModeVel + movementDirection * accel
                end
            end
        end
    end

    local newMapModePos = nil
    if zoomGoalInfo then
        local currentHeight = getMapModePlayerHeight()
        if zoomGoalInfo.usePositionInterpolation then
            newMapModePos = mapModePos + (zoomGoalInfo.goalPos - mapModePos) * math.min(dt * zoomSpeedToUse, 1.0)
            
        else
            local interpolationFraction = mjm.reverseLinearInterpolate(currentHeight, zoomGoalInfo.startHeight, zoomGoalInfo.endHeight)
            interpolationFraction = mjm.clamp(interpolationFraction, 0.0, 1.0)
            newMapModePos = zoomGoalInfo.startPos + (zoomGoalInfo.goalPos - zoomGoalInfo.startPos) * interpolationFraction
        end


    else
        newMapModePos = mapModePos + mapModeVel * dt
    end

    local newPlayerPosNormal = normalize(newMapModePos)

    
   --[[ if localPlayer.mapMode <= mapModes.continental then
                    
        local absY = math.abs(newPlayerPosNormal.y)
        if absY > 0.5 then
            local xzToUse = vec3(newPlayerPosNormal.x, 0.0, newPlayerPosNormal.z)--mix(vec3(newPlayerPosNormal.x, 0.0, newPlayerPosNormal.z), vec3(playerPosNormal.x, 0.0, playerPosNormal.z), mjm.clamp((absY - 0.8) / (0.9 - 0.8), 0.0, 1.0))
            local xzNormal = normalize(vec3(xzToUse.x, 0.0, xzToUse.z))
            local yClampLength = math.min(absY, 0.99)
            local xzLength = math.sqrt(1.0 - (yClampLength * yClampLength))

            newPlayerPosNormal = normalize(vec3(xzNormal.x * xzLength, mjm.clamp(newPlayerPosNormal.y, -0.99, 0.99), xzNormal.z * xzLength))
        end
    end]]

   -- local preventDueToPole = false
    
    --if localPlayer.mapMode <= mapModes.continental then
        

        --[[if math.abs(newPlayerPosNormal.y) > 0.9 then
            newPlayerPosNormal.y = mjm.clamp(newPlayerPosNormal.y, -0.9, 0.9)
            --local xzNormal = normalize(vec3(newPlayerPosNormal.x, 0.0, newPlayerPosNormal.z))
            --newPlayerPosNormal = normalize(vec3(xzNormal.x * 0.1, newPlayerPosNormal.y, xzNormal.z * 0.1))

            newPlayerPosNormal = normalize(newPlayerPosNormal)
        end]]

        --[[local dp = math.abs(dot(newPlayerPosNormal, vec3(0.0,1.0,0.0)))
        if dp > 0.999 then
            preventDueToPole = true
        end]]
   -- end

    --if not preventDueToPole then
        playerPosNormal = newPlayerPosNormal
        mapModePos = playerPosNormal * (1.0 + newHeight)
        --mj:log("mapModePos d:", normalize(mapModePos))
   -- end


    --local prevUp = mat3GetRow(mapModeRotation, 1)
    --[[local clampedUp = normalize(vec3(0.0, math.max(prevUp.y, 0.01), prevUp.z))
    right = normalize(cross(playerPosNormal, -clampedUp))
    upVec = cross(playerPosNormal, right)]]

    --[[local clampedUp = normalize(vec3(0.0, math.max(upVec.y, 0.01), upVec.z))

    local clampedRight = normalize(cross(clampedUp, playerPosNormal))
    local clampedZ = normalize(cross(clampedUp, -clampedRight))]]
    

    if localPlayer.mapMode > mapModes.global then
        right = normalize(cross(playerPosNormal, -mat3GetRow(mapModeRotation, 1)))
    else
        right = normalize(cross(playerPosNormal, vec3(0.0,-1.0,0.0)))
    end
    upVec = cross(playerPosNormal, right)

    mapModeRotation = mat3(
        right.x,right.y,right.z,
        upVec.x, upVec.y, upVec.z,
        playerPosNormal.x,playerPosNormal.y,playerPosNormal.z
    )

    bridge.rotationMatrix = mapModeRotation
    updateBridge(dt)

    if not playerSapiens:hasFollowers() then
        world:setMiddayVisualOnly(-1.3)
    end
end

local followCamStopWhenCloseDistanceThreshold2 = mj:mToP(0.2) * mj:mToP(0.2)

local function updateFollowCam(dt)
    local distanceMoved = vec3(0.0,0.0,0.0)
    if not followCamObjectIsTerrain then
        local posInfo = world:getMainThreadDynamicObjectInfo(followCamObjectOrVertID)
        if posInfo then
            local newPos = posInfo.pos + normalize(posInfo.pos) * followCamOffsetDistanceAndHeight.y
            distanceMoved = newPos - followCamObjectLookAtPos
            followCamObjectLookAtPos = newPos
            followCamPositionOffsetDistance = followCamPositionOffsetDistance + (followCamObjectLookAtPos - lastFollowCamObjectLookAtPos)
            lastFollowCamObjectLookAtPos = followCamObjectLookAtPos
        end
    end
    
    local posAmountToAdd = math.min(dt * 12.0, 1.0)
    local thisOffset = followCamPositionOffsetDistance * posAmountToAdd * 0.4
    followCamPositionOffsetDistance = followCamPositionOffsetDistance - thisOffset
    normalModePos = normalModePos + thisOffset
    audio:setPlayerPos(normalModePos)
    local normalizedPos = normalize(normalModePos)

    followCamObjectLookAtPosSmoothed = followCamObjectLookAtPos + distanceMoved

    
    local mouseVelocity = mostRecentMouseOffset / dt
    local accel = baseMovementSpeedHorizontal * dt * 60.0
    
    local movementDirection = vec3(0.0,0.0,0.0)
    movementDirection = movementDirection + mat3GetRow(normalModeRotation, 0) * mouseVelocity.x
    movementDirection = movementDirection + cross(normalizedPos, mat3GetRow(normalModeRotation, 0)) * mouseVelocity.y

    normalModeVel = normalModeVel + movementDirection * accel

    if followCamStopWhenClose then
        if length2(followCamPositionOffsetDistance) < followCamStopWhenCloseDistanceThreshold2 then

            local newZDir = normalize(normalModePos - followCamObjectLookAtPosSmoothed)
            local currentDir = mat3GetRow(normalModeRotation, 2)

            mj:log("dot(newDirection, currentDir):", dot(newZDir, currentDir))

            if dot(newZDir, currentDir) > 0.9999 then
                localPlayer:stopFollowingObject()
            end
        end
    end

    return normalizedPos
end

local function updateNormalCam(dt, normalizedPos)

    local mouseVelocity = mostRecentMouseOffset / dt
    local mouseAcceleration = (mouseVelocity - yawPitchVelocity) / dt

    yawPitchAcceleration = mouseAcceleration * 0.5 + yawPitchAcceleration * 0.5

    --local mousePredictedVelocity = yawPitchVelocity + yawPitchAcceleration * dt

    local mousePredictedOffset = mouseVelocity * dt--mousePredictedVelocity * dt

    yawPitchVelocity = mouseVelocity * 0.2 + yawPitchVelocity * 0.2

    predictedTargetYawPitch.x = (predictedTargetYawPitch.x + mousePredictedOffset.x)
    predictedTargetYawPitch.y = (predictedTargetYawPitch.y + mousePredictedOffset.y)

    if predictedTargetYawPitch.y > math.pi * 0.49 then
        predictedTargetYawPitch.y = math.pi * 0.49
    elseif predictedTargetYawPitch.y < -math.pi * 0.49 then
        predictedTargetYawPitch.y = -math.pi * 0.49
    end

    local pitch = predictedTargetYawPitch.y
    local yaw = predictedTargetYawPitch.x

    local yawDifference = (yaw - prevYaw)
    prevYaw = yaw


    local forwardBase = -normalize(cross(normalizedPos, mat3GetRow(normalModeRotation, 0)))
    normalModeRotation = mat3LookAtInverse(forwardBase, normalizedPos)
    normalModeRotation = mat3Rotate(normalModeRotation, -yawDifference, vec3(0.0,1.0,0.0))
    normalModeRotation = mat3Rotate(normalModeRotation, -pitch, vec3(1.0,0.0,0.0))
end

local lastGroundTestPos = vec3(0.0,0.0,0.0)
local minMovementForGroundTest2 = 0.0--mj:mToP(0.05) * mj:mToP(0.05)

local function testForGround(normalizedPos, measuredFlyingPlayerHeight)
    rayTestedGroundHeightIncludingWalkableObjects = nil
    if (not movementState.slow) and (not preventGroundSnappingDueToSlow) and (not controllerIsZooming) then
        local movement2 = length2(normalizedPos - lastGroundTestPos)
        if movement2 > minMovementForGroundTest2 then
            lastGroundTestPos = normalizedPos
            local rayStart = (normalModePos + normalizedPos * (flyingPlayerDesiredHeight - measuredFlyingPlayerHeight))
            local rayEnd = rayStart * 0.5--mj:mToP(playerHeightMeters + 1.5)
            --mj:log("testForGround rayStart:", rayStart, " rayEnd:", rayEnd)
            local rayResult = world:rayTest(rayStart, rayEnd, nil, physicsSets.walkableOrInProgressWalkable, false, true)
            --mj:log("testForGround good")
            local collisionPoint = nil
            if rayResult.hasHitObject then
                collisionPoint = rayResult.objectCollisionPoint
            elseif rayResult.hasHitTerrain then
                collisionPoint = rayResult.terrainCollisionPoint
            end
            if collisionPoint then
                local pointLength = length(collisionPoint)
                local playerPosLength = length(normalModePos)
                local playerCamLength = playerPosLength + (flyingPlayerDesiredHeight - measuredFlyingPlayerHeight)
                if playerCamLength - pointLength < mj:mToP(playerHeightMeters + 1.5) and (not pointAndClickCamera.enabled) then
                    local desiredHeadHeight = pointLength + defaultPlayerHeight
                    flyingPlayerDesiredHeight = desiredHeadHeight - playerPosLength + measuredFlyingPlayerHeight
                    flyingPlayerDesiredHeight = mjm.clamp(flyingPlayerDesiredHeight, 0.0, maxPlayerHeight + objectInfluencedHeightAboveTerrain)
                    return true
                elseif rayResult.hasHitObject then
                    rayTestedGroundHeightIncludingWalkableObjects = pointLength
                end
            end
        end
    end
    return false
end

local collisionVelocityImpactDistanceStartMeters = 0.3
local collisionStopDistanceStartMeters = 0.1

local function testForWalls(velocitySize)
    local velLength = length(normalModeVel)
    if velLength > 0.0 then
        local velNormal = normalModeVel / velLength
        local rayStart = normalModePos
        local rayEnd = rayStart + velNormal * mj:mToP(collisionVelocityImpactDistanceStartMeters)
        local rayResult = world:rayTest(rayStart, rayEnd, nil, physicsSets.pathColliders, false)
        if rayResult.hasHitObject then
            local collisionPoint = rayResult.objectCollisionPoint
            local objectDistance = length(collisionPoint - rayStart)
            if objectDistance < mj:mToP(collisionStopDistanceStartMeters) then
                normalModeVel = vec3(0.0,0.0,0.0)
            else
           -- if objectDistance < mj:mToP(collisionVelocityImpactDistanceStartMeters) then
                --local positionPoint = rayEnd - normalize(rayEnd - rayStart) * mj:mToP(collisionVelocityImpactDistanceStartMeters)
                --local velMultiplier = (objectDistance - mj:mToP(collisionVelocityImpactDistanceStartMeters)) / mj:mToP(collisionVelocityImpactDistanceEndMeters - collisionVelocityImpactDistanceStartMeters)
                --local velMultiplier = (objectDistance - mj:mToP(collisionVelocityImpactDistanceStartMeters)) / mj:mToP(collisionVelocityImpactDistanceEndMeters - collisionVelocityImpactDistanceStartMeters)
                --mj:log("rayResult.objectCollisionNormal:", rayResult.objectCollisionNormal)
                --normalModeVel = vec3(0.0,0.0,0.0)--rayResult.objectCollisionNormal * velLength-- * (1.0 - velMultiplier)
                --normalModePos = collisionPoint + rayResult.objectCollisionNormal * mj:mToP(collisionVelocityImpactDistanceStartMeters) * 0.01--velLength * velocitySize

                --[[ works quite well
                local rayDir = normalize(rayEnd - rayStart)
                normalModePos = collisionPoint - rayDir * mj:mToP(collisionVelocityImpactDistanceStartMeters)

                local v = normalModeVel * velocitySize
                local dist = dot(v, rayResult.objectCollisionNormal)
                normalModePos = normalModePos + v - rayResult.objectCollisionNormal * dist
                ]]

                
                --local rayDir = normalize(rayEnd - rayStart)
                --normalModePos = collisionPoint - rayDir * mj:mToP(collisionVelocityImpactDistanceStartMeters)
                
                --local rayDir = normalize(rayEnd - rayStart)
               -- normalModePos = collisionPoint - rayDir * mj:mToP(collisionVelocityImpactDistanceStartMeters)


                local objectCollisionNormal = rayResult.objectCollisionNormal
                local up = normalize(normalModePos)
                local right = normalize(cross(up, objectCollisionNormal))
                objectCollisionNormal = cross(up, -right)


                local v = normalModeVel * (velocitySize + (mj:mToP(collisionVelocityImpactDistanceStartMeters) - objectDistance))
                local dist = dot(v, objectCollisionNormal)
                normalModePos = normalModePos + v - objectCollisionNormal * dist + objectCollisionNormal * (mj:mToP(collisionVelocityImpactDistanceStartMeters) - objectDistance) * 0.1
                --normalModeVel = vec3(0.0,0.0,0.0)

                return true
            end
        end
    end
    return false
end

--local autoTeleportToMarkerStarted = nil

local function updateNormalModePhaseOne(dt)

    local normalizedPos = normalize(normalModePos)

    if not hasSetPlayerPosOnWorldLoad then
        local result = world:getMainThreadTerrainAltitude(normalModePos)
        if result.hasHit then
            localPlayer:teleportToPos(normalizedPos * (1.0 + result.terrainAltitude))
        end
        hasSetPlayerPosOnWorldLoad = true
    end
    
    local updateFlyingPlayerDesiredHeightForPointAndClickTransformOffset = nil

    if lockCameraLookAtPos and lockCameraMode then
        localPlayer:lookAt(lockCameraLookAtPos)
    elseif followCamObjectOrVertID then
        normalizedPos = updateFollowCam(dt)
    elseif pointAndClickCamera.enabled or pointAndClickCamera.keyRotationActive then
        local initialHeight = length(normalModePos)
        local transformInfo = pointAndClickCamera:update(dt, normalModePos, normalModeRotation)
        normalModeRotation = transformInfo.rotation
        normalModePos = transformInfo.pos
        normalizedPos = normalize(normalModePos)
        updateFlyingPlayerDesiredHeightForPointAndClickTransformOffset = length(normalModePos) - initialHeight
    else
        updateNormalCam(dt, normalizedPos)
    end


    
    local damping = dt * 16.0
    local clamped = mjm.clamp(1.0 - damping, 0.0, 1.0)
    normalModeVel = normalModeVel * clamped


    local distanceFromDesiredHeight = 0.0
    local hitGround = false

    --[[if preventGroundSnappingDueToSlow then
        if movementState.forward or movementState.back or movementState.left  or movementState.right then
            --preventGroundSnappingDueToSlow = false
        end
    end]]
    
    

    if not world.isVR then
        hitGround = testForGround(normalizedPos, normalModeHeightAboveTerrain - onGroundPlayerHeight)

        if prevNormalModeHeightAtPlayerPos and rayTestedGroundHeightIncludingWalkableObjects then
            flyingPlayerDesiredHeight = flyingPlayerDesiredHeight + (prevNormalModeHeightAtPlayerPos - normalModeHeightAtPlayerPos)
            --flyingPlayerDesiredHeight = flyingPlayerDesiredHeight + (normalModeHeightAboveTerrain - prevNormalModeHeightAboveTerrain)
            --prevNormalModeHeightAboveTerrain = nil
        end

        if updateFlyingPlayerDesiredHeightForPointAndClickTransformOffset then
            flyingPlayerDesiredHeight = flyingPlayerDesiredHeight + updateFlyingPlayerDesiredHeightForPointAndClickTransformOffset
        end
        
        flyingPlayerHeight = flyingPlayerDesiredHeight

        --[[if rayTestedGroundHeightIncludingWalkableObjects then
            heightToUse = length(normalModePos) - rayTestedGroundHeightIncludingWalkableObjects
        end]]

        --[[if rayTestedGroundHeightIncludingWalkableObjects then
            distanceFromDesiredHeight = 0.0
        else]]
            local measuredFlyingPlayerHeight = normalModeHeightAboveTerrain - onGroundPlayerHeight
            distanceFromDesiredHeight = (flyingPlayerHeight - measuredFlyingPlayerHeight) * math.min(dt * 16.0, 1.0)
            onGroundPlayerHeight = onGroundPlayerHeight + (desiredOnGroundPlayerHeight - onGroundPlayerHeight) * math.min(dt * 8.0, 1.0)
        --end
        
    end
    
    --mj:log("flyingPlayerDesiredHeight:", flyingPlayerDesiredHeight)
    local goalSpeedInfluenceHeight = flyingPlayerDesiredHeight - math.max(objectInfluencedHeightAboveTerrain - mj:mToP(10.0), 0.0)
    if hitGround then
        goalSpeedInfluenceHeight = 0.0
    end

    goalSpeedInfluenceHeight = math.max(goalSpeedInfluenceHeight, 0.0)
    speedInfluencingSmoothedHeight = math.min(goalSpeedInfluenceHeight, speedInfluencingSmoothedHeight * (1.0 - dt) + goalSpeedInfluenceHeight * dt)
    speedInfluencingSmoothedHeight = math.max(speedInfluencingSmoothedHeight, 0.0)

    local movementSpeedHorizontal = baseMovementSpeedHorizontal * (1.0 + (speedIncreaseFactorAtMaxHeight * (speedInfluencingSmoothedHeight / mj:mToP(1000000.0))))

    if movementState.fast or isDoubleTapForward then
        movementSpeedHorizontal = movementSpeedHorizontal * 4.0
    elseif movementState.slow then
        movementSpeedHorizontal = movementSpeedHorizontal * 0.125
    end
    
    local movementDirection = vec3(0.0,0.0,0.0)
    local isMovingKeyboard = false

    if gameUI:shouldAllowPlayerMovement() then
        if movementState.forward then
            movementDirection = cross(normalizedPos, mat3GetRow(normalModeRotation, 0))
            isMovingKeyboard = true
        elseif movementState.back then
            movementDirection = cross(normalizedPos, -mat3GetRow(normalModeRotation, 0))
            isMovingKeyboard = true
        end

        if movementState.left then
            movementDirection = movementDirection - mat3GetRow(normalModeRotation, 0)
            isMovingKeyboard = true
        elseif movementState.right then
            movementDirection = movementDirection + mat3GetRow(normalModeRotation, 0)
            isMovingKeyboard = true
        end
    end

    if isMovingKeyboard then
        hasMovedNormal = true
        movementDirection = normalize(movementDirection)
        local accel = movementSpeedHorizontal * dt * 60.0
        if pointAndClickCamera.panMouseDown then
            local zAxis = cross(normalizedPos, mat3GetRow(normalModeRotation, 0))
            movementDirection = mat3GetRow(normalModeRotation, 0) * pointAndClickCamera.leftRightMovementAnalog + zAxis * pointAndClickCamera.forwardBackMovementAnalog
            movementDirection = movementDirection * 0.2
        end
        normalModeVel = normalModeVel + movementDirection * accel
    else
        if gameUI:shouldAllowPlayerMovement() and movementState.controllerMovement and (not approxEqual(movementState.controllerMovement.x, 0.0) or not approxEqual(movementState.controllerMovement.y, 0.0)) then
            hasMovedNormal = true
            movementDirection = movementDirection + normalize(cross(normalizedPos, mat3GetRow(normalModeRotation, 0))) * movementState.controllerMovement.y
            movementDirection = movementDirection + mat3GetRow(normalModeRotation, 0) * movementState.controllerMovement.x
            local accel = movementSpeedHorizontal * dt * 60.0
            normalModeVel = normalModeVel + movementDirection * accel
        end
    end

    --newVel = newVel + player.worldUp * distanceFromDesiredHeight * 200.0

    local velocitySize = dt * 0.01

    local prevPos = normalModePos
    normalizedPos = normalize(normalModePos)

    normalModePos = normalModePos + normalizedPos * distanceFromDesiredHeight
    if not testForWalls(velocitySize) then
        normalModePos = normalModePos + normalModeVel * velocitySize
    end

    normalizedPos = normalize(normalModePos)

    if pointAndClickCamera.rotateMouseDown then
        pointAndClickCamera:offsetRotationCenterForPlayerMovement(normalModePos - prevPos)
    end
end

local function updateNormalMode(dt)

    updateNormalModePhaseOne(dt)

    if followCamObjectOrVertID and (not followCamDesiredOffsetRotation) then
        local followCamObjectLookAtPosLength = length(followCamObjectLookAtPos)
        local normalModePosLength = length(normalModePos)
        local dirVec = followCamObjectLookAtPos / followCamObjectLookAtPosLength - normalModePos / normalModePosLength
        local distanceFromFollowCamObject = length(dirVec)
        local minDistance = mj:mToP(2.0)
        if distanceFromFollowCamObject < minDistance and distanceFromFollowCamObject > mj:mToP(0.0001) then
            local offsetDirNormal = dirVec / distanceFromFollowCamObject
            local followObjectPosNormalized = followCamObjectLookAtPos / followCamObjectLookAtPosLength

            local newNormal = normalize(followObjectPosNormalized - offsetDirNormal * minDistance)
            normalModePos = newNormal * normalModePosLength
        end
    end

    prevNormalModeHeightAtPlayerPos = normalModeHeightAtPlayerPos
    if not world.isVR or mapModeInterpolationFraction < 0.0 then
        local result = world:getMainThreadTerrainAltitude(normalModePos)
        if result.hasHit then
            normalModeHeightAtPlayerPos = math.max(result.terrainAltitude, 0.0)
        end
    end

    --normalModeHeightAboveTerrain = onGroundPlayerHeight
    if not world.isVR then

        if normalModeHeightAtPlayerPos then
            normalModeHeightAboveTerrain = length(normalModePos) - 1.0 - normalModeHeightAtPlayerPos
            --mj:log("updated normalModeHeightAboveTerrain:", normalModeHeightAboveTerrain, " terrainHeightSmoothed:", normalModeHeightAtPlayerPos)
            local minHeight = onGroundPlayerHeight
        
            if normalModeHeightAboveTerrain < minHeight then
                local desiredHeight = (1.0 + normalModeHeightAtPlayerPos) + minHeight
                normalModePos = normalize(normalModePos) * desiredHeight
            end
        end
    end

    if followCamObjectOrVertID and (not followCamDesiredOffsetRotation) then --update this down here to ensure we have the final player pos to calculate the look angle
        
        local newDirection = normalize(followCamObjectLookAtPosSmoothed - normalModePos)
        local desiredNormalModeRotation = mat3LookAtInverse(-newDirection, normalize(normalModePos))

        normalModeRotation = mat3Slerp(normalModeRotation, desiredNormalModeRotation, 0.2)
    end

    

    updateBridge(dt)
    audio:setPlayerPos(normalModePos)


    if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu and renderDebugPhysicsLookAtObject then
        --mj:log("test:", newPos, ", dir:", newPos + player.direction * distance)
        
        local playerDirection = -mat3GetRow(normalModeRotation, 2)
        logicInterface:rayTest(normalModePos, normalModePos + playerDirection * rayCastDistance, nil, function(rayCollsionResponse)
            --mj:log(rayCollsionResponse)
            if rayCollsionResponse.hasHitTerrain or rayCollsionResponse.hasHitObject then
                local debugText = nil
                if rayCollsionResponse.hasHitObject then
                    debugText = "Physics Object:" .. rayCollsionResponse.objectID
                else
                    debugText = "Physics Terrain:" .. rayCollsionResponse.triID
                end
                gameUI:setPhysicsLookAtText(debugText)
            else
                gameUI:setPhysicsLookAtText(nil)
            end
        end)
    end


    mostRecentMouseOffset = vec2(0.0,0.0)
end

local terrainHeightRequestSent = false


local function updateLookAtRay()
    if gameUI:shouldAllowPlayerMovement() and (not gameUI:pointAndClickModeHasHiddenMouseForMoveControl()) then
       -- mj:log("updateLookatRay")
        localPlayer.lookAtPositionMainThread = nil
        localPlayer.lookAtPositionMainThreadTerrain = nil

        local rayTestStartPos = world:getPointerRayStart()
        local rayTestEndPos = rayTestStartPos + world:getPointerRayDirection() * rayCastDistance

        
        local allowsTerrain = true
        local collideWithSeaLevel = true
        local physicsSet = nil
        if not buildModeInteractUI:hidden() then
            physicsSet = physicsSets.buildRayColliders
        elseif not storageLogisticsDestinationsUI:hidden() then
            physicsSet = physicsSets.storageLogisticsLookAtColliders
        elseif not changeAssignedSapienUI:hidden() then
            physicsSet = physicsSets.sapiens
            allowsTerrain = false
        elseif (not sapienMoveUI:hidden()) or (not objectMoveUI:hidden()) then
            --collideWithSeaLevel = true
            physicsSet = physicsSets.walkable
        end

        local forwardRayTestResult = world:rayTest(rayTestStartPos, rayTestEndPos, "lookAt", physicsSet, collideWithSeaLevel)

        --mj:log("forwardRayTestResult:", forwardRayTestResult)

        if (forwardRayTestResult.hasHitTerrain and allowsTerrain) or forwardRayTestResult.hasHitObject  or (forwardRayTestResult.hasHitSeaLevel and collideWithSeaLevel) then
            
            local collisionPoint = nil

            if forwardRayTestResult.hasHitObject and ((not forwardRayTestResult.terrainIsCloserThanObject) or (not allowsTerrain)) then
                cursorLookAtID = forwardRayTestResult.objectID
                cursorMeshType = MeshTypeGameObject
                collisionPoint = forwardRayTestResult.objectCollisionPoint
            else
                if forwardRayTestResult.hasHitSeaLevel then
                    collisionPoint = forwardRayTestResult.seaLevelCollisionPoint
                    cursorLookAtTerrainVertID = forwardRayTestResult.seaVertID
                    cursorLookAtID = forwardRayTestResult.seaTriID
                    cursorLookAtTerrainMinLevel = forwardRayTestResult.seaMinLevel
                else
                    collisionPoint = forwardRayTestResult.terrainCollisionPoint
                    cursorLookAtTerrainVertID = forwardRayTestResult.vertID
                    cursorLookAtID = forwardRayTestResult.triID
                    cursorLookAtTerrainMinLevel = forwardRayTestResult.minLevel
                end


                cursorMeshType = MeshTypeTerrain

            end

            
            local lookAtCrowFliesDistance2 = length2(normalize(collisionPoint) - normalize(rayTestStartPos))
            if lookAtCrowFliesDistance2 > maxLookAtTerrainCrowFliesDistance2 then
                cursorLookAtID = nil
                cursorLookAtTerrainVertID = nil
                cursorLookAtTerrainMinLevel = forwardRayTestResult.minLevel
                cursorMeshType = MeshTypeUndefined
            end

            if cursorLookAtID then
                if forwardRayTestResult.hasHitSeaLevel then
                    localPlayer.lookAtPositionMainThreadTerrain = forwardRayTestResult.seaLevelCollisionPoint
                else
                    localPlayer.lookAtPositionMainThreadTerrain = forwardRayTestResult.terrainCollisionPoint
                end

                localPlayer.lookAtPositionMainThread = collisionPoint
                cursorLookAtPos = collisionPoint
            end

        else
            cursorLookAtID = nil
            cursorMeshType = MeshTypeUndefined
        end
    else
        cursorLookAtID = nil
        cursorMeshType = MeshTypeUndefined
    end
end

function localPlayer:update(dt)
    --mj:log("localPlayer:update")
    world:update(dt)

    --[[if controllerZoomValue then
        controllerZoomAccumulator = controllerZoomAccumulator + (controllerZoomValue * dt)
        controllerZoomValue = nil
        
        if controllerZoomAccumulator > controllerZoomAccumulatorThreshold then
            doMouseWheelZoom(controllerZoomAccumulator)
            controllerZoomAccumulator = controllerZoomAccumulator - controllerZoomAccumulatorThreshold
        elseif controllerZoomAccumulator < -controllerZoomAccumulatorThreshold then
            doMouseWheelZoom(controllerZoomAccumulator)
            controllerZoomAccumulator = controllerZoomAccumulator + controllerZoomAccumulatorThreshold
        end
            
    else
        controllerZoomAccumulator = 0.0
    end]]

    if controllerZoomValue then
        doMouseWheelZoom(controllerZoomValue * dt * 30.0 * controllerZoomSensitivityMultiplier, true)
        controllerIsZooming = true
        controllerZoomValue = nil
    else
        controllerIsZooming = false
    end


    if cinematicCamera:update(dt) then
        return
    end

    if lastForwardKeyDownTimer then
        lastForwardKeyDownTimer = lastForwardKeyDownTimer + dt
        if lastForwardKeyDownTimer >= 0.3 then
            lastForwardKeyDownTimer = nil
        end
    end
    if not world.isVR then
        updateLookAtRay()
    end
    if not initialSetupComplete then
        if logicInterface:ready() then
            if not terrainHeightRequestSent then
                terrainHeightRequestSent = true
                logicInterface:callLogicThreadFunction("getHighestDetailTerrainPointAtPoint", normalModePos, function(terrainPoint)
                    normalModeHeightAtPlayerPos = math.max(length(terrainPoint) - 1.0, 0.0)
                    normalModeHeightAboveTerrain = length(normalModePos) - 1.0 - normalModeHeightAtPlayerPos
                    local minHeight = onGroundPlayerHeight
                    local desiredHeight = (1.0 + normalModeHeightAtPlayerPos) + minHeight
                    normalModePos = normalize(normalModePos) * desiredHeight
                    audio:setPlayerPos(normalModePos)
                    initialSetupComplete = true
                end) 
            end
        end
    end
    
    if localPlayer.mapMode then
        updateMapMode(dt)
            worldUIViewManager:updatePointerRay()
            updateLookAtObject()
    else
        if initialSetupComplete then
            updateNormalMode(dt)
            if eventManager:mouseHidden() or pointAndClickCamera.enabled then --todo and no ui displayed?
                worldUIViewManager:updatePointerRay()
                updateLookAtObject()
            end
        end
    end
    mapModeScrollWheelEventDelay = mapModeScrollWheelEventDelay - dt
    
    localPlayer:updateNearSapienDistanceBoundaryWarning()
end


function localPlayer:preUBOUpdate() --careful what happens in here, don't add or remove UI or you get artifacts. The command buffer has already been constructed, you can only update UBOs.

    
    if world.isVR then
        updateLookAtRay()
    end

    --gameUI:update() we used to do this here as it provided quicker turnaround for VR. However now we are hiding views in there in the buildModeUI, and that means we will not be submitting UBOs for already submitted views = very bad.
    -- May need to sort this out when working on VR support, perhaps by queuing up any UI changes made here and applying next frame. Or maybe buildModeUI can just be a bit laggy in VR and that's OK.

end


function localPlayer:updateLookAtObjectsForEnteringNormalGameState()
    updateLookAtObject()
    updateLookAtObjectUI()
end

local function gameOrMenuStateChanged(newActionStateIndex)
    --[[if not mouseHidden then
        prevMovementState = mj:cloneTable(movementState)
        resetMovementState()
    elseif prevMovementState then
        movementState = prevMovementState
        prevMovementState = nil
    end]]
    if newActionStateIndex == eventManager.controllerSetIndexInGame then
        --localPlayer:preUBOUpdate()
        --mj:log("mouseHiddenChanged cursorLookAtID:", cursorLookAtID, " cursorMeshType:", cursorMeshType)
        localPlayer:updateLookAtObjectsForEnteringNormalGameState()
        --retrieveLatestInfoForLookAt()
    end
end

function localPlayer:startLockCamera()
    --mj:log("localPlayer:startLockCamera")
    lockCameraMode = true
    lockCameraLookAtPos = nil
end

function localPlayer:stopCinemaCamera()
    --mj:log("localPlayer:stopCinemaCamera")
    lockCameraMode = false
end

function localPlayer:init(world_, gameUI_)
    
    --mj:log("local player init")
    world = world_
    gameUI = gameUI_

    gameUI:setLocalPlayer(localPlayer)
    world:setMapMode(localPlayer.mapMode)

end

local function rotatePlayer(angle)

    predictedTargetYawPitch.x = predictedTargetYawPitch.x + angle
end

function localPlayer:doVRTeleport()
    local rayTestStartPos = world:getTeleportRayStart()
    local rayTestEndPos = rayTestStartPos + world:getTeleportRayDirection() * rayCastDistance

    local forwardRayTestResult = world:rayTest(rayTestStartPos, rayTestEndPos, nil, nil, true)
    if forwardRayTestResult.hasHitTerrain or forwardRayTestResult.hasHitObject then
        
        if (not forwardRayTestResult.hasHitObject) or forwardRayTestResult.terrainIsCloserThanObject then
            local collisionPoint = forwardRayTestResult.terrainCollisionPoint
            localPlayer:teleportToPos(collisionPoint)
        end
    end
end

function localPlayer:turnLeft()
    rotatePlayer(math.pi * -0.25)
end

function localPlayer:turnRight()
    rotatePlayer(math.pi * 0.25)
end


function localPlayer:mouseDown(position, buttonIndex, modKey)
    if localPlayer.mapMode and buttonIndex == 0 then
        mouseDown = true
    end
end

function localPlayer:mouseUp(position, buttonIndex, modKey)
    if localPlayer.mapMode and buttonIndex == 0 and mouseDown then
        mouseDown = false
    end
end

function localPlayer:vrControllerTriggerDown()
    if localPlayer.mapMode then
        mouseDown = true
    end
end

function localPlayer:vrControllerTriggerUp()
    if localPlayer.mapMode and mouseDown then
        mouseDown = false
    end
end

function localPlayer:zoomToTribeMarker(tribeMarkerPos)


    local tribeMarkerPosLength = length(tribeMarkerPos)
    local mapModePosNormal = normalize(mapModePos)
    local initialMatrix = mapModeRotation
    local sphereRadius2 = (1.0 + mapModeHeightAtPlayerPos) * (1.0 + mapModeHeightAtPlayerPos)

    local initialLatLong = getLatLong(initialMatrix, sphereRadius2, mapModePos, -mapModePosNormal)

    local zoomEndMapMode = mapModes.closest
    if (hasZoomedWithTribeSlectionUIVisible and localPlayer.mapMode > mapModes.regional) then
        zoomEndMapMode = localPlayer.mapMode
    end

    local zoomEndHeight = mapModeHeights[zoomEndMapMode]

    zoomEndHeight = mjm.clamp(zoomEndHeight, zoomEndHeight + (tribeMarkerPosLength - 1.0), maxPlayerHeightMap)
    local newHeight = zoomEndHeight
    if world and world.isVR then
        newHeight = newHeight * 2.0
    end

    local markerSphereRadius2 = tribeMarkerPosLength * tribeMarkerPosLength
    local normalizedTribeMarkerPos = tribeMarkerPos / tribeMarkerPosLength
    local screenRayDirection = world:getRayDirectionForScreenFraction(vec2(0.4, 0.0))
    local finalMapModePos = normalizedTribeMarkerPos * (1.0 + newHeight)
    local finalLatLong = getLatLong(initialMatrix, markerSphereRadius2, finalMapModePos, screenRayDirection)


    local difference = initialLatLong - finalLatLong

    local positionRotationMatrixX = mat3Rotate(mat3Identity, difference.x, mat3GetRow(initialMatrix, 0))
    local positionRotationMatrix = mat3Rotate(positionRotationMatrixX, difference.y, mat3GetRow(initialMatrix, 1))

    local goalPos = normalize(vec3xMat3(mapModePos, positionRotationMatrix))

    zoomGoalInfo = {
        startHeight = getMapModePlayerHeight(),
        endHeight = newHeight,
        startPos = mapModePos,
        goalPos = goalPos,
    }

    if localPlayer.mapMode == mapModes.closest or (hasZoomedWithTribeSlectionUIVisible and localPlayer.mapMode > mapModes.regional) then
        zoomGoalInfo.usePositionInterpolation = true
        return
    end

    localPlayer.mapMode = zoomEndMapMode
    notifyOfMapModeDetailChange()
end

function localPlayer:updateNearSapienDistanceBoundaryWarning()
    if isNearSapienDistanceBoundary and playerSapiens:hasFollowers() and (not localPlayer.mapMode) and (not gameUI:hasUIPanelDisplayed()) then
        warningNoticeUI:show()
    else
        warningNoticeUI:hide()
    end
end

function localPlayer:setBridge(bridge_, clientState)
    bridge = bridge_
    bridge.update = function(dt)
        localPlayer:update(dt)
    end

    normalModePos = clientState.public.pos
    audio:setPlayerPos(normalModePos)
    bridge.pos = normalModePos


    local prevDirection = clientState.public.dir
    if mj:isNan(prevDirection.x) or length2(prevDirection) < 0.000001 then
        prevDirection = vec3(0.0,1.0,0.0)
    end

    local normalizedPos = normalize(normalModePos)
    local rightBase = normalize(cross(normalizedPos, -prevDirection))
    local forwardBase = normalize(cross(normalizedPos, rightBase))
    normalModeRotation = mat3LookAtInverse(forwardBase, normalizedPos)
    bridge.rotationMatrix = normalModeRotation

   -- mj:log("initial rotation:", bridge.rotationMatrix)

    bridge.playerHeightMeters = playerHeightMeters

    eventManager:addEventListenter(mouseMoved, eventManager.mouseMovedListeners)
    eventManager:addEventListenter(mouseWheel, eventManager.mouseWheelListeners)
    eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)
    eventManager:addEventListenter(gameOrMenuStateChanged, eventManager.gameOrMenuStateChangedListeners)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, false, "move", function(pos)
        local skip = false
        if controllerInputReset or controllerInputDipInitialPos then
            --local posLength = length2D(pos)
            if controllerInputReset then 
                controllerInputDipMinMagnitude = length2D(pos)
                if controllerInputDipMinMagnitude > 0.1 then
                    controllerInputDipInitialPos = pos
                    skip = true
                end
                controllerInputReset = false
            else
                local dotProduct = pos.x * controllerInputDipInitialPos.x + pos.y * controllerInputDipInitialPos.y
                if dotProduct < 0.1 then
                    controllerInputDipInitialPos = nil
                else
                    local magnitude = length2D(pos)
                    if magnitude < 0.1 then
                        controllerInputDipInitialPos = nil
                        controllerInputDipMinMagnitude = nil
                    else
                        if magnitude > controllerInputDipMinMagnitude then
                            if magnitude > controllerInputDipMinMagnitude + 0.1 then
                                controllerInputDipInitialPos = nil
                                controllerInputDipMinMagnitude = nil
                            else
                                skip = true
                            end
                        else
                            controllerInputDipMinMagnitude = magnitude
                            skip = true
                        end
                    end
                end
            end
        end

        if not skip then
            movementState.controllerMovement = pos
        else
            movementState.controllerMovement = vec2(0.0,0.0)
        end
        
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, false, "look", function(pos)
        if not localPlayer.mapMode then
            local controllerSensitivity = (0.0001 + controllerLookSensitivityMultiplier * 0.2)
            local offset = controllerSensitivity * pos.x
            mostRecentMouseOffset.x = offset
            local yOffset = controllerSensitivity * pos.y
            if invertControllerLookY then
                yOffset = -yOffset
            end
            mostRecentMouseOffset.y = yOffset
        end
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, false, "zoomIn", function(pos)
        if not approxEqual(pos.x, 0.0) then
            --doMouseWheelZoom(pos.x * mj:mToP(0.1))
            controllerZoomValue = pos.x
        end
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, false, "zoomOut", function(pos)
        if not approxEqual(pos.x, 0.0) then
            controllerZoomValue = -pos.x
            --doMouseWheelZoom(-pos.x * mj:mToP(0.1))
        end
    end)

    local function applyMouseSensitivity(baseValue)
        local rampedValue = math.pow((baseValue + 0.75), 4.0)
        mouseSensitivityMultiplier = MOUSE_MOVE_MULTIPLIER_BASE * rampedValue
    end

    local function applyMouseZoomWheelSensitivity(baseValue)
        local rampedValue = math.pow((baseValue + 0.5), 4.0)
        mouseWheelZoomSensitivitySetting = rampedValue
        --mj:log("applyMouseZoomWheelSensitivity baseValue:", baseValue, " rampedValue:", rampedValue, " mouseWheelZoomSensitivitySetting:", mouseWheelZoomSensitivitySetting)
    end
    
    local function applyControllerLookSensitivity(baseValue)
        local rampedValue = math.pow((baseValue + 0.75), 4.0)
        controllerLookSensitivityMultiplier = MOUSE_MOVE_MULTIPLIER_BASE * rampedValue
    end
    
    local function applyControllerZoomSensitivity(baseValue)
        local rampedValue = 0.2 + math.pow((baseValue + 0.5), 4.0)
        controllerZoomSensitivityMultiplier = rampedValue
    end


    clientGameSettings:addObserver("mouseSensitivity", function(newValue)
        applyMouseSensitivity(newValue)
    end)
    
    clientGameSettings:addObserver("mouseZoomSensitivity", function(newValue)
        applyMouseZoomWheelSensitivity(newValue)
    end)

    clientGameSettings:addObserver("controllerLookSensitivity", function(newValue)
        applyControllerLookSensitivity(newValue)
    end)

    clientGameSettings:addObserver("controllerZoomSensitivity", function(newValue)
        applyControllerZoomSensitivity(newValue)
    end)

    
    applyMouseZoomWheelSensitivity(0.0)
    applyMouseZoomWheelSensitivity(0.3)
    applyMouseZoomWheelSensitivity(0.5)
    applyMouseZoomWheelSensitivity(0.75)
    applyMouseZoomWheelSensitivity(1.0)
    
    applyMouseSensitivity(clientGameSettings.values.mouseSensitivity)
    applyMouseZoomWheelSensitivity(clientGameSettings.values.mouseZoomSensitivity)
    applyControllerLookSensitivity(clientGameSettings.values.controllerLookSensitivity)
    applyControllerZoomSensitivity(clientGameSettings.values.controllerZoomSensitivity)

    
    clientGameSettings:addObserver("invertMouseWheelZoom", function(newValue)
        invertMouseWheelZoom = newValue
    end)
    invertMouseWheelZoom = clientGameSettings.values.invertMouseWheelZoom

    

    clientGameSettings:addObserver("invertControllerLookY", function(newValue)
        invertControllerLookY = newValue
    end)
    invertControllerLookY = clientGameSettings.values.invertControllerLookY

    clientGameSettings:addObserver("enableDoubleTapForFastMovement", function(newValue)
        enableDoubleTapForFastMovement = newValue
    end)
    enableDoubleTapForFastMovement = clientGameSettings.values.enableDoubleTapForFastMovement

    

    mj:log("local player setbridge")

    if clientState.privateShared.tribeID ~= nil then
        localPlayer:setMapMode(nil, true)
    else
        localPlayer:setMapMode(mapModes.global, true)
    end

    pointAndClickCamera:load(localPlayer)
end

function localPlayer:resetControllerMovementInput()
    --mj:log("resetControllerMovementInput")
    
    controllerInputReset = true
end

function localPlayer:startCinematicMapModeCameraRotateGlobeTransition()
    localPlayer:setMapMode(mapModes.global, true)
    cinematicMapModeCameraZoomGoalLevel = mapModes.global
    cinematicMapModeCameraRotationTimer = 0.0
end

function localPlayer:startCinematicMapModeCameraZoomTransition()
    localPlayer:setMapMode(mapModes.global, true)
    cinematicMapModeCameraZoomGoalLevel = mapModes.regional
end

function localPlayer:finishCinematicMapModeTransitions()
    cinematicMapModeCameraZoomGoalLevel = nil
    localPlayer:setMapMode(mapModes.regional, false)
end

function localPlayer:zoomOutToMapForTribeFail()
    localPlayer:setMapMode(mapModes.regional, false)
end

function localPlayer:transitionToGroundAfterTribeSelection(terrainPoint)
    cinematicTribeSelectionTransitionTimer = cinematicTribeSelectionTransitionTimerDuration
    localPlayer:teleportToPos(terrainPoint, true)
    localPlayer:setMapMode(nil, false)
end

function localPlayer:hasMovedAndZoomed(mapModeOrNil)
    if mapModeOrNil then
        return hasZoomedMap and hasMovedMap
    end
    return hasZoomedNormal and hasMovedNormal
    
end

function localPlayer:getPos()
    return bridge.pos
end

function localPlayer:getRotation()
    return bridge.rotationMatrix
end

local hasMostRecentMainThreadHeight = false

function localPlayer:setCinematicTransform(pos, rotation)
    if localPlayer.mapMode then
        localPlayer:setMapMode(nil, true)
    end
    normalModePos = pos
    normalModeRotation = rotation
    
    bridge.pos = pos
    bridge.rotationMatrix = rotation

    --local forwardBase = -normalize(cross(normalize(pos), mat3GetRow(normalModeRotation, 0)))
    local posNormal = normalize(pos)
    predictedTargetYawPitch.y = math.acos(dot(mat3GetRow(normalModeRotation, 1), posNormal))
    if dot(posNormal, mat3GetRow(normalModeRotation, 2)) < 0 then
        predictedTargetYawPitch.y = -predictedTargetYawPitch.y
    end

    audio:setPlayerPos(normalModePos)
    normalModeVel = vec3(0.0,0.0,0.0)

    local playerAltitude = length(pos) - 1.0

    local function updatePosForHeight(terrainAltitude)
        normalModeHeightAtPlayerPos = math.max(terrainAltitude, 0.0)

        local heightAboveTerrain = playerAltitude - normalModeHeightAtPlayerPos
       -- mj:log("heightAboveTerrain:", mj:pToM(heightAboveTerrain))

        if heightAboveTerrain < defaultPlayerHeight then
            onGroundPlayerHeight = math.max(minPlayerHeightSlow, heightAboveTerrain)
            flyingPlayerHeight = 0.0
            preventGroundSnappingDueToSlow = true --hacks
           -- mj:log("b")
        else
            onGroundPlayerHeight = defaultPlayerHeight
            flyingPlayerHeight = heightAboveTerrain - defaultPlayerHeight
            --mj:log("c")
        end

        desiredOnGroundPlayerHeight = onGroundPlayerHeight
        normalModeHeightAboveTerrain = heightAboveTerrain
        flyingPlayerDesiredHeight = flyingPlayerHeight
    end

    local result = world:getMainThreadTerrainAltitude(normalModePos)
    if result.hasHit then
        updatePosForHeight(result.terrainAltitude)
        hasMostRecentMainThreadHeight = true
        --mj:log("a")
    else
        --mj:log("b")
        hasMostRecentMainThreadHeight = false

        logicInterface:callLogicThreadFunction("getHighestDetailTerrainPointAtPoint", normalize(normalModePos), function(terrainPoint)
            if not hasMostRecentMainThreadHeight then
                --mj:log("c")
                updatePosForHeight(length(terrainPoint) - 1.0)
            end
        end) 
    end
    
    bridge.approximateHeightAboveTerrain = normalModeHeightAboveTerrain
    logicInterface:callLogicThreadFunction("setPlayerInfoForTerrain", {playerPos = normalModePos, playerHeightAboveTerrain = normalModeHeightAboveTerrain})
    

    logicInterface:callLogicThreadFunction("updatePlayerPos", {
        playerPos = normalModePos,
        playerDir = mat3GetRow(normalModeRotation, 2),
        mapPos = mapModePos or normalModePos,
        mapMode = localPlayer.mapMode,
    })
end

return localPlayer