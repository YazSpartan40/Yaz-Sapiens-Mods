--local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
--local vec3xMat3 = mjm.vec3xMat3
--local mat3Identity = mjm.mat3Identity
--local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
--local mat3GetRow = mjm.mat3GetRow
--local mat3Inverse = mjm.mat3Inverse

--local model = mjrequire "common/model"
--local storage = mjrequire "common/storage"
--local constructable = mjrequire "common/constructable"
--local resource = mjrequire "common/resource"
--local gameObject = mjrequire "common/gameObject"
--local modelPlaceholder = mjrequire "common/modelPlaceholder"
local objectInventory = mjrequire "common/objectInventory"
--local worldHelper = mjrequire "common/worldHelper"
--local physicsSets = mjrequire "common/physicsSets"

local clientConstruction = mjrequire "logicThread/clientConstruction"
local clientBuiltObject = mjrequire "logicThread/clientBuiltObject"

local clientCraftArea = {}

local clientGOM = nil

clientCraftArea.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    if not pos then --debug crashed here due to no pos?
        mj:error("no pos in clientCraftArea.serverUpdate. object:", object, " pos:", pos, " rotation:", rotation, " incomingServerStateDelta:", incomingServerStateDelta)
    end
    clientGOM:updateMatrix(object.uniqueID, pos, rotation)
    clientCraftArea:updateCraftAreaSubModels(object)
end

clientCraftArea.objectWasLoaded = function(object, pos, rotation, scale)
    clientCraftArea:updateCraftAreaSubModels(object)
end

clientCraftArea.objectSnapMatrix = function(object, pos, rotation)
    clientCraftArea:updateCraftAreaSubModels(object)
end

clientCraftArea.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        clientCraftArea:updateCraftAreaSubModels(object)
    end
end


function clientCraftArea:getInUseToolGameObjectInfo(craftAreaObjectID)
    local craftAreaObject = clientGOM:getObjectWithID(craftAreaObjectID)
    if craftAreaObject then
        local sharedState = craftAreaObject.sharedState
        local inventories = sharedState.inventories
        --mj:log("inventories:", inventories)
        if inventories then
            local inventory = inventories[objectInventory.locations.tool.index]
            if inventory and inventory.objects then
                return inventory.objects[1]
            end
        end
    end
    return nil
end

function clientCraftArea:getInUseResourceGameObjectInfos(craftAreaObjectID)
    local craftAreaObject = clientGOM:getObjectWithID(craftAreaObjectID)
    if craftAreaObject then
        local sharedState = craftAreaObject.sharedState
        local inventories = sharedState.inventories
        if inventories then
            local inventory = inventories[objectInventory.locations.inUseResource.index]
            if inventory then
                return inventory.objects
            end
        end
    end
    return nil
end



function clientCraftArea:updateCraftAreaSubModels(object)
    
    --disabled--mj:objectLog(object.uniqueID, "clientCraftArea:updateCraftAreaSubModels sharedState:", object.sharedState)
    clientGOM:removeAllSubmodels(object.uniqueID)

    local sharedState = object.sharedState

    --[[if modelPlaceholder:modelHasPlaceholderKey(object.modelIndex, "pebble_1") then
        for i=1,12 do
            local pebbleKey = "pebble_" .. mj:tostring(i)
            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, pebbleKey)
            local subModelIndex = placeholderInfo.defaultModelIndex
            local subModelTransform = clientGOM:getSubModelTransformForModel(object.modelIndex, object.pos, object.rotation, object.scale, pebbleKey, object.uniqueID)
            object:setSubModelForKey(
                pebbleKey,
                nil,
                subModelIndex,
                1.5 - 0.08 * i,
                RENDER_TYPE_STATIC,
                subModelTransform.offsetMeters,
                subModelTransform.rotation,
                false,
                nil
                )
        end
    end]]

    clientBuiltObject:updateBuiltObjectSubModels(object)

    if sharedState and sharedState.inventories then
        --disabled--mj:objectLog(object.uniqueID, "clientConstruction:updatePlaceholdersForCraftOrBuild")
        clientConstruction:updatePlaceholdersForCraftOrBuild(object)
    end
end

function clientCraftArea:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientCraftArea