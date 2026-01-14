

local profile = require("jit.profile")
local timer = mjrequire "common/timer"

local profilerRunning = false

local traces = {}

local profiler = {}

function profiler:start(durationOrNil, callbackFuncOrNil)
    if not profilerRunning then
        mj:log("start profile")
        profilerRunning = true
        profile.start("Fi10", function(thread, samples, vmstate)
            table.insert(traces, profile.dumpstack(thread, "l:f\n", 20))
        end)
        if durationOrNil then
            timer:addCallbackTimer(durationOrNil, function()
                profiler:stop(callbackFuncOrNil)
            end)
        end
    end
end

function profiler:stop(callbackFuncOrNil)
    if profilerRunning then
        local resultString = nil
        profilerRunning = false
        profile.stop()
        local traceCount = #traces
        mj:log("profile complete with trace count:", traceCount)
        if callbackFuncOrNil then
            resultString = string.format("Server profile complete with trace count:%d\n", traceCount)
        end
        if traceCount > 0 then
            local counts = {}
            local ordered = {}
            for i, trace in ipairs(traces) do
                
                for subString in string.gmatch(trace, "(.-)\n") do
                    if not counts[subString] then 
                        counts[subString] = 1
                        table.insert(ordered, subString)
                    else
                        counts[subString] = counts[subString] + 1
                    end
                end
            end

            local function sortCount(a,b)
                return counts[a] > counts[b]
            end
            table.sort(ordered, sortCount)
            
            for i, traceLine in ipairs(ordered) do
                local lineString = string.format("[%.2f%%] %s", (counts[traceLine] / traceCount) * 100, traceLine)
                mj:log(lineString)
                if resultString then
                    resultString = resultString .. lineString .. "\n"
                end
            end
            --mj:log("traces:", traces)
        end

        if callbackFuncOrNil then
            callbackFuncOrNil(resultString)
        end

    end
end

return profiler