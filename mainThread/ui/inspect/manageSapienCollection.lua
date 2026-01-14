local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local locale = mjrequire "common/locale"

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"


local inspectSapienTasks = mjrequire "mainThread/ui/inspect/inspectSapienTasks"
local inspectSapienInventory = mjrequire "mainThread/ui/inspect/inspectSapienInventory"
local inspectSapienRelationshipsView = mjrequire "mainThread/ui/inspect/inspectSapienRelationshipsView"

local manageSapienCollection = {}

local tabSize = uiStandardButton.standardTabSize
local tabPadding = uiStandardButton.standardTabPadding

local currentModeIndex = nil
--local inspectUI = nil
local currentSapien = nil

local modeTypes = mj:enum {
    "roles",
    "inventory",
    "relationships",
}

local tabCount = #modeTypes

manageSapienCollection.modeTypes = modeTypes

local modeInfos = {
    [modeTypes.roles] = {
        title = locale:get("sapien_ui_roles"),
        icon = "icon_tasks",
    },
    [modeTypes.inventory] = {
        title = locale:get("sapien_ui_inventory"),
        icon = "icon_store",
    },
    [modeTypes.relationships] = {
        title = locale:get("sapien_ui_relationships"),
        icon = "icon_tribe",
    },
}

local uiObjectsByModeType = {
    [modeTypes.roles] = inspectSapienTasks,
    [modeTypes.inventory] = inspectSapienInventory,
    [modeTypes.relationships] = inspectSapienRelationshipsView,
}

local function switchTabs(modeIndex)
    if currentModeIndex ~= modeIndex then
        if currentModeIndex then
            local currentInfo = modeInfos[currentModeIndex]
            currentInfo.contentView.hidden = true

            uiObjectsByModeType[currentModeIndex]:hide()

            uiStandardButton:setSelected(currentInfo.tabButton, false)
            local prevOffset = currentInfo.tabButton.baseOffset
            currentInfo.tabButton.baseOffset = vec3(prevOffset.x, prevOffset.y, uiCommon.unSelectedTabZOffset)

        end

        currentModeIndex = modeIndex

        local currentInfo = modeInfos[currentModeIndex]
        currentInfo.contentView.hidden = false
        
        uiStandardButton:setSelected(currentInfo.tabButton, true)
        local prevOffset = currentInfo.tabButton.baseOffset
        currentInfo.tabButton.baseOffset = vec3(prevOffset.x, prevOffset.y, uiCommon.selectedTabZOffset)

        --if not inspectUI:containerViewIsHidden(currentInfo.contentView) then
            --uiObjectsByModeType[currentModeIndex]:update()
        --end
        
        if currentSapien then
            uiObjectsByModeType[currentModeIndex]:show(currentSapien)
        end
    end
end

function manageSapienCollection:show(sapien)
    
    --mj:log("manageSapienCollection:show")
    
    --local sharedState = sapien.sharedState
   -- local sapienName = sharedState.name
   -- inspectUI:setModalPanelTitleAndObject(sapienName .. " - " .. modeInfos[currentModeIndex].title, sapien)

    currentSapien = sapien
    uiObjectsByModeType[currentModeIndex]:show(currentSapien)
end

function manageSapienCollection:setBackFunction(backFunction)
    uiObjectsByModeType[currentModeIndex]:setBackFunction(backFunction)
end

function manageSapienCollection:init(inspectUI_, inspectFollowerUI_, world_, contentView)

    --inspectUI = inspectUI_
    
    local rolesContentView = View.new(contentView)
    rolesContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    rolesContentView.size = vec2(contentView.size.x, contentView.size.y)
    rolesContentView.hidden = true
    inspectSapienTasks:init(inspectUI_, inspectFollowerUI_, world_, rolesContentView)
    
    local inventoryContentView = View.new(contentView)
    inventoryContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    inventoryContentView.size = vec2(contentView.size.x, contentView.size.y)
    inventoryContentView.hidden = true
    inspectSapienInventory:init(inspectUI_, inspectFollowerUI_, world_, inventoryContentView)
    
    local relationshipsContentView = View.new(contentView)
    relationshipsContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    relationshipsContentView.size = vec2(contentView.size.x, contentView.size.y)
    relationshipsContentView.hidden = true
    inspectSapienRelationshipsView:init(inspectUI_, inspectFollowerUI_, world_, relationshipsContentView)


    local function addTabButton(buttonIndex, modeInfo)
        local tabButton = uiStandardButton:create(contentView, tabSize, uiStandardButton.types.tabTitle, nil)
        tabButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionAbove)

        local xOffset = (tabCount * -0.5 + (buttonIndex - 1) + 0.5) * (tabSize.x + tabPadding)
        local zOffset = uiCommon.unSelectedTabZOffset
        if buttonIndex == 1 then
            zOffset = uiCommon.selectedTabZOffset
            uiStandardButton:setSelected(tabButton, true)
        end

        tabButton.baseOffset = vec3(xOffset, 0, zOffset)
        uiStandardButton:setText(tabButton, modeInfo.title)
        uiStandardButton:setIconModel(tabButton, modeInfo.icon)
        
        uiStandardButton:setClickFunction(tabButton, function()
            switchTabs(buttonIndex)
        end)

        modeInfo.tabButton = tabButton
    end

    for i,v in ipairs(modeTypes) do
        addTabButton(i, modeInfos[i])
    end


    modeInfos[modeTypes.roles].contentView = rolesContentView
    modeInfos[modeTypes.inventory].contentView = inventoryContentView
    modeInfos[modeTypes.relationships].contentView = relationshipsContentView

    
    switchTabs(modeTypes.roles)
end


function manageSapienCollection:popUI()
    return false
end

return manageSapienCollection