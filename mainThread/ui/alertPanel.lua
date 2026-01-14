local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local keyMapping = mjrequire "mainThread/keyMapping"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local eventManager = mjrequire "mainThread/eventManager"

local alertPanel = {}

local controller = nil
local mainView = nil
local parentView = nil
local confirmFunction = nil
local cancelFunction = nil

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and (not isRepeat) then 
            if confirmFunction then
                confirmFunction()
            end
            alertPanel:hide() 
        end 
        return true 
    end,
    [keyMapping:getMappingIndex("game", "escape")] = function(isDown, isRepeat) 
        if isDown and (not isRepeat) then 
            if cancelFunction then
                cancelFunction()
            end
            alertPanel:hide() 
        end 
        return true 
    end,
}

local function keyChanged(isDown, code, modKey, isRepeat)
    if isRepeat then
        return false
    end
    if keyMap[code]  then
		return keyMap[code](isDown, isRepeat)
	end
end

function alertPanel:show(parentView_, title, message, buttons, optionsOrNil)
    parentView = parentView_

    mainView = ColorView.new(parentView)
    mainView.size = controller.screenSize
    mainView.color = vec4(0.0,0.0,0.0,0.9)

    mainView.keyChanged = keyChanged

    local width = (optionsOrNil and optionsOrNil.width) or 540

    local backgroundSize = vec2(width, 200)
    
    local backgroundView = ModelView.new(mainView)
    backgroundView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    backgroundView.baseOffset = vec3(0, 0, 20)
    

    --[[local alertView = uiCommon:createBackgroundView(mainView, "img/ui/uiBoxSmall.png", 4.0)
    local alertViewSize = vec2(540, 200)
    uiCommon:resizeBackgroundView(alertView, alertViewSize)]]


    local titleText = ModelTextView.new(backgroundView)
    titleText.font = Font(uiCommon.titleFontName, 24)
    titleText.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleText.baseOffset = vec3(0,-6,0)
    titleText:setText(title, material.types.standardText.index)

    local messageText = TextView.new(backgroundView)
    messageText.font = Font(uiCommon.fontName, 18)
    messageText.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    messageText.baseOffset = vec3(0,-60,0)
    messageText.color = mj.textColor
    messageText.wrapWidth = backgroundSize.x - 40
    messageText.textAlignment = MJHorizontalAlignmentCenter
    messageText.size = vec2(messageText.wrapWidth, backgroundSize.y * 0.5)
    messageText.text = message

    --mj:log("messageText.size.y:", messageText.size.y)
    
    backgroundSize = vec2(backgroundSize.x, math.max(backgroundSize.y, messageText.size.y + 140))
    backgroundView.size = backgroundSize
    local scaleToUseX = backgroundSize.x * 0.5
    local scaleToUseY = backgroundSize.y * 0.5 / (9.0/16.0)
    backgroundView.scale3D = vec3(scaleToUseX, scaleToUseY, scaleToUseX)

    local buttonCollection = View.new(backgroundView)
    buttonCollection.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)

    local prevButtonView = nil
    local buttonViewWidth = 0

    local buttonSize = vec2(142,30)

    confirmFunction = nil
    cancelFunction = nil

    for i,buttonInfo in ipairs(buttons) do

        local buttonView = uiStandardButton:create(buttonCollection, buttonSize)
        if prevButtonView then
            buttonView.relativeView = prevButtonView
            buttonView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
            buttonView.baseOffset = vec3(-20, 0,0)
            buttonViewWidth = buttonViewWidth + 20
        else
            buttonView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
        end
        
        uiStandardButton:setClickFunction(buttonView, buttonInfo.action)

        if buttonInfo.isDefault then
            confirmFunction = buttonInfo.action
            uiStandardButton:setTextWithShortcut(buttonView, buttonInfo.name, "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
        elseif buttonInfo.isCancel then
            cancelFunction = buttonInfo.action
            uiStandardButton:setTextWithShortcut(buttonView, buttonInfo.name, "game", "escape", eventManager.controllerSetIndexMenu, "menuCancel")
        else
            uiStandardButton:setText(buttonView, buttonInfo.name)
        end

        prevButtonView = buttonView
        buttonViewWidth = buttonViewWidth + buttonSize.x
    end

    buttonCollection.size = vec2(buttonViewWidth,80)
end


function alertPanel:hide()
    if mainView then
        parentView:removeSubview(mainView)
        mainView = nil
    end
end

function alertPanel:hidden()
    return mainView == nil
end

function alertPanel:init(controller_)
    controller = controller_
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if mainView and isDown then
            if confirmFunction then
                confirmFunction()
            end
            alertPanel:hide() 
            return true
        end
    end)


    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuCancel", function(isDown)
        if mainView and isDown then
            if cancelFunction then
                cancelFunction()
            end
            alertPanel:hide() 
            return true
        end
    end)
end

return alertPanel