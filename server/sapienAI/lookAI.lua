
--local constructable = mjrequire "common/constructable"
local skill = mjrequire "common/skill"
--local plan = mjrequire "common/plan"
--local desire = mjrequire "common/desire"
--local mood = mjrequire "common/mood"
local maintenance = mjrequire "common/maintenance"
local sapienConstants = mjrequire "common/sapienConstants"
local weather = mjrequire "common/weather"
local statusEffect = mjrequire "common/statusEffect"

--local planManager = mjrequire "server/planManager"
local serverWeather = mjrequire "server/serverWeather"

local serverSapien = nil
local serverGOM = nil
local serverWorld = nil

local lookAI = {}

lookAI.minHeuristic = -20.0


lookAI.randomTurnCooldown = 10.0
lookAI.lookAwayCooldown = 10.0
lookAI.planCooldown = 10.0
lookAI.socialCooldown = 3.0

function lookAI:getSkillOffsetForPlanObject(sapien, maintenanceTypeIndexOrNil, planStateOrNil, allowUnassigned)
    
    local minHeuristic = lookAI.minHeuristic

    local function offsetForSkill(requiredSkillTypeIndex, additionalMultiplierOrNil)
        if skill.types[requiredSkillTypeIndex].noCapacityWithLimitedGeneralAbility then
            if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState, skill.types[requiredSkillTypeIndex].noCapacityWithLimitedGeneralAbilityIncludesElders) then
                --disabled--mj:objectLog(sapien.uniqueID, "limited ability, returning minHeuristic")
                return minHeuristic - 1.0
            end
        end

        local priorityLevel = skill:priorityLevel(sapien, requiredSkillTypeIndex)
        local additionalMultiplier = additionalMultiplierOrNil or 1.0
        if priorityLevel > 0 then
            if priorityLevel == 1 then
                return 50.0 * additionalMultiplier
            elseif priorityLevel == 2 then
                return 10.0 * additionalMultiplier
            end
        end
        if allowUnassigned then

            if serverWorld:getAutoRoleAssignmentIsAllowedForRole(sapien.sharedState.tribeID, requiredSkillTypeIndex, sapien) then
                local wellRestedStatusEffect = sapien.sharedState.statusEffects[statusEffect.types.wellRested.index]
                if (wellRestedStatusEffect and wellRestedStatusEffect.incrementing and wellRestedStatusEffect.timer > 10.0) then
                    return 0.0
                end
            end
        end
        --disabled--mj:objectLog(sapien.uniqueID, "not allowUnassigned, returning minHeuristic")
        return minHeuristic - 1.0
    end
    
    local function offsetForRequiredPlanStateSkills(planState)

        local requiredSkill = planState.requiredSkill
        if requiredSkill then
            local skillOffset = offsetForSkill(requiredSkill, nil)
            if skillOffset < minHeuristic then
                local optionalFallbackSkill = planState.optionalFallbackSkill
                if optionalFallbackSkill then
                    skillOffset = offsetForSkill(optionalFallbackSkill, 0.1)
                end
            end
            return skillOffset
        end

        return nil
    end

    --mj:log("getSkillOffsetForPlanObject:", planObjectID, " sapien:", sapien.uniqueID)

    local bestOffset = minHeuristic - 1.0
    local requiresSkill = false

    if maintenanceTypeIndexOrNil then
        if maintenance.types[maintenanceTypeIndexOrNil].skills then
            local requiredSkillTypeIndex = maintenance.types[maintenanceTypeIndexOrNil].skills.required
            if requiredSkillTypeIndex then
                requiresSkill = true
                local maintenanceSkill = offsetForSkill(requiredSkillTypeIndex)
                if maintenanceSkill > bestOffset then
                    bestOffset = maintenanceSkill
                end
            end
        end
    elseif planStateOrNil then
        local planState = planStateOrNil

        local thisOffset = offsetForRequiredPlanStateSkills(planState)
        --disabled--mj:objectLog(sapien.uniqueID, "thisOffset:", thisOffset)
        if thisOffset then
            requiresSkill = true
        else
            thisOffset = 0.0
        end

        if thisOffset > bestOffset then
            bestOffset = thisOffset
        end
    end

    if requiresSkill then
        --disabled--mj:objectLog(sapien.uniqueID, "requiresSkill or prioritizesSkill, look heuristic skillOffset:", bestOffset, " requiresSkill:", requiresSkill, " maintenanceTypeIndexOrNil:", maintenanceTypeIndexOrNil, " planStateOrNil:", planStateOrNil)
       -- mj:log("requiresSkill, returning ", bestOffset - 30.0)
        return bestOffset
    end
    --mj:log("returning zero")
    return 0.0
end


function lookAI:checkIsTooColdAndBusyWarmingUp(sapien)
    local sharedState = sapien.sharedState
    if statusEffect:hasEffect(sharedState, statusEffect.types.veryCold.index) then
        --disabled--mj:objectLog(sapien.uniqueID, "very cold")
        if sharedState.temperatureZoneIndex == weather.temperatureZones.veryCold.index then
            --disabled--mj:objectLog(sapien.uniqueID, "also in very cold area ")
            serverSapien:doUpdateTemperature(sapien)
        end
        if sharedState.temperatureZoneIndex > weather.temperatureZones.veryCold.index then
            local unsavedState = serverGOM:getUnsavedPrivateState(sapien)
            local isWetOrStormy = (sapien.sharedState.statusEffects[statusEffect.types.wet.index] ~= nil) or serverWeather:getIsDamagingWindStormOccuring()
            local ambientTemperatureZoneIndex = weather:getTemperatureZoneIndex(unsavedState.temperatureZones, serverWorld:getWorldTime(), serverWorld:getTimeOfDayFraction(sapien.pos), serverWorld.yearSpeed, sapien.pos, false, isWetOrStormy, 0)
        
            if ambientTemperatureZoneIndex <= weather.temperatureZones.veryCold.index then
                --disabled--mj:objectLog(sapien.uniqueID, "not in cold area, and it's cold outside")
                return true
            else
                --disabled--mj:objectLog(sapien.uniqueID, "not in cold area, but it's the same outside")
            end
        end
    end
    return false
end

function lookAI:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    serverSapien = initObjects.serverSapien
end


return lookAI