local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local approxEqual = mjm.approxEqual

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local gameObject = mjrequire "common/gameObject"
local sapienConstants = mjrequire "common/sapienConstants"
local destination = mjrequire "common/destination"
--local gameConstants = mjrequire "common/gameConstants"
local locale = mjrequire "common/locale"
local resource = mjrequire "common/resource"

local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
--local audio = mjrequire "mainThread/audio"
--local clientGameSettings = mjrequire "mainThread/clientGameSettings"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"

local questUIHelper = mjrequire "mainThread/ui/questUIHelper"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"

local mainThreadDestination = nil
local localPlayer = nil
local world = nil
local gameUI = nil

local currentIsMapMode = false

local interestMarkersUI = {
}

local currentMaterialTypesByTribeID = {}

--[[local function tribeColorMaterialForFavor(favor)
    if favor > gameConstants.tribeRelationshipScoreThresholds.mildNegative then
        if favor > gameConstants.tribeRelationshipScoreThresholds.mildPositive then
            if favor > gameConstants.tribeRelationshipScoreThresholds.moderatePositive then
                return material.types.mood_severePositive.index
            end
            return material.types.mood_moderatePositive.index
        end
        return material.types.mood_mildPositive.index
    end

    if favor < gameConstants.tribeRelationshipScoreThresholds.moderateNegative then
        if favor < gameConstants.tribeRelationshipScoreThresholds.severeNegative then
            return material.types.mood_severeNegative.index
        end
        return material.types.mood_moderateNegative.index
    end
    return material.types.mood_mildNegative.index
end]]

--[[

        if markerInfo.detailInfo.ownedByLocalPlayer then
            iconMaterial = material.types.ui_selected.index
        elseif markerInfo.detailInfo.clientID then
            iconMaterial = material.types.ui_otherPlayer.index
        else
            iconMaterial = material.types.ui_bronze_lighter.index
        end
]]

interestMarkersUI.interestMarkerTypes = mj:indexed {
    {
        key = "AITribe",
        uiGroup = worldUIViewManager.groups.interestTribeMarker,
        iconNameFunction = function(posMarkerViewInfo, updateDataInfo)
            if (not updateDataInfo.population) or updateDataInfo.population == 0 then
                return "icon_failedTribeWithOutline"
            end
            return "icon_tribeWithOutline"
        end,
        mapModeTogglesDepthTest = true,
        iconMaterialIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            if updateDataInfo.clientID then
                --mj:log("updateDataInfo:", updateDataInfo)
                local materialTypeIndex = material.types.ui_selected.index
                if updateDataInfo.destinationID ~= world:getTribeID() then
                    materialTypeIndex = material.types.ui_otherPlayer.index
                end
                currentMaterialTypesByTribeID[updateDataInfo.destinationID] = materialTypeIndex

                return materialTypeIndex
            elseif updateDataInfo.relationships then
                local relationship = updateDataInfo.relationships[world:getTribeID()]
                if relationship and relationship.favor then
                    --local materialTypeIndex = tribeColorMaterialForFavor(relationship.favor)
                    --currentMaterialTypesByTribeID[updateDataInfo.destinationID] = materialTypeIndex
                    --return materialTypeIndex
                    local materialTypeIndex = material.types.ui_bronze_lighter.index
                    currentMaterialTypesByTribeID[updateDataInfo.destinationID] = materialTypeIndex
                    return materialTypeIndex
                end
            end
            return material.types.ui_standard.index
        end,
        --alpha = 0.8,

        normalSize = 0.06,
        selectedSize = 0.12,
        iconBaseOffset = vec3(0.0,0.03,0.0),

        titleTextViewYOffset = 0.75,
        titleTextScale = 0.02,
        titleTextViewRenderBackground = true,

        minDistance = mj:mToP(200.0),
        scaleStartDistance = mj:mToP(4.0),
        maxDistanceFunction = function(posMarkerViewInfo, updateDataInfo, isMapMode)
            if updateDataInfo.clientID then
                return nil
            else
                if isMapMode then
                    return mj:mToP(1000000.0)
                end
            end
            return mj:mToP(10000.0)
        end,
        useHorizonMaxDistance = true, --used only if maxDistanceFunction returns nil

        clickFunction = function(posMarkerViewInfo, updateDataInfo)
            local destinationInfo = mainThreadDestination.destinationInfosByID[updateDataInfo.destinationID]

            gameUI:teleportToLookAtPos(posMarkerViewInfo.pos)
            localPlayer:setMapMode(nil, false)

            if destinationInfo.destinationID == world.tribeID then
                gameUI:showTribeMenu()
            else
                if destinationInfo and destinationInfo.relationships and destinationInfo.relationships[world.tribeID] then
                    tribeRelationsUI:show(destinationInfo, nil, nil, nil, false)
                end
            end
        end
    },
    {
        key = "nonFollowerSapien",
        attachToObject = true,
        attachBoneName = "head",
        uiGroup = worldUIViewManager.groups.interestNonFollowerSapienMarker,
        iconName = "ui_sapienMarkerOtherTribe",
        renderXRay = true,
        iconMaterialIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            if updateDataInfo.sharedState then
                local tribeID = updateDataInfo.sharedState.tribeID
                if tribeID then
                    local materialTypeIndex = currentMaterialTypesByTribeID[tribeID]
                    if materialTypeIndex then
                        return material.types.ui_bronze_lightest.index
                    end
                end
            end
            return nil
        end,

        iconDefaultMaterialIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            if updateDataInfo.sharedState then
                local tribeID = updateDataInfo.sharedState.tribeID
                if tribeID then
                    local materialTypeIndex = currentMaterialTypesByTribeID[tribeID]
                    if materialTypeIndex then
                        return materialTypeIndex
                    end
                end
            end
            return material.types.ui_standard.index
        end,

        normalSize = 0.02,
        selectedSize = 0.04,
        iconBaseOffset = vec3(0.0,0.01,0.0),

        titleTextViewYOffset = 1.0,
        titleTextScale = 0.04,
        titleTextViewRenderBackground = true,

        minDistance = mj:mToP(0.3),
        scaleStartDistance = mj:mToP(2.0),
        maxDistance = mj:mToP(200.0),
    },
    {
        key = "tradeRequest",
        hoverOnLookAtObject = true,
        uiGroup = worldUIViewManager.groups.interestTradeRequestMarker,
        iconName = "ui_tradeRequestMarker",
        --iconDefaultMaterialIndex = material.types.ui_background_black.index,
        iconDefaultMaterialIndex = material.types.ui_bronze.index,
        --iconMaterialIndex = material.types.ui_bronze_lightest_severePositive.index,
        iconMaterialIndex = material.types.ui_bronze_lightest.index,
        --iconMaterialIndex = material.types.ui_standard.index,
        --iconMaterialIndex = material.types.ui_bronze.index,
        renderXRay = true,

        offsetInfo = {
            worldOffset = vec3(0,mj:mToP(1.0),0)
        },

        normalSize = 0.24,
        selectedSize = 0.48,
        iconBaseOffset = vec3(0.0,0.0,0.0),

        minDistance = mj:mToP(0.3),
        scaleStartDistance = mj:mToP(6.0),
        maxDistance = mj:mToP(200.0),
        maxDistanceMapMode = mj:mToP(1000000.0),

        titleTextViewYOffset = 0.0,
        titleTextScale = 0.01,
        titleTextViewRenderBackground = true,
        titleTextViewBackgroundMaterialIndex = material.types.ui_bronze.index,

        gameObjectViewBaseOffset = vec3(0.0,0.0,0.0),
        gameObjectViewScale = 0.6,
        gameObjectViewObjectTypeIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            --mj:log("updateDataInfo:", updateDataInfo)
            return updateDataInfo.objectTypeIndex or resource.types[updateDataInfo.resourceTypeIndex].displayGameObjectTypeIndex
        end,

        clickFunction = function(posMarkerViewInfo, updateDataInfo)
            --open trade panel updateDataInfo.destinationID
            --mj:log("anchorStatesByTribe:", updateDataInfo.anchorStatesByTribe)
        end
    },
    {
        key = "tradeOffer",
        hoverOnLookAtObject = true,
        uiGroup = worldUIViewManager.groups.interestTradeOfferMarker,
        iconName = "ui_tradeOfferMarker",
        --iconDefaultMaterialIndex = material.types.ui_background_black.index,
        iconDefaultMaterialIndex = material.types.ui_bronze.index,
        --iconMaterialIndex = material.types.ui_bronze_lightest_severePositive.index,
        iconMaterialIndex = material.types.ui_bronze_lightest.index,
        --iconMaterialIndex = material.types.ui_standard.index,
        --iconMaterialIndex = material.types.ui_bronze.index,
        renderXRay = true,

        offsetInfo = {
            worldOffset = vec3(0,mj:mToP(1.0),0)
        },

        normalSize = 0.24,
        selectedSize = 0.48,
        iconBaseOffset = vec3(0.0,0.0,0.0),

        minDistance = mj:mToP(0.3),
        scaleStartDistance = mj:mToP(6.0),
        maxDistance = mj:mToP(200.0),
        maxDistanceMapMode = mj:mToP(1000000.0),

        titleTextViewYOffset = 0.0,
        titleTextScale = 0.01,
        titleTextViewRenderBackground = true,
        titleTextViewBackgroundMaterialIndex = material.types.ui_bronze.index,

        gameObjectViewBaseOffset = vec3(0.0,0.0,0.0),
        gameObjectViewScale = 0.6,
        gameObjectViewObjectTypeIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            --mj:log("updateDataInfo:", updateDataInfo)
            return updateDataInfo.objectTypeIndex or resource.types[updateDataInfo.resourceTypeIndex].displayGameObjectTypeIndex
        end,

        clickFunction = function(posMarkerViewInfo, updateDataInfo)
            --open trade panel updateDataInfo.destinationID
            --mj:log("anchorStatesByTribe:", updateDataInfo.anchorStatesByTribe)
        end
    },
    {
        key = "quest",
        hoverOnLookAtObject = true,
        uiGroup = worldUIViewManager.groups.interestQuestMarker,
        iconName = "ui_questMarker",
        iconDefaultMaterialIndex = material.types.ui_bronze.index,
        --iconMaterialIndex = material.types.ui_bronze_severePositive.index,
        iconMaterialIndex = material.types.ui_bronze_lightest.index,
        renderXRay = true,

        offsetInfo = {
            worldOffset = vec3(0,mj:mToP(1.0),0)
        },

        normalSize = 0.24,
        selectedSize = 0.48,
        iconBaseOffset = vec3(0.0,0.0,0.0),

        minDistance = mj:mToP(0.3),
        scaleStartDistance = mj:mToP(6.0),
        maxDistance = mj:mToP(200.0),
        maxDistanceMapMode = mj:mToP(1000000.0),

        titleTextViewYOffset = 0.0,
        titleTextScale = 0.01,
        titleTextViewRenderBackground = true,
        titleTextViewBackgroundMaterialIndex = material.types.ui_bronze.index,

        gameObjectViewBaseOffset = vec3(0.0,0.0,0.0),
        gameObjectViewScale = 0.6,
        gameObjectViewObjectTypeIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            --mj:log("updateDataInfo:", updateDataInfo)
            return updateDataInfo.objectTypeIndex or resource.types[updateDataInfo.questState.resourceTypeIndex].displayGameObjectTypeIndex
        end,
    },
    {
        key = "debugMarker",
        uiGroup = worldUIViewManager.groups.interestDebugMarker,
        iconName = "icon_lock",
        iconMaterialIndex = material.types.ui_green.index,
        renderXRay = true,

        normalSize = 0.06,
        selectedSize = 0.12,
        iconBaseOffset = vec3(0.0,0.03,0.0),

        minDistance = mj:mToP(0.3),
        scaleStartDistance = mj:mToP(4.0),
        maxDistance = mj:mToP(10000.0),
        maxDistanceMapMode = mj:mToP(1000000.0),

        clickFunction = function(posMarkerViewInfo, updateDataInfo)
            mj:log("anchorStatesByTribe:", updateDataInfo.anchorStatesByTribe)
        end
    },
}

local posMarkerViewInfosByTypeThenID = {}



local posOffsetInfoAdult = {
    worldOffset = vec3(0,mj:mToP(0.2),0), 
    boneOffset = vec3(0,mj:mToP(0.2),0)
}

local posOffsetInfoChild = {
    worldOffset = vec3(0,mj:mToP(0.2),0), 
    boneOffset = vec3(0,mj:mToP(0.1),0)
}

local hoverMarker = nil

local function getOffsetInfo(interestMarkerTypeIndex, sharedState)
    local interestMarkerType = interestMarkersUI.interestMarkerTypes[interestMarkerTypeIndex]

    if interestMarkerType.attachBoneName then
        if (not sharedState) or (not sharedState.lifeStageIndex) then
            return {
                worldOffset = vec3(0,mj:mToP(1.0),0)
            }
        end
        if sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then
            return posOffsetInfoChild
        end
            
        return posOffsetInfoAdult
    end

    return interestMarkerType.offsetInfo or {
        worldOffset = vec3(0,mj:mToP(0.5),0)
    }
end


local function updateSizes(info)

    local interestMarkerType = interestMarkersUI.interestMarkerTypes[info.interestMarkerTypeIndex]
    local logoHalfSize = info.currentSize * 0.6
    info.icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
    info.icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0


    if interestMarkerType.useCircleHitRadius then
        info.icon:setCircleHitRadius(logoHalfSize)
    end

    info.icon.baseOffset = interestMarkerType.iconBaseOffset * (info.currentSize / info.baseSize)

    local alpha = mjm.mix(interestMarkerType.alpha or 1.0, 1.0, mjm.clamp((info.currentSize - info.baseSize) / (interestMarkerType.selectedSize - info.baseSize), 0.0, 1.0))
    info.icon.alpha = alpha

    if info.titleTextView and (not info.titleTextView.hidden) then

        local textViewSize = interestMarkerType.selectedSize

        info.titleTextView.fontGeometryScale = textViewSize * interestMarkerType.titleTextScale
        info.titleTextView.baseOffset = vec3(0,0,0.001)
        --info.titleTextView.baseOffset = vec3(0,info.currentSize * interestMarkerType.titleTextViewYOffset,0)


        info.textBackgroundView.baseOffset = vec3(0,info.currentSize + textViewSize * interestMarkerType.titleTextViewYOffset,0)

        local panelHeight = 40
        local width = math.max(80, (info.titleTextView.size.x / (textViewSize * interestMarkerType.titleTextScale)) + 20)

        if info.subTitleTextView then
            panelHeight = panelHeight + 20
            info.subTitleTextView.fontGeometryScale = textViewSize * interestMarkerType.titleTextScale
            info.titleTextView.baseOffset = vec3(0,13.0 * textViewSize * interestMarkerType.titleTextScale,0)
            info.textBackgroundView.baseOffset = vec3(0,info.currentSize + textViewSize * interestMarkerType.titleTextViewYOffset * 1.2,0)
        end
    
        --[[if descriptionTextView then
            panelHeight = 32 + descriptionTextView.size.y
            width = math.max(width, descriptionTextView.size.x + 12)
        end]]
        
        local sizeToUse = vec2(width, panelHeight) * textViewSize * interestMarkerType.titleTextScale
        info.textBackgroundView.size = sizeToUse

        local scaleToUseX = sizeToUse.x * 0.5
        local scaleToUseY = sizeToUse.y * 0.5 / 0.2
        if interestMarkerType.titleTextViewRenderBackground then
            info.textBackgroundView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
        end
        info.textBackgroundView.alpha = alpha
    end

    if info.gameObjectView then
        info.gameObjectView.baseOffset = (interestMarkerType.gameObjectViewBaseOffset or vec3(0.0,0.0,0.0)) * info.currentSize
        local gameObjectViewHalfSize = interestMarkerType.gameObjectViewScale * info.currentSize
        uiGameObjectView:setSize(info.gameObjectView, vec2(gameObjectViewHalfSize,gameObjectViewHalfSize))
    end
end

local function getTitleTexts(markerInfo, isRenderingSelectedState)

    local titleText = nil
    local subTitleText = nil
    local pluralName = (markerInfo.dataInfo.resourceTypeIndex and resource.types[markerInfo.dataInfo.resourceTypeIndex].plural) or (markerInfo.dataInfo.objectTypeIndex and gameObject.types[markerInfo.dataInfo.objectTypeIndex].plural) or "missing"
    if markerInfo.interestMarkerTypeIndex == interestMarkersUI.interestMarkerTypes.tradeRequest.index then
        --mj:log("markerInfo.dataInfo:", markerInfo.dataInfo)
        if isRenderingSelectedState then
            if markerInfo.dataInfo.deliveredCount then
                titleText = string.format("%s: %d %s - %s: %d/%d", 
                locale:get("ui_name_request"), 
                markerInfo.dataInfo.requestInfo.count,
                pluralName,
                locale:get("ui_name_delivered"),
                markerInfo.dataInfo.deliveredCount, 
                markerInfo.dataInfo.requestInfo.count)
            else
                titleText = string.format("%s: %d %s", 
                locale:get("ui_name_request"), 
                markerInfo.dataInfo.requestInfo.count,
                pluralName)
            end
        end
    elseif markerInfo.interestMarkerTypeIndex == interestMarkersUI.interestMarkerTypes.tradeOffer.index then
        if isRenderingSelectedState then
            if markerInfo.dataInfo.purchasedCount and markerInfo.dataInfo.purchasedCount > 0 then
                titleText = string.format("%s: %d %s - %s: %d", 
                locale:get("ui_name_offer"), 
                markerInfo.dataInfo.offerInfo.count,
                pluralName, 
                locale:get("ui_name_purchased"),
                markerInfo.dataInfo.purchasedCount)
            else
                titleText = string.format("%s: %d %s", 
                locale:get("ui_name_offer"), 
                markerInfo.dataInfo.offerInfo.count,
                pluralName)
            end
        end
    elseif markerInfo.interestMarkerTypeIndex == interestMarkersUI.interestMarkerTypes.quest.index then
        if isRenderingSelectedState then
            titleText = questUIHelper:getDescriptiveQuestLabelTextForQuestState(markerInfo.dataInfo.questState) .. ": " .. questUIHelper:getQuestShortSummaryText(markerInfo.dataInfo.questState, markerInfo.dataInfo.deliveredCount)
            subTitleText = questUIHelper:getTimeLeftTextForQuestState(markerInfo.dataInfo.questState)
        end
    else
        local shouldRender = isRenderingSelectedState
        if not shouldRender then 
            if markerInfo.interestMarkerTypeIndex == interestMarkersUI.interestMarkerTypes.AITribe.index then
                shouldRender = markerInfo.dataInfo and markerInfo.dataInfo.playerOnline
            end
        end

        if shouldRender then
            --mj:log("update hover")
            local tribeName = nil
            local playerName = nil
            if markerInfo.interestMarkerTypeIndex == interestMarkersUI.interestMarkerTypes.AITribe.index then
                tribeName = markerInfo.name
                playerName = markerInfo.dataInfo and markerInfo.dataInfo.playerName
                --mj:log("markerInfo:", markerInfo)
            elseif markerInfo.sharedState and markerInfo.sharedState.tribeID then
                local info = mainThreadDestination.destinationInfosByID[markerInfo.sharedState.tribeID]
                if info then
                    tribeName = info.name
                    playerName = info.playerName
                end
            end

            if tribeName then
                titleText = locale:get("misc_tribeName", {tribeName = tribeName}) 
            end

            if playerName then
                titleText = titleText .. " - " .. playerName
            end

            --[[if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu and markerInfo.uniqueID then
                if titleText then
                    titleText = titleText .. " " .. markerInfo.uniqueID
                else
                    titleText = markerInfo.uniqueID
                end
            end]]
        end
    end
    return {
        titleText = titleText,
        subTitleText = subTitleText,
    }
end

local function updateTitles(markerInfo, isRenderingSelectedState, enableDepthTest)
    local titleTexts = getTitleTexts(markerInfo, isRenderingSelectedState)

    local titleText = titleTexts.titleText
    local subTitleText = titleTexts.subTitleText

    if titleText then
        local interestMarkerType = interestMarkersUI.interestMarkerTypes[markerInfo.interestMarkerTypeIndex]
        local textBackgroundView = markerInfo.textBackgroundView
        if not textBackgroundView then
            if interestMarkerType.titleTextViewRenderBackground then
                textBackgroundView = ModelView.new(markerInfo.view)
                textBackgroundView:setModel(model:modelIndexForName("ui_panel_10x2"), {default = interestMarkerType.titleTextViewBackgroundMaterialIndex or material.types.ui_background_black.index})
            else
                textBackgroundView = View.new(markerInfo.view)
            end
            markerInfo.textBackgroundView = textBackgroundView
            textBackgroundView.masksEvents = false
        end


        local titleTextView = markerInfo.titleTextView
        if not titleTextView then
            titleTextView = TextView.new(textBackgroundView)
            markerInfo.titleTextView = titleTextView
            titleTextView.color = mj.textColor
            titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            titleTextView.font = Font(uiCommon.titleFontName, 24)
            titleTextView.fontGeometryScale = markerInfo.currentSize * interestMarkerType.titleTextScale
        end

        titleTextView.text = titleText
        
        if interestMarkerType.titleTextViewRenderBackground then
            textBackgroundView:setDepthTestEnabled(enableDepthTest)
        end
        titleTextView:setDepthTestEnabled(enableDepthTest)

        if subTitleText then
            local subTitleTextView = markerInfo.subTitleTextView
            if not subTitleTextView then
                subTitleTextView = TextView.new(textBackgroundView)
                markerInfo.subTitleTextView = subTitleTextView
                subTitleTextView.color = mj.textColor
                subTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
                subTitleTextView.relativeView = titleTextView
                subTitleTextView.font = Font(uiCommon.fontName, 18)
                subTitleTextView.fontGeometryScale = markerInfo.currentSize * interestMarkerType.titleTextScale
            end

            subTitleTextView.text = subTitleText

            if markerInfo.interestMarkerTypeIndex == interestMarkersUI.interestMarkerTypes.quest.index then
                local accumulator = 0.0
                subTitleTextView.update = function(dt)
                    accumulator = accumulator + dt
                    if accumulator >= 1.0 then
                        accumulator = accumulator - 1.0
                        if accumulator > 1.0 then
                            accumulator = 0.0
                        end

                        local newSubTitleText = questUIHelper:getTimeLeftTextForQuestState(markerInfo.dataInfo.questState) or ""
                        subTitleTextView.text = newSubTitleText
                    end
                end
            end

        end

        updateSizes(markerInfo)
    else
        if markerInfo.textBackgroundView then
            markerInfo.view:removeSubview(markerInfo.textBackgroundView)
            markerInfo.titleTextView = nil
            markerInfo.textBackgroundView = nil
            markerInfo.subTitleTextView = nil
        end
    end
end

local function updateHoverDecorations(markerInfo)
    
    if (hoverMarker and hoverMarker == markerInfo) then
        if not markerInfo.renderingSelectedState then
            markerInfo.renderingSelectedState = true

            local enableDepthTest = false
            markerInfo.view:setDepthTestEnabled(enableDepthTest)

            local interestMarkerType = interestMarkersUI.interestMarkerTypes[markerInfo.interestMarkerTypeIndex]
            markerInfo.goalSize = interestMarkerType.selectedSize
            markerInfo.worldView.drawOrder = 1 --higher drawOrder gets rendered on top, if we have disabled depth testing

            updateTitles(markerInfo, markerInfo.renderingSelectedState, enableDepthTest)
        end
    else
        if markerInfo.renderingSelectedState then
            markerInfo.renderingSelectedState = nil
            local interestMarkerType = interestMarkersUI.interestMarkerTypes[markerInfo.interestMarkerTypeIndex]
            markerInfo.worldView.drawOrder = 0 --reset drawOrder to default of 0

            markerInfo.goalSize = markerInfo.baseSize

            local enableDepthTest = true
            if interestMarkerType.mapModeTogglesDepthTest then
                enableDepthTest = not currentIsMapMode
            end
            markerInfo.view:setDepthTestEnabled(enableDepthTest)

            updateTitles(markerInfo, markerInfo.renderingSelectedState, enableDepthTest)
        
        end
    end
end


function interestMarkersUI:setHoverMarker(newHoverMarker, preventAnimation)
    if hoverMarker ~= newHoverMarker then
        local prevHoverMarker = hoverMarker
        hoverMarker = newHoverMarker
        
        if prevHoverMarker then
            updateHoverDecorations(prevHoverMarker)
        end
        if hoverMarker then
            if not preventAnimation then
                hoverMarker.view:resetAnimationTimer()
            end
            updateHoverDecorations(hoverMarker)
        end
    end
end

function interestMarkersUI:setHoverMarkerID(hoverMarkerID)
    if hoverMarkerID then
        local found = false
        for interestMarkerTypeIndex,viewInfos in pairs(posMarkerViewInfosByTypeThenID) do
            local interestMarkerType = interestMarkersUI.interestMarkerTypes[interestMarkerTypeIndex]
            if interestMarkerType.attachToObject or interestMarkerType.hoverOnLookAtObject then
                local posMarkerViewInfo = viewInfos[hoverMarkerID]
                if posMarkerViewInfo then
                    interestMarkersUI:setHoverMarker(posMarkerViewInfo, false)
                    found = true
                end
            end
        end
        if not found then
            interestMarkersUI:setHoverMarker(nil, false)
        end
    else
        interestMarkersUI:setHoverMarker(nil, false)
    end
end

function interestMarkersUI:mapModeChanged(newMapMode)
    local isMapMode = newMapMode ~= nil

    if currentIsMapMode ~= isMapMode then
        currentIsMapMode = isMapMode
        for interestMarkerTypeIndex, posMarkerViewInfosByID in pairs(posMarkerViewInfosByTypeThenID) do
            local interestMarkerType = interestMarkersUI.interestMarkerTypes[interestMarkerTypeIndex]
            if interestMarkerType.mapModeTogglesDepthTest then
                for uniqueID,markerInfo in pairs(posMarkerViewInfosByID) do
                    markerInfo.view:setDepthTestEnabled((not currentIsMapMode) and (not markerInfo.renderingSelectedState))
                end
            end
        end
    end
    
end

function interestMarkersUI:objectChanged(interestMarkerTypeIndex, uniqueID, pos, updateDataInfo)

    local function updateMaterials(interestMarkerType, posMarkerViewInfo)

        local iconMaterialIndex = interestMarkerType.iconMaterialIndex
        local defaultMaterialIndex = interestMarkerType.iconDefaultMaterialIndex
        local iconName = interestMarkerType.iconName

        if interestMarkerType.iconMaterialIndexFunction then
            iconMaterialIndex = interestMarkerType.iconMaterialIndexFunction(posMarkerViewInfo, updateDataInfo)
        end

        if interestMarkerType.iconDefaultMaterialIndexFunction then
            defaultMaterialIndex = interestMarkerType.iconDefaultMaterialIndexFunction(posMarkerViewInfo, updateDataInfo)
        end

        if interestMarkerType.iconNameFunction then
            --[[if updateDataInfo.clientID then
                mj:log("updateDataInfo:", updateDataInfo)
            end]]
            iconName = interestMarkerType.iconNameFunction(posMarkerViewInfo, updateDataInfo)
        end
        
        posMarkerViewInfo.icon:setModel(model:modelIndexForName(iconName), {
            default = defaultMaterialIndex,
            [material.types.ui_standard.index] = iconMaterialIndex
        })
    end

   -- mj:log("updateDataInfo:", updateDataInfo)
    --mj:log("interestMarkersUI:objectChanged interestMarkerTypeIndex:", interestMarkerTypeIndex)
    --mj:log("posMarkerViewInfosByTypeThenID:", posMarkerViewInfosByTypeThenID)
    local posMarkerViewInfosByID = posMarkerViewInfosByTypeThenID[interestMarkerTypeIndex]
    local posMarkerViewInfo = posMarkerViewInfosByID[uniqueID]

    local interestMarkerType = interestMarkersUI.interestMarkerTypes[interestMarkerTypeIndex]

    if not posMarkerViewInfo then

        local attachObjectUniqueID = nil
        local attachBoneName = nil
        if interestMarkerType.attachToObject then
            attachObjectUniqueID = uniqueID
            attachBoneName = interestMarkerType.attachBoneName
        end

        local useHorizonMaxDistance = interestMarkerType.useHorizonMaxDistance
        local maxDistance = interestMarkerType.maxDistance
        local maxDistancMapMode = interestMarkerType.maxDistanceMapMode
        if interestMarkerType.maxDistanceFunction then
            maxDistance = interestMarkerType.maxDistanceFunction(posMarkerViewInfo, updateDataInfo, false)
            maxDistancMapMode = interestMarkerType.maxDistanceFunction(posMarkerViewInfo, updateDataInfo, true)

            if maxDistance then
                useHorizonMaxDistance = false
            end
        end

        local worldView = worldUIViewManager:addView(pos, interestMarkerType.uiGroup, {
            startScalingDistance = interestMarkerType.scaleStartDistance, 
            offsets = {getOffsetInfo(interestMarkerTypeIndex, updateDataInfo.sharedState)}, 
            minDistance = interestMarkerType.minDistance,
            maxDistance = maxDistance,
            maxDistanceMapMode = maxDistancMapMode,
            useHorizonMaxDistance = useHorizonMaxDistance,
            attachObjectUniqueID = attachObjectUniqueID, 
            attachBoneName = attachBoneName, 
            renderXRay = interestMarkerType.renderXRay
        })
        local viewID = worldView.uniqueID
        local view = worldView.view
        view.size = vec2(interestMarkerType.normalSize,interestMarkerType.normalSize)
        view.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        
        --[[local backgroundDebug = ColorView.new(view)
        backgroundDebug.color = mjm.vec4(0.4,0.0,0.0,1.0)
        backgroundDebug.size = view.size]]

        local icon = ModelView.new(view)
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        icon.alpha = interestMarkerType.alpha or 1.0
        --[[if not interestMarkerType.renderXRay then
            icon:setDepthTestEnabled(false)
        end]]

        if interestMarkerType.mapModeTogglesDepthTest and currentIsMapMode then
            view:setDepthTestEnabled(false)
        end

        
        local iconHalfSize = interestMarkerType.normalSize * 0.5
        icon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
        icon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
        icon.baseOffset = interestMarkerType.iconBaseOffset

        --backgroundView:setUsesModelHitTest(true)

        if interestMarkerType.useCircleHitRadius then
            icon:setCircleHitRadius(iconHalfSize)
        else
            icon:setUsesModelHitTest(true)
        end



        posMarkerViewInfo = {
            viewID = viewID,
            uniqueID = uniqueID,
            worldView = worldView,
            pos = pos,
            view = view,
            icon = icon,
            hover = false,
            currentSize = interestMarkerType.normalSize * 0.8,
            goalSize = interestMarkerType.normalSize,
            baseSize = interestMarkerType.normalSize,
            differenceVelocity = 0.0,

            dataInfo = updateDataInfo,

            interestMarkerTypeIndex = interestMarkerTypeIndex,

            attachObjectUniqueID = attachObjectUniqueID,
            attachBoneName = attachBoneName,

            sharedState = updateDataInfo.sharedState,
            name = updateDataInfo.name,
        }

        updateMaterials(interestMarkerType, posMarkerViewInfo)

        local enableDepthTest = (not currentIsMapMode) and (not posMarkerViewInfo.renderingSelectedState)
        posMarkerViewInfo.view:setDepthTestEnabled(enableDepthTest)
        updateTitles(posMarkerViewInfo, posMarkerViewInfo.renderingSelectedState, enableDepthTest)

        --[[

        gameObjectViewBaseOffset = vec3(0.0,0.06,0.0),
        gameObjectViewScale = 0.03,
        gameObjectViewObjectTypeIndexFunction = function(posMarkerViewInfo, updateDataInfo)
            return 
        ]]
        if interestMarkerType.gameObjectViewObjectTypeIndexFunction then

            local gameObjectView = uiGameObjectView:create(view, vec2(128,128), uiGameObjectView.types.standard)
            gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            gameObjectView.baseOffset = (interestMarkerType.gameObjectViewBaseOffset or vec3(0.0,0.0,0.0)) * posMarkerViewInfo.currentSize
            gameObjectView.masksEvents = false
            local logoHalfSize = interestMarkerType.gameObjectViewScale * posMarkerViewInfo.currentSize
            uiGameObjectView:setSize(gameObjectView, vec2(logoHalfSize,logoHalfSize))
            posMarkerViewInfo.gameObjectView = gameObjectView
                
            local objectInfo = {
                objectTypeIndex = interestMarkerType.gameObjectViewObjectTypeIndexFunction(posMarkerViewInfo, updateDataInfo)
            }

            uiGameObjectView:setObject(gameObjectView, objectInfo, nil, nil)
        end

        posMarkerViewInfosByID[uniqueID] = posMarkerViewInfo


        icon.hoverStart = function ()
            if interestMarkerType.attachToObject or interestMarkerType.hoverOnLookAtObject then
                localPlayer:markerLookAtStarted(uniqueID, worldView.pos, nil)
            else
                interestMarkersUI:setHoverMarker(posMarkerViewInfo, false)
            end
        end
        icon.hoverEnd = function ()
            --if (hoverMarker and hoverMarker.uniqueID == uniqueID) then
                if interestMarkerType.attachToObject or interestMarkerType.hoverOnLookAtObject then
                    localPlayer:markerLookAtEnded(uniqueID)
                elseif posMarkerViewInfo == hoverMarker then
                    interestMarkersUI:setHoverMarker(nil, false)
                end
            --end
        end
        icon.click = function (mouseLoc)
            if interestMarkerType.attachToObject or interestMarkerType.hoverOnLookAtObject then
                localPlayer:markerClick(uniqueID, 0)
            end

            if interestMarkerType.clickFunction then
                interestMarkerType.clickFunction(posMarkerViewInfo, updateDataInfo)
            end
        end
        
        icon.rightClick = function (mouseLoc)
            if interestMarkerType.attachToObject or interestMarkerType.hoverOnLookAtObject then
                localPlayer:markerClick(uniqueID, 1)
            end
        end

        --[[if posChangeUpdateData.learningInfo then
            posMarkerViewInfosByObject[uniqueID].learningInfo = posChangeUpdateData.learningInfo
        end]]

        
        icon.update = function(dt)
            local info = posMarkerViewInfosByID[uniqueID]
            if (not approxEqual(info.goalSize, info.currentSize)) or (not approxEqual(info.differenceVelocity, 0.0)) then
                local difference = info.goalSize - info.currentSize
                local clampedDT = mjm.clamp(dt * 40.0, 0.0, 1.0)
                info.differenceVelocity = info.differenceVelocity * math.max(1.0 - dt * 20.0, 0.0) + (difference * clampedDT)
                info.currentSize = info.currentSize + info.differenceVelocity * dt * 12.0

                updateSizes(info)
            end

            --[[local info = posMarkerViewInfosByObject[uniqueID]
            if (not approxEqual(info.goalSize, info.currentSize)) or (not approxEqual(info.differenceVelocity, 0.0)) then
                local difference = info.goalSize - info.currentSize
                local clampedDT = mjm.clamp(dt * 40.0, 0.0, 1.0)
                info.differenceVelocity = info.differenceVelocity * math.max(1.0 - dt * 20.0, 0.0) + (difference * clampedDT)
                info.currentSize = info.currentSize + info.differenceVelocity * dt * 12.0

                local updatedLogoHalfSize = info.currentSize * 0.4 * 0.5
                info.icon.scale3D = vec3(updatedLogoHalfSize,updatedLogoHalfSize,updatedLogoHalfSize)
                info.icon.size = vec2(updatedLogoHalfSize,updatedLogoHalfSize) * 2.0
                info.icon.baseOffset = vec3(0, 0.08 * (info.currentSize / normalSize), 0.002)
            end]]
        end
    else
        --local sharedStateChanged = false
        posMarkerViewInfo.dataInfo = updateDataInfo

        if updateDataInfo.sharedState then
            --sharedStateChanged = true
            posMarkerViewInfo.sharedState = updateDataInfo.sharedState
        end
        if updateDataInfo.name then
            posMarkerViewInfo.name = updateDataInfo.name
        end
        
        --local sharedState = posMarkerViewInfo.sharedState

        if pos then
            posMarkerViewInfo.pos = pos
        end

        worldUIViewManager:updateView(posMarkerViewInfo.viewID, posMarkerViewInfo.pos, nil, {getOffsetInfo(interestMarkerTypeIndex, updateDataInfo.sharedState)}, posMarkerViewInfo.attachObjectUniqueID, posMarkerViewInfo.attachBoneName)
    
        updateMaterials(interestMarkerType, posMarkerViewInfo)

        local enableDepthTest = (not currentIsMapMode) and (not posMarkerViewInfo.renderingSelectedState)
        posMarkerViewInfo.view:setDepthTestEnabled(enableDepthTest)
        updateTitles(posMarkerViewInfo, posMarkerViewInfo.renderingSelectedState, enableDepthTest)
        
    end

end

local function removeMarker(interestMarkerType, uniqueID)
    if posMarkerViewInfosByTypeThenID[interestMarkerType][uniqueID] then
        if (hoverMarker and hoverMarker.uniqueID == uniqueID) then
            interestMarkersUI:setHoverMarker(nil, false)
        end
        worldUIViewManager:removeView(posMarkerViewInfosByTypeThenID[interestMarkerType][uniqueID].viewID, true)
        posMarkerViewInfosByTypeThenID[interestMarkerType][uniqueID] = nil

    end
end

function interestMarkersUI:updateDestination(destinationInfo)
    if destinationInfo.destinationTypeIndex == destination.types.staticTribe.index then
        local interestMarkerType = interestMarkersUI.interestMarkerTypes.AITribe.index

        local toRemoveMarkers = {}

        for i=1,1000 do
            local uniqueID = destinationInfo.destinationID .. string.format("_%d", i)
            local markerInfo = posMarkerViewInfosByTypeThenID[interestMarkerType][uniqueID]
            if markerInfo then
                toRemoveMarkers[uniqueID] = markerInfo
            else
                break
            end
        end

        local tribeCenters = destinationInfo.tribeCenters
        if tribeCenters and tribeCenters[1] then
            for i,destinationCenterInfo in ipairs(tribeCenters) do
                local uniqueID = destinationInfo.destinationID .. string.format("_%d", i)
                interestMarkersUI:objectChanged(interestMarkerType, uniqueID, destinationCenterInfo.pos, destinationInfo)
                toRemoveMarkers[uniqueID] = nil
            end
        else
            local uniqueID = destinationInfo.destinationID .. string.format("_%d", 1)
            interestMarkersUI:objectChanged(interestMarkerType, uniqueID, destinationInfo.pos, destinationInfo)
            toRemoveMarkers[uniqueID] = nil
        end

        for uniqueID,markerInfo in pairs(toRemoveMarkers) do
            removeMarker(interestMarkerType, uniqueID)
        end
    end
end


--- conveneince functions vvvvvv

function interestMarkersUI:addDestination(destinationInfo)
    interestMarkersUI:updateDestination(destinationInfo)
end

function interestMarkersUI:removeDestination(destinationInfo)
    removeMarker(interestMarkersUI.interestMarkerTypes.AITribe.index, destinationInfo.destinationID)
end

function interestMarkersUI:nonFollowerSapienAdded(addedInfo)
    interestMarkersUI:nonFollowerSapienUpdated(addedInfo)
end

function interestMarkersUI:nonFollowerSapienUpdated(updatedInfo)
    interestMarkersUI:objectChanged(interestMarkersUI.interestMarkerTypes.nonFollowerSapien.index, updatedInfo.uniqueID, updatedInfo.pos, updatedInfo)
end

function interestMarkersUI:nonFollowerSapienRemoved(removeInfo)
    removeMarker(interestMarkersUI.interestMarkerTypes.nonFollowerSapien.index, removeInfo.uniqueID)
end

local function reloadDataIfHoverMarker(interestMarkerTypeIndex, uniqueID)
    local posMarkerViewInfosByID = posMarkerViewInfosByTypeThenID[interestMarkerTypeIndex]
    local posMarkerViewInfo = posMarkerViewInfosByID[uniqueID]
    if posMarkerViewInfo and posMarkerViewInfo == hoverMarker then --bit of a hack, force a reload to update text
        interestMarkersUI:setHoverMarker(nil, true)
        interestMarkersUI:setHoverMarker(posMarkerViewInfo, true)
    end
end

function interestMarkersUI:updateTradeRequestsForStorageArea(updatedInfo)
    if (not updatedInfo.favorIsBelowTradingThreshold) and ((not updatedInfo.requestInfo.tradeLimitReached) or (updatedInfo.deliveredCount and updatedInfo.deliveredCount > 0)) then
        local interestMarkerTypeIndex = interestMarkersUI.interestMarkerTypes.tradeRequest.index
        interestMarkersUI:objectChanged(interestMarkerTypeIndex, updatedInfo.uniqueID, updatedInfo.pos, updatedInfo)
        reloadDataIfHoverMarker(interestMarkerTypeIndex, updatedInfo.uniqueID)
    else
        interestMarkersUI:removeTradeRequestsForStorageArea(updatedInfo.uniqueID)
    end
end

function interestMarkersUI:updateTradeOffersForStorageArea(updatedInfo)
    if (not (updatedInfo.offerInfo.tradeLimitReached or updatedInfo.favorIsBelowTradingThreshold)) or (updatedInfo.purchasedCount and updatedInfo.purchasedCount > 0) then
        local interestMarkerTypeIndex = interestMarkersUI.interestMarkerTypes.tradeOffer.index
        interestMarkersUI:objectChanged(interestMarkerTypeIndex, updatedInfo.uniqueID, updatedInfo.pos, updatedInfo)
        reloadDataIfHoverMarker(interestMarkerTypeIndex, updatedInfo.uniqueID)
    else
        interestMarkersUI:removeTradeOffersForStorageArea(updatedInfo.uniqueID)
    end
end

function interestMarkersUI:removeTradeRequestsForStorageArea(storageAreaID)
    removeMarker(interestMarkersUI.interestMarkerTypes.tradeRequest.index, storageAreaID)
end

function interestMarkersUI:removeTradeOffersForStorageArea(storageAreaID)
    removeMarker(interestMarkersUI.interestMarkerTypes.tradeOffer.index, storageAreaID)
end

function interestMarkersUI:updateQuestsForObject(updatedInfo)
    local interestMarkerTypeIndex = interestMarkersUI.interestMarkerTypes.quest.index
    interestMarkersUI:objectChanged(interestMarkerTypeIndex, updatedInfo.uniqueID, updatedInfo.pos, updatedInfo)
    reloadDataIfHoverMarker(interestMarkerTypeIndex, updatedInfo.uniqueID)
end

function interestMarkersUI:removeQuestForStorageArea(objectID)
    removeMarker(interestMarkersUI.interestMarkerTypes.quest.index, objectID)
end



--- end conveneince functions ^^^^

function interestMarkersUI:setHasSelectedTribe(hasSelectedTribe)
    if hasSelectedTribe then
        if interestMarkersUI.hiddenTribeMarkers then
            interestMarkersUI.hiddenTribeMarkers = false
            worldUIViewManager:setGroupHidden(interestMarkersUI.interestMarkerTypes.AITribe.uiGroup, false)
        end
    else
        if not interestMarkersUI.hiddenTribeMarkers then
            interestMarkersUI.hiddenTribeMarkers = true
            worldUIViewManager:setGroupHidden(interestMarkersUI.interestMarkerTypes.AITribe.uiGroup, true)
        end
    end
end

function interestMarkersUI:setDebugAnchors(debugAnchors)
    for uniqueID, posMarkerInfo in pairs(posMarkerViewInfosByTypeThenID[interestMarkersUI.interestMarkerTypes.debugMarker.index]) do
        worldUIViewManager:removeView(posMarkerInfo.viewID, true)
    end
    posMarkerViewInfosByTypeThenID[interestMarkersUI.interestMarkerTypes.debugMarker.index] = {}

    if debugAnchors then
        for i,anchorInfo in ipairs(debugAnchors) do
            local uniqueID = anchorInfo.objectID .. "_a"
            interestMarkersUI:objectChanged(interestMarkersUI.interestMarkerTypes.debugMarker.index, uniqueID, anchorInfo.pos, anchorInfo)
        end
    end
end

function interestMarkersUI:init(localPlayer_, world_, gameUI_, mainThreadDestination_, hasSelectedTribe)
    localPlayer = localPlayer_
    gameUI = gameUI_
    currentIsMapMode = localPlayer.mapMode ~= nil
    world = world_
    mainThreadDestination = mainThreadDestination_
    for index,v in ipairs(interestMarkersUI.interestMarkerTypes) do
        posMarkerViewInfosByTypeThenID[index] = {}
    end

    interestMarkersUI:setHasSelectedTribe(hasSelectedTribe)
end

return interestMarkersUI