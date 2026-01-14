local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

--local gameObject = mjrequire "common/gameObject"
local model = mjrequire "common/model"
local material = mjrequire "common/material"

local locale = mjrequire "common/locale"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local audio = mjrequire "mainThread/audio"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local alertPanel = mjrequire "mainThread/ui/alertPanel"
local timer = mjrequire "common/timer"
--local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local keyMapping = mjrequire "mainThread/keyMapping"


local tutorialStoryPanel = {}

--local notificationsUI = nil
local mainView = nil
local iconGameObjectView = nil
local backgroundView = nil

local titleTextView = nil
local descriptionTextView = nil
local skipTutorialButton = nil

local circleSize = 100.0
local circleOffsetYFromTop = 60
local titleTextViewPaddingYFromTop = 5
local standardPaddingYFromTop = 30
local paddingX = 40
local tutorialSkipChangedFunction = nil

--local infoViewWidthMultiplier = 0.6

local hubUI = nil
local world = nil
local gameUI = nil

local backgroundSize = vec2(640, 480)

local disableCloseDueToJustDisplayed = false

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            tutorialStoryPanel:popUI()
        end 
        return true 
    end,
}

local function keyChanged(isDown, code, modKey, isRepeat)
    if keyMap[code]  then
		return keyMap[code](isDown, isRepeat)
	end
end

local function updateTipType(tipType)
    local storyPanelInfo = tipType.storyPanel

    if storyPanelInfo.iconImage then
        uiGameObjectView:setModelName(iconGameObjectView, storyPanelInfo.iconImage, nil)
    else
        uiGameObjectView:setObject(iconGameObjectView, {objectTypeIndex = storyPanelInfo.iconGameObjectTypeIndex}, nil, nil)
    end

    titleTextView:setText(tipType.title, material.types.standardText.index)
    descriptionTextView.text = storyPanelInfo.description

    local panelHeight = circleSize + circleOffsetYFromTop + 200 + descriptionTextView.size.y
    local adjustedBackgroundSize = vec2(backgroundSize.x, panelHeight)
    backgroundView.size = adjustedBackgroundSize
    local scaleToUseX = adjustedBackgroundSize.x * 0.5
    local scaleToUseY = adjustedBackgroundSize.y * 0.5 / (9.0/16.0)
    backgroundView.scale3D = vec3(scaleToUseX, scaleToUseY, scaleToUseX)

    
    if tipType.hideSkipButton then
        skipTutorialButton.hidden = true
    else
        skipTutorialButton.hidden = false
    end
end


function tutorialStoryPanel:load(gameUI_, hubUI_, world_)
    world = world_
    hubUI = hubUI_
    gameUI = gameUI_
    
    mainView = View.new(gameUI.view)
    mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    mainView.size = gameUI.view.size
    mainView.hidden = true
    mainView.keyChanged = keyChanged

    backgroundView = ModelView.new(mainView)
    backgroundView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    --infoView.relativeView = circleView
    backgroundView.baseOffset = vec3(0, 0, -2)
    backgroundView.size = backgroundSize
    local scaleToUse = backgroundSize.x * 0.5
    backgroundView.scale3D = vec3(scaleToUse, scaleToUse, scaleToUse)

    iconGameObjectView = uiGameObjectView:create(backgroundView, vec2(circleSize,circleSize), uiGameObjectView.types.backgroundCircle)
    iconGameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    iconGameObjectView.baseOffset = vec3(0, -circleOffsetYFromTop, 2)

    local tutorialTitleTextView = ModelTextView.new(backgroundView)
    tutorialTitleTextView.font = Font(uiCommon.titleFontName, 24)
    tutorialTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    tutorialTitleTextView.baseOffset = vec3(0,-6, 0)
    tutorialTitleTextView:setText(locale:get("ui_name_tutorial"), material.types.standardText.index)

    titleTextView = ModelTextView.new(backgroundView)
    titleTextView.font = Font(uiCommon.titleFontName, 48)
    titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    titleTextView.relativeView = iconGameObjectView
    titleTextView.baseOffset = vec3(0,-titleTextViewPaddingYFromTop,0)

    descriptionTextView = TextView.new(backgroundView)
    descriptionTextView.font = Font(uiCommon.fontName, 20)
    descriptionTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    descriptionTextView.relativeView = titleTextView
    descriptionTextView.baseOffset = vec3(0,-standardPaddingYFromTop,0)
    descriptionTextView.wrapWidth = backgroundView.size.x - (paddingX * 2)

    local okButton = uiStandardButton:create(backgroundView, vec2(200, 40))
    okButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    okButton.relativeView = descriptionTextView
    --okButton.baseOffset = vec3(100.0 + 10.0,-40, 0)
    okButton.baseOffset = vec3(0.0,-40, 0)
    uiStandardButton:setTextWithShortcut(okButton, locale:get("ui_action_continue"), "game", "confirm", nil, nil)
    uiStandardButton:setClickFunction(okButton, function()
        tutorialStoryPanel:popUI()
    end)
    
    skipTutorialButton = uiStandardButton:create(backgroundView, vec2(200, 40), uiStandardButton.types.linkSmall)
    skipTutorialButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    skipTutorialButton.baseOffset = vec3(10,10,0)
    --skipTutorialButton.relativeView = okButton
    --skipTutorialButton.baseOffset = vec3(-100.0 - 10.0,-40, 0)
    uiStandardButton:setText(skipTutorialButton, locale:get("tutorial_skip"))
    uiStandardButton:setClickFunction(skipTutorialButton, function()
        alertPanel:show(mainView, locale:get("tutorial_skip"), locale:get("tutorial_skipAreYouSure"), {
            {
                isDefault = true,
                name = locale:get("tutorial_skip"),
                action = function()
                    alertPanel:hide()
                    tutorialStoryPanel:hide()
                    if tutorialSkipChangedFunction then
                        tutorialSkipChangedFunction(true)
                    end
                    --local clientWorldSettingsDatabase = world:getClientWorldSettingsDatabase()
                    --clientWorldSettingsDatabase:setDataForKey(true, "tutorialSkipped")
                    --tutorialUI:skipTutorialSettingChanged(true)
                end
            },
            {
                isCancel = true,
                name = locale:get("ui_action_cancel"),
                action = function()
                    alertPanel:hide()
                end
            }
        })
    end)
    
    local closeButton = uiStandardButton:create(backgroundView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        tutorialStoryPanel:popUI()
    end)

end


function tutorialStoryPanel:setFunctionForSkipTutorialChange(changeFunction)
    tutorialSkipChangedFunction = changeFunction
end

function tutorialStoryPanel:show(tipType)

    disableCloseDueToJustDisplayed = true
    timer:addCallbackTimer(0.5, function()
        disableCloseDueToJustDisplayed = false
    end)
    
    audio:playUISound("audio/sounds/events/tutorial.wav", 0.3, nil)

    updateTipType(tipType)
    mainView.hidden = false
    hubUI:hideAllUI(false)
    world:startTemporaryPauseForPopup()
end
    
function tutorialStoryPanel:hide()
    if not mainView.hidden then
        tutorialUI:resetDelayTimer()
        world:endTemporaryPauseForPopup()
        mainView.hidden = true
        gameUI:updateUIHidden()
    end
    --notificationsUI:discoveryUIHidden()
end

function tutorialStoryPanel:popUI()
    if disableCloseDueToJustDisplayed then
        --mj:log("tutorialStoryPanel:popUI ignored due to only just being displayed")
        disableCloseDueToJustDisplayed = false
        return true
    else
        tutorialStoryPanel:hide()
    end
    return false
end

function tutorialStoryPanel:hidden()
    return mainView.hidden
end

return tutorialStoryPanel