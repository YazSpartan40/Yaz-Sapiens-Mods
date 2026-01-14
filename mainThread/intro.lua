
local timer = mjrequire "common/timer"
local locale = mjrequire "common/locale"
--local mapModes = mjrequire "common/mapModes"

local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"

local intro = {}

local gameUI = nil
local world = nil
local localPlayer = nil
local storyPanel = nil
local isVisible = false

local storyCounter = 1
local initialized = false

local functionsByCounter = {
    function()
        local worldName = world:getWorldName()
        local text = locale:get("intro_a", {
            worldName = worldName,
        })
        storyPanel:show(text, false)
    end,
    function()
        local text = locale:get("intro_b")
        storyPanel:show(text, false)
    end,
    function()
        local text = locale:get("intro_c")
        storyPanel:show(text, false)
    end,
    function()
        localPlayer:startCinematicMapModeCameraZoomTransition()
        local text = locale:get("intro_d")
        storyPanel:show(text, true)
        localPlayer:finishCinematicMapModeTransitions()
        storyPanel:setHideOnClickOutside()
        gameUI:setKeepWorldUIHiddenEvenIfTribeNotSelected(false)
    end,
}

function intro:dismiss()
    isVisible = false
    storyPanel:hide()
    
    --localPlayer:finishCinematicMapModeTransitions()
    --tutorialUI:show(tutorialUI.types.mapNavigation.index)
    tutorialUI:show()
end

local function showNext()
    local func = functionsByCounter[storyCounter]
    if func then
        func()
        storyCounter = storyCounter + 1
    else
        intro:dismiss()
    end
end

function intro:init(gameUI_, world_, localPlayer_, storyPanel_)
    initialized = true
    gameUI = gameUI_
    world = world_
    localPlayer = localPlayer_
    storyPanel = storyPanel_
    isVisible = true

    storyPanel:show(nil, nil)
    storyPanel:setNextFunction(showNext)
    localPlayer:startCinematicMapModeCameraRotateGlobeTransition()
end

function intro:getVisible()
    return isVisible
end


function intro:worldLoaded()
    if initialized then
        gameUI:setKeepWorldUIHiddenEvenIfTribeNotSelected(true)
        if clientGameSettings.values.skipIntro then
            localPlayer:finishCinematicMapModeTransitions()
            storyPanel:setHideOnClickOutside()
            gameUI:setKeepWorldUIHiddenEvenIfTribeNotSelected(false)
            intro:dismiss()
        else
            timer:addCallbackTimer(2.0, function()
                showNext()
            end)
        end
    end
end

return intro