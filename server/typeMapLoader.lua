local typeMaps = mjrequire "common/typeMaps"
local mjs = mjrequire "common/mjs"

local typeMapLoader = {}
local typesFilePath = nil

local existingTypes = {}
local idCounter = typeMaps.startIndex --start at typeMaps.startIndex just to make logging of indexes a little less noisy

function typeMapLoader:init(typesFilePath_)
    typesFilePath = typesFilePath_
	local fileContents = fileUtils.getFileContents(typesFilePath)
	if fileContents and fileContents ~= "" then
		local unserialized = mjs.getUnserialized(fileContents)
		if unserialized and type(unserialized) == "table" then
            existingTypes = unserialized.types
            idCounter = unserialized.idCounter
		end
    end

    --mj:log("loaded types:", existingTypes)
    
    typeMaps:setAddTypeFunction(function(mapKey, typeTable, typeKey)
        local existingMap = existingTypes[mapKey]
        if not existingMap then
            existingTypes[mapKey] = {}
            existingMap = existingTypes[mapKey]
        end

        
        local existingType = existingMap[typeKey]
        if existingType then
            return existingType
        end

        local index = idCounter
        idCounter = idCounter + 1

        existingMap[typeKey] = index
        typeTable[typeKey] = index

        --mj:log("add type:", typeKey)

        return index
    end)

end

function typeMapLoader:saveForLoadComplete()
    typeMaps:setAddTypeFunction(nil)
    
	local serialized = mjs.getSerialized({
        types = existingTypes,
        idCounter = idCounter,
    })
    --mj:log("saving types:", existingTypes)

    fileUtils.writeToFile(typesFilePath, serialized)

    existingTypes = nil
    return idCounter
end

return typeMapLoader