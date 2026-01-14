
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local mat3GetRow = mjm.mat3GetRow
local length2 = mjm.length2
local length = mjm.length
local clientGameSettings = mjrequire "mainThread/clientGameSettings"

local audio = {}


local bridge = nil
local logicInterface = nil

local playerPos = vec3(0.0,0.0,0.0)
local maxPlayDistance2 = mj:mToP(100.0) * mj:mToP(100.0)
local lastUpdatedLoopingSoundsPlayerPos = vec3(0.0,0.0,0.0)
local updateLoopingSoundsDistance2 = mj:mToP(2.0) * mj:mToP(2.0)
local rainNoise = mjNoise(789, 0.6) --seed, persistance
local loopingSoundInfosByID = {}
local soundsPaused = false
local speedMultiplier = 1.0

local maxLoopingSoundPlaysPerFile = 2
local singlePlaySounds = {
    ["audio/sounds/events/conflictLoop.wav"] = {}
}

for k,v in pairs(singlePlaySounds) do
    v.name = k
    v.positions = {}
end

local playingWorldSounds = {}
local playingWorldSoundCounts = {}

local function updateLoopingSoundDistances()
    lastUpdatedLoopingSoundsPlayerPos = playerPos

    local orderedSoundsByName = {}

    for soundID, soundInfo in pairs(loopingSoundInfosByID) do
        local soundName = soundInfo.name
        local orderedSounds = orderedSoundsByName[soundName]
        if not orderedSounds then
            orderedSounds = {}
            orderedSoundsByName[soundName] = orderedSounds
        end
        soundInfo.distanceFromPlayer2 = length2(playerPos - soundInfo.pos)
        table.insert(orderedSounds, soundInfo)
    end

    
    local function sortByDistance(a,b)
        return a.distanceFromPlayer2 < b.distanceFromPlayer2
    end


    for soundName, orderedArray in pairs(orderedSoundsByName) do
        table.sort(orderedArray, sortByDistance)
        for i, soundInfo in ipairs(orderedArray)  do
            if i <= maxLoopingSoundPlaysPerFile and soundInfo.distanceFromPlayer2 < maxPlayDistance2 then
                if not soundInfo.sound then
                    local sound = bridge:loadSound3D(soundInfo.name, false)
                    soundInfo.sound = sound
                    sound:setLooping(true)
                    sound.completionCallback = function(channel) --fmod is weird, it sometimes allows looping sounds to complete. Not sure why exactly, but we can handle it here in the callback
                        for soundID, soundInfoReloaded in pairs(loopingSoundInfosByID) do
                            if soundInfoReloaded.name == soundInfo.name then
                                if soundInfoReloaded.channel == channel then
                                    soundInfoReloaded.channel = nil
                                end
                            end
                        end
                    end
                end
                if not soundInfo.channel then
                    local channel = soundInfo.sound:play(soundInfo.pos, 1.0, 1.0)
                    soundInfo.channel = channel
                    if soundsPaused then
                        soundInfo.sound:setPaused(true, channel)
                    end
                end
            else
                if soundInfo.channel then
                    soundInfo.sound:stop(soundInfo.channel)
                    soundInfo.channel = nil
                end
            end
        end
    end

    for soundName, soundInfo in pairs(singlePlaySounds) do
        local closestThreatDistance2 = 1000.0
        local closestThreatPos = vec3(0.0,0.0,0.0)
        for objectID,pos in pairs(soundInfo.positions) do
            local thisDistance2 = length2(playerPos - pos)
            if thisDistance2 < closestThreatDistance2 then
                closestThreatDistance2 = thisDistance2
                closestThreatPos = pos
            end
        end

        if closestThreatDistance2 < maxPlayDistance2 then
            local averagePos = closestThreatPos
            
            if not soundInfo.sound then
                local sound = bridge:loadSound3D(soundInfo.name, false)
                soundInfo.sound = sound
                sound:setLooping(true)
                sound.completionCallback = function(channel) --fmod is weird, it sometimes allows looping sounds to complete. Not sure why exactly, but we can handle it here in the callback
                    if singlePlaySounds[soundInfo.name] then
                        if singlePlaySounds[soundInfo.name].channel == channel then
                            singlePlaySounds[soundInfo.name].channel = nil
                        end
                    end
                end
            end

            if not soundInfo.channel then
                local channel = soundInfo.sound:play(averagePos, 0.5, 1.0) --50% volume bit of a hack, the drums need dialing back and it probably applies to any future loops
                soundInfo.channel = channel
                if soundsPaused then
                    soundInfo.sound:setPaused(true, channel)
                end
            else
                soundInfo.sound:setPos(averagePos)
            end
        else
            if soundInfo.channel then
                soundInfo.sound:stop(soundInfo.channel)
                soundInfo.channel = nil
            end
        end
    end
end

function audio:preloadUISound(name)
    bridge:loadSound2D(name, true)
end

function audio:playUISound(name, volumeOrNil, pitchOrNil)
    local sound = bridge:loadSound2D(name, false)
    return sound:play((volumeOrNil or 1.0) * 0.6, pitchOrNil or 1.0)
end

local function getPitchMultiplier()
    if speedMultiplier > 1.1 then
        if speedMultiplier > 10.0 then
            return 2.0
        else
            return 1.5
        end
    end
    return 1.0
end

local function getRainWindPitchMultiplier()
    if speedMultiplier > 1.1 then
        if speedMultiplier > 10.0 then
            return 2.0
        else
            return 1.5
        end
    end
    return 1.0
end

function audio:playWorldSound(name, pos, volumeOrNil, pitchOrNil, priorityOrNil, maxPlayDistanceOrNIl, completionCallbackIDOrNil)-- priority default is 127. 0 most important, 255 least
    local distance2 = length2(pos - playerPos)
    if distance2 <  (maxPlayDistanceOrNIl or maxPlayDistance2) then

        if playingWorldSoundCounts[name] and playingWorldSoundCounts[name] > 2 then
            return nil
        end

        local sound = bridge:loadSound3D(name, false)
        local soundPlayInstances = playingWorldSounds[name]
        if not soundPlayInstances then
            soundPlayInstances = {}
            playingWorldSounds[name] = soundPlayInstances
        end
        
        sound.completionCallback = function(channel)
           -- mj:log("callback for finished sound:", name, " channel:", channel, " soundPlayInstances[channel]:", soundPlayInstances[channel])
            if soundPlayInstances[channel] then
                if soundPlayInstances[channel].completionCallbackID then
                    logicInterface:callLogicThreadFunction("worldPlaySoundComplete", soundPlayInstances[channel].completionCallbackID)
                end
                soundPlayInstances[channel] = nil
                playingWorldSoundCounts[name] = playingWorldSoundCounts[name] - 1
            end
        end
        
        if priorityOrNil then
            sound:setPriority(priorityOrNil, 0)
        end

        local channel = sound:play(pos, volumeOrNil or 1.0, (pitchOrNil or 1.0) * getPitchMultiplier())

        playingWorldSoundCounts[name] = (playingWorldSoundCounts[name] or 0) + 1
        
        --mj:log("playing world sound:", name, " channel:", channel)

        soundPlayInstances[channel] = {
            sound = sound,
            pitch = (pitchOrNil or 1.0),
            completionCallbackID = completionCallbackIDOrNil,
        }

        if soundsPaused then
            sound:setPaused(true, channel)
        end
        
        return channel
    end
    return nil
end

function audio:stopWorldSound(name, channel)
    
    --mj:log("sound:", sound, " channel:", channel, " playingWorldSounds[sound]:",playingWorldSounds[sound] )
    local soundPlayInstances = playingWorldSounds[name]
    if soundPlayInstances and soundPlayInstances[channel] then
        local sound = soundPlayInstances[channel].sound
        --mj:log("calling stop")
        sound:stop(channel)
        soundPlayInstances[channel] = nil
    end
end

function audio:playSong(name, volumeOrNil, completionCallbackOrNil)
    local song = bridge:loadSong(name, false)
    if completionCallbackOrNil then
        song.completionCallback = completionCallbackOrNil
    end
    song:play(volumeOrNil or 1.0)
end

function audio:getQueuedOrPlayingSong()
    return bridge:getQueuedOrPlayingSong()
end

function audio:fadeOutAnyCurrentSong()
    bridge:fadeOutAnyCurrentSong()
end


function audio:getMusicVolume()
    return bridge.musicVolume
end

function audio:setMusicVolume(newVolume)
    bridge.musicVolume = newVolume
end

function audio:getSoundVolume()
    return bridge.soundVolume
end

function audio:setSoundVolume(newVolume)
    bridge.soundVolume = newVolume
end

function audio:setBridge(bridge_)
    bridge = bridge_
end

local ambientSoundInfos = {}
for i=1,4 do
    ambientSoundInfos[i] = {
        noiseValue = 0.0,
    }
end

local rainAmount = 0.0
local windAmount = 0.0
local rainMasterVolume = 0.7
local windMasterVolume = 1.5

local rainSoundPathsHeavy = {
    "audio/sounds/rainHeavy1.wav",
    "audio/sounds/rainHeavy2.wav",
    "audio/sounds/rainHeavy3.wav",
    "audio/sounds/rainHeavy4.wav"
}

local windSoundPaths = {
    "audio/sounds/wind1.wav",
    "audio/sounds/wind2.wav",
    "audio/sounds/wind3.wav",
    "audio/sounds/wind4.wav"
}

function audio:setPlayerPos(playerPos_)
    playerPos = playerPos_
    if length2(lastUpdatedLoopingSoundsPlayerPos - playerPos) > updateLoopingSoundsDistance2 then
        updateLoopingSoundDistances()
    end

    local function stopAmbientSoundsIfPlaying(soundInfo)
        --mj:log("stopAmbientSoundsIfPlaying:", soundInfo)
        if soundInfo.rainChannel then
            soundInfo.rainSound:stop(soundInfo.rainChannel)
            soundInfo.rainChannel = nil
            soundInfo.heightAbovePlayer = nil
            soundInfo.obstructedFraction = nil
        end
        if soundInfo.windChannel then
            soundInfo.windSound:stop(soundInfo.windChannel)
            soundInfo.windChannel = nil
            soundInfo.heightAbovePlayer = nil
            soundInfo.obstructedFraction = nil
        end
    end

    if rainAmount > 0.001 or windAmount > 0.001 then
        local playerPosHeight = length(playerPos)
        local normalizedPlayerPos = playerPos / playerPosHeight
        local rotation = mj:getNorthFacingFlatRotationForPoint(normalizedPlayerPos)

        local right = mat3GetRow(rotation, 0)
        local forward = mat3GetRow(rotation, 2)

        local emitterBasePositions = {
            playerPos + right * mj:mToP(2.0),
            playerPos - right * mj:mToP(2.0),
            playerPos + forward * mj:mToP(2.0),
            playerPos - forward * mj:mToP(2.0),
        }

        local averageObstruction = 0.0
        for i=1,4 do
            local emitterInfo = ambientSoundInfos[i].emitterInfo
            if emitterInfo and emitterInfo.heightAbovePlayer then
                if emitterInfo.obstructed then
                    averageObstruction = averageObstruction + 0.25
                end
            end
        end


        for i=1,4 do
            local emitterInfo = ambientSoundInfos[i].emitterInfo
            if emitterInfo and emitterInfo.heightAbovePlayer then
                local prevHeight = ambientSoundInfos[i].heightAbovePlayer
                local heightAbovePlayer = emitterInfo.heightAbovePlayer
                if prevHeight then
                    heightAbovePlayer = prevHeight * 0.9 + emitterInfo.heightAbovePlayer * 0.1
                end
                ambientSoundInfos[i].heightAbovePlayer = heightAbovePlayer

                local position = normalize(emitterBasePositions[i]) * (playerPosHeight + heightAbovePlayer)

                local dominantSoundIsWind = false
                if windAmount > 0.001 then
                    if windAmount > (0.2 + i * 0.15) then
                        dominantSoundIsWind = true
                    elseif windAmount > (rainAmount + i * 0.1 - 0.2) then
                        dominantSoundIsWind = true
                    end
                end

                local volume = 0.0
                if dominantSoundIsWind then
                    volume = windAmount * windMasterVolume
                else
                    volume = rainAmount * rainMasterVolume
                end

                volume = volume * (1.0 + ambientSoundInfos[i].noiseValue * 0.5)
                volume = math.max(volume, 0.0)

                if dominantSoundIsWind then
                    if ambientSoundInfos[i].rainChannel then
                        ambientSoundInfos[i].rainSound:stop(ambientSoundInfos[i].rainChannel)
                        ambientSoundInfos[i].rainChannel = nil
                    end
                    --mj:log("update wind dominant:", i, " volume:", volume)

                    if ambientSoundInfos[i].windChannel then
                        local soundInfo = ambientSoundInfos[i]
                        soundInfo.windSound:setPos(position)
                        soundInfo.windSound:setVolume(volume, soundInfo.windChannel)
                    else
                        local windSound = ambientSoundInfos[i].windSound
                        if not windSound then
                            windSound = bridge:loadSound3D(windSoundPaths[i], false)
                            windSound:setLooping(true)
                            windSound.completionCallback = function(channel) --fmod is weird, it sometimes allows looping sounds to complete. Not sure why exactly, but we can handle it here in the callback
                                ambientSoundInfos[i].windChannel = nil
                                ambientSoundInfos[i].heightAbovePlayer = nil
                                ambientSoundInfos[i].obstructedFraction = nil
                            end
                            ambientSoundInfos[i].windSound = windSound
                        end
                        local channel = windSound:play(position, volume, 1.0)
                        ambientSoundInfos[i].windChannel = channel
                        windSound:setPriority(64, channel)
                        --mj:log("play channel:", channel)
                        if soundsPaused then
                            windSound:setPaused(true, channel)
                        end
                        
                        local pitchMultiplier = getRainWindPitchMultiplier()
                        windSound:setPitch(pitchMultiplier, channel)
                    end

                else
                    --mj:log("update rain dominant:", i, " volume:", volume)
                    
                    if ambientSoundInfos[i].windChannel then
                        ambientSoundInfos[i].windSound:stop(ambientSoundInfos[i].windChannel)
                        ambientSoundInfos[i].windChannel = nil
                    end

                    if ambientSoundInfos[i].rainChannel then
                        local soundInfo = ambientSoundInfos[i]
                        soundInfo.rainSound:setPos(position)
                        soundInfo.rainSound:setVolume(volume, soundInfo.rainChannel)
                    else
                        local rainSound = ambientSoundInfos[i].rainSound
                        if not rainSound then
                            rainSound = bridge:loadSound3D(rainSoundPathsHeavy[i], false)
                            rainSound:setLooping(true)
                            rainSound.completionCallback = function(channel) --fmod is weird, it sometimes allows looping sounds to complete. Not sure why exactly, but we can handle it here in the callback
                                ambientSoundInfos[i].rainChannel = nil
                                ambientSoundInfos[i].heightAbovePlayer = nil
                                ambientSoundInfos[i].obstructedFraction = nil
                            end
                            ambientSoundInfos[i].rainSound = rainSound
                        end
                        local channel = rainSound:play(position, volume, 1.0)
                        ambientSoundInfos[i].rainChannel = channel
                        rainSound:setPriority(64, channel)
                        --mj:log("play rain sound:", channel)
                        if soundsPaused then
                            --mj:log("pause rain sound as soundsPaused")
                            rainSound:setPaused(true, channel)
                        end
                        
                        local pitchMultiplier = getRainWindPitchMultiplier()
                        rainSound:setPitch(pitchMultiplier, channel)
                    end
                end


                local prevObstruction = ambientSoundInfos[i].obstructedFraction
                local newObstruction = 0.0
                if emitterInfo.obstructed then
                    newObstruction = 1.0
                end

                newObstruction = newObstruction * 0.5 + averageObstruction * 0.5

                if prevObstruction then
                    newObstruction = prevObstruction * 0.99 + newObstruction * 0.01
                end
                ambientSoundInfos[i].obstructedFraction = newObstruction

                if newObstruction > 0.1 then
                    if ambientSoundInfos[i].rainChannel then
                        ambientSoundInfos[i].rainSound:setLowPassFilter(true, (newObstruction - 0.1) / 0.9, ambientSoundInfos[i].rainChannel)
                    end
                    if ambientSoundInfos[i].windChannel then
                        ambientSoundInfos[i].windSound:setLowPassFilter(true, (newObstruction - 0.1) / 0.9, ambientSoundInfos[i].windChannel)
                    end
                else
                    if ambientSoundInfos[i].rainChannel then
                        ambientSoundInfos[i].rainSound:setLowPassFilter(false, 0.0, ambientSoundInfos[i].rainChannel)
                    end
                    if ambientSoundInfos[i].windChannel then
                        ambientSoundInfos[i].windSound:setLowPassFilter(false, 0.0, ambientSoundInfos[i].windChannel)
                    end
                end

                --mj:log("update:", i, " newObstruction:", newObstruction, " volume:", volume, " heightAbovePlayer:", mj:pToM(heightAbovePlayer))
                
            else
                stopAmbientSoundsIfPlaying(ambientSoundInfos[i])
            end
        end
    else
        for i=1,4 do
            stopAmbientSoundsIfPlaying(ambientSoundInfos[i])
        end
    end
end


function audio:updateAmbientInfo(ambientInfo)
    if ambientInfo then
        for i=1,4 do
            ambientSoundInfos[i].emitterInfo = ambientInfo.emitterInfos[i]
        end

        rainAmount = math.min(ambientInfo.rainAmount, 1.0)
        windAmount = math.min(ambientInfo.windAmount, 1.0)
    else
        rainAmount = 0.0
        windAmount = 0.0
    end

    --mj:log("rainAmount:", rainAmount, " windAmount:", windAmount)
end

local timeCounter = 0.0

function audio:update(dt)
    if rainAmount > 0.0 or windAmount > 0.0 then
        timeCounter = timeCounter + dt * 0.2
        for i=1,4 do
            local noiseLocation = vec3(0.5,0.3 + 0.3 * i,timeCounter)
            ambientSoundInfos[i].noiseValue = rainNoise:get(noiseLocation, 1)
        end
    end
end


function audio:addLoopingSoundForObject(uniqueID, name, pos)
    if singlePlaySounds[name] then
        singlePlaySounds[name].positions[uniqueID] = pos
    else
        if loopingSoundInfosByID[uniqueID] and loopingSoundInfosByID[uniqueID].channel then
            loopingSoundInfosByID[uniqueID].sound:stop(loopingSoundInfosByID[uniqueID].channel)
            loopingSoundInfosByID[uniqueID].channel = nil
        end

        loopingSoundInfosByID[uniqueID] = {
            uniqueID = uniqueID,
            name = name,
            pos = pos,
        }
    end
    updateLoopingSoundDistances()

end

function audio:removeLoopingSoundForObject(uniqueID)
    if loopingSoundInfosByID[uniqueID] and loopingSoundInfosByID[uniqueID].channel then
        loopingSoundInfosByID[uniqueID].sound:stop(loopingSoundInfosByID[uniqueID].channel)
    end
    loopingSoundInfosByID[uniqueID] = nil

    for soundName,v in pairs(singlePlaySounds) do
        v.positions[uniqueID] = nil
    end
    updateLoopingSoundDistances()
end

function audio:updateLoopingSoundPos(uniqueID, pos)
    if loopingSoundInfosByID[uniqueID] then
        loopingSoundInfosByID[uniqueID].pos = pos
        if loopingSoundInfosByID[uniqueID].sound then
            loopingSoundInfosByID[uniqueID].sound:setPos(pos)
        end
    end

    for soundName,v in pairs(singlePlaySounds) do
        if v.positions[uniqueID] then
            v.positions[uniqueID] = pos
        end
    end

    updateLoopingSoundDistances()
end

function audio:setSpeedMultiplier(speedMultiplier_)
    --mj:log("audio:setSpeedMultiplier:", speedMultiplier_)
    if speedMultiplier ~= speedMultiplier_ then
        speedMultiplier = speedMultiplier_
        if speedMultiplier < 0.001 then
            if not soundsPaused then
                soundsPaused = true
                for uniqueID,soundInfo in pairs(loopingSoundInfosByID) do
                    if soundInfo.channel then
                        soundInfo.sound:setPaused(true, soundInfo.channel)
                    end
                end
                
                for soundName,v in pairs(singlePlaySounds) do
                    if v.channel then
                        v.sound:setPaused(true, v.channel)
                    end
                end

                for name,playInstances in pairs(playingWorldSounds) do
                    for channelID,soundInfo in pairs(playInstances) do
                        soundInfo.sound:setPaused(true, channelID)
                    end
                end

                for i,soundInfo in pairs(ambientSoundInfos) do
                    if soundInfo.rainChannel then
                        soundInfo.rainSound:setPaused(true, soundInfo.rainChannel)
                        --mj:log("pause rain sound in audio:setSpeedMultiplier")
                    end
                    if soundInfo.windChannel then
                        soundInfo.windSound:setPaused(true, soundInfo.windChannel)
                    end
                end
            end
        else
            if soundsPaused then
                soundsPaused = false
                for uniqueID,soundInfo in pairs(loopingSoundInfosByID) do
                    if soundInfo.channel then
                        soundInfo.sound:setPaused(false, soundInfo.channel)
                    end
                end
                
                for soundName,v in pairs(singlePlaySounds) do
                    if v.channel then
                        v.sound:setPaused(false, v.channel)
                    end
                end

                for name,playInstances in pairs(playingWorldSounds) do
                    for channelID,soundInfo in pairs(playInstances) do
                        soundInfo.sound:setPaused(false, channelID)
                    end
                end
                for i,soundInfo in pairs(ambientSoundInfos) do
                    if soundInfo.rainChannel then
                        soundInfo.rainSound:setPaused(false, soundInfo.rainChannel)
                        --mj:log("unpause rain sound in audio:setSpeedMultiplier")
                    end
                    if soundInfo.windChannel then
                        soundInfo.windSound:setPaused(false, soundInfo.windChannel)
                    end
                end
            end

            local pitchMultiplier = getPitchMultiplier()

            for name,playInstances in pairs(playingWorldSounds) do
                for channelID,soundInfo in pairs(playInstances) do
                    soundInfo.sound:setPitch(soundInfo.pitch * pitchMultiplier, channelID)
                end
            end
            
            local rainWindPitchMultiplier = getRainWindPitchMultiplier()
            for i,soundInfo in pairs(ambientSoundInfos) do
                if soundInfo.rainChannel then
                    soundInfo.rainSound:setPitch(rainWindPitchMultiplier, soundInfo.rainChannel)
                end
                if soundInfo.windChannel then
                    soundInfo.windSound:setPitch(rainWindPitchMultiplier, soundInfo.windChannel)
                end
            end

        end
    end
end

function audio:clientGameSettingsLoaded()
    audio:setMusicVolume(clientGameSettings.values.musicVolume)
    audio:setSoundVolume(clientGameSettings.values.soundVolume)

    clientGameSettings:addObserver("musicVolume", function(newValue)
        audio:setMusicVolume(newValue)
    end)

    clientGameSettings:addObserver("soundVolume", function(newValue)
        audio:setSoundVolume(newValue)
    end)
end

function audio:setLogicInterface(logicInterface_)
    logicInterface = logicInterface_
end

return audio