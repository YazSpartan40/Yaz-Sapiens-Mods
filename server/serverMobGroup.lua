local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
local normalize = mjm.normalize
local length2 = mjm.length2
local cross = mjm.cross

local rng = mjrequire "common/randomNumberGenerator"
local mob = mjrequire "common/mob/mob"

local serverDestination = mjrequire "server/serverDestination"

local serverMobGroup = {}

local serverTerrain = nil
local serverMob = nil
local serverGOM = nil

local defaultTravelPastDistance = mj:mToP(120.0)

--local minSapienProximityDistance = mj:mToP(100.0) --should be less than sampleDistance
--local minSapienProximityDistance2 = minSapienProximityDistance * minSapienProximityDistance

local maxPossibleInfluenceDistance = mj:mToP(1000.0) -- should be around minSapienProximityDistance * 2 above the maximum spawnDistance set in an mobType
local maxPossibleInfluenceDistance2 = maxPossibleInfluenceDistance * maxPossibleInfluenceDistance


local landSeaAltitudeCutoffSeaLevelRelative =  -mj:mToP(0.25)


local function doSample(mobType, samplePoint, nearSapiens) -- checkForTerrainModifications far too aggressive. Need to check for built objects or something
    local found = false

    local terrainResult = serverTerrain:getRawTerrainDataAtNormalizedPoint(samplePoint)
   -- mj:log("terrainResult:", mj:pToM(terrainResult.x))

    local validAltitude = false
    if mobType.swims then
        validAltitude = terrainResult.x < landSeaAltitudeCutoffSeaLevelRelative
    else
        validAltitude = terrainResult.x > landSeaAltitudeCutoffSeaLevelRelative
    end

    if validAltitude then
        local minSapienProximityDistance = mobType.minSapienProximityDistanceForSpawning or mj:mToP(100.0)
        local minSapienProximityDistance2 = minSapienProximityDistance * minSapienProximityDistance
        local allFarAway = true
        for i,sapien in ipairs(nearSapiens) do
            local distance2 = length2(sapien.normalizedPos - samplePoint)
            if distance2 < minSapienProximityDistance2 then
                --mj:log("mob load minSapienProximityDistance fail")
                allFarAway = false
                break
            end
        end

        found = allFarAway

    else
        --mj:log("mob load notPassable terrain found:", mobType.key)
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

function serverMobGroup:addRandomMobGroup(tribeID, averagePositionOfTribeSapiens, avoidLateGameMobs)
        
    --mj:log("serverMobGroup:addRandomMobGroup")

    --[[local spawnSuccess = false
    serverGOM:callFunctionForRandomSapienInTribe(storyTribeID, function(sapien)
        mj:log("serverMobGroup:spawnMigratingMobGroup for sapien:", sapien.uniqueID)
        spawnSuccess = serverMobGroup:addRandomMobGroup(sapien.normalizedPos, averagePosition, avoidLateGameMobs)
    end)]]

        
    local mobTypeIndex = nil
    local randomTypeValue = rng:randomValue() * mob.spawnFrequencyWeightTotal;
    local weightAccumulation = 0.0
    for i,thisMobTypeIndex in ipairs(mob.spawningTypeIndexes) do
        mobTypeIndex = thisMobTypeIndex
        weightAccumulation = weightAccumulation + mob.types[mobTypeIndex].spawnFrequency
        --mj:log("weightAccumulation:", weightAccumulation)
        if weightAccumulation > randomTypeValue then
            --mj:log("weightAccumulation > randomTypeValue")
            break
        end
    end

    if not mobTypeIndex then
        return false
    end

    mj:log("serverMobGroup:addRandomMobGroup mobTypeIndex:", mobTypeIndex)

    local mobType = mob.types[mobTypeIndex]
    
    if avoidLateGameMobs and mobType.dontSpawnInEarlyGame then
        return false
    end
    

    local sapienID = nil
    local sapien = nil

    local sapiensByThisTribe = serverGOM.sapienObjectsByTribe[tribeID]
    if sapiensByThisTribe then
        local loadedSapienCount = serverGOM.loadedSapienCountsByTribe[tribeID]
        if loadedSapienCount and loadedSapienCount > 0 then
            local randomIndex = rng:randomInteger(loadedSapienCount)
            local counter = 0
            for uid,object in pairs(sapiensByThisTribe) do
                counter = counter + 1
                if counter > randomIndex then
                    sapienID = uid
                    sapien = object
                    break
                end
            end
        end
    end

    if not sapienID then
        return false
    end

    for sampleIndex=1,4 do --next is called below to get a new sapien
        local sapienNormalizedPos = sapien.normalizedPos

        local allNearSapiens = {}
        serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function(objectID)
            local otherSapien = serverGOM:getObjectWithID(objectID)
            if otherSapien then
                if length2(sapienNormalizedPos - otherSapien.normalizedPos) < maxPossibleInfluenceDistance2 then
                    table.insert(allNearSapiens, otherSapien)
                end
            end
        end)


        --mj:log("mobType:", mobType.key)

        local function getRandomPerpVecNormal(pointNormal)
            local randomVecNormalized = normalize(rng:vec())
            return normalize(cross(randomVecNormalized, pointNormal))
        end

        local goalMidPoint = nil
        local startSampleResult = nil
        local perpVec = nil

        local spawnDistance = mobType.spawnDistance
        local startPosNormal = nil
        local exitPosNormal = nil

        mj:log("spawn attempt:", sampleIndex, " type:", mobType.key)
        local awayVec = getRandomPerpVecNormal(sapienNormalizedPos) -- note this is a normalized direction only
        perpVec = normalize(cross(sapienNormalizedPos, awayVec))
        if rng:randomBool() then
            perpVec = -perpVec
        end

        local travelPastDistanceToUse = (mobType.travelPastDistance or defaultTravelPastDistance) * (0.5 + rng:randomValue())
        goalMidPoint = normalize(sapienNormalizedPos + awayVec * travelPastDistanceToUse)
        local sampleResult = doSample(mobType, goalMidPoint, allNearSapiens)

        if not sampleResult.success then
            --mj:log("initial goalMidPoint fail")
            travelPastDistanceToUse = travelPastDistanceToUse * 2.0
            goalMidPoint = normalize(sapienNormalizedPos + awayVec * travelPastDistanceToUse)
            sampleResult = doSample(mobType, goalMidPoint, allNearSapiens)
        end

        if not sampleResult.success then
            --mj:log("*2 goalMidPoint fail")
            travelPastDistanceToUse = travelPastDistanceToUse * 4.0
            goalMidPoint = normalize(sapienNormalizedPos + awayVec * travelPastDistanceToUse)
            sampleResult = doSample(mobType, goalMidPoint, allNearSapiens)
        end

        if not sampleResult.success then
            --mj:log("*4 goalMidPoint fail")
            travelPastDistanceToUse = travelPastDistanceToUse * 8.0
            goalMidPoint = normalize(sapienNormalizedPos + awayVec * travelPastDistanceToUse)
            sampleResult = doSample(mobType, goalMidPoint, allNearSapiens)
        end

        if sampleResult.success then
            mj:log("mid point found")
            
            startPosNormal = normalize(goalMidPoint - perpVec * spawnDistance + rng:randomVec() * spawnDistance * 0.75)
            startSampleResult = doSample(mobType, startPosNormal, allNearSapiens)

            local subSampleRetryCount = 0
            while not startSampleResult.success do
                startPosNormal = normalize(goalMidPoint - perpVec * spawnDistance + rng:randomVec() * spawnDistance * 0.75)
                startSampleResult = doSample(mobType, startPosNormal, allNearSapiens)

                subSampleRetryCount = subSampleRetryCount + 1
                if subSampleRetryCount >= 4 then
                    break
                end
            end

            if startSampleResult.success then

                local biomeTags = nil

                if mobType.requiredBiomeTags or mobType.disallowedBiomeTags then
                    mj:log("mobType.requiredBiomeTags or mobType.disallowedBiomeTags")
                    if not biomeTags then
                        biomeTags = serverTerrain:getBiomeTagsForNormalizedPoint(startPosNormal)
                    end
                    mj:log("biomeTags:", biomeTags)

                    if mobType.requiredBiomeTags then
                        local found = false
                        for i,tag in ipairs(mobType.requiredBiomeTags) do
                            if biomeTags[tag] then
                                found = true
                                break
                            end
                        end
                        if not found then
                            mj:log("not valid due to mobType missing one of the required tags:", mobType.requiredBiomeTags)
                            return false
                        end
                    end

                    
                    if mobType.disallowedBiomeTags then
                        for i,tag in ipairs(mobType.disallowedBiomeTags) do
                            if biomeTags[tag] then
                                mj:log("not valid due to mobType containing disallowed tag:", tag)
                                return false
                            end
                        end
                    end
                end

                local mobGameObjectTypeIndex = mobType.gameObjectTypeIndex
                if mobType.variants then
                    mj:log("variants found")
                    local variantCount = #mobType.variants
                    local randomIndexOffset = rng:randomInteger(variantCount)
                    for i=1,variantCount do
                        local index = i + randomIndexOffset
                        if index > variantCount then
                            index = index - variantCount
                        end
                        
                        local variant = mobType.variants[index]
                        local valid = true
                        mj:log("test variant:", variant)

                        if variant.requiredBiomeTags or variant.disallowedBiomeTags then
                            if not biomeTags then
                                biomeTags = serverTerrain:getBiomeTagsForNormalizedPoint(startPosNormal)
                            end
                            mj:log("biomeTags:", biomeTags)
                            
                           --[[ if variant.requiredBiomeTags then
                                for j,tag in pairs(variant.requiredBiomeTags) do
                                    if not biomeTags[tag] then
                                        mj:log("not valid due to variant missing required tag:", tag)
                                        valid = false
                                        break
                                    end
                                end
                            end]]

                            if variant.requiredBiomeTags then
                                local found = false
                                for j,tag in pairs(variant.requiredBiomeTags) do
                                    if biomeTags[tag] then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    mj:log("not valid due to variant missing one of the required tags:", variant.requiredBiomeTags)
                                    valid = false
                                end
                            end
                            
                            if valid and variant.disallowedBiomeTags then
                                for j,tag in pairs(variant.disallowedBiomeTags) do
                                    if biomeTags[tag] then
                                        mj:log("not valid due to variant containing disallowed tag:", tag)
                                        valid = false
                                        break
                                    end
                                end
                            end
                        end


                        if valid then
                            mj:log("setting game object type:", variant.gameObjectTypeIndex)
                            mobGameObjectTypeIndex = variant.gameObjectTypeIndex
                            break
                        end
                    end
                end
                

                mj:log("start point found")
                exitPosNormal = normalize(goalMidPoint + perpVec * spawnDistance + rng:randomVec() * spawnDistance * 0.75)
                local exitSampleResult = doSample(mobType, exitPosNormal, allNearSapiens)

                subSampleRetryCount = 0
                while not exitSampleResult.success do
                    exitPosNormal = normalize(goalMidPoint + perpVec * spawnDistance + rng:randomVec() * spawnDistance * 0.75)
                    exitSampleResult = doSample(mobType, exitPosNormal, allNearSapiens)

                    subSampleRetryCount = subSampleRetryCount + 1
                    if subSampleRetryCount >= 4 then
                        break
                    end
                end

                if exitSampleResult.success then
                    mj:log("exit point found")
                
                    local groupCenter = startPosNormal
                    local groupID = serverGOM:reserveUniqueID() --technically we should use some other id here, but this seems a harmless easy hack
                    
                    local countToAdd = rng:integerForUniqueID(groupID, 23875, 4) + 3


                    for j=1,countToAdd do
                        serverMob:createMob(mobTypeIndex, mobGameObjectTypeIndex, groupID, groupCenter, j, exitPosNormal, goalMidPoint, nil, nil)
                    end
        
                    return true
                end
            end
        end
        
        sapienID,sapien =  next(sapiensByThisTribe, sapienID)
        if not sapienID then
            sapienID,sapien =  next(sapiensByThisTribe)
        end
    end
        

    return false
end

function serverMobGroup:spawnMigratingMobGroupsForInitialTribeSelection(storyTribeID)

    local averagePosition = serverDestination:getDestinationState(storyTribeID).normalizedPos
    local avoidLateGameMobs = true

    for i=1,20 do
        serverMobGroup:addRandomMobGroup(storyTribeID, averagePosition, avoidLateGameMobs)

        --[[serverGOM:callFunctionForRandomSapienInTribe(storyTribeID, function(sapien)
            serverMobGroup:addRandomMobGroup(sapien.normalizedPos, averagePosition, avoidLateGameMobs)
        end)]]
    end
end

function serverMobGroup:spawnMigratingMobGroup(storyTribeID)
    local averagePosition = serverDestination:getDestinationState(storyTribeID).normalizedPos
    local avoidLateGameMobs = false

    local destinationState = serverDestination:getDestinationState(storyTribeID)
    local tribePopulation = (destinationState and destinationState.population) or 0

    if tribePopulation < 30 then --reduce late game mod spawn rate to 1/4 if you have a population < 30
        avoidLateGameMobs = rng:randomInteger(4) > 0
    end

    --[[local spawnSuccess = false
    serverGOM:callFunctionForRandomSapienInTribe(storyTribeID, function(sapien)
        mj:log("serverMobGroup:spawnMigratingMobGroup for sapien:", sapien.uniqueID)
        spawnSuccess = serverMobGroup:addRandomMobGroup(sapien.normalizedPos, averagePosition, avoidLateGameMobs)
    end)]]

    return serverMobGroup:addRandomMobGroup(storyTribeID, averagePosition, avoidLateGameMobs)
end

function serverMobGroup:init(serverGOM_, serverTerrain_, serverMob_)
    serverGOM = serverGOM_
    serverTerrain = serverTerrain_
    serverMob = serverMob_
end


return serverMobGroup