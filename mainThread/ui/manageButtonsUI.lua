local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local locale = mjrequire "common/locale"

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
--local timeControls = mjrequire "mainThread/ui/timeControls"
local eventManager = mjrequire "mainThread/eventManager"
local pointAndClickCamera = mjrequire "mainThread/pointAndClickCamera"
local playerSapiens = mjrequire "mainThread/playerSapiens"

local manageButtonsUI = {}

local gameUI = nil
local manageUI = nil
local hubUI = nil

manageButtonsUI.menuButtonsView = nil
manageButtonsUI.menuButtonsByManageUIModeType = {}
manageButtonsUI.selectedButtonModeIndex = nil
manageButtonsUI.menuButtonCount = 3

manageButtonsUI.menuButtonSize = 80.0
manageButtonsUI.menuButtonPaddingRatio = 0.28
manageButtonsUI.toolTipOffset = vec3(0,-10,0)


function manageButtonsUI:setSelectedButton(modeIndex)
    if manageButtonsUI.selectedButtonModeIndex ~= modeIndex then
        if manageButtonsUI.selectedButtonModeIndex then
            local button = manageButtonsUI.menuButtonsByManageUIModeType[manageButtonsUI.selectedButtonModeIndex]
            --uiStandardButton:setDisabled(button, false)
            uiStandardButton:setSelected(button, false)
            --mj:log("dseselt:", button)
        end

        manageButtonsUI.selectedButtonModeIndex = modeIndex

        if manageButtonsUI.selectedButtonModeIndex then
            local button = manageButtonsUI.menuButtonsByManageUIModeType[manageButtonsUI.selectedButtonModeIndex]
            --uiStandardButton:setDisabled(button, true)
            uiStandardButton:setSelected(button, true)
            --mj:log("select:", button)
        end

    end
end

function manageButtonsUI:init(gameUI_, manageUI_, hubUI_, world)
    gameUI = gameUI_
    manageUI = manageUI_
    hubUI = hubUI_
    
    manageButtonsUI.orderedModes = {
        manageUI.modeTypes.build,
        manageUI.modeTypes.tribe,
        manageUI.modeTypes.options,
    }

    local menuButtonSize = manageButtonsUI.menuButtonSize
    local menuButtonPaddingRatio = manageButtonsUI.menuButtonPaddingRatio
    
    local menuButtonPadding = menuButtonSize * menuButtonPaddingRatio
    
    --local settingsButtonSize = 60.0
    --local settingsButtonPadding = settingsButtonSize * 0.28

    local menuButtonsView = View.new(gameUI.view)
    manageButtonsUI.menuButtonsView = menuButtonsView
    menuButtonsView.hidden = true
    menuButtonsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    menuButtonsView.size = vec2(menuButtonSize * manageButtonsUI.menuButtonCount + menuButtonPadding * (manageButtonsUI.menuButtonCount - 1), menuButtonSize)
    menuButtonsView.baseOffset = vec3(0.0, -40.0, 0.0)

    --[[gameSettingsButtonsView = View.new(gameUI.view)
    gameSettingsButtonsView.hidden = true
    gameSettingsButtonsView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    gameSettingsButtonsView.size = vec2(settingsButtonSize * settingsButtonCount + settingsButtonPadding * (settingsButtonCount - 1), settingsButtonSize)
    gameSettingsButtonsView.baseOffset = vec3(20.0, -20.0, 0.0)]]

    local toolTipOffset = manageButtonsUI.toolTipOffset

    local buildButton = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize,menuButtonSize), uiStandardButton.types.markerLike)
    buildButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    uiStandardButton:setIconModel(buildButton, "icon_hammer")
    uiToolTip:add(buildButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("manage_build"), nil, toolTipOffset, nil, buildButton)
    uiToolTip:addKeyboardShortcut(buildButton.userData.backgroundView, "game", "buildMenu2", nil, nil)

    local tribeButton = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize,menuButtonSize), uiStandardButton.types.markerLike)
    tribeButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    tribeButton.relativeView = buildButton
    tribeButton.baseOffset = vec3(menuButtonPadding, 0, 0)
    uiStandardButton:setIconModel(tribeButton, "icon_tribe2")
    uiToolTip:add(tribeButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("manage_tribe"), nil, toolTipOffset, nil, tribeButton)
    uiToolTip:addKeyboardShortcut(tribeButton.userData.backgroundView, "game", "tribeMenu", nil, nil)
    

    --[[local storageLogisticsButton = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize,menuButtonSize), uiStandardButton.types.markerLike)
    storageLogisticsButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    storageLogisticsButton.relativeView = tribeButton
    storageLogisticsButton.baseOffset = vec3(menuButtonPadding, 0, 0)
    uiStandardButton:setIconModel(storageLogisticsButton, "icon_logistics")
    uiToolTip:add(storageLogisticsButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("manage_storageLogistics"), nil, toolTipOffset, nil, storageLogisticsButton)
    uiToolTip:addKeyboardShortcut(storageLogisticsButton.userData.backgroundView, "game", "routesMenu", nil, nil)]]
    

    local optionsButton = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize,menuButtonSize), uiStandardButton.types.markerLike)
    optionsButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    optionsButton.relativeView = tribeButton
    optionsButton.baseOffset = vec3(menuButtonPadding, 0, 0)
    uiStandardButton:setIconModel(optionsButton, "icon_settings")
    uiToolTip:add(optionsButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("settings_options"), nil, toolTipOffset, nil, optionsButton)
    uiToolTip:addKeyboardShortcut(optionsButton.userData.backgroundView, "game", "settingsMenu", nil, nil)

    manageButtonsUI.menuButtonsByManageUIModeType[manageUI.modeTypes.build] = buildButton
    manageButtonsUI.menuButtonsByManageUIModeType[manageUI.modeTypes.tribe] = tribeButton
    manageButtonsUI.menuButtonsByManageUIModeType[manageUI.modeTypes.options] = optionsButton

    
    menuButtonsView.hiddenStateChanged = function(newHiddenState)
        if newHiddenState then
            for modeIndex,button in pairs(manageButtonsUI.menuButtonsByManageUIModeType) do
                uiStandardButton:resetAnimationState(button)
            end
        end
    end


    --local settingsButtonsToolTipOffset = vec3(0,-10,0)

    for modeIndex,button in pairs(manageButtonsUI.menuButtonsByManageUIModeType) do
        uiStandardButton:setClickFunction(button, function()
            manageUI:show(modeIndex)
        end)
    end

    local function indexForMode(modeIndex)
        for i, modeIndex_ in ipairs(manageButtonsUI.orderedModes) do
            if modeIndex_ == modeIndex then
                return i
            end
        end
        return nil
    end

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuTabLeft", function(isDown)
        if isDown and not menuButtonsView.hidden then
            if manageUI:hidden() then
                manageUI:show(manageUI.modeTypes.build)
            else
                local currentModeIndex = manageUI:getCurrentModeIndex()
                local orderIndex = indexForMode(currentModeIndex)
                if orderIndex then
                    if orderIndex > 1 then
                        manageUI:show(manageButtonsUI.orderedModes[orderIndex - 1])
                    else
                        manageUI:show(currentModeIndex)
                    end
                else
                    manageUI:show(manageUI.modeTypes.build)
                end
            end
            return true
        end
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuTabRight", function(isDown)
        if isDown and not menuButtonsView.hidden then
            if manageUI:hidden() then
                manageUI:show(manageUI.modeTypes.tribe)
            else
                local currentModeIndex = manageUI:getCurrentModeIndex()
                local orderIndex = indexForMode(currentModeIndex)
                if orderIndex then
                    if orderIndex < #manageButtonsUI.orderedModes then
                        manageUI:show(manageButtonsUI.orderedModes[orderIndex + 1])
                    else
                        manageUI:show(currentModeIndex)
                    end
                else
                    manageUI:show(manageUI.modeTypes.tribe)
                end
            end
            return true
        end
    end)

end

function manageButtonsUI:updateHiddenState()
    if not playerSapiens:hasFollowers() then
        manageButtonsUI.menuButtonsView.hidden = true
    elseif manageUI:hidden() and (not hubUI:anyModalUIIsDisplayed()) and ((not pointAndClickCamera.enabled) or gameUI:modalMoveOrBuildLikeUIIsVisible()) then
        manageButtonsUI.menuButtonsView.hidden = true
       -- gameSettingsButtonsView.hidden = true
    else
        manageButtonsUI.menuButtonsView.hidden = false
        --gameSettingsButtonsView.hidden = false
    end
end

return manageButtonsUI