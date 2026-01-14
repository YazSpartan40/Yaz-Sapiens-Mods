local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local createUpAlignedRotationMatrix = mjm.createUpAlignedRotationMatrix
local normalize = mjm.normalize

local particleManagerInterface = mjrequire "logicThread/particleManagerInterface"
local logic = nil

local playerAvatars = {
    avatarsByClient = {}
}

function playerAvatars:addAvatar(clientID,publicData)
    local info = {}
    local posNormal = normalize(publicData.pos)
    local rotation = createUpAlignedRotationMatrix(posNormal, publicData.dir)
    info.emitterID = particleManagerInterface:addEmitter(particleManagerInterface.emitterTypes.playerAvatarDefault, publicData.pos, rotation, nil, false)
    info.goalPos = publicData.pos
    info.pos = info.goalPos

    playerAvatars.avatarsByClient[clientID] = info

    
    logic:callMainThreadFunction("addLight", {
        pos = info.goalPos, 
        color = vec3(4.0,1.0,0.1) * 1.0,
        priority = 2, --todo should use a constant
    }, function(lightID)
        if playerAvatars.avatarsByClient[clientID] then
            playerAvatars.avatarsByClient[clientID].lightID = lightID
        else
            logic:callMainThreadFunction("removeLight", lightID)
        end
    end)

    mj:log("added avatar:", particleManagerInterface.emitterTypes.playerAvatarDefault)
end

function playerAvatars:updateAvatar(clientID,info,publicData)
    local posNormal = normalize(publicData.pos)
    local rotation = createUpAlignedRotationMatrix(posNormal, publicData.dir)
    info.goalPos = publicData.pos
    local lightID = playerAvatars.avatarsByClient[clientID].lightID
    if lightID then
        logic:callMainThreadFunction("updateLight", {
            lightID = lightID,
            pos = info.goalPos, 
            color = vec3(4.0,1.0,0.1) * 1.0,
            priority = 2, --todo should use a constant
        })
    end

    particleManagerInterface:updateEmitter(info.emitterID, info.pos, rotation, nil, false)
end

function playerAvatars:update(dt)
    for clientID, info in pairs(playerAvatars.avatarsByClient) do
        info.pos = info.pos + (info.goalPos - info.pos) * dt
    end
end

function playerAvatars:removeAvatar(clientID, info)
    local lightID = playerAvatars.avatarsByClient[clientID].lightID
    if lightID then
        logic:callMainThreadFunction("removeLight", lightID)
    end

    particleManagerInterface:removeEmitter(info.emitterID)
    playerAvatars.avatarsByClient[clientID] = nil
end

function playerAvatars:otherClientDataUpdate(otherClientData)
    local avatarsByClient = playerAvatars.avatarsByClient

    if otherClientData then
        for clientID,publicData in pairs(otherClientData) do
            local info = avatarsByClient[clientID]
            if not info then
                playerAvatars:addAvatar(clientID,publicData)
            else
                playerAvatars:updateAvatar(clientID,info,publicData)
            end
        end
    end

    for clientID,info in pairs(avatarsByClient) do
        if not (otherClientData and otherClientData[clientID]) then
            playerAvatars:removeAvatar(clientID, info)
        end
    end

end

function playerAvatars:init(logic_)
    logic = logic_
end

return playerAvatars