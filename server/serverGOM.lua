local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local length = mjm.length
local length2 = mjm.length2
local mat3Identity = mjm.mat3Identity
local mat3GetRow = mjm.mat3GetRow
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3Rotate = mjm.mat3Rotate
local cross = mjm.cross
local mat3LookAtInverse = mjm.mat3LookAtInverse
--local vec3xMat3 = mjm.vec3xMat3
--local mat3Inverse = mjm.mat3Inverse

local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"
local order = mjrequire "common/order"
local constructable = mjrequire "common/constructable"
local rng = mjrequire "common/randomNumberGenerator"
local terrain = mjrequire "server/serverTerrain"
local physics = mjrequire "common/physics"
local physicsSets = mjrequire "common/physicsSets"
local worldHelper = mjrequire "common/worldHelper"
local resource = mjrequire "common/resource"
local timer = mjrequire "common/timer"
local gameConstants = mjrequire "common/gameConstants"
local model = mjrequire "common/model"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local objectInventory = mjrequire "common/objectInventory"
local fuel = mjrequire "common/fuel"
local tool = mjrequire "common/tool"
local notification = mjrequire "common/notification"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
local harvestable = mjrequire "common/harvestable"
--local pathBuildable = mjrequire "common/pathBuildable"
--local statistics = mjrequire "common/statistics"
local skill = mjrequire "common/skill"
local flora = mjrequire "common/flora"
local research = mjrequire "common/research"

local planManager = mjrequire "server/planManager"
local planLightProbes = mjrequire "server/planLightProbes"
local serverSapien = mjrequire "server/serverSapien"
local serverSapienSkills = mjrequire "server/serverSapienSkills"
local serverStorageArea = mjrequire "server/serverStorageArea"
local serverCraftArea = mjrequire "server/serverCraftArea"
local serverLogistics = mjrequire "server/serverLogistics"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverEvolvingObject = mjrequire "server/serverEvolvingObject"
local server = mjrequire "server/server"
local serverGameObjectSharedState = mjrequire "server/serverGameObjectSharedState"
local sapienObjectSnapping = mjrequire "server/sapienObjectSnapping"
local anchor = mjrequire "server/anchor"
--local serverStatistics = mjrequire "server/serverStatistics"
local serverNotifications = mjrequire "server/serverNotifications"
local serverFuel = mjrequire "server/serverFuel"
local serverTutorialState = mjrequire "server/serverTutorialState"
local serverSapienAI = mjrequire "server/sapienAI/ai"

local serverMob = mjrequire "server/objects/serverMob"
local serverFlora = mjrequire "server/objects/serverFlora"

local serverBuiltObject = mjrequire "server/objects/serverBuiltObject"
local serverCampfire = mjrequire "server/objects/serverCampfire"
local serverKiln = mjrequire "server/objects/serverKiln"
local serverLitObject = mjrequire "server/objects/serverLitObject"
local serverTorch= mjrequire "server/objects/serverTorch"
local serverSeat = mjrequire "server/objects/serverSeat"
local serverCompostBin = mjrequire "server/objects/serverCompostBin"
local serverWeather = mjrequire "server/serverWeather"


local serverGOM = {
}

local allObjects = {}
serverGOM.allObjects = allObjects
local sapienObjects = {}
serverGOM.sapienObjectsByTribe = {}
serverGOM.loadedSapienCountsByTribe = {}
serverGOM.totalLoadedSapienCount = 0



serverGOM.sentFollowerIDsSetByClient = {}

local objectLoadedFunctionsByType = {}
local objectUnloadedFunctionsByType = {}
local objectCoveredStatusChangedFunctionsByType = {}
local objectTransientInspectionFunctionsByType = {}

local bridge = nil

--local maxAutoOrderDistanceSquared = mj:mToP(500.0) * mj:mToP(500.0)

local serverWorld = nil
local serverDestination = nil
local serverTribe = nil
local serverTribeAIPlayer = nil

local inaccessibleCheckCount = 2

local cachedLitObjects = nil


serverGOM.coveredTestRayLength = mj:mToP(100.0)
serverGOM.coveredTestRayStartOffsetLength = mj:mToP(0.5)

function serverGOM:createObjectSet(objectSetName)
    return bridge:createObjectSet(objectSetName)
end

function serverGOM:createObjectSets()
    serverGOM.objectSets = {
        sapiens = serverGOM:createObjectSet("sapiens"),

        plans = serverGOM:createObjectSet("plans"),
        maintenance = serverGOM:createObjectSet("maintenance"),
        
        logistics = serverGOM:createObjectSet("logistics"),
        craftAreas = serverGOM:createObjectSet("craftAreas"),

        beds = serverGOM:createObjectSet("beds"),
        inProgressBeds = serverGOM:createObjectSet("inProgressBeds"),
        seats = serverGOM:createObjectSet("seats"),

        interestingToLookAt = serverGOM:createObjectSet("interestingToLookAt"),

        litCampfires = serverGOM:createObjectSet("litCampfires"),
        litKilns = serverGOM:createObjectSet("litKilns"),
        litTorches = serverGOM:createObjectSet("litTorches"),
        litObjects = serverGOM:createObjectSet("litObjects"),

        unlitCampfires = serverGOM:createObjectSet("unlitCampfires"),
        
        musicPlayers = serverGOM:createObjectSet("musicPlayers"),

        mobs = serverGOM:createObjectSet("mobs"),
        landMobs = serverGOM:createObjectSet("landMobs"),
        chickens = serverGOM:createObjectSet("chickens"),
        alpacas = serverGOM:createObjectSet("alpacas"),
        mammoths = serverGOM:createObjectSet("mammoths"),
        catfish = serverGOM:createObjectSet("catfish"),
        coelacanth = serverGOM:createObjectSet("coelacanth"),
        flagellipinna = serverGOM:createObjectSet("flagellipinna"),
        polypterus = serverGOM:createObjectSet("polypterus"),
        redfish = serverGOM:createObjectSet("redfish"),
        tropicalfish = serverGOM:createObjectSet("tropicalfish"),
        swordfish = serverGOM:createObjectSet("swordfish"),
        
        coveredStatusObservers = serverGOM:createObjectSet("coveredStatusObservers"),
        pathingCollisionObservers = serverGOM:createObjectSet("pathingCollisionObservers"),
        inaccessible = serverGOM:createObjectSet("inaccessible"),
        soilQualityStatusObservers = serverGOM:createObjectSet("soilQualityStatusObservers"),

        temperatureIncreasers = serverGOM:createObjectSet("temperatureIncreasers"),
        temperatureDecreasers = serverGOM:createObjectSet("temperatureDecreasers"),
        
        lightEmitters = serverGOM:createObjectSet("lightEmitters"),
        lightObservers = serverGOM:createObjectSet("lightObservers"),

        --playerSapiens = serverGOM:createObjectSet("playerSapiens"),
        --nomads = serverGOM:createObjectSet("nomads"),

        compostBins = serverGOM:createObjectSet("compostBins"),
        
        windAffectedHighChance = serverGOM:createObjectSet("windAffectedHighChance"),
        windAffectedModerateChance = serverGOM:createObjectSet("windAffectedModerateChance"),
        windAffectedLowChance = serverGOM:createObjectSet("windAffectedLowChance"),

        rainAffectedLowChance = serverGOM:createObjectSet("rainAffectedLowChance"),

        aiTribeGatherableFood = serverGOM:createObjectSet("aiTribeGatherableFood"),

        waterRideableObjects = serverGOM:createObjectSet("waterRideableObjects"),
    }
end


function serverGOM:init()
    --mj:log("serverGOM:init")
    gameObjectSharedState:init(serverGOM)
    worldHelper:setGOM(serverGOM, modelPlaceholder)

    serverGOM:createObjectSets()

    serverGOM.objectSets.planObjectsWithoutRequiredSkill = serverGOM:createObjectSet("planObjectsWithoutRequiredSkill")
    
    serverGOM:addProximityCallbackForGameObjectsInSet(serverGOM.objectSets.planObjectsWithoutRequiredSkill, serverGOM.objectSets.sapiens, planManager.maxPlanDistance, function(planObjectID, sapienID, distance2, newIsClose)
        planManager:updateProximity(nil, planObjectID, sapienID, newIsClose)
    end)

    for i,skillType in ipairs(skill.validTypes) do
        local planObjectSetKey = "planObjectsBySkill_" .. skillType.key
        local planObjectSetIndex = serverGOM:createObjectSet(planObjectSetKey)
        skillType.planObjectSetIndex = planObjectSetIndex
        serverGOM.objectSets[planObjectSetKey] = planObjectSetIndex
        
        local sapienSetKey = "sapiensBySkill_" .. skillType.key
        local sapienSetIndex = serverGOM:createObjectSet(sapienSetKey)
        skillType.sapienSetIndex = sapienSetIndex
        serverGOM.objectSets[sapienSetKey] = sapienSetIndex

        --mj:log("adding proximity callback planObjectSetIndex:", planObjectSetIndex, " sapienSetIndex:", sapienSetIndex)
        
        serverGOM:addProximityCallbackForGameObjectsInSet(planObjectSetIndex, sapienSetIndex, planManager.maxPlanDistance, function(planObjectID, sapienID, distance2, newIsClose)
            planManager:updateProximity(skillType.index, planObjectID, sapienID, newIsClose)
        end)
    end


    for i,resourceType in ipairs(resource.validTypes) do --brute force as it is cheap. Not all resource types are required here, only those that can be gathered.
        local aiTribeGatherableResourceKey = "aiTribeGatherableResource_" .. resourceType.key
        local setIndex = serverGOM:createObjectSet(aiTribeGatherableResourceKey)
        serverGOM.objectSets[aiTribeGatherableResourceKey] = setIndex
    end

    --aiTribeGatherableResource_branch = serverGOM:createObjectSet("aiTribeGatherableResource_branch"),

    local initObjects = {
        serverGOM = serverGOM,
        serverSapien = serverSapien,
        serverCraftArea = serverCraftArea,
        serverWorld = serverWorld,
        serverTribe = serverTribe,
    }

	serverGameObjectSharedState:init(serverGOM)
    anchor:init(serverGOM, serverWorld, serverDestination)
    serverSapien:init(serverGOM, serverWorld, serverTribe, serverDestination, serverStorageArea)
    serverStorageArea:init(serverGOM, serverWorld, planManager, serverSapien, serverTribe, serverTribeAIPlayer, serverDestination)
    serverCraftArea:init(serverGOM, serverWorld, serverSapien, planManager, serverStorageArea)
    serverLogistics:init(serverGOM, serverWorld, serverSapien, serverStorageArea, serverCraftArea)
    serverEvolvingObject:init(serverGOM, serverWorld, serverStorageArea)
    serverCampfire:init(serverGOM, serverWorld, planManager)
    serverKiln:init(serverGOM, serverWorld, planManager)
    serverLitObject:init(serverGOM, serverWorld, planManager)
    serverBuiltObject:init(serverGOM, serverWorld, planManager)
    serverTorch:init(serverGOM, serverWorld, planManager)
    serverMob:init(serverGOM, serverWorld, serverSapien, serverSapienAI, planManager)
    serverFlora:init(serverGOM, serverWorld, planManager, serverSapien)
    planManager:init(initObjects)
    sapienObjectSnapping:init(serverGOM)
    serverSeat:init(serverGOM, serverWorld, serverSapien)
    serverCompostBin:init(serverGOM, serverWorld, planManager)
	serverWeather:init(server, serverWorld, serverGOM, planManager, serverStorageArea, serverFlora)
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.bedTypes, function(bed)
        serverGOM:addObjectToSet(bed, serverGOM.objectSets.beds)
        serverGOM:addObjectToSet(bed, serverGOM.objectSets.coveredStatusObservers)
        serverWorld.needsToUpdateBedCounts = true
        return false
    end)
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.inProgressBedTypes, function(bed)
        serverGOM:addObjectToSet(bed, serverGOM.objectSets.inProgressBeds)
        serverGOM:addObjectToSet(bed, serverGOM.objectSets.coveredStatusObservers)
        return false
    end)

    serverGOM:addObjectLoadedFunctionForTypes({gameObject.types.canoe.index, gameObject.types.coveredCanoe.index}, function(boat)
        if boat.sharedState.waterRideable then
            serverGOM:addObjectToSet(boat, serverGOM.objectSets.waterRideableObjects)
        end
        return false
    end)
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.craftAreaTypes, function(object)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.craftAreas)

        if object.sharedState.inProgressConstructableTypeIndex then --no longer stored here, must be derived from the planState instead
            if object.sharedState.inProgressConstructableTypeIndex == constructable.types.brickBuildingResearch.index then --deprecated 0.4
                local tribeID = object.sharedState.tribeID
                serverCraftArea:planWasCancelledForCraftObject(object, plan.types.research.index, tribeID)
                local removed = serverGOM:removeIfTemporaryCraftAreaAndDropInventoryIfNeeded(object, tribeID, nil, nil, nil)
                if removed then
                    return true
                end
            end

            object.sharedState:remove("inProgressConstructableTypeIndex")
        end
        return false
    end)

    serverGOM:addObjectLoadedFunctionForTypes(gameObject.windDestructableHighChanceTypes, function(object)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.windAffectedHighChance)
        return false
    end)
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.windDestructableModerateChanceTypes, function(object)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.windAffectedModerateChance)
        return false
    end)
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.windDestructableLowChanceTypes, function(object)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.windAffectedLowChance)
        return false
    end)
    
    serverGOM:addObjectLoadedFunctionForTypes(gameObject.rainDestructableLowChanceTypes, function(object)
        local rainfallValues = nil
        if object.privateState then
            rainfallValues = object.privateState.cachedRainfallValues
            --mj:log("found cached rainfall:", rainfallValues, " object:", object.uniqueID)
        end
        if not rainfallValues then
            rainfallValues = terrain:getRainfallForNormalizedPoint(object.normalizedPos)
            if not object.privateState then
                object.privateState = {}
            end
            object.privateState.cachedRainfallValues = rainfallValues
            serverGOM:saveObject(object.uniqueID)
            --mj:log("generated rainfall:", rainfallValues, " object:", object.uniqueID)
        end
        if rainfallValues[1] > gameConstants.minRainfallForRainDamage or rainfallValues[2] > gameConstants.minRainfallForRainDamage then
            serverGOM:addObjectToSet(object, serverGOM.objectSets.rainAffectedLowChance)
        end
        return false
    end)

    serverGOM:addObjectUnloadedFunctionForType(gameObject.bedTypes, function(bed)
        serverWorld.needsToUpdateBedCounts = true
    end)

    serverGOM:addObjectLoadedFunctionForTypes(gameObject.automaticAnchorTypes, function(object)
        local gameObjectType = gameObject.types[object.objectTypeIndex]
		if gameObjectType.anchorType then
            anchor:addAnchor(object.uniqueID, gameObjectType.anchorType, object.sharedState.tribeID)
        end
    end)

    serverGOM:addObjectUnloadedFunctionForType(gameObject.automaticAnchorTypes, function(object)
        local gameObjectType = gameObject.types[object.objectTypeIndex]
		if gameObjectType.anchorType then
            anchor:anchorObjectUnloaded(object.uniqueID)
        end
    end)


    bridge.objectDynamicPhysicsChangedFunction = function(objectID, dynamicPhysics)
        local object = allObjects[objectID]
        if object then
            object.dynamicPhysics = dynamicPhysics
            if not dynamicPhysics then
                local minInactiveShiftDistance = mj:mToP(0.1)
                local minInactiveShiftDistance2 = minInactiveShiftDistance * minInactiveShiftDistance

                serverResourceManager:updateResourcesForObject(object)
                serverGOM:testAndUpdateCoveredStatusIfNeeded(object)

                local clampToSeaLevel = true
                local shiftedPos = worldHelper:getBelowSurfacePos(object.pos, 0.1, nil, nil, clampToSeaLevel)
                if length2(shiftedPos - object.pos) > minInactiveShiftDistance2 then
                    serverGOM:setPos(object.uniqueID, shiftedPos, true)
                    --mj:log("objectDynamicPhysicsChangedFunction pos altitude:", mj:pToM(mjm.length(shiftedPos) - 1.0))
                    serverGOM:saveObject(object.uniqueID)
                end
            end
        end
    end
    
    bridge.deltaCompressSharedStateFunction = function(objectID)
        local object = allObjects[objectID]
        if object then
            return serverGameObjectSharedState:getAndResetStateDiff(object)
        end
        return nil
    end

    bridge.objectMatrixChangedFunction = function(objectID, pos, rotation)
        local object = allObjects[objectID]
        if object then
            object.pos = pos
            object.normalizedPos = normalize(pos)
            object.rotation = rotation
        end
    end

    bridge.objectModelIndexFunction = function(objectID, subdivLevel, terrainVariations)
        local object = allObjects[objectID]
        if object then
            object.modelIndex = gameObject:modelIndexForGameObjectAndLevel(object, subdivLevel, terrainVariations)
            return object.modelIndex or 4294967295
        end
        return 4294967295
    end
    
    --serverGOM:addObjectToSet(bed, serverGOM.objectSets.seats)

end

function serverGOM:setServerWorld(serverWorld_, serverTribe_, serverTribeAIPlayer_, serverDestination_)
    --mj:log("serverGOM:setServerWorld")
    serverWorld = serverWorld_
    serverTribe = serverTribe_
    serverTribeAIPlayer = serverTribeAIPlayer_
    serverDestination = serverDestination_
    serverSapienSkills:setServerGOM(serverGOM, serverWorld, serverSapien)
    if bridge then
        serverGOM:init()
    end
end

function serverGOM:addObjectLoadedFunctionForType(type, func)
    if not objectLoadedFunctionsByType[type] then
        objectLoadedFunctionsByType[type] = {}
    end

    table.insert(objectLoadedFunctionsByType[type], func)
end

function serverGOM:addObjectLoadedFunctionForTypes(types, func)
    for i,type in ipairs(types) do
        serverGOM:addObjectLoadedFunctionForType(type, func)
    end
end

function serverGOM:addObjectUnloadedFunctionForType(type, func)
    if not objectUnloadedFunctionsByType[type] then
        objectUnloadedFunctionsByType[type] = {}
    end

    table.insert(objectUnloadedFunctionsByType[type], func)
end

function serverGOM:addObjectUnloadedFunctionForTypes(types, func)
    for i,type in ipairs(types) do
        serverGOM:addObjectUnloadedFunctionForType(type, func)
    end
end


function serverGOM:addObjectCoveredStatusChangedFunctionForType(type, func)
    if not objectCoveredStatusChangedFunctionsByType[type] then
        objectCoveredStatusChangedFunctionsByType[type] = {}
    end

    table.insert(objectCoveredStatusChangedFunctionsByType[type], func)
end

function serverGOM:addTransientInspectionFunctionForType(type, func)
    if not objectTransientInspectionFunctionsByType[type] then
        objectTransientInspectionFunctionsByType[type] = {}
    end

    table.insert(objectTransientInspectionFunctionsByType[type], func)
end

function serverGOM:addTransientInspectionFunctionForTypes(types, func)
    for i,type in ipairs(types) do
        serverGOM:addTransientInspectionFunctionForType(type, func)
    end
end

function serverGOM:addObjectCallbackTimerForWorldTime(objectID, time, func)
    return bridge:addObjectCallbackTimerForWorldTime(objectID, time, func)
end

function serverGOM:removeObjectCallbackTimerWithID(objectID, callBackTimerID)
    bridge:removeObjectCallbackTimerWithID(objectID, callBackTimerID)
end

function serverGOM:removeObjectCallbackTimers(objectID)
    bridge:removeObjectCallbackTimers(objectID)
end

function serverGOM:createSharedState(object)
    object.sharedState = {}
    bridge:setSharedState(object.uniqueID, object.sharedState)
end

function serverGOM:getPrivateState(object)
    if not object.privateState then
        object.privateState = {}
        bridge:setPrivateState(object.uniqueID, object.privateState)
    end
    return object.privateState
end

function serverGOM:createLazyPrivateState(object)
    object.lazyPrivateState = {}
    bridge:setLazyPrivateState(object.uniqueID, object.lazyPrivateState)
end

function serverGOM:getUnsavedPrivateState(object)
    if not object.temporaryPrivateState then
        object.temporaryPrivateState = {}
    end
    return object.temporaryPrivateState
end

function serverGOM:ensureSharedStateLoaded(object)
    if not object.sharedState then
        if serverGOM:isStored(object.uniqueID) then
            serverGOM:createSharedState(object)
        else
            local stateFunction = gameObject.types[object.objectTypeIndex].initialTransientStateFunction
            if stateFunction then
                object.sharedState = stateFunction(object.uniqueID,
                object.objectTypeIndex,
                object.scale,
                object.pos)
                bridge:setSharedState(object.uniqueID, object.sharedState)
            else
                serverGOM:createSharedState(object)
            end
        end

        gameObjectSharedState:setupState(object, object.sharedState)
    end
end

function serverGOM:getSharedState(object, createIfNil, ...)
    if createIfNil then
        serverGOM:ensureSharedStateLoaded(object)
    end

    local sharedState = object.sharedState
    if sharedState then
        local result = sharedState
        
        for i,member in ipairs{...} do
            local nextResult = result[member]
            if not nextResult then
                if createIfNil then
                    nextResult = {}
                    result[member] = nextResult
                else
                    return nil
                end
            end
            result = nextResult
        end

        return result
    end

    return nil
end

local findDirectionFOVMinDot = 0.0
local findDirectionInnerRadius = mj:mToP(4.0) --objects within this radius will be returned even if dot product test fails

function serverGOM:findObjectsInDirectionInSet(rayStart, rayEnd, limitSet) 
    return bridge:findObjectsInDirectionInSet(rayStart, rayEnd, findDirectionFOVMinDot, limitSet, findDirectionInnerRadius)
end

function serverGOM:removeGatherObjectFromInventory(object, objectTypeIndex)
    local objectState = object.sharedState
    local inventory = objectState.inventory

   -- mj:log("objectTypeIndex:", objectTypeIndex)
   -- mj:log("serverGOM:removeGatherObjectFromInventory a:", inventory)


    if inventory and inventory.countsByObjectType then
        if inventory.countsByObjectType[objectTypeIndex] > 0 then
           -- mj:log("serverGOM:removeGatherObjectFromInventory b:", inventory)
            if not gameConstants.debugInfiniteGather then
                objectState:set("inventory", "countsByObjectType", objectTypeIndex, inventory.countsByObjectType[objectTypeIndex] - 1)
            end

            local objectInfoToReturn = nil

            if inventory.objects then
                local objects = inventory.objects
                for i = #objects, 1, -1 do
                    local objectInfo = objects[i]
                    if objectInfo.objectTypeIndex == objectTypeIndex then
                        objectInfoToReturn = objectInfo
                        if not gameConstants.debugInfiniteGather then
                            --mj:log("removing from inventory:", object.uniqueID, " index:", i)
                            objectState:removeFromArray("inventory", "objects", i)
                            --[[for j = i,#objects - 1 do
                                objectState:set("inventory", "objects", j, objects[j + 1])
                            end
                            objectState:remove("inventory", "objects", #objects)]]
                        end
                        break
                    end
                end
            end

            --mj:log("gameObject.types[objectTypeIndex]:", gameObject.types[objectTypeIndex])

           -- if 
            if gameObject.types[object.objectTypeIndex].floraTypeIndex then
                serverFlora:addCallbackToGrowFruitNextSeasonIfNeeded(object)
                serverFlora:updateGatherableResourceSets(object)
            end

            return objectInfoToReturn
        end
    end

    return nil
end


function serverGOM:getStateForAdditionToInventory(addObject)

	local additionInfo = {
        objectTypeIndex = addObject.objectTypeIndex,
    }
    
    if addObject.sharedState then
        
        if addObject.sharedState.fractionDegraded or addObject.sharedState.degradeReferenceTime then
            additionInfo.fractionDegraded = addObject.sharedState.fractionDegraded
            additionInfo.degradeReferenceTime = addObject.sharedState.degradeReferenceTime
        end

        if gameObject.types[addObject.objectTypeIndex].preservesConstructionObjects then
            additionInfo.constructionObjects = addObject.sharedState.constructionObjects
            additionInfo.constructionConstructableTypeIndex = addObject.sharedState.constructionConstructableTypeIndex
        end
        additionInfo.usedPortionCount = addObject.sharedState.usedPortionCount
        additionInfo.contaminationResourceTypeIndex = addObject.sharedState.contaminationResourceTypeIndex
        
        additionInfo.restrictedResourceObjectTypes = addObject.sharedState.restrictedResourceObjectTypes
        additionInfo.restrictedToolObjectTypes = addObject.sharedState.restrictedToolObjectTypes

        additionInfo.name = addObject.sharedState.name
    end

    return additionInfo
end

function serverGOM:stripObjectInfoForAdditionToInventory(objectInfo)
	local additionInfo = {
        objectTypeIndex = objectInfo.objectTypeIndex,
    }
    
    if objectInfo.fractionDegraded or additionInfo.degradeReferenceTime then
        additionInfo.fractionDegraded = objectInfo.fractionDegraded
        additionInfo.degradeReferenceTime = objectInfo.degradeReferenceTime
    end
    
    
    if gameObject.types[objectInfo.objectTypeIndex].preservesConstructionObjects then
        additionInfo.constructionObjects = objectInfo.constructionObjects
        additionInfo.constructionConstructableTypeIndex = objectInfo.constructionConstructableTypeIndex
    end
    
    additionInfo.usedPortionCount = objectInfo.usedPortionCount
    additionInfo.contaminationResourceTypeIndex = objectInfo.contaminationResourceTypeIndex
    
    additionInfo.restrictedResourceObjectTypes = objectInfo.restrictedResourceObjectTypes
    additionInfo.restrictedToolObjectTypes = objectInfo.restrictedToolObjectTypes

    additionInfo.name = objectInfo.name

    return additionInfo
end

function serverGOM:getSharedStateForRemovalFromInventory(inventoryRemovalObjectInfo)
    local sharedState = {}

    sharedState.fractionDegraded = inventoryRemovalObjectInfo.fractionDegraded
    sharedState.usedPortionCount = inventoryRemovalObjectInfo.usedPortionCount
    sharedState.contaminationResourceTypeIndex = inventoryRemovalObjectInfo.contaminationResourceTypeIndex
    sharedState.degradeReferenceTime = inventoryRemovalObjectInfo.degradeReferenceTime
    sharedState.constructionConstructableTypeIndex = inventoryRemovalObjectInfo.constructionConstructableTypeIndex
    sharedState.constructionObjects = inventoryRemovalObjectInfo.constructionObjects
    sharedState.restrictedResourceObjectTypes = inventoryRemovalObjectInfo.restrictedResourceObjectTypes
    sharedState.restrictedToolObjectTypes = inventoryRemovalObjectInfo.restrictedToolObjectTypes
    sharedState.name = inventoryRemovalObjectInfo.name
    
    return sharedState
end

--note this returns all required items for the entire build, and shouldn't be used to determine whether a given item is needed right now. 
-- use serverGOM:getNextRequiredItems for that purpose
function serverGOM:getRequiredItemsNotInInventory(buildObject, planState, allRequiredTools, allRequiredResourceTypesOrGroups, constructableTypeIndex) 

    local result = nil

    local function setAllResourcesRequired()
        if allRequiredResourceTypesOrGroups then
            if not result then
                result = {}
            end

            result.resources = allRequiredResourceTypesOrGroups
        end
    end

    local function setAllRequired()
        if allRequiredTools or allRequiredResourceTypesOrGroups then
            result = {
                tools = allRequiredTools,
            }
            setAllResourcesRequired()
        end
    end

    local inventories = buildObject.sharedState.inventories

    if not inventories then
        setAllRequired()
        return result
    end

   -- local restrictedResourceObjectTypes = buildObject.sharedState.restrictedResourceObjectTypes

   --[[ if planState.constructableTypeIndex then
        restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(planState.tribeID, constructableTypeIndex, restrictedResourceObjectTypes)
    elseif plan.types[planState.planTypeIndex].isMedicineTreatment then
        restrictedResourceObjectTypes = serverWorld:getResourceBlockListForMedicineTreatment(planState.tribeID, restrictedResourceObjectTypes)
    end]]
    
    --local restrictedToolObjectTypes = buildObject.sharedState.restrictedToolObjectTypes

    local toolBlockList = nil
    local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(planState.tribeID)
    if resourceBlockLists then
        toolBlockList = resourceBlockLists.toolBlockList
    end

   -- mj:log("inventoryObjects:", inventoryObjects)
   -- mj:log("allRequiredToolIndices:", allRequiredToolIndices)
   -- mj:log("allRequiredResources:", allRequiredResources)

    

    if allRequiredResourceTypesOrGroups then
        
            
        local inventoryObjectTypeIndicesAvailable = {}

        if inventories[objectInventory.locations.availableResource.index] then
            local inventoryObjects = inventories[objectInventory.locations.availableResource.index].objects
            if inventoryObjects then
                for i, objectInfo in ipairs(inventoryObjects) do
                    table.insert(inventoryObjectTypeIndicesAvailable, objectInfo.objectTypeIndex)
                end
            end
        end
        if inventories[objectInventory.locations.inUseResource.index] then
            local inventoryObjects = inventories[objectInventory.locations.inUseResource.index].objects
            if inventoryObjects then
                for i, objectInfo in ipairs(inventoryObjects) do
                    table.insert(inventoryObjectTypeIndicesAvailable, objectInfo.objectTypeIndex)
                end
            end
        end

        if not inventoryObjectTypeIndicesAvailable[1] then
            setAllResourcesRequired()
        else

            local function addResourceGroupRequired(requiredResourceInfo, notFoundCount)
                if not result then
                    result = {}
                end

                if not result.resources then
                    result.resources = {}
                end
                
                local resourceGroupInfoToAdd = mj:cloneTable(requiredResourceInfo)
                resourceGroupInfoToAdd.count = notFoundCount
                table.insert(result.resources, resourceGroupInfoToAdd)

            end

            
            for i,requiredResourceInfo in ipairs(allRequiredResourceTypesOrGroups) do
                local notFoundCount = 0
                for j=1,requiredResourceInfo.count do
                    local matchIndex = nil
                    for k,inventoryObjectTypeIndex in ipairs(inventoryObjectTypeIndicesAvailable) do
                        --if (not restrictedResourceObjectTypes) or (not restrictedResourceObjectTypes[inventoryObjectTypeIndex]) then
                            if requiredResourceInfo.objectTypeIndex then
                                if requiredResourceInfo.objectTypeIndex == inventoryObjectTypeIndex then
                                    matchIndex = k
                                    break
                                end
                            else
                                if resource:groupOrResourceMatchesResource(requiredResourceInfo.type or requiredResourceInfo.group, gameObject.types[inventoryObjectTypeIndex].resourceTypeIndex) then
                                    matchIndex = k
                                    break
                                end
                            end
                       -- end
                    end
                    if matchIndex then
                        table.remove(inventoryObjectTypeIndicesAvailable, matchIndex)
                    else
                        notFoundCount = notFoundCount + 1
                    end
                end
                if notFoundCount > 0 then
                    addResourceGroupRequired(requiredResourceInfo, notFoundCount)
                end
            end
        end
    end

    if allRequiredTools then
        local function addToolIndexRequired(requiredToolIndex)
            if not result then
                result = {}
            end

            if not result.tools then
                result.tools = {}
            end

            table.insert(result.tools, requiredToolIndex)
        end
        
        local inventoryObjectTypeIndicesAvailable = {}
        
        if inventories[objectInventory.locations.tool.index] then
            local inventoryObjects = inventories[objectInventory.locations.tool.index].objects
            if inventoryObjects then
                for i, objectInfo in ipairs(inventoryObjects) do
                    table.insert(inventoryObjectTypeIndicesAvailable, objectInfo.objectTypeIndex)
                end
            end
        end

        if not inventoryObjectTypeIndicesAvailable[1] then
            if not result then
                result = {}
            end
            result.tools = allRequiredTools
        else
            
            for l,toolTypeIndex in ipairs(allRequiredTools) do
                local matchIndex = nil
                for j,inventoryObjectTypeIndex in ipairs(inventoryObjectTypeIndicesAvailable) do
                    --if (not restrictedToolObjectTypes) or (not restrictedToolObjectTypes[inventoryObjectTypeIndex]) then
                        if (not toolBlockList) or (not toolBlockList[inventoryObjectTypeIndex]) then
                            for k,suitableObjectTypeIndex in ipairs(gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex]) do
                                if suitableObjectTypeIndex == inventoryObjectTypeIndex then
                                    matchIndex = j
                                    break
                                end
                            end
                            if matchIndex then
                                break
                            end
                        end
                    --end
                end
                if matchIndex then
                    table.remove(inventoryObjectTypeIndicesAvailable, matchIndex)
                else
                    addToolIndexRequired(toolTypeIndex)
                end
            end
        end
    end

    --mj:log("result:", result)
    return result
end

function serverGOM:objectTypeIndexIsRestrictedForPlan(planObject, planState, objectTypeIndex, isTool) --this is also used for chopping and digging, which have no constructable.
    if isTool then
        local toolBlockList = nil
        local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(planState.tribeID)
        if resourceBlockLists then
            toolBlockList = resourceBlockLists.toolBlockList
        end

        if toolBlockList and toolBlockList[objectTypeIndex] then
            return true
        end

        local restrictedToolObjectTypes = planObject.sharedState.restrictedToolObjectTypes or planState.restrictedToolObjectTypes
        if restrictedToolObjectTypes then
            return restrictedToolObjectTypes[objectTypeIndex] ~= nil
        end
    else
        
        local restrictedResourceObjectTypes = planObject.sharedState.restrictedResourceObjectTypes
        if planState.constructableTypeIndex then
            restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(planState.tribeID, planState.constructableTypeIndex, restrictedResourceObjectTypes)
        elseif plan.types[planState.planTypeIndex].isMedicineTreatment then
            restrictedResourceObjectTypes = serverWorld:getResourceBlockListForMedicineTreatment(planState.tribeID, restrictedResourceObjectTypes)
        elseif planState.planTypeIndex == plan.types.light.index then
            local fuelGroup = fuel.groupsByObjectTypeIndex[planObject.objectTypeIndex]
            if fuelGroup then
                restrictedResourceObjectTypes = serverWorld:getResourceBlockListForFuel(planState.tribeID, fuelGroup.index, restrictedResourceObjectTypes)
            end
        end

       -- mj:log("serverGOM:objectTypeIndexIsRestrictedForPlan:", planObject.uniqueID, " restrictedResourceObjectTypes:", restrictedResourceObjectTypes, " objectTypeIndex:", objectTypeIndex)
        
        if restrictedResourceObjectTypes then
            return restrictedResourceObjectTypes[objectTypeIndex] ~= nil
        end
    end

    return false
end


function serverGOM:getNextRequiredItems(buildObjectOrCraftArea, planState)
    --mj:log("serverGOM:getNextRequiredItems planState:", planState)
    if not planState then
        return nil
    end
    
    if not planState.canComplete then
        return nil
    end

    local requiredResources = planState.requiredResources
    if requiredResources and requiredResources[1] then
       -- mj:log("serverGOM:getNextRequiredItems requiredResources:", requiredResources)
        return {
            resources = requiredResources
        }--serverGOM:getRequiredItemsNotInInventory(buildObjectOrCraftArea, nil, requiredResources, false) 
    else
        local requiredTools = planState.requiredTools
        if requiredTools then
            return {
                tools = requiredTools
            }--serverGOM:getRequiredItemsNotInInventory(buildObjectOrCraftArea, requiredTools, nil, false) 
        end
    end

    return nil
end

function serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(planObject, objectTypeIndex, planState, tribeID)

    if (not planState) or (planState.planTypeIndex == plan.types.addFuel.index or planState.planTypeIndex == plan.types.light.index) then
        --mj:log("inventoryLocationifObjectTypeIndexIsRequiredForPlanObject a")
        if serverFuel:objectRequiresFuelOfType(planObject, objectTypeIndex, tribeID) then
            --mj:log("inventoryLocationifObjectTypeIndexIsRequiredForPlanObject b")
            return objectInventory.locations.availableResource.index
        end
    end

    if (not planState) or (planState.planTypeIndex == plan.types.deliverToCompost.index) then
        if serverCompostBin:compostBinRequiresObjectOfType(planObject, objectTypeIndex, tribeID) then
            return objectInventory.locations.availableResource.index
        end
    end

    if not planState then
        return nil
    end

    if plan.types[planState.planTypeIndex].isMedicineTreatment then
        local requiredResourceInfo = planState.requiredResources[1]
        if resource:groupOrResourceMatchesResource(requiredResourceInfo.group or requiredResourceInfo.type, gameObject.types[objectTypeIndex].resourceTypeIndex) then
            
            local medicineBlockList = nil
            local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
            if resourceBlockLists then
                medicineBlockList = resourceBlockLists.medicineList
            end

            if medicineBlockList and medicineBlockList[objectTypeIndex] then
                return nil
            end
            return {}
        end

        return nil
    end

    --local allowRequiredResources = true
    local allowRequiredTools = true

    
    local constructableTypeIndex = planState.constructableTypeIndex
    if constructableTypeIndex then
        local constructableType = constructable.types[constructableTypeIndex]

        serverGOM:updateBuildSequenceIndex(planObject, nil, planState.planTypeIndex, constructableType, planState) --could pass through sapien into this function most (but not all) of the time if needed
        local currentBuildSequenceIndex = planObject.sharedState.buildSequenceIndex
        --mj:log("currentBuildSequenceIndex:", currentBuildSequenceIndex)
       -- mj:log("planObject.sharedState:", planObject.sharedState)
        
        --local currentBuildSequenceIndex = serverSapienAI:getCurrentBuildSequenceIndex(planObject, planState)
        if currentBuildSequenceIndex then
            if planState.planTypeIndex ~= plan.types.deconstruct.index and planState.planTypeIndex ~= plan.types.rebuild.index then
                local currentBuildSequenceInfo = constructableType.buildSequence[currentBuildSequenceIndex]
               --[[ if currentBuildSequenceInfo.constructableSequenceTypeIndex ~= constructable.sequenceTypes.bringResources.index and 
                currentBuildSequenceInfo.constructableSequenceTypeIndex ~= constructable.sequenceTypes.bringTools.index then
                    allowRequiredResources = false
                end]]
                if not currentBuildSequenceInfo then
                    return false
                end

                if currentBuildSequenceInfo.constructableSequenceTypeIndex ~= constructable.sequenceTypes.bringTools.index then
                    allowRequiredTools = false
                end
            end
        end
    end

    local requiredResources = planState.requiredResources
    if requiredResources and requiredResources[1] then
        if not serverGOM:objectTypeIndexIsRestrictedForPlan(planObject, planState, objectTypeIndex, false) then
            for i,resourceInfo in ipairs(requiredResources) do
                if resourceInfo.count > 0 then
                    if resourceInfo.objectTypeIndex then
                        if resourceInfo.objectTypeIndex == objectTypeIndex then
                            return objectInventory.locations.availableResource.index
                        end
                    else
                        local resourceTypeIndex = gameObject.types[objectTypeIndex].resourceTypeIndex
                        if resource:groupOrResourceMatchesResource(resourceInfo.type or resourceInfo.group, resourceTypeIndex) then
                            return objectInventory.locations.availableResource.index
                        end
                    end
                end
            end
        end
    elseif allowRequiredTools then
        if not serverGOM:objectTypeIndexIsRestrictedForPlan(planObject, planState, objectTypeIndex, true) then
            local requiredTools = planState.requiredTools
            if requiredTools then
                for j, toolTypeIndex in ipairs(requiredTools) do
                    local gameObjectTypes = gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex]
                    for k,toolObjectTypeIndex in ipairs(gameObjectTypes) do
                        if toolObjectTypeIndex == objectTypeIndex then
                            return objectInventory.locations.tool.index
                        end
                    end
                end
            end
        end
    end

    return nil
end

function serverGOM:objectTypeIndexIsRequiredForPlanObject(buildObjectOrCraftArea, objectTypeIndex, planState, tribeID)
    return (serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(buildObjectOrCraftArea, objectTypeIndex, planState, tribeID) ~= nil)
end

function serverGOM:objectTypeIndexIsRequiredForMaintenanceObject(maintenanceObject, objectTypeIndex, tribeID)
    if serverFuel:objectRequiresFuelOfType(maintenanceObject, objectTypeIndex, tribeID) then
        return true
    end
    
    if serverCompostBin:compostBinRequiresObjectOfType(maintenanceObject, objectTypeIndex, tribeID) then
        return true
    end

    return false
end

function serverGOM:resourcesAreRequiredToStartBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)

    local requiredResources = planState.requiredResources
    if requiredResources then
        for i,resourceInfo in ipairs(requiredResources) do
            if resourceInfo.count > 0 then
                return true
            end
        end
    end

    return false

end

function serverGOM:resourcesAreRequiredForMultipleItemsForBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)
    --local planState = getPlanSateForConstructionObject(buildObjectOrCraftArea, planStateOrNil, tribeID)

    local requiredResources = planState.requiredResources
    if requiredResources then
        for i,resourceInfo in ipairs(requiredResources) do
            if resourceInfo.count > 0 then
                return true
            end
        end
    end

    return false
end

function serverGOM:nextItemInfoToBeRemovedForBuildObjectOrCraftArea(buildObjectOrCraftArea, allRequiredTools, allRequiredResources)
    --local planState = getPlanSateForBuildOrCraftObject(buildObjectOrCraftArea, planStateOrNil)


    local inventories = buildObjectOrCraftArea.sharedState.inventories

    if not inventories then
        return nil
    end

    local function checkInventory(location)
        if inventories[location] then
        
            local inventoryObjects = inventories[location].objects
    
            if allRequiredResources and allRequiredResources[1] then
                local inventoryObjectTypeIndicesRemaining = {}
                for i, objectInfo in ipairs(inventoryObjects) do
                    inventoryObjectTypeIndicesRemaining[i] = objectInfo.objectTypeIndex --todo could just use a hash of object types instead of an array
                end
    
                for i,requiredResourceInfo in ipairs(allRequiredResources) do
                    for k=#inventoryObjectTypeIndicesRemaining,1,-1 do
                        local inventoryObjectTypeIndex = inventoryObjectTypeIndicesRemaining[k]
                        if requiredResourceInfo.objectTypeIndex then
                            if requiredResourceInfo.objectTypeIndex == inventoryObjectTypeIndex then
                                table.remove(inventoryObjectTypeIndicesRemaining, k)
                            end
                        else
                            if resource:groupOrResourceMatchesResource(requiredResourceInfo.type or requiredResourceInfo.group, gameObject.types[inventoryObjectTypeIndex].resourceTypeIndex) then
                                table.remove(inventoryObjectTypeIndicesRemaining, k)
                            end
                        end
                    end
                end
    
                if inventoryObjectTypeIndicesRemaining[1] then
                    return {
                        location = location,
                        objectTypeIndex = inventoryObjectTypeIndicesRemaining[#inventoryObjectTypeIndicesRemaining],
                    }
                end
            else
                if inventoryObjects and inventoryObjects[1] then
                    return {
                        location = location,
                        objectTypeIndex = inventoryObjects[#inventoryObjects].objectTypeIndex,
                    }
                end
            end
        end
    end
    
    local result = checkInventory(objectInventory.locations.availableResource.index)
    if result then
        return result
    end
    result = checkInventory(objectInventory.locations.inUseResource.index)
    if result then
        return result
    end
    
    
    if inventories[objectInventory.locations.tool.index] then
        
        local inventoryObjects = inventories[objectInventory.locations.tool.index].objects

        if allRequiredTools and allRequiredTools[1] then
            local inventoryObjectTypeIndicesRemaining = {}
            for i, objectInfo in ipairs(inventoryObjects) do
                inventoryObjectTypeIndicesRemaining[i] = objectInfo.objectTypeIndex
            end

            for i,requiredToolIndex in ipairs(allRequiredTools) do
                
                local matchIndex = nil
                for j,inventoryObjectTypeIndex in ipairs(inventoryObjectTypeIndicesRemaining) do
                    for k,suitableObjectTypeIndex in ipairs(gameObject.gameObjectTypeIndexesByToolTypeIndex[requiredToolIndex]) do
                        if suitableObjectTypeIndex == inventoryObjectTypeIndex then
                            matchIndex = j
                            break
                        end
                    end
                    if matchIndex then
                        break
                    end
                end
                if matchIndex then
                    table.remove(inventoryObjectTypeIndicesRemaining, matchIndex)
                end
                if #inventoryObjectTypeIndicesRemaining == 0 then
                    break
                end
            end

            if inventoryObjectTypeIndicesRemaining[1] then
                return {
                    location = objectInventory.locations.tool.index,
                    objectTypeIndex = inventoryObjectTypeIndicesRemaining[#inventoryObjectTypeIndicesRemaining],
                }
            end
        else
            if inventoryObjects and inventoryObjects[1] then
                return {
                    location = objectInventory.locations.tool.index,
                    objectTypeIndex = inventoryObjects[#inventoryObjects].objectTypeIndex,
                }
            end
        end

    end

    
    return nil

end


function serverGOM:toolsAreRequiredToStartBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)
    local requiredTools = planState.requiredTools
    if requiredTools and requiredTools[1] then
        return true
    end

    return false
end

function serverGOM:anythingIsRequiredToStartBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)
    if serverGOM:resourcesAreRequiredToStartBuildObjectOrCraftArea(buildObjectOrCraftArea, planState) then
        return true
    end

    return serverGOM:toolsAreRequiredToStartBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)
end

function serverGOM:anythingIsRequiredForMultipleItemsForBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)
    if serverGOM:resourcesAreRequiredForMultipleItemsForBuildObjectOrCraftArea(buildObjectOrCraftArea, planState) then
        return true
    end

    return serverGOM:toolsAreRequiredToStartBuildObjectOrCraftArea(buildObjectOrCraftArea, planState)
end

function serverGOM:getOffsetForPlaceholderInObject(objectID, placeholderKey)
    return bridge:getOffsetForPlaceholderInObject(objectID, placeholderKey)
end

function serverGOM:getOffsetForPlaceholderInModel(modelIndex, rotation, scale, placeholderKey)
    return bridge:getOffsetForPlaceholderInModel(modelIndex, rotation, scale, placeholderKey)
end

function serverGOM:getPlaceholderRotationForModel(modelIndex, placeholderKey)
    return bridge:getPlaceholderRotationForModel(modelIndex, placeholderKey)
end

function serverGOM:getPlaceholderScaleForModel(modelIndex, placeholderKey)
    return bridge:getPlaceholderScaleForModel(modelIndex, placeholderKey)
end

function serverGOM:getLocalOffsetForPlaceholderInModel(modelIndex, placeholderKey)
    return bridge:getLocalOffsetForPlaceholderInModel(modelIndex, placeholderKey)
end


function serverGOM:getNextMoveInfoForBuildOrCraftObject(buildOrCraftObject, planState)    
    local constructableType = constructable.types[planState.constructableTypeIndex]
    
    --[[local modelName = constructableType.placeholderOverrideModelName
    if not modelName then
        modelName = constructableType.inProgressBuildModel
    end]]
    local modelName = constructableType.inProgressBuildModel
    if not modelName then
        modelName = constructableType.modelName
    end

    local function getModelInfo(resourceKey, resourceIndex)
        local modelIndex = model:modelIndexForModelNameAndDetailLevel(modelName, 1)
        local modelIndexForPlaceholders = modelIndex
        --[[if constructableType.placeholderOverrideModelName then
            modelIndexForPlaceholders = model:modelIndexForModelNameAndDetailLevel(constructableType.placeholderOverrideModelName, 1)
        end]]
        resourceKey = modelPlaceholder:resourceRemapForModelIndexAndResourceKey(modelIndexForPlaceholders, resourceKey) or resourceKey

        local storageKey = resourceKey .. "_store"
        local finalKey = resourceKey .. "_" .. mj:tostring(resourceIndex)
        if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, storageKey) then
            storageKey = "resource_store"
            finalKey = "resource_" .. mj:tostring(objectInventory:getTotalCount(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index) + 1)
        end

        if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, finalKey) then
            finalKey = resourceKey .. "_1" -- default to 1 eg. spliLog_1 has a hacky way to allow multiple copies of the same resource to be placed in the same spot 
        end

        if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, storageKey) then
            mj:error("No store key found in getNextMoveInfoForBuildOrCraftObject for model:", modelName, " resourceKey:", resourceKey)
            if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, finalKey) then
                mj:error("No final key found in getNextMoveInfoForBuildOrCraftObject for model:", modelName, " resourceKey:", resourceKey)
            end
            return nil
        end
        if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, finalKey) then
            mj:error("No final key found in getNextMoveInfoForBuildOrCraftObject for model:", modelName, " resourceKey:", resourceKey, " finalKey:", finalKey)
            return nil
        end

        return {
            storageKey= storageKey,
            finalKey = finalKey,
            modelIndexForPlaceholders = modelIndexForPlaceholders,
        }
    end
    
    local isDeconstructOrRebuild = (planState.planTypeIndex == plan.types.deconstruct.index or planState.planTypeIndex == plan.types.rebuild.index)

    if isDeconstructOrRebuild then
        for i=#constructableType.requiredResources,1,-1 do
            local resourceInfo = constructableType.requiredResources[i]
            local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group
            local resourceKey = resource:placheolderKeyForGroupOrResource(resourceTypeOrGroupIndex)
            local thisResourceMovedCount = objectInventory:getMatchCount(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index, nil, resourceTypeOrGroupIndex)
            if thisResourceMovedCount > 0 then
                local objectInfo = objectInventory:getNextMatch(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index, nil, resourceTypeOrGroupIndex)
                if objectInfo then
                    local resourceIndex = thisResourceMovedCount
                    
                    local modelInfo = getModelInfo(resourceKey, resourceIndex)
                    if not modelInfo then
                        return {
                            pickupPos = buildOrCraftObject.pos,
                            dropOffPos = buildOrCraftObject.pos,
                            resourceInfo = resourceInfo,
                        }
                    end
                    
                    return {
                        pickupPos = buildOrCraftObject.pos + serverGOM:getOffsetForPlaceholderInModel(modelInfo.modelIndexForPlaceholders, buildOrCraftObject.rotation, 1.0, modelInfo.finalKey),
                        pickupPlaceholderKey = modelInfo.finalKey,
                        dropOffPos = buildOrCraftObject.pos + serverGOM:getOffsetForPlaceholderInModel(modelInfo.modelIndexForPlaceholders, buildOrCraftObject.rotation, 1.0, modelInfo.storageKey),
                        dropOffPlaceholderKey = modelInfo.storageKey,
                        resourceInfo = resourceInfo,
                    }

                end
            end
        end
    else
        local alreadyMovedResourceCountsByKey = {}

        for i,resourceInfo in ipairs(constructableType.requiredResources) do
            local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group
            local resourceKey = resource:placheolderKeyForGroupOrResource(resourceTypeOrGroupIndex)

            local thisResourceMovedCount = objectInventory:getMatchCount(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index, nil, resourceTypeOrGroupIndex)

            local requiredRemainingCount = resourceInfo.count + (alreadyMovedResourceCountsByKey[resourceKey] or 0)
            if thisResourceMovedCount < requiredRemainingCount then
                local objectInfo = objectInventory:getNextMatch(buildOrCraftObject.sharedState, objectInventory.locations.availableResource.index, nil, resourceTypeOrGroupIndex)
                if objectInfo then
                    local resourceIndex = thisResourceMovedCount + 1
                    
                    local modelInfo = getModelInfo(resourceKey, resourceIndex)
                    if not modelInfo then
                        return {
                            pickupPos = buildOrCraftObject.pos,
                            dropOffPos = buildOrCraftObject.pos,
                            resourceInfo = resourceInfo,
                        }
                    end
                    
                    return {
                        pickupPos = buildOrCraftObject.pos + serverGOM:getOffsetForPlaceholderInModel(modelInfo.modelIndexForPlaceholders, buildOrCraftObject.rotation, 1.0, modelInfo.storageKey),
                        pickupPlaceholderKey = modelInfo.storageKey,
                        dropOffPos = buildOrCraftObject.pos + serverGOM:getOffsetForPlaceholderInModel(modelInfo.modelIndexForPlaceholders, buildOrCraftObject.rotation, 1.0, modelInfo.finalKey),
                        dropOffPlaceholderKey = modelInfo.finalKey,
                        resourceInfo = resourceInfo,
                    }
                end
            end

            if not alreadyMovedResourceCountsByKey[resourceKey] then
                alreadyMovedResourceCountsByKey[resourceKey] = resourceInfo.count
            else
                alreadyMovedResourceCountsByKey[resourceKey] = alreadyMovedResourceCountsByKey[resourceKey] + resourceInfo.count
            end
        end
    end
    return nil
end

function serverGOM:completeBuildMoveComponent(buildOrCraftObject, sapienOrNil, planState)
    local constructableType = constructable.types[planState.constructableTypeIndex]

    
    local isDeconstructOrRebuild = (planState.planTypeIndex == plan.types.deconstruct.index or planState.planTypeIndex == plan.types.rebuild.index)

    if isDeconstructOrRebuild then
        objectInventory:moveNextResourceFromInUseToAvailable(buildOrCraftObject.sharedState, constructableType.requiredResources)
    else
        objectInventory:moveNextResourceFromAvailableToInUse(buildOrCraftObject.sharedState, constructableType.requiredResources)
    end
    
    

   -- if not gameObject.types[buildOrCraftObject.objectTypeIndex].isCraftArea then
    serverGOM:checkIfNeedsToIncrementBuildSequenceDueToMoveComponentsComplete(buildOrCraftObject, sapienOrNil, planState)
    serverGOM:checkIfBuildOrCraftOrderIsComplete(buildOrCraftObject, sapienOrNil, planState)
    --end
end


function serverGOM:updatePlanDueToBuildOrCraftChange(buildObjectOrCraftArea, constructableType, planState)
    local buildObjectState = buildObjectOrCraftArea.sharedState

    local requiredItems = serverGOM:getRequiredItemsNotInInventory(buildObjectOrCraftArea, planState, constructableType.requiredTools, constructableType.requiredResources, constructableType.index)
    planManager:updateRequiredResourcesForPlan(planState.tribeID, planState, buildObjectOrCraftArea, requiredItems)

    if (not requiredItems) or ((not requiredItems.resources) and (not requiredItems.tools)) then
        --[[if planState.researchTypeIndex then --probably no longer necessary
            planManager:updateRequiredSkillForPlan(buildObjectState.tribeID, planState, buildObjectOrCraftArea, skill.types.researching.index)
        else
            if constructableType.skills and constructableType.skills.required then
                planManager:updateRequiredSkillForPlan(buildObjectState.tribeID, planState, buildObjectOrCraftArea, constructableType.skills.required)
            end
        end]]
        serverSapien:announce(buildObjectOrCraftArea.uniqueID, buildObjectState.tribeID)
    end
end

function serverGOM:addConstructionObjectComponent(buildObjectOrCraftArea, addObjectInfo, tribeID)

    local buildObjectState = buildObjectOrCraftArea.sharedState
    
    local planState = planManager:getPlanSateForConstructionObject(buildObjectOrCraftArea, tribeID)
    if not planState then
        mj:error("no plan state for construction object sharedState:", buildObjectState)
    end

    local objectTypeIndex = addObjectInfo.objectTypeIndex

    local constructableType = nil
    if planState.constructableTypeIndex then
        constructableType = constructable.types[planState.constructableTypeIndex]
    elseif buildObjectOrCraftArea.sharedState.inProgressConstructableTypeIndex then
        constructableType = constructable.types[buildObjectOrCraftArea.sharedState.inProgressConstructableTypeIndex]
    else
        mj:warn("attempt to addBuildObjectComponent to non-build object (probably already completed)")
        return false
    end
    --serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(buildObjectOrCraftArea, objectTypeIndex, planState, tribeID)
    local inventoryLocation = serverGOM:inventoryLocationifObjectTypeIndexIsRequiredForPlanObject(buildObjectOrCraftArea, objectTypeIndex, planState, tribeID) 
    --serverGOM:inventoryLocationForObjectTypeIndexForBuildObjectOrCraftArea(buildObjectOrCraftArea, objectTypeIndex, planState)
    
    if not inventoryLocation then
        mj:log("WARNING: attempting to addConstructionObjectComponent that isn't required to object:", buildObjectOrCraftArea.uniqueID)
        return false
    end

    
    local newCount = 1
    local addIndex = 1
    if buildObjectState.inventories and buildObjectState.inventories[inventoryLocation] then
        local currentInventory = buildObjectState.inventories[inventoryLocation]
        if currentInventory.countsByObjectType and currentInventory.countsByObjectType[objectTypeIndex] then
            newCount = currentInventory.countsByObjectType[objectTypeIndex] + 1
        end
        if currentInventory.objects then
            addIndex = #currentInventory.objects + 1
        end
    end

    buildObjectState:set("inventories", inventoryLocation, "countsByObjectType", objectTypeIndex, newCount)
    buildObjectState:set("inventories", inventoryLocation, "objects", addIndex, addObjectInfo)
    
    if planState then
        serverGOM:updatePlanDueToBuildOrCraftChange(buildObjectOrCraftArea, constructableType, planState)
    end

   -- local completeMoveNow = false
    
   --[[ if constructableType.modelName then --this is a hack, moved across when buildable turned to constructable. Should probably be sorted out
        if not constructableType.isPlantType and not constructableType.isFillType then
            local storagePlaceholderName = getNextStoragePlaceholderNameForBuildObject(buildObjectOrCraftArea, objectTypeIndex)
            local modelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.modelName, 1)
            if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndex, storagePlaceholderName) then
                completeMoveNow = true
            end
        end
    end]]

   -- if completeMoveNow then
        --serverGOM:completeBuildMoveComponent(buildObjectOrCraftArea, planState)
  --  end

   -- mj:log("serverGOM:addBuildObjectComponent : planState:", planState, " buildObjectState:", buildObjectState)

    --serverGOM:saveObject(buildObjectOrCraftArea.uniqueID)
    --serverResourceManager:updateResourcesForObject(buildObject)

    
    return true
end

function serverGOM:spawnObject(objectTypeIndexOrName, pos, rotation, tribeID)
    local createObjectType = gameObject.types[objectTypeIndexOrName]
    if createObjectType then
        if createObjectType.index == gameObject.types.sapien.index then
            serverTribe:createCheatSapien(tribeID, pos)
        elseif gameObject.types[createObjectType.index].mobTypeIndex then
            serverMob:createCheatMob(createObjectType.index, pos, rotation)
        else
            serverGOM:createOutput(pos, nil, createObjectType.index, nil, tribeID, nil, nil)
        end
    end

end

function serverGOM:createOutput(outputPos, 
    rotationOrNil,
    createObjectTypeIndex, 
    createObjectSharedState, 
    tribeID, 
    addCustomPlanTypeIndex, 
    addCustomPlanContextOrNil)
    --mj:error("createOutput:", createObjectTypeIndex)
    local up = normalize(outputPos)
    local randomDirection = normalize(up + cross(up, rng:vec()) * 0.25)
    local randomVel = randomDirection * 2.0

    local offset = randomDirection * mj:mToP(0.8)
    local basePos = outputPos + offset

    local gameObjectTypeIndex = createObjectTypeIndex

    local sharedState = createObjectSharedState or {}

    sharedState.tribeID = tribeID

    local gameObjectType = gameObject.types[gameObjectTypeIndex]


    --[[if tribeID then --should now be added in serverResourceManager
        if gameObjectType.resourceTypeIndex then
            serverWorld:addObjectTypeIndexToSeenResourceList(gameObjectTypeIndex, tribeID)
        end
    end]]

    --mj:log("in serverGOM:createOutput:", gameObjectTypeIndex)

    if type(rotationOrNil) == "number" then
        mj:warn("serverGOM:createOutput now requires a rotation matrix or nil for the second argument, but a number has been passed. This will crash in the future.") --warning for mods
        rotationOrNil = nil
    end

    local rotationToUse = rotationOrNil or rng:randomRotation()

    if gameObjectType then
        local outputObjectID = serverGOM:createGameObject(
            {
                objectTypeIndex = gameObjectTypeIndex,
                addLevel = mj.SUBDIVISIONS - 2,
                pos = basePos,
                rotation = rotationToUse,
                velocity = randomVel,
                scale = gameObjectType.scale,
                renderType = RENDER_TYPE_DYNAMIC,
                hasPhysics = gameObjectType.hasPhysics,
                dynamicPhysics = true,
                sharedState = sharedState,
            }
        )
        if addCustomPlanTypeIndex and tribeID then
            if outputObjectID then
                if addCustomPlanTypeIndex == plan.types.research.index then
                    local addCustomPlanContext = addCustomPlanContextOrNil or {}
                    planManager:addResearchPlan(sharedState.tribeID, 
                    addCustomPlanTypeIndex, 
                    outputObjectID, 
                    {outputObjectID},
                    addCustomPlanContext.objectTypeIndex, 
                    addCustomPlanContext.researchTypeIndex, 
                    addCustomPlanContext.discoveryCraftableTypeIndex, 
                    addCustomPlanContext.planOrderIndex, 
                    addCustomPlanContext.planPriorityOffset, 
                    addCustomPlanContext.manuallyPrioritized)
                else
                    local planAdditionSupressed = (addCustomPlanContextOrNil and addCustomPlanContextOrNil.supressStoreOrders and addCustomPlanTypeIndex == plan.types.storeObject.index)
                    if not planAdditionSupressed then
                        local planOrderIndex = nil
                        local planPriorityOffset = nil
                        local manuallyPrioritized = nil
                        if addCustomPlanContextOrNil then
                            planOrderIndex = addCustomPlanContextOrNil.planOrderIndex
                            planPriorityOffset = addCustomPlanContextOrNil.planPriorityOffset
                            manuallyPrioritized = addCustomPlanContextOrNil.manuallyPrioritized
                        end
                        planManager:addStandardPlan(sharedState.tribeID, addCustomPlanTypeIndex, outputObjectID, nil, nil, nil, nil, planOrderIndex, planPriorityOffset, manuallyPrioritized)
                    end
                end

            end
        end
        return outputObjectID
    else
        mj:error("serverGOM:createOutput bad object type index:", gameObjectTypeIndex)
    end
    return nil
end

function serverGOM:removeGameObjectAndDropInventory(objectID, tribeID, addStoreOrders, storeOrderPrioritySapienOrNil, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil)
    local object = serverGOM:getObjectWithID(objectID)
    local dropPos = object.pos
    local objects = serverGOM:getSharedState(object, false, "inventory", "objects")
    local addPlanTypeIndex = nil
    if addStoreOrders then
        addPlanTypeIndex = plan.types.storeObject.index
    end
    
    serverGOM:removeGameObject(objectID)
    object = nil
    local lastOutputID = nil
    if objects then
        for i, objectInfo in ipairs(objects) do
            lastOutputID = serverGOM:createOutput(dropPos, nil, objectInfo.objectTypeIndex, nil, tribeID, addPlanTypeIndex, {
                planOrderIndex = planOrderIndexOrNil,
                planPriorityOffset = planPriorityOffsetOrNil,
                manuallyPrioritized = manuallyPrioritizedOrNil,
            })
        end
    end

    if lastOutputID and storeOrderPrioritySapienOrNil then
        local lastOutputObject = serverGOM:getObjectWithID(lastOutputID)
        if lastOutputObject then
            serverSapien:setLookAt(storeOrderPrioritySapienOrNil, lastOutputID, lastOutputObject.pos)
        end
    end
end

function serverGOM:removeFromHarvestingObject(object, sapien, tribeID, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil, harvestableTypeIndex)
    local harvestableType = harvestable.types[harvestableTypeIndex]
    local harvestIndex = (object.sharedState.harvestIndex or 0) + 1
    local completionHarvestCount = #harvestableType.objectTypesArray
    local dropPos = sapien.pos
    local lastOutputID = nil

    local function createOutput(index)
        local objectTypeIndex = harvestableType.objectTypesArray[index]
        lastOutputID = serverGOM:createOutput(dropPos, nil, objectTypeIndex, nil, tribeID, plan.types.storeObject.index, {
            planOrderIndex = planOrderIndexOrNil,
            planPriorityOffset = planPriorityOffsetOrNil,
            manuallyPrioritized = manuallyPrioritizedOrNil,
        })
    end

    if harvestIndex > completionHarvestCount or harvestIndex >= harvestableType.completionIndex then
        serverGOM:removeGameObject(object.uniqueID)
        object = nil
        for i=harvestIndex,completionHarvestCount do
            createOutput(i)
        end
    else
        object.sharedState:set("harvestIndex", harvestIndex)
        createOutput(harvestIndex)
    end
    
    if lastOutputID then
        local lastOutputObject = serverGOM:getObjectWithID(lastOutputID)
        if lastOutputObject then
            serverSapien:setLookAt(sapien, lastOutputID, lastOutputObject.pos)
        end
    end
end

function serverGOM:removeTemporaryGameObjectForOrderCompleteIfNeeded(orderObject)
    if orderObject then
        if orderObject.privateState and orderObject.privateState.removeWhenOrderComplete then
            --mj:debug("serverGOM:removeTemporaryGameObjectForOrderCompleteIfNeeded:", orderObject.sharedState)
            serverGOM:removeGameObject(orderObject.uniqueID)
        end
    end
end

function serverGOM:decreaseSoilFertilityForObjectHarvest(object, fertilityOffset)
    --mj:log("serverGOM:decreaseSoilFertilityForObjectHarvest:",object)
    local vertID = terrain:getClosestVertIDToPos(object.normalizedPos)
    --mj:log("vertID:", vertID, " fertilityOffset:", fertilityOffset)
    terrain:partiallyDegradeSoilFertilityForVertex(vertID, fertilityOffset)
   -- mj:log("ok")
end

function serverGOM:dropInventory(object, tribeID, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil)
   --mj:log("dropInventory")
   -- mj:log(debug.traceback())
    local dropPos = object.pos
    local resources = serverGOM:getSharedState(object, false, "inventories", objectInventory.locations.availableResource.index, "objects")
    local inUseResources = serverGOM:getSharedState(object, false, "inventories", objectInventory.locations.inUseResource.index, "objects")
    local tools = serverGOM:getSharedState(object, false, "inventories", objectInventory.locations.tool.index, "objects")
    if resources then
        for i, objectInfo in ipairs(resources) do
            serverGOM:createOutput(dropPos, nil, objectInfo.objectTypeIndex, nil, tribeID, plan.types.storeObject.index, {
                planOrderIndex = planOrderIndexOrNil,
                planPriorityOffset = planPriorityOffsetOrNil,
                manuallyPrioritized = manuallyPrioritizedOrNil,
            })
        end
    end
    if inUseResources then
        for i, objectInfo in ipairs(inUseResources) do
            serverGOM:createOutput(dropPos, nil, objectInfo.objectTypeIndex, nil, tribeID, plan.types.storeObject.index, {
                planOrderIndex = planOrderIndexOrNil,
                planPriorityOffset = planPriorityOffsetOrNil,
                manuallyPrioritized = manuallyPrioritizedOrNil,
            })
        end
    end

    if tools then
        for i, objectInfo in ipairs(tools) do
            serverGOM:createOutput(dropPos, nil, objectInfo.objectTypeIndex, {
                fractionDegraded = objectInfo.fractionDegraded, 
                constructionObjects = objectInfo.constructionObjects
            }, tribeID, plan.types.storeObject.index, {
                planOrderIndex = planOrderIndexOrNil,
                planPriorityOffset = planPriorityOffsetOrNil,
                manuallyPrioritized = manuallyPrioritizedOrNil,
            })
        end
    end
    object.sharedState:remove("inventories")
end

function serverGOM:removeIfTemporaryCraftAreaAndDropInventoryIfNeeded(object, tribeID, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil)
    if (object.privateState and object.privateState.removeWhenOrderComplete) then
        serverGOM:dropInventory(object, tribeID, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil)
        serverGOM:removeGameObject(object.uniqueID)
        return true
    end
    return false
end


local function updateVertsForObjectRemoval(object)
    if object.sharedState and object.sharedState.preventGrassAndSnowVertIDs then
        for i,vertID in ipairs(object.sharedState.preventGrassAndSnowVertIDs) do
            terrain:addToPreventGrassAndSnowCountForVert(vertID, -1, object.normalizedPos)
        end
        object.sharedState:remove("preventGrassAndSnowVertIDs")
    end
end

local function updateVertsForObjectIfNeeded(object, removeAnyGrassAndSnow)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if gameObjectType.preventGrassAndSnow then
        local minAltitude = -1.0
        local verts = physics:getVertsAffectedByBuildModel(object.pos, object.rotation, object.scale, gameObjectType.modelIndex, minAltitude)
        
        local vertsToAdd = {}
        local vertsToRemove = {}
        local newVertIDs = {}

        for i,vert in ipairs(verts) do
            vertsToAdd[vert.uniqueID] = true
            table.insert(newVertIDs, vert.uniqueID)
        end
        
        if object.sharedState.preventGrassAndSnowVertIDs then
            for i,vertID in ipairs(object.sharedState.preventGrassAndSnowVertIDs) do
                if not vertsToAdd[vertID] then
                    vertsToRemove[vertID] = true
                else
                    vertsToAdd[vertID] = nil
                end
            end
        end

        for vertID,v in pairs(vertsToAdd) do
            terrain:addToPreventGrassAndSnowCountForVert(vertID, 1, object.normalizedPos)
        end

        for vertID,v in pairs(vertsToRemove) do
            terrain:addToPreventGrassAndSnowCountForVert(vertID, -1, object.normalizedPos)
        end

        
        if removeAnyGrassAndSnow then
            for i,vert in ipairs(verts) do
                terrain:removeSnowForVertex(vert.uniqueID)
                terrain:removeVegetationForVertex(vert.uniqueID)
            end
        end

        if newVertIDs[1] then
            object.sharedState:set("preventGrassAndSnowVertIDs", newVertIDs)
        else
            object.sharedState:remove("preventGrassAndSnowVertIDs")
        end
    elseif object.sharedState.preventGrassAndSnowVertIDs then
        for i,vertID in ipairs(object.sharedState.preventGrassAndSnowVertIDs) do
            terrain:addToPreventGrassAndSnowCountForVert(vertID, -1, object.normalizedPos)
        end
        object.sharedState:remove("preventGrassAndSnowVertIDs")
    end
end

local function createFinalObjectForBuildObjectCompletion(orderObject, constructableType)

    
    local orderObjectSharedState = orderObject.sharedState
    planManager:removeAllPlanStatesForObject(orderObject, orderObjectSharedState, nil)

    --mj:log("createFinalObjectForBuildObjectCompletion orderObjectSharedState:", orderObjectSharedState)
    
    local newSharedState = {
        tribeID = orderObjectSharedState.tribeID,
        name = orderObjectSharedState.name,
        subModelInfos = orderObjectSharedState.subModelInfos,
        constructionConstructableTypeIndex = orderObjectSharedState.inProgressConstructableTypeIndex,
        restrictedResourceObjectTypes = orderObjectSharedState.restrictedResourceObjectTypes,
        preventGrassAndSnowVertIDs = orderObjectSharedState.preventGrassAndSnowVertIDs,
    }

    --mj:log("orderObjectSharedState:", orderObjectSharedState)

    local newConstructionObjects = nil

    local inventories = orderObjectSharedState.inventories
    if inventories and not constructableType.isPlaceType then
        local function addConstructionObjects(inventory)
            if inventory and inventory.objects and inventory.objects[1] then
                if not newConstructionObjects then
                    newConstructionObjects = {}
                end
                --mj:log("inventory:", inventory)
                for i, object in ipairs(inventory.objects) do
                    local objectInfo = serverGOM:getSharedStateForRemovalFromInventory(object)
                    objectInfo.objectTypeIndex = object.objectTypeIndex
                    objectInfo.orderContext = nil
                    table.insert(newConstructionObjects, objectInfo)
                end
            end
        end

        addConstructionObjects(inventories[objectInventory.locations.availableResource.index])--hmm, changed this from inUseResource to fix bug where inventory wasnt used, inUse/available distinction isnt clear
        addConstructionObjects(inventories[objectInventory.locations.inUseResource.index])--bugger it, I'll just do both
    end

    newSharedState.constructionObjects = newConstructionObjects

    --[[if constructableType.finalGameObjectTypeFunction then
        newTypeIndex = constructableType.finalGameObjectTypeFunction(newSharedState.constructionObjects)
    end]]


    local newTypeIndex = orderObject.objectTypeIndex
    if constructableType.finalGameObjectTypeKey then
        newTypeIndex = gameObject.types[constructableType.finalGameObjectTypeKey].index
    end


    if constructableType.isPlaceType then

        if inventories then
            local function findFirstInventoryItem(inventory)
                if inventory and inventory.objects and inventory.objects[1] then
                    return inventory.objects[1]
                end
            end
            local addedObjectInfo = findFirstInventoryItem(inventories[objectInventory.locations.availableResource.index])
            if not addedObjectInfo then
                addedObjectInfo = findFirstInventoryItem(inventories[objectInventory.locations.inUseResource.index])
            end

           -- mj:log("addedObjectInfo:", addedObjectInfo)

            local newTypeKey = "placed_" .. gameObject.types[addedObjectInfo.objectTypeIndex].key
            newTypeIndex = gameObject.types[newTypeKey].index

            newSharedState.degradeReferenceTime = addedObjectInfo.degradeReferenceTime
            newSharedState.fractionDegraded = addedObjectInfo.fractionDegraded
            newSharedState.constructionConstructableTypeIndex = addedObjectInfo.constructionConstructableTypeIndex
            newSharedState.constructionObjects = addedObjectInfo.constructionObjects

            if (not newSharedState.name) and addedObjectInfo.name then --if we have renamed the placeholder, use that, otherwise use the item that is being placed's name
                newSharedState.name = addedObjectInfo.name
            end

            --mj:log("newSharedState:", newSharedState)
        end
    end

    --mj:log("setting to final type index:", newTypeIndex)
    

    local keysToRemove = {}
    for k,v in pairs(orderObject.sharedState) do
        table.insert(keysToRemove, k)
    end

    for i,k in ipairs(keysToRemove) do
        orderObject.sharedState:remove(k)
    end

    for k,v in pairs(newSharedState) do
        orderObject.sharedState:set(k,v)
    end


    gameObjectSharedState:setupState(orderObject, orderObject.sharedState)
    
    local prevObjectTypeIndex = orderObject.objectTypeIndex
    if newTypeIndex ~= prevObjectTypeIndex then
        local keepDegradeInfo = constructableType.isPlaceType
        serverGOM:changeObjectType(orderObject.uniqueID, newTypeIndex, keepDegradeInfo)
    end

    serverGOM:updateNearByObjectObservers(orderObject.uniqueID, newTypeIndex, prevObjectTypeIndex)


    updateVertsForObjectIfNeeded(orderObject, true)

    if orderObject.privateState and orderObject.privateState.decalBlockers then
        orderObject.sharedState:set("decalBlockers", orderObject.privateState.decalBlockers)
        orderObject.privateState.decalBlockers = nil
    end

    --tutorial hooks
    if constructableType.index == constructable.types.hayBed.index or
    constructableType.index == constructable.types.woolskinBed.index then
        local tribeID = newSharedState.tribeID
        if not serverTutorialState:builtBedsIsComplete(tribeID) then
            local totalCount = 0
            local beds = serverGOM:getAllGameObjectsInSet(serverGOM.objectSets.beds)
            local function checkOwnership(objectID)
                local object = serverGOM:getObjectWithID(objectID)
                if object and object.sharedState and object.sharedState.tribeID == tribeID then
                    totalCount = totalCount + 1
                end
            end
            for i,objectID in ipairs(beds) do
                checkOwnership(objectID)
            end
            serverTutorialState:setTotalBuiltBedCount(tribeID, totalCount)
        end
    elseif constructableType.index == constructable.types.craftArea.index then
        local tribeID = newSharedState.tribeID
        if not serverTutorialState:builtCraftAreasIsComplete(tribeID) then
            local totalCount = 0
            local craftAreas = serverGOM:getAllGameObjectsInSet(serverGOM.objectSets.craftAreas) --includes campfires and temporary craftAreas
            local function checkOwnership(objectID)
                local object = serverGOM:getObjectWithID(objectID)
                if object and object.objectTypeIndex == gameObject.types.craftArea.index and object.sharedState and object.sharedState.tribeID == tribeID then
                    totalCount = totalCount + 1
                end
            end
            for i,objectID in ipairs(craftAreas) do
                checkOwnership(objectID)
            end
            serverTutorialState:setTotalBuiltCraftAreaCount(tribeID, totalCount)
        end
    elseif constructableType.countsAsThatchRoofForTutorial then
        serverTutorialState:setBuildThatchHutComplete(newSharedState.tribeID)
    elseif constructableType.countsAsSplitLogWallForTutorial then
        serverTutorialState:setBuiltSplitLogWallComplete(newSharedState.tribeID)
    elseif constructableType.classification == constructable.classifications.path.index then
        serverTutorialState:pathWasBuilt(newSharedState.tribeID)
    elseif constructableType.classification == constructable.classifications.plant.index then
        if flora:isFoodCrop(orderObject) then
            serverTutorialState:foodCropWasPlanted(newSharedState.tribeID)
        end
    end

end

function serverGOM:resetBuildSequence(object)
    --mj:error("serverGOM:resetBuildSequence:", object.uniqueID, " sharedState:", object.sharedState)
    object.sharedState:remove("buildSequenceIndex")
end


local function completeBuildOrder(buildOrCraftObject, constructableType, planStateOrNil, tribeID)
    --mj:log("completeBuildOrder:", buildOrCraftObject.uniqueID)
    --mj:error("completeBuildOrder:", buildOrCraftObject.uniqueID, " sharedState:", buildOrCraftObject.sharedState)

    local planOrderIndex = nil
    local planPriorityOffset = nil
    local manuallyPrioritized = nil
    if planStateOrNil then
        planOrderIndex = planStateOrNil.planOrderIndex or planStateOrNil.planID
        planPriorityOffset = planStateOrNil.priorityOffset
        manuallyPrioritized = planStateOrNil.manuallyPrioritized
    end

    serverGOM:ejectTools(buildOrCraftObject, tribeID, planOrderIndex, planPriorityOffset, manuallyPrioritized)
    local vertID = buildOrCraftObject.sharedState.vertID

    if not vertID then
        createFinalObjectForBuildObjectCompletion(buildOrCraftObject, constructableType)
    else
        if planStateOrNil.planTypeIndex == plan.types.fill.index then
            local inventories = buildOrCraftObject.sharedState.inventories
            if inventories then
                local objectTypeCounts = {}
                local function findFillTypes(inventory)
                    if inventory and inventory.objects and inventory.objects[1] then
                        for i, object in ipairs(inventory.objects) do
                            local objectTypeIndex = inventory.objects[1].objectTypeIndex
                            if not objectTypeCounts[objectTypeIndex] then
                                objectTypeCounts[objectTypeIndex] = 1
                            else
                                objectTypeCounts[objectTypeIndex] = objectTypeCounts[objectTypeIndex] + 1
                            end
                        end
                    end
                end

                findFillTypes(inventories[objectInventory.locations.availableResource.index])--hmm, changed this from inUseResource to fix bug where inventory wasnt used, inUse/available distinction isnt clear
                findFillTypes(inventories[objectInventory.locations.inUseResource.index])--bugger it, I'll just do both
                
                terrain:fillVertex(vertID, objectTypeCounts, tribeID)
            end
        elseif planStateOrNil.planTypeIndex == plan.types.fertilize.index or planStateOrNil.researchTypeIndex == research.types.mulching.index then
            terrain:changeSoilQualityForVertex(vertID, 1)
        end
    end

    buildOrCraftObject.sharedState:remove("inventories")
    buildOrCraftObject.sharedState:remove("inProgressConstructableTypeIndex")
    buildOrCraftObject.sharedState:remove("buildSequenceIndex")
    buildOrCraftObject.sharedState:remove("buildSequenceRepeatCounters")
        
    if planStateOrNil then
        if vertID then
            planManager:removePlanStateFromTerrainVertForTerrainModification(buildOrCraftObject.sharedState.vertID, planStateOrNil.planTypeIndex, planStateOrNil.tribeID, planStateOrNil.researchTypeIndex)
        elseif not constructableType.finalGameObjectTypeKey then
            planManager:removePlanStateForObject(buildOrCraftObject, planStateOrNil.planTypeIndex, planStateOrNil.objectTypeIndex, planStateOrNil.researchTypeIndex, planStateOrNil.tribeID, nil) --untested
        end

        if constructableType.buildCompletionPlanIndex then
            planManager:addStandardPlan(tribeID, constructableType.buildCompletionPlanIndex, buildOrCraftObject.uniqueID, nil, nil, nil, nil, planStateOrNil.planOrderIndex or planStateOrNil.planID, planStateOrNil.priorityOffset, planStateOrNil.manuallyPrioritized)
        end
    end
end

function serverGOM:completeBuildImmediately(buildOrCraftObject, constructableType, planStateOrNil, tribeID)
    --mj:log("buildOrCraftObject.sharedState:", buildOrCraftObject.sharedState)
    
    local requiredResources = constructableType.requiredResources

    if requiredResources then
        local inUseInventory = {
            objects = {},
            countsByObjectType = {},
        }

        local function addObject(objectTypeIndex)
            
            if not inUseInventory.countsByObjectType[objectTypeIndex] then
                inUseInventory.countsByObjectType[objectTypeIndex] = 0
            end
            inUseInventory.countsByObjectType[objectTypeIndex] = inUseInventory.countsByObjectType[objectTypeIndex] + 1

            table.insert(inUseInventory.objects, {
                objectTypeIndex = objectTypeIndex,
            })
        end

        local whiteListTypes = serverWorld:seenResourceObjectTypesForTribe(tribeID)

        for i, resourceInfo in ipairs(requiredResources) do
            local requiredCount = resourceInfo.count

            local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, buildOrCraftObject.sharedState.restrictedResourceObjectTypes, whiteListTypes)
            --mj:log("availableObjectTypeIndexes:", availableObjectTypeIndexes, " whiteListTypes:", whiteListTypes)
            if availableObjectTypeIndexes and availableObjectTypeIndexes[1] then
                for j=1,requiredCount do
                    addObject(availableObjectTypeIndexes[1])
                end
            else
                local objectTypeIndex = nil
                if resourceInfo.type then
                    objectTypeIndex = resource.types[resourceInfo.type].displayGameObjectTypeIndex
                else
                    objectTypeIndex = resource.groups[resourceInfo.group].displayGameObjectTypeIndex
                end

                for j=1,requiredCount do
                    addObject(objectTypeIndex)
                end
            end
        end
        
        local newInventories = {
            [objectInventory.locations.inUseResource.index] = inUseInventory
        }
        buildOrCraftObject.sharedState:set("inventories", newInventories)
    end
        
    completeBuildOrder(buildOrCraftObject, constructableType, planStateOrNil, tribeID)
end

function serverGOM:planWasCancelledForObject(object, planTypeIndex, tribeID)
    if planTypeIndex == plan.types.haulObject.index then
        --mj:log("planWasCancelledForObject:", object.sharedState)
        if object.sharedState.haulingSapienID then
            --mj:log("object.sharedState.haulingSapienID:", object.sharedState.haulingSapienID)
            local sapien = serverGOM:getObjectWithID(object.sharedState.haulingSapienID)
            if sapien then
                if sapien.sharedState.haulingObjectID == object.uniqueID then
                    serverSapien:cancelAllOrders(sapien, false, false)
                end
            end
        end
    end

    if planTypeIndex == plan.types.research.index and gameObject.types[object.objectTypeIndex].isInProgressBuildObject then
        mj:debug("removing object due to research plan cancel. object sharedState:", object.sharedState)
        serverGOM:dropInventory(object, tribeID, nil, nil, nil)
        serverGOM:removeGameObject(object.uniqueID)
    elseif planTypeIndex == plan.types.deconstruct.index or planTypeIndex == plan.types.rebuild.index then
        local constructableType = constructable.types[object.sharedState.inProgressConstructableTypeIndex]
        if constructableType then
            if constructableType.requiredResourceTotalCount and constructableType.requiredResourceTotalCount > 0 then
                local totalMovedCount = objectInventory:getTotalCount(object.sharedState, objectInventory.locations.inUseResource.index)
                local done = (totalMovedCount >= constructableType.requiredResourceTotalCount)
                if done then
                    completeBuildOrder(object, constructableType, nil, tribeID)
                end
            end
        end
    elseif gameObject.types[object.objectTypeIndex].isCraftArea then
        serverCraftArea:planWasCancelledForCraftObject(object, planTypeIndex, tribeID)
        serverGOM:removeIfTemporaryCraftAreaAndDropInventoryIfNeeded(object, tribeID, nil, nil, nil) --WARNING! object may be removed
    elseif planTypeIndex == plan.types.fill.index or planTypeIndex == plan.types.fertilize.index or (planTypeIndex == plan.types.research.index and object.sharedState.inProgressConstructableTypeIndex) then
        serverGOM:dropInventory(object, tribeID, nil, nil, nil)
        object.sharedState:remove("inProgressConstructableTypeIndex")
        serverGOM:removeTemporaryGameObjectForOrderCompleteIfNeeded(object)
    else
        serverGOM:removeTemporaryGameObjectForOrderCompleteIfNeeded(object)
    end
     --WARNING! object may have been removed above
end

function serverGOM:removeGameObject(objectID)
    --mj:log("removeGameObject:", objectID)
    --mj:log(debug.traceback())
    --[[local object = serverGOM:getObjectWithID(objectID)
    if object then
        serverResourceManager:removeAnyResourceForObject(object)
    end]]
    local object = serverGOM:getObjectWithID(objectID)
    if object then
        updateVertsForObjectRemoval(object)
        
        if gameObject.types[object.objectTypeIndex].seatTypeIndex then
            serverSeat:removeSeatNodes(object)
        end

        if gameObject.types[object.objectTypeIndex].isStorageArea then
            serverLogistics:updateRoutesForStorageAreaRemoval(object.uniqueID)
        end
    end
	bridge:removeGameObject(objectID)
end


function serverGOM:doCoveredTestForObject(object)
    if gameObject.types[object.objectTypeIndex].alwaysTreatAsCoveredInside then
        return true
    end

    local rayDirection = object.normalizedPos
    local rayStart = object.pos + rayDirection * serverGOM.coveredTestRayStartOffsetLength
    local rayEnd = rayStart + rayDirection * serverGOM.coveredTestRayLength

    local rayResult = physics:rayTest(rayStart, rayEnd, physicsSets.blocksRain, object.uniqueID)
    if rayResult and rayResult.hasHitObject then
        return true
    end

    return false
end

local queuedUpdateCoveredStatusObjects = {}


local function doTestAndUpdateCoveredStatus(object)
    --mj:log("do covered test:", object.uniqueID)
    --disabled--mj:objectLog(object.uniqueID, "doCoveredTest")
    local coveredStatusChanged = false

    local newCovered = serverGOM:doCoveredTestForObject(object)
    if newCovered then
        --disabled--mj:objectLog(object.uniqueID, "covered test found cover")
        if not object.sharedState.covered then
            object.sharedState:set("covered", true)
            coveredStatusChanged = true
        end
    else
        --disabled--mj:objectLog(object.uniqueID, "covered test no cover found")
        if object.sharedState.covered then
            object.sharedState:remove("covered")
            coveredStatusChanged = true
        end
    end

    if coveredStatusChanged then
        local objectCoveredStatusChangedFunctions = objectCoveredStatusChangedFunctionsByType[object.objectTypeIndex]

        if objectCoveredStatusChangedFunctions then
            for i,func in ipairs(objectCoveredStatusChangedFunctions) do
                func(object)
            end
        end
    end
end

local function doCoveredStatusTests()
    for objectID,v in pairs(queuedUpdateCoveredStatusObjects) do
        local object = serverGOM:getObjectWithID(objectID)
        if object then 
            doTestAndUpdateCoveredStatus(object)
        end
    end
    queuedUpdateCoveredStatusObjects = {}
end

function serverGOM:testAndUpdateCoveredStatusIfNeeded(object)
    if serverGOM:setContainsObjectWithID(serverGOM.objectSets.coveredStatusObservers, object.uniqueID) then
        queuedUpdateCoveredStatusObjects[object.uniqueID] = true
    end
    --if serverGOM:setContainsObjectWithID(serverGOM.objectSets.pathingCollisionObservers, object.uniqueID) then --this is currently always a sapien, so just call it directly
        --doCoveredTest(object)
   -- end
end


function serverGOM:debugToggleCovered(object)
    mj:log("serverGOM:debugTestCovered")
    if serverGOM:setContainsObjectWithID(serverGOM.objectSets.coveredStatusObservers, object.uniqueID) then
        if not object.sharedState.covered then
            object.sharedState:set("covered", true)
        else
            object.sharedState:remove("covered")
        end

        local objectCoveredStatusChangedFunctions = objectCoveredStatusChangedFunctionsByType[object.objectTypeIndex]

        if objectCoveredStatusChangedFunctions then
            for i,func in ipairs(objectCoveredStatusChangedFunctions) do
                func(object)
            end
        end
    end
end

local radiusForCoveredObservers = mj:mToP(4.0)
local radiusForLightObservers = mj:mToP(20.0)

local function doUpdateNearByObjectObservers(changedObject, sets)

    local setsToUse = {}
    local foundLightObserverSet = false
    for setIndex, tf in pairs(sets) do
        if setIndex == serverGOM.objectSets.lightObservers then
            foundLightObserverSet = true
        else
            table.insert(setsToUse, setIndex)
        end
    end

    local resultObjectsBySet = serverGOM:getGameObjectsInSetsWithinNormalizedRadiusOfPos(setsToUse, changedObject.normalizedPos, radiusForCoveredObservers)

    --mj:log("serverGOM:updateNearByObjectObservers:", changedObject.uniqueID, " resultObjectsBySet:", resultObjectsBySet)
    local coveredStatusObserverObjects = resultObjectsBySet[serverGOM.objectSets.coveredStatusObservers]
    if coveredStatusObserverObjects then
        for i,objectInfo in ipairs(coveredStatusObserverObjects) do
            local object = allObjects[objectInfo.objectID]
            if object then
               -- mj:log("do covered test due to near by object change:", object.uniqueID)
               --testAndUpdateCoveredStatus(object)
               queuedUpdateCoveredStatusObjects[object.uniqueID] = true
            end
        end
    end

    local pathingCollisionObserverObjects = resultObjectsBySet[serverGOM.objectSets.pathingCollisionObservers]
    if pathingCollisionObserverObjects then
        for i,objectInfo in ipairs(pathingCollisionObserverObjects) do
            local object = allObjects[objectInfo.objectID]
            if object then
                serverGOM:removeObjectFromSet(object, serverGOM.objectSets.pathingCollisionObservers)
                object.sharedState:remove("pathStuckLastAttemptTime")
            end
        end
    end

    local inaccessibleObserverObjects = resultObjectsBySet[serverGOM.objectSets.inaccessible]
    if inaccessibleObserverObjects then
        for i,objectInfo in ipairs(inaccessibleObserverObjects) do
            local object = allObjects[objectInfo.objectID]
            if object then
                serverGOM:removeInaccessible(object)
            end
        end
    end

    if foundLightObserverSet then
        local results = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.lightObservers, changedObject.pos, radiusForLightObservers)
        for i,info in ipairs(results) do
            local object = serverGOM:getObjectWithID(info.objectID)
            if object then
                planLightProbes:updateDarkStatus(object)
            end
        end
    end
    
end

local objectsThatNeedToUpdateNearByObservers = {}

function serverGOM:updateNearByObjectObservers(changedObjectID, objectTypeIndex, prevObjectTypeIndexOrNil)
    --mj:log("serverGOM:updateNearByObjectObservers:",changedObjectID)

    local function addSet(setIndex)
        local sets = objectsThatNeedToUpdateNearByObservers[changedObjectID]
        if not sets then
            sets = {}
            objectsThatNeedToUpdateNearByObservers[changedObjectID] = sets
        end
        sets[setIndex] = true
    end

    local function checkObjectType(objectTypeIndexToCheck)
        local gameObjectType = gameObject.types[objectTypeIndexToCheck]

        if gameObjectType.isPathFindingCollider then
            addSet(serverGOM.objectSets.pathingCollisionObservers)
            addSet(serverGOM.objectSets.inaccessible)
        elseif gameObjectType.pathFindingDifficulty ~= nil then
            addSet(serverGOM.objectSets.inaccessible)
        end

        if gameObjectType.blocksRain then
            addSet(serverGOM.objectSets.coveredStatusObservers)
        end
    end

    checkObjectType(objectTypeIndex)
    if prevObjectTypeIndexOrNil and objectTypeIndex ~= prevObjectTypeIndexOrNil then
        checkObjectType(prevObjectTypeIndexOrNil)
    end
end

function serverGOM:updateNearByObjectObserversForLightChange(changedObjectID)
    local sets = objectsThatNeedToUpdateNearByObservers[changedObjectID]
    if not sets then
        sets = {}
        objectsThatNeedToUpdateNearByObservers[changedObjectID] = sets
    end
    sets[serverGOM.objectSets.lightObservers] = true
end

function serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
    local terrainModificationObjectID = terrain:getObjectIDForTerrainModificationForVertex(vert)

    if not terrainModificationObjectID then
        local gameObjectType = gameObject.types.terrainModificationProxy
        local point = vert.pos

        terrainModificationObjectID = serverGOM:createGameObject({
            objectTypeIndex = gameObjectType.index,
            addLevel = mj.SUBDIVISIONS - 3,
            pos = point,
            rotation = mj:getNorthFacingFlatRotationForPoint(point),
            velocity = vec3(0.0,0.0,0.0),
            scale = 1.0,
            renderType = gameObjectType.renderTypeOverride or RENDER_TYPE_STATIC,
            hasPhysics = gameObjectType.hasPhysics,
            sharedState = {
                point = point,
                vertID = vert.uniqueID,
                planStates = {}
            },
        })
        terrain:addAndSaveObjectIDForVertex(vert, terrainModificationObjectID)
    end
    return terrainModificationObjectID
end

function serverGOM:objectCanBeRemovedHarmlessly(object) --used when loading up AI tribes, finding spaces to spawn structures
    if object.objectTypeIndex == gameObject.types.terrainModificationProxy.index or object.objectTypeIndex == gameObject.types.sapien.index then
        return false
    end

    if object.sharedState and (object.sharedState.tribeID or object.sharedState.planStates) then
        return false
    end

    return true
end

function serverGOM:convertToTemporaryCraftArea(object, tribeID)

    local objectInfo = serverGOM:getStateForAdditionToInventory(object)
    local prevObjectTypeIndex = object.objectTypeIndex
    
    local newSharedState = {
        tribeID = tribeID,
        temporaryCraftAreaOriginalObjectInfo = objectInfo,
        temporaryCraftAreaOriginalObjectPos = object.pos,
        temporaryCraftAreaOriginalObjectRotation = object.rotation
    }

    local keysToRemove = {}
    for k,v in pairs(object.sharedState) do
        table.insert(keysToRemove, k)
    end

    for i,k in ipairs(keysToRemove) do
        object.sharedState:remove(k)
    end

    for k,v in pairs(newSharedState) do
        object.sharedState:set(k,v)
    end

    gameObjectSharedState:setupState(object, object.sharedState)

    local privateState = serverGOM:getPrivateState(object)
    privateState.removeWhenOrderComplete = true

    local newRotation = mj:getNorthFacingFlatRotationForPoint(object.normalizedPos)

    --mj:log("convertToTemporaryCraftArea setting rotation:", newRotation, " for pos:", object.normalizedPos)
    local clampToSeaLevel = false
    local shiftedPos = worldHelper:getBelowSurfacePos(object.pos, 0.1, physicsSets.walkable, nil, clampToSeaLevel)
    serverGOM:setPos(object.uniqueID, shiftedPos)

    serverGOM:setDynamicPhysics(object.uniqueID, false)
    serverGOM:setRotation(object.uniqueID, newRotation)
    serverGOM:changeObjectType(object.uniqueID, gameObject.types.temporaryCraftArea.index, false)
    
    --mj:log("convertToTemporaryCraftArea new rotation:", object.rotation, " id:", object.uniqueID)


    serverGOM:updateNearByObjectObservers(object.uniqueID, object.objectTypeIndex, prevObjectTypeIndex)

    return objectInfo

end

function serverGOM:updateTerrainModificationProxyObjectPosForTerrainModifcation(vertID)
    local vert = terrain:getVertWithID(vertID)
    if vert then
        local terrainModificationObjectID = terrain:getObjectIDForTerrainModificationForVertex(vert)
        if terrainModificationObjectID then
            local object = serverGOM:getObjectWithID(terrainModificationObjectID)
            if object then
                serverGOM:setPos(object.uniqueID, vert.pos)
                serverGOM:saveObject(object.uniqueID)
            end
        end
    end
end

function serverGOM:updateBuildSequenceIndex(buildOrCraftObject, sapien, planTypeIndex, constructableType, planStateOrNil)
    local sharedState = buildOrCraftObject.sharedState
    local isDeconstructOrRebuild = (planTypeIndex == plan.types.deconstruct.index or planTypeIndex == plan.types.rebuild.index)

    local buildSequenceIndex = sharedState.buildSequenceIndex
    if isDeconstructOrRebuild then
        if (not buildSequenceIndex) then
            buildSequenceIndex = #constructableType.buildSequence
        end
    else
        if (not buildSequenceIndex) or buildSequenceIndex == 0 then
            buildSequenceIndex = 1
        end
    end

    sharedState:set("buildSequenceIndex", buildSequenceIndex)
    
    if isDeconstructOrRebuild and constructableType.buildSequence[buildSequenceIndex] then
        local constructableSequenceTypeIndex = constructableType.buildSequence[buildSequenceIndex].constructableSequenceTypeIndex
        if constructable.sequenceTypes[constructableSequenceTypeIndex].skipOnDestruction then
            local planState = planStateOrNil
            if not planState then
                planState = planManager:getPlanStateForObject(buildOrCraftObject, planTypeIndex, nil, nil, sapien.sharedState.tribeID, nil)
            end
            if planState then
                serverGOM:incrementBuildSequence(buildOrCraftObject, sapien, planState, constructableType, false)
            end
        end
    end
end


function serverGOM:incrementBuildSequence(buildOrCraftObject, sapienOrNil, planState, constructableType, completeEntireSequenceImmediately)
    local sharedState = buildOrCraftObject.sharedState
    
    local isDeconstructOrRebuild = planState and (planState.planTypeIndex == plan.types.deconstruct.index or planState.planTypeIndex == plan.types.rebuild.index)

    local buildSequenceIndex = sharedState.buildSequenceIndex


    local function doIncrement()
        if isDeconstructOrRebuild then
            --mj:error("doIncrement")
            if buildSequenceIndex == nil then
                buildSequenceIndex = #constructableType.buildSequence
            else
                buildSequenceIndex = buildSequenceIndex - 1
            end
            if buildSequenceIndex > 0 then
                local constructableSequenceTypeIndex = constructableType.buildSequence[buildSequenceIndex].constructableSequenceTypeIndex
                if constructable.sequenceTypes[constructableSequenceTypeIndex].skipOnDestruction then
                    doIncrement()
                end
            end
        else
            local skipIncrementDueToRepeat = false
            --[[if not constructableType.buildSequence[buildSequenceIndex] then
                mj:error("no constructableType.buildSequence[buildSequenceIndex]:",  buildOrCraftObject.uniqueID, " state:", sharedState)
            end]]

            if buildSequenceIndex and constructableType.buildSequence[buildSequenceIndex] and constructableType.buildSequence[buildSequenceIndex].repeatCount and (not completeEntireSequenceImmediately) then
                if planState and planState.planTypeIndex ~= plan.types.research.index then --hack this in here, we don't want to wait around if this is a research order, just complete the craft straight away
                    local repeatCounters = sharedState.buildSequenceRepeatCounters
                    if not repeatCounters then
                        sharedState:set("buildSequenceRepeatCounters", {})
                        repeatCounters = sharedState.buildSequenceRepeatCounters
                    end
                    local repeatCounter = (sharedState.buildSequenceRepeatCounters[buildSequenceIndex] or 0) + 1
                    if repeatCounter < constructableType.buildSequence[buildSequenceIndex].repeatCount then
                        skipIncrementDueToRepeat = true
                        sharedState:set("buildSequenceRepeatCounters", buildSequenceIndex, repeatCounter)
                    end
                end
            end

            if not skipIncrementDueToRepeat then
                if buildSequenceIndex == nil then
                    buildSequenceIndex = 1
                else
                    buildSequenceIndex = buildSequenceIndex + 1
                end
            end
        end
        sharedState:set("buildSequenceIndex", buildSequenceIndex)
        ----disabled--mj:objectLog(buildOrCraftObject.uniqueID, "serverGOM:incrementBuildSequence buildSequenceIndex:", buildSequenceIndex)
        
        if completeEntireSequenceImmediately and buildSequenceIndex > 0 and 
        buildSequenceIndex <= #constructableType.buildSequence and
        constructableType.buildSequence[buildSequenceIndex] and
        constructableType.buildSequence[buildSequenceIndex].constructableSequenceTypeIndex == constructable.sequenceTypes.actionSequence.index then
            doIncrement()
        end
    end

    doIncrement()
    
    if not serverGOM:checkIfNeedsToIncrementBuildSequenceDueToMoveComponentsComplete(buildOrCraftObject, sapienOrNil, planState) then
        planManager:updateRequiredSkillsForBuildSequenceIncrement(buildOrCraftObject, planState)

        if not serverGOM:checkIfBuildOrCraftOrderIsComplete(buildOrCraftObject, sapienOrNil, planState) then
            serverSapien:announce(buildOrCraftObject.uniqueID, sharedState.tribeID)
        end
    end
end


function serverGOM:ejectTools(buildOrCraftObject, tribeID, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil)
    local inventories = buildOrCraftObject.sharedState.inventories
    if inventories then
        local inventory = inventories[objectInventory.locations.tool.index]
        if inventory and inventory.objects then
            
            local function restoreResource(objectInfo)
                serverGOM:createOutput(buildOrCraftObject.pos, nil, objectInfo.objectTypeIndex, {
                    fractionDegraded = objectInfo.fractionDegraded, 
                    constructionObjects = objectInfo.constructionObjects
                }, tribeID, plan.types.storeObject.index, {
                    planOrderIndex = planOrderIndexOrNil,
                    planPriorityOffset = planPriorityOffsetOrNil,
                    manuallyPrioritized = manuallyPrioritizedOrNil,
                })
            end

            for i, objectInfo in ipairs(inventory.objects) do
                restoreResource(objectInfo)
            end
            buildOrCraftObject.sharedState:remove("inventories", objectInventory.locations.tool.index)
        end
    end
end

function serverGOM:ejectFuel(buildObject, tribeID, planOrderIndexOrNil, planPriorityOffsetOrNil, manuallyPrioritizedOrNil)
    local sharedState = buildObject.sharedState
    local fuelState = sharedState.fuelState
    if fuelState then
        for i,fuelInfo in ipairs(fuelState) do
            if fuelInfo.objectTypeIndex and fuelInfo.fuel > 0.05 then
                serverGOM:createOutput(buildObject.pos, nil, fuelInfo.objectTypeIndex, {fractionDegraded = fuel:degradeFractionForFuelStateInfo(buildObject, fuelInfo) }, tribeID, plan.types.storeObject.index, {
                    planOrderIndex = planOrderIndexOrNil,
                    planPriorityOffset = planPriorityOffsetOrNil,
                    manuallyPrioritized = manuallyPrioritizedOrNil,
                })
            end
            sharedState:set("fuelState", i, "fuel", 0)
        end
    end
end

function serverGOM:removeObjectFromInProgressBuildObjectWithObjectTypeIndex(buildObjectID, objectTypeIndex, inventoryLocationOrNil)
    local object = serverGOM:getObjectWithID(buildObjectID)

    local objectInfo = nil

    local placesToCheck = nil
    if inventoryLocationOrNil then
        placesToCheck = {inventoryLocationOrNil}
    else
        placesToCheck = {
            objectInventory.locations.availableResource.index,
            objectInventory.locations.tool.index,
        }
    end
    
    local objectState = object.sharedState

    if objectState.inventories then
        for i,inventoryLocation in ipairs(placesToCheck) do
            objectInfo = objectInventory:removeAndGetInfo(objectState, inventoryLocation, objectTypeIndex, nil)

            if objectInfo then
                serverGOM:saveObject(object.uniqueID)
                return objectInfo
            end
        end
    end
    return nil
end

function serverGOM:convertFinalBuildObjectToInProgressForDeconstruction(buildObject, tribeID)
    serverGOM:ejectFuel(buildObject, tribeID, nil, nil)
    serverGOM:ejectTools(buildObject, tribeID, nil, nil, nil)

    local oldSharedState = buildObject.sharedState
    local prevObjectTypeIndex = buildObject.objectTypeIndex

    if not oldSharedState.constructionConstructableTypeIndex then
        mj:error("no constructionConstructableTypeIndex:", oldSharedState)
    end

    local newSharedState = {
        tribeID = oldSharedState.tribeID,
        subModelInfos = oldSharedState.subModelInfos,
        inProgressConstructableTypeIndex = oldSharedState.constructionConstructableTypeIndex,
        preventGrassAndSnowVertIDs = oldSharedState.preventGrassAndSnowVertIDs,
        restrictedResourceObjectTypes = oldSharedState.restrictedResourceObjectTypes,
    }

    local constructionObjects = oldSharedState.constructionObjects
    if constructionObjects then
        
        newSharedState.inventories = {}
        local newInUseInventory = {}
        newSharedState.inventories[objectInventory.locations.inUseResource.index] = newInUseInventory
        newInUseInventory.objects = constructionObjects
        newInUseInventory.countsByObjectType = {}
        for i, objectInfo in ipairs(constructionObjects) do
            if not newInUseInventory.countsByObjectType[objectInfo.objectTypeIndex] then
                newInUseInventory.countsByObjectType[objectInfo.objectTypeIndex] = 0
            end
            newInUseInventory.countsByObjectType[objectInfo.objectTypeIndex] = newInUseInventory.countsByObjectType[objectInfo.objectTypeIndex] + 1
        end
    end
    
    if oldSharedState.decalBlockers then
        buildObject.privateState.decalBlockers = oldSharedState.decalBlockers
    end

    local constructableType = constructable.types[newSharedState.inProgressConstructableTypeIndex]

    local newTypeIndex = gameObject.types[constructableType.inProgressGameObjectTypeKey].index or buildObject.objectTypeIndex

    local keysToRemove = {}
    for k,v in pairs(buildObject.sharedState) do
        table.insert(keysToRemove, k)
    end

    for i,k in ipairs(keysToRemove) do
        buildObject.sharedState:remove(k)
    end

    for k,v in pairs(newSharedState) do
        buildObject.sharedState:set(k,v)
    end
    gameObjectSharedState:setupState(buildObject, buildObject.sharedState)
    
    if newTypeIndex ~= buildObject.objectTypeIndex then
        serverGOM:changeObjectType(buildObject.uniqueID, newTypeIndex, false)
        serverGOM:updateNearByObjectObservers(buildObject.uniqueID, newTypeIndex, prevObjectTypeIndex)
    end

    updateVertsForObjectIfNeeded(buildObject, true)

end

function serverGOM:checkIfNeedsToIncrementBuildSequenceDueToMoveComponentsComplete(buildOrCraftObject, sapienOrNil, planState)
    local constructableType = planState and constructable.types[planState.constructableTypeIndex]
    if constructableType then
        local isDeconstructOrRebuild = (planState.planTypeIndex == plan.types.deconstruct.index or planState.planTypeIndex == plan.types.rebuild.index)
        local buildSequenceIndex = buildOrCraftObject.sharedState.buildSequenceIndex or 1
        local currentBuildSequenceInfo = constructableType.buildSequence[buildSequenceIndex]
        if currentBuildSequenceInfo and currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.moveComponents.index then
            if constructableType.requiredResourceTotalCount and constructableType.requiredResourceTotalCount > 0 then
                local totalMovedCount = objectInventory:getTotalCount(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index)
                local done = false
                if isDeconstructOrRebuild then
                    done = (totalMovedCount == 0)
                else
                    done = (totalMovedCount >= constructableType.requiredResourceTotalCount)
                end
                if done then
                    serverGOM:incrementBuildSequence(buildOrCraftObject, sapienOrNil, planState, constructableType, false)
                    return true
                end
            else
                serverGOM:incrementBuildSequence(buildOrCraftObject, sapienOrNil, planState, constructableType, false)
                return true
            end
        end
    end
    return false
end


function serverGOM:checkIfBuildOrCraftOrderIsComplete(buildOrCraftObject, sapienOrNil, planState)
    if planManager:getPlanStateForObject(buildOrCraftObject, planState.planTypeIndex, planState.objectTypeIndex, planState.researchTypeIndex, planState.tribeID, nil) == nil then
        mj:warn("plan no longer exits in serverGOM:checkIfBuildOrCraftOrderIsComplete for object:", buildOrCraftObject.uniqueID)
        return
    end

    local constructableType = constructable.types[planState.constructableTypeIndex]
    local isDeconstruct = (planState.planTypeIndex == plan.types.deconstruct.index)
    local isRebuild = (planState.planTypeIndex == plan.types.rebuild.index)
    local orderObjectGameObjectType = gameObject.types[buildOrCraftObject.objectTypeIndex]
    
    if isDeconstruct or isRebuild then
        local buildSequenceIndex = 0
        if constructableType.buildSequence then
            buildSequenceIndex = buildOrCraftObject.sharedState.buildSequenceIndex or #constructableType.buildSequence
            
            local totalMovedCount = objectInventory:getTotalCount(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index)
            local totalAvailableCount = objectInventory:getTotalCount(buildOrCraftObject.sharedState, objectInventory.locations.availableResource.index)
            

            if totalMovedCount == 0 and totalAvailableCount == 0 then
                buildSequenceIndex = 0
            else
                local currentBuildSequenceInfo = constructableType.buildSequence[buildSequenceIndex]
                if not currentBuildSequenceInfo then
                    mj:error("expected currentBuildSequenceInfo in serverGOM:checkIfBuildOrCraftOrderIsComplete. buildSequenceIndex is:", buildSequenceIndex)
                    buildSequenceIndex = 0
                else
                    if currentBuildSequenceInfo.constructableSequenceTypeIndex == constructable.sequenceTypes.moveComponents.index then
                        if constructableType.requiredResourceTotalCount and constructableType.requiredResourceTotalCount > 0 then
                            totalMovedCount = objectInventory:getTotalCount(buildOrCraftObject.sharedState, objectInventory.locations.inUseResource.index)
                            if totalMovedCount <= 0 then
                                serverGOM:incrementBuildSequence(buildOrCraftObject, sapienOrNil, planState, constructableType, false)
                                buildSequenceIndex = buildOrCraftObject.sharedState.buildSequenceIndex
                            end
                        else
                            serverGOM:incrementBuildSequence(buildOrCraftObject, sapienOrNil, planState, constructableType, false)
                            buildSequenceIndex = buildOrCraftObject.sharedState.buildSequenceIndex
                        end
                    end
                end
            end
        end

        if buildSequenceIndex <= 0 then
            if isDeconstruct then
                serverGOM:ejectTools(buildOrCraftObject, planState.tribeID, planState.planOrderIndex or planState.planID, planState.priorityOffset, planState.manuallyPrioritized)
                serverGOM:removeGameObject(buildOrCraftObject.uniqueID)
            elseif isRebuild then
                ----disabled--mj:objectLog(buildOrCraftObject.uniqueID, "planState in serverGOM:checkIfBuildOrCraftOrderIsComplete:", planState, " sharedState:", buildOrCraftObject.sharedState)
                planManager:addBuildOrPlantPlanForRebuild(buildOrCraftObject.uniqueID, planState.tribeID, planState.rebuildConstructableTypeIndex, planState.rebuildRestrictedResourceObjectTypes, planState.rebuildRestrictedToolObjectTypes)
            end

            return true
        else
            return false
        end
    else

        if not constructableType then
            return false
        end
        

        local function completeCraftOrder()
            serverCraftArea:completeCraft(buildOrCraftObject, planState.planTypeIndex, planState.tribeID, sapienOrNil)
        end
        
        local function completeOrder()
            if orderObjectGameObjectType.isCraftArea then
                completeCraftOrder()
            else
                completeBuildOrder(buildOrCraftObject, constructableType, planState, planState.tribeID)
            end
        end

        local buildSequenceIndex = buildOrCraftObject.sharedState.buildSequenceIndex or 1

        if buildSequenceIndex > #constructableType.buildSequence then
            --mj:error("completeOrder. state:", buildOrCraftObject.sharedState)
            completeOrder()

            if sapienOrNil and planState.researchTypeIndex then
                local researchType = research.types[planState.researchTypeIndex]
                if researchType.completeDiscoveryOnlyAllowConstructableTypes then
                    if researchType.completeDiscoveryOnlyAllowConstructableTypes[constructableType.index] then
                        serverSapienSkills:completeResearchImmediately(sapienOrNil, planState.researchTypeIndex, planState.discoveryCraftableTypeIndex or constructableType.index)
                    end
                else
                    serverSapienSkills:completeResearchImmediately(sapienOrNil, planState.researchTypeIndex, planState.discoveryCraftableTypeIndex or constructableType.index)
                end
            end

            return true
        else
            return false
        end
    end
end

function serverGOM:setAllowItemUse(object, allowItemUse)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if gameObjectType.isPlacedObject then
        local keepDegradeInfo = true
        serverGOM:changeObjectType(object.uniqueID, gameObjectType.placeBaseObjectTypeIndex, keepDegradeInfo)
    end
end

function serverGOM:addActionForNPC(sapienObject, actionInfo, userData)
    serverSapien:addAction(sapienObject, actionInfo, userData)
end


function serverGOM:dropObject(inventoryRemovalObjectInfo, shiftedPos, sapienTribeIDOrNil, addStoreOrder)
    local sharedState = serverGOM:getSharedStateForRemovalFromInventory(inventoryRemovalObjectInfo)

    local gameObjectType = gameObject.types[inventoryRemovalObjectInfo.objectTypeIndex]

    
    local randomVel = (normalize(shiftedPos) + rng:vec()) * 0.2
    
    local droppedObjectID = serverGOM:createGameObject(
        {
            objectTypeIndex = gameObjectType.index,
            addLevel = mj.SUBDIVISIONS - 2,
            pos = shiftedPos,
            rotation = mat3Identity,
            velocity = randomVel,
            scale = gameObjectType.scale,
            renderType = RENDER_TYPE_DYNAMIC,
            hasPhysics = gameObjectType.hasPhysics,
            dynamicPhysics = true,
            sharedState = sharedState,
        }
    )

    if droppedObjectID and sapienTribeIDOrNil then
        --mj:log("inventoryRemovalObjectInfo:", inventoryRemovalObjectInfo)
        if inventoryRemovalObjectInfo.orderContext and (inventoryRemovalObjectInfo.orderContext.orderTypeIndex == order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index or
        (inventoryRemovalObjectInfo.orderContext.planState and inventoryRemovalObjectInfo.orderContext.planState.researchTypeIndex)) then
            planManager:reAddPlanForDroppedObjectWithPlanState(sapienTribeIDOrNil, inventoryRemovalObjectInfo, droppedObjectID)
        elseif addStoreOrder then
            if sharedState.storageAreaTransferInfo then
                planManager:addStandardPlan(sapienTribeIDOrNil, plan.types.transferObject.index, droppedObjectID, nil, nil, nil, nil, nil, nil)
            else
                planManager:addStandardPlan(sapienTribeIDOrNil, plan.types.storeObject.index, droppedObjectID, nil, nil, nil, nil, nil, nil)
            end
        end
    end

end

function serverGOM:throwObjectAtGoal(inventoryRemovalObjectInfo, startPos, goalPos, velocity)

    local sharedState = serverGOM:getSharedStateForRemovalFromInventory(inventoryRemovalObjectInfo)

    local gameObjectType = gameObject.types[inventoryRemovalObjectInfo.objectTypeIndex]

    local trajectoryVec = mj:calculateTrajectory(startPos, goalPos, velocity)

    local rotation = mjm.mat3LookAtInverse(normalize(trajectoryVec), normalize(startPos))
    rotation = mjm.mat3Rotate(rotation, math.pi * -0.5, vec3(0.0,1.0,0.0))
    
    local thrownObjectID = serverGOM:createGameObject(
        {
            objectTypeIndex = gameObjectType.index,
            addLevel = mj.SUBDIVISIONS - 2,
            pos = startPos,
            rotation = rotation,
            velocity = trajectoryVec * mj:pToM(1.0),
            scale = gameObjectType.scale,
            renderType = RENDER_TYPE_DYNAMIC,
            hasPhysics = gameObjectType.hasPhysics,
            dynamicPhysics = true,
            sharedState = sharedState,
        }
    )

    --mj:log("thrownObjectID:", thrownObjectID)
    return thrownObjectID
end

function serverGOM:throwObjectWithVelocity(inventoryRemovalObjectInfo, startPos, velocityVec)
    
    local sharedState = serverGOM:getSharedStateForRemovalFromInventory(inventoryRemovalObjectInfo)
    local gameObjectType = gameObject.types[inventoryRemovalObjectInfo.objectTypeIndex]
    local rotation = mjm.mat3LookAtInverse(normalize(velocityVec), normalize(startPos))
    rotation = mjm.mat3Rotate(rotation, math.pi * -0.5, vec3(0.0,1.0,0.0))

    local thrownObjectID = serverGOM:createGameObject(
        {
            objectTypeIndex = gameObjectType.index,
            addLevel = mj.SUBDIVISIONS - 2,
            pos = startPos,
            rotation = rotation,
            velocity = velocityVec * mj:pToM(1.0),
            scale = gameObjectType.scale,
            renderType = RENDER_TYPE_DYNAMIC,
            hasPhysics = gameObjectType.hasPhysics,
            dynamicPhysics = true,
            sharedState = sharedState,
        }
    )

    --mj:log("thrownObjectID:", thrownObjectID)
    return thrownObjectID
end


function serverGOM:degradeWeapon(weaponObject, toolInfo, throwerSapienID)
    local function getWeaponDurabilityMultiplier(toolObjectInfo)
        local degradeIncrementMultiplier = nil
        if toolInfo then
            if toolInfo[tool.propertyTypes.durability.index] then
                degradeIncrementMultiplier = 1.0 / toolInfo[tool.propertyTypes.durability.index]
            end
        end
        return degradeIncrementMultiplier
    end

    local degradeIncrementMultiplier = getWeaponDurabilityMultiplier(weaponObject)
    if degradeIncrementMultiplier then
        local fractionDegraded = weaponObject.sharedState.fractionDegraded or 0.0
        fractionDegraded = fractionDegraded + 0.1251 * degradeIncrementMultiplier
        if fractionDegraded >= 1.0 then
            local throwerSapien = serverGOM:getObjectWithID(throwerSapienID)
            if throwerSapien then
                serverGOM:sendNotificationForObject(throwerSapien, notification.types.toolBroke.index, {
                    pos = weaponObject.pos
                }, nil)
            end
            serverGOM:removeGameObject(weaponObject.uniqueID)
            return true
        else
            weaponObject.sharedState:set("fractionDegraded", fractionDegraded)
        end
    end
    return false
end

--thrownObjectID, throwerSapienID, delay, directionNormal, projectileVelocity, tribeID
function serverGOM:degradeAndEmbedProjectileInGroundForThrow(thrownObjectID, throwerSapienID, targetObjectID, tribeID, delay, directionNormal, projectileVelocity, goalPos)
    timer:addCallbackTimer(delay, function()
        local weaponObject = serverGOM:getObjectWithID(thrownObjectID)
        if weaponObject then
            local toolInfo = nil
            local toolType = nil
            local heldObjectType = gameObject.types[weaponObject.objectTypeIndex]
            local toolUsages = heldObjectType.toolUsages
            if toolUsages then
                toolType = tool.types.weaponSpear
                toolInfo = toolUsages[toolType.index]
                if not toolInfo then
                    toolType = tool.types.weaponBasic
                    toolInfo = toolUsages[toolType.index]
                end
            end

            local degradeRemoved = serverGOM:degradeWeapon(weaponObject, toolInfo, throwerSapienID)

            if not degradeRemoved then
                if toolType.projectileEmbeds then
                    local embedRotation = createUpAlignedRotationMatrix(normalize(goalPos), directionNormal)
                    embedRotation = mat3Rotate(embedRotation, math.pi * 0.25, vec3(1.0,0.0,0.0))

                    local clampToSeaLevel = true
                    local shiftedPos = worldHelper:getBelowSurfacePos(goalPos, 0.1, nil, nil, clampToSeaLevel)
                    local posOffset = mat3GetRow(embedRotation, 2) * mj:mToP(-0.75)

                    embedRotation = mat3Rotate(embedRotation,math.pi * -0.5, vec3(0.0,1.0,0.0))
                    serverGOM:setRotation(weaponObject.uniqueID, embedRotation)
                    serverGOM:setPos(weaponObject.uniqueID, shiftedPos + posOffset)
                    serverGOM:setDynamicPhysics(weaponObject.uniqueID, false);
                    serverGOM:sendSnapObjectMatrix(weaponObject.uniqueID, false)

                    --mj:log("serverGOM:degradeAndEmbedProjectileInGroundForThrow sending pos:", weaponObject.pos, " shiftedPos + posOffset:", shiftedPos + posOffset)

                    --[[local orderContext = {
                        planObjectID = targetObjectID,
                    }
                    weaponObject.sharedState:set("orderContext", orderContext)]]

                    planManager:addStandardPlan(tribeID, plan.types.storeObject.index, weaponObject.uniqueID, nil, nil, nil, nil, nil, nil)
                    local sapien = serverGOM:getObjectWithID(throwerSapienID)
                    if sapien then
                        local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
                        unsavedState.preventUnnecessaryAutomaticOrderTimer = nil
                        serverSapienAI:focusOnPlanObjectAfterCompletingOrder(sapien, weaponObject)
                        serverSapien:cancelAllOrders(sapien, false, false)
                    end
                end
            end
        end
    end)
end


--[[local minModifiedTerrainShiftDistance = mj:mToP(0.01)
local minModifiedTerrainShiftDistance2 = minModifiedTerrainShiftDistance * minModifiedTerrainShiftDistance

function serverGOM:shiftObjectForModifiedTerrain(object)
    local shiftedPos = worldHelper:getBelowSurfacePos(object.pos, 0.3, physicsSets.walkable)
    if length2(shiftedPos - object.pos) > minModifiedTerrainShiftDistance2 then
        if shiftedPos then
            serverGOM:setPos(object.uniqueID, shiftedPos)
        end
    
        serverGOM:setDynamicPhysics(object.uniqueID, true);
        
        serverResourceManager:updateResourcesForObject(object)
        serverGOM:saveObject(object.uniqueID)
    end
end

local function checkObjectsForBelowSurfaceHeightModification(objectIDs)
    for j,objectID in ipairs(objectIDs) do
        local object = allObjects[objectID]
        if object then
            if object.objectTypeIndex == gameObject.types.sapien.index then
                serverSapien:terrainModifiedBelow(object)
            elseif not gameObject.types[object.objectTypeIndex].preventShiftOnTerrainSurfaceModification then
                serverGOM:shiftObjectForModifiedTerrain(object)
            end
        end
    end
end

function serverGOM:updateObjectsForVertHeightModification(vertID)
    local objectIDs = serverGOM:getGameObjectsBelongingToFacesAroundVertex(vertID)
    checkObjectsForBelowSurfaceHeightModification(objectIDs)
end]]

--[[local function updatePathSubModels()
    local function offsetPathSubObjectsToTerrain()
        if nodeInfo.pathSubModelUpdatedInfos then
            for i,subModelUpdatedInfo in ipairs(nodeInfo.pathSubModelUpdatedInfos) do
                local maxSubModelAltitude = nil
                for j=1,4 do
                    local rotatedOffset = vec3xMat3(pathTestOffsets[j] * buildObjectScale * subModelUpdatedInfo.scale * 0.3, mat3Inverse(rotation * subModelUpdatedInfo.rotation))
                    local finalPosition = subModelUpdatedInfo.pos + rotatedOffset
                    local terrainAltitudeResult = world:getMainThreadTerrainAltitude(finalPosition)
                    if terrainAltitudeResult.hasHit then
                        if ((not maxSubModelAltitude) or terrainAltitudeResult.terrainAltitude > maxSubModelAltitude) then
                            maxSubModelAltitude = terrainAltitudeResult.terrainAltitude
                        end
                    end
                end
                
        
                if maxSubModelAltitude then
                    local subObjectPosLength = length(subModelUpdatedInfo.pos)
                    subModelUpdatedInfo.pos = (subModelUpdatedInfo.pos / subObjectPosLength) * (maxSubModelAltitude + 1.0)
                end
            end
        end
    end
end]]

--local pathTestOffsets = pathBuildable.pathTestOffsets

--[[local function updatePathSubModels(object)
    local subModelInfos = object.sharedState.subModelInfos
    if subModelInfos then
        for i,subModelInfo in ipairs(subModelInfos) do
            local maxTerrainPointLength2 = nil
            for j=1,4 do
                local rotatedOffset = vec3xMat3(pathTestOffsets[j] * subModelInfo.scale * 0.3, mat3Inverse(object.rotation * subModelInfo.rotation))
                rotatedOffset = rotatedOffset + vec3xMat3(mj:mToP(subModelInfo.objectLocalOffsetMeters), mat3Inverse(object.rotation))
                local finalPosition = object.pos + rotatedOffset
                
                local terrainPoint = terrain:getHighestDetailTerrainPointAtPoint(finalPosition)
                local terrainPointLength2 = length2(terrainPoint)
                if ((not maxTerrainPointLength2) or terrainPointLength2 > maxTerrainPointLength2) then
                    maxTerrainPointLength2 = terrainPointLength2
                end
                --[[local terrainAltitudeResult = world:getMainThreadTerrainAltitude(finalPosition)
                if terrainAltitudeResult.hasHit then
                    if ((not maxSubModelAltitude) or terrainAltitudeResult.terrainAltitude > maxSubModelAltitude) then
                        maxSubModelAltitude = terrainAltitudeResult.terrainAltitude
                    end
                end]]
           -- end
            
           --[[ if maxTerrainPointLength2 then
                local maxTerrainPointLength = math.sqrt(maxTerrainPointLength2)
                local rotatedOffset = vec3xMat3(mj:mToP(subModelInfo.objectLocalOffsetMeters), mat3Inverse(object.rotation))
                local finalPosition = object.pos + rotatedOffset
                local finalSubModelWorldPos = normalize(finalPosition) * maxTerrainPointLength
                local offsetFromPreviousPos = finalSubModelWorldPos - finalPosition
                local objectLocalOffsetMeters = subModelInfo.objectLocalOffsetMeters + vec3xMat3(mj:pToM(offsetFromPreviousPos), object.rotation)
                object.sharedState:set("subModelInfos", i, "objectLocalOffsetMeters", objectLocalOffsetMeters)]]
               -- mj:log("set objectLocalOffsetMeters i:", i, " offset:", objectLocalOffsetMeters)

        --    end
     --   end
  --  end
--end]]

function serverGOM:applyShiftsForObjectsForVertHeightModification(vertID, affectedObjects, tribeIDOrNil)
    if affectedObjects then
        for i, objectInfo in ipairs(affectedObjects) do
            local object = objectInfo.object
            local terrainPoint = terrain:getHighestDetailTerrainPointAtPoint(object.pos)
            local newTerrainAltitude = length(terrainPoint)
            local gameObjectType = gameObject.types[object.objectTypeIndex]
            if gameObjectType.isPathObject or gameObjectType.isPathBuildObject or (newTerrainAltitude > objectInfo.objectAltitude or (objectInfo.objectAltitude - objectInfo.oldTerrainAltitude < mj:mToP(0.2))) then
                local altitudeChange = newTerrainAltitude - objectInfo.oldTerrainAltitude
                if altitudeChange > mj:mToP(0.0001) or altitudeChange < mj:mToP(-0.0001) then
                    serverGOM:setPos(object.uniqueID, object.pos + object.normalizedPos * altitudeChange, true)
                -- serverResourceManager:updateResourcesForObject(object) --maybe?

                    local removed = false
                    if gameObject.types[object.objectTypeIndex].floraTypeIndex then
                        local invalidSoil = serverFlora:getIsInvalidGrowthMedium(object)
                        if invalidSoil then
                            serverGOM:removeGameObjectAndDropInventory(object.uniqueID, tribeIDOrNil, true, nil, nil, nil, nil)
                            removed = true
                        end
                    end

                    if not removed then
                        
                        if gameObject.types[object.objectTypeIndex].seatTypeIndex then
                            serverSeat:removeSeatNodes(object)
                        end
                        serverGOM:testAndUpdateCoveredStatusIfNeeded(object)
                    
                        --if gameObject.types[object.objectTypeIndex].isPathObject or gameObject.types[object.objectTypeIndex].isPathBuildObject then
                        -- mj:log("affected path:", object.uniqueID)
                        --    updatePathSubModels(object)
                        --end

                        serverGOM:sendSnapObjectMatrix(object.uniqueID, true)
                        serverGOM:saveObject(object.uniqueID)
                    end
                end
            end
        end
    end
end

function serverGOM:updateObjectsForChangedSoilQuality(vertID)
    local vert = terrain:getVertWithID(vertID)
    local objectInfos = serverGOM:getGameObjectsInSetWithinRadiusOfPos(serverGOM.objectSets.soilQualityStatusObservers, vert.pos, mj:mToP(4.0))
    for i, objectInfo in ipairs(objectInfos) do
        local object = allObjects[objectInfo.objectID]
        if object then
            serverFlora:updateForChangedSoilQuality(object)
        end
    end
end


function serverGOM:getAffectedObjectInfosBeforeVertexHeightModification(vertID)
    local vert = terrain:getVertWithID(vertID)
    local objectInfos = serverGOM:getAllGameObjectsWithinRadiusOfPos(vert.pos, mj:mToP(10.0))
    local affectedObjectInfos = {}

    for i,objectInfo in ipairs(objectInfos) do
        local object = allObjects[objectInfo.objectID]
        if object then
            if not gameObject.types[object.objectTypeIndex].preventShiftOnTerrainSurfaceModification then
                local terrainPoint = terrain:getHighestDetailTerrainPointAtPoint(object.pos)
                local terrainAltitude = length(terrainPoint)
                local objectAltitude = length(object.pos)

                if terrainAltitude > objectAltitude or (objectAltitude - terrainAltitude < mj:mToP(1.1)) then
                    table.insert(affectedObjectInfos, {
                        object = object,
                        objectAltitude = objectAltitude,
                        oldTerrainAltitude = terrainAltitude,
                    })
                end
            end
        end
    end
    return affectedObjectInfos
end

--[[function serverGOM:clientFollowersRemoved(tribeID, sapienIDs)
    --mj:log("serverGOM:clientFollowersRemoved tribeID:", tribeID, " sapienIDs:", sapienIDs)
    local clientID = serverWorld:clientIDForTribeID(tribeID)
    if not clientID or clientID == mj.serverClientID or (not followerIDsByClient[clientID]) then
        return
    end
    local removedIDs = {}
    local removeCount = 0
    for i,sapienID in ipairs(sapienIDs) do
        if followerIDsByClient[clientID][sapienID] then
            table.insert(removedIDs, sapienID)
            removeCount = removeCount + 1
            followerIDsByClient[clientID][sapienID] = nil
        end
    end
    if removeCount > 0 then
        --mj:log("serverGOM:clientFollowersRemoved calling client followersRemoved with removeCount:", removeCount)
        server:callClientFunction(
            "followersRemoved",
            clientID,
            removedIDs
        )
    end
end]]

local function getInfoForFollowerAddition(sapien, tribeID)
    local state = sapien.sharedState
    if state and state.tribeID == tribeID then
        local sapienData = {
            objectTypeIndex = sapien.objectTypeIndex,
            sharedState = state,
            pos = sapien.pos,
            scale = sapien.scale,
            rotation = sapien.rotation,
            uniqueID = sapien.uniqueID
        }
        return sapienData
    end
    return nil
end

--[[function serverGOM:clientFollowersAdded(tribeID, sapienIDs)
    --mj:log("serverGOM:clientFollowersAdded tribeID:", tribeID, " sapienIDs:", sapienIDs)
    local clientID = serverWorld:clientIDForTribeID(tribeID)
    if not clientID or clientID == mj.serverClientID then
        return
    end
    
    local followerInfosToSend = {}
    if not followerIDsByClient[clientID] then
        followerIDsByClient[clientID] = {}
    end

    for i,sapienID in ipairs(sapienIDs) do
        if not followerIDsByClient[clientID][sapienID] then
            local infoToAdd = getInfoForFollowerAddition(sapien, tribeID)
            if infoToAdd then
                followerInfosToSend[sapienID] = infoToAdd
                followerIDsByClient[clientID][sapienID] = true
            end
        end
    end

    if next(followerInfosToSend) then
        server:callClientFunction(
            "followersAdded",
            clientID,
            followerInfosToSend
        )
    end
    
end]]


function serverGOM:sendFollowersListsForSapienCountChange(tribeID)
    --mj:log("serverGOM:sendFollowersListsForSapienCountChange a")
    local clientID = serverWorld:clientIDForTribeID(tribeID)
    if not clientID or clientID == mj.serverClientID then
        return
    end
    local sentIDSSet = serverGOM.sentFollowerIDsSetByClient[clientID]
    if not sentIDSSet then
        sentIDSSet = {}
        serverGOM.sentFollowerIDsSetByClient[clientID] = sentIDSSet
    end

    local addInfos = {}
    local remainingPreviousIDs = mj:cloneTable(sentIDSSet)
    
    --mj:log("serverGOM:sendFollowersListsForSapienCountChange b", remainingPreviousIDs)
    
    serverGOM:callFunctionForAllSapiensInTribe(tribeID, function (sapien)
        local sapienID = sapien.uniqueID
        if not remainingPreviousIDs[sapienID] then
            addInfos[sapienID] = getInfoForFollowerAddition(sapien, tribeID)
            sentIDSSet[sapienID] = true
        else
            remainingPreviousIDs[sapienID] = nil
        end
    end)

    --mj:log("addInfos:", addInfos)
    
    if next(addInfos) then
        server:callClientFunction(
            "followersAdded",
            clientID,
            addInfos
        )
    end
    
    if next(remainingPreviousIDs) then
        local removeIDs = {}
        for sapienID,v in pairs(remainingPreviousIDs) do
            table.insert(removeIDs, sapienID)
        end
        
        --mj:log("removeIDs:", removeIDs)
        
        server:callClientFunction(
            "followersRemoved",
            clientID,
            removeIDs
        )
    end
end


function serverGOM:sendInitialClientFollowersList(tribeID) --this probably isn't actually necessary anymore, client should have all the infos already
    local clientID = serverWorld:clientIDForTribeID(tribeID)
    if not clientID or clientID == mj.serverClientID then
        return
    end
    local followerInfosToSend = {}

    serverGOM:callFunctionForAllSapiensInTribe(tribeID, function (sapien) 
        followerInfosToSend[sapien.uniqueID] = getInfoForFollowerAddition(sapien, tribeID)
    end)

    mj:log("serverGOM:sendInitialClientFollowersList")
    
    server:callClientFunction(
        "initialFollowersList",
        clientID,
        followerInfosToSend
    )

end

function serverGOM:callFunctionForAllSapiensInTribe(tribeID, func)
    local sapiensByThisTribe = serverGOM.sapienObjectsByTribe[tribeID]
    if sapiensByThisTribe then
        for uid,object in pairs(sapiensByThisTribe) do
            func(object)
        end
    end
end

function serverGOM:callFunctionForRandomSapienInTribe(tribeID, func)
    local sapiensByThisTribe = serverGOM.sapienObjectsByTribe[tribeID]
    if sapiensByThisTribe then
        local loadedSapienCount = serverGOM.loadedSapienCountsByTribe[tribeID]
        if loadedSapienCount and loadedSapienCount > 0 then
            local randomIndex = rng:randomInteger(loadedSapienCount)
            local counter = 0
            for uid,object in pairs(sapiensByThisTribe) do
                counter = counter + 1
                if counter > randomIndex then
                    func(object)
                    return
                end
            end
        end
    end
end

function serverGOM:getObjectWithID(objectID)
    return allObjects[objectID]
end

function serverGOM:getObjectWithIDLoadingAreaIfNeeded(objectID, objectPos)
    local object = allObjects[objectID]
    if not object then
        terrain:loadAreaAtLevels(objectPos, mj.SUBDIVISIONS - 2, mj.SUBDIVISIONS - 1)
        object = allObjects[objectID]
    end
    return object
end

function serverGOM:saveObject(objectID)
    bridge:saveObject(objectID)
end

function serverGOM:sendNotificationForObject(object, notificationTypeIndex, userData, tribeIDOrNil)
    
    local clientID = nil
    if tribeIDOrNil then
        clientID = serverWorld:clientIDForTribeID(tribeIDOrNil)
        if clientID then 
            if clientID == mj.serverClientID then
                return
            end
            if not server.connectedClientsSet[clientID] then
                return
            end
        end
    end

    local objectSaveData = {
        uniqueID = object.uniqueID,
        pos = object.pos,
        objectTypeIndex = object.objectTypeIndex,
    }
    local titleFunction = notification.types[notificationTypeIndex].titleFunction
    if titleFunction then

        if object.objectTypeIndex == gameObject.types.sapien.index then
            objectSaveData.sharedState = serverNotifications:getSapienSaveSharedStateForNotification(object)
            if not userData then
                userData = {}
            end
            if not userData.name then
                userData.name = object.sharedState.name
            end
            --mj:log("object.objectTypeIndex == gameObject.types.sapien.index")
        end

        serverNotifications:saveNotification(object.uniqueID, notificationTypeIndex, userData, objectSaveData, tribeIDOrNil)
    end

    if clientID then
        serverGOM:setAlwaysSendToClientForObjectWithID(object.uniqueID, clientID, true)
    end

    --mj:log("serverGOM:sendNotificationForObject:", object.uniqueID, " userData:", userData, " notificationType:", notification.types[notificationTypeIndex].key)

    if tribeIDOrNil then
        if clientID then
            server:callClientFunction("objectNotification",
                clientID,
                {
                    notificationTypeIndex = notificationTypeIndex,
                    userData = userData,
                    objectSaveData = objectSaveData,
                }
            )
        end
    else
        server:callClientFunctionForAllClients("objectNotification", {
            notificationTypeIndex = notificationTypeIndex,
            userData = userData,
            objectSaveData = objectSaveData,
        })
    end
end

function serverGOM:sendSnapObjectMatrix(objectID, sendAfterAnyTerrainModifications)
    bridge:sendSnapObjectMatrix(objectID, sendAfterAnyTerrainModifications)
end

function serverGOM:addObjectToSet(object, setIndex)
    if setIndex == serverGOM.objectSets.lightEmitters then
        cachedLitObjects = nil
    end
    bridge:addObjectToSet(object.uniqueID, setIndex)
end

function serverGOM:countOfObjectsInSet(setIndex)
    return bridge:countOfObjectsInSet(setIndex)
end

function serverGOM:getAllGameObjectsInSet(setIndex)
    return bridge:getAllGameObjectsInSet(setIndex)
end

function serverGOM:getRandomGameObjectInSet(setIndex)
    return bridge:getRandomGameObjectInSet(setIndex)
end

function serverGOM:setContainsObjectWithID(setIndex, objectID)
    return bridge:setContainsObjectWithID(setIndex, objectID)
end

function serverGOM:removeObjectFromSet(object, setIndex)
    if setIndex == serverGOM.objectSets.lightEmitters then
        cachedLitObjects = nil
    end
    bridge:removeObjectFromSet(object.uniqueID, setIndex)
end

function serverGOM:getGameObjectsBelongingToFacesAroundVertex(vertID)
    return bridge:getGameObjectsBelongingToFacesAroundVertex(vertID)
end

function serverGOM:getGameObjectsOfTypesWithinRadiusOfPos(types, pos, radius)
    return bridge:getGameObjectsOfTypesWithinRadiusOfPos(types, pos, radius)
end


--should be much faster than getGameObjectsOfTypesWithinRadiusOfPos Particularly fast for radius of <= 20 meters, even with large sets. Quite a bit slower with large object sets above that
--returns objectID and distance2 in table
function serverGOM:getGameObjectsInSetWithinRadiusOfPos(setIndex, pos, radius) 
    return bridge:getGameObjectsInSetWithinRadiusOfPos(setIndex, pos, radius)
end

function serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(setIndex, pos, radius) --as above speed and accuracy-wise
    return bridge:getGameObjectExistsInSetWithinRadiusOfPos(setIndex, pos, radius)
end


function serverGOM:getAllGameObjectsWithinRadiusOfPos(pos, radius) --as above, much faster if <= 20m. returns objectID and distance2 in table
    return bridge:getAllGameObjectsWithinRadiusOfPos(pos, radius)
end

function serverGOM:getAllGameObjectsWithinRadiusOfNormalizedPos(pos, radius)
    return bridge:getAllGameObjectsWithinRadiusOfNormalizedPos(pos, radius)
end

function serverGOM:getGameObjectsInSetsWithinNormalizedRadiusOfPos(setIndexes, normalizedPos, radius) --as above but radius is calculated as the crow flies (compares normalized pos), and takes an array of indexes
    return bridge:getGameObjectsInSetsWithinNormalizedRadiusOfPos(setIndexes, normalizedPos, radius)
end

function serverGOM:setInfrequentCallbackForGameObjectsInSet(setIndex, timerKey, frequency, func) 
    bridge:setInfrequentCallbackForGameObjectsInSet(setIndex, timerKey, frequency, func)
end

function serverGOM:addProximityCallbackForGameObjectsInSet(setA, setB, proximityRadius, func)
    bridge:addProximityCallbackForGameObjectsInSet(setA, setB, proximityRadius, func)
end

function serverGOM:changeObjectType(objectID, newTypeIndex, keepDegradeInfo)
    local object = serverGOM:getObjectWithID(objectID)

    local objectUnloadedFunctions = objectUnloadedFunctionsByType[object.objectTypeIndex]

    if objectUnloadedFunctions then
        for i,func in ipairs(objectUnloadedFunctions) do
            func(object)
        end
    end
    
    bridge:removeObjectFromAllSets(object.uniqueID)
    bridge:changeObjectType(objectID, newTypeIndex)
    object.objectTypeIndex = newTypeIndex
    
    local sharedState = serverGOM:getSharedState(object, true)
    if not keepDegradeInfo then
        sharedState:remove("degradeReferenceTime")
        sharedState:remove("fractionDegraded")
    end

    
    local objectLoadedFunctions = objectLoadedFunctionsByType[object.objectTypeIndex]

    if objectLoadedFunctions then
        for i,func in ipairs(objectLoadedFunctions) do
            if func(object) then
                return
            end
        end
    end
    
    if sharedState.planStates then
        planManager:addPlanObject(object)
    end

    serverResourceManager:updateResourcesForObject(object)

    serverGOM:testAndUpdateCoveredStatusIfNeeded(object)
end


local function finalizeGameObjectCreation(uniqueID)
    local object = serverGOM:getObjectWithID(uniqueID)

    gameObjectSharedState:setupState(object, object.sharedState)
    
    serverGOM:testAndUpdateCoveredStatusIfNeeded(object)
    updateVertsForObjectIfNeeded(object, false)
    if gameObject.types[object.objectTypeIndex].isStorageArea then
        serverStorageArea:finalizeObjectCreation(object)
    end
end

function serverGOM:createGameObjectWithID(objectID, createTable)
    local uniqueID = bridge:createGameObjectWithID(objectID, createTable)
    local object = serverGOM:getObjectWithID(uniqueID) --check it still exists, as it might be removed immediately when loaded
    if not object then
        return nil
    end

    if uniqueID then
        finalizeGameObjectCreation(uniqueID)
    end

    return uniqueID
end

function serverGOM:createGameObject(createTable)
    --mj:log("serverGOM:createGameObject:", createTable)
    local uniqueID = bridge:createGameObject(createTable)
    local object = serverGOM:getObjectWithID(uniqueID) --check it still exists, as it might be removed immediately when loaded
    if not object then
        return nil
    end
    if uniqueID then
      --  mj:log("uniqueID:", uniqueID)
        finalizeGameObjectCreation(uniqueID)
    end

    return uniqueID
end

function serverGOM:reserveUniqueID()
    return bridge:reserveUniqueID()
end

function serverGOM:callFunctionForObjectsInSet(setName, func)
    bridge:callFunctionForObjectsInSet(setName, func)
end

local frequentCallbacks = {}

function serverGOM:setFrequentCallback(objectID, frequentUpdateFunc)
    frequentCallbacks[objectID] = frequentUpdateFunc
end

function serverGOM:removeFrequentCallback(objectID)
    frequentCallbacks[objectID] = nil
end

function serverGOM:getCloseObjectTemperatureOffset(objectPos)
    local offset = 0
    if serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(serverGOM.objectSets.temperatureIncreasers, objectPos, gameConstants.fireWarmthRadius) then --also change in clientGOM or factor out
        offset = offset + 1
    end
    if serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(serverGOM.objectSets.temperatureDecreasers, objectPos, gameConstants.fireWarmthRadius) then --also change in clientGOM or factor out
        offset = offset - 1
    end
    return offset
end

function serverGOM:getIsCloseToLightSource(objectPos)
    if serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(serverGOM.objectSets.lightEmitters, objectPos, mj:mToP(20.0)) then
        return true
    end
    return false
end


function serverGOM:getHasLight(objectPos, normalizedPos)
    if serverWorld:getHasDaylight(normalizedPos) then
        return true
    end
    if serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(serverGOM.objectSets.lightEmitters, objectPos, mj:mToP(20.0)) then
        return true
    end
    return false
end

function serverGOM:getObjectHasLight(object)
    if serverWorld:getHasDaylight(object.normalizedPos) then
        return true
    end

    if cachedLitObjects then
        if cachedLitObjects[object.uniqueID] ~= nil then
            return cachedLitObjects[object.uniqueID]
        end
    else
        cachedLitObjects = {}
    end

    local result = serverGOM:getGameObjectExistsInSetWithinRadiusOfPos(serverGOM.objectSets.lightEmitters, object.pos, mj:mToP(20.0))
    cachedLitObjects[object.uniqueID] = result

    return result
end

function serverGOM:moveObjectIntoFormationWithOthersOfSameType(object, newPos, rotateToTerrain) --note this could easily push things through walls. Maybe OK for sleds for now, but should really do a ray cast for walls on movement. Also needs to set sled rotation
    --mj:log("serverGOM:moveObjectIntoFormationWithOthersOfSameType")
    local function getRandomPerpVecNormal(pointNormal, uniqueID, seed)
        local randomVecNormalized = normalize(rng:vecForUniqueID(uniqueID, seed))
        return normalize(cross(randomVecNormalized, pointNormal))
    end

    local pos = newPos
    local clampToSeaLevel = true
    --local minDistance2 = mj:mToP(1.5) * mj:mToP(1.5)
    local terrainUpVector = nil
    pos, terrainUpVector = worldHelper:getBelowSurfacePos(pos, 0.1, nil, physicsSets.walkable, clampToSeaLevel, rotateToTerrain)

    for i = 1,4 do
        local foundHit = false
        local objectInfos = serverGOM:getAllGameObjectsWithinRadiusOfPos(pos, mj:mToP(1.5))
        if objectInfos then
            --mj:log("objectInfos:", objectInfos)
            for j,objectInfo in ipairs(objectInfos) do
                local hitObject = allObjects[objectInfo.objectID]
                if hitObject and hitObject.uniqueID ~= object.uniqueID and hitObject.objectTypeIndex == object.objectTypeIndex then
                   -- local prevPos = pos
                    local perpNormal = getRandomPerpVecNormal(object.normalizedPos, object.uniqueID, 2467 + j + i * 32)
                    pos = pos + perpNormal * mj:mToP(2.0 + 2.0 * rng:valueForUniqueID(object.uniqueID, 398 + j + i * 73))
                    pos, terrainUpVector = worldHelper:getBelowSurfacePos(pos, 0.1, nil, physicsSets.walkable, clampToSeaLevel, rotateToTerrain)
                    foundHit = true
                    --mj:log("pos moved:", mj:pToM(length(prevPos - pos)))
                   -- mj:log("foundHit perpNormal:", perpNormal, " object.normalizedPos:", object.normalizedPos)
                    break
                end
            end
        end

        if not foundHit then
            break
        end
    end

    --mj:log("moveObjectIntoFormationWithOthersOfSameType pos altitude:", mj:pToM(mjm.length(pos) - 1.0))
    serverGOM:setPos(object.uniqueID, pos, false)

    if rotateToTerrain and terrainUpVector then
        local leftVector = mat3GetRow(object.rotation, 2)
        local rotation = mat3LookAtInverse(leftVector, terrainUpVector)
        serverGOM:setRotation(object.uniqueID, rotation, false)
    end

end

-- called by engine

function serverGOM:setBridge(bridge_)
    --mj:log("serverGOM:setBridge")
    bridge = bridge_
    if serverWorld then
        serverGOM:init()
    end
end


--local prevSapienUpdateID = nil
--local resultsBySapienID = nil
--local distancesByAssignedObjectID = nil
--local sapienIDsByAssignedObjectID = nil

--local checkPlanCounter = 0

local skipUpdateCounter = 0

function serverGOM:update(dt, worldTime, speedMultiplier)
    doCoveredStatusTests()
    --[[if not prevSapienUpdateID then
        resultsBySapienID = {}
        distancesByAssignedObjectID = {}
        sapienIDsByAssignedObjectID = {}
    end]]

    --[[local resultsBySapienID = {}
    local distancesByAssignedObjectID = {}
    local sapienIDsByAssignedObjectID = {}

    if speedMultiplier > 0.001 then
        for sapienID, sapienObject in pairs(sapienObjects) do
            local resultWithInfo = serverSapien:checkPlans(sapienObject, dt, speedMultiplier)
            if resultWithInfo then
                if resultWithInfo.result then
                    local bestObjectInfo = resultWithInfo.result.bestObjectInfo
                    local valid = true
                    if bestObjectInfo then
                        local assignedObjectID = bestObjectInfo.assignObjectID
                        if assignedObjectID then
                            local currentAssignedDistance = distancesByAssignedObjectID[assignedObjectID]
                            if (not currentAssignedDistance) or bestObjectInfo.assignObjectDistance < currentAssignedDistance then
                                if sapienIDsByAssignedObjectID[assignedObjectID] then
                                    --disabled--mj:objectLog(sapienIDsByAssignedObjectID[assignedObjectID], "another sapien got a closer result:", sapienObject.uniqueID, "my distance:", mj:pToM(currentAssignedDistance), " their distance:", mj:pToM(bestObjectInfo.assignObjectDistance), " bestObjectInfo:", bestObjectInfo, " assignedObjectID:", assignedObjectID)
                                    resultsBySapienID[sapienIDsByAssignedObjectID[assignedObjectID] ] = nil
                                end
                                distancesByAssignedObjectID[assignedObjectID] = bestObjectInfo.assignObjectDistance
                                sapienIDsByAssignedObjectID[assignedObjectID] = sapienID

                                --disabled--mj:objectLog(sapienID, "assigning my distance:", mj:pToM(bestObjectInfo.assignObjectDistance), " to object id:", assignedObjectID)
                            else
                                valid = false
                            end
                        end
                    end

                    if valid then
                        resultsBySapienID[sapienID] = resultWithInfo.result
                    end
                end
            end
        end

        for sapienID, object in pairs(sapienObjects) do
            serverSapien:update(object, dt, speedMultiplier, resultsBySapienID[object.uniqueID])
        end
    end]]
    
    serverTribe:updateSapienProximityCallbacksIfNeeded()

    skipUpdateCounter = skipUpdateCounter + 1
    if skipUpdateCounter > 2 then
        skipUpdateCounter = 0
    end
    local checkPlansIndex = 0
    for sapienID, object in pairs(sapienObjects) do
        if checkPlansIndex == skipUpdateCounter then
            local resultWithInfo = serverSapien:checkPlans(object, dt, speedMultiplier)
        -- --disabled--mj:objectLog(object.uniqueID, resultWithInfo)
            serverSapien:update(object, dt, speedMultiplier, resultWithInfo and resultWithInfo.result)
        else
            serverSapien:update(object, dt, speedMultiplier, nil)
        end

        checkPlansIndex = checkPlansIndex + 1
        if checkPlansIndex > 2 then
            checkPlansIndex = 0
        end
    end


    for objectID, callbackFunc in pairs(frequentCallbacks) do
        callbackFunc(allObjects[objectID], dt, speedMultiplier)
    end

    --mj:log("objectsThatNeedToUpdateNearByObservers:", objectsThatNeedToUpdateNearByObservers)
    for objectID, sets in pairs(objectsThatNeedToUpdateNearByObservers) do
        local object = allObjects[objectID]
        if object then
           -- mj:log("calling doUpdateNearByObjectObservers:", object.uniqueID)
            doUpdateNearByObjectObservers(object, sets)
        end
    end
    objectsThatNeedToUpdateNearByObservers = {}
   -- planManager:update(dt)
end

local inaccessibleTimerIDSByObjectID = {}

local function addInaccessibleTimer(object)
    if not inaccessibleTimerIDSByObjectID[object.uniqueID] then
        inaccessibleTimerIDSByObjectID[object.uniqueID] = serverGOM:addObjectCallbackTimerForWorldTime(object.uniqueID, object.sharedState.lastInaccessibleTime + 400.0, function(objectID)
            local object_ = serverGOM:getObjectWithID(objectID)
            if object_ then
                serverGOM:removeInaccessible(object_)
            end
        end)
    end
end

function serverGOM:removeInaccessible(object)
    if object.sharedState then
        local inaccessibleCount = object.sharedState.inaccessibleCount
        if inaccessibleCount then
            object.sharedState:remove("inaccessibleCount")
            object.sharedState:remove("lastInaccessibleTime")
            if inaccessibleCount >= inaccessibleCheckCount then
                if inaccessibleTimerIDSByObjectID[object.uniqueID] then
                    serverGOM:removeObjectCallbackTimerWithID(object.uniqueID, inaccessibleTimerIDSByObjectID[object.uniqueID])
                    inaccessibleTimerIDSByObjectID[object.uniqueID] = nil
                end
                serverResourceManager:updateResourcesForObject(object)
                if gameObject.types[object.objectTypeIndex].isStorageArea then
                    serverStorageArea:doChecksForAvailibilityChange(object)
                    planManager:storageAreaAllowItemUseChanged(object)
                    serverResourceManager:storageAreaAllowItemUseChanged(object)
                end
                planManager:updateAnyPlanStatesForPlanObjectAccessibilityChange(object, false)
                serverGOM:removeObjectFromSet(object, serverGOM.objectSets.inaccessible)
            end
        end
    end
end

local minInaccessibleShiftDistance = mj:mToP(0.5)
local minInaccessibleShiftDistance2 = minInaccessibleShiftDistance * minInaccessibleShiftDistance

function serverGOM:setInaccessible(object)

    if object.dynamicPhysics or object.objectTypeIndex == gameObject.types.sapien.index or gameObject.types[object.objectTypeIndex].mobTypeIndex then
        return --don't do this for anything that moves
    end

    local inaccessibleCount = 1
    if object.sharedState.inaccessibleCount then
        if object.sharedState.inaccessibleCount >= inaccessibleCheckCount then
            return
        end
        inaccessibleCount = object.sharedState.inaccessibleCount + 1
    end
    
    object.sharedState:set("inaccessibleCount", inaccessibleCount)

    if inaccessibleCount >= inaccessibleCheckCount then
        local shifted = false
        if gameObject.types[object.objectTypeIndex].resourceTypeIndex then
            local clampToSeaLevel = false
            local shiftedPos = worldHelper:getBelowSurfacePos(object.pos + rng:randomVec() * mj:mToP(4.0), 0.5, physicsSets.walkable, object.uniqueID, nil, clampToSeaLevel)
            if length2(shiftedPos - object.pos) > minInaccessibleShiftDistance2 then
                mj:warn("shifting inaccessible object:", object.uniqueID)
                serverGOM:setPos(object.uniqueID, shiftedPos, true)
                serverGOM:saveObject(object.uniqueID)
                shifted = true
                serverGOM:removeInaccessible(object)
            end
        end
        if not shifted then
            local currentTime = serverWorld:getWorldTime()
            object.sharedState:set("lastInaccessibleTime", currentTime)
            addInaccessibleTimer(object)
            serverResourceManager:updateResourcesForObject(object)
            if gameObject.types[object.objectTypeIndex].isStorageArea then
                serverStorageArea:doChecksForAvailibilityChange(object)
                planManager:storageAreaAllowItemUseChanged(object)
                serverResourceManager:storageAreaAllowItemUseChanged(object)
            end
            planManager:updateAnyPlanStatesForPlanObjectAccessibilityChange(object, true)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.inaccessible)
        end
    end
end

function serverGOM:objectIsInaccessible(object)
    if object.sharedState and object.sharedState.inaccessibleCount and object.sharedState.inaccessibleCount >= inaccessibleCheckCount then
        return true
    end
    return false
end

--local debugInfo = {}

function serverGOM:gameObjectWasLoaded(object, subdivLevel, terrainVariations)

    if not gameObject.types[object.objectTypeIndex] then
        mj:error("No object type:", object, " object.objectTypeIndex:", object.objectTypeIndex, " object sharedState:", object.sharedState)
        mj:warn("This is likely due to an issue with the typeMaps file, and can occur if a world save is opened by an earlier version. You can try restoring one of the typeMap_{NUMBER} files, which are backups.")
        error()
    end

    --mj:log("serverGOM:gameObjectWasLoaded")
   --mj:log("load object:", object.uniqueID)
    allObjects[object.uniqueID] = object
    if object.objectTypeIndex == gameObject.types.sapien.index then
        sapienObjects[object.uniqueID] = object
        local sapiensByThisTribe = serverGOM.sapienObjectsByTribe[object.sharedState.tribeID]
        if not sapiensByThisTribe then
            sapiensByThisTribe = {}
            serverGOM.sapienObjectsByTribe[object.sharedState.tribeID] = sapiensByThisTribe
        end
        sapiensByThisTribe[object.uniqueID] = object
        serverGOM.loadedSapienCountsByTribe[object.sharedState.tribeID] = (serverGOM.loadedSapienCountsByTribe[object.sharedState.tribeID] or 0) + 1
        serverGOM.totalLoadedSapienCount = serverGOM.totalLoadedSapienCount + 1
    end

    local objectLoadedFunctions = objectLoadedFunctionsByType[object.objectTypeIndex]

    --[[if object.sharedState then
        local debugInfoForObjectType = debugInfo[1]
        if not debugInfoForObjectType then
            debugInfoForObjectType = {
                countsByKey = {},
                currentCount = 0,
            }
            debugInfo[1] = debugInfoForObjectType
        end

        debugInfoForObjectType.currentCount = mj:getTableKeyCountRecursive(object.sharedState, debugInfoForObjectType.currentCount, debugInfoForObjectType.countsByKey)
    end]]

    local stateHasBeenSetup = false
    if object.sharedState then
        gameObjectSharedState:setupState(object, object.sharedState)
        stateHasBeenSetup = true
        
        if object.sharedState.inaccessibleCount and object.sharedState.inaccessibleCount >= inaccessibleCheckCount then
            if object.sharedState.lastInaccessibleTime and (serverWorld:getWorldTime() - object.sharedState.lastInaccessibleTime < 400.0) then
                addInaccessibleTimer(object)
                serverGOM:addObjectToSet(object, serverGOM.objectSets.inaccessible)
            else
                object.sharedState:remove("inaccessibleCount")
                object.sharedState:remove("lastInaccessibleTime")
            end
        end
    end

    object.modelIndex = gameObject:modelIndexForGameObjectAndLevel(object, subdivLevel, terrainVariations)
    if object.modelIndex then
        bridge:setModelIndex(object.uniqueID, object.modelIndex)
    end
    

    if objectLoadedFunctions then
        for i,func in ipairs(objectLoadedFunctions) do
            if func(object) then
                return
            end
        end
    end

    if object.sharedState and not stateHasBeenSetup then
        gameObjectSharedState:setupState(object, object.sharedState)
    end

    if object.sharedState and object.sharedState.planStates then
        --mj:log("load plan object:", object.uniqueID, " type:", gameObject.types[object.objectTypeIndex].key, " altitude:", mj:pToM((length(object.pos) - 1.0)))
        planManager:addPlanObject(object)
    end

    if gameObject.types[object.objectTypeIndex].mayOfferResources then
        serverResourceManager:addAnyResourceForObject(object, false, nil)
    end
    serverGameObjectSharedState:removeAnyDiffStates(object)

    if object.objectTypeIndex == gameObject.types.temporaryCraftArea.index then --check for any broken temporaryCraftAreas, the bug that created them should have been fixed in 0.5.0.54
        if not object.sharedState.planStates then
            serverGOM:removeGameObject(object.uniqueID)
            return
        end 
    end
end

function serverGOM:printDebugInfo()
    --[[local countsByKey = debugInfo[1].countsByKey
    local orderedKeys = {}
    for k,v in pairs(countsByKey) do
        table.insert(orderedKeys, k)
    end

    local function sortByCount(a,b)
        return countsByKey[a] < countsByKey[b]
    end

    table.sort(orderedKeys, sortByCount)
    for i,k in ipairs(orderedKeys) do
        mj:log(k, ": ", countsByKey[k])
    end]]
end

function serverGOM:gameObjectWillBeUnloaded(objectID)
    --mj:log("unload object:", objectID)
    
    local object = allObjects[objectID]
    if not object then
        return
    end
    --object.isBeingUnloaded = true
    if gameObject.types[object.objectTypeIndex].mayOfferResources then
        serverResourceManager:removeAnyResourceForObject(object)
    end
    inaccessibleTimerIDSByObjectID[object.uniqueID] = nil

    if object.sharedState and object.sharedState.planStates then
        planManager:removePlanObject(object)
    end

    --planManager:debugCheckAllPlansGone(object)
    
    local objectUnloadedFunctions = objectUnloadedFunctionsByType[object.objectTypeIndex]

    if objectUnloadedFunctions then
       -- mj:log("objectUnloadedFunctions")
        for i,func in ipairs(objectUnloadedFunctions) do
            func(object)
        end
    end

    if object.objectTypeIndex == gameObject.types.sapien.index then
        sapienObjects[object.uniqueID] = nil
        local sapiensByThisTribe = serverGOM.sapienObjectsByTribe[object.sharedState.tribeID]
        if sapiensByThisTribe then
            sapiensByThisTribe[object.uniqueID] = nil
            serverGOM.loadedSapienCountsByTribe[object.sharedState.tribeID] = (serverGOM.loadedSapienCountsByTribe[object.sharedState.tribeID] or 1) - 1
            serverGOM.totalLoadedSapienCount = serverGOM.totalLoadedSapienCount - 1
        end
    end
    frequentCallbacks[object.uniqueID] = nil
    allObjects[object.uniqueID] = nil
    serverGameObjectSharedState:removeAnyDiffStates(object)
end

function serverGOM:sapienTribeChanged(sapien, previousTribeID, newTribeID)
    local prevSapiensByThisTribe = serverGOM.sapienObjectsByTribe[previousTribeID]
    if prevSapiensByThisTribe then
        prevSapiensByThisTribe[sapien.uniqueID] = nil
        serverGOM.loadedSapienCountsByTribe[previousTribeID] = (serverGOM.loadedSapienCountsByTribe[previousTribeID] or 1) - 1
    end
    local newSapiensByThisTribe = serverGOM.sapienObjectsByTribe[newTribeID]
    if not newSapiensByThisTribe then
        newSapiensByThisTribe = {}
        serverGOM.sapienObjectsByTribe[newTribeID] = newSapiensByThisTribe
    end
    serverGOM.loadedSapienCountsByTribe[newTribeID] = (serverGOM.loadedSapienCountsByTribe[newTribeID] or 0) + 1
    newSapiensByThisTribe[sapien.uniqueID] = sapien
    
    serverWorld:updateFollowerCount(previousTribeID)
    serverWorld:updateFollowerCount(newTribeID)
end


-- NOTE! don't use these anchor methods directly, use server/anchor.lua
function serverGOM:setAnchorForObjectWithID(uniqueID, isPadded, anchorLevel, subdivLevel, anchorLevelBOrNil, subdivLevelBOrNil)
    if anchorLevelBOrNil then
        bridge:setDualAnchorForObjectWithID(uniqueID, isPadded, anchorLevel, subdivLevel, anchorLevelBOrNil, subdivLevelBOrNil)
    else
        bridge:setAnchorForObjectWithID(uniqueID, isPadded, anchorLevel, subdivLevel)
    end
end

-- NOTE! don't use these anchor methods directly, use server/anchor.lua
function serverGOM:removeAnchorForObjectWithID(objectID)
    bridge:removeAnchorForObjectWithID(objectID)
end

function serverGOM:objectWithIDHasAnchor(objectID)
    return bridge:objectWithIDHasAnchor(objectID)
end


function serverGOM:setAlwaysSendToClientForObjectWithID(objectID, clientID, alwaysSend) -- when alwaysSend is set, update data will be sent to this client even if the client's camera position is far away so the object wouldn't normally be loaded client-side
    if clientID and clientID ~= mj.serverClientID then
        bridge:setAlwaysSendForObjectWithID(objectID, clientID, alwaysSend)
    end
end

function serverGOM:setAlwaysSendToClientWithTribeIDForObjectWithID(objectID, tribeID, alwaysSend) -- when alwaysSend is set, update data will be sent to this client even if the client's camera position is far away so the object wouldn't normally be loaded client-side
    serverGOM:setAlwaysSendToClientForObjectWithID(objectID, serverWorld:clientIDForTribeID(tribeID), alwaysSend)
end

function serverGOM:setAlwaysSendToOwnerClientForObjectWithID(objectID, alwaysSend)
    local object = serverGOM:getObjectWithID(objectID)
    local tribeID = object.sharedState.tribeID
    if tribeID then
        serverGOM:setAlwaysSendToClientWithTribeIDForObjectWithID(objectID, tribeID, alwaysSend)
    end
end


function serverGOM:clientHasOwnershipPermissions(clientID, object)
    local sharedState = object.sharedState
    if sharedState.tribeID then
        local objectClientID = serverWorld:clientIDForTribeID(sharedState.tribeID)
        if objectClientID and objectClientID ~= clientID then
            return false
        end
    end
    return true
end

function serverGOM:getObjectIfLoadedAndHasOwnershipPermissions(clientID, objectID)
    local object = serverGOM:getObjectWithID(objectID)
    if not object then
        mj:warn("Object not loaded:", objectID)
        return nil
    end

    if not serverGOM:clientHasOwnershipPermissions(clientID, object) then
        mj:warn("Client attempted to run protected function but didn't own object:", objectID, " clientID:", clientID)
        return nil
    end

    return object
end

function serverGOM:changeObjectNameIfAllowed(clientID, objectID, newName)
    local object = serverGOM:getObjectIfLoadedAndHasOwnershipPermissions(clientID, objectID)
    if object then
        local sharedState = object.sharedState
        sharedState:set("name", newName)

        if sharedState.assignedBedID then
            
            local bed = serverGOM:getObjectWithID(sharedState.assignedBedID)
            if not bed then
                terrain:loadArea(sharedState.assignedBedPos)
                bed = serverGOM:getObjectWithID(sharedState.assignedBedID)
            end
            if bed then
                bed.sharedState:set("assignedBedSapienName", newName)
            end
        end
    else
        mj:warn("Failed to change name")
    end
end

function serverGOM:getRelationshipsForClientRequest(sapienID)
    local sapien = serverGOM:getObjectWithID(sapienID)
    if not sapien then
        mj:warn("Object not loaded for getRelationshipsForClientRequest:", sapienID)
        return
    end
    if sapien.lazyPrivateState then
        return sapien.lazyPrivateState.relationships
    end
end

function serverGOM:setRotation(objectID, rotation, updatePhysics)
    local object = allObjects[objectID]
    if object then
        object.rotation = rotation
        if updatePhysics then
            bridge:updateMatrix(objectID, object.pos, rotation)
        else
            bridge:setRotation(objectID, rotation)
        end
    end
end

function serverGOM:setPos(objectID, pos, updatePhysics)
    local object = allObjects[objectID]
    if object then
        object.pos = pos
        object.normalizedPos = normalize(pos)
        if updatePhysics then
            bridge:updateMatrix(objectID, pos, object.rotation)
        else
            bridge:setPos(objectID, pos)
        end
        serverSeat:updateNodesForSeatObjectPosChange(object)
    end
end

function serverGOM:setSubModelForKey(
    objectID, 
    subModelKey,
	placeholderKeyOrNil,
	modelIndex,
	scale,
	renderType,
	translation,
	rotation,
	addToPhysics,
	subModelSubModelInfosOrNil)
    
    bridge:setSubModelForKey(
        objectID, 
        subModelKey,
        placeholderKeyOrNil,
        modelIndex,
        scale,
        renderType,
        translation,
        rotation,
        addToPhysics,
        subModelSubModelInfosOrNil)

end

function serverGOM:applyImpulse(objectID, impulseVec) --impulse is in kg meters/s, but everything has mass of 1 for now
    bridge:applyImpulse(objectID, impulseVec)
end

function serverGOM:getLinearVelocity(objectID)
    return bridge:getLinearVelocity(objectID)
end

function serverGOM:getAngularVelocity(objectID)
    return bridge:getAngularVelocity(objectID)
end

function serverGOM:setLinearVelocity(objectID, vel)
    bridge:setLinearVelocity(objectID, vel)
end

function serverGOM:setAngularVelocity(objectID, velA)
    bridge:setAngularVelocity(objectID, velA)
end

function serverGOM:setDynamicPhysics(objectID, dynamicPhysics)
    local object = allObjects[objectID]
    if object then
        object.dynamicPhysics = dynamicPhysics
        bridge:setDynamicPhysics(objectID, dynamicPhysics)
    end
end

function serverGOM:isStored(objectID)
    return bridge:isStored(objectID)
end

function serverGOM:getCloseTerrainVertID(objectID)
    return bridge:getCloseTerrainVertID(objectID)
end

function serverGOM:transientObjectsWereInspected(objectIDs) --only called for objectTypes that have notifyServerOnTransientInspection set, eg. trees that only fruit every 10 years
    for i, objectID in ipairs(objectIDs) do
        local object = serverGOM:getObjectWithID(objectID)
        if object then
            local objectTransientInspectionFunctions = objectTransientInspectionFunctionsByType[object.objectTypeIndex]

            if objectTransientInspectionFunctions then
                for j,func in ipairs(objectTransientInspectionFunctions) do
                    func(object)
                end
            end
        end
    end
end

-- lazy state is saved lazily. This means it will get saved some time in the next 10 seconds or so. 
-- If the game crashes, this state might not be saved so could be inconsistent with sharedState and privateState
-- So only use this state for stuff that doesn't have to be totally accurate
function serverGOM:saveLazyPrivateStateForObjectWithID(objectID) 
    bridge:saveLazyPrivateStateForObjectWithID(objectID)
end

function serverGOM:setObjectDetailLevelChangedCallbackFunctionForObjectTypes(objectTypes, func) --untested
    for i,objectType in ipairs(objectTypes) do
        bridge:setObjectDetailLevelChangedCallbackFunctionForObjectType(objectType, func)
    end
end

function serverGOM:preventFutureTransientObjectsNearObject(objectID)
    bridge:preventFutureTransientObjectsNearObject(objectID)
end


function serverGOM:setDebugObject(objectID)
    bridge:setDebugObject(objectID)
end

return serverGOM