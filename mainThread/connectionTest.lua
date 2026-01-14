local mjm = mjrequire "common/mjm"
local timer = mjrequire "common/timer"
local gameConstants = mjrequire "common/gameConstants"

local debugUI = mjrequire "mainThread/ui/debugUI"
local timeControls = mjrequire "mainThread/ui/timeControls"

local connectionTest = {}

local world = nil
local logicInterface = nil

local currentPingValue = 0.0
local smoothedPingValue = 0.0

local function sendPing()
    local pingTimerID = timer:addDeltaTimer()
    logicInterface:callServerFunction("debugPing", nil, function()
        local elapsed = timer:getDt(pingTimerID)
        currentPingValue = elapsed
    end)
end

local secondsPerUpdate = 0.2
local createPingTimer = nil
local skipPingCount = 0
createPingTimer = function()
    timer:addCallbackTimer(secondsPerUpdate, 
    function()
        skipPingCount = skipPingCount + 1
        if skipPingCount >= 5 then
            skipPingCount = 0
            sendPing()
        end
        smoothedPingValue = mjm.mix(smoothedPingValue, currentPingValue, 0.1)
        currentPingValue = currentPingValue + secondsPerUpdate
        if currentPingValue >= gameConstants.disconnectDelayThreshold then
            world:disconnectFromServer()
        end
        debugUI:setPingValue(currentPingValue)
        timeControls:setPingValue(currentPingValue)
        createPingTimer()
    end)
end

function connectionTest:init(world_, logicInterface_)
    world = world_
    logicInterface = logicInterface_
    if world:getIsOnlineClient() then
        createPingTimer()
    end
end

return connectionTest