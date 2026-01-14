local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local material = mjrequire "common/material"
local typeMaps = mjrequire "common/typeMaps"

local terrainDecal = {}

local topOffset = 0.008

local quantityMultiplier = 1.0
local sizeMultiplier = 1.2
local sizeVariationMin = 1.0
local sizeVariationMax = 2.0

local eighth = 1.0/8.0
local sixteenth = 1.0/16.0
local thirtysecond = 1.0/32.0

terrainDecal.sprites = mj:indexed {
    {
        key = "grassA",
        textureLocation = vec4(0.0,0.875 + topOffset,0.5, 1.0 - topOffset), --left, bot, right, top
        size = vec2(0.8, 0.2) * sizeMultiplier,
    },
    {
        key = "grassB",
        textureLocation = vec4(0.5,0.875 + topOffset,1.0, 1.0 - topOffset),
        size = vec2(0.8, 0.2) * sizeMultiplier,
    },

    {
        key = "tallLittleFlowers", --carrot family
        textureLocation = vec4(0.0,0.625 + topOffset,0.125, 0.875 - topOffset),
        size = vec2(0.2, 0.4) * sizeMultiplier,
        matA = material.types.pine.index,
    },
    {
        key = "legume",
        textureLocation = vec4(0.125,0.625 + topOffset,0.25, 0.875 - topOffset),
        size = vec2(0.2, 0.4) * sizeMultiplier,
    },
    {
        key = "flowerA",
        textureLocation = vec4(0.5+eighth,0.75 + topOffset,0.5+eighth+thirtysecond, 0.875 - topOffset),
        size = vec2(0.05, 0.2) * sizeMultiplier,
    },
    {
        key = "lupin",
        textureLocation = vec4(0.5+sixteenth,0.75 + topOffset,0.5+eighth, 0.875 - topOffset),
        size = vec2(0.14, 0.3) * sizeMultiplier,
        matA = material.types.leafyBushA.index,
        matB = material.types.pinkFlower.index,
        matC = material.types.blueFlower.index,
    },
    {
        key = "meadowGrass",
        textureLocation = vec4(0.25,0.75 + topOffset,0.5, 0.75 + eighth - topOffset),
        size = vec2(0.6, 0.4) * sizeMultiplier,
        matB = material.types.new_grassSeedHeads.index,
        matC = material.types.new_grassSeedHeads.index,
    },
    {
        key = "hardGrassWithSeedHeads",
        textureLocation = vec4(0.25,0.5 + eighth + topOffset,0.5, 0.75 - topOffset),
        size = vec2(0.6, 0.4) * sizeMultiplier,
        matB = material.types.new_grassSeedHeads.index,
        matC = material.types.new_grassSeedHeads.index,
    },
    {
        key = "poppy",
        textureLocation = vec4(0.5,0.75 + topOffset,0.5+sixteenth, 0.875 - topOffset),
        size = vec2(0.4, 0.8) * sizeMultiplier * 0.5,
    },
    {
        key = "dirt1",
        textureLocation = vec4(0.0,0.5 + topOffset,0.125, 0.5625 - topOffset),
        size = vec2(0.1, 0.05) * sizeMultiplier,
    },
    {
        key = "dirt2",
        textureLocation = vec4(0.125,0.5 + topOffset,0.25, 0.5625 - topOffset),
        size = vec2(0.1, 0.05) * sizeMultiplier,
    },
    {
        key = "dirt3",
        textureLocation = vec4(0.25,0.5 + topOffset,0.25 + 0.125, 0.5625 - topOffset),
        size = vec2(0.1, 0.05) * sizeMultiplier,
    },
    {
        key = "grassSnow",
        textureLocation = vec4(0.5,0.5 + eighth + topOffset,1.0, 0.75 - topOffset),
        size = vec2(0.4, 0.1) * sizeMultiplier,
    },
    {
        key = "grassSnowB",
        textureLocation = vec4(0.5,0.5 + topOffset,1.0, 0.5 + eighth - topOffset),
        size = vec2(0.4, 0.1) * sizeMultiplier,
    },
    {
        key = "fern",
        textureLocation = vec4(0.0,0.25 + topOffset,0.25, 0.5 - topOffset), --fern
        size = vec2(0.6, 0.6) * sizeMultiplier,
    },
    
    {
        key = "coral1",
        textureLocation = vec4(0.25,0.5 - eighth + topOffset,0.25 + sixteenth, 0.5 - sixteenth - topOffset),
        size = vec2(0.4, 0.3) * sizeMultiplier,
        sizeVariationMin = 0.5,
    },
    {
        key = "coral2",
        textureLocation = vec4(0.25 + sixteenth,0.5 - eighth + topOffset,0.25 + eighth, 0.5 - sixteenth - topOffset),
        size = vec2(0.4, 0.3) * sizeMultiplier,
        sizeVariationMin = 0.5,
    },
    
    {
        key = "seaweed1",
        textureLocation = vec4(0.25 + eighth,0.5 - eighth + topOffset,0.5, 0.5 + eighth - topOffset),
        size = vec2(0.25, 0.4) * sizeMultiplier,
    },
    {
        key = "seaweed2",
        textureLocation = vec4(0.5,0.25 + topOffset,0.5 + eighth, 0.5 - topOffset),
        size = vec2(0.25, 0.4) * sizeMultiplier,
    },
}

local function makeDenseGrassInstances(grassTopsMaterial, additionalInstancesOrNil)
    local result = {
        {
            spriteTypeIndex = terrainDecal.sprites.grassA.index,
            matA = grassTopsMaterial,
            matB = material.types.blueFlower.index,
            matC = material.types.blueFlower.index,
            min = -20,
            max = 60 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.grassB.index,
            matA = grassTopsMaterial,
            matB = material.types.blueFlower.index,
            matC = material.types.blueFlower.index,
            min = -20,
            max = 60 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
            matA = material.types.temperateGrassRichTops.index,
            matB = material.types.blueFlower.index,
            matC = material.types.blueFlower.index,
            min = -20,
            max = 20 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.flowerA.index,
            matA = material.types.dryGrass.index,
            matB = material.types.whiteFlower.index,
            matC = material.types.whiteFlower.index,
            min = -10,
            max = 6 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.poppy.index,
            matA = material.types.temperateGrassRichTops.index,
            matB = material.types.yellowFlower.index,
            matC = material.types.whiteFlower.index,
            sizeVariationMin = 0.8,
            sizeVariationMax = 1.2,
            min = -20,
            max = 2 * quantityMultiplier
        },
    }

    if additionalInstancesOrNil then
        for i,v in ipairs(additionalInstancesOrNil) do
            table.insert(result, v)
        end
    end

    return result
end

local function makeGrassInstances(grassTopsMaterial, grassTopsMaterialB)
    return {
        {
            spriteTypeIndex = terrainDecal.sprites.grassA.index,
            matA = grassTopsMaterial,
            matB = material.types.blueFlower.index,
            matC = material.types.whiteFlower.index,
            min = -20,
            max = 100 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.grassB.index,
            matA = grassTopsMaterial,
            matB = material.types.blueFlower.index,
            matC = material.types.whiteFlower.index,
            min = -20,
            max = 100 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.flowerA.index,
            matA = material.types.dryGrass.index,
            matB = material.types.whiteFlower.index,
            matC = material.types.whiteFlower.index,
            min = -10,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
        {
            spriteTypeIndex = terrainDecal.sprites.lupin.index,
            min = -200,
            max = 4 * quantityMultiplier
        },
    }
end

terrainDecal.groupTypes = typeMaps:createMap("terrainDecalGroup", {
    {
        key = "grass",
        instances = makeGrassInstances(material.types.temperateGrassTops.index, material.types.temperateGrassTopsB.index)
    },
    {
        key = "grassWinter",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.temperateGrassWinterTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 80 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.temperateGrassWinterTopsB.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 80 * quantityMultiplier
            },
        }
    },
    {
        key = "grassSnow",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassSnow.index,
                --[[matA = material.types.snowGrass.index,
                matB = material.types.temperateGrassTops.index,
                matC = material.types.whiteFlower.index,]]
                
                matA = material.types.darkGrassPokingThroughSnow.index,
                matB = material.types.temperateGrassWinter.index,
                matC = material.types.temperateGrassWinter.index,
                min = -10,
                max = 5 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassSnowB.index,
                matA = material.types.darkGrassPokingThroughSnow.index,
                matB = material.types.temperateGrassWinter.index,
                matC = material.types.temperateGrassWinter.index,
                min = -10,
                max = 5 * quantityMultiplier
            },
            --[[{
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.pine.index,
                matB = material.types.pine.index,
                matC = material.types.mediterraneanGrassTops.index,
                min = -40,
                max = 5 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.hardGrassWithSeedHeads.index,
                matA = material.types.pine.index,
                matB = material.types.pine.index,
                matC = material.types.mediterraneanGrassTops.index,
                min = -40,
                max = 5 * quantityMultiplier
            },]]
        }
    },

    {
        key = "grassDense",
        instances = makeDenseGrassInstances(material.types.temperateGrassRichTops.index)
    },
    {
        key = "tropicalGrassDense",
        instances = makeDenseGrassInstances(material.types.tropicalRainforestGrassRichTops.index, {
            {
                spriteTypeIndex = terrainDecal.sprites.fern.index,
                matA = material.types.pine.index,
                matB = material.types.darkPlantStalks.index,
                matC = material.types.darkPlantStalks.index,
                min = -20,
                max = 30 * quantityMultiplier
            },
        })
    },
    {
        key = "tropicalGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.tropicalRainforestGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.tropicalRainforestGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.fern.index,
                matA = material.types.pine.index,
                matB = material.types.darkPlantStalks.index,
                matC = material.types.darkPlantStalks.index,
                min = -20,
                max = 5 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.legume.index,
                matA = material.types.tropicalRainforestTallGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 5 * quantityMultiplier
            },
        }
    },
    
    {
        key = "mediterraneanGrassPlentiful",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.mediterraneanGrassTopsPlentiful.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 40 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.mediterraneanGrassTopsPlentiful.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 40 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.lightOrangeFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.flowerA.index,
                matA = material.types.dryGrass.index,
                matB = material.types.whiteFlower.index,
                matC = material.types.whiteFlower.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.lupin.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.lupin.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.lupin.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.mediterraneanGrassTopsPlentiful.index,
                sizeVariationMax = sizeVariationMax,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.hardGrassWithSeedHeads.index,
                matA = material.types.mediterraneanGrassTopsPlentiful.index,
                sizeVariationMax = sizeVariationMax,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.poppy.index,
                matA = material.types.darkGrassTops.index,
                matB = material.types.yellowFlower.index,
                matC = material.types.whiteFlower.index,
                sizeVariationMin = 0.8,
                sizeVariationMax = 1.2,
                min = -20,
                max = 4 * quantityMultiplier
            },
        }
    },

    {
        key = "mediterraneanGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.mediterraneanGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.mediterraneanGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.lightOrangeFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 5 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.flowerA.index,
                matA = material.types.dryGrass.index,
                matB = material.types.whiteFlower.index,
                matC = material.types.whiteFlower.index,
                min = -10,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.mediterraneanGrassTops.index,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.hardGrassWithSeedHeads.index,
                matA = material.types.mediterraneanGrassTops.index,
                sizeVariationMin = sizeVariationMin * 0.5,
                sizeVariationMax = sizeVariationMax,
                min = -20,
                max = 10 * quantityMultiplier
            },
        }
    },

    
    {
        key = "savannaGrassPlentiful",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.savannaGrassTopsPlentiful.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.savannaGrassTopsPlentiful.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.lightOrangeFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.flowerA.index,
                matA = material.types.dryGrass.index,
                matB = material.types.whiteFlower.index,
                matC = material.types.whiteFlower.index,
                min = -10,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.lupin.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.lupin.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.lupin.index,
                min = -200,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.savannaGrassTopsPlentiful.index,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.hardGrassWithSeedHeads.index,
                matA = material.types.savannaGrassTopsPlentiful.index,
                sizeVariationMin = sizeVariationMin * 0.5,
                sizeVariationMax = sizeVariationMax,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.poppy.index,
                matA = material.types.darkGrassTops.index,
                matB = material.types.yellowFlower.index,
                matC = material.types.whiteFlower.index,
                sizeVariationMin = 0.8,
                sizeVariationMax = 1.2,
                min = -20,
                max = 4 * quantityMultiplier
            },
        }
    },

    {
        key = "savannaGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.savannaGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.savannaGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 60 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.lightOrangeFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 5 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.flowerA.index,
                matA = material.types.dryGrass.index,
                matB = material.types.whiteFlower.index,
                matC = material.types.whiteFlower.index,
                min = -10,
                max = 4 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.savannaGrassTops.index,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.hardGrassWithSeedHeads.index,
                matA = material.types.savannaGrassTops.index,
                sizeVariationMin = sizeVariationMin * 0.5,
                sizeVariationMax = sizeVariationMax,
                min = -20,
                max = 10 * quantityMultiplier
            },
        }
    },

    {
        key = "gravelGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.poppy.index,
                matA = material.types.temperateGrassTops.index,
                matB = material.types.yellowFlower.index,
                matC = material.types.whiteFlower.index,
                sizeVariationMin = 0.8,
                sizeVariationMax = 1.2,
                min = -1000,
                max = 10 * quantityMultiplier
            },
        }
    },
    {
        key = "desertGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.yellowFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 4 * quantityMultiplier
            },
        }
    },
    {
        key = "dirtGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.dirt1.index,
                matA = material.types.dirtGrass.index,
                matB = material.types.dryGrass.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.dirt3.index,
                matA = material.types.dirtGrass.index,
                matB = material.types.dryGrass.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 20 * quantityMultiplier
            },
        }
    },
    {
        key = "steppeGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.steppeGrassTops.index,
                min = -5,
                max = 20 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassA.index,
                matA = material.types.steppeGrassTops.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 50 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.grassB.index,
                matA = material.types.steppeGrassTopsB.index,
                matB = material.types.blueFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 50 * quantityMultiplier
            },
        }
    },
    {
        key = "tundraGrass",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.tallLittleFlowers.index,
                matB = material.types.whiteFlower.index,
                matC = material.types.whiteFlower.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.meadowGrass.index,
                matA = material.types.yellowGrassTops.index,
                min = -5,
                max = 20 * quantityMultiplier
            },
        }
    },
    {
        key = "oceanGravel",
        instances = {
            {
                spriteTypeIndex = terrainDecal.sprites.coral1.index,
                belowWater = true,
                matA = material.types.coralRed.index,
                matB = material.types.coralRed.index,
                matC = material.types.coralRed.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.coral2.index,
                belowWater = true,
                matA = material.types.coralBlue.index,
                matB = material.types.coralBlue.index,
                matC = material.types.coralBlue.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.seaweed1.index,
                belowWater = true,
                matA = material.types.seaweed1.index,
                matB = material.types.seaweed1.index,
                matC = material.types.seaweed1.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
            {
                spriteTypeIndex = terrainDecal.sprites.seaweed2.index,
                belowWater = true,
                matA = material.types.seaweed2.index,
                matB = material.types.seaweed2.index,
                matC = material.types.seaweed2.index,
                min = -20,
                max = 10 * quantityMultiplier
            },
        }
    },
})

function terrainDecal:mjInit()
    terrainDecal.groupTypesArray = typeMaps:createValidTypesArray("terrainDecalGroup", terrainDecal.groupTypes)

    for i,decalGroupType in ipairs(terrainDecal.groupTypesArray) do
        for j,decalInstance in ipairs(decalGroupType.instances) do
            local sprite = decalInstance.spriteTypeIndex and terrainDecal.sprites[decalInstance.spriteTypeIndex]
            if sprite then
                decalInstance.textureLocation = decalInstance.textureLocation or sprite.textureLocation
                decalInstance.size = decalInstance.size or sprite.size

                decalInstance.matA = decalInstance.matA or sprite.matA
                decalInstance.matB = decalInstance.matB or sprite.matB
                decalInstance.matC = decalInstance.matC or sprite.matC
                decalInstance.sizeVariationMin = decalInstance.sizeVariationMin or sprite.sizeVariationMin
                decalInstance.sizeVariationMax = decalInstance.sizeVariationMax or sprite.sizeVariationMax
            end
    
            if not decalInstance.sizeVariationMin then
                decalInstance.sizeVariationMin = sizeVariationMin
                decalInstance.sizeVariationMax = sizeVariationMax
            end
            
            if not decalInstance.sizeVariationMax then
                decalInstance.sizeVariationMax = sizeVariationMax
            end
        end
    end
end

return terrainDecal