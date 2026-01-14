local typeMaps = mjrequire "common/typeMaps"
--local locale = mjrequire "common/locale"
local gameObject = mjrequire "common/gameObject"
local skill = mjrequire "common/skill"
local fuel = mjrequire "common/fuel"
local plan = mjrequire "common/plan"

local maintenance = {}

local serverStorageArea = nil --only set on server

local maintenanceTypeIndexesByObjectTypeIndex = {}


local function sapienTribeShouldDoMaintenanceOrdersForObject(sapienTribeID, object)
	if object.sharedState and object.sharedState.tribeID then
        return sapienTribeID == object.sharedState.tribeID
    end
    return true
end

maintenance.types = typeMaps:createMap( "maintenance", {
    {
        key = "fireFuel",
        planTypeIndex = plan.types.addFuel.index,
        skills = {
            required = skill.types.fireLighting.index,
        },
        objectTypeIndexes = {
            gameObject.types.campfire.index,
            gameObject.types.brickKiln.index,
        },
        requiresMaintenanceFunction = function(tribeID, object, spaienIDOrNilForAny)
            if sapienTribeShouldDoMaintenanceOrdersForObject(tribeID, object) then
                return fuel:objectRequiresAnyFuel(object)
            end
            return false
        end,
    },
    {
        key = "torchFuel",
        planTypeIndex = plan.types.addFuel.index,
        skills = {
            required = skill.types.fireLighting.index,
        },
        objectTypeIndexes = {
            gameObject.types.torch.index,
        },
        requiresMaintenanceFunction = function(tribeID, object, spaienIDOrNilForAny)
            if sapienTribeShouldDoMaintenanceOrdersForObject(tribeID, object) then
                return fuel:objectRequiresAnyFuel(object)
            end
            return false
        end,
    },
    {
        key = "storageTransfer",
        planTypeIndex = plan.types.transferObject.index,
        skills = {
            required = skill.types.gathering.index,
        },
        objectTypeIndexes = gameObject.storageAreaTypes,
        requiresMaintenanceFunction = function(tribeID, object, spaienIDOrNilForAny)
            if serverStorageArea then
                --if sapienTribeShouldDoMaintenanceOrdersForObject(tribeID, object) then
                    return serverStorageArea:requiresMaintenanceTransfer(tribeID, object, spaienIDOrNilForAny)
                --end
                --return false
            end
            mj:error("requiresMaintenanceFunction may only be called for storageTransfer orders on the server")
            return false
        end,
    },
    {
        key = "storageTransferHaul",
        planTypeIndex = plan.types.haulObject.index,
        skills = {
            required = skill.types.gathering.index,
        },
        objectTypeIndexes = gameObject.moveableStorageAreaTypes,
        requiresMaintenanceFunction = function(tribeID, object, spaienIDOrNilForAny)
            if serverStorageArea then
                --if sapienTribeShouldDoMaintenanceOrdersForObject(tribeID, object) then
                    return serverStorageArea:requiresMaintenanceHaul(tribeID, object, spaienIDOrNilForAny)
                --end
                --return false
            end
            mj:error("requiresMaintenanceFunction may only be called for storageTransferHaul orders on the server")
            return false
        end,
    },
    {
        key = "destroyContents",
        planTypeIndex = plan.types.destroyContents.index,
        skills = {
            required = skill.types.gathering.index,
        },
        objectTypeIndexes = gameObject.storageAreaTypes,
        requiresMaintenanceFunction = function(tribeID, object, spaienIDOrNilForAny)
            --if sapienTribeShouldDoMaintenanceOrdersForObject(tribeID, object) then
                return serverStorageArea:requiresMaintenanceDestroyItems(tribeID, object, spaienIDOrNilForAny)
           -- end
            --return false
        end,
    },
    {
        key = "compost",
        planTypeIndex = plan.types.deliverToCompost.index,
        skills = {
            required = skill.types.gathering.index,
        },
        objectTypeIndexes = {
            gameObject.types.compostBin.index,
        },
        requiresMaintenanceFunction = function(tribeID, object, spaienIDOrNilForAny)
            if sapienTribeShouldDoMaintenanceOrdersForObject(tribeID, object) then
                return true--serverCompostBin:requiresMaintenance(tribeID, object, spaienIDOrNilForAny)
            end
            return false
        end,
    },
})

function maintenance:requiredMaintenanceTypeIndex(tribeID, object, spaienIDOrNilForAny)
    if object.sharedState.requiresMaintenanceByTribe and object.sharedState.requiresMaintenanceByTribe[tribeID] then
        local maintenanceTypeIndexes = maintenanceTypeIndexesByObjectTypeIndex[object.objectTypeIndex]
        if maintenanceTypeIndexes then
            for i,maintenanceTypeIndex in ipairs(maintenanceTypeIndexes) do
                local maintenanceType = maintenance.types[maintenanceTypeIndex]
                if maintenanceType.requiresMaintenanceFunction(tribeID, object, spaienIDOrNilForAny) then
                    return maintenanceTypeIndex
                end
            end
        end
    end

    return nil
end

function maintenance:maintenanceTypeIndexesForObjectTypeIndex(objectTypeIndex)
    return maintenanceTypeIndexesByObjectTypeIndex[objectTypeIndex]
end

function maintenance:maintenanceIsRequiredOfType(tribeID, object, maintenanceTypeIndex, spaienIDOrNilForAny)
    if object.sharedState.requiresMaintenanceByTribe and object.sharedState.requiresMaintenanceByTribe[tribeID] then
        local maintenanceType = maintenance.types[maintenanceTypeIndex]
        if maintenanceType.requiresMaintenanceFunction(tribeID, object, spaienIDOrNilForAny) then
            return true
        end
    end
    return false
end

function maintenance:setServerStorageArea(serverStorageArea_)
    serverStorageArea = serverStorageArea_
end

maintenance.validTypes = typeMaps:createValidTypesArray("maintenance", maintenance.types)
    
for i,maintenanceType in ipairs(maintenance.validTypes) do
    for j,objectTypeIndex in ipairs(maintenanceType.objectTypeIndexes) do
        if not maintenanceTypeIndexesByObjectTypeIndex[objectTypeIndex] then
            maintenanceTypeIndexesByObjectTypeIndex[objectTypeIndex] = {}
        end
        table.insert(maintenanceTypeIndexesByObjectTypeIndex[objectTypeIndex], maintenanceType.index)
    end
end

return maintenance