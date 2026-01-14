
local locale = require "common/locale"
locale:mjInit() --needs to be called manually as we haven't loaded a world yet, so mjrequire is not setup

local serverBugReporting = {}


local bridge = nil
local worldID = nil


local function makeTitleSafe(reportTitle)
    local titleToUse = string.gsub (reportTitle, " ", "_")
    if string.len(titleToUse) > 40 then
        titleToUse = string.sub(titleToUse, 1, 40)
    end

    titleToUse = string.gsub (titleToUse, "([^0-9a-zA-Z._])","")
    return titleToUse
 end


function serverBugReporting:startBugReport(reportID, includeWorldSave, reportTitle, descriptionOrNil, contactEmailOrNil)
    mj:log("Starting bug report:", reportID, "_", makeTitleSafe(reportTitle))
    bridge:startBugReport(reportID, worldID, includeWorldSave, makeTitleSafe(reportTitle), reportTitle, descriptionOrNil, contactEmailOrNil)
end

function serverBugReporting:setCallback(callbackFunc)
    bridge:setCallback(callbackFunc)
end

function serverBugReporting:cancelCurrentReport()
    bridge:cancelCurrentReport()
end

local function logStatusText(statusText)
    mj:log("bug reporter:", statusText)
end

--local lastUploadSizeMBFloored = 99

local statusFunctions = {
    uploading = function(done, uploadProgress, uploadSize)
        -- let's just let the curl progress display without interrupting it
        --[[if uploadSize > 0 then
            local sizeInMB = uploadSize / (1024 * 1024)
            local progressInMB = uploadProgress / (1024 * 1024)
            local uploadSizeMBFloored = math.floor(progressInMB)
            if uploadSizeMBFloored ~= lastUploadSizeMBFloored then
                lastUploadSizeMBFloored = uploadSizeMBFloored
                local statusText = string.format("%s... %.1f/%.1fMB", locale:get("reporting_uploading"), progressInMB, sizeInMB)
                logStatusText(statusText)
            end
        elseif not hasReportedUploadStart then
            local statusText = string.format("%s...", locale:get("reporting_uploading"))
            logStatusText(statusText)
            hasReportedUploadStart = true
        end]]
    end,
    zipFailed = function(done, uploadProgress, uploadSize)
        local statusText = locale:get("reporting_zipFailed")
        logStatusText(statusText)
    end,
    connectionFailed = function(done, uploadProgress, uploadSize)
        local statusText = locale:get("reporting_connectionFailed")
        logStatusText(statusText)
    end,
    fileTooLarge = function(done, uploadProgress, uploadSize)
        local sizeInMB = uploadSize / (1024 * 1024)
        local statusText = locale:get("reporting_fileTooLarge") .. string.format(" (%.1fMB, 500MB max)", sizeInMB)
        logStatusText(statusText)
    end,
    uploadFailed = function(done, uploadProgress, uploadSize, extraInfoTextOrNil)
        local statusText = locale:get("reporting_uploadFailed")
        if extraInfoTextOrNil then --pretty sure this is all old s3 garbage, left here for now
            mj:log("extraInfoText:", extraInfoTextOrNil)
            local appendText = nil
            local parsed = mj:simpleXMLParse(extraInfoTextOrNil)
            mj:log("parsed:", parsed)
            if parsed then
                local recursivelyFindMessages = nil
                recursivelyFindMessages = function(inputTable)
                    if type(inputTable) == "table" then
                        if (inputTable.label == "Message" or inputTable.label == "Code") and inputTable[1] and type(inputTable[1]) == "string" then
                            if appendText then
                                appendText = appendText .. "\n" .. inputTable[1]
                            else
                                appendText = inputTable[1]
                            end
                        end
                        for i,subTable in ipairs(inputTable) do
                            recursivelyFindMessages(subTable)
                        end
                    end
                end
                recursivelyFindMessages(parsed)
            end

            if not appendText then
                appendText = extraInfoTextOrNil
            end
            statusText = statusText .. "\n" .. appendText
        end
        logStatusText(statusText)
    end,
    error = function(done, uploadProgress, uploadSize)
        local statusText = locale:get("reporting_error")
        logStatusText(statusText)
    end,
    inProgress = function(done, uploadProgress, uploadSize)
        local statusText = locale:get("reporting_inProgress")
        logStatusText(statusText)
    end,
    uploadComplete = function(done, uploadProgress, uploadSize)
        local statusText = locale:get("reporting_uploadComplete")
        logStatusText(statusText)
    end,
    cancelled = function(done, uploadProgress, uploadSize)
        local statusText = locale:get("reporting_cancelled")
        logStatusText(statusText)
    end
}


local function bugReportCallback(done, status, uploadProgress, uploadSize, extraInfoTextOrNil)
    if statusFunctions[status] then
        statusFunctions[status](done, uploadProgress, uploadSize, extraInfoTextOrNil)
    end
end

local function createNewReportIDString()
    local bugReportIDString = bridge:randomHashString() --rng has not been initialized yet on the server
    bugReportIDString = string.sub(bugReportIDString, 1,6)
    return bugReportIDString
end

function serverBugReporting:setBridge(bridge_, worldID_, sendBugReportWorlds)
    bridge = bridge_
    worldID = worldID_

    --locale:setLocale("en_us")
    
    if not bridge.exitedCleanlyLastRun then
        serverBugReporting:setCallback(bugReportCallback)
        serverBugReporting:startBugReport(createNewReportIDString(), sendBugReportWorlds, "server_crash", nil, nil)
    end
end

function serverBugReporting:exitedCleanlyLastRun()
    return bridge.exitedCleanlyLastRun
end


return serverBugReporting
