local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
local vec2 = mjm.vec2

local keyMapping = mjrequire "mainThread/keyMapping"
--local uIScreenSize = vec2(1920,1080)

local eventManager = {
	mouseMovedListeners = {},
	mouseDownListeners = {},
	mouseUpListeners = {},
	mouseWheelListeners = {},
	keyChangedListeners = {},
	mouseHiddenChangedListeners = {},
	gameOrMenuStateChangedListeners = {},
	vrControllerButtonDownListeners = {},
	vrControllerButtonUpListeners = {},
	vrControllerAnalogChangedListeners = {},
	textEntryListener = nil,
	controllerPrimaryChangedListeners = {},
	appFocusChangedListeners = {},

	mouseLoc = vec2(0.0,0.0),
}

local downKeys = {}

eventManager.controllerSetIndexMenu = 0
eventManager.controllerSetIndexInGame = 1
eventManager.controllerIsPrimary = false

local sets = {
	eventManager.controllerSetIndexMenu,
	eventManager.controllerSetIndexInGame
}


local controllerMapping = {
	[eventManager.controllerSetIndexMenu] = {
		setName = "MenuControls",
		digital = {},
		digitalDownSet = {},
		analog = {},
	},
	[eventManager.controllerSetIndexInGame] = {
		setName = "InGameControls",
		digital = {},
		digitalDownSet = {},
		analog = {},
	}
}

local controllerActionCallbacksBySet = {}

function eventManager:addControllerCallback(setIndex, isDigital, actionName, func)
	local controllerActionCallbacks = controllerActionCallbacksBySet[setIndex]
	if not controllerActionCallbacks then
		controllerActionCallbacks = {}
		controllerActionCallbacksBySet[setIndex] = controllerActionCallbacks
	end

	local controllerActionCallbacksForType = nil
	if isDigital then
		controllerActionCallbacksForType = controllerActionCallbacks.digital
		if not controllerActionCallbacksForType then
			controllerActionCallbacksForType = {}
			controllerActionCallbacks.digital = controllerActionCallbacksForType
			controllerActionCallbacks.digitalDownSet = {}
		end
	else
		controllerActionCallbacksForType = controllerActionCallbacks.analog
		if not controllerActionCallbacksForType then
			controllerActionCallbacksForType = {}
			controllerActionCallbacks.analog = controllerActionCallbacksForType
		end
	end

	local callbacksForActionName = controllerActionCallbacksForType[actionName]

	if not callbacksForActionName then
		callbacksForActionName = {}
		controllerActionCallbacksForType[actionName] = callbacksForActionName
	end

	table.insert(callbacksForActionName, func)

	--mj:log("controllerActionCallbacksBySet:", controllerActionCallbacksBySet)
end

eventManager.vrControllerCodes = {
	LEFT_TRIGGER = 0,
	RIGHT_TRIGGER = 1,
	LEFT_TRACKPAD_TOUCH = 2,
	RIGHT_TRACKPAD_TOUCH = 3,
	LEFT_TRACKPAD_CLICK = 4,
	RIGHT_TRACKPAD_CLICK = 5,
	BUILD = 6,
	CANCEL = 7,
	TELEPORT = 8,
	TURN_LEFT = 9,
	TURN_RIGHT = 10,
	GRIP_LEFT = 11,
	GRIP_RIGHT = 12,
}
eventManager.vrControllerAnalogCodes = {
	LEFT_TRACKPAD = 0,
	LEFT_JOYSTICK = 1,
	RIGHT_TRACKPAD = 2,
	RIGHT_JOYSTICK = 3,
}

local bridge = nil
local listenerKeyChangedFunc = nil
local modalEventListener = nil

local timeSinceLastEvent = nil


local function callModalEventListener(functionName, ...)
	if modalEventListener then
		if modalEventListener[functionName] then
			modalEventListener[functionName](...)
		end
		return true
	end
	return false
end

function eventManager:hideMouse()
	if not bridge.mouseHidden then
		bridge.mouseHidden = true
		for i,func in ipairs(self.mouseHiddenChangedListeners) do
			func(true)
		end
	end
end

function eventManager:showMouse()
	if bridge.mouseHidden then
		bridge.mouseHidden = false
		for i,func in ipairs(self.mouseHiddenChangedListeners) do
			func(false)
		end
	end
end

local prevControllerActionSetIndex = nil

function eventManager:setControllerActionSetIndex(newSetIndex)
	if prevControllerActionSetIndex ~= newSetIndex then

		--mj:log("eventManager:setControllerActionSetIndex prev:", prevControllerActionSetIndex, " new:", newSetIndex)
		local callbacksForSet = controllerActionCallbacksBySet[prevControllerActionSetIndex]
		if callbacksForSet and callbacksForSet.digitalDownSet then
			for key,tf in pairs(callbacksForSet.digitalDownSet) do
				local callbacksForKey = callbacksForSet.digital[key]
				if callbacksForKey then
					for i, callback in ipairs(callbacksForKey) do
						if callback(false) then
							break
						end
					end
				end
				
				controllerMapping[prevControllerActionSetIndex].repeats[key] = nil
			end
			callbacksForSet.digitalDownSet = {}
		end

		prevControllerActionSetIndex = newSetIndex
		bridge:setControllerActionSetIndex(newSetIndex)
		
		for i,func in ipairs(self.gameOrMenuStateChangedListeners) do
			func(newSetIndex)
		end
	end
end

function eventManager:mouseHidden()
	return bridge.mouseHidden
end

function eventManager:getModKey()
	return bridge:getModKey()
end

function eventManager:getSecondModKey()
	return bridge:getSecondModKey()
end

function eventManager:addEventListenter(func, listenerTable)
    table.insert(listenerTable,func)
end

function eventManager:getPathForActionIconImage(actionSetIndex, actionKey)
	return bridge:getPathForActionIconImage(actionSetIndex, actionKey)
end

local function finishActiveEvents()
	--mj:error("finishActiveEvents:", downKeys)
	for code,mods in pairs(downKeys) do
		for modKeyOrZero,v in pairs(mods) do
			local modKey = modKeyOrZero
			if modKeyOrZero == 0 then
				modKey = nil
			end
			local modKey2 = nil
			if modKey then
				modKey2 = eventManager:getSecondModKey()
			end
			local mapIndexes = keyMapping:getMappingsForInput(code, modKey, modKey2)

			if mapIndexes then
				for i,func in ipairs(eventManager.keyChangedListeners) do
					func(false, mapIndexes, false)
					--[[if func(false, mapIndexes, false) then
						break
					end]]
				end
			end
		end
	end

	downKeys = {}
end


eventManager.textEntryListnerIdCounter = 1
function eventManager:setTextEntryListener(newListener, listenerKeyChangedFunc_, sendKeyEventsToAllListeners)

	if newListener then
		finishActiveEvents()
	end

	local hadListener = eventManager.textEntryListener
	
	eventManager.textEntryListener = newListener
	eventManager.textEntryListenerSendKeyEventsToAllListeners = sendKeyEventsToAllListeners

	if newListener and not hadListener then
		bridge:startTextEntry()
	elseif not newListener and hadListener then
		bridge:stopTextEntry()
	end

	if newListener then
		listenerKeyChangedFunc = listenerKeyChangedFunc_
		eventManager.textEntryListnerIdCounter = eventManager.textEntryListnerIdCounter + 1
		return eventManager.textEntryListnerIdCounter
	end
	return nil
end

function eventManager:removeTextEntryListener(textEntryListenerID)
	if textEntryListenerID == eventManager.textEntryListnerIdCounter then
		eventManager:setTextEntryListener(nil)
	end
end

function eventManager:setClipboardText(text)
	bridge:setClipboardText(text)
end

function eventManager:getClipboardText()
	return bridge:getClipboardText()
end

local function updateControllerIsPrimary(newControllerIsPrimary)
	if eventManager.controllerIsPrimary ~= newControllerIsPrimary then
		--mj:error("eventManager.controllerIsPrimary changed:", newControllerIsPrimary)
		eventManager.controllerIsPrimary = newControllerIsPrimary
		bridge.controllerIsPrimary = newControllerIsPrimary
		
		for i,func in ipairs(eventManager.controllerPrimaryChangedListeners) do
			func(newControllerIsPrimary)
		end
	end
end

-- called by engine


local function callDigitalCallbacks(setIndex, key, isDown)
	local callbacksForSet = controllerActionCallbacksBySet[setIndex]
	if callbacksForSet and callbacksForSet.digital then
		local callbacksForKey = callbacksForSet.digital[key]
		if callbacksForKey then
			if isDown then 
				callbacksForSet.digitalDownSet[key] = true
			else
				callbacksForSet.digitalDownSet[key] = nil
			end

			for i, callback in ipairs(callbacksForKey) do
				if callback(isDown) then
					break
				end
			end
		end
	end
end



local turboPhases = {
	{
		duration = 0.4,
		delay = 0.4,
	},
	{
		duration = 1.0,
		delay = 0.1,
	},
	{
		delay = 0.02,
	},
}

local inactivityCallback = nil

function eventManager:setInactivityCallback(inactivityCallback_)
	inactivityCallback = inactivityCallback_
end

function eventManager:update(dt)
	for i,setIndex in ipairs(sets) do
		if controllerMapping[setIndex].repeats then
			for key, timerInfo in pairs(controllerMapping[setIndex].repeats) do
				local newTimerValue = timerInfo.fireTimer + dt

				local currentDelay = turboPhases[timerInfo.phaseIndex].delay
				local currentDuration = turboPhases[timerInfo.phaseIndex].duration

				if newTimerValue >= currentDelay then
					if currentDuration then
						timerInfo.phaseTimer = timerInfo.phaseTimer + currentDelay
						if timerInfo.phaseTimer >= currentDuration then
							timerInfo.phaseIndex = timerInfo.phaseIndex + 1
							timerInfo.phaseTimer = timerInfo.phaseTimer - currentDuration
						end
					end

					newTimerValue = newTimerValue - currentDelay
					callDigitalCallbacks(setIndex, key, false)
					callDigitalCallbacks(setIndex, key, true)
				end
				timerInfo.fireTimer = newTimerValue
			end
		end
	end

	if timeSinceLastEvent then
		timeSinceLastEvent = timeSinceLastEvent + dt
		if inactivityCallback and timeSinceLastEvent > 1.0 then
			inactivityCallback(timeSinceLastEvent)
		end
	else
		timeSinceLastEvent = dt
	end
end

function eventManager:setBridge(bridge_)
    bridge = bridge_

	eventManager.controllerIsPrimary = bridge.controllerIsPrimary


	local function addDigitalControllerMap(setIndex, key, turboRepeat)
		if turboRepeat then
			if not controllerMapping[setIndex].repeats then
				controllerMapping[setIndex].repeats = {}
			end
		end
		controllerMapping[setIndex].digital[key] = function(isDown)
			timeSinceLastEvent = nil
			updateControllerIsPrimary(true)
			--mj:log("digital callback:", setIndex, " key:", key, " isDown:", isDown)

			callDigitalCallbacks(setIndex, key, isDown)

			if turboRepeat then
				if isDown then
					--mj:log("set repeat timer")
					controllerMapping[setIndex].repeats[key] = {
						fireTimer = 0.0,
						phaseTimer = 0.0,
						phaseIndex = 1,
					}
				else
					--mj:log("remove repeat timer")
					controllerMapping[setIndex].repeats[key] = nil
				end
			end
		end
	end

	local function addAnalogControllerMap(setIndex, key)
		controllerMapping[setIndex].analog[key] = function(pos)
			timeSinceLastEvent = nil
			--mj:log("analog callback:", setIndex, " key:", key)
			local callbacksForSet = controllerActionCallbacksBySet[setIndex]
			if callbacksForSet and callbacksForSet.analog then
				local callbacksForKey = callbacksForSet.analog[key]
				if callbacksForKey then
					for i, callback in ipairs(callbacksForKey) do
						callback(pos)
					end
				end
			end
		end
	end

	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuUp", true)
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuDown", true)
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuLeft", true)
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuRight", true)
	
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuTabLeft", true)
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuTabRight", true)

	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuSelect")
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuCancel")
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuSpecial") -- X
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuOther") -- Y
	
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuStart")
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuRightBumper", true)
	addDigitalControllerMap(eventManager.controllerSetIndexMenu, "menuLeftBumper", true)

	addAnalogControllerMap(eventManager.controllerSetIndexMenu, "radialMenuDirection")

	--
	
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "confirm")
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "cancel")
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "buildMenu") --X
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "other") --Y

	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "menuUp", true)
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "menuDown", true)
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "menuLeft", true)
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "menuRight", true)
	
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "pauseMenu")
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "speedDown", true)
	addDigitalControllerMap(eventManager.controllerSetIndexInGame, "speedUp", true)
	
	addAnalogControllerMap(eventManager.controllerSetIndexInGame, "move")
	addAnalogControllerMap(eventManager.controllerSetIndexInGame, "look")
	addAnalogControllerMap(eventManager.controllerSetIndexInGame, "zoomIn")
	addAnalogControllerMap(eventManager.controllerSetIndexInGame, "zoomOut")

	--mj:log("controllerMapping:", controllerMapping)

	bridge:setControllerMapping(controllerMapping)
	

end



function eventManager:textEntry(text)
	if callModalEventListener("textEntry", text) then
		return
	end
	if eventManager.textEntryListener then
		eventManager.textEntryListener(text)
	end
end


function eventManager:keyChanged(isDown, code, modKey, isRepeat)
	timeSinceLastEvent = nil

	local downKeysByCode = downKeys[code]
	if isDown then
		if not downKeysByCode then
			downKeysByCode = {}
			downKeys[code] = downKeysByCode
		end
		downKeysByCode[modKey or 0] = true
	elseif downKeysByCode then
		downKeysByCode[modKey or 0] = nil
		if not next(downKeysByCode) then
			downKeys[code] = nil
			downKeysByCode = nil
		end
	end

	updateControllerIsPrimary(false)
	if callModalEventListener("keyChanged", isDown, code, modKey, isRepeat) then
		return
	end

	local modKey2 = nil
	if modKey then
		modKey2 = eventManager:getSecondModKey()
	end


	local mapIndexes = keyMapping:getMappingsForInput(code, modKey, modKey2)
	
	--mj:log("modKey:", modKey, " modKey2:", modKey2, " mapIndexes:", mapIndexes)
	if mapIndexes then
		if eventManager.textEntryListener then
			if listenerKeyChangedFunc then
				listenerKeyChangedFunc(isDown, mapIndexes, isRepeat)
			end
			if not eventManager.textEntryListenerSendKeyEventsToAllListeners then
				return
			end
		end

		for i,func in ipairs(eventManager.keyChangedListeners) do
			if func(isDown, mapIndexes, isRepeat) then
				break
			end
		end
	end
end

local mainViewScale = 1.0

function eventManager:setUIScreenSize(virtualSize, mainViewScale_)
	--uIScreenSize = virtualSize
	mainViewScale = mainViewScale_
end

function eventManager:mouseMoved(position, relativeMovement, dt)
	timeSinceLastEvent = nil
	eventManager.mouseLocPixels = position
	eventManager.mouseLocUI = vec2(position.x / mainViewScale, position.y / mainViewScale)
	--[[mj:log("eventManager.mouseLocUI:", eventManager.mouseLocUI)
	mj:log("position:", position)
	mj:log("screenSize:", uIScreenSize)
	mj:log("mainViewScale:", mainViewScale)
	mj:log("position / mainViewScale:", vec2(position.x / mainViewScale, position.y / mainViewScale))]]

	if callModalEventListener("mouseMoved", position, relativeMovement, dt) then
		return
	end
	--local listenersCopy = mj:cloneTable(eventManager.mouseMovedListeners)
	for i,func in ipairs(eventManager.mouseMovedListeners) do
		if func(position, relativeMovement, dt) then
			break
		end
	end
end

function eventManager:mouseDown(position, buttonIndex, modKey)
	timeSinceLastEvent = nil
	if callModalEventListener("mouseDown", position, buttonIndex, modKey) then
		return
	end
	--local listenersCopy = mj:cloneTable(eventManager.mouseDownListeners)
	for i,func in ipairs(eventManager.mouseDownListeners) do
		if func(position, buttonIndex, modKey) then
			break
		end
	end
end

function eventManager:mouseUp(position, buttonIndex, modKey)
	timeSinceLastEvent = nil
	if callModalEventListener("mouseUp", position, buttonIndex, modKey) then
		return
	end
	--local listenersCopy = mj:cloneTable(eventManager.mouseUpListeners)
	for i,func in ipairs(eventManager.mouseUpListeners) do
		func(position, buttonIndex, modKey)
	end
end

function eventManager:mouseWheel(position, scrollChange, modKey)
	timeSinceLastEvent = nil
	if callModalEventListener("mouseWheel", position, scrollChange, modKey) then
		return
	end
	for i,func in ipairs(eventManager.mouseWheelListeners) do
		func(position, scrollChange, modKey)
	end
end

function eventManager:multiGesture(position, theta, dist, modKey)
	--unimplemented here, but this might currently be called. (doesn't on macbook trackads for some reason). theta is multigesture (touch event) rotation, and dist is pinch zoom
	--mj:log("touch:", theta, " dist:", dist)
end

function eventManager:vrControllerButtonDown(buttonIndex)
	timeSinceLastEvent = nil
	--local listenersCopy = mj:cloneTable(eventManager.mouseUpListeners)
	for i,func in ipairs(eventManager.vrControllerButtonDownListeners) do
		if func(buttonIndex) then
			break
		end
	end
end

function eventManager:vrControllerButtonUp(buttonIndex)
	timeSinceLastEvent = nil
	--local listenersCopy = mj:cloneTable(eventManager.mouseUpListeners)
	for i,func in ipairs(eventManager.vrControllerButtonUpListeners) do
		func(buttonIndex)
	end
end


function eventManager:vrControllerAnalogChanged(position, analogIndex)
	timeSinceLastEvent = nil
	--local listenersCopy = mj:cloneTable(eventManager.mouseUpListeners)
	for i,func in ipairs(eventManager.vrControllerAnalogChangedListeners) do
		func(position, analogIndex)
	end
end

function eventManager:setModalEventListener(modalEventListener_)
	modalEventListener = modalEventListener_
	if modalEventListener then
		bridge.mouseHidden = true
	else
		bridge.mouseHidden = false
	end
end

function eventManager:getMouseScreenFractionNonClamped()
	return bridge:getMouseScreenFractionNonClamped()
end
	
function eventManager:warpMouse(mouseLocUI)
	--mj:log("warpMouse:", mouseLocUI)
	bridge:warpMouse(vec2(mouseLocUI.x * mainViewScale, mouseLocUI.y * mainViewScale))
end

function eventManager:preventMouseWarpUntilAfterNextShow()
	bridge:preventMouseWarpUntilAfterNextShow()
end



function eventManager:appLostFocus()
	for i,func in ipairs(eventManager.appFocusChangedListeners) do
		func(false)
	end
end

function eventManager:appGainedFocus()
	for i,func in ipairs(eventManager.appFocusChangedListeners) do
		func(true)
	end
end

return eventManager