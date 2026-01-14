local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"

local gameUI = nil

local cinematicCameraUI = {}

local mainView = nil
local titleView = nil
local statusTextView = nil
local controlsView = nil

local recordingPathIndex = nil


local controlsLines = {
    {
        {
            text = locale:get("key_cinematicCamera_nextKeyframe"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "nextKeyframe",
                    }
                },
            }
        },
    },
    {
        {
            text = locale:get("key_cinematicCamera_prevKeyframe"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "prevKeyframe",
                    }
                },
            }
        },
    },
    {
        {
            text = locale:get("key_cinematicCamera_insertKeyframe"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "insertKeyframe",
                    }
                },
            }
        },
    },
    {
        {
            text = locale:get("key_cinematicCamera_saveKeyframe"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "saveKeyframe",
                    }
                },
            }
        },
    },
    {
        {
            text = locale:get("key_cinematicCamera_removeKeyframe"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "removeKeyframe",
                    }
                },
            }
        },
    },
    {
        {
            text = locale:get("key_cinematicCamera_increaseKeyframeDuration"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "increaseKeyframeDuration",
                    }
                },
            }
        },
    },
    {
        {
            text = locale:get("key_cinematicCamera_decreaseKeyframeDuration"),
        },
        {
            keyboardController = {
                keyboard = {
                    keyImage = {
                        groupKey = "cinematicCamera", 
                        mappingKey = "decreaseKeyframeDuration",
                    }
                },
            }
        },
    },
}

local controlsHeight = 0.0
local controlsWidth = 0.0

local function updateBackgroundSize()
    local maxWidth = math.max(titleView.size.x, controlsWidth)
    local height = titleView.size.y

    if not statusTextView.hidden then
        maxWidth = math.max(maxWidth, statusTextView.size.x)
        height = height + statusTextView.size.y
    end

    height = height + controlsHeight

    mainView.size = vec2(maxWidth + 20,height + 20)
    local panelScale = vec2(mainView.size.x * 0.5, mainView.size.y * 0.5 / 0.2)
    mainView.scale3D = vec3(panelScale.x, panelScale.y, 30.0)
end

function cinematicCameraUI:load(gameUI_)
    gameUI = gameUI_

end

function cinematicCameraUI:doLoad()
    mainView = ModelView.new(gameUI.view)
    mainView:setModel(model:modelIndexForName("ui_panel_10x2"))
    mainView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    mainView.baseOffset = vec3(-24,-16)
    mainView.size = vec2(gameUI.view.size.x * 0.5,90)
    mainView.alpha = 0.9
    mainView.hidden = true
    
    local font = Font(uiCommon.fontName, 18)

    titleView = TextView.new(mainView)
    titleView.font = font
    titleView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    titleView.baseOffset = vec3(-10,-10, 0)
    titleView.textAlignment = MJHorizontalAlignmentRight

    statusTextView = TextView.new(mainView)
    statusTextView.font = font
    statusTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    statusTextView.relativeView = titleView

    controlsView = View.new(mainView)
    controlsView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
    controlsView.relativeView = statusTextView

    local relativeView = nil

    for i, line in ipairs(controlsLines) do
        local titleComplexView = uiComplexTextView:create(controlsView, line, nil)
        if relativeView then
            titleComplexView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBelow)
            titleComplexView.relativeView = relativeView
        else
            titleComplexView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        end
        titleComplexView.baseOffset = vec3(0,-8,0)
        relativeView = titleComplexView
        controlsHeight = controlsHeight + titleComplexView.size.y + 8
        controlsWidth = math.max(titleComplexView.size.x, controlsWidth)
    end
end

local function update(recordingPath, recordingFrameIndex, statusText, duration)
    titleView.text = string.format("Editing camera path: %d\nkeyframe: %d/%d\nduration: %.1f", recordingPathIndex, recordingFrameIndex, #recordingPath, duration)
    if statusText then
        statusTextView.text = statusText
        statusTextView.hidden = false
        controlsView.relativeView = statusTextView
    else
        statusTextView.hidden = true
        controlsView.relativeView = titleView
    end
    updateBackgroundSize()
end


function cinematicCameraUI:show(recordingPathIndex_, recordingPath, recordingFrameIndex, statusText, duration)
    if not mainView then
        cinematicCameraUI:doLoad()
    end
    
    recordingPathIndex = recordingPathIndex_
    update(recordingPath, recordingFrameIndex, statusText, duration)
    mainView.hidden = false
        
end

function cinematicCameraUI:update(recordingPath, recordingFrameIndex, statusText, duration)
    update(recordingPath, recordingFrameIndex, statusText, duration)
end

function cinematicCameraUI:hide()
    if mainView then
        mainView.hidden = true
    end
end

return cinematicCameraUI