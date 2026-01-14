local ffi = mjrequire("ffi")

local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4
local mat3 = mjm.mat3


local mjsTokens = mjrequire "common/mjsTokens"
local tokens = mjsTokens.tokens

local mjs = {}

local ffiToString = ffi.string
local ffiCopy = ffi.copy

local function getNumber(numType, buf)
   return ffi.cast(numType, buf)[0]
end

local outputBuffer = nil
local currentOffset = 0

local mjTypeIndexNil = 1
local mjTypeIndexNumber = 2
local mjTypeIndexBool = 3
local mjTypeIndexString = 4
local mjTypeIndexTable = 5
local mjTypeIndexSPVec2 = 6
local mjTypeIndexSPVec3 = 7
local mjTypeIndexSPVec4 = 8
local mjTypeIndexSPMat3 = 9
local mjTypeIndexToken = 10

local headerType = ffi.typeof("uint8_t[1]")
local headerTypePtr = ffi.typeof("const uint8_t*")
local headerSize = ffi.sizeof("uint8_t")

local numberType = ffi.typeof("double[1]")
local numberTypePtr = ffi.typeof("const double*")
local numberSize = ffi.sizeof("double")

local boolType = ffi.typeof("uint8_t[1]")
local boolTypePtr = ffi.typeof("const uint8_t*")
local boolSize = ffi.sizeof("uint8_t")

local tokenType = ffi.typeof("uint8_t[1]")
local tokenTypePtr = ffi.typeof("const uint8_t*")
local tokenSize = ffi.sizeof("uint8_t")

local mjHeaderTypeNil = headerType(mjTypeIndexNil)
local mjHeaderTypeNumber = headerType(mjTypeIndexNumber)
local mjHeaderTypeBool = headerType(mjTypeIndexBool)
local mjHeaderTypeString = headerType(mjTypeIndexString)
local mjHeaderTypeTable = headerType(mjTypeIndexTable)
local mjHeaderTypeSPVec2 = headerType(mjTypeIndexSPVec2)
local mjHeaderTypeSPVec3 = headerType(mjTypeIndexSPVec3)
local mjHeaderTypeSPVec4 = headerType(mjTypeIndexSPVec4)
local mjHeaderTypeSPMat3 = headerType(mjTypeIndexSPMat3)
local mjHeaderTypeToken = headerType(mjTypeIndexToken)

local maxOutputSize = 0
function mjs:setOutputBuffer(outputBuffer_, maxOutputSize_)
    local conversion = ffi.typeof("uint8_t*")
    outputBuffer = conversion(outputBuffer_)
    maxOutputSize = maxOutputSize_
end

--local debugTokens = {}

local serializeFunctions = nil

--local debugObj = nil
local function debugObjectSize(size)
    if currentOffset + size >= maxOutputSize then
        mj:error("trying to serialize an object larger than the max")
        --mj:log("object:", debugObj)
        error()
    end
end

local function addValue(value, size)
    debugObjectSize(size)
    ffiCopy(outputBuffer + currentOffset, value, size)
    currentOffset = currentOffset + size
end


local cdataSerializeFunctions = {
    [tostring(vec2)] = function(obj)
        addValue(mjHeaderTypeSPVec2, headerSize)
        addValue(numberType(obj.x), numberSize)
        addValue(numberType(obj.y), numberSize)
    end,
    [tostring(vec3)] = function(obj)
        addValue(mjHeaderTypeSPVec3, headerSize)
        addValue(numberType(obj.x), numberSize)
        addValue(numberType(obj.y), numberSize)
        addValue(numberType(obj.z), numberSize)
    end,
    [tostring(vec4)] = function(obj)
        addValue(mjHeaderTypeSPVec4, headerSize)
        addValue(numberType(obj.x), numberSize)
        addValue(numberType(obj.y), numberSize)
        addValue(numberType(obj.z), numberSize)
        addValue(numberType(obj.w), numberSize)
    end,
    [tostring(mjm.mat3)] = function(obj)
        addValue(mjHeaderTypeSPMat3, headerSize)
        addValue(numberType(obj.m0), numberSize)
        addValue(numberType(obj.m1), numberSize)
        addValue(numberType(obj.m2), numberSize)
        addValue(numberType(obj.m3), numberSize)
        addValue(numberType(obj.m4), numberSize)
        addValue(numberType(obj.m5), numberSize)
        addValue(numberType(obj.m6), numberSize)
        addValue(numberType(obj.m7), numberSize)
        addValue(numberType(obj.m8), numberSize)
    end,
}

--todo comment out the warnings for lack of serializeFunctions for release

serializeFunctions = {
    ['nil'] = function(obj)
        addValue(mjHeaderTypeNil, headerSize)
    end,
    ['number'] = function(obj)
        addValue(mjHeaderTypeNumber, headerSize)
        addValue(numberType(obj), numberSize)
    end,
    ['boolean'] = function(obj)
        addValue(mjHeaderTypeBool, headerSize)
        addValue(boolType(obj), boolSize)
    end,
    ['string'] = function(obj)
        local token = tokens[obj]
        if token then
            addValue(mjHeaderTypeToken, headerSize)
            addValue(tokenType(token), tokenSize)
        else
            --[[if debugTokens[obj] then
                debugTokens[obj] = debugTokens[obj] + 1
            else
                debugTokens[obj] = 1
            end]]

            local stringLength = #obj
            addValue(mjHeaderTypeString, headerSize)
            
            debugObjectSize(stringLength + 1)
            ffiCopy(outputBuffer + currentOffset, obj)
            currentOffset = currentOffset + stringLength + 1
        end
    end,
    ['table'] = function(obj)
        addValue(mjHeaderTypeTable, headerSize)

        for k,v in pairs(obj) do
            local keyFunc = serializeFunctions[type(k)]
            local valueFunc = serializeFunctions[type(v)]
            if keyFunc and valueFunc then
                keyFunc(k)
                valueFunc(v)
            else
                if not keyFunc then
                    mj:warn("No serializeFunctions for table key object of type:", type(k), " key:", k, " table:", obj)
                end
                if not valueFunc then
                   -- if k ~= "set" and k ~= "remove" then --this is a horrible hack, but given this is a debug message, Ima go ahead and do it. sharedState has these methods, and that's OK, just ignore em.
                        mj:warn("No serializeFunctions for table value object of type:", type(v), " key:", k, " table:", obj)
                   -- end
                end
            end
        end

        addValue(mjHeaderTypeNil, headerSize)
    end,
    ['cdata'] = function (obj)
        local ctypeKey = tostring(ffi.typeof(obj))
        if cdataSerializeFunctions[ctypeKey] then
            cdataSerializeFunctions[ctypeKey](obj)
        else
            mj:warn("no serialization function found for cdata:", ctypeKey)
            mj:log("available cdataSerializeFunctions:", cdataSerializeFunctions)
            mj:log(debug.traceback())
        end
    end,
}


local unserializeFunctions = nil
unserializeFunctions = {
    [mjTypeIndexNil] = function(ptrData)
        return nil
    end,
    [mjTypeIndexNumber] = function(ptrData)
        local offset = currentOffset
        currentOffset = offset + numberSize
        return getNumber(numberTypePtr, ptrData + offset)
    end,
    [mjTypeIndexBool] = function(ptrData)
        local offset = currentOffset
        currentOffset = offset + boolSize
        return getNumber(boolTypePtr, ptrData + offset) == 1
    end,
    [mjTypeIndexString] = function(ptrData)
        local offset = currentOffset
        local string = ffiToString(ptrData + offset)
        currentOffset = offset + #string + 1
        return string
    end,
    [mjTypeIndexToken] = function(ptrData)
        local offset = currentOffset
        currentOffset = offset + tokenSize
        local token = getNumber(tokenTypePtr, ptrData + offset)
        return tokens[token]
    end,
    [mjTypeIndexTable] = function(ptrData)
        local table = {}

        while 1 do
            local keyMJType = getNumber(headerTypePtr, ptrData + currentOffset)
            if not unserializeFunctions[keyMJType] then
                mj:error("no serialization function for type:", keyMJType, " table so far:", table, " currentOffset:", currentOffset, " ptrData:", ptrData)
                    local debugPrint = ""
                    for i=0,currentOffset + 16 do
                        debugPrint = debugPrint .. string.format("%02x", ptrData[i])
                    end
                    mj:log("error outputBuffer:", debugPrint)
                return nil
            end
            currentOffset = currentOffset + headerSize
            local key = unserializeFunctions[keyMJType](ptrData)

            if key == nil then
                break
            end

            local valueMJType = getNumber(headerTypePtr, ptrData + currentOffset)
            currentOffset = currentOffset + headerSize
            local value = unserializeFunctions[valueMJType](ptrData)

            if value == nil then
                mj:error("nil value found for key:", key, " table so far:", table, " valueMJType:", valueMJType, " mjTypeIndexNil:", mjTypeIndexNil)
                return nil
            end

            table[key] = value
        end
        
        return table
    end,
    [mjTypeIndexSPVec2] = function(ptrData)
        local x = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        local y = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        return vec2(x,y)
    end,
    [mjTypeIndexSPVec3] = function(ptrData)
        local x = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        local y = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        local z = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        return vec3(x,y,z)
    end,
    [mjTypeIndexSPVec4] = function(ptrData)
        local x = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        local y = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        local z = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        local w = getNumber(numberTypePtr, ptrData + currentOffset)
        currentOffset = currentOffset + numberSize
        return vec4(x,y,z,w)
    end,
    [mjTypeIndexSPMat3] = function(ptrData)
        local function getNumberValue()
            local offset = currentOffset
            local v = getNumber(numberTypePtr, ptrData + offset)
            currentOffset = currentOffset + numberSize
            return v
        end
        return mat3(
            getNumberValue(),
            getNumberValue(),
            getNumberValue(),
            getNumberValue(),
            getNumberValue(),
            getNumberValue(),
            getNumberValue(),
            getNumberValue(),
            getNumberValue()
        )
    end,
}

function mjs.serialize(obj)
    --mj:log("serialize:", obj)
    currentOffset = 0
    --debugObj = obj
    local func = serializeFunctions[type(obj)]
    if func then
        func(obj)
    else
        mj:warn("No serializeFunctions for object of type:", type(obj))
        mj:log(debug.traceback())
    end
    --[[if hitLargeObject then
        mj:error(obj)
        error()
    end]]
    --mj:log("length:", currentOffset)
    return currentOffset
end

function mjs.unserialize(arc)
    currentOffset = 0
    local ptrData = headerTypePtr(arc)
    local mjType = getNumber(headerTypePtr, ptrData)
    currentOffset = currentOffset + headerSize
    local func = unserializeFunctions[mjType]
    if func then
        --return func(ptrData)
        local result = func(ptrData)
        --mj:log("unserialize:", result)
        return result
    end
    return nil
end

function mjs.getSerialized(obj)
    local len = mjs.serialize(obj)
    --debugObjectSize(len)
    --[[if hitLargeObject then
        mj:error(obj)
        error()
    end]]
    return ffiToString(outputBuffer, len)
end

function mjs.getUnserialized(arc)
    return mjs.unserialize(arc)
end

--[[ human readable ]]--

local serializeObjectReadable = nil

local function escape(str)
    return str:gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function serializeTableReadable(tbl, indent, maintainOrder, comments, commentOutKeys, isCommentedOut)
	if not tbl then
		return "nil"
	end
	if not indent then 
		indent = 0 
	end

    local toprint = ""
   --[[if isCommentedOut then
        toprint = "--"
    end]]

	toprint = toprint .. "{\n"
    indent = indent + 2 
    local keyIndex = 1

    local function addKeyValue(k, v)
        local thisCommentedOut = isCommentedOut
        if thisCommentedOut or (commentOutKeys and commentOutKeys[k]) then
            toprint = toprint .. "--"
            thisCommentedOut = true
        end

		toprint = toprint .. string.rep(" ", indent)
        if (type(k) == "number") then
            if k ~= keyIndex then
                toprint = toprint .. "[" .. k .. "] = "
            end
            keyIndex = keyIndex + 1
		elseif (type(k) == "string") then
			toprint = toprint  .. escape(k) ..  " = "   
		end

        if comments and comments[k] and comments[k] ~= "" then
            toprint = toprint .. serializeObjectReadable(v, indent, maintainOrder, comments, commentOutKeys, thisCommentedOut) .. ", --" .. comments[k] .. "\n"
        else
            toprint = toprint .. serializeObjectReadable(v, indent, maintainOrder, comments, commentOutKeys, thisCommentedOut) .. ",\n"
        end

    end

    if maintainOrder then
        local orderedKeys = {}
        for k,v in pairs(tbl) do
            table.insert(orderedKeys, k)
        end
        table.sort(orderedKeys)
        for i,k in ipairs(orderedKeys) do
            addKeyValue(k, tbl[k])
        end
    else
        for k, v in pairs(tbl) do
            addKeyValue(k, v)
        end
    end

    if isCommentedOut then
        toprint = toprint .. "--"
    end
	toprint = toprint .. string.rep(" ", indent-4) .. "}"
	return toprint
end

serializeObjectReadable = function(v, indent, maintainOrder, comments, commentOutKeys, isCommentedOut)
    if v == nil then
		return "nil"
	end
	if not indent then 
		indent = 0 
	end

	if (type(v) == "number") then
		return v
	elseif (type(v) == "string") then
		return "\"" .. escape(v) .. "\""
	elseif (type(v) == "table") then
		return serializeTableReadable(v, indent + 2, maintainOrder, comments, commentOutKeys, isCommentedOut)
	else
		return tostring(v)
	end
end

function mjs.serializeReadable(obj, maintainOrder, comments, commentOutKeys)
    return "return " .. serializeObjectReadable(obj, 0, maintainOrder, comments, commentOutKeys, false)
end

function mjs:printDebug()
   --[[ local ordered = {}
    for k,v in pairs(debugTokens) do
        if v > 2 then
            table.insert(ordered, {
                token = k,
                count = v,
            })
        end
    end

    local function sortCount(a,b)
        return a.count > b.count
    end
    
    table.sort(ordered, sortCount)

    mj:log(ordered)]]
end

function mjs.unserializeReadable(arc)
    local types = [[
local mjm = require "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4
local mat3 = mjm.mat3
    ]]

    local arcWithTypes = types .. arc

    local loaded,loadErr = loadstring(arcWithTypes)
    if not loaded then
        mj:log("a:", arcWithTypes)
        mj:error("problem unserializing readable lua data:", arc, "\nerror:", loadErr)
    end

    local function errorhandler(err)
        mj:log("b:", arcWithTypes)
        mj:error("problem unserializing readable lua data:", arc, "\nerror:", err)
        mj:log(debug.traceback())
    end
    local ok, resultTable = xpcall(loaded, errorhandler)
    if ok then
        return resultTable
    end
    return nil

    --return "return " .. serializeObjectReadable(obj, 0)
end

return mjs