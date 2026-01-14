local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec2 = mjm.vec2



local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
local gameObject = mjrequire "common/gameObject"

--local sapienConstants = mjrequire "common/sapienConstants"
--local constructable = mjrequire "common/constructable"
local resource = mjrequire "common/resource"
--local quest = mjrequire "common/quest"
--local gameConstants = mjrequire "common/gameConstants"
--local rng = mjrequire "common/randomNumberGenerator"
--local audio = mjrequire "mainThread/audio"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiFavorView = mjrequire "mainThread/ui/uiCommon/uiFavorView"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
--local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"

local uiMenuItem = mjrequire "mainThread/ui/uiCommon/uiMenuItem"


local tribeRelationsOffersView = {}

local gameUI = nil
local world = nil
local logicInterface = nil

local tradeAllowedMainContainerView = nil
local noTradeMainContainerView = nil

local tradeOffersSummaryTextView = nil
local noTradeSummaryTextView = nil
local offersListView = nil


local offersListItems = {}
local hoverColor = mj.highlightColorFavor * 0.6
local mouseDownColor = mj.highlightColorFavor * 0.8
local backgroundColors = {vec4(0.5,0.5,0.5,0.05), vec4(0.0,0.0,0.0,0.05)}
local tradeListViewItemHeight = 40
local listViewItemObjectImageViewSize = vec2(38.0, 38.0)

local offerSelectedRowIndex = nil

local selectedOfferGameObjectViewSize = vec2(50,50)
local selectedOfferCountLayoutView = nil
local selectedOfferCountTextView = nil
local selectedOfferGameObjectView = nil
local selectedOfferResourceNameTextView = nil
local selectedOfferPurchasedCountTextView = nil
local selectedOfferLargeFavorView = nil

local buyButton = nil
local mainZoomButton = nil


local function createRowBackground(listView, backgroundColorCounter)
    local rowBackgroundView = ColorView.new(listView)
    local defaultColor = backgroundColors[backgroundColorCounter % 2 + 1]

    rowBackgroundView.color = defaultColor

    rowBackgroundView.size = vec2(listView.size.x - 22, tradeListViewItemHeight)
    rowBackgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

    uiScrollView:insertRow(listView, rowBackgroundView, nil)

    return rowBackgroundView
end


local function updateInfoForSelectedOffer()
    if offerSelectedRowIndex then
        local offerListItem = offersListItems[offerSelectedRowIndex]
        selectedOfferCountTextView.text = mj:tostring(offerListItem.offerInfo.count)


        uiGameObjectView:setObject(selectedOfferGameObjectView, {
            objectTypeIndex = offerListItem.objectTypeIndex or resource.types[offerListItem.resourceTypeIndex].displayGameObjectTypeIndex
        }, nil, nil)

        selectedOfferCountLayoutView.size = vec2(selectedOfferGameObjectView.size.x + selectedOfferCountTextView.size.x - 4, math.max(selectedOfferGameObjectView.size.y, selectedOfferCountTextView.size.y) + 5)

        selectedOfferCountLayoutView.hidden = false

        local resourceOrObjectName = nil

        if offerListItem.resourceTypeIndex then
            resourceOrObjectName = resource.types[offerListItem.resourceTypeIndex].plural
        else
            resourceOrObjectName = gameObject.types[offerListItem.objectTypeIndex].plural
        end

        selectedOfferResourceNameTextView.text = resourceOrObjectName

        local purchasedCount = offerListItem.purchasedCount or 0
        local textString = string.format("%s: %d", locale:get("ui_name_purchased"), purchasedCount)

        selectedOfferPurchasedCountTextView.text = textString

        local disabled = offerListItem.offerInfo.tradeLimitReached
        selectedOfferLargeFavorView.hidden = disabled
        if not disabled then
            uiFavorView:setValue(selectedOfferLargeFavorView, -offerListItem.offerInfo.cost, false)
        end
            
        uiStandardButton:setDisabled(buyButton, disabled)
    else
        selectedOfferCountLayoutView.hidden = true
        selectedOfferResourceNameTextView.text = ""

        selectedOfferLargeFavorView.hidden = true

        uiStandardButton:setDisabled(buyButton, true)
    end
end

local function zoomToStorageArea(rowIndex)
    if rowIndex then
        local offerInfo = offersListItems[rowIndex].offerInfo
        logicInterface:callLogicThreadFunction("retrieveObject", offerInfo.storageAreaID, function(result)
            if result and result.found then
                gameUI:followObject(result, false, {dismissAnyUI = true, showInspectUI = true})
            else
                gameUI:teleportToLookAtPos(offerInfo.storageAreaPos)
            end
        end)
    end
end

local function updateOfferSelectedIndex(thisIndex, wasClick)
    if offerSelectedRowIndex ~= thisIndex then
        offerSelectedRowIndex = thisIndex
        if offerSelectedRowIndex == 0 then
            offerSelectedRowIndex = nil
        end
        if offerSelectedRowIndex then
            --mj:log("offersListItems:", offersListItems, "offerSelectedRowIndex:", offerSelectedRowIndex)
            uiSelectionLayout:setSelection(offersListView, offersListItems[offerSelectedRowIndex].backgroundView)
        end
        updateInfoForSelectedOffer()
        return true
    end
    if not wasClick then
        uiSelectionLayout:setActiveSelectionLayoutView(offersListView)
    end
    return false
end

function tribeRelationsOffersView:selectOfferWithResourceOrObjectTypeIndex(resourceTypeIndex, objectTypeIndex)
    for rowIndex,listItem in ipairs(offersListItems) do
        if listItem.resourceTypeIndex == resourceTypeIndex or listItem.objectTypeIndex == objectTypeIndex then
            updateOfferSelectedIndex(rowIndex, false)
            break
        end
    end
end

function tribeRelationsOffersView:update(destinationState)
    local relationshipState = destinationState.relationships[world:getTribeID()]

    if relationshipState.favorIsBelowTradingThreshold then
        tradeAllowedMainContainerView.hidden = true
        noTradeMainContainerView.hidden = false

        noTradeSummaryTextView.text = locale:get("tribeRelations_willNotTradeTitle", {tribeName = destinationState.name})

        return
    end

    tradeAllowedMainContainerView.hidden = false
    noTradeMainContainerView.hidden = true

    tradeOffersSummaryTextView.text = locale:get("tribeRelations_useFavorForOffers", {tribeName = destinationState.name})

    local tradeables = destinationState.tradeables

    uiScrollView:removeAllRows(offersListView)
    uiSelectionLayout:removeAllViews(offersListView)
    offersListItems = {}
    
    local rowIndex = 1
    if tradeables then

        local function createStuff(offerInfo, resourceTypeIndex, objectTypeIndex)
            local rowBackgroundView = createRowBackground(offersListView, rowIndex)
            
            local gameObjectView = uiGameObjectView:create(rowBackgroundView, listViewItemObjectImageViewSize, uiGameObjectView.types.standard)
            gameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            gameObjectView.baseOffset = vec3(0,0, 2)
            uiGameObjectView:setObject(gameObjectView, {
                objectTypeIndex = objectTypeIndex or resource.types[resourceTypeIndex].displayGameObjectTypeIndex
            }, nil, nil)

            local objectTitleTextView = TextView.new(rowBackgroundView)
            objectTitleTextView.font = Font(uiCommon.fontName, 16)
            objectTitleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
            objectTitleTextView.relativeView = gameObjectView

            local resourceOrObjectName = nil
            local purchasedCount = nil

            if resourceTypeIndex then
                local tradeOfferPurchases = relationshipState.tradeOfferPurchases 
                purchasedCount = tradeOfferPurchases and tradeOfferPurchases[resourceTypeIndex]
                resourceOrObjectName = resource.types[resourceTypeIndex].plural
            else
                local tradeOfferObjectTypePurchases = relationshipState.tradeOfferObjectTypePurchases 
                purchasedCount = tradeOfferObjectTypePurchases and tradeOfferObjectTypePurchases[objectTypeIndex]
                resourceOrObjectName = gameObject.types[objectTypeIndex].plural
            end

            local textString = nil
            if purchasedCount and purchasedCount > 0 then
                textString = string.format("%d %s (%d)", offerInfo.count, resourceOrObjectName, purchasedCount)
            else
                textString = string.format("%d %s", offerInfo.count, resourceOrObjectName)
            end

            objectTitleTextView.text = textString

            if not offerInfo.tradeLimitReached then
                local favorView = uiFavorView:create(rowBackgroundView)
                favorView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
                favorView.baseOffset = vec3(-5,0, 1)
                uiFavorView:setValue(favorView, -offerInfo.cost, false)
            end

            --[[if offerInfo.tradeLimitReached then
                uiFavorView:setDisabled(favorView, true)
            else
                uiFavorView:setDisabled(favorView, false)
            end]]

            offersListItems[rowIndex] = {
                backgroundView = rowBackgroundView,
                resourceTypeIndex = resourceTypeIndex,
                objectTypeIndex = objectTypeIndex,
                offerInfo = offerInfo,
                purchasedCount = purchasedCount
            }
            
            uiSelectionLayout:addView(offersListView, rowBackgroundView)
            
            local indexCopy = rowIndex
            uiMenuItem:makeMenuItemBackground(rowBackgroundView, offersListView, rowIndex, hoverColor, mouseDownColor, function(wasClick)
                updateOfferSelectedIndex(indexCopy, wasClick)
            end)


            local zoomButton = nil
            local zoomButtonSize = 22
            local function hoverStart()
                if not zoomButton then
                    zoomButton = uiStandardButton:create(rowBackgroundView, vec2(zoomButtonSize,zoomButtonSize), uiStandardButton.types.slim_1x1)
                    zoomButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
                    zoomButton.baseOffset = vec3(-6 - 5 - 40, 0, 3)
                    uiStandardButton:setIconModel(zoomButton, "icon_inspect")
                    uiStandardButton:setClickFunction(zoomButton, function()
                        zoomToStorageArea(indexCopy)
                    end)
                    uiToolTip:add(zoomButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_action_zoom"), nil, vec3(0,-8,10), nil, zoomButton, offersListView)
                end
            end
            
            local function hoverEnd()
                if zoomButton then
                    rowBackgroundView:removeSubview(zoomButton)
                    
                    zoomButton = nil
                end
            end
            
            uiMenuItem:setHoverFunctions(rowBackgroundView, hoverStart, hoverEnd)

            rowIndex = rowIndex + 1
        end

        if tradeables.offers then
            for resourceTypeIndex,offerInfo in pairs(tradeables.offers) do
                createStuff(offerInfo, resourceTypeIndex, nil)
            end
        end
        if tradeables.objectTypeOffers then
            for objectTypeIndex,offerInfo in pairs(tradeables.objectTypeOffers) do
                createStuff(offerInfo, nil, objectTypeIndex)
            end
        end
    end

    local infoWasUpdated = false
    if (not offerSelectedRowIndex) or (offerSelectedRowIndex > #offersListItems) then
        if offerSelectedRowIndex and #offersListItems > 0 then
            infoWasUpdated = updateOfferSelectedIndex(#offersListItems, false)
        else
            if #offersListItems > 0 then
                infoWasUpdated = updateOfferSelectedIndex(1, false)
            else
                infoWasUpdated = updateOfferSelectedIndex(nil, false)
            end
        end
    end

    if not infoWasUpdated then
        if offerSelectedRowIndex then
            mj:log("tribeRelationsOffersView setting selection:", offerSelectedRowIndex)
            --uiSelectionLayout:setActiveSelectionLayoutView(offersListView) --wrong place
            uiSelectionLayout:setSelection(offersListView, offersListItems[offerSelectedRowIndex].backgroundView)
            updateInfoForSelectedOffer()
        end
    end
    
end

function tribeRelationsOffersView:load(tradeOffersView, tribeRelationsUI, gameUI_, world_, logicInterface_)
    gameUI = gameUI_
    world = world_
    logicInterface = logicInterface_

    tradeAllowedMainContainerView = View.new(tradeOffersView)
    tradeAllowedMainContainerView.size = tradeOffersView.size

    noTradeMainContainerView = View.new(tradeOffersView)
    noTradeMainContainerView.size = tradeOffersView.size
    noTradeMainContainerView.hidden = true

    noTradeSummaryTextView = TextView.new(noTradeMainContainerView)
    noTradeSummaryTextView.font = Font(uiCommon.fontName, 18)
    noTradeSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    noTradeSummaryTextView.color = mj.textColor
    noTradeSummaryTextView.baseOffset = vec3(0,0, 0)

    tradeOffersSummaryTextView = TextView.new(tradeAllowedMainContainerView)
    tradeOffersSummaryTextView.font = Font(uiCommon.fontName, 18)
    tradeOffersSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    tradeOffersSummaryTextView.color = mj.textColor
    tradeOffersSummaryTextView.baseOffset = vec3(0,-20, 0)
    

    local offersListInsetViewSize = vec2(math.floor(tradeAllowedMainContainerView.size.x * 0.6) - 10, tradeAllowedMainContainerView.size.y - 40 - 12 - 10)
    local offersScrollViewSize = vec2(offersListInsetViewSize.x - 10, offersListInsetViewSize.y - 10)
    local offersInsetView = ModelView.new(tradeAllowedMainContainerView)
    offersInsetView:setModel(model:modelIndexForName("ui_inset_lg_2x3"), {
        [material.types.ui_background_inset.index] = material.types.ui_background_inset_lighter.index,
    })
    local scaleToUsePaneX = offersListInsetViewSize.x * 0.5 / (2.0/3.0)
    local scaleToUsePaneY = offersListInsetViewSize.y * 0.5
    offersInsetView.scale3D = vec3(scaleToUsePaneX,scaleToUsePaneY,scaleToUsePaneX)
    offersInsetView.size = offersListInsetViewSize
    offersInsetView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    offersInsetView.baseOffset = vec3(20,12,0)

    offersListView = uiScrollView:create(offersInsetView, offersScrollViewSize, MJPositionInnerLeft)
    offersListView.baseOffset = vec3(0, 0, 2)
    uiSelectionLayout:createForView(offersListView)

    local rightPane = View.new(tradeAllowedMainContainerView)
    --rightPane.color = vec4(0.5,0.0,0.0,0.5)
    rightPane.size = vec2(tradeAllowedMainContainerView.size.x - 44 - offersListInsetViewSize.x, offersListInsetViewSize.y + 6)
    rightPane.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightPane.baseOffset = vec3(-14,2,0)

    selectedOfferCountLayoutView = View.new(rightPane)
    selectedOfferCountLayoutView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    selectedOfferCountLayoutView.baseOffset = vec3(0,10, 0)

    selectedOfferCountTextView = TextView.new(selectedOfferCountLayoutView)
    selectedOfferCountTextView.font = Font(uiCommon.fontName, 36)
    selectedOfferCountTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    selectedOfferCountTextView.color = mj.textColor

    selectedOfferGameObjectView = uiGameObjectView:create(selectedOfferCountLayoutView, selectedOfferGameObjectViewSize, uiGameObjectView.types.standard)
    selectedOfferGameObjectView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
    selectedOfferGameObjectView.baseOffset = vec3(0,4, 0)

    selectedOfferResourceNameTextView = TextView.new(rightPane)
    selectedOfferResourceNameTextView.font = Font(uiCommon.fontName, 20)
    selectedOfferResourceNameTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectedOfferResourceNameTextView.relativeView = selectedOfferCountLayoutView
    selectedOfferResourceNameTextView.color = mj.textColor
    selectedOfferResourceNameTextView.baseOffset = vec3(0,10, 0)
    selectedOfferResourceNameTextView.wrapWidth = rightPane.size.x

    selectedOfferPurchasedCountTextView = TextView.new(rightPane)
    selectedOfferPurchasedCountTextView.font = Font(uiCommon.fontName, 20)
    selectedOfferPurchasedCountTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectedOfferPurchasedCountTextView.relativeView = selectedOfferResourceNameTextView
    selectedOfferPurchasedCountTextView.color = mj.textColor
    selectedOfferPurchasedCountTextView.baseOffset = vec3(0,0,0)
    selectedOfferPurchasedCountTextView.wrapWidth = rightPane.size.x

    selectedOfferLargeFavorView = uiFavorView:create(rightPane, uiFavorView.types.large_1x1)
    selectedOfferLargeFavorView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    selectedOfferLargeFavorView.baseOffset = vec3(0,10,0)

    buyButton = uiStandardButton:create(rightPane, vec2(200, 60), uiStandardButton.types.favor_10x3)
    buyButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    buyButton.baseOffset = vec3(0, 60, 0)
    uiStandardButton:setTextWithShortcut(buyButton, locale:get("ui_action_buy"), "game", "confirmSpecial", eventManager.controllerSetIndexMenu, "menuSpecial")
    uiStandardButton:setClickFunction(buyButton, function()
        local offerInfo = offersListItems[offerSelectedRowIndex].offerInfo
        local currentDestinationState = tribeRelationsUI:getCurrentDestinationState()
        uiStandardButton:setDisabled(buyButton, true)
        logicInterface:callServerFunction("buyTradeOffer", {
            destinationID = currentDestinationState.destinationID,
            offerInfo = offerInfo,
        }, function(updatedDestinationState)
            uiStandardButton:setDisabled(buyButton, false)
            if updatedDestinationState then
                tribeRelationsUI:updateDestination(updatedDestinationState)
            end
        end)

        --[[local relationshipState = currentDestinationState.relationships[world:getTribeID()]
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
                updateQuestState()
            end
        end)]]
    end)

    mainZoomButton = uiStandardButton:create(rightPane, vec2(200, 50), nil)
    mainZoomButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    mainZoomButton.baseOffset = vec3(0, 10, 0)
    uiStandardButton:setTextWithShortcut(mainZoomButton, locale:get("ui_action_zoom"), "game", "confirmSpecial", eventManager.controllerSetIndexMenu, "menuSpecial")
    uiStandardButton:setClickFunction(mainZoomButton, function()
        if offerSelectedRowIndex then
            zoomToStorageArea(offerSelectedRowIndex)
        end
    end)

    updateInfoForSelectedOffer()
end

function tribeRelationsOffersView:didBecomeVisible()
    uiSelectionLayout:setActiveSelectionLayoutView(offersListView)
end

return tribeRelationsOffersView