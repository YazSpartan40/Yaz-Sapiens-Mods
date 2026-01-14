# Arsenic Bronze Mod - Complete Game Functionality Documentation

**Target Audience**: Mod Developers  
**Purpose**: Technical reference for all systems, objects, and mechanics implemented

---

## Overview

The Arsenic Bronze mod adds a complete metallurgy system centered around arsenic bronze alloy, including ore spawning, smelting with poisoning mechanics, tool crafting, and performance bonuses. This document details every technical implementation.

---

## Game Objects

### Terrain Types
- **`terrain_arsenicOre`** - Mineable arsenic ore deposits
  - Spawns as random extra output from copper/tin ore (10% chance)
  - Spawns as random extra output from rock types (1% chance)
  - Rock types: rock, limestone, graniteRock, marbleRock, redRock, sandstoneYellowRock, sandstoneRedRock, sandstoneOrangeRock, sandstoneBlueRock, lapisRock

### Resources
**Base Resources:**
- **`arsenicOre`** - Raw arsenic ore (resource.types)
- **`arsenicBronzeIngot`** - Smelted alloy ingot (1 arsenicOre + 1 tinOre + 1 copperOre → 3 ingots)

**Tool Heads (Kiln-forged, require blacksmithing skill):**
- **`arsenicAxehead`** - Has toolUsages: treeChop + dig
- **`arsenicKnife`** - Has toolUsages: carving + butcher + weaponKnife  
- **`arsenicChisel`** - Has toolUsages: softChiselling + hardChiselling + carving
- **`arsenicSpearhead`** - No toolUsages (assembly component only)
- **`arsenicHammerhead`** - No toolUsages (assembly component only)
- **`arsenicPickaxehead`** - No toolUsages (assembly component only)

**Assembled Tools (Craft area, require toolAssembly skill):**
- **`arsenicAxe`** (arsenicAxehead + branch + flaxTwine) - toolUsages: treeChop with 2.0x speed
- **`arsenicSpear`** (arsenicSpearhead + branch + flaxTwine) - toolUsages: weaponSpear with 2.0x damage
- **`arsenicHammer`** (arsenicHammerhead + branch + flaxTwine) - toolUsages: hammering only
- **`arsenicPickaxe`** (arsenicPickaxehead + branch + flaxTwine) - toolUsages: dig (2.0x speed) + mine (1.0x speed)

### Game Objects
All resources above also registered as gameObject types with matching keys (e.g., `gameObject.types.arsenicOre`).

### Storage Areas
- **`arsenicOreStorage`** - Stores arsenicOre
- **`arsenicBronzeIngotStorage`** - Stores arsenicBronzeIngot
- **`arsenicComponentStorage`** - Stores all tool heads (axehead, knife, chisel, spearhead, hammerhead, pickaxehead)
- **`arsenicToolStorage`** - Stores assembled tools (axe, spear, hammer, pickaxe)

All use Hammerstone framework with 2x2 layout (4 storage slots).

### Craftables
**Smelting (brickKiln):**
- **`arsenicBronzeIngot`** - Requires crucible, blacksmithing skill
- **`arsenicAxehead`** - Blacksmithing skill
- **`arsenicKnife`** - Blacksmithing skill
- **`arsenicChisel`** - Blacksmithing skill
- **`arsenicSpearhead`** - Blacksmithing skill (assembly component)
- **`arsenicHammerhead`** - Blacksmithing skill (assembly component)
- **`arsenicPickaxehead`** - Blacksmithing skill (assembly component)

**Assembly (craftArea):**
- **`arsenicAxe`** - ToolAssembly skill
- **`arsenicSpear`** - ToolAssembly skill
- **`arsenicHammer`** - ToolAssembly skill
- **`arsenicPickaxe`** - ToolAssembly skill

### Research
- **`arsenicAlloy`** - Research type
  - Requires: blacksmithing skill
  - Trigger: Pickup arsenicOre
  - Unlocks: arsenicBronzeIngot, arsenicKnife, arsenicChisel
  - Tool heads (spear/hammer/pickaxe/axe) added to existing toolAssembly research

### Materials
- **`arsenicOre`** - Material for terrain (vec3(0.60, 0.62, 0.60), roughness 0.80, metal 0.0)
- **`terrain_arsenicOre`** - Terrain material variant
- **`arsenicBronze`** - Metal material (vec3(0.68, 0.70, 0.68), roughness 0.10, metal 1.0)
  - Silver-white metallic appearance, distinct from bronze

### Models
All models use **materialRemap system** - no custom .glb files required.

**Model Remaps (base → arsenic variant):**
- `ingot` → `arsenicBronzeIngot` (metal: arsenicBronze)
- `ore` → `arsenicOre` (ore: arsenicOre)
- `metalAxeHead` → `arsenicAxeHead` (metal: arsenicBronze)
- `metalPickaxeHead` → `arsenicPickaxeHead` (metal: arsenicBronze)
- `metalSpearHead` → `arsenicSpearHead` (metal: arsenicBronze)
- `metalHammerHead` → `arsenicHammerHead` (metal: arsenicBronze)
- `metalKnife` → `arsenicKnife` (metal: arsenicBronze)
- `metalChisel` → `arsenicChisel` (metal: arsenicBronze)
- `stoneHatchet` → `arsenicHatchet` (metal: arsenicBronze)
- `stonePickaxe` → `arsenicPickaxe` (metal: arsenicBronze)
- `stoneSpear` → `arsenicSpear` (metal: arsenicBronze)
- `stoneHammer` → `arsenicHammer` (metal: arsenicBronze)
- `stoneHatchetBuild` → `arsenicHatchetBuild` (metal: arsenicBronze)
- `stonePickaxeBuild` → `arsenicPickaxeBuild` (metal: arsenicBronze)
- `stoneSpearBuild` → `arsenicSpearBuild` (metal: arsenicBronze)
- `stoneHammerBuild` → `arsenicHammerBuild` (metal: arsenicBronze)

---

## Tool Properties & Balance

### Multipliers
```lua
arsenicSpeedMultiplier = 1.6      -- vs bronze 1.4
arsenicDamageMultiplier = 1.6     -- vs bronze 1.4
arsenicDurabilityMultiplier = 5.0 -- vs bronze 4.0
```

### Tool Usage Patterns
**Standalone Tool Heads:**
- arsenicAxehead: treeChop + dig (both use speed multiplier)
- arsenicKnife: carving + butcher + weaponKnife (damage for weapon)
- arsenicChisel: softChiselling + hardChiselling + carving

**Component Heads (NO toolUsages):**
- arsenicSpearhead, arsenicHammerhead, arsenicPickaxehead
- Must be assembled before use

**Assembled Tools:**
- arsenicAxe: treeChop with `2.0 * arsenicSpeedMultiplier`
- arsenicSpear: weaponSpear with `2.0 * arsenicDamageMultiplier`
- arsenicHammer: hammering only (no mine usage)
- arsenicPickaxe: dig with `2.0 * arsenicSpeedMultiplier`, mine with `1.0 * arsenicSpeedMultiplier`

---

## File Structure & Implementation

### `/scripts/common/`

#### **`terrainTypes.lua`** (loadOrder: 3)
**Type**: Table injection  
**Method**: Direct table.insert into `terrainTypes.baseTypes[oreType].randomExtraOutputs`

**Spawning Configuration:**
```lua
copperOre: 10% arsenicOre chance
tinOre: 10% arsenicOre chance
rock types (10 variants): 1% arsenicOre chance
```

#### **`biomes.lua`** (loadOrder: 1)
**Type**: Table injection  
**Method**: Direct table.insert into `biome.types[biomeType].terrainTypes`

**Adds arsenicOre terrain to all biomes:**
- temperate, cold, alpine, polar, desert, tropics, jungle, desert, lush

#### **`resource.lua`** (loadOrder: 1)
**Type**: Table injection  
**Method**: mj:insertIndexed into resource.types

**Resources Created:**
- All 12 arsenic resources (ore, ingot, 6 tool heads, 4 assembled tools)
- Each resource includes: classification, plural form, storageBox references

#### **`gameObject.lua`** (loadOrder: 1)
**Type**: Table injection  
**Method**: mj:insertIndexed into gameObject.types

**Game Objects Created:**
- Corresponding gameObject for each resource
- Sets modelName, displayModelName, objectViewZOffsetMultiplier

#### **`storage.lua`** (loadOrder: 1)
**Type**: Hammerstone integration  
**Method**: Direct modification of hammerstone.storage

**Storage Types Created:**
- 4 storage areas (ore, ingot, components, tools)
- Each uses 2x2 layout (4 slots) with allowMixed=true

#### **`craftable.lua`** (loadOrder: 1)
**Type**: Table injection + Hammerstone integration  
**Method**: mj:insertIndexed into constructable.types + hammerstone.craftAreaGroup registration

**Craftables Created:**
- 1 ingot smelting (crucible + kiln)
- 6 tool head forgings (kiln)
- 4 tool assemblies (craft area)

**Special Features:**
- All kiln craftables use `requiredSupportObjectKey = "crucible"`
- Tool heads use blacksmithing skill, assembled tools use toolAssembly skill
- Assembled tools require: tool head + branch + flaxTwine

#### **`research.lua`** (loadOrder: 1)
**Type**: Mixed (new research + existing research modification)  
**Method**: 
- New: mj:insertIndexed for arsenicAlloy research
- Modification: Table injection into existing toolAssembly research

**arsenicAlloy Research:**
- Classification: general
- Skill: blacksmithing
- Clue: arsenicOre pickup
- Unlocks: arsenicBronzeIngot, arsenicKnife, arsenicChisel

**toolAssembly Research Additions:**
- 4 tool heads added to constructableTypeIndexesByBaseResourceTypeIndex
- 4 tool heads added to orderTypeIndexesByBaseObjectTypeIndex (for clickable discoveries)
- Calls `research_:updateDerivedInfo(research_.types.toolAssembly)` to rebuild cache

#### **`material.lua`** (loadOrder: 1)
**Type**: Table injection  
**Method**: mj:insertIndexed into material.types

**Materials Created:**
```lua
arsenicOre: vec3(0.60, 0.62, 0.60), roughness 0.80, metal 0.0
terrain_arsenicOre: (variant)
arsenicBronze: vec3(0.68, 0.70, 0.68), roughness 0.10, metal 1.0
```

#### **`model.lua`** (loadOrder: 1)
**Type**: Table modification (model.remapModels)  
**Method**: Direct table assignment to model.remapModels[baseModel][newModel]

**Remaps Created:**
- 16 total model remaps (ingot, ore, 6 heads, 2 small tools, 4 assembled, 4 build)
- All use `{ metal = "arsenicBronze" }` material override
- Assembled tools remap from **stone** tools (not bronze), matching vanilla pattern

#### **`inspectCraftPanel.lua`** (loadOrder: 2)
**Type**: Table injection  
**Method**: table.insert into inspectCraftPanel.itemLists[craftAreaIndex/kilnIndex]

**UI Integration:**
- 7 items added to brickKiln menu (ingot + 6 tool heads)
- 4 items added to craftArea menu (assembled tools)

#### **`notification.lua`** (loadOrder: 1)
**Type**: Function shadowing  
**Method**: Function wrapping (stores original, replaces with wrapper)

**Implementation:**
```lua
local originalTitleFunction = notification.types.minorFoodPoisoning.titleFunction
notification.types.minorFoodPoisoning.titleFunction = function(userData)
    -- Check for arsenicBronzeIngot + arsenicOre contamination
    if [arsenic detection logic] then
        return custom message
    end
    return originalTitleFunction(userData)
end
```

### `/scripts/server/`

#### **`terrainGen.lua`** (loadOrder: 1)
**Type**: Table injection  
**Method**: table.insert into terrainGen.resources array

**Adds arsenicOre to terrain generation:**
```lua
{
    key = "arsenicOre",
    colorMapKey = "rock",
    noiseScale = 0.001,
    threshold = 0.8,
    thresholdVsAltitude = vec2(-0.2, 0.0),
}
```

#### **`serverGOM.lua`** (loadOrder: 1)
**Type**: Function shadowing  
**Method**: Function wrapping with pre-hook

**Purpose**: Add arsenicOre research clue to oreDiscoveredFunction

**Implementation:**
```lua
local super_oreDiscoveredFunction = serverGOM.oreDiscoveredFunction
serverGOM.oreDiscoveredFunction = function(...)
    -- Pre-hook: Add arsenicAlloy research if arsenicOre discovered
    local result = super_oreDiscoveredFunction(...)
    -- Post-hook logic
    return result
end
```

### `/scripts/server/sapienAI/`

#### **`activeOrderAI.lua`** (loadOrder: 1)
**Type**: Function shadowing (completionFunction)  
**Method**: Function wrapping with post-hook

**Purpose**: Add arsenic poisoning mechanic to smelting

**Implementation:**
```lua
local super_smeltMetalCompletion = activeOrderAI.updateInfos[action.types.smeltMetal.index].completionFunction

local function arsenicBronzeSmeltMetalCompletionFunction(allowCompletion, sapien, orderObject, orderState, actionState, constructableType, requiredLearnComplete)
    -- Call vanilla completion (handles burns, item creation, etc.)
    super_smeltMetalCompletion(allowCompletion, sapien, orderObject, orderState, actionState, constructableType, requiredLearnComplete)
    
    -- Post-hook: Check if arsenicBronzeIngot was smelted
    if allowCompletion and constructableType.key == "arsenicBronzeIngot" then
        -- 40% chance of minorFoodPoisoning status effect
        -- Sends notification (caught by notification shadow)
        -- Adds treatFoodPoisoning plan
    end
end

activeOrderAI.updateInfos[action.types.smeltMetal.index].completionFunction = arsenicBronzeSmeltMetalCompletionFunction
```

**Poisoning Mechanics:**
- 40% chance per arsenicBronzeIngot smelted
- Uses RNG: `rng:randomInteger(math.floor(1.0 / 0.40))`
- Prevents duplicate poisoning (checks existing status effects)
- Duration: `sapienConstants.foodPoisoningDuration`
- Uses vanilla `statusEffect.types.minorFoodPoisoning` (but custom notification)

### `/localizations/en_us/`

#### **`localizations.lua`**
**Type**: Localization table  
**Method**: Direct table assignment

**Strings Provided:**
- Terrain names (1): terrain_arsenicOre
- Resource names (24): 12 resources × (singular + plural)
- Game object names (24): 12 objects × (singular + plural)
- Storage names (4): 4 storage areas
- Craftable names (33): 11 craftables × (name + plural + summary)
- Skill descriptions (2): blacksmithing skill override
- Research (3): arsenicAlloy (name + description + clue)
- Notifications (1): arsenicPoisoning (function returning concatenated string)

**Notification Function:**
```lua
notification_arsenicPoisoning = function(values)
    return values.name .. " fell ill from exposure to toxic arsenic fumes while smelting!"
end
```

### `/hammerstone/`

#### **`objects/build/` & `objects/craft/`**
**Type**: Hammerstone JSON descriptors (empty by design)

#### **`shared/materials.shared.json`**
**Type**: Hammerstone material descriptor (empty by design)

#### **`storage/*.json`**
**Type**: Hammerstone storage descriptors

**Files:**
- `arsenic_bronze_storage.json`
- `arsenic_storage.json`
- `iron_ingot_storage.json` (unused, from Iron Age template)
- `iron_ore_storage.json` (unused, from Iron Age template)

**Structure:**
```json
{
  "key": "arsenicOreStorage",
  "allowMixed": true,
  "inProgressDisplayGameObjectTypeKey": "storageArea",
  "path": "storageArea2x2",
  "modelName": "storageArea2x2",
  "builtDisplayGameObjectTypeKey": "storageArea"
}
```

---

## Technical Patterns & Best Practices

### Shadowing vs. Injection
**Injection (mj:insertIndexed or table.insert):**
- Adding new entries to existing tables
- Used for: resources, gameObjects, craftables, materials, research types

**Shadowing (Function Wrapping):**
- Preserving original function, wrapping with custom logic
- Used for: activeOrderAI.completionFunction, notification.titleFunction, serverGOM.oreDiscoveredFunction
- Pattern: `local super = original; newFunc = function(...) [pre-hook] super(...) [post-hook] end`

### Load Order Importance
- **terrainTypes.lua**: loadOrder 3 (after Iron Working's greenRock override)
- **inspectCraftPanel.lua**: loadOrder 2 (after craftable definitions)
- All others: loadOrder 1 (standard mod load)

### Model Remap Strategy
- Remap from **stone** tools (not bronze) for assembled tools
- This matches vanilla pattern where bronze remaps from stone
- Use `{ metal = "arsenicBronze" }` to override material slot in base model

### Research Integration
- New research for new content (arsenicAlloy)
- Modify existing research for familiar patterns (toolAssembly)
- **Must call** `research_:updateDerivedInfo()` after modifying existing research

### Hammerstone Integration
- Storage areas require JSON descriptors in `/hammerstone/storage/`
- Craftables at craft area registered via `hammerstone.craftAreaGroup.add()`
- Empty JSON files in other Hammerstone directories prevent errors

### Notification Customization
- Shadow existing notification type rather than creating new one
- Check userData fields to detect specific scenario
- Use function-based localizations for dynamic text

---

## Dependency Chain

```
terrainTypes.lua (spawning) → terrainGen.lua (world generation)
    ↓
biomes.lua (biome integration)
    ↓
resource.lua → gameObject.lua → model.lua → material.lua
    ↓
craftable.lua → storage.lua
    ↓
research.lua → serverGOM.lua (research clues)
    ↓
inspectCraftPanel.lua (UI)
    ↓
activeOrderAI.lua (poisoning) → notification.lua (custom message)
```

---

## Performance Considerations

- **Model Remaps**: Uses existing geometry, no extra GPU memory
- **Spawning**: Random checks on existing ore generation (minimal overhead)
- **Poisoning**: Only checked on smelt completion (infrequent event)
- **No Custom Assets**: All resources use vanilla model system

---

## Compatibility Notes

- **Hammerstone**: Required for storage and craft area systems
- **Load Order**: terrainTypes must load after Iron Working (loadOrder 3) if present
- **Vanilla Shadowing**: Compatible with other mods that don't shadow same functions
- **Model System**: No .glb files means no asset conflicts

---

## Testing Checklist

- [ ] Arsenic ore spawns in terrain (copper/tin 10%, rocks 1%)
- [ ] Ore appears with silver-white color
- [ ] Smelting produces 3 ingots from 1 arsenic + 1 tin + 1 copper
- [ ] 40% chance poisoning notification with custom text
- [ ] All tool heads craftable at kiln with correct models
- [ ] Tool heads show silver-white metal in UI and world
- [ ] Component heads (spear/hammer/pickaxe) cannot be used standalone
- [ ] Assembled tools craftable at craft area
- [ ] Assembled tools show silver-white metal components
- [ ] Assembled tools have correct tool usages
- [ ] Arsenic tools slightly better than bronze (1.6/1.6/5.0 vs 1.4/1.4/4.0)
- [ ] Research discoveries appear and are clickable
- [ ] Storage areas work for all item types

---

## Version Information

**Current Version**: 1.0  
**Sapiens Game Version**: Compatible with vanilla Sapiens mod system  
**Last Updated**: 2026-01-10
