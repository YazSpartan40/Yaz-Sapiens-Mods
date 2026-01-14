--local mapModes = mjrequire "common/mapModes"

local audio = mjrequire "mainThread/audio"
local musicPlayer = mjrequire "mainThread/musicPlayer"
local playerSapiens = mjrequire "mainThread/playerSapiens"
local mainThreadDestination = mjrequire "mainThread/mainThreadDestination"
local notification = mjrequire "common/notification"
--local notificationSound = mjrequire "common/notificationSound"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
--local locale = mjrequire "common/locale"

local sapienMarkersUI = mjrequire "mainThread/ui/sapienMarkersUI"
local lightManager = mjrequire "mainThread/lightManager"
local tribeSelectionMarkersUI = mjrequire "mainThread/ui/tribeSelectionMarkersUI"
local interestMarkersUI = mjrequire "mainThread/ui/interestMarkersUI"
local planMarkersUI = mjrequire "mainThread/ui/planMarkersUI"
local chatMessageUI = mjrequire "mainThread/ui/chatMessageUI"
local animationManager = mjrequire "mainThread/animationManager"
local notificationsUI = mjrequire "mainThread/ui/notificationsUI"
local discoveryUI = mjrequire "mainThread/ui/discoveryUI"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local debugUI = mjrequire "mainThread/ui/debugUI"
--local manageButtonsUI = mjrequire "mainThread/ui/manageButtonsUI"

local tribeNotificationsUI = mjrequire "mainThread/ui/manageUI/tribeNotificationsUI"


local logicInterface = {
    stateChangeRegistrationGroups = {
        playerSapiens = 1,
        playerLookAt = 2,
        actionUI = 3,
        inspectUI = 4,
    }
}

local bridge = nil
local world = nil
local localPlayer = nil

function logicInterface:init(world_, localPlayer_)
    world = world_
    localPlayer = localPlayer_
    sapienMarkersUI:init(world, localPlayer)
    planMarkersUI:init(localPlayer)
end


local registeredObjectStateChangeFunctionsByIdAndGroup = {}
local registeredVertStateChangeFunctionsByIdAndGroup = {}

function logicInterface:setBridge(bridge_)
    bridge = bridge_

    playerSapiens:setLogicInterface(logicInterface)
    audio:setLogicInterface(logicInterface)

    bridge:registerMainThreadFunction("followerChanged", function(posChangeUpdateData)
        posChangeUpdateData.sharedState = playerSapiens:followerUpdated(posChangeUpdateData.uniqueID, posChangeUpdateData.pos, posChangeUpdateData.sharedState, posChangeUpdateData.incomingServerStateDelta)
        sapienMarkersUI:followerChanged(posChangeUpdateData)
    end)
    
    bridge:registerMainThreadFunction("followersPosChanged", function(posChangeUpdateData)
        sapienMarkersUI:bulkFollowerPositionsChanged(posChangeUpdateData)
    end)


    bridge:registerMainThreadFunction("initialFollowersListReceived", function(followerInfos)
        --mj:log("initialFollowersListReceived")
        playerSapiens:initialFollowersListReceived(followerInfos)
        if playerSapiens:hasFollowers() then
            tribeSelectionMarkersUI:disable()
            interestMarkersUI:setHasSelectedTribe(true)
            world:setSunRotationOverride(nil)
            world:queueSaveForMainMenu()
        end
        sapienMarkersUI:followersListChanged(playerSapiens:getFollowerInfos())
        --manageButtonsUI:updateHiddenState()
    end)
    
    bridge:registerMainThreadFunction("followersAdded", function(addedInfos)
        playerSapiens:followersAdded(addedInfos)
        if playerSapiens:hasFollowers() then
            tribeSelectionMarkersUI:disable()
            interestMarkersUI:setHasSelectedTribe(true)
            world:setSunRotationOverride(nil)
        end
        sapienMarkersUI:followersListChanged(playerSapiens:getFollowerInfos())
    end)

    bridge:registerMainThreadFunction("followersRemoved", function(removedIDs)
        playerSapiens:followersRemoved(removedIDs)
        sapienMarkersUI:followersListChanged(playerSapiens:getFollowerInfos())
    end)
    
    bridge:registerMainThreadFunction("skillPriorityListChanged", function()
        playerSapiens:skillPriorityListChanged()
    end)

    
    bridge:registerMainThreadFunction("nonFollowerSapienAdded", function(addedInfo)
        interestMarkersUI:nonFollowerSapienAdded(addedInfo)
    end)
    bridge:registerMainThreadFunction("nonFollowerSapienUpdated", function(updatedInfo)
        interestMarkersUI:nonFollowerSapienUpdated(updatedInfo)
    end)
    bridge:registerMainThreadFunction("nonFollowerSapienRemoved", function(removeInfo)
        interestMarkersUI:nonFollowerSapienRemoved(removeInfo)
    end)
    

    local registeredObjectInfos = {}
    
    bridge:registerMainThreadFunction("registeredObjectServerStateChanged", function(objectInfo)
        if objectInfo.sharedState then
            registeredObjectInfos[objectInfo.uniqueID] = objectInfo.sharedState
        elseif objectInfo.stateDelta then
            objectInfo.sharedState = registeredObjectInfos[objectInfo.uniqueID]
            gameObjectSharedState:mergeDelta(objectInfo, objectInfo.stateDelta)
        end
        local funcsForObject = registeredObjectStateChangeFunctionsByIdAndGroup[objectInfo.uniqueID]
        if funcsForObject then
            for groupID,registeredObjectStateChangeFunctions in pairs(funcsForObject) do 
                registeredObjectStateChangeFunctions.stateChangeFunc(objectInfo)
            end
        end
    end)
    
    bridge:registerMainThreadFunction("registeredVertServerStateChanged", function(vertInfo)
        local funcsForVert = registeredVertStateChangeFunctionsByIdAndGroup[vertInfo.uniqueID]
        if funcsForVert then
            for groupID,registeredVertStateChangeFunction in pairs(funcsForVert) do 
                registeredVertStateChangeFunction(vertInfo)
            end
        end
    end)

    

    bridge:registerMainThreadFunction("addLightForObject", function(addLightData)
        lightManager:addLightForObject(addLightData.uniqueID, addLightData.pos, addLightData.color, addLightData.priority)
    end)

    bridge:registerMainThreadFunction("removeLightForObject", function(uniqueID)
        lightManager:removeLightForObject(uniqueID)
    end)

    bridge:registerMainThreadFunction("addLight", function(addLightData)
        return lightManager:addLight(addLightData.pos, addLightData.color, addLightData.priority)
    end)

    bridge:registerMainThreadFunction("updateLight", function(updateLightData)
        lightManager:updateLight(updateLightData.lightID, updateLightData.pos, updateLightData.color, updateLightData.priority)
    end)

    bridge:registerMainThreadFunction("removeLight", function(lightID)
        lightManager:removeLight(lightID)
    end)

    bridge:registerMainThreadFunction("playWorldSound",function(soundInfo)
        return audio:playWorldSound(soundInfo.name, soundInfo.pos, soundInfo.volume, soundInfo.pitch, soundInfo.priority, soundInfo.maxPlayDistance, soundInfo.completionCallbackID)
    end)

    bridge:registerMainThreadFunction("stopWorldSound",function(soundInfo)
        audio:stopWorldSound(soundInfo.name, soundInfo.channel)
    end)

    bridge:registerMainThreadFunction("playUISound",function(soundInfo)
        audio:playUISound(soundInfo.name, soundInfo.volume, soundInfo.pitch)
    end)

    bridge:registerMainThreadFunction("addLoopingSoundForObject",function(soundInfo)
        audio:addLoopingSoundForObject(soundInfo.uniqueID, soundInfo.name, soundInfo.pos)
    end)
    
    bridge:registerMainThreadFunction("updateLoopingSoundPos",function(soundInfo)
        audio:updateLoopingSoundPos(soundInfo.uniqueID, soundInfo.pos)
    end)

    
    
    bridge:registerMainThreadFunction("updateAmbientSoundInfo",function(ambientSoundInfo)
        audio:updateAmbientInfo(ambientSoundInfo)
    end)

    bridge:registerMainThreadFunction("removeLoopingSoundForObject",function(uniqueID)
        audio:removeLoopingSoundForObject(uniqueID)
    end)

    bridge:registerMainThreadFunction("fadeOutGameMusic",function()
        musicPlayer:fadeOutGameMusic()
    end)
    

    bridge:registerMainThreadFunction("serverPrivateSharedClientStateChanged",function(serverPrivateSharedClientState)
       -- mj:log("privateSharedClientStateChanged:", serverPrivateSharedClientState.tribeID)
        world:serverPrivateSharedClientStateChanged(serverPrivateSharedClientState)
    end)


    bridge:registerMainThreadFunction("validOwnerTribeIDsChanged", function(validOwnerTribeIDs)
        world:validOwnerTribeIDsChanged(validOwnerTribeIDs)
    end)


    bridge:registerMainThreadFunction("updateServerDebugStats", function(statsString)
        debugUI:updateServerDebugStats(statsString)
    end)
    
    
    bridge:registerMainThreadFunction("creationWorldTimeChanged", function(creationWorldTime)
        world:creationWorldTimeChanged(creationWorldTime)
    end)

    bridge:registerMainThreadFunction("resetDueToTribeFail",function(states)
         world:resetDueToTribeFail(states)
         interestMarkersUI:setHasSelectedTribe(false)
    end)
    
    bridge:registerMainThreadFunction("serverWeatherChanged",function(serverWeatherInfo)
        world:serverWeatherChanged(serverWeatherInfo)
    end)

    bridge:registerMainThreadFunction("speedThrottleChanged",function(newIsThrottled)
        world:speedThrottleChanged(newIsThrottled)
    end)
    
    bridge:registerMainThreadFunction("serverDiscoveriesChanged",function(discoveries)
        -- mj:log("privateSharedClientStateChanged:", discoveries)
        world:serverDiscoveriesChanged(discoveries)
    end)
    
    bridge:registerMainThreadFunction("serverCraftableDiscoveriesChanged",function(craftableDiscoveries)
        -- mj:log("privateSharedClientStateChanged:", discoveries)
        world:serverCraftableDiscoveriesChanged(craftableDiscoveries)
    end)

    
    
    bridge:registerMainThreadFunction("serverLogisticsRoutesChanged",function(logisticsRoutes)
         -- mj:log("serverLogisticsRoutesChanged:", logisticsRoutes)
        world:serverLogisticsRoutesChanged(logisticsRoutes)
    end)

    
    bridge:registerMainThreadFunction("serverTribeRelationsSettingsChanged",function(tribeRelationsSettingsInfo)
        --mj:log("serverTribeRelationsSettingsChanged:", tribeRelationsSettingsInfo)
        world:serverTribeRelationsSettingsChanged(tribeRelationsSettingsInfo)
    end)
     
    bridge:registerMainThreadFunction("seenResourceObjectTypesAdded",function(objectTypeIndexes)
        -- mj:log("privateSharedClientStateChanged:", serverPrivateSharedClientState.tribeID)
         world:seenResourceObjectTypesAdded(objectTypeIndexes)
     end)
     
    bridge:registerMainThreadFunction("tutorialStateChanged", function(info)
        tutorialUI:netTutorialStateChanged(info)
    end)

     

    bridge:registerMainThreadFunction("addDestination", function(destinationInfo)
        mainThreadDestination:addDestination(destinationInfo)
    end)

    bridge:registerMainThreadFunction("updateDestinationTribeCenters", function(tribeCentersInfo)
        mainThreadDestination:updateDestinationTribeCenters(tribeCentersInfo)
    end)

    bridge:registerMainThreadFunction("updateDestinationRelationship", function(relationshipInfo)
        mainThreadDestination:updateDestinationRelationship(relationshipInfo)
    end)
    
    bridge:registerMainThreadFunction("updateDestinationTradeables", function(info)
        mainThreadDestination:updateDestinationTradeables(info)
    end)

    bridge:registerMainThreadFunction("updateDestination", function(destinationInfo)
        mainThreadDestination:updateDestination(destinationInfo)
    end)

    bridge:registerMainThreadFunction("updateDestinationPlayerOnlineStatus", function(info)
        mainThreadDestination:updateDestinationPlayerOnlineStatus(info)
    end)
    

    bridge:registerMainThreadFunction("removeDestination", function(destinationInfo)
        mainThreadDestination:removeDestination(destinationInfo)
    end)

    bridge:registerMainThreadFunction("chatMessageReceived", function(messageInfo)
        chatMessageUI:displayMessage(messageInfo)
    end)

    bridge:registerMainThreadFunction("clientStateChange", function(messageInfo)
        chatMessageUI:displayClientStateChange(messageInfo)
    end)
    
    bridge:registerMainThreadFunction("setAnimationIndexForObject", function(animationInfo)
        animationManager:setAnimationIndexForObject(animationInfo.objectID, animationInfo.animationGroupIndex, animationInfo.animationTypeIndex, animationInfo.speedMultiplier)
    end)

    
    bridge:registerMainThreadFunction("removeAnimationObject", function(uniqueID)
        animationManager:removeAnimationObject(uniqueID)
    end)

    bridge:registerMainThreadFunction("setObjectHeadRotation", function(userData)
        animationManager:updateHeadRotation(userData.uniqueID, userData.rotationMatrix, userData.rate)
    end)
    
    bridge:registerMainThreadFunction("playSapienTalkAnimation", function(userData)
        animationManager:playSapienTalkAnimation(userData.uniqueID, userData.phraseDuration)
    end)

    bridge:registerMainThreadFunction("addPlanInfo", function(planInfo)
        planMarkersUI:addPlan(planInfo)
    end)
    bridge:registerMainThreadFunction("updatePlanInfo", function(planInfo)
        planMarkersUI:updatePlan(planInfo)
    end)
    bridge:registerMainThreadFunction("removePlanInfo", function(planInfo)
        planMarkersUI:removePlan(planInfo)
    end)

    
    bridge:registerMainThreadFunction("orderCountsChanged", function(userData)
        world:orderCountsChanged(userData.currentOrderCount, userData.maxOrderCount)
    end)

    bridge:registerMainThreadFunction("objectWasUnloaded", function(objectID)
        local funcsForObject = registeredObjectStateChangeFunctionsByIdAndGroup[objectID]
        if funcsForObject then
            for groupID,registeredObjectStateChangeFunctions in pairs(funcsForObject) do 
                registeredObjectStateChangeFunctions.removalFunc(objectID)
            end
            registeredObjectStateChangeFunctionsByIdAndGroup[objectID] = nil
            bridge:callLogicThreadFunction("deregisterServerStateChangeMainThreadNotificationsForObjects", {objectID})
        end
    end)

    
    bridge:registerMainThreadFunction("displayUINotification", function(notificationInfo)
        --mj:log("displayUINotification:", notificationInfo)
        if notification.types[notificationInfo.notificationTypeIndex].supressedByDefault then --todo user settings for supressing notifications
            return
        end
        if notificationInfo.notificationTypeIndex == notification.types.discovery.index then
            notificationsUI:displayNotification(notificationInfo)
            discoveryUI:show(notificationInfo.userData.researchTypeIndex, notificationInfo.userData.discoveryCraftableTypeIndex)
            tutorialUI:researchCompleted(notificationInfo.userData.researchTypeIndex)
        else
            notificationsUI:displayNotification(notificationInfo)
        end
        tribeNotificationsUI:updateDataDueToNewNotificationsIfVisible()
    end)

    
    bridge:registerMainThreadFunction("tribeFirstMetNotification", function(notificationInfo)
        local destinationState = notificationInfo.userData.destinationState
        local tribeSapienInfos = notificationInfo.userData.tribeSapienInfos
        mainThreadDestination:updateDestination(destinationState)
        notificationsUI:displayNotification(notificationInfo)
        tribeRelationsUI:show(destinationState, tribeSapienInfos, notificationInfo.userData.name, notification:getObjectInfo(notificationInfo), true)
        --[[

        serverGOM:sendNotificationForObject(instigatorSapien, notification.types.tribeFirstMet.index, {
            otherSapienID = orderObjectSapien.uniqueID,
            destinationState = destinationState,
        }, instigatorTribeID)
        ]]
        --world:setPathDebugConnections(debugConnections)
    end)

    
    
    
    bridge:registerMainThreadFunction("setPathDebugConnections", function(debugConnections)
        world:setPathDebugConnections(debugConnections)
    end)
    
    bridge:registerMainThreadFunction("setPathDebugPath", function(debugConnections)
        world:setPathDebugPath(debugConnections)
    end)

    
    bridge:registerMainThreadFunction("setDebugAnchors", function(debugAnchors)
        interestMarkersUI:setDebugAnchors(debugAnchors)
    end)

    bridge:registerMainThreadFunction("playerTemperatureZoneChanged", function(newTemperatureZoneIndex)
        world:playerTemperatureZoneChanged(newTemperatureZoneIndex)
    end)

    bridge:registerMainThreadFunction("playerWeatherChanged", function(weatherInfo)
        world:playerWeatherChanged(weatherInfo)
    end)

    

end


function logicInterface:registerFunctionForObjectStateChanges(objectIDs, registrationGroupID, stateChangeFunc, removalFunc)
    for i, objectID in ipairs(objectIDs) do
        local funcsForObject = registeredObjectStateChangeFunctionsByIdAndGroup[objectID]
        if not funcsForObject then 
            funcsForObject = {}
            registeredObjectStateChangeFunctionsByIdAndGroup[objectID] = funcsForObject
        end

        funcsForObject[registrationGroupID] = {
            stateChangeFunc = stateChangeFunc,
            removalFunc = removalFunc
        }
    end

    bridge:callLogicThreadFunction("registerServerStateChangeMainThreadNotificationsForObjects", objectIDs)
end

function logicInterface:deregisterFunctionForObjectStateChanges(objectIDs, registrationGroupID)
    local objectIdsWithNoCallbacks = {}
    for i, objectID in ipairs(objectIDs) do
        local funcsForObject = registeredObjectStateChangeFunctionsByIdAndGroup[objectID]
        if funcsForObject then 
            funcsForObject[registrationGroupID] = nil
            if not next(funcsForObject) then
                table.insert(objectIdsWithNoCallbacks, objectID)
            end
        end
    end

    bridge:callLogicThreadFunction("deregisterServerStateChangeMainThreadNotificationsForObjects", objectIdsWithNoCallbacks)
end


function logicInterface:registerFunctionForVertStateChanges(vertIDs, registrationGroupID, func)
    for i, vertID in ipairs(vertIDs) do
        local funcsForVert = registeredVertStateChangeFunctionsByIdAndGroup[vertID]
        if not funcsForVert then 
            funcsForVert = {}
            registeredVertStateChangeFunctionsByIdAndGroup[vertID] = funcsForVert
        end

        funcsForVert[registrationGroupID] = func
    end
    --mj:log("logic interface reg:", vertIDs)
    bridge:callLogicThreadFunction("registerServerStateChangeMainThreadNotificationsForVerts", vertIDs)
end

function logicInterface:deregisterFunctionForVertStateChanges(vertIDs, registrationGroupID)
    local vertIdsWithNoCallbacks = {}
    for i, vertID in ipairs(vertIDs) do
        local funcsForVert = registeredVertStateChangeFunctionsByIdAndGroup[vertID]
        if funcsForVert then 
            funcsForVert[registrationGroupID] = nil
        end
        if not next(funcsForVert) then
            table.insert(vertIdsWithNoCallbacks, vertID)
        end
    end

    bridge:callLogicThreadFunction("deregisterServerStateChangeMainThreadNotificationsForVerts", vertIdsWithNoCallbacks)
end

function logicInterface:callLogicThreadFunction(functionName, userData, callback)
    bridge:callLogicThreadFunction(functionName, userData, callback)
end

function logicInterface:rayTest(rayStart, rayEnd, physicsSetIndexOrNil, callback)
    bridge:callLogicThreadFunction("rayTest", {
        rayStart = rayStart,
        rayEnd = rayEnd,
        physicsSetIndexOrNil = physicsSetIndexOrNil,
    }, callback)
end


function logicInterface:createLogisticsRoute(fromStorageAreaObjectID, toStorageAreaObjectID, callbackFunction)
    local routeIDCounter = 1
    local savedRoutesInfoOld = world:getLogisticsRoutes()
    if savedRoutesInfoOld then
        routeIDCounter = (savedRoutesInfoOld.routeIDCounter or 0) + 1
    end

    local creationInfo = {
        fromStorageAreaObjectID = fromStorageAreaObjectID,
        toStorageAreaObjectID = toStorageAreaObjectID,
    }
    logicInterface:callServerFunction("createLogisticsRoute", creationInfo, function(result)
        if result.success then
            routeIDCounter = result.routeID
            --mj:log("got result:", result)
            
            local savedRoutesInfo = world:getLogisticsRoutes()
            if not savedRoutesInfo.routes then 
                savedRoutesInfo.routes = {}
            end
            local routeInfo = result.routeInfo
            savedRoutesInfo.routes[result.routeID] = routeInfo
            savedRoutesInfo.routeIDCounter = routeIDCounter
            
            local uiRouteInfo = {
                routeID = result.routeID,
                to = toStorageAreaObjectID,
                from = fromStorageAreaObjectID,
                fromPos = routeInfo.fromPos,
                toPos = routeInfo.toPos,
            }

            callbackFunction(uiRouteInfo)
        else
            callbackFunction(nil)
        end
    end)
end

function logicInterface:callServerFunction(functionName, userData, callback)
    bridge:callServerFunction(functionName, userData, callback)
end

function logicInterface:ready()
    return bridge ~= nil and world ~= nil
end

return logicInterface