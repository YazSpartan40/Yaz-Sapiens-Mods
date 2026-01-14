local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4
local length = mjm.length
local cross = mjm.cross
local normalize = mjm.normalize
local mat3LookAtInverse = mjm.mat3LookAtInverse

local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
--local order = mjrequire "common/order"
local material = mjrequire "common/material"

local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"

local gameObject = mjrequire "common/gameObject"

local logicInterface = mjrequire "mainThread/logicInterface"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"


local uiRouteInfo = nil


local storageLogisticsDestinationsUI = {}

local mainView = nil
local topView = nil
local titleView = nil
local subTitleView = nil

local localPlayer = nil
local world = nil
local gameUI = nil

local currentMarkerLookAtID = nil

local iconHalfSize = 20

local mainConnectionLineViews = {} --not tested or supported, left here in case for now

local additionalLineTypes = mj:enum {
    "hoverDestination",
}

local additionalLineInfosByType = {}

local lineTextures = {"img/routeArrow.png", "img/icons/flat.png"}

function storageLogisticsDestinationsUI:setLocalPlayer(localPlayer_, world_) 
    localPlayer = localPlayer_
    world = world_
end

local function updateTitle()
    local maxWidth = math.max(200, titleView.size.x + 30 + iconHalfSize * 2.0)
    maxWidth = math.max(maxWidth, subTitleView.size.x + 20)

    local height = titleView.size.y + 10 + subTitleView.size.y + 4
    local sizeToUse = vec2(maxWidth, height)

    local scaleToUseX = sizeToUse.x * 0.5
    local scaleToUseY = sizeToUse.y * 0.5 / 0.4
    topView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
    topView.size = sizeToUse
end


local function addOrUpdateLine(startPos, endPos, lineTypeOrNil)
    local midPoint = (endPos + startPos) * 0.5
    local midPointNormal = normalize(midPoint)
    local directionVec = startPos - endPos
    local directionDistance = length(directionVec)
    local directionNormal = directionVec / directionDistance
    local zLookVec = normalize(cross(directionNormal, -midPointNormal))
    local vecUp = normalize(cross(directionNormal, zLookVec))
    local rotationMatrix = mat3LookAtInverse(zLookVec, vecUp)

    local lineInfo = nil
    if lineTypeOrNil and additionalLineInfosByType[lineTypeOrNil] then
        lineInfo = additionalLineInfosByType[lineTypeOrNil]

        worldUIViewManager:updateView(lineInfo.worldView.uniqueID, {
            basePos = midPoint,
            constantRotationMatrix = rotationMatrix,
        })
    else
        local worldView = worldUIViewManager:addView(midPoint, worldUIViewManager.groups.storageLogistics, {
            constantRotationMatrix = rotationMatrix,
            renderXRay = true,
            renderWhenCenterBehindCamera = true,
        })

        local lineView = ModelImageView.new(worldView.view)
        lineView:setShader("uiAnimatedLineWorld")
        lineView:setTextures(lineTextures[1], lineTextures[2]) 
        lineView.masksEvents = false
        lineView.rotation = mjm.mat3Rotate(mjm.mat3Identity, math.pi * 0.5, vec3(1.0,0.0,0.0))

        if lineTypeOrNil then
            lineInfo = {
                worldView = worldView,
                lineView = lineView,
            }
            additionalLineInfosByType[lineTypeOrNil] = lineInfo
        else
            table.insert(mainConnectionLineViews, worldView)
        end
    end

    lineInfo.lineView.size = vec2(mj:pToM(directionDistance), 0.5)
    local shaderUniformY = 1.0
    local shaderUniformZ = 0.0
    lineInfo.lineView.shaderUniformA = vec4(mj:pToM(directionDistance) * 2.0, shaderUniformY, shaderUniformZ, 0.0)

    return lineInfo
end

local function updateLineViews()
    if mainConnectionLineViews then
        for i,worldView in ipairs(mainConnectionLineViews) do
            worldUIViewManager:removeView(worldView.uniqueID)
        end
        mainConnectionLineViews = {}
    end

    --if uiRouteInfo then
        --[[local destinations = uiRouteInfo.destinations 
        if destinations and #destinations > 1 then
            for i, destination in ipairs(destinations) do
                if i < #destinations then
                    local sourceID = destination.uniqueID
                    local destinationID = destinations[i + 1].uniqueID
                    local sourceObjectInfo = uiRouteInfo.objectInfos[sourceID]
                    local detsinationObjectInfo = uiRouteInfo.objectInfos[destinationID]
                    if sourceObjectInfo and detsinationObjectInfo then
                        addOrUpdateLine(sourceObjectInfo.pos, detsinationObjectInfo.pos, nil)
                    end
                end
            end
        end]]
    --end
end


function storageLogisticsDestinationsUI:load(gameUI_, manageUI_)
    gameUI = gameUI_
    --manageUI = manageUI_
    
    mainView = View.new(gameUI.worldViews)
    mainView.hidden = true
    mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    
    topView = ModelView.new(mainView)
    topView:setModel(model:modelIndexForName("ui_panel_10x4"))
    topView.alpha = 0.9
    topView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    topView.baseOffset = vec3(0, -20, 0)


    titleView = ModelTextView.new(topView)
    titleView.font = Font(uiCommon.fontName, 36)
    titleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleView.baseOffset = vec3(iconHalfSize, -6, 0)
    
    local iconView = ModelView.new(topView)
    iconView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    iconView.relativeView = titleView
    iconView.baseOffset = vec3(-5,0,0)
    iconView:setModel(model:modelIndexForName("icon_logistics"))
    iconView.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    iconView.size = vec2(iconHalfSize,iconHalfSize) * 2.0

    
    subTitleView = TextView.new(topView)
    subTitleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    subTitleView.relativeView = titleView
    subTitleView.font = Font(uiCommon.fontName, 16)
    subTitleView.color = mj.textColor
    subTitleView.baseOffset = vec3(-iconHalfSize,-4,0)

end

local function hideNextDestinationSelectionUI()
    if additionalLineInfosByType[additionalLineTypes.hoverDestination] then
        worldUIViewManager:removeView(additionalLineInfosByType[additionalLineTypes.hoverDestination].worldView.uniqueID)
        additionalLineInfosByType[additionalLineTypes.hoverDestination] = nil
    end
end

function storageLogisticsDestinationsUI:show(routeInfo_)
    uiRouteInfo = routeInfo_
    worldUIViewManager:setAllHiddenExceptGroupsSet({
        [worldUIViewManager.groups.storageLogistics] = true,
        [worldUIViewManager.groups.interestTradeRequestMarker] = true,
        [worldUIViewManager.groups.interestQuestMarker] = true,
    })
    --mj:log("uiRouteInfo:", uiRouteInfo)
    local subTitleText = nil
    local titleText = nil
    if not uiRouteInfo.from then
        subTitleText = locale:get("misc_selectRouteFrom")
        titleText = locale:get("misc_selectRouteFromTitle")
    else
        subTitleText = locale:get("misc_selectRouteTo")
        titleText = locale:get("misc_selectRouteToTitle")
    end

    titleView:setText(titleText, material.types.standardText.index)
    subTitleView.text = subTitleText


    hideNextDestinationSelectionUI()

    updateTitle()
    updateLineViews()

    if mainView.hidden then
        mainView.hidden = false
        gameUI:updateWarningNoticeForTopPanelDisplayed(-topView.size.y - 10)
    end
end

function storageLogisticsDestinationsUI:update()
    if not storageLogisticsDestinationsUI:hidden() then
        if (not currentMarkerLookAtID) then
            local lookAtPosition = localPlayer.lookAtPositionMainThread or localPlayer.lookAtPosition
            local lineInfo = nil
            if uiRouteInfo.fromPos then
                lineInfo = addOrUpdateLine(uiRouteInfo.fromPos, lookAtPosition, additionalLineTypes.hoverDestination)
            elseif uiRouteInfo.toPos then
                lineInfo = addOrUpdateLine(lookAtPosition, uiRouteInfo.toPos, additionalLineTypes.hoverDestination)
            end
            if lineInfo then
                local uniformVec = lineInfo.lineView.shaderUniformA
                local shaderUniformY = 0.0
                lineInfo.lineView.shaderUniformA = vec4(uniformVec.x, shaderUniformY, uniformVec.z, uniformVec.w)
            end
        end
    end
end
        
    --end


function storageLogisticsDestinationsUI:updateLookAtObject(uniqueID)
    if (not currentMarkerLookAtID) or currentMarkerLookAtID ~= uniqueID then
        --hideNextDestinationSelectionUI()

        local lookAtObject = localPlayer.retrievedLookAtObject
        if uniqueID and lookAtObject then
            local gameObjectType = gameObject.types[lookAtObject.objectTypeIndex]
            if gameObjectType.isStorageArea then
                if uiRouteInfo.fromPos then
                    addOrUpdateLine(uiRouteInfo.fromPos, lookAtObject.pos, additionalLineTypes.hoverDestination)
                elseif uiRouteInfo.toPos then
                    addOrUpdateLine(lookAtObject.pos, uiRouteInfo.toPos, additionalLineTypes.hoverDestination)
                end
                currentMarkerLookAtID = uniqueID
            end
        else
            currentMarkerLookAtID = nil
        end
    end
end

function storageLogisticsDestinationsUI:terrainOrObjectClicked(terrainClicked, buttonIndex)
    if localPlayer.retrievedLookAtObject then
        local gameObjectType = gameObject.types[localPlayer.retrievedLookAtObject.objectTypeIndex]
        if gameObjectType.isStorageArea then
            local destinationObjectID = localPlayer.retrievedLookAtObject.uniqueID

            local additionInfo = {
                routeID = uiRouteInfo.routeID
            }

            if uiRouteInfo.fromPos then
                additionInfo.to = destinationObjectID
            else
                additionInfo.from = destinationObjectID
            end
            
            logicInterface:callServerFunction("addLogisticsRouteDestination", additionInfo , function(result)
                if mainView.hidden then
                    return
                end

                if result.success then
                    local serverRouteInfo = result.routeInfo
                    local logisticsRoutes = world:getLogisticsRoutes()
                    logisticsRoutes.routes[uiRouteInfo.routeID] = serverRouteInfo


                    tutorialUI:secondDestinationWasAddedToRoute()
                    
                    storageLogisticsDestinationsUI:hide()


                    gameUI:displayInspectUIForLookAtObject(terrainClicked, {dismissAnyUI = true, showInspectUI = true, completActionIndex = 1})
                    
                end
            end)
        end
    end
end

function storageLogisticsDestinationsUI:hide()
    if mainView and not mainView.hidden then
        mainView.hidden = true
        gameUI:updateWarningNoticeForTopPanelWillHide()

        if mainConnectionLineViews then
            for i,worldView in ipairs(mainConnectionLineViews) do
                worldUIViewManager:removeView(worldView.uniqueID)
            end
        end
        mainConnectionLineViews = {}
        
        hideNextDestinationSelectionUI()

        currentMarkerLookAtID = nil

        worldUIViewManager:unhideAllGroups()
        gameUI:updateUIHidden()
    end
end

function storageLogisticsDestinationsUI:popUI()
    if mainView and not mainView.hidden then
        storageLogisticsDestinationsUI:hide()
    end
end

function storageLogisticsDestinationsUI:hidden()
    return (mainView and mainView.hidden)
end


return storageLogisticsDestinationsUI