local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local normalize = mjm.normalize
local dot = mjm.dot
local mix = mjm.mix
local cross = mjm.cross
local length = mjm.length
local length2 = mjm.length2
local vec3xMat3 = mjm.vec3xMat3
local mat3LookAtInverse = mjm.mat3LookAtInverse
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local mat3Inverse = mjm.mat3Inverse
local mat3GetRow = mjm.mat3GetRow
local approxEqual = mjm.approxEqual
local approxEqualEpsilon = mjm.approxEqualEpsilon
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix

local locale = mjrequire "common/locale"
local constructable = mjrequire "common/constructable"
local buildable = mjrequire "common/buildable"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
local physicsSets = mjrequire "common/physicsSets"
local plan = mjrequire "common/plan"
local resource = mjrequire "common/resource"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local gameObject = mjrequire "common/gameObject"
local rng = mjrequire "common/randomNumberGenerator"
local pathBuildable = mjrequire "common/pathBuildable"
local terrainTypes = mjrequire "common/terrainTypes"
local storage = mjrequire "common/storage"
--local skill = mjrequire "common/skill"
local timer = mjrequire "common/timer"

local logicInterface = mjrequire "mainThread/logicInterface"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiKeyImage = mjrequire "mainThread/ui/uiCommon/uiKeyImage"
local uiObjectManager = mjrequire "mainThread/uiObjectManager"
local audio = mjrequire "mainThread/audio"
local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"
local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local contextualTipUI = mjrequire "mainThread/ui/contextualTipUI"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"

local localPlayer = nil
local world = nil
local gameUI = nil

local buildModeInteractUI = {}


local allFinalPositionViews = {}

local finalPositionMode = false
local finalPositionWorldView = nil
local finalPositionConfirmWorldView = nil

local finalPositionXrotationView = nil
local finalPositionYrotationView = nil
local finalPositionZrotationView = nil

local finalPositionXTranslationView = nil
local finalPositionYTranslationView = nil
local finalPositionZTranslationView = nil

local buildObjectPos = vec3(0.0,0.0,0.0)
local buildObjectCanBuild = false
local buildObjectRotation = mat3Identity
local objectExtraRotationDueToKeysOrDupe = mat3Identity

local mouseExtraPosOffsets = vec3(0.0,0.0,0.0)
local mouseExtraRotation = mat3Identity
local finalControlsRotationMatrix = mat3Identity

local currentModelDisplayedCanBuild = false

local constructableTypeIndex = nil
local randomVariationBaseConstructableTypeIndex = nil
local useRandomVariation = false

local buildObjectInfo = nil

--local baseObjectRotation = mat3Identity
--local additionalRotationComponent = mat3Identity

local pathNodes = nil
local pathSubModelInfosByNode = nil
local pathMainNodeSubModelInfosByNode = nil

local currentSelection = nil
local selectedControls = {}
local mouseDownControl = nil

local crossButtonInfo = {}
local tickButtonInfo = {}

local leftMouseIsDown = false
local rightMouseIsDown = false
local middleMouseIsDown = false
local zAxisAndDisableSnapModifierDown = false
local adjustmentModifierDown = false
local noBuildOrderModifierDown = false


local finalPositionConfirmButtonRadius = 0.2


local pathStringInitialNodePos = nil
local maxPathExtraNodes = 10

local topView = nil
local titleView = nil
local titleGameObjectView = nil
local subTitleView = nil

--[[local waitingForBuildConfirm = false
local waitingForBuildConfirmObjectIDToLoad = nil
local waitingForBuildConfirmSanityCallbackTimer = nil]]

local unconfirmedIndexCounter = 0
local unconfirmedInfos = {}


local warningObjectIDs = nil

local attachedToTerrain = nil


local shortcutKeyImageViewHeight = 40.0
local shortcutKeyImageViewScale = 0.01

local isDupeBuild = false
local dupeBuildRestrictedResourceObjectTypes = nil

local maxBuildDepthBelowTerrain = mj:mToP(1.1)

local titleIconHalfSize = 20

local function clearWarningObjectIDs()
    if warningObjectIDs then
        warningObjectIDs = nil
        logicInterface:callLogicThreadFunction("setWarningColorForObjects", nil)
    end
end

local function setWarningObjectIDs(objectIDs, value)

    if (not objectIDs) or (not objectIDs[1]) then
        clearWarningObjectIDs()
        return
    end

    local matching = true

    local newIDs = {}
    for i, objectID in ipairs(objectIDs) do
        if (not warningObjectIDs) or (not warningObjectIDs[objectID]) then
            matching = false
        end
        newIDs[objectID] = true
    end

    if matching and warningObjectIDs then
        for k,v in pairs(warningObjectIDs) do
            if not newIDs[k] then
                matching = false
            end
        end
    end

    if matching then
        return
    end

    warningObjectIDs = newIDs
    logicInterface:callLogicThreadFunction("setWarningColorForObjects", {
        objectIDs = objectIDs,
        value = value,
    })
end


local function removeUnconfirmedInfo(unconfirmedID)
    local unconfirmedInfo = unconfirmedInfos[unconfirmedID]
    if unconfirmedInfo then
        local modelInfo = unconfirmedInfo.modelInfo
        if modelInfo.modelID then
            uiObjectManager:removeUIModel(modelInfo.modelID)
        end
    
        if modelInfo.subModelIDs then
            for subID,info in pairs(modelInfo.subModelIDs) do
                uiObjectManager:removeUIModel(subID)
            end
        end

        unconfirmedInfos[unconfirmedID] = nil
    end
end

local function doPlaceWithAdjustment()
    if finalPositionMode then
        buildModeInteractUI:doFinalPlacementIfAble()
    else
        buildModeInteractUI:enterFinalPositionMode()
    end
end

local buildRepeatDelayTimer = timer:addDeltaTimer()
local buildRepeatTimeAccumulation = nil
local buildRepeatTimeMinValue = 0.2

local confirmFunction = function(isDown, isRepeat) 
    if isDown then
        local function doFunc()
            if zAxisAndDisableSnapModifierDown or adjustmentModifierDown then
                if not finalPositionMode then
                    doPlaceWithAdjustment()
                end
                --buildRepeatTimeAccumulation = nil
            else
                if buildObjectInfo ~= nil and buildObjectCanBuild then
                    finalPositionMode = true
                    buildModeInteractUI:doFinalPlacementIfAble()
                    gameUI:updateUIHidden()
                end
            end
        end

        if not buildRepeatTimeAccumulation then
            buildRepeatTimeAccumulation = -buildRepeatTimeMinValue
            timer:getDt(buildRepeatDelayTimer)
            doFunc()
        else
            local elapsed = buildRepeatTimeAccumulation + timer:getDt(buildRepeatDelayTimer)
            if elapsed < buildRepeatTimeMinValue then
                buildRepeatTimeAccumulation = elapsed
            else
                buildRepeatTimeAccumulation = 0.0
                doFunc()
            end
        end
    else
        buildRepeatTimeAccumulation = nil
    end
    return true 
end

local zAxisAndDisableSnapModifierFunction = function(isDown, isRepeat) 
    zAxisAndDisableSnapModifierDown = isDown
    return true 
end

local adjustmentModifierFunction = function(isDown, isRepeat) 
    adjustmentModifierDown = isDown
    return true 
end

local noBuildOrderModifierFunction = function(isDown, isRepeat) 
    noBuildOrderModifierDown = isDown
    return true 
end




local function updateFinalControls()
    worldUIViewManager:updateView(finalPositionWorldView.uniqueID, {
        basePos = buildObjectPos,
        constantRotationMatrix = buildObjectRotation
    })
    worldUIViewManager:updateView(finalPositionConfirmWorldView.uniqueID, {
        basePos = buildObjectPos, 
        baseRotation = buildObjectRotation,
        offsets = {{ 
            worldOffset = vec3(0.0, mj:mToP(1.0), mj:mToP(0.0))
        }},
    })
end

local function rotateX(isDown, isRepeat)
    if (not isRepeat) and isDown and constructable.types[constructableTypeIndex].allowXZRotation then
        if finalPositionMode then
            buildObjectRotation = mat3Rotate(buildObjectRotation, math.pi * 0.5, vec3(1.0,0.0,0.0))
            updateFinalControls()
        else
            objectExtraRotationDueToKeysOrDupe = mat3Rotate(objectExtraRotationDueToKeysOrDupe, math.pi * 0.5, vec3(1.0,0.0,0.0))
        end
    end
end

local function rotateY(isDown, isRepeat)
    if (not isRepeat) and isDown then
        if finalPositionMode then
            buildObjectRotation = mat3Rotate(buildObjectRotation, math.pi * 0.5, vec3(0.0,1.0,0.0))
            updateFinalControls()
        else
            objectExtraRotationDueToKeysOrDupe = mat3Rotate(objectExtraRotationDueToKeysOrDupe, math.pi * 0.5, vec3(0.0,1.0,0.0))
        end
    end
end

local function rotateZ(isDown, isRepeat)
    if (not isRepeat) and isDown and constructable.types[constructableTypeIndex].allowXZRotation then
        if finalPositionMode then
            buildObjectRotation = mat3Rotate(buildObjectRotation, math.pi * 0.5, vec3(0.0,0.0,1.0))
            updateFinalControls()
        else
            objectExtraRotationDueToKeysOrDupe = mat3Rotate(objectExtraRotationDueToKeysOrDupe, math.pi * 0.5, vec3(0.0,0.0,1.0))
        end
    end
end

local keyMap = {
    [keyMapping:getMappingIndex("building", "cancel")] = function(isDown, isRepeat) 
        if isDown and not isRepeat then 
            buildModeInteractUI:hide()
        end
        return true 
    end,
    [keyMapping:getMappingIndex("building", "confirm")] = confirmFunction,
    [keyMapping:getMappingIndex("building", "zAxisModifier")] = zAxisAndDisableSnapModifierFunction,
    [keyMapping:getMappingIndex("building", "adjustmentModifier")] = adjustmentModifierFunction,
    [keyMapping:getMappingIndex("building", "noBuildOrderModifier")] = noBuildOrderModifierFunction,

    [keyMapping:getMappingIndex("building", "rotateX")] = rotateX,
    [keyMapping:getMappingIndex("building", "rotateY")] = rotateY,
    [keyMapping:getMappingIndex("building", "rotateZ")] = rotateZ,

    
}

local function keyChanged(isDown, mapIndexes, isRepeat)
    if not topView.hidden then
        --if eventManager:mouseHidden() then
            for i,mapIndex in ipairs(mapIndexes) do
                if keyMap[mapIndex]  then
                    if keyMap[mapIndex](isDown, isRepeat) then
                        return true
                    end
                end
            end
        --end
    end
    return false
end

local function updateSubtitle(subtitleTextOrNil, colorOrNil) --if color changes but not text, it's currently ignored.
    local maxWidth = math.max(200, titleView.size.x + 30 + titleIconHalfSize * 2.0)
    local height = titleView.size.y + 10

    if subtitleTextOrNil then
        subTitleView.hidden = false
        subTitleView.text = subtitleTextOrNil
        subTitleView.color = colorOrNil or mj.textColor
        maxWidth = math.max(maxWidth, subTitleView.size.x + 20)
        height = height + subTitleView.size.y
    else
        subTitleView.hidden = true
    end
    
    local sizeToUse = vec2(maxWidth, height)

    local scaleToUseX = sizeToUse.x * 0.5
    local scaleToUseY = sizeToUse.y * 0.5 / 0.4
    topView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
    topView.size = sizeToUse
    if not topView.hidden then
        gameUI:updateWarningNoticeForTopPanelDisplayed(-topView.size.y - 20)
    end
end

local function showTitle(constructableType)
    titleView:setText(constructableType.name, material.types.standardText.index)

    local restrictedResourceObjectTypes = nil
    if isDupeBuild then
        restrictedResourceObjectTypes = dupeBuildRestrictedResourceObjectTypes
    else
        restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
    end
    uiGameObjectView:setObject(titleGameObjectView, {
        objectTypeIndex = constructable:getDisplayGameObjectType(constructableType.index, restrictedResourceObjectTypes, nil),
    }, nil, nil)


    pathStringInitialNodePos = nil
    pathNodes = nil

    if topView.hidden then
        topView.hidden = false
        gameUI:updateWarningNoticeForTopPanelDisplayed(-topView.size.y - 20)
        logicInterface:callLogicThreadFunction("showObjectsForBuildModeStart")
    end
end

function buildModeInteractUI:setLocalPlayer(localPlayer_)
    localPlayer = localPlayer_
end

function buildModeInteractUI:shouldOwnMouseMoveControl()
    return (rightMouseIsDown or middleMouseIsDown) and (not buildModeInteractUI:hidden())
end

function buildModeInteractUI:mouseDown(pos, buttonIndex, modKey)
    if buildObjectPos then
        if buttonIndex == 0 then
            leftMouseIsDown = true
        else
            eventManager:preventMouseWarpUntilAfterNextShow()
        end
        if zAxisAndDisableSnapModifierDown or (not gameUI:pointAndClickModeEnabled()) then
            if buttonIndex == 1 then
                rightMouseIsDown = true
                return true
            elseif buttonIndex == 2 then
                if not rightMouseIsDown then
                    middleMouseIsDown = true
                end
                return true
            end
        end
    end
    return false
end

function buildModeInteractUI:mouseUp(pos, buttonIndex, modKey)
    if buttonIndex == 0 then
        leftMouseIsDown = false
        return true
    elseif buttonIndex == 1 then
        rightMouseIsDown = false
        return true
    elseif buttonIndex == 2 then
        middleMouseIsDown = false
        return true
    end
    return false
end

local function mouseMoved(pos, relativeMovement, dt)
    if not buildModeInteractUI:hidden() then
        if rightMouseIsDown then
            --[[if zAxisAndDisableSnapModifierDown then
                if constructable.types[constructableTypeIndex].allowXZRotation then
                    local angle = relativeMovement.x * -0.005
                    if finalPositionMode then
                        local lookAtPos =  localPlayer.lookAtPosition
                        if localPlayer.lookAtPositionMainThread then
                            lookAtPos = localPlayer.lookAtPositionMainThread
                        end
                        local lookAtPosNormal = normalize(lookAtPos)
                        local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)
                        local viewMatrix = mat3LookAtInverse(directionNormal, lookAtPosNormal)

                        local objectSpaceMatrix = mat3Inverse(buildObjectRotation) * viewMatrix
                        buildObjectRotation = mat3Rotate(buildObjectRotation, angle, mat3GetRow(objectSpaceMatrix, 2))
                        updateFinalControls()
                    else
                        mouseExtraRotation = mat3Rotate(mouseExtraRotation, angle, mat3GetRow(mat3Inverse(mouseExtraRotation), 2))
                    end
                end
            else]]
                local angle = relativeMovement.x * 0.005
                if finalPositionMode then
                    local objectSpaceMatrix = mat3Inverse(buildObjectRotation) * finalControlsRotationMatrix
                    buildObjectRotation = mat3Rotate(buildObjectRotation, angle, mat3GetRow(objectSpaceMatrix, 1))
                    updateFinalControls()
                else
                    mouseExtraRotation = mat3Rotate(mouseExtraRotation, angle, mat3GetRow(mat3Inverse(mouseExtraRotation), 1))
                end
            --end
        elseif middleMouseIsDown then

            local lookAtPos =  localPlayer.lookAtPosition
            if localPlayer.lookAtPositionMainThread then
                lookAtPos = localPlayer.lookAtPositionMainThread
            end
            local lookAtPosNormal = normalize(lookAtPos)
            
            if zAxisAndDisableSnapModifierDown then
                if constructable.types[constructableTypeIndex].allowYTranslation then
                    local offset = mj:mToP(relativeMovement.y * -0.01)
                    buildObjectPos = buildObjectPos + lookAtPosNormal * offset
                    
                    if finalPositionMode then
                        updateFinalControls()
                    else
                        mouseExtraPosOffsets.y = mouseExtraPosOffsets.y + offset
                    end
                end
            else
                local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)

                local backVector = directionNormal
                local rightVector = normalize(cross(lookAtPosNormal, backVector))
                local forwardVector = normalize(cross(lookAtPosNormal, rightVector))
                local xOffset = mj:mToP(relativeMovement.x * 0.01)
                local zOffset = mj:mToP(relativeMovement.y * -0.01)

                buildObjectPos = buildObjectPos + rightVector * xOffset + forwardVector * zOffset
                
                if finalPositionMode then
                    updateFinalControls()
                else
                    mouseExtraPosOffsets.x = mouseExtraPosOffsets.x + xOffset
                    mouseExtraPosOffsets.z = mouseExtraPosOffsets.z + zOffset
                end
            end
            return true
        end
    end
    return false
end


function buildModeInteractUI:init(gameUI_, world_)
    gameUI = gameUI_
    world = world_
    topView = ModelView.new(gameUI.worldViews)
    topView:setModel(model:modelIndexForName("ui_panel_10x4"))
    topView.hidden = true;
    topView.alpha = 0.9
    topView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    topView.baseOffset = vec3(0, -20, 0)

    

    titleView = ModelTextView.new(topView)
    titleView.font = Font(uiCommon.fontName, 36)
    titleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleView.baseOffset = vec3(titleIconHalfSize, -6, 0)
    
    titleGameObjectView = uiGameObjectView:create(topView, vec2(titleIconHalfSize,titleIconHalfSize) * 2.0, uiGameObjectView.types.standard)
    --uiGameObjectView:setBackgroundAlpha(gameObjectView, 0.6)
    titleGameObjectView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    titleGameObjectView.relativeView = titleView
    titleGameObjectView.baseOffset = vec3(-5,0,0)
    --[[uiGameObjectView:setObject(titleGameObjectView, {
        objectTypeIndex = gameObjectType.index
    }, nil, nil)]]

    subTitleView = TextView.new(topView)
    subTitleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    subTitleView.relativeView = titleView
    subTitleView.font = Font(uiCommon.fontName, 16)
    subTitleView.color = mj.textColor
    subTitleView.hidden = true
    subTitleView.baseOffset = vec3(-titleIconHalfSize, 0, 0)

    eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)
    eventManager:addEventListenter(mouseMoved, eventManager.mouseMovedListeners)

    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "confirm", function(isDown)
        if isDown and not buildModeInteractUI:hidden() then
            doPlaceWithAdjustment()
            return true
        end
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "buildMenu", function(isDown)
        if isDown and not buildModeInteractUI:hidden() then
            doPlaceWithAdjustment()
            return true
        end
    end)

end

local function resetFinalPositionViews()
    local function resetInfo(buttonInfo)
        buttonInfo.goalSize = finalPositionConfirmButtonRadius
        buttonInfo.currentSize = finalPositionConfirmButtonRadius
        buttonInfo.differenceVelocity = 0.0
        buttonInfo.selected = false
        
        local iconRadiusToUse = buttonInfo.currentSize
        buttonInfo.buttonBackgroundView.scale3D = vec3(iconRadiusToUse,iconRadiusToUse,iconRadiusToUse)
        buttonInfo.buttonBackgroundView.size = vec2(buttonInfo.currentSize, buttonInfo.currentSize) * 2.0
        local logoHalfSize = buttonInfo.currentSize * 0.4
        buttonInfo.icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
        buttonInfo.icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0
        buttonInfo.icon.baseOffset = vec3(0, buttonInfo.currentSize * 0.25, 0.01)

        --buttonInfo.keyImage.fontGeometryScale = buttonInfo.currentSize * 0.01
        uiKeyImage:setGeometryScale(buttonInfo.keyImage, buttonInfo.currentSize * shortcutKeyImageViewScale)
        buttonInfo.keyImage.baseOffset = vec3(0.0, -buttonInfo.currentSize * 0.4, 0.02)
    end
    resetInfo(crossButtonInfo)
    resetInfo(tickButtonInfo)
end

--local mouseDown


local function updateHiddenFinalPositionViews()
    if mouseDownControl then
        for i=1,6 do
            if allFinalPositionViews[i] ~= mouseDownControl.view then
                allFinalPositionViews[i].hidden = true
            end
        end
    else
        
        finalPositionXTranslationView.hidden = false
        if constructable.types[constructableTypeIndex].allowYTranslation then
            finalPositionYTranslationView.hidden = false
        end
        finalPositionZTranslationView.hidden = false

        finalPositionYrotationView.hidden = false
        if constructable.types[constructableTypeIndex].allowXZRotation then
            finalPositionXrotationView.hidden = false
            finalPositionZrotationView.hidden = false
        end
    end
end

local function updateSelection()
    local newSelection = mouseDownControl
    if not newSelection then
        newSelection = selectedControls[1]
    end
    if newSelection ~= currentSelection then
        if currentSelection then
            currentSelection.view:setModel(model:modelIndexForName(currentSelection.modelName), {
                default = currentSelection.mat
            })
        end
        if newSelection then
            --mj:log("newSelection:", newSelection, " model:modelIndexForName:", model:modelIndexForName(newSelection.modelName))
            newSelection.view:setModel(model:modelIndexForName(newSelection.modelName), {
                default = newSelection.matHover
            })
        end
        currentSelection = newSelection
    end
    updateHiddenFinalPositionViews()
end


local maxTranslationDistance = mj:mToP(20.0)



local function setRandomInitialRotation(constructableType)

    if constructableType.randomInitialYRotation then
        objectExtraRotationDueToKeysOrDupe = mat3Rotate(mat3Identity, rng:randomValue() * math.pi * 2.0, vec3(0.0,1.0,0.))
    end

    --[[if constructableType.randomInitialYRotation then
        baseObjectRotation = mat3Rotate(mat3Identity, rng:randomValue() * math.pi * 2.0, vec3(0.0,1.0,0.))
    elseif reset then
        baseObjectRotation = mat3Identity
    end]]

    --[[if not reset then
        baseObjectRotation = baseObjectRotation * additionalRotationComponent
    end

    additionalRotationComponent = mat3Identity]]

end



local function assignRandomVariation()
    local variations = constructable.variations[randomVariationBaseConstructableTypeIndex]
    if variations then
        local randomIndex = rng:randomInteger(#variations) + 1
        constructableTypeIndex = variations[randomIndex]
        --mj:log("assignRandomVariation:", constructableTypeIndex)
    end
end


local buildObjectScale = 1.0

local function createBuildObject()
    if buildModeInteractUI:hidden() then
        return nil
    end

    local posToUse = buildObjectPos
    buildObjectScale = 1.0

    local materialSubstitute = 0
    if (not buildObjectCanBuild) then
        materialSubstitute = material.types.red.index
        buildObjectScale = 1.02
    end

    local constructableType = constructable.types[constructableTypeIndex]

    local modelIndex = constructableType.modelIndex
    local restrictedResourceObjectTypes = nil
    if isDupeBuild then
        restrictedResourceObjectTypes = dupeBuildRestrictedResourceObjectTypes
    else
        restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
    end
    local restrictedResourceTypes = restrictedResourceObjectTypes

    if constructableType.isPlaceType then
        local resourceInfo = constructableType.requiredResources[1]
        local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, restrictedResourceTypes, world:getSeenResourceObjectTypes())
        
        if availableObjectTypeIndexes then
            modelIndex = gameObject.types[availableObjectTypeIndexes[1]].modelIndex
        end
    end

    local buildObjectID = uiObjectManager:addUIModel(
        modelIndex,
        vec3(buildObjectScale,buildObjectScale,buildObjectScale),
        posToUse,
        buildObjectRotation,
        materialSubstitute
    )

    local buildObjectSubIDs = {}

    local function getModelIndexForPlaceholders()
        --[[local modelNameToUse = constructableType.placeholderOverrideModelName
        if not modelNameToUse then
            modelNameToUse = constructableType.inProgressBuildModel
        end]]
        local modelNameToUse = constructableType.inProgressBuildModel
        if not modelNameToUse then
            modelNameToUse = constructableType.modelName
        end
    
        local modelIndexForPlaceholders = model:modelIndexForModelNameAndDetailLevel(modelNameToUse, 1)
        return modelIndexForPlaceholders
    end

    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(modelIndex)
    if placeholderKeys then
        
        local resourceKeys = {}
        local resourceCountersByResourceTypeOrGroup = {}
        local finalCountersByResourceTypeOrGroup = {}
        local modelIndexForPlaceholders = getModelIndexForPlaceholders()
    
        if constructableType.requiredResources then
            for i = 1, #constructableType.requiredResources do
                local groupIndex = i
                local resourceInfo = constructableType.requiredResources[groupIndex]
                local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group
                local requiredCount = resourceInfo.count
                
                if not resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] then
                    resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = 0
                    finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = 1
                end

                local resourceKey = resource:placheolderKeyForGroupOrResource(resourceTypeOrGroupIndex)
                resourceKey = modelPlaceholder:resourceRemapForModelIndexAndResourceKey(modelIndexForPlaceholders, resourceKey) or resourceKey
                local storageKey = resourceKey .. "_store"
                for storageCounter = 1, requiredCount do
                    resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + 1
                    
                    local finalIndexIdentifier = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]
                    
                    local finalKeyBase = resourceKey .. "_"

                    if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, storageKey) then
                        storageKey = "resource_store"
                        finalKeyBase = "resource_"
                    end
                    
                    local mainFinalKey = finalKeyBase .. finalIndexIdentifier

                    local mainPlaceHolderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, mainFinalKey)

                    local finalCount = 1
                    if mainPlaceHolderInfo and mainPlaceHolderInfo.additionalIndexCount and mainPlaceHolderInfo.additionalIndexCount > 0 then
                        finalCount = 1 + mainPlaceHolderInfo.additionalIndexCount
                    end
                    
                    finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + finalCount

                    for finalIndex = 1, finalCount do
                        local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1
                        resourceKeys[finalKey] = true
                    end
                end
            end
        end

        --mj:log("resourceKeys:", resourceKeys)
        --mj:log("restrictedResourceTypes:", restrictedResourceTypes)

        for i,key in pairs(placeholderKeys) do
            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndex, key)

            if (not placeholderInfo.hiddenOnBuildComplete) then
                local modelIndexToUse = placeholderInfo.defaultModelIndex

                if resourceKeys[key] then
                    modelIndexToUse = modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes(placeholderInfo, restrictedResourceTypes, world:getSeenResourceObjectTypes(), nil)
                end

                if modelIndexToUse then
                    local posOffset = uiObjectManager:getPlaceholderOffset(modelIndex, key)
                    local rotatedOffset = vec3xMat3(posOffset * buildObjectScale, mat3Inverse(buildObjectRotation))

                    local rotationOffset = uiObjectManager:getPlaceholderRotation(modelIndex, key)

                    local subModelPos = posToUse + rotatedOffset
                    local subModelRotation = buildObjectRotation * rotationOffset

                    local scale = buildObjectScale * (placeholderInfo.scale or 1.0)
                    local subObjectID = uiObjectManager:addUIModel(
                        modelIndexToUse,
                        vec3(scale,scale,scale),
                        subModelPos,
                        subModelRotation,
                        materialSubstitute
                    )

                    buildObjectSubIDs[subObjectID] = {
                        key = key,
                        posOffset = posOffset,
                        rotationOffset = rotationOffset,
                        offsetToWalkableHeight = placeholderInfo.offsetToWalkableHeight,
                        rotateToWalkableRotation = placeholderInfo.rotateToWalkableRotation,
                        scale = placeholderInfo.scale or 1.0,
                    }
                end
            end
        end
    end

    --[[

    local buildObjectID = uiObjectManager:addUIModel(
        modelIndex,
        vec3(buildObjectScale,buildObjectScale,buildObjectScale),
        posToUse,
        buildObjectRotation,
        materialSubstitute
    )
    ]]

    return {
        modelID = buildObjectID,

        modelIndex = modelIndex,
        scale = buildObjectScale,
        pos = posToUse,
        rotation = buildObjectRotation,

        subModelIDs = buildObjectSubIDs,
    }

end


local connectorDecalBlockerRadius = mj:mToP(1.0)
local connectorDecalBlockerRadius2 = connectorDecalBlockerRadius * connectorDecalBlockerRadius

function buildModeInteractUI:doFinalPlacementIfAble()
    --[[if waitingForBuildConfirm then
        if waitingForBuildConfirmObjectIDToLoad and world:objectIsLoaded(waitingForBuildConfirmObjectIDToLoad) then
            markWaitObjectLoaded()
        else
            return
        end
    end]]
    if finalPositionMode and buildObjectInfo ~= nil and buildObjectCanBuild then
        audio:playUISound("audio/sounds/place.wav")

        local constructableType = constructable.types[constructableTypeIndex]

        local restrictedResourceObjectTypes = nil
        if isDupeBuild then
            restrictedResourceObjectTypes = dupeBuildRestrictedResourceObjectTypes
        else
            restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
        end

        --mj:log("isDupeBuild:", isDupeBuild)
        --mj:log("dupeBuildRestrictedResourceObjectTypes:", dupeBuildRestrictedResourceObjectTypes)
        --mj:log("sending restrictedResourceObjectTypes:", restrictedResourceObjectTypes)

        local planInfo = {
            planTypeIndex = constructableType.planTypeIndex or plan.types.build.index,
            constructableTypeIndex = constructableTypeIndex,
            pos = buildObjectPos,
            rotation = buildObjectRotation,
            restrictedResourceObjectTypes = restrictedResourceObjectTypes,
            restrictedToolObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, true),
            attachedToTerrain = attachedToTerrain,
            noBuildOrder = noBuildOrderModifierDown,
        }

        local function addUnconfirmedInfo()
            local unconfirmedID = unconfirmedIndexCounter
            unconfirmedIndexCounter = unconfirmedIndexCounter + 1

            local modelInfo = createBuildObject()

            unconfirmedInfos[unconfirmedID] = {
                unconfirmedID = unconfirmedID,
                planInfo = planInfo,
                modelInfo = modelInfo
            }
            return unconfirmedID
        end

        
        if constructableType.isPathType then
            local sendNodes = {}

            for i,nodeInfo in ipairs(pathNodes) do

                local sendNodeInfo = {
                    pos = nodeInfo.pos,
                    rotation = nodeInfo.rotation,
                    decalBlockers = {}
                }
                sendNodes[i] = sendNodeInfo

                local pathSubModelInfos = pathSubModelInfosByNode[i]
                if pathSubModelInfos and pathSubModelInfos[1] then
                    for j,info in ipairs(pathSubModelInfos) do

                        local placementInfo = info.placementInfo

                        sendNodeInfo.decalBlockers[j] = {
                            pos = placementInfo.pos,
                            radius2 = connectorDecalBlockerRadius2
                        }
                    end
                end
            end

            pathStringInitialNodePos = pathNodes[1].pos

            planInfo.nodes = sendNodes

            --mj:log("sending planInfo:", planInfo)
            

            --waitingForBuildConfirm = true
            --waitingForBuildConfirmObjectIDToLoad = nil
            local unconfirmedID = addUnconfirmedInfo()
            logicInterface:callServerFunction("addPathPlacementPlans", planInfo, function(lastBuildObjectInfo)
                --waitingForBuildConfirm = false
                if not buildModeInteractUI:hidden() then
                    if lastBuildObjectInfo and constructableType.isPathType then 
                        pathStringInitialNodePos = lastBuildObjectInfo.pos
                    end
                end
                
                local unconfirmedInfo = unconfirmedInfos[unconfirmedID]
                if unconfirmedInfo then
                    if lastBuildObjectInfo and lastBuildObjectInfo.uniqueID then
                        unconfirmedInfo.objectID = lastBuildObjectInfo.uniqueID
                    else
                        removeUnconfirmedInfo(unconfirmedID)
                        audio:playUISound(uiCommon.failSoundFile)
                    end
                end

            end)
        else
            --waitingForBuildConfirm = true
            --waitingForBuildConfirmObjectIDToLoad = nil

            local unconfirmedID = addUnconfirmedInfo()
            logicInterface:callServerFunction("addPlans", planInfo, function(result)
                local unconfirmedInfo = unconfirmedInfos[unconfirmedID]
                if unconfirmedInfo then
                    if result then
                        unconfirmedInfo.objectID = result
                    else
                        removeUnconfirmedInfo(unconfirmedID)
                        audio:playUISound(uiCommon.failSoundFile)
                    end
                end
                
                --[[if result and (not buildModeInteractUI:hidden()) then
                    if world:objectIsLoaded(result) then
                        waitingForBuildConfirm = false
                    else
                        waitingForBuildConfirmObjectIDToLoad = result
                        waitingForBuildConfirmSanityCallbackTimer = timer:addCallbackTimer(2.0, function()
                            waitingForBuildConfirmObjectIDToLoad = nil
                            waitingForBuildConfirmSanityCallbackTimer = nil
                            waitingForBuildConfirm = false
                        end)
                    end
                else
                    waitingForBuildConfirm = false
                end]]
            end)
        end
        --buildModeInteractUI:hide()

        setRandomInitialRotation(constructableType)
        if useRandomVariation then
            assignRandomVariation()
        end
        finalPositionMode = false
        if finalPositionWorldView then
            finalPositionWorldView.view.hidden = true
            finalPositionConfirmWorldView.view.hidden = true
        end
        gameUI:updateUIHidden()
    end
end

local function initializeFinalControls()
    local view = finalPositionWorldView.view
    view.size = vec2(1.0, 1.0)
    view.baseOffset = vec3(0.0,0.0,0.0)
    local scaleToUse = 0.5

    local function addToSelectedControlsIfNeeded(info)
        for i,otherInfo in ipairs(selectedControls) do
            if otherInfo.view == info.view then
                return
            end
        end
        table.insert(selectedControls, info)
        updateSelection()
    end

    local function removeFromSelectedControls(info)
        for i,otherInfo in ipairs(selectedControls) do
            if otherInfo.view == info.view then
                table.remove(selectedControls, i)
                updateSelection()
                return
            end
        end
    end

    local function addArrow(mat, matHover, rotation, axisIndex)
        local arrowView = ModelView.new(view)
        arrowView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        if rotation then
            arrowView.rotation = rotation
        end
        arrowView:setUsesModelHitTest(true)
        arrowView:setModel(model:modelIndexForName("moveArrow"), {
            default = mat
        })
        arrowView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
        arrowView.size = vec2(view.size.x, view.size.y)

        local selectionInfo = {
            view = arrowView,
            mat = mat,
            matHover = matHover,
            modelName = "moveArrow",
        }
    
        arrowView.hoverStart = function ()
            addToSelectedControlsIfNeeded(selectionInfo)
        end
        arrowView.hoverEnd = function ()
            removeFromSelectedControls(selectionInfo)
        end

        arrowView.mouseDown = function(buttonIndex)
            if buttonIndex == 0 then
                if (not mouseDownControl) and currentSelection and currentSelection.view == arrowView then
                    mouseDownControl = selectionInfo

                    local function getValue(objectStartPos)
                        local rayStart = world:getPointerRayStart()
                        local rayDirection = world:getPointerRayDirection()
                        local objectSpaceRayStart = vec3xMat3(rayStart - objectStartPos, buildObjectRotation)
                        local objectSpaceRayDirection = normalize(vec3xMat3(rayDirection, buildObjectRotation))
                        local planeNormal = nil
                        if axisIndex == 0 then
                            planeNormal = normalize(vec3(0.0, objectSpaceRayStart.y, objectSpaceRayStart.z))
                        elseif axisIndex == 1 then
                            planeNormal = normalize(vec3(objectSpaceRayStart.x, 0.0, objectSpaceRayStart.z))
                        else
                            planeNormal = normalize(vec3(objectSpaceRayStart.x, objectSpaceRayStart.y, 0.0))
                        end
                        local planeDistance = mjm.rayPlaneIntersectionDistance(objectSpaceRayStart, objectSpaceRayDirection, vec3(0.0,0.0,0.0), planeNormal)
                        if planeDistance then
                            local intersectionPoint = objectSpaceRayStart + objectSpaceRayDirection * planeDistance
                            if axisIndex == 0 then
                                return intersectionPoint.x
                            elseif axisIndex == 1 then
                                return intersectionPoint.y
                            else
                                return intersectionPoint.z
                            end
                        end
                        return nil
                    end

                    local objectStartPos = buildObjectPos
                    local startValue = getValue(objectStartPos)
                    if startValue then
                        arrowView.update = function(dt)
                            local thisValue = getValue(objectStartPos)
                            if thisValue then
                                local valueDifference = mjm.clamp(thisValue - startValue, -maxTranslationDistance, maxTranslationDistance)
                                buildObjectPos = objectStartPos + mat3GetRow(buildObjectRotation, axisIndex) * valueDifference
                                updateFinalControls()
                            end
                        end
                    end
                    updateSelection()
                end
            end
        end
        
        arrowView.mouseUp = function()
            if mouseDownControl and mouseDownControl.view == arrowView then
                mouseDownControl = nil
                arrowView.update = nil
                updateSelection()
            end
        end

        return arrowView
    end

    local function addRotation(mat, matHover, rotation, axisIndex)
        local rotateView = ModelView.new(view)
        rotateView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        if rotation then
            rotateView.rotation = rotation
        end
        rotateView:setUsesModelHitTest(true)
        rotateView:setModel(model:modelIndexForName("rotateHandle"), {
            default = mat
        })
        rotateView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse) * 1.5
        rotateView.size = view.size * 1.5
        
        local selectionInfo = {
            view = rotateView,
            mat = mat,
            matHover = matHover,
            modelName = "rotateHandle",
        }
    
        rotateView.hoverStart = function ()
            addToSelectedControlsIfNeeded(selectionInfo)
        end
        rotateView.hoverEnd = function ()
            removeFromSelectedControls(selectionInfo)
        end
        

        rotateView.mouseDown = function(buttonIndex)
            if buttonIndex == 0 then
                if (not mouseDownControl) and currentSelection and currentSelection.view == rotateView then
                    mouseDownControl = selectionInfo

                    local function getAngle(objectStartRotation)
                        local rayStart = world:getPointerRayStart()
                        local rayDirection = world:getPointerRayDirection()
                        local objectSpaceRayStart = vec3xMat3(rayStart - buildObjectPos, objectStartRotation)
                        local objectSpaceRayDirection = normalize(vec3xMat3(rayDirection, objectStartRotation))
                        local planeNormal = nil
                        if axisIndex == 0 then
                            planeNormal = vec3(1.0,0.0,0.0)
                        elseif axisIndex == 1 then
                            planeNormal = vec3(0.0,1.0,0.0)
                        else
                            planeNormal = vec3(0.0,0.0,1.0)
                        end
                        local planeDistance = mjm.rayPlaneIntersectionDistance(objectSpaceRayStart, objectSpaceRayDirection, vec3(0.0,0.0,0.0), planeNormal)
                        if planeDistance then
                            local intersectionPoint = objectSpaceRayStart + objectSpaceRayDirection * planeDistance
                            if axisIndex == 0 then
                                return math.atan2(intersectionPoint.z, intersectionPoint.y)
                            elseif axisIndex == 1 then
                                return math.atan2(intersectionPoint.x, intersectionPoint.z)
                            else
                                return math.atan2(intersectionPoint.y, intersectionPoint.x)
                            end
                        end
                        return nil
                    end

                    local objectStartRotation = buildObjectRotation
                --  local objectStartAdditionalRotationComponent = additionalRotationComponent
                    local startAngle = getAngle(objectStartRotation)
                    if startAngle and not mj:isNan(startAngle) then
                        rotateView.update = function(dt)
                            local thisAngle = getAngle(objectStartRotation)
                            if thisAngle and not mj:isNan(thisAngle) then
                                local angleDifference = thisAngle - startAngle
                                if math.abs(angleDifference) > 0.01 then
                                    if axisIndex == 0 then
                                        buildObjectRotation = mat3Rotate(objectStartRotation, angleDifference, vec3(1.0,0.0,0.0))
                                    elseif axisIndex == 1 then
                                        buildObjectRotation = mat3Rotate(objectStartRotation, angleDifference, vec3(0.0,1.0,0.0))
                                    else
                                        buildObjectRotation = mat3Rotate(objectStartRotation, angleDifference, vec3(0.0,0.0,1.0))
                                    end
                                    updateFinalControls()
                                end
                            end
                        end
                    end
                    updateSelection()
                end
            end
        end
        
        rotateView.mouseUp = function()
            if mouseDownControl and mouseDownControl.view == rotateView then
                mouseDownControl = nil
                rotateView.update = nil
                updateSelection()
            end
        end

        return rotateView
    end

    local xRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,-1.0))
    local zRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(1.0,0.0,0.0))

    finalPositionXTranslationView = addArrow(material.types.red.index, material.types.lightRed.index, xRotation, 0)
    finalPositionYTranslationView = addArrow(material.types.green.index, material.types.lightGreen.index, nil, 1)
    finalPositionZTranslationView = addArrow(material.types.blue.index, material.types.lightBlue.index, zRotation, 2)

    finalPositionXrotationView = addRotation(material.types.red.index, material.types.lightRed.index, xRotation, 0)
    finalPositionYrotationView = addRotation(material.types.green.index, material.types.lightGreen.index, nil, 1)
    finalPositionZrotationView = addRotation(material.types.blue.index, material.types.lightBlue.index, zRotation, 2)

    allFinalPositionViews[1] = finalPositionXTranslationView
    allFinalPositionViews[2] = finalPositionYTranslationView
    allFinalPositionViews[3] = finalPositionZTranslationView
    allFinalPositionViews[4] = finalPositionXrotationView
    allFinalPositionViews[5] = finalPositionYrotationView
    allFinalPositionViews[6] = finalPositionZrotationView

    local confirmWorldView = finalPositionConfirmWorldView.view
    local confirmButtonRadius = finalPositionConfirmButtonRadius
    local iconRadius = confirmButtonRadius * 0.4

    local function addButton(iconName, groupKey, mappingKey, controllerSetIndex, controllerActionName, buttonInfo, offset, clickFunction)
        local buttonBackgroundView = ModelView.new(confirmWorldView)
        buttonBackgroundView:setModel(model:modelIndexForName("ui_order"))
        buttonBackgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        buttonBackgroundView:setUsesModelHitTest(true)
        buttonBackgroundView.baseOffset = offset
        buttonBackgroundView.scale3D = vec3(confirmButtonRadius,confirmButtonRadius,confirmButtonRadius)
        buttonBackgroundView.size = vec2(confirmButtonRadius, confirmButtonRadius)
        
        
        local icon = ModelView.new(buttonBackgroundView)
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        icon.baseOffset = vec3(0, finalPositionConfirmButtonRadius * 0.1, 0.01)
        icon.scale3D = vec3(iconRadius,iconRadius,iconRadius)
        icon.size = vec2(iconRadius, iconRadius)

        icon:setModel(model:modelIndexForName(iconName))
        

        --[[local keyCodeTextView = ModelTextView.new(buttonBackgroundView)
        keyCodeTextView.font = Font(uiCommon.fontName, 24)
        keyCodeTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        keyCodeTextView:setText(keyCodeText, material.types.standardText.index)]]


        local keyImage = uiKeyImage:create(buttonBackgroundView, shortcutKeyImageViewHeight, groupKey, mappingKey, controllerSetIndex, controllerActionName, nil)
        uiKeyImage:setGeometryScale(keyImage, finalPositionConfirmButtonRadius * shortcutKeyImageViewScale)

        buttonInfo.buttonBackgroundView = buttonBackgroundView
        buttonInfo.icon = icon
        buttonInfo.keyImage = keyImage
        
        buttonBackgroundView.update = function(dt)
            local info = buttonInfo
            if (not approxEqual(info.goalSize, info.currentSize)) or (not approxEqual(info.differenceVelocity, 0.0)) then
                local difference = info.goalSize - info.currentSize
                local clampedDT = mjm.clamp(dt * 40.0, 0.0, 1.0)
                info.differenceVelocity = info.differenceVelocity * math.max(1.0 - dt * 20.0, 0.0) + (difference * clampedDT)
                info.currentSize = info.currentSize + info.differenceVelocity * dt * 12.0

                local iconRadiusToUse = info.currentSize
                buttonBackgroundView.scale3D = vec3(iconRadiusToUse,iconRadiusToUse,iconRadiusToUse)
                buttonBackgroundView.size = vec2(info.currentSize, info.currentSize) * 2.0
                local logoHalfSize = info.currentSize * 0.4
                icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
                icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0
                icon.baseOffset = vec3(0, info.currentSize * 0.25, 0.01)

                uiKeyImage:setGeometryScale(keyImage, buttonInfo.currentSize * shortcutKeyImageViewScale)
                --keyCodeTextView.fontGeometryScale = info.currentSize * 0.01
                keyImage.baseOffset = vec3(0.0, -info.currentSize * 0.4, 0.02)
            end
        end
        
        buttonBackgroundView.hoverStart = function ()
            buttonInfo.selected = true
            buttonInfo.goalSize = confirmButtonRadius * 1.5
        end
        buttonBackgroundView.hoverEnd = function ()
            buttonInfo.selected = false
            buttonInfo.goalSize = confirmButtonRadius
        end
        
        buttonBackgroundView.click = function ()
            if buttonInfo.selected then
                clickFunction()
            end
        end
    end

    

    --"game", "confirm", eventManager.controllerSetIndexMenu, "menuSelect"
    --groupKey, mappingKey, controllerSetIndex, controllerActionName
    --
	--addDigitalControllerMap(eventManager.controllerSetIndexInGame, "confirm")
	--addDigitalControllerMap(eventManager.controllerSetIndexInGame, "cancel")

    addButton("icon_crossRed", "building", "cancel", eventManager.controllerSetIndexInGame, "cancel", crossButtonInfo, vec3(-0.25,0.0,0.0), function()
        buildModeInteractUI:hide()
    end)
    addButton("icon_tick", "building", "confirm", eventManager.controllerSetIndexInGame, "confirm", tickButtonInfo, vec3(0.25,0.0,0.0), function()
        buildModeInteractUI:doFinalPlacementIfAble()
    end)

    resetFinalPositionViews()

end

function buildModeInteractUI:enterFinalPositionMode()
    if (not finalPositionMode) and buildObjectInfo ~= nil and buildObjectCanBuild then
        finalPositionMode = true
        logicInterface:callLogicThreadFunction("hideObjectsForBuildModeEnd")

        
        mouseExtraPosOffsets = vec3(0.0,0.0,0.0)
        mouseExtraRotation = mat3Identity
        objectExtraRotationDueToKeysOrDupe = mat3Identity


        local lookAtPos =  localPlayer.lookAtPosition
        if localPlayer.lookAtPositionMainThread then
            lookAtPos = localPlayer.lookAtPositionMainThread
        end
        local lookAtPosNormal = normalize(lookAtPos)
        local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)
        finalControlsRotationMatrix = mat3LookAtInverse(directionNormal, lookAtPosNormal)

        --[[

            local lookAtPos =  localPlayer.lookAtPosition
            if localPlayer.lookAtPositionMainThread then
                lookAtPos = localPlayer.lookAtPositionMainThread
            end
            local lookAtPosNormal = normalize(lookAtPos)
            
            if zAxisAndDisableSnapModifierDown then
                if constructable.types[constructableTypeIndex].allowYTranslation then
                    local offset = mj:mToP(relativeMovement.y * -0.01)
                    mouseExtraPosOffsets.y = mouseExtraPosOffsets.y + offset
                    buildObjectPos = buildObjectPos + lookAtPosNormal * offset
                end
            else
                local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)
        ]]
        
        if not finalPositionWorldView then
            finalPositionWorldView = worldUIViewManager:addView(buildObjectPos,  worldUIViewManager.groups.buildUI, {
                constantRotationMatrix = buildObjectRotation,
                renderXRay = true,
            })
            --mj:log("finalPositionWorldView uniqueID:", finalPositionWorldView.uniqueID)
            finalPositionConfirmWorldView = worldUIViewManager:addView(buildObjectPos, worldUIViewManager.groups.buildUI, {
                baseRotation = buildObjectRotation,
                offsets = {{ 
                    worldOffset = vec3(0.0, mj:mToP(1.0), mj:mToP(0.0))
                }},
                renderXRay = true,
            })
            --mj:log("finalPositionConfirmWorldView uniqueID:", finalPositionConfirmWorldView.uniqueID)
            initializeFinalControls()
        else
            updateFinalControls()
            finalPositionWorldView.view.hidden = false
            finalPositionConfirmWorldView.view.hidden = false

            resetFinalPositionViews()
        end

        if constructable.types[constructableTypeIndex].allowYTranslation then
            finalPositionYTranslationView.hidden = false
        else
            finalPositionYTranslationView.hidden = true
        end

        if constructable.types[constructableTypeIndex].allowXZRotation then
            finalPositionXrotationView.hidden = false
            finalPositionZrotationView.hidden = false
        else
            finalPositionXrotationView.hidden = true
            finalPositionZrotationView.hidden = true
        end
        
        gameUI:updateUIHidden()
        
    end
end


local function updateBuildObject()

    
    --mj:log("updateBuildObject:", buildObjectPos)

    uiObjectManager:updateUIModel(
        buildObjectInfo.modelID,
        buildObjectPos,
        buildObjectRotation,
        1.0,
        true
    )
    
    if buildObjectInfo.subModelIDs then
        local walkableOffsetRequestInfo = nil
        for subID,info in pairs(buildObjectInfo.subModelIDs) do
            
            local rotatedOffset = vec3xMat3(info.posOffset * buildObjectScale, mat3Inverse(buildObjectRotation))
            local finalPosition = buildObjectPos + rotatedOffset
            local baseRotation = buildObjectRotation

            if info.offsetToWalkableHeight or info.rotateToWalkableRotation then
                if not walkableOffsetRequestInfo then
                    walkableOffsetRequestInfo = {}
                end
                walkableOffsetRequestInfo[subID] = {
                    basePos = finalPosition,
                    requiresRotation = info.rotateToWalkableRotation
                }

                if info.offsetToWalkableHeight and info.currentWalkableOffset then
                    
                    if not info.lerpedWalkableOffset then
                        info.lerpedWalkableOffset = info.currentWalkableOffset
                    else
                        info.lerpedWalkableOffset = mjm.mix(info.lerpedWalkableOffset, info.currentWalkableOffset, 0.3)
                    end
                    finalPosition = finalPosition + info.lerpedWalkableOffset + vec3xMat3(vec3(0.0,info.posOffset.y, 0.0) * buildObjectScale, mat3Inverse(buildObjectRotation))
                end
                
                if info.rotateToWalkableRotation and info.currentWalkableUpVector then

                    if not info.lerpedUpVector then
                        info.lerpedUpVector = info.currentWalkableUpVector
                    else
                        info.lerpedUpVector = normalize(mjm.mix(info.lerpedUpVector, info.currentWalkableUpVector, 0.3))
                    end

                    baseRotation = createUpAlignedRotationMatrix(info.lerpedUpVector, mat3GetRow(baseRotation, 2))


                    --[[local incomingRotation = createUpAlignedRotationMatrix(info.currentWalkableUpVector, mat3GetRow(baseRotation, 2))
                    if not info.slerpedRotation then 
                        info.slerpedRotation = incomingRotation
                    else
                        info.slerpedRotation = mjm.mat3Slerp(info.slerpedRotation, incomingRotation, 0.2)
                    end

                    baseRotation = info.slerpedRotation]]

                end
            end
            
            uiObjectManager:updateUIModel(
                subID,
                finalPosition,
                baseRotation * info.rotationOffset,
                1.0,
                true
            )
        end

        if walkableOffsetRequestInfo then
            local requestBuildObjectID = buildObjectInfo.modelID
            logicInterface:callLogicThreadFunction("getWalkableOffsets", walkableOffsetRequestInfo, function(offsetResults)
                if not buildModeInteractUI:hidden() then
                    if buildObjectInfo and requestBuildObjectID == buildObjectInfo.modelID then
                        for subID,info in pairs(buildObjectInfo.subModelIDs) do
                            local thisResult = offsetResults[subID]
                            if thisResult then
                                info.currentWalkableOffset = thisResult.offset
                                info.currentWalkableUpVector = thisResult.up
                            end
                        end
                    end
                end
            end)
        end
    end
end

local function updatePathSubObjects()
    local pathNodesCount = 0

    if pathNodes and pathNodes[1] then
        pathNodesCount = #pathNodes
        if not pathSubModelInfosByNode then
            pathSubModelInfosByNode = {}
        end
        
        local constructableType = constructable.types[constructableTypeIndex]
        local restrictedResourceObjectTypes = nil
        if isDupeBuild then
            restrictedResourceObjectTypes = dupeBuildRestrictedResourceObjectTypes
        else
            restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
        end
        local resourceInfo = constructableType.requiredResources[1]
        local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, restrictedResourceObjectTypes, world:getSeenResourceObjectTypes())

        for j,nodeInfo in ipairs(pathNodes) do
            local pathSubModelInfos = pathSubModelInfosByNode[j]
            if nodeInfo.pathSubModelUpdatedInfos then
                if not pathSubModelInfos then
                    pathSubModelInfos = {}
                    pathSubModelInfosByNode[j] = pathSubModelInfos
                end
                for i,subModelUpdatedInfo in ipairs(nodeInfo.pathSubModelUpdatedInfos) do
                    if pathSubModelInfos[i] then
                        uiObjectManager:updateUIModel(
                            pathSubModelInfos[i].subObjectID,
                            subModelUpdatedInfo.pos,
                            buildObjectRotation * subModelUpdatedInfo.rotation,
                            1.0,
                            true
                        )
                        local placementInfo = pathSubModelInfos[i].placementInfo
                        placementInfo.pos = subModelUpdatedInfo.pos
                        placementInfo.rotation = subModelUpdatedInfo.rotation
                    else
                        local materialSubstitute = 0
                        if not buildObjectCanBuild then
                            materialSubstitute = material.types.red.index
                        end
        
                        local scale = buildObjectScale * subModelUpdatedInfo.scale

                        local modelName = constructableType.defaultSubModelName
                        if availableObjectTypeIndexes then
                            modelName = constructableType.subModelNameByObjectTypeIndexFunction(availableObjectTypeIndexes[1])
                        end

                        local subObjectID = uiObjectManager:addUIModel(
                            model:modelIndexForName(modelName),
                            vec3(scale,scale,scale),
                            subModelUpdatedInfo.pos,
                            buildObjectRotation * subModelUpdatedInfo.rotation,
                            materialSubstitute
                        )
        
                        pathSubModelInfos[i] = {
                            subObjectID = subObjectID,
                            placementInfo = {
                                pos = subModelUpdatedInfo.pos,
                                rotation = subModelUpdatedInfo.rotation,
                                scale = subModelUpdatedInfo.scale,
                            },
                        }
                    end
                end
            end

            if pathSubModelInfos then
                local pathSubModelUpdatedInfosCount = 0
                if nodeInfo.pathSubModelUpdatedInfos then
                    pathSubModelUpdatedInfosCount = #nodeInfo.pathSubModelUpdatedInfos
                end
        
                if #pathSubModelInfos > pathSubModelUpdatedInfosCount then
                    for i = #pathSubModelInfos,pathSubModelUpdatedInfosCount + 1,-1 do
                        local info = pathSubModelInfos[i]
                        uiObjectManager:removeUIModel(info.subObjectID) --remove
                        table.remove(pathSubModelInfos, i)
                    end
                end
            end

            if j > 1 then
                if not pathMainNodeSubModelInfosByNode then
                    pathMainNodeSubModelInfosByNode = {}
                end

                if pathMainNodeSubModelInfosByNode[j] then
                    for i,subModelInfo in ipairs(pathMainNodeSubModelInfosByNode[j]) do
                        uiObjectManager:updateUIModel(
                            subModelInfo.modelID,
                            nodeInfo.pos + subModelInfo.posOffset,
                            nodeInfo.rotation * subModelInfo.rotationOffset,
                            1.0,
                            true
                        )
                    end
                    --mj:log("uiObjectManager:updateUIModel:", j, " id:", pathMainNodeSubModelIDsByNode[j], " nodeInfo.pos:", nodeInfo.pos, " main node pos:", pathNodes[1].pos)
                else
                    local materialSubstitute = 0
                    if not buildObjectCanBuild then
                        materialSubstitute = material.types.red.index
                    end

                   -- mj:log("constructable.types[constructableTypeIndex].modelIndex:", constructable.types[constructableTypeIndex].modelIndex)

                   --[[ local modelName = constructableType.modelName
                    if availableObjectTypeIndexes then
                        modelName = constructableType.mainModelNameByObjectTypeIndexFunction(availableObjectTypeIndexes[1])
                    end

                    local modelIndex = constructable.types[constructableTypeIndex].modelIndex]]

                   --[[ local subObjectID = uiObjectManager:addUIModel(
                        constructable.types[constructableTypeIndex].modelIndex,
                        vec3(buildObjectScale,buildObjectScale,buildObjectScale),
                        nodeInfo.pos,
                        nodeInfo.rotation,
                        materialSubstitute
                    )]]
                    pathMainNodeSubModelInfosByNode[j] = { 
                       --[[ {
                            modelID = subObjectID,
                            posOffset = vec3(0.0,0.0,0.0),
                            rotationOffset = mat3Identity,
                        }]]
                    }
                    
                    local modelIndex = constructable.types[constructableTypeIndex].modelIndex

                    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(constructable.types[constructableTypeIndex].modelIndex)
                    if placeholderKeys then
                        for i,key in pairs(placeholderKeys) do
                            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndex, key)
                            local modelIndexToUse = modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes(placeholderInfo, restrictedResourceObjectTypes, world:getSeenResourceObjectTypes(), nil)
                            if modelIndexToUse then

                                local posOffset = uiObjectManager:getPlaceholderOffset(modelIndex, key)
                                local rotatedOffset = vec3xMat3(posOffset * buildObjectScale, mat3Inverse(nodeInfo.rotation))

                                local rotationOffset = uiObjectManager:getPlaceholderRotation(modelIndex, key)

                                local subModelPos = nodeInfo.pos + rotatedOffset
                                local subModelRotation = nodeInfo.rotation * rotationOffset
                                local scale = buildObjectScale * (placeholderInfo.scale or 1.0)

                                local subModelID = uiObjectManager:addUIModel(
                                    modelIndexToUse,
                                    vec3(scale,scale,scale),
                                    subModelPos,
                                    subModelRotation,
                                    materialSubstitute
                                )

                                table.insert(pathMainNodeSubModelInfosByNode[j],{
                                    modelID = subModelID,
                                    posOffset = rotatedOffset,
                                    rotationOffset = rotationOffset,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    if pathMainNodeSubModelInfosByNode then
        for j,subModelInfos in pairs(pathMainNodeSubModelInfosByNode) do
            if not pathNodes[j] then
                for i, subModelInfo in ipairs(subModelInfos) do
                    uiObjectManager:removeUIModel(subModelInfo.modelID)
                end
                pathMainNodeSubModelInfosByNode[j] = nil
            end
        end
    end
    
    if pathSubModelInfosByNode then
        for j,pathSubModelInfos in pairs(pathSubModelInfosByNode) do
            if j > pathNodesCount then
                for i,info in ipairs(pathSubModelInfos) do
                    uiObjectManager:removeUIModel(info.subObjectID)
                end
                pathSubModelInfosByNode[j] = nil
            end
        end
    end
end

local pathTestOffsets = pathBuildable.pathTestOffsets

local function expireUncomfirmed(expireUnloadedObjects)
    local removeKeys = {}

    for unconfirmedID, unconfirmedInfo in pairs(unconfirmedInfos) do
        if expireUnloadedObjects or unconfirmedInfo.objectID and world:objectIsLoaded(unconfirmedInfo.objectID) then
            table.insert(removeKeys, unconfirmedID)
        end
    end

    for i,unconfirmedID in ipairs(removeKeys) do
        removeUnconfirmedInfo(unconfirmedID)
    end
end

local rotationBaseFromInitialCick = nil
local buildObjectBaseLookAtPos = nil

local function updateBuildDisplay()

    expireUncomfirmed(false)

    local function getRotation(directionNormal, up)
        if rotationBaseFromInitialCick and gameUI:pointAndClickModeEnabled() then
            return rotationBaseFromInitialCick * mouseExtraRotation
        end

        local baseRotation = mat3LookAtInverse(directionNormal, up)
        --baseRotation = mat3Rotate(baseRotation, mouseExtraRotationOffsets.y, vec3(0.0,1.0,0.0)) -- mouseExtraRotationOffset needs to be a matrix, rotated above.
        --baseRotation = mat3Rotate(baseRotation, mouseExtraRotationOffsets.z, vec3(0.0,0.0,1.0))

        rotationBaseFromInitialCick = baseRotation
        return rotationBaseFromInitialCick * mouseExtraRotation
    end

    local constructableType = constructable.types[constructableTypeIndex]

    local rotation = buildObjectRotation
    local buildPos = buildObjectPos

    if (not finalPositionMode) then
        if ((not buildObjectBaseLookAtPos) or (not buildModeInteractUI:shouldOwnMouseMoveControl()) and (not gameUI:pointAndClickModeHasHiddenMouseForMoveControl())) then
            local lookAtPos =  localPlayer.lookAtPosition
            if localPlayer.lookAtPositionMainThread then
                lookAtPos = localPlayer.lookAtPositionMainThread
            end
            if constructableType.isPathType and localPlayer.lookAtPositionMainThreadTerrain then
                lookAtPos = localPlayer.lookAtPositionMainThreadTerrain
            end
            buildObjectBaseLookAtPos = lookAtPos
        end

        local lookAtPosNormal = normalize(buildObjectBaseLookAtPos)
        local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)

        rotation = getRotation(directionNormal, lookAtPosNormal) * objectExtraRotationDueToKeysOrDupe
        
        local backVector = directionNormal
        local rightVector = normalize(cross(lookAtPosNormal, backVector))
        local forwardVector = normalize(cross(lookAtPosNormal, rightVector))

        buildPos = buildObjectBaseLookAtPos + rightVector * mouseExtraPosOffsets.x + lookAtPosNormal * mouseExtraPosOffsets.y + forwardVector * mouseExtraPosOffsets.z
    end

    --local initialRotation = rotation

    local canBuild = true
   -- local pathSubModelUpdatedInfos = nil

    local function finalize(buildObjectPosNew, buildObjectRotationNew, buildObjectCanBuildNew)
        if buildModeInteractUI:hidden() then
            return
        end

        buildObjectPos = buildObjectPosNew
        buildObjectRotation = buildObjectRotationNew
        buildObjectCanBuild = buildObjectCanBuildNew
        
        if buildObjectCanBuild ~= currentModelDisplayedCanBuild or not buildObjectInfo then
            buildModeInteractUI:removeBuildObjects()
            buildObjectInfo = createBuildObject()
            currentModelDisplayedCanBuild = buildObjectCanBuild
        else
            updateBuildObject()
        end

        updatePathSubObjects()
    end
    

   local orderedUnconfirmedInfos = nil
   if next(unconfirmedInfos) then
       orderedUnconfirmedInfos = {}
       for unconfirmedID, unconfirmedInfo in pairs(unconfirmedInfos) do

           local gameObjectType = nil
           local unconfirmedConstructableType = constructable.types[unconfirmedInfo.planInfo.constructableTypeIndex]
           if not unconfirmedConstructableType.buildSequence then
               gameObjectType = gameObject.types[unconfirmedConstructableType.finalGameObjectTypeKey]
           else
               gameObjectType = gameObject.types[unconfirmedConstructableType.inProgressGameObjectTypeKey]
           end

           table.insert(orderedUnconfirmedInfos, {
               unconfirmedID = unconfirmedID,
               modelIndex = unconfirmedInfo.modelInfo.modelIndex,
               pos = unconfirmedInfo.modelInfo.pos,
               rotation = unconfirmedInfo.modelInfo.rotation,
               scale = unconfirmedInfo.modelInfo.scale,
               objectTypeIndex = gameObjectType.index,
           })
       end
   end

    if constructableType.isPathType then
        
        local minDistance = mj:mToP(1.5)
        local minDistance2 = minDistance * minDistance
        local subModelMinDistances = {
            mj:mToP(1.51),
            mj:mToP(2.0),
            mj:mToP(2.5),
            mj:mToP(2.75)
        }
        
        local addSubModelsMaxDistance2 = pathBuildable.maxDistanceBetweenPathNodes * pathBuildable.maxDistanceBetweenPathNodes
        local subModelRightOffset = mj:mToP(0.3)
        
        local function offsetPathNodeToTerrain(nodeInfo)
            local maxAltitude = nil
            --local averageNormal = vec3(0.0,0.0,0.0)
            for i=1,4 do
                local rotatedOffset = vec3xMat3(pathTestOffsets[i] * buildObjectScale, mat3Inverse(nodeInfo.rotation))
                local finalPosition = nodeInfo.pos + rotatedOffset
                local terrainAltitudeResult = world:getMainThreadTerrainAltitude(finalPosition)
                if terrainAltitudeResult.hasHit then
                    if ((not maxAltitude) or terrainAltitudeResult.terrainAltitude > maxAltitude) then
                        maxAltitude = terrainAltitudeResult.terrainAltitude
                        --averageNormal = terrainAltitudeResult.normal
                    end
                end
            end
            
            if maxAltitude then
                local buildPosLength = length(nodeInfo.pos)
                local buildPosNormal = nodeInfo.pos / buildPosLength
                --local buildPosAltitude = buildPosLength - 1.0
                --local altitudeDifference = maxAltitude - buildPosAltitude
                --if altitudeDifference > 0.0 then
                    nodeInfo.pos = buildPosNormal * (maxAltitude + 1.0)
                    --local averageNormalSplit = normalize(mix(normalize(averageNormal), buildPosNormal, 0.5))
                    --rotation = createUpAlignedRotationMatrix(averageNormalSplit, mat3GetRow(rotation, 2))
                --end
            end
        end

        

        

        local buildPosLength = length(buildPos)
        local buildPosNormal = buildPos / buildPosLength
        local potentialSnapablesResult = world:objectCentersRadiusTest(buildPos, mj:mToP(4.0), physicsSets.pathSnappables)
        pathNodes = {}


        if potentialSnapablesResult.hasHitObject then
            

            local function checkDistance(nodePos)
                local snapObjectNormalizedPos = normalize(nodePos)
                local closestObjectDirectionVector = buildPosNormal - snapObjectNormalizedPos
                local distance2 = length2(closestObjectDirectionVector)
                --mj:log("snapObject:", snapObject.uniqueID, "distance:", mj:pToM(math.sqrt(distance2)), "buildPos:", buildPos, " snapObject.pos:", snapObject.pos)
                if distance2 < minDistance2 then
                    local closestObjectDirectionVectorLength = length(closestObjectDirectionVector)
                    buildPosNormal = normalize(snapObjectNormalizedPos + (closestObjectDirectionVector / closestObjectDirectionVectorLength) * minDistance)
                    buildPos = buildPosNormal * buildPosLength
                end
            end

            for i,snapObject in ipairs(potentialSnapablesResult.objectHits) do
                checkDistance(snapObject.pos)
            end

            if orderedUnconfirmedInfos then
                for i,orderedUnconfirmedInfo in ipairs(orderedUnconfirmedInfos) do
                    checkDistance(orderedUnconfirmedInfo.pos) --assumes you haven't switched from object building to path building somehow in a lag spike
                end
            end
        end

        pathNodes[1] = {
            pos = buildPos,
            rotation = rotation,
            decalBlockers = nil
        }

        offsetPathNodeToTerrain(pathNodes[1])


        local function addConnectingSubModels(nodeInfo, snapObjectPos, nodePos, nodePosNormal, objectDirectionVector, objectDirectionVectorLength, snapObjectIDOrNil)
            --local objectDirectionVectorLength = math.sqrt(objectDirectionVectorLength2)

            if objectDirectionVectorLength > subModelMinDistances[1] and objectDirectionVectorLength < pathBuildable.maxDistanceBetweenPathNodes then

                local function offsetPathSubObjectsToTerrain()
                    if nodeInfo.pathSubModelUpdatedInfos then
                        for i,subModelUpdatedInfo in ipairs(nodeInfo.pathSubModelUpdatedInfos) do
                            local maxSubModelAltitude = nil
                            for j=1,4 do
                                local rotatedOffset = vec3xMat3(pathTestOffsets[j] * buildObjectScale * subModelUpdatedInfo.scale * 0.3, mat3Inverse(rotation * subModelUpdatedInfo.rotation))
                                local finalPosition = subModelUpdatedInfo.pos + rotatedOffset
                                local terrainAltitudeResult = world:getMainThreadTerrainAltitude(finalPosition)
                                if terrainAltitudeResult.hasHit then
                                    if ((not maxSubModelAltitude) or terrainAltitudeResult.terrainAltitude > maxSubModelAltitude) then
                                        maxSubModelAltitude = terrainAltitudeResult.terrainAltitude
                                    end
                                end
                            end
                            
                    
                            if maxSubModelAltitude then
                                local subObjectPosLength = length(subModelUpdatedInfo.pos)
                                subModelUpdatedInfo.pos = (subModelUpdatedInfo.pos / subObjectPosLength) * (maxSubModelAltitude + 1.0)
                            end
                        end
                    end
                end

                local distanceFraction = (objectDirectionVectorLength - subModelMinDistances[1]) / (pathBuildable.maxDistanceBetweenPathNodes - subModelMinDistances[1])
                local midPointA = mix(snapObjectPos, nodePos, 0.5 + 0.25 * distanceFraction)
                local directionNormal = objectDirectionVector / objectDirectionVectorLength
                local rightVector = normalize(cross(nodePosNormal, directionNormal))

                local directionMultiplier = 1.0
                if rng:boolForSeed(923) then
                    directionMultiplier = -1.0
                end

                if not nodeInfo.pathSubModelUpdatedInfos then
                    nodeInfo.pathSubModelUpdatedInfos = {}
                end

                table.insert(nodeInfo.pathSubModelUpdatedInfos, {
                    pos = midPointA - rightVector * subModelRightOffset * (1.2 - 0.6 * distanceFraction) * directionMultiplier,
                    scale = 1.0,
                    rotation = mat3Rotate(mat3Identity, rng:valueForSeed(279) * math.pi * 2.0, vec3(0.0,1.0,0.)),
                })
                

                if objectDirectionVectorLength > subModelMinDistances[2] then
                    local distanceFractionB = (objectDirectionVectorLength - subModelMinDistances[2]) / (pathBuildable.maxDistanceBetweenPathNodes - subModelMinDistances[2])
                    local midPointB = mix(snapObjectPos, nodePos, 0.5 - 0.2 * distanceFractionB)
                    table.insert(nodeInfo.pathSubModelUpdatedInfos, {
                        pos = midPointB + rightVector * subModelRightOffset * (1.0 - 0.4 * distanceFractionB) * directionMultiplier,
                        scale = 1.1,
                        rotation = mat3Rotate(mat3Identity, rng:valueForSeed(346) * math.pi * 2.0, vec3(0.0,1.0,0.)),
                    })
                    if objectDirectionVectorLength > subModelMinDistances[3] then
                        local distanceFractionC = (objectDirectionVectorLength - subModelMinDistances[3]) / (pathBuildable.maxDistanceBetweenPathNodes - subModelMinDistances[3])
                        local midPointC = mix(snapObjectPos, nodePos, 0.3 + 0.12 * distanceFractionC)
                        table.insert(nodeInfo.pathSubModelUpdatedInfos, {
                            pos = midPointC - rightVector * subModelRightOffset * (1.2 - 0.4 * distanceFractionC) * directionMultiplier,
                            scale = 1.3,
                            rotation = mat3Rotate(mat3Identity, rng:valueForSeed(791) * math.pi * 2.0, vec3(0.0,1.0,0.)),
                        })
                        if objectDirectionVectorLength > subModelMinDistances[4] then
                            --local distanceFractionD = (objectDirectionVectorLength - subModelMinDistances[4]) / (addSubModelsMaxDistance - subModelMinDistances[4])
                            local midPointD = mix(snapObjectPos, nodePos, 0.6)-- + 0.2 * distanceFractionD)
                            table.insert(nodeInfo.pathSubModelUpdatedInfos, {
                                pos = midPointD + rightVector * subModelRightOffset * 0.7 * directionMultiplier,
                                scale = 1.25,
                                rotation = mat3Rotate(mat3Identity, rng:valueForSeed(3454) * math.pi * 2.0, vec3(0.0,1.0,0.)),
                            })
                        end
                    end
                end

                offsetPathSubObjectsToTerrain()
            end
        end

        local hasHitInitialNode = false
        if potentialSnapablesResult.hasHitObject then
            
            for i,snapObject in ipairs(potentialSnapablesResult.objectHits) do

                local nodeNormal = normalize(pathNodes[1].pos)
                local objectNormal = normalize(snapObject.pos)
                local objectDirectionVector = nodeNormal - objectNormal
                local objectDirectionVectorLength2 = length2(objectDirectionVector)

                if objectDirectionVectorLength2 < addSubModelsMaxDistance2 then

                    --[[if length2(pathStringInitialNodePos - snapObject.pos) < mj:mtoP(1.0) * mj:mtoP(1.0) then
                        hasHitInitialNode = true
                    end]]

                   --local randomSeed = snapObject.uniqueID
                    local snapNodePos = snapObject.pos

                    addConnectingSubModels(pathNodes[1], snapNodePos, pathNodes[1].pos, nodeNormal, objectDirectionVector, math.sqrt(objectDirectionVectorLength2), snapObject.uniqueID)
                end
            end
        end

        if (not hasHitInitialNode) and pathStringInitialNodePos then
            local finalNodeNormal = normalize(pathNodes[1].pos)
            local initialNodeNormal = normalize(pathStringInitialNodePos)
            local distanceToInitialNode = length(initialNodeNormal - finalNodeNormal)
            if distanceToInitialNode > pathBuildable.maxDistanceBetweenPathNodes then
                local extraNodeCount = math.floor(distanceToInitialNode / pathBuildable.maxDistanceBetweenPathNodes)
                if extraNodeCount < maxPathExtraNodes then
                    local distanceBetweenNodes = distanceToInitialNode / (extraNodeCount + 1)
                    local directionToInitialNode = (initialNodeNormal - finalNodeNormal) / distanceToInitialNode
                    for i = 1,extraNodeCount do
                        local nodePosition = pathNodes[1].pos + directionToInitialNode * distanceBetweenNodes * i
                        
                        local nodeIndex = i + 1
                        pathNodes[nodeIndex] = {
                            pos = nodePosition,
                            rotation = rotation,
                            decalBlockers = nil
                        }

                        offsetPathNodeToTerrain(pathNodes[nodeIndex])

                        --mj:log("addConnectingSubModels:", nodeIndex)
                        addConnectingSubModels(pathNodes[nodeIndex], pathNodes[nodeIndex - 1].pos, nodePosition, normalize(nodePosition), directionToInitialNode, distanceBetweenNodes, nil)
                    end

                    local finalNodeIndex = #pathNodes
                   -- mj:log(" finalNodeIndex addConnectingSubModels:", finalNodeIndex)
                    addConnectingSubModels(pathNodes[finalNodeIndex], pathStringInitialNodePos, pathNodes[finalNodeIndex].pos, normalize(pathNodes[finalNodeIndex].pos), directionToInitialNode, distanceBetweenNodes, nil)
                end
            end
        end

        --mj:log("potentialSnapablesResult:", potentialSnapablesResult)
    end

    local hasVerifiedAttachesAndNoCollision = false

    --local countsA = 0
   -- local countsB = 0
   -- local countsC = 0

   local snapColisionObjectIdsSet = {}

    if not finalPositionMode then
        local maleSnapPoints = constructableType.maleSnapPoints
        if (not zAxisAndDisableSnapModifierDown) and (not rightMouseIsDown) and (not middleMouseIsDown) and maleSnapPoints then

            --local closestPos = nil
            --local closestRotation = nil
            --local bestHeuristic = -999

            local results = {}
            local resultIDsSet = {}

            local cachedMaleInfos = {}


            local function testSnapObject(uniqueID, snapObjectTypeIndex, snapObjectPos, snapObjectRotation, snapObjectScale)
                if resultIDsSet[uniqueID] then
                    return false
                else
                    resultIDsSet[uniqueID] = true
                end
                --mj:log("testSnapObject:", uniqueID, "world normal:", normalize(snapObjectPos), " snapObjectRotation:", snapObjectRotation)
                local femaleSnapPoints = gameObject.types[snapObjectTypeIndex].femaleSnapPoints
                if femaleSnapPoints then
                    local allowedMaleSnapGroupSet = femaleSnapPoints.allowedMaleSnapGroupSet
                    local found = false
                    for maleSnapGroup,tf in pairs(maleSnapPoints.maleSnapGroupSet) do
                        if allowedMaleSnapGroupSet[maleSnapGroup] then
                            found = true
                            break
                        end
                    end
                    if not found then
                        return false
                    end
                    --mj:log("femaleSnapPoints:", #femaleSnapPoints, " object type:", gameObject.types[snapObjectTypeIndex].name)
                    --countsA = countsA + #femaleSnapPoints
                    for i,snapPoint in ipairs(femaleSnapPoints) do

                        local femaleSnapPointWorldSpace = nil
                        local femaleMatrixWorldSpace = nil
                        
                        local function setupFemale()
                            if not femaleSnapPointWorldSpace then
                                --countsB = countsB + 1
                                local snapOffset = vec3xMat3(snapPoint.point, mat3Inverse(snapObjectRotation))
                                snapOffset = snapOffset * mj:mToP(snapObjectScale or 1.0)
                                femaleSnapPointWorldSpace = snapObjectPos + snapOffset

                                if snapPoint.matrix then
                                    femaleMatrixWorldSpace = (snapObjectRotation * snapPoint.matrix)
                                else
                                    local femaleNormalWorldSpace = vec3xMat3(snapPoint.normal, mat3Inverse(snapObjectRotation))
                                    --mj:log("femaleNormalWorldSpace:", femaleNormalWorldSpace, " snapPoint.normal:", snapPoint.normal, " mat3GetRow(snapObjectRotation, 1):", mat3GetRow(snapObjectRotation, 1))

                                    local snapRotationUpVec = mat3GetRow(snapObjectRotation, 1)
                                    if approxEqualEpsilon(math.abs(femaleNormalWorldSpace.y), math.abs(snapRotationUpVec.y), 0.001) then
                                        snapRotationUpVec = mat3GetRow(snapObjectRotation, 2)
                                        femaleMatrixWorldSpace = mat3LookAtInverse(femaleNormalWorldSpace, snapRotationUpVec)
                                       -- mj:log("female matrix up A:", mat3GetRow(femaleMatrixWorldSpace, 1))
                                    else
                                        femaleMatrixWorldSpace = mat3LookAtInverse(femaleNormalWorldSpace, snapRotationUpVec)
                                        --mj:log("female matrix up B:", mat3GetRow(femaleMatrixWorldSpace, 1))
                                    end
                                end
                            end
                        end
                        
                        
                        for m,thisMaleSnapPoint in ipairs(maleSnapPoints) do
                            if snapPoint.allowedMaleSnapGroupSet[thisMaleSnapPoint.snapGroup] then
                                --countsC = countsC + 1
                                setupFemale()

                                local cachedMaleInfo = cachedMaleInfos[m]
                                if not cachedMaleInfo then
                                    local objectSpaceRotationUpVec = vec3(0.0,1.0,0.0)
                                    if approxEqual(math.abs(thisMaleSnapPoint.normal.y), 1.0) then
                                        objectSpaceRotationUpVec = vec3(0.0,0.0,1.0)
                                    end
                                    cachedMaleInfo = {
                                        objectSpaceRotation = mat3Inverse(mat3LookAtInverse(-thisMaleSnapPoint.normal, objectSpaceRotationUpVec))
                                    }
                                    cachedMaleInfos[m] = cachedMaleInfo
                                    --mj:log("cachedMaleInfos matrix up:", mat3GetRow(cachedMaleInfo.objectSpaceRotation, 1))
                                end
                                

                                local snappedBuildObjectRotation = femaleMatrixWorldSpace * cachedMaleInfo.objectSpaceRotation
                                local snappedBuildObjectRotationInverse = mat3Inverse(snappedBuildObjectRotation)
                                local dpA = dot(mat3GetRow(rotation, 0), mat3GetRow(snappedBuildObjectRotation, 0))
                                local dpB = dot(mat3GetRow(rotation, 1), mat3GetRow(snappedBuildObjectRotation, 1))
                                local dpC = dot(mat3GetRow(rotation, 2), mat3GetRow(snappedBuildObjectRotation, 2))
                                local dpHeuristic = dpA + dpB + dpC
                                local worldSpaceSnapPointRelativeToObjectCenter = vec3xMat3(thisMaleSnapPoint.point * mj:mToP(1.0), snappedBuildObjectRotationInverse)
        
                                local snappedBuildObjectPos = femaleSnapPointWorldSpace - worldSpaceSnapPointRelativeToObjectCenter

                                local heuristicPosition = femaleSnapPointWorldSpace - worldSpaceSnapPointRelativeToObjectCenter * 0.4
                                --if thisMaleSnapPoint.heuristicOffset then
                                --    heuristicPosition = heuristicPosition + vec3xMat3(thisMaleSnapPoint.heuristicOffset * mj:mToP(1.0), snappedBuildObjectRotationInverse)
                                --end


                                --translate buildPos towards the camera by thisMaleSnapPoint.point length

                                --local buildPosOffsetTowardsCamera = buildPos - world:getPointerRayDirection() * length(thisMaleSnapPoint.point * mj:mToP(1.0))

                                local positionToBuildDistance = length(heuristicPosition - buildPos)
        
                                local heuristic = (dpHeuristic - positionToBuildDistance * 999999.9) * (snapPoint.heuristicWeight or 1.0)

                               -- mj:log("heuristic:",heuristic, " rotation:", rotation, " buildPos:", buildPos)
                                
                                table.insert(results, {
                                    heuristic = heuristic,
                                    pos = snappedBuildObjectPos,
                                    rotation = snappedBuildObjectRotation,
                                })
                                --mj:log("snap rotation:", snappedBuildObjectRotation)
                            end
                        end
                    end
                else
                    return false
                end
                return true
            end


            local lookAtObject = localPlayer.retrievedLookAtObject

            if orderedUnconfirmedInfos then

                local rayStart = world:getPointerRayStart()
                local rayDirection = world:getPointerRayDirection()
                local rayEnd = rayStart + rayDirection * mj:mToP(1000.0)

                local unconfirmedLookAtResult = world:rayToModelTest(rayStart,
                rayEnd,
                orderedUnconfirmedInfos,
                "placeAttach",
                physicsSets.femaleSnap)
                if unconfirmedLookAtResult.hasHitObject then
                    for si,snapObjectInfo in ipairs(unconfirmedLookAtResult.objectHits) do

                        buildPos = snapObjectInfo.objectCollisionPoint

            if not lookAtObject then
                        local orderedUnconfirmedInfosIndex = snapObjectInfo.index
                        local orderedUnconfirmedInfo = orderedUnconfirmedInfos[orderedUnconfirmedInfosIndex]
                        --mj:log("test uncomfirmed", orderedUnconfirmedInfo.unconfirmedID, " type:", orderedUnconfirmedInfo.objectTypeIndex, orderedUnconfirmedInfo.pos, orderedUnconfirmedInfo.rotation)
                        testSnapObject(orderedUnconfirmedInfo.unconfirmedID, orderedUnconfirmedInfo.objectTypeIndex, orderedUnconfirmedInfo.pos, orderedUnconfirmedInfo.rotation, orderedUnconfirmedInfo.scale)
                        --mj:log("results:", results)
            end
                    end
                end
            end

            if lookAtObject then

              --  mj:log("test standard:", lookAtObject.uniqueID, " type:", lookAtObject.objectTypeIndex, lookAtObject.pos, lookAtObject.rotation)
                testSnapObject(lookAtObject.uniqueID, lookAtObject.objectTypeIndex, lookAtObject.pos, lookAtObject.rotation, lookAtObject.scale)
                --mj:log("results:", results)
            else

            local useMeshForWorldObjects = false
            local testTerrain = false
            local potentialSnapablesResult = world:modelTest(buildPos, rotation, 1.0, constructableType.modelIndex, "placeAttach", "placeAttach", testTerrain, useMeshForWorldObjects, physicsSets.femaleSnap)
            if potentialSnapablesResult.hasHitObject then
                --mj:log("potentialSnapablesResult.objectHits:", #potentialSnapablesResult.objectHits)
                local foundValidCount = 0
                for si,snapObject in ipairs(potentialSnapablesResult.objectHits) do
                    if testSnapObject(snapObject.uniqueID, snapObject.objectTypeIndex, snapObject.pos, snapObject.rotation, snapObject.scale) then
                        foundValidCount = foundValidCount + 1
                    end

                    if foundValidCount == 4 then --optimization. world:modelTest returns closest objects first. If we find a couple to potentially snap to, that will do.
                        break
                    end
                end
            end
        end

            if orderedUnconfirmedInfos then

                local unconfirmedPotentialSnapablesResult = world:modelToModelTest({
                    modelIndex = constructableType.modelIndex,
                    pos = buildPos,
                    rotation = rotation,
                    scale = 1.0
                }, 
                orderedUnconfirmedInfos,
                "placeAttach",
                "placeAttach",
                physicsSets.femaleSnap)
                
                if unconfirmedPotentialSnapablesResult.hasHitObject then
                    for si,snapObjectInfo in ipairs(unconfirmedPotentialSnapablesResult.objectHits) do
                        local orderedUnconfirmedInfosIndex = snapObjectInfo.index
                        local orderedUnconfirmedInfo = orderedUnconfirmedInfos[orderedUnconfirmedInfosIndex]
                        testSnapObject(orderedUnconfirmedInfo.unconfirmedID, orderedUnconfirmedInfo.objectTypeIndex, orderedUnconfirmedInfo.pos, orderedUnconfirmedInfo.rotation, orderedUnconfirmedInfo.scale)
                    end
                end
            end


            local function sortByHeuristic(a,b)
                return a.heuristic > b.heuristic
            end

           -- mj:log("countsA:", countsA, " countsB:", countsB, " countsC:", countsC)

            if results and results[1] then
                table.sort(results, sortByHeuristic)
                
                world:startMultiModelTest(buildPos, 1.0, constructableType.modelIndex, "placeCollide", testTerrain, useMeshForWorldObjects, nil, orderedUnconfirmedInfos)
                local foundCollisionFreeResult = false
                --mj:log("results count:", #results)
                for i,result in ipairs(results) do
                    if i > 32 then --optimization
                        break
                    end

                    --mj:log("a")
                    
                    local posToUse = result.pos
                    local terrainAltitudeResult = world:getMainThreadTerrainAltitude(posToUse)
                    if terrainAltitudeResult.hasHit then

                        if constructableType.snapToWalkableHeight then
                            --mj:log("b")
                            local buildPosLength = length(posToUse)
                            local buildPosAltitude = buildPosLength - 1.0
                            local buildPosNormal = posToUse / buildPosLength
                            if buildPosAltitude < terrainAltitudeResult.terrainAltitude then-- - mj:mToP(0.2) then --this causes issues with snapping storage areas on uneven terrain. If required, can offset in next block.
                                posToUse = buildPosNormal * (terrainAltitudeResult.terrainAltitude + 1.0)
                            else
                                local rayStart = posToUse + buildPosNormal * mj:mToP(0.1)
                                local rayEnd = posToUse - buildPosNormal * mj:mToP(1.1)
                                local rayResult = world:rayTest(rayStart, rayEnd, nil, physicsSets.walkableOrInProgressWalkable, false)
                                if rayResult.hasHitTerrain or rayResult.hasHitObject then
                                    if rayResult.hasHitObject then
                                        posToUse = rayResult.objectCollisionPoint
                                    else
                                        posToUse = rayResult.terrainCollisionPoint
                                    end
                                else
                                    posToUse = nil
                                end
                            end
                        else
                            local buildPosLength = length(posToUse)
                            local buildPosAltitude = buildPosLength - 1.0
                            if buildPosAltitude < terrainAltitudeResult.terrainAltitude - maxBuildDepthBelowTerrain then
                                posToUse = nil
                            end
                        end
                        
                        if posToUse then
                            local collidersTestResult = world:multiModelTest(posToUse, result.rotation, "placeCollide")
                            local minDistance = mj:mToP(0.01) * mj:mToP(0.01)

                            local rejectedDueToCollison = collidersTestResult.hasHitObject
                            if not rejectedDueToCollison then
                                foundCollisionFreeResult = true
                            end

                            if rejectedDueToCollison and (not constructableType.checkObjectCollisions) then
                                rejectedDueToCollison = false
                                for j,collideObject in ipairs(collidersTestResult.objectHits) do
                                    
                                    local disallowAnyCollisionsOnPlacement = false
                                    local comparePos = collideObject.pos
                                    if collideObject.objectTypeIndex then
                                        disallowAnyCollisionsOnPlacement = gameObject.types[collideObject.objectTypeIndex].disallowAnyCollisionsOnPlacement
                                    else --this must be an unconfimerd info, lets assume it's the same as the build object type
                                        disallowAnyCollisionsOnPlacement = constructableType.checkObjectCollisions
                                        comparePos = orderedUnconfirmedInfos[collideObject.index] and orderedUnconfirmedInfos[collideObject.index].pos
                                    end
                                    
                                    if disallowAnyCollisionsOnPlacement or (comparePos and length2(comparePos - posToUse) < minDistance) then
                                        rejectedDueToCollison = true
                                        break
                                    end
                                end
                            end

                            if (not rejectedDueToCollison) then
                                if foundCollisionFreeResult or adjustmentModifierDown then
                                    buildPos = posToUse
                                    rotation = result.rotation
                                    hasVerifiedAttachesAndNoCollision = true
                                    break
                                elseif not hasVerifiedAttachesAndNoCollision then
                                    buildPos = posToUse
                                    rotation = result.rotation
                                    hasVerifiedAttachesAndNoCollision = true
                                end
                            else
                                for j,collideObject in ipairs(collidersTestResult.objectHits) do
                                    snapColisionObjectIdsSet[collideObject.uniqueID] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    local subTitleWarningText = nil
    local subTitleInfoText = nil

    ----- WARNING! the server has another code path for checking of this stuff. ------
    ------ If you add something that rejects the buid here, it should also be added to the server path -----

    
    if canBuild then
        if constructableType.requiresSlopeCheck then
            local slopeOK = world:doSlopeCheckForBuildModel(buildPos, rotation, 1.0, constructableType.modelIndex, physicsSets.attachable)
            if not slopeOK then
                canBuild = false
                subTitleWarningText = locale:get("ui_buildMode_fail_tooSteep")
                --mj:log("cant build A")
            end
        end
    end

    if canBuild then
        local minSeaLength2 = buildable.minSeaLevelPosLengthDefault2
        if constructableType.noBuildUnderWater then
            minSeaLength2 = buildable.minSeaLevelPosLengthNoUnderwater2
        end
        if length2(buildPos) < minSeaLength2 then
            canBuild = false
            subTitleWarningText = locale:get("ui_buildMode_fail_underwater")
        end
    end

    attachedToTerrain = nil

    if canBuild then
        if constructableType.requiredMediumTypes then

            local buildPosNormal = normalize(buildPos)
            local rayTestStartPos = buildPos + buildPosNormal * mj:mToP(0.1)
            local rayTestEndPos = rayTestStartPos - buildPosNormal * mj:mToP(0.2)

            local forwardRayTestResult = world:rayTest(rayTestStartPos, rayTestEndPos, "growMedium", nil, false)
            if forwardRayTestResult.hasHitTerrain or forwardRayTestResult.hasHitObject then
                if forwardRayTestResult.hasHitTerrain then
                    if forwardRayTestResult.minLevel == mj.SUBDIVISIONS -1 then
                        --mj:log("forwardRayTestResult:", forwardRayTestResult)
                        local terrainBaseType = forwardRayTestResult.baseType
                        if not constructableType.requiredMediumTypes[terrainBaseType] then
                            canBuild = false
                            subTitleWarningText = locale:get("ui_buildMode_plantFail_badMedium", { terrainName = terrainTypes.baseTypes[terrainBaseType].name})
                        else
                            attachedToTerrain = true
                            subTitleInfoText = terrainTypes.baseTypes[terrainBaseType].name
                        end
                    else
                        canBuild = false
                        subTitleWarningText = locale:get("ui_buildMode_plantFail_tooDistant")
                    end
                else
                    canBuild = false --could test for planter boxes here somehow
                    subTitleWarningText = locale:get("ui_buildMode_plantFail_notTerrain")
                end
            else
                canBuild = false
                subTitleWarningText = locale:get("ui_buildMode_plantFail_notTerrain")
            end
            
        elseif  constructableType.isPathType then
            attachedToTerrain = true
        else
            if not hasVerifiedAttachesAndNoCollision then
                local useMeshForWorldObjects = false
                local testTerrain = true
                local attachablesTestResult = world:modelTest(buildPos, rotation, 1.0, constructableType.modelIndex, "placeAttach", "placeAttach", testTerrain, useMeshForWorldObjects, physicsSets.attachable)
                if (not attachablesTestResult.hasHitTerrain) and not (attachablesTestResult.hasHitObject) then
                    --mj:log("cant build B")
                    canBuild = false
                    subTitleWarningText = locale:get("ui_buildMode_fail_needsAttachment")
                else
                    attachedToTerrain = attachablesTestResult.hasHitTerrain or nil
                end
            end
        end

        --[[if canBuild and (not constructableType.checkObjectCollisions) then
            hasVerifiedAttachesAndNoCollision = true
        end]]
        
        if canBuild and (not hasVerifiedAttachesAndNoCollision) then
            local useMeshForWorldObjects = false
            local testTerrain = false

            local physicsTestSet = physicsSets.disallowAnyCollisionsOnPlacement
            if constructableType.checkObjectCollisions then
                physicsTestSet = nil --test all objects if we don't allow collisons, otherwise we can limit it just to other objects that don't allow collisions
            end
            --[[local placeGameObjectType = gameObject.types[constructableType.finalGameObjectTypeKey]
            if not placeGameObjectType.disallowAnyCollisionsOnPlacement then
                physicsTestSet = physicsSets.disallowAnyCollisionsOnPlacement
            end]]

            --mj:log("test physicsTestSet:", physicsTestSet, " constructableType.modelIndex:", constructableType.modelIndex)
            local collidersTestResult = world:modelTest(buildPos, rotation, 1.0, constructableType.modelIndex, "placeCollide", "placeCollide", testTerrain, useMeshForWorldObjects, physicsTestSet)
            --mj:log("collidersTestResult:", collidersTestResult)
            if collidersTestResult.hasHitObject then
                local hitObjectIDs = nil
                for i,collideObject in ipairs(collidersTestResult.objectHits) do
                    --mj:log("cant build B")
                    if not hitObjectIDs then
                        canBuild = false
                        subTitleWarningText = locale:get("ui_buildMode_fail_collidesWithObjects")
                        hitObjectIDs = {}
                    end
                    table.insert(hitObjectIDs, collideObject.uniqueID)
                    setWarningObjectIDs(hitObjectIDs, 0.5)
                end
            else
                local terrainAltitudeResult = world:getMainThreadTerrainAltitude(buildPos)
                if terrainAltitudeResult.hasHit then
                    local buildPosLength = length(buildPos)
                    local buildPosAltitude = buildPosLength - 1.0
                    if buildPosAltitude > terrainAltitudeResult.terrainAltitude - maxBuildDepthBelowTerrain then
                        hasVerifiedAttachesAndNoCollision = true
                    end
                end
                if not hasVerifiedAttachesAndNoCollision then
                    canBuild = false
                    subTitleWarningText = locale:get("ui_buildMode_fail_belowTerrain")
                end
            end

            if canBuild and orderedUnconfirmedInfos then
                local unconfirmedCollidersResult = world:modelToModelTest({
                    modelIndex = constructableType.modelIndex,
                    pos = buildPos,
                    rotation = rotation,
                    scale = 1.0
                }, 
                orderedUnconfirmedInfos,
                "placeCollide",
                "placeCollide",
                physicsTestSet)
                
                if unconfirmedCollidersResult.hasHitObject then
                    canBuild = false
                    subTitleWarningText = locale:get("ui_buildMode_fail_collidesWithObjects")
                end
            end
        end

        if hasVerifiedAttachesAndNoCollision then
            if next(snapColisionObjectIdsSet) then
                local snapCollisionArray = {}
                for k,v in pairs(snapColisionObjectIdsSet) do
                    table.insert(snapCollisionArray, k)
                end
                setWarningObjectIDs(snapCollisionArray, 1.0)
            else
                clearWarningObjectIDs()
            end
        end
        
    else
        clearWarningObjectIDs()
    end

    if subTitleWarningText then
        updateSubtitle(subTitleWarningText, material:getUIColor(material.types.warning.index))
    elseif subTitleInfoText then
        updateSubtitle(subTitleInfoText, mj.textColor)
    else
        updateSubtitle(nil)
    end

    
    --mj:log("finalize canBuild:", canBuild, " buildPos:", buildPos)
    finalize(buildPos, rotation, canBuild)
end

function buildModeInteractUI:removeBuildObjects()
    if buildObjectInfo ~= nil then
        uiObjectManager:removeUIModel(buildObjectInfo.modelID)

        if buildObjectInfo.subModelIDs then
            for subID,info in pairs(buildObjectInfo.subModelIDs) do
                uiObjectManager:removeUIModel(subID)
            end
        end
        buildObjectInfo = nil
            
        if pathSubModelInfosByNode then
            for j,pathSubModelInfos in pairs(pathSubModelInfosByNode) do
                for i,info in ipairs(pathSubModelInfos) do
                    uiObjectManager:removeUIModel(info.subObjectID)
                end
            end
            pathSubModelInfosByNode = nil
        end
        
        if pathMainNodeSubModelInfosByNode then
            for j,subModelInfos in pairs(pathMainNodeSubModelInfosByNode) do
                for i, subModelInfo in ipairs(subModelInfos) do
                    uiObjectManager:removeUIModel(subModelInfo.modelID)
                end
            end
            pathMainNodeSubModelInfosByNode = nil
        end

    end
end

function buildModeInteractUI:updateAnimatingObjects(dt) --todo call this

end

function buildModeInteractUI:show(constructableTypeIndex_, useRandomVariation_, isDupeBuild_)

    
    worldUIViewManager:setAllHiddenExceptGroup(worldUIViewManager.groups.buildUI)

    expireUncomfirmed(true)

    --mj:log("buildModeInteractUI:show:", constructableTypeIndex)

    constructableTypeIndex = constructableTypeIndex_
    isDupeBuild = isDupeBuild_
    randomVariationBaseConstructableTypeIndex = constructableTypeIndex
    useRandomVariation = useRandomVariation_
    rotationBaseFromInitialCick = nil
    buildObjectBaseLookAtPos = nil
    
    if useRandomVariation then
        assignRandomVariation()
    end
    finalPositionMode = false
    local constructableType = constructable.types[constructableTypeIndex]
    
    showTitle(constructableType)
    updateBuildDisplay()
    pathStringInitialNodePos = nil
    rightMouseIsDown = false
    leftMouseIsDown = false
    middleMouseIsDown = false
    mouseExtraPosOffsets = vec3(0.0,0.0,0.0)
    mouseExtraRotation = mat3Identity
    objectExtraRotationDueToKeysOrDupe = mat3Identity
    setRandomInitialRotation(constructableType)
    if not isDupeBuild then
        local resourceTypeIndex = constructableType.placeResourceTypeIndex
        if resourceTypeIndex then
            local storageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex)
            local storageBox = storage.types[storageTypeIndex].storageBox
            if storageBox then
                local placeObjectRotation = storageBox.placeObjectRotation
                if placeObjectRotation then
                    objectExtraRotationDueToKeysOrDupe = placeObjectRotation
                end

                local placeObjectOffset = storageBox.placeObjectOffset
                if placeObjectOffset then
                    mouseExtraPosOffsets = placeObjectOffset
                end
            end
        end
        --placeObjectRotation = mat3Rotate(mat3Identity, math.pi * 0.5, vec3(0.0,0.0,1.0)),
        --placeObjectOffset = vec3(0.0,1.0,0.0)
    end
    zAxisAndDisableSnapModifierDown = false
    adjustmentModifierDown = false
    noBuildOrderModifierDown = false
    --isDupeBuild = false
    gameUI:updateUIHidden()

    local tipsTypeIndex = contextualTipUI.types.buildContext.index
    if gameUI:pointAndClickModeEnabled() then
        tipsTypeIndex = contextualTipUI.types.buildContext_pointAndClickMode.index
    end
    contextualTipUI:show(tipsTypeIndex)
end

function buildModeInteractUI:pointAndClickModeWasToggled()
    if not buildModeInteractUI:hidden() then
        local tipsTypeIndex = contextualTipUI.types.buildContext.index
        if gameUI:pointAndClickModeEnabled() then
            tipsTypeIndex = contextualTipUI.types.buildContext_pointAndClickMode.index
        end
        contextualTipUI:show(tipsTypeIndex)
    end
end

function buildModeInteractUI:showForDuplication(objectInfo)
    local constructableTypeIndexToUse = constructable:getConstructableTypeIndexForCloneOrRebuild(objectInfo)

    if constructableTypeIndexToUse then
        local sharedState = objectInfo.sharedState
        dupeBuildRestrictedResourceObjectTypes = nil
        if sharedState then
            dupeBuildRestrictedResourceObjectTypes = sharedState.restrictedResourceObjectTypes
        end

        if not dupeBuildRestrictedResourceObjectTypes then
            local restrictToOnlyObjectTypeIndex = nil
            local baseObjectType = gameObject.types[objectInfo.objectTypeIndex]
            if baseObjectType.placeBaseObjectTypeIndex then
                restrictToOnlyObjectTypeIndex = baseObjectType.placeBaseObjectTypeIndex
            else
                if baseObjectType.resourceTypeIndex then
                    restrictToOnlyObjectTypeIndex = baseObjectType.index
                end
            end

            if restrictToOnlyObjectTypeIndex then
                local resourceTypeIndex = gameObject.types[restrictToOnlyObjectTypeIndex].resourceTypeIndex
                local gameObjectsTypesForResource = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
                dupeBuildRestrictedResourceObjectTypes = {}
                for k,gameObjectTypeIndex in ipairs(gameObjectsTypesForResource) do
                    if gameObjectTypeIndex ~= restrictToOnlyObjectTypeIndex then
                        dupeBuildRestrictedResourceObjectTypes[gameObjectTypeIndex] = true
                    end
                end
            end

        end
        
        buildModeInteractUI:show(constructableTypeIndexToUse, false, true)

        local incomingRotation = objectInfo.rotation

        local lookAtPosNormal = normalize(objectInfo.pos)
        local directionNormal = normalize(normalize(world:getRealPlayerHeadPos()) - lookAtPosNormal)

        local lookAtRotation = mat3LookAtInverse(directionNormal, lookAtPosNormal)
        
        objectExtraRotationDueToKeysOrDupe = mat3Inverse(lookAtRotation) * incomingRotation
        setRandomInitialRotation(constructable.types[constructableTypeIndexToUse])
    else
        mj:error("No suitable constructableTypeIndex found in buildModeInteractUI:showForDuplication for object:", objectInfo)
    end
end

local leftMouseWasDown = false
function buildModeInteractUI:update()
    if not buildModeInteractUI:hidden() then
        updateBuildDisplay()
        if leftMouseIsDown then
            leftMouseWasDown = true
            confirmFunction(true, true)
        elseif leftMouseWasDown then
            leftMouseWasDown = false
            buildRepeatTimeAccumulation = nil
        end
    end
end

function buildModeInteractUI:hide()
    --mj:debug("buildModeInteractUI:hide")
    if topView and not topView.hidden then
        worldUIViewManager:unhideAllGroups()
        contextualTipUI:hide()
        topView.hidden = true
        gameUI:updateWarningNoticeForTopPanelWillHide()
        if not finalPositionMode then
            logicInterface:callLogicThreadFunction("hideObjectsForBuildModeEnd")
        else
            if finalPositionWorldView then
                finalPositionWorldView.view.hidden = true
                finalPositionConfirmWorldView.view.hidden = true
            end
        end
        buildModeInteractUI:removeBuildObjects()
        expireUncomfirmed(true)

        clearWarningObjectIDs()

        pathStringInitialNodePos = nil
        pathNodes = nil
        mouseDownControl = nil

        if allFinalPositionViews[1] then
            updateSelection()
            for i=1,6 do
                allFinalPositionViews[i].update = nil
            end
        end
        gameUI:updateUIHidden()
    end
end

function buildModeInteractUI:hidden()
    return (topView and topView.hidden)
end

function buildModeInteractUI:isFinalPositionMode()
    return finalPositionMode
end

function buildModeInteractUI:isDetachedForTransforming()
    return topView and not topView.hidden and (mouseDownControl ~= nil)
end


function buildModeInteractUI:cickEvent(buttonIndex)
    if buttonIndex == 0 then
        confirmFunction(true, true)
    end
end

return buildModeInteractUI