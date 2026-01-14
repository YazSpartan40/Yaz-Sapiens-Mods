local typeMaps = mjrequire "common/typeMaps"

local resource = mjrequire "common/resource"
local material = mjrequire "common/material"
local locale = mjrequire "common/locale"

local statistics = {}

local valueFormatFunctions = {
    integer = function(value)
        return string.format("%d", value)
    end,
    percentage = function(value)
        return string.format("%.1f%%", value)
    end,
    decimal = function(value)
        return string.format("%.2f", value)
    end,
}

statistics.types = typeMaps:createMap( "statistics", {
    {
        key = "birth",
        name = locale:get("stats_birth"),
        description = locale:get("stats_birth_description"),
        iconModelName = "icon_tribe2",
        iconModelMaterialRemapTable = {
            default = material.types.ui_selected.index
        },
        rollingAverage = true,
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "recruit",
        name = locale:get("stats_recruit"),
        description = locale:get("stats_recruit_description"),
        iconModelName = "icon_tribe2",
        iconModelMaterialRemapTable = {
            default = material.types.ui_selected.index
        },
        rollingAverage = true,
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "death",
        name = locale:get("stats_death"),
        description = locale:get("stats_death_description"),
        iconModelName = "icon_tribe2",
        iconModelMaterialRemapTable = {
            default = material.types.red.index
        },
        rollingAverage = true,
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "leave",
        name = locale:get("stats_leave"),
        description = locale:get("stats_leave_description"),
        iconModelName = "icon_tribe2",
        iconModelMaterialRemapTable = {
            default = material.types.red.index
        },
        rollingAverage = true,
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "population",
        name = locale:get("stats_population"),
        description = locale:get("stats_population_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "populationChild",
        name = locale:get("stats_populationChild"),
        description = locale:get("stats_populationChild_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "populationAdult",
        name = locale:get("stats_populationAdult"),
        description = locale:get("stats_populationAdult_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "populationElder",
        name = locale:get("stats_populationElder"),
        description = locale:get("stats_populationElder_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "populationPregnant",
        name = locale:get("stats_populationPregnant"),
        description = locale:get("stats_populationPregnant_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "populationBaby",
        name = locale:get("stats_populationBaby"),
        description = locale:get("stats_populationBaby_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "averageHappiness",
        name = locale:get("stats_averageHappiness"),
        description = locale:get("stats_averageHappiness_description"),
        iconModelName = "icon_happy",
        valueFormatFunction = valueFormatFunctions.percentage,
    },
    {
        key = "averageLoyalty",
        name = locale:get("stats_averageLoyalty"),
        description = locale:get("stats_averageLoyalty_description"),
        iconModelName = "icon_tribe2",
        valueFormatFunction = valueFormatFunctions.percentage,
    },
    {
        key = "averageSkill",
        name = locale:get("stats_averageSkill"),
        description = locale:get("stats_averageSkill_description"),
        iconModelName = "icon_idea",
        valueFormatFunction = valueFormatFunctions.decimal,
    },
    {
        key = "bedCount",
        name = locale:get("stats_bedCount"),
        description = locale:get("stats_bedCount_description"),
        iconModelName = "icon_bed",
        valueFormatFunction = valueFormatFunctions.integer,
    },
    {
        key = "foodCount",
        name = locale:get("stats_foodCount"),
        description = locale:get("stats_foodCount_description"),
        iconModelName = "icon_food",
        valueFormatFunction = valueFormatFunctions.integer,
    },
})

function statistics:getDecriptionWithCurrentValue(statisticsTypeIndex, value)
    if not statisticsTypeIndex then
        return ""
    end
    return statistics.types[statisticsTypeIndex].description .. ": " .. statistics.types[statisticsTypeIndex].valueFormatFunction(value)
end

function statistics:mjInit()

    
    --mj:log("statistics:mjInit")
    
    statistics.orderedList = {
        statistics.types.population.index, 
        statistics.types.birth.index, 
        statistics.types.recruit.index, 
        statistics.types.death.index, 
        statistics.types.leave.index, 
        statistics.types.populationPregnant.index, 
        statistics.types.populationBaby.index, 
        statistics.types.populationChild.index, 
        statistics.types.populationAdult.index, 
        statistics.types.populationElder.index, 
        statistics.types.averageHappiness.index, 
        statistics.types.averageLoyalty.index, 
        statistics.types.averageSkill.index, 
        statistics.types.bedCount.index, 
        statistics.types.foodCount.index, 
    }

    local orderedResources = {}

    for i,resourceType in ipairs(resource.validTypes) do
        local statsKey = "r_" .. resourceType.key
        typeMaps:insert("statistics", statistics.types, {
            key = statsKey,
            name = resourceType.plural,
            description = locale:get("stats_resource_description", {
                resourcePlural = resourceType.plural
            }),
            resourceTypeIndex = resourceType.index,
            iconObjectTypeIndex = resourceType.displayGameObjectTypeIndex,
            valueFormatFunction = valueFormatFunctions.integer,
        })
        table.insert(orderedResources, statistics.types[statsKey].index)
    end

    
    local function sortByName(a,b)
        return statistics.types[a].name < statistics.types[b].name
    end

    table.sort(orderedResources, sortByName)
	for i=1,#orderedResources do
        table.insert(statistics.orderedList, orderedResources[i])
	end

    statistics.validTypes = typeMaps:createValidTypesArray("statistics", statistics.types)



end

return statistics