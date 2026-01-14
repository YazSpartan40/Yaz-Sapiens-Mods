
local typeMaps = mjrequire "common/typeMaps"
local resource = mjrequire "common/resource"
local plan = mjrequire "common/plan"

local medicine = {}

local statusEffectTypeMap = typeMaps.types.statusEffect


medicine.types = typeMaps:createMap("medicine", {
    {
        key = "injury",
        medicineResource = resource.groups.injuryMedicine.index,
        treatmentStatusEffect = statusEffectTypeMap.injuryTreated,
        treatmentPlanTypeIndex = plan.types.treatInjury.index,
    },
    {
        key = "burn",
        medicineResource = resource.groups.burnMedicine.index,
        treatmentStatusEffect = statusEffectTypeMap.burnTreated,
        treatmentPlanTypeIndex = plan.types.treatBurn.index,
    },
    {
        key = "foodPoisoning",
        medicineResource = resource.groups.foodPoisoningMedicine.index,
        treatmentStatusEffect = statusEffectTypeMap.foodPoisoningTreated,
        treatmentPlanTypeIndex = plan.types.treatFoodPoisoning.index,
        immunityStatusEffect = statusEffectTypeMap.foodPoisoningImmunity,
    },
    {
        key = "virus",
        medicineResource = resource.groups.virusMedicine.index,
        treatmentStatusEffect = statusEffectTypeMap.virusTreated,
        treatmentPlanTypeIndex = plan.types.treatVirus.index,
        immunityStatusEffect = statusEffectTypeMap.virusImmunity,
    },
})

function medicine:getRequiredItemsForPlanType(planTypeIndex)
    local requiredResource = medicine.requiredResourceByPlanTypes[planTypeIndex]
    if resource.groups[requiredResource] then
        return {
            resources = {
                {
                    group = requiredResource,
                    count = 1,
                }
            }
        }
    end
    return {
        resources = {
            {
                type = requiredResource,
                count = 1,
            }
        }
    }
end

function medicine:mjInit()
    medicine.requiredResourceByPlanTypes = {}
    medicine.medicinesByResourceType = {}

    medicine.validTypes = typeMaps:createValidTypesArray("medicine", medicine.types)
	for i,medicineType in ipairs(medicine.validTypes) do
        medicine.requiredResourceByPlanTypes[medicineType.treatmentPlanTypeIndex] = medicineType.medicineResource

        for j,resourceTypeIndex in ipairs(resource.groups[medicineType.medicineResource].resourceTypes) do
            medicine.medicinesByResourceType[resourceTypeIndex] = medicineType
        end
    end
end

return medicine