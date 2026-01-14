

local objectSpawner = {
    spawners = {}
}

local complete = false


function objectSpawner:addObjectSpawner(addTable) --safe way to add
    if complete then
        mj:error("attempt to call objectSpawner:addObjectSpawner after objectSpawner:getObjectSpawners has already been called")
        error()
    end

    addTable.minSpawnObjectCount = addTable.minSpawnObjectCount or 1
    addTable.maxSpawnObjectCount = addTable.maxSpawnObjectCount or 1

    addTable.addLevel = addTable.addLevel or 2

    --mj:log("adding spawner:", addTable)

    table.insert(objectSpawner.spawners, addTable)
end


function objectSpawner:init(gameObject)

    objectSpawner:addObjectSpawner({
        objectTypeIndex = gameObject.types.manure.index,
        addLevel = 2, -- highest detail level is 1, which would mean objects are not spawned until the terrain is subdivided to that level. Large objects especially will pop in close at level 1. Small objects usually 2, large at 3. max 7.
        requiredBiomeTags = {}, -- if none of these are present, it won't spawn. If any single one of these tags is present, it can spawn.
        disallowedBiomeTags = {}, -- if any of these are present, it won't spawn
        minSpawnObjectCount = 1, --number of objects spawned per cluster
        maxSpawnObjectCount = 4,
        spawnChanceFraction = 0.002, --chance per triangle of a cluster spawning. 1.0 = 100%, every triangle at the specified subdivision level would spawn a cluster
        minAltitude = 0.0, --above sea level. This is in prerender units (meters / 8388608.0)
        maxAltitude = nil,
    })

    objectSpawner:addObjectSpawner({
        objectTypeIndex = gameObject.types.bone.index,
        addLevel = 2,
        requiredBiomeTags = {},
        disallowedBiomeTags = {},
        minSpawnObjectCount = 1,
        maxSpawnObjectCount = 4,
        spawnChanceFraction = 0.002,
        minAltitude = 0.0,
        maxAltitude = nil,
    })
end

function objectSpawner:getObjectSpawners() --this is called by the engine after initialization
    --mj:log("objectSpawner:getObjectSpawners called")
    complete = true
    return objectSpawner.spawners
end

return objectSpawner