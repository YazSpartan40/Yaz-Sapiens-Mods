local mjm = mjrequire "common/mjm"
local normalize = mjm.normalize
local length2 = mjm.length2
local dot = mjm.dot
--local vec4 = mjm.vec4
local vec3 = mjm.vec3
--local vec3xMat3 = mjm.vec3xMat3
--local mat3Identity = mjm.mat3Identity
--local mat3Inverse = mjm.mat3Inverse
--local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
--local mat3GetRow = mjm.mat3GetRow
--local resource = mjrequire "common/resource"
--local action = mjrequire "common/action"
--local order = mjrequire "common/order"
--local actionSequence = mjrequire "common/actionSequence"
local gameObject = mjrequire "common/gameObject"
local mob = mjrequire "common/mob/mob"
local plan = mjrequire "common/plan"
--local storage = mjrequire "common/storage"
--local terrain = mjrequire "common/terrain"
local modelMorphTargets = mjrequire "common/modelMorphTargets"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
--local rng = mjrequire "common/randomNumberGenerator"
--local timer = mjrequire "common/timer"
local worldHelper = mjrequire "common/worldHelper"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
local sapienConstants = mjrequire "common/sapienConstants"
local gameConstants = mjrequire "common/gameConstants"
local research = mjrequire "common/research"
--local constructable = mjrequire "common/constructable"

local logic = mjrequire "logicThread/logic"
local logicAudio = mjrequire "logicThread/logicAudio"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local clientSapien = mjrequire "logicThread/clientSapien"
local clientBoat = mjrequire "logicThread/clientBoat"
local clientMob = mjrequire "logicThread/mobs/clientMob"
local clientStorageArea = mjrequire "logicThread/clientStorageArea"
local clientCraftArea = mjrequire "logicThread/clientCraftArea"
local clientObjectAnimation = mjrequire "logicThread/clientObjectAnimation"
local clientBuildableObject = mjrequire "logicThread/clientBuildableObject"
local clientBuiltObject = mjrequire "logicThread/clientBuiltObject"
local clientPathBuildable = mjrequire "logicThread/clientPathBuildable"
local clientConstruction = mjrequire "logicThread/clientConstruction"
local musicalInstrumentPlayer = mjrequire "logicThread/musicalInstrumentPlayer"
local clientFlora = mjrequire "logicThread/clientFlora"
local clientCampfire = mjrequire "logicThread/clientCampfire"
local clientKiln = mjrequire "logicThread/clientKiln"
local clientTorch = mjrequire "logicThread/clientTorch"
local clientLitObject = mjrequire "logicThread/clientLitObject"
local clientCompostBin = mjrequire "logicThread/clientCompostBin"
local clientObjectNotifications = mjrequire "logicThread/clientObjectNotifications"
--local physicsSets = mjrequire "common/physicsSets"
local planHelper = mjrequire "common/planHelper"
--local clientNPC = mjrequire "logicThread/clientNPC"

local clientGOM = {
    clientStates = {}
}

local allObjects = {}
local unloadedObjectInfos = {}

local bridge = nil
local terrain = nil


local currentRegisteredServerUpdateNotificationIDs = {}
local initialStateSentIDs = {}

local unhiddenLookAtGameObjectID = nil
local unhiddenSubModelsLookAtGameObjectID = nil
local buildModeIsActive = false
local allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode = {}
local objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode = {}

local function setupDefaultClientState(object, clientState)
    if object.objectTypeIndex == gameObject.types.sapien.index then
        local normalizedPos = normalize(object.pos)
        clientState.directionNormal = normalize(normalize(logic.playerPos) - normalizedPos)
    end
end

function clientGOM:getClientState(object)
    local clientState = clientGOM.clientStates[object.uniqueID]
    if not clientState then
        clientState = {}

        setupDefaultClientState(object, clientState)

        clientGOM.clientStates[object.uniqueID] = clientState
    end
    return clientState
end

function clientGOM:getSharedState(object, createIfNil, ...)
    local sharedState = object.sharedState
    if not sharedState and createIfNil then
        if clientGOM:isStored(object.uniqueID) then
            object.sharedState = {}
            sharedState = object.sharedState
        else
            local stateFunction = gameObject.types[object.objectTypeIndex].initialTransientStateFunction
            if stateFunction then
                object.sharedState = stateFunction(object.uniqueID,
                object.objectTypeIndex,
                object.scale,
                object.pos)
            else
                object.sharedState = {}
            end
            sharedState = object.sharedState
        end
        --gameObjectSharedState:setupState(object, sharedState)
    end

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

function clientGOM:getObjectWithID(uniqueID)
    return allObjects[uniqueID]
end


local hiddenObjects = {}

function clientGOM:setObjectHidden(uniqueID, hidden)
    local change = false
    if not hiddenObjects[uniqueID] and hidden then
        hiddenObjects[uniqueID] = true
        change = true
    elseif hiddenObjects[uniqueID] and not hidden then
        hiddenObjects[uniqueID] = nil
        if (not allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode[uniqueID]) or buildModeIsActive or unhiddenLookAtGameObjectID == uniqueID then
            change = true
        end
    end

    if change then
        local object = clientGOM:getObjectWithID(uniqueID)
        object.hidden = hidden
        bridge:setObjectHidden(uniqueID, hidden)
    end
end

local uIHiddenDueToInactivity = false
local selectionHightlightObjectsByID = {}
local warningColorsObjectsByID = {}
local destructionWarningColorsObjectsByID = {}


function clientGOM:sendExtraRenderData(uniqueID)
    local brightness = 0.0
    local warningColor = 0.0
    if not uIHiddenDueToInactivity then
        brightness = selectionHightlightObjectsByID[uniqueID] or 0.0
        if warningColorsObjectsByID[uniqueID] then
            warningColor = warningColorsObjectsByID[uniqueID]
        elseif destructionWarningColorsObjectsByID[uniqueID] then
            warningColor = 0.5
        end
    end
    clientGOM:setExtraRenderData(uniqueID,vec3(brightness,warningColor,0.0)) --reduced from vec4 in 0.6, as the engine now uses the w value to provide the position relative to sea level in meters
end
    
function clientGOM:setObjectSelectionHighlightBrightness(uniqueID, brightness)
    if brightness > 0.001 then
        selectionHightlightObjectsByID[uniqueID] = brightness
    else
        selectionHightlightObjectsByID[uniqueID] = nil
    end
    clientGOM:sendExtraRenderData(uniqueID)
end

function clientGOM:clearAllSelectionHighlights()
    local prevSelectionHightlightObjectsByID = selectionHightlightObjectsByID
    selectionHightlightObjectsByID = {}
    for uniqueID,v in pairs(prevSelectionHightlightObjectsByID) do
        clientGOM:sendExtraRenderData(uniqueID)
    end
end

function clientGOM:setWarningColorForObject(uniqueID, value)
    if value ~= nil then
        warningColorsObjectsByID[uniqueID] = value
    else
        warningColorsObjectsByID[uniqueID] = nil
    end
    clientGOM:sendExtraRenderData(uniqueID)
end

function clientGOM:clearAllWarningColors()
    local prevWarningColorsObjectsByID = warningColorsObjectsByID
    warningColorsObjectsByID = {}
    for uniqueID,v in pairs(prevWarningColorsObjectsByID) do
        clientGOM:sendExtraRenderData(uniqueID)
    end
end

function clientGOM:setDestructionWarningForObject(uniqueID, value) --no longer used by the base game, but feels useful to keep supporting it for future featuers, so will leave this exposed for now
    if value then
        if (not destructionWarningColorsObjectsByID[uniqueID]) then
            destructionWarningColorsObjectsByID[uniqueID] = true
            clientGOM:sendExtraRenderData(uniqueID)
        end
    else
        if destructionWarningColorsObjectsByID[uniqueID] then
            destructionWarningColorsObjectsByID[uniqueID] = nil
            clientGOM:sendExtraRenderData(uniqueID)
        end
    end
end

function clientGOM:setSelectionHightlightForObjects(objectIDs, brightness)
    clientGOM:clearAllSelectionHighlights()
    for i,uniqueID in ipairs(objectIDs) do
        clientGOM:setObjectSelectionHighlightBrightness(uniqueID, brightness)
    end
end

function clientGOM:setWarningColorForObjects(objectIDs, value)
    clientGOM:clearAllWarningColors()
    for i,uniqueID in ipairs(objectIDs) do
        clientGOM:setWarningColorForObject(uniqueID, value)
    end
end

function clientGOM:setUIHiddenDueToInactivity(uIHiddenDueToInactivity_)
    if uIHiddenDueToInactivity ~= uIHiddenDueToInactivity_ then
        uIHiddenDueToInactivity = uIHiddenDueToInactivity_
        for uniqueID, v in pairs(selectionHightlightObjectsByID) do
            clientGOM:sendExtraRenderData(uniqueID)
        end
        for uniqueID, v in pairs(warningColorsObjectsByID) do
            clientGOM:sendExtraRenderData(uniqueID)
        end
        for uniqueID, v in pairs(destructionWarningColorsObjectsByID) do
            clientGOM:sendExtraRenderData(uniqueID)
        end
    end
end

function clientGOM:setLookAtObjectID(uniqueID)

    if unhiddenLookAtGameObjectID ~= uniqueID then
        if unhiddenLookAtGameObjectID then
            if not buildModeIsActive then
                local object = clientGOM:getObjectWithID(unhiddenLookAtGameObjectID)
                if object then
                    object.hidden = true
                    bridge:setObjectHidden(uniqueID, true)
                end
            end
            unhiddenLookAtGameObjectID = nil
        end

        if uniqueID then
            if allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode[uniqueID] then
                local object = clientGOM:getObjectWithID(uniqueID)
                if object and not hiddenObjects[uniqueID] then
                    object.hidden = false
                    bridge:setObjectHidden(uniqueID, false)
                end
                unhiddenLookAtGameObjectID = uniqueID
            end
        end
    end
    
    if unhiddenSubModelsLookAtGameObjectID ~= uniqueID then
        if unhiddenSubModelsLookAtGameObjectID then
            if not buildModeIsActive then
                local subModelsToUnHide = objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode[unhiddenSubModelsLookAtGameObjectID]
                if subModelsToUnHide then
                    local object = clientGOM:getObjectWithID(unhiddenSubModelsLookAtGameObjectID)
                    if object then
                        for i,key in ipairs(subModelsToUnHide) do
                            clientGOM:setSubModelHidden(object.uniqueID, key, true)
                        end
                    end
                end
            end
            unhiddenSubModelsLookAtGameObjectID = nil
        end

        if uniqueID then
            local subModelsToUnHide = objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode[uniqueID]
            if subModelsToUnHide then
                local object = clientGOM:getObjectWithID(uniqueID)
                if object then
                    for i,key in ipairs(subModelsToUnHide) do
                        clientGOM:setSubModelHidden(object.uniqueID, key, false)
                    end
                end
                unhiddenSubModelsLookAtGameObjectID = uniqueID
            end
        end
    end
end

function clientGOM:showObjectsForBuildModeStart()
    if not buildModeIsActive then
        buildModeIsActive = true
        for objectID,value in pairs(allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode) do
            local object = clientGOM:getObjectWithID(objectID)
            if object and not hiddenObjects[objectID] then
                object.hidden = false
                bridge:setObjectHidden(objectID, false)
            end
        end
        for objectID,subModelsToUnHide in pairs(objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode) do
            local object = clientGOM:getObjectWithID(objectID)
            if object then
                for i,key in ipairs(subModelsToUnHide) do
                    clientGOM:setSubModelHidden(object.uniqueID, key, false)
                end
            end
        end
    end
end

function clientGOM:hideObjectsForBuildModeEnd()
    if buildModeIsActive then
        buildModeIsActive = false
        for objectID,value in pairs(allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode) do
            if objectID ~= unhiddenLookAtGameObjectID then
                local object = clientGOM:getObjectWithID(objectID)
                if object then
                    object.hidden = true
                    bridge:setObjectHidden(objectID, true)
                end
            end
        end
        for objectID,subModelsToUnHide in pairs(objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode) do
            if objectID ~= unhiddenSubModelsLookAtGameObjectID then
                local object = clientGOM:getObjectWithID(objectID)
                if object then
                    for i,key in ipairs(subModelsToUnHide) do
                        clientGOM:setSubModelHidden(object.uniqueID, key, true)
                    end
                end
            end
        end
    end
end

local function createObjectInfo(object)
    return {
        uniqueID = object.uniqueID,
        found = true,
        loaded = true,
        follower = clientSapien:objectIsFollower(object.uniqueID) or nil,

        objectTypeIndex = object.objectTypeIndex,
        sharedState = clientGOM:getSharedState(object, true),
        clientState = clientGOM.clientStates[object.uniqueID],
        stored = bridge:isStored(object.uniqueID),

        pos = object.pos,
        scale = object.scale,
        rotation = object.rotation,
    }
end

function clientGOM:requestUnloadedStateForNotificationIfNeeded(uniqueID) --this basically registers it for more frequent updates even if the object is offscreen, so we can have reliable state to zoom to. Could be optimized to only send position perhaps
    local object = clientGOM:getObjectWithID(uniqueID)
    if not object then
        local followerInfo = clientSapien:getFollowerInfo(uniqueID)
        if not followerInfo then
            clientGOM:requestUnloadedObjectFromServer(uniqueID)
        end
    end
end

function clientGOM:retrieveObjectInfo(uniqueID, useStateDelta)
    local object = clientGOM:getObjectWithID(uniqueID)
    if not object then
        local followerInfo = clientSapien:getFollowerInfo(uniqueID)
        if followerInfo then
            local result =  {
                uniqueID = uniqueID,
                found = true,
                loaded = false,
                follower = true,

                objectTypeIndex = followerInfo.objectTypeIndex,
                sharedState = followerInfo.sharedState,
                clientState = nil,
                stored = true,

                pos = followerInfo.pos,
                scale = followerInfo.scale,
                rotation = followerInfo.rotation,
            }
            if useStateDelta then
                result.stateDelta = followerInfo.stateDelta
            else
                result.sharedState = followerInfo.sharedState
            end
            return result
        else
            clientGOM:requestUnloadedObjectFromServer(uniqueID) --this hould be OK, just ensures that we are paying attention to this object

            local unloadedInfo = unloadedObjectInfos[uniqueID]
            if unloadedInfo then
                return {
                    uniqueID = uniqueID,
                    found = true,
                    loaded = false,
                    follower = false,
    
                    objectTypeIndex = unloadedInfo.objectTypeIndex,
                    sharedState = unloadedInfo.sharedState,
                    stored = true,
    
                    pos = unloadedInfo.pos,
                    scale = unloadedInfo.scale,
                    rotation = unloadedInfo.rotation,
                }
            else
                return {
                    uniqueID = uniqueID,
                    found = false,
                    loaded = false,
                }
            end
        end
    end
    return createObjectInfo(object)
end

function clientGOM:retrieveObjectInfos(uniqueIDs)
    local result = {}
    for i,uniqueID in ipairs(uniqueIDs) do
        result[i] = clientGOM:retrieveObjectInfo(uniqueID, false)
    end
    return result
end

function clientGOM:hidableSubModelShouldBeHidden(objectID)
    return not buildModeIsActive and unhiddenSubModelsLookAtGameObjectID ~= objectID
end

function clientGOM:update(dt, worldTime, speedMultiplier)
    bridge:callFunctionForVisibleGameObjectsInSet(clientGOM.objectSets.sapiens, function(objectID)
        local object = allObjects[objectID]
        if object then
            clientSapien:update(object, dt, speedMultiplier)
        end
    end)
    bridge:callFunctionForVisibleGameObjectsInSet(clientGOM.objectSets.mobs, function(objectID)
        local object = allObjects[objectID]
        if object then
            clientMob:mobUpdate(object, dt, speedMultiplier)
        end
    end)
    bridge:callFunctionForVisibleGameObjectsInSet(clientGOM.objectSets.boats, function(objectID)
        local object = allObjects[objectID]
        if object then
            clientBoat:visibleObjectUpdate(object, dt, speedMultiplier)
        end
    end)
    
    gameObject:updateSeasonFraction(logic:getSeasonFraction(), worldTime)
    musicalInstrumentPlayer:update(dt, worldTime, speedMultiplier)
    
    clientBuildableObject:update()
    clientBuiltObject:update()
    clientPathBuildable:update()
    clientSapien:globalUpdate()
end


local planObjectUIInfos = {}

function clientGOM:getThisTribeFirstPlanStateForObjectSharedState(sharedState, matchingPlanTypeIndexOrNil)
    --mj:log("getPlanStatesForObjectSharedState:", sharedState.planStates, "logic.tribeID:", logic.tribeID)
    local bestPlanState = nil

    if sharedState then
        if sharedState.planStates then
            local planStatesForThisTribe = sharedState.planStates[logic.tribeID]
            if planStatesForThisTribe and planStatesForThisTribe[1] then

                if matchingPlanTypeIndexOrNil then
                    for i, planState in ipairs(sharedState.planStates[logic.tribeID]) do
                        if planState.planTypeIndex == matchingPlanTypeIndexOrNil then
                            if planState.canComplete then
                                return planState
                            end
                            bestPlanState = bestPlanState or planState
                        end
                    end
                else
                    bestPlanState = sharedState.planStates[logic.tribeID][1]
                    if (not bestPlanState.canComplete) then
                        for i, planState in ipairs(sharedState.planStates[logic.tribeID]) do
                            if planState.canComplete then
                                return planState
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPlanState
end

local function updatePlanObject(object, planState, assignedSapienIDs)

    --mj:log("updatePlanObject incomingServerState:", incomingServerState)

    --mj:log("updatePlanObject:", object.uniqueID, " planState:", planState)

    --[[local assignedSapienInfo = nil
    if planState and planState.manualAssignedSapien then
        local sapienInfo = clientGOM:retrieveObjectInfo(planState.manualAssignedSapien, false)
        if sapienInfo and sapienInfo.sharedState then
            if sapienInfo.sharedState.manualAssignedPlanObject == object.uniqueID then
                assignedSapienInfo = sapienInfo
            end
        end
    end]]

    --mj:log("a")
    --if not assignedSapienInfo then
        --mj:log("b:", assignedSapienIDs)
        --[[if assignedSapienIDs and planState then

            for assignedSapienID,planTypeIndexOrTrue in pairs(assignedSapienIDs) do
                local sapienInfo = clientGOM:retrieveObjectInfo(assignedSapienID, false)
                if sapienInfo and sapienInfo.sharedState then
                    local orderQueue = sapienInfo.sharedState.orderQueue
                    if orderQueue and orderQueue[1] then
                        local orderContext = orderQueue[1].context
                        if orderContext and 
                        (orderContext.planObjectID == object.uniqueID or (object.sharedState and orderContext.planObjectID == object.sharedState.haulObjectID))  and 
                        orderContext.planTypeIndex == planState.planTypeIndex and 
                        ((not planState.objectTypeIndex) or (not orderContext.objectTypeIndex) or orderContext.objectTypeIndex == planState.objectTypeIndex) then
                            --mj:log("found assigned sapien info:", sapienInfo)
                            assignedSapienInfo = sapienInfo
                            break
                        end
                    end
                end
            end]]
       -- end
   -- end

   local assignedSapienInfos = {}

   if assignedSapienIDs and planState then
        for assignedSapienID,planTypeIndexOrTrue in pairs(assignedSapienIDs) do
            local sapienInfo = clientGOM:retrieveObjectInfo(assignedSapienID, false)
            if sapienInfo and sapienInfo.sharedState then
                local orderQueue = sapienInfo.sharedState.orderQueue
                if orderQueue and orderQueue[1] then
                    local orderContext = orderQueue[1].context
                    if orderContext and 
                    (orderContext.planObjectID == object.uniqueID or (object.sharedState and orderContext.planObjectID == object.sharedState.haulObjectID))  and 
                    (orderContext.planTypeIndex == planState.planTypeIndex) and 
                    ((not planState.objectTypeIndex) or (not orderContext.objectTypeIndex) or orderContext.objectTypeIndex == planState.objectTypeIndex) then
                        --mj:log("found assigned sapien info:", sapienInfo)
                        table.insert(assignedSapienInfos, sapienInfo)
                    end
                end
            end
        end
    end

    if not next(assignedSapienInfos) then
        assignedSapienInfos = nil
    end

    local planInfo = nil
    if planState then
        local iconObjectTypeIndex = planHelper:getIconObjectTypeIndexForPlanState(object, planState)

        local attachBoneName = nil
        local offsets = gameObject.types[object.objectTypeIndex].markerPositions
        if object.objectTypeIndex == gameObject.types.sapien.index then
            attachBoneName = "head"
            offsets = sapienConstants:getSapienMarkerOffsetInfo(object.sharedState)
        end

        local isDestructive = plan.types[planState.planTypeIndex].isDestructive or (planState.researchTypeIndex and research.types[planState.researchTypeIndex].isDestructive)
        if isDestructive  then
            if planState.planTypeIndex == plan.types.banish.index and object.sharedState.tribeID ~= logic.tribeID then
                isDestructive = false
            end
        end

        planInfo = {
            uniqueID = object.uniqueID,
            basePos = object.pos,
            baseRotation = object.rotation,
            offsets = offsets,
            hasImpossiblePlan = (not planState.canComplete),
            disabledDueToOrderLimit = planState.disabledDueToOrderLimit,
            maintainQuantityThresholdMet = planState.maintainQuantityThresholdMet,
            hasMaintainQuantitySet = (planState.maintainQuantityOutputResourceCounts ~= nil),
            planTypeIndex = planState.planTypeIndex,
            iconObjectTypeIndex = iconObjectTypeIndex,
            vertID = object.sharedState.vertID,
            assignedSapienInfos = assignedSapienInfos,
            attachBoneName = attachBoneName,
            manuallyPrioritized = planState.manuallyPrioritized,
            isDestructive = isDestructive,
        }
    end

    if not planObjectUIInfos[object.uniqueID] then
        if planState then
            planObjectUIInfos[object.uniqueID] = {}
            --mj:log("addPlanInfo:",object.uniqueID, " planInfo:", planInfo)
            logic:callMainThreadFunction("addPlanInfo", planInfo)
        end
    else
       -- mj:log("updatePlanInfo:",object.uniqueID, " planInfo:", planInfo)
        if planState then
            if not planInfo.planTypeIndex then
                mj:error("no plan type index:", planInfo, " full shared state:", object.sharedState)
                error()
            end
            logic:callMainThreadFunction("updatePlanInfo", planInfo)
        else
            logic:callMainThreadFunction("removePlanInfo", {
                uniqueID = object.uniqueID
            })
            planObjectUIInfos[object.uniqueID] = nil
        end
    end
end

--local snapLength2 = mj:mToP(0.5) * mj:mToP(0.5)


function clientGOM:createSharedState(object)
    object.sharedState = {}
end


local objectWasLoadedFunctionsByObjectTypeIndex = {}
local objectSnapMatrixFunctionsByObjectTypeIndex = {}
local serverUpdateFunctionsByObjectTypeIndex = {}
local objectWasUnloadedFunctionsByObjectTypeIndex = {}
--local processNotificationsForRemovalByObjectTypeIndex = {}

local function updatePlanObjectAndMarkers(object)
    if object.sharedState.haulObjectID then --this probably shouldn't happen, the marker object shouldn't be updated. But just in case.
        local haulObjectInfo = clientGOM:retrieveObjectInfo(object.sharedState.haulObjectID, false)
        if haulObjectInfo and haulObjectInfo.found then
            local planState = clientGOM:getThisTribeFirstPlanStateForObjectSharedState(haulObjectInfo.sharedState, plan.types.haulObject.index)
            updatePlanObject(object, planState, haulObjectInfo.sharedState.assignedSapienIDs)
        else
            clientGOM:requestUnloadedObjectFromServer(object.sharedState.haulObjectID)
        end
    else
        local planState = clientGOM:getThisTribeFirstPlanStateForObjectSharedState(object.sharedState)
        updatePlanObject(object, planState, object.sharedState.assignedSapienIDs)
        
        if planState and planState.markerObjectID then
            
            --mj:log("clientGOM:serverUpdate for:", object.uniqueID, " with markerObjectID:", planState.markerObjectID)

            local markerObjectInfo = clientGOM:retrieveObjectInfo(planState.markerObjectID, false)
            if markerObjectInfo and markerObjectInfo.found then
               --mj:log("update marker planState:", planState, " assignedSapienIDs:", object.sharedState.assignedSapienIDs, " markerObjectInfo:", markerObjectInfo)
                updatePlanObject(markerObjectInfo, planState, object.sharedState.assignedSapienIDs)
            end
        end
    end
end

local action = mjrequire "common/action"
local actionSequence = mjrequire "common/actionSequence"
local function debugCheckPlanStatesValid(object, incomingServerStateDelta, prevSharedState)
    local planState = clientGOM:getThisTribeFirstPlanStateForObjectSharedState(object.sharedState)
    if planState then
        if not planState.planTypeIndex then
            mj:error("no plan type index:", object.uniqueID, " state:", object.sharedState)
            mj:log("incomingServerStateDelta:", incomingServerStateDelta)
            mj:log("prevSharedState:", prevSharedState)
            error()
        end
    end

    local actionState = object.sharedState and object.sharedState.actionState
    if actionState then
        local sequenceTypeIndex = actionState.sequenceTypeIndex
        if not sequenceTypeIndex then
            mj:error("no sequenceTypeIndex:", object.uniqueID, " state:", object.sharedState)
            mj:log("incomingServerStateDelta:", incomingServerStateDelta)
            mj:log("prevSharedState:", prevSharedState)
            error()
        end

        local actionSequenceActions = actionSequence.types[actionState.sequenceTypeIndex].actions
        local actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]

        if action.types[actionTypeIndex].isMovementAction then
            if not actionState.path then
                mj:error("no path:", object.uniqueID, " state:", object.sharedState)
                mj:log("incomingServerStateDelta:", incomingServerStateDelta)
                mj:log("prevSharedState:", prevSharedState)
                error()
            end
        end

    end
end

function clientGOM:serverUpdate(object, incomingServerStateDelta, pos, rotation, scale)

    --mj:log("serverUpdate:", object.objectTypeIndex)
    local prevSharedState = mj:cloneTable(object.sharedState)
    debugCheckPlanStatesValid(object, incomingServerStateDelta)
    if incomingServerStateDelta then
        gameObjectSharedState:mergeDelta(object, incomingServerStateDelta)
        debugCheckPlanStatesValid(object, incomingServerStateDelta, prevSharedState)
    end
    
    
    if (planObjectUIInfos[object.uniqueID] ~= nil or (object.sharedState and object.sharedState.planStates and object.sharedState.planStates[logic.tribeID])) then
        --mj:log("updatePlanObject:", object.uniqueID)

        clientGOM:addObjectToSet(object, clientGOM.objectSets.planObjects)
        updatePlanObjectAndMarkers(object)
    else
        clientGOM:removeObjectFromSet(object, clientGOM.objectSets.planObjects)
    end

    local serverUpdateFunctions = serverUpdateFunctionsByObjectTypeIndex[object.objectTypeIndex]
    if serverUpdateFunctions then
        --mj:log("serverUpdateFunctions object.uniqueID:", object.uniqueID, " pos:", pos, " rotation:", rotation)
        for i,func in ipairs(serverUpdateFunctions) do
            func(object, pos, rotation, scale, incomingServerStateDelta)
        end

        --clientGOM:updateMatrix(object.uniqueID, pos, rotation) this performs a snap every server update
    end

    if currentRegisteredServerUpdateNotificationIDs[object.uniqueID] then
        local useStateDelta = nil
        if initialStateSentIDs[object.uniqueID] then
            useStateDelta = true
        else
            initialStateSentIDs[object.uniqueID] = true
        end
        logic:callMainThreadFunction("registeredObjectServerStateChanged", clientGOM:retrieveObjectInfo(object.uniqueID, useStateDelta))
    end

    terrain:objectChanged(object)

    clientObjectNotifications:callAnyNotificationsForObjectUpdate(object)
end

function clientGOM:gameObjectWasLoaded(object, subdivLevel, terrainVariations, incomingServerState, pos, rotation, scale)

    --mj:log("load object:", object.uniqueID)
    allObjects[object.uniqueID] = object

    object.sharedState = incomingServerState
    object.subdivLevel = subdivLevel

    debugCheckPlanStatesValid(object, nil)
    
    object.modelIndex = gameObject:modelIndexForGameObjectAndLevel(object, subdivLevel, terrainVariations)
    if object.modelIndex then
        bridge:setModelIndex(object.uniqueID, object.modelIndex)
    end

    local gameObjectTypeInfo = gameObject.types[object.objectTypeIndex]
    if gameObjectTypeInfo.visibleOnlyWhenLookedAtOrBuildMode then
        if not buildModeIsActive then
            object.hidden = true
            bridge:setObjectHidden(object.uniqueID, true)
        end
        allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode[object.uniqueID] = true
    end

    
    local decalBlockers = nil

    if object.sharedState then
        decalBlockers = object.sharedState.decalBlockers
    end

    if gameObjectTypeInfo.decalBlockRadius2 then
        local decalBlockersToUse = {
            {
                pos = object.pos,
                radius2 = gameObjectTypeInfo.decalBlockRadius2,
            },
        }
        if decalBlockers then
            for i, blocker in ipairs(decalBlockers) do
                table.insert(decalBlockersToUse, blocker)
            end
        end
        decalBlockers = decalBlockersToUse
    end

    if decalBlockers then
        --mj:log("decalBlockers for:", object.uniqueID, " is:", decalBlockers)
        clientGOM:setDecalBlockers(object.uniqueID, decalBlockers)
    end

    objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode[object.uniqueID] = gameObjectTypeInfo.visibleOnlyWhenLookedAtOrBuildModeSubModels

    if incomingServerState then
        clientGOM:addObjectToSet(object, clientGOM.objectSets.planObjects)
        updatePlanObjectAndMarkers(object)
    end

    local objectWasLoadedFunctions = objectWasLoadedFunctionsByObjectTypeIndex[object.objectTypeIndex]
    if objectWasLoadedFunctions then
        for i,func in ipairs(objectWasLoadedFunctions) do
            func(object, pos, rotation, scale)
        end
    end

    
    terrain:objectChanged(object)

end

function clientGOM:updatePlanObjectsForTribeSelection()
    clientGOM:callFunctionForObjectsInSet(clientGOM.objectSets.planObjects, function(objectID)
        local object = clientGOM:getObjectWithID(objectID)
        if object then
            updatePlanObjectAndMarkers(object)
        end
    end)
end

local function cleanupForObjectRemovalOrTypeChange(object)

    local clientState = clientGOM.clientStates[object.uniqueID]
    if clientState then
        if clientState.emitterID then
           -- mj:log("remov emitter:", clientState.emitterID)
            particleManagerInterface:removeEmitter(clientState.emitterID)
        end
        if clientState.animationSent then
            logic:callMainThreadFunction("removeAnimationObject", object.uniqueID)
        end
        if clientState.lightAdded then
            logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
        end
        if clientState.soundAdded then
            logicAudio:removeLoopingSoundForObject(object)
        end
        if clientState.swimmingEmitterID then
            particleManagerInterface:removeEmitter(clientState.swimmingEmitterID)
        end
    end
end

function clientGOM:gameObjectWillBeUnloaded(objectID, objectWasRemovedFromWorld)

    --mj:log("unload object:", objectID, " objectWasRemovedFromWorld:", objectWasRemovedFromWorld)

    local object = allObjects[objectID]
    
    allObjectIDsVisibleOnlyWhenLookedAtOrBuildMode[object.uniqueID] = nil
    objectIDsWithSubModelsVisibleOnlyWhenLookedAtOrBuildMode[object.uniqueID] = nil

    
    local objectWasUnLoadedFunction = objectWasUnloadedFunctionsByObjectTypeIndex[object.objectTypeIndex]
    if objectWasUnLoadedFunction then
        objectWasUnLoadedFunction(object)
    end

    logic:callMainThreadFunction("objectWasUnloaded", object.uniqueID)

    if planObjectUIInfos[object.uniqueID] then
        logic:callMainThreadFunction("removePlanInfo", {
            uniqueID = object.uniqueID
        })
        planObjectUIInfos[object.uniqueID] = nil
    end

    cleanupForObjectRemovalOrTypeChange(object)
    
    local clientState = clientGOM.clientStates[object.uniqueID]
    if clientState then
        clientGOM.clientStates[object.uniqueID] = nil
    end
    
    
    if objectWasRemovedFromWorld then
        unloadedObjectInfos[objectID] = nil
        --mj:log("set nil")
    else
        local info = unloadedObjectInfos[objectID]
        --mj:log("info:", info)

        if info then
            info.sharedState = object.sharedState
            info.pos = object.pos
            info.rotation = object.rotation
        else
            --mj:log("object type:", gameObject.types[object.objectTypeIndex])
            if gameObject.types[object.objectTypeIndex].keepLoadedOnClient then
                --mj:log("object was moved to unloaded:", objectID)
                unloadedObjectInfos[objectID] = object
            end
        end
    end

    
    allObjects[objectID] = nil

end

function clientGOM:gameObjectTypeChanged(object, incomingServerStateDelta, incomingServerStateComplete, pos, rotation, scale, subdivLevel, terrainVariations)
    --mj:log("gameObjectTypeChanged:", object.uniqueID, " - ", gameObject.types[object.objectTypeIndex], " pos:", pos, " rotation:", rotation)

    local gameObjectType = gameObject.types[object.objectTypeIndex]

    if not gameObjectType.resourceTypeIndex then --this might need to be better targeted. Makes sure that if a resource is turned into a craft area, it won't have physics
        clientGOM:setDynamicPhysics(object.uniqueID, false)
    end

    if gameObjectType.isPlacedObject then
        clientGOM:setTransparentBuildObject(object.uniqueID, false)
    end

    cleanupForObjectRemovalOrTypeChange(object)
    bridge:removeObjectFromAllSets(object.uniqueID)
    clientGOM:removeAllSubmodels(object.uniqueID)
    if incomingServerStateDelta then
        gameObjectSharedState:mergeDelta(object, incomingServerStateDelta)
    elseif incomingServerStateComplete then
        object.sharedState = incomingServerStateComplete
    end
    clientGOM:setDecalBlockers(object.uniqueID, nil)
    clientGOM:gameObjectWasLoaded(object, subdivLevel, terrainVariations, object.sharedState, pos, rotation, scale)
end

function clientGOM:reloadModelIfNeededForObject(objectID)
    bridge:reloadModelIfNeededForObject(objectID)
end

function clientGOM:initialMorphTargetWeightsForObject(objectID, count)
    local object = allObjects[objectID]
    if object then
        return modelMorphTargets:randomizedWeights(object.uniqueID, object.modelIndex, count)
    end
end

function clientGOM:registerServerStateChangeMainThreadNotificationsForObjects(uniqueIDs)
    for i, uniqueID in ipairs(uniqueIDs) do
        currentRegisteredServerUpdateNotificationIDs[uniqueID] = true
    end
end

function clientGOM:deregisterServerStateChangeMainThreadNotificationsForObjects(uniqueIDs)
    for i, uniqueID in ipairs(uniqueIDs) do
        currentRegisteredServerUpdateNotificationIDs[uniqueID] = nil
        initialStateSentIDs[uniqueID] = nil
    end
end


function clientGOM:addObjectCallbackTimerForWorldTime(objectID, time, func)
    bridge:addObjectCallbackTimerForWorldTime(objectID, time, func)
end

function clientGOM:setBridge(bridge_)
    bridge = bridge_
    gameObjectSharedState:init(clientGOM)
    worldHelper:setGOM(clientGOM, modelPlaceholder)
    
    gameObject:setYearLength(1.0 / logic.yearSpeed)
    gameObject:updateSeasonFraction(logic:getSeasonFraction(), logic.worldTime)
    gameObject:setLocalTribeID(logic.tribeID)
    
	for i,gameObjectType in ipairs(gameObject.validTypes) do
        gameObjectType.modelFunction = gameObjectType.clientModelFunction
    end

    bridge.objectTypeChangedFunction = function(objectID, newGameObjectType, incomingServerStateDelta, incomingServerStateComplete, pos, rotation, scale, subdivLevel, terrainVariations)
        local object = allObjects[objectID]
        if object then
            object.objectTypeIndex = newGameObjectType
            clientGOM:gameObjectTypeChanged(object, incomingServerStateDelta, incomingServerStateComplete, pos, rotation, scale, subdivLevel, terrainVariations)
        else
            mj:error("objectTypeChangedFunction called for object not loaded:", objectID)
        end
    end

    bridge.defaultDeltaUpdateFunction = function(objectID, sharedStateDelta)
        local object = allObjects[objectID]
        if object then
            gameObjectSharedState:mergeDelta(object, sharedStateDelta)
        end
    end

    --[[if gameObjectSharedState.enableDebugDeltaCompression then
        bridge.debugDeltaUpdateVerifyFunction = function(objectID, sharedStateComplete) --todo comment this out before release, and stop sending full state alongside delta
            local object = allObjects[objectID]
            if object then
                gameObjectSharedState:debugVerifyDeltaUpdate(object, sharedStateComplete)
            end
        end
    end]]

    bridge.serverUpdateFunction = function(objectID, incomingServerStateDelta_, pos_, rotation_, scale_)
        local object = allObjects[objectID]
        if object then
            if not object.sharedState then
                return
            end
            clientGOM:serverUpdate(object, incomingServerStateDelta_, pos_, rotation_, scale_)
        else
            mj:error("serverUpdateFunction called for object not loaded:", objectID)
            error()
        end
    end

    

    bridge.fullGameObjectStateReceivedFunction = function (objectID, incomingServerStateComplete, pos, rotation, scale)
        local object = allObjects[objectID]
        if object then
            --mj:log("fullGameObjectStateReceivedFunction:", objectID, " incomingServerStateComplete:", incomingServerStateComplete)
            object.sharedState = incomingServerStateComplete
            clientGOM:serverUpdate(object, nil, pos, rotation, scale)
        else
            mj:error("fullGameObjectStateReceivedFunction called for object not loaded:", objectID)
           -- error()
        end
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

    --[[bridge.notificationsForRemovalFunction = function(objectID, notifications_)
       -- mj:log("notificationsForRemovalFunction:", objectID, " notifications_:", notifications_)
        local object = allObjects[objectID]
        if not object then
            object = clientSapien:getFollowerInfoIncludingRemoved(objectID)
        end
        if object then
           -- mj:log("notificationsForRemovalFunction object found")
            local processNotificationsForRemovalFunction = processNotificationsForRemovalByObjectTypeIndex[object.objectTypeIndex]
            if processNotificationsForRemovalFunction then
                --mj:log("processNotificationsForRemovalFunction found")
                processNotificationsForRemovalFunction(object, notifications_)
            end
        end
    end]]

    bridge.snapObjectFunction = function(objectID, pos, rotation, velocity)
        local object = allObjects[objectID]

        clientGOM:setLinearVelocity(objectID, velocity)
        clientGOM:updateMatrix(objectID, pos, rotation)

        --mj:log("snap object:", objectID, " pos:", pos)
        
        clientGOM:clearCachedSubmodelTransforms(object)
        local objectSnapMatrixFunctions = objectSnapMatrixFunctionsByObjectTypeIndex[object.objectTypeIndex]
        if objectSnapMatrixFunctions then
            for i,func in ipairs(objectSnapMatrixFunctions) do
                func(object, pos, rotation)
            end
        end
    end

    clientGOM.objectSets = {
        sapiens = bridge:createObjectSet("sapiens"),
        mobs = bridge:createObjectSet("mobs"),
        boats = bridge:createObjectSet("boats"),

        temperatureIncreasers = bridge:createObjectSet("temperatureIncreasers"),
        temperatureDecreasers = bridge:createObjectSet("temperatureDecreasers"),

        planObjects = bridge:createObjectSet("planObjects"),
        pathSnappables = bridge:createObjectSet("pathSnappables")
    }

    logic:setClientGOM(clientGOM, clientSapien)
    clientObjectAnimation:init(clientGOM)
    clientConstruction:init(clientGOM)
    clientBuildableObject:init(clientGOM)
    clientBuiltObject:init(clientGOM)
    clientPathBuildable:init(clientGOM)
    clientFlora:init(clientGOM)
    clientSapien:init(clientGOM)
    clientMob:init(clientGOM)
    clientBoat:init(clientGOM)
    clientCraftArea:init(clientGOM)
    clientStorageArea:init(clientGOM)
    clientCampfire:init(clientGOM)
    clientKiln:init(clientGOM)
    clientTorch:init(clientGOM)
    clientLitObject:init(clientGOM)
    clientCompostBin:init(clientGOM)
    musicalInstrumentPlayer:init(logic, clientGOM)
    clientObjectNotifications:init(logic, clientGOM)

    
    local function addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, loaderObject)
        local loadFunc = loaderObject.objectWasLoaded
        if loadFunc then
            if not objectWasLoadedFunctionsByObjectTypeIndex[gameObjectTypeIndex] then 
                objectWasLoadedFunctionsByObjectTypeIndex[gameObjectTypeIndex] = {}
            end
            table.insert(objectWasLoadedFunctionsByObjectTypeIndex[gameObjectTypeIndex], loadFunc)
        end
        local serverUpdateFunc = loaderObject.serverUpdate
        if serverUpdateFunc then
            if not serverUpdateFunctionsByObjectTypeIndex[gameObjectTypeIndex] then 
                serverUpdateFunctionsByObjectTypeIndex[gameObjectTypeIndex] = {}
            end
            table.insert(serverUpdateFunctionsByObjectTypeIndex[gameObjectTypeIndex], serverUpdateFunc)
        end

        local objectSnapMatrixFunc = loaderObject.objectSnapMatrix
        if objectSnapMatrixFunc then
            if not objectSnapMatrixFunctionsByObjectTypeIndex[gameObjectTypeIndex] then 
                objectSnapMatrixFunctionsByObjectTypeIndex[gameObjectTypeIndex] = {}
            end
            table.insert(objectSnapMatrixFunctionsByObjectTypeIndex[gameObjectTypeIndex], objectSnapMatrixFunc)
        end

        local detailLevelChangedFunc = loaderObject.objectDetailLevelChanged
        if detailLevelChangedFunc then
            --[[if not objectDetailLevelChangedFunctionsByObjectTypeIndex[gameObjectTypeIndex] then 
                objectDetailLevelChangedFunctionsByObjectTypeIndex[gameObjectTypeIndex] = {}
            end
            table.insert(objectDetailLevelChangedFunctionsByObjectTypeIndex[gameObjectTypeIndex], detailLevelChangedFunc)]]
            bridge:setObjectDetailLevelChangedCallbackFunctionForObjectType(gameObjectTypeIndex, loaderObject.objectDetailLevelChanged)
        end
    end
    
    
    local excludeBuiltObjectFunctionsByType = {
        [gameObject.types.campfire.index] = true,
        [gameObject.types.brickKiln.index] = true,
        [gameObject.types.torch.index] = true,
        [gameObject.types.compostBin.index] = true,
    }
    local excludeInProgressBuildObjectFunctionsByType = {
    }
    
    for i,gameObjectTypeIndex in ipairs(gameObject.storageAreaTypes) do
        addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientStorageArea)
        local buildKey = "build_" .. gameObject.types[gameObjectTypeIndex].key
        local buildObjectType = gameObject.types[buildKey]
        addLoadAndUpdateFunctionsForObjectType(buildObjectType.index, clientStorageArea)
        excludeBuiltObjectFunctionsByType[gameObjectTypeIndex] = true
    end
    
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.craftArea.index, clientCraftArea)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.build_craftArea.index, clientCraftArea)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.temporaryCraftArea.index, clientCraftArea)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.terrainModificationProxy.index, clientCraftArea)

    for i,gameObjectTypeIndex in ipairs(gameObject.floraTypes) do
        addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientFlora)
    end

    addLoadAndUpdateFunctionsForObjectType(gameObject.types.campfire.index, clientCampfire)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.brickKiln.index, clientKiln)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.compostBin.index, clientCompostBin)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.torch.index, clientTorch)
    for i,gameObjectTypeIndex in ipairs(gameObject.burntObjectTypes) do
        addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientLitObject)
    end

    bridge:setReloadModelOnTerrainVariationChangedForObjectType(gameObject.types.pine1.index)
    bridge:setReloadModelOnTerrainVariationChangedForObjectType(gameObject.types.pine2.index)
    bridge:setReloadModelOnTerrainVariationChangedForObjectType(gameObject.types.pine3.index)
    bridge:setReloadModelOnTerrainVariationChangedForObjectType(gameObject.types.pine4.index)

    -- in progress build objects
    for i, gameObjectTypeIndex in ipairs(gameObject.pathInProgressBuildBuildableTypes) do
        addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientPathBuildable)
        excludeInProgressBuildObjectFunctionsByType[gameObjectTypeIndex] = true
        excludeBuiltObjectFunctionsByType[gameObjectTypeIndex] = true
    end

    for i, gameObjectTypeIndex in ipairs(gameObject.inProgressBuildObjectTypes) do
        if not excludeInProgressBuildObjectFunctionsByType[gameObjectTypeIndex] then
            addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientBuildableObject)
            excludeBuiltObjectFunctionsByType[gameObjectTypeIndex] = true
        end
    end

    -- completed built objects
    for i, gameObjectTypeIndex in ipairs(gameObject.pathBuildableTypes) do
        addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientPathBuildable)
        excludeBuiltObjectFunctionsByType[gameObjectTypeIndex] = true
    end

    for i, gameObjectTypeIndex in ipairs(gameObject.preservesConstructionObjectsObjectTypes) do
        if not excludeBuiltObjectFunctionsByType[gameObjectTypeIndex] then
            addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientBuiltObject)
        end
    end
    
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.sapien.index, clientSapien)
    objectWasUnloadedFunctionsByObjectTypeIndex[gameObject.types.sapien.index] = clientSapien.objectWillBeUnloaded
    --processNotificationsForRemovalByObjectTypeIndex[gameObject.types.sapien.index] = clientSapien.processNotificationsForObjectRemoval

    for i,gameObjectTypeIndex in ipairs(mob.gameObjectIndexes) do
        addLoadAndUpdateFunctionsForObjectType(gameObjectTypeIndex, clientMob)
    end


    addLoadAndUpdateFunctionsForObjectType(gameObject.types.canoe.index, clientBoat)
    addLoadAndUpdateFunctionsForObjectType(gameObject.types.coveredCanoe.index, clientBoat)

    bridge:setCameraMaxHeightInfluencerObjectTypes(gameObject.blocksRainTypes)

    bridge:setDontCacheObjectTypes(gameObject.dontCacheObjectTypes)

end

function clientGOM:setTerrain(terrain_)
    terrain = terrain_
end

local requestedUnloadedObjects = {}

local function updatePlansForUnloadedObject(object)
    local planState = clientGOM:getThisTribeFirstPlanStateForObjectSharedState(object.sharedState, plan.types.haulObject.index)
    --mj:log("unloaded object planState:", planState)
    if planState and planState.markerObjectID then
        local markerObjectInfo = clientGOM:retrieveObjectInfo(planState.markerObjectID, false)
        if markerObjectInfo and markerObjectInfo.found then
            --mj:log("unloaded object updatePlanObject markerObjectInfo:", markerObjectInfo)
            updatePlanObject(markerObjectInfo, planState, object.sharedState.assignedSapienIDs)
        end
    end
end

function clientGOM:requestUnloadedObjectFromServer(objectID)
    --mj:log("clientGOM:requestUnloadedObjectFromServer:", objectID)
    if not requestedUnloadedObjects[objectID] then
        requestedUnloadedObjects[objectID] = true
        logic:callServerFunction("requestUnloadedObject", {
            objectID = objectID,
        }, function(object)
            --mj:log("clientGOM:requestUnloadedObjectFromServer callback:", object)
            if object then
                unloadedObjectInfos[object.uniqueID] = object

                updatePlansForUnloadedObject(object)
            end
            requestedUnloadedObjects[objectID] = nil
        end)
    end
end

function clientGOM:unloadedObjectUpdate(uniqueID, incomingServerStateDelta, posOrNil, rotationOrNil, scaleOrNil)
    if clientSapien:objectIsFollower(uniqueID) then
        --mj:log("unloaded follower update:", uniqueID)
        clientSapien:updateUnloadedFollower(uniqueID, incomingServerStateDelta, posOrNil, rotationOrNil, scaleOrNil)
        if currentRegisteredServerUpdateNotificationIDs[uniqueID] then
            logic:callMainThreadFunction("registeredObjectServerStateChanged", clientGOM:retrieveObjectInfo(uniqueID, false))
        end
    else
        --mj:log("unloaded object update:", uniqueID)
        local object = unloadedObjectInfos[uniqueID]
        if object and object.sharedState then
            --mj:log("object update:", object.objectTypeIndex)
            gameObjectSharedState:mergeDelta(object, incomingServerStateDelta)
            if posOrNil then
                object.pos = posOrNil
            end
            if rotationOrNil then
                object.rotation = rotationOrNil
            end
            updatePlansForUnloadedObject(object)
        --else
            --mj:log("unloaded object update:", uniqueID)
        end
    end
end

function clientGOM:unloadedObjectWasRemoved(uniqueID)
    unloadedObjectInfos[uniqueID] = nil
end

function clientGOM:addObjectToSet(object, set)
    bridge:addObjectToSet(object.uniqueID, set)
end

function clientGOM:removeObjectFromSet(object, setIndex)
    bridge:removeObjectFromSet(object.uniqueID, setIndex)
end

function clientGOM:getCompositeModelInfo(objectID)
    local object = allObjects[objectID]
    if object then
        return gameObject:getCompositeModelInfo(object)
    end
    return nil
end

function clientGOM:getPlaceholderRotationForObject(object, placeholderName)
    return bridge:getPlaceholderRotationForObject(object.uniqueID, placeholderName)
end

function clientGOM:getOffsetForPlaceholderInObject(object, placeholderName)
    return bridge:getOffsetForPlaceholderInObject(object.uniqueID, placeholderName)
end

function clientGOM:getOffsetForPlaceholderInModel(modelIndex, rotation, scale, placeholderKey)
    return bridge:getOffsetForPlaceholderInModel(modelIndex, rotation, scale, placeholderKey)
end

function clientGOM:getPlaceholderRotationForModel(modelIndex, placeholderKey)
    return bridge:getPlaceholderRotationForModel(modelIndex, placeholderKey)
end

function clientGOM:getLocalOffsetForPlaceholderInModel(modelIndex, placeholderKey)
    return bridge:getLocalOffsetForPlaceholderInModel(modelIndex, placeholderKey)
end

function clientGOM:getPlaceholderScaleForModel(modelIndex, placeholderKey)
    return bridge:getPlaceholderScaleForModel(modelIndex, placeholderKey)
end

function clientGOM:getCloseObjectTemperatureOffset(objectPos)
    local offset = 0
    if clientGOM:getGameObjectExistsInSetWithinRadiusOfPos(clientGOM.objectSets.temperatureIncreasers, objectPos, gameConstants.fireWarmthRadius) then --also change in serverGOM or factor out
        offset = offset + 1
    end
    if clientGOM:getGameObjectExistsInSetWithinRadiusOfPos(clientGOM.objectSets.temperatureDecreasers, objectPos, gameConstants.fireWarmthRadius) then --also change in serverGOM or factor out
        offset = offset - 1
    end
    return offset
end

function clientGOM:clearCachedSubmodelTransforms(object)
    local clientState = clientGOM:getClientState(object)
    clientState.cachedSubmodelTransforms = nil
end

function clientGOM:getSubModelTransformForModel(modelIndex, pos, rotation, scale, placeholderName, parentObjectIDOrNil, resourceTypeIndexOrNil)
    
    local object = nil
    local cachedTransforms = nil

    local function loadCachedTransforms()
        if not cachedTransforms then
            local clientState = clientGOM:getClientState(object)
            cachedTransforms = clientState.cachedSubmodelTransforms
            if not cachedTransforms then
                cachedTransforms = {}
                clientState.cachedSubmodelTransforms = cachedTransforms
            end
        end
    end

    if parentObjectIDOrNil then
        object = clientGOM:getObjectWithID(parentObjectIDOrNil)
        
        if object and (not object.dynamicPhysics) then
            if object.subdivLevel < mj.SUBDIVISIONS - 1 then --only use the cached value if we're at a lower detail level. Otherwise recalculate, as the environment might have changed
                loadCachedTransforms()
                if cachedTransforms[modelIndex] then
                    local result = cachedTransforms[modelIndex][placeholderName]
                    if result then
                        return result
                    end
                end
            end
        end
    end

    local result = worldHelper:getSubModelTransformForModel(modelIndex, pos, rotation, scale, placeholderName, parentObjectIDOrNil, resourceTypeIndexOrNil)

    if object and object.subdivLevel == mj.SUBDIVISIONS - 1 then
        loadCachedTransforms()
        if not cachedTransforms[modelIndex] then
            cachedTransforms[modelIndex] = {}
        end
        cachedTransforms[modelIndex][placeholderName] = result
    end
    return result
end

function clientGOM:getSubModelTransform(object, placeholderName)
    return clientGOM:getSubModelTransformForModel(object.modelIndex, object.pos, object.rotation, object.scale, placeholderName, object.uniqueID)
end

function clientGOM:getGameObjectsOfTypesWithinRadiusOfPos(types, pos, radius)
    return bridge:getGameObjectsOfTypesWithinRadiusOfPos(types, pos, radius)
end

--should be much faster than getGameObjectsOfTypesWithinRadiusOfPos Particularly fast for radius of < 20 meters, even with large sets. Quite a bit slower with large object sets above that
--returns object and distance2 in table
function clientGOM:getGameObjectsInSetWithinRadiusOfPos(setIndex, pos, radius) 
    return bridge:getGameObjectsInSetWithinRadiusOfPos(setIndex, pos, radius)
end

function clientGOM:getGameObjectsInSetsWithinNormalizedRadiusOfPos(setIndexes, normalizedPos, radius) --as above but radius is calculated as the crow flies (compares normalized pos), and takes an array of indexes
    return bridge:getGameObjectsInSetsWithinNormalizedRadiusOfPos(setIndexes, normalizedPos, radius)
end

function clientGOM:getAllGameObjectsWithinRadiusOfPos(pos, radius) --much faster if < 20m. returns object and distance2 in table
    return bridge:getAllGameObjectsWithinRadiusOfPos(pos, radius)
end

function clientGOM:getAllGameObjectsWithinRadiusOfNormalizedPos(pos, radius)
    return bridge:getAllGameObjectsWithinRadiusOfNormalizedPos(pos, radius)
end

function clientGOM:getGameObjectExistsInSetWithinRadiusOfPos(setIndex, pos, radius) --as above speed and accuracy-wise
    return bridge:getGameObjectExistsInSetWithinRadiusOfPos(setIndex, pos, radius)
end


function clientGOM:getGameObjectINFOsOfTypesWithinRadiusOfPos(types, pos, radius, tribeRestrictInfo)
    local objectIDs = bridge:getGameObjectsOfTypesWithinRadiusOfPos(types, pos, radius)
    local result = {}
    local addIndex = 1
    for i,objectID in ipairs(objectIDs) do
        local object = allObjects[objectID]
        if object then
            if (not tribeRestrictInfo) or (not object.sharedState) or (not object.sharedState.tribeID) or tribeRestrictInfo.match == object.sharedState.tribeID or (tribeRestrictInfo.exclude and tribeRestrictInfo.exclude ~= object.sharedState.tribeID) then
                result[addIndex] = createObjectInfo(object)
                addIndex = addIndex + 1
            end
        end
    end
    return result
end

function clientGOM:getGameObjectIDsOfTypesWithinRadiusOfPos(types, pos, radius, tribeRestrictInfo)
    local objectIDs = bridge:getGameObjectsOfTypesWithinRadiusOfPos(types, pos, radius)
    local result = {}
    local addIndex = 1
    for i,objectID in ipairs(objectIDs) do
        local object = allObjects[objectID]
        if object then
            if (not tribeRestrictInfo) or tribeRestrictInfo.match == object.sharedState.tribeID or (tribeRestrictInfo.exclude and tribeRestrictInfo.exclude ~= object.sharedState.tribeID) then
                result[addIndex] = object.uniqueID
                addIndex = addIndex + 1
            end
        end
    end
    return result
end

function clientGOM:getGameObjectINFOsForIDs(objectIDs)
    local result = {}
    local addIndex = 1
    for i,uniqueID in ipairs(objectIDs) do
        local object = clientGOM:getObjectWithID(uniqueID)
        if object then
            result[addIndex] = createObjectInfo(object)
            addIndex = addIndex + 1
        end
    end
    return result
end

local cameraCloseDistance = mj:mToP(200.0) * mj:mToP(200.0)
function clientGOM:getIsCloseInPlayerCameraView(objectPos)
    local objectVec = objectPos - logic.playerPos
    local distance = length2(objectVec)
    if distance < cameraCloseDistance then
        local viewDot = dot(objectVec, logic.playerDir)
        return viewDot > 0.0
    end
end

function clientGOM:updateMatrix(objectID, pos, rotation)
    local object = allObjects[objectID]
    if object then

        object.basePos = pos
        object.baseRotation = rotation

        if object.animationTransformPos then
            object.pos = pos + object.animationTransformPos
        else
            object.pos = pos
        end
        object.normalizedPos = normalize(object.pos)

        if object.animationTransformRotation then
            object.rotation = rotation * object.animationTransformRotation
        else
            object.rotation = rotation
        end

        --mj:objectLogTraceback(objectID, "clientGOM:updateMatrix:", rotation)

        bridge:updateMatrix(objectID, object.pos, object.rotation)
    end
end


function clientGOM:setAnimationTransform(objectID, translation, rotation)

    local object = allObjects[objectID]
    if object then
        object.animationTransformRotation = rotation
        object.animationTransformTranslation = translation
        clientGOM:updateMatrix(objectID, object.basePos or object.pos, object.baseRotation or object.rotation)
    end
end

function clientGOM:setSubModelForKey(
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

    local scaleToUse = scale
    if type(scale) == "number" then
        scaleToUse = vec3(scale,scale,scale)
    end

    bridge:setSubModelForKey(
        objectID, 
        subModelKey,
        placeholderKeyOrNil,
        modelIndex,
        scaleToUse,
        renderType,
        translation,
        rotation,
        addToPhysics,
        subModelSubModelInfosOrNil)

end

function clientGOM:setSubModelTransform(objectID, key, translation, scale, rotation) --alternatively you can repeat calls to setSubModelForKey, as this will be called internally if nothing else changed. 
    bridge:setSubModelTransform(objectID, key, translation, scale, rotation)
end

function clientGOM:removeSubModelForKey(uniqueID, key)
    bridge:removeSubModelForKey(uniqueID, key)
end


function clientGOM:removeAllSubmodels(uniqueID, excludeArrayOrNil)
    --[[if uniqueID == mj.debugObject then
        mj:debug("removeAllSubmodels:", uniqueID)
    end]]
    bridge:removeAllSubmodels(uniqueID, excludeArrayOrNil)
end

function clientGOM:applyImpulse(objectID, impulseVec)
    bridge:applyImpulse(objectID, impulseVec)
end

function clientGOM:getLinearVelocity(objectID)
    return bridge:getLinearVelocity(objectID)
end

function clientGOM:getAngularVelocity(objectID)
    return bridge:getAngularVelocity(objectID)
end

function clientGOM:setLinearVelocity(objectID, vel)
    bridge:setLinearVelocity(objectID, vel)
end

function clientGOM:setAngularVelocity(objectID, velA)
    bridge:setAngularVelocity(objectID, velA)
end

function clientGOM:setDynamicPhysics(objectID, dynamicPhysics)
    local object = allObjects[objectID]
    if object then
        object.dynamicPhysics = dynamicPhysics
        bridge:setDynamicPhysics(objectID, dynamicPhysics)
    end
end

function clientGOM:setTransparentBuildObject(objectID, transparentBuildObject)
    bridge:setTransparentBuildObject(objectID, transparentBuildObject)
end

function clientGOM:setDynamicRenderOverride(objectID, dynamicRenderOverride)
    bridge:setDynamicRenderOverride(objectID, dynamicRenderOverride)
end

function clientGOM:setSubModelHidden(objectID, key, hidden)
    bridge:setSubModelHidden(objectID, key, hidden)
end

function clientGOM:setExtraRenderData(objectID, extraRenderDataVec3)
    bridge:setExtraRenderData(objectID, extraRenderDataVec3)
end

function clientGOM:setCovered(objectID, covered) --this is only used to inform the renderer if an object is covered, so it can not blow particles in the wind, or potentially otherwise render differently
    bridge:setCovered(objectID, covered)
end

function clientGOM:setDecalBlockers(objectID, decalBlockers)
    bridge:setDecalBlockers(objectID, decalBlockers)
end

function clientGOM:isStored(objectID)
    return bridge:isStored(objectID)
end

function clientGOM:callFunctionForObjectsInSet(setName, func)
    bridge:callFunctionForObjectsInSet(setName, func)
end


function clientGOM:updateObjectsForModifiedOffsetVertReceivedFromServer(vert)
    local objectInfos = clientGOM:getAllGameObjectsWithinRadiusOfPos(vert.pos, mj:mToP(8.0))
    for i,objectInfo in ipairs(objectInfos) do
        local object = allObjects[objectInfo.objectID]
        if object then
            local objectSnapMatrixFunctions = objectSnapMatrixFunctionsByObjectTypeIndex[object.objectTypeIndex]
            if objectSnapMatrixFunctions then
                clientGOM:clearCachedSubmodelTransforms(object)
                for j,func in ipairs(objectSnapMatrixFunctions) do
                    func(object, object.pos, object.rotation)
                end
            end
        end
    end
end


function clientGOM:setDebugObject(objectID)
    bridge:setDebugObject(objectID)
end

return clientGOM
