local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4
--local normalize = mjm.normalize

local model = mjrequire "common/model"
local locale = mjrequire "common/locale"
local material = mjrequire "common/material"
local gameObject = mjrequire "common/gameObject"
local biome = mjrequire "common/biome"
local gameConstants = mjrequire "common/gameConstants"

local eventManager = mjrequire "mainThread/eventManager"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local keyMapping = mjrequire "mainThread/keyMapping"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local audio = mjrequire "mainThread/audio"
local sapienConstants = mjrequire "common/sapienConstants"
local sapienTrait = mjrequire "common/sapienTrait"
local uiAnimation = mjrequire "mainThread/ui/uiAnimation"
local uiTribeView = mjrequire "mainThread/ui/uiCommon/uiTribeView"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local destination = mjrequire "common/destination"
--local tutorialUI = mjrequire "mainThread/ui/tutorialUI"

local logicInterface = nil
local localPlayer = nil

local tribeSelectionUI = {
    selectedTribeID = nil
}

local gameUI = nil
local world = nil
local tribeSelectionMarkersUI = nil

local sapienRows = 8
local sapienColumns = 2
local sapienCardCount = sapienRows * sapienColumns

local sapienCards = {}

local mainViewAnimateOnTimer = 0.0
local mainView = nil
local selectableTribeView = nil
local biomeDifficultyTitleTextView = nil
local biomeDifficultyStarsIcon = nil
local biomeDifficultyValueTextView = nil
local biomeDescriptionTextView = nil
local cardContainerView = nil
local selectTribeButton = nil
local titleTextView = nil

local slidingOffMainBanner = false

local bannerXOffset = -200
local slideAnimationOffset = -100.0 --this is set to something else in init

local cardContainerViewYOffsetFromTop = 75.0
local cardSize = vec2(280, 70)
local cardPadding = 10.0
local objectImageViewSize = vec2(60.0,60.0)
local biomeTextViewYPadding = 20.0
local panelWidth = cardSize.x * 2 + cardPadding + 40.0

local slideOnWhenDoneInfo = nil

local panelSizeInitialized = false

local tribeSapiensRenderGameObjectView = nil
local playerOwnedTribePopulationTextView = nil

local disabledAndWaitingForServer = false

local function updateDifficultyIconModel(biomeDifficulty)
    local disabledStarMaterial = material.types.ui_disabled.index
    local difficultyMaterialIndex = material.types[string.format("biomeDifficulty_%d", biomeDifficulty)].index
    local defaultMaterial = difficultyMaterialIndex

    local starMaterials = {}
    for i=1,5 do
        if i <= biomeDifficulty then
            starMaterials[i] = difficultyMaterialIndex
        else
            starMaterials[i] = disabledStarMaterial
        end
    end

    biomeDifficultyStarsIcon:setModel(model:modelIndexForName("icon_fiveStars"), {
        default = defaultMaterial,
        [material.types.star1.index] = starMaterials[1],
        [material.types.star2.index] = starMaterials[2],
        [material.types.star3.index] = starMaterials[3],
        [material.types.star4.index] = starMaterials[4],
        [material.types.star5.index] = starMaterials[5],

    })
end


local function slideOn()
    slidingOffMainBanner = false
    mainView.baseOffset = vec3(bannerXOffset, slideAnimationOffset, 0)
    mainView.hidden = false
    audio:playUISound("audio/sounds/ui/stone.wav")
    mainView.update = function(dt_)
        mainViewAnimateOnTimer = mainViewAnimateOnTimer + dt_ * 2.0 --hack in a delay
        local fraction = (mainViewAnimateOnTimer - 0.5) * 2.0
        fraction = math.max(fraction, 0.0)
        fraction = math.pow(fraction, 0.1)
        if fraction < 1.0 then
            mainView.baseOffset = vec3(bannerXOffset, slideAnimationOffset * (1.0 - fraction), 0)
        else
            mainView.baseOffset = vec3(bannerXOffset, 0, 0)
            mainView.update = nil
            mainViewAnimateOnTimer = 1.0
        end
    end
end

local function updatePanelInfoForSapienStates(detailInfo, sapienCount)

    local hideAll = (not detailInfo.creationSapienStates or (not next(detailInfo.creationSapienStates)))

    if hideAll then
        tribeSelectionUI:hide(false)
        return
    else
        if mainView.hidden then
            slideOn()
            localPlayer:tribeSelectionUIBecameVisible()
        elseif slidingOffMainBanner then
            slideOnWhenDoneInfo = detailInfo
            return
        end
    end
    
    local titleString = string.format("%s - %d %s", 
    locale:get("misc_tribeName", {tribeName = detailInfo.name}), 
    detailInfo.population or sapienCount, 
    locale:get("object_sapien_plural"))

    if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu then
        titleString = titleString .. " " .. tribeSelectionUI.selectedTribeID
    end

    titleTextView:setText(titleString, material.types.standardText.index)

    for j,cardInfo in ipairs(sapienCards) do
        if hideAll or j > sapienCount then
            cardInfo.view.hidden = true
        else
            cardInfo.view.hidden = false
        end
    end

    if sapienCount > 0 or (not panelSizeInitialized) then
        panelSizeInitialized = true
        local rowCount = (math.floor((math.min(sapienCount, sapienCardCount) + 1) / sapienColumns))

        cardContainerView.size = vec2(cardSize.x * sapienColumns + cardPadding * (sapienColumns - 1), cardSize.y * rowCount + cardPadding * (rowCount - 1))

        local panelHeight = cardContainerView.size.y + cardContainerViewYOffsetFromTop + biomeTextViewYPadding * 2.0 + biomeDescriptionTextView.size.y + 24.0 + selectTribeButton.size.y + 20.0

        --mj:log("sapienCounter:", sapienCounter, " rowCount:", rowCount, " panelHeight:", panelHeight)
        
        local panelSizeToUse = vec2(panelWidth, panelHeight)
        local scaleToUseX = panelSizeToUse.x * 0.5
        local scaleToUseY = panelSizeToUse.y * 0.5 / (9.0/16.0)
        mainView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
        mainView.size = panelSizeToUse
        selectableTribeView.size = mainView.size
    end
end

--[[local function fooo()


    uiTribeView:setTribe(tribeSapiensRenderGameObjectView, world:getTribeID(), sapiensByID)
end]]

local function displaySapienStates(detailInfo)
    local sapienCounter = 0
    for spaienUniqueID,sapienStates in pairs(detailInfo.creationSapienStates) do
        sapienCounter = sapienCounter + 1
        if sapienCounter <= sapienCardCount then
            local sharedState = sapienStates.sharedState
            local cardInfo = sapienCards[sapienCounter]
            cardInfo.nameView.text = sharedState.name .. " - " .. sapienConstants:getAgeDescription(sharedState)

        -- mj:log(sapienInfo)

            local secondLineText = ""

            --mj:log("sapienTrait.types:", sapienTrait.types)
            for j,traitTypeInfo in ipairs(sharedState.traits) do
                --mj:log("traitTypeInfo.index:", traitTypeInfo.traitTypeIndex)
                local sapienTraitType = sapienTrait.types[traitTypeInfo.traitTypeIndex]
                local traitName = sapienTraitType.name
                if traitTypeInfo.opposite then
                    traitName = sapienTraitType.opposite
                end
                if j == 1 then
                    secondLineText = traitName
                else
                    secondLineText = secondLineText .. ", " .. traitName
                end
            end
            cardInfo.secondLineView.text = secondLineText

            local thirdLineText = ""
            if sharedState.pregnant then
                thirdLineText = locale:get("misc_pregnant")
            elseif sharedState.hasBaby then
                thirdLineText = locale:get("misc_carryingBaby")
            end
            cardInfo.thirdLineView.text = thirdLineText
            
            cardInfo.view.hidden = false

            --[[if (not next(sapienStatesArray, spaienUniqueID)) and sapienCounter % 2 == 1 then
                cardInfo.view.baseOffset = vec3((cardSize.x + cardPadding) * 0.5, -(cardSize.y + cardPadding) * (cardInfo.row - 1), 0.0)
            else
                cardInfo.view.baseOffset = vec3((cardSize.x + cardPadding) * (cardInfo.column - 1), -(cardSize.y + cardPadding) * (cardInfo.row - 1), 0.0)
            end]]

            local sapienObject = {
                uniqueID = spaienUniqueID,
                sharedState = sharedState,
                objectTypeIndex = gameObject.types.sapien.index
            }
            
            local animationInstance = uiAnimation:getUIAnimationInstance(sapienConstants:getAnimationGroupKey(sapienObject.sharedState))
            uiCommon:setGameObjectViewObject(cardInfo.objectImageView, sapienObject, animationInstance)
        end
    end
    updatePanelInfoForSapienStates(detailInfo, sapienCounter)
end

local function updateSelectButton(availableForSelection, isLocalPlayerOwned)
    if availableForSelection then
        uiStandardButton:setDisabled(selectTribeButton, false)
        if isLocalPlayerOwned then
            uiStandardButton:setTextWithShortcut(selectTribeButton, locale:get("ui_action_resumeTribe"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
        else
            uiStandardButton:setTextWithShortcut(selectTribeButton, locale:get("ui_action_chooseTribe"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
        end
    else
        uiStandardButton:setDisabled(selectTribeButton, true)
        uiStandardButton:setTextWithShortcut(selectTribeButton, locale:get("ui_action_chooseTribe"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
    end
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

local creationStatesRequestIndex = 0
local function updateInfo(detailInfo)
   --mj:log("detailInfo:", detailInfo)
    tribeSelectionUI.selectedTribeID = detailInfo.destinationID
    local isPlayerControlled = (detailInfo.clientID ~= nil)
    local isLocalPlayerOwned = detailInfo.ownedByLocalPlayer

    local availableForSelection = false
    if isLocalPlayerOwned or (detailInfo.failedTribe and detailInfo.population > 0) then
        availableForSelection = true
    elseif (not detailInfo.clientID) then
        if gameConstants.debugAllowPlayersToTakeOverAITribes or (not detailInfo.loadState) or detailInfo.loadState == destination.loadStates.seed then
            availableForSelection = true
        end
    end

    updateSelectButton(availableForSelection, isLocalPlayerOwned)

    if (not availableForSelection) or isLocalPlayerOwned then
        
        selectableTribeView.hidden = true

        --mj:log("detailInfo:", detailInfo)

        local titleText = nil
        if isPlayerControlled then
            titleText = string.format("%s - %s", 
            locale:get("misc_tribeName", {tribeName = detailInfo.name}), 
            locale:get("misc_tribeLedBy", {playerName = detailInfo.playerName or "no_name"}))
        else
            titleText = string.format("%s - %s", 
            locale:get("misc_tribeName", {tribeName = detailInfo.name}), 
            locale:get("misc_aiTribe"))
        end

        if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu then
            titleText = titleText .. " " .. tribeSelectionUI.selectedTribeID
        end

        titleTextView:setText(titleText, material.types.standardText.index)


        local panelHeight = 360
        local panelSizeToUse = vec2(panelWidth, panelHeight)
        local scaleToUseX = panelSizeToUse.x * 0.5
        local scaleToUseY = panelSizeToUse.y * 0.5 / (9.0/16.0)
        mainView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
        mainView.size = panelSizeToUse
        selectableTribeView.size = mainView.size

        tribeSapiensRenderGameObjectView.hidden = true
        logicInterface:callServerFunction("getTribeSapienInfos", {tribeID = tribeSelectionUI.selectedTribeID}, function(sapienInfos)
            --mj:log("got getTribeSapienInfos result:", result)
            if sapienInfos and (not mainView.hidden) then
                uiTribeView:setTribe(tribeSapiensRenderGameObjectView, tribeSelectionUI.selectedTribeID, sapienInfos, world:getWorldTime())
                tribeSapiensRenderGameObjectView.hidden = false

                playerOwnedTribePopulationTextView.text = locale:get("tribeUI_population") .. ": " .. mj:tostring(getTribePopulation(sapienInfos))
                playerOwnedTribePopulationTextView.hidden = false
            end
        end)
    else
        tribeSapiensRenderGameObjectView.hidden = true
        playerOwnedTribePopulationTextView.hidden = true
        selectableTribeView.hidden = false
        uiStandardButton:setDisabled(selectTribeButton, false)

        local function updateBiomeTags(detailInfo_)
            local biomeDescription = biome:getDescriptionFromTags(detailInfo_.biomeTags)
            local biomeDifficulty = biome:getDifficultyLevelFromTags(detailInfo_.biomeTags)

            local difficultyString = biome.difficultyStrings[biomeDifficulty]
            local difficultyColor = biome.difficultyColors[biomeDifficulty]

            biomeDifficultyValueTextView.text = difficultyString
            biomeDifficultyValueTextView.color = difficultyColor

            biomeDescriptionTextView.text = biomeDescription

            updateDifficultyIconModel(biomeDifficulty)
        end

        --biomeTextView:addColoredText("\n" .. biomeDescription, vec4(1.0,1.0,1.0,1.0))
        
        if detailInfo.creationSapienStates and detailInfo.biomeTags then
            updateBiomeTags(detailInfo)
            displaySapienStates(detailInfo) --resizies the panel, so call this last
        else
            updatePanelInfoForSapienStates(detailInfo, 0)

            creationStatesRequestIndex = creationStatesRequestIndex + 1
            local thisCreationStatesRequestIndex = creationStatesRequestIndex
            logicInterface:callServerFunction("getDestinationInfoForClientTribeSelection", detailInfo.destinationID, function(additionalInfo)
                if additionalInfo and creationStatesRequestIndex == thisCreationStatesRequestIndex then
                    detailInfo.creationSapienStates = additionalInfo.creationSapienStates
                    detailInfo.biomeTags = additionalInfo.biomeTags
                    updateBiomeTags(detailInfo)
                    displaySapienStates(detailInfo) --resizies the panel, so call this last
                end
            end)
            --get from server
        end
    end
end

local function slideOff()
    if not slidingOffMainBanner then
        slidingOffMainBanner = true
        audio:playUISound("audio/sounds/ui/stone.wav")
        mainView.update = function(dt_)
            mainViewAnimateOnTimer = mainViewAnimateOnTimer - dt_ * 4.0
            local fraction = mainViewAnimateOnTimer
            fraction = math.pow(fraction, 0.8)
            if fraction > 0.0 then
                mainView.baseOffset = vec3(bannerXOffset, slideAnimationOffset * (1.0 - fraction), 0)
            else
                mainViewAnimateOnTimer = 0.0
                mainView.update = nil
                mainView.hidden = true
                if slideOnWhenDoneInfo then
                    displaySapienStates(slideOnWhenDoneInfo)
                    localPlayer:tribeSelectionUIBecameVisible()
                    slideOnWhenDoneInfo = nil
                end
            end
        end
    end
end

local confirmFunction = nil

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            if confirmFunction then
                confirmFunction()
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

function tribeSelectionUI:init(world_, gameUI_, tribeSelectionMarkersUI_, localPlayer_, logicInterface_)
    world = world_
    gameUI = gameUI_
    tribeSelectionMarkersUI = tribeSelectionMarkersUI_
    localPlayer = localPlayer_
    logicInterface = logicInterface_
    local ownerView = gameUI.view

    slideAnimationOffset = -ownerView.size.y
    

    mainView = ModelView.new(ownerView)
    

    --mainView:setRenderTargetBacked(true)
    mainView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    mainView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
    mainView.hidden = true

    mainView.keyChanged = keyChanged
    
    

    local titleView = View.new(mainView)
    titleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleView.baseOffset = vec3(0,-15, 0)
    titleView.size = vec2(200, 32.0)
    

    titleTextView = ModelTextView.new(titleView)
    titleTextView.font = Font(uiCommon.titleFontName, 28)
    titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    --titleTextView.relativeView = titleIcon
    --titleTextView.baseOffset = vec3(titleIconPadding, 0, 0)

    selectableTribeView = View.new(mainView)
    selectableTribeView.size = mainView.size
    
    cardContainerView = View.new(selectableTribeView)
    cardContainerView.size = vec2(cardSize.x * sapienColumns + cardPadding * (sapienColumns - 1), cardSize.y * sapienRows + cardPadding * (sapienRows - 1))
    cardContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    cardContainerView.baseOffset = vec3(0,-cardContainerViewYOffsetFromTop,0)

    for row = 1,sapienRows do
        for column = 1,sapienColumns do
            
            local cardView = ModelView.new(cardContainerView)
            cardView:setModel(model:modelIndexForName("ui_inset_lg_10x3"))
            cardView.scale3D = vec3(cardSize.x * 0.5, cardSize.x * 0.5 / 0.3 * (cardSize.y / cardSize.x) ,cardSize.x * 0.5)
            
            cardView.size = cardSize
            cardView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
            cardView.hidden = true

            cardView.baseOffset = vec3((cardSize.x + cardPadding) * (column - 1), -(cardSize.y + cardPadding) * (row - 1), 0.0)
            
            local nameView = TextView.new(cardView)
            nameView.font = Font(uiCommon.fontName, 16)
            nameView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
            nameView.color = mj.textColor
            nameView.baseOffset = vec3(72.0,-4.0,0.0)

            local secondLineView = TextView.new(cardView)
            secondLineView.font = Font(uiCommon.fontName, 16)
            secondLineView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
            secondLineView.relativeView = nameView
            secondLineView.color = mj.textColor
            secondLineView.baseOffset = vec3(0.0,2.0,0.0)

            local thirdLineView = TextView.new(cardView)
            thirdLineView.font = Font(uiCommon.fontName, 16)
            thirdLineView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
            thirdLineView.relativeView = secondLineView
            thirdLineView.color = mj.textColor
            thirdLineView.baseOffset = vec3(0.0,2.0,0.0)
            
            local objectImageView = GameObjectView.new(cardView, objectImageViewSize)
            objectImageView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            objectImageView.size = objectImageViewSize
            objectImageView.baseOffset = vec3(4.0,0.0,0.0)

            local cardInfo = {
                view = cardView,
                nameView = nameView,
                secondLineView = secondLineView,
                thirdLineView = thirdLineView,
                objectImageView = objectImageView,
                row = row,
                column = column,
            }

            table.insert(sapienCards, cardInfo)
        end
    end
    
    biomeDifficultyTitleTextView = TextView.new(selectableTribeView)
    biomeDifficultyTitleTextView.font = Font(uiCommon.fontName, 18)
    biomeDifficultyTitleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    biomeDifficultyTitleTextView.relativeView = cardContainerView
    biomeDifficultyTitleTextView.color = mj.textColor
    biomeDifficultyTitleTextView.baseOffset = vec3(0.0,-biomeTextViewYPadding,0.0)
    biomeDifficultyTitleTextView.text = locale:get("misc_BiomeDifficulty") .. ":"

    
    local starsHalfSize = 50.0
    biomeDifficultyStarsIcon = ModelView.new(selectableTribeView)
    biomeDifficultyStarsIcon.masksEvents = false
    biomeDifficultyStarsIcon.scale3D = vec3(starsHalfSize,starsHalfSize,starsHalfSize)
    biomeDifficultyStarsIcon.size = vec2(starsHalfSize,starsHalfSize) * 2.0
    biomeDifficultyStarsIcon.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    biomeDifficultyStarsIcon.relativeView = biomeDifficultyTitleTextView
    biomeDifficultyStarsIcon.baseOffset = vec3(4.0,1.0,0.0)

    biomeDifficultyValueTextView  = TextView.new(selectableTribeView)
    biomeDifficultyValueTextView.font = Font(uiCommon.fontName, 18)
    biomeDifficultyValueTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    biomeDifficultyValueTextView.relativeView = biomeDifficultyStarsIcon
    biomeDifficultyValueTextView.baseOffset = vec3(4.0,-1.0,0.0)
    
    biomeDescriptionTextView = TextView.new(selectableTribeView)
    biomeDescriptionTextView.font = Font(uiCommon.fontName, 18)
    biomeDescriptionTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    biomeDescriptionTextView.relativeView = cardContainerView
    biomeDescriptionTextView.color = mj.textColor
    biomeDescriptionTextView.baseOffset = vec3(0.0,-biomeTextViewYPadding - 24,0.0)
    biomeDescriptionTextView.wrapWidth = cardSize.x * 2 + cardPadding

    selectTribeButton = uiStandardButton:create(mainView, vec2(180, 40))
    selectTribeButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    selectTribeButton.baseOffset = vec3(0, 20.0, 0)

    confirmFunction = function()
        uiStandardButton:setDisabled(selectTribeButton, true)
        tribeSelectionUI:hide(false)
        --tutorialUI:hide()
        --tutorialUI:enable()

        if not disabledAndWaitingForServer then
            disabledAndWaitingForServer = true
            logicInterface:callServerFunction("selectStartTribe", tribeSelectionUI.selectedTribeID, function(tribeInfo)
                disabledAndWaitingForServer = false
                if tribeInfo then
                    world:serverAssignedTribe(tribeInfo.destinationID)
                    gameUI:transitionToWorldViewAfterTribeCreation(tribeInfo)
                end
            end)
        end
    end
    
    
    uiStandardButton:setClickFunction(selectTribeButton, function()
            confirmFunction()
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        --mj:log("controllerSetIndexMenu callback:", tribeSelectionUI:hidden(), " isDown:", isDown)
        if isDown and (not tribeSelectionUI:hidden()) and (not uiStandardButton:getDisabled(selectTribeButton)) then
            --mj:log("confirm")
            confirmFunction()
            return true
        end
    end)
    
    local closeButton = uiStandardButton:create(mainView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        tribeSelectionUI:hide(true)
    end)



    local tribeSapiensRenderGameObjectViewSize = vec2(panelWidth - 20, 300)

    --[[local testView = ColorView.new(selectedTribeView)
    testView.size = tribeSapiensRenderGameObjectViewSize
    testView.color = vec4(0.2,0.6,0.2,0.5)
    testView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    testView.baseOffset = vec3(0,55, 0)]]

    tribeSapiensRenderGameObjectView = uiTribeView:create(mainView, tribeSapiensRenderGameObjectViewSize)
    tribeSapiensRenderGameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    tribeSapiensRenderGameObjectView.baseOffset = vec3(0,52, 0)

    playerOwnedTribePopulationTextView = TextView.new(mainView)
    playerOwnedTribePopulationTextView.font = Font(uiCommon.titleFontName, 22)
    playerOwnedTribePopulationTextView.color = mj.textColor
    playerOwnedTribePopulationTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    playerOwnedTribePopulationTextView.relativeView = titleView
    --playerOwnedTribePopulationTextView.baseOffset = vec3(0,0,0)
    
end


function tribeSelectionUI:initForTribeFailReset(world_, gameUI_, tribeSelectionMarkersUI_, localPlayer_, logicInterface_)
    if not mainView then
        tribeSelectionUI:init(world_, gameUI_, tribeSelectionMarkersUI_, localPlayer_, logicInterface_)
    end
end

function tribeSelectionUI:showTribe(detailInfo)
    
    updateInfo(detailInfo)

   --[[ if not mainView.hidden and (not slidingOffMainBanner) then
        updateInfo(detailInfo)
        --queuedInfo = detailInfo
        --slideOff()
    elseif mainView.hidden then
        updateInfo(detailInfo)
        slideOn()
        localPlayer:tribeSelectionUIBecameVisible()
    end]]
end

function tribeSelectionUI:hidden()
    return (not mainView) or mainView.hidden
end

function tribeSelectionUI:hide(notifyPlayerToZoomOut)
    if mainView and (not mainView.hidden) and (not slidingOffMainBanner) then
        --mj:error("tribeSelectionUI:hide")
        eventManager:setTextEntryListener(nil)
        tribeSelectionMarkersUI:clearSelection()
        if notifyPlayerToZoomOut then
            localPlayer:tribeSelectionUIWasHidden()
        end
        slideOff()
    end
end

return tribeSelectionUI