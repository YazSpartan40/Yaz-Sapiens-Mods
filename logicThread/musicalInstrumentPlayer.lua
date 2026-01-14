
local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local maxPlayDistance2 = mj:mToP(99.0) * mj:mToP(99.0)

local action = mjrequire "common/action"
local rng = mjrequire "common/randomNumberGenerator"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
--local sapienInventory = mjrequire "common/sapienInventory"

local logicAudio = mjrequire "logicThread/logicAudio"

local clientGOM = nil
local logic = nil

local soundFiles_A_Flute_High = {
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_1.ogg",
        duration = 5.2,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_2.ogg",
        duration = 4.8,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_3.ogg",
        duration = 8.5,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_4.ogg",
        duration = 8.9,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_5.ogg",
        duration = 8.2,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_6.ogg",
        duration = 7.1,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_7.ogg",
        duration = 8.0,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_8.ogg",
        duration = 7.8,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_9.ogg",
        duration = 9.2,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_High_10.ogg",
        duration = 9.8,
    },
}

local soundFiles_A_Flute_Low = {
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_1.ogg",
        duration = 5.6,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_2.ogg",
        duration = 5.1,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_3.ogg",
        duration = 6.9,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_4.ogg",
        duration = 6.1,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_5.ogg",
        duration = 7.0,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_6.ogg",
        duration = 6.5,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_7.ogg",
        duration = 6.5,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_8.ogg",
        duration = 7.2,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_9.ogg",
        duration = 7.6,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_10.ogg",
        duration = 8.7,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_11.ogg",
        duration = 6.8,
    },
    {
        file = "audio/sounds/instruments/flute/SP_A_Flute_Low_12.ogg",
        duration = 5.8,
    },
}

local soundFiles_B_Flute_High = {
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_1.ogg",
        duration = 8.6,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_2.ogg",
        duration = 8.6,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_3.ogg",
        duration = 4.4,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_4.ogg",
        duration = 5.2,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_5.ogg",
        duration = 6.3,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_6.ogg",
        duration = 10.3,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_7.ogg",
        duration = 11.2,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_High_8.ogg",
        duration = 13.5,
    },
}


local soundFiles_B_Flute_Low = {
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_1.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_2.ogg",
        duration = 5.8,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_3.ogg",
        duration = 3.9,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_4.ogg",
        duration = 6.8,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_5.ogg",
        duration = 5.5,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_6.ogg",
        duration = 4.8,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_7.ogg",
        duration = 4.3,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_8.ogg",
        duration = 5.5,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_9.ogg",
        duration = 5.7,
    },
    {
        file = "audio/sounds/instruments/flute/SP_B_Flute_Low_10.ogg",
        duration = 6.2,
    },
}



local soundFiles_A_LogDrum = {
    {
        file = "audio/sounds/instruments/logDrum/SP_A_LogDrum_1.ogg",
        duration = 28.8,
    },
    {
        file = "audio/sounds/instruments/logDrum/SP_A_LogDrum_2.ogg",
        duration = 14.6,
    },
    {
        file = "audio/sounds/instruments/logDrum/SP_A_LogDrum_3.ogg",
        duration = 17.1,
    },
   --[[ {
        file = "audio/sounds/instruments/logDrum/SP_A_LogDrum_4.ogg",
        duration = 1.4,
    },]]
}

local soundFiles_B_LogDrum = {
    {
        file = "audio/sounds/instruments/logDrum/SP_B_LogDrum_1.ogg",
        duration = 6.0,
    },
    {
        file = "audio/sounds/instruments/logDrum/SP_B_LogDrum_2.ogg",
        duration = 9.2,
    },
    {
        file = "audio/sounds/instruments/logDrum/SP_B_LogDrum_3.ogg",
        duration = 7.3,
    },
    {
        file = "audio/sounds/instruments/logDrum/SP_B_LogDrum_4.ogg",
        duration = 9.8,
    },
    --[[{
        file = "audio/sounds/instruments/logDrum/SP_B_LogDrum_5.ogg",
        duration = 1.1,
    },]]
}



local soundFiles_A_Balafon = {
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_1.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_2.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_3.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_4.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_5.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_6.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_7.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_8.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_9.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_10.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_A_Balafon_11.ogg",
        duration = 4.5,
    },
}

local soundFiles_B_Balafon = {
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_1.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_2.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_3.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_4.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_5.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_6.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_7.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_8.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_9.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_10.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_11.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_12.ogg",
        duration = 4.5,
    },
    {
        file = "audio/sounds/instruments/balafon/SP_B_Balafon_13.ogg",
        duration = 4.5,
    },
}

local musicalInstrumentPlayer = {}

local playingSapiens = {}

local function sortedSapiensByDistance(actionTypeIndex)
    local sapiens = {}

    for sapienID,info in pairs(playingSapiens) do
        if info.sapienDistance2 and info.actionTypeIndex == actionTypeIndex then
            table.insert(sapiens, info)
        end
    end
    
    local function sortByDistance(a,b)
        return a.sapienDistance2 < b.sapienDistance2
    end

    table.sort(sapiens, sortByDistance)
    return sapiens

end

local function stopOtherPlayingSapiensIfNeededDueToPlayStart(sapienID)
    local newPlayingInfo = playingSapiens[sapienID]
    if newPlayingInfo and newPlayingInfo.playedChannel then
        
        if newPlayingInfo.actionTypeIndex == action.types.playDrum.index or newPlayingInfo.actionTypeIndex == action.types.playBalafon.index then
            for otherSapienID,otherInfo in pairs(playingSapiens) do
                if otherSapienID ~= sapienID and otherInfo.actionTypeIndex == newPlayingInfo.actionTypeIndex then
                    
                    if otherInfo.playedChannel then
                        --mj:log("calling stop:", playingInfo.playedTrackName, " channel:", playingInfo.playedChannel, " sapien.uniqueID:", sapien.uniqueID)
                        --mj:log("calling stop due to override:", otherSapienID)
                        logicAudio:stopWorldSound(otherInfo.playedTrackName, otherInfo.playedChannel)
                        --otherInfo.playedChannel = nil
                        --otherInfo.playing = false
                    end
                end
            end
        end
    end
end

local function getVolume(playingSapienInfo)
    local actionTypeIndex = playingSapienInfo.actionTypeIndex
    --mj:log("playingSapienInfo:", playingSapienInfo)
    if actionTypeIndex == action.types.playDrum.index or actionTypeIndex == action.types.playBalafon.index then
        return 0.5
    end
    return 0.1
end

local function getSoundFiles(playingSapienInfo, skillLevel)
    local actionTypeIndex = playingSapienInfo.actionTypeIndex
    local sorted = sortedSapiensByDistance(actionTypeIndex)
    if actionTypeIndex == action.types.playDrum.index then
        if sorted[1] and sorted[1].uniqueID ~= playingSapienInfo.uniqueID then
            return nil
        end

        if skillLevel == 1 then
            return soundFiles_B_LogDrum
        else
            return soundFiles_A_LogDrum
        end
    elseif actionTypeIndex == action.types.playBalafon.index then
        if sorted[1] and sorted[1].uniqueID ~= playingSapienInfo.uniqueID then
            return nil
        end

        if skillLevel == 1 then
            return soundFiles_B_Balafon
        else
            return soundFiles_A_Balafon
        end
    else
        local isHigh = true
        if sorted[1] and sorted[1].uniqueID ~= playingSapienInfo.uniqueID then
            if sorted[2] and sorted[2].uniqueID == playingSapienInfo.uniqueID then
                isHigh = false
            else
                return nil
            end
        end

        if skillLevel == 1 then
            if isHigh then
                return soundFiles_B_Flute_High
            else
                return soundFiles_B_Flute_Low
            end
        else
            if isHigh then
                return soundFiles_A_Flute_High
            else
                return soundFiles_A_Flute_Low
            end
        end
    end
end

local function getNextTrackInfo(sapien, clientState, playingSapienInfo)
    local skillTypeIndex = skill.types.flutePlaying.index

    local fractionComplete = 0.0
    local orderState = sapien.sharedState.orderQueue[1]
    local researchTypeIndex = nil
    if orderState and orderState.context then
        researchTypeIndex = orderState.context.researchTypeIndex
    end
    if researchTypeIndex and research.types[researchTypeIndex].skillTypeIndex == skillTypeIndex then
        local discoveryInfo = logic:discoveryInfoForResearchTypeIndex(researchTypeIndex)
        if discoveryInfo and discoveryInfo.fractionComplete then
            fractionComplete = discoveryInfo.fractionComplete
        end
    else
        fractionComplete = skill:fractionLearned(sapien, skillTypeIndex)
    end

    local skillLevel = 1
    if fractionComplete >= 0.99 then
        skillLevel = 2
    end
    --mj:log("getNextTrackInfo fractionComplete:", fractionComplete, " skillLevel:", skillLevel, " playedTrackID:", playingSapienInfo.playedTrackID)
    local soundFiles = getSoundFiles(playingSapienInfo, skillLevel)
    if not soundFiles then
        return nil
    end
    local newTrackID = rng:randomInteger(#soundFiles) + 1
    --mj:log("newTrackID:", newTrackID)
    if newTrackID == playingSapienInfo.playedTrackID then
        --mj:log("same")
        newTrackID = rng:randomInteger(#soundFiles) + 1
       -- mj:log("newTrackID B:", newTrackID)
        if newTrackID == playingSapienInfo.playedTrackID then
           -- mj:log("same again")
            newTrackID = playingSapienInfo.playedTrackID + 1
            --mj:log("newTrackID C:", newTrackID)
            if newTrackID > #soundFiles then
               -- mj:log("reset to 1")
                newTrackID = 1
            end
        end
    end
    return {
        skillLevel = skillLevel,
        trackID = newTrackID,
        file = soundFiles[newTrackID].file,
    }
end

function musicalInstrumentPlayer:updateStateForServerUpdate(sapien, clientState, actionTypeIndex)
    local playingInstrument = false
    if actionTypeIndex then
        if actionTypeIndex == action.types.playFlute.index or actionTypeIndex == action.types.playDrum.index or actionTypeIndex == action.types.playBalafon.index then
            --mj:log("playingInstrument")
            --local incomingHeldObjects = sapienInventory:getObjects(sapien, sapienInventory.locations.held.index)
            playingInstrument = true
        end
    end

    if playingInstrument ~= clientState.playingInstrument then
        clientState.playingInstrument = playingInstrument
        --mj:log("playing instrument state changed:", sapien.uniqueID, " playingInstrument:", playingInstrument)
        if playingInstrument then
            playingSapiens[sapien.uniqueID] = {
                uniqueID = sapien.uniqueID,
                actionTypeIndex = actionTypeIndex
            }
        else
            local playingInfo = playingSapiens[sapien.uniqueID]
            if playingInfo then
                if playingInfo.playedChannel then
                    --mj:log("calling stop:", playingInfo.playedTrackName, " channel:", playingInfo.playedChannel, " sapien.uniqueID:", sapien.uniqueID)
                    logicAudio:stopWorldSound(playingInfo.playedTrackName, playingInfo.playedChannel)
                end
                playingSapiens[sapien.uniqueID] = nil
            end
        end
    end
end

function musicalInstrumentPlayer:update(dt, worldTime, speedMultiplier)
    for sapienID,info in pairs(playingSapiens) do
        --local timeSinceLastPlay = worldTime - (info.lastPlayTime or -10.0)
       -- local timer
        if not info.playing then
            --mj:log("not playing")
            --mj:log("info:", info, " soundFiles:", soundFiles[info.nextTrackID])
            local sapien = clientGOM:getObjectWithID(sapienID)
            if not sapien then
               -- mj:log("no sapien")
                playingSapiens[sapienID] = nil
            else
                local sapienDistance2 = length2(sapien.pos - logic.playerPos)
                info.sapienDistance2 = sapienDistance2
                if sapienDistance2 < maxPlayDistance2 then
                    local clientState = clientGOM:getClientState(sapien)
                    local nextTrackInfo = getNextTrackInfo(sapien, clientState, info)
                    if nextTrackInfo then
                        local fileToPlay = nextTrackInfo.file
                        info.playedTrackName = fileToPlay
                        info.playedTrackID = nextTrackInfo.trackID
                        info.playedChannel = false
                        info.playing = true

                        local function playStartedCallback(playedChannel)
                        -- mj:log("playWorldSound callback:", playedChannel, " playingSapiens[sapienID]:", playingSapiens[sapienID], " sapienID:", sapienID)
                            if not playingSapiens[sapienID] then
                            -- mj:log("not playingSapiens[sapienID]")
                                logicAudio:stopWorldSound(fileToPlay, playedChannel)
                            else
                                --mj:log("setting playedChannel")
                                playingSapiens[sapienID].playedChannel = playedChannel
                                stopOtherPlayingSapiensIfNeededDueToPlayStart(sapienID)
                            end
                        end
                        
                        local function completionCallback()
                            --mj:log("playWorldSound completionCallback:", fileToPlay, " sapienID:", sapienID)
                            info.playing = false
                        end
                        --mj:log("musicalInstrumentPlayer:update playWorldSound:", fileToPlay, " sapienID:", sapienID)

                        logicAudio:playWorldSound(fileToPlay, sapien.pos, getVolume(playingSapiens[sapienID]), nil, 120, nil, playStartedCallback, completionCallback)
                        logicAudio:fadeOutGameMusic()
                    end
                end
            end
        end
    end
end

function musicalInstrumentPlayer:init(logic_, clientGOM_)
    clientGOM = clientGOM_
    logic = logic_
end


return musicalInstrumentPlayer