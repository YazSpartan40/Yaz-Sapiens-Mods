
local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local tool = {}

local gameObjectTypeIndexMap = typeMaps.types.gameObject


tool.groupTypes = typeMaps:createMap("toolGroup", { --not actually used anywhere as far as I can tell. Might be useful later, but delete if it's a pain
    {
        key = "weapon",
        name = locale:get("toolGroup_weapon"),
        plural = locale:get("toolGroup_weapon_plural")
    },
})

tool.propertyTypes = typeMaps:createMap("toolProperties", {
    {
        key = "damage",
        name = locale:get("toolProperties_damage"),
    },
    {
        key = "speed",
        name = locale:get("toolProperties_speed"),
    },
    {
        key = "durability",
        name = locale:get("toolProperties_durability"),
    },
})

local usageThresholds = {
    {
        fraction = 0.25,
        name = locale:get("tool_usage_new")--"New",
    },
    {
        fraction = 0.5,
        name = locale:get("tool_usage_used")--"Used",
    },
    {
        fraction = 0.75,
        name = locale:get("tool_usage_wellUsed")--"Well Used",
    },
    {
        fraction = 2.0,
        name = locale:get("tool_usage_nearlyBroken")--"Nearly Broken",
    },
}

function tool:getUsageThresholdIndexForFraction(fractionDegraded)
    if not fractionDegraded then
        return usageThresholds[1]
    end
    local result = usageThresholds[1]
    for i,usageThreshold in ipairs(usageThresholds) do
        result = usageThreshold
        if fractionDegraded < usageThreshold.fraction then
            break
        end
    end
    return result
end

function tool:getUsageNameForFraction(fractionDegraded)
    return tool:getUsageThresholdIndexForFraction(fractionDegraded).name
end

tool.orderedPropertyTypeIndexesForUI = {
    tool.propertyTypes.speed.index,
    tool.propertyTypes.damage.index,
    tool.propertyTypes.durability.index,
}

tool.types = typeMaps:createMap("tool", {
    {
        key = "treeChop",
        name = locale:get("tool_treeChop"),
        plural = locale:get("tool_treeChop_plural"),
        usage = locale:get("tool_treeChop_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneHatchet,
    },
    {
        key = "dig",
        name = locale:get("tool_dig"),
        plural = locale:get("tool_dig_plural"),
        usage = locale:get("tool_dig_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneAxeHead,
    },
    {
        key = "mine",
        name = locale:get("tool_mine"),
        plural = locale:get("tool_mine_plural"),
        usage = locale:get("tool_mine_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stonePickaxe,
    },
    {
        key = "weaponBasic",
        name = locale:get("tool_weaponBasic"),
        plural = locale:get("tool_weaponBasic_plural"),
        usage = locale:get("tool_weaponBasic_usage"),
        groupTypes = {
            tool.groupTypes.weapon.index
        },
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.rockSmall,
        projectileBaseThrowDistance = mj:mToP(15.0),
    },
    {
        key = "weaponSpear",
        name = locale:get("tool_weaponSpear"),
        plural = locale:get("tool_weaponSpear_plural"),
        usage = locale:get("tool_weaponSpear_usage"),
        groupTypes = {
            tool.groupTypes.weapon.index
        },
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneSpear,
        projectileEmbeds = true, --maybe not the best place for this?
        projectileBaseThrowDistance = mj:mToP(30.0),
    },
    {
        key = "weaponKnife",
        name = locale:get("tool_weaponKnife"),
        plural = locale:get("tool_weaponKnife_plural"),
        usage = locale:get("tool_weaponKnife_usage"),
        groupTypes = {
            tool.groupTypes.weapon.index
        },
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneKnife,
        projectileEmbeds = true,
        projectileBaseThrowDistance = mj:mToP(20.0),
    },
    {
        key = "butcher",
        name = locale:get("tool_butcher"),
        plural = locale:get("tool_butcher_plural"),
        usage = locale:get("tool_butcher_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneKnife,
    },
    {
        key = "knapping",
        name = locale:get("tool_knapping"),
        plural = locale:get("tool_knapping_plural"),
        usage = locale:get("tool_knapping_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.rockSmall,
    },
    {
        key = "knappingCrude",
        name = locale:get("tool_knappingCrude"),
        plural = locale:get("tool_knappingCrude_plural"),
        usage = locale:get("tool_knappingCrude_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.rock,
    },
    {
        key = "grinding",
        name = locale:get("tool_grinding"),
        plural = locale:get("tool_grinding_plural"),
        usage = locale:get("tool_grinding_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.quernstone,
    },
    {
        key = "carving",
        name = locale:get("tool_carving"),
        plural = locale:get("tool_carving_plural"),
        usage = locale:get("tool_carving_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneChisel,
    },
    {
        key = "crucible",
        name = locale:get("tool_crucible"),
        plural = locale:get("tool_crucible_plural"),
        usage = locale:get("tool_crucible_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.crucibleDry,
    },
    {
        key = "hammering",
        name = locale:get("tool_hammering"),
        plural = locale:get("tool_hammering_plural"),
        usage = locale:get("tool_hammering_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneHammer,
    },
    {
        key = "softChiselling",
        name = locale:get("tool_softChiselling"),
        plural = locale:get("tool_softChiselling_plural"),
        usage = locale:get("tool_softChiselling_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.stoneChisel,
    },
    {
        key = "hardChiselling",
        name = locale:get("tool_hardChiselling"),
        plural = locale:get("tool_hardChiselling_plural"),
        usage = locale:get("tool_hardChiselling_usage"),
        displayGameObjectTypeIndex = gameObjectTypeIndexMap.bronzeChisel,
    },
})

tool.validTypes = typeMaps:createValidTypesArray("tool", tool.types)

return tool
