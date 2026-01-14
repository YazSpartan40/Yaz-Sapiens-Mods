
local gameObject = mjrequire "common/gameObject"
local fuel = mjrequire "common/fuel"
local plan = mjrequire "common/plan"

local serverFuel = {}

local serverWorld = nil
local planManager = nil

local function getFuelObjectTypeBlocked(objectTypeIndex, fuelGroupIndex, tribeID)
    local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
    if resourceBlockLists then
        local fuelBlockLists = resourceBlockLists.fuelLists
        if fuelBlockLists then
            local fuelBlockList = fuelBlockLists[fuelGroupIndex]
            if fuelBlockList then
                return fuelBlockList[objectTypeIndex]
            end
        end
    end
    return false
end


function serverFuel:requiredFuelObjectTypesArrayForObject(object, tribeID)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local fuelBlockList = nil
        local resourceBlockLists = serverWorld:getResourceBlockListsForTribe(tribeID)
        if resourceBlockLists then
            local fuelBlockLists = resourceBlockLists.fuelLists
            if fuelBlockLists then
                fuelBlockList = fuelBlockLists[thisFuelGroup.index]
            end
        end

        if fuelBlockList and next(fuelBlockList) then
            local allowedList = {}
            for i, objectTypeIndex in ipairs(thisFuelGroup.objectTypes) do
                if not fuelBlockList[objectTypeIndex] then
                    table.insert(allowedList, objectTypeIndex)
                end
            end

            if next(allowedList) then
                return allowedList
            end
            return nil
        end

        return thisFuelGroup.objectTypes
    end
    return nil
end

function serverFuel:fuelAdditionForFuelForObject(object, fuelObjectTypeIndex, degradeFractionOrNil, tribeID)
    -- mj:log("serverFuel:fuelAdditionForFuelForObject:", object.uniqueID, " fuelObjectTypeIndex:", fuelObjectTypeIndex)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
--  mj:log("thisFuelGroup:", thisFuelGroup)
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local fuelGameObjectType = gameObject.types[fuelObjectTypeIndex]
    --  mj:log("fuelGameObjectType:", fuelGameObjectType)
        if fuelGameObjectType.resourceTypeIndex and thisFuelGroup.resources[fuelGameObjectType.resourceTypeIndex] then
            if not getFuelObjectTypeBlocked(fuelObjectTypeIndex, thisFuelGroup.index, tribeID) then
                --mj:log("good:")
                local fuelValue = thisFuelGroup.resources[fuelGameObjectType.resourceTypeIndex].fuelAddition
                --  mj:log("fuelValue:", fuelValue)
                if degradeFractionOrNil then
                -- mj:log("degradeFractionOrNil:", degradeFractionOrNil)
                    fuelValue = fuelValue * (1.0 - degradeFractionOrNil)
                end
                return fuelValue
            end
        end
    end
    return nil
end

function serverFuel:objectTypeIsFuelForObject(object, fuelObjectTypeIndex, tribeID)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local fuelGameObjectType = gameObject.types[fuelObjectTypeIndex]
        if fuelGameObjectType.resourceTypeIndex and thisFuelGroup.resources[fuelGameObjectType.resourceTypeIndex] then
            if not getFuelObjectTypeBlocked(fuelObjectTypeIndex, thisFuelGroup.index, tribeID) then
                return true
            end
        end
    end
    return false
end
 
function serverFuel:objectRequiresFuelOfType(object, fuelObjectTypeIndex, tribeID)
    --mj:log("serverFuel:objectTypeIsFuelForObject(object, fuelObjectTypeIndex, tribeID):", serverFuel:objectTypeIsFuelForObject(object, fuelObjectTypeIndex, tribeID), " object id:", object.uniqueID)
    if serverFuel:objectTypeIsFuelForObject(object, fuelObjectTypeIndex, tribeID) then
        local fuelState = object.sharedState.fuelState
        if fuelState then
            --mj:log("fuelState:", fuel:objectTypeIsFuelForObject(fuelState))
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel <= 0.0 then
                --mj:log("fuel is required")
                    return true
                end
            end
        end
    end
    return false
end


 function serverFuel:addFuel(orderObject, addObjectInfo, adderTribeID)
    
    local fuelState = orderObject.sharedState.fuelState
    if not fuelState then
        return false
    end

    local objectTypeIndex = addObjectInfo.objectTypeIndex
    local fuelAddition = serverFuel:fuelAdditionForFuelForObject(orderObject, objectTypeIndex, addObjectInfo.fractionDegraded, adderTribeID)
    if fuelAddition then
        for i=#fuelState, 1,-1 do
            local fuelItemState = fuelState[i]
            if fuelItemState.fuel <= 0.0 then
                local newFuelItemState = {
                    fuel = fuelAddition,
                    objectTypeIndex = objectTypeIndex,
                    fractionDegraded = orderObject.sharedState.fractionDegraded,
                }
                orderObject.sharedState:set("fuelState", i, newFuelItemState)

                local sharedState = orderObject.sharedState
                if sharedState then
                    if sharedState.planStates and next(sharedState.planStates) then
                        local requiredItems = fuel:getRequiredItemsForFuelAdd(orderObject)

                        for tribeID, planStatesForTribeID in pairs(sharedState.planStates) do
                            for j,thisPlanState in ipairs(planStatesForTribeID) do
                                if thisPlanState.planTypeIndex == plan.types.light.index or thisPlanState.planTypeIndex == plan.types.addFuel.index then
                                    planManager:updateRequiredResourcesForPlan(tribeID, thisPlanState, orderObject, requiredItems)
                                end
                            end
                        end
                    end
                end
                
                return true
            end
        end
    end

    return false
end

function serverFuel:init(serverWorld_, planManager_)
    serverWorld = serverWorld_
    planManager = planManager_
end

return serverFuel