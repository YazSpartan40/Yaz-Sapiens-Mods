local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

local gameObject = mjrequire "common/gameObject"
--local model = mjrequire "common/model"
--local order = mjrequire "common/order"
local plan = mjrequire "common/plan"
local mob = mjrequire "common/mob/mob"
local resource = mjrequire "common/resource"
local locale = mjrequire "common/locale"
local selectionGroup = mjrequire "common/selectionGroup"
local compostBin = mjrequire "common/compostBin"
--local timer = mjrequire "common/timer"

local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
----local evolvingObject = mjrequire "common/evolvingObject"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiTextEntry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"
local mainThreadDestination = mjrequire "mainThread/mainThreadDestination"
--local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
--local logicInterface = mjrequire "mainThread/logicInterface"


--local sapienMoveUI = mjrequire "mainThread/ui/sapienMoveUI"
--local inspectSapienRelationshipsView = mjrequire "mainThread/ui/inspect/inspectSapienRelationshipsView"
local hubUIUtilities = mjrequire "mainThread/ui/hubUIUtilities"
local inspectCraftPanel = mjrequire "mainThread/ui/inspect/inspectCraftPanel"
local inspectStoragePanel = mjrequire "mainThread/ui/inspect/inspectStoragePanel"
local inspectUsePanel = mjrequire "mainThread/ui/inspect/inspectUsePanel"
local inspectRebuildPanel = mjrequire "mainThread/ui/inspect/inspectRebuildPanel"

--local logicInterface = mjrequire "mainThread/logicInterface"

local inspectObjectUI = {}

local inspectUI = nil
local world = nil

local objectDetailView = nil


local inspectCraftContainerView = nil
local manageStorageContainerView = nil
local inspectUseContainerView = nil
local inspectRebuildContainerView = nil

local extraInfoViews = {}
local planInfoView = nil

--local degradeTimerUpdateTimerID = nil

local degradeInfoView = nil

function inspectObjectUI:updateObjectInfo()
    local object = inspectUI.baseObjectOrVertInfo
    --local sharedState = object.sharedState

   -- mj:log("sharedState:", sharedState)

    --local objectName = uiCommon:getNameForObject(object)

    
    for i=1,4 do
        extraInfoViews[i].hidden = true
    end

    if inspectUI.selectedObjectOrVertInfoCount > 1 then

        local function getSelectionGroupName()
            local firstGameObjectType = gameObject.types[object.objectTypeIndex]
            if firstGameObjectType.additionalSelectionGroupTypeIndexes and #firstGameObjectType.additionalSelectionGroupTypeIndexes > 0 then
                for i,otherObject in ipairs(inspectUI.allObjectsOrVerts) do
                    if otherObject.objectTypeIndex ~= object.objectTypeIndex then
                        local otherGameObjectType = gameObject.types[otherObject.objectTypeIndex]
                        for j,selectionGroupTypeIndex in ipairs(firstGameObjectType.additionalSelectionGroupTypeIndexes) do
                            for k,otherSelectionGroupTypeIndex in ipairs(otherGameObjectType.additionalSelectionGroupTypeIndexes) do
                                if otherSelectionGroupTypeIndex == selectionGroupTypeIndex then
                                    return selectionGroup.types[selectionGroupTypeIndex].plural
                                end
                            end
                        end
                    end
                end
            end
            return gameObject.types[object.objectTypeIndex].plural
        end

        local selectionGroupName = getSelectionGroupName()

        if not selectionGroupName then
            selectionGroupName = gameObject.types[object.objectTypeIndex].plural
        end

        local objectName = mj:tostring(inspectUI.selectedObjectOrVertInfoCount) .. " " .. selectionGroupName
        inspectUI:setTitleText(objectName, false)
    else
        local gameObjectType = gameObject.types[object.objectTypeIndex]
        local objectName = gameObjectType.name
        if object.sharedState and object.sharedState.name then
            objectName = object.sharedState.name
        end

        hubUIUtilities:updatePlanInfoView(planInfoView, false, object, world.tribeID)

        inspectUI.objectName = objectName

        if inspectUI:canChangeName() then
            if not uiTextEntry:isEditing(inspectUI.nameTextEntry) then
                inspectUI:setTitleText(objectName, true)
            end
        else
            inspectUI:setTitleText(objectName, false)
        end

        local extraTextIndex = 1
        
        if planInfoView.hidden then
            planInfoView.size = vec2(0.0,0.0)
        end

        
        hubUIUtilities:updateDegradeInfoView(degradeInfoView, object, world:getWorldTime())
        if degradeInfoView.hidden then
            degradeInfoView.size = vec2(0.0,0.0)
        end

        if object.objectTypeIndex == gameObject.types.sapien.index then
            local sapienSharedState = object.sharedState
            if sapienSharedState.nomad and sapienSharedState.tribeBehaviorTypeIndex then
                local tribeInfoText = nomadTribeBehavior.types[sapienSharedState.tribeBehaviorTypeIndex].name
                if sapienSharedState.fleeing then
                    tribeInfoText = tribeInfoText .. " (" .. locale:get("action_flee_inProgress") .. ")"
                end
                extraInfoViews[extraTextIndex].text = tribeInfoText
                extraTextIndex = extraTextIndex + 1
            else
                local destinationInfo = mainThreadDestination.destinationInfosByID[sapienSharedState.tribeID]
                if destinationInfo then
                    if destinationInfo.unprotectedByAnyAbleSapiens then
                        local tribeInfoText =  " (" .. locale:get("misc_unprotected") .. ")"
                        extraInfoViews[extraTextIndex].text = tribeInfoText
                        extraTextIndex = extraTextIndex + 1
                    end
                end
            end
        end

        local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
        if mobTypeIndex and object.sharedState.health then
            local mobType = mob.types[mobTypeIndex]
            extraInfoViews[extraTextIndex].text = string.format("%d/%d", object.sharedState.health * 10.5, mobType.initialHealth * 10.5)
            extraTextIndex = extraTextIndex + 1
        end

        local resourceTypeIndex = gameObject.types[object.objectTypeIndex].resourceTypeIndex
        if resourceTypeIndex then
            local foodPortionCount = resource:getFoodPortionCount(object.objectTypeIndex)
            if foodPortionCount then
                local availablePortionCount = foodPortionCount - (object.sharedState.usedPortionCount or 0)
                if availablePortionCount ~= 0 then
                    extraInfoViews[extraTextIndex].text = locale:get("ui_portionCount", {portionCount = availablePortionCount})
                    extraTextIndex = extraTextIndex + 1
                end

            end
        end

        if object.objectTypeIndex == gameObject.types.compostBin.index then
            local extraCompostText = compostBin:getCompostUIInfoText(object)
            if extraCompostText then
                extraInfoViews[extraTextIndex].text = extraCompostText
                extraTextIndex = extraTextIndex + 1
            end
        end

        --local sharedState = object.sharedState


        --[[if sharedState.fractionDegraded then
            local evolution = evolvingObject.evolutions[object.objectTypeIndex]
            if evolution then
                local covered = sharedState.covered
                local evolutionLength = evolution.minTime
                if covered then
                    evolutionLength = evolutionLength * evolvingObject.coveredDurationMultiplier
                end
                local degradeReferenceTime = sharedState.degradeReferenceTime or world:getWorldTime()
                
                local timeRemaining = (1.0 - sharedState.fractionDegraded) * evolutionLength
                local evolveTime = degradeReferenceTime + timeRemaining

                
                local yearLengthHours = world:getYearLength() / world:getDayLength() * 24

                local bucketThresholdsHours = {
                    {
                        time = 2,
                        name = "very soon",
                    },
                    {
                        time = 24,
                        name = "< 1 day",
                    },
                    {
                        time = 48,
                        name = "< 2 days",
                    },
                    {
                        time = yearLengthHours,
                        name = "< 1 year",
                    },
                    {
                        time = yearLengthHours * 100,
                        name = "> 1 year",
                    },
                }
                
                local function getDegradeBucket(degradeDuration)
                    local hours = degradeDuration / world:getDayLength() * 24
                    for i,bucketThreshold in ipairs(bucketThresholdsHours) do
                        if hours < bucketThreshold.time then
                            return i
                        end
                    end
                end

                local function setText()

                    local bucketIndex = getDegradeBucket(evolveTime - world:getWorldTime())
                    local timeRangeDescription = bucketThresholdsHours[bucketIndex].name --todo use localization again
                    local textValue = locale:get("evolution_timeFunc", {
                        actionName = evolvingObject.categories[evolution.categoryIndex].actionName,
                        time = timeRangeDescription
                    })

                   -- local remainingTimeDescription = locale:getTimeDurationDescription(evolveTime - world:getWorldTime(), world:getDayLength(), world:getYearLength())
                    if evolution.toType then
                        degradeTextView.text = textValue
                    else
                        degradeTextView.text = textValue
                    end
                end

                local function updateTimerText(timerID)
                    if timerID == degradeTimerUpdateTimerID and not objectDetailView.hidden then
                        setText()
                        degradeTimerUpdateTimerID = timer:addCallbackTimer(1.0, updateTimerText)
                    end
                end

                setText()
                degradeTimerUpdateTimerID = timer:addCallbackTimer(1.0, updateTimerText)
                degradeView.hidden = false
                degradeView.size = degradeTextView.size
            else
                
                degradeView.hidden = true
            end
        else
            degradeView.hidden = true
        end]]

        for i=1,extraTextIndex-1 do
            extraInfoViews[i].hidden = false
        end
    end

    
    inspectUI.contentExtraHeight = 0.0
    inspectUI.contentExtraWidth = 0.0
    local maxWidth = 0.0
    
    if not planInfoView.hidden then
        inspectUI.contentExtraHeight = inspectUI.contentExtraHeight + planInfoView.size.y
        maxWidth = math.max(maxWidth, planInfoView.size.x)
    end
    
    if not degradeInfoView.hidden then
        inspectUI.contentExtraHeight = inspectUI.contentExtraHeight + degradeInfoView.size.y
        maxWidth = math.max(maxWidth, degradeInfoView.size.x)
    end

    for i=1,4 do
        if not extraInfoViews[i].hidden then
            if i == 1 then
                inspectUI.contentExtraHeight = inspectUI.contentExtraHeight + 4
            end
            inspectUI.contentExtraHeight = inspectUI.contentExtraHeight + extraInfoViews[i].size.y
            maxWidth = math.max(maxWidth, extraInfoViews[i].size.x)
        end
        if maxWidth > inspectUI.defaultContentWidth then
            inspectUI.contentExtraWidth = maxWidth - inspectUI.defaultContentWidth + 4
        end
    end


end

function inspectObjectUI:load(gameUI, inspectUI_, world_, manageUI_)

    inspectUI = inspectUI_
    world = world_

    local containerView = inspectUI.containerView
    objectDetailView = View.new(containerView)
    objectDetailView.size = containerView.size
    objectDetailView.hidden = true

    
    inspectCraftContainerView = View.new(inspectUI.modalPanelView)
    inspectCraftContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    inspectCraftContainerView.size = inspectUI.modalPanelView.size
    inspectCraftContainerView.hidden = true
    inspectObjectUI.inspectCraftContainerView = inspectCraftContainerView

    inspectCraftPanel:load(inspectUI, inspectObjectUI, world, inspectCraftContainerView)

    
    manageStorageContainerView = View.new(inspectUI.modalPanelView)
    manageStorageContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    manageStorageContainerView.size = inspectUI.modalPanelView.size
    manageStorageContainerView.hidden = true
    inspectObjectUI.manageStorageContainerView = manageStorageContainerView

    inspectStoragePanel:load(inspectUI, inspectObjectUI, world, gameUI, manageUI_, manageStorageContainerView)

    
    inspectUseContainerView = View.new(inspectUI.modalPanelView)
    inspectUseContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    inspectUseContainerView.size = inspectUI.modalPanelView.size
    inspectUseContainerView.hidden = true
    inspectObjectUI.inspectUseContainerView = inspectUseContainerView

    inspectUsePanel:load(inspectUI, inspectObjectUI, world, inspectUseContainerView)
    
    inspectRebuildContainerView = View.new(inspectUI.modalPanelView)
    inspectRebuildContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    inspectRebuildContainerView.size = inspectUI.modalPanelView.size
    inspectRebuildContainerView.hidden = true
    inspectObjectUI.inspectRebuildContainerView = inspectRebuildContainerView

    inspectRebuildPanel:load(inspectUI, inspectObjectUI, world, inspectRebuildContainerView)

    planInfoView = hubUIUtilities:createPlanInfoView(objectDetailView)
    planInfoView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    planInfoView.relativeView = inspectUI.nameTextEntry
    planInfoView.baseOffset = vec3(4,-4,0)
    planInfoView.hidden = true
    planInfoView.size = vec2(0.0,0.0)

    degradeInfoView = hubUIUtilities:createDegradeInfoView(objectDetailView)
    degradeInfoView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    degradeInfoView.relativeView = planInfoView
    degradeInfoView.baseOffset = vec3(0,-4,0)
    degradeInfoView.hidden = true
    degradeInfoView.size = vec2(0.0,0.0)

    --[[degradeTextView = TextView.new(objectDetailView)
    degradeTextView.font = Font(uiCommon.fontName, 16)
    degradeTextView.color = mj.textColor
    degradeTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)]]

    for i=1,4 do
        extraInfoViews[i] = TextView.new(objectDetailView)
        extraInfoViews[i].font = Font(uiCommon.fontName, 16)
        extraInfoViews[i].color = mj.textColor
        extraInfoViews[i].hidden = true
    end
    
    extraInfoViews[1].relativeView = degradeInfoView
    extraInfoViews[1].relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    extraInfoViews[1].baseOffset = vec3(0,0,0)

    for i=2,4 do
        extraInfoViews[i].relativeView = extraInfoViews[i - 1]
        extraInfoViews[i].relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    end

    --inspectCraftPanel:load(gameUI, inspectUI)


end

function inspectObjectUI:showInspectPanelForActionUISelectedPlanType(planTypeIndex)
    if inspectUI.baseObjectOrVertInfo then
        if planTypeIndex == plan.types.craft.index then
            inspectCraftPanel:show(inspectUI.baseObjectOrVertInfo)
            inspectUI:showModalPanelView(inspectCraftContainerView, inspectCraftPanel)
        elseif planTypeIndex == plan.types.manageStorage.index then
            inspectStoragePanel:show(inspectUI.baseObjectOrVertInfo)
            inspectUI:showModalPanelView(manageStorageContainerView, inspectStoragePanel)
        elseif planTypeIndex == plan.types.constructWith.index then
            inspectUsePanel:show(inspectUI.baseObjectOrVertInfo)
            inspectUI:showModalPanelView(inspectUseContainerView, inspectUsePanel)
        elseif planTypeIndex == plan.types.rebuild.index then
            inspectRebuildPanel:show(inspectUI.baseObjectOrVertInfo)
            inspectUI:showModalPanelView(inspectRebuildContainerView, inspectRebuildPanel)
        end
    end
end

function inspectObjectUI:show(baseObject, allObjects)
    objectDetailView.hidden = false

   --[[ if baseObject then
        local gameObjectType = gameObject.types[baseObject.objectTypeIndex]

        if gameObjectType.iconOverrideIconModelName then
            uiCommon:setGameObjectViewObject(inspectUI.objectImageView, nil)
            inspectUI.objectIconView:setModel(model:modelIndexForName(gameObjectType.iconOverrideIconModelName))
            inspectUI.objectIconView.hidden = false
        else
            uiCommon:setGameObjectViewObject(inspectUI.objectImageView, baseObject)
            inspectUI.objectIconView.hidden = true
        end
    else
        uiCommon:setGameObjectViewObject(inspectUI.objectImageView, nil)
        inspectUI.objectIconView.hidden = true
    end]]

    
    inspectUI:setIconForObject(baseObject)

    --uiCommon:setGameObjectViewObject(inspectUI.objectImageView, baseObject)
    
    inspectObjectUI:updateObjectInfo()
end

function inspectObjectUI:hide()
    if not objectDetailView.hidden then
        objectDetailView.hidden = true
    end
end



return inspectObjectUI