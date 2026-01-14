local clientGameSettings = {
    values = {}
}

local defaults = {
    joinWorldIP = "127.0.0.1",
    joinWorldPort = "16161",
    allowLanConnections = false,
    chatNotifications = "enabled", -- enabled, disabled or messagesOnly

    pauseOnLostFocus = false, -- when app loses focus, whether to pause the game.
    inactivityPauseDelay = 10, --after this many minutes without text/mouse/controller input, the game will auto pause. >= 31 minutes is treated as disabled.

    multiSamplingEnabled = true,
    brightness = 50, -- 1 to 100
    renderDistance = 4, -- UI allows from 1 to 14, it's clamped to 15 in the engine, and that would use a lot of RAM, probably crash or be very slow.
    grassDistance = 3, --also 1 to 10, clamped to 15. Higher values cause lots of CPU usage in the logic thread when moving around which can cause issues, and will also have some impact on GPU
    grassDensity = 3, -- 1 to 10, 10 is 4x 5, 1 is 0.25x
    animatedObjectsCount = 5, -- 1 to 10, clamped to these values, then mapped to a range which is hard coded in the engine, probably between 32 to 512
    ssao = true,
    bloomEnabled = true,
    highQualityWater = true,
    
    mouseSensitivity = 0.3,
    mouseZoomSensitivity = 0.5,
    invertMouseLookY = false,
    invertMouseLookX = false,
    invertMouseWheelZoom = false,
    controllerLookSensitivity = 0.3,
    controllerZoomSensitivity = 0.5,
    invertControllerLookY = false,
    enableDoubleTapForFastMovement = true,
    reticleType = "dot",
    reticleSize = 0.5,

    musicVolume = 1.0,
    soundVolume = 1.0,

    multiSelectMode = 2,
    enableTutorialForNewWorlds = true,
    renderDebug = false,
    uiScale = 1.0,

    skipIntro = false,

    statsGraphSelectionIndexA = 0,
    statsGraphSelectionIndexB = 0,
    statsGraphSelectionIndexC = 0,
    statsGraphSelectionIndexD = 0,
    statsGraphSelectionIndexE = 0,
    statsGraphSelectionIndexF = 0,

    statsZoomStartFraction = 0,

    modDevelopment_replaceDescription = true,

    pointAndClickCameraEnabled = false,
    contourAlpha = 0.5,
}

local appDatabase = nil

local observers = {}

function clientGameSettings:load(appDatabase_)
    appDatabase = appDatabase_
    local storedValues = appDatabase:dataForKey("clientGameSettings")
    
    if storedValues then
        for k,storedValue in pairs(storedValues) do
            clientGameSettings.values[k] = storedValue
        end
    end

    if not appDatabase:dataForKey("installedAfter_0_6") then
        defaults.pointAndClickCameraEnabled = true --Now defaults to false. The default was point and click < 0.6, so lets try to keep it that way for older installs.
    end

    --mj:log("clientGameSettings:", storedValues)
    
    for k,default in pairs(defaults) do
        if clientGameSettings.values[k] == nil then
            clientGameSettings.values[k] = default
        end
    end
    
end

function clientGameSettings:changeSetting(key, value)
    --mj:log("clientGameSettings:changeSetting:", key, ": ", value)
    clientGameSettings.values[key] = value
    appDatabase:setDataForKey(clientGameSettings.values, "clientGameSettings")

    if observers[key] then
        for i,func in ipairs(observers[key]) do
            func(value)
        end
    end
end

function setPref(key, value)
    clientGameSettings:changeSetting(key, value)
end

function clientGameSettings:getSetting(key)
    return clientGameSettings.values[key]
end

function clientGameSettings:addObserver(name, func)
    if not observers[name] then
        observers[name] = {}
    end
    table.insert(observers[name], func)
end

clientGameSettings.defaults = defaults


return clientGameSettings