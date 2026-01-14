local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

local model = mjrequire "common/model"
local notification = mjrequire "common/notification"
local audio = mjrequire "mainThread/audio"
local eventManager = mjrequire "mainThread/eventManager"
local notificationSound = mjrequire "common/notificationSound"
local timer = mjrequire "common/timer"
--local grievance = mjrequire "common/grievance"
local material = mjrequire "common/material"
local gameObject = mjrequire "common/gameObject"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"
local uiFavorView = mjrequire "mainThread/ui/uiCommon/uiFavorView"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"

local mainThreadDestination = mjrequire "mainThread/mainThreadDestination"

local notificationsUI = {}

local soundPlayDelays = {}

local gameUI = nil
local logicInterface = nil

local mainView = nil


notificationsUI.messageViewInfos = {}
local topIndex = nil
local zoomIndex = nil
local nextIndex = 1

local fadeOutTimeAfterReceivingMessage = 30.0
local zoomShortcutKeyImageFullAlpha = 0.67

local minDelayBetweenNotifcations = 1.0

local minDelayBetweenNotifcationMainSoundPlays = 10.0

local zoomInfo = nil

local delayTimer = 0.0
local queuedNotifications = {}

local zoomShortcutKeyImage = nil

function notificationsUI:setPosition(messageViewInfo)
    local aboveMessageInfo = notificationsUI.messageViewInfos[messageViewInfo.index - 1]
    local yOffset = -10.0
    if aboveMessageInfo then
        yOffset = aboveMessageInfo.backgroundView.baseOffset.y - aboveMessageInfo.backgroundView.size.y - 4
    else
        if messageViewInfo.fadeOutValue and messageViewInfo.fadeOutValue > 0.5 then
            local offsetMix = (messageViewInfo.fadeOutValue - 0.5) * 2.0
            offsetMix = math.pow(offsetMix, 0.7)
            yOffset = mjm.mix(-2, messageViewInfo.backgroundView.size.y - 10, offsetMix)
        end
    end
    messageViewInfo.backgroundView.baseOffset = vec3(-10, yOffset, -8)
end

function notificationsUI:updateAllPositions()
    if topIndex then
        for i=topIndex,nextIndex - 1 do
            local messageViewInfo = notificationsUI.messageViewInfos[i]
            if messageViewInfo then
                notificationsUI:setPosition(messageViewInfo)
            end
        end
    end
end

local function removeNotification(messageViewInfo)
    if topIndex == messageViewInfo.index then
        local belowMessageInfo = notificationsUI.messageViewInfos[messageViewInfo.index + 1]
        if belowMessageInfo then
            topIndex = belowMessageInfo.index
        else
            topIndex = nil
            mainView.hidden = true
            zoomInfo = nil
            zoomIndex = nil
            tutorialUI:setNotificationIsVisible(false)
            zoomShortcutKeyImage.relativeView = mainView
        end
    end

    mainView:removeSubview(messageViewInfo.backgroundView)
    notificationsUI.messageViewInfos[messageViewInfo.index] = nil
    notificationsUI:updateAllPositions()
end

local function displayNotification(notificationInfo, objectInfo, title)
    
    local notificationTypeIndex = notificationInfo.notificationTypeIndex
    local userData = notificationInfo.userData

    local displayGroupTypeIndex = notification.types[notificationTypeIndex].displayGroupTypeIndex or notification.displayGroups.standard.index
    
    local prefsKey = "notificationDisabled_" .. notification.displayGroups[displayGroupTypeIndex].key
    if clientGameSettings.values[prefsKey] then
        return
    end

    mainView.hidden = false

    local backgroundView = View.new(mainView)
    backgroundView.size = vec2(60.0, 60.0)
    backgroundView.relativeView = mainView
    backgroundView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    backgroundView.alpha = 0.9

    local colorType = notification.displayGroups[displayGroupTypeIndex]
    local materialCircle = colorType.foregroundMaterial
    local backgroundMaterialText = colorType.backgroundMaterial
    
    local circleView = ModelView.new(backgroundView)
    circleView:setModel(model:modelIndexForName("ui_circleBackgroundLargeOutline"), {
        [material.types.ui_background.index] = backgroundMaterialText,
        [material.types.ui_standard.index] = materialCircle,
    })
    circleView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    
    local circleViewSize = 60.0
    local circleBackgroundScale = circleViewSize * 0.5
    circleView.scale3D = vec3(circleBackgroundScale,circleBackgroundScale,circleBackgroundScale)
    circleView.size = vec2(circleViewSize, circleViewSize)
    circleView.baseOffset = vec3(0.0, 0.0, 0.0)

    local panelView = ModelView.new(backgroundView)
    panelView:setModel(model:modelIndexForName("ui_panel_10x2"), {
        default = backgroundMaterialText
    })
    panelView.relativeView = circleView
    panelView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    panelView.baseOffset = vec3(-circleViewSize * 0.5, 0.0, -1)
    panelView.alpha = 0.9

    local penalty = userData.penalty or userData.cost

    if objectInfo and objectInfo.objectTypeIndex == gameObject.types.sapien.index and objectInfo.sharedState then
        local objectImageViewSizeMultiplier = 0.97
        local objectImageView = uiGameObjectView:create(circleView, vec2(circleViewSize, circleViewSize) * objectImageViewSizeMultiplier, uiGameObjectView.types.standard)
        uiGameObjectView:setObject(objectImageView, objectInfo, nil, nil)
    elseif userData.grievanceTypeIndex then
        local favorView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1)
        --favorView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        uiFavorView:setValue(favorView, -userData.favorPenaltyTaken, false)
        favorView.baseOffset = vec3(-4,0,0)
    elseif userData.reward then
        local favorView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1)
        uiFavorView:setValue(favorView, userData.reward, false)
        favorView.baseOffset = vec3(-4,0,0)
    elseif penalty then
        local favorView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1)
        uiFavorView:setValue(favorView, -penalty, false)
        favorView.baseOffset = vec3(-4,0,0)
    elseif objectInfo and objectInfo.objectTypeIndex then
        local objectImageViewSizeMultiplier = 0.97
        local objectImageView = uiGameObjectView:create(circleView, vec2(circleViewSize, circleViewSize) * objectImageViewSizeMultiplier, uiGameObjectView.types.standard)
        uiGameObjectView:setObject(objectImageView, objectInfo, nil, nil)
    else
        mj:error("missing info in displayNotification objectInfo:", objectInfo, " userData:", userData)
        error()
    end

    --[[if userData.reward then
        local favorView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1)
        uiFavorView:setValue(favorView, userData.reward, false)
        favorView.baseOffset = vec3(-4,0,0)
    elseif userData.grievanceTypeIndex then
        local favorView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1)
        --favorView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        uiFavorView:setValue(favorView, -userData.favorPenaltyTaken, false)
        favorView.baseOffset = vec3(-4,0,0)
    elseif objectInfo and objectInfo.objectTypeIndex then
        local objectImageViewSizeMultiplier = 0.97
        local objectImageView = uiGameObjectView:create(circleView, vec2(circleViewSize, circleViewSize) * objectImageViewSizeMultiplier, uiGameObjectView.types.standard)
        uiGameObjectView:setObject(objectImageView, objectInfo, nil, nil)
    end]]

    --[[

            local objectView = nil
            local objectInfo = notification:getObjectInfo(notificationInfo)
            if objectInfo.objectTypeIndex == gameObject.types.sapien.index then
                objectView = GameObjectView.new(circleView, vec2(sapienIconSize, sapienIconSize))
                objectView.size = vec2(sapienIconSize, sapienIconSize)
                objectView.baseOffset = vec3(0,0,1)

                local animationInstance = uiAnimation:getUIAnimationInstance(sapienConstants:getAnimationGroupKey(objectInfo.sharedState))
                uiCommon:setGameObjectViewObject(objectView, objectInfo, animationInstance)
            elseif notificationInfo.userData.grievanceTypeIndex then
                objectView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1_small)
                --favorView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
                uiFavorView:setValue(objectView, -notificationInfo.userData.favorPenaltyTaken, false)
                --objectView.baseOffset = vec3(-4,0,0)
            elseif notificationInfo.userData.reward then
                objectView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1_small)
                uiFavorView:setValue(objectView, notificationInfo.userData.reward, false)
            elseif notificationInfo.userData.penalty then
                objectView = uiFavorView:create(circleView, uiFavorView.types.noBackground_notification_1x1_small)
                uiFavorView:setValue(objectView, -notificationInfo.userData.penalty, false)
            else
                mj:error("missing info:", notificationInfo)
            end
    ]]

    local textView = TextView.new(panelView)
    textView.font = Font(uiCommon.fontName, 16)
    textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    textView.baseOffset = vec3(-38,-4,0)
    textView.text = title
    
    --[[local descriptionTextView = nil

    if description then
        descriptionTextView = TextView.new(panelView)
        descriptionTextView.font = Font(uiCommon.fontName, 16)
        descriptionTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
        descriptionTextView.relativeView = textView
        descriptionTextView.baseOffset = vec3(-2,0,0)
        descriptionTextView.text = description
    end]]

    local messageViewInfo = {
        backgroundView = backgroundView,
        index = nextIndex,
        fadeOutTimer = 0.0,
        notificationTypeIndex = notificationTypeIndex,
        objectInfo = objectInfo,
        panelView = panelView,
    }
    
    zoomShortcutKeyImage.relativeView = panelView
    zoomShortcutKeyImage.alpha = zoomShortcutKeyImageFullAlpha

    zoomInfo = objectInfo
    zoomIndex = messageViewInfo.index
    

    nextIndex = nextIndex + 1

    if not topIndex then
        topIndex = messageViewInfo.index
    end
    notificationsUI.messageViewInfos[messageViewInfo.index] = messageViewInfo
    notificationsUI:setPosition(messageViewInfo)

    local textWidth = textView.size.x
    local textHeight = textView.size.y
   --[[ if descriptionTextView then
        textHeight = textHeight + descriptionTextView.size.y
        textWidth = math.max(textWidth, descriptionTextView.size.x)
    end]]

    local sizeToUse = vec2(textWidth + 38 + 4, textHeight + 8)
    local scaleToUseX = sizeToUse.x * 0.5
    local scaleToUseY = sizeToUse.y * 0.5 / 0.2
    panelView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
    panelView.size = sizeToUse

    local buttonTable = {
        selected = false,
        mouseDown = false,
    }
    
    backgroundView.hoverStart = function (mouseLoc)
        if not buttonTable.hover then
            if not buttonTable.disabled then
                buttonTable.hover = true
                audio:playUISound(uiCommon.hoverSoundFile)
                --mj:log("hover start")
                --updateVisuals(wheelSegment, buttonTable)
            end
        end
    end

    backgroundView.hoverEnd = function ()
        if buttonTable.hover then
            buttonTable.hover = false
            buttonTable.mouseDown = false
            --mj:log("hover end")
            --updateVisuals(wheelSegment, buttonTable)
        end
    end

    backgroundView.mouseDown = function (buttonIndex)
        if buttonIndex == 0 then
            if not buttonTable.mouseDown then
                if not buttonTable.disabled then
                    buttonTable.mouseDown = true
                    --mj:log("mouseDown")
                    --updateVisuals(wheelSegment, buttonTable)
                    audio:playUISound(uiCommon.clickDownSoundFile)
                end
            end
        end
    end

    backgroundView.mouseUp = function (buttonIndex)
        if buttonIndex == 0 then
            if buttonTable.mouseDown then
                buttonTable.mouseDown = false
                --updateVisuals(wheelSegment, buttonTable)
                audio:playUISound(uiCommon.clickReleaseSoundFile)
            end
           -- mj:log("clickFunction")
            if not buttonTable.disabled then
                if objectInfo.objectTypeIndex then
                    logicInterface:callLogicThreadFunction("retrieveObject", objectInfo.uniqueID, function(result)
                        if result and result.found then
                            gameUI:followObject(result, false, {dismissAnyUI = true, showInspectUI = true})
                        else
                            gameUI:teleportToLookAtPos(objectInfo.pos)
                        end
                    end)
                elseif objectInfo.tribeID then
                    local destinationInfo = mainThreadDestination.destinationInfosByID[objectInfo.tribeID]
                    gameUI:hideAllUI()
                    tribeRelationsUI:show(destinationInfo, nil, nil, nil, false)
                end
            end
        end
    end

    
    local hoverOffset = 2.0
    local offsetUpdateFunction = uiCommon:createButtonUpdateFunction(buttonTable, backgroundView, hoverOffset)

    messageViewInfo.updateFunction = function(dt)
        offsetUpdateFunction(dt)
        messageViewInfo.fadeOutTimer = messageViewInfo.fadeOutTimer + dt * 2.0
        if messageViewInfo.fadeOutTimer < fadeOutTimeAfterReceivingMessage then
            local fadeOutValue = messageViewInfo.fadeOutTimer - fadeOutTimeAfterReceivingMessage + 1.0
            messageViewInfo.fadeOutValue = fadeOutValue
            if fadeOutValue > 0.0 then
                messageViewInfo.backgroundView.alpha = math.max(0.9 - fadeOutValue * 2.0, 0.0);
                if zoomIndex == messageViewInfo.index then
                    zoomShortcutKeyImage.alpha = math.max(zoomShortcutKeyImageFullAlpha - fadeOutValue * 2.0, 0.0);
                end
                if fadeOutValue > 0.5 then
                    notificationsUI:updateAllPositions()
                end
            end
        else
            removeNotification(messageViewInfo)
        end
    end

    tutorialUI:setNotificationIsVisible(true)

    
    local notificationType = notification.types[notificationTypeIndex]
    local soundTypeIndex = notificationType.soundTypeIndex
    if not soundTypeIndex then
        if notificationType.soundFunction then
            soundTypeIndex = notificationType.soundFunction(notificationInfo)
        end
    end

    notificationsUI:playSoundForNotificationIfFree(soundTypeIndex)
    
end

function notificationsUI:playSoundForNotificationIfFree(soundTypeIndex)
    if soundTypeIndex then
        if not soundPlayDelays[soundTypeIndex] then
            soundPlayDelays[soundTypeIndex] = minDelayBetweenNotifcationMainSoundPlays
            local soundPath = notificationSound:getPath(soundTypeIndex)
            --mj:log("playing notification sound:", soundPath)
            audio:playUISound(soundPath, 0.3, nil)
        else
            local soundPath = notificationSound:getRepeatPath(soundTypeIndex)
            --mj:log("playing repeat notification sound:", soundPath)
            audio:playUISound(soundPath, 0.3, nil)
        end
    end
end


local function displayNotificationWithInfo(notificationInfo)

    --tutorialUI:show(tutorialUI.types.notifications.index)
    
    delayTimer = minDelayBetweenNotifcations
    local notificationType = notification.types[notificationInfo.notificationTypeIndex]
    local title = notificationType.key
    if notificationType.titleFunction then
        title = notificationType.titleFunction(notificationInfo.userData)
    end

    local objectInfo = notification:getObjectInfo(notificationInfo)
    displayNotification(notificationInfo, objectInfo, title)
    --gameUI:showUIIfHiddenDueToInactivity()

end

function notificationsUI:load(gameUI_, world, logicInterface_)
    gameUI = gameUI_
    logicInterface = logicInterface_
    
    mainView = View.new(gameUI.view)
    mainView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    mainView.size = gameUI.view.size
    mainView.hidden = true

    
    zoomShortcutKeyImage = uiKeyImage:create(mainView, 16, "game", "zoomToNotification", eventManager.controllerSetIndexMenu, "menuOther", nil)
    zoomShortcutKeyImage.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    --zoomShortcutKeyImage.relativeView = requiredResourcesTitleTextView
    zoomShortcutKeyImage.baseOffset = vec3(-10,0,0)
    zoomShortcutKeyImage.alpha = 0.67

    timer:addUpdateTimer(function(dt)
        local speedMultiplier = world:getSpeedMultiplier()
        if speedMultiplier > 0.001 then
            if delayTimer > 0.0 then
                delayTimer = delayTimer - dt
                if delayTimer <= 0.0 then
                    if queuedNotifications[1] then
                        displayNotificationWithInfo(queuedNotifications[1])
                        table.remove(queuedNotifications, 1)
                    end
                end
            end

            for k,info in pairs(notificationsUI.messageViewInfos) do
                info.updateFunction(dt)
            end

            for k,delay in pairs(soundPlayDelays) do
                soundPlayDelays[k] = delay - dt
                if soundPlayDelays[k] <= 0.0 then
                    soundPlayDelays[k] = nil
                end
            end
        end
    end)
end

--[[function notificationsUI:discoveryUIDisplayed(discoveryUISize)
    mainView.baseOffset = vec3(0,-discoveryUISize.y - 20.0, 0.0)
end

function notificationsUI:discoveryUIHidden()
    mainView.baseOffset = vec3(0.0,0.0,0.0)
end]]

function notificationsUI:displayNotification(notificationInfo)
    if delayTimer > 0.0 then
        table.insert(queuedNotifications, notificationInfo)
    else
        displayNotificationWithInfo(notificationInfo)
    end
end

function notificationsUI:getZoomInfoForTopNotification()
    return zoomInfo
end

return notificationsUI