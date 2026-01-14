local uiTerrainMeshRenderer = mjrequire "mainThread/uiTerrainMeshRenderer"

local lookAtTerrainMesh = {}

local currrentVertexID = nil
local currentMeshID = nil

function lookAtTerrainMesh:show(newVertexID)
    if currrentVertexID ~= newVertexID then
        currrentVertexID = newVertexID
        if currentMeshID then
            uiTerrainMeshRenderer:updateMesh(currentMeshID, {newVertexID})
            uiTerrainMeshRenderer:setTerrainMeshHidden(currentMeshID, false)
        else
            currentMeshID = uiTerrainMeshRenderer:addMesh("lookAtTerrainMesh", {newVertexID})
        end
    end
end

function lookAtTerrainMesh:hide()
    if currentMeshID then
        uiTerrainMeshRenderer:setTerrainMeshHidden(currentMeshID, true)
        currrentVertexID = nil
    end
end

return lookAtTerrainMesh