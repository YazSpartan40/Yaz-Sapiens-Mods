local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4

--local model = mjrequire "common/model"
--local material = mjrequire "common/material"
local rng = mjrequire "common/randomNumberGenerator"
local locale = mjrequire "common/locale"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiTextEntry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"
local steam = mjrequire "common/utility/steam"
local bugReporting = mjrequire "mainThread/bugReporting"

local bugReportView = {}

local sendButton = nil
local forumsSendButton = nil
--local mailButton = nil
local statusLabelTextView = nil
local titleTextEntry = nil
local descriptionTextEntry = nil
local emailTextEntry = nil
local bugReportIDString = nil
local worldSaveToggleButton = nil
local cancelUploadButton = nil

local additionalStatusTextFunc = nil

local controller = nil

local worldSaveNameTextView = nil
local currentTitleText = nil 

local minTitleChars = 5



--local joinConfirmButtonFunc = nil

local function createNewReportIDString()
    bugReportIDString = rng:randomHashString()
    bugReportIDString = string.sub(bugReportIDString, 1,6)
end

local function urlEscape(str)
    str = string.gsub (str, "([^0-9a-zA-Z !'()*._~-])", -- locale independent
       function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "%%20")
    return str
 end
 
 local function setUIDisabled(uiDisabled, buttonsDisabled)
    --uiStandardButton:setDisabled(mailButton, buttonsDisabled)
    uiStandardButton:setDisabled(sendButton, buttonsDisabled)
    if forumsSendButton then
        uiStandardButton:setDisabled(forumsSendButton, buttonsDisabled)
    end

    uiStandardButton:setDisabled(worldSaveToggleButton, uiDisabled)
    uiTextEntry:setDisabled(titleTextEntry, uiDisabled)
    uiTextEntry:setDisabled(descriptionTextEntry, uiDisabled)
    uiTextEntry:setDisabled(emailTextEntry, uiDisabled)
end

local function callAdditionalStatusFunc()
    if additionalStatusTextFunc then
        additionalStatusTextFunc(statusLabelTextView.text)
    end
end

local statusFunctions = {
    uploading = function(done, uploadProgress, uploadSize)
        if uploadSize > 0 then
            local sizeInMB = uploadSize / (1024 * 1024)
            local progressInMB = uploadProgress / (1024 * 1024)
            statusLabelTextView.text = string.format("%s... %.1f/%.1fMB", locale:get("reporting_uploading"), progressInMB, sizeInMB)
        else
            statusLabelTextView.text = string.format("%s...", locale:get("reporting_uploading"))
        end
        callAdditionalStatusFunc()
        cancelUploadButton.hidden = false
    end,
    uploading_logs = function(done, uploadProgress, uploadSize)
        if uploadSize > 0 then
            local sizeInMB = uploadSize / (1024 * 1024)
            local progressInMB = uploadProgress / (1024 * 1024)
            statusLabelTextView.text = string.format("%s logs... %.1f/%.1fMB", locale:get("reporting_uploading"), progressInMB, sizeInMB)
        else
            statusLabelTextView.text = string.format("%s logs...", locale:get("reporting_uploading"))
        end
        callAdditionalStatusFunc()
        cancelUploadButton.hidden = false
    end,
    uploading_world = function(done, uploadProgress, uploadSize)
        if uploadSize > 0 then
            local sizeInMB = uploadSize / (1024 * 1024)
            local progressInMB = uploadProgress / (1024 * 1024)
            statusLabelTextView.text = string.format("%s world... %.1f/%.1fMB", locale:get("reporting_uploading"), progressInMB, sizeInMB)
        else
            statusLabelTextView.text = string.format("%s world...", locale:get("reporting_uploading"))
        end
        callAdditionalStatusFunc()
        cancelUploadButton.hidden = false
    end,
    zipFailed = function(done, uploadProgress, uploadSize)
        statusLabelTextView.text = locale:get("reporting_zipFailed")
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end,
    connectionFailed = function(done, uploadProgress, uploadSize)
        statusLabelTextView.text = locale:get("reporting_connectionFailed")
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end,
    fileTooLarge = function(done, uploadProgress, uploadSize)
        local sizeInMB = uploadSize / (1024 * 1024)
        statusLabelTextView.text = locale:get("reporting_fileTooLarge") .. string.format(" (%.1fMB, 500MB max)", sizeInMB)
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end,
    uploadFailed = function(done, uploadProgress, uploadSize, extraInfoTextOrNil)
        local statusText = locale:get("reporting_uploadFailed")
        if extraInfoTextOrNil then
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
        statusLabelTextView.text = statusText
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end,
    error = function(done, uploadProgress, uploadSize)
        statusLabelTextView.text = locale:get("reporting_error")
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end,
    inProgress = function(done, uploadProgress, uploadSize)
        statusLabelTextView.text = locale:get("reporting_inProgress")
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end,
    uploadComplete = function(done, uploadProgress, uploadSize)
        if titleTextEntry then
            statusLabelTextView.text = locale:get("reporting_uploadComplete")
            uiTextEntry:setText(titleTextEntry, nil)
            createNewReportIDString()
            cancelUploadButton.hidden = true
            callAdditionalStatusFunc()
        end
    end,
    cancelled = function(done, uploadProgress, uploadSize)
        statusLabelTextView.text = locale:get("reporting_cancelled")
        uiTextEntry:setText(titleTextEntry, nil)
        createNewReportIDString()
        cancelUploadButton.hidden = true
        callAdditionalStatusFunc()
    end
}


local function bugReportCallback(done, status, uploadProgress, uploadSize, extraInfoTextOrNil)
    if statusFunctions[status] then
        statusFunctions[status](done, uploadProgress, uploadSize, extraInfoTextOrNil)
    end
    if done then
        setUIDisabled(false, true)
    else
        setUIDisabled(true, true)
    end
end


local function startBugReport(title, descriptionOrNil, contactEmailOrNil)
    statusLabelTextView.text = locale:get("reporting_creating")
    setUIDisabled(true, true)
    uiStandardButton:setDisabled(cancelUploadButton, false)
    bugReporting:setCallback(bugReportCallback)
    bugReporting:startBugReport(bugReportIDString, uiStandardButton:getToggleState(worldSaveToggleButton), title, descriptionOrNil, contactEmailOrNil)

end

local function titleChanged(newValue)
    currentTitleText = newValue
    if newValue and string.len(newValue) >= minTitleChars then
        if forumsSendButton then
            uiStandardButton:setDisabled(forumsSendButton, false)
        end
        uiStandardButton:setDisabled(sendButton, false)
        --uiStandardButton:setDisabled(mailButton, false)
        statusLabelTextView.text = ""
    else
        statusLabelTextView.text = locale:get("reporting_pleaseWriteATitle")
        if forumsSendButton then
            uiStandardButton:setDisabled(forumsSendButton, true)
        end
        uiStandardButton:setDisabled(sendButton, true)
       -- uiStandardButton:setDisabled(mailButton, true)
    end
end

function bugReportView:load(controller_, containerView, isMainMenu)
    if bugReportView.mainView then
        return
    end
    controller = controller_
    local showForumsButton = false-- (not controller_:getIsDemo())
    
    bugReportView.containerView = containerView
    local mainView = View.new(containerView)
    mainView.size = containerView.size
    bugReportView.mainView = mainView

    local baseYOffset = -40
    if isMainMenu then
        baseYOffset = -100
    end

    local infoTextView = TextView.new(mainView)
    infoTextView.baseOffset = vec3(60, baseYOffset, 0)
    infoTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    infoTextView.font = Font(uiCommon.fontName, 18)
    infoTextView.color = vec4(1.0,1.0,1.0,1.0)
    infoTextView.wrapWidth = mainView.size.x - 120
    infoTextView.text = locale:get("reporting_infoText")

    local titleTextEntrySize = vec2(700.0,30.0)

    titleTextEntry = uiTextEntry:create(mainView, titleTextEntrySize, uiTextEntry.types.wide, MJPositionInnerLeft, locale:get("reporting_bugTitle"))
    uiTextEntry:setMaxChars(titleTextEntry, 100)
    titleTextEntry.baseOffset = vec3(0, baseYOffset -40, 2)
    titleTextEntry.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    uiTextEntry:setText(titleTextEntry, nil)
    uiTextEntry:setChangedContinuousFunction(titleTextEntry, function(newValue)
        titleChanged(newValue)
    end)

    local titleLabelTextView = TextView.new(mainView)
    titleLabelTextView.baseOffset = vec3(-12, 0, 0)
    titleLabelTextView.relativeView = titleTextEntry
    titleLabelTextView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    titleLabelTextView.font = Font(uiCommon.fontName, 18)
    titleLabelTextView.color = vec4(1.0,1.0,1.0,1.0)
    titleLabelTextView.text = locale:get("reporting_bugTitle") .. ":"

    
    local descriptionTextEntrySize = vec2(700.0,220)

    descriptionTextEntry = uiTextEntry:create(mainView, descriptionTextEntrySize, uiTextEntry.types.multiLine, MJPositionInnerLeft, locale:get("reporting_bugDescription"))
    uiTextEntry:setMaxChars(descriptionTextEntry, 1000)
    descriptionTextEntry.baseOffset = vec3(0, -10, 2)
    descriptionTextEntry.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    descriptionTextEntry.relativeView = titleTextEntry
    uiTextEntry:setText(descriptionTextEntry, nil)
    

    local descriptionLabelTextView = TextView.new(mainView)
    descriptionLabelTextView.baseOffset = vec3(-15, -4, 0)
    descriptionLabelTextView.relativeView = descriptionTextEntry
    descriptionLabelTextView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionTop)
    descriptionLabelTextView.font = Font(uiCommon.fontName, 18)
    descriptionLabelTextView.color = vec4(1.0,1.0,1.0,1.0)
    descriptionLabelTextView.text = locale:get("reporting_bugDescription") .. ":"

    local emailTextEntrySize = vec2(700.0,30.0)

    emailTextEntry = uiTextEntry:create(mainView, emailTextEntrySize, uiTextEntry.types.wide, MJPositionInnerLeft, locale:get("reporting_email"))
    uiTextEntry:setMaxChars(emailTextEntry, 320)
    emailTextEntry.baseOffset = vec3(0, -10, 2)
    emailTextEntry.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    emailTextEntry.relativeView = descriptionTextEntry
    local contactEmailText = controller.appDatabase:dataForKey("bugReportContact")
    uiTextEntry:setText(emailTextEntry, contactEmailText)

    local emailLabelTextView = TextView.new(mainView)
    emailLabelTextView.baseOffset = vec3(-15, 0, 0)
    emailLabelTextView.relativeView = emailTextEntry
    emailLabelTextView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    emailLabelTextView.font = Font(uiCommon.fontName, 18)
    emailLabelTextView.color = vec4(1.0,1.0,1.0,1.0)
    emailLabelTextView.text = locale:get("reporting_email") .. ":"

    local yOffsetBetweenElements = 25
    local elementTitleX = -mainView.size.x * 0.5 - 10 + 40
    local elementControlX = mainView.size.x * 0.5 + 40
    local elementYOffsetStart = titleTextEntry.baseOffset.y - titleTextEntry.size.y - 20 - descriptionTextEntry.size.y + descriptionTextEntry.baseOffset.y - emailTextEntry.size.y + emailTextEntry.baseOffset.y

    local elementYOffset = elementYOffsetStart

    

    local function addToggleButton(parentView, toggleButtonTitle, toggleValue, changedFunction)
        local toggleButton = uiStandardButton:create(parentView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        toggleButton.baseOffset = vec3(elementControlX, elementYOffset, 0)
        uiStandardButton:setToggleState(toggleButton, toggleValue)
        
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 18)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
        textView.text = toggleButtonTitle
    
        uiStandardButton:setClickFunction(toggleButton, function()
            changedFunction(uiStandardButton:getToggleState(toggleButton))
        end)

        elementYOffset = elementYOffset - yOffsetBetweenElements
        return toggleButton
    end

    worldSaveToggleButton = addToggleButton(mainView, locale:get("reporting_sendWorldSaveFiles") .. ":", true, function(newValue) 
    end)

    

    worldSaveNameTextView = TextView.new(mainView)
    worldSaveNameTextView.baseOffset = vec3(8, -4, 0)
    worldSaveNameTextView.relativeView = worldSaveToggleButton
    worldSaveNameTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    worldSaveNameTextView.font = Font(uiCommon.fontName, 18)
    worldSaveNameTextView.color = vec4(1.0,1.0,1.0,1.0)
    worldSaveNameTextView.text = "(World Name)"

    local buttonSize = vec2(180, 40)
    
    --[[mailButton = uiStandardButton:create(mainView, buttonSize)
    mailButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    mailButton.baseOffset = vec3(-buttonSize.x * 0.5 - 10,60, 0)
    uiStandardButton:setText(mailButton, locale:get("reporting_submitViaEmail"))
    uiStandardButton:setDisabled(mailButton, true)
    uiStandardButton:setClickFunction(mailButton, function()
        if currentTitleText and string.len(currentTitleText) > 5 then
            local titleWithID = currentTitleText .. " [" .. controller:getVersionString() .. "-" .. bugReportIDString .. "]"
            local escapedTitle = urlEscape(titleWithID)
            fileUtils.openFile("mailto:bugreports@majicjungle.com?Subject=" .. escapedTitle .. "&Body=" .. "Please provide a summary of what went wrong here.%0D%0AIf possible please include a series of steps we can follow that will cause the bug to happen.")
            startBugReport(currentTitleText)
        end
    end)]]

    local function getTitleWithID()
        return currentTitleText .. " [" .. controller:getVersionString() .. "-" .. bugReportIDString .. "]"
    end

    local function getAndSaveContactDetails()
        local contactInfo = uiTextEntry:getText(emailTextEntry)
        if contactInfo and contactInfo ~= "" then
            controller.appDatabase:setDataForKey(contactInfo, "bugReportContact")
            return contactInfo
        else
            controller.appDatabase:removeDataForKey("bugReportContact")
        end
        return nil
    end

    sendButton = uiStandardButton:create(mainView, buttonSize)
    sendButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    if showForumsButton then
        sendButton.baseOffset = vec3(-buttonSize.x * 0.5 - 10,60, 0)
    else
        sendButton.baseOffset = vec3(0,40, 0)
    end
    uiStandardButton:setText(sendButton, locale:get("reporting_sendBugReport"))
    uiStandardButton:setDisabled(sendButton, true)
    uiStandardButton:setClickFunction(sendButton, function()
        if currentTitleText and string.len(currentTitleText) >= minTitleChars then
            --[[local titleWithID = getTitleWithID()
            local escapedTitle = urlEscape(titleWithID)
            fileUtils.openFile("mailto:bugreports@majicjungle.com?Subject=" .. escapedTitle .. "&Body=" .. "Please provide a summary of what went wrong here.%0D%0AIf possible please include a series of steps we can follow that will cause the bug to happen.")]]
            startBugReport(currentTitleText, uiTextEntry:getText(descriptionTextEntry), getAndSaveContactDetails())
        end
    end)

    if showForumsButton then
        forumsSendButton = uiStandardButton:create(mainView, buttonSize)
        forumsSendButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        forumsSendButton.baseOffset = vec3(buttonSize.x * 0.5 + 10,60, 0)
        uiStandardButton:setText(forumsSendButton, locale:get("reporting_submitViaForums"))
        uiStandardButton:setDisabled(forumsSendButton, true)
        uiStandardButton:setClickFunction(forumsSendButton, function()
            if currentTitleText and string.len(currentTitleText) >= minTitleChars then
                local titleWithID = getTitleWithID()
                local escapedTitle = urlEscape(titleWithID)
                local postURL = "https://forums.playsapiens.com/new-topic?title=" .. escapedTitle 
                local descriptionText = uiTextEntry:getText(descriptionTextEntry)
                if descriptionText and descriptionText ~= "" then
                    local escapedDescription = urlEscape(descriptionText)
                    if escapedDescription and escapedDescription ~= "" then
                        postURL = postURL .. "&body=" .. escapedDescription
                    end
                end
                postURL = postURL .. "&category=beta-testing/beta-bug-reports&tags=bug-report"

                steam:openURL(postURL)

                startBugReport(currentTitleText, descriptionText, getAndSaveContactDetails())
            end
        end)
    end

    statusLabelTextView = TextView.new(mainView)
    statusLabelTextView.baseOffset = vec3(0, 90, 0)
    statusLabelTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    statusLabelTextView.font = Font(uiCommon.fontName, 18)
    statusLabelTextView.color = vec4(1.0,1.0,1.0,1.0)
    statusLabelTextView.text = locale:get("reporting_pleaseWriteATitle")
    statusLabelTextView.wrapWidth = mainView.size.x - 80
    
    cancelUploadButton = uiStandardButton:create(mainView, buttonSize)
    cancelUploadButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    cancelUploadButton.relativeView = statusLabelTextView
    cancelUploadButton.baseOffset = vec3(10,0, 0)
    uiStandardButton:setText(cancelUploadButton, locale:get("ui_action_cancel"))
    cancelUploadButton.hidden = true
    uiStandardButton:setClickFunction(cancelUploadButton, function()
        uiStandardButton:setDisabled(cancelUploadButton, true)
        statusLabelTextView.text = locale:get("ui_action_cancelling") .. "..."
        bugReporting:cancelCurrentReport()
    end)

end

function bugReportView:parentBecameVisible()
    createNewReportIDString()

    local mostRecentWorldID = bugReporting.mostRecentWorldID
    local worldName = nil

    for i,worldInfo in ipairs(controller:getWorldSaveFileList()) do
        if worldInfo.worldID == mostRecentWorldID then
            worldName = worldInfo.name
            break
        end
    end

    if worldName then
        worldSaveNameTextView.text = string.format("(%s)", worldName)
    else
        worldSaveNameTextView.text = ""
    end

    bugReporting:setCallback(bugReportCallback) --this may get called immediately
end

--[[
function bugReportView:sendCrashReport(controller_, mainMenu, statusFunc_)
    additionalStatusTextFunc = statusFunc_
    createNewReportIDString()
    if not bugReportView.mainView then
        bugReportView:init(controller_, mainMenu)
    end
    uiStandardButton:setToggleState(worldSaveToggleButton, false)
    uiStandardButton:setToggleState(logFilesToggleButton, true)
    bugReporting:setCallback(bugReportCallback) --this may get called immediately
    startBugReport("crash", nil, nil)
end]]

function bugReportView:populateCrashTitle()
    local textToUse = "Crash"
    uiTextEntry:setText(titleTextEntry, textToUse)
    titleChanged(textToUse)
end

function bugReportView:cleanup()
    if bugReportView.mainView then
        bugReportView.containerView:removeSubview(bugReportView.mainView)
        bugReporting:setCallback(nil)
        bugReportView.containerView = nil
        bugReportView.mainView = nil
    end
end

function bugReportView:backButtonClicked()
    return false
end

function bugReportView:parentBecameHidden()
    
end

return bugReportView