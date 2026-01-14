local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate

local modelPlaceholder = mjrequire "common/modelPlaceholder"
local sapienInventory = mjrequire "common/sapienInventory"
local storage = mjrequire "common/storage"
local action = mjrequire "common/action"
local gameObject = mjrequire "common/gameObject"

local clientGOM = nil

local clientSapienInventory = {}


function clientSapienInventory:hasHeldObjectOverride(sapien, clientState)
    return (clientState.heldObjectOverrides ~= nil)
end

function clientSapienInventory:assignHeldObjectOverrides(sapien, clientState, actionTypeIndex, gameObjectInfos, placementOverrides)
    --mj:log("clientSapienInventory:assignHeldObjectOverrides:", sapien.uniqueID, " infos:", gameObjectInfos, " placementOverrides:", placementOverrides)
    local changed = (not clientState.heldObjectOverrides) or clientState.heldObjectOverrideActionTypeIndex ~= actionTypeIndex
    
    if not changed then
        changed = #clientState.heldObjectOverrides ~= #gameObjectInfos
    end

    if not changed then
        for i,info in ipairs(gameObjectInfos) do
            if clientState.heldObjectOverrides[i] ~= gameObjectInfos[i] then
                changed = true
                break
            end
        end
    end

    if changed then
        clientState.heldObjectOverrides = gameObjectInfos
        clientState.placementOverrides = placementOverrides
        clientSapienInventory:updateHeldObjects(sapien, clientState, actionTypeIndex)
    end
end

function clientSapienInventory:removeHeldObjectOverrides(sapien, clientState)
    if clientState.heldObjectOverrides then
        clientState.heldObjectOverrides = nil
        clientSapienInventory:updateHeldObjects(sapien, clientState, nil)
    end
end


function clientSapienInventory:updateHeldObjects(sapien, clientState, actionTypeIndex)
    
    

    local incomingHeldObjects = nil
    local placementOverrides = nil
    
    if clientState.heldObjectOverrides then
        incomingHeldObjects = clientState.heldObjectOverrides
        placementOverrides = clientState.placementOverrides
    elseif actionTypeIndex == action.types.playDrum.index or actionTypeIndex == action.types.playBalafon.index then
        incomingHeldObjects = mj:cloneTable(sapienInventory:getObjects(sapien, sapienInventory.locations.held.index))
        table.insert(incomingHeldObjects, {
            objectTypeIndex = gameObject.types.drumStick.index,
        })
        table.insert(incomingHeldObjects, {
            objectTypeIndex = gameObject.types.drumStick.index,
        })
    elseif actionTypeIndex == action.types.chiselStone.index then
        incomingHeldObjects = mj:cloneTable(sapienInventory:getObjects(sapien, sapienInventory.locations.held.index))
    else
        incomingHeldObjects = sapienInventory:getObjects(sapien, sapienInventory.locations.held.index)
    end

    if not incomingHeldObjects then
        incomingHeldObjects = {}
    end
    
    if actionTypeIndex == action.types.chiselStone.index then
        table.insert(incomingHeldObjects, {
            objectTypeIndex = gameObject.types.rockSmall.index,
        })
    end
    

    local function getIsBeingPickedUp(isLastObject)
        if isLastObject and actionTypeIndex and (actionTypeIndex == action.types.pickupMultiAddToHeld.index or actionTypeIndex == action.types.placeMultiFromHeld.index) then
            return true
        end
        return false
    end

    local function getPlaceholderKey(placeholderIndex, forceRightHand)
        if placementOverrides and placementOverrides[placeholderIndex] and placementOverrides[placeholderIndex].placeholderKey then
            return placementOverrides[placeholderIndex].placeholderKey
        end

        if actionTypeIndex and action.types[actionTypeIndex].heldObjectPlaceholderKeyOverride then
            return action.types[actionTypeIndex].heldObjectPlaceholderKeyOverride
        end

        if actionTypeIndex == action.types.playDrum.index or actionTypeIndex == action.types.playBalafon.index then
            if placeholderIndex == 1 then
                return "rootObject"
            elseif placeholderIndex == 2 then
                return "heldObject"
            end
            return "leftHandObject"
        end

        
        if actionTypeIndex == action.types.chiselStone.index then
            if placeholderIndex == 1 then
                return "leftHandObject"
            end
            return "heldObject"
        end

        if (not placementOverrides) and (not forceRightHand) then
            if clientState.carryType == storage.carryTypes.high or clientState.carryType == storage.carryTypes.highSmall or clientState.carryType == storage.carryTypes.highMedium then
                return "shoulderObject"
            elseif clientState.carryType == storage.carryTypes.small then
                return "leftHandObject"
            else
                return "heldObject"
            end
        else
            return "heldObject"
        end
    end
    

    local function getCarryPlacementInfo(placeholderIndex, gameObjectType, isBeingPickedUp)

        if actionTypeIndex and action.types[actionTypeIndex].carryTransformFunction then
            return action.types[actionTypeIndex].carryTransformFunction(placeholderIndex, gameObjectType, isBeingPickedUp)
        end
        
        if actionTypeIndex == action.types.playDrum.index or actionTypeIndex == action.types.playBalafon.index then
            if placeholderIndex == 1 then
                return {
                    offset = vec3(0.0,0.6,0.0),
                    rotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi, vec3(0.0,0.0,1.0)), math.pi * -0.5, vec3(1.0,0.0,0.0)),
                }
            end
            if placeholderIndex == 2 then
                local rotation = mat3Rotate(mat3Identity, math.pi * 0.25, vec3(0.0,1.0,0.0))
                local offset = mjm.vec3xMat3(vec3(-0.2,0.0,0.0), mjm.mat3Inverse(rotation))
                return {
                    offset = offset,
                    rotation = rotation,
                }

            end
            local rotation = mat3Rotate(mat3Identity, math.pi * -0.25, vec3(0.0,1.0,0.0))
            local offset = mjm.vec3xMat3(vec3(-0.2,0.0,0.0), mjm.mat3Inverse(rotation))
            return {
                offset = offset,
                rotation = rotation,
            }
        end
        
        if actionTypeIndex == action.types.chiselStone.index then
            if placeholderIndex == 1 then
                return storage:carryPlacementInfoForResourceTypeAtIndex(sapien.uniqueID, gameObjectType.resourceTypeIndex, placeholderIndex, 1)
            end
            local rotation = mat3Identity
            local offset = vec3(0.0,0.0,0.0)
            return {
                offset = offset,
                rotation = rotation,
            }
        end
        
        local carryOffsetIndex = placeholderIndex
        if isBeingPickedUp then
            carryOffsetIndex = 1
        end
        
        if placementOverrides and placementOverrides[placeholderIndex] then
            return placementOverrides[placeholderIndex]
        else
            if gameObjectType and gameObjectType.resourceTypeIndex then
                return storage:carryPlacementInfoForResourceTypeAtIndex(sapien.uniqueID, gameObjectType.resourceTypeIndex, carryOffsetIndex, #incomingHeldObjects)
            end
        end

        return {}
    end

    local function getKey(heldObjectIndex)
        return "h_" .. mj:tostring(heldObjectIndex)
    end
    
    local function removeSubModelHeldObjectAtIndex(heldObjectIndex)
        --mj:log("remove:", getKey(heldObjectIndex))
        local key = getKey(heldObjectIndex)
        clientGOM:removeSubModelForKey(sapien.uniqueID, key)
    end


    local function assignObject(placeholderIndex, objectInfo, placeholderKey, isBeingPickedUp)
        clientState.heldObjectInfos[placeholderIndex] = {
            objectInfo = objectInfo,
            placeholderKey = placeholderKey,
        }
        local gameObjectType = gameObject.types[objectInfo.objectTypeIndex]

        local carryPlacementInfo = getCarryPlacementInfo(placeholderIndex, gameObjectType, isBeingPickedUp)

        --mj:log("sapien:setSubModelForKey:", sapien.uniqueID, " key:", getKey(placeholderIndex), " placeholderKey:", placeholderKey, " gameObjectType.modelIndex:", gameObjectType.modelIndex, " objectInfo:", objectInfo)
        
        clientGOM:setSubModelForKey(sapien.uniqueID,
            getKey(placeholderIndex),
            placeholderKey,
            gameObjectType.modelIndex,
            1.0,
            RENDER_TYPE_DYNAMIC,
            carryPlacementInfo.offset or vec3(0.0,0.0,0.0),
            carryPlacementInfo.rotation or mat3Identity,
            false,
            modelPlaceholder:getSubModelInfos(objectInfo, mj.SUBDIVISIONS - 1)
            )

    end

    if incomingHeldObjects and incomingHeldObjects[1] then
        local gameObjectType = gameObject.types[incomingHeldObjects[1].objectTypeIndex]
        if gameObjectType.resourceTypeIndex then
            clientState.carryType = storage:carryTypeForResourceType(gameObjectType.resourceTypeIndex, #incomingHeldObjects)
        else
            clientState.carryType = storage.carryTypes.standard
        end
    end

    local updateCounter = 0
    if clientState.heldObjectInfos then
        for i,oldHoldingObjectInfo in ipairs(clientState.heldObjectInfos) do
            if incomingHeldObjects and incomingHeldObjects[i] then
                local newHeldObjectInfo = incomingHeldObjects[i]
                local isLastObject = (i == #incomingHeldObjects)
                local isBeingPickedUp = getIsBeingPickedUp(isLastObject)
                local newPlaceholderKey = getPlaceholderKey(i, isBeingPickedUp or (clientState.carryType == storage.carryTypes.small and #incomingHeldObjects == 1))
                ----disabled--mj:objectLog(sapien.uniqueID, "update held object i:", i, " newPlaceholderKey:", newPlaceholderKey, " isBeingPickedUp:", isBeingPickedUp)
                if oldHoldingObjectInfo.objectInfo.objectTypeIndex ~= newHeldObjectInfo.objectTypeIndex or oldHoldingObjectInfo.placeholderKey ~= newPlaceholderKey then
                    ----disabled--mj:objectLog(sapien.uniqueID, "assignObject")
                    assignObject(i, newHeldObjectInfo, newPlaceholderKey, isBeingPickedUp)
                end
            else
                removeSubModelHeldObjectAtIndex(i)
                clientState.heldObjectInfos[i] = nil
            end
            updateCounter = updateCounter + 1
        end
    end

    if incomingHeldObjects and updateCounter < #incomingHeldObjects then
        for i = updateCounter + 1, #incomingHeldObjects do
            local newHeldObjectInfo = incomingHeldObjects[i]
            if i == 1 then
                clientState.heldObjectInfos = {}
            end
            local isLastObject = (i == #incomingHeldObjects)
            local isBeingPickedUp = getIsBeingPickedUp(isLastObject)
            local newPlaceholderKey = getPlaceholderKey(i, isBeingPickedUp or (clientState.carryType == storage.carryTypes.small and #incomingHeldObjects == 1))

            --mj:log("newHeldObjectInfo:", gameObject.types[newHeldObjectInfo.objectTypeIndex].name)

            assignObject(i, newHeldObjectInfo, newPlaceholderKey, isBeingPickedUp)
        end
    elseif clientState.heldObjectInfos and not clientState.heldObjectInfos[1] then
        clientState.heldObjectInfos = nil
    end
end

function clientSapienInventory:init(clientGOM_)
    clientGOM = clientGOM_
end


return clientSapienInventory