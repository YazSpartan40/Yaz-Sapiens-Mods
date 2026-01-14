
local timer = mjrequire "common/timer"
local locale = mjrequire "common/locale"
--local mapModes = mjrequire "common/mapModes"

--local tutorialUI = mjrequire "mainThread/ui/tutorialUI"

local gameFailSequence = {}

--local world = nil
local gameUI = nil
local localPlayer = nil
local storyPanel = nil

local storyCounter = 1
local initialized = false

local functionsByCounter = {
    function()
        local text = locale:get("gameFailSequence_a")
        storyPanel:show(text, false)
    end,
    function()
        --localPlayer:startCinematicMapModeCameraZoomTransition()
        local text = locale:get("gameFailSequence_b")
        storyPanel:show(text, true)
        localPlayer:finishCinematicMapModeTransitions()
        storyPanel:setHideOnClickOutside()
        gameUI:setKeepWorldUIHiddenEvenIfTribeNotSelected(false)
    end,
}

function gameFailSequence:dismiss()
    storyPanel:hide()
    --localPlayer:finishCinematicMapModeTransitions()
    --tutorialUI:show(tutorialUI.types.mapNavigation.index)
end

local function showNext()
    local func = functionsByCounter[storyCounter]
    if func then
        func()
        storyCounter = storyCounter + 1
    else
        gameFailSequence:dismiss()
    end
end

function gameFailSequence:init(gameUI_, world_, localPlayer_, storyPanel_)
    gameUI = gameUI_

    initialized = true
   --world = world_
    localPlayer = localPlayer_
    storyPanel = storyPanel_

    storyPanel:show(nil, nil)
    storyPanel:setNextFunction(showNext)
    --localPlayer:startCinematicMapModeCameraRotateGlobeTransition()
end

function gameFailSequence:showForTribeFail(gameUI_, world_, localPlayer_, storyPanel_)
    if not initialized then
        gameFailSequence:init(gameUI_, world_, localPlayer_, storyPanel_)
    else
        storyCounter = 1
        storyPanel:show(nil, nil)
        storyPanel:setNextFunction(showNext)
    end
    gameUI:setKeepWorldUIHiddenEvenIfTribeNotSelected(true)
    showNext()
end

function gameFailSequence:worldLoaded()
    if initialized then
        timer:addCallbackTimer(2.0, function()
            showNext()
        end)
    end
end

return gameFailSequence