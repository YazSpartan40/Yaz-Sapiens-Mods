--local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
--local mat3Identity = mjm.mat3Identity

local gameObject = mjrequire "common/gameObject"
--local modelPlaceholder = mjrequire "common/modelPlaceholder"
--local resource = mjrequire "common/resource"
--local worldHelper = mjrequire "common/worldHelper"
local model = mjrequire "common/model"
local constructable = mjrequire "common/constructable"

local serverBuiltObject = {}

local serverGOM = nil

function serverBuiltObject:init(serverGOM_, serverWorld_, planManager_)
    serverGOM = serverGOM_
    --planManager = planManager_
   -- serverWorld = serverWorld_

    serverGOM:addObjectLoadedFunctionForTypes(gameObject.builtObjectTypes, function(object)
        --mj:log("calling object loaded function for built object:", object.uniqueID)

        serverBuiltObject:updateBuiltObjectSubModels(object)
        return false
    end)
    
end


function serverBuiltObject:updateBuiltObjectSubModels(object)
    local gameObjectType = gameObject.types[object.objectTypeIndex]
    if not (gameObjectType.isPathObject or gameObjectType.isPathBuildObject) then
        local subModelInfos = object.sharedState.subModelInfos
        if subModelInfos then
            local constructionObjects = object.sharedState.constructionObjects
            --mj:log("updateBuiltObjectSubModels:", object.uniqueID,   " constructionObjects:", constructionObjects, "sharedState:", object.sharedState)
            for i, subModelInfo in ipairs(subModelInfos) do
                
                local constructableTypeIndex = object.sharedState.constructionConstructableTypeIndex
                local constructableType = constructable.types[constructableTypeIndex]
                local modelName = constructableType.defaultSubModelName

                if constructionObjects then
                    for j=1,#constructionObjects do
                        local inventoryObjectInfo = constructionObjects[j]
                        local foundModelName = constructableType.subModelNameByObjectTypeIndexFunction(inventoryObjectInfo.objectTypeIndex)
                        if foundModelName then
                            modelName = foundModelName
                            break
                        end
                    end
                end

                local modelIndex = model:modelIndexForModelNameAndDetailLevel(modelName, 1)
                if not modelIndex then
                    mj:error("Attempt to load missing sub model:", modelName)
                    modelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.defaultSubModelName, 1)
                end
                
        
                local placeholderIdentifierToUse = "sub_" .. mj:tostring(i)
                serverGOM:setSubModelForKey(object.uniqueID,
                    placeholderIdentifierToUse,
                    nil,
                    modelIndex,
                    subModelInfo.scale,
                    RENDER_TYPE_STATIC,
                    subModelInfo.objectLocalOffsetMeters,
                    subModelInfo.rotation,
                    true,
                    nil
                    )
            end
        end
    elseif object.sharedState.subModelInfos then -- no longer needed in path objects
        --mj:log("removing sub model infos for object:", object.uniqueID)
        object.sharedState:remove("subModelInfos")
    end
end

--[[ --this almost worked, but ultimately a bad idea. If we're going to do this, we will need to store offsets and potentially rotations for every stored object, which will bloat world saves, network etc. Leave it for the client.
local function getSubModelTransform(object, placeholderName)
    return worldHelper:getSubModelTransformForModel(object.modelIndex, object.pos, object.rotation, object.scale, placeholderName, object.uniqueID, nil)
end

function serverBuiltObject:createSubModelTransforms(object)
    if object and object.sharedState then
        local sharedState = object.sharedState
        local transformsResult = {}
        local constructableTypeIndex = sharedState.constructionConstructableTypeIndex or sharedState.inProgressConstructableTypeIndex
        if constructableTypeIndex and constructable.types[constructableTypeIndex] then

            local constructableType = constructable.types[constructableTypeIndex]
            local requiredResources = constructableType.requiredResources
            
            local finalCountersByResourceTypeOrGroup = {}

            for i=1,#requiredResources do
                local groupIndex = i
            -- if isDeconstruct then
                --    groupIndex = #requiredResources - i + 1
            -- end
                local resourceInfo = requiredResources[groupIndex]
                
                local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group
                local requiredCount = resourceInfo.count

                if not finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] then
                    finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = 1
                end
                
                local resourceKey = resource:placheolderKeyForGroupOrResource(resourceTypeOrGroupIndex)
                
                
                for storageCounter=1,requiredCount do

                    local finalIndexIdentifier = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]
                    
                    local finalKeyBase = resourceKey .. "_"
                    local mainFinalKey = finalKeyBase .. finalIndexIdentifier
                    
                    
                    if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, mainFinalKey) then
                        finalKeyBase = "resource_"
                    end

                    mainFinalKey = finalKeyBase .. finalIndexIdentifier

                    local mainPlaceHolderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, mainFinalKey)

                    if mainPlaceHolderInfo then
                        local finalCount = 1
                        if mainPlaceHolderInfo.additionalIndexCount and mainPlaceHolderInfo.additionalIndexCount > 0 then
                            finalCount = 1 + mainPlaceHolderInfo.additionalIndexCount
                        end

                        finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + finalCount

                        for finalIndex=1,finalCount do
                            local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1
                            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, finalKey)
                            if placeholderInfo and placeholderInfo.defaultModelIndex and not placeholderInfo.hiddenOnBuildComplete then
                                local subModelTransform = getSubModelTransform(object, finalKey)
                                transformsResult[finalKey] = subModelTransform
                            end
                        end
                    end

                end
            end
        end

        if transformsResult and next(transformsResult) then
            object.sharedState:set("submodelTransforms", transformsResult)
        else
            object.sharedState:remove("submodelTransforms")
        end
    end
end]]

return serverBuiltObject