local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"
--local logicInterface = mjrequire "mainThread/logicInterface"
--local chatMessageUI = mjrequire "mainThread/ui/chatMessageUI"
local timer = mjrequire "common/timer"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"

local terminal = {
    hidden = true
}
local controller = nil

local cursorOffset = 0

terminal.maxLines = 10
terminal.view = nil
terminal.inputLine = nil
terminal.lastLine = nil
terminal.lines = {}
terminal.history = {}
terminal.historyEditing = {""}
terminal.historyIndex = 1

terminal.background = nil
terminal.totalHeight = 0

terminal.font = Font(uiCommon.consoleFontName, 18)

local function getPromptName()
    return "lua>"
end

function terminal:updateInputString()
    local inputWithPrompt = getPromptName() .. terminal.historyEditing[terminal.historyIndex] .. "_"
    terminal.inputLine.text = inputWithPrompt
end

function terminal:textEntry(text)
    terminal.historyEditing[terminal.historyIndex] = terminal.historyEditing[terminal.historyIndex] .. text
    if #terminal.historyEditing[terminal.historyIndex] > 150 then
        terminal.historyEditing[terminal.historyIndex] = terminal.historyEditing[terminal.historyIndex]:sub(1,150)
    end
    terminal:updateInputString()
end

function terminal:addLine(text)
    local newLine = TextView.new(terminal.view)
    newLine.font = terminal.font
    newLine.text = text
    newLine.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionAbove)
    newLine.relativeView = terminal.inputLine


    if terminal.lastLine then
        terminal.lastLine.relativeView = newLine
    end
    terminal.lastLine = newLine

    table.insert(terminal.lines, newLine)
    if #terminal.lines > terminal.maxLines then
        local eraseLine = terminal.lines[1]
        table.remove(terminal.lines, 1)
        terminal.view:removeSubview(eraseLine)
    else
        terminal.totalHeight = terminal.totalHeight + newLine.size.y
        terminal.background.size = vec2(terminal.background.size.x, terminal.totalHeight)
    end
end

function terminal:sendCommand()
    local input = terminal.historyEditing[terminal.historyIndex]
    local inputWithPromptForHistory = getPromptName() .. input
    terminal:addLine(inputWithPromptForHistory)

    local loaded, loadError = loadstring(input)
    if not loaded then
        mj:log("ERROR:", loadError)
    else
        local status, error = pcall(loaded)
        if status == false then
            mj:log("ERROR: " .. mj:tostring(error))
        end
    end

    table.insert(terminal.history, input)
    terminal.historyEditing = mj:cloneTable(terminal.history)
    table.insert(terminal.historyEditing, "")
    terminal.historyIndex = #terminal.historyEditing

    --[[if not terminal.luaPrompt then
        if input == "/lua" then
            terminal.luaPrompt = true
            mj:log("type /exit to exit lua")
        else
            if logicInterface:ready() then
                logicInterface:callServerFunction("sendChatMessage", {text = input})
            end
        end
        terminal.historyEditing[terminal.historyIndex] = ""
    else
        if input == "/exit" then
            terminal.luaPrompt = false
            terminal.historyEditing[terminal.historyIndex] = ""
        else
            local status, error = pcall(loadstring(input))
            if status == false then
                mj:log("ERROR: " .. mj:tostring(error))
            end

            table.insert(terminal.history, input)
            terminal.historyEditing = mj:cloneTable(terminal.history)
            table.insert(terminal.historyEditing, "")
            terminal.historyIndex = #terminal.historyEditing
        end
    end]]

    terminal:updateInputString()

end

local function backspacePressed()
    local currentString = terminal.historyEditing[terminal.historyIndex]
    if currentString and string.len(currentString) > 0 then
        terminal.historyEditing[terminal.historyIndex] = currentString:sub(1, -2)
        terminal:updateInputString()
    end
end

local function prevCommand()
    if terminal.historyIndex > 1 then
        terminal.historyIndex = terminal.historyIndex - 1
        terminal:updateInputString()
    end
end

local function nextCommand()
    if terminal.historyIndex < #terminal.historyEditing then
        terminal.historyIndex = terminal.historyIndex + 1
        terminal:updateInputString()
    end
end

local function cursorChanged(offset) --cursor not rendered yet
    cursorOffset = cursorOffset + offset
    local currentString = terminal.historyEditing[terminal.historyIndex]
    cursorOffset = mjm.clamp(cursorOffset, -1 - string.len(currentString), -1)
end

terminal.keyMap = {
	[keyMapping:getMappingIndex("textEntry", "send")] = function(isDown, isRepeat) if isDown and not isRepeat then terminal:sendCommand() return true end end,
	[keyMapping:getMappingIndex("textEntry", "backspace")] = function(isDown, isRepeat) if isDown then backspacePressed() end end,
    
	[keyMapping:getMappingIndex("textEntry", "prevCommand")] = function(isDown, isRepeat) if isDown then prevCommand() end end,
	[keyMapping:getMappingIndex("textEntry", "nextCommand")] = function(isDown, isRepeat) if isDown then nextCommand() end end,
	[keyMapping:getMappingIndex("textEntry", "cursorLeft")] = function(isDown, isRepeat) if isDown then cursorChanged(-1) end end,
	[keyMapping:getMappingIndex("textEntry", "cursorRight")] = function(isDown, isRepeat) if isDown then cursorChanged(1) end end,

	[keyMapping:getMappingIndex("game", "escape")] = function(isDown, isRepeat) if isDown and not isRepeat then controller:resumeGameAndHideTerminal() end end,
    [keyMapping:getMappingIndex("debug", "reload")] = function(isDown, isRepeat)
		if isDown and not isRepeat then 
            controller:reloadAll(nil)
            return true
		end 
    end,
}

local function keyChanged(isDown, mapIndexes, isRepeat)
    for i,mapIndex in ipairs(mapIndexes) do
        if terminal.keyMap[mapIndex]  then
            return terminal.keyMap[mapIndex](isDown, isRepeat)
        end
    end
end

function terminal:displayMessage(message) --if anything calls mjlog() from here, you're gonna have a bad time
    terminal:addLine(message)
end


function terminal:load(controller_)
    controller = controller_
    terminal.view = View.new(controller.mainView)
    terminal.view.size = vec2(controller.mainView.size.x, 0)

    terminal.background = ColorView.new(terminal.view)
    terminal.background.size = terminal.view.size
    terminal.background.color = vec4(0.0,0.0,0.0,0.6)
    terminal.background.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)

    terminal.inputLine = TextView.new(terminal.view)
    terminal.inputLine.font = terminal.font
    terminal.inputLine.text = getPromptName() .. "_"
    terminal.inputLine.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)

    terminal.totalHeight = terminal.inputLine.size.y + 4

    terminal:addLine("Welcome to " .. mj.gameName .. ".")

    table.insert(terminal.historyEditing, "")
    --view.keyChanged = keyChanged

    --[[local oldMJLogFunction = mj.log
    mj.log = function(selfObject, ...)
        
        local string = ""
        local count = select("#",...)
        for i = 1,count do
            string = string .. mj:tostring(select(i,...), 0)
        end
        oldMJLogFunction(selfObject, string)
        terminal:displayMessage(string)
    end]]
    
    terminal.hidden = true
    terminal.view.hidden = true

    mj.terminal = terminal
end

function terminal:show()
    if terminal.hidden then
        terminal.view.size = controller.mainView.size
        timer:addCallbackTimer(0.01, function() --hacky calback to avoid displaying any text events that may have caused the terminal to be displayed eg. via C key shortcut
            terminal.hidden = false
            terminal.view.hidden = false
            eventManager:setTextEntryListener(function(text) 
                terminal:textEntry(text)
            end, keyChanged)
            --chatMessageUI:setChatTextEntryActive(true)
        end)
    end
end

function terminal:hide()
    if not terminal.hidden then
        terminal.hidden = true
        terminal.view.hidden = true
        eventManager:setTextEntryListener(nil)
        --chatMessageUI:setChatTextEntryActive(false)
    end
end

function terminal:toggleHidden()
    if terminal.hidden then
        terminal:show()
    else
        terminal:hide()
    end
end

return terminal