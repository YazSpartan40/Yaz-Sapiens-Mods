--local mjm = mjrequire "common/mjm"
--local vec4 = mjm.vec4

local planHelper = mjrequire "common/planHelper"
local quest = mjrequire "common/quest"

local tribeSelectionMarkersUI = mjrequire "mainThread/ui/tribeSelectionMarkersUI"
local interestMarkersUI = mjrequire "mainThread/ui/interestMarkersUI"
local actionUIQuestView = mjrequire "mainThread/ui/actionUIQuestView"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"
local tribeSelectionUI = mjrequire "mainThread/ui/tribeSelectionUI"
--local lightManager = mjrequire "mainThread/lightManager"

local world = nil


local mainThreadDestination = {
    destinationInfosByID = {},
    tradeableAddedMarkerStorageAreaIDsByDestinationID = {},
    questAddedMarkerObjectIDsByDestinationID = {}
}

local function updateQuests(destinationInfo)
    if not (destinationInfo.relationships and destinationInfo.relationships[world.tribeID]) then
        return
    end
    --mj:log("updateQuests:", destinationInfo)
    local activeQuest = destinationInfo.relationships[world.tribeID].questState
    if not activeQuest then
        return
    end
    --mj:log("activeQuest:", activeQuest)

    local questDeliveries = destinationInfo.relationships[world.tribeID].questDeliveries or {}

    local addedIDToRemove = mainThreadDestination.questAddedMarkerObjectIDsByDestinationID[destinationInfo.destinationID]

    if activeQuest.questTypeIndex == quest.types.resource.index then
        if activeQuest.objectID then
            addedIDToRemove = nil
            --mj:log("added.")
            mainThreadDestination.questAddedMarkerObjectIDsByDestinationID[destinationInfo.destinationID] = activeQuest.objectID

            local questInfo = {
                uniqueID = activeQuest.objectID,
                pos = activeQuest.objectPos,
                questState = activeQuest,
                --resourceTypeIndex = activeQuest.resourceTypeIndex,
                --requiredCount = activeQuest.requiredCount,
                deliveredCount = questDeliveries[activeQuest.resourceTypeIndex],
                --timeRemaining = activeQuest.generationTime?, --todo
            }
            interestMarkersUI:updateQuestsForObject(questInfo)
            actionUIQuestView:updateQuestsForObject(questInfo)
        end
    end

    if addedIDToRemove then
        interestMarkersUI:removeQuestForStorageArea(addedIDToRemove)
        --mj:log("called interestMarkersUI:removeQuestForStorageArea:", addedIDToRemove)
    end
end

--local addedLights = {}

--[[local function updateLightsForOnlineStatusChange(destinationState)
    local shouldAdd = true--destinationState.playerOnline
    local lightID = addedLights[destinationState.destinationID]

    if shouldAdd and (not lightID) then
        lightID = lightManager:addLight(destinationState.pos, vec4(32.0,16.0,32.0, 32.0), lightManager.lightPriorities.high)
        addedLights[destinationState.destinationID] = lightID
    elseif (not shouldAdd) and lightID then
        lightManager:removeLight(lightID)
        addedLights[destinationState.destinationID] = nil
    end
end]]

local function updateTradeables(destinationInfo)
    --mj:log("updateTradeables relationships:", destinationInfo.relationships)

    if not (destinationInfo.tradeables and destinationInfo.relationships and destinationInfo.relationships[world.tribeID]) then
        return
    end

    
    local addedIDs = mainThreadDestination.tradeableAddedMarkerStorageAreaIDsByDestinationID[destinationInfo.destinationID] or {}
    local keepIDs = {}

    local relationship = destinationInfo.relationships[world.tribeID]

    local tradeRequestDeliveries = relationship.tradeRequestDeliveries 
    local tradeOfferPurchases = relationship.tradeOfferPurchases 
    local tradeOfferObjectTypePurchases = relationship.tradeOfferObjectTypePurchases 

   -- mj:log("updateTradeables:", destinationInfo.tradeables)
   -- mj:log("tradeRequestDeliveries:", tradeRequestDeliveries)

    for resourceTypeIndex,requestInfo in pairs(destinationInfo.tradeables.requests) do
        if requestInfo.storageAreaID then
            local deliveredCount = nil
            if tradeRequestDeliveries then
                deliveredCount = tradeRequestDeliveries[resourceTypeIndex]
            end

            keepIDs[requestInfo.storageAreaID] = true
            addedIDs[requestInfo.storageAreaID] = true
            --mj:log("adding requestInfo:", requestInfo, " deliveredCount:", deliveredCount)
            interestMarkersUI:updateTradeRequestsForStorageArea({
                uniqueID = requestInfo.storageAreaID,
                pos = requestInfo.storageAreaPos,
                resourceTypeIndex = resourceTypeIndex,
                deliveredCount = deliveredCount,
                requestInfo = requestInfo,
                favorIsBelowTradingThreshold = relationship.favorIsBelowTradingThreshold,
            })
        end
    end


    for resourceTypeIndex,offerInfo in pairs(destinationInfo.tradeables.offers) do
        if offerInfo.storageAreaID then
            local purchasedCount = nil
            if tradeOfferPurchases then
                purchasedCount = tradeOfferPurchases[resourceTypeIndex]
            end

            keepIDs[offerInfo.storageAreaID] = true
            addedIDs[offerInfo.storageAreaID] = true
            --mj:log("adding requestInfo:", requestInfo, " deliveredCount:", deliveredCount)
            interestMarkersUI:updateTradeOffersForStorageArea({
                uniqueID = offerInfo.storageAreaID,
                pos = offerInfo.storageAreaPos,
                resourceTypeIndex = resourceTypeIndex,
                purchasedCount = purchasedCount,
                offerInfo = offerInfo,
                favorIsBelowTradingThreshold = relationship.favorIsBelowTradingThreshold,
            })
        end
    end

    if destinationInfo.tradeables.objectTypeOffers then
        for objectTypeIndex, offerInfo in pairs(destinationInfo.tradeables.objectTypeOffers) do
            if offerInfo.storageAreaID then
                local purchasedCount = nil
                if tradeOfferObjectTypePurchases then
                    purchasedCount = tradeOfferObjectTypePurchases[objectTypeIndex]
                end

                keepIDs[offerInfo.storageAreaID] = true
                addedIDs[offerInfo.storageAreaID] = true
                --mj:log("adding requestInfo:", requestInfo, " deliveredCount:", deliveredCount)
                interestMarkersUI:updateTradeOffersForStorageArea({
                    uniqueID = offerInfo.storageAreaID,
                    pos = offerInfo.storageAreaPos,
                    objectTypeIndex = objectTypeIndex,
                    purchasedCount = purchasedCount,
                    offerInfo = offerInfo,
                    favorIsBelowTradingThreshold = relationship.favorIsBelowTradingThreshold,
                })
            end
        end
    end

    for storageAreaID,v in pairs(addedIDs) do
        if not keepIDs[storageAreaID] then
            interestMarkersUI:removeTradeRequestsForStorageArea(storageAreaID)
            interestMarkersUI:removeTradeOffersForStorageArea(storageAreaID)
        end
    end

end

function mainThreadDestination:addDestination(destinationInfo)
    mainThreadDestination.destinationInfosByID[destinationInfo.destinationID] = destinationInfo
    mainThreadDestination.tradeableAddedMarkerStorageAreaIDsByDestinationID[destinationInfo.destinationID] = {}

    tribeSelectionMarkersUI:addDestination(destinationInfo)
    interestMarkersUI:addDestination(destinationInfo)
    --updateLightsForOnlineStatusChange(destinationInfo)
    updateTradeables(destinationInfo)
    updateQuests(destinationInfo)
    planHelper:setDestinationStateForTribeID(destinationInfo.destinationID, destinationInfo)
end

function mainThreadDestination:updateDestinationTribeCenters(tribeCentersInfo)
    local fullDestinationInfo = mainThreadDestination.destinationInfosByID[tribeCentersInfo.destinationID]
    if fullDestinationInfo then
        fullDestinationInfo.tribeCenters = tribeCentersInfo.tribeCenters
        interestMarkersUI:updateDestination(fullDestinationInfo)
    end
end

function mainThreadDestination:updateDestinationRelationship(relationshipInfo)
    --mj:log("mainThreadDestination:updateDestinationRelationship:", relationshipInfo)
    local fullDestinationInfo = mainThreadDestination.destinationInfosByID[relationshipInfo.destinationID]
    if fullDestinationInfo then
        if not fullDestinationInfo.relationships then
            fullDestinationInfo.relationships = {}
        end
        fullDestinationInfo.relationships[world.tribeID] = relationshipInfo.relationship
        interestMarkersUI:updateDestination(fullDestinationInfo)
        tribeRelationsUI:updateDestination(fullDestinationInfo)
        updateTradeables(fullDestinationInfo)
        updateQuests(fullDestinationInfo)
    end
end


function mainThreadDestination:updateDestinationTradeables(info)
    --mj:log("mainThreadDestination:updateDestinationTradeables")
    local fullDestinationInfo = mainThreadDestination.destinationInfosByID[info.destinationID]
    if fullDestinationInfo then
        fullDestinationInfo.tradeables = info.tradeables
        updateTradeables(fullDestinationInfo)
        updateQuests(fullDestinationInfo)
    end
end


--[[local function removeLightForDestinationRemoval(destinationState)
    local lightID = addedLights[destinationState.destinationID]
    if lightID then
        lightManager:removeLight(lightID)
        addedLights[destinationState.destinationID] = nil
    end
end]]

function mainThreadDestination:updateDestinationPlayerOnlineStatus(info)
    local fullDestinationInfo = mainThreadDestination.destinationInfosByID[info.destinationID]
    if fullDestinationInfo then
        fullDestinationInfo.playerOnline = info.playerOnline
        interestMarkersUI:updateDestination(fullDestinationInfo)
        --updateLightsForOnlineStatusChange(fullDestinationInfo)
    end
end

function mainThreadDestination:updateDestination(destinationInfo)
    mainThreadDestination.destinationInfosByID[destinationInfo.destinationID] = destinationInfo
    interestMarkersUI:updateDestination(destinationInfo)
    --updateLightsForOnlineStatusChange(destinationInfo)
    tribeRelationsUI:updateDestination(destinationInfo)
    updateTradeables(destinationInfo)
    updateQuests(destinationInfo)
    planHelper:setDestinationStateForTribeID(destinationInfo.destinationID, destinationInfo)
    tribeSelectionMarkersUI:updateDestination(destinationInfo)
    if (not tribeSelectionUI:hidden()) and (tribeSelectionUI.selectedTribeID == destinationInfo.destinationID) then
        tribeSelectionUI:showTribe(destinationInfo)
    end
end

function mainThreadDestination:removeDestination(destinationInfo)
    tribeSelectionMarkersUI:removeDestination(destinationInfo)
    interestMarkersUI:removeDestination(destinationInfo)
    --removeLightForDestinationRemoval(destinationInfo)
    tribeRelationsUI:removeDestination(destinationInfo)
    mainThreadDestination.destinationInfosByID[destinationInfo.destinationID] = nil
    planHelper:setDestinationStateForTribeID(destinationInfo.destinationID, nil)
    if (not tribeSelectionUI:hidden()) and (tribeSelectionUI.selectedTribeID == destinationInfo.destinationID) then
        tribeSelectionUI:hide(true)
    end
end

function mainThreadDestination:init(world_)
    world = world_
end



-- below ended up not being used, so is untested
--[[
function mainThreadDestination:getOtherTribeIsThreatening(otherTribeID)

    if world.tribeID ~= otherTribeID then

        local otherDestinationState = mainThreadDestination.destinationInfosByID[otherTribeID]
        if otherDestinationState then
            if otherDestinationState.clientID then
                local relationshipSettings = world:getOrCreateTribeRelationsSettings(otherTribeID)
                if relationshipSettings and relationshipSettings.treatAsThreat then
                    return true
                end
            else
                if otherDestinationState.nomadState then
                    return nomadTribeBehavior.types[otherDestinationState.nomadState.tribeBehaviorTypeIndex].isRaid
                end

                local relationship = otherDestinationState.relationships and otherDestinationState.relationships[world.tribeID]
                if (not relationship) or relationship.favor <= gameConstants.tribeRelationshipScoreThresholds.mildNegative then
                    return true
                end
            end
        end
    end

    return false
end]]

return mainThreadDestination