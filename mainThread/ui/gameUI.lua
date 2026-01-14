local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local normalize = mjm.normalize
local length = mjm.length
local vec3xMat3 = mjm.vec3xMat3
local mat3LookAtInverse = mjm.mat3LookAtInverse
local mat3Inverse = mjm.mat3Inverse

local gameObject = mjrequire "common/gameObject"
local gameConstants = mjrequire "common/gameConstants"
local playerSapiens = mjrequire "mainThread/playerSapiens"
--local planHelper = mjrequire "common/planHelper"
--local plan = mjrequire "common/plan"
local musicPlayer = mjrequire "mainThread/musicPlayer"
--local biomeTypes = mjrequire "common/biomeTypes"

local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
local intro = mjrequire "mainThread/intro"
local gameFailSequence = mjrequire "mainThread/gameFailSequence"
local audio = mjrequire "mainThread/audio"
local storyPanel = mjrequire "mainThread/storyPanel"
local mainThreadDestination = mjrequire "mainThread/mainThreadDestination"
local pointAndClickCamera = mjrequire "mainThread/pointAndClickCamera"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local hubUI = mjrequire "mainThread/ui/hubUI"
local lookAtTerrainMesh = mjrequire "mainThread/ui/lookAtTerrainMesh"
local debugUI = mjrequire "mainThread/ui/debugUI"
local cinematicCameraUI = mjrequire "mainThread/ui/cinematicCameraUI"
local buildModeInteractUI = mjrequire "mainThread/ui/buildModeInteractUI"
local sapienMoveUI = mjrequire "mainThread/ui/sapienMoveUI"
local objectMoveUI = mjrequire "mainThread/ui/objectMoveUI"
local changeAssignedSapienUI = mjrequire "mainThread/ui/changeAssignedSapienUI"
local storageLogisticsDestinationsUI = mjrequire "mainThread/ui/storageLogisticsDestinationsUI"
local chatMessageUI = mjrequire "mainThread/ui/chatMessageUI"
local notificationsUI = mjrequire "mainThread/ui/notificationsUI"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local manageUI = mjrequire "mainThread/ui/manageUI/manageUI"
local constructableUIHelper = mjrequire "mainThread/ui/constructableUIHelper"
local logicInterface = mjrequire "mainThread/logicInterface"
local tribeSelectionMarkersUI = mjrequire "mainThread/ui/tribeSelectionMarkersUI"
local interestMarkersUI = mjrequire "mainThread/ui/interestMarkersUI"
local tribeSelectionUI = mjrequire "mainThread/ui/tribeSelectionUI"
local terminal = mjrequire "mainThread/ui/terminal"
local discoveryUI = mjrequire "mainThread/ui/discoveryUI"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"
local tutorialStoryPanel = mjrequire "mainThread/ui/tutorialStoryPanel"
local timeControls = mjrequire "mainThread/ui/timeControls"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local contextualTipUI = mjrequire "mainThread/ui/contextualTipUI"
local mapModeUI = mjrequire "mainThread/ui/mapModeUI"
local pauseUI = mjrequire "mainThread/ui/pauseUI"
local cinematicCamera = mjrequire "mainThread/cinematicCamera"
local warningNoticeUI = mjrequire "mainThread/ui/warningNoticeUI"
local questUIHelper = mjrequire "mainThread/ui/questUIHelper"
local resourcesUI = mjrequire "mainThread/ui/manageUI/resourcesUI"
local manageButtonsUI = mjrequire "mainThread/ui/manageButtonsUI"

local actionUI = mjrequire "mainThread/ui/actionUI"

local gameUI = {
    view = nil,
    worldViews = nil,
}

local localPlayer = nil
--local keyDownLookAtId = nil
local world = nil
local controller = nil
local worldHasLoaded = false

local crosshairsView = nil

--local hideUITimer = nil
local uihiddenDueToInactivity = false


local currentRetrievedObjectResponse = nil
local currentRetrievedObjectIsTerrain = false



local function setUIHiddenDueToInactivity(newUIhiddenDueToInactivity)
    if newUIhiddenDueToInactivity ~= uihiddenDueToInactivity then
        uihiddenDueToInactivity = newUIhiddenDueToInactivity
        logicInterface:callLogicThreadFunction("setUIHiddenDueToInactivity", uihiddenDueToInactivity)
    end
end

local function startButtonPressed()
    if world:isPaused() then
        gameUI:popUI(false, false)
        gameUI:updateUIHidden()
       --[[ if not manageUI:hidden() then
            manageUI:hide()
        end]]
		world:setPlay()
    else
        localPlayer:stopFollowingObject()

        if uihiddenDueToInactivity then
            setUIHiddenDueToInactivity(false)
            gameUI:updateUIHidden()
        end

        gameUI:popUI(false, false)
        world:setPaused()

        mj:log("startButton gameUI.view.hidden:", gameUI.view.hidden, " gameUI.worldViews.hidden:", gameUI.worldViews.hidden, " gameUI:hasUIPanelDisplayed():", gameUI:hasUIPanelDisplayed())

        if playerSapiens:hasFollowers() and (not gameUI.view.hidden) and (not gameUI.worldViews.hidden) and (not gameUI:isMapMode()) then
            if not gameUI:hasUIPanelDisplayed() then
                manageUI:show(manageUI.modeTypes.options)
            end
        end
    end
end


function gameUI:modalMoveOrBuildLikeUIIsVisible()
    --[[mj:log("gameUI:hasUIPanelDisplayeda:", gameUI:hasUIPanelDisplayed(true),
"\nsapienMoveUI:hidden():", sapienMoveUI:hidden(),
"\nobjectMoveUI:hidden():", objectMoveUI:hidden(),
"\nstorageLogisticsDestinationsUI:hidden():", storageLogisticsDestinationsUI:hidden(),
"\nchangeAssignedSapienUI:hidden():", changeAssignedSapienUI:hidden(),
"\nbuildModeInteractUI:hidden():", buildModeInteractUI:hidden(),
"\nplayerSapiens:hasFollowers():", playerSapiens:hasFollowers(),
"\nresult:", gameUI:isMapMode() or gameUI:hasUIPanelDisplayed(true) or
(not (sapienMoveUI:hidden() and objectMoveUI:hidden() and storageLogisticsDestinationsUI:hidden() and changeAssignedSapienUI:hidden() and buildModeInteractUI:hidden() and playerSapiens:hasFollowers())))]]

    return gameUI:isMapMode() or gameUI:hasUIPanelDisplayed(true) or
    (not (sapienMoveUI:hidden() and objectMoveUI:hidden() and storageLogisticsDestinationsUI:hidden() and changeAssignedSapienUI:hidden() and buildModeInteractUI:hidden() and playerSapiens:hasFollowers()))
end

function gameUI:updateWarningNoticeForTopPanelDisplayed(topOffsetForWarningNotice)
    warningNoticeUI:setTopOffset(topOffsetForWarningNotice)
end

function gameUI:updateWarningNoticeForTopPanelWillHide()
    warningNoticeUI:removeTopOffset()
end

--[[local function shouldHideWorldUIViewsDueToModalMoveOrBuildLikeUIIsVisible()
    return (not (sapienMoveUI:hidden() and objectMoveUI:hidden() and (buildModeInteractUI:hidden() or buildModeInteractUI:isFinalPositionMode()) and playerSapiens:hasFollowers())) -- storageLogisticsDestinationsUI:hidden() - tricky, this will hide the routes themselves
end]]

local function menuPressed(modeTypeOrNil)
    if (not gameUI:modalMoveOrBuildLikeUIIsVisible()) or (not manageUI:hidden()) then
        localPlayer:stopFollowingObject()

        if uihiddenDueToInactivity then
            setUIHiddenDueToInactivity(false)
            gameUI:updateUIHidden()
        end

        if not manageUI:hidden() then
            if ((not modeTypeOrNil) or modeTypeOrNil == manageUI:getCurrentModeIndex()) then
                manageUI:hide()
            else
                manageUI:show(modeTypeOrNil, nil)
            end
        else
            if (not gameUI.view.hidden) and (not gameUI.worldViews.hidden) then 
                --if not hubUI:handleEnterPress() then
                    if not gameUI:hasUIPanelDisplayed() then
                        manageUI:show(modeTypeOrNil, nil)
                        localPlayer:stopCinemaCamera()
                    end
            -- end
            end
        end
    end
end

local function escapePressed()

    if not playerSapiens:hasFollowers() then
        if not gameUI:popUI(false, false) then
            manageUI:showTribeSelectionSettingsMenu()
        end
    else
        if localPlayer.mapMode and tribeSelectionUI:hidden() then
            localPlayer:setMapMode(nil, false)
            return
        end

    -- local wasFollowing = localPlayer:isFollowingObject()
    -- localPlayer:stopFollowingObject()

        if not gameUI:popUI(false, false) then
            
            if uihiddenDueToInactivity then
                setUIHiddenDueToInactivity(false)
                gameUI:updateUIHidden()
            end

            if (not gameUI.view.hidden) and (not gameUI.worldViews.hidden) and (not gameUI:isMapMode()) then 
            --if not hubUI:handleEnterPress() then
                if not gameUI:hasUIPanelDisplayed() then
                    manageUI:show()
                    localPlayer:stopCinemaCamera()
                end
            -- end
            end
        end
    end
end

local function zoomToNotificationPressed()
    if playerSapiens:hasFollowers() and (not eventManager.textEntryListener) and (not gameUI:isMapMode()) and (not gameUI:hasUIPanelDisplayed()) then 
        local objectInfo = notificationsUI:getZoomInfoForTopNotification()
        if objectInfo then
            --mj:log("objectInfo:", objectInfo)
            logicInterface:callLogicThreadFunction("retrieveObject", objectInfo.uniqueID, function(retrievedObjectResponse)
                --mj:log("zoomToNotificationPressed retrievedObjectResponse:", retrievedObjectResponse)
                local objectInfoToUse = retrievedObjectResponse
                if not objectInfoToUse.found then
                    --mj:log("not found, using backup info:", objectInfo)
                    objectInfoToUse = objectInfo
                end
                --localPlayer:followObject(objectInfoToUse, false, objectInfoToUse.pos)
                gameUI:followObject(objectInfoToUse, false, {dismissAnyUI = true, showInspectUI = true})
                tutorialUI:setHasZoomedToNotification()
            end)
            return true
        end
    end
    return false
end

local radialMenuModKeyDown = false
local zoomModifierKeyDown = false
local multiselectModifierKeyDown = false

local function radialShortCutFunction(selectionIndex)
    if not manageUI:hidden() then
        manageUI:subTabSelectionShortcut(selectionIndex)
    else
        if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
            if (not gameUI.view.hidden) and (not gameUI.worldViews.hidden) then 
                localPlayer:stopFollowingObject()
                
                if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
                    hubUI:actionShortcut(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, false, selectionIndex, radialMenuModKeyDown)
                elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
                    hubUI:actionShortcut(localPlayer.retrievedLookAtTerrainVert, nil, localPlayer.lookAtPosition, true, selectionIndex, radialMenuModKeyDown)
                end
            end
        end
    end
end

local function zoomShortcut()
    if manageUI:hidden() then
        if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
            if (not gameUI.view.hidden) and (not gameUI.worldViews.hidden) then 
                localPlayer:stopFollowingObject()
                
                if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
                    hubUI:zoomShortcut(localPlayer.retrievedLookAtObject, localPlayer.lookAtPosition, false)
                elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
                    hubUI:zoomShortcut(localPlayer.retrievedLookAtTerrainVert, localPlayer.lookAtPosition, true)
                end
            end
        end
    end
end

local function multiselectShortcut()
    if manageUI:hidden() then
        if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
            if (not gameUI.view.hidden) and (not gameUI.worldViews.hidden) then 
                localPlayer:stopFollowingObject()
                
                if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
                    hubUI:multiselectShortcut(localPlayer.retrievedLookAtObject, localPlayer.lookAtPosition, false)
                elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
                    hubUI:multiselectShortcut(localPlayer.retrievedLookAtTerrainVert, localPlayer.lookAtPosition, true)
                end
            end
        end
    end
end

local function deconstructFunction()
    if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
        localPlayer:stopFollowingObject()
        
        if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
            hubUI:deconstructShortcut(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, false, radialMenuModKeyDown)
        elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
            hubUI:deconstructShortcut(localPlayer.retrievedLookAtTerrainVert, nil, localPlayer.lookAtPosition, true, radialMenuModKeyDown)
        end
    end
end

local function prioritizeKeyFunction()
    if not gameUI:modalMoveOrBuildLikeUIIsVisible() then

        local allObjectIDs = actionUI:getCurrentObjectOfVertIDs()
        if not allObjectIDs then
            if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
                allObjectIDs = {localPlayer.lookAtID}
            elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
                allObjectIDs = {localPlayer.retrievedLookAtTerrainVert.uniqueID}
            end
        end
        
        if allObjectIDs then
            logicInterface:callServerFunction("togglePlanPrioritization", {
                objectOrVertIDs = allObjectIDs,
            })
        end
    end
end

local function cloneFunction()
    if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
        localPlayer:stopFollowingObject()
        
        if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
            hubUI:cloneShortcut(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, false, radialMenuModKeyDown)
        elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
            hubUI:cloneShortcut(localPlayer.retrievedLookAtTerrainVert, nil, localPlayer.lookAtPosition, true, radialMenuModKeyDown)
        end
    end
end

local function radialMenuChopReplant()
    if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
        localPlayer:stopFollowingObject()
        
        if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
            hubUI:chopReplantShortcut(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, false, radialMenuModKeyDown)
        elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
            hubUI:chopReplantShortcut(localPlayer.retrievedLookAtTerrainVert, nil, localPlayer.lookAtPosition, true, radialMenuModKeyDown)
        end
    end
end

local function radialMenuInvestigate()
    if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
        localPlayer:stopFollowingObject()
        
        if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
            hubUI:investigateShortcut(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, false, radialMenuModKeyDown)
        elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and localPlayer.retrievedLookAtTerrainVert then
            hubUI:investigateShortcut(localPlayer.retrievedLookAtTerrainVert, nil, localPlayer.lookAtPosition, true, radialMenuModKeyDown)
        end
    end
end


local function debugKeyPressed()
    if currentRetrievedObjectResponse then
        gameUI:setDebugObject(currentRetrievedObjectResponse, currentRetrievedObjectIsTerrain)
    end
end

local measureStartPos = nil
local function measureDistanceKeyPressed()
    if localPlayer.lookAtPosition then
        if measureStartPos then
            local distance = length(localPlayer.lookAtPosition - measureStartPos)
            local result = string.format("\nDistance:%.3fm\nFirst point:%s (altitude:%.3f)\nSecond point:%s (altitude:%.3f)",
                mj:pToM(distance), 
                mj:tostring(measureStartPos), 
                mj:pToM(length(measureStartPos) - 1.0), 
                mj:tostring(localPlayer.lookAtPosition), 
                mj:pToM(length(localPlayer.lookAtPosition) - 1.0))
            terminal:show()
            mj.terminal:displayMessage(result)
            mj:log(result)
            measureStartPos = nil
        else
            measureStartPos = localPlayer.lookAtPosition
        end
    end
end

local keyMap = {
	--[keyMapping:getMappingIndex("game", "menu")] = function(isDown, isRepeat) if isDown and not isRepeat then menuPressed(nil) end return true end,
	[keyMapping:getMappingIndex("game", "buildMenu")] = function(isDown, isRepeat) if isDown and not isRepeat then menuPressed(manageUI.modeTypes.build) end return true end,
	[keyMapping:getMappingIndex("game", "buildMenu2")] = function(isDown, isRepeat) if isDown and not isRepeat then menuPressed(manageUI.modeTypes.build) end return true end,
	[keyMapping:getMappingIndex("game", "tribeMenu")] = function(isDown, isRepeat) if isDown and not isRepeat then menuPressed(manageUI.modeTypes.tribe) end return true end,
	--[keyMapping:getMappingIndex("game", "routesMenu")] = function(isDown, isRepeat) if isDown and not isRepeat then menuPressed(manageUI.modeTypes.storageLogistics) end return true end,
	[keyMapping:getMappingIndex("game", "settingsMenu")] = function(isDown, isRepeat) if isDown and not isRepeat then menuPressed(manageUI.modeTypes.options) end return true end,

    [keyMapping:getMappingIndex("game", "escape")] = function(isDown, isRepeat) if isDown and not isRepeat then escapePressed() end return true end,
	[keyMapping:getMappingIndex("game", "zoomToNotification")] = function(isDown, isRepeat) if isDown and not isRepeat then zoomToNotificationPressed() end return true end,
    
    [keyMapping:getMappingIndex("game", "speedFast")] = function(isDown, isRepeat) 
        if isDown and not isRepeat and world:hasSelectedTribeID() then 
            world:toggleFast() 
        end 
        return true 
    end,
    [keyMapping:getMappingIndex("game", "speedSlowMotion")] = function(isDown, isRepeat) 
        if isDown and not isRepeat and world:hasSelectedTribeID() then 
            world:toggleSlowMotion() 
        end 
        return true 
    end,
    [keyMapping:getMappingIndex("game", "pause")] = function(isDown, isRepeat)
         if isDown and not isRepeat and world:hasSelectedTribeID() then 
            world:togglePause() 
        end 
        return true 
    end,
    
    [keyMapping:getMappingIndex("game", "radialMenuShortcut1")] = function(isDown, isRepeat) if isDown and not isRepeat then radialShortCutFunction(1) end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuShortcut2")] = function(isDown, isRepeat) if isDown and not isRepeat then radialShortCutFunction(2) end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuShortcut3")] = function(isDown, isRepeat) if isDown and not isRepeat then radialShortCutFunction(3) end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuShortcut4")] = function(isDown, isRepeat) if isDown and not isRepeat then radialShortCutFunction(4) end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuShortcut5")] = function(isDown, isRepeat) if isDown and not isRepeat then radialShortCutFunction(5) end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuShortcut6")] = function(isDown, isRepeat) if isDown and not isRepeat then radialShortCutFunction(6) end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuDeconstruct")] = function(isDown, isRepeat) if isDown and not isRepeat then deconstructFunction() end return true end,
    [keyMapping:getMappingIndex("game", "prioritize")] = function(isDown, isRepeat) if isDown and not isRepeat then prioritizeKeyFunction() end return true end,
    
    [keyMapping:getMappingIndex("game", "radialMenuClone")] = function(isDown, isRepeat) if isDown and not isRepeat then cloneFunction() end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuChopReplant")] = function(isDown, isRepeat) if isDown and not isRepeat then radialMenuChopReplant() end return true end,
    [keyMapping:getMappingIndex("game", "radialMenuInvestigate")] = function(isDown, isRepeat) if isDown and not isRepeat then radialMenuInvestigate() end return true end,

    [keyMapping:getMappingIndex("game", "radialMenuAutomateModifier")] = function(isDown, isRepeat) radialMenuModKeyDown = isDown return false end,
    [keyMapping:getMappingIndex("game", "zoomModifier")] = function(isDown, isRepeat) zoomModifierKeyDown = isDown return false end,
    [keyMapping:getMappingIndex("game", "multiselectModifier")] = function(isDown, isRepeat) multiselectModifierKeyDown = isDown return false end,

    [keyMapping:getMappingIndex("game", "togglePointAndClick")] = function(isDown, isRepeat) if isDown and not isRepeat then 
        pointAndClickCamera:toggleEnabled() 
        buildModeInteractUI:pointAndClickModeWasToggled()
    end return true end,
    
    [keyMapping:getMappingIndex("debug", "setDebugObject")] = function(isDown, isRepeat) if isDown and not isRepeat then debugKeyPressed() end return true end,
    [keyMapping:getMappingIndex("debug", "measureDistance")] = function(isDown, isRepeat) if isDown and not isRepeat then measureDistanceKeyPressed() end return true end,
}

local function keyChanged(isDown, mapIndexes, isRepeat)
    if cinematicCamera:keyChanged(isDown, mapIndexes, isRepeat) then
        return true
    end
    --[[if not terminal.hidden then
        return
    end]]
    for i, mapIndex in ipairs(mapIndexes) do
        if keyMap[mapIndex]  then
            if keyMap[mapIndex](isDown, isRepeat) then
                return true
            end
        end
    end
    return false
end

function gameUI:showUIIfHiddenDueToInactivity()
    if uihiddenDueToInactivity then
        setUIHiddenDueToInactivity(false)
        gameUI:updateUIHidden()
    end
end

function gameUI:worldLoaded()
    worldHasLoaded = true
    if not world:hasSelectedTribeID() then
        intro:worldLoaded()
        gameFailSequence:worldLoaded()
    else
        musicPlayer:worldLoaded()
        tutorialUI:show()
    end
    gameUI:updateUIHidden()
end

function gameUI:getWorldHasLoaded()
    return worldHasLoaded
end


function gameUI:showTribeMenu()
    menuPressed(manageUI.modeTypes.tribe)
end

local keepWorldUIHiddenEvenIfTribeNotSelected = false -- urgh I don't know how to solve this better
function gameUI:setKeepWorldUIHiddenEvenIfTribeNotSelected(keepWorldUIHiddenEvenIfTribeNotSelected_)
    keepWorldUIHiddenEvenIfTribeNotSelected = keepWorldUIHiddenEvenIfTribeNotSelected_
    gameUI:updateUIHidden()
end

function gameUI:updateUIHidden()
    local uiHidden = uihiddenDueToInactivity or (not storyPanel:hidden()) or (not worldHasLoaded) or (not terminal.hidden)
    if uiHidden then
        gameUI.view.hidden = true
        lookAtTerrainMesh:hide()
    else
        gameUI.view.hidden = false
    end

    if storyPanel:hidden() or (not worldHasLoaded) then
        gameUI.storyView.hidden = true
    else
        gameUI.storyView.hidden = false
    end
    
    if tutorialUI:hidden() or (not worldHasLoaded) or uiHidden then
       -- mj:log("hide tips")
        gameUI.tipsView.hidden = true
    else
        --mj:log("show tips")
        gameUI.tipsView.hidden = false
    end

    local hideWorldUI = uiHidden
    local hideWorldViews = uiHidden
    
    --mj:error("gameUI:updateUIHidden:", uiHidden)
    local keepTransparentBuildObjectsVisible = false
    if not hideWorldUI then
        --local gameState = controller:getGameState()
        --[[if gameState == GameStateLoadedPaused then
            hideWorldUI = true
            hideWorldViews = true
            gameUI.view.hidden = true
            lookAtTerrainMesh:hide()
        else]]
            if localPlayer and localPlayer:isFollowingObject() then
                hideWorldUI = true
                hideWorldViews = true
                --mj:log("hideWorldViews b:", hideWorldViews)
            elseif not actionUI:hidden() then
                hideWorldUI = true
                keepTransparentBuildObjectsVisible = true
            elseif gameUI:hasUIPanelDisplayed() and (not gameUI:modalMoveOrBuildLikeUIIsVisible()) then
                hideWorldViews = true
                --mj:log("hideWorldViews c:", hideWorldViews)
                if (not hubUI:anyModalUIIsDisplayed()) then --and actionUI:hidden() then --commented out, not sure if needed
                    hideWorldUI = true
                end
            end
        --end
    end

    --[[if not hideWorldUI then
        hideWorldUI = shouldHideWorldUIViewsDueToModalMoveOrBuildLikeUIIsVisible()
    end]]

    if hideWorldUI then
        if (not world:hasSelectedTribeID()) and (not keepWorldUIHiddenEvenIfTribeNotSelected) then
            hideWorldUI = false --show tribe markers
        end
    end

    if hideWorldViews then
        gameUI.worldViews.hidden = true
    else
        gameUI.worldViews.hidden = false
    end

    --mj:log("set hideWorldUI:", hideWorldUI)
    --mj:log("set hideWorldViews:", hideWorldViews)

    worldUIViewManager:setHidden(hideWorldUI)

    world:setDisableTransparantBuildObjectRender(hideWorldUI and (not keepTransparentBuildObjectsVisible))
end

function gameUI:resizeCrosshairs()
    if crosshairsView then
        local sizeFraction = clientGameSettings.values.reticleSize
        local rampedValue = uiCommon:getCrosshairsScale(sizeFraction)
        crosshairsView.size = vec2(rampedValue,rampedValue)
    end
end

function gameUI:reloadCrosshairs(reticleType)
    if not world.isVR then
        local wasHidden = false
        if crosshairsView then
            wasHidden = crosshairsView.hidden
            gameUI.worldViews:removeSubview(crosshairsView)
        end

        crosshairsView = ImageView.new(gameUI.worldViews)
        local mipmap = true
        local imageName = uiCommon.reticleImagesByTypes[reticleType] or uiCommon.reticleImagesByTypes.dot
        crosshairsView.imageTexture = MJCache:getTexture(imageName, false, false, mipmap)
        crosshairsView.masksEvents = false
        crosshairsView.hidden = wasHidden
        gameUI:resizeCrosshairs()

    end
end

function gameUI:init(controller_, world_)
    world = world_
    controller = controller_

    local mainView = controller.mainView


    gameUI.view = View.new(mainView)
    gameUI.view.size = mainView.size
    
    gameUI.storyView = View.new(mainView)
    gameUI.storyView.size = mainView.size
    gameUI.storyView.hidden = true


    
    gameUI.tipsView = View.new(mainView)
    gameUI.tipsView.size = mainView.size
    gameUI.tipsView.hidden = true

    uihiddenDueToInactivity = false


    controller.mainView.update = function(dt)
        
        gameUI:update()
    end


    gameUI.worldViews = View.new(gameUI.view)
    gameUI.worldViews.size = mainView.size

    if not world.isVR then
        clientGameSettings:addObserver("reticleType", function(newValue)
            gameUI:reloadCrosshairs(newValue)
        end)
        clientGameSettings:addObserver("reticleSize", function(newValue)
            gameUI:resizeCrosshairs()
        end)
        gameUI:reloadCrosshairs(clientGameSettings.values.reticleType)
    else
        local scaleToUse = 2.0 / 1920.0
        controller.mainView.scale = scaleToUse
    end
    
    hubUI:init(gameUI, manageUI, world)
    debugUI:load(gameUI, controller, logicInterface)
    cinematicCameraUI:load(gameUI)
    buildModeInteractUI:init(gameUI, world)
    sapienMoveUI:load(gameUI)
    objectMoveUI:load(gameUI)
    changeAssignedSapienUI:load(gameUI)
    storageLogisticsDestinationsUI:load(gameUI, manageUI)
    chatMessageUI:load(gameUI, logicInterface)
    discoveryUI:load(gameUI, hubUI, world, notificationsUI)
    tribeRelationsUI:load(gameUI, hubUI, world, notificationsUI, logicInterface)
    tutorialStoryPanel:load(gameUI, hubUI, world)
    notificationsUI:load(gameUI, world, logicInterface)
    constructableUIHelper:init(world)
    manageUI:init(gameUI, controller, hubUI, world, logicInterface)
    timeControls:init(gameUI, world)
    storyPanel:init(gameUI)
    mapModeUI:load(gameUI, world)
    pauseUI:load(gameUI, world)
    tribeSelectionMarkersUI:setFailPositions(world:getFailPositions())
    contextualTipUI:init(gameUI)
    warningNoticeUI:init(gameUI)
    questUIHelper:init(world)

    gameUI.view.clickDownOutside = function(buttonIndex)
        if not gameUI:modalMoveOrBuildLikeUIIsVisible() and not localPlayer:isFollowingObject() then
            gameUI:popUI(true, buttonIndex == 1)
        end
    end

    gameUI:updateUIHidden()

    eventManager:addEventListenter(function(pos, buttonIndex, modKey) return gameUI:mouseDown(pos, buttonIndex, modKey) end, eventManager.mouseDownListeners)
    eventManager:addEventListenter(function(pos, buttonIndex, modKey) gameUI:mouseUp(pos, buttonIndex, modKey) end, eventManager.mouseUpListeners)
    eventManager:addEventListenter(function(buttonIndex) return gameUI:vrControllerButtonDown(buttonIndex) end, eventManager.vrControllerButtonDownListeners)
    eventManager:addEventListenter(function(buttonIndex) gameUI:vrControllerButtonUp(buttonIndex) end, eventManager.vrControllerButtonUpListeners)
    eventManager:addEventListenter(function(position, analogIndex) gameUI:vrControllerAnalogChanged(position, analogIndex) end, eventManager.vrControllerAnalogChangedListeners)
    eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "confirm", function(isDown)
        if isDown and (not gameUI:modalMoveOrBuildLikeUIIsVisible()) then
            gameUI:mouseDown(nil, 0, nil)
            return true
        end
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "pauseMenu", function(isDown)
        if isDown then
            startButtonPressed()
            return true
        end
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "buildMenu", function(isDown)
        if isDown then
            menuPressed(manageUI.modeTypes.build)
            return true
        end
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "cancel", function(isDown)
        if isDown then
            if not gameUI:popUI(false, false) then
                if uihiddenDueToInactivity then
                    setUIHiddenDueToInactivity(false)
                    gameUI:updateUIHidden()
                    return true
                else
                    if not gameUI:cancelPlansForLookAtObject() then
                        if playerSapiens:hasFollowers() then
                            setUIHiddenDueToInactivity(true)
                            gameUI:updateUIHidden()
                            return true
                        end
                    end
                end
            end
        end
        return false
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "speedUp", function(isDown)
        if isDown then
            world:increaseSpeed()
            return true
        end
    end)
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "speedDown", function(isDown)
        if isDown then
            world:decreaseSpeed()
            return true
        end
    end)
    
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "menuLeft", function(isDown)
        if isDown then
            multiselectShortcut()
            return true
        end
        return false
    end)

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "menuRight", function(isDown)
        if isDown then
            zoomShortcut()
            return true
        end
        return false
    end)
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "other", function(isDown)
        if isDown then
            return zoomToNotificationPressed()
        end
        return false
    end)


    --[[eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "cancel", function(isDown)
        if isDown then
            escapePressed()
        end
    end)]]
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuStart", function(isDown)
        if isDown then
            startButtonPressed()
            return true
        end
    end)
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuCancel", function(isDown)
        if isDown then
            escapePressed()
            return true
        end
    end)

    gameUI:mouseHiddenChanged(eventManager:mouseHidden())
    
    eventManager:setInactivityCallback(function(timeSinceInput)
        local limitMinutes = clientGameSettings.values.inactivityPauseDelay
        if limitMinutes < 30.5 then
            if not controller.isOnlineClient then
                if timeSinceInput > limitMinutes * 60 then
                    world:setPaused()
                end
            end
        end
    end)

	--[[MJLog("ortho test");
	printMat4(testMatrix);

	dmat4 testMatrixB = lookAt(dvec3(0.0,1.0,0.0), dvec3(3.0,0.0,54.0), dvec3(0.5, 1.0, 0.0));

	MJLog("lookAt test");
	printMat4(testMatrixB);

	dvec4 multiplyTest = testMatrixB * dvec4(1.0,2.0,3.0, 1.0);
	MJLog("multiply test:%.2f, %.2f, %.2f", multiplyTest.x, multiplyTest.y, multiplyTest.z);]]

    
end

function gameUI:remove(controller_)
    if gameUI.view then
        controller.mainView:removeSubview(gameUI.view)
        gameUI.view = nil
    end
end

function gameUI:hide()
    eventManager:setTextEntryListener(nil)
    gameUI.view.hidden = true
    lookAtTerrainMesh:hide()
    
    localPlayer:stopCinemaCamera()
end

function gameUI:show()
    gameUI.view.hidden = false
end


local function loadTribeSelectionUIIfNeeded()
    if not world:hasSelectedTribeID() and (not tribeSelectionMarkersUI.initialized) then
        tribeSelectionMarkersUI:init(world, localPlayer)
        tribeSelectionUI:init(world, gameUI, tribeSelectionMarkersUI, localPlayer, logicInterface)
        local failPositions = world:getFailPositions()
        if failPositions and failPositions[1] then
            gameFailSequence:init(gameUI, world, localPlayer, storyPanel)
            localPlayer:startCinematicMapModeCameraRotateGlobeTransition()
        else
            intro:init(gameUI, world, localPlayer, storyPanel)
        end
        timeControls:setHiddenForTribeSelection(true)
    end
end

function gameUI:setLocalPlayer(localPlayer_)
    localPlayer = localPlayer_
    buildModeInteractUI:setLocalPlayer(localPlayer)
    sapienMoveUI:setLocalPlayer(localPlayer, world)
    objectMoveUI:setLocalPlayer(localPlayer, world)
    storageLogisticsDestinationsUI:setLocalPlayer(localPlayer, world)
    changeAssignedSapienUI:setLocalPlayer(localPlayer, world)
    cinematicCamera:load(localPlayer, world)
    resourcesUI:setLocalPlayer(localPlayer_)
    
    hubUI:setLocalPlayer(localPlayer)

    interestMarkersUI:init(localPlayer, world, gameUI, mainThreadDestination, world:hasSelectedTribeID())
    loadTribeSelectionUIIfNeeded()
    
    tutorialUI:init(gameUI, world, localPlayer, intro, tutorialStoryPanel, logicInterface)
end

local lastBiomeTagVertID = nil


function gameUI:updateLookAtObjectUI(retrievedObjectResponse, isTerrain)
    
    currentRetrievedObjectResponse = retrievedObjectResponse
    currentRetrievedObjectIsTerrain = isTerrain
    --mj:log("gameUI:updateLookAtObjectUI:", (retrievedObjectResponse ~= nil))
    if retrievedObjectResponse and (not gameUI.view.hidden) and buildModeInteractUI:hidden() then
        local shouldHighlightSelection = (not localPlayer:getIsFollowCamMode())
        if isTerrain then
        -- debugUI:setBiome(biomeTypes[retrievedObjectResponse.verts[1].biome].key)

            if lastBiomeTagVertID ~= retrievedObjectResponse.uniqueID then
                lastBiomeTagVertID = retrievedObjectResponse.uniqueID
                logicInterface:callLogicThreadFunction("getBiomeTagsForVertWithID", lastBiomeTagVertID, function(biomeTags) 
                    if biomeTags and next(biomeTags) then
                        local tagsString = ""
                        for tag,v in pairs(biomeTags) do
                            tagsString = tagsString .. tag
                            if next(biomeTags, tag) then
                                tagsString = tagsString .. ", "
                            end
                        end
                        debugUI:setBiome(tagsString)
                    else
                        debugUI:setBiome("")
                    end
                end)
            end

            debugUI:setUniqueID("vertID:" .. retrievedObjectResponse.uniqueID)
        -- lookAtUI:hide()
            hubUI:setLookAtInfo(retrievedObjectResponse, isTerrain, shouldHighlightSelection)
            if not gameUI.view.hidden then
                lookAtTerrainMesh:show(retrievedObjectResponse.uniqueID)
            end
        else
            debugUI:setUniqueID("objectID:" ..retrievedObjectResponse.uniqueID)
            --if buildModeInteractUI:hidden() and sapienMoveUI:hidden() then
                --lookAtUI:show(retrievedObjectResponse)
                hubUI:setLookAtInfo(retrievedObjectResponse, isTerrain, shouldHighlightSelection)
            --end
            lookAtTerrainMesh:hide()
        end
    else
        debugUI:setUniqueID(nil)
        hubUI:setLookAtInfo(nil, nil, false)
        lookAtTerrainMesh:hide()
    end

    if not storageLogisticsDestinationsUI:hidden() then
        if retrievedObjectResponse and (not isTerrain) then-- and (not localPlayer.lookAtIsUI) then
            storageLogisticsDestinationsUI:updateLookAtObject(retrievedObjectResponse.uniqueID)
        else
            storageLogisticsDestinationsUI:updateLookAtObject(nil)
        end
    end
    
    if not changeAssignedSapienUI:hidden() then
        if retrievedObjectResponse and (not isTerrain) then-- and (not localPlayer.lookAtIsUI) then
            changeAssignedSapienUI:updateLookAtObject(retrievedObjectResponse.uniqueID)
        else
            changeAssignedSapienUI:updateLookAtObject(nil)
        end
    end

    
end

function gameUI:setPhysicsLookAtText(value)
    debugUI:setPhysicsLookAtText(value)
end

function gameUI:isFollowingObject()
    return localPlayer:isFollowingObject()
end

--function gameUI:inspectUIShouldBeDisplayed()
    --if localPlayer:isFollowingObject() then
    --    return true
    --end
    --[[if not actionUI:hidden() then
        return true
    end]]
   --- return false
--end

function gameUI:canShowInvasivePopup()
    if uihiddenDueToInactivity then
        return false
    end
    
    if localPlayer:isFollowingObject() then
        return false
    end

    if localPlayer:isMovingDueToControls() then
        return false
    end

    if not hubUI:canShowInvasivePopup() then
        return false
    end
    if (not buildModeInteractUI:hidden()) then
        return false
    end
    if (not sapienMoveUI:hidden()) then
        return false
    end
    if (not objectMoveUI:hidden()) then
        return false
    end
    if (not storageLogisticsDestinationsUI:hidden()) then
        return false
    end
    if (not changeAssignedSapienUI:hidden()) then
        return false
    end
    if (not manageUI:hidden()) then
        return false
    end
    if not tribeSelectionUI:hidden() then
        return false
    end

    if not discoveryUI:hidden() then
        return false
    end
    if not tribeRelationsUI:hidden() then
        return false
    end
    if not tutorialStoryPanel:hidden() then
        return false
    end
    return true
end

function gameUI:popUI(wasDueToClickOutside, wasRightClick)
    --[[if localPlayer:isFollowingObject() then
        localPlayer:stopFollowingObject()
        return hubUI:popUI()
    end]]

    
    --mj:log("gameUI:popUI")

    if not hubUI:popUI() then
        if (not buildModeInteractUI:hidden()) then
            if (not wasDueToClickOutside) and (not wasRightClick) then
                buildModeInteractUI:hide()
            end
        elseif not sapienMoveUI:hidden() then
            sapienMoveUI:hide()
        elseif not objectMoveUI:hidden() then
            objectMoveUI:hide()
        elseif not discoveryUI:hidden() then
            discoveryUI:hide()
        elseif not tribeRelationsUI:hidden() then
            tribeRelationsUI:hide()
        elseif not tutorialStoryPanel:hidden() then
            tutorialStoryPanel:popUI()
        elseif not storageLogisticsDestinationsUI:hidden() then
            storageLogisticsDestinationsUI:popUI()
        elseif not changeAssignedSapienUI:hidden() then
            changeAssignedSapienUI:popUI()
        elseif not manageUI:hidden() then
            manageUI:popUI()
        elseif not tribeSelectionUI:hidden() then
            if not tribeSelectionMarkersUI:isHoveringOverActiveMarker() then
                tribeSelectionUI:hide(true)
            end
       --[[ elseif not uihiddenDueToInactivity and (not wasDueToClickOutside) then
            uihiddenDueToInactivity = true
            gameUI:updateUIHidden()]]
        elseif localPlayer:isFollowingObject() then
            --mj:log("localPlayer:isFollowingObject")
            localPlayer:stopFollowingObject()
        else
            return false
        end
    end
    
    gameUI:updateUIHidden()
    
    return true
end

function gameUI:hideAllUI(completionFunctionOrNil)
    local calledCompletionFunction = false
    
    sapienMoveUI:hide()
    objectMoveUI:hide()
    storageLogisticsDestinationsUI:hide()
    changeAssignedSapienUI:hide()
    buildModeInteractUI:hide()
    hubUI:hideAllModalUI(false)
    --hubUI:hideAllUI(false)
    manageUI:hide()
    discoveryUI:hide()
    tribeRelationsUI:hide()
    tutorialStoryPanel:hide()


    if (not calledCompletionFunction) and completionFunctionOrNil then
        completionFunctionOrNil()
    end
end

function gameUI:hasUIPanelDisplayed(allowHubUI)
    if (not allowHubUI) and hubUI:anyModalUIIsDisplayed() then
        return true
    elseif not manageUI:hidden() then
        return true
    elseif not discoveryUI:hidden() then
        return true
    elseif not tribeRelationsUI:hidden() then
        return true
    elseif not tutorialStoryPanel:hidden() then
        return true
    elseif not tribeSelectionUI:hidden() then
        return true
    end
    return false
end

function gameUI:shouldAllowPlayerMovement()
   -- local gameState = controller:getGameState()
    --[[if gameState == GameStateLoadedPaused then
        return false
    end]]

    if gameUI:hasUIPanelDisplayed() or (not terminal.hidden) then
        return false
    end

    return true
end

function gameUI:pointAndClickModeHasHiddenMouseForMoveControl()
    return pointAndClickCamera:hasHiddenMouseForMoveControl()
end

function gameUI:pointAndClickModeEnabled()
    return pointAndClickCamera.enabled
end

-- options: maintainDirection, dismissAnyUI, stopWhenClose, showInspectUI

function gameUI:followObject(objectInfo, isTerrain, options)
    --mj:log("gameUI:followObject:", debug.traceback())
    if not objectInfo then
        mj:error("attempt to follow object with no objectInfo")
        return
    end
    --[[local gameState = controller:getGameState()
    if gameState == GameStateLoadedPaused then
        controller:resumeGameAndHidePauseUI()
    end]]

    if options.dismissAnyUI then
        gameUI:hideAllUI()
    end

    --mj:log("objectInfo:", objectInfo)

    local pos = objectInfo.pos
    if not pos then
        local posInfo = world:getMainThreadDynamicObjectInfo(objectInfo.uniqueID)
        if posInfo then
            pos = posInfo.pos
            objectInfo.pos = pos
        else
            pos = playerSapiens:posForSapienWithUniqueID(objectInfo.uniqueID)
            if pos then
                objectInfo.pos = pos
            end
        end
    end

    if pos then
        local stopWhenClose = options.stopWhenClose
        if (not stopWhenClose) and (not isTerrain) then
            local objectMoves = (objectInfo.objectTypeIndex == gameObject.types.sapien.index or gameObject.types[objectInfo.objectTypeIndex].mobTypeIndex)
            if not objectMoves then
                stopWhenClose = true
            end
        end

        localPlayer:followObject(objectInfo, isTerrain, pos, options.maintainDirection, stopWhenClose)

        if options.completActionIndex then
            hubUI:actionShortcut(objectInfo, nil, localPlayer.lookAtPosition, isTerrain, options.completActionIndex, options.completActionShouldAutomateOrOpenOptions)
        elseif options.showInspectUI then
            hubUI:showInspectUI(objectInfo, nil, isTerrain)
        else
            hubUI:updateInspectUIIfVisible(objectInfo, nil, localPlayer.lookAtPosition, isTerrain)
        end
    end
end


function gameUI:displayInspectUIForLookAtObject(isTerrain, options)
    if not localPlayer.retrievedLookAtObject then
        return
    end
    
    if options.dismissAnyUI then
        gameUI:hideAllUI()
    end

    if options.completActionIndex then
        hubUI:actionShortcut(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, isTerrain, options.completActionIndex, options.completActionShouldAutomateOrOpenOptions)
    elseif options.showInspectUI then
        hubUI:showInspectUI(localPlayer.retrievedLookAtObject, nil, isTerrain)
    else
        hubUI:updateInspectUIIfVisible(localPlayer.retrievedLookAtObject, nil, localPlayer.lookAtPosition, isTerrain)
    end
end

function gameUI:teleportToLookAtPos(pos)
    localPlayer:teleportToLookAtPos(pos)
end

local function getValidObjectWasClicked(eventStartLookAtID)
    return localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID and localPlayer.lookAtID == eventStartLookAtID
end

function gameUI:selectMulti(baseObjectInfo, isTerrain)
    if not gameUI:isMapMode() then
        if not gameUI:modalMoveOrBuildLikeUIIsVisible() then
            hubUI:showMultiSelectUI(baseObjectInfo, isTerrain, localPlayer:getNormalModePos(), localPlayer.lookAtPosition)
        end
    end
end


--[[function gameUI:showActionUI(baseObjectInfo, allObjectInfos)
    if (not gameUI:isMapMode()) and playerSapiens:hasFollowers() then
        actionUI:showObjects(baseObjectInfo, allObjectInfos, localPlayer.lookAtPosition)
    end
end]]

function gameUI:multiSelectObjectsReceived(baseObjectInfo, allObjectInfos)
    if (not gameUI:isMapMode()) and playerSapiens:hasFollowers() then
        hubUI:showInspectUI(baseObjectInfo, allObjectInfos, false)
        return true
    end
end

function gameUI:multiSelectVertsReceived(currentVert, selectedVertInfos)
    if (not gameUI:isMapMode()) and playerSapiens:hasFollowers() then
        hubUI:showInspectUI(currentVert, selectedVertInfos, true)
        return true
    end
end

function gameUI:debugTeleport(objectID)
    if not gameUI:isMapMode() then
        if mainThreadDestination.destinationInfosByID[objectID] then
            localPlayer:teleportToPos(mainThreadDestination.destinationInfosByID[objectID].pos, true)
        else
            logicInterface:callLogicThreadFunction("retrieveObject", objectID, function(retrievedObjectResponse)
                --mj:log("retrievedObjectResponse:", retrievedObjectResponse)
                if retrievedObjectResponse and retrievedObjectResponse.found then
                    localPlayer:teleportToObject(objectID, retrievedObjectResponse.pos)
                    hubUI:showInspectUI(retrievedObjectResponse, nil, false)
                else
                    mj:log("no object found with id:", objectID)
                    logicInterface:callLogicThreadFunction("requestUnloadedObjectFromServer", objectID)
                end
            end)
        end
    end
end

function gameUI:showTasksMenuForSapienFromTribeTaskAssignUI(sapien, backFunction)
    manageUI:hide()
    hubUI:showInspectUI(sapien, nil, false)
    hubUI:showTasksForCurrentSapien(backFunction)
end

function gameUI:cancelPlansForLookAtObject()
    --mj:log("gameUI:cancelPlansForLookAtObject a")
    if localPlayer.lookAtID ~= nil and not gameUI:isMapMode() then
        --mj:log("gameUI:cancelPlansForLookAtObject b")
        local eventStartLookAtID = localPlayer.lookAtID
        local objectClicked = false
        local terrainClicked = false
        if getValidObjectWasClicked(eventStartLookAtID) then
           -- mj:log("gameUI:cancelPlansForLookAtObject c")
            --mj:log("hi")
            objectClicked = true
        elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and eventStartLookAtID then
            terrainClicked = true
        end

        local planObjectInfo = nil
        if objectClicked then
            planObjectInfo = localPlayer.retrievedLookAtObject
        elseif terrainClicked then
            if localPlayer.retrievedLookAtTerrainVert then
                planObjectInfo = localPlayer.retrievedLookAtTerrainVert.planObjectInfo
            end
        end

        --mj:log("planObjectInfo:", planObjectInfo)

        if planObjectInfo then
            --mj:log("planObjectInfo:", planObjectInfo)
            local sharedState = planObjectInfo.sharedState
            if sharedState then
                if planObjectInfo.objectTypeIndex == gameObject.types.sapien.index and sharedState.tribeID == world.tribeID then
                    audio:playUISound(uiCommon.cancelSoundFile)
                    logicInterface:callServerFunction("cancelSapienOrders", {
                        sapienIDs = {localPlayer.retrievedLookAtObject.uniqueID},
                    })
                    return true
                else
                    local foundPlanToCancel = false
                    if sharedState.haulObjectID then
                        foundPlanToCancel = true
                    else
                        local planStatesByTribeID = sharedState.planStates
                        if planStatesByTribeID then
                            local planStates = planStatesByTribeID[world.tribeID]
                            if planStates and planStates[1] then
                                foundPlanToCancel = true
                            end
                        end
                    end

                    if foundPlanToCancel then
                        audio:playUISound(uiCommon.cancelSoundFile)
                        if objectClicked then
                            logicInterface:callServerFunction("cancelAll", {
                                objectIDs = {localPlayer.retrievedLookAtObject.uniqueID},
                            })
                        else
                            logicInterface:callServerFunction("cancelAll", {
                                vertIDs = {localPlayer.retrievedLookAtTerrainVert.uniqueID},
                            })
                        end
                        return true
                    end
                end
            end

        end



       --[[ local availablePlans = nil --alterantive that matches UI but fails in some situations, eg move markers which required the alternate method anyway as below
        if objectClicked then
            availablePlans = planHelper:availablePlansForObjectInfos({localPlayer.retrievedLookAtObject}, world.tribeID)
        elseif terrainClicked then
            availablePlans = planHelper:availablePlansForVertInfos({localPlayer.retrievedLookAtTerrainVert}, world.tribeID)
        end
        
        if availablePlans then
            local foundPlanToCancel = false
            for i,planInfo in ipairs(availablePlans) do
                if planInfo.hasQueuedPlans then
                    foundPlanToCancel = true
                end
            end
            if foundPlanToCancel then
                audio:playUISound(uiCommon.cancelSoundFile)
                if objectClicked then
                    logicInterface:callServerFunction("cancelAll", {
                        objectIDs = {localPlayer.retrievedLookAtObject.uniqueID},
                    })
                else
                    logicInterface:callServerFunction("cancelAll", {
                        vertIDs = {localPlayer.retrievedLookAtTerrainVert.uniqueID},
                    })
                end
                return true
            end
        end

        ]]

        --[[if localPlayer.retrievedLookAtObject then --this is all a bit weird, added to allow cancelling of move plans via the temporary move object. Perhaps we could use this route instead of availablePlans for all objects
            local sharedState = localPlayer.retrievedLookAtObject.sharedState
            local planStatesByTribeID = sharedState.planStates
            local foundPlanToCancel = false
            if planStatesByTribeID then
                for tribeID,planStates in pairs(planStatesByTribeID) do
                    for i=#planStates,1,-1 do
                        local thisPlanState = planStates[i]
                        if thisPlanState.planTypeIndex == plan.types.moveTo.index then
                            foundPlanToCancel = true
                            break
                        end
                    end
                end
            end
            if foundPlanToCancel then
                audio:playUISound(uiCommon.cancelSoundFile)
                logicInterface:callServerFunction("cancelAll", {
                    objectIDs = {localPlayer.retrievedLookAtObject.uniqueID},
                })
                return true
            end
        end]]

    end
    return false
end

local function checkForNewSeenResourcesForObjectClick(retrievedLookAtObject)
    if retrievedLookAtObject then
        local addObjectTypeIndexSet = {}
        addObjectTypeIndexSet[retrievedLookAtObject.objectTypeIndex] = true

        local baseObjectGameObjectType = gameObject.types[retrievedLookAtObject.objectTypeIndex]

        if baseObjectGameObjectType.gatherableTypes then
            for i,gatherableTypeIndex in ipairs(baseObjectGameObjectType.gatherableTypes) do
                addObjectTypeIndexSet[gatherableTypeIndex] = true
            end
        end

        local inventory = retrievedLookAtObject.sharedState and retrievedLookAtObject.sharedState.inventory
        if inventory and inventory.countsByObjectType then
            for k,v in pairs(inventory.countsByObjectType) do
                addObjectTypeIndexSet[k] = true
            end
        end

        world:addSeenResourceObjectTypesForClientInteraction(addObjectTypeIndexSet)
    end
end

function gameUI:interact(eventStartLookAtID, wasMarkerClick)


    localPlayer:stopFollowingObject()
    --if localPlayer:isFollowingObject() then

   -- end
    --mj:log("interact:", eventStartLookAtID, " localPlayer.lookAtID:", localPlayer.lookAtID, " localPlayer.retrievedLookAtObject:", localPlayer.retrievedLookAtObject)
   -- mj:log(debug.traceback())
    local objectClicked = false
    local terrainClicked = false

    if eventStartLookAtID and getValidObjectWasClicked(eventStartLookAtID) then
        --mj:log("hi")
        objectClicked = true
    elseif eventStartLookAtID and localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert and eventStartLookAtID then
        terrainClicked = true
    end

    if gameUI:isMapMode() then
        if objectClicked then
            if playerSapiens:hasFollowers() and localPlayer.retrievedLookAtObject then
                if localPlayer.retrievedLookAtObject.objectTypeIndex == gameObject.types.sapien.index then
                    local pos = playerSapiens:posForSapienWithUniqueID(localPlayer.retrievedLookAtObject.uniqueID)
                    if pos then
                        
                        logicInterface:callLogicThreadFunction("getHighestDetailTerrainPointAtPoint", pos, function(terrainPoint)
                            if localPlayer.retrievedLookAtObject then
                                localPlayer:teleportToObject(localPlayer.retrievedLookAtObject.uniqueID, terrainPoint)
                                localPlayer:setMapMode(nil, false)
                            end
                        end) 
                        return true
                    end
                end
            end
        end
    else
        if objectClicked then
            if not sapienMoveUI:hidden() then
                sapienMoveUI:terrainOrObjectClicked(terrainClicked, 0)
                return true
            elseif not objectMoveUI:hidden() then
                objectMoveUI:terrainOrObjectClicked(terrainClicked, 0)
                return true
            elseif not storageLogisticsDestinationsUI:hidden() then
                storageLogisticsDestinationsUI:terrainOrObjectClicked(terrainClicked, 0)
                return true
            elseif not changeAssignedSapienUI:hidden() then
                changeAssignedSapienUI:terrainOrObjectClicked(terrainClicked, 0)
                return true
            elseif not buildModeInteractUI:hidden() then
                buildModeInteractUI:cickEvent(0)
                return true
            else
                if playerSapiens:hasFollowers() and localPlayer.retrievedLookAtObject then
                    if zoomModifierKeyDown then
                        zoomShortcut()
                        return
                    end
                    if multiselectModifierKeyDown then
                        multiselectShortcut()
                        return
                    end
                    checkForNewSeenResourcesForObjectClick(localPlayer.retrievedLookAtObject)
                    hubUI:showInspectUI(localPlayer.retrievedLookAtObject, nil, false)
                    if pointAndClickCamera.enabled then
                        actionUI:warpForPointAndClickInteraction()
                    end

                    --if wasMarkerClick then
                    --    localPlayer:followObject(localPlayer.retrievedLookAtObject, localPlayer.retrievedLookAtObject.pos)
                   -- end
                    return true
                end
            end
        elseif terrainClicked then
            if not sapienMoveUI:hidden() then
                sapienMoveUI:terrainOrObjectClicked(terrainClicked, 0)
                return true
            elseif not objectMoveUI:hidden() then
                objectMoveUI:terrainOrObjectClicked(terrainClicked, 0)
                return true
            elseif not storageLogisticsDestinationsUI:hidden() then
                return true
            elseif not changeAssignedSapienUI:hidden() then
                return true
            elseif not buildModeInteractUI:hidden() then
                buildModeInteractUI:cickEvent(0)
                return true
            else
                if playerSapiens:hasFollowers() and localPlayer.retrievedLookAtTerrainVert then
                    if zoomModifierKeyDown then
                        zoomShortcut()
                        return
                    end
                    if multiselectModifierKeyDown then
                        multiselectShortcut()
                        return
                    end
                    hubUI:showInspectUI(localPlayer.retrievedLookAtTerrainVert, nil, true)
                    if pointAndClickCamera.enabled then
                        actionUI:warpForPointAndClickInteraction()
                    end
                    return true
                end
            end
        else
            if not buildModeInteractUI:hidden() then
                buildModeInteractUI:cickEvent(0)
                return true
            end
        end
    end
    return false
end

function gameUI:rightClick()
    if not gameUI:popUI(false, true) then
        if uihiddenDueToInactivity then
            setUIHiddenDueToInactivity(false)
            gameUI:updateUIHidden()
        else
            if not gameUI:cancelPlansForLookAtObject() then
                --mj:log("gameUI:rightClick e")
                if playerSapiens:hasFollowers() then
                    --mj:log("gameUI:rightClick f")
                    setUIHiddenDueToInactivity(true)
                    gameUI:updateUIHidden()
                end
            end
        end
    end
end

local pointAndClickRightMouseDownWaitForClick = false

function gameUI:mouseDown(pos, buttonIndex, modKey)

    if pointAndClickCamera.enabled then
        pointAndClickCamera:mouseDown(pos, buttonIndex, modKey)
    end

    if uihiddenDueToInactivity then
        if pointAndClickCamera.enabled and buttonIndex == 1 then
            pointAndClickRightMouseDownWaitForClick = true
        else
            setUIHiddenDueToInactivity(false)
            gameUI:updateUIHidden()
            return
        end
    end

    if gameUI.view.hidden then
        return
    end

    
    if (not buildModeInteractUI:hidden()) then
        if buildModeInteractUI:mouseDown(pos, buttonIndex, modKey) then
            return
        end
    end

    if buttonIndex == 0 then
        if gameUI:isMapMode() then
            localPlayer:mouseDown(pos, buttonIndex)
            gameUI:interact(localPlayer.lookAtID, false)
        elseif eventManager:mouseHidden() or pointAndClickCamera.enabled then
            gameUI:interact(localPlayer.lookAtID, false)
        end
    elseif buttonIndex == 1 then
        if eventManager:mouseHidden() or pointAndClickCamera.enabled then
            if pointAndClickCamera.enabled then
                pointAndClickRightMouseDownWaitForClick = true
            else
                gameUI:rightClick()
            end
        else
            gameUI:popUI(false, true)
        end
    end

    --[[if eventManager:mouseHidden() or pointAndClickCamera.enabled then
        if buttonIndex == 0 then
            gameUI:interact(localPlayer.lookAtID, false)
        elseif buttonIndex == 1 then
            if pointAndClickCamera.enabled then
                pointAndClickRightMouseDownWaitForClick = true
            else
                gameUI:rightClick()
            end
        end
        return
    else
        if buttonIndex == 0 then
            if gameUI:isMapMode() then
                localPlayer:mouseDown(pos, buttonIndex)
                gameUI:interact(localPlayer.lookAtID, false)
            end
        elseif buttonIndex == 1 then
            gameUI:popUI(false, true)
        end
        return
    end]]
end

function gameUI:mouseUp(pos, buttonIndex, modKey)
    if pointAndClickCamera.enabled then
        if pointAndClickRightMouseDownWaitForClick and buttonIndex == 1 then
            gameUI:rightClick()
        end
        pointAndClickCamera:mouseUp(pos, buttonIndex, modKey)
    end
    
    if gameUI.view.hidden then
        return
    end


    if (not buildModeInteractUI:hidden()) then
        if buildModeInteractUI:mouseUp(pos, buttonIndex, modKey) then
            return
        end
    end


    if not eventManager:mouseHidden() then
        if buttonIndex == 0 then
            if gameUI:isMapMode() then
                localPlayer:mouseUp(pos, buttonIndex)
            end
        end
    end
end

function gameUI:mouseMoved(pos, relativeMovement, dt)
    pointAndClickRightMouseDownWaitForClick = false
end

function gameUI:shouldBlockPointAndClickFromShowingMouse()
    return buildModeInteractUI:shouldOwnMouseMoveControl()
end

--local trackpadTouched = false

local leftAnalogValue = nil
local leftAnalogIsTrackpad = false
local leftJoystickCooldown = false

local hasUpdatedView = false

function gameUI:updateMainViewOrientation()
    if world.isVR then
        local headDirection = world:getHeadDirectionUISpace()
        if headDirection.x ~= 0.0 or headDirection.z ~= 0.0 then
            local xzRotation = normalize(vec3(-headDirection.x, 0.0, -headDirection.z))
            local rotationMatrix = mat3LookAtInverse(xzRotation, vec3(0.0,1.0,0.0))
           -- rotationMatrix = mat3Rotate(rotationMatrix, math.pi * 0.125, vec3(0.0,1.0,0.0))
            controller.mainView.windowRotation = rotationMatrix

            local headPosition = world:getHeadPositionUISpace()
            local screenPosition = vec3(headPosition.x, headPosition.y - 1.0, headPosition.z) + vec3xMat3(vec3(0.0,0.0,-1.0), mat3Inverse(rotationMatrix)) 
            --local screenOffset = length(screenPosition)
            controller.mainView.windowPosition = screenPosition

            if not hasUpdatedView then
                controller.mainView.windowZOffset = 0.0
                hasUpdatedView = true
            end
        end
    end
end

function gameUI:vrControllerAnalogChanged(position, analogIndex)
    if gameUI.view.hidden then
        return
    end
    --if analogIndex == eventManager.vrControllerAnalogCodes.RIGHT_TRACKPAD then
        --[[if trackpadTouched then
            if not actionUI:hidden() then
                actionUI:controllerChanged(position)
            end
        end]]
    if analogIndex == eventManager.vrControllerAnalogCodes.LEFT_TRACKPAD then
        leftAnalogValue = position
        leftAnalogIsTrackpad = true
        local foundTeleport = false
        if length(vec3(leftAnalogValue.x, leftAnalogValue.y, 0.0)) > 0.2 then
            if leftAnalogValue.y > 0.0 and leftAnalogValue.y > math.abs(leftAnalogValue.x) then
                if not world:getTeleportActive() then
                    gameUI:hideAllUI()
                    world:setTeleportActive(true)
                end
                foundTeleport = true
            end
        end
        if not foundTeleport and world:getTeleportActive() then
            world:setTeleportActive(false)
        end
    elseif analogIndex == eventManager.vrControllerAnalogCodes.LEFT_JOYSTICK then
        if not leftAnalogIsTrackpad then
            leftAnalogValue = position
            
            local positionLength = length(vec3(leftAnalogValue.x, leftAnalogValue.y, 0.0))
            if world:getTeleportActive() then
                if positionLength < 0.5 then
                    localPlayer:doVRTeleport()
                    world:setTeleportActive(false)
                    leftJoystickCooldown = false
                end
            else
                if positionLength < 0.5 then
                    leftJoystickCooldown = false
                elseif not leftJoystickCooldown and positionLength > 0.95 then
                    local absX = math.abs(leftAnalogValue.x)
                    local absY = math.abs(leftAnalogValue.y)
                    if absY > absX then
                        if leftAnalogValue.y > 0.0 then
                            gameUI:hideAllUI()
                            world:setTeleportActive(true)
                        end
                    else
                        gameUI:hideAllUI()
                        if eventManager:mouseHidden() then
                            if leftAnalogValue.x > 0.0 then
                                localPlayer:turnRight()
                                leftJoystickCooldown = true
                            else
                                localPlayer:turnLeft()
                                leftJoystickCooldown = true
                            end
                        end
                    end
                end
            end
        end
    end
end

function gameUI:vrControllerButtonDown(buttonIndex)
    if buttonIndex == eventManager.vrControllerCodes.RIGHT_TRACKPAD_TOUCH then
        if gameUI.view.hidden then
            return false
        end
        --[[if actionUI:hidden() then
            if (not trackpadTouched) and gameUI:interact(localPlayer.lookAtID) then
                trackpadTouched = true
                return true
            end
        end]]
    elseif buttonIndex == eventManager.vrControllerCodes.RIGHT_TRACKPAD_CLICK then
        if gameUI.view.hidden then
            return false
        end
        --[[if not actionUI:hidden() then
            actionUI:rightPrimaryButtonDown()
            return true
        end]]
    elseif buttonIndex == eventManager.vrControllerCodes.RIGHT_TRIGGER then
        if gameUI.view.hidden then
            return false
        end
        --if eventManager:mouseHidden() then
            --[[if not actionUI:hidden() then
                local rayTestStartPos = world:getPointerRayStartUISpace()
                local rayDirection = world:getPointerRayDirectionUISpace()
                local intersectionTestResult = actionUI:getVRPointerIntersection(rayTestStartPos, rayDirection)
                if not intersectionTestResult then
                    actionUI:animateOut(nil, nil)
                    hubUI:hideInspectUI()
                else
                    return true
                end
            else
                local objectClicked = false
                local terrainClicked = false
                if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
                    objectClicked = true
                elseif localPlayer.lookAtMeshType == MeshTypeTerrain and localPlayer.mainThreadLookAtTerrainVert then
                    terrainClicked = true
                end

                if not sapienMoveUI:hidden() then
                    if terrainClicked or objectClicked then
                        sapienMoveUI:terrainOrObjectClicked(terrainClicked, 0)
                        return true
                    end
                elseif not buildModeInteractUI:hidden() then
                    if terrainClicked or objectClicked then
                        buildModeInteractUI:cickEvent(0)
                        return true
                    end
                else
                    if (not trackpadTouched) then
                        gameUI:interact(localPlayer.lookAtID) 
                    end
                    trackpadTouched = false
                    return true
                end
            end]]
        if not eventManager:mouseHidden() then
            if gameUI:isMapMode() then
                tribeSelectionUI:hide(true)
                localPlayer:vrControllerTriggerDown()
                gameUI:interact(localPlayer.lookAtID, true)
                return true
            end
        end
    elseif buttonIndex == eventManager.vrControllerCodes.BUILD then
        gameUI:hideAllUI()
        gameUI:updateMainViewOrientation()
        manageUI:show()
        return true
    elseif buttonIndex == eventManager.vrControllerCodes.TELEPORT then
        if gameUI.view.hidden then
            return false
        end
        gameUI:hideAllUI()
        world:setTeleportActive(true)
        return true
    elseif buttonIndex == eventManager.vrControllerCodes.GRIP_RIGHT then
        gameUI.gripRight = true
        return true
    end
    return false
end

function gameUI:vrControllerButtonUp(buttonIndex)
    if gameUI.view.hidden then
        return
    end
   -- if buttonIndex == eventManager.vrControllerCodes.RIGHT_TRACKPAD_TOUCH then
        --trackpadTouched = false
        --if eventManager:mouseHidden() then
            --[[if not actionUI:hidden() then
                actionUI:animateOut(nil, nil)
                hubUI:hideInspectUI()
            end]]
       -- end
    --elseif buttonIndex == eventManager.vrControllerCodes.RIGHT_TRACKPAD_CLICK then
        --[[if not actionUI:hidden() then
            actionUI:rightPrimaryButtonUp()
        end]]
    if buttonIndex == eventManager.vrControllerCodes.LEFT_TRACKPAD_CLICK then
        if leftAnalogIsTrackpad then
            if eventManager:mouseHidden() and world:getTeleportActive() then
                localPlayer:doVRTeleport()
                world:setTeleportActive(false)
            else
                local absX = math.abs(leftAnalogValue.x)
                if absX > 0.2 and absX > math.abs(leftAnalogValue.y) then
                    gameUI:hideAllUI()
                    if eventManager:mouseHidden() then
                        if leftAnalogValue.x > 0.0 then
                            localPlayer:turnRight()
                        else
                            localPlayer:turnLeft()
                        end
                    end
                end
            end
        end
    elseif buttonIndex == eventManager.vrControllerCodes.RIGHT_TRIGGER then
        if not eventManager:mouseHidden() then
            if gameUI:isMapMode() then
                localPlayer:vrControllerTriggerUp()
            end
        end
    elseif buttonIndex == eventManager.vrControllerCodes.TELEPORT then
        if eventManager:mouseHidden() and world:getTeleportActive() then
            localPlayer:doVRTeleport()
            world:setTeleportActive(false)
        end
    elseif buttonIndex == eventManager.vrControllerCodes.TURN_LEFT then
        gameUI:hideAllUI()
        if eventManager:mouseHidden() then
            localPlayer:turnLeft()
        end
    elseif buttonIndex == eventManager.vrControllerCodes.TURN_RIGHT then
        gameUI:hideAllUI()
        if eventManager:mouseHidden() then
            localPlayer:turnRight()
        end
    elseif buttonIndex == eventManager.vrControllerCodes.GRIP_RIGHT then
        gameUI.gripRight = false
    end
end




--[[function gameUI:interactKeyChanged(isDown)
    if not gameUI.view.hidden then
        if isDown then
            if eventManager:mouseHidden() then
                if localPlayer.lookAtID ~= nil then
                    keyDownLookAtId = localPlayer.lookAtID
                end
            end
        else
            gameUI:interact(keyDownLookAtId, false)
            keyDownLookAtId = nil
        end
    end
end]]

--[[function gameUI:buildKeyChanged(isDown)
    if not isDown then
        if playerSapiens:hasFollowers() then
        if not gameUI.view.hidden then
                gameUI:popUI(false, false)
                manageUI:show()
            end
        end
    end
end]]

function gameUI:isBuildMode()
    return not buildModeInteractUI:hidden()
end

function gameUI:startLockCamera()
    localPlayer:startLockCamera()
end

function gameUI:isMapMode()
    if localPlayer then
        return localPlayer.mapMode ~= nil
    end
    return false
end


function gameUI:isFollowCamMode()
    if localPlayer then
        return localPlayer:getIsFollowCamMode()
    end
    return false
end

function gameUI:shouldShowMouse()
    return gameUI:isMapMode() or gameUI:isDetachedForBuildModeInteraction()-- or gameUI:isFollowCamMode()
end

function gameUI:isDetachedForBuildModeInteraction()
    return buildModeInteractUI:isDetachedForTransforming()
end


function gameUI:setDebugObject(currentObjectInfo, isTerrain)
    if clientGameSettings.values.renderDebug and currentObjectInfo and gameConstants.showDebugMenu then
        eventManager:setClipboardText(currentObjectInfo.uniqueID)

        local objectIDToUse = currentObjectInfo.uniqueID

        if isTerrain then
            mj:log("Vert ID:", objectIDToUse, " has been copied to the clipboard, and if it has an associated proxy object, is now set as the target for detailed logging.")
            mj:log("Vert Info:", currentObjectInfo)
            if currentObjectInfo.planObjectInfo then
                objectIDToUse = currentObjectInfo.planObjectInfo.uniqueID
            end
        else
            mj:log("Object ID:", objectIDToUse, " has been copied to the clipboard, and is now set as the target for detailed logging.")
            mj:log("Object Info:", currentObjectInfo)
        end
        
        mj.debugObject = objectIDToUse
        logicInterface:callServerFunction("changeDebugObject", objectIDToUse)
        logicInterface:callLogicThreadFunction("changeDebugObject", objectIDToUse)
    end
end

function gameUI:playerTemperatureZoneChanged(newTemperatureZoneIndex)
	timeControls:playerTemperatureZoneChanged(newTemperatureZoneIndex)
end

function gameUI:updateOrdersText(currentOrderCount, maxOrderCount)
    debugUI:updateOrdersText(currentOrderCount, maxOrderCount)
end

function gameUI:stopFollowingObject()
    localPlayer:stopFollowingObject()
end

function gameUI:setupForTribeFailReset(failPositions)
    gameUI:hideAllUI()
    localPlayer:stopFollowingObject()
    loadTribeSelectionUIIfNeeded()
    tribeSelectionMarkersUI:reset(localPlayer)
    tribeSelectionUI:initForTribeFailReset(world, gameUI, tribeSelectionMarkersUI, localPlayer, logicInterface)
    tutorialUI:disable()
    tribeSelectionMarkersUI:setFailPositions(failPositions)

    gameFailSequence:showForTribeFail(gameUI, world, localPlayer, storyPanel)
    --intro:init(gameUI, world, localPlayer, storyPanel)
end

function gameUI:transitionToWorldViewAfterTribeCreation(tribeInfo)
    --mj:log("gameUI:transitionToWorldViewAfterTribeCreation:", tribeInfo)
    local cross = mjm.cross

    local up = tribeInfo.normalizedPos
    local right = normalize(-cross(up, vec3(0.0,1.0,0.0)))
    local tribeDirection = normalize(cross(up, right))
    local offsetPoint = tribeInfo.normalizedPos - tribeDirection * mj:mToP(20.0)
    
    tribeSelectionMarkersUI:reset(localPlayer)
    
    logicInterface:callLogicThreadFunction("getHighestDetailTerrainPointAtPoint", offsetPoint, function(terrainPoint)
        localPlayer:transitionToGroundAfterTribeSelection(terrainPoint)
        musicPlayer:worldLoaded()
        timeControls:setHiddenForTribeSelection(false)
    end) 

    tutorialUI:show()
end

function gameUI:mouseHiddenChanged(mouseHidden)

    --mj:log("gameUI:mouseHiddenChanged:", mouseHidden)
    
    if mouseHidden then
        if crosshairsView then
            if (not pointAndClickCamera.enabled) or pointAndClickCamera:hasHiddenMouseForMoveControl() then
                crosshairsView.hidden = false
            end
        end
        debugUI:show()
    else
        --lookAtUI:hide()
        if (not pointAndClickCamera.enabled) or gameUI:hasUIPanelDisplayed() then
            debugUI:hide()
        end
        if crosshairsView then
            crosshairsView.hidden = true
        end
    end

    gameUI:updateUIHidden()
end

function gameUI:update()
    buildModeInteractUI:update(gameUI.gripRight)
    sapienMoveUI:update()
    objectMoveUI:update()
    storageLogisticsDestinationsUI:update()
    changeAssignedSapienUI:update()
    manageButtonsUI:updateHiddenState()
    --tribeSelectionMarkersUI:update()

    if world.isVR then
        local function updatePointer(shouldDisplay, displayLengthOrNil)
            if shouldDisplay then
                world:setPointerIntersection(true)
                world:setPointerLengthMeters(displayLengthOrNil or 100.0)
                world:setPointerActive(true)
            else
                world:setPointerIntersection(false)
                world:setPointerLengthMeters(100.0)
                world:setPointerActive(false)
            end
        end

        local function hasBlockingUI()
            return gameUI:hasUIPanelDisplayed()
        end

        if hasBlockingUI() then
            local rayTestStartPos = world:getPointerRayStartUISpace()
            local rayDirection = world:getPointerRayDirectionUISpace()
            local intersectionTestResult = gameUI.view:getIntersection(rayTestStartPos, rayDirection)
            if intersectionTestResult then
                updatePointer(true, intersectionTestResult.distance)
            else
                updatePointer(false, nil)
            end
        else
            local foundActionUI = false
            --[[if not actionUI:hidden() then
                if trackpadTouched then
                    updatePointer(false, nil)
                    foundActionUI = true
                else
                    local rayTestStartPos = world:getPointerRayStartUISpace()
                    local rayDirection = world:getPointerRayDirectionUISpace()
                    local intersectionTestResult = actionUI:getVRPointerIntersection(rayTestStartPos, rayDirection)
                    if intersectionTestResult then
                        updatePointer(true, intersectionTestResult.distance)
                        foundActionUI = true
                    end
                end
            end]]

            if not foundActionUI then
                local lookAtPoint = localPlayer:getLookAtPoint()
                if lookAtPoint then
                    local rayTestStartPos = world:getPointerRayStart()
                    local rayLength = length(rayTestStartPos - lookAtPoint)
                    updatePointer(true, mj:pToM(rayLength))
                else
                    updatePointer(true, 100000.0)
                end
            end
        end

        if world:getTeleportActive() then
            local rayTestStartPos = world:getTeleportRayStart()
            local rayTestEndPos = rayTestStartPos + world:getTeleportRayDirection() * mj:mToP(100.0)
            local foundPoint = nil

            local forwardRayTestResult = world:rayTest(rayTestStartPos, rayTestEndPos, nil, nil, true)
            if forwardRayTestResult.hasHitTerrain or forwardRayTestResult.hasHitObject then
                
                if not (forwardRayTestResult.hasHitObject and (not forwardRayTestResult.terrainIsCloserThanObject)) then
                    foundPoint = forwardRayTestResult.terrainCollisionPoint
                end
            end

            if foundPoint then
                world:setTeleportIntersection(true)
                world:setTeleportPos(foundPoint)
            else
                world:setTeleportIntersection(false)
            end
        end
    end
end

return gameUI