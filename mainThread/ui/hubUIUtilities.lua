local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local approxEqualEpsilon = mjm.approxEqualEpsilon


local gameObject = mjrequire "common/gameObject"

local locale = mjrequire "common/locale"
local model = mjrequire "common/model"
local material = mjrequire "common/material"
local plan = mjrequire "common/plan"
local tool = mjrequire "common/tool"
local resource = mjrequire "common/resource"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local constructable = mjrequire "common/constructable"
local planHelper = mjrequire "common/planHelper"
local evolvingObject = mjrequire "common/evolvingObject"
local craftAreaGroup = mjrequire "common/craftAreaGroup"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"


local currentOrderCount = 0
local maxOrderCount = 0

local hubUIUtilities = {}

local planStatusSize = vec2(24.0,24.0)
local planStatusWarningSize = vec2(24.0,24.0)
local orderMarkerWarningIconYOffset = -0.1

function hubUIUtilities:createPlanInfoView(containerView)
    local planInfoView = View.new(containerView)
    planInfoView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    local viewTable = {}
    planInfoView.userData = viewTable

    local iconBackgroundView = ModelView.new(planInfoView)
    iconBackgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    iconBackgroundView.baseOffset = vec3(0, 4, 4)
    iconBackgroundView.hidden = true
    
    local icon = ModelView.new(iconBackgroundView)
    icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)

    
    local logoHalfSize = planStatusWarningSize.x * 0.5
    local gameObjectView = uiGameObjectView:create(iconBackgroundView, vec2(logoHalfSize,logoHalfSize), uiGameObjectView.types.standard)
    gameObjectView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    gameObjectView.baseOffset = vec3(0.0,0.0, 0.1)
    gameObjectView.hidden = true
    gameObjectView.masksEvents = false

    local planInfoTextView = TextView.new(planInfoView)
    planInfoTextView.font = Font(uiCommon.fontName, 16)
    planInfoTextView.baseOffset = vec3(0,-2,0)
    planInfoTextView.relativeView = iconBackgroundView
    planInfoTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)

    viewTable.planInfoTextView = planInfoTextView
    viewTable.iconBackgroundView = iconBackgroundView
    viewTable.icon = icon
    viewTable.gameObjectView = gameObjectView

    return planInfoView
end

function hubUIUtilities:orderCountsChanged(currentOrderCount_, maxOrderCount_)
    currentOrderCount = currentOrderCount_
    maxOrderCount = maxOrderCount_
end

function hubUIUtilities:onlyDisabledDueToOrderLimit(planStateOrInfo)
    if planStateOrInfo.disabledDueToOrderLimit then
        if planStateOrInfo.tooDark then
            return false
        end
        if planStateOrInfo.inaccessible then
            return false
        end
        if planStateOrInfo.needsLit then
            return false
        end
        if planStateOrInfo.missingTools then
            return false
        end
        if planStateOrInfo.missingResources then
            return false
        end
        if planStateOrInfo.missingStorage then
            return false
        end
        if planStateOrInfo.missingCraftArea then
            return false
        end
        if planStateOrInfo.missingSuitableTerrain then
            return false
        end
        if planStateOrInfo.missingShallowWater then
            return false
        end
        if planStateOrInfo.missingStorageAreaContainedObjects then
            return false
        end
        if planStateOrInfo.missingSkill then
            return false
        end
        if planStateOrInfo.terrainTooSteepFill then
            return false
        end
        if planStateOrInfo.invalidUnderWater then
            return false
        end
        if planStateOrInfo.terrainTooSteepDig then
            return false
        end
        if planStateOrInfo.tooDistant then
            return false
        end
        if planStateOrInfo.closeThreat then
            return false
        end
    end
    return false
end

function hubUIUtilities:getPlanProblemStrings(planStateOrInfo)
    local result = {}
    if planStateOrInfo.disabledDueToOrderLimit then
        table.insert(result, locale:get("lookatUI_disabledDueToOrderLimit") .. string.format(" (%d/%d)", currentOrderCount, maxOrderCount))
    end
    if planStateOrInfo.tooDark then
        table.insert(result, locale:get("lookatUI_tooDark"))
    end
    if planStateOrInfo.closeThreat then
        table.insert(result, locale:get("lookatUI_closeThreat"))
    end
    if planStateOrInfo.inaccessible then
        table.insert(result, locale:get("lookatUI_inaccessible"))
    end
    if planStateOrInfo.needsLit then
        table.insert(result, locale:get("lookatUI_needsLit"))
    end
    if planStateOrInfo.missingTools then
        local missingToolLocalizationInfos = {}
        for j, toolTypeIndex in ipairs(planStateOrInfo.missingTools) do
            table.insert(missingToolLocalizationInfos, {
                toolName = tool.types[toolTypeIndex].name,
                exampleObjectName = gameObject.types[tool.types[toolTypeIndex].displayGameObjectTypeIndex].name,
            })
        end
        
        local planInfoString = locale:get("lookatUI_needsTools", {missingToolInfos = missingToolLocalizationInfos})
        table.insert(result, planInfoString)

        --[[local planInfoString = locale:get("lookatUI_needs") .. " "
        for j, toolTypeIndex in ipairs(planStateOrInfo.missingTools) do
            planInfoString = planInfoString .. tool.types[toolTypeIndex].name .. " (eg. " .. gameObject.types[tool.types[toolTypeIndex].displayGameObjectTypeIndex].name .. ")"
            if j < #planStateOrInfo.missingTools then
                planInfoString = planInfoString .. ", "
            end
        end

        table.insert(result, planInfoString)]]
    end
    
    if planStateOrInfo.maintainQuantityThresholdMet then

        local resourceTypeIndex = nil
        local resourceGroupTypeIndex = nil
        local storedCount = 0
        local maintainCount = 0

        if planStateOrInfo.maintainQuantityOutputResourceCounts then
            for j,resourceInfo in ipairs(planStateOrInfo.maintainQuantityOutputResourceCounts) do
                if resourceInfo.nearbyCount and resourceInfo.nearbyCount >= resourceInfo.count then
                    resourceTypeIndex = resourceInfo.resourceTypeIndex
                    resourceGroupTypeIndex = resourceInfo.resourceGroupTypeIndex
                    storedCount = resourceInfo.nearbyCount
                    maintainCount = resourceInfo.count
                    break
                end
            end
        end

        
        if resourceTypeIndex or resourceGroupTypeIndex then
            local pluralName = nil
            if resourceTypeIndex then 
                pluralName = resource.types[resourceTypeIndex].pluralGeneric or resource.types[resourceTypeIndex].plural
            else
                pluralName = resource.groups[resourceGroupTypeIndex].plural
            end
            table.insert(result, locale:get("lookatUI_maintainQuantityThresholdMet", {
                storedCount = storedCount,
                maintainCount = maintainCount,
                resourcePlural = pluralName,
            }))
        else
            table.insert(result, locale:get("lookatUI_maintainQuantityThresholdMetNoData"))
        end

    end

    if planStateOrInfo.missingResources then
        local missingResourceStrings = {}
        for i,missingResourceInfo in ipairs(planStateOrInfo.missingResources) do
            local missingString = nil
            if missingResourceInfo.objectTypeIndex then
                missingString = gameObject:stringForObjectTypeAndCount(missingResourceInfo.objectTypeIndex, missingResourceInfo.requiredCount)
            elseif missingResourceInfo.group then
                missingString = resource:stringForResourceGroupTypeAndCount(missingResourceInfo.group, missingResourceInfo.requiredCount)
            else
                missingString = resource:stringForResourceTypeAndCount(missingResourceInfo.type, missingResourceInfo.requiredCount)
            end

            local constructableTypeIndex = planStateOrInfo.constructableTypeIndex
            if constructableTypeIndex then
                local requiredResources = constructable.types[constructableTypeIndex].requiredResources
                if requiredResources then
                    for j,requiredResourceInfo in ipairs(requiredResources) do
                        if requiredResourceInfo.count > 0 then
                            local match = false
                            if requiredResourceInfo.objectTypeIndex then
                                if requiredResourceInfo.objectTypeIndex == missingResourceInfo.objectTypeIndex then
                                    match = true
                                end
                            elseif missingResourceInfo.group then
                                if requiredResourceInfo.group then
                                    if requiredResourceInfo.group == missingResourceInfo.group then
                                        match = true
                                    end
                                else
                                    if resource:groupOrResourceMatchesResource(missingResourceInfo.group, requiredResourceInfo.type) then
                                        match = true
                                    end
                                end
                            else
                                if resource:groupOrResourceMatchesResource(requiredResourceInfo.type or requiredResourceInfo.group, missingResourceInfo.type) then
                                    match = true
                                end
                            end

                            if match then
                                missingString = missingString .. string.format(" (%d/%d)", missingResourceInfo.requiredCount - missingResourceInfo.missingCount, missingResourceInfo.requiredCount)
                                break
                            end
                        end
                    end
                end
            end
            
            table.insert(missingResourceStrings, missingString)
        end

        local planInfoString = locale:get("lookatUI_needsResources", {missingResources = missingResourceStrings})
        table.insert(result, planInfoString)
    end
    if planStateOrInfo.missingStorage then
        table.insert(result, locale:get("lookatUI_missingStorage"))
    end
    if planStateOrInfo.missingCraftArea then
        local firstGroup = nil
        if planStateOrInfo.requiresCraftAreaGroupTypeIndexes then
            firstGroup = planStateOrInfo.requiresCraftAreaGroupTypeIndexes[1]
        end
        if firstGroup == craftAreaGroup.types.campfire.index then
            table.insert(result, locale:get("lookatUI_missingCampfire"))
        elseif firstGroup == craftAreaGroup.types.kiln.index then
            table.insert(result, locale:get("lookatUI_missingKiln"))
        else
            table.insert(result, locale:get("lookatUI_missingCraftArea"))
        end
    end
    if planStateOrInfo.missingSuitableTerrain then
        table.insert(result, locale:get("lookatUI_missingSuitableTerrain"))
    end
    
    if planStateOrInfo.missingShallowWater then
        table.insert(result, locale:get("lookatUI_missingShallowWater"))
    end

    if planStateOrInfo.missingShallowWater then
        table.insert(result, locale:get("lookatUI_missingShallowWater"))
    end
    
    if planStateOrInfo.missingStorageAreaContainedObjects then
        table.insert(result, locale:get("lookatUI_missingStorageAreaContainedObjects"))
    end
    if planStateOrInfo.missingSkill then
        table.insert(result, locale:get("lookatUI_missingTaskAssignment", {
            taskName = skill.types[planStateOrInfo.missingSkill].name
        }))
    end
    if planStateOrInfo.terrainTooSteepFill then
        table.insert(result, locale:get("lookatUI_terrainTooSteepFill"))
    end
    if planStateOrInfo.invalidUnderWater then
        table.insert(result, locale:get("lookatUI_invalidUnderWater"))
    end
    if planStateOrInfo.terrainTooSteepDig then
        table.insert(result, locale:get("lookatUI_terrainTooSteepDig"))
    end

    --lookatUI_tooDistantWithRoleName
    
    if planStateOrInfo.tooDistant and (not planStateOrInfo.missingSkill) then
        local skillType = skill.types[planStateOrInfo.tooDistant] --lookatUI_tooDistantRequiresCapable
        if skillType then
            local added = false
            if planStateOrInfo.tooDistant == skill.types.researching.index then
                local researchTypeIndex = planStateOrInfo.researchTypeIndex
                if researchTypeIndex and research.types[researchTypeIndex].disallowsLimitedAbilitySapiens then
                    table.insert(result, locale:get("lookatUI_tooDistantRequiresCapable", {
                        taskName = skillType.name
                    }))
                    added = true
                end
            end
            
            if not added then
                table.insert(result, locale:get("lookatUI_tooDistantWithRoleName", {
                    taskName = skillType.name
                }))
            end
        else
            table.insert(result, locale:get("lookatUI_tooDistant"))
        end
    end
    
    return result
end

function hubUIUtilities:getPlanTitle(planState)
    local planInfoString = nil
    if planState.canComplete then
        planInfoString = plan.types[planState.planTypeIndex].inProgress
    else
        planInfoString = locale:get("misc_cantDoPlan", {planName = plan.types[planState.planTypeIndex].name})
    end

    if not planState.researchTypeIndex then
        local foundObjectText = false
        if planState.constructableTypeIndex then
            local constructableType = constructable.types[planState.constructableTypeIndex]

            if constructableType.actionText then
                if planState.canComplete then
                    planInfoString = constructableType.actionInProgressText
                end
                
                if planState.craftCount then
                    if planState.craftCount == -1 then
                        planInfoString = planInfoString .. string.format(" %s (%s)", constructableType.actionObjectNamePlural, locale:get("misc_continuous"))
                    elseif planState.maintainQuantityThresholdMet then
                        planInfoString = planInfoString .. " " .. constructableType.actionObjectNamePlural
                    elseif planState.maintainQuantityOutputResourceCounts then
                        local resourceInfo = planState.maintainQuantityOutputResourceCounts[1]

                        planInfoString = locale:get("lookatUI_maintainQuantityInProgress", {
                            actionInProgressName = planInfoString,
                            storedCount = resourceInfo.nearbyCount,
                            maintainCount = resourceInfo.count,
                            resourcePlural = constructableType.actionObjectNamePlural,
                        })
                    else
                        local outputDisplayCountMultiplier = (constructableType.outputDisplayCount or 1)
                        local countRemaining = planState.craftCount - planState.currentCraftIndex + 1
                        if countRemaining > 1 then
                            planInfoString = planInfoString .. string.format(" %d %s", countRemaining * outputDisplayCountMultiplier, constructableType.actionObjectNamePlural)
                        else
                            planInfoString = planInfoString .. " " .. constructableType.actionObjectName
                        end
                    end
                end
            else
                if planState.craftCount then
                    if planState.craftCount == -1 then
                        planInfoString = planInfoString .. string.format(" %s (%s)", constructableType.plural, locale:get("misc_continuous"))
                    elseif planState.maintainQuantityThresholdMet then
                        planInfoString = planInfoString .. " " .. constructableType.plural
                    elseif planState.maintainQuantityOutputResourceCounts then
                        local resourceInfo = planState.maintainQuantityOutputResourceCounts[1]

                        planInfoString = locale:get("lookatUI_maintainQuantityInProgress", {
                            actionInProgressName = planInfoString,
                            storedCount = resourceInfo.nearbyCount,
                            maintainCount = resourceInfo.count,
                            resourcePlural = constructableType.plural,
                        })
                    else
                        local outputDisplayCountMultiplier = (constructableType.outputDisplayCount or 1)

                        local countRemaining = planState.craftCount - planState.currentCraftIndex + 1
                        if countRemaining > 1 then
                            planInfoString = planInfoString .. string.format(" %d %s", countRemaining * outputDisplayCountMultiplier, constructableType.plural)
                        else
                            planInfoString = planInfoString .. " " .. constructableType.name
                        end
                    end
                end
            end

            foundObjectText = true
        end

        if not foundObjectText then
            local planObjectTypeIndex = planState.objectTypeIndex
            if planObjectTypeIndex then
                planInfoString = planInfoString .. " " .. gameObject.types[planObjectTypeIndex].plural
            end
        end
    end
    return planInfoString
end

function hubUIUtilities:updatePlanInfoView(planInfoView, currentIsTerrain, currentObjectInfo, tribeID)
    

    local function getMostImportantPlanState(objectInfo) --todo we are probably going to need to have one for each plan state
        if objectInfo.sharedState and objectInfo.sharedState.planStates then
            local planStatesForTribe = objectInfo.sharedState.planStates[tribeID]
            if planStatesForTribe and planStatesForTribe[1] then
                local planState = planStatesForTribe[1]

                if (not planState.canComplete) and planStatesForTribe[2] then
                    for i,otherPlanState in ipairs(planStatesForTribe) do
                        if otherPlanState.canComplete then
                            planState = otherPlanState
                            break
                        end
                    end
                end

                return planState
            end
        end
        return nil
    end
    
    local planState = nil
                
    if currentIsTerrain then
        local planObjectInfo = currentObjectInfo.planObjectInfo
        if planObjectInfo then
            planState = getMostImportantPlanState(planObjectInfo)
        end
    else
        planState = getMostImportantPlanState(currentObjectInfo)
    end

    if planState and planState.planTypeIndex then
        local planTypeIndex = planState.planTypeIndex

        --commented out below 11/25 as it's very shit. May need to be solved another way
       --[[ if planTypeIndex == plan.types.research.index and currentObjectInfo.objectTypeIndex and gameObject.types[currentObjectInfo.objectTypeIndex].isInProgressBuildObject then --could be far more generic safely, limiting it to target canoes only at present
            titleText = plan.types[planTypeIndex].inProgress
        end]]
        
        local planInfoString = hubUIUtilities:getPlanTitle(planState)
        local iconYOffset = 0.0

        local materialToUse = material.types.ok.index
        if not planState.canComplete then
            materialToUse = material.types.warning.index
           --[[ if not planState.disabledDueToOrderLimit then
                iconYOffset = planStatusWarningSize.x * orderMarkerWarningIconYOffset
            end]]

            local problems = hubUIUtilities:getPlanProblemStrings(planState)
            if problems and next(problems) then
                planInfoString = planInfoString .. ": "
                for i, problemString in ipairs(problems) do
                    planInfoString = planInfoString .. problemString .. ". "
                end
            end
        end

        local viewTable = planInfoView.userData
        local icon = viewTable.icon
        local gameObjectView = viewTable.gameObjectView
        local iconBackgroundView = viewTable.iconBackgroundView
        local planInfoTextView = viewTable.planInfoTextView

        local iconHalfSize = nil
        if not planState.canComplete then
            local modelName = "ui_order_warning"
            --[[if planState.disabledDueToOrderLimit then
                modelName = "ui_order_warningSquare"
            end]]
            iconBackgroundView:setModel(model:modelIndexForName(modelName), 
            {
                [material.types.warning.index] = materialToUse
            })
            local scaleToUse = planStatusWarningSize.x * 0.5
            iconBackgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
            iconBackgroundView.size = planStatusWarningSize
            iconHalfSize = planStatusWarningSize.x * 0.4 * 0.5
        else
            iconBackgroundView:setModel(model:modelIndexForName("ui_order"), {
                [material.types.ui_standard.index] = materialToUse
            })
            local scaleToUse = planStatusSize.x * 0.5
            iconBackgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
            iconBackgroundView.size = planStatusSize
            iconHalfSize = planStatusSize.x * 0.5 * 0.5
        end

        local iconObjectTypeIndex = planHelper:getIconObjectTypeIndexForPlanState(currentObjectInfo, planState)

        --mj:log("planState:", planState)

        if iconObjectTypeIndex then
            local objectInfo = {
                objectTypeIndex = iconObjectTypeIndex
            }

            uiGameObjectView:setObject(gameObjectView, objectInfo, nil, nil)
            gameObjectView.baseOffset = vec3(0, iconYOffset, 0.1)

            gameObjectView.hidden = false
            icon.hidden = true
        else
            icon.hidden = false
            gameObjectView.hidden = true
            icon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
            icon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
            icon:setModel(model:modelIndexForName(plan.types[planTypeIndex].icon or "icon_hand"), {
                default = materialToUse
            })
            icon.baseOffset = vec3(0, iconYOffset, 0.1)
        end
        
        if planInfoString then
            -- planInfoTextView:setText(planInfoString, materialToUse)
            planInfoTextView.text = planInfoString
            planInfoTextView.color = material:getUIColor(materialToUse)
            planInfoTextView.hidden = false
            iconBackgroundView.hidden = false
            
        end
        planInfoView.size = vec2(planInfoTextView.size.x + iconBackgroundView.size.x, math.max(planInfoTextView.size.y, iconBackgroundView.size.y))
        planInfoView.hidden = false
    else

        local inaccessible = false
        if currentObjectInfo.sharedState then
            inaccessible = (currentObjectInfo.sharedState.inaccessibleCount and currentObjectInfo.sharedState.inaccessibleCount >= 2)
        end

        if inaccessible then
            local viewTable = planInfoView.userData
            local icon = viewTable.icon
            local gameObjectView = viewTable.gameObjectView
            local iconBackgroundView = viewTable.iconBackgroundView
            local planInfoTextView = viewTable.planInfoTextView

            local materialToUse = material.types.warning.index
            local iconYOffset = planStatusWarningSize.x * orderMarkerWarningIconYOffset
            local planInfoString = locale:get("lookatUI_inaccessible")

            iconBackgroundView:setModel(model:modelIndexForName("ui_order_warning"), 
            {
                [material.types.warning.index] = materialToUse
            })
            local scaleToUse = planStatusWarningSize.x * 0.5
            iconBackgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
            iconBackgroundView.size = planStatusWarningSize
            local iconHalfSize = planStatusWarningSize.x * 0.4 * 0.5

            
            icon.hidden = false
            gameObjectView.hidden = true
            icon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
            icon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
            icon:setModel(model:modelIndexForName("icon_hand"), {
                default = materialToUse
            })
            icon.baseOffset = vec3(0, iconYOffset, 0.1)
            
            planInfoTextView.text = planInfoString
            planInfoTextView.color = material:getUIColor(materialToUse)
            planInfoTextView.hidden = false
            iconBackgroundView.hidden = false

            planInfoView.size = vec2(planInfoTextView.size.x + iconBackgroundView.size.x, math.max(planInfoTextView.size.y, iconBackgroundView.size.y))
            planInfoView.hidden = false

        else
            planInfoView.hidden = true
        end
    end
end


local resourceViewSize = vec2(200.0,24.0)
local iconHalfSize = 8

function hubUIUtilities:createDegradeInfoView(containerView)
    local resourceView = View.new(containerView)
    local viewTable = {}
    resourceView.userData = viewTable
    --resourceView.size = vec2(200.0,24.0)
    

    
    --[[local usageIcon = ModelView.new(resourceView)
    usageIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    usageIcon.baseOffset = vec3(0,0,2)
    usageIcon:setModel(model:modelIndexForName("icon_circle_filled"), {
        default = material.types.ui_background_dark.index
    })]]

    --usageIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    --usageIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
    
    local usageProgressIcon = ModelView.new(resourceView)
    usageProgressIcon.masksEvents = false
    usageProgressIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    usageProgressIcon.baseOffset = vec3(0, 0, 2)
    usageProgressIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    usageProgressIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0

    
    local coveredTextView = TextView.new(resourceView)
    coveredTextView.font = Font(uiCommon.fontName, 16)
    coveredTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    coveredTextView.relativeView = usageProgressIcon
    coveredTextView.color = mj.textColor
    coveredTextView.baseOffset = vec3(3, -1, 0)

    
    viewTable.usageIcon = usageProgressIcon
    viewTable.usageProgressIcon = usageProgressIcon
    viewTable.coveredTextView = coveredTextView

    return resourceView
end


function hubUIUtilities:getTrueFractionDegraded(incomingFractionDegraded, degradeReferenceTime, currentTime, evolution, covered)
    local fractionDegraded = incomingFractionDegraded or 0
    local timeElapsed = currentTime - (degradeReferenceTime or currentTime)

    local evolutionLength = evolution.minTime
    if covered then
        evolutionLength = evolutionLength * 4.0
    end

    local fractionAddition = timeElapsed / evolutionLength
    fractionDegraded = fractionDegraded + fractionAddition
    return fractionDegraded
end

function hubUIUtilities:updateDegradeInfoView(degradeInfoView, object, worldTime)
    degradeInfoView.hidden = true
    local evolution = evolvingObject.evolutions[object.objectTypeIndex]
    local viewTable = degradeInfoView.userData

    local function showDegradeCommon(radialMaterialIndex, fractionDegraded)
        degradeInfoView.hidden = false
        degradeInfoView.size = resourceViewSize
        
        viewTable.usageProgressIcon:setModel(model:modelIndexForName("icon_circle_thic"), {
            default = radialMaterialIndex
        })
        viewTable.usageProgressIcon:setRadialMaskFraction(fractionDegraded)

        local maxWidth = degradeInfoView.size.x
        if viewTable.coveredTextView then
            maxWidth = math.max(maxWidth, viewTable.usageIcon.size.x + 3 + viewTable.coveredTextView.size.x)
        end

        degradeInfoView.size = vec2(maxWidth, degradeInfoView.size.y)

    end

    if evolution then
        local fractionDegraded = hubUIUtilities:getTrueFractionDegraded(object.sharedState.fractionDegraded, object.sharedState.degradeReferenceTime, worldTime, evolution, object.sharedState.covered)

        if fractionDegraded > 0.001 then
            local evolutionDuration = evolvingObject:getEvolutionDuration(object.objectTypeIndex, fractionDegraded, object.sharedState.degradeReferenceTime, worldTime, object.sharedState.covered)

            local evolutionBucket = evolvingObject:getEvolutionBucket(evolutionDuration)

            viewTable.coveredTextView.text = ""
            
            --uiToolTip:addColoredTitleText(usageIcon, evolvingObject.categories[evolution.categoryIndex].actionName, evolvingObject.categories[evolution.categoryIndex].color)
            viewTable.coveredTextView:addColoredText(evolvingObject.categories[evolution.categoryIndex].actionName, evolvingObject.categories[evolution.categoryIndex].color)
            viewTable.coveredTextView:addColoredText(" " .. evolvingObject:getName(object.objectTypeIndex, evolutionBucket), mj.textColor)
            
            --local text = evolvingObject.categories[evolution.categoryIndex].actionName .. " " .. evolvingObject.descriptionThresholdsHours[evolutionBucket].name
            
            --containedResourceInfos[i].coveredTextView.text = text
            if object.sharedState.covered then
                local color = mjm.vec4(0.5,1.0,0.5, 1.0)
                viewTable.coveredTextView:addColoredText(" (" .. locale:get("misc_inside") .. ")", color)
            else
                viewTable.coveredTextView:addColoredText(" (" .. locale:get("misc_outside") .. ")", evolvingObject.categories[evolution.categoryIndex].color)
            end
            
            showDegradeCommon(evolvingObject.categories[evolution.categoryIndex].material, fractionDegraded)
        end
    elseif object.sharedState.fractionDegraded and object.sharedState.fractionDegraded > 0.01 then
        local usageName = tool:getUsageNameForFraction(object.sharedState.fractionDegraded)
        viewTable.coveredTextView.text = usageName

        showDegradeCommon(material.types.ui_red.index, object.sharedState.fractionDegraded)
    end
end

return hubUIUtilities