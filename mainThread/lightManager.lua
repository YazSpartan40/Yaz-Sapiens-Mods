local lightManager = {}

local bridge = nil

function lightManager:setBridge(bridge_)
    bridge = bridge_
end

local lightIdsByObjectIds = {}

lightManager.lightPriorities = mj:enum {
    "standard",
    "high"
}

function lightManager:addLight(pos, color, priorityOrNil)
    return bridge:addLight(pos, color, priorityOrNil or lightManager.lightPriorities.standard)
end

function lightManager:updateLight(lightID, pos, color, priorityOrNil)
    --mj:log("lightManager:updateLight:",lightID, " color:", color)
    bridge:updateLight(lightID, pos, color, priorityOrNil or lightManager.lightPriorities.standard)
end

function lightManager:removeLight(lightID)
    bridge:removeLight(lightID)
end

function lightManager:addLightForObject(uniqueID, pos, color, priorityOrNil)
    if not lightIdsByObjectIds[uniqueID] then
        lightIdsByObjectIds[uniqueID] = lightManager:addLight(pos, color, priorityOrNil)
        --mj:log("added light for object:",uniqueID, " lightId:", lightIdsByObjectIds[uniqueID], " color:", color)
    end
end


function lightManager:removeLightForObject(uniqueID)
    local lightID = lightIdsByObjectIds[uniqueID]
    if lightID then
        bridge:removeLight(lightID)
        lightIdsByObjectIds[uniqueID] = nil
    end
end

function lightManager:getSSAORenderTarget()
    return bridge.ssaoRenderTarget
end

return lightManager