local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local length2 = mjm.length2
--local length = mjm.length
--local vec4 = mjm.vec4
local normalize = mjm.normalize
local mat3LookAtInverse = mjm.mat3LookAtInverse

local model = mjrequire "common/model"
--local order = mjrequire "common/order"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"
local physicsSets = mjrequire "common/physicsSets"
local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"

local logicInterface = mjrequire "mainThread/logicInterface"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
--local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"
--local uiObjectManager = mjrequire "mainThread/uiObjectManager"
local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local audio = mjrequire "mainThread/audio"
local eventManager = mjrequire "mainThread/eventManager"
local inspectUI = mjrequire "mainThread/ui/inspect/inspectUI"

local localPlayer = nil
local gameUI = nil

local objectMoveUI = {}

local objectIDs = nil

local mainView = nil
local titleView = nil
--local subTitleView = nil
local iconView = nil
local moveMarkerWorldView = nil
local world = nil
--local moveToObjectID = nil

local iconHalfSize = 20.0

function objectMoveUI:setLocalPlayer(localPlayer_, world_) 
    localPlayer = localPlayer_
    world = world_
end

local function updateTitleText()

    --local baseObjectType = gameObject.types[objectInfo.objectTypeIndex]

    local titleText = inspectUI:getTitleText() or ""

    titleView:setText(locale:get("ui_moveObject", { objectName = titleText}), material.types.standardText.index)
    iconView:setModel(model:modelIndexForName("icon_destinationPin"))
    
    local maxWidth = math.max(200, titleView.size.x + 30 + iconHalfSize * 2.0)
    local height = titleView.size.y + 10
    --[[if not subTitleView.hidden then
        height = height + subTitleView.size.y
        maxWidth = math.max(maxWidth, subTitleView.size.x + 20)
    end]]
    
    local sizeToUse = vec2(maxWidth, height)
    local scaleToUseX = sizeToUse.x * 0.5
    local scaleToUseY = sizeToUse.y * 0.5 / 0.4
    mainView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
    mainView.size = sizeToUse

end

function objectMoveUI:load(gameUI_)
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

    --[[local escapeWhenDoneComplexArray = {
        {
            text = locale:get("storage_ui_hit"),
        },
        {
            keyboardController = {
                keyboard = {
                    {
                        keyImage = {
                            groupKey = "game", 
                            mappingKey = "escape",
                        }
                    },
                },
                controller = {
                    controllerImage = {
                        controllerSetIndex = eventManager.controllerSetIndexInGame,
                        controllerActionName = "cancel"
                    }
                }
            }
        },
        {
            text = locale:get("storage_ui_whenDone"),
        },

    }
    subTitleView = uiComplexTextView:create(mainView, escapeWhenDoneComplexArray, nil)
    subTitleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    subTitleView.relativeView = titleView
    subTitleView.baseOffset = vec3(-iconHalfSize,0,0)]]
    
    updateTitleText()
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "confirm", function(isDown)
        if isDown and (not mainView.hidden) then
            local result = objectMoveUI:doClick()
            objectMoveUI:hide()
            return result
        end
        return false
    end)

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
        pos = lookAtPos,-- + lookAtPosNormal * mj:mToP(0.25),
        rotation = rotation
    }
end

local displayedCanMove = false
local displayedMovePosition = nil

local function updateDisplay(canMove, posInfo, lookAtObjectID, lookAtObjectIsBed)

    if displayedCanMove ~= canMove then
        if moveMarkerWorldView then
            worldUIViewManager:removeView(moveMarkerWorldView.uniqueID)
            moveMarkerWorldView = nil
        end
        displayedCanMove = canMove
    end

    displayedMovePosition = posInfo.lookAtPos

    --[[

    local midPoint = (endPos + startPos) * 0.5
    local midPointNormal = normalize(midPoint)
    local directionVec = startPos - endPos
    local directionDistance = length(directionVec)
    local directionNormal = directionVec / directionDistance
    local zLookVec = normalize(cross(directionNormal, -midPointNormal))
    local vecUp = normalize(cross(directionNormal, zLookVec))
    local rotationMatrix = mat3LookAtInverse(zLookVec, vecUp)

    
    local worldView = worldUIViewManager:addView(midPoint, worldUIViewManager.groups.storageLogistics, {
        constantRotationMatrix = rotationMatrix,
        renderXRay = true,
        renderWhenCenterBehindCamera = true,
    })

    
        worldUIViewManager:removeView(additionalLineInfosByType[additionalLineTypes.currentLoopLine].uniqueID)
    ]]

    if not moveMarkerWorldView then
        local materialSubstitute = material.types.ui_greenBright.index
        if not displayedCanMove then
            materialSubstitute = material.types.red.index
        end

        --[[moveMarkerModel = uiObjectManager:addUIModel(
            model:modelIndexForName(modelName),
            vec3(0.4,0.4,0.4),
            posInfo.pos,
            posInfo.rotation,
            materialSubstitute
            )]]

        moveMarkerWorldView = worldUIViewManager:addView(posInfo.pos, 
        worldUIViewManager.groups.moveUIDestinationMarker, {
            constantRotationMatrix = posInfo.rotation,
            renderXRay = true,
        })

        
        local modelView = ModelView.new(moveMarkerWorldView.view)
        modelView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        modelView:setModel(model:modelIndexForName("ui_moveArrow"), {
            default = materialSubstitute
        })
        local scaleToUse = 0.4
        modelView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
        --modelView.size = vec2(view.size.x, view.size.y)


    else
        
        worldUIViewManager:updateView(moveMarkerWorldView.uniqueID, posInfo.pos, nil, nil, nil, nil, posInfo.rotation)

        --[[uiObjectManager:updateUIModel(
            moveMarkerModel,
            posInfo.pos,
            posInfo.rotation,
        1.0,
            world.isVR
        )]]
    end

    --moveToObjectID = lookAtObjectID
    
end


function objectMoveUI:show(objectIDs_, baseObjectInfo_)
   -- mj:error("objectMoveUI:show()")
   -- mj:log("objectMoveUI:show:", sapienIDs_)
    if mainView.hidden then
        mainView.hidden = false
        gameUI:updateWarningNoticeForTopPanelDisplayed(-mainView.size.y - 20)
    end
    objectIDs = objectIDs_

    objectMoveUI:update()
    updateTitleText()

end

local maxRayHitDistanceFromDesriedPosition = mj:mToP(0.2)
local maxRayHitDistanceFromDesriedPosition2 = maxRayHitDistanceFromDesriedPosition * maxRayHitDistanceFromDesriedPosition

function objectMoveUI:update()
    if not objectMoveUI:hidden() then
        
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

function objectMoveUI:hide()
    if mainView and not mainView.hidden then
        mainView.hidden = true
        gameUI:updateWarningNoticeForTopPanelWillHide()
        if moveMarkerWorldView then
            worldUIViewManager:removeView(moveMarkerWorldView.uniqueID)
            moveMarkerWorldView = nil
        end
    end
    gameUI:updateUIHidden()
end

function objectMoveUI:hidden()
    return (mainView and mainView.hidden)
end

function objectMoveUI:terrainOrObjectClicked(wasTerrain, buttonIndex)
    if buttonIndex == 0 then
        if displayedMovePosition and displayedCanMove then
            objectMoveUI:doClick()
        end
        objectMoveUI:hide()
    end
end


function objectMoveUI:doClick()
    if displayedMovePosition and displayedCanMove then
        audio:playUISound("audio/sounds/place.wav")
        --[[logicInterface:callServerFunction("addObjectMoveOrder", {
            objectIDs = objectIDs,
            moveToPos = localPlayer.lookAtPosition,
            moveToObjectID = moveToObjectID,
        })]]

        local addInfo = {
            planTypeIndex = plan.types.haulObject.index,
            objectOrVertIDs = objectIDs,
            moveToPos = localPlayer.lookAtPosition,
        }
        logicInterface:callServerFunction("addPlans", addInfo)

        return true
    end
    return false
end

return objectMoveUI