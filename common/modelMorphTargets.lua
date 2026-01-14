

local rng = mjrequire "common/randomNumberGenerator"

local modelMorphTargets = {}

function modelMorphTargets:randomizedWeights(uniqueID, modelIndex, count)
    local result = {}
    for i=1,count do
        result[i] = rng:valueForUniqueID(uniqueID, 83410 + i + modelIndex * 100)
    end
    return result
end

return modelMorphTargets