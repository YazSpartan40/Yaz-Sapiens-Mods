
local clientConstruction = mjrequire "logicThread/clientConstruction"

local clientBuildableObject = {}

local clientGOM = nil

local objectsNeedingUpdate = {}


clientBuildableObject.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    objectsNeedingUpdate[object.uniqueID] = true
    --clientBuildableObject:updateBuildabaleSubModels(object)
end

clientBuildableObject.objectWasLoaded = function(object, pos, rotation, scale)
    objectsNeedingUpdate[object.uniqueID] = true
    --clientBuildableObject:updateBuildabaleSubModels(object)
end

clientBuildableObject.objectSnapMatrix = function(object, pos, rotation)
    objectsNeedingUpdate[object.uniqueID] = true
   -- clientBuildableObject:updateBuildabaleSubModels(object)
end

clientBuildableObject.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        objectsNeedingUpdate[objectID] = true
        --clientBuildableObject:updateBuildabaleSubModels(object)
    end
end

function clientBuildableObject:updateBuildabaleSubModels(object)
    --mj:log("updateBuildabaleSubModels:", object.sharedState)
    
    clientGOM:setTransparentBuildObject(object.uniqueID, true)
    clientConstruction:updatePlaceholdersForCraftOrBuild(object)
end

function clientBuildableObject:update()
    for objectID,v in pairs(objectsNeedingUpdate) do
        local object = clientGOM:getObjectWithID(objectID)
        if object then
            clientBuildableObject:updateBuildabaleSubModels(object)
        end
    end
    objectsNeedingUpdate = {}
end

function clientBuildableObject:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientBuildableObject