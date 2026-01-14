local worldConfig = mjrequire "common/worldConfig"

local serverWorldSettings = {}

function serverWorldSettings:set(key,value)
    worldConfig.configData[key] = value
    worldConfig:save()
end

function serverWorldSettings:get(key)
    return worldConfig.configData[key]
end


function serverWorldSettings:getAll()
    return worldConfig.configData
end

return serverWorldSettings