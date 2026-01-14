
--local gameObject = mjrequire "common/gameObject"
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4
local normalize = mjm.normalize
local mat3Rotate = mjm.mat3Rotate
local mat3GetRow = mjm.mat3GetRow

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"
local plan = mjrequire "common/plan"
local research = mjrequire "common/research"
local constructable = mjrequire "common/constructable"
local gameObject = mjrequire "common/gameObject"




--local eventManager = mjrequire "mainThread/eventManager"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local constructableUIHelper = mjrequire "mainThread/ui/constructableUIHelper"
--local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local audio = mjrequire "mainThread/audio"
--local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"
local alertPanel = mjrequire "mainThread/ui/alertPanel"
local inspectUI = mjrequire "mainThread/ui/inspect/inspectUI"
local logicInterface = mjrequire "mainThread/logicInterface"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local hubUIUtilities = mjrequire "mainThread/ui/hubUIUtilities"

local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"

--local currentDisabledPlansByGroupPlanTypeIndex = {}


local actionUI = nil
local world = nil

local actionUIOuterButtons = {}

actionUIOuterButtons.segmentOffset = 172
actionUIOuterButtons.iconOffset = 3
actionUIOuterButtons.tickOffset = -16

local selectedTerrainSegment = nil

local buttonGroupsBySegmentIndex = {}

function actionUIOuterButtons:init(gameUI_, hubUI_, world_, actionUI_)
    actionUI = actionUI_
    world = world_
end

--translate 1.15

local function updateVisuals(wheelSegment)
    local buttonTable = wheelSegment.userData

    local modelName = "ui_radialMenu_optionButton"
    
    local backgroundMaterialIndex = material.types.ui_background.index
    local outerRingMaterialIndex = material.types.ui_background.index
    local iconMaterialIndex = material.types.ui_standard.index

    if buttonTable.availibilityResult then
        iconMaterialIndex = material.types.warning.index
    else
        iconMaterialIndex = material.types.standardText.index
    end

    if buttonTable.isDestructive then
        backgroundMaterialIndex = material.types.ui_destructiveBackground_red.index
        outerRingMaterialIndex = material.types.ui_destructiveBackground_red.index
    end

    if buttonTable.disabled then
        if buttonTable.tickIcon then
            buttonTable.tickIcon.hidden = true
        end
    else
        if buttonTable.isToggledOn then
            outerRingMaterialIndex = iconMaterialIndex

            if not buttonTable.tickIcon then
                
                local iconHalfSize = 5
                
                local tickIcon = ModelView.new(wheelSegment)
                buttonTable.tickIcon = tickIcon
                tickIcon.masksEvents = false
                tickIcon.relativeView = (buttonTable.icon or buttonTable.gameObjectView)
                --tickIcon.baseOffset = vec3(10, 10, 1)
                
                tickIcon.baseOffset = buttonTable.directionNormal * actionUIOuterButtons.tickOffset + vec3(0,0, 1)
                tickIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
                tickIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
            else
                buttonTable.tickIcon.hidden = false
            end
        elseif buttonTable.tickIcon then
            buttonTable.tickIcon.hidden = true
        end
    end

    wheelSegment:setModel(model:modelIndexForName(modelName), {
        [material.types.ui_background_inset.index] = backgroundMaterialIndex,
        [material.types.ui_standard.index] = outerRingMaterialIndex
    })

    if buttonTable.disabled then
        uiToolTip:updateText(wheelSegment, "", nil, buttonTable.disabled)
    else
        uiToolTip:updateText(wheelSegment, buttonTable.name, nil, buttonTable.disabled)
    end

    if buttonTable.researchTypeIndex then
        local clueText = research.types[buttonTable.researchTypeIndex].clueText
        if clueText then
            uiToolTip:addColoredTitleText(wheelSegment,": " .. clueText, vec4(1.0,1.0,1.0,1.0))
        end
    end

    --[[if buttonTable.isDestructive then
        uiToolTip:addColoredTitleText(wheelSegment," (" .. locale:get("misc_destructive") .. ")", material:getUIColor(material.types.ui_red.index))
    end]]

    if buttonTable.disabled then
        if buttonTable.unavailableReasonText then
            uiToolTip:addColoredTitleText(wheelSegment,"(" .. buttonTable.unavailableReasonText .. ")", vec4(0.5,0.5,0.5,1.0))
        else
            uiToolTip:addColoredTitleText(wheelSegment,"(" .. locale:get("misc_unavailable") .. ")", vec4(0.5,0.5,0.5,1.0))
        end
    else
        --todo warnings for plans

        if buttonTable.isToggledOn then
            uiToolTip:addColoredTitleText(wheelSegment," (" .. locale:get("misc_enabled") .. ")", vec4(1.0,1.0,1.0,1.0))

            buttonTable.tickIcon:setModel(model:modelIndexForName("icon_tick"), {
                default = iconMaterialIndex
            })
        elseif buttonTable.isToggleType then
            uiToolTip:addColoredTitleText(wheelSegment," (" .. locale:get("misc_disabled") .. ")", vec4(0.5,0.5,0.5,1.0))
        end
    end

    
    if buttonTable.availibilityResult then
        
        local problemStrings = hubUIUtilities:getPlanProblemStrings(buttonTable.availibilityResult)
        if problemStrings and next(problemStrings) then
            local descriptionText = ""
            for i, problemString in ipairs(problemStrings) do
                descriptionText = descriptionText .. problemString
                if i < #problemStrings then
                    descriptionText = descriptionText .. "\n"
                end
            end

            uiToolTip:addColoredDescriptionText(wheelSegment, descriptionText, material:getUIColor(material.types.warning.index))
        end
        
    end
    
    if buttonTable.gameObjectView then
        uiGameObjectView:setDisabled(buttonTable.gameObjectView, buttonTable.disabled)
    else  
        if buttonTable.disabled then
            buttonTable.icon.alpha = 0.5
        else
            buttonTable.icon.alpha = 1.0
        end
        
        buttonTable.icon:setModel(model:modelIndexForName(buttonTable.iconName), {
            default = iconMaterialIndex
        })
    end

end


function actionUIOuterButtons:updatePlanAvailibility(result)
    --mj:log("actionUIOuterButtons:updatePlanAvailibility(result):", result)
    if result and next(result) then
        for segmentIndex,buttonGroup in pairs(buttonGroupsBySegmentIndex) do
            for buttonIndex,wheelSegment in ipairs(buttonGroup) do
                local buttonTable = wheelSegment.userData
                buttonTable.availibilityResult = nil
                --mj:log("buttonTable:", buttonTable)
                for i,availibilityInfo in ipairs(result) do
                    if availibilityInfo.planTypeIndex == buttonTable.planTypeIndex and buttonTable.objectTypeIndex == availibilityInfo.objectTypeIndex and buttonTable.researchTypeIndex == availibilityInfo.researchTypeIndex then
                        buttonTable.availibilityResult = availibilityInfo
                        --mj:log("match:", availibilityInfo)
                    --else
                        --mj:log("no match:", availibilityInfo)
                    end
                end
                
                updateVisuals(wheelSegment)
            end
        end
    end
end

local function addWheelSegment(parentView, rotation, toolTipDirection, buttonTable)--iconModelNameOrNil, gameObjectTypeIndexOrNil, toolTipText, toolTipDirection)
    local scaleToUse = actionUI.iconViewHalfSize -- weird, but for consistency
    local directionNormal = mat3GetRow(rotation, 1)
    buttonTable.directionNormal = directionNormal
    buttonTable.parentView = parentView

    local wheelSegmentView = View.new(parentView)
    wheelSegmentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    wheelSegmentView.size = vec2(actionUI.iconViewHalfSize * 0.5, actionUI.iconViewHalfSize * 0.5)
    wheelSegmentView.baseOffset = directionNormal * actionUIOuterButtons.segmentOffset

    local mainSegmentHasQueuedPlans = buttonTable.mainSegmentTable.planInfo.hasQueuedPlans

    if (not mainSegmentHasQueuedPlans) and (not buttonTable.mainSegmentTable.hover) then
        wheelSegmentView.hidden = true
    end

    local backgroundModelView = ModelView.new(wheelSegmentView)
    backgroundModelView.alpha = 0.97
    
    backgroundModelView:setUsesModelHitTest(true)
    backgroundModelView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse * 0.1)
    backgroundModelView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    backgroundModelView.size = vec2(actionUI.iconViewHalfSize * 0.5, actionUI.iconViewHalfSize * 0.5)

    backgroundModelView.rotation = rotation

    buttonTable.wheelSegmentView = wheelSegmentView
    backgroundModelView.userData = buttonTable

    
    backgroundModelView.hoverStart = function (mouseLoc)
        if not (buttonTable.hover or buttonTable.disabledHover) then
            if not buttonTable.disabled then
                buttonTable.hover = true
                buttonTable.disabledHover = false
                audio:playUISound(uiCommon.hoverSoundFile)
            else
                buttonTable.hover = false
                buttonTable.disabledHover = true
            end
            updateVisuals(backgroundModelView)
        end
    end

    backgroundModelView.hoverEnd = function ()
        if buttonTable.hover then
            buttonTable.hover = false
            buttonTable.mouseDown = false
        end
        buttonTable.disabledHover = false
        updateVisuals(backgroundModelView)
    end

    backgroundModelView.mouseDown = function (buttonIndex)
        if buttonIndex == 0 then
            if not buttonTable.mouseDown then
                if not buttonTable.disabled then
                    buttonTable.mouseDown = true
                    buttonTable.hover = true
                    updateVisuals(backgroundModelView)
                    audio:playUISound(uiCommon.clickDownSoundFile)
                end
            end
        end
    end

    backgroundModelView.mouseUp = function (buttonIndex)
        if (not actionUI:isAnimatingInOrOut()) and buttonIndex == 0 then
            if buttonTable.mouseDown then
                buttonTable.mouseDown = false
                updateVisuals(backgroundModelView)
                audio:playUISound(uiCommon.clickReleaseSoundFile)
            end
            if alertPanel:hidden() and buttonTable.clickFunction and not buttonTable.disabled then
                buttonTable.clickFunction()
            end
        end
    end

    local logoHalfSize = 10

    if buttonTable.iconName then
        local icon = ModelView.new(wheelSegmentView)
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        icon.baseOffset = directionNormal * actionUIOuterButtons.iconOffset + vec3(0,0, 1)
        icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
        icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0
        icon.masksEvents = false
        buttonTable.icon = icon
    elseif buttonTable.objectTypeIndex then
        local gameObjectView = uiGameObjectView:create(wheelSegmentView, vec2(logoHalfSize,logoHalfSize) * 2.2, uiGameObjectView.types.standard)
        gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        gameObjectView.baseOffset = directionNormal * actionUIOuterButtons.iconOffset + vec3(0,0, 1)
        gameObjectView.masksEvents = false
        buttonTable.gameObjectView = gameObjectView
        uiGameObjectView:setObject(buttonTable.gameObjectView, {objectTypeIndex=buttonTable.objectTypeIndex}, nil, nil)
    end

    local hoverOffset = 2.0
    if world.isVR then
        hoverOffset = -2.0
    end
    backgroundModelView.update = uiCommon:createButtonUpdateFunction(buttonTable, wheelSegmentView, hoverOffset)

    --[[local toolTipLocation = {
        relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
        offset = vec3(buttonLocation.offset.x,buttonLocation.offset.y + 40.0, 10)
    }]]

-- uiToolTip:add(cancelButton.userData.backgroundView, toolTipLocation.cancelRelativePosition, "Stop", nil, toolTipLocation.orderTextPlinthOffset, nil, cancelButton)
    uiToolTip:add(backgroundModelView, toolTipDirection, buttonTable.name, nil, nil, nil, wheelSegmentView)


    updateVisuals(backgroundModelView)

    return backgroundModelView
end

function actionUIOuterButtons:setPlanDisabled(groupPlanTypeIndex, planTypeIndex, newDisabled) --these functions should probably live in another module, unsure where
    local key = string.format("disabledGroupPlan_%d_%d", groupPlanTypeIndex, planTypeIndex)
    local prevBoolValue = clientGameSettings.values[key] ~= nil
    local newBoolValue = (newDisabled ~= nil and newDisabled ~= false)
    if prevBoolValue ~= newBoolValue then
        if newBoolValue then
            clientGameSettings:changeSetting(key, true)
        else
            clientGameSettings:changeSetting(key, nil)
        end
    end
end

function actionUIOuterButtons:getPlanDisabled(groupPlanTypeIndex, planTypeIndex)
    local key = string.format("disabledGroupPlan_%d_%d", groupPlanTypeIndex, planTypeIndex)
    return clientGameSettings.values[key]
end


local currentHoverSegmentIndex = nil

function actionUIOuterButtons:update()

    --currentHoverSegmentIndex = nil

    local parentView = actionUI.backgroundView
    local viewsToRemove = {}
    
    for segmentIndex,buttonGroup in pairs(buttonGroupsBySegmentIndex) do
        for buttonIndex,wheelSegment in ipairs(buttonGroup) do
            local buttonTable = wheelSegment.userData
            if buttonTable.hover then --if we are interacting right now, just throw this update away
                return
            end
            table.insert(viewsToRemove, buttonTable.wheelSegmentView)
        end
    end
    
    buttonGroupsBySegmentIndex = {}

    for i,wheelSegmentView in ipairs(viewsToRemove) do
        parentView:removeSubview(wheelSegmentView)
    end

    local wheel = actionUI.wheels[actionUI.currentWheelIndex]
    
    local function getRotationInfo(buttonCount, segmentIndex)
        local iconLocations = actionUI.iconLocationsForCounts[#wheel.segments]
        local iconLocationOffset = iconLocations[segmentIndex].offset
        local iconLocationOffsetNormal = normalize(vec3(iconLocationOffset.x, iconLocationOffset.y, 0))
        local toolTipDirection = uiToolTip:relativePositionForDirection(iconLocationOffsetNormal)

        local rotationDirection = 1
        if iconLocationOffsetNormal.x > 0.5 or iconLocationOffsetNormal.y > 0.5 then
            rotationDirection = -1
        end

        local rotation = mjm.createUpAlignedRotationMatrix(iconLocationOffsetNormal, vec3(0,0,1))
        if buttonCount > 1 then
            rotation = mat3Rotate(rotation, (-rotationDirection * math.pi / 32) * (buttonCount - 1), vec3(0,0, 1))
        end

        return {
            rotation = rotation,
            rotationDirection = rotationDirection,
            toolTipDirection = toolTipDirection,
        }
    end

    for segmentIndex,segment in ipairs(wheel.segments) do
        local segmentTable = segment.userData

        if segmentTable.planTypeIndex == plan.types.fill.index then

            local orderedFillTypeList = constructableUIHelper.orderedFillTypeList
            local buttonCount = #orderedFillTypeList + 1

            local rotationInfo = getRotationInfo(buttonCount, segmentIndex)
            local rotation = rotationInfo.rotation
            local toolTipDirection = rotationInfo.toolTipDirection
            local rotationDirection = rotationInfo.rotationDirection

            local buttonGroup = {}
            buttonGroupsBySegmentIndex[segmentIndex] = buttonGroup
            
            local outerWheelSegment = addWheelSegment(parentView, rotation, toolTipDirection, {
                iconName = "icon_settings",
                name = locale:get("ui_action_setFillType"),
                mainSegmentTable = segmentTable,
            })
            table.insert(buttonGroup, outerWheelSegment)

            outerWheelSegment.userData.clickFunction = function()
                inspectUI:showInspectPanelForActionUIOptionsButton(segmentTable.planTypeIndex)
            end
            
            local selectedConstructableTypeIndex = constructableUIHelper:getTerrainFillConstructableTypeIndex()
            selectedTerrainSegment = nil

            for i,constructableTypeIndex in ipairs(orderedFillTypeList) do
                rotation = mat3Rotate(rotation, (rotationDirection * math.pi / 16), vec3(0,0, 1))
                
                local constructableType = constructable.types[constructableTypeIndex]
                local gameObjectType = gameObject.types[constructableType.iconGameObjectType]

                local hasSeenRequiredResources = constructableUIHelper:checkHasSeenRequiredResourcesIncludingVariations(constructableType, nil)
                local hasSeenRequiredTools = constructableUIHelper:checkHasSeenRequiredTools(constructableType, nil)
                local discoveryComplete = constructableUIHelper:checkHasRequiredDiscoveries(constructableType)

                local newUnlocked = discoveryComplete and hasSeenRequiredResources and hasSeenRequiredTools

                local isToggledOn = false
                if constructableTypeIndex == selectedConstructableTypeIndex then
                    isToggledOn = true
                end

                local fillSegment = addWheelSegment(parentView, rotation, toolTipDirection, {
                        objectTypeIndex = gameObjectType.index,
                        name = constructableType.name,
                        isToggledOn = isToggledOn,
                        unavailableReasonText = constructableUIHelper:getDisabledToolTipText(discoveryComplete, hasSeenRequiredResources, hasSeenRequiredTools),
                        disabled = (not newUnlocked),
                        mainSegmentTable = segmentTable,
                    })
                table.insert(buttonGroup, fillSegment)

                if isToggledOn then
                    selectedTerrainSegment = fillSegment
                end

                fillSegment.userData.clickFunction = function()
                    if fillSegment ~= selectedTerrainSegment then

                        selectedTerrainSegment.userData.isToggledOn = false
                        updateVisuals(selectedTerrainSegment)
                        selectedTerrainSegment = fillSegment
                        selectedTerrainSegment.userData.isToggledOn = true
                        updateVisuals(selectedTerrainSegment)

                        world:setTerrainFillConstructableTypeIndex(constructableTypeIndex)

                        --todo update any existing plans
                        actionUI:updateButtons()
                        logicInterface:callServerFunction("modifyFillObjectTypeIndexForAnyPlans", {
                            vertIDs = actionUI:getCurrentObjectOfVertIDs(),
                            constructableTypeIndex = constructableTypeIndex,
                        })
                    end
                end
            end
        else
            local groupPlanInfos = segmentTable.planInfo.groupPlanInfos
            if groupPlanInfos then
                --mj:log("found groupPlanInfos:", groupPlanInfos, " segmentTable.planInfo:", segmentTable.planInfo) 

                local buttonCount = #groupPlanInfos
                local rotationInfo = getRotationInfo(buttonCount, segmentIndex)
                local rotation = rotationInfo.rotation
                local toolTipDirection = rotationInfo.toolTipDirection
                local rotationDirection = rotationInfo.rotationDirection
                
                local buttonGroup = {}
                buttonGroupsBySegmentIndex[segmentIndex] = buttonGroup


                for i,planInfo in ipairs(groupPlanInfos) do
                    rotation = mat3Rotate(rotation, (rotationDirection * math.pi / 16), vec3(0,0, 1))

                    --mj:log("segmentTable.planTypeIndex:", segmentTable.planTypeIndex, " planInfo.planTypeIndex:", planInfo.planTypeIndex)

                    local isDestructive = false
                    if planInfo.isDestructiveOverride ~= nil then
                        isDestructive = planInfo.isDestructiveOverride
                    else
                        isDestructive = plan.types[planInfo.planTypeIndex].isDestructive or (planInfo.researchTypeIndex and research.types[planInfo.researchTypeIndex].isDestructive)
                    end

                    local isToggledOn = (not actionUIOuterButtons:getPlanDisabled(segmentTable.planTypeIndex, planInfo.planTypeIndex))

                    if planInfo.hasQueuedPlans then
                        isToggledOn = true
                    elseif segmentTable.planInfo.hasQueuedPlans then
                        isToggledOn = false
                    end

                    local outerWheelSegment = addWheelSegment(parentView, rotation, toolTipDirection, {
                        iconName = plan.types[planInfo.planTypeIndex].icon,
                        name = plan.types[planInfo.planTypeIndex].name,
                        mainSegmentTable = segmentTable,
                        isToggleType = true,
                        isDestructive = isDestructive,
                        isToggledOn = isToggledOn,
                        disabled = (not planInfo.hasNonQueuedAvailable) and (not planInfo.hasQueuedPlans),
                        unavailableReasonText = planInfo.unavailableReasonText,
                        planTypeIndex = planInfo.planTypeIndex,
                        researchTypeIndex = planInfo.researchTypeIndex,
                        objectTypeIndex = planInfo.objectTypeIndex,
                    })

                    table.insert(buttonGroup, outerWheelSegment)

                   --[[ local prevUpdateFunc = outerWheelSegment.update
                    outerWheelSegment.update = function(dt)
                        if prevUpdateFunc then
                            prevUpdateFunc(dt)
                        end

                    end]]

                    outerWheelSegment.userData.clickFunction = function()
                        local buttonTable = outerWheelSegment.userData
                        buttonTable.isToggledOn = (not buttonTable.isToggledOn)
                        updateVisuals(outerWheelSegment)

                        if segmentTable.planInfo.hasQueuedPlans then
                            if buttonTable.isToggledOn then
                                local addInfo = {
                                    planTypeIndex = buttonTable.planTypeIndex,
                                    objectTypeIndex = buttonTable.objectTypeIndex,
                                    researchTypeIndex = buttonTable.researchTypeIndex,
                                    objectOrVertIDs = actionUI:getCurrentObjectOfVertIDs(),
                                }

                                logicInterface:callServerFunction("addPlans", addInfo)
                            else
                                logicInterface:callServerFunction("cancelPlans", {
                                    planTypeIndex = buttonTable.planTypeIndex,
                                    objectTypeIndex = buttonTable.objectTypeIndex,
                                    researchTypeIndex = buttonTable.researchTypeIndex,
                                    objectOrVertIDs = actionUI:getCurrentObjectOfVertIDs(),
                                })
                            end
                        else
                            if buttonTable.isToggledOn then
                                actionUIOuterButtons:setPlanDisabled(segmentTable.planTypeIndex, planInfo.planTypeIndex, false)
                            else
                                actionUIOuterButtons:setPlanDisabled(segmentTable.planTypeIndex, planInfo.planTypeIndex, true)
                            end
                        end

                        --inspectUI:showInspectPanelForActionUIOptionsButton(segmentTable.planTypeIndex)
                    end
                end
            end
        end
    end 
end

function actionUIOuterButtons:hideForNewDisplay()
    if currentHoverSegmentIndex then
        
        local buttonGroup = buttonGroupsBySegmentIndex[currentHoverSegmentIndex]
        local prevHoverSegmentIndex = currentHoverSegmentIndex
        currentHoverSegmentIndex = nil

        if buttonGroup then
            for buttonIndex,outerWheelSegment in ipairs(buttonGroup) do
                local buttonTable = outerWheelSegment.userData
                local mainSegmentHasQueuedPlans = buttonTable.mainSegmentTable.planInfo.hasQueuedPlans

                if (not mainSegmentHasQueuedPlans) and (not buttonTable.mainSegmentTable.hover) then
                    buttonTable.wheelSegmentView.hidden = true
                end

                if buttonTable.mainSegmentTable.hover then
                    currentHoverSegmentIndex = prevHoverSegmentIndex
                    break
                end
            end
        end
    end
end


function actionUIOuterButtons:animateOn(wheelSegment)
    local segmentTable = wheelSegment.userData

    if currentHoverSegmentIndex then
        if currentHoverSegmentIndex == segmentTable.segmentIndex then
            return
        end

        actionUIOuterButtons:hideForNewDisplay()
    end

    local buttonGroup = buttonGroupsBySegmentIndex[segmentTable.segmentIndex]
    if buttonGroup then
        currentHoverSegmentIndex = segmentTable.segmentIndex
        for buttonIndex,outerWheelSegment in ipairs(buttonGroup) do
            outerWheelSegment.userData.wheelSegmentView.hidden = false
            --local buttonTable = outerWheelSegment.userData
        end
    end
end

return actionUIOuterButtons