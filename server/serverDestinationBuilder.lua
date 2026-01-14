local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
--local dot = mjm.dot
local cross = mjm.cross
local mat3Rotate = mjm.mat3Rotate
local length2 = mjm.length2
local length = mjm.length
local normalize = mjm.normalize
local mat3LookAtInverse = mjm.mat3LookAtInverse
local vec3xMat3 = mjm.vec3xMat3
local mat3Inverse = mjm.mat3Inverse
local mat3GetRow = mjm.mat3GetRow

local rng = mjrequire "common/randomNumberGenerator"
local constructable = mjrequire "common/constructable"
local buildable = mjrequire "common/buildable"
local plan = mjrequire "common/plan"
local gameObject = mjrequire "common/gameObject"
local evolvingObject = mjrequire "common/evolvingObject"
local sapienInventory = mjrequire "common/sapienInventory"
local physics = mjrequire "common/physics"
local physicsSets = mjrequire "common/physicsSets"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local resource = mjrequire "common/resource"
local worldHelper = mjrequire "common/worldHelper"
local flora = mjrequire "common/flora"
local pathBuildable = mjrequire "common/pathBuildable"

local terrain = mjrequire "server/serverTerrain"
local planManager = mjrequire "server/planManager"
local serverStorageArea = mjrequire "server/serverStorageArea"
local serverSapienInventory = mjrequire "server/serverSapienInventory"
local serverSapienSkills = mjrequire "server/serverSapienSkills"
local serverFlora = mjrequire "server/objects/serverFlora"
local serverCampfire = mjrequire "server/objects/serverCampfire"
local serverResourceManager = mjrequire "server/serverResourceManager"
local serverFuel = mjrequire "server/serverFuel"
local serverCraftArea = mjrequire "server/serverCraftArea"
local serverKiln = mjrequire "server/objects/serverKiln"

--local serverWorld = nil
local serverGOM = nil
local serverSapien = nil

local serverDestinationBuilder = {
    outputAssignmentTypes = { --in an ordered array here to ensure consistency
        "storageArea",
        "sapien",
        "output",
        "discard",
    },
}

local function testValidBuildingTransform(transform, constructableTypeIndex, ignoreCollisions)
    local constructableType = constructable.types[constructableTypeIndex]

    if constructableType.requiresSlopeCheck then
        local slopeOK = physics:doSlopeCheckForBuildModel(transform.pos, transform.rotation, 1.0, constructableType.modelIndex, physicsSets.attachable)
        if not slopeOK then
            --mj:log("slope fail:", transform)
            return false
        end
    end

    local minSeaLength2 = buildable.minSeaLevelPosLengthDefault2
    if constructableType.noBuildUnderWater then
        minSeaLength2 = buildable.minSeaLevelPosLengthNoUnderwater2
    end
    if length2(transform.pos) < minSeaLength2 then
        --mj:log("underwater fail")
        return false
    end

    if constructableType.requiredMediumTypes then

        local buildPosNormal = normalize(transform.pos)
        local rayTestStartPos = transform.pos + buildPosNormal * mj:mToP(0.1)
        local rayTestEndPos = rayTestStartPos - buildPosNormal * mj:mToP(0.2)

        local forwardRayTestResult = physics:rayTest(rayTestStartPos, rayTestEndPos, nil, nil)
        if not forwardRayTestResult.hasHitTerrain then
           -- mj:log("requiredMediumTypes hit terrain fail")
            return false
        end
    end

    if (not ignoreCollisions) then
        local useMeshForWorldObjects = false

        local physicsTestSet = nil
        local placeGameObjectType = gameObject.types[constructableType.finalGameObjectTypeKey]
        if not placeGameObjectType.disallowAnyCollisionsOnPlacement then
            physicsTestSet = physicsSets.disallowAnyCollisionsOnPlacement
        end

        local collidersTestResult = physics:modelTest(transform.pos, transform.rotation, 1.0, constructableType.modelIndex, "placeCollide", useMeshForWorldObjects, physicsTestSet, "placeCollide")
       -- mj:log("collidersTestResult:", collidersTestResult)
        if collidersTestResult.hasHitObject then
            --mj:log("collides with object fail")
            return false
        end
    end

    return true
end

local function getRandomPerpVecNormal(pointNormal, uniqueID, seed)
    local randomVecNormalized = normalize(rng:vecForUniqueID(uniqueID, seed))
    return normalize(cross(randomVecNormalized, pointNormal))
end


local function getNodeTransform(destinationState, node, randomSeed, parentInfo)
    local rotation = parentInfo.rotation
    local pos = parentInfo.pos

    if node.pos then
        pos = normalize(pos + vec3xMat3(mj:mToP(node.pos), mat3Inverse(rotation)))
    end


    if node.randomOffsetMinDistance then

        local minOffsetToUse = node.randomOffsetMinDistance
        local maxOffsetToUse = node.randomOffsetMaxDistance
        if parentInfo.increaseOffsetMultiplier then --used to start close, moving out with each
            local increase = (node.randomOffsetMaxDistance - node.randomOffsetMinDistance) * parentInfo.increaseOffsetMultiplier
            --mj:log("increase:", increase)
            minOffsetToUse = minOffsetToUse + increase
            maxOffsetToUse = maxOffsetToUse + increase
        end

        if node.randomOffsetUseRoadsideDistribution then
            local xVec = mat3GetRow(rotation, 0)
            local zVec = mat3GetRow(rotation, 2)
            if rng:integerForUniqueID(destinationState.destinationID, 739921 + randomSeed, 2) == 1 then
                xVec = -xVec
            end
            xVec = xVec * mj:mToP(minOffsetToUse + (maxOffsetToUse - minOffsetToUse) * rng:valueForUniqueID(destinationState.destinationID, 926 + randomSeed))
            zVec = zVec * mj:mToP((maxOffsetToUse - minOffsetToUse) * (rng:valueForUniqueID(destinationState.destinationID, 2313958 + randomSeed) - 0.5))
            pos = normalize(pos + xVec + zVec)
        elseif node.randomOffsetUseRoadEndDistribution then
            local zVec = mat3GetRow(rotation, 2)
            zVec = zVec * mj:mToP(minOffsetToUse + (maxOffsetToUse - minOffsetToUse) * rng:valueForUniqueID(destinationState.destinationID, 2313958 + randomSeed))
            pos = normalize(pos + zVec)
        else
            local randomVecPerpNormal = getRandomPerpVecNormal(pos, destinationState.destinationID, 6738 + randomSeed)
            local offset = mj:mToP(minOffsetToUse + (maxOffsetToUse - minOffsetToUse) * rng:valueForUniqueID(destinationState.destinationID, 926 + randomSeed))
            pos = normalize(pos + randomVecPerpNormal * offset)
        end
    end

    if node.rotationYSetRadialOffsetFromParant then
        local parentDirectionVec = parentInfo.pos - pos
        local parentDirectionVecLength = length(parentDirectionVec)
        if parentDirectionVecLength > mj:mToP(0.01) then
            rotation = mat3LookAtInverse(parentDirectionVec / parentDirectionVecLength, pos)
        end
    end

    if node.rotationYRandom then
        local randValue = rng:valueForUniqueID(destinationState.destinationID, 23680 + randomSeed)
        rotation = mat3Rotate(rotation, node.rotationYRandom * (randValue - 0.5), vec3(0.0,1.0,0.0))
    end


    if node.rotation then
        rotation = rotation * node.rotation
    end


    return {
        pos = pos,
        rotation = rotation,
    }
end

local function getConstructableTypeIndex(destinationState, node, seed)
    if node.constructableTypeWeights then

        local outputWeightCount = 0
        if not node.constructableTypeWeightSum then
            node.constructableTypeWeightSum = 0.0
            for k,outputWeight in pairs(node.constructableTypeWeights) do
                node.constructableTypeWeightSum = node.constructableTypeWeightSum + outputWeight
                outputWeightCount = outputWeightCount + 1
            end
            node.constructableTypeIndexWeightCount = outputWeightCount
        end

        local weightsToUse = node.constructableTypeWeights
        local sumToUse = node.constructableTypeWeightSum
        
        if node.constructableTypeMaxDifferentTypes then
            if not node.cache.constructableTypeWeightSum then --note this uses cache, so is unique per node instance
                local foundCount = 0
                local tryCount = 0
                local foundOutputWeights = {}
                local desiredCount = math.min(node.constructableTypeMaxDifferentTypes, node.constructableTypeIndexWeightCount)
                while foundCount < desiredCount and (tryCount < desiredCount * 2 or foundCount == 0) do
                    local randomObjectAssignmentFraction = rng:valueForUniqueID(destinationState.destinationID, 34784 + seed + tryCount) * sumToUse
                    local weightAccumulation = 0.0
                    local foundConstructableTypeKey = nil
                    for thisConstructableTypeKey,outputWeight in pairs(weightsToUse) do
                        foundConstructableTypeKey = thisConstructableTypeKey
                        weightAccumulation = weightAccumulation + outputWeight
                        if weightAccumulation > randomObjectAssignmentFraction then
                            break
                        end
                    end
                    if foundConstructableTypeKey then
                        if not foundOutputWeights[foundConstructableTypeKey] then
                            foundOutputWeights[foundConstructableTypeKey] = weightsToUse[foundConstructableTypeKey]
                            foundCount = foundCount + 1
                        end
                    end
                    tryCount = tryCount + 1
                end

                if next(foundOutputWeights) then
                    node.cache.constructableTypeWeights = foundOutputWeights
                    node.cache.constructableTypeWeightSum = 0.0
                    for k,outputWeight in pairs(foundOutputWeights) do
                        node.cache.constructableTypeWeightSum = node.cache.constructableTypeWeightSum + outputWeight
                    end
                end
            end

            if node.cache.constructableTypeWeights then
                weightsToUse = node.cache.constructableTypeWeights
                sumToUse = node.cache.constructableTypeWeightSum
            end
        end

        
        if sumToUse > 0.0 then
            local randomObjectAssignmentFraction = rng:valueForUniqueID(destinationState.destinationID, 43344 + seed) * sumToUse
    
            local weightAccumulation = 0.0
            local foundConstructableTypeKey = nil
            for thisConstructableTypeKey,outputWeight in pairs(weightsToUse) do
                foundConstructableTypeKey = thisConstructableTypeKey
                weightAccumulation = weightAccumulation + outputWeight
                if weightAccumulation > randomObjectAssignmentFraction then
                    break
                end
            end
            if foundConstructableTypeKey then
                local constructableType = constructable.types[foundConstructableTypeKey]
                if not constructableType then
                    mj:error("found invalid constructable type in constructableTypeWeights in constructable node:", node)
                    return nil
                end
                return constructableType.index
            end
        end
    end
    local constructableType = constructable.types[node.constructableType]
    if not constructableType then
        mj:error("no valid constructable type in constructable node:", node)
        return nil
    end
    return constructableType.index
end

local function levelTerrainIfNeeded(node, nodeTransform)
    if node.levelTerrainRadius then
        terrain:levelArea(nodeTransform.pos, mj:mToP(node.levelTerrainRadius))
    end
end

local function ensureClearRadiusIfNeeded(node, nodeTransform)
    local clearRadius = node.ensureClearRadius
    if (not clearRadius) and node.levelTerrainRadius then
        clearRadius = node.levelTerrainRadius + 2.0
    end

    if clearRadius then
        local objectInfos = serverGOM:getAllGameObjectsWithinRadiusOfNormalizedPos(nodeTransform.pos, mj:mToP(clearRadius))
        if objectInfos then
            local removeObjects = {}
            for i,objectInfo in ipairs(objectInfos) do
                local object = serverGOM:getObjectWithID(objectInfo.objectID)
                if object then
                    if serverGOM:objectCanBeRemovedHarmlessly(object) or gameObject.types[object.objectTypeIndex].resourceTypeIndex then
                        table.insert(removeObjects, objectInfo.objectID)
                    elseif object.objectTypeIndex ~= gameObject.types.terrainModificationProxy.index and (not gameObject.types[object.objectTypeIndex].isPathObject) then
                        --mj:log("clear radius fail due to object of type:", object.objectTypeIndex)
                        return false
                    end
                end
            end

            for i,objectID in ipairs(removeObjects) do
                serverGOM:removeGameObject(objectID)
            end
        end
    end
    return true
end

local minConstructableHeight2 = (1.0 - mj:mToP(0.1)) * (1.0 - mj:mToP(0.1))

local function loadConstructable(destinationState, node, seed, parentInfo, createdObjectIDsOrNil)
    --mj:log("loadConstructable:", node)
    local constructableTypeIndex = getConstructableTypeIndex(destinationState, node, seed + 9527444)

    --local buildingTransform = getLayoutTransform(destinationState, node, seed + 24396, parentInfo, constructableTypeIndex)

    local nodeTransform = getNodeTransform(destinationState, node, seed + 9243, parentInfo)

    if not ensureClearRadiusIfNeeded(node, nodeTransform) then
        return nil
    end

    levelTerrainIfNeeded(node, nodeTransform)

    local posAtCorrectHeight = terrain:getHighestDetailTerrainPointAtPoint(nodeTransform.pos)
    local posLength2 = length2(posAtCorrectHeight)

    if posLength2 < minConstructableHeight2 then
        return nil
    end

    if node.pos then
        posAtCorrectHeight = nodeTransform.pos * (length(posAtCorrectHeight) + mj:mToP(node.pos.y))
    end

    local constructableTransform = {
        pos = posAtCorrectHeight,
        rotation = nodeTransform.rotation,
    }

    if testValidBuildingTransform(constructableTransform, constructableTypeIndex, node.ignoreCollisions or false) then
        local tribeID = destinationState.destinationID
        local buildObjectID = planManager:addBuildOrPlantPlan(tribeID, 
            plan.types.build.index, 
            constructableTypeIndex,
            nil,
            constructableTransform.pos, 
            constructableTransform.rotation, 
            nil, 
            nil, 
            true,
            nil,
            nil,
            nil,
            true)

        if buildObjectID then
            local buildObject = serverGOM:getObjectWithID(buildObjectID)
            if buildObject then
                if constructable.types[constructableTypeIndex].buildSequence then
                    serverGOM:completeBuildImmediately(buildObject, constructable.types[constructableTypeIndex], nil, tribeID)
                end
                if createdObjectIDsOrNil then
                    table.insert(createdObjectIDsOrNil, buildObjectID)
                end

                if node.restrictContentsResourceType and gameObject.types[buildObject.objectTypeIndex].isStorageArea then

                    local resourceType = resource.types[node.restrictContentsResourceType]
                    if not resourceType then
                        mj:error("found invalid resource type in restrictContentsResourceType in constructable node:", node)
                    else
                        serverStorageArea:restrictStorageAreaConfig(tribeID, buildObject, resourceType.index, nil)
                    end
                end

                return {
                    success = true,
                    pos = nodeTransform.pos,
                    rotation = nodeTransform.rotation,
                    object = buildObject,
                }
            end
        end
    end
    return nil
end

local function loadPathConstructable(destinationState, fromPos, toPos, seed)

    local constructableTypeIndex = constructable.types.path_dirt.index
    local tribeID = destinationState.destinationID

    local pathVec = toPos - fromPos
    local pathVecLength2 = length2(pathVec)


    --pathBuildable.maxDistanceBetweenPathNodes
    local pathVecLength = math.sqrt(pathVecLength2)
    --mj:log("pathVecLength:", mj:pToM(pathVecLength))
    local pathNormal = pathVec / pathVecLength

    local pathRotation = mat3LookAtInverse(pathNormal, normalize(fromPos))

    local nodeCount = math.ceil((pathVecLength * 1.01) / pathBuildable.maxDistanceBetweenPathNodes) + 1
    nodeCount = math.max(nodeCount, 1)
    local distanceBetweenNodes = pathVecLength / (nodeCount - 1)

    --mj:log("nodeCount:", nodeCount)

    local lastPathPos = nil

    for i=1,nodeCount do
        local pathNodePos = nil
        if lastPathPos then
            local randomValue = rng:valueForUniqueID(destinationState.destinationID, seed + 28532 + i * 28)
            pathNodePos = lastPathPos + mat3GetRow(mat3Rotate(pathRotation, math.pi * 0.08 * (randomValue - 0.5), vec3(0.0,1.0,0.0)), 2) * distanceBetweenNodes
        else
            pathNodePos = fromPos
        end

        pathNodePos = terrain:getHighestDetailTerrainPointAtPoint(pathNodePos)

        local posLength2 = length2(pathNodePos)

        if posLength2 < minConstructableHeight2 then
            return nil
        end
        lastPathPos = pathNodePos

        local pathBuildObjectID = planManager:addBuildOrPlantPlan(tribeID, 
        plan.types.buildPath.index, 
        constructableTypeIndex,
        nil,
        pathNodePos, 
        pathRotation, 
        nil, 
        nil, 
        true,
        nil, --planInfo.decalBlockers,
        nil, --puserData.restrictedResourceObjectTypes,
        nil, --puserData.restrictedToolObjectTypes,
        nil) --puserData.noBuildOrder)

        if not pathBuildObjectID then
            return nil
        end

        local buildObject = serverGOM:getObjectWithID(pathBuildObjectID)
        if buildObject then
            if constructable.types[constructableTypeIndex].buildSequence then
                serverGOM:completeBuildImmediately(buildObject, constructable.types[constructableTypeIndex], nil, tribeID)
            end
        end

    end

    return lastPathPos
end

local assignOutputFunctionsByType = {
    storageArea = function(spawnPos, gameObjectTypeIndex, tribeID, sapienIDs)
        local matchInfo = serverStorageArea:bestStorageAreaForObjectType(tribeID, gameObjectTypeIndex, spawnPos, nil)
        if matchInfo then
            serverStorageArea:addObjectToStorageArea(matchInfo.object.uniqueID, {
                objectTypeIndex = gameObjectTypeIndex,
            }, tribeID)
            return true
        end
        return false
    end,
    sapien = function(spawnPos, gameObjectTypeIndex, tribeID, sapienIDs)
        if sapienIDs then
            for k, sapienID in ipairs(sapienIDs) do
                local sapien = serverGOM:getObjectWithID(sapienID)
                if sapien and sapienInventory:objectCount(sapien, sapienInventory.locations.held.index) == 0 then
                    local objectInfo = {
                        objectTypeIndex = gameObjectTypeIndex,
                    }
                    local objectOrderContext = nil
                    serverSapienInventory:addObjectFromInventory(sapien, objectInfo, sapienInventory.locations.held.index, objectOrderContext)

                    local clampToSeaLevel = true
                    local shiftedPos = worldHelper:getBelowSurfacePos(spawnPos, 1.0, physicsSets.walkable, nil, clampToSeaLevel)
                    serverGOM:setPos(sapien.uniqueID, shiftedPos, false)
                        
                    return true
                end
            end
        end
        return false
    end,
    output = function(spawnPos, gameObjectTypeIndex, tribeID, sapienIDs)
        serverGOM:createOutput(spawnPos, nil, gameObjectTypeIndex, nil, tribeID, nil, nil)
        return true
    end,
}

local function assignOutput(destinationState, sapienIDs, node, uniqueID, seed, outputPos, outputGameObjectTypeIndex, createdObjectIDsOrNil)
    local createdOutputs = false

    if not node.outputWeightSum then
        node.outputWeightSum = 0.0
        for k,outputKey in ipairs(serverDestinationBuilder.outputAssignmentTypes) do
            local outputWeight = node.outputAssignmentWeights[outputKey]
            if outputWeight then
                node.outputWeightSum = node.outputWeightSum + outputWeight
            end
        end
    end

    if node.outputWeightSum > 0.0 then
        local randomObjectAssignmentFraction = rng:valueForUniqueID(uniqueID, 43756 + seed) * node.outputWeightSum

        local weightAccumulation = 0.0
        local foundOutputKey = nil
        for k,outputKey in ipairs(serverDestinationBuilder.outputAssignmentTypes) do
            local outputWeight = node.outputAssignmentWeights[outputKey]
            if outputWeight then
                foundOutputKey = outputKey
                weightAccumulation = weightAccumulation + outputWeight
                if weightAccumulation > randomObjectAssignmentFraction then
                    break
                end
            end
        end

        if foundOutputKey then
            local assignOutputFunction = assignOutputFunctionsByType[foundOutputKey]
            if assignOutputFunction then
                if assignOutputFunction(outputPos, outputGameObjectTypeIndex, destinationState.destinationID, sapienIDs) then
                    createdOutputs = true
                end
            end
        end
    end
    return createdOutputs
end

local function clearVerts(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    --mj:log("clearVerts:", node)
    local clearRadiusMeters = node.clearRadiusMeters or 10.0
    if node.minClearRadius then
        clearRadiusMeters = node.minClearRadius + (node.maxClearRadius - node.minClearRadius) * rng:valueForUniqueID(destinationState.destinationID, seed + 92223)
    end
    local outputEvolveChance = node.outputEvolveChance or 0.8

    --local centerTransform = getLayoutTransform(destinationState, node, seed + 63959, parentInfo, nil)
    local nodeTransform = getNodeTransform(destinationState, node, seed + 63959, parentInfo)
    if not ensureClearRadiusIfNeeded(node, nodeTransform) then
        return nil
    end
    levelTerrainIfNeeded(node, nodeTransform)

    if nodeTransform then
        local baseVertID = terrain:getClosestVertIDToPos(nodeTransform.pos)
        --mj:log("baseVertID:", baseVertID)
        local nearVertIDs = terrain:getVertIDsWithinRadiusOfVertID(baseVertID, nodeTransform.pos, mj:mToP(clearRadiusMeters))

        local createdOutputs = false

        if nearVertIDs then
            --mj:log("got vert ids:", #nearVertIDs)
            for i,vertID in ipairs(nearVertIDs) do

                local outputs = terrain:outputsForClearAtVertex(vertID)
                --mj:log("outputs:", outputs)

                terrain:removeSnowForVertex(vertID)
                terrain:removeVegetationForVertex(vertID)

                if outputs then

                        local vert = terrain:getVertWithID(vertID)
                        for j,objectTypeKey in ipairs(outputs) do

                        -- mj:log("output:", objectTypeKey)
                            local gameObjectType = gameObject.types[objectTypeKey]

                            if rng:valueForUniqueID(vertID, seed + 38537 + j) < outputEvolveChance then
                                local toEvolution = evolvingObject.evolutions[gameObjectType.index]
                                if toEvolution and toEvolution.toType then
                                    gameObjectType = gameObject.types[toEvolution.toType]
                                end
                            end
                            
                            if gameObjectType then
                                --mj:log("final output:", gameObjectType.key)
                                createdOutputs = assignOutput(destinationState, sapienIDs, node, vertID, seed + j + 78783, vert.pos, gameObjectType.index)
                            end

                        end
                end
            end
        end

        if createdOutputs then
            return {
                success = true,
                pos = nodeTransform.pos,
                rotation = nodeTransform.rotation,
            }
        end
    end
    return nil
end

local function completeDiscovery(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)

    local researchTypeIndex = research.types[node.researchType].index
    if not researchTypeIndex then
        mj:error("no valid researchType in discovery node:", node)
        error()
    end

    local randomOffset = rng:integerForUniqueID(destinationState.destinationID, seed + 783255 + researchTypeIndex, #sapienIDs)
    local sapiensToGiveSkill = {}
    local maxAssignCount = 1
    if node.assignToSapiensFraction then
        maxAssignCount = math.ceil(node.assignToSapiensFraction * #sapienIDs)
        maxAssignCount = mjm.clamp(maxAssignCount, 1, #sapienIDs)
        --mj:log("completeDiscovery assignToSapiensFraction:", node.assignToSapiensFraction, " maxAssignCount:", maxAssignCount, " #sapienIDs:", #sapienIDs)
    end

    local assignedCount = 0
    for i=1,#sapienIDs do
        local sapienIndex = ((randomOffset + i) % #sapienIDs) + 1
        local sapienID = sapienIDs[sapienIndex]
        local sapien = serverGOM:getObjectWithID(sapienID)
        if sapien then
            local assignedRoleCount = skill:getAssignedRolesCount(sapien)
            if assignedRoleCount < skill.maxRoles then
                table.insert(sapiensToGiveSkill, sapien)
                assignedCount = assignedCount + 1
                if assignedCount >= maxAssignCount then
                    break
                end
            end
        end
    end

    local firstSapien = sapiensToGiveSkill[1]
    if firstSapien then
        serverSapienSkills:completeResearchImmediately(firstSapien, researchTypeIndex, node.discoveryCraftableTypeIndexToComplete)
        --mj:log("completeResearchImmediately:", firstSapien.uniqueID)

        for i=1,#sapiensToGiveSkill - 1 do
            local otherSapienIndex = i + 1
            local otherSapien = sapiensToGiveSkill[otherSapienIndex]

            local skillTypeIndex = research.types[researchTypeIndex].skillTypeIndex

            serverSapienSkills:completeSkill(otherSapien, skillTypeIndex)
            serverSapien:setSkillPriority(otherSapien, skillTypeIndex, 1)
            --mj:log("additional completeSkill:", otherSapien.uniqueID)
        end

        return {
            success = true,
            pos = firstSapien.pos,
            rotation = firstSapien.rotation,
        }
    end

    return nil
end

local function gatherResources(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)

    local gatherResourceTypeIndex = resource.types[node.gatherResourceType].index
    if not gatherResourceTypeIndex then
        mj:error("no valid resource type in gather node:", node)
        return nil
    end

    local nodeTransform = getNodeTransform(destinationState, node, seed + 9243, parentInfo)
    local centerPos = terrain:getHighestDetailTerrainPointAtPoint(nodeTransform.pos)

    local countToFind = node.gatherCount
    local minGatherCount = node.minGatherCount
    local maxGatherCount = node.maxGatherCount
    if node.maxGatherCountPerSapien and sapienIDs then
        minGatherCount = math.max(minGatherCount or 0, math.floor(node.minGatherCountPerSapien * #sapienIDs))
        maxGatherCount = math.min(maxGatherCount or 9999, math.floor(node.maxGatherCountPerSapien * #sapienIDs))
    end
    if maxGatherCount then
        countToFind = minGatherCount + rng:integerForUniqueID(destinationState.destinationID, seed + 834, maxGatherCount - minGatherCount)
    end

    local countRemainingToFind = countToFind

    local completionSuccessRequiredCount = 1
    if node.completionSuccessRequiredCount then
        completionSuccessRequiredCount = node.completionSuccessRequiredCount
    else
        completionSuccessRequiredCount = node.minGatherCount or node.gatherCount
    end


	local resourceObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[gatherResourceTypeIndex]

    local options = {
        maxCount = countRemainingToFind,
    }
    local nearestResources = serverResourceManager:distanceOrderedObjectsForResourceinTypesArray(resourceObjectTypes, centerPos, options, destinationState.destinationID)

    if nearestResources then
        for i,resourceInfo in ipairs(nearestResources) do
            countRemainingToFind = countRemainingToFind - 1
            assignOutput(destinationState, sapienIDs, node, destinationState.destinationID, seed + i + 275, resourceInfo.pos, resourceInfo.objectTypeIndex)
            if node.removeResourceFromSource then
                if resourceInfo.providerType == serverResourceManager.providerTypes.standard or resourceInfo.providerType == serverResourceManager.providerTypes.looseWithStorePlan then
                    serverGOM:removeGameObject(resourceInfo.objectID)
                elseif resourceInfo.providerType == serverResourceManager.providerTypes.storageArea then
                    serverStorageArea:removeObjectFromStorageArea(resourceInfo.objectID, resourceInfo.objectTypeIndex, nil)
                end
            end
        end
    end

    --mj:log("count remaining to find:", countRemainingToFind)
    if countRemainingToFind > 0 then
        local floraObjectTypes = flora.floraObjectTypesByGatherableResourceTypes[gatherResourceTypeIndex]
       -- mj:log("floraObjectTypes:", floraObjectTypes)
        if floraObjectTypes then
            local floraObjectIDs = serverGOM:getGameObjectsOfTypesWithinRadiusOfPos(floraObjectTypes, centerPos, mj:mToP(200.0))
            if floraObjectIDs then
                --mj:log("#floraObjectIDs:", #floraObjectIDs)
                for i, floraObjectID in ipairs(floraObjectIDs) do
                    local object = serverGOM:getObjectWithID(floraObjectID)
                    if object then
                        --mj:log("harvest inventory:", object.uniqueID)
                        local objectInfos = serverFlora:harvestInventoryAndReturnInfos(object)
                        for j,objectInfo in ipairs(objectInfos) do
                            if gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex == gatherResourceTypeIndex then
                                countRemainingToFind = countRemainingToFind - 1
                            end

                            --mj:log("assign output")
                            assignOutput(destinationState, sapienIDs, node, destinationState.destinationID, seed + i + 82745 + 99 * j, object.pos, objectInfo.objectTypeIndex)
                        end
                    end
                    if countRemainingToFind <= 0 then
                        break
                    end
                end
            end
        end
    end

    local totalFoundCount = countToFind - countRemainingToFind

    if totalFoundCount >= completionSuccessRequiredCount then
        --mj:log("gather success!")
        return {
            success = true,
            pos = nodeTransform.pos,
            rotation = nodeTransform.rotation,
        }
    end
    

    return nil
end

local function addFuel(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    local object = parentInfo.object
    if (not object) then
        mj:error("serverDestinationBuilder addFuel, requires parent constructable. parentInfo:", parentInfo)
        return {}
    end

    if object then
        local fuelObjectTypesArray = serverFuel:requiredFuelObjectTypesArrayForObject(object, destinationState.destinationID)
        local fuelResourceInfos = serverResourceManager:distanceOrderedObjectsForResourceinTypesArray(fuelObjectTypesArray, object.pos, {maxCount = 10, allowStockpiles = true}, destinationState.destinationID)
        
        for i,resourceInfo in ipairs(fuelResourceInfos) do
            for j=1,resourceInfo.count do
                if not serverFuel:addFuel(object, {objectTypeIndex = resourceInfo.objectTypeIndex}, destinationState.destinationID) then
                    return {
                        success = true,
                        object = object,
                        pos = object.pos,
                        rotation = object.rotation,
                    }
                end
            end
        end

        if fuelObjectTypesArray[1] then
            for j=1,8 do
                if not serverFuel:addFuel(object, {objectTypeIndex = fuelObjectTypesArray[1]}, destinationState.destinationID) then
                    return {
                        success = true,
                        object = object,
                        pos = object.pos,
                        rotation = object.rotation,
                    }
                end
            end
        end

        
    end

    return nil
end

local function lightObject(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    local object = parentInfo.object
    if (not object) then
        mj:error("serverDestinationBuilder lightCampfire, requires parent constructable. parentInfo:", parentInfo)
        return {}
    end

    if object.objectTypeIndex == gameObject.types.campfire.index then
        serverCampfire:setLit(object, true, destinationState.destinationID)
    elseif object.objectTypeIndex == gameObject.types.brickKiln.index then
        serverKiln:setLit(object, true, destinationState.destinationID)
    end
    return {
        success = true,
        object = object,
        pos = object.pos,
        rotation = object.rotation,
    }
end

--[[
local storageAreaSubNode = {
    type = "constructable",
    constructableTypeIndex = constructable.types.storageArea.index,
}

local storageNode = {
    type = "grid",
    randomOffsetMinDistance = 20.0,
    randomOffsetMaxDistance = 55.0,
    maxRetries = 10,
    
    gridWidth = 2,
    gridDepth = 2,
    gridCellSize = vec2(2.0,2.0),

    cellNode = storageAreaSubNode,

    completionSuccessRequiredCount = 1,
    completionNodes = {
        {
            type = "clearVerts",
            randomOffsetMinDistance = 0.0,
            randomOffsetMaxDistance = 2.0,

            minClearRadius = 6.0,
            maxClearRadius = 8.0,
            outputEvolveChance = 0.8,
            outputAssignmentWeights = {
                storageArea = 0.8,
                sapien = 0.1,
                output = 0.1,
            },
        },
    }
]]

--[[
local forestryPineScatterNode = {
    type = "group",
    subNode = forestryPineNode,
    minCount = 1,
    maxCount = 20,
}
]]

local function group(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    --mj:log("load group")
    local groupCenterTransform = getNodeTransform(destinationState, node, seed * 28742 + 94237, parentInfo)

    if not ensureClearRadiusIfNeeded(node, groupCenterTransform) then
        return nil
    end

    levelTerrainIfNeeded(node, groupCenterTransform)

    local completedCount = 0

    if node.subNodes then --array option
        for i,subNode in ipairs(node.subNodes) do
            local subModelParantInfo = {
                pos = groupCenterTransform.pos,
                rotation = groupCenterTransform.rotation,
            }

            if serverDestinationBuilder:loadNode(destinationState, sapienIDs, subNode, seed + i * 264, subModelParantInfo, createdObjectIDsOrNil) then
                completedCount = completedCount + 1
            end
        end
    else -- repeat single node option
        local spawnCount = node.count
        if node.minCount then
            spawnCount = node.minCount + rng:integerForUniqueID(destinationState.destinationID, seed + 83448, node.maxCount - node.minCount)
        end

        for cellIndex=1,spawnCount do
            local subModelParantInfo = {
                pos = groupCenterTransform.pos,
                rotation = groupCenterTransform.rotation,
            }
            if serverDestinationBuilder:loadNode(destinationState, sapienIDs, node.subNode, seed + cellIndex * 264, subModelParantInfo, createdObjectIDsOrNil) then
                completedCount = completedCount + 1
            end
        end
    end
    
    local success = (completedCount >= (node.completionSuccessRequiredCount or 1))
    return {
        pos = groupCenterTransform.pos,
        rotation = groupCenterTransform.rotation,
        success = success,
    }
end

local function resourceQuarry(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    --mj:log("resourceQuarry")
    local objectType = gameObject.types[node.fillObjectType]
    if not objectType then
        mj:error("found invalid object type in fillStorage node:", node)
        return nil
    end

    local transform = getNodeTransform(destinationState, node, seed * 2483 + 2327, parentInfo)

    local quarryRadius = mj:mToP(node.quarryRadius or 20.0)

    terrain:createResourceQuarry(transform.pos, quarryRadius, node.quarryDepth or 5.0, objectType.index)
    return {
        pos = transform.pos,
        rotation = transform.rotation,
        success = true,
    }
end

local function grid(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    local gridTransform = getNodeTransform(destinationState, node, seed * 28742 + 8924, parentInfo)

    if not ensureClearRadiusIfNeeded(node, gridTransform) then
        return nil
    end

    levelTerrainIfNeeded(node, gridTransform)

    if node.gridMinWidth then
        node.gridWidth = node.gridMinWidth + rng:integerForUniqueID(destinationState.destinationID, seed + 35643, node.gridMaxWidth - node.gridMinWidth)
        --mj:log("node.gridMinWidth:", node.gridMinWidth, " node.gridMaxWidth:", node.gridMaxWidth, " node.gridWidth:", node.gridWidth)
    end
    if node.gridMinDepth then
        node.gridDepth = node.gridMinDepth + rng:integerForUniqueID(destinationState.destinationID, seed + 63944, node.gridMaxDepth - node.gridMinDepth)
        --mj:log("node.gridMinDepth:", node.gridMinDepth, " node.gridMaxDepth:", node.gridMaxDepth, " node.gridDepth:", node.gridDepth)
    end

    local spawnCount = node.gridWidth * node.gridDepth

    local completedCount = 0
    for cellIndex=1,spawnCount do
        local xIndex = (cellIndex - 1) % node.gridWidth
        local zIndex = math.floor((cellIndex - 1) / node.gridWidth)
        local indexOffset = vec2((node.gridWidth - 1) * -0.5, (node.gridDepth - 1) * -0.5) + vec2(xIndex, zIndex)
        local localOffset = mj:mToP(vec2(node.gridCellSize.x * indexOffset.x, node.gridCellSize.y * indexOffset.y))

        local worldSpaceOffset = vec3xMat3(vec3(localOffset.x, 0.0, localOffset.y), mat3Inverse(gridTransform.rotation))

        local cellPos = normalize(gridTransform.pos + worldSpaceOffset)
        local cellInfo = {
            pos = cellPos,
            rotation = gridTransform.rotation,
        }
        if serverDestinationBuilder:loadNode(destinationState, sapienIDs, node.cellNode, seed + cellIndex * 967, cellInfo, createdObjectIDsOrNil) then
            completedCount = completedCount + 1
        end
    end


    local success = (completedCount >= (node.completionSuccessRequiredCount or 1))
    return {
        pos = gridTransform.pos,
        rotation = gridTransform.rotation,
        success = success,
    }
end

local function randomChoice(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    
    local randomChoices = node.randomChoices

    if not node.randomChoiceOutputWeightSum then
        node.randomChoiceOutputWeightSum = 0.0
        for i,choice in ipairs(randomChoices) do
            node.randomChoiceOutputWeightSum = node.randomChoiceOutputWeightSum + choice.weight
        end
    end

    local randomObjectAssignmentFraction = rng:valueForUniqueID(destinationState.destinationID, 93574 + seed) * node.randomChoiceOutputWeightSum

    local weightAccumulation = 0.0
    local chosen = nil
    for i,choice in ipairs(randomChoices) do
        chosen = choice
        weightAccumulation = weightAccumulation + choice.weight
        if weightAccumulation > randomObjectAssignmentFraction then
            break
        end
    end
    if chosen then
        for j, completionNode in ipairs(chosen.nodes) do
            local nodeTransform = getNodeTransform(destinationState, node, seed * 242 + 894, parentInfo)
            local subModelParantInfo = {
                pos = nodeTransform.pos,
                rotation = nodeTransform.rotation,
            }
            serverDestinationBuilder:loadNode(destinationState, sapienIDs, completionNode, seed + j * 99999, subModelParantInfo, createdObjectIDsOrNil)
        end
        return {
            success = true,
        }
    end

    return nil
end

local splitNodeCountMin = 4
local splitNodeCountMax = 6

local function radialPaths(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    local nodeTransform = getNodeTransform(destinationState, node, seed * 242 + 894, parentInfo)
    levelTerrainIfNeeded(node, nodeTransform)
   -- local centerPosNormal = nodeTransform.pos

    local availableDirectionInfos = {}
    local rotationMatrix = nodeTransform.rotation

    local enableCount = 3 + rng:integerForUniqueID(destinationState.destinationID, seed + 23511, 3)

    for i=1,6 do
        local rotatedMatrix = mat3Rotate(rotationMatrix, math.pi * 0.2 * (rng:valueForUniqueID(destinationState.destinationID, seed + i * 753 + 8870) - 0.5), vec3(0.0,1.0,0.0))
        local directionVector = mat3GetRow(rotatedMatrix, 2)
        --mj:log("directionVector:", directionVector)
        --mj:log("distance:", mj:pToM((mj:mToP(2.0) + mj:mToP(30.0) * rng:valueForUniqueID(destinationState.destinationID, seed + i * 28582 + 18837))))
        availableDirectionInfos[i] = {
            splitNodeCounter = 0,
            rotationMatrix = rotatedMatrix,
            pos = normalize(nodeTransform.pos + directionVector * (mj:mToP(4.0) + mj:mToP(10.0) * rng:valueForUniqueID(destinationState.destinationID, seed + i * 28582 + 18837))),
        }
        rotationMatrix = mat3Rotate(rotationMatrix, (math.pi * 2.0 / 6.0), vec3(0.0,1.0,0.0))
    end

    local enabledInfos = {}
    for i=1,enableCount do
        local randomIndex = rng:integerForUniqueID(destinationState.destinationID, seed + i * 35 + 723864, #availableDirectionInfos) + 1
        table.insert(enabledInfos, availableDirectionInfos[randomIndex])
        table.remove(availableDirectionInfos, randomIndex)
    end

    local subNodeIndex = 1
    local totalNodeCount = #node.nodes

    local prevEnabledInfoIndex = nil
    local success = true

    local subModelParantInfosBySubNodeIndex = {}
    
    for i=1,100 do
        local subNode = node.nodes[subNodeIndex]
        local loadNode = false
        local subModelParantInfo = {
            pos = nodeTransform.pos,
            rotation = nodeTransform.rotation,
        }

        if subNode.radialPathSkip then
            loadNode = true
        else
            local enabledInfoIndex = prevEnabledInfoIndex
            if (not subNode.radialPathFollowParent) or (not enabledInfoIndex) then
                enabledInfoIndex = rng:integerForUniqueID(destinationState.destinationID, seed + i * 2487 + 215, #enabledInfos) + 1
            end
            prevEnabledInfoIndex = enabledInfoIndex
            
            local directionInfo = enabledInfos[enabledInfoIndex]
            directionInfo.splitNodeCounter = directionInfo.splitNodeCounter + 1

            if directionInfo.splitNodeCounter > (splitNodeCountMin + rng:integerForUniqueID(destinationState.destinationID, seed + i * 6943 + 42, splitNodeCountMax - splitNodeCountMin)) then
                directionInfo.splitNodeCounter = 0
                local rotationAngleA = math.pi * (-0.3 * rng:valueForUniqueID(destinationState.destinationID, seed + i * 83 + 937))
                local rotationAngleB = rotationAngleA + math.pi * 0.3 + math.pi * 0.2 * rng:valueForUniqueID(destinationState.destinationID, seed + i * 733 + 24888)
                local rotationA = mat3Rotate(directionInfo.rotationMatrix, rotationAngleA, vec3(0.0,1.0,0.0))
                local rotationB = mat3Rotate(directionInfo.rotationMatrix, rotationAngleB, vec3(0.0,1.0,0.0))
                directionInfo.rotationMatrix = rotationA

                table.insert(availableDirectionInfos,{
                    splitNodeCounter = 0,
                    rotationMatrix = rotationB,
                    pos = directionInfo.pos,
                })
                enabledInfos[#enabledInfos] = availableDirectionInfos[#availableDirectionInfos]
            end


            local rotatedMatrix = mat3Rotate(directionInfo.rotationMatrix, math.pi * 0.2 * (rng:valueForUniqueID(destinationState.destinationID, seed + i * 224 + 4217) - 0.5), vec3(0.0,1.0,0.0))
            local directionVector = mat3GetRow(rotatedMatrix, 2)

            local radialPathDistanceMin = mj:mToP(subNode.radialPathDistanceMin or 4.0)
            local radialPathDistanceMax = mj:mToP(subNode.radialPathDistanceMax or 12.0)

            local offsetDistance = radialPathDistanceMin + (radialPathDistanceMax - radialPathDistanceMin) * rng:valueForUniqueID(destinationState.destinationID, seed + i * 28582 + 18837) + (directionInfo.offsetAccumulation or 0.0)
            local pathStartPos = directionInfo.pos
            local finalPos = nil
            if offsetDistance < pathBuildable.maxDistanceBetweenPathNodes * 2.0 then
                directionInfo.offsetAccumulation = (directionInfo.offsetAccumulation or 0.0) + offsetDistance
                finalPos = directionInfo.pos
            else
                pathStartPos = normalize(directionInfo.pos + directionVector * (pathBuildable.maxDistanceBetweenPathNodes - mj:mToP(0.1)))
                local pathEndPos = normalize(directionInfo.pos + directionVector * offsetDistance)
                finalPos = loadPathConstructable(destinationState, pathStartPos, pathEndPos, seed + i * 34 + 204)
                directionInfo.offsetAccumulation = nil
            end

            local function endPath()
                directionInfo.blocked = true
                prevEnabledInfoIndex = nil
                table.remove(enabledInfos, enabledInfoIndex)
            end

            if not finalPos then
                endPath()
                if not enabledInfos[1] then
                    success = false
                    break
                end
            else
                directionInfo.pos = normalize(finalPos)
                --mj:log("parentInfo:", parentInfo)
                local nodePos = nil
                if subNode.randomOffsetUseRoadEndDistribution then
                    nodePos = directionInfo.pos
                else
                    nodePos = normalize(pathStartPos + finalPos)
                end
                subModelParantInfo = {
                    pos = nodePos,
                    rotation = rotatedMatrix,
                }
                loadNode = true
                
                if subNode.randomOffsetUseRoadEndDistribution then
                    endPath()
                    if not enabledInfos[1] then
                        success = false
                        break
                    end
                end
            end



        end

        if loadNode then
            subModelParantInfosBySubNodeIndex[subNodeIndex] = subModelParantInfo
            subNodeIndex = subNodeIndex + 1
            if subNodeIndex > totalNodeCount then
                break
            end
        end
    end

    for i,subNode in ipairs(node.nodes) do
        local subModelParantInfo = subModelParantInfosBySubNodeIndex[i]
        if subModelParantInfo then
            serverDestinationBuilder:loadNode(destinationState, sapienIDs, subNode, seed + i * 99995, subModelParantInfo, createdObjectIDsOrNil)
        end
    end

    return {
        success = success,
        pos = nodeTransform.pos,
        rotation = nodeTransform.rotation,
    }
end

local function fillStorage(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)

    local object = parentInfo.object
    if (not object) then
        mj:error("serverDestinationBuilder fillStorage, requires parent constructable. parentInfo:", parentInfo)
        return nil
    end

    local objectType = gameObject.types[node.objectType]
    if not objectType then
        mj:error("found invalid object type in fillStorage node:", node)
        return nil
    end

    local objectAddedCount = 0

    if object and gameObject.types[object.objectTypeIndex].isStorageArea then
        local count = node.count

        local minCount = node.minCount
        local maxCount = node.maxCount
        if node.maxCountPerSapien and sapienIDs then
            minCount = math.max(minCount or 0, math.floor(node.minCountPerSapien * #sapienIDs))
            maxCount = math.min(maxCount or 9999, math.floor(node.maxCountPerSapien * #sapienIDs))
        end
        if maxCount then
            count = minCount + rng:integerForUniqueID(destinationState.destinationID, seed + 83448, maxCount - minCount)
        end

        for i=1,count do
            if serverStorageArea:addObjectToStorageArea(object.uniqueID, {objectTypeIndex = objectType.index}, destinationState.destinationID) then
                objectAddedCount = objectAddedCount + 1
            else
                break
            end
        end
    end

    local completionSuccessRequiredCount = 1
    if node.completionSuccessRequiredCount then
        completionSuccessRequiredCount = node.completionSuccessRequiredCount
    else
        completionSuccessRequiredCount = node.minCount or node.count
    end

    if objectAddedCount >= completionSuccessRequiredCount then
        return {
            success = true,
            object = object,
            pos = object.pos,
            rotation = object.rotation,
        }
    end

    return nil
end

local function loadCraftable(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    local constructableTypeIndex = getConstructableTypeIndex(destinationState, node, seed + 886864)
    local outputs = serverCraftArea:createCraftedObjectInfos(constructableTypeIndex, destinationState.destinationID)

    if outputs then

        local nodeTransform = getNodeTransform(destinationState, node, seed + 6215, parentInfo)
        local centerPos = terrain:getHighestDetailTerrainPointAtPoint(nodeTransform.pos)

        for i,objectInfo in ipairs(outputs) do
            assignOutput(destinationState, sapienIDs, node, destinationState.destinationID, seed + i + 827727, centerPos, objectInfo.objectTypeIndex)
        end

        return {
            success = true,
            pos = centerPos,
            rotation = nodeTransform.rotation,
        }
    end
    return nil
end

serverDestinationBuilder.loadFunctionsByNodeType = {
    constructable = function(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
        return loadConstructable(destinationState, node, seed, parentInfo, createdObjectIDsOrNil)
    end,

    flora = function(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
        local childInfo = loadConstructable(destinationState, node, seed, parentInfo, createdObjectIDsOrNil)
        if childInfo and childInfo.object then
            local object = childInfo.object
            local vertID = terrain:getClosestVertIDToPos(object.normalizedPos)
            local vert = terrain:getVertWithID(vertID)
            if vert then
                local baseType = vert.baseType
                local floraMedium = flora.mediumTypes[baseType]
                local floraMediumSoilQuality = flora.soilQualities.invalid
                if floraMedium then
                    floraMediumSoilQuality = floraMedium.soilQuality
                end

                if floraMediumSoilQuality == flora.soilQualities.invalid or floraMediumSoilQuality == flora.soilQualities.veryPoor then
                    terrain:changeVertexSurfaceFill(vertID, gameObject.types.poorDirt.index)
                end
            end

            serverFlora:growSaplingImmediately(object)
            serverFlora:refillInventory(object, object.sharedState, true, true)
            return {
                success = true,
                object = object,
                pos = object.pos,
                rotation = object.rotation,
            }
        end
        return nil
    end,

    discovery = function(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
        return completeDiscovery(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    end,

    grid = grid,
    group = group,
    craftable = loadCraftable,

    resourceQuarry = resourceQuarry,
    clearVerts = clearVerts,
    gatherResources = gatherResources,
    addFuel = addFuel,
    lightObject = lightObject,
    randomChoice = randomChoice,
    fillStorage = fillStorage,
    radialPaths = radialPaths,
}

function serverDestinationBuilder:loadNode(destinationState, sapienIDs, node, seed, parentInfo, createdObjectIDsOrNil)
    node.cache = {}
    local loadFunc = serverDestinationBuilder.loadFunctionsByNodeType[node.type]
    if not loadFunc then
        mj:error("no load function for serverDestinationBuilder node:", node)
        return false
    end

    local retryCount = node.maxRetries or 1
    local increaseOffsetMultiplier = nil

    for i=1,retryCount do
        if node.increaseRandomOffsetEachRetry then
            increaseOffsetMultiplier = (increaseOffsetMultiplier or 0.0) + 1.0
            parentInfo.increaseOffsetMultiplier = increaseOffsetMultiplier --it's a hack putting this in here
        else
            parentInfo.increaseOffsetMultiplier = nil
        end
        local childInfo = loadFunc(destinationState, sapienIDs, node, seed + 4297 + i * 247, parentInfo, createdObjectIDsOrNil)
        if childInfo and childInfo.success then
            if node.completionNodes then
                for k, completionNode in ipairs(node.completionNodes) do
                    serverDestinationBuilder:loadNode(destinationState, sapienIDs, completionNode, seed + k * 99, childInfo, createdObjectIDsOrNil)
                end
            end
            return true
        end
    end

    return false

    --[[if not serverDestinationBuilder.singleSpawnNodeTypes[node.type] then
        if node.layout == "grid" then
            if node.layoutGridMinWidth then
                node.layoutGridWidth = node.layoutGridMinWidth + rng:integerForUniqueID(destinationState.destinationID, seed + 35643, node.layoutGridMaxWidth - node.layoutGridMinWidth)
            end
            if node.layoutGridMinDepth then
                node.layoutGridDepth = node.layoutGridMinDepth + rng:integerForUniqueID(destinationState.destinationID, seed + 63944, node.layoutGridMaxDepth - node.layoutGridMinDepth)
            end
            spawnCount = node.layoutGridWidth * node.layoutGridDepth
        end
        if node.count then
            spawnCount = math.max(node.count, spawnCount)
        elseif node.minCount then
            spawnCount = node.minCount + rng:integerForUniqueID(destinationState.destinationID, seed + 2964, node.maxCount - node.minCount)
        end

        if node.maxCountPerSapien and sapienIDs then
            local minCount = math.max(node.minCount or 0, math.floor(node.minCountPerSapien * #sapienIDs))
            if minCount > 0 then
                local maxCount = math.min(node.maxCount or 9999, math.floor(node.maxCountPerSapien * #sapienIDs))
                if maxCount > minCount then
                    spawnCount = minCount + rng:integerForUniqueID(destinationState.destinationID, seed + 2964, maxCount - minCount)
                else
                    spawnCount = minCount
                end
            else
                return
            end
        end
    end]]
end

function serverDestinationBuilder:loadBlueprint(destinationState, sapienIDs, blueprint, createdObjectIDsOrNil)
    if blueprint.nodes then
        local randomVecPerpNormal = getRandomPerpVecNormal(destinationState.normalizedPos, destinationState.destinationID, 752)
        local rotation = mat3LookAtInverse(randomVecPerpNormal, destinationState.normalizedPos)
        local parentInfo = {
            pos = destinationState.normalizedPos,
            rotation = rotation,
        }

        for i, node in ipairs(blueprint.nodes) do
            serverDestinationBuilder:loadNode(destinationState, sapienIDs, node, i, parentInfo, createdObjectIDsOrNil)
        end
    end
end

function serverDestinationBuilder:init(serverWorld_, serverGOM_, serverSapien_)
    --serverWorld = serverWorld_
    serverGOM = serverGOM_
    serverSapien = serverSapien_
end

return serverDestinationBuilder