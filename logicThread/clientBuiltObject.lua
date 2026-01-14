--local mjm = mjrequire "common/mjm"
--local vec3 = mjm.vec3
--local mat3Identity = mjm.mat3Identity

local gameObject = mjrequire "common/gameObject"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local model = mjrequire "common/model"
local resource = mjrequire "common/resource"
local constructable = mjrequire "common/constructable"

local clientBuiltObject = {}

local clientGOM = nil

local objectsNeedingUpdate = {}


clientBuiltObject.serverUpdate = function(object, pos, rotation, scale, incomingServerStateDelta)
    objectsNeedingUpdate[object.uniqueID] = true
    --clientBuiltObject:updateBuiltObjectSubModels(object)
end

clientBuiltObject.objectWasLoaded = function(object, pos, rotation, scale)
    --mj:log("clientBuiltObject.objectWasLoaded:", object.uniqueID, " pos:", pos)

    objectsNeedingUpdate[object.uniqueID] = true
    --clientBuiltObject:updateBuiltObjectSubModels(object)
end

clientBuiltObject.objectSnapMatrix = function(object, pos, rotation)
    objectsNeedingUpdate[object.uniqueID] = true
    --clientBuiltObject:updateBuiltObjectSubModels(object)
end


clientBuiltObject.objectDetailLevelChanged = function(objectID, newDetailLevel)
    local object = clientGOM:getObjectWithID(objectID)
    if object then
        object.subdivLevel = newDetailLevel
        objectsNeedingUpdate[object.uniqueID] = true
        --clientBuiltObject:updateBuiltObjectSubModels(object)
    end
end

local function updateStandardSubModels(object)
    --disabled--mj:objectLog(object.uniqueID, "updateStandardSubModels")
    local placeholderContext = {
        subdivLevel = object.subdivLevel,
    }
    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(object.modelIndex)
    if placeholderKeys then
        for i,key in pairs(placeholderKeys) do
            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, key)
            local modelIndex = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
            if modelIndex then

                local subModelTransform = clientGOM:getSubModelTransform(object, key)

                clientGOM:setSubModelForKey(
                    object.uniqueID,
                    key,
                    nil,
                    modelIndex,
                    placeholderInfo.scale or 1.0,
                    RENDER_TYPE_STATIC,
                    subModelTransform.offsetMeters,
                    subModelTransform.rotation,
                    false,
                    nil
                    )
            end
        end
    end
end


function clientBuiltObject:updateBuiltObjectSubModels(object, optionsOrNil)

    --disabled--mj:objectLog(object.uniqueID, "updateBuiltObjectSubModels")
    clientGOM:removeAllSubmodels(object.uniqueID, optionsOrNil and optionsOrNil.preserveSubModelKeys)
    local createIfNil = false
    local constructionObjects = clientGOM:getSharedState(object, createIfNil, "constructionObjects")
    if constructionObjects then

        local constructableTypeIndex = object.sharedState.constructionConstructableTypeIndex
        
        if constructableTypeIndex and constructable.types[constructableTypeIndex] then
            local placeholderContext = {
                buildComplete = true,
                subdivLevel = object.subdivLevel,
            }

            if optionsOrNil and optionsOrNil.additionalPlaceholderContext then
                for k,v in pairs(optionsOrNil.additionalPlaceholderContext) do
                    placeholderContext[k] = v
                end
            end

            local constructableType = constructable.types[constructableTypeIndex]
            local requiredResources = constructableType.requiredResources

            
            local finalCountersByResourceTypeOrGroup = {}
            local usedObjects = {}
            
    --disabled--mj:objectLog(object.uniqueID, "requiredResources:", requiredResources)

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
                resourceKey = modelPlaceholder:resourceRemapForModelIndexAndResourceKey(object.modelIndex, resourceKey) or resourceKey
                
                ----disabled--mj:objectLog(object.uniqueID, "requiredCount:", requiredCount, " resourceKey:", resourceKey)
                
                for storageCounter=1,requiredCount do

                    local finalIndexIdentifier = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]
                    
                    local finalKeyBase = resourceKey .. "_"
                    local mainFinalKey = finalKeyBase .. finalIndexIdentifier
                    
                    
                    if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, mainFinalKey) then
                        finalKeyBase = "resource_"
                    end

                    mainFinalKey = finalKeyBase .. finalIndexIdentifier

                    local mainPlaceHolderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, mainFinalKey)

                    
                    ----disabled--mj:objectLog(object.uniqueID, "mainPlaceHolderInfo:", mainPlaceHolderInfo)
                

                    if mainPlaceHolderInfo then
                        local finalCount = 1
                        if mainPlaceHolderInfo.additionalIndexCount and mainPlaceHolderInfo.additionalIndexCount > 0 then
                            finalCount = 1 + mainPlaceHolderInfo.additionalIndexCount
                        end

                        finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + finalCount

                        local foundObjectInfo = nil

                        for j,objectInfo in ipairs(constructionObjects) do
                           -- mj:log("constructionObjects:", constructionObjects)
                            if not usedObjects[j] then
                                if resource:groupOrResourceMatchesResource(resourceTypeOrGroupIndex, gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex) then
                                    usedObjects[j] = true
                                    foundObjectInfo = objectInfo
                                    break
                                end
                            end
                        end

                        for finalIndex=1,finalCount do
                            local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1
                            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(object.modelIndex, finalKey)
                            if placeholderInfo and (placeholderInfo.defaultModelIndex or placeholderInfo.placeholderModelIndexForObjectTypeFunction) and (not placeholderInfo.hiddenOnBuildComplete) then
                                local modelIndexToUse = nil
                                if foundObjectInfo then
                                    modelIndexToUse = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, foundObjectInfo.objectTypeIndex, placeholderContext)
                                end
                                
                                --disabled--mj:objectLog(object.uniqueID, "modelIndexToUse a:", modelIndexToUse)

                                if (not modelIndexToUse) and (not placeholderInfo.placeholderModelIndexForObjectTypeFunction) then
                                    modelIndexToUse = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
                                end
                                --disabled--mj:objectLog(object.uniqueID, "modelIndexToUse b:", modelIndexToUse)
                                
                                if modelIndexToUse then
                                
                                    local subModelTransform = clientGOM:getSubModelTransform(object, finalKey)
                                    --local subModelTransform = clientGOM:getSubModelTransform(object, finalKey)

                                -- mj:log("setting sub model:", object.uniqueID, " finalKey:", finalKey, " subModelTransform:", subModelTransform)

                                    clientGOM:setSubModelForKey(object.uniqueID,
                                        finalKey,
                                        nil,
                                        modelIndexToUse,
                                        placeholderInfo.scale or 1.0,
                                        RENDER_TYPE_STATIC,
                                        subModelTransform.offsetMeters,
                                        subModelTransform.rotation,
                                        false,
                                        modelPlaceholder:getSubModelInfos(foundObjectInfo, object.subdivLevel)
                                        )
                                end
                            
                            end
                        end
                    end

                end
            end

        else
            clientGOM:setTransparentBuildObject(object.uniqueID, false)
            --updateStandardSubModels(object)
        end
    else
        clientGOM:setTransparentBuildObject(object.uniqueID, false) --maybe not necessary?
        updateStandardSubModels(object)
    end

    if not object.sharedState then
        mj:error("no object.sharedState:", object.uniqueID)
    end
    
    
    local subModelInfos = object.sharedState.subModelInfos
    if subModelInfos then
        --local createIfNil = false
        --local constructionObjects = clientGOM:getSharedState(object, createIfNil, "constructionObjects")
        --mj:log("updateBuiltObjectSubModels constructionObjects:", constructionObjects, "sharedState:", object.sharedState)
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

            local modelIndex = model:modelIndexForModelNameAndDetailLevel(modelName, model:modelLevelForSubdivLevel(object.subdivLevel))
            if not modelIndex then
                mj:error("Attempt to load missing sub model:", modelName)
                modelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.defaultSubModelName, 1)
            end
            
    
            local placeholderIdentifierToUse = "sub_" .. mj:tostring(i)
            clientGOM:setSubModelForKey(object.uniqueID,
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
end

function clientBuiltObject:update()
    for objectID,v in pairs(objectsNeedingUpdate) do
        local object = clientGOM:getObjectWithID(objectID)
        if object then
            clientBuiltObject:updateBuiltObjectSubModels(object)
        end
    end
    objectsNeedingUpdate = {}
end


function clientBuiltObject:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientBuiltObject