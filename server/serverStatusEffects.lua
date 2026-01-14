
local rng = mjrequire "common/randomNumberGenerator"
local statistics = mjrequire "common/statistics"
local sapienConstants = mjrequire "common/sapienConstants"
local notification = mjrequire "common/notification"
local statusEffect = mjrequire "common/statusEffect"
local medicine = mjrequire "common/medicine"
local sapienTrait = mjrequire "common/sapienTrait"
local gameObject = mjrequire "common/gameObject"
local plan = mjrequire "common/plan"
local desire = mjrequire "common/desire"
local need = mjrequire "common/need"

local serverStatistics = mjrequire "server/serverStatistics"

local serverSapien = nil
local serverGOM = nil

local serverStatusEffects = {}



function serverStatusEffects:addEffect(sharedState, statusEffectTypeIndex)
    sharedState:set("statusEffects", statusEffectTypeIndex, {})
    if statusEffect.types[statusEffectTypeIndex].replaces then
        for i, replaceTypeIndex in ipairs(statusEffect.types[statusEffectTypeIndex].replaces) do
            sharedState:remove("statusEffects", replaceTypeIndex)
        end
    end
end


function serverStatusEffects:removeEffect(sharedState, statusEffectTypeIndex)
    sharedState:remove("statusEffects", statusEffectTypeIndex)
end


function serverStatusEffects:setTimedEffect(sharedState, statusEffectTypeIndex, addition)
    local shouldAdd = (addition > 0.0)
    if not shouldAdd then
        local statusEffectInfo = sharedState.statusEffects[statusEffectTypeIndex]
        if statusEffectInfo then
            shouldAdd = true
        end
    end
    if shouldAdd then
        sharedState:set("statusEffects", statusEffectTypeIndex, "timer", addition)
        if statusEffect.types[statusEffectTypeIndex].replaces then
            for i, replaceTypeIndex in ipairs(statusEffect.types[statusEffectTypeIndex].replaces) do
                sharedState:remove("statusEffects", replaceTypeIndex)
            end
        end
    end
end

function serverStatusEffects:setTimedEffectIncrementing(sharedState, statusEffectTypeIndex, incrementing)
    local statusEffectInfo = sharedState.statusEffects[statusEffectTypeIndex]
    if incrementing then
        if statusEffectInfo then
            sharedState:set("statusEffects", statusEffectTypeIndex, "incrementing", true)
        else
            sharedState:set("statusEffects", statusEffectTypeIndex, {
                incrementing = true,
                timer = 0.0,
            })
        end
    else
        if statusEffectInfo then
            sharedState:remove("statusEffects", statusEffectTypeIndex, "incrementing")
        end
    end
end

function serverStatusEffects:setTimerCompletionCallBackFunction(statusEffectTypeIndex, callbackFunc)
    statusEffect.types[statusEffectTypeIndex].completionFunction = callbackFunc
end

function serverStatusEffects:updateTimedEffects(sapien, dt)
    if dt > 0.0 then
        local sharedState = sapien.sharedState
        local statusEffects = sharedState.statusEffects
        local statusEffectTypeIndices = {}
        for statusEffectTypeIndex, statusEffectInfo in pairs(statusEffects) do --looping over these directly can fail, as statusEffects may be added to during the loop
            table.insert(statusEffectTypeIndices, statusEffectTypeIndex)
        end

        for i,statusEffectTypeIndex in ipairs(statusEffectTypeIndices) do
            local statusEffectInfo = statusEffects[statusEffectTypeIndex]
            if statusEffectInfo then
                if statusEffectInfo.timer then
                    local speedMultiplier = 1.0
                    local isTreated = false
                    local isImmune = false
                    local statusEffectType = statusEffect.types[statusEffectTypeIndex]
                    if statusEffectType.requiredMedicineTypeIndex then
                        local treatmentStatusEffect = medicine.types[statusEffectType.requiredMedicineTypeIndex].treatmentStatusEffect
                        if statusEffects[treatmentStatusEffect] ~= nil then
                            speedMultiplier = 4.0
                            isTreated = true
                        end

                        local immunityStatusEffect = medicine.types[statusEffectType.requiredMedicineTypeIndex].immunityStatusEffect
                        if statusEffects[immunityStatusEffect] ~= nil then
                            isImmune = true
                        end
                    end

                    local dtToUse = -dt
                    if statusEffectInfo.incrementing then
                        dtToUse = dt
                    end
                    local timerValue = statusEffectInfo.timer + dtToUse * speedMultiplier
                    if timerValue <= 0.0 then
                        local completionFunction = statusEffect.types[statusEffectTypeIndex].completionFunction
                        if completionFunction then
                            if serverSapien:getOwnerPlayerIsOnline(sapien) then
                                sharedState:remove("statusEffects", statusEffectTypeIndex)
                                completionFunction(sapien, isTreated, isImmune)
                            else
                                sharedState:set("statusEffects", statusEffectTypeIndex, "timer", 1.0 + rng:randomValue() * 300.0) -- effectively pause this until player returns, and spread out over first 5 minutes of play
                            end
                        else
                            sharedState:remove("statusEffects", statusEffectTypeIndex)
                        end
                    else
                        sharedState:set("statusEffects", statusEffectTypeIndex, "timer", timerValue)
                    end
                end
            end
        end
    end
end

local function getChanceOfRecoveryMultiplier(sapien)
    local multiplier = 1
    if serverSapien:isSleeping(sapien) then
        
        local sleepIsCovered = false
        local sleepOnBed = false
        local orderState = sapien.sharedState.orderQueue[1]
        if orderState and orderState.objectID then
            local orderObject = serverGOM:getObjectWithID(orderState.objectID)
            if orderObject and gameObject.types[orderObject.objectTypeIndex].bedComfort then
                sleepOnBed = true
                sleepIsCovered = orderObject.sharedState.covered
            end
        end
        if not sleepOnBed then
            sleepIsCovered = sapien.sharedState.covered
        end

        if sleepOnBed then
            multiplier = multiplier + 1
        end
        if sleepIsCovered then
            multiplier = multiplier + 1
        end

    end
    return multiplier
end

local function getChancedRecovery(sapien, chance)
    return rng:randomInteger(chance * getChanceOfRecoveryMultiplier(sapien)) == 1
end

function serverStatusEffects:init(serverGOM_, serverSapien_, planManager)
    serverSapien = serverSapien_
    serverGOM = serverGOM_

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.familyDiedShortTerm.index, function(sapien, isTreated, isImmune)
        serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.familyDiedLongTerm.index, 1000.0)
    end)

    
    --starvation
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.hungry.index, function(sapien, isTreated, isImmune)
        local foodDesire = desire:getDesire(sapien, need.types.food.index, false)
        if foodDesire >= desire.levels.strong then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.veryHungry.index, sapienConstants.hungryDurationUntilEscalation)
            serverGOM:sendNotificationForObject(sapien, notification.types.veryHungry.index, nil, sapien.sharedState.tribeID)
        else
            mj:error("hungry completion callback when sapien not hungry:", sapien.uniqueID)
        end
    end)

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.veryHungry.index, function(sapien, isTreated, isImmune)
        local foodDesire = desire:getDesire(sapien, need.types.food.index, false)
        if foodDesire >= desire.levels.strong then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.starving.index, sapienConstants.hungryDurationUntilEscalation)
            serverGOM:sendNotificationForObject(sapien, notification.types.starving.index, nil, sapien.sharedState.tribeID)
        else
            mj:error("veryHungry completion callback when sapien not hungry:", sapien.uniqueID)
        end
    end)

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.starving.index, function(sapien, isTreated, isImmune)
        local foodDesire = desire:getDesire(sapien, need.types.food.index, false)
        if foodDesire >= desire.levels.strong then
            mj:log("died of starvation:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
                deathReasonKey = "deathReason_starvation"
            }, sapien.sharedState.tribeID)
            serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
            serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
            serverSapien:removeSapien(sapien, true, true)
        else
            mj:error("starving completion callback when sapien not hungry:", sapien.uniqueID)
        end
    end)

    --hypothermia

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.veryCold.index, function(sapien, isTreated, isImmune)
        serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.hypothermia.index, sapienConstants.timeToDieFromHypothermia)
        serverGOM:sendNotificationForObject(sapien, notification.types.hypothermia.index, nil, sapien.sharedState.tribeID)
    end)
    

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.hypothermia.index, function(sapien, isTreated, isImmune)
        mj:log("died of hypothermia:", sapien.uniqueID)
        serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
            deathReasonKey = "deathReason_hypothermia"
        }, sapien.sharedState.tribeID)
        serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
        serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
        serverSapien:removeSapien(sapien, true, true)
    end)
    
        
    -- injury
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.minorInjury.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and getChancedRecovery(sapien, 4) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorInjury.index, sapienConstants.injuryDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorInjury.index, nil, sapien.sharedState.tribeID)
        else
            local medicineType = medicine.types.injury
            planManager:removePlanStateForObject(sapien, medicineType.treatmentPlanTypeIndex, nil, nil, nil)
            serverGOM:sendNotificationForObject(sapien, notification.types.minorInjuryHealed.index, nil, sapien.sharedState.tribeID)
        end
    end)
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.majorInjury.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and getChancedRecovery(sapien, 4) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.criticalInjury.index, sapienConstants.injuryDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalInjury.index, nil, sapien.sharedState.tribeID)
        else
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorInjury.index, sapienConstants.injuryDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorInjuryBecameMinor.index, nil, sapien.sharedState.tribeID)
        end
    end)

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.criticalInjury.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and getChancedRecovery(sapien, 4) then
            mj:log("died of injury:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
                deathReasonKey = "deathReason_criticalInjury"
            }, sapien.sharedState.tribeID)
            serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
            serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
            serverSapien:removeSapien(sapien, true, true)
        else
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorInjury.index, sapienConstants.injuryDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalInjuryBecameMajor.index, nil, sapien.sharedState.tribeID)
        end
    end)

    
    -- burn
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.minorBurn.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and getChancedRecovery(sapien, 4) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorBurn.index, sapienConstants.burnDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorBurn.index, nil, sapien.sharedState.tribeID)
        else
            local medicineType = medicine.types.burn
            serverStatusEffects:removeEffect(sapien.sharedState, medicineType.treatmentStatusEffect)
            planManager:removePlanStateForObject(sapien, medicineType.treatmentPlanTypeIndex, nil, nil, nil)
            serverGOM:sendNotificationForObject(sapien, notification.types.minorBurnHealed.index, nil, sapien.sharedState.tribeID)
        end
    end)
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.majorBurn.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and getChancedRecovery(sapien, 4) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.criticalBurn.index, sapienConstants.burnDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalBurn.index, nil, sapien.sharedState.tribeID)
        else
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorBurn.index, sapienConstants.burnDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorBurnBecameMinor.index, nil, sapien.sharedState.tribeID)
        end
    end)

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.criticalBurn.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and getChancedRecovery(sapien, 4) then
            mj:log("died of burn:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
                deathReasonKey = "deathReason_burn"
            }, sapien.sharedState.tribeID)
            serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
            serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
            serverSapien:removeSapien(sapien, true, true)
        else
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorBurn.index, sapienConstants.burnDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalBurnBecameMajor.index, nil, sapien.sharedState.tribeID)
        end
    end)

    -- foodPoisoning
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.minorFoodPoisoning.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and (not isImmune) and getChancedRecovery(sapien, 4) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorFoodPoisoning.index, sapienConstants.foodPoisoningDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorFoodPoisoning.index, nil, sapien.sharedState.tribeID)
        else
            local medicineType = medicine.types.foodPoisoning
            serverStatusEffects:removeEffect(sapien.sharedState, medicineType.treatmentStatusEffect)
            serverStatusEffects:setTimedEffect(sapien.sharedState, medicineType.immunityStatusEffect, sapienConstants.foodPoisoningImmunityDuration)
            planManager:removePlanStateForObject(sapien, medicineType.treatmentPlanTypeIndex, nil, nil, nil)
            serverGOM:sendNotificationForObject(sapien, notification.types.minorFoodPoisoningHealed.index, nil, sapien.sharedState.tribeID)
        end
    end)
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.majorFoodPoisoning.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and (not isImmune) and getChancedRecovery(sapien, 4) then
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.criticalFoodPoisoning.index, sapienConstants.foodPoisoningDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalFoodPoisoning.index, nil, sapien.sharedState.tribeID)
        else
            local medicineType = medicine.types.foodPoisoning
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorFoodPoisoning.index, sapienConstants.foodPoisoningDuration)
            serverStatusEffects:setTimedEffect(sapien.sharedState, medicineType.immunityStatusEffect, sapienConstants.foodPoisoningImmunityDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorFoodPoisoningBecameMinor.index, nil, sapien.sharedState.tribeID)
        end
    end)

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.criticalFoodPoisoning.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and (not isImmune) and getChancedRecovery(sapien, 4) then
            mj:log("died of food poisoning:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
                deathReasonKey = "deathReason_foodPoisoning"
            }, sapien.sharedState.tribeID)
            serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
            serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
            serverSapien:removeSapien(sapien, true, true)
        else
            local medicineType = medicine.types.foodPoisoning
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorFoodPoisoning.index, sapienConstants.foodPoisoningDuration)
            serverStatusEffects:setTimedEffect(sapien.sharedState, medicineType.immunityStatusEffect, sapienConstants.foodPoisoningImmunityDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalFoodPoisoningBecameMajor.index, nil, sapien.sharedState.tribeID)
        end
    end)


    -- virus

    local function getImmunityDuration(sapien)
        local immunityInfluence = sapienTrait:getInfluence(sapien.sharedState.traits, sapienTrait.influenceTypes.immunity.index)
        local traitMultiplier = math.pow(2.0, immunityInfluence)
        return sapienConstants.virusImmunityDuration * traitMultiplier
    end
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.incubatingVirus.index, function(sapien, isTreated, isImmune)
        serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorVirus.index, sapienConstants.virusDuration)
        serverGOM:sendNotificationForObject(sapien, notification.types.minorVirus.index, nil, sapien.sharedState.tribeID)
        planManager:addStandardPlan(sapien.sharedState.tribeID, plan.types.treatVirus.index, sapien.uniqueID, nil, nil, nil, nil, nil, nil)
    end)
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.minorVirus.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and (not isImmune) and getChancedRecovery(sapien, 2) then --note 1 in 2
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorVirus.index, sapienConstants.virusDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.majorVirus.index, nil, sapien.sharedState.tribeID)
        else
            local medicineType = medicine.types.virus
            serverStatusEffects:removeEffect(sapien.sharedState, medicineType.treatmentStatusEffect)
            serverStatusEffects:setTimedEffect(sapien.sharedState, medicineType.immunityStatusEffect, getImmunityDuration(sapien))
            planManager:removePlanStateForObject(sapien, medicineType.treatmentPlanTypeIndex, nil, nil, nil)
            serverGOM:sendNotificationForObject(sapien, notification.types.minorVirusHealed.index, nil, sapien.sharedState.tribeID)
        end
    end)
    
    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.majorVirus.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and (not isImmune) and (sapienTrait:getInfluence(sapien.sharedState.traits, sapienTrait.influenceTypes.immunity.index) < 0.5) and getChancedRecovery(sapien, 2) then --strong immunity trait prevents critical infections
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.criticalVirus.index, sapienConstants.virusDuration)
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalVirus.index, nil, sapien.sharedState.tribeID)
        else
            local medicineType = medicine.types.virus
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.minorVirus.index, sapienConstants.virusDuration)
            serverStatusEffects:setTimedEffect(sapien.sharedState, medicineType.immunityStatusEffect, getImmunityDuration(sapien))
            serverGOM:sendNotificationForObject(sapien, notification.types.majorVirusBecameMinor.index, nil, sapien.sharedState.tribeID)
        end
    end)

    serverStatusEffects:setTimerCompletionCallBackFunction(statusEffect.types.criticalVirus.index, function(sapien, isTreated, isImmune)
        if (not isTreated) and (not isImmune) and getChancedRecovery(sapien, 4) then
            mj:log("died of virus:", sapien.uniqueID)
            serverGOM:sendNotificationForObject(sapien, notification.types.died.index, {
                deathReasonKey = "deathReason_virus"
            }, sapien.sharedState.tribeID)
            serverSapien:updateStatusForFriendsOfDyingSapien(sapien)
            serverStatistics:recordEvent(sapien.sharedState.tribeID, statistics.types.death.index)
            serverSapien:removeSapien(sapien, true, true)
        else
            local medicineType = medicine.types.virus
            serverStatusEffects:setTimedEffect(sapien.sharedState, statusEffect.types.majorVirus.index, sapienConstants.virusDuration)
            serverStatusEffects:setTimedEffect(sapien.sharedState, medicineType.immunityStatusEffect, getImmunityDuration(sapien))
            serverGOM:sendNotificationForObject(sapien, notification.types.criticalVirusBecameMajor.index, nil, sapien.sharedState.tribeID)
        end
    end)
    
end

return serverStatusEffects