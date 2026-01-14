

local rng = mjrequire "common/randomNumberGenerator"
local mjm = mjrequire "common/mjm"
local clamp = mjm.clamp
--local normalize = mjm.normalize
--local length2 = mjm.length2

local serverWorldSettings = mjrequire "server/serverWorldSettings"

local serverStoryEvents = {}

--local infrequentUpdateTimer = 0.0
--local infrequentUpdateRandomWait = 1.0

local serverWorld = nil
--local serverGOM = nil
local serverTribe = nil
local serverDestination = nil
local serverNomadTribe = nil
local serverMobGroup = nil
local serverWeather = nil
--local terrain = nil
local perTribeEventsDatabase = nil
local globalEventsDatabase = nil

local perTribeRetryInfos = {}
local globalRetryInfos = {}
local loadedTribes = {}


--default day length is 2880, year length is 23040
local perTribeTimerTypes = {
    spawnNomadTribe = {
       -- minTime = 180, --constant nomads for testing
       -- maxTime = 200,
        minTime = (2880 - 2880 * 0.5),
        maxTime = (2880 - 2880 * 0.5),
        retryCount = 16,
        func = function(storyTribeID)
            return serverNomadTribe:spawnNomadTribe(storyTribeID)
        end,
        nextTimeOverrideFunction = function(timerTypeInfo, worldTime, storyTribeID)
            local followerCount = serverTribe:getPopulation(storyTribeID)
            local timeMultiplier = clamp(0.6 + 0.01 * followerCount, 0.7, 1.0)
            return worldTime + (timerTypeInfo.minTime + (timerTypeInfo.maxTime - timerTypeInfo.minTime) * rng:randomValue()) * timeMultiplier
        end
    },
    spawnMobsGroup = {
        minTime = 240,
        maxTime = 480,
        func = function(storyTribeID)
            return serverMobGroup:spawnMigratingMobGroup(storyTribeID)
        end
    },
    createNearbyTribeIfNeeded = {
        minTime = 23040 * 0.5,
        maxTime = 23040 * 1.5,
        func = function(storyTribeID)
            if serverWorldSettings:get("disableTribeSpawns") then
                return true
            end
            --mj:log("in createNearbyTribeIfNeeded callback")
            local destinationState = serverDestination:getDestinationState(storyTribeID)
            if destinationState and destinationState.tribeCenters and destinationState.tribeCenters[1] then
                --mj:log("calling createTribesIfNeededNearLocation")
                local randomCenterInfo = destinationState.tribeCenters[rng:randomInteger(#destinationState.tribeCenters) + 1]
                serverTribe:createStoryTribesIfNeededNearLocation(randomCenterInfo.normalizedPos)
            end
            return true
        end,
    },
}

local globalTimerTypes = {
    severeWeatherEvent = {
        minTime = 23040 * 0.25,
        maxTime = 23040 * 3.0,
        --minTime = 50,
        --maxTime = 100,
        func = function()
            serverWeather:startSevereWeatherEvent()
            return true
        end
    }
}


function serverStoryEvents:update(dt, worldTime, speedMultiplier)
    --mj:log("serverStoryEvents:update:", retryInfos )
    for timerTypeName,retryInfosByTribe in pairs(perTribeRetryInfos) do
        local timerTypeInfo = perTribeTimerTypes[timerTypeName]
        for tribeID,retryInfo in pairs(retryInfosByTribe) do
            local success = timerTypeInfo.func(tribeID)
            --mj:log("repeat per-tribe story event timer callback of type:", timerTypeName, " result:", success )
            if success then
                retryInfosByTribe[tribeID] = nil
            else
                retryInfo.count = retryInfo.count + 1
                if retryInfo.count >= timerTypeInfo.retryCount then
                    retryInfosByTribe[tribeID] = nil
                end
            end
        end
        if not next(retryInfosByTribe) then
            perTribeRetryInfos[timerTypeName] = nil
        end
    end
    
    for timerTypeName,retryInfo in pairs(globalRetryInfos) do
        local timerTypeInfo = globalTimerTypes[timerTypeName]
        
        local success = timerTypeInfo.func()
        --mj:log("repeat global story event timer callback of type:", timerTypeName, " result:", success )
        if success then
            globalRetryInfos[timerTypeName] = nil
        else
            retryInfo.count = retryInfo.count + 1
            if retryInfo.count >= timerTypeInfo.retryCount then
                globalRetryInfos[timerTypeName] = nil
            end
        end
    end

end

local function getNextCallbackTime(timerTypeInfo, worldTime, storyTribeIDOrNil)
    if timerTypeInfo.nextTimeOverrideFunction then
        return timerTypeInfo.nextTimeOverrideFunction(timerTypeInfo, worldTime, storyTribeIDOrNil)
    else
        return worldTime + timerTypeInfo.minTime + (timerTypeInfo.maxTime - timerTypeInfo.minTime) * rng:randomValue()
    end
end


local function createGlobalEventCallback(callbackTime, timerTypeName)
    local timerTypeInfo = globalTimerTypes[timerTypeName]
    --mj:log("createGlobalEventCallback:", timerTypeName, " time:", callbackTime)
    serverWorld:addCallbackTimerForWorldTime(callbackTime, function()
        
        local callbackTimes = globalEventsDatabase:dataForKey("callbackTimes") or {}
        local worldTime = serverWorld:getWorldTime()
        local nextCallbackTime = getNextCallbackTime(timerTypeInfo, worldTime, nil)

        callbackTimes[timerTypeName] = nextCallbackTime
        globalEventsDatabase:setDataForKey(callbackTimes, "callbackTimes")

        createGlobalEventCallback(nextCallbackTime, timerTypeName)

        local success = timerTypeInfo.func()
        if (not success) and timerTypeInfo.retryCount then
            mj:log("initial global story event timer callback of type:", timerTypeName, " not successful. Adding retry info." )
            local retryInfo = globalRetryInfos[timerTypeName]
            if not retryInfo then
                retryInfo = {}
                globalRetryInfos[timerTypeName] = retryInfo
            end
            retryInfo.count = 0
        end
    end)
end

local function loadGlobalEvents()
    local callbackTimes = globalEventsDatabase:dataForKey("callbackTimes") or {}
    
    local worldTime = serverWorld:getWorldTime()
    
    local needsSave = false
    for timerTypeName,timerTypeInfo in pairs(globalTimerTypes) do
        local callbackTime = callbackTimes[timerTypeName]
        if not callbackTime then
            callbackTime = getNextCallbackTime(timerTypeInfo, worldTime, nil)
            callbackTimes[timerTypeName] = callbackTime
            needsSave = true
        end

        mj:log("global story callback:", timerTypeName, " triggers in " .. math.floor(callbackTime - worldTime) .. " seconds")

        createGlobalEventCallback(callbackTime, timerTypeName)
    end
    if needsSave then
        globalEventsDatabase:setDataForKey(callbackTimes, "callbackTimes")
    end
end


local function createTribeEventCallback(tribeID, callbackTime, timerTypeName)
    local timerTypeInfo = perTribeTimerTypes[timerTypeName]
    --mj:log("createCallback:", timerTypeName, " time:", callbackTime)
    serverWorld:addCallbackTimerForWorldTime(callbackTime, function()
        if not loadedTribes[tribeID] then
            return
        end
        --mj:log("tribeEventCallback:", timerTypeName, " time:", callbackTime)
        local tribeStoryStateReloaded = perTribeEventsDatabase:dataForKey(tribeID)
        local callbackTimesReloaded = tribeStoryStateReloaded.callbackTimes
        local worldTimeReloaded = serverWorld:getWorldTime()

        local nextCallbackTime = getNextCallbackTime(timerTypeInfo, worldTimeReloaded, tribeID)

        callbackTimesReloaded[timerTypeName] = nextCallbackTime
        perTribeEventsDatabase:setDataForKey(tribeStoryStateReloaded, tribeID)

        createTribeEventCallback(tribeID, nextCallbackTime, timerTypeName)

        local success = timerTypeInfo.func(tribeID)
        if (not success) and timerTypeInfo.retryCount then
            --mj:log("initial story event timer callback of type:", timerTypeName, " not successful. Adding retry info." )
            local retryInfosByTribe = perTribeRetryInfos[timerTypeName]
            if not retryInfosByTribe then
                retryInfosByTribe = {}
                perTribeRetryInfos[timerTypeName] = retryInfosByTribe
            end
            retryInfosByTribe[tribeID] = {
                count = 0,
            }
        end
    end)
end

local function loadTribe(tribeID, tribeStoryState)

    if loadedTribes[tribeID] then
        mj:warn("tribe already loaded in serverStoryEvents")
        return
    end

    local tribeState = serverTribe:getTribeState(tribeID)
    if tribeState and not tribeState.nomad then
        loadedTribes[tribeID] = true
        local worldTime = serverWorld:getWorldTime()

        local callbackTimes = tribeStoryState.callbackTimes
        if not callbackTimes then
            callbackTimes = {}
            tribeStoryState.callbackTimes = callbackTimes
        end

        local needsSave = false
        for timerTypeName,timerTypeInfo in pairs(perTribeTimerTypes) do
            local callbackTime = callbackTimes[timerTypeName]
            if not callbackTime then
                callbackTime = getNextCallbackTime(timerTypeInfo, worldTime, tribeID)
                callbackTimes[timerTypeName] = callbackTime
                needsSave = true
            end

            mj:log("per-tribe story callback:", timerTypeName, " triggers in " .. math.floor(callbackTime - worldTime) .. " seconds")

            createTribeEventCallback(tribeID, callbackTime, timerTypeName)
        end

        if needsSave then
            perTribeEventsDatabase:setDataForKey(tribeStoryState, tribeID)
        end

    end
end

function serverStoryEvents:connectedClientTribeLoaded(tribeID)
    --mj:log("serverStoryEvents:connectedClientTribeLoaded:", tribeID)
    local tribeStoryState = perTribeEventsDatabase:dataForKey(tribeID) or {}
    loadTribe(tribeID, tribeStoryState)
end

function serverStoryEvents:clientDisconnectedOrFailed(tribeID)
    loadedTribes[tribeID] = nil
    for timerTypeName,retryInfosByTribe in pairs(perTribeRetryInfos) do
        retryInfosByTribe[tribeID] = nil
    end
end

function serverStoryEvents:init(serverWorld_, serverGOM_, serverTribe_, serverNomadTribe_, serverMobGroup_, terrain_, serverWeather_, serverDestination_)
    serverWorld = serverWorld_
    --serverGOM = serverGOM_
    serverTribe = serverTribe_
    serverNomadTribe = serverNomadTribe_
    serverMobGroup = serverMobGroup_
    serverWeather = serverWeather_
    serverDestination = serverDestination_
    --terrain = terrain_
    perTribeEventsDatabase = serverWorld:getDatabase("storyTribeEvents", true)
    globalEventsDatabase = serverWorld:getDatabase("globalEvents", true)

    --[[for tribeID,clientID in pairs(liveTribeList) do
        local tribeStoryState = perTribeEventsDatabase:dataForKey(tribeID) or {}
        loadTribe(tribeID, tribeStoryState)
    end]]

    loadGlobalEvents()
end

return serverStoryEvents