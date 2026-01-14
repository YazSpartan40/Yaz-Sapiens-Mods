local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2


local modManager = mjrequire "common/modManager"

local debugLowDetail = false

local model = { 
	clones = {}
}

local modelsWithoutVolume = {
	"grass3",
	"grass4",
	"grass5",
	"grassNew1",
}

local pineHeight = 15.0
local pineBigHeight = 30.0
local birchHeight = 7.0
local appleHeight = 5.0

local function getStrength(base,height)
	return 1.0 - ((1.0 - base) / height)
end

local windStrengthsBase = { -- vec2(main object triangles, decals)
	appleTree = vec2(getStrength(0.9,appleHeight), 0.8),
	appleTreeWinter = vec2(getStrength(0.99,appleHeight), 0.8),
	appleHangingFruit = vec2(getStrength(0.9,appleHeight), 0.8),
	appleHangingFruitWinter = vec2(getStrength(0.99,appleHeight), 0.8),
	appleTreeSapling = vec2(0.95, 0.8),
	appleTreeSaplingWinter = vec2(0.99, 0.8),
	elderberryTree = vec2(getStrength(0.9,appleHeight), 0.8),
	elderberryTreeWinter = vec2(getStrength(0.99,appleHeight), 0.8),
	elderberryHangingFruit = vec2(getStrength(0.9,appleHeight), 0.8),
	elderberryHangingFruitWinter = vec2(getStrength(0.99,appleHeight), 0.8),
	elderberryTreeSapling = vec2(0.95, 0.8),
	elderberryTreeSaplingWinter = vec2(0.99, 0.8),
	orangeHangingFruit = vec2(getStrength(0.9,appleHeight), 0.8),
	orangeTree = vec2(getStrength(0.9,appleHeight), 0.8),
	orangeTreeSapling = vec2(0.95, 0.8),
	peachHangingFruit = vec2(getStrength(0.9,appleHeight), 0.8),
	peachHangingFruitWinter = vec2(getStrength(0.99,appleHeight), 0.8),
	peachTree = vec2(getStrength(0.9,appleHeight), 0.8),
	peachTreeWinter = vec2(getStrength(0.99,appleHeight), 0.8),
	peachTreeSapling = vec2(0.95, 0.8),
	peachTreeSaplingWinter = vec2(0.99, 0.8),
	aspen1 = vec2(getStrength(0.95,pineBigHeight), 0.9),
	aspen2 = vec2(getStrength(0.95,pineBigHeight), 0.9),
	aspen3 = vec2(getStrength(0.98,pineBigHeight), 0.95),
	aspen1Winter = vec2(getStrength(0.99,pineBigHeight), 0.9),
	aspen2Winter = vec2(getStrength(0.99,pineBigHeight), 0.9),
	aspen3Winter = vec2(getStrength(0.995,pineBigHeight), 0.95),
	aspenSapling = vec2(0.95, 0.8),
	aspenSaplingWinter = vec2(0.99, 0.9),
	birch1 = vec2(getStrength(0.95,birchHeight),0.8),
	birch2 = vec2(getStrength(0.95,birchHeight),0.8),
	birch3 = vec2(getStrength(0.95,birchHeight),0.8),
	birch4 = vec2(getStrength(0.95,birchHeight),0.8),
	birch1Winter = vec2(getStrength(0.99,birchHeight),0.8),
	birch2Winter = vec2(getStrength(0.99,birchHeight),0.8),
	birch3Winter = vec2(getStrength(0.99,birchHeight),0.8),
	birch4Winter = vec2(getStrength(0.99,birchHeight),0.8),
	birchSapling = vec2(0.95, 0.8),
	birchSaplingWinter = vec2(0.99, 0.9),
	willow1 = vec2(getStrength(0.95,birchHeight),0.8),
	willow2 = vec2(getStrength(0.95,birchHeight),0.8),
	willow1Winter = vec2(getStrength(0.99,birchHeight),0.8),
	willow2Winter = vec2(getStrength(0.99,birchHeight),0.8),
	willowSapling = vec2(0.95, 0.8),
	willowSaplingWinter = vec2(0.99, 0.9),
	bush2 = vec2(0.9,0.0),
	cactus = vec2(0.9,0.0),
	palm = vec2(0.9,0.0),
	pine1 = vec2(getStrength(0.95,pineHeight),0.9),
	pine2 = vec2(getStrength(0.95,pineHeight),0.9),
	pine3 = vec2(getStrength(0.98,pineHeight),0.9),
	pine4 = vec2(getStrength(0.95,pineHeight),0.9),
	pine1Snow = vec2(getStrength(0.95,pineHeight),0.9),
	pine2Snow = vec2(getStrength(0.95,pineHeight),0.9),
	pine3Snow = vec2(getStrength(0.98,pineHeight),0.9),
	pine4Snow = vec2(getStrength(0.95,pineHeight),0.9),
	pineSapling = vec2(0.98, 0.8),
	pineSaplingWinter = vec2(0.98, 0.8),
	pineBig1 = vec2(getStrength(0.95,pineBigHeight),0.9),
	pineBigSapling = vec2(0.95, 0.8),
	pineBigSaplingWinter = vec2(0.95, 0.8),
	raspberryHangingFruit = vec2(0.9,0.8),
	raspberryBush = vec2(0.9,0.8),
	raspberryBushSapling = vec2(0.7,0.6),
	gooseberryHangingFruit = vec2(0.9,0.8),
	gooseberryBush = vec2(0.9,0.8),
	gooseberryBushSapling = vec2(0.7,0.6),
	shrub = vec2(0.6,0.8),
	sunflower = vec2(0.9,0.8),
	beetrootPlant = vec2(0.2,0.6),
	beetrootPlantSapling = vec2(0.1,0.6),
	wheatPlant = vec2(0.9,0.6),
	wheatPlantSapling = vec2(0.6,0.6),
	bananaHangingFruit = vec2(getStrength(0.9,appleHeight), 0.8),
	bananaTree = vec2(getStrength(0.9,appleHeight), 0.8),
	bananaTreeSapling = vec2(0.9, 0.8),
	flaxPlant = vec2(0.9,0.95),
	flaxPlantSapling = vec2(0.9,0.9),
	bamboo1 = vec2(getStrength(0.95,birchHeight), 0.9),
	bamboo2 = vec2(getStrength(0.95,birchHeight), 0.9),
	bambooSapling = vec2(0.99, 0.8),
	coconutTree = vec2(getStrength(0.9,pineBigHeight), 0.8),
	coconutHangingFruit = vec2(getStrength(0.9,pineBigHeight), 0.8),
	coconutTreeSapling = vec2(0.9, 0.8),
	aspenBig1 = vec2(getStrength(0.95,pineBigHeight),0.9),
	aspenBig1Winter = vec2(getStrength(0.995,pineBigHeight),0.9),
	aspenBigSapling = vec2(0.95, 0.8),
	aspenBigSaplingWinter = vec2(0.99, 0.8),
	pumpkinPlant = vec2(0.7,0.6),
	pumpkinPlantSapling = vec2(0.7,0.6),
	poppyPlant = vec2(0.8,0.6),
	poppyPlantSapling = vec2(0.4,0.6),
	echinaceaPlant = vec2(0.8,0.6),
	echinaceaPlantSapling = vec2(0.4,0.6),
	gingerPlant = vec2(0.9,0.8),
	gingerPlantSapling = vec2(0.8,0.6),
	turmericPlant = vec2(0.9,0.8),
	turmericPlantSapling = vec2(0.8,0.6),
	marigoldPlant = vec2(0.4,0.6),
	marigoldPlantSapling = vec2(0.4,0.6),
	garlicPlant = vec2(0.9,0.9),
	garlicPlantSapling = vec2(0.9,0.9),
	aloePlant = vec2(0.9,1.0),
	aloePlantSapling = vec2(0.9,1.0),
}



local remapModels = {
	appleTree = {
		appleTreeAutumn = {
			leafyBushA = "autumn1Leaf",
			bushA = "autumn1"
		},
		appleTreeSpring = {
			leafyBushA = "leafyBushASpring",
			bushA = "bushASpring"
		},
	},
	appleTreeSapling = {
		appleTreeSaplingAutumn = {
			leafyBushSmall = "autumn1Small",
			bushA = "autumn1"
		},
		appleTreeSaplingSpring = {
			leafyBushSmall = "leafyBushSmallSpring",
			bushA = "bushASpring"
		},
	},
	elderberryTree = {
		elderberryTreeAutumn = {
			leafyBushElderberry = "autumn16Leaf",
			bushElderberry = "autumn16"
		},
		elderberryTreeSpring = {
			leafyBushElderberry = "leafyBushElderberrySpring",
			bushElderberry = "bushElderberrySpring"
		},
	},
	elderberryTreeSapling = {
		elderberryTreeSaplingAutumn = {
			leafyBushSmallElderberry = "autumn16Small",
			bushElderberry = "autumn16"
		},
		elderberryTreeSaplingSpring = {
			leafyBushSmallElderberry = "leafyBushSmallElderberrySpring",
			bushElderberry = "bushElderberrySpring"
		},
	},
	icon_sapiens = {
		icon_sapiensWhite = {
			logoColor = "ui_standard"
		},
	},
	peachTree = {
		peachTreeAutumn = {
			leafyBushMid = "autumn4Leaf",
			bushMid = "autumn4"
		},
		peachTreeSpring = {
			leafyBushMid = "leafyBushMidSpring",
			bushMid = "bushMidSpring"
		},
	},
	peachTreeSapling = {
		peachTreeSaplingAutumn = {
			leafyBushSmall = "autumn4Small",
			bushMid = "autumn4"
		},
		peachTreeSaplingSpring = {
			leafyBushSmall = "leafyBushSmallSpring",
			bushMid = "bushMidSpring"
		},
	},
	willow1 = {
		willow1Autumn = {
			leafyBushC = "autumn2LeafWillow",
			bushC = "autumn2Willow"
		},
		willow1Spring = {
			leafyBushC = "leafyBushCSpring",
			bushC = "bushCSpring"
		},
	},
	willow2 = {
		willow2Autumn = {
			leafyBushC = "autumn3LeafWillow",
			bushC = "autumn3Willow"
		},
		willow2Spring = {
			leafyBushC = "leafyBushCSpring",
			bushC = "bushCSpring"
		},
	},
	birchSapling = {
		birchSaplingAutumn = {
			leafyBushSmall = "autumn5Small"
		},
		birchSaplingSpring = {
			leafyBushSmall = "leafyBushSmallSpring"
		},
	},
	aspenSapling = {
		aspenSaplingAutumn = {
			leafyBushAspenSmall = "autumn8Small"
		},
		aspenSaplingSpring = {
			leafyBushAspenSmall = "leafyBushAspenSmallSpring"
		},
	},

	dirt = {
		richDirt = {
			dirt = "richDirt"
		},
		poorDirt = {
			dirt = "poorDirt"
		},
		sand = {
			dirt = "sand"
		},
		riverSand = {
			dirt = "riverSand"
		},
		redSand = {
			dirt = "redSand"
		},
		clay = {
			dirt = "clay"
		},
		compost = {
			dirt = "compost"
		},
		compostRotten = {
			dirt = "compostRotten"
		},
	},

	pathNode_dirt_1 = {
		pathNode_richDirt_1 = {
			dirtPath = "richDirtPath"
		},
		pathNode_poorDirt_1 = {
			dirtPath = "poorDirtPath"
		},
		pathNode_sand_1 = {
			dirtPath = "sand"
		},
		pathNode_riverSand_1 = {
			dirtPath = "riverSand"
		},
		pathNode_redSand_1 = {
			dirtPath = "redSand"
		},
		pathNode_clay_1 = {
			dirtPath = "clay"
		},
	},
	pathNode_dirt_small = {
		pathNode_richDirt_small = {
			dirtPath = "richDirtPath"
		},
		pathNode_poorDirt_small = {
			dirtPath = "poorDirtPath"
		},
		pathNode_sand_small = {
			dirtPath = "sand"
		},
		pathNode_riverSand_small = {
			dirtPath = "riverSand"
		},
		pathNode_redSand_small = {
			dirtPath = "redSand"
		},
		pathNode_clay_small = {
			dirtPath = "clay"
		},
	},


	dirtFoundation1x1Content = {
		dirtFoundation1x1Content_richDirt = {
			dirt = "richDirt"
		},
		dirtFoundation1x1Content_poorDirt = {
			dirt = "poorDirt"
		},
	},

	dirtFoundation1x1Content_low = {
		dirtFoundation1x1Content_low_richDirt = {
			dirt = "richDirt"
		},
		dirtFoundation1x1Content_low_poorDirt = {
			dirt = "poorDirt"
		},
	},

	dirtFoundation2x2Content = {
		dirtFoundation2x2Content_richDirt = {
			dirt = "richDirt"
		},
		dirtFoundation2x2Content_poorDirt = {
			dirt = "poorDirt"
		},
	},

	dirtFoundation2x2Content_low = {
		dirtFoundation2x2Content_low_richDirt = {
			dirt = "richDirt"
		},
		dirtFoundation2x2Content_low_poorDirt = {
			dirt = "poorDirt"
		},
	},

	
	ingot = {
		bronzeIngot = {
			metal = "bronze",
		},
	},

	stoneHatchetBuild = {
		bronzeHatchetBuild = {},
	},

	stoneHatchet = {
		bronzeHatchet = {},
	},

	stonePickaxeBuild = {
		bronzePickaxeBuild = {},
	},

	stonePickaxe = {
		bronzePickaxe = {},
	},

	stoneSpearBuild = {
		bronzeSpearBuild = {},
	},

	stoneSpear = {
		bronzeSpear = {},
	},

	stoneHammerBuild = {
		bronzeHammerBuild = {},
	},

	stoneHammer = {
		bronzeHammer = {},
	},

	woolskinBed_1 = {
		woolskinBed_woolskin_1 = {},
		woolskinBed_woolskinMammoth_1 = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	woolskinBed_2 = {
		woolskinBed_woolskin_2 = {},
		woolskinBed_woolskinMammoth_2 = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	woolskinBed_3 = {
		woolskinBed_woolskin_3 = {},
		woolskinBed_woolskinMammoth_3 = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	coveredSledEmptyWoolskin = {
		coveredSledEmptyWoolskinMammoth = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	coveredSledHalfFullWoolskin = {
		coveredSledHalfFullWoolskinMammoth = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	coveredSledFullWoolskin = {
		coveredSledFullWoolskinMammoth = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	coveredCanoeEmptyWoolskin = {
		coveredCanoeEmptyWoolskinMammoth = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	coveredCanoeHalfFullWoolskin = {
		coveredCanoeHalfFullWoolskinMammoth = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},

	coveredCanoeFullWoolskin = {
		coveredCanoeFullWoolskinMammoth = {
			clothes = "clothesMammoth",
			clothesNoDecal = "clothesMammothNoDecal",
		},
	},
	
	unfiredUrn = {
		unfiredUrnWet = {
			clay = "clayWet"
		},
	},
	
	unfiredBowl = {
		unfiredBowlWet = {
			clay = "clayWet",
			clayDarker = "clayDarkerWet",
		},
	},
	
	unfiredCrucible = {
		unfiredCrucibleWet = {
			clay = "clayWet",
			clayDarker = "clayDarkerWet",
		},
	},
	
	mudBrick = {
		mudBrickWet_sand = {
			mudBrick = "mudBrickWet_sand"
		},
		mudBrickWet_hay = {
			mudBrick = "mudBrickWet_hay"
		},
		mudBrickWet_riverSand = {
			mudBrick = "mudBrickWet_riverSand"
		},
		mudBrickWet_redSand = {
			mudBrick = "mudBrickWet_redSand"
		},

		mudBrickDry_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickDry_hay = {
			mudBrick = "mudBrickDry_hay"
		},
		mudBrickDry_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickDry_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	
	brick = {
		firedBrick_sand = {
			brick = "firedBrick_sand"
		},
		firedBrick_hay = {
			brick = "firedBrick_hay"
		},
		firedBrick_riverSand = {
			brick = "firedBrick_riverSand"
		},
		firedBrick_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	
	tile = {
		mudTileWet = {
			brick = "clayWet"
		},
		mudTileDry = {
			brick = "clay"
		},
		firedTile = {
			brick = "terracotta"
		},
		stoneTile = {
			brick = "rockBlock"
		},
	},

	mudBrickWallSection = {
		mudBrickWallSection_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSection_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	

	mudBrickWallSectionRoofEnd1 = {
		mudBrickWallSectionRoofEnd1_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionRoofEnd1_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionRoofEnd1_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionRoofEnd1_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickWallSectionRoofEnd2 = {
		mudBrickWallSectionRoofEnd2_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionRoofEnd2_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionRoofEnd2_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionRoofEnd2_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickWallSectionRoofEndLow = {
		mudBrickWallSectionRoofEndLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionRoofEndLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionRoofEndLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionRoofEndLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
		
		brickWallSectionRoofEndLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSectionRoofEndLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSectionRoofEndLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSectionRoofEndLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},
		
		stoneBlockWallSectionRoofEndLow = {
			mudBrick = "rock"
		},
	},

	
	brickWallSectionRoofEnd1 = {
		brickWallSectionRoofEnd1_sand = {
			brick = "firedBrick_sand"
		},
		brickWallSectionRoofEnd1_hay = {
			brick = "firedBrick_hay"
		},
		brickWallSectionRoofEnd1_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallSectionRoofEnd1_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	
	brickWallSectionRoofEnd2 = {
		brickWallSectionRoofEnd2_sand = {
			brick = "firedBrick_sand"
		},
		brickWallSectionRoofEnd2_hay = {
			brick = "firedBrick_hay"
		},
		brickWallSectionRoofEnd2_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallSectionRoofEnd2_redSand = {
			brick = "firedBrick_redSand"
		},
	},

	mudBrickKilnSection = {
		mudBrickKilnSection_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickKilnSection_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickKilnSection_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickKilnSection_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickKilnSectionWithOpening = {
		mudBrickKilnSectionWithOpening_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickKilnSectionWithOpening_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickKilnSectionWithOpening_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickKilnSectionWithOpening_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickKilnSectionTop = {
		mudBrickKilnSectionTop_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickKilnSectionTop_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickKilnSectionTop_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickKilnSectionTop_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	
	
	mudBrickColumnTop = {
		mudBrickColumnTop_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickColumnTop_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickColumnTop_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickColumnTop_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	mudBrickColumnBottom = {
		mudBrickColumnBottom_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickColumnBottom_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickColumnBottom_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickColumnBottom_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	mudBrickColumnFullLow = {
		mudBrickColumnFullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickColumnFullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickColumnFullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickColumnFullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickWallSectionSingleHigh = {
		mudBrickWallSectionSingleHigh_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionSingleHigh_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionSingleHigh_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionSingleHigh_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	
	mudBrickWallSection_075 = {
		mudBrickWallSection_075_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection_075_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection_075_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSection_075_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickWallSectionDoorTop = {
		mudBrickWallSectionDoorTop_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionDoorTop_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionDoorTop_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionDoorTop_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	
	mudBrickWallSectionFullLow = {
		mudBrickWallSectionFullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionFullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionFullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionFullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
		
		brickWallSectionFullLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSectionFullLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSectionFullLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSectionFullLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},
		
		stoneBlockWallSectionFullLow = {
			mudBrick = "rock"
		},
	},
	
	mudBrickWallSection4x1FullLow = {
		mudBrickWallSection4x1FullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection4x1FullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection4x1FullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSection4x1FullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
		
		brickWallSection4x1FullLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSection4x1FullLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSection4x1FullLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSection4x1FullLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},
		
		stoneBlockWallSection4x1FullLow = {
			mudBrick = "rock"
		},
	},
	
	mudBrickWallSection2x2FullLow = {
		mudBrickWallSection2x2FullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection2x2FullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection2x2FullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSection2x2FullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},

		brickWallSection2x2FullLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSection2x2FullLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSection2x2FullLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSection2x2FullLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},

		stoneBlockWallSection2x2FullLow = {
			mudBrick = "rock"
		},
	},

	
	mudBrickWallSection2x1FullLow = {
		mudBrickWallSection2x1FullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection2x1FullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSection2x1FullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSection2x1FullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},

		brickWallSection2x1FullLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSection2x1FullLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSection2x1FullLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSection2x1FullLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},

		stoneBlockWallSection2x1FullLow = {
			mudBrick = "rock"
		},
	},
	
	mudBrickWallSectionWindowFullLow = {
		mudBrickWallSectionWindowFullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionWindowFullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionWindowFullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionWindowFullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},

		brickWallSectionWindowFullLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSectionWindowFullLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSectionWindowFullLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSectionWindowFullLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},

		stoneBlockWallSectionWindowFullLow = {
			mudBrick = "rock"
		},
	},
	
	mudBrickWallSectionDoorFullLow = {
		mudBrickWallSectionDoorFullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionDoorFullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallSectionDoorFullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallSectionDoorFullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},

		brickWallSectionDoorFullLow_sand = {
			mudBrick = "firedBrick_sand"
		},
		brickWallSectionDoorFullLow_hay = {
			mudBrick = "firedBrick_hay"
		},
		brickWallSectionDoorFullLow_riverSand = {
			mudBrick = "firedBrick_riverSand"
		},
		brickWallSectionDoorFullLow_redSand = {
			mudBrick = "firedBrick_redSand"
		},

		stoneBlockWallSectionDoorFullLow = {
			mudBrick = "rock"
		},
	},
	
	mudBrickWallColumn = {
		mudBrickWallColumn_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallColumn_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickWallColumn_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickWallColumn_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	
	
	mudBrickFloorSection4x4FullLow = {
		mudBrickFloorSection4x4FullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection4x4FullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection4x4FullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFloorSection4x4FullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
		--tile
		--todod
		tileFloorSection4x4FullLow_firedTile = {
			mudBrick = "terracottaTile"
		},
		tileFloorSection4x4FullLow_stoneTile = {
			mudBrick = "rockBlock"
		},
	},
	
	
	mudBrickFloorSection2x2FullLow = {
		mudBrickFloorSection2x2FullLow_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection2x2FullLow_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection2x2FullLow_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFloorSection2x2FullLow_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
		--tile
		tileFloorSection2x2FullLow_firedTile = {
			mudBrick = "terracottaTile"
		},
		tileFloorSection2x2FullLow_stoneTile = {
			mudBrick = "rockBlock"
		},
	},
	
	mudBrickFloorTri2LowContent = {
		mudBrickFloorTri2LowContent_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorTri2LowContent_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorTri2LowContent_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFloorTri2LowContent_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
		--tile
		tileFloorTri2LowContent_firedTile = {
			mudBrick = "terracottaTile"
		},
		tileFloorTri2LowContent_stoneTile = {
			mudBrick = "rockBlock"
		},
	},
	
	
	mudBrickFloorSection1x1 = {
		mudBrickFloorSection1x1_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection1x1_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection1x1_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFloorSection1x1_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickFloorSection2x1 = {
		mudBrickFloorSection2x1_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection2x1_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorSection2x1_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFloorSection2x1_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},
	
	mudBrickFloorTriSection2 = {
		mudBrickFloorTriSection2_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorTriSection2_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFloorTriSection2_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFloorTriSection2_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickFoundation1x1Content = {
		mudBrickFoundation1x1Content_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation1x1Content_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation1x1Content_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFoundation1x1Content_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickFoundation1x1Content_low = {
		mudBrickFoundation1x1Content_low_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation1x1Content_low_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation1x1Content_low_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFoundation1x1Content_low_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickFoundation2x2Content = {
		mudBrickFoundation2x2Content_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation2x2Content_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation2x2Content_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFoundation2x2Content_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},

	mudBrickFoundation2x2Content_low = {
		mudBrickFoundation2x2Content_low_sand = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation2x2Content_low_hay = {
			mudBrick = "mudBrickDry_sand"
		},
		mudBrickFoundation2x2Content_low_riverSand = {
			mudBrick = "mudBrickDry_riverSand"
		},
		mudBrickFoundation2x2Content_low_redSand = {
			mudBrick = "mudBrickDry_redSand"
		},
	},


	brickWallSection = {
		brickWallSection_sand = {
			brick = "firedBrick_sand"
		},
		brickWallSection_hay = {
			brick = "firedBrick_hay"
		},
		brickWallSection_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallSection_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	
	brickWallSection_075 = {
		brickWallSection_075_sand = {
			brick = "firedBrick_sand"
		},
		brickWallSection_075_hay = {
			brick = "firedBrick_hay"
		},
		brickWallSection_075_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallSection_075_redSand = {
			brick = "firedBrick_redSand"
		},
	},

	brickWallSectionDoorTop = {
		brickWallSectionDoorTop_sand = {
			brick = "firedBrick_sand"
		},
		brickWallSectionDoorTop_hay = {
			brick = "firedBrick_hay"
		},
		brickWallSectionDoorTop_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallSectionDoorTop_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	
	brickWallColumn = {
		brickWallColumn_sand = {
			brick = "firedBrick_sand"
		},
		brickWallColumn_hay = {
			brick = "firedBrick_hay"
		},
		brickWallColumn_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallColumn_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	

	brickWallSectionSingleHigh = {
		brickWallSectionSingleHigh_sand = {
			brick = "firedBrick_sand"
		},
		brickWallSectionSingleHigh_hay = {
			brick = "firedBrick_hay"
		},
		brickWallSectionSingleHigh_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickWallSectionSingleHigh_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	


	brickFoundation1x1Content = {
		brickFoundation1x1Content_sand = {
			brick = "firedBrick_sand"
		},
		brickFoundation1x1Content_hay = {
			brick = "firedBrick_sand"
		},
		brickFoundation1x1Content_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickFoundation1x1Content_redSand = {
			brick = "firedBrick_redSand"
		},
	},

	brickFoundation1x1Content_low = {
		brickFoundation1x1Content_low_sand = {
			brick = "firedBrick_sand"
		},
		brickFoundation1x1Content_low_hay = {
			brick = "firedBrick_sand"
		},
		brickFoundation1x1Content_low_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickFoundation1x1Content_low_redSand = {
			brick = "firedBrick_redSand"
		},
	},

	brickFoundation2x2Content = {
		brickFoundation2x2Content_sand = {
			brick = "firedBrick_sand"
		},
		brickFoundation2x2Content_hay = {
			brick = "firedBrick_sand"
		},
		brickFoundation2x2Content_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickFoundation2x2Content_redSand = {
			brick = "firedBrick_redSand"
		},
	},

	brickFoundation2x2Content_low = {
		brickFoundation2x2Content_low_sand = {
			brick = "firedBrick_sand"
		},
		brickFoundation2x2Content_low_hay = {
			brick = "firedBrick_sand"
		},
		brickFoundation2x2Content_low_riverSand = {
			brick = "firedBrick_riverSand"
		},
		brickFoundation2x2Content_low_redSand = {
			brick = "firedBrick_redSand"
		},
	},
	
	tileFloorSection2x1 = {
		tileFloorSection2x1_firedTile = {
			brick = "terracottaTile"
		},
		tileFloorSection2x1_stoneTile = {
			brick = "rockBlock"
		},
	},

	tileFloorSection1x1 = {
		tileFloorSection1x1_firedTile = {
			brick = "terracottaTile"
		},
		tileFloorSection1x1_stoneTile = {
			brick = "rockBlock"
		},
	},
	
	tileFloorTriSection2 = {
		tileFloorTriSection2_firedTile = {
			brick = "terracottaTile"
		},
		tileFloorTriSection2_stoneTile = {
			brick = "rockBlock"
		},
	},

	tileRoofSection4 = {
		tileRoofSection4_firedTile = {},
		tileRoofSection4_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},

	tileRoofSection2 = {
		tileRoofSection2_firedTile = {},
		tileRoofSection2_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},

	tileRoofLowContent = {
		tileRoofLowContent_firedTile = {},
		tileRoofLowContent_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},

	tileRoofSlopeLowContent = {
		tileRoofSlopeLowContent_firedTile = {},
		tileRoofSlopeLowContent_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},


	tileRoofSmallCornerSection1 = {
		tileRoofSmallCornerSection1_firedTile = {},
		tileRoofSmallCornerSection1_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},
	tileRoofSmallCornerSection2 = {
		tileRoofSmallCornerSection2_firedTile = {},
		tileRoofSmallCornerSection2_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},
	tileRoofSmallCornerLowContent = {
		tileRoofSmallCornerLowContent_firedTile = {},
		tileRoofSmallCornerLowContent_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},
	

	tileRoofSmallInnerCornerSection1 = {
		tileRoofSmallInnerCornerSection1_firedTile = {},
		tileRoofSmallInnerCornerSection1_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},
	tileRoofSmallInnerCornerSection2 = {
		tileRoofSmallInnerCornerSection2_firedTile = {},
		tileRoofSmallInnerCornerSection2_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},
	tileRoofTriangleSection = {
		tileRoofTriangleSection_firedTile = {},
		tileRoofTriangleSection_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},
	tileRoofInvertedTriangleSection = {
		tileRoofInvertedTriangleSection_firedTile = {},
		tileRoofInvertedTriangleSection_stoneTile = {
			terracottaTile = "rockBlock"
		},
	},

	
	pathNode_firedTile_1 = {
		pathNode_stoneTile_1 = {
			terracottaTile = "rockBlock"
		},
	},
	pathNode_firedTile_2 = {
		pathNode_stoneTile_2 = {
			terracottaTile = "rockBlock"
		},
	},
	pathNode_firedTile_small = {
		pathNode_stoneTile_small = {
			terracottaTile = "rockBlock"
		},
	},
	
	unfiredUrnGrain = {
		unfiredUrnWheat = {
			grain = "wheatGrain"
		},
		unfiredUrnFlour = {
			grain = "flour"
		},
		unfiredUrnWheatRotten = {
			grain = "wheatGrainRotten"
		},
		unfiredUrnFlourRotten = {
			grain = "flourRotten"
		},
	},
	
	
	firedUrnGrain = {
		firedUrnWheat = {
			grain = "wheatGrain"
		},
		firedUrnFlour = {
			grain = "flour"
		},
		firedUrnWheatRotten = {
			grain = "wheatGrainRotten"
		},
		firedUrnFlourRotten = {
			grain = "flourRotten"
		},
	},
	
	
	unfiredBowlFilled = {
		unfiredBowlInjuryMedicine = {
			grain = "injuryMedicine"
		},
		unfiredBowlBurnMedicine = {
			grain = "burnMedicine"
		},
		unfiredBowlFoodPoisoningMedicine = {
			grain = "foodPoisoningMedicine"
		},
		unfiredBowlVirusMedicine = {
			grain = "virusMedicine"
		},
		unfiredBowlMedicineRotten = {
			grain = "medicineRotten"
		},
	},

	
	firedBowlFilled = {
		firedBowlInjuryMedicine = {
			grain = "injuryMedicine"
		},
		firedBowlBurnMedicine = {
			grain = "burnMedicine"
		},
		firedBowlFoodPoisoningMedicine = {
			grain = "foodPoisoningMedicine"
		},
		firedBowlVirusMedicine = {
			grain = "virusMedicine"
		},
		firedBowlMedicineRotten = {
			grain = "medicineRotten"
		},
	},

	flatbread = {
		flatbreadRotten = {
			bread = "rottenBread",
			darkBread = "darkRottenBread",
		}
	},
	
	breadDough = {
		breadDoughRotten = {
			breadDough = "breadDoughRotten",
		}
	},
	
	manure = {
		manureRotten = {
			manure = "manureRotten",
		}
	},

	chickenMeat = {
		chickenMeatCooked = {
			whiteMeat = "whiteMeatCooked",
			bone = "boneCooked",
		}
	},
	chickenMeatBreast = {
		chickenMeatBreastCooked = {
			whiteMeat = "whiteMeatCooked",
			bone = "boneCooked",
		}
	},
	

	alpacaMeatRack = {
		alpacaMeatRackCooked = {
			redMeat = "redMeatCooked"
		}
	},
	alpacaMeatLeg = {
		alpacaMeatLegCooked = {
			redMeat = "redMeatCooked"
		}
	},
	mammothMeat = {
		mammothMeatCooked = {
			redMeat = "redMeatCooked"
		}
	},
	mammothMeatTBone = {
		mammothMeatTBoneCooked = {
			redMeat = "redMeatCooked"
		}
	},

	fillet = {
		filletCooked = {
			fillet_raw = "fillet_cooked",
			fillet_raw_inner = "fillet_cooked_inner",
		}
	},
	
	alpacaWoolskin = {
		mammothWoolskin = {
			alpacaWool = "mammothHide",
			alpacaWoolNoDecal = "mammothHide",
		}
	},
	

	catfishDead = {
		catfishCooked = {
			catfish = "catfish_cooked",
			catfish_fins = "catfish_fins_cooked",
		}
	},
	
	coelacanthDead = {
		coelacanthCooked = {
			coelacanth = "coelacanth_cooked",
			coelacanth_fins = "coelacanth_fins_cooked",
		}
	},
	flagellipinnaDead = {
		flagellipinnaCooked = {
			flagellipinna = "flagellipinna_cooked",
		}
	},
	polypterusDead = {
		polypterusCooked = {
			polypterus = "polypterus_cooked",
		}
	},
	redfishDead = {
		redfishCooked = {
			redfish = "redfish_cooked",
			redfish_fins = "redfish_fins_cooked",
		}
	},
	tropicalfishDead = {
		tropicalfishCooked = {
			tropicalfish = "tropicalfish_cooked",
		}
	},
	
	
	coconut = {
		coconutRotten = {
			coconut = "coconutRotten"
		},
		coconutHangingFruit = {}
	},
	
	bambooSeed = {
		bambooSeedRotten = {
			bambooSeed = "bambooSeedRotten"
		},
	},
	
	apple = {
		appleHangingFruit = {},
		appleHangingFruitWinter = {}
	},
	elderberry = {
		elderberryHangingFruit = {},
		elderberryHangingFruitWinter = {}
	},
	banana = {
		bananaHangingFruit = {}
	},
	orange = {
		orangeHangingFruit = {}
	},
	peach = {
		peachHangingFruit = {},
		peachHangingFruitWinter = {}
	},
	raspberry = {
		raspberryHangingFruit = {}
	},
	gooseberry = {
		gooseberryHangingFruit = {}
	},
	pumpkin = {
		pumpkinHangingFruit = {},
		pumpkinCooked = {
			pumpkin = "pumpkinCooked",
			wood = "charcoal",
		}
	},
	beetroot = {
		beetrootCooked = {
			beetroot = "beetrootCooked",
			beetleaf = "charcoal",
		}
	},

	-- branches
	birchBranch = {
		aspenBranch = {},
	},
	birchBranchLong = {
		aspenBranchLong = {},
	},
	birchBranchHalf = {
		aspenBranchHalf = {},
	},

	willowBranch = {
		appleBranch = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeBranch = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachBranch = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowBranchLong = {
		appleBranchLong = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeBranchLong = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachBranchLong = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowBranchHalf = {
		appleBranchHalf = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeBranchHalf = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachBranchHalf = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},

	-- woodenPole
	woodenPole_birch = {
		woodenPole_aspen = {},
	},
	woodenPoleShort_birch = {
		woodenPoleShort_aspen = {},
	},
	woodenPoleLong_birch = {
		woodenPoleLong_aspen = {},
	},
	woodenPole_willow = {
		woodenPole_apple = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		woodenPole_orange = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		woodenPole_peach = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	woodenPoleShort_willow = {
		woodenPoleShort_apple = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		woodenPoleShort_orange = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		woodenPoleShort_peach = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	woodenPoleLong_willow = {
		woodenPoleLong_apple = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		woodenPoleLong_orange = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		woodenPoleLong_peach = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	
	-- log
	birchLog = {
		aspenLog = {},
	},
	birchLogShort = {
		aspenLogShort = {},
	},
	birchLog4 = {
		aspenLog4 = {},
	},
	birchLog3 = {
		aspenLog3 = {},
	},
	birchLogHalf = {
		aspenLogHalf = {},
	},
	
	--[[pineLog = {
		coconutLog = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineLogShort = {
		coconutLogShort = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineLog4 = {
		coconutLog4 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineLog3 = {
		coconutLog3 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineLogHalf = {
		coconutLogHalf = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},]]
	

	willowLog = {
		appleLog = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeLog = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachLog = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowLogShort = {
		appleLogShort = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeLogShort = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachLogShort = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowLog4 = {
		appleLog4 = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeLog4 = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachLog4 = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowLog3 = {
		appleLog3 = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeLog3 = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachLog3 = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowLogHalf = {
		appleLogHalf = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeLogHalf = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachLogHalf = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},


	
	-- splitLog
	birchSplitLog = {
		aspenSplitLog = {},
	},
	birchSplitLogLong = {
		aspenSplitLogLong = {},
	},
	birchSplitLog3 = {
		aspenSplitLog3 = {},
	},
	birchSplitLogLongAngleCut = {
		aspenSplitLogLongAngleCut = {},
	},
	birchSplitLog075 = {
		aspenSplitLog075 = {},
	},
	birchSplitLog075AngleCut = {
		aspenSplitLog075AngleCut = {},
	},
	birchSplitLog2x1Grad = {
		aspenSplitLog2x1Grad = {},
	},
	birchSplitLog2x1GradAngleCut = {
		aspenSplitLog2x1GradAngleCut = {},
	},
	birchSplitLog2x2Grad = {
		aspenSplitLog2x2Grad = {},
	},
	birchSplitLog2x2GradAngleCut = {
		aspenSplitLog2x2GradAngleCut = {},
	},
	birchSplitLog05 = {
		aspenSplitLog05 = {},
	},
	birchSplitLog05AngleCut = {
		aspenSplitLog05AngleCut = {},
	},
	
	--[[pineSplitLog = {
		coconutSplitLog = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogLong = {
		coconutSplitLogLong = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog3 = {
		coconutSplitLog3 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogLongAngleCut = {
		coconutSplitLogLongAngleCut = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog075 = {
		coconutSplitLog075 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog075AngleCut = {
		coconutSplitLog075AngleCut = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog2x1Grad = {
		coconutSplitLog2x1Grad = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog2x1GradAngleCut = {
		coconutSplitLog2x1GradAngleCut = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog2x2Grad = {
		coconutSplitLog2x2Grad = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog2x2GradAngleCut = {
		coconutSplitLog2x2GradAngleCut = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog05 = {
		coconutSplitLog05 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLog05AngleCut = {
		coconutSplitLog05AngleCut = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutLeft1 = {
		coconutSplitLogSingleAngleCutLeft1 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutRight1 = {
		coconutSplitLogSingleAngleCutRight1 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutLeft2 = {
		coconutSplitLogSingleAngleCutLeft2 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutRight2 = {
		coconutSplitLogSingleAngleCutRight2 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutLeft3 = {
		coconutSplitLogSingleAngleCutLeft3 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutRight3 = {
		coconutSplitLogSingleAngleCutRight3 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutLeft4 = {
		coconutSplitLogSingleAngleCutLeft4 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutRight4 = {
		coconutSplitLogSingleAngleCutRight4 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutLeft5 = {
		coconutSplitLogSingleAngleCutLeft5 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutRight5 = {
		coconutSplitLogSingleAngleCutRight5 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogSingleAngleCutLeftSmallShelf = {
		coconutSplitLogSingleAngleCutLeftSmallShelf = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogTriFloorSection1 = {
		coconutSplitLogTriFloorSection1 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	pineSplitLogTriFloorSection2 = {
		coconutSplitLogTriFloorSection2 = {
			wood = "coconutWood",
			trunk = "coconutBark",
		},
	},
	]]
	

	willowSplitLog = {
		appleSplitLog = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLogLong = {
		appleSplitLogLong = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLogLong = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLogLong = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog3 = {
		appleSplitLog3 = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog3 = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog3= {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLogLongAngleCut = {
		appleSplitLogLongAngleCut = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLogLongAngleCut = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLogLongAngleCut = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog075 = {
		appleSplitLog075 = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog075 = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog075 = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog075AngleCut = {
		appleSplitLog075AngleCut = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog075AngleCut = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog075AngleCut = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog2x1Grad = {
		appleSplitLog2x1Grad = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog2x1Grad = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog2x1Grad = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog2x1GradAngleCut = {
		appleSplitLog2x1GradAngleCut = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog2x1GradAngleCut = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog2x1GradAngleCut = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog2x2Grad = {
		appleSplitLog2x2Grad = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog2x2Grad = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog2x2Grad = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog2x2GradAngleCut = {
		appleSplitLog2x2GradAngleCut = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog2x2GradAngleCut = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog2x2GradAngleCut = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog05 = {
		appleSplitLog05 = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog05 = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog05 = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},
	willowSplitLog05AngleCut = {
		appleSplitLog05AngleCut = {
			darkBark = "appleBark",
			willowWood = "appleWood",
		},
		orangeSplitLog05AngleCut = {
			darkBark = "orangeBark",
			willowWood = "orangeWood",
		},
		peachSplitLog05AngleCut = {
			darkBark = "peachBark",
			willowWood = "peachWood",
		},
	},

	metalAxeHead = {
		bronzeAxeHead = {
			metal = "bronze",
		}
	},

	metalPickaxeHead = {
		bronzePickaxeHead = {
			metal = "bronze",
		}
	},

	metalSpearHead = {
		bronzeSpearHead = {
			metal = "bronze",
		}
	},

	metalKnife = {
		bronzeKnife = {
			metal = "bronze",
		}
	},

	metalHammerHead = {
		bronzeHammerHead = {
			metal = "bronze",
		}
	},

	metalChisel = {
		bronzeChisel = {
			metal = "bronze",
		}
	},

	storageAreaPeg = {
		storageAreaPeg_allowAll = {
			trunk = "trunk",
			wood = "trunk",
		},
		storageAreaPeg_removeAll = {
			trunk = "warning",
			wood = "warning",
		},
		storageAreaPeg_destroyAll = {
			trunk = "red",
			wood = "red",
		},
		storageAreaPeg_allowNone = {
			trunk = "whiteTrunk",
			wood = "whiteTrunk",
		},
		storageAreaPeg_allowTakeOnly = {
			trunk = "trunk",
			wood = "whiteTrunk",
		},
		storageAreaPeg_allowGiveOnly = {
			trunk = "whiteTrunk",
			wood = "trunk",
		},
	},
	storageAreaSmallPeg = {
		storageAreaSmallPeg_allowAll = {
			trunk = "trunk",
			wood = "trunk",
		},
		storageAreaSmallPeg_removeAll = {
			trunk = "warning",
			wood = "warning",
		},
		storageAreaSmallPeg_destroyAll = {
			trunk = "red",
			wood = "red",
		},
		storageAreaSmallPeg_allowNone = {
			trunk = "whiteTrunk",
			wood = "whiteTrunk",
		},
		storageAreaSmallPeg_allowTakeOnly = {
			trunk = "trunk",
			wood = "whiteTrunk",
		},
		storageAreaSmallPeg_allowGiveOnly = {
			trunk = "whiteTrunk",
			wood = "trunk",
		},
	},
	storageAreaLargePeg = {
		storageAreaLargePeg_allowAll = {
			trunk = "trunk",
			wood = "trunk",
		},
		storageAreaLargePeg_removeAll = {
			trunk = "warning",
			wood = "warning",
		},
		storageAreaLargePeg_destroyAll = {
			trunk = "red",
			wood = "red",
		},
		storageAreaLargePeg_allowNone = {
			trunk = "whiteTrunk",
			wood = "whiteTrunk",
		},
		storageAreaLargePeg_allowTakeOnly = {
			trunk = "trunk",
			wood = "whiteTrunk",
		},
		storageAreaLargePeg_allowGiveOnly = {
			trunk = "whiteTrunk",
			wood = "trunk",
		},
	},

	sledRail = {
		sledRail_allowAll = {
			trunk = "trunk",
			wood = "trunk",
		},
		sledRail_removeAll = {
			trunk = "warning",
			wood = "warning",
		},
		sledRail_destroyAll = {
			trunk = "red",
			wood = "red",
		},
		sledRail_allowNone = {
			trunk = "whiteTrunk",
			wood = "whiteTrunk",
		},
		sledRail_allowTakeOnly = {
			trunk = "trunk",
			wood = "whiteTrunk",
		},
		sledRail_allowGiveOnly = {
			trunk = "whiteTrunk",
			wood = "trunk",
		},
	},
}

		--[[if baseRemapInfo.material == "rockBlock" or baseRemapInfo.material == "terracottaTile" or baseRemapInfo.material == "brick" then --horrible hack, but a refactor would take 100 years
			material = additionalInfo.blockMaterial
		end]]

local rockRemapInfos = {
	rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			return variantName
		end,
	},
	rockSmall = {
		material = "rock",
		keyFunction = function(variantName)
			return variantName .. "Small"
		end,
	},
	rockLarge = {
		material = "rock",
		keyFunction = function(variantName)
			return variantName .. "Large"
		end,
	},
	stoneBlock = {
		material = "rock",
		keyFunction = function(variantName)
			return variantName .. "Block"
		end,
	},
	pathNode_rock_1 = {
		material = "rock",
		keyFunction = function(variantName)
			return "pathNode_" .. variantName .. "_1"
		end,
	},
	pathNode_rock_2 = {
		material = "rock",
		keyFunction = function(variantName)
			return "pathNode_" .. variantName .. "_2"
		end,
	},
	pathNode_rock_small = {
		material = "rock",
		keyFunction = function(variantName)
			return "pathNode_" .. variantName .. "_small"
		end,
	},
	quernstone_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "quernstone_limestone"
			end
			return "quernstone_" .. variantName
		end,
	},
	craftArea_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			return "craftArea_" .. variantName
		end,
	},
	craftArea_rock1_low = {
		material = "rock",
		keyFunction = function(variantName)
			return "craftArea_low_" .. variantName
		end,
	},
	stoneKnife_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stoneKnife_limestone"
			end
			return "stoneKnife_" .. variantName
		end,
	},
	stoneChisel_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stoneChisel_limestone"
			end
			return "stoneChisel_" .. variantName
		end,
	},
	stoneAxeHead_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stoneAxeHead_limestone"
			end
			return "stoneAxeHead_" .. variantName
		end,
	},
	stoneHammerHead_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stoneHammerHead_limestone"
			end
			return "stoneHammerHead_" .. variantName
		end,
	},
	stoneSpearHead_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stoneSpearHead_limestone"
			end
			return "stoneSpearHead_" .. variantName
		end,
	},
	stonePickaxeHead_rock1 = {
		material = "rock",
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stonePickaxeHead_limestone"
			end
			return "stonePickaxeHead_" .. variantName
		end,
	},

	stoneBlockWallSection = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSection_" .. variantName
		end,
	},

	stoneBlockColumnTop = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockColumnTop_" .. variantName
		end,
	},
	stoneBlockColumnBottom = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockColumnBottom_" .. variantName
		end,
	},
	stoneBlockColumnFullLow = {
		material = "rock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockColumnFullLow_" .. variantName
		end,
	},
	stoneBlockWallSection_075 = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSection_075_" .. variantName
		end,
	},
	stoneBlockWallSectionDoorTop = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionDoorTop_" .. variantName
		end,
	},
	stoneBlockWallColumn = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallColumn_" .. variantName
		end,
	},
	stoneBlockWallSectionSingleHigh = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionSingleHigh_" .. variantName
		end,
	},
	stoneBlockWall4x1 = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWall4x1_" .. variantName
		end,
	},
	stoneBlockWallSectionRoofEnd1 = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionRoofEnd1_" .. variantName
		end,
	},
	stoneBlockWallSectionRoofEnd2 = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionRoofEnd2_" .. variantName
		end,
	},
	stoneBlockFoundation1x1Content = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockFoundation1x1Content_" .. variantName
		end,
	},
	stoneBlockFoundation1x1Content_low = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockFoundation1x1Content_low_" .. variantName
		end,
	},
	stoneBlockFoundation2x2Content = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockFoundation2x2Content_" .. variantName
		end,
	},
	stoneBlockFoundation2x2Content_low = {
		material = "rockBlock",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockFoundation2x2Content_low_" .. variantName
		end,
	},
	mudBrickWallSectionRoofEndLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionRoofEndLow_" .. variantName
		end,
	},
	mudBrickWallSectionFullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionFullLow_" .. variantName
		end,
	},
	mudBrickWallSection4x1FullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSection4x1FullLow_" .. variantName
		end,
	},
	mudBrickWallSection2x2FullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSection2x2FullLow_" .. variantName
		end,
	},
	mudBrickWallSection2x1FullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSection2x1FullLow_" .. variantName
		end,
	},
	mudBrickWallSectionWindowFullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionWindowFullLow_" .. variantName
		end,
	},
	mudBrickWallSectionDoorFullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "stoneBlockWallSectionDoorFullLow_" .. variantName
		end,
	},
	tile = {
		material = "brick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			if variantName == "limestoneRock" then
				return "stoneTile_limestone"
			end
			return "stoneTile_" .. variantName
		end,
	},
	tileFloorSection1x1 = {
		material = "brick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileFloorSection1x1_stoneTile_" .. variantName
		end,
	},
	tileFloorSection2x1 = {
		material = "brick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileFloorSection2x1_stoneTile_" .. variantName
		end,
	},
	mudBrickFloorSection4x4FullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileFloorSection4x4FullLow_stoneTile_" .. variantName
		end,
	},
	mudBrickFloorSection2x2FullLow = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileFloorSection2x2FullLow_stoneTile_" .. variantName
		end,
	},
	mudBrickFloorTri2LowContent = {
		material = "mudBrick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileFloorTri2LowContent_stoneTile_" .. variantName
		end,
	},
	tileFloorTriSection2 = {
		material = "brick",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileFloorTriSection2_stoneTile_" .. variantName
		end,
	},
	tileRoofSection4 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSection4_stoneTile_" .. variantName
		end,
	},
	tileRoofSection2 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSection2_stoneTile_" .. variantName
		end,
	},
	tileRoofLowContent = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofLowContent_stoneTile_" .. variantName
		end,
	},
	tileRoofSlopeLowContent = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSlopeLowContent_stoneTile_" .. variantName
		end,
	},
	tileRoofSmallCornerSection1 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSmallCornerSection1_stoneTile_" .. variantName
		end,
	},
	tileRoofSmallCornerSection2 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSmallCornerSection2_stoneTile_" .. variantName
		end,
	},
	tileRoofSmallCornerLowContent = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSmallCornerLowContent_stoneTile_" .. variantName
		end,
	},
	tileRoofSmallInnerCornerSection1 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSmallInnerCornerSection1_stoneTile_" .. variantName
		end,
	},
	tileRoofSmallInnerCornerSection2 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofSmallInnerCornerSection2_stoneTile_" .. variantName
		end,
	},
	tileRoofTriangleSection = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofTriangleSection_stoneTile_" .. variantName
		end,
	},
	tileRoofInvertedTriangleSection = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			return "tileRoofInvertedTriangleSection_stoneTile_" .. variantName
		end,
	},
	pathNode_firedTile_1 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			local variantToUse = variantName
			return "pathNode_stoneTile_" .. variantToUse .. "_1"
		end,
	},
	pathNode_firedTile_2 = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			local variantToUse = variantName
			return "pathNode_stoneTile_" .. variantToUse .. "_2"
		end,
	},
	pathNode_firedTile_small = {
		material = "terracottaTile",
		useBlockMaterial = true,
		keyFunction = function(variantName)
			local variantToUse = variantName
			if variantToUse == "limestoneRock" then
				variantToUse = "limestone"
			end
			return "pathNode_stoneTile_" .. variantToUse .. "_small"
		end,
	},
}

local additionalRockTypes = {
	limestoneRock = {
		material = "limestone",
		blockMaterial = "limestoneBlock",
	},
	sandstoneYellowRock = {
		material = "sandstoneYellowRock",
		blockMaterial = "sandstoneYellowRockBlock",
	},
	sandstoneRedRock = {
		material = "sandstoneRedRock",
		blockMaterial = "sandstoneRedRockBlock",
	},
	sandstoneOrangeRock = {
		material = "sandstoneOrangeRock",
		blockMaterial = "sandstoneOrangeRockBlock",
	},
	sandstoneBlueRock = {
		material = "sandstoneBlueRock",
		blockMaterial = "sandstoneBlueRockBlock",
	},
	redRock = {
		material = "redRock",
		blockMaterial = "redRockBlock",
	},
	greenRock = {
		material = "greenRock",
		blockMaterial = "greenRockBlock",
	},
	graniteRock = {
		material = "graniteRock",
		blockMaterial = "graniteRockBlock",
	},
	marbleRock = {
		material = "marbleRock",
		blockMaterial = "marbleRockBlock",
	},
	lapisRock = {
		material = "lapisRock",
		blockMaterial = "lapisRockBlock",
	},
}

for rockRemapInfoBaseModelKey,baseRemapInfo in pairs(rockRemapInfos) do
	--remapModels[rockRemapInfoBaseModelKey] = nil
	if not remapModels[rockRemapInfoBaseModelKey] then
		remapModels[rockRemapInfoBaseModelKey] = {}
	end
	
	for additionalRockKey, additionalInfo in pairs(additionalRockTypes) do
		local material = additionalInfo.material
		if baseRemapInfo.useBlockMaterial then
			material = additionalInfo.blockMaterial
		end
		remapModels[rockRemapInfoBaseModelKey][baseRemapInfo.keyFunction(additionalRockKey)] = {
			[baseRemapInfo.material] = material
		}
	end
	--mj:log("after new add:", remapModels[rockRemapInfoBaseModelKey])
end

if not remapModels.ore then
	remapModels.ore = {}
end

local oreRemaps = {
	"copperOre",
	"tinOre"
}

for i,oreKey in ipairs(oreRemaps) do
	remapModels.ore[oreKey] = {
		ore = oreKey
	}
end
	

local birchAllBases = {-- birch base, all variants
	balafon_birch = "balafon_%s",
}

local additionalBirchVariantsAll = {
	aspen = {},
	pine = {
		whiteTrunk = "trunk",
		lightWood = "wood",
	},
	coconut = {
		whiteTrunk = "coconutBark",
		lightWood = "coconutWood",
	},
	willow = {
		whiteTrunk = "darkBark",
		lightWood = "willowWood",
	},
	apple = {
		whiteTrunk = "appleBark",
		lightWood = "appleWood",
	},
	orange = {
		whiteTrunk = "orangeBark",
		lightWood = "orangeWood",
	},
	peach = {
		whiteTrunk = "peachBark",
		lightWood = "peachWood",
	},
	elderberry = {
		whiteTrunk = "elderberryBark",
		lightWood = "elderberryWood",
	},
}

local birchBases = {-- birch base, birch variants
	logDrum_birch = "logDrum_%s",
}

local additionalBirchVariants = {
	aspen = {},
}


local pineWillowBases = { -- pine base, pine and willow variants
	logDrum_pine = "logDrum_%s",
}

local additionalPineWillowVariants = { 
	coconut = {
		trunk = "coconutBark",
		wood = "coconutWood",
	},
	willow = {
		trunk = "darkBark",
		wood = "willowWood",
	},
	apple = {
		trunk = "appleBark",
		wood = "appleWood",
	},
	orange = {
		trunk = "orangeBark",
		wood = "orangeWood",
	},
	peach = {
		trunk = "peachBark",
		wood = "peachWood",
	},
	elderberry = {
		trunk = "elderberryBark",
		wood = "elderberryWood",
	},
}

local function addVariantMaps(bases, variants)
	for base,addKeyFormat in pairs(bases) do
		for addKey,addMap in pairs(variants) do
			if not remapModels[base] then
				remapModels[base] = {}
			end
			remapModels[base][string.format(addKeyFormat, addKey)] = addMap
		end
	end
end

addVariantMaps(birchAllBases, additionalBirchVariantsAll)
addVariantMaps(birchBases, additionalBirchVariants)
addVariantMaps(pineWillowBases, additionalPineWillowVariants)



--mj:log("remapModels:", remapModels)

	
local willowBases = { --these types don't apply to apple, peach, orange, as they had already been added above. Could refactor to combine, but tricky to test.
	willowBranch = "%sBranch",
	willowBranchLong = "%sBranchLong",
	willowBranchHalf = "%sBranchHalf",

	woodenPole_willow = "woodenPole_%s",
	woodenPoleShort_willow = "woodenPoleShort_%s",
	woodenPoleLong_willow = "woodenPoleLong_%s",

	willowLog = "%sLog",
	willowLogShort = "%sLogShort",
	willowLog4 = "%sLog4",
	willowLog3 = "%sLog3",
	willowLogHalf = "%sLogHalf",

	willowSplitLog = "%sSplitLog",
	willowSplitLogLong = "%sSplitLogLong",
	willowSplitLog3 = "%sSplitLog3",
	willowSplitLogLongAngleCut = "%sSplitLogLongAngleCut",
	willowSplitLog075 = "%sSplitLog075",
	willowSplitLog075AngleCut = "%sSplitLog075AngleCut",
	willowSplitLog2x1Grad = "%sSplitLog2x1Grad",
	willowSplitLog2x1GradAngleCut = "%sSplitLog2x1GradAngleCut",
	willowSplitLog2x2Grad = "%sSplitLog2x2Grad",
	willowSplitLog2x2GradAngleCut = "%sSplitLog2x2GradAngleCut",
	willowSplitLog05 = "%sSplitLog05",
	willowSplitLog05AngleCut = "%sSplitLog05AngleCut",
}

local willowNewAdditionalBases = { --add new object types here
	willowSplitLogSingleAngleCutLeft1 = "%sSplitLogSingleAngleCutLeft1",
	willowSplitLogSingleAngleCutRight1 = "%sSplitLogSingleAngleCutRight1",
	willowSplitLogSingleAngleCutLeft2 = "%sSplitLogSingleAngleCutLeft2",
	willowSplitLogSingleAngleCutRight2 = "%sSplitLogSingleAngleCutRight2",
	willowSplitLogSingleAngleCutLeft3 = "%sSplitLogSingleAngleCutLeft3",
	willowSplitLogSingleAngleCutRight3 = "%sSplitLogSingleAngleCutRight3",
	willowSplitLogSingleAngleCutLeft4 = "%sSplitLogSingleAngleCutLeft4",
	willowSplitLogSingleAngleCutRight4 = "%sSplitLogSingleAngleCutRight4",
	willowSplitLogSingleAngleCutLeft5 = "%sSplitLogSingleAngleCutLeft5",
	willowSplitLogSingleAngleCutRight5 = "%sSplitLogSingleAngleCutRight5",
	willowSplitLogSingleAngleCutLeftSmallShelf = "%sSplitLogSingleAngleCutLeftSmallShelf",

	--willowSplitLogRoofSmallCornerLeftLowContent = "%sSplitLogRoofSmallCornerLeftLowContent",
	--willowSplitLogRoofSmallCornerRightLowContent = "%sSplitLogRoofSmallCornerRightLowContent",

	willowSplitLogTriFloorSection1 = "%sSplitLogTriFloorSection1",
	willowSplitLogTriFloorSection2 = "%sSplitLogTriFloorSection2",
}

local additionalWillowVariants = {
	"elderberry"
}

local additionalWillowVariantsIncludingNewBases = { --add new wood types here
	"elderberry",
	"apple",
	"peach",
	"orange",
}

for willowBase,addKeyFormat in pairs(willowNewAdditionalBases) do
	for i,addKey in ipairs(additionalWillowVariantsIncludingNewBases) do
		if not remapModels[willowBase] then
			remapModels[willowBase] = {}
		end
		remapModels[willowBase][string.format(addKeyFormat, addKey)] = {
			darkBark = addKey .. "Bark",
			willowWood = addKey .. "Wood",
		}
	end
end

for willowBase,addKeyFormat in pairs(willowBases) do
	for i,addKey in ipairs(additionalWillowVariants) do
		if not remapModels[willowBase] then
			remapModels[willowBase] = {}
		end
		remapModels[willowBase][string.format(addKeyFormat, addKey)] = {
			darkBark = addKey .. "Bark",
			willowWood = addKey .. "Wood",
		}
	end
end

local woodRemaps = {
	pine = {},
	birch = {
		trunk = "whiteTrunk",
		wood = "lightWood",
	},
	aspen = {
		trunk = "whiteTrunk",
		wood = "lightWood",
	},
	willow = {
		trunk = "darkBark",
		wood = "willowWood",
	},
	coconut = {
		trunk = "coconutBark",
		wood = "coconutWood",
	},
	apple = {
		trunk = "appleBark",
		wood = "appleWood",
	},
	elderberry = {
		trunk = "elderberryBark",
		wood = "elderberryWood",
	},
	orange = {
		trunk = "orangeBark",
		wood = "orangeWood",
	},
	peach = {
		trunk = "peachBark",
		wood = "peachWood",
	},
}

remapModels.splitLogFloor4x4FullLow = {}
remapModels.splitLogFloor2x2FullLow = {}
remapModels.splitLogFloor1x1FullLow = {}
remapModels.splitLogFloorTri2LowContent = {}
remapModels.woodenPole_pine_low = {}
remapModels.woodenPoleShort_pine_low = {}
remapModels.woodenPoleLong_pine_low = {}

remapModels.splitLogRoofSmallCornerLeftLowContent = {}
remapModels.splitLogRoofSmallCornerRightLowContent = {}
remapModels.splitLogRoofLowContent = {}
remapModels.splitLogRoofEndLowContent = {}
remapModels.splitLogRoofSlopeLowContent = {}
remapModels.splitLogRoofTriangleLowContent = {}

remapModels.canoe = {}

for k,v in pairs(woodRemaps) do
	remapModels.splitLogFloor4x4FullLow["splitLogFloor4x4FullLow_" .. k] = v
	remapModels.splitLogFloor2x2FullLow["splitLogFloor2x2FullLow_" .. k] = v
	remapModels.splitLogFloor1x1FullLow["splitLogFloor1x1FullLow_" .. k] = v
	remapModels.splitLogFloorTri2LowContent[k .. "SplitLogFloorTri2LowContent"] = v
	
	remapModels.splitLogRoofSmallCornerLeftLowContent[k .. "SplitLogRoofSmallCornerLeftLowContent"] = v
	remapModels.splitLogRoofSmallCornerRightLowContent[k .. "SplitLogRoofSmallCornerRightLowContent"] = v
	remapModels.splitLogRoofLowContent[k .. "SplitLogRoofLowContent"] = v
	remapModels.splitLogRoofEndLowContent[k .. "SplitLogRoofEndLowContent"] = v
	remapModels.splitLogRoofSlopeLowContent[k .. "SplitLogRoofSlopeLowContent"] = v
	remapModels.splitLogRoofTriangleLowContent[k .. "SplitLogRoofTriangleLowContent"] = v

	remapModels.canoe["canoe_" .. k] = v

	if k ~= "pine" then
		remapModels.woodenPole_pine_low["woodenPole_"..k.."_low"] = v
		remapModels.woodenPoleShort_pine_low["woodenPoleShort_"..k.."_low"] = v
		remapModels.woodenPoleLong_pine_low["woodenPoleLong_"..k.."_low"] = v
	end


	if not remapModels.pineSplitLogNotchedRack then
		remapModels.pineSplitLogNotchedRack = {}
	end
	if not remapModels.pineSplitLogSingleAngleCutLeftSmallShelf then
		remapModels.pineSplitLogSingleAngleCutLeftSmallShelf = {}
	end

	remapModels.pineSplitLogNotchedRack[k .. "SplitLogNotchedRack"] = {
		trunk = v.trunk or "trunk",
		wood = v.wood or "wood",
	}

	local function addStorageStatusRemaps(baseModelKey, remapModelKey)
		if not remapModels[baseModelKey] then
			remapModels[baseModelKey] = {}
		end

		remapModels[baseModelKey][remapModelKey .. "_allowAll"] = {
			trunk = v.trunk or "trunk",
			wood = v.wood or "wood",
			sideStatus = "wood",
			endStatus = "trunk",
		}
	
		remapModels[baseModelKey][remapModelKey .. "_removeAll"] = {
			trunk = v.trunk or "trunk",
			wood = v.wood or "wood",
			sideStatus = "warning",
			endStatus = "warning",
		}
	
		remapModels[baseModelKey][remapModelKey .. "_destroyAll"] = {
			trunk = v.trunk or "trunk",
			wood = v.wood or "wood",
			sideStatus = "red",
			endStatus = "red",
		}
	
		remapModels[baseModelKey][remapModelKey .. "_allowNone"] = {
			trunk = v.trunk or "trunk",
			wood = v.wood or "wood",
			sideStatus = "whiteTrunk",
			endStatus = "whiteTrunk",
		}
	
		remapModels[baseModelKey][remapModelKey .. "_allowTakeOnly"] = {
			trunk = v.trunk or "trunk",
			wood = v.wood or "wood",
			sideStatus = "wood",
			endStatus = "whiteTrunk",
		}
	
		remapModels[baseModelKey][remapModelKey .. "_allowGiveOnly"] = {
			trunk = v.trunk or "trunk",
			wood = v.wood or "wood",
			sideStatus = "whiteTrunk",
			endStatus = "trunk",
		}
	end
		
	addStorageStatusRemaps("pineSplitLogNotchedRack", k .. "SplitLogNotchedRack")
	addStorageStatusRemaps("pineSplitLogSingleAngleCutLeftSmallShelf", k .. "SplitLogSingleAngleCutLeftSmallShelf")

	addStorageStatusRemaps("canoe_" .. k, "canoe_" .. k)
			
end


for i=1,4 do
	local modelName = "birch" .. mj:tostring(i)
	local autumnName = modelName .. "Autumn"
	local springName = modelName .. "Spring"

	local function addRemaps(modelName_, autumnName_, springName_)
		remapModels[modelName_] = {
			[autumnName_] = {
				leafyBushB = "autumn" .. i + 3 .. "Leaf",
				bush = "autumn" .. i + 3,
				bushB = "autumn" .. i + 3
			},
			[springName_] = {
				leafyBushB = "leafyBushBSpring",
				bush = "bushBSpring",
				bushB = "bushBSpring"
			},
		}
	end

	addRemaps(modelName, autumnName, springName)
	--addRemaps(modelName .. "_low", autumnName .. "_low", springName .. "_low")

end

for i=1,3 do
	local modelName = "aspen" .. mj:tostring(i)
	local autumnName = modelName .. "Autumn"
	local springName = modelName .. "Spring"
	remapModels[modelName] = {
		[autumnName] = {
			leafyBushAspen = "autumn" .. i + 7 .. "Leaf",
			bushAspen = "autumn" .. i + 7
		},
		[springName] = {
			leafyBushAspen = "leafyBushAspenSpring",
			bushAspen = "bushAspenSpring"
		},
	}
end

for i=1,1 do
	local modelName = "aspenBig" .. mj:tostring(i)
	local autumnName = modelName .. "Autumn"
	local springName = modelName .. "Spring"
	remapModels[modelName] = {
		[autumnName] = {
			leafyBushAspen = "autumn" .. i + 10 .. "Leaf",
			bushAspen = "autumn" .. i + 10
		},
		[springName] = {
			leafyBushAspen = "leafyBushAspenSpring",
			bushAspen = "bushAspenSpring"
		},
	}
end


local modelIndexesByName = {}
local modelsByIndex = {}

model.modelsByIndex = modelsByIndex
model.modelIndexesByName = modelIndexesByName
model.remapModels = remapModels


local modelIndex = 1



local modelLevelsBySubdivLevel = {}
local modelDetailLevelsByHighestDetailIndex = {}

local function setupModelDetailLevels(renderDistance)
	
	for i=1,mj.SUBDIVISIONS do
		if i < mj.SUBDIVISIONS - 5 and renderDistance > 5.5 then
			modelLevelsBySubdivLevel[i] = 4
		elseif i < mj.SUBDIVISIONS - 4 and renderDistance > 9.5 then
			modelLevelsBySubdivLevel[i] = 4
		elseif i < mj.SUBDIVISIONS - 3 and renderDistance > 2.5 then
			modelLevelsBySubdivLevel[i] = 3
		else
			local minLowDetailDistance = 1
			--[[if renderDistance < 3.5 then
				minLowDetailDistance = 2
			end]]
			if debugLowDetail then
				minLowDetailDistance = 0
			end
			if i < mj.SUBDIVISIONS - minLowDetailDistance then
				modelLevelsBySubdivLevel[i] = 2
			else
				modelLevelsBySubdivLevel[i] = 1
			end
		end
	end
end

function model:addModel(fileName)
	local nameWithoutExtension = fileName:match("^(.+).glb$")
	if nameWithoutExtension then
		--mj:log("add model:", fileName)
		local existingMoodelIndex = modelIndexesByName[nameWithoutExtension]
		if existingMoodelIndex then
			--mj:log("existingMoodelIndex:", existingMoodelIndex)
			local modelInfo = modelsByIndex[existingMoodelIndex]
			modelInfo.path = fileName
			--mj:log("modelInfo:", modelInfo)
		else
			modelIndexesByName[nameWithoutExtension] = modelIndex
			
			local modelInfo = {
				path = fileName, 
				hasVolume = true, 
				materialRemap = nil,
				windStrength = vec2(1.0, 1.0)
			}

			if model.windStrengths[nameWithoutExtension] ~= nil then
				modelInfo.windStrength = model.windStrengths[nameWithoutExtension]
			end

			for unused, withoutVolume in ipairs(modelsWithoutVolume) do
				if withoutVolume == nameWithoutExtension then
					modelInfo.hasVolume = false
				end
			end
			--mj:log("modelIndex assigned:", modelIndex)

			modelsByIndex[modelIndex] = modelInfo

			modelIndex = modelIndex + 1
		end

	end
end

function model:searchModelDir(modelsDirPath)
	local fileList = fileUtils.getDirectoryContents(modelsDirPath)

	for i,fileName in ipairs(fileList) do
		model:addModel(fileName)
	end
end

function model:addModModels()
	local resourceAdditions = modManager.resourceAdditions["models"]
	--mj:log("addModModels resourceAdditions:", resourceAdditions)


	if resourceAdditions then
		
		local orderedKeys = {}
		for resourcesRelativePath, fullPath in pairs(resourceAdditions) do
			table.insert(orderedKeys, resourcesRelativePath)
		end

		--mj:log("orderedKeys:", orderedKeys)

		table.sort(orderedKeys)
		
		--mj:log("orderedKeys sorted:", orderedKeys)

		for i,resourcesRelativePath in ipairs(orderedKeys) do
			local nameWithoutModelsPath = resourcesRelativePath:match("^models/(.+.glb)$")
			if nameWithoutModelsPath then
				--mj:log("addModModels nameWithoutModelsPath:", nameWithoutModelsPath)
				model:addModel(nameWithoutModelsPath)
			end
		end
	end
end

function model:loadRemap(nameWithoutExtension, remaps)

	--mj:log("model:loadRemap:",nameWithoutExtension, " remaps:", remaps)

	local orderedRemapKeys = {}
	for remapName,materialRemap in pairs(remaps) do
		table.insert(orderedRemapKeys, remapName)
	end
	--mj:log("loadRemaps orderedRemapKeys:", orderedRemapKeys)

	table.sort(orderedRemapKeys) --must be consistent order on logic/main threads, so that model indexes are the same
	--mj:log("loadRemaps orderedRemapKeys sorted:", orderedRemapKeys)

	for j,remapName in ipairs(orderedRemapKeys) do
		if modelIndexesByName[remapName] then
			mj:warn("Remap model:", remapName, " is overwriting an existing model.")
		end
		
		local existingModelIndex = modelIndexesByName[nameWithoutExtension]
		local materialRemap = remaps[remapName]

		local function addClone(remapNameToUse, modelIndexToClone)
			local remapModelInfo = mj:cloneTable(modelsByIndex[modelIndexToClone])
			remapModelInfo.materialRemap = materialRemap
			modelIndexesByName[remapNameToUse] = modelIndex
			modelsByIndex[modelIndex] = remapModelInfo

			
			if model.windStrengths[remapNameToUse] ~= nil then
				remapModelInfo.windStrength = model.windStrengths[remapNameToUse]
			end

			for unused, withoutVolume in ipairs(modelsWithoutVolume) do
				if withoutVolume == remapNameToUse then
					remapModelInfo.hasVolume = false
				end
			end

			--mj:log("adding clone:", modelIndex, " modelIndexToClone:", modelIndexToClone, " remapModelInfo:", remapModelInfo)
			model.clones[modelIndex] = modelIndexToClone
			modelIndex = modelIndex + 1
		end


		--mj:log("adding remap:", remapName, " for base:", nameWithoutExtension)
		addClone(remapName, existingModelIndex)

		local existingNameWithDetail = nameWithoutExtension .. "_low"
		if modelIndexesByName[existingNameWithDetail] then
			local remapNameWithDetail = remapName .. "_low"
			addClone(remapNameWithDetail, modelIndexesByName[existingNameWithDetail])
		end
		existingNameWithDetail = nameWithoutExtension .. "_lowest"
		if modelIndexesByName[existingNameWithDetail] then
			local remapNameWithDetail = remapName .. "_lowest"
			addClone(remapNameWithDetail, modelIndexesByName[existingNameWithDetail])
		end
		existingNameWithDetail = nameWithoutExtension .. "_distant"
		if modelIndexesByName[existingNameWithDetail] then
			local remapNameWithDetail = remapName .. "_distant"
			addClone(remapNameWithDetail, modelIndexesByName[existingNameWithDetail])
		end
		
	end
end


function model:loadRemaps()
	--local modelIndexesByNameCopy = mj:cloneTable(modelIndexesByName)

	local orderedKeys = {}
	for nameWithoutExtension,existingModelIndex in pairs(modelIndexesByName) do
		table.insert(orderedKeys, nameWithoutExtension)
	end
	--mj:log("loadRemaps orderedKeys:", orderedKeys)

	table.sort(orderedKeys) --must be consistent order on logic/main threads, so that model indexes are the same
	--mj:log("loadRemaps orderedKeys sorted:", orderedKeys)


	for i,nameWithoutExtension in ipairs(orderedKeys) do
		local remaps = remapModels[nameWithoutExtension]
		if remaps then
			model:loadRemap(nameWithoutExtension, remaps)
		end
	end
end

function model:loadLOD(nameWithoutExtension,existingModelIndex)
	local info = {}
	modelDetailLevelsByHighestDetailIndex[existingModelIndex] = info

	info[1] = existingModelIndex

	local existingNameWithDetail = nameWithoutExtension .. "_low"
	local otherDetailIndex = modelIndexesByName[existingNameWithDetail]
	if otherDetailIndex then
		info[2] = otherDetailIndex
	else
		info[2] = existingModelIndex
	end
	
	existingNameWithDetail = nameWithoutExtension .. "_lowest"
	otherDetailIndex = modelIndexesByName[existingNameWithDetail]
	if otherDetailIndex then
		info[3] = otherDetailIndex
	else
		info[3] = existingModelIndex
	end
	
	existingNameWithDetail = nameWithoutExtension .. "_distant"
	otherDetailIndex = modelIndexesByName[existingNameWithDetail]
	if otherDetailIndex then
		info[4] = otherDetailIndex
	else
		info[4] = existingModelIndex
	end
end

function model:loadLODs()
	for nameWithoutExtension,existingModelIndex in pairs(modelIndexesByName) do
		model:loadLOD(nameWithoutExtension,existingModelIndex)
	end
end

function model:setup()

	local windStrengthsCopy = {}
	for k,v in pairs(windStrengthsBase) do
		windStrengthsCopy[k] = v
		windStrengthsCopy[k .. "_low"] = v
		windStrengthsCopy[k .. "_lowest"] = v
		windStrengthsCopy[k .. "_distant"] = v
	end

	model.windStrengths = windStrengthsCopy
	
	local modelsDirPath = fileUtils.getResourcePath("models")
	model:searchModelDir(modelsDirPath)
	model:addModModels()

	model:loadRemaps()
	model:loadLODs()

	--mj:log("modelIndexesByName:", modelIndexesByName)
	setupModelDetailLevels(4.0)
end

local cachedCompositeModelIndexes = {}

function model:getModelIndexForCompositeModel(compositeInfo)
	if cachedCompositeModelIndexes[compositeInfo.hash] then
		return cachedCompositeModelIndexes[compositeInfo.hash]
	end

	local newModelIndex = modelIndex

	modelsByIndex[newModelIndex] = {
		compositeInfo = compositeInfo.paths, 
		hasVolume = true, 
		materialRemap = compositeInfo.materialRemap,
	}

	modelIndex = modelIndex + 1

	cachedCompositeModelIndexes[compositeInfo.hash] = newModelIndex

	return newModelIndex
end

local cachedModelNames = {}

function model:modelIndexForModelNameAndDetailLevel(modelName, level)
	if modelName then
		local cachedModelName = cachedModelNames[modelName]
		if cachedModelName then
			return cachedModelName[level]
		end

		cachedModelName = {}
		cachedModelNames[modelName] = cachedModelName

		local lowestDetailIndex = modelIndexesByName[modelName]
		cachedModelName[1] = lowestDetailIndex

		local lowDetail = modelName .. "_low"
		lowestDetailIndex = modelIndexesByName[lowDetail] or lowestDetailIndex
		cachedModelName[2] = lowestDetailIndex
		
		local lowestDetail = modelName .. "_lowest"
		lowestDetailIndex = modelIndexesByName[lowestDetail] or lowestDetailIndex
		cachedModelName[3] = lowestDetailIndex
		
		local distantDetail = modelName .. "_distant"
		lowestDetailIndex = modelIndexesByName[distantDetail] or lowestDetailIndex
		cachedModelName[4] = lowestDetailIndex

		return cachedModelName[level]
	end
	return nil
end


function model:modelIndexForDetailedModelIndexAndDetailLevel(detailedModelIndex, level)
	local modelDetailLevels = modelDetailLevelsByHighestDetailIndex[detailedModelIndex]
	--mj:log("modelDetailLevels:", modelDetailLevels, " level:", level)
	if modelDetailLevels then
		return modelDetailLevels[level]
	end

	return detailedModelIndex
end


function model:modelLevelForSubdivLevel(subdivLevel)
	return modelLevelsBySubdivLevel[math.min(subdivLevel, mj.SUBDIVISIONS - 1)]
end

function model:modelIndexForName(modelName)
	if modelName then
		local foundModel = modelIndexesByName[modelName]
		if not foundModel then
			mj:log("ERROR: model not found in modelIndexForName:", modelName)
			error("ERROR: model not found")
		end
		return  foundModel
	end
	return nil
end

function model:renderDistanceChanged(renderDistance)
	--mj:log("model:renderDistanceChanged:", renderDistance)
	setupModelDetailLevels(renderDistance)
end


function model:mjInit()
	model:setup()
end

-- called by engine

function model:modelInfoForModelIndex(modelIndexToFind)
	local foundModel = modelsByIndex[modelIndexToFind]
	return foundModel
end

return model