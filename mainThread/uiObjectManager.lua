

local uiObjectManager = {
}

local bridge = nil

function uiObjectManager:setBridge(bridge_)
    bridge = bridge_
end

function uiObjectManager:addUIModel(
    modelIndex,
    scale,
    translation,
    rotation,
    materialSubstitution)

    return bridge:addUIModel(modelIndex,
    scale,
    translation,
    rotation,
    materialSubstitution or 0)

end

function uiObjectManager:updateUIModel(
uniqueID,
translation,
rotation,
snap)
    bridge:updateUIModel(
        uniqueID,
        translation,
        rotation,
        snap)
end

function uiObjectManager:removeUIModel(uniqueID)
    bridge:removeUIModel(uniqueID)
end

function uiObjectManager:getPlaceholderOffset(parentModelIndex, placeholderName)
    return bridge:getPlaceholderOffset(parentModelIndex, placeholderName)
end

function uiObjectManager:getPlaceholderRotation(parentModelIndex, placeholderName)
    return bridge:getPlaceholderRotation(parentModelIndex, placeholderName)
end

function uiObjectManager:addUIShaderMesh(
    shaderName,
    extraComponentCount,
    transparent,
    triCount,
    vertices,
    extraComponents,
    attributes)
    return bridge:addUIShaderMesh(
        shaderName,
        extraComponentCount,
        transparent,
        triCount,
        vertices,
        extraComponents,
        attributes)
end

function uiObjectManager:removeUIMesh(uniqueID)
    bridge:removeUIMesh(uniqueID)
end

return uiObjectManager