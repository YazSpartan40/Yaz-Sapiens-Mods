local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local eventManager = mjrequire "mainThread/eventManager"
--local keyMapping = mjrequire "mainThread/keyMapping"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"

local locale = mjrequire "common/locale"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiTextEntry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"
local audio = mjrequire "mainThread/audio"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"

local chatMessageUI = {}

local logicInterface = nil

local mainView = nil
local titleView = nil
local playersOnlineTextView = nil
local textEntryView = nil

local messageViewInfos = {}

local displayMessagesMaxCount = 8
local fadeOutTimeAfterReceivingMessage = 10.0

local fadeOutTimer = 0.0

local messageViewSize = vec2(400,60)

local function updatePlayerCountText(currentPlayerCountOrNil)
    if (not currentPlayerCountOrNil) or currentPlayerCountOrNil <= 1 then
        playersOnlineTextView.text = locale:get("ui_info_noOtherPlayers")
    elseif currentPlayerCountOrNil == 2 then
        playersOnlineTextView.text = locale:get("ui_info_singleOtherPlayer")
    else
        playersOnlineTextView.text = locale:get("ui_info_multipleOtherPlayers", {playerCount = currentPlayerCountOrNil - 1})
    end
end

function chatMessageUI:load(gameUI, logicInterface_)
    logicInterface = logicInterface_
    mainView = View.new(gameUI.view)
    mainView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    mainView.size = gameUI.view.size
    mainView.hidden = true
    mainView.alpha = 0.0
    mainView.baseOffset = vec3(0.0,-70.0,0.0)


    titleView = ColorView.new(mainView)
    titleView.relativeView = mainView
    titleView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    titleView.baseOffset = vec3(12, -12, 0)
    titleView.size = messageViewSize
    titleView.color = vec4(0.0,0.0,0.0,0.8)

    local titleTextView = TextView.new(titleView)
    titleTextView.font = Font(uiCommon.consoleFontName, 13)
    titleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    titleTextView.wrapWidth = titleView.size.x - 8
    titleTextView.baseOffset = vec3(4,0, 0)
    titleTextView.text = string.lower(locale:get("ui_name_chat")) .. " "

    local chatKeyImage = uiKeyImage:create(mainView, 16, "game", "chat", eventManager.controllerSetIndexMenu, "menuLeftBumper", nil)
    chatKeyImage.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    chatKeyImage.relativeView = titleTextView

    playersOnlineTextView = TextView.new(titleView)
    playersOnlineTextView.font = Font(uiCommon.consoleFontName, 13)
    playersOnlineTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    playersOnlineTextView.relativeView = chatKeyImage
    playersOnlineTextView.wrapWidth = titleView.size.x - 8
    playersOnlineTextView.baseOffset = vec3(4,0, 0)
    updatePlayerCountText(1)

    titleView.size = vec2(titleView.size.x, titleTextView.size.y + 8)

    mainView.update = function(dt)
        if (not textEntryView.hidden) then
            fadeOutTimer = 0.0
        else
            fadeOutTimer = fadeOutTimer + dt
        end

        if fadeOutTimer < fadeOutTimeAfterReceivingMessage then
            mainView.hidden = false
            if mainView.alpha < 1.0 then 
                mainView.alpha = mainView.alpha + dt * 4.0
                if mainView.alpha > 1.0 then
                    mainView.alpha = 1.0
                end
            end
        else
            if not mainView.hidden then
                mainView.alpha = mainView.alpha - dt
                if mainView.alpha <= 0.0 then
                    mainView.alpha = 0.0
                    mainView.hidden = true
                end
            end
        end
    end


    local textEntrySize = vec2(messageViewSize.x,24.0)
    textEntryView = uiTextEntry:create(mainView, textEntrySize, uiTextEntry.types.chatInput, MJPositionInnerLeft)
    uiTextEntry:setMaxChars(textEntryView, 200)

    textEntryView.relativeView = titleView
    textEntryView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    textEntryView.baseOffset = vec3(0, -2, 0)

    uiTextEntry:setPromptText(textEntryView, string.lower(locale:get("ui_name_chat")) .. ": ", mj.highlightColor)

    --textEntryView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    --textEntryView.relativeView = reportListView
    --textEntryView.baseOffset = vec3(0, 14, 0)
    uiTextEntry:setAllowsEmpty(textEntryView, true)
    uiTextEntry:setText(textEntryView, "")
    uiTextEntry:setFunction(textEntryView, function(input, confirmChanges)
        if confirmChanges then
            uiTextEntry:clearText(textEntryView)
            chatMessageUI:sendMessage(input)
        end
        textEntryView.hidden = true

        --[[local newSearchTextToUse = newSearchText
        if newSearchTextToUse == "" then
            newSearchTextToUse = nil
        end
        searchText = newSearchTextToUse
        updateList()]]
    end)
    textEntryView.hidden = true
    
end

function chatMessageUI:displayMessage(messageInfo, isStateChangeMessage)
    

    local function attachToMainView(messageViewToAttach)
        messageViewToAttach.relativeView = titleView
        messageViewToAttach.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
        messageViewToAttach.baseOffset = vec3(0, -2, 0)
    end

    local messageView = ColorView.new(mainView)
    attachToMainView(messageView)

    if #messageViewInfos > 0 then
        messageView.relativeView = messageViewInfos[#messageViewInfos].view
        messageViewInfos[#messageViewInfos].dependentView = messageView
        messageView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
        messageView.baseOffset = vec3(0, -2, 0)
    end

    messageView.size = messageViewSize
    messageView.color = vec4(0.0,0.0,0.0,0.8)

    local textView = TextView.new(messageView)
    textView.font = Font(uiCommon.consoleFontName, 13)
    textView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    textView.wrapWidth = messageView.size.x - 8
    textView.baseOffset = vec3(4,0, 0)

    local playerColor = mj.otherPlayerColor

    local promptText = nil
    local messageColor = playerColor
    if isStateChangeMessage then
        promptText = (messageInfo.clientName or "no name") .. " "
    else
        messageColor = vec4(1.0,1.0,1.0, 1.0)
        promptText = (messageInfo.clientName or "no name") .. ": "
    end

    textView:addColoredText(promptText, playerColor)
    textView:addColoredText(messageInfo.text, messageColor)

    --[[for i = 1, #messageInfo.text do
        local c = messageInfo.text:sub(i,i)
        local randomColor = rng:vecForUniqueID(32, i)
        randomColor = randomColor * 0.5 + vec3(0.5,0.5,0.5);
        textView:addColoredText(c, vec4(randomColor.x, randomColor.y, randomColor.z, 1.0))
    end]]

    local messageViewInfo = {
        view = messageView,
        index = #messageViewInfos + 1,
        fadeOutTimer = 0.0,
    }

    textEntryView.relativeView = messageView
    messageViewInfo.dependentView = textEntryView
    textEntryView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    textEntryView.baseOffset = vec3(0, -2, 0)

    table.insert(messageViewInfos, messageViewInfo)

    if #messageViewInfos > displayMessagesMaxCount then
        local messageViewInfoToRemove = messageViewInfos[#messageViewInfos - displayMessagesMaxCount]
        messageViewInfoToRemove.view.update = function(dt)
            messageViewInfoToRemove.fadeOutTimer = messageViewInfoToRemove.fadeOutTimer + dt
            local dependentView = messageViewInfoToRemove.dependentView
            if messageViewInfoToRemove.fadeOutTimer < 1.0 then
                messageViewInfoToRemove.view.alpha = math.max(1.0 - messageViewInfoToRemove.fadeOutTimer * 2.0, 0.0);
                if dependentView and messageViewInfoToRemove.fadeOutTimer > 0.5 then
                    local offsetMix = (messageViewInfoToRemove.fadeOutTimer - 0.5) * 2.0
                    dependentView.baseOffset = vec3(0, mjm.mix(-2, messageViewInfoToRemove.view.size.y, offsetMix), 0)
                end
            else
                if dependentView then
                    attachToMainView(dependentView)
                end
                mainView:removeSubview(messageViewInfoToRemove.view)
                for i = messageViewInfoToRemove.index, #messageViewInfos - 1 do
                    messageViewInfos[i] = messageViewInfos[i + 1]
                    messageViewInfos[i].index = messageViewInfos[i].index - 1
                end
                table.remove(messageViewInfos, #messageViewInfos)
            end
        end
    end

    messageView.size = vec2(messageView.size.x, textView.size.y + 8)
    
    if clientGameSettings.values.chatNotifications == "enabled" or (isStateChangeMessage and clientGameSettings.values.chatNotifications == "messagesOnly") then
        chatMessageUI:show()
        audio:playUISound("audio/sounds/chat.wav", 0.5)
    end
end

function chatMessageUI:displayClientStateChange(messageInfo)
    updatePlayerCountText(messageInfo.playerCount)

    if not messageInfo.isLocalPlayer then
        if messageInfo.type == "connected" then
            messageInfo.text = string.lower(locale:get("ui_name_connected"))
        elseif messageInfo.type == "disconnected" then
            messageInfo.text = string.lower(locale:get("ui_name_disconnected"))
        elseif messageInfo.type == "hibernated" then
            messageInfo.text = string.lower(locale:get("ui_name_hibernated"))
        end
        chatMessageUI:displayMessage(messageInfo, true)
    end
end

function chatMessageUI:sendMessage(input)
    if logicInterface:ready() then
        logicInterface:callServerFunction("sendChatMessage", {text = input})
    end
end

--[[chatMessageUI.keyMap = {
	[keyMapping:getMappingIndex("textEntry", "send")] = function(isDown, isRepeat) if isDown and not isRepeat then chatMessageUI:sendMessage() return true end end,
	[keyMapping:getMappingIndex("textEntry", "backspace")] = function(isDown, isRepeat) if isDown then backspacePressed() end end,

	[keyMapping:getMappingIndex("textEntry", "cursorLeft")] = function(isDown, isRepeat) if isDown then cursorChanged(-1) end end,
	[keyMapping:getMappingIndex("textEntry", "cursorRight")] = function(isDown, isRepeat) if isDown then cursorChanged(1) end end,

	--[keyMapping:getMappingIndex("game", "escape")] = function(isDown, isRepeat) if isDown and not isRepeat then controller:resumeGameAndHideTerminal() end end,
}]]

--[[local function keyChanged(isDown, mapIndexes, isRepeat)
    for i,mapIndex in ipairs(mapIndexes) do
        if chatMessageUI.keyMap[mapIndex]  then
            return chatMessageUI.keyMap[mapIndex](isDown, isRepeat)
        end
    end
end]]

--[[function chatMessageUI:textEntry(text)
    
end]]

function chatMessageUI:show()
    fadeOutTimer = 0.0
    mainView.hidden = false
end

function chatMessageUI:showWithTextEntryActive()
    chatMessageUI:show()
    textEntryView.hidden = false
    uiTextEntry:callClickFunction(textEntryView)

    --[[eventManager:setTextEntryListener(function(text) 
        chatMessageUI:textEntry(text)
    end, keyChanged)]]
end

--[[function chatMessageUI:setChatTextEntryActive(newActive)
    chatTextEntryActive = newActive
    if newActive then
        mainView.hidden = false
    end
end]]

return chatMessageUI