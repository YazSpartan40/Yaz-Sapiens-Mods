local bugReporting = {}


local bridge = nil


local function makeTitleSafe(reportTitle)
    local titleToUse = string.gsub (reportTitle, " ", "_")
    if string.len(titleToUse) > 40 then
        titleToUse = string.sub(titleToUse, 1, 40)
    end

    titleToUse = string.gsub (titleToUse, "([^0-9a-zA-Z._])","")
    return titleToUse
 end


function bugReporting:startBugReport(reportID, includeWorldSave, reportTitle, descriptionOrNil, contactEmailOrNil)
    mj:log("startBugReport:", reportID, "_", makeTitleSafe(reportTitle))
    bridge:startBugReport(reportID, bugReporting.mostRecentWorldID, includeWorldSave, makeTitleSafe(reportTitle), reportTitle, descriptionOrNil, contactEmailOrNil)
end

function bugReporting:setCallback(callbackFunc)
    bridge:setCallback(callbackFunc)
end

function bugReporting:cancelCurrentReport()
    bridge:cancelCurrentReport()
end

function bugReporting:setMostRecentWorldID(worldID)
    bugReporting.mostRecentWorldID = worldID
end

function bugReporting:hasMostRecentWorldID()
    return (bugReporting.mostRecentWorldID ~= nil)
end

function bugReporting:setBridge(bridge_)
    bridge = bridge_
end

function bugReporting:exitedCleanlyLastRun()
    return bridge.exitedCleanlyLastRun
end


return bugReporting