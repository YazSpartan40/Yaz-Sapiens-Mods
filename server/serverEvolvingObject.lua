
local evolvingObject = mjrequire "common/evolvingObject"
local storage = mjrequire "common/storage"
local plan = mjrequire "common/plan"
local gameObject = mjrequire "common/gameObject"
local rng = mjrequire "common/randomNumberGenerator"

local serverResourceManager = mjrequire "server/serverResourceManager"

local serverEvolvingObject = {}

local serverGOM = nil
local serverWorld = nil
local serverStorageArea = nil

function serverEvolvingObject:init(serverGOM_, serverWorld_, serverStorageArea_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    serverStorageArea = serverStorageArea_

    evolvingObject:init(serverWorld:getDayLength(), serverWorld:getYearLength())
    serverEvolvingObject:finalize()
end

local callBackInfosByObjectID = {}


function serverEvolvingObject:addCallbackForStorageAreaIfNeeded(storageAreaObjectID)
    --mj:log("serverEvolvingObject:addCallbackForStorageAreaIfNeeded:", storageAreaObjectID)
    local storageObject = serverGOM:getObjectWithID(storageAreaObjectID)
    local sharedState = storageObject.sharedState

    local needsToUpdate = false
    
    local objects = serverGOM:getSharedState(storageObject, false, "inventory", "objects")
    if objects then
        
        local earliestCallbackTime = nil

        local countsByObjectType = sharedState.inventory.countsByObjectType
        for i = #objects, 1, -1 do
            local objectInfo = objects[i]
            local fromObjectTypeIndex = objectInfo.objectTypeIndex
            local evolution = evolvingObject.evolutions[fromObjectTypeIndex]
            if evolution then
                local degradeReferenceTime = objectInfo.degradeReferenceTime
                if not degradeReferenceTime then
                    degradeReferenceTime = serverWorld:getWorldTime()
                end
                
                local fractionDegraded = objectInfo.fractionDegraded or 0
                
                local currentTime = serverWorld:getWorldTime()
                
                local timeElapsed = currentTime - degradeReferenceTime
                local covered = storageObject.sharedState.covered
            
                local evolutionLength = evolution.minTime
                if covered then
                    evolutionLength = evolutionLength * evolvingObject.coveredDurationMultiplier
                end
            
                local fractionAddition = timeElapsed / evolutionLength
                fractionDegraded = fractionDegraded + fractionAddition
                if fractionDegraded >= 0.99 then
                    --mj:log("evolution for object within storage area:", storageAreaObjectID,  ". evolutionLength:", evolutionLength, " degradeReferenceTime:", degradeReferenceTime, " currentTime:", currentTime, " timeElapsed:", timeElapsed)
                    needsToUpdate = true

                    if evolution.toType then
                        local toObjectTypeIndex = evolution.toType
                        if storage:resourceTypesCanBeStoredToegether(gameObject.types[fromObjectTypeIndex].resourceTypeIndex, gameObject.types[toObjectTypeIndex].resourceTypeIndex) then
                            sharedState:set("inventory", "objects", i, "objectTypeIndex", toObjectTypeIndex)
                            sharedState:remove("inventory", "objects", i, "fractionDegraded")
                            sharedState:remove("inventory", "objects", i, "degradeReferenceTime")

                            local newFromCount = countsByObjectType[fromObjectTypeIndex] - 1
                            if newFromCount == 0 then
                                sharedState:remove("inventory", "countsByObjectType", fromObjectTypeIndex)
                            else
                                sharedState:set("inventory", "countsByObjectType", fromObjectTypeIndex, newFromCount)
                            end

                            local newToCount = 1
                            if countsByObjectType[toObjectTypeIndex] then
                                newToCount = countsByObjectType[toObjectTypeIndex] + 1
                            end
                            sharedState:set("inventory", "countsByObjectType", toObjectTypeIndex, newToCount)
                            earliestCallbackTime = currentTime --as the object type changed, we need to check again to see if the new type requires another callback. Adding a quick callback should achieve this
                            
                            serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, fromObjectTypeIndex, -1)
                            serverStorageArea:updateStatsForObjectAdditionOrRemoval(storageObject, toObjectTypeIndex, 1)
                        else
                            local removedObjectInfo = serverStorageArea:removeObjectAtIndex(storageAreaObjectID, i)
                            if removedObjectInfo then
                                serverGOM:createOutput(storageObject.pos, nil, toObjectTypeIndex, nil, sharedState.tribeID, plan.types.storeObject.index, nil)
                            end
                        end
                    elseif evolution.toTypes then
                        local removedObjectInfo = serverStorageArea:removeObjectAtIndex(storageAreaObjectID, i)
                        if removedObjectInfo then
                            for j,toType in ipairs(evolution.toTypes) do
                                serverGOM:createOutput(storageObject.pos, nil, toType, nil, sharedState.tribeID, plan.types.storeObject.index, nil)
                            end
                        end
                    else
                        serverStorageArea:removeObjectAtIndex(storageAreaObjectID, i)
                    end
                    
                else
                    --mj:log("saving updated degrade fraction for object within storage area:", storageAreaObjectID,  ". evolutionLength:", evolutionLength, " degradeReferenceTime:", degradeReferenceTime, " currentTime:", currentTime, " timeElapsed:", timeElapsed, " fractionAddition:", fractionAddition)
                    sharedState:set("inventory", "objects", i, "degradeReferenceTime", currentTime)
                    sharedState:set("inventory", "objects", i, "fractionDegraded", fractionDegraded)

                    local evolveTime = currentTime + (1.0 - fractionDegraded) * evolutionLength
                    if (not earliestCallbackTime) or evolveTime < earliestCallbackTime then
                        earliestCallbackTime = evolveTime
                    end
                end
            end
        end

        if needsToUpdate then
            serverResourceManager:updateResourcesForObject(storageObject)
        end

        if earliestCallbackTime then
            
            --mj:log("adding callback in serverEvolvingObject:addCallbackForStorageAreaIfNeeded:", storageAreaObjectID, " delay:", earliestCallbackTime - serverWorld:getWorldTime())
            --mj:log("callBackInfosByObjectID[storageAreaObjectID]:", callBackInfosByObjectID[storageAreaObjectID], " world time:", serverWorld:getWorldTime())

            local foundEarlierTime = false
            if callBackInfosByObjectID[storageAreaObjectID] then
                if callBackInfosByObjectID[storageAreaObjectID].evolveTime <= earliestCallbackTime + 0.1 then
                    --mj:log("STORAGE foundEarlierTime")
                    foundEarlierTime = true
                else
                   -- mj:log("STORAGE removeObjectCallbackTimerWithID:", storageAreaObjectID, " callbackID:", callBackInfosByObjectID[storageAreaObjectID].timerID)
                    serverGOM:removeObjectCallbackTimerWithID(storageAreaObjectID, callBackInfosByObjectID[storageAreaObjectID].timerID)
                    callBackInfosByObjectID[storageAreaObjectID] = nil
                end
            end

            if not foundEarlierTime then
                local timerID = serverGOM:addObjectCallbackTimerForWorldTime(storageAreaObjectID, earliestCallbackTime, function(objectID)
                    --mj:log("in callback function")
                    callBackInfosByObjectID[storageAreaObjectID] = nil
                    serverEvolvingObject:addCallbackForStorageAreaIfNeeded(objectID)
                end)
                --mj:log("added callback:", timerID)
        
                callBackInfosByObjectID[storageAreaObjectID] = {
                    timerID = timerID,
                    evolveTime = earliestCallbackTime
                }
            end
        end
    end
end

function serverEvolvingObject:coveredStatusChangedForStorageArea(storageAreaObjectID)
    if callBackInfosByObjectID[storageAreaObjectID] then
       -- mj:log("STORAGE removeObjectCallbackTimerWithID:", storageAreaObjectID, " callbackID:", callBackInfosByObjectID[storageAreaObjectID].timerID)
        serverGOM:removeObjectCallbackTimerWithID(storageAreaObjectID, callBackInfosByObjectID[storageAreaObjectID].timerID)
        callBackInfosByObjectID[storageAreaObjectID] = nil
    end
    serverEvolvingObject:addCallbackForStorageAreaIfNeeded(storageAreaObjectID)
end

local function checkForEvolution(object, evolution)
    local sharedState = serverGOM:getSharedState(object, true)
    local degradeReferenceTime = sharedState.degradeReferenceTime
    if not degradeReferenceTime then
        degradeReferenceTime = serverWorld:getWorldTime()
        sharedState:set("degradeReferenceTime", degradeReferenceTime)
    end

    local fractionDegraded = sharedState.fractionDegraded or 0
    local currentTime = serverWorld:getWorldTime()
    local timeElapsed = currentTime - degradeReferenceTime
    local covered = sharedState.covered

    local evolutionLength = evolution.minTime
    if covered then
        evolutionLength = evolutionLength * 4.0
    end

    local fractionAddition = timeElapsed / evolutionLength
    fractionDegraded = fractionDegraded + fractionAddition
    --mj:log("in callback for evolution for object:", object.uniqueID, " is covered:", covered, "\ndegradeReferenceTime:", degradeReferenceTime, " currentTime:", currentTime, " timeElapsed:", timeElapsed, "\nevolutionLength:", evolutionLength, " fractionAddition:", fractionAddition, " fractionDegraded:", fractionDegraded)

    local function addNextDegradation(toObject)
        local newFractionDegraded = fractionDegraded - 1.0

        local timeRemaining = newFractionDegraded * evolutionLength
        local newEvolution = evolvingObject.evolutions[toObject.objectTypeIndex]
        local newEvolutionLength = newEvolution.minTime
        if covered then
            newEvolutionLength = newEvolutionLength * 4.0
        end
        newFractionDegraded = math.min(timeRemaining / newEvolutionLength, 0.95)
        toObject.sharedState:set("degradeReferenceTime", currentTime)
        toObject.sharedState:set("fractionDegraded", newFractionDegraded)
    end

    if evolution.delayUntilUsable then
        sharedState:set("degradeReferenceTime", currentTime)
        sharedState:set("fractionDegraded", fractionDegraded)
    else
        if fractionDegraded >= 0.99 then
            --mj:log("evolution for object:", object.uniqueID)
            if evolution.toType then
                serverGOM:changeObjectType(object.uniqueID, evolution.toType, false)
                if fractionDegraded > 1.01 and evolvingObject.evolutions[evolution.toType] then
                    addNextDegradation(object)
                end
            elseif evolution.toTypes then
                for i,toType in ipairs(evolution.toTypes) do
                    local createdObjectID = serverGOM:createOutput(object.pos, nil, toType, nil, nil, nil, nil)
                    if fractionDegraded > 1.01 and evolvingObject.evolutions[toType] then
                        local toObject = serverGOM:getObjectWithID(createdObjectID)
                        if toObject then
                            addNextDegradation(toObject)
                        end
                    end
                end
                serverGOM:removeGameObject(object.uniqueID)
                return false
            else
                serverGOM:removeGameObject(object.uniqueID)
                return false
            end
        else
            
            sharedState:set("degradeReferenceTime", currentTime)
            sharedState:set("fractionDegraded", fractionDegraded)

            local evolveTime = currentTime + (1.0 - fractionDegraded) * evolutionLength
            --mj:log("adding callback for evolution for object:", object.uniqueID, " delay:", evolveTime - currentTime)
            local timerID = serverGOM:addObjectCallbackTimerForWorldTime(object.uniqueID, evolveTime, function(objectID)
                local object_ = serverGOM:getObjectWithID(objectID)
                if object_ then
                    if object_.objectTypeIndex == object.objectTypeIndex then
                        checkForEvolution(object_, evolution)
                    end
                end
            end)

            callBackInfosByObjectID[object.uniqueID] = {
                timerID = timerID,
                evolveTime = evolveTime
            }
        end
        return true
    end
end

function serverEvolvingObject:finalize()
    for objectTypeIndex, evolution in pairs(evolvingObject.evolutions) do
        serverGOM:addObjectLoadedFunctionForType(objectTypeIndex, function(object)
            if not serverGOM:isStored(object.uniqueID) then
                local sharedState = serverGOM:getSharedState(object, true)
                sharedState:set("fractionDegraded", 0.5 * rng:valueForUniqueID(object.uniqueID, 32998))
            end
            local objectValid = checkForEvolution(object, evolution)
            if not objectValid then
                return true
            end
            serverGOM:addObjectToSet(object, serverGOM.objectSets.coveredStatusObservers)
            return false
        end)

        serverGOM:addObjectCoveredStatusChangedFunctionForType(objectTypeIndex, function(object)
            --mj:log("covered status changed callback being called for object:", object.uniqueID)
            if callBackInfosByObjectID[object.uniqueID] then
                --mj:log("removeObjectCallbackTimerWithID:", object.uniqueID, " callbackID:", callBackInfosByObjectID[object.uniqueID].timerID)
                serverGOM:removeObjectCallbackTimerWithID(object.uniqueID, callBackInfosByObjectID[object.uniqueID].timerID)
                callBackInfosByObjectID[object.uniqueID] = nil
            end
            checkForEvolution(object, evolution)
        end)

        --[[serverGOM:addObjectUnloadedFunctionForType(objectTypeIndex, function(object)
            serverGOM:removeObjectCallbackTimers(object.uniqueID)
        end)]] --should be handled by the engine
    end
end

return serverEvolvingObject