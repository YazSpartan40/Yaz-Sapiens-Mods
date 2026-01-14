
local resource = mjrequire "common/resource"
local plan = mjrequire "common/plan"
local gameObject = mjrequire "common/gameObject"
local flora = mjrequire "common/flora"
local skill = mjrequire "common/skill"
local tool = mjrequire "common/tool"
local rock = mjrequire "common/rock"
local research = mjrequire "common/research"
local terrainTypes = mjrequire "common/terrainTypes"
local constructable = mjrequire "common/constructable"
local statusEffect = mjrequire "common/statusEffect"
local sapienConstants = mjrequire "common/sapienConstants"
local medicine = mjrequire "common/medicine"
local locale = mjrequire "common/locale"
local mood = mjrequire "common/mood"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"
--local destination = mjrequire "common/destination"
local gameConstants = mjrequire "common/gameConstants"

local mob = mjrequire "common/mob/mob"

local planHelper = {}

planHelper.availablePlansFunctionsByObjectType = {}

planHelper.completedSkillsByTribeID = {}
planHelper.discoveriesByTribeID = {}
planHelper.craftableDiscoveriesByTribeID = {}
planHelper.destinationsByID = {}

local world = nil --only set on main thread
local serverWorld = nil --only set on server

local function getWorldTime()
    if world then
        return world:getWorldTime()
    end
    return serverWorld:getWorldTime()
end

function planHelper:updateCompletedSkillsForDiscoveriesChange(tribeID)
    for researchTypeIndex,discoveryInfo in pairs(planHelper.discoveriesByTribeID[tribeID]) do
        if discoveryInfo.complete then
            local researchType = research.types[researchTypeIndex]
            if researchType then
                local skillTypeIndex = researchType.skillTypeIndex
                if skillTypeIndex then
                    planHelper.completedSkillsByTribeID[tribeID][skillTypeIndex] = true
                end
            end
        end
    end
end

function planHelper:setDiscoveriesForTribeID(tribeID, discoveries, craftableDiscoveries)
    planHelper.discoveriesByTribeID[tribeID] = discoveries
    planHelper.completedSkillsByTribeID[tribeID] = {}
    planHelper.craftableDiscoveriesByTribeID[tribeID] = craftableDiscoveries
    planHelper:updateCompletedSkillsForDiscoveriesChange(tribeID)
end

function planHelper:setDestinationStateForTribeID(tribeID, destinationState) --only called on main thread for now
    planHelper.destinationsByID[tribeID] = destinationState
end

local function getPlanStatesForObjectSharedState(sharedState, tribeID)
    if sharedState then
        if sharedState.planStates and sharedState.planStates[tribeID] then
            if next(sharedState.planStates[tribeID]) then
                return sharedState.planStates[tribeID]
            end
        end
    end
    return nil
end



local function hasDiscoveredOneOfSkillsArray(tribeID, skillsArray)
    if planHelper.completedSkillsByTribeID[tribeID] then
        for i,skillTypeIndex in ipairs(skillsArray) do
            if planHelper.completedSkillsByTribeID[tribeID][skillTypeIndex] then
                return true
            end
        end
    end
    return false
end

local function hasDiscoveredSkill(tribeID, skillTypeIndex)
    if planHelper.completedSkillsByTribeID[tribeID] then
        if planHelper.completedSkillsByTribeID[tribeID][skillTypeIndex] then
            return true
        end
    end
    return false
end

function planHelper:getPlanStatesForVertInfo(objectOrVertInfo, tribeID)
    if objectOrVertInfo.sharedState then
        --mj:log("getPlanStatesForVertInfo objectOrVertInfo.sharedState:", objectOrVertInfo.sharedState)
        local planObjectInfo = objectOrVertInfo.planObjectInfo
        if planObjectInfo then
            local planStates = {}
            local found = false
            local planObjectSharedState = planObjectInfo.sharedState
            if planObjectSharedState then
                local objectPlanStates = planObjectSharedState.planStates
                if objectPlanStates then
                    local objectPlanStatesForTribe = objectPlanStates[tribeID]
                    if objectPlanStatesForTribe then
                        for i,planState in ipairs(objectPlanStatesForTribe) do
                            table.insert(planStates, planState)
                            found = true
                        end
                    end
                end
            end
            if found then
                return planStates
            end
        end
    end
    
    return nil
end

function planHelper:getGeneralDiplomacyChanceOffset(targetSapien, diplomatSapienTribeID) -- this function assumes we have already excluded nomads
    --normal
    -- -2: 0% chance
    -- -1: 15% chance
    -- 0: 75% chance
    -- 1+: 100% chance

    --master
    -- -2: 15% chance
    -- -1: 75% chance
    -- 0: 100% chance
    -- 1+: 100% chance

    -- todo maybe tribe desirablity eg. no luxuries

    if targetSapien.sharedState.tribeID == diplomatSapienTribeID then
        return 1
    end
    

    local destinationState = planHelper.destinationsByID[targetSapien.sharedState.tribeID]
    
    if destinationState.unprotectedByAnyAbleSapiens then
        return 1
    end

    if destinationState.clientID then
        local loyalty = mood:getMood(targetSapien, mood.types.loyalty.index)
        if loyalty <= mood.levels.moderateNegative then 
            if loyalty <= mood.levels.severeNegative then
                return 0
            end
            return -1
        end
        
        return -2
    end

    --now this must be an ai tribe

    local relationship = destinationState.relationships and destinationState.relationships[diplomatSapienTribeID]
    if (not relationship) then
        return -2
    end

    if relationship.favor <= gameConstants.tribeRelationshipScoreThresholds.moderateNegative then
        return -2
    end
    
    if relationship.favor >= gameConstants.tribeRelationshipScoreThresholds.moderatePositive then
        return 0
    end

    return -1

end

function planHelper:getHasDiplomacyFailTimeout(targetSapien)
    if targetSapien.sharedState.recruitFailTimeoutStartWorldTime then
        if getWorldTime() < targetSapien.sharedState.recruitFailTimeoutStartWorldTime + 120 then
            return true
        end
        if world then --main thread
            targetSapien.sharedState.recruitFailTimeoutStartWorldTime = nil
        else --server
            targetSapien.sharedState:remove("recruitFailTimeoutStartWorldTime")
        end
    end
    return false
end

function planHelper:getBanishChanceOffset(targetSapien, recruitingSapienTribeID)
    if targetSapien.sharedState.nomad then
        return nomadTribeBehavior.types[targetSapien.sharedState.tribeBehaviorTypeIndex].banishChanceOffset or 0
    end

    return planHelper:getGeneralDiplomacyChanceOffset(targetSapien, recruitingSapienTribeID)
end

function planHelper:getRecruitChanceOffset(targetSapien, recruitingSapienTribeID)
    if targetSapien.sharedState.nomad then
        return nomadTribeBehavior.types[targetSapien.sharedState.tribeBehaviorTypeIndex].recruitChanceOffset or 0
    end

    return planHelper:getGeneralDiplomacyChanceOffset(targetSapien, recruitingSapienTribeID)
end

function planHelper:getRecruitChanceOffsetText(recruitChanceOffset)
    if recruitChanceOffset <= -2 then
        return locale:get("recruitChanceOffset_veryHard") -- "Very hard"
    end
    if recruitChanceOffset <= -1 then
        return locale:get("recruitChanceOffset_hard") -- "Hard"
    end
    if recruitChanceOffset <= 0 then
        return locale:get("recruitChanceOffset_easy") -- "Easy"
    end

    return locale:get("recruitChanceOffset_veryEasy") -- "Very Easy"
end

function planHelper:getRestrictedObjectTypes(resourceInfo, toolTypeIndex)

    local gameObjectTypeIndexes = nil

    if resourceInfo then
        if resourceInfo.group then
            gameObjectTypeIndexes = {}
            for k,resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                gameObjectTypeIndexes = mj:concatTables(gameObjectTypeIndexes, gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex])
            end
        else
            gameObjectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceInfo.type]
        end
    else
        gameObjectTypeIndexes = gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex]
    end

    
    local gameObjectTypes = {}

    for i, objectTypeIndex in ipairs(gameObjectTypeIndexes) do
        gameObjectTypes[i] = gameObject.types[objectTypeIndex]
    end
    
    local function sortByName(a,b)
        return a.plural < b.plural
    end

    table.sort(gameObjectTypes, sortByName)

    return gameObjectTypes

end

function planHelper:getIconObjectTypeIndexForPlanState(object, planState)
    if planState.planTypeIndex == plan.types.research.index then
        return nil
    end

    local objectTypeIndex = planState.objectTypeIndex

    if planState.constructableTypeIndex then
        local constructableType = constructable.types[planState.constructableTypeIndex]
        local gameObjectTypeKeyOrIndex = constructableType.iconGameObjectType or constructableType.inProgressGameObjectTypeKey
        if gameObjectTypeKeyOrIndex then
            objectTypeIndex = gameObject.types[gameObjectTypeKeyOrIndex].index
        end

        if planState.planTypeIndex == plan.types.fill.index then
            local restrictedResourceTypes = object.sharedState.restrictedResourceObjectTypes
            if restrictedResourceTypes then
                local resourceInfo = constructableType.requiredResources[1]
                local objectTypes = planHelper:getRestrictedObjectTypes(resourceInfo, nil)
                for i, availableObjectType in ipairs(objectTypes) do
                    if not restrictedResourceTypes[availableObjectType.index] then
                        objectTypeIndex = availableObjectType.index
                        break
                    end
                end
            end
        end
    end
    return objectTypeIndex
end

function planHelper:getPlanHash(planInfo)
    local hash = mj:tostring(planInfo.planTypeIndex)
    if planInfo.objectTypeIndex then --and (not planInfo.allowAnyObjectType) then
        hash = hash .. "_o" .. mj:tostring(planInfo.objectTypeIndex)
    end
    if planInfo.researchTypeIndex then
        hash = hash .. "_r" .. mj:tostring(planInfo.researchTypeIndex)
    end
    if planInfo.extraHashIdentifier then
        hash = hash .. planInfo.extraHashIdentifier
    end
    return hash
end

function planHelper:addCancelPlansForAnyMissingQueuedPlans(objectOrVertInfos, tribeID, queuedPlanInfos, plans) --ambulance in case something went terribly wrong
    local function checkPlansMatch(queuedPlanInfo, addedPlan)
        return queuedPlanInfo.planTypeIndex == addedPlan.planTypeIndex and
        queuedPlanInfo.objectTypeIndex == addedPlan.objectTypeIndex and 
        queuedPlanInfo.researchTypeIndex == addedPlan.researchTypeIndex
    end

    for queuedHash,queuedPlanInfo in pairs(queuedPlanInfos) do
        if queuedPlanInfo.count > 0 then
            local found = false
            for i,addedPlan in ipairs(plans) do
                if checkPlansMatch(queuedPlanInfo, addedPlan) then
                    found = true
                    break
                end
            end
            if not found then
                local planInfoToAdd = {
                    planTypeIndex = queuedPlanInfo.planTypeIndex,
                    researchTypeIndex = queuedPlanInfo.researchTypeIndex,
                    discoveryCraftableTypeIndex = queuedPlanInfo.discoveryCraftableTypeIndex,
                    objectTypeIndex = queuedPlanInfo.objectTypeIndex,
                    constructableTypeIndex = queuedPlanInfo.constructableTypeIndex,
                    hasQueuedPlans = true,
                }
                table.insert(plans, planInfoToAdd)
            end
        end
    end
end

function planHelper:getQueuedPlanObjectCount(objectOrVertInfos, tribeID, isTerrain)
    local queuedCount = 0
    for i,objectOrVertInfo in ipairs(objectOrVertInfos) do
        local planStates = nil

        if isTerrain then
            planStates = planHelper:getPlanStatesForVertInfo(objectOrVertInfo, tribeID)
        else
            planStates = getPlanStatesForObjectSharedState(objectOrVertInfo.sharedState, tribeID)
        end
    
        if planStates and #planStates > 0 then
            queuedCount = queuedCount + 1
        end
    end
    return queuedCount
end

function planHelper:getQueuedPlanInfos(objectOrVertInfos, tribeID, isTerrain)

    local queuedPlanInfos = {}
    for i,objectOrVertInfo in ipairs(objectOrVertInfos) do
        local planStates = nil

        if isTerrain then
            planStates = planHelper:getPlanStatesForVertInfo(objectOrVertInfo, tribeID)
        else
            planStates = getPlanStatesForObjectSharedState(objectOrVertInfo.sharedState, tribeID)
        end
        
        if planStates then
            for j,planState in ipairs(planStates) do
                local planInfo = {
                    planTypeIndex = planState.planTypeIndex,
                    researchTypeIndex = planState.researchTypeIndex,
                    discoveryCraftableTypeIndex = planState.discoveryCraftableTypeIndex,
                    objectTypeIndex = planState.objectTypeIndex,
                }

               --[[ if objectOrVertInfo.objectTypeIndex and gameObject.types[objectOrVertInfo.objectTypeIndex].revertToSeedlingGatherResourceCounts then
                    planInfo.allowAnyObjectType = true
                end]]

                local hash = planHelper:getPlanHash(planInfo)
                if not queuedPlanInfos[hash] then
                    queuedPlanInfos[hash] = {
                        count = 1,
                        canComplete = planState.canComplete,
                        researchTypeIndex = planState.researchTypeIndex,
                        objectTypeIndex = planState.objectTypeIndex,
                        discoveryCraftableTypeIndex = planState.discoveryCraftableTypeIndex,
                        planTypeIndex = planState.planTypeIndex,
                        hasManuallyPrioritizedPlan = planState.manuallyPrioritized,
                        constructableTypeIndex = planState.constructableTypeIndex,
                        --objectOrVertIDs = {[objectOrVertInfo.uniqueID] = true}
                    }
                else
                    queuedPlanInfos[hash].count = queuedPlanInfos[hash].count + 1
                    queuedPlanInfos[hash].canComplete = queuedPlanInfos[hash].canComplete and planState.canComplete
                    queuedPlanInfos[hash].hasManuallyPrioritizedPlan = queuedPlanInfos[hash].hasManuallyPrioritizedPlan or planState.manuallyPrioritized
                   -- queuedPlanInfos[hash].objectOrVertIDs[objectOrVertInfo.uniqueID] = true
                end
            end
        end
    end

    return queuedPlanInfos
end

local function getQueuedPlanInfoMatch(planInfo, hash, queuedPlanInfos)
    local queuedInfo = queuedPlanInfos[hash]
    
    if not queuedInfo then --this hack deals with the case where the objectTypeIndex has been set on the planState, so the hash doesn't match here, but it's the same plan
        if not planInfo.objectTypeIndex then
            for k,queuedPlanInfo in pairs(queuedPlanInfos) do
                if queuedPlanInfo.planTypeIndex == planInfo.planTypeIndex and queuedPlanInfo.researchTypeIndex == planInfo.researchTypeIndex then
                    queuedInfo = queuedPlanInfo
                    break
                end
            end
        end
    end

    return queuedInfo
end

function planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)
    local hash = planHelper:getPlanHash(planInfo)
    local queuedInfo = getQueuedPlanInfoMatch(planInfo, hash, queuedPlanInfos)

    local availableCount = availablePlanCounts[hash]
    if availableCount and availableCount > 0 and ((not queuedInfo) or availableCount > queuedInfo.count) then
        planInfo.hasNonQueuedAvailable = true
    end
    --mj:log("addPlanExtraInfo:", planInfo, " availablePlanCounts:", availablePlanCounts)


    if queuedInfo then
        if queuedInfo.count > 0 then
            planInfo.hasQueuedPlans = true
        end
        planInfo.anyQueuedPlansCanComplete = queuedInfo.canComplete
        planInfo.hasManuallyPrioritizedQueuedPlan = queuedInfo.hasManuallyPrioritizedPlan
    end
end

function planHelper:requiredDiscoveryForResearchPlanIfMissing(tribeID, planInfo)
    local researchRequiredForVisibilityDiscoverySkillTypeIndexes = research.types[planInfo.researchTypeIndex].researchRequiredForVisibilityDiscoverySkillTypeIndexes

    --mj:log("researchRequiredForVisibilityDiscoverySkillTypeIndexes:", researchRequiredForVisibilityDiscoverySkillTypeIndexes)
    
    if not researchRequiredForVisibilityDiscoverySkillTypeIndexes then
        return nil
    end

    for i,researchRequiredForVisibilityDiscoverySkillTypeIndex in ipairs(researchRequiredForVisibilityDiscoverySkillTypeIndexes) do
        if not hasDiscoveredSkill(tribeID, researchRequiredForVisibilityDiscoverySkillTypeIndex) then
            --mj:log("missing researchRequiredForVisibilityDiscoverySkillTypeIndex:", researchRequiredForVisibilityDiscoverySkillTypeIndex)
            return researchRequiredForVisibilityDiscoverySkillTypeIndex
        end
    end
    --mj:log("no required discovery:", planInfo)

    if planInfo.discoveryCraftableTypeIndex then
        local constructableType = constructable.types[planInfo.discoveryCraftableTypeIndex]
        --mj:log("constructableType:", constructableType)
        if constructableType.researchRequiredForCraftableVisibilityDiscoverySkillTypeIndexes then
            for i,researchRequiredForVisibilityDiscoverySkillTypeIndex in ipairs(constructableType.researchRequiredForCraftableVisibilityDiscoverySkillTypeIndexes) do
               -- mj:log("researchRequiredForVisibilityDiscoverySkillTypeIndex:", researchRequiredForVisibilityDiscoverySkillTypeIndex)
                if not hasDiscoveredSkill(tribeID, researchRequiredForVisibilityDiscoverySkillTypeIndex) then
                    --mj:log("missing researchRequiredForVisibilityDiscoverySkillTypeIndex:", researchRequiredForVisibilityDiscoverySkillTypeIndex)
                    return researchRequiredForVisibilityDiscoverySkillTypeIndex
                end
            end
        end
    end

    --mj:log("no required discovery b")
    return nil
end

function planHelper:updateForAnyMissingOrInProgressDiscoveries(planInfo, tribeID, availablePlanCounts, vertOrObjectInfos, queuedPlanInfos, researchableCount)
    --mj:log("updateForAnyMissingOrInProgressDiscoveries planHelper.discoveriesByTribeID:", planHelper.discoveriesByTribeID, " research.types[planInfo.researchTypeIndex]:", research.types[planInfo.researchTypeIndex])
    if planInfo and planInfo.researchTypeIndex then
        local missingResearchTypeIndex = planHelper:requiredDiscoveryForResearchPlanIfMissing(tribeID, planInfo)
        if missingResearchTypeIndex then
            availablePlanCounts[planHelper:getPlanHash(planInfo)] = 0
            planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_missingKnowledge")
        end
    end
end

function planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, disableDueToObjectState, disableDueToObjectStateReasonTextOrNil, planTypeIndexOrNilForDeconstruct)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    local deconstructPlanInfo = {
        planTypeIndex = planTypeIndexOrNilForDeconstruct or plan.types.deconstruct.index,
    }

    local deconstructHash = planHelper:getPlanHash(deconstructPlanInfo)

    local availablePlanCounts = {
        [deconstructHash] = #objectInfos
    }

    if disableDueToObjectState or next(queuedPlanInfos) then --don't allow if any other plans are queued
        if disableDueToObjectState and disableDueToObjectStateReasonTextOrNil then
            deconstructPlanInfo.unavailableReasonText = disableDueToObjectStateReasonTextOrNil
        else
            deconstructPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
        availablePlanCounts[deconstructHash] = 0
    end

    planHelper:addPlanExtraInfo(deconstructPlanInfo, queuedPlanInfos, availablePlanCounts)

    return deconstructPlanInfo
end


function planHelper:getRebuildPlanInfo(objectInfos, tribeID, disableDueToObjectState, disableDueToObjectStateReasonTextOrNil, planTypeIndexOrNilForRebuild)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    local planInfo = {
        planTypeIndex = planTypeIndexOrNilForRebuild or plan.types.rebuild.index,
    }

    local planHash = planHelper:getPlanHash(planInfo)

    local availablePlanCounts = {
        [planHash] = #objectInfos
    }

    if disableDueToObjectState or next(queuedPlanInfos) then --don't allow if any other plans are queued
        if disableDueToObjectState and disableDueToObjectStateReasonTextOrNil then
            planInfo.unavailableReasonText = disableDueToObjectStateReasonTextOrNil
        else
            planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
        availablePlanCounts[planHash] = 0
    end

    planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)

    return planInfo
end

function planHelper:getClonePlanInfo(objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    local clonePlanInfo = {
        planTypeIndex = plan.types.clone.index,
    }

    local cloneHash = planHelper:getPlanHash(clonePlanInfo)

    local availablePlanCounts = {
        [cloneHash] = 1
    }

    if #objectInfos > 1 then
        availablePlanCounts[cloneHash] = 0
        clonePlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_multiSelect")
    end

    planHelper:addPlanExtraInfo(clonePlanInfo, queuedPlanInfos, availablePlanCounts)

    return clonePlanInfo
end

function planHelper:availablePlansForFloraObjects(baseObject, objectInfos, tribeID)

    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    local availablePlanCounts = {}
    
    local destroyPlanInfo = nil
    local chopAndReplantInfo = nil
    local researchPlanInfo = nil

    if not flora:requiresAxeToChop(baseObject) then
        destroyPlanInfo = {
            planTypeIndex = plan.types.pullOut.index;
            requirements = {
                skill = skill.types.gathering.index,
            },
        }
    else
        local requiredSkillTypeIndex = skill.types.treeFelling.index
        if hasDiscoveredSkill(tribeID, requiredSkillTypeIndex) then
            destroyPlanInfo = {
                planTypeIndex = plan.types.chop.index,
                requirements = {
                    toolTypeIndex = tool.types.treeChop.index,
                    skill = skill.types.treeFelling.index,
                },
            }

            if hasDiscoveredSkill(tribeID, skill.types.planting.index) then
                chopAndReplantInfo = {
                    planTypeIndex = plan.types.chopReplant.index,
                    requirements = {
                        toolTypeIndex = tool.types.treeChop.index,
                        skill = skill.types.treeFelling.index,
                    },
                }
            end
        else
            --if not planHelper:requiredDiscoveryForResearchPlanIfMissing(tribeID, research.types.treeFelling.index) then
                researchPlanInfo = {
                    planTypeIndex = plan.types.research.index,
                    researchTypeIndex = research.types.treeFelling.index,
                }
                availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = #objectInfos
           --end
        end
    end

    if destroyPlanInfo then
        if queuedPlanInfos and next(queuedPlanInfos) then
            availablePlanCounts[planHelper:getPlanHash(destroyPlanInfo)] = 0
            destroyPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        else
            availablePlanCounts[planHelper:getPlanHash(destroyPlanInfo)] = #objectInfos
        end
    end

    if chopAndReplantInfo then
        if queuedPlanInfos and next(queuedPlanInfos) then
            availablePlanCounts[planHelper:getPlanHash(chopAndReplantInfo)] = 0
            chopAndReplantInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        else
            availablePlanCounts[planHelper:getPlanHash(chopAndReplantInfo)] = #objectInfos
        end
    end

    

    if researchPlanInfo then
        planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, #objectInfos)
    end

    --local queuedPlanObjectCount = planHelper:getQueuedPlanObjectCount(objectInfos, tribeID, false)

    local gatherPlansByHash = {}
    local orderedHashes = {}
    
    
    local baseObjectGameObjectType = gameObject.types[baseObject.objectTypeIndex]
    
    local baseObjectRevertToSeedlingGatherResourceCounts = baseObjectGameObjectType.revertToSeedlingGatherResourceCounts
    local baseObjectGatherableTypes = baseObjectGameObjectType.gatherableTypes
    if baseObjectRevertToSeedlingGatherResourceCounts then
        baseObjectGatherableTypes = {baseObjectGameObjectType.gatherableTypes[1]}
    end

    --mj:log("baseObjectGatherableTypes:", baseObjectGatherableTypes)


    local foundFirstGatherableType = nil
    local foundMultipleGatherTypes = false

    local availableCountForGatherForAllObjectsCombined = 0
    local totalAvailableObjectTypesPerGatherableObjectTypeIndex = {}
    
    for i,objectInfo in ipairs(objectInfos) do
        local thisObjectInfoGameObjectType = gameObject.types[objectInfo.objectTypeIndex]
        local thisObjectInfoRevertToSeedlingGatherResourceCounts = thisObjectInfoGameObjectType.revertToSeedlingGatherResourceCounts
        
        local thisObjectInfoGatherableTypes = thisObjectInfoGameObjectType.gatherableTypes
        if thisObjectInfoRevertToSeedlingGatherResourceCounts then
            thisObjectInfoGatherableTypes = {thisObjectInfoGameObjectType.gatherableTypes[1]}
        end
        if thisObjectInfoGatherableTypes then

            local countsByObjectTypes = nil
            local sharedState = objectInfo.sharedState
            if sharedState.inventory then
                countsByObjectTypes = sharedState.inventory.countsByObjectType
            end

            local foundAnyGatherableThisObjectInfo = false
            for j,objectTypeIndex in ipairs(thisObjectInfoGatherableTypes) do
                if not foundFirstGatherableType then
                    foundFirstGatherableType = objectTypeIndex
                elseif foundFirstGatherableType ~= objectTypeIndex then
                    foundMultipleGatherTypes = true
                end

                if countsByObjectTypes then
                    local thisCount = countsByObjectTypes[objectTypeIndex]
                    if thisCount and thisCount > 0 then
                        if thisObjectInfoGameObjectType.gatherKeepMinQuantity and thisObjectInfoGameObjectType.gatherKeepMinQuantity[objectTypeIndex] then
                            thisCount = thisCount - thisObjectInfoGameObjectType.gatherKeepMinQuantity[objectTypeIndex]
                        end
                        if thisCount > 0 then
                            foundAnyGatherableThisObjectInfo = true
                            totalAvailableObjectTypesPerGatherableObjectTypeIndex[objectTypeIndex] = (totalAvailableObjectTypesPerGatherableObjectTypeIndex[objectTypeIndex] or 0) + 1
                        end
                    end
                end
            end

            if foundAnyGatherableThisObjectInfo then
                availableCountForGatherForAllObjectsCombined = availableCountForGatherForAllObjectsCombined + 1
            end
        end
    end

    local foundBaseGatherableType = (baseObjectGatherableTypes and baseObjectGatherableTypes[1])

    local hasQueuedGatherAllPlans = false
    if queuedPlanInfos then
        for queuedHash,queuedInfo in pairs(queuedPlanInfos) do
            --mj:log("queuedInfo:", queuedInfo)
            if queuedInfo.planTypeIndex == plan.types.gather.index and (not queuedInfo.objectTypeIndex) and queuedInfo.count > 0 then
                hasQueuedGatherAllPlans = true
                break
            end
        end
    end

    --mj:log("foundMultipleGatherTypes:", foundMultipleGatherTypes, "foundFirstGatherableType :", foundFirstGatherableType, " foundBaseGatherableType:", foundBaseGatherableType, " hasQueuedGatherAllPlans:", hasQueuedGatherAllPlans)
    
    local gatherAllPlanAdded = false
    if foundMultipleGatherTypes or (foundFirstGatherableType and (not foundBaseGatherableType)) or hasQueuedGatherAllPlans then

        local gatherAllPlanInfo = {
            planTypeIndex = plan.types.gather.index,
            extraHashIdentifier = "all",
            requirements = {
                skill = skill.types.gathering.index,
            }
        }
        local gatherAllPlanHash = planHelper:getPlanHash(gatherAllPlanInfo)

        gatherPlansByHash[gatherAllPlanHash] = gatherAllPlanInfo
        table.insert(orderedHashes, gatherAllPlanHash)
        availablePlanCounts[gatherAllPlanHash] = availableCountForGatherForAllObjectsCombined
        gatherAllPlanAdded = true
    end

    if ((not gatherAllPlanAdded) or foundMultipleGatherTypes) and baseObjectGatherableTypes then
        for j,objectTypeIndex in ipairs(baseObjectGatherableTypes) do
            local planInfo = {
                planTypeIndex = plan.types.gather.index,
                objectTypeIndex = objectTypeIndex,
                requirements = {
                    skill = skill.types.gathering.index,
                }
            }

            local planHash = planHelper:getPlanHash(planInfo)
            gatherPlansByHash[planHash] = planInfo
            table.insert(orderedHashes, planHash)
            if hasQueuedGatherAllPlans then
                availablePlanCounts[planHash] = 0
                planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
            else
                availablePlanCounts[planHash] = totalAvailableObjectTypesPerGatherableObjectTypeIndex[objectTypeIndex]
            end
        end
    end
    

    local plans = {}

    for i,hash in ipairs(orderedHashes) do
        local planInfo = gatherPlansByHash[hash]

        if availablePlanCounts[hash] and availablePlanCounts[hash] > 0  then
            if queuedPlanInfos[hash] then
                availablePlanCounts[hash] = availablePlanCounts[hash] - queuedPlanInfos[hash].count
                if availablePlanCounts[hash] <= 0 then
                    availablePlanCounts[hash] = 0
                    planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                end
            end
        end
        --mj:log("updated:", planInfo)

        planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)
        table.insert(plans, planInfo)
    end
    
    if researchPlanInfo then
        
        local researchHash = planHelper:getPlanHash(researchPlanInfo)
        
        if availablePlanCounts[researchHash] and availablePlanCounts[researchHash] > 0  then
            if queuedPlanInfos[researchHash] then
                availablePlanCounts[researchHash] = availablePlanCounts[researchHash] - queuedPlanInfos[researchHash].count
                if availablePlanCounts[researchHash] <= 0 then
                    availablePlanCounts[researchHash] = 0
                    researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                end
            end
        end

        planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
        table.insert(plans, researchPlanInfo)
    end

    local cloneRequiredSkillTypeIndex = skill.types.planting.index
    
    if hasDiscoveredSkill(tribeID, cloneRequiredSkillTypeIndex) then
        local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
        table.insert(plans, clonePlanInfo)
    end

    if chopAndReplantInfo then
        planHelper:addPlanExtraInfo(chopAndReplantInfo, queuedPlanInfos, availablePlanCounts)
        table.insert(plans, chopAndReplantInfo)
    end
    
    if destroyPlanInfo then
        planHelper:addPlanExtraInfo(destroyPlanInfo, queuedPlanInfos, availablePlanCounts)
        table.insert(plans, destroyPlanInfo)
    end

    --mj:log("plans:", plans)

    planHelper:addCancelPlansForAnyMissingQueuedPlans(objectInfos, tribeID, queuedPlanInfos, plans)
    
    return plans
end

function planHelper:availablePlansForNonResourceCarcass(baseObject, objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    local researchTypeIndex = research.types.butchery.index
    local requiredSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex

    local planInfo = nil
    
    if hasDiscoveredSkill(tribeID, requiredSkillTypeIndex) then
        planInfo = {
            planTypeIndex = plan.types.butcher.index,
            requirements = {
                toolTypeIndex = tool.types.butcher.index,
                skill = skill.types.butchery.index,
            },
        }
    else
       -- if not planHelper:requiredDiscoveryForResearchPlanIfMissing(tribeID, researchTypeIndex) then
            planInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = researchTypeIndex,
            }
       -- end
    end

    if not planInfo then
        return nil
    end

    local availablePlanCounts = {
        [planHelper:getPlanHash(planInfo)] = #objectInfos
    }

    planHelper:updateForAnyMissingOrInProgressDiscoveries(planInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, #objectInfos)

    if queuedPlanInfos and next(queuedPlanInfos) then
        availablePlanCounts[planHelper:getPlanHash(planInfo)] = 0
        planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
    else
        availablePlanCounts[planHelper:getPlanHash(planInfo)] = #objectInfos
    end

    planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)

    local plans = {
        planInfo
    }
    
    return plans
end

function planHelper:getPlanInfoForResearchableAction(objectInfos, tribeID, queuedPlanInfos, researchTypeIndex, researchCompletePlanInfo, returnResearchPlanIfNotDiscovered)
    local requiredSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex

    local planInfo = nil
    
    if hasDiscoveredSkill(tribeID, requiredSkillTypeIndex) then
        planInfo = researchCompletePlanInfo
    else
        if not returnResearchPlanIfNotDiscovered then
            return nil
        end

        planInfo = {
            planTypeIndex = plan.types.research.index,
            researchTypeIndex = researchTypeIndex,
        }
    end

    local planHash = planHelper:getPlanHash(planInfo)

    local availablePlanCounts = {
        [planHash] = #objectInfos
    }

    planHelper:updateForAnyMissingOrInProgressDiscoveries(planInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, #objectInfos)

    
    if availablePlanCounts[planHash] > 0  then
        local queuedPlanObjectCount = planHelper:getQueuedPlanObjectCount(objectInfos, tribeID, false)
        if queuedPlanObjectCount >= availablePlanCounts[planHash] then
            availablePlanCounts[planHash] = 0
            planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
    end

    planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)
    
    return planInfo
end

function planHelper:availablePlansForMineableObjects(baseObject, objectInfos, tribeID)

    local hasMineDiscovery = false
    local hasChiselStoneDiscovery = false
    if planHelper.completedSkillsByTribeID[tribeID] then
        if planHelper.completedSkillsByTribeID[tribeID][skill.types.mining.index] then
            hasMineDiscovery = true
        end
        if planHelper.completedSkillsByTribeID[tribeID][skill.types.chiselStone.index] then
            hasChiselStoneDiscovery = true
        end
    end

    
    local availablePlanCounts = {}
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    local plans = {}
    
    local minePlanInfo = {
        planTypeIndex = plan.types.mine.index,
        requirements = {
            toolTypeIndex = tool.types.mine.index,
            skill = skill.types.mining.index,
        },
    }
    local mineHash = planHelper:getPlanHash(minePlanInfo)
    availablePlanCounts[mineHash] = #objectInfos

    local chiselToolTypeIndex = tool.types.hardChiselling.index
    local foundSoftRock = false
    
    for i, objectInfo in ipairs(objectInfos) do
        local rockTypeIndex = gameObject.types[objectInfo.objectTypeIndex].rockTypeIndex
        if rock.types[rockTypeIndex].isSoftRock then
            foundSoftRock = true
            chiselToolTypeIndex = tool.types.softChiselling.index
            break
        end
    end
    
    local chiselPlanInfo = {
        planTypeIndex = plan.types.chiselStone.index,
        requirements = {
            toolTypeIndex = chiselToolTypeIndex,
            skill = skill.types.chiselStone.index,
        },
    }

    local chiselHash = planHelper:getPlanHash(chiselPlanInfo)
    availablePlanCounts[chiselHash] = #objectInfos

    
    
    local function addMineResearchPlan()
        local researchType = research.types.mining
        local researchPlanInfo = {
            planTypeIndex = plan.types.research.index,
            researchTypeIndex = researchType.index,
            requirements = {
                toolTypeIndex = tool.types.mine.index,
                skill = skill.types.researching.index,
            },
        }
        planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, availablePlanCounts[mineHash])
        if queuedPlanInfos and next(queuedPlanInfos) then
            availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = 0
            researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        else
            availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = #objectInfos
        end
        planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
        table.insert(plans, researchPlanInfo)
    end
    
    local function addChiselResearchPlan()
        local hasRequirementsForVisiblity = false --this could be factored out if similar pattern needed again, but it's a special case for now
        if foundSoftRock then
            if hasDiscoveredSkill(tribeID, skill.types.rockKnapping.index) then --able to craft stone chisel
                hasRequirementsForVisiblity = true
            end
        end
        if not hasRequirementsForVisiblity then
            if hasDiscoveredSkill(tribeID, skill.types.blacksmithing.index) then --able to craft bronze chisel
                hasRequirementsForVisiblity = true
            end
        end
        if hasRequirementsForVisiblity then
            local researchType = research.types.chiselStone
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = researchType.index,
                requirements = {
                    toolTypeIndex = chiselToolTypeIndex,
                    skill = skill.types.researching.index,
                },
            }
            planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, availablePlanCounts[chiselHash])
            --mj:log("queuedPlanInfos:", queuedPlanInfos, " hash:", planHelper:getPlanHash(researchPlanInfo))
            if queuedPlanInfos and next(queuedPlanInfos) then
                availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = 0
                researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
            else
                availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = #objectInfos
            end
            planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
            table.insert(plans, researchPlanInfo)
        end
    end
    
    if hasMineDiscovery then
        table.insert(plans, minePlanInfo)
        planHelper:addPlanExtraInfo(minePlanInfo, queuedPlanInfos, availablePlanCounts)
        if queuedPlanInfos and next(queuedPlanInfos) then
            availablePlanCounts[mineHash] = 0
            minePlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
    else
        addMineResearchPlan()
    end
    
    if hasChiselStoneDiscovery then
        table.insert(plans, chiselPlanInfo)
        planHelper:addPlanExtraInfo(chiselPlanInfo, queuedPlanInfos, availablePlanCounts)
        if queuedPlanInfos and next(queuedPlanInfos) then
            availablePlanCounts[chiselHash] = 0
            chiselPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
    else
        addChiselResearchPlan()
    end

    return plans
end

function planHelper:availablePlansForGenericBuiltObjects(baseObject, objectInfos, tribeID)
    local deconstructionPlanInfo = planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, false)
    local rebuildPlanInfo = planHelper:getRebuildPlanInfo(objectInfos, tribeID, false)
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    
    local plans = {
        clonePlanInfo,
        rebuildPlanInfo,
        deconstructionPlanInfo,
    }
    
    return plans
end


function planHelper:getPlayMusicalInstrumentPlanInfo(objectInfos, tribeID, musicalInstrumentSkillTypeIndex)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local playPlanInfo = {
        planTypeIndex = plan.types.playInstrument.index,
        requirements = {
            skill = musicalInstrumentSkillTypeIndex,
        },
    }

    local musicalInstrumentResearchType = research.researchTypesBySkillType[musicalInstrumentSkillTypeIndex]

    local planInfo = planHelper:getPlanInfoForResearchableAction(objectInfos, tribeID, queuedPlanInfos, musicalInstrumentResearchType.index, playPlanInfo, false)

    return planInfo
end

function planHelper:defaultAvailablePlansForResourceObjects(baseObject, objectInfos, tribeID, firstObjectType)

    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local queuedPlanObjectCount = planHelper:getQueuedPlanObjectCount(objectInfos, tribeID, false)
    
	local storePlanInfo = {
        planTypeIndex = plan.types.storeObject.index,
        requirements = {
            skill = skill.types.gathering.index,
        }
    }

    --mj:log("#objectInfos:", #objectInfos, " queuedPlanObjectCount:", queuedPlanObjectCount, " queuedPlanInfos:", queuedPlanInfos)

    local storeHash = planHelper:getPlanHash(storePlanInfo)
    local availablePlanCounts = {
        [storeHash] = #objectInfos-- - queuedPlanObjectCount
    }

    planHelper:addPlanExtraInfo(storePlanInfo, queuedPlanInfos, availablePlanCounts)

    if availablePlanCounts[storeHash] == 0 and queuedPlanObjectCount > 0 then
        storePlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
    end

    local plans = {
        storePlanInfo
    }

    if constructable.constructablesByResourceObjectTypeIndexes[firstObjectType.index] then
        local constructWithPlanInfo = {
            planTypeIndex = plan.types.constructWith.index,
        }
        local hash = planHelper:getPlanHash(constructWithPlanInfo)
        availablePlanCounts[hash] = #objectInfos

        
        planHelper:addPlanExtraInfo(constructWithPlanInfo, queuedPlanInfos, availablePlanCounts)

        local craftHash = planHelper:getPlanHash({
            planTypeIndex = plan.types.craft.index,
        })
        
        local queuedInfo = getQueuedPlanInfoMatch(constructWithPlanInfo, craftHash, queuedPlanInfos)

        if queuedInfo then
            if queuedInfo.count > 0 then
                constructWithPlanInfo.hasNonQueuedAvailable = nil
                constructWithPlanInfo.hasQueuedPlans = true
            end
            constructWithPlanInfo.anyQueuedPlansCanComplete = queuedInfo.canComplete
            constructWithPlanInfo.hasManuallyPrioritizedQueuedPlan = queuedInfo.hasManuallyPrioritizedPlan
        end
        
        table.insert(plans, constructWithPlanInfo)

    end
    
    --local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
   -- table.insert(plans, clonePlanInfo)
    
    local resourceType = resource.types[firstObjectType.resourceTypeIndex]
    if resourceType.musicalInstrumentSkillTypeIndex then
        local playPlanInfo = planHelper:getPlayMusicalInstrumentPlanInfo(objectInfos, tribeID, resourceType.musicalInstrumentSkillTypeIndex)
        if playPlanInfo then
            table.insert(plans, playPlanInfo)
        end
    end
    
    return plans
end

function planHelper:availablePlansForResourceObjects(baseObject, objectInfos, tribeID)
    
    local firstObjectType = gameObject.types[baseObject.objectTypeIndex]
    local researchTypes = research.researchTypesByResourceType[firstObjectType.resourceTypeIndex]
    if not researchTypes then
        return planHelper:defaultAvailablePlansForResourceObjects(baseObject, objectInfos, tribeID, firstObjectType)
    end

    local plans = planHelper:defaultAvailablePlansForResourceObjects(baseObject, objectInfos, tribeID, firstObjectType)
    local availablePlanCounts = {}

    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    for i, researchType in ipairs(researchTypes) do
        local complete = planHelper.discoveriesByTribeID[tribeID] and planHelper.discoveriesByTribeID[tribeID][researchType.index] and planHelper.discoveriesByTribeID[tribeID][researchType.index].complete

        local discoveryCraftableTypeIndex = research:getIncompleteDiscoveryCraftableTypeIndexForResearchAndResourceType(researchType.index, firstObjectType.resourceTypeIndex, planHelper.craftableDiscoveriesByTribeID[tribeID], complete)
        --mj:log("complete:", complete, "discoveryCraftableTypeIndex:", discoveryCraftableTypeIndex, " researchType:", researchType)
        if complete and discoveryCraftableTypeIndex then
            complete = false
        end

        if not complete then
            
           -- if not planHelper:requiredDiscoveryForResearchPlanIfMissing(tribeID, researchType.index) then
                local researchPlanInfo = {
                    planTypeIndex = plan.types.research.index,
                    researchTypeIndex = researchType.index,
                    discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
                }
                planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, #objectInfos)

                
                local canCompleteResearch = (not researchPlanInfo.unavailableReasonText)
                --if canCompleteResearch or i == #researchTypes then

                    if queuedPlanInfos and next(queuedPlanInfos) then
                        availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = 0
                        researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                    elseif canCompleteResearch then
                        availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = #objectInfos
                    end

                    planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
                    table.insert(plans, researchPlanInfo)
                --end
          --  end
        end
    end
    
    return plans
end

function planHelper:availablePlansForFollowerSapiens(baseObject, objectInfos, tribeID)
    local hasQueuedOrderCancelOverride = nil
    local hasWaitOrderSet = false
    local hasNonQueuedWaitOrder = false
    local hasMoveOrder = false

    local completedTreatmentPlans = {}
    local availableTreatmentPlanCounts = {}
    local hasTreatmentPlans = false
    --local hasMoveAndWaitOrder = false
    for i, objectInfo in ipairs(objectInfos) do
        local sharedState = objectInfo.sharedState
        if sharedState.orderQueue and sharedState.orderQueue[1] then
            
            local orderState = sharedState.orderQueue[1]
            local orderContext = orderState.context
            if orderContext then
                if orderContext.planTypeIndex == plan.types.moveTo.index then
                    hasMoveOrder = true
                --elseif orderContext.planTypeIndex == plan.types.moveAndWait.index then
                    --hasMoveAndWaitOrder = true
                end
            end

            hasQueuedOrderCancelOverride = true
        end

        if sharedState.waitOrderSet then
            hasWaitOrderSet = true
        else
            hasNonQueuedWaitOrder = true
        end

        for statusEffectTypeIndex,statusEffectInfo in pairs(sharedState.statusEffects) do
            local statusEffectType = statusEffect.types[statusEffectTypeIndex]
            if statusEffectType.requiredMedicineTypeIndex then
                hasTreatmentPlans = true
                local medicineType = medicine.types[statusEffectType.requiredMedicineTypeIndex]
                if statusEffect:hasEffect(sharedState, medicineType.treatmentStatusEffect) then
                    completedTreatmentPlans[medicineType.treatmentPlanTypeIndex] = true
                else
                    availableTreatmentPlanCounts[medicineType.treatmentPlanTypeIndex] = (availableTreatmentPlanCounts[medicineType.treatmentPlanTypeIndex] or 0) + 1
                end
            end
        end
    end

    local managePlanInfo = {
        planTypeIndex = plan.types.manageSapien.index,
    }
    if #objectInfos == 1 then
        managePlanInfo.hasNonQueuedAvailable = true
    else
        managePlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_multiSelect")
    end

    local plans = {
        managePlanInfo
    }

    --move

	local movePlanInfo = {
        planTypeIndex = plan.types.moveTo.index,
        sapienAssignButtonShouldBeHidden = true,
        hasNonQueuedAvailable = true
    }

    if hasMoveOrder then
        movePlanInfo.hasQueuedPlans = true
        movePlanInfo.anyQueuedPlansCanComplete = true
        movePlanInfo.cancelIsFollowerOrderQueue = true
    end
    table.insert(plans, movePlanInfo)
    

    --wait
    
	local waitPlanInfo = {
        planTypeIndex = plan.types.wait.index,
        sapienAssignButtonShouldBeHidden = true,
    }

    if hasWaitOrderSet then
        waitPlanInfo.hasQueuedPlans = true
        waitPlanInfo.anyQueuedPlansCanComplete = true
    end

    if hasNonQueuedWaitOrder then
        waitPlanInfo.hasNonQueuedAvailable = true
    end
    table.insert(plans, waitPlanInfo)

    if hasTreatmentPlans then
        local maxCount = 2
        local foundCount = 0

        local planTypesToAdd = {}
        local addedPlanTypeSet = {}

        for i,statusEffectTypeIndex in ipairs(statusEffect.orderedNegativeEffects) do
            local statusEffectType = statusEffect.types[statusEffectTypeIndex]
            if statusEffectType.requiredMedicineTypeIndex then
                local medicineType = medicine.types[statusEffectType.requiredMedicineTypeIndex]
                if not addedPlanTypeSet[medicineType.treatmentPlanTypeIndex] then
                    addedPlanTypeSet[medicineType.treatmentPlanTypeIndex] = true
                    if availableTreatmentPlanCounts[medicineType.treatmentPlanTypeIndex] then
                        table.insert(planTypesToAdd, medicineType.treatmentPlanTypeIndex)
                        foundCount = foundCount + 1
                        --mj:log("add to availableTreatmentPlanCounts ")
                    end

                    if foundCount >= maxCount then
                        break
                    end
                end
            end
        end

        if foundCount < maxCount then
            for i,statusEffectTypeIndex in ipairs(statusEffect.orderedNegativeEffects) do
                local statusEffectType = statusEffect.types[statusEffectTypeIndex]
                if statusEffectType.requiredMedicineTypeIndex then
                    local medicineType = medicine.types[statusEffectType.requiredMedicineTypeIndex]
                    if not addedPlanTypeSet[medicineType.treatmentPlanTypeIndex] then
                        addedPlanTypeSet[medicineType.treatmentPlanTypeIndex] = true
                        if completedTreatmentPlans[medicineType.treatmentPlanTypeIndex] then
                            table.insert(planTypesToAdd, medicineType.treatmentPlanTypeIndex)
                            foundCount = foundCount + 1
                            --mj:log("add to completedTreatmentPlans ")
                        end
            
                        if foundCount >= maxCount then
                            break
                        end
                    end
                end
            end
        end

        local skillsArray = {
            skill.types.medicine.index,
        }
        local hasDiscoveredMedicine = hasDiscoveredOneOfSkillsArray(tribeID, skillsArray)

        local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
        for i,planTypeIndex in ipairs(planTypesToAdd) do
            local treatPlanInfo = {
                planTypeIndex = planTypeIndex,
                requirements = {
                    skill = skill.types.medicine.index,
                }
            }
            local treatHash = planHelper:getPlanHash(treatPlanInfo)
            local availableCount = 0
            if hasDiscoveredMedicine and availableTreatmentPlanCounts[planTypeIndex] then
                availableCount = availableTreatmentPlanCounts[planTypeIndex]
            end

            local availablePlanCounts = {
                [treatHash] = availableCount
            }

            if availableCount == 0 then
                if hasDiscoveredMedicine then
                    treatPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_alreadyTreated")
                else
                    treatPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_missingKnowledge")
                end
            end

            planHelper:addPlanExtraInfo(treatPlanInfo, queuedPlanInfos, availablePlanCounts)
            table.insert(plans, treatPlanInfo)
        end
    end

    --stop
    
	local stopPlanInfo = {
        planTypeIndex = plan.types.stop.index,
    }
    
    if hasQueuedOrderCancelOverride then
        stopPlanInfo.hasNonQueuedAvailable = true
    end
    table.insert(plans, stopPlanInfo)


    --banish
    
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

	local banishPlanInfo = {
        planTypeIndex = plan.types.banish.index,
        banishChanceOffset = 2, --note little hack, > 1 means that "(Easy)" will not be appended in the radial menu
        requiresConfirmation = true, --todo requiresConfirmation assumes banish only
    }

    local availablePlanCounts = {
        [planHelper:getPlanHash(banishPlanInfo)] = #objectInfos
    }

    planHelper:addPlanExtraInfo(banishPlanInfo, queuedPlanInfos, availablePlanCounts)

    table.insert(plans, banishPlanInfo)

    
    return plans
end

function planHelper:availablePlansForNonFollowerSapiens(baseObject, objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local firstObjectSharedState = baseObject.sharedState
    local sapienTribeID = firstObjectSharedState.tribeID

    local plans = {}

    local ableSapienCount = 0
    local totalSapienCount = #objectInfos

    for i,objectInfo in ipairs(objectInfos) do
        if not sapienConstants:getHasLimitedGeneralAbility(objectInfo.sharedState, false) then
            ableSapienCount = ableSapienCount + 1
        end
    end

    local function addPlan(planTypeIndex, planGroupTypeIndexOrNil, requiredSkillTypeIndexOrNilForDiplomacy, requiredToolTypeIndexOrNil, researchTypeIndexOrNil)

        local researchTypeIndex = nil
        local planGroupTypeIndex = planGroupTypeIndexOrNil
        local isAttackPlan = plan.types[planTypeIndex].isAttackPlan
        
        if researchTypeIndexOrNil and requiredSkillTypeIndexOrNilForDiplomacy and (not hasDiscoveredSkill(tribeID, requiredSkillTypeIndexOrNilForDiplomacy)) then
            planTypeIndex = plan.types.research.index
            researchTypeIndex = researchTypeIndexOrNil
            requiredSkillTypeIndexOrNilForDiplomacy = skill.types.researching.index
            isAttackPlan = research.types[researchTypeIndex].isAttackPlan
        end

        local planInfo = {
            planTypeIndex = planTypeIndex,
            researchTypeIndex = researchTypeIndex,
            planGroupTypeIndex = planGroupTypeIndex,
            requirements = {
                skill = requiredSkillTypeIndexOrNilForDiplomacy or skill.types.diplomacy.index,
                toolTypeIndex = requiredToolTypeIndexOrNil,
            },
        }
        
        local available = true

        if planTypeIndex == plan.types.recruit.index or planTypeIndex == plan.types.banish.index then
            if baseObject.sharedState.fleeing or planHelper:getHasDiplomacyFailTimeout(baseObject) then
                available = false
                planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_recruitBanishTimeout")
            else
                if planTypeIndex == plan.types.recruit.index then
                    local recruitChanceOffset = planHelper:getRecruitChanceOffset(baseObject, tribeID)
                    if recruitChanceOffset <= -2 then
                        available = false --todo if mastered, allow
                    end
                    planInfo.recruitChanceOffset = recruitChanceOffset
                elseif planTypeIndex == plan.types.banish.index then
                    local banishChanceOffset = planHelper:getBanishChanceOffset(baseObject, tribeID)
                    if banishChanceOffset <= -2 then
                        available = false --todo if mastered, allow
                    end
                    planInfo.banishChanceOffset = banishChanceOffset
                    planInfo.isDestructiveOverride = false --note we also need a hack in clientGOM updatePlanObject for the order markers to be correct
                end
            end
        end

        local count = 0
        if available then
            if isAttackPlan then
                count = ableSapienCount
            else
                count = totalSapienCount
            end
        end

        local availablePlanCounts = {
            [planHelper:getPlanHash(planInfo)] = count
        }

        if researchTypeIndex then
            planHelper:updateForAnyMissingOrInProgressDiscoveries(planInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, count)
        end


        planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)

        table.insert(plans, planInfo)
        return planInfo
    end

    local function addAttackPlans()
        --todo this maybe only enabled if below dimplomatic threshold?
        addPlan(plan.types.attack_handToHand.index, plan.types.attack.index, skill.types.handToHandCombat.index, nil, nil)
        addPlan(plan.types.attack_throwRock.index, plan.types.attack.index, skill.types.basicHunting.index, tool.types.weaponBasic.index, research.types.basicHunting.index)
        addPlan(plan.types.attack_throwSpear.index, plan.types.attack.index, skill.types.spearHunting.index, tool.types.weaponSpear.index, research.types.spearHunting.index)
    end
    
    if firstObjectSharedState.nomad then
        addPlan(plan.types.recruit.index)
        addPlan(plan.types.banish.index)
        addAttackPlans()
    else
        local destinationState = planHelper.destinationsByID[sapienTribeID]
        if destinationState and (destinationState.relationships and destinationState.relationships[tribeID]) then
            addPlan(plan.types.manageTribeRelations.index)
            addPlan(plan.types.recruit.index)
            addPlan(plan.types.banish.index)
            
            addAttackPlans()
        else
            addPlan(plan.types.greet.index)
            addPlan(plan.types.recruit.index)
            addPlan(plan.types.banish.index)

            addAttackPlans()
        end
    end

    --mj:log("plans:", plans)
    
    return plans
end

function planHelper:availablePlansForSapiens(baseObject, objectInfos, tribeID)

    local firstObjectSharedState = baseObject.sharedState
    local sapienTribeID = firstObjectSharedState.tribeID

    if sapienTribeID == tribeID then
        return planHelper:availablePlansForFollowerSapiens(baseObject, objectInfos, tribeID)
    else
        return planHelper:availablePlansForNonFollowerSapiens(baseObject, objectInfos, tribeID)
    end
end

--[[local function availablePlansForCarcass(objectInfo, tribeID)
    local cancelPlans = getCancelPlans(objectInfo, tribeID)
    if cancelPlans then
        return cancelPlans
    end
    
    local plans = defaultAvailablePlansForResourceObject(objectInfo, tribeID)

    return plans
end]]


function planHelper:availablePlansForCraftArea(baseObject, objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local craftPlanInfo = {
        planTypeIndex = plan.types.craft.index,
    }
    local hash = planHelper:getPlanHash(craftPlanInfo)
    local availablePlanCounts = {
        [hash] = #objectInfos
    }

    planHelper:addPlanExtraInfo(craftPlanInfo, queuedPlanInfos, availablePlanCounts)

    local plans = {
        craftPlanInfo,
    }
    
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    table.insert(plans, clonePlanInfo)
    
    local rebuildPlanInfo = planHelper:getRebuildPlanInfo(objectInfos, tribeID, false)
    table.insert(plans, rebuildPlanInfo)
    
    local deconstructionPlanInfo = planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, false)
    table.insert(plans, deconstructionPlanInfo)

    
    return plans
end


function planHelper:availablePlansForTemporaryCraftArea(baseObject, objectInfos, tribeID)

    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local plans = {}
    for hash, queuedInfo in pairs(queuedPlanInfos) do
        local planTypeIndex = plan.types.research.index
        if not queuedInfo.researchTypeIndex then
            planTypeIndex = plan.types.craft.index
        end
        local craftPlanInfo = {
            planTypeIndex = planTypeIndex,
            researchTypeIndex = queuedInfo.researchTypeIndex,
            discoveryCraftableTypeIndex = queuedInfo.discoveryCraftableTypeIndex,
            hasQueuedPlans = true,
            anyQueuedPlansCanComplete = queuedInfo.canComplete,
            hasManuallyPrioritizedQueuedPlan = queuedInfo.hasManuallyPrioritizedPlan,
            hideUIOnCancel = true,
        }
        table.insert(plans, craftPlanInfo)
    end
    
    return plans
end

function planHelper:availablePlansForCampfires(baseObject, objectInfos, tribeID)

    
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local plans = {}

    for hash, queuedInfo in pairs(queuedPlanInfos) do
        if queuedInfo.researchTypeIndex then
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = queuedInfo.researchTypeIndex,
                discoveryCraftableTypeIndex = queuedInfo.discoveryCraftableTypeIndex,
                hasQueuedPlans = true,
                anyQueuedPlansCanComplete = queuedInfo.canComplete,
                hasManuallyPrioritizedQueuedPlan = queuedInfo.hasManuallyPrioritizedPlan,
                hideUIOnCancel = true,
            }
            table.insert(plans, researchPlanInfo)
        end
    end

    local craftPlanInfo = {
        planTypeIndex = plan.types.craft.index,
    }
    local craftHash = planHelper:getPlanHash(craftPlanInfo)


    local lightPlanInfo = {
        planTypeIndex = plan.types.light.index,
        requirements = {
            skill = skill.types.fireLighting.index,
        },
    }
    local lightHash = planHelper:getPlanHash(lightPlanInfo)

    local extinguishPlanInfo = {
        planTypeIndex = plan.types.extinguish.index,
    }
    local extinguishHash = planHelper:getPlanHash(extinguishPlanInfo)
    
    local availablePlanCounts = {
        [craftHash] = 0,
        [lightHash] = 0,
        [extinguishHash] = 0,
    }
    
    local anyCampfireIsLit = false
    for i,objectInfo in ipairs(objectInfos) do
        local sharedState = objectInfo.sharedState
        if sharedState.isLit then
            availablePlanCounts[extinguishHash] = availablePlanCounts[extinguishHash] + 1
            availablePlanCounts[craftHash] = availablePlanCounts[craftHash] + 1
            anyCampfireIsLit = true
        else
            availablePlanCounts[lightHash] = availablePlanCounts[lightHash] + 1
        end
    end

    local skillsArray = {
        skill.types.campfireCooking.index,
        skill.types.baking.index,
    }
    if not hasDiscoveredOneOfSkillsArray(tribeID, skillsArray) then
        availablePlanCounts[craftHash] = 0
        craftPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_missingKnowledge")
    end
    
    planHelper:addPlanExtraInfo(craftPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(lightPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(extinguishPlanInfo, queuedPlanInfos, availablePlanCounts)

    table.insert(plans, craftPlanInfo)
    table.insert(plans, lightPlanInfo)
    table.insert(plans, extinguishPlanInfo)

    
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    table.insert(plans, clonePlanInfo)
    
    local rebuildPlanInfo = planHelper:getRebuildPlanInfo(objectInfos, tribeID, anyCampfireIsLit, locale:get("ui_plan_unavailable_extinguishFirst"))
    table.insert(plans, rebuildPlanInfo)

    local deconstructionPlanInfo = planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, anyCampfireIsLit, locale:get("ui_plan_unavailable_extinguishFirst"))
    table.insert(plans, deconstructionPlanInfo)
    
    return plans
end


function planHelper:availablePlansForKilns(baseObject, objectInfos, tribeID)

    
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local plans = {}

    for hash, queuedInfo in pairs(queuedPlanInfos) do
        if queuedInfo.researchTypeIndex then
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = queuedInfo.researchTypeIndex,
                discoveryCraftableTypeIndex = queuedInfo.discoveryCraftableTypeIndex,
                hasQueuedPlans = true,
                anyQueuedPlansCanComplete = queuedInfo.canComplete,
                hasManuallyPrioritizedQueuedPlan = queuedInfo.hasManuallyPrioritizedPlan,
                hideUIOnCancel = true,
            }
            table.insert(plans, researchPlanInfo)
        end
    end

    local craftPlanInfo = {
        planTypeIndex = plan.types.craft.index,
    }
    local craftHash = planHelper:getPlanHash(craftPlanInfo)


    local lightPlanInfo = {
        planTypeIndex = plan.types.light.index,
        requirements = {
            skill = skill.types.fireLighting.index,
        },
    }
    local lightHash = planHelper:getPlanHash(lightPlanInfo)

    local extinguishPlanInfo = {
        planTypeIndex = plan.types.extinguish.index,
    }
    local extinguishHash = planHelper:getPlanHash(extinguishPlanInfo)
    
    local availablePlanCounts = {
        [craftHash] = 0,
        [lightHash] = 0,
        [extinguishHash] = 0,
    }
    
    local anyIsLit = false
    for i,objectInfo in ipairs(objectInfos) do
        local sharedState = objectInfo.sharedState
        if sharedState.isLit then
            availablePlanCounts[extinguishHash] = availablePlanCounts[extinguishHash] + 1
            availablePlanCounts[craftHash] = availablePlanCounts[craftHash] + 1
            anyIsLit = true
        else
            availablePlanCounts[lightHash] = availablePlanCounts[lightHash] + 1
        end
    end

    local skillsArray = {
        skill.types.potteryFiring.index,
        skill.types.blacksmithing.index,
    }
    if not hasDiscoveredOneOfSkillsArray(tribeID, skillsArray) then
        availablePlanCounts[craftHash] = 0
        craftPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_missingKnowledge")
    end
    
    planHelper:addPlanExtraInfo(craftPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(lightPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(extinguishPlanInfo, queuedPlanInfos, availablePlanCounts)

    table.insert(plans, craftPlanInfo)
    table.insert(plans, lightPlanInfo)
    table.insert(plans, extinguishPlanInfo)

    
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    table.insert(plans, clonePlanInfo)
    
    local rebuildPlanInfo = planHelper:getRebuildPlanInfo(objectInfos, tribeID, anyIsLit, locale:get("ui_plan_unavailable_extinguishFirst"))
    table.insert(plans, rebuildPlanInfo)

    local deconstructionPlanInfo = planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, anyIsLit, locale:get("ui_plan_unavailable_extinguishFirst"))
    table.insert(plans, deconstructionPlanInfo)
    
    return plans
end

function planHelper:availablePlansForTorches(baseObject, objectInfos, tribeID)

    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local lightPlanInfo = {
        planTypeIndex = plan.types.light.index,
        requirements = {
            skill = skill.types.fireLighting.index,
        },
    }
    local lightHash = planHelper:getPlanHash(lightPlanInfo)

    local extinguishPlanInfo = {
        planTypeIndex = plan.types.extinguish.index,
    }
    local extinguishHash = planHelper:getPlanHash(extinguishPlanInfo)
    
    local availablePlanCounts = {
        [lightHash] = 0,
        [extinguishHash] = 0,
    }
    
    
    local anyIsLit = false
    for i,objectInfo in ipairs(objectInfos) do
        local sharedState = objectInfo.sharedState
        if sharedState.isLit then
            anyIsLit = true
            availablePlanCounts[extinguishHash] = availablePlanCounts[extinguishHash] + 1
        else
            availablePlanCounts[lightHash] = availablePlanCounts[lightHash] + 1
        end
    end
    
    planHelper:addPlanExtraInfo(lightPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(extinguishPlanInfo, queuedPlanInfos, availablePlanCounts)

    local plans = {
        lightPlanInfo,
        extinguishPlanInfo
    }
    
    
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    table.insert(plans, clonePlanInfo)
    
    local rebuildPlanInfo = planHelper:getRebuildPlanInfo(objectInfos, tribeID, anyIsLit, locale:get("ui_plan_unavailable_extinguishFirst"))
    table.insert(plans, rebuildPlanInfo)
    
    local deconstructionPlanInfo = planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, anyIsLit, locale:get("ui_plan_unavailable_extinguishFirst"))
    table.insert(plans, deconstructionPlanInfo)
    
    return plans
end


function planHelper:availablePlansForMobObjects(baseObject, objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    local plans = {}

    local function addHuntPlan(planTypeIndex, researchTypeIndex, requiredToolTypeIndex)
        local requiredSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex

        local planInfo = nil
        
        if hasDiscoveredSkill(tribeID, requiredSkillTypeIndex) then
            planInfo = {
                planTypeIndex = planTypeIndex,
                requirements = {
                    toolTypeIndex = requiredToolTypeIndex,
                    skill = plan.types[planTypeIndex].requiredSkillTypeIndex,
                },
            }
        else
            planInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = researchTypeIndex,
            }
        end

        local availablePlanCounts = {
            [planHelper:getPlanHash(planInfo)] = #objectInfos
        }

        planHelper:updateForAnyMissingOrInProgressDiscoveries(planInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, #objectInfos)
        
       --[[ if queuedPlanInfos and next(queuedPlanInfos) then
            availablePlanCounts[planHelper:getPlanHash(planInfo)] = 0
            planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        else
            availablePlanCounts[planHelper:getPlanHash(planInfo)] = #objectInfos
        end]]

        planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)

        table.insert(plans, planInfo)
    end

    local preventRockThrowingHunting = false --used for fish
    
    local mobTypeIndex = gameObject.types[baseObject.objectTypeIndex].mobTypeIndex
    if mobTypeIndex then
        local mobType = mob.types[mobTypeIndex]
        preventRockThrowingHunting = mobType.preventRockThrowingHunting
    end

    if not preventRockThrowingHunting then
        addHuntPlan(plan.types.hunt.index, research.types.basicHunting.index, tool.types.weaponBasic.index)
    end
    addHuntPlan(plan.types.hunt_throwSpear.index, research.types.spearHunting.index, tool.types.weaponSpear.index)

    --mj:log("plans:", plans)
    
    return plans

end

function planHelper:availablePlansForObjectInfos(baseObjectOrVert, objectInfos, tribeID)
    if baseObjectOrVert and objectInfos and objectInfos[1] then
        local availablePlansFunction = planHelper.availablePlansFunctionsByObjectType[baseObjectOrVert.objectTypeIndex]
        if availablePlansFunction then
            return availablePlansFunction(planHelper, baseObjectOrVert, objectInfos, tribeID)
        end
    end

    return nil
end


function planHelper:availablePlansForVertInfos(baseObjectOrVert, vertInfos, tribeID)
    if not (vertInfos and baseObjectOrVert) then
        return nil
    end
    
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(vertInfos, tribeID, true)

    --mj:log("queuedPlanInfos:", queuedPlanInfos)

    local hasDigDiscovery = false
    local hasMineDiscovery = false
    local hasMulchingDiscovery = false
    local hasChiselStoneDiscovery = false
    if planHelper.completedSkillsByTribeID[tribeID] then
        if planHelper.completedSkillsByTribeID[tribeID][skill.types.digging.index] then
            hasDigDiscovery = true
            if planHelper.completedSkillsByTribeID[tribeID][skill.types.mulching.index] then
                hasMulchingDiscovery = true
            end
        end
        if planHelper.completedSkillsByTribeID[tribeID][skill.types.mining.index] then
            hasMineDiscovery = true
        end
        if planHelper.completedSkillsByTribeID[tribeID][skill.types.chiselStone.index] then
            hasChiselStoneDiscovery = true
        end
    end
    

    
    local clearPlanInfo = {
        planTypeIndex = plan.types.clear.index,
        requirements = {
            skill = skill.types.gathering.index,
        }
    }
    local clearHash = planHelper:getPlanHash(clearPlanInfo)

    local digPlanInfo = {
        planTypeIndex = plan.types.dig.index,
        requirements = {
            toolTypeIndex = tool.types.dig.index,
            skill = skill.types.digging.index,
        },
    }
    local digHash = planHelper:getPlanHash(digPlanInfo)

    local fillPlanInfo = {
        planTypeIndex = plan.types.fill.index,
        hasExtraOptionsPanel = true,
        requirements = {
            skill = skill.types.digging.index,
        }
    }
    local fillHash = planHelper:getPlanHash(fillPlanInfo)

    local fertilizePlanInfo = {
        planTypeIndex = plan.types.fertilize.index,
        --allowsObjectTypeSelection = true,
        requirements = {
            skill = skill.types.mulching.index,
        }
    }
    local fertilizeHash = planHelper:getPlanHash(fertilizePlanInfo)

    local minePlanInfo = {
        planTypeIndex = plan.types.mine.index,
        requirements = {
            toolTypeIndex = tool.types.mine.index,
            skill = skill.types.mining.index,
        },
    }
    local mineHash = planHelper:getPlanHash(minePlanInfo)

    local chiselPlanInfo = {
        planTypeIndex = plan.types.chiselStone.index,
        requirements = {
            --toolTypeIndex = chiselToolTypeIndex, --this is set later, doesn't affect the hash
            skill = skill.types.chiselStone.index,
        },
    }
    local chiselHash = planHelper:getPlanHash(chiselPlanInfo)

    
    local availablePlanCounts = {}
    local plans = {}
    
    local availableDiggableVertexCount = 0
    local availableMineableVertexCount = 0
    local availableSoftChiselableVertexCount = 0
    local availableHardChiselableVertexCount = 0
    local availableClearableVertexCount = 0
    local availableFertilizeableVertexCount = 0
    local availableGeneralVertCount = 0

    local foundDiggableVert = false
    local foundMineableVert = false
    local foundSoftChiselableVert = false
    local foundHardChiselableVert = false 
    --local foundClearableVert = false
    local foundFertilizeableVert = false 

   -- mj:log("vertInfos:", vertInfos)
        --mj:log("vert count:", #vertInfos)

    for i,vertInfo in ipairs(vertInfos) do
        --local thisVertQueuedInfos = planHelper:getQueuedPlanInfos({vertInfo}, tribeID, true)
        local available = true--(not (thisVertQueuedInfos and next(thisVertQueuedInfos)))
       -- mj:log("available:", available)

        if available then
            availableGeneralVertCount = availableGeneralVertCount + 1
        end

        --mj:log("vert info:", vertInfo)

        local variations = vertInfo.variations
        if variations then
            for terrainVariationTypeIndex,v in pairs(variations) do
                local terrainVariationType = terrainTypes.variations[terrainVariationTypeIndex]
                if terrainVariationType.canBeCleared then
                    --foundClearableVert = true
                    if available then
                        availableClearableVertexCount = availableClearableVertexCount + 1
                        --mj:log("clearable")
                    end
                    break
                end
            end
        end

        local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]
        if terrainBaseType.requiresMining then
            foundMineableVert = true
            if available then
                availableMineableVertexCount = availableMineableVertexCount + 1
            end
        else
            foundDiggableVert = true
            if available then
                availableDiggableVertexCount = availableDiggableVertexCount + 1
            end
        end

        --mj:log("terrainBaseType:", terrainBaseType)

        if terrainBaseType.chiselOutputs then
            if terrainBaseType.isSoftRock then
                foundSoftChiselableVert = true
                if available then
                    availableSoftChiselableVertexCount = availableSoftChiselableVertexCount + 1
                end
            else
                foundHardChiselableVert = true
                if available then
                    availableHardChiselableVertexCount = availableHardChiselableVertexCount + 1
                end
            end
        end

        if terrainBaseType.fertilizedTerrainTypeKey then
            foundFertilizeableVert = true
            if available then
                availableFertilizeableVertexCount = availableFertilizeableVertexCount + 1
            end
        end
    end
    
    local chiselToolTypeIndex = nil
    if foundSoftChiselableVert then
        chiselToolTypeIndex = tool.types.softChiselling.index
    else
        chiselToolTypeIndex = tool.types.hardChiselling.index
    end
    chiselPlanInfo.requirements.toolTypeIndex = chiselToolTypeIndex

    --planHelper:addPlanExtraInfo(clearPlanInfo, queuedPlanInfos, availablePlanCounts)

    availablePlanCounts[clearHash] = availableClearableVertexCount
    availablePlanCounts[digHash] = availableDiggableVertexCount
    availablePlanCounts[fillHash] = availableGeneralVertCount
    availablePlanCounts[fertilizeHash] = availableFertilizeableVertexCount
    availablePlanCounts[mineHash] = availableMineableVertexCount
    availablePlanCounts[chiselHash] = availableSoftChiselableVertexCount + availableHardChiselableVertexCount


    local function addUnavailableReason(vertexCount, hash, planInfo)
        if vertexCount > 0 and availablePlanCounts[hash] == 0 then
            planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
    end
    
    local function addDigResearchPlan()
        if foundDiggableVert then
            local researchType = research.types.digging
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = researchType.index,
            }
            planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, vertInfos, queuedPlanInfos, availablePlanCounts[digHash])
            availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = availableDiggableVertexCount
            planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
            table.insert(plans, researchPlanInfo)
        end
    end
    
    local function addMineResearchPlan()
        if foundMineableVert then
            local researchType = research.types.mining
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = researchType.index,
            }
            planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, vertInfos, queuedPlanInfos, availablePlanCounts[mineHash])
            availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = availableMineableVertexCount
            planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
            table.insert(plans, researchPlanInfo)
        end
    end
    
    local function addChiselResearchPlan()
        if foundSoftChiselableVert or foundHardChiselableVert then
            local hasRequirementsForVisiblity = false --this could be factored out if similar pattern needed again, but it's a special case for now
            if foundSoftChiselableVert then
                if hasDiscoveredSkill(tribeID, skill.types.rockKnapping.index) then --able to craft stone chisel
                    hasRequirementsForVisiblity = true
                end
            end
            if not hasRequirementsForVisiblity then
                if hasDiscoveredSkill(tribeID, skill.types.blacksmithing.index) then --able to craft bronze chisel
                    hasRequirementsForVisiblity = true
                end
            end
            if hasRequirementsForVisiblity then
                local researchType = research.types.chiselStone
                local researchPlanInfo = {
                    planTypeIndex = plan.types.research.index,
                    researchTypeIndex = researchType.index,
                    requirements = {
                        toolTypeIndex = chiselToolTypeIndex,
                        skill = skill.types.researching.index,
                    },
                }
                planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, vertInfos, queuedPlanInfos, availablePlanCounts[chiselHash])
                if foundSoftChiselableVert then
                    availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = availableSoftChiselableVertexCount
                else
                    availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] = availableHardChiselableVertexCount
                end

                if availablePlanCounts[planHelper:getPlanHash(researchPlanInfo)] == 0 then
                    researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                end
                planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
                table.insert(plans, researchPlanInfo)
            end
        end
    end
    
    
    local function addMulchingResearchPlanIfInProgress()
        if queuedPlanInfos then
            local researchType = research.types.mulching
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index,
                researchTypeIndex = researchType.index,
            }
            local researchPlanHash = planHelper:getPlanHash(researchPlanInfo)
            if queuedPlanInfos[researchPlanHash] and queuedPlanInfos[researchPlanHash].count > 0 then

                availablePlanCounts[researchPlanHash] = queuedPlanInfos[researchPlanHash].count
                researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                
                planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
                table.insert(plans, researchPlanInfo)
            end
        end
    end

    --if foundClearableVert then
        table.insert(plans, clearPlanInfo)
    --end

    if hasDigDiscovery then
        table.insert(plans, fillPlanInfo)
        if foundDiggableVert then
            table.insert(plans, digPlanInfo)
        end
    else
        addDigResearchPlan()
    end

    if hasMineDiscovery then
        if foundMineableVert then
            table.insert(plans, minePlanInfo)
        end
    else
        addMineResearchPlan()
    end

    if hasChiselStoneDiscovery then
        if foundSoftChiselableVert or foundHardChiselableVert then
            table.insert(plans, chiselPlanInfo)
        end
    else
        addChiselResearchPlan()
    end
    
    if hasMulchingDiscovery then
        if foundFertilizeableVert then
            table.insert(plans, fertilizePlanInfo)
        end
    else
        addMulchingResearchPlanIfInProgress()
    end

   -- mj:log("minePlanInfo:", minePlanInfo, " queuedPlanInfos:", queuedPlanInfos, " availablePlanCounts:", availablePlanCounts)

    
    planHelper:addPlanExtraInfo(clearPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(digPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(fillPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(minePlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(chiselPlanInfo, queuedPlanInfos, availablePlanCounts)
    planHelper:addPlanExtraInfo(fertilizePlanInfo, queuedPlanInfos, availablePlanCounts)

    addUnavailableReason(availableClearableVertexCount, clearHash, clearPlanInfo)
    addUnavailableReason(availableDiggableVertexCount, digHash, digPlanInfo)
    addUnavailableReason(availableGeneralVertCount, fillHash, fillPlanInfo)
    addUnavailableReason(availableFertilizeableVertexCount, fertilizeHash, fertilizePlanInfo)
    addUnavailableReason(availableMineableVertexCount, mineHash, minePlanInfo)
    addUnavailableReason(availableSoftChiselableVertexCount + availableHardChiselableVertexCount, chiselHash, chiselPlanInfo)

    --mj:log("clearPlanInfo:", clearPlanInfo)

    local function addDefensePlan(planTypeIndex, requiredSkillTypeIndex, requiredToolTypeIndexOrNil, researchTypeIndexOrNil)
        local planGroupTypeIndex = plan.types.defend.index
        --local isAttackPlan = plan.types[planTypeIndex].isAttackPlan
        
        local requiresResearch = false
        if researchTypeIndexOrNil and requiredSkillTypeIndex and (not hasDiscoveredSkill(tribeID, requiredSkillTypeIndex)) then
            requiresResearch = true
            planTypeIndex = plan.types.research.index
            requiredSkillTypeIndex = skill.types.researching.index
        end

        local planInfo = {
            planTypeIndex = planTypeIndex,
            planGroupTypeIndex = planGroupTypeIndex,
            requirements = {
                skill = requiredSkillTypeIndex,
                toolTypeIndex = requiredToolTypeIndexOrNil,
            },
        }

        if requiresResearch then
            availablePlanCounts[planHelper:getPlanHash(planInfo)] = 0
        else
            availablePlanCounts[planHelper:getPlanHash(planInfo)] = #vertInfos
        end

        planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)

        table.insert(plans, planInfo)
        return planInfo
    end

    addDefensePlan(plan.types.defend_handToHand.index, skill.types.handToHandCombat.index, nil, nil)
    addDefensePlan(plan.types.defend_throwRock.index, skill.types.basicHunting.index, tool.types.weaponBasic.index, research.types.basicHunting.index)
    addDefensePlan(plan.types.defend_throwSpear.index, skill.types.spearHunting.index, tool.types.weaponSpear.index, research.types.spearHunting.index)

    return plans
end


--[[
local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local firstObjectSharedState = baseObject.sharedState
    local sapienTribeID = firstObjectSharedState.tribeID

    local plans = {}

    local ableSapienCount = 0
    local totalSapienCount = #objectInfos

    for i,objectInfo in ipairs(objectInfos) do
        if not sapienConstants:getHasLimitedGeneralAbility(objectInfo.sharedState, false) then
            ableSapienCount = ableSapienCount + 1
        end
    end

    local function addPlan(planTypeIndex, planGroupTypeIndexOrNil, requiredSkillTypeIndexOrNilForDiplomacy, requiredToolTypeIndexOrNil, researchTypeIndexOrNil)

        local researchTypeIndex = nil
        local planGroupTypeIndex = planGroupTypeIndexOrNil
        local isAttackPlan = plan.types[planTypeIndex].isAttackPlan
        
        if researchTypeIndexOrNil and requiredSkillTypeIndexOrNilForDiplomacy and (not hasDiscoveredSkill(tribeID, requiredSkillTypeIndexOrNilForDiplomacy)) then
            planTypeIndex = plan.types.research.index
            researchTypeIndex = researchTypeIndexOrNil
            requiredSkillTypeIndexOrNilForDiplomacy = skill.types.researching.index
            isAttackPlan = research.types[researchTypeIndex].isAttackPlan
        end

        local planInfo = {
            planTypeIndex = planTypeIndex,
            researchTypeIndex = researchTypeIndex,
            planGroupTypeIndex = planGroupTypeIndex,
            requirements = {
                skill = requiredSkillTypeIndexOrNilForDiplomacy or skill.types.diplomacy.index,
                toolTypeIndex = requiredToolTypeIndexOrNil,
            },
        }
        
        local available = true

        if planTypeIndex == plan.types.recruit.index or planTypeIndex == plan.types.banish.index then
            local hasTimeout = planHelper:getHasDiplomacyFailTimeout(baseObject)
            if hasTimeout then
                available = false
                planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_recruitBanishTimeout")
            else
                if planTypeIndex == plan.types.recruit.index then
                    local recruitChanceOffset = planHelper:getRecruitChanceOffset(baseObject, tribeID)
                    if recruitChanceOffset <= -2 then
                        available = false --todo if mastered, allow
                    end
                    planInfo.recruitChanceOffset = recruitChanceOffset
                elseif planTypeIndex == plan.types.banish.index then
                    local banishChanceOffset = planHelper:getBanishChanceOffset(baseObject, tribeID)
                    if banishChanceOffset <= -2 then
                        available = false --todo if mastered, allow
                    end
                    planInfo.banishChanceOffset = banishChanceOffset
                    planInfo.isDestructiveOverride = false --note we also need a hack in clientGOM updatePlanObject for the order markers to be correct
                end
            end
        end

        local count = 0
        if available then
            if isAttackPlan then
                count = ableSapienCount
            else
                count = totalSapienCount
            end
        end

        local availablePlanCounts = {
            [planHelper:getPlanHash(planInfo)] = count
        }

        if researchTypeIndex then
            planHelper:updateForAnyMissingOrInProgressDiscoveries(planInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, count)
        end


        planHelper:addPlanExtraInfo(planInfo, queuedPlanInfos, availablePlanCounts)

        table.insert(plans, planInfo)
        return planInfo
    end

    local function addAttackPlans()
        --todo this maybe only enabled if below dimplomatic threshold?
        addPlan(plan.types.attack_handToHand.index, plan.types.attack.index, skill.types.handToHandCombat.index, nil, nil)
        addPlan(plan.types.attack_throwRock.index, plan.types.attack.index, skill.types.basicHunting.index, tool.types.weaponBasic.index, research.types.basicHunting.index)
        addPlan(plan.types.attack_throwSpear.index, plan.types.attack.index, skill.types.spearHunting.index, tool.types.weaponSpear.index, research.types.spearHunting.index)
    end
    
    if firstObjectSharedState.nomad then
        addPlan(plan.types.recruit.index)
        addPlan(plan.types.banish.index)
        addAttackPlans()
    else
        local destinationState = planHelper.destinationsByID[sapienTribeID]
        if destinationState and (destinationState.relationships and destinationState.relationships[tribeID]) then
            addPlan(plan.types.manageTribeRelations.index)
            addPlan(plan.types.recruit.index)
            addPlan(plan.types.banish.index)
            
            addAttackPlans()
        else
            addPlan(plan.types.greet.index)
            addPlan(plan.types.recruit.index)
            addPlan(plan.types.banish.index)

            addAttackPlans()
        end
    end

    --mj:log("plans:", plans)
    
    return plans
]]

local function tribeIsValidOwner(tribeID)
    if world then
        return world:tribeIsValidOwner(tribeID)
    end
    return serverWorld:tribeIsValidOwner(tribeID)
end

local function getTribeRelationsSettings(objectTribeID, sapienTribeID)
    if world then
        return world:getOrCreateTribeRelationsSettings(objectTribeID)
    end
    return serverWorld:getTribeRelationsSettings(objectTribeID, sapienTribeID)
end

local function getAllowStorageAreaItemUse(storageAreaObject, tribeID)
    --mj:log("getAllowUseValue:", objectTribeSettings)
    local objectTribeSettings = storageAreaObject.sharedState.settingsByTribe[tribeID]
    if (objectTribeSettings and objectTribeSettings.disallowItemUse ~= nil) then
        return (not objectTribeSettings.disallowItemUse)
    end

    if tribeID == storageAreaObject.sharedState.tribeID or (not tribeIsValidOwner(storageAreaObject.sharedState.tribeID)) then
        --mj:log("b:true:", world:tribeIsValidOwner(storageAreaObject.sharedState.tribeID))
        return true
    end

    local globalTribeSettings = getTribeRelationsSettings(storageAreaObject.sharedState.tribeID, tribeID)
    --mj:log("globalTribeSettings:", globalTribeSettings)
    if globalTribeSettings and globalTribeSettings.storageAlly then
        --mj:log("c:true")
        return true
    end

    --mj:log("d:false")
    return false
end


--[[
--TODO -- ??? what is this relic
local function getTreatAsThreatSetting(potentialThreatSapien, threatenedTribeID)
    --mj:log("getAllowUseValue:", objectTribeSettings)

    if threatenedTribeID == potentialThreatSapien.sharedState.tribeID or (not tribeIsValidOwner(storageAreaObject.sharedState.tribeID)) then
        --mj:log("b:true:", world:tribeIsValidOwner(storageAreaObject.sharedState.tribeID))
        return true
    end

    local globalTribeSettings = getTribeRelationsSettings(storageAreaObject.sharedState.tribeID, threatenedTribeID)
    --mj:log("globalTribeSettings:", globalTribeSettings)
    if globalTribeSettings and globalTribeSettings.storageAlly then
        --mj:log("c:true")
        return true
    end

    --mj:log("d:false")
    return false
end
]]

function planHelper:availablePlansForStorageAreas(baseObject, objectInfos, tribeID)
    --mj:log("availablePlansForStorageAreas objectInfos:", objectInfos)

    

    local availablePlanCounts = {}
    local foundStorageAllowUseSetting = getAllowStorageAreaItemUse(baseObject, tribeID)

    local function checkForAllowedUse(thisHash, thisPlanInfo)
        if not foundStorageAllowUseSetting then
            availablePlanCounts[thisHash] = 0
            thisPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_tribeSettingsDontAllowUse")
            thisPlanInfo.hasNonQueuedAvailable = false
            return false
        end
        return true
    end
    
    local isMultiSelect = #objectInfos > 1
    
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local deconstructionPlanInfo = planHelper:getDeconstructionPlanInfo(objectInfos, tribeID, false, nil)
    local deconstructionPlanHash = planHelper:getPlanHash(deconstructionPlanInfo)
    checkForAllowedUse(deconstructionPlanHash, deconstructionPlanInfo)

    local hasDeconstructPlanQueued = queuedPlanInfos[deconstructionPlanHash] ~= nil
    
    local manageStoragePlanInfo = {
        planTypeIndex = plan.types.manageStorage.index,
    }
    local manageHash = planHelper:getPlanHash(manageStoragePlanInfo)
    availablePlanCounts[manageHash] = #objectInfos
    
    if isMultiSelect or hasDeconstructPlanQueued then
        availablePlanCounts[manageHash] = 0
        
        if hasDeconstructPlanQueued then
            manageStoragePlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        elseif isMultiSelect then
            manageStoragePlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_multiSelect")
        end
    end

    planHelper:addPlanExtraInfo(manageStoragePlanInfo, queuedPlanInfos, availablePlanCounts)

    local plans = {
        manageStoragePlanInfo,
    }

    local firstObjectType = gameObject.types[baseObject.objectTypeIndex]
    if firstObjectType.isMoveableStorage then
        local haulObjectPlanInfo = {
            planTypeIndex = plan.types.haulObject.index,
            --[[requirements = {
                skill = musicalInstrumentSkillTypeIndex, --todo hauling skill?
            },]]
        }
        table.insert(plans, haulObjectPlanInfo)
        availablePlanCounts[planHelper:getPlanHash(haulObjectPlanInfo)] = #objectInfos
        planHelper:addPlanExtraInfo(haulObjectPlanInfo, queuedPlanInfos, availablePlanCounts)
    end

   --[[ if baseObject.sharedState.tribeID ~= tribeID then
        local takePlanInfo = {
            planTypeIndex = plan.types.take.index,
        }
        table.insert(plans, takePlanInfo)
        local hash = planHelper:getPlanHash(takePlanInfo)
        availablePlanCounts[hash] = #objectInfos
        checkForAllowedUse(hash, takePlanInfo)
        planHelper:addPlanExtraInfo(takePlanInfo, queuedPlanInfos, availablePlanCounts)
    end]]

    --[[local startRoutePlanInfo = {
        planTypeIndex = plan.types.startRoute.index,
    }
    table.insert(plans, startRoutePlanInfo)
    local hash = planHelper:getPlanHash(startRoutePlanInfo)
    availablePlanCounts[hash] = #objectInfos
    planHelper:addPlanExtraInfo(startRoutePlanInfo, queuedPlanInfos, availablePlanCounts)]]
    
    local constructWithPlanInfo = {
        planTypeIndex = plan.types.constructWith.index,
    }
    local constructWithHash = planHelper:getPlanHash(constructWithPlanInfo)
    availablePlanCounts[constructWithHash] = 0

    local researchPlanInfos = {}
    local musicalInstrumentSkillTypeIndex = nil

    if (not isMultiSelect) and (not hasDeconstructPlanQueued) then
        local sharedState = baseObject.sharedState
        local inventory = sharedState.inventory
        local resourceTypeIndexes = {}
        local hasConstructable = false
        if inventory and inventory.countsByObjectType then
            for objectTypeIndex,count in pairs(inventory.countsByObjectType) do
                if count > 0 then
                    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                    resourceTypeIndexes[resourceTypeIndex] = true
                    if constructable.constructablesByResourceObjectTypeIndexes[objectTypeIndex] then
                        hasConstructable = true
                    end
                end
            end
        end
    
        if hasConstructable then
            availablePlanCounts[constructWithHash] = #objectInfos
        end

        if next(resourceTypeIndexes) then
            local consolidatedResearchTypes = {}
            
            for resourceTypeIndex, tf in pairs(resourceTypeIndexes) do
                local researchTypes = research.researchTypesByResourceType[resourceTypeIndex]
                if researchTypes then
                    for i, researchType in ipairs(researchTypes) do
                        local complete = planHelper.discoveriesByTribeID[tribeID] and planHelper.discoveriesByTribeID[tribeID][researchType.index] and planHelper.discoveriesByTribeID[tribeID][researchType.index].complete
                        local discoveryCraftableTypeIndex = research:getIncompleteDiscoveryCraftableTypeIndexForResearchAndResourceType(researchType.index, resourceTypeIndex, planHelper.craftableDiscoveriesByTribeID[tribeID], complete)
                        local discoveryCraftableTypes = consolidatedResearchTypes[researchType.index]
                        if not discoveryCraftableTypes then
                            discoveryCraftableTypes = {}
                            consolidatedResearchTypes[researchType.index] = discoveryCraftableTypes
                        end
                        
                        if discoveryCraftableTypeIndex then
                            discoveryCraftableTypes[discoveryCraftableTypeIndex] = true
                        end
                    end
                end
                local resourceType = resource.types[resourceTypeIndex]
                if resourceType.musicalInstrumentSkillTypeIndex then
                    musicalInstrumentSkillTypeIndex = resourceType.musicalInstrumentSkillTypeIndex
                end
            end
    
            if next(consolidatedResearchTypes) then
                --local availableResearchPlanCounts = {}
            
                for researchTypeIndex, discoveryCraftableTypes in pairs(consolidatedResearchTypes) do
                    local researchType = research.types[researchTypeIndex]
                    local complete = false
                    if planHelper.discoveriesByTribeID[tribeID] and planHelper.discoveriesByTribeID[tribeID][researchType.index] then
                        complete = planHelper.discoveriesByTribeID[tribeID][researchType.index].complete
                    end
                    
                    local discoveryCraftableTypeIndex = nil
                    if complete and next(discoveryCraftableTypes) then
                        discoveryCraftableTypeIndex = next(discoveryCraftableTypes)
                        complete = false
                    end

                    --mj:log("researchType:", researchType, " discoveryCraftableTypeIndex:", discoveryCraftableTypeIndex)

                    if not complete then
                        --if not planHelper:requiredDiscoveryForResearchPlanIfMissing(tribeID, researchType.index) then
                            local researchPlanInfo = {
                                planTypeIndex = plan.types.research.index,
                                researchTypeIndex = researchType.index,
                                discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
                            }
                            local researchPlanHash = planHelper:getPlanHash(researchPlanInfo)
                            planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, objectInfos, queuedPlanInfos, #objectInfos)
                            --mj:log("thisResearchPlanInfo:", thisResearchPlanInfo)
                            --availablePlanCounts[researchPlanHash] = #objectInfos

                            local canCompleteResearch = (not researchPlanInfo.unavailableReasonText)
                            
                            availablePlanCounts[researchPlanHash] = 1
                            if queuedPlanInfos[researchPlanHash] or (not canCompleteResearch) then
                                availablePlanCounts[researchPlanHash] = 0
                                constructWithPlanInfo.hasQueuedPlans = false
                            end
                            
                            planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
                            table.insert(researchPlanInfos, researchPlanInfo)
                                

                       -- end
                    end
                end
            end
        end
        
        for queuedPlanHash, queuedPlanInfo in pairs(queuedPlanInfos) do
            if queuedPlanInfo.planTypeIndex ~= plan.types.deconstruct.index then
                if queuedPlanInfo.planTypeIndex == plan.types.playInstrument.index then
                    availablePlanCounts[constructWithHash] = 0
                    constructWithPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
               -- elseif queuedPlanInfo.planTypeIndex ~= plan.types.haulObject.index and 
                --queuedPlanInfo.planTypeIndex ~= plan.types.research.index then --this causes bugs all the time, it's trying to allow for both craft and build orders I think? But it has hit haul and research by accident now

                -- first try commenting it out, otherwise below maybe
                --[[elseif queuedPlanInfo.planTypeIndex == plan.types.constructWith.index then --lets try this instead?
                    constructWithPlanInfo = {
                        planTypeIndex = queuedPlanInfo.planTypeIndex,
                        hasQueuedPlans = true,
                    }
                    constructWithHash = planHelper:getPlanHash(constructWithPlanInfo)
                    availablePlanCounts[constructWithHash] = 0]]
                end
            end
        end

    else
        if hasDeconstructPlanQueued then
            constructWithPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        elseif isMultiSelect then
            constructWithPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_multiSelect")
        end
    end
    
    planHelper:addPlanExtraInfo(constructWithPlanInfo, queuedPlanInfos, availablePlanCounts)
    table.insert(plans, constructWithPlanInfo)

    

    
    if musicalInstrumentSkillTypeIndex then
        local playPlanInfo = planHelper:getPlayMusicalInstrumentPlanInfo(objectInfos, tribeID, musicalInstrumentSkillTypeIndex) --if this ever doesn't return plan.types.playInstrument.index then above check fails
        if playPlanInfo then
            local playPlanInfoHash = planHelper:getPlanHash(playPlanInfo)
            checkForAllowedUse(playPlanInfoHash, playPlanInfo)
            table.insert(plans, playPlanInfo)
        end
    end

    for i,researchPlanInfo in ipairs(researchPlanInfos) do
        local researchPlanHash = planHelper:getPlanHash(researchPlanInfo)
        checkForAllowedUse(researchPlanHash, researchPlanInfo)
        table.insert(plans, researchPlanInfo)
    end

    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    table.insert(plans, clonePlanInfo)

    --todo this needs to be supported, but we need to add automatic empty orders, fix the bug where sleds vanish, and don't pull apart stuff if it matches the new stuff, so a cover can be added or removed without replacing the planks
   --[[ local constructableType = constructable.types[baseObject.sharedState.constructionConstructableTypeIndex]
    if constructableType and constructableType.rebuildGroupIndex then
        local rebuildPlanInfo = planHelper:getRebuildPlanInfo(objectInfos, tribeID, false)
        table.insert(plans, rebuildPlanInfo)
    end]]
    
    table.insert(plans, deconstructionPlanInfo)

   --[[ for queuedPlanHash, queuedPlanInfo in pairs(queuedPlanInfos) do
        local found = false
        for i, addedPlanInfo in ipairs(plans) do
            if addedPlanInfo.planTypeIndex == queuedPlanTypeIndex then
                found = true
                break
            end
        end
        if not found then
            table.insert(plans, 2, {
                planTypeIndex = queuedPlanTypeIndex,
                hasQueuedPlans = true,
            })
        end
    end]]
    
    --mj:log("queuedPlanInfos:", queuedPlanInfos, "\n\nplans:", plans)
    
    return plans
end

function planHelper:availablePlansForInProgressBuildObjects(baseObject, objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)
    
    local firstObjectInProgressConstructableTypeIndex = baseObject.sharedState.inProgressConstructableTypeIndex
    local constuctableType = constructable.types[firstObjectInProgressConstructableTypeIndex]
    if not constuctableType then
        mj:error("not constuctableType objectInfos:", objectInfos)
        return nil
    end
    
    if queuedPlanInfos then
        for queuedHash,queuedInfo in pairs(queuedPlanInfos) do
            --mj:log("queuedInfo:", queuedInfo)
            if queuedInfo.planTypeIndex == plan.types.research.index then
                local plans = {
                    {
                        planTypeIndex = queuedInfo.planTypeIndex,
                        researchTypeIndex = queuedInfo.researchTypeIndex,
                        discoveryCraftableTypeIndex = queuedInfo.discoveryCraftableTypeIndex,
                        hasQueuedPlans = true,
                        anyQueuedPlansCanComplete = queuedInfo.canComplete,
                        hasManuallyPrioritizedQueuedPlan = queuedInfo.hasManuallyPrioritizedPlan,
                        hideUIOnCancel = true,
                    }
                }
                return plans
            end
        end
    end

    local buildPlanTypeIndex = constuctableType.planTypeIndex or plan.types.build.index
    
    local buildPlanInfo = {
        planTypeIndex = buildPlanTypeIndex,
    }
    
    local deconstructPlanInfo = {
        planTypeIndex = plan.types.deconstruct.index,
    }

    local buildHash = planHelper:getPlanHash(buildPlanInfo)
    local deconstructHash = planHelper:getPlanHash(deconstructPlanInfo)
    
   -- mj:log("buildHash:", buildHash)
   -- mj:log("objectInfos:", objectInfos)
    --mj:log("queuedPlanInfos:", queuedPlanInfos)

    local rebuildPlanInfo = nil
    local availablePlanCounts = {}
    local rebuildCount = 0
    if constuctableType.rebuildGroupIndex then
        rebuildPlanInfo = {
            planTypeIndex = plan.types.rebuild.index,
        }
        local rebuildHash = planHelper:getPlanHash(rebuildPlanInfo)
        if queuedPlanInfos[rebuildHash] then
            rebuildCount = queuedPlanInfos[rebuildHash].count
        end
        availablePlanCounts[rebuildHash] = #objectInfos
    end

    local availableToBuildAndRemoveCount = #objectInfos - rebuildCount
    --mj:log("rebuildCount:", rebuildCount, " availableToBuildAndRemoveCount:", availableToBuildAndRemoveCount, " plan.types.rebuild.index:", plan.types.rebuild.index)

    availablePlanCounts[buildHash] = availableToBuildAndRemoveCount
    availablePlanCounts[deconstructHash] = availableToBuildAndRemoveCount

    --if next(queuedPlanInfos) then --don't allow deconstruct if any other plans are queued
    --    availablePlanCounts[deconstructHash] = 0
    --end
    --if queuedPlanInfos[deconstructHash] then
    --    availablePlanCounts[buildHash] = 0
    --end

    planHelper:addPlanExtraInfo(buildPlanInfo, queuedPlanInfos, availablePlanCounts)
    if rebuildPlanInfo then
        planHelper:addPlanExtraInfo(rebuildPlanInfo, queuedPlanInfos, availablePlanCounts)
    end
    planHelper:addPlanExtraInfo(deconstructPlanInfo, queuedPlanInfos, availablePlanCounts)
    

    if availableToBuildAndRemoveCount == 0 then
        buildPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        deconstructPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
    end
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)

    local plans = {
        buildPlanInfo,
        clonePlanInfo,
    }
    
    if rebuildPlanInfo then
        table.insert(plans, rebuildPlanInfo)
    end
    table.insert(plans, deconstructPlanInfo)

    return plans
end

function planHelper:availablePlansForPlacedObjects(baseObject, objectInfos, tribeID)
    local queuedPlanInfos = planHelper:getQueuedPlanInfos(objectInfos, tribeID, false)

    local allowUsePlanInfo = {
        planTypeIndex = plan.types.allowUse.index,
    }
    local hash = planHelper:getPlanHash(allowUsePlanInfo)
    local availablePlanCounts = {
        [hash] = #objectInfos
    }

    planHelper:addPlanExtraInfo(allowUsePlanInfo, queuedPlanInfos, availablePlanCounts)

    local plans = {
        allowUsePlanInfo,
    }
    
    
    local clonePlanInfo = planHelper:getClonePlanInfo(objectInfos, tribeID)
    table.insert(plans, clonePlanInfo)
    
    return plans
end

function planHelper:init(world_, serverWorld_)
    world = world_ --only on main thread
    serverWorld = serverWorld_ --only on server

    for i,gameObjectTypeIndex in ipairs(gameObject.floraTypes) do
        planHelper.availablePlansFunctionsByObjectType[gameObjectTypeIndex] = planHelper.availablePlansForFloraObjects
    end

    planHelper.availablePlansFunctionsByObjectType[gameObject.types.sapien.index] = planHelper.availablePlansForSapiens
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.campfire.index] = planHelper.availablePlansForCampfires
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.brickKiln.index] = planHelper.availablePlansForKilns
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.torch.index] = planHelper.availablePlansForTorches
    
    for i,gameObjectTypeIndex in ipairs(gameObject.storageAreaTypes) do
        planHelper.availablePlansFunctionsByObjectType[gameObjectTypeIndex] = planHelper.availablePlansForStorageAreas
    end
    
    for i,mobGameObjectTypeIndex in ipairs(mob.gameObjectIndexes) do
        planHelper.availablePlansFunctionsByObjectType[mobGameObjectTypeIndex] = planHelper.availablePlansForMobObjects
    end

    for i,gameObjectTypeIndex in ipairs(gameObject.inProgressBuildObjectTypes) do
        planHelper.availablePlansFunctionsByObjectType[gameObjectTypeIndex] = planHelper.availablePlansForInProgressBuildObjects
    end

    for i,gameObjectTypeIndex in ipairs(gameObject.placedObjectTypes) do
        planHelper.availablePlansFunctionsByObjectType[gameObjectTypeIndex] = planHelper.availablePlansForPlacedObjects
    end
    

    
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.craftArea.index] = planHelper.availablePlansForCraftArea


    planHelper.availablePlansFunctionsByObjectType[gameObject.types.temporaryCraftArea.index] = planHelper.availablePlansForTemporaryCraftArea
    

    for i,gameObjectTypeIndex in ipairs(gameObject.builtObjectTypes) do
        if not planHelper.availablePlansFunctionsByObjectType[gameObjectTypeIndex] then
            planHelper.availablePlansFunctionsByObjectType[gameObjectTypeIndex] = planHelper.availablePlansForGenericBuiltObjects
        end
    end

    
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.deadMammoth.index] = planHelper.availablePlansForNonResourceCarcass
    
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.rockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.limestoneRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.redRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.sandstoneYellowRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.sandstoneRedRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.sandstoneOrangeRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.sandstoneBlueRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.greenRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.graniteRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.marbleRockLarge.index] = planHelper.availablePlansForMineableObjects
    planHelper.availablePlansFunctionsByObjectType[gameObject.types.lapisRockLarge.index] = planHelper.availablePlansForMineableObjects

    --availablePlansFunctionsByObjectType[gameObject.types.deadChicken.index] = availablePlansForCarcass

    --[[for i,resourceTypeIndex in ipairs(flora.seedResourceTypeIndexes) do
        if not researchByResourceTypes[resourceTypeIndex] then -- let
            researchByResourceTypes[resourceTypeIndex] = { plantingResearch }
        else
            table.insert(researchByResourceTypes[resourceTypeIndex], plantingResearch)
        end
    end]]
    

    for k,v in pairs(gameObject.typeIndexMap) do
        local gameObjectType = gameObject.types[v]
        if gameObjectType then
            if gameObjectType.resourceTypeIndex then
                planHelper.availablePlansFunctionsByObjectType[v] = planHelper.availablePlansForResourceObjects
            end
        end
    end

end

function planHelper:getCraftableDiscoveriesForTribeID(tribeID)
    return planHelper.craftableDiscoveriesByTribeID[tribeID]
end

return planHelper