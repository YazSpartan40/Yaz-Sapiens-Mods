local mjs = mjrequire "common/mjs"
local gameConstants = mjrequire "common/gameConstants"

local worldConfig = {}

-- NOTE!!! The comment below applies for the generated file, not this file. Don't change anything here, this is not a config file. The output config file location is config.lua in each world's directory.
local headerComments = [[-- This lua file configures settings for each world.
-- To "whitelist" this world, so only those listed can connect, modify this file, adding the steam ids of players who will be allowed to connect: allowList = {"7656119XXXXXXXXXX","7656119XXXXXXXXXX"}
-- Some values here can also optionally be supplied as arguments when starting the dedicated server. In that case, any args passed on launch will override, but not replace the values set here.
-- However ban/allow/mod/admin lists can (in the future, maybe not implemented yet!) all be modified by server commands, so be aware this config file can get modified by the game, but it will do its best to preserve any of your changes.

-- PLEASE NOTE! Any line that begins with '--' like this one are ignored. To change a setting, you must delete the two '-' characters from the start of the line, otherwise it will be ignored and overwritten with the default.
]]

local defaultDayLength = 1440.0 * 2 --1440.0 = 24mins

local configPath = nil
local appliedToGameConstants = false
local overriddenValues = {}

worldConfig.defaults = { --watch out that you don't accidentally use the same key as in gameConstants.lua, as they are merged here
    globalTimeZone = false,
    dayLength = defaultDayLength,
    yearLength = defaultDayLength * 8.0,
    worldName = "World",

    disableTribeSpawns = false,

    welcomeMessage = "Welcome",
    advertiseName = "",
    enableCheats = false,
    maxPlayers = 16,
    banList = {}, 
    allowList = {},
    modList = {},
    adminList = {},
    enabledMods = {},
}

local comments = {
    welcomeMessage = "Displayed when players connect",
    advertiseName = "This name is displayed on the public server list in the game client if this is a dedicacted server that has been started with the --advertise option. Max 64 chars.",
}

local commentedOutDefaults = {
    --advertiseName = true
}

function worldConfig:reset()
    overriddenValues = {}
    worldConfig.configData = nil
end

function worldConfig:loadDefaults()
    if appliedToGameConstants then
        mj:error("attempt to call loadDefaults after gameConstants have been set")
        return
    end
    worldConfig.configData = {}
    for k,v in pairs(worldConfig.defaults) do
        worldConfig.configData[k] = v
    end
    for k,comment in pairs(gameConstants.showInConfigFileKeys) do
        worldConfig.configData[k] = gameConstants[k]
    end

   -- mj:log("loaded defaults:", worldConfig)
end

function worldConfig:save()
    if not worldConfig.configData then
        mj:error("save called in worldConfig but worldConfig has not been initialized")
        error()
    end

    local commentOutKeys = {}
    local commentsByKey = {}

    for k,v in pairs(commentedOutDefaults) do
        commentOutKeys[k] = true
    end
    for k,v in pairs(comments) do
        commentsByKey[k] = v
    end

    for k,v in pairs(gameConstants.showInConfigFileKeys) do
        if overriddenValues[k] == nil then
            commentOutKeys[k] = true
        end
        commentsByKey[k] = v
    end
    
    local serialized = mjs.serializeReadable(worldConfig.configData, true, commentsByKey, commentOutKeys)
    --mj:log("worldConfig:save serialized:", serialized, " worldConfig.configData:", worldConfig.configData)
    local withComments = headerComments .. serialized
    fileUtils.createDirectoriesIfNeededForFilePath(configPath)
    fileUtils.writeToFile(configPath, withComments)
end

function worldConfig:init(configPath_)
    worldConfig:reset()
    configPath = configPath_
    worldConfig:loadDefaults()

    local fileContents = fileUtils.getFileContents(configPath)
    if fileContents and fileContents ~= "" then
        local configData = mjs.unserializeReadable(fileContents)
        for k,v in pairs(configData) do
            worldConfig.configData[k] = v
            overriddenValues[k] = v
        end
    else
        mj:warn("failed to find world config data at path:", configPath)
        return nil
    end
    worldConfig:save()
    return worldConfig.configData
end

function worldConfig:applyToGameConstants()
    if overriddenValues then
        appliedToGameConstants = true
        for k,v in pairs(overriddenValues) do
            if gameConstants[k] ~= nil then
                gameConstants[k] = v
            end
        end
    end
end

function worldConfig:initForWorldCreation(configPath_, worldName, enabledMods)
    --mj:log("worldConfig:initForWorldCreation:", enabledMods)
    worldConfig:reset()
    configPath = configPath_
    worldConfig:loadDefaults()

    worldConfig.configData.worldName = worldName or "World"
    worldConfig.configData.enabledMods = enabledMods
    if enabledMods then
        overriddenValues.enabledMods = true
    end
    overriddenValues.worldName = true

    worldConfig:save()

    return worldConfig.configData
end

function worldConfig:initWithLegacyData(configPath_, worldName, enabledMods, globalTimeZone, dayLength, yearLength)
    worldConfig:reset()
    --mj:log("initWithLegacyData worldName:", worldName, " enabledMods:", enabledMods)
    configPath = configPath_
    worldConfig:loadDefaults()

    worldConfig.configData.worldName = worldName
    worldConfig.configData.enabledMods = enabledMods
    worldConfig.configData.globalTimeZone = globalTimeZone
    worldConfig.configData.dayLength = dayLength
    worldConfig.configData.yearLength = yearLength

    if enabledMods then
        overriddenValues.enabledMods = true
    end
    overriddenValues.worldName = true
    overriddenValues.dayLength = true
    overriddenValues.yearLength = true

    worldConfig:save()

    return worldConfig.configData
end

function worldConfig:getData()
    return worldConfig.configData
end


function worldConfig:setModEnabled(modDir, newEnabled)
    if not worldConfig.configData then
        mj:error("configData is nil in worldConfig:setModEnabled. init must be called first.")
        error()
    end

    if newEnabled then
        local enabledMods = worldConfig.configData.enabledMods
        if not enabledMods then
            enabledMods = {}
            worldConfig.configData.enabledMods = enabledMods
            overriddenValues.enabledMods = true
        end
        local found = false
        for i,existing in ipairs(enabledMods) do
            if existing == modDir then
                found = true
                break
            end
        end
        if not found then
            table.insert(enabledMods, modDir)
            worldConfig:save()
        end
    else
        for i,existing in ipairs(worldConfig.configData.enabledMods) do
            if existing == modDir then
                table.remove(worldConfig.configData.enabledMods, i)
                worldConfig:save()
                break
            end
        end
    end
end

function worldConfig:getClientGameConstantsConfig() --sent to clients to override gameConstants values client-side
    local clientGameConstantsConfig = {}
    for k,v in pairs(gameConstants.showInConfigFileKeys) do
        clientGameConstantsConfig[k] = overriddenValues[k]
    end
   --mj:log("clientGameConstantsConfig:", clientGameConstantsConfig)
    return clientGameConstantsConfig
end

return worldConfig