local mjm = mjrequire "common/mjm"
local mjs = mjrequire "common/mjs"
local vec3 = mjm.vec3
local cross = mjm.cross
local mix = mjm.mix
local clamp = mjm.clamp
local mat3 = mjm.mat3
local mat3Slerp = mjm.mat3Slerp
local cardinalSplineInterpolate = mjm.cardinalSplineInterpolate
local normalize = mjm.normalize

local keyMapping = mjrequire "mainThread/keyMapping"
local cinematicCameraUI = mjrequire "mainThread/ui/cinematicCameraUI"

local localPlayer = nil
local world = nil

local cinematicCamera = {}

local defaultFrameDuration = 2.0
local overallSpeedMultiplier = 1.0

local recordingPathIndex = nil
local recordingFrameIndex = nil
local recordingFrameDuration = defaultFrameDuration

local playingPathIndex = nil
local playingFrameIndex = nil
local playTimer = 0.0
local paths = {}


local keyMap = {
    [keyMapping:getMappingIndex("cinematicCamera", "startRecord1")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:startRecord(1) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "startRecord2")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:startRecord(2) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "startRecord3")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:startRecord(3) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "startRecord4")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:startRecord(4) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "startRecord5")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:startRecord(5) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "play1")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:play(1) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "play2")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:play(2) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "play3")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:play(3) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "play4")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:play(4) end return true end,
    [keyMapping:getMappingIndex("cinematicCamera", "play5")] = function(isDown, isRepeat) if isDown and not isRepeat then cinematicCamera:play(5) end return true end,

    [keyMapping:getMappingIndex("game", "escape")] = function(isDown, isRepeat) if isDown and not isRepeat then return cinematicCamera:stop() end return false end,

    [keyMapping:getMappingIndex("cinematicCamera", "insertKeyframe")] = function(isDown, isRepeat) if isDown and not isRepeat then return cinematicCamera:insertKeyframe() end return false end,
    [keyMapping:getMappingIndex("cinematicCamera", "saveKeyframe")] = function(isDown, isRepeat) if isDown and not isRepeat then return cinematicCamera:saveKeyframe() end return false end,
    [keyMapping:getMappingIndex("cinematicCamera", "removeKeyframe")] = function(isDown, isRepeat) if isDown then return cinematicCamera:removeKeyframe() end return false end,
    [keyMapping:getMappingIndex("cinematicCamera", "nextKeyframe")] = function(isDown, isRepeat) if isDown then return cinematicCamera:nextKeyframe() end return false end,
    [keyMapping:getMappingIndex("cinematicCamera", "prevKeyframe")] = function(isDown, isRepeat) if isDown then return cinematicCamera:prevKeyframe() end return false end,
    [keyMapping:getMappingIndex("cinematicCamera", "increaseKeyframeDuration")] = function(isDown, isRepeat) if isDown then return cinematicCamera:increaseKeyframeDuration() end return false end,
    [keyMapping:getMappingIndex("cinematicCamera", "decreaseKeyframeDuration")] = function(isDown, isRepeat) if isDown then return cinematicCamera:decreaseKeyframeDuration() end return false end,
}

function cinematicCamera:keyChanged(isDown, mapIndexes, isRepeat)
    for i, mapIndex in ipairs(mapIndexes) do
        if keyMap[mapIndex]  then
            if keyMap[mapIndex](isDown, isRepeat) then
                return true
            end
        end
    end
    return false
end

function cinematicCamera:load(localPlayer_, world_)
    localPlayer = localPlayer_
    world = world_

    for i=0,9 do
        local fileName = string.format("cameraPaths/%d.lua", i)
        local filePath = world:getWorldSavePath(fileName)
        local fileContents = fileUtils.getFileContents(filePath)
        if fileContents and fileContents ~= "" then
            local unserialized = mjs.unserializeReadable(fileContents)
            if unserialized and type(unserialized) == "table" then
                paths[i] = unserialized
            end
        end
    end
end



local function saveToDisk(pathIndex)
    local path = paths[pathIndex]
    if path and path[1] then
        local serialized = mjs.serializeReadable(paths[pathIndex])
        local fileName = string.format("cameraPaths/%d.lua", pathIndex)
        local filePath = world:getWorldSavePath(fileName)
        fileUtils.createDirectoriesIfNeededForFilePath(filePath)
        fileUtils.writeToFile(filePath, serialized)
    end
end

function cinematicCamera:startRecord(pathIndex)
    if recordingPathIndex then
        cinematicCamera:stop()
    end

   -- mj:log("cinematicCamera:startRecord:", pathIndex)
    recordingPathIndex = pathIndex
    recordingFrameIndex = 1
    if playingFrameIndex and paths[recordingPathIndex] and paths[recordingPathIndex][playingFrameIndex] then
        recordingFrameIndex = playingFrameIndex
    end
    recordingFrameDuration = defaultFrameDuration
    --mj:log("recordingFrameDuration:", recordingFrameDuration)
    if not paths[recordingPathIndex] then
        paths[recordingPathIndex] = {}
    elseif paths[recordingPathIndex][recordingFrameIndex] then
        local firstFrame = paths[recordingPathIndex][recordingFrameIndex]
        --mj:log("firstFrame:", firstFrame)
        recordingFrameDuration = firstFrame.duration
        localPlayer:setCinematicTransform(firstFrame.pos, firstFrame.rotation)
    end
    
    cinematicCameraUI:show(recordingPathIndex, paths[recordingPathIndex], recordingFrameIndex, nil, recordingFrameDuration)
end

function cinematicCamera:saveKeyframe()
    if not recordingPathIndex then
        return false
    end

    local path = paths[recordingPathIndex]
    path[recordingFrameIndex] = {
        pos = localPlayer:getPos(),
        rotation = localPlayer:getRotation(),
        duration = recordingFrameDuration,
    }

    if recordingFrameIndex == #path then
        recordingFrameIndex = recordingFrameIndex + 1
        recordingFrameDuration = defaultFrameDuration
    end

    cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, "saved", recordingFrameDuration)
    saveToDisk(recordingPathIndex)

    return true
end


function cinematicCamera:increaseKeyframeDuration()
    if not recordingPathIndex then
        return false
    end
    recordingFrameDuration = recordingFrameDuration + 0.1
    cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, nil, recordingFrameDuration)
end

function cinematicCamera:decreaseKeyframeDuration()
    if not recordingPathIndex then
        return false
    end
    recordingFrameDuration = math.max(recordingFrameDuration - 0.1, 0.1)
    cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, nil, recordingFrameDuration)
end

function cinematicCamera:insertKeyframe()
    if not recordingPathIndex then
        return false
    end

    local path = paths[recordingPathIndex]
    table.insert(path, recordingFrameIndex + 1, {
        pos = localPlayer:getPos(),
        rotation = localPlayer:getRotation(),
        duration = defaultFrameDuration,
    })
    recordingFrameIndex = recordingFrameIndex + 1
    recordingFrameDuration = defaultFrameDuration
    cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, string.format("key frame added at:%d", recordingFrameIndex), recordingFrameDuration)
    saveToDisk(recordingPathIndex)
   
    return true
end

function cinematicCamera:removeKeyframe()
    if not recordingPathIndex then
        return false
    end
    
    local path = paths[recordingPathIndex]
    if path[recordingFrameIndex] then
        table.remove(path, recordingFrameIndex)
        if path[recordingFrameIndex] then
            local frame = path[recordingFrameIndex]
            localPlayer:setCinematicTransform(frame.pos, frame.rotation)
        end
        cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, string.format("key frame removed at:%d", recordingFrameIndex), recordingFrameDuration)
        saveToDisk(recordingPathIndex)
    end

    return true
end

function cinematicCamera:nextKeyframe()
    --mj:log("nextKeyframe")
    if not recordingPathIndex then
        return false
    end
    
    local path = paths[recordingPathIndex]
    if recordingFrameIndex <= #path then
        recordingFrameIndex = recordingFrameIndex + 1
        recordingFrameDuration = defaultFrameDuration
        if path[recordingFrameIndex] then
            local frame = path[recordingFrameIndex]
            localPlayer:setCinematicTransform(frame.pos, frame.rotation)
            recordingFrameDuration = frame.duration
        end
        cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, nil, recordingFrameDuration)
    end
    
    return true
end

function cinematicCamera:prevKeyframe()
    if not recordingPathIndex then
        return false
    end

    local path = paths[recordingPathIndex]
    if recordingFrameIndex > 1 then
        recordingFrameIndex = recordingFrameIndex - 1
        recordingFrameDuration = defaultFrameDuration
        if path[recordingFrameIndex] then
            local frame = path[recordingFrameIndex]
            localPlayer:setCinematicTransform(frame.pos, frame.rotation)
            recordingFrameDuration = frame.duration
        end
        cinematicCameraUI:update(paths[recordingPathIndex], recordingFrameIndex, nil, recordingFrameDuration)
    end

    return true
end

function cinematicCamera:play(pathIndex)
    if paths[pathIndex] and paths[pathIndex][1] then
        playingPathIndex = pathIndex
        playingFrameIndex = 1
        if recordingPathIndex == pathIndex then
            playingFrameIndex = math.max(recordingFrameIndex - 1, 1)
            recordingPathIndex = nil
            cinematicCameraUI:hide()
        end
        local keyframe = paths[pathIndex][playingFrameIndex]
        playTimer = 0.0
        localPlayer:setCinematicTransform(keyframe.pos, keyframe.rotation)
        return true
    end
    mj:warn("No recorded path at index:", pathIndex)
    return false
end

function cinematicCamera:stop()
    if recordingPathIndex then
        saveToDisk(recordingPathIndex)
        recordingPathIndex = nil
        cinematicCameraUI:hide()
        return true
    end
    if playingPathIndex then
        playingPathIndex = nil
        return true
    end
    return false
end

local function smoothSlerpySlerpSmoothie(qAA, qA, qB, qBB, f)
	local slerpB = mat3Slerp(qB,qBB,mjm.smoothStep(0.0, 1.0, f * 0.5))
	local slerpA = mat3Slerp(qA,qB,mjm.smoothStep(0.0, 1.0, 0.5 + f * 0.5))
	return mat3Slerp(slerpA,slerpB,f)
end

local function getSpeed(path)
    local frames = {
        path[playingFrameIndex],
        path[playingFrameIndex + 1] or path[playingFrameIndex],
    }

    local durations = {}
    for i=1,2 do
        if frames[i] then
            durations[i] = frames[i].duration
        else
            durations[i] = defaultFrameDuration
        end
    end

    return mix(1.0 / durations[1], 1.0 / durations[2], clamp(playTimer, 0.0, 1.0)) * overallSpeedMultiplier

end

local zoomOutOnLastFrame = false

function cinematicCamera:update(dt)
    if playingPathIndex then
        local path = paths[playingPathIndex]
        local currentFrame = path[playingFrameIndex]

        local speed = getSpeed(path)

        local worldSpeedMultiplier = world:getSpeedMultiplier()
        if worldSpeedMultiplier > 0.0001 and worldSpeedMultiplier < 1.0 then
            speed = speed * worldSpeedMultiplier
        end
        
        playTimer = playTimer + dt * speed

        if playTimer >= 1.0 then
            if (not zoomOutOnLastFrame) or playingFrameIndex < #path then
                if not currentFrame then
                    local finalFrame = path[#path]
                    localPlayer:setCinematicTransform(finalFrame.pos, finalFrame.rotation)
                    playingPathIndex = nil
                    return true
                end
                playTimer = playTimer - 1.0
                playingFrameIndex = playingFrameIndex + 1
                local nextFrame = path[playingFrameIndex]
                if nextFrame and playTimer >= nextFrame.duration then
                    playTimer = 0.0
                end
                currentFrame = nextFrame
            end
        end

        if not currentFrame then
            currentFrame = path[playingFrameIndex - 1]
        end
        
        if not currentFrame then
            playingPathIndex = nil
            return false
        end

        local prevFrame = path[playingFrameIndex - 1] or currentFrame
        local nextFrame = path[playingFrameIndex + 1] or currentFrame
        local prevPrevFrame = path[playingFrameIndex - 2] or prevFrame

        local aa = prevPrevFrame.pos
        local a = prevFrame.pos
        local b = currentFrame.pos
        local bb = nextFrame.pos

        local qaa = prevPrevFrame.rotation
        local qa = prevFrame.rotation
        local qb = currentFrame.rotation
        local qbb = nextFrame.rotation

        local fraction = playTimer
        local clampedFraction = math.min(playTimer, 1.0)

        local lerpedPos = cardinalSplineInterpolate(aa, a, b, bb, clampedFraction, 0.5)

        if zoomOutOnLastFrame then
            if playingFrameIndex >= #path - 1 then

                local lerpedPosNormal = normalize(lerpedPos)
                local right = normalize(cross(lerpedPosNormal, vec3(0.0,-1.0,0.0)))
                local upVec = normalize(cross(lerpedPosNormal, right))

                local mapModeRotation = mat3(
                    right.x,right.y,right.z,
                    upVec.x, upVec.y, upVec.z,
                    lerpedPosNormal.x,lerpedPosNormal.y,lerpedPosNormal.z
                )

                qbb = mapModeRotation
                if playingFrameIndex == #path then
                    qb = mapModeRotation
                end
            end
        end

        local lerpedRotation = smoothSlerpySlerpSmoothie(qaa, qa, qb, qbb, clampedFraction)

        if zoomOutOnLastFrame and playingFrameIndex == #path then
            local zoomTime = 4.0
            local zoomFraction = fraction / zoomTime
            zoomFraction = math.pow(zoomFraction, 5.0)
            local lerpedPosNormal = normalize(lerpedPos)
            lerpedPos = mjm.mix(lerpedPos, lerpedPosNormal * (1.0 + mj:mToP(8000000.0)), zoomFraction)
        end



        localPlayer:setCinematicTransform(lerpedPos, lerpedRotation)

        return true
    end
    return false
end

return cinematicCamera