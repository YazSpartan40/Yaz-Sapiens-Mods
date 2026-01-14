local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local normalize = mjm.normalize
local mat3Identity = mjm.mat3Identity
local dot = mjm.dot
local length2 = mjm.length2
local length = mjm.length
local mat3LookAtInverse = mjm.mat3LookAtInverse
--local vec3xMat3 = mjm.vec3xMat3
local mat3Rotate = mjm.mat3Rotate
--local mat3Inverse = mjm.mat3Inverse
local mat3GetRow = mjm.mat3GetRow
local mat3Slerp = mjm.mat3Slerp

local mob = mjrequire "common/mob/mob"
local gameObject = mjrequire "common/gameObject"
local mobInventory = mjrequire "common/mobInventory"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local rng = mjrequire "common/randomNumberGenerator"
local animationGroups = mjrequire "common/animationGroups"
--local worldHelper = mjrequire "common/worldHelper"
--local physicsSets = mjrequire "common/physicsSets"

local clientObjectAnimation = mjrequire "logicThread/clientObjectAnimation"

local logicAudio = mjrequire "logicThread/logicAudio"

local clientMob = {}

local clientGOM = nil

local minSoundTime = 10.0
local randomSoundTimeMultiplier = 100.0

local randomCounter = 0

local snapDistanceMax2 = mj:mToP(10.0) * mj:mToP(10.0)
local walkDistanceMax2 = mj:mToP(0.5) * mj:mToP(0.5)

local debugServerState = false


local function snapToPos(object, newPos, rotation)
    if object.uniqueID == mj.debugObject then
        mj:debug("snapToPos")
    end
    local clientState = clientGOM:getClientState(object)
    clientState.walkGoalPosNormal = normalize(newPos)
   -- clientState.directionNormal = mat3GetRow(rotation, 2)
    clientGOM:updateMatrix(object.uniqueID, newPos, rotation)
end

local function loadRandomAnimation(object, clientState, mobType)
    local sharedState = object.sharedState
    local animationsList = mobType.idleAnimations
    if sharedState.sleeping or ((not sharedState.spooked) and clientState.idleAnimationCounter and clientState.idleAnimationCounter > 2 and rng:randomBool()) then
        animationsList = mobType.sleepAnimations
    elseif sharedState.agro and mobType.agroIdleAnimations then
        animationsList = mobType.agroIdleAnimations
    end

    clientState.idleAnimationCounter = (clientState.idleAnimationCounter or 0) + 1
    clientState.walkSpeed = 1.0

    randomCounter = randomCounter + 1
    local randomIndex = rng:integerForUniqueID(object.uniqueID, 215 + randomCounter, #animationsList) + 1
    local animationGroup = animationGroups.groups[mobType.animationGroup]
    local animations = animationGroup.animations
    ----disabled--mj:objectLog(object.uniqueID, "loadRandomAnimation sharedState:", sharedState)
    clientObjectAnimation:changeAnimation(object, animations[animationsList[randomIndex]].index, animationGroup.index, clientState.walkSpeed)
end


local function updateClientRotationGoal(object, clientState, objectNormal, newDirection) --protects against looking straight up or down
   --[[ if object.uniqueID == mj.debugObject then
        mj:debug("updateClientRotationGoal:", newDirection)
    end]]

    local dp = dot(newDirection, objectNormal)
    if dp > -0.9999 and dp < 0.9999 then
        local rotation = mat3LookAtInverse(newDirection, objectNormal)
        clientState.rotationGoal = rotation
    end
end

clientMob.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
    local mobType = mob.types[mobTypeIndex]

    local clientState = clientGOM:getClientState(object)
    clientState.serverPos = pos

    --disabled--mj:objectLog(object.uniqueID, "server update ", mobTypeIndex, " altitude:", mj:pToM(length(pos) - 1.0))

    if debugServerState then
        snapToPos(object, pos, rotation)
        loadRandomAnimation(object, clientState, mobType)
        return
    end

    local animationGroupKey = mobType.animationGroup
    local animationGroup = animationGroups.groups[animationGroupKey]
    local animations = animationGroup.animations
    local sharedState = object.sharedState

    local posToUse = sharedState.goalPos
    if not posToUse then
        posToUse = pos
    end

    if sharedState.dead then
        if not clientState.dead then
            if animations.dead and clientState.animationTypeIndex ~= animations.dead then
                clientState.walkSpeed = 1.0
                clientObjectAnimation:changeAnimation(object, animations.dead.index, animationGroup.index, 1.0)
            end
            clientState.dead = true
            if mobType.deathSound then
                local pitch = 0.85 + rng:valueForUniqueID(object.uniqueID, 932) * 0.1
                logicAudio:playWorldSound("audio/sounds/" .. mobType.deathSound .. ".wav", object.pos, mobType.soundVolume, pitch, nil, mobType.maxSoundDistance2)
            end

            if mobType.deathAnimation then
                clientState.walkSpeed = 1.0
                clientObjectAnimation:changeAnimation(object, animations[mobType.deathAnimation].index, animationGroup.index, 1.0)
            end
        end
    elseif sharedState.sleeping then
        clientState.walking = false
        loadRandomAnimation(object, clientState, mobType)
    else
        if sharedState.attackSapienID then
            local sapien = clientGOM:getObjectWithID(sharedState.attackSapienID)
            if sapien then
                local sapienDirectionVec = sapien.pos - object.pos
                local sapienDistance2 = length2(sapienDirectionVec)
                if sapienDistance2 > mj:mToP(0.1) * mj:mToP(0.1) then
                    local sapienDirection = sapienDirectionVec / math.sqrt(sapienDistance2)
                    updateClientRotationGoal(object, clientState, object.normalizedPos, sapienDirection)
                end
            end
            if not animations.attack then
                mj:error("mobs that attack must be given an attack animation. Problem mob type:", mobType.key)
            else
                --disabled--mj:objectLog(object.uniqueID, "setAnimation b:", animations.attack)
                clientState.walkSpeed = 1.0
                clientObjectAnimation:changeAnimation(object, animations.attack.index, animationGroup.index, 1.0)
                clientState.idleAnimationCounter = nil
            end
        else
            local posDistance2 = length2(object.pos - posToUse)
            if posDistance2 > snapDistanceMax2 then
                snapToPos(object, posToUse, rotation)
                clientState.walking = false
            elseif posDistance2 > walkDistanceMax2 then
                local animationType = animations[mobType.walkAnimation or "walk"]

                if sharedState.agro and mobType.agroWalkAnimation then
                    animationType = animations[mobType.agroWalkAnimation]
                end

                if (sharedState.walkSpeed and sharedState.walkSpeed > 1.1) then
                    clientState.walkSpeed = sharedState.walkSpeed
                    if mobType.runAnimation then
                        animationType = animations[mobType.runAnimation]
                    end
                else
                    clientState.walkSpeed = 1.0
                end
                
                --[[if mj.debugObject == object.uniqueID then
                    mj:log("animationType:", animationType)
                end]]

                clientObjectAnimation:changeAnimation(object, animationType.index, animationGroup.index, clientState.walkSpeed)

                clientState.idleAnimationCounter = nil
                clientState.walking = true
                clientState.walkGoalPosNormal = normalize(posToUse)
               -- updateClientRotationGoal(object, clientState, object.normalizedPos, normalize(clientState.walkGoalPosNormal - object.normalizedPos))
                --clientState.directionNormal = normalize(clientState.walkGoalPosNormal - normalize(object.pos))
            else
                if sharedState.agressiveLookDirection then
                    updateClientRotationGoal(object, clientState, object.normalizedPos, sharedState.agressiveLookDirection)
                    clientState.idleAnimationCounter = nil
                    --clientState.directionNormal = sharedState.agressiveLookDirection
                end

                if (not clientState.animationSent) or clientState.walking then
                    clientState.walking = false
                    loadRandomAnimation(object, clientState, mobType)
                end
            end
        end
    end

    clientMob:updateEmbededObjects(object, mobType)
end

clientMob.objectWasLoaded = function(object, pos, rotation, scale)
    --mj:log("clientMob.objectWasLoaded:", object.uniqueID)
    local clientState = clientGOM:getClientState(object)
    clientState.serverPos = pos
    clientState.soundTimer = rng:valueForUniqueID(object.uniqueID, 47) * randomSoundTimeMultiplier + 2.0
    clientState.animationChangeTimer = rng:valueForUniqueID(object.uniqueID, 48) * 10.0 + 1.0

    snapToPos(object, pos, rotation)

    clientGOM:addObjectToSet(object, clientGOM.objectSets.mobs)
    clientMob.serverUpdate(object, pos, rotation, scale, nil)
end

function clientMob:mobUpdate(object, dt, speedMultiplier) --NOTE this is only called for visible mobs
    local sharedState = object.sharedState
    if sharedState.dead then
        return
    end

    local mobTypeIndex = gameObject.types[object.objectTypeIndex].mobTypeIndex
    if not mobTypeIndex then
        mj:log("trying to call mob update on incorrect object type for object with id:", object.uniqueID)
        return
    end

    local mobType = mob.types[mobTypeIndex]

    local clientState = clientGOM:getClientState(object)
    
    if not sharedState.sleeping then
        
        if sharedState.attackSapienID then
            if mobType.soundAngryBaseName and clientState.soundPlayedAttackSapienID ~= sharedState.attackSapienID then
                clientState.soundPlayedAttackSapienID = sharedState.attackSapienID
                randomCounter = randomCounter + 1
                local randomSound = rng:integerForUniqueID(object.uniqueID, 4223 + randomCounter, mobType.soundAngryBaseCount) + 1
                local pitch = 0.85 + rng:valueForUniqueID(object.uniqueID, 932) * 0.1
                logicAudio:playWorldSound("audio/sounds/" .. mobType.soundAngryBaseName .. mj:tostring(randomSound) .. ".wav", object.pos, mobType.soundVolume, pitch, nil, mobType.maxSoundDistance2)
            end
        else
            if mobType.soundRandomBaseName then
                clientState.soundPlayedAttackSapienID = nil
                clientState.soundTimer =  clientState.soundTimer - dt * math.min(speedMultiplier, 3.0)
                if clientState.soundTimer < 0.0 then
                    randomCounter = randomCounter + 1
                    clientState.soundTimer = 0.1 + rng:valueForUniqueID(object.uniqueID, 47 + randomCounter) * randomSoundTimeMultiplier + minSoundTime

                    local randomSound = rng:integerForUniqueID(object.uniqueID, 4123 + randomCounter, mobType.soundRandomBaseCount) + 1
                    local pitch = 0.85 + rng:valueForUniqueID(object.uniqueID, 932) * 0.1
                    logicAudio:playWorldSound("audio/sounds/" .. mobType.soundRandomBaseName .. mj:tostring(randomSound) .. ".wav", object.pos, mobType.soundVolume, pitch, nil, mobType.maxSoundDistance2)
                end
            end
        end
    end

    local newRotation = nil
    local newPos = nil

    local function moveToPos(normalizedMoveToPos)

        local done = false

        --[[if mobType.swims then
            --local swimVelocity = clientState.swimVelocity or vec3(0.0,0.0,0.0)
            local dtAtSpeed = mjm.clamp(dt * speedMultiplier, 0.0, 1.0)

            if object.sharedState.goalPos then
                local goalDirectionVec = object.sharedState.goalPos - object.pos
                local goalDirectionLength = length(goalDirectionVec)

                --local walkDistanceToUse = mob.types[mobTypeIndex].walkSpeed * dt * speedMultiplier * clientState.walkSpeed
                local directionNormal = nil
                local desiredVelocity = vec3(0.0,0.0,0.0)
                if goalDirectionLength > mj:mToP(0.1) then
                    directionNormal = goalDirectionVec / goalDirectionLength
                    updateClientRotationGoal(object, clientState, object.normalizedPos, directionNormal)
                    desiredVelocity = directionNormal * (mob.types[mobTypeIndex].walkSpeed * clientState.walkSpeed) * (0.25 + (goalDirectionLength /  mj:mToP(8.0)))
                end

                local currentVelocity = clientState.swimVelocity or vec3(0.0,0.0,0.0)
                clientState.swimVelocity = currentVelocity * (1.0 - dtAtSpeed) + desiredVelocity * dtAtSpeed
                newPos = object.pos + clientState.swimVelocity * dtAtSpeed
            else
                local currentVelocity = clientState.swimVelocity or vec3(0.0,0.0,0.0)
                clientState.swimVelocity = currentVelocity * (1.0 - dtAtSpeed)
                newPos = object.pos + clientState.swimVelocity * dtAtSpeed
            end
        else]]
            local dtAtSpeed = mjm.clamp(dt * speedMultiplier, 0.0, 1.0)

            if object.sharedState.goalPos then
                local speedUpMultiplier = 4.0
                if mobType.swims then
                    speedUpMultiplier = 2.0
                end
                local goalDirectionVec = object.sharedState.goalPos - object.pos
                local goalDirectionLength = length(goalDirectionVec)

                local lerpDtClamped = math.min(dtAtSpeed * speedUpMultiplier, 1.0)

                clientState.rawGoalLengthFactor = (clientState.rawGoalLengthFactor or 0.0) * math.max(1.0 - lerpDtClamped, 0.0) + (goalDirectionLength / mj:mToP(4.5)) * lerpDtClamped

                --local walkDistanceToUse = mob.types[mobTypeIndex].walkSpeed * dt * speedMultiplier * clientState.walkSpeed
                local directionNormal = nil
                local desiredVelocity = vec3(0.0,0.0,0.0)
                local desiredVelocityMagnitude = 0.0

                if goalDirectionLength > mj:mToP(0.1) then
                    directionNormal = goalDirectionVec / goalDirectionLength
                    updateClientRotationGoal(object, clientState, object.normalizedPos, directionNormal)
                    desiredVelocityMagnitude =  (0.5 + (goalDirectionLength /  mj:mToP(12.0)))
                    desiredVelocity = directionNormal * (mob.types[mobTypeIndex].walkSpeed * clientState.walkSpeed) * desiredVelocityMagnitude
                end

                
                clientState.velocityMagnitude = (clientState.velocityMagnitude or 0.0) * (1.0 - lerpDtClamped) + desiredVelocityMagnitude * lerpDtClamped

                local currentVelocity = clientState.swimVelocity or vec3(0.0,0.0,0.0)
                clientState.swimVelocity = currentVelocity * (1.0 - lerpDtClamped) + desiredVelocity * lerpDtClamped
                newPos = object.pos + clientState.swimVelocity * dtAtSpeed

            else
                local slowDownMultiplier = 32.0
                if mobType.swims then
                    slowDownMultiplier = 1.0
                end
                clientState.velocityMagnitude = (clientState.velocityMagnitude or 0.0) * math.max(1.0 - dtAtSpeed * slowDownMultiplier, 0.0)
                clientState.rawGoalLengthFactor = 0.0

                if clientState.velocityMagnitude < 0.1 and (not mobType.swims) then
                    done = true
                else
                    local currentVelocity = clientState.swimVelocity or vec3(0.0,0.0,0.0)
                    clientState.swimVelocity = currentVelocity * (1.0 - dtAtSpeed)
                    newPos = object.pos + clientState.swimVelocity * dtAtSpeed
                end
            end
            

            clientObjectAnimation:changeAnimationSpeed(object, clientState.walkSpeed * (clientState.velocityMagnitude or 1.0))
       -- end

        ----disabled--mj:objectLog(object.uniqueID, "moveToPos current altitude:", mj:pToM(newPosLength - 1.0), " server altitude:", mj:pToM(length(clientState.serverPos) - 1.0))

        return not done
    end

    

    if clientState.rotationGoal then
        ----disabled--mj:objectLog(object.uniqueID, "clientState.rotationGoal:", clientState.rotationGoal)
        
        local goalSlerpSpeedBase = (mobType.rotationSpeedMultiplier or 1.0) * 12.0 * (clientState.rawGoalLengthFactor or 0.0)

        if goalSlerpSpeedBase > 0.0001 then

            if sharedState.agressiveLookDirection then
                goalSlerpSpeedBase = goalSlerpSpeedBase * 4.0
            end

            local allComplete = true

            local rotationGoalSmoothed = clientState.rotationGoalSmoothed or object.rotation
            local goalDp = dot(mat3GetRow(rotationGoalSmoothed, 2), mat3GetRow(clientState.rotationGoal, 2))
            if goalDp < 0.99999 then
                rotationGoalSmoothed = mat3Slerp(rotationGoalSmoothed, clientState.rotationGoal, mjm.clamp(dt * goalSlerpSpeedBase * speedMultiplier, 0.0, 1.0))
                clientState.rotationGoalSmoothed = rotationGoalSmoothed
                allComplete = false
            else
                rotationGoalSmoothed = clientState.rotationGoal
            end


            local lookDp = dot(mat3GetRow(object.rotation, 2), mat3GetRow(rotationGoalSmoothed, 2))
            if lookDp < 0.99999 then
                newRotation = mat3Slerp(object.rotation, rotationGoalSmoothed, mjm.clamp(dt * goalSlerpSpeedBase * speedMultiplier * 0.3, 0.0, 1.0))
                allComplete = false
            else 
                newRotation = rotationGoalSmoothed
            end

            
        -- --disabled--mj:objectLog(object.uniqueID, " lookDp:", lookDp, " allComplete:", allComplete, " teest b:", dot(mat3GetRow(object.rotation, 0), mat3GetRow(rotationGoalSmoothed, 0)))

            if allComplete then
                clientState.rotationGoal = nil
            end
        end

    end

    if sharedState.sleeping then
        clientState.animationChangeTimer = clientState.animationChangeTimer - dt * math.min(speedMultiplier, 3.0) * 0.1
        if clientState.animationChangeTimer < 0.0 then
            randomCounter = randomCounter + 1
            clientState.animationChangeTimer = 10.0 + rng:valueForUniqueID(object.uniqueID, 48 + randomCounter) * 10.0
            loadRandomAnimation(object, clientState, mobType)
        end
    elseif clientState.walking then
        if not moveToPos(clientState.walkGoalPosNormal) then
            loadRandomAnimation(object, clientState, mobType)
            clientState.walking = false
        end
    else
        clientState.animationChangeTimer = clientState.animationChangeTimer - dt * math.min(speedMultiplier, 3.0)
        if clientState.animationChangeTimer < 0.0 then
            randomCounter = randomCounter + 1
            clientState.animationChangeTimer = 10.0 + rng:valueForUniqueID(object.uniqueID, 48 + randomCounter) * 10.0
            loadRandomAnimation(object, clientState, mobType)
        end
    end

    if newRotation or newPos then
        
        --[[if object.uniqueID == mj.debugObject then
            if newRotation then
                mj:log("calling clientGOM:updateMatrix:", mat3GetRow(newRotation, 0))
                if clientState.rotationGoal then
                    mj:log("clientState.rotationGoal:", mat3GetRow(clientState.rotationGoal, 0))
                end
            else
                mj:log("calling clientGOM:updateMatrix due to pos change only")
            end
        end]]

        clientGOM:updateMatrix(object.uniqueID, newPos or object.pos, newRotation or object.rotation)
    end
end

function clientMob:updateEmbededObjects(object, mobType)
    local clientState = clientGOM:getClientState(object)
    local incomingHeldObjects = mobInventory:getObjects(object, mobInventory.locations.embeded.index)

    
    local function getKey(heldObjectIndex)
        return "h_" .. mj:tostring(heldObjectIndex)
    end

    local function removeSubModelObjectAtIndex(heldObjectIndex)
        local key = getKey(heldObjectIndex)
        clientGOM:removeSubModelForKey(object.uniqueID, key)
    end


    local function assignObject(index, objectInfo)
        clientState.inventoryObjectInfos[index] = {
            objectInfo = objectInfo,
        }
        local gameObjectType = gameObject.types[objectInfo.objectTypeIndex]
        
        local offset = vec3(0.0,0.0,0.0)
        local rotation = mat3Identity
        if objectInfo.embedRotation then
            local randomAngle = rng:valueForUniqueID(object.uniqueID, 3582 + index)
            local rotatedEmbedRotation = mat3Rotate(objectInfo.embedRotation, math.pi * 0.3 * (randomAngle - 0.3), vec3(1.0,0.0,0.0))
            rotation = mat3Rotate(rotatedEmbedRotation,math.pi * -0.5, vec3(0.0,1.0,0.0))-- * mat3Rotate(mat3Identity, math.pi * -0.5, vec3(0.0,1.0,0.0))
            local zVec = mat3GetRow(rotatedEmbedRotation, 2)
            local embedBoxHalfSize = mobType.embedBoxHalfSize
            offset = vec3(-zVec.x * embedBoxHalfSize.x,-zVec.y * embedBoxHalfSize.y,-zVec.z * embedBoxHalfSize.z) - zVec * 0.7 --offset to edge of 1x1x3 box, then add half spear size
        end

        clientGOM:setSubModelForKey(object.uniqueID,
            getKey(index),
            "bodyInventory",
            gameObjectType.modelIndex,
            1.0,
            RENDER_TYPE_DYNAMIC,
            offset,
            rotation,
            false,
            modelPlaceholder:getSubModelInfos(objectInfo, mj.SUBDIVISIONS - 1)
            )

    end
    
    local updateCounter = 0
    if clientState.inventoryObjectInfos then
        for i,oldHoldingObjectInfo in ipairs(clientState.inventoryObjectInfos) do
            if incomingHeldObjects and incomingHeldObjects[i] then
                local newHeldObjectInfo = incomingHeldObjects[i]
                if oldHoldingObjectInfo.objectInfo.objectTypeIndex ~= newHeldObjectInfo.objectTypeIndex then
                    assignObject(i, newHeldObjectInfo)
                end
            else
                removeSubModelObjectAtIndex(i)
                clientState.inventoryObjectInfos[i] = nil
            end
            updateCounter = updateCounter + 1
        end
    end

    if incomingHeldObjects and updateCounter < #incomingHeldObjects then
        for i = updateCounter + 1, #incomingHeldObjects do
            local newHeldObjectInfo = incomingHeldObjects[i]
            if i == 1 then
                clientState.inventoryObjectInfos = {}
            end

            assignObject(i, newHeldObjectInfo)
        end
    elseif clientState.inventoryObjectInfos and not clientState.inventoryObjectInfos[1] then
        clientState.inventoryObjectInfos = nil
    end

end

function clientMob:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientMob