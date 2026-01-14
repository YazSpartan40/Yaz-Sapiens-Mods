local animationGroups = mjrequire "common/animationGroups"

local uiAnimation = {}

function uiAnimation:getUIAnimationInstance(animationGroupKey, animationTypeKeyOrNil)
    local animationGroup = animationGroups.groups[animationGroupKey]
    local uiAnimationTypeKey = animationTypeKeyOrNil or animationGroup.default
    --mj:log("uiAnimationTypeKey:", uiAnimationTypeKey, " animationGroup.animations:", animationGroup.animations)
    return {
        animationFrameIndex = 0,
        modelTypeIndex = animationGroup.modelTypeIndex,
        keyframes = animationGroup.animations[uiAnimationTypeKey].keyframes
    }
end


function uiAnimation:getNextAnimationFrame(animationInstance, offsetOrNil)
    local newAnimationFrameIndex = animationInstance.animationFrameIndex + 1
    local nextNewAnimationFrameIndex = animationInstance.animationFrameIndex + 2
    if offsetOrNil then
        newAnimationFrameIndex = newAnimationFrameIndex + offsetOrNil
        nextNewAnimationFrameIndex = nextNewAnimationFrameIndex + offsetOrNil
    end

    local animationKeyframes = animationInstance.keyframes

    if newAnimationFrameIndex > #animationKeyframes then
        newAnimationFrameIndex = newAnimationFrameIndex % #animationKeyframes
        if newAnimationFrameIndex == 0 then
            newAnimationFrameIndex = #animationKeyframes
        end
    end

    if nextNewAnimationFrameIndex > #animationKeyframes then
        nextNewAnimationFrameIndex = nextNewAnimationFrameIndex % #animationKeyframes
        if nextNewAnimationFrameIndex == 0 then
            nextNewAnimationFrameIndex = #animationKeyframes
        end
    end

    local speed = 1.0 / animationKeyframes[newAnimationFrameIndex][2]
    local nextSpeed = 1.0 / animationKeyframes[nextNewAnimationFrameIndex][2]

    local easeIn = 1.0
    local easeOut = 1.0

    local extraData = animationKeyframes[newAnimationFrameIndex][3]
    if extraData then
        if extraData.ease then
            easeIn = extraData.ease[1]
            easeOut = extraData.ease[2]
        end
    end

    animationInstance.animationFrameIndex = newAnimationFrameIndex

    return {
        animationKeyframes[newAnimationFrameIndex][1], 
        speed,
        animationKeyframes[nextNewAnimationFrameIndex][1], 
        nextSpeed,
        easeIn, 
        easeOut
    }
end

return uiAnimation