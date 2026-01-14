local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local dot = mjm.dot
--local cross = mjm.cross
local length2 = mjm.length2
local normalize = mjm.normalize
--local randomPointWithinTriangle = mjm.randomPointWithinTriangle
--local clamp = mjm.clamp

local rng = mjrequire "common/randomNumberGenerator"
--local resource = mjrequire "common/resource"
--local biome = mjrequire "common/biome"
local gameObject = mjrequire "common/gameObject"
local gameConstants = mjrequire "common/gameConstants"
local sapienConstants = mjrequire "common/sapienConstants"
local planHelper = mjrequire "common/planHelper"
local skill = mjrequire "common/skill"
local weather = mjrequire "common/weather"
local destination = mjrequire "common/destination"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
--local terrainTypesModule = mjrequire "common/terrainTypes"
local statusEffect = mjrequire "common/statusEffect"
local notification = mjrequire "common/notification"
local quest = mjrequire "common/quest"
local industry = mjrequire "common/industry"
local sapienTrait = mjrequire "common/sapienTrait"

local serverTutorialState = mjrequire "server/serverTutorialState"
local anchor = mjrequire "server/anchor"
local serverTribeAIPlayer = mjrequire "server/serverTribeAIPlayer"
--local serverQuest = mjrequire "server/serverQuest"
local serverResourceManager = mjrequire "server/serverResourceManager"
--local serverStatusEffects = mjrequire "server/serverStatusEffects"
local serverDestinationBuilder = mjrequire "server/serverDestinationBuilder"
local serverNotifications = mjrequire "server/serverNotifications"
local serverStorageArea = mjrequire "server/serverStorageArea"
local villageBlueprintBuilder = mjrequire "server/blueprints/villageBlueprintBuilder"
local nameLists = mjrequire "common/nameLists"

local serverTribe = {}


--tribeRelationship

-- recruitment tasks

-- find lost sapien
-- treat medical event
-- bring supplies from location
-- build x beds, collect x more food, craft x pick axes


local server = nil
local serverWorld = nil
local serverGOM = nil
local serverSapien = nil
local serverSapienAI = nil
local terrain = nil
local serverDestination = nil



local noise = mjNoise(7185, 0.6) --seed, persistance

local function getNoiseValue(pos)
    local noiseLookup = (pos + vec3(1.2,1.2,1.2)) * 99
    return noise:get(noiseLookup, 2)
end


function serverTribe:init(server_, serverWorld_, serverGOM_, serverSapien_, serverTerrain_, serverDestination_, serverCraftArea_)
    server = server_
    serverWorld = serverWorld_
    serverGOM = serverGOM_
    serverSapien = serverSapien_
    terrain = serverTerrain_
    serverDestination = serverDestination_
    serverSapienAI = serverSapien.serverSapienAI

    serverDestinationBuilder:init(serverWorld, serverGOM, serverSapien)
    serverTribeAIPlayer:init(serverWorld, serverGOM, serverTribe, serverDestination, serverDestinationBuilder, serverCraftArea_)
end

local function loadHibernatedDestinationAndSpawnSapiensForTribe(destinationState)
    terrain:loadAreaAtLevels(destinationState.normalizedPos, mj.SUBDIVISIONS - 4, mj.SUBDIVISIONS - 1)

    local counter = 1
    local spawnedSapien = false

    for i,hibernationState in ipairs(destinationState.hibernatingSapienStates) do
        local result = nil
        if hibernationState.pos then
            result = serverSapien:createSapienObjectAtPos(hibernationState.uniqueID, hibernationState.states, destinationState.tribeID, hibernationState.pos, hibernationState.rotation)
        else --legacy path for 0.5.0.0 -> 0.5.0.13
            result = serverSapien:createSapienObject(hibernationState.uniqueID, hibernationState.states, destinationState.tribeID, destinationState.normalizedPos, counter)
        end
        mj:log("loadHibernatedDestinationAndSpawnSapiensForTribe new spawned sapien result:",result)
        if result then
            spawnedSapien = true
        end
        counter = counter + 1
    end

    if spawnedSapien then
        destinationState.hibernatingSapienStates = nil
        destinationState.loadState = destination.loadStates.loaded
		planHelper:setDiscoveriesForTribeID(destinationState.destinationID, destinationState.discoveries, destinationState.craftableDiscoveries)
        serverDestination:saveDestinationState(destinationState.destinationID)
        anchor:updateAnchorsForTribeLoadStateChange(destinationState.destinationID)
        serverTribeAIPlayer:addDestination(destinationState)
    end
end

function serverTribe:getNextIndustryType()
    if gameConstants.debugSingleIndustryTypeKey then
        mj:log("getNextIndustryType returning gameConstants.debugSingleIndustryTypeKey:", gameConstants.debugSingleIndustryTypeKey)
        return industry.types[gameConstants.debugSingleIndustryTypeKey].index
    end
    
    local industryAssignList = serverWorld.worldDatabase:dataForKey("industryAssignList")

    if not (industryAssignList and industryAssignList[1]) then
        industryAssignList = {}
        for i,industryType in ipairs(industry.validTypes) do
            local randomIndex = rng:randomInteger(#industryAssignList + 1) + 1
            table.insert(industryAssignList, randomIndex, industryType.index)
        end
        --mj:log("industryAssignList:", industryAssignList)
    end

    local industryTypeIndex = industryAssignList[#industryAssignList]
    --mj:log("industryTypeIndex:", industryTypeIndex)
    table.remove(industryAssignList, #industryAssignList)

    serverWorld.worldDatabase:setDataForKey(industryAssignList, "industryAssignList")

    return industryTypeIndex
end

local function createDestinationObjectsAndSpawnSapiensForTribe(destinationState, clientID) --can be an ai tribe being created, with no clientID
    local counter = 1
    local spawnedSapien = false
    local sapienIDs = {}

    destinationState.seenResourceObjectTypes = {}

    --mj:log("createDestinationObjectsAndSpawnSapiensForTribe destinationState.creationSapienStates:", destinationState.creationSapienStates)

    if not destinationState.creationSapienStates then
        serverTribe:assignCreationSapienStates(destinationState)
    end

    for sapienID,states in pairs(destinationState.creationSapienStates) do
        --mj:log("sapienID:", sapienID, "states:",states)
        local result = serverSapien:createSapienObject(sapienID, states, destinationState.tribeID, destinationState.normalizedPos, counter)
        if result then
            --mj:log("creating new spawned sapien:",sapienID)
            spawnedSapien = true
            table.insert(sapienIDs, sapienID)
        end
        counter = counter + 1
    end
    if spawnedSapien then
        --mj:log("spawned sapiens")
        destinationState.creationSapienStates = nil
        destinationState.spawnSapienCount = nil
        --destinationState.population = counter
        destinationState.discoveries = {}
        destinationState.craftableDiscoveries = {}
        destinationState.clientID = clientID
        destinationState.clientDisconnectWorldTime = nil
        destinationState.loadState = destination.loadStates.loaded
        destinationState.destinationTypeIndex = destination.types.staticTribe.index

        if clientID then
            serverWorld:addValidOwnerTribe(destinationState.tribeID)
            destinationState.tradeables = nil
            destinationState.relationships = nil
        end


		planHelper:setDiscoveriesForTribeID(destinationState.tribeID, destinationState.discoveries, destinationState.craftableDiscoveries)

        terrain:loadAreaAtLevels(destinationState.normalizedPos, mj.SUBDIVISIONS - 4, mj.SUBDIVISIONS - 1)

        serverTribe:updateTribeCenters()
        serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = destinationState
        serverResourceManager:addTribe(destinationState)
        serverTribe:updateSapienProximityCallbacks()

        local pos = terrain:getHighestDetailTerrainPointAtPoint(destinationState.normalizedPos)
        local resourcesToAssign = serverResourceManager:getAllResourceObjectTypesForTribe(destinationState.tribeID, pos)
        for i,objectTypeIndex in ipairs(resourcesToAssign) do
            destinationState.seenResourceObjectTypes[objectTypeIndex] = true
        end

        if (not clientID) and (not destinationState.nomad) then
            if not destinationState.industryTypeIndex then
                destinationState.industryTypeIndex = serverTribe:getNextIndustryType()()
            end
            local industryType = industry.types[destinationState.industryTypeIndex]


            local additionalNodes = nil
            if industryType.blueprintName then
                local blueprint = mjrequire("server/blueprints/industry/" .. industryType.blueprintName)
                additionalNodes = blueprint.nodes
            end

            local blueprint = villageBlueprintBuilder:buildBlueprint(additionalNodes)
            serverDestinationBuilder:loadBlueprint(destinationState, sapienIDs, blueprint, nil)
        end
            

        --mj:log("saving tribe state:", destinationState)

        serverDestination:saveDestinationState(destinationState.tribeID)

        if clientID then
            serverWorld:addPlayerControlledTribe(destinationState.tribeID, clientID)
        elseif destinationState.loadState == destination.loadStates.loaded then
            serverTribeAIPlayer:addDestination(destinationState)
        end
        

        serverWorld:updateFollowerCount(destinationState.tribeID)
        serverGOM:sendFollowersListsForSapienCountChange(destinationState.tribeID)

        --mj.debugObject = sapienIDs[1]
        
        return true
    end

    return false
end

function serverTribe:getTribeState(tribeID)
    return serverDestination:getDestinationState(tribeID)
end

function serverTribe:clientRequestSelectStartTribe(clientID, tribeID, ownedByClient)
    local destinationState = serverDestination:getDestinationState(tribeID)
    local requiresAllowDueToIncorrectFailedTribeState = (destinationState and destinationState.failedTribe and destinationState.hibernatingSapienStates) --this is to work around as bug where tribes were marked failed when hibernating in 0.7 beta
    if destinationState and (ownedByClient or (not destinationState.clientID) or requiresAllowDueToIncorrectFailedTribeState) then
        --mj:log("serverTribe:clientRequestSelectStartTribe destinationState:", destinationState)

        if (not destinationState.loadState) or (destinationState.loadState == destination.loadStates.seed) then
            if createDestinationObjectsAndSpawnSapiensForTribe(destinationState, clientID) then
                if gameConstants.debugCreateCloseTribeCount then
                    local pos = terrain:getHighestDetailTerrainPointAtPoint(destinationState.normalizedPos)
                    serverTribe:createDebugCloseTribes(pos, clientID, gameConstants.debugCreateCloseTribeCount)
                end

                return destinationState
            end
        else
            if gameConstants.debugAllowPlayersToTakeOverAITribes or ownedByClient or requiresAllowDueToIncorrectFailedTribeState then
                if destinationState.loadState == destination.loadStates.hibernating then
                    --mj:log("player is taking over hibernating tribe, waking them up.")
                    local hibernatingLoadFunction = serverDestination.hibernatingLoadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex]
                    hibernatingLoadFunction(destinationState)
                end

                if destinationState.loadState == destination.loadStates.loaded then

                    local sapienIDs = {}
                    
                    serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function (sapienID) 
                        local sapien = serverGOM:getObjectWithID(sapienID)
                        if sapien then
                            local state = sapien.sharedState
                            if state and state.tribeID == tribeID then
                                table.insert(sapienIDs, sapienID)
                            end
                        end
                    end)

                    --mj:log("player is taking over loaded tribe. sapien count:", #sapienIDs, " destinationState:", destinationState)
                    destinationState.clientID = clientID
                    destinationState.clientDisconnectWorldTime = nil

                    serverWorld:addValidOwnerTribe(destinationState.tribeID)
                    planHelper:setDiscoveriesForTribeID(destinationState.tribeID, destinationState.discoveries, destinationState.craftableDiscoveries)
                    serverTribeAIPlayer:removeDestination(destinationState)

                    destinationState.tradeables = nil
                    destinationState.relationships = nil
                    destinationState.destinationTypeIndex = destination.types.staticTribe.index
                    destinationState.assignedToClientWorldTime = serverWorld:getWorldTime() --only added in 0.7

                    --warning, duplicate code! this needs tidying, if you add any init stuff here, add it above in createDestinationObjectsAndSpawnSapiensForTribe too, or fix

                    --serverWorld:setClientFollowerCount(clientID, #sapienIDs, destinationState.tribeID)
                    --serverWorld:updateFollowerCount(destinationState.tribeID)
                    terrain:loadAreaAtLevels(destinationState.normalizedPos, mj.SUBDIVISIONS - 4, mj.SUBDIVISIONS - 1)
            
                    local resourcesToAssign = serverResourceManager:getAllResourceObjectTypesForTribe(destinationState.tribeID)
                    for i,objectTypeIndex in ipairs(resourcesToAssign) do
                        destinationState.seenResourceObjectTypes[objectTypeIndex] = true
                    end
            
                    serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = destinationState
            
                    serverTribe:updateTribeCenters()
                    serverResourceManager:addTribe(destinationState)
                    serverTribe:updateSapienProximityCallbacks()
                    
                    serverDestination:saveDestinationState(destinationState.tribeID)
            
                    serverWorld:addPlayerControlledTribe(destinationState.tribeID, clientID)
                    --serverGOM:clientFollowersAdded(destinationState.tribeID, sapienIDs)
                    serverGOM:sendFollowersListsForSapienCountChange(destinationState.tribeID)

                    serverTribe:recalculatePopulation(destinationState.destinationID)
                    serverWorld:updateFollowerCount(destinationState.destinationID)

                    return destinationState
                end
            end
        end
    end
    mj:error("Failed to load any sapiens for tribe selection")
    return nil
end

function serverTribe:loadSapiensForSeedDestination(destinationState)
    createDestinationObjectsAndSpawnSapiensForTribe(destinationState, nil)
end

local function sanitizeSapienSharedState(sharedState)
    local sharedStateCopy = mj:cloneTable(sharedState)
    sharedStateCopy.orderQueue = {}
    sharedStateCopy.actionState = nil
    sharedStateCopy.activeOrder = nil
    sharedStateCopy.actionModifiers = nil
    --mj:log("sanitizeSharedState sharedState:", sharedStateCopy)
    return sharedStateCopy
end

function serverTribe:hibernateTribe(destinationState)


    local function sanitizePrivateState(privateState)
        return {
            version = serverSapien.sapienSaveStateVersion
        }
    end

    local function sanitizeLazyPrivateState(lazyPrivateState)
        return {
            relationships = {},
        }
    end

    local hibernatingSapienStates = {}
    serverGOM:callFunctionForAllSapiensInTribe(destinationState.destinationID, function(sapien)
        local hibernationState = {
            uniqueID = sapien.uniqueID,
            pos = sapien.pos,
            rotation = sapien.rotation,
            states = {
                sharedState = sanitizeSapienSharedState(sapien.sharedState),
                privateState = sanitizePrivateState(sapien.privateState),
                lazyPrivateState = sanitizeLazyPrivateState(sapien.lazyPrivateState),
            },
        }
        table.insert(hibernatingSapienStates, hibernationState)
    end) 
    destinationState.hibernatingSapienStates = hibernatingSapienStates --NOTE! We must set hibernatingSapienStates here to ensure that updateFollowerCount exits early when serverSapien:removeSapien is called and doesn't fail the tribe
    serverDestination:saveDestinationState(destinationState.destinationID)

    for i,hibernationState in ipairs(hibernatingSapienStates) do
        local sapien = serverGOM:getObjectWithID(hibernationState.uniqueID)
        serverSapien:removeSapien(sapien, false, false)
    end

    anchor:updateAnchorsForTribeLoadStateChange(destinationState.destinationID)

    if destinationState.clientID then
        server:clientHibernated(destinationState.clientID)
    end
end

function serverTribe:wakeHibernatingTribe(destinationState)
    loadHibernatedDestinationAndSpawnSapiensForTribe(destinationState)
end


function serverTribe:startNomadTribeExit(destinationState)
    destinationState.exiting = true
    serverDestination:saveDestinationState(destinationState.tribeID)
    serverTutorialState:tribeStartedExiting(destinationState.tribeID)
end

function serverTribe:updateNomadTribeExitState(tribeState)
    if not tribeState.exiting and tribeState.nomad then
        local worldTime = serverWorld:getWorldTime()
        local goalTime = tribeState.nomadState.goalTime

        if worldTime > goalTime then
            serverTribe:startNomadTribeExit(tribeState)
        end
        
        --let's try just this ^^^ instead of that vvv
        --[[
        if tribeState.nomadState.tribeBehaviorTypeIndex == nomadTribeBehavior.types.foodRaid.index then
            if worldTime > tribeState.nomadState.exitTime - (tribeState.nomadState.exitTime - goalTime) * 0.5 then
                startExit()
            end
        else
            if worldTime > goalTime then
                startExit()
            end
        end]]
    end
end



local baseRoles = {
    skill.types.researching.index,
    --skill.types.gathering.index, --now always set
    --skill.types.basicBuilding.index, --now always set
    --skill.types.diplomacy.index,
}

function serverTribe:createTribeDestination(destinationID, tribeCenterNormalized, creationInfoOrNil, extraDestinationStateOrNil, biomeTagsOrNil)

    local biomeTags = biomeTagsOrNil
    
    if not biomeTags then
        biomeTags = serverDestination:getBiomeTagsIfSuitableForTribeSpawn(tribeCenterNormalized, destinationID)
        if not biomeTags then
            return nil
        end
    end


    local minSapienCount = 2
    local maxSapienCount = 12
    if creationInfoOrNil then
        if creationInfoOrNil.minSpawnCount and creationInfoOrNil.maxSpawnCount then
            minSapienCount = creationInfoOrNil.minSpawnCount
            maxSapienCount = creationInfoOrNil.maxSpawnCount
        end
    end

    local count = minSapienCount
    if maxSapienCount - minSapienCount > 0 then
        count = count + rng:integerForUniqueID(destinationID, 35923, maxSapienCount - minSapienCount + 1)
    end
    

    --mj:log("serverTribe:createTribeDestination spawn count:", count, " minSapienCount:", minSapienCount, " maxSapienCount:", maxSapienCount)

    local faceID = terrain:getFaceIDForNormalizedPointAtLevel(tribeCenterNormalized, serverDestination.faceLevel)

    local destinationState = {
        destinationTypeIndex = (extraDestinationStateOrNil and extraDestinationStateOrNil.destinationTypeIndex) or destination.types.staticTribe.index,
        faceID = faceID,
        destinationID = destinationID,
        normalizedPos = tribeCenterNormalized,
        pos = terrain:getHighestDetailTerrainPointAtPoint(tribeCenterNormalized),
        
        tribeID = destinationID,
        name = nameLists:generateTribeName(destinationID, 3634),
        --creationSapienStates = sapienStatesBySapienID,
        spawnSapienCount = count,
        population = count,
        biomeTags = biomeTags,

        extraSapienSharedState = creationInfoOrNil and creationInfoOrNil.extraSapienSharedState,
        tribeHasVirus = creationInfoOrNil and creationInfoOrNil.tribeHasVirus,

        --industryTypeIndex = getNextIndustryType(),
    }

    if extraDestinationStateOrNil then
        for k,v in pairs(extraDestinationStateOrNil) do
            destinationState[k] = v
        end
        if extraDestinationStateOrNil.nomad then
            destinationState.destinationTypeIndex = destination.types.nomadTribe.index
        end
    end

    serverDestination:saveNewDestination(destinationState)
    

    return destinationState
end

local function generateSapienStates(destinationState, generationSeedOffset, spawnSapienCount)

    local isNomad = (destinationState.destinationTypeIndex == destination.types.nomadTribe.index)
    local biomeTags = destinationState.biomeTags
    local tribeCenterNormalized = destinationState.normalizedPos
    local tribeHasVirus = destinationState.tribeHasVirus
    local extraSapienSharedState = destinationState.extraSapienSharedState
    local destinationID = destinationState.destinationID

    local addChildren = true --could be passed through destinationState, but for now all tribes have children
    --local preventLimitedAbility = false

    local sapienStatesBySapienID = {}
    local sapienIDsArray = {}
    
    local temperatureZones = weather:getTemperatureZones(biomeTags)

    local averageSkinColorFraction = 0.5

    if isNomad then
        averageSkinColorFraction = rng:valueForUniqueID(destinationID, 228876 + generationSeedOffset)
        if nomadTribeBehavior.types[extraSapienSharedState.tribeBehaviorTypeIndex].preventLimitedAbility then
            --preventLimitedAbility = true
            addChildren = false
        end
    else
        local noiseValue = getNoiseValue(tribeCenterNormalized)
        averageSkinColorFraction = (noiseValue + 1.0) * 0.5
    end

    local hairColorCount = 5
    local eyeColorCount = 4

    local averageHairColorGene = rng:integerForUniqueID(destinationID, 72872 + generationSeedOffset, hairColorCount) + 1
    local averageEyeColorGene = rng:integerForUniqueID(destinationID, 72754 + generationSeedOffset, eyeColorCount) + 1
    
    local function getSkinColorWithOffset(seedOffset)
        local skinColorOffset = (rng:valueForUniqueID(destinationID, 5474 + seedOffset + generationSeedOffset) - 0.5) * 0.1
        return mjm.clamp(averageSkinColorFraction + skinColorOffset, 0.0, 1.0)
    end

    local function getHairColorWithOffset(seedOffset)
        local offset = rng:integerForUniqueID(destinationID, 236212 + seedOffset + generationSeedOffset, 4)
        if offset == 1 then
            return math.min(averageHairColorGene + 1, hairColorCount)
        elseif offset ==2 then
            return math.max(averageHairColorGene - 1, 1)
        else
            return averageHairColorGene
        end
    end

    local function getEyeColorWithOffset(seedOffset)
        local offset = rng:integerForUniqueID(destinationID, 2416 + seedOffset + generationSeedOffset, 8)
        if offset == 1 then
            return math.min(averageEyeColorGene + 1, eyeColorCount)
        elseif offset ==2 then
            return math.max(averageEyeColorGene - 1, 1)
        else
            return averageEyeColorGene
        end
    end


    --[[local function assignRelationshipScore(relationships, otherSapienID, score)
        local relationshipInfo = relationships[otherSapienID]
        if not relationshipInfo then
            relationshipInfo = {}
            relationships[otherSapienID] = relationshipInfo
        end
        relationshipInfo.score = score
    end]]

    
    local function generateRandomRelationship(uniqueID, baseBond, bondVariation, familyRelationshipType)
        local longTermMood = mjm.clamp(rng:valueForUniqueID(uniqueID, rng:getRandomSeed()) * 0.6 + 0.4, 0.0, 1.0)
        return {
            mood = {
                short = mjm.clamp(longTermMood + (rng:valueForUniqueID(uniqueID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = longTermMood,
            },
            bond = {
                short = mjm.clamp(rng:valueForUniqueID(uniqueID, rng:getRandomSeed()) * bondVariation + baseBond * 0.8, 0.0, 1.0),
                long =  mjm.clamp(longTermMood * 0.5 + (rng:valueForUniqueID(uniqueID, rng:getRandomSeed()) * bondVariation + baseBond) * 0.5, 0.0, 1.0),
            },
            familyRelationshipType = familyRelationshipType,
        }

    end

    

    local potentialMothers = {}
    local potentialFatherCount = 0

    
    local roleInfosBySapienIndex = {}
    local tribeInitialRolesSet = {}

    local function createSkillsArray(index, rollsInfo)
        local initialRolesArray = {}
        local sapienInitialRolesSet = {}

        local function addRequiredSkill(skillTypeIndex)
            table.insert(initialRolesArray, skillTypeIndex)
            sapienInitialRolesSet[skillTypeIndex] = true
            tribeInitialRolesSet[skillTypeIndex] = true
        end

        addRequiredSkill(skill.types.gathering.index)
        addRequiredSkill(skill.types.basicBuilding.index)
        
        --[[if counter <= #baseRoles then
            initialRolesSet[baseRoles[counter] ] = true
            table.insert(initialRolesArray, baseRoles[counter])
        end]]

        local function addRandomSkill(seed)
            local skillArrayIndex = rng:integerForUniqueID(destinationID, seed + index + generationSeedOffset, #baseRoles) + 1
            local skillTypeIndex = baseRoles[skillArrayIndex]
            if not sapienInitialRolesSet[skillTypeIndex] then
                sapienInitialRolesSet[skillTypeIndex] = true
                tribeInitialRolesSet[skillTypeIndex] = true
                table.insert(initialRolesArray, skillTypeIndex)
            end
        end

        addRandomSkill(690)
        addRandomSkill(952)

        rollsInfo.sapienInitialRolesSet = sapienInitialRolesSet
        rollsInfo.initialRolesArray = initialRolesArray
    end
    
    for i=1,spawnSapienCount do
        local rollsInfo = {}
        roleInfosBySapienIndex[i] = rollsInfo
        createSkillsArray(i, rollsInfo)
    end

   -- mj:log("tribeInitialRolesSet:", tribeInitialRolesSet)

    local sapienIndexCounter = rng:integerForUniqueID(destinationID, 23829 + generationSeedOffset, spawnSapienCount)
    for i,skillTypeIndex in ipairs(baseRoles) do
        if not tribeInitialRolesSet[skillTypeIndex] then
            local sapienIndex = (sapienIndexCounter % spawnSapienCount) + 1
            sapienIndexCounter = sapienIndexCounter + 1
            --mj:log("adding missing role:", roleInfosBySapienIndex[sapienIndex].initialRolesArray)
            table.insert(roleInfosBySapienIndex[sapienIndex].initialRolesArray, skillTypeIndex)
            --mj:log("added missing role:", roleInfosBySapienIndex[sapienIndex].initialRolesArray)
        end
    end

    local function addAdultSapien(counter)
        local sapienID = serverGOM:reserveUniqueID()
        
        local extraState = {
            skinColorFraction = getSkinColorWithOffset(counter),
            hairColorGene = getHairColorWithOffset(counter),
            eyeColorGene = getEyeColorWithOffset(counter),
        }

        if extraSapienSharedState then
            for k,v in pairs(extraSapienSharedState) do
                extraState[k] = v
            end
        end

        local initialRolesArray = roleInfosBySapienIndex[counter].initialRolesArray

        local lifeStage = sapienConstants.lifeStages.adult.index
        if rng:integerForUniqueID(sapienID, 334584, 4) == 1 then
            lifeStage = sapienConstants.lifeStages.elder.index
        end
        
        local sapienStates = serverSapien:createInitialTribeSpawnSapienStates(destinationID, counter + generationSeedOffset, lifeStage, extraState, initialRolesArray, temperatureZones, isNomad, tribeCenterNormalized)

        sapienStatesBySapienID[sapienID] = sapienStates
        table.insert(sapienIDsArray, sapienID)
        local sharedState = sapienStates.sharedState
        if lifeStage == sapienConstants.lifeStages.adult.index then
            if sharedState.isFemale then
                table.insert(potentialMothers, sapienID)
                sharedState.pregnancyOrBabyTimer = rng:valueForUniqueID(sapienID, 1135) * 0.8
            else
                potentialFatherCount = potentialFatherCount + 1
            end
        end
        

        if tribeHasVirus then
            local virusRandom = rng:randomInteger(15)
            if virusRandom < 7 then
                if virusRandom == 1 then
                    sharedState.statusEffects[statusEffect.types.majorVirus.index] = {
                        timer = sapienConstants.virusDuration * (0.5 + rng:randomValue() * 0.5)
                    }
                else
                    sharedState.statusEffects[statusEffect.types.minorVirus.index] = {
                        timer = sapienConstants.virusDuration * (0.5 + rng:randomValue() * 0.5)
                    }
                end
            elseif virusRandom < 12 then
                sharedState.statusEffects[statusEffect.types.incubatingVirus.index] = {
                    timer = sapienConstants.virusIncubationDuration * (0.5 + rng:randomValue() * 0.5)
                }
            else
                sharedState.statusEffects[statusEffect.types.virusImmunity.index] = {
                    timer = sapienConstants.virusImmunityDuration * (0.5 + rng:randomValue() * 0.5)
                }
            end
        end
    end

    local adultCount = spawnSapienCount
    if addChildren then
        adultCount = math.max(math.ceil(spawnSapienCount / 2), 1)
    end
    
    for i=1,adultCount do
        addAdultSapien(i)
    end

    
    if addChildren then
        if potentialFatherCount == 0 then
            addChildren = (rng:integerForUniqueID(destinationID, 82453 + generationSeedOffset, 4) == 1)
        end
    end

    
    
    local function assignVariationOfChildRelationshipForOtherSapien(childSapienID, otherSapienID, childRelationships, motherRelationshipInfo, childRelationshipInfo, otherSapienLazyPrivateState)
        local variation = {
            mood = {
                short = mjm.clamp(childRelationshipInfo.mood.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = mjm.clamp(childRelationshipInfo.mood.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
            },
            bond = {
                short = mjm.clamp(childRelationshipInfo.bond.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
                long = mjm.clamp(childRelationshipInfo.bond.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
            },
        }


        if motherRelationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.biologicalChild then
            variation.familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
            childRelationships[otherSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
        end
            
        otherSapienLazyPrivateState.relationships[childSapienID] = variation
    end

    local function assignVariationOfMotherRelationshipForChild(childSapienID, otherSapienID, fatherID, childRelationships, motherRelationshipInfo, otherSapienLazyPrivateState)
        local variation = {
            mood = {
                short = mjm.clamp(motherRelationshipInfo.mood.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.6, 0.0, 1.0),
                long = mjm.clamp(motherRelationshipInfo.mood.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.4, 0.0, 1.0),
            },
            bond = {
                short = mjm.clamp(motherRelationshipInfo.bond.short + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.2, 0.0, 1.0),
                long = mjm.clamp(motherRelationshipInfo.bond.long + (rng:valueForUniqueID(childSapienID, rng:getRandomSeed()) - 0.5) * 0.1, 0.0, 1.0),
            },
        }

        childRelationships[otherSapienID] =  variation
    end

    local babyCount = 0

    --mj:log("addChildren:", addChildren)
    if addChildren then
        local randomChildSeedCounter = 1 + generationSeedOffset
        for i,motherID in ipairs(potentialMothers) do
            if #sapienIDsArray + babyCount >= spawnSapienCount then
                break
            end
            randomChildSeedCounter = randomChildSeedCounter + 1
            local childCount = rng:integerForUniqueID(destinationID, 3924 + randomChildSeedCounter, 6) - 3
            if potentialFatherCount > 1 then
                childCount = childCount + 1
            end
            
            --mj:log("childCount a:", childCount)
            if childCount > 0 then
                local babyChance = rng:integerForUniqueID(destinationID, 43534 + randomChildSeedCounter, 4)
                if babyChance == 1 then
                    local motherStates = sapienStatesBySapienID[motherID]
                    local hasBaby = rng:boolForUniqueID(motherID, 1134)
                    if hasBaby then
                        motherStates.sharedState.hasBaby = true
                        babyCount = babyCount + 1
                    else
                        motherStates.sharedState.pregnant = true
                    end

                    childCount = childCount - 1
                end
            end

            --mj:log("childCount b:", childCount)
            if childCount > 0 then
                local motherStates = sapienStatesBySapienID[motherID]

                --local childrenByThisMotherByID = {}

                for j=1,childCount do
                    if #sapienIDsArray + babyCount >= spawnSapienCount then
                        break
                    end
                    
                    local extraState = {
                        skinColorFraction = motherStates.sharedState.skinColorFraction,
                        hairColorGene = motherStates.sharedState.hairColorGene,
                        eyeColorGene = motherStates.sharedState.eyeColorGene,
                    }

                    if extraSapienSharedState then
                        for k,v in pairs(extraSapienSharedState) do
                            extraState[k] = v
                        end
                    end
                        
                    local initialRoles = {}
                    for skillTypeIndex,priority in pairs(motherStates.sharedState.skillPriorities) do
                        table.insert(initialRoles, skillTypeIndex)
                    end

                    local childSapienStates = serverSapien:createInitialTribeSpawnSapienStates(destinationID, 285311 + randomChildSeedCounter, sapienConstants.lifeStages.child.index, extraState, initialRoles, temperatureZones, isNomad, tribeCenterNormalized)
                    randomChildSeedCounter = randomChildSeedCounter + 1
                    if childSapienStates then
                        local childSapienID = serverGOM:reserveUniqueID()
                        sapienStatesBySapienID[childSapienID] = childSapienStates
                        table.insert(sapienIDsArray, childSapienID)

                        --childrenByThisMotherByID[childSapienID] = childSapienStates

                        local childRelationships = childSapienStates.lazyPrivateState.relationships
                        childRelationships[motherID] = generateRandomRelationship(childSapienID, 0.95, 0.05, sapienConstants.familyRelationshipTypes.mother)
                        
                        local motherRelationships = motherStates.lazyPrivateState.relationships
                        motherRelationships[childSapienID] = generateRandomRelationship(childSapienID, 0.95, 0.05, sapienConstants.familyRelationshipTypes.biologicalChild)

                        local potentialFatherIDs = {}
                        local highestFatherBond = -1
                        local highestFatherID = nil
                        local fatherID = nil
                        
                        for otherSapienID,relationshipInfo in pairs(motherRelationships) do
                            local otherSapienStates = sapienStatesBySapienID[otherSapienID]
                            local otherSapienSharedState = otherSapienStates.sharedState
                            if (not otherSapienSharedState.isFemale) and (otherSapienSharedState.lifeStageIndex == sapienConstants.lifeStages.adult.index) then
                                table.insert(potentialFatherIDs, otherSapienID)
                                if motherRelationships[otherSapienID].bond.long > highestFatherBond then
                                    highestFatherID = otherSapienID
                                    highestFatherBond = motherRelationships[otherSapienID].bond.long
                                end
                            end
                        end

                        local randomFatherType = rng:integerForUniqueID(childSapienID, 2332 + rng:getRandomSeed(), 3)

                        if randomFatherType > 0 then
                            if #potentialFatherIDs <= 1 or randomFatherType == 1 then
                                fatherID = highestFatherID
                            else
                                local randomIndex = rng:integerForUniqueID(childSapienID, 32454 + rng:getRandomSeed(), #potentialFatherIDs) + 1
                                fatherID = potentialFatherIDs[randomIndex]
                            end
                        end
                        
                        for otherSapienID,relationshipInfo in pairs(motherRelationships) do -- create child relationships according to mother relationships
                            if otherSapienID ~= childSapienID then
                                local otherSapienStates = sapienStatesBySapienID[otherSapienID]
                                local otherSapienLazyPrivateState = otherSapienStates.lazyPrivateState

                                assignVariationOfMotherRelationshipForChild(childSapienID, otherSapienID, fatherID, childRelationships, motherRelationships[otherSapienID], otherSapienLazyPrivateState)
                                assignVariationOfChildRelationshipForOtherSapien(childSapienID, otherSapienID, childRelationships, motherRelationships[otherSapienID], childRelationships[otherSapienID], otherSapienLazyPrivateState)

                                if otherSapienID == fatherID then
                                    childRelationships[otherSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.father
                                    otherSapienLazyPrivateState.relationships[childSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.biologicalChild
                                end
                            end
                        end

                        
                        local fatherRelationships = nil
                        if fatherID then
                            local fatherStates = sapienStatesBySapienID[fatherID]
                            if fatherStates then
                                fatherRelationships = fatherStates.lazyPrivateState.relationships
                            end
                        end

                        if fatherRelationships then
                            for otherSapienID,fatherRelationshipInfo in pairs(fatherRelationships) do
                                if otherSapienID ~= childSapienID then
                                    local otherSapienStates = sapienStatesBySapienID[otherSapienID]
                                    if otherSapienStates then
                                        if fatherRelationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.biologicalChild then
                                            if childRelationships[otherSapienID] and otherSapienStates.lazyPrivateState.relationships[childSapienID] then
                                                otherSapienStates.lazyPrivateState.relationships[childSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
                                                childRelationships[otherSapienID].familyRelationshipType = sapienConstants.familyRelationshipTypes.sibling
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local createdSapienCount = #sapienIDsArray
    local remainingCountToAdd = spawnSapienCount - createdSapienCount - babyCount
    for i=1,remainingCountToAdd do
        addAdultSapien(createdSapienCount + i)
    end


    for i,sapienID in ipairs(sapienIDsArray) do
        local sapienStates = sapienStatesBySapienID[sapienID]

        local randomCloseIndexA = rng:integerForUniqueID(sapienID, 5675634, #sapienIDsArray)
        local randomCloseIndexB = rng:integerForUniqueID(sapienID, 5436232, #sapienIDsArray)

        for j=i +1, #sapienIDsArray do
            local otherSapienID = sapienIDsArray[j]
            local otherSapienStates = sapienStatesBySapienID[otherSapienID]
            local baseBond = 0.4
            local bondVariation = 0.4

            if j == randomCloseIndexA or j == randomCloseIndexB then
                baseBond = 0.8
                bondVariation = 0.2
            end

            sapienStates.lazyPrivateState.relationships[otherSapienID] = generateRandomRelationship(sapienID, baseBond, bondVariation, nil)
            otherSapienStates.lazyPrivateState.relationships[sapienID] = generateRandomRelationship(otherSapienID, baseBond, bondVariation, nil)
        end
    end

    return {
        sapienStatesBySapienID = sapienStatesBySapienID,
        population = #sapienIDsArray + babyCount,
    }
end

function serverTribe:assignCreationSapienStates(destinationState)
    local spawnSapienCount = destinationState.spawnSapienCount

    local seedOffset = 0
    local creationStatesResult = generateSapienStates(destinationState, seedOffset, spawnSapienCount)

    destinationState.creationSapienStates = creationStatesResult.sapienStatesBySapienID
    destinationState.population = creationStatesResult.population

    serverDestination:saveDestinationState(destinationState.destinationID)
end

function serverTribe:recalculatePopulation(destinationID)
    local destinationState = serverDestination:getDestinationState(destinationID)
    if destinationState and destinationState.loadState == destination.loadStates.loaded then
        local newPopulation = 0
        local unprotectedByAnyAbleSapiens = true
        serverGOM:callFunctionForAllSapiensInTribe(destinationState.destinationID, function(sapien)
            newPopulation = newPopulation + 1
            if sapien.sharedState.hasBaby then
                newPopulation = newPopulation + 1
            end
            if unprotectedByAnyAbleSapiens and (not sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, false)) then
                unprotectedByAnyAbleSapiens = nil
            end
        end)

        if destinationState.population ~= newPopulation or destinationState.unprotectedByAnyAbleSapiens ~= unprotectedByAnyAbleSapiens then
            destinationState.population = newPopulation
            destinationState.unprotectedByAnyAbleSapiens = unprotectedByAnyAbleSapiens
            serverDestination:saveDestinationState(destinationState.destinationID)
        end
    end
end

function serverTribe:getPopulation(destinationID)
    local destinationState = serverDestination:getDestinationState(destinationID)
    return (destinationState and destinationState.population) or 0
end

function serverTribe:tribeAllowsPopulationGrowth(destinationID)
    return (not serverTribeAIPlayer:getIsAIPlayerTribe(destinationID)) or serverTribe:getPopulation(destinationID) < gameConstants.aiTribeMaxPopulation
end

function serverTribe:tribeRequiresPopulationGrowth(destinationID)
    local destinationState = serverDestination:getDestinationState(destinationID)
    if destinationState and (not destinationState.clientID) then
        if destinationState.population and destinationState.population <= gameConstants.aiTribeMinPopulation and destinationState.population > 0 then
            return true
        end
    end
    return false
end

function serverTribe:getOrCreateCreationSapienStatesForClientInspection(destinationID)
    local destinationState = serverDestination:getDestinationState(destinationID)
    --mj:log("serverTribe:getOrCreateCreationSapienStatesForClientInspection destinationID:", destinationID, " found:", destinationState ~= nil)
    if destinationState and ((not destinationState.clientID) or (destinationState.failedTribe and destinationState.hibernatingSapienStates)) then
        if destinationState.loadState and destinationState.loadState ~= destination.loadStates.seed then
            if destinationState.loadState == destination.loadStates.hibernating or (destinationState.failedTribe and destinationState.hibernatingSapienStates) then
                --mj:log("serverTribe:getOrCreateCreationSapienStatesForClientInspection tribe is hibernating")
                local creationSapienStates = {}
                for i,hibernationState in ipairs(destinationState.hibernatingSapienStates) do
                    creationSapienStates[hibernationState.uniqueID] = {
                        sharedState = hibernationState.states.sharedState
                    }
                end
                return creationSapienStates
            else
                local creationSapienStates = {}
                serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function (sapienID) 
                    --mj:log("serverTribe:getOrCreateCreationSapienStatesForClientInspection tribe is loaded")
                    local sapien = serverGOM:getObjectWithID(sapienID)
                    if sapien then
                        local sharedState = sapien.sharedState
                        if sharedState and sharedState.tribeID == destinationID then
                            creationSapienStates[sapienID] = {
                                sharedState = sharedState
                            }
                        end
                    end
                end)
                return creationSapienStates
            end
        else
            if not destinationState.creationSapienStates then
                serverTribe:assignCreationSapienStates(destinationState)
            end
            return destinationState.creationSapienStates
        end
    end
    return nil
end


function serverTribe:createNomadTribe(tribeCenterNormalized, creationInfo, extraTribeState)
    
    local destinationID = serverGOM:reserveUniqueID()
    local tribeState = serverTribe:createTribeDestination(destinationID, tribeCenterNormalized, creationInfo, extraTribeState, nil)

    if tribeState then
        serverTribe:assignCreationSapienStates(tribeState)
        createDestinationObjectsAndSpawnSapiensForTribe(tribeState, nil)
        return tribeState
    end

    return  nil
end

function serverTribe:createLeavingAITribe(tribeCenterNormalized, extraTribeState)
    local destinationID = serverGOM:reserveUniqueID()
    local faceID = terrain:getFaceIDForNormalizedPointAtLevel(tribeCenterNormalized, serverDestination.faceLevel)
    local destinationState = {
        destinationID = destinationID,
        tribeID = destinationID,
        faceID = faceID,
        center = tribeCenterNormalized,
        normalizedPos = tribeCenterNormalized,
        pos = terrain:getHighestDetailTerrainPointAtPoint(tribeCenterNormalized)
    }
    if extraTribeState then
        for k,v in pairs(extraTribeState) do
            destinationState[k] = v
        end
    end

    serverDestination:saveNewDestination(destinationState)

    
    serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = destinationState
    --serverResourceManager:addTribe(destinationState)
    serverTribe:updateSapienProximityCallbacks()

    return destinationState
end

function serverTribe:addSapiensToTribe(destinationState, countToAdd) --used when AI tribes population too low
    --mj:log("serverTribe:addSapiensToTribe:", countToAdd)
    if countToAdd > 0 then
        local seedOffset = rng:randomInteger(999999)
        local creationStatesResult = generateSapienStates(destinationState, seedOffset, countToAdd)

        local counter = 1
        local spawnedSapien = false
        local sapienIDs = {}

        for sapienID,states in pairs(creationStatesResult.sapienStatesBySapienID) do
            -- mj:log("sapienID:", sapienID, "states:",states)
            local result = serverSapien:createSapienObject(sapienID, states, destinationState.destinationID, destinationState.normalizedPos, seedOffset + counter)
            if result then
                --mj:log("creating new spawned sapien:",sapienID)
                spawnedSapien = true
                table.insert(sapienIDs, sapienID)
            end
            counter = counter + 1
        end
        if spawnedSapien then
            serverTribe:recalculatePopulation(destinationState.destinationID)
            serverDestination:saveDestinationState(destinationState.destinationID)
            serverWorld:updateFollowerCount(destinationState.destinationID)
        end
    end
end

function serverTribe:createCheatSapien(parentTribeID, pos)
    
    local goalTimeOffset = 800.0
    local exitTimeOffset = 1600.0

    local exitPos = normalize(pos + normalize(rng:randomVec()) * mj:mToP(500.0))
    local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(exitPos)
    exitPos = exitPos * (1.0 + terrainResult.x)

    local extraTribeState = {
        nomad = true,
        nomadState = {
            tribeBehaviorTypeIndex = nomadTribeBehavior.types.join.index,
            spawnTime = serverWorld:getWorldTime(),
            goalTime = serverWorld:getWorldTime() + goalTimeOffset,
            exitTime = serverWorld:getWorldTime() + exitTimeOffset,
            goalPos = pos,
            exitPos = exitPos,
        }
    }

    local creationInfo = {
        minSpawnCount = 1,
        maxSpawnCount = 1,
        --addChildren = false,
        extraSapienSharedState = {
            nomad = true,
            tribeBehaviorTypeIndex = nomadTribeBehavior.types.join.index, --bit of a hack, should probably use tribeID and tribeInfo
        }
    }
    
    local tribeCenterNormalized = normalize(pos)

    serverTribe:createNomadTribe(tribeCenterNormalized, creationInfo, extraTribeState)
end

local minCloseTribeDistance = mj:mToP(600.0)
local minCloseTribeDistance2 = minCloseTribeDistance * minCloseTribeDistance

function serverTribe:getOtherDestinationTooClose(nearDestinationStates, tribeCenterNormalized)
    for duid,destinationState in pairs(nearDestinationStates) do
        if length2(destinationState.normalizedPos - tribeCenterNormalized) < minCloseTribeDistance2 then
            return true
        end

        if destinationState.tribeCenters then
            for j,tribeCenter in ipairs(destinationState.tribeCenters) do
                if length2(tribeCenter.normalizedPos - tribeCenterNormalized) < minCloseTribeDistance2 then
                    return true
                end
            end
        end
    end
    return false
end

function serverTribe:getAnyOtherDestinationTooClose(thisCenter) --very brute force
    for duid,destinationState in pairs(serverDestination.destinationStatesByDestinationID) do
        if length2(destinationState.normalizedPos - thisCenter) < minCloseTribeDistance2 then
            return true
        end

        if destinationState.tribeCenters then
            for j,tribeCenter in ipairs(destinationState.tribeCenters) do
                if length2(tribeCenter.normalizedPos - thisCenter) < minCloseTribeDistance2 then
                    return true
                end
            end
        end
    end
end

function serverTribe:createRandomCloseTribes(baseTribeCenterNormal, startFace, nearDestinationStates, baseUniqueID, randomSeed)
    if startFace and startFace.level == serverDestination.faceLevel then
        local countToAdd = rng:integerForUniqueID(baseUniqueID, randomSeed + 184499, 45) - 25
        if countToAdd > 0 then
            local addedCount = 0
            local prevDir = nil
            local thisStraightCount = 0
            local startPoint = baseTribeCenterNormal
            local infosToSend = {}



            for i = 1,100 do

                local heightThresholdRandomValue = mj:mToP(1000.0) * rng:valueForUniqueID(startFace.uniqueID, 23234 + i)
                local offsetPoint = nil
                if prevDir then
                    offsetPoint = normalize(startPoint + (prevDir + rng:randomVec() * 2.0) * mj:mToP(200.0))
                else
                    offsetPoint = normalize(startPoint + rng:randomVec() * mj:mToP(200.0))
                end
                
                local offsetDir = normalize(offsetPoint - startPoint)
                local tribeCenterNormalized = normalize(startPoint + offsetDir * (minCloseTribeDistance + mj:mToP(8000.0) * rng:randomValue() * math.min((0.05 + (thisStraightCount * 2) / countToAdd), 1.0)))




                --[[local tooClose = false
                for j,alreadyAdded in ipairs(infosToSend) do
                    if length2(alreadyAdded.normalizedPos - tribeCenterNormalized) < minCloseTribeDistance2 then
                        tooClose = true
                        break
                    end
                end]]

                local tooClose = serverTribe:getOtherDestinationTooClose(nearDestinationStates, tribeCenterNormalized)

                if not tooClose then
                    local faceID = terrain:getFaceIDForNormalizedPointAtLevel(tribeCenterNormalized, serverDestination.faceLevel)
                    if faceID == startFace.uniqueID then
                        local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(tribeCenterNormalized)
                        --mj:log("terrainResult:", terrainResult)
                        if terrainResult.x > mj:mToP(0.1) and terrainResult.x < heightThresholdRandomValue then
                            local terrainNormal = terrain:getHighestDetailTerrainNormalAtPoint(tribeCenterNormalized)
                            if dot(terrainNormal, tribeCenterNormalized) > 0.99 then
                                local tribeID = serverGOM:reserveUniqueID()
                                local destinationState = serverTribe:createTribeDestination(tribeID, tribeCenterNormalized, nil, nil, nil)
                                --mj:log("createRandomCloseTribes tribe created:", destinationState.destinationID, " faceID:", faceID)
                                if destinationState then
                                    table.insert(infosToSend, destinationState)
                                    nearDestinationStates[tribeID] = destinationState
                                    addedCount = addedCount + 1
                                    if rng:integerForUniqueID(startFace.uniqueID, 70336 + i, math.max(countToAdd / 2, 4)) == 1 then
                                        prevDir = nil
                                        startPoint = baseTribeCenterNormal
                                        thisStraightCount = 0
                                    else
                                        prevDir = offsetDir
                                        startPoint = tribeCenterNormalized
                                        thisStraightCount = thisStraightCount + 1
                                    end
                                end
                            end
                        end
                        

                        if addedCount >= countToAdd then
                            --mj:log("serverTribe:createRandomCloseTribes added:", addedCount)
                            break
                        end
                    end
                end
            end
            if infosToSend[1] then
                return infosToSend
            end
        end
    end
    return nil
end

function serverTribe:createTribesIfNeededNearLocation(baseLocation, minDesiredCountOrNil, createPlayerSelectionTribes)

    local maxSpawnDistanceMeters = 10000
    if createPlayerSelectionTribes then
        maxSpawnDistanceMeters = 2000
    end

    local desiredCount = mjm.clamp(serverWorld:getWorldTime() / (serverWorld:getYearLength() * 2.0), minDesiredCountOrNil or 1,6)
    --mj:log("serverTribe:createTribesIfNeededNearLocation minDesiredCountOrNil:", minDesiredCountOrNil, " desiredCount:", desiredCount)
    if desiredCount > 0 then
        local baseLocationNormal = normalize(baseLocation)

        terrain:loadAreaAtLevels(baseLocationNormal, serverDestination.faceLevel - 2, serverDestination.faceLevel)
        local baseLocationFace = terrain:getFaceForPointWithStartFace(baseLocationNormal, nil, serverDestination.faceLevel)
        if baseLocationFace and baseLocationFace.level == serverDestination.faceLevel then


            local addedCount = 0
            local foundCount = 0

            local nearDestinationStates = {}
            
            local faces = terrain:retrieveTrianglesWithinRadius(baseLocationNormal, mj:mToP(10000.0), serverDestination.faceLevel)
            --mj:log("faces:", faces)
            for i,face in ipairs(faces) do
                local destinationStates = serverDestination:getDestinationsForFace(face.uniqueID, false)
                if destinationStates then
                    for destinationID,destinationState in pairs(destinationStates) do
                        --mj:log("found destination state:", destinationID, " destinationState.destinationTypeIndex:", destinationState.destinationTypeIndex)
                        if not destinationState.failedTribe then
                            if destinationState.destinationTypeIndex == destination.types.staticTribe.index or 
                            destinationState.destinationTypeIndex == destination.types.playerSelectionSeedTribe.index then
                                if not nearDestinationStates[destinationID] then
                                    nearDestinationStates[destinationID] = destinationState 

                                    if (not destinationState.clientID) and
                                    destinationState.destinationTypeIndex == destination.types.playerSelectionSeedTribe.index then
                                        foundCount = foundCount + 1
                                        --mj:log("found:", destinationState)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            local countToAdd = desiredCount - foundCount
            --mj:log("foundCount:", foundCount, " countToAdd:", countToAdd)
            if countToAdd > 0 then
                local tribeID = serverGOM:reserveUniqueID()
                for i = 1,100 do



                    local offsetPoint = normalize(baseLocationNormal + rng:vecForUniqueID(tribeID, 12932 + i) * mj:mToP(2000.0))
                    
                    local offsetDir = normalize(offsetPoint - baseLocationNormal)
                    local tribeCenterNormalized = baseLocationNormal + offsetDir * (mj:mToP(500.0) + mj:mToP(maxSpawnDistanceMeters - 500.0) * rng:valueForUniqueID(tribeID, 2541 + i))

                    local modified = false
                    local heightThresholdRandomValue = nil
                    if not createPlayerSelectionTribes then
                        modified = terrain:getHasRemovedTransientObjectsNearPos(tribeCenterNormalized)
                        heightThresholdRandomValue = mj:mToP(1000.0) * rng:valueForUniqueID(tribeID, 22953 + i)
                    end
                    if not modified then
                        local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(tribeCenterNormalized)
                       -- mj:log("terrainResult:", terrainResult)
                        if terrainResult.x > mj:mToP(0.1) and ((not heightThresholdRandomValue) or terrainResult.x < heightThresholdRandomValue) then
                            local terrainNormal = terrain:getHighestDetailTerrainNormalAtPoint(tribeCenterNormalized)
                            if dot(terrainNormal, tribeCenterNormalized) > 0.99 then
                                --mj:log("flat enough")

                                local foundTooClose = false
                                if not createPlayerSelectionTribes then -- we can spawn them in other villages or whatever, they are nomads
                                    foundTooClose = serverTribe:getOtherDestinationTooClose(nearDestinationStates, tribeCenterNormalized)
                                end

                                if not foundTooClose then
                                    --mj:log("creating new tribe in createTribesIfNeededNearLocation with id:", tribeID)
                                    local extraDestinationState = nil
                                    if createPlayerSelectionTribes then
                                        extraDestinationState = {destinationTypeIndex = destination.types.playerSelectionSeedTribe.index}
                                    end
                                    local destinationState = serverTribe:createTribeDestination(tribeID, tribeCenterNormalized, nil, extraDestinationState, nil)
                                    if destinationState then
                                        nearDestinationStates[tribeID] = destinationState 
                                        --mj:log("createTribesIfNeededNearLocation tribe created:", tribeID, " faceID:", baseLocationFace.uniqueID)
                                        --mj:log("tribe creation success")
                                        addedCount = addedCount + 1
                                        if addedCount < countToAdd then
                                            tribeID = serverGOM:reserveUniqueID()
                                        end
                                    end
                                end
                            end
                        end
                    end
                    

                    if addedCount >= countToAdd then
                        break
                    end
                end
            end

            if addedCount < countToAdd then
                mj:warn("failed to spawn tribes in serverTribe:createTribesIfNeededNearLocation")
            end
        end
    end
end

function serverTribe:createPlayerSelectionTribesIfNeededNearLocation(baseLocation)
    serverTribe:createTribesIfNeededNearLocation(baseLocation, 4, true)
end

function serverTribe:createStoryTribesIfNeededNearLocation(baseLocation)
    serverTribe:createTribesIfNeededNearLocation(baseLocation, nil, false)
end


function serverTribe:createDebugCloseTribes(center,clientID, countToAdd)

    local centerNormal = normalize(center)

    local failLocationFace = terrain:getFaceForPointWithStartFace(centerNormal, nil, serverDestination.faceLevel)
    if failLocationFace and failLocationFace.level == serverDestination.faceLevel then
        local addedCount = 0
        local infosToSend = {}
        local prevDir = nil
        for i = 1,100 do

            local heightThresholdRandomValue = mj:mToP(1000.0) * rng:valueForUniqueID(failLocationFace.uniqueID, 23234 + i)
            local offsetPoint = nil
            if prevDir then
                offsetPoint = normalize(centerNormal + (prevDir + rng:randomVec() * 0.5) * mj:mToP(200.0))
            else
                offsetPoint = normalize(centerNormal + rng:randomVec() * mj:mToP(200.0))
            end
            
            local offsetDir = normalize(offsetPoint - centerNormal)
            
            local distanceMultiplier = 1.0
            if addedCount == 0 then --make one really close
                distanceMultiplier = 0.2
            end
            local tribeCenterNormalized = normalize(centerNormal + offsetDir * (mj:mToP(200.0) + mj:mToP(500.0) * rng:randomValue()) * distanceMultiplier)

            local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(tribeCenterNormalized)
            --mj:log("terrainResult:", terrainResult)
            if terrainResult.x > mj:mToP(0.1) and terrainResult.x < heightThresholdRandomValue then
                local terrainNormal = terrain:getHighestDetailTerrainNormalAtPoint(tribeCenterNormalized)
                if dot(terrainNormal, tribeCenterNormalized) > 0.99 then
                    local tribeID = serverGOM:reserveUniqueID()
                    local creationInfo = {
                        minSpawnCount = 15,
                        maxSpawnCount = 30,
                    }
                    local destinationState = serverTribe:createTribeDestination(tribeID, tribeCenterNormalized, creationInfo, nil, nil)
                    if destinationState then
                        local sanitized = serverDestination:sanitizeDestinationForSendToClient(clientID, destinationState)

                        local transientClientState = serverWorld.transientClientStates[clientID]
                        transientClientState.sentDestinationIDs[tribeID] = true

                        table.insert(infosToSend, sanitized)
                        addedCount = addedCount + 1
                        prevDir = offsetDir
                    end
                end
            end
            

            if addedCount >= countToAdd then
                break
            end
        end

        if infosToSend and infosToSend[1] then
            server:callClientFunction("addDestinationInfos", clientID, infosToSend, nil)
        end
    end
end

local function doChecksOnTradeStorageAreasDueToRelationshipFavorChange(destinationState)
    local tradeables = destinationState.tradeables
    if tradeables then
        if tradeables.requests then
            for resourceTypeIndex,requestInfo in pairs(tradeables.requests) do
                if requestInfo.storageAreaID then
                    local storageObject = serverGOM:getObjectWithID(requestInfo.storageAreaID)
                    if storageObject then
                        serverStorageArea:doChecksForAvailibilityChange(storageObject)
                    end
                end
            end
        end
    end
end

function serverTribe:setFavor(destinationState, relationshipState, favor)
    relationshipState.favor = favor

    if relationshipState.favor < gameConstants.tribeAIMinimumFavorForTrading and (not gameConstants.debugAllowTradesWithNoFavor) then
        if not relationshipState.favorIsBelowTradingThreshold then
            relationshipState.favorIsBelowTradingThreshold = true
            doChecksOnTradeStorageAreasDueToRelationshipFavorChange(destinationState)
        end
    else
        if relationshipState.favorIsBelowTradingThreshold then
            relationshipState.favorIsBelowTradingThreshold = nil
            doChecksOnTradeStorageAreasDueToRelationshipFavorChange(destinationState)
        end
    end

    if relationshipState.favor <= gameConstants.tribeRelationshipScoreThresholds.moderateNegative then
        serverTribe:updateSapienProximityCallbacks()
    end
end

function serverTribe:generateNewRelationshipIfMissing(tribeID, clientTribeID, contexturalOffset) --warning! destinationState is not saved in here, caller is responsible
    --mj:log("serverTribe:generateNewRelationshipIfMissing:", tribeID, " clientTribeID:", clientTribeID)
    local destinationState = serverDestination:getDestinationState(tribeID)
    if not destinationState then
        return false
    end
    if not destinationState.relationships then
        --mj:log("no existing relationships:", destinationState)
        destinationState.relationships = {}
    end
    if (not destinationState.relationships[clientTribeID]) then
        --mj:log("no existing for clientTribeID:", destinationState.relationships)

        local relationshipState = {}
        destinationState.relationships[clientTribeID] = relationshipState

        local averageTribeReputation = serverTribeAIPlayer:getAITribeAverageReputation(clientTribeID)
        local nomadReputation = serverWorld:getPlayerNomadReputation(clientTribeID)

        local reputationOffset = ((averageTribeReputation + nomadReputation) / 2) - 50
        

        local initialFavor = 50
        if not destinationState.clientID then
            initialFavor = 42 + rng:integerForUniqueID(destinationState.destinationID, 90553, 7) + reputationOffset + contexturalOffset
            initialFavor = math.floor(mjm.clamp(initialFavor, 25, 75))
        end

        mj:log("generatingNewRelationship for tribe:", clientTribeID, ". averageTribeReputation:", averageTribeReputation, ", nomadReputation:", nomadReputation, " reputationOffset:", reputationOffset, " contexturalOffset:", contexturalOffset, " final initial favor:", initialFavor)

        serverTribe:setFavor(destinationState, relationshipState, initialFavor)

        if not destinationState.clientID then
            serverTribeAIPlayer:generateQuestIfMissing(destinationState, clientTribeID)
        end

        return true
    end
    return false
end


function serverTribe:getSapienInfosForUIRequest(tribeID, clientTribeID, generateRelationshipIfMissing)
    --mj:log("getInfosForUIRequest")
    local destinationState = serverDestination:getDestinationState(tribeID)

    if not destinationState then
        return nil
    end

    if generateRelationshipIfMissing then -- this is a bit weird, we can generate a relationship as a result of a UI request like this
        serverTribe:generateNewRelationshipIfMissing(tribeID, clientTribeID, 0)
    end

    local tribeSapienInfos = {}

    if destinationState.loadState == destination.loadStates.hibernating then
        for i,hibernationState in ipairs(destinationState.hibernatingSapienStates) do
            tribeSapienInfos[hibernationState.uniqueID] = {
                uniqueID = hibernationState.uniqueID,
                objectTypeIndex = gameObject.types.sapien.index,
                sharedState = sanitizeSapienSharedState(hibernationState.states.sharedState),
            }
        end
    else
        serverGOM:callFunctionForAllSapiensInTribe(destinationState.destinationID, function(sapien)
            tribeSapienInfos[sapien.uniqueID] = {
                uniqueID = sapien.uniqueID,
                objectTypeIndex = sapien.objectTypeIndex,
                sharedState = sanitizeSapienSharedState(sapien.sharedState),
            }
        end)
    end
    return tribeSapienInfos
end

function serverTribe:completeGreetAction(orderObjectSapien, instigatorSapien)

    local function doCompleteGreetAction(metSapien, greetSapien)
        local clientTribeID = greetSapien.sharedState.tribeID
        local orderObjectTribeID = metSapien.sharedState.tribeID
        
        
        local diplomacyTraitInfluence = sapienTrait:getSkillInfluence(greetSapien.sharedState.traits, skill.types.diplomacy.index) --at the moment this is 0 or 1, it could be -1 or 2 in the future
        
        local skillOffset = -5
        if skill:hasSkill(greetSapien, skill.types.diplomacy.index) then
            skillOffset = 0
        end

        local wasGenerated = serverTribe:generateNewRelationshipIfMissing(orderObjectTribeID, clientTribeID, diplomacyTraitInfluence * 5 + skillOffset)
        local tribeSapienInfos = serverTribe:getSapienInfosForUIRequest(orderObjectTribeID, clientTribeID, false, 0)
        local destinationState = serverDestination:getDestinationState(orderObjectTribeID)
        if not destinationState then
            return
        end
    
        if wasGenerated and tribeSapienInfos then
            local notificationTypeIndex = notification.types.tribeFirstMet.index
    
            serverGOM:sendNotificationForObject(greetSapien, notificationTypeIndex, {
                otherSapienID = metSapien.uniqueID,
                destinationState = destinationState,
                tribeSapienInfos = tribeSapienInfos,
                tribeName = destinationState.name,
            }, clientTribeID)
        end
    
        if wasGenerated then
            serverDestination:saveDestinationState(orderObjectTribeID)
        end
    end

    doCompleteGreetAction(orderObjectSapien, instigatorSapien)
    doCompleteGreetAction(instigatorSapien, orderObjectSapien)

    serverTribe:updateSapienProximityCallbacks()
end

function serverTribe:completeQuestDelivery(orderObject, orderObjectTribeID, clientTribeID, resourceTypeIndex)
    if (not clientTribeID) or clientTribeID == orderObjectTribeID then
        return
    end

    local destinationState = serverDestination:getDestinationState(orderObjectTribeID)
    if not destinationState then
        return
    end
    
    local relationshipState = destinationState.relationships[clientTribeID]
    if relationshipState then
        local questDeliveries = relationshipState.questDeliveries
        if not questDeliveries then
            questDeliveries = {}
            relationshipState.questDeliveries = questDeliveries
        end
        questDeliveries[resourceTypeIndex] = (questDeliveries[resourceTypeIndex] or 0) + 1

        local questState = relationshipState.questState
        if questState and questState.resourceTypeIndex == resourceTypeIndex then
            if questDeliveries[resourceTypeIndex] >= questState.requiredCount then
                questDeliveries[resourceTypeIndex] = questDeliveries[resourceTypeIndex] - questState.requiredCount
                questState.complete = true
                questState.expirationTime = serverWorld:getWorldTime() + quest.failureOrCompletionDelayBeforeNewQuest

                serverTribeAIPlayer:updateQuestForCompletion(destinationState, clientTribeID)

                if relationshipState.favor < 100 then
                    local reward = math.min(questState.reward, 100 - relationshipState.favor)
                    serverTribe:setFavor(destinationState, relationshipState, relationshipState.favor + reward)

                    local notificationTypeIndex = notification.types.resourceQuestFavorReward.index

                    serverGOM:sendNotificationForObject(orderObject, notificationTypeIndex, {
                        reward = reward,
                        deliveredCount = questState.requiredCount,
                        resourceTypeIndex = resourceTypeIndex,
                        tribeName = destinationState.name,
                    }, clientTribeID)
                end
            end
        end

        serverDestination:sendDestinationRelationshipToClient(destinationState, clientTribeID)
    end

    serverDestination:saveDestinationState(destinationState.destinationID)
end

function serverTribe:completeTradeRequestDelivery(orderObject, orderObjectTribeID, clientTribeID, resourceTypeIndex)
    if (not clientTribeID) or clientTribeID == orderObjectTribeID then
        return
    end
    serverTribe:generateNewRelationshipIfMissing(orderObjectTribeID, clientTribeID, 0)
    local destinationState = serverDestination:getDestinationState(orderObjectTribeID)
    if not destinationState then
        return
    end
    local tradeables = destinationState.tradeables
    
    local relationshipState = destinationState.relationships[clientTribeID]
    if relationshipState then
        local tradeRequestDeliveries = relationshipState.tradeRequestDeliveries
        if not tradeRequestDeliveries then
            tradeRequestDeliveries = {}
            relationshipState.tradeRequestDeliveries = tradeRequestDeliveries
        end
        tradeRequestDeliveries[resourceTypeIndex] = (tradeRequestDeliveries[resourceTypeIndex] or 0) + 1

        --mj:log("tradeables:", tradeables)
       --mj:log("tradeRequestDeliveries:", tradeRequestDeliveries)
        if tradeables and tradeables.requests then
            local countAndCost = tradeables.requests[resourceTypeIndex]
            if countAndCost and countAndCost.count > 0 then
                if tradeRequestDeliveries[resourceTypeIndex] >= countAndCost.count then
                    tradeRequestDeliveries[resourceTypeIndex] = tradeRequestDeliveries[resourceTypeIndex] - countAndCost.count
                    if relationshipState.favor < 100 then
                        local reward = math.min(countAndCost.reward, 100 - relationshipState.favor)
                        serverTribe:setFavor(destinationState, relationshipState, relationshipState.favor + reward)

                        local notificationTypeIndex = notification.types.tradeRequestFavorReward.index

                        --[[serverTribe:sendTribeRelationshipNotification(clientTribeID, destinationState.destinationID, notificationTypeIndex, {
                            reward = reward,
                            deliveredCount = countAndCost.count,
                            resourceTypeIndex = resourceTypeIndex,
                            tribeName = destinationState.name,
                        })]]
                        
                        serverGOM:sendNotificationForObject(orderObject, notificationTypeIndex, {
                            reward = reward,
                            deliveredCount = countAndCost.count,
                            resourceTypeIndex = resourceTypeIndex,
                            tribeName = destinationState.name,
                        }, clientTribeID)
                    end
                end
            end
        end

        serverDestination:sendDestinationRelationshipToClient(destinationState, clientTribeID)
    end

    if tradeables and tradeables.requests then
        serverTribeAIPlayer:updateTradeables(destinationState)
    end

    serverDestination:saveDestinationState(destinationState.destinationID)
end

function serverTribe:purchaseTradeOffer(destinationState, clientTribeID, resourceTypeIndex, objectTypeIndex, offerInfo)
    local relationshipState = destinationState.relationships[clientTribeID]
    if (not offerInfo.tradeLimitReached) and (not relationshipState.favorIsBelowTradingThreshold) and (relationshipState.favor > offerInfo.cost) then
        serverTribe:setFavor(destinationState, relationshipState, relationshipState.favor - offerInfo.cost)

        if resourceTypeIndex then
            if not relationshipState.tradeOfferPurchases then
                relationshipState.tradeOfferPurchases = {}
            end
            relationshipState.tradeOfferPurchases[resourceTypeIndex] = (relationshipState.tradeOfferPurchases[resourceTypeIndex] or 0) + offerInfo.count
        else
            if not relationshipState.tradeOfferObjectTypePurchases then
                relationshipState.tradeOfferObjectTypePurchases = {}
            end
            relationshipState.tradeOfferObjectTypePurchases[objectTypeIndex] = (relationshipState.tradeOfferObjectTypePurchases[objectTypeIndex] or 0) + offerInfo.count
        end

        serverDestination:sendDestinationRelationshipToClient(destinationState, clientTribeID)
        serverTribeAIPlayer:updateTradeables(destinationState)

        local notificationTypeIndex = notification.types.tradeOfferFavorPaid.index

        local storageAreaObject = serverGOM:getObjectWithID(offerInfo.storageAreaID)
        
        serverGOM:sendNotificationForObject(storageAreaObject, notificationTypeIndex, {
            cost = offerInfo.cost,
            count = offerInfo.count,
            resourceTypeIndex = resourceTypeIndex,
            objectTypeIndex = objectTypeIndex,
            tribeName = destinationState.name,
        }, clientTribeID)

        serverDestination:saveDestinationState(destinationState.destinationID)

        return true
    end
    return false
end

function serverTribe:completeTradeOfferPickup(orderObject, orderObjectTribeID, clientTribeID, resourceTypeIndex, objectTypeIndex)
    --mj:log("serverTribe:completeTradeOfferPickup")
    local destinationState = serverDestination:getDestinationState(orderObjectTribeID)
    if not destinationState then
        return
    end
    local tradeables = destinationState.tradeables

    if (not clientTribeID) or clientTribeID == orderObjectTribeID then
        if tradeables and tradeables.offers then
            serverTribeAIPlayer:updateTradeables(destinationState)
        end
        --mj:log("false a")
        return false
    end

    serverTribe:generateNewRelationshipIfMissing(orderObjectTribeID, clientTribeID, 0)

    local offerInfo = nil
    if resourceTypeIndex then
        offerInfo = (tradeables and tradeables.offers and tradeables.offers[resourceTypeIndex])
    else
        offerInfo = (tradeables and tradeables.objectTypeOffers and tradeables.objectTypeOffers[objectTypeIndex])
    end

    --[[mj:log("tradeables:", tradeables)
    mj:log("resourceTypeIndex:", resourceTypeIndex)
    mj:log("offerInfo:", offerInfo)]]

    if offerInfo then
        local relationshipState = destinationState.relationships[clientTribeID]
        if relationshipState then

            if resourceTypeIndex then
                local tradeOfferPurchases = relationshipState.tradeOfferPurchases
                if not tradeOfferPurchases then
                    tradeOfferPurchases = {}
                    relationshipState.tradeOfferPurchases = tradeOfferPurchases
                end
                if (not tradeOfferPurchases[resourceTypeIndex]) or tradeOfferPurchases[resourceTypeIndex] == 0 then
                    if not serverTribe:purchaseTradeOffer(destinationState, clientTribeID, resourceTypeIndex, nil, offerInfo) then
                        return false
                    end
                end

                tradeOfferPurchases[resourceTypeIndex] = (tradeOfferPurchases[resourceTypeIndex] or 1) - 1
            else
                local tradeOfferObjectTypePurchases = relationshipState.tradeOfferObjectTypePurchases
                if not tradeOfferObjectTypePurchases then
                    tradeOfferObjectTypePurchases = {}
                    relationshipState.tradeOfferObjectTypePurchases = tradeOfferObjectTypePurchases
                end
                if (not tradeOfferObjectTypePurchases[objectTypeIndex]) or tradeOfferObjectTypePurchases[objectTypeIndex] == 0 then
                    if not serverTribe:purchaseTradeOffer(destinationState, clientTribeID, nil, objectTypeIndex, offerInfo) then
                        return false
                    end
                end

                tradeOfferObjectTypePurchases[objectTypeIndex] = (tradeOfferObjectTypePurchases[objectTypeIndex] or 1) - 1
                
            end

            serverDestination:sendDestinationRelationshipToClient(destinationState, clientTribeID)
            serverDestination:saveDestinationState(destinationState.destinationID)

            return true
        end
    end
    return false
end

function serverTribe:updateDestinationStateForTribeFail(tribeID)
    local destinationState = serverDestination:getDestinationState(tribeID)
    if destinationState then
        destinationState.failedTribe = true
        serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = nil
        serverResourceManager:removeTribe(destinationState.destinationID)
        serverDestination:saveDestinationState(destinationState.destinationID)
    end
end


local worldTimeBetweenTribeCenterUpdates = 10.0
local lastTribeCenterPosUpdateWorldTime = nil

local saveUpdateMovementMinDistance2 = mj:mToP(40.0) * mj:mToP(40.0)

local function doUpdateTribeCenters()
    --mj:log("doUpdateTribeCenters")

    local tribeCenterMaxRadius2 = serverDestination.tribeCenterMaxRadius * serverDestination.tribeCenterMaxRadius

    if (not lastTribeCenterPosUpdateWorldTime) or (serverWorld:getWorldTime() - lastTribeCenterPosUpdateWorldTime > worldTimeBetweenTribeCenterUpdates) then
        lastTribeCenterPosUpdateWorldTime = serverWorld:getWorldTime()

        local foundDestinationStates = {}
        local newTribeCentersByDestinationID = {}

        serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.sapiens, function(sapienID)
            local sapien = serverGOM:getObjectWithID(sapienID)
            if sapien then
                local tribeID = sapien.sharedState.tribeID
                local destinationState = foundDestinationStates[tribeID]
                local newTribeCenters = newTribeCentersByDestinationID[tribeID]

                if not destinationState then
                    destinationState = serverDestination:getDestinationState(tribeID)
                    foundDestinationStates[tribeID] = destinationState
                    newTribeCenters = {}
                    newTribeCentersByDestinationID[tribeID] = newTribeCenters
                end

                if destinationState then
                    local foundInfo = nil
                    if newTribeCenters then
                        for i,centerInfo in ipairs(newTribeCenters) do
                            if centerInfo.count == 0 then
                                foundInfo = centerInfo
                                break
                            else
                                --mj:log("centerInfo.firstPos:", centerInfo.firstPos, " sapien.normalizedPos:",sapien.normalizedPos)
                                local distanceToFirstPos2 = length2(sapien.normalizedPos - centerInfo.firstNormalizedPos)
                                if distanceToFirstPos2 < tribeCenterMaxRadius2 then
                                    foundInfo = centerInfo
                                    break
                                end
                            end
                        end
                    end

                    if foundInfo then
                        foundInfo.count = foundInfo.count + 1
                        foundInfo.sum = foundInfo.sum + sapien.normalizedPos
                    else 
                        foundInfo = {
                            firstNormalizedPos = sapien.normalizedPos,
                            sum = sapien.normalizedPos,
                            count = 1
                        }
                        --mj:log("set for tribeID:", tribeID, " foundInfo:", foundInfo)
                        table.insert(newTribeCenters, foundInfo)
                    end

                end

            end
        end)

        for destinationID, destinationState in pairs(foundDestinationStates) do

            local newTribeCenters = newTribeCentersByDestinationID[destinationID]
            local newTribeCentersCount = #newTribeCenters
            local oldTribeCentersCount = (destinationState.tribeCenters and #destinationState.tribeCenters) or 0

            local tribeCentersChanged = newTribeCentersCount ~= oldTribeCentersCount

            if not tribeCentersChanged then
                for i,newTribeCenter in ipairs(newTribeCenters) do
                    newTribeCenter.normalizedPos = normalize(newTribeCenter.sum)
                    local foundClose = false
                    for j,oldTribeCenter in ipairs(destinationState.tribeCenters) do
                        if length2(oldTribeCenter.normalizedPos - newTribeCenter.normalizedPos) < saveUpdateMovementMinDistance2 then
                            foundClose = true
                            --mj:log("found close:", mj:pToM(mjm.length(oldTribeCenter.normalizedPos - newTribeCenter.normalizedPos)))
                            break
                        end
                    end
                    if not foundClose then 
                        tribeCentersChanged = true
                        break
                    end
                end
            end

            if tribeCentersChanged then
                destinationState.tribeCenters = newTribeCenters

                local newDestinationCenter = vec3(0.0,0.0,0.0)
                
                for i,centerInfo in ipairs(destinationState.tribeCenters) do
                    newDestinationCenter = newDestinationCenter + centerInfo.sum
                    centerInfo.normalizedPos = centerInfo.normalizedPos or normalize(centerInfo.sum)
                    centerInfo.pos = terrain:getHighestDetailTerrainPointAtPoint(centerInfo.normalizedPos)
                end
                
                serverDestination:updateDestinationPos(destinationState, normalize(newDestinationCenter))
                serverDestination:sendUpdatedDestinationTribeCenters(destinationState)
                serverResourceManager:recalculateForTribe(destinationState)
            end
        end
    end
end


local tribeCenterUpdateFrequency = 8.0

local tribeCenterTimerID = nil

local function updateTribeCenterCallback(callbackID)
    if (not callbackID) or callbackID == tribeCenterTimerID then

        doUpdateTribeCenters()

        tribeCenterTimerID = serverWorld:addCallbackTimerForWorldTime(serverWorld:getWorldTime() + tribeCenterUpdateFrequency, updateTribeCenterCallback)
    end
end

function serverTribe:updateTribeCenters()
    lastTribeCenterPosUpdateWorldTime = nil
    updateTribeCenterCallback(nil)
end

function serverTribe:sendTribeRelationshipNotification(sendToTribeID, tribeID, notificationTypeIndex, userData)
    local sendToClientID = serverWorld:clientIDForTribeID(sendToTribeID)
    if not server.connectedClientsSet[sendToClientID] then
        return
    end

    local titleFunction = notification.types[notificationTypeIndex].titleFunction
    if titleFunction then
        local destinationState = serverDestination:getDestinationState(tribeID)
        if not destinationState then
            return
        end
        local tribeSaveData = {
            tribeID = tribeID,
            name = destinationState.name,
            pos = destinationState.pos,
        }
        serverNotifications:saveNotification(tribeID, notificationTypeIndex, userData, tribeSaveData, sendToTribeID)
        server:callClientFunction("tribeNotification",
        sendToClientID,
        {
            notificationTypeIndex = notificationTypeIndex,
            userData = userData,
            objectSaveData = tribeSaveData,
        })
    end


end

function serverTribe:clientAcceptQuest(acceptingPlayerTribeID, destinationID, chosenQuestState)
    mj:log("serverTribe:clientAcceptQuest by player:", acceptingPlayerTribeID, " destinationID:", destinationID)
    local destinationState = serverDestination:getDestinationState(destinationID)
    if destinationState then
        local relationships = destinationState.relationships
        if relationships then
            local relationshipState = relationships[acceptingPlayerTribeID]
            if relationshipState then
                local questState = relationshipState.questState
                mj:log("serverTribe:clientAcceptQuest questState:", questState)
                if questState and questState.questTypeIndex == chosenQuestState.questTypeIndex and 
                questState.resourceTypeIndex == chosenQuestState.resourceTypeIndex then
                    if serverTribeAIPlayer:assignQuest(destinationState, acceptingPlayerTribeID) then
                        return relationshipState -- sent back to client for UI
                    end
                end
            end
        end
    end
end

function serverTribe:clientPurchaseTradeOffer(acceptingPlayerTribeID, destinationID, chosenOfferInfo)
    local destinationState = serverDestination:getDestinationState(destinationID)
    if not destinationState then
        return
    end
    local tradeables = destinationState.tradeables

    local resourceTypeIndex = chosenOfferInfo.resourceTypeIndex
    local objectTypeIndex = chosenOfferInfo.objectTypeIndex

    local offerInfo = nil
    if resourceTypeIndex then
        offerInfo = (tradeables and tradeables.offers and tradeables.offers[resourceTypeIndex])
    else
        offerInfo = (tradeables and tradeables.objectTypeOffers and tradeables.objectTypeOffers[objectTypeIndex])
    end

    mj:log("serverTribe:clientPurchaseTradeOffer offerInfo:", offerInfo, " tradeables:", tradeables, " chosenOfferInfo:", chosenOfferInfo)

    if offerInfo then
        if serverTribe:purchaseTradeOffer(destinationState, acceptingPlayerTribeID, resourceTypeIndex, objectTypeIndex, offerInfo) then
            --mj:log("serverTribe:clientPurchaseTradeOffer success. returning destinationState:", destinationState)
            return destinationState -- sent back to client for UI
        end
    end
end

function serverTribe:sendNoticedNotificationIfNeeded(playerSapien, otherSapien)
    local playerTribeState = serverDestination.loadedPlayerOrAITribeDestinationStatesByID[playerSapien.sharedState.tribeID]
    if not playerTribeState.clientID then
        return
    end

    local otherTribeState = serverDestination.loadedPlayerOrAITribeDestinationStatesByID[otherSapien.sharedState.tribeID]

    local otherTribeIsDangerous = serverTribe:getOtherTribeIsThreatening(playerTribeState.destinationID, otherTribeState.destinationID)

    local function sendNotification(notificationTypeIndex)
        serverGOM:sendNotificationForObject(otherSapien, notificationTypeIndex, {
            name = playerSapien.sharedState.name,
            otherSapienID = otherSapien.uniqueID,
            otherSapienSharedState = serverNotifications:getSapienSaveSharedStateForNotification(otherSapien),
            otherSapienPos = otherSapien.pos,
        }, playerTribeState.destinationID)

        serverWorld:addTribeToSeenList(playerTribeState.destinationID, otherTribeState.destinationID)
    end

    if not serverWorld:clientWithTribeIDHasSeenTribeID(playerTribeState.destinationID, otherTribeState.destinationID) then
        --mj:log("sending tribe seen notification. My tribe:", playerTribeState.destinationID, " other tribe:", otherTribeState.destinationID)
        local notificationTypeIndex = notification.types.newTribeSeen.index
        if otherTribeIsDangerous then
            notificationTypeIndex = notification.types.dangerousNewTribeSeen.index
        end
        sendNotification(notificationTypeIndex)
        
        local tribeState = serverTribe:getTribeState(otherTribeState.destinationID)
        if tribeState and (not tribeState.exiting) then
            serverTutorialState:tribeNoticed(otherTribeState.destinationID, playerTribeState.destinationID, tribeState.nomadState and  nomadTribeBehavior.types[tribeState.nomadState.tribeBehaviorTypeIndex].recruitChanceOffset)
        end
    else
        if otherTribeIsDangerous then
            local lastSeenTime = serverWorld:getLastSeenNotificationSentTime(playerTribeState.destinationID, otherTribeState.destinationID)
            if serverWorld:getWorldTime() > lastSeenTime + 1440 then --half a day?
                sendNotification(notification.types.dangerousNewTribeSeen.index)
            end
        end
    end
end

local function sapienOtherTribeProximity(sapienIDA, sapienIDB, distance2, newIsClose)
    

    

    local function updateAIState(aiSapien, otherSapienID, otherSapien)
        if aiSapien then
            local aiState = serverSapienAI.aiStates[aiSapien.uniqueID]
            if aiState then
                local closeThreatPotentialSapiens = aiState.closeThreatPotentialSapiens
                if newIsClose then
                    if not closeThreatPotentialSapiens then
                        closeThreatPotentialSapiens = {}
                        aiState.closeThreatPotentialSapiens = closeThreatPotentialSapiens
                    end
                    closeThreatPotentialSapiens[otherSapienID] = otherSapien
                elseif closeThreatPotentialSapiens then
                    closeThreatPotentialSapiens[otherSapienID] = nil
                end
            end
        end
    end

    local sapienA = serverGOM:getObjectWithID(sapienIDA)
    local sapienB = serverGOM:getObjectWithID(sapienIDB)

    updateAIState(sapienA, sapienIDB, sapienB)
    updateAIState(sapienB, sapienIDA, sapienA)

    if sapienA and sapienB then
        if newIsClose then
            serverTribe:sendNoticedNotificationIfNeeded(sapienA, sapienB)
            serverTribe:sendNoticedNotificationIfNeeded(sapienB, sapienA)
        end
    end
end

local needsToUpdateSapienProximityCallbacks = false
local addedCallbacks = {} --currently a callback is forever, and duplicates stack, so we need to ensure there are no duplicates
serverTribe.loadedPotentialThreatTribesByTribeID = addedCallbacks

function serverTribe:updateSapienProximityCallbacksIfNeeded()
    if needsToUpdateSapienProximityCallbacks then
        needsToUpdateSapienProximityCallbacks = false
        local doneIDs = {}
        for destinationID,destinationState in pairs(serverDestination.loadedPlayerOrAITribeDestinationStatesByID) do
            doneIDs[destinationID] = true
            for otherDestinationID,otherDestinationState in pairs(serverDestination.loadedPlayerOrAITribeDestinationStatesByID) do
                if not doneIDs[otherDestinationID] then

                    local function addCallbacks(tribeIDA, tribeIDB, relationship, treatAsThreatDueToClientSetting)
                        if not (addedCallbacks[tribeIDA] and addedCallbacks[tribeIDA][tribeIDB]) then

                            if not addedCallbacks[tribeIDA] then
                                addedCallbacks[tribeIDA] = {}
                            end
                            addedCallbacks[tribeIDA][tribeIDB] = true
                            if not addedCallbacks[tribeIDB] then
                                addedCallbacks[tribeIDB] = {}
                            end
                            addedCallbacks[tribeIDB][tribeIDA] = true

                            if treatAsThreatDueToClientSetting or (not relationship) or relationship.favor <= gameConstants.tribeRelationshipScoreThresholds.mildNegative then
                                
                                local setKeyA = "tribe_" .. tribeIDA
                                if not serverGOM.objectSets[setKeyA] then
                                    serverGOM.objectSets[setKeyA] = serverGOM:createObjectSet(setKeyA)
                                end
                                local setKeyB = "tribe_" .. tribeIDB
                                if not serverGOM.objectSets[setKeyB] then
                                    serverGOM.objectSets[setKeyB] = serverGOM:createObjectSet(setKeyB)
                                end

                                serverGOM:addProximityCallbackForGameObjectsInSet(serverGOM.objectSets[setKeyA], serverGOM.objectSets[setKeyB], mj:mToP(100.0), sapienOtherTribeProximity)
                            end
                        end
                    end

                    if destinationState.clientID then
                        if otherDestinationState.clientID then
                            local relationshipSettingsA = serverWorld:getTribeRelationsSettings(otherDestinationID, destinationID)
                            local relationshipSettingsB = serverWorld:getTribeRelationsSettings(destinationID, otherDestinationID)
                            local treatAsThreatDueToClientSetting = (relationshipSettingsA and relationshipSettingsA.treatAsThreat) or (relationshipSettingsB and relationshipSettingsB.treatAsThreat)
                            addCallbacks(destinationID, otherDestinationID, otherDestinationState.relationships and otherDestinationState.relationships[destinationID], treatAsThreatDueToClientSetting)
                        else
                            addCallbacks(destinationID, otherDestinationID, otherDestinationState.relationships and otherDestinationState.relationships[destinationID], false)
                        end
                    elseif otherDestinationState.clientID then
                        addCallbacks(otherDestinationID, destinationID, destinationState.relationships and destinationState.relationships[otherDestinationID], false)
                    end
                end
            end
        end
    end
end

function serverTribe:updateSapienProximityCallbacks()
    needsToUpdateSapienProximityCallbacks = true
    -- TODO will need to update proximity callbacks if AI tribe hostile state changes
end


function serverTribe:getOtherTribeIsThreatening(thisTribeID, otherTribeID) --this mirrors mainThreadDestination:getOtherTribeIsThreatening, changes here should be applied there
    local destinationState = serverDestination:getDestinationState(thisTribeID)
    local otherDestinationState = serverDestination:getDestinationState(otherTribeID)

    if destinationState ~= otherDestinationState then

        if destinationState.clientID then
            if otherDestinationState.clientID then
                local relationshipSettings = serverWorld:getTribeRelationsSettings(otherDestinationState.destinationID, destinationState.destinationID)
                if relationshipSettings and relationshipSettings.treatAsThreat then
                    return true
                end
            else
                if otherDestinationState.nomadState then
                    return nomadTribeBehavior.types[otherDestinationState.nomadState.tribeBehaviorTypeIndex].isRaid
                end

                local relationship = otherDestinationState.relationships and otherDestinationState.relationships[destinationState.destinationID]
                if (not relationship) or relationship.favor <= gameConstants.tribeRelationshipScoreThresholds.mildNegative then
                    return true
                end
            end
        elseif otherDestinationState.clientID then
            local relationship = destinationState.relationships and destinationState.relationships[otherDestinationState.destinationID]
            if (not relationship) or relationship.favor <= gameConstants.tribeRelationshipScoreThresholds.mildNegative then
                return true
            end
        end
    end

    return false
end

return serverTribe