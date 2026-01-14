local gameConstants = mjrequire "common/gameConstants"
local resource = mjrequire "common/resource"

local serverTutorialState = {}

local clientStates = nil
local serverWorld = nil
local server = nil

local function getTutorialState(tribeID)
    local clientID = serverWorld:clientIDForTribeID(tribeID)
    local clientState = clientStates[clientID]
    if clientState and clientState.privateShared then
        local tutorialState = clientState.privateShared.tutorial
        if not tutorialState then
            tutorialState = {}
            clientState.privateShared.tutorial = tutorialState
        end
        return tutorialState
    end
    return nil
end


local function saveAndSendNotificationForClientID(clientID, notificationKey, value)
    if server.connectedClientsSet[clientID] then
        server:callClientFunction(
            "tutorialStateChanged",
            clientID,
            {
                key = notificationKey,
                value = value,
            }
        )
    end
    serverWorld:saveClientState(clientID)
end

local function saveAndSendNotification(tribeID, notificationKey, value)
    saveAndSendNotificationForClientID(serverWorld:clientIDForTribeID(tribeID), notificationKey, value)
end

function serverTutorialState:addToGrassClearCount(tribeID, countToAdd)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.grassClearCount or 0) < gameConstants.tutorial_grassClearCount and countToAdd > 0 then
        tutorialState.grassClearCount = (tutorialState.grassClearCount or 0) + countToAdd
        saveAndSendNotification(tribeID, "grassClearCount", tutorialState.grassClearCount)
    end
end


function serverTutorialState:placeStorageIsComplete(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState then
        return (tutorialState.storageAreaPlaceCount or 0) >= gameConstants.tutorial_storageAreaPlaceCount
    end
    return true
end

function serverTutorialState:setTotalStorageAreaCount(tribeID, newCount)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.storageAreaPlaceCount or 0) < gameConstants.tutorial_storageAreaPlaceCount then
        tutorialState.storageAreaPlaceCount = newCount
        saveAndSendNotification(tribeID, "storageAreaPlaceCount", tutorialState.storageAreaPlaceCount)
    end
end


function serverTutorialState:placeBedsIsComplete(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState then
        return (tutorialState.bedPlaceCount or 0) >= gameConstants.tutorial_bedPlaceCount
    end
    return true
end

function serverTutorialState:setTotalPlacedBedCount(tribeID, newCount)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.bedPlaceCount or 0) < gameConstants.tutorial_bedPlaceCount then
        tutorialState.bedPlaceCount = newCount
        saveAndSendNotification(tribeID, "bedPlaceCount", tutorialState.bedPlaceCount)
    end
end


function serverTutorialState:builtBedsIsComplete(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState then
        return (tutorialState.bedBuiltCount or 0) >= gameConstants.tutorial_bedBuiltCount
    end
    return true
end

function serverTutorialState:setTotalBuiltBedCount(tribeID, newCount)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.bedBuiltCount or 0) < gameConstants.tutorial_bedBuiltCount then
        tutorialState.bedBuiltCount = newCount
        saveAndSendNotification(tribeID, "bedBuiltCount", tutorialState.bedBuiltCount)
    end
end

function serverTutorialState:builtCraftAreasIsComplete(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState then
        return (tutorialState.craftAreaBuiltCount or 0) >= gameConstants.tutorial_craftAreaBuiltCount
    end
    return true
end

function serverTutorialState:setTotalBuiltCraftAreaCount(tribeID, newCount)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.craftAreaBuiltCount or 0) < gameConstants.tutorial_craftAreaBuiltCount then
        tutorialState.craftAreaBuiltCount = newCount
        saveAndSendNotification(tribeID, "craftAreaBuiltCount", tutorialState.craftAreaBuiltCount)
    end
end

local function setBoolean(tribeID, key)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (not tutorialState[key]) then
        tutorialState[key] = true
        saveAndSendNotification(tribeID, key, true)
    end
end

function serverTutorialState:setPlaceCampfireComplete(tribeID)
    setBoolean(tribeID, "hasPlacedCampfire")
end

function serverTutorialState:setLitCampfireComplete(tribeID)
    setBoolean(tribeID, "hasLitCampfire")
end

function serverTutorialState:setPlaceThatchHutComplete(tribeID)
    setBoolean(tribeID, "hasPlacedThatchHut")
end

function serverTutorialState:setBuildThatchHutComplete(tribeID)
    setBoolean(tribeID, "hasBuiltThatchHut")
end

function serverTutorialState:setChopTreeComplete(tribeID)
    setBoolean(tribeID, "hasChoppedTree")
end

function serverTutorialState:setSplitLogComplete(tribeID)
    setBoolean(tribeID, "hasSplitLog")
end

function serverTutorialState:setBuiltSplitLogWallComplete(tribeID)
    setBoolean(tribeID, "hasBuiltSplitLogWall")
end

function serverTutorialState:setCraftPickAxeComplete(tribeID)
    setBoolean(tribeID, "hasCraftedPickAxe")
end

function serverTutorialState:setCraftSpearComplete(tribeID)
    setBoolean(tribeID, "hasCraftedSpear")
end

function serverTutorialState:setCraftHatchetComplete(tribeID)
    setBoolean(tribeID, "hasCraftedHatchet")
end

function serverTutorialState:setCraftedCookedMeatComplete(tribeID)
    setBoolean(tribeID, "hasCraftedCookedMeat")
end


function serverTutorialState:setSapienHungry(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and not tutorialState.sapienIsHungry then
        tutorialState.sapienIsHungry = true
        saveAndSendNotification(tribeID, "sapienIsHungry", true)
    end
end

function serverTutorialState:foodCropWasPlanted(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.foodCropPlantCount or 0) < gameConstants.tutorial_foodCropPlantCount then
        tutorialState.foodCropPlantCount = (tutorialState.foodCropPlantCount or 0) + 1
        saveAndSendNotification(tribeID, "foodCropPlantCount", tutorialState.foodCropPlantCount)
    end
end

function serverTutorialState:pathWasBuilt(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.pathBuildCount or 0) < gameConstants.tutorial_pathBuildCount then
        tutorialState.pathBuildCount = (tutorialState.pathBuildCount or 0) + 1
        saveAndSendNotification(tribeID, "pathBuildCount", tutorialState.pathBuildCount)
    end
end

function serverTutorialState:musicPlayActionSequenceStarted(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (not tutorialState.musicPlayActionStarted) and (not tutorialState.flutePlayActionStarted) then
        tutorialState.musicPlayActionStarted = true
        saveAndSendNotification(tribeID, "musicPlayActionStarted", true)
    end
end

function serverTutorialState:objectWasDeliveredForTransferRoute(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (not tutorialState.objectWasDeliveredForTransferRoute) then
        tutorialState.objectWasDeliveredForTransferRoute = true
        saveAndSendNotification(tribeID, "objectWasDeliveredForTransferRoute", true)
    end
end

function serverTutorialState:sapienGotFoodPoisoningDueToContamination(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (not tutorialState.sapienGotFoodPoisoningDueToContamination) then
        tutorialState.sapienGotFoodPoisoningDueToContamination = true
        saveAndSendNotification(tribeID, "sapienGotFoodPoisoningDueToContamination", true)
    end
end

local storedResourceFunctionByResourceType = {
    [resource.types.hay.index] = function(tribeID, resourceTypeIndex, newCount)
        local tutorialState = getTutorialState(tribeID)
        if tutorialState and (tutorialState.storeHayCount or 0) < gameConstants.tutorial_storeHayCount then
            tutorialState.storeHayCount = newCount
            saveAndSendNotification(tribeID, "storeHayCount", tutorialState.storeHayCount)
        end
    end,
    [resource.types.branch.index] = function(tribeID, resourceTypeIndex, newCount)
        local tutorialState = getTutorialState(tribeID)
        if tutorialState and (tutorialState.storeBranchCount or 0) < gameConstants.tutorial_storeBranchCount then
            tutorialState.storeBranchCount = newCount
            saveAndSendNotification(tribeID, "storeBranchCount", tutorialState.storeBranchCount)
        end
    end,
    [resource.types.stoneAxeHead.index] = function(tribeID, resourceTypeIndex, newCount)
        local tutorialState = getTutorialState(tribeID)
        if tutorialState and (tutorialState.craftHandAxeCount or 0) < gameConstants.tutorial_craftHandAxeCount then
            tutorialState.craftHandAxeCount = newCount
            saveAndSendNotification(tribeID, "craftHandAxeCount", tutorialState.craftHandAxeCount)
        end
    end,
    [resource.types.stoneKnife.index] = function(tribeID, resourceTypeIndex, newCount)
        local tutorialState = getTutorialState(tribeID)
        if tutorialState and (tutorialState.craftKnifeCount or 0) < gameConstants.tutorial_craftKnifeCount then
            tutorialState.craftKnifeCount = newCount
            saveAndSendNotification(tribeID, "craftKnifeCount", tutorialState.craftKnifeCount)
        end
    end,
    [resource.types.flaxDried.index] = function(tribeID, resourceTypeIndex, newCount)
        local tutorialState = getTutorialState(tribeID)
        if tutorialState and (tutorialState.storeFlaxCount or 0) < gameConstants.tutorial_storeFlaxCount then
            tutorialState.storeFlaxCount = newCount
            saveAndSendNotification(tribeID, "storeFlaxCount", tutorialState.storeFlaxCount)
        end
    end,
    [resource.types.flaxTwine.index] = function(tribeID, resourceTypeIndex, newCount)
        local tutorialState = getTutorialState(tribeID)
        if tutorialState and (tutorialState.storeTwineCount or 0) < gameConstants.tutorial_storeTwineCount then
            tutorialState.storeTwineCount = newCount
            saveAndSendNotification(tribeID, "storeTwineCount", tutorialState.storeTwineCount)
        end
    end,
}

storedResourceFunctionByResourceType[resource.types.stoneAxeHeadSoft.index] = storedResourceFunctionByResourceType[resource.types.stoneAxeHead.index]

function serverTutorialState:checkForTutorialNotificationDueToAddition(tribeID, resourceTypeIndex, newCount)
    local func = storedResourceFunctionByResourceType[resourceTypeIndex]
    if func then
        func(tribeID, resourceTypeIndex, newCount)
    end
end

function serverTutorialState:checkForTutorialNotificationDueToFoodAddition(tribeID, newFoodCount)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (tutorialState.storeFoodCount or 0) < gameConstants.tutorial_storeFoodCount then
        tutorialState.storeFoodCount = newFoodCount
        saveAndSendNotification(tribeID, "storeFoodCount", tutorialState.storeFoodCount)
    end
end
    
function serverTutorialState:reset(clientID)
    local clientState = clientStates[clientID]
    if clientState and clientState.privateShared then
        if clientState.privateShared.tutorial then
            clientState.privateShared.tutorial = {}
            serverWorld:saveClientState(clientID)
        end
    end
end

function serverTutorialState:tribeNoticed(nomadTribeID, clientTribeID, recruitChanceOffsetOrNil)
    --mj:log("serverTutorialState:tribeNoticed:", nomadTribeID, " clientTribeID:", clientTribeID)
    local tutorialState = getTutorialState(clientTribeID)
    if tutorialState and not tutorialState.hasRecruitedNomad then
        local noticedTribes = tutorialState.noticedTribes
        if not noticedTribes then
            noticedTribes = {}
            tutorialState.noticedTribes = noticedTribes
        end
        if not noticedTribes[nomadTribeID] then
            noticedTribes[nomadTribeID] = true
            --mj:log("update noticedTribes:", noticedTribes)

            if (not tutorialState.nomadsAvailableToBeRecruited) and (recruitChanceOffsetOrNil and recruitChanceOffsetOrNil >= 0) then
                --mj:log("set tutorialState.nomadsAvailableToBeRecruited")
                tutorialState.nomadsAvailableToBeRecruited = true
                saveAndSendNotification(clientTribeID, "nomadsAvailableToBeRecruited", true)
            else
                --mj:log("tutorialState.nomadsAvailableToBeRecruited already set")
                serverWorld:saveClientState(serverWorld:clientIDForTribeID(clientTribeID))
            end
        end
    end
end

function serverTutorialState:tribeStartedExiting(nomadTribeID) --todo if all of the sapiens die or otherwise disappear before they start to exit, then this fails
    --mj:log("serverTutorialState:tribeStartedExiting:", nomadTribeID)
    for clientID,clientState in pairs(clientStates) do
        if clientState.privateShared then
            local tutorialState = clientState.privateShared.tutorial
            if tutorialState and (not tutorialState.hasRecruitedNomad) then
                local noticedTribes = tutorialState.noticedTribes
                if noticedTribes then
                    --mj:log("noticedTribes:", noticedTribes)
                    if noticedTribes[nomadTribeID] then
                        noticedTribes[nomadTribeID] = nil
                        --mj:log("removed tribe")
                    end

                    if next(noticedTribes) then
                        --mj:log("still tribes available")
                        serverWorld:saveClientState(clientID)
                    else
                       -- mj:log("setting nomadsAvailableToBeRecruited to false")
                        tutorialState.noticedTribes = nil
                        tutorialState.nomadsAvailableToBeRecruited = false
                        saveAndSendNotificationForClientID(clientID, "nomadsAvailableToBeRecruited", false)
                    end
                end
            end
        end
    end
end

function serverTutorialState:nomadWasRecruited(tribeID)
    local tutorialState = getTutorialState(tribeID)
    if tutorialState and (not tutorialState.hasRecruitedNomad) then
        tutorialState.hasRecruitedNomad = true
        tutorialState.noticedTribes = nil
        tutorialState.nomadsAvailableToBeRecruited = nil
        saveAndSendNotification(tribeID, "hasRecruitedNomad", tutorialState.hasRecruitedNomad)
    end
end

function serverTutorialState:init(server_, serverWorld_, clientStates_)
    server = server_
    serverWorld = serverWorld_
    clientStates = clientStates_
end

return serverTutorialState