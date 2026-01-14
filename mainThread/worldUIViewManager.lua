local worldUIViewManager = {
}

worldUIViewManager.groups = mj:enum {
    "sapienMarker",
    "orderMarker",
    "actionUI",
    "buildUI",
    "tribeSelectionMarker",
    "storageLogistics",
    "moveUIDestinationMarker",
    
    "interestTribeMarker",
    "interestNonFollowerSapienMarker",
    "interestTradeRequestMarker",
    "interestTradeOfferMarker",
    "interestQuestMarker",
    "interestDebugMarker",
}

local bridge = nil

function worldUIViewManager:setBridge(bridge_)
    bridge = bridge_
end

function worldUIViewManager:mouseDownInput(pos, buttonIndex)
    if bridge then
        return bridge:mouseDown(pos, buttonIndex)
    end
    return false
end

function worldUIViewManager:mouseUpInput(pos, buttonIndex)
    if bridge then
        bridge:mouseUp(pos, buttonIndex)
    end
end


function worldUIViewManager:vrMouseDown(buttonIndex)
    if bridge then
        return bridge:vrMouseDown(buttonIndex)
    end
    return false
end

function worldUIViewManager:vrMouseUp(buttonIndex)
    if bridge then
        bridge:vrMouseUp(buttonIndex)
    end
end

function worldUIViewManager:updatePointerRay()
    if bridge then
        return bridge:updatePointerRay()
    end
end



function worldUIViewManager:keyChangedInput(isDown, code, modKey, isRepeat)
    if bridge then
        return bridge:keyChanged(isDown, code, modKey, isRepeat)
    end
    return false
end

--[[
addView options:

baseRotation
startScalingDistance
offsets
minDistance
maxDistance
attachObjectUniqueID
attachBoneName
constantRotationMatrix
renderXRay
renderWhenCenterBehindCamera
]]

function worldUIViewManager:addView(basePos, groupID, options)
    return bridge:addView(basePos, groupID, options)
end

function worldUIViewManager:updateView(uniqueID, basePosOrTable, baseRotationOrNil, offsets, attachObjectUniqueIDOrNil, attachBoneNameOrNil, constantRotationMatrixOrNil)
    if type(basePosOrTable) == "table" then
        return bridge:updateView(uniqueID,
            basePosOrTable.basePos, 
            basePosOrTable.baseRotation, 
            basePosOrTable.offsets, 
            basePosOrTable.attachObjectUniqueID, 
            basePosOrTable.attachBoneName, 
            basePosOrTable.constantRotationMatrix)
    else
        bridge:updateView(uniqueID, basePosOrTable, baseRotationOrNil, offsets, attachObjectUniqueIDOrNil, attachBoneNameOrNil, constantRotationMatrixOrNil)
    end
end

function worldUIViewManager:scaleForViewAtPos(uniqueID, basePos)
    return bridge:scaleForViewAtPos(uniqueID, basePos)
end

function worldUIViewManager:addDistanceCallback(uniqueID, distance, callback)
    bridge:addDistanceCallback(uniqueID, distance, callback)
end

function worldUIViewManager:setMouseInteractionsEnabledForView(uniqueID, enabled)
    bridge:setMouseInteractionsEnabledForView(uniqueID, enabled)
end

function worldUIViewManager:setHidden(hidden)
    bridge:setHidden(hidden)
end

function worldUIViewManager:removeView(uniqueID)
    bridge:removeView(uniqueID)
end

function worldUIViewManager:setGroupHidden(groupID, hidden)
    bridge:setGroupHidden(groupID, hidden)
end

function worldUIViewManager:setAllHiddenExceptGroup(groupID)
    for thisGroupID,v in ipairs(worldUIViewManager.groups) do
        if thisGroupID == groupID then
            worldUIViewManager:setGroupHidden(thisGroupID, false)
        else
            worldUIViewManager:setGroupHidden(thisGroupID, true)
        end
    end
end


function worldUIViewManager:setAllHiddenExceptGroupsSet(groupsSet)
    for thisGroupID,v in ipairs(worldUIViewManager.groups) do
        if groupsSet[thisGroupID] then
            worldUIViewManager:setGroupHidden(thisGroupID, false)
        else
            worldUIViewManager:setGroupHidden(thisGroupID, true)
        end
    end
end

function worldUIViewManager:unhideAllGroups()
    for thisGroupID,v in ipairs(worldUIViewManager.groups) do
        worldUIViewManager:setGroupHidden(thisGroupID, false)
    end
end

return worldUIViewManager