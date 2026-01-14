local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local dot = mjm.dot
local cross = mjm.cross
local length2 = mjm.length2
local normalize = mjm.normalize
local randomPointWithinTriangle = mjm.randomPointWithinTriangle
local clamp = mjm.clamp

--local gameConstants = mjrequire "common/gameConstants"
local destination = mjrequire "common/destination"
local rng = mjrequire "common/randomNumberGenerator"
local biome = mjrequire "common/biome"
local terrainTypesModule = mjrequire "common/terrainTypes"
local timer = mjrequire "common/timer"
local industry = mjrequire "common/industry"
local planHelper = mjrequire "common/planHelper"

local serverTribe = mjrequire "server/serverTribe"
local serverTribeAIPlayer = mjrequire "server/serverTribeAIPlayer"
local nameLists = mjrequire "common/nameLists"
local serverResourceManager = mjrequire "server/serverResourceManager"

-- serverDestination.lua: destinations are groups of objects that spawn together, usually based on distance from active players. They also include groups of nomad sapiens, leaving sapiens, and will include things like abandoned villages.

local serverDestination = {
    loadAndHibernateTimerDelay = 1.0, --how often to check whether to load and hibernate destinations

    generationPlayerMovementLevel = mj.SUBDIVISIONS - 14, --when a player moves into a different triangle at this level, it will generate nearby destinations as "seeds" (without actually creating the game objects etc)
    sendTribesPlayerMovementLevel = mj.SUBDIVISIONS - 8, -- like above, but specifies how far a player needs to move before sending destinations

    generateSeedDistanceChoosingTribeOrMap = mj:mToP(200000.0),
    generateSeedDistanceStandard = mj:mToP(20000.0),
    loadDistance = mj:mToP(400.0), -- if a seed or hibernating destination is within this distance of a player or tribe center, load it. 
    unloadDistance = mj:mToP(800.0), --If a loaded destination is outside this distance, hibernate it

    tribeCenterMaxRadius = mj:mToP(400.0), --distances for loading/hibernating are based on player distance as well as tribe distance. Multiple tribe centers will be made if sapiens are more than this distance apart from each other. Also used for tribe icons in map view.

    faceLevel = mj.SUBDIVISIONS - 13, -- destinations are saved attached to triangles at this level (shouldn't be modified due to existing save states)
    
    loadedPlayerOrAITribeDestinationStatesByID = {},
}

local locationSampleCount = 30
local minAltitudeForConsideration = mj:mToP(-10.0)
local minDistanceBetweenTribes2 = mj:mToP(400.0) * mj:mToP(400.0)

local destinationsByIDDatabase = nil --destinations by destinationID
local destinationIDsByFaceDatabase = nil --destinationIDs by faceID
local facesByDestinationDatabase = nil --faceIDs by destinationIDs
local faceDatabase = nil -- contains a version index for each face, whether generation has been done

local currentFaceDatabaseVersionIndex = 1

local transientClientStates = nil

local server = nil
local serverWorld = nil
local serverGOM = nil
local terrain = nil

local destinationStatesByFaceID = {}
local destinationStatesByDestinationID = {}
serverDestination.destinationStatesByDestinationID = destinationStatesByDestinationID

--[[

destination.types = typeMaps:createMap( "destination", {
    {
        key = "staticTribe",
    },
    {
        key = "nomadTribe",
    },
    {
        key = "abandondedVillage",
    },
    {
        key = "abandondedMine",
    },
})


destination.loadStates = mj:enum {
    "seed",
    "loaded",
    "hibernating",
    "complete"
}
]]

local hibernationDelaysByKey = {
    now = 0,
    oneDay = 1,
    twoDays = 2,
}

local function getHibernationDelay(clientID)
    local dayLength = serverWorld:getDayLength()
	local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
    if privateSharedState and privateSharedState.hibernationDurationKey then
        if hibernationDelaysByKey[privateSharedState.hibernationDurationKey] then
            return hibernationDelaysByKey[privateSharedState.hibernationDurationKey] * dayLength
        end
    end

    return 0
end

serverDestination.shouldLoadAndHibernateByDestinationTypes = {
    [destination.types.staticTribe.index] = true,
}

serverDestination.seedLoadFunctionsByDestinationTypeIndex = {
    [destination.types.staticTribe.index] = function(destinationState)
        mj:log("loading seed tribe:", destinationState.destinationID)
        destinationState.loadState = destination.loadStates.loaded
        destinationState.industryTypeIndex = serverTribe:getNextIndustryType()
        serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = destinationState
        --serverResourceManager:addTribe(destinationState)
        serverWorld:addValidOwnerTribe(destinationState.destinationID)
        serverTribe:loadSapiensForSeedDestination(destinationState)
        serverTribe:updateSapienProximityCallbacks()

        serverDestination:saveDestinationState(destinationState.destinationID)
    end,
}


serverDestination.hibernatingLoadFunctionsByDestinationTypeIndex = {
    [destination.types.staticTribe.index] = function(destinationState)
        mj:log("reloading hibernated tribe:", destinationState.destinationID)
        destinationState.loadState = destination.loadStates.loaded
        serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = destinationState
        serverResourceManager:addTribe(destinationState)
        serverTribe:wakeHibernatingTribe(destinationState)
        if not destinationState.clientID then
            serverTribeAIPlayer:addDestination(destinationState)
        end
        serverTribe:updateSapienProximityCallbacks()

        serverDestination:saveDestinationState(destinationState.destinationID)
    end,
}

serverDestination.unloadFunctionsByDestinationTypeIndex = {
    [destination.types.staticTribe.index] = function(destinationState)
        mj:log("hibernating tribe:", destinationState.destinationID)
        destinationState.loadState = destination.loadStates.hibernating
        destinationState.hibernationTime = serverWorld:getWorldTime() --added 0.5.0.45, not migrated currently
        serverResourceManager:removeTribe(destinationState.destinationID)

        serverTribe:hibernateTribe(destinationState)
        serverTribeAIPlayer:removeDestination(destinationState)

        serverDestination:saveDestinationState(destinationState.destinationID)
        serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = nil
        
        serverWorld:pauseIfNoPlayerTribesLoaded()
    end,
}

serverDestination.shouldKeepLoadedFunctionsByDestinationTypeIndex = { --ignores load distances to keep loaded always, unless unloadFunction returns true also
    [destination.types.staticTribe.index] = function(destinationState)
        if destinationState.clientID then
            --mj:log("checking keep loaded:", destinationState.destinationID, " disconnect time:", destinationState.clientDisconnectWorldTime)
            if destinationState.clientDisconnectWorldTime then
                --mj:log("shouldKeepLoadedFunctionsByDestinationTypeIndex:", destinationState.destinationID, " delay:", getHibernationDelay(destinationState.clientID), " returning: ", (serverWorld:getWorldTime() - destinationState.clientDisconnectWorldTime) < getHibernationDelay(destinationState.clientID))
                return (serverWorld:getWorldTime() - destinationState.clientDisconnectWorldTime) < getHibernationDelay(destinationState.clientID)
            end
            return true
        else
            return serverTribeAIPlayer:shouldPreventHibernation(destinationState)
        end
    end,
}

serverDestination.shouldUnloadFunctionsByDestinationTypeIndex = { -- overrides everything to unload regardless of distance or shouldKeepLoadedFunction
    [destination.types.staticTribe.index] = function(destinationState)
        if destinationState.clientID then
            --mj:log("shouldUnloadFunctionsByDestinationTypeIndex:", destinationState.destinationID, " delay:", getHibernationDelay(destinationState.clientID), " returning: ", (serverWorld:getWorldTime() - destinationState.clientDisconnectWorldTime) >= getHibernationDelay(destinationState.clientID))
            if destinationState.clientDisconnectWorldTime then
                return (serverWorld:getWorldTime() - destinationState.clientDisconnectWorldTime) > getHibernationDelay(destinationState.clientID)
            end
        end
        return false
    end,
}

--[[local function checkIsValidDestination(destinationState) --some may have been sent to "true" somewhere.
    local valid = (type(destinationState) == "table")
    if not valid then
        mj:error("inavlid destinationState")
    end
    return valid
end]]

function serverDestination:getDestinationsForFace(faceID, createIfNil)
    local destinationStates = destinationStatesByFaceID[faceID]
    --mj:log("destinationStates:", destinationStates)
    --mj:log("serverDestination:getDestinationsForFace:", faceID, " found existing:", destinationStates ~= nil)
    if not destinationStates then
        local destinationIDsForFace = destinationIDsByFaceDatabase:dataForKey(faceID) or {}

        if destinationIDsForFace and next(destinationIDsForFace) then
            destinationStates = {}
            for destinationID,v in pairs(destinationIDsForFace) do
                destinationStates[destinationID] = destinationsByIDDatabase:dataForKey(destinationID)
            end
            if not next(destinationStates) then
                destinationStates = nil
                destinationIDsByFaceDatabase:removeDataForKey(faceID)
                destinationIDsForFace = {}
            end
        end

        if createIfNil and (not destinationStates) then
            --mj:log("creating new")
            destinationStates = {}
        end
        --mj:log("loaded destinationStatesArray:", destinationStatesArray)
       -- local needsSave = false
        if destinationStates then
            destinationStatesByFaceID[faceID] = destinationStates
            local faceNeedsSave = false
            for destinationID,destinationState in pairs(destinationStates) do
                local needsSave = false


                if not destinationStatesByDestinationID[destinationState.destinationID] then
                    local removed = false
                    if not destinationState.destinationID then --migrate to 0.5
                        --mj:log("migrate destination:", destinationState.tribeID)
                        needsSave = true
                        if destinationState.creationSapienStates then
                            destinationStates[destinationID] = nil
                            destinationIDsForFace[destinationID] = nil
                            removed = true
                        else
                            destinationState.destinationID = destinationState.tribeID
                            destinationState.loadState = destination.loadStates.loaded
                            destinationState.industryTypeIndex = industry.types.rockTools.index
                            destinationState.normalizedPos = destinationState.normalizedPos or normalize(destinationState.center)
                            if destinationState.nomad then
                                destinationState.destinationTypeIndex = destination.types.nomadTribe.index
                            else
                                destinationState.destinationTypeIndex = destination.types.staticTribe.index
                            end
                            if not destinationState.name then
                                destinationState.name = nameLists:generateTribeName(destinationState.destinationID, 3634)
                            end

                            if not destinationState.pos then
                                destinationState.pos = terrain:getHighestDetailTerrainPointAtPoint(destinationState.normalizedPos)
                            end
                            
                        end
                        destinationState.seenResourceObjectTypes = {}
                    end

                    --[[if destinationState.failedTribe then
                        mj:error("failed tribe:", destinationState)
                    end]]

                    if not destinationState.pos then
                        destinationStates[destinationID] = nil
                        destinationIDsForFace[destinationID] = nil
                        removed = true
                    end

                    if not removed then
                        --[[if destinationState.relationships then
                            mj:log("loaded destinationState with relationshipts:", destinationState)
                        else
                            mj:log("loaded destinationState with not relationshipts:", destinationState.destinationID)
                        end]]
                        destinationStatesByDestinationID[destinationState.destinationID] = destinationState
                        planHelper:setDestinationStateForTribeID(destinationState.destinationID, destinationState)
                        --mj:log("loaded:", destinationState.destinationID, " faceID:", faceID, " loadState:", destinationState.loadState)

                        if destinationState.clientID then
                            if not destinationState.clientDisconnectWorldTime and (not serverWorld.connectedClientIDSet[destinationState.clientID]) then
                                destinationState.clientDisconnectWorldTime = serverWorld:getWorldTime()
                                --mj:log("Set clientDisconnectWorldTime on load:", destinationState.clientDisconnectWorldTime)
                                needsSave = true
                            end

                            if not destinationState.assignedToClientWorldTime then --only added in 0.7. For backwards compatibility, assume it's as old as the world
                                destinationState.assignedToClientWorldTime = 0
                            end
                        end

                        if destinationState.loadState == destination.loadStates.complete then --complete has been deprecated, but a few tribes ended up with it
                            destinationState.loadState = destination.loadStates.loaded
                            needsSave = true
                        end

                        if destinationState.loadState == destination.loadStates.loaded and destinationState.destinationTypeIndex == destination.types.staticTribe.index then
                            serverDestination.loadedPlayerOrAITribeDestinationStatesByID[destinationState.destinationID] = destinationState
                            serverResourceManager:addTribe(destinationState)
                            if not destinationState.clientID then
                                serverTribeAIPlayer:addDestination(destinationState)
                            end
                            serverTribe:updateSapienProximityCallbacks()
                        end
                    end

                    faceNeedsSave = faceNeedsSave or removed or needsSave

                    if removed then
                        destinationsByIDDatabase:removeDataForKey(destinationState.destinationID)
                    elseif needsSave then
                        destinationsByIDDatabase:setDataForKey(destinationState, destinationState.destinationID)
                    end
                end
            end
            if faceNeedsSave then
                destinationIDsByFaceDatabase:setDataForKey(destinationIDsForFace, faceID)
            end
        end
    end

    return destinationStates
end

function serverDestination:saveNewDestination(destinationState)
    --[[if not checkIsValidDestination(destinationState) then
        mj:error("attempt to save invalid destination state")
        error()
    end]]
   -- mj:log("saveNewDestination:", destinationState.destinationID)
    local destinationStatesForThisFace = serverDestination:getDestinationsForFace(destinationState.faceID, true)

    destinationStatesForThisFace[destinationState.destinationID] = destinationState
    destinationStatesByDestinationID[destinationState.destinationID] = destinationState
    planHelper:setDestinationStateForTribeID(destinationState.destinationID, destinationState)

    local faceDestinationIDs = destinationIDsByFaceDatabase:dataForKey(destinationState.faceID) or {}
    faceDestinationIDs[destinationState.destinationID] = true
    destinationIDsByFaceDatabase:setDataForKey(faceDestinationIDs, destinationState.faceID)

    destinationsByIDDatabase:setDataForKey(destinationState, destinationState.destinationID)
    facesByDestinationDatabase:setDataForKey(destinationState.faceID, destinationState.destinationID)

end


local sendKeys = {
    industryTypeIndex = true,
    clientID = true,
    name = true,
    population = true,
    destinationTypeIndex = true,
    spawnSapienCount = true,
    pos = true,
    destinationID = true,
    faceID = true,
    normalizedPos = true,
    tradables = true,
    nomad = true,
    loadState = true,
    tradeables = true,
    failedTribe = true,
    unprotectedByAnyAbleSapiens = true,
}

function serverDestination:sanitizeDestinationForSendToClient(clientID, destinationState)
    local sanitized = {}

    for k,v in pairs(destinationState) do
        if sendKeys[k] then
            sanitized[k] = v
        end
    end

    if destinationState.relationships then
        local clientTribeID = serverWorld:tribeIDForClientID(clientID)
        if clientTribeID then
            sanitized.relationships = {
                [clientTribeID] = destinationState.relationships[clientTribeID]
            }
        else
            sanitized.relationships = nil
        end
    end

    sanitized.ownedByLocalPlayer = serverWorld:getTribeIsOwnedByPlayer(destinationState.destinationID, clientID)
    if destinationState.clientID then
        sanitized.playerName = serverWorld:getPlayerNameForClient(destinationState.clientID)
        if serverWorld.connectedClientIDSet[destinationState.clientID] then
            sanitized.playerOnline = true
        end    
    end

    if destinationState.biomeTags then
        sanitized.biomeDifficulty = biome:getDifficultyLevelFromTags(destinationState.biomeTags)
    end

    --[[if sanitized.ownedByLocalPlayer then
        mj:log("client owned tribe playername:", sanitized.playerName)
    end]]

    return sanitized
end


local tryAgainCallbackIDs = {}

local function sendInfos(clientID, mapPos, isChoosingTribeAndDistant, sanityCounter, transientClientState)
    if sanityCounter > 2 then
        mj:error("sanityCounter > 2 in sendInfos")
        return
    end

    if not serverWorld.connectedClientIDSet[clientID] then --can happen due to dodgy dangerous timer callback below
        return
    end

    local infosToSend = {}
        --mj:log("newPosFace:", newPosFace.uniqueID)
    local checkRadius = serverDestination.generateSeedDistanceStandard
    if isChoosingTribeAndDistant then
        checkRadius = serverDestination.generateSeedDistanceChoosingTribeOrMap
    end
    local faces = terrain:retrieveTrianglesWithinRadius(mapPos, checkRadius, serverDestination.faceLevel)

    --mj:log("face count:", #faces)

    if not transientClientState.sentDestinationIDs then
        transientClientState.sentDestinationIDs = {}
    end

    for i,face in ipairs(faces) do 
        if face.level == serverDestination.faceLevel then
            local faceID = face.uniqueID
            local alreadySent = transientClientStates[clientID].sentFaceIDs[faceID]
            if (not alreadySent) then
               -- mj:log("new face id:", faceID)
                
                transientClientStates[clientID].sentFaceIDs[faceID] = true
                local destinationInfos = serverDestination:loadDestinationsIfNeededForFace(face)
                if destinationInfos then
                    for destinationID,destinationInfo in pairs(destinationInfos) do 
                        if (not destinationInfo.nomad) and (not transientClientState.sentDestinationIDs[destinationID]) then
                            local sanitized = serverDestination:sanitizeDestinationForSendToClient(clientID, destinationInfo)
                            --mj:log("sending destinationInfo for face id::", faceID, " sanitized:", sanitized)
                            table.insert(infosToSend, sanitized)
                            transientClientState.sentDestinationIDs[destinationID] = true
                        end
                    end
                end
            end
        else
           -- mj:log("sendInfos addTemporaryAnchorForFaceID level:", face.level, "/", serverDestination.faceLevel, " call depth:", sanityCounter)
            terrain:addTemporaryAnchorForFaceID(face.uniqueID, serverDestination.faceLevel)
            if not tryAgainCallbackIDs[clientID] then
                tryAgainCallbackIDs[clientID] = timer:addCallbackTimer(0.3, function()
                    tryAgainCallbackIDs[clientID] = nil
                    sendInfos(clientID, mapPos, isChoosingTribeAndDistant, sanityCounter + 1, transientClientState)
                end)
            end
        end
    end

    if infosToSend[1] then
        --mj:log("sending destinations:", infosToSend)
        server:callClientFunction("addDestinationInfos", clientID, infosToSend, nil)
    end
end

function serverDestination:sendRecentClientDestinations(clientID)

    local transientClientState = transientClientStates[clientID]
    if not transientClientState.sentDestinationIDs then
        transientClientState.sentDestinationIDs = {}
    end

    local infosToSend = {}
    
	for i,recentPlayerInfo in ipairs(serverWorld.recentPlayerTribeList) do
        if not transientClientState.sentDestinationIDs[recentPlayerInfo.tribeID] then
            local destinationState = serverDestination:getDestinationState(recentPlayerInfo.tribeID, true)
            if destinationState then
                local sanitized = serverDestination:sanitizeDestinationForSendToClient(clientID, destinationState)
                --mj:log("sending destinationInfo for face id::", faceID, " sanitized:", sanitized)
                table.insert(infosToSend, sanitized)
                transientClientState.sentDestinationIDs[recentPlayerInfo.tribeID] = true
            end
        end
    end

    if infosToSend[1] then
        --mj:log("sending destinations:", infosToSend)
        server:callClientFunction("addDestinationInfos", clientID, infosToSend, nil)
    end
end

function serverDestination:sendUpdatedDestinationTribeCenters(destinationState)
    for clientID,v in pairs(serverWorld.connectedClientIDSet) do
        local transientClientState = transientClientStates[clientID]
        if transientClientState and transientClientState.sentDestinationIDs and transientClientState.sentDestinationIDs[destinationState.destinationID] then
            --mj:log("sendUpdatedDestinationTribeCenters:", destinationState.destinationID, " client:", clientID)
            server:callClientFunction("updateDestinationTribeCenters", clientID, {
                destinationID = destinationState.destinationID,
                tribeCenters = destinationState.tribeCenters,
            }, nil)
        end
    end
end

function serverDestination:sendDestinationRelationshipToClient(destinationState, clientTribeID)
    local clientID = serverWorld:clientIDForTribeID(clientTribeID)
    if clientID and serverWorld.connectedClientIDSet[clientID] then
        local relationship = destinationState.relationships and destinationState.relationships[clientTribeID]
        if relationship then
            server:callClientFunction("updateDestinationRelationship", clientID, {
                destinationID = destinationState.destinationID,
                relationship = relationship,
            }, nil)
        end
    end
end

function serverDestination:sendDestinationTradeables(destinationState)
    server:callClientFunctionForAllClients("updateDestinationTradeables", {
        destinationID = destinationState.destinationID,
        tradeables = destinationState.tradeables,
    })
end

function serverDestination:sendDestinationUpdateToAllClients(destinationState)
    for clientID,v in pairs(serverWorld.connectedClientIDSet) do
        local transientClientState = transientClientStates[clientID]
        if transientClientState and transientClientState.sentDestinationIDs and transientClientState.sentDestinationIDs[destinationState.destinationID] then
            local sanitized = serverDestination:sanitizeDestinationForSendToClient(clientID, destinationState)
            server:callClientFunction("updateDestination", clientID, sanitized, nil)
        end
    end
end

function serverDestination:sendPlayerOnlineStatusChangedToAllClients(destinationState, playerOnline)
    server:callClientFunctionForAllClients("updateDestinationPlayerOnlineStatus", {
        destinationID = destinationState.destinationID,
        playerOnline = playerOnline,
    })
end

local destinationIDsNeedingSave = {}

function  serverDestination:saveImmediately(destinationID)
    local destinationState = destinationStatesByDestinationID[destinationID]
    if destinationState then
        destinationsByIDDatabase:setDataForKey(destinationState, destinationID)
    end
end

function serverDestination:saveDestinationState(destinationID)
    destinationIDsNeedingSave[destinationID] = true
    --mj:log("saveTribeState:", destinationID)
    --[[local destinationState = destinationStatesByDestinationID[destinationID]
    if destinationState then
        destinationFacesNeedingSave[destinationState.faceID] = true
        --local destinationStatesForThisFace = serverDestination:getDestinationsForFace(destinationState.faceID, false)
        --destinationDatabase:setDataForKey(destinationStatesForThisFace, destinationState.faceID)
    end]]
end

function serverDestination:saveDestinationStates()
    for destinationID,v in pairs(destinationIDsNeedingSave) do
        local destinationState = destinationStatesByDestinationID[destinationID]
        if destinationState then
            destinationsByIDDatabase:setDataForKey(destinationState, destinationID)
        end
        --local destinationStatesForThisFace = serverDestination:getDestinationsForFace(faceID, false)
        --destinationDatabase:setDataForKey(destinationStatesForThisFace, faceID)
    end
    destinationIDsNeedingSave = {}
end

function serverDestination:getDestinationState(destinationID, useDatabaseIfNotLoaded) -- useDatabaseIfNotLoaded for once off cases where we don't want to load up and cache the entire area
    local destinationState = destinationStatesByDestinationID[destinationID]
    if not destinationState then
        if useDatabaseIfNotLoaded then
            destinationState = destinationsByIDDatabase:dataForKey(destinationID)
        else
            local faceID = facesByDestinationDatabase:dataForKey(destinationID)
            if faceID then
                serverDestination:getDestinationsForFace(faceID, false)
                destinationState = destinationStatesByDestinationID[destinationID]

                if not destinationState then
                    destinationState = destinationsByIDDatabase:dataForKey(destinationID)
                    if destinationState then
                        local thisFaceIDs = destinationIDsByFaceDatabase:dataForKey(destinationState.faceID)
                        if not thisFaceIDs[destinationID] then
                            mj:warn("Found destination state not assigned to correct face. This is probably some mess left over from migrating to 0.5, cleaning up.")
                            thisFaceIDs[destinationID] = true
                            destinationIDsByFaceDatabase:setDataForKey(thisFaceIDs, faceID)
                        end
                    end
                end

            end
        end
    end
    return destinationState
end



local markedHibernationCounters = {} -- it's too easy to create order related bugs hibernating too soon and reloading again, so let's be cautious and create a delay

function serverDestination:ensureLoaded(destinationState)
    if (not destinationState.loadState) or (destinationState.loadState == destination.loadStates.seed) then
        --mj:log("is seed state:", destinationState.destinationID)
        local seedLoadFunction = serverDestination.seedLoadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex]
        if seedLoadFunction then
            seedLoadFunction(destinationState)
            --mj:log("called load function, new loadState:", destinationState.loadState)
        --[[else --commented out just before 0.5 alpha, as it doesn't work for playerSelectionSeedTribe which should remain a seed here
            destinationState.loadState = destination.loadStates.complete
            serverDestination:saveDestinationState(destinationState.destinationID)]]
        end
    elseif destinationState.loadState == destination.loadStates.hibernating then
        markedHibernationCounters[destinationState.destinationID] = nil
        --mj:log("is hibernating state:", destinationState.destinationID)
        local hibernatingLoadFunction = serverDestination.hibernatingLoadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex]
        hibernatingLoadFunction(destinationState)
    end

    return (destinationState.loadState == destination.loadStates.loaded)
end


function serverDestination:loadAndHibernateSingleDestination(destinationID, hibernateImmediately)
    local destinationState = destinationStatesByDestinationID[destinationID]
    if (not destinationState) or (not serverDestination.shouldLoadAndHibernateByDestinationTypes[destinationState.destinationTypeIndex]) then
        return
    end

    local loadDistance2 = serverDestination.loadDistance * serverDestination.loadDistance
    local unloadDistance2 = serverDestination.unloadDistance * serverDestination.unloadDistance

    local currentLoadState = destinationState.loadState or destination.loadStates.seed

    local shouldUnload = false
    local shouldLoad = false

    local shouldUnloadFunction = serverDestination.shouldUnloadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex]
    if shouldUnloadFunction then
        shouldUnload = shouldUnloadFunction(destinationState)
    end

    if not shouldUnload then
        local minDistance2 = 99

        for clientID,v in pairs(serverWorld.connectedClientIDSet) do
            local transientClientState = transientClientStates[clientID]
            local function doCheck(a,b)
                local distance2 = length2(a - b)
                minDistance2 = math.min(minDistance2, distance2)
            end

            local checkPositions = destinationState.tribeCenters
            if (not checkPositions) or (not checkPositions[1]) then
                checkPositions = {
                    {
                        normalizedPos = destinationState.normalizedPos
                    }
                }
            end

            if transientClientState.loadAndHibernatePos then
                for i,destinationCenterInfo in ipairs(checkPositions) do
                    doCheck(transientClientState.loadAndHibernatePos, destinationCenterInfo.normalizedPos)
                end
            end

            local clientTribeID = serverWorld:tribeIDForClientID(clientID)
            if clientTribeID then
                local clientTribeDestinationState = serverDestination:getDestinationState(clientTribeID)
                if clientTribeDestinationState and clientTribeDestinationState.tribeCenters then
                    for i,destinationCenterInfo in ipairs(checkPositions) do
                        for j,clientCenterInfo in ipairs(clientTribeDestinationState.tribeCenters) do
                            doCheck(clientCenterInfo.normalizedPos, destinationCenterInfo.normalizedPos)
                        end
                    end
                end
            end
        end

        if minDistance2 < loadDistance2 then
            shouldLoad = true
        elseif minDistance2 > unloadDistance2 then
            shouldUnload = true
        end

    end

    if shouldLoad then
        --mj:log("within load distance")
        if destinationState.loadState ~= destination.loadStates.loaded then
            serverDestination:ensureLoaded(destinationState)
            if destinationState.loadState == destination.loadStates.loaded then
                serverDestination:saveImmediately(destinationID)
                return true
            end
        end
    elseif shouldUnload then
        --mj:log("shouldUnload:", destinationState.destinationID)
        if currentLoadState == destination.loadStates.loaded then
            local shouldKeepLoaded = false
            local shouldKeepLoadedFunction = serverDestination.shouldKeepLoadedFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex]
            if shouldKeepLoadedFunction then
                shouldKeepLoaded = shouldKeepLoadedFunction(destinationState)
            end
            --mj:log("is loaded state, hibernating:", destinationState.destinationID)
            --mj:log("shouldKeepLoaded:", shouldKeepLoaded)
            if not shouldKeepLoaded then
                markedHibernationCounters[destinationID] = (markedHibernationCounters[destinationID] or 0) + 1
                if hibernateImmediately or markedHibernationCounters[destinationID] > 2 then
                    markedHibernationCounters[destinationID] = nil
                    local unloadFunction = serverDestination.unloadFunctionsByDestinationTypeIndex[destinationState.destinationTypeIndex]
                    if not unloadFunction then
                        mj:error("no unloadFunction for destination type:", destination.types[destinationState.destinationTypeIndex])
                    end
                    --mj:log("calling unload function:", destinationID)
                    unloadFunction(destinationState)
                    if destinationState.loadState == destination.loadStates.hibernating then
                        --mj:log("hibernation success")
                        serverDestination:saveImmediately(destinationID)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function loadAndHibernate()
    --mj:log("loadAndHibernate")
    serverTribe:updateTribeCenters()

    for destinationID, destinationState in pairs(destinationStatesByDestinationID) do
        if serverDestination:loadAndHibernateSingleDestination(destinationID, false) then
            return
        end
    end

end


function serverDestination:loadAndSendDestinationsToClientForPos(clientID, mapPos, mapMode)
    if mapMode and mapMode <= 2 then
        return
    end
    local transientClientState = transientClientStates[clientID]
    local prevSendFaceID = transientClientState.sendFaceID
    local prevIsChoosingTribeAndDistant = transientClientState.isChoosingTribeAndDistant
    local isChoosingTribeAndDistant = (serverWorld:tribeIDForClientID(clientID) == nil) or (mapMode and mapMode > 2 and mapMode < 5)
    local normalizedMapPos = normalize(mapPos)

    local newSendFaceID = terrain:getFaceIDForNormalizedPointAtLevel(normalizedMapPos, serverDestination.sendTribesPlayerMovementLevel)

    if newSendFaceID and (newSendFaceID ~= prevSendFaceID or prevIsChoosingTribeAndDistant ~= isChoosingTribeAndDistant) then
        
        transientClientState.sendFaceID = newSendFaceID
        transientClientState.isChoosingTribeAndDistant = isChoosingTribeAndDistant
        transientClientState.pos = mapPos
        transientClientState.normalizedPos = normalizedMapPos


        if mapMode == nil then
            transientClientState.loadAndHibernatePos = normalizedMapPos
        end

        local prevGenerationFaceID = transientClientState.generationFaceID
        local newGenerationFace = terrain:getFaceForPointWithStartFace(mapPos, prevGenerationFaceID, serverDestination.generationPlayerMovementLevel)
        if newGenerationFace and (newGenerationFace.uniqueID ~= prevGenerationFaceID or prevIsChoosingTribeAndDistant ~= isChoosingTribeAndDistant) and newGenerationFace.level == serverDestination.generationPlayerMovementLevel then
            transientClientState.generationFaceID = newGenerationFace.uniqueID
            
            if not transientClientState.sentFaceIDs then
                transientClientState.sentFaceIDs = {}
            end
            --mj:log("sent")
            --mj:log("sending infos isChoosingTribeAndDistant:", isChoosingTribeAndDistant)
            sendInfos(clientID, mapPos, isChoosingTribeAndDistant, 0, transientClientState)
        end
    end
end

function serverDestination:findNearByTribesToCheckForSpawnVailidityForPos(mapPos)
    local faces = terrain:retrieveTrianglesWithinRadius(mapPos, serverDestination.generateSeedDistanceStandard, serverDestination.faceLevel)
    local infosToSend = {}

    for i,face in ipairs(faces) do 
        local destinationInfos = serverDestination:loadDestinationsIfNeededForFace(face)
        if destinationInfos then
            for destinationID,destinationInfo in pairs(destinationInfos) do 
                if not destinationInfo.clientID and not destinationInfo.nomad then
                    table.insert(infosToSend, destinationInfo)
                end
            end
        end
    end
    if infosToSend[1] then
        return infosToSend
    end
    
    return nil
end


function serverDestination:getBiomeTagsIfSuitableForTribeSpawn(pointNormalized, uniqueSeed)
    

    local biomeTags = terrain:getBiomeTagsForNormalizedPoint(pointNormalized)
    
    local crossDirection = normalize(cross(pointNormalized, vec3(0.0,1.0,0.0)))
    local southDirection = normalize(cross(pointNormalized, crossDirection))

    local function addTagsForDistance(distance)

        local lookupPoints = { 
            normalize(pointNormalized + crossDirection * distance),
            normalize(pointNormalized - crossDirection * distance),
            normalize(pointNormalized + southDirection * distance),
            normalize(pointNormalized - southDirection * distance),
        }

        for i,lookupPoint in ipairs(lookupPoints) do
            local pointBiomeTags = terrain:getBiomeTagsForNormalizedPoint(lookupPoint)
            for k,v in pairs(pointBiomeTags) do
                biomeTags[k] = true
            end
        end
    end
    addTagsForDistance(mj:mToP(80.0))
    addTagsForDistance(mj:mToP(200.0))
    --addTagsForDistance(mj:mToP(120.0))

    if not biome:getIsSuitableForTribeSpawn(biomeTags) then
        addTagsForDistance(mj:mToP(400.0))
    end


    return biomeTags
end


local function getCurved(fraction)
    if fraction > 0.5 then
        local foo = (fraction - 0.5) * 2.0
        return 0.5 + 0.5 * foo * foo
    else
        local foo = 1.0 - fraction * 2.0
        return 0.5 - 0.5 * foo * foo
    end
end

--[[for i=0,10 do
    mj:log("curve:", i/10, " result:", getCurved(i/10))
end]]


function serverDestination:loadDestinationsIfNeededForFace(triFace)
    
    --mj:error("loadDestinationsIfNeededForFace:", triFace.uniqueID)

    local versionIndex = faceDatabase:dataForKey(triFace.uniqueID)
    if versionIndex and versionIndex >= currentFaceDatabaseVersionIndex then
        --mj:log("up to date, returning saved")
        return serverDestination:getDestinationsForFace(triFace.uniqueID, false)
    end
    faceDatabase:setDataForKey(currentFaceDatabaseVersionIndex,triFace.uniqueID)


    local existingTribeStates = serverDestination:getDestinationsForFace(triFace.uniqueID, false)
    --local hasExistingTribeStatesToAdd = false
    --if existingTribeStates and next(existingTribeStates) then
    --    hasExistingTribeStatesToAdd = true
    --end

    if terrain:getHasRemovedTransientObjectsNearPos(triFace.centerNormalized) then
        return existingTribeStates
    end

    --if (not hasExistingTribeStatesToAdd) and (rng:integerForUniqueID(triFace.uniqueID, 269290, 3) == 1) then --simply discard 30% randomly
   --     return nil
   -- end

    local results = {}

    local verts = {
        triFace:getVert(0),
        triFace:getVert(1),
        triFace:getVert(2),
    }

    local foundGrassOrHay = false
    --local allOcean = true
    --local foundOcean = false

    for i, vert in ipairs(verts) do
        local terrainTypeIndex = vert.baseType
        if terrainTypeIndex == 0 then
            mj:warn("terrainTypeIndex == 0:", triFace.uniqueID) --this happens rarely, not sure why.
            return existingTribeStates
        end

        if vert.altitude > minAltitudeForConsideration then
            --allOcean = false
            local terrainType = terrainTypesModule.baseTypes[terrainTypeIndex]
            if terrainType.disableSpawn then
                return existingTribeStates
            elseif terrainType.reduceSpawn then
                if rng:integerForUniqueID(triFace.uniqueID, 8310952, 8) ~= 1 then
                    return existingTribeStates
                end
            end
        --else
            --foundOcean = true
        end

        if not foundGrassOrHay then
            local variations = vert:getVariations()
            if variations then
                for variationTypeIndex,v in pairs(variations) do
                    local variationType = terrainTypesModule.variations[variationTypeIndex]
                    if variationType.containsGrassOrHay then
                        foundGrassOrHay = true
                        break
                    end
                end
            end
        end
    end

    if (not foundGrassOrHay) then
        return existingTribeStates
    end

    local vertANormal = verts[1].normalizedVert
    local vertBNormal = verts[2].normalizedVert
    local vertCNormal = verts[3].normalizedVert

    local maxHeightRandomValue = rng:valueForUniqueID(triFace.uniqueID, 23234)
    local heightThresholdRandomValue = mj:mToP(1000.0) * maxHeightRandomValue * maxHeightRandomValue + mj:mToP(20.0)

    local function testAndAddLocation(pointNormalized, terrainHeight)
        if terrainHeight < heightThresholdRandomValue then
            local terrainNormal = terrain:getHighestDetailTerrainNormalAtPoint(pointNormalized)
            if dot(terrainNormal, pointNormalized) > 0.99 then
                local foundTooClose = false
                for i, result in ipairs(results) do
                    if length2(pointNormalized - result.center) < minDistanceBetweenTribes2 then
                        foundTooClose = true
                        break
                    end
                end
                if not foundTooClose then
                    table.insert(results, {
                        height = terrainHeight,
                        center = pointNormalized,
                    })
                end
            end
        end
    end

    local function offsetTowardsRiverOrHilltopAndAdd(pointNormal, seedOffset)

        local riverPoint = pointNormal
        local requiresWaterFind = false
        if (rng:integerForUniqueID(triFace.uniqueID, 36572, 4) ~= 1) then --note ~=, so 3/4 times
            riverPoint = terrain:getCloseRiverPointToPoint(pointNormal)
            if not riverPoint then
                riverPoint = pointNormal
            else
                requiresWaterFind = true
            end
        end

        if riverPoint then
            local randomVecNormalized = normalize(rng:vecForUniqueID(triFace.uniqueID, 34672 + seedOffset))
            local perpVec = normalize(cross(randomVecNormalized, riverPoint))
            local terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(riverPoint)
            local prevTerrainHeight = terrainResult.x
            if terrainResult.x < mj:mToP(0.1) then --start in water
                --foundOcean = true
                
                for i=1,8 do
                    local offsetPoint = normalize(riverPoint + perpVec * mj:mToP(400) * i)
                    terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(offsetPoint)
                    if terrainResult.x > mj:mToP(0.1) then --found land
                        testAndAddLocation(offsetPoint, terrainResult.x)
                        break
                    elseif prevTerrainHeight > terrainResult.x then --we're getting deeper
                        perpVec = -perpVec
                    end
                end

            else --started with land
                if requiresWaterFind then

                    local prevOffsetpoint = riverPoint
                    for i=1,8 do
                        local offsetPoint = normalize(riverPoint + perpVec * mj:mToP(400) * i)
                        terrainResult = terrain:getRawTerrainDataAtNormalizedPoint(offsetPoint)
                        if terrainResult.x < mj:mToP(-0.1) then --found water
                            testAndAddLocation(prevOffsetpoint, prevTerrainHeight)
                            break
                        elseif prevTerrainHeight < terrainResult.x then --we're getting higher
                            perpVec = -perpVec
                        end
                        prevOffsetpoint = offsetPoint
                        prevTerrainHeight = terrainResult.x
                    end
                else
                    testAndAddLocation(riverPoint, terrainResult.x)
                end
            end
        end
    end

    local sampleCountRandomValue = rng:valueForUniqueID(triFace.uniqueID, 162992)
    sampleCountRandomValue = sampleCountRandomValue * sampleCountRandomValue --rare large quantities, mostly small
    local sampleCount = math.floor(locationSampleCount * sampleCountRandomValue) + 1
   -- local quantityFraction = rng:valueForUniqueID(triFace.uniqueID, 162992)

   -- local maxSamplesWithWater = locationSampleCount * (0.4 + 0.6 * quantityFraction)
   -- local maxSamplesWithoutWater = locationSampleCount * (0.1 * quantityFraction)

    --if foundOcean then
    local aHeight = verts[1].altitude
    local bHeight = verts[1].altitude
    local cHeight = verts[1].altitude

    local xStartFraction = nil
    local yStartFraction = nil

    if ((aHeight > 1.0) ~= (bHeight > 1.0)) then
        xStartFraction = (1.0 - aHeight) / (bHeight - aHeight)
        xStartFraction = clamp(xStartFraction - 0.05, 0.0, 0.9)
    end
    if ((aHeight > 1.0) ~= (cHeight > 1.0)) then
        yStartFraction = (1.0 - aHeight) / (cHeight - aHeight)
        yStartFraction = clamp(yStartFraction - 0.05, 0.0, 0.9)
    end

    for i=1,sampleCount do
        local xFraction = rng:valueForUniqueID(triFace.uniqueID, i * 3 + 42358)
        local yFraction = rng:valueForUniqueID(triFace.uniqueID, i * 3 + 322)


        if xStartFraction then
            xFraction = xStartFraction + xFraction * 0.1
        else
            xFraction = getCurved(xFraction)
        end
        if yStartFraction then
            yFraction = yStartFraction + yFraction * 0.1
        else
            yFraction = getCurved(yFraction)
        end
        local pointNormalized = normalize(randomPointWithinTriangle(vertANormal, vertBNormal, vertCNormal, xFraction, yFraction))
        offsetTowardsRiverOrHilltopAndAdd(pointNormalized, i)
        --if pointNormalized then
          --  testLocation(pointNormalized)
        --end

        --[[if foundOcean then
            if i >= maxSamplesWithWater then
                break
            end
        else
            if i >= maxSamplesWithoutWater then
                break
            end
        end]]
    end
        
    --[[else
        if rng:integerForUniqueID(triFace.uniqueID, 968991, 4) ~= 1 then
            return existingTribeStates
        end
        for i=1,sampleCount do
            local xFraction = rng:valueForUniqueID(triFace.uniqueID, i * 3 + 42358)
            local yFraction = rng:valueForUniqueID(triFace.uniqueID, i * 3 + 322)
            local pointNormalized = normalize(randomPointWithinTriangle(vertANormal, vertBNormal, vertCNormal, xFraction, yFraction))
            testLocation(pointNormalized)
        end
    end]]
    

    if results and results[1] then
        
        local destinationCount = #results
        --mj:log("result count:", #results)

        --[[local destinationStates = nil
        if existingTribeStates then
            destinationStates = mj:cloneTable(existingTribeStates)
        else
            destinationStates = {}
        end]]

        local newDestinationStates = {}

        local biomeTags = nil


        for i=1,destinationCount do
            local thisCenter = results[i].center
            local tooClose = serverTribe:getAnyOtherDestinationTooClose(thisCenter)
            if not tooClose then
                local destinationID = serverGOM:reserveUniqueID()
                local destinationState = serverTribe:createTribeDestination(destinationID, thisCenter, nil, nil, biomeTags)
                if destinationState then
                    newDestinationStates[destinationState.destinationID] = destinationState
                end
            end
        end


        if next(newDestinationStates) then

            local faceDestinationsByFaceID = {}
            local faceDestinationIDsByFaceID = {}
            for destinationID,destinationState in pairs(newDestinationStates) do
                local faceDestinations = faceDestinationsByFaceID[destinationState.faceID]
                if not faceDestinations then
                    faceDestinations = serverDestination:getDestinationsForFace(destinationState.faceID, true)
                    faceDestinationsByFaceID[destinationState.faceID] = faceDestinations
                    faceDestinationIDsByFaceID[destinationState.faceID] = destinationIDsByFaceDatabase:dataForKey(destinationState.faceID)
                end
                faceDestinations[destinationID] = destinationState
                faceDestinationIDsByFaceID[destinationState.faceID][destinationID] = true

                destinationsByIDDatabase:setDataForKey(destinationState, destinationID)
            end

            for faceID,faceDestinationIDsSet in pairs(faceDestinationIDsByFaceID) do
                destinationIDsByFaceDatabase:setDataForKey(faceDestinationIDsSet, faceID)
            end

            return faceDestinationsByFaceID[triFace.uniqueID] or existingTribeStates
        end


        --[[if next(destinationStates) then
            if hasExistingTribeStatesToAdd then
                for destinationID,destinationState in pairs(destinationStates) do
                    --mj:log("added existing:", destinationState.destinationID)
                    existingTribeStates[destinationID] = destinationState
                    mj:log("adding existing with faceID:", destinationState.faceID)
                end
                mj:log("saving to destination database a triFace.uniqueID:", triFace.uniqueID)
                destinationDatabase:setDataForKey(existingTribeStates, triFace.uniqueID)
                return existingTribeStates
            else
                mj:log("saving to destination database b triFace.uniqueID:", triFace.uniqueID)
                destinationDatabase:setDataForKey(destinationStates, triFace.uniqueID)
                return destinationStates
            end
        end]]
    end

    return existingTribeStates
end

function serverDestination:wakeTribeDebug(destinationID)
    mj:log("serverDestination:wakeTribeDebug:", destinationID)
    local clientID = serverWorld:clientIDForTribeID(destinationID)
    if clientID then
        --mj:log("clientID:", clientID)
        serverWorld:loadClientStateIfNeededForSapienTribeID(destinationID)
        local privateSharedState = serverWorld:getPrivateSharedClientState(clientID)
        if privateSharedState then
            local destinationState = serverDestination:getDestinationState(destinationID)
            if destinationState then
                privateSharedState.hibernationDurationKey = "twoDays"
                serverWorld:saveClientState(clientID)

                --mj:log("destinationState:", destinationState)
            
                destinationState.clientDisconnectWorldTime = nil
                serverDestination:ensureLoaded(destinationState)
                serverDestination:saveDestinationState(destinationState.destinationID)
                serverResourceManager:addTribe(destinationState)
            end

        end
    end
end


function serverDestination:updateDestinationPos(destinationState, newNormalizedPos)
    destinationState.normalizedPos = newNormalizedPos
    destinationState.pos = terrain:getHighestDetailTerrainPointAtPoint(newNormalizedPos)
    local newFaceID = terrain:getFaceIDForNormalizedPointAtLevel(newNormalizedPos, serverDestination.faceLevel)
    local oldFaceID = destinationState.faceID
    --mj:log("serverDestination:updateDestinationPos oldFaceID:", oldFaceID, " newFaceID:", newFaceID)
    if newFaceID ~= oldFaceID then
        local destinationIDsForOldFace = destinationIDsByFaceDatabase:dataForKey(oldFaceID)
        if destinationIDsForOldFace and destinationIDsForOldFace[destinationState.destinationID] then
            destinationIDsForOldFace[destinationState.destinationID] = nil
            destinationIDsByFaceDatabase:setDataForKey(destinationIDsForOldFace, oldFaceID)
        end

        destinationState.faceID = newFaceID

        --mj:log("serverDestination:updateDestinationPos FACE ID CHANGED from:", oldFaceID, " -> ", newFaceID, " for:", destinationState.destinationID)

        local destinationIDsForNewFace = destinationIDsByFaceDatabase:dataForKey(newFaceID) or {}
        if not destinationIDsForNewFace[destinationState.destinationID] then
            destinationIDsForNewFace[destinationState.destinationID] = true
            destinationIDsByFaceDatabase:setDataForKey(destinationIDsForNewFace, newFaceID)
        end

        facesByDestinationDatabase:setDataForKey(destinationState.faceID, destinationState.destinationID)
    end

    destinationsByIDDatabase:setDataForKey(destinationState, destinationState.destinationID)

    --serverDestination:saveDestinationState(destinationState.destinationID)
end


local destinationInfosToSend = {}
local function sendClientDestinations() --this needs to be delayed until the next update tick to ensure terrain is loaded
	for clientID,info in pairs(destinationInfosToSend) do
		serverDestination:loadAndSendDestinationsToClientForPos(clientID, info.posToUseForTerrain, info.mapMode)
	end

	destinationInfosToSend = {}
end

function serverDestination:queueSendDestinationInfoForClient(clientID, posToUseForTerrain, mapMode)
    destinationInfosToSend[clientID] = {
        posToUseForTerrain = posToUseForTerrain,
        mapMode = mapMode,
    }
end

local loadAndHibernateTimer = 0.0
function serverDestination:update(dt)
    loadAndHibernateTimer = loadAndHibernateTimer + dt
    if loadAndHibernateTimer >= serverDestination.loadAndHibernateTimerDelay then
        loadAndHibernateTimer = 0.0
        loadAndHibernate()
    end

    sendClientDestinations()
end

function serverDestination:init(server_, serverWorld_, serverGOM_, serverTerrain_, transientClientStates_)
    server = server_
    serverWorld = serverWorld_
    serverGOM = serverGOM_
    terrain = serverTerrain_
    transientClientStates = transientClientStates_

    destinationsByIDDatabase = serverWorld:getDatabase("destinationsByID")
    destinationIDsByFaceDatabase = serverWorld:getDatabase("destinationsByFaceDatabase")

    facesByDestinationDatabase = serverWorld:getDatabase("facesByTribes")
    faceDatabase = serverWorld:getDatabase("tribeFaces")

    local destinationDatabaseLegacy = serverWorld:getDatabase("tribes", false) --destinations used to be called tribes < 0.5
    if destinationDatabaseLegacy then
        if not destinationDatabaseLegacy:dataForKey("migrationComplete") then
            --mj:log("migrating destinations to 0.5.41")

            local allData = destinationDatabaseLegacy:allData()
            if allData then
                for faceID,destinations in pairs(allData) do
                    local destinationIDs = {}
                    for destinationID,destinationState in pairs(destinations) do
                        destinationIDs[destinationID] = true
                        destinationsByIDDatabase:setDataForKey(destinationState, destinationID)
                    end
                    if next(destinationIDs) then
                        destinationIDsByFaceDatabase:setDataForKey(destinationIDs, faceID)
                    end
                    destinationDatabaseLegacy:removeDataForKey(faceID)
                end
            end

            destinationDatabaseLegacy:setDataForKey(true, "migrationComplete")
            --mj:log("migration complete")
        end
    end

   --[[ if not destinationIDsByFaceDatabase:dataForKey("migration_46b") then --clean up after a bug where destination states were saved in this database still. This can be removed safely around July '24
       -- mj:log("migrating destinations for 0.5.0.46, this may take a while...")

        local badData = {}
        local badCount = 0
        destinationIDsByFaceDatabase:callFunctionForAllKeys(function(faceID,destinationIDs) --might not be a good idea to modifiy the database in here
            if type(destinationIDs) == "table" then
                for destinationID,v in pairs(destinationIDs) do
                    if v ~= true then
                        destinationIDs[destinationID] = true
                        badData[faceID] = destinationIDs
                        badCount = badCount + 1
                    end
                end
            end
        end)
        for key,destinationIDs in pairs(badData) do
            --mj:log("set destination ids:", destinationIDs)
            destinationIDsByFaceDatabase:setDataForKey(destinationIDs, key)
        end
       -- mj:log("Migration complete. Bad destination count:", badCount)
        destinationIDsByFaceDatabase:setDataForKey(true, "migration_46b")
    end]]


	--[[if next(serverWorld.validOwnerTribeIDs) then
		for tribeID,v in pairs(serverWorld.validOwnerTribeIDs) do
			local destinationFaceID = facesByDestinationDatabase:dataForKey(tribeID)

			mj:log("found destinationFaceID:", destinationFaceID)
            if destinationFaceID then
                terrain:addTemporaryAnchorForFaceID(destinationFaceID, serverDestination.faceLevel)
            end
		end
	end]]
end

return serverDestination
