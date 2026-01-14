

local uiTerrainMeshRenderer = {
}

local bridge = nil

function uiTerrainMeshRenderer:setBridge(bridge_)
    bridge = bridge_
end

function uiTerrainMeshRenderer:addMesh(
    shaderName,
    vertexIndices)
    return bridge:addUITerrainMesh(
        shaderName,
        vertexIndices)
end

function uiTerrainMeshRenderer:updateMesh(uniqueID, vertexIndices)
    bridge:updateUITerrainMesh(uniqueID, vertexIndices)
end

function uiTerrainMeshRenderer:removeMesh(uniqueID)
    bridge:removeUITerrainMesh(uniqueID)
end

function uiTerrainMeshRenderer:setTerrainMeshHidden(uniqueID, hidden)
    bridge:setTerrainMeshHidden(uniqueID, hidden)
end

return uiTerrainMeshRenderer