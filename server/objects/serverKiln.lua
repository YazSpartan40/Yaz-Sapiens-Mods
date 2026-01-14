
local gameObject = mjrequire "common/gameObject"
local serverCraftArea = mjrequire "server/serverCraftArea"
--local craftAreaGroup = mjrequire "common/craftAreaGroup"
local plan = mjrequire "common/plan"
local gameConstants = mjrequire "common/gameConstants"
local anchor = mjrequire "server/anchor"
local terrain = mjrequire "server/serverTerrain"
--local serverTutorialState = mjrequire "server/serverTutorialState"
--local fuel = mjrequire "common/fuel"

local serverKiln = {}

local serverGOM = nil
local planManager = nil

local burnSpeed = 0.02
local fuelHoldCount = 10 --if you change this, you will need to migrate existing below

local function litKilnUpdate(objectID, dt, speedMultiplier)
    local object = serverGOM:getObjectWithID(objectID)
    if object then
        local sharedState = object.sharedState
        local fuelState = sharedState.fuelState
        
        local privateState = serverGOM:getPrivateState(object)
        if (not privateState.coveredStatusReset) then --added 0.4, only to update existing objects which hadn't previously been coveredStatusObservers. Done here as world isn't fully loaded on object load.
            serverGOM:testAndUpdateCoveredStatusIfNeeded(object)
            privateState.coveredStatusReset = true
        end

        local foundFuel = false
        if fuelState then
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel > 0.0 then
                    local newFuel = fuelInfo.fuel - dt * speedMultiplier * burnSpeed
                    sharedState:set("fuelState", i, "fuel", newFuel)
                    foundFuel = true
                    break
                end
            end
        end

        if not foundFuel then
            serverKiln:setLit(object, false, nil)
            planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
        else
            local vertID = serverGOM:getCloseTerrainVertID(objectID)
            if vertID then
                terrain:removeSingleSnowNear(vertID, object.normalizedPos, gameConstants.fireWarmthRadius)
            end
        end
    end
end

local function updateLitEffects(object)
    if object.sharedState.isLit then
        serverGOM:addObjectToSet(object, serverGOM.objectSets.interestingToLookAt)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.litKilns)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.maintenance)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.temperatureIncreasers)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.lightEmitters)
        serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
        
        object.sharedState:set("requiresMaintenanceByTribe", object.sharedState.tribeID, true)
        object.sharedState:set("hasAsh", true)
        serverCraftArea:addCraftArea(object)
    else
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.interestingToLookAt)
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.litKilns)
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.maintenance)
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.temperatureIncreasers)
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.lightEmitters)
        serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
        object.sharedState:remove("requiresMaintenanceByTribe")
        serverCraftArea:removeCraftArea(object)
    end
end

function serverKiln:init(serverGOM_, serverWorld_, planManager_)
    serverGOM = serverGOM_
    planManager = planManager_
   -- serverWorld = serverWorld_

    serverGOM:addObjectLoadedFunctionForTypes({ gameObject.types.brickKiln.index }, function(object)

        if object.sharedState.requiresMaintenance then --migrate to 0.5
            object.sharedState:set("requiresMaintenanceByTribe", object.sharedState.tribeID, true)
            object.sharedState:remove("requiresMaintenance")
        end
        
        updateLitEffects(object)

        if not object.sharedState.fuelState then
            local fuelState = {}
            for i=1,fuelHoldCount do
                table.insert(fuelState, {
                    fuel = 0
                })
            end
            object.sharedState:set("fuelState", fuelState)
        end

        anchor:addAnchor(object.uniqueID, anchor.types.craftArea.index, object.sharedState.tribeID)
        serverGOM:addObjectToSet(object, serverGOM.objectSets.coveredStatusObservers)
        
        return false
    end)

    

    serverGOM:addObjectUnloadedFunctionForType(gameObject.types.brickKiln.index, function(object)
        anchor:anchorObjectUnloaded(object.uniqueID)
    end)
    
    serverGOM:setInfrequentCallbackForGameObjectsInSet(serverGOM.objectSets.litKilns, "update", 20.0, litKilnUpdate) 
end

function serverKiln:setLit(object, lit, sapienTribeID)
    if object.sharedState.isLit ~= lit then
        if lit then
            object.sharedState:set("isLit", lit)
        else
            object.sharedState:remove("isLit")
        end
        
        updateLitEffects(object)
        planManager:updatePlansForCraftFireLitStateChange(object)
    end
end

return serverKiln