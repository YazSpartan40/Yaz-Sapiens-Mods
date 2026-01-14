local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4

local particleManagerInterface = {
}

local bridge = nil

function particleManagerInterface:setBridge(bridge_, emitterTypes)
    bridge = bridge_
    particleManagerInterface.emitterTypes = emitterTypes
end

function particleManagerInterface:addEmitter(typeIndex, pos, rotation, userDataVec4OrNil, covered)
    return bridge:addEmitter(typeIndex, pos, rotation, userDataVec4OrNil or vec4(0,0,0,0), covered)
end

function particleManagerInterface:updateEmitter(emitterID, pos, rotation, userDataVec4OrNil, covered)
    bridge:updateEmitter(emitterID, pos, rotation, userDataVec4OrNil or vec4(0,0,0,0), covered)
end

function particleManagerInterface:removeEmitter(emitterID)
    bridge:removeEmitter(emitterID)
end

return particleManagerInterface