local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local approxEqualEpsilon = mjm.approxEqualEpsilon

local locale = mjrequire "common/locale"
local gameObject = mjrequire "common/gameObject"
local material = mjrequire "common/material"
local terrainTypes = mjrequire "common/terrainTypes"
local storageSettings = mjrequire "common/storageSettings"
--local modelPlaceholder = mjrequire "common/modelPlaceholder"

local playerSapiens = mjrequire "mainThread/playerSapiens"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local sapienMarkersUI = mjrequire "mainThread/ui/sapienMarkersUI"
local interestMarkersUI = mjrequire "mainThread/ui/interestMarkersUI"
local planMarkersUI = mjrequire "mainThread/ui/planMarkersUI"
local hubUIUtilities = mjrequire "mainThread/ui/hubUIUtilities"
--local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
--local uiObjectManager = mjrequire "mainThread/uiObjectManager"

local lookAtUI = {}

--local gameUI = nil
local world = nil

local titleTextView = nil
local planInfoView = nil
local containerView = nil

local desiredText = nil
local desiredObjectInfo = nil
local desiredIsTerrain = false

local currentText = nil
local currentObjectInfo = nil
local currentIsTerrain = false

local changeRequired = false

local backgroundSizeNormal = nil
local backgroundSizeDouble = nil
local desiredBackgroundSize = nil

local coveredStatus = nil
local notAllowedStatus = nil
local removeAllStatus = nil
local destroyAllStatus = nil
local extraInfoText = nil

function lookAtUI:init(gameUI_, world_, backgroundView, circleView, infoView)
    --gameUI = gameUI_
    world = world_


    containerView = View.new(infoView)
    containerView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

    local subContainerView = View.new(containerView) --we need the update function to be called on containerView even when this is hidden
    subContainerView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    
    --objectImageView.baseOffset = vec3(0,0,-circleView.size.x * 0.01)

    
    local heightMultiplier = 0.2

    backgroundSizeDouble = vec2(300, 50.0)
    backgroundSizeNormal = vec2(200, 25.0)

    desiredBackgroundSize = backgroundSizeNormal
    local backgroundScale = vec2(desiredBackgroundSize.x * 0.5, desiredBackgroundSize.y * 0.5 / heightMultiplier)
    infoView.scale3D = vec3(backgroundScale.x, backgroundScale.y, backgroundScale.x)
    infoView.size = desiredBackgroundSize

    titleTextView = TextView.new(subContainerView)
    titleTextView.font = Font(uiCommon.fontName, 16)
    titleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    titleTextView.baseOffset = vec3(38,-4,0)

    planInfoView = hubUIUtilities:createPlanInfoView(subContainerView)
    planInfoView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    planInfoView.relativeView = titleTextView
    planInfoView.hidden = true

    
   -- icon.baseOffset = vec3(0, 0, 1)

    containerView.update = function(dt)

        


        local function updateViews()
           -- mj:log("updateText from:", currentText, " to:", desiredText)
            currentText = desiredText
            currentObjectInfo = desiredObjectInfo
            currentIsTerrain = desiredIsTerrain
            changeRequired = false
            
            if currentText then
                hubUIUtilities:updatePlanInfoView(planInfoView, currentIsTerrain, currentObjectInfo, world.tribeID)
                titleTextView.text = currentText
            end
        end
        

        local function addExtraFields()
            if coveredStatus ~= nil then
                if coveredStatus then
                    local color = mjm.vec4(0.5,1.0,0.5, 1.0)
                    titleTextView:addColoredText(" - ", mj.textColor)
                    titleTextView:addColoredText(locale:get("misc_inside"), color)
                else
                    titleTextView:addColoredText(" - ", mj.textColor)
                    titleTextView:addColoredText(locale:get("misc_outside"), mj.textColor)
                end
            end

            if destroyAllStatus then
                titleTextView:addColoredText(" - ", mj.textColor)
                titleTextView:addColoredText(locale:get("misc_destroyAllItems"), material:getUIColor(material.types.ui_redBright.index))
            elseif removeAllStatus then
                titleTextView:addColoredText(" - ", mj.textColor)
                titleTextView:addColoredText(locale:get("misc_removeAllItems"), material:getUIColor(material.types.ui_yellowBright.index))
            elseif notAllowedStatus then
                titleTextView:addColoredText(" - ", mj.textColor)
                titleTextView:addColoredText(locale:get("misc_itemUseNotAllowed"), material:getUIColor(material.types.ui_redBright.index))
            end

            if extraInfoText then
                titleTextView:addColoredText(" - " .. extraInfoText, mj.textColor)
            end

            --misc_removeAllItems
        end
        
        local function updateDesiredBackgroundSize()
            desiredBackgroundSize = vec2(titleTextView.size.x + 46, backgroundSizeNormal.y)
            if not planInfoView.hidden then
                desiredBackgroundSize.y = backgroundSizeDouble.y
                desiredBackgroundSize.x = math.max(desiredBackgroundSize.x, planInfoView.size.x + 46)
            end
            if not (approxEqualEpsilon(desiredBackgroundSize.x, infoView.size.x, 2) and approxEqualEpsilon(desiredBackgroundSize.y, infoView.size.y, 2)) then
                subContainerView.hidden = true
            end
        end


        if changeRequired then
            updateViews()
            addExtraFields()
            updateDesiredBackgroundSize()
        end
        

        if not (approxEqualEpsilon(desiredBackgroundSize.x, infoView.size.x, 2) and approxEqualEpsilon(desiredBackgroundSize.y, infoView.size.y, 2)) then
            infoView.size = infoView.size + (desiredBackgroundSize - infoView.size) * math.min(dt * 20.0, 1.0)
            local newBackgroundScale = vec2(infoView.size.x * 0.5, infoView.size.y * 0.5 / heightMultiplier)
            infoView.scale3D = vec3(newBackgroundScale.x, newBackgroundScale.y, infoView.scale3D.z)
        else
            subContainerView.hidden = false
        end
    end
end


local function updateInfo(title, retrievedObjectInfo, isTerrain)
    --mj:log("lookAtUI:updateInfo:", title, " info:", retrievedObjectInfo, " current:", currentText)

    desiredText = title
    desiredObjectInfo = retrievedObjectInfo
    desiredIsTerrain = isTerrain

    --[[if retrievedObjectInfo then
        if retrievedObjectInfo.objectTypeIndex == gameObject.types.temporaryCraftArea.index then
            local temporaryCraftAreaOriginalObjectInfo = retrievedObjectInfo.sharedState.temporaryCraftAreaOriginalObjectInfo
            if temporaryCraftAreaOriginalObjectInfo then
                local originalObjectTypeIndex = temporaryCraftAreaOriginalObjectInfo.objectTypeIndex
                if originalObjectTypeIndex then
                    desiredObjectInfo.displayedObjectTypeIndex = originalObjectTypeIndex
                    desiredText = gameObject:getDisplayName(temporaryCraftAreaOriginalObjectInfo)
                end
            end
        end
    end]]

    local function planStatesEqual(planStatesA, planStatesB)
        if ((planStatesA == nil) ~= (planStatesB == nil)) then
            return false
        end

        local planStatesForTribeA = planStatesA[world.tribeID]
        local planStatesForTribeB = planStatesB[world.tribeID]

        if ((planStatesForTribeA == nil) ~= (planStatesForTribeB == nil)) then
            return false
        end

        if planStatesForTribeA then
            if ((planStatesForTribeA[1] == nil) ~= (planStatesForTribeB[1] == nil)) then
                return false
            end

            local planStateA = planStatesForTribeA[1]
            local planStateB = planStatesForTribeB[1]
            if ((planStateA == nil) ~= (planStateB == nil)) then
                return false
            end

            if planStateA == nil then
                return true
            end

            if (planStateA.planTypeIndex ~= planStateB.planTypeIndex) then
                return false
            end
            
            if (planStateA.canComplete ~= planStateB.canComplete) then
                return false
            end

            if (planStateA.objectTypeIndex ~= planStateB.objectTypeIndex) then
                return false
            end

            return true
        end
    end

    
    local oldCoveredStatus = coveredStatus
    coveredStatus = nil
    local oldNotAllowedStatus = notAllowedStatus
    notAllowedStatus = nil
    local oldRemoveAllStatus = removeAllStatus
    removeAllStatus = nil
    local oldDestroyAllStatus = destroyAllStatus
    destroyAllStatus = nil
    local oldExtraInfoText = extraInfoText
    extraInfoText = nil

    if retrievedObjectInfo and retrievedObjectInfo.objectTypeIndex then
        local gameObjectType = gameObject.types[retrievedObjectInfo.objectTypeIndex]
        if gameObjectType.displayCoveredStatus then
            if retrievedObjectInfo.sharedState.covered then
                coveredStatus = true
            else
                coveredStatus = false
            end
        end



        if gameObjectType.isStorageArea then
            local storageAreaSettingsTribeID = storageSettings:getSettingsTribeIDToUse(retrievedObjectInfo.sharedState, world.tribeID, world:getServerClientState().privateShared.tribeRelationsSettings)
            if retrievedObjectInfo.sharedState.settingsByTribe[storageAreaSettingsTribeID] then
                if retrievedObjectInfo.sharedState.settingsByTribe[storageAreaSettingsTribeID].disallowItemUse then
                    notAllowedStatus = true
                end
                if retrievedObjectInfo.sharedState.settingsByTribe[storageAreaSettingsTribeID].removeAllItems then
                    removeAllStatus = true
                end
                if retrievedObjectInfo.sharedState.settingsByTribe[storageAreaSettingsTribeID].destroyAllItems then
                    destroyAllStatus = true
                end
            end
            
        end
        
        if gameObjectType.extraStatusTextFunction then
            extraInfoText = gameObjectType.extraStatusTextFunction(retrievedObjectInfo)
        end
    end

    if desiredText ~= currentText or 
    (desiredObjectInfo and not currentObjectInfo) or 
    (currentObjectInfo and not desiredObjectInfo) or 
    (desiredIsTerrain ~= currentIsTerrain) or 
    coveredStatus ~= oldCoveredStatus  or 
    notAllowedStatus ~= oldNotAllowedStatus or 
    removeAllStatus ~= oldRemoveAllStatus or 
    destroyAllStatus ~= oldDestroyAllStatus or 
    extraInfoText ~= oldExtraInfoText then
        changeRequired = true
    elseif desiredObjectInfo and currentObjectInfo then
        if desiredObjectInfo.uniqueID ~= currentObjectInfo.uniqueID then
            changeRequired = true
        else
            local function checkInaccessible(currentSharedState, desiredSharedState)
                local currentInaccessible = false
                local desiredInaccessible = false

                if currentSharedState then
                    currentInaccessible = (currentSharedState.inaccessibleCount and currentSharedState.inaccessibleCount >= 2)
                end
                if desiredSharedState then
                    desiredInaccessible = (desiredSharedState.inaccessibleCount and desiredSharedState.inaccessibleCount >= 2)
                end

                return (currentInaccessible ~= desiredInaccessible)
            end

            if desiredIsTerrain then
                if (currentObjectInfo.planObjectInfo == nil) ~= (desiredObjectInfo.planObjectInfo == nil) then
                    changeRequired = true
                elseif (currentObjectInfo.planObjectInfo and desiredObjectInfo.planObjectInfo) then 
                    local currentPlanObjectInfo = currentObjectInfo.planObjectInfo
                    local desiredPlanObjectInfo = desiredObjectInfo.planObjectInfo
                    if checkInaccessible(currentPlanObjectInfo.sharedState, desiredPlanObjectInfo.sharedState) then
                        changeRequired = true
                    else
                        if currentPlanObjectInfo.uniqueID ~= desiredPlanObjectInfo.uniqueID then
                            changeRequired = true
                        else
                            if (currentPlanObjectInfo.sharedState and desiredPlanObjectInfo.sharedState) and (currentPlanObjectInfo.sharedState.planStates or desiredPlanObjectInfo.sharedState.planStates) then 
                                if not planStatesEqual(currentPlanObjectInfo.sharedState.planStates, desiredPlanObjectInfo.sharedState.planStates) then
                                    changeRequired = true
                                end
                            end
                        end
                    end
                end
            else
                if checkInaccessible(currentObjectInfo.sharedState, desiredObjectInfo.sharedState) then
                    changeRequired = true
                else
                    if (currentObjectInfo.sharedState and desiredObjectInfo.sharedState) and (currentObjectInfo.sharedState.planStates or desiredObjectInfo.sharedState.planStates) then 
                        if not planStatesEqual(currentObjectInfo.sharedState.planStates, desiredObjectInfo.sharedState.planStates) then
                            changeRequired = true
                        end
                    end
                end
            end
        end
    end

end

function lookAtUI:show(retrievedObjectInfo, isTerrain)
    
    --mj:error("show:", retrievedObjectInfo)
    containerView.hidden = false


    local name = locale:get("misc_Unknown")

    if isTerrain then
        name = terrainTypes:getLookAtName(retrievedObjectInfo)
        planMarkersUI:setTerrainHoverMarkerByVertID(retrievedObjectInfo.uniqueID)
        sapienMarkersUI:setHoverMarker(nil)
        interestMarkersUI:setHoverMarkerID(nil)
    else

        local gameObjectType = gameObject.types[retrievedObjectInfo.objectTypeIndex]

        if gameObjectType then
            if gameObjectType.isStorageArea or
            gameObjectType.index == gameObject.types.craftArea.index then
                world:setHasLoadedCraftOrStorageArea()
            end
        end

        name = gameObject:getDisplayName(retrievedObjectInfo)

        if retrievedObjectInfo.objectTypeIndex == gameObject.types.sapien.index then
            planMarkersUI:setHoverMarker(retrievedObjectInfo.uniqueID)
            if playerSapiens:sapienIsFollower(retrievedObjectInfo.uniqueID) then
                --mj:log("retrievedObjectInfo.objectTypeIndex == gameObject.types.sapien.index")
                sapienMarkersUI:setHoverMarker(retrievedObjectInfo.uniqueID)
                interestMarkersUI:setHoverMarkerID(nil)
                --planMarkersUI:setHoverMarker(nil)
            else
                interestMarkersUI:setHoverMarkerID(retrievedObjectInfo.uniqueID)
                sapienMarkersUI:setHoverMarker(nil)
            end
        else
            planMarkersUI:setHoverMarker(retrievedObjectInfo.uniqueID)
            sapienMarkersUI:setHoverMarker(nil)
            interestMarkersUI:setHoverMarkerID(retrievedObjectInfo.uniqueID)
        end
    end

    updateInfo(name, retrievedObjectInfo, isTerrain)
end

function lookAtUI:hide()
    --mj:error("lookAtUI:hide")
    --if backgroundView then
    if not containerView.hidden then
        containerView.hidden = true
        updateInfo(nil, nil, nil)
        sapienMarkersUI:setHoverMarker(nil)
        planMarkersUI:setHoverMarker(nil)
        interestMarkersUI:setHoverMarkerID(nil)
    end
    --end
end

function lookAtUI:hidden()
    return containerView.hidden
end

return lookAtUI