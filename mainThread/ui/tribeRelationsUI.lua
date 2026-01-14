local mjm = mjrequire "common/mjm"
--local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local mat3Rotate = mjm.mat3Rotate
--local mat3Identity = mjm.mat3Identity
--local mat3LookAtInverse = mjm.mat3LookAtInverse
--local normalize = mjm.normalize
--local vec4 = mjm.vec4

local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
local timer = mjrequire "common/timer"
local industry = mjrequire "common/industry"
local notificationSound = mjrequire "common/notificationSound"
--local sapienConstants = mjrequire "common/sapienConstants"
--local constructable = mjrequire "common/constructable"
local resource = mjrequire "common/resource"
local quest = mjrequire "common/quest"
local gameConstants = mjrequire "common/gameConstants"
--local rng = mjrequire "common/randomNumberGenerator"
--local audio = mjrequire "mainThread/audio"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiTribeView = mjrequire "mainThread/ui/uiCommon/uiTribeView"
--local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiProgressBar = mjrequire "mainThread/ui/uiCommon/uiProgressBar"
local uiFavorView = mjrequire "mainThread/ui/uiCommon/uiFavorView"
--local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local tribeRelationsOffersView = mjrequire "mainThread/ui/tribeRelationsOffersView"
local tribeRelationsRequestsView = mjrequire "mainThread/ui/tribeRelationsRequestsView"
local tribeRelationsSettingsView = mjrequire "mainThread/ui/tribeRelationsSettingsView"
--local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"

local questUIHelper = mjrequire "mainThread/ui/questUIHelper"
local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
--local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"

local logicInterface = nil


local tribeRelationsUI = {}

local gameUI = nil
local notificationsUI = nil
local mainView = nil
local backgroundView = nil

local titleTextView = nil
local tribeSapiensRenderGameObjectView = nil
local populationTextView = nil
local favorBackgroundView = nil
local favorTextView = nil
local favorProgressBarView = nil

local introView = nil
local questView = nil
local tradeView = nil

local introSentenceTextView = nil
local questGeneralDescriptionTextView = nil

local questTextTitleTextView = nil
local questTimerTextView = nil
--local tradeTextTitleTextView = nil

local questBriefLine1LabelTextView = nil
local questBriefLine1TextView = nil
local timeLimitLabelTextView = nil
local timeLimitTextView = nil

local rewardLabelTextView = nil
local rewardFavorView = nil
local penaltyLabelTextView = nil
local penaltyFavorView = nil

local acceptQuestButton = nil
local zoomToQuestButton = nil

local tradeRequestsSummaryTextView = nil

local titleTextViewPaddingYFromTop = 10

--local infoViewWidthMultiplier = 0.6

local queuedEvents = nil
local waitForDisplayTimerID = nil
local hubUI = nil
local world = nil


local backgroundSize = vec2(1440, 810)
local tribeBannerHeight = 320
local favorTextMaterial = material.types.ui_bronze_roughText.index

local tradePanelWidth = math.floor((backgroundSize.x - 40 - 10) / 2)
local tradePanelHeight = backgroundSize.y - tribeBannerHeight - 100


local questViewSize = vec2(tradePanelWidth, tradePanelHeight)
local questViewScaleToUseX = questViewSize.x * 0.5
local questViewScaleToUseY = questViewSize.y * 0.5 / 0.75

local tradeViewSize = vec2(tradePanelWidth, tradePanelHeight - 20)
local tradeViewScaleToUseX = tradeViewSize.x * 0.5
local tradeViewScaleToUseY = tradeViewSize.y * 0.5 / 0.75


local tabSize = vec2(180.0, 45.0)
local tabPadding = 10.0

local currentTabIndex = nil

local selectedTabZOffset = 1.0
local unSelectedTabZOffset = -2.0

local currentDestinationState = nil
local currentTribeSapienInfos = nil

local tabTypes = mj:enum {
    "offers",
    "requests",
    "settings",
}

local tabCount = #tabTypes

local tabInfos = {
    [tabTypes.offers] = {
        title = locale:get("ui_name_trade_offers"),
    },
    [tabTypes.requests] = {
        title = locale:get("ui_name_trade_requests"),
    },
    [tabTypes.settings] = {
        title = locale:get("ui_name_trade_settings"),
    },
}

local function getMoodString(relationshipState)
    if relationshipState.favor > gameConstants.tribeRelationshipScoreThresholds.mildNegative then
        if relationshipState.favor > gameConstants.tribeRelationshipScoreThresholds.mildPositive then
            if relationshipState.favor > gameConstants.tribeRelationshipScoreThresholds.moderatePositive then
                return "severePositive"
            end
            return "moderatePositive"
        end
        return "mildPositive"
    end

    if relationshipState.favor <= gameConstants.tribeRelationshipScoreThresholds.moderateNegative then
        if relationshipState.favor <= gameConstants.tribeRelationshipScoreThresholds.severeNegative then
            return "severeNegative"
        end
        return "moderateNegative"
    end
    return "mildNegative"
end


local function getTribeIntroSentence(destinationState, relationship, ourSapienNameOrNil)

    if destinationState.clientID then
        local tribeName = destinationState.name
        return locale:get("tribeRelations_otherPlayer", {tribeName = tribeName, playerName = (destinationState.playerName or "another player")})
    else
        local tribeName = destinationState.name
        local industryWorkerTypeNameLocaleKey = "industry_" .. industry.types[destinationState.industryTypeIndex].key .. "_workerTypeName"
        local industryWorkerTypeName = string.lower(locale:get(industryWorkerTypeNameLocaleKey))
        local moodString = getMoodString(relationship)
        if ourSapienNameOrNil then
            return locale:get("tribeRelations_firstMeet_" .. moodString, {tribeName = tribeName, name = ourSapienNameOrNil, industryWorkerTypeName = industryWorkerTypeName})
        else
            return locale:get("tribeRelations_general_" .. moodString, {tribeName = tribeName, industryWorkerTypeName = industryWorkerTypeName})
        end
    end
end

--[[

    local questState = {
        questTypeIndex = quest.types.resource.index,
        resourceTypeIndex = resourceTypeIndex,
        count = 40,
        motivationTypeIndex = quest.motivationTypes.craftable.index,
        storageObjectID = foundStorageObjectID,
        reward = 10,
        penalty = 5,
    }
]]


local function getQuestSummaryText(destinationState, questState)
    --mj:log("questState:", questState)

    local localeKeys = {
        tribeName = destinationState.name,
        count = questState.requiredCount,
    }

    if questState.resourceTypeIndex then
        local baseString = resource.types[questState.resourceTypeIndex].pluralGeneric or resource.types[questState.resourceTypeIndex].plural
        localeKeys.resourcePlural = string.lower(baseString)
    end

    --local questType = quest.types[questState.questTypeIndex]

    local questMotivationType = quest.motivationTypes[questState.motivationTypeIndex]

    --if questType.extraKeysFunc then --todo maybe?
    --end

    --[[
    mj:log("localeKeys:", localeKeys)
    mj:log("questMotivationType:", questMotivationType)
    mj:log("questType.storyLocaleKey:", questMotivationType.storyLocaleKey)
    mj:log("questState.questTypeIndex:", questState.questTypeIndex)
    ]]
    
    local result = locale:get(questMotivationType.storyLocaleKey, localeKeys)

    return result

    --[[quest_motivation_story_craftable = function(values)
        return "the " .. values.tribeName .. " tribe is looking for " .. values.resourcePlural
    end,]]
    --return ourSapienName .. " has learned that the " .. destinationState.name .. " tribe is looking for small rocks to craft into tools.\nIf we can deliver 40 small rocks to their village, it will increase our standing with them."
end

local function getTribePopulation(tribeSapienInfos) --todo this can be generated server-side in destinationState, probably will be at some point
    local count = 0
    for sapienID,sapienInfo in pairs(tribeSapienInfos) do
        count = count + 1
        if sapienInfo.sharedState.hasBaby then
            count = count + 1
        end
    end
    return count
end

local function getTimeString(remainingTime)
    if remainingTime > 60.99 then
        return locale:getTimeDurationDescription(remainingTime, world:getDayLength(), world:getYearLength())
    end
    return string.format("%d:%d%d", math.floor(remainingTime / 60), math.floor((remainingTime % 60) / 10), math.floor(remainingTime) % 10)
end

local function updateQuestTimerText()
    local questState = currentDestinationState and currentDestinationState.relationships[world:getTribeID()].questState
    if questState then
        local timerText = questUIHelper:getTimeLeftTextForQuestState(questState)
        if timerText then
            questTimerTextView.hidden = false
            questTimerTextView.text = timerText
        else
            questTimerTextView.hidden = true
        end
    end

end

function tribeRelationsUI:updateQuestState()
    if not currentDestinationState then
        return
    end

    local questState = currentDestinationState.relationships[world:getTribeID()].questState

    if questState then
        questView.hidden = false

        local questTitleText = questUIHelper:getDescriptiveQuestLabelTextForQuestState(questState) .. ": " .. quest.types[questState.questTypeIndex].name -- Active Quest: Resources
        questTextTitleTextView:setText(questTitleText, material.types.standardText.index)

        questBriefLine1LabelTextView.text = locale:get("ui_name_quest") .. ":"

        local relationshipState = currentDestinationState.relationships[world:getTribeID()]

        local questBriefLine1Text = questUIHelper:getQuestShortSummaryText(questState, relationshipState.questDeliveries and relationshipState.questDeliveries[questState.resourceTypeIndex])
        --[[if questState.deliveredCount then
            questBriefLine1Text = locale:get("ui_questSummaryWithDeliveredCount", {
                count = questState.requiredCount,
                deliveredCount = questState.deliveredCount,
                resourceName = resource.types[questState.resourceTypeIndex].name,
                resourcePlural = resource.types[questState.resourceTypeIndex].plural,
            })
        else
            questBriefLine1Text = locale:get("ui_questSummary", {
                count = questState.requiredCount,
                resourceName = resource.types[questState.resourceTypeIndex].name,
                resourcePlural = resource.types[questState.resourceTypeIndex].plural,
            })
        end]]

        questBriefLine1TextView.text = questBriefLine1Text

        questGeneralDescriptionTextView.text = getQuestSummaryText(currentDestinationState, questState)

        local timeLimit = quest.types[questState.questTypeIndex].completionTimeLimit
        timeLimitTextView.text = getTimeString(timeLimit)

        uiFavorView:setValue(rewardFavorView, questState.reward, true)
        uiFavorView:setValue(penaltyFavorView, -questState.penalty, true)

        questBriefLine1LabelTextView.baseOffset = vec3(-questGeneralDescriptionTextView.size.x * 0.5, -20.0, 0.0)

        if questState.assignedTime then
            zoomToQuestButton.hidden = false
            acceptQuestButton.hidden = true
        else    
            acceptQuestButton.hidden = false
            zoomToQuestButton.hidden = true
        end
        updateQuestTimerText()
    else
        questView.hidden = true
    end
end

local function updateWithState(destinationState, tribeSapienInfos, ourSapienNameOrNil)
    currentDestinationState = destinationState
    currentTribeSapienInfos = tribeSapienInfos
    local relationshipState = destinationState.relationships[world:getTribeID()]

    local titleString = locale:get("misc_tribeNameFormal", {tribeName = destinationState.name})
    titleTextView:setText(titleString, material.types.standardText.index)

    populationTextView.text = locale:get("tribeUI_population") .. ": " .. mj:tostring(getTribePopulation(tribeSapienInfos))

    if destinationState.clientID then
        favorBackgroundView.hidden = true
    else
        favorBackgroundView.hidden = false
        favorTextView:setText(locale:get("ui_name_favor") .. ": " .. mj:tostring(math.floor(relationshipState.favor)), favorTextMaterial)
        uiProgressBar:setValue(favorProgressBarView, mjm.clamp(math.floor(relationshipState.favor), 1, 100) / 100)
    end

    local moodString = getMoodString(relationshipState)
    local barInsetMaterialName = "ui_bronze_" .. moodString
    local barMaterialName = "ui_bronze_lightest_" .. moodString
    uiProgressBar:setMaterials(favorProgressBarView, nil, material.types[barInsetMaterialName].index, material.types[barMaterialName].index)

    uiTribeView:setTribe(tribeSapiensRenderGameObjectView, destinationState.destinationID, tribeSapienInfos, world:getWorldTime())

    introSentenceTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    introSentenceTextView.relativeView = introView
    introSentenceTextView.baseOffset = vec3(0,0, 0)

    introSentenceTextView.text = getTribeIntroSentence(destinationState, relationshipState, ourSapienNameOrNil)
    local maxWidth = introSentenceTextView.size.x
    introView.size = vec2(maxWidth + 20, 10 + introSentenceTextView.size.y)

    tribeRelationsUI:updateQuestState()


    tribeRelationsOffersView:update(destinationState)
    tribeRelationsRequestsView:update(destinationState)
    tribeRelationsSettingsView:update(destinationState)

    --timeLimitLabelTextView.baseOffset = vec3(-questBriefLine1TextView.size.x * 0.5 - 10,0, 0)
end

function tribeRelationsUI:updateDueToTribeRelationsSettingsChange(destinationID)
    --mj:log("tribeRelationsUI:updateDueToTribeRelationsSettingsChange")
    if not mainView.hidden then
        if currentDestinationState and destinationID == currentDestinationState.destinationID then
            tribeRelationsSettingsView:updateDueToTribeRelationsSettingsChange()
        end
    end
end

function tribeRelationsUI:updateDestination(destinationInfo)
    --mj:log("tribeRelationsUI:updateDestination:", destinationInfo)
    if not mainView.hidden then
        if currentDestinationState and destinationInfo.destinationID == currentDestinationState.destinationID then
            updateWithState(destinationInfo, currentTribeSapienInfos, nil)
        end
    end
end

function tribeRelationsUI:removeDestination(destinationInfo)
    if not mainView.hidden then
        if currentDestinationState and destinationInfo.destinationID == currentDestinationState.destinationID then
            currentDestinationState = nil
            tribeRelationsUI:hide()
        end
    end
end

local function showPanel(event)
    updateWithState(event.destinationState, event.tribeSapienInfos, event.ourSapienName)
    mainView.hidden = false
    mainView:resetAnimationTimer()
    hubUI:hideAllUI(false)
    if event.shouldPauseGameOnDisplay then
        world:startTemporaryPauseForPopup()
        notificationsUI:playSoundForNotificationIfFree(notificationSound.types.notificationPositive.index)
    end

    local currentInfo = tabInfos[currentTabIndex]
    currentInfo.viewController:didBecomeVisible()
end

local function showNextEventInQueue()
    if queuedEvents and queuedEvents[1] then
        showPanel(queuedEvents[1])

        if #queuedEvents == 1 then
            queuedEvents = nil
        else
            table.remove(queuedEvents, 1)
        end
        return true
    end
    return false
end

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            if not showNextEventInQueue() then
                tribeRelationsUI:hide()
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
    if queuedEvents and queuedEvents[1] then
        if gameUI:canShowInvasivePopup() then
            extraDelayTimer = extraDelayTimer + dt
            if extraDelayTimer > 0.5 then
                showNextEventInQueue()
                removeTimer()
            end
        else
            extraDelayTimer = 0.0
        end
    else 
        removeTimer()
    end
end


local function switchTabs(tabIndex)
    if currentTabIndex ~= tabIndex then
        if currentTabIndex then
            local currentInfo = tabInfos[currentTabIndex]
            currentInfo.contentView.hidden = true

            --uiObjectsByModeType[currentModeIndex]:hide()

            uiStandardButton:setActivated(currentInfo.tabButton, false)
            local prevOffset = currentInfo.tabButton.baseOffset
            currentInfo.tabButton.baseOffset = vec3(prevOffset.x, prevOffset.y, unSelectedTabZOffset)

        end

        currentTabIndex = tabIndex

        local currentInfo = tabInfos[currentTabIndex]
        currentInfo.contentView.hidden = false
        
        uiStandardButton:setActivated(currentInfo.tabButton, true)
        local prevOffset = currentInfo.tabButton.baseOffset
        currentInfo.tabButton.baseOffset = vec3(prevOffset.x, prevOffset.y, selectedTabZOffset)
        
        --[[if currentTabIndex == tabTypes.mods then
            updateModsList()
        end]]

    end
end


local function createTradeView()
    tradeView = ModelView.new(backgroundView)
    tradeView:setModel(model:modelIndexForName("ui_inset_lg_4x3"), {
        [material.types.ui_background_inset.index] = material.types.ui_background_inset_lightest.index,
    })
    tradeView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    tradeView.relativeView = introView
    tradeView.baseOffset = vec3(-tradeViewSize.x * 0.5 - 10, -40, 4)
    tradeView.scale3D = vec3(tradeViewScaleToUseX,tradeViewScaleToUseY,tradeViewScaleToUseX)
    tradeView.size = tradeViewSize
    
    local tradeOffersView = View.new(tradeView)
    --tradeOffersView.color = mjm.vec4(0.5,0.0,0.0,0.5)
    tradeOffersView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    tradeOffersView.size = vec2(tradeViewSize.x, tradeViewSize.y)
    tradeOffersView.hidden = true
    tabInfos[tabTypes.offers].contentView = tradeOffersView
    tabInfos[tabTypes.offers].viewController = tribeRelationsOffersView

    tribeRelationsOffersView:load(tradeOffersView, tribeRelationsUI, gameUI, world, logicInterface)

    local tradeRequestsView = View.new(tradeView)
    --tradeRequestsView.color = mjm.vec4(0.0,0.5,0.0,0.5)
    tradeRequestsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    tradeRequestsView.size = vec2(tradeViewSize.x, tradeViewSize.y)
    tradeRequestsView.hidden = true
    tabInfos[tabTypes.requests].contentView = tradeRequestsView
    tabInfos[tabTypes.requests].viewController = tribeRelationsRequestsView

    tribeRelationsRequestsView:load(tradeRequestsView, gameUI, world, logicInterface)


    local tribeSettingsView = View.new(tradeView)
    --tradeRequestsView.color = mjm.vec4(0.0,0.5,0.0,0.5)
    tribeSettingsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    tribeSettingsView.size = vec2(tradeViewSize.x, tradeViewSize.y)
    tribeSettingsView.hidden = true
    tabInfos[tabTypes.settings].contentView = tribeSettingsView
    tabInfos[tabTypes.settings].viewController = tribeRelationsSettingsView

    tribeRelationsSettingsView:load(tribeSettingsView, world, logicInterface)

    tradeRequestsSummaryTextView = TextView.new(tradeRequestsView)
    tradeRequestsSummaryTextView.font = Font(uiCommon.fontName, 18)
    tradeRequestsSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    tradeRequestsSummaryTextView.color = mj.textColor
    tradeRequestsSummaryTextView.baseOffset = vec3(0,-20, 0)
    
    --uiSelectionLayout:createForView(tradeRequestsView) --todo

    local function addTabButton(buttonIndex, modeInfo)
        local tabButton = uiStandardButton:create(backgroundView, tabSize, uiStandardButton.types.tabInsetTitle, nil)
        tabButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionAbove)
        tabButton.relativeView = tradeView

        local xOffset = (tabCount * -0.5 + (buttonIndex - 1) + 0.5) * (tabSize.x + tabPadding)
        local zOffset = unSelectedTabZOffset
        --[[if buttonIndex == 1 then
            zOffset = selectedTabZOffset
        end]]

        tabButton.baseOffset = vec3(xOffset, -8, zOffset)
        uiStandardButton:setText(tabButton, modeInfo.title)
        --uiStandardButton:setSelectedTextColor(tabButton, mj.textColor)

        local function doSelect(wasUserClick)
            --uiSelectionLayout:setActiveSelectionLayoutView(backgroundView)
            --menuIsActiveForCurrentSelection = true

            if not (wasUserClick and currentTabIndex == buttonIndex) then
                switchTabs(buttonIndex)
            end

            --uiSelectionLayout:setSelection(rightPane, tabButton, true)
        end
        
        uiStandardButton:setClickFunction(tabButton, function()
            doSelect(true)
        end)
        
        --[[uiSelectionLayout:setItemSelectedFunction(tabButton, function()
            doSelect(false)
        end)]]

        modeInfo.tabButton = tabButton
        
        --uiSelectionLayout:addView(rightPane, tabButton)
        --uiSelectionLayout:addDirectionOverride(tabButton, loadButton, uiSelectionLayout.directions.up, false)
    end

    for i,v in ipairs(tabTypes) do
        addTabButton(i, tabInfos[i])
    end
    switchTabs(1)


end

local function createQuestsView()
    questView = ModelView.new(backgroundView)
    questView:setModel(model:modelIndexForName("ui_inset_lg_4x3"), {
        [material.types.ui_background_inset.index] = material.types.ui_background_inset_lightest.index,
    })
    questView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    questView.relativeView = introView
    questView.baseOffset = vec3(questViewSize.x * 0.5 + 10, -20, 4)
    questView.scale3D = vec3(questViewScaleToUseX,questViewScaleToUseY,questViewScaleToUseX)
    questView.size = questViewSize

    questTextTitleTextView = ModelTextView.new(questView)
    questTextTitleTextView.font = Font(uiCommon.titleFontName, 32)
    questTextTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    questTextTitleTextView.baseOffset = vec3(0,-10,0)

    questTimerTextView = TextView.new(questView)
    questTimerTextView.font = Font(uiCommon.fontName, 16)
    questTimerTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    questTimerTextView.relativeView = questTextTitleTextView
    questTimerTextView.baseOffset = vec3(0,2, 0)
    questTimerTextView.color = mj.textColor

    local accumulator = 0.0
    questTimerTextView.update = function(dt)
        accumulator = accumulator + dt
        if accumulator > 1.0 then
            accumulator = accumulator - 1.0
            updateQuestTimerText()
        end
    end

    questGeneralDescriptionTextView = TextView.new(questView)
    questGeneralDescriptionTextView.font = Font(uiCommon.fontName, 18)
    questGeneralDescriptionTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    questGeneralDescriptionTextView.baseOffset = vec3(0,-94, 0)
    questGeneralDescriptionTextView.wrapWidth = tradePanelWidth - 40
    questGeneralDescriptionTextView.color = mj.textColor

    questBriefLine1LabelTextView = TextView.new(questView)
    questBriefLine1LabelTextView.font = Font(uiCommon.fontName, 18)
    questBriefLine1LabelTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    questBriefLine1LabelTextView.color = mj.textColor
    questBriefLine1LabelTextView.relativeView = questGeneralDescriptionTextView

    questBriefLine1TextView = TextView.new(questView)
    questBriefLine1TextView.font = Font(uiCommon.fontName, 18)
    questBriefLine1TextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    questBriefLine1TextView.relativeView = questBriefLine1LabelTextView
    questBriefLine1TextView.baseOffset = vec3(10,0,0)
    questBriefLine1TextView.color = mj.textColor

    timeLimitLabelTextView = TextView.new(questView)
    timeLimitLabelTextView.font = Font(uiCommon.fontName, 18)
    timeLimitLabelTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    timeLimitLabelTextView.color = mj.textColor
    timeLimitLabelTextView.relativeView = questBriefLine1LabelTextView
    timeLimitLabelTextView.text = locale:get("quest_timeLimit") .. ":"

    timeLimitTextView = TextView.new(questView)
    timeLimitTextView.font = Font(uiCommon.fontName, 18)
    timeLimitTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    timeLimitTextView.relativeView = timeLimitLabelTextView
    timeLimitTextView.color = mj.textColor
    timeLimitTextView.baseOffset = vec3(10,0, 0)

    rewardLabelTextView = TextView.new(questView)
    rewardLabelTextView.font = Font(uiCommon.fontName, 18)
    rewardLabelTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    rewardLabelTextView.relativeView = timeLimitLabelTextView
    rewardLabelTextView.color = mj.textColor
    rewardLabelTextView.text = locale:get("quest_completionReward") .. ":"

    --[[rewardTextView = TextView.new(questView)
    rewardTextView.font = Font(uiCommon.fontName, 18)
    rewardTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    rewardTextView.relativeView = rewardLabelTextView
    rewardTextView.color = mj.textColor
    rewardTextView.text = "10 favor"
    rewardTextView.baseOffset = vec3(10,0, 0)]]

    rewardFavorView = uiFavorView:create(questView)
    rewardFavorView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    rewardFavorView.relativeView = rewardLabelTextView
    rewardFavorView.baseOffset = vec3(10,2, 0)

    penaltyLabelTextView = TextView.new(questView)
    penaltyLabelTextView.font = Font(uiCommon.fontName, 18)
    penaltyLabelTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    penaltyLabelTextView.relativeView = rewardLabelTextView
    penaltyLabelTextView.color = mj.textColor
    penaltyLabelTextView.text = locale:get("quest_failurePenalty") .. ":"

    --[[penaltyTextView = TextView.new(questView)
    penaltyTextView.font = Font(uiCommon.fontName, 18)
    penaltyTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    penaltyTextView.relativeView = penaltyLabelTextView
    penaltyTextView.color = mj.textColor
    penaltyTextView.text = "5 favor"
    penaltyTextView.baseOffset = vec3(10,0, 0)]]

    penaltyFavorView = uiFavorView:create(questView)
    penaltyFavorView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    penaltyFavorView.relativeView = penaltyLabelTextView
    penaltyFavorView.baseOffset = vec3(10,2, 0)


    acceptQuestButton = uiStandardButton:create(questView, vec2(200, 60), uiStandardButton.types.favor_10x3)
    acceptQuestButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    acceptQuestButton.baseOffset = vec3(0, 10, 2)
    uiStandardButton:setTextWithShortcut(acceptQuestButton, locale:get("ui_action_acceptQuest"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
    uiStandardButton:setClickFunction(acceptQuestButton, function()
        local relationshipState = currentDestinationState.relationships[world:getTribeID()]
        local questState = relationshipState.questState
        uiStandardButton:setDisabled(acceptQuestButton, true)
        mj:log("calling acceptQuest:", questState)
        logicInterface:callServerFunction("acceptQuest", {
            destinationID = currentDestinationState.destinationID,
            questState = questState,
            
        }, function(updatedRelationshipState)
            mj:log("got callback:", updatedRelationshipState)
            uiStandardButton:setDisabled(acceptQuestButton, false)
            if updatedRelationshipState then
                currentDestinationState.relationships[world:getTribeID()] = updatedRelationshipState
                tribeRelationsUI:updateQuestState()
            end
        end)
    end)

    zoomToQuestButton = uiStandardButton:create(questView, vec2(200, 60), uiStandardButton.types.standard_10x3)
    zoomToQuestButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    zoomToQuestButton.baseOffset = vec3(0, 20, 2)
    zoomToQuestButton.hidden = true
    uiStandardButton:setTextWithShortcut(zoomToQuestButton, locale:get("ui_action_zoom"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
    uiStandardButton:setClickFunction(zoomToQuestButton, function()

        local relationshipState = currentDestinationState.relationships[world:getTribeID()]
        local questState = relationshipState.questState
        if questState and questState.objectID then
            logicInterface:callLogicThreadFunction("retrieveObject", questState.objectID, function(result)
                if result and result.found then
                    gameUI:followObject(result, false, {dismissAnyUI = true, showInspectUI = true})
                else
                    gameUI:teleportToLookAtPos(questState.objectPos)
                end
            end)
        end
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if isDown and not mainView.hidden then
            if acceptQuestButton.hidden then
                uiStandardButton:callClickFunction(zoomToQuestButton)
            else
                uiStandardButton:callClickFunction(acceptQuestButton)
            end
        end
    end)
end


function tribeRelationsUI:load(gameUI_, hubUI_, world_, notificationsUI_, logicInterface_)
    gameUI = gameUI_
    hubUI = hubUI_
    world = world_
    notificationsUI = notificationsUI_
    logicInterface = logicInterface_
    
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


    local insetViewSize = vec2(backgroundSize.x - 20, tribeBannerHeight)

    local insetView = ModelView.new(backgroundView)
    insetView:setModel(model:modelIndexForName("ui_inset_lg_4x3"))
    local scaleToUsePaneX = insetViewSize.x * 0.5
    local scaleToUsePaneY = insetViewSize.y * 0.5 / 0.75
    insetView.scale3D = vec3(scaleToUsePaneX,scaleToUsePaneY,scaleToUsePaneX)
    insetView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    insetView.size = insetViewSize
    insetView.baseOffset = vec3(0,-10,0)

    local tribeSapiensRenderGameObjectViewSize = vec2(insetViewSize.x - 20, insetViewSize.y - 50)
    tribeSapiensRenderGameObjectView = uiTribeView:create(insetView, tribeSapiensRenderGameObjectViewSize)
    tribeSapiensRenderGameObjectView.baseOffset = vec3(0,10,0)


    titleTextView = ModelTextView.new(backgroundView)
    titleTextView.font = Font(uiCommon.titleFontName, 48)
    titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleTextView.baseOffset = vec3(0,-titleTextViewPaddingYFromTop,0)
    titleTextView.wrapWidth = backgroundView.size.x - 10

    populationTextView = TextView.new(backgroundView)
    populationTextView.font = Font(uiCommon.fontName, 22)
    populationTextView.color = mj.textColor
    populationTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    populationTextView.relativeView = titleTextView
    populationTextView.baseOffset = vec3(0,5,0)

    favorBackgroundView = ModelView.new(backgroundView)
    favorBackgroundView:setModel(model:modelIndexForName("ui_favorBarPlinthBackground"), {
        [material.types.ui_background.index] = material.types.ui_bronze.index,
        --[material.types.ui_selected.index] = material.types.ui_bronze_lighter.index,
    })
    local favorBackgroundSize = vec2(400,60)
    local scaleToUseFavorBackgroundX = favorBackgroundSize.x * 0.5
    local scaleToUseFavorBackgroundY = favorBackgroundSize.y * 0.5 / 0.3
    favorBackgroundView.scale3D = vec3(scaleToUseFavorBackgroundX,scaleToUseFavorBackgroundY,scaleToUseFavorBackgroundY)
    favorBackgroundView.relativeView = insetView
    favorBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    favorBackgroundView.size = favorBackgroundSize
    favorBackgroundView.baseOffset = vec3(0,7,2)

    favorProgressBarView = uiProgressBar:create(favorBackgroundView, vec2(368,10), 0.5, nil)
    favorProgressBarView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    favorProgressBarView.baseOffset = vec3(0,12,4)

    favorTextView = ModelTextView.new(favorBackgroundView)
    favorTextView.font = Font(uiCommon.titleFontName, 28)
    favorTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionAbove)
    favorTextView.relativeView = favorProgressBarView
    favorTextView.baseOffset = vec3(0,0,0)

    introView = View.new(backgroundView)
    --introView.color = mjm.vec4(0.5,0.0,0.0,1.0)
    introView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    introView.relativeView = insetView
    introView.baseOffset = vec3(0, -14, 0)

    local wrapWidth = insetView.size.x - 40 - 20

    introSentenceTextView = TextView.new(introView)
    introSentenceTextView.font = Font(uiCommon.fontName, 22)
    introSentenceTextView.wrapWidth = wrapWidth
    introSentenceTextView.color = mj.textColor

    createTradeView()
    createQuestsView()

    local closeButton = uiStandardButton:create(backgroundView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        if not showNextEventInQueue() then
            tribeRelationsUI:hide()
        end
    end)
    

    
   --[[ local maybeLaterButton = uiStandardButton:create(backgroundView, vec2(200, 40))
    maybeLaterButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    maybeLaterButton.baseOffset = vec3(-110, 40, 0)
    uiStandardButton:setTextWithShortcut(maybeLaterButton, locale:get("ui_action_maybeLater"), "game", "escape", eventManager.controllerSetIndexMenu, "menuCancel")
    uiStandardButton:setClickFunction(maybeLaterButton, function()
        if not showNextEventInQueue() then
            tribeRelationsUI:hide()
        end
    end)]]
    

    

end

function tribeRelationsUI:show(destinationState_, tribeSapienInfosOrNil, ourSapienName, ourSapienInfo, shouldPauseGameOnDisplay)
    local function addEvent(destinationState, tribeSapienInfos)
        if not queuedEvents then
            queuedEvents = {}
        end
        table.insert(queuedEvents, {
            destinationState = destinationState,
            tribeSapienInfos = tribeSapienInfos,
            ourSapienName = ourSapienName,
            ourSapienInfo = ourSapienInfo,
            shouldPauseGameOnDisplay = shouldPauseGameOnDisplay,
        })
        
        if not waitForDisplayTimerID then
            waitForDisplayTimerID = timer:addUpdateTimer(update)
            extraDelayTimer = 0.0
        end
    end

    if not tribeSapienInfosOrNil then
        hubUI:hideAllUI(false)
        logicInterface:callServerFunction("getTribeSapienInfos", {
            tribeID = destinationState_.destinationID,
            generateRelationshipIfMissing = true,
        }, function(sapienInfos)
            --mj:log("got result:", result)
            if sapienInfos then
                addEvent(destinationState_, sapienInfos)
                showNextEventInQueue()
            end
        end)
    else
        addEvent(destinationState_, tribeSapienInfosOrNil)
        if not shouldPauseGameOnDisplay then
            showNextEventInQueue()
        end
    end
end

function tribeRelationsUI:selectOffer(offerInfo)
    switchTabs(tabTypes.offers)
    tribeRelationsOffersView:selectOfferWithResourceOrObjectTypeIndex(offerInfo.resourceTypeIndex, offerInfo.objectTypeIndex)
end

function tribeRelationsUI:selectRequest(requestInfo)
    switchTabs(tabTypes.requests)
    tribeRelationsRequestsView:selectOfferWithResourceTypeIndex(requestInfo.resourceTypeIndex)
end

function tribeRelationsUI:isDisplayedOrHasQueued()
    if queuedEvents and queuedEvents[1] then
        return true
    end
    return (not mainView.hidden)
end
    
function tribeRelationsUI:hide()
    world:endTemporaryPauseForPopup()
    mainView.hidden = true
end

function tribeRelationsUI:hidden()
    return mainView.hidden
end

function tribeRelationsUI:getCurrentDestinationState()
    return currentDestinationState
end

return tribeRelationsUI