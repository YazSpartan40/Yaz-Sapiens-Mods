
local terrain = mjrequire "server/serverTerrain"
local plan = mjrequire "common/plan"

local planLightProbes = {}

local serverWorld = nil
local serverGOM = nil
local planManager = nil

local probes = {}
local probeFaceIDsByObjectID = {}

planLightProbes.darkDotProductThreshold = -0.1


local function updateDarkStatusForPlans(object, isDark)
    local planStatesByTribeID = object.sharedState.planStates
    if planStatesByTribeID then
        for tribeID,planStates in pairs(planStatesByTribeID) do
            for i,thisPlanState in ipairs(planStates) do
                if isDark then
                    if (not thisPlanState.tooDark) and (plan.types[thisPlanState.planTypeIndex].requiresLight) then
                        object.sharedState:set("planStates", tribeID, i, "tooDark", true)
                        planManager:updateCanCompleteAndSave(object, object.sharedState, thisPlanState, tribeID, i, false)
                    end
                else
                    if thisPlanState.tooDark then
                        object.sharedState:remove("planStates", tribeID, i, "tooDark")
                        planManager:updateCanCompleteAndSave(object, object.sharedState, thisPlanState, tribeID, i, false)
                    end
                end
            end
        end
    end
end


function planLightProbes:updateDarkStatus(object)
    local probeFaceID = probeFaceIDsByObjectID[object.uniqueID]
    if probeFaceID then
        local probe = probes[probeFaceID]
        updateDarkStatusForPlans(object, probe.dark and (not serverGOM:getIsCloseToLightSource(object.pos)))
    end
end

function planLightProbes:update(dt)
    -- loop over light probes,
    for faceID,probe in pairs(probes) do
        local sunDot = serverWorld:getSunDot(probe.center)
        local newDark = sunDot < planLightProbes.darkDotProductThreshold
        if newDark ~= probe.dark then
            probe.dark = newDark

            for objectID, object in pairs(probe.objects) do
                updateDarkStatusForPlans(object, newDark and (not serverGOM:getIsCloseToLightSource(object.pos)))
            end
        end
    end
end

function planLightProbes:getIsDarkIgnoringLights(pos)
    local sunDot = serverWorld:getSunDot(pos)
    return sunDot < planLightProbes.darkDotProductThreshold
end

function planLightProbes:getIsDarkForPos(pos)
    local sunDot = serverWorld:getSunDot(pos)
    local newDark = sunDot < planLightProbes.darkDotProductThreshold
    return newDark and (not serverGOM:getIsCloseToLightSource(pos))
end

function planLightProbes:addPlanObject(object)
    local faceID = terrain:getFaceIDForNormalizedPointAtLevel(object.normalizedPos, mj.SUBDIVISIONS - 5)
    local probe = probes[faceID]
    if not probe then
        local center = terrain:getNormalizedCenterForFaceID(faceID)
        local sunDot = serverWorld:getSunDot(center)
        local newDark = sunDot < planLightProbes.darkDotProductThreshold
        probe = {
            center = center,
            dark = newDark,
            objects = {}
        }
        probes[faceID] = probe
    end

    probeFaceIDsByObjectID[object.uniqueID] = faceID
    probe.objects[object.uniqueID] = object
    serverGOM:addObjectToSet(object, serverGOM.objectSets.lightObservers)
    updateDarkStatusForPlans(object, probe.dark and (not serverGOM:getIsCloseToLightSource(object.pos)))
end


function planLightProbes:removePlanObject(object)
    local probeFaceID = probeFaceIDsByObjectID[object.uniqueID]
    if probeFaceID then
        probes[probeFaceID].objects[object.uniqueID] = nil
        probeFaceIDsByObjectID[object.uniqueID] = nil
        serverGOM:removeObjectFromSet(object, serverGOM.objectSets.lightObservers)
    end
end

function planLightProbes:init(planManager_, serverGOM_, serverWorld_)
    planManager = planManager_
    serverWorld = serverWorld_
    serverGOM = serverGOM_
end

return planLightProbes