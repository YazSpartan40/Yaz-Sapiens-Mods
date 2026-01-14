local typeMaps = mjrequire "common/typeMaps"

local globeThread = {}

--local bridge = nil
local idCounter = typeMaps.startIndex --start at typeMaps.startIndex just to make logging of indexes a little less noisy

function globeThread:setBridge(bridge_)
    --bridge = bridge_

    mj:log("typeMapLoader:init()")
    typeMaps:setAddTypeFunction(function(mapKey, typeTable, typeKey)
        local index = idCounter
        idCounter = idCounter + 1

        typeTable[typeKey] = index
        return index
    end)
end

return globeThread