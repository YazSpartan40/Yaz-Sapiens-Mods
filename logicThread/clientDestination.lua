
local gameConstants = mjrequire "common/gameConstants"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"

local clientDestination = {}

local destinations = {}
local logic = nil
local terrain = nil

function clientDestination:setLogic(logic_)
    logic = logic_
end

function clientDestination:setTerrain(terrain_)
    terrain = terrain_
end

function clientDestination:reset()
    destinations = {}
end

function clientDestination:addDestinationInfos(destinationInfos)
    for i,destinationInfo in ipairs(destinationInfos) do
        --mj:log("clientDestination:addDestinationInfo:", destinationInfo)
        local destinationID = destinationInfo.destinationID
        if not destinations[destinationID] then
            if (not destinationInfo.pos) and destinationInfo.normalizedPos then
                destinationInfo.pos = terrain:getHighestDetailTerrainPointAtPoint(destinationInfo.normalizedPos) --probably not needed anymore
            end
            if destinationInfo.pos then
                logic:callMainThreadFunction("addDestination", destinationInfo)
                destinations[destinationID] = destinationInfo
            end
        end
    end
end


function clientDestination:updateDestination(destinationInfo)
    if destinations[destinationInfo.destinationID] then
        --mj:log("update destination:", destinationInfo)
        destinations[destinationInfo.destinationID] = destinationInfo
        logic:callMainThreadFunction("updateDestination", destinationInfo)
    else
        --mj:log("update destination adding:", destinationInfo)
        clientDestination:addDestinationInfos({destinationInfo})
    end
end

function clientDestination:updateDestinationTribeCenters(tribeCentersInfo)
    if destinations[tribeCentersInfo.destinationID] then
        logic:callMainThreadFunction("updateDestinationTribeCenters", tribeCentersInfo)
    end
end

function clientDestination:updateDestinationRelationship(relationshipInfo)
    if destinations[relationshipInfo.destinationID] then
        logic:callMainThreadFunction("updateDestinationRelationship", relationshipInfo)
    end
end

function clientDestination:updateDestinationTradeables(info)
    if destinations[info.destinationID] then
        logic:callMainThreadFunction("updateDestinationTradeables", info)
    end
end

function clientDestination:updateDestinationPlayerOnlineStatus(info)
    if destinations[info.destinationID] then
        logic:callMainThreadFunction("updateDestinationPlayerOnlineStatus", info)
    end
end

function clientDestination:getOtherTribeIsThreatening(otherTribeID)
    if logic.tribeID ~= otherTribeID then
        local otherDestinationState = destinations[otherTribeID]
        if otherDestinationState then
            if otherDestinationState.clientID then
                local relationshipSettings = logic:getTribeRelationsSettings(otherTribeID)
                if relationshipSettings and relationshipSettings.treatAsThreat then
                    return true
                end
            else
                if otherDestinationState.nomadState then
                    return nomadTribeBehavior.types[otherDestinationState.nomadState.tribeBehaviorTypeIndex].isRaid
                end

                local relationship = otherDestinationState.relationships and otherDestinationState.relationships[logic.tribeID]
                if relationship and relationship.favor <= gameConstants.tribeRelationshipScoreThresholds.mildNegative then
                    return true
                end
            end
        end
    end
    return false
end

return clientDestination