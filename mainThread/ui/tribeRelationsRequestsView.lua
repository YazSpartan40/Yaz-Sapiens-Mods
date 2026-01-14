local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec2 = mjm.vec2



local locale = mjrequire "common/locale"
--local gameObject = mjrequire "common/gameObject"
local model = mjrequire "common/model"
local material = mjrequire "common/material"

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


local tribeRelationsRequestsView = {}

local gameUI = nil
local world = nil
local logicInterface = nil

local tradeAllowedMainContainerView = nil
local noTradeMainContainerView = nil

local tradeRequestsSummaryTextView = nil
local noTradeSummaryTextView = nil
local requestsListView = nil

local requestsListItems = {}
local hoverColor = mj.highlightColorFavor * 0.6
local mouseDownColor = mj.highlightColorFavor * 0.8
local backgroundColors = {vec4(0.5,0.5,0.5,0.05), vec4(0.0,0.0,0.0,0.05)}
local tradeListViewItemHeight = 40
local listViewItemObjectImageViewSize = vec2(38.0, 38.0)

local requestSelectedRowIndex = nil

local selectedRequestGameObjectViewSize = vec2(50,50)
local selectedRequestCountLayoutView = nil
local selectedRequestCountTextView = nil
local selectedRequestGameObjectView = nil
local selectedRequestResourceNameTextView = nil
local selectedRequestDeliveredCountTextView = nil
local selectedRequestLargeFavorView = nil

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


local function updateInfoForSelectedRequest()
    if requestSelectedRowIndex then
        local requestListItem = requestsListItems[requestSelectedRowIndex]
        local requestItemCount = requestListItem.requestInfo.count
        selectedRequestCountTextView.text = mj:tostring(requestItemCount)


        uiGameObjectView:setObject(selectedRequestGameObjectView, {
            objectTypeIndex = resource.types[requestListItem.resourceTypeIndex].displayGameObjectTypeIndex
        }, nil, nil)

        selectedRequestCountLayoutView.size = vec2(selectedRequestGameObjectView.size.x + selectedRequestCountTextView.size.x - 4, math.max(selectedRequestGameObjectView.size.y, selectedRequestCountTextView.size.y) + 5)

        selectedRequestCountLayoutView.hidden = false
        selectedRequestResourceNameTextView.text = resource.types[requestListItem.resourceTypeIndex].plural

        local deliveredCount = requestListItem.deliveredCount or 0
        local textString = string.format("%s: %d/%d", locale:get("ui_name_delivered"), deliveredCount, requestItemCount)

        selectedRequestDeliveredCountTextView.text = textString

        selectedRequestLargeFavorView.hidden = false
        uiFavorView:setValue(selectedRequestLargeFavorView, requestListItem.requestInfo.reward, true)

        uiStandardButton:setDisabled(mainZoomButton, false)

    else
        selectedRequestCountLayoutView.hidden = true
        selectedRequestResourceNameTextView.text = ""
        selectedRequestDeliveredCountTextView.text = ""
        selectedRequestLargeFavorView.hidden = true

        uiStandardButton:setDisabled(mainZoomButton, true)
    end
end

local function zoomToStorageArea(rowIndex)
    if rowIndex then
        local requestInfo = requestsListItems[rowIndex].requestInfo
        if requestInfo.storageAreaID then
            logicInterface:callLogicThreadFunction("retrieveObject", requestInfo.storageAreaID, function(result)
                if result and result.found then
                    gameUI:followObject(result, false, {dismissAnyUI = true, showInspectUI = true})
                else
                    gameUI:teleportToLookAtPos(requestInfo.storageAreaPos)
                end
            end)
        end
    end
end

local function updateRequestSelectedIndex(thisIndex, wasClick)
    if requestSelectedRowIndex ~= thisIndex then
        requestSelectedRowIndex = thisIndex
        if requestSelectedRowIndex == 0 then
            requestSelectedRowIndex = nil
        end
        if requestSelectedRowIndex then
            --mj:log("requestsListItems:", requestsListItems, "requestSelectedRowIndex:", requestSelectedRowIndex)
            uiSelectionLayout:setSelection(requestsListView, requestsListItems[requestSelectedRowIndex].backgroundView)
        end
        updateInfoForSelectedRequest()
        return true
    end
    if not wasClick then
        uiSelectionLayout:setActiveSelectionLayoutView(requestsListView)
    end
    return false
end

function tribeRelationsRequestsView:selectOfferWithResourceTypeIndex(resourceTypeIndex)
    for rowIndex,listItem in ipairs(requestsListItems) do
        if listItem.resourceTypeIndex == resourceTypeIndex then
            updateRequestSelectedIndex(rowIndex, false)
            break
        end
    end
end

function tribeRelationsRequestsView:update(destinationState)
    local relationshipState = destinationState.relationships[world:getTribeID()]

    if relationshipState.favorIsBelowTradingThreshold then
        tradeAllowedMainContainerView.hidden = true
        noTradeMainContainerView.hidden = false

        noTradeSummaryTextView.text = locale:get("tribeRelations_willNotTradeTitle", {tribeName = destinationState.name})

        return
    end

    tradeRequestsSummaryTextView.text = locale:get("tribeRelations_gainFavorForRequests", {tribeName = destinationState.name})

    local tradeables = destinationState.tradeables

    uiScrollView:removeAllRows(requestsListView)
    uiSelectionLayout:removeAllViews(requestsListView)
    requestsListItems = {}
    
    local rowIndex = 1
    if tradeables and tradeables.requests then
        for resourceTypeIndex,requestInfo in pairs(tradeables.requests) do

            local rowBackgroundView = createRowBackground(requestsListView, rowIndex)
            
            local gameObjectView = uiGameObjectView:create(rowBackgroundView, listViewItemObjectImageViewSize, uiGameObjectView.types.standard)
            gameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            gameObjectView.baseOffset = vec3(0,0, 2)
            uiGameObjectView:setObject(gameObjectView, {
                objectTypeIndex = resource.types[resourceTypeIndex].displayGameObjectTypeIndex
            }, nil, nil)

            local objectTitleTextView = TextView.new(rowBackgroundView)
            objectTitleTextView.font = Font(uiCommon.fontName, 16)
            objectTitleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
            objectTitleTextView.relativeView = gameObjectView
            
            local tradeRequestDeliveries = relationshipState.tradeRequestDeliveries
            local deliveredCount = tradeRequestDeliveries and tradeRequestDeliveries[resourceTypeIndex]

            local textString = nil
            if deliveredCount and deliveredCount > 0 then
                textString = string.format("%d %s (%d)", requestInfo.count, resource.types[resourceTypeIndex].plural, deliveredCount)
            else
                textString = string.format("%d %s", requestInfo.count, resource.types[resourceTypeIndex].plural)
            end

            objectTitleTextView.text = textString

            local favorView = uiFavorView:create(rowBackgroundView)
            favorView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
            favorView.baseOffset = vec3(-5,0, 1)
            uiFavorView:setValue(favorView, requestInfo.reward, true)

            
            requestsListItems[rowIndex] = {
                backgroundView = rowBackgroundView,
                resourceTypeIndex = resourceTypeIndex,
                requestInfo = requestInfo,
                deliveredCount = deliveredCount,
            }
            
            uiSelectionLayout:addView(requestsListView, rowBackgroundView)
            
            local indexCopy = rowIndex
            uiMenuItem:makeMenuItemBackground(rowBackgroundView, requestsListView, rowIndex, hoverColor, mouseDownColor, function(wasClick)
                updateRequestSelectedIndex(indexCopy, wasClick)
            end)

            local zoomButton = nil
            local zoomButtonSize = 22
            local function hoverStart()
                if not zoomButton then
                    zoomButton = uiStandardButton:create(rowBackgroundView, vec2(zoomButtonSize,zoomButtonSize), uiStandardButton.types.slim_1x1)
                    zoomButton.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
                    zoomButton.relativeView = favorView
                    zoomButton.baseOffset = vec3(-6, 0, 3)
                    uiStandardButton:setIconModel(zoomButton, "icon_inspect")
                    uiStandardButton:setClickFunction(zoomButton, function()
                        zoomToStorageArea(indexCopy)
                    end)
                    uiToolTip:add(zoomButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_action_zoom"), nil, vec3(0,-8,10), nil, zoomButton, requestsListView)
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
    end


    local infoWasUpdated = false
    if (not requestSelectedRowIndex) or (requestSelectedRowIndex > #requestsListItems) then
        if requestSelectedRowIndex and #requestsListItems > 0 then
            infoWasUpdated = updateRequestSelectedIndex(#requestsListItems, false)
        else
            if #requestsListItems > 0 then
                infoWasUpdated = updateRequestSelectedIndex(1, false)
            else
                infoWasUpdated = updateRequestSelectedIndex(nil, false)
            end
        end
    end

    if not infoWasUpdated then
        if requestSelectedRowIndex then
            mj:log("tribeRelationsRequestsView setting selection:", requestSelectedRowIndex)
            --uiSelectionLayout:setActiveSelectionLayoutView(requestsListView)--wrong place
            uiSelectionLayout:setSelection(requestsListView, requestsListItems[requestSelectedRowIndex].backgroundView)
        end
    end
end

function tribeRelationsRequestsView:didBecomeVisible()
    uiSelectionLayout:setActiveSelectionLayoutView(requestsListView)
end

function tribeRelationsRequestsView:load(tradeRequestsView, gameUI_, world_, logicInterface_)
    gameUI = gameUI_
    world = world_
    logicInterface = logicInterface_

    tradeAllowedMainContainerView = View.new(tradeRequestsView)
    tradeAllowedMainContainerView.size = tradeRequestsView.size

    noTradeMainContainerView = View.new(tradeRequestsView)
    noTradeMainContainerView.size = tradeRequestsView.size
    noTradeMainContainerView.hidden = true


    noTradeSummaryTextView = TextView.new(noTradeMainContainerView)
    noTradeSummaryTextView.font = Font(uiCommon.fontName, 18)
    noTradeSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    noTradeSummaryTextView.color = mj.textColor
    noTradeSummaryTextView.baseOffset = vec3(0,0, 0)

    tradeRequestsSummaryTextView = TextView.new(tradeAllowedMainContainerView)
    tradeRequestsSummaryTextView.font = Font(uiCommon.fontName, 18)
    tradeRequestsSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    tradeRequestsSummaryTextView.color = mj.textColor
    tradeRequestsSummaryTextView.baseOffset = vec3(0,-20, 0)
    

    local requestsListInsetViewSize = vec2(math.floor(tradeAllowedMainContainerView.size.x * 0.6) - 10, tradeAllowedMainContainerView.size.y - 40 - 12 - 10)
    local requestsScrollViewSize = vec2(requestsListInsetViewSize.x - 10, requestsListInsetViewSize.y - 10)
    local requestsInsetView = ModelView.new(tradeAllowedMainContainerView)
    requestsInsetView:setModel(model:modelIndexForName("ui_inset_lg_2x3"), {
        [material.types.ui_background_inset.index] = material.types.ui_background_inset_lighter.index,
    })
    local scaleToUsePaneX = requestsListInsetViewSize.x * 0.5 / (2.0/3.0)
    local scaleToUsePaneY = requestsListInsetViewSize.y * 0.5
    requestsInsetView.scale3D = vec3(scaleToUsePaneX,scaleToUsePaneY,scaleToUsePaneX)
    requestsInsetView.size = requestsListInsetViewSize
    requestsInsetView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    requestsInsetView.baseOffset = vec3(20,12,0)

    requestsListView = uiScrollView:create(requestsInsetView, requestsScrollViewSize, MJPositionInnerLeft)
    requestsListView.baseOffset = vec3(0, 0, 2)
    uiSelectionLayout:createForView(requestsListView)

    local rightPane = View.new(tradeAllowedMainContainerView)
    --rightPane.color = vec4(0.5,0.0,0.0,0.5)
    rightPane.size = vec2(tradeAllowedMainContainerView.size.x - 44 - requestsListInsetViewSize.x, requestsListInsetViewSize.y + 6)
    rightPane.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightPane.baseOffset = vec3(-14,2,0)

    selectedRequestCountLayoutView = View.new(rightPane)
    selectedRequestCountLayoutView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    selectedRequestCountLayoutView.baseOffset = vec3(0,10, 0)

    selectedRequestCountTextView = TextView.new(selectedRequestCountLayoutView)
    selectedRequestCountTextView.font = Font(uiCommon.fontName, 36)
    selectedRequestCountTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    selectedRequestCountTextView.color = mj.textColor

    selectedRequestGameObjectView = uiGameObjectView:create(selectedRequestCountLayoutView, selectedRequestGameObjectViewSize, uiGameObjectView.types.standard)
    selectedRequestGameObjectView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
    selectedRequestGameObjectView.baseOffset = vec3(0,2, 0)

    selectedRequestResourceNameTextView = TextView.new(rightPane)
    selectedRequestResourceNameTextView.font = Font(uiCommon.fontName, 20)
    selectedRequestResourceNameTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectedRequestResourceNameTextView.relativeView = selectedRequestCountLayoutView
    selectedRequestResourceNameTextView.color = mj.textColor
    selectedRequestResourceNameTextView.baseOffset = vec3(0,10, 0)
    selectedRequestResourceNameTextView.wrapWidth = rightPane.size.x

    selectedRequestDeliveredCountTextView = TextView.new(rightPane)
    selectedRequestDeliveredCountTextView.font = Font(uiCommon.fontName, 20)
    selectedRequestDeliveredCountTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectedRequestDeliveredCountTextView.relativeView = selectedRequestResourceNameTextView
    selectedRequestDeliveredCountTextView.color = mj.textColor
    selectedRequestDeliveredCountTextView.baseOffset = vec3(0,0,0)
    selectedRequestDeliveredCountTextView.wrapWidth = rightPane.size.x

    selectedRequestLargeFavorView = uiFavorView:create(rightPane, uiFavorView.types.large_1x1)
    selectedRequestLargeFavorView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    selectedRequestLargeFavorView.baseOffset = vec3(0,-10,0)

    mainZoomButton = uiStandardButton:create(rightPane, vec2(200, 50), nil)
    mainZoomButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    mainZoomButton.baseOffset = vec3(0, 10, 0)
    uiStandardButton:setTextWithShortcut(mainZoomButton, locale:get("ui_action_zoom"), "game", "confirmSpecial", eventManager.controllerSetIndexMenu, "menuSpecial")
    uiStandardButton:setClickFunction(mainZoomButton, function()
        if requestSelectedRowIndex then
            zoomToStorageArea(requestSelectedRowIndex)
            --[[local requestInfo = requestsListItems[requestSelectedRowIndex].requestInfo


            local objectInfoForInspect = {
                uniqueID = requestInfo.storageAreaID,
                objectTypeIndex = gameObject.types.storageArea.index,
                pos = requestInfo.storageAreaPos,
            }

            gameUI:followObject(objectInfoForInspect, false, {dismissAnyUI = true, showInspectUI = true})]]
        end
    end)
    
    updateInfoForSelectedRequest()

end

return tribeRelationsRequestsView