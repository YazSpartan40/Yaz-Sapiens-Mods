local mjm = mjrequire "common/mjm"
local length2 = mjm.length2

local social = mjrequire "common/social"
local statusEffect = mjrequire "common/statusEffect"
local mood = mjrequire "common/mood"
local rng = mjrequire "common/randomNumberGenerator"
local vocal = mjrequire "common/vocal"
local sapienConstants = mjrequire "common/sapienConstants"

local serverWorld = nil
local serverGOM = nil
local serverWeather = nil

local conversation = {}

local currentVoices = {}

local currentVoicesExclusionDistance = mj:mToP(15.0)
local currentVoicesExclusionDistance2 = currentVoicesExclusionDistance * currentVoicesExclusionDistance

local interactionProgression = {
    social.interactions.greeting.index,
    social.interactions.howAreYou.index,
    social.interactions.chuckle.index,
    social.interactions.imOK.index,
    social.interactions.andHowAreYou.index,
    social.interactions.iMissYou.index,
    social.interactions.thatsFunny.index,
    social.interactions.doYouUnderstand.index,
    social.interactions.dontUnderstand.index,
    social.interactions.please.index,
    social.interactions.iDontKnowWhy.index,
    social.interactions.understand.index,
    social.interactions.enjoyTheFood.index,
    social.interactions.thanks.index,
    social.interactions.excuseMe.index,
    social.interactions.letsGo.index,
    social.interactions.go.index,
    social.interactions.haveFun.index,
    social.interactions.goodbye.index,
}

local hungryInteractions = {
    social.interactions.iDontHaveFood.index,
    social.interactions.iWantToEatChicken.index,
    social.interactions.dontUnderstand.index,
    social.interactions.iDontKnowWhy.index,
    social.interactions.please.index,
    social.interactions.understand.index,
    social.interactions.leaveMeAlone.index,
}

local tiredInteractions = {
    social.interactions.iJustWork.index,
    social.interactions.imLazy.index,
    social.interactions.yawn.index,
    social.interactions.leaveMeAlone.index,
    social.interactions.dontUnderstand.index,
    social.interactions.iDontKnowWhy.index,
    social.interactions.please.index,
    social.interactions.understand.index,
    social.interactions.yawn.index,
    social.interactions.yawn.index,
}

local sickInteractions = {
    social.interactions.cough.index,
    social.interactions.imLazy.index,
    social.interactions.cough.index,
    social.interactions.damn.index,
    social.interactions.cough.index,
    social.interactions.yawn.index,
}

local sadInteractions = {
    social.interactions.beQuiet.index,
    social.interactions.sorry.index,
    social.interactions.damn.index,
    social.interactions.iDontLikeThat.index,
    social.interactions.leaveMeAlone.index,
    social.interactions.yawn.index,
}

local panicInteractions = {
    social.interactions.damn.index,
    social.interactions.iDontLikeThat.index,
    social.interactions.leaveMeAlone.index,
}

local hungryStatusEffects = {
    statusEffect.types.starving.index,
    statusEffect.types.veryHungry.index,
    statusEffect.types.hungry.index
}

local tiredStatusEffects = {
    statusEffect.types.exhaustedSleep.index,
    statusEffect.types.exhausted.index,
    statusEffect.types.tired.index,
    statusEffect.types.overworked.index,
}

local sickStatusEffects = {
    statusEffect.types.minorVirus.index,
    statusEffect.types.majorVirus.index,
    statusEffect.types.criticalVirus.index
}


function conversation:getNextInteractionInfo(sapien, otherSapien)
    --disabled--mj:objectLog(sapien.uniqueID, "conversation:getNextInteractionInfo:", otherSapien.uniqueID)
    --local sapienPrivateState = sapien.privateState
    --local otherPrivateState = otherSapien.privateState



    local distance2 = length2(sapien.pos - otherSapien.pos)

    local socialInteractionDistance = social:getSocialInteractionDistance(distance2)

    if socialInteractionDistance == social.interactionDistances.beyondBounds then
        --disabled--mj:objectLog(sapien.uniqueID, "social.interactionDistances.beyondBounds")
        return nil
    end
    
    local worldTime = serverWorld:getWorldTime()
    for i=#currentVoices,1,-1 do
        local currentVoiceInfo = currentVoices[i]
        if worldTime - currentVoiceInfo.time > 1.0 then
            table.remove(currentVoices, i)
        else
            if currentVoiceInfo.uniqueID == otherSapien.uniqueID then
                return nil
            end
            local distance2FromCurrentVoice = length2(sapien.pos - currentVoiceInfo.pos)
            if distance2FromCurrentVoice < currentVoicesExclusionDistance2 then
                return nil
            end
        end
    end

    local function hasEffect(statusEffectsArray)
        for i,statusEffectTypeIndex in ipairs(statusEffectsArray) do
            if statusEffect:hasEffect(sapien.sharedState, statusEffectTypeIndex) then
                return true
            end
        end
        return false
    end

    local interactionTypeIndex = nil

    if serverWeather:getIsDamagingWindStormOccuring() then
        local interactionIndex = rng:randomInteger(#panicInteractions * 2) + 1 --note #*2, so half will be nil
        interactionTypeIndex = panicInteractions[interactionIndex]
    elseif hasEffect(sickStatusEffects) then
        local interactionIndex = rng:randomInteger(#sickInteractions) + 1
        interactionTypeIndex = sickInteractions[interactionIndex]
    elseif hasEffect(hungryStatusEffects) then
        local interactionIndex = rng:randomInteger(#hungryInteractions) + 1
        interactionTypeIndex = hungryInteractions[interactionIndex]
    elseif hasEffect(tiredStatusEffects) then
        local interactionIndex = rng:randomInteger(#tiredInteractions) + 1
        interactionTypeIndex = tiredInteractions[interactionIndex]
    else
        local happySadMood = mood:getMood(sapien, mood.types.happySad.index)
    
        if happySadMood <= mood.levels.moderateNegative then
            local interactionIndex = rng:randomInteger(#sadInteractions) + 1
            interactionTypeIndex = sadInteractions[interactionIndex]
        else
            local conversations = sapien.lazyPrivateState.conversations
            if not conversations then
                conversations = {}
                sapien.lazyPrivateState.conversations = conversations
            end

            local conversationInfo = conversations[otherSapien.uniqueID]
            if not conversationInfo then
                conversationInfo = {
                    progressionIndex = 1
                }
                conversations[otherSapien.uniqueID] = conversationInfo
            else
                if conversationInfo.finishedTime then
                    if worldTime - conversationInfo.finishedTime < 20.0 then
                        --disabled--mj:objectLog(sapien.uniqueID, "not starting interaction, time elapsed since last conversation too short:", worldTime - conversationInfo.finishedTime)
                        return nil
                    else
                        conversationInfo.finishedTime = nil
                        conversationInfo.progressionIndex = 0
                    end
                end

                conversationInfo.progressionIndex = conversationInfo.progressionIndex + 1
                if conversationInfo.progressionIndex > #interactionProgression then
                    conversationInfo.finishedTime = worldTime
                    return nil
                end
            end

            local interactionIndex = nil
            if conversationInfo.progressionIndex < 3 then
                interactionIndex = rng:randomInteger(4) + 1
            else
                interactionIndex = rng:randomInteger(#interactionProgression - 4) + 1
            end

            interactionTypeIndex = interactionProgression[interactionIndex]
            serverGOM:saveLazyPrivateStateForObjectWithID(sapien.uniqueID) 
        end
    end

    --[[elseif hasEffect(hungryStatusEffects) then
        local interactionIndex = rng:randomInteger(#hungryInteractions) + 1
        interactionTypeIndex = hungryInteractions[interactionIndex]
    elseif hasEffect(tiredStatusEffects) then
        local interactionIndex = rng:randomInteger(#tiredInteractions) + 1
        interactionTypeIndex = tiredInteractions[interactionIndex]
    else
        
    end]]

    if interactionTypeIndex then
        local socialInteractionType = social.interactions[interactionTypeIndex]

        local socialInteractionContext = {
            timeOfDayFraction = serverWorld:getTimeOfDayFraction(sapien.pos),
        }

        local interactionInfo = socialInteractionType.getInteraction(socialInteractionDistance, sapien, otherSapien, socialInteractionContext)
        if interactionInfo then
            local voiceTypeIndex = vocal.voices.dave.index
            if sapien.sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then 
                voiceTypeIndex = vocal.voices.ethan.index
            elseif sapien.sharedState.isFemale then
                voiceTypeIndex = vocal.voices.emma.index
            end
            interactionInfo.voiceTypeIndex = voiceTypeIndex
        end
        --disabled--mj:objectLog(sapien.uniqueID, "generated interactionInfo:", interactionInfo)
        return interactionInfo
    end
    return nil
end

function conversation:voiceStarted(sapien)
    table.insert(currentVoices, {
        uniqueID = sapien.uniqueID,
        pos = sapien.pos,
        time = serverWorld:getWorldTime()
    })
end

function conversation:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    serverWeather = initObjects.serverWeather
end

return conversation