local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4

local locale = mjrequire "common/locale"

local biome = {}

biome.difficulties = mj:enum {
    "veryEasy",
    "easy",
    "normal",
    "hard",
    "veryHard",
}

biome.difficultyColors = {
    [biome.difficulties.veryEasy] = vec4(0.0,0.75,0.0,1.0),
    [biome.difficulties.easy] = vec4(0.5,1.0,0.0,1.0),
    [biome.difficulties.normal] = vec4(0.75,1.0,0.0,1.0),
    [biome.difficulties.hard] = vec4(1.0,0.5,0.0,1.0),
    [biome.difficulties.veryHard] = vec4(0.75,0.0,0.0,1.0),
}

biome.difficultyStrings = {
    [biome.difficulties.veryEasy] = locale:get("misc_BiomeDifficulty_veryEasy"),
    [biome.difficulties.easy] = locale:get("misc_BiomeDifficulty_easy"),
    [biome.difficulties.normal] = locale:get("misc_BiomeDifficulty_normal"),
    [biome.difficulties.hard] = locale:get("misc_BiomeDifficulty_hard"),
    [biome.difficulties.veryHard] = locale:get("misc_BiomeDifficulty_veryHard"),
}


function biome:getDescriptionFromTags(biomeTags)
    if not biomeTags then
        mj:warn("no biomeTags passed to biome:getDescriptionFromTags")
        return ""
    end

    return locale:getBiomeFullDescription(biomeTags)
end

function biome:getWoodDifficultyLevel(biomeTags)
    if biomeTags.coniferous or biomeTags.birch then
        if biomeTags.mediumForest then
            return biome.difficulties.easy
        elseif biomeTags.denseForest then
            return biome.difficulties.veryEasy
        elseif biomeTags.sparseForest then
            return biome.difficulties.normal
        elseif biomeTags.verySparseForest then
            return biome.difficulties.hard
        end
    elseif biomeTags.bamboo then
        return biome.difficulties.hard
    end
    return biome.difficulties.veryHard
end

function biome:getDifficultyLevelFromTags(biomeTags)
    local difficulty = biome:getWoodDifficultyLevel(biomeTags)
    if difficulty < biome.difficulties.hard then
        if biomeTags.temperatureWinterCold or biomeTags.temperatureWinterVeryCold then
            difficulty = difficulty + 1
        end
    end
    return mjm.clamp(difficulty, biome.difficulties.veryEasy, biome.difficulties.veryHard)
end

function biome:getIsSuitableForTribeSpawn(biomeTags)
    if biomeTags.coniferous or biomeTags.birch or biomeTags.bamboo then
        return true
    end
    return false
end

local function getForestDescription(biomeTags)
    return locale:getForestDescription(biomeTags)
end

biome.getForestDescription = getForestDescription

return biome