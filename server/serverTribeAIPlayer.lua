
local mjm = mjrequire "common/mjm"
local reverseLinearInterpolate = mjm.reverseLinearInterpolate
local length2 = mjm.length2

local rng = mjrequire "common/randomNumberGenerator"
local plan = mjrequire "common/plan"
local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local grievance = mjrequire "common/grievance"
local notification = mjrequire "common/notification"
local gameConstants = mjrequire "common/gameConstants"
local quest = mjrequire "common/quest"
local craftAreaGroup = mjrequire "common/craftAreaGroup"
local destination = mjrequire "common/destination"
local skill = mjrequire "common/skill"
--local storage = mjrequire "common/storage"
local constructable = mjrequire "common/constructable"
local industry = mjrequire "common/industry"
local planHelper = mjrequire "common/planHelper"
--local storage = mjrequire "common/storage"

local serverStorageArea = mjrequire "server/serverStorageArea"
local planManager = mjrequire "server/planManager"
local terrain = mjrequire "server/serverTerrain"

local storageAreasBlueprint = mjrequire "server/blueprints/storageAreas"
local serverResourceManager = mjrequire "server/serverResourceManager"
--local serverDestinationBuilder = mjrequire "server/serverDestinationBuilder"

local serverWorld = nil
local serverGOM = nil
local serverTribe = nil
local serverDestination = nil
local serverDestinationBuilder = nil
local serverCraftArea = nil
--local planManager = nil

local gatherMaxCount = 8
local maxClearPlans = 32
local lightMaxCount = 4

local serverTribeAIPlayer = {}

local aiTribes = {}

local function isLoaded(destinationState)
    local currentState = destinationState.loadState or destination.loadStates.seed
    return currentState == destination.loadStates.loaded
end


local function checkMaxPlansAdded(destinationID, planTypeIndex, maxCount)
    local foundTotalCount = 0
    local orderedPlans = planManager.orderedPlansByTribeID[destinationID]
    if orderedPlans then
        for i, orderedPlan in ipairs(orderedPlans) do
            if orderedPlan.planTypeIndex == planTypeIndex then
                foundTotalCount = foundTotalCount + 1
                if foundTotalCount >= maxCount then
                    return true
                end
            end
        end
    end
    return false
end

local function findStorageAreaForObjectType(destinationState, objectTypeIndex, optionsOrNil)
    local matchInfo = serverStorageArea:bestStorageAreaForObjectType(destinationState.destinationID, objectTypeIndex, nil, optionsOrNil)

    if not matchInfo then
        serverDestinationBuilder:loadBlueprint(destinationState, nil, storageAreasBlueprint, nil)
        matchInfo = serverStorageArea:bestStorageAreaForObjectType(destinationState.destinationID, objectTypeIndex, nil, optionsOrNil)
    end
    return matchInfo
end

local function findStorageAreaForResourceType(destinationState, resourceTypeIndex, optionsOrNil)
    local matchInfo = serverStorageArea:bestStorageAreaForObjectType(destinationState.destinationID, resource.types[resourceTypeIndex].displayGameObjectTypeIndex, nil, optionsOrNil)

    if not matchInfo then
        serverDestinationBuilder:loadBlueprint(destinationState, nil, storageAreasBlueprint, nil)
        matchInfo = serverStorageArea:bestStorageAreaForObjectType(destinationState.destinationID, resource.types[resourceTypeIndex].displayGameObjectTypeIndex, nil, optionsOrNil)
    end
    return matchInfo
end

local function addGatherOrder(destinationID, aiTribeInfo, gatherSetIndex, isDesiredObjectTypeFunction)
    local radius = math.min((aiTribeInfo.gatherSearchRadius or 0.0) + mj:mToP(20.0), mj:mToP(200.0))
    aiTribeInfo.gatherSearchRadius = radius
    serverGOM:callFunctionForRandomSapienInTribe(destinationID, function(sapien)
        --mj:log("callFunctionForRandomSapienInTribe:", sapien.uniqueID)
        local closeGatherableFood = serverGOM:getGameObjectsInSetWithinRadiusOfPos(gatherSetIndex, sapien.pos, radius)
        --mj:log("closeGatherableFood:", closeGatherableFood)
        if closeGatherableFood and #closeGatherableFood > 0 then
            local randomInfo = closeGatherableFood[rng:randomInteger(#closeGatherableFood) + 1]
            local gatherObjectTypeIndex = nil
            local object = serverGOM:getObjectWithID(randomInfo.objectID)
            local sharedState = object.sharedState
            local inventory = sharedState.inventory
            if inventory then
                local countsByObjectType = inventory.countsByObjectType
                if countsByObjectType then
                    local gatherableTypes = gameObject.types[object.objectTypeIndex].gatherableTypes
                    if gatherableTypes then
                        for j,objectTypeIndex in ipairs(gatherableTypes) do
                            if countsByObjectType[objectTypeIndex] and countsByObjectType[objectTypeIndex] > 0 then
                                if isDesiredObjectTypeFunction(objectTypeIndex) then
                                    gatherObjectTypeIndex = objectTypeIndex
                                    break
                                end
                            end
                        end
                    end
                end
            end
            --mj:log("gatherObjectTypeIndex:", gatherObjectTypeIndex)
            if gatherObjectTypeIndex then
                aiTribeInfo.gatherSearchRadius = nil
                planManager:addPlans(destinationID, {
                    planTypeIndex = plan.types.gather.index,
                    objectTypeIndex = gatherObjectTypeIndex,
                    objectOrVertIDs = {randomInfo.objectID},
                })
            end
        end
    end)
end

local function addTerrainClearOrder(destinationID, aiTribeInfo)
    serverGOM:callFunctionForRandomSapienInTribe(destinationID, function(sapien)
        local vertIDs = terrain:getVertIDsWithinRadiusOfNormalizedPos(sapien.normalizedPos, mj:mToP(10.0))
        if vertIDs and vertIDs[1] then
            planManager:addTerrainModificationPlan(destinationID, 
            plan.types.clear.index, 
            vertIDs, 
            nil,--constructableTypeIndex, 
            nil, 
            nil,--restrictedResourceObjectTypes, 
            nil,--restrictedToolObjectTypes, 
            nil, 
            nil, 
            nil)
        end
    end)
end

local function addTerrainDigOrder(destinationID, aiTribeInfo, requiredTerrainTypes)
    serverGOM:callFunctionForRandomSapienInTribe(destinationID, function(sapien)
        local suitableTerrainVertID = terrain:closeVertIDWithinRadiusOfTypes(requiredTerrainTypes, sapien.normalizedPos, serverResourceManager.storageResourceMaxDistance)
        if suitableTerrainVertID then
            planManager:addTerrainModificationPlan(destinationID, 
            plan.types.dig.index, 
            {suitableTerrainVertID}, 
            nil,--constructableTypeIndex, 
            nil, 
            nil,--restrictedResourceObjectTypes, 
            nil,--restrictedToolObjectTypes, 
            nil, 
            nil, 
            nil)
        end
    end)
end

local function addPlansForFoodGather(destinationID, aiTribeInfo)
    local gatherFood = false
    local foodCount = serverStorageArea.foodCountsByTribeID[destinationID]
    if not foodCount or foodCount < 10 then
        gatherFood = true
    end

    --mj:log("food count:", foodCount)

    if gatherFood then

        local maxGatherPlansReached = checkMaxPlansAdded(destinationID, plan.types.gather.index, gatherMaxCount)
       -- mj:log("maxGatherPlansReached:", maxGatherPlansReached)

        if not maxGatherPlansReached then
            local function isDesiredObjectTypeFunction(objectTypeIndex)
                if resource.types[gameObject.types[objectTypeIndex].resourceTypeIndex].foodValue then
                    return true
                end
                return false
            end

            addGatherOrder(destinationID, aiTribeInfo, serverGOM.objectSets.aiTribeGatherableFood, isDesiredObjectTypeFunction)
        end
    end
    return false
end

local function addPlansForMaintainSupplies(destinationState, destinationID, aiTribeInfo)
    local needsSave = false
   -- mj:log("addPlansForMaintainSupplyGather:", destinationID)

    local industryType = industry.types[destinationState.industryTypeIndex]
    local maxGatherPlansReached = checkMaxPlansAdded(destinationID, plan.types.gather.index, gatherMaxCount)

    local maintainGatherState = destinationState.maintainGatherState
    if not maintainGatherState then
        maintainGatherState = {}
        destinationState.maintainGatherState = maintainGatherState
    end

    local function checkMaintainInfo(maintainInfo)
        --mj:log("maintainInfo:", maintainInfo)
        local storageAreaID = nil

        local resourceTypeIndex = maintainInfo.resourceTypeIndex
        local objectTypeIndex = maintainInfo.objectTypeIndex

        local maintainResourceTypeIndex = (maintainInfo.maintainResourceTypeIndex or resourceTypeIndex)
        local maintainObjectTypeIndexIndex = (maintainInfo.maintainObjectTypeIndex or objectTypeIndex)

        local maintainGatherStateKey = maintainResourceTypeIndex or maintainObjectTypeIndexIndex

        if maintainGatherState[maintainGatherStateKey] then
            storageAreaID = maintainGatherState[maintainGatherStateKey].storageAreaID
        else
            local matchInfo = nil
            if resourceTypeIndex then
                matchInfo = findStorageAreaForResourceType(destinationState, resourceTypeIndex, nil)
            else
                matchInfo = findStorageAreaForObjectType(destinationState, objectTypeIndex, nil)
            end

            if matchInfo then
                local storageObject = matchInfo.object
                serverStorageArea:restrictStorageAreaConfig(destinationState.destinationID, storageObject, resourceTypeIndex, objectTypeIndex)

--[[
                local restrictStorageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceTypeIndex or gameObject.types[objectTypeIndex].resourceTypeIndex)
                local modifyRestrictObjectTypeIndexes = getRestrictedObjectTypesForSingleResourceOrObjectType(restrictStorageTypeIndex, resourceTypeIndex, objectTypeIndex)

                serverStorageArea:changeStorageAreaConfig(storageObject, {
                    storageAreaObjectID = storageObject.uniqueID,
                    restrictStorageTypeIndex = restrictStorageTypeIndex,

                    modifyRestrictObjectTypeIndexes = modifyRestrictObjectTypeIndexes,
                    restrictionValue = true,

                }, destinationID)]]
                
                storageAreaID = storageObject.uniqueID
                maintainGatherState[maintainGatherStateKey] = {
                    storageAreaID = storageAreaID
                }
                needsSave = true
            end
        end

        if storageAreaID then
            --mj:log("addPlansForMaintainSupplyGather storageAreaID:", storageAreaID)

            local storedCount = 0
            if maintainResourceTypeIndex then
                storedCount = serverStorageArea:storedResourceCount(storageAreaID, maintainResourceTypeIndex)
            else
                storedCount = serverStorageArea:storedObjectTypeCount(storageAreaID, maintainObjectTypeIndexIndex)
            end
            if storedCount < maintainInfo.count then
                if maintainInfo.plan == "clear" then
                    --mj:log("gathering hay")
                    if not checkMaxPlansAdded(destinationID, plan.types.clear.index, maxClearPlans) then
                        addTerrainClearOrder(destinationID, aiTribeInfo)
                    end
                elseif maintainInfo.plan == "craft" then
                    if not maintainGatherState[maintainGatherStateKey].craftOrderSet then
                        local constructableTypeIndex = maintainInfo.constructableTypeIndex
                        local constructableType = constructable.types[constructableTypeIndex]
                        local craftAreaGroups = constructableType.requiredCraftAreaGroups or {
                            craftAreaGroup.types.standard.index,
                        }
                        local craftArea = serverCraftArea:getFirstAvailableCraftAreaForPos(destinationState.pos, craftAreaGroups, destinationState.destinationID)
                        if craftArea then
                            mj:log("found craft area, adding craft plan:", craftArea.uniqueID)
                            planManager:addPlans(destinationState.destinationID, {
                                planTypeIndex = plan.types.craft.index,

                                craftAreaObjectID = craftArea.uniqueID,
                                constructableTypeIndex = constructableTypeIndex,
                                craftCount = math.floor(maintainInfo.count * 1.5),
                                shouldMaintainSetQuantity = true,
                            })
                            maintainGatherState[maintainGatherStateKey].craftOrderSet = true
                            
                            if constructableType.skills and constructableType.skills.required then
                                planManager:assignNearbySapienToRequiredRoleIfable(destinationState.destinationID, constructableType.skills.required, destinationState.pos, nil)
                            end
                        end
                    end
                --resourceTypeIndex = resource.types.unfiredUrn.index,
                --constructableTypeIndex = constructable.types.unfiredUrnWet.index,
                elseif maintainInfo.plan == "gather" then
                    if not maxGatherPlansReached then
                        --mj:log("adding gather order for branches")
                        local function isDesiredObjectTypeFunction(testObjectTypeIndex)
                            if objectTypeIndex then
                                return testObjectTypeIndex == objectTypeIndex
                            end
                            return gameObject.types[testObjectTypeIndex].resourceTypeIndex == resourceTypeIndex
                        end
                        local resourceType = resource.types[resourceTypeIndex]
                        local aiTribeGatherableResourceKey = "aiTribeGatherableResource_" .. resourceType.key
                        addGatherOrder(destinationID, aiTribeInfo, serverGOM.objectSets[aiTribeGatherableResourceKey], isDesiredObjectTypeFunction)
                    end
                elseif maintainInfo.plan == "dig" then
                    if not checkMaxPlansAdded(destinationID, plan.types.dig.index, maxClearPlans) then
                        addTerrainDigOrder(destinationID, aiTribeInfo, maintainInfo.terrainTypes)
                    end
                elseif maintainInfo.plan == "mine" then
                    if not checkMaxPlansAdded(destinationID, plan.types.mine.index, maxClearPlans) then
                        addTerrainDigOrder(destinationID, aiTribeInfo, maintainInfo.terrainTypes)
                    end
                else
                    mj:warn("unsupported plan type in industry maintainSupplies:", maintainInfo.plan)
                end
            end
        end
    end

    if industryType.maintainSupplies then
        for j,maintainInfo in ipairs(industryType.maintainSupplies) do
            checkMaintainInfo(maintainInfo)
        end
    end


    if destinationState.tradeables.objectTypeOffers then
        for objectTypeIndex,offer in pairs(destinationState.tradeables.objectTypeOffers) do

            if offer.maintainSuppliesInfo then
                checkMaintainInfo(offer.maintainSuppliesInfo)
            end
        end
    end

    return needsSave
end

local function addLightPlans(destinationState)
    --mj:log("addLightPlans:", destinationState.destinationID)
    local unlitFires = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.unlitCampfires, destinationState.pos, mj:mToP(50.0))
    if unlitFires and unlitFires[1] then
        if not checkMaxPlansAdded(destinationState.destinationID, plan.types.light.index, lightMaxCount) then
            local objectIDs = {}
            for i,objectInfo in ipairs(unlitFires) do
                table.insert(objectIDs, objectInfo.objectID)
            end
            planManager:addPlans(destinationState.destinationID, {
                planTypeIndex = plan.types.light.index,
                objectOrVertIDs = objectIDs,
            })
            --mj:log("assigning sapien:", destinationState.destinationID)
            planManager:assignNearbySapienToRequiredRoleIfable(destinationState.destinationID, skill.types.fireLighting.index, destinationState.pos, nil)
        end
    end
end

local function getMaintainCount(resourceTypeIndex)
    return resource.types[resourceTypeIndex].tradeBatchSize * 2
end

local function updateProduction(destinationState) --called on longwait
    --mj:log("updateProduction:", destinationState.destinationID)
    local needsToSaveDestinationState = false

    local industryType = industry.types[destinationState.industryTypeIndex]
    if industryType.outputs then
        local offers = destinationState.tradeables.offers
        for resourceTypeIndex,outputInfo in pairs(industryType.outputs) do

            local offerInfo = offers[resourceTypeIndex]
            if offerInfo and offerInfo.storageAreaID then

                local offerConstructableTypeIndex = outputInfo.constructableTypeIndex


                local function addCraft(constructableTypeIndex, craftCount)
                    if not offerInfo.craftOrders then
                        offerInfo.craftOrders = {}
                    end

                    if not offerInfo.craftOrders[constructableTypeIndex] then
                        local craftAreaGroups = constructable.types[constructableTypeIndex].requiredCraftAreaGroups or {
                            craftAreaGroup.types.standard.index,
                        }
                        local craftArea = serverCraftArea:getFirstAvailableCraftAreaForPos(destinationState.pos, craftAreaGroups, destinationState.destinationID)
                        if craftArea then
                            --mj:log("found craft area, adding craft plan:", craftArea.uniqueID)
                            planManager:addPlans(destinationState.destinationID, {
                                planTypeIndex = plan.types.craft.index,

                                craftAreaObjectID = craftArea.uniqueID,
                                constructableTypeIndex = constructableTypeIndex,
                                craftCount = craftCount,
                                shouldMaintainSetQuantity = true,
                            })
                            offerInfo.craftOrders[constructableTypeIndex] = craftArea.uniqueID
                            needsToSaveDestinationState = true
                        end
                    end
                end

                local storedResourceCount = serverStorageArea:storedResourceCount(offers[resourceTypeIndex].storageAreaID, resourceTypeIndex)

                local maintainCount = getMaintainCount(resourceTypeIndex)

                --mj:log("updateProduction resourceTypeIndex:", resourceTypeIndex, " storedResourceCount:", storedResourceCount, " maintainCount:", maintainCount)
                if storedResourceCount < maintainCount then
                    addCraft(offerConstructableTypeIndex, maintainCount)
                end
            end
        end
    end

    return needsToSaveDestinationState
end


local function sendGrievance(destinationState, grievanceType, grievanceState, otherTribeID, relationshipState)
    local multiplier = math.max(math.floor(grievanceState.count / grievanceType.thresholdMax), 1)
    local favorPenaltyTaken = multiplier * grievanceType.favorPenalty
    favorPenaltyTaken = math.min(favorPenaltyTaken, relationshipState.favor)
    serverTribe:setFavor(destinationState, relationshipState, relationshipState.favor - favorPenaltyTaken)
    
    local userData = {
        grievanceTypeIndex = grievanceType.index,
        favorPenaltyTaken = favorPenaltyTaken,
        tribeName = destinationState.name,
        resourceTypeIndex = grievanceState.resourceTypeIndex,
        objectTypeIndex = grievanceState.objectTypeIndex,
    }
    serverDestination:sendDestinationRelationshipToClient(destinationState, otherTribeID)
    serverTribe:sendTribeRelationshipNotification(otherTribeID, destinationState.destinationID, notification.types.grievance.index, userData)
end

local function longWaitUpdateGrievances(dt, destinationState, aiTribeInfo)
    --mj:log("longWaitUpdateGrievances:", destinationState.destinationID)
    local needsToSaveDestinationState = false
    local relationships = destinationState.relationships
    if relationships then
        for otherTribeID,relationshipState in pairs(relationships) do
            local grievances = relationshipState.grievances
            if grievances then
                if relationshipState.favor > 0 then
                    for grievanceTypeIndex,grievanceState in pairs(grievances) do
                        local grievanceType = grievance.types[grievanceTypeIndex]
                        if (not grievanceType.onlyAddWhenNotTrading) or relationshipState.favor < gameConstants.tribeAIMinimumFavorForTrading then
                            local chanceFraction = reverseLinearInterpolate(grievanceState.count, grievanceType.thresholdMin, grievanceType.thresholdMax)
                        --mj:log("grievanceState.count:", grievanceState.count, " chanceFraction:", chanceFraction)
                            if chanceFraction > 0.9999 or chanceFraction > rng:randomValue() then
                                mj:log("sendGrievance:", grievanceTypeIndex, " otherTribeID:", otherTribeID, " relationshipState:", relationshipState)
                                sendGrievance(destinationState, grievanceType, grievanceState, otherTribeID, relationshipState)
                            end
                        end
                        grievances[grievanceTypeIndex] = nil
                        needsToSaveDestinationState = true
                    end
                    if not next(grievances) then
                        relationshipState.grievances = nil
                    end
                else
                    relationshipState.grievances = nil
                    needsToSaveDestinationState = true
                end
            end
        end
    end
    return needsToSaveDestinationState
end

function serverTribeAIPlayer:assignQuest(destinationState, otherTribeID)
    if not serverDestination:ensureLoaded(destinationState) then
        return
    end
    
    --mj:log("serverTribeAIPlayer:assignQuest:", otherTribeID)
    local relationships = destinationState.relationships
    if relationships then
        local relationshipState = relationships[otherTribeID]
        if relationshipState then
            --mj:log("serverTribeAIPlayer:assignQuest relationshipState:", relationshipState)
            if relationshipState.questState then
                local questState = relationshipState.questState
                if questState.questTypeIndex == quest.types.resource.index then
                    if not questState.objectID then
                        local matchInfo = findStorageAreaForResourceType(destinationState, questState.resourceTypeIndex, nil)

                        if matchInfo then
                            
                            local storageObject = matchInfo.object
                            storageObject.sharedState:set("quest", {
                                tribeID = otherTribeID,
                                resourceTypeIndex = questState.resourceTypeIndex,
                                requiredCount = questState.requiredCount,
                            })

                            serverStorageArea:restrictStorageAreaConfig(destinationState.destinationID, storageObject, questState.resourceTypeIndex, nil)

                            questState.objectID = storageObject.uniqueID
                            questState.objectPos = storageObject.pos
                            questState.assignedTime = serverWorld:getWorldTime()
                            questState.expirationTime = questState.assignedTime + quest.types[questState.questTypeIndex].completionTimeLimit

                            --mj:log("assigned storage area for questState:", questState)

                            serverDestination:sendDestinationRelationshipToClient(destinationState, otherTribeID)
                            serverDestination:saveDestinationState(destinationState.destinationID)
                        else
                            return false
                        end
                    end
                end
                return true
            end
        end
    end
    return false
end

function serverTribeAIPlayer:generateQuestIfMissing(destinationState, otherTribeID)
    local relationshipState = destinationState.relationships and destinationState.relationships[otherTribeID]
    if relationshipState then
        local industryType = industry.types[destinationState.industryTypeIndex]
        if industryType.inputs then

            local questInputAssignList = destinationState.questInputAssignList

            if not (questInputAssignList and questInputAssignList[1]) then
                questInputAssignList = {}
                destinationState.questInputAssignList = questInputAssignList
                for resourceTypeIndex,inputInfo in pairs(industryType.inputs) do
                    local randomIndex = rng:randomInteger(#questInputAssignList + 1) + 1
                    table.insert(questInputAssignList, randomIndex, resourceTypeIndex)
                end
            end

            local requiredResourceTypeIndex = questInputAssignList[#questInputAssignList]
            table.remove(questInputAssignList, #questInputAssignList)

            --this option below could work, but probably less fun
            --[[local requiredResourceTypeIndex = nil
            local requiredCount = nil
            local minStoreWeight = 9999

            local foundResourceTypeIndexes = nil

            local storedCounts = serverStorageArea.resourceCountsByTribeID[destinationState.destinationID]
            for resourceTypeIndex,inputInfo in pairs(industryType.inputs) do
                local storedCount = (storedCounts and storedCounts[resourceTypeIndex]) or 0
                local maintainCount = getMaintainCount(resourceTypeIndex)
                local storeWeight = storedCount / maintainCount
                if storeWeight < minStoreWeight then
                    storeWeight = minStoreWeight
                    foundResourceTypeIndexes = {
                        resourceTypeIndex
                    }
                elseif storeWeight == minStoreWeight then
                    table.insert(foundResourceTypeIndexes, resourceTypeIndex)
                end
            end

            if foundResourceTypeIndexes then
                local randomIndex = rng:randomInteger(#foundResourceTypeIndexes) + 1
                requiredResourceTypeIndex = foundResourceTypeIndexes[randomIndex]
            end]]

            if requiredResourceTypeIndex then

                local tradeBatchSize = resource.types[requiredResourceTypeIndex].tradeBatchSize
                local requiredCount = math.max(math.floor(tradeBatchSize / 2), 1)

                local generationTime = serverWorld:getWorldTime()
                local expirationTime = generationTime + quest.regenerationTime * (0.8 + 0.4 * rng:valueForUniqueID(destinationState.destinationID, 50633))
                local questState = {
                    questTypeIndex = quest.types.resource.index,
                    resourceTypeIndex = requiredResourceTypeIndex,
                    requiredCount = requiredCount,
                    motivationTypeIndex = quest.motivationTypes.craftable.index,
                    generationTime = generationTime,
                    expirationTime = expirationTime,
                    reward = 10,
                    penalty = 5,
                }
                relationshipState.questState = questState
            end
        end
    end
end

local function setQuestFailed(destinationState, questState, relationshipState, clientTribeID)

    if not questState.failed then
        questState.failed = true
        questState.expirationTime = serverWorld:getWorldTime() + quest.failureOrCompletionDelayBeforeNewQuest

        if relationshipState.favor > 0 then

            local penalty = questState.penalty
            local notificationTypeIndex = notification.types.resourceQuestFailFavorPenalty.index

            local deliveredCount = 0
            local questDeliveries = relationshipState.questDeliveries
            if questDeliveries and questDeliveries[questState.resourceTypeIndex] then
                deliveredCount = questDeliveries[questState.resourceTypeIndex]
                questDeliveries[questState.resourceTypeIndex] = nil
            end

            if questState.requiredCount > 1 then
                if deliveredCount >= questState.requiredCount / 2 then
                    notificationTypeIndex = notification.types.resourceQuestFailNoReward.index
                    penalty = 0
                end
            end

            penalty = math.min(penalty, relationshipState.favor)
            serverTribe:setFavor(destinationState, relationshipState, relationshipState.favor - penalty)
            serverDestination:sendDestinationRelationshipToClient(destinationState, clientTribeID)

            local questObject = serverGOM:getObjectWithIDLoadingAreaIfNeeded(questState.objectID, questState.objectPos)
            if questObject then
                serverGOM:sendNotificationForObject(questObject, notificationTypeIndex, {
                    penalty = penalty,
                    requiredCount = questState.requiredCount,
                    deliveredCount = deliveredCount,
                    resourceTypeIndex = questState.resourceTypeIndex,
                    tribeName = destinationState.name,
                }, clientTribeID)
            end
        end

        serverDestination:saveDestinationState(destinationState.destinationID)
    end

    --[[

    {
        key = "resourceQuestFailReducedFavorPenalty",
        titleFunction = function(userData)
            return locale:get("notification_resourceQuestFailReducedFavorPenalty", {
                penalty = userData.penalty,
                requiredCount = userData.requiredCount,
                deliveredCount = userData.deliveredCount, --todo
                resourcePlural = resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.favorLost.index,
    },
    {
        key = "resourceQuestFailNoReward",
    ]]
end

local function updateQuest(destinationState, otherTribeID) --called every update tick, so don't do too much
    local relationships = destinationState.relationships
    if relationships then
        local relationshipState = relationships[otherTribeID]
        if relationshipState then
            local function updateStateAndCheckNeedsRemoved()
                local questState = relationshipState.questState
                if questState then
                    local worldTime = serverWorld:getWorldTime()

                    if questState.complete or questState.failed then
                        if worldTime > questState.expirationTime then
                            return true
                        end
                        return false
                    end

                    if questState.assignedTime then
                        if worldTime > questState.expirationTime then
                            setQuestFailed(destinationState, questState, relationshipState, otherTribeID)
                        end
                        return false
                    else
                        if worldTime > questState.expirationTime then
                            return true
                        end
                    end
                end
                return false
            end

            local questNeedsRemoved = updateStateAndCheckNeedsRemoved()

            if questNeedsRemoved then
                local objectID = relationshipState.questState.objectID
                if objectID then
                    local storageObject = serverGOM:getObjectWithID(objectID)
                    if storageObject then
                        if storageObject.sharedState.quest and storageObject.sharedState.quest.tribeID == otherTribeID then
                            storageObject.sharedState:remove("quest")
                            serverStorageArea:doChecksForAvailibilityChange(storageObject)
                        end
                    end
                end
                relationshipState.questState = nil
                serverTribeAIPlayer:generateQuestIfMissing(destinationState, otherTribeID)
                serverDestination:saveDestinationState(destinationState.destinationID)
                serverDestination:sendDestinationRelationshipToClient(destinationState, otherTribeID)
            end
        end
    end
end

function serverTribeAIPlayer:updateQuestForCompletion(destinationState, delivereredByTribeID)
    updateQuest(destinationState, delivereredByTribeID)
end

local function createTradeRequest(resourceTypeIndex)
    return {
        resourceTypeIndex = resourceTypeIndex,
        count = resource.types[resourceTypeIndex].tradeBatchSize,
        reward = resource.types[resourceTypeIndex].tradeValue,
    }
end

local function createTradeOffer(resourceTypeIndex)
    return {
        resourceTypeIndex = resourceTypeIndex,
        count = resource.types[resourceTypeIndex].tradeBatchSize,
        cost = resource.types[resourceTypeIndex].tradeValue + 1,
    }
end

function serverTribeAIPlayer:updateTradeables(destinationState) --called on init and when items delivered or picked up, and on long wait update
    if not isLoaded(destinationState) then
        return
    end
    --mj:log("updateTradeables:", destinationState.destinationID)
    local changed = false

    local storedCounts = serverStorageArea.resourceCountsByTribeID[destinationState.destinationID]
    local industryType = industry.types[destinationState.industryTypeIndex]
    if industryType.inputs then
        local requests = destinationState.tradeables.requests
        for resourceTypeIndex,inputInfo in pairs(industryType.inputs) do
            if not requests[resourceTypeIndex] then
                requests[resourceTypeIndex] = createTradeRequest(resourceTypeIndex)
            end

            local storedCount = (storedCounts and storedCounts[resourceTypeIndex]) or 0
            local tradeLimitReached = nil
            local maintainCount = getMaintainCount(resourceTypeIndex)
            if storedCount >= maintainCount then
                tradeLimitReached = true
            end

            if tradeLimitReached ~= requests[resourceTypeIndex].tradeLimitReached then
                changed = true
                requests[resourceTypeIndex].tradeLimitReached = tradeLimitReached
            end

            local foundValidAssignedStorageArea = false
            if requests[resourceTypeIndex].storageAreaID then
                local matchInfo = serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(requests[resourceTypeIndex].storageAreaID, 
                resource.types[resourceTypeIndex].displayGameObjectTypeIndex, 
                destinationState.destinationID,
                {
                    allowTradeRequestsMatchingResourceTypeIndex = resourceTypeIndex,
                })
                
                if matchInfo then
                    foundValidAssignedStorageArea = true
                else
                    local storageObject = serverGOM:getObjectWithID(requests[resourceTypeIndex].storageAreaID)
                    if storageObject and storageObject.sharedState.tradeRequest and storageObject.sharedState.tradeRequest.resourceTypeIndex == resourceTypeIndex then
                        storageObject.sharedState:remove("tradeRequest")
                    end
                    requests[resourceTypeIndex].storageAreaID = nil
                    if storageObject then
                        serverStorageArea:doChecksForAvailibilityChange(storageObject)
                    end
                end
            end

            if not tradeLimitReached then
                if not foundValidAssignedStorageArea then
                    changed = true
                    local options = {
                        allowTradeRequestsMatchingResourceTypeIndex = resourceTypeIndex,
                    }
                    local matchInfo = findStorageAreaForResourceType(destinationState, resourceTypeIndex, options)

                    if matchInfo then
                        requests[resourceTypeIndex].tradeLimitReached = nil
                        
                        local storageObject = matchInfo.object
                        storageObject.sharedState:set("tradeRequest", {
                            resourceTypeIndex = resourceTypeIndex,
                            count = requests[resourceTypeIndex].count
                        })

                        requests[resourceTypeIndex].storageAreaID = storageObject.uniqueID
                        requests[resourceTypeIndex].storageAreaPos = storageObject.pos --doesnt support moveable storage

                        serverStorageArea:restrictStorageAreaConfig(destinationState.destinationID, storageObject, resourceTypeIndex, nil)

                        --mj:log("assigning storage area for trade request:", storageObject.uniqueID)

                        --serverStorageArea:doChecksForAvailibilityChange(storageObject) --now called in restrictStorageAreaConfig above
                    else
                        requests[resourceTypeIndex].tradeLimitReached = true
                    end
                end
            elseif changed then
                if requests[resourceTypeIndex].storageAreaID then
                    local storageObject = serverGOM:getObjectWithID(requests[resourceTypeIndex].storageAreaID)
                    if storageObject and storageObject.sharedState.tradeRequest and storageObject.sharedState.tradeRequest.resourceTypeIndex == resourceTypeIndex then
                        storageObject.sharedState:set("tradeRequest", "tradeLimitReached", true)
                        serverStorageArea:doChecksForAvailibilityChange(storageObject)
                    end
                end
            end
        end
    end

    if destinationState.tradeables.objectTypeOffers then
        for objectTypeIndex,offer in pairs(destinationState.tradeables.objectTypeOffers) do

            local tradeLimitReached = true

            if offer.storageAreaID then
                local storedResourceCount = serverStorageArea:storedObjectTypeCount(offer.storageAreaID, objectTypeIndex)
                local gameObjectType = gameObject.types[objectTypeIndex]
                local tradeBatchSize = gameObjectType.tradeBatchSize or resource.types[gameObjectType.resourceTypeIndex].tradeBatchSize
                if storedResourceCount < tradeBatchSize then
                    if not serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(offer.storageAreaID, 
                    objectTypeIndex, 
                    destinationState.destinationID, 
                    nil) then
                        mj:log("serverTribeAIPlayer unassigning trade offer storage area as original no longer valid")
                        -- this check is in case the storage area becomes unreachable or something else is stored there.

                        local storageObject = serverGOM:getObjectWithID(offer.storageAreaID)
                        if storageObject then
                            storageObject.sharedState:remove("tradeOffer")
                        end

                        offer.storageAreaID = nil
                        offer.storageAreaPos = nil

                        changed = true
                    end
                end
            end

            if not offer.storageAreaID then
                local matchInfo = findStorageAreaForObjectType(destinationState, objectTypeIndex, nil)
                if matchInfo then
                    local storageObject = matchInfo.object
                    
                    offer.storageAreaID = storageObject.uniqueID
                    offer.storageAreaPos = storageObject.pos --doesnt support moveable storage

                    storageObject.sharedState:set("tradeOffer", {
                        objectTypeIndex = objectTypeIndex,
                        count = offer.count
                    })

                    serverStorageArea:restrictStorageAreaConfig(destinationState.destinationID, storageObject, nil, objectTypeIndex)

                    changed = true
                end
            end

            if offer.storageAreaID then
                local storedResourceCount = serverStorageArea:storedObjectTypeCount(offer.storageAreaID, objectTypeIndex)
                local gameObjectType = gameObject.types[objectTypeIndex]
                local tradeBatchSize = gameObjectType.tradeBatchSize or resource.types[gameObjectType.resourceTypeIndex].tradeBatchSize
                if storedResourceCount >= tradeBatchSize then

                    --mj:log("updating tradables, initial offer stored count > batch size for:", resourceTypeIndex)

                    if destinationState.relationships then
                        for clientTribeID,relationshipState in pairs(destinationState.relationships) do
                            local soldCount = ((relationshipState.tradeOfferObjectTypePurchases and relationshipState.tradeOfferObjectTypePurchases[objectTypeIndex]) or 0)
                            --mj:log("soldCount:", soldCount)
                            storedResourceCount = storedResourceCount - soldCount
                        end
                    end

                    --mj:log("final stored count/batch size:", storedResourceCount, "/", resource.types[resourceTypeIndex].tradeBatchSize)
                    if storedResourceCount >= tradeBatchSize then
                        tradeLimitReached = nil
                    end
                end
            end

            if offer.tradeLimitReached ~= tradeLimitReached then
                offer.tradeLimitReached = tradeLimitReached
                changed = true
            end
        end
    end
    
    if industryType.outputs then
        local offers = destinationState.tradeables.offers
        for resourceTypeIndex,outputInfo in pairs(industryType.outputs) do
            local offer = offers[resourceTypeIndex]
            if not offer then
                offer = createTradeOffer(resourceTypeIndex)
                offers[resourceTypeIndex] = offer
            end

            local tradeLimitReached = true

            if offers[resourceTypeIndex].storageAreaID then
                local storedResourceCount = serverStorageArea:storedResourceCount(offers[resourceTypeIndex].storageAreaID, resourceTypeIndex)
                if storedResourceCount < resource.types[resourceTypeIndex].tradeBatchSize then
                    if not serverStorageArea:storageAreaMatchInfoIfCanTakeObjectType(offers[resourceTypeIndex].storageAreaID, 
                    resource.types[resourceTypeIndex].displayGameObjectTypeIndex, 
                    destinationState.destinationID, 
                    nil) then
                        mj:log("serverTribeAIPlayer unassigning trade offer storage area as original no longer valid")
                        -- this check is in case the storage area becomes unreachable or something else is stored there.

                        local storageObject = serverGOM:getObjectWithID(offers[resourceTypeIndex].storageAreaID)
                        if storageObject then
                            storageObject.sharedState:remove("tradeOffer")
                        end

                        offers[resourceTypeIndex].storageAreaID = nil
                        offers[resourceTypeIndex].storageAreaPos = nil

                        changed = true
                    end
                end
            end

            if not offers[resourceTypeIndex].storageAreaID then
                local matchInfo = findStorageAreaForResourceType(destinationState, resourceTypeIndex, nil)
                if matchInfo then
                    local storageObject = matchInfo.object
                    
                    offers[resourceTypeIndex].storageAreaID = storageObject.uniqueID
                    offers[resourceTypeIndex].storageAreaPos = storageObject.pos --doesnt support moveable storage

                    storageObject.sharedState:set("tradeOffer", {
                        resourceTypeIndex = resourceTypeIndex,
                        count = offers[resourceTypeIndex].count
                    })

                    serverStorageArea:restrictStorageAreaConfig(destinationState.destinationID, storageObject, resourceTypeIndex, nil)

                    changed = true
                end
            end

            if offers[resourceTypeIndex].storageAreaID then
                local storedResourceCount = serverStorageArea:storedResourceCount(offers[resourceTypeIndex].storageAreaID, resourceTypeIndex)
                if storedResourceCount >= resource.types[resourceTypeIndex].tradeBatchSize then

                    --mj:log("updating tradables, initial offer stored count > batch size for:", resourceTypeIndex)

                    if destinationState.relationships then
                        for clientTribeID,relationshipState in pairs(destinationState.relationships) do
                            local soldCount = ((relationshipState.tradeOfferPurchases and relationshipState.tradeOfferPurchases[resourceTypeIndex]) or 0)
                            --mj:log("soldCount:", soldCount)
                            storedResourceCount = storedResourceCount - soldCount
                        end
                    end

                    --mj:log("final stored count/batch size:", storedResourceCount, "/", resource.types[resourceTypeIndex].tradeBatchSize)
                    if storedResourceCount >= resource.types[resourceTypeIndex].tradeBatchSize then
                        tradeLimitReached = nil
                    end
                end
            end

            if offers[resourceTypeIndex].tradeLimitReached ~= tradeLimitReached then
                offers[resourceTypeIndex].tradeLimitReached = tradeLimitReached
                changed = true
            end
        end
    end

    if changed then
        serverDestination:sendDestinationTradeables(destinationState)
    end
    return changed
end

local function longWaitCheckPopulation(dt, destinationState, aiTribeInfo)
    if serverTribe:tribeRequiresPopulationGrowth(destinationState.destinationID) then
        local spawnTopUpPreventionLastInteractionTime = destinationState.spawnTopUpPreventionLastInteractionTime or 0
        local worldTime = serverWorld:getWorldTime()
        if worldTime - spawnTopUpPreventionLastInteractionTime > (2880 * 2) then --wait 2 days
            destinationState.spawnTopUpPreventionLastInteractionTime = worldTime
            mj:log("tribe population too low for:", destinationState.destinationID, " population:", destinationState.population)
            serverTribe:addSapiensToTribe(destinationState, 1 + rng:randomInteger(2))
        end
    end

    return false --if we changed anything here, it would have saved within
end

local function checkForNomadReputationGrievances(destinationState)
    if destinationState.relationships then
        for clientTribeID, relationshipState in pairs(destinationState.relationships) do
            if relationshipState.favor >= gameConstants.tribeRelationshipScoreThresholds.moderatePositive then --we only care if we like them
                local nomadReputation = serverWorld:getPlayerNomadReputation(clientTribeID)
                if nomadReputation <= gameConstants.tribeRelationshipScoreThresholds.moderateNegative then
                    serverTribeAIPlayer:addGrievanceIfNeeded(destinationState.destinationID, clientTribeID, grievance.types.nomadsMistreated.index, 1, nil)
                end
            end
        end
    end
end

function serverTribeAIPlayer:longWaitInfrequentUpdate(dt, worldTime, destinationID, aiTribeInfo)
    --mj:log("serverTribeAIPlayer:longWaitInfrequentUpdate:", destinationID)

    local destinationState = aiTribeInfo.destinationState
    
    serverTribeAIPlayer:updateTradeables(destinationState) --added sep/25. We might update the industry config, or some other random thing might happen, so let's just do this now and then

    
    if rng:randomInteger(80) == 1 then --longWaitInfrequentUpdate gets called every 30 seconds so every 40 minutes average, couple of days
        checkForNomadReputationGrievances(destinationState)
    end
    --serverTribeAIPlayer:addGrievanceIfNeeded(orderObject.sharedState.tribeID, sharedState.tribeID, grievance.types.sapienAttacked.index, 1, nil)

    local needsSave = addPlansForFoodGather(destinationID, aiTribeInfo)
    needsSave = addPlansForMaintainSupplies(destinationState, destinationID, aiTribeInfo) or needsSave
    needsSave = updateProduction(destinationState) or needsSave
    needsSave = longWaitUpdateGrievances(dt, destinationState, aiTribeInfo) or needsSave
    needsSave = longWaitCheckPopulation(dt, destinationState, aiTribeInfo) or needsSave
    addLightPlans(destinationState)

    if needsSave then
        serverDestination:saveDestinationState(destinationState.destinationID)
    end
end


function serverTribeAIPlayer:preventSpawnTopUps(destinationID)
    local destinationState = serverDestination:getDestinationState(destinationID)
    destinationState.spawnTopUpPreventionLastInteractionTime = serverWorld:getWorldTime()
    serverDestination:saveDestinationState(destinationState.destinationID)
end

function serverTribeAIPlayer:update(dt, worldTime, speedMultiplier)
    for destinationID,aiTribeInfo in pairs(aiTribes) do
        local destinationState = aiTribeInfo.destinationState

        if destinationState.relationships then
            for otherTribeID, relationshipState in pairs(destinationState.relationships) do
                updateQuest(destinationState, otherTribeID)
            end
        end

        aiTribeInfo.longWaitTimer = aiTribeInfo.longWaitTimer + dt * speedMultiplier
        if aiTribeInfo.longWaitTimer >= gameConstants.tribeAIPlayerTimeBetweenUpdates then
            local timePassed = aiTribeInfo.longWaitTimer
            aiTribeInfo.longWaitTimer = 0.0
            serverTribeAIPlayer:longWaitInfrequentUpdate(timePassed, worldTime, destinationID, aiTribeInfo)
        end
    end
end

local function initTradeables(destinationState)
    destinationState.tradeables = {
        requests = {},
        offers = {}
    }

    local industryType = industry.types[destinationState.industryTypeIndex]

    if industryType.createTradeOutputsForStoredObjectTypes then
        local foundTypes = {}
        serverResourceManager:callFunctionForEachResourceObject(destinationState.destinationID, serverResourceManager.providerTypes.storageArea, function(storageObject, objectTypeIndex, objectCount)
            if objectCount >= 80 and (not foundTypes[objectTypeIndex]) then
                local maintainSuppliesInfo = industryType.createTradeOutputsForStoredObjectTypes[objectTypeIndex]
                if maintainSuppliesInfo then
                    --maintainSupplies
                    foundTypes[objectTypeIndex] = true
                    local objectTypeOffers = destinationState.tradeables.objectTypeOffers
                    if not objectTypeOffers then
                        objectTypeOffers = {}
                        destinationState.tradeables.objectTypeOffers = objectTypeOffers
                    end


                    local gameObjectType = gameObject.types[objectTypeIndex]
                    local tradeBatchSize = gameObjectType.tradeBatchSize or resource.types[gameObjectType.resourceTypeIndex].tradeBatchSize
                    local tradeValue = gameObjectType.tradeValue or resource.types[gameObjectType.resourceTypeIndex].tradeValue

                    objectTypeOffers[objectTypeIndex] = {
                        objectTypeIndex = objectTypeIndex,
                        count = tradeBatchSize,
                        cost = tradeValue + 1,
                        maintainSuppliesInfo = maintainSuppliesInfo,
                    }

                    objectTypeOffers[objectTypeIndex].storageAreaID = storageObject.uniqueID
                    objectTypeOffers[objectTypeIndex].storageAreaPos = storageObject.pos --doesnt support moveable storage

                    storageObject.sharedState:set("tradeOffer", {
                        objectTypeIndex = objectTypeIndex,
                        count = tradeBatchSize
                    })
                end

            end
        end)
    end

    if industryType.outputs then
        terrain:loadAreaAtLevels(destinationState.normalizedPos, mj.SUBDIVISIONS - 4, mj.SUBDIVISIONS - 1)
        local storedCounts = serverStorageArea.resourceCountsByTribeID[destinationState.destinationID]
        for resourceTypeIndex,outputInfo in pairs(industryType.outputs) do

            local offer = createTradeOffer(resourceTypeIndex)
            destinationState.tradeables.offers[resourceTypeIndex] = offer

            local storedCount = (storedCounts and storedCounts[resourceTypeIndex]) or 0
            
            local maintainCount = getMaintainCount(resourceTypeIndex)
            if storedCount < maintainCount then
                local matchInfo = findStorageAreaForResourceType(destinationState, resourceTypeIndex, nil)
                if matchInfo then
                    
                    local storageObject = matchInfo.object
                    local addCount = math.floor(maintainCount * (0.25 + math.min(rng:randomValue())))

                    local outputs = serverCraftArea:createCraftedObjectInfos(outputInfo.constructableTypeIndex, destinationState.destinationID)
                    local foundOutput = nil
                    for i,objectInfo in ipairs(outputs) do
                        if gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex == resourceTypeIndex then
                            foundOutput = objectInfo
                            break
                        end
                    end

                    if foundOutput then
                        for i=1,addCount do
                            local objectInfoForAdditionToInventory = serverGOM:stripObjectInfoForAdditionToInventory(foundOutput) --must be done on each iteration, or otherwise cloned, or big troubles
                            if not serverStorageArea:addObjectToStorageArea(storageObject.uniqueID, objectInfoForAdditionToInventory, storageObject.sharedState.tribeID) then
                                break
                            end
                        end

                        offer.storageAreaID = storageObject.uniqueID
                        offer.storageAreaPos = storageObject.pos --doesnt support moveable storage

                        storageObject.sharedState:set("tradeOffer", {
                            resourceTypeIndex = resourceTypeIndex,
                            count = offer.count
                        })

                        serverStorageArea:restrictStorageAreaConfig(destinationState.destinationID, storageObject, resourceTypeIndex, nil)
                    end
                end
            end
        end
    end

    

    serverTribeAIPlayer:updateTradeables(destinationState)
end

function serverTribeAIPlayer:addDestination(destinationState)
    if destinationState.clientID or destinationState.nomad then
        return
    end

    if not isLoaded(destinationState) then
        mj:warn("serverTribeAIPlayer:addDestination called when destination not loaded:", destinationState.destinationID)
        return
    end

    --mj:log("serverTribeAIPlayer destination added:", destinationState.destinationID)
    if not destinationState.tradeables then
        initTradeables(destinationState)
    end
    aiTribes[destinationState.destinationID] = {
        destinationState = destinationState,
        longWaitTimer = rng:randomValue() * gameConstants.tribeAIPlayerTimeBetweenUpdates, --tribeAIPlayerTimeBetweenUpdates default is 30
    }
    planHelper:setDiscoveriesForTribeID(destinationState.destinationID, destinationState.discoveries, destinationState.craftableDiscoveries)
end

function serverTribeAIPlayer:removeDestination(destinationState)
    --mj:log("serverTribeAIPlayer destination removed:", destinationState.destinationID)
    aiTribes[destinationState.destinationID] = nil
end

function serverTribeAIPlayer:getIsAIPlayerTribe(tribeID)
    return aiTribes[tribeID] ~= nil
end

function serverTribeAIPlayer:addGrievanceIfNeeded(victimTribeID, grieferTribeID, grievanceTypeIndex, grievanceCount, extraStateOrNil)
    --mj:log("addGrievanceIfNeeded:",  grievanceCount, " of type:", grievanceTypeIndex, " victimTribeID:", victimTribeID, " grieferTribeID:", grieferTribeID)
    if victimTribeID ~= grieferTribeID then
        if aiTribes[victimTribeID] ~= nil then
            if serverWorld:tribeIsValidOwner(grieferTribeID) then
                mj:log("adding grievance:", grievanceTypeIndex, " against:", victimTribeID, " by:", grieferTribeID, " grievanceCount:", grievanceCount)
                local destinationState = serverDestination:getDestinationState(victimTribeID)
                if not destinationState then
                    return
                end
                local relationshipState = destinationState.relationships and destinationState.relationships[grieferTribeID]
                if not relationshipState then
                    serverTribe:generateNewRelationshipIfMissing(victimTribeID, grieferTribeID, -5) --contextural -5 relationship offset, we started off with a grievance before greeting them
                    relationshipState = destinationState.relationships[grieferTribeID]
                end
                local grievances = relationshipState.grievances
                if not grievances then
                    grievances = {}
                    relationshipState.grievances = grievances
                end

                local grievanceState = grievances[grievanceTypeIndex]
                if not grievanceState then
                    grievanceState = {
                        count = grievanceCount,
                    }
                    grievances[grievanceTypeIndex] = grievanceState
                else
                    grievanceState.count = (grievanceState.count or 0) + grievanceCount
                end

                if extraStateOrNil then
                    for k,v in pairs(extraStateOrNil) do
                        grievanceState[k] = v
                    end
                end

                serverDestination:saveDestinationState(victimTribeID)
            end
        end
    end
end

function serverTribeAIPlayer:addGrievanceIfNeededForResourceTaken(takenFromObjectTribeID, takerSapienTribeID, takenResourceTypeIndex, takenObjectTypeIndex, countTaken)
    --mj:log("serverTribeAIPlayer:addGrievanceIfNeededForResourceTaken:", takenFromObjectTribeID)
    serverTribeAIPlayer:addGrievanceIfNeeded(takenFromObjectTribeID, takerSapienTribeID, grievance.types.resourcesTaken.index, countTaken, {
        resourceTypeIndex = takenResourceTypeIndex,
        objectTypeIndex = takenObjectTypeIndex,
    })
end

function serverTribeAIPlayer:addGrievanceIfNeededForBedUsed(bedTribeID, userSapienTribeID)
    serverTribeAIPlayer:addGrievanceIfNeeded(bedTribeID, userSapienTribeID, grievance.types.bedsUsed.index, 1, nil)
end

function serverTribeAIPlayer:addGrievanceIfNeededForObjectDestruction(objectTribeID, naughtySapienTribeID, destroyedObjectTypeIndex)
    --mj:log("serverTribeAIPlayer:addGrievanceIfNeededForObjectDestruction:", destroyedObjectTypeIndex)
    serverTribeAIPlayer:addGrievanceIfNeeded(objectTribeID, naughtySapienTribeID, grievance.types.objectsDestroyed.index, 1, {
        objectTypeIndex = destroyedObjectTypeIndex,
    })
end

function serverTribeAIPlayer:addGrievanceIfNeededForCraftAreaUsed(objectTribeID, naughtySapienTribeID, craftAreaObjectTypeIndex)
    serverTribeAIPlayer:addGrievanceIfNeeded(objectTribeID, naughtySapienTribeID, grievance.types.craftAreasUsed.index, 1, {
        objectTypeIndex = craftAreaObjectTypeIndex,
    })
end

--local grievanceRadius = mj:mToP(100.0)
--local grievanceRadius2 = grievanceRadius * grievanceRadius

function serverTribeAIPlayer:addGrievanceIfNeededForObjectBeingBuilt(buildObjectPos, naughtySapienTribeID, buildObjectTypeIndex)
    --mj:log("serverTribeAIPlayer:addGrievanceIfNeededForObjectBeingBuilt:", buildObjectTypeIndex)
    --[[for objectTribeID,aiTribeInfo in pairs(aiTribes) do
        if objectTribeID ~= naughtySapienTribeID then
            if length2(aiTribeInfo.destinationState.pos - buildObjectPos) < grievanceRadius2 then
                serverTribeAIPlayer:addGrievanceIfNeeded(objectTribeID, naughtySapienTribeID, grievance.types.objectsBuilt.index, 1, {
                    objectTypeIndex = buildObjectTypeIndex,
                })
            end
        end
    end]]
end

function serverTribeAIPlayer:shouldPreventHibernation(destinationState)
    --[[if aiTribes[destinationState.destinationID] then --this could be used to keep the ai tribe producing goods, but we don't want AI tribe sapiens wasting so much cpu.
        return planManager:getHasAvailablePlan(destinationState.destinationID)
    end]]
    return false
end

function serverTribeAIPlayer:getAITribeAverageReputation(clientTribeID) --returns an average reputation score
    local sum = 0
    local count = 0
    for destinationID,aiTribeInfo in pairs(aiTribes) do
        local relationships = aiTribeInfo.destinationState.relationships
        if relationships then
            local relationship = relationships[clientTribeID]
            if relationship and relationship.favor then
                sum = sum + relationship.favor
                count = count + 1
            end
        end
    end

    if count > 0 then
        return sum / count
    end

    return 0
end

function serverTribeAIPlayer:init(serverWorld_, serverGOM_, serverTribe_, serverDestination_, serverDestinationBuilder_, serverCraftArea_)
    serverWorld = serverWorld_
    serverGOM = serverGOM_
    serverTribe = serverTribe_
    serverDestination = serverDestination_
    serverDestinationBuilder = serverDestinationBuilder_
    serverCraftArea = serverCraftArea_
end

return serverTribeAIPlayer