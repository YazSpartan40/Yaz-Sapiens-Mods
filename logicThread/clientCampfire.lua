local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
--local normalize = mjm.normalize
local length = mjm.length

local gameObject = mjrequire "common/gameObject"
--local resource = mjrequire "common/resource"
local modelPlaceholder = mjrequire "common/modelPlaceholder"

local logic = mjrequire "logicThread/logic"
local logicAudio = mjrequire "logicThread/logicAudio"
local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local clientConstruction = mjrequire "logicThread/clientConstruction"
local resource = mjrequire "common/resource"

local clientCampfire = {}

local clientGOM = nil


clientCampfire.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    clientCampfire:updateCampfireEffects(object)
    clientCampfire:updateSubModels(object)
    clientGOM:setCovered(object.uniqueID, object.sharedState.covered)
end

clientCampfire.objectWasLoaded = function(object, pos, rotation, scale)
    clientCampfire:updateCampfireEffects(object)
    clientCampfire:updateSubModels(object)
    clientGOM:setCovered(object.uniqueID, object.sharedState.covered)
end

clientCampfire.objectSnapMatrix = function(object, pos, rotation)
    --mj:log("clientCampfire.objectSnapMatrix:", pos, " object.pos:", object.pos )
    local clientState = clientGOM:getClientState(object)
    if clientState.emitterID then
        particleManagerInterface:removeEmitter(clientState.emitterID)
        clientState.emitterID = nil
    end
    if clientState.lightAdded then
        logic:callMainThreadFunction("removeLightForObject", object.uniqueID)
        clientState.lightAdded = false
    end
    if clientState.soundAdded then
        logicAudio:removeLoopingSoundForObject(object)
        clientState.soundAdded = false
    end
    clientCampfire:updateCampfireEffects(object)
    clientCampfire:updateSubModels(object)
end

clientCampfire.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientCampfire:updateSubModels(object)
    end
end

function clientCampfire:updateCampfireEffects(campfire)
    local clientState = clientGOM:getClientState(campfire)
    if campfire.sharedState.isLit then
        local emitterType = particleManagerInterface.emitterTypes.campfireLarge
        
        local fuelState = campfire.sharedState.fuelState
        local fuelCount = 0
        if fuelState then
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel > 0.0 then
                    fuelCount = fuelCount + 1
                end
            end
            if fuelCount <= 1 then
                emitterType = particleManagerInterface.emitterTypes.campfireSmall
            elseif fuelCount <= 4 then 
                emitterType = particleManagerInterface.emitterTypes.campfireMedium
            end
        end

        if (not clientState.emitterID) or (clientState.emitterType ~= emitterType)then
            if clientState.emitterID then
                particleManagerInterface:removeEmitter(clientState.emitterID)
            end
            local emitterID = particleManagerInterface:addEmitter(emitterType, campfire.pos, campfire.rotation, nil, campfire.sharedState.covered)
            clientState.emitterID = emitterID
            clientState.emitterType = emitterType
            --mj:log("add emitter:", clientState.emitterID)
        end

        if (not clientState.lightAdded) or (clientState.lightFuelCount ~= fuelCount) then
            if clientState.lightAdded then
                logic:callMainThreadFunction("removeLightForObject", campfire.uniqueID)
            end
            local lengthObjectPos = length(campfire.pos)
            logic:callMainThreadFunction("addLightForObject", {
                uniqueID = campfire.uniqueID, 
                pos = campfire.pos / lengthObjectPos * (lengthObjectPos + mj:mToP(0.7)), 
                color = vec3(4.0,1.0,0.1) * 0.1 * (0.05 + (fuelCount * 0.2) * (fuelCount * 0.2))
            })
            clientState.lightAdded = true
            clientState.lightFuelCount = fuelCount
        end

        if not clientState.soundAdded then
            logicAudio:addLoopingSoundForObject(campfire, "audio/sounds/fire1.wav")
            clientState.soundAdded = true
        end
        
        clientGOM:addObjectToSet(campfire, clientGOM.objectSets.temperatureIncreasers)
    else
        if clientState.emitterID then
            particleManagerInterface:removeEmitter(clientState.emitterID)
            clientState.emitterID = nil
            logicAudio:playWorldSound("audio/sounds/extinguish1.wav", campfire.pos)
        end
        if clientState.lightAdded then
            logic:callMainThreadFunction("removeLightForObject", campfire.uniqueID)
            clientState.lightAdded = false
        end
        if clientState.soundAdded then
            logicAudio:removeLoopingSoundForObject(campfire)
            clientState.soundAdded = false
        end
        clientGOM:removeObjectFromSet(campfire, clientGOM.objectSets.temperatureIncreasers)
    end
end


function clientCampfire:updateSubModels(object)
    --mj:log("clientCampfire:updateSubModels:", object.uniqueID)
    clientGOM:removeAllSubmodels(object.uniqueID)
    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(object.modelIndex)
    if not placeholderKeys then --probably using lowest model, everything hidden
        return
    end
    local sharedState = object.sharedState
    local constructionObjects = sharedState.constructionObjects
    
    local fuelState = sharedState.fuelState
    local fuelIndex = 1

    local foundResourceCounts = {}
    local placeholderContext = {
        buildComplete = true,
        hasFuel = true,
        subdivLevel = object.subdivLevel,
    }

    for i,key in pairs(placeholderKeys) do
        local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key)
        --mj:log("key:", key)
        --mj:log("placeholderInfo:", placeholderInfo)

        local modelIndex = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
        if modelIndex then
            local foundObjectInfo = nil
            local resourceTypeOrGroupIndex = placeholderInfo.resourceTypeIndex or placeholderInfo.resourceGroupIndex
            if resourceTypeOrGroupIndex then
                local resourceCounter = 0
                if constructionObjects then
                    for j,objectInfo in ipairs(constructionObjects) do
                        if resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndex, gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex) then
                            resourceCounter = resourceCounter + 1
                            if not foundResourceCounts[resourceTypeOrGroupIndex] or resourceCounter > foundResourceCounts[resourceTypeOrGroupIndex] then
                                foundResourceCounts[resourceTypeOrGroupIndex] = resourceCounter
                                modelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, objectInfo.objectTypeIndex, placeholderContext)
                                foundObjectInfo = objectInfo
                                --mj:log("modelIndex B:", modelIndex, " objectTypeIndex:", objectInfo.objectTypeIndex)
                                break
                            end
                        end
                    end
                end
            else
                if key == "ash" then
                    if not sharedState.hasAsh then
                        modelIndex = nil
                    end
                else
                    if fuelState then
                        local fuelInfo = fuelState[fuelIndex]
                        if fuelInfo then

                            if fuelInfo.objectTypeIndex then
                            --mj:log("fuelInfo", fuelInfo)
                                local objectTypeIndex = fuelInfo.objectTypeIndex
                                local hasFuel = (fuelInfo.fuel and (fuelInfo.fuel > 0.0))

                                local fuelPlacholderContext = {
                                    buildComplete = true,
                                    hasFuel = hasFuel,
                                    subdivLevel = object.subdivLevel,
                                }
                                
                                modelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, objectTypeIndex, fuelPlacholderContext)
                                --mj:log("modelIndex A:", modelIndex, " objectTypeIndex:", objectTypeIndex)
                                foundObjectInfo = {
                                    objectTypeIndex = objectTypeIndex,
                                }
                            else
                                modelIndex = nil
                            end

                            fuelIndex = fuelIndex + 1

                        end
                    end
                end
            end

            if modelIndex then
                local subModelTransform = clientGOM:getSubModelTransform(object, key)

                clientGOM:setSubModelForKey(object.uniqueID,
                    key,
                    nil,
                    modelIndex,
                    placeholderInfo.scale or 1.0,
                    RENDER_TYPE_STATIC,
                    subModelTransform.offsetMeters,
                    subModelTransform.rotation,
                    false,
                    modelPlaceholder:getSubModelInfos(foundObjectInfo, object.subdivLevel)
                    )
            else
                clientGOM:removeSubModelForKey(object.uniqueID, key)
            end
        else
            clientGOM:removeSubModelForKey(object.uniqueID, key)
        end
    end
    
    if sharedState and sharedState.inventories then
        --mj:log("campfire clientConstruction:updatePlaceholdersForCraftOrBuild:", object.uniqueID)
        clientConstruction:updatePlaceholdersForCraftOrBuild(object)
    end
end

function clientCampfire:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientCampfire