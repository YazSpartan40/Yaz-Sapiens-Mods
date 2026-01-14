# SAPIENS MODDING TRUTHS

Essential patterns and anti-patterns for creating Sapiens mods. These truths prevent common mistakes and ensure compatibility with the game's architecture.

---

## Core Load Mechanics

**TRUTH #1: loadOrder values DO NOT control game loading sequence**
- The game determines its own internal loading order
- loadOrder values are just identifiers/metadata
- NEVER attempt to manipulate loadOrder to change when your mod files load
- The game controls the sequence - your job is to work within it

**TRUTH #2: There is NO way to impact load order of files within your mod**
- File loading sequence is predetermined by the game engine
- Server/common files load first → then mainThread files
- Mirror vanilla file structure to ensure your files load in the correct phase
- Work within the existing load order patterns

**TRUTH #3: Use the existing load order and make changes in files as they load**
- Don't fight the system - adapt to it
- If you need something available later, put it in the right file that loads at that time
- Example: UI modifications go in mainThread files, type definitions go in common files

---

## Type System & Registration

**TRUTH #4: Types are available in mainThread onload() but NOT at module load time**
- Server/common files register types (craftable.types, gameObject.types, etc.)
- MainThread files load AFTER server types are fully registered
- Access types inside onload() function, never at module top level
- Pattern:
```lua
function mod:onload(module)
    local constructable = mjrequire "common/constructable"
    local gameObject = mjrequire "common/gameObject"
    -- Now safe to access types
    local myType = constructable.types.myItem.index
end
```

**TRUTH #5: addGameObjectInfo in craftable.lua creates gameObjects automatically**
- When you register a craftable with `addGameObjectInfo`, it registers the gameObject too
- Don't manually register the same object in gameObject.lua
- Causes "overwriting object type" warnings and potential conflicts
- Only register base objects (ores, resources) in gameObject.lua

**TRUTH #6: Research gating requires ALL recipe ingredients in constructableTypeIndexesByBaseResourceTypeIndex**
- Vanilla pattern: bronze requires BOTH copper AND tin
- Your pattern: arsenic bronze requires ALL THREE (arsenicOre, tinOre, copperOre)
- Missing any ingredient means research won't unlock the craftable when that ingredient is discovered
- Example:
```lua
constructableTypeIndexesByBaseResourceTypeIndex = {
    [resource.types.arsenicOre.index] = constructable.types.arsenicBronzeIngot.index,
    [resource.types.tinOre.index] = constructable.types.arsenicBronzeIngot.index,
    [resource.types.copperOre.index] = constructable.types.arsenicBronzeIngot.index,
}
```

---

## Craftable Flags & Patterns

**TRUTH #7: dontPickUpRequiredTool = true is ONLY for smelting operations**
- Use for ingots/bars that are smelted (bronzeIngot, arsenicBronzeIngot, etc.)
- Do NOT use for tool heads (axehead, knife, etc.)
- Tool heads should be picked up and assembled with handles
- Vanilla pattern: bronzeKnife doesn't have this flag

**TRUTH #8: Tool assembly requires gameObjectTypeName for tool heads**
- Tool heads need `gameObjectTypeName` set to the assembled tool type
- Example: `gameObjectTypeName = "arsenicAxe"` on arsenicAxehead craftable
- This tells the game what type to create when the tool head is assembled with a handle
- Without it, assembly won't work properly

---

## File Structure & Mirroring

**TRUTH #9: Only files mirroring vanilla structure will load**
- Can't create custom file paths like mainThread/arsenicBronzeUI.lua
- Must use existing vanilla file paths like mainThread/ui/inspect/inspectCraftPanel.lua
- Game looks for specific file paths - custom paths are ignored
- Check vanilla game files to see what paths exist

**TRUTH #10: Mirror vanilla patterns for consistency and compatibility**
- Study how vanilla implements similar features
- Copy the pattern, adapt for your content
- Bronze → Arsenic Bronze: same pattern, different materials
- Reduces bugs and ensures game engine compatibility

---

## Common Patterns

**TRUTH #11: Shadowing FUNCTIONS vs modifying TABLES**
- **Modify tables directly** when you just need to add/change data:
  - Example: Adding items to `inspectCraftPanel.itemLists[kilnIndex]`
  - Pattern: `table.insert(existingTable, newValue)`
  - Simpler, less error-prone
  
- **Shadow functions** when you need to change behavior/logic:
  - Example: Replacing how `inspectCraftPanel.load()` processes data
  - Pattern: Save original, call it, modify result
  ```lua
  local original_function = module.functionName
  module.functionName = function(...)
      local result = original_function(...)
      -- modify result or behavior
      return result
  end
  ```
  
- **Rule of thumb:** If it's a table/array of data → modify directly. If it's a function with logic → shadow it.

**TRUTH #12: Type access in mainThread - always in onload()**
- Types registered in server/common phase are available in mainThread onload
- Never access types at module top level in mainThread files
- Pattern that always works:
```lua
local mod = {
    loadOrder = 1
}

function mod:onload(inspectCraftPanel)
    -- Safe to require and access types here
    local constructable = mjrequire "common/constructable"
    local gameObject = mjrequire "common/gameObject"
    
    local myType = constructable.types.myItem.index
    -- work with types...
    
    return inspectCraftPanel
end

return mod
```

**TRUTH #13: DO NOT use Hammerstone framework**
- **Why avoid it:**
  - Inflexible - forces specific patterns that may not fit your needs
  - Slow to update - lags behind game updates, can break your mod
  - Adds unnecessary complexity - another layer to debug and understand
  - Not needed for most mods

- **Use simple mod pattern instead:**
```lua
local mod = {
    loadOrder = 1
}

function mod:onload(module)
    -- Your modifications here
    return module
end

return mod
```

- Direct Sapiens API is more flexible, always up-to-date, and easier to debug
- Only use framework if you're building something that truly needs shared infrastructure

---

## API Naming & Validation

**TRUTH #14: NEVER guess API names - always verify against working code**
- Similar words have different meanings: `carve` ≠ `carving`, `assemble` ≠ `toolAssembly`
- Before writing any API reference, grep_search working mods to verify exact name
- Example mistake: `tool.types.carve` → Correct: `tool.types.carving`
- Example mistake: `actionSequence.types.assemble` → Correct: `actionSequence.types.toolAssembly`

**TRUTH #15: Use prevLoad pattern for modifying craftables and research**
- Don't use low-level APIs like `mj:insertIndexed(constructable.types, ...)`
- Use high-level helpers: `craftable:addCraftable()` with `addGameObjectInfo`
- Pattern:
```lua
function mod:onload(craftable)
    local prevLoad = craftable.load
    craftable.load = function(craftable_, gameObject, flora)
        prevLoad(craftable_, gameObject, flora)
        
        craftable:addCraftable("myItem", {
            -- configuration
            addGameObjectInfo = {
                -- creates gameObject automatically
            }
        })
    end
end
```

**TRUTH #16: Validated API names from vanilla/working mods**
**Tool Types (VERIFIED):**
```lua
tool.types.crucible
tool.types.treeChop
tool.types.dig
tool.types.hammering
tool.types.carving           -- NOT "carve"
tool.types.butcher
tool.types.weaponKnife
tool.types.softChiselling
tool.types.hardChiselling
tool.types.weaponSpear
tool.types.mine
tool.types.pound
```

**Action Sequence Types (VERIFIED):**
```lua
actionSequence.types.smeltMetal
actionSequence.types.toolAssembly  -- NOT "assemble"
```

**Tool Property Types (VERIFIED):**
```lua
tool.propertyTypes.speed
tool.propertyTypes.durability
tool.propertyTypes.damage
```

**TRUTH #17: Only register base resources in gameObject.lua**
- gameObject.lua should ONLY register ores and ingots (raw resources)
- Tool heads and assembled tools are created by craftable.lua via `addGameObjectInfo`
- Registering tools in both places causes conflicts and nil errors
- Pattern: 2-3 objects in gameObject.lua (ore, ingot), rest in craftable.lua

**TRUTH #18: Assembled tools need explicit outputObjectInfo**
- Don't rely solely on `addGameObjectInfo` for assembled tools
- Must include `outputObjectInfo` with `objectTypesArray`:
```lua
craftable:addCraftable("myAxe", {
    addGameObjectInfo = {
        modelName = "myAxe",
        resourceTypeIndex = resource.types.myAxe.index,
        preservesConstructionObjects = true,
        toolUsages = { ... }
    },
    outputObjectInfo = {
        objectTypesArray = { gameObject.typeIndexMap.myAxe }
    },
    buildSequence = craftable:createStandardBuildSequence(actionSequence.types.toolAssembly.index, nil),
    -- ...
})
```

**TRUTH #19: Two-step validation workflow for all new code**
1. **First: Manual comparison against working code**
   - Compare new code against vanilla scripts (best option)
   - If syntax only exists in mods, compare against working mods (Arsenic Bronze)
   - Use `grep_search` to find exact API patterns in working code
   - Copy exact names - never abbreviate or "improve" them

2. **Second: Run Python API validator**
   - Script location: `Sapiens Truths/validate_mod_api.py`
   - Command: `python validate_mod_api.py`
   - Validates all API names against vanilla scripts
   - Catches errors like `tool.types.pound` (doesn't exist, should be `hammering`)
   - Suggests closest matches using fuzzy matching
   - Run BEFORE testing in-game to catch errors early

**Validation workflow example:**
```bash
# Step 1: Grep search for pattern in working code
grep_search("tool.types.hammering", "Vanilla Scripts/**/*.lua")

# Step 2: Write code using exact pattern found

# Step 3: Validate before testing
cd "Sapiens Truths"
python validate_mod_api.py
# Fix any errors found

# Step 4: Test in-game
```

This two-step process catches API naming errors before runtime, saving hours of debugging.

---

## Summary

These 19 truths form the foundation of reliable Sapiens modding:
1. Game controls load order, not you
2. Can't change file loading sequence within mod
3. Work within existing load patterns
4. Types available in mainThread onload, not at module top
5. addGameObjectInfo creates gameObjects automatically
6. Research gating needs ALL recipe ingredients
7. dontPickUpRequiredTool only for smelting
8. Tool heads need gameObjectTypeName for assembly
9. Only vanilla file paths will load
10. Mirror vanilla patterns for compatibility
11. Modify tables directly, shadow functions when changing behavior
12. Always access types inside onload() in mainThread
13. Avoid Hammerstone - use simple mod pattern instead
14. NEVER guess API names - always verify against working code
15. Use prevLoad pattern for craftables and research
16. Validated API names: carving not carve, toolAssembly not assemble
17. Only register base resources in gameObject.lua
18. Assembled tools need explicit outputObjectInfo
19. Two-step validation: manual comparison + Python validator

Follow these truths to avoid the most common pitfalls and create stable, compatible Sapiens mods.

---

**Sample `modInfo` (canonical format)**

Use this `modInfo` snippet as the canonical example when creating new mods:

```lua
local modInfo = {
    name = "Arsenic Bronze",
    description = "**Arsenic Bronze** adds a dangerous new metallurgy path to Sapiens. Discover arsenic ore hidden within copper and tin deposits, then combine it to create arsenic bronze - an alloy that produces tools superior to regular bronze. But beware: the toxic fumes from smelting can poison your sapiens! Will the improved performance be worth the risk? **Hammerstone not required**",
    version = "1.0.0",
    type = "world",
    developer = "Yaz",
    loadOrder = 1,
    preview = "arsenic_bronze.jpg",
}

return modInfo
```

