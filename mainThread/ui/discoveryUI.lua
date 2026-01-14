local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

local locale = mjrequire "common/locale"
local gameObject = mjrequire "common/gameObject"
local model = mjrequire "common/model"
local research = mjrequire "common/research"
local material = mjrequire "common/material"
local constructable = mjrequire "common/constructable"
local timer = mjrequire "common/timer"
local notificationSound = mjrequire "common/notificationSound"
--local audio = mjrequire "mainThread/audio"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"


local discoveryUI = {}

local gameUI = nil
local notificationsUI = nil
local mainView = nil
local imageView = nil
local backgroundView = nil

local titleTextView = nil
local descriptionTextView = nil
local unlocksTitleTextView = nil

local unlockedItemsView = nil

local circleSize = 200.0
local circleOffsetYFromTop = 80
local titleTextViewPaddingYFromTop = 5
local standardPaddingYFromTop = 30
local paddingX = 40

--local infoViewWidthMultiplier = 0.6

local queuedDiscoveries = nil
local waitForDisplayTimerID = nil
local hubUI = nil
local world = nil


local backgroundSize = vec2(1140, 640) * 0.75
local iconHalfSize = 14
local iconPadding = 6

local function getUnlockedConstructablesForDiscovery(researchTypeIndex, discoveryCraftableTypeIndex)
    local result = {}
    local resultSet = {}
    --research.types[researchTypeIndex].skillTypeIndex
    if researchTypeIndex ~= research.types.planting.index then -- it's weird to unlock all the plants
        for i,constructableType in ipairs(constructable.validTypes) do
            if not resultSet[constructableType.index] then
                if constructableType.classification and 
                (not constructableType.omitFromDiscoveryUI) and
                (not constructableType.isVariationOfConstructableTypeIndex) and 
                ((not constructableType.disabledUntilCraftableResearched) or (constructableType.index == discoveryCraftableTypeIndex)) then

                    local matchesRequiredSkill = (constructableType.skills and (constructableType.skills.required == research.types[researchTypeIndex].skillTypeIndex))
                    local matchesAdditionalDiscovery = (constructableType.disabledUntilAdditionalResearchDiscovered == researchTypeIndex)

                    if matchesRequiredSkill or matchesAdditionalDiscovery then
                        local hasBoth = false
                        if matchesRequiredSkill then
                            if constructableType.disabledUntilAdditionalResearchDiscovered then
                                hasBoth = world:tribeHasMadeDiscovery(constructableType.disabledUntilAdditionalResearchDiscovered)
                            else
                                hasBoth = true
                            end
                        else
                            if constructableType.skills and constructableType.skills.required then
                                local requiredSkillResearchType = research.researchTypesBySkillType[constructableType.skills.required]
                                if requiredSkillResearchType then
                                    hasBoth = world:tribeHasMadeDiscovery(requiredSkillResearchType.index)
                                else
                                    hasBoth = true
                                end
                            else
                                hasBoth = true
                            end
                        end
                        if hasBoth then
                            resultSet[constructableType.index] = true
                            table.insert(result, constructableType.index)
                        end
                    end
                end
            end
        end
    end

    return result
end

local function updateResearchType(researchTypeIndex, discoveryCraftableTypeIndex)

    local icon = research.types[researchTypeIndex].icon
    
    imageView:setModel(model:modelIndexForName(icon))
    --mj:log("researchTypeIndex:", researchTypeIndex, " type:", research.types[researchTypeIndex])
    titleTextView:setText(research.types[researchTypeIndex].name, material.types.standardText.index)
    descriptionTextView.text = research.types[researchTypeIndex].description
    if unlockedItemsView then
        backgroundView:removeSubview(unlockedItemsView)
        unlockedItemsView = nil
    end
    
    unlocksTitleTextView.baseOffset = vec3(0,-standardPaddingYFromTop * 2.0 - descriptionTextView.size.y, 0)
    
    local iconsSize = 60.0
    local unlockedConstructables = getUnlockedConstructablesForDiscovery(researchTypeIndex, discoveryCraftableTypeIndex)
    local additionalUnlocks = research.types[researchTypeIndex].additionalUnlocksToShowInBreakthroughUI

    local unlockIconPadding = 8.0
    local maxIconsPerRow = math.floor((backgroundSize.x - (paddingX * 2)) / (iconsSize + unlockIconPadding))
    local maxRows = 2
    local maxCount = maxIconsPerRow * maxRows

    local panelHeight = 480.0 + descriptionTextView.size.y

    if next(unlockedConstructables) or (additionalUnlocks and additionalUnlocks[1]) then
        unlockedItemsView = View.new(backgroundView)
        unlockedItemsView.size.x = backgroundView.size.x
        unlockedItemsView.size.y = iconsSize
        unlockedItemsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        unlockedItemsView.relativeView = unlocksTitleTextView
        unlockedItemsView.baseOffset = vec3(0.0, -8.0, 0)

        unlocksTitleTextView.hidden = false

        local count = 0

        local unlockedInfos = {}
        for i, constructableTypeIndex in ipairs(unlockedConstructables) do
            
            local constructableType = constructable.types[constructableTypeIndex]
            local gameObjectTypeKey = constructableType.iconGameObjectType
            if not gameObjectTypeKey then
                gameObjectTypeKey = constructableType.inProgressGameObjectTypeKey
            end
            local gameObjectType = gameObject.types[gameObjectTypeKey]

            if gameObjectType then
                table.insert(unlockedInfos, {
                    name = constructableType.name,
                    gameObjectTypeIndex = gameObjectType.index,
                })
                count = count + 1

                if count >= maxCount then
                    break
                end
            end
        end

        if additionalUnlocks then
            for i, additionalUnlockInfo in ipairs(additionalUnlocks) do
                table.insert(unlockedInfos, {
                    name = additionalUnlockInfo.text,
                    gameObjectTypeIndex = additionalUnlockInfo.iconObjectTypeIndex,
                })
                count = count + 1

                if count >= maxCount then
                    break
                end
            end
        end
        

        for i, unlockedInfo in ipairs(unlockedInfos) do
            local objectView = uiGameObjectView:create(unlockedItemsView, vec2(iconsSize, iconsSize), uiGameObjectView.types.backgroundCircle)
            objectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
            local xIndex = (i - 1) % maxIconsPerRow
            local yIndex = math.floor((i - 1) / maxIconsPerRow)

            local countThisRow = math.min(count, maxIconsPerRow)
            if yIndex > 0 and yIndex == math.floor((count - 1) / maxIconsPerRow) then
                countThisRow = ((count - 1) % maxIconsPerRow) + 1
            end
            
            local rowOffsetX = (countThisRow - 1) * (iconsSize + unlockIconPadding) * 0.5

            --mj:log("i:", i, " xIndex:", xIndex, " yIndex:", yIndex, " rowOffsetX:", rowOffsetX, " name:", unlockedInfo.name)

            objectView.baseOffset = vec3(xIndex * (iconsSize + unlockIconPadding) - rowOffsetX, -yIndex * (iconsSize + unlockIconPadding), 2.0)

            uiGameObjectView:setObject(objectView, {objectTypeIndex = unlockedInfo.gameObjectTypeIndex}, nil, nil)

            uiGameObjectView:setBackgroundMasksEvents(objectView, true)
            uiToolTip:add(objectView.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionAbove), unlockedInfo.name, nil, nil, nil, objectView, unlockedItemsView)
        end

        
        local rowCount = math.floor((count - 1) / maxIconsPerRow) + 1

        panelHeight = panelHeight + (iconsSize + unlockIconPadding) * rowCount + 60.0

    else
        unlocksTitleTextView.hidden = true
    end

    
    backgroundView.size = vec2(backgroundSize.x, panelHeight)
    local scaleToUseX = backgroundSize.x * 0.5
    local scaleToUseY = panelHeight * 0.5 / (9.0/16.0)
    --[[mj:log("backgroundView.size:", backgroundView.size)
    mj:log("scaleToUseY:", scaleToUseY)
    mj:log("scaleToUseX:", scaleToUseX)]]
    backgroundView.scale3D = vec3(scaleToUseX, scaleToUseY, scaleToUseX)
end

local function showPanel(queuedDiscovery)
    updateResearchType(queuedDiscovery.researchTypeIndex, queuedDiscovery.discoveryCraftableTypeIndex)
    mainView.hidden = false
    hubUI:hideAllUI(false)
    world:startTemporaryPauseForPopup()
end

local function showNextDiscoveryInQueue()
    if queuedDiscoveries and queuedDiscoveries[1] then
        showPanel(queuedDiscoveries[1])
        notificationsUI:playSoundForNotificationIfFree(notificationSound.types.research.index)

        if #queuedDiscoveries == 1 then
            queuedDiscoveries = nil
        else
            table.remove(queuedDiscoveries, 1)
        end
        return true
    end
    return false
end

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            if not showNextDiscoveryInQueue() then
                discoveryUI:hide()
            end
        end 
        return true 
    end,
}

local function keyChanged(isDown, code, modKey, isRepeat)
    if keyMap[code]  then
		return keyMap[code](isDown, isRepeat)
	end
end

local extraDelayTimer = 0.0

local function update(dt)
    local function removeTimer()
        if waitForDisplayTimerID then
            timer:removeTimer(waitForDisplayTimerID)
            waitForDisplayTimerID = nil
        end
    end
    if queuedDiscoveries and queuedDiscoveries[1] then
        if gameUI:canShowInvasivePopup() then
            extraDelayTimer = extraDelayTimer + dt
            if extraDelayTimer > 0.5 then
                showNextDiscoveryInQueue()
                removeTimer()
            end
        else
            extraDelayTimer = 0.0
        end
    else 
        removeTimer()
    end
end


function discoveryUI:load(gameUI_, hubUI_, world_, notificationsUI_)
    gameUI = gameUI_
    hubUI = hubUI_
    world = world_
    notificationsUI = notificationsUI_
    
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

    local circleView = ModelView.new(backgroundView)
    circleView:setModel(model:modelIndexForName("ui_circleBackgroundLarge"))

    --local circleViewOffset = vec3(20,-20, 0)

    local lookAtCircleBackgroundScale = circleSize * 0.5
    circleView.scale3D = vec3(lookAtCircleBackgroundScale,lookAtCircleBackgroundScale,30.0)
    circleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    circleView.size = vec2(circleSize, circleSize)
    circleView.baseOffset = vec3(0, -circleOffsetYFromTop, 2)
    --local infoViewOffset = vec3(-circleSize * 0.56,-1, -1)

    --imageView = ImageView.new(circleView)
    local iconSize = circleSize * 0.8
    imageView = ModelView.new(circleView)
    imageView.size = vec2(iconSize, iconSize)
    imageView.masksEvents = false
    imageView.baseOffset = vec3(0, 0, 1)
    imageView.scale3D = vec3(iconSize * 0.5, iconSize * 0.5, 30.0)

    local newDiscoveryView = View.new(backgroundView)
    newDiscoveryView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    newDiscoveryView.baseOffset = vec3(0,-10, 0)
    newDiscoveryView.size = vec2(200, 32.0)
    
    local titleIcon = ModelView.new(newDiscoveryView)
    titleIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    --icon.baseOffset = vec3(4, 0, 1)
    titleIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    titleIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
    titleIcon:setModel(model:modelIndexForName("icon_idea"))

    local newDiscoveryTextView = ModelTextView.new(newDiscoveryView)
    newDiscoveryTextView.font = Font(uiCommon.titleFontName, 36)
    newDiscoveryTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    newDiscoveryTextView.relativeView = titleIcon
    newDiscoveryTextView.baseOffset = vec3(iconPadding, 0, 0)
    newDiscoveryTextView:setText(locale:get("misc_newBreakthrough"), material.types.standardText.index)

    newDiscoveryView.size = vec2(newDiscoveryTextView.size.x + iconHalfSize + iconHalfSize + iconPadding, newDiscoveryView.size.y)

    titleTextView = ModelTextView.new(backgroundView)
    titleTextView.font = Font(uiCommon.titleFontName, 48)
    titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    titleTextView.relativeView = circleView
    titleTextView.baseOffset = vec3(0,-titleTextViewPaddingYFromTop,0)
    titleTextView.wrapWidth = backgroundView.size.x - 10

    descriptionTextView = TextView.new(backgroundView)
    descriptionTextView.font = Font(uiCommon.fontName, 20)
    descriptionTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    descriptionTextView.relativeView = titleTextView
    descriptionTextView.baseOffset = vec3(0,-standardPaddingYFromTop,0)
    descriptionTextView.wrapWidth = backgroundView.size.x - (paddingX)

    unlocksTitleTextView = TextView.new(backgroundView)
    unlocksTitleTextView.font = Font(uiCommon.fontName, 20)
    unlocksTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    unlocksTitleTextView.relativeView = titleTextView
    unlocksTitleTextView.text = locale:get("misc_unlocks") .. ":"

    
    local okButton = uiStandardButton:create(backgroundView, vec2(200, 40))
    okButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    okButton.baseOffset = vec3(0.0,40, 0)
    uiStandardButton:setTextWithShortcut(okButton, locale:get("ui_action_continue"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
    uiStandardButton:setClickFunction(okButton, function()
        if not showNextDiscoveryInQueue() then
            discoveryUI:hide()
        end
    end)
    
    local closeButton = uiStandardButton:create(backgroundView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        if not showNextDiscoveryInQueue() then
            discoveryUI:hide()
        end
    end)

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if isDown and not mainView.hidden then
            uiStandardButton:callClickFunction(okButton)
        end
    end)

end

function discoveryUI:show(researchTypeIndex, discoveryCraftableTypeIndex)

    --if not gameUI:canShowInvasivePopup() then
        if not queuedDiscoveries then
            queuedDiscoveries = {}
        end
        table.insert(queuedDiscoveries, {
            researchTypeIndex = researchTypeIndex,
            discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
        })
        
        if not waitForDisplayTimerID then
            waitForDisplayTimerID = timer:addUpdateTimer(update)
            extraDelayTimer = 0.0
        end
    --[[else
        showPanel(researchTypeIndex)
    end]]
end

function discoveryUI:isDisplayedOrHasQueued()
    if queuedDiscoveries and queuedDiscoveries[1] then
        return true
    end
    return (not mainView.hidden)
end
    
function discoveryUI:hide()
    world:endTemporaryPauseForPopup()
    mainView.hidden = true
    --notificationsUI:discoveryUIHidden()
end

function discoveryUI:hidden()
    return mainView.hidden
end

return discoveryUI