local rng = mjrequire "common/randomNumberGenerator"
--local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"
local mood = mjrequire "common/mood"
local serverResourceManager = mjrequire "server/serverResourceManager"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
local sapienConstants = mjrequire "common/sapienConstants"
local gameConstants = mjrequire "common/gameConstants"
--local research = mjrequire "common/research"
local skill = mjrequire "common/skill"

local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local length2 = mjm.length2


local serverWorldSettings = mjrequire "server/serverWorldSettings"

local serverWorld = nil
local serverGOM = nil
local serverTribe = nil
local serverSapien = nil
local planManager = nil
local terrain = nil

local serverNomadTribe = {}


local sampleCount = 16
local sampleDistance = mj:mToP(300.0)
local sampleDistanceIncrease = mj:mToP(50.0)
local minSapienProximityDistance = mj:mToP(280.0) --should be less than sampleDistance
local minSapienProximityDistance2 = minSapienProximityDistance * minSapienProximityDistance

local maxPossibleInfluenceDistance = sampleDistance + sampleDistanceIncrease * (sampleCount + 1)
local maxPossibleInfluenceDistance2 = maxPossibleInfluenceDistance * maxPossibleInfluenceDistance

local function doSample(samplePoint, nearSapiens)
    local found = false

    local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(samplePoint)
    if terrainResult.x > mj:mToP(0.1) then
        local allFarAway = true
        for i,sapien in ipairs(nearSapiens) do
            local distance2 = length2(sapien.normalizedPos - samplePoint)
            if distance2 < minSapienProximityDistance2 then
                --mj:log("nomad minSapienProximityDistance fail")
                allFarAway = false
                break
            end
        end

        found = allFarAway

    else
        --mj:log("nomad notPassable terrain found")
        return {
            notPassable = true
        }
    end

    if found then
        return {
            success = true
        }
    end

    return {}
end

local function getNearbyGoalPos(baseSapien)
    local nearToSapienPos = normalize(baseSapien.normalizedPos + normalize(rng:randomVec()) * mj:mToP(50.0))
    local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(nearToSapienPos)
    if terrainResult.x > mj:mToP(0.1) then
        return nearToSapienPos * (1.0 + terrainResult.x)
    else
        terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(baseSapien.normalizedPos) --todo get real terrain point
        if terrainResult.x > mj:mToP(0.1) then
            return baseSapien.normalizedPos * (1.0 + terrainResult.x)
        end
    end

    return nil
end

local function getCampfirePos(baseSapien)
    local campfireInfosBySet = serverGOM:getGameObjectsInSetsWithinNormalizedRadiusOfPos({serverGOM.objectSets.litCampfires}, baseSapien.normalizedPos, mj:mToP(100.0))
    local campfireInfos = campfireInfosBySet[serverGOM.objectSets.litCampfires]
    if campfireInfos and #campfireInfos > 0 then
        local randomCampfireIndex = rng:randomInteger(#campfireInfos) + 1
        local campfire = serverGOM:getObjectWithID(campfireInfos[randomCampfireIndex].objectID)
        if campfire then
            return campfire.pos
        end
    end

    return nil
end

local function getFoodStockpilePos(baseSapien, minFoodContentsCount)
    local options = {
        onlyStockpiles = true,
        maxCount = 1,
        minStockpileCount = minFoodContentsCount,
        foodValueAffectsHeuristic = true,
    }
    local storageAreas = serverResourceManager:distanceOrderedObjectsForResourceinTypesArray(gameObject.foodObjectTypes, baseSapien.pos, options, nil)
    if storageAreas and storageAreas[1] then
        return storageAreas[1].pos
    end
    return nil
end

local function getValuableResourcePos(baseSapien)
    local options = {
        allowStockpiles = true,
        minStoredPerItemValue = 0.3,
        minLoosePerItemValue = 0.5,
    }
    local valuableResources = serverResourceManager:getValueOrderedValuableResources(baseSapien.pos, options)
    if valuableResources and valuableResources[1] then
        return valuableResources[1].pos
    end
    return nil
end

local timeOffsetHackThisNeedsToBeFixed = 2.0

serverNomadTribe.nomadTribeBehaviorFunctionsByTypeIndex = {
    [nomadTribeBehavior.types.foodRaid.index] = {
        getGoalPos = function(baseSapien)
            local goalPos = getFoodStockpilePos(baseSapien, 5)
            if goalPos then
                return goalPos
            end
            return nil
        end,
        validate = function(baseSapien)
            local foodStorageAreaPos = getFoodStockpilePos(baseSapien, 5)
            if foodStorageAreaPos == nil then
                return nil
            end
            return true
        end,
        getGoalTimeOffset = function()
            return 600.0 * timeOffsetHackThisNeedsToBeFixed
        end,
        getExitTimeOffset = function()
            return 900.0 * timeOffsetHackThisNeedsToBeFixed
        end,
    },
    [nomadTribeBehavior.types.opportunisticThief.index] = {
        getGoalPos = function(baseSapien)
            return getCampfirePos(baseSapien) or getNearbyGoalPos(baseSapien)
        end,
        getGoalTimeOffset = function()
            return 600.0 * timeOffsetHackThisNeedsToBeFixed
        end,
        getExitTimeOffset = function()
            return 900.0 * timeOffsetHackThisNeedsToBeFixed
        end,
    },
    [nomadTribeBehavior.types.armedThief.index] = {
        getGoalPos = function(baseSapien)
            return getValuableResourcePos(baseSapien)
        end,
        getGoalTimeOffset = function()
            return 600.0 * timeOffsetHackThisNeedsToBeFixed
        end,
        getExitTimeOffset = function()
            return 900.0 * timeOffsetHackThisNeedsToBeFixed
        end,
    },
    [nomadTribeBehavior.types.friendlyVisit.index] = {
        getGoalPos = function(baseSapien)
            return getCampfirePos(baseSapien) or getNearbyGoalPos(baseSapien)
        end,
        getGoalTimeOffset = function()
            return 400.0 * timeOffsetHackThisNeedsToBeFixed
        end,
        getExitTimeOffset = function()
            return 2880.0 * timeOffsetHackThisNeedsToBeFixed
        end,
    },
    [nomadTribeBehavior.types.cautiousVisit.index] = {
        getGoalPos = function(baseSapien)
            return getCampfirePos(baseSapien) or getNearbyGoalPos(baseSapien)
        end,
        getGoalTimeOffset = function()
            return 1000.0
        end,
        getExitTimeOffset = function()
            return 2880.0
        end,
    },
    [nomadTribeBehavior.types.join.index] = {
        getGoalPos = function(baseSapien)
            local goalPos = getCampfirePos(baseSapien)
            if goalPos then
                return goalPos
            end
            return getNearbyGoalPos(baseSapien)
        end,
        validate = function(baseSapien)
            
            local loyalty = mood:getMood(baseSapien, mood.types.loyalty.index)
            if loyalty < mood.levels.moderateNegative then 
                return nil
            end
            local foodStorageAreaPos = getFoodStockpilePos(baseSapien, 10)
            if foodStorageAreaPos == nil then
                return nil
            end
            return true
        end,
        getGoalTimeOffset = function()
            return 400.0 * timeOffsetHackThisNeedsToBeFixed
        end,
        getExitTimeOffset = function()
            return 2880.0 * timeOffsetHackThisNeedsToBeFixed
        end,
    },
    [nomadTribeBehavior.types.passThrough.index] = {
        getGoalPos = function(baseSapien)
            return getNearbyGoalPos(baseSapien)
        end,
        getExitPos = function(baseSapien, nearSapiens, foundSpawnPoint, goalPos)
            local goalToFoundVec = goalPos - foundSpawnPoint
            local exitPosNormal = normalize(goalPos + goalToFoundVec)
            local sampleResult = doSample(exitPosNormal, nearSapiens)
            if sampleResult.success then
                return exitPosNormal
            end
            return nil
        end,
        getGoalTimeOffset = function()
            return 400.0
        end,
        getExitTimeOffset = function()
            return 2880.0
        end,
    },
    [nomadTribeBehavior.types.leave.index] = {
        getGoalPos = function(baseSapien)
            return getNearbyGoalPos(baseSapien)
        end,
        getGoalTimeOffset = function()
            return 0.0
        end,
        getExitTimeOffset = function()
            return 0.0
        end,
    },
}

function serverNomadTribe:createLeavingTribe(previousTribeID, leavingSapiens, banishedByTribeIDOrNil)
    local sapienToUse = leavingSapiens[1]

    local extraTribeState = nil
    
    local allNearSapiens = {}
    serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function(objectID)
        local otherSapien = serverGOM:getObjectWithID(objectID)
        local leaving = false
        if otherSapien then
            for i,leavingSapien in ipairs(leavingSapiens) do
                if leavingSapien.uniqueID == otherSapien.uniqueID then
                    leaving = true
                    break
                end
            end
        end
        if not leaving then
            if length2(sapienToUse.normalizedPos - otherSapien.normalizedPos) < maxPossibleInfluenceDistance2 then
                table.insert(allNearSapiens, otherSapien)
            end
        end
    end)

    local foundExitPoint = nil

    local randomDirectionCountMax = 8
    for randDirectionCounter = 1,randomDirectionCountMax do
        local awayVec = normalize(sapienToUse.normalizedPos - normalize(sapienToUse.normalizedPos + rng:randomVec() * mj:mToP(100.0)))
    
        for sampleIndex=1,sampleCount do
            local samplePoint = normalize(sapienToUse.normalizedPos + awayVec * (sampleDistance + sampleDistanceIncrease * sampleIndex))
            local sampleResult = doSample(samplePoint, allNearSapiens)
            if sampleResult.success then
                --mj:log("nomad foundSpawnPoint")
                foundExitPoint = samplePoint
                break
            elseif sampleResult.notPassable then
                break
            end
        end

        if foundExitPoint then
            break
        end
    end

    if foundExitPoint then

        local tribeBehaviorType = nomadTribeBehavior.types.leave
        local tribeBehaviorFunctions = serverNomadTribe.nomadTribeBehaviorFunctionsByTypeIndex[tribeBehaviorType.index]

        mj:log("attempting to create LEAVING nomad tribe with behavior:", tribeBehaviorType.name)

        local exitPos = foundExitPoint
        if tribeBehaviorType.getExitPos then
            exitPos = tribeBehaviorFunctions.getExitPos(sapienToUse, allNearSapiens, foundExitPoint, foundExitPoint)
        end

        if  exitPos then
            --local nearToSapienPos = normalize(sapienToUse.normalizedPos + normalize(rng:randomVec()) * mj:mToP(50.0))

            local goalTimeOffset = 800.0
            local exitTimeOffset = 2880.0
            if tribeBehaviorFunctions.getGoalTimeOffset then
                goalTimeOffset = tribeBehaviorFunctions.getGoalTimeOffset()
            end
            if tribeBehaviorFunctions.getExitTimeOffset then
                exitTimeOffset = tribeBehaviorFunctions.getExitTimeOffset()
            end

            --mj:log("tribeBehaviorType:", tribeBehaviorType)


            --mj:log("goalTimeOffset:", goalTimeOffset, " exitTimeOffset:", exitTimeOffset)

            extraTribeState = {
                nomad = true,
                population = #leavingSapiens,
                nomadState = {
                    tribeBehaviorTypeIndex = tribeBehaviorType.index,
                    spawnTime = serverWorld:getWorldTime(),
                    goalTime = serverWorld:getWorldTime() + goalTimeOffset,
                    exitTime = serverWorld:getWorldTime() + exitTimeOffset,
                    goalPos = foundExitPoint,
                    exitPos = exitPos,
                }
            }
            
        else
            mj:log("couldnt find nomad tribe exit pos")
        end
    else
        mj:log("couldnt find nomad tribe spawn point")
    end


    if extraTribeState then

        local averagePosition = vec3(0.0,0.0,0.0)
        for i,leavingSapien in ipairs(leavingSapiens) do
            averagePosition = averagePosition + leavingSapien.normalizedPos
        end
        local tribeCenterNormalized = normalize(averagePosition / #leavingSapiens)

        local newTribeState = serverTribe:createLeavingAITribe(tribeCenterNormalized, extraTribeState)
        serverWorld:addTribeToSeenList(previousTribeID, newTribeState.tribeID)
        if banishedByTribeIDOrNil then
            serverWorld:addTribeToSeenList(banishedByTribeIDOrNil, newTribeState.tribeID) --maybe a client tribe banished a nomad tribe. We need to inform the client or we get a new tribe seen notification
        end
        
        for i,leavingSapien in ipairs(leavingSapiens) do
            local removeHeldObjectOrderContext = false
            serverSapien:cancelOrderAtQueueIndex(leavingSapien, 1, removeHeldObjectOrderContext)
            planManager:cancelAllPlansForObject(previousTribeID, leavingSapien.uniqueID)
            local sharedState = leavingSapien.sharedState
            sharedState:set("tribeID", newTribeState.tribeID)
            sharedState:set("previousTribeID", previousTribeID)
            sharedState:set("nomad", true)
            sharedState:set("tribeBehaviorTypeIndex", nomadTribeBehavior.types.leave.index)
            sharedState:remove("manualAssignedPlanObject")
            sharedState:set("fleeing", true)
            mj:debug("fleeing")

            --mj:debug("fleeing")

            serverGOM:sapienTribeChanged(leavingSapien, previousTribeID, newTribeState.tribeID)


            --serverGOM:addObjectToSet(leavingSapien, serverGOM.objectSets.nomads)
            --serverGOM:removeObjectFromSet(leavingSapien, serverGOM.objectSets.playerSapiens)
            for skillTypeIndex,v in pairs(sharedState.skillPriorities) do
                if v == 1 then
                    serverGOM:removeObjectFromSet(leavingSapien, skill.types[skillTypeIndex].sapienSetIndex)
                end
            end
        end
        mj:log("updated leaving sapiens to nomad state successfully")
        return true
    end

    return false
end

serverNomadTribe.peacefulTypes = {
    nomadTribeBehavior.types.friendlyVisit.index,
    nomadTribeBehavior.types.cautiousVisit.index,
    nomadTribeBehavior.types.join.index,
    nomadTribeBehavior.types.passThrough.index,
}

serverNomadTribe.theifTypes = {
    nomadTribeBehavior.types.foodRaid.index,
    nomadTribeBehavior.types.opportunisticThief.index,
    nomadTribeBehavior.types.armedThief.index,
}
--[[
serverNomadTribe.combinedTypes = {}
for i,t in ipairs(serverNomadTribe.peacefulTypes) do
    table.insert(serverNomadTribe.combinedTypes, t)
end
for i,t in ipairs(serverNomadTribe.theifTypes) do
    table.insert(serverNomadTribe.combinedTypes, t)
end]]

function serverNomadTribe:spawnNomadTribe(parentTribeID)
    
    --mj:log("serverNomadTribe:spawnNomadTribe")
    local averagePosition = vec3(0.0,0.0,0.0)
    local thisTribeSapiens = {}


    serverGOM:callFunctionForAllSapiensInTribe(parentTribeID, function(sapien)
        averagePosition = averagePosition + sapien.normalizedPos
        table.insert(thisTribeSapiens, sapien)
    end)

    if #thisTribeSapiens > 0 then
        averagePosition = normalize(averagePosition / #thisTribeSapiens)

        local randomIndex = rng:randomInteger(#thisTribeSapiens) + 1
        local sapienToUse = thisTribeSapiens[randomIndex]

        local randomTribeBehaviorIndex = nil
        local isPeaceful = false
        local gameDifficultyMode = serverWorldSettings:get("gameDifficulty")
        local parentTribePopulation = serverTribe:getPopulation(parentTribeID)

        local raidPopulationMet = rng:randomChance((parentTribePopulation - gameConstants.minPopulationForRaids + 5) / 10) -- from (minPopulationForRaids - 5) to (minPopulationForRaids + 5) the chance goes from 0% to 100%

        if gameDifficultyMode == "peaceful" or (not raidPopulationMet) then
            isPeaceful = true
            mj:log("nomad spawn peaceful due to gameDifficulty setting or low population")
        else
            local nomadReputation = serverWorld:getPlayerNomadReputation(parentTribeID)
            local peacefulChance = 0.1 + (nomadReputation / 100) * 0.8
            isPeaceful = rng:randomChance(peacefulChance)
            mj:log("nomad spawn peaceful:", isPeaceful, " due to reputation:", nomadReputation, " peacefulChance:", peacefulChance)
        end

        if isPeaceful then
            randomTribeBehaviorIndex = serverNomadTribe.peacefulTypes[rng:randomInteger(#serverNomadTribe.peacefulTypes) + 1]
        else
            randomTribeBehaviorIndex = serverNomadTribe.theifTypes[rng:randomInteger(#serverNomadTribe.theifTypes) + 1]
        end

            
        local tribeBehaviorType = nomadTribeBehavior.types[randomTribeBehaviorIndex]

        if tribeBehaviorType.validate then
            if not tribeBehaviorType.validate(sapienToUse) then
                return true --return a success. We don't want to keep trying with other spawn types in this case.
            end
        end
        
        local awayVec = normalize(sapienToUse.normalizedPos - normalize(averagePosition + rng:randomVec() * mj:mToP(100.0)))
        
        local allNearSapiens = {}
        serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function(objectID)
            local otherSapien = serverGOM:getObjectWithID(objectID)
            if otherSapien then
                if length2(sapienToUse.normalizedPos - otherSapien.normalizedPos) < maxPossibleInfluenceDistance2 then
                    table.insert(allNearSapiens, otherSapien)
                end
            end
        end)

        local foundSpawnPoint = nil

        for sampleIndex=1,sampleCount do
            local samplePoint = normalize(sapienToUse.normalizedPos + awayVec * (sampleDistance + sampleDistanceIncrease * sampleIndex))
            local sampleResult = doSample(samplePoint, allNearSapiens)
            if sampleResult.success then
                --mj:log("nomad foundSpawnPoint")
                foundSpawnPoint = samplePoint
                break
            elseif sampleResult.notPassable then
                break
            end
        end

        if foundSpawnPoint then


            local tribeBehaviorFunctions = serverNomadTribe.nomadTribeBehaviorFunctionsByTypeIndex[tribeBehaviorType.index]

            mj:log("attempting to create nomad tribe with behavior:", tribeBehaviorType.name)

            local goalPos = tribeBehaviorFunctions.getGoalPos(sapienToUse)
            if goalPos then
                local exitPos = foundSpawnPoint
                if tribeBehaviorType.getExitPos then
                    exitPos = tribeBehaviorFunctions.getExitPos(sapienToUse, allNearSapiens, foundSpawnPoint, goalPos)
                end

                if exitPos then
                    --local nearToSapienPos = normalize(sapienToUse.normalizedPos + normalize(rng:randomVec()) * mj:mToP(50.0))

                    local goalTimeOffset = 800.0
                    local exitTimeOffset = 1600.0
                    if tribeBehaviorFunctions.getGoalTimeOffset then
                        goalTimeOffset = tribeBehaviorFunctions.getGoalTimeOffset()
                    end
                    if tribeBehaviorFunctions.getExitTimeOffset then
                        exitTimeOffset = tribeBehaviorFunctions.getExitTimeOffset()
                    end


                    local extraTribeState = {
                        nomad = true,
                        nomadState = {
                            tribeBehaviorTypeIndex = tribeBehaviorType.index,
                            spawnTime = serverWorld:getWorldTime(),
                            goalTime = serverWorld:getWorldTime() + goalTimeOffset,
                            exitTime = serverWorld:getWorldTime() + exitTimeOffset,
                            goalPos = goalPos,
                            exitPos = exitPos,
                        }
                        --pathType = 
                    }

                    local tribeHasVirus = false

                    local virusPopulationMet = rng:randomChance((parentTribePopulation - gameConstants.minPopulationForVirusIntroduction + 5) / 10) -- from (minPopulationForVirusIntroduction - 5) to (minPopulationForVirusIntroduction + 5) the chance goes from 0% to 100%

                    if virusPopulationMet and rng:randomValue() < sapienConstants.virusInNomadTribeChance then
                        tribeHasVirus = true
                    end


                    local creationInfo = {
                        minSpawnCount = tribeBehaviorType.minSpawnCount or 1,
                        maxSpawnCount = tribeBehaviorType.maxSpawnCount or 4,
                        tribeHasVirus = tribeHasVirus,
                        extraSapienSharedState = {
                            nomad = true,
                            tribeBehaviorTypeIndex = tribeBehaviorType.index, --bit of a hack, should probably use tribeID and tribeInfo
                        }
                    }
                    
                    mj:log("serverTribe:createNomadTribe has virus:", tribeHasVirus, " parentTribeID:", parentTribeID, " parent tribe population:", serverTribe:getPopulation(parentTribeID), " creationInfo:", creationInfo)
                    
                    local tribeCenterNormalized = normalize(foundSpawnPoint)


                    serverTribe:createNomadTribe(tribeCenterNormalized, creationInfo, extraTribeState)
                else
                    mj:log("couldnt find nomad tribe exit pos")
                    return false
                end
            else
                mj:log("couldnt find nomad tribe goal pos")
                return false
            end
        else
            mj:log("couldnt find nomad tribe spawn point")
            return false
        end

    end

    return true
end

function serverNomadTribe:setServerSapien(serverSapien_)
    serverSapien = serverSapien_
end

function serverNomadTribe:init(serverWorld_, serverGOM_, serverTribe_, planManager_, terrain_, liveTribeList)
    serverWorld = serverWorld_
    serverGOM = serverGOM_
    serverTribe = serverTribe_
    planManager = planManager_
    terrain = terrain_
    

    --for tribeID,clientID in pairs(liveTribeList) do
       -- local tribeStoryState = tribeEventsDatabase:dataForKey(tribeID) or {}
      --  loadTribe(tribeID, tribeStoryState)
   -- end
end

return serverNomadTribe