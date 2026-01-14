local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3 = mjm.mat3
local cross = mjm.cross

local typeMaps = mjrequire "common/typeMaps"

local seat = {}

seat.minWorldUpDotProduct = 0.9


seat.nodeTypes = typeMaps:createMap("seatNodeType", {
    {
        key = "yUpForwardOnly",
        sitDirections = {
            vec3(0.0,0.0,1.0),
        }
    },
    {
        key = "yUpForwardBack",
        sitDirections = {
            vec3(0.0,0.0,1.0),
            vec3(0.0,0.0,-1.0),
        },
        allowYFlip = true,
    },
    {
        key = "yUpAnyDirection",
        sitDirections = {
            vec3(0.0,0.0,1.0),
            vec3(0.0,0.0,-1.0),
            vec3(1.0,0.0,0.0),
            vec3(-1.0,0.0,0.0),
        }
    },
    {
        key = "yUpFlat",
        isFlatSurface = true, --they will sit cross legged like on the ground, don't need to test for ground for legs dangling over the edge, no support implemented for constraining direction
    },
    {
        key = "yZCircle", 
        sitDirections = {
            vec3(0.0,0.0,1.0),
            vec3(0.0,0.0,-1.0),
        }
    }
})

seat.types = typeMaps:createMap("seat", {
    {
        key = "bench",
        comfort = 0.5,
        nodes = {
            {
                placeholderKey = "seatNode_1",
                nodeTypeIndex = seat.nodeTypes.yUpForwardBack.index
            },
            {
                placeholderKey = "seatNode_2",
                nodeTypeIndex = seat.nodeTypes.yUpForwardBack.index,
            },
        }
    },
    {
        key = "log",
        comfort = 0.3,
        nodes = {
            {
                placeholderKey = "seatNode_1",
                nodeTypeIndex = seat.nodeTypes.yZCircle.index,
            },
            {
                placeholderKey = "seatNode_2",
                nodeTypeIndex = seat.nodeTypes.yZCircle.index,
            },
            {
                placeholderKey = "seatNode_3",
                nodeTypeIndex = seat.nodeTypes.yUpAnyDirection.index
            },
            {
                placeholderKey = "seatNode_4",
                nodeTypeIndex = seat.nodeTypes.yUpAnyDirection.index
            },
        }
    },
    {
        key = "bed",
        comfort = 1.0,
        nodes = {
            {
                placeholderKey = "seatNode_1",
                nodeTypeIndex = seat.nodeTypes.yUpFlat.index,
            },
        }
    },
    {
        key = "canoe",
        comfort = 0.5,
        dynamic = true, --will skip ray casts, and snap sapien rotation continuously
        onlyAllowAdultsWhenWaterRidable = true,
        isRidableObject = true,
        nodes = {
            {
                placeholderKey = "seatNode_1",
                nodeTypeIndex = seat.nodeTypes.yUpFlat.index,
            },
        }
    },
})


function seat:mjInit()
    
    seat.validNodeTypes = typeMaps:createValidTypesArray("seatNodeType", seat.nodeTypes)
    
    for i,nodeType in ipairs(seat.validNodeTypes) do
        if nodeType.sitDirections then
            nodeType.sitDirectionMatrices = {}
            for j, sitDirection in ipairs(nodeType.sitDirections) do
                local right = cross(vec3(0.0,1.0,0.0), sitDirection)
                table.insert(nodeType.sitDirectionMatrices, mat3(
                    right.x, right.y, right.z,
                    0.0,1.0,0.0,
                    sitDirection.x, sitDirection.y, sitDirection.z
                ))
            end

            if nodeType.allowYFlip then
                for j, sitDirection in ipairs(nodeType.sitDirections) do
                    local right = cross(vec3(0.0,-1.0,0.0), sitDirection)
                    table.insert(nodeType.sitDirectionMatrices, mat3(
                        right.x, right.y, right.z,
                        0.0,-1.0,0.0,
                        sitDirection.x, sitDirection.y, sitDirection.z
                    ))
                end
            end
        end
    end
end

return seat