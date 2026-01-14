
local statistics = mjrequire "common/statistics"

local serverStatistics = {}

local serverWorld = nil
local statsDatabase = nil

local maxDataFrameCount = 512 --1024 works OK and offers higher detail, but higher performance cost.

local function getDBKey(tribeID, statisticsTypeIndex, dayIndex)
    return tribeID .. "_" .. mj:tostring(dayIndex) .. "_" .. mj:tostring(statisticsTypeIndex)
end

function serverStatistics:getValues(tribeID, statisticsTypeIndexes, startIndexBase)

    local startIndex = startIndexBase or 1
    if startIndex < 1 then
        startIndex = 1
    end
    local nowDayIndex = serverWorld:getStatsIndex()
    if startIndex > nowDayIndex then
        startIndex = nowDayIndex
    end

    local spread = nowDayIndex - startIndex
    local step = 1 + math.floor(spread / maxDataFrameCount)

   -- local debugCount = 0

    local result = {}
    for i,statisticsTypeIndex in ipairs(statisticsTypeIndexes) do

        local resultForThisStatisticsType = {}

        if step == 1 or statistics.types[statisticsTypeIndex].rollingAverage then
            for iDayIndex=startIndex,nowDayIndex do
                local key = getDBKey(tribeID, statisticsTypeIndex, iDayIndex)
                local data = statsDatabase:dataForKey(key)
                resultForThisStatisticsType[iDayIndex] = data
            end
        else
            local prevValue = 0
            for iDayIndex=startIndex,nowDayIndex,step do
                local sum = 0
                for subStep=1,step do
                    local key = getDBKey(tribeID, statisticsTypeIndex, iDayIndex + (subStep - 1))
                    local data = statsDatabase:dataForKey(key) or prevValue
                    sum = sum + data
                    prevValue = data
                end
                resultForThisStatisticsType[iDayIndex] = sum / step
                --debugCount = debugCount + 1
            end

            if not resultForThisStatisticsType[nowDayIndex] then
                local key = getDBKey(tribeID, statisticsTypeIndex, nowDayIndex)
                local data = statsDatabase:dataForKey(key) or prevValue
                resultForThisStatisticsType[nowDayIndex] = data
            end

        end

        result[statisticsTypeIndex] = resultForThisStatisticsType
    end
    
    --mj:log("spread:", spread, " maxDataFrameCount:", maxDataFrameCount, " step:", step, " total count:", debugCount)

    --mj:log("sending stats:", result)
    return result
end


function serverStatistics:setValueForToday(tribeID, statisticsTypeIndex, value)
    --[[if statisticsTypeIndex == statistics.types.population.index then
        mj:debug("setting population:", value)
    end]]
    local dayIndex = serverWorld:getStatsIndex()
    local key = getDBKey(tribeID, statisticsTypeIndex, dayIndex)
    statsDatabase:setDataForKey(value, key)
    --mj:log("serverStatistics record value for type:", statistics.types[statisticsTypeIndex].key)
end

function serverStatistics:recordEvent(tribeID, statisticsTypeIndex)
    local dayIndex = serverWorld:getStatsIndex()
    local key = getDBKey(tribeID, statisticsTypeIndex, dayIndex)
    local statsThisDay = statsDatabase:dataForKey(key) or 0
    statsThisDay = statsThisDay + 1
    statsDatabase:setDataForKey(statsThisDay, key)
end

function serverStatistics:init(serverWorld_)
    serverWorld = serverWorld_
    statsDatabase = serverWorld:getDatabase("stats", true)
end

return serverStatistics