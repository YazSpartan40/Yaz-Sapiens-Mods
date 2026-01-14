local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

local terrainTypes = mjrequire "common/terrainTypes"
local plan = mjrequire "common/plan"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"

local inspectTerrainFillSelectionUI = mjrequire "mainThread/ui/inspect/inspectTerrainFillSelectionUI"

local inspectTerrainUI = {}

local inspectUI = nil

local terrainDetailView = nil

local terrainFillSelectionContainerView = nil

local extraInfoViews = {}


function inspectTerrainUI:updateVertInfo()
    for i=1,4 do
        extraInfoViews[i].hidden = true
    end
    
    local vertInfo = inspectUI.baseObjectOrVertInfo

    if inspectUI.selectedObjectOrVertInfoCount > 1 then
        local objectName = terrainTypes:getMultiLookAtName(inspectUI.selectedObjectOrVertInfosByID, false)
        inspectUI:setTitleText(objectName, false)
    else
        local objectName = terrainTypes:getLookAtName(vertInfo)
        inspectUI:setTitleText(objectName, false)
    end
end

function inspectTerrainUI:load(gameUI, inspectUI_, world)

    inspectUI = inspectUI_

    local containerView = inspectUI.containerView
    terrainDetailView = View.new(containerView)
    terrainDetailView.size = containerView.size
    terrainDetailView.hidden = true

    
    
    terrainFillSelectionContainerView = View.new(inspectUI.modalPanelView)
    inspectTerrainUI.terrainFillSelectionContainerView = terrainFillSelectionContainerView
    terrainFillSelectionContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    terrainFillSelectionContainerView.size = inspectUI.modalPanelView.size
    terrainFillSelectionContainerView.hidden = true

    inspectTerrainFillSelectionUI:load(inspectUI, inspectTerrainUI, world, terrainFillSelectionContainerView)
    
    for i=1,4 do
        extraInfoViews[i] = TextView.new(terrainDetailView)
        extraInfoViews[i].font = Font(uiCommon.fontName, 16)
        extraInfoViews[i].color = mj.textColor
        extraInfoViews[i].hidden = true
    end
    
    extraInfoViews[1].relativeView = inspectUI.gameObjectView
    extraInfoViews[1].relativePosition = ViewPosition(MJPositionOuterRight, MJPositionTop)
    extraInfoViews[1].baseOffset = vec3(10,-20, 0)

    for i=2,4 do
        extraInfoViews[i].relativeView = extraInfoViews[i - 1]
        extraInfoViews[i].relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
    end
end


function inspectTerrainUI:showInspectPanelForActionUIOptionsButton(planTypeIndex)
    if planTypeIndex == plan.types.fill.index then
        inspectTerrainFillSelectionUI:show()
        inspectUI:showModalPanelView(terrainFillSelectionContainerView, inspectTerrainFillSelectionUI)
    --elseif planTypeIndex == plan.types.defend.index then
        --todo
    end
end

function inspectTerrainUI:show(baseVertInfo, allVertInfos)
    terrainDetailView.hidden = false

    inspectUI:setIconForTerrain(baseVertInfo)
    
    inspectTerrainUI:updateVertInfo()
end


function inspectTerrainUI:hide()
    if not terrainDetailView.hidden then
        terrainDetailView.hidden = true
    end
end


return inspectTerrainUI