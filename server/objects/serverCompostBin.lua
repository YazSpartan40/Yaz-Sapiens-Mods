
local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local plan = mjrequire "common/plan"
local gameConstants = mjrequire "common/gameConstants"
local constructable = mjrequire "common/constructable"
local anchor = mjrequire "server/anchor"

local serverCompostBin = {}

local serverGOM = nil
local serverWorld = nil
local planManager = nil

local timeUntilCompostGeneratedSeconds = nil

function serverCompostBin:checkForEmptyAndUpdatePlans(object)
    if object then
        local sharedState = object.sharedState
        if (not sharedState.inventory) or (not sharedState.inventory.objects) or #sharedState.inventory.objects == 0 then
            if sharedState.planStates then

                local function updateDeconstructPlan(tribeID, planState)
                    planManager:removePlanStateForObject(object, plan.types.deconstruct.index, nil, nil, tribeID)
                    planManager:addDeconstructPlanForEmptyConstructedObject(tribeID, object)
                end
                
                local function updateRebuildPlan(tribeID, planState)
                    planManager:removePlanStateForObject(object, plan.types.rebuild.index, nil, nil, tribeID)
                    planManager:addRebuildPlanForEmptyConstructedObject(sharedState.tribeID, object, planState.rebuildConstructableTypeIndex, 
                    planState.rebuildRestrictedResourceObjectTypes, planState.rebuildRestrictedToolObjectTypes)
                end
                
                for tribeID,planStatesForThisTribe in pairs(sharedState.planStates) do
                    for i=#planStatesForThisTribe,1,-1 do
                        local thisPlanState = planStatesForThisTribe[i]
                        if thisPlanState.planTypeIndex == plan.types.deconstruct.index then
                            updateDeconstructPlan(tribeID, thisPlanState)
                            return
                        end
                        if thisPlanState.planTypeIndex == plan.types.rebuild.index then
                            updateRebuildPlan(tribeID, thisPlanState)
                            return
                        end
                    end
                end
            end
        end
    end
end

local function infrequentUpdate(objectID, dt, speedMultiplier)
    --mj:log("serverCompostBin infrequentUpdate:", objectID)
    local object = serverGOM:getObjectWithID(objectID)
    if object then
        local sharedState = object.sharedState
        local inventory = sharedState.inventory
        if inventory and inventory.objects then
            local currentTime = serverWorld:getWorldTime()

            local objects = inventory.objects
            local currentCount = #inventory.objects
            local readyCompostSum = 0
            local compostCreated = false
            --mj:log("serverCompostBin currentCount:", currentCount)

            for i=1,currentCount do
                local objectInfo = objects[i]
                if currentTime - objectInfo.addTime >= timeUntilCompostGeneratedSeconds then
                    readyCompostSum = readyCompostSum + resource.types[gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex].compostValue
                    --mj:log("serverCompostBin found compost item, sum:", readyCompostSum)
                    if readyCompostSum >= gameConstants.compostBinValueSumRequiredForOutput then
                        --mj:log("serverCompostBin readyCompostSum >= compostValueSumRequiredForOutput readyCompostSum:", readyCompostSum)

                        --[[for j=1,i do
                            sharedState:removeFromArray("inventory", "objects", 1)
                        end]]
                        
                        serverGOM:createOutput(object.pos, nil, gameObject.types.compost.index, nil, sharedState.tribeID, plan.types.storeObject.index, nil)
                        compostCreated = true

                        local remainingGooCount = readyCompostSum - gameConstants.compostBinValueSumRequiredForOutput

                        local newObjectList = {}
                        for j=1,remainingGooCount do
                            table.insert(newObjectList, {
                                objectTypeIndex = gameObject.types.rottenGoo.index,
                                addTime = objectInfo.addTime,
                            })
                        end

                        for j=i + 1,currentCount do
                            table.insert(newObjectList, objects[j])
                        end

                        sharedState:set("inventory", "objects", newObjectList)
                        sharedState:set("previousOutputTime", serverWorld:getWorldTime())
                        
                        break
                    end
                else
                    break
                end
            end

            if compostCreated then
                serverCompostBin:checkForEmptyAndUpdatePlans(object)
            end
        end
    end
end

function serverCompostBin:init(serverGOM_, serverWorld_, planManager_)
    serverGOM = serverGOM_
    planManager = planManager_
    serverWorld = serverWorld_

    timeUntilCompostGeneratedSeconds = serverWorld:getDayLength() * gameConstants.compostTimeUntilCompostGeneratedDays

    serverGOM:addObjectLoadedFunctionForTypes({ gameObject.types.compostBin.index }, function(compostBin)
        serverGOM:addObjectToSet(compostBin, serverGOM.objectSets.maintenance)
        serverGOM:addObjectToSet(compostBin, serverGOM.objectSets.compostBins)

        if compostBin.sharedState.removeAllDueToDeconstruct then --migrate to 0.5
            compostBin.sharedState:set("settingsByTribe", compostBin.sharedState.tribeID, "removeAllDueToDeconstruct", compostBin.sharedState.removeAllDueToDeconstruct)
            compostBin.sharedState:remove("removeAllDueToDeconstruct")
        end

        compostBin.sharedState:remove("requiresMaintenance") --migrate to 0.5
        compostBin.sharedState:set("requiresMaintenanceByTribe", compostBin.sharedState.tribeID, true)

        anchor:addAnchor(compostBin.uniqueID, anchor.types.craftArea.index, compostBin.sharedState.tribeID)
        return false
        --compostBin.sharedState:remove("inventory") --todo
    end)

    serverGOM:addObjectUnloadedFunctionForType(gameObject.types.compostBin.index, function(object)
        anchor:anchorObjectUnloaded(object.uniqueID)
    end)
    
    serverGOM:setInfrequentCallbackForGameObjectsInSet(serverGOM.objectSets.compostBins, "update", 10.0, infrequentUpdate) 
end


function serverCompostBin:compostBinRequiresObjectOfType(possibleCompostBinObject, objectTypeIndex, tribeID)
    if possibleCompostBinObject.objectTypeIndex == gameObject.types.compostBin.index then
        local tribeSettings = (possibleCompostBinObject.sharedState.settingsByTribe and possibleCompostBinObject.sharedState.settingsByTribe[tribeID]) or {}
        if tribeSettings.removeAllDueToDeconstruct then
            return false
        end
        if resource.types[gameObject.types[objectTypeIndex].resourceTypeIndex].compostValue then
            
            local restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(tribeID, constructable.types.compost.index, nil)

            if restrictedResourceObjectTypes and restrictedResourceObjectTypes[objectTypeIndex] then
                mj:log("success, object not wanted:", objectTypeIndex)
                return false
            end

            local requiredCount = serverCompostBin:objectRequiredCount(possibleCompostBinObject, tribeID)
            if requiredCount == 0 then
                return false
            end
            return true
        end
    end
    return false
end


function serverCompostBin:getRequiredItems(possibleCompostBinObject, tribeID)
    if possibleCompostBinObject.objectTypeIndex == gameObject.types.compostBin.index then
        local requiredCount = serverCompostBin:objectRequiredCount(possibleCompostBinObject, tribeID)
        if requiredCount == 0 then
            return nil
        end

        return {
            resources = {
                {
                    group = resource.groups.compostable.index,
                    count = requiredCount,
                }
            }
        }
    end

    return nil
end

function serverCompostBin:objectRequiredCount(possibleCompostBinObject, tribeID)
    if possibleCompostBinObject.objectTypeIndex == gameObject.types.compostBin.index then
        local sharedState = possibleCompostBinObject.sharedState
        local tribeSettings = (sharedState.settingsByTribe and sharedState.settingsByTribe[tribeID]) or {}
        if tribeSettings.removeAllDueToDeconstruct then
            return 0
        end
        local inventory = sharedState.inventory
        local currentCount = 0
        if inventory and inventory.objects then
            currentCount = #inventory.objects
        end
        if currentCount >= gameConstants.compostBinMaxItemCount then
            return 0
        end

        return gameConstants.compostBinMaxItemCount - currentCount
    end
    return 0
end

function serverCompostBin:requiredCompostObjectTypesArrayForObject(object, tribeID)
    if serverCompostBin:objectRequiredCount(object, tribeID) == 0 then
        return nil
    end
    
    local restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(tribeID, constructable.types.compost.index, nil)
    if restrictedResourceObjectTypes and next(restrictedResourceObjectTypes) then
        local allowedTypes = {}
        for i,objectTypeIndex in ipairs(gameObject.compostableObjectTypes) do
            if not restrictedResourceObjectTypes[objectTypeIndex] then
                table.insert(allowedTypes, objectTypeIndex)
            end
        end
        return allowedTypes
    end

    return gameObject.compostableObjectTypes
end

local function addItem(compostBinObject, objectTypeIndex)
    local sharedState = compostBinObject.sharedState
    local inventory = sharedState.inventory

    local newIndex = 1
    if inventory and inventory.objects then
        newIndex = #inventory.objects + 1
    end

    if newIndex > gameConstants.compostBinMaxItemCount then
        mj:warn("attempting to add object to full compost bin:", compostBinObject.uniqueID)
        return false
    end

    sharedState:set("inventory", "objects", newIndex, {
        objectTypeIndex = objectTypeIndex,
        addTime = serverWorld:getWorldTime(),
    })

end

function serverCompostBin:deliverToCompost(compostBinObject, objectInfo, tribeID)
    if serverCompostBin:objectRequiredCount(compostBinObject, tribeID) == 0 then
        return false
    end

    local objectTypeIndex = objectInfo.objectTypeIndex
    local compostValue = resource.types[gameObject.types[objectTypeIndex].resourceTypeIndex].compostValue

    if not compostValue then
        mj:error("attempting to add non-compostibale object to compost bin:", compostBinObject.uniqueID, " of type:", gameObject.types[objectTypeIndex].key)
        return false
    end
    
    local restrictedResourceObjectTypes = serverWorld:getResourceBlockListForConstructableTypeIndex(tribeID, constructable.types.compost.index, nil)
    if restrictedResourceObjectTypes and restrictedResourceObjectTypes[objectTypeIndex] then
        mj:log("attempting to add object to compost, but it's on the block list:", objectTypeIndex)
        return false
    end

    local compostByProducts = gameObject.types[objectTypeIndex].compostByProducts
    if compostByProducts then
        for i=1,compostValue do
            addItem(compostBinObject, gameObject.types.rottenGoo.index)
        end
        for i,byProductObjectTypeIndex in ipairs(compostByProducts) do
            serverGOM:createOutput(compostBinObject.pos, nil, byProductObjectTypeIndex, nil, tribeID, plan.types.storeObject.index, nil)
        end
    else
        addItem(compostBinObject, objectTypeIndex)
    end
        
    return true
end

function serverCompostBin:removeObjectFromCompostBin(objectID)
    local compostBinObject = serverGOM:getObjectWithID(objectID)
    if compostBinObject and compostBinObject.objectTypeIndex == gameObject.types.compostBin.index then

        local sharedState = compostBinObject.sharedState
        local inventory = sharedState.inventory

        if inventory and inventory.objects then
            local foundIndex = #inventory.objects
            if foundIndex > 0 then
                local objectTypeIndex = inventory.objects[foundIndex].objectTypeIndex
                sharedState:removeFromArray("inventory", "objects", foundIndex)
                return {
                    objectTypeIndex = objectTypeIndex,
                    degradeReferenceTime = serverWorld:getWorldTime(),
                    fractionDegraded = 0,
                }
            end
        end
    end
    return nil
end

function serverCompostBin:cheatClicked(object)
    mj:log("serverCompostBin cheat")
    local sharedState = object.sharedState

    for i=1,gameConstants.compostBinValueSumRequiredForOutput do
        sharedState:set("inventory", "objects", i, {
            objectTypeIndex = gameObject.types.rottenGoo.index,
            addTime = serverWorld:getWorldTime() - timeUntilCompostGeneratedSeconds,
        })
    end
    mj:log("after inventory:", sharedState.inventory)
end

return serverCompostBin