
local gameObject = mjrequire "common/gameObject"
--local fuel = mjrequire "common/fuel"

local serverLitObject = {}

local serverGOM = nil

local burnSpeed = 0.01

local function litObjectUpdate(objectID, dt, speedMultiplier)
    local object = serverGOM:getObjectWithID(objectID)
    if object then
        local sharedState = object.sharedState
        local fuelState = sharedState.fuelState

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
            serverGOM:removeGameObject(object.uniqueID)
            --serverLitObject:setLit(object, false)
        end
    end
end

function serverLitObject:init(serverGOM_, serverWorld_, planManager_)
    serverGOM = serverGOM_
    --planManager = planManager_
   -- serverWorld = serverWorld_

    serverGOM:addObjectLoadedFunctionForTypes(gameObject.burntObjectTypes, function(object)
        if object.sharedState.isLit then
            serverGOM:addObjectToSet(object, serverGOM.objectSets.interestingToLookAt)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.litObjects)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.lightEmitters)
            serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
        end
        return false
    end)
    
    serverGOM:setInfrequentCallbackForGameObjectsInSet(serverGOM.objectSets.litObjects, "update", 5.0, litObjectUpdate) 
end

function serverLitObject:setLit(object, lit)
    if not gameObject.types[object.objectTypeIndex].isBurntObject then
        mj:error("Attempting to set non-burnt object to lit:", object.uniqueID)
        return
    end
    if (lit and not object.sharedState.isLit) or (not lit and object.sharedState.isLit) then
        if lit then
            object.sharedState:set("isLit", lit)
        else
            object.sharedState:remove("isLit")
        end
        if lit then
            serverGOM:addObjectToSet(object, serverGOM.objectSets.interestingToLookAt)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.litObjects)
            serverGOM:addObjectToSet(object, serverGOM.objectSets.lightEmitters)
            serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
            
            if not object.sharedState.fuelState then
                local fuelState = {
                    {
                        fuel = 1.0 --todo more fuel for logs etc
                    }
                }
                object.sharedState:set("fuelState", fuelState)
            end
        else
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets.interestingToLookAt)
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets.litObjects)
            serverGOM:removeObjectFromSet(object, serverGOM.objectSets.lightEmitters)
            serverGOM:updateNearByObjectObserversForLightChange(object.uniqueID)
        end
    end
end

return serverLitObject