local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

--local locale = mjrequire "common/locale"
--local steam = mjrequire "common/utility/steam"
local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local audio = mjrequire "mainThread/audio"
local musicPlayer = mjrequire "mainThread/musicPlayer"
local bugReporting = mjrequire "mainThread/bugReporting"
local pointAndClickCamera = mjrequire "mainThread/pointAndClickCamera"
local updateDriverMenu = mjrequire "mainThread/ui/mainMenu/updateDriverMenu"
--local publicUnstablePasswordPanel = mjrequire "mainThread/ui/mainMenu/publicUnstablePasswordPanel"
--local logicInterface = mjrequire "mainThread/logicInterface"

local terminal = mjrequire "mainThread/ui/terminal"
local chatMessageUI = mjrequire "mainThread/ui/chatMessageUI"
local gameUI = mjrequire "mainThread/ui/gameUI"
local mainMenu = mjrequire "mainThread/ui/mainMenu/mainMenu"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"
local alertPanel = mjrequire "mainThread/ui/alertPanel"
local uiTextEntry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"

local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"

local nameLists = mjrequire "common/nameLists"

--local mjs = mjrequire "common/mjs"

local controller = {
    appDatabase = nil,
    mainView = nil,
    isOnlineClient = false
}
local bridge = nil

function controller:reloadAll(preservedState)
    bridge:reloadAll(preservedState)
end

local keyMapsByGameState = {}

local keyMap = {
    [keyMapping:getMappingIndex("debug", "reload")] = function(isDown)
		if isDown then 
            controller:reloadAll(nil)
            return true
		end 
    end,

   --[[ [keyMapping:getMappingIndex("game", "escape")] = function (isDown) 
        if isDown then 
            if not terminal.hidden then
                terminal:hide()
                return true
            end
		end 
    end,]]
}

keyMapsByGameState[GameStateLoadedRunning] = {
	--[[[keyMapping:getMappingIndex("game", "escape")] = function (isDown) 
        if isDown then 
            if not gameUI:popUI(false, false) then
                controller:pauseGameAndshowPauseUI()
            end
		end 
        return true 
    end,]]
    [keyMapping:getMappingIndex("game", "luaPrompt")] = function(isDown)
        if isDown then
            terminal:show()
            return true
        end
    end,
    [keyMapping:getMappingIndex("game", "chat")] = function(isDown)
        if isDown then
            chatMessageUI:showWithTextEntryActive()
            return true
        end
    end,
}


function controller:presentConnectionLostAlert(disconnectionWasConnected, disconnectionWasRejection, rejectionReason, rejectionContext)
    if controller:getGameState() == GameStateMainMenu then
        mainMenu:presentConnectionLostAlert(disconnectionWasConnected, disconnectionWasRejection, rejectionReason, rejectionContext)
    end
end

local function mouseMoved(pos, relativePos)
    return bridge:mouseMovedInput(pos)
end

local function mouseDown(pos, buttonIndex, modKey)
    if bridge:mouseDownInput(pos, buttonIndex) then
        return true
    end
    if worldUIViewManager:mouseDownInput(pos, buttonIndex) then
        return true
    end
    return false
end

local function mouseUp(pos, buttonIndex, modKey)
    bridge:mouseUpInput(pos, buttonIndex)
    worldUIViewManager:mouseUpInput(pos, buttonIndex)
end

local function controllerButtonDown(buttonIndex)
    if buttonIndex == eventManager.vrControllerCodes.RIGHT_TRIGGER then
        if bridge:vrMouseDown(0) then
            return true
        end
        if worldUIViewManager:vrMouseDown(0) then
            return true
        end
    elseif buttonIndex == eventManager.vrControllerCodes.CANCEL then
        local gameState = controller:getGameState()
        local escapeFunction = keyMapsByGameState[gameState][keyMapping.game.escape.index]
        if escapeFunction then
            escapeFunction(true)
            return true
        end
    end
end

local function controllerButtonUp(buttonIndex)
    if buttonIndex == eventManager.vrControllerCodes.RIGHT_TRIGGER then
        bridge:vrMouseUp(0)
        worldUIViewManager:vrMouseUp(0)
    end
end

local function keyChanged(isDown, mapIndexes, isRepeat)
    
    local gameState = controller:getGameState()
    local keyMapToUse = keyMapsByGameState[gameState]

    for i,mapIndex in ipairs(mapIndexes) do
        if keyMapToUse and keyMapToUse[mapIndex]  then
            if keyMapToUse[mapIndex](isDown) then
                return true
            end
        end
        if keyMap[mapIndex]  then
            if keyMap[mapIndex](isDown) then
                return true
            end
        end

        if bridge.mainView:keyChangedInput(isDown, mapIndex, 0, isRepeat) then
            return true
        end
        
        if worldUIViewManager:keyChangedInput(isDown, mapIndex, 0, isRepeat) then
            return true
        end
    end
    return false
end

local function mouseWheel(position, scrollChange, modKey)
    return bridge:mouseWheelInput(position, scrollChange)
end


function controller:resumeGameAndHideTerminal()
    if not terminal.hidden then
        terminal:hide()
        gameUI:show()
        gameUI:updateUIHidden()
    end
end

function controller:getGameState()
    return bridge:getGameState()
end

function controller:getFPS()
    return bridge.FPS
end

function controller:loadWorld(worldID, sessionIndex, createNewSession)
    bridge:loadWorld(worldID, sessionIndex or 0, createNewSession or false)
end

function controller:joinWorld(ip, port)
    bridge:joinWorld(ip, port)
end

function controller:newWorld(name, seed, customOptions, enabledWorldMods)
    bridge:newWorld(name, seed, customOptions, enabledWorldMods)
end

function controller:exitToMenu()
    bridge:exitToMenu()
end

function controller:exitToDesktop()
    bridge:exitToDesktop()
end

function controller:getWorldSaveFileList()
    return bridge:getWorldList()
end

function controller:renameWorld(worldID, newName)
    bridge:renameWorld(worldID, newName)
end

function controller:getWorldConfigurationInfo(worldID)
    return bridge:getWorldConfigurationInfo(worldID)
end

function controller:setMultiSamplingEnabled(multiSamplingEnabled)
    bridge.multiSamplingEnabled = multiSamplingEnabled
end

function controller:getSupportedScreenResolutionList()
    return bridge:getSupportedScreenResolutionList()
end

function controller:selectScreenResolutionAndWindowMode(screenResolutionIndex, windowModeIndex)
    bridge:selectScreenResolutionAndWindowMode(screenResolutionIndex, windowModeIndex)
end

function controller:getCurrentScreenResolutionIndexAndMode()
    return bridge:getCurrentScreenResolutionIndexAndMode()
end

function controller:getWorldSavePath(worldID, appendPathOrNil)
    return bridge:getWorldSavePath(worldID, appendPathOrNil)
end

function controller:setModEnabledForWorld(worldID, dirName, enabled)
    bridge:setModEnabledForWorld(worldID, dirName, enabled)
end

function controller:updateMod(worldID, dirName)
    bridge:updateMod(worldID, dirName)
end

function controller:setVsync(newValue)
    bridge:setVsync(newValue)
end


function controller:getFOVYDegrees()
    return bridge.fovY / 0.0174533
end

function controller:setFOVYDegrees(newValue)
    bridge.fovY = newValue * 0.0174533
end

function controller:setLocale(newValue)
    if newValue == nil then
        newValue = ""
    end
    bridge.locale = newValue
end

function controller:getLocaleSettingKey()
    local localeSettingKey = bridge.locale
    if localeSettingKey == "" then
        return nil
    end
    return localeSettingKey
end

function controller:getVersionString()
    return bridge:getVersionString()
end


function controller:getWorldDataVersionCompatibilityIndex()
    return bridge:getWorldDataVersionCompatibilityIndex()
end

function controller:getRawVersionString()
    return bridge:getRawVersionString()
end

function controller:getHasEverLoadedWorld()
    return bridge:getHasEverLoadedWorld()
end

function controller:getIsDevelopmentBuild()
    return bridge:getIsDevelopmentBuild()
end

function controller:getPlayerID()
    return bridge.playerID
end

function controller:getVulkanDeviceVendorID()
    return bridge.vulkanDeviceVendorID
end

function controller:getVulkanDeviceName()
    return bridge.vulkanDeviceName
end

function controller:getVulkanDriverVersion()
    return bridge.vulkanDriverVersion
end

function controller:getVRAMUsageInfo()
    return bridge:getVRAMUsageInfo()
end

function controller:generateVRAMProfile()
    bridge:generateVRAMProfile()
end

function controller:getIsDemo()
    return bridge:getIsDemo()
end

function controller:getPlatform() -- windows, mac
    return bridge:getPlatform()
end

function controller:getShouldCheckGPUDriver()
    return bridge:getShouldCheckGPUDriver()
end

function controller:getEnabledModListFromConfig(worldID)
    return bridge:getEnabledModListFromConfig(worldID)
end

function controller:deleteWorld(worldID)
    bridge:deleteWorld(worldID)
end

function controller:changeAppModEnabled(modDir, newEnabled)
    bridge:changeAppModEnabled(modDir, newEnabled)
end

function controller:appModIsEnabled(modDir)
    return bridge:appModIsEnabled(modDir)
end

function controller:getWindowSize()
    return bridge:getWindowSize()
end

--[[function generateVRAMProfile()
    controller:generateVRAMProfile()
end]]

local function hideMouse()
    if not eventManager:mouseHidden() then
        eventManager:hideMouse()
        gameUI:mouseHiddenChanged(true)
    end
end

local function showMouse()
    if eventManager:mouseHidden() then
        eventManager:showMouse()
        gameUI:mouseHiddenChanged(false)
    end
end

function controller:addToSavedIPConnectionsList(joinWorldIP, joinWorldPort, joinWorldServerName)
    local recentIPConnections = controller.appDatabase:dataForKey("recentIPConnections") or {}

    local found = false
    for i,connection in ipairs(recentIPConnections) do
        if connection.ip == joinWorldIP and connection.port == joinWorldPort then
            connection.serverName = joinWorldServerName
            found = true
            if i ~= 1 then
                table.remove(recentIPConnections, i)
                table.insert(recentIPConnections, 1, connection)
            end
            break
        end

        if i > 50 then
            break
        end
    end

    if not found then
        table.insert(recentIPConnections, 1, {
            ip = joinWorldIP,
            port = joinWorldPort,
            serverName = joinWorldServerName
        })
    end

    controller.appDatabase:setDataForKey(recentIPConnections, "recentIPConnections")
end

function controller:getSavedIPConnectionsList()
    return controller.appDatabase:dataForKey("recentIPConnections")
end

local function migrateDetailedInfo(worldID) -- for < 0.5 worlds, so that the tribe name is displayed in the load list. also migrates imported world directories
    --mj:log("migrateDetailedInfo")
    local result = nil
	local playersDatabase = bridge:loadServerDatabase(worldID, "players")
    local clientID = bridge:getClientIDForSessionIndex(0)
    local playerID = bridge:getPlayerID()

    local playerInfo = playersDatabase:dataForKey(clientID)
    if not playerInfo then
        local allData = playersDatabase:allData()
        for otherID,clientState in pairs(allData) do
            if otherID ~= clientID and clientState.privateShared and clientState.privateShared.tribeID then
                --todo this may not always be the desired behavior, and it should show some UI allowing the player to choose from the available taken tribes, or to create a new tribe.
                mj:log("It looks like this world was transferred from somewhere else, and this clientID has no associated tribe. Doing automatic migration of client data from:", otherID, " to:", clientID)
                playersDatabase:setDataForKey(clientState, clientID)
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
                                --mj:log("setting playerInfos:", playerInfos)
                                worldDatabase:setDataForKey(playerInfos, "playerInfos")
                            end
                        end
                        worldDatabase:setDataForKey(playerClientIDsByTribeIDs, "tribeList")
                    end
                end

                break
            end
        end
    end

    if playerInfo and playerInfo.privateShared.tribeID then
        
        local detailedSessionInfo = {}

        detailedSessionInfo.tribeID = playerInfo.privateShared.tribeID
        detailedSessionInfo.tribeName = playerInfo.privateShared.tribeName or nameLists:generateTribeName(playerInfo.privateShared.tribeID, 3634)
        
        controller:saveDetailedWorldSessionInfo(detailedSessionInfo, worldID, 0)

        result = detailedSessionInfo

    end

    bridge:cleanupServerDatabase()

    return result
end

function controller:getDetailedWorldSessionInfo(worldID, sessionIndex, attemptToMigrateIfNotFound)
    local dbKey = "sessionInfo_" .. worldID .. string.format("%d", (sessionIndex or 0))
    local detailedSessionInfo = bridge.appDatabase:dataForKey(dbKey)

    if detailedSessionInfo then
        return detailedSessionInfo
    end
    --mj:log("not found:", attemptToMigrateIfNotFound, " sessionIndex:", sessionIndex)
    if attemptToMigrateIfNotFound then
        if (sessionIndex or 0) == 0 then
            return migrateDetailedInfo(worldID)
        end
    end
    return nil
end


function controller:saveDetailedWorldSessionInfo(detailedSessionInfo, worldID, sessionIndex)
    local dbKey = "sessionInfo_" .. worldID .. string.format("%d", (sessionIndex or 0))
    bridge.appDatabase:setDataForKey(detailedSessionInfo, dbKey)
end

function controller:getDetailedWorldSessionInfoForCurrentWorld()
    local worldID = bridge:getWorldID()
    if worldID then
        local sessionIndex = bridge:getWorldSessionIndex()
        return controller:getDetailedWorldSessionInfo(worldID, sessionIndex, false)
    end
    return nil
end

function controller:saveDetailedWorldSessionInfoForCurrentWorld(detailedSessionInfo)
    local worldID = bridge:getWorldID()
    if worldID then
        local sessionIndex = bridge:getWorldSessionIndex()
        controller:saveDetailedWorldSessionInfo(detailedSessionInfo, worldID, sessionIndex)
    end
end

function controller:incrementCurrentWorldSessionIndexForTribeLoad()
    local worldID = bridge:getWorldID()
    if worldID then
        local sessionIndexKey = "sessionCounter_" .. worldID
        local savedSessionIndex = controller.appDatabase:dataForKey(sessionIndexKey)
        local nextSessionIndex = (savedSessionIndex or 1) + 1
        controller.appDatabase:setDataForKey(nextSessionIndex, sessionIndexKey)
    end
end

function controller:removeAnySavedTribeNotMatchingCurrentClientID(tribeID)
    --mj:log("controller:removeAnySavedTribeNotMatchingCurrentClientID:", tribeID)
    local currentWorldID = bridge:getWorldID()
    if currentWorldID then
        local sessionIndexKey = "sessionCounter_" .. currentWorldID
        local currentSessionIndex = controller.appDatabase:dataForKey(sessionIndexKey) or 0

        local orderedWorlds = controller.appDatabase:dataForKey("orderedWorldInfos")

        if orderedWorlds then
            local removed = false
            for i=#orderedWorlds,1,-1 do
                if currentWorldID == orderedWorlds[i].worldID and currentSessionIndex ~= (orderedWorlds[i].sessionIndex or 0) then
                    --mj:log("found:", orderedWorlds[i])
                    local sessionIndex = orderedWorlds[i].sessionIndex
                    local sessionInfo = controller:getDetailedWorldSessionInfo(currentWorldID, sessionIndex, false)
                    if sessionInfo and sessionInfo.tribeID == tribeID then
                       -- mj:log("removed:", sessionInfo)
                        table.remove(orderedWorlds, i)
                        removed = true
                    end
                end
            end
            if removed then
                controller.appDatabase:setDataForKey(orderedWorlds, "orderedWorldInfos")
            end
        end
    end
end

function controller:joinSessionWithIndex(totalSessionCount) --don't call this generally, it's handling a specific once off requirement
    bridge:joinSessionWithIndex(totalSessionCount)
end

-- called by engine

function controller:skipMainMenu() --bit of a hack, used when reloading when a Steam friend invite comes through
    mainMenu:hideForEngineWorldLoad()
end

function controller:worldLoaded(worldID, sessionIndex)
    --mj:log("controller:worldLoaded:", worldID, " sessionIndex:", sessionIndex)
    local orderedWorlds = bridge.appDatabase:dataForKey("orderedWorldInfos")
    if not orderedWorlds then
        orderedWorlds = {}
    else
        for i=#orderedWorlds,1,-1 do
            if worldID == orderedWorlds[i].worldID and sessionIndex == (orderedWorlds[i].sessionIndex or 0) then
                table.remove(orderedWorlds, i)
            end
        end
    end
    
    table.insert(orderedWorlds, 1, {
        worldID = worldID,
        sessionIndex = sessionIndex,
    })
    bugReporting:setMostRecentWorldID(worldID, sessionIndex)
    bridge.appDatabase:setDataForKey(orderedWorlds, "orderedWorldInfos")

    gameUI:worldLoaded()
end

function controller:update(dt)
    local gameState = controller:getGameState()
    if gameState == GameStateLoadedRunning then
        if eventManager.controllerIsPrimary then
            hideMouse()
            if gameUI:hasUIPanelDisplayed() or (not terminal.hidden) then
                eventManager:setControllerActionSetIndex(eventManager.controllerSetIndexMenu)
            else
                eventManager:setControllerActionSetIndex(eventManager.controllerSetIndexInGame)
            end
        else
            if gameUI:hasUIPanelDisplayed() or (not terminal.hidden) then
                showMouse()
                
                eventManager:setControllerActionSetIndex(eventManager.controllerSetIndexMenu)
            else
                if gameUI:shouldShowMouse() or (pointAndClickCamera:shouldShowMouse() and (not gameUI:shouldBlockPointAndClickFromShowingMouse())) then
                    showMouse()
                else
                    hideMouse()
                end
                eventManager:setControllerActionSetIndex(eventManager.controllerSetIndexInGame)
            end
        end
    else
        eventManager:setControllerActionSetIndex(eventManager.controllerSetIndexMenu)
    end

    eventManager:update(dt)
end

function controller:setIsOnlineClient(isOnlineClient_)
    if isOnlineClient_ ~= controller.isOnlineClient then
        controller.isOnlineClient = isOnlineClient_
		bridge:setPauseOnLostFocus(clientGameSettings.values.pauseOnLostFocus and (not controller.isOnlineClient))
    end
end

function controller:modInstallAuthorizationResponse(allowModInstall)
    bridge:modInstallAuthorizationResponse(allowModInstall)
end

function controller:setBridge(bridge_, isVR, preservedState)

    mj:log("Loading with preservedState:", preservedState)
    bridge = bridge_
    controller.appDatabase = bridge.appDatabase


    local orderedWorlds = bridge.appDatabase:dataForKey("orderedWorldInfos")
    if not orderedWorlds then
        local orderedWorldsLegacy = bridge.appDatabase:dataForKey("orderedWorlds") --migrate from < 0.5
        if orderedWorldsLegacy then
            if orderedWorldsLegacy[1] then
                orderedWorlds = {}
                for i,worldID in ipairs(orderedWorldsLegacy) do
                    orderedWorlds[i] = {
                        worldID = worldID,
                    }
                end
                bridge.appDatabase:setDataForKey(orderedWorlds, "orderedWorldInfos")
            end
            bridge.appDatabase:removeDataForKey("orderedWorlds")
        end

        --0.7
        bridge.appDatabase:setDataForKey(true, "installedAfter_0_6")
    end

    local mainView = bridge.mainView
    controller.preservedState = preservedState

    clientGameSettings:load(bridge.appDatabase)
    keyMapping:loadSettings()
    
    if orderedWorlds and orderedWorlds[1] then
        bugReporting:setMostRecentWorldID(orderedWorlds[1].worldID, orderedWorlds[1].sessionIndex)
    end

    audio:clientGameSettingsLoaded()

    bridge.multiSamplingEnabled = clientGameSettings.values.multiSamplingEnabled
    
	
	clientGameSettings:addObserver("allowLanConnections", function(newValue)
		bridge:setAllowLanConnections(newValue)
	end)
    bridge:setAllowLanConnections(clientGameSettings.values.allowLanConnections)
    
	
	clientGameSettings:addObserver("pauseOnLostFocus", function(newValue)
		bridge:setPauseOnLostFocus(newValue and (not controller.isOnlineClient))
	end)
    bridge:setPauseOnLostFocus(clientGameSettings.values.pauseOnLostFocus)

	clientGameSettings:addObserver("bloomEnabled", function(newValue)
		bridge.bloomEnabled = newValue
	end)
    bridge.bloomEnabled = clientGameSettings.values.bloomEnabled

    local windowZOffset = 0.0

    if isVR then
        local scaleToUse = 4.0 / 1920.0
        windowZOffset = -2.0
        mainView.scale = scaleToUse

        mainView.size = vec2(1920.0, 1080.0)
        mainView.baseOffset = vec3(0.0, 1080.0 / 2.0 + 0.05 * 1920.0, 0.0)

       -- bridge.mainView.windowRotation = mat3LookAtInverse(vec3(1.0,0.0,0.0), vec3(0.0,1.0,0.0))
    else
       -- mj:log("window size: (", bridge.mainView.size.x, ", ",bridge.mainView.size.y, ")")
        local scaleToUse = mainView.size.y / 1080;
        if scaleToUse > 1.0001 then
            if scaleToUse >= 3.0 then
                scaleToUse = 3.0
            elseif scaleToUse >= 2.0 then
                scaleToUse = 2.0
            elseif scaleToUse >= 1.5 then
                scaleToUse = 1.5
            elseif scaleToUse >= 1.25 then
                scaleToUse = 1.25
            else
                scaleToUse = 1.0
            end
        elseif scaleToUse < 0.9999 then
            if scaleToUse >= 0.75 then
                scaleToUse = 0.75
            elseif scaleToUse >= 0.66 then
                scaleToUse = 2.0/3.0
            else
                scaleToUse = 0.5
            end
        else
            scaleToUse = 1.0
        end

        local fovY = bridge.fovY
        windowZOffset = -(mainView.size.y * 0.5 / math.tan(fovY * 0.5))
        
        local oldSize = mainView.size
        mainView.scale = scaleToUse
        mainView.size = oldSize / scaleToUse
        
    end
    
    mainView.windowZOffset = windowZOffset


    local uiMainView = View.new(mainView)
    --uiMainView.color = mjm.vec4(0.5,0.5,1.0,1.0)
    local mainViewSize = mainView.size
    controller.virtualSize = mainViewSize
    local sizeToUse = vec2(mainViewSize.x, mainViewSize.y)
    local desiredRatio = 16.0/9.0
    local ratio = mainViewSize.x / mainViewSize.y
    if ratio > desiredRatio + 0.0001 then
        sizeToUse.x = sizeToUse.y * desiredRatio
    --elseif ratio < desiredRatio - 0.0001 then
       -- sizeToUse.y = sizeToUse.x / desiredRatio
    end

    uiMainView.size = sizeToUse
   -- mj:log("setting UI view size:", sizeToUse)

    controller.mainView = uiMainView
    controller.screenSize = mainView.size
   -- mj:log("screenSize:", controller.screenSize)

    --uiMainView.keyChanged = keyChanged

    local function showMainMenu()
        local function doShow()
            mainMenu:load(controller)
            terminal:load(controller)
        end

        --[[local function checkHasPlayed05World()
            if controller.appDatabase:dataForKey("entered05Password_a") then
                return true
            end

            if controller.appDatabase:dataForKey("recentIPConnections") then
                return true
            end
            if orderedWorlds then
                for i = 1, #orderedWorlds do
                    if orderedWorlds[i].sessionIndex ~= nil then
                        return true
                    end
                end
            end
            return false
        end]]

        local foundDelay = false
        --[[local currentBetaName = steam:getCurrentBetaName()
        if currentBetaName and currentBetaName == "public-beta-unstable" then
            if not checkHasPlayed05World() then
                foundDelay = true
                publicUnstablePasswordPanel:load(controller, function()
                    controller.appDatabase:setDataForKey(true, "entered05Password_a")
                    doShow()
                end)
            end
        end]]

        if not foundDelay then
            doShow()
        end
    end

    local deviceVendorID = controller:getVulkanDeviceVendorID()
    local deviceName = controller:getVulkanDeviceName()
    local driverVersion = controller:getVulkanDriverVersion()

    --mj:log("deviceVendorID:", deviceVendorID)
   -- mj:log("deviceName:", deviceName)
   -- mj:log("driverVersion:", driverVersion)

   local vendorInfo = nil

    if controller:getShouldCheckGPUDriver() then
        local infosByVendor = {
            ["10de"] = { --nvidia
                minVersion = 1937768448,
                downloadURL = "https://www.nvidia.com/Download/index.aspx",
                downloadText = "Download from NVIDIA",
            },
            ["1002"] = { --amd
                minVersion = 8388608 + 179,
                downloadURL = "https://www.amd.com/en/support",
                downloadText = "Download from AMD",
            }
        }
    
        vendorInfo = infosByVendor[deviceVendorID]
    end

    
    if vendorInfo and vendorInfo.minVersion > driverVersion and (not clientGameSettings.values.disableDriverVersionWarning) then
        updateDriverMenu:load(controller, deviceName, vendorInfo.downloadURL, vendorInfo.downloadText, function()
            updateDriverMenu:hide()
            showMainMenu()
        end)
    else
        showMainMenu()
    end

    musicPlayer:init(controller, controller:getGameState())

    eventManager:setUIScreenSize(controller.virtualSize, mainView.scale)

    eventManager:addEventListenter(mouseMoved, eventManager.mouseMovedListeners)
    eventManager:addEventListenter(mouseDown, eventManager.mouseDownListeners)
    eventManager:addEventListenter(mouseUp, eventManager.mouseUpListeners)
    eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)
    eventManager:addEventListenter(controllerButtonDown, eventManager.vrControllerButtonDownListeners)
    eventManager:addEventListenter(controllerButtonUp, eventManager.vrControllerButtonUpListeners)
    eventManager:addEventListenter(mouseWheel, eventManager.mouseWheelListeners)


    uiSelectionLayout:init(eventManager)
	uiKeyImage:init()

    alertPanel:init(controller)
    uiTextEntry:init(controller)

    --musicPlayer:gameStateChanged(controller:getGameState())

    --[[local testData = {
		seasonLengthDays = 4.0,
		testArray = {
			357.7,
			vec3(1,2,3),
			"string"
		},
		[4] = "this is the number 4"
    }
    
    local serialized = mjs.serializeReadable(testData)

    mj:log("testData:\n", serialized)]]
end

return controller