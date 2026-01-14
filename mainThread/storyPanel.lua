local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local audio = mjrequire "mainThread/audio"
local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"

local storyPanel = {}

local gameUI = nil
local hidden = true

local mainView = nil
local panelView = nil
local contentTextView = nil
local nextButton = nil

local slidingOffMainBanner = false
local slideBaseYOffset = 40.0
local slideAnimationOffset = -500.0
local slideAnimationTimer = 0.0

local panelWidth = 1000.0
local nextFunction = nil
local isFinal = false


local function callNextFunctionIfVisible()
    if (not hidden) and (not slidingOffMainBanner) and (not panelView.hidden) and (not panelView.update) and nextFunction then
        nextFunction()
        return true
    end
    return false
end

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            return callNextFunctionIfVisible()
        end 
        return false 
    end,
}

local function keyChanged(isDown, code, modKey, isRepeat)
    if keyMap[code]  then
		return keyMap[code](isDown, isRepeat)
	end
end

local function slideOn()
    slidingOffMainBanner = false
    panelView.baseOffset = vec3(0.0, slideAnimationOffset + slideBaseYOffset, 0)
    panelView.hidden = false
    audio:playUISound("audio/sounds/ui/stone.wav")
    panelView.update = function(dt_)
        slideAnimationTimer = slideAnimationTimer + dt_ * 4.0
        local fraction = slideAnimationTimer
        fraction = math.pow(fraction, 0.1)
        if fraction < 1.0 then
            panelView.baseOffset = vec3(0.0, slideAnimationOffset * (1.0 - fraction) + slideBaseYOffset, 0)
        else
            panelView.baseOffset = vec3(0.0, slideBaseYOffset, 0)
            panelView.update = nil
            slideAnimationTimer = 1.0
        end
    end
    gameUI:updateUIHidden()
end

local textToUpdate = nil

local function updateText()
    contentTextView.text = textToUpdate

    panelView.size = vec2(panelWidth, contentTextView.size.y + 120.0)
    local panelScale = vec2(panelView.size.x * 0.5, panelView.size.y * 0.5 / 0.2)
    panelView.scale3D = vec3(panelScale.x, panelScale.y, 30.0)

    if isFinal then
        uiStandardButton:setTextWithShortcut(nextButton, locale:get("ui_action_choose"), "game", "confirm", eventManager.controllerSetIndexInGame, "confirm")
    else
        uiStandardButton:setTextWithShortcut(nextButton, locale:get("ui_action_next"), "game", "confirm", eventManager.controllerSetIndexInGame, "confirm")
    end
end

local function slideOff()
    if not panelView.hidden then
        if not slidingOffMainBanner then
            slidingOffMainBanner = true
            audio:playUISound("audio/sounds/ui/stone.wav")
            panelView.update = function(dt_)
                slideAnimationTimer = slideAnimationTimer - dt_ * 4.0
                local fraction = slideAnimationTimer
                fraction = math.pow(fraction, 0.8)
                if fraction > 0.0 then
                    panelView.baseOffset = vec3(0.0, slideAnimationOffset * (1.0 - fraction) + slideBaseYOffset, 0)
                else
                    slideAnimationTimer = 0.0
                    if textToUpdate then
                        updateText()
                        slideOn()
                    else
                        panelView.update = nil
                        panelView.hidden = true
                    end
                end
            end
        end
    elseif textToUpdate then
        updateText()
        slideOn()
    end
end

function storyPanel:init(gameUI_)
    gameUI = gameUI_

    mainView = View.new(gameUI.storyView)
    mainView.size = gameUI.storyView.size
    
    panelView = ModelView.new(mainView)
    panelView:setModel(model:modelIndexForName("ui_panel_10x2"))
    panelView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    panelView.hidden = true
    
    panelView.keyChanged = keyChanged

    contentTextView = TextView.new(panelView)
    contentTextView.font = Font(uiCommon.fontName, 22)
    contentTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    contentTextView.baseOffset = vec3(40,-40,0)
    contentTextView.wrapWidth = panelWidth - 80.0

    
    nextButton = uiStandardButton:create(panelView, vec2(142,30))
    nextButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    nextButton.baseOffset = vec3(-20,20, 0.5)
    uiStandardButton:setTextWithShortcut(nextButton, locale:get("ui_action_next"), "game", "confirm", eventManager.controllerSetIndexInGame, "confirm")

    uiStandardButton:setClickFunction(nextButton, function()
        callNextFunctionIfVisible()
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "confirm", function(isDown)
        if isDown and (not hidden) then
            return callNextFunctionIfVisible()
        end
    end)
    
end

function storyPanel:show(text, isFinal_)
    textToUpdate = text
    isFinal = isFinal_
    slideOff()

    hidden = false
    gameUI:updateUIHidden()
end

function storyPanel:setHideOnClickOutside()
    panelView.clickDownOutside = function(buttonIndex)
        callNextFunctionIfVisible()
    end
end

function storyPanel:setNextFunction(func)
    nextFunction = func
end

function storyPanel:hide()
    hidden = true
    gameUI:updateUIHidden()
end

function storyPanel:hidden()
    return hidden
end

return storyPanel