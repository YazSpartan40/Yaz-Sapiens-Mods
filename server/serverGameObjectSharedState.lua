local mjm = mjrequire "common/mjm"
local gameObjectSharedState = mjrequire "common/gameObjectSharedState"
local serverGameObjectSharedState = {}

local stateDiffsByObjectID = {}
local serverGOM = nil

local approxEqual = mjm.approxEqual


local function set(sharedState, ...)
    local uniqueID = sharedState.uniqueID

    local count = select("#",...)

    --mj:log("set:", uniqueID, ...)

    local table = sharedState
    for i = 1,count - 2 do
        local subTableKey = select(i,...)
        local subTable = table[subTableKey]
        if not subTable then
            subTable = {}
            table[subTableKey] = subTable
        end
        table = subTable
    end
    
    local valueKey = select(count - 1,...)
    local value = select(count,...)
    local modifiedValue = value

    --[[if valueKey == "progressIndex" then
        mj:error("progressIndex")
    end]]

    local valueIsTable = false
    if type(value) == "table" then
        valueIsTable = true
        modifiedValue = mj:cloneTable(value)
    end
    

    local needsUpdate = true
    if table[valueKey] ~= nil then
        --mj:log("not nil")
        needsUpdate = false
        local function recursivelyCheckNeedsUpdateAndAddFlagsForRemovedTableItems(thisValueCurrent, thisValueIncoming)
            --mj:log("checking:", thisValueCurrent, " against:", thisValueIncoming)
            if thisValueCurrent == nil and thisValueIncoming ~= nil then
                needsUpdate = true
                return
            end

            local valueType = type(thisValueCurrent)
            
            if valueType ~= type(thisValueIncoming) then
                needsUpdate = true
                return
            end

            if valueType == "table" then
                
                for k,v in pairs(thisValueIncoming) do
                    recursivelyCheckNeedsUpdateAndAddFlagsForRemovedTableItems(thisValueCurrent[k], thisValueIncoming[k])
                end

                for k,v in pairs(thisValueCurrent) do
                    if thisValueIncoming[k] == nil then
                       -- mj:log("set to __0")
                        
                        if not thisValueIncoming["__0"] then
                            thisValueIncoming["__0"] = {}
                        end
                        thisValueIncoming["__0"][k] = true
                        needsUpdate = true
                    end
                end

                return
            end

            if not needsUpdate then
                --mj:log("valueType:", valueType)
                if valueType == "string" or valueType == "boolean" then
                    needsUpdate = (thisValueCurrent ~= thisValueIncoming)
                elseif valueType == "number" then
                    needsUpdate = not approxEqual(thisValueCurrent, thisValueIncoming)
                elseif valueType == 'cdata' then
                    local v = thisValueIncoming
                    local ov = thisValueCurrent
                    if v.x and ((not ov.x) or not approxEqual(v.x, ov.x)) then
                        needsUpdate = true
                    elseif v.y and ((not ov.y) or not approxEqual(v.y, ov.y)) then
                        needsUpdate = true
                    elseif v.z and ((not ov.z) or not approxEqual(v.z, ov.z)) then
                        needsUpdate = true
                    end
                end
            end
        end

        recursivelyCheckNeedsUpdateAndAddFlagsForRemovedTableItems(table[valueKey], modifiedValue)
    end

    if needsUpdate then
        table[valueKey] = value

        local objectStateDiff = stateDiffsByObjectID[uniqueID]
        if not objectStateDiff then
            objectStateDiff = {}
            stateDiffsByObjectID[uniqueID] = objectStateDiff
        end
        
        local clientTable = objectStateDiff
        for i = 1,count - 2 do
            local subTableKey = select(i,...)
            local subTable = clientTable[subTableKey]
            if not subTable then
                subTable = {}
                clientTable[subTableKey] = subTable
                --[[
                if not clientTable["__0"] then 
                    clientTable["__0"] = {}
                end
                clientTable["__0"][subTableKey] = true --not sure if this is needed]]
            end
            clientTable = subTable
        end

        if modifiedValue ~= nil then
            clientTable[valueKey] = modifiedValue
        else
            clientTable[valueKey] = nil
        end

        if valueIsTable or modifiedValue == nil then
            if not clientTable["__0"] then
                clientTable["__0"] = {}
            end
            clientTable["__0"][valueKey] = true
        end
        -- mj:log("sending table to client:", clientTable[valueKey])
        
        serverGOM:saveObject(uniqueID)
    --else
        --mj:log("skipping state save")
    end
end


local function removeFromArray(sharedState, ...)
    
    local uniqueID = sharedState.uniqueID
    --mj:log("remove:", uniqueID, ...)
    local count = select("#",...)

    local tableToUse = sharedState
    for i = 1,count - 1 do
        local subTableKey = select(i,...)
        local subTable = tableToUse[subTableKey]
        if not subTable then
            subTable = {}
            tableToUse[subTableKey] = subTable
        end
        tableToUse = subTable
    end
    
    local valueKey = select(count,...)

    if tableToUse[valueKey] ~= nil then

        local tableArrayCount = #tableToUse
        --mj:log("setting remove for array item")

        
        if tableArrayCount == nil or type(valueKey) ~= "number" or math.floor(valueKey) ~= valueKey or valueKey > tableArrayCount then
            mj:error("using sharedState:removeFromArray on what doesn't look like an array")
        end

        local objectStateDiff = stateDiffsByObjectID[uniqueID]
        if not objectStateDiff then
            objectStateDiff = {}
            stateDiffsByObjectID[uniqueID] = objectStateDiff
        end
        
        local clientTable = objectStateDiff
        for i = 1,count - 1 do
            local subTableKey = select(i,...)
            local subTable = clientTable[subTableKey]
            if not subTable then
                subTable = {}
                clientTable[subTableKey] = subTable
            end
            clientTable = subTable
        end

        if not clientTable["__0"] then
            clientTable["__0"] = {}
        end

        for i=valueKey,tableArrayCount-1 do
            local movedValue = tableToUse[i + 1]
            if type(movedValue) == "table" then
                movedValue = mj:cloneTable(movedValue)
            end
            clientTable[i] = movedValue
            clientTable["__0"][i] = true
        end
        
        clientTable["__0"][tableArrayCount] = true
        clientTable[tableArrayCount] = nil
        
        table.remove(tableToUse, valueKey)

        -- Below is an alternative to just send through a reset and the whole table if the above ends up not working out.

        --[[table.remove(tableToUse, valueKey)


        local objectStateDiff = stateDiffsByObjectID[uniqueID]
        if not objectStateDiff then
            objectStateDiff = {}
            stateDiffsByObjectID[uniqueID] = objectStateDiff
        end
        
        local clientTableParent = objectStateDiff
        for i = 1,count - 2 do
            local subTableKey = select(i,...)
            local subTable = clientTableParent[subTableKey]
            if not subTable then
                subTable = {}
                clientTableParent[subTableKey] = subTable
            end
            clientTableParent = subTable
        end

        local parentKey= select(count - 1,...)
        
        if not clientTableParent["__0"] then
            clientTableParent["__0"] = {}
        end
        clientTableParent["__0"][parentKey] = true

        clientTableParent[parentKey] = tableToUse]]
        
        serverGOM:saveObject(uniqueID)
    --else
        
        --mj:log("item to remove was already nil")
    end
end


local function remove(sharedState, ...)
    local uniqueID = sharedState.uniqueID
    --mj:log("remove:", uniqueID, ...)
    local count = select("#",...)

    local tableToUse = sharedState
    for i = 1,count - 1 do
        local subTableKey = select(i,...)
        local subTable = tableToUse[subTableKey]
        if not subTable then
            subTable = {}
            tableToUse[subTableKey] = subTable
        end
        tableToUse = subTable
    end
    
    local valueKey = select(count,...)

    if tableToUse[valueKey] ~= nil then

        local tableArrayCount = #tableToUse
        if tableArrayCount ~= nil and tableArrayCount > 1 and type(valueKey) == "number" and math.floor(valueKey) == valueKey and valueKey < tableArrayCount then
            mj:warn("using sharedState:remove on what looks like an array, may not be intended:", debug.traceback())
        end

        --mj:log("setting remove for value item")
        tableToUse[valueKey] = nil

        local objectStateDiff = stateDiffsByObjectID[uniqueID]
        if not objectStateDiff then
            objectStateDiff = {}
            stateDiffsByObjectID[uniqueID] = objectStateDiff
        end
        
        local clientTable = objectStateDiff
        for i = 1,count - 1 do
            local subTableKey = select(i,...)
            local subTable = clientTable[subTableKey]
            if not subTable then
                subTable = {}
                clientTable[subTableKey] = subTable
            end
            clientTable = subTable
        end

        if not clientTable["__0"] then
            clientTable["__0"] = {}
        end
        clientTable["__0"][valueKey] = true
        clientTable[valueKey] = nil
        
        serverGOM:saveObject(uniqueID)
    --else
        
        --mj:log("item to remove was already nil")
    end
end


function serverGameObjectSharedState:getAndResetStateDiff(object)

    --mj:log("serverGameObjectSharedState:getAndResetStateDiff:", object.uniqueID)

    if (not object.sharedState) or (not next(object.sharedState)) then
        if stateDiffsByObjectID then
            stateDiffsByObjectID[object.uniqueID] = nil
            return "__0"
        end
        --mj:log("serverGameObjectSharedState:return nil a")
        return nil
    end

    local objectStateDiff = stateDiffsByObjectID[object.uniqueID]

    if not objectStateDiff then
        stateDiffsByObjectID[object.uniqueID] = {}
       -- mj:log("serverGameObjectSharedState:return object.sharedState b:", object.sharedState)
        return object.sharedState
    end

    stateDiffsByObjectID[object.uniqueID] = {}
    --mj:log("serverGameObjectSharedState:return objectStateDiff:", objectStateDiff)
    return objectStateDiff
end


function serverGameObjectSharedState:removeAnyDiffStates(object)
    stateDiffsByObjectID[object.uniqueID] = nil
end

function serverGameObjectSharedState:init(serverGOM_)
    serverGOM = serverGOM_

    local serverDiffMetaTable = {
        __index = {
            set = set,
            remove = remove,
            removeFromArray = removeFromArray
        }
    }
    gameObjectSharedState:setServerDiffMetaTable(serverDiffMetaTable)
end


return serverGameObjectSharedState