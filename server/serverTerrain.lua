local terrain = mjrequire "common/terrain"

local mjm = mjrequire "common/mjm"
local length = mjm.length
local length2 = mjm.length2

local gameConstants = mjrequire "common/gameConstants"
local terrainTypesModule = mjrequire "common/terrainTypes"
local plan = mjrequire "common/plan"
local gameObject = mjrequire "common/gameObject"
local research = mjrequire "common/research"

--local serverTribe = mjrequire "server/serverTribe"
--local serverMobGroup = mjrequire "server/serverMobGroup"
local serverEvolvingTerrain = mjrequire "server/serverEvolvingTerrain"
local rng = mjrequire "common/randomNumberGenerator"
local serverResourceManager = mjrequire "server/serverResourceManager"


local serverTerrain = setmetatable({}, {__index=terrain})

local serverGOM = nil
local planManager = nil

local bridge = nil


local baseTypeChangeCallbackInfosByTerrainTypeIndex = {}
local baseTypeChangeTerrainTypesByObjectID = {}

local function callCallbacksForBaseTypeChange(vertPos, baseType, vertID)
    local callbackInfos = baseTypeChangeCallbackInfosByTerrainTypeIndex[baseType]
    if callbackInfos then
        for objectID,callbackInfo in pairs(callbackInfos) do
            local callbackDistance2 = length2(callbackInfo.pos - vertPos)
            if callbackDistance2 < serverResourceManager.storageResourceMaxDistance2 then
                callbackInfo.func(objectID, vertID)
            end
        end
    end
end

local function retrieveVertInfoForVert(vert)

    local sharedState = vert:getSharedState()

    if sharedState and not next(sharedState) then
        sharedState = nil
    end

    local vertInfo = {
        uniqueID = vert.uniqueID,
        pos = vert.pos,
        baseType = vert.baseType,
        variations = vert:getVariations(),
        sharedState = sharedState,
        offset = vert.offset,
        material = vert.material,
        altitude = vert.altitude
    }

    if sharedState and sharedState.modificationObjectID then
        vertInfo.planObjectInfo = serverGOM:getObjectWithID(sharedState.modificationObjectID)
    end

    return vertInfo
end


function serverTerrain:retrieveVertInfo(vertID)
    local vert = terrain:getVertWithID(vertID)

    if not vert then
        return nil
    end
    
    return retrieveVertInfoForVert(vert)
end

function serverTerrain:setBridge(bridge_)
    bridge = bridge_
    terrain:setBridge(bridge)
end

function serverTerrain:getObjectIDForTerrainModificationForVertex(vert)
    local sharedState = serverTerrain:getSharedLuaStateForVertex(vert)
    if sharedState then
        return sharedState.modificationObjectID
    end
    return nil
end

function serverTerrain:addAndSaveObjectIDForVertex(vert, objectID)
    local sharedState = serverTerrain:getSharedLuaStateForVertex(vert) or {}
    if not sharedState.modificationObjectID then
        sharedState.modificationObjectID = objectID
        serverTerrain:saveSharedLuaStateForVertex(vert, sharedState)
    end
end


function serverTerrain:outputsForDigAtVertex(vertID, isChisel)
    local vert = bridge:getVertWithID(vertID)
	local terrainTypeIndex = vert.baseType
	local variations = vert:getVariations()

	local isFilled = (vert.fillObjectType ~= 0)
    
	local outputs = {}
	local foundOutput = false

    if isFilled and (not isChisel) then
        local privateState = serverTerrain:getPrivateLuaStateForVertex(vert)
        if privateState then
            local fillCounts = privateState.fillCounts
            if fillCounts then
                local objectTypeCountsByObjectTypeIndex = fillCounts[vert.offset]
                if objectTypeCountsByObjectTypeIndex then
                    for objectTypeIndex, count in pairs(objectTypeCountsByObjectTypeIndex) do
                        table.insert(outputs, objectTypeIndex)
                    end
                    foundOutput = true
                end
            end
        end
    end


	local function addOutputIfAllowed(outputInfo)
		if (not isFilled) or outputInfo.allowsOutputWhenVertexHasBeenFilled then
			table.insert(outputs, outputInfo.objectKeyName)
			foundOutput = true
		end
	end

    if not foundOutput then
        local digOutputs = nil
        if isChisel then
            digOutputs = terrainTypesModule.baseTypes[terrainTypeIndex].chiselOutputs
        else
            digOutputs = terrainTypesModule.baseTypes[terrainTypeIndex].digOutputs
        end
        if digOutputs then
            for i,outputInfo in ipairs(digOutputs) do
                addOutputIfAllowed(outputInfo)
            end
        end
    end

	if variations then
		for variationTypeIndex,v in pairs(variations) do
			local variationOutputs = terrainTypesModule.variations[variationTypeIndex].digOutputs
			if variationOutputs then
				for i,outputInfo in ipairs(variationOutputs) do
					addOutputIfAllowed(outputInfo)
				end
			end
		end
	end

    local randomExtraOutputs = terrainTypesModule.baseTypes[terrainTypeIndex].randomExtraOutputs
    if randomExtraOutputs then
        for i,outputInfo in ipairs(randomExtraOutputs) do
            if outputInfo.chanceFraction and rng:valueForUniqueID(vertID, 38221 + (vert.offset or 0)) < outputInfo.chanceFraction then
                addOutputIfAllowed(outputInfo)
            end
        end
    end

	if foundOutput then
		return outputs
	end
	return nil
end


local function updateModificationsDueToDigOrFill(vertID) --modifications are stored individually for each offset. So when digging/filling we need to update the modification to the correct value for the private state. Kind of hacky.
    local vert = terrain:getVertWithID(vertID)
    local privateState = serverTerrain:getPrivateLuaStateForVertex(vert)
    if privateState and privateState.preventGrassAndSnowCount then
        serverTerrain:addModificationForVertex(vertID, terrainTypesModule.modifications.preventGrassAndSnow.index)
    else
        serverTerrain:removeModificationForVertex(vertID, terrainTypesModule.modifications.preventGrassAndSnow.index)
    end
end

local function vertWasModified(vertID, vert, prevBaseType, affectedObjects, tribeIDOrNil)
    serverTerrain:removeVegetationForVertex(vertID)
    serverTerrain:removeSnowForVertex(vertID)
    updateModificationsDueToDigOrFill(vertID)
    serverGOM:applyShiftsForObjectsForVertHeightModification(vertID, affectedObjects, tribeIDOrNil)
    planManager:updateImpossibleStatesForSurroundingVertsForTerrainLevelChange(vertID)
    serverGOM:updateTerrainModificationProxyObjectPosForTerrainModifcation(vertID)

    if prevBaseType ~= vert.baseType then
        callCallbacksForBaseTypeChange(vert.pos, prevBaseType, vertID)
        callCallbacksForBaseTypeChange(vert.pos, vert.baseType, vertID)
        serverGOM:updateObjectsForChangedSoilQuality(vertID)
    end
end

function serverTerrain:digVertex(vertID, tribeIDOrNil)
    local affectedObjects = serverGOM:getAffectedObjectInfosBeforeVertexHeightModification(vertID)
    
    local vert = bridge:getVertWithID(vertID)
    local prevBaseType = vert.baseType
	local isFilled = (vert.fillObjectType ~= 0)
    if isFilled then
        local privateState = serverTerrain:getPrivateLuaStateForVertex(vert)
        if privateState then
            local fillCounts = privateState.fillCounts
            if fillCounts then
                local objectTypeCountsByObjectTypeIndex = fillCounts[vert.offset]
                if objectTypeCountsByObjectTypeIndex then
                    fillCounts[vert.offset] = nil
                    serverTerrain:savePrivateLuaStateForVertex(vert, privateState)
                end
            end
        end
    end

    bridge:digVertex(vertID, 1)
    vertWasModified(vertID, vert, prevBaseType, affectedObjects, tribeIDOrNil)

end

function serverTerrain:fillVertex(vertID, objectTypeCountsByObjectTypeIndex, tribeID)
    local affectedObjects = serverGOM:getAffectedObjectInfosBeforeVertexHeightModification(vertID)
    local maxCount = 0
    local gameObjectTypeIndex = nil
    local differentTypesCount = 0
    for objectTypeIndex,count in pairs(objectTypeCountsByObjectTypeIndex) do
        differentTypesCount = differentTypesCount + 1
        if count > maxCount then
            gameObjectTypeIndex = objectTypeIndex
            maxCount = count
        end
    end
    local vert = terrain:getVertWithID(vertID)
    local prevBaseType = vert.baseType
    if differentTypesCount > 1 then
        local privateState = serverTerrain:getPrivateLuaStateForVertex(vert) or {}
        local fillCounts = privateState.fillCounts
        if not fillCounts then
            fillCounts = {}
            privateState.fillCounts = fillCounts
        end
        fillCounts[vert.offset + 1] = objectTypeCountsByObjectTypeIndex
        serverTerrain:savePrivateLuaStateForVertex(vert, privateState)
    end

    bridge:fillVertex(vertID, gameObjectTypeIndex, 1)
    vertWasModified(vertID, vert, prevBaseType, affectedObjects, tribeID)
    
end

function serverTerrain:levelArea(normalizedPos, radius) --flattens to average of the vert height. For UI based flattening, a new function should use the rounded height at the pos to flatten.
    serverTerrain:loadArea(normalizedPos)
    local vertIDs = terrain:getVertIDsWithinRadiusOfNormalizedPos(normalizedPos, radius)
    if not vertIDs then
        mj:warn("failed to load vert ids in serverTerrain:levelArea")
        return
    end
    local verts = {}
    local altitudeSum = 0.0

    
    for i,vertID in ipairs(vertIDs) do
        local vert = terrain:getVertWithID(vertID)
        if vert then
            table.insert(verts, vert)
            altitudeSum = altitudeSum + vert.altitude
        end
    end

    --mj:log("levelArea vertIDs count:", #vertIDs, " loaded:", #verts)

    if verts[1] then
        local averageAltitude = altitudeSum / #verts
        local averageAltitudeMeters = mj:pToM(averageAltitude)
        local floored = math.floor(averageAltitudeMeters)
        local roundedAverage = floored
        if averageAltitudeMeters - floored > 0.5 then
            roundedAverage = floored + 1
        end
        --mj:log("got verts roundedAverage:", roundedAverage, " averageAltitudeMeters:", averageAltitudeMeters)
        
        for i,vert in ipairs(verts) do
            local vertAltitudeMeters = math.floor(mj:pToM(vert.altitude))
            --mj:log("found vert:", vert.uniqueID, " vertAltitudeMeters:", vertAltitudeMeters)
            if vertAltitudeMeters > roundedAverage + 0.5 then
                local diffCount = math.ceil(vertAltitudeMeters - roundedAverage - 0.5)
                diffCount = math.min(diffCount, 8)
                --mj:log("digging:", diffCount, " id:", vert.uniqueID)
                for j=1,diffCount do
                    serverTerrain:digVertex(vert.uniqueID, nil)
                end
            elseif vertAltitudeMeters < roundedAverage - 0.5 then
                local terrainBaseType = terrainTypesModule.baseTypes[vert.baseType]
                local fillObjectTypeIndex = terrainBaseType.fillObjectTypeIndex
                if not fillObjectTypeIndex then
                    mj:warn("found no base type for vert:", vert, " terrainBaseType:", terrainBaseType)
                    fillObjectTypeIndex = gameObject.types.poorDirt.index
                end
                if fillObjectTypeIndex then
                    local diffCount = roundedAverage - vertAltitudeMeters
                    diffCount = math.min(diffCount, 8)
                    --mj:log("filling:", diffCount, " id:", vert.uniqueID)
                    for j=1,diffCount do
                        serverTerrain:fillVertex(vert.uniqueID, {
                            [fillObjectTypeIndex] = 1,
                        }, nil)
                    end
                end
            end
        end
    end
end

function serverTerrain:createResourceQuarry(normalizedPos, radius, depthMeters, fillGameObjectTypeIndex)
    serverTerrain:loadAreaAtLevels(normalizedPos, mj.SUBDIVISIONS - 4, mj.SUBDIVISIONS - 1)
    local vertIDs = terrain:getVertIDsWithinRadiusOfNormalizedPos(normalizedPos, radius)
    if not (vertIDs and vertIDs[1]) then
        serverTerrain:loadArea(normalizedPos)
        vertIDs = terrain:getVertIDsWithinRadiusOfNormalizedPos(normalizedPos, radius)
        if not vertIDs then
            mj:warn("failed to load vert ids in serverTerrain:levelArea")
            return
        end
    end
    --mj:log("vertIDs:", vertIDs)
    
    for i,vertID in ipairs(vertIDs) do
        local vert = terrain:getVertWithID(vertID)
        if vert then
            local vertDistance = length(vert.normalizedVert - normalizedPos)
            local randomOffsetFraction = rng:valueForUniqueID(vert.uniqueID, 3258) * -0.5
            local depthToUse = ((1.1 - (vertDistance / radius)) + randomOffsetFraction) * depthMeters
            if depthToUse >= 1 then
                depthToUse = math.floor(math.min(depthToUse, depthMeters))
                --mj:log("depthToUse:", depthToUse)

                local affectedObjects = serverGOM:getAffectedObjectInfosBeforeVertexHeightModification(vertID)
                local nonRemovedAffectedObjects = {}

                for j, objectInfo in ipairs(affectedObjects) do
                    local affectedObject = objectInfo.object
                    if serverGOM:objectCanBeRemovedHarmlessly(affectedObject) then
                        --mj:log("remove:", affectedObject.uniqueID)
                        serverGOM:removeGameObject(affectedObject.uniqueID)
                    else
                        --mj:log("skip:", affectedObject.uniqueID)
                        table.insert(nonRemovedAffectedObjects, objectInfo)
                    end
                end
    
                local prevBaseType = vert.baseType
                local isFilled = (vert.fillObjectType ~= 0)
                if isFilled then
                    local privateState = serverTerrain:getPrivateLuaStateForVertex(vert)
                    if privateState then
                        local fillCounts = privateState.fillCounts
                        if fillCounts then
                            local objectTypeCountsByObjectTypeIndex = fillCounts[vert.offset]
                            if objectTypeCountsByObjectTypeIndex then
                                fillCounts[vert.offset] = nil
                                serverTerrain:savePrivateLuaStateForVertex(vert, privateState)
                            end
                        end
                    end
                end
            
                bridge:digVertex(vertID, depthToUse + 2)
                if depthToUse > 0 then
                    bridge:fillVertex(vertID, fillGameObjectTypeIndex, depthToUse + 1)
                end
                vertWasModified(vertID, vert, prevBaseType, nonRemovedAffectedObjects, nil)
            end
        end
    end
end

function serverTerrain:changeVertexSurfaceFill(vertID, fillGameObjectTypeIndex)
    bridge:changeVertexSurfaceFill(vertID, fillGameObjectTypeIndex)
end

function serverTerrain:changeSoilQualityForVertex(vertID, qualityOffset)
    local vert = bridge:getVertWithID(vertID)
    local terrainBaseType = terrainTypesModule.baseTypes[vert.baseType]
    local fillGameObjectTypeIndex = nil
    if qualityOffset > 0 and terrainBaseType.fertilizedTerrainTypeKey then
        local fertilizedFillTerrainType = terrainTypesModule.baseTypes[terrainBaseType.fertilizedTerrainTypeKey]
        fillGameObjectTypeIndex = fertilizedFillTerrainType.fillObjectTypeIndex
    elseif qualityOffset < 0 and terrainBaseType.defertilizedTerrainTypeKey then
        local defertilizedFillTerrainType = terrainTypesModule.baseTypes[terrainBaseType.defertilizedTerrainTypeKey]
        fillGameObjectTypeIndex = defertilizedFillTerrainType.fillObjectTypeIndex
    --else--this is OK, just trying to degrade poor soil probably. Don't set fillGameObjectTypeIndex.
       -- mj:error("changeSoilQualityForVertex called with qualityOffset:", qualityOffset, " incompatible with terrain type:", terrainBaseType) 
    end

    if fillGameObjectTypeIndex then
        serverTerrain:changeVertexSurfaceFill(vertID, fillGameObjectTypeIndex)
        serverTerrain:removeVegetationForVertex(vertID)
        serverTerrain:removeSnowForVertex(vertID)

        if qualityOffset > 0 then -- if fertalizing, reset the partial degraded fertitlity offset to ensure full fertility
            local privateState = serverTerrain:getPrivateLuaStateForVertex(vert) or {}
            privateState.fertilityOffset = 0
            serverTerrain:savePrivateLuaStateForVertex(vert, privateState)
        end
        
        callCallbacksForBaseTypeChange(vert.pos, terrainBaseType.index, vertID)
        callCallbacksForBaseTypeChange(vert.pos, vert.baseType, vertID)
        serverGOM:updateObjectsForChangedSoilQuality(vertID)
    end


end


function serverTerrain:partiallyDegradeSoilFertilityForVertex(vertID, fertilityOffset)
    local vert = bridge:getVertWithID(vertID)
    local privateState = serverTerrain:getPrivateLuaStateForVertex(vert) or {}
    local currentFertilityOffset = privateState.fertilityOffset
    if not currentFertilityOffset then
        currentFertilityOffset = rng:integerForUniqueID(vertID, 285, math.floor(gameConstants.harvestCountForSoilFertilityDegredation * 0.75))
    end
    privateState.fertilityOffset = currentFertilityOffset + fertilityOffset
    if privateState.fertilityOffset >= gameConstants.harvestCountForSoilFertilityDegredation then
        privateState.fertilityOffset = privateState.fertilityOffset - gameConstants.harvestCountForSoilFertilityDegredation
        serverTerrain:changeSoilQualityForVertex(vertID, -1)
    end
    serverTerrain:savePrivateLuaStateForVertex(vert, privateState)
end

function serverTerrain:addModificationForVertex(vertID, modificationTypeIndex)
    bridge:addModificationForVertex(vertID, modificationTypeIndex)
end

function serverTerrain:removeModificationForVertex(vertID, modificationTypeIndex)
    bridge:removeModificationForVertex(vertID, modificationTypeIndex)
end

function serverTerrain:hasModificationForVertex(vertID, modificationTypeIndex)
    return bridge:hasModificationForVertex(vertID, modificationTypeIndex)
end

function serverTerrain:getHasRemovedTransientObjectsNearPos(pos) --doesnt matter if normalized. Area needs to be loaded. This is a good general guide to say if the area has been modified in any way by the player.
    return bridge:getHasRemovedTransientObjectsNearPos(pos)
end

function serverTerrain:removeSnowForVertex(vertID)
    local removalTypeIndex = terrainTypesModule.modifications.snowRemoved.index
    if not bridge:hasModificationForVertex(vertID, removalTypeIndex) then
        serverTerrain:addModificationForVertex(vertID, removalTypeIndex)
        serverEvolvingTerrain:addCallbacksForRemoval(vertID, removalTypeIndex)
        return true
    end
    return false
end

function serverTerrain:removeVegetationForVertex(vertID)
    local removalTypeIndex = terrainTypesModule.modifications.vegetationRemoved.index
    if not bridge:hasModificationForVertex(vertID, removalTypeIndex) then
        serverTerrain:addModificationForVertex(vertID, removalTypeIndex)
        serverEvolvingTerrain:addCallbacksForRemoval(vertID, removalTypeIndex)
        return true
    end
    return false
end

function serverTerrain:removeSingleSnowNear(vertID, normalizedPos, radius)
    local nearVerts = terrain:getVertIDsWithinRadiusOfVertID(vertID, normalizedPos, radius)
    --mj:log("serverTerrain:removeSingleSnowNear nearVerts:", nearVerts)
    if nearVerts then
        for i,otherVertID in ipairs(nearVerts) do
            if serverTerrain:removeSnowForVertex(otherVertID) then
                --mj:log("removed snow:", otherVertID)
                return
            end
        end
    end
end


function serverTerrain:addToPreventGrassAndSnowCountForVert(vertID, change, normalizedPos)
    local vert = terrain:getVertWithID(vertID)
    if (not vert) and normalizedPos then
        serverTerrain:loadArea(normalizedPos)
        vert = terrain:getVertWithID(vertID)
    end

    if not vert then
        mj:warn("no vert found in addToPreventGrassAndSnowCountForVert:", vertID)
        return
    end
    
    local privateState = serverTerrain:getPrivateLuaStateForVertex(vert) or {}

    if privateState.preventGrassAndSnowCount then
        privateState.preventGrassAndSnowCount = privateState.preventGrassAndSnowCount + change
        if privateState.preventGrassAndSnowCount <= 0 then
            privateState.preventGrassAndSnowCount = nil
            serverTerrain:removeModificationForVertex(vertID, terrainTypesModule.modifications.preventGrassAndSnow.index)

            local removalTypeIndex = terrainTypesModule.modifications.vegetationRemoved.index
            if serverTerrain:hasModificationForVertex(vertID, removalTypeIndex) then
                serverEvolvingTerrain:addCallbacksForRemoval(vertID, removalTypeIndex)
            end
            removalTypeIndex = terrainTypesModule.modifications.snowRemoved.index
            if serverTerrain:hasModificationForVertex(vertID, removalTypeIndex) then
                serverEvolvingTerrain:addCallbacksForRemoval(vertID, removalTypeIndex)
            end
        end
    else
        if change > 0 then
            privateState.preventGrassAndSnowCount = change
            
            serverTerrain:addModificationForVertex(vertID, terrainTypesModule.modifications.preventGrassAndSnow.index)
        end
    end
    
    serverTerrain:savePrivateLuaStateForVertex(vert, privateState)
end

function serverTerrain:getPrivateLuaStateForFace(face)
	return bridge:getPrivateLuaStateForFace(face)
end

function serverTerrain:savePrivateLuaStateForFace(face, facePrivateState)
	bridge:savePrivateLuaStateForFace(face, facePrivateState)
end

function serverTerrain:getSharedLuaStateForFace(face)
	return bridge:getSharedLuaStateForFace(face)
end

function serverTerrain:saveSharedLuaStateForFace(face, faceSharedState)
	bridge:saveSharedLuaStateForFace(face, faceSharedState)
end

function serverTerrain:getPrivateLuaStateForVertex(vert)
	return bridge:getPrivateLuaStateForVertex(vert)
end

function serverTerrain:savePrivateLuaStateForVertex(vert, vertPrivateState)
	bridge:savePrivateLuaStateForVertex(vert, vertPrivateState)
end

function serverTerrain:getSharedLuaStateForVertex(vert)
	return bridge:getSharedLuaStateForVertex(vert)
end

function serverTerrain:saveSharedLuaStateForVertex(vert, vertSharedState)
	bridge:saveSharedLuaStateForVertex(vert, vertSharedState)
end

function serverTerrain:loadArea(normalizedPosition)
    local faceID = bridge:getFaceIDForNormalizedPointAtLevel(normalizedPosition, mj.SUBDIVISIONS - 2)
	bridge:addTemporaryAnchorForFaceID(faceID, mj.SUBDIVISIONS - 1, true, 60.0) --third argument is whether to pad it, 4th is duration
end

function serverTerrain:loadAreaAtLevels(normalizedPosition, faceLevel, subdivLevel)
    local faceID = bridge:getFaceIDForNormalizedPointAtLevel(normalizedPosition, faceLevel)
	bridge:addTemporaryAnchorForFaceID(faceID, subdivLevel, true, 60.0)
end


function serverTerrain:addTemporaryAnchorForFaceID(faceID, subdivLevel)
	bridge:addTemporaryAnchorForFaceID(faceID, subdivLevel, true, 60.0)
end

function serverTerrain:updatePlayerAnchor(clientID)
    bridge:updatePlayerAnchor(clientID)
end

function serverTerrain:vertCanBeCleared(vertID)
    local vert = bridge:getVertWithID(vertID)
    if vert then
        local variations = vert:getVariations()
        if variations then
            for terrainVariationTypeIndex,v in pairs(variations) do
                local terrainVariationType = terrainTypesModule.variations[terrainVariationTypeIndex]
                if terrainVariationType.canBeCleared then
                    return true
                end
            end
        end
    end
    return false
end

function serverTerrain:vertCanBeFertilized(vertID)
    local vert = bridge:getVertWithID(vertID)
    if vert then
        local terrainBaseType = terrainTypesModule.baseTypes[vert.baseType]
        if terrainBaseType.fertilizedTerrainTypeKey then
            return true
        end
    end
    return false
end


function serverTerrain:startPlanWithDeliveredPlanObject(planObject, objectInfo, sapien) --only supports research for now
    mj:log("serverTerrain:startPlanWithDeliveredPlanObject objectInfo:", objectInfo)
    if objectInfo.orderContext and objectInfo.orderContext.planState then
        local planTypeIndex = plan.types.research.index
        local tribeID = sapien.sharedState.tribeID
        local vertID = planObject.sharedState.vertID
        local deliverObjectPlanState = objectInfo.orderContext.planState
        local researchTypeIndex = deliverObjectPlanState.researchTypeIndex
        local restrictedResourceObjectTypes = objectInfo.restrictedResourceObjectTypes
        local restrictedToolObjectTypes = objectInfo.restrictedToolObjectTypes



                --[[

                
function planManager:addBuildOrPlantPlan(tribeID, 
    planTypeIndex, 
    constructableTypeIndex,
    researchTypeIndex,
    pos, 
    rotation, 

    sapienIDOrNil, 
    subModelInfosOrNil, 
    attachedToTerrain,
    decalBlockersOrNil,

    restrictedResourceObjectTypesOrNil,
    restrictedToolObjectTypesOrNil,
    noBuildOrder)

anState = {
            tribeID = 8815,
            missingStorageAreaContainedObjects = true,
            discoveryCraftableTypeIndex = 11033(constructable.canoe),
            suitableTerrainVertID = 9cdef1698c740,
            suitableTerrainVertPos = vec3(0.18636547637729, 0.099476855737061, 0.97743146275702),
            planTypeIndex = 10898(plan.research),
            requiredSkill = 10623(skill.researching),

            manualAssignedSapien = b5b5,
            priorityOffset = 5,

            objectTypeIndex = 11375(gameObject.pineLog),
            researchTypeIndex = 11837(researchable.woodWorking),
            requiresShallowWater = true,
            canComplete = false,
            planID = 1474,

                ]]

        if researchTypeIndex then
            if deliverObjectPlanState.requiresShallowWater then --crude, but not sure what a more generic check/api needs to be at this point
                local constructableTypeIndex = deliverObjectPlanState.discoveryCraftableTypeIndex
                local buildObjectID = planManager:addBuildOrPlantPlan(tribeID, 
                planTypeIndex, 
                constructableTypeIndex,
                researchTypeIndex,
                planObject.pos, 
                planObject.rotation, 
                nil, 
                nil, 
                true,
                nil,

                restrictedResourceObjectTypes,
                restrictedToolObjectTypes,
                false)
                
                mj:log("requiresShallowWater. deliverObjectPlanState:", deliverObjectPlanState, " constructableTypeIndex:", constructableTypeIndex, " buildObjectID:", buildObjectID)

                if buildObjectID then
                    local buildObject = serverGOM:getObjectWithID(buildObjectID)
                    if buildObject then

                        local objectInfoToAdd = serverGOM:stripObjectInfoForAdditionToInventory(objectInfo)
                        serverGOM:addConstructionObjectComponent(buildObject, objectInfoToAdd, tribeID)
                        
                        if deliverObjectPlanState.manualAssignedSapien == sapien.uniqueID then
                            planManager:assignSapienToPlan(tribeID, {
                                sapienID = sapien.uniqueID,
                                planObjectID = buildObjectID,
                                planTypeIndex = planTypeIndex,
                                researchTypeIndex = researchTypeIndex,
                            })
                        end
                    end
                end
            else
                mj:log("startPlanWithDeliveredPlanObject researchTypeIndex:", researchTypeIndex)
                planManager:addTerrainModificationPlan(tribeID, planTypeIndex, {vertID}, nil, researchTypeIndex, restrictedResourceObjectTypes, restrictedToolObjectTypes, deliverObjectPlanState.planOrderIndex, deliverObjectPlanState.priorityOffset, deliverObjectPlanState.manuallyPrioritized)

                local objectInfoToAdd = serverGOM:stripObjectInfoForAdditionToInventory(objectInfo)
                serverGOM:addConstructionObjectComponent(planObject, objectInfoToAdd, tribeID)
                
                if deliverObjectPlanState.manualAssignedSapien == sapien.uniqueID then
                    planManager:assignSapienToPlan(tribeID, {
                        sapienID = sapien.uniqueID,
                        planObjectID = planObject.uniqueID,
                        planTypeIndex = planTypeIndex,
                        researchTypeIndex = researchTypeIndex,
                    })
                end
            end

            
            return true
        end
    end

    return false
end

function serverTerrain:addCallbackForTerrainTypeChange(objectID, requiredTerrainBaseTypeIndexes, objectPos, func)
    for i, baseTypeIndex in ipairs(requiredTerrainBaseTypeIndexes) do
        local callbackInfos = baseTypeChangeCallbackInfosByTerrainTypeIndex[baseTypeIndex]
        if not callbackInfos then
            callbackInfos = {}
            baseTypeChangeCallbackInfosByTerrainTypeIndex[baseTypeIndex] = callbackInfos
        end

        callbackInfos[objectID] = {
            pos = objectPos,
            func = func,
        }

        if not baseTypeChangeTerrainTypesByObjectID[objectID] then
            baseTypeChangeTerrainTypesByObjectID[objectID] = {}
        end

        baseTypeChangeTerrainTypesByObjectID[objectID][baseTypeIndex] = true
    end
end

function serverTerrain:removeAllCallbacksForAvailabilityChange(objectID)
    if baseTypeChangeTerrainTypesByObjectID[objectID] then
        for baseTypeIndex, trueFalse in pairs(baseTypeChangeTerrainTypesByObjectID[objectID]) do
            local callbackInfos = baseTypeChangeCallbackInfosByTerrainTypeIndex[baseTypeIndex]
            if callbackInfos then
                callbackInfos[objectID] = nil
            end
        end
        baseTypeChangeTerrainTypesByObjectID[objectID] = nil
    end
end

function serverTerrain:setServerGOM(serverGOM_, planManager_)
    serverGOM = serverGOM_
    planManager = planManager_
end


return serverTerrain