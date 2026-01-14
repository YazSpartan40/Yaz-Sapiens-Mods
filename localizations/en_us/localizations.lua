local localizations = {}

local researchName = "Investigate"
local researchingName = "Investigating"

local vowelsSet = {
    a = true,
    e = true,
    i = true,
    o = true,
    u = true,
}

local function getAorAn(noun) --crude, may need exceptions for 'hour' 'use' etc
    if noun and vowelsSet[string.sub(string.lower(noun), 1, 1)] then
        return "an"
    end
    return "a"
end

localizations.values = {
    gameName = "Sapiens",
    sapiens = "Sapiens",

    -- mobs
    mob_alpaca = "Alpaca",
    mob_alpaca_plural = "Alpacas",
    mob_chicken = "Chicken",
    mob_chicken_plural = "Chickens",
    mob_mammoth = "Mammoth",
    mob_mammoth_plural = "Mammoths",
    mob_catfish = "Catfish", --0.6
    mob_catfish_plural = "Catfish", --0.6
    mob_coelacanth = "Coelacanth", --0.6
    mob_coelacanth_plural = "Coelacanth", --0.6
    mob_flagellipinna = "Flagellipinna", --0.6
    mob_flagellipinna_plural = "Flagellipinna", --0.6
    mob_polypterus = "Polypterus", --0.6
    mob_polypterus_plural = "Polypterus", --0.6
    mob_redfish = "Redfish", --0.6
    mob_redfish_plural = "Redfish", --0.6
    mob_tropicalfish = "Jackfish", --0.6
    mob_tropicalfish_plural = "Jackfish", --0.6
    mob_swordfish = "Swordfish", --0.6
    mob_swordfish_plural = "Swordfish", --0.6

    -- buildables
    buildable_craftArea = "Crafting Area",
    buildable_craftArea_plural = "Crafting Areas",
    buildable_craftArea_summary = "Craft basic items, simple tools.",
    buildable_storageArea = "Storage Area 2x2", --0.5
    buildable_storageArea_plural = "Storage Area 2x2s", --0.5
    buildable_storageArea_summary = "Collect everything you have lying around and store them in a tidy pile.",
    buildable_storageArea1x1 = "Small Storage Area 1x1", --0.5
    buildable_storageArea1x1_plural = "Small Storage Area 1x1s", --0.5
    buildable_storageArea1x1_summary = "Takes up less space for smaller quantities. Can't store large items.", --0.5
    buildable_storageArea4x4 = "Large Storage Area 4x4", --0.5
    buildable_storageArea4x4_plural = "Large Storage Area 4x4s", --0.5
    buildable_storageArea4x4_summary = "Stores a large quantity of resources.", --0.5
    buildable_compostBin = "Compost Bin", --0.4
    buildable_compostBin_plural = "Compost Bins", --0.4
    buildable_compostBin_summary = "Compost bins turn rotting organic matter into compost, which can then be used to enrich the soil.", --0.4
    buildable_campfire = "Campfire",
    buildable_campfire_plural = "Campfires",
    buildable_campfire_summary = "The campfire provides warmth and light, and allows cooking of food to increase its nutritional value. Campfires also keep animals away.", --0.5 added "Campfires also keep animals away"
    buildable_brickKiln = "Kiln",
    buildable_brickKiln_plural = "Kilns",
    buildable_brickKiln_summary = "Kilns can be used to fire pottery. Fired pottery is more water resistant and will last longer than unfired pottery.",
    buildable_torch = "Torch",
    buildable_torch_plural = "Torches",
    buildable_torch_summary = "Provides light. The hay needs to be replaced frequently.",
    buildable_hayBed = "Hay Bed",
    buildable_hayBed_plural = "Hay Beds",
    buildable_hayBed_summary = "Better than sleeping on the hard ground.",
    buildable_woolskinBed = "Woolskin Bed",
    buildable_woolskinBed_plural = "Woolskin Beds",
    buildable_woolskinBed_summary = "A warm place to sleep.",
    buildable_dirtFoundation1x1 = "Dirt Foundation 1x1", -- 0.6.1
    buildable_dirtFoundation1x1_plural = "Dirt Foundation 1x1s", -- 0.6.1
    buildable_dirtFoundation1x1_summary = "A basic cube of dirt. Can be used as a floor, raised above ground level, or used to build thick walls and structures.", -- 0.6.1
    buildable_dirtFoundation2x2 = "Dirt Foundation 2x2", -- 0.6.1
    buildable_dirtFoundation2x2_plural = "Dirt Foundation 2x2s", -- 0.6.1
    buildable_dirtFoundation2x2_summary = "A basic cube of dirt. Can be used as a floor, raised above ground level, or used to build thick walls and structures.", -- 0.6.1
    buildable_thatchRoof = "Thatch Hut/Roof",
    buildable_thatchRoof_plural = "Thatch Huts/Roofs",
    buildable_thatchRoof_summary = "A basic shelter, which can also be used as a roof.",
    buildable_thatchRoofSlope = "Thatch Roof Sloping Section", --0.4
    buildable_thatchRoofSlope_plural = "Thatch Roof Sloping Sections", --0.4
    buildable_thatchRoofSlope_summary = "Useful near corners, or to fill a small gap.", --0.4
    buildable_thatchRoofSmallCorner = "Thatch Roof Corner", --0.4
    buildable_thatchRoofSmallCorner_plural = "Thatch Roof Corners", --0.4
    buildable_thatchRoofSmallCorner_summary = "A small roof corner.", --0.4
    buildable_thatchRoofSmallCornerInside = "Thatch Roof Inner Corner", --0.4
    buildable_thatchRoofSmallCornerInside_plural = "Thatch Roof Inner Corners", --0.4
    buildable_thatchRoofSmallCornerInside_summary = "To fill that pesky gap.", --0.4
    buildable_thatchRoofTriangle = "Thatch Roof Triangle", --0.4
    buildable_thatchRoofTriangle_plural = "Thatch Roof Triangles", --0.4
    buildable_thatchRoofTriangle_summary = "Useful above triangluar floors.", --0.4
    buildable_thatchRoofInvertedTriangle = "Thatch Roof Inverted Triangle", --0.4
    buildable_thatchRoofInvertedTriangle_plural = "Thatch Roof Inverted Triangles", --0.4
    buildable_thatchRoofInvertedTriangle_summary = "Useful above triangluar floors.", --0.4
    buildable_thatchRoofLarge = "Large Thatch Roof",
    buildable_thatchRoofLarge_plural = "Large Thatch Roofs",
    buildable_thatchRoofLarge_summary = "A large roof section.",
    buildable_thatchRoofLargeCorner = "Large Thatch Roof Corner",
    buildable_thatchRoofLargeCorner_plural = "Large Thatch Roof Corners",
    buildable_thatchRoofLargeCorner_summary = "A large roof corner.",
    buildable_thatchRoofLargeCornerInside = "Large Thatch Roof Inner Corner", --0.4
    buildable_thatchRoofLargeCornerInside_plural = "Large Thatch Roof Inner Corners", --0.4
    buildable_thatchRoofLargeCornerInside_summary = "A large roof inner corner.", --0.4
    buildable_thatchWall = "Thatch Wall",
    buildable_thatchWall_plural = "Thatch Walls",
    buildable_thatchWall_summary = "The simplest and quickest wall to build. Dimensions: 4x2",
    buildable_thatchWallDoor = "Thatch Wall With Door",
    buildable_thatchWallDoor_plural = "Thatch Walls With Doors",
    buildable_thatchWallDoor_summary = "The simplest and quickest wall to build. Dimensions: 4x2",
    buildable_thatchWallLargeWindow = "Thatch Wall Large Window",
    buildable_thatchWallLargeWindow_plural = "Thatch Walls Large Windows",
    buildable_thatchWallLargeWindow_summary = "The simplest and quickest wall to build. Dimensions: 4x2",
    buildable_thatchWall4x1 = "Thatch Short Wall",
    buildable_thatchWall4x1_plural = "Thatch Short Walls",
    buildable_thatchWall4x1_summary = "The simplest and quickest wall to build. Dimensions: 4x1",
    buildable_thatchWall2x2 = "Thatch Square Wall",
    buildable_thatchWall2x2_plural = "Thatch Square Walls",
    buildable_thatchWall2x2_summary = "The simplest and quickest wall to build. Dimensions: 2x2",
    buildable_thatchWall2x1 = "Thatch Short Wall 2x1", --0.5
    buildable_thatchWall2x1_plural = "Thatch Short Walls 2x1", --0.5
    buildable_thatchWall2x1_summary = "The simplest and quickest wall to build. Dimensions: 2x1", --0.5
    buildable_thatchRoofEnd = "Thatch Roof End Wall", --0.4 added "End"
    buildable_thatchRoofEnd_plural = "Thatch Roof End Walls", --0.4 added "End"
    buildable_thatchRoofEnd_summary = "The simplest and quickest wall to build. Fills the end triangle of a hut/roof.", --0.4 modified
    buildable_splitLogFloor = "Split Log Floor 2x2",
    buildable_splitLogFloor_plural = "Split Log Floor 2x2s",
    buildable_splitLogFloor_summary = "A simple floor.",
    buildable_splitLogFloor1x1 = "Split Log Floor 1x1", -- 0.6.1
    buildable_splitLogFloor1x1_plural = "Split Log Floor 1x1s", -- 0.6.1
    buildable_splitLogFloor1x1_summary = "A simple floor.", -- 0.6.1
    buildable_splitLogFloor4x4 = "Split Log Floor 4x4",
    buildable_splitLogFloor4x4_plural = "Split Log Floor 4x4s",
    buildable_splitLogFloor4x4_summary = "A simple floor.",
    buildable_splitLogFloorTri2 = "Split Log Floor Triangle", --0.4
    buildable_splitLogFloorTri2_plural = "Split Log Floor Triangles", --0.4
    buildable_splitLogFloorTri2_summary = "A wooden triangular floor.", --0.4
    buildable_splitLogWall = "Split Log Wall",
    buildable_splitLogWall_plural = "Split Log Walls",
    buildable_splitLogWall_summary = "A strong wall made of wood. Dimensions: 4x2",
    buildable_splitLogWall4x1 = "Split Log Short Wall",
    buildable_splitLogWall4x1_plural = "Split Log Short Walls",
    buildable_splitLogWall4x1_summary = "A strong wall made of wood. Dimensions: 4x1",
    buildable_splitLogWall2x2 = "Split Log Square Wall",
    buildable_splitLogWall2x2_plural = "Split Log Square Walls",
    buildable_splitLogWall2x2_summary = "A strong wall made of wood. Dimensions: 2x2",
    buildable_splitLogWall2x1 = "Split Log Short Wall 2x1", --0.5
    buildable_splitLogWall2x1_plural = "Split Log Short Walls 2x1", --0.5
    buildable_splitLogWall2x1_summary = "A strong wall made of wood. Dimensions: 2x1", --0.5
    buildable_splitLogWallDoor = "Split Log Wall With Door",
    buildable_splitLogWallDoor_plural = "Split Log Walls With Doors",
    buildable_splitLogWallDoor_summary = "A strong wall made of wood. Dimensions: 4x2",
    buildable_splitLogWallLargeWindow = "Split Log Wall With Large Window",
    buildable_splitLogWallLargeWindow_plural = "Split Log Walls With Large Windows",
    buildable_splitLogWallLargeWindow_summary = "A strong wall made of wood. Dimensions: 4x2",
    buildable_splitLogRoofEnd = "Split Log Roof End Wall", --0.4 added "End"
    buildable_splitLogRoofEnd_plural = "Split Log Roof End Walls", --0.4 added "End"
    buildable_splitLogRoofEnd_summary = "A strong wall made of wood. Fills the end triangle of a hut/roof.", --0.4 modified
    buildable_splitLogBench = "Split Log Bench",
    buildable_splitLogBench_plural = "Split Log Benches",
    buildable_splitLogBench_summary = "A good place to sit.",
    buildable_splitLogShelf = "Split Log Shelf", --0.5
    buildable_splitLogShelf_plural = "Split Log Shelves", --0.5
    buildable_splitLogShelf_summary = "Works like a storage area, for storing and displaying small items.", --0.5
    buildable_splitLogToolRack = "Split Log Tool Rack", --0.5
    buildable_splitLogToolRack_plural = "Split Log Tool Racks", --0.5
    buildable_splitLogToolRack_summary = "Works like a storage area, for storing spears, axes, and other long-handled tools.", --0.5
    buildable_sled = "Sled", --0.5
    buildable_sled_plural = "Sleds", --0.5
    buildable_sled_summary = "Haul piles of items over long distances. Works like a storage area, but can be dragged to different locations over any type of terrain.", --0.5
    buildable_canoe = "Canoe", --0.5.1
    buildable_canoe_plural = "Canoes", --0.5.1
    buildable_canoe_summary = "Moves quickly over water, and can carry a small quantity of items.", --0.5.1
    buildable_canoe_researchClueText = "Carve and float on water", --0.5.1
    buildable_coveredCanoe = "Covered Canoe", --0.5.1
    buildable_coveredCanoe_plural = "Covered Canoes", --0.5.1
    buildable_coveredCanoe_summary = "Moves quickly over water. The cover helps to prevent the contents from spoiling.", --0.5.1
    buildable_coveredSled = "Covered Sled", --0.5
    buildable_coveredSled_plural = "Covered Sleds", --0.5
    buildable_coveredSled_summary = "Haul piles of items over long distances. The cover helps to prevent the contents from spoiling.", --0.5
    buildable_splitLogSteps = "Split Log Steps 2x3 Single Floor",
    buildable_splitLogSteps_plural = "Split Log Steps 2x3 Single Floor",
    buildable_splitLogSteps_summary = "For moving between floors or up hillsides.",
    buildable_splitLogSteps2x2 = "Split Log Steps 2x2 Half Floor",
    buildable_splitLogSteps2x2_plural = "Split Log Steps 2x2 Half Floor",
    buildable_splitLogSteps2x2_summary = "For moving between floors or up hillsides.",
    buildable_splitLogRoof = "Split Log Hut/Roof",
    buildable_splitLogRoof_plural = "Split Log Huts/Roofs",
    buildable_splitLogRoof_summary = "A strong shelter, which can also be used as a roof.",
    buildable_splitLogRoofSlope = "Split Log Roof Sloping Section", --0.4
    buildable_splitLogRoofSlope_plural = "Split Log Roof Sloping Sections", --0.4
    buildable_splitLogRoofSlope_summary = "Useful near corners, or to fill a small gap.", --0.4
    buildable_splitLogRoofSmallCorner = "Split Log Roof Corner", --0.4
    buildable_splitLogRoofSmallCorner_plural = "Split Log Roof Corners", --0.4
    buildable_splitLogRoofSmallCorner_summary = "A small roof corner.", --0.4
    buildable_splitLogRoofSmallCornerInside = "Split Log Roof Inner Corner", --0.4
    buildable_splitLogRoofSmallCornerInside_plural = "Split Log Roof Inner Corners", --0.4
    buildable_splitLogRoofSmallCornerInside_summary = "To fill that pesky gap.", --0.4
    buildable_splitLogRoofTriangle = "Split Log Roof Triangle", --0.4
    buildable_splitLogRoofTriangle_plural = "Split Log Roof Triangles", --0.4
    buildable_splitLogRoofTriangle_summary = "Useful above triangluar floors.", --0.4
    buildable_splitLogRoofInvertedTriangle = "Split Log Roof Inverted Triangle", --0.4
    buildable_splitLogRoofInvertedTriangle_plural = "Split Log Roof Inverted Triangles", --0.4
    buildable_splitLogRoofInvertedTriangle_summary = "Useful above triangluar floors.", --0.4
    buildable_mudBrickWall = "Mudbrick Wall",
    buildable_mudBrickWall_plural = "Mudbrick Walls",
    buildable_mudBrickWall_summary = "A sturdy wall, but can be damaged by rain. Dimensions: 4x2", --0.4 updated with addition of "but can be damaged by rain"
    buildable_mudBrickWallDoor = "Mudbrick Wall With Door",
    buildable_mudBrickWallDoor_plural = "Mudbrick Walls With Doors",
    buildable_mudBrickWallDoor_summary = "A sturdy wall, but can be damaged by rain. Dimensions: 4x2", --0.4 updated with addition of "but can be damaged by rain"
    buildable_mudBrickWallLargeWindow = "Mudbrick Wall With Large Window",
    buildable_mudBrickWallLargeWindow_plural = "Mudbrick Walls With Large Windows",
    buildable_mudBrickWallLargeWindow_summary = "A sturdy wall, but can be damaged by rain. Dimensions: 4x2", --0.4 updated with addition of "but can be damaged by rain"
    buildable_mudBrickWall4x1 = "Mudbrick Short Wall", -- 0.4 changed "Half" to "Short"
    buildable_mudBrickWall4x1_plural = "Mudbrick Short Walls", -- 0.4 changed "Half" to "Short"
    buildable_mudBrickWall4x1_summary = "A sturdy wall, but can be damaged by rain. Dimensions: 4x1", --0.4 updated with addition of "but can be damaged by rain"
    buildable_mudBrickWall2x2 = "Mudbrick Square Wall",
    buildable_mudBrickWall2x2_plural = "Mudbrick Square Walls",
    buildable_mudBrickWall2x2_summary = "A sturdy wall, but can be damaged by rain. Dimensions: 2x2", --0.4 updated with addition of "but can be damaged by rain"
    buildable_mudBrickWall2x1 = "Mudbrick Short Wall 2x1", --0.5
    buildable_mudBrickWall2x1_plural = "Mudbrick Short Walls 2x1", --0.5
    buildable_mudBrickWall2x1_summary = "A sturdy wall, but can be damaged by rain. Dimensions: 2x1", --0.5
    buildable_mudBrickRoofEnd = "Mudbrick Roof End Wall", --0.4
    buildable_mudBrickRoofEnd_plural = "Mudbrick Roof End Walls", --0.4
    buildable_mudBrickRoofEnd_summary = "A sturdy wall, but can be damaged by rain. Fills the end triangle of a hut/roof.", --0.4
    buildable_mudBrickColumn = "Mudbrick Column",
    buildable_mudBrickColumn_plural = "Mudbrick Columns",
    buildable_mudBrickColumn_summary = "A decorative column. Can be damaged by rain.", --0.4 updated with addition of "Can be damaged by rain"
    buildable_mudBrickFloor1x1 = "Mudbrick Floor 1x1", -- 0.6.1
    buildable_mudBrickFloor1x1_plural = "Mudbrick Floor 1x1s", -- 0.6.1
    buildable_mudBrickFloor1x1_summary = "A good floor for dry locations.", -- 0.6.1
    buildable_mudBrickFloor2x2 = "Mudbrick Floor 2x2",
    buildable_mudBrickFloor2x2_plural = "Mudbrick Floor 2x2s",
    buildable_mudBrickFloor2x2_summary = "A good floor for dry locations.",
    buildable_mudBrickFoundation1x1 = "Mudbrick Foundation 1x1", -- 0.6.1
    buildable_mudBrickFoundation1x1_plural = "Mudbrick Foundation 1x1s", -- 0.6.1
    buildable_mudBrickFoundation1x1_summary = "A good foundation for dry locations.", -- 0.6.1
    buildable_mudBrickFoundation2x2 = "Mudbrick Foundation 2x2", -- 0.6.1
    buildable_mudBrickFoundation2x2_plural = "Mudbrick Foundation 2x2s", -- 0.6.1
    buildable_mudBrickFoundation2x2_summary = "A good foundation for dry locations.", -- 0.6.1
    buildable_mudBrickFloor4x4 = "Mudbrick Floor 4x4",
    buildable_mudBrickFloor4x4_plural = "Mudbrick Floor 4x4s",
    buildable_mudBrickFloor4x4_summary = "A good floor for dry locations.",
    buildable_mudBrickFloorTri2 = "Mudbrick Floor Triangle", --0.4
    buildable_mudBrickFloorTri2_plural = "Mudbrick Floor Triangles", --0.4
    buildable_mudBrickFloorTri2_summary = "A good floor for dry locations.", --0.4

    buildable_stoneBlockWall = "Stone Block Wall", --0.4
    buildable_stoneBlockWall_plural = "Stone Block Walls", --0.4
    buildable_stoneBlockWall_summary = "A sturdy wall. Dimensions: 4x2", --0.4
    buildable_stoneBlockWallDoor = "Stone Block Wall With Door", --0.4
    buildable_stoneBlockWallDoor_plural = "Stone Block Walls With Doors", --0.4
    buildable_stoneBlockWallDoor_summary = "A sturdy wall. Dimensions: 4x2", --0.4
    buildable_stoneBlockWallLargeWindow = "Stone Block Wall With Large Window", --0.4
    buildable_stoneBlockWallLargeWindow_plural = "Stone Block Walls With Large Windows", --0.4
    buildable_stoneBlockWallLargeWindow_summary = "A sturdy wall. Dimensions: 4x2", --0.4
    buildable_stoneBlockRoofEnd = "Stone Block Roof End Wall", --0.4
    buildable_stoneBlockRoofEnd_plural = "Stone Block Roof End Walls", --0.4
    buildable_stoneBlockRoofEnd_summary = "A sturdy wall. Fills the end triangle of a hut/roof.", --0.4
    buildable_stoneBlockWall4x1 = "Stone Block Short Wall", --0.4
    buildable_stoneBlockWall4x1_plural = "Stone Block Short Walls", --0.4
    buildable_stoneBlockWall4x1_summary = "A sturdy wall. Dimensions: 4x1", --0.4
    buildable_stoneBlockWall2x2 = "Stone Block Square Wall", --0.4
    buildable_stoneBlockWall2x2_plural = "Stone Block Square Walls", --0.4
    buildable_stoneBlockWall2x2_summary = "A sturdy wall. Dimensions: 2x2", --0.4
    buildable_stoneBlockWall2x1 = "Stone Block Short Wall 2x1", --0.5
    buildable_stoneBlockWall2x1_plural = "Stone Block Short Walls 2x1", --0.5
    buildable_stoneBlockWall2x1_summary = "A sturdy wall. Dimensions: 2x1", --0.5
    buildable_stoneBlockColumn = "Stone Block Column", --0.4
    buildable_stoneBlockColumn_plural = "Stone Block Columns", --0.4
    buildable_stoneBlockColumn_summary = "A decorative column.", --0.4
    buildable_stoneBlockFoundation1x1 = "Stone Block Foundation 1x1", -- 0.6.1
    buildable_stoneBlockFoundation1x1_plural = "Stone Block Foundation 1x1s", -- 0.6.1
    buildable_stoneBlockFoundation1x1_summary = "A sturdy foundation.", -- 0.6.1
    buildable_stoneBlockFoundation2x2 = "Stone Block Foundation 2x2", -- 0.6.1
    buildable_stoneBlockFoundation2x2_plural = "Stone Block Foundation 2x2s", -- 0.6.1
    buildable_stoneBlockFoundation2x2_summary = "A sturdy foundation.", -- 0.6.1

    buildable_brickWall = "Brick Wall",
    buildable_brickWall_plural = "Brick Walls",
    buildable_brickWall_summary = "A sturdy wall. Dimensions: 4x2",
    buildable_brickWallDoor = "Brick Wall With Door",
    buildable_brickWallDoor_plural = "Brick Walls With Doors",
    buildable_brickWallDoor_summary = "A sturdy wall. Dimensions: 4x2",
    buildable_brickWallLargeWindow = "Brick Wall With Large Window",
    buildable_brickWallLargeWindow_plural = "Brick Walls With Large Windows",
    buildable_brickWallLargeWindow_summary = "A sturdy wall. Dimensions: 4x2",
    buildable_brickWall4x1 = "Brick Short Wall", -- 0.4 changed "Half" to "Short"
    buildable_brickWall4x1_plural = "Brick Short Walls", -- 0.4 changed "Half" to "Short"
    buildable_brickWall4x1_summary = "A sturdy wall. Dimensions: 4x1",
    buildable_brickWall2x2 = "Brick Square Wall",
    buildable_brickWall2x2_plural = "Brick Square Walls",
    buildable_brickWall2x2_summary = "A sturdy wall. Dimensions: 2x2",
    buildable_brickWall2x1 = "Brick Short Wall 2x1", --0.5
    buildable_brickWall2x1_plural = "Brick Short Walls 2x1", --0.5
    buildable_brickWall2x1_summary = "A sturdy wall. Dimensions: 2x1", --0.5
    buildable_brickRoofEnd = "Brick Roof End Wall", --0.4
    buildable_brickRoofEnd_plural = "Brick Roof End Walls", --0.4
    buildable_brickRoofEnd_summary = "A sturdy wall. Fills the end triangle of a hut/roof.", --0.4
    buildable_brickFoundation1x1 = "Brick Foundation 1x1", -- 0.6.1
    buildable_brickFoundation1x1_plural = "Brick Foundation 1x1s", -- 0.6.1
    buildable_brickFoundation1x1_summary = "A sturdy foundation.", -- 0.6.1
    buildable_brickFoundation2x2 = "Brick Foundation 2x2", -- 0.6.1
    buildable_brickFoundation2x2_plural = "Brick Foundation 2x2s", -- 0.6.1
    buildable_brickFoundation2x2_summary = "A sturdy foundation.", -- 0.6.1
    buildable_tileFloor1x1 = "Tile Floor 1x1", --0.6.1
    buildable_tileFloor1x1_plural = "Tile Floor 1x1s", --0.6.1
    buildable_tileFloor1x1_summary = "Rustic charm.", --0.6.1
    buildable_tileFloor2x2 = "Tile Floor 2x2",
    buildable_tileFloor2x2_plural = "Tile Floor 2x2s",
    buildable_tileFloor2x2_summary = "Rustic charm.",
    buildable_tileFloor4x4 = "Tile Floor 4x4",
    buildable_tileFloor4x4_plural = "Tile Floor 4x4s",
    buildable_tileFloor4x4_summary = "Rustic charm.",
    buildable_genericPath_summary = "Paths allow sapiens to move around faster.",
    buildable_tileRoof = "Tile Hut/Roof",
    buildable_tileRoof_plural = "Tile Huts/Roofs",
    buildable_tileRoof_summary = "A sturdy weatherproof roof.",
    buildable_tileRoofSlope = "Tile Roof Sloping Section", --0.4
    buildable_tileRoofSlope_plural = "Tile Roof Sloping Sections", --0.4
    buildable_tileRoofSlope_summary = "Useful near corners, or to fill a small gap.", --0.4
    buildable_tileRoofSmallCorner = "Tile Roof Corner", --0.4
    buildable_tileRoofSmallCorner_plural = "Tile Roof Corners", --0.4
    buildable_tileRoofSmallCorner_summary = "A small roof corner.", --0.4
    buildable_tileRoofSmallCornerInside = "Tile Roof Inner Corner", --0.4
    buildable_tileRoofSmallCornerInside_plural = "Tile Roof Inner Corners", --0.4
    buildable_tileRoofSmallCornerInside_summary = "To fill that pesky gap.", --0.4
    buildable_tileRoofTriangle = "Tile Roof Triangle", --0.4
    buildable_tileRoofTriangle_plural = "Tile Roof Triangles", --0.4
    buildable_tileRoofTriangle_summary = "Useful above triangluar floors.", --0.4
    buildable_tileRoofInvertedTriangle = "Tile Roof Inverted Triangle", --0.4
    buildable_tileRoofInvertedTriangle_plural = "Tile Roof Inverted Triangles", --0.4
    buildable_tileRoofInvertedTriangle_summary = "Useful above triangluar floors.", --0.4
    buildable_tileFloorTri2 = "Tile Floor Triangle", --0.4
    buildable_tileFloorTri2_plural = "Tile Floor Triangles", --0.4
    buildable_tileFloorTri2_summary = "Rustic charm.", --0.4
    buildable_fertilize = "Mulch", --0.4
    buildable_fertilize_plural = "Mulch", --0.4
    buildable_fertilize_summary = "Enrich soil by digging in compost or manure.", --0.4

    -- these buildableVariationGroup values are displayed as a tool tip in the build UI when you hover over the icon in the grid
    buildableVariationGroup_bed = "Bed", --0.5
    buildableVariationGroup_splitLogFloor = "Split Log Floor", --0.5
    buildableVariationGroup_splitLogSteps = "Split Log Steps", --0.5
    buildableVariationGroup_mudBrickFloor = "Mud Brick Floor", --0.5
    buildableVariationGroup_dirtFoundation = "Dirt Foundation", --0.6.1
    buildableVariationGroup_mudBrickFoundation = "Mud Brick Foundation", --0.6.1
    buildableVariationGroup_stoneBlockFoundation = "Stone Block Foundation", --0.6.1
    buildableVariationGroup_brickFoundation = "Brick Foundation", --0.6.1
    buildableVariationGroup_tileFloor = "Tile Floor", --0.5
    buildableVariationGroup_storageArea = "Storage Area", --0.5
    
    

    
    --craftables
    craftable_rockSmall = "Hard Small Rock", --0.4 added "Hard", 0.5 changed
    craftable_rockSmall_plural = "Hard Small Rocks", --0.4 added "Hard", 0.5 changed
    craftable_rockSmall_summary = "Can be knapped into basic tools.",
    craftable_rockSmallSoft = "Soft Small Rock", --0.4, 0.5 changed
    craftable_rockSmallSoft_plural = "Soft Small Rocks", --0.4, 0.5 changed
    craftable_rockSmallSoft_summary = "Can be quickly knapped into simple hand axes.", --0.4
    craftable_stoneSpearHead = "Stone Spear Head",
    craftable_stoneSpearHead_plural = "Stone Spear Heads",
    craftable_stoneSpearHead_summary = "Used for making stone spears.",
    craftable_stonePickaxeHead = "Stone Pickaxe Head",
    craftable_stonePickaxeHead_plural = "Stone Pickaxe Heads",
    craftable_stonePickaxeHead_summary = "Used for making stone pickaxes.",
    craftable_flintSpearHead = "Flint Spear Head",
    craftable_flintSpearHead_plural = "Flint Spear Heads",
    craftable_flintSpearHead_summary = "Used for making flint spears.",
    craftable_boneSpearHead = "Bone Spear Head",
    craftable_boneSpearHead_plural = "Bone Spear Heads",
    craftable_boneSpearHead_summary = "Used for making bone spears.",
    craftable_stoneKnife = "Stone Knife",
    craftable_stoneKnife_plural = "Stone Knives",
    craftable_stoneKnife_summary = "Used for many things, including butchering and crafting with wood.",
    craftable_stoneChisel = "Stone Chisel", --0.4
    craftable_stoneChisel_plural = "Stone Chisels", --0.4
    craftable_stoneChisel_summary = "Used to cut stone blocks out from soft rock like sandstone and limestone, and to carve wood.", --0.4
    craftable_quernstone = "Quern-stone",
    craftable_quernstone_plural = "Quern-stones",
    craftable_quernstone_summary = "Used for grinding, can grind wheat into flour.",
    craftable_flintKnife = "Flint Knife",
    craftable_flintKnife_plural = "Flint Knives",
    craftable_flintKnife_summary = "Used for many things, including butchering and crafting with wood.",
    craftable_boneKnife = "Bone Knife",
    craftable_boneKnife_plural = "Bone Knives",
    craftable_boneKnife_summary = "Used for many things, including butchering and crafting with wood.",
    craftable_bronzeKnife = "Bronze Knife", --0.4
    craftable_bronzeKnife_plural = "Bronze Knives", --0.4
    craftable_bronzeKnife_summary = "Used for many things, including butchering and crafting with wood.", --0.4
    craftable_bronzeChisel = "Bronze Chisel", --0.4
    craftable_bronzeChisel_plural = "Bronze Chisels", --0.4
    craftable_bronzeChisel_summary = "Used to cut stone blocks out from both soft and hard rock, and to carve wood.", --0.4
    craftable_boneFlute = "Bone Flute",
    craftable_boneFlute_plural = "Bone Flutes",
    craftable_boneFlute_summary = "Music helps to keep sapiens happy.",
    craftable_logDrum = "Log Drum",
    craftable_logDrum_plural = "Log Drums",
    craftable_logDrum_summary = "Music helps to keep sapiens happy.",
    craftable_logDrum_researchClueText = "Carve and make sounds",
    craftable_balafon = "Balafon",
    craftable_balafon_plural = "Balafons",
    craftable_balafon_summary = "Music helps to keep sapiens happy.",
    craftable_flintPickaxeHead = "Flint Pickaxe Head",
    craftable_flintPickaxeHead_plural = "Flint Pickaxe Heads",
    craftable_flintPickaxeHead_summary = "Used for making flint pickaxes.",
    craftable_woodenPole = "Wooden Pole (Deprecated)",
    craftable_woodenPole_plural = "Wooden Poles (Deprecated)",
    craftable_woodenPole_summary = "Will be removed from the game soon.",
    craftable_stoneSpear = "Stone Spear",
    craftable_stoneSpear_plural = "Stone Spears",
    craftable_stoneSpear_summary = "Used for hunting.", --0.5 changed
    craftable_flintSpear = "Flint Spear",
    craftable_flintSpear_plural = "Flint Spears",
    craftable_flintSpear_summary = "Used for hunting.", --0.5 changed
    craftable_boneSpear = "Bone Spear",
    craftable_boneSpear_plural = "Bone Spears",
    craftable_boneSpear_summary = "Used for hunting.", --0.5 changed
    craftable_stonePickaxe = "Stone Pickaxe",
    craftable_stonePickaxe_plural = "Stone Pickaxes",
    craftable_stonePickaxe_summary = "Can be used to mine rock, and also dig more easily.",
    craftable_flintPickaxe = "Flint Pickaxe",
    craftable_flintPickaxe_plural = "Flint Pickaxes",
    craftable_flintPickaxe_summary = "Can be used to mine rock, and also dig more easily.",
    craftable_stoneHatchet = "Stone Hatchet",
    craftable_stoneHatchet_plural = "Stone Hatchets",
    craftable_stoneHatchet_summary = "Good for chopping trees.",
    craftable_stoneAxeHead = "Hard Stone Hand Axe", --0.4 added "(Hard Rock)", 0.5 changed
    craftable_stoneAxeHead_plural = "Hard Stone Hand Axes", --0.4 added "(Hard Rock)", 0.5 changed
    craftable_stoneAxeHead_summary = "Can be used to chop wood, and dig the ground. Can also be used to make hatchets.", --0.4 added "Can also be used to make hatchets"
    craftable_stoneAxeHeadSoft = "Soft Stone Hand Axe", --0.4, 0.5 changed
    craftable_stoneAxeHeadSoft_plural = "Soft Stone Hand Axes", --0.4, 0.5 changed
    craftable_stoneAxeHeadSoft_summary = "Can be used to chop wood, and dig the ground. This rock type is soft, so it is quick to craft but will degrade quickly.", --0.4
    craftable_stoneAxeHeadGeneric = "Stone Hand Axe", --0.5
    craftable_stoneAxeHeadGeneric_plural = "Stone Hand Axes", --0.5
    craftable_flintAxeHead = "Flint Hand Axe",
    craftable_flintAxeHead_plural = "Flint Hand Axes",
    craftable_flintAxeHead_summary = "Can be used to chop wood, and dig the ground.",
    craftable_flintHatchet = "Flint Hatchet",
    craftable_flintHatchet_plural = "Flint Hatchets",
    craftable_flintHatchet_summary = "Good for chopping trees.",

    craftable_bronzeAxeHead = "Bronze Hand Axe", --0.4
    craftable_bronzeAxeHead_plural = "Bronze Hand Axes", --0.4
    craftable_bronzeAxeHead_summary = "Can be used to chop wood, and dig the ground.", --0.4
    craftable_bronzeHatchet = "Bronze Hatchet", --0.4
    craftable_bronzeHatchet_plural = "Bronze Hatchets", --0.4
    craftable_bronzeHatchet_summary = "Good for chopping trees.", --0.4
    craftable_bronzeSpearHead = "Bronze Spear Head", --0.4
    craftable_bronzeSpearHead_plural = "Bronze Spear Heads", --0.4
    craftable_bronzeSpearHead_summary = "Used for making bronze spears.", --0.4
    craftable_bronzeSpear = "Bronze Spear", --0.4
    craftable_bronzeSpear_plural = "Bronze Spears", --0.4
    craftable_bronzeSpear_summary = "Used for hunting, fishing, and combat.", --0.4
    craftable_bronzePickaxeHead = "Bronze Pickaxe Head", --0.4
    craftable_bronzePickaxeHead_plural = "Bronze Pickaxe Heads", --0.4
    craftable_bronzePickaxeHead_summary = "Used for making bronze pickaxes.", --0.4
    craftable_bronzePickaxe = "Bronze Pickaxe", --0.4
    craftable_bronzePickaxe_plural = "Bronze Pickaxes", --0.4
    craftable_bronzePickaxe_summary = "Can be used to mine rock, and also dig more easily.", --0.4
    craftable_stoneHammerHead = "Stone Hammer Head", --0.4
    craftable_stoneHammerHead_plural = "Stone Hammer Heads", --0.4
    craftable_stoneHammerHead_summary = "Used to craft hammers for blacksmithing.", --0.4
    craftable_stoneHammer = "Stone Hammer", --0.4
    craftable_stoneHammer_plural = "Stone Hammers", --0.4
    craftable_stoneHammer_summary = "For building and blacksmithing.", --0.4
    craftable_bronzeHammerHead = "Bronze Hammer Head", --0.4
    craftable_bronzeHammerHead_plural = "Bronze Hammer Heads", --0.4
    craftable_bronzeHammerHead_summary = "Used to craft hammers for blacksmithing.", --0.4
    craftable_bronzeHammer = "Bronze Hammer", --0.4
    craftable_bronzeHammer_plural = "Bronze Hammers", --0.4
    craftable_bronzeHammer_summary = "For blacksmithing.", --0.4

    craftable_splitLog = "Split Log",
    craftable_splitLog_plural = "Split Logs",
    craftable_splitLog_summary = "Used for building, can also be walked on.", --b20
    craftable_butcherChicken = "Butcher Chicken",
    craftable_butcherChicken_plural = "Butcher Chickens",
    craftable_butcherChicken_action = "Butchering a chicken", --0.3.0
    craftable_butcherChicken_summary = "Collect meat from chicken.",
    craftable_butcherAlpaca = "Butcher Alpaca",
    craftable_butcherAlpaca_plural = "Butcher Alpacas",
    craftable_butcherAlpaca_action = "Butchering an alpaca", --0.3.0
    craftable_butcherAlpaca_summary = "Collect meat and wool from alpaca.",

    craftable_fishFillet = "Fish Fillets",
    craftable_fishFillet_plural = "Fish Fillets",
    craftable_fishFillet_action = "Filleting fish",
    craftable_fishFillet_summary = "Fillet a large fish.",

    craftable_cookedChicken = "Cooked Chicken Meat",
    craftable_cookedChicken_plural = "Cooked Chicken Meat",
    craftable_cookedChicken_summary = "Winner winner.",
    craftable_campfireRoastedPumpkin = "Campfire Roasted Pumpkin",
    craftable_campfireRoastedPumpkin_plural = "Campfire Roasted Pumpkin",
    craftable_campfireRoastedPumpkin_summary = "Gourdgeous.",
    craftable_campfireRoastedBeetroot = "Campfire Roasted Beetroot",
    craftable_campfireRoastedBeetroot_plural = "Campfire Roasted Beetroot",
    craftable_campfireRoastedBeetroot_summary = "Beets eating it raw.",
    craftable_cookedFish = "Cooked Fish", --0.5.1.4
    craftable_cookedFish_plural = "Cooked Fish", --0.5.1.4
    craftable_cookedFish_summary = "More filling, and safer to eat than raw fish.", --0.5.1.4
    craftable_flatbread = "Flatbread",
    craftable_flatbread_plural = "Flatbreads",
    craftable_flatbread_summary = "The simplest bread.",    
    craftable_unfiredUrnWet = "Unfired Urn",
    craftable_unfiredUrnWet_plural = "Unfired Urns",
    craftable_unfiredUrnWet_summary = "Can be used to store grains. Keeps contents longer when fired.", --0.3.0 modified
    craftable_firedUrn = "Fired Urn",
    craftable_firedUrn_plural = "Fired Urns",
    craftable_firedUrn_summary = "Can be used to store grains. Keeps contents longer when fired.", --0.3.0 modified
    craftable_unfiredBowlWet = "Unfired Bowl", --0.3.0
    craftable_unfiredBowlWet_plural = "Unfired Bowls", --0.3.0
    craftable_unfiredBowlWet_summary = "Can be used to hold medicines. Keeps contents longer when fired.", --0.3.0
    craftable_firedBowl = "Fired Bowl", --0.3.0
    craftable_firedBowl_plural = "Fired Bowls", --0.3.0
    craftable_firedBowl_summary = "Can be used to hold medicines. Keeps contents longer when fired.", --0.3.0
    craftable_crucibleWet = "Crucible", --0.4
    craftable_crucibleWet_plural = "Crucibles", --0.4
    craftable_crucibleWet_summary = "Used to hold molten metal when crafting ingots.", --0.4
    craftable_hulledWheat = "Hulled Wheat",
    craftable_hulledWheat_plural = "Hulled Wheat",
    craftable_hulledWheat_summary = "Can be processed into flour.", --0.3.0 removed mention of pottage, as it isn't in the game
    craftable_thatchResearch = "Thatch Research",
    craftable_thatchResearch_plural = "Thatch Research",
    craftable_thatchResearch_summary = "Thatch Research.",
    craftable_mudBrickBuildingResearch = "Masonry Research", --0.4 changed from mud brick building to masonry, now applies to all brick/block based building
    craftable_mudBrickBuildingResearch_plural = "Masonry Research", --0.4 changed from mud brick building to masonry, now applies to all brick/block based building
    craftable_mudBrickBuildingResearch_summary = "Masonry Research.", --0.4 changed from mud brick building to masonry, now applies to all brick/block based building
    craftable_woodBuildingResearch = "Wood Building Research",
    craftable_woodBuildingResearch_plural = "Wood Building Research",
    craftable_woodBuildingResearch_summary = "Wood Building Research.",
    craftable_tilingResearch = "Tiling Research",
    craftable_tilingResearch_plural = "Tiling Research",
    craftable_tilingResearch_summary = "Tiling Research.",
    craftable_plantingResearch = "Planting Research.",
    craftable_plantingResearch_plural = "Planting Research",
    craftable_plantingResearch_summary = "Planting Research.",
    craftable_flour = "Flour",
    craftable_flour_plural = "Flour",
    craftable_flour_summary = "Used to make bread.",
    craftable_breadDough = "Bread Dough",
    craftable_breadDough_plural = "Bread Dough",
    craftable_breadDough_summary = "Can be baked into bread.",
    craftable_flaxTwine = "Flax Twine",
    craftable_flaxTwine_plural = "Flax Twine",
    craftable_flaxTwine_summary = "Used for more advanced tool making, and weaving.",
    craftable_mudBrickWet = "Mud Brick",
    craftable_mudBrickWet_plural = "Mud Bricks",
    craftable_mudBrickWet_summary = "Once dry, can be used for building shelter, as well as for constructing kilns.",
    craftable_mudTileWet = "Unfired Tile",
    craftable_mudTileWet_plural = "Unfired Tiles",
    craftable_mudTileWet_summary = "Once dried and fired, can be used for roofs, floors, and paths.",
    craftable_firedTile = "Tile",
    craftable_firedTile_plural = "Tiles",
    craftable_firedTile_summary = "Can be used for roofs, floors, and paths.",
    craftable_cookedAlpaca = "Cooked Alpaca Meat",
    craftable_cookedAlpaca_plural = "Cooked Alpaca Meat",
    craftable_cookedAlpaca_summary = "One leg or rack can feed a large family.",
    craftable_cookedMammoth = "Cooked Mammoth Meat",
    craftable_cookedMammoth_plural = "Cooked Mammoth Meat",
    craftable_cookedMammoth_summary = "Tastes like furry elephant.",
    craftable_firedBrick = "Brick",
    craftable_firedBrick_plural = "Bricks",
    craftable_firedBrick_summary = "A durable resource for building with.",
    
    --0.3.0 group:
    craftable_injuryMedicine = "Injury Medicine",
    craftable_injuryMedicine_plural = "Injury Medicine",
    craftable_injuryMedicine_summary = "Treats general physical injuries.",
    craftable_burnMedicine = "Burn Medicine",
    craftable_burnMedicine_plural = "Burn Medicine",
    craftable_burnMedicine_summary = "Treats burns.",
    craftable_foodPoisoningMedicine = "Poisoning Medicine",
    craftable_foodPoisoningMedicine_plural = "Poisoning Medicine",
    craftable_foodPoisoningMedicine_summary = "Treats stomach issues caused by food poisoning.",
    craftable_virusMedicine = "Virus Medicine",
    craftable_virusMedicine_plural = "Virus Medicine",
    craftable_virusMedicine_summary = "Treats colds and viral infections.",
    --0.3.0 group end
    
    craftable_bronzeIngot = "Bronze Ingot", --0.4
    craftable_bronzeIngot_plural = "Bronze Ingots", --0.4
    craftable_bronzeIngot_summary = "Used to craft stronger tools and weapons.", --0.4
    craftable_stoneTileSoft = "Soft Stone Tile", --0.4, 0.5 changed
    craftable_stoneTileSoft_plural = "Soft Stone Tiles", --0.4, 0.5 changed
    craftable_stoneTileSoft_summary = "Chisel limestone or sandstone into tiles for roofs, floors, and paths.", --0.4
    craftable_stoneTileHard = "Hard Stone Tile", --0.4, 0.5
    craftable_stoneTileHard_plural = "Hard Stone Tiles", --0.4, 0.5
    craftable_stoneTileHard_summary = "Chisel hard rock, granite or marble into tiles for roofs, floors, and paths.", --0.4

    craftable_stoneTileGeneric = "Stone Tile", --0.5
    craftable_stoneTileGeneric_plural = "Stone Tiles", --0.5

    --actions
    action_idle = "Idle",
    action_idle_inProgress = "Idle",
    action_gather = "Gather",
    action_gather_inProgress = "Gathering",
    action_chop = "Chop",
    action_chop_inProgress = "Chopping",
    action_pullOut = "Pull Out",
    action_pullOut_inProgress = "Pulling out",
    action_dig = "Dig",
    action_dig_inProgress = "Digging",
    action_mine = "Mine",
    action_mine_inProgress = "Mining",
    action_clear = "Clear",
    action_clear_inProgress = "Clearing",
    action_moveTo = "Move",
    action_moveTo_inProgress = "Moving",
    action_flee = "Flee",
    action_flee_inProgress = "Fleeing",
    action_pickup = "Pickup",
    action_pickup_inProgress = "Picking up",
    action_place = "Place",
    action_place_inProgress = "Placing",
    action_eat = "Eat",
    action_eat_inProgress = "Eating",
    action_playFlute = "Play",
    action_playFlute_inProgress = "Playing",
    action_playDrum = "Play",
    action_playDrum_inProgress = "Playing",
    action_playBalafon = "Play",
    action_playBalafon_inProgress = "Playing",
    action_wave = "Wave",
    action_wave_inProgress = "Waving",
    action_turn = "Turn",
    action_turn_inProgress = "Turning",
    action_fall = "Fall",
    action_fall_inProgress = "Falling",
    action_sleep = "Sleep",
    action_sleep_inProgress = "Sleeping",
    action_build = "Build",
    action_build_inProgress = "Building",
    action_light = "Light",
    action_light_inProgress = "Lighting",
    action_extinguish = "Extinguish",
    action_extinguish_inProgress = "Extinguishing",
    action_destroyContents = "Destroy Contents",
    action_destroyContents_inProgress = "Destroying Contents",
    action_throwProjectile = "Throw",
    action_throwProjectile_inProgress = "Throwing",
    action_butcher = "Butcher",
    action_butcher_inProgress = "Butchering",
    action_knap = "Knap",
    action_knap_inProgress = "Knapping",
    action_grind = "Grind",
    action_grind_inProgress = "Grinding",
    action_potteryCraft = "Craft",
    action_potteryCraft_inProgress = "Crafting",
    action_craft = "Craft", --0.3.0
    action_craft_inProgress = "Crafting", --0.3.0
    action_spinCraft = "Craft",
    action_spinCraft_inProgress = "Crafting",
    action_thresh = "Thresh",
    action_thresh_inProgress = "Threshing",
    action_scrapeWood = "Craft",
    action_scrapeWood_inProgress = "Crafting",
    action_fireStickCook = "Cook",
    action_fireStickCook_inProgress = "Cooking",
    action_smeltMetal = "Smelt", --0.4.2
    action_smeltMetal_inProgress = "Smelting", --0.4.2
    action_recruit = "Recruit",
    action_recruit_inProgress = "Recruiting",
    action_banish = "Banish", --0.7
    action_banish_inProgress = "Banishing", --0.7
    action_fight = "Fight", --0.7
    action_fight_inProgress = "Fighting", --0.7
    action_defend = "Defend", --0.7
    action_defend_inProgress = "Defending", --0.7
    action_sneak = "Sneak",
    action_sneak_inProgress = "Sneaking",
    action_sit = "Sit",
    action_sit_inProgress = "Sitting",
    action_inspect = "Inspect",
    action_inspect_inProgress = "Inspecting",
    action_patDown = "Tidy",
    action_patDown_inProgress = "Tidying",
    action_takeOffTorsoClothing = "Take Off Clothing",
    action_takeOffTorsoClothing_inProgress = "Taking Off Clothing",
    action_putOnTorsoClothing = "Put On Clothing",
    action_putOnTorsoClothing_inProgress = "Putting On Clothing",
    action_greet = "Greet", --0.5
    action_greet_inProgress = "Greeting", --0.5
    action_row = "Row", --0.5.1
    action_row_inProgress = "Rowing", --0.5.1
    
    --0.3.0 group:
    action_selfApplyOralMedicine = "Take Medicine",
    action_selfApplyOralMedicine_inProgress = "Taking Medicine",
    action_selfApplyTopicalMedicine = "Apply Medicine",
    action_selfApplyTopicalMedicine_inProgress = "Applying Medicine",
    action_giveMedicine = "Give Medicine",
    action_giveMedicine_inProgress = "Giving Medicine",
    --0.3.0 group end
    
    action_smithHammer = "Blacksmith", --0.4
    action_smithHammer_inProgress = "Blacksmithing", --0.4
    action_chiselStone = "Chisel", --0.4
    action_chiselStone_inProgress = "Chiselling", --0.4
    
    action_dragObject = "Haul", --0.5
    action_dragObject_inProgress = "Hauling", --0.5

    --action modifiers
    action_jog = "Jog",
    action_jog_inProgress = "Jogging",
    action_run = "Run",
    action_run_inProgress = "Running",
    action_slowWalk = "Slow Walk",
    action_slowWalk_inProgress = "Walking Slowly",
    action_sadWalk = "Sad Walk",
    action_sadWalk_inProgress = "Walking Sadly",
    action_crouch = "Crouch",
    action_crouch_inProgress = "Crouching",

    -- terrain types
    terrain_rock = "Rock",
    terrain_limestone = "Limestone",
    terrain_redRock = "Red Rock",
    terrain_greenRock = "Greenstone",
    terrain_graniteRock = "Granite", --0.4
    terrain_marbleRock = "Marble", --0.4
    terrain_lapisRock = "Lapis Lazuli", --0.4
    terrain_beachSand = "Sand",
    terrain_riverSand = "River Sand",
    terrain_desertSand = "Sand",
    terrain_ice = "Ice",
    terrain_desertRedSand = "Red Desert Sand",
    terrain_dirt = "Soil",
    terrain_richDirt = "Rich Soil",
    terrain_poorDirt = "Poor Soil",
    terrain_clay = "Clay",
    terrain_copperOre = "Copper Ore", --0.4
    terrain_tinOre = "Tin Ore", --0.4
    terrain_sandstoneYellowRock = "Sandstone (Yellow)", --0.4
    terrain_sandstoneRedRock = "Sandstone (Red)", --0.4
    terrain_sandstoneOrangeRock = "Sandstone (Orange)", --0.4
    terrain_sandstoneBlueRock = "Sandstone (Blue)", --0.4

    -- terrain variations
    terrainVariations_snow = "Snow",
    terrainVariations_grassSnow = "Grass/Snow",
    terrainVariations_grass = "Grass",
    terrainVariations_flint = "Flint",
    terrainVariations_clay = "Clay",
    terrainVariations_copperOre = "Copper Ore", --0.4
    terrainVariations_tinOre = "Tin Ore", --0.4
    terrainVariations_limestone = "Limestone",
    terrainVariations_redRock = "Red Rock",
    terrainVariations_greenRock = "Greenstone",
    terrainVariations_graniteRock = "Granite", --0.4
    terrainVariations_marbleRock = "Marble", --0.4
    terrainVariations_lapisRock = "Lapis Lazuli", --0.4
    terrainVariations_shallowWater = "Shallow Water",
    terrainVariations_deepWater = "Deep Water",
    terrainVariations_sandstoneYellowRock = "Sandstone (Yellow)", --0.4
    terrainVariations_sandstoneRedRock = "Sandstone (Red)", --0.4
    terrainVariations_sandstoneOrangeRock = "Sandstone (Orange)", --0.4
    terrainVariations_sandstoneBlueRock = "Sandstone (Blue)", --0.4

    -- needs
    need_sleep = "Sleep",
    need_warmth = "Warmth",
    need_food = "Hunger",
    need_rest = "Rest",
    --need_starvation = "Starving", --deprecated 0.3.0
    need_exhaustion = "Exhausted",
    need_music = "Music",

    --flora
    flora_willow = "Willow Tree",
    flora_willow_plural = "Willow Trees",
    flora_willow_summary = "Found near rivers, willow trees provide a strong but twisted wood.",
    flora_willow_sapling = "Willow Sapling",
    flora_willow_sapling_plural = "Willow Saplings",
    flora_beetrootPlant = "Beetroot",
    flora_beetrootPlant_plural = "Beetroots",
    flora_beetrootPlant_summary = "A delicious hardy root vegetable.",
    flora_beetrootPlantSapling = "Beetroot Seedling",
    flora_beetrootPlantSapling_plural = "Beetroot Seedlings",
    flora_wheatPlant = "Wheat",
    flora_wheatPlant_plural = "Wheat",
    flora_wheatPlant_summary = "Wheat can be threshed and then ground into flour to make bread.",
    flora_wheatPlantSapling = "Wheat Seedling",
    flora_wheatPlantSapling_plural = "Wheat Seedlings",
    flora_flaxPlant = "Flax",
    flora_flaxPlant_plural = "Flax",
    flora_flaxPlant_summary = "A versatile plant, flax fibers can be spun into twine, and the seeds can be eaten for a small quantity of calories.",
    flora_flaxPlantSapling = "Flax Seedling",
    flora_flaxPlantSapling_plural = "Flax Seedlings",
    flora_poppyPlant = "Poppy", --0.3.0
    flora_poppyPlant_plural = "Poppies", --0.3.0
    flora_poppyPlant_summary = "Not only nice to look at, the flower of the poppy has medicinal uses.", --0.3.0
    flora_poppyPlantSapling = "Poppy Seedling", --0.3.0
    flora_poppyPlantSapling_plural = "Poppy Seedlings", --0.3.0
    flora_echinaceaPlant = "Echinacea", --0.3.0
    flora_echinaceaPlant_plural = "Echinaceas", --0.3.0
    flora_echinaceaPlant_summary = "Echinacea flowers have medicinal uses.", --0.3.0
    flora_echinaceaPlantSapling = "Echinacea Seedling", --0.3.0
    flora_echinaceaPlantSapling_plural = "Echinacea Seedlings", --0.3.0
    flora_gingerPlant = "Ginger", --0.3.0
    flora_gingerPlant_plural = "Ginger", --0.3.0
    flora_gingerPlant_summary = "Ginger roots help to soothe upset stomachs.", --0.3.0
    flora_gingerPlantSapling = "Ginger Seedling", --0.3.0
    flora_gingerPlantSapling_plural = "Ginger Seedlings", --0.3.0
    flora_turmericPlant = "Turmeric", --0.3.0
    flora_turmericPlant_plural = "Turmeric", --0.3.0
    flora_turmericPlant_summary = "Turmeric can help with inflammation.", --0.3.0
    flora_turmericPlantSapling = "Turmeric Seedling", --0.3.0
    flora_turmericPlantSapling_plural = "Turmeric Seedlings", --0.3.0
    flora_marigoldPlant = "Marigold", --0.3.0
    flora_marigoldPlant_plural = "Marigolds", --0.3.0
    flora_marigoldPlant_summary = "Marigolds can be used to make a poultice for treating wounds.", --0.3.0
    flora_marigoldPlantSapling = "Marigold Seedling", --0.3.0
    flora_marigoldPlantSapling_plural = "Marigold Seedlings", --0.3.0
    flora_garlicPlant = "Garlic", --0.3.0
    flora_garlicPlant_plural = "Garlic", --0.3.0
    flora_garlicPlant_summary = "Garlic can be eaten, or used in medicine.", --0.3.0
    flora_garlicPlantSapling = "Garlic Seedling", --0.3.0
    flora_garlicPlantSapling_plural = "Garlic Seedlings", --0.3.0
    flora_aloePlant = "Aloe", --0.3.0
    flora_aloePlant_plural = "Aloes", --0.3.0
    flora_aloePlant_summary = "Aloe leaves help to soothe burns.", --0.3.0
    flora_aloePlantSapling = "Aloe Seedling", --0.3.0
    flora_aloePlantSapling_plural = "Aloe Seedlings", --0.3.0
    flora_aspen = "Aspen Tree",
    flora_aspen_plural = "Aspen Trees",
    flora_aspen_summary = "A tall deciduous tree native to cold regions. Supplies a light wood with white bark.",
    flora_aspen_sapling = "Aspen Sapling",
    flora_aspen_sapling_plural = "Aspen Saplings",
    flora_bamboo = "Bamboo",
    flora_bamboo_plural = "Bamboo",
    flora_bamboo_summary = "Bamboo grows quickly, and can be used instead of tree branches for building or firewood.",
    flora_bamboo_sapling = "Bamboo Sapling",
    flora_bamboo_sapling_plural = "Bamboo Saplings",
    flora_palm = "Palm Tree",
    flora_palm_plural = "Palm Trees",
    flora_palm_summary = "Palm Tree",
    flora_palm_sapling = "Palm Sapling",
    flora_palm_sapling_plural = "Palm Saplings",
    flora_birch = "Birch Tree",
    flora_birch_plural = "Birch Trees",
    flora_birch_summary = "A quite compact deciduous tree that supplies a light wood with white bark.",
    flora_birch_sapling = "Birch Sapling",
    flora_birch_sapling_plural = "Birch Saplings",
    flora_pine = "Pine Tree",
    flora_pine_plural = "Pine Trees",
    flora_pine_summary = "Pine trees can be found throughout the world, and supply plenty of wood, as well as pine cones which can be burned.",
    flora_pine_sapling = "Pine Sapling",
    flora_pine_sapling_plural = "Pine Saplings",
    flora_pineBig = "Tall Pine Tree",
    flora_pineBig_plural = "Tall Pine Trees",
    flora_pineBig_summary = "Tall pines are rare, take a long time to grow, and only produce seeds every ten years, but provide a large quantity of wood when chopped.",
    flora_pineBig_sapling = "Tall Pine Sapling",
    flora_pineBig_sapling_plural = "Tall Pine Saplings",
    flora_aspenBig = "Tall Aspen Tree",
    flora_aspenBig_plural = "Tall Aspen Trees",
    flora_aspenBig_summary = "Tall aspens are rare, take a long time to grow, and only produce seeds every ten years, but provide a large quantity of wood when chopped.",
    flora_aspenBig_sapling = "Tall Aspen Sapling",
    flora_aspenBig_sapling_plural = "Tall Aspen Saplings",
    flora_appleTree = "Apple Tree",
    flora_appleTree_plural = "Apple Trees",
    flora_appleTree_summary = "A compact deciduous tree, that provides fruit from late summer to autumn.",
    flora_appleTree_sapling = "Apple Sapling",
    flora_appleTree_sapling_plural = "Apple Saplings",
    flora_elderberryTree = "Elderberry Tree", --0.3.0
    flora_elderberryTree_plural = "Elderberry Trees", --0.3.0
    flora_elderberryTree_summary = "A small bushy tree with berries that have medicinal uses.", --0.3.0
    flora_elderberryTree_sapling = "Elderberry Sapling", --0.3.0
    flora_elderberryTree_sapling_plural = "Elderberry Saplings", --0.3.0
    flora_gooseberryBush = "Gooseberry Bush",
    flora_gooseberryBush_plural = "Gooseberry Bushes",
    flora_gooseberryBush_summary = "Provides a juicy fruit, rich in vitamin C. Harvested in summer.",
    flora_pumpkinPlant = "Pumpkin Plant",
    flora_pumpkinPlant_plural = "Pumpkin Plants",
    flora_pumpkinPlant_summary = "Pumpkins store a long time, are good eating, and can be useful for other things too.",
    flora_peachTree = "Peach Tree",
    flora_peachTree_plural = "Peach Trees",
    flora_peachTree_summary = "Provides a juicy stone fruit, ready to eat in summer.",
    flora_peachTree_sapling = "Peach Sapling",
    flora_peachTree_sapling_plural = "Peach Saplings",
    flora_bananaTree = "Banana Tree",
    flora_bananaTree_plural = "Banana Trees",
    flora_bananaTree_summary = "Banana trees aren't actually trees at all, but herbs, and the fruit are technically berries. Long yellow berries.",
    flora_bananaTree_sapling = "Banana Sapling",
    flora_bananaTree_sapling_plural = "Banana Saplings",
    flora_coconutTree = "Coconut Tree",
    flora_coconutTree_plural = "Coconut Trees",
    flora_coconutTree_summary = "Coconut trees offer a large and nutritious fruit, and a unique wood. Falling coconuts kill 150 people every year.",
    flora_coconutTree_sapling = "Coconut Sapling",
    flora_coconutTree_sapling_plural = "Coconut Saplings",
    flora_raspberryBush = "Raspberry Bush",
    flora_raspberryBush_plural = "Raspberry Bushes",
    flora_raspberryBush_summary = "Raspberries are rich in vitamin C and bursting with flavor. Harvested in autumn.",
    flora_shrub = "Bush",
    flora_shrub_plural = "Bushes",
    flora_shrub_summary = "Bush",
    flora_orangeTree = "Orange Tree",
    flora_orangeTree_plural = "Orange Trees",
    flora_orangeTree_summary = "Orange trees are hardy and provide an often much needed harvest in late winter.",
    flora_orangeTree_sapling = "Orange Sapling",
    flora_orangeTree_sapling_plural = "Orange Saplings",
    flora_cactus = "Cactus",
    flora_cactus_plural = "Cacti",
    flora_cactus_summary = "Cactus",
    flora_cactus_sapling = "Cactus Sapling",
    flora_cactus_sapling_plural = "Cactus Saplings",
    flora_sunflower = "Sunflower",
    flora_sunflower_plural = "Sunflowers",
    flora_sunflower_summary = "Sunflowers brighten up the landscape, and the seeds provide a small amount of calories.",
    flora_sunflowerSapling = "Sunflower Sapling",
    flora_sunflowerSapling_plural = "Sunflower Saplings",
    flora_flower1 = "Flower",
    flora_flower1_plural = "Flowers",
    flora_flower1_summary = "Flower",
    
    -- branches
    branch_birch = "Birch Branch",
    branch_birch_plural = "Birch Branches",
    branch_pine = "Pine Branch",
    branch_pine_plural = "Pine Branches",
    branch_aspen = "Aspen Branch",
    branch_aspen_plural = "Aspen Branches",
    branch_bamboo = "Bamboo",
    branch_bamboo_plural = "Bamboo",
    branch_willow = "Willow Branch",
    branch_willow_plural = "Willow Branches",
    branch_apple = "Apple Branch",
    branch_apple_plural = "Apple Branches",
    branch_elderberry = "Elderberry Branch", --0.3.0
    branch_elderberry_plural = "Elderberry Branches", --0.3.0
    branch_orange = "Orange Branch",
    branch_orange_plural = "Orange Branches",
    branch_peach = "Peach Branch",
    branch_peach_plural = "Peach Branches",

    -- logs
    log_birch = "Birch Log",
    log_birch_plural = "Birch Logs",
    log_willow = "Willow Log",
    log_willow_plural = "Willow Logs",
    log_apple = "Apple Log",
    log_apple_plural = "Apple Logs",
    log_elderberry = "Elderberry Log", --0.3.0
    log_elderberry_plural = "Elderberry Logs", --0.3.0
    log_orange = "Orange Log",
    log_orange_plural = "Orange Logs",
    log_peach = "Peach Log",
    log_peach_plural = "Peach Logs",
    log_pine = "Pine Log",
    log_pine_plural = "Pine Logs",
    log_aspen = "Aspen Log",
    log_aspen_plural = "Aspen Logs",
    log_coconut = "Coconut Log",
    log_coconut_plural = "Coconut Logs",

    --fruits/seeds
    fruit_orange = "Orange",
    fruit_orange_plural = "Oranges",
    fruit_orange_rotten = "Rotten Orange",
    fruit_orange_rotten_plural = "Rotten Oranges",
    fruit_apple = "Apple",
    fruit_apple_plural = "Apples",
    fruit_apple_rotten = "Rotten Apple",
    fruit_apple_rotten_plural = "Rotten Apples",
    fruit_elderberry = "Elderberry", --0.3.0
    fruit_elderberry_plural = "Elderberries", --0.3.0
    fruit_elderberry_rotten = "Rotten Elderberry", --0.3.0
    fruit_elderberry_rotten_plural = "Rotten Elderberries", --0.3.0
    fruit_banana = "Banana",
    fruit_banana_plural = "Bananas",
    fruit_banana_rotten = "Rotten Banana",
    fruit_banana_rotten_plural = "Rotten Bananas",
    fruit_coconut = "Coconut",
    fruit_coconut_plural = "Coconuts",
    fruit_coconut_rotten = "Rotten Coconut",
    fruit_coconut_rotten_plural = "Rotten Coconuts",
    fruit_pineCone = "Pine Cone",
    fruit_pineCone_plural = "Pine Cones",
    fruit_pineCone_rotten = "Rotten Pine Cone",
    fruit_pineCone_rotten_plural = "Rotten Pine Cones",
    fruit_pineConeBig = "Large Pine Cone",
    fruit_pineConeBig_plural = "Large Pine Cones",
    fruit_pineConeBig_rotten = "Rotten Large Pine Cone",
    fruit_pineConeBig_rotten_plural = "Rotten Large Pine Cones",
    fruit_aspenBigSeed = "Tall Aspen Seed",
    fruit_aspenBigSeed_plural = "Tall Aspen Seeds",
    fruit_aspenBigSeed_rotten = "Rotten Tall Aspen Seed",
    fruit_aspenBigSeed_rotten_plural = "Rotten Tall Aspen Seeds",
    fruit_beetroot = "Beetroot",
    fruit_beetroot_plural = "Beetroots",
    fruit_beetroot_rotten = "Rotten Beetroot",
    fruit_beetroot_rotten_plural = "Rotten Beetroots",
    fruit_beetrootSeed = "Beetroot Seed",
    fruit_beetrootSeed_plural = "Beetroot Seeds",
    fruit_beetrootSeed_rotten = "Rotten Beetroot Seed",
    fruit_beetrootSeed_rotten_plural = "Rotten Beetroot Seeds",
    fruit_wheat = "Wheat",
    fruit_wheat_plural = "Wheat",
    fruit_wheat_rotten = "Rotten Wheat",
    fruit_wheat_rotten_plural = "Rotten Wheat",
    fruit_flax = "Wet Flax",
    fruit_flax_plural = "Wet Flax",
    fruit_flax_rotten = "Rotten Flax",
    fruit_flax_rotten_plural = "Rotten Flax",
    fruit_flaxSeed = "Flax Seed",
    fruit_flaxSeed_plural = "Flax Seeds",
    fruit_flaxSeed_rotten = "Rotten Flax Seed",
    fruit_flaxSeed_rotten_plural = "Rotten Flax Seeds",
    fruit_poppyFlower = "Poppy Flower", --0.3.0
    fruit_poppyFlower_plural = "Poppy Flowers", --0.3.0
    fruit_poppyFlower_rotten = "Rotten Poppy Flower", --0.3.0
    fruit_poppyFlower_rotten_plural = "Rotten Poppy Flowers", --0.3.0
    fruit_echinaceaFlower = "Echinacea Flower", --0.3.0
    fruit_echinaceaFlower_plural = "Echinacea Flowers", --0.3.0
    fruit_echinaceaFlower_rotten = "Rotten Echinacea Flower", --0.3.0
    fruit_echinaceaFlower_rotten_plural = "Rotten Echinacea Flowers", --0.3.0
    fruit_marigoldFlower = "Marigold Flower", --0.3.0
    fruit_marigoldFlower_plural = "Marigold Flowers", --0.3.0
    fruit_marigoldFlower_rotten = "Rotten Marigold Flower", --0.3.0
    fruit_marigoldFlower_rotten_plural = "Rotten Marigold Flowers", --0.3.0
    fruit_gingerRoot = "Ginger Root", --0.3.0
    fruit_gingerRoot_plural = "Ginger Roots", --0.3.0
    fruit_gingerRoot_rotten = "Rotten Ginger Root", --0.3.0
    fruit_gingerRoot_rotten_plural = "Rotten Ginger Roots", --0.3.0
    fruit_turmericRoot = "Turmeric Root", --0.3.0
    fruit_turmericRoot_plural = "Turmeric Roots", --0.3.0
    fruit_turmericRoot_rotten = "Rotten Turmeric Root", --0.3.0
    fruit_turmericRoot_rotten_plural = "Rotten Turmeric Roots", --0.3.0
    fruit_garlic = "Garlic", --0.3.0
    fruit_garlic_plural = "Garlic", --0.3.0
    fruit_garlic_rotten = "Rotten Garlic", --0.3.0
    fruit_garlic_rotten_plural = "Rotten Garlic", --0.3.0
    fruit_aloeLeaf = "Aloe Leaf", --0.3.0
    fruit_aloeLeaf_plural = "Aloe Leaves", --0.3.0
    fruit_aloeLeaf_rotten = "Rotten Aloe Leaf", --0.3.0
    fruit_aloeLeaf_rotten_plural = "Rotten Aloe Leaves", --0.3.0
    fruit_sunflowerSeed = "Sunflower Seed",
    fruit_sunflowerSeed_plural = "Sunflower Seeds",
    fruit_sunflowerSeed_rotten = "Rotten Sunflower Seed",
    fruit_sunflowerSeed_rotten_plural = "Rotten Sunflower Seeds",
    fruit_peach = "Peach",
    fruit_peach_plural = "Peaches",
    fruit_peach_rotten = "Rotten Peach",
    fruit_peach_rotten_plural = "Rotten Peaches",
    fruit_raspberry = "Raspberry",
    fruit_raspberry_plural = "Raspberries",
    fruit_raspberry_rotten = "Rotten Raspberry",
    fruit_raspberry_rotten_plural = "Rotten Raspberries",
    fruit_gooseberry = "Gooseberry",
    fruit_gooseberry_plural = "Gooseberries",
    fruit_gooseberry_rotten = "Rotten Gooseberry",
    fruit_gooseberry_rotten_plural = "Rotten Gooseberries",
    fruit_pumpkin = "Pumpkin",
    fruit_pumpkin_plural = "Pumpkins",
    fruit_pumpkin_rotten = "Rotten Pumpkin",
    fruit_pumpkin_rotten_plural = "Rotten Pumpkins",
    fruit_birchSeed = "Birch Seed",
    fruit_birchSeed_plural = "Birch Seeds",
    fruit_birchSeed_rotten = "Rotten Birch Seed",
    fruit_birchSeed_rotten_plural = "Rotten Birch Seeds",
    fruit_aspenSeed = "Aspen Seed",
    fruit_aspenSeed_plural = "Aspen Seeds",
    fruit_aspenSeed_rotten = "Rotten Aspen Seed",
    fruit_aspenSeed_rotten_plural = "Rotten Aspen Seeds",
    fruit_willowSeed = "Willow Seed",
    fruit_willowSeed_plural = "Willow Seeds",
    fruit_willowSeed_rotten = "Rotten Willow Seed",
    fruit_willowSeed_rotten_plural = "Rotten Willow Seeds",
    fruit_bambooSeed = "Bamboo Seed",
    fruit_bambooSeed_plural = "Bamboo Seeds",
    fruit_bambooSeed_rotten = "Rotten Bamboo Seed",
    fruit_bambooSeed_rotten_plural = "Rotten Bamboo Seeds",

    -- tool groups
    toolGroup_weapon = "Weapon",
    toolGroup_weapon_plural = "Weapons",
    
    -- tools
    tool_treeChop = "Chopping Tool",
    tool_treeChop_plural = "Chopping Tools",
    tool_treeChop_usage = "Chopping",
    tool_dig = "Digging Tool",
    tool_dig_plural = "Digging Tools",
    tool_dig_usage = "Digging",
    tool_mine = "Mining Tool",
    tool_mine_plural = "Mining Tools",
    tool_mine_usage = "Mining",
    tool_weaponBasic = "Basic Weapon",
    tool_weaponBasic_plural = "Basic Weapons",
    tool_weaponBasic_usage = "Weapon (Basic)",
    tool_weaponSpear = "Spear",
    tool_weaponSpear_plural = "Spears",
    tool_weaponSpear_usage = "Weapon (Spear)",
    tool_weaponKnife = "Knife",
    tool_weaponKnife_plural = "Knives",
    tool_weaponKnife_usage = "Weapon (Knife)",
    tool_butcher = "Butchering Tool",
    tool_butcher_plural = "Butchering Tools",
    tool_butcher_usage = "Butchering",
    tool_knapping = "Knapping Tool",
    tool_knapping_plural = "Knapping Tools",
    tool_knapping_usage = "Knapping",
    tool_carving = "Carving Tool",
    tool_carving_plural = "Carving Tools",
    tool_carving_usage = "Carving",
    tool_grinding = "Grinding Tool",
    tool_grinding_plural = "Grinding Tools",
    tool_grinding_usage = "Grinding",

    tool_knappingCrude = "Crude Knapping Tool", --b20
    tool_knappingCrude_plural = "Crude Knapping Tools", --b20
    tool_knappingCrude_usage = "Crude Knapping", --b20


    tool_crucible = "Crucible", --0.4
    tool_crucible_plural = "Crucibles", --0.4
    tool_crucible_usage = "Crucible", --0.4
    tool_hammering = "Hammer", --0.4
    tool_hammering_plural = "Hammers", --0.4
    tool_hammering_usage = "Hammering", --0.4
    tool_softChiselling = "Chisel (Soft Rock)", --0.4
    tool_softChiselling_plural = "Chisels (Soft Rock)", --0.4
    tool_softChiselling_usage = "Chiselling (Soft Rock)", --0.4
    tool_hardChiselling = "Chisel (Hard Rock)", --0.4
    tool_hardChiselling_plural = "Chisels (Hard Rock)", --0.4
    tool_hardChiselling_usage = "Chiselling (Hard Rock)", --0.4
    

    --tool properties
    toolProperties_damage = "Damage",
    toolProperties_speed = "Speed",
    toolProperties_durability = "Durability",

    -- tool usages
    tool_usage_new = "New",
    tool_usage_used = "Used",
    tool_usage_wellUsed = "Well Used",
    tool_usage_nearlyBroken = "Nearly Broken",

    -- plans
    plan_build = "Build",
    plan_build_inProgress = "Building",
    plan_plant = "Plant",
    plan_plant_inProgress = "Planting",
    plan_dig = "Dig",
    plan_dig_inProgress = "Digging",
    plan_mine = "Mine",
    plan_mine_inProgress = "Mining",
    plan_clear = "Clear",
    plan_clear_inProgress = "Clearing",
    plan_fill = "Fill",
    plan_fill_inProgress = "Filling",
    plan_chop = "Chop",
    plan_chop_inProgress = "Chopping",
    plan_chopReplant = "Chop & Replant", --0.5.1
    plan_chopReplant_inProgress = "Chopping & Replanting", --0.5.1
    plan_storeObject = "Store",
    plan_storeObject_inProgress = "Storing",
    plan_transferObject = "Transfer",
    plan_transferObject_inProgress = "Transferring",
    plan_destroyContents = "Destroy Contents",
    plan_destroyContents_inProgress = "Destroying Contents",
    plan_pullOut = "Pull Out",
    plan_pullOut_inProgress = "Pulling Out",
    plan_removeObject = "Remove",
    plan_removeObject_inProgress = "Removing",
    plan_gather = "Gather",
    plan_gather_inProgress = "Gathering",
    plan_moveTo = "Move", --used when telling a sapien to move
    plan_moveTo_inProgress = "Moving",
    plan_wait = "Wait Here",
    plan_wait_inProgress = "Waiting",
    plan_moveAndWait = "Move and Wait",
    plan_moveAndWait_inProgress = "Move and Wait",
    plan_light = "Light",
    plan_light_inProgress = "Lighting",
    plan_extinguish = "Extinguish",
    plan_extinguish_inProgress = "Extinguishing",
    plan_hunt = "Hunt With Rocks", --0.7 this use to apply to all hunting, now only applies to hunting with rocks, or basic hunting
    plan_hunt_inProgress = "Hunting With Rocks", --0.7
    plan_hunt_throwSpear = "Hunt With Spears", --0.7
    plan_hunt_throwSpear_inProgress = "Hunting With Spears", --0.7
    plan_craft = "Craft",
    plan_craft_inProgress = "Crafting",
    plan_recruit = "Recruit",
    plan_recruit_inProgress = "Recruiting",
    plan_banish = "Banish", --0.7
    plan_banish_inProgress = "Banishing", --0.7
    plan_attack = "Attack", --0.7
    plan_attack_inProgress = "Attacking", --0.7
    plan_attack_handToHand = "Attack With Fists", --0.7
    plan_attack_handToHand_inProgress = "Attacking With Fists", --0.7
    plan_attack_throwSpear = "Attack With Spears", --0.7
    plan_attack_throwSpear_inProgress = "Attacking With Spears", --0.7
    plan_attack_throwRock = "Attack With Rocks", --0.7
    plan_attack_throwRock_inProgress = "Attacking With Rocks", --0.7
    plan_defend = "Defend", --0.7
    plan_defend_inProgress = "Defending", --0.7
    plan_defend_handToHand = "Defend With Fists", --0.7
    plan_defend_handToHand_inProgress = "Defending With Fists", --0.7
    plan_defend_throwSpear = "Defend With Spears", --0.7
    plan_defend_throwSpear_inProgress = "Defending With Spears", --0.7
    plan_defend_throwRock = "Defend With Rocks", --0.7
    plan_defend_throwRock_inProgress = "Defending With Rocks", --0.7
    plan_deconstruct = "Remove",
    plan_deconstruct_inProgress = "Removing",
    plan_manageStorage = "Manage Storage",
    plan_manageStorage_inProgress = "Managing Storage",
    plan_manageSapien = "Manage Sapien",
    plan_manageSapien_inProgress = "Managing Sapien",
    plan_addFuel = "Add Fuel",
    plan_addFuel_inProgress = "Adding Fuel",
    plan_buildPath = "Build", --0.5 removed "Path"
    plan_buildPath_inProgress = "Building", --0.5 removed "Path", as the noun/path type may be appended later. Previously it would say "Building path a stone path"
    plan_research = researchName,
    plan_research_inProgress = researchingName,
    plan_constructWith = "Use",
    plan_constructWith_inProgress = "Using",
    plan_allowUse = "Allow Use",
    plan_allowUse_inProgress = "Allow Use",
    plan_stop = "Stop",
    plan_stop_inProgress = "Stopping",
    plan_butcher = "Butcher",
    plan_butcher_inProgress = "Butchering",
    plan_clone = "Build",
    plan_clone_inProgress = "Building",
    plan_playInstrument = "Play",
    plan_playInstrument_inProgress = "Playing",
    plan_rebuild = "Rebuild", --0.4
    plan_rebuild_inProgress = "Rebuilding", --0.4
    plan_rebuild_title = function(values)
        return values.rebuildText .. " " .. values.objectName
    end,

    plan_treatInjury = "Treat Injury", --0.3.0 
    plan_treatInjury_inProgress = "Treating Injury", --0.3.0 
    plan_treatBurn = "Treat Burn", --0.3.0 
    plan_treatBurn_inProgress = "Treating Burn", --0.3.0 
    plan_treatFoodPoisoning = "Treat Food Poisoning", --0.3.0 
    plan_treatFoodPoisoning_inProgress = "Treating Food Poisoning", --0.3.0 
    plan_treatVirus = "Treat Virus", --0.3.0 
    plan_treatVirus_inProgress = "Treating Virus", --0.3.0 

    plan_fertilize = "Mulch", --0.4
    plan_fertilize_inProgress = "Mulching", --0.4
    plan_deliverToCompost = "Compost", --0.4
    plan_deliverToCompost_inProgress = "Composting", --0.4
    plan_chiselStone = "Chisel", --0.4
    plan_chiselStone_inProgress = "Chiselling", --0.4
    
    plan_haulObject = "Move", --0.5 used when moving a large object, eg dragging a sled
    plan_haulObject_inProgress = "Moving", --0.5 
    plan_greet = "Greet", --0.5 used when meeting a sapien from another tribe
    plan_greet_inProgress = "Greeting", --0.5
    plan_manageTribeRelations = "Relations", --0.5
    plan_manageTribeRelations_inProgress = "Relations", --0.5
    

    plan_manageTribeRelationsWithTribeName = function(values) --0.5 displayed when inspecting sapien from another tribe that has been met already, or inspectring an object that has an associated quest/trade request
        return "Manage relationship with the " .. values.tribeName .. " tribe"
    end,

    plan_gatherAll = "Gather All", --0.5
    plan_gatherAllInProgress = "Gathering All", --0.5

    --research    
    research_fire_description = "Your tribe has discovered that heat is generated from the friction when you rub two sticks together. If it gets hot enough, an ember can be produced to start a fire, providing warmth and light, and keeping animals away.", --0.5 added "and keeping animals away"
    research_fire_clueText = "Rub together", --0.5.1

    research_thatchBuilding_description = "Your tribe has discovered that when dried vegetation is lined up and placed over a supporting structure, it can provide water tight shelter.",
    research_thatchBuilding_clueText = "Construct", --0.5.1

    research_mudBrickBuilding_description = "Your tribe has discovered that stacked blocks or bricks can make sturdy structures.", --0.4 changed, now applies to all brick/block based building
    research_mudBrickBuilding_clueText = "Construct", --0.5.1

    research_brickBuilding_description = "Now that your tribe has figured out how to bind fired bricks together, they have a new decorative alternative to mud bricks for building walls.", --deprecated (0.4)
    research_brickBuilding_clueText = "Construct", --0.5.1

    research_woodBuilding_description = "By splitting logs with simple tools, your tribe has found a new building material. Structures built with wood are stronger and more resistant to the weather.",
    research_woodBuilding_clueText = "Construct", --0.5.1

    research_rockKnapping_description = "By using one rock to hit another, your tribe has discovered that the edges can be sharpened, and some very useful tools can be made.",
    research_rockKnapping_clueText = "Craft", --0.5.1

    research_flintKnapping_description = "After finding a new type of rock, your tribe tried knapping it to create a new sharper edge. This new material is also more durable.",
    research_flintKnapping_clueText = "Construct", --0.5.1

    research_pottery_description = "Your tribe has discovered that some types of earth can be pressed into forms when soft and wet, and they will then keep their shape when they dry out and harden. This will be useful for storing certain resources.",
    research_pottery_clueText = "Craft", --0.5.1

    research_potteryFiring_description = "Your tribe noticed that clay hardened when heated by fire. With the help of a purpose-built mud brick enclosure, an even hotter fire, they can now make pottery that is more water resistant, and preserve their contents better.",
    research_potteryFiring_clueText = "Heat", --0.5.1

    research_spinning_description = "Your tribe can now create twines and ropes by spinning plant fibers together. This will be particularly useful to bind things together and make complex tools.",
    research_spinning_clueText = "Craft", --0.5.1

    research_digging_description = "With the new knowledge of rock knapping, hand axes could be used to more easily remove the top soil, transport it elsewhere and reveal what is beneath.",
    research_digging_clueText = "Strike with tool", --0.5.1

    research_mining_description = "By adding a handle to a simple stone tool, enough force can be generated to splinter harder surfaces, and your tribe has discovered it is now possible to mine rocks.",
    research_mining_clueText = "Strike with tool", --0.5.1

    research_chiselStone_description = "Your tribe has discovered that a chisel can be used to carve blocks directly out of stone. Stone blocks can be used to build strong structures, or can be chiselled again to create tiles.", --0.4
    research_chiselStone_clueText = "Carve with tool", --0.7 changed from strike to carve, to better differentiate between researching mining and researching chiseling

    research_planting_description = "By observing seeds and plants, your tribe has discovered how to control where things grow. This will make it easier to control food supply, and provide new decorative options.",
    research_planting_clueText = "Bury seed", --0.5.1

    research_mulching_description = "Your tribe has discovered that soil can be improved by adding a layer of rotted organic material. With richer soil, plants and trees grow faster and provide bountiful harvests.", --0.4
    research_mulching_clueText = "Improve soil", --0.5.1

    research_threshing_description = "The seeds of certain grasses have nutritional value, and your tribe has discovered how to extract them more easily.",
    research_threshing_clueText = "Separate seeds", --0.5.1

    research_treeFelling_description = "With enough strikes with a hand axe, even the mightiest trees can be taken down. This will provide wooden logs, which will burn in fires for much longer, but perhaps there are other uses too.",
    research_treeFelling_clueText = "Strike with tool", --0.5.1

    research_basicHunting_description = "Your tribe has found a way to hunt and kill small prey, which can provide valuable resources and potentially food, once prepared and cooked.",
    research_basicHunting_clueText = "Attack", --0.5.1

    research_spearHunting_description = "After experimenting with various projectiles, your tribe has found that by combining the sharpness of a knapped blade with the flight stability of a straight stick, they can now hunt and fight more successfully.", --0.7 modified, now used for spear combat too
    research_spearHunting_clueText = "Attack with weapon",  --0.7 modified

    research_butchery_description = "Your tribe now has the ability to separate out the valuable resources contained within an animal carcass. They can now obtain raw meat, though you may want to tell them not to eat it just yet.",
    research_butchery_clueText = "Cut", --0.5.1

    research_woodWorking_description = "Your tribe has discovered that by scraping layers away from branches and logs, many useful tools and building materials can be made.",
    research_woodWorking_clueText = "Carve with tool", --0.5.1

    research_boneCarving_description = "Your tribe has found that bones can be shaped using a knife to create sharp blades or even make a musical sound.",
    research_boneCarving_clueText = "Craft", --0.5.1

    research_flutePlaying_description = "Your tribe has discovered how to make music. Music helps to unite your tribe, increasing loyalty and happiness for those nearby.",
    research_flutePlaying_clueText = "Play", --0.5.1

    research_campfireCooking_description = "After a moment of inspiration, your tribe has found that by heating raw ingredients in fire, they can become tastier and easier to eat.",
    research_campfireCooking_clueText = "Heat", --0.5.1

    research_baking_description = "Finally after much experimentation, your tribe can now create a delicious and fulfilling meal using the plentiful grains found growing around them.",
    research_baking_clueText = "Craft & Heat", --0.5.1

    research_toolAssembly_description = "A sharpened rock can be used with more force when attached to a wooden handle. Your tribe can now craft better tools and more formidable weapons.",
    research_toolAssembly_clueText = "Craft", --0.5.1

    research_medicine_description = "By grinding together herbs, roots, and flowers, your tribe has found that poultices and medicines can be made. These mixtures can help with injuries and illness.", --0.3.0
    research_medicine_clueText = "Craft", --0.5.1
    
    research_grinding_description = "Pulverizing things can be very useful, in particular to unlock the valuable calories hidden within seeds and grains. Your tribe has found that a quern-stone makes grinding tasks much easier.", --modified b13
    research_grinding_clueText = "Crush", --0.5.1

    research_tiling_description = "Your tribe has discovered a new construction method using thinly sliced blocks of stone or pottery. Tiles can be used to build high quality roofing, floors, and paths.", --0.4 modified
    research_tiling_clueText = "Construct", --0.5.1

    research_composting_name = "Composting", --0.4 --the name is usually derived from the skill, so research types that don't have an associated skill must be given a name.
    research_composting_description = "Rotting organic matter can be piled up and left to turn into compost, which can then be used to enrich the soil.", --0.4
    research_composting_clueText = "Improve soil", --0.5.1

    research_blacksmithing_description = "By heating and combining certain types of rock at high temperatures, your tribe has discovered how to produce and use bronze. Bronze tools last a lot longer, and can be used to make entirely new categories of tools.", --0.4
    research_blacksmithing_clueText = "Craft", --0.5.1



    research_unlock_butcherMammoth = "Butcher Mammoth",

    -- paths
    path_dirt = "Soil Path",
    path_dirt_plural = "Soil Paths",
    path_sand = "Sand Path",
    path_sand_plural = "Sand Paths",
    path_rock = "Rock Path",
    path_rock_plural = "Rock Paths",
    path_clay = "Clay Path",
    path_clay_plural = "Clay Paths",
    path_tile = "Tile Path",
    path_tile_plural = "Tile Paths",

    -- other objects
    object_campfire = "Campfire",
    object_campfire_plural = "Campfires",
    object_brickKiln = "Kiln",
    object_brickKiln_plural = "Kilns",
    object_torch = "Torch",
    object_torch_plural = "Torches",
    object_alpacaMeatRack = "Raw Alpaca Meat", --0.3.0 added "Raw"
    object_alpacaMeatRack_plural = "Raw Alpaca Meat", --0.3.0 added "Raw"
    object_alpacaMeatRackCooked = "Cooked Alpaca Meat",
    object_alpacaMeatRackCooked_plural = "Cooked Alpaca Meat",
    object_catfishDead = "Raw Catfish", --0.6
    object_catfishDead_plural = "Raw Catfish", --0.6
    object_catfishCooked = "Cooked Catfish", --0.6
    object_catfishCooked_plural = "Cooked Catfish", --0.6
    object_coelacanthDead = "Raw Coelacanth", --0.6
    object_coelacanthDead_plural = "Raw Coelacanth", --0.6
    object_coelacanthCooked = "Cooked Coelacanth", --0.6
    object_coelacanthCooked_plural = "Cooked Coelacanth", --0.6
    object_flagellipinnaDead = "Raw Flagellipinna", --0.6
    object_flagellipinnaDead_plural = "Raw Flagellipinna", --0.6
    object_flagellipinnaCooked = "Cooked Flagellipinna", --0.6
    object_flagellipinnaCooked_plural = "Cooked Flagellipinna", --0.6
    object_polypterusDead = "Raw Polypterus", --0.6
    object_polypterusDead_plural = "Raw Polypterus", --0.6
    object_polypterusCooked = "Cooked Polypterus", --0.6
    object_polypterusCooked_plural = "Cooked Polypterus", --0.6
    object_redfishDead = "Raw Redfish", --0.6
    object_redfishDead_plural = "Raw Redfish", --0.6
    object_redfishCooked = "Cooked Redfish", --0.6
    object_redfishCooked_plural = "Cooked Redfish", --0.6
    object_tropicalfishDead = "Raw Jackfish", --0.6
    object_tropicalfishDead_plural = "Raw Jackfish", --0.6
    object_tropicalfishCooked = "Cooked Jackfish", --0.6
    object_tropicalfishCooked_plural = "Cooked Jackfish", --0.6
    object_swordfishDead = "Swordfish", --0.6
    object_swordfishDead_plural = "Swordfish", --0.6
    object_fishFillet = "Raw Fish Fillet", --0.6
    object_fishFillet_plural = "Raw Fish Fillets", --0.6
    object_fishFilletCooked = "Cooked Fish Fillet", --0.6
    object_fishFilletCooked_plural = "Cooked Fish Fillets", --0.6
    object_dirtWallDoor = "Dirt Wall With Door",
    object_dirtWallDoor_plural = "Dirt Wall With Door",
    object_build_storageArea = "Storage Area",
    object_build_storageArea_plural = "Storage Areas",
    object_build_storageArea1x1 = "Small Storage Area 1x1", --0.5
    object_build_storageArea1x1_plural = "Small Storage Areas 1x1", --0.5
    object_build_storageArea4x4 = "Large Storage Area 4x4", --0.5
    object_build_storageArea4x4_plural = "Large Storage Areas 4x4", --0.5
    object_build_compostBin = "Compost Bin", --0.4
    object_build_compostBin_plural = "Compost Bins", --0.4
    object_aspenSplitLog = "Aspen Split Log",
    object_aspenSplitLog_plural = "Aspen Split Logs",
    object_dirtRoof = "Dirt Roof",
    object_dirtRoof_plural = "Dirt Roofs",
    object_plan_move = "Move",
    object_plan_move_plural = "Move",
    object_haulObjectDestinationMarker = "Haul Object", --0.5 The name of the destination marker displayed when dragging sleds or canoes
    object_haulObjectDestinationMarker_plural = "Haul Object", --0.5
    object_deadAlpaca = "Alpaca Carcass",
    object_deadAlpaca_plural = "Alpaca Carcasses",
    object_deadMammoth = "Mammoth Carcass",
    object_deadMammoth_plural = "Mammoth Carcasses",
    object_chickenMeatBreastCooked = "Cooked Chicken Meat",
    object_chickenMeatBreastCooked_plural = "Cooked Chicken Meat",
    object_build_dirtWall = "Dirt Wall",
    object_build_dirtWall_plural = "Dirt Walls",
    object_grass = "Wet Hay",
    object_grass_plural = "Wet Hay",
    object_flaxDried = "Dry Flax",
    object_flaxDried_plural = "Dry Flax",
    object_splitLogFloor1x1 = "Split Log Floor 1x1",  --0.6.1
    object_splitLogFloor1x1_plural = "Split Log Floors 1x1", --0.6.1
    object_build_splitLogFloor1x1 = "Split Log Floor 1x1", --0.6.1
    object_build_splitLogFloor1x1_plural = "Split Log Floors 1x1", --0.6.1
    object_splitLogFloor = "Split Log Floor 2x2",
    object_splitLogFloor_plural = "Split Log Floors 2x2",
    object_build_splitLogFloor = "Split Log Floor 2x2",
    object_build_splitLogFloor_plural = "Split Log Floors 2x2",
    object_splitLogFloor4x4 = "Split Log Floor 4x4",
    object_splitLogFloor4x4_plural = "Split Log Floors 4x4",
    object_build_splitLogFloor4x4 = "Split Log Floor 4x4",
    object_build_splitLogFloor4x4_plural = "Split Log Floors 4x4",
    object_splitLogFloorTri2 = "Split Log Floor Triangle", --0.4
    object_splitLogFloorTri2_plural = "Split Log Floor Triangles", --0.4
    object_build_splitLogFloorTri2 = "Split Log Floor Triangle", --0.4
    object_build_splitLogFloorTri2_plural = "Split Log Floor Triangles", --0.4
    object_mudBrickFloor1x1 = "Mudbrick Floor 1x1", --0.6.1
    object_mudBrickFloor1x1_plural = "Mudbrick Floor 1x1", --0.6.1
    object_build_mudBrickFloor1x1 = "Mudbrick Floor 1x1", --0.6.1
    object_build_mudBrickFloor1x1_plural = "Mudbrick Floor 1x1", --0.6.1
    object_mudBrickFloor2x2 = "Mudbrick Floor 2x2",
    object_mudBrickFloor2x2_plural = "Mudbrick Floor 2x2",
    object_build_mudBrickFloor2x2 = "Mudbrick Floor 2x2",
    object_build_mudBrickFloor2x2_plural = "Mudbrick Floor 2x2",
    object_mudBrickFoundation1x1 = "Mudbrick Foundation 1x1", --0.6.1
    object_mudBrickFoundation1x1_plural = "Mudbrick Foundation 1x1", --0.6.1
    object_build_mudBrickFoundation1x1 = "Mudbrick Foundation 1x1", --0.6.1
    object_build_mudBrickFoundation1x1_plural = "Mudbrick Foundation 1x1", --0.6.1
    object_mudBrickFoundation2x2 = "Mudbrick Foundation 2x2", --0.6.1
    object_mudBrickFoundation2x2_plural = "Mudbrick Foundation 2x2", --0.6.1
    object_build_mudBrickFoundation2x2 = "Mudbrick Foundation 2x2", --0.6.1
    object_build_mudBrickFoundation2x2_plural = "Mudbrick Foundation 2x2", --0.6.1
    object_dirtFoundation1x1 = "Dirt Foundation 1x1", --0.6.1
    object_dirtFoundation1x1_plural = "Dirt Foundation 1x1", --0.6.1
    object_build_dirtFoundation1x1 = "Dirt Foundation 1x1", --0.6.1
    object_build_dirtFoundation1x1_plural = "MudDirtbrick Foundation 1x1", --0.6.1
    object_dirtFoundation2x2 = "Dirt Foundation 2x2", --0.6.1
    object_dirtFoundation2x2_plural = "Dirt Foundation 2x2", --0.6.1
    object_build_dirtFoundation2x2 = "Dirt Foundation 2x2", --0.6.1
    object_build_dirtFoundation2x2_plural = "Dirt Foundation 2x2", --0.6.1
    object_mudBrickFloor4x4 = "Mudbrick Floor 4x4",
    object_mudBrickFloor4x4_plural = "Mudbrick Floor 4x4",
    object_build_mudBrickFloor4x4 = "Mudbrick Floor 4x4",
    object_build_mudBrickFloor4x4_plural = "Mudbrick Floor 4x4",
    object_mudBrickFloorTri2 = "Mudbrick Floor Triangle", --0.4
    object_mudBrickFloorTri2_plural = "Mudbrick Floor Triangles", --0.4
    object_build_mudBrickFloorTri2 = "Mudbrick Floor Triangle", --0.4
    object_build_mudBrickFloorTri2_plural = "Mudbrick Floor Triangles", --0.4
    object_tileFloor1x1 = "Tile Floor 1x1", --0.6.1
    object_tileFloor1x1_plural = "Tile Floor 1x1s", --0.6.1
    object_build_tileFloor1x1 = "Tile Floor 1x1", --0.6.1
    object_build_tileFloor1x1_plural = "Tile Floor 1x1s", --0.6.1
    object_tileFloor2x2 = "Tile Floor 2x2",
    object_tileFloor2x2_plural = "Tile Floor 2x2s",
    object_build_tileFloor2x2 = "Tile Floor 2x2",
    object_build_tileFloor2x2_plural = "Tile Floor 2x2s",
    object_tileFloor4x4 = "Tile Floor 4x4",
    object_tileFloor4x4_plural = "Tile Floor 4x4s",
    object_build_tileFloor4x4 = "Tile Floor 4x4",
    object_build_tileFloor4x4_plural = "Tile Floor 4x4s",
    object_splitLogWall = "Split Log Wall",
    object_splitLogWall_plural = "Split Log Walls",
    object_splitLogWall4x1 = "Split Log Short Wall",
    object_splitLogWall4x1_plural = "Split Log Short Walls",
    object_splitLogWall2x2 = "Split Log Square Wall",
    object_splitLogWall2x2_plural = "Split Log Square Walls",
    object_splitLogWall2x1 = "Split Log Short Wall 2x1", --0.5
    object_splitLogWall2x1_plural = "Split Log Short Walls 2x1", --0.5
    object_splitLogWallDoor = "Split Log Wall With Door",
    object_splitLogWallDoor_plural = "Split Log Walls With Doors",
    object_splitLogRoofEnd = "Split Log Roof Wall",
    object_splitLogRoofEnd_plural = "Split Log Roof Walls",
    object_splitLogSteps = "Split Log Steps 2x3 Single Floor",
    object_splitLogSteps_plural = "Split Log Steps 2x3 Single Floor",
    object_splitLogSteps2x2 = "Split Log Steps 2x2 Half Floor",
    object_splitLogSteps2x2_plural = "Split Log Steps 2x2 Half Floor",
    object_splitLogRoofSlope = "Split Log Roof Slope", --0.4
    object_splitLogRoofSlope_plural = "Split Log Roof Slopes", --0.4
    object_build_splitLogRoofSlope = "Split Log Roof Slope", --0.4
    object_build_splitLogRoofSlope_plural = "Split Log Roof Slopes", --0.4
    object_splitLogRoofSmallCorner = "Split Log Roof Corner", --0.4
    object_splitLogRoofSmallCorner_plural = "Split Log Roof Corners", --0.4
    object_build_splitLogRoofSmallCorner = "Split Log Roof Corner", --0.4
    object_build_splitLogRoofSmallCorner_plural = "Split Log Roof Corners", --0.4
    object_splitLogRoofSmallCornerInside = "Split Log Roof Inner Corner", --0.4
    object_splitLogRoofSmallCornerInside_plural = "Split Log Roof Inner Corners", --0.4
    object_build_splitLogRoofSmallCornerInside = "Split Log Roof Inner Corner", --0.4
    object_build_splitLogRoofSmallCornerInside_plural = "Split Log Roof Inner Corners", --0.4
    object_splitLogRoofTriangle = "Split Log Roof Triangle", --0.4
    object_splitLogRoofTriangle_plural = "Split Log Roof Triangles", --0.4
    object_build_splitLogRoofTriangle = "Split Log Roof Triangle", --0.4
    object_build_splitLogRoofTriangle_plural = "Split Log Roof Triangles", --0.4
    object_splitLogRoofInvertedTriangle = "Split Log Roof Inverted Triangle", --0.4
    object_splitLogRoofInvertedTriangle_plural = "Split Log Roof Inverted Triangles", --0.4
    object_build_splitLogRoofInvertedTriangle = "Split Log Roof Inverted Triangle", --0.4
    object_build_splitLogRoofInvertedTriangle_plural = "Split Log Roof Inverted Triangles", --0.4
    object_stick = "Stick",
    object_stick_plural = "Sticks",
    object_build_thatchRoof = "Thatch Roof",
    object_build_thatchRoof_plural = "Thatch Roofs",
    object_build_thatchRoofSlope = "Thatch Roof Slope", --0.4
    object_build_thatchRoofSlope_plural = "Thatch Roof Slopes", --0.4
    object_build_thatchRoofSmallCorner = "Thatch Roof Corner", --0.4
    object_build_thatchRoofSmallCorner_plural = "Thatch Roof Corners", --0.4
    object_build_thatchRoofSmallCornerInside = "Thatch Roof Inner Corner", --0.4
    object_build_thatchRoofSmallCornerInside_plural = "Thatch Roof Inner Corners", --0.4
    object_build_thatchRoofTriangle = "Thatch Roof Triangle", --0.4
    object_build_thatchRoofTriangle_plural = "Thatch Roof Triangles", --0.4
    object_build_thatchRoofInvertedTriangle = "Thatch Roof Inverted Triangle", --0.4
    object_build_thatchRoofInvertedTriangle_plural = "Thatch Roof Inverted Triangles", --0.4
    object_build_thatchRoofLarge = "Large Thatch Roof",
    object_build_thatchRoofLarge_plural = "Large Thatch Roofs",
    object_build_thatchRoofLargeCorner = "Large Thatch Roof Corner",
    object_build_thatchRoofLargeCorner_plural = "Large Thatch Roof Corners",
    object_build_thatchRoofLargeCornerInside = "Large Thatch Roof Inner Corner", --0.4
    object_build_thatchRoofLargeCornerInside_plural = "Large Thatch Roof Inner Corners", --0.4
    object_build_tileRoof = "Tile Hut/Roof",
    object_build_tileRoof_plural = "Tile Roofs",
    object_tileRoofSlope = "Tile Roof Slope", --0.4
    object_tileRoofSlope_plural = "Tile Roof Slopes", --0.4
    object_build_tileRoofSlope = "Tile Roof Slope", --0.4
    object_build_tileRoofSlope_plural = "Tile Roof Slopes", --0.4
    object_tileRoofSmallCorner = "Tile Roof Corner", --0.4
    object_tileRoofSmallCorner_plural = "Tile Roof Corners", --0.4
    object_build_tileRoofSmallCorner = "Tile Roof Corner", --0.4
    object_build_tileRoofSmallCorner_plural = "Tile Roof Corners", --0.4
    object_tileRoofSmallCornerInside = "Tile Roof Inner Corner", --0.4
    object_tileRoofSmallCornerInside_plural = "Tile Roof Inner Corners", --0.4
    object_build_tileRoofSmallCornerInside = "Tile Roof Inner Corner", --0.4
    object_build_tileRoofSmallCornerInside_plural = "Tile Roof Inner Corners", --0.4
    object_tileRoofTriangle = "Tile Roof Triangle", --0.4
    object_tileRoofTriangle_plural = "Tile Roof Triangles", --0.4
    object_build_tileRoofTriangle = "Tile Roof Triangle", --0.4
    object_build_tileRoofTriangle_plural = "Tile Roof Triangles", --0.4
    object_tileRoofInvertedTriangle = "Tile Roof Inverted Triangle", --0.4
    object_tileRoofInvertedTriangle_plural = "Tile Roof Inverted Triangles", --0.4
    object_build_tileRoofInvertedTriangle = "Tile Roof Inverted Triangle", --0.4
    object_build_tileRoofInvertedTriangle_plural = "Tile Roof Inverted Triangles", --0.4
    object_tileFloorTri2 = "Tile Floor Triangle", --0.4
    object_tileFloorTri2_plural = "Tile Floor Triangles", --0.4
    object_build_tileFloorTri2 = "Tile Floor Triangle", --0.4
    object_build_tileFloorTri2_plural = "Tile Floor Triangles", --0.4
    object_dirtWall = "Dirt Wall",
    object_dirtWall_plural = "Dirt Walls",
    object_alpacaWoolskin = "Alpaca Woolskin",
    object_alpacaWoolskin_plural = "Alpaca Woolskins",
    object_alpacaWoolskin_white = "Alpaca Woolskin (White)", --0.6
    object_alpacaWoolskin_white_plural = "Alpaca Woolskins (White)", --0.6
    object_alpacaWoolskin_black = "Alpaca Woolskin (Black)", --0.6
    object_alpacaWoolskin_black_plural = "Alpaca Woolskins (Black)", --0.6
    object_alpacaWoolskin_red = "Alpaca Woolskin (Red)", --0.6
    object_alpacaWoolskin_red_plural = "Alpaca Woolskins (Red)", --0.6
    object_alpacaWoolskin_yellow = "Alpaca Woolskin (Yellow)", --0.6
    object_alpacaWoolskin_yellow_plural = "Alpaca Woolskins (Yellow)", --0.6
    object_alpacaWoolskin_cream = "Alpaca Woolskin (Cream)", --0.6
    object_alpacaWoolskin_cream_plural = "Alpaca Woolskins (Cream)", --0.6
    object_mammothWoolskin = "Mammoth Woolskin",
    object_mammothWoolskin_plural = "Mammoth Woolskins",
    object_bone = "Bone",
    object_bone_plural = "Bones",
    object_fishBones = "Fish Bones", 
    object_fishBones_plural = "Fish Bones",
    object_rock = "Plain Rock",
    object_rock_plural = "Plain Rocks",
    object_rockSmall = "Small Rock",
    object_rockSmall_plural = "Small Rocks",
    object_rockLarge = "Boulder",
    object_rockLarge_plural = "Boulders",
    object_stoneBlock = "Stone Block", --0.4,
    object_stoneBlock_plural = "Stone Blocks", --0.4
    object_stoneTile = "Stone Tile", --0.4,
    object_stoneTile_plural = "Stone Tiles", --0.4

    object_limestoneRock = "Limestone Rock",
    object_limestoneRock_plural = "Limestone Rocks",
    object_limestoneRockSmall = "Small Limestone Rock",
    object_limestoneRockSmall_plural = "Small Limestone Rocks",
    object_limestoneRockLarge = "Limestone Boulder",
    object_limestoneRockLarge_plural = "Limestone Boulders",
    object_limestoneRockBlock = "Limestone Block", --0.4
    object_limestoneRockBlock_plural = "Limestone Blocks", --0.4
    object_stoneTile_limestone = "Limestone Tile", --0.4,
    object_stoneTile_limestone_plural = "Limestone Tiles", --0.4

    object_redRock = "Red Rock",
    object_redRock_plural = "Red Rocks",
    object_redRockSmall = "Small Red Rock",
    object_redRockSmall_plural = "Small Red Rocks",
    object_redRockLarge = "Red Rock Boulder",
    object_redRockLarge_plural = "Red Rock Boulders",
    object_redRockBlock = "Red Stone Block", --0.4
    object_redRockBlock_plural = "Red Stone Blocks", --0.4
    object_stoneTile_redRock = "Red Stone Tile", --0.4,
    object_stoneTile_redRock_plural = "Red Stone Tiles", --0.4

    object_greenRock = "Greenstone Rock",
    object_greenRock_plural = "Greenstone Rocks",
    object_greenRockSmall = "Small Greenstone Rock",
    object_greenRockSmall_plural = "Small Greenstone Rocks",
    object_greenRockLarge = "Greenstone Boulder",
    object_greenRockLarge_plural = "Greenstone Boulders",
    object_greenRockBlock = "Greenstone Block", --0.4
    object_greenRockBlock_plural = "Greenstone Blocks", --0.4
    object_stoneTile_greenRock = "Greenstone Tile", --0.4
    object_stoneTile_greenRock_plural = "Greenstone Tiles", --0.4

    --0.4 added group start
    
    object_graniteRock = "Granite Rock",
    object_graniteRock_plural = "Granite Rocks",
    object_graniteRockSmall = "Small Granite Rock",
    object_graniteRockSmall_plural = "Small Granite Rocks",
    object_graniteRockLarge = "Granite Boulder",
    object_graniteRockLarge_plural = "Granite Boulders",
    object_graniteRockBlock = "Granite Block",
    object_graniteRockBlock_plural = "Granite Blocks",
    object_stoneTile_graniteRock = "Granite Tile",
    object_stoneTile_graniteRock_plural = "Granite Tiles",
    
    
    object_marbleRock = "Marble Rock",
    object_marbleRock_plural = "Marble Rocks",
    object_marbleRockSmall = "Small Marble Rock",
    object_marbleRockSmall_plural = "Small Marble Rocks",
    object_marbleRockLarge = "Marble Boulder",
    object_marbleRockLarge_plural = "Marble Boulders",
    object_marbleRockBlock = "Marble Block",
    object_marbleRockBlock_plural = "Marble Blocks",
    object_stoneTile_marbleRock = "Marble Tile",
    object_stoneTile_marbleRock_plural = "Marble Tiles",

    object_lapisRock = "Lapis Lazuli Rock",
    object_lapisRock_plural = "Lapis Lazuli Rocks",
    object_lapisRockSmall = "Small Lapis Lazuli Rock",
    object_lapisRockSmall_plural = "Small Lapis Lazuli Rocks",
    object_lapisRockLarge = "Lapis Lazuli Boulder",
    object_lapisRockLarge_plural = "Lapis Lazuli Boulders",
    object_lapisRockBlock = "Lapis Lazuli Block",
    object_lapisRockBlock_plural = "Lapis Lazuli Blocks",
    object_stoneTile_lapisRock = "Lapis Lazuli Tile",
    object_stoneTile_lapisRock_plural = "Lapis Lazuli Tiles",

    object_sandstoneYellowRock = "Sandstone (Yellow) Rock",
    object_sandstoneYellowRock_plural = "Sandstone (Yellow) Rocks",
    object_sandstoneYellowRockSmall = "Small Sandstone (Yellow) Rock",
    object_sandstoneYellowRockSmall_plural = "Small Sandstone (Yellow) Rocks",
    object_sandstoneYellowRockLarge = "Sandstone (Yellow) Boulder",
    object_sandstoneYellowRockLarge_plural = "Sandstone (Yellow) Boulders",
    object_sandstoneYellowRockBlock = "Sandstone (Yellow) Block",
    object_sandstoneYellowRockBlock_plural = "Sandstone (Yellow) Blocks",
    object_stoneTile_sandstoneYellowRock = "Sandstone (Yellow) Tile",
    object_stoneTile_sandstoneYellowRock_plural = "Sandstone (Yellow) Tiles",

    object_sandstoneRedRock = "Sandstone (Red) Rock",
    object_sandstoneRedRock_plural = "Sandstone (Red) Rocks",
    object_sandstoneRedRockSmall = "Small Sandstone (Red) Rock",
    object_sandstoneRedRockSmall_plural = "Small Sandstone (Red) Rocks",
    object_sandstoneRedRockLarge = "Sandstone (Red) Boulder",
    object_sandstoneRedRockLarge_plural = "Sandstone (Red) Boulders",
    object_sandstoneRedRockBlock = "Sandstone (Red) Block",
    object_sandstoneRedRockBlock_plural = "Sandstone (Red) Blocks",
    object_stoneTile_sandstoneRedRock = "Sandstone (Red) Tile",
    object_stoneTile_sandstoneRedRock_plural = "Sandstone (Red) Tiles",

    object_sandstoneOrangeRock = "Sandstone (Orange) Rock",
    object_sandstoneOrangeRock_plural = "Sandstone (Orange) Rocks",
    object_sandstoneOrangeRockSmall = "Small Sandstone (Orange) Rock",
    object_sandstoneOrangeRockSmall_plural = "Small Sandstone (Orange) Rocks",
    object_sandstoneOrangeRockLarge = "Sandstone (Orange) Boulder",
    object_sandstoneOrangeRockLarge_plural = "Sandstone (Orange) Boulders",
    object_sandstoneOrangeRockBlock = "Sandstone (Orange) Block",
    object_sandstoneOrangeRockBlock_plural = "Sandstone (Orange) Blocks",
    object_stoneTile_sandstoneOrangeRock = "Sandstone (Orange) Tile",
    object_stoneTile_sandstoneOrangeRock_plural = "Sandstone (Orange) Tiles",

    object_sandstoneBlueRock = "Sandstone (Blue) Rock",
    object_sandstoneBlueRock_plural = "Sandstone (Blue) Rocks",
    object_sandstoneBlueRockSmall = "Small Sandstone (Blue) Rock",
    object_sandstoneBlueRockSmall_plural = "Small Sandstone (Blue) Rocks",
    object_sandstoneBlueRockLarge = "Sandstone (Blue) Boulder",
    object_sandstoneBlueRockLarge_plural = "Sandstone (Blue) Boulders",
    object_sandstoneBlueRockBlock = "Sandstone (Blue) Block",
    object_sandstoneBlueRockBlock_plural = "Sandstone (Blue) Blocks",
    object_stoneTile_sandstoneBlueRock = "Sandstone (Blue) Tile",
    object_stoneTile_sandstoneBlueRock_plural = "Sandstone (Blue) Tiles",

    --0.4 group end

    object_chickenMeatBreast = "Raw Chicken Meat", --0.3.0 added "Raw"
    object_chickenMeatBreast_plural = "Raw Chicken Meat", --0.3.0 added "Raw"
    object_birchWoodenPole = "Birch Wooden Pole",
    object_birchWoodenPole_plural = "Birch Wooden Poles",
    object_willowWoodenPole = "Willow Wooden Pole",
    object_willowWoodenPole_plural = "Willow Wooden Poles",
    object_appleWoodenPole = "Apple Wooden Pole",
    object_appleWoodenPole_plural = "Apple Wooden Poles",
    object_elderberryWoodenPole = "Elderberry Wooden Pole",
    object_elderberryWoodenPole_plural = "Elderberry Wooden Poles",
    object_orangeWoodenPole = "Orange Wooden Pole",
    object_orangeWoodenPole_plural = "Orange Wooden Poles",
    object_peachWoodenPole = "Peach Wooden Pole",
    object_peachWoodenPole_plural = "Peach Wooden Poles",
    object_bambooWoodenPole = "Bamboo Wooden Pole",
    object_bambooWoodenPole_plural = "Bamboo Wooden Poles",
    object_thatchWallDoor = "Thatch Wall With Door",
    object_thatchWallDoor_plural = "Thatch Walls With Door",
    object_birchSplitLog = "Birch Split Log",
    object_birchSplitLog_plural = "Birch Split Logs",
    object_willowSplitLog = "Willow Split Log",
    object_willowSplitLog_plural = "Willow Split Logs",
    object_appleSplitLog = "Apple Split Log",
    object_appleSplitLog_plural = "Apple Split Logs",
    object_elderberrySplitLog = "Elderberry Split Log",
    object_elderberrySplitLog_plural = "Elderberry Split Logs",
    object_orangeSplitLog = "Orange Split Log",
    object_orangeSplitLog_plural = "Orange Split Logs",
    object_peachSplitLog = "Peach Split Log",
    object_peachSplitLog_plural = "Peach Split Logs",
    object_coconutSplitLog = "Coconut Split Log",
    object_coconutSplitLog_plural = "Coconut Split Logs",
    object_build_hayBed = "Hay Bed",
    object_build_hayBed_plural = "Hay Beds",
    object_build_woolskinBed = "Woolskin Bed",
    object_build_woolskinBed_plural = "Woolskin Beds",
    object_aspenWoodenPole = "Aspen Wooden Pole",
    object_aspenWoodenPole_plural = "Aspen Wooden Poles",
    object_chicken = "Chicken",
    object_chicken_plural = "Chickens",
    object_chickenMeat = "Raw Chicken Meat", --0.3.0 added "Raw"
    object_chickenMeat_plural = "Raw Chicken Meat", --0.3.0 added "Raw"
    object_build_splitLogWall = "Split Log Wall",
    object_build_splitLogWall_plural = "Split Log Walls",
    object_build_splitLogWall4x1 = "Split Log Short Wall",
    object_build_splitLogWall4x1_plural = "Split Log Short Walls",
    object_build_splitLogWall2x2 = "Split Log Square Wall",
    object_build_splitLogWall2x2_plural = "Split Log Square Walls",
    object_build_splitLogWall2x1 = "Split Log Short Wall 2x1", --0.5
    object_build_splitLogWall2x1_plural = "Split Log Short Walls 2x1", --0.5
    object_build_splitLogRoofEnd = "Split Log Roof Wall",
    object_build_splitLogRoofEnd_plural = "Split Log Roof Walls",
    object_build_splitLogWallDoor = "Split Log Wall With Door",
    object_build_splitLogWallDoor_plural = "Split Log Walls With Doors",
    object_build_splitLogSteps = "Split Log Steps 2x3 Single Floor",
    object_build_splitLogSteps_plural = "Split Log Steps 2x3 Single Floor",
    object_build_splitLogSteps2x2 = "Split Log Steps 2x2 Half Floor",
    object_build_splitLogSteps2x2_plural = "Split Log Steps 2x2 Half Floor",
    object_build_splitLogRoof = "Split Log Roof",
    object_build_splitLogRoof_plural = "Split Log Roofs",
    object_mammoth = "Mammoth",
    object_mammoth_plural = "Mammoths",
    object_build_dirtRoof = "Dirt Roof",
    object_build_dirtRoof_plural = "Dirt Roofs",
    object_flint = "Flint",
    object_flint_plural = "Flint",
    object_clay = "Clay",
    object_clay_plural = "Clay",
    object_copperOre = "Copper Ore", --0.4
    object_copperOre_plural = "Copper Ore", --0.4
    object_tinOre = "Tin Ore", --0.4
    object_tinOre_plural = "Tin Ore", --0.4
    object_manure = "Manure", --0.4
    object_manure_plural = "Manure", --0.4
    object_manureRotten = "Rotten Manure", --0.4
    object_manureRotten_plural = "Rotten Manure", --0.4
    object_rottenGoo = "Rotten Goo", --0.4
    object_rottenGoo_plural = "Rotten Goo", --0.4
    object_compost = "Compost", --0.4
    object_compost_plural = "Compost", --0.4
    object_compostRotten = "Rotten Compost", --0.4.1
    object_compostRotten_plural = "Rotten Compost", --0.4.1
    object_build_craftArea = "Crafting Area",
    object_build_craftArea_plural = "Crafting Areas",
    object_build_dirtWallDoor = "Dirt Wall With Door",
    object_build_dirtWallDoor_plural = "Dirt Wall With Door",
    object_stoneKnife = "Stone Knife",
    object_stoneKnife_plural = "Stone Knives",
    object_stoneKnife_limestone = "Limestone Knife",
    object_stoneKnife_limestone_plural = "Limestone Knives",
    object_stoneKnife_redRock = "Red Rock Knife",
    object_stoneKnife_redRock_plural = "Red Rock Knives",
    object_stoneKnife_greenRock = "Greenstone Knife",
    object_stoneKnife_greenRock_plural = "Greenstone Knives",
    object_stoneKnife_graniteRock = "Granite Knife", --0.4
    object_stoneKnife_graniteRock_plural = "Granite Knives", --0.4
    object_stoneKnife_marbleRock = "Marble Knife", --0.4
    object_stoneKnife_marbleRock_plural = "Marble Knives", --0.4
    object_stoneKnife_lapisRock = "Lapis Lazuli Knife", --0.4
    object_stoneKnife_lapisRock_plural = "Lapis Lazuli Knives", --0.4
    object_flintKnife = "Flint Knife",
    object_flintKnife_plural = "Flint Knives",
    object_boneKnife = "Bone Knife",
    object_boneKnife_plural = "Bone Knives",
    object_bronzeKnife = "Bronze Knife", --0.4
    object_bronzeKnife_plural = "Bronze Knives", --0.4
    object_bronzeChisel = "Bronze Chisel", --0.4
    object_bronzeChisel_plural = "Bronze Chisels", --0.4
    object_boneFlute = "Bone Flute",
    object_boneFlute_plural = "Bone Flutes",
    object_logDrum = "Log Drum",
    object_logDrum_plural = "Log Drums",
    object_balafon = "Balafon",
    object_balafon_plural = "Balafons",
    object_drumStick = "Drum Stick",
    object_drumStick_plural = "Drum Sticks",
    object_alpaca = "Alpaca",
    object_alpaca_plural = "Alpacas",
    object_storageArea = "Storage Area",
    object_storageArea_plural = "Storage Areas",
    object_storageArea1x1 = "Small Storage Area 1x1", --0.5
    object_storageArea1x1_plural = "Small Storage Areas 1x1", --0.5
    object_storageArea4x4 = "Large Storage Area 4x4", --0.5
    object_storageArea4x4_plural = "Large Storage Areas 4x4", --0.5
    object_stoneAxeHead = "Stone Hand Axe",
    object_stoneAxeHead_plural = "Stone Hand Axes",
    object_stoneAxeHead_limestone = "Limestone Hand Axe",
    object_stoneAxeHead_limestone_plural = "Limestone Hand Axes",
    object_stoneAxeHead_redRock = "Red Rock Hand Axe",
    object_stoneAxeHead_redRock_plural = "Red Rock Hand Axes",
    object_stoneAxeHead_greenRock = "Greenstone Hand Axe",
    object_stoneAxeHead_greenRock_plural = "Greenstone Hand Axes",

     --0.4 group start:
    object_stoneChisel = "Stone Chisel", --0.4
    object_stoneChisel_plural = "Stone Chisels", --0.4
    object_stoneChisel_limestone = "Limestone Chisel", --0.4
    object_stoneChisel_limestone_plural = "Limestone Chisels", --0.4
    object_stoneChisel_redRock = "Red Rock Chisel", --0.4
    object_stoneChisel_redRock_plural = "Red Rock Chisels", --0.4
    object_stoneChisel_greenRock = "Greenstone Chisel", --0.4
    object_stoneChisel_greenRock_plural = "Greenstone Chisels", --0.4
    object_stoneChisel_graniteRock = "Granite Chisel", --0.4
    object_stoneChisel_graniteRock_plural = "Granite Chisels", --0.4
    object_stoneChisel_marbleRock = "Marble Chisel", --0.4
    object_stoneChisel_marbleRock_plural = "Marble Chisels", --0.4
    object_stoneChisel_lapisRock = "Lapis Lazuli Chisel", --0.4
    object_stoneChisel_lapisRock_plural = "Lapis Lazuli Chisels", --0.4

    
    object_stoneAxeHead_sandstoneYellowRock = "Sandstone (Yellow) Hand Axe", --0.4
    object_stoneAxeHead_sandstoneYellowRock_plural = "Sandstone (Yellow) Hand Axes", --0.4
    object_quernstone_sandstoneYellowRock = "Quern-stone", --0.4
    object_quernstone_sandstoneYellowRock_plural = "Quern-stones", --0.4

    object_stoneAxeHead_sandstoneRedRock = "Sandstone (Red) Hand Axe", --0.4
    object_stoneAxeHead_sandstoneRedRock_plural = "Sandstone (Red) Hand Axes", --0.4
    object_quernstone_sandstoneRedRock = "Quern-stone", --0.4
    object_quernstone_sandstoneRedRock_plural = "Quern-stones", --0.4

    object_stoneAxeHead_sandstoneOrangeRock = "Sandstone (Orange) Hand Axe", --0.4
    object_stoneAxeHead_sandstoneOrangeRock_plural = "Sandstone (Orange) Hand Axes", --0.4
    object_quernstone_sandstoneOrangeRock = "Quern-stone", --0.4
    object_quernstone_sandstoneOrangeRock_plural = "Quern-stones", --0.4

    object_stoneAxeHead_sandstoneBlueRock = "Sandstone (Blue) Hand Axe", --0.4
    object_stoneAxeHead_sandstoneBlueRock_plural = "Sandstone (Blue) Hand Axes", --0.4
    object_quernstone_sandstoneBlueRock = "Quern-stone", --0.4
    object_quernstone_sandstoneBlueRock_plural = "Quern-stones", --0.4

    object_stoneAxeHead_graniteRock = "Granite Hand Axe", --0.4
    object_stoneAxeHead_graniteRock_plural = "Granite Hand Axes", --0.4
    object_stoneAxeHead_marbleRock = "Marble Hand Axe", --0.4
    object_stoneAxeHead_marbleRock_plural = "Marble Hand Axes", --0.4
    object_stoneAxeHead_lapisRock = "Lapis Lazuli Hand Axe", --0.4
    object_stoneAxeHead_lapisRock_plural = "Lapis Lazuli Hand Axes", --0.4
    object_stoneHammerHead = "Stone Hammer Head", --0.4
    object_stoneHammerHead_plural = "Stone Hammer Heads", --0.4
    object_stoneHammerHead_redRock = "Red Rock Hammer Head", --0.4
    object_stoneHammerHead_redRock_plural = "Red Rock Hammer Heads", --0.4
    object_stoneHammerHead_greenRock = "Greenstone Hammer Head", --0.4
    object_stoneHammerHead_greenRock_plural = "Greenstone Hammer Heads", --0.4
    object_stoneHammerHead_graniteRock = "Granite Hammer Head", --0.4
    object_stoneHammerHead_graniteRock_plural = "Granite Hammer Heads", --0.4
    object_stoneHammerHead_marbleRock = "Marble Hammer Head", --0.4
    object_stoneHammerHead_marbleRock_plural = "Marble Hammer Heads", --0.4
    object_stoneHammerHead_lapisRock = "Lapis Lazuli Hammer Head", --0.4
    object_stoneHammerHead_lapisRock_plural = "Lapis Lazuli Hammer Heads", --0.4
    object_bronzeHammerHead = "Bronze Hammer Head", --0.4
    object_bronzeHammerHead_plural = "Bronze Hammer Heads", --0.4
    object_bronzeAxeHead = "Bronze Hand Axe", --0.4
    object_bronzeAxeHead_plural = "Bronze Hand Axes", --0.4
    object_bronzePickaxeHead = "Bronze Pickaxe Head", --0.4
    object_bronzePickaxeHead_plural = "Bronze Pickaxe Heads", --0.4
    object_compostBin = "Compost Bin", --0.4
    object_compostBin_plural = "Compost Bins", --0.4
    --0.4 group end

    object_flintAxeHead = "Flint Hand Axe",
    object_flintAxeHead_plural = "Flint Hand Axes",
    object_chickenMeatCooked = "Cooked Chicken Meat",
    object_chickenMeatCooked_plural = "Cooked Chicken Meat",
    object_pumpkinCooked = "Roasted Pumpkin",
    object_pumpkinCooked_plural = "Roasted Pumpkins",
    object_beetrootCooked = "Roasted Beetroot",
    object_beetrootCooked_plural = "Roasted Beetroots",
    object_flatbread = "Flatbread",
    object_flatbread_plural = "Flatbreads",
    object_flatbreadRotten = "Moldy Flatbread",
    object_flatbreadRotten_plural = "Moldy Flatbreads",
    object_build_thatchWall = "Thatch Wall",
    object_build_thatchWall_plural = "Thatch Walls",
    object_build_thatchWallLargeWindow = "Thatch Wall With Large Window", --0.3.0 change Single to Large
    object_build_thatchWallLargeWindow_plural = "Thatch Wall With Large Windows", --0.3.0 change Single to Large
    object_build_thatchWall4x1 = "Thatch Short Wall",
    object_build_thatchWall4x1_plural = "Thatch Short Walls",
    object_build_thatchWall2x2 = "Thatch Square Wall",
    object_build_thatchWall2x2_plural = "Thatch Square Walls",
    object_build_thatchWall2x1 = "Thatch Short Wall 2x1", --0.5
    object_build_thatchWall2x1_plural = "Thatch Short Walls 2x1", --0.5
    object_build_thatchRoofEnd = "Thatch Roof Wall",
    object_build_thatchRoofEnd_plural = "Thatch Roof Walls",
    object_deadChicken = "Chicken Carcass",
    object_deadChicken_plural = "Chicken Carcasses",
    object_deadChickenRotten = "Rotten Chicken Carcass",
    object_deadChickenRotten_plural = "Rotten Chicken Carcasses",
    object_thatchWall = "Thatch Wall",
    object_thatchWall_plural = "Thatch Walls",
    object_thatchWallLargeWindow = "Thatch Wall With Large Window", --0.3.0 change Single to Large
    object_thatchWallLargeWindow_plural = "Thatch Wall With Large Windows", --0.3.0 change Single to Large
    object_thatchWall4x1 = "Thatch Short Wall",
    object_thatchWall4x1_plural = "Thatch Short Walls",
    object_thatchWall2x2 = "Thatch Square Wall",
    object_thatchWall2x2_plural = "Thatch Square Walls",
    object_thatchWall2x1 = "Thatch Short Wall 2x1", --0.5
    object_thatchWall2x1_plural = "Thatch Short Walls 2x1", --0.5
    object_thatchRoofEnd = "Thatch Roof Wall",
    object_thatchRoofEnd_plural = "Thatch Roof Walls",
    object_sand = "Sand",
    object_sand_plural = "Sand",
    object_craftArea = "Crafting Area",
    object_craftArea_plural = "Crafting Areas",
    object_build_campfire = "Campfire",
    object_build_campfire_plural = "Campfires",
    object_build_brickKiln = "Kiln",
    object_build_brickKiln_plural = "Kilns",
    object_build_torch = "Torch",
    object_build_torch_plural = "Torches",
    object_stoneSpear = "Stone Spear",
    object_stoneSpear_plural = "Stone Spears",
    object_flintSpear = "Flint Spear",
    object_flintSpear_plural = "Flint Spears",
    object_boneSpear = "Bone Spear",
    object_boneSpear_plural = "Bone Spears",
    object_stonePickaxe = "Stone Pickaxe",
    object_stonePickaxe_plural = "Stone Pickaxes",
    object_flintPickaxe = "Flint Pickaxe",
    object_flintPickaxe_plural = "Flint Pickaxes",
    object_stoneHatchet = "Stone Hatchet",
    object_stoneHatchet_plural = "Stone Hatchets",
    object_flintHatchet = "Flint Hatchet",
    object_flintHatchet_plural = "Flint Hatchets",
    object_bronzeHatchet = "Bronze Hatchet", --0.4
    object_bronzeHatchet_plural = "Bronze Hatchets", --0.4
    object_bronzePickaxe = "Bronze Pickaxe", --0.4
    object_bronzePickaxe_plural = "Bronze Pickaxes", --0.4
    object_bronzeSpear = "Bronze Spear", --0.4
    object_bronzeSpear_plural = "Bronze Spears", --0.4
    object_alpacaMeatLeg = "Raw Alpaca Meat", --0.3.0 added "Raw"
    object_alpacaMeatLeg_plural = "Raw Alpaca Meat", --0.3.0 added "Raw"
    object_alpacaMeatLegCooked = "Cooked Alpaca Meat",
    object_alpacaMeatLegCooked_plural = "Cooked Alpaca Meat",
    object_hayBed = "Hay Bed",
    object_hayBed_plural = "Hay Beds",
    object_woolskinBed = "Woolskin Bed",
    object_woolskinBed_plural = "Woolskin Beds",
    object_sapien = "Sapien",
    object_sapien_plural = "Sapiens",
    object_thatchRoof = "Thatch Roof",
    object_thatchRoof_plural = "Thatch Roofs",
    object_thatchRoofSlope = "Thatch Roof Slope", --0.4
    object_thatchRoofSlope_plural = "Thatch Roof Slopes", --0.4
    object_thatchRoofSmallCorner = "Thatch Roof Corner", --0.4
    object_thatchRoofSmallCorner_plural = "Thatch Roof Corners", --0.4
    object_thatchRoofSmallCornerInside = "Thatch Roof Inner Corner", --0.4
    object_thatchRoofSmallCornerInside_plural = "Thatch Roof Inner Corners", --0.4
    object_thatchRoofTriangle = "Thatch Roof Triangle", --0.4
    object_thatchRoofTriangle_plural = "Thatch Roof Triangles", --0.4
    object_thatchRoofInvertedTriangle = "Thatch Roof Inverted Triangle", --0.4
    object_thatchRoofInvertedTriangle_plural = "Thatch Roof Inverted Triangles", --0.4
    object_thatchRoofLarge = "Large Thatch Roof",
    object_thatchRoofLarge_plural = "Large Thatch Roofs",
    object_thatchRoofLargeCorner = "Large Thatch Roof Corner",
    object_thatchRoofLargeCorner_plural = "Large Thatch Roof Corners",
    object_thatchRoofLargeCornerInside = "Large Thatch Roof Inner Corner", --0.4
    object_thatchRoofLargeCornerInside_plural = "Large Thatch Roof Inner Corners", --0.4
    object_tileRoof = "Tile Hut/Roof",
    object_tileRoof_plural = "Tile Roofs",
    object_pineWoodenPole = "Pine Wooden Pole",
    object_pineWoodenPole_plural = "Pine Wooden Poles",
    object_hay = "Hay",
    object_hay_plural = "Hay",
    object_hayRotten = "Rotten Hay",
    object_hayRotten_plural = "Rotten Hay",
    object_terrainModificationProxy = "Modify Terrain",
    object_terrainModificationProxy_plural = "Modify Terrain",
    object_dirt = "Soil",
    object_dirt_plural = "Soil",
    object_richDirt = "Rich Soil",
    object_richDirt_plural = "Rich Soil",
    object_poorDirt = "Poor Soil",
    object_poorDirt_plural = "Poor Soil",
    object_riverSand = "River Sand",
    object_riverSand_plural = "River Sand",
    object_redSand = "Red Sand",
    object_redSand_plural = "Red Sand",
    object_stoneSpearHead = "Stone Spear Head",
    object_stoneSpearHead_plural = "Stone Spear Heads",
    object_stoneSpearHead_limestone = "Limestone Spear Head",
    object_stoneSpearHead_limestone_plural = "Limestone Spear Heads",
    object_stoneSpearHead_redRock = "Red Rock Spear Head",
    object_stoneSpearHead_redRock_plural = "Red Rock Spear Heads",
    object_stoneSpearHead_greenRock = "Greenstone Spear Head",
    object_stoneSpearHead_greenRock_plural = "Greenstone Spear Heads",
    object_stoneSpearHead_graniteRock = "Granite Spear Head", --0.4
    object_stoneSpearHead_graniteRock_plural = "Granite Spear Heads", --0.4
    object_stoneSpearHead_marbleRock = "Marble Spear Head", --0.4
    object_stoneSpearHead_marbleRock_plural = "Marble Spear Heads", --0.4
    object_stoneSpearHead_lapisRock = "Lapis Lazuli Spear Head", --0.4
    object_stoneSpearHead_lapisRock_plural = "Lapis Lazuli Spear Heads", --0.4
    object_stonePickaxeHead = "Stone Pickaxe Head",
    object_stonePickaxeHead_plural = "Stone Pickaxe Heads",
    object_stonePickaxeHead_limestone = "Limestone Pickaxe Head",
    object_stonePickaxeHead_limestone_plural = "Limestone Pickaxe Heads",
    object_stonePickaxeHead_redRock = "Red Rock Pickaxe Head",
    object_stonePickaxeHead_redRock_plural = "Red Rock Pickaxe Heads",
    object_stonePickaxeHead_greenRock = "Greenstone Pickaxe Head",
    object_stonePickaxeHead_greenRock_plural = "Greenstone Pickaxe Heads",
    object_stonePickaxeHead_graniteRock = "Granite Pickaxe Head", --0.4
    object_stonePickaxeHead_graniteRock_plural = "Granite Pickaxe Heads", --0.4
    object_stonePickaxeHead_marbleRock = "Marble Pickaxe Head", --0.4
    object_stonePickaxeHead_marbleRock_plural = "Marble Pickaxe Heads", --0.4
    object_stonePickaxeHead_lapisRock = "Lapis Lazuli Pickaxe Head", --0.4
    object_stonePickaxeHead_lapisRock_plural = "Lapis Lazuli Pickaxe Heads", --0.4
    object_flintSpearHead = "Flint Spear Head",
    object_flintSpearHead_plural = "Flint Spear Heads",
    object_bronzeSpearHead = "Bronze Spear Head", --0.4
    object_bronzeSpearHead_plural = "Bronze Spear Heads", --0.4
    object_boneSpearHead = "Bone Spear Head",
    object_boneSpearHead_plural = "Bone Spear Heads",
    object_flintPickaxeHead = "Flint Pickaxe Head",
    object_flintPickaxeHead_plural = "Flint Pickaxe Heads",
    object_stoneHammer = "Stone Hammer", --0.4
    object_stoneHammer_plural = "Stone Hammers", --0.4
    object_bronzeHammer = "Bronze Hammer", --0.4
    object_bronzeHammer_plural = "Bronze Hammers", --0.4
    object_build_thatchWallDoor = "Thatch Wall With Door",
    object_build_thatchWallDoor_plural = "Thatch Wall With Door",
    object_pineSplitLog = "Pine Split Log",
    object_pineSplitLog_plural = "Pine Split Logs",
    object_burntBranch = "Burnt Branch",
    object_burntBranch_plural = "Burnt Branches",
    object_unfiredUrnWet = "Unfired Urn (Wet)",
    object_unfiredUrnWet_plural = "Unfired Urns (Wet)",
    object_unfiredUrnDry = "Unfired Urn",
    object_unfiredUrnDry_plural = "Unfired Urns",
    object_firedUrn = "Fired Urn",
    object_firedUrn_plural = "Fired Urns",
    object_unfiredUrnHulledWheat = "Hulled Wheat (Unfired Urn)",
    object_unfiredUrnHulledWheat_plural = "Hulled Wheat (Unfired Urn)",
    object_unfiredUrnHulledWheatRotten = "Moldy Hulled Wheat (Unfired Urn)",
    object_unfiredUrnHulledWheatRotten_plural = "Moldy Hulled Wheat (Unfired Urn)",
    object_firedUrnHulledWheat = "Hulled Wheat (Fired Urn)",
    object_firedUrnHulledWheat_plural = "Hulled Wheat (Fired Urn)",
    object_firedUrnHulledWheatRotten = "Moldy Hulled Wheat (Fired Urn)",
    object_firedUrnHulledWheatRotten_plural = "Moldy Hulled Wheat (Fired Urn)",

    --0.3.0 added group start
    object_unfiredBowlWet = "Unfired Bowl (Wet)",
    object_unfiredBowlWet_plural = "Unfired Bowls (Wet)",
    object_unfiredBowlDry = "Unfired Bowl",
    object_unfiredBowlDry_plural = "Unfired Bowls",
    object_firedBowl = "Fired Bowl",
    object_firedBowl_plural = "Fired Bowls",
    
    object_unfiredBowlInjuryMedicine = "Injury Medicine",
    object_unfiredBowlInjuryMedicine_plural = "Injury Medicine",
    object_unfiredBowlBurnMedicine = "Burn Medicine",
    object_unfiredBowlBurnMedicine_plural = "Burn Medicine",
    object_unfiredBowlFoodPoisoningMedicine = "Food Poisoning Medicine",
    object_unfiredBowlFoodPoisoningMedicine_plural = "Food Poisoning Medicine",
    object_unfiredBowlVirusMedicine = "Virus Medicine (Unfired Bowl)",
    object_unfiredBowlVirusMedicine_plural = "Virus Medicine (Unfired Bowls)",
    object_unfiredBowlMedicineRotten = "Rotten Medicine",
    object_unfiredBowlMedicineRotten_plural = "Rotten Medicine",
    
    object_firedBowlInjuryMedicine = "Injury Medicine",
    object_firedBowlInjuryMedicine_plural = "Injury Medicine",
    object_firedBowlBurnMedicine = "Burn Medicine",
    object_firedBowlBurnMedicine_plural = "Burn Medicine",
    object_firedBowlFoodPoisoningMedicine = "Food Poisoning Medicine",
    object_firedBowlFoodPoisoningMedicine_plural = "Food Poisoning Medicine",
    object_firedBowlVirusMedicine = "Virus Medicine",
    object_firedBowlVirusMedicine_plural = "Virus Medicine",
    object_firedBowlMedicineRotten = "Rotten Medicine",
    object_firedBowlMedicineRotten_plural = "Rotten Medicine",
    --0.3.0 group end

    
    object_crucibleWet = "Crucible (Wet)", --0.4
    object_crucibleWet_plural = "Crucibles (Wet)", --0.4
    object_crucibleDry = "Crucible", --0.4
    object_crucibleDry_plural = "Crucibles", --0.4

    object_temporaryCraftArea = "Craft",
    object_temporaryCraftArea_plural = "Craft",
    object_quernstone = "Quern-stone",
    object_quernstone_plural = "Quern-stones",
    object_quernstone_limestone = "Quern-stone",
    object_quernstone_limestone_plural = "Quern-stones",
    object_quernstone_redRock = "Quern-stone",
    object_quernstone_redRock_plural = "Quern-stones",
    object_quernstone_greenRock = "Quern-stone",
    object_quernstone_greenRock_plural = "Quern-stones",
    object_quernstone_graniteRock = "Quern-stone", --0.4
    object_quernstone_graniteRock_plural = "Quern-stones", --0.4
    object_quernstone_marbleRock = "Quern-stone", --0.4
    object_quernstone_marbleRock_plural = "Quern-stones", --0.4
    object_quernstone_lapisRock = "Quern-stone", --0.4
    object_quernstone_lapisRock_plural = "Quern-stones", --0.4
    object_unfiredUrnFlour = "Flour (Unfired Urn)",
    object_unfiredUrnFlour_plural = "Flour (Unfired Urns)",
    object_unfiredUrnFlourRotten = "Moldy Flour (Unfired Urn)",
    object_unfiredUrnFlourRotten_plural = "Moldy Flour (Unfired Urns)",
    object_firedUrnFlour = "Flour (Fired Urn)",
    object_firedUrnFlour_plural = "Flour (Fired Urns)",
    object_firedUrnFlourRotten = "Moldy Flour (Fired Urn)",
    object_firedUrnFlourRotten_plural = "Moldy Flour (Fired Urns)",
    object_splitLogBench = "Split Log Bench",
    object_splitLogBench_plural = "Split Log Benches",
    object_build_splitLogBench = "Split Log Bench",
    object_build_splitLogBench_plural = "Split Log Benches",
    object_splitLogShelf = "Split Log Shelf", --0.5
    object_splitLogShelf_plural = "Split Log Shelves", --0.5
    object_build_splitLogShelf = "Split Log Shelf", --0.5
    object_build_splitLogShelf_plural = "Split Log Shelves", --0.5
    object_splitLogToolRack = "Split Log Tool Rack", --0.5
    object_splitLogToolRack_plural = "Split Log Tool Racks", --0.5
    object_build_splitLogToolRack = "Split Log Tool Rack", --0.5
    object_build_splitLogToolRack_plural = "Split Log Tool Racks", --0.5
    object_sled = "Sled", --0.5
    object_sled_plural = "Sleds", --0.5
    object_uncoveredSled = "Uncovered Sled", --0.5 only used in multiselect
    object_uncoveredSled_plural = "Uncovered Sleds", --0.5 only used in multiselect
    object_uncoveredCanoe = "Uncovered Canoe", --0.5.1 only used in multiselect
    object_uncoveredCanoe_plural = "Uncovered Canoes", --0.5.1 only used in multiselect

    object_canoe = "Canoe", --0.5.1
    object_canoe_plural = "Canoes", --0.5.1
    object_coveredCanoe = "Covered Canoe", --0.5.1
    object_coveredCanoe_plural = "Covered Canoes", --0.5.1
    object_build_canoe = "Canoe", --0.5.1
    object_build_canoe_plural = "Canoes", --0.5.1
    object_build_coveredCanoe = "Covered Canoe", --0.5.1
    object_build_coveredCanoe_plural = "Covered Canoes", --0.5.1
    object_paddle = "Paddle", --0.5.1
    object_paddle_plural = "Paddles", --0.5.1
    
    object_build_sled = "Sled", --0.5
    object_build_sled_plural = "Sleds", --0.5
    object_coveredSled = "Covered Sled", --0.5
    object_coveredSled_plural = "Covered Sleds", --0.5
    object_build_coveredSled = "Covered Sled", --0.5
    object_build_coveredSled_plural = "Covered Sleds", --0.5
    object_splitLogRoof = "Split Log Roof",
    object_splitLogRoof_plural = "Split Log Roofs",
    object_branchRotten = "Rotten Branch",
    object_branchRotten_plural = "Rotten Branches",
    object_breadDough = "Bread Dough",
    object_breadDough_plural = "Bread Dough",
    object_breadDoughRotten = "Rotten Bread Dough",
    object_breadDoughRotten_plural = "Rotten Bread Dough",
    object_flaxTwine = "Flax Twine",
    object_flaxTwine_plural = "Flax Twine",
    object_mudBrickWet_sand = "Sand Mud Brick (Wet)",
    object_mudBrickWet_sand_plural = "Sand Mud Bricks (Wet)",
    object_mudBrickWet_hay = "Hay Mud Brick (Wet)",
    object_mudBrickWet_hay_plural = "Hay Mud Bricks (Wet)",
    object_mudBrickWet_riverSand = "River Sand Mud Brick (Wet)",
    object_mudBrickWet_riverSand_plural = "River Sand Mud Bricks (Wet)",
    object_mudBrickWet_redSand = "Red Sand Mud Brick (Wet)",
    object_mudBrickWet_redSand_plural = "Red Sand Mud Bricks (Wet)",
    object_mudTileWet = "Unfired Tile (Wet)",
    object_mudTileWet_plural = "Unfired Tiles (Wet)",
    object_mudTileDry = "Unfired Tile",
    object_mudTileDry_plural = "Unfired Tiles",
    object_firedTile = "Tile",
    object_firedTile_plural = "Tiles",
    object_mudBrickDry_sand = "Sand Mud Brick (Dry)",
    object_mudBrickDry_sand_plural = "Sand Mud Bricks (Dry)",
    object_mudBrickDry_hay = "Hay Mud Brick (Dry)",
    object_mudBrickDry_hay_plural = "Hay Mud Bricks (Dry)",
    object_mudBrickDry_riverSand = "River Sand Mud Brick (Dry)",
    object_mudBrickDry_riverSand_plural = "River Sand Mud Bricks (Dry)",
    object_mudBrickDry_redSand = "Red Sand Mud Brick (Dry)",
    object_mudBrickDry_redSand_plural = "Red Sand Mud Bricks (Dry)",
    object_firedBrick_sand = "Fired Sand Brick",
    object_firedBrick_sand_plural = "Fired Sand Bricks",
    object_firedBrick_hay = "Fired Hay Brick",
    object_firedBrick_hay_plural = "Fired Hay Bricks",
    object_firedBrick_riverSand = "Fired River Sand Brick",
    object_firedBrick_riverSand_plural = "Fired River Sand Bricks",
    object_firedBrick_redSand = "Fired Red Sand Brick",
    object_firedBrick_redSand_plural = "Fired Red Sand Bricks",
    object_mudBrickWall = "Mudbrick Wall",
    object_mudBrickWall_plural = "Mudbrick Walls",
    object_mudBrickWall4x1 = "Mudbrick Short Wall",
    object_mudBrickWall4x1_plural = "Mudbrick Short Walls",
    object_mudBrickWall2x2 = "Mudbrick Square Wall",
    object_mudBrickWall2x2_plural = "Mudbrick Square Walls",
    object_mudBrickWall2x1 = "Mudbrick Short Wall 2x1", --0.5
    object_mudBrickWall2x1_plural = "Mudbrick Short Walls 2x1", --0.5
    object_build_mudBrickWall = "Mudbrick Wall",
    object_build_mudBrickWall_plural = "Mudbrick Walls",
    object_build_mudBrickWall4x1 = "Mudbrick Short Wall",
    object_build_mudBrickWall4x1_plural = "Mudbrick Short Walls",
    object_build_mudBrickWall2x2 = "Mudbrick Square Wall",
    object_build_mudBrickWall2x2_plural = "Mudbrick Square Walls",
    object_build_mudBrickWall2x1 = "Mudbrick Short Wall 2x1", --0.5
    object_build_mudBrickWall2x1_plural = "Mudbrick Short Walls 2x1", --0.5
    object_mudBrickRoofEnd = "Mudbrick Roof End Wall", --0.4
    object_mudBrickRoofEnd_plural = "Mudbrick Roof End Walls",--0.4
    object_build_mudBrickRoofEnd = "Mudbrick Roof End Wall",--0.4
    object_build_mudBrickRoofEnd_plural = "Mudbrick Roof End Walls",--0.4
    object_mudBrickWallDoor = "Mudbrick Wall With Door",
    object_mudBrickWallDoor_plural = "Mudbrick Wall With Door",
    object_build_mudBrickWallDoor = "Mudbrick Wall With Door",
    object_build_mudBrickWallDoor_plural = "Mudbrick Wall With Door",
    object_mudBrickWallLargeWindow = "Mudbrick Wall With Large Window",
    object_mudBrickWallLargeWindow_plural = "Mudbrick Wall With Large Window",
    object_build_mudBrickWallLargeWindow = "Mudbrick Wall With Large Window",
    object_build_mudBrickWallLargeWindow_plural = "Mudbrick Wall With Large Window",
    object_mudBrickColumn = "Mudbrick Column",
    object_mudBrickColumn_plural = "Mudbrick Columns",
    object_build_mudBrickColumn = "Mudbrick Column",
    object_build_mudBrickColumn_plural = "Mudbrick Columns",
    
    object_stoneBlockWall = "Stone Block Wall", --0.4
    object_stoneBlockWall_plural = "Stone Block Walls", --0.4
    object_build_stoneBlockWall = "Stone Block Wall", --0.4
    object_build_stoneBlockWall_plural = "Stone Block Walls", --0.4
    object_stoneBlockWallDoor = "Stone Block Wall With Door", --0.4
    object_stoneBlockWallDoor_plural = "Stone Block Wall With Door", --0.4
    object_build_stoneBlockWallDoor = "Stone Block Wall With Door", --0.4
    object_build_stoneBlockWallDoor_plural = "Stone Block Wall With Door", --0.4
    object_stoneBlockWallLargeWindow = "Stone Block Wall With Large Window", --0.4
    object_stoneBlockWallLargeWindow_plural = "Stone Block Wall With Large Window", --0.4
    object_build_stoneBlockWallLargeWindow = "Stone Block Wall With Large Window", --0.4
    object_build_stoneBlockWallLargeWindow_plural = "Stone Block Wall With Large Window", --0.4
    object_stoneBlockWall4x1 = "Stone Block Short Wall", --0.4
    object_stoneBlockWall4x1_plural = "Stone Block Short Walls", --0.4
    object_build_stoneBlockWall4x1 = "Stone Block Short Wall", --0.4
    object_build_stoneBlockWall4x1_plural = "Stone Block Short Walls", --0.4
    object_stoneBlockWall2x2 = "Stone Block Square Wall", --0.4
    object_stoneBlockWall2x2_plural = "Stone Block Square Walls", --0.4
    object_build_stoneBlockWall2x2 = "Stone Block Square Wall", --0.4
    object_build_stoneBlockWall2x2_plural = "Stone Block Square Walls", --0.4
    object_stoneBlockWall2x1 = "Stone Block Short Wall 2x1", --0.5
    object_stoneBlockWall2x1_plural = "Stone Block Short Walls 2x1", --0.5
    object_build_stoneBlockWall2x1 = "Stone Block Short Wall 2x1", --0.5
    object_build_stoneBlockWall2x1_plural = "Stone Block Short Walls 2x1", --0.5
    object_stoneBlockRoofEnd = "Stone Block Roof End Wall", --0.4
    object_stoneBlockRoofEnd_plural = "Stone Block Roof End Walls",--0.4
    object_build_stoneBlockRoofEnd = "Stone Block Roof End Wall",--0.4
    object_build_stoneBlockRoofEnd_plural = "Stone Block Roof End Walls",--0.4
    object_stoneBlockColumn = "Stone Block Column", --0.4
    object_stoneBlockColumn_plural = "Stone Block Columns", --0.4
    object_build_stoneBlockColumn = "Stone Block Column", --0.4
    object_build_stoneBlockColumn_plural = "Stone Block Columns", --0.4
    object_stoneBlockFoundation1x1 = "Stone Block Foundation 1x1", --0.6.1
    object_stoneBlockFoundation1x1_plural = "Stone Block Foundation 1x1", --0.6.1
    object_build_stoneBlockFoundation1x1 = "Stone Block Foundation 1x1", --0.6.1
    object_build_stoneBlockFoundation1x1_plural = "Stone Block Foundation 1x1", --0.6.1
    object_stoneBlockFoundation2x2 = "Stone Block Foundation 2x2", --0.6.1
    object_stoneBlockFoundation2x2_plural = "Stone Block Foundation 2x2", --0.6.1
    object_build_stoneBlockFoundation2x2 = "Stone Block Foundation 2x2", --0.6.1
    object_build_stoneBlockFoundation2x2_plural = "Stone Block Foundation 2x2", --0.6.1

    object_brickWall = "Brick Wall",
    object_brickWall_plural = "Brick Walls",
    object_build_brickWall = "Brick Wall",
    object_build_brickWall_plural = "Brick Walls",
    object_brickWallDoor = "Brick Wall With Door",
    object_brickWallDoor_plural = "Brick Wall With Door",
    object_build_brickWallDoor = "Brick Wall With Door",
    object_build_brickWallDoor_plural = "Brick Wall With Door",
    object_brickWallLargeWindow = "Brick Wall With Large Window",
    object_brickWallLargeWindow_plural = "Brick Wall With Large Window",
    object_build_brickWallLargeWindow = "Brick Wall With Large Window",
    object_build_brickWallLargeWindow_plural = "Brick Wall With Large Window",
    object_brickWall4x1 = "Brick Short Wall",
    object_brickWall4x1_plural = "Brick Short Walls",
    object_build_brickWall4x1 = "Brick Short Wall",
    object_build_brickWall4x1_plural = "Brick Short Walls",
    object_brickWall2x2 = "Brick Square Wall",
    object_brickWall2x2_plural = "Brick Square Walls",
    object_build_brickWall2x2 = "Brick Square Wall",
    object_build_brickWall2x2_plural = "Brick Square Walls",
    object_brickWall2x1 = "Brick Short Wall 2x1", --0.5
    object_brickWall2x1_plural = "Brick Short Walls 2x1", --0.5
    object_build_brickWall2x1 = "Brick Short Wall 2x1", --0.5
    object_build_brickWall2x1_plural = "Brick Short Walls 2x1", --0.5
    object_brickRoofEnd = "Brick Roof End Wall", --0.4
    object_brickRoofEnd_plural = "Brick Roof End Walls",--0.4
    object_build_brickRoofEnd = "Brick Roof End Wall",--0.4
    object_build_brickRoofEnd_plural = "Brick Roof End Walls",--0.4
    object_brickFoundation1x1 = "Brick Foundation 1x1", --0.6.1
    object_brickFoundation1x1_plural = "Brick Foundation 1x1", --0.6.1
    object_build_brickFoundation1x1 = "Brick Foundation 1x1", --0.6.1
    object_build_brickFoundation1x1_plural = "Brick Foundation 1x1", --0.6.1
    object_brickFoundation2x2 = "Brick Foundation 2x2", --0.6.1
    object_brickFoundation2x2_plural = "Brick Foundation 2x2", --0.6.1
    object_build_brickFoundation2x2 = "Brick Foundation 2x2", --0.6.1
    object_build_brickFoundation2x2_plural = "Brick Foundation 2x2", --0.6.1
    object_splitLogWallLargeWindow = "Split Log Wall With Large Window",
    object_splitLogWallLargeWindow_plural = "Split Log Wall With Large Window",
    object_build_splitLogWallLargeWindow = "Split Log Wall With Large Window",
    object_build_splitLogWallLargeWindow_plural = "Split Log Wall With Large Window",
    object_mammothMeat = "Raw Mammoth Meat", --0.3.0 added "Raw"
    object_mammothMeat_plural = "Raw Mammoth Meat", --0.3.0 added "Raw"
    object_mammothMeatTBone = "Raw Mammoth Meat", --0.3.0 added "Raw"
    object_mammothMeatTBone_plural = "Raw Mammoth Meat", --0.3.0 added "Raw"
    object_mammothMeatCooked = "Cooked Mammoth Meat",
    object_mammothMeatCooked_plural = "Cooked Mammoth Meat",
    object_mammothMeatTBoneCooked = "Cooked Mammoth Meat",
    object_mammothMeatTBoneCooked_plural = "Cooked Mammoth Meat",
    object_bronzeIngot = "Bronze Ingot", --0.4
    object_bronzeIngot_plural = "Bronze Ingots", --0.4

    
    object_catfish = "Catfish",
    object_catfish_plural = "Catfish",

    
    object_coelacanth = "Coelacanth", --0.6
    object_coelacanth_plural = "Coelacanth", --0.6
    object_flagellipinna = "Flagellipinna", --0.6
    object_flagellipinna_plural = "Flagellipinna", --0.6
    object_polypterus = "Polypterus", --0.6
    object_polypterus_plural = "Polypterus", --0.6
    object_redfish = "Redfish", --0.6
    object_redfish_plural = "Redfish", --0.6
    object_tropicalfish = "Jackfish", --0.6
    object_tropicalfish_plural = "Jackfish", --0.6
    object_swordfish = "Swordfish", --0.6
    object_swordfish_plural = "Swordfish", --0.6

    --order
    order_idle = "Idle",
    order_resting = "Resting",
    order_multitask_social = "Social",
    order_multitask_social_inProgress = "Socializing",
    order_multitask_lookAt = "Look",
    order_multitask_lookAt_inProgress = "Looking",

    order_moveToMotivation_bed = "Moving towards home", --0.3.0
    order_moveToMotivation_warmth = "Moving towards warmth", --0.3.0
    order_moveToMotivation_light = "Moving towards light", --0.3.0
    order_moveToMotivation_avoidThreat = "Moving away from threat", --0.7

    order_gather = "Gather",
    order_gather_inProgress = "Gathering",
    order_chop = "Chop",
    order_chop_inProgress = "Chopping",
    order_storeObject = "Store",
    order_storeObject_inProgress = "Storing",
    order_transferObject = "Transfer",
    order_transferObject_inProgress = "Transferring",
    order_destroyContents = "Destroy Contents",
    order_destroyContents_inProgress = "Destroying Contents",
    order_pullOut = "Pull Out",
    order_pullOut_inProgress = "Pulling out",
    order_moveTo = "Move",
    order_moveTo_inProgress = "Moving",
    order_moveToLogistics = "Transfer",
    order_moveToLogistics_inProgress = "Transferring",
    order_flee = "Flee",
    order_flee_inProgress = "Fleeing",
    order_sneakTo = "Sneak",
    order_sneakTo_inProgress = "Sneaking",
    order_pickupObject = "Fetch",
    order_pickupObject_inProgress = "Fetching",
    order_deliver = "Deliver",
    order_deliver_inProgress = "Delivering",
    order_removeObject = "Clear",
    order_removeObject_inProgress = "Clearing",
    order_buildMoveComponent = "Build",
    order_buildMoveComponent_inProgress = "Building",
    order_buildActionSequence = "Build",
    order_buildActionSequence_inProgress = "Building",
    order_eat = "Eat",
    order_eat_inProgress = "Eating",
    order_dig = "Dig",
    order_dig_inProgress = "Digging",
    order_mine = "Mine",
    order_mine_inProgress = "Mining",
    order_clear = "Clear",
    order_clear_inProgress = "Clearing",
    order_follow = "Follow",
    order_follow_inProgress = "Following",
    order_social = "Social",
    order_social_inProgress = "Socializing",
    order_turn = "Turn",
    order_turn_inProgress = "Turning",
    order_fall = "Fall",
    order_fall_inProgress = "Falling",
    order_dropObject = "Drop",
    order_dropObject_inProgress = "Dropping",
    order_sleep = "Sleep",
    order_sleep_inProgress = "Sleeping",
    order_light = "Light",
    order_light_inProgress = "Lighting",
    order_extinguish = "Extinguish",
    order_extinguish_inProgress = "Extinguishing",
    order_throwProjectile = "Throw", --0.7 changed from hunt, as it may now be used for conflict
    order_throwProjectile_inProgress = "Throwing", --0.7 changed from hunting, as it may now be used for conflict
    order_craft = "Craft",
    order_craft_inProgress = "Crafting",
    order_recruit = "Recruit",
    order_recruit_inProgress = "Recruiting",
    order_banish = "Banish", --0.7
    order_banish_inProgress = "Banishing", --0.7
    order_fight = "Fight", --0.7
    order_fight_inProgress = "Fighting", --0.7
    order_defend = "Defend", --0.7
    order_defend_inProgress = "Defending", --0.7
    order_sit = "Sit",
    order_sit_inProgress = "Sitting",
    order_playInstrument = "Play",
    order_playInstrument_inProgress = "Playing",
    order_butcher = "Butcher",
    order_butcher_inProgress = "Butchering",
    order_putOnClothing = "Put On Clothing",
    order_putOnClothing_inProgress = "Putting On Clothing",
    order_takeOffClothing = "Take Off Clothing",
    order_takeOffClothing_inProgress = "Taking Off Clothing",
    order_giveMedicineToSelf = "Treat", --0.3.0
    order_giveMedicineToSelf_inProgress = "Treating", --0.3.0
    order_giveMedicineToOtherSapien = "Treat", --0.3.0
    order_giveMedicineToOtherSapien_inProgress = "Treating", --0.3.0

    order_fertilize = "Mulch", --0.4
    order_fertilize_inProgress = "Mulching", --0.4
    order_deliverToCompost = "Compost", --0.4
    order_deliverToCompost_inProgress = "Composting", --0.4
    order_chiselStone = "Chisel", --0.4
    order_chiselStone_inProgress = "Chiselling", --0.4

    order_haul = "Haul", --0.5 --moving/dragging a large object like a sled or canoe
    order_haul_inProgress = "Hauling", --0.5
    order_greet = "Greet", --0.5
    order_greet_inProgress = "Greeting", --0.5

    --resource
    resource_branch = "Branch",
    resource_branch_plural = "Branches",
    resource_burntBranch = "Burnt Branch",
    resource_burntBranch_plural = "Burnt Branches",
    resource_log = "Log",
    resource_log_plural = "Logs",
    resource_rock = "Hard Large Rock", --0.4 added (Hard), --0.5 changed from x (Hard) to Hard x
    resource_rock_plural = "Hard Large Rocks", --0.4 added "Hard", 0.5 changed from x (Hard) to Hard x
    resource_rockSoft = "Soft Large Rock", --0.4, 0.5
    resource_rockSoft_plural = "Soft Large Rocks", --0.4, 0.5
    resource_rockGeneric = "Large Rock", --0.5
    resource_rockGeneric_plural = "Large Rocks ", --0.5
    resource_dirt = "Soil",
    resource_dirt_plural = "Soil",
    resource_hay = "Hay",
    resource_hay_plural = "Hay",
    resource_hayRotten = "Rotten Hay",
    resource_hayRotten_plural = "Rotten Hay",
    resource_grass = "Wet Hay",
    resource_grass_plural = "Wet Hay",
    resource_flaxDried = "Dry Flax",
    resource_flaxDried_plural = "Dry Flax",
    resource_sand = "Sand",
    resource_sand_plural = "Sand",
    resource_rockSmall = "Hard Small Rock", --0.4 added "Hard"
    resource_rockSmall_plural = "Hard Small Rocks", --0.4 added "Hard"
    resource_rockSmallSoft = "Soft Small Rock", --0.4, 0.5 changed
    resource_rockSmallSoft_plural = "Soft Small Rocks", --0.4, 0.5 changed
    resource_rockSmallGeneric = "Small Rock", --0.5
    resource_rockSmallGeneric_plural = "Small Rocks", --0.5
    resource_stoneBlockSoft = "Soft Stone Block", --0.4, 0.5 changed
    resource_stoneBlockSoft_plural = "Soft Stone Blocks", --0.4, 0.5 changed
    resource_stoneBlockHard = "Hard Stone Block", --0.4, --0.5 changed from x y (Hard) to Hard x y
    resource_stoneBlockHard_plural = "Hard Stone Blocks", --0.4, 0.5 changed
    resource_stoneBlockGeneric = "Stone Block", --0.5
    resource_stoneBlockGeneric_plural = "Stone Blocks", --0.5
    resource_flint = "Flint",
    resource_flint_plural = "Flint",
    resource_clay = "Clay",
    resource_clay_plural = "Clay",
    resource_copperOre = "Copper Ore",
    resource_copperOre_plural = "Copper Ore",
    resource_tinOre = "Tin Ore",
    resource_tinOre_plural = "Tin Ore",
    resource_manure = "Manure", --0.4
    resource_manure_plural = "Manure", --0.4
    resource_manureRotten = "Rotten Manure", --0.4
    resource_manureRotten_plural = "Rotten Manure", --0.4
    resource_rottenGoo = "Rotten Goo", --0.4
    resource_rottenGoo_plural = "Rotten Goo", --0.4
    resource_compost = "Compost", --0.4
    resource_compost_plural = "Compost", --0.4
    resource_compostRotten = "Rotten Compost", --0.4.1
    resource_compostRotten_plural = "Rotten Compost", --0.4.1
    resource_deadChicken = "Chicken Carcass",
    resource_deadChicken_plural = "Chicken Carcasses",
    resource_deadChickenRotten = "Rotten Chicken Carcass",
    resource_deadChickenRotten_plural = "Rotten Chicken Carcasses",
    resource_deadAlpaca = "Alpaca Carcass",
    resource_deadAlpaca_plural = "Alpaca Carcasses",
    resource_chickenMeat = "Raw Chicken Meat", --0.3.0 added "Raw"
    resource_chickenMeat_plural = "Raw Chicken Meat", --0.3.0 added "Raw"
    resource_chickenMeatCooked = "Cooked Chicken Meat",
    resource_chickenMeatCooked_plural = "Cooked Chicken Meat",
    resource_pumpkinCooked = "Roasted Pumpkin",
    resource_pumpkinCooked_plural = "Roasted Pumpkins",
    resource_beetrootCooked = "Roasted Beetroot",
    resource_beetrootCooked_plural = "Roasted Beetroots",
    resource_flatbread = "Flatbread",
    resource_flatbread_plural = "Flatbreads",
    resource_flatbreadRotten = "Moldy Flatbread",
    resource_flatbreadRotten_plural = "Moldy Flatbreads",
    resource_alpacaMeat = "Raw Alpaca Meat", --0.3.0 added "Raw"
    resource_alpacaMeat_plural = "Raw Alpaca Meat", --0.3.0 added "Raw"
    resource_alpacaMeatCooked = "Cooked Alpaca Meat",
    resource_alpacaMeatCooked_plural = "Cooked Alpaca Meat",
    resource_fish = "Raw Fish", --0.5.1.4
    resource_fish_plural = "Raw Fish", --0.5.1.4
    resource_fishCooked = "Cooked Fish",--0.5.1.4
    resource_fishCooked_plural = "Cooked Fish",--0.5.1.4
    resource_stoneSpear = "Stone Spear",
    resource_stoneSpear_plural = "Stone Spears",
    resource_stoneSpearHead = "Stone Spear Head",
    resource_stoneSpearHead_plural = "Stone Spear Heads",
    resource_stonePickaxe = "Stone Pickaxe",
    resource_stonePickaxe_plural = "Stone Pickaxes",
    resource_stonePickaxeHead = "Stone Pickaxe Head",
    resource_stonePickaxeHead_plural = "Stone Pickaxe Heads",
    resource_stoneHatchet = "Stone Hatchet",
    resource_stoneHatchet_plural = "Stone Hatchets",
    resource_stoneAxeHead = "Hard Stone Axe Head", --0.4 added (Hard), 0.5 changed to Hard x
    resource_stoneAxeHead_plural = "Hard Stone Axe Heads", --0.4 added (Hard), 0.5 changed to Hard x
    resource_stoneAxeHeadSoft = "Soft Stone Axe Head", --0.4, 0.5
    resource_stoneAxeHeadSoft_plural = "Soft Stone Axe Heads", --0.4, 0.5
    resource_stoneAxeHeadGeneric = "Stone Axe Head", --0.5
    resource_stoneAxeHeadGeneric_plural = "Stone Axe Heads", --0.5
    resource_stoneHammerHead = "Stone Hammer Head", --0.4
    resource_stoneHammerHead_plural = "Stone Hammer Heads", --0.4
    resource_stoneHammer = "Stone Hammer", --0.4
    resource_stoneHammer_plural = "Stone Hammers", --0.4
    resource_bronzeHammerHead = "Bronze Hammer Head", --0.4
    resource_bronzeHammerHead_plural = "Bronze Hammer Heads", --0.4
    resource_bronzeHammer = "Bronze Hammer", --0.4
    resource_bronzeHammer_plural = "Bronze Hammers", --0.4
    resource_stoneKnife = "Stone Knife",
    resource_stoneKnife_plural = "Stone Knives",
    resource_stoneChisel = "Stone Chisel", --0.4
    resource_stoneChisel_plural = "Stone Chisels", --0.4
    resource_flintSpear = "Flint Spear",
    resource_flintSpear_plural = "Flint Spears",
    resource_boneSpear = "Bone Spear",
    resource_boneSpear_plural = "Bone Spears",
    resource_bronzeSpear = "Bronze Spear", --0.4
    resource_bronzeSpear_plural = "Bronze Spears", --0.4
    resource_flintPickaxe = "Flint Pickaxe",
    resource_flintPickaxe_plural = "Flint Pickaxes",
    resource_flintHatchet = "Flint Hatchet",
    resource_flintHatchet_plural = "Flint Hatchets",
    resource_flintSpearHead = "Flint Spear Head",
    resource_flintSpearHead_plural = "Flint Spear Heads",
    resource_bronzeSpearHead = "Bronze Spear Head", --0.4
    resource_bronzeSpearHead_plural = "Bronze Spear Heads", --0.4
    resource_boneSpearHead = "Bone Spear Head",
    resource_boneSpearHead_plural = "Bone Spear Heads",
    resource_flintPickaxeHead = "Flint Pickaxe Head",
    resource_flintPickaxeHead_plural = "Flint Pickaxe Heads",
    resource_flintAxeHead = "Flint Axe Head",
    resource_flintAxeHead_plural = "Flint Axe Heads",
    resource_bronzeAxeHead = "Bronze Axe Head", --0.4
    resource_bronzeAxeHead_plural = "Bronze Axe Heads", --0.4
    resource_bronzeHatchet = "Bronze Hatchet", --0.4
    resource_bronzeHatchet_plural = "Bronze Hatchets", --0.4
    resource_bronzePickaxeHead = "Bronze Pickaxe Head", --0.4
    resource_bronzePickaxeHead_plural = "Bronze Pickaxe Heads", --0.4
    resource_bronzePickaxe = "Bronze Pickaxe", --0.4
    resource_bronzePickaxe_plural = "Bronze Pickaxes", --0.4
    resource_flintKnife = "Stone Knife",
    resource_flintKnife_plural = "Stone Knives",
    resource_boneKnife = "Bone Knife",
    resource_boneKnife_plural = "Bone Knives",
    resource_bronzeKnife = "Bronze Knife", --0.4
    resource_bronzeKnife_plural = "Bronze Knives", --0.4
    resource_bronzeChisel = "Bronze Chisel", --0.4
    resource_bronzeChisel_plural = "Bronze Chisels", --0.4
    resource_boneFlute = "Bone Flute",
    resource_boneFlute_plural = "Bone Flutes",
    resource_logDrum = "Log Drum",
    resource_logDrum_plural = "Log Drums",
    resource_balafon = "Balafon",
    resource_balafon_plural = "Balafons",
    resource_woodenPole = "Wooden Pole",
    resource_woodenPole_plural = "Wooden Poles",
    resource_splitLog = "Split Log",
    resource_splitLog_plural = "Split Logs",
    resource_woolskin = "Woolskin",
    resource_woolskin_plural = "Woolskins",
    resource_bone = "Bone",
    resource_bone_plural = "Bones",
    resource_unfiredUrnWet = "Unfired Urn (Wet)",
    resource_unfiredUrnWet_plural = "Unfired Urns (Wet)",
    resource_unfiredUrnDry = "Unfired Urn",
    resource_unfiredUrnDry_plural = "Unfired Urns",
    resource_firedUrn = "Fired Urn",
    resource_firedUrn_plural = "Fired Urns",
    resource_unfiredUrnHulledWheat = "Hulled Wheat (Unfired Urn)",
    resource_unfiredUrnHulledWheat_plural = "Hulled Wheat (Unfired Urn)",
    resource_unfiredUrnHulledWheatRotten = "Moldy Hulled Wheat (Unfired Urn)",
    resource_unfiredUrnHulledWheatRotten_plural = "Moldy Hulled Wheat (Unfired Urn)",
    resource_firedUrnHulledWheat = "Hulled Wheat (Fired Urn)",
    resource_firedUrnHulledWheat_plural = "Hulled Wheat (Fired Urn)",
    resource_firedUrnHulledWheatRotten = "Moldy Hulled Wheat (Fired Urn)",
    resource_firedUrnHulledWheatRotten_plural = "Moldy Hulled Wheat (Fired Urn)",
    resource_quernstone = "Quern-stone",
    resource_quernstone_plural = "Quern-stones",
    resource_unfiredUrnFlour = "Flour (Unfired Urn)",
    resource_unfiredUrnFlour_plural = "Flour (Unfired Urn)",
    resource_unfiredUrnFlourRotten = "Moldy Flour (Unfired Urn)",
    resource_unfiredUrnFlourRotten_plural = "Moldy Flour (Unfired Urn)",
    resource_firedUrnFlour = "Flour (Fired Urn)",
    resource_firedUrnFlour_plural = "Flour (Fired Urn)",
    resource_firedUrnFlourRotten = "Moldy Flour (Fired Urn)",
    resource_firedUrnFlourRotten_plural = "Moldy Flour (Fired Urn)",

    --0.3.0 added group start
    resource_unfiredBowlWet = "Unfired Bowl (Wet)",
    resource_unfiredBowlWet_plural = "Unfired Bowls (Wet)",
    resource_unfiredBowlDry = "Unfired Bowl",
    resource_unfiredBowlDry_plural = "Unfired Bowls",
    resource_firedBowl = "Fired Bowl",
    resource_firedBowl_plural = "Fired Bowls",
    
    resource_unfiredBowlInjuryMedicine = "Injury Medicine",
    resource_unfiredBowlInjuryMedicine_plural = "Injury Medicine",
    resource_unfiredBowlBurnMedicine = "Burn Medicine",
    resource_unfiredBowlBurnMedicine_plural = "Burn Medicine",
    resource_unfiredBowlFoodPoisoningMedicine = "Food Poisoning Medicine",
    resource_unfiredBowlFoodPoisoningMedicine_plural = "Food Poisoning Medicine",
    resource_unfiredBowlVirusMedicine = "Virus Medicine (Unfired Bowl)",
    resource_unfiredBowlVirusMedicine_plural = "Virus Medicine (Unfired Bowls)",
    resource_unfiredBowlMedicineRotten = "Rotten Medicine",
    resource_unfiredBowlMedicineRotten_plural = "Rotten Medicine",
    
    resource_firedBowlInjuryMedicine = "Injury Medicine",
    resource_firedBowlInjuryMedicine_plural = "Injury Medicine",
    resource_firedBowlBurnMedicine = "Burn Medicine",
    resource_firedBowlBurnMedicine_plural = "Burn Medicine",
    resource_firedBowlFoodPoisoningMedicine = "Food Poisoning Medicine",
    resource_firedBowlFoodPoisoningMedicine_plural = "Food Poisoning Medicine",
    resource_firedBowlVirusMedicine = "Virus Medicine",
    resource_firedBowlVirusMedicine_plural = "Virus Medicine",
    resource_firedBowlMedicineRotten = "Rotten Medicine",
    resource_firedBowlMedicineRotten_plural = "Rotten Medicine",
    --0.3.0 group end

    resource_crucibleWet = "Crucible (Wet)", --0.4
    resource_crucibleWet_plural = "Crucibles (Wet)", --0.4
    resource_crucibleDry = "Crucible", --0.4
    resource_crucibleDry_plural = "Crucibles", --0.4

    resource_branch_rotten = "Rotten Branch",
    resource_branch_rotten_plural = "Rotten Branches",
    resource_breadDough = "Bread Dough",
    resource_breadDough_plural = "Bread Dough",
    resource_breadDoughRotten = "Rotten Bread Dough",
    resource_breadDoughRotten_plural = "Rotten Bread Dough",
    resource_flaxTwine = "Flax Twine",
    resource_flaxTwine_plural = "Flax Twine",
    resource_mudBrickWet = "Mud Brick (Wet)",
    resource_mudBrickWet_plural = "Mud Bricks (Wet)",
    resource_mudBrickDry = "Mud Brick (Dry)",
    resource_mudBrickDry_plural = "Mud Bricks (Dry)",
    resource_firedBrick = "Fired Brick",
    resource_firedBrick_plural = "Fired Bricks",
    resource_mudTileWet = "Unfired Tile (Wet)",
    resource_mudTileWet_plural = "Unfired Tiles (Wet)",
    resource_mudTileDry = "Unfired Tile",
    resource_mudTileDry_plural = "Unfired Tiles",
    resource_firedTile = "Tile",
    resource_firedTile_plural = "Tiles",
    resource_bronzeIngot = "Bronze Ingot", --0.4
    resource_bronzeIngot_plural = "Bronze Ingots", --0.4
    resource_mammothMeat = "Raw Mammoth Meat", --0.3.0 added "Raw"
    resource_mammothMeat_plural = "Raw Mammoth Meat", --0.3.0 added "Raw"
    resource_mammothMeatCooked = "Cooked Mammoth Meat",
    resource_mammothMeatCooked_plural = "Cooked Mammoth Meat",

    
    resource_swordfishDead = "Swordfish", --0.6
    resource_swordfishDead_plural = "Swordfish", --0.6

    --resource group
    resource_group_seed = "Seed",
    resource_group_seed_plural = "Seeds",
    resource_group_container = "Large Container", --0.3.0 added "Large"
    resource_group_container_plural = "Large Containers", --0.3.0 added "Large"
    resource_group_bowl = "Bowl", --0.3.0
    resource_group_bowl_plural = "Bowls", --0.3.0
    resource_group_campfireFuel = "Branch/Log/Fuel",
    resource_group_campfireFuel_plural = "Branches/Logs/Fuel",
    resource_group_kilnFuel = "Branch/Log/Fuel",
    resource_group_kilnFuel_plural = "Branches/Logs/Fuel",
    resource_group_torchFuel = "Hay",
    resource_group_torchFuel_plural = "Hay",
    resource_group_brickBinder = "Binder (Hay or Sand)",
    resource_group_brickBinder_plural = "Binder (Hay or Sand)",
    resource_group_urnFlour = "Flour",
    resource_group_urnFlour_plural = "Flour",
    resource_group_urnHulledWheat = "Hulled Wheat",
    resource_group_urnHulledWheat_plural = "Hulled Wheat",

    --0.3.0 group:
    resource_group_injuryMedicine = "Injury Medicine",
    resource_group_injuryMedicine_plural = "Injury Medicine",
    resource_group_burnMedicine = "Burn Medicine",
    resource_group_burnMedicine_plural = "Burn Medicine",
    resource_group_foodPoisoningMedicine = "Food Poisoning Medicine",
    resource_group_foodPoisoningMedicine_plural = "Food Poisoning Medicine",
    resource_group_virusMedicine = "Virus Medicine",
    resource_group_virusMedicine_plural = "Virus Medicine",
    --0.3.0 group end
    
    resource_group_fertilizer = "Manure/Compost", --0.4
    resource_group_fertilizer_plural = "Manure/Compost", --0.4
    resource_group_compostable = "Rotten item", --0.4
    resource_group_compostable_plural = "Rotten items", --0.4

    resource_group_rockSmallAny = "Small Rock", --0.4 
    resource_group_rockSmallAny_plural = "Small Rocks", --0.4
    resource_group_rockAny = "Large Rock", --0.4
    resource_group_rockAny_plural = "Large Rocks", --0.4
    resource_group_stoneBlockAny = "Stone Block", --0.4
    resource_group_stoneBlockAny_plural = "Stone Blocks", --0.4

    --desire
    desire_names_none = "None",
    desire_names_mild = "Mild",
    desire_names_moderate = "Moderate",
    desire_names_strong = "Strong",
    desire_names_severe = "Severe",
    desire_sleepDescriptions_none = "Not Tired",
    desire_sleepDescriptions_mild = "Slightly Tired",
    desire_sleepDescriptions_moderate = "Moderately Tired",
    desire_sleepDescriptions_strong = "Very Tired",
    desire_sleepDescriptions_severe = "Completely Exhausted",
    desire_foodDescriptions_none = "Just Eaten",
    desire_foodDescriptions_mild = "Not Very Hungry",
    desire_foodDescriptions_moderate = "Moderately Hungry",
    desire_foodDescriptions_strong = "Very Hungry",
    desire_foodDescriptions_severe = "Extremely Hungry",
    desire_restDescriptions_none = "Very Well Rested",
    desire_restDescriptions_mild = "Quite Well Rested",
    desire_restDescriptions_moderate = "Wants a Rest",
    desire_restDescriptions_strong = "Overworked",
    desire_restDescriptions_severe = "Severe Fatigue",

    -- mood
    mood_happySad_name = "Happiness",
    mood_happySad_severeNegative = "Extremely Unhappy",
    mood_happySad_moderateNegative = "Sad",
    mood_happySad_mildNegative = "A Little Down",
    mood_happySad_mildPositive = "Positive",
    mood_happySad_moderatePositive = "Happy",
    mood_happySad_severePositive = "Very Happy",
    mood_confidentScared_name = "Confidence",
    mood_confidentScared_severeNegative = "Terrified",
    mood_confidentScared_moderateNegative = "Quite Scared",
    mood_confidentScared_mildNegative = "A Little Worried",
    mood_confidentScared_mildPositive = "Cautiously Confident",
    mood_confidentScared_moderatePositive = "Confident",
    mood_confidentScared_severePositive = "Very Confident",
    mood_loyalty_name = "Tribe Loyalty",
    mood_loyalty_severeNegative = "Leaving Imminently",
    mood_loyalty_moderateNegative = "Quite Annoyed",
    mood_loyalty_mildNegative = "A Little Annoyed",
    mood_loyalty_mildPositive = "Somewhat Loyal",
    mood_loyalty_moderatePositive = "Loyal",
    mood_loyalty_severePositive = "Very Loyal",

    -- statusEffects
    statusEffect_justAte_name = "Just Ate",
    statusEffect_justAte_description = "Ate some food recently",
    statusEffect_goodSleep_name = "Good Sleep",
    statusEffect_goodSleep_description = "Slept in a bed under some cover.",
    statusEffect_learnedSkill_name = "Learned a skill",
    statusEffect_learnedSkill_description = "Learned a new skill recently.",
    statusEffect_wellRested_name = "Well rested",
    statusEffect_wellRested_description = "Just had a nice break from working.",
    statusEffect_hadChild_name = "Had a child",
    statusEffect_hadChild_description = "Had a child recently.",
    statusEffect_optimist_name = "Optimist",
    statusEffect_optimist_description = "Permanent effect caused by the optimist personality trait.",
    statusEffect_minorInjury_name = "Minor injury",
    statusEffect_minorInjury_description = "Just a few cuts and bruises. Should heal on its own but can become infected without treatment.", --0.3.0 modified to add mention of treatment
    statusEffect_majorInjury_name = "Major injury",
    statusEffect_majorInjury_description = "Can move, but can no longer do work. Will heal faster with the right medicine, or could become critical.", --0.3.0 modified to add mention of treatment
    statusEffect_criticalInjury_name = "Critical injury",
    statusEffect_criticalInjury_description = "Life threatening injury. May heal slowly, but without treatment it could lead to death.", --0.3.0 modified to add mention of treatment

    --0.3.0 added group start:
    statusEffect_minorBurn_name = "Minor burn",
    statusEffect_minorBurn_description = "A little painful, but should heal on its own. Can heal faster with the right medicine.",
    statusEffect_majorBurn_name = "Major burn",
    statusEffect_majorBurn_description = "Prevents certain activities. May heal slowly without treatment, or could become critical.",
    statusEffect_criticalBurn_name = "Critical burn",
    statusEffect_criticalBurn_description = "Life threatening burn.",
    statusEffect_minorFoodPoisoning_name = "Minor food poisoning",
    statusEffect_minorFoodPoisoning_description = "Should recover fine, but treat with the right medicine to make sure it doesn't get worse.",
    statusEffect_majorFoodPoisoning_name = "Major food poisoning",
    statusEffect_majorFoodPoisoning_description = "Can no longer work. May recover slowly without treatment, or could become critical.",
    statusEffect_criticalFoodPoisoning_name = "Critical food poisoning",
    statusEffect_criticalFoodPoisoning_description = "Life threatening condition.",
    statusEffect_minorVirus_name = "Minor viral symptoms",
    statusEffect_minorVirus_description = "A little sniffle, should clear on its own, but could become worse or spread to other sapiens without treatment.",
    statusEffect_majorVirus_name = "Major viral infection",
    statusEffect_majorVirus_description = "Prevents certain activities. Could become critical and will spread easily to other sapiens.",
    statusEffect_criticalVirus_name = "Critical viral infection",
    statusEffect_criticalVirus_description = "Extremely infectious. Without treatment, could lead to death.",
    statusEffect_hypothermia_name = "Hypothermia",
    statusEffect_hypothermia_description = "Needs to warm up urgently, or will soon die.",
    
    statusEffect_injuryTreated_name = "Injury treated",
    statusEffect_injuryTreated_description = "The injury has been treated and will now heal faster.",
    statusEffect_burnTreated_name = "Burn treated",
    statusEffect_burnTreated_description = "The burn has been treated and will now heal faster.",
    statusEffect_foodPoisoningTreated_name = "Food poisoning treated",
    statusEffect_foodPoisoningTreated_description = "Starting to feel better.",
    statusEffect_virusTreated_name = "Virus treated",
    statusEffect_virusTreated_description = "Recovering faster thanks to the correct medicine.",
    --0.3.0 group end

    statusEffect_unconscious_name = "Unconscious",
    statusEffect_unconscious_description = "Unable to move.",
    statusEffect_wet_name = "Wet",
    statusEffect_wet_description = "Sapiens don't like being wet, and it will make them feel colder. Let them dry out somewhere warm.",
    statusEffect_wantsMusic_name = "Needs Music",
    statusEffect_wantsMusic_description = "Musical sapiens need to play or hear music now and then, otherwise they will start to feel sad.",
    statusEffect_enjoyedMusic_name = "Enjoyed Music",
    statusEffect_enjoyedMusic_description = "Played or listened to music recently.",
    statusEffect_inDarkness_name = "Dark",
    statusEffect_inDarkness_description = "There is not enough light. Sapiens like to be able to see what they are doing.",

    --negative
    statusEffect_hungry_name = "Hungry",
    statusEffect_hungry_description = "Needs food some time soon.",
    statusEffect_veryHungry_name = "Very Hungry", --0.3.0
    statusEffect_veryHungry_description = "Needs food very soon, or will start to starve.", --0.3.0
    statusEffect_starving_name = "Starving",
    statusEffect_starving_description = "Desperately needs food.",
    statusEffect_sleptOnGround_name = "Slept on the ground",
    statusEffect_sleptOnGround_description = "There were no available beds.",
    statusEffect_sleptOutside_name = "Slept outside",
    statusEffect_sleptOutside_description = "Sapiens like to sleep under cover.",
    statusEffect_tired_name = "Tired",
    statusEffect_tired_description = "Needs a rest.",
    statusEffect_overworked_name = "Overworked",
    statusEffect_overworked_description = "Everyone needs a break now and then.",
    statusEffect_exhausted_name = "Fatigued",
    statusEffect_exhausted_description = "Desperately needs to rest.",
    statusEffect_exhaustedSleep_name = "Exhausted",
    statusEffect_exhaustedSleep_description = "Desperately needs to sleep.",
    statusEffect_acquaintanceDied_name = "Friend died",
    statusEffect_acquaintanceDied_description = "Knew someone who died recently.",
    statusEffect_acquaintanceLeft_name = "Friend Left",
    statusEffect_acquaintanceLeft_description = "Knew someone who left the tribe recently.",
    statusEffect_familyDied_name = "Family member died",
    statusEffect_familyDied_description = "A close relative or friend has died.",
    statusEffect_pessimist_name = "Pessimist",
    statusEffect_pessimist_description = "Permanent effect caused by the pessimist personality trait.",
    statusEffect_cold_name = "Cold",
    statusEffect_cold_description = "Needs to warm up.",
    statusEffect_veryCold_name = "Very Cold",
    statusEffect_veryCold_description = "High risk of developing hypothermia.",
    statusEffect_hot_name = "Hot",
    statusEffect_hot_description = "Needs to cool down.",
    statusEffect_veryHot_name = "Very Hot",
    statusEffect_veryHot_description = "High risk of overheating.",

    --fuel
    fuelGroup_campfire = "Campfire Fuel",
    fuelGroup_kiln = "Kiln Fuel",
    fuelGroup_torch = "Torch Fuel",
    fuelGroup_litObject = "Fuel",

    --recruitChanceOffset
    recruitChanceOffset_veryHard = "Very hard", --0.7
    recruitChanceOffset_hard = "Hard", --0.7
    recruitChanceOffset_easy = "Easy", --0.7
    recruitChanceOffset_veryEasy = "Very Easy", --0.7

    
    banish_areYouSure = function(values)
        return "Are you sure you want to banish " .. values.name .. "?\nThey may take other sapiens with them when they leave."
    end,

    --stats
    stats_birth = "Births",
    stats_birth_description = "Number of births in the previous year", --0.4.3 changed from day to year
    stats_recruit = "Recruitments",
    stats_recruit_description = "Number of sapiens recruited in the previous year", --0.4.3 changed from day to year
    stats_death = "Deaths",
    stats_death_description = "Number of sapiens who died in the previous year", --0.4.3 changed from day to year
    stats_leave = "Leavers",
    stats_leave_description = "Number of sapiens who left the tribe in the previous year", --0.4.3 changed from day to year
    stats_population = "Population",
    stats_population_description = "Total number of sapiens in the tribe",
    stats_populationChild = "Child Population",
    stats_populationChild_description = "Number of children in the tribe",
    stats_populationAdult = "Adult Population",
    stats_populationAdult_description = "Number of adults in the tribe",
    stats_populationElder = "Elder Population",
    stats_populationElder_description = "Number of elders in the tribe",
    stats_populationPregnant = "Pregnant Population",
    stats_populationPregnant_description = "Number of pregnant women in the tribe",
    stats_populationBaby = "Baby Population",
    stats_populationBaby_description = "Number of babies in the tribe",
    stats_averageHappiness = "Average Happiness %",
    stats_averageHappiness_description = "Average percentage happiness across all sapiens in the tribe",
    stats_averageLoyalty = "Average Loyalty %",
    stats_averageLoyalty_description = "Average percentage loyalty across all sapiens in the tribe",
    stats_averageSkill = "Average Skill Count",
    stats_averageSkill_description = "Average number of skills that each sapien has",
    stats_bedCount = "Bed Count",
    stats_bedCount_description = "Number of beds currently available for use by your sapiens",
    stats_foodCount = "Food Count",
    stats_foodCount_description = "Number of food items stored in your storage areas",
    stats_resource_description = function(values)
        return string.format("Number of %s currently stored in your storage areas", values.resourcePlural)
    end,
    stats_currentValue = function(values)
        return string.format("Current: %s", values.currentValue)
    end,

    -- nomadTribeBehavior
    nomadTribeBehavior_foodRaid_name = "Hungry thief", --0.7
    nomadTribeBehavior_friendlyVisit_name = "Visiting (friendly)",
    nomadTribeBehavior_cautiousVisit_name = "Visiting (tourist)", --0.7 modified from cautious
    nomadTribeBehavior_join_name = "Wants to join the tribe",
    nomadTribeBehavior_passThrough_name = "Passing through",
    nomadTribeBehavior_leave_name = "Leaving",
    nomadTribeBehavior_opportunisticThief_name = "Opportunistic thief", --0.7
    nomadTribeBehavior_armedThief_name = "Determined thief", --0.7

    -- manageUI
    manage_build = "Build",
    manage_tribe = "Tribe",
    manage_storageLogistics = "Routes",
    
    -- build ui
    build_ui_build = "Build",
    build_ui_place = "Decorate",
    build_ui_plant = "Plant",
    build_ui_path = "Paths",

    --construct ui
    construct_ui_needsDiscovery = "Investigate items to make a required breakthrough",
    construct_ui_unseenResources = "Find or craft a required item",
    construct_ui_unseenTools = "Find or craft a required tool",
    construct_ui_acceptOnly = "Accept Only",
    construct_ui_requires = "Requires",
    construct_ui_rdisabledInResourcesPanel = "Use of this resource has been disabled in the tribe resources panel",
    construct_ui_discoveryRequired = "Discovery required",
    construct_ui_discoveryRequired_plantsInfo = "To grow plants and trees, your tribe first needs to discover rock knapping, digging and planting.",
    construct_ui_discoveryRequired_pathsInfo = "Paths allow sapiens to move around faster. To build paths, your tribe first needs to discover digging.",

    --storage ui
    storage_ui_acceptOnly = "Accept Only",
    storage_ui_Unlimited = "Unlimited",
    storage_ui_RouteDisabled = "Route Disabled",
    storage_ui_routeName = function(values)
        return string.format("Route %d", values.count)
    end,
    storage_ui_returnToFirstStop = "Return to first stop when done",
    storage_ui_returnToFirstStop_toolTip = "After a sapien drops off items at the final stop, they will walk back to the first stop again.",
    storage_ui_removeRouteWhenComplete = "Remove route when complete",
    storage_ui_removeRouteWhenComplete_toolTip = "Delete this route when there are no longer any stops requiring pick-up.",
    storage_ui_maxSapiens = "Max sapiens",
    storage_ui_clickToAddStops = "Click on storage areas to add stops",
    storage_ui_hit = "Hit",
    storage_ui_whenDone = "When Done",
    --storage_ui_NoDestinations = "No destinations", --deprecated
    
    --resources ui
    resources_ui_allowUse = "Allow use",
    
    -- tribe ui
    tribe_ui_tribe = "Sapiens",
    tribe_ui_roles = "Roles",
    tribe_ui_stats = "Stats",
    tribe_ui_resources = "Resources",
    tribe_ui_notifications = "Events", --0.5



    --settings ui
    settings_options = "Settings",
    settings_exit = "Exit",
    --settings_header = "Settings: General", --deprecated 0.5
    settings_general = "General",
    settings_graphics = "Graphics",
    settings_world = "World", --0.5
    settings_notifications = "Notifications", --0.7
    settings_KeyBindings = "Key Bindings",
    settings_Debug = "Debug",
    settings_Exit = "Exit",
    settings_language = "Language",
    settings_language_tip = "Install more languages from Steam Workshop via the 'Mods' panel in the main menu",
    settings_Controls = "Controls",
    settings_Controls_mouseSensitivity = "Mouse Look Sensitivity",
    settings_Controls_invertMouseLookY = "Invert Mouse Look Vertical",
    settings_Controls_invertMouseLookX = "Horizontal",
    settings_Controls_invertMouseWheelZoom = "Invert Mouse Wheel Zoom", --b20
    settings_Controls_controllerLookSensitivity = "Controller Look Sensitivity",
    settings_Controls_controllerZoomSensitivity = "Controller Zoom Sensitivity", --0.4
    settings_Controls_mouseZoomSensitivity = "Mouse Zoom Sensitivity", --0.5.1.1
    settings_Controls_invertControllerLookY = "Invert Controller Look Y",
    settings_Controls_enableDoubleTapForFastMovement = "Double Tap Fast Movement",
    settings_Controls_reticle = "Reticle", --0.4 - refers to the pointer/crosshairs image setting
    settings_Controls_reticleSize = "Reticle Size", --0.4
    settings_Controls_reticleType_dot = "Dot", --0.4
    settings_Controls_reticleType_bullseye = "Bullseye", --0.4
    settings_Controls_reticleType_crosshairs = "Crosshairs", --0.4

    settings_Controls_cameraControlType = "Camera Control Type", --0.5.1 -- this is the title for the pop up button in the options menu to select point and click mode
    settings_Controls_cameraControlType_firstPerson3D = "First person 3D", --0.5.1
    settings_Controls_cameraControlType_pointAndClick = "Point and click", --0.5.1
    
    settings_Audio = "Audio",
    settings_Audio_MusicVolume = "Music Volume",
    settings_Audio_SoundVolume = "Sound Volume",
    settings_Other = "Other",
    settings_allowLanConnections = "Allow Multiplayer LAN Connections",
    settings_chatNotifications = "Chat Notifications", --0.6
    settings_chatNotifications_messagesOnly = "Messages Only", --0.6 title in pull down menu to only show notifications for chat messages, not joins/disconnects
    settings_pauseOnLostFocus = "Pause when app loses focus", --b19
    settings_pauseOnInactivity = "Pause after inactivity", --0.4
    settings_enableTutorialForThisWorld = "Tutorial", --0.5 modified, removed "Enable tutorial for this world", as it has its own section for world settings now
    settings_enableTutorialForNewWorlds = "Enable tutorial for new worlds",
    settings_GeneralGraphics = "General Graphics",
    settings_graphics_brightness = "Brightness",
    settings_graphics_desktop = "Desktop",
    settings_graphics_Multi = "Multi",
    settings_graphics_Resolution = "Resolution",
    settings_graphics_Display = "Display",
    settings_graphics_window = "Window",
    settings_graphics_Borderless = "Borderless",
    settings_graphics_FullScreen = "Full Screen",
    settings_graphics_Relaunch = "Relaunch",
    settings_graphics_VSync = "VSync",
    settings_graphics_FOV = "FOV",
    settings_graphics_terrainContours = "Terrain Contours", --0.5.1.2 controls opacity of contour lines that are rendered on the terrain
    settings_Performance = "Performance",
    settings_Performance_RenderDistance = "Render Distance",
    settings_Performance_GrassDistance = "Grass Distance",
    settings_Performance_grassDensity = "Grass Density",
    settings_Performance_animatedObjectsCount = "Maximum Animated Objects",
    settings_Performance_ssao = "Ambient Occlusion",
    settings_Performance_highQualityWater = "High Quality Water Reflections", --0.3.0
    settings_Performance_bloomEnabled = "Bloom", --0.3.0
    settings_Debug_display = "Debug Display",
    settings_Debug_Cloud = "Cloud",
    settings_Debug_setSunrise = "Set Sunrise",
    settings_Debug_setMidday = "Set Midday",
    settings_Debug_setSunset = "Set Sunset",
    settings_Debug_startLockCamera = "Lock Camera",
    settings_Debug_startServerProfile = "Profile Server",
    settings_Debug_startLogicProfile = "Profile Logic Thread",
    settings_Debug_startMainThreadProfile = "Profile Main Thread",
    settings_Debug_toggleAnchorMarkers = "Toggle Anchor Markers", --0.5
    settings_exitAreYouSure = "Are you sure you want to exit Sapiens?",
    settings_exitAreYouSure_info = "The game is saved constantly while you play.",
    settings_exitMainMenu = "Exit To Main Menu",
    settings_exitDesktop = "Exit To Desktop",

    settings_exit_hibernate = "Hibernate", --0.5 -- when using exit from the settings menu, but only in multiplayer
    settings_exit_hibernate_helpInfoText = "Sets how long your tribe will stay loaded for if you are playing multiplayer and the world keeps running, or if you load this same world with a different tribe.", --0.7
    settings_exit_hibernate_now = "Now", -- 0.5
    settings_exit_hibernate_oneDay = "One Day", -- 0.5
    settings_exit_hibernate_twoDays = "Two Days", -- 0.5

    settings_inviteFriends = "Invite Steam Friends...", --0.5 in general settings, to invite Steam friends to play multiplayer in your current world
    settings_inviteFriendsButton_tip = "Opens the Steam overlay, allowing you to invite your friends and play multiplayer.", --0.5 from the pause menu when in-game
    settings_inviteFriendsButton_tip_no_world = "First load a world, then you can invite your friends and play multiplayer.", --0.5 when there is no world yet loaded, we are in the main menu and the button is disabled

    worldSettings_tribeSpawns = "Settle villages nearby", -- 0.5
    worldSettings_tribeSpawns_tip = "Spawn new AI villages near your tribes over time, and when others join in multiplayer", -- 0.5

    worldSettings_gameDifficulty = "Game Difficulty Mode", -- 0.7
    worldSettings_gameDifficulty_normal = "Normal", -- 0.7
    worldSettings_gameDifficulty_peaceful = "Peaceful", -- 0.7
    
    worldSettings_populationCap = "Population Cap", -- 0.7
    worldSettings_populationCap_tip = "Above this population per tribe, no new pregnancies will occur", -- 0.5


    --stats ui
    ui_stats_days_ago = function(values)
        return string.format("%d Days ago", values.dayCount)
    end,
    ui_stats_now = "Now",

    --roles ui
    ui_roles_allowed = "Assigned",
    ui_roles_disallowed = "Not Assigned",

    ui_roles_assignAutomatically = "Assign Roles Automatically", --0.5
    ui_roles_assignAutomatically_toolTip = "If checked, idle sapiens will be assigned the required role when no one else is available", --0.5

    -- resources ui
    ui_resources_allResourceType = function(values)
        return string.format("All %s", values.resourceName)
    end,
    ui_resources_storedCount = function(values)
        return string.format("Stored: %s", values.storedCount) --0.5 updated from "%s stored" for readibility
    end,
    ui_resources_decorations = "Place Decoration",
    ui_resources_eating = "Eating",
    ui_resources_tool = "Tool or Weapon", --b13
    ui_resources_medicine = "Medicine", --0.3.0
    ui_resources_clothing = "Clothing", --0.6

    -- look at ui
    lookatUI_needs = "Needs",
    lookatUI_missingStorage = "No matching or empty storage area nearby",
    lookatUI_missingCraftArea = "No available craft area nearby", --0.3.0 added "available"
    lookatUI_missingCampfire = "No available lit campfire nearby", --0.3.0 added "available"
    lookatUI_missingKiln = "No available lit kiln nearby", --0.3.0 added "available"
    lookatUI_missingStorageAreaContainedObjects = "No suitable items stored here",
    lookatUI_missingTaskAssignment = function(values)
        return "No capable sapiens are assigned the \"" .. values.taskName .. "\" role"
    end,
    lookatUI_needsTools = function(values)-- b16
        local planInfoString = "Needs "
        for i,missingToolInfo in ipairs(values.missingToolInfos) do
            planInfoString = planInfoString .. missingToolInfo.toolName
            if missingToolInfo.exampleObjectName and missingToolInfo.exampleObjectName ~= missingToolInfo.toolName then --0.4 modified to only add example if it is present and different.
                planInfoString = planInfoString .. " (eg. " .. missingToolInfo.exampleObjectName .. ")"
            end
            if i ~= #values.missingToolInfos then
                planInfoString = planInfoString .. ", "
            end
        end
        return planInfoString
    end,
    lookatUI_needsResources = function(values)-- b16
        local planInfoString = "Needs "
        for i,missingResourceString in ipairs(values.missingResources) do
            planInfoString = planInfoString .. missingResourceString
            if i ~= #values.missingResources then
                planInfoString = planInfoString .. ", "
            end
        end
        return planInfoString
    end,
    lookatUI_inaccessible = "Too difficult to get to",
    lookatUI_terrainTooSteepFill = "Filling this would create a slope that is too steep",
    lookatUI_invalidUnderWater = "Needs access from dry land",
    lookatUI_terrainTooSteepDig = "Digging this would create a slope that is too steep",
    lookatUI_needsLit = "Needs to be lit first",
    lookatUI_disabledDueToOrderLimit = "Maximum orders reached",
    lookatUI_tooDark = "Not enough light. Add torches or wait until day time",
    lookatUI_tooDistant = "No capable sapiens nearby with the required role assigned",
    lookatUI_tooDistantWithRoleName = function(values)
        return "No capable sapiens nearby with the \"" .. values.taskName .. "\" role"
    end,
    lookatUI_tooDistantRequiresCapable = function(values)
        return "No capable sapiens nearby with the \"" .. values.taskName .. "\" role (Requires heavy lifting)"
    end,
    lookatUI_missingSuitableTerrain = "No available terrain of the required type nearby", --0.4
    lookatUI_maintainQuantityThresholdMet = function(values) --0.5
        return "Maintain quantity reached: " .. values.storedCount .. "/" .. values.maintainCount .. " " .. values.resourcePlural
    end,
    lookatUI_maintainQuantityThresholdMetNoData = "Maintain quantity reached", -- 0.5
    lookatUI_maintainQuantityInProgress = function(values) --0.5
        return values.actionInProgressName .. " to maintain " .. values.maintainCount .. " " .. values.resourcePlural .. ": " .. values.storedCount .. "/" .. values.maintainCount
    end,
    lookatUI_missingShallowWater = "No shallow water near by", --0.5.1

    lookatUI_closeThreat = "Threat is too close", --0.7 when a threatening sapien eg raider is close to most plans, they cannot be completed and display this
    
    
    sapien_ui_roles = "Roles",
    sapien_ui_inventory = "Inventory",
    sapien_ui_relationships = "Family",

    -- ui actions    
    ui_action_chooseTribe = "Lead this tribe",
    ui_action_resumeTribe = "Continue this tribe", --0.5, from the map view, for tribes you have already played
    ui_action_place = "Place",
    ui_action_plant = "Plant",
    ui_action_build = "Build",
    ui_action_craft = "Craft",
    ui_action_continue = "Continue",
    ui_action_craft_continuous = "Craft Continuously",
    ui_action_assign = "Assign",
    ui_action_cancel = "Cancel",
    ui_action_cancelling = "Cancelling",
    ui_action_retry = "Retry", --0.5 when you are disconnected from a server in multiplayer, you can use the "Retry" button to attempt to connect again
    ui_action_stop = "Stop",
    ui_action_next = "Next",
    ui_action_choose = "Choose",
    ui_action_set = "Set",
    ui_action_zoom = "Zoom",
    ui_action_remove = "Remove",
    ui_action_manageRoles = "Manage Roles",
    ui_action_disallowAll = "Unassign All",
    ui_action_allowAll = "Assign All",
    ui_action_allow = "Assign",
    ui_action_disallow = "Unassign",
    ui_action_selectMore = "Select More",
    ui_action_select = "Select",
    ui_action_deselect = "Deselect", --0.5 in multiselect ui, in box selection mode
    ui_action_boxSelect = "Box Select",
    ui_action_radiusSelect = "Radius Select",
    ui_action_editName = "Rename",
    ui_action_inspectRoute = "Inspect Route",
    ui_action_assignDifferentSapien = "Assign Different Sapien",
    ui_action_assignSapien = "Assign Sapien",
    ui_action_prioritize = "Prioritize",
    ui_action_deprioritize = "Deprioritize", --0.4.2
    ui_action_manageSapien = function(values)
        return "Manage " .. values.name
    end,
    ui_action_join = "Join",
    ui_action_createWorld = "Create World",
    ui_action_credits = "Credits",
    ui_action_exit = "Exit",
    ui_action_reportBug = "Report Bug",
    ui_action_importReports = "Import Reports",
    ui_action_wishlist = "Add to your wishlist",
    ui_action_wishlistNow = "Wishlist now!",
    ui_action_sendFeedback = "Send Feedback",
    ui_action_apply = "Apply",
    ui_action_dontShowAgain = "Don't show this again",
    ui_action_attemptToPlayAnyway = "Attempt to play anyway",
    ui_action_setFillType = "Set Fill Type",
    ui_action_update = "Update", --b20
    ui_action_OK = "OK", --b20
    ui_action_filter = "Filter", --0.5
    ui_action_maybeLater = "Maybe Later", --0.5 used on a button when a tribe has a quest to dismiss the UI, however the quest remains available for later
    ui_action_acceptQuest = "Accept Quest", --0.5
    ui_action_acceptDelivery = "Accept Delivery", --0.5
    ui_action_multiplayer = "Multiplayer", --0.5 button on main menu
    ui_action_buy = "Buy", --0.5 on button for purchasing in trade offers

    ui_action_enable = "Enable", -- 0.5 when enabling routes in storage area panel
    ui_action_disable = "Disable", -- 0.5 when enabling routes in storage area panel
    
    ui_action_craftX = function(values) --0.5
        return "Craft " .. values.countText
    end,
    ui_action_maintainX = function(values) --0.5
        return "Maintain " .. values.countText
    end,

    ui_maintainToolTip = "Crafting will start when the number of resources nearby drops below the set amount", --0.5

    --ui plans
    ui_plan_unavailable_stopOrders = "Cancel other orders first",
    ui_plan_unavailable_multiSelect = "Too many selected",
    ui_plan_unavailable_missingKnowledge = "Missing Knowledge",
    ui_plan_unavailable_investigatedElsewhere = "Being investigated elsewhere",
    ui_plan_unavailable_extinguishFirst = "Extinguish first",
    ui_plan_unavailable_alreadyTreated = "Already Treated", --0.3.0, for medicinal tasks, treatment has already been given
    ui_plan_unavailable_tribeSettingsDontAllowUse = "Allow item use first", --0.5 either the "Allow Use" checkbox is unchecked, or tribe settings disallow use, tool tip in action UI
    ui_plan_unavailable_recruitBanishTimeout = "Won't talk", --0.7
    

    -- ui buildMode
    ui_buildMode_fail_needsAttachment = "Needs to attach to something",
    ui_buildMode_fail_collidesWithObjects = "Collides with something",
    ui_buildMode_fail_tooSteep = "Slope is too steep",
    ui_buildMode_fail_underwater = "Can't build under water",
    ui_buildMode_plantFail_tooDistant = "Too far away",
    ui_buildMode_plantFail_notTerrain = "Needs to be planted in the ground",
    ui_buildMode_plantFail_badMedium = function(values)
        return "Cannot be planted in " .. values.terrainName
    end,
    ui_buildMode_fail_belowTerrain = "Can't build below terrain",
    fill_summary = function(values)
        if values.requiredResourceCount > 1 then
            return string.format("Fill the terrain with %d %s", values.requiredResourceCount, values.resourceTypeNamePlural)
        else
            return "Fill the terrain with " .. values.resourceTypeNamePlural
        end
    end,
    ui_cantDoTasks = function(values)
        if values.pregnant then
            return "Can't do these tasks due to pregnancy."
        elseif values.hasBaby then
            return "Can't do these tasks while carrying a baby."
        elseif values.child then
            return "Children can't do these tasks."
        elseif values.elder then
            return "Elders can't do these tasks."
        elseif values.maxAssigned then
            return "Maximum roles assigned"
        end
        return "Can't do tasks due to limited ability."
    end,
    ui_partiallyCantDoTasks = function(values)
        if values.pregnant then
            return "Some of these tasks can't be done due to pregnancy."
        elseif values.hasBaby then
            return "Some of these tasks can't be done while carrying a baby."
        elseif values.child then
            return "Children can't do some of these tasks."
        elseif values.elder then
            return "Elders can't do some of these tasks."
        end
        return "Some of these tasks can't be done due to limited ability."
    end,
    ui_cantDoTasksShort = function(values)
        if values.pregnant then
            return "Pregnant"
        elseif values.hasBaby then
            return "Carrying baby"
        elseif values.child then
            return "Child"
        elseif values.elder then
            return "Elder"
        elseif values.maxAssigned then
            return "Max assigned"
        end
        return "Limited ability"
    end,
    ui_missingTaskAssignment = function(values)
        return "Not assigned the \"" .. values.taskName .. "\" role"
    end,
    ui_portionCount = function(values)
        if values.portionCount == 1 then
            return string.format("1 portion")
        else
            return string.format("%d portions", values.portionCount)
        end
    end,
    ui_notInYourTribe = "Not a member of your tribe", --0.5 displayed in changeAssignedSapienUI when you look at a visiting sapien that has not been recruited
    ui_tooTiredToWork = "Too tired to work", --0.5 displayed in changeAssignedSapienUI when sapien is too tired to work
    ui_slowConnection = "Connection Issues", --0.5 tool tip when hovering over connection alert icon near the time controls. Displayed if there is a bad connection with the server

    -- ui names
    ui_name_traits = "Traits",
    ui_name_skillFocus = "Skill Focus",
    ui_name_relationships = "Family",
    ui_name_tasks = "Roles",
    ui_name_move = "Move",
    ui_name_moveAndWait = "Move & Wait",
    ui_moveObject = function(values) --0.5 displayed at top of screen when moving a draggable object like a sled
        return "Move " .. values.objectName
    end,
    ui_name_assignBed = "Assign Bed", --b20
    ui_name_mapMode = "World Map",
    ui_name_changeAssignedSapien = "Select a Sapien to Assign",
    ui_name_tutorial = "Tutorial",
    ui_name_terrain = "Terrain",
    ui_name_craftCount = "Craft Count",
    ui_name_ipAddress = "IP Address/Host",
    ui_name_port = "UDP Port", --0.5 added "UDP", removed default info
    ui_name_notApplicable = "N/A",
    ui_name_today = "Today",
    ui_name_yesterday = "Yesterday",
    ui_daysAgo = function(values)
        return string.format("%d days ago", values.count)
    end,
    ui_name_lastPlayed = "Last Played",
    ui_name_created = "Created",
    ui_name_lastPlayedVersion = "Last Played Version",
    ui_name_worldAge = "World Age (game days)", --b20
    ui_name_seed = "Seed",
    ui_name_manage = "Manage", --b20
    ui_name_manageWorld = "Manage World", --0.5 replaces ui_name_manage in saves panel in main menu
    ui_name_saves = "Saves",
    ui_name_load = "Load",
    ui_name_tribes = "Tribes",
    ui_name_startNewTribe = "Select New Tribe", --0.5 new button in load menu, loads world map, where you can start a new tribe or select an existing one
    ui_name_deleteWorld = "Delete World",
    ui_name_changeMods = "Change Mods", --b20
    ui_name_updateMod = "Update Mod", --b20
    ui_name_steamOverlayDisabled = "Requires Steam Overlay", --b20
    ui_name_quest = "Quest", --0.5
    ui_name_activeQuest = "Active Quest", --0.5
    ui_name_availableQuest = "Available Quest", --0.5
    ui_name_completedQuest = "Completed Quest", --0.5
    ui_name_failedQuest = "Failed Quest", --0.5
    ui_name_trade_offers = "Trade Offers", --0.5
    ui_name_trade_requests = "Trade Requests", --0.5
    ui_name_trade_settings = "Tribe Settings", --0.5 (not "trade settings", these settings apply to the tribe as a whole, not just trade)
    ui_name_favor = "Favor", --0.5 this might be tricky to translate, broadly it is a representation of trust and respect, a kind of social debt/currency. 
    ui_name_joinMultiplayer = "Join Multiplayer", --0.5 title for multiplayer panel in main menu
    ui_name_world = "World", --0.5 used in load menu
    ui_name_previous = "Previous Connections", --0.5 in Multiplayer menu, title for previous connections
    ui_name_request = "Request", --0.5 hovering over trade request storage area
    ui_name_offer = "Offer", --0.5 hovering over trade offer storage area
    ui_name_purchased = "Purchased", -- hovering over trade offer storage area eg. "Offer: 45 Stone Axe Heads - Purchased:40"
    ui_name_delivered = "Delivered", -- hovering over trade request storage area eg. "Request: 45 Stone Axe Heads - Delivered:40"
    ui_name_chat = "Chat", --0.5 displayed in the chat message ui [t]

    ui_name_connected = "Connected", --0.5 displayed in the chat message ui when players connect
    ui_name_disconnected = "Disconnected", --0.5 displayed in the chat message ui when players disconnect
    ui_name_hibernated = "Tribe hibernated", --0.5 displayed in the chat message ui when players hibernate

    ui_info_noOtherPlayers = "(no other players)", --0.5 displayed in the chat message ui when no other players are connected
    ui_info_singleOtherPlayer = "(1 other player)", --0.5 displayed in the chat message ui when one other player is connected
    ui_info_multipleOtherPlayers = function(values) --0.5 displayed in the chat message ui when multiple other players are connected
        return string.format("(%d other players)", values.playerCount)
    end,

    ui_name_serverName = "Server Name", --0.5 displayed as table header title in multiplayer main menu
    ui_name_playersOnline = "Players Online", --0.5 displayed as table header title in multiplayer main menu

    -- ui infos
    ui_info_deleteWorldAreYouSure = function(values)
        return string.format("Are you sure you want to delete the world %s? This cannot be undone, the game save will be gone forever.", values.worldName)
    end,    
    ui_info_bindingPopUpViewInstructions = "Press and release the keys to assign to this binding.",
    ui_info_bindingTimeRemaining = function(values)
        return string.format("Reverts in %d seconds...", values.seconds)
    end,
    ui_info_changeModAreYouSure = "Are you sure you want to change the mods for this world?\n\nThis can cause the world to fail to load, so you should backup a copy of the world's directory first.", --b20
    ui_info_updateModAreYouSure = function(values) --b20
        return string.format("Are you sure you want to update the mod %s?\n\nThis cannot be undone and can cause the world to fail to load.\n\nIt will copy the latest version (%s) of the mod into this world's directory, overwriting the old version (%s).\n\nYou should backup a copy of the world's directory first.", values.modName, values.newVersion, values.oldVersion)
    end,  
    ui_info_steamOverlayDisabled = "This feature requires the Steam Overlay.\n\nYou can enable the Steam Overlay from within the Steam app, either for all games, or just for Sapiens.", --b20

    ui_info_joinMultiplayerDescription = "This is a list of public servers which are hosted by other players.\n\nThere are dedicated server binaries available for Windows and Linux, and you can also open any single player game up for LAN connections via the pause menu. If you are hosting and need to open up ports on your firewall for external connections, the default UDP port is 16161, and you will need to open 16162 for Steam and 16168 for HTTP connections too. For the latest information, please join the Discord.", --0.5 in multiplayer join main menu


    ui_pause = "Pause",
    ui_play = "Play",
    ui_fastForward = "Fast Forward",

    ui_fastForwardDisabledDueToServerLoad = "Fast forward is disabled due to high server load", --0.5

    ui_objectBelongingToSapien = function(values) --b20
        return string.format("%s's %s", values.sapienName, values.objectName)
    end,  

    tribeUI_sapien = "Sapien",
    tribeUI_distance = "Dist.",
    tribeUI_age = "Age",
    tribeUI_happiness = "Happy",
    tribeUI_loyalty = "Loyalty",
    tribeUI_effects = "Effects",
    tribeUI_roles = "Roles",
    tribeUI_skills = "Skills",
    tribeUI_population = "Population",

    ui_questSummary = function(values) --0.5 used for markers and UI when looking at a quest object
        return "Deliver " .. values.count .. " " .. values.resourcePlural
    end,

    ui_questSummaryWithDeliveredCount = function(values) --0.5
        return "Deliver " .. values.count .. " " .. values.resourcePlural .. " (" .. values.deliveredCount .. "/" .. values.count .. ")"
    end,

    --misc
    misc_no_summary_available = "No summary available",
    misc_missing_name = "No Name",
    misc_none_assigned = "None Assigned",
    misc_place_object_summary = "Place anywhere in the world for decoration purposes.",
    misc_undiscovered = "Undiscovered",
    misc_dry = "Dry",
    misc_newBreakthrough = "New Breakthrough!",
    misc_unlocks = "Unlocked", --0.3.0 changed from "Unlocks"
    misc_pregnant = "Pregnant",
    misc_carryingBaby = "Carrying Baby",
    misc_unnamed = "Unnamed",
    misc_inside = "inside",
    misc_outside = "outside",
    misc_acceptAll = "Accept All",
    misc_uncheckDestroyFirst = "Can't accept all with Destroy All Items",
    misc_acceptNone = "Accept None",
    misc_route = "Route",
    misc_items = "Items",
    misc_specialOrders = "Special Orders",
    misc_allowItemUse = "Allow Item Use",
    misc_itemUseNotAllowed = "Item Use Not Allowed",
    misc_removeAllItems = "Remove All Items",
    misc_destroyAllItems = "Destroy All Items",
    misc_routes = "Routes",
    misc_addStops = "Add Stops",
    misc_addNewRoute = "Add New Route",
    misc_addNewRouteStartingHere = "Add Route From Here", --0.5
    misc_sendingItems = "Sending Items To", -- 0.5 in storage area management panel
    misc_receivingItems = "Receiving Items From", -- 0.5 in storage area management panel
    misc_sendItems = "Send Items", -- 0.5 in storage area management panel
    misc_receiveItems = "Receive Items", -- 0.5 in storage area management panel
    misc_selectRouteFromTitle = "Select the source", --0.5 when connecting storage areas via the above
    misc_selectRouteToTitle = "Select the destination", --0.5 when connecting storage areas via the above
    misc_selectRouteFrom = "Select the storage to recieve the items from", --0.5 when connecting storage areas via the above
    misc_selectRouteTo = "Select the storage to send the items to", --0.5 when connecting storage areas via the above
    misc_setFillType = "Set Fill Type",
    misc_debug = "Debug",
    misc_cheat = "Cheat",
    misc_fmodCredit = "For audio, Sapiens Uses FMOD Studio by Firelight Technologies Pty Ltd.",
    misc_version = "Version",
    misc_demo = "Demo",
    misc_forums = "Sapiens Forums",
    misc_discord = "Sapiens Discord",
    --misc_twitter = "Sapiens on Twitter", --deprecated 0.5
    misc_reddit = "Sapiens on Reddit", --0.5 tool tip on reddit button on main menu
    misc_serverNotFound = "Couldn't find server",
    misc_serverNotFound_info = "The server may be offline or unreachable",
    misc_publicServerList = "Public Server List", --0.5 main menu multiplayer screen
    misc_connectionLost = "Connection Lost",
    misc_connectionLost_info = "The connection to the server was lost",
    misc_random = "Random",
    misc_randomVariation = "Random variation",
    misc_variations = "Variations",
    misc_skilled = "Skilled",
    misc_noSelection = "No Selection",
    misc_unavailable = "Unavailable",
    misc_elsewhere = "Elsewhere",
    misc_cantDoPlan = function(values)
        return string.format("Can't %s", values.planName)
    end,
    
    misc_settings = "Settings",
    misc_continuous = "Continuous",
    misc_Empty = "Empty",
    misc_Unknown = "Unknown",
    misc_Rebinding = "Rebinding",
    misc_NotLoaded = "Not loaded",
    misc_Toggle = "Toggle",
    misc_Biome = "Biome",
    misc_BiomeDifficulty = "Location Difficulty", --b20
    misc_BiomeDifficulty_veryEasy = "Very Easy", --b20
    misc_BiomeDifficulty_easy = "Easy", --b20
    misc_BiomeDifficulty_normal = "Normal", --b20
    misc_BiomeDifficulty_hard = "Hard", --b20
    misc_BiomeDifficulty_veryHard = "Very Hard", --b20
    misc_WIP_Panel = "This panel is not ready yet, Coming soon!",
    misc_decorate_with = function(values)--b13
        return string.format("Decorate With %s", values.name)
    end,

    misc_compostNotEnoughMaterialStored = "Not enough material stored, add more rotten items", --0.4
    misc_compostNextInLessThanAnHour = "Next compost ready in < 1 hour", --0.4
    misc_compostNextInXHours = function(values) --0.4
        return string.format("Next compost ready in %d hours", values.hours)
    end,
    misc_compostPreviousWasLessThanAnHour = "Last compost produced < 1 hour ago", --0.4
    misc_compostPreviousWasXHours = function(values) --0.4
        return string.format("Last compost produced %d hours ago", values.hours)
    end,
    
    misc_disabled = "Disabled", --0.4
    misc_enabled = "Enabled", --0.6 used in settings menu -> chat notifications pop up menu
    misc_maxQuantity = "Max Quantity", --0.4
    misc_max = "Max", --0.4

    
    misc_needsLargerStorageArea = "Needs larger storage area", --0.5 this is displayed for large items like logs in the "Accept Only" popup button in a small storage area
    misc_tribeName = function(values) --0.5 displayed on tribe selection. No longer actually adds anything, but could be used to display things like "The tribeName Tribe"
        return values.tribeName
    end,
    misc_tribeNameFormal = function(values) --0.5 displayed as title on greeting panel
        return "The " .. values.tribeName
    end,
    misc_tribeLedBy = function(values) --0.5 displayed when selecting a tribe to lead, inspecting a tribe owned by another player
        return "Led by " .. values.playerName
    end,
    misc_aiTribe = "AI Tribe", --0.5 displayed when selecting a tribe to lead but it has been loaded up as an AI tribe and can no longer be led

    misc_expires = "Expires", --in tribe relationship UI, under quest title
    misc_timeRemaining = "Time remaining", --in tribe relationship UI, under quest title, when quest is assigned
    misc_timeUntilNextQuest = "Next quest", --in tribe relationship UI, under quest title, when quest is failed or complete

    misc_active = "Active", --0.5
    misc_hibernating = "Hibernating", --0.5

    misc_hex = "Hex", --0.5 displayed when using multiselect on multiple types of terrain
    misc_hexes = "Hexes", --0.5 displayed when using multiselect on multiple types of terrain

    misc_selectionTool = "Selection Tool", --0.5 in multiselect UI

    misc_destructive = "Destructive", -- 0.7 tool tip in radial menu for chop/remove/attack/hunt plans that destroy the object
    misc_paused = "Paused", -- 0.7 title text displayed when game is paused

    -- multiplayer server responses, new in 0.5
    serverRejectionTitle_bad_player_name_or_id = "Connection error: Bad player name", --0.5
    serverRejectionMessage_bad_player_name_or_id = "Please check your player alias is not too long or too short.", --0.5

    serverRejectionTitle_client_too_old = "Connection error: Please update Sapiens", --0.5
    serverRejectionMessage_client_too_old = function(values) --0.5
        return "The server requires a newer Sapiens version: " .. values.requiredVersion .. ".\nYour version is: " .. values.localVersion
    end,

    serverRejectionTitle_client_too_new = "Connection error: Please update the server", --0.5
    serverRejectionMessage_client_too_new = function(values) --0.5
        return "The server is running an older Sapiens version: " .. values.requiredVersion .. ".\nYour version is: " .. values.localVersion
    end,

    serverRejectionTitle_steam_authentication_failed = "Unable to authenticate with Steam", --0.5
    serverRejectionMessage_steam_authentication_failed = "Something went wrong trying to authenticate the Steam user. Please ensure you are not logged in elsewhere, and try again later.", --0.5

    serverRejectionTitle_server_authentication_failed = "Server not accepting join request", --0.5
    serverRejectionMessage_server_authentication_failed = "The server may be restricting connections, or you may have been banned from connecting.", --0.5

    serverRejectionTitle_generic = "Connection error", --0.5
    serverRejectionMessage_generic = function(values) --0.5
        return "The server has rejected your request to join. reason:" .. values.rejectionReason .. " context:" .. values.rejectionContext
    end,

    --loading
    loading_connecting = "Connecting to server",
    loading_connected = "Connected to server",
    --loading_loadingShaders = "Loading shaders", --0.5 DEPRECATED
    --loading_waiting = "Waiting for server", --0.5 DEPRECATED
    --loading_generating = "Generating World", --0.5 DEPRECATED
    loading_world = "Loading World",
    loading_downloadingData = "Downloading world data/mods",
    loading_downloading = "Downloading",
    loading_loading = "Loading",

    -- lifeStages
    lifeStages_child = "Child",
    lifeStages_adult = "Adult",
    lifeStages_elder = "Elder",

    --sapienTrait
    sapienTrait_charismatic = "Charismatic",
    sapienTrait_charismatic_opposite = "Dull", --0.7
    sapienTrait_loyal = "Loyal",
    sapienTrait_loyal_opposite = "Disloyal", --0.7
    sapienTrait_courageous = "Courageous",
    sapienTrait_courageous_opposite = "Fearful",
    sapienTrait_strong = "Strong",
    sapienTrait_focused = "Focused",
    sapienTrait_logical = "Logical",
    sapienTrait_creative = "Creative",
    sapienTrait_clever = "Fast Learner",
    sapienTrait_clever_opposite = "Slow Learner",
    sapienTrait_lazy = "Lazy",
    sapienTrait_lazy_opposite = "Energetic",
    sapienTrait_longSleeper = "Long Sleeper",
    sapienTrait_longSleeper_opposite = "Early Riser",
    sapienTrait_glutton = "Glutton",
    sapienTrait_glutton_opposite = "Small Eater",
    sapienTrait_optimist = "Optimist",
    sapienTrait_optimist_opposite = "Pessimist",
    sapienTrait_musical = "Musical",
    sapienTrait_musical_opposite = "Tone Deaf",
    sapienTrait_immune = "Strong Immunity", --0.3.0
    sapienTrait_immune_opposite = "Weak Immunity", --0.3.0

    --skill
    skill_gathering = "General Labor",
    skill_gathering_description = "Haul items, clear grasses, and harvest resources from plants and trees.",
    skill_basicBuilding = "Basic Building",
    skill_basicBuilding_description = "Build basic items like beds and craft/storage areas, and place objects.",
    skill_woodBuilding = "Wood Building",
    skill_woodBuilding_description = "Build structures out of wood.",
    skill_basicResearch = "Investigation",
    skill_basicResearch_description = "Investigate objects to make breakthroughs and advance the tribe's knowledge.",
    skill_diplomacy = "Diplomacy",
    skill_diplomacy_description = "Inspire other sapiens to join and remain in your tribe, or convince them to go away.",
    skill_fireLighting = "Fire Lighting",
    skill_fireLighting_description = "Fire provides warmth and light, keeps animals away, and allows cooking of food to increase its nutritional value.", --0.5 added "keeps animals away"
    skill_knapping = "Rock Knapping",
    skill_knapping_description = "Create primitive rock tools, and split large rocks into smaller ones.",
    skill_flintKnapping = "Flint Knapping",
    skill_flintKnapping_description = "Create flint tools, which last longer and are sharper.",
    skill_boneCarving = "Bone Carving",
    skill_boneCarving_description = "Make sharp blades and musical instruments from bone.",
    skill_flutePlaying = "Music",--the key is flutePlaying, but the translation should be for playing all instruments eg "Music"
    skill_flutePlaying_description = "Music helps to unite your tribe, increasing loyalty and happiness for those nearby.",
    skill_pottery = "Pottery",
    skill_pottery_description = "Craft urns and mud bricks.",
    skill_potteryFiring = "Ceramics",
    skill_potteryFiring_description = "Fire urns and bricks.",
    skill_spinning = "Flax Spinning",
    skill_spinning_description = "Create twines and ropes from plant fibers.",
    skill_thatchBuilding = "Thatch Building",
    skill_thatchBuilding_description = "Build simple shelters out of hay or reeds, and branches.",
    skill_mudBrickBuilding = "Masonry", --0.4 changed from mud brick building to masonry, now applies to all brick/block based building
    skill_mudBrickBuilding_description = "Build structures with bricks and stone blocks.", --0.4 changed to "bricks and stone blocks" from "mud bricks"
    skill_brickBuilding = "Brick Building", --deprecated (0.4)
    skill_brickBuilding_description = "Build structures with fired bricks.", --deprecated (0.4)
    skill_tiling = "Tiling",
    skill_tiling_description = "Build roofs, floors, and paths with ceramic tiles.",

    skill_basicHunting = "Rock Throwing", --0.7 now is the skill name for both hunting and conflict by throwing rocks
    skill_basicHunting_description = "Hunt small prey and scare off invaders by throwing rocks.", --0.7 
    skill_spearHunting = "Spear Hunting/Combat", --0.7 now is the skill name for both hunting and conflict with spears
    skill_spearHunting_description = "Hunt larger and faster prey, and fight other tribes with spears.", --0.7 

    skill_butchery = "Butchery",
    skill_butchery_description = "Butcher carcasses to provide meat.",
    skill_campfireCooking = "Basic Cooking",
    skill_campfireCooking_description = "Cook meat to provide more nutritional value.",
    skill_baking = "Baking",
    skill_baking_description = "Kneed flour into bread dough and bake it to create a nutritious meal.",
    skill_treeFelling = "Tree Felling",
    skill_treeFelling_description = "Chop down trees using hand tools.",
    skill_woodWorking = "Wood Working",
    skill_woodWorking_description = "Craft things out of branches and logs.",
    skill_toolAssembly = "Tool Assembly",
    skill_toolAssembly_description = "Craft more complex tools by combining multiple components.",
    skill_medicine = "Medicine", --0.3.0
    skill_medicine_description = "Craft and administer poultices and medicines to help the injured or sick.", --0.3.0
    skill_digging = "Digging",
    skill_digging_description = "Dig and fill soil, sands, and clays.",
    skill_mining = "Mining",
    skill_mining_description = "Mine hard materials, like rock and ore.", --0.4 added "and ore"
    skill_planting = "Planting",
    skill_planting_description = "Plant seeds to grow trees and crops.",
    skill_mulching = "Mulching",
    skill_mulching_description = "Improve the soil with manure or compost.",
    skill_threshing = "Threshing",
    skill_threshing_description = "Thresh grains to make them ready to mill or cook.",
    skill_grinding = "Grain Grinding", --0.3.0 added Grain
    skill_grinding_description = "Pulverize grains to unlock the nutrition within.",
    skill_blacksmithing = "Blacksmithing", --0.4
    skill_blacksmithing_description = "Smelt ores and craft with metals.", --0.4
    skill_chiselStone = "Stone Carving", --0.4
    skill_chiselStone_description = "Chisel stone blocks directly from rocky ground.", --0.4
    skill_handToHandCombat = "Hand to Hand", --0.7
    skill_handToHandCombat_description = "Fight other sapiens in hand to hand combat.", --0.7

    --storage
    storage_rockSmall = "Small Rocks",
    storage_seed = "Seeds",
    storage_rock = "Large Rocks",
    storage_log = "Logs",
    storage_woodenPole = "Wooden Poles",
    storage_woolskin = "Woolskins",
    storage_bone = "Bones",
    storage_pineCone = "Pine Cones",
    storage_pineConeBig = "Large Pine Cones",
    storage_deadChicken = "Chicken Carcasses",
    storage_beetroot = "Beetroots",
    storage_flower = "Flowers", --0.3.0
    storage_gingerRoot = "Ginger Roots", --0.3.0
    storage_turmericRoot = "Turmeric Roots", --0.3.0
    storage_garlic = "Garlic", --0.3.0
    storage_aloeLeaf = "Aloe Leaves", --0.3.0
    storage_wheat = "Wheat",
    storage_flax = "Flax",
    storage_knife = "Knives",
    storage_axeHead = "Axe Heads",
    storage_hammerHead = "Hammer Heads", --0.4
    storage_hammer = "Hammers", --0.4
    storage_pickaxeHead = "Pickaxe Heads",
    storage_pickaxe = "Pickaxes",
    storage_hatchet = "Hatchets",
    storage_branch = "Branches",
    storage_spearHead = "Spear Heads",
    storage_raspberry = "Raspberries",
    storage_peach = "Peaches",
    storage_flatbread = "Flatbreads",
    storage_spear = "Spears",
    storage_dirt = "Soil",
    storage_flint = "Flint",
    storage_clay = "Clay",
    storage_sand = "Sand",
    storage_orange = "Oranges",
    storage_splitLog = "Split Logs",
    storage_chickenMeat = "Chicken Meat",
    storage_hayGrass = "Hay",
    storage_deadAlpaca = "Alpaca Carcasses",
    storage_apple = "Apples",
    storage_elderberry = "Elderberries", --0.3.0
    storage_banana = "Bananas",
    storage_coconut = "Coconuts",
    storage_alpacaMeat = "Alpaca Meat",
    storage_fish = "Fish", --0.5.1.3
    storage_gooseberry = "Gooseberries",
    storage_pumpkin = "Pumpkins",
    storage_urn = "Urns",
    storage_bowl = "Bowls", --0.3.0
    storage_quernstone = "Quern-stones",
    storage_breadDough = "Bread Dough",
    storage_brick = "Bricks",
    storage_mammothMeat = "Mammoth Meat",
    storage_flaxTwine = "Flax Twine",
    storage_boneFlute = "Bone Flutes",
    storage_logDrum = "Log Drums",
    storage_balafon = "Balafons",
    storage_tile = "Tiles",

    storage_copperOre = "Copper Ore", --0.4
    storage_tinOre = "Tin Ore", --0.4
    storage_manure = "Manure", --0.4
    storage_rottenGoo = "Rotten Goo", --0.4
    storage_compost = "Compost", --0.4
    storage_crucible = "Crucibles", --0.4
    storage_ingot = "Ingots", --0.4
    storage_chisel = "Chisels", --0.4
    storage_stoneBlock = "Stone Blocks", --0.4

    
    storage_swordfishDead = "Swordfish", --0.6
    storage_swordfishDead_plural = "Swordfish", --0.6

    -- constructable_classification
    constructable_classification_build = "Buildings",
    constructable_classification_build_action = "Build",
    constructable_classification_plant = "Plants/Trees",
    constructable_classification_plant_action = "Plant",
    constructable_classification_craft = "Crafted Objects",
    constructable_classification_craft_action = "Craft",
    constructable_classification_path = "Paths",
    constructable_classification_path_action = "Build",
    constructable_classification_place = "Place Object",
    constructable_classification_place_action = "Place",
    constructable_classification_fill = "Fill Terrain",
    constructable_classification_fill_action = "Fill",
    constructable_classification_research = "Discoveries",
    constructable_classification_research_action = researchName,
    constructable_classification_fertilize = "Mulch", --0.4
    constructable_classification_fertilize_action = "Mulch", --0.4

    --evolution
    evolution_dryAction = "Dries",
    evolution_rotAction = "Rots",
    evolution_despawnAction = "Gone",
    evolution_time_verySoon = "very soon",
    evolution_time_fewHours = "in a few hours",
    evolution_time_fewDays = "in a few days",
    evolution_time_nextYear = "next year",
    evolution_time_fewYears = "in a few years",
    evolution_time_whenUsable = "when allowed to use", --0.3.0. Will stay in current state until "Allow use" is selected
    evolution_timeFunc = function(values)
        return values.actionName .. " " .. values.time
    end,

    -- time
    time_year = "Year",
    time_year_plural = "Years",
    time_day = "Day",
    time_day_plural = "Days",
    time_second = "Second",
    time_second_plural = "Seconds",
    time_hour = "Hour", --0.4
    time_hour_plural = "Hours", --0.4

    --weather
    weather_temperatureZone_veryCold = "Very Cold",
    weather_temperatureZone_cold = "Cold",
    weather_temperatureZone_moderate = "Warm",
    weather_temperatureZone_hot = "Hot",
    weather_temperatureZone_veryHot = "Very Hot",

    -- keyMaps
    keygroup_game = "Game",
    keygroup_menu = "Menu",
    keygroup_movement = "Movement",
    keygroup_building = "Building",
    keygroup_textEntry = "Text Entry",
    keygroup_debug = "Debug",
    keygroup_multiSelect = "Multi-Select",
    keygroup_cinematicCamera = "Cinematic Camera",

    -- key_game
    key_game_escape = "Close/Hide",
    key_game_chat = "Chat",
    key_game_luaPrompt = "Lua Console", --0.5
    key_game_toggleMap = "Map",
    key_game_confirm = "Confirm/Enter",
    key_game_confirmSpecial = "Secondary Confirm",
    key_game_menu = "Open Menu",
    key_game_buildMenu = "Open Build Menu",
    key_game_buildMenu2 = "Open Build Menu (Alternate)",
    key_game_tribeMenu = "Open Tribe Menu",
    key_game_routesMenu = "Open Routes Menu",
    key_game_settingsMenu = "Open settings Menu",
    key_game_zoomToNotification = "Zoom To Notification",
    key_game_pause = "Pause/Unpause",
    key_game_speedFast = "Toggle Speed Up Time",
    key_game_speedSlowMotion = "Game Speed Slow Motion",
    key_game_radialMenuShortcut1 = "Radial Menu Shortcut 1",
    key_game_radialMenuShortcut2 = "Radial Menu Shortcut 2",
    key_game_radialMenuShortcut3 = "Radial Menu Shortcut 3",
    key_game_radialMenuShortcut4 = "Radial Menu Shortcut 4",
    key_game_radialMenuShortcut5 = "Radial Menu Shortcut 5",
    key_game_radialMenuShortcut6 = "Radial Menu Shortcut 6", --0.3.0
    key_game_radialMenuAutomateModifier = "Radial Menu Options Modifier", --0.4 modified, changed "Automate" to "Options"
    key_game_radialMenuDeconstruct = "Radial Menu Remove/Destroy",
    key_game_moveCommandAddWaitOrderModifier = "Move Sapien - Add Wait Order Modifier", --0.4
    key_game_zoomModifier = "Zoom click modifier",
    key_game_multiselectModifier = "Multi-select click modifier",
    key_game_radialMenuClone = "Radial Menu Build More",--b13
    key_game_radialMenuInvestigate = "Radial Menu Investigate", --0.7
    key_game_prioritize = "Prioritize", --0.5
    key_game_togglePointAndClick = "Toggle point-and-click camera mode", --0.5.1
    key_game_radialMenuChopReplant = "Chop & replant", --0.5.1

    -- key_menu
    key_menu_up = "Up",
    key_menu_down = "Down",
    key_menu_left = "Left",
    key_menu_right = "Right",
    key_menu_select = "Select",
    key_menu_selectAlt = "Select (Alternative)",
    key_menu_back = "Back",
    
    -- key_movement
    key_movement_forward = "Forward",
    key_movement_back = "Back",
    key_movement_left = "Left",
    key_movement_right = "Right",
    key_movement_slow = "Slow",
    key_movement_fast = "Fast",
    key_movement_forwardAlt = "Forward (Alternative)",
    key_movement_backAlt = "Back (Alternative)",
    key_movement_leftAlt = "Left (Alternative)",
    key_movement_rightAlt = "Right (Alternative)",
    key_movement_zoomIn = "Zoom In", --0.4
    key_movement_zoomOut = "Zoom Out", --0.4
    key_movement_rotateLeft = "Rotate Left", --0.5.1
    key_movement_rotateRight = "Rotate Right", --0.5.1
    key_movement_rotateForward = "Rotate Forward", --0.5.1.3
    key_movement_rotateBack = "Rotate Back", --0.5.1.3
    
    

    key_building_cancel = "Cancel",
    key_building_confirm = "Confirm",
    key_building_zAxisModifier = "Axis Switch / Disable Snapping",
    key_building_adjustmentModifier = "Placement Fine Tune Modifier",
    key_building_noBuildOrderModifier = "Placement No Build Order Modifier",
    key_building_rotateX = "Rotate 90 on X axis",
    key_building_rotateY = "Rotate 90 on Y axis",
    key_building_rotateZ = "Rotate 90 on Z axis",
    key_textEntry_backspace = "Backspace", --0.5
    key_textEntry_delete = "Delete", --0.5
    key_textEntry_send = "Send/Enter",
    key_textEntry_newline = "Newline",
    key_textEntry_prevCommand = "Up", --0.5 changed from "Previous", now mostly used to navigate text, but in the terminal console, it is also used for the previous command
    key_textEntry_nextCommand = "Down", --0.5 changed from "Next", now mostly used to navigate text, but in the terminal console, it is also used for the next command
    key_textEntry_cursorLeft = "Left", --0.5
    key_textEntry_cursorRight = "Right", --0.5

    -- key_multiSelect
    key_multiSelect_subtractModifier = "Subtract Modifier",

    -- key_debug
    key_debug_reload = "Reload",
    key_debug_lockCamera = "Lock Camera",
    key_debug_setDebugObject = "Set Debug Object",
    key_debug_measureDistance = "Measure Distance", --0.5

    -- key_cinematicCamera
    key_cinematicCamera_startRecord1 = "Start Record 1",
    key_cinematicCamera_startRecord2 = "Start Record 2",
    key_cinematicCamera_startRecord3 = "Start Record 3",
    key_cinematicCamera_startRecord4 = "Start Record 4",
    key_cinematicCamera_startRecord5 = "Start Record 5",
    key_cinematicCamera_play1 = "Play 1",
    key_cinematicCamera_play2 = "Play 2",
    key_cinematicCamera_play3 = "Play 3",
    key_cinematicCamera_play4 = "Play 4",
    key_cinematicCamera_play5 = "Play 5",
    key_cinematicCamera_stop = "Stop Playback",
    key_cinematicCamera_insertKeyframe = "Insert Keyframe",
    key_cinematicCamera_saveKeyframe = "Save Keyframe",
    key_cinematicCamera_removeKeyframe = "Remove Keyframe",
    key_cinematicCamera_nextKeyframe = "Next Keyframe",
    key_cinematicCamera_prevKeyframe = "Previous Keyframe",
    key_cinematicCamera_increaseKeyframeDuration = "+ Keyframe Duration",
    key_cinematicCamera_decreaseKeyframeDuration = "- Keyframe Duration",

    -- selection groups
    selectionGroup_branch_objectName = "Branch",
    selectionGroup_branch_plural = "Branches",
    selectionGroup_branch_descriptive = "Any Branches",
    selectionGroup_log_objectName = "Log",
    selectionGroup_log_plural = "Logs",
    selectionGroup_log_descriptive = "Any Logs",
    selectionGroup_rock_objectName = "Rock",
    selectionGroup_rock_plural = "Rocks",
    selectionGroup_rock_descriptive = "Any Rocks",
    selectionGroup_smallRock_objectName = "Small Rock",
    selectionGroup_smallRock_plural = "Small Rocks",
    selectionGroup_smallRock_descriptive = "Any Small Rocks",
    
    selectionGroup_stoneBlock_objectName = "Stone Block", --0.4
    selectionGroup_stoneBlock_plural = "Stone Blocks", --0.4
    selectionGroup_stoneBlock_descriptive = "Any Stone Blocks", --0.4
    
    selectionGroup_plant_objectName = "Plant", --0.5
    selectionGroup_plant_plural = "Plants", --0.5
    selectionGroup_plant_descriptive = "Any Plants", --0.5

    selectionGroup_tree_objectName = "Tree", --0.5
    selectionGroup_tree_plural = "Trees", --0.5
    selectionGroup_tree_descriptive = "Any Trees", --0.5

    selectionGroup_sled_objectName = "Sled", --0.5
    selectionGroup_sled_plural = "Sleds", --0.5
    selectionGroup_sled_descriptive = "Any Sleds", --0.5

    selectionGroup_canoe_objectName = "Canoe", --0.5.1
    selectionGroup_canoe_plural = "Canoes", --0.5.1
    selectionGroup_canoe_descriptive = "Any Canoes", --0.5.1

    selectionGroup_chicken = "Any Chickens", --0.6, when using multi select, this is in the pull down menu, allowing you to select between any chickens or only red chickens
    selectionGroup_alpaca = "Any Alpacas", --0.6
    selectionGroup_mammoth = "Any Mammoths", --0.6
    selectionGroup_catfish = "Any Catfish", --0.6
    selectionGroup_coelacanth = "Any Coelacanth", --0.6
    selectionGroup_flagellipinna = "Any Flagellipinna", --0.6
    selectionGroup_polypterus = "Any Polypterus", --0.6
    selectionGroup_redfish = "Any Redfish", --0.6
    selectionGroup_tropicalfish = "Any Jackfish", --0.6
    selectionGroup_swordfish = "Any Swordfish", --0.6
    

    selectionGroup_alpaca_white = "White Alpacas", --0.6
    selectionGroup_alpaca_black = "Black Alpacas", --0.6
    selectionGroup_alpaca_red = "Red Alpacas", --0.6
    selectionGroup_alpaca_yellow = "Yellow Alpacas", --0.6
    selectionGroup_alpaca_cream = "Cream Alpacas", --0.6
    
    -- notifications
    notification_becamePregnant = function(values)
        return values.name .. " is pregnant"
    end,
    notification_babyBorn = function(values)
            local gender = "Girl"
            if not values.babyIsFemale then
                gender = "Boy"
            end
        return values.parentName .. " had a baby " .. gender
    end,
    notification_babyGrew = function(values)
        return values.parentName .. "'s baby grew into a child and has been named " .. values.childName
    end,
    notification_agedUp = function(values)
        if values.lifeStageName then
            return values.name .. " is now an " .. string.lower(values.lifeStageName)
        end
        return values .. " aged up"
    end,
    notification_died = function(values)
        return values.name .. " has died of " .. string.lower(values.deathReason) --0.3.0 changed from "has died. reason:"
    end,
    notification_left = function(values)
        return values.name .. " has left the tribe"
    end,
    notification_banished = function(values) --0.7
        if values.tribeName then
            return values.name .. " was banished from your tribe by the " .. values.tribeName .. " tribe!"
        end
        return values.name .. " was banished from your tribe by another tribe!"
    end,
    notification_lowLoyalty = function(values)
        return values.name .. " may leave the tribe soon"
    end,
    notification_recruited = function(values)
        return values.name .. " has joined your tribe"
    end,
    notification_recruitedTakenByOtherTribe = function(values) --0.7
        if values.tribeName then
            return values.name .. " was recruited away by the " .. values.tribeName .. " tribe!"
        end
        return values.name .. " was recruited by another tribe!"
    end,
    
    notification_recruitFail = function(values) --0.7
        return values.name .. " refused to join your tribe"
    end,
    notification_banishSuccess = function(values) --0.7
        return values.name .. " has been banished"
    end,
    notification_banishFail = function(values) --0.7
        return values.name .. " refused to leave"
    end,
    notification_banishedByOtherTribe = function(values) --0.7
        if values.tribeName then
            return values.name .. " was banished by the " .. values.tribeName .. " tribe!"
        end
        return values.name .. " was bainshed by another tribe!"
    end,
    notification_sapienFleeing = function(values) --0.7
        return values.name .. " is fleeing!"
    end,
    
    notification_sapienUnderAttack = function(values) --0.7
        return values.name .. " is under attack!"
    end,
    notification_threatScared = function(values) --0.7
        return values.name .. " has scared the threat away!"
    end,
    notification_skillLearned = function(values)
        return values.name .. " has learned the " .. values.skillName .. " skill"
    end,
    
    notification_recruitmentIncreasedDiscovery = function(values) --0.7. If this is too complex, could just be: "Recruiting " .. values.name .. " has increased our knowledge of " .. values.discoveryName
        return "Recruiting " .. values.name .. ", who is skilled in " .. values.skillName .. " has increased our knowledge of " .. values.discoveryName
    end,
    
    notification_newTribeSeen = function(values)
        return "A visitor has been spotted" --0.7 modified from "Another tribe has been spotted"
    end,
    notification_dangerousNewTribeSeen = function(values) --0.7
        return "A potential threat has been spotted"
    end,
    notification_discovery = function(values)
        return "Your tribe has discovered " .. values.skillName .. "!"
    end,
    notification_craftableDiscovery = function(values) --0.3.0
        return "Your tribe has discovered how to craft " .. values.craftablePlural .. "!"
    end,
    notification_researchNearlyDone = function(values)
        return "Breakthrough is nearly complete!"
    end,
    notification_mammothKill = function(values)
        return values.name .. " has killed a mammoth"
    end,

    --[[notification_minorInjuryByMob = function(values) --0.3.0 these have been removed, replaced by notification_triggerActionHuntingMob combined with notification_minorInjury
        return values.name .. " was injured by a " .. values.mobTypeName
    end,]]
    --[[notification_majorInjuryByMob = function(values)
        return values.name .. " was majorly injured by a " .. values.mobTypeName
    end,
    notification_criticalInjuryByMob = function(values)
        return values.name .. " was critically injured by a " .. values.mobTypeName
    end,]]

    --b13
    notification_majorInjuryDeveloped = function(values)
        return values.name .. "'s injury has become major"
    end,
    notification_criticalInjuryDeveloped = function(values)
        return values.name .. "'s injury has become critical"
    end,
    --/b13

    
    notification_triggerActionCrafting = function(values)
        return "crafting " .. string.lower(values.craftablePlural)
    end,
    notification_triggerActionResearching = function(values)
        return "researching"
    end,
    notification_triggerActionDeliveringFuel = function(values)
        return "delivering fuel to " .. string.lower(values.objectName)
    end,
    notification_triggerActionHuntingMob = function(values)
        return "hunting " .. getAorAn(string.lower(values.mobTypeName)) .. " " .. string.lower(values.mobTypeName) --0.3.6 modified
    end,
    notification_triggerActionBasic = function(values)  --values.actionName is also available
        return string.lower(values.actionInProgress)
    end,
    
    notification_minorInjury = function(values)
        return values.name .. " was injured while " .. values.triggerAction
    end,
    notification_majorInjury = function(values)
        return values.name .. " was majorly injured while " .. values.triggerAction
    end,
    notification_criticalInjury = function(values)
        return values.name .. " was critically injured while " .. values.triggerAction
    end,

    notification_minorInjuryBy = function(values) --0.3.6 added
        return values.name .. " was injured by " .. getAorAn(string.lower(values.objectName)) .. " " .. string.lower(values.objectName)
    end,
    notification_majorInjuryBy = function(values) --0.3.6 added
        return values.name .. " was majorly injured by " .. getAorAn(string.lower(values.objectName)) .. " " .. string.lower(values.objectName)
    end,
    notification_criticalInjuryBy = function(values) --0.3.6 added
        return values.name .. " was critically injured by " .. getAorAn(string.lower(values.objectName)) .. " " .. string.lower(values.objectName)
    end,

    notification_minorInjuryByAttack = function(values) --0.7
        return values.name .. " was injured by an attack from the" .. string.lower(values.tribeName) .. " tribe."
    end,
    notification_majorInjuryByAttack = function(values) --0.7
        return values.name .. " was majorly injured by an attack from the" .. string.lower(values.tribeName) .. " tribe."
    end,
    notification_criticalInjuryByAttack = function(values) --0.7
        return values.name .. " was critically injured by an attack from the" .. string.lower(values.tribeName) .. " tribe."
    end,

    notification_minorBurn = function(values)
        return values.name .. " was burned while " .. values.triggerAction
    end,
    notification_majorBurn = function(values)
        return values.name .. " was majorly burned while " .. values.triggerAction
    end,
    notification_criticalBurn = function(values)
        return values.name .. " was critically burned while " .. values.triggerAction
    end,
    notification_majorBurnDeveloped = function(values)
        return values.name .. "'s burn has become major"
    end,
    notification_criticalBurnDeveloped = function(values)
        return values.name .. "'s burn has become critical"
    end,
    notification_minorFoodPoisoning = function(values)
        return values.name .. " has an upset stomach from eating " .. values.resourceName
    end,
    notification_minorFoodPoisoningFromContamination = function(values)
        return values.name .. " has an upset stomach from eating " .. values.resourceName .. " contaminated by " .. values.contaminationResourceName
    end,
    notification_majorFoodPoisoningDeveloped = function(values)
        return values.name .. " now has a major case of food poisoning"
    end,
    notification_criticalFoodPoisoningDeveloped = function(values)
        return values.name .. " is now critically ill from food poisoning"
    end,
    notification_minorVirus = function(values)
        return values.name .. " has caught a virus and is showing minor symptoms"
    end,
    notification_majorVirusDeveloped = function(values)
        return values.name .. "'s symptoms have worsened, they now have a major infection"
    end,
    notification_criticalVirusDeveloped = function(values)
        return values.name .. " is now critically ill due to viral infection"
    end,
    notification_starving = function(values)
        return values.name .. " is starving"
    end,
    notification_starvingRemoved = function(values)
        return values.name .. " is no longer starving"
    end,
    notification_veryHungry = function(values)
        return values.name .. " is very hungry"
    end,
    notification_veryHungryRemoved = function(values)
        return values.name .. " is no longer hungry"
    end,
    notification_hypothermia = function(values)
        return values.name .. " has developed hypothermia"
    end,
    notification_hypothermiaRemoved = function(values)
        return values.name .. " no longer has hypothermia"
    end,

    notification_minorInjuryHealed = function(values)
        return values.name .. "'s injury has completely healed"
    end,
    notification_majorInjuryBecameMinor = function(values)
        return values.name .. "'s injury is improving"
    end,
    notification_criticalInjuryBecameMajor = function(values)
        return values.name .. "'s injury is no longer critical"
    end,
    notification_minorBurnHealed = function(values)
        return values.name .. "'s burn has completely healed"
    end,
    notification_majorBurnBecameMinor = function(values)
        return values.name .. "'s burn is improving"
    end,
    notification_criticalBurnBecameMajor = function(values)
        return values.name .. "'s burn is no longer critical"
    end,
    notification_minorFoodPoisoningHealed = function(values)
        return values.name .. "'s food poisoning has completely cleared up"
    end,
    notification_majorFoodPoisoningBecameMinor = function(values)
        return values.name .. "'s food poisoning illness is improving"
    end,
    notification_criticalFoodPoisoningBecameMajor = function(values)
        return values.name .. "'s food poisoning illness is no longer critcial"
    end,
    notification_minorVirusHealed = function(values)
        return values.name .. " is no longer sick or infectious"
    end,
    notification_majorVirusBecameMinor = function(values)
        return values.name .. "'s viral infection is clearing up"
    end,
    notification_criticalVirusBecameMajor = function(values)
        return values.name .. "'s viral infection is no longer critical"
    end,

    notification_windDestruction = function(values) --0.4. values.name is not a sapien's name, it is an object's name like "Thatch Roof/Hut"
        return "A " .. values.name .. " has been damaged in the wind"
    end,
    notification_rainDestruction = function(values) --0.4. values.name is not a sapien's name, it is an object's name like "Thatch Roof/Hut"
        return "A " .. values.name .. " has been damaged by the rain"
    end,
    
    notification_addWindBlownAdjective = function(values) --0.4 Used in a wind storm eg: "Bob was majorly injured by a 'flying banana'"
        return "flying " .. string.lower(values.objectName)
    end,

    notification_autoRoleAssign = function(values) --0.5
        return values.name .. " has been auto-assigned the " .. values.skillName .. " role"
    end,
    notification_tribeFirstMet = function(values) --0.5
        return values.name .. " has met the " .. values.tribeName .. " tribe!"
    end,

    notification_tribeGrievance_resourcesTaken = function(values) --0.5
        return "The " .. values.tribeName .. " tribe is upset that we have been taking " .. string.lower(values.resourcePlural)
    end,

    notification_tribeGrievance_bedsUsed = function(values) --0.5
        return "The " .. values.tribeName .. " tribe is upset that we have been sleeping in their beds"
    end,

    notification_tribeGrievance_objectsDestroyed = function(values) --0.5
        return "The " .. values.tribeName .. " tribe is upset that we have been destroying their " .. string.lower(values.objectName)
    end,

    notification_tribeGrievance_objectsBuilt = function(values) --0.5
        return "The " .. values.tribeName .. " tribe is upset that we have been building " .. getAorAn(values.objectName) .. " " .. string.lower(values.objectName) .. " too close to them"
    end,

    notification_tribeGrievance_craftAreasUsed = function(values) --0.5
        return "The " .. values.tribeName .. " tribe is upset that we have been using their " .. string.lower(values.objectName)
    end,

    notification_tribeGrievance_sapienRecruited = function(values) --0.7
        return "The " .. values.tribeName .. " tribe is upset that we have been recruiting their sapiens"
    end,

    notification_tribeGrievance_sapienBanished = function(values) --0.7
        return "The " .. values.tribeName .. " tribe is upset that we have been banishing their sapiens"
    end,

    notification_tribeGrievance_sapienAttacked = function(values) --0.7
        return "The " .. values.tribeName .. " tribe is upset that we have been attacking their sapiens"
    end,

    notification_tribeGrievance_nomadsMistreated = function(values) --0.7
        return "The " .. values.tribeName .. " tribe is upset with how we have been treating vistors to our tribe"
    end,

    notification_tradeRequestFavorReward = function(values) --0.5
        return "The " .. values.tribeName .. " tribe has awarded " .. values.reward .. " favor for our delivery of " .. values.deliveredCount .. " " .. values.resourcePlural
    end,

    notification_tradeOfferFavorPaid = function(values) --0.5
        return "We have accepted the offer of " .. values.count .. " " .. values.resourcePlural .. " for " .. values.cost .. " favor from the " .. values.tribeName .. " tribe"
    end,

    notification_resourceQuestFavorReward = function(values) --0.5
        return "Quest complete! The " .. values.tribeName .. " tribe has awarded " .. values.reward .. " favor for our delivery of " .. values.deliveredCount .. " " .. values.resourcePlural
    end,

    notification_resourceQuestFailFavorPenalty = function(values) --0.5
        return "Quest failed. We have lost " .. values.penalty .. " favor with the " .. values.tribeName .. " tribe for failing to deliver " .. values.requiredCount .. " " .. values.resourcePlural
    end,

    --[[notification_resourceQuestFailReducedFavorPenalty = function(values) --0.5
        return "Quest failed. We have lost " .. values.penalty .. " favor with the " .. values.tribeName .. " tribe for only delivering " ..values.deliveredCount .. " of the " .. values.requiredCount .. " required " .. values.resourcePlural
    end,]]

    notification_resourceQuestFailNoReward = function(values) --0.5
        return "Quest failed. As we delivered more than half (" .. values.deliveredCount .. ") of the " .. values.requiredCount .. " required " .. values.resourcePlural .. ", our favor remains unchanged"
    end,

    grievance_resourcesTaken = "Resources Taken", --0.5
    grievance_bedsUsed = "Beds Slept In", --0.5
    grievance_objectsDestroyed = "Structures Destroyed", --0.5
    grievance_objectsBuilt = "Structures Built", --0.5
    grievance_craftAreasUsed = "Craft Areas Used", --0.5
    
    grievance_sapienRecruited = "Sapiens Recruited", --0.7
    grievance_sapienBanished = "Sapiens Banished", --0.7
    grievance_sapienAttacked = "Sapiens Attacked", --0.7
    grievance_nomadsMistreated = "Visitors Mistreated", --0.7

    

    deathReason_criticalInjury = "Critical Injury",
    deathReason_oldAge = "Old Age",
    deathReason_burn = "Critical Burn",
    deathReason_foodPoisoning = "Food Poisoning",
    deathReason_virus = "Viral Infection", 
    deathReason_starvation = "Starvation", 
    deathReason_hypothermia = "Hypothermia",

    --notification display groups (new in 0.5 for notifications panel in tribe management UI)
    notification_displayGroup_informative = "Informative", --0.5
    notification_displayGroup_minorWarning = "Minor Warnings", --0.5
    notification_displayGroup_majorWarning = "Major Warnings", --0.5
    notification_displayGroup_skillsAndResearch = "Skills & Research", --0.5
    notification_displayGroup_favorLost = "Favor Lost", --0.5
    notification_displayGroup_favorGained = "Favor Gained", --0.5
    notification_displayGroup_conflict = "Conflict", --0.7


    tribeRelations_firstMeet_severePositive = function(values) --0.5
        return "The " .. values.tribeName .. " tribe was very excited to meet with " .. values.name .. "! They are skilled " .. values.industryWorkerTypeName .. ". They are ready to help however they can."
    end,
    tribeRelations_firstMeet_moderatePositive = function(values) --0.5
        return "The " .. values.tribeName .. " tribe was happy to meet with " .. values.name .. "! They are skilled " .. values.industryWorkerTypeName .. ", and are keen to trade with us."
    end,
    tribeRelations_firstMeet_mildPositive = function(values) --0.5
        return "The " .. values.tribeName .. " tribe greeted " .. values.name .. " respectfully. They are skilled " .. values.industryWorkerTypeName .. ", and are willing to trade with us."
    end,

    tribeRelations_firstMeet_mildNegative = function(values) --0.5
        return "The " .. values.tribeName .. " tribe greeted " .. values.name .. " cautiously. They are skilled " .. values.industryWorkerTypeName .. ". We will need to complete a quest before we can trade."
    end,
    tribeRelations_firstMeet_moderateNegative = function(values) --0.5
        return "The " .. values.tribeName .. " tribe reluctantly agreed to meet with " .. values.name .. ", despite our reputation, however they will not trade."
    end,
    tribeRelations_firstMeet_severeNegative = function(values) --0.5
        return "The " .. values.tribeName .. " tribe appears extremely hostile towards us. They are not interested in any trades."
    end,

    tribeRelations_general_severePositive = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are skilled " .. values.industryWorkerTypeName .. ". They are keen to trade, and ready to help however they can."
    end,
    tribeRelations_general_moderatePositive = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are skilled " .. values.industryWorkerTypeName .. ". They are keen to trade with us."
    end,
    tribeRelations_general_mildPositive = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are skilled " .. values.industryWorkerTypeName .. ". They are willing to trade with us."
    end,

    tribeRelations_general_mildNegative = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are skilled " .. values.industryWorkerTypeName .. ". They will only trade if we increase our favor with them."
    end,
    tribeRelations_general_moderateNegative = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are not happy with us. We will need to work on our relationship before they will trade."
    end,
    tribeRelations_general_severeNegative = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are extremely hostile towards us. They are not interested in any trades."
    end,

    tribeRelations_otherPlayer = function(values) --0.5
        return "The " .. values.tribeName .. " tribe are led by " .. values.playerName .. "."
    end,

    favor_tooltip_gain_later = function(values) --0.5
        return "Gain " .. values.favorChangeValue .. " favor when complete"
    end,
    favor_tooltip_gain_now = function(values) --0.5
        return "Gain " .. values.favorChangeValue .. " favor"
    end,
    favor_tooltip_cost_later = function(values) --0.5
        return "Costs " .. values.favorChangeValue .. " favor if not completed in time"
    end,
    favor_tooltip_cost_now = function(values) --0.5
        return "Costs " .. values.favorChangeValue .. " favor"
    end,


    tribeRelations_useFavorForOffers = function(values) --0.5
        return "Use favor to purchase resources from the " .. values.tribeName .. " tribe."
    end,
    tribeRelations_willNotTradeTitle = function(values) --0.5
        return "The " .. values.tribeName .. " tribe will not trade with us until our favor is higher."
    end,
    tribeRelations_gainFavorForRequests = function(values) --0.5
        return "Gain favor by delivering resources to the " .. values.tribeName .. " tribe."
    end,

    tribeRelations_tribeSettingsSummary = function(values) --0.5
        return "Allow our tribe to share storage or use things owned by the " .. values.tribeName .. " tribe."
    end,

    tribeRelations_settings_allowStorageAreaItemUse_short = "Share Storage", --0.5 modified in 0.5.0.78 from "Take Items" as this now allows shared storage area settings too
    tribeRelations_settings_allowStorageAreaItemUse_long = "Use their stored items and storage area settings, and allow them to change our storage area settings", --0.5 modified in 0.5.0.78
    --tribeRelations_settings_allowStoringInStorageAreas_short = "Store Items", --0.5 --removed 0.5.0.78
    --tribeRelations_settings_allowStoringInStorageAreas_long = "Store our items in their storage areas", --0.5 --removed 0.5.0.78
    tribeRelations_settings_allowBedUse_short = "Use Seats and Beds", --0.5
    tribeRelations_settings_allowBedUse_long = "Allow our sapiens to use their seats and sleep in their beds", --0.5
    tribeRelations_settings_shareStorage_notAllied = "To share storage, the other player must also enable this setting",  --0.5 added 0.5.0.78. If you have selected "Share Storage", but they have not
    tribeRelations_settings_shareStorage_notPlayer = "The shared storage option is only available with other players, not AI controlled tribes.",  --0.5 added 0.5.0.78, when trying to ally storage with AI tribes, as this not supported (yet?)

    tribeRelations_settings_treatAsThreat_short = "Treat as Threat", --0.7
    tribeRelations_settings_treatAsThreat_long = "Our sapiens will arm themselves and defend or run away if anyone from this tribe gets too close", --0.7
    

    industry_rockTools_workerTypeName = "Rock Knappers", --0.5 displayed in tribe relations UI for ai tribes when favor is above 40 or so
    industry_flour_workerTypeName = "Bakers", --0.5 (note: combined grain farmers and bakers in 0.5.70)
    industry_bronze_workerTypeName = "Bronze Workers", --0.5
    industry_pottery_workerTypeName = "Potters", --0.5

    -- menues
    menu_createWorld = "Create World",
    menu_worldName = "World Name",
    menu_seed = "Seed",
    menu_seaLevel = "Sea Level",
    menu_rainfall = "Rainfall",
    menu_temperature = "Temperature",
    menu_continentSize = "Continent Size",
    menu_continentHeight = "Continent Height", --0.4 modified
    menu_featureSize = "Mountains", --0.4 modified
    menu_featureHeight = "Mountain Height", --0.4 modified
    menu_mods = "Mods",

    --bug reporting
    reporting_uploading = "Uploading",
    reporting_zipFailed = "Sorry, something went wrong creating the report package.",
    reporting_connectionFailed = "Sorry, couldn't connect to the bug server.",
    reporting_uploadFailed = "Sorry, the bug report package upload failed.",
    reporting_fileTooLarge = "Sorry, the bug report package created is too large to be uploaded.",
    reporting_error = "Sorry, something went wrong.",
    reporting_inProgress = "Sorry, a previous bug report is currently still being created and uploaded. Please try again later.", --0.5
    reporting_uploadComplete = "Thank you for your report, it was sent successfully.",
    reporting_cancelled = "Upload cancelled.",
    reporting_creating = "Thank you. Creating report...",
    reporting_infoText = "Please help us to make Sapiens better! The report will upload in the background after you click send. Thank you.",
    reporting_pleaseWriteATitle = "Please provide a brief description for this bug report.",
    reporting_bugTitle = "Brief description",
    reporting_bugDescription = "More details",
    reporting_email = "Contact email (optional)",
    reporting_sendLogFiles = "Send Log Files",
    reporting_sendWorldSaveFiles = "Send World Save Files",
    reporting_submitViaEmail = "Send Via Email",
    reporting_submitViaForums = "Send Via Forums",
    reporting_sendBugReport = "Send Bug Report",
    reporting_sendCrashReport = "Send Crash Report",

    reporting_crashNotification = "It looks like Sapiens crashed last time you played.\n\
We want to fix the bug that caused this, so please send us the crash report. Thanks!",

    --mods
    mods_cautionCaps = "CAUTION!",

    mods_cautionInfo = "Mods can contain and execute both Lua and C code, which may have access to your system, files and network.\n\
Mods in Sapiens are not in any way sandboxed, so should be treated as totally separate applications, and with extreme care. They have the potential to harm your computer.\n\
Even mods that have been installed from Steam Workshop may not be safe. Only install and enable mods from mod authors and servers that you trust.", --0.5 added "and servers"
    mods_enableMods = "Enable Mods",
    mods_installWarningTitle = "WARNING: This server wants to install mods on your computer", --0.5 title for an alert panel if you connect to a modded server
    mods_installListMessage = "The following required mods will be downloaded automatically from this server:", --0.5 in the alert panel if you connect to a modded server
    mods_installMods = "Install Mods", --0.5 when connecting to a modded server, on the button to confirm we want to install the mods.
    mods_notAddedToWorkshop = "Not added to Steam Workshop.",
    mods_addedToWorkshop = "Added to Steam Workshop. Click upload to update mod files on Steam.",
    mods_modDeveloperTools = "Mod Developer Tools",
    mods_AddToSteamWorkshop = "Add To Steam Workshop",
    mods_ContactingSteam = "Contacting Steam",
    mods_acceptAgreement = "You need to accept the Steam Workshop legal agreement first. After you have accepted, click upload.",
    mods_idReceived = "ID received. By submitting this item, you agree to the workshop terms of service at:\nhttp://steamcommunity.com/sharedfiles/workshoplegalagreement\nClick upload to update mod files on Steam.",
    mods_failedToSaveID = "Failed to save Steam ID to",
    mods_failedToAddToSteam = "Failed to add to Steam.",
    mods_UploadToSteam = "Upload To Steam",
    mods_replaceDescription = "Send updated info (eg. description) from modInfo.lua", --0.3.0
    mods_Uploadcomplete = "Upload complete.",
    mods_failedToUploadToSteam = "Failed to upload to Steam.",
    mods_nameDefault = "No Name",
    mods_descriptionDefault = "No Description",
    mods_versionDefault = "No Version",
    mods_developerDefault = "Unknown Developer",
    mods_version = "Version",
    mods_developer = "Developer",
    mods_gameMods = "Game mods",
    mods_gameMods_info = "App-wide, applies to all worlds.",
    mods_worldMods = "World mods",
    mods_worldMods_info = "Only configurable per world.", --b20 changed from "Only configurable when creating a new world.", as now they can be changed for existing worlds in the saves menu
    mods_configureWorldMods = "Configure mods for this world",
    mods_configureWorldMods_info = "World mods enabled here apply to this world only. The currently installed versions of enabled mods will be copied and stored with the world save on creation. You can also enable/disable or update world mods from the \"Saves\" panel later.", --b20 changed as now they can be changed for existing worlds in the saves menu
    mods_configureGameMods = "Configure game mods",
    mods_configureGameMods_info = "Game mods apply to the entire game, and affect your experience in every world. Only these type of app-wide mods can be enabled here.\nWorld mods affect worlds more directly, and can be enabled from the Mods button in the world creation screen, or from the \"Saves\" panel.",
    mods_findMods = "Find mods on Steam->",
    mods_makeMods = "Make your own mods->",
    mods_websiteLink = "Website ->",
    mods_steamLink = "Steam Page ->",
    mods_filesLink = "Files Location ->",
    mods_visitSteamWorkshopLink = "Visit Steam Workshop->",
    mods_steamWorkshop = "Steam Workshop",

    mods_steamWorkshop_info = "You can browse Steam Workshop to find and install mods, which can then be enabled in the game.\n\
Ensure you have the Steam overlay enabled. Once you find a mod you want on Steam Workshop, you install it by clicking '+ Subscribe'. However, Steam will then need to download the mod in the background before it will become available. For quick results, you may need to restart Steam, wait until the download has completed, and then relaunch Sapiens.\n\
BE CAREFUL! Install mods at your own risk. Even when installed from Steam Workshop, mods can contain and run code that could harm your computer. Only install and enable mods from mod authors and servers that you trust.", --0.5 added "and servers"

    -- graphics drivers
    gfx_updateRequiredTitle = "Please update your graphics card driver.",
    gfx_updateRequired_info = "The driver that has been detected on this system is out of date.\n\nIf you do not update your driver, it will likely cause graphical glitches and/or the game might crash and exit to the desktop while playing.\n\nPlease download and install the latest driver from your graphics card manufacturer. Your graphics card is:",

    --intro
    intro_a = function(values)
        return "For millennia, Sapiens have been exploring " .. values.worldName .. ".\n\nSmall tribes are scattered wide across the world. Travelling, gathering, hunting, and surviving."
    end,
    intro_b = "These Sapiens are happy, but they are limited by their lack of knowledge and ambition.\n\nAlone, they may survive, but can never reach their full potential.",
    intro_c = "You are to become the guardian of a tribe of Sapiens. You will give them direction, and purpose.\n\nYour goal is to encourage them to learn, advance, and grow, and ultimately to create a thriving Sapien civilization.",
    intro_d = "Those you choose to lead will be the ancestors of the entire human species.\n\nChoose your tribe wisely.",

    -- gameFailSequence
    gameFailSequence_a = "With their needs not met, your Sapiens have been dwindling in numbers.\n\nSadly, the last remaining member of your tribe has just departed.",
    gameFailSequence_b = "Fortunately, there are other small tribes nearby willing to follow your lead.\n\nChoose a new tribe to continue.",

    --tips/tutorial
    tutorial_skip = "Skip Tutorial",
    tutorial_skipAreYouSure = "Are you sure you want to skip the tutorial?\nYou can enable it again later in the settings menu.",
    tutorial_or = "or",

    -- choose tribe
    tutorial_title_chooseTribe = "Choose a tribe to lead",
    tutorial_subtitle_mapNavigation = "Navigate the map",
    tutorial_use = "- Use",
    tutorial_toMoveAnd = "to move, and",
    tutorial_toZoom = "to zoom",
    tutorial_subtitle_chooseTribe_title = "Lead a tribe",
    tutorial_subtitle_chooseTribe_a = "- Zoom in close, then click on a few different tribes",
    tutorial_subtitle_chooseTribe_b = "and choose one to lead",
    -- Gathering hay
    tutorial_title_basicControls = "Gathering hay",
    tutorial_basicControls_storyText = "Your sapiens are going to want somewhere to sleep tonight, and hay makes a decent bed. Let's clear some grass so it can dry out and be used for beds.",
    tutorial_basicControls_navigation = "Move around the world",
    tutorial_basicControls_issueOrder = "Order your tribe to clear some grass",
    tutorial_issueOrder_instructions_a = "- Click on grassy ground near your tribe and select",
    tutorial_issueOrder_instructions_b = "Clear",
    tutorial_basicControls_clearHexes = function(values)
        return string.format("Clear %d grass hexes", values.count) --0.5 renamed tiles to "hexes", as this has become the common name for them
    end,

    -- storingResources
    tutorial_title_storingResources = "Storage areas",
    tutorial_storingResources_storyText = "To store and manage all of the resources your tribe finds and crafts, you're going to need storage areas.\n\nEach storage area only stores a single type of resource, so you will need to build many more as you progress, at least one for each resource type.",
    tutorial_storingResources_build = function(values)
        return string.format("Build %d storage areas", values.count) 
    end,
    tutorial_storingResources_subTitle_accessWith = "- Access the build menu with",
    tutorial_storingResources_subTitle_andPlace = "- Place storage areas near your tribe",
    tutorial_storingResources_store = function(values)
        return string.format("Store %d %s", values.count, values.typeName) 
    end,
    tutorial_storingResources_storeTip_a = "- You may need to wait for the grass to dry out",
    tutorial_storingResources_storeTip_b = "You can gather branches from trees",

    -- game speed controls
    tutorial_title_speedControls = "Controlling Game Speed",
    tutorial_subtitle_togglePause = "Toggle pause with",
    tutorial_subtitle_toggleFastForward = "Toggle fast forward with",

    --multiselect
    tutorial_title_multiselect = "Selecting multiple things",
    tutorial_description_multiselect = "You can select many objects or terrain tiles at once, and then issue or cancel orders for all of them at the same time.\n\nThis is particularly useful for clearing large areas, or gathering from many trees.",
    tutorial_task_multiselect = function(values)
        return string.format("Issue any order for %d or more things at once", values.count) 
    end,
    tutorial_task_multiselect_subtitle = "- Click on any object or ground tile",
    tutorial_task_multiselect_subtitle_b = "- Hit \"Select More\"",
    tutorial_task_multiselect_subtitle_c = "- Issue any order for all of them",

    -- beds
    tutorial_title_beds = "Sleeping in beds",
    tutorial_beds_storyText = "Sapiens will be happier if they sleep on a bed, rather than the hard ground. So now that we have enough hay stored, let's build a few beds.",
    tutorial_beds_build = function(values)
        return string.format("Place %d or more beds", values.count) 
    end,
    tutorial_beds_subTitle_accessWith = "- Access the build menu with",
    tutorial_beds_subTitle_andPlace = "- Place beds near your tribe",
    tutorial_beds_waitForBuild = "Wait for the beds to be completed",
    tutorial_beds_waitForBuild_tip = "- Clear more grass to create more hay if necessary",

    --roleAssignment
    tutorial_title_roleAssignment = "How to assign roles",
    tutorial_description_roleAssignment = "When a sapien discovers a new technology, they become skilled in it, and will automatically be assigned a role allowing them to complete tasks relating to that skill. Sapiens will automatically be assigned to roles sometimes too, unless you turn auto-assignment off.\n\nYou can also assign roles to sapiens manually. This can help you to keep everyone busier, and allow you to focus your tribe on specific tasks.", --0.5 re-worded for clarity, and to help explain the new auto-assign feature
    tutorial_task_roleAssignment = "Assign a sapien to a new role",
    tutorial_task_roleAssignment_subtitle_a = "- Hit",
    tutorial_task_roleAssignment_subtitle_b = "then select the tribe menu",
    tutorial_task_roleAssignment_subtitle_c = "- Select \"Roles\"",
    tutorial_task_roleAssignment_subtitle_d = "- Assign a sapien to any role",
    
    -- research
    tutorial_title_research = "Investigating to advance",
    tutorial_research_storyText = "In order to advance, sapiens need to investigate the world around them.\n\nThis leads to technological breakthroughs which will unlock new things to build and craft.\n\nTip: Investigate many of the same items at once to research faster!",
    tutorial_research_branch = "Investigate a branch. It's faster if you research multiple branches at the same time.",--0.5 added "You can research multiple branches at the same time to increase speed"
    tutorial_research_rock = "Investigate rocks", --0.5 changed rock to rocks.
    tutorial_research_hay = "Investigate hay",
    
    -- tools
    tutorial_title_tools = "Crafting areas and tools",
    tutorial_tools_storyText = "With an understanding of rock knapping, sapiens now have the ability to create tools.\n\nHand axes and knives are very useful to start with, so your tribe should craft some now.\n\nThe best way to manage your tribe's crafting activities is to first build designated crafting areas.",
    tutorial_tools_buildCraftAreas = function(values)
        return string.format("Build %d crafting areas", values.count) 
    end,
    tutorial_tools_craftHandAxes = function(values)
        return string.format("Craft and store %d stone hand axes", values.count) 
    end,
    tutorial_tools_craftKnives = function(values)
        return string.format("Craft and store %d stone knives", values.count) 
    end,
    
    -- fire
    tutorial_title_fire = "Lighting a Fire",
    tutorial_fire_storyText = "Fire is an important early discovery which provides light at night, helps to keep your tribe warm when it is cold, keeps animals away, and allows cooking of food.\n\nNow would be a good time to get a campfire going.", --0.5 added "keeps animals away"
    tutorial_fire_place = "Place a campfire",
    tutorial_fire_waitForBuild = "Wait for the fire to be built and lit",
    
    -- thatchBuilding
    tutorial_title_thatchBuilding = "Building with thatch",
    tutorial_thatchBuilding_storyText = "With the new understanding of thatch building, now would be a great time for the tribe to start working on some basic structures.\n\nSapiens will be happier if their beds are under cover, and resources stored under a roof will also last longer.",
    tutorial_thatchBuilding_place = "Place a thatch hut/roof",
    tutorial_thatchBuilding_waitForBuild = "Wait for the structure to be built",
    
    -- food
    tutorial_title_food = "Hunger and food",
    tutorial_food_storyText = "Your sapiens are starting to get hungry. Sapiens will gather fruits by themselves if they get desperate, but you need to issue orders to gather, hunt, and store food to keep them happy.\n\nDon't gather everything at once though, most fruits will last on the tree until next season, but will quickly rot if picked and left outside.", --0.5 changed to "Sapiens will gather fruits by themselves if they get desperate, but you need to issue orders to gather, hunt, and store food to keep them happy". In 0.5, sapiens now gather food themselves, but only if it is very close and they are starving 
    tutorial_food_storeTask = function(values)
        return string.format("Gather and store %d food resources", values.count) 
    end,
    tutorial_food_storeTask_subTitle = "Fruits grow on some types of trees and bushes",
    
    -- farming
    tutorial_title_farming = "Agriculture",
    tutorial_farming_storyText = "Now that the tribe's immediate needs are taken care of, we need to start planning ahead.\n\nAs the tribe grows, they will need to grow enough produce to feed everyone.",
    tutorial_farming_digging = "Discover digging",
    tutorial_farming_planting = "Discover planting",
    tutorial_farming_plantXTrees = function(values)
        return string.format("Plant %d fruiting trees or plants", values.count) 
    end,
    
    -- music
    tutorial_title_music = "Playing Music",
    tutorial_music_storyText = "Music makes sapiens happier and more loyal, and musical sapiens can even grow sad if they haven't heard or played music for a long time.",
    tutorial_music_discoverBoneCarving = "Discover bone carving",
    tutorial_music_playFlute = "Play a musical instrument", --0.3.0 changed to "musical instrument" as drums and balafons now count for completion too
    
    -- routes
    tutorial_title_routes = "Moving resources around", --0.5 changed from "Routes and logistics"
    tutorial_routes_storyText = "Sapiens can move resources from one storage area to another with send and receive orders.\n\nThis is useful for distributing resources to where they are needed or to transfer resources over large distances.", --0.5 routes have been replaced with send/receive orders
    tutorial_routes_create = "Create a send or receive order", --0.5 changed route to send or receive order
    tutorial_routes_create_subtitle_a = "- Click on a storage area, and select \"Manage Storage\"", --0.5
    tutorial_routes_create_subtitle_b = "- Click either the the \"Send items\" or \"Receive items\" button and then select another storage area", --0.5
    tutorial_routes_doTransfer = "Transfer any item from one storage area to another",
    
    -- paths
    tutorial_title_paths = "Paths and Roads",
    tutorial_paths_storyText = "Sapiens can move faster on paths, which makes your tribe more efficient.\n\nDifferent path types have different speed increases, with tile paths being the fastest.",
    tutorial_paths_buildXPaths = function(values)
        return string.format("Construct %d path segments", values.count) 
    end,
    
    -- woodBuilding
    tutorial_title_woodBuilding = "Building with wood",
    tutorial_woodBuilding_storyText = "Thatch huts are better than nothing, but your tribe will need to start building with more advanced materials if their new civilization is to stand the test of time.",
    tutorial_woodBuilding_chopTree = "Chop down a tree",
    tutorial_woodBuilding_splitLog = "Split a log",
    tutorial_woodBuilding_buildWall = "Build something using split logs", --0.3.0 -changed from "build a split log wall" as any split log buildable now counts
    -- advancedTools
    tutorial_title_advancedTools = "Crafting advanced tools",
    tutorial_advancedTools_storyText = "By attaching simple rock tools to a wooden handle, your tribe can make more advanced tools that can last longer, make some tasks faster, and unlock the ability to hunt larger prey.",
    tutorial_advancedTools_driedFlax = function(values)
        return string.format("Find, harvest, and store %d dried flax", values.count) 
    end,
    tutorial_advancedTools_twine = function(values)
        return string.format("Craft and store %d twine", values.count) 
    end,
    tutorial_advancedTools_pickAxe = "Craft a pick axe",
    tutorial_advancedTools_spear = "Craft a spear",
    tutorial_advancedTools_hatchet = "Craft a hatchet",
    -- cookingMeat
    tutorial_title_cookingMeat = "Cooking meat",
    tutorial_cookingMeat_storyText = "After a successful hunt, your sapiens need to prepare the carcass to make it ready to eat. To do this, they'll need to butcher and then cook the meat.",
    tutorial_cookingMeat_butcher = "Butcher a carcass",
    tutorial_cookingMeat_cook = "Cook some meat",
    -- worldMap
    tutorial_title_worldMap = "World Map",
    tutorial_worldMap_task = "View the world from above with",
    -- recruitment
    tutorial_title_recruitment = "Recruitment",
    tutorial_recruitment_storyText = "Sometimes nomadic tribes will wander through the area, or come looking for food.\n\nThis is a good opportunity to grow the tribe, as many will decide to join if we invite them.",
    tutorial_recruitment_task = "Invite a visitor to join the tribe",

    -- orderLimit
    tutorial_title_orderLimit = "Order Limit",
    tutorial_orderLimit_storyText = function(values)
        return string.format("There is a tribe-wide limit of %d orders per sapien. After that, they will ignore lower priority orders until others have been completed.\n\nYou can prioritize orders in the radial menu.", --0.4.1 modified due to change in prioritization mechanics
            values.allowedPlansPerFollower)
    end,
    tutorial_orderLimit_task = "Prioritize any order", --0.4.1 modified due to change in prioritization mechanics
    
    -- notifications
    tutorial_title_notifications = "Notifications",
    tutorial_notifications_task = "Zoom to the most recent notification",

    --food poisoning added 0.3.0
    tutorial_title_foodPoisoning = "Food Poisoning",
    tutorial_foodPoisoning_storyText = "Sapiens can get food poisoning if raw and cooked meat are stored together.\n\nYou can prevent this by managing storage areas to only allow certain types of objects to be stored.",
    tutorial_foodPoisoning_configureRawMeat = "Set a storage area to only allow raw meat types",
    tutorial_foodPoisoning_configureCookedMeat = "Set a storage area to only allow cooked meat types",
    --/0.3.0

    -- completion
    tutorial_title_completion = "Tutorial Complete!",
    tutorial_completion_storyText = "Well done!\n\nYour tribe is only just getting started, but from here you are on your own.\n\nContinue to explore, craft, and investigate, and advance and grow your tribe. Look after your sapiens, build a bustling town, lead your tribe to a new and prosperous future.\n\nGood luck!",

    --done
    tutorial_subtitle_movement = "Movement:",
    tutorial_subtitle_zoom = "Zoom:",
    tutorial_subtitle_movementSpeed = "Move faster or slower:",
    tutorial_title_worldNavigation = "World Navigation",
    tutorial_title_investigate = "Investigation and Breakthroughs",
    tutorial_subtitle_investigateLine1 = "Investigating items leads to breakthroughs which unlock new things to craft and build.",
    tutorial_subtitle_investigateLine2 = "Select a rock or branch and investigate it.",
    buildContext_title = "Build Controls",
    buildContext_placeTitle = "Place: ",
    buildContext_place = "Place",
    buildContext_placeRefine = "Place and refine: ",
    buildContext_placeWithoutBuild = "Place without issuing build order: ",
    buildContext_cancel = "Cancel: ",
    buildContext_rotate = "Rotate: ",
    buildContext_rotate90 = "Rotate 90 degrees: ",
    buildContext_moveXZ = "Move horizontally: ",
    buildContext_moveY = "Move up/down: ",
    buildContext_disableSnapping = "Disable Snapping: ",

    --mouse
    mouse_left = "Left mouse button",
    mouse_right = "Right mouse button",
    mouse_left_drag = "Drag with ",
    mouse_right_drag = "Drag with right mouse",
    mouse_wheel = "Mouse wheel",
    creditsText_dave = "Created by Dave Frampton",
    creditsText_music = "Original soundtrack by John Konsalakis & Dave Frampton",
    creditsText_soundtrackLinkText = "Soundtrack details",
    creditsText = [[
Voice Acting by Emma Frampton, Ethan Frampton, & Dave Frampton
3D Models & Animations: Paddy Benson & Dave Frampton
Community Management: Milla Koutsos
Promotional Illustrations by Jérémy Forveille
Atmosphere rendering based on the work by Eric Bruneton
Audio Engine: FMOD Studio by Firelight Technologies Pty Ltd.
Physics: Bullet Physics
Serialization: Cereal - Grant, W. Shane and Voorhies, Randolph (2017)
Networking: Enet - Lee Salzman
Sapiens uses the amazing LuaJIT library by Mike Pall
Sapiens also uses LuaBridge by Nathan Reed, Vinnie Falco and others
Vocals in Sapiens are in "toki pona", the constructed language by Sonja Lang - tokipona.org

Many thanks for the huge support, testing, feedback and help from many others. An especially large thanks goes to the alpha testers, and also members of the community Discord server, and those who gave feedback on the devlog videos on YouTube. I couldn't have made Sapiens without you.

And most of all, thank you to my amazing wife Emma, who supported our family and me through this very long period of development, sacrificing her own career to give me the time to work on mine. This game is every bit as much the result of Emma's hard work, sacrifice, and dedication as it is mine.
]],

    -- orderStatus
    -- values for these function usally include .name, the noun variant of the inProgressName. Also planName, which is the name of the plan, instead of the in-progress variant provided with planText.

    orderStatus_deliverTo = function(values)
        return values.inProgressName .. " " .. values.heldObjectName .. " to " .. values.retrievedObjectName
    end,
    orderStatus_deliverForConstruction = function(values)
        if values.planText then
            if values.retrievedObjectConstructableTypeName then
                return values.inProgressName .. " " .. values.heldObjectName .. " for " .. values.planText .. " " .. values.retrievedObjectConstructableTypeName
            else
                return values.inProgressName .. " " .. values.heldObjectName .. " for " .. values.planText
            end
        end
        return values.inProgressName .. " " .. values.heldObjectName .. " for construction at " .. values.retrievedObjectName
    end,
    orderStatus_deliverForFuel = function(values)
        return values.inProgressName .. " " .. values.heldObjectName .. " for fuel at " .. values.retrievedObjectName
    end,
    orderStatus_pickupObject = function(values)
        if values.planText then
            if values.retrievedObjectConstructableLocationName then
                return values.inProgressName .. " " .. values.pickupObjectName .. " for " .. values.planText .. " at " .. values.retrievedObjectConstructableLocationName
            elseif values.retrievedObjectConstructableTypeName then
                return values.inProgressName .. " " .. values.pickupObjectName .. " for " .. values.planText .. " " .. values.retrievedObjectConstructableTypeName
            else
                return values.inProgressName .. " " .. values.pickupObjectName .. " for " .. values.planText
            end
        end
        return values.inProgressName .. " " .. values.pickupObjectName
    end,
    orderStatus_pickupObjectToEat = function(values)
        return values.inProgressName .. " " .. values.pickupObjectName .. " to eat"
    end,
    orderStatus_pickupObjectToWear = function(values)
        return values.inProgressName .. " " .. values.pickupObjectName .. " to wear"
    end,
    orderStatus_pickupObjectToPlayWith = function(values)
        return values.inProgressName .. " " .. values.pickupObjectName .. " to play with"
    end,
    orderStatus_crafting = "crafting",
    orderStatus_research = "research",
    orderStatus_moveObjectForAction = function(values)
        return "Moving " .. values.objectName .. " for " .. values.action
    end,
    orderStatus_talkingTo = function(values)
        return "Talking to " .. values.objectName
    end,
    --b13
    --[[orderStatus_getLogisticsPostfix = function(values) --deprecated 0.5.0.78
        return " (" .. values.routeName .. ")"
    end,
    orderStatus_addLogisticsPostfix = function(values) --deprecated 0.5.0.78
        return values.inProgressName .. " " .. values.logisticsPostfix
    end,]]
    orderStatus_buildConstructablePlan = function(values)
        return values.planText .. " " .. values.retrievedObjectConstructableTypeName
    end,
    --/b13

    --0.3.0
    
    orderStatus_butchering = "butchering",

    orderStatus_getObjectNameSingleGeneric = function(values) --for things without names. eg chopping "a coconut tree"
        return getAorAn(values.objectName) .. " " .. values.objectName
    end,
    orderStatus_getObjectNameSingleNamed = function(values) -- for named things eg. hunting "Sam The Mammoth"
        return values.objectName
    end,
    orderStatus_getObjectNamePlural = function(values) 
        return values.objectPlural
    end,

    orderStatus_addObjectNameSingleGeneric = function(values) --for things without names. eg chopping "a coconut tree"
        return values.inProgressName .. " " .. getAorAn(values.objectName) .. " " .. values.objectName
    end,
    orderStatus_addObjectNameSingleNamed = function(values) -- for named things eg. hunting "Sam The Mammoth"
        return values.inProgressName .. " " .. values.objectName
    end,
    orderStatus_addObjectNamePlural = function(values) 
        return values.inProgressName .. " " .. values.objectPlural
    end,

    -- 0.3.3
    orderStatus_addWarmingUp = function(values) 
        return values.currentText .. " (Warming up)"
    end,
    --/0.3.0

    --0.4
    orderStatus_deliverToCompost = function(values)
        return values.inProgressName .. " " .. values.heldObjectName .. " at " .. values.retrievedObjectName
    end,
    --/0.4


    ---- quests, all below is added in 0.5

    quest_motivation_story_craftable = function(values)
        return "The " .. values.tribeName .. " tribe is looking for " .. values.count .. " " .. values.resourcePlural 
        .. ". If we create a route and deliver these to the marked storage area in their village, it will increase our standing with them."
    end,

    quest_timeLimit = "Time Limit",
    quest_completionReward = "Completion Reward",
    quest_failurePenalty = "Failure Penalty",

    quest_resource = "Resources",
    quest_knowledge = "Knowledge",
    quest_findSapien = "Lost Sapien",
    quest_treatSick = "Medicine",
    quest_repairBuilding = "Repairs",
    quest_huntMob = "Hunting",

    quest_resource_summaryTitle = "Deliver Resources",
}

local function getTimeSplit(durationSeconds, dayLength, yearLength)
    local result = {
        years = 0,
        days = 0,
        hours = 0,
    }
    
    if durationSeconds >= yearLength then
        result.years = math.floor(durationSeconds / yearLength)
        durationSeconds = durationSeconds - result.years * yearLength
    end
    
    if durationSeconds >= dayLength then
        result.days = math.floor(durationSeconds / dayLength)
        durationSeconds = durationSeconds - result.days * dayLength
    end
    
    if durationSeconds > 0 then
        result.hours = math.floor(durationSeconds / dayLength * 24)
    end

    --mj:log("getTimeSplit durationSeconds:", durationSeconds, " result:", result, " dayLength:", dayLength, " hourLength:", dayLength / 24)
    return result
end

local function getTimeDurationDescriptionFromSplitTime(timeSplit)
    local result = ""
    local empty = true
    if timeSplit.years > 0 then
        local postfix = " year"
        if timeSplit.years > 1 then
            postfix = " years"
        end
        result = mj:tostring(timeSplit.years) .. postfix
        empty = false
    end

    if timeSplit.days > 0 then
        local postfix = " day"
        if timeSplit.days > 1 then
            postfix = " days"
        end

        if not empty then
            result = result .. ", "
        end
        
        result = result .. mj:tostring(timeSplit.days) .. postfix
        empty = false
    end
    
    if timeSplit.hours > 0 then
        local postfix = " hour"
        if timeSplit.hours > 1 then
            postfix = " hours"
        end

        if not empty then
            result = result .. ", "
        end
        
        result = result .. mj:tostring(timeSplit.hours) .. postfix
        empty = false
    else 
        if empty then
            return "< 1 hour"
        end
    end

    return result
end

function localizations.getTimeDurationDescription(durationSeconds, dayLength, yearLength)
    local timeSplit = getTimeSplit(durationSeconds, dayLength, yearLength)
    return getTimeDurationDescriptionFromSplitTime(timeSplit)
end

function localizations.getTimeRangeDescription(durationSecondsMin, durationSecondsMax, dayLength, yearLength)
    local minHourCount = math.floor(durationSecondsMin / dayLength * 24)
    local maxHourCount = math.floor(durationSecondsMax / dayLength * 24)
    if minHourCount == maxHourCount then
        return localizations.getTimeDurationDescription(durationSecondsMin, dayLength, yearLength)
    end

    if minHourCount == 0 then
        local maxDescription = localizations.getTimeDurationDescription(durationSecondsMax, dayLength, yearLength)
        return "< " .. maxDescription
    end
    
    local timeSplitMin = getTimeSplit(durationSecondsMin, dayLength, yearLength)
    local timeSplitMax = getTimeSplit(durationSecondsMax, dayLength, yearLength)

    if (timeSplitMin.years == 0 and timeSplitMax.years == 0) then
        if (timeSplitMin.days == 0 and timeSplitMax.days == 0) then
        return mj:tostring(timeSplitMin.hours) .. " - " .. mj:tostring(timeSplitMax.hours) .. " hours"
        end
        if (timeSplitMin.hours == 0 and timeSplitMax.hours == 0) then
        return mj:tostring(timeSplitMin.days) .. " - " .. mj:tostring(timeSplitMax.days) .. " days"
        end
    elseif (timeSplitMin.days == 0 and timeSplitMax.days == 0) and (timeSplitMin.hours == 0 and timeSplitMax.hours == 0) then
        return mj:tostring(timeSplitMin.years) .. " - " .. mj:tostring(timeSplitMax.years) .. " years"
    end

    local minDescription = getTimeDurationDescriptionFromSplitTime(timeSplitMin)
    local maxDescription = getTimeDurationDescriptionFromSplitTime(timeSplitMax)

    return minDescription .. " - " .. maxDescription
end

function localizations.getBiomeForestDescription(biomeTags)
    local typeString = nil

    if biomeTags.coniferous then
        if biomeTags.birch then
            typeString = "pine & birch"
        elseif biomeTags.bamboo then
            typeString = "pine & bamboo"
        else
            typeString = "pine"
        end
    else 
        typeString = "birch"
    end
    
    if not typeString then
        return "No trees."
    end

    local forestString = true
    if biomeTags.mediumForest then
        forestString = string.format("%s forest.", mj:capitalize(typeString))
    elseif biomeTags.denseForest then
        forestString = string.format("Dense %s forest.", typeString)
    elseif biomeTags.sparseForest then
        forestString = string.format("%s trees.", mj:capitalize(typeString))
    elseif biomeTags.verySparseForest then
        forestString = string.format("Very few %s trees.", typeString)
    else
        return "No trees."
    end

    return forestString

end

function localizations.getBiomeMainDescription(biomeTags)
    local descriptionString = nil
    if biomeTags.tropical then
        descriptionString = "Tropical"
    elseif biomeTags.polar or biomeTags.icecap or biomeTags.heavySnowSummer or biomeTags.medSnowSummer or biomeTags.lightSnowSummer then
        descriptionString = "Icey"
    elseif biomeTags.temperate then
        descriptionString = "Temperate"
    elseif biomeTags.dry then
        descriptionString = "Dry"
    end

    local mainAdded = false

    local function addMain(value)
        if descriptionString then
            descriptionString = descriptionString .. " " .. value .. "."
        else
            descriptionString = mj:capitalize(value) .. "."
        end
        mainAdded = true
    end

    if biomeTags.desert then
        addMain("desert")
    elseif biomeTags.steppe then
        addMain("steppe")
    elseif biomeTags.rainforest then
        addMain("rainforest")
    elseif biomeTags.savanna then
        addMain("savanna")
    elseif biomeTags.tundra then
        addMain("tundra")
    end

    if not mainAdded then
        if not descriptionString then
        return ""
        end
        return descriptionString .. "."
    end
    return descriptionString
end

function localizations.getBiomeTemperatureDescription(biomeTags)
    
    local descriptionString = nil

    if biomeTags.temperatureSummerVeryHot then
        descriptionString = "Very Hot Summer."
    elseif biomeTags.temperatureSummerHot then
        descriptionString = "Hot Summer."
    elseif biomeTags.temperatureSummerCold then
        descriptionString = "Cold Summer."
    elseif biomeTags.temperatureSummerVeryCold then
        descriptionString = "Very Cold Summer."
    else
        descriptionString = "Moderate Summer."
    end
    if biomeTags.temperatureWinterVeryHot then
        descriptionString = descriptionString .. " Very Hot Winter."
    elseif biomeTags.temperatureWinterHot then
        descriptionString = descriptionString .. " Hot Winter."
    elseif biomeTags.temperatureWinterCold then
        descriptionString = descriptionString .. " Cold Winter."
    elseif biomeTags.temperatureWinterVeryCold then
        descriptionString = descriptionString .. " Very Cold Winter."
    else
        descriptionString = descriptionString .. " Moderate Winter."
    end

    return descriptionString
end

function localizations.getBiomeFullDescription(biomeTags) --b13
    return localizations.getBiomeMainDescription(biomeTags) .. " " .. localizations.getBiomeForestDescription(biomeTags) .. " " .. localizations.getBiomeTemperatureDescription(biomeTags)
end

--mj:log("localizations count:", #(localizations.localizations))
        
return localizations