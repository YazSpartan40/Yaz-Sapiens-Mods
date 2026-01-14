
local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local rng = mjrequire "common/randomNumberGenerator"
local timer = mjrequire "common/timer"

local maxDistance2 = mj:mToP(99.0) * mj:mToP(99.0)

local logic = nil

local logicAudio = {}

local delayedLoopAddTimers = {}
local addCount = 0

local worldSoundCompletionCallbackIDCounter = 0
local worldSoundCompletionCallbacksByID = {}


function logicAudio:playWorldSound(name, pos, volumeOrNil, pitchOrNil, priorityOrNil, maxDistance2OverrideOrNil, playedCallbackOrNil, completionCallbackOrNil) -- priority default is 127. 0 most important, 255 least
    if length2(pos - logic.playerPos) < (maxDistance2OverrideOrNil or maxDistance2) then
       --[[ local speedPitchOffsetMultiplier = 1.0
        if logic.speedMultiplier > 1.1 then
            if logic.speedMultiplier > 10.0 then
                speedPitchOffsetMultiplier = 2.0
            else
                speedPitchOffsetMultiplier = 1.5
            end
        end]]

        local completionCallbackID = nil
        if completionCallbackOrNil then
            worldSoundCompletionCallbackIDCounter = worldSoundCompletionCallbackIDCounter + 1
            completionCallbackID = worldSoundCompletionCallbackIDCounter
            worldSoundCompletionCallbacksByID[completionCallbackID] = completionCallbackOrNil
        end
        

        logic:callMainThreadFunction("playWorldSound", {
            name = name,
            pos = pos,
            volume = volumeOrNil,
            pitch = (pitchOrNil or 1.0),
            priority = priorityOrNil,
            maxPlayDistance = maxDistance2OverrideOrNil,
            completionCallbackID = completionCallbackID,
        }, playedCallbackOrNil)
        return true
    else
        if completionCallbackOrNil then
            completionCallbackOrNil()
        end
        return false
    end
end

function logicAudio:worldPlaySoundComplete(completionCallbackID)
    if worldSoundCompletionCallbacksByID[completionCallbackID] then
        worldSoundCompletionCallbacksByID[completionCallbackID]()
        worldSoundCompletionCallbacksByID[completionCallbackID] = nil
    end
end

function logicAudio:stopWorldSound(name, channel)
    logic:callMainThreadFunction("stopWorldSound", {
        name = name,
        channel = channel,
    })
end

function logicAudio:playUISound(name, volumeOrNil, pitchOrNil)
    logic:callMainThreadFunction("playUISound", {
        name = name,
        volume = volumeOrNil,
        pitch = (pitchOrNil or 1.0),
    })
end

function logicAudio:addLoopingSoundForObject(object, name)
    local delay = rng:randomValue() * (1.0 + addCount)
    local uniqueID = object.uniqueID
    local pos = object.pos

    local timerID = timer:addCallbackTimer(delay, function()
        logic:callMainThreadFunction("addLoopingSoundForObject", {
            uniqueID = uniqueID,
            name = name,
            pos = pos,
        })
        delayedLoopAddTimers[uniqueID] = nil
        addCount = addCount - 1
    end)

    delayedLoopAddTimers[object.uniqueID] = timerID
    addCount = addCount + 1
end


function logicAudio:updateLoopingSoundPos(object, pos)
    local uniqueID = object.uniqueID
    logic:callMainThreadFunction("updateLoopingSoundPos", {
        uniqueID = uniqueID,
        pos = pos,
    })
end

function logicAudio:removeLoopingSoundForObject(object)
    if delayedLoopAddTimers[object.uniqueID] then
        timer:removeTimer(delayedLoopAddTimers[object.uniqueID])
        delayedLoopAddTimers[object.uniqueID] = nil
    else
        logic:callMainThreadFunction("removeLoopingSoundForObject", object.uniqueID)
    end
end

function logicAudio:fadeOutGameMusic()
    logic:callMainThreadFunction("fadeOutGameMusic")
end

--[[
function logicAudio:startLoopForThreat(userData, sapienObjectOrNil)
    logicAudio:addLoopingSoundForObject(sapienObject, "audio/sounds/events/conflictLoop.wav")
end]]


function logicAudio:setLogic(logic_)
    logic = logic_
end

return logicAudio