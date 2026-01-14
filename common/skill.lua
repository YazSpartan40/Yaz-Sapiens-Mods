
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"
local sapienConstants = mjrequire "common/sapienConstants"

local skill = {
    types = {},
    validTypes = {}
}

skill.timeToCompleteSkills = 400.0
skill.maxRoles = 6

skill.defaultSkills = {}


local typeIndexMap = typeMaps.types.skill

local function addSkill(key, info)
	local index = typeIndexMap[key]
	if not index then
		mj:log("ERROR: attempt to add skill type that isn't in typeIndexMap:", key)
	else
		if skill.types[key] then
			mj:log("WARNING: overwriting skill type:", key)
		end

		info.key = key
		info.index = index
		skill.types[key] = info
        skill.types[index] = info

        if info.startLearned then
            skill.defaultSkills[index] = true
        end
	end
	return index
end

addSkill("gathering",{
    name = locale:get("skill_gathering"),
    description = locale:get("skill_gathering_description"),
    icon = "icon_clear",
    startLearned = true,
})

addSkill("diplomacy",{
    name = locale:get("skill_diplomacy"),
    description = locale:get("skill_diplomacy_description"),
    icon = "icon_tribe2",
})

addSkill("handToHandCombat",{
    name = locale:get("skill_handToHandCombat"),
    description = locale:get("skill_handToHandCombat_description"),
    icon = "icon_fist",
    noCapacityWithLimitedGeneralAbility = true,
})


addSkill("basicBuilding",{
    name = locale:get("skill_basicBuilding"),
    description = locale:get("skill_basicBuilding_description"),
    icon = "icon_hammer",
    startLearned = true,
})

addSkill("researching",{
    name = locale:get("skill_basicResearch"),
    description = locale:get("skill_basicResearch_description"),
    icon = "icon_idea",
    startLearned = true,
    partialCapacityWithLimitedGeneralAbility = true,
})

addSkill("fireLighting",{
    name = locale:get("skill_fireLighting"),
    description = locale:get("skill_fireLighting_description"),
    icon = "icon_fire",
    learnSpeed = 2.0,
})

addSkill("rockKnapping",{
    name = locale:get("skill_knapping"),
    description = locale:get("skill_knapping_description"),
    icon = "icon_rockKnapping",
    learnSpeed = 2.0,
})

addSkill("flintKnapping",{
    name = locale:get("skill_flintKnapping"),
    description = locale:get("skill_flintKnapping_description"),
    icon = "icon_flintKnapping",
})


addSkill("boneCarving",{
    name = locale:get("skill_boneCarving"),
    description = locale:get("skill_boneCarving_description"),
    icon = "icon_boneCarving",
})

addSkill("pottery",{
    name = locale:get("skill_pottery"),
    description = locale:get("skill_pottery_description"),
    icon = "icon_pottery",
})

addSkill("potteryFiring",{
    name = locale:get("skill_potteryFiring"),
    description = locale:get("skill_potteryFiring_description"),
    icon = "icon_firedPottery",
})

addSkill("spinning",{
    name = locale:get("skill_spinning"),
    description = locale:get("skill_spinning_description"),
    icon = "icon_spinning",
})


addSkill("flutePlaying",{
    name = locale:get("skill_flutePlaying"),
    description = locale:get("skill_flutePlaying_description"),
    icon = "icon_music",
})

addSkill("thatchBuilding",{
    name = locale:get("skill_thatchBuilding"),
    description = locale:get("skill_thatchBuilding_description"),
    icon = "icon_thatchBuilding",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("woodBuilding",{
    name = locale:get("skill_woodBuilding"),
    description = locale:get("skill_woodBuilding_description"),
    icon = "icon_woodBuilding",
    noCapacityWithLimitedGeneralAbility = true,
})


addSkill("mudBrickBuilding",{
    name = locale:get("skill_mudBrickBuilding"),
    description = locale:get("skill_mudBrickBuilding_description"),
    icon = "icon_mudBrickBuilding",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("basicHunting",{ --basicHunting is now rockThrowing, key kept for compatibility
    name = locale:get("skill_basicHunting"),
    description = locale:get("skill_basicHunting_description"),
    icon = "icon_basicHunting",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("spearHunting",{ --spearHunting is now spearing, key kept for compatibility
    name = locale:get("skill_spearHunting"),
    description = locale:get("skill_spearHunting_description"),
    icon = "icon_spear",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("butchery",{
    name = locale:get("skill_butchery"),
    description = locale:get("skill_butchery_description"),
    icon = "icon_food",
})

addSkill("campfireCooking",{
    name = locale:get("skill_campfireCooking"),
    description = locale:get("skill_campfireCooking_description"),
    icon = "icon_basicCooking",
})

addSkill("treeFelling",{
    name = locale:get("skill_treeFelling"),
    description = locale:get("skill_treeFelling_description"),
    icon = "icon_axe",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("woodWorking",{
    name = locale:get("skill_woodWorking"),
    description = locale:get("skill_woodWorking_description"),
    icon = "icon_woodWorking",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("toolAssembly",{
    name = locale:get("skill_toolAssembly"),
    description = locale:get("skill_toolAssembly_description"),
    icon = "icon_toolAssembly",
})

addSkill("digging",{
    name = locale:get("skill_digging"),
    description = locale:get("skill_digging_description"),
    icon = "icon_dig",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("mining",{
    name = locale:get("skill_mining"),
    description = locale:get("skill_mining_description"),
    icon = "icon_mine",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("chiselStone",{
    name = locale:get("skill_chiselStone"),
    description = locale:get("skill_chiselStone_description"),
    icon = "icon_chisel",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("planting",{
    name = locale:get("skill_planting"),
    description = locale:get("skill_planting_description"),
    icon = "icon_plant",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("mulching",{
    name = locale:get("skill_mulching"),
    description = locale:get("skill_mulching_description"),
    icon = "icon_mulch",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("threshing",{
    name = locale:get("skill_threshing"),
    description = locale:get("skill_threshing_description"),
    icon = "icon_threshing",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("grinding",{
    name = locale:get("skill_grinding"),
    description = locale:get("skill_grinding_description"),
    icon = "icon_grinding",
})

addSkill("baking",{
    name = locale:get("skill_baking"),
    description = locale:get("skill_baking_description"),
    icon = "icon_bread",
})


addSkill("brickBuilding",{ --deprecated 0.4
    name = locale:get("skill_brickBuilding"),
    description = locale:get("skill_brickBuilding_description"),
    icon = "icon_brickBuilding",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("tiling",{
    name = locale:get("skill_tiling"),
    description = locale:get("skill_tiling_description"),
    icon = "icon_tiling",
    noCapacityWithLimitedGeneralAbility = true,
})

addSkill("medicine",{
    name = locale:get("skill_medicine"),
    description = locale:get("skill_medicine_description"),
    icon = "icon_injury",
})


addSkill("blacksmithing",{
    name = locale:get("skill_blacksmithing"),
    description = locale:get("skill_blacksmithing_description"),
    icon = "icon_craft",
})



function skill:titleForSkill(skillTypeIndex)
    return skill.types[skillTypeIndex].name
end

function skill:hasSkill(sapien, skillTypeIndex)
    local sharedState = sapien.sharedState
    if sharedState.skillState then
        if sharedState.skillState[skillTypeIndex] and sharedState.skillState[skillTypeIndex].complete then
            return true
        end
    end
    return false
end

function skill:learnStarted(sapien, skillTypeIndex)
    local sharedState = sapien.sharedState
    if sharedState.skillState then
        if sharedState.skillState[skillTypeIndex] and (sharedState.skillState[skillTypeIndex].complete or sharedState.skillState[skillTypeIndex].fractionComplete > 0.0001) then
            return true
        end
    end
    return false
end

function skill:fractionLearned(sapien, skillTypeIndex)
    local sharedState = sapien.sharedState
    if sharedState.skillState then
        if sharedState.skillState[skillTypeIndex] then
            if sharedState.skillState[skillTypeIndex].complete then
                return 1.0
            else
                return sharedState.skillState[skillTypeIndex].fractionComplete or 0.0
            end
        end
    end
    return 0.0
end

function skill:getSkilledHeuristic(sapien)
    local heuristic = 0
    local sharedState = sapien.sharedState
    if sharedState.skillState then
        for skillTypeIndex, info in pairs(sharedState.skillState) do
            if info.complete then
                heuristic = heuristic + 100
            else
                heuristic = heuristic + info.fractionComplete
            end
        end
    end
    return heuristic
end

function skill:getSkilledCount(sapien)
    local skillCount = 0
    local sharedState = sapien.sharedState
    if sharedState.skillState then
        for skillTypeIndex, info in pairs(sharedState.skillState) do
            if info.complete then
                skillCount = skillCount + 1
            end
        end
    end
    return skillCount
end


function skill:priorityLevel(sapien, skillTypeIndex)
    local sharedState = sapien.sharedState
    return (sharedState.skillPriorities[skillTypeIndex] or 0)
end

function skill:getAssignedRolesCount(sapien)
    local count = 0
    for i, skillType in ipairs(skill.validTypes) do
        local priorityLevel = skill:priorityLevel(sapien, skillType.index)
        if priorityLevel == 1 then
            count = count + 1
        end
    end
    return count
end

function skill:isAllowedToDoTasks(sapien, requiredSkillTypeIndex)
    if requiredSkillTypeIndex then
        if skill:priorityLevel(sapien, requiredSkillTypeIndex) == 0 then
            return false
        end
        
        if skill.types[requiredSkillTypeIndex].noCapacityWithLimitedGeneralAbility then
            if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, skill.types[requiredSkillTypeIndex].noCapacityWithLimitedGeneralAbilityIncludesElders) then
                return false
            end
        end
    end
    return true
end

function skill:getLimitedAbilityReason(sharedState, partiallyAllowed)
    local reason = {}
    if sharedState.pregnant then
        reason.pregnant = true
    elseif sharedState.hasBaby then
        reason.hasBaby = true
    elseif sharedState.lifeStageIndex == sapienConstants.lifeStages.child.index then
        reason.child = true
    elseif sharedState.lifeStageIndex == sapienConstants.lifeStages.elder.index then
        reason.elder = true
    end
    if partiallyAllowed then
        return locale:get("ui_partiallyCantDoTasks", reason)
    end
    return locale:get("ui_cantDoTasks", reason)
end


local function finalize()
    skill.validTypes = typeMaps:createValidTypesArray("skill", skill.types)
end

finalize()

return skill