local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3Rotate = mjm.mat3Rotate
local mat3Identity = mjm.mat3Identity

local animationGroups = mjrequire("common/animationGroups")
--local timer = mjrequire "common/timer"
local rng = mjrequire "common/randomNumberGenerator"

local animationManager = {}

local bridge = nil
--local world = nil

function animationManager:setWorld(world_)
    --world = world_
end

function animationManager:setBridge(bridge_)
    bridge = bridge_
    --mj:log("animationGroups:", animationGroups)
    animationGroups:initMainThread()
    for i,animationInfo in ipairs(animationGroups.groups) do
        bridge:addAnimationGroup(animationInfo)
    end
end

function animationManager:setAnimationIndexForObject(objectID, animationGroupIndex, animationTypeIndex, speedMultiplier)
    if not animationTypeIndex then
        mj:log("ERROR: atttmpt to set nil animationTypeIndex in animationManager:setAnimationIndexForObject. ObjectID:", objectID, " animationGroupIndex:", animationGroupIndex)
        return
    end

    --mj:log("animationManager:setAnimationIndexForObject:", objectID, " animationGroupIndex:", animationGroupIndex, " animationTypeIndex:", animationTypeIndex)

    bridge:setAnimationIndexForObject(objectID, animationGroupIndex, animationTypeIndex, speedMultiplier)
end

function animationManager:removeAnimationObject(objectID)
    bridge:removeAnimationObject(objectID)
end

function animationManager:setBoneRotation(objectID, boneName, rotationMatrix, additive, rate)
    if rotationMatrix then
        bridge:setBoneRotation(objectID, boneName, rotationMatrix, additive, rate)
    else
        bridge:removeBoneRotation(objectID, boneName)
    end
end

function animationManager:updateHeadRotation(objectID, rotationMatrix, rate)
    --disabled--mj:objectLog(objectID, "updateHeadRotation rate:", rate, " rotationMatrix:", rotationMatrix)
    if rotationMatrix then
        bridge:setBoneRotation(objectID, "head", rotationMatrix, false, rate)
    else
        bridge:removeBoneRotation(objectID, "head")
    end
end

local talkAnimations = {}

local frameDurationMin = 0.15
local frameDurationMax = 0.25

local frameDurationDifference = frameDurationMax - frameDurationMin

local mouthDownRotations = {}
local mouthDownRotationCount = 8

for i=1,mouthDownRotationCount do
    mouthDownRotations[i] = mat3Rotate(mat3Identity, 0.25 * rng:randomValue(), vec3(1.0,0.0,0.0))
end

function animationManager:playSapienTalkAnimation(sapienID, phraseDuration)
    --[[--disabled--mj:objectLog(sapienID, "animationManager:playSapienTalkAnimation:", phraseDuration)
    local oldAnimation = talkAnimations[sapienID]
    if oldAnimation then
        timer:removeTimer(oldAnimation.timerID)
    end

    local callbackFunction = nil

    callbackFunction = function()
        local currentAnimation = talkAnimations[sapienID]
        currentAnimation.timer = currentAnimation.timer - currentAnimation.frameDuration

        local mouthRotation = nil

        if currentAnimation.timer > frameDurationMax then
            local frameDuration = (frameDurationMin + frameDurationDifference * rng:randomValue())
            currentAnimation.timerID = timer:addCallbackTimer(math.min(phraseDuration, frameDuration), callbackFunction)
            currentAnimation.frameDuration = frameDuration
            mouthRotation = mouthDownRotations[rng:randomInteger(mouthDownRotationCount) + 1]
        end
        
        --disabled--mj:objectLog(sapienID, "timer callback:", mouthRotation)
        animationManager:setBoneRotation(sapienID, "jaw", mouthRotation, true, 4.0)
    end

    local frameDuration = (frameDurationMin + frameDurationDifference * rng:randomValue())
        
    local timerID = timer:addCallbackTimer(math.min(phraseDuration, frameDuration), callbackFunction)

    local newAnimation = {
        timerID = timerID,
        timer = phraseDuration,
        frameDuration = frameDuration,
    }
    talkAnimations[sapienID] = newAnimation]]
    
    local frameDuration = (frameDurationMin + frameDurationDifference * rng:randomValue())
    
    talkAnimations[sapienID] = {
        frameTimer = frameDuration,
        remainingTime = phraseDuration - frameDuration,
    }
end

function animationManager:update(dt)
    for sapienID, info in pairs(talkAnimations) do
        info.frameTimer = info.frameTimer - dt
        if info.frameTimer <= 0.0 then
            local mouthRotation = nil
            if info.remainingTime <= 0.0 then
                talkAnimations[sapienID] = nil
            else
                local frameDuration = (frameDurationMin + frameDurationDifference * rng:randomValue())
                info.frameTimer = frameDuration
                info.remainingTime = info.remainingTime - frameDuration
                mouthRotation = mouthDownRotations[rng:randomInteger(mouthDownRotationCount) + 1]
            end
            animationManager:setBoneRotation(sapienID, "jaw", mouthRotation, true, 2.0)
        end
    end
end


return animationManager