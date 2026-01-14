local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

--local mjs = mjrequire "common/mjs"

local gameObject = mjrequire "common/gameObject"
local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
--local order = mjrequire "common/order"
local sapienTrait = mjrequire "common/sapienTrait"
local gameConstants = mjrequire "common/gameConstants"
local plan = mjrequire "common/plan"
--local skill = mjrequire "common/skill"
--local desire = mjrequire "common/desire"
--local need = mjrequire "common/need"
local statusEffect = mjrequire "common/statusEffect"
local mood = mjrequire "common/mood"
local sapienConstants = mjrequire "common/sapienConstants"

--local uiAnimation = mjrequire "mainThread/ui/uiAnimation"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
--local logicInterface = mjrequire "mainThread/logicInterface"
--local inspectSapienTasks = mjrequire "mainThread/ui/inspect/inspectSapienTasks"
--local inspectSapienRelationshipsView = mjrequire "mainThread/ui/inspect/inspectSapienRelationshipsView"
local manageSapienCollection = mjrequire "mainThread/ui/inspect/manageSapienCollection"

local uiTextEntry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"
local logicInterface = mjrequire "mainThread/logicInterface"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local orderStatus = mjrequire "mainThread/orderStatus"


--local sapienMoveUI = mjrequire "mainThread/ui/sapienMoveUI"

--local logicInterface = mjrequire "mainThread/logicInterface"
--local playerSapiens = mjrequire "mainThread/playerSapiens"

local inspectFollowerUI = {}

local inspectUI = nil
local hubUI = nil
--local gameUI = nil
local world = nil


local inspectSapienTasksContainerView = nil
--local inspectSapienRelationshipsContainerView = nil

local ageTextView = nil
--local loyaltyTextView = nil
local statusEffectsContainerView = nil
--local happySadTextView = nil

local traitsTextView = nil

local currentOrderTextView = nil

local sapienDetailView = nil
local multiSapienDetailView = nil

local happyIconsView = nil
local loyaltyIconsView = nil

local starIconsByType = {}
local flashingWarningIconByType = {}
local currentStarCounts = {}

--[[local function isSleeping(sapien)
    local sharedState = sapien.sharedState
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderTypeIndex = sharedState.orderQueue[1].orderTypeIndex
        return (orderTypeIndex == order.types.sleep.index)
    end
end]]

local function updateSize()
    inspectUI.contentExtraHeight = 80.0
    inspectUI.contentExtraWidth = math.max(ageTextView.size.x + traitsTextView.size.x + 14.0, 200.0)
    inspectUI.contentExtraWidth = math.max(inspectUI.contentExtraWidth, currentOrderTextView.size.x - inspectUI.nameTextEntry.size.x + 10)
end

local function doSetCurrentStatusText(text)
    currentOrderTextView.text = text
    updateSize()
end

local statusRequestIDCounter = 0

local function statusReceived(callbackID, text)
    if callbackID == statusRequestIDCounter then
        doSetCurrentStatusText(text)
    end
end

local function setCurrentStatusText(sharedState)
    statusRequestIDCounter = statusRequestIDCounter + 1
    orderStatus:getStatusText(sharedState.orderQueue[1], sharedState, statusRequestIDCounter, statusReceived)
end

local currentEffectViews = nil

function inspectFollowerUI:updateObjectInfo()

    local sharedState = inspectUI.baseObjectOrVertInfo.sharedState

    if not uiTextEntry:isEditing(inspectUI.nameTextEntry) then

        local sapienName = sharedState.name
        if not sapienName then
            sapienName = locale:get("misc_missing_name")
        end

        inspectUI:setTitleText(sapienName, true)
    end
    

    ageTextView.text = sapienConstants:getAgeDescription(sharedState) .. "."

    local selectedObject = inspectUI.baseObjectOrVertInfo

    local function updateStarCount(moodTypeIndex, parentView)
        local newCount = mood:getStarCount(selectedObject, moodTypeIndex)
        if newCount ~= currentStarCounts[moodTypeIndex] then

            local moodValue = mood:getMood(selectedObject, moodTypeIndex)

            uiToolTip:updateText(parentView, mood.types[moodTypeIndex].name, mood.types[moodTypeIndex].descriptions[moodValue], false)

            currentStarCounts[moodTypeIndex] = newCount
            local starIcons = starIconsByType[moodTypeIndex]
            if not starIcons then
                starIcons = {}
                starIconsByType[moodTypeIndex] = starIcons
            end

            local function updateModel(starIcon, starIndex)
                local modelName = "icon_star_inset"
                local materialIndex = "ui_background_inset"
                if newCount >= starIndex then
                    modelName = "icon_star"
                    materialIndex = mood.materials[moodValue]
                else
                    materialIndex = mood.uiBackgroundMaterials[moodValue]
                end
                starIcon:setModel(model:modelIndexForName(modelName), {
                    default = materialIndex
                })
            end

            local iconHalfSize = 8.0

            for i = 1,5 do
                if starIcons[i] then
                    updateModel(starIcons[i], i)
                else
                
                    local starIcon = ModelView.new(parentView)
                    starIcons[i] = starIcon
                    starIcon.masksEvents = false
                    starIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
                    starIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
                    starIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
                    starIcon.baseOffset = vec3(22.0 + (i - 1) * 20.0, 0.0,0.0)
                    updateModel(starIcon, i)
                end
            end

            if newCount == 0 then
                local warningHalfSize = 8.0
                local flashingWarningIconView = ModelView.new(parentView)
                flashingWarningIconByType[moodTypeIndex] = flashingWarningIconView
                flashingWarningIconView.relativeView = starIcons[5]
                flashingWarningIconView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
                flashingWarningIconView.baseOffset = vec3(20.0, 0.0,0.2)
                flashingWarningIconView.scale3D = vec3(warningHalfSize,warningHalfSize,warningHalfSize)
                flashingWarningIconView.size = vec2(warningHalfSize, warningHalfSize) * 2.0
                flashingWarningIconView:setModel(model:modelIndexForName("icon_warning"), {
                    default = mood.materials[moodValue]
                })

                local alphaTimer = 0.0
                flashingWarningIconView.update = function(dt)
                    alphaTimer = alphaTimer + dt
                    local animationValue = math.sin(alphaTimer * math.pi * 2.0) * 0.5 + 0.5
                    local alpha = animationValue * 0.5 + 0.75
                    flashingWarningIconView.alpha = alpha
                    local warningHalfSizeToUse = warningHalfSize + animationValue * 2.0
                    flashingWarningIconView.scale3D = vec3(warningHalfSizeToUse,warningHalfSizeToUse,warningHalfSizeToUse)
                end
            elseif flashingWarningIconByType[moodTypeIndex] then
                parentView:removeSubview(flashingWarningIconByType[moodTypeIndex])
                flashingWarningIconByType[moodTypeIndex] = nil
            end
        end
    end

    updateStarCount(mood.types.happySad.index, happyIconsView)
    updateStarCount(mood.types.loyalty.index, loyaltyIconsView)


    local incomingStatusEffects = selectedObject.sharedState.statusEffects

    local statusNeedsUpdated = false

    if currentEffectViews then
        for statusEffectTypeIndex,v in pairs(incomingStatusEffects) do
            if not currentEffectViews[statusEffectTypeIndex] then
                local statusEffectType = statusEffect.types[statusEffectTypeIndex]
                if statusEffectType.impact ~= 0 then
                    statusNeedsUpdated = true
                    break
                end
            end
        end
        
        for statusEffectTypeIndex,v in pairs(currentEffectViews) do
            if not incomingStatusEffects[statusEffectTypeIndex] then
                statusNeedsUpdated = true
                break
            end
        end

        if statusNeedsUpdated then
            for statusEffectTypeIndex, view in pairs(currentEffectViews) do
                statusEffectsContainerView:removeSubview(view)
            end
            currentEffectViews = nil
        end
    elseif incomingStatusEffects then
        for statusEffectTypeIndex,v in pairs(incomingStatusEffects) do
            local statusEffectType = statusEffect.types[statusEffectTypeIndex]
            if statusEffectType.impact ~= 0 then
                statusNeedsUpdated = true
                break
            end
        end
    end

    if statusNeedsUpdated then
        currentEffectViews = {}
        local bigEffectCount = 0
        local smallEffectPositiveCount = 0
        local smallEffectNegativeCount = 0
        --local hasBigNegative = false
        --local hasBigPositive = false

        local function addIcon(statusEffectType)

            local isBig = (statusEffectType.impact < -1 or statusEffectType.impact > 1)
            local isNegative = statusEffectType.impact < 0

            local xOffset = 44.0 * bigEffectCount
            local yOffset = 0.0

            local iconBackgroundHalfSize = 8.0
            if isBig then
                iconBackgroundHalfSize = 20.0
            else
                if isNegative then
                    xOffset = xOffset + smallEffectNegativeCount * 22.0
                    if smallEffectPositiveCount > 0 or bigEffectCount > 0 then
                        yOffset = -22.0
                    else
                        yOffset = -2.0
                    end
                else
                    xOffset = xOffset + smallEffectPositiveCount * 22.0
                    yOffset = - 2.0
                end
            end

            local materialIndex = material.types.mood_severePositive.index
            if isNegative then
                if statusEffectType.impact < -5 then
                    materialIndex = material.types.mood_severeNegative.index
                else
                    materialIndex = material.types.mood_moderateNegative.index
                end
            end

            local iconBackgroundView = View.new(statusEffectsContainerView)
            iconBackgroundView.size = vec2(iconBackgroundHalfSize,iconBackgroundHalfSize) * 2.0
            iconBackgroundView.baseOffset = vec3(xOffset, yOffset, 0.001)
            iconBackgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

            local iconCircle = ModelView.new(iconBackgroundView)
            iconCircle.scale3D = vec3(iconBackgroundHalfSize,iconBackgroundHalfSize,iconBackgroundHalfSize)
            iconCircle.size = vec2(iconBackgroundHalfSize,iconBackgroundHalfSize) * 2.0
            uiToolTip:add(iconCircle, ViewPosition(MJPositionCenter, MJPositionAbove), statusEffectType.name, statusEffectType.description, vec3(0,8,2), nil, nil)

            iconCircle:setModel(model:modelIndexForName("icon_circle"), {
                default = materialIndex
            })

            local iconHalfSize = iconBackgroundHalfSize * 0.7
            local icon = ModelView.new(iconBackgroundView)
            icon.masksEvents = false
            icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            icon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
            icon.size = vec2(iconHalfSize,iconHalfSize) * 2.0

            icon:setModel(model:modelIndexForName(statusEffectType.icon), {
                default = materialIndex
            })

            if isBig then
                bigEffectCount = bigEffectCount + 1
                --[[if isNegative then
                    hasBigNegative = true
                else
                    hasBigPositive = true
                end]]
            else
                if isNegative then
                    smallEffectNegativeCount = smallEffectNegativeCount + 1
                else 
                    smallEffectPositiveCount = smallEffectPositiveCount + 1
                end
            end

            currentEffectViews[statusEffectType.index] = iconBackgroundView
        end

        for i,statusEffectTypeIndex in ipairs(statusEffect.orderedNegativeEffects) do -- critical negatives
            local statusEffectType = statusEffect.types[statusEffectTypeIndex]
            if statusEffectType.impact < -5 then
                if incomingStatusEffects[statusEffectTypeIndex] then
                    addIcon(statusEffectType)
                end
            end
        end

        for i,statusEffectTypeIndex in ipairs(statusEffect.orderedNegativeEffects) do -- big negatives
            local statusEffectType = statusEffect.types[statusEffectTypeIndex]
            if statusEffectType.impact >= -5 and statusEffectType.impact < -1 then
                if incomingStatusEffects[statusEffectTypeIndex] then
                    addIcon(statusEffectType)
                end
            end
        end

        for i,statusEffectTypeIndex in ipairs(statusEffect.orderedPositiveEffects) do --all positives (big first)
            if incomingStatusEffects[statusEffectTypeIndex] then
                local statusEffectType = statusEffect.types[statusEffectTypeIndex]
                addIcon(statusEffectType)
            end
        end
        for i,statusEffectTypeIndex in ipairs(statusEffect.orderedNegativeEffects) do -- non-big negatives
            if incomingStatusEffects[statusEffectTypeIndex] then
                local statusEffectType = statusEffect.types[statusEffectTypeIndex]
                if statusEffectType.impact == -1 then
                    addIcon(statusEffectType)
                end
            end
        end

        if bigEffectCount == 0 and (smallEffectPositiveCount == 0 or smallEffectNegativeCount == 0) then
            statusEffectsContainerView.size = vec2(statusEffectsContainerView.size.x, 20.0)
        else
            statusEffectsContainerView.size = vec2(statusEffectsContainerView.size.x, 40.0)
        end
    end

    
    --[[local happySadMood = mood:getMood(selectedObject, mood.types.happySad.index)
    happySadTextView.text = locale:get("mood_happySad_name") .. ": "
    happySadTextView:addColoredText(mood.types.happySad.descriptions[happySadMood], mood.colors[happySadMood])

    local loyaltyMood = mood:getMood(selectedObject, mood.types.loyalty.index)
    loyaltyTextView.text = locale:get("mood_loyalty_name") .. ": "
    loyaltyTextView:addColoredText(mood.types.loyalty.descriptions[loyaltyMood], mood.colors[loyaltyMood])]]


    local traitsText = ""

    if sharedState.pregnant then
        traitsText = locale:get("misc_pregnant") .. ". "
    elseif sharedState.hasBaby then
        traitsText = locale:get("misc_carryingBaby") .. ". "
    end

    for i,traitInfo in ipairs(sharedState.traits) do
        local sapienTraitType = sapienTrait.types[traitInfo.traitTypeIndex]
        if i ~= 1 then
            traitsText = traitsText .. ", "
        end
        
        local traitName = sapienTraitType.name
        if traitInfo.opposite then
            traitName = sapienTraitType.opposite
        end

        traitsText = traitsText .. traitName
    end
    traitsText = traitsText .. "."
    traitsTextView.text = traitsText

    --[[if sharedState.prioritySkill then
        focusTextView.text = locale:get("ui_name_skillFocus") .. ": " .. skill:titleForSkill(sharedState.prioritySkill)
    else
        focusTextView.text = locale:get("ui_name_skillFocus") .. ": " .. locale:get("misc_none_assigned")
    end]]


    --- THIS BELOW IS THE OLD CODE THAT DISPLAYED THE TEXT AND ICON IN ACTIONUI
    --[[
local hasQueuedOrderCancelOverrideText = nil
    local queuedOrderTypeOverrideIconName = nil
    local hasWaitOrderSet = false
    local hasNonQueuedWaitOrder = false
    for i, objectInfo in ipairs(objectInfos) do
        local sharedState = objectInfo.sharedState
        if sharedState.orderQueue and sharedState.orderQueue[1] then
            if hasQueuedOrderCancelOverrideText then
                hasQueuedOrderCancelOverrideText = "Orders"
            else
                local orderState = sharedState.orderQueue[1]
                local orderTypeIndex = orderState.orderTypeIndex
                queuedOrderTypeOverrideIconName = order.types[orderTypeIndex].icon
                
                local orderinProgressText = order.types[orderTypeIndex].inProgressName
                local orderContext = orderState.context
                if orderContext then
                    if orderState.context.researchTypeIndex then
                        queuedOrderTypeOverrideIconName = "icon_idea"
                        orderinProgressText = locale:get("plan_research_inProgress")
                    else
                        if orderContext.objectTypeIndex then
                            orderinProgressText = orderinProgressText .. " " .. gameObject.types[orderContext.objectTypeIndex].name
                        end
                    end
                end

                hasQueuedOrderCancelOverrideText = orderinProgressText
            end
        end

        if objectInfo.sharedState.waitOrderSet then
            hasWaitOrderSet = true
        else
            hasNonQueuedWaitOrder = true
        end
    end
    ]]

    setCurrentStatusText(sharedState)

    updateSize()
    
    
    --[[if not planInfoView.hidden then
        inspectUI.contentExtraHeight = inspectUI.contentExtraHeight + planInfoView.size.y
        maxWidth = math.max(maxWidth, planInfoView.size.x)
    end]]
end

function inspectFollowerUI:showTasksForCurrentSapien(backFunction)
    manageSapienCollection:setBackFunction(backFunction)
    manageSapienCollection:show(inspectUI.baseObjectOrVertInfo)
    inspectUI:showModalPanelView(inspectSapienTasksContainerView, manageSapienCollection)
end

function inspectFollowerUI:load(gameUI_, inspectUI_, manageUI, hubUI_, world_, infoView)

    inspectUI = inspectUI_
    --gameUI = gameUI_
    hubUI = hubUI_
    world = world_

    orderStatus:load(world_)

    
    inspectSapienTasksContainerView = View.new(inspectUI.modalPanelView)
    inspectSapienTasksContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    inspectSapienTasksContainerView.size = inspectUI.modalPanelView.size
    inspectSapienTasksContainerView.hidden = true

    manageSapienCollection:init(inspectUI, inspectFollowerUI, world, inspectSapienTasksContainerView)

    --[[inspectSapienRelationshipsContainerView = View.new(inspectUI.modalPanelView)
    inspectSapienRelationshipsContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    inspectSapienRelationshipsContainerView.size = inspectUI.modalPanelView.size
    inspectSapienRelationshipsContainerView.hidden = true

    inspectSapienRelationshipsView:load(inspectUI, inspectFollowerUI, world, inspectSapienRelationshipsContainerView)]]

    local containerView = inspectUI.containerView

    sapienDetailView = View.new(containerView)
    sapienDetailView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    sapienDetailView.hidden = true
    
    multiSapienDetailView = View.new(containerView)
    multiSapienDetailView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    multiSapienDetailView.hidden = true

    ageTextView = TextView.new(sapienDetailView)
    ageTextView.font = Font(uiCommon.fontName, 16)
    ageTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    ageTextView.relativeView = inspectUI.nameTextEntry
    ageTextView.baseOffset = vec3(4,0, 0)
    ageTextView.color = mj.textColor
    
    traitsTextView = TextView.new(sapienDetailView)
    traitsTextView.font = Font(uiCommon.fontName, 16)
    traitsTextView.relativeView = ageTextView
    traitsTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    traitsTextView.baseOffset = vec3(4,0, 0)
    traitsTextView.color = mj.textColor


    
    currentOrderTextView = TextView.new(sapienDetailView)
    currentOrderTextView.relativeView = inspectUI.nameTextEntry
    currentOrderTextView.font = Font(uiCommon.fontName, 16)
    currentOrderTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    currentOrderTextView.color = mj.textColor
    currentOrderTextView.text = locale:get("order_idle")
    currentOrderTextView.baseOffset = vec3(2.0,-6.0,0.0)
    --currentOrderTextView.baseOffset = vec3(-20,0, 0)
    --currentOrderTextView.wrapWidth = 300.0
    --currentOrderTextView.textAlignment = MJHorizontalAlignmentRight

    local iconHalfSize = 8.0

    happyIconsView = ColorView.new(sapienDetailView)
    happyIconsView.color = mjm.vec4(0.2,0.2,0.2,0.2)
    happyIconsView.size = vec2(130.0,24.0)
    happyIconsView.relativeView = currentOrderTextView
    happyIconsView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    happyIconsView.baseOffset = vec3(0.0,-6.0,0.0)
    uiToolTip:add(happyIconsView, ViewPosition(MJPositionCenter, MJPositionAbove), locale:get("mood_happySad_name"), nil, vec3(0,8,2), nil, nil)

    local happyIcon = ModelView.new(happyIconsView)
    happyIcon.masksEvents = false
    happyIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    happyIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
    happyIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    happyIcon.baseOffset = vec3(4.0,0.0,0.0)
    happyIcon:setModel(model:modelIndexForName("icon_happy"))


    loyaltyIconsView = ColorView.new(sapienDetailView)
    loyaltyIconsView.color = mjm.vec4(0.2,0.2,0.2,0.2)
    loyaltyIconsView.size = vec2(130.0,24.0)
    loyaltyIconsView.relativeView = happyIconsView
    loyaltyIconsView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    loyaltyIconsView.baseOffset = vec3(0.0,-2.0,0.0)
    uiToolTip:add(loyaltyIconsView, ViewPosition(MJPositionCenter, MJPositionAbove), locale:get("mood_loyalty_name"), nil, vec3(0,8,2), nil, nil)

    local loyaltyIcon = ModelView.new(loyaltyIconsView)
    loyaltyIcon.masksEvents = false
    loyaltyIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    loyaltyIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
    loyaltyIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    loyaltyIcon.baseOffset = vec3(4.0,0.0,0.0)
    loyaltyIcon:setModel(model:modelIndexForName("icon_tribe2"))
    

    local statusEffectsContainerViewSize = vec2(240.0, 40.0)

    statusEffectsContainerView = View.new(sapienDetailView)
    statusEffectsContainerView.relativeView = happyIconsView
    statusEffectsContainerView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    statusEffectsContainerView.size = statusEffectsContainerViewSize
    statusEffectsContainerView.baseOffset = vec3(8.0,-4.0,0.0)

    --[[happySadTextView = TextView.new(sapienDetailView)
    happySadTextView.font = Font(uiCommon.fontName, 12)
    happySadTextView.relativeView = statusEffectsContainerView
    happySadTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    happySadTextView.color = mj.textColor
    happySadTextView.baseOffset = vec3(0,-10, 0)

    loyaltyTextView = TextView.new(sapienDetailView)
    loyaltyTextView.font = Font(uiCommon.fontName, 12)
    loyaltyTextView.relativeView = happySadTextView
    loyaltyTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    loyaltyTextView.color = mj.textColor
    loyaltyTextView.baseOffset = vec3(20,0, 0)]]
    


    --[[local focusButton = uiStandardButton:create(skillsView, vec2(100.0,30.0))
    focusButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    focusButton.relativeView = currentOrderTextView
    focusButton.baseOffset = vec3(0,-4,0)
    uiStandardButton:setText(focusButton,  locale:get("ui_name_tasks") .. "...")
    uiStandardButton:setClickFunction(focusButton, function()
        local savedInfo = inspectUI.baseObjectOrVertInfo
        inspectSapienTasks:setBackFunction(function()
            inspectUI:hideUIPanel(true)
            --manageUI:hide()
            --hubUI:setLookAtInfo(sapien, false, false)
            hubUI:showInspectUI(savedInfo, nil, false)
        end)
        inspectSapienTasks:show(inspectUI.baseObjectOrVertInfo)
        inspectUI:showModalPanelView(inspectSapienTasksContainerView)
    end)
    

    local relationshipsButton = uiStandardButton:create(skillsView, vec2(100.0,30.0))
    relationshipsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    relationshipsButton.relativeView = focusButton
    relationshipsButton.baseOffset = vec3(0,-4,0)
    uiStandardButton:setText(relationshipsButton, locale:get("ui_name_relationships"))
    uiStandardButton:setClickFunction(relationshipsButton, function()
        inspectSapienRelationshipsView:show(inspectUI.baseObjectOrVertInfo)
        inspectUI:showModalPanelView(inspectSapienRelationshipsContainerView)
    end)
]]

    
    if gameConstants.showCheatButtons then
        local debugButton = uiStandardButton:create(multiSapienDetailView, vec2(80.0,20.0))
        debugButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
        debugButton.relativeView = inspectUI.cheatButton
        uiStandardButton:setText(debugButton, "MaxNeeds")
        uiStandardButton:setClickFunction(debugButton, function()
            local objectIds = {}
            for uniqueID,objectInfo in pairs(inspectUI.selectedObjectOrVertInfosByID) do
                table.insert(objectIds, uniqueID)
            end
            logicInterface:callServerFunction("maxFollowerNeeds", objectIds)
            --mjs:printDebug()
        end)
        
        local function updateHiddenStatus()
            if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu then
                debugButton.hidden = false
                --relationshipsButton.hidden = false
            else
                debugButton.hidden = true
                --relationshipsButton.hidden = true
            end
        end
        
        clientGameSettings:addObserver("renderDebug", updateHiddenStatus)
        updateHiddenStatus()
    end
    

    


end

function inspectFollowerUI:showNext(sapien)
    inspectUI:setIconForObject(sapien)
    --local animationInstance = uiAnimation:getUIAnimationInstance(sapienConstants:getAnimationGroupKey(sapien.sharedState))
    --uiCommon:setGameObjectViewObject(inspectUI.objectImageView, sapien, animationInstance)
    inspectFollowerUI:updateObjectInfo()
end


function inspectFollowerUI:showInspectPanelForActionUISelectedPlanType(planTypeIndex)

    if planTypeIndex == plan.types.manageSapien.index then
        local savedInfo = inspectUI.baseObjectOrVertInfo
        manageSapienCollection:setBackFunction(function()
            inspectUI:hideUIPanel(true)
            --manageUI:hide()
            --hubUI:setLookAtInfo(sapien, false, false)
            hubUI:showInspectUI(savedInfo, nil, false)
        end)
        manageSapienCollection:show(inspectUI.baseObjectOrVertInfo)
        inspectUI:showModalPanelView(inspectSapienTasksContainerView, manageSapienCollection)
    end
end

function inspectFollowerUI:show(baseObject, allObjects)

    
    if inspectUI.selectedObjectOrVertInfoCount > 1 then

        local objectName = mj:tostring(inspectUI.selectedObjectOrVertInfoCount) .. " " .. gameObject.types[baseObject.objectTypeIndex].plural
        inspectUI:setTitleText(objectName, false)
        sapienDetailView.hidden = true
    else
        --inspectUI.orderedObjectList = playerSapiens:getDistanceOrderedSapienList(baseObject.pos)
        --mj:log("orderedSapienList:", inspectUI.orderedObjectList)
        --mj:log("based on sapien:", sapien)
        --inspectUI.currentOredredListIndex = 1


        inspectFollowerUI:updateObjectInfo()
        sapienDetailView.hidden = false
    end
    
    multiSapienDetailView.hidden = false
    
    inspectUI:setIconForObject(baseObject)
    --local animationInstance = uiAnimation:getUIAnimationInstance(sapienConstants:getAnimationGroupKey(baseObject.sharedState))
    --uiCommon:setGameObjectViewObject(inspectUI.objectImageView, baseObject, animationInstance)
    --inspectUI.objectIconView.hidden = true

end

function inspectFollowerUI:hide()
    sapienDetailView.hidden = true
    multiSapienDetailView.hidden = true
end


return inspectFollowerUI