local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3xMat3 = mjm.vec3xMat3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate
local mat3Inverse = mjm.mat3Inverse
local normalize = mjm.normalize
--local mat3GetRow = mjm.mat3GetRow

local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local eventManager = mjrequire "mainThread/eventManager"

local pointAndClickCamera = {
    enabled = true,
    keyRotationVelocity = 0.0,
    keyForwardBackRotationVelocity = 0.0,
    yRotationOffset = 0.0,
    xRotationOffset = 0.0,
    panOffset = vec2(0.0,0.0),
    leftRightMovementAnalog = 0.0,
    forwardBackMovementAnalog = 0.0,

    keyRotationGoal = 0,
    keyForwardBackRotationGoal = 0,
}

local localPlayer = nil

local mouseDownCenter = nil
--local mouseDownMouseLoc = nil

local appHasFocus = true

function pointAndClickCamera:load(localPlayer_)
    localPlayer = localPlayer_

    pointAndClickCamera.enabled = clientGameSettings.values.pointAndClickCameraEnabled
    clientGameSettings:addObserver("pointAndClickCameraEnabled", function(newValue)
        pointAndClickCamera.enabled = newValue
    end)

    
    eventManager:addEventListenter(
        function(gainedFocus)
            appHasFocus = gainedFocus
        end, 
        eventManager.appFocusChangedListeners
    )
end

function pointAndClickCamera:toggleEnabled()
    pointAndClickCamera.enabled = (not pointAndClickCamera.enabled)
    clientGameSettings:changeSetting("pointAndClickCameraEnabled", pointAndClickCamera.enabled)
end

local rotateMouseDownNotMoved = false
local panMouseDownButNotMoved = false

function pointAndClickCamera:mouseDown(position, buttonIndex, modKey)
    if (not modKey) or (modKey == 0) then
        if buttonIndex == 1 then
            rotateMouseDownNotMoved = true
            --mj:log("pointAndClickCamera:mouseDown right")
            --[[pointAndClickCamera.rotateMouseDown = true
            mouseDownCenter = localPlayer:calculatePointAndClickRotationCenter()
            eventManager:preventMouseWarpUntilAfterNextShow()]]
        elseif buttonIndex == 2 then
            panMouseDownButNotMoved = true
            --[[pointAndClickCamera.panMouseDown = true
            eventManager:preventMouseWarpUntilAfterNextShow()]]
        end
    end
end

function pointAndClickCamera:mouseUp(position, buttonIndex, modKey)
    if buttonIndex == 1 then
        rotateMouseDownNotMoved = false
        if pointAndClickCamera.rotateMouseDown then
            pointAndClickCamera.rotateMouseDown = false
            pointAndClickCamera.xRotationOffset = 0
            pointAndClickCamera.yRotationOffset = 0
        end
    elseif buttonIndex == 2 then
        panMouseDownButNotMoved = false
        if pointAndClickCamera.panMouseDown then
            pointAndClickCamera.panMouseDown = false
            pointAndClickCamera.panOffset = vec2(0.0,0.0)
            pointAndClickCamera.leftRightMovementAnalog = 0.0
            pointAndClickCamera.forwardBackMovementAnalog = 0.0
        end
    end
end

function pointAndClickCamera:mouseMoved(pos, relativeMovement, dt)
    if rotateMouseDownNotMoved and (not pointAndClickCamera.rotateMouseDown) then
        pointAndClickCamera.rotateMouseDown = true
        mouseDownCenter = localPlayer:calculatePointAndClickRotationCenter()
        eventManager:preventMouseWarpUntilAfterNextShow()
        rotateMouseDownNotMoved = false
    end

    if panMouseDownButNotMoved and (not pointAndClickCamera.panMouseDown) then
        pointAndClickCamera.panMouseDown = true
        eventManager:preventMouseWarpUntilAfterNextShow()
        panMouseDownButNotMoved = false
    end


    if pointAndClickCamera.rotateMouseDown then
        local yRotationDiff = relativeMovement.x * 0.001
        if clientGameSettings.values.invertMouseLookX then
            yRotationDiff = -yRotationDiff
        end
        pointAndClickCamera.yRotationOffset = pointAndClickCamera.yRotationOffset + yRotationDiff

        local xRotationDiff = relativeMovement.y * 0.001
        if clientGameSettings.values.invertMouseLookY then
            xRotationDiff = -xRotationDiff
        end
        pointAndClickCamera.xRotationOffset = pointAndClickCamera.xRotationOffset + xRotationDiff
    end

    if pointAndClickCamera.panMouseDown then
        pointAndClickCamera.panOffset = pointAndClickCamera.panOffset + relativeMovement
    end
end

function pointAndClickCamera:shouldShowMouse()
    return pointAndClickCamera.enabled and (not pointAndClickCamera.rotateMouseDown) and (not pointAndClickCamera.panMouseDown)
end

function pointAndClickCamera:hasHiddenMouseForMoveControl()
    return pointAndClickCamera.enabled and (pointAndClickCamera.rotateMouseDown or pointAndClickCamera.panMouseDown)
end

function pointAndClickCamera:update(dt, camPos, camRotation)
    local result = {
        pos = camPos,
        rotation = camRotation,
    }


    if pointAndClickCamera.enabled then

        if (not appHasFocus) then
            pointAndClickCamera.leftMovement = false
            pointAndClickCamera.rightMovement = false
            pointAndClickCamera.forwardMovement = false
            pointAndClickCamera.backMovement = false
        elseif pointAndClickCamera.panMouseDown then
            local movementThreshold = 10.0
            local maxSpeedThreshold = 100.0

            pointAndClickCamera.leftRightMovementAnalog = 0.0
            if pointAndClickCamera.panOffset.x > movementThreshold then
                pointAndClickCamera.leftRightMovementAnalog = (pointAndClickCamera.panOffset.x - movementThreshold) / maxSpeedThreshold
            elseif pointAndClickCamera.panOffset.x < -movementThreshold then
                pointAndClickCamera.leftRightMovementAnalog = (pointAndClickCamera.panOffset.x + movementThreshold) / maxSpeedThreshold
            end

            pointAndClickCamera.forwardBackMovementAnalog = 0.0
            if pointAndClickCamera.panOffset.y > movementThreshold then
                pointAndClickCamera.forwardBackMovementAnalog = -(pointAndClickCamera.panOffset.y - movementThreshold) / maxSpeedThreshold
            elseif pointAndClickCamera.panOffset.y < -movementThreshold then
                pointAndClickCamera.forwardBackMovementAnalog = -(pointAndClickCamera.panOffset.y + movementThreshold) / maxSpeedThreshold
            end
        else

            local mouseFractions = eventManager:getMouseScreenFractionNonClamped()

            if mouseFractions.x < 0.001 then
                pointAndClickCamera.leftMovement = true
                pointAndClickCamera.rightMovement = false
            elseif mouseFractions.x > 0.999 then
                pointAndClickCamera.leftMovement = false
                pointAndClickCamera.rightMovement = true
            else
                pointAndClickCamera.leftMovement = false
                pointAndClickCamera.rightMovement = false
            end

            if mouseFractions.y < 0.001 then
                pointAndClickCamera.forwardMovement = true
                pointAndClickCamera.backMovement = false
            elseif mouseFractions.y > 0.999 then
                pointAndClickCamera.forwardMovement = false
                pointAndClickCamera.backMovement = true
            else
                pointAndClickCamera.forwardMovement = false
                pointAndClickCamera.backMovement = false
            end
        end

        localPlayer:updateMovementState()
    end
    

    if pointAndClickCamera.keyRotationActive then

        pointAndClickCamera.keyRotationVelocity = pointAndClickCamera.keyRotationVelocity + (pointAndClickCamera.keyRotationGoal - pointAndClickCamera.keyRotationVelocity) * mjm.clamp(dt * 10.0, 0.0, 1.0)
        pointAndClickCamera.keyForwardBackRotationVelocity = pointAndClickCamera.keyForwardBackRotationVelocity + (pointAndClickCamera.keyForwardBackRotationGoal - pointAndClickCamera.keyForwardBackRotationVelocity) * mjm.clamp(dt * 10.0, 0.0, 1.0)

        pointAndClickCamera.yRotationOffset = pointAndClickCamera.yRotationOffset + pointAndClickCamera.keyRotationVelocity * dt * 4.0
        pointAndClickCamera.xRotationOffset = pointAndClickCamera.xRotationOffset + pointAndClickCamera.keyForwardBackRotationVelocity * dt * 4.0

        if pointAndClickCamera.keyRotationGoal == 0 and math.abs(pointAndClickCamera.keyRotationVelocity) < 0.01 and pointAndClickCamera.keyForwardBackRotationGoal == 0 and math.abs(pointAndClickCamera.keyForwardBackRotationVelocity) < 0.01 then
            pointAndClickCamera.keyRotationVelocity = 0.0
            pointAndClickCamera.keyForwardBackRotationVelocity = 0.0
            pointAndClickCamera.keyRotationActive = false
            pointAndClickCamera.xRotationOffset = 0
            pointAndClickCamera.yRotationOffset = 0
        end
    end

    --[[

function localPlayer:updateMovementState()
    movementState.forward = (movementState.forwardKey or pointAndClickCamera.forwardMovement) 
    movementState.back = (movementState.backKey or pointAndClickCamera.backMovement)  
    movementState.left = (movementState.leftKey or pointAndClickCamera.leftMovement)  
    movementState.right = (movementState.rightKey or pointAndClickCamera.rightMovement)  
    ]]

   --[[ if pointAndClickCamera.yRotationOffset ~= 0.0 or pointAndClickCamera.xRotationOffset ~= 0.0 then
        local rotationCenter = mouseDownCenter
        local offsetPos = camPos - rotationCenter
        local rotationMatrix = mat3Rotate(mat3Identity, pointAndClickCamera.yRotationOffset, camPosNormal)
        rotationMatrix = mat3Rotate(rotationMatrix, pointAndClickCamera.xRotationOffset, mjm.cross(camPosNormal, normalize(offsetPos)))
        local rotatedOffsetPos = vec3xMat3(offsetPos, mat3Inverse(rotationMatrix))
        result.pos = rotationCenter + rotatedOffsetPos
        result.rotation = mjm.mat3LookAtInverse(normalize(result.pos - rotationCenter), normalize(result.pos))

        pointAndClickCamera.yRotationOffset = 0.0
        pointAndClickCamera.xRotationOffset = 0.0
    end]]

    if pointAndClickCamera.yRotationOffset ~= 0.0 or pointAndClickCamera.xRotationOffset ~= 0.0 then
        local camPosNormal = normalize(camPos)
        local verticalDot = mjm.dot(camPosNormal, mjm.mat3GetRow(result.rotation, 2))
        if (verticalDot > 0) ~= (pointAndClickCamera.xRotationOffset > 0) then
            local absDot = math.abs(verticalDot)
            local xRotationVerticalMultiplier = mjm.smoothStep(0.9, 0.8, absDot)
            pointAndClickCamera.xRotationOffset = pointAndClickCamera.xRotationOffset * xRotationVerticalMultiplier
        end

        local rotationCenter = mouseDownCenter
        local offsetPos = camPos - rotationCenter

        local clampedDt = mjm.clamp(dt * 10.0, 0.0, 1.0)
        local yAmountToAdd = pointAndClickCamera.yRotationOffset * clampedDt
        local xAmountToAdd = pointAndClickCamera.xRotationOffset * clampedDt

        local rotationMatrix = mat3Rotate(mat3Identity, yAmountToAdd, camPosNormal)
        rotationMatrix = mat3Rotate(rotationMatrix, xAmountToAdd, mjm.cross(camPosNormal, normalize(offsetPos)))
        local rotatedOffsetPos = vec3xMat3(offsetPos, mat3Inverse(rotationMatrix))
        result.pos = rotationCenter + rotatedOffsetPos
        result.rotation = mjm.mat3LookAtInverse(normalize(result.pos - rotationCenter), normalize(result.pos))

        pointAndClickCamera.yRotationOffset = pointAndClickCamera.yRotationOffset - yAmountToAdd
        pointAndClickCamera.xRotationOffset = pointAndClickCamera.xRotationOffset - xAmountToAdd
    end

    return result
end

function pointAndClickCamera:updateKeyRotation(direction)
    pointAndClickCamera.keyRotationGoal = direction
    if direction ~= 0 then
        if not pointAndClickCamera.keyRotationActive then
            mouseDownCenter = localPlayer:calculatePointAndClickRotationCenter()
            pointAndClickCamera.keyRotationActive = true
        end
    end
end


function pointAndClickCamera:updateKeyForwardBackRotation(direction)
    pointAndClickCamera.keyForwardBackRotationGoal = direction
    if direction ~= 0 then
        if not pointAndClickCamera.keyRotationActive then
            mouseDownCenter = localPlayer:calculatePointAndClickRotationCenter()
            pointAndClickCamera.keyRotationActive = true
        end
    end
end

function pointAndClickCamera:offsetRotationCenterForPlayerMovement(offset)
    mouseDownCenter = mouseDownCenter + offset
end

return pointAndClickCamera