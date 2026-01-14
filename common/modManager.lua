local modManager = {
    modInfosByTypeByDirName = {
        world = {},
        app = {},
    },

    resourceAdditions = {},
    localizationAdditions = {},

    orderedCmodLibraryPaths = {}, --used by engine
    resourceOverrides = {}, --used by engine
    enabledModDirNamesAndVersionsByType = { --used by engine
        world = {},
        app = {},
    }
}

local scriptModPathArraysByRequireName = {}
local orderedCmodLoadOrders = {}
local loadedPaths = {}
local overridePathsAndLoadOrders = {}
local localizationsWithLoadOrders = {}

local function modRequire(path)
    if loadedPaths[path] then
        return loadedPaths[path]
    end

    local mods = scriptModPathArraysByRequireName[path]
    if mods then
       -- mj:log("found mod script:", path)
        --local module = require(path)
        local moduleLoaded, module = pcall(require, path)


        local orderedLoadFunctionsAndLoadOrders = {}
        
        for i,moduleInfo in ipairs(mods) do
            local identifierString = moduleInfo.dirName .. "/"
            local stringLength = string.len(identifierString)

            if stringLength < 44 then
                local maxRemainingLength = 44 - stringLength
                if string.len(moduleInfo.relativeFileOrDir) > maxRemainingLength then
                    identifierString = identifierString .. ".." .. string.sub(moduleInfo.relativeFileOrDir, -maxRemainingLength)
                else
                    identifierString = identifierString .. moduleInfo.relativeFileOrDir
                end
            end
            local modFile, modError = loadstring(fileUtils.getFileContents(moduleInfo.path), identifierString)
            if not modFile then
                mj:error("Failed to load mod file at path:", moduleInfo.path, "\nerror:", modError)
            else
    
                local function errorhandler(err)
                    mj:error("Mod error:", moduleInfo.path, "\n", err)
                end
                local ok, modObject = xpcall(modFile, errorhandler)
                if not modObject then
                    mj:error("Mod load failed:", moduleInfo.path, "\nPlease make sure that you are returning the mod object at the end of this file")
                elseif not ok then
                    mj:error("Mod load failed:", moduleInfo.path)
                else
                    local onloadFunction = modObject.onload
                    if onloadFunction then
                        local loadOrder = moduleInfo.defaultLoadOrder
                        if modObject.loadOrder then
                            loadOrder = modObject.loadOrder
                        end
                        local insertIndex = #orderedLoadFunctionsAndLoadOrders + 1
                        for j,currentFunctionInfo in ipairs(orderedLoadFunctionsAndLoadOrders) do
                            if currentFunctionInfo.loadOrder >= loadOrder then
                                insertIndex = j
                                break
                            end
                        end
                        table.insert(orderedLoadFunctionsAndLoadOrders, insertIndex, {
                            loadOrder = loadOrder,
                            modObject = modObject,
                            errorhandler = errorhandler,
                            onloadFunction = onloadFunction,
                        })
                    elseif not moduleLoaded then
                        module = modObject
                        moduleLoaded = true
                    end
                end
            end
        end
        
        if not module then
            mj:error("Failed to load any base lua module at path:", path)
            error()
        end

        for i,onloadFunctionInfo in ipairs(orderedLoadFunctionsAndLoadOrders) do
            xpcall(onloadFunctionInfo.onloadFunction, onloadFunctionInfo.errorhandler, onloadFunctionInfo.modObject, module)
        end


        if module.mjInit then
            module.mjInit(module)
        end

        loadedPaths[path] = module
        return module
    else
        local module = require(path)
        
        if module.mjInit then
            module.mjInit(module)
        end
        
        loadedPaths[path] = module
        
        return module
    end
end

local function recursivelyFindScripts(scriptDirPath, requirePath, infoTable, localPath)
    local scriptDirContents = fileUtils.getDirectoryContents(scriptDirPath)
    for i,subFileOrDir in ipairs(scriptDirContents) do
        local extension = fileUtils.fileExtensionFromPath(subFileOrDir)
        if extension and extension == ".lua" then
            local moduleName = fileUtils.removeExtensionForPath(subFileOrDir)
            if requirePath then
                moduleName = requirePath .. "/" .. moduleName
            end
            if not scriptModPathArraysByRequireName[moduleName] then
                scriptModPathArraysByRequireName[moduleName] = {}
            end
            table.insert(scriptModPathArraysByRequireName[moduleName], {
                path = scriptDirPath .. "/" .. subFileOrDir,
                defaultLoadOrder = infoTable.loadOrder or 1,
                dirName = infoTable.dirName,
                relativeFileOrDir = localPath .. "/" .. subFileOrDir,
            })
        else
            local subDirName = subFileOrDir
            if requirePath then
                subDirName = requirePath .. "/" .. subDirName
            end
            recursivelyFindScripts(scriptDirPath .. "/" .. subFileOrDir, subDirName, infoTable, localPath .. "/" .. subFileOrDir)
        end
    end
end




local function loadMod(modDirPath, infoTable)
    local scriptDir = modDirPath .. "/scripts"
    local loadOrder = infoTable.loadOrder or 1
    recursivelyFindScripts(scriptDir, nil, infoTable, "scripts")

    local cmodDir = modDirPath .. "/lib"
    local cmodDirContents = fileUtils.getDirectoryContents(cmodDir)

    mj:log("Loading mod at path:", modDirPath, " info:", infoTable, " cmodDirContents:", cmodDirContents)

    if cmodDirContents then
        for i,cmodName in ipairs(cmodDirContents) do
            local absolutePath = cmodDir .. "/" .. cmodName
            
            local insertIndex = #orderedCmodLoadOrders + 1
            for j,otherOrder in ipairs(orderedCmodLoadOrders) do
                if otherOrder >= loadOrder then
                    insertIndex = j
                    break
                end
            end

            table.insert(orderedCmodLoadOrders, insertIndex, loadOrder)
            table.insert(modManager.orderedCmodLibraryPaths, insertIndex, absolutePath)
        end
    end


    --[[local function loadResources(dirName, outputTable)
        local shadersDir = modDirPath .. "/" .. dirName
        local shadersDirContents = fileUtils.getDirectoryContents(shadersDir)
    
        if shadersDirContents then
            for i,shaderName in ipairs(shadersDirContents) do
                local absolutePath = shadersDir .. "/" .. shaderName
    
                local shouldAdd = true
                if outputTable[shaderName] then
                    if outputTable[shaderName].loadOrder > loadOrder then
                        shouldAdd = false
                    end
                end
    
                if shouldAdd then
                    outputTable[shaderName] = {
                        loadOrder = loadOrder,
                        absolutePath = absolutePath,
                    }
                end
            end
        end
    end]]

    local function recursivelyFindResources(localDirPath, resourceAdditionsOrNil)

        local resourceAdditions = resourceAdditionsOrNil
        if not resourceAdditions then
            resourceAdditions = modManager.resourceAdditions[localDirPath]
            if not resourceAdditions then
                resourceAdditions = {}
                modManager.resourceAdditions[localDirPath] = resourceAdditions
            end
        end

        local absoluteDirPath = modDirPath .. "/" .. localDirPath
        local dirContents = fileUtils.getDirectoryContents(absoluteDirPath)
        for i,subFileOrDir in ipairs(dirContents) do
            local localSubFileOrDirPath = localDirPath .. "/" .. subFileOrDir
            local absoluteSubPath = modDirPath .. "/" .. localSubFileOrDirPath
            if fileUtils.isDirectoryAtPath(absoluteSubPath) then
                recursivelyFindResources(localSubFileOrDirPath, resourceAdditions)
            else
                local shouldAdd = true
                if overridePathsAndLoadOrders[localSubFileOrDirPath] then
                    if overridePathsAndLoadOrders[localSubFileOrDirPath].loadOrder > loadOrder then
                        shouldAdd = false
                    end
                end
    
                if shouldAdd then
                    overridePathsAndLoadOrders[localSubFileOrDirPath] = {
                        loadOrder = loadOrder,
                        absolutePath = absoluteSubPath,
                    }

                    resourceAdditions[localSubFileOrDirPath] = absoluteSubPath
                end
            end
        end
    end

    recursivelyFindResources("spv")
    recursivelyFindResources("models")
    recursivelyFindResources("audio")
    recursivelyFindResources("fonts")
    recursivelyFindResources("img")

    
    local function findLocalizations()
        local absoluteDirPath = modDirPath .. "/localizations"
        local dirContents = fileUtils.getDirectoryContents(absoluteDirPath)
        if dirContents then
            for i,subFileOrDir in ipairs(dirContents) do
                local localizationsPath = absoluteDirPath .. "/" .. subFileOrDir
                if fileUtils.isDirectoryAtPath(localizationsPath) then
                    local localizationInfos = localizationsWithLoadOrders[subFileOrDir]
                    if not localizationInfos then
                        localizationInfos = {}
                        localizationsWithLoadOrders[subFileOrDir] = localizationInfos
                    end
                    table.insert(localizationInfos, {
                        path = localizationsPath,
                        loadOrder = loadOrder
                    })
                end
            end
        end
    end

    findLocalizations()
end

function modManager:init(enabledAppMods, enabledWorldMods, worldModPathOrNil, steamWorkshopMods, additionalSearchPaths)
    local modPath = fileUtils.getSavePath("mods")
    fileUtils.createDirectoriesIfNeededForDirPath(modPath)

    local foundMods = {}

    mj:log("enabledAppMods:", enabledAppMods, " enabledWorldMods:", enabledWorldMods)
    --mj:log("worldModPathOrNilToLoadFromBasePath:", worldModPathOrNilToLoadFromBasePath)

    local function inspectMod(modDirName, modDirPath, worldMods, isLocal)
        local modInfoPath = modDirPath .. "/modInfo.lua"

        local fileContents = fileUtils.getFileContents(modInfoPath)
        if fileContents and fileContents ~= "" then
            local modInfoFile,loadError = loadstring(fileContents)
            if not modInfoFile then
                mj:error("Failed to load mod info file at path:", modInfoPath, " loadError:", loadError)
            else
                local function errorhandler(err)
                    mj:error("ERROR in mod info:", modInfoPath, "\n", err)
                end

                local ok, infoTable = xpcall(modInfoFile, errorhandler)
                if ok then
                    local modType = infoTable.type
                    if (not modType) or (modType ~= "world" and modType ~= "app") then
                        mj:error("Mod info contained invalid type:", infoTable.type, " at path:", modInfoPath, " (modinfo table must have a type of \"world\" or \"app\")")
                    else

                        infoTable.isLocal = isLocal
                        infoTable.directory = modDirPath
                        infoTable.dirName = modDirName
                        modManager.modInfosByTypeByDirName[modType][modDirName] = infoTable

                        if not isLocal then
                            infoTable.steamURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. modDirName
                        end

                        if modType == "app" then
                            if not worldMods then
                                foundMods[modDirName] = true
                                if enabledAppMods and enabledAppMods[modDirName] then
                                    mj:log("Loading enabled app mod:", modDirName)
                                    table.insert(modManager.enabledModDirNamesAndVersionsByType["app"], {
                                        name = modDirName,
                                        path = modDirPath,
                                        version = infoTable.version,
                                    })
                                    loadMod(modDirPath, infoTable) --todo loadMod probably needs to be called after some kind of version check
                                --else
                                    --mj:log("Skipping disabled app mod:", modDirName)
                                end
                            end
                        else
                            if worldMods then
                                foundMods[modDirName] = true
                                if enabledWorldMods and enabledWorldMods[modDirName] then
                                    mj:log("Loading enabled world mod:", modDirName)
                                    table.insert(modManager.enabledModDirNamesAndVersionsByType["world"], {
                                        name = modDirName,
                                        path = modDirPath,
                                        version = infoTable.version,
                                    })
                                    loadMod(modDirPath, infoTable)
                                --else
                                    --mj:log("Skipping disabled world mod:", modDirName)
                                end
                            end
                        end
                    end
                end
            end
        else
            mj:error("Failed to load mod info file at path:", modInfoPath)
        end
    end

    local function searchDir(dirPath, worldMods)
        local modDirNames = fileUtils.getDirectoryContents(dirPath)
        for i, modDirName in ipairs(modDirNames) do
            if not foundMods[modDirName] then
                local modDirPath = dirPath .. "/" .. modDirName
                inspectMod(modDirName, modDirPath, worldMods, true)
            end
        end
    end
    
    local function searchSteamMods(worldMods)
        if steamWorkshopMods then
            for i,modDirPath in ipairs(steamWorkshopMods) do
                local modDirName = fileUtils.fileNameFromPath(modDirPath)
                if not foundMods[modDirName] then
                    inspectMod(modDirName, modDirPath, worldMods, false)
                end
            end
        end
    end

    if worldModPathOrNil then --first found wins. So this will prioritize mods that are in the world's directory.
        searchDir(worldModPathOrNil, true)
    end

    local function searchAll(worldMods)
        if additionalSearchPaths then
            for i,additionalSearchPath in ipairs(additionalSearchPaths) do
                searchDir(additionalSearchPath, worldMods)
            end
        end
        searchDir(modPath, worldMods)
        searchSteamMods(worldMods)
    end

    searchAll(true)
    searchAll(false)
    

    for k,infos in pairs(localizationsWithLoadOrders) do
        
        local function sortLocalizations(a,b)
            return a.loadOrder < b.loadOrder
        end

        table.sort(infos, sortLocalizations)
    end
    modManager.localizations = localizationsWithLoadOrders

    for override, info in pairs(overridePathsAndLoadOrders) do
        modManager.resourceOverrides[override] = info.absolutePath
    end
    
    mjrequire = modRequire
end

return modManager