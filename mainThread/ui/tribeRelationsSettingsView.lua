local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec2 = mjm.vec2



local locale = mjrequire "common/locale"
--local gameObject = mjrequire "common/gameObject"
local model = mjrequire "common/model"
local material = mjrequire "common/material"

--local sapienConstants = mjrequire "common/sapienConstants"
--local constructable = mjrequire "common/constructable"
--local resource = mjrequire "common/resource"
--local quest = mjrequire "common/quest"
--local gameConstants = mjrequire "common/gameConstants"
--local rng = mjrequire "common/randomNumberGenerator"
--local audio = mjrequire "mainThread/audio"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
--local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
--local keyMapping = mjrequire "mainThread/keyMapping"
--local eventManager = mjrequire "mainThread/eventManager"
--local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"


local tribeRelationsSettingsView = {}

local tribeSettingsView = nil
local world = nil
local logicInterface = nil

local tribeSettingsSummaryTextView = nil
local allowStorageAreaItemUseToggleButton = nil
--local allowStoringInStorageAreasToggleButton = nil
local allowBedUseToggleButton = nil
local treatAsThreatToggleButton = nil

local currentDestinationState = nil

local notAlliedWarningIconView = nil

function tribeRelationsSettingsView:update(destinationState)
    currentDestinationState = destinationState

    tribeSettingsSummaryTextView.text = locale:get("tribeRelations_tribeSettingsSummary", {tribeName = destinationState.name})

    local relationshipSettings = world:getOrCreateTribeRelationsSettings(currentDestinationState.destinationID)
    --mj:log("relationshipSettings on update:", relationshipSettings)

    if currentDestinationState.clientID then
        uiStandardButton:setDisabled(allowStorageAreaItemUseToggleButton, false)
        uiStandardButton:setToggleState(allowStorageAreaItemUseToggleButton, relationshipSettings.allowItemUse)

        if relationshipSettings.allowItemUse and (not relationshipSettings.storageAlly) then
            notAlliedWarningIconView.hidden = false
        elseif notAlliedWarningIconView then
            notAlliedWarningIconView.hidden = true
        end

        local tipText = locale:get("tribeRelations_settings_allowStorageAreaItemUse_long")
        uiToolTip:remove(allowStorageAreaItemUseToggleButton.userData.backgroundView)
        uiToolTip:add(allowStorageAreaItemUseToggleButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), tipText, nil, vec3(0,-8,10), nil, allowStorageAreaItemUseToggleButton, tribeSettingsView)
    else
        uiStandardButton:setDisabled(allowStorageAreaItemUseToggleButton, true)
        uiStandardButton:setToggleState(allowStorageAreaItemUseToggleButton, false)

        local tipText = locale:get("tribeRelations_settings_shareStorage_notPlayer")
        uiToolTip:remove(allowStorageAreaItemUseToggleButton.userData.backgroundView)
        uiToolTip:add(allowStorageAreaItemUseToggleButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), tipText, nil, vec3(0,-8,10), nil, allowStorageAreaItemUseToggleButton, tribeSettingsView)
    end

    --uiStandardButton:setToggleState(allowStoringInStorageAreasToggleButton, relationshipSettings.allowStoringInStorageAreas)
    uiStandardButton:setToggleState(allowBedUseToggleButton, relationshipSettings.allowBedUse)
    uiStandardButton:setToggleState(treatAsThreatToggleButton, relationshipSettings.treatAsThreat)
    
end

function tribeRelationsSettingsView:updateDueToTribeRelationsSettingsChange() --we are visible, the caller has checked
    tribeRelationsSettingsView:update(currentDestinationState)
end

local function sendValueChange(valueKey, newValue)
    local relationshipSettings = world:getOrCreateTribeRelationsSettings(currentDestinationState.destinationID)
    --mj:log("relationshipSettings:", relationshipSettings, " valueKey:", valueKey, " newValue", newValue)
    if relationshipSettings[valueKey] ~= newValue and (not (relationshipSettings[valueKey] == nil and (not newValue))) then
        relationshipSettings[valueKey] = newValue
        --mj:log("sending relationshipSettings:", relationshipSettings)
        logicInterface:callServerFunction("changeTribeRelationsSetting", {
            tribeID = currentDestinationState.destinationID,
            key = valueKey,
            value = newValue or false,
        })
    end
end

function tribeRelationsSettingsView:didBecomeVisible()
    
end

function tribeRelationsSettingsView:load(tribeSettingsView_, world_, logicInterface_)
    world = world_
    tribeSettingsView = tribeSettingsView_
    logicInterface = logicInterface_
    tribeSettingsSummaryTextView = TextView.new(tribeSettingsView)
    tribeSettingsSummaryTextView.font = Font(uiCommon.fontName, 18)
    tribeSettingsSummaryTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    tribeSettingsSummaryTextView.color = mj.textColor
    tribeSettingsSummaryTextView.baseOffset = vec3(0,-20, 0)

    local yOffset = -60
    local yOffsetBetweenElements = 40

    local elementTitleX = -tribeSettingsView.size.x * 0.5
    local elementControlX =  tribeSettingsView.size.x * 0.5 + 10.0
    
    local function addToggleButton(toggleButtonTitle, tipText, isRed, changedFunction)

        local textColor = mj.textColor
        if isRed then
            textColor = vec4(1.0,0.5,0.5,1.0)
        end

        local toggleButton = uiStandardButton:create(tribeSettingsView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        toggleButton.baseOffset = vec3(elementControlX, yOffset + 4, 0)
       -- uiStandardButton:setToggleState(toggleButton, toggleValue)

        if isRed then
            uiStandardButton:setToggleButtonHighlightMaterial(toggleButton, material.types.ui_red.index)
        end
        
        local textView = TextView.new(tribeSettingsView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.color = textColor
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,yOffset, 0)
        textView.text = toggleButtonTitle

        uiToolTip:add(toggleButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), tipText, nil, vec3(0,-8,10), nil, toggleButton, tribeSettingsView)

    
        if changedFunction then
            uiStandardButton:setClickFunction(toggleButton, function()
                changedFunction(uiStandardButton:getToggleState(toggleButton))
            end)
        end

        yOffset = yOffset - yOffsetBetweenElements

        return toggleButton, textView
    end

    allowStorageAreaItemUseToggleButton = addToggleButton(locale:get("tribeRelations_settings_allowStorageAreaItemUse_short") .. ":", locale:get("tribeRelations_settings_allowStorageAreaItemUse_long"), false, function(toggleValue)
        sendValueChange("allowItemUse", toggleValue)
    end)


    local warningHalfSize = 10.0
    notAlliedWarningIconView = ModelView.new(tribeSettingsView)
    notAlliedWarningIconView.relativeView = allowStorageAreaItemUseToggleButton
    notAlliedWarningIconView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    notAlliedWarningIconView.baseOffset = vec3(5.0, 0.0,0.0)
    notAlliedWarningIconView.scale3D = vec3(warningHalfSize,warningHalfSize,warningHalfSize)
    notAlliedWarningIconView.size = vec2(warningHalfSize, warningHalfSize) * 2.0
    notAlliedWarningIconView.hidden = true
    notAlliedWarningIconView:setModel(model:modelIndexForName("icon_warning"), {
        default = material.types.ui_standard.index
    })
    uiToolTip:add(notAlliedWarningIconView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("tribeRelations_settings_shareStorage_notAllied"), nil, vec3(0,-10,10), nil, notAlliedWarningIconView, tribeSettingsView)

    --[[allowStoringInStorageAreasToggleButton = addToggleButton(locale:get("tribeRelations_settings_allowStoringInStorageAreas_short") .. ":", locale:get("tribeRelations_settings_allowStoringInStorageAreas_long"), function(toggleValue)
        sendValueChange("allowStoringInStorageAreas", toggleValue)
    end)]]

    allowBedUseToggleButton = addToggleButton(locale:get("tribeRelations_settings_allowBedUse_short") .. ":", locale:get("tribeRelations_settings_allowBedUse_long"), false, function(toggleValue)
        sendValueChange("allowBedUse", toggleValue)
    end)
    
    treatAsThreatToggleButton = addToggleButton(locale:get("tribeRelations_settings_treatAsThreat_short") .. ":", locale:get("tribeRelations_settings_treatAsThreat_long"), true, function(toggleValue)
        sendValueChange("treatAsThreat", toggleValue)
    end)
end

return tribeRelationsSettingsView