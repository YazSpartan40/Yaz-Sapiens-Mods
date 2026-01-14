local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec3xMat3 = mjm.vec3xMat3
local length2 = mjm.length2
--local mat3Identity = mjm.mat3Identity
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local mat3GetRow = mjm.mat3GetRow
local mat3Inverse = mjm.mat3Inverse

local model = mjrequire "common/model"
local storage = mjrequire "common/storage"
local constructable = mjrequire "common/constructable"
local resource = mjrequire "common/resource"
local plan = mjrequire "common/plan"
local gameObject = mjrequire "common/gameObject"
local modelPlaceholder = mjrequire "common/modelPlaceholder"
local objectInventory = mjrequire "common/objectInventory"
local worldHelper = mjrequire "common/worldHelper"
local physicsSets = mjrequire "common/physicsSets"

local clientGOM = nil

local clientConstruction = {}

local function getModelIndexForPlaceholders(constructableType, subdivLevel)
    --[[local modelNameToUse = constructableType.placeholderOverrideModelName
    if not modelNameToUse then
        modelNameToUse = constructableType.inProgressBuildModel
    end]]
    
    local modelNameToUse = constructableType.inProgressBuildModel
    if not modelNameToUse then
        modelNameToUse = constructableType.modelName
    end

    local modelIndexForPlaceholders = model:modelIndexForModelNameAndDetailLevel(modelNameToUse, model:modelLevelForSubdivLevel(subdivLevel))
    return modelIndexForPlaceholders
end

local function getConstructableTypeIndex(craftOrBuildObject)
    local constructableTypeIndex = craftOrBuildObject.sharedState.inProgressConstructableTypeIndex
    if constructableTypeIndex then
        return constructableTypeIndex
    end

    local planStates = craftOrBuildObject.sharedState.planStates
    if planStates then
        for tribeID,planStatesForTribe in pairs(planStates) do
            for j,planState in ipairs(planStatesForTribe) do
                if planState.constructableTypeIndex then 
                    return planState.constructableTypeIndex
                end
            end
        end
    end

    return nil
end

function clientConstruction:hideStoreBuildObjectMoveModelIndex(buildOrCraftAreaObjectID)
    --disabled--mj:objectLog(buildOrCraftAreaObjectID, "hideStoreBuildObjectMoveModelIndex")
    local buildOrCraftAreaObject = clientGOM:getObjectWithID(buildOrCraftAreaObjectID)
    if buildOrCraftAreaObject then
        local clientState = clientGOM:getClientState(buildOrCraftAreaObject)
        if clientState.moveObjectIsDestruct then
            local finalKey = clientState.moveObjectFinalPlaceholderName

            local constructableTypeIndex = getConstructableTypeIndex(buildOrCraftAreaObject)
            local constructableType = constructable.types[constructableTypeIndex]
            local modelIndexForPlaceholders = getModelIndexForPlaceholders(constructableType, buildOrCraftAreaObject.subdivLevel)
            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, finalKey)
            
            if placeholderInfo then
                local placeholderContext = {
                    subdivLevel = buildOrCraftAreaObject.subdivLevel,
                }
                
                local modelIndex = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)
                --mj:log("placeholderInfo:", placeholderInfo, " modelIndexForPlaceholders:", modelIndexForPlaceholders, " finalKey:", finalKey)
                if modelIndex then
                    
                    local subModelTransform =
                        clientGOM:getSubModelTransformForModel(
                        modelIndexForPlaceholders,
                        buildOrCraftAreaObject.pos,
                        buildOrCraftAreaObject.rotation,
                        buildOrCraftAreaObject.scale,
                        finalKey,
                        buildOrCraftAreaObject.uniqueID
                    )
                    --disabled--mj:objectLog(buildOrCraftAreaObject.uniqueID,"setFinalPositionModelToTransparentDefault finalKey:",finalKey)
                    clientGOM:setSubModelForKey(buildOrCraftAreaObject.uniqueID,
                        finalKey,
                        nil,
                        modelIndex,
                        placeholderInfo.scale or 1.0,
                        RENDER_TYPE_STATIC_TRANSPARENT_BUILD,
                        subModelTransform.offsetMeters,
                        subModelTransform.rotation,
                        false,
                        nil
                    )
                end
            end
        else
            if clientState.moveObjectStoragePlaceholderIdentifier then
                clientGOM:removeSubModelForKey(buildOrCraftAreaObject.uniqueID, clientState.moveObjectStoragePlaceholderIdentifier)
            end
        end
    end
end

function clientConstruction:showFinalLocationBuildObjectMoveModelIndex(buildOrCraftAreaObjectID)
    local buildOrCraftAreaObject = clientGOM:getObjectWithID(buildOrCraftAreaObjectID)
    if buildOrCraftAreaObject then
        local clientState = clientGOM:getClientState(buildOrCraftAreaObject)
        --disabled--mj:objectLog(buildOrCraftAreaObjectID,"showFinalLocationBuildObjectMoveModelIndex moveObjectFinalPlaceholderName:",clientState.moveObjectFinalPlaceholderName)
        local identifierToUse = clientState.moveObjectFinalPlaceholderName
        if clientState.moveObjectIsDestruct then
            identifierToUse = clientState.moveObjectStoragePlaceholderIdentifier
        end
        if identifierToUse then
            if clientState.moveObjectIsDestruct then
                if clientState.finalLocationDisplayedByPlaceholderName then
                    clientState.finalLocationDisplayedByPlaceholderName[clientState.moveObjectFinalPlaceholderName] =
                        nil
                end
            else
                if not clientState.finalLocationDisplayedByPlaceholderName then
                    clientState.finalLocationDisplayedByPlaceholderName = {}
                end
                clientState.finalLocationDisplayedByPlaceholderName[clientState.moveObjectFinalPlaceholderName] = true
            end

            --local subModelTransform = clientGOM:getSubModelTransform(buildObject, clientState.moveObjectFinalPlaceholderName)

            clientGOM:setSubModelForKey(buildOrCraftAreaObject.uniqueID,
                identifierToUse,
                nil,
                clientState.moveObjectFinalSubModelIndex,
                clientState.moveObjectFinalSubModelScale,
                RENDER_TYPE_STATIC,
                clientState.moveObjectFinalPlaceholderSubModelTransform.offsetMeters,
                clientState.moveObjectFinalPlaceholderSubModelTransform.rotation,
                false,
                nil
            )
        end
    end
end

function clientConstruction:setToolHidden(craftOrBuildObject, newHidden)
    local clientState = clientGOM:getClientState(craftOrBuildObject)
    if (clientState.toolHidden and (not newHidden)) or ((not clientState.toolHidden) and newHidden) then
        clientState.toolHidden = newHidden
        clientConstruction:updatePlaceholdersForCraftOrBuild(craftOrBuildObject)
    end
end

function clientConstruction:setResourceHiddenIndex(craftOrBuildObject, hiddenInUseResourceIndex)
    local clientState = clientGOM:getClientState(craftOrBuildObject)
    if clientState.hiddenInUseResourceIndex ~= hiddenInUseResourceIndex then
        clientState.hiddenInUseResourceIndex = hiddenInUseResourceIndex
        --mj:log("clientConstruction:setResourceHiddenIndex:", hiddenInUseResourceIndex)
        clientConstruction:updatePlaceholdersForCraftOrBuild(craftOrBuildObject)
    end
end


local maxStorageHeightOffset2 = mj:mToP(4.0) * mj:mToP(4.0)

function clientConstruction:updatePlaceholdersForCraftOrBuild(craftOrBuildObject)

    
    local sharedState = craftOrBuildObject.sharedState
    local constructableTypeIndex = getConstructableTypeIndex(craftOrBuildObject)
    if not constructableTypeIndex then
        return
    end
    ---mj:warn("clientConstruction:updatePlaceholdersForCraftOrBuild:",craftOrBuildObject.uniqueID)

    local orderObjectGameObjectType = gameObject.types[craftOrBuildObject.objectTypeIndex]
    local isCraftArea = orderObjectGameObjectType.isCraftArea

    local constructableType = constructable.types[constructableTypeIndex]

    --mj:log("clientConstruction:updatePlaceholdersForCraftOrBuild:", craftOrBuildObject.uniqueID)
    -- mj:log("modelNameToUse:", modelNameToUse, " constructableType:", constructableType)

    local requiredResources = constructableType.requiredResources

    
    local placeholderContext = {
        subdivLevel = craftOrBuildObject.subdivLevel,
    }

    --mj:log("craftOrBuildObject id:", craftOrBuildObject.uniqueID, " rotation:", craftOrBuildObject.rotation)

    local clientState = clientGOM:getClientState(craftOrBuildObject)
    --local movedCount = objectInventory:getTotalCount(craftOrBuildObject.sharedState, objectInventory.locations.inUseResource.index)
    local objectIndex = 1
    --local totalCount = 0

    local inventories = sharedState.inventories
    local toolKey = "tool"

    local modelIndexForPlaceholders = getModelIndexForPlaceholders(constructableType, craftOrBuildObject.subdivLevel)
    
    local function getStorageTransform(resourceTypeIndex, counterIndexToUseOrNil, storageKey)
        local storageBox = storage:getStorageBoxForResourceType(resourceTypeIndex)
        local rotationFunction = nil
        if storageBox then
            rotationFunction = storageBox.rotationFunction
        end
        local localStorageOffsetMeters = nil
        if counterIndexToUseOrNil then
            localStorageOffsetMeters = storage:getPosition(resourceTypeIndex, storage.areaDistributions["2x2"].index, counterIndexToUseOrNil)
        else
            if storageBox then
                local offset = storageBox.offset or vec3(0.0,0.0,0.0)
                localStorageOffsetMeters = offset + vec3(0.0, (storageBox.size.y or 0.0) * 0.5, 0.0)
            else
                localStorageOffsetMeters = vec3(0.0,0.0,0.0)
            end
        end
        local localStorageOffset = mj:mToP(localStorageOffsetMeters)

        local placeholderPos =
            clientGOM:getOffsetForPlaceholderInModel(
            modelIndexForPlaceholders,
            craftOrBuildObject.rotation,
            1.0,
            storageKey
        )

        local worldPosition = craftOrBuildObject.pos + placeholderPos + vec3xMat3(localStorageOffset, mjm.mat3Inverse(craftOrBuildObject.rotation))
        local clampToSeaLevel = false
        local offsetPosition = worldHelper:getBelowSurfacePos(worldPosition, 0.3, physicsSets.walkableOrInProgressWalkable, nil, clampToSeaLevel)
        if length2(offsetPosition - worldPosition) > maxStorageHeightOffset2 then
            offsetPosition = worldPosition
        end
        local worldOffset = offsetPosition - craftOrBuildObject.pos
        local localOffset = vec3xMat3(worldOffset, (craftOrBuildObject.rotation))
        local localOffsetMeters = mj:pToM(localOffset) + vec3(0.0, localStorageOffsetMeters.y, 0.0) --vec3(0.0,localOffset.y, 0.0)) + vec3(localStorageOffsetMeters.x, localStorageOffsetMeters.y * 2.0, localStorageOffsetMeters.z)

        local upVector = worldHelper:getWalkableUpVector(worldPosition)
        local rotationMatrix =
            mat3Inverse(craftOrBuildObject.rotation) *
            createUpAlignedRotationMatrix(upVector, mat3GetRow(craftOrBuildObject.rotation, 2))

        if rotationFunction then
            rotationMatrix = rotationMatrix * rotationFunction(craftOrBuildObject.uniqueID, counterIndexToUseOrNil or 1)
        end

        --local placeholderRotation = clientGOM:getPlaceholderRotationForObject(object, storageAreaPlaceholderName)
        local placeholderRotation = clientGOM:getPlaceholderRotationForModel(modelIndexForPlaceholders, storageKey)

        rotationMatrix = placeholderRotation * rotationMatrix

        return {
            offsetMeters = localOffsetMeters,
            rotation = rotationMatrix
        }
    end

    if clientState.toolHidden then
        clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, toolKey)
    else
        local foundTool = false
        if inventories then
            local toolInventory = inventories[objectInventory.locations.tool.index]
            if toolInventory and toolInventory.objects[1] then
                local toolObjectInfo = toolInventory.objects[1]
                if not toolObjectInfo.objectTypeIndex then
                    mj:error("no toolObjectInfo.objectTypeIndex:", toolObjectInfo, " sharedState:", sharedState)
                    error()
                end
                local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, toolKey)
                if placeholderInfo then
                    foundTool = true
                    local subModelIndex =
                        modelPlaceholder:getPlaceholderModelIndexForObjectType(
                        placeholderInfo,
                        toolObjectInfo.objectTypeIndex,
                        placeholderContext
                    )
                    local resourceTypeIndex = gameObject.types[toolObjectInfo.objectTypeIndex].resourceTypeIndex
                    --local subModelTransform = getStorageTransform(resourceTypeIndex, nil, toolKey)

                    local subModelTransform =
                                            clientGOM:getSubModelTransformForModel(
                                            modelIndexForPlaceholders,
                                            craftOrBuildObject.pos,
                                            craftOrBuildObject.rotation,
                                            craftOrBuildObject.scale,
                                            toolKey,
                                            craftOrBuildObject.uniqueID,
                                            resourceTypeIndex
                                        )

                    clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                        toolKey,
                        nil,
                        subModelIndex,
                        placeholderInfo.scale or 1.0,
                        RENDER_TYPE_STATIC,
                        subModelTransform.offsetMeters,
                         -- + placeholderPos,
                        subModelTransform.rotation,
                         -- * placeholderRotation,
                        false,
                        modelPlaceholder:getSubModelInfos(toolObjectInfo, craftOrBuildObject.subdivLevel)
                    )
                end
            end
        end
        if not foundTool then
            clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, toolKey)
        end
    end

    local resourcePositionOverrides = nil

    if constructableType.buildSequence then
        local buildSequenceIndex = sharedState.buildSequenceIndex or 1
        local currentBuildSequenceInfo = constructableType.buildSequence[buildSequenceIndex]
        if currentBuildSequenceInfo then
            resourcePositionOverrides = currentBuildSequenceInfo.resourcePositionOverrides
            local buildSequenceSubModelAddition = currentBuildSequenceInfo.subModelAddition
            if buildSequenceSubModelAddition then
                local scale = 1.0
                local offsetMeters = vec3(0.0, 0.0, 0.0)
                local rotation = mjm.mat3Identity
                local subModelIndex = model:modelIndexForModelNameAndDetailLevel(buildSequenceSubModelAddition.modelName, model:modelLevelForSubdivLevel(craftOrBuildObject.subdivLevel))
                if buildSequenceSubModelAddition.placeholderKey then
                    local placeholderInfo =
                        modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(
                        modelIndexForPlaceholders,
                        buildSequenceSubModelAddition.placeholderKey
                    )
                    if placeholderInfo then
                        scale = placeholderInfo.scale or 1.0
                        local subModelTransform =
                            clientGOM:getSubModelTransformForModel(
                            modelIndexForPlaceholders,
                            craftOrBuildObject.pos,
                            craftOrBuildObject.rotation,
                            craftOrBuildObject.scale,
                            buildSequenceSubModelAddition.placeholderKey,
                            craftOrBuildObject.uniqueID
                        )
                        offsetMeters = subModelTransform.offsetMeters
                        rotation = subModelTransform.rotation
                    end
                end
                
                --mj:log("craftOrBuildObject id:", craftOrBuildObject.uniqueID, " rotation:", craftOrBuildObject.rotation, " buildSequenceSubModelAddition rotation:", rotation)
                clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                    "buildSequenceSubModelAddition",
                    nil,
                    subModelIndex,
                    scale,
                    RENDER_TYPE_STATIC,
                    offsetMeters,
                    rotation,
                    false,
                    nil
                )
            end
        end
    end

    local modelIndexForFinalModel = modelIndexForPlaceholders--model:modelIndexForModelNameAndDetailLevel(constructableType.modelName, 1) --this caused fruit to be displayed on in progress saplings

    
    --[[if constructableType.isPlaceType then
        local restrictedResourceTypes = sharedState.restrictedResourceObjectTypes
        local resourceInfo = constructableType.requiredResources[1]
        local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, restrictedResourceTypes, nil)
        
        if availableObjectTypeIndexes then
            modelIndexForFinalModel = gameObject.types[availableObjectTypeIndexes[1] ].modelIndex
        end
    end]]

    local remainingPlaceholderKeysWithDefaults = {}
    local placeholderKeys = modelPlaceholder:placeholderKeysForModelIndex(modelIndexForFinalModel)
    if placeholderKeys then
        --lderKeys:", placeholderKeys)
        for i, key in pairs(placeholderKeys) do
            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForFinalModel, key)
            --disabled--mj:objectLog(craftOrBuildObject.uniqueID, "placeholderInfo for key:", key, " info:", placeholderInfo)
            if placeholderInfo and placeholderInfo.defaultModelIndex then
                remainingPlaceholderKeysWithDefaults[key] = true
            end
        end
    end

    local function removeDefaultPlaceholderKey(key)
        remainingPlaceholderKeysWithDefaults[key] = nil
    end

    if requiredResources then

        local remainingInUseInventoryObjects = {}
        local remainingAvailableInventoryObjects = {}
        if inventories then
            local inventory = inventories[objectInventory.locations.inUseResource.index]
            if inventory then
                remainingInUseInventoryObjects = mj:cloneTable(inventory.objects)
            end
            inventory = inventories[objectInventory.locations.availableResource.index]
            if inventory then
                remainingAvailableInventoryObjects = mj:cloneTable(inventory.objects)
            end
        end

        local hasMovedAnyItems = (remainingInUseInventoryObjects[1] ~= nil)
        local inUseResourceCounter = 0

        local resourceCountersByResourceTypeOrGroup = {}
        local finalCountersByResourceTypeOrGroup = {}

        local foundResourceTypesCount = 0
        local hasFoundNextResourceToBeMoved = false

        local destructNextResourceToBeMovedToStorageResourceTypeIndex = nil
        local destructNextResourceToBeMovedToStorageCounterIndex = nil
        local destructNextResourceToBeMovedToStorageKey = nil

        local isDeconstruct = false
        local planState = clientGOM:getThisTribeFirstPlanStateForObjectSharedState(sharedState)
        if planState and (planState.planTypeIndex == plan.types.deconstruct.index or planState.planTypeIndex == plan.types.rebuild.index) then
            isDeconstruct = true
        end

        local totalFoundResourceTypesCountForResourceKeys = 0

        for i = 1, #requiredResources do
            local groupIndex = i
            -- if isDeconstruct then
            --    groupIndex = #requiredResources - i + 1
            -- end
            local resourceInfo = requiredResources[groupIndex]

            local resourceTypeOrGroupIndex = resourceInfo.type or resourceInfo.group
            local requiredCount = resourceInfo.count

            if not resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] then
                resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = 0
                finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = 1
            end


            local resourceKey = resource:placheolderKeyForGroupOrResource(resourceTypeOrGroupIndex)

            local remappedResourceKey = modelPlaceholder:resourceRemapForModelIndexAndResourceKey(modelIndexForPlaceholders, resourceKey) or resourceKey

            local storageKey = remappedResourceKey .. "_store"
            local storageKeyBase = remappedResourceKey .. "_store"
            
            if not modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, storageKey) then
                storageKey = "resource_store"
            end
            
            --disabled--mj:objectLog(craftOrBuildObject.uniqueID, "resourceKey:", resourceKey, " remappedResourceKey:", remappedResourceKey, " storageKey:", storageKey, " i:", i, " requiredCount:", requiredCount)

            for storageCounter = 1, requiredCount do
                resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + 1
                --finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + 1


                local resourceIndexIdentifier = resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]
                local finalIndexIdentifier = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]


                local storageAreaPlaceholderIdentifierWithIndex = storageKeyBase .. "_" .. resourceIndexIdentifier

                local finalKeyBase = remappedResourceKey .. "_"
                local mainFinalKey = finalKeyBase .. finalIndexIdentifier
                local mainPlaceHolderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, mainFinalKey)
                
                if not mainPlaceHolderInfo then
                    finalKeyBase = "resource_"
                    totalFoundResourceTypesCountForResourceKeys = totalFoundResourceTypesCountForResourceKeys + 1
                    finalIndexIdentifier = totalFoundResourceTypesCountForResourceKeys
                    mainFinalKey = finalKeyBase .. finalIndexIdentifier
                    mainPlaceHolderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, mainFinalKey)
                end

                
                --disabled--mj:objectLog(craftOrBuildObject.uniqueID, "mainPlaceHolderInfo for key:", mainFinalKey, " info:", mainPlaceHolderInfo)

                local finalCount = 1
                if mainPlaceHolderInfo and mainPlaceHolderInfo.additionalIndexCount and mainPlaceHolderInfo.additionalIndexCount > 0 then
                    finalCount = 1 + mainPlaceHolderInfo.additionalIndexCount
                end

                finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] = finalCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + finalCount

                -- mj:log("finalKey:", finalKey, " modelIndexForPlaceholders:", modelIndexForPlaceholders)

                local foundInInventoryObjectTypeInfo = nil
                local hasMoved = false

                if remainingInUseInventoryObjects then
                    for j, objectInfo in ipairs(remainingInUseInventoryObjects) do
                        if resource:groupOrResourceMatchesResource(
                                resourceTypeOrGroupIndex,
                                gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex
                            )
                         then
                            foundInInventoryObjectTypeInfo = objectInfo
                            hasMoved = true
                            table.remove(remainingInUseInventoryObjects, j)
                            inUseResourceCounter = inUseResourceCounter + 1
                            break
                        end
                    end
                end

                if not foundInInventoryObjectTypeInfo then
                    if remainingAvailableInventoryObjects then
                        for j, objectInfo in ipairs(remainingAvailableInventoryObjects) do
                            if
                                resource:groupOrResourceMatchesResource(
                                    resourceTypeOrGroupIndex,
                                    gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex
                                )
                             then
                                foundInInventoryObjectTypeInfo = objectInfo
                                table.remove(remainingAvailableInventoryObjects, j)
                                break
                            end
                        end
                    end
                end

                local function setFinalPositionModelToTransparentDefault()
                    if isCraftArea then
                        for finalIndex = 1, finalCount do
                            local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1
                            clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, finalKey)
                        end
                    else
                        for finalIndex = 1, finalCount do
                            local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1

                            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(
                                modelIndexForPlaceholders,
                                finalKey
                            )
                            if placeholderInfo then
                                local modelIndexToUse = modelPlaceholder:getPlaceholderModelIndexWithRestrictedObjectTypes(placeholderInfo, sharedState.restrictedResourceObjectTypes, nil, placeholderContext)
                                --mj:log("placeholderInfo:", placeholderInfo, " modelIndexForPlaceholders:", modelIndexForPlaceholders, " finalKey:", finalKey)
                                if modelIndexToUse then
                                    if constructableType.classification == constructable.classifications.research.index then
                                        clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, finalKey)
                                    else
                                        local subModelTransform =
                                            clientGOM:getSubModelTransformForModel(
                                            modelIndexForPlaceholders,
                                            craftOrBuildObject.pos,
                                            craftOrBuildObject.rotation,
                                            craftOrBuildObject.scale,
                                            finalKey,
                                            craftOrBuildObject.uniqueID
                                        )
                                        --disabled--mj:objectLog(craftOrBuildObject.uniqueID,"setFinalPositionModelToTransparentDefault finalKey:",finalKey)
                                        removeDefaultPlaceholderKey(finalKey)
                                        clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                                            finalKey,
                                            nil,
                                            modelIndexToUse,
                                            placeholderInfo.scale or 1.0,
                                            RENDER_TYPE_STATIC_TRANSPARENT_BUILD,
                                            subModelTransform.offsetMeters,
                                            subModelTransform.rotation,
                                            false,
                                            nil
                                        )
                                    end
                                end
                            end
                        end
                    end
                end

                if not foundInInventoryObjectTypeInfo then
                    --disabled--mj:objectLog(craftOrBuildObject.uniqueID,"not foundInInventoryObjectTypeInfo:",storageAreaPlaceholderIdentifierWithIndex)
                    setFinalPositionModelToTransparentDefault()
                    clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, storageAreaPlaceholderIdentifierWithIndex)
                else
                    if constructableType.isPlaceType then
                        local inventoryPlaceObjectKey = "place_" .. gameObject.types[foundInInventoryObjectTypeInfo.objectTypeIndex].key
                        if gameObject.types[inventoryPlaceObjectKey].index == craftOrBuildObject.objectTypeIndex then --this results in things looking bad if the delivered item doesn't match the preview
                            clientGOM:setTransparentBuildObject(craftOrBuildObject.uniqueID, false) 
                        end
                    else
                        --mj:log("hasMoved:", hasMoved, " inUseResourceCounter:", inUseResourceCounter, " clientState.hiddenInUseResourceIndex:", clientState.hiddenInUseResourceIndex)
                        local storageAreaPlaceholderIdentifierToUse = storageAreaPlaceholderIdentifierWithIndex

                        for finalIndex = 1, finalCount do
                            local finalKey = finalKeyBase .. finalIndexIdentifier + finalIndex - 1
                            --disabled--mj:objectLog(craftOrBuildObject.uniqueID, "else finalKey a:", finalKey)
                            if hasMoved and inUseResourceCounter == clientState.hiddenInUseResourceIndex then
                                clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, finalKey)
                            else
                                if hasMoved or
                                        (clientState.finalLocationDisplayedByPlaceholderName and clientState.finalLocationDisplayedByPlaceholderName[finalKey]) or
                                        constructableType.placeBuildObjectsInFinalLocationsOnDropOff
                                 then
                                    --disabled--mj:objectLog(craftOrBuildObject.uniqueID,"setting hasMoved:",hasMoved," clientState.finalLocationDisplayedByPlaceholderName[finalKey]:", clientState.finalLocationDisplayedByPlaceholderName and clientState.finalLocationDisplayedByPlaceholderName[finalKey]," finalKey:", finalKey)

                                    local finalKeyForTransform = finalKey
                                    if resourcePositionOverrides then
                                        if resourcePositionOverrides[finalKey] then
                                            finalKeyForTransform = resourcePositionOverrides[finalKey]
                                        end
                                    end

                                    local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForPlaceholders, finalKey)
                                    --disabled--mj:objectLog("placeholderInfo:", placeholderInfo, " finalKey:", finalKey)
                                    if placeholderInfo then
                                        local subModelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(placeholderInfo, foundInInventoryObjectTypeInfo.objectTypeIndex, placeholderContext)

                                        --[[if not subModelIndex then
                                            mj:log("model:modelInfoForModelIndex(modelIndexToFind):", model:modelInfoForModelIndex(modelIndexForPlaceholders))
                                            mj:error("no subModelIndex for placeholderInfo:", placeholderInfo, " foundInInventoryObjectTypeInfo:", foundInInventoryObjectTypeInfo, " placeholderContext:", placeholderContext, " foundInInventoryObjectTypeInfo.objectTypeIndex:", gameObject.types[foundInInventoryObjectTypeInfo.objectTypeIndex])
                                        end]]

                                       -- mj:log("calling getSubModelTransformForModel:", craftOrBuildObject.uniqueID)
                                        --disabled--mj:objectLog(craftOrBuildObject.uniqueID, "calling getSubModelTransformForModel:", finalKey)
                                        if subModelIndex then
                                            local subModelTransform = clientGOM:getSubModelTransformForModel(
                                                    modelIndexForPlaceholders,
                                                    craftOrBuildObject.pos,
                                                    craftOrBuildObject.rotation,
                                                    1,
                                                    finalKeyForTransform,
                                                    craftOrBuildObject.uniqueID,
                                                    gameObject.types[foundInInventoryObjectTypeInfo.objectTypeIndex].resourceTypeIndex)

                                            removeDefaultPlaceholderKey(finalKey)

                                            --disabled--mj:objectLog(craftOrBuildObject.uniqueID, "subModelTransform:", subModelTransform)

                                            clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                                                finalKey,
                                                nil,
                                                subModelIndex,
                                                placeholderInfo.scale or 1.0,
                                                RENDER_TYPE_STATIC,
                                                subModelTransform.offsetMeters,
                                                subModelTransform.rotation,
                                                false,
                                                modelPlaceholder:getSubModelInfos(foundInInventoryObjectTypeInfo, craftOrBuildObject.subdivLevel)
                                            )
                                        end
                                    end

                                    clientGOM:removeSubModelForKey(craftOrBuildObject.uniqueID, storageAreaPlaceholderIdentifierToUse)

                                    --[[if not hasMoved then
                                        hasFoundNextResourceToBeMoved = true
                                    else
                                        if clientState.finalLocationDisplayedByPlaceholderName then
                                            clientState.finalLocationDisplayedByPlaceholderName[finalKey] = nil
                                        end
                                    end]]
                                    if isDeconstruct and finalIndex == 1 then
                                        local storagePlaceholderInfo =
                                            modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(
                                            modelIndexForPlaceholders,
                                            storageKey
                                        )
                                        if storagePlaceholderInfo then
                                            hasFoundNextResourceToBeMoved = true
                                            clientState.moveObjectGameObjectInfo = foundInInventoryObjectTypeInfo
                                            clientState.moveObjectIsDestruct = isDeconstruct
                                            clientState.moveObjectStoragePlaceholderIdentifier = storageAreaPlaceholderIdentifierToUse
                                            clientState.moveObjectFinalPlaceholderName = finalKey

                                            local storageModelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(storagePlaceholderInfo, foundInInventoryObjectTypeInfo.objectTypeIndex, placeholderContext)
                                            clientState.moveObjectFinalSubModelIndex = storageModelIndex
                                            clientState.moveObjectFinalSubModelScale = storagePlaceholderInfo.scale or 1.0
                                            clientState.moveObjectAfterAction = resourceInfo.afterAction

                                            destructNextResourceToBeMovedToStorageResourceTypeIndex = gameObject.types[foundInInventoryObjectTypeInfo.objectTypeIndex].resourceTypeIndex
                                            destructNextResourceToBeMovedToStorageCounterIndex = requiredCount - resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex] + 1
                                            destructNextResourceToBeMovedToStorageKey = storageKey
                                        end
                                    end
                                else
                                    ----disabled--mj:objectLog(craftOrBuildObject.uniqueID, "else finalKey b:", finalKey)
                                    setFinalPositionModelToTransparentDefault()

                                    local storagePlaceholderInfo =
                                        modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(
                                        modelIndexForPlaceholders,
                                        storageKey
                                    )
                                    if storagePlaceholderInfo then
                                        local counterIndexToUse = resourceCountersByResourceTypeOrGroup[resourceTypeOrGroupIndex]
                                        if hasMovedAnyItems then
                                            counterIndexToUse = requiredCount - counterIndexToUse + 1 --reverse order when taking things off the pile
                                        end

                                        local resourceTypeIndex = gameObject.types[foundInInventoryObjectTypeInfo.objectTypeIndex].resourceTypeIndex

                                        local storageTransform = getStorageTransform(resourceTypeIndex, counterIndexToUse, storageKey)

                                        local storageModelIndex = modelPlaceholder:getPlaceholderModelIndexForObjectType(
                                            storagePlaceholderInfo,
                                            foundInInventoryObjectTypeInfo.objectTypeIndex,
                                            placeholderContext
                                        )
                                        ----disabled--mj:objectLog( craftOrBuildObject.uniqueID, "storageAreaPlaceholderIdentifierToUse:", storageAreaPlaceholderIdentifierToUse)
                                        removeDefaultPlaceholderKey(storageAreaPlaceholderIdentifierToUse)
                                        clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                                            storageAreaPlaceholderIdentifierToUse,
                                            nil,
                                            storageModelIndex,
                                            storagePlaceholderInfo.scale or 1.0,
                                            RENDER_TYPE_STATIC,
                                            storageTransform.offsetMeters,
                                            storageTransform.rotation,
                                            false,
                                            modelPlaceholder:getSubModelInfos(foundInInventoryObjectTypeInfo, craftOrBuildObject.subdivLevel)
                                        )

                                        if (not hasFoundNextResourceToBeMoved) and not isDeconstruct and finalIndex == 1 then
                                            hasFoundNextResourceToBeMoved = true
                                            clientState.moveObjectGameObjectInfo = foundInInventoryObjectTypeInfo
                                            clientState.moveObjectIsDestruct = isDeconstruct
                                            clientState.moveObjectStoragePlaceholderIdentifier = storageAreaPlaceholderIdentifierToUse
                                            clientState.moveObjectFinalPlaceholderName = finalKey
                                            clientState.moveObjectFinalSubModelIndex = storageModelIndex
                                            clientState.moveObjectFinalSubModelScale = storagePlaceholderInfo.scale or 1.0
                                            clientState.moveObjectAfterAction = resourceInfo.afterAction

                                            clientState.moveObjectFinalPlaceholderSubModelTransform = clientGOM:getSubModelTransformForModel(
                                                modelIndexForPlaceholders,
                                                craftOrBuildObject.pos,
                                                craftOrBuildObject.rotation,
                                                1.0,
                                                clientState.moveObjectFinalPlaceholderName,
                                                craftOrBuildObject.uniqueID,
                                                resourceTypeIndex
                                            )
                                        end
                                    end
                                end
                            end
                        end
                    end

                    foundResourceTypesCount = foundResourceTypesCount + 1
                end

                objectIndex = objectIndex + 1
            end
        end

        if hasFoundNextResourceToBeMoved and isDeconstruct then
            clientState.moveObjectFinalPlaceholderSubModelTransform = getStorageTransform(
                destructNextResourceToBeMovedToStorageResourceTypeIndex,
                destructNextResourceToBeMovedToStorageCounterIndex,
                destructNextResourceToBeMovedToStorageKey
            )
        --mj:log("clientState.moveObjectFinalPlaceholderSubModelTransform:", clientState.moveObjectFinalPlaceholderSubModelTransform)
        --mj:log("destructNextResourceToBeMovedToStorageKey:", destructNextResourceToBeMovedToStorageKey, " destructNextResourceToBeMovedToStorageCounterIndex:", destructNextResourceToBeMovedToStorageCounterIndex)
        end
    end

    local subModelInfos = craftOrBuildObject.sharedState.subModelInfos
    if not subModelInfos then
        subModelInfos = clientState.subModelInfos
    end

    if subModelInfos then
        --mj:log("updating submodels:", craftOrBuildObject.uniqueID)
        local inventoryObjects = nil
        if inventories then
            local inventory = inventories[objectInventory.locations.availableResource.index]
            if inventory and inventory.objects and next(inventory.objects) then
                inventoryObjects = inventory.objects
            else
                inventory = inventories[objectInventory.locations.inUseResource.index]
                if inventory then
                    inventoryObjects = inventory.objects
                end
            end
        end

        local movedCount = objectInventory:getTotalCount(craftOrBuildObject.sharedState, objectInventory.locations.inUseResource.index)

        for i, subModelInfo in ipairs(subModelInfos) do
            local modelName = constructableType.defaultSubModelName
            local renderType = RENDER_TYPE_STATIC_TRANSPARENT_BUILD
            if movedCount >= constructableType.requiredResourceTotalCount then --todo this probably isn't good enough
                renderType = RENDER_TYPE_STATIC
            end

            local foundInventoryModel = false
            if inventoryObjects then
                for j = 1, #inventoryObjects do
                    local inventoryObjectInfo = inventoryObjects[j]
                    local foundModelName = constructableType.subModelNameByObjectTypeIndexFunction(inventoryObjectInfo.objectTypeIndex)
                    if foundModelName then
                        modelName = foundModelName
                        foundInventoryModel = true
                        break
                    end
                end
            end

            if not foundInventoryModel then
                local resourceInfo = constructableType.requiredResources[1]
                local availableObjectTypeIndexes = gameObject:getAvailableGameObjectTypeIndexesForRestrictedResource(resourceInfo, sharedState.restrictedResourceObjectTypes, nil)
                if availableObjectTypeIndexes then
                    local foundModelName = constructableType.subModelNameByObjectTypeIndexFunction(availableObjectTypeIndexes[1])
                    if foundModelName then
                        modelName = foundModelName
                    end
                end
            end

            local subModelIndex = model:modelIndexForModelNameAndDetailLevel(modelName, model:modelLevelForSubdivLevel(craftOrBuildObject.subdivLevel))
            if not subModelIndex then
                mj:error("Attempt to load missing sub model:", modelName)
                subModelIndex = model:modelIndexForModelNameAndDetailLevel(constructableType.defaultSubModelName, 1)
            end
            

            local placeholderIdentifierToUse = "sub_" .. mj:tostring(i)
            --mj:log("setSubModelForKey:", placeholderIdentifierToUse, " objectLocalOffsetMeters:",subModelInfo.objectLocalOffsetMeters)
            clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                placeholderIdentifierToUse,
                nil,
                subModelIndex,
                subModelInfo.scale,
                renderType,
                subModelInfo.objectLocalOffsetMeters or subModelInfo.pos, --todo
                subModelInfo.rotation,
                false,
                nil
            )
        end
    end

    if constructableType.classification ~= constructable.classifications.research.index then
        for key, tf in pairs(remainingPlaceholderKeysWithDefaults) do
            local placeholderInfo = modelPlaceholder:placeholderInfoForModelAndPlaceholderKey(modelIndexForFinalModel, key)
            --mj:log("B placeholderInfo for key:", key, " info:", placeholderInfo)
            local subModelTransform = clientGOM:getSubModelTransformForModel(
                modelIndexForFinalModel,
                craftOrBuildObject.pos,
                craftOrBuildObject.rotation,
                craftOrBuildObject.scale,
                key,
                craftOrBuildObject.uniqueID
            )

            local defaultModelIndex = modelPlaceholder:getDefaultModelIndex(placeholderInfo, placeholderContext)

            clientGOM:setSubModelForKey(craftOrBuildObject.uniqueID,
                key,
                nil,
                defaultModelIndex,
                placeholderInfo.scale or 1.0,
                RENDER_TYPE_STATIC_TRANSPARENT_BUILD,
                subModelTransform.offsetMeters,
                subModelTransform.rotation,
                false,
                nil
            )
        end
    end
end

function clientConstruction:init(clientGOM_)
    clientGOM = clientGOM_
end

return clientConstruction
