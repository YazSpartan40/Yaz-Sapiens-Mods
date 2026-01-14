local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local gameConstants = mjrequire "common/gameConstants"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local weather = mjrequire "common/weather"


--local lightManager = mjrequire "mainThread/lightManager"

local debugUI = {}

local mainView = nil

local biomeTextViewInfo = nil
local uniqueIDTextViewInfo = nil
local physicsLookAtTextViewInfo = nil
local ordersTextViewInfo = nil
local pingTextView = nil
local serverStatsTextViewInfo = nil

local function setText(textViewInfo, newText)
    textViewInfo.textView.text = newText or ""
    if (not newText) or newText == "" then
        textViewInfo.backgroundView.size = vec2(0,0)
    else
        textViewInfo.backgroundView.size = vec2(textViewInfo.textView.size.x + 8, textViewInfo.textView.size.y + 4)
    end
end

function debugUI:setPingValue(currentPingValue)
    setText(pingTextView, string.format("delay:%.1f", currentPingValue))
end

function debugUI:load(gameUI, controller, logicInterface_)
    mainView = View.new(gameUI.view)
    mainView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    --[[local ssaoDebugView = RenderTargetView.new(mainView)
    ssaoDebugView.size = gameUI.view.size * 0.25
    ssaoDebugView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    ssaoDebugView.renderTarget = lightManager:getSSAORenderTarget()]]

    
    local consoleFont = Font(uiCommon.consoleFontName, 12)

    --[[local fpsView = TextView.new(mainView)
    fpsView.font = consoleFont
    fpsView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    fpsView.baseOffset = vec3(-4,-4, 0)]]

    local function addTextView(relativeViewInfo)
        local backgroundView = ColorView.new(mainView)
        backgroundView.color = vec4(0.0,0.0,0.0,0.5)
        backgroundView.size = vec2(0,0)
        if relativeViewInfo then
            backgroundView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
            backgroundView.relativeView = relativeViewInfo.backgroundView
        else
            backgroundView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
            backgroundView.baseOffset = vec3(-4,-4, 0)
        end

        local textView = TextView.new(backgroundView)
        textView.font = consoleFont
        textView.textAlignment = MJHorizontalAlignmentRight
        --textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
        --textView.text = " "
        return {
            backgroundView = backgroundView,
            textView = textView
        }
    end

    local fpsViewInfo = addTextView(nil)
    local vramUsageViewInfo = addTextView(fpsViewInfo)
    biomeTextViewInfo = addTextView(vramUsageViewInfo)
    local weatherViewInfo = addTextView(biomeTextViewInfo)
    ordersTextViewInfo = addTextView(weatherViewInfo)
    uniqueIDTextViewInfo = addTextView(ordersTextViewInfo)
    physicsLookAtTextViewInfo = addTextView(uniqueIDTextViewInfo)
    pingTextView = addTextView(physicsLookAtTextViewInfo)
    serverStatsTextViewInfo = addTextView(pingTextView)
    
    mainView.update = function(dt)
        local string = "FPS:" .. controller:getFPS()
        setText(fpsViewInfo, string)

        --mj:log("a")
        
        local usageInfo = controller:getVRAMUsageInfo()
       -- mj:log("b:", usageInfo)
        local vramText = string.format("VRAM allocated:%.1fMB block:%.1fMB, usage:%.1fMB, budget:%.1fMB", usageInfo.allocationBytes / (1024 * 1024), usageInfo.blockBytes / (1024 * 1024), usageInfo.usage / (1024 * 1024), usageInfo.budget / (1024 * 1024))
        
       -- mj:log(vramText)
        setText(vramUsageViewInfo, vramText)

        local weatherString = string.format("Global Rain Chance:%.1f Wind Strength:%.1f", weather:getCurrentGlobalChanceOfRain(), weather:getWindStrength())
        local windStormStrength = weather:getServerWindstormStrength()
        if windStormStrength and windStormStrength > 0.001 then
            weatherString = weatherString .. string.format(" (Wind Storm Active:%.1f)", windStormStrength)
        end

        setText(weatherViewInfo, weatherString)

    end

    local function updateHiddenStatus()
        if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu then
            mainView.hidden = false
        else
            mainView.hidden = true
        end
    end

    clientGameSettings:addObserver("renderDebug", updateHiddenStatus)

    updateHiddenStatus()

end

function debugUI:setBiome(biomeString)
    if mainView then
        setText(biomeTextViewInfo, "biome:" .. biomeString)
    end
end

function debugUI:setUniqueID(value)
    if mainView then
        if value then
            setText(uniqueIDTextViewInfo,value)
        else
            setText(uniqueIDTextViewInfo,nil)
        end
    end
end

function debugUI:setPhysicsLookAtText(value)
    if mainView then
        if value then
            setText(physicsLookAtTextViewInfo,value)
        else
            setText(physicsLookAtTextViewInfo,nil)
        end
    end
end

function debugUI:updateOrdersText(currentOrderCount, maxOrderCount)
    if mainView then
        setText(ordersTextViewInfo,string.format("Queued order count:%d/%d", currentOrderCount,maxOrderCount))
    end
end

function debugUI:updateServerDebugStats(statsString)
    if mainView then
        setText(serverStatsTextViewInfo,statsString)
    end
end

function debugUI:show()
    if mainView then
        if clientGameSettings.values.renderDebug and gameConstants.showDebugMenu then
            mainView.hidden = false
        end
    end
end
function debugUI:hide()
    if mainView then
        mainView.hidden = true
    end
end

return debugUI