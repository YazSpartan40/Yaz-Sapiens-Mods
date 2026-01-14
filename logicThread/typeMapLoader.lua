local typeMaps = mjrequire "common/typeMaps"
local mjs = mjrequire "common/mjs"

local typeMapLoader = {}

local loadedTypes = {}

function typeMapLoader:init(typesFilePath)
	local fileContents = fileUtils.getFileContents(typesFilePath)
	if fileContents and fileContents ~= "" then
		local unserialized = mjs.getUnserialized(fileContents)
		if unserialized and type(unserialized) == "table" then
            loadedTypes = unserialized.types
		end
    end

    --mj:log("loaded types:", loadedTypes)
    
    typeMaps:setAddTypeFunction(function(mapKey, typeTable, typeKey)
        local existingMap = loadedTypes[mapKey]
        if not existingMap then
            mj:error("Attempt to access unknown type map:", mapKey, "  with type:", typeKey)
            return nil
        end

        
        local existingType = existingMap[typeKey]
        if existingType then
            return existingType
        end

        mj:error("Attempt to access unknown type key:", typeKey, "  from map:", mapKey)
        return nil
    end)

end

return typeMapLoader