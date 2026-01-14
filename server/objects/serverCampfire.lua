
local gameObject = mjrequire "common/gameObject"
--local craftAreaGroup = mjrequire "common/craftAreaGroup"
local plan = mjrequire "common/plan"
local gameConstants = mjrequire "common/gameConstants"
local rng = mjrequire "common/randomNumberGenerator"
local weather = mjrequire "common/weather"

local anchor = mjrequire "server/anchor"
local serverCraftArea = mjrequire "server/serverCraftArea"
local serverTutorialState = mjrequire "server/serverTutorialState"
local terrain = mjrequire "server/serverTerrain"
local serverWeather = mjrequire "server/serverWeather"
--local fuel = mjrequire "common/fuel"

local serverCampfire = {}

local serverGOM = nil
local planManager = nil
local serverWorld = nil

local burnSpeed = 0.01
local fuelHoldCount = 6 --if you change this, you will need to migrate existing below

local function litCampfireUpdate(objectID, dt, speedMultiplier)
    --mj:log("litCampfireUpdate:", objectID)
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
            serverCampfire:setLit(object, false, nil)
            planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
        else
            local vertID = serverGOM:getCloseTerrainVertID(objectID)
            if vertID then
                terrain:removeSingleSnowNear(vertID, object.normalizedPos, gameConstants.fireWarmthRadius)
            end
            
            if (not sharedState.covered) then
                if serverWeather:getIsDamagingWindStormOccuring() then 
                    if rng:randomInteger(10) == 1 then
                        serverCampfire:setLit(object, false, nil)
                        planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
                    end
                else
                    if rng:randomInteger(50) == 1 then
                        local rainfallValues = terrain:getRainfallForNormalizedPoint(object.normalizedPos)
                        local currentRainfall = weather:getRainfall(rainfallValues, object.normalizedPos, serverWorld:getWorldTime(), serverWorld.yearSpeed)
                        local rainSnow = weather:getRainSnowCombinedPrecipitation(currentRainfall)
                        if rainSnow > 0.8 then
                            serverCampfire:setLit(object, false, nil)
                            planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
                        end
                    end
                end
            end
        end


    end
end

local function updateLitEffects(campfire)
    if campfire.sharedState.isLit then
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.interestingToLookAt)
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.litCampfires)
        serverGOM:removeObjectFromSet(campfire, serverGOM.objectSets.unlitCampfires)
        
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.maintenance)
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.temperatureIncreasers)
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.lightEmitters)
        serverGOM:updateNearByObjectObserversForLightChange(campfire.uniqueID)
        
        campfire.sharedState:set("requiresMaintenanceByTribe", campfire.sharedState.tribeID, true)
        campfire.sharedState:set("hasAsh", true)
        serverCraftArea:addCraftArea(campfire)
    else
        serverGOM:removeObjectFromSet(campfire, serverGOM.objectSets.interestingToLookAt)
        serverGOM:removeObjectFromSet(campfire, serverGOM.objectSets.litCampfires)
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.unlitCampfires)
        serverGOM:removeObjectFromSet(campfire, serverGOM.objectSets.maintenance)
        serverGOM:removeObjectFromSet(campfire, serverGOM.objectSets.temperatureIncreasers)
        serverGOM:removeObjectFromSet(campfire, serverGOM.objectSets.lightEmitters)
        serverGOM:updateNearByObjectObserversForLightChange(campfire.uniqueID)
        campfire.sharedState:remove("requiresMaintenanceByTribe")
        serverCraftArea:removeCraftArea(campfire)
    end
end

function serverCampfire:init(serverGOM_, serverWorld_, planManager_)
    serverGOM = serverGOM_
    planManager = planManager_
    serverWorld = serverWorld_

    serverGOM:addObjectLoadedFunctionForTypes({ gameObject.types.campfire.index }, function(campfire)

        if campfire.sharedState.requiresMaintenance then --migrate to 0.5
            campfire.sharedState:set("requiresMaintenanceByTribe", campfire.sharedState.tribeID, true)
            campfire.sharedState:remove("requiresMaintenance")
        end

        updateLitEffects(campfire)

        if not campfire.sharedState.fuelState then
            local fuelState = {}
            for i=1,fuelHoldCount do
                table.insert(fuelState, {
                    fuel = 0
                })
            end
            campfire.sharedState:set("fuelState", fuelState)
        end

        --serverGOM:addObjectToSet(campfire, serverGOM.objectSets.logistics)
        anchor:addAnchor(campfire.uniqueID, anchor.types.craftArea.index, campfire.sharedState.tribeID)
        serverGOM:addObjectToSet(campfire, serverGOM.objectSets.coveredStatusObservers)
        return false
        
    end)

    

    serverGOM:addObjectUnloadedFunctionForType(gameObject.types.campfire.index, function(campfire)
        serverCraftArea:removeCraftArea(campfire)
        anchor:anchorObjectUnloaded(campfire.uniqueID)
    end)
    
    serverGOM:setInfrequentCallbackForGameObjectsInSet(serverGOM.objectSets.litCampfires, "update", 10.0, litCampfireUpdate) 
end

function serverCampfire:setLit(campfire, lit, sapienTribeID)
    if campfire.sharedState.isLit ~= lit then
        if lit then
            campfire.sharedState:set("isLit", lit)
            if sapienTribeID then
                serverTutorialState:setLitCampfireComplete(sapienTribeID)
            end
        else
            campfire.sharedState:remove("isLit")
        end
        
        updateLitEffects(campfire)
        planManager:updatePlansForCraftFireLitStateChange(campfire)
    end
end

return serverCampfire