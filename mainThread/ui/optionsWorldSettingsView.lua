local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

--local model = mjrequire "common/model"
--local material = mjrequire "common/material"
local locale = mjrequire "common/locale"

local gameConstants = mjrequire "common/gameConstants"
--local eventManager = mjrequire "mainThread/eventManager"
--local keyMapping = mjrequire "mainThread/keyMapping"
local logicInterface = mjrequire "mainThread/logicInterface"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiPopUpButton = mjrequire "mainThread/ui/uiCommon/uiPopUpButton"
local uiSlider = mjrequire "mainThread/ui/uiCommon/uiSlider"

local optionsWorldSettingsView = {}

--"getWorldSettings"

local tribeSpawnButton = nil
local autoRoleAssignmentToggleButton = nil
local difficultySelectionPopUpButton = nil
local populationCapSlider = nil
local populationCapSliderTextValueView = nil

local world = nil


local modeNameList = {}
local difficultyModes = {
    {
        name = locale:get("worldSettings_gameDifficulty_normal"),
        key = "normal",
    },
    {
        name = locale:get("worldSettings_gameDifficulty_peaceful"),
        key = "peaceful",
    },
}
for i,mode in ipairs(difficultyModes) do
    table.insert(modeNameList, mode.name)
end


local function updatePopulationCapText(newValue)
    if newValue and newValue < gameConstants.populationLimitPerTribeSoftCap then
        populationCapSliderTextValueView.text = string.format("%d", newValue)
    else
        populationCapSliderTextValueView.text = string.format("%d", gameConstants.populationLimitPerTribeSoftCap)
    end
end

function optionsWorldSettingsView:update()
    if tribeSpawnButton then
        local function setUIDisabled(disabled)
            uiStandardButton:setDisabled(tribeSpawnButton, disabled)
        end

        setUIDisabled(true)

        logicInterface:callServerFunction("getWorldSettings", nil, function(result)

            --mj:log("optionsWorldSettingsView result:", result)
            uiStandardButton:setToggleState(tribeSpawnButton, (not result.disableTribeSpawns))

            local gameModeSelectionIndex = 1
            if result.gameDifficulty then
                for i,mode in ipairs(difficultyModes) do
                    if mode.key == result.gameDifficulty then
                        gameModeSelectionIndex = i
                        break
                    end
                end
            end
            uiPopUpButton:setSelection(difficultySelectionPopUpButton, gameModeSelectionIndex)

            if result.populationCap then
                updatePopulationCapText(result.populationCap)
                uiSlider:setValue(populationCapSlider, result.populationCap)
            else
                updatePopulationCapText(nil)
                uiSlider:setValue(populationCapSlider, gameConstants.populationLimitPerTribeSoftCap)
            end

            setUIDisabled(false)
        end)

        uiStandardButton:setToggleState(autoRoleAssignmentToggleButton, world:getAutoRoleAssignmentEnabled())
    end
end

function optionsWorldSettingsView:create(world_, mainParentView, elementYOffset)
    world = world_

    local yOffsetBetweenElements = 35
    local elementTitleX = -mainParentView.size.x * 0.5 - 10
    local elementControlX = mainParentView.size.x * 0.5

    local function addToggleButton(parentView, toggleButtonTitle, tipText, toggleValue, changedFunction)
        local toggleButton = uiStandardButton:create(parentView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        toggleButton.baseOffset = vec3(elementControlX, elementYOffset, 0)
        uiStandardButton:setToggleState(toggleButton, toggleValue)
        
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = toggleButtonTitle

        if tipText then
            uiToolTip:add(toggleButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), tipText, nil, vec3(0,-8,10), nil, toggleButton, parentView)
        end
    
        uiStandardButton:setClickFunction(toggleButton, function()
            changedFunction(uiStandardButton:getToggleState(toggleButton))
        end)

        elementYOffset = elementYOffset - yOffsetBetweenElements
        
        uiSelectionLayout:addView(parentView, toggleButton)
        return toggleButton
    end

    
    local buttonSize = vec2(200, 40)
    local popUpMenuSize = vec2(240, 180)

    local function addPopUpButton(parentView, popOversView, popUpTitle, itemList, selectionFunction)
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = popUpTitle

        local button = uiPopUpButton:create(parentView, popOversView, buttonSize, popUpMenuSize)
        button.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        button.baseOffset = vec3(elementControlX + 4, elementYOffset + 6, 0)
        uiPopUpButton:setItems(button, itemList)
        uiPopUpButton:setSelection(button, 1)
        uiPopUpButton:setSelectionFunction(button, selectionFunction)

        elementYOffset = elementYOffset - yOffsetBetweenElements
        uiSelectionLayout:addView(parentView, button)

        return button
    end

    
    local function addSlider(parentView, sliderTitle, tipText, min, max, value, changedFunction, continuousFunctionOrNil)
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = sliderTitle

        local options = nil
        local baseFunction = changedFunction
        if continuousFunctionOrNil then
            options = {
                continuous = true,
                releasedFunction = changedFunction
            }
            baseFunction = continuousFunctionOrNil
        end
        
        local sliderView = uiSlider:create(parentView, vec2(200, 20), min, max, value, options, baseFunction)
        sliderView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        sliderView.baseOffset = vec3(elementControlX, elementYOffset - 6, 0)

        
        if tipText then
            uiToolTip:add(sliderView.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), tipText, nil, vec3(0,-8,10), nil, sliderView, parentView)
        end

        elementYOffset = elementYOffset - yOffsetBetweenElements
        uiSelectionLayout:addView(parentView, sliderView)
        return sliderView
    end


    tribeSpawnButton = addToggleButton(mainParentView, locale:get("worldSettings_tribeSpawns") .. ":", locale:get("worldSettings_tribeSpawns_tip"), true, function(newValue)
        logicInterface:callServerFunction("changeWorldSetting", 
        {
            key = "disableTribeSpawns",
            value = (not newValue),
        })
    end)


    autoRoleAssignmentToggleButton = addToggleButton(mainParentView, locale:get("ui_roles_assignAutomatically") .. ":", locale:get("ui_roles_assignAutomatically_toolTip"), true, function(newValue)
        world:setAutoRoleAssignmentEnabled(uiStandardButton:getToggleState(autoRoleAssignmentToggleButton))
    end)

    
    difficultySelectionPopUpButton = addPopUpButton(mainParentView, mainParentView, locale:get("worldSettings_gameDifficulty") .. ":", modeNameList, function(selectedIndex, selectedTitle)
        logicInterface:callServerFunction("changeWorldSetting", 
        {
            key = "gameDifficulty",
            value = difficultyModes[selectedIndex].key,
        })
    end)

    --[[local pauseDelayMinutes = math.floor(clientGameSettings.values.inactivityPauseDelay)

    local function updatePauseOnInactivitySliderValueView(pauseDelayMinutes_)
        if pauseDelayMinutes_ >= 31 then
            pauseOnInactivitySliderValueView.text = locale:get("misc_disabled") 
        else
            pauseOnInactivitySliderValueView.text = string.format("%d minutes", pauseDelayMinutes_)
        end
    end

    pauseOnInactivitySlider = addSlider(generalView, locale:get("settings_pauseOnInactivity") .. ":", 1, 31, pauseDelayMinutes, function(newValue)
        clientGameSettings:changeSetting("inactivityPauseDelay", newValue)
    end, function(newValue)
        updatePauseOnInactivitySliderValueView(newValue)
    end)

    pauseOnInactivitySliderValueView = TextView.new(generalView)
    pauseOnInactivitySliderValueView.font = Font(uiCommon.fontName, 16)
    pauseOnInactivitySliderValueView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    pauseOnInactivitySliderValueView.relativeView = pauseOnInactivitySlider
    pauseOnInactivitySliderValueView.baseOffset = vec3(2,0, 0)
    updatePauseOnInactivitySliderValueView(pauseDelayMinutes)]]


    local initialValue = gameConstants.populationLimitPerTribeSoftCap

    populationCapSlider = addSlider(mainParentView, locale:get("worldSettings_populationCap") .. ":", locale:get("worldSettings_populationCap_tip"), 0, gameConstants.populationLimitPerTribeSoftCap, initialValue, function(newValue)
        if newValue >= gameConstants.populationLimitPerTribeSoftCap then
            logicInterface:callServerFunction("changeWorldSetting", 
            {
                key = "populationCap",
            })
        else
            logicInterface:callServerFunction("changeWorldSetting", 
            {
                key = "populationCap",
                value = newValue,
            })
        end
        updatePopulationCapText(newValue)
    end,
    function(newValue)
        updatePopulationCapText(newValue)
    end)
    
    populationCapSliderTextValueView = TextView.new(mainParentView)
    populationCapSliderTextValueView.font = Font(uiCommon.fontName, 16)
    populationCapSliderTextValueView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    populationCapSliderTextValueView.relativeView = populationCapSlider
    populationCapSliderTextValueView.baseOffset = vec3(2,0, 0)
    updatePopulationCapText(initialValue)

end

return optionsWorldSettingsView