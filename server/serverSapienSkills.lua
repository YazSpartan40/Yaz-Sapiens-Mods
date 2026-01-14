local mjm = mjrequire "common/mjm"

local skill = mjrequire "common/skill"
local sapienTrait = mjrequire "common/sapienTrait"
local notification = mjrequire "common/notification"
local research = mjrequire "common/research"
local statusEffect = mjrequire "common/statusEffect"
local constructable = mjrequire "common/constructable"

local serverStatusEffects = mjrequire "server/serverStatusEffects"
--local sapienConstants = mjrequire "common/sapienConstants"
--local server = mjrequire "server/server"

local serverGOM = nil
local serverWorld = nil
local serverSapien = nil

local serverSapienSkills = {}


local callbackObjectIDsBySkillTypeIndex = {}
local callbackInfosByObjectID = {}



         

function serverSapienSkills:setCallbackForSkillAvailabilityChange(objectID, skillTypeIndexes, func)

    --mj:log("serverSapienSkills:setCallbackForSkillAvailabilityChange:", objectID)
    if callbackInfosByObjectID[objectID] then
        local oldTypeIndexes = callbackInfosByObjectID[objectID].skillTypeIndexes
        for i, oldTypeIndex in ipairs(oldTypeIndexes) do
            callbackObjectIDsBySkillTypeIndex[oldTypeIndex][objectID] = nil
        end
    end

    callbackInfosByObjectID[objectID] = {
        func = func,
        skillTypeIndexes = skillTypeIndexes,
    }
    
    for i, skillTypeIndex in ipairs(skillTypeIndexes) do
        if not callbackObjectIDsBySkillTypeIndex[skillTypeIndex] then
            callbackObjectIDsBySkillTypeIndex[skillTypeIndex] = {}
        end
        callbackObjectIDsBySkillTypeIndex[skillTypeIndex][objectID] = true
    end
end

function serverSapienSkills:removeCallbackForSkillAvailabilityChange(objectID)
    if callbackInfosByObjectID[objectID] then
        local oldTypeIndexes = callbackInfosByObjectID[objectID].skillTypeIndexes
        for i, oldTypeIndex in ipairs(oldTypeIndexes) do
            callbackObjectIDsBySkillTypeIndex[oldTypeIndex][objectID] = nil
        end
        callbackInfosByObjectID[objectID] = nil
    end
end


local function callCallbacksForSkillTypeChange(tribeID, skillTypeIndex, becameAvailableOrRemoved)
    local callbackObjectIDs = callbackObjectIDsBySkillTypeIndex[skillTypeIndex]
    if callbackObjectIDs then
        for objectID,trueFalse in pairs(callbackObjectIDs) do
            local callbackInfo = callbackInfosByObjectID[objectID]
           -- mj:log("callCallbacksForSkillTypeChange:", skillTypeIndex)
            callbackInfo.func(tribeID, objectID, skillTypeIndex, becameAvailableOrRemoved)
        end
    end
end

local allowedTaskListsByTribeID = {}
local needsToUpdateAllowedTaskListsTribeIDs = {}

function serverSapienSkills:updateTribeAllowedTaskListsForSapienLoaded(sapien)
    --mj:log("updateTribeAllowedTaskListsForSapienLoaded:", sapien.uniqueID, " tribe:", sapien.sharedState.tribeID)
    needsToUpdateAllowedTaskListsTribeIDs[sapien.sharedState.tribeID] = true
end

function serverSapienSkills:updateTribeAllowedTaskLists(tribeID)
    local allowedTaskLists = {}
    local prevAllowedTaskLists = allowedTaskListsByTribeID[tribeID] or {}
    local changedList = {}

    needsToUpdateAllowedTaskListsTribeIDs[tribeID] = false
        
    serverGOM:callFunctionForAllSapiensInTribe(tribeID, function(sapien)
        --local skillPriorities = sapien.sharedState.skillPriorities
        for i,skillType in ipairs(skill.validTypes) do
            local skillTypeIndex = skillType.index
            if skill:isAllowedToDoTasks(sapien, skillTypeIndex) then
            --if (not skillPriorities) or (not skillPriorities[skillTypeIndex]) or skillPriorities[skillTypeIndex] > 0 then
                allowedTaskLists[skillTypeIndex] = true
                if not prevAllowedTaskLists[skillTypeIndex] then
                    changedList[skillTypeIndex] = 1
                end
            end
        end
    end) 

    for skillTypeIndex,v in pairs(prevAllowedTaskLists) do
        if not allowedTaskLists[skillTypeIndex] then
            changedList[skillTypeIndex] = -1
        end
    end

    allowedTaskListsByTribeID[tribeID] = allowedTaskLists

    for skillTypeIndex,v in pairs(changedList) do
       -- mj:log("serverSapienSkills:updateTribeAllowedTaskLists found change:", skillTypeIndex)
        callCallbacksForSkillTypeChange(tribeID, skillTypeIndex, v)
    end

    --mj:log("serverSapienSkills:updateTribeAllowedTaskLists:", allowedTaskLists)
end

function serverSapienSkills:tribeHasSapienAllowedToDoTask(tribeID, skillTypeIndex)
    local allowedTaskLists = allowedTaskListsByTribeID[tribeID]
    --[[if not allowedTaskLists or not allowedTaskLists[skillTypeIndex] then
        mj:warn("no sapiens for skill:", skillTypeIndex, " tribeID:", tribeID, " given:", allowedTaskLists)
    end]]
    return allowedTaskLists and allowedTaskLists[skillTypeIndex]
end

function serverSapienSkills:sapienHasSkill(sapien, skillTypeIndex)
    local sharedState = sapien.sharedState
    if sharedState.skillState[skillTypeIndex] then
        return sharedState.skillState[skillTypeIndex].complete
    end
    return false
end

function serverSapienSkills:completeSkill(sapien, skillTypeIndex)
    local sharedState = sapien.sharedState
    sharedState:set("skillState", skillTypeIndex, "fractionComplete", 1.0)
    if not sharedState.skillState[skillTypeIndex].complete then
        sharedState:set("skillState", skillTypeIndex, "complete", true)
        serverGOM:sendNotificationForObject(sapien, notification.types.skillLearned.index, {
            skillTypeIndex = skillTypeIndex
        }, sharedState.tribeID)
        
        serverStatusEffects:setTimedEffect(sharedState, statusEffect.types.learnedSkill.index, 1000.0)
    end
end

local function sendNotificationsForResearchCompletion(sapien, researchTypeIndex, discoveryCraftableTypeIndex, isBaseDiscovery)
    local researchingSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex
    if isBaseDiscovery then
        serverGOM:sendNotificationForObject(sapien, notification.types.discovery.index, {
            skillTypeIndex = researchingSkillTypeIndex,
            researchTypeIndex = researchTypeIndex,
            discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
        }, sapien.sharedState.tribeID)
    end
    
    if discoveryCraftableTypeIndex and constructable.types[discoveryCraftableTypeIndex].disabledUntilCraftableResearched then
        serverGOM:sendNotificationForObject(sapien, notification.types.craftableDiscovery.index, {
            skillTypeIndex = researchingSkillTypeIndex,
            researchTypeIndex = researchTypeIndex,
            discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
        }, sapien.sharedState.tribeID)
    end
end

function serverSapienSkills:givePartialSkillForResearchCompletion(sapien, researchTypeIndex, skillFractionComplete)
    local researchingSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex
    if researchingSkillTypeIndex then
        local sharedState = sapien.sharedState
        if not (sharedState.skillState[researchingSkillTypeIndex] and sharedState.skillState[researchingSkillTypeIndex].complete) then
            sharedState:set("skillState", researchingSkillTypeIndex, "fractionComplete", mjm.clamp(skillFractionComplete, 0.05, 0.95))
        end
    end
end

function serverSapienSkills:completeSapienSkillsForResearchCompletion(sapien, researchTypeIndex)
    local researchingSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex
    if researchingSkillTypeIndex then
        serverSapienSkills:completeSkill(sapien, researchingSkillTypeIndex)
            
        if skill:priorityLevel(sapien, researchingSkillTypeIndex) == 0 then
            local beforeAssignmentAssignedCount = skill:getAssignedRolesCount(sapien)
            local autoAssignEnabled = serverWorld:getAutoRoleAssignmentEnabled(sapien.sharedState.tribeID)
            if beforeAssignmentAssignedCount < skill.maxRoles or autoAssignEnabled then
                serverSapien:setSkillPriority(sapien, researchingSkillTypeIndex, 1)
                if beforeAssignmentAssignedCount >= skill.maxRoles then
                    serverSapien:setSkillPriority(sapien, skill.types.researching.index, 0)
                end
            end
        end
    end
end

local function addToResearchIfNotComplete(sapien, researchTypeIndexOrNil, discoveryCraftableTypeIndex, combinedIncrement)
    if researchTypeIndexOrNil then
        --mj:debug("addToResearchIfNotComplete:", combinedIncrement, " researchTypeIndexOrNil:", researchTypeIndexOrNil, " discoveryCraftableTypeIndex", discoveryCraftableTypeIndex)
        if not serverWorld:discoveryIsCompleteForTribe(sapien.sharedState.tribeID, researchTypeIndexOrNil) then
            --mj:log("calling serverWorld:incrementDiscovery")
            if serverWorld:incrementDiscovery(sapien.sharedState.tribeID, researchTypeIndexOrNil, discoveryCraftableTypeIndex, combinedIncrement) then
                serverSapienSkills:completeSapienSkillsForResearchCompletion(sapien, researchTypeIndexOrNil)
                sendNotificationsForResearchCompletion(sapien, researchTypeIndexOrNil, discoveryCraftableTypeIndex, true)
            end
            return true --research is preventing skill learning
        else
            if discoveryCraftableTypeIndex then
                if not serverWorld:craftableDiscoveryIsCompleteForTribe(sapien.sharedState.tribeID, discoveryCraftableTypeIndex) then
            --mj:log("calling serverWorld:incrementCraftableDiscovery")
                    if serverWorld:incrementCraftableDiscovery(sapien.sharedState.tribeID, discoveryCraftableTypeIndex, combinedIncrement) then
                        serverSapienSkills:completeSapienSkillsForResearchCompletion(sapien, researchTypeIndexOrNil)
                        sendNotificationsForResearchCompletion(sapien, researchTypeIndexOrNil, discoveryCraftableTypeIndex, false)
                    end
                end
            end
        end


    end
    return false
end

function serverSapienSkills:completeResearchImmediately(sapien, researchTypeIndex, discoveryCraftableTypeIndex)
    if not serverWorld:discoveryIsCompleteForTribe(sapien.sharedState.tribeID, researchTypeIndex) then
        serverWorld:completeDiscoveryForTribe(sapien.sharedState.tribeID, researchTypeIndex, discoveryCraftableTypeIndex)
        serverSapienSkills:completeSapienSkillsForResearchCompletion(sapien, researchTypeIndex)
        sendNotificationsForResearchCompletion(sapien, researchTypeIndex, discoveryCraftableTypeIndex, true)
    else
        if discoveryCraftableTypeIndex then
            if not serverWorld:craftableDiscoveryIsCompleteForTribe(sapien.sharedState.tribeID, discoveryCraftableTypeIndex) then
                serverWorld:completeCraftableDiscoveryForTribe(sapien.sharedState.tribeID, discoveryCraftableTypeIndex)
                serverSapienSkills:completeSapienSkillsForResearchCompletion(sapien, researchTypeIndex)
                sendNotificationsForResearchCompletion(sapien, researchTypeIndex, discoveryCraftableTypeIndex, false)
            end
        end
    end
end

local function getIncrement(sapien, timerValue, skillTypeIndexOrNil, researchTypeIndexOrNil)

    local sharedState = sapien.sharedState
    local learnSpeed = 1.0
    if skillTypeIndexOrNil then
        learnSpeed = skill.types[skillTypeIndexOrNil].learnSpeed or learnSpeed
    end

    if researchTypeIndexOrNil then
        local researchType = research.types[researchTypeIndexOrNil]
        if researchType.initialResearchSpeedLearnMultiplier then
            learnSpeed = learnSpeed * researchType.initialResearchSpeedLearnMultiplier
        end
    end

    local baseIncrement = (timerValue / skill.timeToCompleteSkills) * learnSpeed

    local cleverSlowTraitInfluence = sapienTrait:getInfluence(sharedState.traits, sapienTrait.influenceTypes.allSkills.index)
    local cleverSlowTraitMultiplier = math.pow(2.0, cleverSlowTraitInfluence * sapienTrait.allSkillsInfluenceOnSkillLearningIncrement)

    local combinedIncrement = baseIncrement * cleverSlowTraitMultiplier
    if researchTypeIndexOrNil then
        combinedIncrement = combinedIncrement * 2.0
    end

   -- mj:log("in getIncrement. timerValue:", timerValue, " skill.timeToCompleteSkills:", skill.timeToCompleteSkills, " skill.types[skillTypeIndex].learnSpeed:", skill.types[skillTypeIndex].learnSpeed)
    --mj:log("cleverSlowTraitInfluence:", cleverSlowTraitInfluence, " cleverSlowTraitMultiplier:", cleverSlowTraitMultiplier, " combinedIncrement:", combinedIncrement)
    return combinedIncrement
end

function serverSapienSkills:addToSkill(sapien, skillTypeIndex, researchTypeIndexOrNil, discoveryCraftableTypeIndex, timerValueOrNil, absoluteFractionValueOrNil) --two variants, either a timerValue or an absoluteFractionValue

    --mj:debug("serverSapienSkills:addToSkill:", sapien.uniqueID, " researchTypeIndexOrNil:", researchTypeIndexOrNil, " discoveryCraftableTypeIndex:", discoveryCraftableTypeIndex, " timerValueOrNil:", timerValueOrNil, " absoluteFractionValueOrNil:", absoluteFractionValueOrNil)
    local sharedState = sapien.sharedState
    local combinedIncrement = absoluteFractionValueOrNil
    if not combinedIncrement then --
        combinedIncrement = getIncrement(sapien, timerValueOrNil, skillTypeIndex, researchTypeIndexOrNil)
    end
   -- mj:log("combinedIncrement:", combinedIncrement)
    --mj:error("serverSapienSkills:addToSkill:", timerValue, " combinedIncrement:", combinedIncrement)

    if addToResearchIfNotComplete(sapien, researchTypeIndexOrNil, discoveryCraftableTypeIndex, combinedIncrement) then
        return
    end

    if skillTypeIndex then
        if not sharedState.skillState[skillTypeIndex] then
            sharedState:set("skillState", skillTypeIndex, {
                complete = false,
                fractionComplete = 0.0,
            })
        elseif sharedState.skillState[skillTypeIndex].complete then
            return
        end

        local newSkillValue = sharedState.skillState[skillTypeIndex].fractionComplete + combinedIncrement

        --disabled--mj:objectLog(sapien.uniqueID, "serverSapienSkills:addToSkill skillTypeIndex:", skillTypeIndex, " newSkillValue:", newSkillValue)

        if newSkillValue >= 1.0 then
            serverSapienSkills:completeSkill(sapien, skillTypeIndex)
        else
            sharedState:set("skillState", skillTypeIndex, "fractionComplete", newSkillValue)
        end
    end
end



function serverSapienSkills:willHaveResearch(sapien, researchTypeIndex, discoveryCraftableTypeIndexOrNil, timerValue, absoluteFractionValueOrNil) --two variants, either a timerValue or an absoluteFractionValue
   -- mj:log("serverSapienSkills:willHaveResearch:", timerValue)
    local researchingSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex

    local baseDiscoveryComplete = serverWorld:discoveryIsCompleteForTribe(sapien.sharedState.tribeID, researchTypeIndex)

    if baseDiscoveryComplete then
        if not discoveryCraftableTypeIndexOrNil then
            return true
        else
            if serverWorld:craftableDiscoveryIsCompleteForTribe(sapien.sharedState.tribeID, discoveryCraftableTypeIndexOrNil) then
                return true
            end
        end
    end
    
    local combinedIncrement = absoluteFractionValueOrNil
    if not combinedIncrement then --
        combinedIncrement = getIncrement(sapien, timerValue, researchingSkillTypeIndex, researchTypeIndex)
    end
   -- mj:log("combinedIncrement:", combinedIncrement)

    if baseDiscoveryComplete then
        return serverWorld:craftableDiscoveryIncrementWouldComplete(sapien.sharedState.tribeID, discoveryCraftableTypeIndexOrNil, combinedIncrement)
    end
    return serverWorld:discoveryIncrementWouldComplete(sapien.sharedState.tribeID, researchTypeIndex, combinedIncrement)
end

function serverSapienSkills:update()
    for tribeID,v in pairs(needsToUpdateAllowedTaskListsTribeIDs) do
        serverSapienSkills:updateTribeAllowedTaskLists(tribeID)
    end
    needsToUpdateAllowedTaskListsTribeIDs = {}
end


function serverSapienSkills:setServerGOM(serverGOM_, serverWorld_, serverSapien_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    serverSapien = serverSapien_
end

return serverSapienSkills