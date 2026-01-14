
local skill = mjrequire "common/skill"
local sapienTrait = mjrequire "common/sapienTrait"
local order = mjrequire "common/order"

local skillLearning = {}

--NOTE this whole module turned out to be a bad approach, still used for some actions but will be removed eventually


function skillLearning:load(gameObject)
    local infosByOrderTypeIndexByObjectTypeIndex = {
        [order.types.deliverFuel.index] = {
            [gameObject.types.campfire.index] = {
                skillTypeIndex = skill.types.fireLighting.index,
                baseIncrease = 2.0,
            },
            [gameObject.types.brickKiln.index] = {
                skillTypeIndex = skill.types.fireLighting.index,
                baseIncrease = 2.0,
            },
            [gameObject.types.torch.index] = {
                skillTypeIndex = skill.types.fireLighting.index,
                baseIncrease = 2.0,
            }
        },

        [order.types.light.index] = {
            [gameObject.types.campfire.index] = {
                skillTypeIndex = skill.types.fireLighting.index,
                baseIncrease = 10.0,
            },
            [gameObject.types.brickKiln.index] = {
                skillTypeIndex = skill.types.fireLighting.index,
                baseIncrease = 10.0,
            },
            [gameObject.types.torch.index] = {
                skillTypeIndex = skill.types.fireLighting.index,
                baseIncrease = 10.0,
            },
        },
    }

    local infosByOrderTypeIndexWithAnyObject = {
        [order.types.dig.index] = {
            skillTypeIndex = skill.types.digging.index,
            baseIncrease = 10.0,
        },
        [order.types.mine.index] = {
            skillTypeIndex = skill.types.mining.index,
            baseIncrease = 10.0,
        },
        [order.types.recruit.index] = {
            skillTypeIndex = skill.types.diplomacy.index,
            baseIncreaseFraction = 0.2, --note baseIncreaseFraction, this happens per action
        },
        [order.types.banish.index] = {
            skillTypeIndex = skill.types.diplomacy.index,
            baseIncreaseFraction = 0.2,
        },
        [order.types.fight.index] = {
            skillTypeIndex = skill.types.handToHandCombat.index,
            baseIncreaseFraction = 0.05,
        },
        [order.types.chop.index] = {
            skillTypeIndex = skill.types.treeFelling.index,
            baseIncrease = 10.0,
        },
        [order.types.butcher.index] = {
            skillTypeIndex = skill.types.butchery.index,
            baseIncrease = 10.0,
        },
        [order.types.playInstrument.index] = {
            skillTypeIndex = skill.types.flutePlaying.index,
            baseIncrease = 10.0,
        },
        [order.types.fertilize.index] = {
            skillTypeIndex = skill.types.mulching.index,
            baseIncrease = 10.0,
        },
        [order.types.chiselStone.index] = {
            skillTypeIndex = skill.types.chiselStone.index,
            baseIncrease = 10.0,
        },
    }

    skillLearning.infosByOrderTypeIndexByObjectTypeIndex = infosByOrderTypeIndexByObjectTypeIndex
    skillLearning.infosByOrderTypeIndexWithAnyObject = infosByOrderTypeIndexWithAnyObject
end

function skillLearning:addVariant(baseObjectTypeIndex, variantObjectTypeIndex)
    for orderTypeIndex,learningInfo in pairs(skillLearning.infosByOrderTypeIndexByObjectTypeIndex) do
        if learningInfo[baseObjectTypeIndex] then
            learningInfo[variantObjectTypeIndex] = mj:cloneTable(learningInfo[baseObjectTypeIndex])
        end
    end
end

function skillLearning:getTaughtSkillInfo(orderTypeIndex, objectTypeIndex)
    --mj:log("skillLearning:getTaughtSkillInfo orderTypeIndex:", orderTypeIndex, " objectTypeIndex:", objectTypeIndex)
    local infosByObjectTypeIndex = skillLearning.infosByOrderTypeIndexByObjectTypeIndex[orderTypeIndex]
    if infosByObjectTypeIndex then
        --mj:log("infosByObjectTypeIndex[objectTypeIndex]:", infosByObjectTypeIndex[objectTypeIndex])
        return infosByObjectTypeIndex[objectTypeIndex]
    end

    local infoForAnyObject = skillLearning.infosByOrderTypeIndexWithAnyObject[orderTypeIndex]
    if infoForAnyObject then
        --mj:log("infoForAnyObject:", infoForAnyObject)
        return infoForAnyObject
    end

    --mj:log("returning nil from skillLearning:getTaughtSkillInfo orderTypeIndex:", orderTypeIndex, " objectTypeIndex:", objectTypeIndex)
    return nil
end

                
function skillLearning:getGeneralSkillSpeedMultiplier(sapien, sharedState, skillTypeIndex)
    local skillSpeedMultiplierPower = sapienTrait:getSkillInfluence(sharedState.traits, skillTypeIndex)
    return math.pow(2.0, skillSpeedMultiplierPower * 0.5)
end

return skillLearning