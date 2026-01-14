--local mjm = mjrequire "common/mjm"
--local vec2 = mjm.vec2
--local vec3 = mjm.vec3
--local dot = mjm.dot

local constructable = mjrequire "common/constructable"
local gameObject = mjrequire "common/gameObject"
--local research = mjrequire "common/research"
local resource = mjrequire "common/resource"
local typeMaps = mjrequire "common/typeMaps"
local terrainTypes = mjrequire "common/terrainTypes"

local industry = {}



industry.types = typeMaps:createMap("industry", {
    {
        key = "rockTools",
        blueprintName = "rockTools", --will look for blueprintName.lua in server/blueprints/industry/
        maintainSupplies = {
            {
                plan = "clear",
                resourceTypeIndex = resource.types.grass.index,
                maintainResourceTypeIndex = resource.types.hay.index,
                count = 20, 
            },
            {
                plan = "gather",
                resourceTypeIndex = resource.types.branch.index,
                count = 20, 
            },
            {
                plan = "gather",
                resourceTypeIndex = resource.types.flax.index,
                maintainResourceTypeIndex = resource.types.flaxDried.index,
                count = 20, 
            },
            {
                plan = "craft",
                count = 20, 
                resourceTypeIndex = resource.types.flaxTwine.index,
                constructableTypeIndex = constructable.types.flaxTwine.index,
            },
            {
                plan = "craft",
                count = 20, 
                resourceTypeIndex = resource.types.rockSmall.index,
                constructableTypeIndex = constructable.types.rockSmall.index,
            },
        },
        inputs = {
            [resource.types.rock.index] = { --assume we will need some info here at some point, so might as well be empty tables
            },
            [resource.types.rockSmall.index] = {
            },
            [resource.types.branch.index] = {
            },
            [resource.types.flaxDried.index] = {
            },
            [resource.types.flaxTwine.index] = {
            },
        },
        outputs = {
            [resource.types.stoneSpearHead.index] = {
                constructableTypeIndex = constructable.types.stoneSpearHead.index,
            },
            [resource.types.stoneAxeHead.index] = {
                constructableTypeIndex = constructable.types.stoneAxeHead.index,
            },
            [resource.types.stoneKnife.index] = {
                constructableTypeIndex = constructable.types.stoneKnife.index,
            },
            [resource.types.stonePickaxeHead.index] = {
                constructableTypeIndex = constructable.types.stonePickaxeHead.index,
            },
            [resource.types.stoneHammerHead.index] = {
                constructableTypeIndex = constructable.types.stoneHammerHead.index,
            },
            [resource.types.stoneChisel.index] = {
                constructableTypeIndex = constructable.types.stoneChisel.index,
            },
            [resource.types.quernstone.index] = {
                constructableTypeIndex = constructable.types.quernstone.index,
            },

            [resource.types.stonePickaxe.index] = {
                constructableTypeIndex = constructable.types.stonePickaxe.index,
            },
            [resource.types.stoneSpear.index] = {
                constructableTypeIndex = constructable.types.stoneSpear.index,
            },
            [resource.types.stoneHammer.index] = {
                constructableTypeIndex = constructable.types.stoneHammer.index,
            },
        },
        createTradeOutputsForStoredObjectTypes = {
            [gameObject.types.lapisRock.index] = {
                plan = "mine",
                count = 200, 
                objectTypeIndex = gameObject.types.lapisRock.index,
                terrainTypes = {terrainTypes.baseTypes.lapisRock.index},
            },
            [gameObject.types.marbleRock.index] = {
                plan = "mine",
                count = 200, 
                objectTypeIndex = gameObject.types.marbleRock.index,
                terrainTypes = {terrainTypes.baseTypes.marbleRock.index},
            },
            [gameObject.types.graniteRock.index] = {
                plan = "mine",
                count = 200, 
                objectTypeIndex = gameObject.types.graniteRock.index,
                terrainTypes = {terrainTypes.baseTypes.graniteRock.index},
            },
            [gameObject.types.redRock.index] = {
                plan = "mine",
                count = 200, 
                objectTypeIndex = gameObject.types.redRock.index,
                terrainTypes = {terrainTypes.baseTypes.redRock.index},
            },
            [gameObject.types.greenRock.index] = {
                plan = "mine",
                count = 200, 
                objectTypeIndex = gameObject.types.greenRock.index,
                terrainTypes = {terrainTypes.baseTypes.greenRock.index},
            },
        },
    },
    {
        key = "flour",
        maintainSupplies = {
            {
                plan = "clear",
                count = 20, 
                resourceTypeIndex = resource.types.grass.index,
                maintainResourceTypeIndex = resource.types.hay.index,
            },
            {
                plan = "gather",
                count = 20, 
                resourceTypeIndex = resource.types.branch.index
            },
            {
                plan = "gather",
                count = 20, 
                resourceTypeIndex = resource.types.wheat.index
            },
            {
                plan = "craft",
                count = 10, 
                resourceTypeIndex = resource.types.quernstone.index,
                constructableTypeIndex = constructable.types.quernstone.index,
            },
        },
        inputs = {
            [resource.types.wheat.index] = {
            },
            [resource.types.firedUrn.index] = {
            },
            [resource.types.log.index] = {
            },
            [resource.types.branch.index] = {
            },
            [resource.types.quernstone.index] = {
            },
        },
        outputs = {
            [resource.types.firedUrnFlour.index] = {
                constructableTypeIndex = constructable.types.flour.index,
            },
            [resource.types.firedUrnHulledWheat.index] = {
                constructableTypeIndex = constructable.types.hulledWheat.index,
            },
            [resource.types.breadDough.index] = {
                constructableTypeIndex = constructable.types.breadDough.index,
            },
            [resource.types.flatbread.index] = {
                constructableTypeIndex = constructable.types.flatbread.index,
            },
        },
        blueprintName = "flour", --will look for blueprintName.lua in server/blueprints/industry/
    },
    {
        key = "pottery",
        maintainSupplies = {
            {
                plan = "clear",
                count = 20, 
                resourceTypeIndex = resource.types.grass.index,
                maintainResourceTypeIndex = resource.types.hay.index,
            },
            {
                plan = "gather",
                count = 40, 
                resourceTypeIndex = resource.types.branch.index
            },
            {
                plan = "craft",
                count = 20, 
                resourceTypeIndex = resource.types.unfiredUrnDry.index,
                constructableTypeIndex = constructable.types.unfiredUrnWet.index,
            },
            {
                plan = "craft",
                count = 20, 
                resourceTypeIndex = resource.types.unfiredBowlDry.index,
                constructableTypeIndex = constructable.types.unfiredBowlWet.index,
            },
            {
                plan = "craft",
                count = 20, 
                resourceTypeIndex = resource.types.mudTileDry.index,
                constructableTypeIndex = constructable.types.mudTileWet.index,
            },
        },
        inputs = {
            [resource.types.flintAxeHead.index] = {
            },
            [resource.types.clay.index] = {
            },
            [resource.types.log.index] = {
            },
            [resource.types.branch.index] = {
            },
        },
        outputs = {
            [resource.types.mudBrickDry.index] = {
                constructableTypeIndex = constructable.types.mudBrickWet.index,
            },
            [resource.types.firedUrn.index] = {
                constructableTypeIndex = constructable.types.firedUrn.index,
            },
            [resource.types.firedBowl.index] = {
                constructableTypeIndex = constructable.types.firedBowl.index,
            },
            [resource.types.firedBrick.index] = {
                constructableTypeIndex = constructable.types.firedBrick.index,
            },
            [resource.types.firedTile.index] = {
                constructableTypeIndex = constructable.types.firedTile.index,
            },
        },
        createTradeOutputsForStoredObjectTypes = {
            [gameObject.types.clay.index] = {
                plan = "dig",
                count = 200, 
                resourceTypeIndex = resource.types.clay.index,
                terrainTypes = {terrainTypes.baseTypes.clay.index},
            },
        },
        blueprintName = "pottery", --will look for blueprintName.lua in server/blueprints/industry/
    },
    {
        key = "bronze",
        blueprintName = "bronze", --will look for blueprintName.lua in server/blueprints/industry/
        maintainSupplies = {
            {
                plan = "clear",
                resourceTypeIndex = resource.types.grass.index,
                maintainResourceTypeIndex = resource.types.hay.index,
                count = 20, 
            },
            {
                plan = "mine",
                count = 200, 
                resourceTypeIndex = resource.types.tinOre.index,
                terrainTypes = {terrainTypes.baseTypes.tinOre.index},
            },
            {
                plan = "mine",
                count = 200, 
                resourceTypeIndex = resource.types.copperOre.index,
                terrainTypes = {terrainTypes.baseTypes.copperOre.index},
            },
            {
                plan = "gather",
                count = 40, 
                resourceTypeIndex = resource.types.branch.index
            },
            {
                plan = "gather",
                resourceTypeIndex = resource.types.flax.index,
                maintainResourceTypeIndex = resource.types.flaxDried.index,
                count = 20, 
            },
            {
                plan = "craft",
                count = 20, 
                resourceTypeIndex = resource.types.flaxTwine.index,
                constructableTypeIndex = constructable.types.flaxTwine.index,
            },
            {
                plan = "craft",
                count = 50, 
                resourceTypeIndex = resource.types.bronzeIngot.index,
                constructableTypeIndex = constructable.types.bronzeIngot.index,
            },
        },
        inputs = {
            [resource.types.tinOre.index] = { --assume we will need some info here at some point, so might as well be empty tables
            },
            [resource.types.copperOre.index] = {
            },
            [resource.types.crucibleDry.index] = {
            },
            [resource.types.branch.index] = {
            },
            [resource.types.log.index] = {
            },
            [resource.types.flaxDried.index] = {
            },
            [resource.types.flaxTwine.index] = {
            },
        },
        outputs = {
            [resource.types.bronzeIngot.index] = {
                constructableTypeIndex = constructable.types.bronzeIngot.index,
            },
            [resource.types.bronzeSpearHead.index] = {
                constructableTypeIndex = constructable.types.bronzeSpearHead.index,
            },
            [resource.types.bronzeAxeHead.index] = {
                constructableTypeIndex = constructable.types.bronzeAxeHead.index,
            },
            [resource.types.bronzeKnife.index] = {
                constructableTypeIndex = constructable.types.bronzeKnife.index,
            },
            [resource.types.bronzePickaxeHead.index] = {
                constructableTypeIndex = constructable.types.bronzePickaxeHead.index,
            },
            [resource.types.bronzeHammerHead.index] = {
                constructableTypeIndex = constructable.types.bronzeHammerHead.index,
            },
            [resource.types.bronzeChisel.index] = {
                constructableTypeIndex = constructable.types.bronzeChisel.index,
            },

            [resource.types.bronzePickaxe.index] = {
                constructableTypeIndex = constructable.types.bronzePickaxe.index,
            },
            [resource.types.bronzeSpear.index] = {
                constructableTypeIndex = constructable.types.bronzeSpear.index,
            },
            [resource.types.bronzeHammer.index] = {
                constructableTypeIndex = constructable.types.bronzeHammer.index,
            },
        },
        createTradeOutputsForStoredObjectTypes = {
            [gameObject.types.tinOre.index] = {
                plan = "mine",
                count = 200, 
                resourceTypeIndex = resource.types.tinOre.index,
                terrainTypes = {terrainTypes.baseTypes.tinOre.index},
            },
            [gameObject.types.copperOre.index] = {
                plan = "mine",
                count = 200, 
                resourceTypeIndex = resource.types.copperOre.index,
                terrainTypes = {terrainTypes.baseTypes.copperOre.index},
            },
        },
    },

    -- NOTE! When adding new types, you need to add industry_KEY_workerTypeName to localizations eg industry_rockTools_workerTypeName = "Rock Knappers" for display in trade relations panel
})


function industry:mjInit()
    industry.validTypes = typeMaps:createValidTypesArray("industry", industry.types)
end

return industry