local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local locale = mjrequire "common/locale"
local gameObject = mjrequire "common/gameObject"
--local resource = mjrequire "common/resource"
--local model = mjrequire "common/model"
--local material = mjrequire "common/material"
local constructable = mjrequire "common/constructable"
local model = mjrequire "common/model"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local eventManager = mjrequire "mainThread/eventManager"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local keyMapping = mjrequire "mainThread/keyMapping"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
--local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local constructableUIHelper = mjrequire "mainThread/ui/constructableUIHelper"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"

local uiObjectGrid = mjrequire "mainThread/ui/uiCommon/uiObjectGrid"

local objectGridView = nil

local inspectTerrainFillSelectionUI = {}

inspectTerrainFillSelectionUI.itemList = constructableUIHelper.orderedFillTypeList

--local buttonInfos = {}

local world = nil
local inspectUI = nil

local leftPaneView = nil
--local gridView = nil

local rightPaneView = nil
local selectedTitleTextView = nil

local confirmButton = nil
local confirmFunction = nil
local selectedObjectImageView = nil
local selectedSummaryTextView = nil

local requiredResourcesView = nil
local requiredResourcesScrollView = nil
local useOnlyScrollView = nil
local requiredResourcesScrollViewHasFocus = false

local useOnlyTitleTextView = nil
local requiredResourcesTitleTextView = nil

local useOnlyHasFocus = false
local mainViewHasFocus = false

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

local function setMainViewHasFocus(newMainViewHasFocus)
    if mainViewHasFocus ~= newMainViewHasFocus then
        mainViewHasFocus = newMainViewHasFocus
        if mainViewHasFocus then
            uiStandardButton:setTextWithShortcut(confirmButton, locale:get("ui_action_set"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
        else
            uiStandardButton:setTextWithShortcut(confirmButton, locale:get("ui_action_set"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuCancel")
        end
    end
end


local function updateMainViewFocus()
    local newMainViewHasFocus = (not requiredResourcesScrollViewHasFocus)
    setMainViewHasFocus(newMainViewHasFocus)
end

local function setResourcesScrollViewFocus(newHasFocus)
    requiredResourcesScrollViewHasFocus = newHasFocus
    if requiredResourcesScrollViewHasFocus then
        if useOnlyHasFocus then
            requiredResourcesTitleTextView.color = mj.textColor
            useOnlyTitleTextView.color = mj.highlightColor
        else
            requiredResourcesTitleTextView.color = mj.highlightColor
            useOnlyTitleTextView.color = mj.textColor
        end
    else
        requiredResourcesTitleTextView.color = mj.textColor
        useOnlyTitleTextView.color = mj.textColor
    end
    updateMainViewFocus()
end

local function setUseOnlyHasFocus(newHasFocus)
    useOnlyHasFocus = newHasFocus
    setResourcesScrollViewFocus(requiredResourcesScrollViewHasFocus)
end

local function selectButton(buttonInfo)

    if buttonInfo.gridButtonData then
        local constructableTypeIndex = buttonInfo.gridButtonData.constructableTypeIndex
        local constructableType = constructable.types[constructableTypeIndex]
        
        --uiStandardButton:setTextWithShortcut(confirmButton, locale:get("ui_action_set"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSpecial")
        selectedTitleTextView.text = constructableType.name
        selectedSummaryTextView.text = constructableType.summary or locale:get("misc_no_summary_available")

        local gameObjectType = gameObject.types[constructableType.iconGameObjectType]
        uiGameObjectView:setObject(selectedObjectImageView, {objectTypeIndex = gameObjectType.index}, nil, nil)

        
        confirmFunction = function()
            world:setTerrainFillConstructableTypeIndex(constructableTypeIndex)
            inspectUI:hideUIPanel(false)
        end
        uiStandardButton:setClickFunction(confirmButton, confirmFunction)

        uiStandardButton:setDisabled(confirmButton, false)

        local function allObjectsForAnyResourceUncheckedChanged(hasAllObjectsForAnyResourceUnchecked)
            uiStandardButton:setDisabled(confirmButton, hasAllObjectsForAnyResourceUnchecked)
        end

        local restrictedObjectsChangedFunction = function()
        end

        constructableUIHelper:updateRequiredResources(requiredResourcesScrollView, useOnlyScrollView, constructableType, allObjectsForAnyResourceUncheckedChanged, restrictedObjectsChangedFunction)
    end
    
end

local function update()
    local gridData = {}
    
    local selectedConstructableTypeIndex = constructableUIHelper:getTerrainFillConstructableTypeIndex()
    local buttonIndexToSelect = nil

    for i, constructableTypeIndex in ipairs(inspectTerrainFillSelectionUI.itemList) do

        local constructableType = constructable.types[constructableTypeIndex]

        local gameObjectType = gameObject.types[constructableType.iconGameObjectType]

        local hasSeenRequiredResources = constructableUIHelper:checkHasSeenRequiredResourcesIncludingVariations(constructableType, nil)
        local hasSeenRequiredTools = constructableUIHelper:checkHasSeenRequiredTools(constructableType, nil)
        local discoveryComplete = constructableUIHelper:checkHasRequiredDiscoveries(constructableType)

        local newUnlocked = discoveryComplete and hasSeenRequiredResources and hasSeenRequiredTools

        gridData[i] = {
            constructableTypeIndex = constructableTypeIndex,

            gameObjectTypeIndex = gameObjectType.index,
            name = constructableType.name,
            disabledToolTipText = constructableUIHelper:getDisabledToolTipText(discoveryComplete, hasSeenRequiredResources, hasSeenRequiredTools),
            enabled = newUnlocked,
        }

        if selectedConstructableTypeIndex == constructableTypeIndex then
            buttonIndexToSelect = i
        end
    end

    uiObjectGrid:updateButtons(objectGridView, gridData, buttonIndexToSelect)
end

function inspectTerrainFillSelectionUI:load(inspectUI_, inspectTerrainUI, world_, terrainFillSelectionContainerView)

    inspectUI = inspectUI_
    world = world_

    local contentView = View.new(terrainFillSelectionContainerView)
    contentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    contentView.size = vec2(terrainFillSelectionContainerView.size.x, terrainFillSelectionContainerView.size.y - 40.0)

    local paneViewSize = vec2(contentView.size.x * 0.5 - 20, contentView.size.y)

    leftPaneView = View.new(contentView)
    leftPaneView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    leftPaneView.baseOffset = vec3(20,0, 0)
    leftPaneView.size = paneViewSize
    
    leftPaneView.keyChanged = keyChanged --hmmm leftPaneView?
    
    rightPaneView = View.new(contentView)
    rightPaneView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightPaneView.baseOffset = vec3(-24,0, 0)
    rightPaneView.size = paneViewSize

    selectedObjectImageView = uiGameObjectView:create(rightPaneView, vec2(200,200), uiGameObjectView.types.standard)
    selectedObjectImageView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)

    --selectedObjectImageView.baseOffset = vec3(0,-4, 0)

    selectedTitleTextView = TextView.new(rightPaneView)
    selectedTitleTextView.font = Font(uiCommon.fontName, 24)
    selectedTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectedTitleTextView.relativeView = selectedObjectImageView
   -- selectedTitleTextView.baseOffset = vec3(0,0, 0)
    selectedTitleTextView.color = mj.textColor

    selectedSummaryTextView = TextView.new(rightPaneView)
    selectedSummaryTextView.font = Font(uiCommon.fontName, 16)
    selectedSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectedSummaryTextView.relativeView = selectedTitleTextView
    selectedSummaryTextView.baseOffset = vec3(0,-5, 0)
    selectedSummaryTextView.wrapWidth = rightPaneView.size.x - 40
    selectedSummaryTextView.color = mj.textColor

    requiredResourcesView = View.new(rightPaneView)
    --requiredResourcesView.color = vec4(0.1,0.1,0.1,0.1)
    requiredResourcesView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    requiredResourcesView.baseOffset = vec3(0,80, 0)
    requiredResourcesView.size = vec2(paneViewSize.x, 200.0)

    requiredResourcesTitleTextView = TextView.new(requiredResourcesView)
    requiredResourcesTitleTextView.font = Font(uiCommon.fontName, 16)
    requiredResourcesTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    requiredResourcesTitleTextView.baseOffset = vec3(-requiredResourcesView.size.x * 0.25 - 5,-10, 0)
    requiredResourcesTitleTextView.text = locale:get("construct_ui_requires") .. ":"
    requiredResourcesTitleTextView.color = mj.textColor
    
    local requiredResourcesKeyImage = uiKeyImage:create(requiredResourcesView, 20, nil, nil, eventManager.controllerSetIndexMenu, "menuOther", nil)
    requiredResourcesKeyImage.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    requiredResourcesKeyImage.relativeView = requiredResourcesTitleTextView
    requiredResourcesKeyImage.baseOffset = vec3(4,0,0)

    useOnlyTitleTextView = TextView.new(requiredResourcesView)
    useOnlyTitleTextView.font = Font(uiCommon.fontName, 16)
    useOnlyTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    useOnlyTitleTextView.baseOffset = vec3(requiredResourcesView.size.x * 0.25 + 5,-10, 0)
    useOnlyTitleTextView.text = locale:get("construct_ui_acceptOnly") .. ":"
    useOnlyTitleTextView.color = mj.textColor

    
    local requiredResourcesInsetViewSize = vec2(requiredResourcesView.size.x * 0.5 - 10, requiredResourcesView.size.y - requiredResourcesTitleTextView.size.y - 20)
    local requiredResourcesScrollViewSize = vec2(requiredResourcesInsetViewSize.x - 10, requiredResourcesInsetViewSize.y - 10)
    local requiredResourcesInsetView = ModelView.new(requiredResourcesView)
    requiredResourcesInsetView:setModel(model:modelIndexForName("ui_inset_sm_4x3"))
    local restrictScaleToUsePaneX = requiredResourcesInsetViewSize.x * 0.5
    local restrictScaleToUsePaneY = requiredResourcesInsetViewSize.y * 0.5 / 0.75
    requiredResourcesInsetView.scale3D = vec3(restrictScaleToUsePaneX,restrictScaleToUsePaneY,restrictScaleToUsePaneX)
    requiredResourcesInsetView.size = requiredResourcesInsetViewSize
    requiredResourcesInsetView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    requiredResourcesInsetView.baseOffset = vec3(0, 0, 0)

    requiredResourcesScrollView = uiScrollView:create(requiredResourcesInsetView, requiredResourcesScrollViewSize, MJPositionInnerLeft)
    requiredResourcesScrollView.baseOffset = vec3(0, 0, 2)
    
    uiSelectionLayout:createForView(requiredResourcesScrollView)

    
    local useOnlyInsetView = ModelView.new(requiredResourcesView)
    useOnlyInsetView:setModel(model:modelIndexForName("ui_inset_sm_4x3"))
    useOnlyInsetView.scale3D = vec3(restrictScaleToUsePaneX,restrictScaleToUsePaneY,restrictScaleToUsePaneX)
    useOnlyInsetView.size = requiredResourcesInsetViewSize
    useOnlyInsetView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    useOnlyInsetView.baseOffset = vec3(0, 0, 0)

    useOnlyScrollView = uiScrollView:create(useOnlyInsetView, requiredResourcesScrollViewSize, MJPositionInnerLeft)
    useOnlyScrollView.baseOffset = vec3(0, 0, 2)

    uiSelectionLayout:createForView(useOnlyScrollView)
    uiSelectionLayout:setSelectionLayoutViewActiveChangedFunction(useOnlyScrollView, function(isSelected)
        setUseOnlyHasFocus(isSelected)
    end)


    confirmButton = uiStandardButton:create(rightPaneView, vec2(142,30))
    confirmButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    confirmButton.baseOffset = vec3(0,30, 0)
    uiStandardButton:setClickFunction(confirmButton, function()
        if confirmFunction then
            confirmFunction()
        end
    end)

    local gridBackgroundViewSize = vec2(leftPaneView.size.x - 40, leftPaneView.size.y - 60)
    objectGridView = uiObjectGrid:create(leftPaneView, gridBackgroundViewSize, function(selectedButtonInfo)
        selectButton(selectedButtonInfo)
    end)
    objectGridView.baseOffset = vec3(10,30, 0)
    uiObjectGrid:setDisableControllerSelection(objectGridView, true) 

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectTerrainUI.terrainFillSelectionContainerView) then
            if mainViewHasFocus and confirmFunction then
                confirmFunction()
                return true
            end
        end
        return false
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuOther", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectTerrainUI.terrainFillSelectionContainerView) then
            setResourcesScrollViewFocus(true)
            uiSelectionLayout:setActiveSelectionLayoutView(requiredResourcesScrollView)
            return true
        end
        return false
    end)
end

function inspectTerrainFillSelectionUI:show()
    update()

    inspectUI:setModalPanelTitleAndObject(locale:get("misc_setFillType"), nil)

    uiObjectGrid:assignLayoutSelection(objectGridView)
    setMainViewHasFocus(true)
end

function inspectTerrainFillSelectionUI:popUI()
    if requiredResourcesScrollViewHasFocus then
        if not constructableUIHelper:popControllerFocus(requiredResourcesScrollView, useOnlyScrollView) then
            setResourcesScrollViewFocus(false)
            uiSelectionLayout:removeActiveSelectionLayoutView(requiredResourcesScrollView)
            uiObjectGrid:assignLayoutSelection(objectGridView)
        end
        return true
    end
    return false
end

return inspectTerrainFillSelectionUI