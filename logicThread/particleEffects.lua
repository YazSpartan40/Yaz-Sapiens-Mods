local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local normalize = mjm.normalize
local length = mjm.length
local length2 = mjm.length2
local mat3GetRow = mjm.mat3GetRow
local clamp = mjm.clamp
--local mix = mjm.mix

local physics = mjrequire "common/physics"
local physicsSets = mjrequire "common/physicsSets"

local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local terrain = mjrequire "logicThread/clientTerrain"
local logic = nil

local particleEffects = {}

local cloudsEmitterID = nil
local dustParticlesEmitterID = nil
local snowParticlesEmitterID = nil
local rainParticlesEmitterID = nil

local rainSoundAdded = false

local smoothedSnowFraction = nil


function particleEffects:setLogic(logic_)
    logic = logic_
end

local smoothedHeights = {}

local maxPlayerHeightToUpdateClouds = 1.0 + mj:mToP(10000)
local playerMoveDistanceToUpdateClouds = mj:mToP(100000)
local playerMoveDistanceToUpdateClouds2 = playerMoveDistanceToUpdateClouds * playerMoveDistanceToUpdateClouds
local lastCloudPlayerPos = nil

function particleEffects:snapCloudsToPlayerLocationIfNeeded(normalizedPlayerPos, rotationOrNil)
    if cloudsEmitterID and length2(lastCloudPlayerPos - normalizedPlayerPos) > playerMoveDistanceToUpdateClouds2 then
        --mj:log("re-creating clouds")
        lastCloudPlayerPos = normalizedPlayerPos
        particleManagerInterface:removeEmitter(cloudsEmitterID)
        cloudsEmitterID = particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.clouds, normalizedPlayerPos, rotationOrNil or mj:getNorthFacingFlatRotationForPoint(normalizedPlayerPos), nil, false)
    end
end

function particleEffects:update(playerPos, dt, speedMultiplier, rainSnow, snowFraction, windFraction_)

    local windFractionForEffects = mjm.clamp((windFraction_ - 0.25) / (1.0 - 0.25), 0.0, 1.0)
    windFractionForEffects = windFractionForEffects * windFractionForEffects

    local playerPosLength = length(playerPos)
    local normalizedPlayerPos = playerPos / playerPosLength
    local terrainPos = terrain:getHighestDetailTerrainPointAtPoint(normalizedPlayerPos)

    local snowFractionToUse = snowFraction

    if rainSnow > 0.0001 then
        if not smoothedSnowFraction then
            smoothedSnowFraction = snowFraction
        else
            local dtToUse = clamp(dt * speedMultiplier * 0.1, 0.0, 1.0)
            if snowFraction > smoothedSnowFraction then
                smoothedSnowFraction = smoothedSnowFraction + dtToUse
                if smoothedSnowFraction >= snowFraction then
                    smoothedSnowFraction = snowFraction
                end
            else
                smoothedSnowFraction = smoothedSnowFraction - dtToUse
                if smoothedSnowFraction <= snowFraction then
                    smoothedSnowFraction = snowFraction
                end
            end
            snowFractionToUse = smoothedSnowFraction
            --mj:log("snowFractionToUse:", snowFractionToUse)
        end
    else
        smoothedSnowFraction = nil
    end

    local snowAmount = rainSnow * snowFractionToUse
    local rainAmount = rainSnow * (1.0 - snowFractionToUse)

    local rotation = mj:getNorthFacingFlatRotationForPoint(normalizedPlayerPos)

    local dustFraction = (1.0 - rainSnow * 10.0)

    if not cloudsEmitterID then
        lastCloudPlayerPos = normalizedPlayerPos;
        cloudsEmitterID = particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.clouds, normalizedPlayerPos, rotation)
        
        dustParticlesEmitterID = particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.dustParticles, terrainPos, rotation, vec4(dustFraction, 0,0,0), false)
        snowParticlesEmitterID = particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.snow, playerPos, rotation, vec4(snowAmount, 0,0,0), false)
        rainParticlesEmitterID = particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.rain, playerPos, rotation, vec4(rainAmount, 0,0,0), false)
    else
        if playerPosLength < maxPlayerHeightToUpdateClouds then
            particleEffects:snapCloudsToPlayerLocationIfNeeded(normalizedPlayerPos, rotation)
        end

        particleManagerInterface:updateEmitter(dustParticlesEmitterID, terrainPos, rotation, vec4(dustFraction, 0,0,0), false)
        particleManagerInterface:updateEmitter(snowParticlesEmitterID, playerPos, rotation, vec4(snowAmount, 0,0,0), false)
        particleManagerInterface:updateEmitter(rainParticlesEmitterID, playerPos, rotation, vec4(rainAmount, 0,0,0), false)
    end

    if rainAmount > 0.001 or windFractionForEffects > 0.001 then

        local right = mat3GetRow(rotation, 0)
        local forward = mat3GetRow(rotation, 2)

        local emitterInfos = {}

        local emitterPositions = {
            playerPos + right * mj:mToP(2.0),
            playerPos - right * mj:mToP(2.0),
            playerPos + forward * mj:mToP(2.0),
            playerPos - forward * mj:mToP(2.0),
        }

        for i = 1,4 do
            local emitterPosition = emitterPositions[i]
            local emitterPositionNormal = normalize(emitterPosition)
            local obstructed = nil
            local heightAbovePlayer = nil
            
            local rayResult =  physics:rayTest(emitterPosition + (emitterPositionNormal * mj:mToP(100.0)), emitterPosition - (emitterPositionNormal * mj:mToP(100.0)), physicsSets.blocksRain, nil)
            ----disabled--mj:objectLog(sapien.uniqueID, " rayResult:", rayResult)
            if rayResult.hasHitObject then
                emitterPosition = rayResult.objectCollisionPoint
            elseif rayResult.hasHitTerrain then
                emitterPosition = rayResult.terrainCollisionPoint
            else
                emitterPosition = emitterPositionNormal
            end

            if emitterPosition then
                local incomingHeight = length(emitterPosition)
                if incomingHeight < 1.0 then
                    emitterPosition = emitterPosition / incomingHeight
                    incomingHeight = 1.0
                end
                local height = incomingHeight
                local prevHeight = smoothedHeights[i]
                if prevHeight then
                    height = prevHeight * 0.95 + incomingHeight * 0.05
                    emitterPosition = (emitterPosition / incomingHeight) * height
                end
                local obstructedRayResult =  physics:rayTest(playerPos, emitterPosition, physicsSets.pathColliders, nil)
                if obstructedRayResult.hasHitObject then
                    obstructed = true
                end
                heightAbovePlayer = height - playerPosLength
                smoothedHeights[i] = height
            else
                smoothedHeights[i] = nil
            end


            emitterInfos[i] = {
                heightAbovePlayer = heightAbovePlayer,
                obstructed = obstructed
            }
        end

        logic:callMainThreadFunction("updateAmbientSoundInfo", {
            rainAmount = rainAmount,
            windAmount = windFractionForEffects,
            emitterInfos = emitterInfos,
        })
        rainSoundAdded = true
    elseif rainSoundAdded then
        logic:callMainThreadFunction("updateAmbientSoundInfo", nil)
        rainSoundAdded = false
    end

end

return particleEffects