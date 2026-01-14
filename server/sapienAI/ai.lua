local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local dot = mjm.dot
local clamp = mjm.clamp
local length = mjm.length
local length2 = mjm.length2
--local mat3Identity = mjm.mat3Identity
local mat3GetRow = mjm.mat3GetRow

local gameObject = mjrequire "common/gameObject"
local order = mjrequire "common/order"
local plan = mjrequire "common/plan"
local skill = mjrequire "common/skill"
--local skillLearning = mjrequire "common/skillLearning"
local action = mjrequire "common/action"
local need = mjrequire "common/need"
local model = mjrequire "common/model"
local statusEffect = mjrequire "common/statusEffect"
local actionSequence = mjrequire "common/actionSequence"
local pathFinding = mjrequire "common/pathFinding"
local sapienTrait = mjrequire "common/sapienTrait"
local rng = mjrequire "common/randomNumberGenerator"
local physics = mjrequire "common/physics"
local physicsSets = mjrequire "common/physicsSets"
local constructable = mjrequire "common/constructable"
local resource = mjrequire "common/resource"
local sapienInventory = mjrequire "common/sapienInventory"
local storage = mjrequire "common/storage"
local sapienConstants = mjrequire "common/sapienConstants"
local desire = mjrequire "common/desire"
local mood = mjrequire "common/mood"
local fuel = mjrequire "common/fuel"
local tool = mjrequire "common/tool"
local research = mjrequire "common/research"
local objectInventory = mjrequire "common/objectInventory"
local worldHelper = mjrequire "common/worldHelper"
local gameConstants = mjrequire "common/gameConstants"
local maintenance = mjrequire "common/maintenance"
--local notification = mjrequire "common/notification"

local activeOrderAI = mjrequire "server/sapienAI/activeOrderAI"
local findOrderAI = mjrequire "server/sapienAI/findOrderAI"
local multitask = mjrequire "server/sapienAI/multitask"
local conversation = mjrequire "server/sapienAI/conversation"
local lookAI = mjrequire "server/sapienAI/lookAI"

local terrain = mjrequire "server/serverTerrain"
local serverStorageArea = mjrequire "server/serverStorageArea"
local serverResourceManager = mjrequire "server/serverResourceManager"
local planManager = mjrequire "server/planManager"
--local serverCraftArea = mjrequire "server/serverCraftArea"
local serverSapienSkills = mjrequire "server/serverSapienSkills"
local serverFuel = mjrequire "server/serverFuel"
local serverTutorialState = mjrequire "server/serverTutorialState"
local serverStatusEffects = mjrequire "server/serverStatusEffects"
local serverCompostBin = mjrequire "server/objects/serverCompostBin"
local serverWeather = mjrequire "server/serverWeather"
local serverLogistics = mjrequire "server/serverLogistics"
local serverTribeAIPlayer = mjrequire "server/serverTribeAIPlayer"
--local serverSeat = mjrequire "server/objects/serverSeat"
--local planLightProbes = mjrequire "server/planLightProbes"
--local serverSapienInventory = mjrequire "server/serverSapienInventory"

local serverSapienAI = {}


local serverSapien = nil
local serverGOM = nil
local serverWorld = nil
local serverDestination = nil

serverSapienAI.aiStates = {}


local clearWeightCloseObject = 8.0
local clearMinHeuristic = -20.0

local maxLightSeakDistance = mj:mToP(100.0)
local minLightSeakDistanceToBother = mj:mToP(8.0)

serverSapienAI.maxWarmthSeakDistance = mj:mToP(200.0)
local minWarmthSeakDistanceToBother = mj:mToP(4.0)

local minSitHeight = 1.0 - mj:mToP(0.1)
local minSitHeight2 = minSitHeight * minSitHeight


serverSapienAI.socialLength = 12.0 -- sapiens will be social for this period of time, then won't be social (unless talked to). Makes them talk less overall, and in bursts
serverSapienAI.antiSocialLength = 40.0
local totalSocialTimersLength = serverSapienAI.socialLength + serverSapienAI.antiSocialLength
    
local function clearHeuristic(dotProduct, distance)
    local distanceWeight = -(distance / mj:mToP(100.0)) * clearWeightCloseObject
    return dotProduct + distanceWeight
end


local randomCheckSeed = 1

local function addOrderToDropHeldItem(sapien, orderContext)
    local cancelCurrentOrders = true
   --mj:log("addOrderToDropHeldItem:", sapien.uniqueID)
   -- mj:log("addOrderToDropHeldItemInfo:", sapien.sharedState)
    --mj:log(debug.traceback())
    serverSapien:addOrder(sapien, order.types.dropObject.index, nil, nil, orderContext, cancelCurrentOrders)
    return true
end

function serverSapienAI:getPrivateAIState(sapien)
    local privateState = sapien.privateState
    if not privateState.ai then
        privateState.ai = {}
    end
    return privateState.ai
end


--function serverSapienAI:getPrefferedObject(sapien)


function serverSapienAI:addOrderToTakeHeldItemToStorage(sapien, storageObject, heldObjectTypeIndex, isTransfer)
    local storageObjectID = storageObject.uniqueID
   -- mj:log("serverSapienAI:addOrderToTakeHeldItemToStorage:", storageObjectID)
    local pathInfo = order:createOrderPathInfo(storageObjectID, pathFinding.proximityTypes.reachable, gameConstants.standardPathProximityDistance, storageObject.pos, nil, storageObject.pos)
    local cancelCurrentOrders = false
    local orderTypeIndex = order.types.deliverObjectToStorage.index
    if isTransfer then
        orderTypeIndex = order.types.deliverObjectTransfer.index
    end
    serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, storageObject, {
        objectTypeIndex = heldObjectTypeIndex,
    }, cancelCurrentOrders)
    return true
end

local function getProximitType(planTypeIndex)
    local proximityType = pathFinding.proximityTypes.reachable
    if planTypeIndex then
        local planType = plan.types[planTypeIndex]
        if planType.skipFinalReachableCollisionPathCheck then
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest
        elseif planType.skipFinalReachableCollisionAndVerticalityPathCheck then
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests
        end
    end
    return proximityType
end

function serverSapienAI:addOrderToTakeHeldItemToCraftAreaOrBuildingSite(sapien, dropOffLocationObject, objectTypeIndex, planTypeIndex, planState)
    --local dropPos = serverGOM:getDropOffLocationForResourceForBuildOrCraftObject(dropOffLocationObject, objectTypeIndex)
    local dropOffLocationObjectID = dropOffLocationObject.uniqueID
    --mj:log("serverSapienAI:addOrderToTakeHeldItemToCraftAreaOrBuildingSite:", dropOffLocationObjectID)
    local proximityType = getProximitType(planTypeIndex)
    
    local pathInfo = order:createOrderPathInfo(dropOffLocationObjectID, proximityType, gameConstants.buildPathProximityDistance, dropOffLocationObject.pos, nil, dropOffLocationObject.pos)

    local orderContext = {
        planObjectID = dropOffLocationObjectID,
        planTypeIndex = planTypeIndex,
        objectTypeIndex = objectTypeIndex,
        researchTypeIndex = planState.researchTypeIndex,
        discoveryCraftableTypeIndex = planState.discoveryCraftableTypeIndex,
    }

    local orderTypeIndex = order.types.deliverObjectToConstructionObject.index
    if planTypeIndex == plan.types.light.index or planTypeIndex == plan.types.addFuel.index then
        orderTypeIndex = order.types.deliverFuel.index
    end

    local cancelCurrentOrders = false
    serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, dropOffLocationObject, orderContext, cancelCurrentOrders)

    return true
end

function serverSapienAI:addOrderToDeliverHeldItemFuel(sapien, dropOffLocationObject, objectTypeIndex, planTypeIndex)
    local dropOffLocationObjectID = dropOffLocationObject.uniqueID
    --mj:log("serverSapienAI:addOrderToDeliverHeldItemFuel:", dropOffLocationObjectID)
    local proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests
    local pathInfo = order:createOrderPathInfo(dropOffLocationObjectID, proximityType, gameConstants.standardPathProximityDistance, dropOffLocationObject.pos, nil, dropOffLocationObject.pos)
    local cancelCurrentOrders = false
    serverSapien:addOrder(sapien, order.types.deliverFuel.index, pathInfo, dropOffLocationObject, {
        planObjectID = dropOffLocationObjectID,
        objectTypeIndex = objectTypeIndex,
        planTypeIndex = planTypeIndex,
    }, cancelCurrentOrders)

    return true
end

function serverSapienAI:addOrderToDeliverHeldItemToCompost(sapien, dropOffLocationObject, objectTypeIndex, planTypeIndex)
    local dropOffLocationObjectID = dropOffLocationObject.uniqueID
    --mj:log("serverSapienAI:addOrderToDeliverHeldItemFuel:", dropOffLocationObjectID)
    local proximityType = getProximitType(planTypeIndex)
    local pathInfo = order:createOrderPathInfo(dropOffLocationObjectID, proximityType, gameConstants.standardPathProximityDistance, dropOffLocationObject.pos, nil, dropOffLocationObject.pos)
    local cancelCurrentOrders = false
    serverSapien:addOrder(sapien, order.types.deliverToCompost.index, pathInfo, dropOffLocationObject, {
        planObjectID = dropOffLocationObjectID,
        objectTypeIndex = objectTypeIndex,
        planTypeIndex = planTypeIndex,
    }, cancelCurrentOrders)

    return true
end

function serverSapienAI:addOrderToDeliverPlanObjectForCraftingElsewhere(sapien, dropOffLocationObject, objectTypeIndex, heldObjectPlanState)
    local dropOffLocationObjectID = dropOffLocationObject.uniqueID
    local pathInfo = order:createOrderPathInfo(dropOffLocationObjectID, pathFinding.proximityTypes.reachable, gameConstants.standardPathProximityDistance, dropOffLocationObject.pos, nil, dropOffLocationObject.pos)
    local cancelCurrentOrders = false

    local planTypeIndex = nil
    if heldObjectPlanState then
        planTypeIndex = heldObjectPlanState.planTypeIndex
    end

    serverSapien:addOrder(sapien, order.types.deliverPlanObjectForCraftingOrResearchElsewhere.index, pathInfo, dropOffLocationObject, {
        planObjectID = dropOffLocationObjectID,
        objectTypeIndex = objectTypeIndex,
        planTypeIndex = planTypeIndex,
    }, cancelCurrentOrders)

    return true
end

function serverSapienAI:addOrderToDropHeldItem(sapien)
    local lastHeldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
    if not lastHeldObjectInfo then
        return false
    end
    local orderContext = lastHeldObjectInfo.orderContext
    return addOrderToDropHeldItem(sapien, orderContext)
end




local function addOrderNearByAllowingUncovered(sapien, pos, orderTypeIndex, orderContext, allowUnCovered, getClose, cancelCurrentOrders)
    local basePosLength = length(pos)
    local distanceStartMeters = 2.5
    local distanceIncrementMeters = 2.5
    if getClose then
        distanceStartMeters = 1.0
        distanceIncrementMeters = 1.1
    end
    for distance = 1,8 do
        for check = 1,3 do
            --disabled--mj:objectLog(sapien.uniqueID, "addOrderNearByAllowingUncovered:",allowUnCovered, " distance:", distance, " check:", check)
            randomCheckSeed = randomCheckSeed + 1
            local randomVec = rng:vecForUniqueID(sapien.uniqueID, randomCheckSeed + 432)
            local offsetVec = normalize(pos + randomVec)
            offsetVec = normalize(offsetVec - pos)
            local randomPointNormal = normalize(pos + offsetVec * mj:mToP(distanceStartMeters + distanceIncrementMeters * distance))

            local terrainPos = terrain:getHighestDetailTerrainPointAtPoint(randomPointNormal)
            local terrainPosHeight2 = length2(terrainPos)
            --mj:log("sit terrainPosHeight2:", terrainPosHeight2, " minSitHeight2:", minSitHeight2, " sapien:", sapien.uniqueID)
            if terrainPosHeight2 > minSitHeight2 then
                local shiftedPos = terrainPos
                
                local invalid = false

                local rayResult =  physics:rayTest(randomPointNormal * (basePosLength + mj:mToP(1.5)), terrainPos, nil, nil)
                if rayResult.hasHitObject then
                    local object = serverGOM:getObjectWithID(rayResult.objectID)
                    if (not object) or (gameObject.types[object.objectTypeIndex].pathFindingDifficulty == nil) then --pathFindingDifficulty is currently used to decide if it is walkable
                        invalid = true
                    else
                        shiftedPos = rayResult.objectCollisionPoint + randomPointNormal * mj:mToP(0.05)
                    end
                end

                if not invalid then
                    if not allowUnCovered then
                        local coveredRayDirection = randomPointNormal
                        local coveredRayStart = shiftedPos + coveredRayDirection * serverGOM.coveredTestRayStartOffsetLength
                        local coveredRayEnd = coveredRayStart + coveredRayDirection * serverGOM.coveredTestRayLength
                        local coveredRayResult = physics:rayTest(coveredRayStart, coveredRayEnd, physicsSets.blocksRain, nil)
                        if (not coveredRayResult) or (not coveredRayResult.hasHitObject) then
                            --disabled--mj:objectLog(sapien.uniqueID, "no covered result")
                            invalid = true
                        end
                    end

                    if not invalid then
                        local result = physics:boxTest(shiftedPos + randomPointNormal * mj:mToP(0.5), sapien.rotation, vec3(1.0,1.0,1.0) * mj:mToP(0.4), false, physicsSets.pathColliders)
                        if result.hasHitObject then
                            --disabled--mj:objectLog(sapien.uniqueID, "failed box test")
                            invalid = true
                        end

                        if not invalid then
                            local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, shiftedPos)
                            serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, nil, orderContext, cancelCurrentOrders)
                            --mj:log("order added:", sapien.uniqueID)
                            return true
                        end
                    end
                end
            end

        end
    end
    return false
end

local function addOrderNearBy(sapien, pos, orderTypeIndex, orderContext, cancelCurrentOrders)
    local isWet = (sapien.sharedState.statusEffects[statusEffect.types.wet.index] ~= nil) or (sapien.privateState.gettingWetTimer ~= nil) or serverWeather:getIsDamagingWindStormOccuring()
    if isWet then
        local allowUnCovered = false
        if addOrderNearByAllowingUncovered(sapien, pos, orderTypeIndex, orderContext, allowUnCovered, false, cancelCurrentOrders) then
            --disabled--mj:objectLog(sapien.uniqueID, "found covered place for order type:", orderTypeIndex)
            return true
        end
        --disabled--mj:objectLog(sapien.uniqueID, "didn't find covered place for order type:", orderTypeIndex)
    end
   -- mj:log("didn't find covered place:", sapien.uniqueID)
    local allowUnCovered = true
    return addOrderNearByAllowingUncovered(sapien, pos, orderTypeIndex, orderContext, allowUnCovered, false, cancelCurrentOrders)
end


local function addOrderToMoveTowards(sapien, goalPos, minDistance, orderContext, getClose, cancelCurrentOrders)
    local routeVec = goalPos - sapien.pos
    local routeLength = length(routeVec)
    local routeNormal = routeVec / routeLength
    routeLength = routeLength - minDistance
    --disabled--mj:objectLog(sapien.uniqueID, "in addOrderToMoveTowards routeLength:", mj:pToM(routeLength))
    local routeMinLength = mj:mToP(5.0)
    if getClose then
        routeMinLength = mj:mToP(1.0)
    end
    if routeLength > routeMinLength then
        routeLength = math.min(routeLength, mj:mToP(80.0)) -- do it in 80m chunks
        local closeEnoughPos = sapien.pos + routeNormal * routeLength
        local allowUnCovered = true
        if not addOrderNearByAllowingUncovered(sapien, closeEnoughPos, order.types.moveTo.index, orderContext, allowUnCovered, getClose, cancelCurrentOrders) then
            --disabled--mj:objectLog(sapien.uniqueID, "in addOrderToMoveTowards partial no good")
            return addOrderNearByAllowingUncovered(sapien, goalPos, order.types.moveTo.index, orderContext, allowUnCovered, getClose, cancelCurrentOrders) -- partial no good, let's try all the way.
        end

        return true

        --[[for distance = 1,8 do
            for check = 1,4 do
                randomCheckSeed = randomCheckSeed + 1
                local randomVec = rng:vecForUniqueID(sapien.uniqueID, randomCheckSeed + 432)
                randomVec = normalize(randomVec)
                local offsetVec = (randomVec - closeEnoughPos)
                offsetVec = normalize(offsetVec)
                local randomPoint = normalize(closeEnoughPos + offsetVec * mj:mToP(2.0 + 1.0 * distance))

                local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(randomPoint)
                local collision = false
                
                local result = physics:boxTest(shiftedPos, mat3Identity, vec3(1.0,1.0,1.0) * mj:mToP(1.0), false, nil)
                if result.hasHitObject then
                    collision = true
                end

                if not collision then
                    local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, shiftedPos)
                    local frontOfQueue = true
                    serverSapien:addOrder(sapien, order.types.moveTo.index, pathInfo, nil, orderContext, frontOfQueue)
                    return true
                end

            end
        end]]
    end
    --mj:log("addOrderToMoveTowards failed:", sapien.uniqueID, " routeLength:", mj:pToM(routeLength))
    return false
end


serverSapienAI.maxDistanceToTravelToReturnToAssignedBed2 = mj:mToP(500.0) * mj:mToP(500.0)
serverSapienAI.maxDistanceToTravelToReturnToBed2 = mj:mToP(300.0) * mj:mToP(300.0)

function serverSapienAI:getOrCreateHomePos(sapien)
    local sharedState = sapien.sharedState

    local posToReturnTo = nil
    if sharedState.assignedBedPos and length2(sharedState.assignedBedPos - sapien.pos) < serverSapienAI.maxDistanceToTravelToReturnToAssignedBed2 then
        posToReturnTo = sharedState.assignedBedPos
    end
    if not posToReturnTo then
        if sharedState.homePos and length2(sharedState.homePos - sapien.pos) < serverSapienAI.maxDistanceToTravelToReturnToBed2 then
            posToReturnTo = sharedState.homePos
        end
    end 

    if not posToReturnTo then
        if serverTribeAIPlayer:getIsAIPlayerTribe(sapien.sharedState.tribeID) then
            local destinationState = serverDestination:getDestinationState(sapien.sharedState.tribeID)
            if destinationState then
                posToReturnTo = destinationState.pos
            end
        end
    end

    if not posToReturnTo then
        local closestBedPos = nil
        local closestDistance2 = serverSapienAI.maxDistanceToTravelToReturnToBed2
        if (not sapien.privateState.noBedsNearByLastCheckTime) or (serverWorld:getWorldTime() - sapien.privateState.noBedsNearByLastCheckTime > 2000.0) then
            serverGOM:callFunctionForObjectsInSet(serverGOM.objectSets.beds, function(objectID)
                local bed = serverGOM:getObjectWithID(objectID)
                if bed then
                    if serverGOM:objectIsInaccessible(bed) then
                        return
                    end

                    local bedTribeID = bed.sharedState.tribeID
                    if bedTribeID ~= sapien.sharedState.tribeID then
                        if serverWorld:tribeIsValidOwner(bedTribeID) then
                            local relationshipSettings = serverWorld:getTribeRelationsSettings(bedTribeID, sapien.sharedState.tribeID)
                            if not (relationshipSettings and relationshipSettings.allowBedUse) then
                                return
                            end
                        end
                    end

                    local bedDistance2 = length2(sapien.pos - bed.pos)
                    if bedDistance2 < closestDistance2 then
                        closestDistance2 = bedDistance2
                        closestBedPos = bed.pos
                    end
                end
            end)
        end

        if closestBedPos then
            sharedState:set("homePos", closestBedPos)
            sapien.privateState.noBedsNearByLastCheckTime = nil
            posToReturnTo = closestBedPos
        else
            sapien.privateState.noBedsNearByLastCheckTime = serverWorld:getWorldTime() --optimization, don't iterate over all the beds every time
        end
    end

    return posToReturnTo
end

local returnHomeToSleepMinDistanceToBother = mj:mToP(100.0)

function serverSapienAI:addOrderToReturnCloseToHomePosIfNeeded(sapien, sleepDesire)
    local sharedState = sapien.sharedState
    if sharedState.nomad then
        return false
    end

    if sharedState.preventUnnecessaryAutomaticOrderTimer then
        return
    end

    if sleepDesire < desire.levels.moderate then
        --disabled--mj:objectLog(sapien.uniqueID, "in serverSapienAI:addOrderToReturnCloseToHomePosIfNeeded sleepDesire < desire.levels.moderate")
        return false
    end

    if sharedState.manualAssignedPlanObject then
        --disabled--mj:objectLog(sapien.uniqueID, "in serverSapienAI:addOrderToReturnCloseToHomePosIfNeeded manualAssignedPlanObject so not returning home")
        return false
    end

    --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:addOrderToReturnCloseToHomePosIfNeeded")

    
    local posToReturnTo = serverSapienAI:getOrCreateHomePos(sapien)
    if not posToReturnTo then
        return false
    end
    --disabled--mj:objectLog(sapien.uniqueID, "in serverSapienAI:addOrderToReturnCloseToHomePosIfNeeded")

    local orderContext = {
        moveToMotivation = order.moveToMotivationTypes.bed.index
    }

    return addOrderToMoveTowards(sapien, posToReturnTo, returnHomeToSleepMinDistanceToBother, orderContext, false, true)
end

function serverSapienAI:addOrderToReturnCloseToHomePosDueToThreat(sapien, threatObjectPos)

    --mj:log("serverSapienAI:addOrderToReturnCloseToHomePosDueToThreat")
    local orderContext = {
        moveToMotivation = order.moveToMotivationTypes.avoidThreat.index
    }

    local posToReturnTo = serverSapienAI:getOrCreateHomePos(sapien)   
    if posToReturnTo then
        local bedVec = posToReturnTo - sapien.pos
        local bedDistance = length(bedVec)
        if bedDistance < mj:mToP(500.0) then
            local bedDir = bedVec / bedDistance
            if dot(bedDir, normalize(threatObjectPos - sapien.pos)) < 0.0 then
                if addOrderToMoveTowards(sapien, posToReturnTo, 0.0, orderContext, false, true) then --todo if we are < 50m from bed, add an order to sit on it instead
                    --mj:log("serverSapienAI:addOrderToReturnCloseToHomePosDueToThreat posToReturnTo success")
                    return true
                end
            end
        end
    end

    local runAwayDirection = normalize(sapien.pos - threatObjectPos)
    local moveToDir = normalize(runAwayDirection + rng:vec() * 0.2)
    local moveToPos = sapien.pos + moveToDir * mj:mToP(rng:randomValue() * 10.0 + 40.0)
    local clampToSeaLevel = true
    moveToPos = worldHelper:getBelowSurfacePos(moveToPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)

    if addOrderToMoveTowards(sapien, moveToPos, 0.0, orderContext, false, true) then
        --mj:log("serverSapienAI:addOrderToReturnCloseToHomePosDueToThreat moveToPos success")
        return true
    end
    return false
end


function serverSapienAI:addOrderToMoveNearLight(sapien)
    if sapien.sharedState.nomad then
        return false
    end

    local bestDistance2 = 999.0
    local bestObjectID = nil
    
    local allLightObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.lightEmitters, sapien.pos, maxLightSeakDistance)
    for i,info in ipairs(allLightObjectInfos) do
        if info.distance2 < bestDistance2 then
            bestDistance2 = info.distance2
            bestObjectID = info.objectID
        end
    end

    if bestObjectID then
        local object = serverGOM:getObjectWithID(bestObjectID)
        if object then
            
            local orderContext = {
                moveToMotivation = order.moveToMotivationTypes.light.index
            }
    
            --mj:log("adding order to move towards light. Sapien:", sapien.uniqueID, " light:", object.uniqueID)
            return addOrderToMoveTowards(sapien, object.pos, minLightSeakDistanceToBother, orderContext, false, true)
        end
    end

    return false
end

function serverSapienAI:addOrderToMoveNearWarmth(sapien)
    if sapien.sharedState.nomad then
        return false
    end
    
    local bestDistance2 = 999.0
    local bestObjectID = nil
    
    local allObjectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.temperatureIncreasers, sapien.pos, serverSapienAI.maxWarmthSeakDistance)
    for i,info in ipairs(allObjectInfos) do
        if info.distance2 < bestDistance2 then
            bestDistance2 = info.distance2
            bestObjectID = info.objectID
        end
    end
    
    if bestObjectID then
        local object = serverGOM:getObjectWithID(bestObjectID)
        if object then
            
            local orderContext = {
                moveToMotivation = order.moveToMotivationTypes.warmth.index
            }
    
            --mj:log("adding order to move towards warmth. Sapien:", sapien.uniqueID, " light:", object.uniqueID)
            return addOrderToMoveTowards(sapien, object.pos, minWarmthSeakDistanceToBother, orderContext, true, true)
        end
    end

    return false
end

function serverSapienAI:addOrderToFindPlaceNearByToSit(sapien, pos, orderContext, onlyAddIfCovered, cancelCurrentOrders)
    if onlyAddIfCovered then
        local allowUnCovered = false
        return addOrderNearByAllowingUncovered(sapien, pos, order.types.sit.index, orderContext, allowUnCovered, false, cancelCurrentOrders)
    end
    return addOrderNearBy(sapien, pos, order.types.sit.index, orderContext, cancelCurrentOrders)
end

function serverSapienAI:addOrderToFindPlaceOnGroundToSleep(sapien, orderContext)
    return addOrderNearBy(sapien, sapien.pos, order.types.sleep.index, orderContext, true)
    --[[for distance = 1,8 do
        for check = 1,4 do
            randomCheckSeed = randomCheckSeed + 1
            local randomVec = rng:vecForUniqueID(sapien.uniqueID, randomCheckSeed + 432)
            randomVec = normalize(randomVec)
            local offsetVec = (randomVec - sapien.pos)
            offsetVec = normalize(offsetVec)
            local randomPoint = normalize(sapien.pos + offsetVec * mj:mToP(8.0 + distance))

            local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(randomPoint)
            if length2(shiftedPos) > 1.0 - mj:mToP(0.01) then --length2 so it's not exact, just a slight fudge to avoid undefined precision problems
                local collision = false
                
                local result = physics:boxTest(shiftedPos, mat3Identity, vec3(1.0,1.0,1.0) * mj:mToP(1.0), false, nil)
                if result.hasHitObject then
                    collision = true
                end

                if not collision then
                    local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, shiftedPos)
                    local frontOfQueue = true
                    serverSapien:addOrder(sapien, order.types.sleep.index, pathInfo, nil, orderContext, frontOfQueue)
                    return true
                end
            end

        end
    end
    return false]]
end


local function addOrderToTakeHeldItemAway(sapien, orderContext, orderTypeIndex)
    local allowUnCovered = true
    local cancelCurrentOrders = true
    return addOrderNearByAllowingUncovered(sapien, sapien.pos, orderTypeIndex, orderContext, allowUnCovered, false, cancelCurrentOrders)
    --mj:log("addOrderToTakeHeldItemAway orderContext:", orderContext)
    --[[for distance = 1,8 do
        for check = 1,4 do
            randomCheckSeed = randomCheckSeed + 1
            local randomVec = rng:vecForUniqueID(sapien.uniqueID, randomCheckSeed + 432)
            randomVec = normalize(sapien.normalizedPos + randomVec * 0.001)
            local offsetVec = (randomVec - sapien.normalizedPos)
            offsetVec = normalize(offsetVec)
            local randomPoint = normalize(sapien.pos + offsetVec * mj:mToP(4.0 + distance * 2.0))

            local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(randomPoint)
            local collision = false
            
            local result = physics:boxTest(shiftedPos, mat3Identity, vec3(1.0,1.0,1.0) * mj:mToP(1.0), false, nil)
            
            if result.hasHitObject then
                collision = true
            end

            if not collision then
                local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil,  shiftedPos)
                local frontOfQueue = true
                serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, nil, orderContext, frontOfQueue)
                return true
            end

        end
    end
    return false]]
end


function serverSapienAI:addOrderToDisposeOfHeldItem(sapien)
    local lastHeldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
    if not lastHeldObjectInfo then
        return false
    end

    local shouldDrop = false
    
    if sapien.sharedState.isStuck then
        --disabled--mj:objectLog(sapien.uniqueID, "dropping instead of storing due to isStuck")
        shouldDrop = true
    elseif desire:getCachedSleep(sapien, sapien.temporaryPrivateState, function() 
        return serverWorld:getTimeOfDayFraction(sapien.pos) 
    end) >= desire.levels.strong then --desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos)) >= desire.levels.strong then
        --disabled--mj:objectLog(sapien.uniqueID, "dropping instead of storing due to sleepDesire")
        shouldDrop = true
    elseif statusEffect:cantDoMostWorkDueToEffects(sapien.sharedState.statusEffects) then
        --disabled--mj:objectLog(sapien.uniqueID, "dropping instead of storing due to status effects")
        shouldDrop = true
    else
        if lookAI:checkIsTooColdAndBusyWarmingUp(sapien) then
            --disabled--mj:objectLog(sapien.uniqueID, "dropping instead of storing due to status effects")
            shouldDrop = true
        end
    end
    
    if shouldDrop then
        if addOrderToDropHeldItem(sapien, nil) then
            return true
        end
    end

    local orderContext = lastHeldObjectInfo.orderContext
    local pickedUpObjectOrderTypeIndex = nil
    if orderContext then
        pickedUpObjectOrderTypeIndex = orderContext.orderTypeIndex
    end
    
    if pickedUpObjectOrderTypeIndex == order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index then
        if addOrderToTakeHeldItemAway(sapien, orderContext, order.types.deliverPlanObjectForCraftingOrResearchElsewhere.index) then
            return true
        end
    elseif pickedUpObjectOrderTypeIndex ~= order.types.transferObject.index then
        local matchInfo = serverStorageArea:bestStorageAreaForObjectType(sapien.sharedState.tribeID, lastHeldObjectInfo.objectTypeIndex, sapien.pos, nil)
        if matchInfo then
            local storageObject = matchInfo.object
            if serverSapienAI:addOrderToTakeHeldItemToStorage(sapien, storageObject, lastHeldObjectInfo.objectTypeIndex, false) then
                return true
            end
        end

        if pickedUpObjectOrderTypeIndex == order.types.removeObject.index then
            ----disabled--mj:objectLog(sapien.uniqueID, "pickedUpObjectOrderTypeIndex == order.types.removeObject.index orderContext:", orderContext)
            if addOrderToTakeHeldItemAway(sapien, nil, order.types.disposeOfObject.index) then
                return true
            end
        end
    end

    return addOrderToDropHeldItem(sapien, orderContext)
end

function serverSapienAI:addOrderToEatHeldItem(sapien)
    local firstObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
    if firstObjectInfo then
        local foodValue = resource.types[gameObject.types[firstObjectInfo.objectTypeIndex].resourceTypeIndex].foodValue

        if foodValue then
            
            local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(sapien.sharedState.tribeID)
            if resourceBlockLists then
                local eatFoodBlockList = resourceBlockLists.eatFoodList
                if eatFoodBlockList and eatFoodBlockList[firstObjectInfo.objectTypeIndex] then
                    return false
                end
            end
            
            local pickedUpObjectOrderTypeIndex = nil
            if firstObjectInfo.orderContext then
                pickedUpObjectOrderTypeIndex = firstObjectInfo.orderContext.orderTypeIndex
            end

            if pickedUpObjectOrderTypeIndex == order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index then
                return false
            end

            local cancelCurrentOrders = true
            local orderContext = nil
            serverSapienAI.aiStates[sapien.uniqueID].lastAteTime = serverWorld:getWorldTime()
            serverSapien:addOrder(sapien, order.types.eat.index, nil, nil, orderContext, cancelCurrentOrders)
            return true
        end
    end
    return false
end

function serverSapienAI:addOrderToRemoveClothingItem(sapien, inventoryLocation)
    local cancelCurrentOrders = true
    local orderContext = {
        inventoryLocation = inventoryLocation,
    }
    serverSapien:addOrder(sapien, order.types.takeOffClothing.index, nil, nil, orderContext, cancelCurrentOrders)
    return true
end

function serverSapienAI:addOrderToPutOnHeldItem(sapien, inventoryLocation)
    local firstObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
    if firstObjectInfo then
        local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(sapien.sharedState.tribeID)
        if resourceBlockLists then
            local wearClothingBlockList = resourceBlockLists.wearClothingList
            if wearClothingBlockList and wearClothingBlockList[firstObjectInfo.objectTypeIndex] then
                return false
            end
        end
        

        local cancelCurrentOrders = true
        local orderContext = {
            inventoryLocation = inventoryLocation,
        }
        serverSapien:addOrder(sapien, order.types.putOnClothing.index, nil, nil, orderContext, cancelCurrentOrders)
        return true
    end
    return false
end

function serverSapienAI:addOrderToPlayHeldItem(sapien, inventoryLocation, heldObjectOrderContext)
    local orderContext = {
        inventoryLocation = inventoryLocation
    }
    
    if heldObjectOrderContext then
        if heldObjectOrderContext.planState then
            orderContext.planTypeIndex = heldObjectOrderContext.planState.planTypeIndex
            orderContext.researchTypeIndex = heldObjectOrderContext.planState.researchTypeIndex
            orderContext.discoveryCraftableTypeIndex = heldObjectOrderContext.planState.discoveryCraftableTypeIndex
        end
    end

    
    local campfireInfosBySet = serverGOM:getGameObjectsInSetsWithinNormalizedRadiusOfPos({serverGOM.objectSets.litCampfires}, sapien.normalizedPos, mj:mToP(20.0))
    local campfireInfos = campfireInfosBySet[serverGOM.objectSets.litCampfires]
    if campfireInfos and #campfireInfos > 0 then
        --mj:log("found campfires")
        local randomCampfireIndex = rng:randomInteger(#campfireInfos) + 1
        local campfire = serverGOM:getObjectWithID(campfireInfos[randomCampfireIndex].objectID)
        if campfire then
            if addOrderNearBy(sapien, campfire.pos, order.types.playInstrument.index, orderContext, true) then
               -- mj:log("add campfire order")
                return true
            end
        end
    end

    return addOrderNearBy(sapien, sapien.pos, order.types.playInstrument.index, orderContext, true)
end

function serverSapienAI:addOrderToFetchResource(sapien, resourceInfo, requiredCount, planObjectID, planTypeIndex, lookAtIntent)
    local orderObject = serverGOM:getObjectWithID(resourceInfo.objectID)
    if not orderObject then
        return false
    end
    local orderTypeIndex = nil
    --mj:log("resourceInfo:", resourceInfo)
    if resourceInfo.providerType == serverResourceManager.providerTypes.gatherRequired then
        orderTypeIndex = order.types.gather.index
    else
        orderTypeIndex = order.types.pickupObject.index
    end
    local orderContext = {
        objectTypeIndex = resourceInfo.objectTypeIndex,
        requiredCount = requiredCount,
        planObjectID = planObjectID,
        planTypeIndex = planTypeIndex,
        lookAtIntent = lookAtIntent,
    }

    local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, orderObject, orderContext, nil)

    if planObjectSapienAssignmentInfo.available then
        
        local proximityType = pathFinding.proximityTypes.reachable
        if resourceInfo.providerType == serverResourceManager.providerTypes.looseWithStorePlan or resourceInfo.providerType == serverResourceManager.providerTypes.standard then
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest
        end

        serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(planObjectSapienAssignmentInfo)
        local pathInfo = order:createOrderPathInfo(resourceInfo.objectID, proximityType, nil, resourceInfo.pos, nil, resourceInfo.pos)
        serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, orderObject, orderContext, true)
        return true
    end
    return false
end

function serverSapienAI:addOrderIfAble(sapien, goalOrderTypeIndex, objectIDOrNil, orderContextOrNil, proximityTypeForObjectOrNil, proximityDistanceOrNil)
    local object = nil
    local planObjectSapienAssignmentInfo = nil

    if objectIDOrNil then
        object = serverGOM:getObjectWithID(objectIDOrNil)
        if not object then
            return false
        end
        
        planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, object, orderContextOrNil, nil)
        if not planObjectSapienAssignmentInfo.available then
            return false
        end
    end

    local orderTypeIndex = goalOrderTypeIndex
    
    if object then
        local pathInfo = order:createOrderPathInfo(object.uniqueID, proximityTypeForObjectOrNil, proximityDistanceOrNil, object.pos, nil, object.pos)
        serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(planObjectSapienAssignmentInfo)
        serverSapien:addOrder(sapien, orderTypeIndex, pathInfo, object, orderContextOrNil, true)
    else
        if orderTypeIndex == order.types.sleep.index then
            if length2(sapien.pos) <= minSitHeight2 then
                return false
            end
        end
        serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(planObjectSapienAssignmentInfo)
        serverSapien:addOrder(sapien, orderTypeIndex, nil, object, orderContextOrNil, true)
    end
    
    return true
end


local function carriedItemIsOfResourceType(sapien, orderAssignInfo, resourceTypeIndexes)
    if orderAssignInfo.lastHeldObjectInfo then
        local carriedObjectResourceType = gameObject.types[orderAssignInfo.lastHeldObjectInfo.objectTypeIndex].resourceTypeIndex
        for i,resourceTypeIndex in ipairs(resourceTypeIndexes) do
            if carriedObjectResourceType == resourceTypeIndex then
                return true
            end
        end
    end
    return false
end

local function carriedItemIsOfObjectType(sapien, orderAssignInfo, objectTypeIndexes)
    if orderAssignInfo.lastHeldObjectInfo then
        local carriedObjectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex
        for i,objectTypeIndex in ipairs(objectTypeIndexes) do
            if carriedObjectTypeIndex == objectTypeIndex then
                return true
            end
        end
    end
    return false
end


local function createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, requiredCount, planObjectID)
    --disabled--mj:objectLog(sapien.uniqueID, "createResourceRetrievalOrder resourceInfo:", resourceInfo, " orderAssignInfo:", orderAssignInfo)
    --local resourceTypeIndex = resourceInfo.type
    --if resourceInfo.objectTypeIndex then
    --    resourceTypeIndex = gameObject.types[resourceInfo.objectTypeIndex].resourceTypeIndex
   -- end
   -- if serverSapien:getMaxCarryCount(sapien, resourceTypeIndex) > 0 then

       -- --disabled--mj:objectLog(sapien.uniqueID, "createResourceRetrievalOrder getMaxCarryCount OK")
        local orderTypeIndex = order.types.pickupObject.index
        local proximityType = pathFinding.proximityTypes.reachable

        if resourceInfo.providerType == serverResourceManager.providerTypes.gatherRequired then
            orderTypeIndex = order.types.gather.index
        end

        if resourceInfo.providerType == serverResourceManager.providerTypes.looseWithStorePlan or resourceInfo.providerType == serverResourceManager.providerTypes.standard then
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest
        end
        
        return {
            orderTypeIndex = orderTypeIndex,
            proximityType = proximityType,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
            orderObject = serverGOM:getObjectWithID(resourceInfo.objectID),
            orderContext = {
                objectTypeIndex = resourceInfo.objectTypeIndex,
                requiredCount = requiredCount,
                planObjectID = planObjectID,
            },
            --pathGoalObjectIDOverride = resourceInfo.objectID
        }
  --  end
   -- return nil
end

local function createRemoveResourceOrder(sapien, orderAssignInfo, removeInfo)
    return {
        orderContext = {
            objectTypeIndex = removeInfo.objectTypeIndex,
            inventoryLocation = removeInfo.location,
        },
        orderTypeIndex = order.types.removeObject.index,
        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
        pathProximityDistance = gameConstants.standardPathProximityDistance,
    }
end


local function createDeliverHeldItemToBuildOrCraftSiteOrder(sapien, orderAssignInfo)
    
    local proximityType = pathFinding.proximityTypes.reachable
    if orderAssignInfo.planState then
        local planTypeIndex = orderAssignInfo.planState.planTypeIndex
        if planTypeIndex then
            local planType = plan.types[planTypeIndex]
            if planType.skipFinalReachableCollisionPathCheck then
                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest
            elseif planType.skipFinalReachableCollisionAndVerticalityPathCheck then
                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests
            end
        end
    end

    return {
        orderTypeIndex = order.types.deliverObjectToConstructionObject.index,
        proximityType = proximityType,
        pathProximityDistance = gameConstants.buildPathProximityDistance,
        orderContext = {
            objectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex,
        }
    }
end

function serverSapienAI:getRequiredObjectInfoForSapienForConstructableOrder(sapien, orderObject, planState)
    
    local requiredItems = serverGOM:getNextRequiredItems(orderObject, planState)

    --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:getRequiredObjectInfoForSapienForConstructableOrder requiredItems:", requiredItems, " planState:", planState)

    --mj:log("serverSapienAI:getRequiredObjectInfoForSapienForConstructableOrder")

    --[[

    local restrictedResourceObjectTypes = lookAtObject.sharedState.restrictedResourceObjectTypes
    
    if planState.constructableTypeIndex then
        restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(sapien.sharedState.tribeID, planState.constructableTypeIndex, restrictedResourceObjectTypes)
    elseif plan.types[planState.planTypeIndex].isMedicineTreatment then
        restrictedResourceObjectTypes = serverWorld:getResourceBlockListForMedicineTreatment(sapien.sharedState.tribeID, restrictedResourceObjectTypes)
    elseif planState.planTypeIndex == plan.types.light.index then
        local fuelGroup = fuel.groupsByObjectTypeIndex[lookAtObject.objectTypeIndex]
        if fuelGroup then
            restrictedResourceObjectTypes = serverWorld:getResourceBlockListForFuel(sapien.sharedState.tribeID, fuelGroup.index, restrictedResourceObjectTypes)
        end
    end

    if restrictedResourceObjectTypes then
        local allowedObjectTypes = {}
        for i,objectTypeIndex in ipairs(gameObjectTypes) do
            if not restrictedResourceObjectTypes[objectTypeIndex] then
                table.insert(allowedObjectTypes, objectTypeIndex)
            end
        end
        gameObjectTypes = allowedObjectTypes
    end 
    ]]

    if not requiredItems then
        return nil
    end

    local objectTypes = {}
    local requiredCountsByObjectType = {}

    if requiredItems.resources then
        for i,resourceInfo in ipairs(requiredItems.resources) do
            if resourceInfo.count > 0 then

                local function addRequiredObjectTypeIfCanCarry(resourceTypeIndex, objectTypeIndex)
                    --mj:log("addRequiredObjectTypeIfCanCarry a:", objectTypeIndex)
                    if not serverGOM:objectTypeIndexIsRestrictedForPlan(orderObject, planState, objectTypeIndex, false) then
                        --mj:log("addRequiredObjectTypeIfCanCarry b")
                        --disabled--mj:objectLog(sapien.uniqueID, "not serverGOM:objectTypeIndexIsRestrictedForPlan serverSapien:getMaxCarryCount(sapien, resourceTypeIndex):", serverSapien:getMaxCarryCount(sapien, resourceTypeIndex))
                        if serverSapien:getMaxCarryCount(sapien, resourceTypeIndex) > 0 then
                            table.insert(objectTypes, objectTypeIndex)
                            if not requiredCountsByObjectType[objectTypeIndex] then
                                requiredCountsByObjectType[objectTypeIndex] = resourceInfo.count
                            else
                                requiredCountsByObjectType[objectTypeIndex] = requiredCountsByObjectType[objectTypeIndex] + resourceInfo.count
                            end
                        end
                    end
                end

                if resourceInfo.objectTypeIndex then
                    addRequiredObjectTypeIfCanCarry(gameObject.types[resourceInfo.objectTypeIndex].resourceTypeIndex, resourceInfo.objectTypeIndex)
                elseif resourceInfo.group then
                    for k,resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                        local gameObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
                        for j,objectTypeIndex in ipairs(gameObjectTypes) do
                            addRequiredObjectTypeIfCanCarry(resourceTypeIndex, objectTypeIndex)
                        end
                    end
                else
                    local gameObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceInfo.type]
                    --disabled--mj:objectLog(sapien.uniqueID, "gameObjectTypes:", gameObjectTypes)
                    for j,objectTypeIndex in ipairs(gameObjectTypes) do
                        addRequiredObjectTypeIfCanCarry(resourceInfo.type, objectTypeIndex)
                    end
                end
            end
        end
    elseif requiredItems.tools then
        for k,toolTypeIndex in ipairs(requiredItems.tools) do
            for j,toolObjectTypeIndex in ipairs(gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex]) do
                if not serverGOM:objectTypeIndexIsRestrictedForPlan(orderObject, planState, toolObjectTypeIndex, true) then
                    table.insert(objectTypes, toolObjectTypeIndex)
                    if not requiredCountsByObjectType[toolObjectTypeIndex] then
                        requiredCountsByObjectType[toolObjectTypeIndex] = 1
                    else
                        requiredCountsByObjectType[toolObjectTypeIndex] = requiredCountsByObjectType[toolObjectTypeIndex] + 1 --todo probably need to modify assignResourceRetrievalOrder and beyond to cope with tool types better
                    end
                end
            end
        end
    end
    --disabled--mj:objectLog(sapien.uniqueID, "returning requiredCountsByObjectType:", requiredCountsByObjectType)
    return {
        objectTypes = objectTypes,
        requiredCountsByObjectType = requiredCountsByObjectType,
    }
end

local function createDeliverObjectToBuildOrCraftSiteOrder(sapien, orderObject, orderAssignInfo)
    if not orderAssignInfo.lastHeldObjectInfo then
        local requiredObjectInfo = serverSapienAI:getRequiredObjectInfoForSapienForConstructableOrder(sapien, orderObject, orderAssignInfo.planState)
        if requiredObjectInfo then
            local resourceInfo = serverResourceManager:findResourceForSapien(sapien, requiredObjectInfo.objectTypes, {
                allowStockpiles = true,
                allowGather = true,
                takePriorityOverStoreOrders = true,
            })
            --disabled--mj:objectLog(sapien.uniqueID, "createDeliverObjectToBuildOrCraftSiteOrder findResourceForSapien returned:", resourceInfo, " for objectTypes:", requiredObjectInfo.objectTypes)
            if resourceInfo then
                return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, requiredObjectInfo.requiredCountsByObjectType[resourceInfo.objectTypeIndex], orderObject.uniqueID)
            end
        end
    end
    return nil
end



local function createStoreOrTransferObjectOrder(sapien, orderAssignInfo)
    --mj:log("attemptToAddStoreObjectOrder:", sapien.uniqueID)
    local objectTypeIndex = nil
    if orderAssignInfo.orderObject then
        objectTypeIndex = orderAssignInfo.orderObject.objectTypeIndex
    elseif orderAssignInfo.lastHeldObjectInfo then
        objectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex
    end

    local orderTypeIndex = order.types.storeObject.index
    if orderAssignInfo.planTypeIndex == plan.types.transferObject.index then
        orderTypeIndex = order.types.transferObject.index
    end
    
    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
    
    local maxCarryCount = serverSapien:getMaxCarryCount(sapien, resourceTypeIndex)
    if maxCarryCount == 0 then
        if orderAssignInfo.lastHeldObjectInfo then
            return nil
        end
    else
        if resourceTypeIndex then --and serverStorageArea:storageAreaIsAvailableForObjectType(sapien.sharedState.tribeID, objectTypeIndex, orderAssignInfo.orderObject.pos) then --commented out April '24, seems redundant, blocking long distance orders
            -- mj:log("attemptToAddStoreObjectOrder b:", sapien.uniqueID)
            if orderAssignInfo.orderObject and orderAssignInfo.lastHeldObjectInfo then
                if not carriedItemIsOfResourceType(sapien, orderAssignInfo, {resourceTypeIndex}) then
                    return nil
                else
                    local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)
                    if heldObjectCount >= maxCarryCount then
                        mj:log("ERROR: attempt to assign store object order when already carrying the maximum:", sapien.uniqueID)
                        mj:log(debug.traceback())
                        return nil
                    end
                end
            end
            return {
                orderTypeIndex = orderTypeIndex,
                proximityType = pathFinding.proximityTypes.reachable,
                pathProximityDistance = gameConstants.standardPathProximityDistance,
               -- pathGoalObjectIDOverride = orderAssignInfo.orderObject.uniqueID,
            }
        end
    end
    return nil
end

local function createPickupPlanObjectForCraftingOrResearchElsewhereOrder(sapien, orderAssignInfo)
    --disabled--mj:objectLog(sapien.uniqueID, "createPickupPlanObjectForCraftingOrResearchElsewhereOrder orderAssignInfo:", orderAssignInfo)
    local objectTypeIndex = nil
    if orderAssignInfo.orderObject then
        local orderObjectGameObjectType = gameObject.types[orderAssignInfo.orderObject.objectTypeIndex]
        if orderObjectGameObjectType.isStorageArea then

            local restrictedResourceObjectTypes = orderAssignInfo.orderObject.sharedState.restrictedResourceObjectTypes

            local discoveryCraftableTypeIndex = orderAssignInfo.planState.discoveryCraftableTypeIndex

            local function checkMatchesDiscoveryCraftableRequiredResource(resourceTypeIndex)
                if discoveryCraftableTypeIndex then
                    local craftableRequiredResources = constructable.types[discoveryCraftableTypeIndex].requiredResources
                    for i, requiredResourceInfo in ipairs(craftableRequiredResources) do
                        if resource:groupOrResourceMatchesResource(requiredResourceInfo.type or requiredResourceInfo.group, resourceTypeIndex) then
                            return true
                        end
                    end
                    return false
                end
                return true
            end

            if orderAssignInfo.planState.researchTypeIndex then
                objectTypeIndex = orderAssignInfo.planState.objectTypeIndex
                if not objectTypeIndex then
                    local researchType = research.types[orderAssignInfo.planState.researchTypeIndex]
                    local validResourceTypeIndexArray = researchType.resourceTypeIndexes
                    local validResourceTypeIndexSet = {}
                    for i, validResourceTypeIndex in ipairs(validResourceTypeIndexArray) do
                        if checkMatchesDiscoveryCraftableRequiredResource(validResourceTypeIndex) then
                            validResourceTypeIndexSet[validResourceTypeIndex] = true
                        end
                    end
                    objectTypeIndex = serverStorageArea:getObjectTypeIndexMatchingResourceType(orderAssignInfo.orderObject, validResourceTypeIndexSet, restrictedResourceObjectTypes)
                end
                
                if not objectTypeIndex then
                    return nil
                end
            else
                local constructableTypeIndex = orderAssignInfo.planState.constructableTypeIndex
                local requiredResources = constructable.types[constructableTypeIndex].requiredResources
                local validResourceTypeIndexSet = {}
                for i, resourceInfo in ipairs(requiredResources) do
                    if resourceInfo.type then
                        validResourceTypeIndexSet[resourceInfo.type] = true
                    else
                        for k, resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                            validResourceTypeIndexSet[resourceTypeIndex] = true
                        end
                    end
                end
                
                restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(sapien.sharedState.tribeID, constructableTypeIndex, restrictedResourceObjectTypes)

                objectTypeIndex = serverStorageArea:getObjectTypeIndexMatchingResourceType(orderAssignInfo.orderObject, validResourceTypeIndexSet, restrictedResourceObjectTypes)

                if not objectTypeIndex then
                    return nil
                end
            end
        else
            objectTypeIndex = orderObjectGameObjectType.index
        end
    elseif orderAssignInfo.lastHeldObjectInfo then
        objectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex
    end
    
    local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
    local maxCarryCount = serverSapien:getMaxCarryCount(sapien, resourceTypeIndex)
    if maxCarryCount == 0 then
        if orderAssignInfo.lastHeldObjectInfo then
            return nil
        end
    else
        if orderAssignInfo.orderObject and orderAssignInfo.lastHeldObjectInfo then
            
            if not carriedItemIsOfResourceType(sapien, orderAssignInfo, {resourceTypeIndex}) then
                return nil
            else
                local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)
                if heldObjectCount >= maxCarryCount then
                    mj:log("ERROR: attempt to assign store object order when already carrying the maximum:", sapien.uniqueID)
                    mj:log(debug.traceback())
                    return nil
                end
            end
        end
        return {
            orderTypeIndex = order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
            --pathGoalObjectIDOverride = orderAssignInfo.orderObject.uniqueID,
            orderContext = {
                objectTypeIndex = objectTypeIndex,
            }
        }
    end
end

local function createAddFuelOrder(sapien, orderAssignInfo)
    local requiredFuelCount = fuel:objectRequiredFuelCount(orderAssignInfo.orderObject)
    if requiredFuelCount > 0 then
        --disabled--mj:objectLog(sapien.uniqueID, "requiredFuelCount > 0")

        local fuelObjectTypes = serverFuel:requiredFuelObjectTypesArrayForObject(orderAssignInfo.orderObject, sapien.sharedState.tribeID)

        if fuelObjectTypes then
            if orderAssignInfo.lastHeldObjectInfo then
                if carriedItemIsOfObjectType(sapien, orderAssignInfo, fuelObjectTypes) then
                    return {
                        orderTypeIndex = order.types.deliverFuel.index,
                        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                        pathProximityDistance = gameConstants.standardPathProximityDistance,
                        objectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex
                    }
                end
            else
                local resourceInfo = serverResourceManager:findResourceForSapien(sapien, fuelObjectTypes, {
                    allowStockpiles = true,
                    allowGather = true,
                    takePriorityOverStoreOrders = true,
                })
                --disabled--mj:objectLog(sapien.uniqueID, "serverResourceManager:findResourceForSapien")
                if resourceInfo then
                    --disabled--mj:objectLog(sapien.uniqueID, "assignResourceRetrievalOrder")
                    return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, requiredFuelCount, orderAssignInfo.orderObject.uniqueID)
                end
            end
        end
    end
    return nil
end


local function createDeliverToCompostBinOrder(sapien, orderAssignInfo)
    local requiredObjectCount = serverCompostBin:objectRequiredCount(orderAssignInfo.orderObject, sapien.sharedState.tribeID)
    if requiredObjectCount > 0 then
        --disabled--mj:objectLog(sapien.uniqueID, "combpost bin requiredObjectCount > 0")
        
        local compostObjectTypes = serverCompostBin:requiredCompostObjectTypesArrayForObject(orderAssignInfo.orderObject, sapien.sharedState.tribeID)

        if compostObjectTypes then
            if orderAssignInfo.lastHeldObjectInfo then
                if carriedItemIsOfObjectType(sapien, orderAssignInfo, compostObjectTypes) then

                    local resourceTypeIndex = gameObject.types[orderAssignInfo.lastHeldObjectInfo.objectTypeIndex].resourceTypeIndex
                    local maxCarryCount = serverSapien:getMaxCarryCount(sapien, resourceTypeIndex)
                    if maxCarryCount > 1 then
                        local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)
                        if heldObjectCount < maxCarryCount then
                            local resourceInfo = serverResourceManager:findResourceForSapien(sapien, compostObjectTypes, {
                                allowStockpiles = true,
                                allowGather = true,
                                maxDistance2 = serverResourceManager.looseResourceMaxDistance2,
                                restrictToCarryWithObjectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex,
                            })
                            if resourceInfo then
                                --disabled--mj:objectLog(sapien.uniqueID, "createDeliverToCompostBinOrder picking up another item")
                                return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, requiredObjectCount, orderAssignInfo.orderObject.uniqueID)
                            end
                        end
                    end

                    return {
                        orderTypeIndex = order.types.deliverToCompost.index,
                        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                        pathProximityDistance = gameConstants.standardPathProximityDistance,
                        objectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex
                    }
                end
            else
                local resourceInfo = serverResourceManager:findResourceForSapien(sapien, compostObjectTypes, {
                    allowStockpiles = true,
                    allowGather = true,
                })
                --disabled--mj:objectLog(sapien.uniqueID, "createDeliverToCompostBinOrder serverResourceManager:findResourceForSapien")
                if resourceInfo then
                    --disabled--mj:objectLog(sapien.uniqueID, "createDeliverToCompostBinOrder assignResourceRetrievalOrder")
                    return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, requiredObjectCount, orderAssignInfo.orderObject.uniqueID)
                end
            end
        end
    end
    return nil
end

local minDistanceToTakeAssignmentFromOtherSapien = mj:mToP(10.0)
local minDistanceToTakeAssignmentFromOtherSapien2 = minDistanceToTakeAssignmentFromOtherSapien * minDistanceToTakeAssignmentFromOtherSapien

local function createStorageItemTransferPickupOrder(sapien, orderAssignInfo)

    local storageAreaTransferInfo = serverStorageArea:storageAreaTransferInfoIfRequiresPickup(sapien.sharedState.tribeID, orderAssignInfo.orderObject, sapien.uniqueID)

    --disabled--mj:objectLog(sapien.uniqueID, "createStorageItemTransferPickupOrder orderAssignInfo.planTypeIndex:", orderAssignInfo and orderAssignInfo.planTypeIndex, " storageAreaTransferInfo:", storageAreaTransferInfo)

    if storageAreaTransferInfo then

        local planObjectSapienAssignmentInfo = nil

        if storageAreaTransferInfo.routeID then
            if serverLogistics:sapienAssignedCountHasReachedMaxForRoute(storageAreaTransferInfo.routeTribeID or sapien.sharedState.tribeID, storageAreaTransferInfo.routeID, sapien.uniqueID) then
                local foundSapien = false
                local myDistanceFromGoal2 = length2(sapien.pos - orderAssignInfo.orderObject.pos)
                serverLogistics:callFunctionForAllSapiensOnRoute(storageAreaTransferInfo.routeTribeID or sapien.sharedState.tribeID, storageAreaTransferInfo.routeID, function(assignedSapien)
                    if sapienInventory:objectCount(assignedSapien, sapienInventory.locations.held.index) == 0 then
                        local assignedSapienLength2 = length2(assignedSapien.pos - orderAssignInfo.orderObject.pos)
                        if assignedSapienLength2 > minDistanceToTakeAssignmentFromOtherSapien2 then
                            if myDistanceFromGoal2 < assignedSapienLength2 * 0.7 then --I'm a fair bit closer
                                foundSapien = true
                                serverSapien:cancelAllOrders(assignedSapien, false, true)
                                --mj:log("cancelled:", assignedSapien.uniqueID, " assigned:", sapien.uniqueID)
                                return true --breaks from the loop in callFunctionForAllSapiensOnRoute
                            end
                        end
                    end
                    return false
                end)

                if not foundSapien then
                    --disabled--mj:objectLog(sapien.uniqueID, "createStorageItemTransferPickupOrder max alreasdy assigned to route, and couldnt cancel")

                    return nil
                end
            end
        else
            planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderAssignInfo.orderObject, sapien, orderAssignInfo.planTypeIndex)
            if not planObjectSapienAssignmentInfo.available then
                return nil
            end
        end

        if not storageAreaTransferInfo.destinationObjectID then
            return {
                orderTypeIndex = order.types.removeObject.index,
                proximityType = pathFinding.proximityTypes.reachable,
                pathProximityDistance = gameConstants.standardPathProximityDistance,
                orderObject = orderAssignInfo.orderObject,
                planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo,
                orderContext = {
                    storageAreaTransferInfo = storageAreaTransferInfo,
                    objectTypeIndex = storageAreaTransferInfo.objectTypeIndex,
                },
            }
        else
            local resourceTypeIndex = storageAreaTransferInfo.resourceTypeIndex
            if serverSapien:getMaxCarryCount(sapien, resourceTypeIndex) > 0 then
                return {
                    orderTypeIndex = order.types.transferObject.index,
                    proximityType = pathFinding.proximityTypes.reachable,
                    orderObject = orderAssignInfo.orderObject,
                    planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo,
                    pathProximityDistance = gameConstants.standardPathProximityDistance,
                    orderContext = {
                        storageAreaTransferInfo = storageAreaTransferInfo,
                        objectTypeIndex = storageAreaTransferInfo.objectTypeIndex,
                    },
                }
            end
        end
    end

        
    return nil
end

local function createCompostBinItemPickupOrder(sapien, orderAssignInfo)
    return {
        orderTypeIndex = order.types.removeObject.index,
        proximityType = pathFinding.proximityTypes.reachable,
        pathProximityDistance = gameConstants.standardPathProximityDistance,
        orderObject = orderAssignInfo.orderObject,
    }
end

local function createDestroyContentsOrder(sapien, orderAssignInfo)
    if not serverStorageArea:requiresMaintenanceDestroyItems(sapien.sharedState.tribeID, orderAssignInfo.orderObject, sapien.uniqueID) then
        return nil
    end

    if (not orderAssignInfo.lastHeldObjectInfo) then
        return {
            orderTypeIndex = order.types.destroyContents.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
        }
    end
        
    return nil

end

local function createLightOrder(sapien, orderAssignInfo)
    local planState = orderAssignInfo.planState
    if not planState.canComplete then
        return nil
    end
    if planState.requiredResources and planState.requiredResources[1] then
        return createAddFuelOrder(sapien, orderAssignInfo)
    end

    if (not orderAssignInfo.lastHeldObjectInfo) then
        return {
            orderTypeIndex = order.types.light.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
        }
    end
        
    return nil
end

local function createPlayInstrumentOrder(sapien, orderAssignInfo)
    local planState = orderAssignInfo.planState
    if not planState.canComplete then
        return nil
    end
    if (not orderAssignInfo.lastHeldObjectInfo) then
        return {
            orderTypeIndex = order.types.pickupObject.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
            orderContext = {
                objectTypeIndex = orderAssignInfo.planState.objectTypeIndex, --may not be correct in all cases?
            }
        }
    end
    return nil
end

local function createHaulObjectOrder(sapien, orderAssignInfo)
    if (not orderAssignInfo.lastHeldObjectInfo) then
        local moveToPos = nil
        local planState = orderAssignInfo.planState
        if planState then
            if planState.canComplete then
                moveToPos = planState.moveToPos
            end
        else
            local destinationObject = serverLogistics:getDestinationIfObjectRequiresHaul(sapien.sharedState.tribeID, orderAssignInfo.orderObject)
            if destinationObject then
                moveToPos = destinationObject.pos
            end
        end

        if moveToPos then
            local orderTypeIndex = order.types.haulMoveToObject.index
            local pathGoalPosOverride = nil

            --disabled--mj:objectLog(sapien.uniqueID, "in createHaulObjectOrder, sapien.sharedState.haulingObjectID:", sapien.sharedState.haulingObjectID, " orderAssignInfo.orderObject.uniqueID:", orderAssignInfo.orderObject.uniqueID)

            local disallowWaterCrossings = false

            if sapien.sharedState.seatObjectID == orderAssignInfo.orderObject.uniqueID then
                if sapien.sharedState.haulingObjectID ~= orderAssignInfo.orderObject.uniqueID then
                    serverSapien:setHaulDragingObject(sapien, orderAssignInfo.orderObject)
                end
            end

            if sapien.sharedState.haulingObjectID == orderAssignInfo.orderObject.uniqueID then
                local drivable = orderAssignInfo.orderObject.sharedState.waterRideable --todo should allow all ridable objects

                if not drivable then
                    if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, true) then
                        --disabled--mj:objectLog(sapien.uniqueID, "createHaulObjectOrder returning nil due to limited ability")
                        return nil
                    end
                end

                orderTypeIndex = order.types.haulDragObject.index

                if drivable then
                    orderTypeIndex = order.types.haulRideObject.index
                else
                    if not gameObject.types[orderAssignInfo.orderObject.objectTypeIndex].rideWaterPathFindingDifficulty then
                        disallowWaterCrossings = true
                    end
                end
                
                pathGoalPosOverride = moveToPos
            end

           -- mj:log("assigning haul order. sapien sharedState:", sapien.sharedState, " orderAssignInfo.orderObject.sharedState:", orderAssignInfo.orderObject.sharedState)

            --this probably only works for direct move orders, not maintenance orders
            local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, orderAssignInfo.orderObject, {planObjectID = orderAssignInfo.orderObject.uniqueID}, orderAssignInfo.planState)
            serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(planObjectSapienAssignmentInfo)
            --disabled--mj:objectLog(orderAssignInfo.orderObject.uniqueID, "in createHaulObjectOrder, orderAssignInfo:", orderAssignInfo, " planObjectSapienAssignmentInfo:", planObjectSapienAssignmentInfo)

            --disabled--mj:objectLog(sapien.uniqueID, "createHaulObjectOrder returning valid order info")
            return {
                orderTypeIndex = orderTypeIndex,
                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                pathProximityDistance = gameConstants.standardPathProximityDistance,
                orderObject = orderAssignInfo.orderObject,
                pathGoalPosOverride = pathGoalPosOverride,
                disallowWaterCrossings = disallowWaterCrossings,
                orderContext = {
                    moveToPos = moveToPos,
                }
            }
        end
    end
    --disabled--mj:objectLog(sapien.uniqueID, "createHaulObjectOrder returning nil")
    return nil
end

local medicineRepeatCount = 3

function serverSapienAI:addOrderToSelfApplyMedicineWithHeldItem(sapien, planTypeIndex)
    local firstObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
    if firstObjectInfo then

        local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(sapien.sharedState.tribeID)
        if resourceBlockLists then
            local blockList = resourceBlockLists.medicineList
            if blockList and blockList[firstObjectInfo.objectTypeIndex] then
                return false
            end
        end
        local cancelCurrentOrders = true
        local orderContext = {
            planTypeIndex = planTypeIndex,
            medicineObjectTypeIndex = firstObjectInfo.objectTypeIndex,
            completionRepeatCount = medicineRepeatCount,
        }
        serverSapien:addOrder(sapien, order.types.giveMedicineToSelf.index, nil, nil, orderContext, cancelCurrentOrders)
        return true
    end
    return false
end

local function createTreatOrder(sapien, orderAssignInfo)
    local planState = orderAssignInfo.planState
    if not planState.canComplete then
        return nil
    end

    local sapienToTreat = orderAssignInfo.orderObject
    if not sapienToTreat then
        return nil
    end

    local requiredResourceInfo = planState.requiredResources[1]
    local requiredMedicineObjectTypes = gameObject:getObjectTypesForResourceTypeOrGroup(requiredResourceInfo.group or requiredResourceInfo.type)
    
    if not next(requiredMedicineObjectTypes) then
        return nil
    end
    
    local allowedObjectTypes = {}

    local medicineBlockList = nil
    local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(sapien.sharedState.tribeID)
    if resourceBlockLists then
        medicineBlockList = resourceBlockLists.medicineList
    end
    for i, objectTypeIndex in ipairs(requiredMedicineObjectTypes) do
        if serverSapien:getMaxCarryCount(sapien, gameObject.types[objectTypeIndex].resourceTypeIndex) > 0 then
            if medicineBlockList then
                if not medicineBlockList[objectTypeIndex] then
                    table.insert(allowedObjectTypes, objectTypeIndex)
                end
            else
                table.insert(allowedObjectTypes, objectTypeIndex)
            end
        end
    end

    if allowedObjectTypes[1] then
        if orderAssignInfo.lastHeldObjectInfo then
            if carriedItemIsOfObjectType(sapien, orderAssignInfo, allowedObjectTypes) then
                local medicineObjectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex
                
                if sapienToTreat.uniqueID == sapien.uniqueID then
                    return {
                        orderTypeIndex = order.types.giveMedicineToSelf.index,
                        orderContext = {
                            planTypeIndex = orderAssignInfo.planTypeIndex,
                            medicineObjectTypeIndex = medicineObjectTypeIndex,
                            completionRepeatCount = medicineRepeatCount,
                        },
                    }
                else
                    return {
                        orderTypeIndex = order.types.giveMedicineToOtherSapien.index,
                        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                        pathProximityDistance = gameConstants.standardPathProximityDistance,
                        orderContext = {
                            planTypeIndex = orderAssignInfo.planTypeIndex,
                            medicineObjectTypeIndex = medicineObjectTypeIndex,
                            completionRepeatCount = medicineRepeatCount,
                        },
                    }
                end
            end
        else
            local resourceInfo = serverResourceManager:findResourceForSapien(sapien, allowedObjectTypes, {
                allowStockpiles = true,
                takePriorityOverStoreOrders = true,
            })
            
            if resourceInfo then
                return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, 1, orderAssignInfo.orderObject.uniqueID)
            end
        end
    end

    return nil
end

local function createDefendOrder(sapien, orderAssignInfo)
    
    if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
        return nil
    end
    
    local hasRequiredTaskAssigned = skill:isAllowedToDoTasks(sapien, orderAssignInfo.planState.requiredSkill)
    if not hasRequiredTaskAssigned then
        return nil
    end

    local posLength = length(orderAssignInfo.orderObject.pos)
    local moveToPos = normalize(orderAssignInfo.orderObject.pos + rng:vec() * mj:mToP(rng:randomValue() * 3.0)) * posLength
    local clampToSeaLevel = true
    moveToPos = worldHelper:getBelowSurfacePos(moveToPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)

    if not orderAssignInfo.requiredTools then
        return {
                orderTypeIndex = order.types.defend.index,
                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                pathProximityDistance = mj:mToP(1.0),
                pathGoalPosOverride = moveToPos,
        }
    end

    local gameObjectTypes = planManager:getGameObjectTypeIndexesForRequiredTools(orderAssignInfo.requiredTools, orderAssignInfo.orderObject, orderAssignInfo.planState)
    if orderAssignInfo.lastHeldObjectInfo then
        if carriedItemIsOfObjectType(sapien, orderAssignInfo, gameObjectTypes) then
            return {
                orderTypeIndex = order.types.defend.index,
                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                pathProximityDistance = mj:mToP(1.0),
                pathGoalPosOverride = moveToPos,
            }
        end
    else
        local resourceInfo = serverResourceManager:findResourceForSapien(sapien, gameObjectTypes, {
            allowStockpiles = true,
            allowGather = true,
            takePriorityOverStoreOrders = true,
        })
        if resourceInfo then
            return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, 1, orderAssignInfo.orderObject.uniqueID)
        end
    end
    return nil

end

local function createThrowProjectileOrder(sapien, orderAssignInfo)
    --mj:log("createThrowProjectileOrder:", orderAssignInfo)
    
    if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
        return nil
    end

    local gameObjectTypes = planManager:getGameObjectTypeIndexesForRequiredTools(orderAssignInfo.requiredTools, orderAssignInfo.orderObject, orderAssignInfo.planState)
        
    if orderAssignInfo.lastHeldObjectInfo then
        if carriedItemIsOfObjectType(sapien, orderAssignInfo, gameObjectTypes) then

            --[[local requiredSkill = orderAssignInfo.planState.requiredSkill
            if orderAssignInfo.planState.researchTypeIndex then
                requiredSkill = research.types[orderAssignInfo.planState.researchTypeIndex].skillTypeIndex
            end]]
            
            local hasRequiredTaskAssigned = skill:isAllowedToDoTasks(sapien, orderAssignInfo.planState.requiredSkill)
            if not hasRequiredTaskAssigned then
                return nil
            end


            local toolObjectTypeIndex = orderAssignInfo.lastHeldObjectInfo.objectTypeIndex

            local throwDistance = mj:mToP(15.0)
            local heldObjectType = gameObject.types[toolObjectTypeIndex]
            local toolUsages = heldObjectType.toolUsages
            --mj:log("toolUsages:", toolUsages)
            if toolUsages then
                --mj:log("orderAssignInfo.requiredTools:", orderAssignInfo.requiredTools)
                for i, requiredToolTypeIndex in ipairs(orderAssignInfo.requiredTools) do
                    local toolInfo = toolUsages[requiredToolTypeIndex]
                    --mj:log("toolInfo:", toolInfo)
                    if toolInfo then
                        local toolType = tool.types[requiredToolTypeIndex]
                        if toolType.projectileBaseThrowDistance then
                            --mj:log("toolType.projectileBaseThrowDistance:", mj:pToM(toolType.projectileBaseThrowDistance))
                            throwDistance = toolType.projectileBaseThrowDistance
                            break
                        end
                    end
                end
            end

            
            
            return {
                orderTypeIndex = order.types.throwProjectile.index,
                proximityType = pathFinding.proximityTypes.lineOfSight,
                pathProximityDistance = throwDistance,
            }
        end
    else
        local resourceInfo = serverResourceManager:findResourceForSapien(sapien, gameObjectTypes, {
            allowStockpiles = true,
            allowGather = true,
            takePriorityOverStoreOrders = true,
        })
        if resourceInfo then
            return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, 1, orderAssignInfo.orderObject.uniqueID)
        end
    end
    return nil
end

function serverSapienAI:createGeneralOrder(sapien, orderAssignInfo, requiresFullAbility, orderTypeIndex, additionalContextOrNil)
    if requiresFullAbility and sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
        return nil
    end
    
    local hasRequiredTaskAssigned = skill:isAllowedToDoTasks(sapien, orderAssignInfo.planState.requiredSkill)
    if not hasRequiredTaskAssigned then
        return nil
    end

    

    local gameObjectTypes = planManager:getGameObjectTypeIndexesForRequiredTools(orderAssignInfo.requiredTools, orderAssignInfo.orderObject, orderAssignInfo.planState)
    if orderAssignInfo.lastHeldObjectInfo then
        if carriedItemIsOfObjectType(sapien, orderAssignInfo, gameObjectTypes) then
            local proximityType = pathFinding.proximityTypes.reachable
            local pathProximityDistance = gameConstants.standardPathProximityDistance
            if orderAssignInfo.planState then
                local planTypeIndex = orderAssignInfo.planState.planTypeIndex
                if planTypeIndex then
                    local planType = plan.types[planTypeIndex]
                    if planType.skipFinalReachableCollisionPathCheck then
                        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest
                    elseif planType.skipFinalReachableCollisionAndVerticalityPathCheck then
                        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests
                    end

                    pathProximityDistance = planType.pathProximityDistance or gameConstants.standardPathProximityDistance
                end
            end
            return {
                orderTypeIndex = orderTypeIndex,
                proximityType = proximityType,
                pathProximityDistance = pathProximityDistance,
                orderContext = additionalContextOrNil,
            }
        end
    else
        local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, orderAssignInfo.orderObject, nil, orderAssignInfo.planState)
        if planObjectSapienAssignmentInfo.available then
        --if not serverSapienAI:otherSapienIsInViewAndHeadingTowardsAndCloser(sapien.uniqueID, orderAssignInfo.orderObject, nil, nil) then
            local resourceInfo = serverResourceManager:findResourceForSapien(sapien, gameObjectTypes, {
                allowStockpiles = true,
                allowGather = true,
                takePriorityOverStoreOrders = true,
            })
            if resourceInfo then
                local orderInfo = createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, 1, orderAssignInfo.orderObject.uniqueID)
                orderInfo.planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo
                return orderInfo
            end
        end
    end
    return nil
end


local function createDigOrder(sapien, orderAssignInfo)
    return serverSapienAI:createGeneralOrder(sapien, orderAssignInfo, true, order.types.dig.index, {
        completionRepeatCount = 3,
    })
end

local function createMineOrder(sapien, orderAssignInfo)
    return serverSapienAI:createGeneralOrder(sapien, orderAssignInfo, true, order.types.mine.index, {
        completionRepeatCount = 4,
    })
end

local function createChiselStoneOrder(sapien, orderAssignInfo)
    return serverSapienAI:createGeneralOrder(sapien, orderAssignInfo, true, order.types.chiselStone.index, {
        completionRepeatCount = 8,
    })
end

local function createChopOrder(sapien, orderAssignInfo)
    return serverSapienAI:createGeneralOrder(sapien, orderAssignInfo, true, order.types.chop.index, {
        completionRepeatCount = 2,
    })
end

local function createButcherOrder(sapien, orderAssignInfo)
    return serverSapienAI:createGeneralOrder(sapien, orderAssignInfo, false, order.types.butcher.index, {
        completionRepeatCount = 3,
    })
end

local craftClearRadius = mj:mToP(1.5)
local function createClearObjectsOrderIfNeeded(sapien, orderAssignInfo, constructableType, planState)
        
    if constructableType.classification == constructable.classifications.craft.index or constructableType.classification == constructable.classifications.research.index then --bit of a hack, but when crafting we are checking for something quite different
        local orderObject = orderAssignInfo.orderObject
        local allCloseObjects = serverGOM:getAllGameObjectsWithinRadiusOfPos(orderObject.pos, craftClearRadius)
        local clearRequired = false
        for i, objectInfo in ipairs(allCloseObjects) do
            if objectInfo.objectID ~= orderObject.uniqueID then
                local clearObject = serverGOM:getObjectWithID(objectInfo.objectID)
                if clearObject then
                    if gameObject.types[clearObject.objectTypeIndex].resourceTypeIndex then
                        clearRequired = true

                        --if not serverSapien:objectIsAssignedToOtherSapien(clearObject, sapien.sharedState.tribeID, nil, sapien, {planState.planTypeIndex}, true) then
                        local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(clearObject, sapien, planState.planTypeIndex)
                        if planObjectSapienAssignmentInfo.available then
                            if orderAssignInfo.lastHeldObjectInfo then
                                return {
                                    clearRequired = clearRequired,
                                }
                            end
                            return 
                            {
                                clearRequired = clearRequired,
                                orderInfo = {
                                    orderTypeIndex = order.types.removeObject.index,
                                    proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                                    pathProximityDistance = gameConstants.standardPathProximityDistance,
                                    orderObject = clearObject,
                                    planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo,
                                }
                            }
                        end
                    end
                end
            end
        end
        return {
            clearRequired = clearRequired,
        }
    end

    local modelIndex = constructableType.modelIndex
    if constructableType.inProgressBuildModel then
        modelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.inProgressBuildModel, 1)
    end

    if not modelIndex or constructableType.noClearOrderRequired then
        return {
            clearRequired = false,
        }
    end

    local orderObject = orderAssignInfo.orderObject
    local hitObjects = {}

    local useMeshForWorldObjects = false
    local autoClearTestResult = physics:modelTest(orderObject.pos, orderObject.rotation, orderObject.scale, modelIndex, "place", useMeshForWorldObjects, physicsSets.autoClear, nil)
    if autoClearTestResult.hasHitObject then
        for i,hitID in ipairs(autoClearTestResult.objectHits) do
            local hitObject = serverGOM:getObjectWithID(hitID)
            if hitObject then
                table.insert(hitObjects, hitObject)
            end
        end
    end

    local bestClearObject = nil
    local bestClearObjectH = clearMinHeuristic
    local bestPlanObjectSapienAssignmentInfo = nil
    
    local clearRequired = false
    local sapienViewDir = mat3GetRow(sapien.rotation, 2)

    for i,clearObject in ipairs(hitObjects) do
        local resourceTypeIndex = gameObject.types[clearObject.objectTypeIndex].resourceTypeIndex
        if resourceTypeIndex then
            clearRequired = true

            local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(clearObject, sapien, planState.planTypeIndex)
            if planObjectSapienAssignmentInfo.available then
            --if not serverSapien:objectIsAssignedToOtherSapien(clearObject, sapien.sharedState.tribeID, nil, sapien, {planState.planTypeIndex}, true) then
                local offset = normalize(clearObject.pos) - normalize(sapien.pos)
                local planDistance = length(offset)
                local normal = offset / planDistance
                local dotProduct = dot(normal, sapienViewDir)
                local heuristic = clearHeuristic(dotProduct, planDistance)

                if heuristic > bestClearObjectH then
                    bestClearObjectH = heuristic
                    bestClearObject = clearObject
                    bestPlanObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo
                end
            end
        end
    end


    if bestClearObject then
        if orderAssignInfo.lastHeldObjectInfo then
            return {
                clearRequired = clearRequired,
            }
        end
        return 
        {
            clearRequired = clearRequired,
            orderInfo = {
                orderTypeIndex = order.types.removeObject.index,
                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                pathProximityDistance = gameConstants.standardPathProximityDistance,
                orderObject = bestClearObject,
                planObjectSapienAssignmentInfo = bestPlanObjectSapienAssignmentInfo,
            }
        }
    end

    return {
        clearRequired = clearRequired,
    }
end

local function createClearVertsOrderIfNeeded(sapien, orderAssignInfo, constructableType, planState)

    ----disabled--mj:objectLog(sapien.uniqueID, "createClearVertsOrderIfNeeded constructableType:", constructableType)
    local orderObject = orderAssignInfo.orderObject
        
    local sapienViewDir = mat3GetRow(sapien.rotation, 2)

    local clearRequired = false

    local verts = nil
    if orderObject.sharedState.vertID then
        verts = {terrain:getVertWithID(orderObject.sharedState.vertID)}
    else
        local minAltitude = length(orderObject.pos) - 1.0 - mj:mToP(2.5)
        verts = physics:getVertsAffectedByBuildModel(orderObject.pos, orderObject.rotation, orderObject.scale, constructableType.modelIndex, minAltitude)
    end
    ----disabled--mj:objectLog(sapien.uniqueID, "verts:", verts)

    local bestClearVert = nil
    local bestClearVertH = clearMinHeuristic
    local bestClearVertObject = nil
    local bestPlanObjectSapienAssignmentInfo = nil

    local function checkVertNeedsClearedAndNotAssigned(vert)
        if terrain:vertNeedsClearedForBuildingPlacement(vert.uniqueID) then
            local modificationObjectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
            local modificationObject = serverGOM:getObjectWithID(modificationObjectID)
            local planObjectSapienAssignmentInfo = nil
            if modificationObject then
            -- mj:log("clearMarkerObject")
                planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(modificationObject, sapien, planState.planTypeIndex)
                if not planObjectSapienAssignmentInfo.available then
                ---if serverSapien:objectIsAssignedToOtherSapien(modificationObject, sapien.sharedState.tribeID, nil, sapien, {planState.planTypeIndex}, true) then
                    --mj:log("assigned")
                    return {
                        assigned = true,
                    }
                end
            end
            return {
                clearMarkerObject = modificationObject,
                planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo,
            }
        end
        return nil
    end

    for i,vert in ipairs(verts) do
        local vertCheckResult = checkVertNeedsClearedAndNotAssigned(vert)
        ----disabled--mj:objectLog(sapien.uniqueID, "vertCheckResult:", vertCheckResult)
        if vertCheckResult then
            clearRequired = true
            if not vertCheckResult.assigned then
                local offset = normalize(vert.pos) - normalize(sapien.pos)
                local planDistance = length(offset)
                local normal = offset / planDistance
                local dotProduct = dot(normal, sapienViewDir)
                local heuristic = clearHeuristic(dotProduct, planDistance)

                if heuristic > bestClearVertH then
                    bestClearVertH = heuristic
                    bestClearVert = vert
                    bestClearVertObject = vertCheckResult.clearMarkerObject
                    bestPlanObjectSapienAssignmentInfo = vertCheckResult.planObjectSapienAssignmentInfo
                end
            end
        end
    end

    if bestClearVert then
        if not orderAssignInfo.lastHeldObjectInfo then
            if bestClearVertObject then
                return {
                    clearRequired = clearRequired,
                    orderInfo = {
                        orderObject = bestClearVertObject,
                        orderTypeIndex = order.types.clear.index,
                        proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest,
                        pathProximityDistance = gameConstants.standardPathProximityDistance,
                        planObjectSapienAssignmentInfo = bestPlanObjectSapienAssignmentInfo,
                    }
                }
            end
        end

        return {
            clearRequired = clearRequired,
        }
    end

    return {
        clearRequired = clearRequired,
    }
end


local function createBuildOrCraftOrder(sapien, orderAssignInfo)
    --disabled--mj:objectLog(sapien.uniqueID, "createBuildOrCraftOrder")
    local planState = orderAssignInfo.planState
    if not planState.canComplete then
        --disabled--mj:objectLog(sapien.uniqueID, "createBuildOrCraftOrder not planState.canComplete")
        return nil
    end
    local orderObject = orderAssignInfo.orderObject
    local researchTypeIndex = planState.researchTypeIndex
    local discoveryCraftableTypeIndex = planState.discoveryCraftableTypeIndex

    local constructableTypeIndex = planState.constructableTypeIndex
    local constructableType = constructable.types[constructableTypeIndex]

    if not constructableType then
        mj:error("no constructableType in createBuildOrCraftOrder for planState:", planState)
        mj:log("plan type:", plan.types[planState.planTypeIndex].key, " object:", orderObject.uniqueID, " type:", gameObject.types[orderObject.objectTypeIndex].key)
        mj:log("object sharedState:", orderObject.sharedState)
        local orderObjectSharedState = orderObject.sharedState
        planManager:removeAllPlanStatesForObject(orderObject, orderObjectSharedState, nil)
        return nil
    end

    if constructableType.disallowsLimitedAbilitySapiens then
        if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
            --disabled--mj:objectLog(sapien.uniqueID, "createBuildOrCraftOrder sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState)")
            return nil
        end
    end

    local isDeconstructOrRebuild = (planState.planTypeIndex == plan.types.deconstruct.index or planState.planTypeIndex == plan.types.rebuild.index)

    serverGOM:updateBuildSequenceIndex(orderObject, sapien, planState.planTypeIndex, constructableType, planState)
    local buildSequenceIndex = orderObject.sharedState.buildSequenceIndex
    if (not buildSequenceIndex) or (buildSequenceIndex == 0) then
        buildSequenceIndex = 1
    end
    
    local currentBuildSequenceInfo = constructableType.buildSequence[buildSequenceIndex]
    if not currentBuildSequenceInfo then
        mj:error("no currentBuildSequenceInfo in createBuildOrCraftOrder. Probably caused by a bug elsewhere, removing all plan states to be safe.")
        local orderObjectSharedState = orderObject.sharedState
        planManager:removeAllPlanStatesForObject(orderObject, orderObjectSharedState, nil)
        return nil
    end

    local function getHasRequiredTasksAssignedAssigningIfAble()
        local skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, nil, planState, false)
        if skillOffset <= 0.1 and planState.requiredSkill and serverWorld:getAutoRoleAssignmentIsAllowedForRole(sapien.sharedState.tribeID, planState.requiredSkill, sapien) then
            local requiredSkill = planState.requiredSkill
            serverSapien:autoAssignToRole(sapien, requiredSkill)
            skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, nil, planState, false)
        end
        return skillOffset > 0.1
    end

    local function incrementBuildSequence()
        serverGOM:incrementBuildSequence(orderObject, sapien, planState, constructableType, false)
        buildSequenceIndex = orderObject.sharedState.buildSequenceIndex or 1
        currentBuildSequenceInfo = constructableType.buildSequence[buildSequenceIndex]
        
        if not serverGOM:getObjectWithID(orderObject.uniqueID) then --serverGOM:incrementBuildSequence can remove the build object
            return false
        end
        return true
    end

    
    --disabled--mj:objectLog(sapien.uniqueID, "createBuildOrCraftOrder currentBuildSequenceInfo.constructableSequenceTypeIndex:", constructable.sequenceTypes[currentBuildSequenceInfo.constructableSequenceTypeIndex].key)

    
    if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.clearIncorrectResources.index or 
    (isDeconstructOrRebuild and (currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.bringResources.index or currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.bringTools.index)) then
        local allRequiredResources = constructableType.requiredResources
        local allRequiredTools = constructableType.requiredTools
        if isDeconstructOrRebuild then
            allRequiredResources = nil
            allRequiredTools = nil
        end
        local removeInfo = serverGOM:nextItemInfoToBeRemovedForBuildObjectOrCraftArea(orderObject, allRequiredTools, allRequiredResources)
        if not removeInfo then
            if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.bringTools.index then
                if not incrementBuildSequence() then
                    return nil
                end
            end
            if not incrementBuildSequence() then
                return nil
            end
            if isDeconstructOrRebuild then
                return nil
            end
           -- return
        else
            if orderAssignInfo.lastHeldObjectInfo then
                return nil
            end
            local orderInfo = createRemoveResourceOrder(sapien, orderAssignInfo, removeInfo)
            return orderInfo
        end
    end
    
    if not currentBuildSequenceInfo then
        return nil
    end

    
    if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.clearObjects.index then
        if isDeconstructOrRebuild then
            incrementBuildSequence()
            return nil
        else
            local result = createClearObjectsOrderIfNeeded(sapien, orderAssignInfo, constructableType, planState)
            if not result.clearRequired then
                if not incrementBuildSequence() then
                    return nil
                end
            else
                --disabled--mj:objectLog(sapien.uniqueID, "createBuildOrCraftOrder result.orderInfo")
                return result.orderInfo
            end
        end
    end
    
    if not currentBuildSequenceInfo then
        return nil
    end

    if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.clearTerrain.index then
        if isDeconstructOrRebuild then
            incrementBuildSequence()
            return nil
        else
            local result = createClearVertsOrderIfNeeded(sapien, orderAssignInfo, constructableType, planState)
            if not result.clearRequired then
                if not incrementBuildSequence() then
                    return nil
                end
            else
                --disabled--mj:objectLog(sapien.uniqueID, "createBuildOrCraftOrder constructable.sequenceTypes.clearTerrain.index:", result)
                return result.orderInfo
            end
        end
    end
    
    if not currentBuildSequenceInfo then
        return nil
    end

    if ((not isDeconstructOrRebuild) and currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.bringResources.index) then
        if not serverGOM:resourcesAreRequiredToStartBuildObjectOrCraftArea(orderObject, orderAssignInfo.planState) then
            
            if not incrementBuildSequence() then
                return nil
            end
        else
            if getHasRequiredTasksAssignedAssigningIfAble() then
                if orderAssignInfo.lastHeldObjectInfo then
                    if serverGOM:objectTypeIndexIsRequiredForPlanObject(orderObject, orderAssignInfo.lastHeldObjectInfo.objectTypeIndex, orderAssignInfo.planState, sapien.sharedState.tribeID) then
                        return createDeliverHeldItemToBuildOrCraftSiteOrder(sapien, orderAssignInfo)
                    end
                else
                    local orderInfo = createDeliverObjectToBuildOrCraftSiteOrder(sapien, orderObject, orderAssignInfo)
                    if orderInfo then
                        return orderInfo
                    end
                end
            end
        end
    end

    if not currentBuildSequenceInfo then
        return nil
    end

    if ((not isDeconstructOrRebuild) and currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.bringTools.index) then
        if not serverGOM:anythingIsRequiredToStartBuildObjectOrCraftArea(orderObject, orderAssignInfo.planState) then
            
            --disabled--mj:objectLog(sapien.uniqueID, "nothing required, incrementing build sequence. currentBuildSequenceInfo:", currentBuildSequenceInfo)
            if not incrementBuildSequence() then
                return nil
            end
            --return
        else
            if getHasRequiredTasksAssignedAssigningIfAble() then
                --disabled--mj:objectLog(sapien.uniqueID, "has required task assigned")
                if orderAssignInfo.lastHeldObjectInfo then
                    if serverGOM:objectTypeIndexIsRequiredForPlanObject(orderObject, orderAssignInfo.lastHeldObjectInfo.objectTypeIndex, orderAssignInfo.planState, sapien.sharedState.tribeID) then
                        return createDeliverHeldItemToBuildOrCraftSiteOrder(sapien, orderAssignInfo)
                    end
                else
                    local orderInfo = createDeliverObjectToBuildOrCraftSiteOrder(sapien, orderObject, orderAssignInfo)
                    if orderInfo then
                        return orderInfo
                    end
                end
            end
        end
    end
    
    if not currentBuildSequenceInfo then
        return nil
    end

    if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.actionSequence.index then
        if (not orderAssignInfo.planState.sapienID) or (orderAssignInfo.planState.sapienID == sapien.uniqueID) then
            if getHasRequiredTasksAssignedAssigningIfAble() then
                local orderTypeIndex = order.types.buildActionSequence.index
                return {
                    orderTypeIndex = orderTypeIndex,
                    proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                    pathProximityDistance = gameConstants.buildPathProximityDistance
                }
            end
        end
    end
    
    if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.moveComponents.index then
        if orderAssignInfo.lastHeldObjectInfo then
            return nil
        end
        if (not orderAssignInfo.planState.sapienID) or (orderAssignInfo.planState.sapienID == sapien.uniqueID) then
            if getHasRequiredTasksAssignedAssigningIfAble() then
                local totalInUseCount = objectInventory:getTotalCount(orderObject.sharedState, objectInventory.locations.inUseResource.index)
                --mj:log("totalMovedCount:", totalMovedCount, " constructableType.requiredResourceTotalCount:", constructableType.requiredResourceTotalCount)
                local done = false
                if isDeconstructOrRebuild then
                    done = (totalInUseCount == 0)
                else
                    done = (totalInUseCount >= constructableType.requiredResourceTotalCount)
                end

                if done then
                    incrementBuildSequence()
                    return
                else
                    local moveInfo = serverGOM:getNextMoveInfoForBuildOrCraftObject(orderObject, orderAssignInfo.planState)
                    if moveInfo then

                        local doLowSkillActionInstead = false
                        local isDelayingSkillLearnDueToNeedingConstructionCompletedForResearch = false
                        
                        if researchTypeIndex then
                            if serverSapienSkills:willHaveResearch(sapien, researchTypeIndex, discoveryCraftableTypeIndex, 10.0) then
                                --disabled--mj:objectLog(sapien.uniqueID, "isDelayingSkillLearnDueToNeedingConstructionCompletedForResearch")
                                isDelayingSkillLearnDueToNeedingConstructionCompletedForResearch = true
                            end
                        end

                        if (not isDeconstructOrRebuild) and (not isDelayingSkillLearnDueToNeedingConstructionCompletedForResearch) and buildSequenceIndex == #constructableType.buildSequence then
                            local taughtSkillTypeIndex = nil
                            if researchTypeIndex then
                                taughtSkillTypeIndex = research.types[researchTypeIndex].skillTypeIndex
                            elseif constructableType then
                                taughtSkillTypeIndex = constructableType.skills.required
                            end

                            if taughtSkillTypeIndex then
                               --[[ local fractionComplete = skill:fractionLearned(sapien, taughtSkillTypeIndex)
                                local maxAllowedMoveCount = fractionComplete * constructableType.requiredResourceTotalCount

                                if isDeconstruct then
                                    if totalInUseCount <= (constructableType.requiredResourceTotalCount - maxAllowedMoveCount) then
                                        doLowSkillActionInstead = true
                                    end
                                else
                                    if totalInUseCount >= maxAllowedMoveCount then
                                        doLowSkillActionInstead = true
                                    end
                                end]]

                                local fractionComplete = 0.0
                                if researchTypeIndex then
                                    fractionComplete = serverWorld:discoveryCompletionFraction(sapien.sharedState.tribeID, researchTypeIndex)
                                    if fractionComplete >= 1.0 and discoveryCraftableTypeIndex then
                                        fractionComplete = serverWorld:craftableDiscoveryCompletionFraction(sapien.sharedState.tribeID, discoveryCraftableTypeIndex)
                                    end
                                else
                                    fractionComplete = skill:fractionLearned(sapien, taughtSkillTypeIndex)
                                end
                                local maxAllowedMoveCount = fractionComplete * constructableType.requiredResourceTotalCount
        
                                if totalInUseCount + 1 >= maxAllowedMoveCount then
                                    doLowSkillActionInstead = true
                                end
                            end
                        end

                        if doLowSkillActionInstead then
                            --disabled--mj:objectLog(sapien.uniqueID, "doLowSkillActionInstead")
                            local orderTypeIndex = order.types.buildActionSequence.index
                            return {
                                orderTypeIndex = orderTypeIndex,
                                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                                pathProximityDistance = gameConstants.buildPathProximityDistance,
                                researchTypeIndex = researchTypeIndex,
                                discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
                            }
                        else
                            local orderTypeIndex = order.types.buildMoveComponent.index
                            local orderContext = {
                                pickupPos = moveInfo.pickupPos,
                                dropOffPos = moveInfo.dropOffPos,
                                pickupPlaceholderKey = moveInfo.pickupPlaceholderKey,
                                dropOffPlaceholderKey = moveInfo.dropOffPlaceholderKey,
                                researchTypeIndex = researchTypeIndex,
                                discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
                            }
                            return {
                                orderTypeIndex = orderTypeIndex,
                                pathGoalPosOverride = moveInfo.pickupPos,
                                proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                                pathProximityDistance = gameConstants.buildPathProximityDistance,
                                orderContext = orderContext,
                            }
                        end
                    else
                        serverGOM:checkIfNeedsToIncrementBuildSequenceDueToMoveComponentsComplete(orderObject, sapien, orderAssignInfo.planState)
                        serverGOM:checkIfBuildOrCraftOrderIsComplete(orderObject, sapien, orderAssignInfo.planState)
                    end
                end
            end
        end
    end
    return nil
end
    
local function createResearchOrder(sapien, orderAssignInfo)

    if gameObject.types[orderAssignInfo.orderObject.objectTypeIndex].isStorageArea then
        return createPickupPlanObjectForCraftingOrResearchElsewhereOrder(sapien, orderAssignInfo)
    end

    if orderAssignInfo.planState.constructableTypeIndex then
        return createBuildOrCraftOrder(sapien, orderAssignInfo)
    end
    
    if orderAssignInfo.planState.requiresCraftAreaGroupTypeIndexes or orderAssignInfo.planState.requiresTerrainBaseTypeIndexes or orderAssignInfo.planState.requiresShallowWater then
        return createPickupPlanObjectForCraftingOrResearchElsewhereOrder(sapien, orderAssignInfo)
    end

    local researchTypeIndex = orderAssignInfo.planState.researchTypeIndex
    local researchType = research.types[researchTypeIndex]

    
    if researchType.disallowsLimitedAbilitySapiens then
        if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
            return nil
        end
    end

   -- mj:log("orderAssignInfo:", orderAssignInfo)
   -- mj:log("researchType:", researchType)
    --requiredCraftAreaGroups

    local orderTypeIndex = researchType.orderTypeIndex

    if researchType.orderTypeIndexesByBaseObjectTypeIndex then
        orderTypeIndex = researchType.orderTypeIndexesByBaseObjectTypeIndex[orderAssignInfo.orderObject.objectTypeIndex]
    end

    if not orderTypeIndex then
        mj:error("no orderTypeIndex increateResearchOrder. sapien:", sapien.uniqueID, " orderAssignInfo:", orderAssignInfo)
        return nil
    end

    if orderTypeIndex == order.types.throwProjectile.index then
        return createThrowProjectileOrder(sapien, orderAssignInfo)
    end

    if order.types[orderTypeIndex].disallowsLimitedAbilitySapiens or order.types[orderTypeIndex].disallowsLimitedAbilityAndElderSapiens then
        if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, order.types[orderTypeIndex].disallowsLimitedAbilityAndElderSapiens) then
            return nil
        end
    end

    if orderAssignInfo.requiredTools then
        local gameObjectTypes = planManager:getGameObjectTypeIndexesForRequiredTools(orderAssignInfo.requiredTools, orderAssignInfo.orderObject, orderAssignInfo.planState)
        if orderAssignInfo.lastHeldObjectInfo then
            if carriedItemIsOfObjectType(sapien, orderAssignInfo, gameObjectTypes) then
                return {
                    orderTypeIndex = orderTypeIndex,
                    proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
                    pathProximityDistance = gameConstants.standardPathProximityDistance,
                }
            end
        else
            local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, orderAssignInfo.orderObject, nil, orderAssignInfo.planState)
            if planObjectSapienAssignmentInfo.available then
            --if not serverSapienAI:otherSapienIsInViewAndHeadingTowardsAndCloser(sapien.uniqueID, orderAssignInfo.orderObject, nil, nil) then
                local resourceInfo = serverResourceManager:findResourceForSapien(sapien, gameObjectTypes, {
                    allowStockpiles = true,
                    allowGather = true,
                    ignoreObjectIDs = {
                        [orderAssignInfo.orderObject.uniqueID] = true,
                    },
                    takePriorityOverStoreOrders = true,
                })
                --mj:log("resourceInfo:", resourceInfo)
                if resourceInfo then
                    local orderInfo = createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, 1, orderAssignInfo.orderObject.uniqueID)
                    orderInfo.planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo
                    return orderInfo
                end
            end
        end
    else
        return {
            orderTypeIndex = orderTypeIndex,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests, --todo this may need to vary depending on research type or something
            pathProximityDistance = gameConstants.standardPathProximityDistance,
        }
    end
end



local function createOrderAssignInfo(sapien, orderObject, planStateOrNil, planTypeIndex)
    local info = {
        lastHeldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index),
        orderObject = orderObject,
        planState = planStateOrNil,
        planTypeIndex = planTypeIndex,
    }

    if planStateOrNil then
        info.planObjectTypeIndex = planStateOrNil.objectTypeIndex
        info.requiredTools = planStateOrNil.requiredTools
    end

    return info
end

local function addOrderForOrderInfo(sapien, orderAssignInfo, createdOrderInfo)

    --disabled--mj:objectLog(sapien.uniqueID, "addOrderForOrderInfo:", createdOrderInfo, " orderAssignInfo:", orderAssignInfo)
    if createdOrderInfo then
        
        if not createdOrderInfo.proximityType then
            mj:error("addOrderForOrderInfo createdOrderInfo.proximityType. createdOrderInfo:", createdOrderInfo, " orderAssignInfo:", orderAssignInfo)
        end
        local orderObjectToUse = createdOrderInfo.orderObject or orderAssignInfo.orderObject
        --[[local contextObjectTypeIndex = nil
        if createdOrderInfo.orderContext then
            contextObjectTypeIndex = createdOrderInfo.orderContext.objectTypeIndex
        end]]

        if createdOrderInfo.planObjectSapienAssignmentInfo then
            serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(createdOrderInfo.planObjectSapienAssignmentInfo)
        end

        local planObjectSapienAssignmentInfo = serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, orderObjectToUse, createdOrderInfo.orderContext, orderAssignInfo.planState)
        if planObjectSapienAssignmentInfo.available then
        --if not serverSapienAI:otherSapienIsInViewAndHeadingTowardsAndCloser(sapien.uniqueID, orderObjectToUse, createdOrderInfo.orderTypeIndex, contextObjectTypeIndex) then
            --local orderObjectID = orderObjectToUse.uniqueID
            
            local objectID = orderObjectToUse.uniqueID
            local orderContext = createdOrderInfo.orderContext or {}
            orderContext.planTypeIndex = orderContext.planTypeIndex or orderAssignInfo.planTypeIndex
            --disabled--mj:objectLog(sapien.uniqueID, "assign orderContext.planObjectID from existing:", orderContext.planObjectID, " or orderAssignInfo.orderObject.uniqueID:", orderAssignInfo.orderObject.uniqueID)
            orderContext.planObjectID = orderContext.planObjectID or orderAssignInfo.orderObject.uniqueID
            orderContext.orderTypeIndex = createdOrderInfo.orderTypeIndex

            local goalObjectID = objectID
            local moveToPos = orderObjectToUse.pos
            local initialObjectPos = moveToPos

            if createdOrderInfo.pathGoalPosOverride then
                goalObjectID = nil
                moveToPos = createdOrderInfo.pathGoalPosOverride
            end

            if orderObjectToUse.objectTypeIndex == gameObject.types.sapien.index then --this should be kept the same as the code in serverSapien:requestPathUpdateIfNotRequested
                if orderContext.planTypeIndex == plan.types.banish.index or orderContext.planTypeIndex == plan.types.recruit.index then --todo this is what, social plan? get in front of sapien's face
                    --disabled--mj:objectLog(sapien.uniqueID, "offsetting initial order in front of other sapien due to social plan")
                    local moveToDir = mat3GetRow(orderObjectToUse.rotation, 2)
                    local newMoveToPos = moveToPos + moveToDir * mj:mToP(6.0)
                    local clampToSeaLevel = true
                    moveToPos = worldHelper:getBelowSurfacePos(newMoveToPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                end 
            end

            -- moveToPos needs to use same code as when we update the path.
            -- new proximityType which positions ahead of target object

            -- the below is most of the way there, but has a bug

           --[[ local function getTargetSapienVelocity()
                local actionState = orderObjectToUse.sharedState.actionState
                if actionState and actionState.path and actionState.path.goalPos and length2(actionState.path.goalPos - orderObjectToUse.pos) > 0 then
                    local actionSequenceActions = actionSequence.types[actionState.sequenceTypeIndex].actions
                    local actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]
                    if action.types[actionTypeIndex].isMovementAction then
                        return sapienConstants:getWalkSpeed(orderObjectToUse.sharedState) * 1.0 * action:combinedMoveSpeedMultiplier(actionTypeIndex, orderObjectToUse.sharedState.actionModifiers)
                    end
                end
                return nil
            end
            
            local function getTargetSapienMovementDirection() --asumes getTargetSapienVelocity checked for validity
                local actionState = orderObjectToUse.sharedState.actionState
                return normalize(actionState.path.goalPos - orderObjectToUse.pos)
            end]]

            --mj:log("adding orderContext:", orderContext)

            --[[if orderObjectToUse.objectTypeIndex == gameObject.types.sapien.index then --todo also mobs
                local targetVelocity = getTargetSapienVelocity()
                if targetVelocity then
                    local vecToOrderObject = orderObjectToUse.pos - sapien.pos
                    local distanceToTarget = length(vecToOrderObject)
                    if distanceToTarget > 0 then
                        local myVelocity = sapienConstants:getWalkSpeed(sapien.sharedState) * 0.8 * 1.5 --0.8 approximate terrain difficulty, 1.5 run speed. Best to estimate slower than the target so we over shoot
                        local targetSapienMovementDirection = getTargetSapienMovementDirection()
                        local timeToTarget = distanceToTarget / myVelocity

                       -- local movementDP = dot(targetSapienMovementDirection * targetVelocity, (vecToOrderObject / distanceToTarget) * myVelocity) --this hack tries to adjust for the target heading towards us, might not work very well
                      --  timeToTarget = timeToTarget * (1.0 + movementDP * 0.5)

                        local targetExpectedDistance = targetVelocity * timeToTarget * 0.5 --just half way, helps smudge things
                        targetExpectedDistance = math.min(targetExpectedDistance, mj:mToP(50.0))
                        local targetExpectedPos = orderObjectToUse.pos + targetSapienMovementDirection * targetExpectedDistance

                        local clampToSeaLevel = true
                        targetExpectedPos = worldHelper:getBelowSurfacePos(targetExpectedPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                        mj:log("predictive code ran, offset pos by:", math.floor(mj:pToM(length(targetExpectedPos - moveToPos))), "m")

                        moveToPos = targetExpectedPos
                    end
                end
            end]]

            serverSapien:cancelAnyOrdersForSapienPlanObjectAssignment(planObjectSapienAssignmentInfo)

            local options = nil
            if createdOrderInfo.disallowWaterCrossings then
                options = {
                    disallowDifficulties = {
                        pathFinding.pathNodeDifficulties.shallowWater.index,
                        pathFinding.pathNodeDifficulties.deepWater.index
                    }
                }
            end
            --disabled--mj:objectLog(sapien.uniqueID, "calling addOrder")
            local pathInfo = order:createOrderPathInfo(goalObjectID, createdOrderInfo.proximityType, createdOrderInfo.pathProximityDistance, moveToPos, options, initialObjectPos)
            serverSapien:addOrder(sapien, createdOrderInfo.orderTypeIndex, pathInfo, orderObjectToUse, orderContext, false)
            return true
        end
    else
        if orderAssignInfo.lastHeldObjectInfo ~= nil then
            return serverSapienAI:addOrderToDisposeOfHeldItem(sapien)
        end
    end

    return false
end


function serverSapienAI:addOrderForMaintenanceIfAble(sapien, orderObject, planTypeIndex, maintenanceTypeIndex)
    
    local planObjectSapienAssignmentInfo = nil
    if planTypeIndex then

        planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
        if not planObjectSapienAssignmentInfo.available then
            return nil
        end

        --[[if serverSapien:objectIsAssignedToOtherSapien(orderObject, sapien.sharedState.tribeID, nil, sapien, {planTypeIndex}, true) then
            return nil
        end]]
    end
    
    local skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, maintenanceTypeIndex, nil, false)
    if skillOffset <= 0.1 then
        if maintenance.types[maintenanceTypeIndex].skills then
            local requiredSkillTypeIndex = maintenance.types[maintenanceTypeIndex].skills.required
            if requiredSkillTypeIndex and serverWorld:getAutoRoleAssignmentIsAllowedForRole(sapien.sharedState.tribeID, requiredSkillTypeIndex, sapien) then
                if serverSapien:autoAssignToRole(sapien, requiredSkillTypeIndex) then
                    skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, maintenanceTypeIndex, nil, false)
                end
            end
        end
    end

    if skillOffset > lookAI.minHeuristic then

        local orderAssignInfo = createOrderAssignInfo(sapien, orderObject, nil, planTypeIndex)
        local orderInfo = nil

        if planTypeIndex == plan.types.addFuel.index then
            orderInfo = createAddFuelOrder(sapien, orderAssignInfo)
        elseif planTypeIndex == plan.types.transferObject.index then
            orderInfo = createStorageItemTransferPickupOrder(sapien, orderAssignInfo)
        elseif planTypeIndex == plan.types.haulObject.index then
            orderInfo = createHaulObjectOrder(sapien, orderAssignInfo)
        elseif planTypeIndex == plan.types.destroyContents.index then
            orderInfo = createDestroyContentsOrder(sapien, orderAssignInfo)
        elseif planTypeIndex == plan.types.deliverToCompost.index then
            orderInfo = createDeliverToCompostBinOrder(sapien, orderAssignInfo)
        else
            mj:error("unimplented planTypeIndex in serverSapienAI:addOrderForMaintenanceIfAble")
            error()
        end


        if orderInfo and (order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilitySapiens or order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilityAndElderSapiens) then
            if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilityAndElderSapiens) then
                return nil
            end
        end

        if orderInfo and (not orderInfo.planObjectSapienAssignmentInfo) then
            orderInfo.planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo
        end

        return addOrderForOrderInfo(sapien, orderAssignInfo, orderInfo)
    end
    return nil
end

function serverSapienAI:addOrderForStorageAreaItemTransferPickupIfAble(sapien, orderObject, planTypeIndex)

    local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
    if not planObjectSapienAssignmentInfo.available then
        return nil
    end
    ---if planTypeIndex and serverSapien:objectIsAssignedToOtherSapien(orderObject, sapien.sharedState.tribeID, nil, sapien, {planTypeIndex}, true) then
   --     return nil
   -- end

    local orderAssignInfo = createOrderAssignInfo(sapien, orderObject, nil, planTypeIndex)
    local orderInfo = createStorageItemTransferPickupOrder(sapien, orderAssignInfo)
    if orderInfo then
        orderInfo.planObjectSapienAssignmentInfo = planObjectSapienAssignmentInfo
        return addOrderForOrderInfo(sapien, orderAssignInfo, orderInfo)
    end
    return nil
end

local function createClearOrder(sapien, orderAssignInfo)
    if (orderAssignInfo.lastHeldObjectInfo == nil) then
        return {
            orderTypeIndex = order.types.clear.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionOrVerticalTests,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
        }
    end
    return nil
end

local function createGatherOrder(sapien, orderAssignInfo)
    if (orderAssignInfo.lastHeldObjectInfo == nil) then
        return {
            orderTypeIndex = order.types.gather.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
            orderContext = {
                objectTypeIndex = orderAssignInfo.planState.objectTypeIndex
            }
        }
    end
    return nil
end

local function createPullOutOrder(sapien, orderAssignInfo)
    if (orderAssignInfo.lastHeldObjectInfo == nil) then
        return {
            orderTypeIndex = order.types.pullOut.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
        }
    end
    return nil
end

local function createExtinguishOrder(sapien, orderAssignInfo)
    if (orderAssignInfo.lastHeldObjectInfo == nil) then
        return {
            orderTypeIndex = order.types.extinguish.index,
            proximityType = pathFinding.proximityTypes.reachableWithoutFinalCollisionTest,
            pathProximityDistance = gameConstants.standardPathProximityDistance,
        }
    end
    return nil
end

local function creatRebuildOrDeconstructOrder(sapien, orderAssignInfo)
    local orderObject = orderAssignInfo.orderObject
    if orderAssignInfo.planTypeIndex == plan.types.deconstruct.index and gameObject.types[orderObject.objectTypeIndex].isStorageArea then
        local pickupOrderInfo = createStorageItemTransferPickupOrder(sapien, orderAssignInfo)
        if pickupOrderInfo then
            return pickupOrderInfo
        end
    end
    if (orderAssignInfo.planTypeIndex == plan.types.deconstruct.index or orderAssignInfo.planTypeIndex == plan.types.rebuild.index) and 
        orderObject.objectTypeIndex == gameObject.types.compostBin.index and
        orderObject.sharedState.inventory and orderObject.sharedState.inventory.objects and #orderObject.sharedState.inventory.objects > 0 then
        return createCompostBinItemPickupOrder(sapien, orderAssignInfo)
    end
    return createBuildOrCraftOrder(sapien, orderAssignInfo)
end

local function createCraftOrder(sapien, orderAssignInfo)
    if gameObject.types[orderAssignInfo.orderObject.objectTypeIndex].isStorageArea then
        return createPickupPlanObjectForCraftingOrResearchElsewhereOrder(sapien, orderAssignInfo)
    end
    if orderAssignInfo.planState.requiresCraftAreaGroupTypeIndexes then
        return createPickupPlanObjectForCraftingOrResearchElsewhereOrder(sapien, orderAssignInfo)
    end
    return createBuildOrCraftOrder(sapien, orderAssignInfo)
end


local function createRecruitOrder(sapien, orderAssignInfo)
    return {
        orderTypeIndex = order.types.recruit.index,
        proximityType = pathFinding.proximityTypes.lineOfSight,
        pathProximityDistance = mj:mToP(2.5),
    }
end

local function createAskToLeaveOrder(sapien, orderAssignInfo)
    return {
        orderTypeIndex = order.types.banish.index,
        proximityType = pathFinding.proximityTypes.lineOfSight,
        pathProximityDistance = mj:mToP(2.5),
    }
end

local function createGreetOrder(sapien, orderAssignInfo)
    return {
        orderTypeIndex = order.types.greet.index,
        proximityType = pathFinding.proximityTypes.lineOfSight,
        pathProximityDistance = mj:mToP(2.5),
    }
end

local function createAttackHandToHandOrder(sapien, orderAssignInfo)
    return {
        orderTypeIndex = order.types.fight.index,
        proximityType = pathFinding.proximityTypes.reachable,
        pathProximityDistance = gameConstants.standardPathProximityDistance,
    }
end

--[[local function createTakeOrder(sapien, orderAssignInfo)
    if not orderAssignInfo.lastHeldObjectInfo then
        local resourceInfo = serverResourceManager:getResourceInfoForObjectWithID()
        if resourceInfo then
            return createResourceRetrievalOrder(sapien, orderAssignInfo, resourceInfo, 99, orderAssignInfo.orderObject.uniqueID)
        end
    end
    return nil
end]]

serverSapienAI.creationFunctionsByPlanTypeIndex = {
    [plan.types.chop.index] = createChopOrder,
    [plan.types.chopReplant.index] = createChopOrder,
    [plan.types.dig.index] = createDigOrder,
    [plan.types.mine.index] = createMineOrder,
    [plan.types.chiselStone.index] = createChiselStoneOrder,
    [plan.types.butcher.index] = createButcherOrder,
    [plan.types.clear.index] = createClearOrder,
    [plan.types.gather.index] = createGatherOrder,
    [plan.types.pullOut.index] = createPullOutOrder,

    [plan.types.fill.index] = createBuildOrCraftOrder,
    [plan.types.fertilize.index] = createBuildOrCraftOrder,
    [plan.types.build.index] = createBuildOrCraftOrder,
    [plan.types.plant.index] = createBuildOrCraftOrder,
    [plan.types.buildPath.index] = createBuildOrCraftOrder,

    [plan.types.deconstruct.index] = creatRebuildOrDeconstructOrder,
    [plan.types.rebuild.index] = creatRebuildOrDeconstructOrder,

    [plan.types.craft.index] = createCraftOrder,

    [plan.types.storeObject.index] = createStoreOrTransferObjectOrder,
    [plan.types.transferObject.index] = createStoreOrTransferObjectOrder,

    [plan.types.destroyContents.index] = createDestroyContentsOrder,

    [plan.types.recruit.index] = createRecruitOrder,
    [plan.types.banish.index] = createAskToLeaveOrder,
    [plan.types.greet.index] = createGreetOrder,

    [plan.types.hunt.index] = createThrowProjectileOrder,
    [plan.types.hunt_throwSpear.index] = createThrowProjectileOrder,
    
    [plan.types.attack_handToHand.index] = createAttackHandToHandOrder,
    [plan.types.attack_throwSpear.index] = createThrowProjectileOrder,
    [plan.types.attack_throwRock.index] = createThrowProjectileOrder,

    [plan.types.defend_handToHand.index] = createDefendOrder,
    [plan.types.defend_throwSpear.index] = createDefendOrder,
    [plan.types.defend_throwRock.index] = createDefendOrder,

    [plan.types.addFuel.index] = createAddFuelOrder,
    [plan.types.light.index] = createLightOrder,
    [plan.types.deliverToCompost.index] = createDeliverToCompostBinOrder,
    [plan.types.playInstrument.index] = createPlayInstrumentOrder,
    [plan.types.haulObject.index] = createHaulObjectOrder,

    [plan.types.treatInjury.index] = createTreatOrder,
    [plan.types.treatBurn.index] = createTreatOrder,
    [plan.types.treatFoodPoisoning.index] = createTreatOrder,
    [plan.types.treatVirus.index] = createTreatOrder,

    [plan.types.research.index] = createResearchOrder,
    [plan.types.extinguish.index] = createExtinguishOrder,
}

function serverSapienAI:createOrderInfo(sapien, orderObject, orderAssignInfo)
    local orderInfo = nil
    local createOrderFunction = serverSapienAI.creationFunctionsByPlanTypeIndex[orderAssignInfo.planTypeIndex]
    if createOrderFunction then
        orderInfo = createOrderFunction(sapien, orderAssignInfo)
    end

    if orderInfo and orderInfo.orderTypeIndex then
        if order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilitySapiens or order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilityAndElderSapiens then
            if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilityAndElderSapiens) then
                return nil
            end
        end
    end

   -- mj:log("orderAssignInfo:", orderAssignInfo)

    if orderInfo and orderAssignInfo.planState.researchTypeIndex then
        if not orderInfo.orderContext then 
            orderInfo.orderContext = {}
        end
        orderInfo.orderContext.researchTypeIndex = orderAssignInfo.planState.researchTypeIndex
        orderInfo.orderContext.discoveryCraftableTypeIndex = orderAssignInfo.planState.constructableTypeIndex
        --mj:log("set orderInfo.context.researchTypeIndex:", orderInfo.orderContext.researchTypeIndex)
        --mj:log("orderInfo.context:", orderInfo.orderContext)
    end

    return orderInfo
end


local function assignToRoleIfAble(sapien, requiredSkill)
    if serverWorld:getAutoRoleAssignmentIsAllowedForRole(sapien.sharedState.tribeID, requiredSkill, sapien) then
        serverSapien:autoAssignToRole(sapien, requiredSkill)
        return true
    end
    return false
end

function serverSapienAI:addOrderForPlanStateIfAble(sapien, orderObject, planState)

    local skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, nil, planState, false)
    --disabled--mj:objectLog(sapien.uniqueID, "addOrderIfAble skillOffset:", skillOffset, " planState:", planState)
    if skillOffset <= 0.1 and planState.requiredSkill then
        if assignToRoleIfAble(sapien, planState.requiredSkill) then
            skillOffset = lookAI:getSkillOffsetForPlanObject(sapien, nil, planState, false)
        end
    end

    if skillOffset > lookAI.minHeuristic then
    
        local orderAssignInfo = createOrderAssignInfo(sapien, orderObject, planState, planState.planTypeIndex)
        ----disabled--mj:objectLog(sapien.uniqueID, "orderAssignInfo:", orderAssignInfo)
        local orderInfo = serverSapienAI:createOrderInfo(sapien, orderObject, orderAssignInfo)
        --disabled--mj:objectLog(sapien.uniqueID, "orderInfo:", orderInfo)

        return addOrderForOrderInfo(sapien, orderAssignInfo, orderInfo)
    end
    return nil
end

function serverSapienAI:addOrderForPlanObjectIDIfAble(sapien, planObjectID, planTypeIndexOrNilForFirst)
  --  mj:log("hello a:", sapien.uniqueID)
    local planStatesToTest = {}
    local planObject = serverGOM:getObjectWithID(planObjectID)
    if planObject then
        ----disabled--mj:objectLog(sapien.uniqueID, "hello b")
        --local planObjectSharedState = planObject.sharedState
       -- if planObjectSharedState then
           -- mj:log("hello c:", sapien.uniqueID)
           -- if ((not planObjectSharedState.assignedSapienID) or planObjectSharedState.assignedSapienID == sapien.uniqueID) then --commented out due to taking resources to crafting site while crafting sapien is assigned
               -- mj:log("hello d:", sapien.uniqueID)
                local planStates = planManager:getPlanStatesForObjectForSapien(planObject, sapien)
                if planStates then
                    for i,planState in ipairs(planStates) do
                        if not planTypeIndexOrNilForFirst or planState.planTypeIndex == planTypeIndexOrNilForFirst then
                            table.insert(planStatesToTest, planState)
                        end
                    end
                end
           -- end
        --end
        for i_,planState in ipairs(planStatesToTest) do
            if serverSapienAI:addOrderForPlanStateIfAble(sapien, planObject, planState) then
                return true
            end
        end
    end


    return false
end

--[[

    local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
    if not planObjectSapienAssignmentInfo.available then
        return nil
    end

]]

function serverSapienAI:planObjectSapienAssignmentInfoForOrderObject(sapien, orderObject, orderContextOrNil, planStateOrNil)
    
    local planTypeIndex = nil
    if orderContextOrNil then
        planTypeIndex = orderContextOrNil.planTypeIndex
    end
    
    --disabled--mj:objectLog(sapien.uniqueID, "in planObjectSapienAssignmentInfoForOrderObject orderContextOrNil:", orderContextOrNil, " planStateOrNil:", planStateOrNil)

    if not planTypeIndex then
        if planStateOrNil then
            planTypeIndex = planStateOrNil.planTypeIndex
        end
    end

    if not planTypeIndex then
        return {
            available = true
        }
    end

    local planObject = nil
    if orderContextOrNil and orderContextOrNil.planObjectID then -- and ((not orderObject) or orderContextOrNil.planObjectID ~= orderObject.uniqueID) then
        planObject = serverGOM:getObjectWithID(orderContextOrNil.planObjectID)
    end

    local storageAreaTransferInfo = orderContextOrNil and orderContextOrNil.storageAreaTransferInfo
    if storageAreaTransferInfo then
        if storageAreaTransferInfo.routeID then
            local maxReached = serverLogistics:sapienAssignedCountHasReachedMaxForRoute(storageAreaTransferInfo.routeTribeID or sapien.sharedState.tribeID, storageAreaTransferInfo.routeID, sapien.uniqueID)
            if maxReached then
                --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. maxReached.")
                return {
                    available = false
                }
            end
        else

            if serverSapien:objectIsAssignedToOtherSapien(orderObject, sapien.sharedState.tribeID, sapien, {plan.types.transferObject.index}, true) then
                --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. orderObject objectIsAssignedToOtherSapien not compatible with storageAreaTransferInfo:", storageAreaTransferInfo)
                return {
                    available = false
                }
            end
        end

        -- we could probably return true here, but it might be a better idea to leave the below checks as a backstop
    end

    local planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
    if not planObjectSapienAssignmentInfo.available then
        --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. planObjectSapienAssignmentInfo returned not available.")
        return planObjectSapienAssignmentInfo
    end
   --[[ if planObject and planObject.uniqueID == orderObject.uniqueID then
        planObjectSapienAssignmentInfo = serverSapien:getInfoForPlanObjectSapienAssignment(orderObject, sapien, planTypeIndex)
        if not planObjectSapienAssignmentInfo.available then
            --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. planObjectSapienAssignmentInfo returned not available.")
            return planObjectSapienAssignmentInfo
        end
    else
        local assignedSapien = serverSapien:objectIsAssignedToOtherSapien(orderObject, sapien.sharedState.tribeID, seatNodeIndex, sapien, {planTypeIndex}, (not planObject) or (planObject.uniqueID == orderObject.uniqueID))
        if assignedSapien then
            --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. orderObject objectIsAssignedToOtherSapien.")
            if assignedSapien == 1 then --serverSapien:objectIsAssignedToOtherSapien returns 1 if the assigned sapien can't be determined
                assignedSapien = nil
            end
            return {
                available = false,
                assignedSapienID = assignedSapien
            }
        end
    end]]
    
    if planObject and (planObject ~= orderObject) then
        local assignedSapien = serverSapien:objectIsAssignedToOtherSapien(planObject, sapien.sharedState.tribeID, sapien, {planTypeIndex}, true)
        if assignedSapien then
            if assignedSapien == 1 then --serverSapien:objectIsAssignedToOtherSapien returns 1 if the assigned sapien can't be determined
                assignedSapien = nil
            end
            --disabled--mj:objectLog(sapien.uniqueID, "in serverSapien:assignOrderObject fail. planObject objectIsAssignedToOtherSapien.")
            return {
                available = false,
                assignedSapienID = assignedSapien
            }
        end
    end

    return planObjectSapienAssignmentInfo or {
        available = true
    }
end

function serverSapienAI:focusOnPlanObjectAfterCompletingOrder(sapien, planObject)
    findOrderAI:focusOnPlanObjectAfterCompletingOrder(sapien, planObject)
end

function serverSapienAI:startLookAt(sapien)
    serverSapienAI.aiStates[sapien.uniqueID].lookAtStartTime = serverWorld:getWorldTime()
end

function serverSapienAI:checkAutoExtendCurrentOrder(sapien)
    --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:checkAutoExtendCurrentOrder", " trace:", debug.traceback())

    local checkResult = findOrderAI:checkAutoExtendCurrentOrder(sapien)
    if checkResult then
        if checkResult.canExtend and (not checkResult.shouldActOnLookAtObject) then
            local sharedState = sapien.sharedState
            local orderState = sharedState.orderQueue[1]
            if orderState then
                --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:checkAutoExtendCurrentOrder has orderState:", orderState)
                if orderState.objectID and orderState.context and orderState.context.planTypeIndex then
                    local orderObject = serverGOM:getObjectWithID(orderState.objectID)
                    if orderObject then
                        local maintenanceTypeIndex = maintenance:requiredMaintenanceTypeIndex(sapien.sharedState.tribeID, orderObject, sapien.uniqueID)
                        if maintenanceTypeIndex and (maintenance.types[maintenanceTypeIndex].planTypeIndex == orderState.context.planTypeIndex) then
                            --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:checkAutoExtendCurrentOrder returning maintenanceTypeIndex:", maintenanceTypeIndex)
                            return checkResult
                        end

                        local planState = planManager:getPlanStateForObjectForSapienForPlanType(orderObject, sapien, orderState.context.planTypeIndex)
                        if planState then
                            --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:checkAutoExtendCurrentOrder found planState:", planState)
                            local orderAssignInfo = createOrderAssignInfo(sapien, orderObject, planState, orderState.context.planTypeIndex)
                            local orderInfo = serverSapienAI:createOrderInfo(sapien, orderObject, orderAssignInfo)
                            --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:checkAutoExtendCurrentOrder generated orderInfo:", orderInfo)
                            if (not orderInfo) or (orderInfo.orderTypeIndex ~= orderState.orderTypeIndex and (not checkResult.replaceOrder))  then
                                --disabled--mj:objectLog(sapien.uniqueID, "serverSapienAI:checkAutoExtendCurrentOrder returning nil")
                                return nil
                            end
                        else
                            return nil
                        end
                    else
                        return nil
                    end
                --else
                   -- return nil --commented out 18/5/23 to try to avoid flute stopping all the time, might cause chaos
                end
                

                if orderState.context and orderState.context.planObjectID then
                    --disabled--mj:objectLog(sapien.uniqueID, "checking planObjectID:", orderState.context.planObjectID)
                    if not serverGOM:getObjectWithID(orderState.context.planObjectID) then
                        --disabled--mj:objectLog(sapien.uniqueID, "plan object is no longer loaded:", orderState.context.planObjectID)
                        return nil
                    end
                end
            end
        end
    end
    return checkResult
end

function serverSapienAI:infrequentUpdate(sapien, dt, isOwnedByOfflinePlayer)
    
    local sharedState = sapien.sharedState
    local traitState = sharedState.traits

    local isSleeping = serverSapien:isSleeping(sapien)

    local aiState = serverSapienAI.aiStates[sapien.uniqueID]

    if not isSleeping then
        local closeThreatPotentialSapiens = aiState.closeThreatPotentialSapiens
        if closeThreatPotentialSapiens then
            local closestThreatSapien = nil
            local closestThreatSapienDistance2 = 99
            local closestThreatSapienThreatLevel = 0

            for otherSapienID, otherSapien in pairs(closeThreatPotentialSapiens) do
                local threatLevel = serverSapien:getOtherSapienThreatLevel(sapien, otherSapien)
                if threatLevel > 0 and threatLevel >= closestThreatSapienThreatLevel then
                    local distanceVec = sapien.pos - otherSapien.pos
                    local distance2 = length2(distanceVec)
                    if distance2 < closestThreatSapienDistance2 then
                        closestThreatSapien = otherSapien
                        closestThreatSapienDistance2 = distance2
                        closestThreatSapienThreatLevel = threatLevel
                    end
                end
            end

            aiState.closestThreatSapien = closestThreatSapien

            if closestThreatSapien then
                --mj:log("found close threat sapien")
                aiState.closestThreatSapienDistance = math.sqrt(closestThreatSapienDistance2)
                aiState.closestThreatSapienDirection = (closestThreatSapien.pos - sapien.pos) / aiState.closestThreatSapienDistance
            end
        end
    end

    if not isSleeping then
        local hungerIncrement = 0.001

        local hungerInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.hunger.index)
        hungerIncrement = hungerIncrement * math.pow(2,hungerInfluence * sapienTrait.hungerInfluenceOnHungerIncrement)
        hungerIncrement = hungerIncrement * sapienConstants.hungerIncrementMultiplier

        local newFoodNeed = math.min(sharedState.needs[need.types.food.index] + dt * hungerIncrement, 1.0)

        sharedState:set("needs", need.types.food.index, newFoodNeed)
    end
    
    local sleepTraitInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.sleep.index)

    if not isSleeping then
        local sleepNeedTraitMultiplier = math.pow(2.0, sleepTraitInfluence * sapienTrait.sleepInfluenceOnGradualSleepNeedIncrease)
        
        if sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then
            sleepNeedTraitMultiplier = sleepNeedTraitMultiplier * 1.1
        end

        ----disabled--mj:objectLog(sapien.uniqueID, "increasing sleep need with sleepNeedTraitMultiplier:", sleepNeedTraitMultiplier)
        local newSleepNeed = sharedState.needs[need.types.sleep.index] + (dt * sleepNeedTraitMultiplier) / (serverWorld:getDayLength() * 0.7)
        if newSleepNeed > 1.0 then
            newSleepNeed = 1.0
        end
        sharedState:set("needs", need.types.sleep.index, newSleepNeed)
    end

    local newRestNeed = sharedState.needs[need.types.rest.index]
    local restTraitInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.rest.index) --lazy = 1
    local restNeedModifier = 0.1

    local foundActionModifier = false
    local actionState = sapien.sharedState.actionState
    if actionState then
        local sequenceTypeIndex = actionState.sequenceTypeIndex
        if sequenceTypeIndex then
            local actionTypeIndex = actionSequence.types[sequenceTypeIndex].actions[actionState.progressIndex]
            if actionTypeIndex then
                local actionModifier = action.types[actionTypeIndex].restNeedModifier
                if actionModifier then
                    --disabled--mj:objectLog(sapien.uniqueID, "action.types[actionTypeIndex].restNeedModifier:", actionModifier)
                    restNeedModifier = actionModifier
                    foundActionModifier = true
                end

                if actionTypeIndex == action.types.moveTo.index
                 or actionTypeIndex == action.types.flee.index
                 or actionTypeIndex == action.types.dragObject.index then
                    local moveRestNeedMultiplier = action:getModifierValue(sapien.sharedState.actionModifiers, "moveRestNeedMultiplier")
                    if moveRestNeedMultiplier then
                        --disabled--mj:objectLog(sapien.uniqueID, "moveRestNeedMultiplier:", moveRestNeedMultiplier)
                        restNeedModifier = restNeedModifier * moveRestNeedMultiplier
                    end
                end
            end
        end
    end

    if (not foundActionModifier) and action:hasModifier(sharedState.actionModifiers, action.modifierTypes.sit.index) then
        restNeedModifier = action.types[action.types.sit.index].restNeedModifier
        --disabled--mj:objectLog(sapien.uniqueID, "sitting in sharedState.actionModifiers. Setting restNeedModifier:", restNeedModifier)
    end

    local hasPositiveOverride = statusEffect:hasPositiveOverride(sharedState)

    if (not hasPositiveOverride) or restNeedModifier < 0.0 then
        if restNeedModifier > 0.0 then
            if sharedState.lifeStageIndex == sapienConstants.lifeStages.elder.index or sharedState.pregnant then
                restNeedModifier = restNeedModifier * 2.0
            end
        else
            restNeedModifier = restNeedModifier * 2.0
        end
        
        local traitMultiplierPower = -0.2
        if restNeedModifier > 0.0 then
            traitMultiplierPower = 0.2
        end
        local restNeedTraitMultiplier = math.pow(2.0, restTraitInfluence * traitMultiplierPower)
        local restMultiplier = (dt * restNeedTraitMultiplier) / (serverWorld:getDayLength() * 0.75)
        

        --disabled--mj:objectLog(sapien.uniqueID, "adding to rest need (", sharedState.needs[need.types.rest.index], ") + ", restNeedModifier * restMultiplier, " restNeedModifier:", restNeedModifier, " restNeedTraitMultiplier:", restNeedTraitMultiplier)

        newRestNeed = sharedState.needs[need.types.rest.index] + restNeedModifier * restMultiplier

        newRestNeed = clamp(newRestNeed, 0, 1.0)
        sharedState:set("needs", need.types.rest.index, newRestNeed)
    end

    local restDesireAccountingForOverride = desire:getDesire(sapien, need.types.rest.index, true)
    local newResting = sharedState.resting
    if hasPositiveOverride then
        newResting = nil
    else
        if (restDesireAccountingForOverride >= desire.levels.strong) and (not sharedState.manualAssignedPlanObject) then
            newResting = true
        elseif restDesireAccountingForOverride < desire.levels.moderate then
            newResting = nil
        end
    end

    if newResting ~= sharedState.resting then
        sharedState:set("resting", newResting)
    end
    
    local musicalTraitValue = sapienTrait:getTraitValue(traitState, sapienTrait.types.musical.index) or 0
    if musicalTraitValue > -0.5 then -- tone deaf sapiens dont need music, dont get any music related status effects
        local musicPlayersNearBy = false

        if actionState and actionState.sequenceTypeIndex then
            local orderQueue = sapien.sharedState.orderQueue
            if orderQueue then
                local orderState = orderQueue[1]
               -- --disabled--mj:objectLog(sapien.uniqueID, "infrequent update, orderState:", orderState)
                if orderState and orderState.orderTypeIndex == order.types.playInstrument.index then
                    local activeSequence = actionSequence.types[actionState.sequenceTypeIndex]
                   -- --disabled--mj:objectLog(sapien.uniqueID, "activeSequence:", activeSequence)
                    if activeSequence.assignedTriggerIndex == actionState.progressIndex then
                        musicPlayersNearBy = true
                    end
                end
            end
        end

       -- --disabled--mj:objectLog(sapien.uniqueID, "infrequent update, actionState:", actionState, " musicPlayersNearBy:", musicPlayersNearBy)

        if not musicPlayersNearBy then
            musicPlayersNearBy = serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(serverGOM.objectSets.musicPlayers, sapien.pos, mj:mToP(20.0))
        end

        local musicIncrement = nil
        local musicalInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.musical.index)
        if musicPlayersNearBy then 
            musicIncrement = -0.008
        else
            musicIncrement = 0.0005 * math.pow(2,musicalInfluence * sapienTrait.musicalInfluenceOnMusicIncrement) * sapienConstants.musicNeedIncrementMultiplier
        end
        
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.enjoyedMusic.index, musicPlayersNearBy)

        local newMusicNeed = sharedState.needs[need.types.music.index] + dt * musicIncrement
        if newMusicNeed > 1.0 then
            newMusicNeed = 1.0
            if musicalTraitValue > 0 then
                serverStatusEffects:addEffect(sharedState, statusEffect.types.wantsMusic.index)
            end
        else
            if musicalTraitValue > 0 then
                serverStatusEffects:removeEffect(sharedState, statusEffect.types.wantsMusic.index)
            end
            if newMusicNeed < 0.0 then
                newMusicNeed = 0.0
            end
        end

        sharedState:set("needs", need.types.music.index, newMusicNeed)
    end


    local happySadMoodValue = 3
    local loyaltyInfluenceHappySadValue = 3
    if sharedState.statusEffects then
        --mj:log("sharedState.statusEffects:", sharedState.statusEffects)
        for statusEffectTypeIndex,efectInfo in pairs(sharedState.statusEffects) do
            local statusEffectType = statusEffect.types[statusEffectTypeIndex]
            local impact = statusEffectType.impact
            happySadMoodValue = happySadMoodValue + impact

            if statusEffectType.affectsLoyalty then
                loyaltyInfluenceHappySadValue = loyaltyInfluenceHappySadValue + impact
            end
        end
    end

    happySadMoodValue = mjm.clamp(happySadMoodValue, 0, 5)
    loyaltyInfluenceHappySadValue = mjm.clamp(loyaltyInfluenceHappySadValue, 0, 5)

    sharedState:set("moods", mood.types.happySad.index, happySadMoodValue)
    
    local happySadMood = mood:getMood(sapien, mood.types.happySad.index)
    
    if not isOwnedByOfflinePlayer then
        local loyaltyMoodValue = sharedState.moods[mood.types.loyalty.index] or 3
        local loyaltyTraitInfluence = sapienTrait:getInfluence(traitState, sapienTrait.influenceTypes.loyaltyMood.index)
        
        if statusEffect:hasEffect(sharedState, statusEffect.types.enjoyedMusic.index) then
            loyaltyInfluenceHappySadValue = loyaltyInfluenceHappySadValue + 1.0
        end
        if loyaltyInfluenceHappySadValue > loyaltyMoodValue then
            loyaltyMoodValue = loyaltyMoodValue + dt * 0.001 * (1.0 + loyaltyTraitInfluence * sapienTrait.loyaltyInfluenceOnMoodIncrement + ((loyaltyInfluenceHappySadValue - math.floor(loyaltyMoodValue)) / 5))
            if loyaltyMoodValue > loyaltyInfluenceHappySadValue then
                loyaltyMoodValue = loyaltyInfluenceHappySadValue
            end
        elseif loyaltyInfluenceHappySadValue < loyaltyMoodValue then
            loyaltyMoodValue = loyaltyMoodValue - dt * 0.001 * (1.0 - loyaltyTraitInfluence * sapienTrait.loyaltyInfluenceOnMoodIncrement + ((loyaltyMoodValue - math.floor(loyaltyInfluenceHappySadValue)) / 5))
            if loyaltyMoodValue < loyaltyInfluenceHappySadValue then
                loyaltyMoodValue = loyaltyInfluenceHappySadValue
            end
        end
        loyaltyMoodValue = clamp(loyaltyMoodValue, 0, 5)
        sharedState:set("moods", mood.types.loyalty.index, loyaltyMoodValue)
    end
    
    
    local function shouldSadWalk()
        if happySadMood <= mood.levels.severeNegative then
            local sleepDesire = desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos))
            if sleepDesire < desire.levels.strong then --lets walk fast to bed
                local orderState = sharedState.orderQueue[1]
                if orderState and orderState.context and orderState.context.moveToMotivation then
                    return false
                end
               -- --disabled--mj:objectLog("shouldSadWalk returning true:", orderState)
                return true
            end
        end
        return false
    end

    local function shouldRunForFood()
        if desire:getDesire(sapien, need.types.food.index, false) > desire.levels.moderate then
            if serverSapien:isRetrievingFood(sapien) then
                return true
            end
        end
        return false
    end

    local debugAnimationModifierType = nil--action.modifierTypes.sneak.index

    if debugAnimationModifierType then
        sharedState:set("actionModifiers", {
            [debugAnimationModifierType] = {}
        })
    else

        local newModifiers = {}

        local heldObjectCount = sapienInventory:objectCount(sapien, sapienInventory.locations.held.index)

        local planRunOrJogTypeIndex = serverSapien:runOrJogMofifierTypeDueToPlan(sapien)
        ----disabled--mj:objectLog(sapien.uniqueID, "planRunOrJogTypeIndex:", planRunOrJogTypeIndex)
        
        if action:hasModifier(sharedState.actionModifiers, action.modifierTypes.sit.index) then
            --mj:log("reasssigning old sit modifier:", sharedState.actionModifiers[action.modifierTypes.sit.index])
            newModifiers[action.modifierTypes.sit.index] = sharedState.actionModifiers[action.modifierTypes.sit.index]
        elseif action:hasModifier(sharedState.actionModifiers, action.modifierTypes.crouch.index) then
            --mj:log("reasssigning old sit modifier:", sharedState.actionModifiers[action.modifierTypes.sit.index])
            newModifiers[action.modifierTypes.crouch.index] = sharedState.actionModifiers[action.modifierTypes.crouch.index]
        elseif action:hasModifier(sharedState.actionModifiers, action.modifierTypes.run.index) then
            newModifiers[action.modifierTypes.run.index] = sharedState.actionModifiers[action.modifierTypes.run.index]
        elseif sharedState.fleeing or shouldRunForFood() then
            newModifiers[action.modifierTypes.run.index] = {}
        elseif planRunOrJogTypeIndex then
            newModifiers[planRunOrJogTypeIndex] = {}
        elseif shouldSadWalk() then
            newModifiers[action.modifierTypes.sadWalk.index] = {}
        else
            local jogLikelyhood = -restTraitInfluence
            
            local orderState = sharedState.orderQueue[1]
            if serverWeather:getIsDamagingWindStormOccuring() or (orderState and orderState.context and orderState.context.moveToMotivation) then
                jogLikelyhood = 10
            else
                if sapien.sharedState.lifeStageIndex ==  sapienConstants.lifeStages.child.index then
                    jogLikelyhood = jogLikelyhood + 1
                elseif sapien.sharedState.lifeStageIndex == sapienConstants.lifeStages.elder.index or sapien.sharedState.hasBaby or sapien.sharedState.pregnant then
                    jogLikelyhood = jogLikelyhood - 1
                end

                if happySadMood >= mood.levels.moderatePositive then
                    jogLikelyhood = jogLikelyhood + 1
                elseif happySadMood <= mood.levels.moderateNegative then
                    jogLikelyhood = jogLikelyhood - 1
                end
                
                if desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos)) < desire.levels.moderate then
                    jogLikelyhood = jogLikelyhood - 1
                end
            end

            local restDesireIndex = desire:getIntValue(restDesireAccountingForOverride)

            ----disabled--mj:objectLog(sapien.uniqueID, "jogLikelyhood:", jogLikelyhood, " restDesireIndex:", restDesireIndex)
            if (jogLikelyhood >= restDesireIndex) then
                newModifiers[action.modifierTypes.jog.index] = {}
            end
            
            if (not (newModifiers[action.modifierTypes.jog.index] or newModifiers[action.modifierTypes.run.index])) and  (sharedState.resting or (jogLikelyhood < restDesireIndex - 2)) then
                local sleepDesire = desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos))
                if sleepDesire < desire.levels.strong then --lets walk fast to bed
                    newModifiers[action.modifierTypes.slowWalk.index] = {}
                end
            end
        end

        if newModifiers[action.modifierTypes.jog.index] or newModifiers[action.modifierTypes.run.index] then
            if heldObjectCount > 0 then
                local lastHeldObjectInfo = sapienInventory:lastObjectInfo(sapien, sapienInventory.locations.held.index)
                local carriedObjectResourceType = gameObject.types[lastHeldObjectInfo.objectTypeIndex].resourceTypeIndex
                if not storage:canRunWithCarriedResource(carriedObjectResourceType, heldObjectCount) then
                    newModifiers[action.modifierTypes.jog.index] = nil
                    newModifiers[action.modifierTypes.run.index] = nil
                end
            end
        end

        sharedState:set("actionModifiers", newModifiers)
    end


    --[[

    if isSleeping then
        comfortNeedOffset = 0.001
        local orderState = sharedState.orderQueue[1]
        if orderState and orderState.objectID then
            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            if orderObject and gameObject.types[orderObject.objectTypeIndex].bedComfort then
                comfortNeedOffset = -0.002 * gameObject.types[orderObject.objectTypeIndex].bedComfort
            end
        end
    elseif action:hasModifier(sharedState.actionModifiers, action.modifierTypes.sit.index) then
        comfortNeedOffset = 0.001
        local orderState = sharedState.orderQueue[1]
        if orderState and orderState.objectID then
            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            if orderObject and gameObject.types[orderObject.objectTypeIndex].seatComfort then
                comfortNeedOffset = -0.002 * gameObject.types[orderObject.objectTypeIndex].seatComfort
            end
        end
    else
        comfortNeedOffset = -0.0001
    end
    ]]

    --statusEffect:updateTimedEffect(sharedState, statusEffect.types.justAte.index, -1.0 * dt)
    
    local foodDesire = desire:getDesire(sapien, need.types.food.index, false)
    if foodDesire >= desire.levels.strong then
        if (not statusEffect:hasEffect(sharedState, statusEffect.types.hungry.index)) and
        (not statusEffect:hasEffect(sharedState, statusEffect.types.veryHungry.index)) and
        (not statusEffect:hasEffect(sharedState, statusEffect.types.starving.index)) then
            serverTutorialState:setSapienHungry(sharedState.tribeID)
            serverStatusEffects:setTimedEffect(sharedState, statusEffect.types.hungry.index, sapienConstants.hungryDurationUntilEscalation)
        end
    end
    

    local sleepDesire = desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos))

    local addExhaustedSleep = sleepDesire >= desire.levels.severe
    if addExhaustedSleep then
        for statusEffectTypeIndex,v in pairs(sharedState.statusEffects) do
            if statusEffectTypeIndex ~= statusEffect.types.exhaustedSleep.index and statusEffect.types[statusEffectTypeIndex].requiresConstantSleep then
                addExhaustedSleep = false
                break
            end
        end
    end
    if addExhaustedSleep then
        serverStatusEffects:addEffect(sharedState, statusEffect.types.exhaustedSleep.index)
    else
        serverStatusEffects:removeEffect(sharedState, statusEffect.types.exhaustedSleep.index)
    end

    if desire:getDesire(sapien, need.types.rest.index, false) >= desire.levels.severe then
        serverStatusEffects:addEffect(sharedState, statusEffect.types.exhausted.index)
    else
        serverStatusEffects:removeEffect(sharedState, statusEffect.types.exhausted.index)
    end
    
    if isSleeping then
        serverStatusEffects:removeEffect(sharedState, statusEffect.types.tired.index)
        local sleepIsCovered = false
        local sleepOnBed = false
        local orderState = sharedState.orderQueue[1]
        if orderState and orderState.objectID then
            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            if orderObject and gameObject.types[orderObject.objectTypeIndex].bedComfort then
                sleepOnBed = true
                sleepIsCovered = orderObject.sharedState.covered
            end
        end
        if not sleepOnBed then
            sleepIsCovered = sapien.sharedState.covered
        end

        
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.sleptOutside.index, (not sleepIsCovered))
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.sleptOnGround.index, (not sleepOnBed))

        local isGoodSleep = sleepIsCovered and sleepOnBed and sleepDesire < desire.levels.moderate
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.goodSleep.index, isGoodSleep)

    else
        if sleepDesire >= desire.levels.strong then
            serverStatusEffects:addEffect(sharedState, statusEffect.types.tired.index)
        end
        
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.sleptOutside.index, false)
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.sleptOnGround.index, false)
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.goodSleep.index, false)
    end
    
    if newResting then
        serverStatusEffects:removeEffect(sharedState, statusEffect.types.wellRested.index)
        serverStatusEffects:addEffect(sharedState, statusEffect.types.overworked.index)
    else
        serverStatusEffects:removeEffect(sharedState, statusEffect.types.overworked.index)
        serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffect.types.wellRested.index, restNeedModifier < 0.0)
    end

    --[[if sharedState.statusEffects[statusEffect.types.familyDiedShortTerm.index] then
        statusEffect:updateTimedEffect(sharedState, statusEffect.types.familyDiedShortTerm.index, -1.0 * dt)
        if not sharedState.statusEffects[statusEffect.types.familyDiedShortTerm.index] then
            serverStatusEffects:setTimedEffect(sharedState, statusEffect.types.familyDiedLongTerm.index, 1000.0)
        end
    end]]

    --[[statusEffect:updateTimedEffect(sharedState, statusEffect.types.familyDiedLongTerm.index, -1.0 * dt)
    statusEffect:updateTimedEffect(sharedState, statusEffect.types.acquaintanceDied.index, -1.0 * dt)
    statusEffect:updateTimedEffect(sharedState, statusEffect.types.acquaintanceLeft.index, -1.0 * dt)]]


    --[[sharedState.actionModifiers = {
        {
            --actionModifierTypeIndex = action.modifierTypes.sneak.index,
            actionModifierTypeIndex = action.modifierTypes.jog.index,
        }
    }]]

    local function updateCooldowns(cooldowns)
        if cooldowns then
            for key,counter in pairs(cooldowns) do
                cooldowns[key] = counter - dt
                if cooldowns[key] < 0.0 then
                    cooldowns[key] = nil
                end
            end
        end
    end

    if not aiState.socialTimer then --crashed here once
        mj:error("no social timer for sapien:", sapien.uniqueID, " aiState:", aiState, " sapien state:", sapien.sharedState)
    end
    aiState.socialTimer = aiState.socialTimer + dt
    if aiState.socialTimer > totalSocialTimersLength then
        aiState.socialTimer = 0.0
    end
    
    updateCooldowns(aiState.cooldowns)
    
    serverSapien:saveState(sapien)
    
    serverStatusEffects:updateTimedEffects(sapien, dt) --warning - this can remove the sapien!
end

function serverSapienAI:addOrderToFlee(sapien, runAwayDirection)
    --mj:log("serverSapienAI:addOrderToFlee")
    serverSapien:dropHeldInventoryImmediately(sapien)
    serverSapien:cancelAllOrders(sapien, false, false)
    serverSapien:cancelWaitOrder(sapien)

    local moveToDir = normalize(runAwayDirection + rng:vec() * 0.2)
    local moveToPos = sapien.pos + moveToDir * mj:mToP(rng:randomValue() * 10.0 + 40.0)
    local clampToSeaLevel = true
    moveToPos = worldHelper:getBelowSurfacePos(moveToPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
    local orderContext = nil--{planTypeIndex = plan.types.moveTo.index}
    local pathInfo = order:createOrderPathInfo(nil, pathFinding.proximityTypes.goalPos, nil, moveToPos)
    serverSapien:addOrder(sapien, order.types.flee.index, pathInfo, nil, orderContext, false)
end

function serverSapienAI:frequentUpdate(sapien, dt, speedMultiplier, bestPlanInfo)
    local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
    if unsavedState.agroMobRunAwayDirection then
        serverSapienAI:addOrderToFlee(sapien, unsavedState.agroMobRunAwayDirection)
        unsavedState.agroMobRunAwayDirection = nil
    else
        if bestPlanInfo then
            findOrderAI:actOnLookAtResult(sapien, bestPlanInfo, dt)
        end
    end

    if sapien.sharedState.activeOrder and sapien.sharedState.actionState then
        activeOrderAI:frequentUpdate(sapien, dt, speedMultiplier) --29%
    end
end

function serverSapienAI:resetAIState(sapienID)
    serverSapienAI.aiStates[sapienID] = {
        socialTimer = rng:randomValue() * totalSocialTimersLength
    }
end

function serverSapienAI:sapienLoaded(sapien)
    sapien.sharedState:remove("lookAtPoint")
    sapien.sharedState:remove("lookAtObjectID")
    serverSapienAI:resetAIState(sapien.uniqueID)
end


function serverSapienAI:sapienUnloaded(sapien)
    serverSapienAI.aiStates[sapien.uniqueID] = nil
end

function serverSapienAI:announce(sapien, announcementTypeIndex, objectID)--, pos, distanceSquared)
    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    if aiState then
        if objectID then
            local cooldowns = serverSapienAI.aiStates[sapien.uniqueID].cooldowns
            if cooldowns then
                cooldowns["plan_" .. objectID] = nil
                cooldowns["m_" .. objectID] = nil
            end
        end

        --[[ if (not aiState.queuedPlanAnnouncementToLookAt) or aiState.queuedPlanAnnouncementToLookAt.distanceSquared > distanceSquared then
            aiState.queuedPlanAnnouncementToLookAt = {
                objectID = objectID,
                pos = pos,
                distanceSquared = distanceSquared
            }
        end]]
    end
end

function serverSapienAI:checkNeedsAllowObjectTypeToBeCarried(resourceTypeIndex, foodDesire, restDesire, sleepDesire, happySadMood)
    if foodDesire >= desire.levels.mild then
        local foodValue = resource.types[resourceTypeIndex].foodValue
        if foodValue then
            return true
        end
    end

    local maxSleepRestDesire = math.max(restDesire, sleepDesire)
    if maxSleepRestDesire >= desire.levels.strong then
        return false
    end

    --[[if happySadMood <= mood.levels.severeNegative then
        return false
    end]] --comented out as it is too dangerous. better to rely on not queuing up plans due to mood somewhere else

    return true
end


function serverSapienAI:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverSapien = initObjects.serverSapien
    serverWorld = initObjects.serverWorld
    serverDestination = initObjects.serverDestination

    activeOrderAI:init(initObjects)
    findOrderAI:init(initObjects)
    multitask:init(initObjects)
    conversation:init(initObjects)
    
end

return serverSapienAI