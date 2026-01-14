local typeMaps = {
    startIndex = 10000,
    types = {}
}

local addTypeFunction = nil

setmetatable(typeMaps.types, {
    __index = function(mapTable, mapKey)
        local currentMapValue = rawget(mapTable, mapKey)
        if currentMapValue then
            return currentMapValue
        end
        if addTypeFunction then
            local newMap = {}
            setmetatable(newMap, {
                __index = function(typeTable, typeKey)
                    local currentTypeValue = rawget(typeTable, typeKey)
                    if currentTypeValue then
                        return currentTypeValue
                    end
                    if addTypeFunction then
                        if type(typeKey) == "string" then
                            local result = addTypeFunction(mapKey, typeTable, typeKey)
                            rawset(typeTable, typeKey, result)
                            return result
                        else
                            mj:error("In typeMaps.lua: Attempting to access type index beyond range or with non string type key:", typeKey, " from map:", mapKey)
                            mj:log(debug.traceback())
                            return nil
                        end
                    else
                        mj:error("In typeMaps.lua: Attempting to access undefined type:", typeKey, " in map:", mapKey)
                        mj:log(debug.traceback())
                        return nil
                    end
                end
            })
            rawset(mapTable, mapKey, newMap)
            return newMap
        else
            mj:error("In typeMaps.lua: Trying to access undefined map:", mapKey)
            mj:log(debug.traceback())
            return nil
        end
    end
})

--mj:log("typeMaps.types:", typeMaps.types)

local function getTypeStringForValue(inValue)
    if type(inValue) == "number" and inValue == math.floor(inValue) and inValue >= typeMaps.startIndex then
        for mapKey,indexMap in pairs(typeMaps.types) do
            for k,index in pairs(indexMap) do
                if index == inValue then
                    return mapKey .. "." .. k
                end
            end
        end
    end
    return nil
end

mj.getTypeStringForValueFunc = getTypeStringForValue

function typeMaps:printType(typeIndexOrKey)

    local function split(inputstr, sep)
        local result = {}
        for subString in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(result, subString)
        end
        return result
    end

    if type(typeIndexOrKey) == "string" then
        local splitString = split(typeIndexOrKey, ".")
        if splitString[2] then
            local indexMap = typeMaps.types[splitString[1]]
            if indexMap then
                local index = indexMap[splitString[2]]
                if index then
                    mj:log("typeKey:", splitString[1], ".", splitString[2], " = ", index)
                    return
                end
            end
        end
    else
        local typeString = getTypeStringForValue(typeIndexOrKey)
        if typeString then
            mj:log("typeIndex:", typeIndexOrKey, " = ", typeString)
            return 
        end
    end
    mj:log("type:", typeIndexOrKey, " not found")
end


function typeMaps:setAddTypeFunction(addTypeFunction_)
    addTypeFunction = addTypeFunction_
    --mj:log("typeMaps:setAddTypeFunction:", addTypeFunction_)
end


function typeMaps:createMap(mapName, mapTable)
    local indexMap = typeMaps.types[mapName]
    local resultTable = {}
    for i,entry in ipairs(mapTable) do
        entry.index = indexMap[entry.key]
        resultTable[entry.index] = entry
        resultTable[entry.key] = entry
    end
    return resultTable
end

function typeMaps:insert(mapName, mapTable, entry)
    local indexMap = typeMaps.types[mapName]
    entry.index = indexMap[entry.key]
    mapTable[entry.index] = entry
    mapTable[entry.key] = entry
end


function typeMaps:createValidTypesArray(mapName, mapTable)
    local validTypes = {}
    for k,v in pairs(typeMaps.types[mapName]) do
        local type = mapTable[v]
        if type then
            table.insert(validTypes, type)
        end
    end
    return validTypes
end

return typeMaps