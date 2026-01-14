
local terrainTypesModule = mjrequire "common/terrainTypes"
local gameObject = mjrequire "common/gameObject"
local worldHelper = mjrequire "common/worldHelper"
local rng = mjrequire "common/randomNumberGenerator"

local serverEvolvingTerrain = {}

local serverGOM = nil
local serverWorld = nil
local serverTerrain = nil
--local planManager = nil

local function callCallback(object, removalTypeIndex)

    local sharedState = object.sharedState

    local function shouldRemoveModification()
        if removalTypeIndex == terrainTypesModule.modifications.snowRemoved.index or removalTypeIndex == terrainTypesModule.modifications.vegetationRemoved.index then
            if serverTerrain:hasModificationForVertex(sharedState.vertID, terrainTypesModule.modifications.preventGrassAndSnow.index) then
                return false
            end
        end
        return true
    end

    if shouldRemoveModification() then
        serverTerrain:removeModificationForVertex(sharedState.vertID, removalTypeIndex)
    end
    sharedState:remove("removalCallbackTimes", removalTypeIndex)
    serverGOM:saveObject(object.uniqueID)
end

local function addCallback(object, callbackWorldTime, removalTypeIndex)
    --mj:log("serverEvolvingTerrain addCallback:", object.uniqueID)
    serverGOM:addObjectCallbackTimerForWorldTime(object.uniqueID, callbackWorldTime, function(loadedObjectID)
        --mj:log("serverEvolvingTerrain timer fired:", loadedObject.uniqueID)
        local object_ = serverGOM:getObjectWithID(loadedObjectID)
        if object_ then
            callCallback(object_, removalTypeIndex)
        end
    end)
end

function serverEvolvingTerrain:addCallbacksForRemoval(vertID, removalTypeIndex)
    if not serverTerrain:hasModificationForVertex(vertID, terrainTypesModule.modifications.preventGrassAndSnow.index) then
        local vert = serverTerrain:getVertWithID(vertID)
        if vert then
            local objectID = serverGOM:getOrCreateObjectIDForTerrainModificationForVertex(vert)
            
            local object = serverGOM:getObjectWithID(objectID)
            if not object then
                mj:error("serverEvolvingTerrain addCallbacks couldn't load object for terrain modification")
                return
            end

            local sharedState = object.sharedState

            if (not sharedState.removalCallbackTimes) or (not sharedState.removalCallbackTimes[removalTypeIndex]) then

                local restoreSeason = terrainTypesModule.modifications[removalTypeIndex].restoreSeason
                local callbackOffset = 0
                if restoreSeason then
                    local currentSeasonIndex = worldHelper:seasonIndexForSeasonFraction(object.pos.y, serverWorld:getSeasonFraction() - 0.1 * rng:valueForUniqueID(object.uniqueID, 22345), object.uniqueID)
                    callbackOffset = serverWorld:getTimeUntilNextSeasonOfType(restoreSeason, currentSeasonIndex, 0.01 + 0.1 * rng:valueForUniqueID(object.uniqueID, 23542))
                else
                    callbackOffset = serverWorld:getYearLength() * 0.25
                    callbackOffset = callbackOffset - 50.0 + 100 * rng:valueForUniqueID(object.uniqueID, 9411)
                end

                local callbackWorldTime = serverWorld:getWorldTime() + callbackOffset

                --mj:log("serverEvolvingTerrain:addCallbacksForRemoval. Time until grow again callback:", callbackWorldTime - serverWorld:getWorldTime())

                sharedState:set("removalCallbackTimes", removalTypeIndex, callbackWorldTime)
                addCallback(object, callbackWorldTime, removalTypeIndex)
                
            end
        end

    end
end

function serverEvolvingTerrain:init(serverWorld_, serverGOM_, serverTerrain_, planManager_)
    serverGOM = serverGOM_
    serverWorld = serverWorld_
    serverTerrain = serverTerrain_
    --planManager = planManager_
    
    serverGOM:addObjectLoadedFunctionForType(gameObject.types.terrainModificationProxy.index, function(object)
        local sharedState = object.sharedState
        if sharedState.removalCallbackTimes and next(sharedState.removalCallbackTimes) then
            local worldTime = serverWorld:getWorldTime()
            local typesToCallNow = {}
            for removalTypeIndex,callbackWorldTime in pairs(sharedState.removalCallbackTimes) do
                if callbackWorldTime < worldTime then
                    table.insert(typesToCallNow, removalTypeIndex)
                else
                    addCallback(object, callbackWorldTime, removalTypeIndex)
                end
            end

            for i,removalTypeIndex in ipairs(typesToCallNow) do
                callCallback(object, removalTypeIndex)
            end
        end
        return false
    end)
end

return serverEvolvingTerrain