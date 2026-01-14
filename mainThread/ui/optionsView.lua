local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"
local steam = mjrequire "common/utility/steam"

local gameConstants = mjrequire "common/gameConstants"
local notification = mjrequire "common/notification"
local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
--local terminal = mjrequire "mainThread/ui/terminal"
local uiSlider = mjrequire "mainThread/ui/uiCommon/uiSlider"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local uiPopUpButton = mjrequire "mainThread/ui/uiCommon/uiPopUpButton"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local tutorialStoryPanel = mjrequire "mainThread/ui/tutorialStoryPanel"
local audio = mjrequire "mainThread/audio"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local optionsWorldSettingsView = mjrequire "mainThread/ui/optionsWorldSettingsView"
local logicInterface = mjrequire "mainThread/logicInterface"

local world = nil
--local gameUI = nil
local controller = nil

local containerView = nil
local mainView = nil

local tabButtonsView = nil

local optionsView = {}

local keyBindingsScrollView = nil
local keyBindingsScrollViewItemHeight = 30

local activeSelectedControllableSubView = nil

local currentView = nil
local currentButton = nil
local currentPopOversView = nil

local generalView = nil

local languagePopupButton = nil
local resolutionPopupButton = nil
local windowModeButton = nil

local pauseOnLostFocusToggleButton = nil
local pauseOnInactivitySlider = nil
local pauseOnInactivitySliderValueView = nil
local allowLanConnectionsToggleButton = nil
local inviteFriendsButton = nil

local function updateInviteButton()
    uiStandardButton:setDisabled(inviteFriendsButton, controller.isOnlineClient or (not clientGameSettings.values.allowLanConnections) or (not world))
    if world then
        uiToolTip:add(inviteFriendsButton, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("settings_inviteFriendsButton_tip"), nil, vec3(0,-8,10), nil, inviteFriendsButton, generalView)
    else        
        uiToolTip:add(inviteFriendsButton, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("settings_inviteFriendsButton_tip_no_world"), nil, vec3(0,-8,10), nil, inviteFriendsButton, generalView)
    end

end

local function initKeyBindingsScrollViewIfNeeded(keyBindingsView)
    if not keyBindingsScrollView then
        local keyBindingsScrollViewSize = keyBindingsView.size - vec2(40.0,40.0)
        keyBindingsScrollViewSize.y = keyBindingsScrollViewSize.y - (keyBindingsScrollViewSize.y % keyBindingsScrollViewItemHeight)
        keyBindingsScrollView = uiScrollView:create(keyBindingsView, keyBindingsScrollViewSize, MJPositionInnerLeft)
        keyBindingsScrollView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)

        local orderedGroupKeys = keyMapping.orderedGroupKeys
        local counter = 1

        
        local bindingPopUpView = ModelView.new(keyBindingsView)
        bindingPopUpView:setModel(model:modelIndexForName("ui_panel_10x4"))
        bindingPopUpView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        bindingPopUpView.hidden = true
        bindingPopUpView.baseOffset = vec3(0,0,8)
        bindingPopUpView.size = vec2(400, 160)
        local bindingPopUpViewScaleToUse = bindingPopUpView.size.x * 0.5
        bindingPopUpView.scale3D = vec3(bindingPopUpViewScaleToUse,bindingPopUpViewScaleToUse,bindingPopUpViewScaleToUse)
        bindingPopUpView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)

        
        local bindingPopUpViewTitle = TextView.new(bindingPopUpView)
        bindingPopUpViewTitle.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        bindingPopUpViewTitle.baseOffset = vec3(0,-20,0)
        bindingPopUpViewTitle.font = Font(uiCommon.fontName, 16)
        
        local bindingPopUpViewInstructions = TextView.new(bindingPopUpView)
        bindingPopUpViewInstructions.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        bindingPopUpViewInstructions.relativeView = bindingPopUpViewTitle
        bindingPopUpViewInstructions.baseOffset = vec3(0,-20,0)
        bindingPopUpViewInstructions.font = Font(uiCommon.fontName, 16)
        bindingPopUpViewInstructions.text = locale:get("ui_info_bindingPopUpViewInstructions")
        
        local bindingPopUpViewTimerText = TextView.new(bindingPopUpView)
        bindingPopUpViewTimerText.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        bindingPopUpViewTimerText.relativeView = bindingPopUpViewInstructions
        bindingPopUpViewTimerText.baseOffset = vec3(0,-10,0)
        bindingPopUpViewTimerText.font = Font(uiCommon.fontName, 16)

    
    --[[{
        key = "ui_info_bindingTimeRemaining",
        func = function(values)
            return "Reverts in " .. values.seconds .. " seconds..."
        end,
    },]]

        local function createBackgroundWithTitle(text, indent)
            local backgroundView = ColorView.new(keyBindingsScrollView)
            local defaultColor = vec4(0.0,0.0,0.0,0.5)
            if counter % 2 == 1 then
                defaultColor = vec4(0.03,0.03,0.03,0.5)
            end

            backgroundView.color = defaultColor

            backgroundView.size = vec2(keyBindingsScrollView.size.x - 20, keyBindingsScrollViewItemHeight)
            backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)

            uiScrollView:insertRow(keyBindingsScrollView, backgroundView, nil)

            local itemContainerView = View.new(backgroundView)
            itemContainerView.size = backgroundView.size - vec2(20.0 * indent)
            itemContainerView.baseOffset = vec3(20.0 * indent, 0, 0)

            local nameTextView = TextView.new(itemContainerView)
            nameTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            nameTextView.baseOffset = vec3(0,0,0)
            nameTextView.font = Font(uiCommon.fontName, 16)

            nameTextView.color = vec4(1.0,1.0,1.0,1.0)
            nameTextView.text = text

            counter = counter + 1
            return itemContainerView
        end

        for i,groupKey in ipairs(orderedGroupKeys) do
            local groupInfo = keyMapping.mappingGroups[groupKey]
            createBackgroundWithTitle(groupInfo.name, 0)
            local orderedMappingKeys = groupInfo.orderedMappingKeys
            for j,mappingKey in ipairs(orderedMappingKeys) do
                local mappingInfo = groupInfo.mappingsByKey[mappingKey]
                local itemContainerView = createBackgroundWithTitle(mappingInfo.name, 1)
                
                local bindingValueLocationX = itemContainerView.size.x * 0.6

                local bindingTextView = TextView.new(itemContainerView)
                bindingTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
                bindingTextView.baseOffset = vec3(bindingValueLocationX,0,0)
                bindingTextView.font = Font(uiCommon.fontName, 16)
                bindingTextView.color = vec4(1.0,1.0,1.0,1.0)

                
                local buttonSize = itemContainerView.size.y * 0.8
                local editButton = uiStandardButton:create(itemContainerView, vec2(buttonSize, buttonSize), uiStandardButton.types.slim_1x1_bordered)
                editButton.baseOffset = vec3(itemContainerView.size.x * 0.8, 0, 0)
                editButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
                uiStandardButton:setIconModel(editButton, "icon_edit")

                local resetButton = uiStandardButton:create(itemContainerView, vec2(buttonSize, buttonSize), uiStandardButton.types.slim_1x1_bordered)
                resetButton.relativeView = editButton
                resetButton.baseOffset = vec3(10, 0, 0)
                resetButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
                uiStandardButton:setIconModel(resetButton, "icon_reset")

                local function updateItem()
                   -- local boundKeyCodeKey = keyMapping.keyCodeKeysByCode[mappingInfo.keyCode]
                   -- local keyName = locale:getKeyName(boundKeyCodeKey)


                   --[[ local bindingText = keyName
                    if mappingInfo.mod and mappingInfo.mod ~= keyMapping.modifiers.none then
                        local modifierKeyCode = keyMapping.modifierKeyCodesByModifierCode[mappingInfo.mod]
                        if modifierKeyCode then
                            local modifierKeyCodeKey = keyMapping.keyCodeKeysByCode[modifierKeyCode]
                            local modifierKeyName = locale:getKeyName(modifierKeyCodeKey)
                            bindingText = modifierKeyName .. "+" .. keyName
                        end
                    end
                    bindingTextView.text = bindingText]]

                    bindingTextView.text = keyMapping:getLocalizedString(groupKey, mappingKey) or "??"
                    
                    if mappingInfo.modified then
                        uiStandardButton:setDisabled(resetButton, false)
                    else
                        uiStandardButton:setDisabled(resetButton, true)
                    end

                end
                

                local function tidyUpAfterBinding()
                    bindingPopUpView.update = nil
                    bindingPopUpView.hidden = true
                    eventManager:setModalEventListener(nil)
                end

                uiStandardButton:setClickFunction(editButton, function()
                    local modKeyCode = nil
                    local mod2KeyCode = nil
                    local mainKeyCode = nil

                    eventManager:hideMouse()
                    eventManager:setModalEventListener({
                        keyChanged = function(isDown, code, modKeyIgnored, isRepeat)
                            if isDown and not isRepeat then
                                local modifierKeyCode = keyMapping:isModifierKey(code)
                                if modifierKeyCode then
                                    if modKeyCode and modKeyCode ~= code then
                                        mod2KeyCode = code
                                    else
                                        modKeyCode = code
                                    end
                                else
                                    mainKeyCode = code
                                end
                            end
                            if not isDown then
                                if not mainKeyCode then
                                    mainKeyCode = modKeyCode
                                    modKeyCode = mod2KeyCode
                                    mod2KeyCode = nil
                                end

                                if mainKeyCode then
                                    --mj:log("updating: ", groupKey, ".", mappingKey, " with:", keyMapping.keyCodeKeysByCode[modKeyCode], "+", keyMapping.keyCodeKeysByCode[mainKeyCode])
                                    keyMapping:setBinding(groupKey, mappingKey, mainKeyCode, modKeyCode, mod2KeyCode)
                                    updateItem()
                                end

                                tidyUpAfterBinding()
                            end
                        end,
                    })
                    bindingPopUpView.hidden = false
                    bindingPopUpViewTitle.text = locale:get("misc_Rebinding") .. ": " .. mappingInfo.name
                    local bindingTimer = 5.0
                    local timeLeftSeconds = -1
                    bindingPopUpView.update = function(dt)
                        bindingTimer = bindingTimer - dt
                        if bindingTimer <= 0.0 then
                            tidyUpAfterBinding()
                        else
                            local newTimeLeftSeconds = math.floor(bindingTimer + 0.99)
                            if newTimeLeftSeconds ~= timeLeftSeconds then
                                timeLeftSeconds = newTimeLeftSeconds
                                bindingPopUpViewTimerText.text = locale:get("ui_info_bindingTimeRemaining", {seconds = timeLeftSeconds})
                            end
                        end
                    end
                end)
                
                uiStandardButton:setClickFunction(resetButton, function()
                    keyMapping:resetBinding(groupKey, mappingKey)
                    updateItem()
                end)

                updateItem()
            end
            --[[tableViewItemInfos[i] = {
                backgroundView = backgroundView,
                defaultColor = defaultColor,
                nameTextView = nameTextView,
            }]]

        end
    end
end

local titleString = nil


local function changeActiveSelectedControlView(newControlView)
    --mj:log("changeActiveSelectedControlView:", newControlView)
    if activeSelectedControllableSubView ~= newControlView then
        activeSelectedControllableSubView = newControlView
        if activeSelectedControllableSubView then
            uiSelectionLayout:setActiveSelectionLayoutView(activeSelectedControllableSubView)
        else
            uiSelectionLayout:setActiveSelectionLayoutView(tabButtonsView)
        end
    end 
end


local isRenderingOnlineClient = false

local function updateEnabledStatesForOnlineClientChange()
    local isOnlineClient = controller.isOnlineClient
    if isOnlineClient ~= isRenderingOnlineClient then
        isRenderingOnlineClient = isOnlineClient
        
        uiStandardButton:setDisabled(allowLanConnectionsToggleButton, isOnlineClient)
        uiStandardButton:setToggleState(allowLanConnectionsToggleButton, clientGameSettings.values.allowLanConnections and (not isOnlineClient))

        uiStandardButton:setDisabled(pauseOnLostFocusToggleButton, isOnlineClient)
        uiStandardButton:setToggleState(pauseOnLostFocusToggleButton, clientGameSettings.values.pauseOnLostFocus and (not isOnlineClient))

        updateInviteButton()

        if isOnlineClient then
            pauseOnInactivitySliderValueView.color = mj.disabledTextColor
        else
            pauseOnInactivitySliderValueView.color = mj.textColor
        end
        uiSlider:setDisabled(pauseOnInactivitySlider, isOnlineClient)
    end
end

local function init(manageUIOrNIl, optionsParentView)
    
    mainView = View.new(containerView)
    optionsView.mainView = mainView
    mainView.size = containerView.size

    --local tabHeight = mainView.size.y-- - 80.0
    local tabWidth = 180.0
    
    local rightViewBottomPadding = 20.0

    local rightViewWithTitleHeightTopPadding = 40.0
    local rightViewBelowTitleHeightPadding = 40.0
    local additionalYHeight = 0.0
    if manageUIOrNIl then
        rightViewWithTitleHeightTopPadding = 0.0
        rightViewBelowTitleHeightPadding = 0.0
        additionalYHeight = 40.0
    end


    local groupButtonsBackgroundView = ModelView.new(mainView)
    groupButtonsBackgroundView:setModel(model:modelIndexForName("ui_inset_lg_1x1"))
    local sizeY = mainView.size.y - 80.0 + additionalYHeight
    sizeY = math.floor(sizeY / 30.0) * 30.0
    local leftPaneInnerSize = vec2(tabWidth, sizeY)
    groupButtonsBackgroundView.size = leftPaneInnerSize + vec2(10.0,10.0)
    local scaleToUsePaneX = groupButtonsBackgroundView.size.x * 0.5
    local scaleToUsePaneY = groupButtonsBackgroundView.size.y * 0.5 
    groupButtonsBackgroundView.scale3D = vec3(scaleToUsePaneX,scaleToUsePaneY,scaleToUsePaneX)
    groupButtonsBackgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    groupButtonsBackgroundView.baseOffset = vec3(20.0, -60.0 + additionalYHeight, 0.0)

    
    local rightView = View.new(mainView)
    rightView.size = vec2(mainView.size.x - tabWidth - 80, mainView.size.y - rightViewWithTitleHeightTopPadding - rightViewBottomPadding)
    rightView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightView.baseOffset = vec3(-40,rightViewBottomPadding, 0)

    local titleTextView = nil
    if not manageUIOrNIl then
        titleTextView = ModelTextView.new(rightView)
        titleTextView.font = Font(uiCommon.titleFontName, 36)
        titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        titleTextView.baseOffset = vec3(0,0, 0)
        titleTextView:setText(locale:get("settings_options") .. ": " .. locale:get("settings_general"), material.types.standardText.index)
    end

    generalView = View.new(rightView)
    generalView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    generalView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    uiSelectionLayout:createForView(generalView)
    
    local generalViewPopOversView = View.new(rightView)
    generalViewPopOversView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    generalViewPopOversView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    generalViewPopOversView.hidden = true


    local worldView = View.new(rightView)
    worldView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    worldView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    worldView.hidden = true
    uiSelectionLayout:createForView(worldView)
    if not worldView.userData then 
        worldView.userData = {}
    end
    worldView.userData.parentBecameVisible = function()
        optionsWorldSettingsView:update()
    end

    
    local notificationsView = View.new(rightView)
    notificationsView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    notificationsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    notificationsView.hidden = true
    uiSelectionLayout:createForView(notificationsView)
    if not notificationsView.userData then 
        notificationsView.userData = {}
    end
    notificationsView.userData.parentBecameVisible = function()
        optionsWorldSettingsView:update()
    end
    
    local graphicsView = View.new(rightView)
    graphicsView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    graphicsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    graphicsView.hidden = true
    uiSelectionLayout:createForView(graphicsView)
    
    local graphicsViewPopOversView = View.new(rightView)
    graphicsViewPopOversView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    graphicsViewPopOversView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    graphicsViewPopOversView.hidden = true

    
    local controlsView = View.new(rightView)
    controlsView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    controlsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    controlsView.hidden = true
    uiSelectionLayout:createForView(controlsView)
    
    local controlsViewPopOversView = View.new(rightView)
    controlsViewPopOversView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    controlsViewPopOversView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    controlsViewPopOversView.hidden = true
    
    local keyBindingsView = View.new(rightView)
    keyBindingsView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    keyBindingsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    keyBindingsView.hidden = true
    uiSelectionLayout:createForView(keyBindingsView)

    local exitButton = nil
    local exitView = nil

    local debugView = View.new(rightView)
    debugView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
    debugView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    debugView.hidden = true
    uiSelectionLayout:createForView(debugView)

    local exitViewPopOversView = nil

    if world then
        exitView = View.new(rightView)
        exitView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
        exitView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        exitView.hidden = true
        uiSelectionLayout:createForView(exitView)

        exitViewPopOversView = View.new(rightView)
        exitViewPopOversView.size = vec2(rightView.size.x, rightView.size.y - rightViewBelowTitleHeightPadding)
        exitViewPopOversView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        exitViewPopOversView.hidden = true
    end




    local function updateSelection(newView, newButton, titleText, popOversView)
        --mj:error("updateSelection:", newView)
        if newView ~= currentView then
            uiSelectionLayout:setSelection(tabButtonsView, newButton)
            changeActiveSelectedControlView(nil)
            
            if currentView then
                currentView.hidden = true
                uiStandardButton:setSelected(currentButton, false)
            end
            if currentPopOversView then
                currentPopOversView.hidden = true
            end
            currentView = newView
            currentPopOversView = popOversView
            currentButton = newButton
            currentView.hidden = false
            uiStandardButton:setSelected(currentButton, true)
            if manageUIOrNIl then
                titleString = locale:get("settings_options") .. ": " .. titleText
                manageUIOrNIl:changeTitle(titleString, "icon_settings")
            else
                titleTextView:setText(locale:get("settings_options") .. ": " .. titleText, material.types.standardText.index)
            end
            if currentPopOversView then
                currentPopOversView.hidden = false
            end

            if currentView.userData and currentView.userData.parentBecameVisible then
                currentView.userData.parentBecameVisible()
            end
        else
            changeActiveSelectedControlView(currentView)
        end
    end
    
    tabButtonsView = View.new(groupButtonsBackgroundView)
    tabButtonsView.size = groupButtonsBackgroundView.size
    tabButtonsView.baseOffset = vec3(0,0, 4)

    uiSelectionLayout:createForView(tabButtonsView)
    
    local generalButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
    generalButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    generalButton.baseOffset = vec3(0,-10, 0)
    uiStandardButton:setText(generalButton, locale:get("settings_general"))
    currentButton = generalButton
    local function generalClick()
        updateSelection(generalView, generalButton, locale:get("settings_general"), generalViewPopOversView)
    end
    uiStandardButton:setClickFunction(generalButton, generalClick)
    uiSelectionLayout:addView(tabButtonsView, generalButton)
    uiSelectionLayout:setItemSelectedFunction(generalButton, generalClick)
    uiSelectionLayout:setSelection(tabButtonsView, generalButton)

    updateSelection(generalView, generalButton, locale:get("settings_general"), generalViewPopOversView)


    local worldButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
    worldButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    worldButton.relativeView = generalButton
    worldButton.baseOffset = vec3(0,0, 0)
    uiStandardButton:setText(worldButton, locale:get("settings_world"))
    local function worldClick()
        updateSelection(worldView, worldButton, locale:get("settings_world"), nil)
    end
    uiStandardButton:setClickFunction(worldButton, worldClick)
    uiSelectionLayout:addView(tabButtonsView, worldButton)
    uiSelectionLayout:setItemSelectedFunction(worldButton, worldClick)

    
    local notificationsButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
    notificationsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    notificationsButton.relativeView = worldButton
    notificationsButton.baseOffset = vec3(0,0, 0)
    uiStandardButton:setText(notificationsButton, locale:get("settings_notifications"))
    local function notificationsButtonClick()
        updateSelection(notificationsView, notificationsButton, locale:get("settings_notifications"), nil)
    end
    uiStandardButton:setClickFunction(notificationsButton, notificationsButtonClick)
    uiSelectionLayout:addView(tabButtonsView, notificationsButton)
    uiSelectionLayout:setItemSelectedFunction(notificationsButton, notificationsButtonClick)

    
    local graphicsButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
    graphicsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    graphicsButton.relativeView = notificationsButton
    graphicsButton.baseOffset = vec3(0,0, 0)
    uiStandardButton:setText(graphicsButton, locale:get("settings_graphics"))
    local function graphicsClick()
        updateSelection(graphicsView, graphicsButton, locale:get("settings_graphics"), graphicsViewPopOversView)
    end
    uiStandardButton:setClickFunction(graphicsButton, graphicsClick)
    uiSelectionLayout:addView(tabButtonsView, graphicsButton)
    uiSelectionLayout:setItemSelectedFunction(graphicsButton, graphicsClick)
    
    local controlsButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
    controlsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    controlsButton.relativeView = graphicsButton
    controlsButton.baseOffset = vec3(0,0, 0)
    uiStandardButton:setText(controlsButton, locale:get("settings_Controls"))
    local function controlsClick()
        updateSelection(controlsView, controlsButton, locale:get("settings_Controls"), controlsViewPopOversView)
    end
    uiStandardButton:setClickFunction(controlsButton, controlsClick)
    uiSelectionLayout:addView(tabButtonsView, controlsButton)
    uiSelectionLayout:setItemSelectedFunction(controlsButton, controlsClick)
    
    local keyBindingsButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
    keyBindingsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    keyBindingsButton.relativeView = controlsButton
    keyBindingsButton.baseOffset = vec3(0,0, 0)
    uiStandardButton:setText(keyBindingsButton, locale:get("settings_KeyBindings"))
    local function keyBindingsClick()
        initKeyBindingsScrollViewIfNeeded(keyBindingsView)
        updateSelection(keyBindingsView, keyBindingsButton, locale:get("settings_KeyBindings"))
    end
    uiStandardButton:setClickFunction(keyBindingsButton, keyBindingsClick)
    uiSelectionLayout:addView(tabButtonsView, keyBindingsButton)
    uiSelectionLayout:setItemSelectedFunction(keyBindingsButton, keyBindingsClick)

    local prevButton = keyBindingsButton
    
    if gameConstants.showDebugMenu then
        local debugButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
        debugButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        debugButton.relativeView = keyBindingsButton
        debugButton.baseOffset = vec3(0,0, 0)
        uiStandardButton:setText(debugButton, locale:get("settings_Debug"))
        local function debugClick()
            updateSelection(debugView, debugButton, locale:get("settings_Debug"))
        end
        uiStandardButton:setClickFunction(debugButton, debugClick)
        uiSelectionLayout:addView(tabButtonsView, debugButton)
        uiSelectionLayout:setItemSelectedFunction(debugButton, debugClick)
        prevButton = debugButton
    end
    
    if world then
        exitButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth,40))
        exitButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        exitButton.relativeView = prevButton
        exitButton.baseOffset = vec3(0,0, 0)
        uiStandardButton:setText(exitButton, locale:get("settings_Exit"))
        local function exitClick()
            updateSelection(exitView, exitButton, locale:get("settings_Exit"), exitViewPopOversView)
        end
        uiStandardButton:setClickFunction(exitButton, exitClick)
        uiSelectionLayout:addView(tabButtonsView, exitButton)
        uiSelectionLayout:setItemSelectedFunction(exitButton, exitClick)
    end
    

   -- local buttonSize = vec2(180, 40)
    local yOffsetBetweenElements = 35
    local elementTitleX = -rightView.size.x * 0.5 - 10
    local elementControlX = rightView.size.x * 0.5
    local elementYOffsetStart = -20

    local elementYOffset = elementYOffsetStart

    
    
    local function addTitleHeader(parentView, title)
        if elementYOffset ~= elementYOffsetStart then
            elementYOffset = elementYOffset - 20
        end

        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        textView.baseOffset = vec3(0,elementYOffset - 4, 0)
        textView.text = title

        elementYOffset = elementYOffset - yOffsetBetweenElements
        return textView
    end

    local function addToggleButton(parentView, toggleButtonTitle, toggleValue, changedFunction)
        local toggleButton = uiStandardButton:create(parentView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        toggleButton.baseOffset = vec3(elementControlX, elementYOffset, 0)
        uiStandardButton:setToggleState(toggleButton, toggleValue)
        
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = toggleButtonTitle
    
        uiStandardButton:setClickFunction(toggleButton, function()
            changedFunction(uiStandardButton:getToggleState(toggleButton))
        end)

        elementYOffset = elementYOffset - yOffsetBetweenElements
        
        uiSelectionLayout:addView(parentView, toggleButton)
        return toggleButton
    end

    
    local function addSlider(parentView, sliderTitle, min, max, value, changedFunction, continuousFunctionOrNil)
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

        elementYOffset = elementYOffset - yOffsetBetweenElements
        uiSelectionLayout:addView(parentView, sliderView)
        return sliderView
    end
        
    local graphicsApplyButton = nil
    local languageApplyButton = nil

    local function popupHiddenFunction()
        uiSelectionLayout:setActiveSelectionLayoutView(activeSelectedControllableSubView)
    end
    
    local buttonSize = vec2(200, 40)
    local popUpMenuSize = vec2(240, 180)
    local function addPopUpButton(parentView, popOversView, popUpTitle, itemList, selectionFunction)
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = popUpTitle

        local button = uiPopUpButton:create(parentView, popOversView, buttonSize, popUpMenuSize, popupHiddenFunction)
        button.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        button.baseOffset = vec3(elementControlX + 4, elementYOffset + 6, 0)
        uiPopUpButton:setItems(button, itemList)
        uiPopUpButton:setSelection(button, 1)
        uiPopUpButton:setSelectionFunction(button, selectionFunction)

        elementYOffset = elementYOffset - yOffsetBetweenElements
        uiSelectionLayout:addView(parentView, button)

        return button
    end

    local function addButton(parentView, buttonTitle, clickFunction)
        local button = uiStandardButton:create(parentView, buttonSize)
        button.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        button.baseOffset = vec3(0,elementYOffset, 0)
        uiStandardButton:setText(button, buttonTitle)
        uiStandardButton:setClickFunction(button, clickFunction)
        elementYOffset = elementYOffset - yOffsetBetweenElements
        uiSelectionLayout:addView(parentView, button)

        return button
    end

    elementYOffset = elementYOffsetStart

    
    local orderedInfoList = {}
    local availableLocalizations = locale.availableLocalizations
    for k,info in pairs(availableLocalizations) do
        local displayName = info.displayName
        if not displayName then
            displayName = k
        end
        table.insert(orderedInfoList, {
            displayName = displayName,
            key = k,
        })
    end
    
    local function sortByName(a,b)
        return a.displayName < b.displayName
    end

    table.sort(orderedInfoList, sortByName)
    local languagesList = {}
    local englishIndex = nil
    local currentSelectedIndex = nil
    local currentLanguageSettingKey = controller:getLocaleSettingKey()
    for i,info in ipairs(orderedInfoList) do
        table.insert(languagesList, info.displayName)
        if info.key == currentLanguageSettingKey then
            currentSelectedIndex = i
        end
        
        if info.key == "en_us" then
            englishIndex = i
        end
    end

    if not currentSelectedIndex then
        currentSelectedIndex = englishIndex or 1
    end

   -- mj:log("languagesList:", languagesList)

    languagePopupButton = addPopUpButton(generalView, generalViewPopOversView, locale:get("settings_language") .. ":", languagesList, function(selectedIndex, selectedTitle)
        controller:setLocale(orderedInfoList[selectedIndex].key)
        languageApplyButton.hidden = false
    end)
    uiPopUpButton:setSelection(languagePopupButton, currentSelectedIndex)
    
    uiToolTip:add(languagePopupButton, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("settings_language_tip"), nil, vec3(0,-8,10), nil, languagePopupButton, generalView)
    
    languageApplyButton = uiStandardButton:create(generalView, buttonSize)
    languageApplyButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    languageApplyButton.baseOffset = vec3(4, 0, 0)
    languageApplyButton.relativeView = languagePopupButton
    languageApplyButton.hidden = true
    uiStandardButton:setText(languageApplyButton, locale:get("settings_graphics_Relaunch"))
    uiStandardButton:setClickFunction(languageApplyButton, function()
        controller:reloadAll()
    end)
    uiSelectionLayout:addView(generalView, languageApplyButton)

    --addTitleHeader(generalView, locale:get("settings_Controls"))
    
    addTitleHeader(generalView, locale:get("settings_Audio"))
    
    addSlider(generalView, locale:get("settings_Audio_MusicVolume") .. ":", 0, 10, math.floor(clientGameSettings.values.musicVolume * 10), function(newValue)
        clientGameSettings:changeSetting("musicVolume", newValue / 10.0)
    end)
    
    addSlider(generalView, locale:get("settings_Audio_SoundVolume") .. ":", 0, 10, math.floor(clientGameSettings.values.soundVolume * 10), function(newValue)
        clientGameSettings:changeSetting("soundVolume", newValue / 10.0)
        
        audio:playUISound("audio/sounds/chickenDie.wav")
    end)
    
    addTitleHeader(generalView, locale:get("settings_Other"))

    
    allowLanConnectionsToggleButton = addToggleButton(generalView, locale:get("settings_allowLanConnections") .. ":", clientGameSettings.values.allowLanConnections, function(newValue)
        clientGameSettings:changeSetting("allowLanConnections", newValue)
        updateInviteButton()
    end)


    local chatNotificationOptions = {
        {
            key = "enabled",
            title = locale:get("misc_enabled"),
        },
        {
            key = "messagesOnly",
            title = locale:get("settings_chatNotifications_messagesOnly"),
        },
        {
            key = "disabled",
            title = locale:get("misc_disabled"),
        },
    }

    local chatNotificationSettingsList = {}
    for index,option in ipairs(chatNotificationOptions) do
        table.insert(chatNotificationSettingsList, option.title)
    end
    
    local chatNotificationsPopupButton = addPopUpButton(generalView, generalViewPopOversView, locale:get("settings_chatNotifications") .. ":", chatNotificationSettingsList, function(selectedIndex, selectedTitle)
        clientGameSettings:changeSetting("chatNotifications", chatNotificationOptions[selectedIndex].key)
    end)

    local currentChatNotificationSettingKey = clientGameSettings.values.chatNotifications
    local currentChatNotificationsSelectedIndex = 1

    if currentChatNotificationSettingKey then
        for index,option in ipairs(chatNotificationOptions) do
            if option.key == currentChatNotificationSettingKey then
                currentChatNotificationsSelectedIndex = index
            end
        end
    end

    uiPopUpButton:setSelection(chatNotificationsPopupButton, currentChatNotificationsSelectedIndex)

    --[[local languagesList = {}
    local englishIndex = nil
    local currentSelectedIndex = nil
    local currentLanguageSettingKey = controller:getLocaleSettingKey()
    for i,info in ipairs(orderedInfoList) do
        table.insert(languagesList, info.displayName)
        if info.key == currentLanguageSettingKey then
            currentSelectedIndex = i
        end
        
        if info.key == "en_us" then
            englishIndex = i
        end
    end

    if not currentSelectedIndex then
        currentSelectedIndex = englishIndex or 1
    end

    mj:log("languagesList:", languagesList)

    languagePopupButton = addPopUpButton(generalView, generalViewPopOversView, locale:get("settings_language") .. ":", languagesList, function(selectedIndex, selectedTitle)
        controller:setLocale(orderedInfoList[selectedIndex].key)
        languageApplyButton.hidden = false
    end)
    uiPopUpButton:setSelection(languagePopupButton, currentSelectedIndex)]]


    inviteFriendsButton = uiStandardButton:create(generalView, vec2(buttonSize.x, buttonSize.y))
    inviteFriendsButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    inviteFriendsButton.relativeView = allowLanConnectionsToggleButton
    inviteFriendsButton.baseOffset = vec3(5, 0.0, 0)
    updateInviteButton()
    uiStandardButton:setText(inviteFriendsButton, locale:get("settings_inviteFriends"))
    uiStandardButton:setClickFunction(inviteFriendsButton, function()
        steam:inviteFriends()
    end)
    uiSelectionLayout:addView(generalView, inviteFriendsButton)
    
    
    pauseOnLostFocusToggleButton = addToggleButton(generalView, locale:get("settings_pauseOnLostFocus") .. ":", clientGameSettings.values.pauseOnLostFocus and (not controller.isOnlineClient), function(newValue)
        clientGameSettings:changeSetting("pauseOnLostFocus", newValue)
    end)

    
    local pauseDelayMinutes = math.floor(clientGameSettings.values.inactivityPauseDelay)

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
    updatePauseOnInactivitySliderValueView(pauseDelayMinutes)

    updateEnabledStatesForOnlineClientChange()

    

    addToggleButton(generalView, locale:get("settings_enableTutorialForNewWorlds") .. ":", clientGameSettings.values.enableTutorialForNewWorlds, function(newValue)
        clientGameSettings:changeSetting("enableTutorialForNewWorlds", newValue)
    end)

    
    addButton(generalView, locale:get("reporting_sendBugReport"), function()
        optionsParentView:displayBugReportPanel()
    end)
    

   --[[ if world then
        local button = uiStandardButton:create(generalView, vec2(240, buttonSize.y))
        button.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
        button.relativeView = tutorialToggleButton
        button.baseOffset = vec3(4,0, 0)
        uiStandardButton:setText(button, "Reset tutorial for this world")
        uiStandardButton:setClickFunction(button, function()
            tutorialUI:reset()
        end)
        --elementYOffset = elementYOffset - yOffsetBetweenElements
        uiSelectionLayout:addView(generalView, button)
    end]]

   --[[ notification_displayGroup_informative = "Informative", --0.5
    notification_displayGroup_minorWarning = "Minor Warnings", --0.5
    notification_displayGroup_majorWarning = "Major Warnings", --0.5
    notification_displayGroup_skillsAndResearch = "Skills & Research", --0.5
    notification_displayGroup_favorLost = "Favor Lost", --0.5
    notification_displayGroup_favorGained = "Favor Gained", --0.5
    notification_displayGroup_conflict = "Conflict", --0.7]]


    elementYOffset = elementYOffsetStart

    for i,displayGroup in ipairs(notification.displayGroups) do
        local prefsKey = "notificationDisabled_" .. displayGroup.key
        addToggleButton(notificationsView, displayGroup.name .. ":", not clientGameSettings.values[prefsKey], function(newValue)
            clientGameSettings:changeSetting(prefsKey, not newValue)
        end)
    end
    

    if world then
        elementYOffset = elementYOffsetStart
        uiStandardButton:setDisabled(worldButton, false)

        local clientWorldSettingsDatabase = world:getClientWorldSettingsDatabase()
        local tutorialDisabledForThisWorld = clientWorldSettingsDatabase:dataForKey("tutorialSkipped")

        local function skipTutorialChanged(newIsSkipped)
            if newIsSkipped then
                clientWorldSettingsDatabase:setDataForKey(true, "tutorialSkipped")
            else
                clientWorldSettingsDatabase:removeDataForKey("tutorialSkipped")
            end
            tutorialUI:skipTutorialSettingChanged(newIsSkipped)
        end

        local skipTutorialButton = addToggleButton(worldView, locale:get("settings_enableTutorialForThisWorld") .. ":", (not tutorialDisabledForThisWorld), function(newValue)
            skipTutorialChanged(not newValue)
        end)

        tutorialStoryPanel:setFunctionForSkipTutorialChange(function(newIsSkipped)
            uiStandardButton:setToggleState(skipTutorialButton, not newIsSkipped)
            skipTutorialChanged(newIsSkipped)
        end)

        optionsWorldSettingsView:create(world, worldView, elementYOffset)

    else
        uiStandardButton:setDisabled(worldButton, true)
    end

    
    elementYOffset = elementYOffsetStart

    
    addTitleHeader(graphicsView, locale:get("settings_GeneralGraphics"))

    addSlider(graphicsView, locale:get("settings_graphics_brightness") .. ":", 1, 100, clientGameSettings.values.brightness, function(newValue)
        clientGameSettings:changeSetting("brightness", newValue)
    end)
        
    local resolutionsList = controller:getSupportedScreenResolutionList()
    local multiIndex = nil
    local resolutionDisplayList = {}
    for i,info in ipairs(resolutionsList) do
        if info.type == "native" then
            resolutionDisplayList[i] = string.format("%s (%dx%d)", locale:get("settings_graphics_desktop"), info.x, info.y)
        elseif info.type == "multi" then
            multiIndex = i
            resolutionDisplayList[i] = string.format("%s (%dx%d)", locale:get("settings_graphics_Multi"), info.x, info.y)
        else
            resolutionDisplayList[i] = string.format("%dx%d", info.x, info.y)
        end
    end

    local currentResAndMode = controller:getCurrentScreenResolutionIndexAndMode()
    local graphicsModeChanged = false


    resolutionPopupButton = addPopUpButton(graphicsView, graphicsViewPopOversView, locale:get("settings_graphics_Resolution") .. ":", resolutionDisplayList, function(selectedIndex, selectedTitle)
        graphicsApplyButton.hidden = false
        graphicsModeChanged = true
        if selectedIndex == multiIndex then
            uiPopUpButton:setDisabled(windowModeButton, true)
        else
            uiPopUpButton:setDisabled(windowModeButton, false)
        end
    end)
    uiPopUpButton:setSelection(resolutionPopupButton, currentResAndMode.screenResolutionIndex)
    
    local fullScreenModeList = {
        locale:get("settings_graphics_window"),
        locale:get("settings_graphics_Borderless"),
        locale:get("settings_graphics_FullScreen"),
    }
    windowModeButton = addPopUpButton(graphicsView, graphicsViewPopOversView, locale:get("settings_graphics_Display") .. ":", fullScreenModeList, function(selectedIndex, selectedTitle)
        graphicsApplyButton.hidden = false
        graphicsModeChanged = true
    end)

    local currentModeIndex = currentResAndMode.windowMode
    if currentResAndMode.resolutionType == 3 then --multi
        currentModeIndex = 2
        uiPopUpButton:setDisabled(windowModeButton, true)
    end
    uiPopUpButton:setSelection(windowModeButton, currentModeIndex)
    
    
    graphicsApplyButton = uiStandardButton:create(graphicsView, vec2(buttonSize.x * 0.5, buttonSize.y))
    graphicsApplyButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    graphicsApplyButton.relativeView = resolutionPopupButton
    graphicsApplyButton.baseOffset = vec3(20, -buttonSize.y * 0.5, 0)
    graphicsApplyButton.hidden = true
    uiStandardButton:setText(graphicsApplyButton, locale:get("settings_graphics_Relaunch"))
    uiStandardButton:setClickFunction(graphicsApplyButton, function()
        if graphicsModeChanged then
            controller:selectScreenResolutionAndWindowMode(uiPopUpButton:getSelectedIndex(resolutionPopupButton), uiPopUpButton:getSelectedIndex(windowModeButton))
        else
            controller:reloadAll()
        end
    end)
    uiSelectionLayout:addView(graphicsView, graphicsApplyButton)
    --elementYOffset = elementYOffset - yOffsetBetweenElements
    local fovyDegrees = controller:getFOVYDegrees()
    local fovSlider = nil
    local fovSliderCountView = nil

    fovSlider = addSlider(graphicsView, locale:get("settings_graphics_FOV") .. ":", 20, 120, fovyDegrees, function(newValue)
        controller:setFOVYDegrees(newValue)
        if graphicsApplyButton.hidden then
            graphicsApplyButton.hidden = false
            graphicsApplyButton.relativeView = fovSlider
            graphicsApplyButton.baseOffset = vec3(30, 0, 0)
        end
    end, function(newValue)
        fovSliderCountView.text = string.format("%d", newValue)
    end)

    
    fovSliderCountView = TextView.new(graphicsView)
    fovSliderCountView.font = Font(uiCommon.fontName, 16)
    fovSliderCountView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    fovSliderCountView.relativeView = fovSlider
    fovSliderCountView.baseOffset = vec3(2,0, 0)
    fovSliderCountView.text = string.format("%d", fovyDegrees)
    
    addToggleButton(graphicsView, locale:get("settings_graphics_VSync") .. ":", currentResAndMode.vsync, function(newValue)
        controller:setVsync(newValue)
    end)

    addSlider(graphicsView, locale:get("settings_graphics_terrainContours") .. ":", 1, 100, clientGameSettings.values.contourAlpha * 100.0, function(newValue)
        clientGameSettings:changeSetting("contourAlpha", newValue * 0.01)
    end)

    addTitleHeader(graphicsView, locale:get("settings_Performance"))
    
    
    addSlider(graphicsView, locale:get("settings_Performance_RenderDistance") .. ":", 1, 14, clientGameSettings.values.renderDistance, function(newValue)
        clientGameSettings:changeSetting("renderDistance", newValue)
    end)
    

    addSlider(graphicsView, locale:get("settings_Performance_GrassDistance") .. ":", 1, 10, clientGameSettings.values.grassDistance, function(newValue)
        clientGameSettings:changeSetting("grassDistance", newValue)
    end)

    addSlider(graphicsView, locale:get("settings_Performance_grassDensity") .. ":", 1, 10, clientGameSettings.values.grassDensity, function(newValue)
        clientGameSettings:changeSetting("grassDensity", newValue)
    end)
    
    addSlider(graphicsView, locale:get("settings_Performance_animatedObjectsCount") .. ":", 1, 10, clientGameSettings.values.animatedObjectsCount, function(newValue)
        clientGameSettings:changeSetting("animatedObjectsCount", newValue)
    end)


    addToggleButton(graphicsView, locale:get("settings_Performance_ssao") .. ":", clientGameSettings.values.ssao, function(newValue)
        clientGameSettings:changeSetting("ssao", newValue)
    end)
    

    addToggleButton(graphicsView, locale:get("settings_Performance_bloomEnabled") .. ":", clientGameSettings.values.bloomEnabled, function(newValue)
        clientGameSettings:changeSetting("bloomEnabled", newValue)
    end)

    addToggleButton(graphicsView, locale:get("settings_Performance_highQualityWater") .. ":", clientGameSettings.values.highQualityWater, function(newValue)
        clientGameSettings:changeSetting("highQualityWater", newValue)
    end)
    


    elementYOffset = elementYOffsetStart

    addTitleHeader(controlsView, locale:get("settings_Controls"))

    local cameraControlTypeList = {
        locale:get("settings_Controls_cameraControlType_pointAndClick"),
        locale:get("settings_Controls_cameraControlType_firstPerson3D"),
    }
    local cameraControlTypePopupButton = addPopUpButton(controlsView, controlsViewPopOversView, locale:get("settings_Controls_cameraControlType") .. ":", cameraControlTypeList, function(selectedIndex, selectedTitle)
        local pointAndClickCameraEnabled = (selectedIndex == 1)
        clientGameSettings:changeSetting("pointAndClickCameraEnabled", pointAndClickCameraEnabled)
    end)
    
    local function updateControlTypePopupButton()
        if clientGameSettings.values.pointAndClickCameraEnabled then
            uiPopUpButton:setSelection(cameraControlTypePopupButton, 1)
        else
            uiPopUpButton:setSelection(cameraControlTypePopupButton, 2)
        end
    end

    clientGameSettings:addObserver("pointAndClickCameraEnabled", function(newValue)
        updateControlTypePopupButton()
    end)
    updateControlTypePopupButton()

    addSlider(controlsView, locale:get("settings_Controls_mouseSensitivity") .. ":", 1, 100, clientGameSettings.values.mouseSensitivity * 100.0, function(newValue)
        clientGameSettings:changeSetting("mouseSensitivity", newValue * 0.01)
    end)

    addSlider(controlsView, locale:get("settings_Controls_mouseZoomSensitivity") .. ":", 1, 100, clientGameSettings.values.mouseZoomSensitivity * 100.0, function(newValue)
        clientGameSettings:changeSetting("mouseZoomSensitivity", newValue * 0.01)
    end)

    local invertMouseLookYToggleButton = addToggleButton(controlsView, locale:get("settings_Controls_invertMouseLookY") .. ":", clientGameSettings.values.invertMouseLookY, function(newValue)
        clientGameSettings:changeSetting("invertMouseLookY", newValue)
    end)

    
    local invertMouseLookXTitleTextView = TextView.new(controlsView)
    invertMouseLookXTitleTextView.font = Font(uiCommon.fontName, 16)
    invertMouseLookXTitleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    invertMouseLookXTitleTextView.relativeView = invertMouseLookYToggleButton
    invertMouseLookXTitleTextView.baseOffset = vec3(8,-4, 0)
    invertMouseLookXTitleTextView.text = locale:get("settings_Controls_invertMouseLookX") .. ":"

    local invertMouseLookXButton = uiStandardButton:create(controlsView, vec2(26,26), uiStandardButton.types.toggle)
    invertMouseLookXButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    invertMouseLookXButton.relativeView = invertMouseLookXTitleTextView
    invertMouseLookXButton.baseOffset = vec3(8, 4, 0)
    uiStandardButton:setToggleState(invertMouseLookXButton, clientGameSettings.values.invertMouseLookX)
    
    uiStandardButton:setClickFunction(invertMouseLookXButton, function(newValue)
        clientGameSettings:changeSetting("invertMouseLookX", uiStandardButton:getToggleState(invertMouseLookXButton))
    end)
    uiSelectionLayout:addView(controlsView, invertMouseLookXButton)

    --[[
    local function addToggleButton(parentView, toggleButtonTitle, toggleValue, changedFunction)
        local toggleButton = uiStandardButton:create(parentView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        toggleButton.baseOffset = vec3(elementControlX, elementYOffset, 0)
        uiStandardButton:setToggleState(toggleButton, toggleValue)
        
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = toggleButtonTitle
    
        uiStandardButton:setClickFunction(toggleButton, function()
            changedFunction(uiStandardButton:getToggleState(toggleButton))
        end)

        elementYOffset = elementYOffset - yOffsetBetweenElements
        
        uiSelectionLayout:addView(parentView, toggleButton)
        return toggleButton
    end
    ]]

    addToggleButton(controlsView, locale:get("settings_Controls_invertMouseWheelZoom") .. ":", clientGameSettings.values.invertMouseWheelZoom, function(newValue)
        clientGameSettings:changeSetting("invertMouseWheelZoom", newValue)
    end)

    
    
    addSlider(controlsView, locale:get("settings_Controls_controllerLookSensitivity") .. ":", 1, 100, clientGameSettings.values.controllerLookSensitivity * 100.0, function(newValue)
        clientGameSettings:changeSetting("controllerLookSensitivity", newValue * 0.01)
    end)
    
    addSlider(controlsView, locale:get("settings_Controls_controllerZoomSensitivity") .. ":", 1, 100, clientGameSettings.values.controllerZoomSensitivity * 100.0, function(newValue)
        clientGameSettings:changeSetting("controllerZoomSensitivity", newValue * 0.01)
    end)

    addToggleButton(controlsView, locale:get("settings_Controls_invertControllerLookY") .. ":", clientGameSettings.values.invertControllerLookY, function(newValue)
        clientGameSettings:changeSetting("invertControllerLookY", newValue)
    end)
    addToggleButton(controlsView, locale:get("settings_Controls_enableDoubleTapForFastMovement") .. ":", clientGameSettings.values.enableDoubleTapForFastMovement, function(newValue)
        clientGameSettings:changeSetting("enableDoubleTapForFastMovement", newValue)
    end)

    local reticleList = {
        locale:get("settings_Controls_reticleType_dot"),
        locale:get("settings_Controls_reticleType_bullseye"),
        locale:get("settings_Controls_reticleType_crosshairs"),
    }

    local reticleKeys = mj:enum {
        "dot",
        "bullseye",
        "crosshairs",
    }

    
    local previewOffsets = {
        dot = 120.0,
        bullseye = 200.0,
        crosshairs = 200.0
    }

    
    local crosshairsView = nil
    local reticlePopupButton = nil
    
    local function resizeCrosshairsImage(sizeFraction)
        if crosshairsView then
            local rampedValue = uiCommon:getCrosshairsScale(sizeFraction)
            crosshairsView.size = vec2(rampedValue,rampedValue)
        end
    end

    local function reloadCrosshairsImage()
        if crosshairsView then
            controlsView:removeSubview(crosshairsView)
        end

        crosshairsView = ImageView.new(controlsView)
        local mipmap = true
        local imageName = uiCommon.reticleImagesByTypes[clientGameSettings.values.reticleType] or uiCommon.reticleImagesByTypes.dot
        crosshairsView.imageTexture = MJCache:getTexture(imageName, false, false, mipmap)
        crosshairsView.masksEvents = false
        crosshairsView.relativeView = reticlePopupButton
        crosshairsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        crosshairsView.baseOffset = vec3(previewOffsets[clientGameSettings.values.reticleType], 0.0, 0.0)
        
        resizeCrosshairsImage(clientGameSettings.values.reticleSize)
    end

    reticlePopupButton = addPopUpButton(controlsView, controlsViewPopOversView, locale:get("settings_Controls_reticle") .. ":", reticleList, function(selectedIndex, selectedTitle)
        clientGameSettings:changeSetting("reticleType", reticleKeys[selectedIndex])
        reloadCrosshairsImage()
    end)
    uiPopUpButton:setSelection(reticlePopupButton, reticleKeys[clientGameSettings.values.reticleType] or 1)
    
    addSlider(controlsView, locale:get("settings_Controls_reticleSize") .. ":", 1, 100, clientGameSettings.values.reticleSize * 100.0, function(newValue)
        clientGameSettings:changeSetting("reticleSize", newValue * 0.01)
        resizeCrosshairsImage(newValue * 0.01)
    end,
    function(newValueContinuous)
        resizeCrosshairsImage(newValueContinuous * 0.01)
    end)



    reloadCrosshairsImage()

    --[[
function gameUI:resizeCrosshairs()
    if crosshairsView then
        local sizeFraction = clientGameSettings.values.reticleSize
        local rampedValue = (math.pow(2.0, sizeFraction * 3.0) - 0.75) * 30.792516
        crosshairsView.size = vec2(rampedValue,rampedValue)
    end
end

function gameUI:reloadCrosshairs(reticleType)
    if not world.isVR then
        local wasHidden = false
        if crosshairsView then
            wasHidden = crosshairsView.hidden
            gameUI.worldViews:removeSubview(crosshairsView)
        end

        crosshairsView = ImageView.new(gameUI.worldViews)
        local mipmap = true
        local imageName = gameUI.reticleImagesByTypes[reticleType] or gameUI.reticleImagesByTypes.dot
        crosshairsView.imageTexture = MJCache:getTexture(imageName, false, false, mipmap)
        crosshairsView.masksEvents = false
        crosshairsView.hidden = wasHidden
        gameUI:resizeCrosshairs()

    end
end
    ]]
    
    elementYOffset = elementYOffsetStart

    addToggleButton(debugView, locale:get("settings_Debug_display") .. ":", clientGameSettings.values.renderDebug, function(newValue)
        clientGameSettings:changeSetting("renderDebug", newValue)
    end)

    if world then
        
        if gameConstants.showCheatButtons then
            addButton(debugView, locale:get("settings_Debug_setSunrise"), function()
                world:setSunrise()
            end)
            
            addButton(debugView, locale:get("settings_Debug_setMidday"), function()
                world:setMidday()
            end)
            
            addButton(debugView, locale:get("settings_Debug_setSunset"), function()
                world:setSunset(-0.4)
            end)
        end

        --[[addButton(debugView, locale:get("settings_Debug_startLockCamera"), function()
            gameUI:startLockCamera()
        end)]]
        
        addButton(debugView, locale:get("settings_Debug_startServerProfile"), function()
            world:startServerProfile()
        end)
        
        addButton(debugView, locale:get("settings_Debug_startLogicProfile"), function()
            world:startLogicProfile()
        end)
        
        addButton(debugView, locale:get("settings_Debug_startMainThreadProfile"), function()
            world:startMainThreadProfile()
        end)

        addButton(debugView, locale:get("settings_Debug_toggleAnchorMarkers"), function()
            world:toggleDebugAnchors()
        end)


        local exitTitleTextView = TextView.new(exitView)
        exitTitleTextView.font = Font(uiCommon.fontName, 24)
        exitTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        exitTitleTextView.baseOffset = vec3(0,-40,0)
        exitTitleTextView.color = mj.textColor
        exitTitleTextView.text = locale:get("settings_exitAreYouSure")

        local descriptionTextView = TextView.new(exitView)
        descriptionTextView.font = Font(uiCommon.fontName, 16)
        descriptionTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        descriptionTextView.relativeView = exitTitleTextView
        descriptionTextView.baseOffset = vec3(0,-10,0)
        descriptionTextView.color = mj.textColor
        descriptionTextView.text = locale:get("settings_exitAreYouSure_info")

        local hibernationChangeQueued = false
        local exitToMenuQueued = false
        local exitToDesktopQueued = false

        elementYOffset = -140

       -- if world:getIsOnlineClient() then
            local hibernateList = {
                locale:get("settings_exit_hibernate_now"),
                locale:get("settings_exit_hibernate_oneDay"),
                locale:get("settings_exit_hibernate_twoDays"),
            }
            local hibernateDelayTypes = mj:indexed { --using keys for furture proofing, in case we want "year" or "tasksComplete"
                {
                    key = "now",
                },
                {
                    key = "oneDay",
                },
                {
                    key = "twoDays",
                }
            }

            
            local exitHibernationPopupButton = addPopUpButton(exitView, exitViewPopOversView, locale:get("settings_exit_hibernate") .. ":", hibernateList, function(selectedIndex, selectedTitle)
                hibernationChangeQueued = true
                --clientGameSettings:changeSetting("hibernationDelayKey", hibernateDelayTypes[selectedIndex].key)
                logicInterface:callServerFunction("changeHibernationOnExitDuration", hibernateDelayTypes[selectedIndex].key, function()
                    hibernationChangeQueued = false
                    if exitToMenuQueued then
                        controller:exitToMenu()
                    elseif exitToDesktopQueued then
                        controller:exitToDesktop()
                    end
                end)
            end)
            --exitHibernationPopupButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
           -- exitHibernationPopupButton.baseOffset = vec3(0,30 + 100, 0)


            local serverClientState = world:getServerClientState()
            local hibernationDurationKey = serverClientState.privateShared.hibernationDurationKey
            local hibernationDelayIndex = 1
            if hibernationDurationKey then
                local hibernationDelayInfo = hibernateDelayTypes[hibernationDurationKey]
                if hibernationDelayInfo then
                    hibernationDelayIndex = hibernationDelayInfo.index
                end
            end
    
            uiPopUpButton:setSelection(exitHibernationPopupButton, hibernationDelayIndex)

            
            uiToolTip:add(exitHibernationPopupButton, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("settings_exit_hibernate_helpInfoText"), nil, vec3(0,-8,10), nil, exitHibernationPopupButton, exitView)

       -- end

        
        local exitToMenuButton = uiStandardButton:create(exitView, vec2(200,40))
        exitToMenuButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        exitToMenuButton.baseOffset = vec3(0,elementYOffset - 4, 0)
        uiStandardButton:setText(exitToMenuButton, locale:get("settings_exitMainMenu"))
        uiStandardButton:setClickFunction(exitToMenuButton, function ()
            if hibernationChangeQueued then
                exitToMenuQueued = true
                exitToDesktopQueued = false
            else
                controller:exitToMenu()
            end
        end)
        uiSelectionLayout:addView(exitView, exitToMenuButton)
        elementYOffset = elementYOffset - yOffsetBetweenElements
        
        local exitToDesktopButton = uiStandardButton:create(exitView, vec2(200,40))
        exitToDesktopButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
        exitToDesktopButton.baseOffset = vec3(0,elementYOffset - 4, 0)
        uiStandardButton:setText(exitToDesktopButton, locale:get("settings_exitDesktop"))
        uiStandardButton:setClickFunction(exitToDesktopButton, function ()
            if hibernationChangeQueued then
                exitToDesktopQueued = true
                exitToMenuQueued = false
            else
                controller:exitToDesktop()
            end
        end)
        uiSelectionLayout:addView(exitView, exitToDesktopButton)
    end
end

function optionsView:load(containerView_, world_, gameUI_, controller_, manageUIOrNIl, optionsParentView)
    if containerView ~= containerView_ then
        if containerView then
            containerView:removeSubview(mainView)
            keyBindingsScrollView = nil
        end
        containerView = containerView_
        
        world = world_
        --gameUI = gameUI_
        controller = controller_
        init(manageUIOrNIl, optionsParentView)
    end
end

function optionsView:getTitle()
    return titleString
end

function optionsView:backButtonClicked()
    if activeSelectedControllableSubView then
        --if currentPopOversView then
        if uiPopUpButton:popupMenuVisible(resolutionPopupButton) then
            uiPopUpButton:hidePopupMenu(resolutionPopupButton)
        elseif uiPopUpButton:popupMenuVisible(windowModeButton) then
            uiPopUpButton:hidePopupMenu(windowModeButton)
        else
            changeActiveSelectedControlView(nil)
        end
        return true
    end
    return false
end

function optionsView:parentBecameHidden()
    if activeSelectedControllableSubView then
        changeActiveSelectedControlView(nil)
    end
    uiSelectionLayout:removeActiveSelectionLayoutView(tabButtonsView)
end

function optionsView:parentBecameVisible()
    updateEnabledStatesForOnlineClientChange()
    uiSelectionLayout:setActiveSelectionLayoutView(tabButtonsView)
    if currentView and currentView.userData and currentView.userData.parentBecameVisible then
        currentView.userData.parentBecameVisible()
    end
end

return optionsView