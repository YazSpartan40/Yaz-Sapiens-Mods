local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local skill = mjrequire "common/skill"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
local gameObject = mjrequire "common/gameObject"
local timeControls = mjrequire "mainThread/ui/timeControls"

local playerSapiens = {}

local logicInterface = nil
local followerInfos = nil

local priorityCountsBySkillTypeIndex = {}
local followerCount = 0

function playerSapiens:setLogicInterface(logicInterface_)
    logicInterface = logicInterface_
end

local function updatePriorityCounts()
    --mj:log("updatePriorityCounts")
    priorityCountsBySkillTypeIndex = {}
    if followerInfos then
        for uniqueID, followerInfo in pairs(followerInfos) do
            local function addToCount(skillTypeIndex, priority)
                if priority ~= 0 then
                    local thisSkillPriorityCounts = priorityCountsBySkillTypeIndex[skillTypeIndex]
                    if not thisSkillPriorityCounts then
                        thisSkillPriorityCounts = {}
                        priorityCountsBySkillTypeIndex[skillTypeIndex] = thisSkillPriorityCounts
                    end
                    local currentCount = thisSkillPriorityCounts[priority] or 0
                    thisSkillPriorityCounts[priority] = currentCount + 1
                end
            end

            local skillPriorities = followerInfo.sharedState.skillPriorities
            for i,skillType in ipairs(skill.validTypes) do
                local skillTypeIndex = skillType.index
                local newPriority = 0
                if skillPriorities and skillPriorities[skillTypeIndex] ~= nil then
                    newPriority = skillPriorities[skillTypeIndex]
                end
                addToCount(skillTypeIndex, newPriority)
            end
        end
    end
end

--[[local function updateDueToChangedState(uniqueID, retrievedObjectResponse)
    if retrievedObjectResponse and followerInfos[uniqueID] then
        followerInfos[uniqueID].sharedState = retrievedObjectResponse.sharedState
        followerInfos[uniqueID].pos = retrievedObjectResponse.pos
    end
end]]

local function updateTimeControlsPopulation()
    timeControls:setPopulation(playerSapiens:getPopulationCountIncludingBabies())
end


local function cacheSapienModels()
    for uniqueID, followerInfo in pairs(followerInfos) do
        local gameObjectModelIndex = gameObject:modelIndexForGameObjectAndLevel(followerInfo, mj.SUBDIVISIONS - 1, nil)
        if gameObjectModelIndex then
            MJCache:cacheModel(gameObjectModelIndex)
        end
    end
end

function playerSapiens:initialFollowersListReceived(followerInfos_)
    
    followerInfos = followerInfos_
    followerCount = 0

    for uniqueID, followerInfo in pairs(followerInfos) do
        followerCount = followerCount + 1
        followerInfos[uniqueID].uniqueID = uniqueID
        followerInfos[uniqueID].objectTypeIndex = gameObject.types.sapien.index

        --[[logicInterface:registerFunctionForObjectStateChanges({uniqueID}, logicInterface.stateChangeRegistrationGroups.playerSapiens, function (retrievedObjectResponse)
            updateDueToChangedState(uniqueID, retrievedObjectResponse)
        end,
        function(removedObjectID)
        end)]]
    end

    updatePriorityCounts()
    cacheSapienModels()
    updateTimeControlsPopulation()
end

function playerSapiens:followersAdded(addedInfos)
    for uniqueID, followerInfo in pairs(addedInfos) do
        if not followerInfos[uniqueID] then
            followerInfos[uniqueID] = followerInfo
            followerCount = followerCount + 1
            followerInfos[uniqueID].uniqueID = uniqueID
            followerInfos[uniqueID].objectTypeIndex = gameObject.types.sapien.index

            --[[logicInterface:registerFunctionForObjectStateChanges({uniqueID}, logicInterface.stateChangeRegistrationGroups.playerSapiens, function (retrievedObjectResponse)
                updateDueToChangedState(uniqueID, retrievedObjectResponse)
            end,
            function(removedObjectID)
            end)]]
        end
    end
    updatePriorityCounts()
    updateTimeControlsPopulation()
end


function playerSapiens:followersRemoved(removedIDs)
    for i, uniqueID in ipairs(removedIDs) do
        if followerInfos[uniqueID] then
            followerCount = followerCount - 1
            followerInfos[uniqueID] = nil
        end
    end
    updatePriorityCounts()
    updateTimeControlsPopulation()
end


function playerSapiens:followerUpdated(uniqueID, pos, fullState, stateDelta)
    local followerInfo = followerInfos[uniqueID]
    if followerInfo then
        local needsToUpdatePopulation = false
        if fullState then 
            needsToUpdatePopulation = (followerInfo.sharedState.hasBaby or fullState.hasBaby) and (followerInfo.sharedState.hasBaby ~= fullState.hasBaby)
            followerInfo.sharedState = fullState
        else
            needsToUpdatePopulation = (stateDelta and stateDelta.hasBaby ~= nil)
            gameObjectSharedState:mergeDelta(followerInfo, stateDelta)
        end
        followerInfo.pos = pos

        if needsToUpdatePopulation then
            updateTimeControlsPopulation()
        end
        return followerInfo.sharedState
    end
    return nil
end

--[[function playerSapiens:followerChanged(posChangeUpdateData)

    followerInfos[]
    
   -- uniqueID = uniqueID,
   -- pos = objectInfo.pos,
   -- sharedState = objectInfo.sharedState,
end]]

function playerSapiens:skillPriorityListChanged()
    --mj:log("skillPriorityListChanged")
    updatePriorityCounts()
end

function playerSapiens:posForSapienWithUniqueID(uniqueID)
    if followerInfos and followerInfos[uniqueID] then
        return followerInfos[uniqueID].pos
    end
    return nil
end

function playerSapiens:getInfo(uniqueID)
    if followerInfos and followerInfos[uniqueID] then
        local info = {
            uniqueID = uniqueID,
            pos = followerInfos[uniqueID].pos,
            sharedState = followerInfos[uniqueID].sharedState,
            objectTypeIndex = gameObject.types.sapien.index,
        }

        return info
    end

    return nil
end

function playerSapiens:getPopulationCountIncludingBabies()
    if not followerInfos then
        return 0
    end
    local count = 0
    for uniqueID,followerInfo in pairs(followerInfos) do
        count = count + 1
        if followerInfo.sharedState.hasBaby then
            count = count + 1
        end
    end
    return count
end

function playerSapiens:getDistanceOrderedSapienList(basePos)    

    if not followerInfos then
        return {}
    end

    local function sortDistance(a,b)
        return a.d2 < b.d2
    end

    local orderedSapiens = {}
    for uniqueID,followerInfo in pairs(followerInfos) do
        local sapienVec = followerInfo.pos - basePos
        local d2 = length2(sapienVec)
        table.insert(orderedSapiens, {
            sapien = {
                uniqueID = uniqueID,
                pos = followerInfos[uniqueID].pos,
                sharedState = followerInfos[uniqueID].sharedState,
                objectTypeIndex = gameObject.types.sapien.index,
            },
            d2 = d2,
        })
    end

    table.sort(orderedSapiens, sortDistance)

   -- mj:log("result:", result)

    return orderedSapiens
end

function playerSapiens:hasFollowers()
    return (followerInfos and next(followerInfos))
end

function playerSapiens:sapienIsFollower(sapienID)
    return (followerInfos and followerInfos[sapienID])
end

function playerSapiens:getFollowerInfos()
    return followerInfos
end

function playerSapiens:moveAllBetweenSkillPriorities(skillTypeIndex, priorityLevelFrom, priorityLevelTo)
    logicInterface:callServerFunction("moveAllBetweenSkillPriorities", {
        skillTypeIndex = skillTypeIndex,
        priorityLevelFrom = priorityLevelFrom,
        priorityLevelTo = priorityLevelTo,
    })

    for uniqueID,followerInfo in pairs(followerInfos) do
        if skill:priorityLevel(followerInfo, skillTypeIndex) == priorityLevelFrom then
            if priorityLevelTo == 0 or skill:getAssignedRolesCount(followerInfo) < skill.maxRoles then
                followerInfos[uniqueID].sharedState.skillPriorities[skillTypeIndex] = priorityLevelTo
            end
        end
    end
    updatePriorityCounts()
end

function playerSapiens:setSkillPriority(sapienID, skillTypeIndex, priorityLevel)
    logicInterface:callServerFunction("setSkillPriority", {
        sapienID = sapienID,
        skillTypeIndex = skillTypeIndex,
        priority = priorityLevel,
    })

    if followerInfos[sapienID] and followerInfos[sapienID].sharedState and followerInfos[sapienID].sharedState.skillPriorities then
        followerInfos[sapienID].sharedState.skillPriorities[skillTypeIndex] = priorityLevel
        updatePriorityCounts()
    end
end

--
--return (sharedState.skillPriorities[skillTypeIndex] or 0)

function playerSapiens:getCountForSkillTypeAndPriority(skillTypeIndex, priority)
    local thisSkillPriorityCounts = priorityCountsBySkillTypeIndex[skillTypeIndex]

    if priority == 0 then
        if (not thisSkillPriorityCounts) or (not thisSkillPriorityCounts[1]) then
            return followerCount
        end
        return followerCount - thisSkillPriorityCounts[1]
    end

    if not thisSkillPriorityCounts then
        return 0
    end

    return thisSkillPriorityCounts[1] or 0
end

return playerSapiens