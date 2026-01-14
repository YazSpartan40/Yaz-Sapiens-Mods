local mjm = mjrequire "common/mjm"
local clamp = mjm.clamp


local weather = mjrequire "common/weather"
local gameConstants = mjrequire "common/gameConstants"
local rng = mjrequire "common/randomNumberGenerator"
local constructable = mjrequire "common/constructable"
local objectInventory = mjrequire "common/objectInventory"
local plan = mjrequire "common/plan"
local notification = mjrequire "common/notification"
local gameObject = mjrequire "common/gameObject"

local serverWeather = {}

local server = nil
local serverWorld = nil
local worldDatabase = nil
local serverGOM = nil
local planManager = nil
local serverStorageArea = nil
local serverFlora = nil

local currentWindstormEventInfo = nil

local peakStartTimeAndRampDuration = gameConstants.windStormDuration * 0.5 - gameConstants.windStormPeakDuration * 0.5
local peakEndTime = peakStartTimeAndRampDuration + gameConstants.windStormPeakDuration

function serverWeather:getInfoForSendToClients()
    local result = {}

    if currentWindstormEventInfo then
        result["windStormEvent"] = currentWindstormEventInfo
    end

    return result
end

function serverWeather:updateWeatherAndSendInfoToAllClients()
    local weatherInfo = serverWeather:getInfoForSendToClients()
    weather:setServerWeatherInfo(weatherInfo)
    server:callClientFunctionForAllClients("serverWeatherChanged", weatherInfo)
end

function serverWeather:startSevereWeatherEvent()
    if not currentWindstormEventInfo then
        currentWindstormEventInfo = {
            startTime = serverWorld:getWorldTime()
        }
        worldDatabase:setDataForKey(currentWindstormEventInfo, "windStormEvent")
        serverWeather:updateWeatherAndSendInfoToAllClients()
    end
end

local weatherDestructionTypes = mj:enum {
    "wind",
    "rain"
}

function serverWeather:destroyConstructedObject(object, weatherDestructionType)
    --mj:log("weather destruction for object:", object.uniqueID)
    local sharedState = object.sharedState
    local constructableTypeIndex = sharedState.inProgressConstructableTypeIndex
            
    local coveredTestPassed = false
    if not constructableTypeIndex then
        constructableTypeIndex = sharedState.constructionConstructableTypeIndex
        if constructableTypeIndex then
            local constructableType = constructable.types[constructableTypeIndex]
            if constructableType.buildSequence then
                local covered = serverGOM:doCoveredTestForObject(object)
                if not covered then
                    --mj:log("weather destruction, calling convertFinalBuildObjectToInProgressForDeconstruction")
                    serverGOM:convertFinalBuildObjectToInProgressForDeconstruction(object, sharedState.tribeID)
                    coveredTestPassed = true
                else
                    constructableTypeIndex = nil
                end
            else
                constructableTypeIndex = nil
            end
        end
    end

    if constructableTypeIndex and sharedState.inventories then
        local inventoryLocation = objectInventory.locations.inUseResource.index
        local inventory = sharedState.inventories[inventoryLocation]
        if inventory then
            local inventoryObjects = sharedState.inventories[inventoryLocation].objects
            if inventoryObjects and #inventoryObjects > 0 then
                if not coveredTestPassed then
                    local covered = serverGOM:doCoveredTestForObject(object)
                    coveredTestPassed = not covered
                end 
                if coveredTestPassed then
                    local lastObjectTypeIndex = inventoryObjects[#inventoryObjects].objectTypeIndex

                    serverGOM:removeObjectFromInProgressBuildObjectWithObjectTypeIndex(object.uniqueID, lastObjectTypeIndex, inventoryLocation)

                    local constructableType = constructable.types[constructableTypeIndex]
                    local newBuildSequenceIndex = nil
                    for buildSequenceIndex = #constructableType.buildSequence,1,-1 do
                        local constructableSequenceTypeIndex = constructableType.buildSequence[buildSequenceIndex].constructableSequenceTypeIndex
                        if constructableSequenceTypeIndex == constructable.sequenceTypes.bringResources.index then
                            newBuildSequenceIndex = buildSequenceIndex
                            break
                        end
                    end

                    if newBuildSequenceIndex then
                        sharedState:set("buildSequenceIndex", newBuildSequenceIndex)
                    end

                    local planState = planManager:getPlanStateForObject(object, plan.types.build.index, nil, nil, sharedState.tribeID, nil)

                    if planState then
                        serverGOM:updatePlanDueToBuildOrCraftChange(object, constructableType, planState)
                    else
                        planState = planManager:getPlanStateForObject(object, plan.types.deconstruct.index, nil, nil, sharedState.tribeID, nil)
                        if not planState then
                            planState = planManager:getPlanStateForObject(object, plan.types.rebuild.index, nil, nil, sharedState.tribeID, nil)
                            if not planState then
                                planManager:reAddBuildOrPlantPlan(sharedState.tribeID, plan.types.build.index, object.uniqueID)
                            end
                        end
                    end
                    
                    local notificationTypeIndex = notification.types.windDestruction.index
                    if weatherDestructionType == weatherDestructionTypes.rain then
                        notificationTypeIndex = notification.types.rainDestruction.index
                    end
                    serverGOM:sendNotificationForObject(object, notificationTypeIndex, {
                        name = sharedState.name,
                        objectTypeIndex = object.objectTypeIndex,
                    }, sharedState.tribeID)
                end
            end
        end
    end
end

local previousDestructionCheckWorldTime = nil

local windAffectedCallbackChances = {
    gameConstants.windAffectedCallbackLowChancePerSecond,
    gameConstants.windAffectedCallbackModerateChancePerSecond,
    gameConstants.windAffectedCallbackHighChancePerSecond
}

local rainAffectedCallbackChances = {
    gameConstants.rainAffectedCallbackLowChancePerSecond,
}

local windDamageCounterAccumulations = {}
local windDamageCounterRandomValues = {}

local rainDamageCounterAccumulations = {}
local rainDamageCounterRandomValues = {}


local windStormIsPeaking = false

local function doWindDamage(object, chanceSet)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if gameObjectType.isStorageArea then
        local windDirection = serverWorld:getWindDirection(object.normalizedPos)
        local blowAwayCount = 4
        if chanceSet == serverGOM.objectSets.windAffectedLowChance then
            blowAwayCount = 2
        end
        serverStorageArea:blowAwayItems(object, windDirection, blowAwayCount)
    elseif gameObjectType.floraTypeIndex then
        serverFlora:dropItemsDueToWind(object)
    elseif gameObjectType.windDestructableHighChance or gameObjectType.windDestructableModerateChance or gameObjectType.windDestructableLowChance then
        serverWeather:destroyConstructedObject(object, weatherDestructionTypes.wind)
    end
end


local function doRainDamage(object, chanceSet)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if gameObjectType.rainDestructableLowChance then
        local rainfallValues = object.privateState.cachedRainfallValues
        local currentRainfall = weather:getRainfall(rainfallValues, object.normalizedPos, serverWorld:getWorldTime(), serverWorld.yearSpeed)
        local rainSnow = weather:getRainSnowCombinedPrecipitation(currentRainfall)

        --mj:log("doRainDamage rainSnow:", rainSnow)
        if rainSnow > 0.5 then
            local snowFraction = weather:getSnowFraction(object.normalizedPos, serverWorld:getWorldTime(), serverWorld.yearSpeed, serverWorld:getTimeOfDayFraction(object.normalizedPos))
            --mj:log("doRainDamage snowFraction:", snowFraction)
            if snowFraction < 0.5 then
                serverWeather:destroyConstructedObject(object, weatherDestructionTypes.rain)
            end
        end
    end
end

function serverWeather:stopWindstorm() --note, you may also want to call serverWeather:updateWeatherAndSendInfoToAllClients() after this
    currentWindstormEventInfo = nil
    worldDatabase:removeDataForKey("windStormEvent")
    windStormIsPeaking = false
end

function serverWeather:update(worldTime)
    --mj:log("serverWeather:update")
    local eventChanged = false
    local timeElapsed = nil

    local isChanceOfHeavyRain = weather:getCurrentGlobalChanceOfRain() > 0.5
    
    if gameConstants.debugConstantWindStorm and (not currentWindstormEventInfo) then
        serverWeather:startSevereWeatherEvent()
    end
    
    if currentWindstormEventInfo or isChanceOfHeavyRain then
        if previousDestructionCheckWorldTime then
            timeElapsed = worldTime - previousDestructionCheckWorldTime
            timeElapsed = clamp(timeElapsed, 0.0, 20.0)
        end
        previousDestructionCheckWorldTime = worldTime
    else
        previousDestructionCheckWorldTime = nil
    end

    if timeElapsed then
        if currentWindstormEventInfo then
            local timeSinceWindStormStart = worldTime - currentWindstormEventInfo.startTime
            
            if timeSinceWindStormStart > gameConstants.windStormDuration then
                serverWeather:stopWindstorm()
                eventChanged = true
            else
            -- mj:log("wind storm active")
                if timeSinceWindStormStart > peakStartTimeAndRampDuration and timeSinceWindStormStart < peakEndTime then
                    windStormIsPeaking = true
                    --mj:log("wind storm peak active")

                    for i,damageSet in ipairs(serverWeather.windDamageLevelSets) do
                        local damageChanceCount = serverGOM:countOfObjectsInSet(damageSet)
                        if damageChanceCount > 0 then
                            --mj:log("damageChanceCount:", damageChanceCount, " in set:", i)
                            local damageCountPerSecond = damageChanceCount * windAffectedCallbackChances[i]
                            local countAverage = damageCountPerSecond * timeElapsed

                            if not windDamageCounterRandomValues[i] then
                                windDamageCounterRandomValues[i] = rng:randomValue() + 0.5
                            end

                            local randomChance = windDamageCounterRandomValues[i] * countAverage

                            local countToDestroy = windDamageCounterAccumulations[i] + randomChance
                            while countToDestroy > 1.0 do
                                countToDestroy = countToDestroy - 1.0
                                local objectID = serverGOM:getRandomGameObjectInSet(damageSet)
                                local object = serverGOM:getObjectWithID(objectID)
                                if object then
                                    doWindDamage(object, damageSet)
                                end
                                windDamageCounterRandomValues[i] = nil
                            end

                            windDamageCounterAccumulations[i] = countToDestroy
                        end
                    end

                else
                    windStormIsPeaking = false
                end
            end
        end
        
        if isChanceOfHeavyRain then
            for i,damageSet in ipairs(serverWeather.rainDamageLevelSets) do
                local damageChanceCount = serverGOM:countOfObjectsInSet(damageSet)
                if damageChanceCount > 0 then
                    --mj:log("rain damageChanceCount:", damageChanceCount, " in set:", i)
                    local damageCountPerSecond = damageChanceCount * rainAffectedCallbackChances[i]
                    local countAverage = damageCountPerSecond * timeElapsed

                    if not rainDamageCounterRandomValues[i] then
                        rainDamageCounterRandomValues[i] = rng:randomValue() + 0.5
                    end

                    local randomChance = rainDamageCounterRandomValues[i] * countAverage

                    local countToDestroy = rainDamageCounterAccumulations[i] + randomChance
                    while countToDestroy > 1.0 do
                        countToDestroy = countToDestroy - 1.0
                        local objectID = serverGOM:getRandomGameObjectInSet(damageSet)
                        local object = serverGOM:getObjectWithID(objectID)
                        if object then
                            doRainDamage(object, damageSet)
                        end
                        rainDamageCounterRandomValues[i] = nil
                    end

                    rainDamageCounterAccumulations[i] = countToDestroy
                end
            end
        end
    end


    if eventChanged then
        serverWeather:updateWeatherAndSendInfoToAllClients()
    end
end

function serverWeather:getIsDamagingWindStormOccuring()
    return windStormIsPeaking
end

function serverWeather:clientConnected(clientID)
    local weatherInfo = serverWeather:getInfoForSendToClients()
    if next(weatherInfo) then
        server:callClientFunction(
		"serverWeatherChanged",
		clientID,
		weatherInfo
	)
    end
end

function serverWeather:init(server_, serverWorld_, serverGOM_, planManager_, serverStorageArea_, serverFlora_)
    server = server_
    serverWorld = serverWorld_
    serverGOM = serverGOM_
    worldDatabase = serverWorld.worldDatabase
    planManager = planManager_
    serverStorageArea = serverStorageArea_
    serverFlora = serverFlora_

    --weather:setServerWindStormStrength(serverWindStormStrength_)

    serverWeather.windDamageLevelSets = {
        serverGOM.objectSets.windAffectedLowChance,
        serverGOM.objectSets.windAffectedModerateChance,
        serverGOM.objectSets.windAffectedHighChance
    }
    
    serverWeather.rainDamageLevelSets = {
        serverGOM.objectSets.rainAffectedLowChance,
    }
    
    for i=1,#serverWeather.windDamageLevelSets do
        windDamageCounterAccumulations[i] = 0.0
    end
    for i=1,#serverWeather.rainDamageLevelSets do
        rainDamageCounterAccumulations[i] = 0.0
    end

    currentWindstormEventInfo = worldDatabase:dataForKey("windStormEvent")
    
    local weatherInfo = serverWeather:getInfoForSendToClients()
    weather:setServerWeatherInfo(weatherInfo)
end

return serverWeather