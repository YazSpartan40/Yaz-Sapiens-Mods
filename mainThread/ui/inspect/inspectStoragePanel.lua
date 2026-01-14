local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local locale = mjrequire "common/locale"

local gameObject = mjrequire "common/gameObject"
local evolvingObject = mjrequire "common/evolvingObject"
local storage = mjrequire "common/storage"
local resource = mjrequire "common/resource"
local tool = mjrequire "common/tool"

local model = mjrequire "common/model"
local material = mjrequire "common/material"
local storageSettings = mjrequire "common/storageSettings"

local logicInterface = mjrequire "mainThread/logicInterface"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiPopUpButton = mjrequire "mainThread/ui/uiCommon/uiPopUpButton"
local uiSlider = mjrequire "mainThread/ui/uiCommon/uiSlider"
--local logisticsUIHelper = mjrequire "mainThread/ui/logisticsUIHelper"
local uiGameObjectView = mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
--local uiMenuItem = mjrequire "mainThread/ui/uiCommon/uiMenuItem"
local storageLogisticsDestinationsUI = mjrequire "mainThread/ui/storageLogisticsDestinationsUI"
local tutorialUI = mjrequire "mainThread/ui/tutorialUI"
local hubUIUtilities = mjrequire "mainThread/ui/hubUIUtilities"



local inspectStoragePanel = {}

local inspectUI = nil
local world = nil
--local manageUI = nil
local gameUI = nil


local allowItemUseToggleButton = nil
local removeAllItemsToggleButton = nil
local destroyAllItemsToggleButton = nil
local maxQuantitySlider = nil
local maxQuantityCountTextView = nil

local storageAreaObjectID = nil
local storageAreaObject = nil
local storageAreaSettingsTribeID = nil

local leftPaneView = nil
local leftPaneTopView = nil
local leftPaneBotView = nil
local rightPaneView = nil
local contentsListView = nil

local receiveRoutesListView = nil
local sendRoutesListView = nil

local contentsViewItemHeight = 40.0
local contentsViewItemObjectImageViewSize = vec2(38.0, 38.0)

local restrictContentsListView = nil
local restrictStorageTypeButton = nil

--local hoverColor = mj.highlightColor * 0.8
--local mouseDownColor = mj.highlightColor * 0.6



local function sendAllowItemUse(allowItemUse)
    logicInterface:callServerFunction("changeStorageAreaConfig", {
        settingsTribeID = storageAreaSettingsTribeID,
        storageAreaObjectID = storageAreaObjectID,
        disallowItemUse = (not allowItemUse),
    })
    
    storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID].disallowItemUse = (not allowItemUse)
end

local function sendRemoveAllItems(removeAllItems)
    logicInterface:callServerFunction("changeStorageAreaConfig", {
        settingsTribeID = storageAreaSettingsTribeID,
        storageAreaObjectID = storageAreaObjectID,
        removeAllItems = (removeAllItems or false),
    })
    storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID].removeAllItems = removeAllItems
end

local function sendDestroyAllItems(destroyAllItems)
    logicInterface:callServerFunction("changeStorageAreaConfig", {
        settingsTribeID = storageAreaSettingsTribeID,
        storageAreaObjectID = storageAreaObjectID,
        destroyAllItems = (destroyAllItems or false),
    })
    storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID].destroyAllItems = destroyAllItems
end


local function sendMaxQuantity(newValue)
    logicInterface:callServerFunction("changeStorageAreaConfig", {
        settingsTribeID = storageAreaSettingsTribeID,
        storageAreaObjectID = storageAreaObjectID,
        maxQuantityFraction = newValue,
    })
    storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID].maxQuantityFraction = newValue
end

local orderedObjectTypesByStorageTypeIndex = {}

local function getOrCreateObjectTypes(storageTypeIndex)
    if orderedObjectTypesByStorageTypeIndex[storageTypeIndex] then
        return orderedObjectTypesByStorageTypeIndex[storageTypeIndex]
    end

    local orderedGameObjectTypes = {}
    local resources = storage.types[storageTypeIndex].resources
    for i, resourceTypeIndex in ipairs(resources) do
        local gameObjectTypeIndexes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
        for j, gameObjectTypeIndex in ipairs(gameObjectTypeIndexes) do
            table.insert(orderedGameObjectTypes, gameObject.types[gameObjectTypeIndex])
        end
    end
    
    local function sortByName(a,b)
        return a.plural < b.plural
    end

    table.sort(orderedGameObjectTypes, sortByName)

    orderedObjectTypesByStorageTypeIndex[storageTypeIndex] = orderedGameObjectTypes
    return orderedGameObjectTypes
end

local dontAllowSameStorageAreaID = nil


local function getAllowUseValue(objectTribeSettings)
    --mj:log("getAllowUseValue:", objectTribeSettings)
    if (objectTribeSettings and objectTribeSettings.disallowItemUse ~= nil) then
        --mj:log("a:", (not objectTribeSettings.disallowItemUse))
        return (not objectTribeSettings.disallowItemUse)
    end

    if world.tribeID == storageAreaObject.sharedState.tribeID or (not world:tribeIsValidOwner(storageAreaObject.sharedState.tribeID)) then
        --mj:log("b:true:", world:tribeIsValidOwner(storageAreaObject.sharedState.tribeID))
        return true
    end

    local globalTribeSettings = world:getOrCreateTribeRelationsSettings(storageAreaObject.sharedState.tribeID)
    --mj:log("globalTribeSettings:", globalTribeSettings)
    if globalTribeSettings.storageAlly then
        --mj:log("c:true")
        return true
    end

    --mj:log("d:false")
    return false
end


local function getRestrictStorageTypeIndexValue(objectTribeSettings)

    if (objectTribeSettings and objectTribeSettings.restrictStorageTypeIndex ~= nil) then
        --mj:log("a:", objectTribeSettings.restrictStorageTypeIndex)
        return objectTribeSettings.restrictStorageTypeIndex
    end

    if world.tribeID == storageAreaObject.sharedState.tribeID or (not world:tribeIsValidOwner(storageAreaObject.sharedState.tribeID)) then
        --mj:log("b:nil:", world:tribeIsValidOwner(storageAreaObject.sharedState.tribeID))
        return nil
    end


    local globalTribeSettings = world:getOrCreateTribeRelationsSettings(storageAreaObject.sharedState.tribeID)
    if globalTribeSettings.storageAlly then
        return nil
    end

    --mj:log("d:-1")
    return -1
end

local function updateRestrictionForType(gameObjectTypeIndex, isRestricted)
    logicInterface:callServerFunction("changeStorageAreaConfig", {
        settingsTribeID = storageAreaSettingsTribeID,
        storageAreaObjectID = storageAreaObjectID,
        modifyRestrictObjectTypeIndexes = {gameObjectTypeIndex},
        restrictionValue = isRestricted,
    })

    local sharedState = storageAreaObject.sharedState
    local settingsToUse = sharedState.settingsByTribe[storageAreaSettingsTribeID]

    if isRestricted then
        if not settingsToUse.restrictedObjectTypeIndexes then
            settingsToUse.restrictedObjectTypeIndexes = {}
        end
        settingsToUse.restrictedObjectTypeIndexes[gameObjectTypeIndex] = true
    else
        if settingsToUse and settingsToUse.restrictedObjectTypeIndexes then
            settingsToUse.restrictedObjectTypeIndexes[gameObjectTypeIndex] = nil
        end
    end

    if dontAllowSameStorageAreaID ~= storageAreaObjectID and (not (tutorialUI:configureRawMeatComplete() and tutorialUI:configureCookedMeatComplete())) then
        local resourceType = resource.types[gameObject.types[gameObjectTypeIndex].resourceTypeIndex]
        if resourceType.isRawMeatForTutorial or resourceType.isCookedMeatForTutorial then
            local allowsCooked = false
            local allowsRaw = false
            local allCookedAllowed = true
            local allRawAllowed = true

            local storageTypeIndex = storage:storageTypeIndexForResourceTypeIndex(resourceType.index)
            local resources = storage.types[storageTypeIndex].resources
            for i, resourceTypeIndex in ipairs(resources) do
                if resource.types[resourceTypeIndex].isRawMeatForTutorial then
                    local gameObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
                    for j, objectTypeIndex in ipairs(gameObjectTypes) do
                        if not (settingsToUse and 
                        settingsToUse.restrictedObjectTypeIndexes and
                        settingsToUse.restrictedObjectTypeIndexes[objectTypeIndex]) then
                            allowsRaw = true
                        else
                            allRawAllowed = false
                        end
                    end
                elseif resource.types[resourceTypeIndex].isCookedMeatForTutorial then
                    local gameObjectTypes = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
                    for j, objectTypeIndex in ipairs(gameObjectTypes) do
                        if not (settingsToUse and 
                        settingsToUse.restrictedObjectTypeIndexes and
                        settingsToUse.restrictedObjectTypeIndexes[objectTypeIndex]) then
                            allowsCooked = true
                        else
                            allCookedAllowed = false
                        end
                    end
                end
            end
            
            if allowsRaw and allRawAllowed and (not allowsCooked) then
                if (not tutorialUI:configureRawMeatComplete()) then
                    tutorialUI:setHasConfiguredRawMeat()
                    dontAllowSameStorageAreaID = storageAreaObjectID
                end
            end
            if allowsCooked and allCookedAllowed and (not allowsRaw) then
                if (not tutorialUI:configureCookedMeatComplete()) then
                    tutorialUI:setHasConfiguredCookedMeat()
                    dontAllowSameStorageAreaID = storageAreaObjectID
                end
            end
        end
    end
end

local function toggleObjectTypeRestriction(gameObjectTypeIndex, newState)
    updateRestrictionForType(gameObjectTypeIndex, not newState)
end

local function updateObjectTypes()
    
    local sharedState = storageAreaObject.sharedState
    
    local settingsToUse = sharedState.settingsByTribe[storageAreaSettingsTribeID]
    local restrictStorageTypeIndex = getRestrictStorageTypeIndexValue(settingsToUse)
    local restrictedObjectTypeIndexes = (settingsToUse and settingsToUse.restrictedObjectTypeIndexes) or {}
    
    uiScrollView:removeAllRows(restrictContentsListView)

    if restrictStorageTypeIndex and restrictStorageTypeIndex > 0 then

        local objectTypes = getOrCreateObjectTypes(restrictStorageTypeIndex)
        local counter = 1


        local function addRow(gameObjectType, discovered)
            local backgroundView = ColorView.new(restrictContentsListView)
            local defaultColor = vec4(0.0,0.0,0.0,0.5)
            if counter % 2 == 1 then
                defaultColor = vec4(0.03,0.03,0.03,0.5)
            end

            backgroundView.color = defaultColor

            backgroundView.size = vec2(restrictContentsListView.size.x - 22, 30)
            backgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

            uiScrollView:insertRow(restrictContentsListView, backgroundView, nil)
            --backgroundView.baseOffset = vec3(0,(-counter + 1) * 30,0)

            local toggleButton = uiStandardButton:create(backgroundView, vec2(26,26), uiStandardButton.types.toggle)
            toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            toggleButton.baseOffset = vec3(4, 0, 0)

            uiStandardButton:setToggleState(toggleButton, not restrictedObjectTypeIndexes[gameObjectType.index])

            local titleString = gameObjectType.plural
            
            if not discovered then
                titleString = locale:get("misc_undiscovered")
            end
            
            uiStandardButton:setClickFunction(toggleButton, function()
                toggleObjectTypeRestriction(gameObjectType.index, uiStandardButton:getToggleState(toggleButton))
            end)
            
            local nameTextView = TextView.new(backgroundView)

            local gameObjectView = uiGameObjectView:create(backgroundView, vec2(30,30), uiGameObjectView.types.standard)
            --uiGameObjectView:setBackgroundAlpha(gameObjectView, 0.6)
            gameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            gameObjectView.baseOffset = vec3(30,0,0)
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
        
            nameTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            nameTextView.baseOffset = vec3(60,0,0)
                
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
                addRow(gameObjectType, discovered)
            end
        end
    end
end

local prevRestrictStorageTypeIndex = nil
local prevRestrictStorageAreaObjectID = nil

local function updateAllowItemUseButton(removeAllItems, allowItemUse_)
    local allowItemUse = allowItemUse_
    if removeAllItems then
        allowItemUse = true
    end
    --mj:error("updateAllowItemUseButton allowItemUse_:", allowItemUse_, " removeAllItems:", removeAllItems, " allowItemUse:", allowItemUse)
    uiStandardButton:setToggleState(allowItemUseToggleButton, allowItemUse)
    uiStandardButton:setDisabled(allowItemUseToggleButton, removeAllItems)
end

local function updateRoutesListViews(uiRoutesResult)
    uiScrollView:removeAllRows(receiveRoutesListView)
    uiScrollView:removeAllRows(sendRoutesListView)
    uiSelectionLayout:removeAllViews(receiveRoutesListView)
    uiSelectionLayout:removeAllViews(sendRoutesListView)

    local backgroundColorCounter = 1
    
    local function createRowBackground(listView)
        local backgroundView = ColorView.new(listView)
        local defaultColor = uiCommon.listBackgroundColors[backgroundColorCounter % 2 + 1]

        backgroundView.color = defaultColor

        backgroundView.size = vec2(listView.size.x - 22, 60)
        backgroundView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)

        uiScrollView:insertRow(listView, backgroundView, nil)

        backgroundColorCounter = backgroundColorCounter + 1
        return backgroundView
    end

    local removedRouteIDs = {} -- cache to ensure they don't pop up again in laggy situations

    local function getRemovedRouteKey(info)
        return string.format("%s_%d", info.tribeID, info.routeID)
    end

    local function createListItem(listView, routeInfo)
        local objectInfo = routeInfo.otherObjectInfo
        local rowBackgroundView = createRowBackground(listView)

        local toggleButton = uiStandardButton:create(rowBackgroundView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        toggleButton.baseOffset = vec3(-4, -4, 0)
        local removeButton = nil

        local function getEnableButtonText(disabled)
            if disabled then
                return locale:get("ui_action_enable")
            end
            return locale:get("ui_action_disable")
        end

        uiStandardButton:setToggleState(toggleButton, not routeInfo.disabled)
        uiStandardButton:setClickFunction(toggleButton, function()
            local disabled = (not uiStandardButton:getToggleState(toggleButton))
            logicInterface:callServerFunction("changeLogisticsRouteConfig", {
                tribeID = routeInfo.tribeID,
                routeID = routeInfo.routeID,
                disabled = disabled
            })
            uiToolTip:updateText(toggleButton.userData.backgroundView, getEnableButtonText(disabled), nil, false)
        end)

        uiToolTip:add(toggleButton.userData.backgroundView, 
        ViewPosition(MJPositionCenter, MJPositionBelow), 
        getEnableButtonText(routeInfo.disabled), 
        nil, vec3(0,-8,10), 
        nil, 
        toggleButton, 
        listView)

        removeButton = uiStandardButton:create(rowBackgroundView, vec2(26,26), uiStandardButton.types.slim_1x1)
        removeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
        removeButton.baseOffset = vec3(-4, 4, 3)
        uiStandardButton:setIconModel(removeButton, "icon_crossRed")
        uiStandardButton:setClickFunction(removeButton, function()
            uiScrollView:removeRow(listView, rowBackgroundView)
            removedRouteIDs[getRemovedRouteKey(routeInfo)] = true
            logicInterface:callServerFunction("removeLogisticsRoute", {
                tribeID = routeInfo.tribeID,
                routeID = routeInfo.routeID,
            })
        end)
        uiToolTip:add(removeButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_action_remove"), nil, vec3(0,-8,10), nil, removeButton, listView)

        local zoomButton = uiStandardButton:create(rowBackgroundView, vec2(26,26), uiStandardButton.types.slim_1x1)
        zoomButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        zoomButton.baseOffset = vec3(4, -4, 0)
        uiStandardButton:setIconModel(zoomButton, "icon_inspect")
        uiStandardButton:setClickFunction(zoomButton, function()
            if objectInfo then
                logicInterface:callLogicThreadFunction("retrieveObject", objectInfo.uniqueID, function(result)
                    if result and result.found then
                        gameUI:followObject(result, false, {dismissAnyUI = true, showInspectUI = true, completActionIndex = 1})
                    else
                        gameUI:teleportToLookAtPos(objectInfo.pos)
                    end
                end)
            end
        end)
        uiToolTip:add(zoomButton.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), locale:get("ui_action_zoom"), nil, vec3(0,-8,10), nil, zoomButton, listView)

        local nameTextView = TextView.new(rowBackgroundView)
        nameTextView.color = mj.textColor
        nameTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        nameTextView.baseOffset = vec3(34,-6,0)
        nameTextView.font = Font(uiCommon.fontName, 16)
        local nameText = nil
        if objectInfo.name then
            nameText = objectInfo.name
        else
            nameText = gameObject.types[objectInfo.objectTypeIndex].name
        end
        nameTextView.text = nameText--logisticsUIHelper:getLogisticsObjectNameText(objectInfo.name, objectInfo.objectTypeIndex, objectInfo.storedCount, objectInfo.contentsStorageTypeIndex)


        local contentsGameObjectView = uiGameObjectView:create(rowBackgroundView, vec2(26,26), uiGameObjectView.types.standard)
        contentsGameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        contentsGameObjectView.baseOffset = vec3(4,-30,1)
        
        local iconObjectInfo = {
            objectTypeIndex = objectInfo.displayObjectTypeIndex,
        }

        uiGameObjectView:setObject(contentsGameObjectView, iconObjectInfo, nil, nil)

        local contentsTextView = TextView.new(rowBackgroundView)
        contentsTextView.color = mj.textColor
        contentsTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        contentsTextView.baseOffset = vec3(34,-32,0)
        contentsTextView.font = Font(uiCommon.fontName, 16)
        
        if objectInfo.contentsStorageTypeIndex and objectInfo.contentsStorageTypeIndex > 0 then
            local objectCountToDisplay = 0
            if objectInfo.storedCount and objectInfo.storedCount > 0 then
                objectCountToDisplay = objectInfo.storedCount or 0
            end
            contentsTextView.text = storage.types[objectInfo.contentsStorageTypeIndex].name .. " (" .. mj:tostring(objectCountToDisplay) .. ")"
        else
            contentsTextView.text = locale:get("misc_Empty")
        end
        
    end
    
    if uiRoutesResult then
        if uiRoutesResult.receiveRoutes then
            backgroundColorCounter = 1
            for i,info in ipairs(uiRoutesResult.receiveRoutes) do
                if not removedRouteIDs[getRemovedRouteKey(info)] then
                    createListItem(receiveRoutesListView, info)
                end
            end
        end
        if uiRoutesResult.sendRoutes then
            backgroundColorCounter = 1
            for i,info in ipairs(uiRoutesResult.sendRoutes) do
                if not removedRouteIDs[getRemovedRouteKey(info)] then
                    createListItem(sendRoutesListView, info)
                end
            end
        end
    end

        --todo update list

    
end

local function updateMaxQuantitySliderTextValue(newValue)
    local function addContentsCountText(baseText)
        if storageAreaObject then
            local sharedState = storageAreaObject.sharedState
            local settingsToUse = sharedState.settingsByTribe[storageAreaSettingsTribeID]
            local storageTypeIndex = settingsToUse and settingsToUse.restrictStorageTypeIndex
            if (not storageTypeIndex) or (storageTypeIndex <= 0) then
                storageTypeIndex = sharedState.contentsStorageTypeIndex
            end
            if storageTypeIndex and storageTypeIndex > 0 then
                local storageType = storage.types[storageTypeIndex]

                local storageMaxItems = storage:maxItemsForStorageType(storageTypeIndex, gameObject.types[storageAreaObject.objectTypeIndex].storageAreaDistributionTypeIndex)
               -- mj:log("hi:", storageMaxItems, " foo:", gameObject.types[storageAreaObject.objectTypeIndex].storageAreaDistributionTypeIndex, " storageAreaObject.objectTypeIndex:", storageAreaObject.objectTypeIndex, " gae:", gameObject.types[storageAreaObject.objectTypeIndex])
                local maxItems = math.floor(newValue * storageMaxItems)

                maxItems = mjm.clamp(maxItems, 1, storageMaxItems)
                return string.format("%s (%d %s)", baseText, maxItems, storageType.name)
            end
        end
        return baseText
    end

    local percentage = newValue * 100.0

    if percentage >= 99.5 then
        local text = locale:get("misc_max")
        maxQuantityCountTextView.text = addContentsCountText(text)
    elseif percentage <= 0.0001 then
        maxQuantityCountTextView.text = locale:get("misc_acceptNone")
    elseif percentage > 10.0 then
        local text = string.format("%d%%", percentage)
        maxQuantityCountTextView.text = addContentsCountText(text)
    elseif percentage < 0.1 then
        local text = "<0.1%"
        maxQuantityCountTextView.text = addContentsCountText(text)
    else
        local text = string.format("%.1f%%", percentage)
        maxQuantityCountTextView.text = addContentsCountText(text)
    end
end

local maxQuantityPower = 0.33
local maxQuantityPowerInverse = 1.0 / 0.33

local function maxQuantityFractionToSliderValue(maxQuantityFraction)
    return mjm.clamp(math.pow(maxQuantityFraction, maxQuantityPower) * 1000, 0, 1000)
end

local function maxQuantitySliderValueToFraction(sliderValue)
    return mjm.clamp(math.pow(sliderValue * 0.001, maxQuantityPowerInverse), 0.0, 1.0)
end


local function getStorageInfoText(object)
	if object.sharedState.contentsStorageTypeIndex then
		local count = 0
		local inventory = object.sharedState.inventory
		if inventory then
			if inventory.objects then
				count = #inventory.objects
			end
		end

		if count > 0 then
			return storage.types[object.sharedState.contentsStorageTypeIndex].name .. " (" .. mj:tostring(count) .. ")"
		else
			return storage.types[object.sharedState.contentsStorageTypeIndex].name
		end
	end
	return nil
end


local usageProgressIcons = nil

local function update(forceUpdateOfItemLists)
    usageProgressIcons = nil
    
    local infoText = getStorageInfoText(storageAreaObject)
    inspectUI:setModalPanelTitleAndObject(storageAreaObject.sharedState.name or gameObject.types[storageAreaObject.objectTypeIndex].name, storageAreaObject, infoText)

    local sharedState = storageAreaObject.sharedState
    local tribeSettings = sharedState.settingsByTribe[storageAreaSettingsTribeID] or {}

    local maxQuantitySliderValue = 1000
    if tribeSettings.maxQuantityFraction then
        maxQuantitySliderValue = maxQuantityFractionToSliderValue(tribeSettings.maxQuantityFraction)
    end
    uiSlider:setValue(maxQuantitySlider, maxQuantitySliderValue)
    updateMaxQuantitySliderTextValue(tribeSettings.maxQuantityFraction or 1.0)

    local removeAllItems = false
    if tribeSettings.removeAllItems then
        removeAllItems = true
    end
    uiStandardButton:setToggleState(removeAllItemsToggleButton, removeAllItems)

    local destroyAllItems = false
    if tribeSettings.destroyAllItems then
        destroyAllItems = true
    end
    uiStandardButton:setToggleState(destroyAllItemsToggleButton, destroyAllItems)
    

    updateAllowItemUseButton(removeAllItems, getAllowUseValue(tribeSettings))

    uiScrollView:removeAllRows(contentsListView)
    local inventory = sharedState.inventory

    if inventory and inventory.objects then

        local countsByResourceTypeIndex = nil

        local function sortGroup(a,b)

            if a.objectTypeIndex ~= b.objectTypeIndex then
                local resourceTypeIndexA = gameObject.types[a.objectTypeIndex].resourceTypeIndex
                local resourceTypeIndexB = gameObject.types[b.objectTypeIndex].resourceTypeIndex
                if resourceTypeIndexA ~= resourceTypeIndexB then
                    return (countsByResourceTypeIndex[resourceTypeIndexA] or 0) > (countsByResourceTypeIndex[resourceTypeIndexB] or 0)
                end
            end

            return a.count > b.count
        end
        
        local function getHash(objectTypeIndex, bucket)
            local hash = mj:tostring(objectTypeIndex)
            if bucket then
                hash = hash .. "_d" .. mj:tostring(bucket)
            end
            return hash
        end

        local function createObjectAdditionInfo(objectInfo)
            local worldTime = world:getWorldTime()

            local evolutionDuration = evolvingObject:getEvolutionDuration(objectInfo.objectTypeIndex, objectInfo.fractionDegraded, objectInfo.degradeReferenceTime, worldTime, sharedState.covered)
            local evolutionBucket = nil
            
            
            local fractionDegraded = 0.0
            if objectInfo.fractionDegraded then
                local evolution = evolvingObject.evolutions[objectInfo.objectTypeIndex]
                if evolution then
                    fractionDegraded = hubUIUtilities:getTrueFractionDegraded(objectInfo.fractionDegraded, objectInfo.degradeReferenceTime, worldTime, evolution, sharedState.covered)
                end
            end

            local usageBucket = nil

            if evolutionDuration then
                evolutionBucket = evolvingObject:getEvolutionBucket(evolutionDuration)
            else 
                usageBucket = tool:getUsageThresholdIndexForFraction(fractionDegraded)
            end
            local hash = getHash(objectInfo.objectTypeIndex, evolutionBucket or usageBucket)
            return {
                hash = hash,
                evolutionDuration = evolutionDuration,
                evolutionBucket = evolutionBucket,
                fractionDegraded = fractionDegraded,
                usageBucket = usageBucket
            }
        end

        local function createGroupInfo(baseObjectInfo, baseObjectAdditionInfo)
            local groupInfo = {
                objectTypeIndex = baseObjectInfo.objectTypeIndex,
                count = 0,
                evolutionBucket = baseObjectAdditionInfo.evolutionBucket,
                usageBucket = baseObjectAdditionInfo.usageBucket,
                totalDuration = 0.0,
                totalDegraded = 0.0,
                portionCount = 0,
            }

            return groupInfo
        end

        local orderedGroups = nil
        local groupsByHash = nil

        local function createGroups()
            orderedGroups = {}
            groupsByHash = {}
            countsByResourceTypeIndex = {}
            for i,objectInfo in ipairs(inventory.objects) do
                local objectAdditionInfo = createObjectAdditionInfo(objectInfo)
                local hash = objectAdditionInfo.hash
                local groupInfo = groupsByHash[hash]
                if not groupInfo then
                    groupInfo = createGroupInfo(objectInfo, objectAdditionInfo)
                    table.insert(orderedGroups, groupInfo)
                    groupsByHash[hash] = groupInfo
                end
                groupInfo.count = groupInfo.count + 1
                local resourceTypeIndex = gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex
                countsByResourceTypeIndex[resourceTypeIndex] = (countsByResourceTypeIndex[resourceTypeIndex] or 0) + 1
                groupInfo.totalDegraded = groupInfo.totalDegraded + objectAdditionInfo.fractionDegraded
                if objectAdditionInfo.evolutionDuration then
                    groupInfo.totalDuration = groupInfo.totalDuration + objectAdditionInfo.evolutionDuration
                end

                local foodPortionCount = resource:getFoodPortionCount(objectInfo.objectTypeIndex)
                if foodPortionCount then
                    groupInfo.portionCount = groupInfo.portionCount + (foodPortionCount - (objectInfo.usedPortionCount or 0))
                end
            end
            
            table.sort(orderedGroups, sortGroup)
           -- mj:log("inspect storage panel createGroups:", orderedGroups)
        end

        
        local function updateGroups()
            for i,groupInfo in ipairs(orderedGroups) do
                groupInfo.count = 0
                groupInfo.totalDegraded = 0
                groupInfo.portionCount = 0
                groupInfo.totalDuration = 0
            end

            for i,objectInfo in ipairs(inventory.objects) do
                local objectAdditionInfo = createObjectAdditionInfo(objectInfo)
                local hash = objectAdditionInfo.hash
                local groupInfo = groupsByHash[hash]
                if groupInfo then
                    groupInfo.count = groupInfo.count + 1
                    groupInfo.totalDegraded = groupInfo.totalDegraded + objectAdditionInfo.fractionDegraded
                    if objectAdditionInfo.evolutionDuration then
                        groupInfo.totalDuration = groupInfo.totalDuration + objectAdditionInfo.evolutionDuration
                    end

                    local foodPortionCount = resource:getFoodPortionCount(objectInfo.objectTypeIndex)
                    if foodPortionCount then
                        groupInfo.portionCount = groupInfo.portionCount + (foodPortionCount - (objectInfo.usedPortionCount or 0))
                    end
                else --number of groups has changed, lets recreate the whole thing
                    update(false)
                    return
                end
            end

            
            for i,groupInfo in ipairs(orderedGroups) do
                if groupInfo.count == 0 then --number of groups has changed, lets recreate the whole thing
                    update(false)
                    return
                end
            end


            table.sort(orderedGroups, sortGroup)
            --mj:log("inspect storage panel orderedGroups:", orderedGroups)
        end

        createGroups()



        local counter = 0.0
        leftPaneView.update = function(dt)
            if usageProgressIcons then
                counter = counter + dt
                if counter > 1.0 then
                    counter = 0.0
                    updateGroups()
                    for i,groupInfo in ipairs(orderedGroups) do
                        local usageProgressIcon = usageProgressIcons[i]
                        if usageProgressIcon then
                            usageProgressIcon:setRadialMaskFraction(groupInfo.totalDegraded / groupInfo.count)
                        end
                    end
                end
            end
        end

        --mj:log("orderedGroups:", orderedGroups)

        usageProgressIcons = {}

        for i,groupInfo in ipairs(orderedGroups) do
            local groupView = ColorView.new(contentsListView)
            
            local backgroundColor = vec4(0.0,0.0,0.0,0.5)
            if i % 2 == 1 then
                backgroundColor = vec4(0.03,0.03,0.03,0.5)
            end

            groupView.color = backgroundColor
            groupView.size = vec2(contentsListView.size.x - 20, contentsViewItemHeight)
            groupView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            
            local gameObjectView = uiGameObjectView:create(groupView, contentsViewItemObjectImageViewSize, uiGameObjectView.types.standard)
            gameObjectView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
            --gameObjectView.baseOffset = vec3(0,-10, 2)
            uiGameObjectView:setObject(gameObjectView, {
                objectTypeIndex = groupInfo.objectTypeIndex
            }, nil, nil)

            local objectTitleTextView = TextView.new(groupView)
            objectTitleTextView.font = Font(uiCommon.fontName, 16)
            objectTitleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
            objectTitleTextView.relativeView = gameObjectView
            
            
            local textString = gameObject:stringForObjectTypeAndCount(groupInfo.objectTypeIndex, groupInfo.count)

            if groupInfo.portionCount ~= 0 then
                textString = textString .. ": " .. locale:get("ui_portionCount", {portionCount = groupInfo.portionCount})
            end

            objectTitleTextView.text = textString


            if (groupInfo.usageBucket and groupInfo.totalDegraded > 0.001) or groupInfo.evolutionBucket then

                local usageIcon = View.new(groupView)
                usageIcon.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
                usageIcon.baseOffset = vec3(-5,0,2)
                usageIcon.masksEvents = true
                --[[usageIcon:setModel(model:modelIndexForName("icon_circle_filled"), {
                    default = material.types.ui_background_dark.index
                })]]

                local iconHalfSize = 12
               -- usageIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
                usageIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
                
                local usageProgressIcon = ModelView.new(groupView)
                usageProgressIcon.masksEvents = false
                usageProgressIcon.relativeView = usageIcon
                usageProgressIcon.baseOffset = vec3(0, 0, 1)
                usageProgressIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
                usageProgressIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0
                
                local toolTipOffset = vec3(0,8,4)

                usageProgressIcon:setRadialMaskFraction(groupInfo.totalDegraded / groupInfo.count)
                usageProgressIcons[i] = usageProgressIcon

                if groupInfo.usageBucket then

                    uiToolTip:add(usageIcon, ViewPosition(MJPositionCenter, MJPositionAbove), groupInfo.usageBucket.name, nil, toolTipOffset, nil, usageIcon)

                    usageProgressIcon:setModel(model:modelIndexForName("icon_circle_thic"), {
                        default = material.types.ui_red.index
                    })
                else
                    local evolution = evolvingObject.evolutions[groupInfo.objectTypeIndex]
                    uiToolTip:add(usageIcon, ViewPosition(MJPositionCenter, MJPositionAbove), "", nil, toolTipOffset, nil, usageIcon)
                    
                    uiToolTip:addColoredTitleText(usageIcon, evolvingObject.categories[evolution.categoryIndex].actionName, evolvingObject.categories[evolution.categoryIndex].color)
                    uiToolTip:addColoredTitleText(usageIcon, " " .. evolvingObject:getName(groupInfo.objectTypeIndex, groupInfo.evolutionBucket), mj.textColor)

                    usageProgressIcon:setModel(model:modelIndexForName("icon_circle_thic"), {
                        default = evolvingObject.categories[evolution.categoryIndex].material
                    })
                    
                    if sharedState.covered then
                        uiToolTip:addColoredTitleText(usageIcon, " " .. locale:get("misc_inside"), vec4(0.5,1.0,0.5,1.0))
                    else
                        uiToolTip:addColoredTitleText(usageIcon, " " .. locale:get("misc_outside"), evolvingObject.categories[evolution.categoryIndex].color)
                    end
                end
            end



            --[[local evolution = evolvingObject.evolutions[groupInfo.objectTypeIndex]
            if evolution and groupInfo.degradeBucket then
                local secondsPerHour = world:getDayLength() / 24
                local timeMin = bucketThresholdsHours[groupInfo.degradeBucket] * secondsPerHour
                local timeMax = timeMin
                if groupInfo.degradeBucket < #bucketThresholdsHours then
                    timeMax = bucketThresholdsHours[groupInfo.degradeBucket + 1] * secondsPerHour
                end
                --mj:log("timeMin:", timeMin, " timeMax:", timeMax)

                local timeRangeDescription = locale:getTimeRangeDescription(timeMin, timeMax, world:getDayLength(), world:getYearLength())
                    --english.getTimeRangeDescription(durationSecondsMin, durationSecondsMax, dayLength, yearLength)
                        --local remainingTimeDescription = locale:getTimeDurationDescription(, world:getDayLength(), world:getYearLength())

                local timeRangeDescription = bucketThresholdsHours[groupInfo.degradeBucket].name --todo use localization again

                local objectTimeTextView = TextView.new(groupView)
                objectTimeTextView.font = Font(uiCommon.fontName, 16)
                objectTimeTextView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionCenter)
                objectTimeTextView.baseOffset = vec3(-8,0, 0)
                objectTimeTextView.text = locale:get("evolution_timeFunc", {
                    actionName = evolvingObject.categories[evolution.categoryIndex].actionName,
                    time = timeRangeDescription
                })
            end]]

            --objectTitleTextView.baseOffset = vec3(10,0, 0)
            
            
            uiScrollView:insertRow(contentsListView, groupView, nil)

        end
    end

    local restrictStorageTypeIndex = getRestrictStorageTypeIndexValue(tribeSettings)
    
    if forceUpdateOfItemLists or prevRestrictStorageAreaObjectID ~= storageAreaObject.uniqueID or prevRestrictStorageTypeIndex ~= restrictStorageTypeIndex then
        logicInterface:callServerFunction("getUIRoutesForStorageArea", storageAreaObjectID, function(uiRoutesResult)
            prevRestrictStorageAreaObjectID = storageAreaObject.uniqueID
            prevRestrictStorageTypeIndex = restrictStorageTypeIndex

            local itemList = {
                {
                    name = locale:get("misc_acceptAll"),
                    iconObjectTypeIndex = gameObject.types.storageArea.index,
                    storageTypeIndex = 0,
                },
                {
                    name = locale:get("misc_acceptNone"),
                    iconModelName = "icon_cancel",
                    iconModelMaterialRemapTable = {
                        default = material.types.red.index
                    },
                    storageTypeIndex = -1,
                }
            }
            local selectionIndex = 1
            
            local contentsStorageTypeIndex = sharedState.contentsStorageTypeIndex

            if restrictStorageTypeIndex ~= nil then
                if restrictStorageTypeIndex == 0 then
                    selectionIndex = 1
                elseif restrictStorageTypeIndex == -1 then
                    selectionIndex = 2
                else
                    selectionIndex = 3
                end
                
                if restrictStorageTypeIndex > 0 then
                    table.insert(itemList, {
                        name = storage.types[restrictStorageTypeIndex].name,
                        iconObjectTypeIndex = storage.types[restrictStorageTypeIndex].displayGameObjectTypeIndex,
                        storageTypeIndex = restrictStorageTypeIndex,
                    })
                end
            end

            if tribeSettings.destroyAllItems then
                if selectionIndex == 1 then
                    selectionIndex = 2
                end
                itemList[1].disabled = true
                itemList[1].name = locale:get("misc_uncheckDestroyFirst")
            end
            
            local storageAreaDistributionTypeIndex = gameObject.types[storageAreaObject.objectTypeIndex].storageAreaDistributionTypeIndex
            
            if contentsStorageTypeIndex and contentsStorageTypeIndex ~= restrictStorageTypeIndex then
                local item = {
                    name = storage.types[contentsStorageTypeIndex].name,
                    iconObjectTypeIndex = storage.types[contentsStorageTypeIndex].displayGameObjectTypeIndex,
                    storageTypeIndex = contentsStorageTypeIndex,
                }

                if storage:maxItemsForStorageType(contentsStorageTypeIndex, storageAreaDistributionTypeIndex) == 0 then
                    item.disabled = true
                end

                table.insert(itemList, item)
            end

            local afterContentsStartIndex = #itemList

            local function storageTypeMatchesRoute(storageTypeIndex)
                if uiRoutesResult then
                    if uiRoutesResult.receiveRoutes then
                        for i,routeInfo in ipairs(uiRoutesResult.receiveRoutes) do
                            if routeInfo.otherObjectInfo.contentsStorageTypeIndex == storageTypeIndex then
                                return true
                            end
                        end
                    end
                    if uiRoutesResult.sendRoutes then
                        for i,routeInfo in ipairs(uiRoutesResult.sendRoutes) do
                            if routeInfo.otherObjectInfo.contentsStorageTypeIndex == storageTypeIndex then
                                return true
                            end
                        end
                    end
                end
                return false
            end
            
            
            for i,storageType in ipairs(storage.alphabeticallyOrderedTypes) do
                if storageType.index ~= restrictStorageTypeIndex and storageType.index ~= contentsStorageTypeIndex then
                    local areaDistributionInfo = storage.areaDistributions[storageAreaDistributionTypeIndex]
                    if (not areaDistributionInfo.whitelistType) or (storageType.whitelistTypes and storageType.whitelistTypes[areaDistributionInfo.whitelistType]) then
                        local foundResource = false
                        for j,resourceTypeIndex in ipairs(storage.types[storageType.index].resources) do
                            if world:tribeHasSeenResource(resourceTypeIndex) then
                                foundResource = true
                                break
                            end
                        end

                        if foundResource then
                            local item = {
                                name = storageType.name,
                                iconObjectTypeIndex = storageType.displayGameObjectTypeIndex,
                                storageTypeIndex = storageType.index,
                            }
                            
                            if storage:maxItemsForStorageType(storageType.index, storageAreaDistributionTypeIndex) == 0 then
                                item.disabled = true
                                item.name = item.name .. " (" .. locale:get("misc_needsLargerStorageArea") .. ")"
                                
                            end

                            if storageTypeMatchesRoute(storageType.index) then
                                table.insert(itemList, afterContentsStartIndex + 1, item)
                            else
                                table.insert(itemList, item)
                            end
                        end
                    end
                end
            end

            --mj:log("itemList:", itemList)

            uiPopUpButton:setItems(restrictStorageTypeButton, itemList, selectionIndex)

            updateObjectTypes()
            updateRoutesListViews(uiRoutesResult)
        end)
    end
end


local function restrictStorageTypeSelectionChanged(selectedIndex, selectedInfo)
    
    logicInterface:callServerFunction("changeStorageAreaConfig", {
        settingsTribeID = storageAreaSettingsTribeID,
        storageAreaObjectID = storageAreaObjectID,
        restrictStorageTypeIndex = selectedInfo.storageTypeIndex,
    })
    if not storageAreaObject.sharedState.settingsByTribe then
        storageAreaObject.sharedState.settingsByTribe = {}
    end
    
    if not storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID] then
        storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID] = {}
    end
    storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID].restrictStorageTypeIndex = selectedInfo.storageTypeIndex
    updateObjectTypes()
end


local changeInProgress = false
local function addRoute(fromStorageAreaObjectID, toStorageAreaObjectID)
    if changeInProgress then
        return
    end

    changeInProgress = true
    logicInterface:createLogisticsRoute(fromStorageAreaObjectID, toStorageAreaObjectID, function(uiRouteInfo)
        changeInProgress = false
        if uiRouteInfo then
            gameUI:hideAllUI(false)
            storageLogisticsDestinationsUI:show(uiRouteInfo)
        end
    end)
end

function inspectStoragePanel:load(inspectUI_, inspectObjectUI, world_, gameUI_, manageUI_, parentContainerView)

    inspectUI = inspectUI_
    world = world_
    --manageUI = manageUI_
    gameUI = gameUI_

    local topPadding = 60
    local bottomPadding = 10
    local containerView = View.new(parentContainerView)
    containerView.size = vec2(parentContainerView.size.x, parentContainerView.size.y - topPadding - bottomPadding)
    containerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    containerView.baseOffset = vec3(0,bottomPadding, 0)


    local leftPaneViewSize = vec2(containerView.size.x * 0.5 - 30, containerView.size.y)
    local rightPaneViewSize = vec2(containerView.size.x * 0.5 - 30, containerView.size.y)

    leftPaneView = View.new(containerView)
    leftPaneView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    leftPaneView.baseOffset = vec3(20,0.0, 0)
    leftPaneView.size = leftPaneViewSize
    
    rightPaneView = View.new(containerView)
    rightPaneView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightPaneView.baseOffset = vec3(-20,0.0, 0)
    rightPaneView.size = rightPaneViewSize

    
    leftPaneTopView = View.new(leftPaneView)
    leftPaneTopView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    leftPaneTopView.size = vec2(leftPaneViewSize.x, leftPaneViewSize.y * 0.5)

    leftPaneBotView = View.new(leftPaneView)
    leftPaneBotView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    leftPaneBotView.size = vec2(leftPaneViewSize.x, leftPaneViewSize.y * 0.5)
    
    local rightPaneTopView = View.new(rightPaneView)
    rightPaneTopView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    rightPaneTopView.size = vec2(rightPaneViewSize.x, rightPaneViewSize.y * 0.4)

    local rightPaneBotView = View.new(rightPaneView)
    rightPaneBotView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    rightPaneBotView.size = vec2(rightPaneViewSize.x, rightPaneViewSize.y * 0.6)

    
    --local titleX = -leftPaneView.size.x * 0.5 - 50
    local startYOffset = -10
    local yOffset = startYOffset
    local yOffsetBetweenElements = 40

    --left
    --left top
    
    local contentsTitleTextView = TextView.new(leftPaneTopView)
    contentsTitleTextView.font = Font(uiCommon.fontName, 16)
    contentsTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    contentsTitleTextView.baseOffset = vec3(0,startYOffset, 0)
    contentsTitleTextView.text = locale:get("misc_items") .. ":"

    
    local insetViewSize = vec2(leftPaneTopView.size.x, leftPaneTopView.size.y - 20 + startYOffset - 10 - 40)
    local scrollViewSize = vec2(insetViewSize.x - 10, insetViewSize.y - 10)
    local insetView = ModelView.new(leftPaneTopView)
    insetView:setModel(model:modelIndexForName("ui_inset_sm_4x3"))
    local scaleToUsePaneX = insetViewSize.x * 0.5
    local scaleToUsePaneY = insetViewSize.y * 0.5 / 0.75
    insetView.scale3D = vec3(scaleToUsePaneX,scaleToUsePaneY,scaleToUsePaneX)
    insetView.size = insetViewSize
    insetView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    insetView.baseOffset = vec3(0,-20 + startYOffset - 10, 0)

    contentsListView = uiScrollView:create(insetView, scrollViewSize, MJPositionInnerLeft)
    contentsListView.baseOffset = vec3(0, 0, 2)

    
    -- left bot

    -- left bot left


    local leftPaneBotLeftView = View.new(leftPaneBotView)
    leftPaneBotLeftView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    leftPaneBotLeftView.size = vec2(leftPaneBotView.size.x, leftPaneBotView.size.y)
    
    local specialOrdersTextView = TextView.new(leftPaneBotLeftView)
    specialOrdersTextView.font = Font(uiCommon.fontName, 16)
    specialOrdersTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    specialOrdersTextView.baseOffset = vec3(0,yOffset, 0)
    specialOrdersTextView.text = locale:get("misc_specialOrders") .. ":"

    local elementTitleX = -leftPaneBotLeftView.size.x * 0.5
    local elementControlX =  leftPaneBotLeftView.size.x * 0.5 + 10.0
    
    local function addToggleButton(toggleButtonTitle, isRed, changedFunction)

        local textColor = mj.textColor
        if isRed then
            textColor = vec4(1.0,0.5,0.5,1.0)
        end

        local toggleButton = uiStandardButton:create(leftPaneBotLeftView, vec2(26,26), uiStandardButton.types.toggle)
        toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        toggleButton.baseOffset = vec3(elementControlX, yOffset + 4, 0)
       -- uiStandardButton:setToggleState(toggleButton, toggleValue)

        if isRed then
            uiStandardButton:setToggleButtonHighlightMaterial(toggleButton, material.types.ui_red.index)
        end
        
        local textView = TextView.new(leftPaneBotLeftView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.color = textColor
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX,yOffset, 0)
        textView.text = toggleButtonTitle
    
        if changedFunction then
            uiStandardButton:setClickFunction(toggleButton, function()
                changedFunction(uiStandardButton:getToggleState(toggleButton))
            end)
        end

        yOffset = yOffset - yOffsetBetweenElements

        return toggleButton, textView
    end

    local sliderOffset = -100
    
    local function addSlider(parentView, sliderTitle, defaultCountText, min, max, value, changedFunction, continuousFunctionOrNil)
        local textView = TextView.new(parentView)
        textView.font = Font(uiCommon.fontName, 16)
        textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        textView.baseOffset = vec3(elementTitleX + sliderOffset,yOffset, 0)
        textView.text = sliderTitle

        local options = nil
        local baseFunction = changedFunction
        if continuousFunctionOrNil then
            options = {
                continuous = true,
                releasedFunction = changedFunction
            }
            baseFunction = continuousFunctionOrNil
        end
        
        local sliderView = uiSlider:create(parentView, vec2(200, 20), min, max, value, options, baseFunction)
        sliderView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
        sliderView.baseOffset = vec3(elementControlX - 5 + sliderOffset, yOffset - 2, 0)

        
        local sliderCountView = TextView.new(parentView)
        sliderCountView.font = Font(uiCommon.fontName, 16)
        sliderCountView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
        sliderCountView.relativeView = sliderView
        sliderCountView.baseOffset = vec3(5,0, 0)
        sliderCountView.text = defaultCountText

        for i=0,8 do
            local checkSize = vec2(2, 6)
            if i % 4 == 0 then
                checkSize.y = 10
            end
            local checkView = ModelView.new(parentView)
            checkView:setModel(model:modelIndexForName("ui_verticalLine"), {
                default = material.types.ui_disabled.index
            })
            local scaleToUseCheckX = checkSize.x * 0.5 / 0.2
            local scaleToUseCheckY = checkSize.y * 0.5
            checkView.scale3D = vec3(scaleToUseCheckX,scaleToUseCheckY,scaleToUseCheckY)
            checkView.size = checkSize
            checkView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
            checkView.relativeView = sliderView
            local fraction = i / 8.0
            fraction = math.pow(fraction, maxQuantityPower)
            checkView.baseOffset = vec3(8.0 + (fraction * (sliderView.size.x - 20.0)), 6, 0.5)
        end

        yOffset = yOffset - yOffsetBetweenElements
        --uiSelectionLayout:addView(parentView, sliderView)
        return sliderView,sliderCountView
    end

    yOffset = yOffset - yOffsetBetweenElements

    allowItemUseToggleButton = addToggleButton(locale:get("misc_allowItemUse") .. ":", false, function(toggleValue)
        sendAllowItemUse(toggleValue)
    end)
    
    removeAllItemsToggleButton = addToggleButton(locale:get("misc_removeAllItems") .. ":", false, function(toggleValue)
        local removeAllItems = toggleValue
        sendRemoveAllItems(removeAllItems)
        local sharedState = storageAreaObject.sharedState
        local tribeSettings = sharedState.settingsByTribe and sharedState.settingsByTribe[storageAreaSettingsTribeID]
        updateAllowItemUseButton(removeAllItems, getAllowUseValue(tribeSettings))
    end)
    
    destroyAllItemsToggleButton = addToggleButton(locale:get("misc_destroyAllItems") .. ":", true, function(toggleValue)
        local destroyAllItems = toggleValue
        sendDestroyAllItems(destroyAllItems)
        local forceUpdateOfItemLists = true
        update(forceUpdateOfItemLists)
    end)

    maxQuantitySlider, maxQuantityCountTextView = addSlider(leftPaneBotLeftView, locale:get("misc_maxQuantity") .. ":", locale:get("misc_max"), 0, 1000, 1000, function(newValue)
        local maxQuantityValue = maxQuantitySliderValueToFraction(newValue)
        sendMaxQuantity(maxQuantityValue)
    end, function(newValue)
        local maxQuantityValue = maxQuantitySliderValueToFraction(newValue)
        updateMaxQuantitySliderTextValue(maxQuantityValue)
    end)
    
    -- left bot right

    yOffset = startYOffset


    --right

    


    local routesInsetViewSize = vec2(rightPaneTopView.size.x / 2 - 5, rightPaneTopView.size.y - 20 + startYOffset - 10 - 40)
    local routesScrollViewSize = vec2(routesInsetViewSize.x - 10, routesInsetViewSize.y - 10)
    local routesScaleToUsePaneX = routesInsetViewSize.x * 0.5
    local routesScaleToUsePaneY = routesInsetViewSize.y * 0.5 / 0.75

    ------------- receive ---------

    local receiveRoutesTitleTextView = TextView.new(rightPaneTopView)
    receiveRoutesTitleTextView.font = Font(uiCommon.fontName, 16)
    receiveRoutesTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    receiveRoutesTitleTextView.baseOffset = vec3(-rightPaneTopView.size.x / 4 - 2,startYOffset, 0)
    receiveRoutesTitleTextView.text = locale:get("misc_receivingItems") .. ":"
    
    local receiveRoutesInsetView = ModelView.new(rightPaneTopView)
    receiveRoutesInsetView:setModel(model:modelIndexForName("ui_inset_sm_4x3"))
    receiveRoutesInsetView.scale3D = vec3(routesScaleToUsePaneX,routesScaleToUsePaneY,routesScaleToUsePaneX)
    receiveRoutesInsetView.size = routesInsetViewSize
    receiveRoutesInsetView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    receiveRoutesInsetView.baseOffset = vec3(0,-20 + startYOffset - 10, 0)

    receiveRoutesListView = uiScrollView:create(receiveRoutesInsetView, routesScrollViewSize, MJPositionInnerLeft)
    receiveRoutesListView.baseOffset = vec3(0, 0, 2)

    local addReceiveRouteButton = uiStandardButton:create(rightPaneTopView, vec2(180,40))
    addReceiveRouteButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    addReceiveRouteButton.relativeView = receiveRoutesInsetView
    addReceiveRouteButton.baseOffset = vec3(0,-10, 0)
    uiStandardButton:setIconModel(addReceiveRouteButton, "icon_receive", nil)
    uiStandardButton:setCenterIconAndText(addReceiveRouteButton, true)
    uiStandardButton:setText(addReceiveRouteButton, locale:get("misc_receiveItems") .. "...")
    uiStandardButton:setClickFunction(addReceiveRouteButton, function()
        addRoute(nil, storageAreaObjectID)
    end)

    ------------send ------------

    local sendRoutesTitleTextView = TextView.new(rightPaneTopView)
    sendRoutesTitleTextView.font = Font(uiCommon.fontName, 16)
    sendRoutesTitleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    sendRoutesTitleTextView.baseOffset = vec3(rightPaneTopView.size.x / 4 + 2,startYOffset, 0)
    sendRoutesTitleTextView.text = locale:get("misc_sendingItems") .. ":"

    local sendRoutesInsetView = ModelView.new(rightPaneTopView)
    sendRoutesInsetView:setModel(model:modelIndexForName("ui_inset_sm_4x3"))
    sendRoutesInsetView.scale3D = vec3(routesScaleToUsePaneX,routesScaleToUsePaneY,routesScaleToUsePaneX)
    sendRoutesInsetView.size = routesInsetViewSize
    sendRoutesInsetView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    sendRoutesInsetView.baseOffset = vec3(0,-20 + startYOffset - 10, 0)

    sendRoutesListView = uiScrollView:create(sendRoutesInsetView, routesScrollViewSize, MJPositionInnerLeft)
    sendRoutesListView.baseOffset = vec3(0, 0, 2)
    
    local addSendRouteButton = uiStandardButton:create(rightPaneTopView, vec2(180,40))
    addSendRouteButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
    addSendRouteButton.relativeView = sendRoutesInsetView
    addSendRouteButton.baseOffset = vec3(0,-10, 0)
    uiStandardButton:setIconModel(addSendRouteButton, "icon_send", nil)
    uiStandardButton:setCenterIconAndText(addSendRouteButton, true)
    uiStandardButton:setText(addSendRouteButton, locale:get("misc_sendItems") .. "...")
    uiStandardButton:setClickFunction(addSendRouteButton, function()
        addRoute(storageAreaObjectID, nil)
    end)

    
    local rightPaneBotRightContentView = View.new(rightPaneBotView)
    rightPaneBotRightContentView.relativePosition = rightPaneBotView.relativePosition
    rightPaneBotRightContentView.size = rightPaneBotView.size

    local rightPaneBotRightPopOversView = View.new(rightPaneBotView)
    rightPaneBotRightPopOversView.relativePosition = rightPaneBotView.relativePosition
    rightPaneBotRightPopOversView.size = vec2(rightPaneBotView.size.x - 20, rightPaneBotView.size.y + 40)

    
    yOffset = yOffset - 40
    
    local restrictContentsTextView = TextView.new(rightPaneBotView)
    restrictContentsTextView.font = Font(uiCommon.fontName, 16)
    restrictContentsTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    restrictContentsTextView.baseOffset = vec3(0,yOffset, 0)
    restrictContentsTextView.text = locale:get("storage_ui_acceptOnly") .. ":"

    --yOffset = yOffset - restrictContentsTextView.size.y - 10
    
    local popUpButtonSize = vec2(200.0, 40)
    local popUpMenuSize = vec2(popUpButtonSize.x + 20, 300)
    restrictStorageTypeButton = uiPopUpButton:create(rightPaneBotRightContentView, rightPaneBotRightPopOversView, popUpButtonSize, popUpMenuSize)
    restrictStorageTypeButton.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    restrictStorageTypeButton.relativeView = restrictContentsTextView
    --restrictStorageTypeButton.baseOffset = vec3(0,yOffset, 0)
    restrictStorageTypeButton.baseOffset = vec3(10,0, 0)
    uiPopUpButton:setSelectionFunction(restrictStorageTypeButton, restrictStorageTypeSelectionChanged)

    local popupSelectionCombinedWidth = popUpButtonSize.x + restrictStorageTypeButton.baseOffset.x + restrictContentsTextView.size.x

    restrictContentsTextView.baseOffset = vec3(rightPaneBotView.size.x * 0.5 - popupSelectionCombinedWidth * 0.5, restrictContentsTextView.baseOffset.y, restrictContentsTextView.baseOffset.z)

    yOffset = yOffset - restrictStorageTypeButton.size.y

    
    local restrictInsetViewSize = vec2(rightPaneBotRightContentView.size.x, rightPaneBotRightContentView.size.y + yOffset - 10)
    local restrictScrollViewSize = vec2(restrictInsetViewSize.x - 10, restrictInsetViewSize.y - 10)
    local restrictInsetView = ModelView.new(rightPaneBotRightContentView)
    restrictInsetView:setModel(model:modelIndexForName("ui_inset_sm_4x3"))
    local restrictScaleToUsePaneX = restrictInsetViewSize.x * 0.5
    local restrictScaleToUsePaneY = restrictInsetViewSize.y * 0.5 / 0.75
    restrictInsetView.scale3D = vec3(restrictScaleToUsePaneX,restrictScaleToUsePaneY,restrictScaleToUsePaneX)
    restrictInsetView.size = restrictInsetViewSize
    restrictInsetView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    restrictInsetView.baseOffset = vec3(0, yOffset, 0)

    restrictContentsListView = uiScrollView:create(restrictInsetView, restrictScrollViewSize, MJPositionInnerLeft)
    restrictContentsListView.baseOffset = vec3(0, 0, 2)
    
end



function inspectStoragePanel:show(storageAreaObject_)

    storageAreaObject = storageAreaObject_
    storageAreaObjectID = storageAreaObject.uniqueID
    storageAreaSettingsTribeID = storageSettings:getSettingsTribeIDToUse(storageAreaObject.sharedState, world.tribeID, world:getServerClientState().privateShared.tribeRelationsSettings)
    if not storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID] then
        storageAreaObject.sharedState.settingsByTribe[storageAreaSettingsTribeID] = {}
    end
    --(storageAreaObject.sharedState)

    local forceUpdateOfItemLists = true
    update(forceUpdateOfItemLists)
end

function inspectStoragePanel:updateObjectInfo(storageAreaObject_) --may be a different object, but panel was already displayed.
    inspectStoragePanel:show(storageAreaObject_)
end



function inspectStoragePanel:popUI()
    return false
end

return inspectStoragePanel