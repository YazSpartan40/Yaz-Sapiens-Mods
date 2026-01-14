local typeMaps = mjrequire "common/typeMaps"
local mjs = mjrequire "common/mjs"

local typeMapLoader = {}

local loadedTypes = nil
local idCounter = typeMaps.startIndex --start at typeMaps.startIndex just to make logging of indexes a little less noisy

function typeMapLoader:init(typesFilePathOrNil)
    if typesFilePathOrNil then
        local fileContents = fileUtils.getFileContents(typesFilePathOrNil)
        if fileContents and fileContents ~= "" then
            local unserialized = mjs.getUnserialized(fileContents)
            if unserialized and type(unserialized) == "table" then
                loadedTypes = unserialized.types
            end
        end

       -- mj:log("loaded types:", loadedTypes)
        
        typeMaps:setAddTypeFunction(function(mapKey, typeTable, typeKey)
            local existingMap = loadedTypes[mapKey]
            if not existingMap then
                local index = idCounter
                idCounter = idCounter + 1
        
                typeTable[typeKey] = index
                return index
            end

            
            local existingType = existingMap[typeKey]
            if existingType then
                return existingType
            end

            mj:error("Attempt to access unknown type key:", typeKey, "  from map:", mapKey)
            mj:log(debug.traceback())
            return nil
        end)
    else
        typeMaps:setAddTypeFunction(function(mapKey, typeTable, typeKey)
            local index = idCounter
            idCounter = idCounter + 1
    
            typeTable[typeKey] = index
            return index
        end)
    end

end

return typeMapLoader