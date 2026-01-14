local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local locale = mjrequire "common/locale"
local eventManager = mjrequire "mainThread/eventManager"
local model = mjrequire "common/model"
--[[local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local material = mjrequire "common/material"
local research = mjrequire "common/research"]]
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"

local contextualTipUI = {}

local gameUI = nil
local mainView = nil
local panelView = nil
local titleTextView = nil

local currentTipTypeIndex = nil


local panelXOffset = 20.0
local baseYOffset = 20.0
--local slideAnimationOffset = -500.0
local panelBaseZOffset = -4

local line_place = {
    {
        text = locale:get("buildContext_placeTitle"),
    },
    {
        icon = "icon_leftMouse"
    },
    {
        text = locale:get("tutorial_or"),
    },
    {
        keyboardController = {
            keyboard = {
                keyImage = {
                    groupKey = "building", 
                    mappingKey = "confirm",
                }
            },
            controller = {
                controllerImage = {
                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                    controllerActionName = "confirm"
                }
            },
        }
    },
}
local line_refine = {
    {
        text = locale:get("buildContext_placeRefine"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "adjustmentModifier",
        },
    },
    {
        text = "+",
    },
    {
        text = locale:get("buildContext_place"),
    },
    --[[{
        icon = "icon_leftMouse"
    },
    {
        text = locale:get("tutorial_or"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "confirm",
        },
        --[[controller = {
            controllerSetIndex = eventManager.controllerSetIndexInGame,
            controllerActionName = "buildMenu"
        },
    },]]
}

local line_placeWithoutBuild = {
    {
        text = locale:get("buildContext_placeWithoutBuild"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "noBuildOrderModifier",
        },
    },
    {
        text = "+",
    },
    {
        text = locale:get("buildContext_place"),
    },
   --[[ {
        icon = "icon_leftMouse"
    },
    {
        text = locale:get("tutorial_or"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "confirm",
        },
        --[[controller = {
            controllerSetIndex = eventManager.controllerSetIndexInGame,
            controllerActionName = "buildMenu"
        },
    },]]
}

local line_cancel = {
    {
        text = locale:get("buildContext_cancel"),
    },
    {
        keyboardController = {
            keyboard = {
                keyImage = {
                    groupKey = "building", 
                    mappingKey = "cancel",
                }
            },
            controller = {
                controllerImage = {
                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                    controllerActionName = "cancel"
                }
            },
        },
    },
}

local line_rotate = {
    {
        text = locale:get("buildContext_rotate"),
    },
    {
        icon = "icon_rightMouse"
    },
}

local line_rotate_pointAndClickMode = {
    {
        text = locale:get("buildContext_rotate"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "zAxisModifier",
        },
    },
    {
        text = "+",
    },
    {
        icon = "icon_rightMouse"
    },
}

local line_rotate90 = {
    {
        text = locale:get("buildContext_rotate90"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "rotateX",
        },
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "rotateY",
        },
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "rotateZ",
        },
    },
}

local line_moveXZ = {
    {
        text = locale:get("buildContext_moveXZ"),
    },
    {
        icon = "icon_middleMouse"
    },
}

local line_moveY = {
    {
        text = locale:get("buildContext_moveY"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "zAxisModifier",
        },
    },
    {
        text = "+",
    },
    {
        icon = "icon_middleMouse"
    },
}

local line_disableSnapping = {
    {
        text = locale:get("buildContext_disableSnapping"),
    },
    {
        keyImage = {
            groupKey = "building", 
            mappingKey = "zAxisModifier",
        },
    },
}

contextualTipUI.types = mj:indexed({
    {
        key = "buildContext",
        title = locale:get("buildContext_title"),
        lines = {
            line_place,
            line_refine,
            line_placeWithoutBuild,
            line_cancel,
            line_rotate,
            line_rotate90,
            line_moveXZ,
            line_moveY,
            line_disableSnapping,
        },
    },
    {
        key = "buildContext_pointAndClickMode",
        title = locale:get("buildContext_title"),
        lines = {
            line_place,
            line_refine,
            line_placeWithoutBuild,
            line_cancel,
            line_rotate_pointAndClickMode,
            line_rotate90,
            line_moveY,
            line_disableSnapping,
        },
    },
})

local function createPanel()
    if panelView then
        mainView:removeSubview(panelView)
        panelView = nil
    end

    local tipType = contextualTipUI.types[currentTipTypeIndex]

    panelView = ModelView.new(mainView)
    panelView:setModel(model:modelIndexForName("ui_panel_10x2"))
    panelView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    panelView.alpha = 0.9

    titleTextView = TextView.new(panelView)
    titleTextView.font = Font(uiCommon.fontName, 20)
    titleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    titleTextView.baseOffset = vec3(20,-20,0)
    titleTextView.text = tipType.title

    local panelHeight = titleTextView.size.y + 40

    local itemOffsetY = 0
    local maxLineWidth = 0
    local linePadding = 10.0

    for i, line in ipairs(tipType.lines) do
        local titleComplexView = uiComplexTextView:create(panelView, line, nil)
        titleComplexView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        titleComplexView.baseOffset = vec3(20.0,-56.0 - itemOffsetY,0.0)

        maxLineWidth = math.max(maxLineWidth, titleComplexView.size.x)
        itemOffsetY = itemOffsetY + titleComplexView.size.y + linePadding
    end

    
    panelHeight = panelHeight + itemOffsetY + 20.0 - linePadding
    
    local panelWidth = math.max(maxLineWidth, titleTextView.size.x) + 40.0
    --local panelHeight = titleTextView.size.y + 40-- + #tipType.lines * 26

    panelView.size = vec2(panelWidth, panelHeight)
    local panelScale = vec2(panelView.size.x * 0.5, panelView.size.y * 0.5 / 0.2)
    panelView.scale3D = vec3(panelScale.x, panelScale.y, 30.0)


    panelView.baseOffset = vec3(panelXOffset, baseYOffset, panelBaseZOffset)
           
end

function contextualTipUI:show(tipTypeIndex)
    if tipTypeIndex ~= currentTipTypeIndex then
        currentTipTypeIndex = tipTypeIndex
        createPanel()
    end
    mainView.hidden = false
end

function contextualTipUI:hide()
    mainView.hidden = true
end

function contextualTipUI:init(gameUI_)
    gameUI = gameUI_

    mainView = View.new(gameUI.view)
    mainView.size = gameUI.view.size
    mainView.hidden = true
end

return contextualTipUI