

local modUtility = {}

function modUtility:getModInfos(dirPath)--used by client to find installed world mods
    local result = {}
    local modDirNames = fileUtils.getDirectoryContents(dirPath)
    for i, modDirName in ipairs(modDirNames) do
        local modDirPath = dirPath .. "/" .. modDirName
        local modInfoPath = modDirPath .. "/modInfo.lua"

        local fileContents = fileUtils.getFileContents(modInfoPath)
        if fileContents and fileContents ~= "" then
            local modInfoFile, loadError = loadstring(fileContents)
            if not modInfoFile then
                mj:error("Failed to load mod info file at path:", modInfoPath, "\nerror:", loadError)
            else
                local function errorhandler(err)
                    mj:error("ERROR in mod info:", modInfoPath, "\n", err)
                end

                local ok, infoTable = xpcall(modInfoFile, errorhandler)
                if ok and infoTable then
                    table.insert(result, {
                        name = modDirName,
                        info = infoTable,
                    })
                end
            end
        else
            mj:error("Failed to load mod info file at path:", modInfoPath)
        end
    end
    return result
end


function modUtility:getWorldModVersion(worldModPath)
    --mj:log("worldModPath:", worldModPath)
    
    local modInfoPath = worldModPath .. "/modInfo.lua"

    local fileContents = fileUtils.getFileContents(modInfoPath)

    if fileContents and fileContents ~= "" then
        local modInfoFile = loadstring(fileContents)
        if modInfoFile then
            local function errorhandler(err)
                mj:error("ERROR in mod info:", modInfoPath, "\n", err)
            end
            local ok, infoTable = xpcall(modInfoFile, errorhandler)
            if ok and infoTable then
                return infoTable.version
            end
        end
    end
    return nil
end

function modUtility:updateWorldMod(worldModPath)
    
end

function modUtility:getEnabledValidWorldModsForWorldCreation(enabledWorldMods, steamWorkshopMods)--used by mainController
    local result = {}

    mj:log("modUtility:getEnabledValidWorldModsForWorldCreation enabledWorldMods:", enabledWorldMods)
    
    local function inspectMod(modDirName, modDirPath, worldMods, isLocal)
        local modInfoPath = modDirPath .. "/modInfo.lua"

        local modInfoFile, loadError = loadstring(fileUtils.getFileContents(modInfoPath))
        if not modInfoFile then
            mj:error("Failed to load mod info file at path:", modInfoPath, "\nerror:", loadError)
        else
            local function errorhandler(err)
                mj:error("ERROR in mod info:", modInfoPath, "\n", err)
            end

            local ok, infoTable = xpcall(modInfoFile, errorhandler)
            if ok and infoTable then
                local modType = infoTable.type
                if modType == "world" then
                    if enabledWorldMods and enabledWorldMods[modDirName] then
                        table.insert(result, modDirName)
                    end
                end
            end
        end
    end

    local appModPath = fileUtils.getSavePath("mods")
    local modDirNames = fileUtils.getDirectoryContents(appModPath)
    for i, modDirName in ipairs(modDirNames) do
        local modDirPath = appModPath .. "/" .. modDirName
        inspectMod(modDirName, modDirPath)
    end

    if steamWorkshopMods then
        for i,modDirPath in ipairs(steamWorkshopMods) do
            local modDirName = fileUtils.fileNameFromPath(modDirPath)
            inspectMod(modDirName, modDirPath)
        end
    end
    
    mj:log("modUtility:getEnabledValidWorldModsForWorldCreation result:", result)

    return result
end

return modUtility