local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4

local locale = mjrequire "common/locale"
local gameObject = mjrequire "common/gameObject"
--local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local resource = mjrequire "common/resource"
local material = mjrequire "common/material"
local constructable = mjrequire "common/constructable"
local tool = mjrequire "common/tool"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
local uiMenuItem = mjrequire "mainThread/ui/uiCommon/uiMenuItem"

local constructableUIHelper = {}

local world = nil

constructableUIHelper.orderedFillTypeList = {
    constructable.types.fill_dirt.index,
    constructable.types.fill_sand.index,
    constructable.types.fill_clay.index,
    constructable.types.fill_rock.index,
    constructable.types.fill_copperOre.index,
    constructable.types.fill_tinOre.index,
}

function constructableUIHelper:checkHasSeenRequiredResources(constructableType, missingResourceGroups)
    local hasSeenRequiredResources = true
    local requiredResources = constructableType.requiredResources
    if requiredResources then
        for groupIndex,resourceInfo in ipairs(requiredResources) do
            if resourceInfo.objectTypeIndex then
                if not world:tribeHasSeenResourceObjectTypeIndex(resourceInfo.objectTypeIndex) then
                    hasSeenRequiredResources = false
                    if missingResourceGroups then
                        table.insert(missingResourceGroups, resourceInfo)
                    end
                end
            elseif resourceInfo.group then
                local seen = false
                for i,resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                    if world:tribeHasSeenResource(resourceTypeIndex) then
                        seen = true
                        break
                    end
                end
                
                if not seen then
                    hasSeenRequiredResources = false
                    if missingResourceGroups then
                        table.insert(missingResourceGroups, resourceInfo)
                    end
                end
            else
                if not world:tribeHasSeenResource(resourceInfo.type) then
                    hasSeenRequiredResources = false
                    if missingResourceGroups then
                        table.insert(missingResourceGroups, resourceInfo)
                    end
                end
            end
        end
    end
    return hasSeenRequiredResources
end

function constructableUIHelper:checkHasSeenRequiredResourcesIncludingVariations(constructableType, missingResourceGroups)
    local hasSeenRequiredResources = constructableUIHelper:checkHasSeenRequiredResources(constructableType, missingResourceGroups)
    if not hasSeenRequiredResources then
        local variations = constructable.variations[constructableType.index]
        --mj:log("variations:", variations)
        if variations then
            for j, variationConstructableTypeIndex in ipairs(variations) do
                if variationConstructableTypeIndex ~= constructableType.index then
                    hasSeenRequiredResources = constructableUIHelper:checkHasSeenRequiredResources(constructable.types[variationConstructableTypeIndex], nil)
                    if hasSeenRequiredResources then
                        missingResourceGroups = nil
                        return true
                    end
                end
            end
        end
    end
    return hasSeenRequiredResources
end

function constructableUIHelper:checkHasSeenRequiredTools(constructableType, missingTools)
    local hasSeenAllRequired = true
    local requiredTools = constructableType.requiredTools
    if requiredTools then
        for j,toolTypeIndex in ipairs(requiredTools) do
            if not world:tribeHasSeenToolTypeIndex(toolTypeIndex) then
                hasSeenAllRequired = false
                if missingTools then
                    table.insert(missingTools, toolTypeIndex)
                end
            end
        end
    end
    return hasSeenAllRequired
end

function constructableUIHelper:checkHasRequiredDiscoveries(constructableType)
    if constructableType.skills then
        local requiredSkillTypeIndex = constructableType.skills.required
        if requiredSkillTypeIndex then
            local requiredSkillResearchType = research.researchTypesBySkillType[requiredSkillTypeIndex]
            if requiredSkillResearchType and (not world:tribeHasMadeDiscovery(requiredSkillResearchType.index)) then
                --mj:log("constructableUIHelper:checkHasRequiredDiscoveries returning false:", constructableType.key, " due to requiredSkillResearchType:", requiredSkillResearchType.key)
                return false
            end
        end
    end

    if constructableType.disabledUntilAdditionalResearchDiscovered then
        if not world:tribeHasMadeDiscovery(constructableType.disabledUntilAdditionalResearchDiscovered) then
            --mj:log("constructableUIHelper:checkHasRequiredDiscoveries returning false:", constructableType.key, " due to constructableType.disabledUntilAdditionalResearchDiscovered:", constructableType.disabledUntilAdditionalResearchDiscovered)
            return false
        end
    end
    
    if constructableType.disabledUntilCraftableResearched then
        if not world:tribeHasDiscoveredCraftable(constructableType.index) then
            --mj:log("constructableUIHelper:checkHasRequiredDiscoveries returning false:", constructableType.key, " due to not world:tribeHasDiscoveredCraftable")
            return false
        end
    end

    return true
end

function constructableUIHelper:getDisabledToolTipText(discoveryComplete, hasSeenRequiredResources, hasSeenRequiredTools)
    if not discoveryComplete then
        return locale:get("construct_ui_needsDiscovery")
    end

    if not hasSeenRequiredResources then
        return locale:get("construct_ui_unseenResources")
    end

    if not hasSeenRequiredTools then
        return locale:get("construct_ui_unseenTools")
    end
end

local function getObjectTypes(resourceInfo, toolTypeIndex)

    local gameObjectTypeIndexes = nil

    if resourceInfo then
        if resourceInfo.group then
            gameObjectTypeIndexes = {}
            for k,resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
                gameObjectTypeIndexes = mj:concatTables(gameObjectTypeIndexes, gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex])
            end
        else
            gameObjectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceInfo.type]
        end
    else
        gameObjectTypeIndexes = gameObject.gameObjectTypeIndexesByToolTypeIndex[toolTypeIndex]
    end

    
    local gameObjectTypes = {}

    for i, objectTypeIndex in ipairs(gameObjectTypeIndexes) do
        gameObjectTypes[i] = gameObject.types[objectTypeIndex]
    end
    

    local function sortByName(typeA,typeB)
		if typeA.scarcityValue ~= typeB.scarcityValue then
			if typeA.scarcityValue == nil then
				return true
			elseif typeB.scarcityValue == nil then
				return false
			end
			return typeA.scarcityValue < typeB.scarcityValue
		end
        return typeA.plural < typeB.plural
    end

    table.sort(gameObjectTypes, sortByName)

    return gameObjectTypes

end

local function checkForAllObjectsForAnyResourceUnchecked(constructableTypeIndex, allObjectsForAnyResourceUncheckedChangedFunction)
    
    local restrictedResourceTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
    local restrictedToolTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, true)
    if restrictedResourceTypes or restrictedToolTypes then
        local constructableType = constructable.types[constructableTypeIndex]

        local function doCheck(resourceInfo, toolTypeIndex, restrictedTypes)
            local objectTypes = getObjectTypes(resourceInfo, toolTypeIndex)
            local foundUnchecked = false
            for j, availableObjectType in ipairs(objectTypes) do
                if not restrictedTypes[availableObjectType.index] then
                    foundUnchecked = true
                    break
                end
            end

            if not foundUnchecked then
                allObjectsForAnyResourceUncheckedChangedFunction(true)
                return true
            end
            return false
        end
        
        if restrictedResourceTypes then
            if constructableType.requiredResources then
                for i,resourceInfo in ipairs(constructableType.requiredResources) do
                    if doCheck(resourceInfo, nil, restrictedResourceTypes) then
                        return
                    end
                end
            end
        end
        if restrictedToolTypes then
            if constructableType.requiredTools then
                for i,toolTypeIndex in ipairs(constructableType.requiredTools) do
                    if doCheck(nil, toolTypeIndex, restrictedToolTypes) then
                        return
                    end
                end
            end
        end
    end

    allObjectsForAnyResourceUncheckedChangedFunction(false)
end

local hoverColor = mj.highlightColor * 0.8
local mouseDownColor = mj.highlightColor * 0.6
--local selectedColor = mj.highlightColor * 0.6

local hideUndiscoveredDeprecatedItemsSet = {
    [gameObject.types.stonePickaxeHead_limestone.index] = true,
    [gameObject.types.stoneSpearHead_limestone.index] = true,
}

local function updateUseOnlyView(constructableTypeIndex, useOnlyScrollView, resourceInfo, toolTypeIndex, allObjectsForAnyResourceUncheckedChangedFunction, restrictedObjectsChangedFunction)
    uiScrollView:removeAllRows(useOnlyScrollView)
    uiSelectionLayout:removeAllViews(useOnlyScrollView)


    local objectTypes = getObjectTypes(resourceInfo, toolTypeIndex)
    local counter = 1

    local isTool = (toolTypeIndex ~= nil)

    local restrictedTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, isTool) or {}
    

    

    local blockedObjectTypes = nil
    local blockedToolTypes = nil
        
    local resourceBlockLists = world:getResourceBlockLists()
    if resourceBlockLists.constructableLists then
        blockedObjectTypes = resourceBlockLists.constructableLists[constructableTypeIndex]
        blockedToolTypes = resourceBlockLists.toolBlockList
    end 


    local function addRow(gameObjectType, discovered)
        local backgroundView = ColorView.new(useOnlyScrollView)
        local defaultColor = vec4(0.0,0.0,0.0,0.5)
        if counter % 2 == 1 then
            defaultColor = vec4(0.03,0.03,0.03,0.5)
        end

        backgroundView.color = defaultColor

        backgroundView.size = vec2(useOnlyScrollView.size.x - 22, 30)
        backgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

        

        uiScrollView:insertRow(useOnlyScrollView, backgroundView, nil)
        
        local titleString = gameObjectType.plural
        
        local toggleButton = uiStandardButton:create(backgroundView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
        toggleButton.baseOffset = vec3(2, 0, 0)
        
        uiSelectionLayout:addView(useOnlyScrollView, toggleButton)

        if not restrictedTypes[gameObjectType.index] then
            uiStandardButton:setToggleState(toggleButton, true)
        end

        --if discovered then
            uiStandardButton:setClickFunction(toggleButton, function()
                world:changeConstructableRestrictedObjectType(constructableTypeIndex, gameObjectType.index, isTool, (not uiStandardButton:getToggleState(toggleButton)))
                checkForAllObjectsForAnyResourceUnchecked(constructableTypeIndex, allObjectsForAnyResourceUncheckedChangedFunction)
                restrictedObjectsChangedFunction()
            end)
        --else
        if not discovered then
            titleString = locale:get("misc_undiscovered")
            --uiStandardButton:setDisabled(toggleButton, true)
        end

        
        local nameTextView = TextView.new(backgroundView)

        local gameObjectView = uiGameObjectView:create(backgroundView, vec2(30,30), uiGameObjectView.types.standard)
        gameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
        gameObjectView.baseOffset = vec3(26,0,0)
        uiGameObjectView:setObject(gameObjectView, {
            objectTypeIndex = gameObjectType.index
        }, nil, nil)
            
        gameObjectView.masksEvents = false
        
        if not discovered then
            uiGameObjectView:setDisabled(gameObjectView, true)
            nameTextView.color = vec4(1.0,1.0,1.0,0.5)
        else
            nameTextView.color = mj.textColor
        end
        
        local function showBlockedInfo()
            nameTextView.color = material:getUIColor(material.types.warning.index)
            uiStandardButton:setDisabled(toggleButton, true)
            uiStandardButton:setToggleState(toggleButton, false)
            local toolTipOffset = vec3(0,10,2)
            uiToolTip:add(backgroundView, ViewPosition(MJPositionCenter, MJPositionAbove), "", nil, toolTipOffset, nil, backgroundView, useOnlyScrollView)
            uiToolTip:addColoredTitleText(backgroundView, locale:get("construct_ui_rdisabledInResourcesPanel"), material:getUIColor(material.types.warning.index))
        end
        
        if resourceInfo and blockedObjectTypes and blockedObjectTypes[gameObjectType.index] then
            showBlockedInfo()
        elseif toolTypeIndex and blockedToolTypes and blockedToolTypes[gameObjectType.index] then
            showBlockedInfo()
        end
    
        nameTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
        nameTextView.baseOffset = vec3(54,0,0)
        nameTextView.size = vec2(backgroundView.size.x - 54, backgroundView.size.y)
            
        nameTextView.font = Font(uiCommon.fontName, 16)

        nameTextView.text = titleString

        counter = counter + 1
    end
    
    for i,gameObjectType in pairs(objectTypes) do
        local discovered = world:tribeHasSeenResourceObjectTypeIndex(gameObjectType.index)
        if discovered then
            addRow(gameObjectType, discovered)
        end
    end
    
    for i,gameObjectType in pairs(objectTypes) do
        local discovered = world:tribeHasSeenResourceObjectTypeIndex(gameObjectType.index)
        if not discovered then
            if not hideUndiscoveredDeprecatedItemsSet[gameObjectType.index] then
                addRow(gameObjectType, discovered)
            end
        end
    end
end

function constructableUIHelper:popControllerFocus(requiredResourcesScrollView, useOnlyScrollView)
    if uiSelectionLayout:isActiveSelectionLayoutView(useOnlyScrollView) then
        uiSelectionLayout:removeActiveSelectionLayoutView(useOnlyScrollView)
        uiSelectionLayout:setActiveSelectionLayoutView(requiredResourcesScrollView)
        return true
    end
    return false
end

function constructableUIHelper:getDisplayObjectTypeIndexForConstructableTypeIndex(constructableTypeIndex)
    local constructableType = constructable.types[constructableTypeIndex]

    if constructableType.classification == constructable.classifications.fill.index then
        local restrictedResourceTypes = world:getConstructableRestrictedObjectTypes(constructableTypeIndex, false)
        if restrictedResourceTypes then
            local resourceInfo = constructableType.requiredResources[1]
            local objectTypes = getObjectTypes(resourceInfo, nil)
            for i, availableObjectType in ipairs(objectTypes) do
                if not restrictedResourceTypes[availableObjectType.index] then
                    return availableObjectType.index
                end
            end
        end
    end

    return constructableType.iconGameObjectType
end

function constructableUIHelper:updateRequiredResources(requiredResourcesScrollView, useOnlyScrollView, constructableType, allObjectsForAnyResourceUncheckedChangedFunction, restrictedObjectsChangedFunction)
    uiScrollView:removeAllRows(requiredResourcesScrollView)
    uiSelectionLayout:removeAllViews(requiredResourcesScrollView)

    if constructableType and (constructableType.requiredResources or constructableType.requiredTools) then

        local counter = 1
        local selectedIndex = 1
        local rowInfos = {}

        local restrictedResourceTypes = world:getConstructableRestrictedObjectTypes(constructableType.index, false)
        local restrictedToolTypes = world:getConstructableRestrictedObjectTypes(constructableType.index, true)
        

        local function updateSelectedIndex(thisIndex, resourceInfo, toolTypeIndex, wasClick)
            if selectedIndex ~= thisIndex then
                uiMenuItem:setMenuItemBackgroundSelected(rowInfos[selectedIndex].backgroundView, false)
                selectedIndex = thisIndex
                uiMenuItem:setMenuItemBackgroundSelected(rowInfos[selectedIndex].backgroundView, true)
                updateUseOnlyView(constructableType.index, useOnlyScrollView, resourceInfo, toolTypeIndex, allObjectsForAnyResourceUncheckedChangedFunction, restrictedObjectsChangedFunction)
            end
            if not wasClick then
                uiSelectionLayout:setActiveSelectionLayoutView(useOnlyScrollView)
            end
        end

        local function addRow(resourceInfo, toolTypeIndex)
            local rowInfo = {}
            local thisIndex = counter
            rowInfos[thisIndex] = rowInfo

            
            local backgroundView = ColorView.new(requiredResourcesScrollView)
            rowInfo.backgroundView = backgroundView
            local defaultColor = vec4(0.0,0.0,0.0,0.5)
            if thisIndex % 2 == 1 then
                defaultColor = vec4(0.03,0.03,0.03,0.5)
            end

            backgroundView.color = defaultColor

            backgroundView.size = vec2(requiredResourcesScrollView.size.x - 22, 30)
            backgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
            
            uiSelectionLayout:addView(requiredResourcesScrollView, backgroundView)
            
            uiMenuItem:makeMenuItemBackground(backgroundView, requiredResourcesScrollView, counter, hoverColor, mouseDownColor, function(wasClick)
                updateSelectedIndex(thisIndex, resourceInfo, toolTypeIndex, wasClick)
            end)

            uiScrollView:insertRow(requiredResourcesScrollView, backgroundView, nil)

            local objectTypeIndex = nil
            local titleString = ""

            if resourceInfo then
                if resourceInfo.type then
                    objectTypeIndex = resource.types[resourceInfo.type].displayGameObjectTypeIndex
                    titleString = resource:stringForResourceTypeAndCount(resourceInfo.type, resourceInfo.count)
                else
                    objectTypeIndex = resource.groups[resourceInfo.group].displayGameObjectTypeIndex
                    titleString = resource:stringForResourceGroupTypeAndCount(resourceInfo.group, resourceInfo.count)
                end
            elseif toolTypeIndex then
                objectTypeIndex = tool.types[toolTypeIndex].displayGameObjectTypeIndex
                titleString = "1 " .. tool.types[toolTypeIndex].name
            end
            
            local nameTextView = TextView.new(backgroundView)

            local gameObjectView = uiGameObjectView:create(backgroundView, vec2(30,30), uiGameObjectView.types.standard)
            gameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            uiGameObjectView:setObject(gameObjectView, {
                objectTypeIndex = objectTypeIndex
            }, nil, nil)
                
            gameObjectView.masksEvents = false
        
            nameTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            nameTextView.baseOffset = vec3(30,0,0)
                
            nameTextView.font = Font(uiCommon.fontName, 16)

            nameTextView.color = vec4(1.0,1.0,1.0,1.0)
            nameTextView.text = titleString

            local restrictedTypes = restrictedToolTypes
            if resourceInfo then
                restrictedTypes = restrictedResourceTypes
            end

            if restrictedTypes then
                local objectTypes = getObjectTypes(resourceInfo, toolTypeIndex)
                local foundUnchecked = false
                for i, availableObjectType in ipairs(objectTypes) do
                    if not restrictedTypes[availableObjectType.index] then
                        foundUnchecked = true
                        break
                    end
                end

                if not foundUnchecked then
                    allObjectsForAnyResourceUncheckedChangedFunction(true)
                end
            end

            if thisIndex == selectedIndex then
                updateUseOnlyView(constructableType.index, useOnlyScrollView, resourceInfo, toolTypeIndex, allObjectsForAnyResourceUncheckedChangedFunction, restrictedObjectsChangedFunction)
            end

            counter = counter + 1
        end
        
        if constructableType.requiredResources then
            for i,resourceInfo in ipairs(constructableType.requiredResources) do
                addRow(resourceInfo, nil)
            end
        end
        if constructableType.requiredTools then
            for i,toolTypeIndex in ipairs(constructableType.requiredTools) do
                addRow(nil, toolTypeIndex)
            end
        end
    else
        uiScrollView:removeAllRows(useOnlyScrollView)
    end
end

function constructableUIHelper:init(world_)
    world = world_
end

function constructableUIHelper:getTerrainFillConstructableTypeIndex()
    local fillConstructableTypeIndex = world:getTerrainFillConstructableTypeIndex()
	if fillConstructableTypeIndex then
		return fillConstructableTypeIndex
	end

	for i, constructableTypeIndex in ipairs(constructableUIHelper.orderedFillTypeList) do
		for j, resourceInfo in ipairs(constructable.types[constructableTypeIndex].requiredResources) do
			if resourceInfo.type then
				if world:tribeHasSeenResource(resourceInfo.type) then
					return constructableTypeIndex
				end
			else
				for k, resourceTypeIndex in ipairs(resource.groups[resourceInfo.group].resourceTypes) do
					if world:tribeHasSeenResource(resourceTypeIndex) then
						return constructableTypeIndex
					end
				end
			end
		end
	end

	return constructable.types.fill_dirt.index
end


return constructableUIHelper