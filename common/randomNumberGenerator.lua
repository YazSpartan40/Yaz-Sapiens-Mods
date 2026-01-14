local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

local randomNumberGenerator = {}

local bridge = nil

local randomSeed = 1

function randomNumberGenerator:valueForPosition(pos, seed)
    return bridge:valueForPosition(pos, seed)
end

function randomNumberGenerator:valueForUniqueID(uniqueID, seed)
    return bridge:valueForUniqueID(uniqueID, seed)
end

function randomNumberGenerator:valueForSeed(seed)
    return bridge:valueForSeed(seed)
end

function randomNumberGenerator:randomValue()
    randomSeed = randomSeed + 1
    return bridge:valueForSeed(randomSeed)
end

function randomNumberGenerator:integerForSeed(seed, max) -- min of 0, max of max - 1
    return bridge:integerForSeed(seed, max)
end

function randomNumberGenerator:integerForUniqueID(uniqueID, seed, max) -- min of 0, max of max - 1
    return bridge:integerForUniqueID(uniqueID, seed, max)
end

function randomNumberGenerator:randomInteger(max) -- min of 0, max of max - 1
    randomSeed = randomSeed + 1
    return bridge:integerForSeed(randomSeed, max)
end

function randomNumberGenerator:randomBool()
    randomSeed = randomSeed + 1
    return bridge:integerForSeed(randomSeed, 2) == 1
end

function randomNumberGenerator:randomChance(fractionChance) -- 1.0 returns true 100% of the time, 0.5 50% of the time, 0.1 10%
    if fractionChance <= 0 then
        return false
    end
    if fractionChance >= 1 then
        return true
    end
    randomSeed = randomSeed + 1
    return bridge:valueForSeed(randomSeed) <= fractionChance
end

function randomNumberGenerator:boolForSeed(seed)
    return bridge:integerForSeed(seed, 2) == 1
end

function randomNumberGenerator:boolForUniqueID(uniqueID, seed)
    return bridge:integerForUniqueID(uniqueID, seed, 2) == 1
end


function randomNumberGenerator:randomHashString()
    return bridge:randomHashString()
end

function randomNumberGenerator:vecForUniqueID(uniqueID, seed)
    return vec3((randomNumberGenerator:valueForUniqueID(uniqueID, 6 + seed) - 0.5), 
        (randomNumberGenerator:valueForUniqueID(uniqueID, 15 + seed) - 0.5),
        (randomNumberGenerator:valueForUniqueID(uniqueID, 34 + seed) - 0.5))
end

function randomNumberGenerator:vec()
    randomSeed = randomSeed + 3
    return vec3((randomNumberGenerator:valueForSeed(6 + randomSeed) - 0.5), 
        (randomNumberGenerator:valueForSeed(15 + randomSeed) - 0.5),
        (randomNumberGenerator:valueForSeed(34 + randomSeed) - 0.5))
end

function randomNumberGenerator:randomVec()
    return randomNumberGenerator:vec()
end

function randomNumberGenerator:randomRotation()
    return mjm.mat3Rotate(mjm.mat3Identity, randomNumberGenerator:randomValue() * math.pi * 2.0, mjm.normalize(randomNumberGenerator:vec()))
end


function randomNumberGenerator:getRandomPerpVecNormal(pointNormal)
    local randomVecNormalized = mjm.normalize(randomNumberGenerator:vec())
    return mjm.normalize(mjm.cross(randomVecNormalized, pointNormal))
end

function randomNumberGenerator:setBridge(bridge_)
    bridge = bridge_
end

function randomNumberGenerator:initRandomSeed(newRandomSeed)
    randomSeed = newRandomSeed
end

function randomNumberGenerator:getRandomSeed()
    randomSeed = randomSeed + 1
    return randomSeed
end

return randomNumberGenerator