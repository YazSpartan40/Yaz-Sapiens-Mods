local gameObjectSharedState = {
    enableDebugDeltaCompression = false --also uncomment enableDebugDeltaCompression section in clientGOM.lua
}

local serverDiffMetaTable = nil
local gom = nil

function gameObjectSharedState:setupState(object, sharedStateTable)

    if serverDiffMetaTable then
        local cloned = mj:cloneTable(serverDiffMetaTable)
        cloned.__index.uniqueID = object.uniqueID
        setmetatable(sharedStateTable, cloned)
    end

    --[[sharedStateTable.set = function(t, ...)
        serverDiffSetFunction(object, ...)
    end

    sharedStateTable.remove = function(t, ...)
        serverDiffRemoveFunction(object, ...)
    end]]
end

function gameObjectSharedState:setServerDiffMetaTable(serverDiffMetaTable_)
    serverDiffMetaTable = serverDiffMetaTable_
end



local function recursivelyMergeDeltaForTable(stateTable, diffStateTable)

    local removeKeysSet = diffStateTable["__0"]
    if removeKeysSet then
        for k,v in pairs(removeKeysSet) do
            stateTable[k] = nil
        end
    end
    
    for k,v in pairs(diffStateTable) do
        if (type(k) ~= "string" or k ~= "__0") then
            local vType = type(v)
            if vType == "table" then
                if not stateTable[k] then
                    stateTable[k] = {}
                end
                recursivelyMergeDeltaForTable(stateTable[k], v)
            else
                stateTable[k] = v
            end
        end
    end
end

function gameObjectSharedState:mergeDelta(object, diffState)

    if type(diffState) == "string" and  diffState == "__0" then
        gom:createSharedState(object)
        gameObjectSharedState:setupState(object, object.sharedState)
        return
    end

    --mj:log(object.uniqueID, ":merge state:", diffState)--, " current:", object.sharedState )
    if not diffState or not next(diffState) then
        return
    end

    if not object.sharedState then
        gom:createSharedState(object)
        gameObjectSharedState:setupState(object, object.sharedState)
    end
    
    recursivelyMergeDeltaForTable(object.sharedState, diffState)
   -- mj:log("merge state after:", object.sharedState )
end

local mjm = mjrequire "common/mjm"
local ffi = mjrequire("ffi")
local approxEqual = mjm.approxEqual

local function recursivelyDebugVerifyDeltaUpdate(objectID, objectStateTable, completeStateTable, keyChain)
    for k,v in pairs(completeStateTable) do
        
        if objectStateTable[k] == nil then
            mj:warn(objectID, ":State verify error: objectStateTable is missing value:", v, " for key:", keyChain .. mj:tostring(k))
        else
            local vType = type(v)
            if vType == "table" then
                recursivelyDebugVerifyDeltaUpdate(objectID, objectStateTable[k], v, keyChain .. mj:tostring(k) .. ".")
            elseif vType == "string" or vType == "number" or vType == "boolean" then
                if v ~= objectStateTable[k] then
                    mj:warn(objectID, ":State verify error: objectStateTable value doesn't equal complete state value for key:", keyChain .. mj:tostring(k), ". objectStateTable:", objectStateTable[k], ", complete value:", v)
                end
            elseif vType == 'cdata' then --only verifies vec3s currently
                local ctypeKey = tostring(ffi.typeof(v))
                if tostring(mjm.vec3) == ctypeKey then
                    local ov = objectStateTable[k]
                    if v.x and ((not ov.x) or not approxEqual(v.x, ov.x)) then
                        mj:warn(objectID, ":State verify error: objectStateTable value.x doesn't equal complete state value for key:", keyChain .. mj:tostring(k), ". objectStateTable:", objectStateTable[k], ", complete value:", v)
                    elseif v.y and ((not ov.y) or not approxEqual(v.y, ov.y)) then
                        mj:warn(objectID, ":State verify error: objectStateTable value.y doesn't equal complete state value for key:", keyChain .. mj:tostring(k), ". objectStateTable:", objectStateTable[k], ", complete value:", v)
                    elseif v.z and ((not ov.z) or not approxEqual(v.z, ov.z)) then
                        mj:warn(objectID, ":State verify error: objectStateTable value.z doesn't equal complete state value for key:", keyChain .. mj:tostring(k), ". objectStateTable:", objectStateTable[k], ", complete value:", v)
                    end
                end
            end
        end
    end
end

local function recursivelyDebugVerifyDeltaUpdateNonRemoved(objectID, objectStateTable, completeStateTable, keyChain)
    for k,v in pairs(objectStateTable) do
        if completeStateTable[k] == nil then
            mj:warn(objectID, ":State verify error: objectStateTable has extra value:", v, " for key:", keyChain .. mj:tostring(k))
        else
            local vType = type(v)
            if vType == "table" then
                recursivelyDebugVerifyDeltaUpdateNonRemoved(objectID, v, completeStateTable[k], keyChain .. mj:tostring(k) .. ".")
            end
        end
    end
end

function gameObjectSharedState:debugVerifyDeltaUpdate(object, completeState)
    if not completeState then
        if object.sharedState then
            mj:warn(object.uniqueID, ":State verify error: not completeState but has object.sharedState")
        end
        return
    end
    if not object.sharedState then
        if next(completeState) then
            mj:warn(object.uniqueID, ":State verify error: not object.sharedState but has completeState values")
        end
        return
    end

    recursivelyDebugVerifyDeltaUpdate(object.uniqueID, object.sharedState, completeState, ".")
    recursivelyDebugVerifyDeltaUpdateNonRemoved(object.uniqueID, object.sharedState, completeState, ".")
end

function gameObjectSharedState:init(gom_)
    gom = gom_
end

return gameObjectSharedState