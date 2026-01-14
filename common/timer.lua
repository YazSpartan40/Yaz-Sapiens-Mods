local timer = {}

local bridge = nil

function timer:addCallbackTimer(delay, callback) --non recurring, is automatically removed when callback is called. Callback gets passed the timerID. returns timerID
    return bridge:addCallbackTimer(delay, callback)
end

function timer:removeTimer(timerID)
    bridge:removeTimer(timerID)
end

function timer:addUpdateTimer(callback) --recurring, called every time step. Callback is given the delta time, and timerID. returns timerID
    return bridge:addUpdateTimer(callback)
end

function timer:addDeltaTimer() --doesn't call back, you query this with getDt and getElapsed, to get precise time durations
    return bridge:addDeltaTimer()
end

function timer:getDt(timerID) -- Returns the time since this getDt last called on this timer (or since added on the first call). Must have been added with timer:addDeltaTimer
    return bridge:getDt(timerID)
end

function timer:getElapsed(timerID) -- Returns the time since this timer was created. Must have been added with timer:addDeltaTimer
    return bridge:getElapsed(timerID)
end

function timer:setBridge(bridge_)
    bridge = bridge_
end

return timer