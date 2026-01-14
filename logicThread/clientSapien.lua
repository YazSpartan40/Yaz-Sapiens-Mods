local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
--local normalize = mjm.normalize
local length2 = mjm.length2
local mat3LookAtInverse = mjm.mat3LookAtInverse
local mat3Rotate = mjm.mat3Rotate
--local mat3GetRow = mjm.mat3GetRow
local dot = mjm.dot
local approxEqual = mjm.approxEqual

--local worldHelper = mjrequire "common/worldHelper"
local action = mjrequire "common/action"
local gameObject = mjrequire "common/gameObject"
--local order = mjrequire "common/order"
local actionSequence = mjrequire "common/actionSequence"
local rng = mjrequire "common/randomNumberGenerator"
local sapienConstants = mjrequire "common/sapienConstants"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
local skillLearning = mjrequire "common/skillLearning"
local constructable = mjrequire "common/constructable"
local nomadTribeBehavior = mjrequire "common/nomadTribeBehavior"

--local clientNPC = mjrequire "logicThread/clientNPC"
local logic = mjrequire "logicThread/logic"
local clientSapienAnimation = mjrequire "logicThread/clientSapienAnimation"
local clientSapienInventory = mjrequire "logicThread/clientSapienInventory"
local logicAudio = mjrequire "logicThread/logicAudio"
--local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local musicalInstrumentPlayer = mjrequire "logicThread/musicalInstrumentPlayer"
local clientDestination = mjrequire "logicThread/clientDestination"
--local physicsSets = mjrequire "common/physicsSets"

local clientSapien = {}

local followerInfos = {}
local removedFollowerInfos = {}

local clientGOM = nil

local minLookAtDistance2 = mj:mToP(1.0) * mj:mToP(1.0)
function clientSapien:getLookAtPoint(serverLookAtPoint, serverLookAtObjectID, sapienEyePos, sapienDir) --this drives the actual rotation of the sapien
    local lookAtPoint = serverLookAtPoint
    if serverLookAtObjectID then
        local lookAtObject = clientGOM:getObjectWithID(serverLookAtObjectID)
        if lookAtObject then
            lookAtPoint = gameObject:getSapienLookAtPointForObject(lookAtObject)
        end
    end

    --[[if not clientSapienAnimation.debugServerState then
        if (not lookAtPoint) or length2(lookAtPoint - sapienEyePos) < minLookAtDistance2 then
            return sapienEyePos + sapienDir * mj:mToP(100.0)
        end
    end]]

    return lookAtPoint
end

local function getMoodHeadXRotationOffset(sapien)
    local headRotationOrNil = action:getModifierValue(sapien.sharedState.actionModifiers, "headXRotationOffset")
    if headRotationOrNil then
        return -headRotationOrNil * 0.4
    end
    return 0.0
end

local displayedNonFollowerSapiens = {}

clientSapien.serverUpdate = function(sapien, pos, rotation, scale, incomingServerStateDelta)
    --mj:log("clientSapien.serverUpdate sapien id:", sapien.uniqueID, "incomingServerStateDelta:", incomingServerStateDelta)
    clientGOM:setCovered(sapien.uniqueID, sapien.sharedState.covered)

    local clientState = clientGOM:getClientState(sapien)

    local sharedState = sapien.sharedState
    
    local actionTypeIndex = nil
    local sequenceTypeIndex = nil
    local actionState = sharedState.actionState

    local function getIsThreatening()
        if  (sharedState.tribeBehaviorTypeIndex and nomadTribeBehavior.types[sharedState.tribeBehaviorTypeIndex].isRaid) then
            return true
        end

        return clientDestination:getOtherTribeIsThreatening(sharedState.tribeID)
    end

    
    if not clientState.soundAdded then
        if getIsThreatening() then
            logicAudio:addLoopingSoundForObject(sapien, "audio/sounds/events/conflictLoop.wav")
            clientState.soundAdded = true
        end
    else
        if not getIsThreatening() then
            logicAudio:removeLoopingSoundForObject(sapien)
            clientState.soundAdded = nil
        else
            logicAudio:updateLoopingSoundPos(sapien, pos)
        end
    end

    if actionState then
        sequenceTypeIndex = actionState.sequenceTypeIndex
        if not sequenceTypeIndex then
            mj:error("no sequenceTypeIndex:", sapien.uniqueID, " sharedState:", sharedState, " delta:", incomingServerStateDelta)
        end
        local actionSequenceActions = actionSequence.types[sequenceTypeIndex].actions
        if not actionSequenceActions then
            mj:error("no actionSequence.types[sequenceTypeIndex].actions:", sharedState, " delta:", incomingServerStateDelta)
        end
        actionTypeIndex = actionSequenceActions[math.min(actionState.progressIndex, #actionSequenceActions)]
    end

    musicalInstrumentPlayer:updateStateForServerUpdate(sapien, clientState, actionTypeIndex)
    
    if actionState and actionState.path then
        local nodes = actionState.path.nodes

        local pathChanged = clientState.currentPathNodeCount ~= #nodes
        if not pathChanged then
            if #nodes > 0 then
                if not clientState.currentPathX1 then
                    pathChanged = true
                   -- --disabled--mj:objectLog(sapien.uniqueID, "not clientState.currentPathX1")
                else
                    local pos1 = nodes[1].pos
                    local posEnd = nodes[#nodes].pos
                    if (not approxEqual(clientState.currentPathX1, pos1.x)) or (not approxEqual(clientState.currentPathX2, posEnd.x)) or 
                    (not approxEqual(clientState.currentPathY1, pos1.y)) or (not approxEqual(clientState.currentPathY2, posEnd.y)) then
                       -- --disabled--mj:objectLog(sapien.uniqueID, "not approxEqual")
                        pathChanged = true
                    end
                end
            end
        end

        if pathChanged then
            --disabled--mj:objectLog(sapien.uniqueID, "pathChanged:", nodes)
            clientState.currentPathNodeCount = #nodes
            if #nodes > 0 then
                local pos1 = nodes[1].pos
                local posEnd = nodes[#nodes].pos
                clientState.currentPathX1 = pos1.x
                clientState.currentPathX2 = posEnd.x
                clientState.currentPathY1 = pos1.y
                clientState.currentPathY2 = posEnd.y
            else
                clientState.currentPathX1 = nil
                clientState.currentPathX2 = nil
                clientState.currentPathY1 = nil
                clientState.currentPathY2 = nil
            end

            --[[if (clientState.pathDone) or 
            (not clientState.pathNodeIndex) or 
            (actionState.pathNodeIndex < clientState.pathNodeIndex) or 
            (actionState.pathNodeIndex > clientState.pathNodeIndex + 1) or 
            (not clientState.lastReaclculatedNodeIndex) then]]
                --disabled--mj:objectLog(sapien.uniqueID, "reset d")
                clientState.pathNodeIndex = actionState.pathNodeIndex
                clientState.nodeDistance = mjm.length(nodes[clientState.pathNodeIndex].pos - sapien.pos)
                clientState.nodeTravelDistance = 0.0
                clientState.lastReaclculatedNodeIndex = clientState.pathNodeIndex
                clientState.pathDone = nil
            --end
        end
    end
    
    clientSapienAnimation:serverUpdate(sapien, sharedState, clientState, sequenceTypeIndex, actionTypeIndex, pos, rotation)
    clientSapienInventory:updateHeldObjects(sapien, clientState, actionTypeIndex)

    local function removeLookAtOverride()
        if clientState.serverLookAtPoint then
            clientState.serverLookAtPoint = nil
            clientState.serverLookAtObjectID = nil

            clientState.nextHeadRotationInfo = {}
            ----disabled--mj:objectLog(sapien.uniqueID, "remove head rotation")
            --logic:callMainThreadFunction("setObjectHeadRotation", )
        end
    end

    if sharedState.lookAtPoint or sharedState.lookAtObjectID then

        local prevLookAtPoint = clientState.serverLookAtPoint
        clientState.serverLookAtPoint = sharedState.lookAtPoint
        clientState.serverLookAtObjectID = sharedState.lookAtObjectID

        if clientState.serverLookAtPoint or clientState.serverLookAtObjectID then
            local lookAtPoint = clientState.serverLookAtPoint
            if not lookAtPoint then
                local lookAtObject = clientGOM:getObjectWithID(clientState.serverLookAtObjectID)
                if lookAtObject then
                    lookAtPoint = lookAtObject.pos
                end
            end

            if lookAtPoint and length2(lookAtPoint - sapien.pos) < minLookAtDistance2 then
                removeLookAtOverride()
            end
        end

        --mj:log("look at point updated:", sapien.uniqueID, " distance:", mj:pToM(mjm.length(clientState.serverLookAtPoint - sapien.pos)), " actionTypeIndex:", actionTypeIndex)
        
        --disabled--mj:objectLog(sapien.uniqueID, "new look at data recieved clientState.serverLookAtPoint:", clientState.serverLookAtPoint, " clientState.serverLookAtObjectID:", clientState.serverLookAtObjectID)
       
        local normalizedSapienPos = sapien.normalizedPos
        
        local sitting = false
        local actionModifiers = sapien.sharedState.actionModifiers
        if actionModifiers and actionModifiers[action.modifierTypes.sit.index] then
            sitting = true
        end

        local sapienEyePos = (sapien.pos + normalizedSapienPos * sapienConstants:getEyeHight(sapien.sharedState.lifeStageIndex, sitting))

        local lookAtPosToUse = clientSapien:getLookAtPoint(clientState.serverLookAtPoint, clientState.serverLookAtObjectID, sapienEyePos, clientState.directionNormal)

        if lookAtPosToUse then
            local lookAtVec = lookAtPosToUse - sapienEyePos
            local lookatVecLength2 = length2(lookAtVec)
            if (lookatVecLength2 > mj:mToP(0.5) * mj:mToP(0.5) or clientSapienAnimation.debugServerState) then
                if ((not prevLookAtPoint) or length2(prevLookAtPoint - lookAtPosToUse) > (mj:mToP(0.1) * mj:mToP(0.1))) then
                    --mj:log("setting:", sapien.uniqueID)
                    local lookAtVecNormal = lookAtVec / math.sqrt(lookatVecLength2)
                    local dotUp = dot(lookAtVecNormal, normalizedSapienPos)
                    if dotUp > -0.9 and dotUp < 0.9 then
                        local rotationMatrix = mat3LookAtInverse(lookAtVecNormal, normalizedSapienPos)

                        local xAddition = getMoodHeadXRotationOffset(sapien)
                        rotationMatrix = mat3Rotate(rotationMatrix, xAddition + (rng:randomValue() - 0.5) * 0.1, vec3(1.0,0.0,0.0))
                        rotationMatrix = mat3Rotate(rotationMatrix, (rng:randomValue() - 0.5) * 0.1, vec3(0.0,0.0,1.0))

                        ----disabled--mj:objectLog(sapien.uniqueID, "set head rotation A:", rotationMatrix)
                        
                        clientState.nextHeadRotationInfo = {
                            rotationMatrix = rotationMatrix,
                        }
                    else
                        removeLookAtOverride()
                    end
                end
            end
        else
            --mj:log("look at point removed B:", sapien.uniqueID)
            removeLookAtOverride()
        end
    else
        --mj:log("look at point removed C:", sapien.uniqueID)
        removeLookAtOverride()
    end

    clientState.prevActionTypeIndex = actionTypeIndex
    if sharedState.tribeID == logic.tribeID then
        clientSapien:notifyMainThreadOfFollowerChange(sapien.uniqueID, sapien.pos, incomingServerStateDelta, sapien.sharedState)
    end


    if sapien.sharedState.tribeID ~= logic.tribeID then
        if not displayedNonFollowerSapiens[sapien.uniqueID] then
            displayedNonFollowerSapiens[sapien.uniqueID] = true
            logic:callMainThreadFunction("nonFollowerSapienAdded", {
                uniqueID = sapien.uniqueID,
                pos = pos,
                sharedState = sapien.sharedState,
            })
        else
            logic:callMainThreadFunction("nonFollowerSapienUpdated", {
                uniqueID = sapien.uniqueID,
                pos = pos,
                sharedState = sapien.sharedState,
            })
        end
    elseif displayedNonFollowerSapiens[sapien.uniqueID] then
        displayedNonFollowerSapiens[sapien.uniqueID] = nil
        logic:callMainThreadFunction("nonFollowerSapienRemoved", {
            uniqueID = sapien.uniqueID,
        })
    end

end

clientSapien.objectWasLoaded = function(sapien, pos, rotation, scale)
    --disabled--mj:objectLog(sapien.uniqueID, "objectWasLoaded")
    local clientState = clientGOM:getClientState(sapien)
    clientState.infrequentUpdateTimer = 0.0
    clientState.infrequentUpdateRandomWait = 0.5 + rng:randomValue() * 1.0

    if mj:isNan(rotation.m0) then
        mj:error("rotation is nan")
        error()
    end
    --snapToPos(sapien, pos)

    clientSapienAnimation:sapienLoaded(sapien, clientState, pos, rotation, scale)

    clientSapien.serverUpdate(sapien, pos, rotation, scale, nil)
    clientGOM:addObjectToSet(sapien, clientGOM.objectSets.sapiens)
    clientSapienAnimation:update(sapien, 0.0, 1.0, clientState)

    if sapien.sharedState.tribeID ~= logic.tribeID then
        displayedNonFollowerSapiens[sapien.uniqueID] = true
        logic:callMainThreadFunction("nonFollowerSapienAdded", {
            uniqueID = sapien.uniqueID,
            pos = pos,
            sharedState = sapien.sharedState,
        })
    end
end

clientSapien.objectWillBeUnloaded = function(object)
    --disabled--mj:objectLog(object.uniqueID, "objectWillBeUnloaded")
    local info = followerInfos[object.uniqueID]
    if info then
        info.sharedState = object.sharedState
        info.pos = object.pos
    end
    clientSapienAnimation:sapienUnLoaded(object, clientGOM:getClientState(object))

    if object.sharedState.tribeID ~= logic.tribeID then
        displayedNonFollowerSapiens[object.uniqueID] = nil
        logic:callMainThreadFunction("nonFollowerSapienRemoved", {
            uniqueID = object.uniqueID,
        })
    end
  --  loadedSapiens[object.uniqueID] = nil
end


clientSapien.objectSnapMatrix = function(object, pos, rotation)
    ----disabled--mj:objectLog(object.uniqueID, "objectSnapMatrix called:", pos)
    local clientState = clientGOM:getClientState(object)
    clientSapienAnimation:snapToServerPos(object, clientState, pos, rotation)
end

function clientSapien:getFollowerInfoIncludingRemoved(uniqueID)
    return followerInfos[uniqueID] or removedFollowerInfos[uniqueID]
end

function clientSapien:getFollowerInfo(uniqueID)
    return followerInfos[uniqueID]
end

function clientSapien:objectIsFollower(uniqueID)
    return followerInfos[uniqueID] ~= nil
end


local function getConstructableTypeIndex(craftOrBuildObject)
    local constructableTypeIndex = craftOrBuildObject.sharedState.inProgressConstructableTypeIndex
    if constructableTypeIndex then
        return constructableTypeIndex
    end

    local planStates = craftOrBuildObject.sharedState.planStates
    if planStates then
        for tribeID,planStatesForTribe in pairs(planStates) do
            for j,planState in ipairs(planStatesForTribe) do
                if planState.constructableTypeIndex then 
                    return planState.constructableTypeIndex
                end
            end
        end
    end

    return nil
end

local function getLearningInfoForMainThread(uniqueID, sharedState)
    
    if not sharedState then
        return nil
    end
    local skillTypeIndex = nil
    local researchTypeIndex = nil
    local discoveryCraftableTypeIndex = nil
    if sharedState.activeOrder and sharedState.orderQueue[1] then
        local orderState = sharedState.orderQueue[1]
       -- --disabled--mj:objectLog(uniqueID, "getLearningInfoForMainThread orderState:", orderState)
        local orderTypeIndex = orderState.orderTypeIndex
        local orderContext = orderState.context
        
        local orderObjectID = orderState.objectID
        local orderObject = nil
        if orderObjectID then
            orderObject = clientGOM:getObjectWithID(orderObjectID)
        end

        

        if orderContext  then
            researchTypeIndex = orderContext.researchTypeIndex
            discoveryCraftableTypeIndex = orderContext.discoveryCraftableTypeIndex
            if (not discoveryCraftableTypeIndex) and orderObject and orderObject.sharedState then --bit of an ambulance, hopefully we should always have this set in the orderContext now
                local planStates = orderObject.sharedState.planStates and orderObject.sharedState.planStates[sharedState.tribeID]
                if planStates then
                    for i,planState in ipairs(planStates) do
                        if planState.researchTypeIndex == researchTypeIndex then
                            discoveryCraftableTypeIndex = planState.constructableTypeIndex
                            break
                        end
                    end
                end
            end
            --[[local researchProvidesSkillTypeIndex = research.types[orderContext.researchTypeIndex].skillTypeIndex
            if researchProvidesSkillTypeIndex then
                skillTypeIndex = researchProvidesSkillTypeIndex
            end]]
        end

        if not researchTypeIndex then
            local objectTypeIndex = nil


            if orderContext then
                objectTypeIndex = orderContext.objectTypeIndex
            end
            if orderObject and (not objectTypeIndex) then
                objectTypeIndex = orderObject.objectTypeIndex
            end
            
            local learningInfo = skillLearning:getTaughtSkillInfo(orderTypeIndex, objectTypeIndex)
            ----disabled--mj:objectLog(uniqueID, "learningInfo:", learningInfo)
            if learningInfo then
                skillTypeIndex = learningInfo.skillTypeIndex
            end

            if (not skillTypeIndex) and (orderObject and orderObject.sharedState) then
                local constructableTypeIndex = getConstructableTypeIndex(orderObject)
                
                local constructableType = constructable.types[constructableTypeIndex]

                if constructableType and constructableType.skills then
                    skillTypeIndex = constructableType.skills.required
                    --disabled--mj:objectLog(uniqueID, "constructableType:", constructableType)
                end
            end
        end

    end
    
    ----disabled--mj:objectLog(uniqueID, "researchTypeIndex:", researchTypeIndex, " skillTypeIndex:", skillTypeIndex)

    if researchTypeIndex then
        return {
            researchTypeIndex = researchTypeIndex,
            discoveryCraftableTypeIndex = discoveryCraftableTypeIndex,
        }
    else
        if skillTypeIndex then
            local hasSkill = false
            local fractionComplete = 0.0
            if sharedState.skillState and sharedState.skillState[skillTypeIndex] then
                if sharedState.skillState[skillTypeIndex].complete then
                    hasSkill = true
                else
                    fractionComplete = sharedState.skillState[skillTypeIndex].fractionComplete or 0.0
                end
            end
            if not hasSkill then
                return {
                    skillTypeIndex = skillTypeIndex,
                    fractionComplete = fractionComplete,
                }
            end
        end
    end

    return {}
end

local followerSharedStateSentByID = {}

local posChangeUpdates = {}

function clientSapien:notifyMainThreadOfFollowerPosChange(uniqueID, pos)
    posChangeUpdates[uniqueID] = pos
end

function clientSapien:notifyMainThreadOfFollowerChange(uniqueID, pos, incomingServerStateDelta, fullSharedState)
    local followerInfo = followerInfos[uniqueID]
    if followerInfo then
        if fullSharedState then
            followerInfo.sharedState = fullSharedState
        end
        -- mj:log("B sapienID:",uniqueID, " learningInfo:", getLearningInfoForMainThread(uniqueID, sharedState))
        local infoToSend = {
            uniqueID = uniqueID,
            pos = pos,
            incomingServerStateDelta = incomingServerStateDelta,
            learningInfo = getLearningInfoForMainThread(uniqueID, followerInfo.sharedState)
        }
        if not followerSharedStateSentByID[uniqueID] then
            infoToSend.sharedState = followerInfo.sharedState
            followerSharedStateSentByID[uniqueID] = true
        end
        logic:callMainThreadFunction("followerChanged", infoToSend)
        posChangeUpdates[uniqueID] = nil
    end
end

function clientSapien:updateUnloadedFollower(uniqueID, incomingServerStateDelta, posOrNil, rotationOrNil, scaleOrNil)
    local shiftedPosOrNil = posOrNil--worldHelper:getBelowSurfacePos(pos, physicsSets.walkable)
    local info = followerInfos[uniqueID]
    if info and info.sharedState then
        gameObjectSharedState:mergeDelta(info, incomingServerStateDelta)
        if shiftedPosOrNil then
            info.pos = shiftedPosOrNil
        end
        clientSapien:notifyMainThreadOfFollowerChange(uniqueID, info.pos, incomingServerStateDelta, info.sharedState)
    end
end

function clientSapien:globalUpdate()
    if next(posChangeUpdates) then
        logic:callMainThreadFunction("followersPosChanged", posChangeUpdates)
        posChangeUpdates = {}
    end
end

function clientSapien:update(sapien, dt, speedMultiplier) --NOTE this is only called for visible sapiens
    local clientState = clientGOM:getClientState(sapien)
    if clientState then
        clientSapienAnimation:update(sapien, dt, speedMultiplier, clientState)
        
        clientState.infrequentUpdateTimer = clientState.infrequentUpdateTimer + dt * speedMultiplier
        if clientState.infrequentUpdateTimer > clientState.infrequentUpdateRandomWait then
            clientSapien:infrequentUpdate(sapien, clientState.infrequentUpdateTimer)
            clientState.infrequentUpdateTimer = 0.0
            clientState.infrequentUpdateRandomWait = 1.5 + rng:randomValue() * 2.0
        end

        --DEBUG tool: to make them all look at the player, uncomment this
       --[[ local normalizedSapienPos = sapien.normalizedPos
        local sitting = false
        local actionModifiers = sapien.sharedState.actionModifiers
        if actionModifiers and actionModifiers[action.modifierTypes.sit.index] then
            sitting = true
        end
        local sapienEyePos = (sapien.pos + normalizedSapienPos * sapienConstants:getEyeHight(sapien.sharedState.lifeStageIndex, sitting))
        local rotationMatrix = mat3LookAtInverse(normalize(logic.playerPos - sapienEyePos), sapien.normalizedPos)
        clientState.nextHeadRotationInfo = {
            rotationMatrix = rotationMatrix,
        }]]

        if clientState.nextHeadRotationInfo or clientState.nextHeadRotationDelayTimer then
            if clientState.nextHeadRotationDelayTimer then
                clientState.nextHeadRotationDelayTimer = clientState.nextHeadRotationDelayTimer - dt * speedMultiplier
                if clientState.nextHeadRotationDelayTimer <= 0.0 then
                    clientState.nextHeadRotationDelayTimer = nil
                end
            else
                if clientState.nextHeadRotationInfo then
                    local rateMultiplier = 2.0
                    local waitDelayAddition = 1.0
                    if not clientState.nextHeadRotationInfo.rotationMatrix then
                        rateMultiplier = 0.5
                        waitDelayAddition = 0.1
                    end
                    local randomExtra = rng:randomValue()
                    --randomExtra = randomExtra * randomExtra
                    logic:callMainThreadFunction("setObjectHeadRotation", {
                        uniqueID = sapien.uniqueID,
                        rotationMatrix = clientState.nextHeadRotationInfo.rotationMatrix,
                        rate = (2.0 - randomExtra) * 0.25 * rateMultiplier,
                    })
                    clientState.nextHeadRotationInfo = nil
                    clientState.nextHeadRotationDelayTimer = waitDelayAddition + rng:randomValue() * waitDelayAddition
                end
            end
        end
        
    end
end

function clientSapien:isSleeping(clientState)
    return clientState.currentActionSequenceTypeIndex == actionSequence.types.sleep.index
end

function clientSapien:infrequentUpdate(sapien, dt)
    
end

function clientSapien:initialFollowersListReceived(followerInfos_)
    followerInfos = followerInfos_
    logic:callMainThreadFunction("initialFollowersListReceived", followerInfos)
end


function clientSapien:followersAdded(addedInfos)
    for sapienID,info in pairs(addedInfos) do
        followerInfos[sapienID] = info
    end
    logic:callMainThreadFunction("followersAdded", addedInfos)
end

function clientSapien:followersRemoved(removedIDs)
    for i, sapienID in ipairs(removedIDs) do
        removedFollowerInfos[sapienID] = followerInfos[sapienID]
        followerInfos[sapienID] = nil
    end
    logic:callMainThreadFunction("followersRemoved", removedIDs)
end

function clientSapien:skillPriorityListChanged()
    logic:callMainThreadFunction("skillPriorityListChanged")
end

function clientSapien:hasAnyFollowers()
    return followerInfos and next(followerInfos)
end

function clientSapien:init(clientGOM_)
    clientGOM = clientGOM_
    clientSapienAnimation:init(clientGOM_, clientSapien)
    clientSapienInventory:init(clientGOM_)
end

return clientSapien