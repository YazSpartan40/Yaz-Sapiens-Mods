local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"
local model = mjrequire "common/model"
local constructable = mjrequire "common/constructable"
--local material = mjrequire "common/material"
local tool = mjrequire "common/tool"
local locale = mjrequire "common/locale"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local eventManager = mjrequire "mainThread/eventManager"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local keyMapping = mjrequire "mainThread/keyMapping"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local constructableUIHelper = mjrequire "mainThread/ui/constructableUIHelper"
--local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiObjectGrid = mjrequire "mainThread/ui/uiCommon/uiObjectGrid"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"

local logicInterface = mjrequire "mainThread/logicInterface"
local prevSelectionIndexByObjectTypeIndex = {}

local inspectRebuildPanel = {}

local inspectUI = nil

local leftPaneView = nil

local world = nil
local objectGridView = nil

local confirmButton = nil
local confirmFunction = nil
--local hasMadeDefaultSelection = false

local rightPaneView = nil
local selectedTitleTextView = nil
local selectedSummaryTextView = nil
local toolUsageTextViews = {}

local requiredResourcesView = nil
local requiredResourcesScrollView = nil
local useOnlyScrollView = nil
local requiredResourcesScrollViewHasFocus = false


local useOnlyTitleTextView = nil
local requiredResourcesTitleTextView = nil

local useOnlyHasFocus = false
local mainViewHasFocus = false

local selectedObjectImageView = nil

local currentItemList = nil
local currentObjectInfo = nil
local currentConstructableTypeIndex = nil


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

local function updateConfirmButton()
    if currentConstructableTypeIndex then
        if mainViewHasFocus then
            uiStandardButton:setTextWithShortcut(confirmButton, locale:get("plan_rebuild"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
        else
            uiStandardButton:setTextWithShortcut(confirmButton, locale:get("plan_rebuild"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuCancel")
        end
    end
end

local function setMainViewHasFocus(newMainViewHasFocus)
    if mainViewHasFocus ~= newMainViewHasFocus then
        mainViewHasFocus = newMainViewHasFocus
        updateConfirmButton()
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
        currentConstructableTypeIndex = buttonInfo.gridButtonData.constructableTypeIndex
        local constructableType = constructable.types[currentConstructableTypeIndex]
        
        
        --uiStandardButton:setTextWithShortcut(confirmButton, classificationType.actionName, "game", "confirm", eventManager.controllerSetIndexMenu, "menuSpecial")
        updateConfirmButton()
        selectedTitleTextView.text = constructableType.name
        selectedSummaryTextView.text = constructableType.summary or locale:get("misc_no_summary_available")

        local gameObjectTypeKeyOrIndex = constructableType.iconGameObjectType
        if not gameObjectTypeKeyOrIndex then
            gameObjectTypeKeyOrIndex = constructableType.inProgressGameObjectTypeKey
        end
        local gameObjectType = gameObject.types[gameObjectTypeKeyOrIndex]

        
        local toolUsages = gameObjectType.toolUsages

        local prevToolTypeIndex = nil
        for i = 1,4 do
            local toolUsageTextView = toolUsageTextViews[i]
            local toolUsageInfo = nil
            local toolTypeIndex = nil
            if toolUsages then
                toolTypeIndex,toolUsageInfo = next(toolUsages, prevToolTypeIndex)
                if toolTypeIndex then
                    prevToolTypeIndex = toolTypeIndex
                end
            end
            if toolUsageInfo and next(toolUsageInfo) then
                toolUsageTextView.hidden = false
                local textString = tool.types[toolTypeIndex].usage .. " : "
                local hasPrevious = false
                for j,toolPropertyTypeIndex in ipairs(tool.orderedPropertyTypeIndexesForUI) do
                    if toolUsageInfo[toolPropertyTypeIndex] then
                        if hasPrevious then
                            textString = textString .. ", "
                        end
                        hasPrevious = true
                        textString = textString .. tool.propertyTypes[toolPropertyTypeIndex].name .. string.format(":%.1fx", toolUsageInfo[toolPropertyTypeIndex])
                    end
                end
                toolUsageTextView.text = textString
            else
                toolUsageTextView.hidden = true
            end
        end

        confirmFunction = function()
            local restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(currentConstructableTypeIndex, false)

            local allObjectIDs = {}
            for objectID,info in pairs(inspectUI.selectedObjectOrVertInfosByID) do
                table.insert(allObjectIDs, objectID)
            end

            local planInfo = {
                planTypeIndex = plan.types.rebuild.index,
                constructableTypeIndex = currentConstructableTypeIndex,
                restrictedResourceObjectTypes = restrictedResourceObjectTypes,
                restrictedToolObjectTypes = world:getConstructableRestrictedObjectTypes(currentConstructableTypeIndex, true),
                objectOrVertIDs = allObjectIDs,
            }
            
            logicInterface:callServerFunction("addPlans", planInfo)

            inspectUI:hideUIPanel(true)
            inspectUI:hideInspectUI()
        end
        uiStandardButton:setClickFunction(confirmButton, confirmFunction)

        uiStandardButton:setDisabled(confirmButton, false)

        local function updateGameObjectView()
            local restrictedObjectTypes = world:getConstructableRestrictedObjectTypes(currentConstructableTypeIndex, false)
            local seenResourceObjectTypes = world:getSeenResourceObjectTypes()
            local objectTypeIndexToUse = constructable:getDisplayGameObjectType(currentConstructableTypeIndex, restrictedObjectTypes, seenResourceObjectTypes)
            uiGameObjectView:setObject(selectedObjectImageView, {objectTypeIndex = objectTypeIndexToUse}, restrictedObjectTypes, world:getSeenResourceObjectTypes())
        end

        local function allObjectsForAnyResourceUncheckedChanged(hasAllObjectsForAnyResourceUnchecked)
            uiStandardButton:setDisabled(confirmButton, hasAllObjectsForAnyResourceUnchecked)
        end
        
        local restrictedObjectsChangedFunction = function()
            updateGameObjectView()
        end

        constructableUIHelper:updateRequiredResources(requiredResourcesScrollView, useOnlyScrollView, constructableType, allObjectsForAnyResourceUncheckedChanged, restrictedObjectsChangedFunction)
        updateGameObjectView()

        prevSelectionIndexByObjectTypeIndex[currentObjectInfo.objectTypeIndex] = uiObjectGrid:getSelectedButtonGridIndex(objectGridView)
    end

end

local function updateButtons()

    local gridData = {}

    for i, constructableTypeIndex in ipairs(currentItemList) do

        local constructableType = constructable.types[constructableTypeIndex]

        local gameObjectTypeKeyOrIndex = constructableType.iconGameObjectType
        if not gameObjectTypeKeyOrIndex then
            gameObjectTypeKeyOrIndex = constructableType.inProgressGameObjectTypeKey
        end
        local gameObjectType = gameObject.types[gameObjectTypeKeyOrIndex]

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
    end


    uiObjectGrid:updateButtons(objectGridView, gridData, prevSelectionIndexByObjectTypeIndex[currentObjectInfo.objectTypeIndex])

    local selectedInfo = uiObjectGrid:getSelectedInfo(objectGridView)
    if selectedInfo then
        rightPaneView.hidden = false
    else
        rightPaneView.hidden = true
    end
end

function inspectRebuildPanel:load(inspectUI_, inspectObjectUI, world_, parentContainerView)
    inspectUI = inspectUI_
    world = world_

    
    local belowTopPadding = 40
    local contentView = View.new(parentContainerView)
    contentView.size = vec2(parentContainerView.size.x, parentContainerView.size.y - belowTopPadding)
    --mj:log("inspectCraftPanel:load parentContainerView.size.y:", parentContainerView.size.y, " titleTextView.size.y:", titleTextView.size.y, "titleTextView.baseOffset.y:", titleTextView.baseOffset.y )
    contentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)

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

    

    local relativeView = selectedSummaryTextView
    for i = 1,4 do
        local toolUsageTextView = TextView.new(rightPaneView)
        toolUsageTextView.font = Font(uiCommon.fontName, 16)
        toolUsageTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        toolUsageTextView.relativeView = relativeView
        if i == 1 then
            toolUsageTextView.baseOffset = vec3(0,-20, 0)
        end
        toolUsageTextView.wrapWidth = rightPaneView.size.x - 40
        toolUsageTextView.color = mj.textColor
        toolUsageTextViews[i] = toolUsageTextView
        relativeView = toolUsageTextView
    end

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
    
    local gridBackgroundViewSize = vec2(leftPaneView.size.x - 40, leftPaneView.size.y - 60)
    objectGridView = uiObjectGrid:create(leftPaneView, gridBackgroundViewSize, function(selectedButtonInfo)
        selectButton(selectedButtonInfo)
    end)
    objectGridView.baseOffset = vec3(10,30, 0)
    uiObjectGrid:setDisableControllerSelection(objectGridView, true)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectUseContainerView) then
            if mainViewHasFocus and confirmFunction then
                confirmFunction()
                return true
            end
        end
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuOther", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectUseContainerView) then
            --requiredResourcesScrollViewHasFocus = true
            setResourcesScrollViewFocus(true)
            uiSelectionLayout:setActiveSelectionLayoutView(requiredResourcesScrollView)
            return true
        end
    end)
end

local baseObjectConstructableTypeIndex = nil

local orderedConstructableClassifications = {
    constructable.classifications.place.index,
    constructable.classifications.build.index,
    constructable.classifications.plant.index,
    constructable.classifications.path.index,
    constructable.classifications.craft.index,
}

local function reconstructGridView()

    --constructables = constructable.constructablesByResourceObjectTypeIndexes[currentObjectTypeIndex]

    --constructable.typesByRebuildGroup

    currentItemList = {}
    if baseObjectConstructableTypeIndex then
        table.insert(currentItemList, baseObjectConstructableTypeIndex)

        local constructables = nil
        local rebuildGroupIndex = constructable.types[baseObjectConstructableTypeIndex].rebuildGroupIndex
        if rebuildGroupIndex then
            constructables = constructable.typesByRebuildGroup[rebuildGroupIndex]
        end

        if constructables and constructables[1] then
            for i,constructableClassificationTypeIndex in ipairs(orderedConstructableClassifications) do
                for j,constructableTypeIndex in ipairs(constructables) do
                    if constructableTypeIndex ~= baseObjectConstructableTypeIndex then
                        local constructableType = constructable.types[constructableTypeIndex]
                        if constructableType.classification == constructableClassificationTypeIndex and (not constructableType.deprecated)  then
                            table.insert(currentItemList, constructableTypeIndex)
                        end
                    end
                end
            end
        end
    end
end


function inspectRebuildPanel:show(object)
    currentObjectInfo = object
    local constructableTypeIndex = constructable:getConstructableTypeIndexForCloneOrRebuild(currentObjectInfo)
    if baseObjectConstructableTypeIndex ~= constructableTypeIndex then
        --hasMadeDefaultSelection = false
        baseObjectConstructableTypeIndex = constructableTypeIndex
        reconstructGridView()
    end

    updateButtons()
    
    uiObjectGrid:assignLayoutSelection(objectGridView)
    setMainViewHasFocus(true)

    inspectUI:setModalPanelTitleAndObject(locale:get("plan_rebuild_title", { rebuildText = locale:get("plan_rebuild"), objectName = gameObject:getDisplayName(object)}), object)
end

function inspectRebuildPanel:popUI()
    if requiredResourcesScrollViewHasFocus then
        if not constructableUIHelper:popControllerFocus(requiredResourcesScrollView, useOnlyScrollView) then
            setResourcesScrollViewFocus(false)
            uiSelectionLayout:removeActiveSelectionLayoutView(requiredResourcesScrollView)
            uiObjectGrid:assignLayoutSelection(objectGridView)
        end
        return true
    end
        
    uiSelectionLayout:removeActiveSelectionLayoutView(requiredResourcesScrollView)
    setResourcesScrollViewFocus(false)

    return false
end

return inspectRebuildPanel