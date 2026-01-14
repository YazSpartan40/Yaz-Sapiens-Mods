
--local gameObject = mjrequire "common/gameObject"
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"
local resource = mjrequire "common/resource"
local gameObject = mjrequire "common/gameObject"

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"

local questUIHelper = mjrequire "mainThread/ui/questUIHelper"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"

local actionUIQuestView = {}

local world = nil
local actionUI = nil
local mainThreadDestination = nil

local mainView = nil
local backgroundView = nil
local gameObjectView = nil
local tribeRelationshipButton = nil
local textBackgroundView = nil
local titleTextView = nil
local subTitleTextView = nil
local iconHalfSize = 60.0

function actionUIQuestView:init(gameUI_, hubUI_, world_, actionUI_, mainThreadDestination_)
    world = world_
    actionUI = actionUI_
    mainThreadDestination = mainThreadDestination_


    mainView = View.new(actionUI.backgroundView)


    backgroundView = ModelView.new(mainView)

    backgroundView.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    backgroundView.size = vec2(iconHalfSize,iconHalfSize) * 2.0
    backgroundView.baseOffset = vec3(0.0,240.0,0.0)

    tribeRelationshipButton = uiStandardButton:create(backgroundView, vec2(iconHalfSize,iconHalfSize), uiStandardButton.types.orderMarkerSmall, {
        [material.types.ui_standard.index] = material.types.ui_bronze_lightest.index,
    })
    uiStandardButton:setIconModel(tribeRelationshipButton, "icon_tribeRelations", nil)

    uiStandardButton:setClickFunction(tribeRelationshipButton, function()
        local baseObjectSharedState = actionUI.baseObject and actionUI.baseObject.sharedState
        local tribeID = baseObjectSharedState and actionUI.baseObject.sharedState.tribeID
        if tribeID then
            tribeRelationsUI:show(mainThreadDestination.destinationInfosByID[tribeID], nil, nil, nil, false)

            if baseObjectSharedState.tradeOffer then 
                tribeRelationsUI:selectOffer(baseObjectSharedState.tradeOffer)
            elseif baseObjectSharedState.tradeRequest then
                tribeRelationsUI:selectRequest(baseObjectSharedState.tradeRequest)
            end

            actionUI:animateOutForOptionSelected()
        end
    end)

end


--if (not updatedInfo.favorIsBelowTradingThreshold) and ((not updatedInfo.requestInfo.tradeLimitReached) or (updatedInfo.deliveredCount and updatedInfo.deliveredCount > 0)) then
--if (not (updatedInfo.offerInfo.tradeLimitReached or updatedInfo.favorIsBelowTradingThreshold)) or (updatedInfo.purchasedCount and updatedInfo.purchasedCount > 0) then


function actionUIQuestView:updateObject()
    local found = false
    if actionUI.selectedObjects then
        local selectedObject = actionUI.selectedObjects[1]
        if selectedObject and selectedObject.sharedState then
            --mj:log("actionUIQuestView selectedObject:", selectedObject)
            local objectQuestState = selectedObject.sharedState.quest
            local tradeRequest = selectedObject.sharedState.tradeRequest
            local tradeOffer = selectedObject.sharedState.tradeOffer



            if objectQuestState or tradeRequest or tradeOffer then

                local objectOwnerTribeDestinationState = nil
                local tribeID = actionUI.baseObject.sharedState and actionUI.baseObject.sharedState.tribeID
                if tribeID then
                    objectOwnerTribeDestinationState = mainThreadDestination.destinationInfosByID[tribeID]
                end

                local tradeIsAllowed = false

                local relationshipState = objectOwnerTribeDestinationState and objectOwnerTribeDestinationState.relationships and objectOwnerTribeDestinationState.relationships[world:getTribeID()]
                if relationshipState then
                    if objectQuestState then
                        tradeIsAllowed = true
                    elseif tradeRequest then
                        local tradeRequestDeliveries = relationshipState.tradeRequestDeliveries
                        local deliveredCount = tradeRequestDeliveries and tradeRequestDeliveries[tradeRequest.resourceTypeIndex]
                        local requests = objectOwnerTribeDestinationState.tradeables.requests
                        local requestInfo = requests[tradeRequest.resourceTypeIndex]
                        if requestInfo then
                            if (not relationshipState.favorIsBelowTradingThreshold) and ((not requestInfo.tradeLimitReached) or (deliveredCount and deliveredCount > 0)) then
                                tradeIsAllowed = true
                            end
                        end
                    elseif objectOwnerTribeDestinationState.tradeables then

                        if tradeOffer.resourceTypeIndex then
                            local tradeOfferPurchases = relationshipState.tradeOfferPurchases 
                            local purchasedCount = tradeOfferPurchases and tradeOfferPurchases[tradeOffer.resourceTypeIndex]
                            local offers = objectOwnerTribeDestinationState.tradeables.offers
                            if offers then
                                local offerInfo = offers[tradeOffer.resourceTypeIndex]
                                if offerInfo then
                                    if (not (offerInfo.tradeLimitReached or relationshipState.favorIsBelowTradingThreshold)) or (purchasedCount and purchasedCount > 0) then
                                        tradeIsAllowed = true
                                    end
                                end
                            end
                        elseif tradeOffer.objectTypeIndex then
                            local tradeOfferObjectTypePurchases = relationshipState.tradeOfferObjectTypePurchases
                            local purchasedObjectTypeCount = tradeOfferObjectTypePurchases and tradeOfferObjectTypePurchases[tradeOffer.objectTypeIndex]
                            local objectTypeOffers = objectOwnerTribeDestinationState.tradeables.objectTypeOffers
                            if objectTypeOffers then
                                local offerInfo = objectTypeOffers[tradeOffer.objectTypeIndex]
                                if offerInfo then
                                    if (not (offerInfo.tradeLimitReached or relationshipState.favorIsBelowTradingThreshold)) or (purchasedObjectTypeCount and purchasedObjectTypeCount > 0) then
                                        tradeIsAllowed = true
                                    end
                                end
                            end
                        end
                    end
                end

                if tradeIsAllowed then

                    local backgroundModelName = nil
                    local resourceTypeIndex = nil
                    local objectTypeIndex = nil

                    if objectQuestState then
                        backgroundModelName = "ui_questMarker"
                        resourceTypeIndex = objectQuestState.resourceTypeIndex
                    elseif tradeRequest then
                        backgroundModelName = "ui_tradeRequestMarker"
                        resourceTypeIndex = tradeRequest.resourceTypeIndex
                    else
                        backgroundModelName = "ui_tradeOfferMarker"
                        resourceTypeIndex = tradeOffer.resourceTypeIndex
                        objectTypeIndex = tradeOffer.objectTypeIndex
                    end


                    backgroundView:setModel(model:modelIndexForName(backgroundModelName), {
                        default = material.types.ui_bronze.index,
                        [material.types.ui_standard.index] = material.types.ui_bronze_lightest.index
                    })

                    if not gameObjectView then
                        gameObjectView = uiGameObjectView:create(backgroundView, vec2(128,128), uiGameObjectView.types.standard)
                        gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
                        gameObjectView.masksEvents = false
                        local objectHalfSize = 0.5 * iconHalfSize * 2.0
                        uiGameObjectView:setSize(gameObjectView, vec2(objectHalfSize,objectHalfSize))
                            
                    end

                    local objectInfo = {
                        objectTypeIndex = objectTypeIndex or resource.types[resourceTypeIndex].displayGameObjectTypeIndex
                    }

                    uiGameObjectView:setObject(gameObjectView, objectInfo, nil, nil)

                    local tribeName = objectOwnerTribeDestinationState.name
                    
                    if tribeName then
                        uiToolTip:add(tribeRelationshipButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("plan_manageTribeRelationsWithTribeName", {tribeName=tribeName}), nil, vec3(0.0,0.0,6.0), nil, tribeRelationshipButton)
                    else
                        uiToolTip:add(tribeRelationshipButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("plan_manageTribeRelations"), nil, vec3(0.0,0.0,6.0), nil, tribeRelationshipButton)
                    end

                    local titleText = nil
                    local subTitleText = nil


                    if objectQuestState then
                        local relationshipQuestState = relationshipState.questState
                        local questDeliveries = relationshipState.questDeliveries
                        titleText = questUIHelper:getDescriptiveQuestLabelTextForQuestState(relationshipQuestState) .. ": " .. questUIHelper:getQuestShortSummaryText(relationshipQuestState, questDeliveries and questDeliveries[relationshipQuestState.resourceTypeIndex])

                        tribeRelationshipButton.baseOffset = vec3(iconHalfSize * 0.8,-iconHalfSize * 0.5, iconHalfSize * 0.01)

                        subTitleText = questUIHelper:getTimeLeftTextForQuestState(relationshipQuestState)
                    elseif tradeRequest then

                        local tradeRequestDeliveries = relationshipState.tradeRequestDeliveries
                        local deliveredCount = tradeRequestDeliveries and tradeRequestDeliveries[resourceTypeIndex]

                        if deliveredCount and deliveredCount > 0 then
                            titleText = string.format("%s: %d %s - %s: %d/%d", 
                            locale:get("ui_name_request"), 
                            tradeRequest.count,
                            resource.types[resourceTypeIndex].plural,
                            locale:get("ui_name_delivered"),
                            deliveredCount, 
                            tradeRequest.count)
                        else
                            titleText = string.format("%s: %d %s", 
                            locale:get("ui_name_request"), 
                            tradeRequest.count,
                            resource.types[resourceTypeIndex].plural)
                        end

                        tribeRelationshipButton.baseOffset = vec3(iconHalfSize * 0.5,-iconHalfSize * 0.5, iconHalfSize * 0.01)
                    else
                        local resourceOrObjectName = nil
                        local purchasedCount = nil

                        if resourceTypeIndex then
                            local tradeOfferPurchases = relationshipState.tradeOfferPurchases 
                            purchasedCount = tradeOfferPurchases and tradeOfferPurchases[resourceTypeIndex]
                            resourceOrObjectName = resource.types[resourceTypeIndex].plural
                        else
                            local tradeOfferObjectTypePurchases = relationshipState.tradeOfferObjectTypePurchases 
                            purchasedCount = tradeOfferObjectTypePurchases and tradeOfferObjectTypePurchases[objectTypeIndex]
                            resourceOrObjectName = gameObject.types[objectTypeIndex].plural
                        end

                        if purchasedCount and purchasedCount > 0 then
                            titleText = string.format("%s: %d %s - %s: %d",
                            locale:get("ui_name_offer"), 
                            tradeOffer.count,
                            resourceOrObjectName,
                            locale:get("ui_name_purchased"),
                            purchasedCount)
                        else
                            titleText = string.format("%s: %d %s", 
                            locale:get("ui_name_offer"), 
                            tradeOffer.count,
                            resourceOrObjectName)
                        end

                        tribeRelationshipButton.baseOffset = vec3(iconHalfSize * 0.5,-iconHalfSize * 0.5, iconHalfSize * 0.01)
                    end

                    if titleText then
                        if not textBackgroundView then
                            textBackgroundView = ModelView.new(backgroundView)
                            textBackgroundView:setModel(model:modelIndexForName("ui_panel_10x2"), {default = material.types.ui_bronze.index})
                            textBackgroundView.masksEvents = false
                        end

                        if not titleTextView then
                            titleTextView = TextView.new(textBackgroundView)
                            titleTextView.color = mj.textColor
                            titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
                            titleTextView.font = Font(uiCommon.titleFontName, 24)
                        end
                        
                        titleTextView.text = titleText

                        local panelHeight = 40
                        if subTitleText then
                            panelHeight = panelHeight + 20

                            if not subTitleTextView then
                                subTitleTextView = TextView.new(textBackgroundView)
                                subTitleTextView.color = mj.textColor
                                subTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
                                subTitleTextView.relativeView = titleTextView
                                subTitleTextView.font = Font(uiCommon.fontName, 18)
                            end

                            subTitleTextView.hidden = false
                            subTitleTextView.text = subTitleText

                            if objectQuestState then
                                local accumulator = 0.0
                                subTitleTextView.update = function(dt)
                                    accumulator = accumulator + dt
                                    if accumulator >= 1.0 then
                                        accumulator = accumulator - 1.0
                                        if accumulator > 1.0 then
                                            accumulator = 0.0
                                        end

                                        local relationshipQuestState = relationshipState and relationshipState.questState
                                        subTitleText = (relationshipQuestState and questUIHelper:getTimeLeftTextForQuestState(relationshipQuestState)) or ""
                                        subTitleTextView.text = subTitleText
                                    end
                                end
                            end

                            textBackgroundView.baseOffset = vec3(0,iconHalfSize + 20.0 + 10.0,0)
                            titleTextView.baseOffset = vec3(0,13,0)
                        else
                            if subTitleTextView then
                                subTitleTextView.hidden = true
                            end

                            textBackgroundView.baseOffset = vec3(0,iconHalfSize + 20.0,0)
                            titleTextView.baseOffset = vec3(0,0,0)
                        end


                        local width = math.max(80, titleTextView.size.x + 20)
                        
                        local sizeToUse = vec2(width, panelHeight)
                        textBackgroundView.size = sizeToUse

                        local scaleToUseX = sizeToUse.x * 0.5
                        local scaleToUseY = sizeToUse.y * 0.5 / 0.2
                        textBackgroundView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)

                    elseif textBackgroundView then
                        backgroundView:removeSubview(textBackgroundView)
                        textBackgroundView = nil
                        titleTextView = nil
                        subTitleTextView = nil
                    end


                    found = true
                end
            end

        end
    end

    mainView.hidden = (not found)
end

function actionUIQuestView:updateQuestsForObject(questInfo)
    if actionUI.selectedObjects and actionUI.selectedObjects[1] and actionUI.selectedObjects[1].uniqueID == questInfo.uniqueID then
        actionUIQuestView:updateObject()
    end
end

return actionUIQuestView