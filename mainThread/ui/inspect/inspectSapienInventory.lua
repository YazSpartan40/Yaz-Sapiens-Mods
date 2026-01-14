



local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local locale = mjrequire "common/locale"


local inspectSapienInventory = {}

--local inspectFollowerUI = nil
--local world = nil

local loadingTextView = nil
local inspectUI = nil


function inspectSapienInventory:init(inspectUI_, inspectFollowerUI_, world_, containerView)
    inspectUI = inspectUI_

    loadingTextView = TextView.new(containerView)
    loadingTextView.font = Font(uiCommon.fontName, 24)
    loadingTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    loadingTextView.color = mj.textColor
    loadingTextView.text = locale:get("misc_WIP_Panel")
end

function inspectSapienInventory:show(sapien)
    local sharedState = sapien.sharedState
    local sapienName = sharedState.name
    inspectUI:setModalPanelTitleAndObject(sapienName, sapien, " - " .. locale:get("sapien_ui_inventory"))
end

function inspectSapienInventory:setBackFunction(backFunction)
end


function inspectSapienInventory:hide()
end


return inspectSapienInventory