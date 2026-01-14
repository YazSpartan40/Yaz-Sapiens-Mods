local typeMaps = mjrequire "common/typeMaps"

local notificationSound = {}

local filesDirRelativePath = "audio/sounds/events/"

notificationSound.types = typeMaps:createMap("notificationSound", {
    {
        key = "notification",
        path = "notification2.wav",
    },
    {
        key = "notificationPositive",
        path = "recruit1.wav",
    },
    {
        key = "research",
        path = "research1.wav",
    },
    {
        key = "sadWarning",
        path = "sad1.wav",
    },
    {
        key = "sadEvent",
        path = "sad2.wav",
    },
    {
        key = "threat",
        path = "threat1.wav",
    },
    {
        key = "threatDiscovery",
        path = "threatDiscovery1.wav",
    },
    {
        key = "agedUp1",
        path = "agedUp1.wav",
    },
    {
        key = "agedUp2",
        path = "agedUp2.wav",
    },
    {
        key = "researchNearlyDone",
        path = "growth1.mp3",
    },
    {
        key = "babyBorn",
        path = "babyBorn.wav",
    },
    {
        key = "babyGrew",
        path = "babyGrew.wav",
    },
    {
        key = "notificationBad",
        path = "notificationBad.wav",
    },
    {
        key = "conflict",
        path = "conflict1.wav",
    },
})


function notificationSound:getPath(notificationSoundTypeIndex)
    return filesDirRelativePath .. notificationSound.types[notificationSoundTypeIndex].path
end

function notificationSound:getRepeatPath(notificationSoundTypeIndex)
    return filesDirRelativePath .. "repeatedNotification.wav"
end

return notificationSound