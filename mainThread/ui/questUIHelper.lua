
local locale = mjrequire "common/locale"
local resource = mjrequire "common/resource"

local world = nil

local questUIHelper = {}


function questUIHelper:getQuestShortSummaryText(questState, deliveredCountOrNil)
    if deliveredCountOrNil and deliveredCountOrNil > 0 then
        --return string.format("%s: %s", locale:get("ui_name_quest"), 
        return locale:get("ui_questSummaryWithDeliveredCount", {
            count = questState.requiredCount,
            deliveredCount = deliveredCountOrNil,
            resourceName = resource.types[questState.resourceTypeIndex].name,
            resourcePlural = resource.types[questState.resourceTypeIndex].plural,
        })
    else
        return locale:get("ui_questSummary", {
            count = questState.requiredCount,
            resourceName = resource.types[questState.resourceTypeIndex].name,
            resourcePlural = resource.types[questState.resourceTypeIndex].plural,
        })
    end
end

function questUIHelper:getDescriptiveQuestLabelTextForQuestState(questState)

    if questState.completed then
        return locale:get("ui_name_completedQuest")
    end

    if questState.failed then
        return locale:get("ui_name_failedQuest")
    end

    if questState.assignedTime then
        return locale:get("ui_name_activeQuest")
    end

    return locale:get("ui_name_availableQuest")
end


function questUIHelper:getTimeLeftTextForQuestState(questState)

    local function getTimeString(remainingTime)
        if remainingTime > 60.99 then
            return locale:getTimeDurationDescription(remainingTime, world:getDayLength(), world:getYearLength())
        end
        return string.format("%d:%d%d", math.floor(remainingTime / 60), math.floor((remainingTime % 60) / 10), math.floor(remainingTime) % 10)
    end

    local expirationTime = questState.expirationTime
    if expirationTime then
        local remainingTime = math.max(expirationTime - world:getWorldTime(), 0)
        local timeDescription = getTimeString(remainingTime)
        if questState.failed or questState.complete then
            return locale:get("misc_timeUntilNextQuest") .. ": " .. timeDescription
        elseif questState.assignedTime then
            return locale:get("misc_timeRemaining") .. ": " .. timeDescription
        else
            return locale:get("misc_expires") .. ": " .. timeDescription
        end
    end
    return nil
end


function questUIHelper:init(world_)
    world = world_
end

return questUIHelper