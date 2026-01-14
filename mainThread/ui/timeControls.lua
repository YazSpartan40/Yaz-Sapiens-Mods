local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local mat3Rotate = mjm.mat3Rotate
local mat3Identity = mjm.mat3Identity

local locale = mjrequire "common/locale"

local model = mjrequire "common/model"
local weather = mjrequire "common/weather"
local gameConstants = mjrequire "common/gameConstants"
local material = mjrequire "common/material"

--local keyMapping = mjrequire "mainThread/keyMapping"
local audio = mjrequire "mainThread/audio"

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local pauseUI = mjrequire "mainThread/ui/pauseUI"

local timeControls = {}

local mainView = nil

local buttonsBySpeedIndex = {}
local currentServerSpeedIndex = nil
local currentLocalSpeedIndex = nil

local clockBackground = nil
local temperatureWarningIconView = nil
local populationTextView = nil
local dayCountTextView = nil
local panelView = nil
local ffButton = nil

local currentlyUltraSpeed = false

local toolTipOffset = vec3(0,-10,0)

local function setPaused(newPaused)
    if newPaused then
        pauseUI:show()
    else
        pauseUI:hide()
    end
end


local function serverSpeedMultiplierChanged(speedMultiplier, speedMultiplierIndex)

    --mj:log("speedMultiplierChanged:", speedMultiplier, " speedMultiplierIndex:", speedMultiplierIndex, " currentSpeedIndex:", currentSpeedIndex)

    local newIsUltraSpeed = false
    if speedMultiplier > gameConstants.fastSpeed + 0.5 then
        newIsUltraSpeed = true
    end

    if newIsUltraSpeed ~= currentlyUltraSpeed then
        currentlyUltraSpeed = newIsUltraSpeed
        if newIsUltraSpeed then
            audio:playUISound("audio/sounds/ui/speedup.wav")
        else
            audio:playUISound("audio/sounds/ui/slowdown.wav")
        end
    end

    if currentServerSpeedIndex ~= speedMultiplierIndex then
        if currentServerSpeedIndex ~= nil then
            local button = buttonsBySpeedIndex[currentServerSpeedIndex]
            uiStandardButton:setSelected(button, false)
        end

        currentServerSpeedIndex = speedMultiplierIndex
        if not buttonsBySpeedIndex[currentServerSpeedIndex] then
            if currentServerSpeedIndex > 2 then
                currentServerSpeedIndex = 2
            else
                currentServerSpeedIndex = 1
            end
        end

        local button = buttonsBySpeedIndex[currentServerSpeedIndex]
        uiStandardButton:setSelected(button, true)

        setPaused(currentServerSpeedIndex == 0)

    end
end


function timeControls:updateLocalSpeedPreference(speedMultiplierIndex)
    if speedMultiplierIndex ~= currentLocalSpeedIndex then
        if currentLocalSpeedIndex ~= nil then
            local button = buttonsBySpeedIndex[currentLocalSpeedIndex]
            uiStandardButton:setSecondarySelected(button, false)
        end

        currentLocalSpeedIndex = speedMultiplierIndex

        local button = buttonsBySpeedIndex[currentLocalSpeedIndex]
        uiStandardButton:setSecondarySelected(button, true)
        
        setPaused(currentServerSpeedIndex == 0)
    end
end

function timeControls:getLocalSpeedPreference()
    return currentLocalSpeedIndex or 0
end

function timeControls:init(gameUI, world)

    mainView = View.new(gameUI.view)
    mainView.hidden = false
    mainView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    mainView.baseOffset = vec3(10.0, -10.0, 0.0)

    local circleViewSize = 60.0
    local panelSizeToUse = vec2(170.0, 60.0)
    local panelXOffset = -30.0
    mainView.size = vec2(circleViewSize + panelSizeToUse.x - panelXOffset, 60.0)

    local circleBackgroundScale = circleViewSize * 0.5

    clockBackground = ModelView.new(mainView)
    clockBackground:setModel(model:modelIndexForName("ui_clockBackground"))
    clockBackground.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    clockBackground.scale3D = vec3(circleBackgroundScale,circleBackgroundScale,circleBackgroundScale)
    clockBackground.size = vec2(circleViewSize, circleViewSize)
    clockBackground.baseOffset = vec3(0.0, 0.0, 0.0)
    clockBackground.alpha = 0.9

    local clockHand = ModelView.new(mainView)
    clockHand:setModel(model:modelIndexForName("ui_clockMark"))
    clockHand.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    clockHand.relativeView = clockBackground
    clockHand.scale3D = vec3(circleBackgroundScale,circleBackgroundScale,circleBackgroundScale)
    clockHand.size = vec2(circleViewSize, circleViewSize)
    clockHand.baseOffset = vec3(0.0, 0.0, 0.02 * circleBackgroundScale)
    clockHand.masksEvents = false

    clockHand.update = function(dt)
        local timeOfDayFraction = world:getTimeOfDayFraction()
        local zRotation = (timeOfDayFraction + 0.5) * math.pi * 2.0
        clockHand.rotation = mat3Rotate(mat3Identity, zRotation, vec3(0.0,0.0,-1.0))
    end

    
    local warningHalfSize = 10.0
    temperatureWarningIconView = ModelView.new(clockBackground)
    --temperatureWarningIconView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    temperatureWarningIconView.baseOffset = vec3(1.0,0.0,0.0)
    temperatureWarningIconView.scale3D = vec3(warningHalfSize,warningHalfSize,warningHalfSize)
    temperatureWarningIconView.size = vec2(warningHalfSize, warningHalfSize) * 2.0
    uiToolTip:add(clockBackground, ViewPosition(MJPositionOuterRight, MJPositionBelow), locale:get("weather_temperatureZone_veryCold"), nil, vec3(-30,-10,10), nil, clockBackground)
    temperatureWarningIconView.hidden = true

    local panelScaleToUseX = panelSizeToUse.x * 0.5
    local panelScaleToUseY = panelSizeToUse.y * 0.5 / 0.2
    
    panelView = ModelView.new(mainView)
    panelView:setModel(model:modelIndexForName("ui_panel_10x2"))
    panelView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    panelView.relativeView = clockBackground
    panelView.baseOffset = vec3(panelXOffset, 0.0, -2)
    panelView.scale3D = vec3(panelScaleToUseX,panelScaleToUseY,panelScaleToUseX)
    panelView.size = panelSizeToUse
    panelView.alpha = 0.9

    local timeButtonSize = 30.0
    local timeButtonInitialXOffsetWithinPanel = 45.0
    local timeButtonInitialYOffsetWithinPanel = -6.0
    local timeButtonXPadding = 10.0

    
    dayCountTextView = TextView.new(panelView)
    dayCountTextView.font = Font(uiCommon.fontName, 14)
    dayCountTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    dayCountTextView.baseOffset = vec3(0,-4,0)
    dayCountTextView.text = ""
    
    local lastTribeAgeDays = 0
    dayCountTextView.update = function(dt)
        local timeOfDayFraction = world:getTimeOfDayFraction()
        local tribeAge = world:getTribeAge() --world:getTribeAge just returns the age of the world at the moment
        local dayLength = world:getDayLength()
        local tribeAgeDays = math.floor((tribeAge - timeOfDayFraction * dayLength) / dayLength) + 2
        if tribeAgeDays > lastTribeAgeDays then
            lastTribeAgeDays = tribeAgeDays
            dayCountTextView.text = string.format("Day %d", tribeAgeDays)
        end
    end
    
    local pauseButton = uiStandardButton:create(panelView, vec2(timeButtonSize,timeButtonSize), uiStandardButton.types.timeControl)
    pauseButton.userData.selectionCircleMaterial = material.types.ui_red.index
    pauseButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    pauseButton.baseOffset = vec3(timeButtonInitialXOffsetWithinPanel, timeButtonInitialYOffsetWithinPanel, 2)
    uiStandardButton:setIconModel(pauseButton, "icon_pause")
    buttonsBySpeedIndex[0] = pauseButton
    uiStandardButton:setClickFunction(pauseButton, function()
        world:setPaused()
        timeControls:updateLocalSpeedPreference(0)
    end)
    uiToolTip:add(pauseButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("misc_Toggle") .. " " .. locale:get("ui_pause"), nil, toolTipOffset, nil, pauseButton)
    uiToolTip:addKeyboardShortcut(pauseButton.userData.backgroundView, "game", "pause", nil, nil)
    
    local playButton = uiStandardButton:create(panelView, vec2(timeButtonSize,timeButtonSize), uiStandardButton.types.timeControl)
    playButton.relativeView = pauseButton
    playButton.userData.selectionCircleMaterial = material.types.ui_green.index
    playButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    playButton.baseOffset = vec3(timeButtonXPadding, 0, 0)
    uiStandardButton:setIconModel(playButton, "icon_play")
    buttonsBySpeedIndex[1] = playButton
    uiStandardButton:setClickFunction(playButton, function()
        world:setPlay()
        timeControls:updateLocalSpeedPreference(1)
    end)
    uiToolTip:add(playButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_play"), nil, toolTipOffset, nil, playButton)
    
    
    ffButton = uiStandardButton:create(panelView, vec2(timeButtonSize,timeButtonSize), uiStandardButton.types.timeControl)
    ffButton.relativeView = playButton
    ffButton.userData.selectionCircleMaterial = material.types.ui_selected.index
    ffButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    ffButton.baseOffset = vec3(timeButtonXPadding, 0, 0)
    uiStandardButton:setIconModel(ffButton, "icon_fastForward")
    buttonsBySpeedIndex[2] = ffButton
    uiStandardButton:setClickFunction(ffButton, function()
        world:setFastForward()
        timeControls:updateLocalSpeedPreference(2)
    end)
    uiToolTip:add(ffButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("misc_Toggle") .. " " .. locale:get("ui_fastForward"), nil, toolTipOffset, nil, ffButton)
    uiToolTip:addKeyboardShortcut(ffButton.userData.backgroundView, "game", "speedFast", nil, nil)


    dayCountTextView.relativeView = pauseButton
    
    populationTextView = TextView.new(panelView)
    populationTextView.font = Font(uiCommon.fontName, 14)
    populationTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    populationTextView.baseOffset = vec3(10,0,0)
    populationTextView.text = "Pop"
    populationTextView.relativeView = dayCountTextView

    world:addSpeedChangeListener(serverSpeedMultiplierChanged)
    timeControls:updateLocalSpeedPreference(1)
    serverSpeedMultiplierChanged(world:getSpeedMultiplier(), world:getSpeedMultiplierIndex())
end

function timeControls:setHiddenForTribeSelection(newHidden)
    mainView.hidden = newHidden
end

local currentTemperatureIndex = nil

function timeControls:playerTemperatureZoneChanged(newTemperatureZoneIndex)
    --temperatureTextView.text = weather.temperatureZones[newTemperatureZoneIndex].name

    if currentTemperatureIndex ~= newTemperatureZoneIndex then
        currentTemperatureIndex = newTemperatureZoneIndex
        if newTemperatureZoneIndex == weather.temperatureZones.veryCold.index then
            --[[clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_thermo_vcold.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_standard.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_standard.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_standard.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_standard.index,
            })]]
            
            clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_background.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_background.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_background.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_background.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_background.index,
            })
            
            temperatureWarningIconView:setModel(model:modelIndexForName("icon_snow"), {
                default = material.types.ui_thermo_vcold.index
            })
            temperatureWarningIconView.hidden = false
            uiToolTip:updateText(clockBackground, locale:get("weather_temperatureZone_veryCold"))

        elseif newTemperatureZoneIndex == weather.temperatureZones.cold.index then
            clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_thermo_cold.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_thermo_cold.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_standard.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_standard.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_standard.index,
            })

            temperatureWarningIconView.hidden = true
            uiToolTip:updateText(clockBackground, locale:get("weather_temperatureZone_cold"))

        elseif newTemperatureZoneIndex == weather.temperatureZones.moderate.index then
            clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_thermo_warm.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_thermo_warm.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_thermo_warm.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_standard.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_standard.index,
            })

            temperatureWarningIconView.hidden = true
            uiToolTip:updateText(clockBackground, locale:get("weather_temperatureZone_moderate"))

        elseif newTemperatureZoneIndex == weather.temperatureZones.hot.index then
            clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_thermo_hot.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_thermo_hot.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_thermo_hot.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_thermo_hot.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_standard.index,
            })

            temperatureWarningIconView.hidden = true
            uiToolTip:updateText(clockBackground, locale:get("weather_temperatureZone_hot"))

        elseif newTemperatureZoneIndex == weather.temperatureZones.veryHot.index then
            --[[clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_thermo_vhot.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_thermo_vhot.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_thermo_vhot.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_thermo_vhot.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_thermo_vhot.index,
            })]]
                
            clockBackground:setModel(model:modelIndexForName("ui_clockBackground"), {
                [material.types.ui_thermo_vcold.index] = material.types.ui_background.index,
                [material.types.ui_thermo_cold.index] = material.types.ui_background.index,
                [material.types.ui_thermo_warm.index] = material.types.ui_background.index,
                [material.types.ui_thermo_hot.index] = material.types.ui_background.index,
                [material.types.ui_thermo_vhot.index] = material.types.ui_background.index,
            })

            temperatureWarningIconView:setModel(model:modelIndexForName("icon_fire"), {
                default = material.types.ui_thermo_vhot.index
            })
            temperatureWarningIconView.hidden = false
            uiToolTip:updateText(clockBackground, locale:get("weather_temperatureZone_veryHot"))

        end
    end
end

function timeControls:setFastForwardDisabledByServer(newIsThrottled)
    if newIsThrottled then
        uiStandardButton:setDisabled(ffButton, true)
        uiToolTip:remove(ffButton.userData.backgroundView)
        uiToolTip:add(ffButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_fastForwardDisabledDueToServerLoad"), nil, toolTipOffset, nil, ffButton)
    else
        uiStandardButton:setDisabled(ffButton, false)
        uiToolTip:remove(ffButton.userData.backgroundView)
        uiToolTip:add(ffButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("misc_Toggle") .. " " .. locale:get("ui_fastForward"), nil, toolTipOffset, nil, ffButton)
        uiToolTip:addKeyboardShortcut(ffButton.userData.backgroundView, "game", "speedFast", nil, nil)
    end
end

function timeControls:setPopulation(newPopulation)
    if newPopulation then
        populationTextView.text = string.format("Pop. %d", newPopulation)
    else
        populationTextView.text = ""
    end
end

local connectionAlertIcon = nil
function timeControls:setPingValue(currentPingValue)
    if currentPingValue > 10.0 then
        if not connectionAlertIcon then

            connectionAlertIcon = ModelView.new(mainView)
            local iconSize = 30
            connectionAlertIcon.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
            connectionAlertIcon.relativeView = panelView
            connectionAlertIcon.baseOffset = vec3(10, 0.0, 0)
            connectionAlertIcon.scale3D = vec3(iconSize,iconSize,iconSize) * 0.5
            connectionAlertIcon.size = vec2(iconSize, iconSize)

            uiToolTip:add(connectionAlertIcon, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_slowConnection"), nil, toolTipOffset, nil, nil)

            local animationTimer = 0.0
            connectionAlertIcon.update = function(dt)
                local timerValue = animationTimer or 0.0
                timerValue = timerValue + dt
                animationTimer = timerValue
                local animationAddition = (1.0 + math.sin(timerValue * 5.0)) * 0.5
                --local iconSizeAnimated = iconSize * (1.0 + animationAddition * 0.1)
                --connectionAlertIcon.scale3D = vec3(iconSizeAnimated,iconSizeAnimated,iconSizeAnimated) * 0.5
                --connectionAlertIcon.size = vec2(iconSizeAnimated, iconSizeAnimated)
                connectionAlertIcon.alpha = 1.0 + animationAddition
            end
        end
        connectionAlertIcon.hidden = false
        if currentPingValue > gameConstants.disconnectDelayThreshold * 0.5 then
            connectionAlertIcon:setModel(model:modelIndexForName("icon_connectionAlert"), {
                [material.types.ui_standard.index] = material.types.ui_red.index,
            })
        else
            connectionAlertIcon:setModel(model:modelIndexForName("icon_connectionAlert"), {
                [material.types.ui_standard.index] = material.types.ui_yellow.index,
            })
        end
    elseif connectionAlertIcon then
        connectionAlertIcon.hidden = true
    end
end


return timeControls