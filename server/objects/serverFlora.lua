local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3Rotate = mjm.mat3Rotate
local normalize = mjm.normalize
local approxEqual = mjm.approxEqual

local gameObject = require "common/gameObject"
local flora = mjrequire "common/flora"
local rng = mjrequire "common/randomNumberGenerator"
local worldHelper = mjrequire "common/worldHelper"
--local physics = mjrequire "common/physics"
local resource = mjrequire "common/resource"
local plan = mjrequire "common/plan"

local terrain = mjrequire "server/serverTerrain"
local serverResourceManager = mjrequire "server/serverResourceManager"

local serverGOM = nil
local serverWorld = nil
local planManager = nil
local serverSapien = nil

local serverFlora = {}

--fruitFrequencyInYears

function serverFlora:updateGatherableResourceSets(object) --todo this method does not work correctly if the object type is changed. It may not be removed from all the aiTribeGatherableResourceKey object sets
    serverGOM:ensureSharedStateLoaded(object)
    local gatherableTypes = gameObject.types[object.objectTypeIndex].gatherableTypes
    if not gatherableTypes then
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.aiTribeGatherableFood)
        return
    end
    local foundFood = false
    local gatherableResourceTypesSet = {}

    local inventory = object.sharedState and object.sharedState.inventory
    if inventory then
        local countsByObjectType = inventory.countsByObjectType
        if countsByObjectType then
            for j,objectTypeIndex in ipairs(gatherableTypes) do
                local resourceType = resource.types[gameObject.types[objectTypeIndex].resourceTypeIndex]
                if countsByObjectType[objectTypeIndex] and countsByObjectType[objectTypeIndex] > 0 then
                    if resourceType.foodValue and (not resourceType.defaultToEatingDisabled) then
                        foundFood = true
                    end

                    gatherableResourceTypesSet[resourceType.index] = true
                elseif gatherableResourceTypesSet[resourceType.index] == nil then
                    gatherableResourceTypesSet[resourceType.index] = false
                end
            end
        end
    end

    if foundFood then
        serverGOM:addObjectToSet(object, serverGOM.objectSets.aiTribeGatherableFood)
    else
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.aiTribeGatherableFood)
    end

    for resourceTypeIndex,found in pairs(gatherableResourceTypesSet) do
        local resourceType = resource.types[resourceTypeIndex]
        local aiTribeGatherableResourceKey = "aiTribeGatherableResource_" .. resourceType.key
        if found then
            serverGOM:addObjectToSet(object, serverGOM.objectSets[aiTribeGatherableResourceKey])
        else
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets[aiTribeGatherableResourceKey])
        end
    end

    --[[
    local setIndex = serverGOM:createObjectSet(aiTribeGatherableResourceKey)
    serverGOM.objectSets[aiTribeGatherableResourceKey] = setIndex]]

    --[[if foundBranch then
        serverGOM:addObjectToSet(object, serverGOM.objectSets.aiTribeGatherableResource_branch)
    else
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.aiTribeGatherableResource_branch)
    end]]

end

function serverFlora:getGrowthMediumQuality(object)
    
    local vertID = terrain:getClosestVertIDToPos(object.normalizedPos)
    local vert = terrain:getVertWithID(vertID)
    if vert then
        local baseType = vert.baseType
        local floraMedium = flora.mediumTypes[baseType]
        if not floraMedium then
           -- mj:log("serverFlora:getGrowthMediumQuality no medium found for baseType:", baseType)
            return flora.soilQualities.invalid
        end
       -- mj:log("serverFlora:getGrowthMediumQuality returning quality:", floraMedium.soilQuality)

        return floraMedium.soilQuality
    end

    --[[local rayStart = object.pos + object.normalizedPos * mj:mToP(0.2)
    local rayEnd = rayStart - object.normalizedPos * mj:mToP(0.4)

    local rayResult = physics:rayTest(rayStart, rayEnd, nil, object.uniqueID)

    if rayResult and rayResult.hasHitTerrain then
        local vert = terrain:getVertClosestToPointInFace(rayResult.triID, object.normalizedPos)
        --mj:log("serverFlora:getGrowthMediumQuality rayResult:", rayResult)
        if vert then
            local baseType = vert.baseType
            local floraMedium = flora.mediumTypes[baseType]
            if not floraMedium then
               -- mj:log("serverFlora:getGrowthMediumQuality no medium found for baseType:", baseType)
                return flora.soilQualities.invalid
            end
           -- mj:log("serverFlora:getGrowthMediumQuality returning quality:", floraMedium.soilQuality)

            return floraMedium.soilQuality
        end
    end
   -- mj:log("serverFlora:getGrowthMediumQuality no result found. rayResult:", rayResult)]]

    return flora.soilQualities.unknown
end

function serverFlora:refillInventory(object, sharedState, addSeasonalItems, addFruitItems)

    if not object then
        mj:error("attempt to call serverFlora:refillInventory on nil object")
    end

    serverGOM:ensureSharedStateLoaded(object)
	local currentInventory = sharedState.inventory

    local floraTypeIndex = gameObject.types[object.objectTypeIndex].floraTypeIndex
    local resourceGroup = floraTypeIndex and flora.types[floraTypeIndex].resourceGroup

    if not resourceGroup then
        mj:warn("attempt to call serverFlora:refillInventory on object with no flora resource group of type:", object.objectTypeIndex, " object:", object.uniqueID)
        return
    end

	if not currentInventory or not currentInventory.objects or #currentInventory.objects == 0 then --probably just grew
		sharedState:set("inventory", flora:createInventory(resourceGroup, addSeasonalItems, addFruitItems))
    else
        local function addItems(replenishItems)
            for gameObjectTypeIndex, count in pairs(replenishItems) do
                local currentCount = sharedState.inventory.countsByObjectType[gameObjectTypeIndex] or 0
                if currentCount < count then
                    for i = currentCount + 1,count do
                        sharedState:set("inventory", "objects", #sharedState.inventory.objects + 1, {
                            objectTypeIndex = gameObjectTypeIndex,
                        })
                    end
                    
                    sharedState:set("inventory", "countsByObjectType", gameObjectTypeIndex, count)
                end
            end
        end

        if addSeasonalItems and resourceGroup.seasonalReplenish then
			addItems(resourceGroup.seasonalReplenish)
        end
        
		if addFruitItems and resourceGroup.fruitReplenish then
			addItems(resourceGroup.fruitReplenish)
		end
    end
    serverFlora:updateGatherableResourceSets(object)
end

local function growSapling(loadedObject)
    local saplingObjectTypeIndex = loadedObject.objectTypeIndex
    local gameObjectType = gameObject.types[saplingObjectTypeIndex]
    if gameObjectType.floraTypeIndex then
        local floraInfo = flora.types[gameObjectType.floraTypeIndex]
        local newTypeIndex = floraInfo.gameObjectTypeIndex
        if newTypeIndex ~= saplingObjectTypeIndex then
            local reloadedSharedState = loadedObject.sharedState
            
            reloadedSharedState:remove("matureTime")

            local growFruitImmediately = floraInfo.fruitImmediatelyWhenMature
            
            if (not growFruitImmediately) and ((not floraInfo.fruitFrequencyInYears) or floraInfo.fruitFrequencyInYears == 1) then
                local soilQuality = serverFlora:getGrowthMediumQuality(loadedObject)
                if soilQuality == flora.soilQualities.rich then
                    growFruitImmediately = true
                end
            end
            

            if growFruitImmediately then
                serverFlora:refillInventory(loadedObject, reloadedSharedState, true, true)
            else
                serverFlora:refillInventory(loadedObject, reloadedSharedState, true, false)
                reloadedSharedState:set("growFruitNextSeasonIndex", floraInfo.fruitSeason)
                reloadedSharedState:set("growFruitYearDelayCounter", (floraInfo.fruitFrequencyInYears or 1))
            end

            serverGOM:changeObjectType(loadedObject.uniqueID, newTypeIndex, false) --calls object loaded function, which calls addCallbackToLoadFruit if needed 
            serverGOM:updateNearByObjectObservers(loadedObject.uniqueID, newTypeIndex, saplingObjectTypeIndex)
        end
    end
end


local function addCallbackToGrowSapling(incomingObject)
    --mj:log("addCallbackToGrowSapling:", incomingObject.uniqueID)
    local matureTime = incomingObject.sharedState.matureTime
    local saplingObjectTypeIndex = incomingObject.objectTypeIndex

    if matureTime then
        serverGOM:addObjectCallbackTimerForWorldTime(incomingObject.uniqueID, matureTime, function(loadedObjectID)
            
            local loadedObject = serverGOM:getObjectWithID(loadedObjectID)
            if loadedObject and saplingObjectTypeIndex == loadedObject.objectTypeIndex and loadedObject.sharedState.matureTime and approxEqual(matureTime, loadedObject.sharedState.matureTime) then
                growSapling(loadedObject)
            end
        end)
    end
end

local function addCallbackToLoadFruit(incomingObject, seasonIndex)
    local currentSeasonIndex = worldHelper:seasonIndexForSeasonFraction(incomingObject.pos.y, serverWorld:getSeasonFraction() - 0.1 * rng:valueForUniqueID(incomingObject.uniqueID, 32987), incomingObject.uniqueID)
    local callbackWorldTime = serverWorld:getWorldTime() + serverWorld:getTimeUntilNextSeasonOfType(seasonIndex, currentSeasonIndex, 0.01 + 0.1 * rng:valueForUniqueID(incomingObject.uniqueID, 32987))
    serverGOM:addObjectCallbackTimerForWorldTime(incomingObject.uniqueID, callbackWorldTime, function(loadedObjectID)
        local loadedObject = serverGOM:getObjectWithID(loadedObjectID)
        if loadedObject then
            --mj:log("load fruit timer fired:", loadedObject.uniqueID)
            local addFruitItems = true

            local sharedState = loadedObject.sharedState
            if sharedState.growFruitYearDelayCounter then
                local newDelayCounter = sharedState.growFruitYearDelayCounter - 1
                if newDelayCounter >= 0 then
                    sharedState:set("growFruitYearDelayCounter", newDelayCounter)
                    addCallbackToLoadFruit(loadedObject, seasonIndex)
                    addFruitItems = false
                else
                    sharedState:remove("growFruitYearDelayCounter")
                end
            end

            if addFruitItems then
                sharedState:remove("growFruitNextSeasonIndex")
            end
            serverFlora:refillInventory(loadedObject, sharedState, true, addFruitItems)

            serverResourceManager:updateResourcesForObject(loadedObject)
        end
    end)
end

function serverFlora:revertToSaplingForHarvest(object)
    local prevObjectTypeIndex = object.objectTypeIndex
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    local floraInfo = flora.types[gameObjectType.floraTypeIndex]
    local saplingGameObjectTypeKey = floraInfo.saplingGameObjectTypeKey
    local saplingGameObjectTypeIndex = gameObject.types[saplingGameObjectTypeKey].index
    
    local sharedState = object.sharedState
    sharedState:remove("inventory")
    sharedState:remove("growFruitNextSeasonIndex")
    sharedState:remove("growFruitYearDelayCounter")
    sharedState:remove("plantTime")
    sharedState:remove("matureTime")

    serverGOM:changeObjectType(object.uniqueID, saplingGameObjectTypeIndex, false)
    serverGOM:updateNearByObjectObservers(object.uniqueID, saplingGameObjectTypeIndex, prevObjectTypeIndex)
    addCallbackToGrowSapling(object)
    serverFlora:updateGatherableResourceSets(object)

    planManager:removePlanStateForObject(object, plan.types.gather.index, nil, nil, nil, nil)
end

function serverFlora:dropInventoryAndRevertOrRemoveForChop(object, 
    tribeID, 
    chopPlanTypeIndex, 
    storeOrderPrioritySapienOrNil, 
    planOrderIndexOrNil, 
    planPriorityOffsetOrNil, 
    manuallyPrioritizedOrNil
)

    local prevObjectTypeIndex = object.objectTypeIndex
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    local floraInfo = flora.types[gameObjectType.floraTypeIndex]
    if not floraInfo then
        return --this happened when a bamboo plant had somehow become a "plant_bamboo1", but we still got here. let's just abort
    end 
    local plantGameObjectTypeKey = floraInfo.plantGameObjectTypeKey
    local plantGameObjectTypeIndex = gameObject.types[plantGameObjectTypeKey].index
    
    local sharedState = object.sharedState

    local dropPos = object.pos
    local objectNormalizedPos = object.pos
    local objectRotation = object.rotation
    local objects = sharedState.inventory and sharedState.inventory.objects
    local addPlanTypeIndex = plan.types.storeObject.index

    if chopPlanTypeIndex ~= plan.types.chopReplant.index then -- WAtch out! object is set to nil here if we are not converting it to a replant build object
        serverGOM:removeGameObject(object.uniqueID)
        object = nil
    end
    
    local lastOutputID = nil
    local dropPosOffset = vec3(0.0,0.0,0.0)
    if objects then
        for i, objectInfo in ipairs(objects) do
            
            local dropPosToUse = dropPos
            local rotation = nil

            if gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex == resource.types.log.index then
                dropPosOffset = dropPosOffset + objectNormalizedPos * mj:mToP(2.5)
                dropPosToUse = dropPos + dropPosOffset
                rotation = mat3Rotate(objectRotation, math.pi * (0.4 + rng:randomValue() * 0.2), normalize(vec3(-0.1 + rng:randomValue() * 0.2, -0.1 + rng:randomValue() * 0.2, 0.9 + rng:randomValue() * 0.2)))
            else
                dropPosToUse = dropPos + objectNormalizedPos * mj:mToP(2.0 + rng:randomValue() * 4.0) + rng:randomVec() * mj:mToP(1.5)
                rotation = mat3Rotate(objectRotation, math.pi * 2.0 * rng:randomValue(), normalize(vec3(-0.1 + rng:randomValue() * 0.2, 0.9 + rng:randomValue() * 0.2, -0.1 + rng:randomValue() * 0.2)))
            end

           -- local rotation = mjm.createUpAlignedRotationMatrix(normalizedPos, lookDirection)


            --rng:randomRotation()

            lastOutputID = serverGOM:createOutput(dropPosToUse, rotation, objectInfo.objectTypeIndex, nil, tribeID, addPlanTypeIndex, {
                planOrderIndex = planOrderIndexOrNil,
                planPriorityOffset = planPriorityOffsetOrNil,
                manuallyPrioritized = manuallyPrioritizedOrNil,
            })
        end
    end

    if object then
        sharedState:remove("inventory")
        sharedState:remove("growFruitNextSeasonIndex")
        sharedState:remove("growFruitYearDelayCounter")
        sharedState:remove("plantTime")
        sharedState:remove("matureTime")

        serverGOM:changeObjectType(object.uniqueID, plantGameObjectTypeIndex, false)

        planManager:addBuildOrPlantPlanForRebuild(object.uniqueID, tribeID, floraInfo.constructableTypeIndex, nil, nil)

        serverGOM:updateNearByObjectObservers(object.uniqueID, plantGameObjectTypeIndex, prevObjectTypeIndex)
        serverFlora:updateGatherableResourceSets(object)
    end

    
    if lastOutputID and storeOrderPrioritySapienOrNil then
        local lastOutputObject = serverGOM:getObjectWithID(lastOutputID)
        if lastOutputObject then
            serverSapien:setLookAt(storeOrderPrioritySapienOrNil, lastOutputID, lastOutputObject.pos)
        end
    end
end

function serverFlora:addCallbackToGrowFruitNextSeasonIfNeeded(object)
    --mj:log("serverFlora:addCallbackToGrowFruitNextSeasonIfNeeded:", object.uniqueID)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    local sharedState = object.sharedState
    if (not sharedState.growFruitNextSeasonIndex) and (not gameObjectType.isSapling) then
        local floraType = flora.types[gameObjectType.floraTypeIndex]
        local seasonIndex = floraType.fruitSeason
        if seasonIndex then
           -- mj:log("sharedState.growFruitNextSeasonIndex true:", object.uniqueID)
            sharedState:set("growFruitNextSeasonIndex", seasonIndex)
            if floraType.fruitFrequencyInYears and floraType.fruitFrequencyInYears > 1 then
                object.sharedState:set("growFruitYearDelayCounter", floraType.fruitFrequencyInYears)
            end
            addCallbackToLoadFruit(object, seasonIndex)
        end
    end
end

function serverFlora:getIsInvalidGrowthMedium(object)
    local soilQuality = serverFlora:getGrowthMediumQuality(object)
    return soilQuality == flora.soilQualities.invalid
end

function serverFlora:dropItemsDueToWind(object)
    local objectState = object.sharedState
    local orderGameObjectType = gameObject.types[object.objectTypeIndex]
    local revertToSeedlingGatherResourceCounts = orderGameObjectType.revertToSeedlingGatherResourceCounts
    local startPos = object.pos + object.normalizedPos * mj:mToP(2.0)
    
    local cachedWindDirection = nil
    local function getWindDirection()
        if cachedWindDirection then
            return cachedWindDirection
        end
        cachedWindDirection = serverWorld:getWindDirection(object.normalizedPos)
        return cachedWindDirection
    end

    local function blowObjectAway(objectInfo)
        
        local flyDirection = normalize(getWindDirection() + rng:randomVec() * 0.5 + object.normalizedPos * 0.25)
        local flyVelocity = flyDirection * mj:mToP(10.0) * (0.5 + rng:randomValue())

        local resourceType = resource.types[gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex]
        if resourceType.impactCausesInjury or resourceType.impactCausesMajorInjury then
            --mj:log("serverFlora impactCausesInjury")
            local halfSecondLocation = startPos + flyVelocity * 0.5
            local closeSapiens = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.sapiens, halfSecondLocation, mj:mToP(10.0))
            if closeSapiens and #closeSapiens > 0 then
                --mj:log("serverFlora found close sapiens:", #closeSapiens)
                local randomSapienInfo = closeSapiens[rng:randomInteger(#closeSapiens) + 1]
                local targetSapien = serverGOM:getObjectWithID(randomSapienInfo.objectID)
                if targetSapien and (not targetSapien.sharedState.covered) then
                    flyVelocity = (targetSapien.pos - startPos) * 2.0
                    
                    --mj:log("serverFlora calling serverSapien:fallAndGetInjured:", targetSapien.uniqueID)
                    
                    local options = {
                        preventMajorInjuries = (not resourceType.impactCausesMajorInjury),
                        hitByFlyingObjectTypeIndex = objectInfo.objectTypeIndex,
                    }
                    serverSapien:fallAndGetInjured(targetSapien, flyDirection, options)
                end
            end
        end
        
        serverGOM:throwObjectWithVelocity(objectInfo, startPos, flyVelocity)
            
        serverFlora:updateGatherableResourceSets(object)
    end

    if revertToSeedlingGatherResourceCounts then
       -- mj:log("reverting flora to seedling due to wind:", object.uniqueID)
        for objectTypeIndex,count in pairs(revertToSeedlingGatherResourceCounts) do
            for i=1,count do
                blowObjectAway({objectTypeIndex = objectTypeIndex})
            end
        end
        serverFlora:revertToSaplingForHarvest(object)
    else
       -- mj:log("dropping flora inventory due to wind:", object.uniqueID)
        local inventory = objectState.inventory
        if inventory then
            local countsByObjectType = inventory.countsByObjectType
            if countsByObjectType then
                local gatherableTypes = orderGameObjectType.gatherableTypes
                if gatherableTypes then
                    for j,objectTypeIndex in ipairs(gatherableTypes) do
                        if countsByObjectType[objectTypeIndex] and countsByObjectType[objectTypeIndex] > 0 then
                            local resourceCount = countsByObjectType[objectTypeIndex]

                            local minQuantityToKeep = 0
                            if orderGameObjectType.gatherKeepMinQuantity and orderGameObjectType.gatherKeepMinQuantity[objectTypeIndex] then
                                minQuantityToKeep = orderGameObjectType.gatherKeepMinQuantity[objectTypeIndex]
                            end
                            
                            resourceCount = resourceCount - minQuantityToKeep

                            if resourceCount > 0 then
                                local objectInfo = serverGOM:removeGatherObjectFromInventory(object, objectTypeIndex)
                                blowObjectAway(objectInfo)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
        
    serverResourceManager:updateResourcesForObject(object)
    planManager:updateAnyPlansForInventoryGatherRemoval(object)
end

function serverFlora:harvestInventoryAndReturnInfos(object)

    local resultInfos = {}

    serverGOM:ensureSharedStateLoaded(object)

    local objectState = object.sharedState
    local orderGameObjectType = gameObject.types[object.objectTypeIndex]
    local revertToSeedlingGatherResourceCounts = orderGameObjectType.revertToSeedlingGatherResourceCounts

    if revertToSeedlingGatherResourceCounts then
        for objectTypeIndex,count in pairs(revertToSeedlingGatherResourceCounts) do
            for i=1,count do
                table.insert(resultInfos, {objectTypeIndex = objectTypeIndex})
            end
        end
        serverFlora:revertToSaplingForHarvest(object)
    else
        local inventory = objectState.inventory
        if inventory then
            local countsByObjectType = inventory.countsByObjectType
            if countsByObjectType then
                local gatherableTypes = orderGameObjectType.gatherableTypes
                if gatherableTypes then
                    for j,objectTypeIndex in ipairs(gatherableTypes) do
                        if countsByObjectType[objectTypeIndex] and countsByObjectType[objectTypeIndex] > 0 then
                            local resourceCount = countsByObjectType[objectTypeIndex]

                            local minQuantityToKeep = 0
                            if orderGameObjectType.gatherKeepMinQuantity and orderGameObjectType.gatherKeepMinQuantity[objectTypeIndex] then
                                minQuantityToKeep = orderGameObjectType.gatherKeepMinQuantity[objectTypeIndex]
                            end
                            
                            resourceCount = resourceCount - minQuantityToKeep

                            if resourceCount > 0 then
                                for k =1,resourceCount do
                                    local objectInfo = serverGOM:removeGatherObjectFromInventory(object, objectTypeIndex)
                                    table.insert(resultInfos, objectInfo)
                                end
                            end
                        end
                    end
                end
            end
        end
     end
     serverFlora:updateGatherableResourceSets(object)

     return resultInfos
end

function serverFlora:updateForChangedSoilQuality(object)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if gameObjectType.isSapling then
        --mj:log("serverFlora:updateForChangedSoilQuality:", object.uniqueID)
        local soilQuality = serverFlora:getGrowthMediumQuality(object)
        if soilQuality ~= object.sharedState.soilQuality then
            local callbackWorldTime = serverFlora:calculateMatureTimeForSapling(object, soilQuality)
            
            if callbackWorldTime then
                object.sharedState:set("matureTime", callbackWorldTime)
                object.sharedState:set("soilQuality", soilQuality)
                addCallbackToGrowSapling(object)
                --mj:log("serverFlora:updateForChangedSoilQuality called addCallbackToGrowSapling:", object.uniqueID, " matureTime:", object.sharedState.matureTime)
            else
                serverGOM:removeGameObjectAndDropInventory(object.uniqueID, nil, false, nil, nil, nil, nil)
                --mj:log("removed flora due to invalid soil in serverFlora:updateForChangedSoilQuality")
            end
        end
    end
end

function serverFlora:calculateMatureTimeForSapling(object, soilQuality)
    local saplingGameObjectType = gameObject.types[object.objectTypeIndex]
    --mj:log("saplingGameObjectType:", saplingGameObjectType)
    local floraInfo = flora.types[saplingGameObjectType.floraTypeIndex]
    local callbackWorldTime = nil

    
   -- mj:log("soilQuality:", soilQuality)

    local maturityDuration = nil
    if floraInfo.maturityDurationDays then
        maturityDuration = serverWorld:getDayLength() * floraInfo.maturityDurationDays
    else
        maturityDuration = serverWorld:getYearLength()
    end
    
    local growthSpeedMultiplier = 1.0
    if soilQuality ~= flora.soilQualities.invalid then
        if soilQuality == flora.soilQualities.veryPoor then
            growthSpeedMultiplier = 0.25
        elseif soilQuality == flora.soilQualities.poor then
            growthSpeedMultiplier = 0.5
        elseif soilQuality == flora.soilQualities.rich then
            growthSpeedMultiplier = 2.0
        end

        local currentTime = serverWorld:getWorldTime()
        local plantTime = object.sharedState.plantTime or currentTime
        
        callbackWorldTime = math.max(plantTime + (maturityDuration / growthSpeedMultiplier), currentTime) + 10.0 + rng:valueForUniqueID(object.uniqueID, 18754) * 20.0
    end
        
    return callbackWorldTime
end

function serverFlora:growSaplingImmediately(incomingObject)
    local sharedState = incomingObject.sharedState
    if sharedState.matureTime then
        growSapling(incomingObject)
    end
end

function serverFlora:init(serverGOM_, serverWorld_, planManager_, serverSapien_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    planManager = planManager_
    serverSapien = serverSapien_

    serverGOM:addObjectLoadedFunctionForTypes(gameObject.floraTypes, function(object)
        local gameObjectType = gameObject.types[object.objectTypeIndex]
        local removed = false
        if serverGOM:isStored(object.uniqueID) then
            local sharedState = object.sharedState
            if gameObjectType.isSapling then
                if not sharedState.plantTime then
                    sharedState:set("plantTime", serverWorld:getWorldTime())
                end

                if not sharedState.matureTime then
                    local soilQuality = serverFlora:getGrowthMediumQuality(object)
                    local callbackWorldTime = serverFlora:calculateMatureTimeForSapling(object, soilQuality)
                    
                    if callbackWorldTime then
                        sharedState:set("matureTime", callbackWorldTime)
                        sharedState:set("soilQuality", soilQuality)
                    else
                        serverGOM:removeGameObjectAndDropInventory(object.uniqueID, nil, false, nil, nil, nil, nil)
                        mj:log("removed flora due to invalid soil in load function")
                        removed = true
                    end
                end
                if not removed then
                    addCallbackToGrowSapling(object)
                    serverGOM:addObjectToSet(object, serverGOM.objectSets.soilQualityStatusObservers)
                end
            else
                if sharedState and sharedState.growFruitNextSeasonIndex then
                    addCallbackToLoadFruit(object, sharedState.growFruitNextSeasonIndex)
                end
                
            end
            if not removed then
                serverGOM:addObjectToSet(object, serverGOM.objectSets.windAffectedModerateChance)
            end
        end

        if not removed then
            serverFlora:updateGatherableResourceSets(object)
        end

        return removed
    end)
    
    serverGOM:addTransientInspectionFunctionForTypes(gameObject.floraTypes, function(object)
        if not serverGOM:isStored(object.uniqueID) then
            local gameObjectType = gameObject.types[object.objectTypeIndex]
            local floraType = flora.types[gameObjectType.floraTypeIndex]
            if floraType.fruitFrequencyInYears and floraType.fruitFrequencyInYears > 1 then
                local hasFruit = (rng:integerForUniqueID(object.uniqueID, 82221, floraType.fruitFrequencyInYears) == 1)
                if not hasFruit then
                    local seasonIndex = floraType.fruitSeason
                    if seasonIndex then
                        local delayCounter = rng:integerForUniqueID(object.uniqueID, 92782, floraType.fruitFrequencyInYears)
                        if delayCounter > 0 then
                            object.sharedState:set("growFruitYearDelayCounter", delayCounter)
                        end
                        object.sharedState:set("growFruitNextSeasonIndex", seasonIndex)
                        mj:log("transient big tree adding state:", object.sharedState)
                        addCallbackToLoadFruit(object, seasonIndex)
                    end
                end
            end
        end
    end)
    
end

return serverFlora