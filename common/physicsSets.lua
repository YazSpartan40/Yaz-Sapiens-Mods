

local physicsSets = mj:enum {
    "walkable",
    "autoClear",
    "snappingPlaceColliders",
    "femaleSnap",
    "attachable",
    "pathColliders",
    "plantable",
    "blocksRain",
    "pathSnappables",
    "roadsAndPaths",
    "buildRayColliders",
    "placeColliders",
    "storageLogisticsLookAtColliders",
    "disallowAnyCollisionsOnPlacement",
    "sapiens",
    "walkableOrInProgressWalkable",
}


function physicsSets:init(physicsSetController, gameObject)
    local objectTypeArrays = {}
    for i,k in ipairs(physicsSets) do
        objectTypeArrays[i] = {}
    end

    for i,gameObjectType in ipairs(gameObject.validTypes) do
        if gameObjectType.pathFindingDifficulty ~= nil then
            table.insert(objectTypeArrays[physicsSets.walkable], gameObjectType.index)
            table.insert(objectTypeArrays[physicsSets.walkableOrInProgressWalkable], gameObjectType.index)
        elseif gameObjectType.inProgressWalkable then
            table.insert(objectTypeArrays[physicsSets.walkableOrInProgressWalkable], gameObjectType.index)
        end

        if gameObjectType.isPathObject then
            table.insert(objectTypeArrays[physicsSets.roadsAndPaths], gameObjectType.index)
        end

        if gameObjectType.resourceTypeIndex then
            table.insert(objectTypeArrays[physicsSets.autoClear], gameObjectType.index)
        else
            if not gameObjectType.isNonPlaceCollider then
                table.insert(objectTypeArrays[physicsSets.snappingPlaceColliders], gameObjectType.index)
            end
        end
        
        if (not gameObjectType.resourceTypeIndex) and (not gameObjectType.ignoreBuildRay) then
            table.insert(objectTypeArrays[physicsSets.buildRayColliders], gameObjectType.index)
        else
            if gameObjectType.ignoreBuildRay and gameObjectType.femaleSnapPoints then
                mj:warn("ignoreBuildRay set on object type with female smap points:", gameObjectType.key)
            end
        end
        
        if gameObjectType.isStorageArea then
            table.insert(objectTypeArrays[physicsSets.storageLogisticsLookAtColliders], gameObjectType.index)
        end

        if gameObjectType.femaleSnapPoints then
            table.insert(objectTypeArrays[physicsSets.femaleSnap], gameObjectType.index)
        end

        if gameObjectType.isPathFindingCollider then--and not gameObjectType.isInProgressBuildObject then
            table.insert(objectTypeArrays[physicsSets.pathColliders], gameObjectType.index)
        end
        
        if gameObjectType.isBuiltObject or gameObjectType.isInProgressBuildObject then
            table.insert(objectTypeArrays[physicsSets.attachable], gameObjectType.index)
        end
        
        if gameObjectType.disallowAnyCollisionsOnPlacement then
            table.insert(objectTypeArrays[physicsSets.disallowAnyCollisionsOnPlacement], gameObjectType.index)
        end
        
        if gameObjectType.blocksRain then
            table.insert(objectTypeArrays[physicsSets.blocksRain], gameObjectType.index)
        end

        
        if gameObjectType.isPathSnappable then
            table.insert(objectTypeArrays[physicsSets.pathSnappables], gameObjectType.index)
        end
        
    end

    table.insert(objectTypeArrays[physicsSets.sapiens], gameObject.types.sapien.index)
    

    for i,objectTypeArray in ipairs(objectTypeArrays) do
        physicsSetController:setObjectTypesForPhysicsSet(i, objectTypeArray)
    end

end

return physicsSets