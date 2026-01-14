local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local approxEqual = mjm.approxEqual

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local skill = mjrequire "common/skill"
--local research = mjrequire "common/research"
local mood = mjrequire "common/mood"
local order = mjrequire "common/order"
local plan = mjrequire "common/plan"
local sapienConstants = mjrequire "common/sapienConstants"

local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"

local world = nil
local localPlayer = nil

local sapienMarkersUI = {}
local posMarkerViewInfosByObject = {}

local hoverMarkerID = nil

local normalSize = 0.13

local minDistance = mj:mToP(0.3)
local scaleStartDistance = mj:mToP(4.0)

local skillModeSkillTypeIndexes = nil

local function getIconName(sharedState, learningInfo)

    if sharedState.waitOrderSet then
        return "icon_hand"
    end

    if learningInfo and learningInfo.researchTypeIndex then
        return "icon_idea"
    end

    if sharedState.orderQueue and sharedState.orderQueue[1] then
        local orderState = sharedState.orderQueue[1]

        if orderState.context and orderState.context.researchTypeIndex then
            return "icon_idea" --probably no longer needed due to above
        end
        
        if orderState.context and orderState.context.planTypeIndex then
            return plan.types[orderState.context.planTypeIndex].icon
        end

        local orderTypeIndex = orderState.orderTypeIndex
        if not orderTypeIndex then
            mj:error("no order type index in sapienUI getIconName:", sharedState)
            return "icon_hand" --crashes here in 0.5 for some reason
        end
        return order.types[orderTypeIndex].icon
    end
    
    if learningInfo and learningInfo.skillTypeIndex then
        return skill.types[learningInfo.skillTypeIndex].icon
    end

    return "icon_sapien"
end

local function getIconMaterialIndex(sharedState, defaultMaterialIndex)
    if sharedState.waitOrderSet then
        return material.types.mood_severeNegative.index
    end
    return defaultMaterialIndex
end

local function updateSkillProgress(markerViewInfo)
    --mj:log("updateSkillProgress:", markerViewInfo)
    local learningInfo = markerViewInfo.learningInfo
    if skillModeSkillTypeIndexes then
        learningInfo = markerViewInfo.skillModeLearningInfo
    end

    if learningInfo and (learningInfo.researchTypeIndex or (learningInfo.skillTypeIndex and learningInfo.fractionComplete > 0 and learningInfo.fractionComplete < 1.0)) then
        if not markerViewInfo.skillAchievementProgressIcon then
            --[[local skillAchievementBackgroundIcon = ModelView.new(markerViewInfo.backgroundView)
            skillAchievementBackgroundIcon:setUsesModelHitTest(true)
            skillAchievementBackgroundIcon.relativePosition = ViewPosition(MJPositionCenter, MJPositionAbove)
            skillAchievementBackgroundIcon.baseOffset = vec3(0, 0.1, 0)
            local skillAchievementIconHalfSize = normalSize
            skillAchievementBackgroundIcon.scale3D = vec3(skillAchievementIconHalfSize,skillAchievementIconHalfSize,skillAchievementIconHalfSize)
            skillAchievementBackgroundIcon.size = vec2(skillAchievementIconHalfSize,skillAchievementIconHalfSize) * 2.0

            markerViewInfo.skillBackgroundView = skillAchievementBackgroundIcon

            skillAchievementBackgroundIcon:setModel(model:modelIndexForName("icon_circle_filled"), nil, nil, function(materialIndexToRemap)
                return material.types.ui_background.index 
            end)]]

            local skillAchievementIconHalfSize = markerViewInfo.currentSize * 0.7 * 0.5

            local skillAchievementProgressIcon = ModelView.new(markerViewInfo.backgroundView)
            skillAchievementProgressIcon.masksEvents = false
            skillAchievementProgressIcon.baseOffset = vec3(0, 0.08 * (markerViewInfo.currentSize / normalSize), 0.001)
            skillAchievementProgressIcon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            skillAchievementProgressIcon.scale3D = vec3(skillAchievementIconHalfSize,skillAchievementIconHalfSize,skillAchievementIconHalfSize)
            skillAchievementProgressIcon.size = vec2(skillAchievementIconHalfSize,skillAchievementIconHalfSize) * 2.0

            skillAchievementProgressIcon:setModel(model:modelIndexForName("icon_circle_thic"), {
                default = material.types.ui_selected.index
            })

            markerViewInfo.skillAchievementProgressIcon = skillAchievementProgressIcon
        end
        
        --mj:log("followerChanged uniqueID:", uniqueID, "posChangeUpdateData.learningInfo:", posChangeUpdateData.learningInfo)
        if learningInfo.researchTypeIndex then
            local discoveryInfo = world:discoveryInfoForResearchTypeIndex(learningInfo.researchTypeIndex)
            local fractionComplete = 0.0

            if discoveryInfo then
                if discoveryInfo.complete then
                    fractionComplete = 1.0
                    if learningInfo.discoveryCraftableTypeIndex then
                        local craftableDiscoveryInfo = world:discoveryInfoForCraftable(learningInfo.discoveryCraftableTypeIndex)
                        if craftableDiscoveryInfo and craftableDiscoveryInfo.fractionComplete then
                            fractionComplete = craftableDiscoveryInfo.fractionComplete
                        else 
                            fractionComplete = 0.0
                        end
                    end
                elseif discoveryInfo.fractionComplete then
                    fractionComplete = discoveryInfo.fractionComplete
                end
            end
            markerViewInfo.skillAchievementProgressIcon:setRadialMaskFraction(fractionComplete)
        else
            markerViewInfo.skillAchievementProgressIcon:setRadialMaskFraction(learningInfo.fractionComplete or 0.0)
        end
        
    else
        if markerViewInfo.skillAchievementProgressIcon then
            markerViewInfo.backgroundView:removeSubview(markerViewInfo.skillAchievementProgressIcon)
            markerViewInfo.skillAchievementProgressIcon = nil
        end
    end
end

function sapienMarkersUI:updateForSkillModeSkillTypeIndex(markerViewInfo)
    if not skillModeSkillTypeIndexes then
        return
    end

    local skillModeSkillTypeIndex = nil
    for i,skillTypeIndex in ipairs(skillModeSkillTypeIndexes) do
        if skill:priorityLevel(markerViewInfo, skillTypeIndex) ~= 0 then
            skillModeSkillTypeIndex = skillTypeIndex
            break
        end
    end

   --[[ if not skillModeSkillTypeIndex then
        skillModeSkillTypeIndex = skillModeSkillTypeIndexes[1]
    end]]

    --mj:log("updateForSkillModeSkillTypeIndex:", markerViewInfo, " skillModeSkillTypeIndexes:", skillModeSkillTypeIndexes, " skillModeSkillTypeIndex:", skillModeSkillTypeIndex)

    if skillModeSkillTypeIndex then

        markerViewInfo.skillModeLearningInfo = {
            skillTypeIndex = skillModeSkillTypeIndex,
            fractionComplete = skill:fractionLearned(markerViewInfo, skillModeSkillTypeIndex)
        }
        
        updateSkillProgress(markerViewInfo)

        local iconName = skill.types[skillModeSkillTypeIndex].icon
        local iconMaterialIndex = material.types.ui_standard.index
        local markerTriangleMaterialIndex = material.types.ui_background_black.index
        if skill:hasSkill(markerViewInfo, skillModeSkillTypeIndex) then
            iconMaterialIndex = material.types.ui_selected.index
            markerTriangleMaterialIndex = iconMaterialIndex
        end

        if skill.types[skillModeSkillTypeIndex].noCapacityWithLimitedGeneralAbility or skill.types[skillModeSkillTypeIndex].partialCapacityWithLimitedGeneralAbility then
            if sapienConstants:getHasLimitedGeneralAbility(markerViewInfo.sharedState, skill.types[skillModeSkillTypeIndex].noCapacityWithLimitedGeneralAbilityIncludesElders) then
                iconMaterialIndex = material.types.ui_background_warning_disabled.index
                markerTriangleMaterialIndex = iconMaterialIndex
            end
        end
            
        markerViewInfo.icon.hidden = false
        markerViewInfo.iconName = iconName
        markerViewInfo.iconMaterialIndex = iconMaterialIndex
        markerViewInfo.icon:setModel(model:modelIndexForName(iconName), {
                default = iconMaterialIndex
        })
        
        markerViewInfo.backgroundView:setModel(model:modelIndexForName("ui_sapienMarkerNew"), {
            [material.types.ui_standard.index] = markerTriangleMaterialIndex,
            [material.types.ui_background.index] = material.types.ui_background_black.index,
        })
    else
        markerViewInfo.skillModeLearningInfo = {
            fractionComplete = 0
        }
        
        updateSkillProgress(markerViewInfo)

        markerViewInfo.icon.hidden = true
        
        markerViewInfo.backgroundView:setModel(model:modelIndexForName("ui_sapienMarkerNew"), {
            [material.types.ui_standard.index] = material.types.warning.index,
            [material.types.ui_background.index] = material.types.ui_background_black.index,
        })
    end

    --todo
    --[[

                if skill.types[skillTypeIndex].noCapacityWithLimitedGeneralAbility or skill.types[skillTypeIndex].partialCapacityWithLimitedGeneralAbility then
                    if sapienConstants:getHasLimitedGeneralAbility(sharedState, skill.types[skillTypeIndex].noCapacityWithLimitedGeneralAbilityIncludesElders) then
                        limitedAbility = true
                        if not skill.types[skillTypeIndex].noCapacityWithLimitedGeneralAbility then
                            limitedAbilityIsPartial = true
                            
                        end

                        material.types.ui_background_warning_disabled.index

                    end
                end
    ]]

    --[[

                local skillAchievementIconHalfSize = 7

                if skill:learnStarted(sapien, skillTypeIndex) then
                    skillAchievementIcon = ModelView.new(backgroundView)
                    skillAchievementIcon.masksEvents = false
                    skillAchievementIcon.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
                    skillAchievementIcon.baseOffset = vec3(-6, 4, 1)
                    skillAchievementIcon.scale3D = vec3(skillAchievementIconHalfSize,skillAchievementIconHalfSize,skillAchievementIconHalfSize)
                    skillAchievementIcon.size = vec2(skillAchievementIconHalfSize,skillAchievementIconHalfSize) * 2.0
                    
                    if skill:hasSkill(sapien, skillTypeIndex) then
                        skillAchievementBackgroundIcon = nil
                        skillAchievementIcon:setModel(model:modelIndexForName("icon_achievement"), {
                            default = material.types.ui_selected.index
                        })
                    else
                        skillAchievementBackgroundIcon = skillAchievementIcon
                        skillAchievementIcon:setModel(model:modelIndexForName("icon_circle_filled"), {
                            default = material.types.ui_disabled.index
                        })

                        
                        local skillAchievementProgressIcon = ModelView.new(backgroundView)
                        skillAchievementProgressIcon.masksEvents = false
                        skillAchievementProgressIcon.relativeView = skillAchievementIcon
                        skillAchievementProgressIcon.baseOffset = vec3(0, 0, 2)
                        skillAchievementProgressIcon.scale3D = vec3(skillAchievementIconHalfSize,skillAchievementIconHalfSize,skillAchievementIconHalfSize)
                        skillAchievementProgressIcon.size = vec2(skillAchievementIconHalfSize,skillAchievementIconHalfSize) * 2.0

                        skillAchievementProgressIcon:setModel(model:modelIndexForName("icon_circle_thic"), {
                            default = material.types.ui_selected.index
                        })
                        skillAchievementProgressIcon:setRadialMaskFraction(skill:fractionLearned(sapien, skillTypeIndex))
    ]]

      --[[  local iconName = skill.types[skillModeSkillTypeIndex].icon
        local iconMaterialIndex = material.types.ui_standard.index
        if hasSkill then
            iconMaterialIndex = material.types.ui_selected.index
        end
        --mj:log("got icon:", iconName, " for sapien:", uniqueID)
        icon:setModel(model:modelIndexForName(iconName), {
            default = iconMaterialIndex
        })]]

               --[[ if posChangeUpdateData.learningInfo then
                    markerViewInfo.learningInfo = posChangeUpdateData.learningInfo
                    updateSkillProgress(markerViewInfo)
                end

                local function updateIcon(materialIndex)
                    local iconName = getIconName(sharedState, markerViewInfo.learningInfo)
                    local iconMaterialIndex = getIconMaterialIndex(posChangeUpdateData.sharedState, materialIndex)
                    if iconMaterialIndex ~= markerViewInfo.iconMaterialIndex or iconName ~= markerViewInfo.iconName then
                        markerViewInfo.iconName = iconName
                        markerViewInfo.iconMaterialIndex = iconMaterialIndex
                        markerViewInfo.icon:setModel(model:modelIndexForName(iconName), {
                                default = iconMaterialIndex
                        })
                    end
                end
                
                local happySadMood = mood:getMood({sharedState = sharedState}, mood.types.happySad.index)
                
                if happySadMood ~= markerViewInfo.happySadMood then
                    markerViewInfo.happySadMood = happySadMood
                    local materialIndex = mood.materials[happySadMood]
                    
                    markerViewInfo.backgroundView:setModel(model:modelIndexForName("ui_sapienMarkerNew"), {
                        [material.types.ui_standard.index] = materialIndex,
                        [material.types.ui_background.index] = material.types.ui_background_black.index,
                    })

                    updateIcon(materialIndex)
                    
                else
                    local materialIndex = mood.materials[markerViewInfo.happySadMood]
                    updateIcon(materialIndex)
                end]]
end


function sapienMarkersUI:followerChanged(posChangeUpdateData)
    ----disabled--mj:objectLog(posChangeUpdateData.uniqueID, "sapienMarkersUI:followerChanged containsSkillInfo:", containsSkillInfo, " posChangeUpdateData:", posChangeUpdateData, " trace:", debug.traceback() )
    local uniqueID = posChangeUpdateData.uniqueID
    local pos = posChangeUpdateData.pos

    if not posMarkerViewInfosByObject[uniqueID] then
        local worldView = worldUIViewManager:addView(pos, worldUIViewManager.groups.sapienMarker, {
            startScalingDistance = scaleStartDistance, 
            offsets = sapienConstants:getSapienMarkerOffsetInfo(posChangeUpdateData.sharedState), 
            minDistance = minDistance,
            attachObjectUniqueID = posChangeUpdateData.uniqueID, 
            attachBoneName = "head", 
            renderXRay = true
        })
        local viewID = worldView.uniqueID
        local view = worldView.view
       -- view:setCircleHitRadius(normalSize * 0.5)
        view.size = vec2(normalSize,normalSize)
        view.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)

        local backgroundView = ModelView.new(view)
        backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        backgroundView:setUsesModelHitTest(true)
        backgroundView:setCircleHitRadius(normalSize * 1.2) --when used with modelHitTest, this is an optimization, basically a bounding circle

        
        
        --[[local scaleToUse = size.x * 0.5
        backgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
        backgroundView.size = size
        local logoHalfSize = size.x * 0.5 * 0.5
        icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
        icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0]]
        
        --[[local icon = ModelView.new(backgroundView)
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        icon.baseOffset = vec3(0, 0, 0.01)]]

        --[[local skillView = ModelView.new(backgroundView)
        skillView:setModel(model:modelIndexForName("ui_sapienMarkerSkillBackground"))
        skillView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        skillView.baseOffset = vec3(0, 0, 0.02)
        skillView:setUsesModelHitTest(true)]]


       --[[ local skillTypeIndex = posChangeUpdateData.sharedState.prioritySkill
        local skillIcon = ModelView.new(skillView)
        skillIcon:setModel(model:modelIndexForName(skill.types[skillTypeIndex].icon))
        skillIcon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        skillIcon.baseOffset = vec3(0, 0, 0.01)]]

        --local backgroundHover = false
        --local skillViewHover = false

        local icon = ModelView.new(backgroundView)
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        icon.baseOffset = vec3(0, 0.08, 0.002)
        local logoHalfSize = normalSize * 0.4 * 0.5
        icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
        icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0

        backgroundView.hoverStart = function ()
            --backgroundHover = true
            --mj:log("hover start:", uniqueID)
            --if not skillViewHover then
                localPlayer:markerLookAtStarted(uniqueID, worldView.pos, nil)
           -- end
        end
        backgroundView.hoverEnd = function ()
            --backgroundHover = false
            --mj:log("hover end")
           -- mj:log("hover end:", uniqueID)
           -- if not skillViewHover then
                localPlayer:markerLookAtEnded(uniqueID)
           -- end
        end
        backgroundView.mouseDown = function (buttonIndex)
            localPlayer:markerClick(uniqueID, buttonIndex)
        end

        --[[skillView.hoverStart = function ()
            --mj:log("hover start")
            skillViewHover = true
            if not backgroundHover then
                localPlayer:markerLookAtStarted(uniqueID, worldView.pos, nil)
            end
        end
        skillView.hoverEnd = function ()
            skillViewHover = false
            --mj:log("hover end")
            if not backgroundHover then
                localPlayer:markerLookAtEnded(uniqueID)
            end
        end]]

        local happySadMood = mood:getMood(posChangeUpdateData, mood.types.happySad.index)
        local materialIndex = mood.materials[happySadMood]

        
        backgroundView:setModel(model:modelIndexForName("ui_sapienMarkerNew"), {
            [material.types.ui_standard.index] = materialIndex,
            [material.types.ui_background.index] = material.types.ui_background_black.index,
        })

        local iconName = getIconName(posChangeUpdateData.sharedState, posChangeUpdateData.learningInfo)
        local iconMaterialIndex = getIconMaterialIndex(posChangeUpdateData.sharedState, materialIndex)
        --mj:log("got icon:", iconName, " for sapien:", uniqueID)
        icon:setModel(model:modelIndexForName(iconName), {
            default = iconMaterialIndex
        })

        --skillView.click = backgroundView.click

        posMarkerViewInfosByObject[uniqueID] = {
            viewID = viewID,
            view = view,
            icon = icon,
            iconName = iconName,
            iconMaterialIndex = iconMaterialIndex,
            --skillIcon = skillIcon,
            --skillTypeIndex = skillTypeIndex,
            --skillView = skillView,
            hover = false,
            backgroundView = backgroundView,
            currentSize = normalSize * 0.8,
            goalSize = normalSize,
            differenceVelocity = 0.0,
            happySadMood = happySadMood,
            sharedState = posChangeUpdateData.sharedState,
        }

        if posChangeUpdateData.learningInfo then
            posMarkerViewInfosByObject[uniqueID].learningInfo = posChangeUpdateData.learningInfo
        end

        
        backgroundView.update = function(dt)
            local info = posMarkerViewInfosByObject[uniqueID]
            if (not approxEqual(info.goalSize, info.currentSize)) or (not approxEqual(info.differenceVelocity, 0.0)) then
                local difference = info.goalSize - info.currentSize
                local clampedDT = mjm.clamp(dt * 40.0, 0.0, 1.0)
                info.differenceVelocity = info.differenceVelocity * math.max(1.0 - dt * 20.0, 0.0) + (difference * clampedDT)
                info.currentSize = info.currentSize + info.differenceVelocity * dt * 12.0

                local scaleToUse = info.currentSize * 0.5
                info.backgroundView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
                info.backgroundView.size = vec2(info.currentSize * 2.0, info.currentSize)

                local updatedLogoHalfSize = info.currentSize * 0.4 * 0.5
                info.icon.scale3D = vec3(updatedLogoHalfSize,updatedLogoHalfSize,updatedLogoHalfSize)
                info.icon.size = vec2(updatedLogoHalfSize,updatedLogoHalfSize) * 2.0
                info.icon.baseOffset = vec3(0, 0.08 * (info.currentSize / normalSize), 0.002)

                if info.skillAchievementProgressIcon then
                    local skillHalfSize = info.currentSize * 0.7 * 0.5
                    info.skillAchievementProgressIcon.scale3D = vec3(skillHalfSize,skillHalfSize,skillHalfSize)
                    info.skillAchievementProgressIcon.size = vec2(skillHalfSize,skillHalfSize) * 2.0
                    info.skillAchievementProgressIcon.baseOffset = vec3(0, 0.08 * (info.currentSize / normalSize), 0.001)
                end

                --[[local skillViewHalfSize = info.currentSize * 1.0 * 0.5
                info.skillView.scale3D = vec3(skillViewHalfSize,skillViewHalfSize,skillViewHalfSize)
                info.skillView.size = vec2(skillViewHalfSize,skillViewHalfSize) * 2.0

                local skillIconOffset = vec2(0.35,0.24)
                info.skillView.baseOffset = vec3(info.currentSize * skillIconOffset.x, info.currentSize * skillIconOffset.y, 0.01)

                local skillIconHalfSize = info.currentSize * 0.2 * 0.5
                info.skillIcon.scale3D = vec3(skillIconHalfSize,skillIconHalfSize,skillIconHalfSize)
                info.skillIcon.size = vec2(skillIconHalfSize,skillIconHalfSize) * 2.0]]

                
            end
        end

        if posChangeUpdateData.learningInfo then
            updateSkillProgress(posMarkerViewInfosByObject[uniqueID])
        end

        if skillModeSkillTypeIndexes then
            sapienMarkersUI:updateForSkillModeSkillTypeIndex(posMarkerViewInfosByObject[uniqueID])
        end

    else
        local markerViewInfo = posMarkerViewInfosByObject[uniqueID]
        local sharedStateChanged = false
        if posChangeUpdateData.sharedState then
            sharedStateChanged = true
            markerViewInfo.sharedState = posChangeUpdateData.sharedState
        end
        local sharedState = markerViewInfo.sharedState

        if sharedStateChanged then
            
            if skillModeSkillTypeIndexes then
                sapienMarkersUI:updateForSkillModeSkillTypeIndex(markerViewInfo)
            else
                --mj:log("sharedStateChanged id:", uniqueID, " learningInfo:", posChangeUpdateData.learningInfo)

                markerViewInfo.learningInfo = posChangeUpdateData.learningInfo
                updateSkillProgress(markerViewInfo)

                local function updateIcon(materialIndex)
                    local iconName = getIconName(sharedState, markerViewInfo.learningInfo)
                    local iconMaterialIndex = getIconMaterialIndex(posChangeUpdateData.sharedState, materialIndex)
                    if iconMaterialIndex ~= markerViewInfo.iconMaterialIndex or iconName ~= markerViewInfo.iconName then
                        markerViewInfo.iconName = iconName
                        markerViewInfo.iconMaterialIndex = iconMaterialIndex
                        markerViewInfo.icon:setModel(model:modelIndexForName(iconName), {
                            default = iconMaterialIndex
                        })
                    end
                end
                
                local happySadMood = mood:getMood({sharedState = sharedState}, mood.types.happySad.index)
                
                markerViewInfo.happySadMood = happySadMood
                local materialIndex = mood.materials[markerViewInfo.happySadMood]
                    
                markerViewInfo.backgroundView:setModel(model:modelIndexForName("ui_sapienMarkerNew"), {
                    [material.types.ui_standard.index] = materialIndex,
                    [material.types.ui_background.index] = material.types.ui_background_black.index,
                })
                markerViewInfo.icon.hidden = false
                updateIcon(materialIndex)
            end
        end
        
        if pos then
            worldUIViewManager:updateView(posMarkerViewInfosByObject[uniqueID].viewID, pos, nil, sapienConstants:getSapienMarkerOffsetInfo(sharedState), uniqueID, "head")
        end



        
        --[[local happySadMood = mood:getMood(selectedObject, mood.types.happySad.index)
        happySadTextView.text = "Happiness: "
        happySadTextView:addColoredText(mood.types.happySad.descriptions[happySadMood], mood.colors[happySadMood])]]
    end

end

function sapienMarkersUI:bulkFollowerPositionsChanged(posChangeUpdateData)
    for uniqueID,pos in pairs(posChangeUpdateData) do
        local markerViewInfo = posMarkerViewInfosByObject[uniqueID]
        if markerViewInfo then
            worldUIViewManager:updateView(posMarkerViewInfosByObject[uniqueID].viewID, pos, nil, sapienConstants:getSapienMarkerOffsetInfo(markerViewInfo.sharedState), uniqueID, "head")
        end
    end
end

function sapienMarkersUI:followersListChanged(followerInfos)
    for uniqueID,markerViewInfo in pairs(posMarkerViewInfosByObject) do
        if not followerInfos[uniqueID] then
            worldUIViewManager:removeView(markerViewInfo.viewID)
            posMarkerViewInfosByObject[uniqueID] = nil
        end
    end

    for uniqueID,objectInfo in pairs(followerInfos) do
        sapienMarkersUI:followerChanged({
            uniqueID = uniqueID,
            pos = objectInfo.pos,
            sharedState = objectInfo.sharedState,
        })
    end
end

function sapienMarkersUI:init(world_, localPlayer_)
    world = world_
    localPlayer = localPlayer_
end

local function updateHover(markerViewInfo)
    
    --local backgroundMaterialIndex = material.types.ui_background.index

    if markerViewInfo.hover then
        --backgroundMaterialIndex = material.types.ui_selected.index
        markerViewInfo.goalSize = normalSize * 2.0
    else
        markerViewInfo.goalSize = normalSize
    end

end

function sapienMarkersUI:setHoverMarker(uniqueID)
    if hoverMarkerID ~= uniqueID then
        if hoverMarkerID then
            local markerViewInfo = posMarkerViewInfosByObject[hoverMarkerID]
            if markerViewInfo then
                markerViewInfo.hover = false
                updateHover(markerViewInfo)
            end
            hoverMarkerID = nil
        end

        if uniqueID then
            local markerViewInfo = posMarkerViewInfosByObject[uniqueID]
            if markerViewInfo then
                hoverMarkerID = uniqueID
                markerViewInfo.hover = true
                updateHover(markerViewInfo)
            end
        end
    end
end

local hasHiddenViews = false

function sapienMarkersUI:hideMarkers(sapienIDs)
    --mj:log("sapienMarkersUI:hideMarkers:", sapienIDs)
    if sapienIDs and next(sapienIDs) then
        for i, sapienID in ipairs(sapienIDs) do
            local markerViewInfo = posMarkerViewInfosByObject[sapienID]
            if markerViewInfo then
                markerViewInfo.view.hidden = true
            end
        end
        hasHiddenViews = true
    end
end


function sapienMarkersUI:setSkillModeSkillTypeIndexes(skillTypeIndexes)
    if ((skillModeSkillTypeIndexes == nil) ~= (skillTypeIndexes == nil)) or
     (skillTypeIndexes and #skillTypeIndexes ~= #skillModeSkillTypeIndexes) or
     (skillTypeIndexes and skillTypeIndexes[1] ~= skillModeSkillTypeIndexes[1]) then
        skillModeSkillTypeIndexes = skillTypeIndexes
        if skillModeSkillTypeIndexes and (not next(skillModeSkillTypeIndexes)) then
            skillModeSkillTypeIndexes = nil
        end

        for uniqueID,markerViewInfo in pairs(posMarkerViewInfosByObject) do
            sapienMarkersUI:followerChanged({
                uniqueID = uniqueID,
                sharedState = markerViewInfo.sharedState,
            })
        end
    end
end

function sapienMarkersUI:showAllMarkers()
    if hasHiddenViews then
        for k,markerViewInfo in pairs(posMarkerViewInfosByObject) do
            markerViewInfo.view.hidden = false
        end
        hasHiddenViews = false
    end
end

return sapienMarkersUI