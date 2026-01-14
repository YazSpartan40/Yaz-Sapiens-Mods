--local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
--local mat3Identity = mjm.mat3Identity

local resource = mjrequire "common/resource"
local gameObject = mjrequire "common/gameObject"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local model = mjrequire "common/model"
local weather = mjrequire "common/weather"
local rng = mjrequire "common/randomNumberGenerator"

local logic = mjrequire "logicThread/logic"
local logicAudio = mjrequire "logicThread/logicAudio"

local clientFlora = {
    birdSoundPlayDelayMultiplier = 2.0,
    birdSoundVolume = 0.25,
}

local clientGOM = nil


clientFlora.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    clientFlora:updateTreeOrBushSubModels(object)
end

local function updateSeasonChangeCallback(object) --todo no need to call callback for plants that never change between seasons
    --mj:log("updateSeasonChangeCallback callback:", object.uniqueID)
    local timeUntilChange = logic:getTimeUntilNextSeasonChange(0.01 + 0.1 * rng:valueForUniqueID(object.uniqueID, 32987))
    clientGOM:addObjectCallbackTimerForWorldTime(object.uniqueID, logic.worldTime + timeUntilChange, function(objectID)
        local object_ = clientGOM:getObjectWithID(objectID)
        if object_ then
            clientGOM:reloadModelIfNeededForObject(objectID)
            updateSeasonChangeCallback(object_)
        end
    end)
end


local birdTypes = {
    {
        tracks = {
            {
                delayAverage = 80.0,
                file = "audio/sounds/bird1.wav",
                maxCount = 1,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 60.0,
                file = "audio/sounds/bird2.wav",
                maxCount = 1,
            },
            {
                delayAverage = 4.0,
                file = "audio/sounds/bird2-2.wav",
                maxCount = 5,
                nextPlay = 0.6,
            },
            {
                delayAverage = 7.0,
                file = "audio/sounds/bird2-3.wav",
                maxCount = 1,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 40.0,
                file = "audio/sounds/bird3.wav",
                maxCount = 3,
                nextPlay = 0.3,
            },
            {
                delayAverage = 8.0,
                file = "audio/sounds/bird3-2.wav",
                maxCount = 4,
                nextPlay = 0.9,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 40.0,
                file = "audio/sounds/bird4.wav",
                maxCount = 4,
                nextPlay = 1.5,
            },
            {
                delayAverage = 4.0,
                file = "audio/sounds/bird4-2.wav",
                maxCount = 1,
            },
            {
                delayAverage = 20.0,
                file = "audio/sounds/bird4-3.wav",
                maxCount = 1,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 120.0,
                file = "audio/sounds/bird5.wav",
                maxCount = 2,
                nextPlay = 1.5,
            },
        },
        {
            {
                delayAverage = 90.0,
                file = "audio/sounds/bird6.wav",
                maxCount = 1,
            },
            {
                delayAverage = 8.0,
                file = "audio/sounds/bird6-2.wav",
                maxCount = 2,
                nextPlay = 0.8,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 70.0,
                file = "audio/sounds/bird6-3.wav",
                maxCount = 2,
                nextPlay = 0.8,
            },
            {
                delayAverage = 35.0,
                file = "audio/sounds/bird6-4.wav",
                maxCount = 3,
                nextPlay = 0.4,
            },
            {
                delayAverage = 35.0,
                file = "audio/sounds/bird6-5.wav",
                maxCount = 3,
                nextPlay = 2.0,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 180.0,
                file = "audio/sounds/bird7.wav",
                maxCount = 2,
                nextPlay = 5.0,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 40.0,
                file = "audio/sounds/bird7-2.wav",
                maxCount = 1,
            },
            {
                delayAverage = 10.0,
                file = "audio/sounds/bird7-3.wav",
                maxCount = 2,
                nextPlay = 3.0,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 80.0,
                file = "audio/sounds/bird8.wav",
                maxCount = 3,
                nextPlay = 0.6,
            },
        },
        {
            {
                delayAverage = 40.0,
                file = "audio/sounds/bird9.wav",
                maxCount = 5,
                nextPlay = 1.0,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 60.0,
                file = "audio/sounds/bird10.wav",
                maxCount = 3,
                nextPlay = 0.3,
            },
            {
                delayAverage = 10.0,
                file = "audio/sounds/bird10-2.wav",
                maxCount = 2,
                nextPlay = 0.3,
            },
            {
                delayAverage = 10.0,
                file = "audio/sounds/bird10-3.wav",
                maxCount = 2,
                nextPlay = 0.5,
            },
        }
    },
    {
        tracks = {
            {
                delayAverage = 160.0,
                file = "audio/sounds/owl1.wav",
                maxCount = 3,
                nextPlay = 10.0,
            },
        },
        nocturnal = true,
    },
    {
        tracks = {
            {
                delayAverage = 20.0,
                file = "audio/sounds/crickets1.wav",
                maxCount = 3,
                nextPlay = 2.5,
            },
        },
        nocturnal = true,
    },
    {
        tracks = {
            {
                delayAverage = 20.0,
                file = "audio/sounds/crickets2.wav",
                maxCount = 3,
                nextPlay = 2.5,
            },
        },
        nocturnal = true,
    },
    {
        tracks = {
            {
                delayAverage = 20.0,
                file = "audio/sounds/crickets3.wav",
                maxCount = 3,
                nextPlay = 2.5,
            },
        },
        nocturnal = true,
    },
}

local function getOrCreateBirdClientState(clientState, tracks, birdType)
    
    local birdPlayState = clientState.birdPlayState

    if not birdPlayState or birdPlayState.birdType ~= birdType then
        birdPlayState = {
            trackIndex = 1,
            subIndex = 1,
            birdType = birdType,
        }
        clientState.birdPlayState = birdPlayState

        local newTrackMaxCount = tracks[birdPlayState.trackIndex].maxCount
        if newTrackMaxCount > 1 then
            birdPlayState.subPlayCount = rng:randomInteger(newTrackMaxCount) + 1
        else
            birdPlayState.subPlayCount = 1
        end
    end

    return birdPlayState
end

local function updateBirdSongCallback(object, birdType, firstAdd)
   -- mj:log("updateBirdSongCallback:", birdType)
    local timeToDelay = 10.0
    local isNight = (logic.timeOfDayFraction < 0.2 or logic.timeOfDayFraction > 0.8)
    local nocturnalMatch = ((not isNight) == (not birdTypes[birdType].nocturnal))
    if firstAdd or (object.subdivLevel > mj.SUBDIVISIONS - 3 and nocturnalMatch) then
        local clientState = clientGOM:getClientState(object)

        local tracks = birdTypes[birdType].tracks
        local birdPlayState = getOrCreateBirdClientState(clientState, tracks, birdType)

        if birdPlayState.subIndex > 1 and birdPlayState.subPlayCount > 1 then
            
            if not tracks[birdPlayState.trackIndex].nextPlay then
                mj:error("not tracks[birdPlayState.trackIndex].nextPlay:", birdPlayState, " birdType:", birdType, " tracks:", tracks)
            end

            timeToDelay = (1.0 + (rng:valueForUniqueID(object.uniqueID, 67742) * 0.1)) * tracks[birdPlayState.trackIndex].nextPlay
        else
            local delayAverage = tracks[birdPlayState.trackIndex].delayAverage * clientFlora.birdSoundPlayDelayMultiplier
            timeToDelay = (rng:valueForUniqueID(object.uniqueID, 67742) + 0.5) * delayAverage
        end
    end
    --mj:log("timeToDelay:", timeToDelay)
    clientGOM:addObjectCallbackTimerForWorldTime(object.uniqueID, logic.worldTime + timeToDelay, function(objectID)
        local object_ = clientGOM:getObjectWithID(objectID)
        if object_ then
            local isNightReloaded = (logic.timeOfDayFraction < 0.2 or logic.timeOfDayFraction > 0.8)
            local nocturnalMatchReloaded = ((not isNightReloaded) == (not birdTypes[birdType].nocturnal))
            --mj:log("callback:", object_.subdivLevel)
            if object_.subdivLevel > mj.SUBDIVISIONS - 2 and nocturnalMatchReloaded then
                if weather:getWindStrength() < 10.0 then
                    local tracks = birdTypes[birdType].tracks
                    local clientState = clientGOM:getClientState(object_)
                    local birdPlayState = getOrCreateBirdClientState(clientState, tracks, birdType)
                    
                    if not tracks[birdPlayState.trackIndex] then
                        mj:error("not tracks[birdPlayState.trackIndex]:", birdPlayState, " birdType:", birdType, " tracks:", tracks)
                        error()
                    end

                    --mj:log("playWorldSound:", object.uniqueID)
                    logicAudio:playWorldSound(tracks[birdPlayState.trackIndex].file, object_.pos, clientFlora.birdSoundVolume, nil, 140)

                    local incrementTrack = true
                    if birdPlayState.subPlayCount > 1 then
                        birdPlayState.subIndex = birdPlayState.subIndex + 1
                        if birdPlayState.subIndex <= birdPlayState.subPlayCount then
                            incrementTrack = false
                        end
                    end

                    if incrementTrack then
                        birdPlayState.trackIndex = birdPlayState.trackIndex + 1
                        if birdPlayState.trackIndex > #tracks then
                            birdPlayState.trackIndex = 1
                        end

                        birdPlayState.subIndex = 1
                        local newTrackMaxCount = tracks[birdPlayState.trackIndex].maxCount
                        if newTrackMaxCount > 1 then
                            birdPlayState.subPlayCount = rng:randomInteger(newTrackMaxCount) + 1
                        else
                            birdPlayState.subPlayCount = 1
                        end
                    end
                end
            end
            updateBirdSongCallback(object, birdType, false)
        end
    end)
end

clientFlora.objectWasLoaded = function(object, pos, rotation, scale)
    clientFlora:updateTreeOrBushSubModels(object)
    updateSeasonChangeCallback(object)
    if gameObject.types[object.objectTypeIndex].playBirdSounds then
        local birdType = rng:integerForUniqueID(object.uniqueID, 234625467, 100)
        if birdType < #birdTypes then
            updateBirdSongCallback(object, birdType + 1, true)
        end
    end
end

clientFlora.objectSnapMatrix = function(object, pos, rotation)
    clientFlora:updateTreeOrBushSubModels(object)
end

clientFlora.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientFlora:updateTreeOrBushSubModels(object)
    end
end

local function updateStandardSubModels(object, placeholderKeys)
    for i,key in pairs(placeholderKeys) do
        local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key)
        if placeholderInfo.defaultModelIndex then
            
            local subModelTransform = clientGOM:getSubModelTransform(object, key)
            clientGOM:setSubModelForKey(object.uniqueID,
                key,
                nil,
                placeholderInfo.defaultModelIndex,
                placeholderInfo.scale or 1.0,
                RENDER_TYPE_STATIC,
                subModelTransform.offsetMeters,
                subModelTransform.rotation,
                false,
                nil
                )
        end
    end
end



function clientFlora:updateTreeOrBushSubModels(object)
    clientGOM:setTransparentBuildObject(object.uniqueID, false)
    
    --[[if object.sharedState then
        mj:log("flora object.sharedState:", object.sharedState, " object:", object.uniqueID)
    end]]

    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(object.modelIndex)
    if placeholderKeys then
        if object.sharedState then
            local placeholderKeysRemaining = {}

            for i,key in pairs(placeholderKeys) do
                placeholderKeysRemaining[key] = true
            end

            if object.sharedState.inventory and object.sharedState.inventory.countsByObjectType then
                
                local countsByObjectType = object.sharedState.inventory.countsByObjectType

                local foundCountsByResourceType = {}

                for objectTypeIndex, count in pairs(countsByObjectType) do
                    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                    if resourceTypeIndex then
                        for i=1,count do 
                            local resourceIndex = 1
                            if foundCountsByResourceType[resourceTypeIndex] then
                                foundCountsByResourceType[resourceTypeIndex] = foundCountsByResourceType[resourceTypeIndex] + 1
                                resourceIndex = foundCountsByResourceType[resourceTypeIndex]
                            else
                                foundCountsByResourceType[resourceTypeIndex] = 1
                            end

                            local key = resource.types[resourceTypeIndex].key .. "_" .. mj:tostring(resourceIndex)
                            if placeholderKeysRemaining[key] then
                                placeholderKeysRemaining[key] = nil
                                
                                local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key) --todo use objectTypeIndex to sub models properly
                                local modelIndex = model:modelIndexForDetailedModelIndexAndDetailLevel(placeholderInfo.defaultModelIndex, model:modelLevelForSubdivLevel(object.subdivLevel))
                                
                                local subModelTransform = clientGOM:getSubModelTransform(object, key)

                                clientGOM:setSubModelForKey(object.uniqueID,
                                    key,
                                    nil,
                                    modelIndex,
                                    placeholderInfo.scale or 1.0,
                                    RENDER_TYPE_STATIC,
                                    subModelTransform.offsetMeters,
                                    subModelTransform.rotation,
                                    false,
                                    nil
                                    )
                            end
                        end
                    end
                end
                
            end
            for key,v in pairs(placeholderKeysRemaining) do
                local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key) --todo use objectTypeIndex to sub models properly
                local modelIndex = model:modelIndexForDetailedModelIndexAndDetailLevel(placeholderInfo.defaultModelIndex, model:modelLevelForSubdivLevel(object.subdivLevel))
                
                if (not placeholderInfo.resourceTypeIndex) and placeholderInfo.defaultModelIndex then
                    
                    local subModelTransform = clientGOM:getSubModelTransform(object, key)
                    clientGOM:setSubModelForKey(object.uniqueID,
                        key,
                        nil,
                        modelIndex,
                        placeholderInfo.scale or 1.0,
                        RENDER_TYPE_STATIC,
                        subModelTransform.offsetMeters,
                        subModelTransform.rotation,
                        false,
                        nil
                        )
                else
                    clientGOM:removeSubModelForKey(object.uniqueID, key)
                end
            end

        else
            updateStandardSubModels(object, placeholderKeys) --no
        end
    end
end




function clientFlora:init(clientGOM_)
    clientGOM = clientGOM_

end

return clientFlora