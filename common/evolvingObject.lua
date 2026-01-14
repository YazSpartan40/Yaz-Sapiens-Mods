
local material = mjrequire "common/material"
local gameObject = mjrequire "common/gameObject"
local locale = mjrequire "common/locale"

local evolvingObject = {}

local dayLength = nil
local yearLength = nil

local rottenItemTimeDays = 2.0

evolvingObject.coveredDurationMultiplier = 4.0

evolvingObject.categories = mj:indexed {
    {
        key = "dry",
        actionName = locale:get("evolution_dryAction"),
        color = material:getUIColor(material.types.ui_yellowBright.index),
        material = material.types.ui_yellowBright.index,
        storageCoveredPriority = "uncovered",
    },
    {
        key = "rot",
        actionName = locale:get("evolution_rotAction"),
        color = material:getUIColor(material.types.ui_redBright.index),
        material = material.types.ui_redBright.index,
        storageCoveredPriority = "covered",
    },
    {
        key = "despawn",
        actionName = locale:get("evolution_despawnAction"),
        color = material:getUIColor(material.types.ui_redDark.index),
        material = material.types.ui_redDark.index,
        storageCoveredPriority = "covered",
    },
}

function evolvingObject:createFromTypesByToTypes()
    evolvingObject.fromTypesByToTypes = {}

    for fromType,evolutionInfo in pairs(evolvingObject.evolutions) do
        if evolutionInfo.toType then
            local fromTypes = evolvingObject.fromTypesByToTypes[evolutionInfo.toType]
            if not fromTypes then
                fromTypes = {}
                evolvingObject.fromTypesByToTypes[evolutionInfo.toType] = fromTypes
            end
            fromTypes[fromType] = true
        end
    end
end

function evolvingObject:init(dayLength_, yearLength_)
    dayLength = dayLength_
    yearLength = yearLength_
    evolvingObject.evolutions = {
        [gameObject.types.grass.index] = {
            minTime = 120.0,
            toType = gameObject.types.hay.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.flax.index] = {
            minTime = 240.0,
            toType = gameObject.types.flaxDried.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.unfiredUrnWet.index] = {
            minTime = 240.0,
            toType = gameObject.types.unfiredUrnDry.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.unfiredBowlWet.index] = {
            minTime = 240.0,
            toType = gameObject.types.unfiredBowlDry.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.crucibleWet.index] = {
            minTime = 240.0,
            toType = gameObject.types.crucibleDry.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },

        [gameObject.types.unfiredBowlInjuryMedicine.index] = {
            minTime = dayLength * 2.0,
            toType = gameObject.types.unfiredBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.unfiredBowlBurnMedicine.index] = {
            minTime = dayLength * 2.0,
            toType = gameObject.types.unfiredBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.unfiredBowlFoodPoisoningMedicine.index] = {
            minTime = dayLength * 2.0,
            toType = gameObject.types.unfiredBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.unfiredBowlVirusMedicine.index] = {
            minTime = dayLength * 2.0,
            toType = gameObject.types.unfiredBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },

        [gameObject.types.firedBowlInjuryMedicine.index] = {
            minTime = yearLength * 2,
            toType = gameObject.types.firedBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.firedBowlBurnMedicine.index] = {
            minTime = yearLength * 2,
            toType = gameObject.types.firedBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.firedBowlFoodPoisoningMedicine.index] = {
            minTime = yearLength * 2,
            toType = gameObject.types.firedBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.firedBowlVirusMedicine.index] = {
            minTime = yearLength * 2,
            toType = gameObject.types.firedBowlMedicineRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },

        [gameObject.types.unfiredBowlMedicineRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.unfiredBowlDry.index,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.firedBowlMedicineRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.firedBowl.index,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        

        [gameObject.types.unfiredUrnHulledWheat.index] = {
            minTime = dayLength * 4.0,
            toType = gameObject.types.unfiredUrnHulledWheatRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.unfiredUrnHulledWheatRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.unfiredUrnDry.index,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.unfiredUrnFlour.index] = {
            minTime = dayLength * 4.0,
            toType = gameObject.types.unfiredUrnFlourRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.unfiredUrnFlourRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.unfiredUrnDry.index,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.firedUrnHulledWheat.index] = {
            minTime = yearLength * 2.0,
            toType = gameObject.types.firedUrnHulledWheatRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.firedUrnHulledWheatRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.unfiredUrnDry.index,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.firedUrnFlour.index] = {
            minTime = yearLength * 2.0,
            toType = gameObject.types.firedUrnFlourRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.firedUrnFlourRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.firedUrn.index,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.mudBrickWet_sand.index] = {
            minTime = 240.0,
            toType = gameObject.types.mudBrickDry_sand.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.mudBrickWet_riverSand.index] = {
            minTime = 240.0,
            toType = gameObject.types.mudBrickDry_riverSand.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.mudBrickWet_redSand.index] = {
            minTime = 240.0,
            toType = gameObject.types.mudBrickDry_redSand.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.mudBrickWet_hay.index] = {
            minTime = 240.0,
            toType = gameObject.types.mudBrickDry_hay.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.mudTileWet.index] = {
            minTime = 240.0,
            toType = gameObject.types.mudTileDry.index,
            categoryIndex = evolvingObject.categories.dry.index,
        },
        [gameObject.types.hay.index] = {
            minTime = yearLength,
            toType = gameObject.types.hayRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.hayRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.apple.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.appleRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.appleRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.elderberry.index] = {
            minTime = yearLength,
            toType = gameObject.types.elderberryRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.elderberryRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.banana.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bananaRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.bananaRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.coconut.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.coconutRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.coconutRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.orange.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.orangeRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.orangeRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.peach.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.peachRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.peachRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.beetroot.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.beetrootRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.beetrootRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.gingerRoot.index] = {
            minTime = yearLength,
            toType = gameObject.types.gingerRootRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.gingerRootRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.turmericRoot.index] = {
            minTime = yearLength,
            toType = gameObject.types.turmericRootRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.turmericRootRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.garlic.index] = {
            minTime = yearLength,
            toType = gameObject.types.garlicRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.garlicRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.beetrootSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.beetrootSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.beetrootSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.wheat.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.wheatRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.wheatRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.poppyFlower.index] = {
            minTime = yearLength,
            toType = gameObject.types.poppyFlowerRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.poppyFlowerRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.echinaceaFlower.index] = {
            minTime = yearLength,
            toType = gameObject.types.echinaceaFlowerRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.echinaceaFlowerRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.marigoldFlower.index] = {
            minTime = yearLength,
            toType = gameObject.types.marigoldFlowerRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.marigoldFlowerRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.aloeLeaf.index] = {
            minTime = yearLength,
            toType = gameObject.types.aloeLeafRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.aloeLeafRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        
        [gameObject.types.breadDough.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.breadDoughRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.breadDoughRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        
        [gameObject.types.manure.index] = {
            minTime = yearLength,
            toType = gameObject.types.manureRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.manureRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        
        [gameObject.types.compost.index] = {
            minTime = yearLength,
            toType = gameObject.types.compostRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.compostRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        
        [gameObject.types.rottenGoo.index] = {
            minTime = dayLength,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.flatbread.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.flatbreadRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.flatbreadRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.sunflowerSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.sunflowerSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.sunflowerSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.flaxSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.flaxSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.flaxSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.flaxDried.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.flaxRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.flaxRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.raspberry.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.raspberryRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.raspberryRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.gooseberry.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.gooseberryRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.gooseberryRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.pumpkin.index] = {
            minTime = yearLength,
            toType = gameObject.types.pumpkinRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.pumpkinRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.pineCone.index] = {
            minTime = yearLength,
            toType = gameObject.types.pineConeRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.pineConeBig.index] = {
            minTime = yearLength * 4.0,
            toType = gameObject.types.pineConeBigRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.pineConeRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.pineConeBigRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.birchSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.birchSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.birchSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.aspenSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.aspenSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.aspenSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.aspenBigSeed.index] = {
            minTime = yearLength * 4.0,
            toType = gameObject.types.aspenBigSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.aspenBigSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.bambooSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.bambooSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.bambooSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.willowSeed.index] = {
            minTime = yearLength,
            toType = gameObject.types.willowSeedRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.willowSeedRotten.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },

        [gameObject.types.deadChicken.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.chickenMeat.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.chickenMeatCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.chickenMeatBreast.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.chickenMeatBreastCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            categoryIndex = evolvingObject.categories.despawn.index,
        },
        [gameObject.types.pumpkinCooked.index] = {
            minTime = yearLength,
            toType = gameObject.types.pumpkinRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.beetrootCooked.index] = {
            minTime = yearLength,
            toType = gameObject.types.beetrootRotten.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.alpacaMeatLeg.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.alpacaMeatRack.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toTypes = {
                gameObject.types.bone.index,
                gameObject.types.bone.index,
            },
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.alpacaMeatLegCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.alpacaMeatRackCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toTypes = {
                gameObject.types.bone.index,
                gameObject.types.bone.index,
            },
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.mammothMeat.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.mammothMeatTBone.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.mammothMeatCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.mammothMeatTBoneCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.bone.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.catfishDead.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.catfishCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.coelacanthDead.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.coelacanthCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.flagellipinnaDead.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.flagellipinnaCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.polypterusDead.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.polypterusCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.redfishDead.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.redfishCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.tropicalfishDead.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.tropicalfishCooked.index] = {
            minTime = dayLength * rottenItemTimeDays,
            toType = gameObject.types.fishBones.index,
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.deadAlpaca.index] = {
            minTime = yearLength,
            toTypes = {
                gameObject.types.bone.index,
                gameObject.types.alpacaWoolskin.index,
                gameObject.types.alpacaWoolskin.index,
            },
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.deadAlpaca_white.index] = {
            minTime = yearLength,
            toTypes = {
                gameObject.types.bone.index,
                gameObject.types.alpacaWoolskin_white.index,
                gameObject.types.alpacaWoolskin_white.index,
            },
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.deadMammoth.index] = {
            minTime = yearLength,
            toTypes = {
                gameObject.types.bone.index,
                gameObject.types.bone.index,
                gameObject.types.mammothWoolskin.index,
                gameObject.types.mammothWoolskin.index,
                gameObject.types.mammothWoolskin.index,
            },
            categoryIndex = evolvingObject.categories.rot.index,
        },
        [gameObject.types.swordfishDead.index] = {
            minTime = yearLength,
            toTypes = {
                gameObject.types.fishBones.index,
                gameObject.types.fishBones.index,
                gameObject.types.fishBones.index,
            },
            categoryIndex = evolvingObject.categories.rot.index,
        },
        --[[[gameObject.types.birchBranch.index] = {
            minTime = yearLength * 4.0,
            toType = gameObject.types.branchRotten.index,
            actionName = locale:get("evolution_rotAction")
        },
        [gameObject.types.aspenBranch.index] = {
            minTime = yearLength * 4.0,
            toType = gameObject.types.branchRotten.index,
            actionName = locale:get("evolution_rotAction")
        },
        [gameObject.types.pineBranch.index] = {
            minTime = yearLength * 4.0,
            toType = gameObject.types.branchRotten.index,
            actionName = locale:get("evolution_rotAction")
        },
        [gameObject.types.burntBranch.index] = {
            minTime = yearLength * 4.0,
            toType = gameObject.types.branchRotten.index,
            actionName = locale:get("evolution_rotAction")
        },
        [gameObject.types.branchRotten.index] = {
            minTime = dayLength,
            actionName = locale:get("evolution_despawnAction")
        },]]
    }

    local yearLengthHours = yearLength / dayLength * 24
    evolvingObject.descriptionThresholdsHours = {
        {
            time = 6,
            name = locale:get("evolution_time_verySoon")
        },
        {
            time = 36,
            name = locale:get("evolution_time_fewHours")
        },
        {
            time = yearLengthHours,
            name = locale:get("evolution_time_fewDays")
        },
        {
            time = yearLengthHours * 2,
            name = locale:get("evolution_time_nextYear")
        },
        {
            time = yearLengthHours * 100,
            name = locale:get("evolution_time_fewYears")
        },
    }

    evolvingObject:loadDerivedEvolutions()
    evolvingObject:createFromTypesByToTypes()
end


function evolvingObject:getEvolutionBucket(degradeDuration)
    local hours = degradeDuration / dayLength * 24
   -- mj:log("evolvingObject:getEvolutionBucket degradeDuration:", degradeDuration, " hours:", hours, " yearLengthHours:", yearLength / dayLength * 24)
    for i,bucketThreshold in ipairs(evolvingObject.descriptionThresholdsHours) do
        if hours < bucketThreshold.time then
            return i
        end
    end
    return #evolvingObject.descriptionThresholdsHours
end


function evolvingObject:getEvolutionDuration(objectTypeIndex, fractionDegraded, degradeReferenceTime, worldTime, covered)
    local evolution = evolvingObject.evolutions[objectTypeIndex]
    if evolution then
        local evolutionLength = evolution.minTime
        if covered then
            evolutionLength = evolutionLength * evolvingObject.coveredDurationMultiplier
        end
        
        local timeRemaining = (1.0 - (fractionDegraded or 0.0)) * evolutionLength
        local evolveTime = (degradeReferenceTime or worldTime) + timeRemaining
        local durationSeconds = evolveTime - worldTime
        return durationSeconds
    end
    return nil
end

function evolvingObject:loadDerivedEvolutions()
    local placedEvolutions = {}
    for gameObjectTypeIndex, evolution in pairs(evolvingObject.evolutions) do
        local baseGameObjectType = gameObject.types[gameObjectTypeIndex]
        if baseGameObjectType.resourceTypeIndex then
            local placedKey = "placed_" .. baseGameObjectType.key

            local placedEvolution = mj:cloneTable(evolution)
            if placedEvolution.toType then
                local evolvedPlacedKey = "placed_" .. gameObject.types[evolution.toType].key
                placedEvolution.toType = gameObject.types[evolvedPlacedKey].index
            elseif placedEvolution.toTypes then
                local newToTypes = {}
                for i,toType in ipairs(placedEvolution.toTypes) do
                    local evolvedPlacedKey = "placed_" .. gameObject.types[toType].key
                    table.insert(newToTypes, gameObject.types[evolvedPlacedKey].index)
                end
                placedEvolution.toTypes = newToTypes
            end
            placedEvolutions[gameObject.types[placedKey].index] = placedEvolution
            placedEvolution.delayUntilUsable = true
        end
    end

    for k,v in pairs(placedEvolutions) do
        evolvingObject.evolutions[k] = v
    end

    --mj:log(evolvingObject.evolutions)
end

function evolvingObject:getName(objectTypeIndex, evolutionBucket)
    if evolutionBucket == 1 then
        local evolution = evolvingObject.evolutions[objectTypeIndex]
        if evolution.delayUntilUsable then
            return locale:get("evolution_time_whenUsable")
        end
    end

    if not (evolvingObject.descriptionThresholdsHours and evolvingObject.descriptionThresholdsHours[evolutionBucket]) then
        return ""
    end
    
    return evolvingObject.descriptionThresholdsHours[evolutionBucket].name
end


return evolvingObject