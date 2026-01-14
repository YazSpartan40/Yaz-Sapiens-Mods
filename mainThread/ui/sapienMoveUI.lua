local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local length2 = mjm.length2
--local vec4 = mjm.vec4
local normalize = mjm.normalize
local mat3LookAtInverse = mjm.mat3LookAtInverse

local model = mjrequire "common/model"
--local order = mjrequire "common/order"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"
local physicsSets = mjrequire "common/physicsSets"
local gameObject = mjrequire "common/gameObject"

local logicInterface = mjrequire "mainThread/logicInterface"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"
local uiObjectManager = mjrequire "mainThread/uiObjectManager"
local audio = mjrequire "mainThread/audio"
local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"

local localPlayer = nil
local gameUI = nil

local sapienMoveUI = {}

local sapienIDs = nil
local addWaitOrder = false

local mainView = nil
local titleView = nil
local subTitleView = nil
local iconView = nil
local moveMarkerModel = nil
local world = nil
local assignBed = false
local moveToObjectID = nil

local iconHalfSize = 20.0

function sapienMoveUI:setLocalPlayer(localPlayer_, world_) 
    localPlayer = localPlayer_
    world = world_
end

local function updateTitleText()

    if assignBed and moveToObjectID then
        titleView:setText(locale:get("ui_name_assignBed"), material.types.standardText.index)
        iconView:setModel(model:modelIndexForName("icon_bed"))
    else
        if addWaitOrder then
            titleView:setText(locale:get("ui_name_moveAndWait"), material.types.standardText.index)
            iconView:setModel(model:modelIndexForName("icon_moveAndWait"))
        else
            titleView:setText(locale:get("ui_name_move"), material.types.standardText.index)
            iconView:setModel(model:modelIndexForName("icon_feet"))
        end
    end
    
    local maxWidth = math.max(200, titleView.size.x + 30 + iconHalfSize * 2.0)
    local height = titleView.size.y + 10
    if not subTitleView.hidden then
        height = height + subTitleView.size.y
        maxWidth = math.max(maxWidth, subTitleView.size.x + 20)
    end

    --mj:log("titleView.size.y:", titleView.size.y, " subTitleView.size.y:", subTitleView.size.y)
    
    local sizeToUse = vec2(maxWidth, height)
    local scaleToUseX = sizeToUse.x * 0.5
    local scaleToUseY = sizeToUse.y * 0.5 / 0.4
    mainView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
    mainView.size = sizeToUse

    --mj:log("scaleToUseX:", scaleToUseX, " scaleToUseY:", scaleToUseY, " sizeToUse:", sizeToUse)

end

local keyMap = {
    [keyMapping:getMappingIndex("game", "moveCommandAddWaitOrderModifier")] = function(isDown, isRepeat) 
        addWaitOrder = isDown 
        if not sapienMoveUI:hidden() then
            updateTitleText()
        end
        return false 
    end,
}

local function keyChanged(isDown, mapIndexes, isRepeat)
    for i, mapIndex in ipairs(mapIndexes) do
        if keyMap[mapIndex]  then
            if keyMap[mapIndex](isDown, isRepeat) then
                return true
            end
        end
    end
    return false
end

function sapienMoveUI:load(gameUI_)
    gameUI = gameUI_
    
    mainView = ModelView.new(gameUI.worldViews)
    mainView:setModel(model:modelIndexForName("ui_panel_10x4"))
    mainView.hidden = true
    mainView.alpha = 0.9
    mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    mainView.baseOffset = vec3(0, -20, 0)

    titleView = ModelTextView.new(mainView)
    titleView.font = Font(uiCommon.fontName, 36)
    titleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleView.baseOffset = vec3(iconHalfSize, -6, 0)
    

    iconView = ModelView.new(mainView)
    iconView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    iconView.relativeView = titleView
    iconView.baseOffset = vec3(-5,0,0)
    iconView.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    iconView.size = vec2(iconHalfSize,iconHalfSize) * 2.0

    local escapeWhenDoneComplexArray = {
        {
            text = locale:get("ui_name_moveAndWait"),
        },
        {
            keyboardController = {
                keyboard = {
                    {
                        keyImage = {
                            groupKey = "game", 
                            mappingKey = "moveCommandAddWaitOrderModifier",
                        }
                    },
                },
                controller = { --todo
                    controllerImage = {
                        controllerSetIndex = eventManager.controllerSetIndexInGame,
                        controllerActionName = "cancel"
                    }
                }
            }
        },

    }
    subTitleView = uiComplexTextView:create(mainView, escapeWhenDoneComplexArray, nil)
    subTitleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    subTitleView.relativeView = titleView
    subTitleView.baseOffset = vec3(-iconHalfSize,0,0)
    
    updateTitleText()
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "confirm", function(isDown)
        if isDown and (not mainView.hidden) then
            return sapienMoveUI:doClick()
        end
        return false
    end)
    
    eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)

end

local function getUpdatedPositionInfo()
    local lookAtPos =  localPlayer.lookAtPosition
    if localPlayer.lookAtPositionMainThread then
        lookAtPos = localPlayer.lookAtPositionMainThread
    end
    local lookAtPosNormal = normalize(lookAtPos)
    local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)
    local rotation = mat3LookAtInverse(directionNormal, lookAtPosNormal)

    return {
        lookAtPos = lookAtPos,
        lookAtPosNormal = lookAtPosNormal,
        pos = lookAtPos + lookAtPosNormal * mj:mToP(0.25),
        rotation = rotation
    }
end

local displayedCanMove = false
local displayedMovePosition = nil

local function updateDisplay(canMove, posInfo, lookAtObjectID, lookAtObjectIsBed)

    if displayedCanMove ~= canMove then
        if moveMarkerModel then
            uiObjectManager:removeUIModel(moveMarkerModel)
            moveMarkerModel = nil
        end
        displayedCanMove = canMove
    end

    displayedMovePosition = posInfo.lookAtPos

    if not moveMarkerModel then
        local materialSubstitute = 0
        if not displayedCanMove then
            materialSubstitute = material.types.red.index
        end

        local modelName = "ui_moveArrow"

        moveMarkerModel = uiObjectManager:addUIModel(
            model:modelIndexForName(modelName),
            vec3(0.2,0.2,0.2),
            posInfo.pos,
            posInfo.rotation,
            materialSubstitute
            )
    else
        uiObjectManager:updateUIModel(
            moveMarkerModel,
            posInfo.pos,
            posInfo.rotation,
            1.0,
            world.isVR
        )
    end

    moveToObjectID = lookAtObjectID
    if assignBed ~= lookAtObjectIsBed then
        assignBed = lookAtObjectIsBed
        updateTitleText()
    end
    
end


function sapienMoveUI:show(sapienIDs_)
   -- mj:error("sapienMoveUI:show()")
   -- mj:log("sapienMoveUI:show:", sapienIDs_)
    if mainView.hidden then
        mainView.hidden = false
        gameUI:updateWarningNoticeForTopPanelDisplayed(-mainView.size.y - 20)
    end
    sapienIDs = sapienIDs_

    sapienMoveUI:update()
    updateTitleText()

end

local maxRayHitDistanceFromDesriedPosition = mj:mToP(0.2)
local maxRayHitDistanceFromDesriedPosition2 = maxRayHitDistanceFromDesriedPosition * maxRayHitDistanceFromDesriedPosition

function sapienMoveUI:update()
    if not sapienMoveUI:hidden() then
        
        local posInfo = getUpdatedPositionInfo()

        local canMove = false
        local rayStart = posInfo.lookAtPos + posInfo.lookAtPosNormal * mj:mToP(1.5)
        local rayEnd = posInfo.lookAtPos - posInfo.lookAtPosNormal * mj:mToP(1.2)
        local rayResult = world:rayTest(rayStart, rayEnd, nil, physicsSets.walkable, true)
        if rayResult.hasHitTerrain or rayResult.hasHitObject or rayResult.hasHitSeaLevel then
            if rayResult.hasHitObject and length2(rayResult.objectCollisionPoint - posInfo.lookAtPos) > maxRayHitDistanceFromDesriedPosition2 then
                canMove = false
            else
                canMove = true
            end
        else
            canMove = false
        end

        local lookAtObjectID = nil
        local lookAtObjectIsBed = false
        if localPlayer.lookAtMeshType == MeshTypeGameObject and localPlayer.retrievedLookAtObject and localPlayer.retrievedLookAtObject.uniqueID == localPlayer.lookAtID then
            lookAtObjectID = localPlayer.retrievedLookAtObject.uniqueID
            if gameObject.types[localPlayer.retrievedLookAtObject.objectTypeIndex].isBed then
                lookAtObjectIsBed = true
            end
        end

        updateDisplay(canMove, posInfo, lookAtObjectID, lookAtObjectIsBed)
    end
end

function sapienMoveUI:hide()
    if mainView and not mainView.hidden then
        mainView.hidden = true
        gameUI:updateWarningNoticeForTopPanelWillHide()
        if moveMarkerModel then
            uiObjectManager:removeUIModel(moveMarkerModel)
            moveMarkerModel = nil
        end
    end
    gameUI:updateUIHidden()
end

function sapienMoveUI:hidden()
    return (mainView and mainView.hidden)
end

function sapienMoveUI:terrainOrObjectClicked(wasTerrain, buttonIndex)
    if buttonIndex == 0 then
        if displayedMovePosition and displayedCanMove then
            sapienMoveUI:doClick()
        end
        --sapienMoveUI:hide()
    end
end


function sapienMoveUI:doClick()
    if displayedMovePosition and displayedCanMove then
        audio:playUISound("audio/sounds/place.wav")
        logicInterface:callServerFunction("addMoveOrder", {
            sapienIDs = sapienIDs,
            moveToPos = localPlayer.lookAtPosition,
            addWaitOrder = addWaitOrder,
            assignBed = assignBed,
            moveToObjectID = moveToObjectID,
        })
        return true
    end
    return false
end

return sapienMoveUI