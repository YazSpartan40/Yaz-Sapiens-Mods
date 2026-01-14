-- NOTE - these test functions are not available on the main thread. Use the functions in mainThread/world.lua instead

local physicsSets = mjrequire "common/physicsSets"

local physics = {}

local bridge = nil
local gameObject = nil

function physics:rayTest(rayStart, rayEnd, physicsSetIndexOrNil, ignoreObjectIDOrNil)
    --mj:debug("physics:rayTest")
    return bridge:rayTest(rayStart, rayEnd, physicsSetIndexOrNil, ignoreObjectIDOrNil)
end

function physics:boxTest(pos, rotation, halfSize, useMeshForWorldObjects, physicsSetIndexOrNil)
    return bridge:boxTest(pos, rotation, halfSize, useMeshForWorldObjects, physicsSetIndexOrNil)
end

function physics:setObjectTypesForPhysicsSet(setIndex, gameObjectTypes)
	bridge:setObjectTypesForPhysicsSet(setIndex, gameObjectTypes)
end

function physics:getVertsAffectedByBuildModel(pos, rotation, scale, modelIndex, minAltitude)
    return bridge:getVertsAffectedByBuildModel(pos, rotation, scale, modelIndex, minAltitude)
end

function physics:modelTest(pos, rotation, scale, modelIndex, modelPrimitivesKeyBase, useMeshForWorldObjects, physicsSetIndexOrNil, collideWithAdditionalPrimitivesKeyBaseOrNil)
	return bridge:modelTest(pos, rotation, scale, modelIndex, modelPrimitivesKeyBase, useMeshForWorldObjects, physicsSetIndexOrNil, collideWithAdditionalPrimitivesKeyBaseOrNil)
end

function physics:doSlopeCheckForBuildModel(pos, rotation, scale, modelIndex, attachableObjectTypeSetIndex)
	return bridge:doSlopeCheckForBuildModel(pos, rotation, scale, modelIndex, attachableObjectTypeSetIndex)
end

function physics:setGameObject(gameObject_)
    gameObject = gameObject_
    if bridge then
        physicsSets:init(physics, gameObject)
    end
end

function physics:setBridge(bridge_)
    bridge = bridge_
    if gameObject then
        physicsSets:init(physics, gameObject)
    end
end

return physics