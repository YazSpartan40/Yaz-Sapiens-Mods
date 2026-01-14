local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec4 = mjm.vec4

--local edgeDecal = {}

local topOffset = 0.0002
local bottomOffset = 0.0002

local nudgeToAvoidBleed = 1.0/512.0

local quarter = 0.25
local eighth = 0.125
local sixteenth = 1.0/16.0
local thirtysecond = 1.0/32.0


local edgeDecal = {}

edgeDecal.textureLocations = { -- left, bottom, right, top
    --[[leavesA = vec4(
        0.25, 
        1.0 - sixteenth, 
        0.25 + eighth * 0.4, 
        0.953125
    ),
    leavesBigger = vec4(
        0.75, 
        1.0 - eighth - thirtysecond, 
        1.0,
        1.0 - sixteenth
    ),]]
    --[[pine = vec4(
        0.25, 
        1.0 - thirtysecond,
        0.5, 
        1.0
    ),]]
    --[[grass = vec4(
        0.5, 
        1.0 - eighth,
        0.75, 
        1.0
    ),]]
    hay = vec4(
        0.5, 
        0.75,
        0.5 + eighth, 
        0.75 + sixteenth
    ),
    hayWide = vec4(
        0.5, 
        0.75,
        0.75, 
        0.75 + sixteenth
    ),
    leavesNewA = vec4(
        0.0, 
        1.0 - eighth * 3.0, 
        eighth,
        1.0 - eighth * 3.0 + sixteenth
    ),
    leavesNewB = vec4(
        0.0, 
        1.0 - eighth * 3.0 - sixteenth, 
        eighth,
        1.0 - eighth * 3.0 + sixteenth
    ),
    willowLeaf = vec4(
        0.0, 
        1.0 - eighth * 2.0, 
        eighth,
        1.0 - eighth * 2.0 + sixteenth
    ),
    --[[leavesNewC = vec4(
        quarter, 
        1.0 - eighth * 3.0, 
        quarter + eighth,
        1.0 - eighth * 3.0 + sixteenth
    ),]]
    wheatA = vec4(
        quarter + eighth, 
        1.0 - eighth * 3.0, 
        quarter + quarter,
        1.0 - eighth * 3.0 + sixteenth
    ),
    wheatB = vec4(
        quarter + eighth, 
        1.0 - eighth * 3.0 - sixteenth, 
        quarter + quarter,
        1.0 - eighth * 3.0 + sixteenth
    ),
    gingerFlowerA = vec4(
        1.0 - eighth, 
        1.0 - eighth * 3.0 + thirtysecond, 
        1.0,
        1.0 - eighth * 3.0 + sixteenth
    ),
    gingerFlowerB = vec4(
        1.0 - eighth, 
        1.0 - eighth * 3.0, 
        1.0,
        1.0 - eighth * 3.0 + sixteenth
    ),
    garlicFlowerA = vec4(
        eighth, 
        0.5 - eighth + thirtysecond, 
        eighth + sixteenth,
        0.5 - sixteenth
    ),
    garlicFlowerB = vec4(
        eighth, 
        0.5 - eighth, 
        eighth + sixteenth,
        0.5 - sixteenth
    ),
    
    pineA = vec4(
        0.0, 
        0.5 - sixteenth, 
        quarter,
        0.5
    ),
    --[[pineB = vec4(
        0.0, 
        0.5 - sixteenth, 
        quarter,
        0.5
    ),]]
    
    
    thatchA = vec4(
        quarter, 
        0.5, 
        0.5,
        0.5 + sixteenth
    ),
    thatchB = vec4(
        quarter, 
        0.5 - sixteenth, 
        0.5,
        0.5 + sixteenth
    ),
    
    
    hairA = vec4(
        0.5, 
        0.5, 
        0.75,
        0.5 + sixteenth
    ),
    hairB = vec4(
        0.5, 
        0.5 - sixteenth, 
        0.75,
        0.5 + sixteenth
    ),

    thatchEdgeA = vec4(
        quarter, 
        0.5 - eighth - thirtysecond, 
        0.5,
        0.5 - eighth
    ),
    thatchEdgeB = vec4(
        quarter, 
        0.5 - eighth - sixteenth, 
        0.5,
        0.5 - eighth - thirtysecond
    ),

    
    thatchThinA = vec4(
        0.5, 
        0.5 - eighth, 
        0.5 + eighth,
        0.5 - eighth + sixteenth
    ),
    thatchThinB = vec4(
        0.5, 
        0.5 - eighth - sixteenth, 
        0.5 + eighth,
        0.5 - eighth + sixteenth
    ),
    
    mammothA = vec4(
        0.5, 
        0.5, 
        0.75,
        0.5 + sixteenth
    ),
    mammothB = vec4(
        0.5, 
        0.5 - sixteenth, 
        0.75,
        0.5 + sixteenth
    ),
    
    mammothC = vec4(
        0.5, 
        0.5, 
        0.75,
        0.5 + sixteenth
    ),
    mammothD = vec4(
        0.5, 
        0.5 - sixteenth, 
        0.75,
        0.5 + sixteenth
    ),
    
    bananaLeafA = vec4(
        0.5, 
        1.0 - eighth * 3.0 + thirtysecond, 
        0.5 + quarter,
        1.0 - eighth * 3.0 + sixteenth
    ),
    bananaLeafB = vec4(
        0.5, 
        1.0 - eighth * 3.0, 
        0.5 + quarter,
        1.0 - eighth * 3.0 + sixteenth
    ),
    
    bananaBarkA = vec4(
        0.5, 
        1.0 - eighth * 3.0 - thirtysecond, 
        0.5 + quarter,
        1.0 - eighth * 3.0
    ),
    bananaBarkB = vec4(
        0.5, 
        1.0 - eighth * 3.0 - sixteenth, 
        0.5 + quarter,
        1.0 - eighth * 3.0
    ),

    eyelashes = vec4(
        0.5 + quarter, 
        0.5 + eighth, 
        0.5 + quarter + eighth,
        0.5 + eighth + sixteenth
    ),
    
    flaxA = vec4(
        quarter * 3.0 + nudgeToAvoidBleed, 
        0.5, 
        1.0,
        0.5 + sixteenth
    ),

    flaxB = vec4(
        quarter * 3.0 + nudgeToAvoidBleed, 
        0.5 - sixteenth, 
        1.0,
        0.5 + sixteenth
    ),
    
    leavesMarigoldA = vec4(
        0.0, 
        0.5 - eighth + thirtysecond, 
        eighth,
        0.5 - sixteenth
    ),
    leavesMarigoldB = vec4(
        0.0, 
        0.5 - eighth, 
        eighth,
        0.5 - sixteenth
    ),
    leavesEchinaceaA = vec4(
        0.0, 
        0.5 - eighth - sixteenth + thirtysecond, 
        eighth,
        0.5 - eighth
    ),
    leavesEchinaceaB = vec4(
        0.0, 
        0.5 - eighth - sixteenth, 
        eighth,
        0.5 - eighth
    ),
    leavesAloe = vec4(
        eighth, 
        0.5 - eighth - thirtysecond, 
        quarter,
        0.5 - eighth - thirtysecond + (thirtysecond / 8.0)
    ),
    flowerPetalsA = vec4(
        0.0, 
        0.5 - eighth - sixteenth - sixteenth + thirtysecond, 
        sixteenth,
        0.5 - eighth - sixteenth
    ),
    flowerPetalsB = vec4(
        0.0, 
        0.5 - eighth - sixteenth - sixteenth, 
        sixteenth,
        0.5 - eighth - sixteenth
    ),
    flowerRoundPetalsA = vec4(
        sixteenth, 
        0.5 - eighth - sixteenth - sixteenth + thirtysecond, 
        eighth,
        0.5 - eighth - sixteenth
    ),
    flowerRoundPetalsB = vec4(
        sixteenth, 
        0.5 - eighth - sixteenth - sixteenth, 
        eighth,
        0.5 - eighth - sixteenth
    ),
    poppyPetalsA = vec4(
        eighth, 
        0.5 - eighth - sixteenth - sixteenth + thirtysecond, 
        eighth + sixteenth,
        0.5 - eighth - sixteenth
    ),
    poppyPetalsB = vec4(
        eighth, 
        0.5 - eighth - sixteenth - sixteenth, 
        eighth + sixteenth,
        0.5 - eighth - sixteenth
    ),
}



--[[
    
    wheatA = vec4(
        quarter + eighth, 
        1.0 - eighth * 3.0, 
        quarter + quarter,
        1.0 - eighth * 3.0 + sixteenth
    ),
    wheatB = vec4(
        quarter + eighth, 
        1.0 - eighth * 3.0 - sixteenth, 
        quarter + quarter,
        1.0 - eighth * 3.0 + sixteenth
    ),
    ]]
for k,vec in pairs(edgeDecal.textureLocations) do
    edgeDecal.textureLocations[k] = vec4(vec.x, vec.y + bottomOffset, vec.z, vec.w - topOffset)
end

--for size with one texture location x is extruded out along the vertex normal, y is perpendicular to that, randomly towards or away from tri center
--with two textureLocations x is extruded out in each direction at roughfly 30-45 degrees, y is the distance that the decal center is placed away from the edge



edgeDecal.groupTypes = mj:indexed { 
	{
        key = "leavesA",
        textureLocations = {
            edgeDecal.textureLocations.leavesNewA,
        },
        --size = vec2(0.025, 0.1) * 0.8, 
        size = vec2(0.07 * 3.5, 0.25),
    },
	{
        key = "leavesSmaller",
        textureLocations = {
            edgeDecal.textureLocations.leavesNewA,
        },
        --size = vec2(0.025, 0.1) * 0.8, 
        size = vec2(0.07 * 0.75, 0.001),
    },
	{
        key = "leavesMarigold",
        textureLocations = {
            edgeDecal.textureLocations.leavesMarigoldA,
            edgeDecal.textureLocations.leavesMarigoldB,
        },
        --size = vec2(0.025, 0.1) * 0.8, 
        size = vec2(0.07 * 0.75, 0.001),
        discardFaces = true,
    },
	{
        key = "leavesAloe",
        textureLocations = {
            edgeDecal.textureLocations.leavesAloe,
        },
        --size = vec2(0.025, 0.1) * 0.8, 
        size = vec2(0.01, 0.01),
    },
	{
        key = "leavesEchinacea",
        textureLocations = {
            edgeDecal.textureLocations.leavesEchinaceaA,
            edgeDecal.textureLocations.leavesEchinaceaB,
        },
        --size = vec2(0.025, 0.1) * 0.8, 
        size = vec2(0.07 * 0.75, 0.001),
        discardFaces = true,
    },
	{
        key = "leavesBigger",
        textureLocations = {
            edgeDecal.textureLocations.leavesNewA,
            --edgeDecal.textureLocations.leavesNewB,
        },
        size = vec2(0.07 * 3.5, 0.25),
    },
	{
        key = "willowLeaf",
        textureLocations = {
            edgeDecal.textureLocations.willowLeaf,
            --edgeDecal.textureLocations.leavesNewB,
        },
        size = vec2(0.07 * 3.5 * 2.0, 0.25),
    },
	{
        key = "willowLeafSmall",
        textureLocations = {
            edgeDecal.textureLocations.willowLeaf,
            --edgeDecal.textureLocations.leavesNewB,
        },
        size = vec2(0.07 * 1.5, 0.25),
    },
	{
        key = "bambooLeaf",
        textureLocations = {
            edgeDecal.textureLocations.willowLeaf,
            --edgeDecal.textureLocations.leavesNewB,
        },
        size = vec2(0.07 * 3.5, 0.25),
    },
	{
        key = "bambooLeafSmall",
        textureLocations = {
            edgeDecal.textureLocations.willowLeaf,
            --edgeDecal.textureLocations.leavesNewB,
        },
        size = vec2(0.07 * 1.5, 0.25),
    },
	{
        key = "pine",
        textureLocations = {
            edgeDecal.textureLocations.pineA,
            --edgeDecal.textureLocations.pineB,
        },
        size = vec2(0.07 * 7.0, 0.5),
        --discardFaces = true,
    },
	{
        key = "pineSmall",
        textureLocations = {
            edgeDecal.textureLocations.pineA,
            --edgeDecal.textureLocations.pineB,
        },
        size = vec2(0.07 * 1.5, 0.01),
        --discardFaces = true,
    },
	{
        key = "hay",
        textureLocations = {
            edgeDecal.textureLocations.hay,
            --edgeDecal.textureLocations.hay,
        },
        size = vec2(0.1, 0.05),
    },
	{
        key = "haySmaller",
        textureLocations = {
            edgeDecal.textureLocations.hayWide,
        },
        size = vec2(0.015, 0.015),
    },
	{
        key = "wheatFlower",
        textureLocations = {
            edgeDecal.textureLocations.wheatA,
            edgeDecal.textureLocations.wheatB,
        },
        size = vec2(0.07 * 1.5, 0.01),
        discardFaces = true,
    },
	{
        key = "gingerFlower",
        textureLocations = {
            edgeDecal.textureLocations.gingerFlowerA,
            edgeDecal.textureLocations.gingerFlowerB,
        },
        size = vec2(0.07 * 0.5, 0.01),
        discardFaces = true,
    },
	{
        key = "garlicFlower",
        textureLocations = {
            edgeDecal.textureLocations.garlicFlowerA,
            edgeDecal.textureLocations.garlicFlowerB,
        },
        size = vec2(0.07 * 1.0, 0.01),
        discardFaces = true,
    },
	{
        key = "flaxFlower",
        textureLocations = {
            edgeDecal.textureLocations.flaxA,
            edgeDecal.textureLocations.flaxB,
        },
        size = vec2(0.07 * 3.0, 0.01),
        discardFaces = true,
    },
	{
        key = "flaxFlowerPicked",
        textureLocations = {
            edgeDecal.textureLocations.flaxA,
            edgeDecal.textureLocations.flaxB,
        },
        size = vec2(0.07 * 1.0, 0.01),
        discardFaces = true,
    },
	{
        key = "thatchShort",
        textureLocations = {
            edgeDecal.textureLocations.thatchA,
            edgeDecal.textureLocations.thatchB,
        },
        size = vec2(0.15, 0.0),
        discardFaces = true,
    },
	{
        key = "thatch075",
        textureLocations = {
            edgeDecal.textureLocations.thatchA,
            edgeDecal.textureLocations.thatchB,
        },
        size = vec2(0.225, 0.0),
        discardFaces = true,
    },
	{
        key = "thatch",
        textureLocations = {
            edgeDecal.textureLocations.thatchA,
            edgeDecal.textureLocations.thatchB,
        },
        size = vec2(0.25, 0.0),
        discardFaces = true,
    },
	{
        key = "thatchLonger",
        textureLocations = {
            edgeDecal.textureLocations.thatchA,
            edgeDecal.textureLocations.thatchB,
        },
        size = vec2(0.35, 0.0),
        discardFaces = true,
    },
	{
        key = "thatchLongerLonger",
        textureLocations = {
            edgeDecal.textureLocations.thatchA,
            edgeDecal.textureLocations.thatchB,
        },
        size = vec2(0.6, 0.0),
        discardFaces = true,
    },
	{
        key = "thatchEdge",
        textureLocations = {
            edgeDecal.textureLocations.thatchEdgeA,
            edgeDecal.textureLocations.thatchEdgeB,
        },
        size = vec2(0.11, 0.0),
        discardFaces = true,
    },
	{
        key = "thatchThin",
        textureLocations = {
            edgeDecal.textureLocations.thatchThinA,
            edgeDecal.textureLocations.thatchThinB,
        },
        size = vec2(0.15, 0.0),
        discardFaces = true,
    },

    
	{
        key = "mammoth",
        textureLocations = {
            edgeDecal.textureLocations.mammothC,
            edgeDecal.textureLocations.mammothD,
        },
        size = vec2(0.06, 0.01),
    },
	{
        key = "mammothEdgeOnly",
        textureLocations = {
            edgeDecal.textureLocations.mammothA,
            edgeDecal.textureLocations.mammothB,
        },
        size = vec2(0.3, 0.0),
        discardFaces = true,
    },
	{
        key = "clothes",
        textureLocations = {
            edgeDecal.textureLocations.mammothC,
           -- edgeDecal.textureLocations.mammothD,
        },
        size = vec2(0.02, 0.001),
    },
	{
        key = "hair",
        textureLocations = {
            edgeDecal.textureLocations.hairA,
        },
        size = vec2(0.006, 0.0),
    },
	{
        key = "beard",
        textureLocations = {
            edgeDecal.textureLocations.hairA,
            --edgeDecal.textureLocations.mammothD,
        },
        size = vec2(0.006, 0.001),
    },
	{
        key = "clothingFur",
        textureLocations = {
            edgeDecal.textureLocations.mammothA,
            edgeDecal.textureLocations.mammothB,
        },
        size = vec2(0.04, 0.0),
        discardFaces = true,
    },
	{
        key = "clothingFurShort",
        textureLocations = {
            edgeDecal.textureLocations.mammothA,
            edgeDecal.textureLocations.mammothB,
        },
        size = vec2(0.02, 0.0),
        discardFaces = true,
    },
	{
        key = "eyebrows",
        textureLocations = {
            edgeDecal.textureLocations.hairA,
           -- edgeDecal.textureLocations.mammothD,
        },
        size = vec2(0.003, 0.001),
    },
	{
        key = "eyelashes",
        textureLocations = {
            edgeDecal.textureLocations.eyelashes,
            edgeDecal.textureLocations.eyelashes,
        },
        size = vec2(0.001, 0.001),
    },
	{
        key = "eyelashesLong",
        textureLocations = {
            edgeDecal.textureLocations.eyelashes,
            edgeDecal.textureLocations.eyelashes,
        },
        size = vec2(0.002, 0.001),
    },
	{
        key = "bananaLeaf",
        textureLocations = {
            edgeDecal.textureLocations.bananaLeafA,
            --edgeDecal.textureLocations.bananaLeafB,
        },
        size = vec2(0.2, 0.0),
    },
	{
        key = "bananaBark",
        textureLocations = {
            edgeDecal.textureLocations.bananaBarkA,
            --edgeDecal.textureLocations.bananaLeafB,
        },
        size = vec2(0.08, 0.0),
    },
	{
        key = "bananaLeafSmall",
        textureLocations = {
            edgeDecal.textureLocations.bananaLeafA,
            --edgeDecal.textureLocations.bananaLeafB,
        },
        size = vec2(0.05, 0.0),
    },

	{
        key = "flaxTwine",
        textureLocations = {
            edgeDecal.textureLocations.bananaBarkA,
        },
        size = vec2(0.02, 0.001),
    },
    

	{
        key = "echinaceaPetals",
        textureLocations = {
            edgeDecal.textureLocations.flowerPetalsA,
            edgeDecal.textureLocations.flowerPetalsB,
        },
        size = vec2(0.08, 0.001),
        discardFaces = true,
    },
	{
        key = "sunflowerPetals",
        textureLocations = {
            edgeDecal.textureLocations.flowerRoundPetalsA,
            edgeDecal.textureLocations.flowerRoundPetalsB,
        },
        size = vec2(0.16, 0.001),
        discardFaces = true,
    },
	{
        key = "marigoldPetals",
        textureLocations = {
            edgeDecal.textureLocations.flowerRoundPetalsA,
            edgeDecal.textureLocations.flowerRoundPetalsB,
        },
        size = vec2(0.05, 0.001),
        discardFaces = true,
    },
	{
        key = "poppyPetals",
        textureLocations = {
            edgeDecal.textureLocations.poppyPetalsA,
            edgeDecal.textureLocations.poppyPetalsB,
        },
        size = vec2(0.05, 0.001),
        discardFaces = true,
    },

    
}

function edgeDecal:groupOfType(groupTypeIndex)
    return edgeDecal.groupTypes[groupTypeIndex]
end

return edgeDecal