
local mjm = mjrequire "common/mjm"
local length2 = mjm.length2
--local normalize = mjm.normalize
--local dot = mjm.dot
--local vec3 = mjm.vec3
--local length = mjm.length
--local mat3LookAtInverse = mjm.mat3LookAtInverse

--local action = mjrequire "common/action"
--local actionSequence = mjrequire "common/actionSequence"
local gameObject = mjrequire "common/gameObject"
local desire = mjrequire "common/desire"
local mood = mjrequire "common/mood"
local order = mjrequire "common/order"
local sapienInventory = mjrequire "common/sapienInventory"
local notification = mjrequire "common/notification"
local lookAtIntents = mjrequire "common/lookAtIntents"
local rng = mjrequire "common/randomNumberGenerator"

local conversation = mjrequire "server/sapienAI/conversation"
local lookAI = mjrequire "server/sapienAI/lookAI"
--local serverTutorialState = mjrequire "server/serverTutorialState"
--local serverTribe  = mjrequire "server/serverTribe"


local findOrderAI = nil
local serverSapien = nil
local serverSapienAI = nil
local serverGOM = nil
local serverWorld = nil

local multitask = {}

local timeBetweenChecks = 5.0


local function removeMultitaskState(sapien)
    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    aiState.multitaskCheckTimer = nil
    sapien.sharedState:remove("multitaskState")
end

local maxVirusSpreadDistance2 = mj:mToP(5.0) * mj:mToP(5.0)

function multitask:update(sapien, dt, speedMultiplier)

    --disabled--mj:objectLog(sapien.uniqueID, "multitask:update")

    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    local cooldowns = mj:getOrCreate(aiState, "cooldowns")
    local sharedState = sapien.sharedState

    local function addMultitask(orderMultitaskTypeIndex, objectID, context)

        local multitaskState = {
            orderMultitaskTypeIndex = orderMultitaskTypeIndex,
            objectID = objectID,
            timer = 0.0,
            context = context,
        }
        
        sharedState:set("multitaskState", multitaskState)
    end

    local function startSocial(otherSapien)
        
        if sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) > 0 then
            --disabled--mj:objectLog(sapien.uniqueID, "multitask:update startSocial failed, sapienInventory:objectCount")
            return false
        end
        local cooldownKey = "social_" .. otherSapien.uniqueID
        if cooldowns[cooldownKey] then
            --disabled--mj:objectLog(sapien.uniqueID, "multitask:update startSocial failed, cooldowns[cooldownKey]")
            --mj:log("cooldown fail:", sapien.uniqueID)
            return false
        end


        local socialInteractionInfo = conversation:getNextInteractionInfo(sapien, otherSapien)

       -- mj:log("start social multitask:", socialInteractionInfo)
        if socialInteractionInfo then
            local context = {
                socialInteractionInfo = socialInteractionInfo,
            }
            addMultitask(order.multitaskTypes.social.index, otherSapien.uniqueID, context)

            serverGOM:sendNotificationForObject(sapien, notification.types.social.index, socialInteractionInfo, sapien.sharedState.tribeID)
            conversation:voiceStarted(sapien)

            local otherSapienAIState = serverSapienAI.aiStates[otherSapien.uniqueID]
            otherSapienAIState.socialTimer = 0.0

            serverSapien:addToBondAndMood(sapien, otherSapien.uniqueID, 0.2, 0.2)

            
            if socialInteractionInfo.spreadsVirus then
                if length2(sapien.pos - otherSapien.pos) < maxVirusSpreadDistance2 then
                    serverSapien:spreadVirus(sapien, otherSapien)
                end
            end

            serverSapien:saveState(sapien)
            return true
        end
        

        cooldowns[cooldownKey] = lookAI.socialCooldown

        --disabled--mj:objectLog(sapien.uniqueID, "multitask:update startSocial addMultitask")

       -- local sapienNormal = normalize(sapien.pos)
       -- local rotation = mat3LookAtInverse(normalize(normalize(otherSapien.pos) - sapienNormal), sapienNormal)
        --[[addMultitask(order.multitaskTypes.social.index, otherSapien.uniqueID)
            --sapien.rotation = rotation
        serverSapien:addToBondAndMood(sapien, otherSapien.uniqueID, 0.2, 0.2)

        serverSapien:saveState(sapien)
        return true]]
    end

    --local sharedState = sapien.sharedState

    if sharedState.multitaskState then
        local actionCompleted = false
        local multitaskState = sharedState.multitaskState
        local currentOrderMultitaskTypeIndex = sharedState.multitaskState.orderMultitaskTypeIndex
        if currentOrderMultitaskTypeIndex == order.multitaskTypes.social.index then
            local newTimer = multitaskState.timer + dt * speedMultiplier

            if newTimer > 1.5 then
                actionCompleted = true
            else
                sharedState:set("multitaskState", "timer", newTimer)
            end
        end

        if actionCompleted then
            --disabled--mj:objectLog(sapien.uniqueID, "multitask:update actionCompleted")
            removeMultitaskState(sapien)
        end
    else

        local checkTimer = aiState.multitaskCheckTimer

        if not checkTimer or checkTimer < 0.0 then
            aiState.multitaskCheckTimer = timeBetweenChecks * 0.5 + rng:randomValue() * timeBetweenChecks

            local bestObjectInfo = findOrderAI:findMultitask(sapien)

            if bestObjectInfo then
                aiState.currentLookAtObjectInfo = bestObjectInfo
                local newLookAtID = bestObjectInfo.uniqueID
                
                cooldowns["look_" .. newLookAtID] = lookAI.lookAwayCooldown

                local lookAtPos = gameObject:getSapienLookAtPointForObject(bestObjectInfo.object)
                
                --disabled--mj:objectLog(sapien.uniqueID, "multitask:update setting look at")
                serverSapien:setLookAt(sapien, bestObjectInfo.uniqueID, lookAtPos)

                if aiState.socialTimer < serverSapienAI.socialLength then
                    local sleepDesire = desire:getSleep(sapien, serverWorld:getTimeOfDayFraction(sapien.pos))
                    local happySadMood = mood:getMood(sapien, mood.types.happySad.index)

                    if bestObjectInfo.lookAtIntent == lookAtIntents.types.social.index then
                        --disabled--mj:objectLog(sapien.uniqueID, "multitask:update bestObjectInfo.lookAtIntent == lookAtIntents.types.social.index")
                        if sleepDesire < desire.levels.strong and happySadMood >= mood.levels.moderateNegative then
                            --local otherObjectAIState = serverSapienAI.aiStates[aiState.currentLookAtObjectInfo.uniqueID]
                            ----disabled--mj:objectLog(sapien.uniqueID, "multitask:update otherObjectAIState:", otherObjectAIState)
                            --if otherObjectAIState and otherObjectAIState.currentLookAtObjectInfo and otherObjectAIState.currentLookAtObjectInfo.uniqueID == sapien.uniqueID then
                                local otherSapien = serverGOM:getObjectWithID(aiState.currentLookAtObjectInfo.uniqueID)
                                if otherSapien and (not serverSapien:isSleeping(otherSapien)) then
                                    --disabled--mj:objectLog(sapien.uniqueID, "multitask:update startSocial()")
                                    if startSocial(otherSapien) then
                                        return true
                                    end
                                end
                            --end
                        end
                    end
                end
            else
                serverSapien:removeLookAt(sapien) --todo could instead look at the current task, contexturally
            end
        else
            aiState.multitaskCheckTimer = aiState.multitaskCheckTimer - dt * speedMultiplier
        end
    end
end

function multitask:orderEnded(sapien)
    removeMultitaskState(sapien)
            
    local aiState = serverSapienAI.aiStates[sapien.uniqueID]
    aiState.currentLookAtObjectInfo = nil
end


function multitask:init(initObjects)
    serverGOM = initObjects.serverGOM
    serverWorld = initObjects.serverWorld
    findOrderAI = initObjects.findOrderAI
    serverSapien = initObjects.serverSapien
    serverSapienAI = initObjects.serverSapienAI
end

return multitask