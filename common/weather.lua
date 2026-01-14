
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local dot = mjm.dot
local clamp = mjm.clamp
--local baryFractions = mjm.baryFractions
local locale = mjrequire "common/locale"
local terrain = mjrequire "common/terrain"
local gameConstants = mjrequire "common/gameConstants"

local noise = mjNoise(123, 0.6) --seed, persistance

local temperatureSeasonTimeOffsetNoiseMultiplier = 0.0

local rawMoisture = 0.0 --cloud and rain base
local extraRainOffset = 0.0
local creationWorldTime = 0.0
local rawWindStrength = 0.0

local currentWindstormEventInfo = nil
local serverWindstormStrength = nil

local weather = {}

weather.temperatureZones = mj:indexed {
    {
        key = "veryCold",
        name = locale:get("weather_temperatureZone_veryCold"),
    },
    {
        key = "cold",
        name = locale:get("weather_temperatureZone_cold"),
    },
    {
        key = "moderate",
        name = locale:get("weather_temperatureZone_moderate"),
    },
    {
        key = "hot",
        name = locale:get("weather_temperatureZone_hot"),
    },
    {
        key = "veryHot",
        name = locale:get("weather_temperatureZone_veryHot"),
    },
}

weather.temperatureZones.veryCold.coveredIndex = weather.temperatureZones.cold.index
weather.temperatureZones.cold.coveredIndex = weather.temperatureZones.moderate.index
weather.temperatureZones.moderate.coveredIndex = weather.temperatureZones.moderate.index
weather.temperatureZones.hot.coveredIndex = weather.temperatureZones.moderate.index
weather.temperatureZones.veryHot.coveredIndex = weather.temperatureZones.hot.index

function weather:setCreationWorldTime(creationWorldTime_)
    creationWorldTime = creationWorldTime_
    --mj:log("weather:setCreationWorldTime:", creationWorldTime)
end

function weather:getTemperatureZones(biomeTags)
    local values = {weather.temperatureZones.moderate.index,weather.temperatureZones.moderate.index}

    if biomeTags.temperatureSummerVeryHot then
        values[1] = weather.temperatureZones.veryHot.index
    elseif biomeTags.temperatureSummerHot then
        values[1] = weather.temperatureZones.hot.index
    elseif biomeTags.temperatureSummerCold then
        values[1] = weather.temperatureZones.cold.index
    elseif biomeTags.temperatureSummerVeryCold then
        values[1] = weather.temperatureZones.veryCold.index
    end
    
    if biomeTags.temperatureWinterVeryHot then
        values[2] = weather.temperatureZones.veryHot.index
    elseif biomeTags.temperatureWinterHot then
        values[2] = weather.temperatureZones.hot.index
    elseif biomeTags.temperatureWinterCold then
        values[2] = weather.temperatureZones.cold.index
    elseif biomeTags.temperatureWinterVeryCold then
        values[2] = weather.temperatureZones.veryCold.index
    end

    return values
end

local function getSeasonFraction(worldTime, yearSpeed, isSouthHemisphere) -- 0.0 is spring, 0.25 summer, 0.5 is autumn, >0.75 winter.
    local offset = 0.0
    if isSouthHemisphere then
        offset = 0.5
    end
    return math.fmod((yearSpeed * worldTime) + temperatureSeasonTimeOffsetNoiseMultiplier * 0.1 + 0.95 + offset, 1.0) -- 0.95 to shift the peak heat into meterological summer
end

local function getSeasonIndex(worldTime, yearSpeed, position) -- 1 spring, 2 summer, 3 autumn, 4 winter
    local isSouthHemisphere = dot(position, vec3(0.0,1.0,0.0)) < 0.0
    local seasonFraction = getSeasonFraction(worldTime, yearSpeed, isSouthHemisphere)
    return mjm.clamp(math.floor(seasonFraction * 4.0) + 1, 1, 4)
end

function weather:getTemperatureZoneIndex(biomeTemperatureZones, worldTime, timeOfDayFraction, yearSpeed, position, isCovered, isWetOrStormy, closeObjectOffset)
    local seasonIndex = getSeasonIndex(worldTime, yearSpeed, position)
    local zoneIndex = weather.temperatureZones.moderate.index
    if seasonIndex == 4 then
        zoneIndex =  biomeTemperatureZones[2]
    elseif seasonIndex == 2 then
        zoneIndex =  biomeTemperatureZones[1]
    else
        zoneIndex = math.floor(biomeTemperatureZones[1] * 0.5 + biomeTemperatureZones[2] * 0.5)
    end


    if zoneIndex ~= weather.temperatureZones.moderate.index then -- it snows when cold. So don't push it down to cold from moderate, or it might snow in the tropics.
        if isWetOrStormy then
            zoneIndex = zoneIndex - 1
        elseif timeOfDayFraction > 0.9 or timeOfDayFraction < 0.3 then -- 11pm ish until 7amish
            zoneIndex = zoneIndex - 1
        end
    end

    zoneIndex = mjm.clamp(zoneIndex, 1, #weather.temperatureZones)
    
    if isCovered then
        zoneIndex = weather.temperatureZones[zoneIndex].coveredIndex
    end

    zoneIndex = mjm.clamp(zoneIndex + closeObjectOffset, 1, #weather.temperatureZones)

    --mj:log("zoneIndex:", zoneIndex, " seasonIndex:", seasonIndex, " biomeTemperatureZones:", biomeTemperatureZones)

    return zoneIndex
end

local minWaitBeforeRain = 800
local maxWaitBeforeRain = 1000
local waitDueToNewlyCreatedWorldMultiplierFraction = 1.0
local weatherChangeSpeed = 0.005

function weather:update(worldTime) 
    local noiseLocation = vec3(0.5,0.5,worldTime * weatherChangeSpeed)
    local noiseValue = noise:get(noiseLocation, 1)

    local extraRainOffsetNoiseValue = noise:get(noiseLocation + vec3(0.23,0.43,worldTime * weatherChangeSpeed), 1)

    rawWindStrength = noise:get(noiseLocation + vec3(0.73,0.62,worldTime * weatherChangeSpeed), 1)

    local temperatureNoiseLocation = vec3(0.3,0.3,worldTime * weatherChangeSpeed)
    temperatureSeasonTimeOffsetNoiseMultiplier = noise:get(temperatureNoiseLocation, 1)
    
    rawMoisture = noiseValue * 6.0 + temperatureSeasonTimeOffsetNoiseMultiplier - 1.0 + (serverWindstormStrength or 0.0) * 0.2
    extraRainOffset = extraRainOffsetNoiseValue * 0.2

    if worldTime - creationWorldTime < maxWaitBeforeRain then
        waitDueToNewlyCreatedWorldMultiplierFraction = mjm.reverseLinearInterpolate(worldTime - creationWorldTime, minWaitBeforeRain, maxWaitBeforeRain)
        waitDueToNewlyCreatedWorldMultiplierFraction = clamp(waitDueToNewlyCreatedWorldMultiplierFraction, 0.0, 1.0)
    end
    
    weather:updateSevereWeatherEvents(worldTime)
end

function weather:getCloudCover(vertRainfall)
    if gameConstants.alwaysFineWeather then
        return 0.0
    end
    local result = clamp((rawMoisture + ((clamp(vertRainfall, 0.0, 800.0) - 500.0) / 1000.0) * 2.0) * waitDueToNewlyCreatedWorldMultiplierFraction, 0.0, 1.0)
    --mj:log("getCloudCover rawMoisture:", rawMoisture, " vertRainfall:", vertRainfall, " result:", result)
    return result
end


function weather:getWindStrength()
    if gameConstants.alwaysFineWeather then
        return 0.1
    end
    local result = clamp((rawWindStrength + 0.3) * 8.0, 0.1, 8.0)

    if serverWindstormStrength then
        result = clamp(mjm.mix(result, 16.0, clamp(serverWindstormStrength, 0.0, 16.0) / 16.0), 0.1, 16.0)
    end
    --mj:log("getCloudCover rawMoisture:", rawMoisture, " vertRainfall:", vertRainfall, " result:", result)
    return result
end

function weather:getRainSnowCombinedPrecipitation(vertRainfall)
    if gameConstants.alwaysFineWeather then
        return 0.0
    end
    return clamp((rawMoisture + extraRainOffset + ((clamp(vertRainfall, 0.0, 800.0) - 500.0) / 1000.0) * 2.0 - 0.6) * waitDueToNewlyCreatedWorldMultiplierFraction, 0.0, 1.0)
end

function weather:getCurrentGlobalChanceOfRain()
    if gameConstants.alwaysFineWeather then
        return 0.0
    end
    --mj:log("weather:getCurrentGlobalChanceOfRain:", (rawMoisture + extraRainOffset) * waitDueToNewlyCreatedWorldMultiplierFraction)
    return (rawMoisture + extraRainOffset) * waitDueToNewlyCreatedWorldMultiplierFraction
end

function weather:getSnowFraction(normalizedPos, worldTime, yearSpeed, timeOfDayFraction)
    local biomeTags = terrain:getBiomeTagsForNormalizedPoint(normalizedPos)
    --mj:log("biomeTags:", biomeTags)
    local temperatureZoneIndex = weather:getTemperatureZoneIndex(weather:getTemperatureZones(biomeTags), worldTime, timeOfDayFraction, yearSpeed, normalizedPos, false, false, 0)
    --mj:log("temperatureZoneIndex:", temperatureZoneIndex)
    if temperatureZoneIndex == weather.temperatureZones.cold.index or temperatureZoneIndex == weather.temperatureZones.veryCold.index then
        return 1.0
    end
    return 0.0
end

function weather:getRainfall(rainfallValues, normalizedPos, worldTime, yearSpeed)
    
    local isSouthHemisphere = dot(normalizedPos, vec3(0.0,1.0,0.0)) < 0.0
    local seasonFraction = getSeasonFraction(worldTime, yearSpeed, isSouthHemisphere)

    local mixFraction = math.cos((seasonFraction - 0.25) * math.pi * 2.0) * 0.5 + 0.5
    local result = mjm.mix(rainfallValues[2], rainfallValues[1], mixFraction)

    --mj:log("getRainfall seasonFraction:", seasonFraction, " mixFraction:", 1.0 - mixFraction, " summer:", rainfallValues[1], " winter:", rainfallValues[2], " result:", result)

    return result
end


local peakStartTimeAndRampDuration = gameConstants.windStormDuration * 0.5 - gameConstants.windStormPeakDuration * 0.5
local peakEndTime = peakStartTimeAndRampDuration + gameConstants.windStormPeakDuration

function weather:updateSevereWeatherEvents(worldTime)
    if currentWindstormEventInfo then
        local timeSinceWindStormStart = worldTime - currentWindstormEventInfo.startTime
        local windStrengthFraction = 0.0
        if timeSinceWindStormStart < gameConstants.windStormDuration then
            if timeSinceWindStormStart < peakStartTimeAndRampDuration then
                windStrengthFraction = timeSinceWindStormStart / peakStartTimeAndRampDuration
            elseif timeSinceWindStormStart < peakEndTime then
                windStrengthFraction = 1.0
            else
                windStrengthFraction = 1.0 - ((timeSinceWindStormStart - peakEndTime) / peakStartTimeAndRampDuration)
            end
        end

        serverWindstormStrength = windStrengthFraction * gameConstants.windStormStrengthAtPeak
        --mj:log("serverWindstormStrength:", serverWindstormStrength)
    end
end

function weather:setServerWeatherInfo(serverWeatherInfo)
    if serverWeatherInfo then
        currentWindstormEventInfo = serverWeatherInfo["windStormEvent"]
    else
        currentWindstormEventInfo = nil
    end

    --mj:log("weather:setServerWeatherInfo", serverWeatherInfo, " currentWindstormEventInfo:", currentWindstormEventInfo)

    if not currentWindstormEventInfo then
        serverWindstormStrength = 0.0
    end
end

function weather:getServerWindstormStrength()
    return serverWindstormStrength
end

return weather