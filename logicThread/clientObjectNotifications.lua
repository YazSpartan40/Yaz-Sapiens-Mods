
local notification = mjrequire "common/notification"

local logicAudio = mjrequire "logicThread/logicAudio"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local clientDestination = mjrequire "logicThread/clientDestination"

local vocal = mjrequire "common/vocal"
--local sapienConstants = mjrequire "common/sapienConstants"
local rng = mjrequire "common/randomNumberGenerator"

local clientObjectNotifications = {
    queuedNotificationsWaitingForObjectUpdates = {}
}

local clientGOM = nil
local logic = nil


local playTimesByVoiceTypeAndVocalType = {}
local maxVocalDistance2 = mj:mToP(20.0) * mj:mToP(20.0)

local function socialNotificationFunction(notificationInfo)
    local vocalTypeIndex = notificationInfo.userData.vocalTypeIndex
    local voiceTypeIndex = notificationInfo.userData.voiceTypeIndex

    if vocalTypeIndex and voiceTypeIndex then
        local playTimesByVocalType = playTimesByVoiceTypeAndVocalType[voiceTypeIndex]
        if not playTimesByVocalType then
            playTimesByVocalType = {}
            playTimesByVoiceTypeAndVocalType[voiceTypeIndex] = playTimesByVocalType
        end

        local currentTime = logic.worldTime
        local lastPlayTime = playTimesByVocalType[vocalTypeIndex]

        if (not lastPlayTime) or ((currentTime - lastPlayTime) > 5.0) then
            local skipPlay = false
            if logic.speedMultiplier > 1.1 then
                skipPlay = rng:randomInteger(math.floor(logic.speedMultiplier + 0.1)) ~= 0 --aim to play the same quantity of sounds when in fast forward too, not 10x the ammount
            end
            if not skipPlay then
                local soundFileName = vocal:getPath(voiceTypeIndex, vocalTypeIndex)
                if soundFileName then
                    local pitch = 0.85 + rng:valueForUniqueID(notificationInfo.objectSaveData.uniqueID, 932) * 0.15
                    local soundPlayed = logicAudio:playWorldSound(soundFileName, notificationInfo.objectSaveData.pos, nil, pitch, nil, maxVocalDistance2)

                    if soundPlayed then
                        logic:callMainThreadFunction("playSapienTalkAnimation", {
                            uniqueID = notificationInfo.objectSaveData.uniqueID,
                            phraseDuration = 1.5,
                        })
                    end
                end
            end

            playTimesByVocalType[vocalTypeIndex] = currentTime
        end

    end
end

local function toolBrokeNotificationFunction(notificationInfo)
    logicAudio:playWorldSound("audio/sounds/rockBreak.wav", notificationInfo.userData.pos)
end

local function fireLitNotificationFunction(notificationInfo)
    logicAudio:playWorldSound("audio/sounds/fireLight1.wav", notificationInfo.userData.pos)
end

local function reloadModelFunction(notificationInfo)
    --mj:log("reloadModelFunction:", notificationInfo)
    clientGOM:reloadModelIfNeededForObject(notificationInfo.objectSaveData.uniqueID)
end

local function tribeFirstMetNotificationFunction(notificationInfo)
    clientDestination:updateDestination(notificationInfo.userData.destinationState)
    logic:callMainThreadFunction("tribeFirstMetNotification", notificationInfo)

    --[[
    serverGOM:sendNotificationForObject(instigatorSapien, notification.types.tribeFirstMet.index, {
        otherSapienID = orderObjectSapien.uniqueID,
        destinationState = destinationState,
    }, instigatorTribeID)]]
end

local function displayNotificationFunction(notificationInfo)
   -- mj:log("displayNotificationFunction:", sapien.uniqueID, " notificationInfo:", notificationInfo)
        --mj:log("call main thread displayUINotification:", notificationInfo.userData)
    --[[local objectInfo = {
        uniqueID = sapien.uniqueID,
        objectTypeIndex = sapien.objectTypeIndex,
        sharedState = sharedState,
        pos = sapien.pos,
    }]]
    --[[if notificationInfo.notificationTypeIndex == notification.types.newTribeSeen.index then
        local userData = notificationInfo.userData
        objectInfo.uniqueID = userData.otherSapienID
        objectInfo.sharedState = userData.otherSapienSharedState
        objectInfo.pos = userData.otherSapienPos
    end]]
    logic:callMainThreadFunction("displayUINotification", notificationInfo)
end

local function reloadModelAndDisplayNotificationFunction(notificationInfo)
    reloadModelFunction(notificationInfo)
    displayNotificationFunction(notificationInfo)
end

--[[local function displayLeaversNotifcationFunction(sapien, notificationInfo)
    local allSapienIDs = notificationInfo.userData.allSapienIDs
    --mj:log("sapien:", sapien)
    displayNotificationFunction(sapien, notificationInfo)
    for i,sapienID in ipairs(allSapienIDs) do
        if sapienID ~= sapien.uniqueID then
            local followerInfo = clientSapien:getFollowerInfoIncludingRemoved(sapienID)
            if followerInfo then
                --mj:log("followerInfo:", followerInfo)
                displayNotificationFunction(followerInfo, notificationInfo)
            end
        end
    end
end]]


local function destructionFunction(notificationInfo)
    displayNotificationFunction(notificationInfo)
    local pos = notificationInfo.objectSaveData.pos
    local rotation = mj:getNorthFacingFlatRotationForPoint(pos)
    particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.destroyLarge, pos, rotation, nil, false)
    logicAudio:playWorldSound("audio/sounds/destruction1.wav", pos)
end

clientObjectNotifications.notificationFunctions = {
    --non sapien
    [notification.types.windDestruction.index] = destructionFunction,
    [notification.types.rainDestruction.index] = destructionFunction,

    --sapien

    [notification.types.toolBroke.index] = toolBrokeNotificationFunction,
    [notification.types.fireLit.index] = fireLitNotificationFunction,

    [notification.types.becamePregnant.index] = reloadModelAndDisplayNotificationFunction,
    [notification.types.babyBorn.index] = reloadModelAndDisplayNotificationFunction,
    [notification.types.agedUp.index] = reloadModelAndDisplayNotificationFunction,

    [notification.types.babyGrew.index] = reloadModelFunction,
    [notification.types.reloadModel.index] = reloadModelFunction,

    [notification.types.social.index] = socialNotificationFunction,

    [notification.types.tribeFirstMet.index] = tribeFirstMetNotificationFunction,
}

for i,notificationType in ipairs(notification.validTypes) do
    if (not clientObjectNotifications.notificationFunctions[notificationType.index]) and notificationType.displayGroupTypeIndex then
        clientObjectNotifications.notificationFunctions[notificationType.index] = displayNotificationFunction
    end
end

function clientObjectNotifications:notificationReceivedFromServer(notificationInfo)
    clientGOM:requestUnloadedStateForNotificationIfNeeded(notificationInfo.objectSaveData.uniqueID)

    local notificationType = notification.types[notificationInfo.notificationTypeIndex]
    if notificationType.requiresObjectModelReload or notificationType.requiresObjectSnapPosition then
        local queuedNotificationsForThisObject = clientObjectNotifications.queuedNotificationsWaitingForObjectUpdates[notificationInfo.objectSaveData.uniqueID]
        if not queuedNotificationsForThisObject then
            queuedNotificationsForThisObject = {}
            clientObjectNotifications.queuedNotificationsWaitingForObjectUpdates[notificationInfo.objectSaveData.uniqueID] = queuedNotificationsForThisObject
        end
        table.insert(queuedNotificationsForThisObject,notificationInfo)
    else
        local notificationFunction = clientObjectNotifications.notificationFunctions[notificationInfo.notificationTypeIndex] 
        if notificationFunction then
            notificationFunction(notificationInfo)
        end
    end
end

function clientObjectNotifications:callAnyNotificationsForObjectUpdate(object)
    local queuedNotificationsForThisObject = clientObjectNotifications.queuedNotificationsWaitingForObjectUpdates[object.uniqueID]
    if queuedNotificationsForThisObject then
        for i,notificationInfo in ipairs(queuedNotificationsForThisObject) do
            local notificationFunction = clientObjectNotifications.notificationFunctions[notificationInfo.notificationTypeIndex]
            if notificationFunction then
                notificationFunction(notificationInfo)
            end
        end
        clientObjectNotifications.queuedNotificationsWaitingForObjectUpdates[object.uniqueID] = nil
    end
end

function clientObjectNotifications:init(logic_, clientGOM_)
    logic = logic_
    clientGOM = clientGOM_
end



return clientObjectNotifications