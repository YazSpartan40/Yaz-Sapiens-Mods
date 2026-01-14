local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4


--local sapienConstants = mjrequire "common/sapienConstants"
local locale = mjrequire "common/locale"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
--local playerSapiens = mjrequire "mainThread/playerSapiens"
--local logicInterface = mjrequire "mainThread/logicInterface"


local inspectSapienRelationshipsView = {}

--local inspectFollowerUI = nil
--local world = nil
local inspectUI = nil

local mainView = nil
local tableView = nil
local loadingTextView = nil


function inspectSapienRelationshipsView:init(inspectUI_, inspectFollowerUI_, world_, containerView)
    inspectUI = inspectUI_
    --inspectFollowerUI = inspectFollowerUI_
    --world = world_
    
    loadingTextView = TextView.new(containerView)
    loadingTextView.font = Font(uiCommon.fontName, 24)
    loadingTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    loadingTextView.color = mj.textColor
    loadingTextView.text = locale:get("misc_WIP_Panel")

    mainView = View.new(containerView)
    mainView.size = vec2(containerView.size.x - 80, containerView.size.y - 140.0)
    mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    mainView.baseOffset = vec3(0,-60,0)
    
    tableView = View.new(mainView)
    tableView.size = mainView.size
    tableView.baseOffset = vec3(0,-40,0)
    tableView.hidden = true
    
end


--[[
local function update(sapien, relationships)
    tableView:removeAllSubviews()
    tableView.hidden = false

    local totalHeight = 0
    local relativeView = tableView
    local relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)

    local relationshipInfosByID = relationships

    local function sortScore(a,b)
        return a.info.bond.long > b.info.bond.long
    end
    
    local orderedScores = {}
    for otherID,relationshipInfo in pairs(relationshipInfosByID) do
        table.insert(orderedScores, {
            uniqueID = otherID,
            info = relationshipInfo,
        })
    end


    table.sort(orderedScores, sortScore)

    for i,infoAndID in ipairs(orderedScores) do
        local relationshipInfo = infoAndID.info
        local otherSapienID = infoAndID.uniqueID

        local otherSapienInfo = playerSapiens:getInfo(otherSapienID)
        if otherSapienInfo and otherSapienInfo.sharedState then
            local otherSapienSharedState = otherSapienInfo.sharedState
            local relationshipView = View.new(tableView)
            relationshipView.relativePosition = relativePosition
            relationshipView.relativeView = relativeView
            relationshipView.size = vec2(tableView.size.x * 0.5,30)

            local textView = TextView.new(relationshipView)
            textView.font = Font(uiCommon.fontName, 16)
            textView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            textView.baseOffset = vec3(0,0, 0)
            local textValue = otherSapienSharedState.name

            if relationshipInfo.familyRelationshipType then
                if relationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.mother then
                    textValue = textValue .. " (Mother)"
                elseif relationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.father then
                    textValue = textValue .. " (Father)"
                elseif relationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.sibling then
                    textValue = textValue .. " (Sibling)"
                elseif relationshipInfo.familyRelationshipType == sapienConstants.familyRelationshipTypes.biologicalChild then
                    if otherSapienSharedState.isFemale then
                        textValue = textValue .. " (Daughter)"
                    else
                        textValue = textValue .. " (Son)"
                    end
                end
            end
            
            textView.text = textValue


            local values = {
                relationshipInfo.mood.short * 100,
                relationshipInfo.mood.long * 100,
                relationshipInfo.bond.short * 100,
                relationshipInfo.bond.long * 100,
            }

            for j=1,4 do
                local valueTextView = TextView.new(relationshipView)
                valueTextView.font = Font(uiCommon.fontName, 16)
                valueTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
                valueTextView.baseOffset = vec3(100 + j * 50,0, 0)
                local valueTextValue = mj:tostring(math.floor(values[j])) .. "%"
                valueTextView.text = valueTextValue
            end
            
            ]]

            --[[if sapienState.relationships.motherID == otherSapienID then
                textValue = textValue .. " (Mother)"
            elseif otherSapienSharedState.relationships.motherID == sapien.uniqueID then
                if otherSapienSharedState.isFemale then
                    textValue = textValue .. " (Daughter)"
                else
                    textValue = textValue .. " (Son)"
                end
            else
                for j,siblingID in ipairs(sapienState.relationships.siblingIDs) do
                    if siblingID == otherSapienID then
                        textValue = textValue .. " (Sibling)"
                        break
                    end
                end
            end]]

--[[
            totalHeight = totalHeight + relationshipView.size.y

            relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
            relativeView = relationshipView
        end
    end
end]]

--local requestedSapienID = nil

function inspectSapienRelationshipsView:show(sapien)
    
    local sharedState = sapien.sharedState
    local sapienName = sharedState.name
    inspectUI:setModalPanelTitleAndObject(sapienName, sapien, " - " .. locale:get("sapien_ui_relationships"))

   --[[ loadingTextView.hidden = false
    loadingTextView.text = "..."
    local sapienID = sapien.uniqueID
    requestedSapienID = sapienID
    tableView.hidden = true
    
    logicInterface:callServerFunction("getRelationships", requestedSapienID, function(relationships)
        if requestedSapienID == sapienID then
            if relationships then
                loadingTextView.hidden = true
                update(sapien, relationships)
            else
                loadingTextView.text = "Error"
            end
        end
    end)]]

    
    --update(sapien, sapien.sharedState.relationships) --todo get from server
end

function inspectSapienRelationshipsView:setBackFunction(backFunction)
end

function inspectSapienRelationshipsView:hide()
end

return inspectSapienRelationshipsView