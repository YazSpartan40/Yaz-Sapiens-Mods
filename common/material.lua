local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec4 = mjm.vec4
local toVec3 = mjm.toVec3
local mix = mjm.mix


local edgeDecal = mjrequire "common/edgeDecal"
local moodColors = mjrequire "common/moodColors"
local biome = mjrequire "common/biome"

local material = {}

local grassRoughness = 0.85
local grassTopsRoughness = 0.8 * 0.8
local grassTopsRoughnessB = 0.6 * 0.8
local bushRoughness = 1.0

local grassRoughnessDry = 0.8
local grassTopsRoughnessDry = 0.6 * 0.8
local grassTopsRoughnessDryB = 0.4 * 0.8


local grassLightness = 1.0

local function mat(key, color, roughness, metal)
	return {key = key, color = color, roughness = roughness, metal = metal or 0.0}
end

local function matWithB(key, color, roughness, colorB, roughnessB, metal)
	return {key = key, color = color, roughness = roughness, colorB = colorB, roughnessB = roughnessB, metal = metal or 0.0, metalB = metal or 0.0}
end

material.mat = mat

local whiteColor = vec3(0.65,0.65,0.65)
--local blueColor = vec3(0.4,0.6,0.8)
local blueColor = vec3(0.3, 0.7, 1.0) * 0.6
local blueHighlightColor = vec3(0.6,0.8,1.0)
local orangeColor = vec3(0.8,0.4,0.0)
local orangeHighlightColor = vec3(1.0,0.2,0.0)
local greenColor = vec3(0.2,0.6,0.2)
local greenHighlightColor = vec3(0.8,1.0,0.8)
local redColor = vec3(0.6,0.2,0.2)
local yellowColor = vec3(0.6,0.6,0.2)

local otherPlayerPurple = mj.otherPlayerColor * 0.6
--local otherPlayerPurpleHighlight = mj.otherPlayerColor

local uiRoughness = 0.55

local skinRoughness = 0.65
local hairRoughness = 0.8

local redColorBright = vec3(0.8,0.1,0.1)
local greenColorBright = vec3(0.1,0.8,0.1)
local yellowColorBright = vec3(0.8,0.8,0.1)

local redColorDark = vec3(0.2,0.0,0.0)
local greenColorDark = vec3(0.05,0.3,0.05)
local blueColorDark = vec3(0.3, 0.7, 1.0) * 0.5


local temperateGrassBaseColor = vec3(0.12,0.17,0.07)
local mediterrainianGrassBaseColor = vec3(0.24,0.21,0.1) * 1.2
local savannaGrassBaseColor = vec3(0.2,0.21,0.1) * 1.2
local tundraGrassBaseColor = vec3(0.18,0.16,0.1) * 1.4
local winterGrassColor = (temperateGrassBaseColor + mediterrainianGrassBaseColor) * 0.5

local mammothColor = vec3(0.16, 0.135, 0.12) * 1.5

local uiColorToMatColorMultiplier = 0.7

local function getMoodColor(baseColor)
	local vecColor = toVec3(baseColor)
	vecColor = vec3(math.pow(vecColor.x, 1.5), math.pow(vecColor.y, 1.5), math.pow(vecColor.z, 1.5))
	return vecColor * uiColorToMatColorMultiplier
end

local function getMoodBackgroundColor(baseColor)
	local vecColor = toVec3(baseColor)
	vecColor = vec3(math.pow(vecColor.x * 0.3, 1.5), math.pow(vecColor.y * 0.3, 1.5), math.pow(vecColor.z * 0.3, 1.5))
	return vecColor * uiColorToMatColorMultiplier
end

function material:getUIColor(materialIndexToUse)
	local vecColor = toVec3(material.types[materialIndexToUse].color) * 2.5
	vecColor = vec3(math.pow(vecColor.x, 0.5), math.pow(vecColor.y, 0.5), math.pow(vecColor.z, 0.5))
	--vecColor = vecColor * uiColorToMatColorMultiplier
	return vec4(vecColor.x, vecColor.y, vecColor.z, 1.0)
end

local function getAutumnColor(base)
	return base * 0.6 + vec3(0.2,0.05,0.05)
end

local thatchBaseColor = vec3(0.33,0.31,0.28) * 0.75
local pineColor = vec3(0.05,0.1,0.05)

local redSandColor = vec3(0.5, 0.2, 0.15)

local function getSandstoneColor(base)
	return base * 0.5 + vec3(0.1,0.1,0.1)
end

local bronzeColor = vec3(0.4,0.2,0.0)
local uiBronzeColor = mjm.mix(bronzeColor,vec3(0.1,0.1,0.1), 0.5) * 0.7


local ironColor = vec3(0.4,0.4,0.42)
local uiIronColor = mjm.mix(ironColor,vec3(0.1,0.1,0.1), 0.5) * 0.7

local richDirtColor = vec3(0.2,0.16,0.12) * 0.7
local standardDirtColor = vec3(0.29,0.23,0.18)
local poorDirtColor = vec3(0.33,0.27,0.19)


local terrain_richDirtColor = mix(richDirtColor, standardDirtColor, 0.3)
local terrain_standardDirtColor = standardDirtColor
local terrain_poorDirtColor = mix(poorDirtColor, standardDirtColor, 0.3)

local rockColor = vec3(0.22,0.23,0.25) * 0.95
local limestoneColor = vec3(0.41,0.4,0.37) * 1.1

local copperOreColor = vec3(0.2,0.47,0.42) * 0.8 + vec3(0.1,0.1,0.1)
local tinOreColor = vec3(0.25,0.35,0.42) * 0.8 + vec3(0.1,0.1,0.1)

local clayColor = vec3(0.62,0.47,0.32)

local sandColor = vec3(0.45, 0.4, 0.35) * 0.7
local riverSandColor = vec3(0.37, 0.36, 0.35) * 0.7
--local desertSandColor = vec3(0.37, 0.36, 0.35) * 0.7

local redRockColor = vec3(0.35,0.05,0.2) * 0.3
local greenRockColor = vec3(0.1,0.3,0.12) * 0.2
local graniteRockColor = vec3(0.05,0.05,0.05) * 0.3
local marbleRockColor = vec3(0.5,0.53,0.56) * 1.0
local lapisRockColor = vec3(0.005,0.03,0.1)


local alpaca_white_colorA = vec3(0.4,0.4,0.4)
local alpaca_white_colorB = vec3(0.8,0.79,0.76)
local alpaca_black_colorA = vec3(0.0,0.0,0.0)
local alpaca_black_colorB = vec3(0.0,0.0,0.0)
local alpaca_red_colorA = vec3(0.12,0.05,0.04)
local alpaca_red_colorB = vec3(0.34,0.25,0.17)
local alpaca_yellow_colorA = vec3(0.25,0.17,0.1)
local alpaca_yellow_colorB = vec3(0.5,0.4,0.2)
local alpaca_cream_colorA = vec3(0.4,0.37,0.3)
local alpaca_cream_colorB = vec3(0.5,0.45,0.3)



material.types = mj:indexed {
	mat("Material", vec3(1.0,0.0,0.0), 1.0), --default blender material. This is often used for shadowVolume primitives, but not rendered. Lets just allow it but color it red if we come across it.

	matWithB("trunk", vec3(0.19,0.14,0.12) * 0.4, 1.0, vec3(0.19,0.14,0.12) * 0.4 + vec3(0.1,0.1,0.05), 1.0),
	matWithB("sideStatus", vec3(0.19,0.14,0.12) * 0.4, 1.0, vec3(0.19,0.14,0.12) * 0.4 + vec3(0.1,0.1,0.05), 1.0),
	mat("whiteTrunk", vec3(0.5,0.5,0.5), 0.8),
	matWithB("darkBark", vec3(0.22,0.2,0.16) * 0.4, 1.0, vec3(0.22,0.2,0.16) * 0.4 + vec3(0.1,0.1,0.05), 1.0),
	mat("bushDecal", vec3(0.25,0.3,0.15) * 1.1, bushRoughness),
	mat("greenSeed", vec3(0.15,0.3,0.15), 1.0),
	
	mat("bananaBarkNoDecal", vec3(0.19,0.14,0.05) * 1.7, 1.0),
	mat("bananaBark", vec3(0.19,0.14,0.05) * 1.7, 1.0),

	mat("autumn1",  getAutumnColor(vec3(0.55,0.43,0.05)  )* 1.0, bushRoughness),
	mat("autumn2",  getAutumnColor(vec3(0.51,0.38,0.05)  )* 1.0, bushRoughness),
	mat("autumn3",  getAutumnColor(vec3(0.35,0.17,0.06)  )* 1.0, bushRoughness),
	mat("autumn4",  getAutumnColor(vec3(0.55,0.45,0.1)   )* 1.0, bushRoughness),
	mat("autumn5",  getAutumnColor(vec3(0.51,0.32,0.1)   )* 1.0, bushRoughness),
	mat("autumn6",  getAutumnColor(vec3(0.4,0.13,0.08)   )* 1.0, bushRoughness),
	mat("autumn7",  getAutumnColor(vec3(0.7,0.35,0.1)    )* 1.0, bushRoughness),
	mat("autumn8",  getAutumnColor(vec3(0.44,0.12,0.04)  )* 1.0, bushRoughness),
	mat("autumn9",  getAutumnColor(vec3(0.54,0.25,0.08)  )* 1.0, bushRoughness),
	mat("autumn10", getAutumnColor(vec3(0.67,0.5,0.01)   )* 1.0, bushRoughness),
	mat("autumn11", getAutumnColor(vec3(0.44,0.06,0.03)  )* 1.0, bushRoughness),
	mat("autumn12", getAutumnColor(vec3(0.52,0.04,0.04)  )* 1.0, bushRoughness),
	mat("autumn13", getAutumnColor(vec3(0.38,0.24,0.08)  )* 1.0, bushRoughness),
	mat("autumn14", getAutumnColor(vec3(0.63,0.42,0.04)  )* 1.0, bushRoughness),
	mat("autumn15", getAutumnColor(vec3(0.82,0.14,0.02)  )* 1.0, bushRoughness),
	mat("autumn16", getAutumnColor(vec3(0.94,0.59,0.1)   )* 1.0, bushRoughness),
	
	mat("winter1", vec3(0.25,0.12,0.08)  * 1.0, bushRoughness),
	mat("winter2", vec3(0.35,0.22,0.08)  * 1.0, bushRoughness),

	mat("leafyBushA", vec3(0.25,0.33,0.15) * 0.8, bushRoughness),
	--mat("leafyBushASpring", vec3(0.25,0.33,0.15) * 1.1, bushRoughness),
	mat("leafyBushASpring", vec3(0.6,0.5,0.5) * 0.8, bushRoughness),
	
	mat("leafyBushB", vec3(0.25,0.33,0.15) * 0.8, bushRoughness),
	mat("leafyBushBSpring", vec3(0.25,0.37,0.15) * 0.8, bushRoughness),
	
	mat("leafyBushC", vec3(0.25,0.35,0.11) * 0.8, bushRoughness),
	mat("leafyBushCSpring", vec3(0.21,0.37,0.11) * 0.8, bushRoughness),
	mat("leafyBushCSmall", vec3(0.25,0.35,0.11) * 0.8, bushRoughness),
	
	mat("leafyBushElderberry", vec3(0.2,0.33,0.15) * 0.8, bushRoughness),
	mat("leafyBushElderberrySpring", vec3(0.2,0.38,0.15) * 0.8, bushRoughness),
	mat("bushElderberry", vec3(0.2,0.33,0.15) * 0.8, bushRoughness),
	mat("bushElderberrySpring", vec3(0.2,0.38,0.15) * 0.8, bushRoughness),
	mat("leafyBushSmallElderberry", vec3(0.2,0.33,0.15) * 0.8, bushRoughness),
	mat("leafyBushSmallElderberrySpring", vec3(0.2,0.38,0.15) * 0.8, bushRoughness),
	
	mat("bush", vec3(0.25,0.33,0.15) * 0.8, bushRoughness),
	mat("bushSpring", vec3(0.25,0.37,0.15) * 1.0, bushRoughness),
	
	mat("bushA", vec3(0.25,0.33,0.15) * 0.8, bushRoughness),
	mat("bushASpring", vec3(0.6,0.5,0.5) * 0.7, bushRoughness),

	mat("bushB", vec3(0.25,0.33,0.15) * 0.8, bushRoughness),
	mat("bushBSpring", vec3(0.25,0.37,0.15) * 0.9, bushRoughness),
	

	mat("bushC", vec3(0.25,0.35,0.11) * 0.8, bushRoughness),
	mat("bushCSpring", vec3(0.21,0.37,0.11) * 0.9, bushRoughness),
	
	mat("leafyBushAspen", vec3(0.25,0.25,0.05) * 0.8, bushRoughness),
	mat("leafyBushAspenSpring", vec3(0.25,0.29,0.05) * 0.9, bushRoughness),
	mat("bushAspen", vec3(0.25,0.25,0.05) * 0.8, bushRoughness),
	mat("bushAspenSpring", vec3(0.25,0.29,0.05) * 0.9, bushRoughness),
	mat("leafyBushAspenSmall", vec3(0.25,0.25,0.05) * 0.8, bushRoughness),
	mat("leafyBushAspenSmallSpring", vec3(0.25,0.29,0.05) * 0.9, bushRoughness),
	
	mat("bananaLeafNoBush", vec3(0.25,0.35,0.15) * 1.2, bushRoughness),
	mat("bananaLeaf", vec3(0.25,0.35,0.15) * 1.2, bushRoughness),
	
	mat("leafyBushMid", vec3(0.25,0.33,0.2) * 0.8, bushRoughness * 0.9),
	mat("leafyBushMidSpring", vec3(0.35,0.43,0.2), bushRoughness * 0.9),
	mat("leafyBushMidSmall", vec3(0.25,0.33,0.2) * 0.8, bushRoughness * 0.9),
	mat("leafyBushMidSmallSpring", vec3(0.35,0.43,0.2), bushRoughness * 0.9),
	mat("bushMid", vec3(0.25,0.33,0.2) * 0.8, bushRoughness * 0.9),
	mat("bushMidSpring", vec3(0.35,0.43,0.2), bushRoughness * 0.9),
	mat("leafyBushSmall", vec3(0.25,0.33,0.2) * 0.8, bushRoughness * 0.9),
	mat("leafyBushSmallSpring", vec3(0.35,0.43,0.2), bushRoughness * 0.9),

	
	matWithB("bambooGreen", vec3(0.25,0.33,0.15) * 0.8, bushRoughness * 0.6, vec3(0.0,0.1,0.0), 1.0),
	matWithB("bambooDark", vec3(0.35,0.33,0.2) * 0.2, bushRoughness, vec3(0.0,0.0,0.0), 1.0), --probably unused
	matWithB("bamboo", vec3(0.28,0.25,0.18) * 1.3, bushRoughness * 0.7, vec3(0.29,0.255,0.18) * 0.7, 1.0),

	mat("bambooLeafNoBush", vec3(0.25,0.4,0.1) * 0.7, bushRoughness),
	mat("bambooLeaf", vec3(0.25,0.4,0.1) * 0.7, bushRoughness),
	mat("bambooLeafSmall", vec3(0.25,0.4,0.1) * 0.7, bushRoughness),
	
	mat("bambooSeed", vec3(0.28,0.25,0.15) * 0.8, bushRoughness * 0.6),
	mat("bambooSeedRotten", vec3(0.4,0.4,0.4), bushRoughness),
	

	mat("leafyPine", pineColor * 0.8, bushRoughness),
	mat("leafyPineSmall", pineColor, bushRoughness),
	mat("pine", pineColor, bushRoughness),
	--mat("darkBush", vec3(0.05,0.15,0.07), 0.8),
	mat("darkBush", vec3(0.05,0.15,0.07) * 0.5, bushRoughness),
	mat("leafyDarkBush", vec3(0.05,0.15,0.07) * 0.5, bushRoughness),
	mat("darkBushDecal", vec3(0.05,0.15,0.07) * 0.5, bushRoughness),
	--mat("leafyBushAspen", vec3(0.4,0.3,0.1), bushRoughness),
	--mat("bushAspen", vec3(0.4,0.3,0.1), bushRoughness),
	mat("palmLeaves", vec3(0.25,0.3,0.15), bushRoughness),
	mat("grass", vec3(0.15,0.25,0.06) * 0.5, grassRoughness),

	mat("dirt", standardDirtColor, 1.0),
	mat("richDirt", terrain_richDirtColor, 1.0),
	mat("poorDirt", terrain_poorDirtColor, 1.0),

	mat("terrain_dirt", terrain_standardDirtColor, 1.0),
	mat("terrain_richDirt", terrain_richDirtColor, 1.0),
	mat("terrain_poorDirt", terrain_poorDirtColor, 1.0),

	mat("clay", clayColor, 1.0),
	mat("terrain_clay", mix(clayColor * 0.8, terrain_standardDirtColor, 0.6), 1.0),
	mat("clayWet", clayColor * 0.3, 0.1),
	mat("clayDarker", clayColor * 0.8, 1.0),
	mat("clayDarkerWet", clayColor * 0.8 * 0.3, 0.1),
	mat("clayTerrain", clayColor, 1.0),
	mat("copperOre", mix(copperOreColor, rockColor, 0.2), 1.0, 1.0),
	mat("terrain_copperOre", mix(vec3(0.1,0.37,0.32), rockColor, 0.7), 1.0, 0.0),
	mat("tinOre", mix(tinOreColor, rockColor, 0.2), 1.0, 1.0),
	mat("terrain_tinOre", mix(vec3(0.15,0.25,0.36), rockColor, 0.7), 1.0, 0.0),
	mat("bronze", bronzeColor, 0.0, 1.0),

	mat("ui_bronze", uiBronzeColor, 0.3, 1.0),
	mat("ui_bronze_lighter", mjm.mix(uiBronzeColor, vec3(1.0,1.0,1.0), 0.1) * 1.1, 0.3, 1.0),
	mat("ui_bronze_roughText", mjm.mix(uiBronzeColor, vec3(1.0,1.0,1.0), 0.1) * 1.2, 0.5, 1.0),
	mat("ui_bronze_lightest", mjm.mix(uiBronzeColor, vec3(1.0,1.0,1.0), 0.2) * 1.2, 0.5, 1.0),

	mat("ui_bronze_disabled", vec3(0.1,0.1,0.1), 0.5, 1.0),

	mat("ui_bronze_severeNegative",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.severeNegative)	, 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_bronze_moderateNegative",	mjm.mix(uiBronzeColor, getMoodColor(moodColors.moderateNegative), 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_bronze_mildNegative",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.mildNegative)	, 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_bronze_mildPositive",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.mildPositive)	, 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_bronze_moderatePositive",	mjm.mix(uiBronzeColor, getMoodColor(moodColors.moderatePositive), 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_bronze_severePositive",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.severePositive)	, 0.3) * 0.5, 	0.3, 1.0),

	mat("ui_bronze_lightest_severeNegative",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.severeNegative)	 , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_bronze_lightest_moderateNegative",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.moderateNegative) , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_bronze_lightest_mildNegative",			mjm.mix(uiBronzeColor, getMoodColor(moodColors.mildNegative)	 , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_bronze_lightest_mildPositive",			mjm.mix(uiBronzeColor, getMoodColor(moodColors.mildPositive)	 , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_bronze_lightest_moderatePositive",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.moderatePositive) , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_bronze_lightest_severePositive",		mjm.mix(uiBronzeColor, getMoodColor(moodColors.severePositive)	 , 0.99) * 1.0, 	0.3, 1.0),
	

	mat("ui_iron", uiIronColor, 0.3, 1.0),
	mat("ui_iron_lighter", mjm.mix(uiIronColor, vec3(1.0,1.0,1.0), 0.1) * 1.1, 0.3, 1.0),
	mat("ui_iron_roughText", mjm.mix(uiIronColor, vec3(1.0,1.0,1.0), 0.1) * 1.2, 0.5, 1.0),
	mat("ui_iron_lightest", mjm.mix(uiIronColor, vec3(1.0,1.0,1.0), 0.2) * 1.2, 0.5, 1.0),

	mat("ui_iron_disabled", vec3(0.1,0.1,0.1), 0.5, 1.0),

	mat("ui_iron_severeNegative",		mjm.mix(uiIronColor, getMoodColor(moodColors.severeNegative)	, 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_iron_moderateNegative",	mjm.mix(uiIronColor, getMoodColor(moodColors.moderateNegative), 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_iron_mildNegative",		mjm.mix(uiIronColor, getMoodColor(moodColors.mildNegative)	, 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_iron_mildPositive",		mjm.mix(uiIronColor, getMoodColor(moodColors.mildPositive)	, 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_iron_moderatePositive",	mjm.mix(uiIronColor, getMoodColor(moodColors.moderatePositive), 0.3) * 0.5, 	0.3, 1.0),
	mat("ui_iron_severePositive",		mjm.mix(uiIronColor, getMoodColor(moodColors.severePositive)	, 0.3) * 0.5, 	0.3, 1.0),

	mat("ui_iron_lightest_severeNegative",		mjm.mix(uiIronColor, getMoodColor(moodColors.severeNegative)	 , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_iron_lightest_moderateNegative",		mjm.mix(uiIronColor, getMoodColor(moodColors.moderateNegative) , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_iron_lightest_mildNegative",			mjm.mix(uiIronColor, getMoodColor(moodColors.mildNegative)	 , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_iron_lightest_mildPositive",			mjm.mix(uiIronColor, getMoodColor(moodColors.mildPositive)	 , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_iron_lightest_moderatePositive",		mjm.mix(uiIronColor, getMoodColor(moodColors.moderatePositive) , 0.99) * 1.0, 	0.3, 1.0),
	mat("ui_iron_lightest_severePositive",		mjm.mix(uiIronColor, getMoodColor(moodColors.severePositive)	 , 0.99) * 1.0, 	0.3, 1.0),

	mat("terracotta", vec3(0.45,0.28,0.22), 1.0),
	mat("terracottaDarkish", vec3(0.45,0.28,0.22) * 0.4 + vec3(0.1,0.0,0.0), 0.4),
	mat("terracottaDark", vec3(0.45,0.24,0.22) * 0.2 + vec3(0.1,0.0,0.0), 0.1),
	mat("hay", vec3(0.35,0.31,0.28) * 1.2, 1.0),
	mat("thatch", thatchBaseColor, 1.0),
	mat("thatchDecal", thatchBaseColor * 1.2, 1.0),
	mat("thatchDecalShort", thatchBaseColor * 1.2, 1.0),
	mat("thatchDecal075", thatchBaseColor * 1.2, 1.0),
	mat("thatchDecalLonger", thatchBaseColor * 1.2, 1.0),
	mat("thatchDecalLongerLonger", thatchBaseColor * 1.2, 1.0),
	mat("thatchThinDecal", thatchBaseColor * 1.2, 1.0),
	mat("thatchDecalTip", thatchBaseColor * 1.2, 1.0),
	mat("thatchEdgeDecal", thatchBaseColor * 1.2, 1.0),
	
	mat("hayNoDecal", vec3(0.35,0.31,0.28) * 1.2, 1.0),
	mat("haySmaller", vec3(0.35,0.31,0.28) * 1.2, 1.0),
	mat("hayRotten", vec3(0.35,0.31,0.28) * 0.5, 1.0),
	mat("greenHay", vec3(0.12,0.16,0.07) * 2.0, 1.0),
	mat("greenHayNoDecal", vec3(0.12,0.16,0.07) * 2.0, 1.0),
	mat("cactus", vec3(0.25,0.3,0.25), 0.6),
	mat("sand", sandColor, 0.7),
	mat("terrain_sand", mix(sandColor, rockColor, 0.6), 1.0),

	
	
	mat("gravel", vec3(0.2, 0.2, 0.2), 0.9),
	mat("riverSand", riverSandColor, 0.9),
	mat("terrain_riverSand", mix(riverSandColor, rockColor, 0.6), 1.0),
	mat("redSand", redSandColor, 0.9),
	mat("desertRedSand", redSandColor + vec3(0.0,0.1,0.1), 0.9),
	mat("terrain_desertRedSand", mix(redSandColor + vec3(0.0,0.1,0.1), rockColor, 0.6), 1.0),
	mat("rock", rockColor, 0.8),
	mat("terrain_rock", rockColor, 0.7),
	mat("limestone", limestoneColor, 1.0),
	mat("terrain_limestone", mix(limestoneColor, rockColor, 0.6), 1.0),
	mat("sandstoneYellowRock", getSandstoneColor(vec3(0.44,0.35,0.2)), 1.0),
	mat("terrain_sandstoneYellowRock", mix(getSandstoneColor(vec3(0.44,0.35,0.2)), rockColor, 0.7), 1.0),
	mat("sandstoneRedRock", getSandstoneColor(vec3(0.38,0.2,0.2)), 1.0),
	mat("terrain_sandstoneRedRock", mix(getSandstoneColor(vec3(0.38,0.2,0.2)), rockColor, 0.7), 1.0),
	mat("sandstoneOrangeRock", getSandstoneColor(vec3(0.44,0.3,0.2) * 0.8), 1.0),
	mat("terrain_sandstoneOrangeRock", mix(getSandstoneColor(vec3(0.44,0.3,0.2) * 0.8), rockColor, 0.7), 1.0),
	mat("sandstoneBlueRock", getSandstoneColor(vec3(0.34,0.38,0.44)), 1.0),
	mat("terrain_sandstoneBlueRock", mix(getSandstoneColor(vec3(0.34,0.38,0.44)), rockColor, 0.7), 1.0),
	mat("snow", vec3(1.0,1.0,1.0) * 0.55, 0.5),
	mat("snowPine", vec3(1.0,1.0,1.0) * 0.55, 0.5),
	mat("water", vec3(0.0, 0.04, 0.01), 0.0),
	mat("wood", vec3(0.4,0.32,0.25) * 0.6, 0.9),
	mat("endStatus", vec3(0.4,0.32,0.25) * 0.6, 0.9),
	matWithB("willowWood", vec3(0.4,0.4,0.27) * 0.6, 0.9, vec3(0.4,0.4,0.35) * 0.7, 0.95),
	mat("lightWood", vec3(0.3,0.25,0.2) * 1.2, 0.7),
	mat("rottenWood", vec3(0.12,0.14,0.18) * 0.5, 0.9),

	mat("coralRed", vec3(0.45, 0.15, 0.1), 1.0),
	mat("coralBlue", vec3(0.1, 0.2, 0.45), 1.0),

	mat("seaweed1", vec3(0.02,0.1,0.0), 1.0),
	mat("seaweed2", vec3(0.0,0.1,0.03), 1.0),
	
	
	mat("mortar", limestoneColor, 1.0),

	mat("mudBrick", vec3(0.45, 0.4, 0.35) * 0.5, 0.3),

	mat("mudBrickWet_sand", vec3(0.45, 0.4, 0.35) * 0.5, 0.3),
	mat("mudBrickWet_riverSand", vec3(0.37, 0.36, 0.35) * 0.5, 0.3),
	mat("mudBrickWet_redSand", redSandColor * 0.5, 0.3),
	mat("mudBrickWet_hay", vec3(0.35,0.31,0.28) * 0.7, 0.3),

	matWithB("mudBrickDry_sand", vec3(0.45, 0.4, 0.35) * 0.8, 1.0, vec3(0.45, 0.4, 0.35), 1.0),
	matWithB("mudBrickDry_riverSand", vec3(0.37, 0.36, 0.35) * 0.8, 1.0, vec3(0.37, 0.36, 0.35), 1.0),
	matWithB("mudBrickDry_redSand", redSandColor * 0.8, 1.0, redSandColor, 1.0),
	matWithB("mudBrickDry_hay", vec3(0.49,0.43,0.39) * 0.8, 1.0, vec3(0.49,0.43,0.39), 1.0),

	mat("brick", vec3(0.45,0.28,0.22), 0.4),
	
	mat("firedBrick_sand", mix(vec3(0.5,0.5,0.5), vec3(0.45,0.28,0.22), 0.3), 1.0),
	mat("firedBrick_riverSand", mix(vec3(0.5,0.5,0.5), vec3(0.35,0.23,0.24), 0.5), 1.0),
	mat("firedBrick_redSand", mix(vec3(0.51,0.52,0.5) * 0.8, redSandColor * 0.8, 0.6), 1.0),
	mat("firedBrick_hay", mix(vec3(0.5,0.5,0.5), vec3(0.47,0.28,0.18), 0.3), 1.0),
	
	mat("firedBrickDark_sand", vec3(0.45,0.28,0.22) * 0.6, 0.1), --unused?
	mat("firedBrickDark_riverSand", vec3(0.33,0.23,0.24) * 0.6, 0.1), --unused?
	mat("firedBrickDark_redSand", redSandColor * 0.6, 0.1), --unused?
	mat("firedBrickDark_hay", vec3(0.47,0.30,0.18) * 0.6, 0.1), --unused?

	mat("snowGrass", vec3(1.0,1.0,1.0) * 0.55, 0.5),
	mat("grassSnowTerrain", vec3(1.0,1.0,1.0) * 0.55, 0.5),
	mat("darkGrassPokingThroughSnow", temperateGrassBaseColor * 0.5 + vec3(0.1,0.1,0.1), 1.0),

	mat("dirtTop", vec3(0.3,0.23,0.18) * 1.04, 0.9),

	mat("steppeGrass", mediterrainianGrassBaseColor, grassRoughness),

	mat("tropicalRainforestGrass", 			vec3(0.05,0.19,0.03) * 										grassLightness * 0.8, grassRoughness),
	mat("tropicalRainforestGrassTops", 		(vec3(0.05,0.19,0.03) + vec3(0.16, 0.12, 0.1) * 0.4) * 		grassLightness * 0.8, grassTopsRoughness),
	mat("tropicalRainforestTallGrassTops", 	(vec3(0.0,0.13,0.0)) 								, grassTopsRoughness),
	mat("tropicalRainforestGrassRich", 		vec3(0.05,0.19,0.03) * 										grassLightness * 0.7, grassRoughness),
	mat("tropicalRainforestGrassRichTops", 	(vec3(0.05,0.19,0.03) + vec3(0.16, 0.12, 0.1) * 0.4) * 		grassLightness * 0.7, grassTopsRoughness),
	mat("tropicalHardGrass", 	(vec3(0.14,0.0,0.07)) 								, grassRoughness * 0.6),

	

	mat("savannaGrass", vec3(mediterrainianGrassBaseColor.x * 0.65, mediterrainianGrassBaseColor.y * 0.85, mediterrainianGrassBaseColor.z * 0.55), grassRoughness),
	mat("tundraGrass", tundraGrassBaseColor, grassRoughness),
	mat("tundraGrassPlentiful", vec3(tundraGrassBaseColor.x * 0.8, tundraGrassBaseColor.y * 0.9, tundraGrassBaseColor.z * 0.75), grassRoughness),

	--mat("desertRedSand", vec3(0.75, 0.5, 0.35), 0.7),
	mat("taigaGrass", vec3(0.18,0.19,0.1), grassRoughness),

	mat("mediterraneanGrass", mediterrainianGrassBaseColor, grassRoughnessDry),
	mat("mediterraneanGrassTops", (mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1)), grassTopsRoughnessDry),
	mat("mediterraneanGrassTopsB", (mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1)) * 1.1, grassTopsRoughnessDryB),
	mat("mediterraneanDarkGrassTops", (vec3(0.24, 0.22, 0.2) * 0.5), grassTopsRoughnessDryB),
	mat("mediterraneanGrassSeedHeads", (vec3(0.46, 0.43, 0.36)), grassTopsRoughnessDryB),

	mat("new_grassSeedHeads", (vec3(0.66, 0.41, 0.24) * 1.5), grassTopsRoughnessDry),

	mat("mediterraneanGrassPlentiful", vec3(mediterrainianGrassBaseColor.x * 0.8, mediterrainianGrassBaseColor.y * 0.9, mediterrainianGrassBaseColor.z * 0.75), grassRoughnessDry),
	mat("mediterraneanGrassTopsPlentiful", (vec3(mediterrainianGrassBaseColor.x * 0.8, mediterrainianGrassBaseColor.y * 0.9, mediterrainianGrassBaseColor.z * 0.75) + vec3(0.16, 0.12, 0.1)), grassTopsRoughnessDry),
	
	mat("savannaGrass", savannaGrassBaseColor, grassRoughnessDry),
	mat("savannaGrassTops", (savannaGrassBaseColor + vec3(0.16, 0.12, 0.1)), grassTopsRoughnessDry),
	mat("savannaGrassTopsB", (savannaGrassBaseColor + vec3(0.16, 0.12, 0.1)) * 1.1, grassTopsRoughnessDryB),
	mat("savannaDarkGrassTops", (vec3(0.24, 0.22, 0.2) * 0.5), grassTopsRoughnessDryB),
	mat("savannaGrassSeedHeads", (vec3(0.46, 0.43, 0.36)), grassTopsRoughnessDryB),

	mat("savannaGrassPlentiful", vec3(savannaGrassBaseColor.x * 0.8, savannaGrassBaseColor.y * 0.9, savannaGrassBaseColor.z * 0.75), grassRoughnessDry),
	mat("savannaGrassTopsPlentiful", (vec3(savannaGrassBaseColor.x * 0.8, savannaGrassBaseColor.y * 0.9, savannaGrassBaseColor.z * 0.75) + vec3(0.16 * 1.5, 0.12 * 1.5, 0.1)), grassTopsRoughnessDry),
	
	mat("yellowGrassTops", vec3(0.17,0.15,0.08), grassTopsRoughness),
	mat("darkGrassTops", vec3(0.17,0.15,0.02), grassTopsRoughness),
	mat("dryGrass", vec3(0.4,0.45,0.25), grassRoughness),
	mat("dirtGrass", vec3(0.29,0.23,0.18) * 1.4, grassTopsRoughness),

	mat("redRock", redRockColor, 0.4),
	mat("terrain_redRock", mix(redRockColor, rockColor, 0.5), 0.7),
	mat("greenRock", greenRockColor, 0.4),
	mat("terrain_greenRock", mix(greenRockColor, rockColor, 0.5), 0.7),
	mat("graniteRock", graniteRockColor, 0.4),
	mat("terrain_graniteRock", mix(graniteRockColor, rockColor, 0.5), 0.7),
	mat("marbleRock", marbleRockColor, 0.25),
	mat("terrain_marbleRock", mix(marbleRockColor, rockColor, 0.5), 0.7),
	mat("lapisRock", lapisRockColor, 0.4),
	mat("terrain_lapisRock", mix(lapisRockColor, rockColor, 0.5), 0.7),

	mat("steppeGrassTops", (mediterrainianGrassBaseColor + vec3(0.01,0.0,0.0)) * 1.1, grassTopsRoughness),
	mat("steppeGrassTopsB", (mediterrainianGrassBaseColor + vec3(0.01,0.02,0.0)), grassTopsRoughness),
	
	mat("temperateGrass", vec3(0.12,0.17,0.07) * grassLightness * 1.2, grassRoughness),
	mat("temperateGrassTops", vec3(0.12  + 0.02,0.17 + 0.015,0.07 + 0.01) * grassLightness * 1.1, grassTopsRoughness),
	mat("temperateGrassTopsB", vec3(0.12  + 0.02,0.17 + 0.015,0.07 + 0.01) * grassLightness * 1.2, grassTopsRoughnessB),

	mat("temperateGrassRich", vec3(0.08,0.15,0.05) * grassLightness * 1.2, grassRoughness),
	mat("temperateGrassRichTops", vec3(0.08 + 0.01,0.15  + 0.01,0.05) * grassLightness * 1.25, grassTopsRoughness),
	mat("temperateGrassRichTopsB", vec3(0.08 + 0.01,0.15 + 0.01,0.05) * grassLightness * 1.3, grassTopsRoughnessB),

	mat("temperateGrassWinter", winterGrassColor * grassLightness * 1.0, grassRoughness),
	mat("temperateGrassWinterTops", winterGrassColor * grassLightness * 1.1, grassTopsRoughness),
	mat("temperateGrassWinterTopsB", winterGrassColor * grassLightness * 1.2, grassTopsRoughness),

	--mat("skin", vec3(0.5, 0.38, 0.32), 0.5),
	mat("skinLightest", vec3(0.4, 0.3, 0.25) * 1.2, skinRoughness),
	mat("skinLighter", vec3(0.4, 0.3, 0.25) * 1.1, skinRoughness),
	mat("skinLight", vec3(0.4, 0.3, 0.25) * 1.0, skinRoughness),
	mat("skin", vec3(0.4, 0.3, 0.25) * 0.9, skinRoughness),
	mat("skinDark", vec3(0.4, 0.3, 0.25) * 0.8, skinRoughness),
	mat("skinDarker", vec3(0.4, 0.285, 0.21) * 0.6, skinRoughness),
	mat("skinDarkest", vec3(0.4, 0.271, 0.19) * 0.4, skinRoughness),
	--mat("skin", vec3(0.3, 0.4, 0.8), 1.0),

	mat("hair", vec3(0.1, 0.05, 0.03), hairRoughness),
	mat("hairDarker", vec3(0.1, 0.05, 0.03) * 0.5, hairRoughness),
	mat("hairDarkest", vec3(0.0, 0.0, 0.0), hairRoughness),
	mat("hairRed", vec3(0.2, 0.12, 0.05), hairRoughness),
	mat("hairBlond", vec3(0.3, 0.25, 0.2), hairRoughness),

	mat("greyHair", vec3(0.4, 0.4, 0.4), 0.9),
	mat("eyes", vec3(0.6, 0.6, 0.6), 0.0),
	mat("pupil", vec3(0.0, 0.0, 0.0), 0.0),

	
	mat("eyeBall", vec3(0.08, 0.2, 0.15), 0.0),
	mat("eyeBallLightBrown", vec3(0.15, 0.15, 0.05), 0.0),
	mat("eyeBallDarkBrown", vec3(0.1, 0.08, 0.0), 0.3),
	mat("eyeBallBlue", vec3(0.15, 0.2, 0.3) * 1.5, 0.0),
	mat("eyeBallBlack", vec3(0.0, 0.0, 0.0), 0.1),
	mat("mouthLighter", vec3(0.35, 0.21, 0.2) * 1.4, 0.7),
	mat("mouth", vec3(0.35, 0.21, 0.2), 0.7),
	mat("mouthDarker", vec3(0.3, 0.15, 0.18) * 0.5, 0.7),

	mat("raspberryBush", vec3(0.1,0.2,0.08), bushRoughness),
	mat("raspberryBush_low", vec3(0.1,0.2,0.08), bushRoughness),

	mat("shrub", vec3(0.05,0.15,0.07), bushRoughness),
	mat("shrub_low", vec3(0.05,0.15,0.07), bushRoughness),
	mat("orangeTreeFoliageNoBush", vec3(0.05,0.15,0.07), bushRoughness),
	mat("orangeTreeFoliage", vec3(0.05,0.15,0.07), bushRoughness),
	mat("raspberry", vec3(0.3,0.05,0.1), 0.5),
	mat("raspberryRotten", vec3(0.3,0.05,0.1) * 0.2, 0.8),
	mat("gooseberry", vec3(0.3,0.4,0.3), 0.2),
	mat("gooseberryRotten", vec3(0.3,0.4,0.3) * 0.2, 0.6),
	mat("yellowFlower", vec3(1.0,0.7,0.0), 0.8),
	mat("whiteFlower", vec3(0.9,0.9,0.8), 0.8),
	mat("blueFlower", vec3(0.5,0.4,0.8) * 0.8, 0.8),
	mat("pinkFlower", vec3(0.8,0.4,0.5) * 0.8, 0.8),
	mat("blueFlowerB", vec3(0.8,0.5,0.6) * 0.6, 0.8),
	mat("blueFlowerC", vec3(0.8,0.6,0.7) * 0.6, 0.8),
	mat("lightOrangeFlower", vec3(0.8,0.25,0.1), 0.8),
	mat("seed", vec3(0.1,0.08,0.06), 0.8),
	mat("seedRotten", vec3(0.4,0.4,0.4), 0.8),
	mat("flaxSeed", vec3(0.28,0.16,0.06), 0.3),
	mat("yellowSeed", vec3(0.6,0.4,0.06), 0.8),
	mat("redFlower", vec3(0.5,0.0,0.0), 0.8),
	mat("poppyCenter", vec3(0.0,0.0,0.0), 1.0),
	mat("poppyCenterRotten", vec3(0.2,0.2,0.2), 1.0),
	mat("poppyRotten", vec3(0.2,0.1,0.1), 0.8),
	mat("beetroot", vec3(0.3,0.0,0.1), 0.6),
	mat("beetrootRotten", vec3(0.3,0.2,0.1) * 0.5, 0.6),
	mat("beetleaf", vec3(0.2,0.33,0.1), 0.8),
	mat("beetrootCooked", vec3(0.3,0.0,0.1) * 0.2, 0.6),
	mat("marigold", vec3(0.5,0.3,0.0), 0.3),
	mat("marigoldCenter", vec3(0.4,0.1,0.0), 1.0),
	mat("marigoldCenterRotten", vec3(0.4,0.1,0.0) * 0.2, 1.0),
	mat("marigoldRotten", vec3(0.5,0.2,0.2) * 0.3, 0.8),
	mat("echinacea", vec3(0.45,0.05,0.4), 0.3),
	mat("echinaceaCenter", vec3(0.3,0.1,0.0), 1.0),
	mat("echinaceaCenterRotten", vec3(0.3,0.1,0.0) * 0.2, 1.0),
	mat("echinaceaRotten", vec3(0.2,0.1,0.2), 1.0),
	
	mat("poppy", vec3(0.5,0.0,0.0), 0.8),
	mat("poppyPetals", vec3(0.5,0.0,0.0), 0.8),
	
	mat("echinaceaPetals", vec3(0.45,0.05,0.4), 0.3),
	mat("sunflowerPetals", vec3(0.8,0.5,0.3), 0.5),
	mat("marigoldPetals", vec3(0.5,0.3,0.0), 0.3),
	
	
	mat("gingerLeaf", vec3(0.15,0.35,0.1) * 0.6, 0.6),
	mat("gingerFlower", vec3(0.6,0.1,0.1), 0.6),
	mat("gingerRoot", vec3(0.3,0.24,0.15) * 1.5, 1.0),
	matWithB("gingerRootRotten", vec3(0.32,0.28,0.2), 1.0, vec3(0.3,0.24,0.15) * 1.5, 1.0),
	mat("gingerRootBark", vec3(0.3,0.24,0.15) * 0.5, 1.0),
	
	mat("turmericLeaf", vec3(0.15,0.35,0.1) * 0.8, 0.6),
	mat("turmericFlower", vec3(0.4,0.1,0.4), 0.6),
	mat("turmericRoot", vec3(0.39,0.22,0.02) * 1.5, 1.0),
	mat("turmericRootBark", vec3(0.39,0.22,0.2) * 0.5, 1.0),
	mat("turmericRootRotten", vec3(0.32,0.28,0.2), 1.0),

	mat("darkPlantStalks", vec3(0.05,0.0,0.0), 0.8),
	
	mat("garlicLeaf", vec3(0.12,0.35,0.3), 0.6),
	mat("garlicFlower", vec3(0.4,0.3,0.5), 0.9),
	matWithB("garlic", vec3(0.8,0.8,0.6), 1.0, vec3(1,0.7,0.89), 1.0),
	matWithB("garlicRotten", vec3(0.8,0.8,0.6), 1.0, vec3(0.32,0.28,0.2), 1.0),
	
	mat("aloeLeaf", vec3(0.15,0.35,0.2), 0.6),
	mat("aloeLeafNoDecal", vec3(0.15,0.35,0.2), 0.6),
	mat("aloeLeafRotten", vec3(0.15,0.35,0.2) * 0.3, 0.6),
	
	mat("wheatLeaf", mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1), grassTopsRoughnessDry),
	mat("wheatLeafSapling", vec3(0.08 + 0.01,0.15  + 0.01,0.05) * grassLightness * 1.25, 0.6),

	mat("wheatFlower", mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1), grassTopsRoughnessDry),
	mat("wheatFlowerDecal", mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1), grassTopsRoughnessDry),
	mat("wheatGrain", mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1), grassTopsRoughnessDry),
	mat("wheatGrainRotten", vec3(0.3,0.3,0.3), grassTopsRoughnessDry),
	mat("wheatRotten", (mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1)) * 0.3, grassTopsRoughnessDry),
	
	mat("flaxLeaf", vec3(0.12,0.19,0.07) * grassLightness * 0.7, grassTopsRoughnessDry),
	mat("flaxLeafSapling", vec3(0.12,0.19,0.07) * grassLightness * 0.7, 0.6),

	mat("flaxFlower", vec3(0.12,0.19,0.07) * grassLightness * 0.7, 1.0),
	mat("flaxRotten", (vec3(0.12,0.19,0.07) * grassLightness * 0.7) * 0.3, grassTopsRoughnessDry),

	
	mat("poppyLeaf", vec3(0.13,0.19,0.07) * 0.8, 1.0),
	mat("poppyLeafSapling", vec3(0.13,0.19,0.07) * 0.8, 1.0),

	mat("marigoldLeaf", vec3(0.13,0.25,0.07) * 0.4, 1.0),
	mat("marigoldLeafSapling", vec3(0.13,0.25,0.07) * 0.4, 1.0),

	mat("echinaceaLeaf", vec3(0.13,0.22,0.1) * 0.8, 1.0),
	mat("echinaceaLeafSapling", vec3(0.13,0.22,0.1) * 0.8, 1.0),

	mat("flour",vec3(0.65,0.65,0.6), 1.0),
	mat("flourRotten",vec3(0.1,0.2,0.1), 1.0),
	mat("breadDough",vec3(0.65,0.65,0.6), 1.0),
	mat("breadDoughRotten",vec3(0.5,0.5,0.5), 1.0),
	mat("bread",vec3(0.7,0.55,0.3) * 1.0, 1.0),
	mat("darkBread",vec3(0.7,0.55,0.1) * 0.4, 1.0),
	mat("rottenBread", vec3(0.5,0.5,0.5), 1.0),
	mat("darkRottenBread", vec3(0.05,0.3,0.05), 1.0),
	
	mat("injuryMedicine",vec3(0.2,0.0,0.1), 1.0),
	mat("burnMedicine",vec3(0.3,0.1,0.1), 1.0),
	mat("foodPoisoningMedicine",vec3(0.2,0.25,0.15), 1.0),
	mat("virusMedicine",vec3(0.25,0.2,0.3), 1.0),

	mat("medicineRotten",vec3(0.2,0.1,0.0), 1.0),

	mat("lightRed", vec3(1.0,0.5,0.5), 0.8),
	mat("red", vec3(1.0,0.0,0.0), 0.8),
	mat("darkRed", vec3(0.5,0.0,0.0), 0.8),
	
	mat("lightGreen", vec3(0.5,1.0,0.5), 0.8),
	mat("green", vec3(0.0,1.0,0.0), 0.8),
	mat("darkGreen", vec3(0.0,0.5,0.0), 0.8),

	mat("lightBlue", vec3(0.5,0.5,1.0), 0.8),
	mat("blue", vec3(0.0,0.0,1.0), 0.8),
	mat("darkBlue", vec3(0.0,0.0,0.5), 0.8),
	
	mat("paleGrey", vec3(0.5,0.5,0.5), 1.0),
	mat("paleBlue", vec3(0.3,0.3,0.7), 1.0),
	mat("paleGreen", vec3(0.3,0.7,0.3), 1.0),
	mat("paleYellow", vec3(0.7,0.7,0.3), 1.0),
	mat("paleMagenta", vec3(0.7,0.3,0.7), 1.0),

	mat("vrObjects", vec3(0.05,0.05,0.05), 0.6),
	

	mat("building", vec3(0.5,0.5,0.5), 1.0),
	mat("matBlack", vec3(0.0,0.0,0.0), 1.0),
	
	mat("manure", vec3(0.08, 0.05, 0.03), 0.7),
	mat("manureRotten", vec3(0.4, 0.4, 0.4), 1.0),
	
	mat("compost", vec3(0.2,0.16 * 0.5,0.12 * 0.5) * 0.7, 0.6),
	mat("compostRotten", vec3(0.2,0.16 * 0.5,0.12 * 0.5) * 0.7 * 0.5 + vec3(0.2, 0.2, 0.2), 1.0),
	
	mat("rottenGoo",vec3(0.1,0.05,0.0),1.0),
	

	mat("apple", vec3(0.5,0.0,0.0), 0.1),
	mat("appleRotten", vec3(0.1,0.0,0.0), 0.6),
	mat("orange", vec3(0.5,0.2,0.0), 0.5),
	mat("orangeRotten", vec3(0.5,0.2,0.0) * 0.2, 0.5),
	mat("peach", vec3(0.5,0.3,0.2), 0.9),
	mat("peachRotten", vec3(0.5,0.3,0.2) * 0.2, 0.9),
	mat("banana", vec3(0.5,0.4,0.0), 0.6),
	mat("bananaRotten", vec3(0.1,0.08,0.0), 0.6),
	mat("elderberry", vec3(0.08,0.0,0.08), 0.1),
	mat("elderberryRotten", vec3(0.0,0.0,0.01), 0.9),
	
	mat("coconut", vec3(0.24, 0.15, 0.1) * 0.5, 1.0),
	mat("coconutRotten", vec3(0.1, 0.1, 0.1) * 1.0, 1.0),
	matWithB("coconutLeafNoBush", vec3(0.25,0.39,0.15) * 0.5, bushRoughness * 0.75, vec3(0.25,0.39,0.15) * 1.5, bushRoughness * 0.4),
	matWithB("coconutLeaf", vec3(0.25,0.39,0.15) * 0.5, bushRoughness * 0.75, vec3(0.25,0.39,0.15) * 1.5, bushRoughness * 0.4),
	matWithB("coconutLeafSmall", vec3(0.25,0.39,0.15) * 0.5, bushRoughness * 0.75, vec3(0.25,0.39,0.15) * 1.5, bushRoughness * 0.4),
	mat("coconutBark", vec3(0.17, 0.16, 0.17) * 1.0, 1.0),
	mat("coconutWood", vec3(0.28, 0.2, 0.15) * 1.5, 0.8),
	
	mat("pumpkin", vec3(0.48, 0.2, 0.05), 0.5),
	mat("pumpkinRotten", vec3(0.48, 0.4, 0.05) * 0.2, 0.8),
	mat("pumpkinLeaf", vec3(0.1,0.2,0.05), 0.6),
	mat("pumpkinCooked", vec3(0.48, 0.2, 0.05) * 0.2, 0.5),
	
	mat("appleBark", vec3(0.22,0.2,0.16) * 0.2, 1.0),
	mat("appleWood", vec3(0.22,0.25,0.16) * 1.5, 0.5),
	mat("orangeBark", vec3(0.28,0.2,0.12) * 0.4, 1.0),
	mat("orangeWood", vec3(0.32,0.24,0.02), 0.5),
	mat("peachBark", vec3(0.34,0.2,0.12) * 0.6, 1.0),
	mat("peachWood", vec3(0.34,0.14,0.06) * 1.5, 0.5),
	mat("elderberryBark", vec3(0.18,0.05,0.22) * 0.05, 1.0),
	mat("elderberryWood", vec3(0.18,0.15,0.22) * 0.8, 0.3),

	mat("mammoth", mammothColor, 1.0),
	mat("mammothFur1", mammothColor, 1.0),
	mat("mammothEyeArea", mammothColor * 0.2, 1.0),
	mat("mammothEye", vec3(0.2, 0.15, 0.05), 0.1),
	mat("mammothHide", mammothColor, 1.0),
	mat("mammoth_tusk", vec3(0.8, 0.8, 0.8), 0.2),
	mat("tusk", vec3(0.8, 0.8, 0.8), 0.2),
	
	--mat("alpaca", vec3(0.1, 0.09, 0.08) * 1.1, 1.0),
	--mat("alpacaWool", vec3(0.1, 0.09, 0.08) * 1.1, 1.0),
	--mat("alpacaWoolNoDecal", vec3(0.1, 0.09, 0.08) * 1.1, 1.0),
	
	matWithB("alpaca", vec3(0.1, 0.09, 0.08), 1.0, vec3(1,0.6,0.35), 1.0),
	matWithB("alpacaWool", vec3(0.1, 0.09, 0.08), 1.0, vec3(1,0.6,0.35) * 0.1 + vec3(0.18,0.14,0.08), 1.0),
	matWithB("alpacaWoolNoDecal", vec3(0.1, 0.09, 0.08), 1.0, vec3(1,0.6,0.35) * 0.1 + vec3(0.18,0.14,0.08), 1.0),
	matWithB("alpaca_head", vec3(0.0, 0.0, 0.0), 1.0, vec3(0.69,0.5,0.28), 1.0),
	
	matWithB(           "alpaca_white", alpaca_white_colorA, 1.0, alpaca_white_colorB, 1.0),
	matWithB(       "alpacaWool_white", alpaca_white_colorA, 1.0, alpaca_white_colorB, 1.0),
	matWithB("alpacaWoolNoDecal_white", alpaca_white_colorA, 1.0, alpaca_white_colorB, 1.0),
	matWithB(      "alpaca_head_white", vec3(0.0, 0.0, 0.0), 1.0, vec3(0.4,0.4,0.4), 1.0),

	matWithB(           "alpaca_black", alpaca_black_colorA, 1.0, alpaca_black_colorB, 1.0),
	matWithB(       "alpacaWool_black", alpaca_black_colorA, 1.0, alpaca_black_colorB, 1.0),
	matWithB("alpacaWoolNoDecal_black", alpaca_black_colorA, 1.0, alpaca_black_colorB, 1.0),
	matWithB(      "alpaca_head_black", vec3(0.3, 0.3, 0.3), 1.0, vec3(0.0, 0.0, 0.0), 1.0),

	matWithB(           "alpaca_red", alpaca_red_colorA, 1.0, alpaca_red_colorB, 1.0),
	matWithB(       "alpacaWool_red", alpaca_red_colorA, 1.0, alpaca_red_colorB, 1.0),
	matWithB("alpacaWoolNoDecal_red", alpaca_red_colorA, 1.0, alpaca_red_colorB, 1.0),
	matWithB(      "alpaca_head_red", vec3(0.3,0.25,0.15), 1.0, alpaca_red_colorA, 1.0),

	matWithB(           "alpaca_yellow", alpaca_yellow_colorA, 1.0, alpaca_yellow_colorB, 1.0),
	matWithB(       "alpacaWool_yellow", alpaca_yellow_colorA, 1.0, alpaca_yellow_colorB, 1.0),
	matWithB("alpacaWoolNoDecal_yellow", alpaca_yellow_colorA, 1.0, alpaca_yellow_colorB, 1.0),
	matWithB(      "alpaca_head_yellow", vec3(0.0, 0.0, 0.0), 1.0, alpaca_yellow_colorB, 1.0),

	matWithB(           "alpaca_cream", alpaca_cream_colorA, 1.0, alpaca_cream_colorB, 1.0),
	matWithB(       "alpacaWool_cream", alpaca_cream_colorA, 1.0, alpaca_cream_colorB, 1.0),
	matWithB("alpacaWoolNoDecal_cream", alpaca_cream_colorA, 1.0, alpaca_cream_colorB, 1.0),
	matWithB(      "alpaca_head_cream", vec3(0.2,0.1,0.04), 1.0, alpaca_cream_colorA, 1.0),


	matWithB("baobab_trunk", vec3(0.92,0.62,0.38), 1.0, vec3(1,0.83,0.25), 1.0),
	matWithB("baobab_foliage", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	
	matWithB("boar", vec3(0.07,0.07,0.07), 1.0, vec3(0.74,0.55,0.37), 1.0),
	matWithB("boar_teeth", vec3(0.69,0.69,0.69), 1.0, vec3(0.6,0.44,0.3), 1.0),
	matWithB("boar_mouth", vec3(0.36,0.18,0.13), 1.0, vec3(0,0.49,0.55), 1.0),

	matWithB("crocodile", vec3(0.4,0.51,0.2), 0.5, vec3(0.31,0.33,0.05), 0.5),
	matWithB("crocodile_teeth", vec3(0.4,0.51,0.2), 0.5, vec3(0.31,0.33,0.05), 0.5),

	matWithB("dodo", vec3(0.62,0.2,0.22), 1.0, vec3(0.25,0.4,0.64), 1.0),
	matWithB("dodo_beak", vec3(0,0,0), 1.0, vec3(0.72,0.59,0.29), 1.0),
	matWithB("dodo_feet", vec3(0,0.04,0.12), 1.0, vec3(0.35,0.31,0.16), 1.0),
	matWithB("dodo_baby", vec3(0.62,0.2,0.22), 1.0, vec3(0.25,0.4,0.64), 1.0),


	matWithB("crocodile", vec3(0,0.04,0.12), 1.0, vec3(0.71,0.53,0.28), 1.0),
	matWithB("crocodile_teeth", vec3(0.74,0.77,0.77), 1.0, vec3(1,0.6,0.58), 1.0),

	matWithB("cactus_flower", vec3(1.0,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0), --todo


	matWithB("zebra", vec3(0.0,0.0,0.0), 0.8, vec3(1.0,1.0,1.0), 0.8),
	matWithB("zebra_baby", vec3(0.0,0.0,0.0), 0.8, vec3(1.0,1.0,1.0), 0.8),
	
	matWithB("goat", vec3(0.7,0.33,0.09), 1.0, vec3(0.97,0.98,1), 1.0),
	matWithB("goatUdder", vec3(1,0.66,0.69), 1.0, vec3(1,0.74,0.72), 1.0),
	matWithB("goatHorn", vec3(0,0,0), 1.0, vec3(0.89,0.61,0.4), 1.0),
	
	matWithB("horse", vec3(0.21,0.11,0.04), 1.0, vec3(0.74,0.53,0.4), 1.0),
	
	matWithB("irish_elk", vec3(0.53,0.41,0.28), 1.0, vec3(0.72,0.64,0.55), 1.0),
	matWithB("irish_elk_mouth", vec3(0.18,0.07,0.02), 1.0, vec3(0.54,0.37,0.33), 1.0),
	matWithB("irish_elk_antlers", vec3(0.42,0.33,0.22), 1.0, vec3(0.02,0.02,0.02), 1.0),
	
	matWithB("sabertoothTiger", vec3(0.61,0.41,0.22), 1.0, vec3(1,0.73,0.53), 1.0),
	matWithB("sabertoothTiger_teeth", vec3(0.37,0.14,0.04), 1.0, vec3(1,0.86,0.78), 1.0),
	matWithB("sabertoothTiger_mouth", vec3(0.63,0.4,0.39), 1.0, vec3(0.45,0.33,0.24), 1.0),

	matWithB("chicken_egg", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	
	mat("mob_eye", vec3(0.0, 0.0, 0.0), 0.2),

	matWithB("catfish", vec3(0.020888, 0.024515, 0.013658), 1.0, vec3(0.462354, 0.302075, 0.110449), 1.0),
	matWithB("catfish_fins", vec3(0.078288, 0.017864, 0.016605), 0.5, vec3(1.000000, 0.473912, 0.320461), 1.0),
	matWithB("catfish_mouth", vec3(0.004, 0.004, 0.004), 0.5, vec3(0.187,0.122,0.116), 1.0),
	matWithB("catfish_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	
	matWithB("catfish_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.232354, 0.102075, 0.0), 0.5),
	matWithB("catfish_fins_cooked", vec3(0.0,0.0,0.0), 0.3, vec3(0.1,0.1,0.1), 1.0),
	
	matWithB("swordfish", vec3(0.000000, 0.063010, 0.111932), 0.5, vec3(0.783252, 0.736018, 1.000000), 0.5),
	matWithB("swordfish_fins", vec3(0.026372, 0.071456, 0.111941), 0.5, vec3(0.000000, 0.020057, 0.046964), 0.5),
	matWithB("swordfish_mouth", vec3(0.004, 0.004, 0.004), 0.5, vec3(0.083562, 0.101015, 0.132916), 1.0),
	matWithB("swordfish_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	matWithB("swordfish_fins_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	
	matWithB("redfish", vec3(0.420014, 0.059766, 0.054212), 0.5, vec3(0.462032, 0.251178, 0.237608), 0.5),
	matWithB("redfish_fins", vec3(0.729448, 0.144744, 0.132800), 0.5, vec3(0.673873, 0.078019, 0.018999), 0.5),
	matWithB("redfish_mouth", vec3(0.050876, 0.014708, 0.010473), 0.5, vec3(0.050876, 0.014708, 0.010473), 1.0),
	matWithB("redfish_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.462032, 0.251178, 0.237608) * 0.2 + vec3(0.05,0.03,0.0), 0.5),
	matWithB("redfish_fins_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.673873, 0.078019, 0.018999) * 0.2, 0.5),
	matWithB("redfish_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	
	matWithB("coelacanth", vec3(0.0,0.0,0.0), 0.5, vec3(0.420028, 0.413464, 0.394165), 0.5),
	matWithB("coelacanth_fins", vec3(0.0,0.0,0.0), 0.5, vec3(0.097900, 0.354696, 0.283882), 0.5),
	matWithB("coelacanth_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.420028, 0.413464, 0.394165) * 0.4 + vec3(0.05,0.03,0.0), 0.5),
	matWithB("coelacanth_fins_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.097900, 0.354696, 0.283882) * 0.2, 0.5),
	matWithB("coelacanth_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	matWithB("coelacanth_fins_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),

	matWithB("flagellipinna", vec3(0.348426, 0.01, 0.000000), 0.5, vec3(0.750000, 0.606995, 0.000000), 0.5),
	matWithB("flagellipinna_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.750000, 0.606995, 0.000000) * 0.4 + vec3(0.05,0.03,0.0), 0.5),
	matWithB("flagellipinna_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),

	matWithB("polypterus", vec3(0.100480, 0.031546, 0.004458), 0.5, vec3(0.823364, 0.420669, 0.099409), 0.5),
	matWithB("polypterus_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.823364, 0.420669, 0.099409) * 0.4 + vec3(0.05,0.03,0.0), 0.5),
	matWithB("polypterus_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),

	matWithB("tropicalfish", vec3(0.13152, 0.2, 0.6), 0.5, vec3(0.623364, 0.520669, 0.099409), 0.5),
	matWithB("tropicalfish_cooked", vec3(0.0,0.0,0.0), 1.0, vec3(0.623364, 0.520669, 0.099409) * 0.4 + vec3(0.05,0.03,0.0), 0.5),
	matWithB("tropicalfish_rotten", vec3(0.4,0.51,0.2), 1.0, vec3(0.31,0.33,0.05), 1.0),
	

	matWithB("fillet_raw", vec3(0.600545, 0.435951, 0.524627), 0.25, vec3(0.600545, 0.435951, 0.524627) * 1.2, 0.25),
	matWithB("fillet_raw_inner", vec3(0.600614, 0.267398, 0.310874), 0.5, vec3(0.600614, 0.267398, 0.310874) * 1.2, 0.5),
	
	matWithB("fillet_cooked", vec3(0.800924, 0.519241, 0.209086) * 0.3, 0.45, vec3(0.800924, 0.519241, 0.209086) * 0.3 * 1.2, 0.45),
	matWithB("fillet_cooked_inner", vec3(0.3,0.25,0.2), 0.5, vec3(0.3,0.25,0.2) * 1.2, 0.5),

	
	mat("clothes", vec3(0.1, 0.09, 0.08), 1.0),
	mat("clothingFur", vec3(0.1, 0.09, 0.08), 1.0),
	mat("clothingFurShort", vec3(0.1, 0.09, 0.08), 1.0),
	mat("clothesNoDecal", vec3(0.1, 0.09, 0.08), 1.0),
	
	mat("clothesMammoth", mammothColor, 1.0),
	mat("clothingMammothFur", mammothColor, 1.0),
	mat("clothingMammothFurShort", mammothColor, 1.0),
	mat("clothesMammothNoDecal", mammothColor, 1.0),

	matWithB("chicken", vec3(0.7, 0.7, 0.7), 1.0, vec3(0.0, 0.0, 0.0), 1.0),
	matWithB("chicken_feet", vec3(0.84,0.59,0.1), 0.8, vec3(0.68,0.65,0.33), 0.8),
	matWithB("chicken_comb", vec3(0.84,0.29,0.23), 0.8, vec3(1,0.62,0.48), 0.8),

	mat("redMeat", vec3(0.4, 0.12 * 1.5, 0.1 * 1.5), 0.4),
	mat("redMeatCooked", vec3(0.1, 0.03, 0.01), 0.8),
	
	mat("rottenMeat", vec3(0.1, 0.12, 0.01), 0.8),

	mat("leafy", vec3(0.25,0.33,0.15) * 1.1, 0.5),

	mat("warning", orangeColor, 0.8),
	mat("warning_selected", orangeHighlightColor, 0.8),
	mat("ok", greenColor, 0.8),
	mat("ok_selected", greenHighlightColor, 0.8),
	mat("neutral", blueColor, 0.8),
	mat("neutral_selected", blueHighlightColor, 0.8),

	mat("ui_background_dark", vec3(0.01,0.01,0.01), 0.8),
	mat("ui_background", vec3(0.02,0.02,0.02), uiRoughness),
	mat("ui_background_black", vec3(0.0,0.0,0.0), 1.0),
	mat("ui_background_button", vec3(0.07,0.07,0.07), uiRoughness),
	--mat("ui_background_inset", vec3(0.2,0.2,0.2), uiRoughness),
	mat("ui_background_inset", vec3(0.067,0.067,0.067), uiRoughness),
	mat("ui_background_green", vec3(0.05,0.1,0.05), uiRoughness),
	mat("ui_background_red", vec3(0.1,0.05,0.05), uiRoughness),
	mat("ui_background_blue", blueColor * 0.2, uiRoughness),
	mat("ui_standard", whiteColor, uiRoughness),
	mat("ui_standardDarker", whiteColor * 0.6, uiRoughness),
	mat("ui_disabled", vec3(0.15,0.15,0.15), uiRoughness),
	mat("ui_disabled_green", vec3(0.075,0.15,0.075), uiRoughness),
	mat("ui_disabled_red", vec3(0.15,0.075,0.075), uiRoughness),
	mat("ui_disabled_blue", blueColor * 0.3, uiRoughness),
	mat("ui_disabled_yellow", vec3(0.4,0.4,0.15), uiRoughness),
	mat("ui_destructiveBackground_red", vec3(0.08,0.0,0.0), uiRoughness),
	mat("ui_orderMarkerdestructiveBackground_red", vec3(0.15,0.0,0.0), uiRoughness), --not used?

	mat("ui_background_inset_lighter", vec3(0.085,0.085,0.085) * 0.4, uiRoughness),
	mat("ui_background_inset_lightest", vec3(0.1,0.1,0.1) * 0.4, uiRoughness),
	
	mat("ui_background_warning", vec3(0.8,0.55,0.0) * 0.2 * 0.4, 0.8),
	mat("ui_background_warning_disabled", (vec3(0.8,0.55,0.0) * 0.1 + vec3(0.01,0.01,0.01)) * 0.4, 0.8),
	
	
	mat("ui_selected", blueColor, uiRoughness),
	mat("ui_otherPlayer", otherPlayerPurple, uiRoughness),
	mat("ui_green", greenColor, uiRoughness),
	mat("ui_red", redColor, uiRoughness),
	mat("ui_yellow", yellowColor, uiRoughness),
	
	mat("ui_sun", vec3(0.9,0.8,0.1), uiRoughness),
	mat("ui_sky", vec3(0.3, 0.4, 0.5), uiRoughness),
	mat("ui_moon", vec3(0.3, 0.4, 0.5), uiRoughness),

	
	mat("ui_greenBright", greenColorBright, uiRoughness),
	mat("ui_redBright", redColorBright, uiRoughness),
	mat("ui_yellowBright", yellowColorBright, uiRoughness),

	mat("ui_blueDark", blueColorDark, uiRoughness),
	mat("ui_greenDark", greenColorDark, uiRoughness),
	mat("ui_redDark", redColorDark, uiRoughness),

	mat("ui_thermo_vcold", blueColorDark, uiRoughness),
	mat("ui_thermo_cold", blueColor, uiRoughness),
	mat("ui_thermo_warm", vec3(0.9,0.8,0.1), uiRoughness),
	mat("ui_thermo_hot", vec3(0.9,0.8,0.1), uiRoughness),
	mat("ui_thermo_vhot", redColorBright, uiRoughness),

	mat("star1", blueColor, uiRoughness),
	mat("star2", blueColor, uiRoughness),
	mat("star3", blueColor, uiRoughness),
	mat("star4", blueColor, uiRoughness),
	mat("star5", blueColor, uiRoughness),
	
	mat("digUIMarker", whiteColor, 0.9),

	mat("logoColor", vec3(0.65,0.3,0.05), uiRoughness),
	mat("standardText", whiteColor, uiRoughness),
	mat("disabledText", vec3(0.25,0.25,0.25), uiRoughness),
	mat("selectedText", blueColor, uiRoughness),

	mat("whiteMeat", vec3(0.5, 0.4, 0.4), 0.7),
	mat("bone", vec3(0.65, 0.6, 0.6), 1.0),
	
	mat("whiteMeatCooked", vec3(0.4, 0.24, 0.1), 0.5),
	mat("boneCooked", vec3(0.45, 0.35, 0.3), 0.8),

	
	mat("boneCooked", vec3(0.45, 0.35, 0.3), 0.8),

	mat("charcoal", vec3(0.1, 0.1, 0.1), 0.8),
	mat("ash", vec3(0.3, 0.3, 0.3), 0.9),
	mat("burntHay", vec3(0.1, 0.1, 0.1), 0.8),

	mat("flint", vec3(0.1,0.09,0.08), 0.4),

	
	mat("mood_severeNegative", getMoodColor(moodColors.severeNegative), 0.9),
	mat("mood_moderateNegative", getMoodColor(moodColors.moderateNegative), 0.9),
	mat("mood_mildNegative", getMoodColor(moodColors.mildNegative), 0.9),
	mat("mood_mildPositive", getMoodColor(moodColors.mildPositive), 0.9),
	mat("mood_moderatePositive", getMoodColor(moodColors.moderatePositive), 0.9),
	mat("mood_severePositive", getMoodColor(moodColors.severePositive), 0.9),

	
	mat(string.format("biomeDifficulty_%d", biome.difficulties.veryEasy), 	getMoodColor(biome.difficultyColors[biome.difficulties.veryEasy]), 0.9),
	mat(string.format("biomeDifficulty_%d", biome.difficulties.easy), 		getMoodColor(biome.difficultyColors[biome.difficulties.easy]), 0.9),
	mat(string.format("biomeDifficulty_%d", biome.difficulties.normal), 	getMoodColor(biome.difficultyColors[biome.difficulties.normal]), 0.9),
	mat(string.format("biomeDifficulty_%d", biome.difficulties.hard), 		getMoodColor(biome.difficultyColors[biome.difficulties.hard]), 0.9),
	mat(string.format("biomeDifficulty_%d", biome.difficulties.veryHard), 	getMoodColor(biome.difficultyColors[biome.difficulties.veryHard]), 0.9),

	
	mat("mood_uiBackground_severeNegative", 	getMoodBackgroundColor(moodColors.severeNegative), uiRoughness),
	mat("mood_uiBackground_moderateNegative", 	getMoodBackgroundColor(moodColors.moderateNegative), uiRoughness),
	mat("mood_uiBackground_mildNegative", 		getMoodBackgroundColor(moodColors.mildNegative), uiRoughness),
	mat("mood_uiBackground_mildPositive", 		getMoodBackgroundColor(moodColors.mildPositive), uiRoughness),
	mat("mood_uiBackground_moderatePositive", 	getMoodBackgroundColor(moodColors.moderatePositive), uiRoughness),
	mat("mood_uiBackground_severePositive", 	getMoodBackgroundColor(moodColors.severePositive), uiRoughness),

	--mat("ui_selected", vec3(0.3,0.65,0.75), 0.5,1.0), --nice blue
}



local function cloneMaterial(baseMatType, newName)
	local matCopy = mj:cloneTable(baseMatType)
	matCopy.key = newName
	mj:insertIndexed(material.types, matCopy)
end


local function setMaterialB(baseTypeKey, color, roughness, metalOrNil)
	material.types[baseTypeKey].colorB = color
	material.types[baseTypeKey].roughnessB = roughness
	material.types[baseTypeKey].metalB = metalOrNil or 0.0
end

local function setMaterialBMixed(baseTypeKey, mixTypeKey, mixFraction)
	material.types[baseTypeKey].colorB = mjm.mix(material.types[baseTypeKey].color, material.types[mixTypeKey].color, mixFraction)
	material.types[baseTypeKey].roughnessB = mjm.mix(material.types[baseTypeKey].roughness, material.types[mixTypeKey].roughness, mixFraction)
	material.types[baseTypeKey].metalB = mjm.mix(material.types[baseTypeKey].metal, material.types[mixTypeKey].metal, mixFraction)
end


--setMaterialB("ui_background", material.types.ui_background.color * 1.1, material.types.ui_background.roughness)


setMaterialB("sand", material.types.sand.color * 1.2, material.types.sand.roughness * 0.8)
setMaterialB("terrain_sand", material.types.sand.color * 1.2, material.types.sand.roughness * 0.8)
setMaterialB("riverSand", material.types.riverSand.color * 1.3, 0.6)
setMaterialB("terrain_riverSand", material.types.riverSand.color * 1.3, 0.6)
setMaterialB("desertRedSand", material.types.desertRedSand.color * 1.2, material.types.desertRedSand.roughness * 0.8)
setMaterialB("terrain_desertRedSand", material.types.desertRedSand.color * 1.2, material.types.desertRedSand.roughness * 0.8)
setMaterialB("redSand", material.types.redSand.color * 1.2, material.types.redSand.roughness * 0.8)
setMaterialB("dirt", material.types.dirt.color * 1.4, material.types.dirt.roughness)
setMaterialB("terrain_dirt", material.types.terrain_dirt.color * 1.3, 1.0)
setMaterialB("clay", material.types.clay.color * 1.1, material.types.clay.roughness)
setMaterialB("terrain_clay", material.types.clay.color, material.types.clay.roughness)

setMaterialB("richDirt", material.types.richDirt.color * 1.4, material.types.richDirt.roughness)
setMaterialB("terrain_richDirt", material.types.richDirt.color * 1.1, 1.0)
setMaterialB("poorDirt", material.types.poorDirt.color * 1.4, material.types.poorDirt.roughness)
setMaterialB("terrain_poorDirt", material.types.terrain_poorDirt.color * 1.3, 1.0)
setMaterialB("compost", material.types.compost.color * 1.4, material.types.compost.roughness * 0.6)
setMaterialB("rock", material.types.rock.color * 1.3, material.types.rock.roughness * 0.6)
setMaterialB("terrain_rock", material.types.rock.color * 1.1, material.types.rock.roughness * 0.6)
setMaterialB("redRock", vec3(0.35,0.15,0.15), material.types.redRock.roughness * 0.5)
setMaterialB("terrain_redRock", redRockColor, 0.1)
setMaterialB("greenRock", material.types.greenRock.color * 0.3, material.types.greenRock.roughness * 0.2)
setMaterialB("terrain_greenRock", greenRockColor, 0.1)
setMaterialB("graniteRock", vec3(0.1,0.1,0.1), 0.0)
setMaterialB("terrain_graniteRock", material.types.terrain_graniteRock.color * 0.4, 0.1)
setMaterialB("marbleRock", mix(marbleRockColor, vec3(0.0,0.0,0.2), 0.25), 0.8)
setMaterialB("terrain_marbleRock", marbleRockColor, 0.1)
setMaterialB("lapisRock", vec3(0.02,0.15,0.3), material.types.lapisRock.roughness * 0.5)
setMaterialB("terrain_lapisRock", vec3(0.02,0.15,0.3), 0.2)

setMaterialB("manure", vec3(0.0,0.0,0.0), 0.0)


setMaterialB("copperOre", vec3(0.4,0.2,0.0), 0.2, 1.0)
setMaterialB("terrain_copperOre", vec3(0.4,0.2,0.0), 0.2, 1.0)
setMaterialB("tinOre", vec3(0.2,0.35,0.7), 0.2, 1.0)
setMaterialB("terrain_tinOre", vec3(0.25,0.35,0.48), 0.2, 1.0)
setMaterialB("bronze", vec3(0.4,0.2,0.0) * 2.2, 1.0, 1.0)

setMaterialB("ui_bronze", material.types.ui_bronze.color * 2.2, 0.5, 1.0)
setMaterialB("ui_bronze_lighter", material.types.ui_bronze_lighter.color * 2.2, 0.5, 1.0)
setMaterialB("ui_bronze_roughText", material.types.ui_bronze_roughText.color * 2.2, 0.5, 1.0)
setMaterialB("ui_bronze_lightest", material.types.ui_bronze_lightest.color * 2.2, 0.5, 1.0)


setMaterialB("ui_bronze_severeNegative",	material.types.ui_bronze_severeNegative.color * 	2.2, 0.2, 1.0)
setMaterialB("ui_bronze_moderateNegative",	material.types.ui_bronze_moderateNegative.color * 	2.2, 0.2, 1.0)
setMaterialB("ui_bronze_mildNegative",		material.types.ui_bronze_mildNegative.color * 		2.2, 0.2, 1.0)
setMaterialB("ui_bronze_mildPositive",		material.types.ui_bronze_mildPositive.color * 		2.2, 0.2, 1.0)
setMaterialB("ui_bronze_moderatePositive",	material.types.ui_bronze_moderatePositive.color * 	2.2, 0.2, 1.0)
setMaterialB("ui_bronze_severePositive",	material.types.ui_bronze_severePositive.color * 	2.2, 0.2, 1.0)

setMaterialB("ui_bronze_lightest_severeNegative",	material.types.ui_bronze_lightest_severeNegative.color * 	2.2, 1.0, 1.0)
setMaterialB("ui_bronze_lightest_moderateNegative",	material.types.ui_bronze_lightest_moderateNegative.color * 	2.2, 1.0, 1.0)
setMaterialB("ui_bronze_lightest_mildNegative",		material.types.ui_bronze_lightest_mildNegative.color * 		2.2, 1.0, 1.0)
setMaterialB("ui_bronze_lightest_mildPositive",		material.types.ui_bronze_lightest_mildPositive.color * 		2.2, 1.0, 1.0)
setMaterialB("ui_bronze_lightest_moderatePositive",	material.types.ui_bronze_lightest_moderatePositive.color * 	2.2, 1.0, 1.0)
setMaterialB("ui_bronze_lightest_severePositive",	material.types.ui_bronze_lightest_severePositive.color * 	2.2, 1.0, 1.0)


setMaterialB("ui_iron", material.types.ui_iron.color * 2.2, 0.1, 1.0)
setMaterialB("ui_iron_lighter", material.types.ui_iron_lighter.color * 2.2, 0.1, 1.0)
setMaterialB("ui_iron_roughText", material.types.ui_iron_roughText.color * 2.2, 0.1, 1.0)
setMaterialB("ui_iron_lightest", material.types.ui_iron_lightest.color * 2.2, 0.1, 1.0)


setMaterialB("ui_iron_severeNegative",	material.types.ui_iron_severeNegative.color * 	2.2, 0.2, 1.0)
setMaterialB("ui_iron_moderateNegative",	material.types.ui_iron_moderateNegative.color * 	2.2, 0.2, 1.0)
setMaterialB("ui_iron_mildNegative",		material.types.ui_iron_mildNegative.color * 		2.2, 0.2, 1.0)
setMaterialB("ui_iron_mildPositive",		material.types.ui_iron_mildPositive.color * 		2.2, 0.2, 1.0)
setMaterialB("ui_iron_moderatePositive",	material.types.ui_iron_moderatePositive.color * 	2.2, 0.2, 1.0)
setMaterialB("ui_iron_severePositive",	material.types.ui_iron_severePositive.color * 	2.2, 0.2, 1.0)

setMaterialB("ui_iron_lightest_severeNegative",	material.types.ui_iron_lightest_severeNegative.color * 	2.2, 1.0, 1.0)
setMaterialB("ui_iron_lightest_moderateNegative",	material.types.ui_iron_lightest_moderateNegative.color * 	2.2, 1.0, 1.0)
setMaterialB("ui_iron_lightest_mildNegative",		material.types.ui_iron_lightest_mildNegative.color * 		2.2, 1.0, 1.0)
setMaterialB("ui_iron_lightest_mildPositive",		material.types.ui_iron_lightest_mildPositive.color * 		2.2, 1.0, 1.0)
setMaterialB("ui_iron_lightest_moderatePositive",	material.types.ui_iron_lightest_moderatePositive.color * 	2.2, 1.0, 1.0)
setMaterialB("ui_iron_lightest_severePositive",	material.types.ui_iron_lightest_severePositive.color * 	2.2, 1.0, 1.0)

setMaterialB("whiteTrunk", vec3(0.5,0.5,0.5) * 0.4, material.types.whiteTrunk.roughness)
setMaterialB("lightWood", vec3(0.3,0.25,0.2) * 0.8, material.types.lightWood.roughness)
setMaterialB("elderberryBark", vec3(0.18,0.15,0.22) * 0.4, material.types.elderberryBark.roughness)
setMaterialB("elderberryWood", (vec3(0.18,0.15,0.22) + vec3(0.05,-0.15,0.0)) * 0.2, 0.9)

setMaterialB("peachBark", vec3(0.34,0.2 * 0.5,0.12 * 0.5) * 0.3, 1.0)
setMaterialB("peachWood", vec3(0.34,0.14 * 0.25,0.06 * 0.25) * 1.0, 0.9)

setMaterialB("appleBark", vec3(0.1,0.25,0.0) * 0.2, 1.0)
setMaterialB("appleWood", vec3(0.1,0.25,0.0) * 0.5, 0.9)


setMaterialB("orangeBark", vec3(0.28,0.1,0.06) * 0.2, 1.0)
setMaterialB("orangeWood", vec3(0.32,0.02,0.0) * 0.4, 1.0)

setMaterialB("coconutBark", vec3(0.17, 0.16, 0.17) * 2.0, 1.0)
setMaterialB("coconutWood", vec3(0.28, 0.2, 0.1) * 0.2 + vec3(0.1,0.1,0.1), 1.0)
--mat("coconutBark", vec3(0.17, 0.16, 0.17) * 1.0, 1.0),
--mat("coconutWood", vec3(0.28, 0.2, 0.15) * 1.5, 0.8),

setMaterialB("wood", vec3(0.42,0.32,0.25) * 0.45, material.types.wood.roughness)
--setMaterialB("trunk", vec3(0.19,0.14,0.12) * 0.5 * 0.5, material.types.trunk.roughness)


setMaterialB("raspberry", vec3(0.0,0.0,0.0), material.types.raspberry.roughness)

setMaterialB("limestone", material.types.limestone.color * 0.125, material.types.limestone.roughness * 0.8)
setMaterialB("terrain_limestone", mix(limestoneColor, rockColor, 0.4), material.types.limestone.roughness)

setMaterialB("sandstoneYellowRock", vec3(0.64,0.1,0.0) * 0.2, material.types.sandstoneYellowRock.roughness * 0.5)
setMaterialB("terrain_sandstoneYellowRock", material.types.sandstoneYellowRock.color, material.types.sandstoneYellowRock.roughness)
setMaterialB("sandstoneRedRock", vec3(0.64,0.1,0.0) * 0.2, material.types.sandstoneRedRock.roughness * 0.5)
setMaterialB("terrain_sandstoneRedRock", material.types.sandstoneRedRock.color, material.types.sandstoneRedRock.roughness * 0.5)
setMaterialB("sandstoneOrangeRock", vec3(0.64,0.1,0.0) * 0.2, material.types.sandstoneOrangeRock.roughness * 0.5)
setMaterialB("terrain_sandstoneOrangeRock", material.types.sandstoneOrangeRock.color, material.types.sandstoneOrangeRock.roughness * 0.5)
setMaterialB("sandstoneBlueRock", vec3(0.34,0.38,1.0) * 0.2, material.types.sandstoneBlueRock.roughness * 0.5)
setMaterialB("terrain_sandstoneBlueRock", material.types.sandstoneBlueRock.color, material.types.sandstoneBlueRock.roughness * 0.5)

setMaterialB("gravel", material.types.gravel.color * 1.3, 0.6)
--setMaterialB("redSand", vec3(0.37, 0.36, 0.35) * 0.6, 0.6)
--setMaterialB("temperateGrassRich", material.types.temperateGrassRich.color * 1.4, material.types.temperateGrassRich.roughness)
--setMaterialB("temperateGrassWinter", material.types.temperateGrassWinter.color * 1.4, material.types.temperateGrassWinter.roughness)

local grassMixFraction = 1.0 --was 0.3

setMaterialBMixed("temperateGrass", "temperateGrassTops", grassMixFraction)
setMaterialBMixed("temperateGrassRich", "temperateGrassRichTops", grassMixFraction)
setMaterialBMixed("temperateGrassWinter", "temperateGrassWinterTops", grassMixFraction)

setMaterialBMixed("steppeGrass", "steppeGrassTops", grassMixFraction)

setMaterialBMixed("mediterraneanGrass", "mediterraneanGrassTops", grassMixFraction)
setMaterialBMixed("mediterraneanGrassPlentiful", "mediterraneanGrassTopsPlentiful", grassMixFraction)

setMaterialBMixed("savannaGrass", "savannaGrassTops", grassMixFraction)
setMaterialBMixed("savannaGrassPlentiful", "savannaGrassTopsPlentiful", grassMixFraction)

setMaterialBMixed("tropicalRainforestGrass", "tropicalRainforestGrassTops", grassMixFraction)
setMaterialBMixed("tropicalRainforestGrassRich", "tropicalRainforestGrassRichTops", grassMixFraction)

setMaterialB("grassSnowTerrain", material.types.temperateGrassWinter.color * 0.2 + material.types.snow.color * 0.8, material.types.temperateGrassWinter.roughness * 0.2 + material.types.snow.roughness * 0.8)
--setMaterialB("grassSnowTerrain", material.types.temperateGrassWinter.color, material.types.temperateGrassWinter.roughness)

setMaterialB("haySmaller", material.types.haySmaller.color, material.types.haySmaller.roughness * 0.6)
setMaterialB("hay", material.types.hay.color, material.types.hay.roughness * 0.6)
setMaterialB("thatch", thatchBaseColor * 1.2 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchDecal", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchThinDecal", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchDecalTip", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchDecalShort", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchDecal075", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchDecalLonger", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchDecalLongerLonger", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("thatchEdgeDecal", thatchBaseColor * 1.4 + vec3(0.05,0.05,0.05), material.types.thatch.roughness * 0.95)
setMaterialB("hayNoDecal", material.types.hay.color, material.types.hay.roughness * 0.6)
--material.types.hay.color = material.types.hay.color * 0.8

setMaterialB("wheatGrainRotten", material.types.darkRottenBread.color, 1.0)
setMaterialB("flourRotten", vec3(0.7,0.7,0.7), 1.0)

setMaterialB("mammoth", mammothColor * 1.02, 1.0)
setMaterialB("mammothFur1", mammothColor * 1.5, 1.0)
setMaterialB("clothingFur", vec3(0.1, 0.09, 0.08) * 1.1, 1.0)
setMaterialB("clothingFurShort", vec3(0.1, 0.09, 0.08) * 1.1, 1.0)
setMaterialB("clothingMammothFur", mammothColor * 1.1, 1.0)
setMaterialB("clothingMammothFurShort", mammothColor * 1.1, 1.0)

setMaterialB("bread", material.types.darkBread.color, 1.0)
setMaterialB("rottenBread", material.types.darkRottenBread.color, 1.0)
setMaterialB("breadDoughRotten", material.types.darkRottenBread.color, 1.0)

setMaterialB("terracotta", material.types.terracottaDark.color, 0.2)
setMaterialB("terracottaDarkish", material.types.terracottaDark.color * 0.8, 0.2)
setMaterialB("terracottaDark", material.types.terracottaDark.color * 0.3, 0.2)

setMaterialB("firedBrick_sand", vec3(0.45,0.28,0.22) + vec3(0.02,0.0,0.01), 1.0)
setMaterialB("firedBrick_riverSand", vec3(0.35,0.23,0.24) + vec3(0.0,0.01,0.02), 1.0)
setMaterialB("firedBrick_redSand", redSandColor * 0.8, 1.0)
setMaterialB("firedBrick_hay", vec3(0.47,0.28,0.18) + vec3(0.0,0.01,0.02), 1.0)


	--[[

	mat("firedBrick_sand", vec3(0.45,0.28,0.22), 0.4),
	mat("firedBrick_riverSand", vec3(0.33,0.23,0.24), 0.4),
	mat("firedBrick_redSand", redSandColor, 0.4),
	mat("firedBrick_hay", vec3(0.47,0.30,0.18), 0.4),
	]]

local function setBushMaterialB(baseKey)
	setMaterialB(baseKey, material.types[baseKey].color * 1.05, material.types[baseKey].roughness * 0.95)
end

local function setMaterialBWithMultipliers(baseKey, baseColorMultiplier, baseRoughnessMultiplier)
	setMaterialB(baseKey, material.types[baseKey].color * baseColorMultiplier, material.types[baseKey].roughness * baseRoughnessMultiplier)
end

setBushMaterialB("bushDecal")
setBushMaterialB("darkBushDecal")
setBushMaterialB("leafy")

setMaterialBWithMultipliers("leafyBushA", 2.0, 1.0)
setBushMaterialB("leafyBushASpring")
setBushMaterialB("leafyBushMid")
setBushMaterialB("leafyBushMidSpring")
setBushMaterialB("leafyBushSmall")
setBushMaterialB("leafyBushSmallSpring")
setBushMaterialB("leafyBushB")
setBushMaterialB("leafyBushBSpring")
setBushMaterialB("leafyBushC")
setBushMaterialB("leafyBushCSpring")
setBushMaterialB("leafyBushCSmall")
setBushMaterialB("leafyBushElderberry")
setBushMaterialB("leafyBushElderberrySpring")
setBushMaterialB("bushElderberry")
setBushMaterialB("bushElderberrySpring")
setBushMaterialB("leafyBushSmallElderberry")
setBushMaterialB("leafyBushSmallElderberrySpring")

setMaterialB("leafyPine", pineColor * 3.0, 1.0)
setBushMaterialB("leafyPineSmall")
setBushMaterialB("leafyBushAspen")
setBushMaterialB("leafyBushAspenSpring")
setBushMaterialB("leafyBushAspenSmall")
setBushMaterialB("leafyBushAspenSmallSpring")
setBushMaterialB("raspberryBush")
setBushMaterialB("shrub")
setBushMaterialB("orangeTreeFoliageNoBush")
setBushMaterialB("orangeTreeFoliage")
setBushMaterialB("wheatFlower")
setBushMaterialB("wheatFlowerDecal")
setBushMaterialB("bananaLeafNoBush")
setBushMaterialB("bananaLeaf")
setBushMaterialB("flaxFlower")
setBushMaterialB("bambooLeafNoBush")
setBushMaterialB("bambooLeaf")
setBushMaterialB("bambooLeafSmall")
setBushMaterialB("marigoldLeaf")
setBushMaterialB("marigoldLeafSapling")

setMaterialBWithMultipliers("poppyLeaf", 1.0, 0.9)
setMaterialBWithMultipliers("poppyLeafSapling", 1.0, 0.9)
setMaterialBWithMultipliers("echinaceaLeaf", 1.0, 0.9)
setMaterialBWithMultipliers("echinaceaLeafSapling", 1.0, 0.9)
setMaterialB("echinaceaPetals", vec3(0.45,0.1 + 0.2,0.4), 0.3)
setMaterialB("sunflowerPetals", vec3(0.8,0.4,0.0), 0.5)
setMaterialB("marigoldPetals", vec3(0.7,0.3,0.0), 0.3)
setMaterialB("poppyPetals", vec3(0.6,0.05,0.05), 0.3)





setMaterialBWithMultipliers("gingerFlower", 1.5, 0.9)
setMaterialBWithMultipliers("turmericFlower", 1.5, 0.9)

setMaterialBWithMultipliers("garlicFlower", 1.5, 0.9)

setMaterialB("flaxFlower", vec3(0.1,0.05,0.5), 1.0)

setMaterialB("aloeLeaf", vec3(0.8,1.0,0.8), 0.6)
setMaterialB("aloeLeafRotten", vec3(0.8,1.0,0.8) * 0.3, 0.6)

setMaterialB("injuryMedicine", vec3(0.3,0.2,0.1), 0.5)
setMaterialB("burnMedicine", vec3(0.4,0.4,0.2), 0.5)
setMaterialB("foodPoisoningMedicine", vec3(0.35,0.35,0.1), 0.5)
setMaterialB("virusMedicine", vec3(0.2,0.0,0.0), 0.5)
setMaterialB("medicineRotten", vec3(0.1,0.2,0.1), 1.0)
setMaterialB("rottenGoo", vec3(0.15,0.2,0.1), 0.1)



setMaterialBWithMultipliers("alpaca", 2.0, 0.5)

local function addClothesVariant(key, colorA, roughnessA, colorB, roughnessB)

	local furColorB = mjm.mix(colorA, colorB, 0.2)

	local clothesMat = matWithB("clothes" .. "_" .. key, colorA, roughnessA, furColorB, roughnessB)
	clothesMat.edgeDecal = edgeDecal.groupTypes.clothes
	mj:insertIndexed(material.types, clothesMat)


	local clothingFurMat = matWithB("clothingFur" .. "_" .. key, colorA, roughnessA, furColorB, roughnessA)
	clothingFurMat.edgeDecal = edgeDecal.groupTypes.clothingFur
	mj:insertIndexed(material.types, clothingFurMat)

	local clothingFurShortMat = matWithB("clothingFurShort" .. "_" .. key, colorA, roughnessA, furColorB, roughnessA)
	clothingFurShortMat.edgeDecal = edgeDecal.groupTypes.clothingFurShort
	mj:insertIndexed(material.types, clothingFurShortMat)

	mj:insertIndexed(material.types, matWithB("clothesNoDecal" .. "_" .. key, colorA, roughnessA, colorB, roughnessB))
end


addClothesVariant("white", alpaca_white_colorA, 1.0, alpaca_white_colorB, 1.0)
addClothesVariant("black", alpaca_black_colorA, 1.0, alpaca_black_colorB, 1.0)
addClothesVariant("red", alpaca_red_colorA, 1.0, alpaca_red_colorB, 1.0)
addClothesVariant("yellow", alpaca_yellow_colorA, 1.0, alpaca_yellow_colorB, 1.0)
addClothesVariant("cream", alpaca_cream_colorA, 1.0, alpaca_cream_colorB, 1.0)


local leavesADecal = edgeDecal.groupTypes.leavesA
local leavesSmallerDecal = edgeDecal.groupTypes.leavesSmaller
local leavesMarigoldDecal = edgeDecal.groupTypes.leavesMarigold
local leavesEchinaceaDecal = edgeDecal.groupTypes.leavesEchinacea
local leavesBiggerDecal = edgeDecal.groupTypes.leavesBigger
local willowLeafDecal = edgeDecal.groupTypes.willowLeaf
local willowLeafSmallDecal = edgeDecal.groupTypes.willowLeafSmall
local leavesAloeDecal = edgeDecal.groupTypes.leavesAloe
local echinaceaPetalsDecal = edgeDecal.groupTypes.echinaceaPetals
local sunflowerPetalsDecal = edgeDecal.groupTypes.sunflowerPetals
local marigoldPetalsDecal = edgeDecal.groupTypes.marigoldPetals
local poppyPetalsDecal = edgeDecal.groupTypes.poppyPetals


for i=1,16 do
	local name = "autumn" .. i
	local baseMat = material.types[name]
	setMaterialB(baseMat.key, vec3(baseMat.color.x + 0.05, baseMat.color.y + 0.1, baseMat.color.z) * 1.1, 0.6)
end

for i=1,16 do
	local name = "autumn" .. i
	local copyName = name .. "Willow"
	local matCopy = mj:cloneTable(material.types[name])
	matCopy.key = copyName
	mj:insertIndexed(material.types, matCopy)
end

for i=1,16 do
	local name = "autumn" .. i
	local copyName = name .. "LeafWillow"
	local matCopy = mj:cloneTable(material.types[name])
	matCopy.key = copyName
	matCopy.edgeDecal = willowLeafDecal
	mj:insertIndexed(material.types, matCopy)
end

for i=1,16 do
	local name = "autumn" .. i
	local leafyName = name .. "Leaf"
	local matCopy = mj:cloneTable(material.types[name])
	matCopy.key = leafyName
	matCopy.edgeDecal = leavesADecal
	mj:insertIndexed(material.types, matCopy)
end

for i=1,16 do
	local name = "autumn" .. i
	local leafyName = name .. "Small"
	local matCopy = mj:cloneTable(material.types[name])
	matCopy.key = leafyName
	matCopy.edgeDecal = leavesSmallerDecal
	mj:insertIndexed(material.types, matCopy)
end

for i=1,2 do
	local name = "winter" .. i
	local leafyName = name .. "Leaf"
	local matCopy = mj:cloneTable(material.types[name])
	matCopy.key = leafyName
	matCopy.edgeDecal = leavesADecal
	mj:insertIndexed(material.types, matCopy)
end

for i=1,2 do
	local name = "winter" .. i
	local leafyName = name .. "Small"
	local matCopy = mj:cloneTable(material.types[name])
	matCopy.key = leafyName
	matCopy.edgeDecal = leavesSmallerDecal
	mj:insertIndexed(material.types, matCopy)
end

--[[
material.types.bushDecal.decal = {
	--matB = material.types.bushShiny.index
	true
}
material.types.darkBushDecal.decal = {
	true
	--matB = material.types.darkBushShiny.index
}
material.types.leafy.decal = {
	true
	--matB = material.types.darkBushShiny.index
}
material.types.wheatFlowerDecal.decal = {
	true
	--matB = material.types.darkBushShiny.index
}]]

material.types.leafyBushA.edgeDecal = leavesADecal
material.types.leafyBushASpring.edgeDecal = leavesADecal

material.types.leafyBushElderberry.edgeDecal = leavesADecal
material.types.leafyBushElderberrySpring.edgeDecal = leavesADecal
material.types.leafyBushSmallElderberry.edgeDecal = leavesSmallerDecal
material.types.leafyBushSmallElderberrySpring.edgeDecal = leavesSmallerDecal

material.types.bananaLeaf.edgeDecal = edgeDecal.groupTypes.bananaLeaf
material.types.coconutLeaf.edgeDecal = edgeDecal.groupTypes.bananaLeaf
material.types.coconutLeafSmall.edgeDecal = edgeDecal.groupTypes.bananaLeafSmall

material.types.bananaBark.edgeDecal = edgeDecal.groupTypes.bananaBark

material.types.leafyBushMid.edgeDecal = leavesADecal
material.types.leafyBushMidSpring.edgeDecal = leavesADecal

material.types.leafyBushMidSmall.edgeDecal = leavesSmallerDecal
material.types.leafyBushMidSmallSpring.edgeDecal = leavesSmallerDecal

material.types.leafyBushSmall.edgeDecal = leavesSmallerDecal
material.types.leafyBushSmallSpring.edgeDecal = leavesSmallerDecal

material.types.leafyBushB.edgeDecal = leavesBiggerDecal
material.types.leafyBushBSpring.edgeDecal = leavesBiggerDecal
material.types.leafyBushC.edgeDecal = willowLeafDecal
material.types.leafyBushCSpring.edgeDecal = willowLeafDecal
material.types.leafyBushCSmall.edgeDecal = willowLeafSmallDecal

material.types.leafyPine.edgeDecal = edgeDecal.groupTypes.pine
material.types.leafyPineSmall.edgeDecal = edgeDecal.groupTypes.pineSmall
material.types.snowPine.edgeDecal = edgeDecal.groupTypes.pine

material.types.thatchDecal.edgeDecal = edgeDecal.groupTypes.thatch
material.types.thatchThinDecal.edgeDecal = edgeDecal.groupTypes.thatchThin
material.types.thatchDecalTip.edgeDecal = edgeDecal.groupTypes.thatchThin
material.types.thatchDecalShort.edgeDecal = edgeDecal.groupTypes.thatchShort
material.types.thatchDecal075.edgeDecal = edgeDecal.groupTypes.thatch075
material.types.thatchDecalLonger.edgeDecal = edgeDecal.groupTypes.thatchLonger
material.types.thatchDecalLongerLonger.edgeDecal = edgeDecal.groupTypes.thatchLongerLonger
material.types.thatchEdgeDecal.edgeDecal = edgeDecal.groupTypes.thatchEdge

material.types.leafyBushAspen.edgeDecal = leavesBiggerDecal
material.types.leafyBushAspenSpring.edgeDecal = leavesBiggerDecal
material.types.leafyBushAspenSmall.edgeDecal = leavesSmallerDecal
material.types.leafyBushAspenSmallSpring.edgeDecal = leavesSmallerDecal


material.types.bambooLeaf.edgeDecal = edgeDecal.groupTypes.bambooLeaf
material.types.bambooLeafSmall.edgeDecal = edgeDecal.groupTypes.bambooLeafSmall

material.types.raspberryBush.edgeDecal = leavesSmallerDecal

material.types.shrub.edgeDecal = leavesSmallerDecal
material.types.orangeTreeFoliage.edgeDecal = leavesBiggerDecal

material.types.poppyLeaf.edgeDecal = leavesSmallerDecal
material.types.poppyLeafSapling.edgeDecal = leavesSmallerDecal

material.types.marigoldLeaf.edgeDecal = leavesMarigoldDecal
material.types.marigoldLeafSapling.edgeDecal = leavesMarigoldDecal

material.types.echinaceaLeaf.edgeDecal = leavesEchinaceaDecal
material.types.echinaceaLeafSapling.edgeDecal = leavesEchinaceaDecal

material.types.echinaceaPetals.edgeDecal = echinaceaPetalsDecal
material.types.sunflowerPetals.edgeDecal = sunflowerPetalsDecal
material.types.marigoldPetals.edgeDecal = marigoldPetalsDecal
material.types.poppyPetals.edgeDecal = poppyPetalsDecal

material.types.aloeLeaf.edgeDecal = leavesAloeDecal
material.types.aloeLeafRotten.edgeDecal = leavesAloeDecal


material.types.wheatFlower.edgeDecal = edgeDecal.groupTypes.wheatFlower
material.types.flaxFlower.edgeDecal = edgeDecal.groupTypes.flaxFlower
material.types.gingerFlower.edgeDecal = edgeDecal.groupTypes.gingerFlower
material.types.turmericFlower.edgeDecal = edgeDecal.groupTypes.gingerFlower
material.types.garlicFlower.edgeDecal = edgeDecal.groupTypes.garlicFlower


cloneMaterial(material.types.flaxFlower, "flaxFlowerPicked")
cloneMaterial(material.types.flaxFlower, "flaxFlowerDry")
cloneMaterial(material.types.flaxLeaf, "flaxLeafDry")

--aterial.types.flaxFlowerPicked.color = material.types.flaxFlowerPicked.color * 0.5 + vec3(0.05,0.05,0.0)
material.types.flaxFlowerPicked.edgeDecal = edgeDecal.groupTypes.flaxFlowerPicked
--material.types.flaxFlowerPicked.colorB = material.types.flaxFlowerPicked.colorB * 0.7 + vec3(0.05,0.05,0.0)

material.types.flaxFlowerDry.color = mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1)
material.types.flaxFlowerDry.edgeDecal = edgeDecal.groupTypes.flaxFlowerPicked
material.types.flaxFlowerDry.colorB = mediterrainianGrassBaseColor + vec3(0.16, 0.12, 0.1)

material.types.flaxLeafDry.color = material.types.flaxLeafDry.color * 0.5 + vec3(0.15,0.12,0.1)
--material.types.flaxFlowerDry.color = material.types.flaxFlowerDry.color * 0.5 + vec3(0.15,0.12,0.1)
--material.types.flaxFlowerDry.colorB = material.types.flaxFlowerDry.color
--material.types.flaxFlowerDry.edgeDecal = edgeDecal.groupTypes.flaxFlowerPicked

cloneMaterial(material.types.flaxLeaf, "flaxTwine")
material.types.flaxTwine.color = material.types.flaxLeafDry.color * 2.0
material.types.flaxTwine.roughness = 1.0
cloneMaterial(material.types.flaxTwine, "flaxTwineDecal")
material.types.flaxTwineDecal.edgeDecal = edgeDecal.groupTypes.flaxTwine


cloneMaterial(material.types.dirt, "dirtPath")
cloneMaterial(material.types.richDirt, "richDirtPath")
cloneMaterial(material.types.poorDirt, "poorDirtPath")

material.types.dirtPath.color = material.types.dirtPath.color * 0.9
material.types.dirtPath.colorB = material.types.dirtPath.colorB * 1.5
material.types.dirtPath.roughness = material.types.dirtPath.roughness * 0.9

material.types.richDirtPath.color = material.types.richDirtPath.color * 0.9
material.types.richDirtPath.colorB = material.types.richDirtPath.colorB * 1.5
material.types.richDirtPath.roughness = material.types.richDirtPath.roughness * 0.9

material.types.poorDirtPath.color = material.types.poorDirtPath.color * 0.9
material.types.poorDirtPath.colorB = material.types.poorDirtPath.colorB * 1.5
material.types.poorDirtPath.roughness = material.types.poorDirtPath.roughness * 0.9

material.types.mammothFur1.edgeDecal = edgeDecal.groupTypes.mammothEdgeOnly
material.types.mammoth.edgeDecal = edgeDecal.groupTypes.mammoth
material.types.clothingFur.edgeDecal = edgeDecal.groupTypes.clothingFur
material.types.clothingFurShort.edgeDecal = edgeDecal.groupTypes.clothingFurShort
material.types.clothingMammothFur.edgeDecal = edgeDecal.groupTypes.clothingFur
material.types.clothingMammothFurShort.edgeDecal = edgeDecal.groupTypes.clothingFurShort
material.types.clothes.edgeDecal = edgeDecal.groupTypes.clothes
material.types.clothesMammoth.edgeDecal = edgeDecal.groupTypes.clothes

cloneMaterial(material.types.hair, "hairNoDecal")
cloneMaterial(material.types.hairBlond, "hairBlondNoDecal")
cloneMaterial(material.types.hairDarker, "hairDarkerNoDecal")
cloneMaterial(material.types.hairDarkest, "hairDarkestNoDecal")
cloneMaterial(material.types.hairRed, "hairRedNoDecal")
cloneMaterial(material.types.greyHair, "greyHairNoDecal")

material.types.hair.edgeDecal = edgeDecal.groupTypes.hair
material.types.hairBlond.edgeDecal = edgeDecal.groupTypes.hair
material.types.hairDarker.edgeDecal = edgeDecal.groupTypes.hair
material.types.hairDarkest.edgeDecal = edgeDecal.groupTypes.hair
material.types.hairRed.edgeDecal = edgeDecal.groupTypes.hair
material.types.greyHair.edgeDecal = edgeDecal.groupTypes.hair

cloneMaterial(material.types.hair, "eyebrows")
cloneMaterial(material.types.hairBlond, "eyebrowsBlond")
cloneMaterial(material.types.hairDarker, "eyebrowsDarker")
cloneMaterial(material.types.hairDarkest, "eyebrowsDarkest")
cloneMaterial(material.types.hairRed, "eyebrowsRed")
cloneMaterial(material.types.greyHair, "eyebrowsGrey")


material.types.eyebrows.edgeDecal = edgeDecal.groupTypes.eyebrows
material.types.eyebrowsBlond.edgeDecal = edgeDecal.groupTypes.eyebrows
material.types.eyebrowsDarker.edgeDecal = edgeDecal.groupTypes.eyebrows
material.types.eyebrowsDarkest.edgeDecal = edgeDecal.groupTypes.eyebrows
material.types.eyebrowsRed.edgeDecal = edgeDecal.groupTypes.eyebrows
material.types.eyebrowsGrey.edgeDecal = edgeDecal.groupTypes.eyebrows


cloneMaterial(material.types.hair, "eyelashes")
cloneMaterial(material.types.hairBlond, "eyelashesBlond")
cloneMaterial(material.types.hairDarker, "eyelashesDarker")
cloneMaterial(material.types.hairDarkest, "eyelashesDarkest")
cloneMaterial(material.types.hairRed, "eyelashesRed")
cloneMaterial(material.types.greyHair, "eyelashesGrey")

material.types.eyelashes.color = material.types.eyelashes.color * 0.6
material.types.eyelashesBlond.color = material.types.eyelashesBlond.color * 0.6
material.types.eyelashesDarker.color = material.types.eyelashesDarker.color * 0.6
material.types.eyelashesDarkest.color = material.types.eyelashesDarkest.color * 0.6
material.types.eyelashesRed.color = material.types.eyelashesRed.color * 0.6
material.types.eyelashesGrey.color = material.types.eyelashesGrey.color * 0.6

cloneMaterial(material.types.eyelashes, "eyelashesLong")
cloneMaterial(material.types.eyelashesBlond, "eyelashesBlondLong")
cloneMaterial(material.types.eyelashesDarker, "eyelashesDarkerLong")
cloneMaterial(material.types.eyelashesDarkest, "eyelashesDarkestLong")
cloneMaterial(material.types.eyelashesRed, "eyelashesRedLong")
cloneMaterial(material.types.eyelashesGrey, "eyelashesGreyLong")


material.types.eyelashes.edgeDecal = edgeDecal.groupTypes.eyelashes
material.types.eyelashesBlond.edgeDecal = edgeDecal.groupTypes.eyelashes
material.types.eyelashesDarker.edgeDecal = edgeDecal.groupTypes.eyelashes
material.types.eyelashesDarkest.edgeDecal = edgeDecal.groupTypes.eyelashes
material.types.eyelashesRed.edgeDecal = edgeDecal.groupTypes.eyelashes
material.types.eyelashesGrey.edgeDecal = edgeDecal.groupTypes.eyelashes

material.types.eyelashesLong.edgeDecal = edgeDecal.groupTypes.eyelashesLong
material.types.eyelashesBlondLong.edgeDecal = edgeDecal.groupTypes.eyelashesLong
material.types.eyelashesDarkerLong.edgeDecal = edgeDecal.groupTypes.eyelashesLong
material.types.eyelashesDarkestLong.edgeDecal = edgeDecal.groupTypes.eyelashesLong
material.types.eyelashesRedLong.edgeDecal = edgeDecal.groupTypes.eyelashesLong
material.types.eyelashesGreyLong.edgeDecal = edgeDecal.groupTypes.eyelashesLong

material.types.hay.edgeDecal = edgeDecal.groupTypes.hay
material.types.haySmaller.edgeDecal = edgeDecal.groupTypes.haySmaller
material.types.greenHay.edgeDecal = edgeDecal.groupTypes.haySmaller
material.types.hayRotten.edgeDecal = edgeDecal.groupTypes.haySmaller

-- supress warnings, temporary future materials
cloneMaterial(material.types.alpaca_head, "alpaca_shaved")
cloneMaterial(material.types.wheatGrain, "grain")
cloneMaterial(material.types.bronze, "metal")
cloneMaterial(material.types.copperOre, "ore")


cloneMaterial(material.types.rock, "rockBlock")
material.types.rockBlock.color = material.types.rock.color * 0.8
material.types.rockBlock.colorB = material.types.rock.color
material.types.rockBlock.textureIndex = 1

cloneMaterial(material.types.limestone, "limestoneBlock")
material.types.limestoneBlock.color = mix(material.types.limestone.color, material.types.limestone.colorB, 0.2)
material.types.limestoneBlock.colorB = mix(material.types.limestone.color, material.types.limestone.colorB, 0.4)
material.types.limestoneBlock.textureIndex = 1

cloneMaterial(material.types.redRock, "redRockBlock")
material.types.redRockBlock.roughness = 0.4
material.types.redRockBlock.roughnessB = 0.2
material.types.redRockBlock.colorB = mix(material.types.redRock.color, material.types.redRock.colorB, 0.2)
material.types.redRockBlock.textureIndex = 1

cloneMaterial(material.types.greenRock, "greenRockBlock")
material.types.greenRockBlock.color = mix(material.types.greenRock.color, material.types.greenRock.colorB, 0.5)
material.types.greenRockBlock.colorB = material.types.greenRock.color
material.types.greenRockBlock.roughness = 0.3
material.types.greenRockBlock.roughnessB = 0.2
material.types.greenRockBlock.textureIndex = 1

cloneMaterial(material.types.graniteRock, "graniteRockBlock")
material.types.graniteRockBlock.roughness = 0.4
material.types.graniteRockBlock.roughnessB = 0.2
material.types.graniteRockBlock.colorB = mix(material.types.graniteRock.color, material.types.graniteRock.colorB, 0.3)
material.types.graniteRockBlock.textureIndex = 1

cloneMaterial(material.types.marbleRock, "marbleRockBlock")
material.types.marbleRockBlock.color = material.types.marbleRock.colorB
material.types.marbleRockBlock.colorB = material.types.marbleRock.color
material.types.marbleRockBlock.roughness = 0.4
material.types.marbleRockBlock.roughnessB = 0.2
material.types.marbleRockBlock.colorB = mix(material.types.marbleRock.color, material.types.marbleRock.colorB, 0.5)
material.types.marbleRockBlock.textureIndex = 1

cloneMaterial(material.types.lapisRock, "lapisRockBlock")
material.types.lapisRockBlock.roughness = 0.4
material.types.lapisRockBlock.roughnessB = 0.2
material.types.lapisRockBlock.colorB = mix(material.types.lapisRock.color, material.types.lapisRock.colorB, 0.3)
material.types.lapisRockBlock.textureIndex = 1

cloneMaterial(material.types.sandstoneYellowRock, "sandstoneYellowRockBlock")
material.types.sandstoneYellowRockBlock.colorB = material.types.sandstoneYellowRock.color
material.types.sandstoneYellowRockBlock.colorA = mix(material.types.sandstoneYellowRock.color, material.types.sandstoneYellowRock.colorB, 0.5)
material.types.sandstoneYellowRockBlock.textureIndex = 1
cloneMaterial(material.types.sandstoneRedRock, "sandstoneRedRockBlock")
material.types.sandstoneRedRockBlock.colorB = material.types.sandstoneRedRock.color
material.types.sandstoneRedRockBlock.colorA = mix(material.types.sandstoneRedRock.color, material.types.sandstoneRedRock.colorB, 0.5)
material.types.sandstoneRedRockBlock.textureIndex = 1
cloneMaterial(material.types.sandstoneOrangeRock, "sandstoneOrangeRockBlock")
material.types.sandstoneOrangeRockBlock.colorB = material.types.sandstoneOrangeRock.color
material.types.sandstoneOrangeRockBlock.colorA = mix(material.types.sandstoneOrangeRock.color, material.types.sandstoneOrangeRock.colorB, 0.5)
material.types.sandstoneOrangeRockBlock.textureIndex = 1
cloneMaterial(material.types.sandstoneBlueRock, "sandstoneBlueRockBlock")
material.types.sandstoneBlueRockBlock.colorB = material.types.sandstoneBlueRock.color
material.types.sandstoneBlueRockBlock.colorA = mix(material.types.sandstoneBlueRock.color, material.types.sandstoneBlueRock.colorB, 0.5)
material.types.sandstoneBlueRockBlock.textureIndex = 1

--[[

	mat("sandstoneYellowRock", getSandstoneColor(vec3(0.44,0.35,0.2)), 1.0),
	mat("terrain_sandstoneYellowRock", mix(getSandstoneColor(vec3(0.44,0.35,0.2)), rockColor, 0.7), 1.0),
	mat("sandstoneRedRock", getSandstoneColor(vec3(0.38,0.2,0.2)), 1.0),
	mat("terrain_sandstoneRedRock", mix(getSandstoneColor(vec3(0.38,0.2,0.2)), rockColor, 0.7), 1.0),
	mat("sandstoneOrangeRock", getSandstoneColor(vec3(0.44,0.3,0.2) * 0.8), 1.0),
	mat("terrain_sandstoneOrangeRock", mix(getSandstoneColor(vec3(0.44,0.3,0.2) * 0.8), rockColor, 0.7), 1.0),
	mat("sandstoneBlueRock", getSandstoneColor(vec3(0.34,0.38,0.44)), 1.0),
	mat("terrain_sandstoneBlueRock", mix(getSandstoneColor(vec3(0.34,0.38,0.44)), rockColor, 0.7), 1.0),
]]

material.types.mudBrickWet_sand.textureIndex = 1
material.types.mudBrickWet_riverSand.textureIndex = 1
material.types.mudBrickWet_redSand.textureIndex = 1
material.types.mudBrickWet_hay.textureIndex = 1

material.types.mudBrickDry_sand.textureIndex = 1
material.types.mudBrickDry_riverSand.textureIndex = 1
material.types.mudBrickDry_redSand.textureIndex = 1
material.types.mudBrickDry_hay.textureIndex = 1


material.types.firedBrick_hay.textureIndex = 1
material.types.firedBrick_redSand.textureIndex = 1
material.types.firedBrick_riverSand.textureIndex = 1
material.types.firedBrick_sand.textureIndex = 1

cloneMaterial(material.types.terracotta, "terracottaTile")
material.types.terracottaTile.color = mix(material.types.terracotta.color, material.types.terracotta.colorB, 0.5)
material.types.terracottaTile.colorB = mix(material.types.terracotta.color, material.types.terracotta.colorB, 0.2)
material.types.terracottaTile.roughnessB = 0.5
material.types.terracottaTile.textureIndex = 1

-- called by engine

function material:materialTypeForName(name)
	return material.types[name].index
end

function material:materials()
    return material.types
end


return material