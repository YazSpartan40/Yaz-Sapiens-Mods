local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local approxEqual = mjm.approxEqual
local approxEqualEpsilon = mjm.approxEqualEpsilon

local model = mjrequire "common/model"
local timer = mjrequire "common/timer"

local actionUI = mjrequire "mainThread/ui/actionUI"
local lookAtUI = mjrequire "mainThread/ui/lookAtUI"
local inspectUI = mjrequire "mainThread/ui/inspect/inspectUI"
local multiSelectUI = mjrequire "mainThread/ui/multiSelectUI"
local manageButtonsUI = mjrequire "mainThread/ui/manageButtonsUI"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"

local logicInterface = mjrequire "mainThread/logicInterface"
local planHelper = mjrequire "common/planHelper"

local hubUI = {}

local hubModes = mj:enum {
    "out",
    "lookAt",
    "inspect",
    "multiSelect",
}

local world = nil
local localPlayer = nil

local backgroundView = nil
local currentMode = hubModes.out


local lookAtAlpha = 0.9
local hiddenAlpha = 0.0
local inspectAlpha = 1.0
local currentAlpha = hiddenAlpha
--local lookAtHideShouldDelay = true

local lookAtShouldBeVisible = false
local inspectShouldBeVisible = false
local multiSelectShouldBeVisible = false

local manageUIVisble = false

local lookAtShowInfo = nil
local inspectShowInfo = nil
local multiSelectShowInfo = nil

--[[local function getOffsetForMode(mode)
    if mode == hubModes.out then
        return hiddenOffset
    elseif mode == hubModes.lookAt then
        return lookAtOffset
    end

    return inspectOffset
end]]

local function getAlphaForMode(mode)
    if mode == hubModes.out then
        return hiddenAlpha
    elseif mode == hubModes.lookAt then
        return lookAtAlpha
    end

    return inspectAlpha
end

local inspectObjectImageView = nil

function hubUI:setLocalPlayer(localPlayer_)
    localPlayer = localPlayer_
end

function hubUI:init(gameUI, manageUI, world_)
    world = world_

    backgroundView = View.new(gameUI.view)
    backgroundView.size = gameUI.view.size
    backgroundView.baseOffset = vec3(0,0, 0)
    backgroundView.hidden = true
    backgroundView.alpha = currentAlpha
    backgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)

    
    local circleView = ModelView.new(backgroundView)
    circleView:setModel(model:modelIndexForName("ui_circleBackgroundLarge"))

    local lookAtCircleViewSize = 60.0
    local lookAtCircleViewOffset = vec3(10,10, 0)
    local lookAtInfoViewOffset = vec3(-lookAtCircleViewSize * 0.56,-1, -1)

    local inspectCircleSize = 200.0
    local inspectCircleViewOffset = vec3(10,10, 0)
    local inspectInfoViewOffset = vec3(-inspectCircleSize * 0.56,-1, -1)

    local objectImageViewSizeMultiplier = 0.97

    local lookAtCircleBackgroundScale = lookAtCircleViewSize * 0.5
    circleView.scale3D = vec3(lookAtCircleBackgroundScale,lookAtCircleBackgroundScale,lookAtCircleBackgroundScale)
    circleView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    circleView.size = vec2(lookAtCircleViewSize, lookAtCircleViewSize)
    circleView.baseOffset = lookAtCircleViewOffset

    inspectObjectImageView = uiGameObjectView:create(circleView, vec2(inspectCircleSize, inspectCircleSize) * objectImageViewSizeMultiplier, uiGameObjectView.types.standard) --create with large size so large backing texture is used
    uiGameObjectView:setSize(inspectObjectImageView, circleView.size * objectImageViewSizeMultiplier) --resize to lookat size
    
    local infoView = ModelView.new(backgroundView)
    infoView:setModel(model:modelIndexForName("ui_panel_10x2"))
    infoView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionBottom)
    infoView.relativeView = circleView
    infoView.baseOffset = lookAtInfoViewOffset
    
    lookAtUI:init(gameUI, world, backgroundView, circleView, infoView)
    inspectUI:load(gameUI, manageButtonsUI, hubUI, manageUI, world, backgroundView, circleView, inspectObjectImageView, infoView)
    multiSelectUI:init(gameUI, actionUI, hubUI, world, backgroundView)
    actionUI:init(gameUI, hubUI, world)
    manageButtonsUI:init(gameUI, manageUI, hubUI, world)

    backgroundView.update = function(dt)

        if inspectShouldBeVisible or lookAtShouldBeVisible then
            local desiredCircleSize = lookAtCircleViewSize
            local desiredCircleOffset = lookAtCircleViewOffset
            local desiredInfoOffset = lookAtInfoViewOffset
            if inspectShouldBeVisible then
                desiredCircleSize = inspectCircleSize
                desiredCircleOffset = inspectCircleViewOffset
                desiredInfoOffset = inspectInfoViewOffset
            end
            if not approxEqualEpsilon(desiredCircleSize, circleView.size.x, 2) then
                local mixValue = math.min(dt * 20.0, 1.0)
                circleView.size = circleView.size + (vec2(desiredCircleSize,desiredCircleSize) - circleView.size) * mixValue
                circleView.baseOffset = circleView.baseOffset + (desiredCircleOffset - circleView.baseOffset) * mixValue
                infoView.baseOffset = infoView.baseOffset + (desiredInfoOffset - infoView.baseOffset) * mixValue
                if approxEqualEpsilon(desiredCircleSize, circleView.size.x, 2) then
                    circleView.size = vec2(desiredCircleSize,desiredCircleSize)
                    circleView.baseOffset = desiredCircleOffset
                    infoView.baseOffset = desiredInfoOffset
                end
                local newBackgroundScale = vec2(circleView.size.x * 0.5, circleView.size.y * 0.5)
                circleView.scale3D = vec3(newBackgroundScale.x, newBackgroundScale.y, circleView.scale3D.z)
                uiGameObjectView:setSize(inspectObjectImageView, circleView.size * objectImageViewSizeMultiplier)
            end
        end

        --[[local goalOffset = getOffsetForMode(currentMode)
        local minDistance = 0.001
        if math.abs(goalOffset - currentOffset) > minDistance then
            currentOffset = currentOffset + (goalOffset - currentOffset) * math.min(dt * 15.0, 1.0)
            backgroundView.baseOffset = vec3(0,backgroundScale * currentOffset, 0)
        else
            if not approxEqual(goalOffset, currentOffset) then
                currentOffset = goalOffset
                backgroundView.baseOffset = vec3(0,backgroundScale * currentOffset, 0)
            end
        end]]
        
        
        local goalAlpha = getAlphaForMode(currentMode)
        local minAlphaDistance = 0.01
        if math.abs(goalAlpha - currentAlpha) > minAlphaDistance then
            
           -- if currentMode ~= hubModes.out or shouldFadeOut or (not lookAtHideShouldDelay) then
                currentAlpha = currentAlpha + (goalAlpha - currentAlpha) * math.min(dt * 10.0, 1.0)
                backgroundView.alpha = currentAlpha
           -- end
        else
            if not approxEqual(goalAlpha, currentAlpha) then
                currentAlpha = goalAlpha
                backgroundView.alpha = currentAlpha
            end
            
            if currentMode == hubModes.out then
                if approxEqual(0.0, currentAlpha) then
                    backgroundView.hidden = true
                end
            end
        end
        
    end
end

local function showActionUI(isTerrain, baseObjectOrVert, allObjectsOrVerts, lookAtPosition)
    local availablePlans = nil
    if isTerrain then
        availablePlans = planHelper:availablePlansForVertInfos(baseObjectOrVert, allObjectsOrVerts, world.tribeID)
    else
        --mj:log("calling planHelper:availablePlansForObjectInfos via showActionUI allObjectsOrVerts:", allObjectsOrVerts)
        availablePlans = planHelper:availablePlansForObjectInfos(baseObjectOrVert, allObjectsOrVerts, world.tribeID)
    end
    --mj:log("availablePlans:", availablePlans, " allObjectsOrVerts:", allObjectsOrVerts)
    if availablePlans and #availablePlans > 0 then
        if isTerrain then
            actionUI:showTerrain(baseObjectOrVert, allObjectsOrVerts, lookAtPosition)
        else
            actionUI:showObjects(baseObjectOrVert, allObjectsOrVerts, lookAtPosition)
        end
    end
end

local prevLookAtShowInfo = nil
local prevInspectShowInfo = nil

local function updateMode()
    local function setToOutMode()
        if currentMode ~= hubModes.out then
           --shouldFadeOut = true
            lookAtUI:hide()
            inspectUI:hideIfNeeded()
            multiSelectUI:hide()
            currentMode = hubModes.out
            timer:addCallbackTimer(0.05, function()
                if currentMode == hubModes.out then
                    logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", nil)
                end
            end)
            --logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", nil) --commented out 29/5 and use callback instead, causes a flash when changing an object type eg. issue order for removal of built objects
            --mj:error("clear b")
        end
    end

    if manageUIVisble then
        setToOutMode()
    elseif multiSelectShouldBeVisible then
        if currentMode ~= hubModes.multiSelect then
            backgroundView.hidden = true
            lookAtUI:hide()
            inspectUI:hideIfNeeded()
            currentMode = hubModes.multiSelect
        end
        if multiSelectShowInfo then
            multiSelectUI:show(multiSelectShowInfo.baseObjectOrVertInfo, multiSelectShowInfo.isTerrain, multiSelectShowInfo.playerPosition, multiSelectShowInfo.lookAtPosition)
            multiSelectShowInfo = nil
        end
    elseif inspectShouldBeVisible then
        if currentMode ~= hubModes.inspect then
            backgroundView.hidden = false
            lookAtUI:hide()
            multiSelectUI:hide()
            currentMode = hubModes.inspect
        end

        if inspectShowInfo then
            local allObjectsOrVerts = inspectShowInfo.multiObjectsOrVertsOrNil
            if not allObjectsOrVerts then
                allObjectsOrVerts = {inspectShowInfo.baseObjectOrVert}
            end
            inspectUI:show(inspectShowInfo.baseObjectOrVert, allObjectsOrVerts, inspectShowInfo.isTerrain)


            if not inspectUI:hasUIPanelDisplayed() then
                showActionUI(inspectShowInfo.isTerrain, inspectShowInfo.baseObjectOrVert, allObjectsOrVerts, inspectShowInfo.lookAtPosition)
            end

            if not inspectShowInfo.isTerrain then --todo
                local allObjectIDs = {}
                for i,objectInfo in ipairs(allObjectsOrVerts) do
                    allObjectIDs[i] = objectInfo.uniqueID
                end
                if inspectShowInfo.shouldHighlightSelection then
                    logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", {
                        objectIDs = allObjectIDs,
                        brightness = 0.1,
                    })
                    --mj:log("setSelectionHightlightForObjects:", allObjectIDs)
                else
                   -- mj:log("clear a")
                    logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", nil)
                end
            end
            prevInspectShowInfo = inspectShowInfo
            inspectShowInfo = nil
        end
    elseif lookAtShouldBeVisible then
        if currentMode ~= hubModes.lookAt then
            backgroundView.hidden = false
            inspectUI:hideIfNeeded()
            multiSelectUI:hide()
            currentMode = hubModes.lookAt
        end
        if lookAtShowInfo then
            lookAtUI:show(lookAtShowInfo.retrievedObjectResponse, lookAtShowInfo.isTerrain)
            if not lookAtShowInfo.isTerrain then
                uiGameObjectView:setObject(inspectObjectImageView, lookAtShowInfo.retrievedObjectResponse, nil, nil)
                inspectObjectImageView.hidden = false
            else
               -- mj:log("terrain lookAtShowInfo:", lookAtShowInfo)
                local materialIndex = lookAtShowInfo.retrievedObjectResponse.material
                local modelMaterialRemapTable = {
                    default = materialIndex
                }

                uiGameObjectView:setModelName(inspectObjectImageView, "icon_terrain", modelMaterialRemapTable)
                inspectObjectImageView.hidden = false
            end
            if not lookAtShowInfo.isTerrain and lookAtShowInfo.shouldHighlightSelection then
                logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", {
                    objectIDs = {lookAtShowInfo.retrievedObjectResponse.uniqueID},
                    brightness = 0.1,
                })
               -- mj:log("setSelectionHightlightForObjects b:", lookAtShowInfo.retrievedObjectResponse.uniqueID)
            else
                --mj:log("clear c")
                logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", nil)
            end
            prevLookAtShowInfo = lookAtShowInfo
            lookAtShowInfo = nil
        end
    else
        setToOutMode()
    end
end

function hubUI:setLookAtInfo(retrievedObjectResponse, isTerrain, shouldHighlightSelection)

    local validForDisplay = (retrievedObjectResponse ~= nil)
    if validForDisplay then
        if isTerrain and not retrievedObjectResponse.baseType then
            validForDisplay = false
        end
    end

    if validForDisplay then
       --mj:debug("setLookAtInfo to visible true")
        backgroundView.hidden = false
        lookAtShouldBeVisible = true
        lookAtShowInfo = {
            retrievedObjectResponse = retrievedObjectResponse, 
            isTerrain = isTerrain,
            shouldHighlightSelection = shouldHighlightSelection,
        }
        updateMode()
    else
        --mj:log("setLookAtInfo to not visible")
        lookAtShouldBeVisible = false
        --lookAtHideShouldDelay = true
        updateMode()
    end
end

local markerObjectWaitingForBaseObjectID = nil

function hubUI:showInspectUI(baseObjectOrVert, multiObjectsOrVertsOrNil, isTerrain)


    local function doShow(baseObjectOrVertToUse, multiObjectsOrVertsOrNilToUse)
        backgroundView.hidden = false
        inspectShouldBeVisible = true
        inspectShowInfo = {
            baseObjectOrVert = baseObjectOrVertToUse, 
            multiObjectsOrVertsOrNil = multiObjectsOrVertsOrNilToUse,
            isTerrain = isTerrain,
            shouldHighlightSelection = true,
        }
        updateMode()
    end

    local baseObjectSharedState = baseObjectOrVert.sharedState
    if baseObjectSharedState and baseObjectSharedState.haulObjectID then
        markerObjectWaitingForBaseObjectID = baseObjectSharedState.haulObjectID
        logicInterface:callLogicThreadFunction("retrieveObject", baseObjectSharedState.haulObjectID, function(retrievedObjectInfo)
            if retrievedObjectInfo.found then
                if markerObjectWaitingForBaseObjectID == retrievedObjectInfo.uniqueID then
                    doShow(retrievedObjectInfo, nil) --todo support multi-select for markers. need to retrieve all object infos, not pass nil
                    markerObjectWaitingForBaseObjectID = nil
                end
            end
        end)
    else
        --mj:log("show:", baseObjectOrVert)
        doShow(baseObjectOrVert, multiObjectsOrVertsOrNil)
    end
    
end

function hubUI:updateInspectUIIfVisible(baseObjectOrVert, multiObjectsOrVertsOrNil, lookAtPosition, isTerrain)
    if inspectShouldBeVisible and not backgroundView.hidden then
        
        local function doUpdate(baseObjectOrVertToUse, multiObjectsOrVertsOrNilToUse)
            inspectShowInfo = {
                baseObjectOrVert = baseObjectOrVertToUse, 
                multiObjectsOrVertsOrNil = multiObjectsOrVertsOrNilToUse,
                isTerrain = isTerrain,
                shouldHighlightSelection = true,
            }
            updateMode()
        end
        

        local baseObjectSharedState = baseObjectOrVert.sharedState
        if baseObjectSharedState and baseObjectSharedState.haulObjectID then
            markerObjectWaitingForBaseObjectID = baseObjectSharedState.haulObjectID
            logicInterface:callLogicThreadFunction("retrieveObject", baseObjectSharedState.haulObjectID, function(retrievedObjectInfo)
                if retrievedObjectInfo.found then
                    if markerObjectWaitingForBaseObjectID == retrievedObjectInfo.uniqueID then
                        doUpdate(retrievedObjectInfo, nil) --todo support multi-select for markers. need to retrieve all object infos, not pass nil
                        markerObjectWaitingForBaseObjectID = nil
                    end
                end
            end)
        else
            --mj:log("doUpdate:", baseObjectOrVert)
            doUpdate(baseObjectOrVert, multiObjectsOrVertsOrNil)
        end
    end
end

function hubUI:hideInspectUI(shouldAnimateActionUI)
    if inspectShouldBeVisible then
        inspectShouldBeVisible = false
        if not actionUI:hidden() then
            if shouldAnimateActionUI then
                actionUI:animateOut(nil, nil)
            else
                actionUI:hide()
            end
            localPlayer:stopFollowingObject() -- added to prevent needing to press escape twice when actionUI visible and is following object.
            localPlayer:resetControllerMovementInput()
        end
        updateMode()
    end
end

function hubUI:inspectUIIsDisplayed()
    return (not inspectUI:hidden())-- or (actionUI:hidden() or actionUI:isAnimatingOut()) --commentd out as it's a port from old api and may be required, but hopefully not
end

function hubUI:currentLookAtObjectInfo()
end

function hubUI:popInspectUI()
    if not inspectUI:popUI() then
        hubUI:hideInspectUI(true)
    end
end


function hubUI:showMultiSelectUI(baseObjectOrVertInfo, isTerrain, playerPosition, lookAtPosition)
    actionUI:hide()
    backgroundView.hidden = false
    multiSelectShouldBeVisible = true
    multiSelectShowInfo = {
        baseObjectOrVertInfo = baseObjectOrVertInfo, 
        isTerrain = isTerrain,
        playerPosition = playerPosition,
        lookAtPosition = lookAtPosition,
    }
    updateMode()
    --multiSelectUI:showObject(baseObjectInfo, playerPosition, lookAtPosition)
end

function hubUI:hideActionUIForInspectPanelDisplay()
    actionUI:hide()
end

function hubUI:showActionUIForInspectPanelHidden()
    actionUI:show()
end

function hubUI:showTasksForCurrentSapien(backFunction)
    inspectUI:showTasksForCurrentSapien(backFunction)
end

function hubUI:actionShortcut(baseObjectOrVert, multiObjectsOrVertsOrNil, lookAtPosition, isTerrain, actionIndex, shouldAutomateOrOpenOptions)
    if not baseObjectOrVert then
        return
    end
    
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, multiObjectsOrVertsOrNil, isTerrain)
    end
    actionUI:selectButtonAtIndex(actionIndex, shouldAutomateOrOpenOptions)
end


function hubUI:zoomShortcut(baseObjectOrVert, lookAtPosition, isTerrain)
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, nil, isTerrain)
    end
    actionUI:zoomShortcut()
end


function hubUI:multiselectShortcut(baseObjectOrVert, lookAtPosition, isTerrain)
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, nil, isTerrain)
    end
    actionUI:multiselectShortcut()
end

function hubUI:deconstructShortcut(baseObjectOrVert, multiObjectsOrVertsOrNil, lookAtPosition, isTerrain, shouldAutomateOrOpenOptions)
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, multiObjectsOrVertsOrNil, isTerrain)
    end
    actionUI:selectDeconstructAction(shouldAutomateOrOpenOptions)
end

function hubUI:cloneShortcut(baseObjectOrVert, multiObjectsOrVertsOrNil, lookAtPosition, isTerrain, shouldAutomateOrOpenOptions)
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, multiObjectsOrVertsOrNil, isTerrain)
    end
    actionUI:selectCloneAction(shouldAutomateOrOpenOptions)
end

function hubUI:chopReplantShortcut(baseObjectOrVert, multiObjectsOrVertsOrNil, lookAtPosition, isTerrain, shouldAutomateOrOpenOptions)
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, multiObjectsOrVertsOrNil, isTerrain)
    end
    actionUI:selectChopReplantAction(shouldAutomateOrOpenOptions)
end

function hubUI:investigateShortcut(baseObjectOrVert, multiObjectsOrVertsOrNil, lookAtPosition, isTerrain, shouldAutomateOrOpenOptions)
    if not inspectShouldBeVisible or (not inspectUI.baseObjectOrVertInfo) or inspectUI.baseObjectOrVertInfo.uniqueID ~= baseObjectOrVert.uniqueID then
        hubUI:showInspectUI(baseObjectOrVert, multiObjectsOrVertsOrNil, isTerrain)
    end
    actionUI:selectInvestigateAction(shouldAutomateOrOpenOptions)
end


--[[function hubUI:handleEnterPress()
    if not multiSelectUI:hidden() then
        multiSelectUI:enterPressed()
        return true
    end
    return false
end]]

function hubUI:canShowInvasivePopup()
    if not hubUI:multiSelectUIHidden() then
        return false
    end
    if hubUI:inspectUIIsDisplayed() then
        return false
    end
    return true
end

function hubUI:popUI()
    if not hubUI:multiSelectUIHidden() then
        lookAtShowInfo = prevLookAtShowInfo
        inspectShowInfo = prevInspectShowInfo
        hubUI:hideMultiSelectUI()
        return true
    elseif hubUI:inspectUIIsDisplayed() then
        hubUI:popInspectUI()
        return true
    end
    return false
end

function hubUI:hideAllModalUI(shouldAnimateActionUI)
    hubUI:hideMultiSelectUI()
    if inspectUI:hasUIPanelDisplayed() then
        inspectUI:hideUIPanel(true)
    end
    hubUI:hideInspectUI(shouldAnimateActionUI)
end

function hubUI:hideAllUI(shouldAnimateActionUI)
    --mj:log("hubUI:hideAllUI")
    hubUI:hideAllModalUI(shouldAnimateActionUI)

    lookAtShouldBeVisible = false
    --lookAtHideShouldDelay = false
    updateMode()
end


function hubUI:setManageUIVisible(manageUIVisble_)
    if manageUIVisble ~= manageUIVisble_ then
        manageUIVisble = manageUIVisble_
        if manageUIVisble then
            hubUI:hideAllUI(false)
        end
        updateMode()
    end
end

function hubUI:multiSelectUIHidden()
    return multiSelectUI:hidden()
end

function hubUI:anyModalUIIsDisplayed()
    return multiSelectShouldBeVisible or inspectShouldBeVisible
end

function hubUI:hideMultiSelectUI()
    if multiSelectShouldBeVisible then
        multiSelectShouldBeVisible = false
        updateMode()
    end
    --multiSelectUI:hide()
end

return hubUI