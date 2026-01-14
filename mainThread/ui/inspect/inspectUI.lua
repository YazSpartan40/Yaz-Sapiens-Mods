local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4
local approxEqualEpsilon = mjm.approxEqualEpsilon

local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
local gameObject = mjrequire "common/gameObject"
local gameConstants = mjrequire "common/gameConstants"

local logicInterface = mjrequire "mainThread/logicInterface"
--local keyMapping = mjrequire "mainThread/keyMapping"
--local audio = mjrequire "mainThread/audio"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
--local eventManager = mjrequire "mainThread/eventManager"
local playerSapiens = mjrequire "mainThread/playerSapiens"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local inspectFollowerUI = mjrequire "mainThread/ui/inspect/inspectFollowerUI"
local inspectObjectUI = mjrequire "mainThread/ui/inspect/inspectObjectUI"
local inspectTerrainUI = mjrequire "mainThread/ui/inspect/inspectTerrainUI"
local inspectStorageUI = mjrequire "mainThread/ui/inspect/inspectStorageUI"
local uiTextEntry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"

local modalPanelSize = vec2(1140, 640)
local modalPanelTitleIconHalfSize = 20
local modalPanelTitleIconPadding = 6

local currentModalPanelUIObject = nil

local inspectUI = {
    selectedObjectOrVertInfoCount = 0,
}

local world = nil
local gameUI = nil
local manageButtonsUI = nil
local hubUI = nil

local currentlyRegisteredForStateChangesObjectID = nil
local currentSubUI = nil
local currentModalContainerView = nil

--local extraButtonBackgroundView = nil
local debugIDText = nil

local function deregisterStateChanges()
    if currentlyRegisteredForStateChangesObjectID then
        logicInterface:deregisterFunctionForObjectStateChanges({currentlyRegisteredForStateChangesObjectID}, logicInterface.stateChangeRegistrationGroups.inspectUI)
        currentlyRegisteredForStateChangesObjectID = nil
    end
end

local function registerStateChanges(objectID)
    
    deregisterStateChanges()
    
    logicInterface:registerFunctionForObjectStateChanges({objectID}, logicInterface.stateChangeRegistrationGroups.inspectUI, function (retrievedObjectResponse)
        --mj:log("incoming:", retrievedObjectResponse, " selectedObjects:", selectedObjects)
        if inspectUI.baseObjectOrVertInfo and inspectUI.baseObjectOrVertInfo.uniqueID == retrievedObjectResponse.uniqueID then
            --mj:log("got updated info forid:", retrievedObjectResponse.uniqueID, " name:", retrievedObjectResponse.sharedState.name)

            if inspectUI.baseObjectOrVertInfo.objectTypeIndex == gameObject.types.sapien.index then
                if inspectUI.baseObjectOrVertInfo.sharedState.tribeID ~= retrievedObjectResponse.sharedState.tribeID then
                    mj:log("tribe changed. UI no longer valid, hiding.")
                    if not inspectUI:hidden() then
                        gameUI:hideAllUI()
                        inspectUI:hideIfNeeded()
                        return
                    end
                end
            end
            
            inspectUI.selectedObjectOrVertInfosByID[inspectUI.baseObjectOrVertInfo.uniqueID] = retrievedObjectResponse
            inspectUI.baseObjectOrVertInfo = retrievedObjectResponse
            currentSubUI:updateObjectInfo()
            
        end
    end,
    function(removedObjectID)
        --mj:log("inspect ui removal:", removedObjectID)
        if not inspectUI:hidden() then
            gameUI:hideAllUI()
            inspectUI:hideIfNeeded()
        end
    end)
        
    currentlyRegisteredForStateChangesObjectID = objectID
end


local function changeObjectName(newName)
    if inspectUI.baseObjectOrVertInfo then
        logicInterface:callServerFunction("changeObjectName", 
        {
            newName = newName,
            objectID = inspectUI.baseObjectOrVertInfo.uniqueID,
        })
        inspectUI.objectName = newName
    end
end

--[[local function tabPressed()
    if inspectUI.orderedObjectList then
        if gameUI:isFollowingObject() then
            inspectUI.currentOredredListIndex = inspectUI.currentOredredListIndex + 1
            if inspectUI.currentOredredListIndex > #inspectUI.orderedObjectList then
                inspectUI.currentOredredListIndex = 1
            end
            inspectUI.selectedObjectOrVertInfos[1] = inspectUI.orderedObjectList[inspectUI.currentOredredListIndex]
            --registerStateChanges(inspectUI.selectedObjectOrVertInfos[1].uniqueID)
            currentSubUI:showNext(inspectUI.selectedObjectOrVertInfos[1])
            gameUI:followObject(inspectUI.selectedObjectOrVertInfos[1])
        end
    end
end]]

--[[function inspectUI:hideExtraButtons()
    extraButtonBackgroundView.hidden = true
end]]

inspectUI.contentExtraWidth = 0.0
inspectUI.contentExtraHeight = 0.0
inspectUI.defaultContentWidth = 200
inspectUI.defaultContentHeight = 40.0


function inspectUI:canChangeName()
    local object = inspectUI.baseObjectOrVertInfo
    local sharedState = object.sharedState
    if sharedState.tribeID then
        if world:getTribeID() ~= sharedState.tribeID then
            return false
        end
    end
    return true
end

function inspectUI:load(gameUI_, manageButtonsUI_, hubUI_, manageUI, world_, backgroundView, circleView, objectImageView, infoView)
    gameUI = gameUI_
    manageButtonsUI = manageButtonsUI_
    hubUI = hubUI_
    world = world_

    local mainView = View.new(gameUI.view)
    inspectUI.mainView = mainView
    mainView.hidden = true
    mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    mainView.size = gameUI.view.size
    
    local containerParentView = View.new(infoView)
    containerParentView.size = infoView.size
    containerParentView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    containerParentView.hidden = true

    local containerView = View.new(containerParentView)
    containerView.size = containerParentView.size
    containerView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

    inspectUI.containerParentView = containerParentView
    inspectUI.containerView = containerView


    local heightMultiplier = 0.2

    containerParentView.update = function(dt)

        local baseWidth = inspectUI.defaultContentWidth
        if not inspectUI.nameTextEntry.hidden then
            baseWidth = math.max(baseWidth, inspectUI.nameTextEntry.size.x)
        end
        local width = baseWidth + inspectUI.contentExtraWidth + 130
        local height = inspectUI.defaultContentHeight + inspectUI.contentExtraHeight + 10
        if not debugIDText.hidden then
            width = width + 100.0
            height = height + 10.0
        end
        local desiredBackgroundSize = vec2(width, height)
        
        if not (approxEqualEpsilon(desiredBackgroundSize.x, infoView.size.x, 2) and approxEqualEpsilon(desiredBackgroundSize.y, infoView.size.y, 2)) then
            --containerView.hidden = true
            infoView.size = infoView.size + (desiredBackgroundSize - infoView.size) * math.min(dt * 20.0, 1.0)
            local newBackgroundScale = vec2(infoView.size.x * 0.5, infoView.size.y * 0.5 / heightMultiplier)
            infoView.scale3D = vec3(newBackgroundScale.x, newBackgroundScale.y, infoView.scale3D.z)
            
            containerView.size = infoView.size
       -- else
            --containerView.hidden = false
            --containerView.size = infoView.size
        end
    end

    --local objectImageViewSize = vec2(100,100)

    inspectUI.gameObjectView = objectImageView
    --gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    --gameObjectView.baseOffset = vec3(0,-10, 2)

    local titleTextView = TextView.new(containerView)
    inspectUI.titleTextView = titleTextView
    titleTextView.font = Font(uiCommon.fontName, 16)
    titleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    titleTextView.baseOffset = vec3(124,-10,0)
    titleTextView.color = mj.textColor
    
    local textEntrySize = vec2(200.0,24.0)
    local  nameTextEntry = uiTextEntry:create(containerView, textEntrySize, uiTextEntry.types.standard_10x3, MJPositionInnerLeft, locale:get("ui_action_editName"))
    inspectUI.nameTextEntry = nameTextEntry
    uiTextEntry:setMaxChars(nameTextEntry, 40)
    nameTextEntry.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    nameTextEntry.baseOffset = vec3(120,-10,2)
    --uiTextEntry:setText(ipTextEntry, ipText)
    uiTextEntry:setFunction(nameTextEntry, function(newValue)
        changeObjectName(newValue)
    end)
    nameTextEntry.hidden = true

    
        
    debugIDText = TextView.new(containerView)
    debugIDText.font = Font(uiCommon.fontName, 14)
    debugIDText.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
   -- debugIDText.baseOffset = vec3(-60,-100,4)
    debugIDText.baseOffset = vec3(-16,-2,2)
    debugIDText.color = mj.textColor


    local debugButton = uiStandardButton:create(containerView, vec2(60.0,20.0))
    debugButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    debugButton.relativeView = debugIDText
    debugButton.baseOffset = vec3(10,0,0)
    uiStandardButton:setText(debugButton, locale:get("misc_debug"))
    uiStandardButton:setClickFunction(debugButton, function()
        gameUI:setDebugObject(inspectUI.baseObjectOrVertInfo, inspectUI.isTerrain)
    end)

    local cheatButton = nil
    if gameConstants.showCheatButtons then
        cheatButton = uiStandardButton:create(containerView, vec2(60.0,20.0))
        cheatButton.relativeView = debugButton
        cheatButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
        uiStandardButton:setText(cheatButton, locale:get("misc_cheat"))
        uiStandardButton:setClickFunction(cheatButton, function()
            local allObjectIDs = {}
            for objectID,info in pairs(inspectUI.selectedObjectOrVertInfosByID) do
                table.insert(allObjectIDs, objectID)
            end
            logicInterface:callServerFunction("cheatButtonClicked", allObjectIDs)
        end)
        inspectUI.cheatButton = cheatButton
    end

    
    local function updateHiddenStatus()
        if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu then
            debugButton.hidden = false
            if cheatButton then
                cheatButton.hidden = false
            end
            debugIDText.hidden = false
            if inspectUI.baseObjectOrVertInfo then
                debugIDText.text = inspectUI.baseObjectOrVertInfo.uniqueID
            end
        else
            debugButton.hidden = true
            debugIDText.hidden = true
            if cheatButton then
                cheatButton.hidden = true
            end
        end
    end

    clientGameSettings:addObserver("renderDebug", updateHiddenStatus)
    updateHiddenStatus()

    

    local modalPanelView = ModelView.new(inspectUI.mainView)

    
    modalPanelView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    local scaleToUse = modalPanelSize.x * 0.5
    modalPanelView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
    modalPanelView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    modalPanelView.size = modalPanelSize
    modalPanelView.hidden = true
    inspectUI.modalPanelView = modalPanelView

    --[[local closeButton = uiStandardButton:create(modalPanelView, vec2(50.0, 80.0), uiStandardButton.types.tab_1x1, nil)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    local unSelectedTabZOffset = -6.0
    local zOffset = unSelectedTabZOffset
    closeButton.baseOffset = vec3(0, -20, zOffset)
    uiStandardButton:setText(closeButton, "X")
    uiStandardButton:setClickFunction(closeButton, function()
        inspectUI:hideUIPanel(true)
    end)]]

    
    
    local closeButton = uiStandardButton:create(modalPanelView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        inspectUI:hideUIPanel(true)
    end)

    

    local modalPanelTitleView = View.new(modalPanelView)
    inspectUI.modalPanelTitleView = modalPanelTitleView
    modalPanelTitleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    modalPanelTitleView.baseOffset = vec3(0,-10, 0)
    modalPanelTitleView.size = vec2(200, 32.0)
    
    --[[local modalPanelTitleIcon = ModelView.new(modalPanelTitleView)
    inspectUI.modalPanelTitleIcon = modalPanelTitleIcon
    modalPanelTitleIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    modalPanelTitleIcon.scale3D = vec3(modalPanelTitleIconHalfSize,modalPanelTitleIconHalfSize,modalPanelTitleIconHalfSize)
    modalPanelTitleIcon.size = vec2(modalPanelTitleIconHalfSize,modalPanelTitleIconHalfSize) * 2.0]]

    local modalPanelTitleGameObjectView = uiGameObjectView:create(modalPanelTitleView, vec2(modalPanelTitleIconHalfSize,modalPanelTitleIconHalfSize) * 2.0, uiGameObjectView.types.backgroundCircle)
    inspectUI.modalPanelTitleGameObjectView = modalPanelTitleGameObjectView
    modalPanelTitleGameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)

    local modalPanelTitleTextView = ModelTextView.new(modalPanelTitleView)
    inspectUI.modalPanelTitleTextView = modalPanelTitleTextView
    modalPanelTitleTextView.font = Font(uiCommon.titleFontName, 36)
    modalPanelTitleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    --modalPanelTitleTextView.relativeView = modalPanelTitleGameObjectView
    --modalPanelTitleTextView.baseOffset = vec3(modalPanelTitleIconPadding, 0, 0)

    

    local titleTextEntry = nil
    local titleTextEntryEditButton = nil
    
    titleTextEntry = uiTextEntry:create(modalPanelView, textEntrySize, uiTextEntry.types.standard_10x3, nil, locale:get("ui_action_editName")) --note added to modalPanelView so it wont get hidden
    uiTextEntry:setMaxChars(titleTextEntry, 40)
    titleTextEntry.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleTextEntry.baseOffset = vec3(0, -10, 0)
    uiTextEntry:setFunction(titleTextEntry, function(newValue)
        if newValue and string.len(newValue) > 0 then
            changeObjectName(newValue)
            inspectUI:updateModalPanelMainTitleOnly(newValue)
            modalPanelTitleView.hidden = false
            titleTextEntry.hidden = true
        end
    end)
    titleTextEntry.hidden = true

    titleTextEntryEditButton = uiStandardButton:create(modalPanelTitleView, vec2(20,20), uiStandardButton.types.slim_1x1)
    inspectUI.titleTextEntryEditButton = titleTextEntryEditButton
    titleTextEntryEditButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    titleTextEntryEditButton.baseOffset = vec3(10, -2, 0)
    titleTextEntryEditButton.relativeView = modalPanelTitleTextView
    --titleTextEntryEditButton.hidden = true
    uiStandardButton:setIconModel(titleTextEntryEditButton, "icon_edit")
    uiStandardButton:setClickFunction(titleTextEntryEditButton, function()
        modalPanelTitleView.hidden = true
        local oldName = inspectUI.baseObjectOrVertInfo and inspectUI.baseObjectOrVertInfo.sharedState and inspectUI.baseObjectOrVertInfo.sharedState.name
        uiTextEntry:setText(titleTextEntry, oldName or "")
        titleTextEntry.hidden = false
        uiTextEntry:callClickFunction(titleTextEntry)
    end)
    uiToolTip:add(titleTextEntryEditButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_action_editName"), nil, vec3(0,-8,10), nil, titleTextEntryEditButton)

    local modalPanelSubTitleTextView = ModelTextView.new(modalPanelTitleView)
    inspectUI.modalPanelSubTitleTextView = modalPanelSubTitleTextView
    modalPanelSubTitleTextView.font = Font(uiCommon.titleFontName, 36)
    modalPanelSubTitleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    modalPanelSubTitleTextView.relativeView = titleTextEntryEditButton
    modalPanelSubTitleTextView.baseOffset = vec3(modalPanelTitleIconPadding * 2, 2, 0)

    inspectFollowerUI:load(gameUI, inspectUI, manageUI, hubUI, world, infoView)
    inspectObjectUI:load(gameUI, inspectUI, world, manageUI)
    inspectStorageUI:load(gameUI, inspectUI, world, inspectObjectUI)
    inspectTerrainUI:load(gameUI, inspectUI, world)
end

function inspectUI:setIconForObject(object)
    uiGameObjectView:setObject(inspectUI.gameObjectView, object, nil, nil)
end

function inspectUI:setIconForTerrain(vertInfo)
    --mj:log(vertInfo)
    --uiGameObjectView:setObject(inspectUI.gameObjectView, object, nil, nil)
end

local function updateModalPanelTitleViewSize()
    local subTitleWidth = 0
    if not inspectUI.modalPanelSubTitleTextView.hidden then
        subTitleWidth = inspectUI.modalPanelSubTitleTextView.size.x + modalPanelTitleIconPadding * 2
    end
   -- modalPanelTitleIconHalfSize + modalPanelTitleIconPadding
    local iconSize = 0
    local iconPadding = 0
    if not inspectUI.modalPanelTitleGameObjectView.hidden then
        iconSize = modalPanelTitleIconHalfSize + modalPanelTitleIconHalfSize
        iconPadding = modalPanelTitleIconPadding
    end

    local editButtonSize = 30
    if inspectUI.titleTextEntryEditButton.hidden then
        editButtonSize = 0
    end


    inspectUI.modalPanelTitleTextView.baseOffset = vec3(iconSize + modalPanelTitleIconPadding, 0, 0)

    inspectUI.modalPanelTitleView.size = vec2(inspectUI.modalPanelTitleTextView.size.x + iconSize + iconPadding + subTitleWidth + editButtonSize, inspectUI.modalPanelTitleTextView.size.y)
    --mj:log("size:", inspectUI.modalPanelTitleView.size)
    --mj:log("inspectUI.modalPanelTitleTextView.size:", inspectUI.modalPanelTitleTextView.size)
end


function inspectUI:updateModalPanelMainTitleOnly(newTitle)
    inspectUI.modalPanelTitleTextView:setText(newTitle, material.types.standardText.index)
    updateModalPanelTitleViewSize()
end

function inspectUI:setModalPanelTitleAndObject(objectNameOrMainTitle, object, subTitleTextOrNil, subTitleMaterialOrNil)
    inspectUI.modalPanelTitleTextView:setText(objectNameOrMainTitle, material.types.standardText.index)

    if subTitleTextOrNil then
        inspectUI.modalPanelSubTitleTextView:setText(subTitleTextOrNil, subTitleMaterialOrNil or material.types.standardText.index)
        inspectUI.modalPanelSubTitleTextView.hidden = false
    else
        inspectUI.modalPanelSubTitleTextView.hidden = true
    end
    

    if object then
        inspectUI.modalPanelTitleGameObjectView.hidden = false
        uiGameObjectView:setObject(inspectUI.modalPanelTitleGameObjectView, object, nil, nil)
    else
        inspectUI.modalPanelTitleGameObjectView.hidden = true
    end

    updateModalPanelTitleViewSize()
end

function inspectUI:showModalPanelView(containerView, panelUIObject)
    if currentModalContainerView ~= containerView then
        currentModalPanelUIObject = panelUIObject
        if currentModalContainerView then
            currentModalContainerView.hidden = true
            uiSelectionLayout:removeAnyActiveSelectionLayoutView()
        end
        --inspectUI:hideExtraButtons()
        currentModalContainerView = containerView
        currentModalContainerView.hidden = false
        inspectUI.modalPanelView.hidden = false
        hubUI:hideActionUIForInspectPanelDisplay()
    end
end

function inspectUI:setTitleText(objectName, allowTextEntry)
    inspectUI.objectName = objectName
    if allowTextEntry then
        uiTextEntry:setText(inspectUI.nameTextEntry, objectName)
    else
        inspectUI.titleTextView.text = objectName
    end

    inspectUI.titleTextView.hidden = allowTextEntry
    inspectUI.nameTextEntry.hidden = (not allowTextEntry)
    inspectUI.titleTextEntryEditButton.hidden = (not allowTextEntry)

    --mj:log("set:", allowTextEntry, " inspectUI.titleTextView.hidden:", inspectUI.titleTextView.hidden, " inspectUI.nameTextEntry.hidden:", inspectUI.nameTextEntry.hidden)
end

function inspectUI:getTitleText()
    return inspectUI.objectName
end

function inspectUI:containerViewIsHidden(containerView)
    return (not currentModalContainerView) or (currentModalContainerView ~= containerView) or currentModalContainerView.hidden
end

function inspectUI:showInspectPanelForActionUISelectedPlanType(planTypeIndex)
    currentSubUI:showInspectPanelForActionUISelectedPlanType(planTypeIndex)
end

function inspectUI:showInspectPanelForActionUIOptionsButton(planTypeIndex)
    if currentSubUI == inspectTerrainUI then
        currentSubUI:showInspectPanelForActionUIOptionsButton(planTypeIndex)
    end
end

function inspectUI:showTasksForCurrentSapien(backFunction)
    if currentSubUI == inspectFollowerUI then
        inspectFollowerUI:showTasksForCurrentSapien(backFunction)
    end
end

local prevObjectID = nil

function inspectUI:show(baseObjectOrVert, allObjectsOrVerts, isTerrain)
    prevObjectID = baseObjectOrVert.uniqueID
    local selectedObjectOrVertInfosByID = {}
    for i,objectOrVert in ipairs(allObjectsOrVerts) do
        selectedObjectOrVertInfosByID[objectOrVert.uniqueID] = objectOrVert
    end
    --[[if not currentModalContainerView then
        extraButtonBackgroundView.hidden = false
    end]]
    inspectUI.isTerrain = isTerrain
    inspectUI.selectedObjectOrVertInfoCount = #allObjectsOrVerts
    inspectUI.allObjectsOrVerts = allObjectsOrVerts
    inspectUI.selectedObjectOrVertInfosByID = selectedObjectOrVertInfosByID
    inspectUI.baseObjectOrVertInfo = baseObjectOrVert
    inspectUI.orderedObjectList = nil
    inspectUI.mainView.hidden = false
    inspectUI.containerParentView.hidden = false
    --[[local objectIDs = {}
    for i,objectInfo in ipairs(allObjects) do
        objectIDs[i] = objectInfo.uniqueID
    end]]

    if isTerrain then
        currentSubUI = inspectTerrainUI
    else
        if inspectUI.baseObjectOrVertInfo.objectTypeIndex == gameObject.types.sapien.index and playerSapiens:sapienIsFollower(inspectUI.baseObjectOrVertInfo.uniqueID) then
            currentSubUI = inspectFollowerUI
        elseif gameObject.types[inspectUI.baseObjectOrVertInfo.objectTypeIndex].isStorageArea then
            currentSubUI = inspectStorageUI
        else
            currentSubUI = inspectObjectUI
        end
    end

    if not debugIDText.hidden then
        debugIDText.text = inspectUI.baseObjectOrVertInfo.uniqueID
    end
    
    currentSubUI:show(inspectUI.baseObjectOrVertInfo, allObjectsOrVerts)

    if #allObjectsOrVerts == 1 then
        registerStateChanges(inspectUI.baseObjectOrVertInfo.uniqueID)
    end
end

function inspectUI:hasUIPanelDisplayed()
    if not inspectUI:hidden() then
        return not inspectUI.modalPanelView.hidden
    end
    return false
end

function inspectUI:popUI()
    if inspectUI:hasUIPanelDisplayed() then
        
        if currentModalPanelUIObject then
            if currentModalPanelUIObject:popUI() then
                return true
            end 
        end

        inspectUI:hideUIPanel(true)
        return true
    end
    --[[if (not inspectUI:hidden()) and (not inspectUI.modalPanelView.hidden) then
        inspectUI.modalPanelView.hidden = true]]

    --inspectUI:hideUIPanel(true)
    return false
end

function inspectUI:hideUIPanel(hideInspectUIToo)
    if (not inspectUI:hidden()) and (not inspectUI.modalPanelView.hidden) then
        inspectUI.modalPanelView.hidden = true

        if currentModalContainerView then
            currentModalContainerView.hidden = true
            uiSelectionLayout:removeAnyActiveSelectionLayoutView()
            currentModalContainerView = nil
            currentModalPanelUIObject = nil
            
            --hubUI:showActionUIForInspectPanelHidden()
            hubUI:hideInspectUI()
        end
        manageButtonsUI:updateHiddenState()
    end
    
    if not hideInspectUIToo then
        gameUI:interact(prevObjectID, false)
    end

    gameUI:updateUIHidden()
end

function inspectUI:hideInspectUI()
    hubUI:hideInspectUI()
end

function inspectUI:hideIfNeeded()
    if not inspectUI.mainView.hidden then

       -- if not gameUI:inspectUIShouldBeDisplayed() then
            deregisterStateChanges()
            inspectUI.mainView.hidden = true
            inspectUI.containerParentView.hidden = true
            inspectUI.selectedObjectOrVertInfosByID = nil
            inspectUI.baseObjectOrVertInfo = nil

            inspectUI:hideUIPanel(true)
            inspectFollowerUI:hide()
            inspectStorageUI:hide()
            inspectObjectUI:hide()
            inspectTerrainUI:hide()
       -- end
    end
end

function inspectUI:hidden()
    return (inspectUI.mainView.hidden)
end


return inspectUI