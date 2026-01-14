local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local plan = mjrequire "common/plan"
local model = mjrequire "common/model"
local constructable = mjrequire "common/constructable"
--local material = mjrequire "common/material"
local tool = mjrequire "common/tool"
local locale = mjrequire "common/locale"

local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiSlider = mjrequire "mainThread/ui/uiCommon/uiSlider"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"

--local buildModeInteractUI = mjrequire "mainThread/ui/buildModeInteractUI"
local constructableUIHelper = mjrequire "mainThread/ui/constructableUIHelper"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiObjectGrid = mjrequire "mainThread/ui/uiCommon/uiObjectGrid"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"

local logicInterface = mjrequire "mainThread/logicInterface"

local inspectCraftPanel = {}

local inspectUI = nil
local inspectObjectUI = nil

local leftPaneView = nil

local world = nil
local objectGridViews = {}

local confirmButton = nil
local confirmFunction = nil
local confirmContinuousButton = nil
--local hasMadeDefaultSelection = false

local rightPaneView = nil
local selectedTitleTextView = nil
local selectedSummaryTextView = nil
local selectedCraftCountDisplayInfos = nil
local quantityTitleTextView = nil
local toolUsageTextViews = {}

local selectedObjectImageView = nil

local sliderCountComplexView = nil
--local countOutputResourceImageView = nil

local sliderView = nil
local quantitySliderKeyImage = nil
local requiredResourcesKeyImage = nil
--local confirmFunction = nil

local requiredResourcesView = nil
local requiredResourcesScrollView = nil
local useOnlyScrollView = nil

local rightPaneViewHasFocus = false
local requiredResourcesScrollViewHasFocus = false

local useOnlyTitleTextView = nil
local requiredResourcesTitleTextView = nil

local useOnlyHasFocus = false
local mainViewHasFocus = false

local craftAreaObjectID = nil

--local currentCraftableTypeIndex = nil
local currentCraftCount = 1
local maxCraftCount = 50

local currentCraftAreaGameObjectTypeIndex = nil
local prevSelectionIndexByCraftAreaObjectTypeIndex = {}

inspectCraftPanel.itemLists = {
    [gameObject.typeIndexMap.craftArea] = {
        constructable.types.rockSmallSoft.index,
        constructable.types.rockSmall.index,
        constructable.types.stoneAxeHeadSoft.index,
        constructable.types.stoneAxeHead.index,
        constructable.types.flintAxeHead.index,
        constructable.types.stoneKnife.index,
        constructable.types.flintKnife.index,
        constructable.types.boneKnife.index,
        constructable.types.stoneChisel.index,
        constructable.types.stoneSpearHead.index,
        constructable.types.flintSpearHead.index,
        constructable.types.boneSpearHead.index,
        constructable.types.stonePickaxeHead.index,
        constructable.types.flintPickaxeHead.index,
        constructable.types.stoneHammerHead.index,
        
        constructable.types.flaxTwine.index,

        constructable.types.stoneSpear.index,
        constructable.types.flintSpear.index,
        constructable.types.boneSpear.index,
        constructable.types.bronzeSpear.index,
        constructable.types.stoneHatchet.index,
        constructable.types.flintHatchet.index,
        constructable.types.bronzeHatchet.index,

        constructable.types.stonePickaxe.index,
        constructable.types.flintPickaxe.index,
        constructable.types.bronzePickaxe.index,
        
        constructable.types.stoneHammer.index,
        constructable.types.bronzeHammer.index,

        constructable.types.splitLog.index,
        constructable.types.butcherChicken.index,
        constructable.types.butcherAlpaca.index,
        constructable.types.fishFillet.index,
        constructable.types.unfiredUrnWet.index,
        constructable.types.unfiredBowlWet.index,
        constructable.types.crucibleWet.index,
        constructable.types.mudBrickWet.index,
        constructable.types.mudTileWet.index,
        constructable.types.stoneTileSoft.index,
        constructable.types.stoneTileHard.index,
        constructable.types.hulledWheat.index,
        constructable.types.quernstone.index,
        constructable.types.flour.index,
        constructable.types.breadDough.index,
        constructable.types.boneFlute.index,
        constructable.types.logDrum.index,
        constructable.types.balafon.index,

        constructable.types.injuryMedicine.index,
        constructable.types.burnMedicine.index,
        constructable.types.foodPoisoningMedicine.index,
        constructable.types.virusMedicine.index,
    },
    [gameObject.typeIndexMap.campfire] = {
        constructable.types.cookedChicken.index,
        constructable.types.cookedAlpaca.index,
        constructable.types.cookedMammoth.index,
        constructable.types.cookedFish.index,
        constructable.types.campfireRoastedBeetroot.index,
        constructable.types.campfireRoastedPumpkin.index,
        constructable.types.flatbread.index,
    },
    [gameObject.typeIndexMap.brickKiln] = {
        constructable.types.firedUrn.index,
        constructable.types.firedBowl.index,
        constructable.types.firedBrick.index,
        constructable.types.firedTile.index,
        constructable.types.bronzeIngot.index,
        constructable.types.bronzeAxeHead.index,
        constructable.types.bronzeKnife.index,
        constructable.types.bronzeSpearHead.index,
        constructable.types.bronzePickaxeHead.index,
        constructable.types.bronzeHammerHead.index,
        constructable.types.bronzeChisel.index,
    },
}

local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectCraftContainerView) then 
            if confirmFunction then
                confirmFunction(false)
            end
        end 
        return true 
    end,

    [keyMapping:getMappingIndex("game", "confirmSpecial")] = function(isDown, isRepeat) 
        if isDown and not isRepeat and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectCraftContainerView) then 
            if confirmFunction then
                confirmFunction(true)
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

local maintainToolTipAdded = false

local function updateConfirmButtonTextAndSliderCountText()
    
    local complexViewUpdateData = nil
    local countToUseOnCraftButton = currentCraftCount
    local countTextOnMaintainButton = nil

    if selectedCraftCountDisplayInfos and #selectedCraftCountDisplayInfos > 1 then
        local countText = mj:tostring(currentCraftCount)
        complexViewUpdateData = {
            {
                text = countText,
            }
        }
        
        table.insert(complexViewUpdateData, {
            text = "("
        })

        countTextOnMaintainButton = ""

        for i,displayinfo in ipairs(selectedCraftCountDisplayInfos) do
            table.insert(complexViewUpdateData, {
                text = mj:tostring(currentCraftCount * displayinfo.count)
            })
            local displayGameObjectTypeIndex = nil
            if displayinfo.objectType then
                displayGameObjectTypeIndex = displayinfo.objectType
            elseif displayinfo.type then
                displayGameObjectTypeIndex = resource.types[displayinfo.type].displayGameObjectTypeIndex
            else
                displayGameObjectTypeIndex = resource.groups[displayinfo.group].displayGameObjectTypeIndex
            end
            table.insert(complexViewUpdateData, {
                gameObject = {objectTypeIndex = displayGameObjectTypeIndex}
            })

            countTextOnMaintainButton = countTextOnMaintainButton .. mj:tostring(currentCraftCount * displayinfo.count)
            if i < #selectedCraftCountDisplayInfos then
                countTextOnMaintainButton = countTextOnMaintainButton .. "/"
            end
        end


        table.insert(complexViewUpdateData, {
            text = ")"
        })
    else
        local countMultiplier = 1
        if selectedCraftCountDisplayInfos and selectedCraftCountDisplayInfos[1] then
            countMultiplier = selectedCraftCountDisplayInfos[1].count
        end
        countToUseOnCraftButton = currentCraftCount * countMultiplier
        local countText = mj:tostring(currentCraftCount * countMultiplier)
        complexViewUpdateData = {
            {
                text = countText,
            }
        }
        countTextOnMaintainButton = mj:tostring(countToUseOnCraftButton)
    end
    
    uiComplexTextView:update(sliderCountComplexView, complexViewUpdateData)


    local controllerButtonToUse = "menuSelect"
    local controllerContinuousButtonToUse = "menuSpecial"
    if not mainViewHasFocus then
        controllerButtonToUse = "menuCancel"
        controllerContinuousButtonToUse = "menuCancel"
    end
    uiStandardButton:setTextWithShortcut(confirmButton, locale:get("ui_action_craftX", {countText = mj:tostring(countToUseOnCraftButton)}), "game", "confirm", eventManager.controllerSetIndexMenu, controllerButtonToUse)
    if currentCraftCount < maxCraftCount then
        uiStandardButton:setTextWithShortcut(confirmContinuousButton, locale:get("ui_action_maintainX", {countText = countTextOnMaintainButton}), "game", "confirmSpecial", eventManager.controllerSetIndexMenu, controllerContinuousButtonToUse)

        if not maintainToolTipAdded then
            uiToolTip:add(confirmContinuousButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_maintainToolTip"), nil, vec3(0,-8,10), nil, confirmContinuousButton, nil)
            maintainToolTipAdded = true
        end
    else
        uiStandardButton:setTextWithShortcut(confirmContinuousButton, locale:get("ui_action_craft_continuous"), "game", "confirmSpecial", eventManager.controllerSetIndexMenu, controllerContinuousButtonToUse)
        if maintainToolTipAdded then
            uiToolTip:remove(confirmContinuousButton.userData.backgroundView)
            maintainToolTipAdded = false
        end
    end


    --sliderCountComplexView.text = countText
end

local function setMainViewHasFocus(newMainViewHasFocus)
    if mainViewHasFocus ~= newMainViewHasFocus then
        mainViewHasFocus = newMainViewHasFocus
        updateConfirmButtonTextAndSliderCountText()
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
    --mj:error("selectButton:", buttonInfo)
    local constructableTypeIndex = buttonInfo.gridButtonData.constructableTypeIndex
    local constructableType = constructable.types[constructableTypeIndex]

    selectedCraftCountDisplayInfos = constructableType.outputDisplayCounts
    --mj:log("constructableType:", constructableType)

    local nameToUse = constructableType.name
    if selectedCraftCountDisplayInfos and #selectedCraftCountDisplayInfos == 1 then
        local simpleCraftCount = selectedCraftCountDisplayInfos[1].count
        if simpleCraftCount > 1 then
            nameToUse = string.format("%s (x%d)", nameToUse, simpleCraftCount)
        end
    end 
    
    
    selectedTitleTextView.text = nameToUse
    selectedSummaryTextView.text = constructableType.summary or locale:get("misc_no_summary_available")

    local gameObjectTypeKeyOrIndex = constructableType.iconGameObjectType
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

    uiStandardButton:setDisabled(confirmButton, false)
    uiStandardButton:setDisabled(confirmContinuousButton, false)
    confirmFunction = function(wasContinuousButton)

        local craftCountToUse = currentCraftCount
        if wasContinuousButton then
            if currentCraftCount == maxCraftCount then
                craftCountToUse = -1
            end
        end
        
        local planInfo = {
            planTypeIndex = plan.types.craft.index,
            craftAreaObjectID = craftAreaObjectID,
            constructableTypeIndex = constructableTypeIndex,
            craftCount = craftCountToUse,
            restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false),
            restrictedToolObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, true),
            shouldMaintainSetQuantity = wasContinuousButton
        }

        logicInterface:callServerFunction("addPlans", planInfo)

        inspectUI:hideUIPanel(true)
    end
    uiStandardButton:setClickFunction(confirmButton, function()
        confirmFunction(false)
    end)
    uiStandardButton:setClickFunction(confirmContinuousButton, function()
        confirmFunction(true)
    end)
    
    local function updateGameObjectView()
        local restrictedObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
        local seenResourceObjectTypes = world:getSeenResourceObjectTypes()
        local objectTypeIndexToUse = constructable:getDisplayGameObjectType(constructableTypeIndex, restrictedObjectTypes, seenResourceObjectTypes)
        uiGameObjectView:setObject(selectedObjectImageView, {objectTypeIndex = objectTypeIndexToUse}, restrictedObjectTypes, world:getSeenResourceObjectTypes())
    end

    local function allObjectsForAnyResourceUncheckedChanged(hasAllObjectsForAnyResourceUnchecked)
        uiStandardButton:setDisabled(confirmButton, hasAllObjectsForAnyResourceUnchecked)
        uiStandardButton:setDisabled(confirmContinuousButton, hasAllObjectsForAnyResourceUnchecked)
    end

    local restrictedObjectsChangedFunction = function()
        updateGameObjectView()
    end
    
    constructableUIHelper:updateRequiredResources(requiredResourcesScrollView, useOnlyScrollView, constructableType, allObjectsForAnyResourceUncheckedChanged, restrictedObjectsChangedFunction)
    updateGameObjectView()

    prevSelectionIndexByCraftAreaObjectTypeIndex[currentCraftAreaGameObjectTypeIndex] = uiObjectGrid:getSelectedButtonGridIndex(objectGridViews[currentCraftAreaGameObjectTypeIndex])
    --mj:log("set prevSelectionIndexByCraftAreaObjectTypeIndex[currentCraftAreaGameObjectTypeIndex]:", prevSelectionIndexByCraftAreaObjectTypeIndex[currentCraftAreaGameObjectTypeIndex], " currentCraftAreaGameObjectTypeIndex:", currentCraftAreaGameObjectTypeIndex)

    --hasMadeDefaultSelection = true

    updateConfirmButtonTextAndSliderCountText()

end

local function updateButtons()

    local gridData = {}

    for i, constructableTypeIndex in ipairs(inspectCraftPanel.itemLists[currentCraftAreaGameObjectTypeIndex]) do

        local constructableType = constructable.types[constructableTypeIndex]

        local gameObjectTypeKeyOrIndex = constructableType.iconGameObjectType
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

    --mj:log("prevSelectionIndexByCraftAreaObjectTypeIndex[currentCraftAreaGameObjectTypeIndex]:", prevSelectionIndexByCraftAreaObjectTypeIndex[currentCraftAreaGameObjectTypeIndex])
    uiObjectGrid:updateButtons(objectGridViews[currentCraftAreaGameObjectTypeIndex], gridData, prevSelectionIndexByCraftAreaObjectTypeIndex[currentCraftAreaGameObjectTypeIndex])

    local selectedInfo = uiObjectGrid:getSelectedInfo(objectGridViews[currentCraftAreaGameObjectTypeIndex])
    if selectedInfo then
        rightPaneView.hidden = false
    else
        rightPaneView.hidden = true
    end
end

local function setRightPanelHasFocus(newHasFcous)
    rightPaneViewHasFocus = newHasFcous
    quantitySliderKeyImage.hidden = newHasFcous
    requiredResourcesKeyImage.hidden = not newHasFcous
    setResourcesScrollViewFocus(not newHasFcous)
    if newHasFcous then
        uiSelectionLayout:setActiveSelectionLayoutView(rightPaneView)
        quantityTitleTextView.color = mj.highlightColor
    else
        uiSelectionLayout:setActiveSelectionLayoutView(requiredResourcesScrollView)
        quantityTitleTextView.color = mj.textColor
    end
end

function inspectCraftPanel:load(inspectUI_, inspectObjectUI_, world_, parentContainerView)

    inspectUI = inspectUI_
    inspectObjectUI = inspectObjectUI_
    world = world_

    local belowTopPadding = 40
    local containerView = View.new(parentContainerView)
    containerView.size = vec2(parentContainerView.size.x, parentContainerView.size.y - belowTopPadding)
    --mj:log("inspectCraftPanel:load parentContainerView.size.y:", parentContainerView.size.y, " titleTextView.size.y:", titleTextView.size.y, "titleTextView.baseOffset.y:", titleTextView.baseOffset.y )
    containerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)


    local paneViewSize = vec2(containerView.size.x * 0.5 - 20, containerView.size.y)

    leftPaneView = View.new(containerView)
    leftPaneView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    leftPaneView.baseOffset = vec3(20,0, 0)
    leftPaneView.size = paneViewSize
    
    leftPaneView.keyChanged = keyChanged --hmmm leftPaneView?
    
    rightPaneView = View.new(containerView)
    rightPaneView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightPaneView.baseOffset = vec3(-30,0, 0)
    rightPaneView.size = paneViewSize

    
    uiSelectionLayout:createForView(rightPaneView)

    local iconSize = 200

    
    local insetViewSize = vec2(rightPaneView.size.x, 220)

    local insetView = ModelView.new(rightPaneView)
    insetView:setModel(model:modelIndexForName("ui_inset_lg_4x3"))
    local scaleToUsePaneX = insetViewSize.x * 0.5
    local scaleToUsePaneY = insetViewSize.y * 0.5 / 0.75
    insetView.scale3D = vec3(scaleToUsePaneX,scaleToUsePaneY,scaleToUsePaneX)
    insetView.size = insetViewSize
    insetView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    insetView.baseOffset = vec3(0,-34, 0)

    selectedObjectImageView = uiGameObjectView:create(insetView, vec2(iconSize,iconSize), uiGameObjectView.types.standard)
    selectedObjectImageView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    selectedObjectImageView.baseOffset = vec3(0,-10, 0)

    selectedTitleTextView = TextView.new(insetView)
    selectedTitleTextView.font = Font(uiCommon.fontName, 24)
    selectedTitleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    selectedTitleTextView.relativeView = selectedObjectImageView
    selectedTitleTextView.baseOffset = vec3(0,-20, 0)
    selectedTitleTextView.color = mj.textColor

    selectedSummaryTextView = TextView.new(insetView)
    selectedSummaryTextView.font = Font(uiCommon.fontName, 16)
    selectedSummaryTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    selectedSummaryTextView.relativeView = selectedTitleTextView
    selectedSummaryTextView.baseOffset = vec3(0,-5, 0)
    selectedSummaryTextView.wrapWidth = insetView.size.x - iconSize - 10
    selectedSummaryTextView.color = mj.textColor

    
    local relativeView = selectedSummaryTextView
    for i = 1,4 do
        local toolUsageTextView = TextView.new(insetView)
        toolUsageTextView.font = Font(uiCommon.fontName, 16)
        toolUsageTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
        toolUsageTextView.relativeView = relativeView
        if i == 1 then
            toolUsageTextView.baseOffset = vec3(0,-10, 0)
        end
        toolUsageTextView.wrapWidth = insetView.size.x - iconSize - 10
        toolUsageTextView.color = mj.textColor
        toolUsageTextViews[i] = toolUsageTextView
        relativeView = toolUsageTextView
    end

    requiredResourcesView = View.new(rightPaneView)
    --requiredResourcesView.color = vec4(0.1,0.1,0.1,0.1)
    requiredResourcesView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    requiredResourcesView.baseOffset = vec3(0,150, 0)
    requiredResourcesView.size = vec2(paneViewSize.x, 200.0)

    requiredResourcesTitleTextView = TextView.new(requiredResourcesView)
    requiredResourcesTitleTextView.font = Font(uiCommon.fontName, 16)
    requiredResourcesTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    requiredResourcesTitleTextView.baseOffset = vec3(-requiredResourcesView.size.x * 0.25 - 5,-10, 0)
    requiredResourcesTitleTextView.text = locale:get("construct_ui_requires") .. ":"
    requiredResourcesTitleTextView.color = mj.textColor
    
    requiredResourcesKeyImage = uiKeyImage:create(requiredResourcesView, 20, nil, nil, eventManager.controllerSetIndexMenu, "menuOther", nil)
    requiredResourcesKeyImage.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    requiredResourcesKeyImage.relativeView = requiredResourcesTitleTextView
    requiredResourcesKeyImage.baseOffset = vec3(4,0,0)
    requiredResourcesKeyImage.hidden = true

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

    local buttonSize = vec2(250,40)
    
    confirmContinuousButton = uiStandardButton:create(rightPaneView, buttonSize)
    confirmContinuousButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    confirmContinuousButton.baseOffset = vec3(-buttonSize.x * 0.5 - 10,30, 0)
    
    --uiStandardButton:setTextWithShortcut(confirmContinuousButton, locale:get("ui_action_craft_continuous"), "game", "confirmSpecial", eventManager.controllerSetIndexMenu, "menuSpecial")


    confirmButton = uiStandardButton:create(rightPaneView, buttonSize)
    confirmButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    confirmButton.baseOffset = vec3(buttonSize.x * 0.5 + 10,30, 0)
    
    
    quantityTitleTextView = TextView.new(rightPaneView)
    quantityTitleTextView.font = Font(uiCommon.fontName, 16)
    quantityTitleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    quantityTitleTextView.relativeView = requiredResourcesInsetView
    quantityTitleTextView.baseOffset = vec3(100, -30, 0)
    quantityTitleTextView.text = locale:get("ui_name_craftCount") .. ":"

    quantitySliderKeyImage = uiKeyImage:create(quantityTitleTextView, 20, nil, nil, eventManager.controllerSetIndexMenu, "menuOther", nil)
    quantitySliderKeyImage.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    quantitySliderKeyImage.relativeView = quantityTitleTextView
    quantitySliderKeyImage.baseOffset = vec3(-4,0,0)

    local initialData = {
        text = "1",
    }
    
    sliderCountComplexView = uiComplexTextView:create(rightPaneView, initialData)
    
    --sliderCountView.font = Font(uiCommon.fontName, 16)
    sliderCountComplexView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    sliderCountComplexView.baseOffset = vec3(10,0, 0)
    --sliderCountView.text = "1"

    --[[countOutputResourceImageView = uiGameObjectView:create(rightPaneView, vec2(16,16), uiGameObjectView.types.standard)
    countOutputResourceImageView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    countOutputResourceImageView.relativeView = sliderCountView]]
    --countOutputResourceImageView.baseOffset = vec3(0,-10, 0)

    local options = {
        continuous = true,
        controllerIncrement = 1
    }

    sliderView = uiSlider:create(rightPaneView, vec2(200, 20), 1, maxCraftCount, 1, options, function(value)
        currentCraftCount = value
        updateConfirmButtonTextAndSliderCountText()
    end)
    sliderView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    sliderView.baseOffset = vec3(10, 0, 0)
    sliderView.relativeView = quantityTitleTextView

    uiSelectionLayout:addView(rightPaneView, sliderView)
    
    sliderCountComplexView.relativeView = sliderView

    local gridBackgroundViewSize = vec2(leftPaneView.size.x - 40, leftPaneView.size.y - 60)

    for craftAreaGameObjectTypeIndex, itemList in pairs(inspectCraftPanel.itemLists) do
        local objectGridView = uiObjectGrid:create(leftPaneView, gridBackgroundViewSize, function(selectedButtonInfo)
            selectButton(selectedButtonInfo)
        end)
        objectGridViews[craftAreaGameObjectTypeIndex] = objectGridView
        objectGridView.baseOffset = vec3(10,30, 0)
        objectGridView.hidden = true
        uiObjectGrid:setDisableControllerSelection(objectGridView, true) --this allows the "menuSelect" callback to be called below, otherwise it will just act like the player is clicking on the object grid, and the below function will not get called
    end
    
    

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectCraftContainerView) then
            if mainViewHasFocus and confirmFunction then
                confirmFunction(false)
                return true
            end
        end
        return false
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSpecial", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectCraftContainerView) then
            if mainViewHasFocus and confirmFunction then
                confirmFunction(true)
                return true
            end
        end
        return false
    end)

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuOther", function(isDown)
        if isDown and not inspectUI:containerViewIsHidden(inspectObjectUI.inspectCraftContainerView) then
            if rightPaneViewHasFocus then
                setRightPanelHasFocus(false)
            else
                setRightPanelHasFocus(true)
            end
            return true
        end
        return false
    end)

end


function inspectCraftPanel:show(craftAreaObject)

    craftAreaObjectID = craftAreaObject.uniqueID

    if currentCraftAreaGameObjectTypeIndex ~= craftAreaObject.objectTypeIndex then
        if currentCraftAreaGameObjectTypeIndex then
            objectGridViews[currentCraftAreaGameObjectTypeIndex].hidden = true
        end
        currentCraftAreaGameObjectTypeIndex = craftAreaObject.objectTypeIndex
        objectGridViews[currentCraftAreaGameObjectTypeIndex].hidden = false
    end

    currentCraftCount = 1 
    uiSlider:setValue(sliderView, 1)
    updateConfirmButtonTextAndSliderCountText()


    updateButtons()
    
    inspectUI:setModalPanelTitleAndObject(gameObject:getDisplayName(craftAreaObject), craftAreaObject)
    
    uiObjectGrid:assignLayoutSelection(objectGridViews[currentCraftAreaGameObjectTypeIndex])
    setMainViewHasFocus(true)
    rightPaneViewHasFocus = false
    quantitySliderKeyImage.hidden = false
    requiredResourcesKeyImage.hidden = true
end

function inspectCraftPanel:popUI()
    if requiredResourcesScrollViewHasFocus then
        if not constructableUIHelper:popControllerFocus(requiredResourcesScrollView, useOnlyScrollView) then
            setRightPanelHasFocus(true)
        end
        return true
    elseif rightPaneViewHasFocus then
        rightPaneViewHasFocus = false
        quantitySliderKeyImage.hidden = false
        requiredResourcesKeyImage.hidden = true
        quantityTitleTextView.color = mj.textColor
        uiSelectionLayout:removeActiveSelectionLayoutView(requiredResourcesScrollView)
        if currentCraftAreaGameObjectTypeIndex then
            uiObjectGrid:assignLayoutSelection(objectGridViews[currentCraftAreaGameObjectTypeIndex])
        end
        return true
    end
    
    if currentCraftAreaGameObjectTypeIndex then
        uiObjectGrid:removeLayoutSelection(objectGridViews[currentCraftAreaGameObjectTypeIndex])
    end

    uiSelectionLayout:removeActiveSelectionLayoutView(requiredResourcesScrollView)
    setResourcesScrollViewFocus(false)

    return false
end


return inspectCraftPanel