local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local approxEqual = mjm.approxEqual

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local plan = mjrequire "common/plan"
--local research = mjrequire "common/research"

local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local playerSapiens = mjrequire "mainThread/playerSapiens"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"

local planMarkersUI = {}

local localPlayer = nil

local hoverMarkerID = nil

local markerViewInfosByID = {}
local terrainMarkerObjectIDsByVertID = {}
local normalSize = 0.2 * 0.55
local warningSize = 0.3 * 0.55
local smallSize = 0.008

local maxDistance = mj:mToP(2000.0)
local dotDistance = mj:mToP(50.0)
local minDistance = mj:mToP(0.3)
local startScalingDistance = mj:mToP(4.0)

local orderMarkerWarningIconYOffset = -0.1

local function updateAssignedSapienViewSize(info)
    if info.assignedSapienInfos then
        local sizeMultiplier = 0.3
        if info.selected then
            sizeMultiplier = 0.6
        end
        local assignedViewSize = info.currentSize * sizeMultiplier
        local assignedScaleToUse = assignedViewSize * 0.5
        info.assignedSapienView.scale3D = vec3(assignedScaleToUse,assignedScaleToUse,assignedScaleToUse)
        info.assignedSapienView.size = vec2(assignedViewSize, assignedViewSize)
        info.assignedSapienView.baseOffset = vec3(info.currentSize * 0.4, -info.currentSize * 0.3, info.currentSize * 0.01)
        
        if info.selected and info.assignedObjectImageView then
            local objectViewRenderSizeNew = info.currentSize * sizeMultiplier * 0.75
            uiGameObjectView:setSize(info.assignedObjectImageView, vec2(objectViewRenderSizeNew,objectViewRenderSizeNew))
        end
    end
end

local function updateManuallyPrioritzedViewSize(info)
    if info.manuallyPrioritized then
        local sizeMultiplier = 0.6
        if info.selected then
            sizeMultiplier = 0.6
        end
        local assignedViewSize = info.currentSize * sizeMultiplier
        local assignedScaleToUse = assignedViewSize * 0.5
        info.manuallyPrioritizedView.scale3D = vec3(assignedScaleToUse,assignedScaleToUse,assignedScaleToUse)
        info.manuallyPrioritizedView.size = vec2(assignedViewSize, assignedViewSize)
        info.manuallyPrioritizedView.baseOffset = vec3(-info.currentSize * 0.4, -info.currentSize * 0.3, info.currentSize * 0.01)
        
        --[[if info.selected and info.assignedObjectImageView then
            local objectViewRenderSizeNew = info.currentSize * sizeMultiplier * 0.75
            uiGameObjectView:setSize(info.assignedObjectImageView, vec2(objectViewRenderSizeNew,objectViewRenderSizeNew))
        end]]
    end
end


local function updateMarker(markerViewInfo)
    local warning = markerViewInfo.hasImpossiblePlan
    
    local remapMaterialIndex = nil
    local materialIndex = material.types.ui_standard.index
    local backgroundMaterialIndex = material.types.ui_background_black.index
    local modelName =  "ui_order"
    local distantModelName = nil
    local iconYOffset = 0.0

    --if markerViewInfo.isDestructive then --looks ugly, more confusing than useful
        --backgroundMaterialIndex = material.types.ui_orderMarkerdestructiveBackground_red.index
        --[[wheelSegment:setModel(model:modelIndexForName(buttonTable.modelName), {
            default = material.types.ui_orderMarkerdestructiveBackground_red.index
        })]]
   -- end

    if warning then
        if markerViewInfo.maintainQuantityThresholdMet then
            modelName = "ui_order_warningSquare"
            distantModelName = "ui_warningDistantMarkerSquare"
            materialIndex = material.types.ui_standard.index
        else
            modelName = "ui_order_warning"
            distantModelName = "ui_warningDistantMarker"
            materialIndex = material.types.warning.index

            iconYOffset = warningSize * orderMarkerWarningIconYOffset
        end
        remapMaterialIndex = material.types.warning.index
    else
        if markerViewInfo.hasMaintainQuantitySet then
            modelName = "ui_order_warningSquare"
            distantModelName = "ui_warningDistantMarkerSquare"
            remapMaterialIndex = material.types.warning.index
        else
            modelName = "ui_order"
            distantModelName = "ui_okDistantMarker"
            remapMaterialIndex = material.types.ui_standard.index
        end
        materialIndex = material.types.ok.index
    end

    local showFull = markerViewInfo.selected or markerViewInfo.isClose
    

    if showFull then
        local extraYOffset = 0.0
        if markerViewInfo.attachBoneName then --
            if playerSapiens:sapienIsFollower(markerViewInfo.uniqueID) then
                extraYOffset = 0.2
            else
                extraYOffset = 0.1
            end
        end
        
        markerViewInfo.extraYOffset = extraYOffset
        markerViewInfo.view.baseOffset = vec3(0.0,normalSize * 0.5 + markerViewInfo.currentScale * markerViewInfo.extraYOffset,0.0)

        if markerViewInfo.selected then
            markerViewInfo.goalScale = 2.0
        else
            markerViewInfo.goalScale = 1.0
        end

        if markerViewInfo.hasImpossiblePlan then
            markerViewInfo.currentSize = warningSize * markerViewInfo.currentScale
        else
            markerViewInfo.currentSize = normalSize * markerViewInfo.currentScale
        end

        

        if markerViewInfo.iconObjectTypeIndex then
            local gameObjectView = markerViewInfo.gameObjectView
            if not gameObjectView then
                gameObjectView = uiGameObjectView:create(markerViewInfo.backgroundView, vec2(128,128), uiGameObjectView.types.standard)
                gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
                gameObjectView.baseOffset = vec3(0.0,0.0, 0.001)
                gameObjectView.hidden = true
                gameObjectView.masksEvents = false
                local logoHalfSize = markerViewInfo.currentSize * 0.4 * 0.5
                uiGameObjectView:setSize(gameObjectView, vec2(logoHalfSize,logoHalfSize) * 2.5)
                markerViewInfo.gameObjectView = gameObjectView
            end
            local objectInfo = {
                objectTypeIndex = markerViewInfo.iconObjectTypeIndex
            }

            uiGameObjectView:setObject(gameObjectView, objectInfo, nil, nil)
            gameObjectView.baseOffset = vec3(0, markerViewInfo.goalScale * iconYOffset, 0.001)

            gameObjectView.hidden = false
            if markerViewInfo.icon then
                markerViewInfo.backgroundView:removeSubview(markerViewInfo.icon)
                markerViewInfo.icon = nil
            end
        else
            local icon = markerViewInfo.icon
            if not icon then
                icon = ModelView.new(markerViewInfo.backgroundView)
                icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
                icon.baseOffset = vec3(0, 0, 0.001)
                icon.masksEvents = false
                markerViewInfo.icon = icon
                local logoHalfSize = markerViewInfo.currentSize * 0.4 * 0.5
                icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
                icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0
            end
            icon.hidden = false
            if markerViewInfo.gameObjectView then
                markerViewInfo.backgroundView:removeSubview(markerViewInfo.gameObjectView)
                markerViewInfo.gameObjectView= nil
            end
            local iconPlanTypeIndex = markerViewInfo.planTypeIndex
            local groupHeaderTypeKey = plan.types[iconPlanTypeIndex].groupHeaderTypeKey
            if groupHeaderTypeKey then
                iconPlanTypeIndex = plan.types[groupHeaderTypeKey].index
            end
            icon:setModel(model:modelIndexForName(plan.types[iconPlanTypeIndex].icon or "icon_hand"), {
                default = materialIndex,
            })
            icon.baseOffset = vec3(0, markerViewInfo.goalScale * iconYOffset, 0.001)
        end


        markerViewInfo.backgroundView:setModel(model:modelIndexForName(modelName), {
            [remapMaterialIndex] = materialIndex,
            [material.types.ui_background.index] = backgroundMaterialIndex,
        })
        
        markerViewInfo.assignedSapienView.hidden = (markerViewInfo.assignedSapienInfos == nil)
        markerViewInfo.manuallyPrioritizedView.hidden = (not markerViewInfo.manuallyPrioritized)

        
        if markerViewInfo.assignedSapienInfos ~= nil then
                    
            if markerViewInfo.selected then
                markerViewInfo.assignedSapienView:setModel(model:modelIndexForName("ui_orderSmall"), {
                    [material.types.ui_standard.index] = material.types.ok.index,
                })
                
                if not markerViewInfo.assignedObjectImageView then
                    local objectViewTextureSize = 64
                    local assignedObjectImageView = uiGameObjectView:create(markerViewInfo.assignedSapienView, vec2(objectViewTextureSize,objectViewTextureSize), uiGameObjectView.types.standard)
                    markerViewInfo.assignedObjectImageView = assignedObjectImageView
                end
                markerViewInfo.assignedObjectImageView.hidden = false
                uiGameObjectView:setObject(markerViewInfo.assignedObjectImageView, markerViewInfo.assignedSapienInfos[1], nil, nil)
                local objectViewRenderSizeNew = markerViewInfo.currentSize * 0.5 * 0.75
                uiGameObjectView:setSize(markerViewInfo.assignedObjectImageView, vec2(objectViewRenderSizeNew,objectViewRenderSizeNew))

            else
                markerViewInfo.assignedSapienView:setModel(model:modelIndexForName("ui_orderSmallDot"),{
                    [material.types.ui_standard.index] = material.types.ok.index,
                })
                if markerViewInfo.assignedObjectImageView then
                    markerViewInfo.assignedObjectImageView.hidden = true
                end
            end

            updateAssignedSapienViewSize(markerViewInfo)
        end

        if markerViewInfo.manuallyPrioritized then
            -- uiStandardButton:setIconModel(prioritizeButton, "icon_upArrow", nil)
            --[[if markerViewInfo.selected then
                markerViewInfo.manuallyPrioritizedView:setModel(model:modelIndexForName("ui_orderSmall"), {
                    [material.types.ui_standard.index] = material.types.ok.index,
                })
            else
                markerViewInfo.manuallyPrioritizedView:setModel(model:modelIndexForName("icon_upArrow"),{
                    [material.types.ui_standard.index] = material.types.ok.index,
                })
                
            end]]

            updateManuallyPrioritzedViewSize(markerViewInfo)
        end

        --[[if markerViewInfo.assignedSapienInfo ~= nil then
            if not markerViewInfo.assignedObjectImageView then
                local objectViewTextureSize = 64
                local assignedObjectImageView = uiGameObjectView:create(markerViewInfo.assignedSapienView, vec2(objectViewTextureSize,objectViewTextureSize), uiGameObjectView.types.standard)
                markerViewInfo.assignedObjectImageView = assignedObjectImageView
            end
            uiGameObjectView:setObject(markerViewInfo.assignedObjectImageView, markerViewInfo.assignedSapienInfo, nil, nil)
            local objectViewRenderSizeNew = markerViewInfo.currentSize * 0.5 * 0.75
            uiGameObjectView:setSize(markerViewInfo.assignedObjectImageView, vec2(objectViewRenderSizeNew,objectViewRenderSizeNew))
        end]]
    else
        if markerViewInfo.icon then
            markerViewInfo.backgroundView:removeSubview(markerViewInfo.icon)
            markerViewInfo.icon = nil
        end
        if markerViewInfo.gameObjectView then
            markerViewInfo.backgroundView:removeSubview(markerViewInfo.gameObjectView)
            markerViewInfo.gameObjectView = nil
        end
        
        
        markerViewInfo.backgroundView:setModel(model:modelIndexForName(distantModelName),{
            [material.types.ui_background.index] = backgroundMaterialIndex,
        })

        markerViewInfo.assignedSapienView.hidden = true
        markerViewInfo.manuallyPrioritizedView.hidden = true
    end
    
    if (markerViewInfo.selected or markerViewInfo.isClose) and ((not approxEqual(markerViewInfo.goalScale, markerViewInfo.currentScale)) or (not approxEqual(markerViewInfo.differenceVelocity, 0.0))) then
        markerViewInfo.addUpdateFunction()
    end
end


local function removeMarker(uniqueID)
    if markerViewInfosByID[uniqueID] then
        worldUIViewManager:removeView(markerViewInfosByID[uniqueID].viewID)
        if markerViewInfosByID[uniqueID].vertID then
            terrainMarkerObjectIDsByVertID[markerViewInfosByID[uniqueID].vertID] = nil
        end
        markerViewInfosByID[uniqueID] = nil
        localPlayer:markerLookAtEnded(uniqueID)
        
    end
end

function planMarkersUI:updatePlan(planInfo)
    if not planInfo.planTypeIndex then
        mj:error("no planTypeIndex in planMarkersUI:updatePlan:", planInfo)
        return
    end
    local currentPlanViewInfo = markerViewInfosByID[planInfo.uniqueID]
    if currentPlanViewInfo then
        if currentPlanViewInfo.hasImpossiblePlan ~= planInfo.hasImpossiblePlan or 
        currentPlanViewInfo.planTypeIndex ~= planInfo.planTypeIndex or 
        currentPlanViewInfo.manuallyPrioritized ~= planInfo.manuallyPrioritized or 
        currentPlanViewInfo.disabledDueToOrderLimit ~= planInfo.disabledDueToOrderLimit  or 
        currentPlanViewInfo.iconObjectTypeIndex ~= planInfo.iconObjectTypeIndex  or 
        currentPlanViewInfo.maintainQuantityThresholdMet ~= planInfo.maintainQuantityThresholdMet  or 
        ((currentPlanViewInfo.assignedSapienInfos == nil) ~= (planInfo.assignedSapienInfos == nil)) or
        (currentPlanViewInfo.assignedSapienInfos and #currentPlanViewInfo.assignedSapienInfos ~= #planInfo.assignedSapienInfos) then
            currentPlanViewInfo.hasImpossiblePlan = planInfo.hasImpossiblePlan
            currentPlanViewInfo.disabledDueToOrderLimit = planInfo.disabledDueToOrderLimit
            currentPlanViewInfo.maintainQuantityThresholdMet = planInfo.maintainQuantityThresholdMet
            currentPlanViewInfo.hasMaintainQuantitySet = planInfo.hasMaintainQuantitySet
            currentPlanViewInfo.planTypeIndex = planInfo.planTypeIndex
            currentPlanViewInfo.manuallyPrioritized = planInfo.manuallyPrioritized
            currentPlanViewInfo.iconObjectTypeIndex = planInfo.iconObjectTypeIndex
            currentPlanViewInfo.assignedSapienInfos = planInfo.assignedSapienInfos
            updateMarker(currentPlanViewInfo)
        end
        worldUIViewManager:updateView(currentPlanViewInfo.viewID, planInfo.basePos, planInfo.baseRotation, planInfo.offsets, planInfo.uniqueID, planInfo.attachBoneName)
    else
        planMarkersUI:addPlan(planInfo)
    end
end


function planMarkersUI:addPlan(planInfo)

    if not planInfo.planTypeIndex then
        mj:error("no planTypeIndex in addMarker")
        return
    end

    local uniqueID = planInfo.uniqueID
    local vertID = planInfo.vertID

    if not markerViewInfosByID[uniqueID] then
        local worldView = worldUIViewManager:addView(planInfo.basePos, worldUIViewManager.groups.orderMarker, {
            baseRotation = planInfo.baseRotation, 
            startScalingDistance = startScalingDistance, 
            offsets = planInfo.offsets, 
            minDistance = minDistance, 
            maxDistance = maxDistance, 
            attachObjectUniqueID = uniqueID,
            renderXRay = true,
            attachBoneName = planInfo.attachBoneName, 
        })
        local viewID = worldView.uniqueID
        local view = worldView.view

        local extraYOffset = 0.0
        if planInfo.attachBoneName then
            if playerSapiens:sapienIsFollower(uniqueID) then
                extraYOffset = 0.2
            else
                extraYOffset = 0.1
            end
        end
        
        view.size = vec2(warningSize * 2.0, warningSize * 2.0)
        view.baseOffset = vec3(0.0,normalSize * 0.5 + 0.5 * extraYOffset,0.0)

        local backgroundView = ModelView.new(view)
        backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        backgroundView:setUsesModelHitTest(true)
        backgroundView:setCircleHitRadius(warningSize * 1.2) --when used with modelHitTest, this is an optimization, basically a bounding circle

        
        local assignedSapienView = ModelView.new(view)
        assignedSapienView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        assignedSapienView.relativeView = backgroundView
        assignedSapienView.masksEvents = false
        assignedSapienView.hidden = (planInfo.assignedSapienInfos == nil)
        assignedSapienView:setModel(model:modelIndexForName("ui_orderSmallDot"),{
            [material.types.ui_standard.index] = material.types.ok.index,
        })
        
        local manuallyPrioritizedView = ModelView.new(view)
        manuallyPrioritizedView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        manuallyPrioritizedView.relativeView = backgroundView
        manuallyPrioritizedView.masksEvents = false
        manuallyPrioritizedView.hidden = (not planInfo.manuallyPrioritized)
        manuallyPrioritizedView:setModel(model:modelIndexForName("icon_upArrow"),{
            [material.types.ui_standard.index] = material.types.ok.index,
        })
        

        --[[
    if objectInfo then
        local objectImageViewSizeMultiplier = 0.97
        local objectImageView = uiGameObjectView:create(circleView, vec2(circleViewSize, circleViewSize) * objectImageViewSizeMultiplier, uiGameObjectView.types.standard)
        uiGameObjectView:setObject(objectImageView, objectInfo, nil, nil)
    end
        ]]
        
        local logoHalfSize = normalSize * 0.4 * 0.5
    
        --uiGameObjectView:setSize(gameObjectView, vec2(logoHalfSize,logoHalfSize) * 2.5)

        local infoToAdd = {
            uniqueID = uniqueID,
            viewID = viewID,
            view = view,
            backgroundView = backgroundView,
            assignedSapienView = assignedSapienView,
            manuallyPrioritizedView = manuallyPrioritizedView,
            assignedSapienInfos = planInfo.assignedSapienInfos,
            manuallyPrioritized = planInfo.manuallyPrioritized,
            isDestructive = planInfo.isDestructive,
            selected = false,
            mouseDown = false,
            hasImpossiblePlan = planInfo.hasImpossiblePlan,
            disabledDueToOrderLimit = planInfo.disabledDueToOrderLimit,
            maintainQuantityThresholdMet = planInfo.maintainQuantityThresholdMet,
            hasMaintainQuantitySet = planInfo.hasMaintainQuantitySet,
            iconObjectTypeIndex = planInfo.iconObjectTypeIndex,
            planTypeIndex = planInfo.planTypeIndex,
            currentScale = 0.5,
            goalScale = 1.0,
            currentSize = normalSize * 0.5,
            differenceVelocity = 0.0,
            isClose = true,
            extraYOffset = extraYOffset,
            attachBoneName = planInfo.attachBoneName,
        }

        markerViewInfosByID[uniqueID] = infoToAdd

        if vertID then
            terrainMarkerObjectIDsByVertID[vertID] = uniqueID
        end
        
        if hoverMarkerID == uniqueID then
            markerViewInfosByID[uniqueID].selected = true
        end
        

        local functionAdded = false

        local function updateSize()
            local info = markerViewInfosByID[uniqueID]
            local scaleToUse = info.currentSize * 0.5
            info.backgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
            info.backgroundView.size = vec2(info.currentSize, info.currentSize)
            logoHalfSize = info.currentSize * 0.4 * 0.5
            if info.icon then
                info.icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
                info.icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0
            end
            if info.gameObjectView then
                uiGameObjectView:setSize(info.gameObjectView, vec2(logoHalfSize,logoHalfSize) * 2.5)
            end
            
            info.view.baseOffset = vec3(0.0,normalSize * 0.5 + info.currentScale * info.extraYOffset,0.0)
            
            updateAssignedSapienViewSize(info)
            updateManuallyPrioritzedViewSize(info)
        end

        local function updateFunction(dt)
            local info = markerViewInfosByID[uniqueID]
            if (info.selected or info.isClose) and ((not approxEqual(info.goalScale, info.currentScale)) or (not approxEqual(info.differenceVelocity, 0.0))) then
                local difference = info.goalScale - info.currentScale
                local clampedDT = mjm.clamp(dt * 40.0, 0.0, 1.0)
                info.differenceVelocity = info.differenceVelocity * math.max(1.0 - dt * 20.0, 0.0) + (difference * clampedDT)
                info.currentScale = info.currentScale + info.differenceVelocity * dt * 12.0
                if info.hasImpossiblePlan then
                    info.currentSize = warningSize * info.currentScale
                else
                    info.currentSize = normalSize * info.currentScale
                end
                updateSize()
            else
                functionAdded = false
                backgroundView.update = nil
            end
        end

        infoToAdd.addUpdateFunction = function()
            if not functionAdded then
                functionAdded = true
                backgroundView.update = updateFunction
            end
        end
        
        updateMarker(markerViewInfosByID[uniqueID])

        
        
        backgroundView.hoverStart = function ()
            localPlayer:markerLookAtStarted(uniqueID, worldView.pos, vertID)
        end
        backgroundView.hoverEnd = function ()
            localPlayer:markerLookAtEnded(uniqueID)
        end
        
        backgroundView.mouseDown = function (buttonIndex)
            localPlayer:markerClick(uniqueID, buttonIndex)
        end

        worldUIViewManager:addDistanceCallback(viewID, dotDistance, function(newIsClose)
            local info = markerViewInfosByID[uniqueID]
            if info then
                if info.isClose ~= newIsClose then
                    info.isClose = newIsClose
                    if newIsClose then
                        local scaleToUse = info.currentSize * 0.5
                        info.backgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
                        info.backgroundView.size = vec2(info.currentSize, info.currentSize)
                    elseif not info.selected then
                        local scaleToUse = smallSize
                        info.backgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
                        info.backgroundView.size = vec2(scaleToUse * 2.0, scaleToUse * 2.0)
                    end
                    updateMarker(info)
                end
            end
        end)
    end
end

function planMarkersUI:removePlan(planInfo)
    removeMarker(planInfo.uniqueID)
end

function planMarkersUI:init(localPlayer_)
    localPlayer = localPlayer_
end

function planMarkersUI:setHoverMarker(uniqueID)
    if hoverMarkerID ~= uniqueID then
        if hoverMarkerID then
            local markerViewInfo = markerViewInfosByID[hoverMarkerID]
            if markerViewInfo then
                markerViewInfo.selected = false
                if not markerViewInfo.isClose then
                    local scaleToUse = smallSize
                    markerViewInfo.backgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
                    markerViewInfo.backgroundView.size = vec2(scaleToUse * 2.0, scaleToUse * 2.0)
                end
                updateMarker(markerViewInfo)
            end
        end
        
        hoverMarkerID = uniqueID

        if uniqueID then
            local markerViewInfo = markerViewInfosByID[uniqueID]
            if markerViewInfo then
                markerViewInfo.selected = true
                updateMarker(markerViewInfo)
            end
        end
    end
end

function planMarkersUI:setTerrainHoverMarkerByVertID(vertID)
    if terrainMarkerObjectIDsByVertID[vertID] then
        planMarkersUI:setHoverMarker(terrainMarkerObjectIDsByVertID[vertID])
    else
        planMarkersUI:setHoverMarker(nil)
    end
end

return planMarkersUI