
local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"
local rng = mjrequire "common/randomNumberGenerator"
local weather = mjrequire "common/weather"

local serverWeather = mjrequire "server/serverWeather"
local terrain = mjrequire "server/serverTerrain"
--local fuel = mjrequire "common/fuel"

local serverTorch = {}

local serverGOM = nil
local planManager = nil
local serverWorld = nil

local burnSpeed = 0.0005

local function litUpdate(objectID, dt, speedMultiplier)
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
        end

        if not foundFuel then
            serverTorch:setLit(object, false, nil)
            planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
        else
            
            if (not sharedState.covered) then
                if serverWeather:getIsDamagingWindStormOccuring() then 
                    if rng:randomInteger(5) == 1 then
                        serverTorch:setLit(object, false, nil)
                        planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
                    end
                else
                    if rng:randomInteger(25) == 1 then
                        local rainfallValues = terrain:getRainfallForNormalizedPoint(object.normalizedPos)
                        local currentRainfall = weather:getRainfall(rainfallValues, object.normalizedPos, serverWorld:getWorldTime(), serverWorld.yearSpeed)
                        local rainSnow = weather:getRainSnowCombinedPrecipitation(currentRainfall)
                        if rainSnow > 0.8 then
                            serverTorch:setLit(object, false, nil)
                            planManager:addStandardPlan(sharedState.tribeID, plan.types.light.index, objectID, nil, nil, nil, nil, nil, nil)
                        end
                    end
                end
            end
        end
    end
end

function serverTorch:init(serverGOM_, serverWorld_, planManager_)
    serverGOM = serverGOM_
    planManager = planManager_
    serverWorld = serverWorld_

    serverGOM:addObjectLoadedFunctionForTypes({ gameObject.types.torch.index }, function(object)
        
        if object.sharedState.isLit then
            serverGOM:addObjectToSet(object, serverGOM.objectSets.litTorches)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.maintenance)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.lightEmitters)
            serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)

            object.sharedState:set("requiresMaintenanceByTribe", object.sharedState.tribeID, true)
        end

        serverGOM:addObjectToSet(object, serverGOM.objectSets.coveredStatusObservers)

        if not object.sharedState.fuelState then
            local fuelState = {}
            for i=1,2 do
                table.insert(fuelState, {
                    fuel = 0
                })
            end
            object.sharedState:set("fuelState", fuelState)
        end
        return false
        
    end)
    
    serverGOM:setInfrequentCallbackForGameObjectsInSet(serverGOM.objectSets.litTorches, "update", 20.0, litUpdate) 
end

function serverTorch:setLit(object, lit, sapienTribeIDOrNil)
    if (lit and not object.sharedState.isLit) or (not lit and object.sharedState.isLit) then
        if lit then
            object.sharedState:set("isLit", lit)
        else
            object.sharedState:remove("isLit")
        end
        if lit then
            serverGOM:addObjectToSet(object, serverGOM.objectSets.litTorches)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.maintenance)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.lightEmitters)
            serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
            object.sharedState:set("requiresMaintenanceByTribe", object.sharedState.tribeID, true)
        else
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets.litTorches)
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets.maintenance)
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets.lightEmitters)
            serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
            object.sharedState:remove("requiresMaintenanceByTribe")
        end
    end
end

return serverTorch