
local typeMaps = mjrequire "common/typeMaps"
local vocal = mjrequire "common/vocal"
local actionSequence = mjrequire "common/actionSequence"
local rng = mjrequire "common/randomNumberGenerator"
local sapienConstants = mjrequire "common/sapienConstants"

local randomOffset = rng:integerForSeed(7153, 200)

local social = {}

local maxFarDistance = mj:mToP(20.0)
local maxFarDistance2 = maxFarDistance * maxFarDistance

local maxMediumDistance = mj:mToP(10.0)
local maxMediumDistance2 = maxMediumDistance * maxMediumDistance

local maxNearDistance = mj:mToP(4.0)
local maxNearDistance2 = maxNearDistance * maxNearDistance

social.interactionDistances = mj:enum {
    "default",
    "near",
    "far",
    "beyondBounds",
}

--[[
{
    key = "goodDay",
},
{
    key = "goodDay_loud",
},
{
    key = "goodEvening",
},]]

social.gestures = typeMaps:createMap("social_gestures", {
    {
        key = "wave",
        actionSequenceTypeIndex = actionSequence.types.wave.index,
    },
})

local function getStandardGreetingVocalTypeIndex(context)
    if context and context.timeOfDayFraction and context.timeOfDayFraction > 0.2  then
        randomOffset = randomOffset + 1
        if randomOffset % 3 == 1 then
            if context.timeOfDayFraction < 0.6 then
                return vocal.phrases.goodDay.index
            else
                return vocal.phrases.goodEvening.index
            end
        end
    end
    return vocal.phrases.toki.index
end

local greetingsByDistance = {
    [social.interactionDistances.default] = function(sapien, otherSapien, context)
        return {
            vocalTypeIndex = getStandardGreetingVocalTypeIndex(context),
            gestureTypeIndex = social.gestures.wave.index,
        }
    end,
    
    [social.interactionDistances.near] = function(sapien, otherSapien, context)
        return {
            vocalTypeIndex = getStandardGreetingVocalTypeIndex(context),
        }
    end,
    
    
    [social.interactionDistances.far] = function(sapien, otherSapien, context)
        local vocalTypeIndex = vocal.phrases.toki_loud.index
        if context and context.timeOfDayFraction and context.timeOfDayFraction > 0.2 and context.timeOfDayFraction < 0.6 then
            randomOffset = randomOffset + 1
            if randomOffset % 3 == 1 then
                vocalTypeIndex = vocal.phrases.goodDay_loud.index
            end
        end
        return {
            vocalTypeIndex = vocalTypeIndex,
            gestureTypeIndex = social.gestures.wave.index,
        }
    end
}

local function createStandardDefaultOrCloseFunction(vocalPhrase, extraDataOrNil)
    return function(interactionDistance, sapien, otherSapien, context)
        if interactionDistance == social.interactionDistances.default or interactionDistance == social.interactionDistances.near then
            local result = {
                vocalTypeIndex = vocalPhrase,
            }

            if extraDataOrNil then
                for k,v in pairs(extraDataOrNil) do
                    result[k] = v
                end
            end

            return result
        else
            return nil
        end
    end
end

social.interactions = typeMaps:createMap("social_interactions", {
    {
        key = "wave",
        getInteraction = function(interactionDistance, sapien, otherSapien, context)
            return {
                gestureTypeIndex = social.gestures.wave.index,
            }
        end
    },
    {
        key = "greeting",
        getInteraction = function(interactionDistance, sapien, otherSapien, context)
            return greetingsByDistance[interactionDistance](sapien, otherSapien, context)
        end
    },
    {
        key = "howAreYou",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.howAreYou.index),
    },
    {
        key = "imOK",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.imOK.index),
    },
    {
        key = "andHowAreYou",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.andHowAreYou.index),
    },
    {
        key = "doYouUnderstand",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.doYouUnderstand.index),
    },
    {
        key = "dontUnderstand",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.dontUnderstand.index),
    },
    {
        key = "understand",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.understand.index),
    },
    {
        key = "enjoyTheFood",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.enjoyTheFood.index),
    },
    {
        key = "excuseMe",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.excuseMe.index),
    },
    {
        key = "fireLit",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.fireLit.index),
    },
    {
        key = "ouchMinor",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.damn.index),
    },
    {
        key = "ouchMajor",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.damn.index),
    },
    {
        key = "ouchCritical",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.damn.index),
    },
    {
        key = "goodNight",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.goodNight.index),
    },
    {
        key = "pona",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.pona.index),
    },
    {
        key = "sorry",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.sorry.index),
    },
    {
        key = "thanks",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.thanks.index),
    },
    {
        key = "beQuiet",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.beQuiet.index),
    },
    {
        key = "chuckle",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.chuckle.index),
    },
    {
        key = "cough",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.cough.index, {spreadsVirus = true}),
    },
    {
        key = "damn",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.damn.index),
    },
    {
        key = "go",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.go.index),
    },
    {
        key = "goodbye",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.goodbye.index),
    },
    {
        key = "haveFun",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.haveFun.index),
    },
    {
        key = "iDontLikeThat",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.iDontLikeThat.index),
    },
    {
        key = "iDontHaveFood",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.iDontHaveFood.index),
    },
    {
        key = "iDontKnowWhy",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.iDontKnowWhy.index),
    },
    {
        key = "iJustWork",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.iJustWork.index),
    },
    {
        key = "iMissYou",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.iMissYou.index),
    },
    {
        key = "imLazy",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.imLazy.index),
    },
    {
        key = "imOK",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.imOK.index),
    },
    {
        key = "iWantToEatChicken",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.iWantToEatChicken.index),
    },
    {
        key = "leaveMeAlone",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.leaveMeAlone.index),
    },
    {
        key = "letsGo",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.letsGo.index),
    },
    {
        key = "please",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.please.index),
    },
    {
        key = "thatsFunny",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.thatsFunny.index),
    },
    {
        key = "yawn",
        getInteraction = createStandardDefaultOrCloseFunction(vocal.phrases.yawn.index),
    },
})

function social:getSocialInteractionDistance(distance2)
    if distance2 < maxFarDistance2 then
        if distance2 < maxMediumDistance2 then
            if distance2 < maxNearDistance2 then
                return social.interactionDistances.near
            end
            return social.interactionDistances.default
        end
        return social.interactionDistances.far
    end
    return social.interactionDistances.beyondBounds
end

function social:getExclamation(sapien, socialInteractionTypeIndex, context)
    local socialInteractionType = social.interactions[socialInteractionTypeIndex]
    local interactionNotificationUserData = socialInteractionType.getInteraction(social.interactionDistances.near, sapien, nil, context)
    if interactionNotificationUserData then
        local voiceTypeIndex = vocal.voices.dave.index
        if sapien.sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then 
            voiceTypeIndex = vocal.voices.ethan.index
        elseif sapien.sharedState.isFemale then
            voiceTypeIndex = vocal.voices.emma.index
        end
        interactionNotificationUserData.voiceTypeIndex = voiceTypeIndex
    end
    return interactionNotificationUserData
end


return social