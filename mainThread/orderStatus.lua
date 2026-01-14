local gameObject = mjrequire "common/gameObject"
local order = mjrequire "common/order"
local plan = mjrequire "common/plan"
local locale = mjrequire "common/locale"
local constructable = mjrequire "common/constructable"
local logicInterface = mjrequire "mainThread/logicInterface"
local sapienInventory = mjrequire "common/sapienInventory"
local lookAtIntents = mjrequire "common/lookAtIntents"
local notification = mjrequire "common/notification"
local statusEffect = mjrequire "common/statusEffect"
local weather = mjrequire "common/weather"

--local world = nil

local orderStatus = {}

-- NOTE for notifications, only the required info is passed through, not the full object, so if more is needed here, that info needs to be added to serverSapien:getOrderStatusUserDataForNotification
-- plan objects and order objects require sharedState.name, objectTypeIndex, sharedState.inProgressConstructableTypeIndex

local function getSingleObjectNameForNameAndPlural(name, plural)
    if name == plural then -- eg. raw alpaca meat. We don't want this to be "a raw alpaca meat"
        return locale:get("orderStatus_getObjectNamePlural", {
            objectPlural = string.lower(plural),
        })
    end
    return locale:get("orderStatus_getObjectNameSingleGeneric", {
        objectName = string.lower(name),
    })
end

local function getSingleObjectNameForType(objectTypeIndex)
    local gameObjectType = gameObject.types[objectTypeIndex]
    return getSingleObjectNameForNameAndPlural(gameObjectType.name, gameObjectType.plural)
end

local function getSingleObjectName(object)
    if object.sharedState and object.sharedState.name then
        return locale:get("orderStatus_getObjectNameSingleNamed", {
            objectName = object.sharedState.name,
        })
    end

    return getSingleObjectNameForType(object.objectTypeIndex)
end

local function addObjectName(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    local orderObject = statusInfo.orderObjectInfo
    --mj:log("storeObject orderState:", orderState)
    
    local name = order.types[orderState.orderTypeIndex].name
    local inProgressName = order.types[orderState.orderTypeIndex].inProgressName
    local orderContext = orderState.context
    if orderContext and orderContext.planTypeIndex then
        name = plan.types[orderContext.planTypeIndex].name
        inProgressName = plan.types[orderContext.planTypeIndex].inProgress --this maybe shouldn't be the case for all plans. Needs to be the case for Chop & Replant, as the order is always just "chop"
    end

    if orderState.objectID then
        local function objectRetrieved(retrievedObject)
            if retrievedObject and (callbackID < 0 or retrievedObject.found) then
                if retrievedObject.sharedState and retrievedObject.sharedState.name then
                    callbackFunction(callbackID, locale:get("orderStatus_addObjectNameSingleNamed", {
                        inProgressName = inProgressName,
                        objectName = retrievedObject.sharedState.name,
                        name = name,
                    }))
                else
                    local gameObjectType = gameObject.types[retrievedObject.objectTypeIndex]
                    if gameObjectType.name == gameObjectType.plural then
                        callbackFunction(callbackID, locale:get("orderStatus_addObjectNamePlural", {
                            inProgressName = inProgressName,
                            objectPlural = string.lower(gameObjectType.plural),
                            name = name,
                        }))
                    else
                        callbackFunction(callbackID, locale:get("orderStatus_addObjectNameSingleGeneric", {
                            inProgressName = inProgressName,
                            objectName = string.lower(gameObjectType.name),
                            name = name,
                        }))
                    end
                end
            else
                callbackFunction(callbackID, inProgressName)
            end
        end
        
        if callbackID < 0 then
            objectRetrieved(orderObject)
        else
            logicInterface:callLogicThreadFunction("retrieveObject", orderState.objectID, objectRetrieved)
        end
    else
        callbackFunction(callbackID, inProgressName)
    end
end

local function getHeldObjectName(statusInfo)
    if (not statusInfo.heldObjectCount) or (not statusInfo.heldObjectTypeIndex) or statusInfo.heldObjectCount == 0 then
        return nil
    end
    
    if statusInfo.heldObjectCount == 1 then
        if statusInfo.heldObjectName then
            return locale:get("orderStatus_getObjectNameSingleNamed", {
                objectName = statusInfo.heldObjectName,
            })
        else
            local gameObjectType = gameObject.types[statusInfo.heldObjectTypeIndex]
            if gameObjectType.name == gameObjectType.plural then
                return locale:get("orderStatus_getObjectNamePlural", {
                    objectPlural = string.lower(gameObjectType.plural),
                })
            end
            return locale:get("orderStatus_getObjectNameSingleGeneric", {
                objectName = string.lower(gameObjectType.name),
            })
        end
    end
    
    return locale:get("orderStatus_getObjectNamePlural", {
        objectPlural = string.lower(gameObject.types[statusInfo.heldObjectTypeIndex].plural),
    })
end

local function addSingleHeldObjectName(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    if statusInfo.heldObjectCount and statusInfo.heldObjectTypeIndex and statusInfo.heldObjectCount > 0 then
        if statusInfo.heldObjectName then
            callbackFunction(callbackID, locale:get("orderStatus_addObjectNameSingleNamed", {
                inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                objectName = statusInfo.heldObjectName,
                name = order.types[orderState.orderTypeIndex].name,
            }))
        else
            local gameObjectType = gameObject.types[statusInfo.heldObjectTypeIndex]
            if gameObjectType.name == gameObjectType.plural then
                callbackFunction(callbackID, locale:get("orderStatus_addObjectNamePlural", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    objectPlural = string.lower(gameObjectType.plural),
                    name = order.types[orderState.orderTypeIndex].name,
                }))
            else
                callbackFunction(callbackID, locale:get("orderStatus_addObjectNameSingleGeneric", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    objectName = string.lower(gameObjectType.name),
                    name = order.types[orderState.orderTypeIndex].name,
                }))
            end
        end
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end


local function gather(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    local orderContext = orderState.context
    if orderContext and orderContext.objectTypeIndex then
        callbackFunction(callbackID, locale:get("orderStatus_addObjectNamePlural", {
            inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
            objectPlural = gameObject.types[orderContext.objectTypeIndex].plural,
            name = order.types[orderState.orderTypeIndex].name,
        }))
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end


local function retrieveObjectWithCallback(statusInfo, callbackID, defaultCallbackFunction, successCallbackFunction)
    local orderState = statusInfo.orderState
    if orderState.objectID then
        local heldObjectName = getHeldObjectName(statusInfo)
        if heldObjectName then
            
            local function objectRetrieved(retrievedObject)
                if retrievedObject and (callbackID < 0 or retrievedObject.found) then
                    
                    local orderContext = orderState.context
                    if orderContext and orderContext.planTypeIndex then
                        if orderContext.planTypeIndex == plan.types.fill.index or 
                        orderContext.planTypeIndex == plan.types.plant.index or 
                        orderContext.planTypeIndex == plan.types.fertilize.index or 
                        orderContext.planTypeIndex == plan.types.research.index or 
                        orderContext.planTypeIndex == plan.types.buildPath.index then
                            successCallbackFunction(heldObjectName, getSingleObjectName(retrievedObject), nil, string.lower(plan.types[orderContext.planTypeIndex].inProgress), string.lower(plan.types[orderContext.planTypeIndex].name))
                            return
                        elseif orderContext.planTypeIndex == plan.types.build.index then
                            local orderObjectState = retrievedObject.sharedState
                            local constructableTypeIndex = orderObjectState.inProgressConstructableTypeIndex
                            local constructableType = constructable.types[constructableTypeIndex]
                            
                            if constructableType then
                                if constructableType.actionText then
                                    successCallbackFunction(heldObjectName, getSingleObjectName(retrievedObject), getSingleObjectNameForNameAndPlural(constructableType.actionObjectName, constructableType.actionObjectNamePlural), string.lower(constructableType.actionInProgressText), string.lower(constructableType.actionText))
                                else
                                    successCallbackFunction(heldObjectName, getSingleObjectName(retrievedObject), getSingleObjectNameForNameAndPlural(constructableType.name, constructableType.plural), string.lower(plan.types[orderContext.planTypeIndex].inProgress), string.lower(plan.types[orderContext.planTypeIndex].name))
                                end
                                return
                            end
                        elseif orderContext.planTypeIndex == plan.types.craft.index then
                            mj:warn("not implemented plan.types.craft.index in retrieveObjectWithCallback")
                        end
                    end

                    successCallbackFunction(heldObjectName, getSingleObjectName(retrievedObject), nil, nil, nil)
                else
                    defaultCallbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
                end
            end
            
            if callbackID < 0 then
                objectRetrieved(statusInfo.orderObjectInfo)
            else
                logicInterface:callLogicThreadFunction("retrieveObject", orderState.objectID, objectRetrieved)
            end
        else
            
            defaultCallbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
            --defaultCallbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName .. getLogisticsPostfix(sapienSharedState))
        end
    else
        defaultCallbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
        --defaultCallbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName .. getLogisticsPostfix(sapienSharedState))
    end
end


local function deliver(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    retrieveObjectWithCallback(statusInfo, callbackID, callbackFunction, function(heldObjectName, retrievedObjectName, retrievedObjectConstructableTypeName, planText, planName)
        callbackFunction(callbackID, locale:get("orderStatus_deliverTo", {
            inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
            heldObjectName = heldObjectName,
            retrievedObjectName = retrievedObjectName,
            retrievedObjectConstructableTypeName = retrievedObjectConstructableTypeName,
            planText = planText,
            name = order.types[orderState.orderTypeIndex].name,
            planName = planName,
            logisticsPostfix = "",
        }))
    end)
    --deliverWithPreposition(orderState, sapienSharedState, callbackID, callbackFunction, "to")
end

local function deliverConstruction(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    --deliverWithPreposition(orderState, sapienSharedState, callbackID, callbackFunction, "for construction at")
    retrieveObjectWithCallback(statusInfo, callbackID, callbackFunction, function(heldObjectName, retrievedObjectName, retrievedObjectConstructableTypeName, planText, planName)
        callbackFunction(callbackID, locale:get("orderStatus_deliverForConstruction", {
            inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
            heldObjectName = heldObjectName,
            retrievedObjectName = retrievedObjectName,
            retrievedObjectConstructableTypeName = retrievedObjectConstructableTypeName,
            planText = planText,
            name = order.types[orderState.orderTypeIndex].name,
            planName = planName,
            logisticsPostfix = "",
        }))
    end)
end

local function deliverFuel(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    --deliverWithPreposition(orderState, sapienSharedState, callbackID, callbackFunction, "for fuel at")
    retrieveObjectWithCallback(statusInfo, callbackID, callbackFunction, function(heldObjectName, retrievedObjectName, retrievedObjectConstructableTypeName, planText, planName)
        callbackFunction(callbackID, locale:get("orderStatus_deliverForFuel", {
            inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
            heldObjectName = heldObjectName,
            retrievedObjectName = retrievedObjectName,
            planText = planText,
            name = order.types[orderState.orderTypeIndex].name,
            planName = planName,
            logisticsPostfix = "",
        }))
    end)
end

local function deliverToCompost(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    --deliverWithPreposition(orderState, sapienSharedState, callbackID, callbackFunction, "for fuel at")
    retrieveObjectWithCallback(statusInfo, callbackID, callbackFunction, function(heldObjectName, retrievedObjectName, retrievedObjectConstructableTypeName, planText, planName)
        callbackFunction(callbackID, locale:get("orderStatus_deliverToCompost", {
            inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
            heldObjectName = heldObjectName,
            retrievedObjectName = retrievedObjectName,
            planText = planText,
            name = order.types[orderState.orderTypeIndex].name,
            planName = planName,
            logisticsPostfix = "",
        }))
    end)
end

local function addLogistics(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    
    --callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName .. getLogisticsPostfix(sapienSharedState))
end

local function pickupObject(statusInfo, callbackID, callbackFunction, preposition)
    local orderState = statusInfo.orderState
    local orderContext = orderState.context
    if orderContext and orderContext.objectTypeIndex then
        if orderContext.planObjectID and orderContext.planTypeIndex then
            
            local function objectRetrieved(retrievedObject)
                if retrievedObject and (callbackID < 0 or retrievedObject.found) then
                    if orderContext.planTypeIndex == plan.types.fill.index or 
                    orderContext.planTypeIndex == plan.types.plant.index or 
                    orderContext.planTypeIndex == plan.types.fertilize.index or 
                    orderContext.planTypeIndex == plan.types.research.index or 
                    orderContext.planTypeIndex == plan.types.buildPath.index then
                        callbackFunction(callbackID, locale:get("orderStatus_pickupObject", {
                            inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                            pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                            planText = string.lower(plan.types[orderContext.planTypeIndex].inProgress),
                            retrievedObjectConstructableTypeName = nil,
                            name = order.types[orderState.orderTypeIndex].name,
                            planName = string.lower(plan.types[orderContext.planTypeIndex].name),
                        }))
                        return
                    elseif orderContext.planTypeIndex == plan.types.build.index then
                        local orderObjectState = retrievedObject.sharedState
                        local constructableTypeIndex = orderObjectState.inProgressConstructableTypeIndex
                        local constructableType = constructable.types[constructableTypeIndex]
                        
                        if constructableType then
                            if constructableType.actionText then
                                callbackFunction(callbackID, locale:get("orderStatus_pickupObject", {
                                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                                    planText = constructableType.actionInProgressText,
                                    name = order.types[orderState.orderTypeIndex].name,
                                    planName = constructableType.actionText,
                                }))
                            else
                                local retrievedObjectConstructableTypeName = nil
                                local retrievedObjectConstructableLocationName = nil
                                if orderContext.planTypeIndex == plan.types.craft.index then
                                    retrievedObjectConstructableTypeName = getSingleObjectNameForNameAndPlural(constructableType.name, constructableType.plural)
                                else
                                    retrievedObjectConstructableLocationName = string.lower(constructableType.name)
                                end

                                callbackFunction(callbackID, locale:get("orderStatus_pickupObject", {
                                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                                    planText = string.lower(plan.types[orderContext.planTypeIndex].inProgress),
                                    retrievedObjectConstructableTypeName = retrievedObjectConstructableTypeName,
                                    retrievedObjectConstructableLocationName = retrievedObjectConstructableLocationName,
                                    name = order.types[orderState.orderTypeIndex].name,
                                    planName = string.lower(plan.types[orderContext.planTypeIndex].name),
                                }))
                            end
                            return
                        end
                    elseif orderContext.planTypeIndex == plan.types.craft.index then
                        mj:warn("not implemented plan.types.craft.index in pickupObject")
                    end
                end
                callbackFunction(callbackID, locale:get("orderStatus_pickupObject", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                    planText = string.lower(plan.types[orderContext.planTypeIndex].inProgress),
                    name = order.types[orderState.orderTypeIndex].name,
                    planName = string.lower(plan.types[orderContext.planTypeIndex].name),
                }))
            end
        
            if callbackID < 0 then
                objectRetrieved(statusInfo.planObjectInfo)
            else
                logicInterface:callLogicThreadFunction("retrieveObject", orderContext.planObjectID, objectRetrieved)
            end
        else
            if orderContext.lookAtIntent == lookAtIntents.types.eat.index then
                callbackFunction(callbackID, locale:get("orderStatus_pickupObjectToEat", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                    planText = string.lower(order.types[orderState.orderTypeIndex].inProgressName),
                    name = order.types[orderState.orderTypeIndex].name,
                    planName = string.lower(order.types[orderState.orderTypeIndex].name),
                }))
            elseif orderContext.lookAtIntent == lookAtIntents.types.putOnClothing.index then
                callbackFunction(callbackID, locale:get("orderStatus_pickupObjectToWear", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                    planText = string.lower(order.types[orderState.orderTypeIndex].inProgressName),
                    name = order.types[orderState.orderTypeIndex].name,
                    planName = string.lower(order.types[orderState.orderTypeIndex].name),
                }))
            elseif orderContext.lookAtIntent == lookAtIntents.types.play.index then
                callbackFunction(callbackID, locale:get("orderStatus_pickupObjectToPlayWith", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                    planText = string.lower(order.types[orderState.orderTypeIndex].inProgressName),
                    name = order.types[orderState.orderTypeIndex].name,
                    planName = string.lower(order.types[orderState.orderTypeIndex].name),
                }))
            else
                callbackFunction(callbackID, locale:get("orderStatus_pickupObject", {
                    inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                    pickupObjectName = getSingleObjectNameForType(orderContext.objectTypeIndex),
                    planText = string.lower(order.types[orderState.orderTypeIndex].inProgressName),
                    name = order.types[orderState.orderTypeIndex].name,
                    planName = string.lower(order.types[orderState.orderTypeIndex].name),
                }))
            end
        end
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local function getResearchOrCraft(orderState)
    if orderState.orderContext and orderState.orderContext.researchTypeIndex then
        return locale:get("orderStatus_research")
    end

    return locale:get("orderStatus_crafting")
end

local function pickupPlanObjectForCraftingOrResearchElsewhere(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    if orderState.objectID then
        local function objectRetrieved(retrievedObject)
            if retrievedObject and (callbackID < 0 or retrievedObject.found) then
                local text = locale:get("orderStatus_moveObjectForAction", {
                    objectName = getSingleObjectName(retrievedObject),
                    action = getResearchOrCraft(orderState),
                })
                callbackFunction(callbackID, text)
            else
                callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
            end
        end
        if callbackID < 0 then
            objectRetrieved(statusInfo.orderObjectInfo)
        else
            logicInterface:callLogicThreadFunction("retrieveObject", orderState.objectID, objectRetrieved)
        end
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local function deliverPlanObjectForCraftingOrResearchElsewhere(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    if orderState.objectID then
        local heldObjectName = getHeldObjectName(statusInfo)
        if heldObjectName then
            local text = locale:get("orderStatus_moveObjectForAction", {
                objectName = heldObjectName,
                action = getResearchOrCraft(orderState),
            })
            callbackFunction(callbackID, text)
        else
            callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
        end
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local function social(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    if orderState.objectID then
        
        local function objectRetrieved(retrievedObject)
            if retrievedObject and (callbackID < 0 or retrievedObject.found) then
                local text = locale:get("orderStatus_talkingTo", {
                    objectName = getSingleObjectName(retrievedObject),
                })
                callbackFunction(callbackID, text)
            else
                callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
            end
        end
        
        if callbackID < 0 then
            objectRetrieved(statusInfo.orderObjectInfo)
        else
            logicInterface:callLogicThreadFunction("retrieveObject", orderState.objectID, objectRetrieved)
        end
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local function buildOrCraft(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    if orderState.objectID then
        local orderContext = orderState.context
        if orderContext and orderContext.planObjectID and orderContext.planTypeIndex then
            
            local function objectRetrieved(retrievedObject)
                if retrievedObject and (callbackID < 0 or retrievedObject.found) then
                    local orderObjectState = retrievedObject.sharedState
                    local constructableTypeIndex = orderObjectState.inProgressConstructableTypeIndex
                    local constructableType = constructable.types[constructableTypeIndex]
                    if constructableType then
                        if constructableType.actionInProgressText then
                            callbackFunction(callbackID, locale:get("orderStatus_buildConstructablePlan", {
                                inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                                name = order.types[orderState.orderTypeIndex].name,
                                planText = constructableType.actionInProgressText,
                                retrievedObjectConstructableTypeName = getSingleObjectNameForNameAndPlural(constructableType.actionObjectName, constructableType.actionObjectNamePlural),
                                planName = constructableType.actionText,
                            }))
                        else
                            callbackFunction(callbackID, locale:get("orderStatus_buildConstructablePlan", {
                                inProgressName = order.types[orderState.orderTypeIndex].inProgressName,
                                name = order.types[orderState.orderTypeIndex].name,
                                planText = (plan.types[orderContext.planTypeIndex].inProgress),
                                retrievedObjectConstructableTypeName = getSingleObjectNameForNameAndPlural(constructableType.name, constructableType.plural),
                                planName = (plan.types[orderContext.planTypeIndex].name),
                            }))
                        end
                    else
                        callbackFunction(callbackID, plan.types[orderContext.planTypeIndex].inProgress)
                    end
                else
                    callbackFunction(callbackID, plan.types[orderContext.planTypeIndex].inProgress)
                end
            end
        
            if callbackID < 0 then
                objectRetrieved(statusInfo.planObjectInfo)
            else
                logicInterface:callLogicThreadFunction("retrieveObject", orderContext.planObjectID, objectRetrieved)
            end
        else
            callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
        end
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local function moveTo(statusInfo, callbackID, callbackFunction)
    local orderState = statusInfo.orderState
    local orderContext = orderState.context
    if orderContext and orderContext.moveToMotivation then
        callbackFunction(callbackID, order.moveToMotivationTypes[orderContext.moveToMotivation].statusText)
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local function throwProjectile(statusInfo, callbackID, callbackFunction)
    
    local orderState = statusInfo.orderState
    local orderContext = orderState.context
    if orderContext and orderContext.planTypeIndex then
        callbackFunction(callbackID, plan.types[orderContext.planTypeIndex].inProgress)
    else
        callbackFunction(callbackID, order.types[orderState.orderTypeIndex].inProgressName)
    end
end

local functionsByOrderType = {
    [order.types.storeObject.index] = addObjectName,
    [order.types.chop.index] = addObjectName,
    [order.types.pullOut.index] = addObjectName,
    [order.types.removeObject.index] = addObjectName,
    [order.types.destroyContents.index] = addObjectName,

    [order.types.buildMoveComponent.index] = buildOrCraft,
    [order.types.buildActionSequence.index] = buildOrCraft,
    --[order.types.dig.index] = addObjectName,
    --[order.types.clear.index] = addObjectName,
    
    
    [order.types.moveTo.index] = moveTo,
    
    [order.types.gather.index] = gather,

    [order.types.deliverObjectToStorage.index] = deliver,
    [order.types.deliverObjectTransfer.index] = deliver,
    [order.types.deliverFuel.index] = deliverFuel,
    [order.types.deliverObjectToConstructionObject.index] = deliverConstruction,
    [order.types.deliverToCompost.index] = deliverToCompost,

    [order.types.moveToLogistics.index] = addLogistics,
    [order.types.transferObject.index] = addLogistics,
    
    [order.types.pickupObject.index] = pickupObject,

    [order.types.pickupPlanObjectForCraftingOrResearchElsewhere.index] = pickupPlanObjectForCraftingOrResearchElsewhere,
    [order.types.deliverPlanObjectForCraftingOrResearchElsewhere.index] = deliverPlanObjectForCraftingOrResearchElsewhere,
    
    [order.types.eat.index] = addSingleHeldObjectName,
    [order.types.playInstrument.index] = addSingleHeldObjectName,
    
    [order.types.social.index] = social,
    
    [order.types.haulMoveToObject.index] = moveTo, --todo
    [order.types.haulDragObject.index] = moveTo, --todo
    [order.types.haulRideObject.index] = moveTo, --todo
    
    [order.types.throwProjectile.index] = throwProjectile,
}

function orderStatus:getStatusText(orderState, sapienSharedState, callbackID, callbackFunction)
    local warmingUp = false
    if statusEffect:hasEffect(sapienSharedState, statusEffect.types.veryCold.index) then
        if sapienSharedState.temperatureZoneIndex ~= weather.temperatureZones.veryCold.index then
            warmingUp = true
        end
    end

    if not orderState then
        local text = nil
        if sapienSharedState.resting then
            text =locale:get("order_resting")
        else
            text = locale:get("order_idle")
        end
        
        if warmingUp then
            text = locale:get("orderStatus_addWarmingUp", {
                currentText = text,
            })
        end

        callbackFunction(callbackID, text)
        return
    end

    --mj:log("orderState:", orderState)
    if orderState.context and orderState.context.researchTypeIndex then
        callbackFunction(callbackID, locale:get("plan_research_inProgress"))
        return
    end
    
    local heldObjectTypeIndex = nil
    local heldObjectName = nil
    local heldObjectCount = sapienInventory:objectCount({sharedState = sapienSharedState}, sapienInventory.locations.held.index)
    if heldObjectCount > 0 then
        local objectInfo = sapienInventory:lastObjectInfo({sharedState = sapienSharedState}, sapienInventory.locations.held.index)
        heldObjectTypeIndex = objectInfo.objectTypeIndex
        heldObjectName = objectInfo.name
    end

    local statusInfo = {
        orderState = orderState,
        heldObjectCount = heldObjectCount,
        heldObjectTypeIndex = heldObjectTypeIndex,
        heldObjectName = heldObjectName,
        warmingUp = warmingUp,
    }

    local statusFunction = functionsByOrderType[orderState.orderTypeIndex]
    if statusFunction then
        statusFunction(statusInfo, callbackID, callbackFunction)
        return
    end
    
    local orderinProgressText = order.types[orderState.orderTypeIndex].inProgressName
    local orderContext = sapienSharedState.orderQueue[1].context
    if orderContext and orderContext.objectTypeIndex then
        orderinProgressText = orderinProgressText .. " " .. gameObject.types[orderContext.objectTypeIndex].name
    end
    
    if warmingUp then
        orderinProgressText = locale:get("orderStatus_addWarmingUp", {
            currentText = orderinProgressText,
        })
    end
    callbackFunction(callbackID, orderinProgressText)
end

function orderStatus:getStatusTextForNotification(notificationUserData)
    if notificationUserData then
        local orderState = notificationUserData.orderState
        if orderState then
            if orderState.context and orderState.context.researchTypeIndex then
                return string.lower(locale:get("plan_research_inProgress"))
            end

            local statusFunction = functionsByOrderType[orderState.orderTypeIndex]
            if statusFunction then
                local result = nil
                statusFunction(notificationUserData, -1, function(callbackID, text)
                    result = string.lower(text)
                end)
                if result then
                    return result
                end
            end

            local orderinProgressText = order.types[orderState.orderTypeIndex].inProgressName
            if orderState.context and orderState.context.objectTypeIndex then
                orderinProgressText = orderinProgressText .. " " .. getSingleObjectNameForType(orderState.context.objectTypeIndex)
            end

            return orderinProgressText
        end
    end

    --mj:error("no result in getStatusTextForNotification notificationUserData:", notificationUserData)
    return nil
end

function orderStatus:load(world_)
    --world = world_
    notification:setOrderStatus(orderStatus)
end

orderStatus.functionsByOrderType = functionsByOrderType

return orderStatus