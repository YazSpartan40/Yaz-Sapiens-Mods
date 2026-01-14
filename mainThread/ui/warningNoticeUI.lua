local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local material = mjrequire "common/material"
local model = mjrequire "common/model"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"

local warningNoticeUI = {}

local titleIconHalfSize = 20

local topView = nil
local titleView = nil
local titleGameObjectView = nil
local subTitleView = nil

local function updateSubtitle(subtitleTextOrNil, colorOrNil) --if color changes but not text, it's currently ignored.
    local maxWidth = math.max(200, titleView.size.x + 30 + titleIconHalfSize * 2.0)
    local height = titleView.size.y + 10

    if subtitleTextOrNil then
        subTitleView.hidden = false
        subTitleView.text = subtitleTextOrNil
        subTitleView.color = colorOrNil or mj.textColor
        maxWidth = math.max(maxWidth, subTitleView.size.x + 20)
        height = height + subTitleView.size.y
    else
        subTitleView.hidden = true
    end
    
    local sizeToUse = vec2(maxWidth, height)

    local scaleToUseX = sizeToUse.x * 0.5
    local scaleToUseY = sizeToUse.y * 0.5 / 0.4
    topView.scale3D = vec3(scaleToUseX,scaleToUseY,scaleToUseX)
    topView.size = sizeToUse
end

function warningNoticeUI:show()
    if topView.hidden then
        topView.hidden = false
        
        titleView:setText("Too far from tribe", material.types.standardText.index)
        updateSubtitle("Move a sapien out here to explore further", material:getUIColor(material.types.warning.index))
    end
end

function warningNoticeUI:hide()
    if not topView.hidden then
        topView.hidden = true
    end
end

function warningNoticeUI:hidden()
    return topView.hidden
end

function warningNoticeUI:setTopOffset(topOffsetForWarningNotice)
    topView.baseOffset = vec3(0, -20 + topOffsetForWarningNotice, 0)
end

function warningNoticeUI:removeTopOffset()
    topView.baseOffset = vec3(0, -20, 0)
end

function warningNoticeUI:init(gameUI)
    topView = ModelView.new(gameUI.worldViews)
    topView:setModel(model:modelIndexForName("ui_panel_10x4"))
    topView.hidden = true;
    topView.alpha = 0.9
    topView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    topView.baseOffset = vec3(0, -20, 0)

    titleView = ModelTextView.new(topView)
    titleView.font = Font(uiCommon.fontName, 36)
    titleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    titleView.baseOffset = vec3(titleIconHalfSize, -6, 0)
    
    titleGameObjectView = uiGameObjectView:create(topView, vec2(titleIconHalfSize,titleIconHalfSize) * 2.0, uiGameObjectView.types.standard)
    titleGameObjectView.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    titleGameObjectView.relativeView = titleView
    titleGameObjectView.baseOffset = vec3(-5,0,0)
    
    uiGameObjectView:setModelName(titleGameObjectView, "icon_tribe2", nil)

    subTitleView = TextView.new(topView)
    subTitleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    subTitleView.relativeView = titleView
    subTitleView.font = Font(uiCommon.fontName, 16)
    subTitleView.color = mj.textColor
    subTitleView.hidden = true
    subTitleView.baseOffset = vec3(-titleIconHalfSize, 0, 0)
end

return warningNoticeUI