local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local length = mjm.length
local length2 = mjm.length2
local mix = mjm.mix
local mat3GetRow = mjm.mat3GetRow
local cross = mjm.cross
local mat3LookAtInverse = mjm.mat3LookAtInverse
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3Inverse = mjm.mat3Inverse

local gameObject = mjrequire "common/gameObject"
local mob = mjrequire "common/mob/mob"
local rng = mjrequire "common/randomNumberGenerator"
local gameConstants = mjrequire "common/gameConstants"
local tool = mjrequire "common/tool"
local plan = mjrequire "common/plan"
local timer = mjrequire "common/timer"
--local notification = mjrequire "common/notification"
local mobInventory = mjrequire "common/mobInventory"
--local physics = mjrequire "common/physics"
local worldHelper = mjrequire "common/worldHelper"
local physicsSets = mjrequire "common/physicsSets"

local terrain = mjrequire "server/serverTerrain"
local pathCreator = mjrequire "server/pathCreator"
local anchor = mjrequire "server/anchor"
local planManager = mjrequire "server/planManager"
local serverWorldSettings = mjrequire "server/serverWorldSettings"

local serverMob = {
    loadedCountsByMobTypeIndex = {}
}

local serverGOM = nil
local serverWorld = nil
local serverSapien = nil
local serverSapienAI = nil
--local planManager = nil

local function resetCloseSapienRandomDirectionOffset(aiState)
    aiState.closeSapienRandomDirectionOffset = (rng:randomValue() - 0.5) * 4.0
    aiState.closeSapienRandomDirectionOffsetTimer = 1.5 + rng:randomValue() * 2.0
end

local function resetAgressiveDecisionTimer(aiState)
    aiState.agressiveDecision = rng:randomInteger(4) > 0
    aiState.agressiveDecisionTimer = 3.5 + rng:randomValue() * 2.0
end

local maxMobCount = 1000
local randomSeed = 3234
local exitMinDistance2 = mj:mToP(50.0) * mj:mToP(50.0)
local maxGoalDistance = mj:mToP(4.5) --this needs to be 4.5 to allow cylinder test to work, higher will miss collisions and would require itteration
local maxGoalDistance2 = maxGoalDistance * maxGoalDistance

local minDespawnDistanceFromClosestPlayer2 = mj:mToP(400.0) * mj:mToP(400.0)

local despawnWithoutMakingItToExitDelay = 2880 * 16 --todo this shouldn't be used on tamed animals

local landSeaAltitudeCutoff = (1.0 - mj:mToP(0.25))
local landSeaAltitudeCutoff2 = landSeaAltitudeCutoff * landSeaAltitudeCutoff

local function getAIState(object)
    local unsavedState = serverGOM:getUnsavedPrivateState(object)
    local aiState = unsavedState.aiState
    if not aiState then
        aiState = {}
        unsavedState.aiState = aiState
    end
    return aiState
end

local function resetAIState(object)
    local unsavedState = serverGOM:getUnsavedPrivateState(object)
    unsavedState.aiState = nil
end


local function addMovementGoalPos(object, newGoalPos, walkSpeed, mixFraction)
    --[[if object.uniqueID == mj.debugObject then
        mj:debug("addMovementGoalPos")
    end]]
    --disabled--mj:objectLog(object.uniqueID, "addMovementGoalPos")
    
    if object.uniqueID == mj.debugObject then
        mj:debug("addMovementGoalPos:", mj:pToM(length(newGoalPos - object.pos)), " direction:", normalize(newGoalPos - object.pos))
    end

    local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
    local mobType = mob.types[mobTypeIndex]

    local aiState = getAIState(object)
    local newGoalPosNormal = normalize(newGoalPos)
    local posLength = length(object.pos)
    newGoalPos = newGoalPosNormal * posLength
    if mixFraction < 1.0 and (not aiState.lastDirectionWasBlocked) then
        local prevGoalPos = object.sharedState.goalPos
        if prevGoalPos then
            newGoalPos = mix(prevGoalPos, newGoalPos, mixFraction)
            newGoalPosNormal = normalize(newGoalPos)
        end
    end
    local newDirectionVec = newGoalPosNormal - object.normalizedPos
    local newDirectionVecLength2 = length2(newDirectionVec)
    if newDirectionVecLength2 ~= 0 then
        local newDirectionVecLength = math.sqrt(newDirectionVecLength2)
        local newDirection = newDirectionVec / newDirectionVecLength

        if newDirectionVecLength > maxGoalDistance then
            newGoalPosNormal = object.normalizedPos + newDirection * maxGoalDistance
        end

        local dp = mjm.dot(newDirection, object.normalizedPos)
        if dp > -0.9 and dp < 0.9 then
            --local rotation = mat3Rotate(mat3LookAtInverse(newDirection, object.normalizedPos), math.pi * 0.5, vec3(0.0,1.0,0.0))
            local rotation = mat3LookAtInverse(newDirection, object.normalizedPos)
            serverGOM:setRotation(object.uniqueID, rotation)
        end
    end

    newGoalPos = newGoalPosNormal * posLength
    local clampToSeaLevel = false
    newGoalPos = worldHelper:getBelowSurfacePos(newGoalPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)

    local function setBlockedAndResetExitPosIfNeeded()
        --disabled--mj:objectLog(object.uniqueID, "RESET longGoalPos in setBlockedAndResetExitPosIfNeeded()")
        if aiState.lastDirectionWasBlocked and (not aiState.frequentCallbackSet) then
            local randomVecNormlaized = normalize(rng:randomVec())
            local randomVecPerp = normalize(cross(randomVecNormlaized, object.normalizedPos))
            local offsetDistance = mj:mToP(50.0)
            local randomPos = normalize(object.normalizedPos + randomVecPerp * offsetDistance)
            object.sharedState:set("exitPos", randomPos)
            object.sharedState:remove("goalMidPoint")
            --disabled--mj:objectLog(object.uniqueID, "setting new exit pos")
        end
        aiState.lastDirectionWasBlocked = true
        aiState.longGoalPos = nil
        resetCloseSapienRandomDirectionOffset(aiState)
    end

    local newPosAltitude = length(newGoalPos)

    local validAltitude = false
    if mobType.swims then
        validAltitude = (newPosAltitude + mj:mToP(0.25)) < landSeaAltitudeCutoff
    else
        validAltitude = newPosAltitude > landSeaAltitudeCutoff
    end

    --disabled--mj:objectLog(object.uniqueID, "validAltitude:", validAltitude, " alt:", mj:pToM((newPosAltitude - 1.0)))

    if validAltitude then
        --disabled--mj:objectLog(object.uniqueID, "valid altitude")
        if mobType.swims then
            local minAltitude = math.max(newPosAltitude + mj:mToP(0.5), 1.0 - mj:mToP(4.0))
            local maxAltitude = 1.0 - mj:mToP(0.5)
            local desiredAltitude = minAltitude + (maxAltitude - minAltitude) * rng:randomValue()
            newGoalPos = newGoalPosNormal * desiredAltitude
        end

        terrain:loadArea(newGoalPosNormal)
        local collisionFound = pathCreator:pathFindingCylinderTest(object.pos, newGoalPos, mobType.pathFindingRayRadius, mobType.pathFindingRayYOffset, nil)

        if not collisionFound then
            --disabled--mj:objectLog(object.uniqueID, "setting new goal pos")
            --[[if object.uniqueID == mj.debugObject then
                mj:debug("setting goal pos altitude:", mj:pToM((length(newGoalPos) - 1.0)), " distance:", mj:pToM(length(newGoalPos - object.pos)))
            end]]
            aiState.lastDirectionWasBlocked = nil
            object.sharedState:set("walkSpeed", walkSpeed)
            object.sharedState:set("goalPos", newGoalPos)
            object.sharedState:set("walkStartTime", serverWorld:getWorldTime())
        else
            setBlockedAndResetExitPosIfNeeded()
            --mj:log("mob path collsion found:", object.uniqueID)
        end
    else
        setBlockedAndResetExitPosIfNeeded()
    end
end

local function updateCurrentPos(object)
    if object.sharedState.goalPos then
        local distanceVec = object.sharedState.goalPos - object.pos
        local distanceLength = length(distanceVec)
        local currentTime = serverWorld:getWorldTime()
        local timeElapsed = currentTime - object.sharedState.walkStartTime
        if timeElapsed > 0.0 then
            local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
            local mobType = mob.types[mobTypeIndex]
            local distanceTravelled = timeElapsed * mobType.walkSpeed * object.sharedState.walkSpeed
            if distanceTravelled >= distanceLength then
                --disabled--mj:objectLog(object.uniqueID, "setPos a:", mj:pToM((length(object.sharedState.goalPos) - 1.0)))
                serverGOM:setPos(object.uniqueID, object.sharedState.goalPos, false)
                object.sharedState:remove("goalPos")
                --disabled--mj:objectLog(object.uniqueID, "remove goal pos for mob. distanceTravelled:", mj:pToM(distanceTravelled), " distanceLength:",  mj:pToM(distanceLength))
                serverGOM:saveObject(object.uniqueID)
            else
                local fraction = distanceTravelled / distanceLength
                --disabled--mj:objectLog(object.uniqueID, "update goal pos for mob")
                local newPos = object.pos + distanceVec * fraction
                if not mobType.swims then
                    --disabled--mj:objectLog(object.uniqueID, "getBelowSurfacePos:", mobTypeIndex)
                    local clampToSeaLevel = false
                    newPos = worldHelper:getBelowSurfacePos(newPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                end
                --disabled--mj:objectLog(object.uniqueID, "setPos b:", mj:pToM((length(newPos) - 1.0)))
                serverGOM:setPos(object.uniqueID, newPos, false)
                object.sharedState:set("walkStartTime", currentTime)
                serverGOM:saveObject(object.uniqueID)
            end
        end
    end
end

local function checkForEmbededObjectFallOut(mobObject)
    local sharedState = mobObject.sharedState
    local locationTypeIndex = mobInventory.locations.embeded.index
    if sharedState.inventories and sharedState.inventories[locationTypeIndex] then
        local inventory = sharedState.inventories[locationTypeIndex]
        local objects = inventory.objects
        if objects and objects[1] then
            if rng:randomInteger(30) == 1 then
                local objectCount = #objects
                local objectInfo = objects[objectCount]
                
                if objectCount == 1 then
                    sharedState:remove("inventories", locationTypeIndex)
                else
                    local objectTypeIndex = objectInfo.objectTypeIndex
                    local newCountByObjectType = inventory.countsByObjectType[objectTypeIndex] - 1
                    if newCountByObjectType == 0 then
                        sharedState:remove("inventories", locationTypeIndex, "countsByObjectType", objectTypeIndex)
                    else
                        sharedState:set("inventories", locationTypeIndex, "countsByObjectType", objectTypeIndex, newCountByObjectType)
                    end

                    sharedState:remove("inventories", locationTypeIndex, "objects", #objects)
                end

                local dropPosNormal = mobObject.normalizedPos
                local clampToSeaLevel = true
                local shiftedPos = worldHelper:getBelowSurfacePos(mobObject.pos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                local shiftedPosLength = length(shiftedPos)
                local finalDropPos = dropPosNormal * (shiftedPosLength + mj:mToP(4.0)) --todo different heights

                local ownerTribeID = objectInfo.ownerTribeID
                objectInfo.ownerTribeID = nil

                serverGOM:dropObject(objectInfo, finalDropPos, ownerTribeID, true)

            end
        end
    end
end

local function dropAllEmbededObjects(mobObject, tribeID)
    local sharedState = mobObject.sharedState
    local locationTypeIndex = mobInventory.locations.embeded.index
    if sharedState.inventories and sharedState.inventories[locationTypeIndex] then
        local inventory = sharedState.inventories[locationTypeIndex]
        local objects = inventory.objects
        if objects then
            local dropPosNormal = mobObject.normalizedPos
            local clampToSeaLevel = true
            local shiftedPos = worldHelper:getBelowSurfacePos(mobObject.pos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
            local shiftedPosLength = length(shiftedPos)
            local finalDropPos = dropPosNormal * (shiftedPosLength + mj:mToP(4.0)) --todo different heights
            for i,objectInfo in ipairs(objects) do
                serverGOM:dropObject(objectInfo, finalDropPos + mj:mToP(rng:randomVec()), tribeID, true)
            end

            sharedState:remove("inventories", locationTypeIndex)
        end
    end
end

local function checkPoo(mobObject)
    local mobTypeIndex = gameObject.types[mobObject.objectTypeIndex].mobTypeIndex
    local mobType = mob.types[mobTypeIndex]
    if mobType.pooFrequencyDays and mobType.pooQuantity and mobType.pooQuantity > 0 then
        local currentTime = serverWorld:getWorldTime()
        local privateState = serverGOM:getPrivateState(mobObject)
        if not privateState.nextPooTime then
            privateState.nextPooTime = currentTime + (serverWorld:getDayLength() * mobType.pooFrequencyDays * rng:randomValue())
            serverGOM:saveObject(mobObject.uniqueID)
        end

        if currentTime > privateState.nextPooTime then

            privateState.nextPooTime = currentTime + (serverWorld:getDayLength() * mobType.pooFrequencyDays) + ((rng:randomValue() - 0.5) * 0.1 * serverWorld:getDayLength())

            local dropPosNormal = mobObject.normalizedPos
            local clampToSeaLevel = true
            local shiftedPos = worldHelper:getBelowSurfacePos(mobObject.pos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
            local shiftedPosLength = length(shiftedPos)
            local finalDropPos = dropPosNormal * (shiftedPosLength + mj:mToP(2.0)) --todo different heights

            local objectInfo = {
                objectTypeIndex = gameObject.types.manure.index
            }

            for i=1,mobType.pooQuantity do
                serverGOM:dropObject(objectInfo, finalDropPos + mj:mToP(rng:randomVec()), nil, false)
            end

            serverGOM:saveObject(mobObject.uniqueID) --ensure it saves, given shared state wasn't modified (which auto-saves), only private
        end
    end

end

function serverMob:infrequentUpdate(objectID, dt, speedMultiplier) --returns early when frequentCallbackSet
    --disabled--mj:objectLog(objectID, "infrequentUpdate a")
    local object = serverGOM:getObjectWithID(objectID)
    if object then
        if object.sharedState.dead then
            return
        end
        local aiState = getAIState(object)
        if aiState.frequentCallbackSet then
            --disabled--mj:objectLog(object.uniqueID, "aiState.frequentCallbackSet, returning early from serverMob:infrequentUpdate")
            return
        end
        
        local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
        local mobType = mob.types[mobTypeIndex]
        
        updateCurrentPos(object)

        if aiState.agroTriggerTimer then
            aiState.agroTriggerTimer = aiState.agroTriggerTimer - dt * speedMultiplier
            if aiState.agroTriggerTimer <= 0.0 then
                aiState.agroTriggerTimer = nil
            end
        end

        local sleepDesire = 0.0
        if (not aiState.agroTriggerTimer) and (not aiState.agroTimer) then
            local timeOfDayFraction = serverWorld:getTimeOfDayFraction(object.pos)
            sleepDesire = math.max(mjm.smoothStep(0.25,0.125, timeOfDayFraction), mjm.smoothStep(0.8,0.85, timeOfDayFraction))
        end
        if sleepDesire > 0.5 then
            object.sharedState:set("sleeping", true)
            object.sharedState:remove("goalPos")
        else
            object.sharedState:remove("sleeping")
        end

        if not object.sharedState.sleeping then
            --disabled--mj:objectLog(objectID, "infrequentUpdate b")

            checkForEmbededObjectFallOut(object)
            checkPoo(object)

            local randomValue = rng:integerForUniqueID(object.uniqueID, randomSeed, 16)
            if mobType.swims or (object.sharedState.walkSpeed and object.sharedState.walkSpeed > 1.1) or randomValue < 4 then
                --disabled--mj:objectLog(objectID, "doing movement update.")

                local headingForMidPoint = false
                local directionVec = nil

                if object.sharedState.goalMidPoint then
                    headingForMidPoint = true
                    directionVec = object.sharedState.goalMidPoint - object.normalizedPos
                    --disabled--mj:objectLog(objectID, "found goal midpoint. direction:", normalize(directionVec))
                else
                    directionVec = normalize(object.sharedState.exitPos) - object.normalizedPos
                    --disabled--mj:objectLog(objectID, "no goal midpoint. direction:", normalize(directionVec))
                end

                local directionVecLength2 = length2(directionVec)
                local unsavedState = serverGOM:getUnsavedPrivateState(object)
                if directionVecLength2 < exitMinDistance2 or (serverWorld:getWorldTime() - object.sharedState.spawnTime) > despawnWithoutMakingItToExitDelay then
                    --disabled--mj:objectLog(objectID, "directionVecLength2 < exitMinDistance2 or despawnWithoutMakingItToExitDelay limit exceeded")
                    if headingForMidPoint then
                        object.sharedState:remove("goalMidPoint")
                        --disabled--mj:objectLog(objectID, "remove goalMidPoint")
                    else
                        --disabled--mj:objectLog(objectID, "serverWorld:distance2FromClosestPlayer:", serverWorld:distance2FromClosestPlayer(object.normalizedPos))
                        --disabled--mj:objectLog(objectID, "minDespawnDistanceFromClosestPlayer2:", minDespawnDistanceFromClosestPlayer2)
                        if serverWorld:distance2FromClosestPlayer(object.normalizedPos) > minDespawnDistanceFromClosestPlayer2 or directionVecLength2 == 0.0 then
                            --mj:debug("remove mob:", objectID, " sharedstate:", object.sharedState)
                            --disabled--mj:objectLog(objectID, "removing")
                            serverGOM:removeGameObject(objectID)
                            return
                        elseif directionVecLength2 < exitMinDistance2 then
                            --disabled--mj:objectLog(objectID, "mob removal failed due to player proximity. Extending path")
                            local directionNormal = directionVec / math.sqrt(directionVecLength2)
                            local offsetDistance = mj:mToP(200.0)
                            local extendedPos = normalize(object.normalizedPos + directionNormal * offsetDistance)
                            object.sharedState:set("exitPos", extendedPos)
                        end
                    end
                    --disabled--mj:objectLog(objectID, "infrequentUpdate d")
                elseif (not mobType.swims) and unsavedState.closeCampfires then
                    --mj:log("mob:", objectID, " unsavedState.closeCampfires:",  unsavedState.closeCampfires)
                    --disabled--mj:objectLog(objectID, "closeCampfires")
                    local campfireArray = {}
                    for campfireObjectID,campfirePos in pairs(unsavedState.closeCampfires) do
                        table.insert(campfireArray, campfireObjectID)
                    end
                    if #campfireArray > 0 then
                        local function doCampfire(campfireIndex)
                            local directionVecLength = math.sqrt(directionVecLength2)
                            local directionNormal = directionVec / directionVecLength
                            local perp = cross(object.normalizedPos, directionNormal)

                            local campfireID = campfireArray[campfireIndex]
                            local campfireDirectionNormal = normalize(unsavedState.closeCampfires[campfireID] - object.normalizedPos)
                            directionNormal = normalize(directionNormal - campfireDirectionNormal + perp * (rng:randomValue() - 0.5))

                            local newGoalPos = object.pos + directionNormal * mj:mToP(20.0)
                            aiState.longGoalPos = newGoalPos
                            addMovementGoalPos(object, newGoalPos, 1.0, 1.0)
                           -- mj:log("mob:", objectID, " running away from campfire:",  campfireID)
                        end

                        if #campfireArray == 1 then
                            doCampfire(1)
                        else
                            local randomIndex = rng:randomInteger(#campfireArray) + 1
                            doCampfire(randomIndex)
                        end

                    end
                elseif (not object.sharedState.goalPos) or rng:randomInteger(8) == 1 then
                    --disabled--mj:objectLog(objectID, "(not object.sharedState.goalPos) or rng:randomInteger(8) == 1")

                    if aiState.longGoalPos then
                        if length2(normalize(aiState.longGoalPos) - object.normalizedPos) < maxGoalDistance2 then
                            aiState.longGoalPos = nil
                        end
                    end
                    
                    local newGoalPos = nil
                    if aiState.longGoalPos then
                        --disabled--mj:objectLog(objectID, "assigning newGoalPos from existing longGoalPos")
                        newGoalPos = aiState.longGoalPos
                    else
                        --disabled--mj:objectLog(objectID, "infrequentUpdate e:", object.sharedState.goalPos)
                        local directionVecLength = math.sqrt(directionVecLength2)
                        local directionNormal = directionVec / directionVecLength
                        local perp = cross(object.normalizedPos, directionNormal)
    
                        directionNormal = normalize(directionNormal + perp * (rng:randomValue() - 0.5) * 2.0 * 0.5)
    
                        newGoalPos = object.pos + directionNormal * mj:mToP(2.0 + ((mobType.walkSpeed * mobType.runSpeedMultiplier) / mj:mToP(1.0))) * 2.0
                        aiState.longGoalPos = newGoalPos
                        --disabled--mj:objectLog(objectID, "assigned new longGoalPos")
                    end

                    addMovementGoalPos(object, newGoalPos, 1.0, 1.0)
                end
            end
        end

        randomSeed = randomSeed + 1
    end
end

local function removeFrequentUpdateIfNeeded(object, aiState)
    if aiState.frequentCallbackSet then
        if object.sharedState.dead or 
        (((not aiState.closeSapiens) or (not next(aiState.closeSapiens))) and (not aiState.agroTimer) and (not object.sharedState.attackSapienID)) then
            --mj:log("stop:", objectID)
            aiState.frequentCallbackSet = nil
            object.sharedState:remove("spooked")
            serverGOM:removeFrequentCallback(object.uniqueID) --todo also call some kind of function to calm down the state now it might be 10 secs until the next infrequent update
        end
    end
end

local frequentUpdate = nil

local function addFrequentUpdateIfNeeded(object, aiState)
    if not aiState.frequentCallbackSet and not object.sharedState.dead then
        --mj:log("start:", objectID)
        object.sharedState:set("sleeping", false)
        object.sharedState:remove("goalPos")
        aiState.frequentCallbackSet = true
        object.sharedState:set("spooked", true)
        serverGOM:setFrequentCallback(object.uniqueID, function(object_, dt, speedMultiplier)
            frequentUpdate(object_, dt, speedMultiplier)
        end)
    end
end

local agroTriggerTimerMaxSecondsBeforeAgroTriggered = 10.0


local function agroTriggerd(object, aiState, mobType, closestSapien, agroDirection)
    local aggresionLevel = mobType.aggresionLevel or 0

    aiState.agroTriggerTimer = agroTriggerTimerMaxSecondsBeforeAgroTriggered
    aiState.agroTimer = mobType.agroTimerDuration
    object.sharedState:set("agro", true)
    object.sharedState:remove("agressiveLookDirection")
    local closestSapienID = nil
    if closestSapien then
        closestSapienID = closestSapien.uniqueID
    end

    if aiState.agroCauseSapienID ~= closestSapienID and (not aiState.preventSwitchingAgroCauseTimer) then
        if aggresionLevel > 0 and (not aiState.avoidRepetitiveAttacksDelay) and rng:randomBool() then
            aiState.agroDirection = agroDirection
        else
            aiState.agroDirection = -agroDirection
        end
        aiState.agroCauseSapienID = closestSapienID
        aiState.preventSwitchingAgroCauseTimer = 2.0 + rng:randomValue()
        
        if mobType.attackDistance and aiState.closeSapiens then
            for sapienID, closeSapienInfo in pairs(aiState.closeSapiens) do
                local distance = closeSapienInfo.distance
                local normal = closeSapienInfo.normal
                if (not distance) or (not normal) then
                    local sapien = serverGOM:getObjectWithID(sapienID)
                    local distanceVec = sapien.pos - object.pos
                    distance = length(distanceVec)
                    normal = distanceVec / distance
                end
                serverSapien:closeMobAgroTriggered(sapienID, object, distance, normal)
            end
        end
    end
    addFrequentUpdateIfNeeded(object, aiState)
end

local function attackTriggered(object, aiState, mobType, closestSapien, closestDirection)
    agroTriggerd(object, aiState, mobType, closestSapien, closestDirection)

    
    local gameDifficultyMode = serverWorldSettings:get("gameDifficulty")

    if gameDifficultyMode ~= "peaceful" then
        if closestSapien then
            local closestSapienID = closestSapien.uniqueID
            if object.sharedState.attackSapienID ~= closestSapienID then
                object.sharedState:set("attackSapienID", closestSapienID)
                aiState.attackTimer = 0.0
                local sapien = serverGOM:getObjectWithID(closestSapienID)
                local options = {
                    --preventMajorInjuries = false, --todo maybe minor injuries only from rats etc
                    --preventCricticalInjuries = false, --todo maybe minor injuries only from rats etc
                    attackMobType = mobType,
                }
                serverSapien:fallAndGetInjured(sapien, closestDirection, options)
            end
        end
    end
end

frequentUpdate = function(object, dt, speedMultiplier) --only called when sapiens are close
    if speedMultiplier == 0.0 then
        return
    end

    if object.sharedState.dead then
        return
    end
    local aiState = getAIState(object)

    local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
    local mobType = mob.types[mobTypeIndex]
    local reactDistance = mobType.reactDistance
    local runDistance = mobType.runDistance
    local aggresionLevel = mobType.aggresionLevel or 0

    updateCurrentPos(object)


    if aiState.agroTimer then
        aiState.agroTimer = aiState.agroTimer - dt * speedMultiplier
        if aiState.agroTimer <= 0.0 then
            aiState.agroTimer = nil
            aiState.agroCauseSapienID = nil
            object.sharedState:remove("agro")
            if aiState.agroTriggerTimer then
                aiState.agroTriggerTimer = aiState.agroTriggerTimer * 0.5
            end
        end
    end

    if aiState.preventSwitchingAgroCauseTimer then
        aiState.preventSwitchingAgroCauseTimer = aiState.preventSwitchingAgroCauseTimer - dt * speedMultiplier
        if aiState.preventSwitchingAgroCauseTimer <= 0.0 then
            aiState.preventSwitchingAgroCauseTimer = nil
        end
    end

    local closestNonThreatDistance = 1.0
    local closestNonThreatSapien = nil
    
    local closestThreatDistance = 1.0
    local closestThreatDirection = nil
    local closestThreatSapien = nil

    local averageDirectionHeuristic = vec3(0.0,0.0,0.0)
    local totalDistanceWeight = 0.0

    if aiState.closeSapiens then
        for sapienID, closeSapienInfo in pairs(aiState.closeSapiens) do
            local sapien = serverGOM:getObjectWithID(sapienID)
            if not sapien then
                aiState.closeSapiens[sapienID] = nil
            else
                local distanceVec = sapien.pos - object.pos
                local distanceLength = length(distanceVec)
                closeSapienInfo.distance = distanceLength
                local distanceNormal = distanceVec / distanceLength
                closeSapienInfo.normal = distanceNormal
                if distanceLength < reactDistance - mj:mToP(1.0) then
                    
                    if serverSapien:getIsThreatening(sapien) then
                        if distanceLength < closestThreatDistance then
                            closestThreatSapien = sapien
                            closestThreatDistance = distanceLength
                            closestThreatDirection = distanceNormal
                        end
                    else
                        if distanceLength < closestNonThreatDistance then
                            closestNonThreatSapien = sapien
                            closestNonThreatDistance = distanceLength
                        end
                    end

                    local distanceWeight = (reactDistance - distanceLength) / reactDistance
                    totalDistanceWeight = totalDistanceWeight + distanceWeight
                    averageDirectionHeuristic = averageDirectionHeuristic + (distanceNormal) * distanceWeight
                end
            end
        end
    end
    

    if aiState.avoidRepetitiveAttacksDelay then
        aiState.avoidRepetitiveAttacksDelay = aiState.avoidRepetitiveAttacksDelay - dt * speedMultiplier
        if aiState.avoidRepetitiveAttacksDelay <= 0.0 then
            aiState.avoidRepetitiveAttacksDelay = nil
        end
    end

    
    if object.sharedState.attackSapienID then
        aiState.attackTimer = (aiState.attackTimer or 0.0) + dt * speedMultiplier
        if aiState.attackTimer > 4.0 then
            aiState.attackTimer = nil
            aiState.avoidRepetitiveAttacksDelay = 10.0
            object.sharedState:remove("attackSapienID")
        else
            return
        end
    end

    local function getRandomPerpVecNormal(pointNormal)
        local randomVecNormalized = normalize(rng:vec())
        return normalize(cross(randomVecNormalized, pointNormal))
    end

    local function addMovement(directionNormal, walkSpeed, addRandomVariation)
        if aiState.lastDirectionWasBlocked then
            directionNormal = normalize(getRandomPerpVecNormal(object.normalizedPos))
        elseif addRandomVariation then
            local perp = cross(object.normalizedPos, directionNormal)
            directionNormal = normalize(directionNormal + perp * (aiState.closeSapienRandomDirectionOffset or 0.0) * 0.2)
        end
        
        local newGoalPos = object.pos + directionNormal * mj:mToP(1.0 + ((mobType.walkSpeed * mobType.runSpeedMultiplier) / mj:mToP(1.0) * (2.0 + rng:randomValue())))
        --mj:log("close Sapien for mob:", objectID, " setting newGoalPos:", newGoalPos, " object.pos:", object.pos, " closestSapien pos:", closestSapien.pos)
        aiState.longGoalPos = newGoalPos
        addMovementGoalPos(object, newGoalPos, walkSpeed, totalDistanceWeight)
    end


    if closestThreatSapien or closestNonThreatSapien then
        
        if closestThreatSapien or closestNonThreatSapien or (not aiState.closeSapienRandomDirectionOffsetTimer) then
            resetCloseSapienRandomDirectionOffset(aiState)
        else
            aiState.closeSapienRandomDirectionOffsetTimer = aiState.closeSapienRandomDirectionOffsetTimer - dt * speedMultiplier
            if aiState.closeSapienRandomDirectionOffsetTimer < 0.0 then
                resetCloseSapienRandomDirectionOffset(aiState)
            end
        end

        if closestThreatSapien then
            if closestThreatDistance < mobType.agroDistance then
                if (not aiState.avoidRepetitiveAttacksDelay) and mobType.attackDistance and closestThreatDistance < mobType.attackDistance then
                    attackTriggered(object, aiState, mobType, closestThreatSapien, closestThreatDirection)
                else
                    agroTriggerd(object, aiState, mobType, closestThreatSapien, closestThreatDirection)
                end
            else
                if not aiState.agroTimer then
                    local increment = dt * speedMultiplier
                    if closestThreatDistance < runDistance then
                        increment = increment * 4.0
                    end
                    if not aiState.agroTriggerTimer then
                        aiState.agroTriggerTimer = increment
                    else
                        aiState.agroTriggerTimer = aiState.agroTriggerTimer + increment
                    end
        
                    if aiState.agroTriggerTimer >= agroTriggerTimerMaxSecondsBeforeAgroTriggered then
                        agroTriggerd(object, aiState, mobType, closestThreatSapien, closestThreatDirection)
                    end
                end
            end
        end

        local addMovementDirectionNormal = nil
        local walkSpeed = 1.0
        local addRandomVariation = true

        if aiState.agroTimer then
            if aiState.lastDirectionWasBlocked or (not object.sharedState.goalPos) or (mobType.runSpeedMultiplier > object.sharedState.walkSpeed) then
                --disabled--mj:objectLog(object.uniqueID, "addMovementDirectionNormal aiState.agroTimer:", aiState.agroTimer)
                addMovementDirectionNormal = aiState.agroDirection
                walkSpeed = mobType.runSpeedMultiplier
                if aggresionLevel > 0 then
                    addRandomVariation = false
                end
            end
        else
            local shouldRun = true
            if aggresionLevel > 0 then
                if not aiState.agressiveDecisionTimer then
                    resetAgressiveDecisionTimer(aiState)
                else
                    aiState.agressiveDecisionTimer = aiState.agressiveDecisionTimer - dt * speedMultiplier
                    if aiState.agressiveDecisionTimer < 0.0 then
                        resetAgressiveDecisionTimer(aiState)
                    end
                end

                if aiState.agressiveDecision and (not aiState.lastDirectionWasBlocked) then
                    shouldRun = false --stand your ground and look
                    object.sharedState:set("agressiveLookDirection", normalize(averageDirectionHeuristic))
                end
            end
            
            if shouldRun then
                local closestDistance = math.min(closestThreatDistance, closestNonThreatDistance)
                if closestDistance < runDistance then
                    walkSpeed = mobType.runSpeedMultiplier
                end

                if aiState.lastDirectionWasBlocked or (not object.sharedState.goalPos) or (walkSpeed > object.sharedState.walkSpeed) then
                    --disabled--mj:objectLog(object.uniqueID, "addMovementDirectionNormal aiState.lastDirectionWasBlocked:", aiState.lastDirectionWasBlocked, "object.sharedState.goalPos:", object.sharedState.goalPos)
                    object.sharedState:remove("agressiveLookDirection")
                    addMovementDirectionNormal = -normalize(averageDirectionHeuristic)
                end
            end
        end

        if addMovementDirectionNormal then
            addMovement(addMovementDirectionNormal, walkSpeed, addRandomVariation)
        end
    else
        removeFrequentUpdateIfNeeded(object, aiState)

        if aiState.agroTriggerTimer then
            aiState.agroTriggerTimer = aiState.agroTriggerTimer - dt * speedMultiplier
            if aiState.agroTriggerTimer <= 0.0 then
                aiState.agroTriggerTimer = nil
            end
        end
        
        if aiState.agroTimer then
            local directionNormal = aiState.agroDirection
            local walkSpeed = mobType.runSpeedMultiplier
            addMovement(directionNormal, walkSpeed, true)
        elseif aiState.lastDirectionWasBlocked or (not object.sharedState.goalPos) then
            local walkSpeed = mobType.runSpeedMultiplier
            local directionNormal = -mat3GetRow(object.rotation, 2)
            addMovement(directionNormal, walkSpeed, true)
        end
    end
end


function serverMob:mobSapienProximity(objectID, sapienID, distance2, newIsClose)

    local object = serverGOM:getObjectWithID(objectID)
    if (not object) or (object.sharedState.dead) then
        return
    end
    local aiState = getAIState(object)

    if not aiState.closeSapiens then
        aiState.closeSapiens = {}
    end
    
    if not aiState.closeSapienRandomDirectionOffset then
        resetCloseSapienRandomDirectionOffset(aiState)
    end

    if newIsClose then
        aiState.closeSapiens[sapienID] = {}
        addFrequentUpdateIfNeeded(object, aiState)
    else
        aiState.closeSapiens[sapienID] = nil
        removeFrequentUpdateIfNeeded(object, aiState)
        object.sharedState:remove("agressiveLookDirection")
    end
    
    --[[local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
    local mobType = mob.types[mobTypeIndex]
    if mobType.attackDistance then
        serverSapien:hostileMobProximityChanged(sapienID, object, newIsClose)
    end]]

end


local function embedWeapon(mobObject, weaponObject, directionNormal, ownerTribeID)
    local addLocationTypeIndex = mobInventory.locations.embeded.index

    local objectInfo = serverGOM:getStateForAdditionToInventory(weaponObject)
    
    local worldSpaceRotation = createUpAlignedRotationMatrix(mobObject.normalizedPos, directionNormal)
    local objectSpaceRotation = mat3Inverse(mobObject.rotation) * worldSpaceRotation

    objectInfo.embedRotation = objectSpaceRotation
    objectInfo.ownerTribeID = ownerTribeID

    local sharedState = mobObject.sharedState

    local inventories = sharedState.inventories or {}

    local incomingInventory = inventories[addLocationTypeIndex] or {}
    local incomingObjects = incomingInventory.objects or {}
    local incomingCountsByObjectType = incomingInventory.countsByObjectType or {}

    local objectTypeIndex = objectInfo.objectTypeIndex


    local newCount = (incomingCountsByObjectType[objectTypeIndex] or 0) + 1
    sharedState:set("inventories", addLocationTypeIndex, "countsByObjectType", objectTypeIndex, newCount)
    sharedState:set("inventories", addLocationTypeIndex, "objects", #incomingObjects + 1, objectInfo)

    serverGOM:removeGameObject(weaponObject.uniqueID)
end

local function convertToDeadObject(object, tribeID, mobType)
    local deadObjectTypeIndex = mobType.deadObjectTypeIndexesByBaseObjectTypeIndex[object.objectTypeIndex]
    if not deadObjectTypeIndex then
        mj:warn("Falling back to default dead object, as no deadObjectTypeIndex for object type:", object.objectTypeIndex, " mobType:", mobType)
        return
    end

    planManager:removeAllPlanStatesForObject(object, object.sharedState)
    if tribeID then
        object.sharedState:set("tribeID", tribeID)
    end
    dropAllEmbededObjects(object, tribeID)

    serverGOM:changeObjectType(object.uniqueID, deadObjectTypeIndex, false)

    if tribeID and gameObject.types[deadObjectTypeIndex].resourceTypeIndex then
        local priorityOffset = plan.huntFireLightPriorityOffset --little bit of a hack, but let's preserve the high priority for storing hunted mobs
        planManager:addStandardPlan(tribeID, plan.types.storeObject.index, object.uniqueID, nil, nil, nil, nil, nil, priorityOffset, nil)
    end
                        
    serverGOM:setDynamicPhysics(object.uniqueID, true)
    serverGOM:applyImpulse(object.uniqueID, object.normalizedPos * mj:mToP(1.0))
     --serverGOM:sendSnapObjectMatrix(object.uniqueID)
end

function serverMob:projectileHit(objectToHit, thrownObjectID, throwerSapienID, delay, directionNormal, projectileVelocity, tribeID, goalPos)
    local hitObjectID = objectToHit.uniqueID
    local initialMobObjectTypeIndex = objectToHit.objectTypeIndex
   -- mj:log("hitObject:", hitObjectID)

    timer:addCallbackTimer(delay, function()
        --mj:log("hit object callback timer:", hitObjectID)
        local object = serverGOM:getObjectWithID(hitObjectID)
        local weaponObject = serverGOM:getObjectWithID(thrownObjectID)
        if object and weaponObject and object.objectTypeIndex == initialMobObjectTypeIndex and not object.sharedState.dead then
            local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
            if mobTypeIndex then
                local mobType = mob.types[mobTypeIndex]
                local toolInfo = nil
                local toolType = nil
                local heldObjectType = gameObject.types[weaponObject.objectTypeIndex]
                local toolUsages = heldObjectType.toolUsages
                if toolUsages then
                    toolType = tool.types.weaponSpear
                    toolInfo = toolUsages[toolType.index]
                    if not toolInfo then
                        toolType = tool.types.weaponBasic
                        toolInfo = toolUsages[toolType.index]
                    end
                end

                local function incrementHitDamage()
                    
                    local health = object.sharedState.health
                    if not health then
                        health = mobType.initialHealth
                    end

                    
                    local function getWeaponDamage()
                        if toolInfo then
                            return toolInfo[tool.propertyTypes.damage.index]
                        end
                        return 0.1
                    end

                    local damage = getWeaponDamage()
                    health = health - damage
                    
                    if health <= 0.0 then
                        planManager:removeAllPlanStatesForObject(object, object.sharedState)
                        object.sharedState:set("dead", true)
                        removeFrequentUpdateIfNeeded(object, getAIState(object))
                        resetAIState(object)
                        

                        timer:addCallbackTimer(1.0, function()
                            local objectReloaded = serverGOM:getObjectWithID(hitObjectID)
                            if objectReloaded and objectReloaded.objectTypeIndex == initialMobObjectTypeIndex then
                                convertToDeadObject(objectReloaded, tribeID, mobType)
                                if throwerSapienID then
                                    local throwerSapien = serverGOM:getObjectWithID(throwerSapienID)
                                    if throwerSapien then
                                        --disabled--mj:objectLog(throwerSapienID, "focusing on hunted object after kill")
                                        serverSapien:cancelAllOrders(throwerSapien, false, false)
                                        local unsavedState = serverGOM:getUnsavedPrivateState(throwerSapien)
                                        unsavedState.preventUnnecessaryAutomaticOrderTimer = nil
                                        serverSapienAI:focusOnPlanObjectAfterCompletingOrder(throwerSapien, objectReloaded)
                                    end
                                end
                            end
                        end)

                        if mobType.killNotificationTypeIndex then
                            if throwerSapienID then
                                local throwerSapien = serverGOM:getObjectWithID(throwerSapienID)
                                if throwerSapien then
                                    serverGOM:sendNotificationForObject(throwerSapien, mobType.killNotificationTypeIndex, nil, tribeID)
                                end
                            end
                        end

                        return true
                    else
                        object.sharedState:set("health", health)
                    end
                    return false
                end

                --local mobObjectPos = object.pos
               -- local mobObjectNormalizedPos = object.normalizedPos

                local dead = incrementHitDamage()
                local degradeRemoved = serverGOM:degradeWeapon(weaponObject, toolInfo, throwerSapienID)
                if not degradeRemoved then
                    if toolType.projectileEmbeds then
                        --[[if dead then
                            local objectInfo = serverGOM:getStateForAdditionToInventory(weaponObject)
                            
                            local dropPosNormal = mobObjectNormalizedPos
                            local clampToSeaLevel = true
                            local shiftedPos = worldHelper:getBelowSurfacePos(mobObjectPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                            local shiftedPosLength = length(shiftedPos)
                            local finalDropPos = dropPosNormal * (shiftedPosLength + mj:mToP(4.0)) --todo different heights
                            serverGOM:dropObject(objectInfo, finalDropPos + mj:mToP(rng:randomVec()), tribeID, true)

                            serverGOM:removeGameObject(weaponObject.uniqueID)
                        else]]
                            embedWeapon(object, weaponObject, directionNormal, tribeID)
                        --end
                    else
                        local oldVel = serverGOM:getLinearVelocity(weaponObject.uniqueID)
                        --local oldVelA = serverGOM:getAngularVelocity(weaponObject.uniqueID)
                        serverGOM:setLinearVelocity(weaponObject.uniqueID, oldVel * 0.1)
                        --serverGOM:setAngularVelocity(weaponObject.uniqueID, oldVelA * 0.2)
                        --serverGOM:sendSnapObjectMatrix(weaponObject.uniqueID, false)
                    end
                end

                if not dead then
                    
                    local aiState = getAIState(object)
                    local closestSapien = nil
                    if throwerSapienID then
                        closestSapien = serverGOM:getObjectWithID(throwerSapienID)
                    end
                    agroTriggerd(object, aiState, mobType, closestSapien, -directionNormal)
                    
                end
            end
        else
            serverGOM:degradeAndEmbedProjectileInGroundForThrow(thrownObjectID, throwerSapienID, thrownObjectID, tribeID, 0.1, directionNormal, projectileVelocity, goalPos)
        end
    end)
end

 
function serverMob:createMob(mobTypeIndex, gameObjectTypeIndex, groupID, groupCenter, indexWithinGroup, exitPos, goalMidPointOrNil, extraStateOrNIl, exactRotationOrNil)
    if serverGOM:countOfObjectsInSet(serverGOM.objectSets.mobs) >= maxMobCount then
        mj:warn("Max mob object count limit reached. Not spawning.")
        return nil
    end

    local mobType = mob.types[mobTypeIndex]

    local randomSeedOffset = mobTypeIndex * 100 + indexWithinGroup

    local spawnPos = groupCenter
    local randomVecNormlaized = normalize(rng:vecForUniqueID(groupID, 426 + randomSeedOffset))
    local randomVecPerp = normalize(cross(randomVecNormlaized, groupCenter))
    if not exactRotationOrNil then
        local offsetDistance = mj:mToP(15.0 + 15.0 * rng:valueForUniqueID(groupID, 122 + randomSeedOffset))
        spawnPos = groupCenter + normalize(randomVecPerp) * offsetDistance
    end
    
    local shiftedPos = terrain:getHighestDetailTerrainPointAtPoint(spawnPos)
    local posLength2 = length2(shiftedPos)

    local correctAltitude = false
    if mobType.swims then
        correctAltitude = posLength2 < landSeaAltitudeCutoff2
        if correctAltitude then
            shiftedPos = normalize(shiftedPos) * landSeaAltitudeCutoff
        end
    else
        correctAltitude = posLength2 > landSeaAltitudeCutoff2
    end

    if correctAltitude then

        local rotation = exactRotationOrNil
        if not exactRotationOrNil then
            rotation = mat3LookAtInverse(-randomVecPerp, groupCenter)
        end

        local sharedState = {
            groupID = groupID,
            exitPos = exitPos,
            goalMidPoint = goalMidPointOrNil,
        }

        if extraStateOrNIl then
            for k,v in pairs(extraStateOrNIl) do
                sharedState[k] = v
            end
        end


        local scale = gameObject.types[gameObjectTypeIndex].scale

        local mobID = serverGOM:createGameObject(
            {
                objectTypeIndex = gameObjectTypeIndex,
                addLevel = mj.SUBDIVISIONS - 3,
                pos = shiftedPos,
                rotation = rotation,
                velocity = vec3(0.0,0.0,0.0),
                scale = scale,
                renderType = RENDER_TYPE_DYNAMIC,
                hasPhysics = gameObject.types[gameObjectTypeIndex].hasPhysics,
                sharedState = sharedState,
            }
        )

        --mj:log("spawned mob with id:", mobID)

        return mobID
    end
    return nil
end


function serverMob:createCheatMob(objectTypeIndex, pos, rotation)
    local mobTypeIndex = gameObject.types[objectTypeIndex].mobTypeIndex
    if mobTypeIndex then
        local groupID = serverGOM:reserveUniqueID()
        local spawnDistance = mob.types[mobTypeIndex].spawnDistance
        --local posNormal = normalize(pos)
        --local perpVec = normalize(cross(posNormal, normalize(rng:randomVec())))
        local exitPosNormal = normalize(pos + mat3GetRow(rotation, 2) * spawnDistance)

        serverMob:createMob(mobTypeIndex, objectTypeIndex, groupID, pos, 1, exitPosNormal, nil, nil, rotation)
    end
end

function serverMob:mobLoaded(object)
    local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
    local mobType = mobTypeIndex and mob.types[mobTypeIndex]

    if object.sharedState.dead then -- just in case the timer didn't complete above, eg due to a crash
        if mobType then
            convertToDeadObject(object, nil, mobType)
            return
        end
    end

    if not object.sharedState.spawnTime then
        object.sharedState:set("spawnTime", serverWorld:getWorldTime())
    end
    
    serverGOM:addObjectToSet(object, serverGOM.objectSets.interestingToLookAt)
    serverGOM:addObjectToSet(object, serverGOM.objectSets.mobs)
    serverGOM:addObjectToSet(object, serverGOM.objectSets[mobType.key])
    if not mobType.swims then
        serverGOM:addObjectToSet(object, serverGOM.objectSets.landMobs)
    end


    local aiState = getAIState(object)
    addFrequentUpdateIfNeeded(object, aiState)
    anchor:addAnchor(object.uniqueID, anchor.types.mob.index, nil)

    serverMob.loadedCountsByMobTypeIndex[mobTypeIndex] = serverMob.loadedCountsByMobTypeIndex[mobTypeIndex] + 1
    
end

function serverMob:mobUnloaded(object)
    anchor:anchorObjectUnloaded(object.uniqueID)

    local gameObjectType = gameObject.types[object.objectTypeIndex]
    serverMob.loadedCountsByMobTypeIndex[gameObjectType.mobTypeIndex] = serverMob.loadedCountsByMobTypeIndex[gameObjectType.mobTypeIndex] - 1
end

function serverMob:init(serverGOM_, serverWorld_, serverSapien_, serverSapienAI_, planManager_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    serverSapien = serverSapien_
    serverSapienAI = serverSapienAI_
    --planManager = planManager_


	for i,mobType in ipairs(mob.validTypes) do
        serverMob.loadedCountsByMobTypeIndex[mobType.index] = 0

        local mobSetIndex = serverGOM.objectSets[mobType.key]
        if not mobSetIndex then
            mobSetIndex = serverGOM:createObjectSet(mobType.key)
            serverGOM.objectSets[mobType.key] = mobSetIndex
        end

        local function addMobObjectFunctions(objectTypeIndex)
            serverGOM:addObjectLoadedFunctionForTypes({ objectTypeIndex }, function(object)
                serverMob:mobLoaded(object)
                return false
            end)
    
            serverGOM:addObjectUnloadedFunctionForTypes({objectTypeIndex}, function(object)
                serverMob:mobUnloaded(object)
            end)
        end

        addMobObjectFunctions(mobType.gameObjectTypeIndex)
            
		if mobType.variants then
			for j,variantInfo in ipairs(mobType.variants) do
				if variantInfo.postfix then
					addMobObjectFunctions(variantInfo.gameObjectTypeIndex)
                end
            end
        end


        serverGOM:setInfrequentCallbackForGameObjectsInSet(mobSetIndex, "update", mobType.infrequentUpdatePeriod or 5.0, function(objectID, dt, speedMultiplier)
            serverMob:infrequentUpdate(objectID, dt, speedMultiplier)
        end)

        
        serverGOM:addProximityCallbackForGameObjectsInSet(mobSetIndex, serverGOM.objectSets.sapiens, mobType.reactDistance, function(objectID, sapienID, distance2, newIsClose)
            serverMob:mobSapienProximity(objectID, sapienID, distance2, newIsClose)
        end)
    end

    serverGOM:addProximityCallbackForGameObjectsInSet(serverGOM.objectSets.litCampfires, serverGOM.objectSets.landMobs, gameConstants.fireMobRepelDistance, function(campfireObjectID, mobID, distance2, newIsClose)
        --mj:log("campfire mob proximity callback mob:", mobID, "campfireObjectID:",  campfireObjectID, " newIsClose:", newIsClose)
        local mobObject = serverGOM:getObjectWithID(mobID)
        local campfireObject = serverGOM:getObjectWithID(campfireObjectID)
        if mobObject and campfireObject then
            local unsavedState = serverGOM:getUnsavedPrivateState(mobObject)
            if newIsClose then
                local closeCampfires = unsavedState.closeCampfires
                if not closeCampfires then
                    closeCampfires = {}
                    unsavedState.closeCampfires = closeCampfires
                end
                closeCampfires[campfireObjectID] = campfireObject.normalizedPos
            elseif unsavedState.closeCampfires then
                unsavedState.closeCampfires[campfireObjectID] = nil
                if not next(unsavedState.closeCampfires) then
                    unsavedState.closeCampfires = nil
                end
            end
        end
    end)
    
end

return serverMob