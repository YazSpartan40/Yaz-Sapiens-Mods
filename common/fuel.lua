

local resource = mjrequire "common/resource"
local gameObject = mjrequire "common/gameObject"
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local fuel = {}

fuel.fuelGroups = typeMaps:createMap("fuelGroup", {
    {
        key = "campfire",
        name = locale:get("fuelGroup_campfire"),
        resources = {
            [resource.types.branch.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.log.index] = {
                fuelAddition = 6.0,
            },
            [resource.types.pineCone.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.pineConeBig.index] = {
                fuelAddition = 6.0,
            },
        },
        objectTypes = {},
        resourceGroupIndex = resource.groups.campfireFuel.index,
    },
    {
        key = "kiln",
        name = locale:get("fuelGroup_kiln"),
        resources = {
            [resource.types.branch.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.log.index] = {
                fuelAddition = 6.0,
            },
            [resource.types.pineCone.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.pineConeBig.index] = {
                fuelAddition = 6.0,
            },
        },
        objectTypes = {},
        resourceGroupIndex = resource.groups.kilnFuel.index,
    },
    {
        key = "torch",
        name = locale:get("fuelGroup_torch"),
        resources = {
            [resource.types.hay.index] = {
                fuelAddition = 1.0,
            },
        },
        objectTypes = {},
        resourceGroupIndex = resource.groups.torchFuel.index,
    },
    {
        key = "litObject",
        name = locale:get("fuelGroup_litObject"),
        resources = {
            [resource.types.hay.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.branch.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.log.index] = {
                fuelAddition = 6.0,
            },
            [resource.types.pineCone.index] = {
                fuelAddition = 1.0,
            },
            [resource.types.pineConeBig.index] = {
                fuelAddition = 6.0,
            },
        },
        objectTypes = {},
    },
}) --DONT FORGET TO ADD TO RESOURCE GROUPS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


function fuel:degradeFractionForFuelStateInfo(object, fuelInfo)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local fuelGameObjectType = gameObject.types[fuelInfo.objectTypeIndex]
        if fuelGameObjectType.resourceTypeIndex then
            return fuelInfo.fuel / thisFuelGroup.resources[fuelGameObjectType.resourceTypeIndex].fuelAddition
        end
    end
    return 0.0
end



function fuel:objectRequiresAnyFuel(object)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local fuelState = object.sharedState.fuelState
        if fuelState then
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel <= 0.0 then
                    return true
                end
            end
        end
    end
    return false
end


function fuel:objectHasAnyFuel(object)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local fuelState = object.sharedState.fuelState
        if fuelState then
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel > 0.0 then
                    return true
                end
            end
        end
    end
    return false
end

function fuel:objectRequiredFuelCount(object)
    local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
    if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
        local requiredCount = 0
        local fuelState = object.sharedState.fuelState
        if fuelState then
            for i,fuelInfo in ipairs(fuelState) do
                if fuelInfo.fuel <= 0.0 then
                    requiredCount = requiredCount + 1
                end
            end
        end
        return requiredCount
    end
    return 0
end

function fuel:getRequiredItemsForFuelAdd(object)
    local result = nil
    local requiredCount = fuel:objectRequiredFuelCount(object)
    if requiredCount > 0 then
        local thisFuelGroup = fuel.groupsByObjectTypeIndex[object.objectTypeIndex]
        if thisFuelGroup and thisFuelGroup.resourceGroupIndex then
            result = {
                resources = {
                    {
                        group = thisFuelGroup.resourceGroupIndex,
                        count = requiredCount,
                    }
                }
            }
        end
    end
    return result
end

function fuel:finalize()
    fuel.validGroupTypes = typeMaps:createValidTypesArray("fuelGroup", fuel.fuelGroups)
    local fuelGroupsByFuelResourceTypes = {}

    for i,groupType in ipairs(fuel.validGroupTypes) do
        for resourceTypeIndex,info in pairs(groupType.resources) do
            local gameObjectsTypesForResource = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
            for j,gameObjectTypeIndex in ipairs(gameObjectsTypesForResource) do
                table.insert(groupType.objectTypes, gameObjectTypeIndex)
            end

            local fuelGroupsArray = fuelGroupsByFuelResourceTypes[resourceTypeIndex]
            if not fuelGroupsArray then
                fuelGroupsArray = {}
                fuelGroupsByFuelResourceTypes[resourceTypeIndex] = fuelGroupsArray
            end
            if groupType.resourceGroupIndex then
                table.insert(fuelGroupsArray, groupType)
            end
        end
    end

    fuel.groupsByObjectTypeIndex = {
        [gameObject.types.campfire.index] = fuel.fuelGroups.campfire,
        [gameObject.types.torch.index] = fuel.fuelGroups.torch,
        [gameObject.types.brickKiln.index] = fuel.fuelGroups.kiln,
    }

    fuel.fuelGroupsByFuelResourceTypes = fuelGroupsByFuelResourceTypes

end

function fuel:mjInit()
    fuel:finalize()
end

return fuel