
local modManager = mjrequire "common/modManager"

local locale = {}

locale.availableLocalizations = {}

locale.defaultLocale = nil
locale.currentLocale = nil

locale.currentLocaleKey = nil

local warned = {}
local errored = {}

function locale:get(key, inputsArrayOrNil)
    local entry = nil
    if locale.currentLocale.values then
        entry = locale.currentLocale.values[key]
    end
    if (not entry) then
        if not warned[key] then
            mj:warn("no localization found in current locale for key:", key)
            warned[key] = true
        end
        entry = locale.defaultLocale.values[key]
        if not entry then
            if not errored[key] then
                mj:error("no localization found at all for key:", key)
                errored[key] = true
            end
            return "[missing localization:" .. key .. "]"
        end
    end

    if inputsArrayOrNil then
        if (type(entry) == "function") then
            return entry(inputsArrayOrNil)
        end
    end

    return entry
end

function locale:hasLocalization(key)
    return locale.defaultLocale.values[key] ~= nil
end


function locale:getTimeDurationDescription(durationSeconds, dayLength, yearLength)
    local localeFunction = locale.currentLocale.getTimeDurationDescription
    if localeFunction then
        return localeFunction(durationSeconds, dayLength, yearLength)
    end
    
    return locale.defaultLocale.getTimeDurationDescription(durationSeconds, dayLength, yearLength)
end

function locale:getTimeRangeDescription(durationSecondsMin, durationSecondsMax, dayLength, yearLength)
    local localeFunction = locale.currentLocale.getTimeRangeDescription
    if localeFunction then
        return localeFunction(durationSecondsMin, durationSecondsMax, dayLength, yearLength)
    end
    
    return locale.defaultLocale.getTimeRangeDescription(durationSecondsMin, durationSecondsMax, dayLength, yearLength)
end

function locale:getBiomeForestDescription(biomeTags)
    local localeFunction = locale.currentLocale.getBiomeForestDescription
    if localeFunction then
        return localeFunction(biomeTags)
    end
    
    return locale.defaultLocale.getBiomeForestDescription(biomeTags)
end

function locale:getBiomeMainDescription(biomeTags)
    local localeFunction = locale.currentLocale.getBiomeMainDescription
    if localeFunction then
        return localeFunction(biomeTags)
    end
    
    return locale.defaultLocale.getBiomeMainDescription(biomeTags)
end

function locale:getBiomeTemperatureDescription(biomeTags)
    local localeFunction = locale.currentLocale.getBiomeTemperatureDescription
    if localeFunction then
        return localeFunction(biomeTags)
    end
    
    return locale.defaultLocale.getBiomeTemperatureDescription(biomeTags)
end

function locale:getBiomeFullDescription(biomeTags)
    local localeFunction = locale.currentLocale.getBiomeFullDescription
    if localeFunction then
        return localeFunction(biomeTags)
    end
    
    return locale.defaultLocale.getBiomeFullDescription(biomeTags)
end

function locale:getKeyName(inputKeyCodeName)
    local entry = nil
    if locale.currentLocale.keyboardNames then
        entry = locale.currentLocale.keyboardNames[inputKeyCodeName]
    end
    if (not entry) then
        entry = locale.defaultLocale.keyboardNames[inputKeyCodeName]
    end
    if not entry then
        return inputKeyCodeName
    end
    return entry
end



function locale:getLocalizationFileTable(infoFilePath)
    local localeInfoFile,loadError = loadstring(fileUtils.getFileContents(infoFilePath))
    if not localeInfoFile then
        mj:warn("Failed to load localization file at path:", infoFilePath, "\nerror:", loadError)
    else
        local function errorhandler(err)
            mj:warn("ERROR in localization file:", infoFilePath, "\nerror:", err)
        end

        local ok, infoTable = xpcall(localeInfoFile, errorhandler)
        if ok then
            return infoTable
        end
    end
    return nil
end


function locale:findAvailableLocalizationsAtPath(localeKeyAndDirName, fullDirPath)
    local infoFilePath = fullDirPath .. "/info.lua"

    local info = locale:getLocalizationFileTable(infoFilePath)

    local thisLocaleDirContents = fileUtils.getDirectoryContents(fullDirPath)
    local fileNames = {}
    for j,thisLocaleSubFileOrDir in ipairs(thisLocaleDirContents) do
        if thisLocaleSubFileOrDir ~= "info.lua" then
            local extension = fileUtils.fileExtensionFromPath(thisLocaleSubFileOrDir)
            if extension and extension == ".lua" then
                table.insert(fileNames, thisLocaleSubFileOrDir)
            end
        end
    end

    if locale.availableLocalizations[localeKeyAndDirName] then
        for j,fileName in ipairs(fileNames) do
            local found = false
            for k,existing in ipairs(locale.availableLocalizations[localeKeyAndDirName].fileNames) do
                if fileName == existing then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(locale.availableLocalizations[localeKeyAndDirName].fileNames, fileName)
            end
        end
    else
        locale.availableLocalizations[localeKeyAndDirName] = {
            fileNames = fileNames,
            basePaths = {}
        }
    end

    if info then
        for k,v in pairs(info) do
            locale.availableLocalizations[localeKeyAndDirName][k] = v
        end
    end

    table.insert(locale.availableLocalizations[localeKeyAndDirName].basePaths, fullDirPath)
end

function locale:searchLocalizationsPath(localizationsParentPath)
    local dirContents = fileUtils.getDirectoryContents(localizationsParentPath)
    for i,localeKeyAndDirName in ipairs(dirContents) do
        
        local fullDirPath = localizationsParentPath .. "/" .. localeKeyAndDirName
       -- mj:log("found localization:", fullDirPath)

        locale:findAvailableLocalizationsAtPath(localeKeyAndDirName, fullDirPath)
    end
end



function locale:addModLocalizations()
	local modLocalizations = modManager.localizations

	if modLocalizations then
        --mj:log("modLocalizations:", modLocalizations)
		for localeKeyAndDirName, localizations in pairs(modLocalizations) do
            for i, info in ipairs(localizations) do
                locale:findAvailableLocalizationsAtPath(localeKeyAndDirName, info.path)
            end
		end
	end
end

function locale:loadLocalizations(localizationsKey)
    local availableInfo = locale.availableLocalizations[localizationsKey]

    if (not availableInfo) or (not availableInfo.fileNames) then
        mj:error("unable to find localizations for:", localizationsKey)
        return nil
    end

    local localeTable = {}

    for i, fileName in ipairs(availableInfo.fileNames) do
        
        local function addValues(toTable, fromTable)
            for k,v in pairs(fromTable) do
                if type(v) == "table" then
                    local newTable = toTable[k]
                    if not newTable then
                        newTable = {}
                        toTable[k] = newTable
                    end
                    addValues(newTable, v)
                else
                    toTable[k] = v
                end
            end
        end

        for j,basePath in ipairs(availableInfo.basePaths) do
            local filePath = basePath .. "/" .. fileName
            local fileTable = locale:getLocalizationFileTable(filePath)
            if fileTable then
                addValues(localeTable, fileTable)
            end
        end

    end

    return localeTable
end

function locale:mjInit()
    local builtinPath = fileUtils.getResourcePath("localizations")

    local userLocalizationsPath = fileUtils.getSavePath("localizations")
    fileUtils.createDirectoriesIfNeededForDirPath(userLocalizationsPath)

    locale:searchLocalizationsPath(builtinPath)

    locale:addModLocalizations()
     
    locale:searchLocalizationsPath(userLocalizationsPath)

    --mj:log("availableLocalizations:", locale.availableLocalizations)
     
    locale.currentLocaleKey = "en_us"
    locale.defaultLocale = locale:loadLocalizations(locale.currentLocaleKey)
    locale.currentLocale = locale.defaultLocale
    
end


function locale:setLocale(localeKey)
    if localeKey ~= locale.currentLocaleKey then
        if (not localeKey) or localeKey == "" then
            locale.currentLocale = locale.defaultLocale
            locale.currentLocaleKey = "en_us"
        else
            local newLocale = locale:loadLocalizations(localeKey)
            if newLocale then
                locale.currentLocaleKey = localeKey
                locale.currentLocale = newLocale
            else
                mj:error("Failed to load localizations for:", localeKey)
            end
        end
    end
end

function locale:getLightFont()
    local availableInfo = locale.availableLocalizations[locale.currentLocaleKey]
    return availableInfo.lightFont or "sapiensLight"
end

function locale:getTitleFont()
    local availableInfo = locale.availableLocalizations[locale.currentLocaleKey]
    return availableInfo.titleFont or "sapiens"
end

function locale:getConsoleFont()
    local availableInfo = locale.availableLocalizations[locale.currentLocaleKey]
    return availableInfo.consoleFont or "console"
end

return locale