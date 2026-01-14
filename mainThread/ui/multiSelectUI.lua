
local gameObject = mjrequire "common/gameObject"
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4
local normalize = mjm.normalize
local length2 = mjm.length2

local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
local selectionGroup = mjrequire "common/selectionGroup"
local terrainTypes = mjrequire "common/terrainTypes"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiPopUpButton = mjrequire "mainThread/ui/uiCommon/uiPopUpButton"

local logicInterface = mjrequire "mainThread/logicInterface"
local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"
local playerSapiens = mjrequire "mainThread/playerSapiens"
--local audio = mjrequire "mainThread/audio"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"

--local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"

local multiSelectUI = {}

local gameUI = nil
local hubUI = nil
local world = nil

local mainView = nil
local containerView = nil
local radarView = nil
local radarBackgroundView = nil
local radarSelectionBackgroundView = nil
local selectButton = nil
local radiusTextView = nil
local boxSelectView = nil
local terrainMapView = nil

local cameraIcon = nil
--local countTextView = nil

local titleTextView = nil
local selectedObjectCenteredView = nil
local subObjectsListTextView = nil
local gameObjectView = nil

local currentObject = nil
local currentVert = nil
local currentVertInfos = nil
local selectedVertInfos = nil

local playerPos = nil

local selectionGroupObjectTypeArrayIndex = 1
local saveSelectionGroupTypeIndexByObjectType = {}
local selectionGroupIndexToggleButtonsBackgroundView = nil
--local groupSelectionButtonA = nil
--local groupSelectionButtonB = nil

--local boxSelectButton = nil
--local radiusSelectButton = nil
local selectionToolPopUpButton = nil
local selectionFilterPopUpButton = nil

local viewRadius = 250.0
local backgroundPadding = 10.0
local backgroundRadius = viewRadius + backgroundPadding
local selectionRadius = viewRadius

local isRadiusSelect = false
local boxIsSubtract = false
local boxDragIsRightMouseButton = false
local shiftDown = false

local maxRadius = mj:mToP(50.0)
local radarItemsView = nil
local orthoMatrix = mjm.mat4Ortho(-maxRadius, maxRadius, -maxRadius, maxRadius, 0.0, -1.0)
local currentRadius = mj:mToP(10)
local currentRadius2 = currentRadius * currentRadius
local maxRadius2 = maxRadius * maxRadius

local boxSelectBoxOrigin = nil
local boxSelectBoxSize = nil

local radarRelativeBoxOrigin = nil
local radarRelativeBoxSize = nil

local selectedObjectIDs = nil

local markerInfos = {}
local selectedCount = 1
local markerTypes = mj:indexed {
    {
        key = "currentObject",
        textures = {"img/icons/circleStarRing.png", "img/icons/flat.png"},
        materialIndex = material.types.ui_selected.index,
        size = 30,
    },
    {
        key = "selected",
        textures = {"img/icons/circleRing.png", "img/icons/flat.png"},
        materialIndex = material.types.ui_selected.index,
        size = 30,
    },
    {
        key = "nonSelected",
        textures = {"img/icons/circle.png", "img/icons/flat.png"},
        materialIndex = material.types.ui_standard.index,
        size = 6,
    },
}

local boxSelectIDs = {}
local boxCurrentSelectionUncomfirmedAddIDMap = {}
local boxCurrentSelectionUncomfirmedSubtractIDMap = {}
local boxSelectedIDMap = {}

local function getCountWithObjectNameText()
    if selectedVertInfos then
        if selectedCount == 1 then
            return mj:tostring(selectedCount) .. " " .. locale:get("misc_hex")
        end
        return mj:tostring(selectedCount) .. " " .. locale:get("misc_hexes")
    elseif currentObject then
        local objectName = nil
        local additionalSelectionGroupTypeIndexes = gameObject.types[currentObject.objectTypeIndex].additionalSelectionGroupTypeIndexes
        if additionalSelectionGroupTypeIndexes and selectionGroupObjectTypeArrayIndex > 1 then
            local selectionGroupType = selectionGroup.types[additionalSelectionGroupTypeIndexes[selectionGroupObjectTypeArrayIndex - 1]]
            if selectedCount == 1 then
                objectName = selectionGroupType.readableName
            else
                objectName = selectionGroupType.plural
            end
        else
            local baseSelectionGroupTypeIndex = gameObject.types[currentObject.objectTypeIndex].baseSelectionGroupTypeIndex
            if baseSelectionGroupTypeIndex and selectionGroupObjectTypeArrayIndex == 1 then
                local selectionGroupType = selectionGroup.types[baseSelectionGroupTypeIndex]
                if selectedCount == 1 then
                    objectName = selectionGroupType.readableName
                else
                    objectName = selectionGroupType.plural
                end
            else

                if selectedCount == 1 then
                    objectName = gameObject.types[currentObject.objectTypeIndex].name
                else
                    objectName = gameObject.types[currentObject.objectTypeIndex].plural
                end
            end
        end
        return mj:tostring(selectedCount) .. " " .. objectName
    end
    return ""
end

local function updateTextViews()
    local text = getCountWithObjectNameText()
    titleTextView.text = text

    local subTitleHeight = 0

    if selectedVertInfos then
        subObjectsListTextView.hidden = false
        local vertText,hasMultipleLines = terrainTypes:getMultiLookAtName(selectedVertInfos, true)
        if hasMultipleLines then
            subObjectsListTextView.textAlignment = MJHorizontalAlignmentLeft
        else
            subObjectsListTextView.textAlignment = MJHorizontalAlignmentCenter
        end
        subObjectsListTextView.text = vertText
        subTitleHeight = subObjectsListTextView.size.y
    else
        subObjectsListTextView.hidden = true
    end

    selectedObjectCenteredView.size = vec2(
        math.max(math.max(gameObjectView.size.x, subObjectsListTextView.size.x), titleTextView.size.x), 
        gameObjectView.size.y + 10 + titleTextView.size.y + subTitleHeight
    )

    --uiStandardButton:setText(selectButton, text)

    local selectText = locale:get("ui_action_select") .. " " .. mj:tostring(selectedCount)
    uiStandardButton:setTextWithShortcut(selectButton, selectText, "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")

   -- uiToolTip:updateText(selectButton.userData.backgroundView, selectText, nil, false)
  --  uiToolTip:addKeyboardShortcut(selectButton.userData.backgroundView, "game", "confirm", nil, nil)

    
    local radiusFraction = currentRadius / maxRadius
    local hoverScaleToUse = selectionRadius * radiusFraction

    local radiusTextY = math.min(-hoverScaleToUse, -26) + 8
    --local countTextY = 16
    
    radiusTextView.text = mj:tostring(math.floor(mj:pToM(currentRadius))) .. "m"
    radiusTextView.baseOffset = vec3(0, radiusTextY, 0)
    
    --countTextView.text = getCountWithObjectNameText()
    --countTextView.baseOffset = vec3(0, countTextY, 0)
end


local function doSelect()
    --mj:error("doESelect")
    hubUI:hideMultiSelectUI()

    if currentVert then
        if selectedVertInfos and next(selectedVertInfos) then
            local vertIDArray = {}
            for uniqueID,vertInfo in pairs(selectedVertInfos) do
                table.insert(vertIDArray, uniqueID)
            end
            
            logicInterface:callLogicThreadFunction("getVertInfosForIDs", vertIDArray, function(vertInfos)
                if vertInfos and vertInfos[1] then
                    gameUI:multiSelectVertsReceived(currentVert, vertInfos)
                end
            end)
        else
            gameUI:multiSelectVertsReceived(currentVert, nil)
        end
        --gameUI:multiSelectVertsReceived(currentVert, vertInfoArray)
    elseif currentObject then
        if selectedObjectIDs and #selectedObjectIDs > 0 then
            logicInterface:callLogicThreadFunction("getGameObjectsForIDs", selectedObjectIDs, function(objectInfos)

                if currentObject and currentObject.objectTypeIndex == gameObject.types.sapien.index then
                    if currentObject.sharedState.tribeID == world.tribeID then
                        local foundSet = {}
                        for i,objectInfo in ipairs(objectInfos) do
                            foundSet[objectInfo.uniqueID] = true
                        end

                        for i, selectedObjectID in ipairs(selectedObjectIDs) do
                            if not foundSet[selectedObjectID] then
                                local sapienInfo = playerSapiens:getInfo(selectedObjectID)
                                if sapienInfo then
                                    table.insert(objectInfos, sapienInfo)
                                end
                            end
                        end
                    end
                end

                if objectInfos and objectInfos[1] then
                    gameUI:multiSelectObjectsReceived(currentObject, objectInfos)
                else
                    gameUI:multiSelectObjectsReceived(currentObject, nil)
                end
            end)
        else
            gameUI:multiSelectObjectsReceived(currentObject, nil)
        end
    end
end

--[[function multiSelectUI:enterPressed()
    doSelect()
end]]

--[[function selectionGroup:getAllObjectTypesForObject(gameObjectType)
    local objectTypes = {currentObject_.objectTypeIndex}
    local selectionGroupTypeIndexes = gameObject.types[currentObject_.objectTypeIndex].selectionGroupTypeIndexes
    if selectionGroupTypeIndexes then
        local additionalObjectTypes = selectionGroup:getGroupObjectTypesForSelectionGroupIndex(selectionGroupTypeIndexes[selectionGroupObjectTypeArrayIndex])
        for i,objectTypeIndex in ipairs(additionalObjectTypes) do
            if objectTypeIndex ~= currentObject_.objectTypeIndex then
                table.insert(objectTypes, objectTypeIndex)
            end
        end
    end
    return objectTypes
end]]

local function getObjectTypes()
    if not currentObject then
        return nil
    end
    local objectTypes = {currentObject.objectTypeIndex}

    local function addTypesForGroup(selectionGroupTypeIndex)
        local additionalObjectTypes = selectionGroup:getGroupObjectTypesForSelectionGroupIndex(selectionGroupTypeIndex)
        --mj:debug("additionalObjectTypes:", additionalObjectTypes, " type:", selectionGroup.types[selectionGroupTypeIndex])
        for i,objectTypeIndex in ipairs(additionalObjectTypes) do
            if objectTypeIndex ~= currentObject.objectTypeIndex then
                table.insert(objectTypes, objectTypeIndex)
            end
        end
    end

    if selectionGroupObjectTypeArrayIndex == 1 then
        if gameObject.types[currentObject.objectTypeIndex].baseSelectionGroupTypeIndex then
            addTypesForGroup(gameObject.types[currentObject.objectTypeIndex].baseSelectionGroupTypeIndex)
        end
    else
        local additionalSelectionGroupTypeIndexes = gameObject.types[currentObject.objectTypeIndex].additionalSelectionGroupTypeIndexes
        if additionalSelectionGroupTypeIndexes and additionalSelectionGroupTypeIndexes[selectionGroupObjectTypeArrayIndex - 1] then
            addTypesForGroup(additionalSelectionGroupTypeIndexes[selectionGroupObjectTypeArrayIndex - 1])
        end
    end

    --mj:log("selectionGroupObjectTypeArrayIndex:", selectionGroupObjectTypeArrayIndex, " objectTypes:", objectTypes, " gameObject.types[currentObject.objectTypeIndex]:", gameObject.types[currentObject.objectTypeIndex])

    return objectTypes
end


local function getTribeRestrictInfo()
    if currentObject then
        if currentObject.sharedState.tribeID then
            return {
                match = currentObject.sharedState.tribeID
            }
        end
    end
    return nil
end

local function setSelectionHighlights()
    local userData = nil
    if selectedObjectIDs and #selectedObjectIDs > 0 then
        userData = {
            objectIDs = selectedObjectIDs,
            brightness = 1.0
        }
    end
    logicInterface:callLogicThreadFunction("setSelectionHightlightForObjects", userData)
end


local function updateSelection()

    if currentVert and currentVertInfos then
        selectedCount = 0
        selectedObjectIDs = {}
        setSelectionHighlights()

        local playerPosNormal = normalize(playerPos)
        local currentVertPosNormal = normalize(currentVert.pos)
        local directionNormal = normalize(currentVertPosNormal - playerPosNormal)

        for uniqueID,vertInfo in pairs(currentVertInfos) do
            if isRadiusSelect then
                local normalizedPos = vertInfo.normalizedVert
                local objectDistance2 = length2(normalizedPos - currentVertPosNormal)
                if uniqueID == currentVert.uniqueID or objectDistance2 <= currentRadius2 then
                    vertInfo.selected = true
                    selectedVertInfos[uniqueID] = vertInfo
                    selectedCount = selectedCount + 1
                else
                    vertInfo.selected = false
                    selectedVertInfos[uniqueID] = nil
                end
            else
                if uniqueID == currentVert.uniqueID or ((boxSelectedIDMap[uniqueID] or boxCurrentSelectionUncomfirmedAddIDMap[uniqueID]) and (not boxCurrentSelectionUncomfirmedSubtractIDMap[uniqueID])) then
                    selectedCount = selectedCount + 1
                    vertInfo.selected = true
                    selectedVertInfos[uniqueID] = vertInfo
                    selectedCount = selectedCount + 1
                else
                    vertInfo.selected = false
                    selectedVertInfos[uniqueID] = nil
                end
            end
        end

        terrainMapView:setLocation(currentVertPosNormal, currentVertInfos, directionNormal)

    elseif currentObject then
        --[[if isRadiusSelect then
            logicInterface:callLogicThreadFunction("getGameObjectIDsWithinRadiusOfPos", {
                types = getObjectTypes(),
                pos = currentObject.pos,
                radius = currentRadius,
                tribeRestrictInfo = getTribeRestrictInfo(),
            }, function(objectIDs)
                selectedObjectIDs = objectIDs
                setSelectionHighlights()
            end)
        else]]
            selectedObjectIDs = {}
            for i,markerInfo in ipairs(markerInfos) do
                if markerInfo.markerTypeIndex == markerTypes.currentObject.index or markerInfo.markerTypeIndex == markerTypes.selected.index then
                    table.insert(selectedObjectIDs, markerInfo.uniqueID)
                end
            end
            setSelectionHighlights()
        --end
    end

    updateTextViews()
end


local function updatePositions()

    currentVertInfos = nil
    selectedVertInfos = nil
    markerInfos = {}
    selectedCount = 1
    updateSelection()

    if radarItemsView then
        radarView:removeSubview(radarItemsView)
        radarItemsView = nil
    end
    
    if currentVert or currentObject then

        local currentObjectOrVertPos = nil
        if currentVert then
            currentObjectOrVertPos = currentVert.pos
        else
            currentObjectOrVertPos = currentObject.pos
        end
        
        local playerPosNormal = normalize(playerPos)
        local currentPosNormal = normalize(currentObjectOrVertPos)
        local directionNormal = normalize(currentPosNormal - playerPosNormal)
        local eye = currentObjectOrVertPos + currentPosNormal * 0.1
        local center = currentObjectOrVertPos
        local up = directionNormal

        local modelViewMat = mjm.mat4LookAt(eye, center, up)
        local mvp = orthoMatrix * modelViewMat

        if length2(playerPosNormal - currentPosNormal) < maxRadius2 then
            local cameraOrthoPos = mjm.mat4xVec4(mvp, vec4(playerPos.x, playerPos.y, playerPos.z, 1.0))
            cameraIcon.baseOffset = vec3(cameraOrthoPos.x * viewRadius, cameraOrthoPos.y * viewRadius, 2)
            cameraIcon.hidden = false
        else
            cameraIcon.hidden = true
        end

        if currentVert then

            logicInterface:callLogicThreadFunction("getVertsForMultiSelectAroundID", currentVert.uniqueID, function(verts)
                currentVertInfos = verts
                selectedVertInfos = {}

                selectedCount = 1
                
                for uniqueID,vertInfo in pairs(currentVertInfos) do
                    if isRadiusSelect then
                        local normalizedPos = vertInfo.normalizedVert
                        local objectDistance2 = length2(normalizedPos - currentPosNormal)
                        if objectDistance2 <= currentRadius2 then
                            selectedCount = selectedCount + 1
                            vertInfo.selected = true
                            selectedVertInfos[uniqueID] = vertInfo
                        end
                    else
                        if uniqueID == currentVert.uniqueID or boxSelectedIDMap[uniqueID] then
                            selectedCount = selectedCount + 1
                            vertInfo.selected = true
                            selectedVertInfos[uniqueID] = vertInfo
                        end
                    end
                    local orthoPos = mjm.mat4xVec4(mvp, vec4(vertInfo.normalizedVert.x, vertInfo.normalizedVert.y, vertInfo.normalizedVert.z, 1.0))
                    vertInfo.pos2D = vec2(orthoPos.x * viewRadius, orthoPos.y * viewRadius)
                end

                terrainMapView:setLocation(currentPosNormal, currentVertInfos, directionNormal)
                terrainMapView.hidden = false
                updateSelection()
            end)
        elseif currentObject then

            local tribeRestrictInfo = getTribeRestrictInfo()

            local requestInfo = {
                types = getObjectTypes(),
                pos = currentObject.pos,
                radius = maxRadius,
                tribeRestrictInfo = tribeRestrictInfo
            }

            if radarItemsView then
                radarView:removeSubview(radarItemsView)
                radarItemsView = nil
            end

            --mj:log("requestInfo:", requestInfo)

            logicInterface:callLogicThreadFunction("getGameObjectsOfTypesWithinRadiusOfPos", requestInfo, function(objects)
                if not mainView.hidden and currentObject == currentObject then

                    radarItemsView = View.new(radarView)
                    radarItemsView.size = radarView.size

                    selectedCount = 1

                    local addedSet = {}

                    local function addObject(objectInfo)
                        local pos = objectInfo.pos
                        local normalizedPos = normalize(pos)
                        local objectDistance2 = length2(normalizedPos - currentPosNormal)
                        if objectDistance2 <= maxRadius2 then

                            local orthoPos = mjm.mat4xVec4(mvp, vec4(pos.x, pos.y, pos.z, 1.0))

                            local markerView = ModelImageView.new(radarItemsView)
                            markerView.masksEvents = false

                            local markerTypeIndex = markerTypes.nonSelected.index

                            if objectInfo.uniqueID == currentObject.uniqueID then
                                markerTypeIndex = markerTypes.currentObject.index
                            else
                                local select = false
                                if isRadiusSelect then
                                    if objectDistance2 <= currentRadius2 then
                                        select = true
                                    end
                                else
                                    if boxSelectedIDMap[objectInfo.uniqueID] then
                                        select = true
                                    end
                                end

                                if select then
                                    selectedCount = selectedCount + 1
                                    markerTypeIndex = markerTypes.selected.index
                                end
                            end

                            local markerType = markerTypes[markerTypeIndex]
                            
                            markerView:setTextures(markerType.textures[1], markerType.textures[2])
                            markerView.materialIndex = markerType.materialIndex
                            markerView.size = vec2(markerType.size, markerType.size)

                            local pos2D = vec2(orthoPos.x * viewRadius, orthoPos.y * viewRadius)

                            markerView.baseOffset = vec3(pos2D.x, pos2D.y, 2)


                            table.insert(markerInfos, {
                                uniqueID = objectInfo.uniqueID,
                                markerView = markerView,
                                objectDistance2 = objectDistance2,
                                markerTypeIndex = markerTypeIndex,
                                pos2D = pos2D,
                            })

                            addedSet[objectInfo.uniqueID] = true

                            return true
                        end
                        return false
                    end

                    for i,objectInfo in ipairs(objects) do
                        addObject(objectInfo)
                    end

                    if currentObject.objectTypeIndex == gameObject.types.sapien.index then
                        if tribeRestrictInfo and tribeRestrictInfo.match and tribeRestrictInfo.match == world.tribeID then
                            local distanceOrderedFollowers = playerSapiens:getDistanceOrderedSapienList(currentObject.pos)
                            for i,infoAndD2 in ipairs(distanceOrderedFollowers) do
                                local sapienInfo = infoAndD2.sapien
                                if (not addedSet[sapienInfo.uniqueID]) then
                                    if not addObject(sapienInfo) then
                                        break
                                    end
                                end
                            end
                        end
                    end

                    updateSelection()
                end
            end)

            logicInterface:callLogicThreadFunction("getVertsForMultiSelectAroundPosition", currentObject.pos, function(verts)
                terrainMapView:setLocation(currentPosNormal, verts, directionNormal)
                terrainMapView.hidden = false
            end)
        end
    end
end

local function updateRadius(newWorldRadius, forceUpdate)
    if forceUpdate or (not mjm.approxEqual(currentRadius, newWorldRadius)) then

        currentRadius = newWorldRadius
        currentRadius2 = currentRadius * currentRadius

        local radiusFraction = currentRadius / maxRadius
        local hoverScaleToUse = selectionRadius * radiusFraction + 4.0
        local hoverSizeToUse = hoverScaleToUse * 2.0
        radarSelectionBackgroundView.scale3D = vec3(hoverScaleToUse,hoverScaleToUse,backgroundRadius)
        radarSelectionBackgroundView.size = vec2(hoverSizeToUse,hoverSizeToUse)
       -- radarSelectionBackgroundView:setCircleHitRadius(hoverScaleToUse)
        if currentObject then
            selectedCount = 1
            for i,markerInfo in ipairs(markerInfos) do
                local newMarkerTypeIndex = nil

                if markerInfo.uniqueID == currentObject.uniqueID then
                    newMarkerTypeIndex = markerTypes.currentObject.index
                elseif markerInfo.objectDistance2 <= currentRadius2 then
                    newMarkerTypeIndex = markerTypes.selected.index
                    selectedCount = selectedCount + 1
                else
                    newMarkerTypeIndex = markerTypes.nonSelected.index
                end

                if newMarkerTypeIndex ~= markerInfo.markerTypeIndex then
                    markerInfo.markerTypeIndex = newMarkerTypeIndex

                    local markerType = markerTypes[newMarkerTypeIndex]
                    local markerView = markerInfo.markerView
                    
                    markerView:setTextures(markerType.textures[1], markerType.textures[2])
                    markerView.materialIndex = markerType.materialIndex
                    markerView.size = vec2(markerType.size, markerType.size)
                end
            end
        end
        
        updateSelection()
    end
end

local function setMarkerTypeIndex(markerInfo, newMarkerTypeIndex)
    if newMarkerTypeIndex ~= markerInfo.markerTypeIndex then
        markerInfo.markerTypeIndex = newMarkerTypeIndex
        local markerType = markerTypes[markerInfo.markerTypeIndex]
        local markerView = markerInfo.markerView
        
        markerView:setTextures(markerType.textures[1], markerType.textures[2])
        markerView.materialIndex = markerType.materialIndex
        markerView.size = vec2(markerType.size, markerType.size)
    end
end

local function resetBoxSelection()
    boxSelectedIDMap = {}
    boxSelectIDs = {}
    boxCurrentSelectionUncomfirmedAddIDMap = {}
    boxCurrentSelectionUncomfirmedSubtractIDMap = {}

    if currentVert then
        for uniqueID,vertInfo in pairs(currentVertInfos) do
            if uniqueID ~= currentVert.uniqueID then
                vertInfo.selected = false
                selectedVertInfos[uniqueID] = nil
            end
        end
    elseif currentObject then
        for i,markerInfo in ipairs(markerInfos) do
            if markerInfo.uniqueID ~= currentObject.uniqueID then
                setMarkerTypeIndex(markerInfo, markerTypes.nonSelected.index)
            end
        end
    end

    selectedCount = 1
    updateSelection()
end

local function updateBoxSelection()

    local isSubtract = boxIsSubtract

    local function shouldCheck(uniqueID)
        if currentObject and uniqueID == currentObject.uniqueID then
            return false
        end
        if currentVert and uniqueID == currentVert.uniqueID then
            return false
        end
        if isSubtract then
            if not boxSelectedIDMap[uniqueID] then
                return false
            end
        else 
            if boxSelectedIDMap[uniqueID] then
                return false
            end
        end
        return true
    end

    local prevSelectedCount = selectedCount
    selectedCount = 1

    if currentVert then
        
        for uniqueID,vertInfo in pairs(currentVertInfos) do
            if shouldCheck(uniqueID) then
                local inBox = false
                local pos2D = vertInfo.pos2D
                if pos2D.x > radarRelativeBoxOrigin.x and pos2D.x < radarRelativeBoxOrigin.x + radarRelativeBoxSize.x then
                    if pos2D.y > radarRelativeBoxOrigin.y and pos2D.y < radarRelativeBoxOrigin.y + radarRelativeBoxSize.y then
                        inBox = true
                    end
                end
                if inBox then
                    if isSubtract then
                        if not boxCurrentSelectionUncomfirmedSubtractIDMap[uniqueID] then
                            boxCurrentSelectionUncomfirmedSubtractIDMap[uniqueID] = vertInfo
                            vertInfo.selected = false
                            selectedVertInfos[uniqueID] = nil
                        end
                    else
                        if not boxCurrentSelectionUncomfirmedAddIDMap[uniqueID] then
                            boxCurrentSelectionUncomfirmedAddIDMap[uniqueID] = vertInfo
                            vertInfo.selected = true
                            selectedVertInfos[uniqueID] = vertInfo
                        end
                    end
                else
                    if isSubtract then
                        if boxCurrentSelectionUncomfirmedSubtractIDMap[uniqueID] then
                            boxCurrentSelectionUncomfirmedSubtractIDMap[uniqueID] = nil
                            vertInfo.selected = true
                            selectedVertInfos[uniqueID] = vertInfo
                        end
                    else
                        if boxCurrentSelectionUncomfirmedAddIDMap[uniqueID] then
                            boxCurrentSelectionUncomfirmedAddIDMap[uniqueID] = nil
                            vertInfo.selected = false
                            selectedVertInfos[uniqueID] = nil
                        end
                    end
                end
                if vertInfo.selected then
                    selectedCount = selectedCount + 1
                end
            end
        end
    elseif currentObject then
        for i,markerInfo in ipairs(markerInfos) do
            if shouldCheck(markerInfo.uniqueID) then
                local inBox = false
                local pos2D = markerInfo.pos2D
                if pos2D.x > radarRelativeBoxOrigin.x and pos2D.x < radarRelativeBoxOrigin.x + radarRelativeBoxSize.x then
                    if pos2D.y > radarRelativeBoxOrigin.y and pos2D.y < radarRelativeBoxOrigin.y + radarRelativeBoxSize.y then
                        inBox = true
                    end
                end

                if inBox then
                    if isSubtract then
                        if not boxCurrentSelectionUncomfirmedSubtractIDMap[markerInfo.uniqueID] then
                            boxCurrentSelectionUncomfirmedSubtractIDMap[markerInfo.uniqueID] = markerInfo
                            setMarkerTypeIndex(markerInfo, markerTypes.nonSelected.index)
                        end
                    else
                        if not boxCurrentSelectionUncomfirmedAddIDMap[markerInfo.uniqueID] then
                            boxCurrentSelectionUncomfirmedAddIDMap[markerInfo.uniqueID] = markerInfo
                            setMarkerTypeIndex(markerInfo, markerTypes.selected.index)
                        end
                    end
                else
                    if isSubtract then
                        if boxCurrentSelectionUncomfirmedSubtractIDMap[markerInfo.uniqueID] then
                            boxCurrentSelectionUncomfirmedSubtractIDMap[markerInfo.uniqueID] = nil
                            setMarkerTypeIndex(markerInfo, markerTypes.selected.index)
                        end
                    else
                        if boxCurrentSelectionUncomfirmedAddIDMap[markerInfo.uniqueID] then
                            boxCurrentSelectionUncomfirmedAddIDMap[markerInfo.uniqueID] = nil
                            setMarkerTypeIndex(markerInfo, markerTypes.nonSelected.index)
                        end
                    end
                end
            end
            if markerInfo.markerTypeIndex == markerTypes.selected.index then
                selectedCount = selectedCount + 1
            end
        end
    end

    if prevSelectedCount ~= selectedCount then
        updateSelection()
    end
end

local function boxSelectionMouseRelease()
    for uniqueID,v in pairs(boxCurrentSelectionUncomfirmedAddIDMap) do
        if not boxSelectedIDMap[uniqueID] then
            boxSelectedIDMap[uniqueID] = true
            table.insert(boxSelectIDs, uniqueID)
        end
    end
    for uniqueID,v in pairs(boxCurrentSelectionUncomfirmedSubtractIDMap) do
        if boxSelectedIDMap[uniqueID] then
            boxSelectedIDMap[uniqueID] = nil
            for i,thisUniqueID in ipairs(boxSelectIDs) do
                if thisUniqueID == uniqueID then
                    table.remove(boxSelectIDs, i)
                    break
                end
            end
        end
    end

    if next(boxCurrentSelectionUncomfirmedAddIDMap) or next(boxCurrentSelectionUncomfirmedSubtractIDMap) then
        updateSelection()
    end

    boxCurrentSelectionUncomfirmedAddIDMap = {}
    boxCurrentSelectionUncomfirmedSubtractIDMap = {}
end


local selectionTipView = nil

local function createSelectionTipView()
    if selectionTipView then
        containerView:removeSubview(selectionTipView)
        selectionTipView = nil
    end

    local complexInfo = nil

    if isRadiusSelect then
        complexInfo = {
            {
                text = locale:get("ui_action_select") .. ":",
            },
            {
                icon = "icon_leftMouse"
            },
            {
                text = locale:get("tutorial_or"),
            },
            {
                keyboardController = {
                    keyboard = {
                        {
                            coloredText = {
                                text = locale:get("mouse_wheel"),
                                color = mj.highlightColor
                            }
                        },
                    },
                    controller = {
                        {
                            controllerImage = {
                                controllerSetIndex = eventManager.controllerSetIndexMenu,
                                controllerActionName = "radialMenuDirection" --todo not sure this is right, untested
                            }
                        }
                    }
                }
            },
        }
    else
        complexInfo = {
            {
                text = locale:get("ui_action_select") .. ":",
            },
            {
                icon = "icon_leftMouse"
            },
            {
                text = locale:get("ui_action_deselect") .. ":",
            },
            {
                icon = "icon_rightMouse"
            },
        }
    end

    if complexInfo then
        selectionTipView = uiComplexTextView:create(containerView, complexInfo, nil)
        selectionTipView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
        selectionTipView.relativeView = selectionToolPopUpButton
        selectionTipView.baseOffset = vec3(0.0,-5.0,0.0)
    end
end

local function applyRadiusSelectChange()
    if isRadiusSelect then
       -- uiStandardButton:setSelected(boxSelectButton, false)
        --uiStandardButton:setSelected(radiusSelectButton, true)
        radarSelectionBackgroundView.hidden = false
        radiusTextView.hidden = false
        updateRadius(currentRadius, true)
    else
        --uiStandardButton:setSelected(boxSelectButton, true)
       -- uiStandardButton:setSelected(radiusSelectButton, false)
        radarSelectionBackgroundView.hidden = true
        radiusTextView.hidden = true
        resetBoxSelection()
    end
end

local function toggleRadiusSelect(newIsRadiusSelect)
    if isRadiusSelect ~= newIsRadiusSelect then
        isRadiusSelect = newIsRadiusSelect

        local multiSelectModeSetting = 1
        if isRadiusSelect then
            multiSelectModeSetting = 2
        end
        clientGameSettings:changeSetting("multiSelectMode", multiSelectModeSetting)
        applyRadiusSelectChange()
        createSelectionTipView()
    end
end

local function updateBoxIsSubtract()
    local newBoxIsSubtract = (shiftDown or boxDragIsRightMouseButton)
    local changed = false
    if newBoxIsSubtract then
        if not boxIsSubtract then
            changed = true
            boxIsSubtract = true
            if boxSelectBoxOrigin then
                if currentVert then
                    for uniqueID,vertInfo in pairs(boxCurrentSelectionUncomfirmedAddIDMap) do
                        vertInfo.selected = false
                        selectedVertInfos[uniqueID] = nil
                    end
                else
                    for uniqueID,markerInfo in pairs(boxCurrentSelectionUncomfirmedAddIDMap) do
                        setMarkerTypeIndex(markerInfo, markerTypes.nonSelected.index)
                    end
                end
                boxCurrentSelectionUncomfirmedAddIDMap = {}
            end
            
            boxSelectView:setModel(model:modelIndexForName("ui_boxSelect"), {
                default = material.types.red.index
            })
        end
    else
        if boxIsSubtract then
            changed = true
            boxIsSubtract = false
            if boxSelectBoxOrigin then
                if currentVert then
                    for uniqueID,vertInfo in pairs(boxCurrentSelectionUncomfirmedSubtractIDMap) do
                        vertInfo.selected = true
                        selectedVertInfos[uniqueID] = vertInfo
                    end
                elseif currentObject then
                    for uniqueID,markerInfo in pairs(boxCurrentSelectionUncomfirmedSubtractIDMap) do
                        setMarkerTypeIndex(markerInfo, markerTypes.selected.index)
                    end
                end
                boxCurrentSelectionUncomfirmedSubtractIDMap = {}
            end
            
            boxSelectView:setModel(model:modelIndexForName("ui_boxSelect"), {
                default = material.types.ui_selected.index
            })
        end
    end
    if changed and boxSelectBoxOrigin then
        updateBoxSelection()
    end
end

local function shiftChanged(isDown)
    if not mainView.hidden then
        shiftDown = isDown
        updateBoxIsSubtract()
    end
end


local keyMap = {
    [keyMapping:getMappingIndex("game", "confirm")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            doSelect()
        end 
        return true 
    end,
    [keyMapping:getMappingIndex("multiSelect", "subtractModifier")] = function(isDown, isRepeat)
        if not isRepeat then
            shiftChanged(isDown) 
            return false 
        end
    end,
}

local function keyChanged(isDown, code, modKey, isRepeat)
    if keyMap[code]  then
		return keyMap[code](isDown, isRepeat)
	end
    return false
end


function multiSelectUI:init(gameUI_, actionUI_, hubUI_, world_, backgroundView)
    gameUI = gameUI_
    hubUI = hubUI_
    world = world_
    local ownerView = gameUI.view

    mainView = View.new(ownerView)
    mainView.hidden = true
    mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    mainView.size = ownerView.size



    --[[local backgroundView = ModelView.new(mainView)
    backgroundView:setModel(model:modelIndexForName("ui_inspectNavigation"))
    local backgroundSize = mainView.size.y * 1.5
    local backgroundScale = backgroundSize * 0.5
    backgroundView.scale3D = vec3(backgroundScale,backgroundScale,backgroundScale)
    backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    backgroundView.size = vec2(backgroundSize, backgroundSize * 0.2)
    backgroundView.baseOffset = vec3(0,-backgroundScale * 0.2, 0)]]
    
    --[[containerView = View.new(backgroundView)
    containerView.size = backgroundView.size
    containerView.hidden = true]]
    
    local modalPanelSize = vec2(1140, 640)
    containerView = ModelView.new(mainView)
    containerView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    local scaleToUse = modalPanelSize.x * 0.5
    containerView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
    containerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    containerView.size = modalPanelSize
    containerView.hidden = true

    local containerViewPopOversView = View.new(mainView)
    containerViewPopOversView.relativePosition = containerView.relativePosition
    containerViewPopOversView.size = vec2(containerView.size.x - 20, containerView.size.y + 40)

    local objectImageViewSize = vec2(100,100)

    selectedObjectCenteredView = View.new(containerView)
    selectedObjectCenteredView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    selectedObjectCenteredView.baseOffset = vec3(-420.0, 0.0, 0.0)

    gameObjectView = uiGameObjectView:create(selectedObjectCenteredView, objectImageViewSize, uiGameObjectView.types.backgroundCircle)
    gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    
    --[[local objectImageBackgroundView = ModelView.new(containerView)
    objectImageBackgroundView:setModel(model:modelIndexForName("ui_insetCircle"))
    local objectImageBackgroundSizeToUse = objectImageViewSize.y
    local objectImageBackgroundScaleToUse = objectImageBackgroundSizeToUse * 0.5
    objectImageBackgroundView.scale3D = vec3(objectImageBackgroundScaleToUse,objectImageBackgroundScaleToUse,objectImageBackgroundScaleToUse)
    objectImageBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    objectImageBackgroundView.size = vec2(objectImageBackgroundSizeToUse, objectImageBackgroundSizeToUse)
    objectImageBackgroundView.baseOffset = vec3(0,100, 2)
    
    objectImageView = GameObjectView.new(objectImageBackgroundView, objectImageViewSize)
    objectImageView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    objectImageView.size = objectImageViewSize]]

    titleTextView = TextView.new(selectedObjectCenteredView)
    titleTextView.font = Font(uiCommon.fontName, 24)
    titleTextView.relativeView = gameObjectView
    titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    titleTextView.baseOffset = vec3(0,-10, 0)
    titleTextView.color = mj.textColor
    titleTextView.wrapWidth = 220.0
    titleTextView.textAlignment = MJHorizontalAlignmentCenter


    subObjectsListTextView = TextView.new(selectedObjectCenteredView)
    subObjectsListTextView.font = Font(uiCommon.fontName, 18)
    subObjectsListTextView.relativeView = titleTextView
    subObjectsListTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    --subObjectsListTextView.baseOffset = vec3(0,-12, 0)
    subObjectsListTextView.color = mj.textColor
    subObjectsListTextView.wrapWidth = 240.0
    subObjectsListTextView.textAlignment = MJHorizontalAlignmentCenter

    selectedObjectCenteredView.size = vec2(
        math.max(math.max(gameObjectView.size.x, subObjectsListTextView.size.x), titleTextView.size.x), 
        gameObjectView.size.y + 10 + titleTextView.size.y + subObjectsListTextView.size.y
    )


    --[[local extraButtonBackgroundSize = backgroundView.size.x * 0.18
    local extraButtonYScale = 0.7
    local extraButtonBackgroundScale = extraButtonBackgroundSize * 0.5
    local extraButtonBackgroundScaleY = extraButtonBackgroundScale * extraButtonYScale
    local hoverOffset = 1.0
    local extraIconHalfSize = 50.0 * 0.5

    local extraButtonBackgroundView = View.new(mainView)
    extraButtonBackgroundView.relativeView = containerView
    extraButtonBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    extraButtonBackgroundView.baseOffset = vec3(0,-(extraButtonBackgroundSize * 0.5 * extraButtonYScale) * 0.52 + 180.0, -hoverOffset - 16)
    extraButtonBackgroundView.size = vec2(extraButtonBackgroundSize, extraButtonBackgroundSize * 0.5 * extraButtonYScale)
    
    local function setupExtraButton(modelName, iconName, iconXOffset, tooltipText, clickFunction)
        
        local buttonBackgroundView = ModelView.new(extraButtonBackgroundView)
        buttonBackgroundView:setModel(model:modelIndexForName(modelName))
        buttonBackgroundView.scale3D = vec3(extraButtonBackgroundScale,extraButtonBackgroundScaleY,extraButtonBackgroundScale * 0.3)
        buttonBackgroundView.size = vec2(extraButtonBackgroundSize * 0.5, extraButtonBackgroundSize * 0.5 * extraButtonYScale)
        
        local icon = ModelView.new(buttonBackgroundView)
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        icon.baseOffset = vec3(iconXOffset,extraButtonBackgroundSize * 0.15, 20)
        icon.scale3D = vec3(extraIconHalfSize,extraIconHalfSize,extraIconHalfSize)
        icon.size = vec2(extraIconHalfSize,extraIconHalfSize) * 2.0
        icon:setModel(model:modelIndexForName(iconName))
        
        local buttonTable = {
            selected = false,
            mouseDown = false,
            clickFunction = clickFunction,
        }

        buttonBackgroundView.hoverStart = function (mouseLoc)
            if not buttonTable.hover then
                if not buttonTable.disabled then
                    buttonTable.hover = true
                    audio:playUISound(uiCommon.hoverSoundFile)
                    icon:setModel(model:modelIndexForName(iconName),
                    nil, nil, function(materialToRemap)
                        return material.types.selectedText.index
                    end)
                    --updateVisuals(wheelSegment, buttonTable)
                end
            end
        end

        buttonBackgroundView.hoverEnd = function ()
            if buttonTable.hover then
                buttonTable.hover = false
                buttonTable.mouseDown = false
                icon:setModel(model:modelIndexForName(iconName))
                --updateVisuals(wheelSegment, buttonTable)
            end
        end

        buttonBackgroundView.mouseDown = function (buttonIndex)
            if buttonIndex == 0 then
                if not buttonTable.mouseDown then
                    if not buttonTable.disabled then
                        buttonTable.mouseDown = true
                        --updateVisuals(wheelSegment, buttonTable)
                        audio:playUISound(uiCommon.clickDownSoundFile)
                    end
                end
            end
        end

        buttonBackgroundView.mouseUp = function (buttonIndex)
            if buttonIndex == 0 then
                if buttonTable.mouseDown then
                    buttonTable.mouseDown = false
                    --updateVisuals(wheelSegment, buttonTable)
                    audio:playUISound(uiCommon.clickReleaseSoundFile)
                    if buttonTable.clickFunction and not buttonTable.disabled then
                        buttonTable.clickFunction()
                    end
                end
            end
        end
        
        buttonBackgroundView:setUsesModelHitTest(true)
        buttonBackgroundView.update = uiCommon:createButtonUpdateFunction(buttonTable, buttonBackgroundView, hoverOffset)
        buttonBackgroundView.userData = buttonTable

        
        uiToolTip:add(buttonBackgroundView, ViewPosition(MJPositionCenter, MJPositionAbove), tooltipText, nil, vec3(iconXOffset, extraIconHalfSize * 1.5), nil, nil)

        selectButton = buttonBackgroundView
    end


    setupExtraButton("ui_inspectExtraSingle", "icon_tickInCircle", 0.0, "Select", function()
        doSelect()
    end)

    ]]

    
    selectButton = uiStandardButton:create(containerView, vec2(240.0,50.0))
    selectButton.baseOffset = vec3(420, -140.0, 2)
    selectButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    --uiStandardButton:setText(selectButton, locale:get("ui_action_select") ..  " [" .. keyMapping:getLocalizedString("game", "confirm") .. "]")
    uiStandardButton:setTextWithShortcut(selectButton, locale:get("ui_action_select"), "game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect")
    
    --uiToolTip:addKeyboardShortcut(selectButton.userData.backgroundView, "game", "confirm", nil, nil)
    uiStandardButton:setClickFunction(selectButton, function()
        doSelect()
    end)
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuSelect", function(isDown)
        if isDown and (not mainView.hidden) then
            doSelect()
            --mj:log("multi")
            return true
        end
    end)

    --uiToolTip:add(selectButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionAbove), locale:get("ui_action_select"), nil, vec3(0.0, 50.0), nil, nil)

    local topYOffset = 160.0
    
    local interactModeToggleButtonsBackgroundView = View.new(containerView)
    interactModeToggleButtonsBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    interactModeToggleButtonsBackgroundView.baseOffset = vec3(410, 0.0, 2)
    interactModeToggleButtonsBackgroundView.size = vec2(220.0, containerView.size.y)

    local selectionToolTitle = TextView.new(interactModeToggleButtonsBackgroundView)
    selectionToolTitle.font = Font(uiCommon.fontName, 16)
    selectionToolTitle.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    selectionToolTitle.baseOffset = vec3(0,topYOffset, 0)
    selectionToolTitle.text = locale:get("misc_selectionTool") .. ":"
    selectionToolTitle.color = mj.textColor

    local popUpButtonSize = vec2(220.0, 50)
    local popUpMenuSize = vec2(popUpButtonSize.x + 20, 300)
    selectionToolPopUpButton = uiPopUpButton:create(interactModeToggleButtonsBackgroundView, containerViewPopOversView, popUpButtonSize, popUpMenuSize)
    selectionToolPopUpButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectionToolPopUpButton.relativeView = selectionToolTitle
    --restrictStorageTypeButton.baseOffset = vec3(0,yOffset, 0)
    selectionToolPopUpButton.baseOffset = vec3(10,0, 0)
    uiPopUpButton:setSelectionFunction(selectionToolPopUpButton, function(selectedIndex, selectedInfo)
        if selectedIndex == 1 then
            toggleRadiusSelect(true)
        else
            toggleRadiusSelect(false)
        end
    end)


    uiPopUpButton:hidePopupMenu(selectionToolPopUpButton)
    uiPopUpButton:setItems(selectionToolPopUpButton, {
        {
            iconModelName = "icon_multiSelectRadial",
            name = locale:get("ui_action_radiusSelect"),
        },
        {
            iconModelName = "icon_multiSelectRect",
            name = locale:get("ui_action_boxSelect"),
        },
    })

    if (clientGameSettings:getSetting("multiSelectMode") == 2) then
        uiPopUpButton:setSelection(selectionToolPopUpButton, 1)
    else
        uiPopUpButton:setSelection(selectionToolPopUpButton, 2)
    end

    --local popupSelectionCombinedWidth = popUpButtonSize.x + restrictStorageTypeButton.baseOffset.x + restrictContentsTextView.size.x

    --[[boxSelectButton = uiStandardButton:create(interactModeToggleButtonsBackgroundView, vec2(200.0,40.0))
    boxSelectButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    uiStandardButton:setText(boxSelectButton, locale:get("ui_action_boxSelect"))
    uiStandardButton:setIconModel(boxSelectButton, "icon_multiSelectRect")
    uiStandardButton:setCenterIconAndText(boxSelectButton, true)
    uiStandardButton:setSelected(boxSelectButton, true)
    uiStandardButton:setClickFunction(boxSelectButton, function()
        toggleRadiusSelect(false)
    end)

    radiusSelectButton = uiStandardButton:create(interactModeToggleButtonsBackgroundView, vec2(200.0,40.0))
    radiusSelectButton.relativeView = boxSelectButton
    radiusSelectButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    radiusSelectButton.baseOffset = vec3(0.0, -10.0, 0.0)
    uiStandardButton:setText(radiusSelectButton, locale:get("ui_action_radiusSelect"))
    uiStandardButton:setIconModel(radiusSelectButton, "icon_multiSelectRadial")
    uiStandardButton:setCenterIconAndText(radiusSelectButton, true)
    uiStandardButton:setClickFunction(radiusSelectButton, function()
        toggleRadiusSelect(true)
    end)]]


    selectionGroupIndexToggleButtonsBackgroundView = View.new(containerView)
    selectionGroupIndexToggleButtonsBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectionGroupIndexToggleButtonsBackgroundView.relativeView = selectionToolPopUpButton
    selectionGroupIndexToggleButtonsBackgroundView.baseOffset = vec3(0, -60, 0)
    selectionGroupIndexToggleButtonsBackgroundView.size = vec2(200.0, 90.0)
    selectionGroupIndexToggleButtonsBackgroundView.hidden = true

    local selectionFilterTitle = TextView.new(selectionGroupIndexToggleButtonsBackgroundView)
    selectionFilterTitle.font = Font(uiCommon.fontName, 16)
    selectionFilterTitle.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    selectionFilterTitle.baseOffset = vec3(0,0, 0)
    selectionFilterTitle.text = locale:get("ui_action_filter") .. ":"
    selectionFilterTitle.color = mj.textColor


    selectionFilterPopUpButton = uiPopUpButton:create(selectionGroupIndexToggleButtonsBackgroundView, containerViewPopOversView, popUpButtonSize, popUpMenuSize)
    selectionFilterPopUpButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    selectionFilterPopUpButton.relativeView = selectionFilterTitle
    --selectionFilterPopUpButton.baseOffset = vec3(0,0, 0)
    uiPopUpButton:setSelectionFunction(selectionFilterPopUpButton, function(selectedIndex, selectedInfo)
        selectionGroupObjectTypeArrayIndex = selectedIndex
        saveSelectionGroupTypeIndexByObjectType[currentObject.objectTypeIndex] = selectionGroupObjectTypeArrayIndex
        updatePositions()
        resetBoxSelection()
    end)

    --[[groupSelectionButtonA = uiStandardButton:create(selectionGroupIndexToggleButtonsBackgroundView, vec2(200.0,40.0))
    groupSelectionButtonA.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    uiStandardButton:setClickFunction(groupSelectionButtonA, function()
        uiStandardButton:setSelected(groupSelectionButtonA, true)
        uiStandardButton:setSelected(groupSelectionButtonB, false)
        selectionGroupObjectTypeArrayIndex = 1
        saveSelectionGroupTypeIndexByObjectType[currentObject.objectTypeIndex] = selectionGroupObjectTypeArrayIndex
        updatePositions()
        resetBoxSelection()
    end)

    groupSelectionButtonB = uiStandardButton:create(selectionGroupIndexToggleButtonsBackgroundView, vec2(200.0,40.0))
    groupSelectionButtonB.relativeView = groupSelectionButtonA
    groupSelectionButtonB.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    groupSelectionButtonB.baseOffset = vec3(0.0, -10.0, 0.0)
    uiStandardButton:setClickFunction(groupSelectionButtonB, function()
        uiStandardButton:setSelected(groupSelectionButtonA, false)
        uiStandardButton:setSelected(groupSelectionButtonB, true)
        selectionGroupObjectTypeArrayIndex = 2
        saveSelectionGroupTypeIndexByObjectType[currentObject.objectTypeIndex] = selectionGroupObjectTypeArrayIndex
        updatePositions()
        resetBoxSelection()
    end)]]


    
    radarView = View.new(mainView)
    radarView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    radarView.size = vec2(viewRadius * 2.0, viewRadius * 2.0)

    radarBackgroundView = ModelView.new(radarView)
    radarBackgroundView:setModel(model:modelIndexForName("ui_radarBackground_inset"))
    radarBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    radarBackgroundView.alpha = 0.9
    radarBackgroundView:setUsesModelHitTest(true)
    --radarBackgroundView:setCircleHitRadius(viewRadius)
    --radarBackgroundView.baseOffset = vec3(0, -80, 0)

    terrainMapView = TerrainMapView.new(radarView)
    terrainMapView.hidden = true
    terrainMapView.size = radarView.size
    terrainMapView.masksEvents = false

    
    radiusTextView = TextView.new(radarView)
    radiusTextView.font = Font(uiCommon.fontName, 16)
    radiusTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    radiusTextView.color = mj.textColor
    radiusTextView.hidden = true
    
    --[[countTextView = TextView.new(radarView)
    countTextView.font = Font(uiCommon.fontName, 16)
    countTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    countTextView.color = mj.textColor]]

    
    local radarSize = vec2(backgroundRadius * 2.0, backgroundRadius * 2.0)
    local radarScale = backgroundRadius
    radarBackgroundView.scale3D = vec3(radarScale,radarScale,radarScale)
    radarBackgroundView.size = radarSize
    
    radarSelectionBackgroundView = ModelView.new(radarView)
    radarSelectionBackgroundView.masksEvents = false
    radarSelectionBackgroundView:setModel(model:modelIndexForName("ui_radarBackground"), {
        default = material.types.ui_selected.index,
    })
    radarSelectionBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    radarSelectionBackgroundView.alpha = 0.4
    radarSelectionBackgroundView.baseOffset = vec3(0,0,1)

    --local selectionSizeToUse = vec2(viewRadius, viewRadius)
    --local selectionScaleToUse = viewRadius * 0.5


    local radiusFraction = currentRadius / maxRadius
    local hoverScaleToUse = selectionRadius * radiusFraction + 4.0
    local hoverSizeToUse = hoverScaleToUse * 2.0

    radarSelectionBackgroundView.scale3D = vec3(hoverScaleToUse,hoverScaleToUse,hoverScaleToUse)
    radarSelectionBackgroundView.size = vec2(hoverSizeToUse,hoverSizeToUse)
    radarSelectionBackgroundView:setUsesModelHitTest(true)
    radarSelectionBackgroundView.hidden = true
    --radarSelectionBackgroundView:setCircleHitRadius(selectionScaleToUse)

    
    boxSelectView = ModelView.new(mainView)
    boxSelectView:setModel(model:modelIndexForName("ui_boxSelect"), {
        default = material.types.ui_selected.index,
    })
    boxSelectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    boxSelectView.alpha = 0.4
    boxSelectView.hidden = true
    boxSelectView.masksEvents = false
    
    cameraIcon = ModelImageView.new(radarView)
    cameraIcon:setTextures("img/icons/camera.png", "img/icons/flat.png")
    cameraIcon.materialIndex = material.types.ui_standard.index
    cameraIcon.size = vec2(20,20)
    cameraIcon.alpha = 0.8

    local function getConstrainedBoxMouseLoc(mouseLoc)
        local constrainedMouseLoc = mouseLoc - mainView.size * 0.5
        constrainedMouseLoc.x = mjm.clamp(constrainedMouseLoc.x, -backgroundRadius, backgroundRadius)
        constrainedMouseLoc.y = mjm.clamp(constrainedMouseLoc.y, -backgroundRadius, backgroundRadius)

        return constrainedMouseLoc
    end

    local function updateBoxDrag(mouseLoc)

        if boxSelectBoxOrigin then
            local constrainedMouseLoc = getConstrainedBoxMouseLoc(mouseLoc)
            boxSelectBoxSize = constrainedMouseLoc - boxSelectBoxOrigin

            local absX = math.abs(boxSelectBoxSize.x)
            local absY = math.abs(boxSelectBoxSize.y)
            
            if absX < 0.1 or absY < 0.1 then
                boxSelectView.hidden = true
            else
                if boxSelectView.hidden then
                    boxSelectView.hidden = false
                    updateBoxIsSubtract()
                end
                
                boxSelectView.scale3D = vec3(absX * 0.5,absY * 0.5, radarScale)
                boxSelectView.size = vec2(absX,absY)

                radarRelativeBoxSize = vec2(absX,absY)

                local posX = math.min(boxSelectBoxOrigin.x, constrainedMouseLoc.x)
                local posY = math.min(boxSelectBoxOrigin.y, constrainedMouseLoc.y)

                
                radarRelativeBoxOrigin = vec2(posX,posY)

                boxSelectView.baseOffset = vec3(posX + mainView.size.x * 0.5,posY + mainView.size.y * 0.5,1)
                updateBoxSelection()
            end
        end
    end

    local function updateRadiusDrag(mouseLoc)
            local offsetFromCenter = (mouseLoc - vec2(backgroundRadius,backgroundRadius)) / viewRadius

            local distanceFromCenter2 = offsetFromCenter.x * offsetFromCenter.x + offsetFromCenter.y * offsetFromCenter.y
            distanceFromCenter2 = mjm.clamp(distanceFromCenter2, 0.00001, 1.0)
            local distanceFromCenter = math.sqrt(distanceFromCenter2)
            local newWorldRadius = maxRadius * distanceFromCenter
            newWorldRadius = mjm.clamp(newWorldRadius, mj:mToP(0.1), maxRadius)
            updateRadius(newWorldRadius, false)

    end

    radarBackgroundView.mouseDragged = function(mouseLoc)
        if isRadiusSelect then
            updateRadiusDrag(mouseLoc)
        end
    end

    radarBackgroundView.mouseDown = function(buttonIndex, mouseLoc)
        if isRadiusSelect then
            updateRadiusDrag(mouseLoc)
        end
    end

    mainView.mouseDragged = function(mouseLoc)
        if not isRadiusSelect then
            updateBoxDrag(mouseLoc)
        end
    end

    mainView.mouseDown = function(buttonIndex, mouseLoc)
        if not isRadiusSelect then
            boxDragIsRightMouseButton = (buttonIndex == 1)
            local constrainedMouseLoc = getConstrainedBoxMouseLoc(mouseLoc)
            boxSelectBoxOrigin = constrainedMouseLoc
            boxSelectBoxSize = vec2(0.0,0.0)
        end
    end

    mainView.mouseUp = function(buttonIndex, mouseLoc)
        if not isRadiusSelect then
            boxSelectionMouseRelease()
            boxSelectBoxOrigin = nil
            boxSelectView.hidden = true
        end
    end

    mainView.mouseWheel = function(position, scrollChange)
        if not mainView.hidden and isRadiusSelect then
            local newRadius = currentRadius + mj:mToP(5.0 * -scrollChange.y)
            newRadius = mjm.clamp(newRadius, mj:mToP(0.01), maxRadius)
            updateRadius(newRadius, false)
        end
    end

    
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, false, "radialMenuDirection", function(pos)
        if not mainView.hidden then
            local absValue = math.abs(pos.y)
                if absValue > 0.001 then
                if not isRadiusSelect then
                    isRadiusSelect = true
                    applyRadiusSelectChange()
                    createSelectionTipView()
                end

                local rampedValue = pos.y * math.abs(pos.y)
                local newRadius = currentRadius + mj:mToP(2.0 * rampedValue)
                newRadius = mjm.clamp(newRadius, mj:mToP(0.01), maxRadius)
                updateRadius(newRadius, false)
                
                return true
            end
        end
        return false
    end)
    
    --eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)

    mainView.keyChanged = keyChanged

    if (clientGameSettings:getSetting("multiSelectMode") == 2) then
        isRadiusSelect = true
        applyRadiusSelectChange()
    end

    createSelectionTipView()

end

function multiSelectUI:show(objectOrVertInfo, isTerrain, playerPos_, lookAtPos_)
    --mj:log("objectOrVertInfo:", objectOrVertInfo)
    if mainView.hidden then
        world.hasUsedMultiselect = true
        mainView.hidden = false
        containerView.hidden = false
        playerPos = playerPos_
        
        if isTerrain then
            currentObject = nil
            currentVert = objectOrVertInfo
        else
            currentVert = nil
            currentObject = objectOrVertInfo
        end

        boxSelectBoxOrigin = nil
        boxSelectView.hidden = true
        shiftDown = false
        --resetMultiSlider()

        boxSelectIDs = {}
        boxSelectedIDMap = {}

        --uiCommon:setGameObjectViewObject(objectImageView, currentObject)

        terrainMapView.hidden = true
        
        if isTerrain then
            local materialIndex = currentVert.material
            local modelMaterialRemapTable = {
                default = materialIndex
            }

            uiGameObjectView:setModelName(gameObjectView, "icon_terrain", modelMaterialRemapTable)
            selectionGroupIndexToggleButtonsBackgroundView.hidden = true

            --terrainMapView:setLocation(normalize(objectOrVertInfo.pos), mj:mToP(50.0), normalize(normalize(lookAtPos_) - normalize(playerPos_)))
        else
            uiGameObjectView:setObject(gameObjectView, currentObject, nil, nil)
            
        
            selectionGroupObjectTypeArrayIndex = 1
            if saveSelectionGroupTypeIndexByObjectType[currentObject.objectTypeIndex] then
                selectionGroupObjectTypeArrayIndex = saveSelectionGroupTypeIndexByObjectType[currentObject.objectTypeIndex]
            end

            local currentGameObjectType = gameObject.types[currentObject.objectTypeIndex]

            local additionalSelectionGroupTypeIndexes = currentGameObjectType.additionalSelectionGroupTypeIndexes


            if additionalSelectionGroupTypeIndexes then
                --mj:log("currentGameObjectType:", currentGameObjectType)
                local baseSelectionGroupTypeIndex = currentGameObjectType.baseSelectionGroupTypeIndex
                local itemInfos = {}

                local baseName = currentGameObjectType.plural
                if baseSelectionGroupTypeIndex then
                    baseName = selectionGroup.types[baseSelectionGroupTypeIndex].descriptivePlural
                else
                    baseName = currentGameObjectType.selectionGroupName or baseName
                end

                table.insert(itemInfos,  {name = baseName})

                if currentGameObjectType.additionalSelectionGroupTypeIndexes then
                    for i,additionalSelectionGroupTypeIndex in ipairs(currentGameObjectType.additionalSelectionGroupTypeIndexes) do
                        table.insert(itemInfos,  {name = selectionGroup.types[additionalSelectionGroupTypeIndex].descriptivePlural})
                    end
                end

                selectionGroupIndexToggleButtonsBackgroundView.hidden = false

                uiPopUpButton:hidePopupMenu(selectionFilterPopUpButton)
                uiPopUpButton:setItems(selectionFilterPopUpButton, itemInfos)

                selectionGroupObjectTypeArrayIndex = math.min(#itemInfos, selectionGroupObjectTypeArrayIndex)

                uiPopUpButton:setSelection(selectionFilterPopUpButton, selectionGroupObjectTypeArrayIndex)
            else
                selectionGroupIndexToggleButtonsBackgroundView.hidden = true
                selectionGroupObjectTypeArrayIndex = 1
            end
        end

        updatePositions()
        
--userData.selectedObjectID, userData.multiHighlightRadius, userData.multiHighlightObjectTypes

    end
    --registerStateChanges(object.uniqueID)
end

function multiSelectUI:hide()
    if not mainView.hidden then
        mainView.hidden = true
        containerView.hidden = true

        --logicInterface:callLogicThreadFunction("setSelectionHighlight", nil)
    end
end


function multiSelectUI:hidden()
    return (mainView.hidden)
end

return multiSelectUI