local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local gameConstants = mjrequire "common/gameConstants"
local model = mjrequire "common/model"
local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local material = mjrequire "common/material"
local research = mjrequire "common/research"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiComplexTextView = mjrequire "mainThread/ui/uiCommon/uiComplexTextView"
--local clientGameSettings = mjrequire "mainThread/clientGameSettings"
--local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local audio = mjrequire "mainThread/audio"
local discoveryUI = mjrequire "mainThread/ui/discoveryUI"
local tribeRelationsUI = mjrequire "mainThread/ui/tribeRelationsUI"

local locale = mjrequire "common/locale"
local eventManager = mjrequire "mainThread/eventManager"
local timer = mjrequire "common/timer"
--local mapModes = mjrequire "common/mapModes"

local gameUI = nil
local localPlayer = nil
local world = nil
local intro = nil
local logicInterface = nil
local tutorialStoryPanel = nil
local clientWorldSettingsDatabase = nil
local showTutorial = true
local disabled = false

local notificationIsVisible = false

local maxSimultaneousCount = 2

local tutorialUI = {}

local timerID = nil
--local queuedTipTypeIndex = nil
--local displayIsQueued = false
local delayBetweenTips = 4.0
local hideDelayAfterCompletingTasks = 4.0
local delayAfterBlockingUIDismissed = 2.0
local delayBeforeFirstTip = 10.0
local queueNextTipDelayTimer = delayBeforeFirstTip
local incrementTimer = 0.0
--local hideDelayTimer = nil

local currentTipOrderIndex = nil

local currentTipTypeInfos = {}

--local hidden = true

local mainView = nil
--local panelView = nil
--local titleTextView = nil
--local tickView = nil

local panelXOffset = -24.0
local baseYOffset = 16.0
local slideAnimationOffset = -500.0
local panelBaseZOffset = 10
local paddingBetweenPanels = 10.0
--local slideAnimationTimer = 0.0

local tickHalfSize = 18.0
local itemTickHalfSize = 10.0

local subTipWrapWidth = 300.0
local subtitleTabWidth = 0.0--10.0

local tutorialState = nil

local hasTribeID = false

local function resetTutorialState()
    tutorialState = {
        movementComplete = false,
        clearPlanHasBeenIssued = false,
        hasClearedXGrassTiles = false,
        grassClearCount = 0,

        playerHasToggledPause = false,
        playerHasToggledFastForward = false,

        hasPlacedXStorageAreas = false,
        storageAreaPlaceCount = 0,
        hasStoredHay = false,
        storeHayCount = 0,
        hasStoredBranches = false,
        storeBranchCount = 0,

        multiSelectComplete = false,

        bedPlaceCount = 0,
        hasPlacedXBeds = false,
        bedBuiltCount = 0,
        hasBuiltXBeds = false,

        roleAssignmentComplete = false,

        researchBranchComplete = false,
        researchRockComplete = false,
        researchHayComplete = false,

        craftAreaBuiltCount = 0,
        hasBuiltXCraftAreas = false,
        craftHandAxeCount = 0,
        hasCraftedXHandAxes = false,
        craftKnifeCount = 0,
        hasCraftedXKnives = false,
        
        hasPlacedCampfire = false,
        hasLitCampfire = false,
        hasPlacedThatchHut = false,
        hasBuiltThatchHut = false,

        sapienIsHungry = false,
        storeFoodCount = 0,
        hasStoredFood = false,

        researchDiggingComplete = false,
        researchPlantingComplete = false,
        foodCropPlantCount = 0,
        hasPlantedXFoodCrops = false,

        playerHasToggledMap = false,

        researchBoneCarvingComplete = false,
        flutePlayActionStarted = false, --no longer set, but kept for backwards compatibility
        musicPlayActionStarted = false,

        hasZoomedToNotification = false,

        nomadsAvailableToBeRecruited = false,
        hasRecruitedNomad = false,

        secondLogisticsDestinationAdded = false,
        objectWasDeliveredForTransferRoute = false,

        pathBuildCount = 0,
        hasBuiltXPaths = false,

        hasChoppedTree = false,
        hasSplitLog = false,
        hasBuiltSplitLogWall = false,
        
        storeFlaxCount = false,
        hasStoredFlax = 0,
        storeTwineCount = false,
        hasStoredTwine = 0,

        hasCraftedPickAxe = false,
        hasCraftedSpear = false,
        hasCraftedHatchet = false,
        
        researchHuntingComplete = false,
        researchSpearHuntingComplete = false,
        researchButcheryComplete = false,
        hasCraftedCookedMeat = false,
        
        orderLimitMaxExceeded = false,
        orderLimitMinExceeded = false,
        hasPrioritizedOrder = false,

        sapienGotFoodPoisoningDueToContamination = false,
        configureRawMeatComplete = false,
        configureCookedMeatComplete = false,
    }
end

local completeKeysByCountKeys = {
    grassClearCount = "hasClearedXGrassTiles",
    storageAreaPlaceCount = "hasPlacedXStorageAreas",
    storeHayCount = "hasStoredHay",
    storeBranchCount = "hasStoredBranches",
    bedPlaceCount = "hasPlacedXBeds",
    bedBuiltCount = "hasBuiltXBeds",
    craftAreaBuiltCount = "hasBuiltXCraftAreas",
    craftHandAxeCount = "hasCraftedXHandAxes",
    craftKnifeCount = "hasCraftedXKnives",
    storeFoodCount = "hasStoredFood",
    foodCropPlantCount = "hasPlantedXFoodCrops",
    pathBuildCount = "hasBuiltXPaths",
    storeFlaxCount = "hasStoredFlax",
    storeTwineCount = "hasStoredTwine",
}

local netTutorialBooleanStateWhitelist = {
    hasPlacedCampfire = true,
    hasLitCampfire = true,
    hasPlacedThatchHut = true,
    hasBuiltThatchHut = true,
    sapienIsHungry = true,
    nomadsAvailableToBeRecruited = true,
    hasRecruitedNomad = true,
    musicPlayActionStarted = true,
    objectWasDeliveredForTransferRoute = true,
    hasChoppedTree = true,
    hasSplitLog = true,
    hasBuiltSplitLogWall = true,
    hasCraftedPickAxe = true,
    hasCraftedSpear = true,
    hasCraftedHatchet = true,
    hasCraftedCookedMeat = true,
    sapienGotFoodPoisoningDueToContamination = true,
}

local typeIndexMap = typeMaps.types.tutorial

function tutorialUI:clearPlanComplete()
    return tutorialState.clearPlanHasBeenIssued
end

local function saveValue(value, key)
    if not tutorialState then
        return
    end
    clientWorldSettingsDatabase:setDataForKey(value, key .. "_" .. world.tribeID)
end

function tutorialUI:clearPlanWasIssued()

    if not tutorialState.clearPlanHasBeenIssued then
        tutorialState.clearPlanHasBeenIssued = true
        saveValue(true, "clearPlanHasBeenIssued")
    end
end

function tutorialUI:playerToggledPause()
    if not tutorialState then
        return
    end
    if not tutorialState.playerHasToggledPause then
        tutorialState.playerHasToggledPause = true
        saveValue(true, "playerHasToggledPause")
    end
end

function tutorialUI:playerToggledFastForward()
    if not tutorialState then
        return
    end
    if not tutorialState.playerHasToggledFastForward then
        tutorialState.playerHasToggledFastForward = true
        saveValue(true, "playerHasToggledFastForward")
    end
end

function tutorialUI:playerToggledMap()
    if not tutorialState then
        return
    end
    if not tutorialState.playerHasToggledMap then
        tutorialState.playerHasToggledMap = true
        saveValue(true, "playerHasToggledMap")
    end
end

function tutorialUI:multiSelectComplete()
    return tutorialState.multiSelectComplete
end

function tutorialUI:multiSelectWasIssued(objectCount)
    if not tutorialState.multiSelectComplete and objectCount >= gameConstants.tutorial_multiselectCount then
        tutorialState.multiSelectComplete = true
        saveValue(true, "multiSelectComplete")
    end
end

function tutorialUI:roleAssignmentWasIssued()
    if not tutorialState.roleAssignmentComplete then
        tutorialState.roleAssignmentComplete = true
        saveValue(true, "roleAssignmentComplete")
    end
end

function tutorialUI:secondDestinationWasAddedToRoute()
    if not tutorialState.secondLogisticsDestinationAdded then
        tutorialState.secondLogisticsDestinationAdded = true
        saveValue(true, "secondLogisticsDestinationAdded")
    end
end

function tutorialUI:setHasZoomedToNotification()
    if not tutorialState then
        return
    end
    if not tutorialState.hasZoomedToNotification then
        tutorialState.hasZoomedToNotification = true
        saveValue(true, "hasZoomedToNotification")
    end
end

function tutorialUI:configureRawMeatComplete()
    return tutorialState.configureRawMeatComplete
end

function tutorialUI:configureCookedMeatComplete()
    return tutorialState.configureCookedMeatComplete
end

function tutorialUI:setHasConfiguredRawMeat()
    if not tutorialState.configureRawMeatComplete then
        tutorialState.configureRawMeatComplete = true
        saveValue(true, "configureRawMeatComplete")
    end
end

function tutorialUI:setHasConfiguredCookedMeat()
    if not tutorialState.configureCookedMeatComplete then
        tutorialState.configureCookedMeatComplete = true
        saveValue(true, "configureCookedMeatComplete")
    end
end


local researchCompletionKeysByResearchTypeIndex = {
    [research.types.fire.index] = "researchBranchComplete",
    [research.types.rockKnapping.index] = "researchRockComplete",
    [research.types.thatchBuilding.index] = "researchHayComplete",
    [research.types.digging.index] = "researchDiggingComplete",
    [research.types.planting.index] = "researchPlantingComplete",
    [research.types.boneCarving.index] = "researchBoneCarvingComplete",
    [research.types.basicHunting.index] = "researchHuntingComplete",
    [research.types.spearHunting.index] = "researchSpearHuntingComplete",
    [research.types.butchery.index] = "researchButcheryComplete",
}

function tutorialUI:researchCompleted(researchTypeIndex)
    --mj:log("tutorialUI:researchCompleted")
    local completionKey = researchCompletionKeysByResearchTypeIndex[researchTypeIndex]
    if completionKey and not tutorialState[completionKey] then
        tutorialState[completionKey] = true
        saveValue(true, completionKey)
    end
end

function tutorialUI:musicPlayActionStarted()
    local completionKey = "musicPlayActionStarted"
    if completionKey and not tutorialState[completionKey] then
        tutorialState[completionKey] = true
        saveValue(true, completionKey)
    end
end

function tutorialUI:orderCountsChanged(currentOrderCount, maxOrderCount)
    local minKey = "orderLimitMinExceeded"
    local maxKey = "orderLimitMaxExceeded"
    local booleanMin = (currentOrderCount >= maxOrderCount)
    local booleanMax = (currentOrderCount >= (maxOrderCount + 10))

    if tutorialState[minKey] ~= booleanMin then
        tutorialState[minKey] = booleanMin
        saveValue(booleanMin, minKey)
    end
    if tutorialState[maxKey] ~= booleanMax then
        tutorialState[maxKey] = booleanMax
        saveValue(booleanMax, maxKey)
    end
end

function tutorialUI:prioritizationWasIssued()
    if not tutorialState.hasPrioritizedOrder then
        tutorialState.hasPrioritizedOrder = true
        saveValue(true, "hasPrioritizedOrder")
    end
end

local function updateCountTextForPanelInfo(typeKey, panelInfo)
    local tipType = tutorialUI.types[panelInfo.tipTypeIndex]
    if tipType.checklist then
        local checklistItemInfos = panelInfo.checklistItemInfos

        for j,checklistItem in ipairs(tipType.checklist) do
            if checklistItem.updateCountTextTypeKey == typeKey then
                local max = gameConstants["tutorial_" .. checklistItem.updateCountTextTypeKey] or 0
                local value = tutorialState[checklistItem.updateCountTextTypeKey]
                if type(value) ~= "number" then --bug in b16, this was a boolean somehow
                    mj:error("bad type for updateCountTextTypeKey:", checklistItem.updateCountTextTypeKey, " tutorialState:", tutorialState)
                    value = 0
                end
                --mj:log("checklistItem.updateCountTextTypeKey:", checklistItem.updateCountTextTypeKey)
                --mj:log("max:", max, " value:", value)
                checklistItemInfos[j].countTextView.text = string.format("(%d/%d)", math.min(value, max), max)
                break
            end
        end
    end
end

local function updateCountTextForAllPanels(typeKey)
    for i,panelInfo in ipairs(currentTipTypeInfos) do
        updateCountTextForPanelInfo(typeKey, panelInfo)
    end
end

local function updateCountedValue(hasCompletedKey, countKey, count)
    if not tutorialState[hasCompletedKey] then
        --mj:log("updateCountedValue countKey:", countKey, " count:", count)
        local requiredCountKey = "tutorial_" .. countKey
        local requiredCount = gameConstants[requiredCountKey]
        tutorialState[countKey] = math.min(count, requiredCount)
        if count >= requiredCount then
            tutorialState[hasCompletedKey] = true
            saveValue(true, hasCompletedKey)
        end
    end
end

local function loadCompletionValues(serverTutorialClientState, migrate)

    for k,v in pairs(tutorialState) do

        local savedValue = nil
        if migrate then
            savedValue = clientWorldSettingsDatabase:dataForKey(k) --this will only contain completed boolean values
            saveValue(savedValue, k)
        else
            savedValue = clientWorldSettingsDatabase:dataForKey(k .. "_" .. world.tribeID) --this will only contain completed boolean values
        end

        if savedValue then
            tutorialState[k] = savedValue
            --mj:log("setting:", k, " to saved value:", savedValue)
        else
            if serverTutorialClientState then
                local serverValue = serverTutorialClientState[k]
                if serverValue then
                    tutorialState[k] = serverValue
                    --mj:log("setting:", k, " to server value:", serverValue)
                    local hasCompletedKey = completeKeysByCountKeys[k]
                    if hasCompletedKey then
                        --mj:log("hasCompletedKey:", hasCompletedKey)
                        local max = gameConstants["tutorial_" .. k]
                        if serverValue >= max then
                            --mj:log("setting complete")
                            tutorialState[hasCompletedKey] = true
                            saveValue(true, hasCompletedKey)
                        end
                    end
                end
            end
        end
    end
end

local preLoadInfoQueue = {} --hack to work around load order problems. We can get these events before we have finished loading and have a tribeID.

function tutorialUI:netTutorialStateChanged(info)
    if not hasTribeID then
        table.insert(preLoadInfoQueue, info)
        return
    end

    --mj:log("tutorialUI:netTutorialStateChanged:", info)

    local completeKey = completeKeysByCountKeys[info.key]
    if completeKey then
        updateCountedValue(completeKeysByCountKeys[info.key], info.key, info.value)
        updateCountTextForAllPanels(info.key)
    elseif netTutorialBooleanStateWhitelist[info.key] then
        local booleanValue = (info.value == true)
        tutorialState[info.key] = booleanValue
        saveValue(booleanValue, info.key)
    end
end

function tutorialUI:setNotificationIsVisible(notificationIsVisible_)
    notificationIsVisible = notificationIsVisible_
end


tutorialUI.types = typeMaps:createMap( "tutorial", {
    {
        key = "chooseTribe",
        title = locale:get("tutorial_title_chooseTribe"),
        disableWordWrap = true,
        readyToDisplayFunction = function()
            return (not intro:getVisible())
        end,
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_subtitle_mapNavigation"),
                    },
                },
                isCompleteFunction = function()
                    return localPlayer:hasMovedAndZoomed(true) or world:hasSelectedTribeID()
                end,
                subtitle = {
                    {
                        text = locale:get("tutorial_use"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "forward",
                                    }
                                },
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "left",
                                    },
                                },
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "back",
                                    },
                                },
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "right",
                                    }
                                },
                                {
                                    text =  locale:get("tutorial_or"),
                                },
                                {
                                    coloredText = {
                                        text = locale:get("mouse_left_drag"),
                                        color = mj.highlightColor
                                    }
                                },
                                {
                                    icon = "icon_leftMouse"
                                },
                            },
                            controller = {
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "move"
                                }
                            }
                        }
                    },
                    {
                        text = locale:get("tutorial_toMoveAnd"),
                    },
                    {
                        
                        keyboardController = {
                            keyboard = {
                                {
                                    coloredText = {
                                        text = locale:get("mouse_wheel"),
                                        color = mj.highlightColor
                                    }
                                },
                            },
                            controller = {
                                {
                                    controllerImage = {
                                        controllerSetIndex = eventManager.controllerSetIndexInGame,
                                        controllerActionName = "zoomIn"
                                    }
                                },
                                {
                                    controllerImage = {
                                        controllerSetIndex = eventManager.controllerSetIndexInGame,
                                        controllerActionName = "zoomOut"
                                    }
                                }
                            }
                        }
                    },
                    {
                        text = locale:get("tutorial_toZoom"),
                    },
                }
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_subtitle_chooseTribe_title"),
                    },
                },
                subtitle = {
                    {
                        text = locale:get("tutorial_subtitle_chooseTribe_a"),
                    },
                    {
                        icon = "icon_tribe2"
                    },
                    {
                        text = locale:get("tutorial_subtitle_chooseTribe_b"),
                    },
                },
                isCompleteFunction = function()
                    return world:hasSelectedTribeID()
                    --return (not localPlayer:hasMovedAndZoomed(true)) --todo
                end,
            },
        },
    },
    {
        key = "basicControls",
        title = locale:get("tutorial_title_basicControls"),
        disableWordWrap = true,
        storyPanel = {
            description = locale:get("tutorial_basicControls_storyText"),
            iconGameObjectTypeIndex = gameObject.types.hay.index,
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.speedControls,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_basicControls_navigation"),
                    },
                },
                isCompleteFunction = function()
                    if not tutorialState.movementComplete then
                        if localPlayer:hasMovedAndZoomed(false) then
                            saveValue(true, "movementComplete")
                            tutorialState.movementComplete = true
                            return true
                        else
                            return false
                        end
                    else
                        return true
                    end
                end,
                subtitle = {
                    {
                        text = locale:get("tutorial_use"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "forward",
                                    }
                                },
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "left",
                                    },
                                },
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "back",
                                    },
                                },
                                {
                                    keyImage = {
                                        groupKey = "movement", 
                                        mappingKey = "right",
                                    }
                                },
                            },
                            controller = {
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "move"
                                }
                            }
                        }
                    },
                    {
                        text = locale:get("tutorial_toMoveAnd"),
                    },
                    {
                        
                        keyboardController = {
                            keyboard = {
                                {
                                    coloredText = {
                                        text = locale:get("mouse_wheel"),
                                        color = mj.highlightColor
                                    }
                                },
                            },
                            controller = {
                                {
                                    controllerImage = {
                                        controllerSetIndex = eventManager.controllerSetIndexInGame,
                                        controllerActionName = "zoomIn"
                                    }
                                },
                                {
                                    controllerImage = {
                                        controllerSetIndex = eventManager.controllerSetIndexInGame,
                                        controllerActionName = "zoomOut"
                                    }
                                }
                            }
                        }
                    },
                    {
                        text = locale:get("tutorial_toZoom"),
                    },
                }
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_basicControls_issueOrder"),
                    },
                },
                subtitle = {
                    {
                        text = locale:get("tutorial_issueOrder_instructions_a"),
                    },
                    {
                        coloredText = {
                            text = locale:get("tutorial_issueOrder_instructions_b"),
                            color = mj.highlightColor
                        }
                    },
                    {
                        icon = "icon_clear"
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.clearPlanHasBeenIssued
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_basicControls_clearHexes", {
                            count = gameConstants.tutorial_grassClearCount
                        }),
                    },
                },

                updateCountTextTypeKey = "grassClearCount",

                isCompleteFunction = function()
                    return tutorialState.hasClearedXGrassTiles
                end,
            },
        },
    },
    {
        key = "speedControls",
        title = locale:get("tutorial_title_speedControls"),
        readyToDisplayFunction = function()
            return tutorialState.clearPlanHasBeenIssued and (tutorialState.hasClearedXGrassTiles or tutorialState.grassClearCount > 0)
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_subtitle_togglePause"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                keyImage = {
                                    groupKey = "game", 
                                    mappingKey = "pause",
                                }
                            },
                            controller = {
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "speedDown"
                                }
                            }
                        }
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.playerHasToggledPause
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_subtitle_toggleFastForward"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                keyImage = {
                                    groupKey = "game", 
                                    mappingKey = "speedFast",
                                }
                            },
                            controller = {
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "speedUp"
                                }
                            }
                        }
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.playerHasToggledFastForward
                end,
            },
        },
    },
    {
        key = "storingResources",
        title = locale:get("tutorial_title_storingResources"),
        storyPanel = {
            description = locale:get("tutorial_storingResources_storyText"),
            iconGameObjectTypeIndex = gameObject.types.storageArea.index,
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.multiselect,
            typeIndexMap.recruitment,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_storingResources_build", {
                            count = gameConstants.tutorial_storageAreaPlaceCount
                        }),
                    },
                },
                
                updateCountTextTypeKey = "storageAreaPlaceCount",

                isCompleteFunction = function()
                    return tutorialState.hasPlacedXStorageAreas
                end,
                subtitles = {
                    {
                        {
                            text = locale:get("tutorial_storingResources_subTitle_accessWith"),
                        },
                        {
                            keyboardController = {
                                keyboard = {
                                    {
                                        keyImage = {
                                            groupKey = "game", 
                                            mappingKey = "buildMenu",
                                        }
                                    },
                                },
                                controller = {
                                    {
                                        controllerImage = {
                                            controllerSetIndex = eventManager.controllerSetIndexInGame,
                                            controllerActionName = "buildMenu"
                                        }
                                    },
                                }
                            }
                        },
                    },
                    {
                        {
                            text = locale:get("tutorial_storingResources_subTitle_andPlace"),
                        },
                    }
                }
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_storingResources_store", {
                            count = gameConstants.tutorial_storeHayCount,
                            typeName = locale:get("misc_dry") .. " " .. resource.types.hay.plural
                        }),
                    },
                },
                updateCountTextTypeKey = "storeHayCount",

                isCompleteFunction = function()
                    return tutorialState.hasStoredHay
                end,
                subtitle = {
                    {
                        text = locale:get("tutorial_storingResources_storeTip_a"),
                    },
                }
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_storingResources_store", {
                            count = gameConstants.tutorial_storeBranchCount,
                            typeName = resource.types.branch.plural
                        }),
                    },
                },
                updateCountTextTypeKey = "storeBranchCount",
                isCompleteFunction = function()
                    return tutorialState.hasStoredBranches
                end,
                --[[subtitle = {
                    {
                        text = locale:get("tutorial_storingResources_storeTip_b"),
                    },
                }]]
            },
        },
    },


    {
        key = "multiselect",
        title = locale:get("tutorial_title_multiselect"),
        storyPanel = {
            description = locale:get("tutorial_description_multiselect"),
            iconImage = "icon_multiSelect",
        },
        readyToDisplayFunction = function()
            return tutorialState.hasPlacedXStorageAreas
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_task_multiselect", {
                            count = gameConstants.tutorial_multiselectCount
                        }),
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.multiSelectComplete
                end,
                subtitles = {
                    {
                        {
                            text = locale:get("tutorial_task_multiselect_subtitle"),
                        },
                    },
                    {
                        {
                            text = locale:get("tutorial_task_multiselect_subtitle_b"),
                        },
                        {
                            icon = "icon_multiSelect"
                        },
                    },
                    {
                        {
                            text = locale:get("tutorial_task_multiselect_subtitle_c"),
                        },
                    },
                }
            },
        },
    },
    
    {
        key = "beds",
        title = locale:get("tutorial_title_beds"),
        storyPanel = {
            description = locale:get("tutorial_beds_storyText"),
            iconGameObjectTypeIndex = gameObject.types.hayBed.index,
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.research,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_beds_build", {
                            count = gameConstants.tutorial_bedPlaceCount
                        }),
                    },
                },
                
                updateCountTextTypeKey = "bedPlaceCount",

                isCompleteFunction = function()
                    return tutorialState.hasPlacedXBeds
                end,
                subtitles = {
                    {
                        {
                            text = locale:get("tutorial_beds_subTitle_accessWith"),
                        },
                        {
                            keyboardController = {
                                keyboard = {
                                    {
                                        keyImage = {
                                            groupKey = "game", 
                                            mappingKey = "buildMenu",
                                        }
                                    },
                                },
                                controller = {
                                    {
                                        controllerImage = {
                                            controllerSetIndex = eventManager.controllerSetIndexInGame,
                                            controllerActionName = "buildMenu"
                                        }
                                    },
                                }
                            }
                        },
                    },
                    {
                        {
                            text = locale:get("tutorial_beds_subTitle_andPlace"),
                        },
                    },
                }
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_beds_waitForBuild"),
                    },
                },
                updateCountTextTypeKey = "bedBuiltCount",

                isCompleteFunction = function()
                    return tutorialState.hasBuiltXBeds
                end,
                subtitle = {
                    {
                        text = locale:get("tutorial_beds_waitForBuild_tip"),
                    },
                }
            },
        },
    },
    
    {
        key = "research",
        title = locale:get("tutorial_title_research"),
        storyPanel = {
            description = locale:get("tutorial_research_storyText"),
            iconImage = "icon_idea",
        },
        readyToDisplayFunction = function()
            return tutorialState.hasPlacedXBeds
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.fire,
            typeIndexMap.tools,
            typeIndexMap.thatchBuilding,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_research_branch"),
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.researchBranchComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_research_rock"),
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.researchRockComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_research_hay"),
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.researchHayComplete
                end,
            },
        },
    },
    
    
    {
        key = "orderLimit",
        title = locale:get("tutorial_title_orderLimit"),
        readyToDisplayFunction = function()
            --mj:log("tutorialState.orderLimitMaxExceeded:", tutorialState.orderLimitMaxExceeded)
            return tutorialState.orderLimitMaxExceeded
        end,
        becameInvalidFunction = function()
           -- mj:log("tutorialState.orderLimitMinExceeded:", tutorialState.orderLimitMinExceeded)
            return (not tutorialState.orderLimitMinExceeded)
        end,
        storyPanel = {
            description = locale:get("tutorial_orderLimit_storyText", {allowedPlansPerFollower = gameConstants.allowedPlansPerFollower}),
            iconImage = "icon_warning",
        },
        allowSimultaneous = {
            typeIndexMap.music,
            typeIndexMap.routes,
            typeIndexMap.paths,
            typeIndexMap.woodBuilding,
            typeIndexMap.advancedTools,
        },
        allowDisplayAboveMaxSimultaneousCount = true,
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_orderLimit_task"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasPrioritizedOrder
                end,
            },
        },
    },

    {
        key = "roleAssignment",
        title = locale:get("tutorial_title_roleAssignment"),
        storyPanel = {
            description = locale:get("tutorial_description_roleAssignment"),
            iconImage = "icon_tasks",
        },
        readyToDisplayFunction = function()
            return tutorialState.hasBuiltXBeds and (tutorialState.researchBranchComplete or tutorialState.researchRockComplete or tutorialState.researchHayComplete)
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.fire,
            typeIndexMap.tools,
            typeIndexMap.thatchBuilding,
        },
        allowDisplayAboveMaxSimultaneousCount = true,
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_task_roleAssignment"),
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.roleAssignmentComplete
                end,
                subtitle = {
                    {
                        text = locale:get("tutorial_task_roleAssignment_subtitle_a"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                keyImage = {
                                    groupKey = "game", 
                                    mappingKey = "buildMenu",
                                }
                            },
                            controller = {
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "buildMenu"
                                }
                            },
                        }
                    },
                    {
                        text = locale:get("tutorial_task_roleAssignment_subtitle_b"),
                    },
                    {
                        icon = "icon_tribe2"
                    },
                    {
                        text = locale:get("tutorial_task_roleAssignment_subtitle_c"),
                    },
                    {
                        icon = "icon_tasks"
                    },
                    {
                        text = locale:get("tutorial_task_roleAssignment_subtitle_d"),
                    },
                }
            },
        },
    },

    {
        key = "tools",
        title = locale:get("tutorial_title_tools"),
        storyPanel = {
            description = locale:get("tutorial_tools_storyText"),
            iconImage = "icon_craft",
        },
        readyToDisplayFunction = function()
            return tutorialState.hasBuiltXBeds and tutorialState.researchRockComplete
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.roleAssignment,
            typeIndexMap.cookingMeat,
            typeIndexMap.fire,
            typeIndexMap.thatchBuilding,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_tools_buildCraftAreas", {
                            count = gameConstants.tutorial_craftAreaBuiltCount
                        }),
                    },
                },
                
                updateCountTextTypeKey = "craftAreaBuiltCount",

                isCompleteFunction = function()
                    return tutorialState.hasBuiltXCraftAreas
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_tools_craftHandAxes", {
                            count = gameConstants.tutorial_craftHandAxeCount
                        }),
                    },
                },
                
                updateCountTextTypeKey = "craftHandAxeCount",

                isCompleteFunction = function()
                    return tutorialState.hasCraftedXHandAxes
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_tools_craftKnives", {
                            count = gameConstants.tutorial_craftKnifeCount
                        }),
                    },
                },
                
                updateCountTextTypeKey = "craftKnifeCount",

                isCompleteFunction = function()
                    return tutorialState.hasCraftedXKnives
                end,
            },
        },
    },
    

    {
        key = "fire",
        title = locale:get("tutorial_title_fire"),
        storyPanel = {
            description = locale:get("tutorial_fire_storyText"),
            iconImage = "icon_fire",
        },
        readyToDisplayFunction = function()
            return tutorialState.hasBuiltXBeds and tutorialState.researchBranchComplete
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.roleAssignment,
            typeIndexMap.cookingMeat,
            typeIndexMap.tools,
            typeIndexMap.thatchBuilding,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_fire_place"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasPlacedCampfire
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_fire_waitForBuild"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasLitCampfire
                end,
            },
        },
    },
    
    {
        key = "thatchBuilding",
        title = locale:get("tutorial_title_thatchBuilding"),
        storyPanel = {
            description = locale:get("tutorial_thatchBuilding_storyText"),
            iconGameObjectTypeIndex = gameObject.types.thatchRoof.index,
        },
        readyToDisplayFunction = function()
            return tutorialState.hasBuiltXBeds and tutorialState.researchHayComplete
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.roleAssignment,
            typeIndexMap.cookingMeat,
            typeIndexMap.fire,
            typeIndexMap.tools,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_thatchBuilding_place"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasPlacedThatchHut
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_thatchBuilding_waitForBuild"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasBuiltThatchHut
                end,
            },
        },
    },
    
    {
        key = "food",
        title = locale:get("tutorial_title_food"),
        storyPanel = {
            description = locale:get("tutorial_food_storyText"),
            iconImage = "icon_food",
        },
        readyToDisplayFunction = function()
            return tutorialState.sapienIsHungry or (
                tutorialState.hasBuiltThatchHut and 
                tutorialState.hasCraftedXHandAxes and 
                tutorialState.hasCraftedXKnives and 
                tutorialState.hasLitCampfire
            )
        end,
        allowSimultaneous = {
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.worldMap,
            typeIndexMap.cookingMeat,
        },
        allowDisplayAboveMaxSimultaneousCount = true,
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_food_storeTask", {
                            count = gameConstants.tutorial_storeFoodCount,
                        }),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasStoredFood
                end,
                
                updateCountTextTypeKey = "storeFoodCount",

                subtitle = {
                    {
                        text = locale:get("tutorial_food_storeTask_subTitle"),
                    },
                },
            },
        },
    },
    
    
    {
        key = "farming",
        title = locale:get("tutorial_title_farming"),
        storyPanel = {
            description = locale:get("tutorial_farming_storyText"),
            iconGameObjectTypeIndex = gameObject.types.apple.index,
        },
        readyToDisplayFunction = function()
            return tutorialState.hasStoredFood and (
                tutorialState.hasBuiltThatchHut and 
                tutorialState.hasCraftedXHandAxes and 
                tutorialState.hasCraftedXKnives and 
                tutorialState.hasLitCampfire
            )
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.worldMap,
            typeIndexMap.cookingMeat,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_farming_digging"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.researchDiggingComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_farming_planting"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.researchPlantingComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_farming_plantXTrees", {
                            count = gameConstants.tutorial_foodCropPlantCount,
                        }),
                    },
                },
                
                updateCountTextTypeKey = "foodCropPlantCount",

                isCompleteFunction = function()
                    return tutorialState.hasPlantedXFoodCrops
                end,
            },
        },
    },
    
    {
        key = "worldMap",
        title = locale:get("tutorial_title_worldMap"),
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_worldMap_task"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                keyImage = {
                                    groupKey = "game", 
                                    mappingKey = "toggleMap",
                                }
                            },
                            controller = {
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "buildMenu" --todo
                                }
                            }
                        }
                    },
                },
                isCompleteFunction = function()
                    return tutorialState.playerHasToggledMap
                end,
            },
        },
    },

    {
        key = "music",
        title = locale:get("tutorial_title_music"),
        storyPanel = {
            description = locale:get("tutorial_music_storyText"),
            iconImage = "icon_music",
        },
        readyToDisplayFunction = function()
            return world:tribeHasSeenResource(resource.types.bone.index)
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_music_discoverBoneCarving"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.researchBoneCarvingComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_music_playFlute"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.musicPlayActionStarted or tutorialState.flutePlayActionStarted
                end,
            },
        },
    },
    
    {
        key = "routes",
        title = locale:get("tutorial_title_routes"),
        storyPanel = {
            description = locale:get("tutorial_routes_storyText"),
            iconImage = "icon_logistics",
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_routes_create"),
                    },
                },

                subtitles = {
                    {
                        {
                            text = locale:get("tutorial_routes_create_subtitle_a"),
                        },
                    },
                    {
                        {
                            text = locale:get("tutorial_routes_create_subtitle_b"),
                        },
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.secondLogisticsDestinationAdded
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_routes_doTransfer"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.objectWasDeliveredForTransferRoute
                end,
            },
        },
    },

    
    {
        key = "paths",
        title = locale:get("tutorial_title_paths"),
        storyPanel = {
            description = locale:get("tutorial_paths_storyText"),
            iconImage = "icon_path",
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_paths_buildXPaths", {
                            count = gameConstants.tutorial_pathBuildCount,
                        }),
                    },
                },
                updateCountTextTypeKey = "pathBuildCount",

                isCompleteFunction = function()
                    return tutorialState.hasBuiltXPaths
                end,
            },
        },
    },
    
    
    {
        key = "woodBuilding",
        title = locale:get("tutorial_title_woodBuilding"),
        storyPanel = {
            description = locale:get("tutorial_woodBuilding_storyText"),
            iconGameObjectTypeIndex = gameObject.types.splitLogWallDoor.index,
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_woodBuilding_chopTree"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasChoppedTree
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_woodBuilding_splitLog"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasSplitLog
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_woodBuilding_buildWall"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasBuiltSplitLogWall
                end,
            },
        },
    },
    
    {
        key = "advancedTools",
        title = locale:get("tutorial_title_advancedTools"),
        storyPanel = {
            description = locale:get("tutorial_advancedTools_storyText"),
            iconGameObjectTypeIndex = gameObject.types.stonePickaxe.index,
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_advancedTools_driedFlax", {
                            count = gameConstants.tutorial_storeFlaxCount,
                        }),
                    },
                },
                updateCountTextTypeKey = "storeFlaxCount",
                isCompleteFunction = function()
                    return tutorialState.hasStoredFlax
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_advancedTools_twine", {
                            count = gameConstants.tutorial_storeTwineCount,
                        }),
                    },
                },
                updateCountTextTypeKey = "storeTwineCount",
                isCompleteFunction = function()
                    return tutorialState.hasStoredTwine
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_advancedTools_pickAxe"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasCraftedPickAxe
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_advancedTools_spear"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasCraftedSpear
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_advancedTools_hatchet"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasCraftedHatchet
                end,
            },
        },
    },
    
    {
        key = "cookingMeat",
        title = locale:get("tutorial_title_cookingMeat"),
        storyPanel = {
            description = locale:get("tutorial_cookingMeat_storyText"),
            iconImage = "icon_food",
        },
        readyToDisplayFunction = function()
            return tutorialState.researchHuntingComplete or tutorialState.researchSpearHuntingComplete
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_cookingMeat_butcher"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.researchButcheryComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_cookingMeat_cook"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasCraftedCookedMeat
                end,
            },
        },
    },
    
    {
        key = "recruitment",
        title = locale:get("tutorial_title_recruitment"),
        readyToDisplayFunction = function()
            return tutorialState.nomadsAvailableToBeRecruited
        end,
        becameInvalidFunction = function()
            return (not tutorialState.nomadsAvailableToBeRecruited)
        end,
        storyPanel = {
            description = locale:get("tutorial_recruitment_storyText"),
            iconImage = "icon_tribe2",
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.notifications,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        allowDisplayAboveMaxSimultaneousCount = true,
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_recruitment_task"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasRecruitedNomad
                end,
            },
        },
    },

    {
        key = "notifications",
        title = locale:get("tutorial_title_notifications"),
        readyToDisplayFunction = function()
            return notificationIsVisible
        end,
        becameInvalidFunction = function()
            return (not notificationIsVisible)
        end,
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.foodPoisoning,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_notifications_task"),
                    },
                    {
                        keyboardController = {
                            keyboard = {
                                keyImage = {
                                    groupKey = "game", 
                                    mappingKey = "zoomToNotification",
                                }
                            },
                            controller = { 
                                controllerImage = {
                                    controllerSetIndex = eventManager.controllerSetIndexInGame,
                                    controllerActionName = "buildMenu" --todo
                                }
                            },
                        }
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.hasZoomedToNotification
                end,
            },
        },
    },

    
    {
        key = "foodPoisoning",
        title = locale:get("tutorial_title_foodPoisoning"),
        readyToDisplayFunction = function()
            return tutorialState.sapienGotFoodPoisoningDueToContamination
        end,
        storyPanel = {
            description = locale:get("tutorial_foodPoisoning_storyText"),
            iconImage = "icon_foodPoisoning",
        },
        allowSimultaneous = {
            typeIndexMap.food,
            typeIndexMap.recruitment,
            typeIndexMap.notifications,
            typeIndexMap.cookingMeat,
            typeIndexMap.orderLimit,
        },
        checklist = {
            {
                title = {
                    {
                        text = locale:get("tutorial_foodPoisoning_configureRawMeat"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.configureRawMeatComplete
                end,
            },
            {
                title = {
                    {
                        text = locale:get("tutorial_foodPoisoning_configureCookedMeat"),
                    },
                },

                isCompleteFunction = function()
                    return tutorialState.configureCookedMeatComplete
                end,
            },
        },
    },

    
    {
        key = "completion",
        title = locale:get("tutorial_title_completion"),
        storyPanel = {
            description = locale:get("tutorial_completion_storyText"),
            iconImage = "hand",
        },
        allowDisplayAboveMaxSimultaneousCount = true,
        hideSkipButton = true,
    },
    
    
})

local orderedTips = {
    typeIndexMap.chooseTribe,
    typeIndexMap.basicControls,
    typeIndexMap.speedControls,
    typeIndexMap.storingResources,
    typeIndexMap.multiselect,
    typeIndexMap.beds,
    typeIndexMap.research,
    typeIndexMap.fire,
    typeIndexMap.tools,
    typeIndexMap.thatchBuilding,
    typeIndexMap.roleAssignment,
    typeIndexMap.food,
    typeIndexMap.farming,
    typeIndexMap.worldMap,
    typeIndexMap.routes,
    typeIndexMap.paths,
    typeIndexMap.woodBuilding,
    typeIndexMap.music,

   -- typeIndexMap.cookingMeat,
   -- typeIndexMap.recruitment,
  --  typeIndexMap.notifications,
  --  typeIndexMap.orderLimit,
  --  typeIndexMap.foodPoisoning,

    --completion
    typeIndexMap.completion,
}

local function addPanel(tipTypeIndex)

    local panelInfo = {
        tipTypeIndex = tipTypeIndex,
        slidingOn = true,
        slideAnimationTimer = 0.0,
    }
    local panelIndex = #currentTipTypeInfos + 1
    currentTipTypeInfos[panelIndex] = panelInfo
    
    local panelView = ModelView.new(mainView)
    panelInfo.panelView = panelView
    panelView:setModel(model:modelIndexForName("ui_panel_10x2"))
    panelView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    panelView.alpha = 0.9
    

    local titleTextView = TextView.new(panelView)
    panelInfo.titleTextView = titleTextView
    titleTextView.font = Font(uiCommon.fontName, 20)
    titleTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    titleTextView.baseOffset = vec3(12,-12,0)

    local tickView = ModelView.new(panelView)
    panelInfo.tickView = tickView
    tickView:setModel(model:modelIndexForName("icon_tick"), {
        default = material.types.ui_selected.index
    })
    tickView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    tickView.size = vec2(tickHalfSize,tickHalfSize) * 2.0
    tickView.scale3D = vec3(tickHalfSize,tickHalfSize,tickHalfSize)
    tickView.baseOffset = vec3(-6,-2,4)
    tickView.hidden = true


    local tipType = tutorialUI.types[tipTypeIndex]
    titleTextView.text = tipType.title

    local maxLineWidth = 0.0
    local panelHeight = titleTextView.size.y + 20

    local checklistItemInfos = {}
    panelInfo.checklistItemInfos = checklistItemInfos
    local itemOffsetY = 5.0

    if tipType.checklist then

        for i,checklistItem in ipairs(tipType.checklist) do
            --title
            
            local checklistItemView = View.new(panelView)
            --checklistItemView.color = mjm.vec4(0.5,0.5,0.0,0.5)
            checklistItemView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBelow)
            checklistItemView.relativeView = titleTextView
            checklistItemView.baseOffset = vec3(-2.0,-itemOffsetY + 2.0,0.0)


            local checkBoxSize = vec2(26,26)
            local checkBoxView = ModelView.new(checklistItemView)
            local checkBoxScaleToUseX = checkBoxSize.x * 0.5
            checkBoxView.scale3D = vec3(checkBoxScaleToUseX,checkBoxScaleToUseX,checkBoxScaleToUseX)
            checkBoxView.size = checkBoxSize
            checkBoxView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
            checkBoxView:setModel(model:modelIndexForName("ui_button_toggle"), {
                [material.types.ui_selected.index] = material.types.ui_background.index,
            })
            checkBoxView.alpha = 0.8

            local itemTickView = ModelView.new(checklistItemView)
            itemTickView:setModel(model:modelIndexForName("icon_tick"), {
                default = material.types.ui_selected.index
            })
            itemTickView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            itemTickView.relativeView = checkBoxView
            itemTickView.size = vec2(itemTickHalfSize,itemTickHalfSize) * 2.0
            itemTickView.scale3D = vec3(itemTickHalfSize,itemTickHalfSize,itemTickHalfSize)
            itemTickView.baseOffset = vec3(-1,1,2)

            local isComplete = checklistItem.isCompleteFunction()
            if not isComplete then
                itemTickView.hidden = true
            end

            --mj:log("loading:", checklistItem.title, " isComplete:", isComplete)

            local titleComplexArray = checklistItem.title
            local titleComplexView = uiComplexTextView:create(checklistItemView, titleComplexArray, nil)
            titleComplexView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
            titleComplexView.baseOffset = vec3(28.0,-4.0,0.0)
            
            local maxItemWidth = 30.0 + titleComplexView.size.x

            local countTextView = nil
            if checklistItem.updateCountTextTypeKey then
                countTextView = TextView.new(checklistItemView)
                countTextView.font = Font(uiCommon.fontName, 16)
                countTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
                --countTextView.baseOffset = vec3(4,0,0)
                countTextView.relativeView = titleComplexView
                
                maxItemWidth = maxItemWidth + 40.0
            end

            local itemHeight = titleComplexView.size.y + 4.0

            local wrapWidthToUse = nil
            --if panelIndex > 1 then --todo?
            if not tipType.disableWordWrap then
                wrapWidthToUse = subTipWrapWidth
            end
            local subtitles = checklistItem.subtitles
            if not subtitles and checklistItem.subtitle then
                subtitles = {checklistItem.subtitle}
            end
            local subtitleYOffset = -titleComplexView.size.y - 4.0
            if subtitles then
                for j, subtitleComplexArray in ipairs(subtitles) do
                    local subtitleComplexView = uiComplexTextView:create(checklistItemView, subtitleComplexArray, wrapWidthToUse)
                    subtitleComplexView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
                    subtitleComplexView.baseOffset = vec3(28.0 + subtitleTabWidth,subtitleYOffset,0.0)

                    maxItemWidth = math.max(maxItemWidth, 28.0 + subtitleTabWidth + subtitleComplexView.size.x)
                    itemHeight = itemHeight + subtitleComplexView.size.y
                    subtitleYOffset = subtitleYOffset - subtitleComplexView.size.y
                end
            end

            itemOffsetY = itemOffsetY + itemHeight
            checklistItemView.size = vec2(maxItemWidth,itemHeight)
            maxLineWidth = math.max(maxLineWidth, maxItemWidth)


            
            checklistItemInfos[i] = {
                view = checklistItemView,
                itemTickView = itemTickView,
                isComplete = isComplete,
                countTextView = countTextView,
            }

            if checklistItem.updateCountTextTypeKey then
                updateCountTextForPanelInfo(checklistItem.updateCountTextTypeKey, panelInfo)
            end

            --uiComplexTextView
            --subtitle
        end
    end

    panelHeight = panelHeight + itemOffsetY
    panelInfo.panelHeight = panelHeight
    
    local panelWidth = math.max(maxLineWidth, titleTextView.size.x) + 20.0
    --local panelHeight = titleTextView.size.y + 40-- + #tipType.lines * 26

    panelView.size = vec2(panelWidth, panelHeight)
    local panelScale = vec2(panelView.size.x * 0.5, panelView.size.y * 0.5 / 0.2)
    panelView.scale3D = vec3(panelScale.x, panelScale.y, 30.0)

    local additionalYOffset = 0
    for i,otherPanelInfo in ipairs(currentTipTypeInfos) do
        if i == #currentTipTypeInfos then
            panelInfo.additionalYOffsetGoal = additionalYOffset
            panelInfo.additionalYOffset = panelInfo.additionalYOffsetGoal
        end
        additionalYOffset = additionalYOffset + panelInfo.panelHeight + paddingBetweenPanels
    end
    panelView.baseOffset = vec3(panelXOffset, slideAnimationOffset + baseYOffset + panelInfo.additionalYOffset, panelBaseZOffset)
            
    if tipType.storyPanel then
        tutorialStoryPanel:show(tipType)
    else
        audio:playUISound("audio/sounds/events/tutorial.wav", 0.3, nil)
    end

    queueNextTipDelayTimer = delayBetweenTips
    gameUI:updateUIHidden()
end

local function canShowStoryPanel()
    return (not discoveryUI:isDisplayedOrHasQueued()) and (not tribeRelationsUI:isDisplayedOrHasQueued()) and gameUI:canShowInvasivePopup()
end

local function update(dt)
    if disabled or (not currentTipOrderIndex) then
        return
    end

    local doInfrequentChecks = false
    incrementTimer = incrementTimer + dt
    if incrementTimer >= 0.25 then
        incrementTimer = 0.0
        doInfrequentChecks = true
    end
    
    local function tipIsInvalid(tipType)
        if tipType.becameInvalidFunction then
            return tipType.becameInvalidFunction()
        end
        return false
    end

    local function tipIsReady(tipType)
        if tipType.readyToDisplayFunction then
            local readyToDisplay = tipType.readyToDisplayFunction()
            if not readyToDisplay then
                return false
            end
        elseif not world:hasSelectedTribeID() then
            return false
        end
        return (not tipIsInvalid(tipType))
    end

    local function tipIsComplete(tipType)
        local allComplete = true

        local checklist = tipType.checklist
        if checklist then
            for i,checklistItem in ipairs(checklist) do
                local isComplete = checklistItem.isCompleteFunction()
                if not isComplete then
                    allComplete = false
                    break
                end
            end
        end
        return allComplete
    end

    local function checkAndShowFinalTip(tipTypeIndex)
        if tipTypeIndex == tutorialUI.types.completion.index then
            if canShowStoryPanel() then
                local tipType = tutorialUI.types[tipTypeIndex]
                tutorialStoryPanel:show(tipType)
                currentTipOrderIndex = nil
                saveValue("complete", "tutorialTipKey")
            else
                queueNextTipDelayTimer = math.max(queueNextTipDelayTimer, delayAfterBlockingUIDismissed)
            end
            return true
        end
        return false
    end

    local function incrementCurrentTipIndex()
        currentTipOrderIndex = currentTipOrderIndex + 1
        local newTipTypeIndex = orderedTips[currentTipOrderIndex]
        if not newTipTypeIndex then
            currentTipOrderIndex = nil
            saveValue("complete", "tutorialTipKey")
        else
            saveValue(tutorialUI.types[newTipTypeIndex].key, "tutorialTipKey")
        end
    end

    if queueNextTipDelayTimer > 0.0 then
        queueNextTipDelayTimer = queueNextTipDelayTimer - dt
    end

    if doInfrequentChecks then
        


        for i,panelInfo in ipairs(currentTipTypeInfos) do
            if not panelInfo.slidingOff and tipIsInvalid(tutorialUI.types[panelInfo.tipTypeIndex]) then
                panelInfo.hideDelayTimer = nil
                panelInfo.slidingOff = true
                panelInfo.slideAnimationTimer = 1.0
            end
        end

        if queueNextTipDelayTimer <= 0.0 and world:getSpeedMultiplier() < (gameConstants.ultraSpeed - 0.1) then
            local firstPanelInfo = currentTipTypeInfos[1]

            if not firstPanelInfo then
                local tipTypeIndex = orderedTips[currentTipOrderIndex]
                local tipType = tutorialUI.types[tipTypeIndex]
                if tipIsReady(tipType) then
                    if checkAndShowFinalTip(tipTypeIndex) then
                        return
                    else
                        if tipIsComplete(tipType) then
                            incrementCurrentTipIndex()
                        elseif canShowStoryPanel() then
                            addPanel(tipTypeIndex)
                        else
                            queueNextTipDelayTimer = math.max(queueNextTipDelayTimer, delayAfterBlockingUIDismissed)
                        end
                    end
                end
            else
                local tipTypeIndex = orderedTips[currentTipOrderIndex]
                if tipTypeIndex ~= tutorialUI.types.completion.index then
                    local alreadyDisplayed = false
                    for j=1,#currentTipTypeInfos do
                        if currentTipTypeInfos[j].tipTypeIndex == tipTypeIndex then
                            alreadyDisplayed = true
                            break
                        end
                    end
                    if not alreadyDisplayed then
                        local tipType = tutorialUI.types[tipTypeIndex]
                        if tipIsReady(tipType) then
                            if tipIsComplete(tipType) then
                                incrementCurrentTipIndex()
                            elseif canShowStoryPanel() then
                                addPanel(tipTypeIndex)
                            else
                                queueNextTipDelayTimer = math.max(queueNextTipDelayTimer, delayAfterBlockingUIDismissed)
                            end
                        end
                    end
                end

                local firstTipTypeIndex = firstPanelInfo.tipTypeIndex
                local firstTipType = tutorialUI.types[firstTipTypeIndex]
                if (not firstPanelInfo.slidingOff) and firstTipType.allowSimultaneous then
                    if canShowStoryPanel() then
                        for i,otherTipTypeIndex in ipairs(firstTipType.allowSimultaneous) do

                            if #currentTipTypeInfos < maxSimultaneousCount or tutorialUI.types[otherTipTypeIndex].allowDisplayAboveMaxSimultaneousCount then
                                local alreadyDisplayed = false
                                for j=2,#currentTipTypeInfos do
                                    if currentTipTypeInfos[j].tipTypeIndex == otherTipTypeIndex then
                                        alreadyDisplayed = true
                                        break
                                    end
                                end

                                local otherTipType = tutorialUI.types[otherTipTypeIndex]
                                if (not alreadyDisplayed) and tipIsReady(otherTipType) then
                                    if not tipIsComplete(otherTipType) then
                                        addPanel(otherTipTypeIndex)
                                        break
                                    end
                                end
                            end
                        end
                    else
                        queueNextTipDelayTimer = math.max(queueNextTipDelayTimer, delayAfterBlockingUIDismissed)
                    end
                end
            end
        end
    end

    local additionalYOffset = 0
    for i,panelInfo in ipairs(currentTipTypeInfos) do
        panelInfo.additionalYOffsetGoal = additionalYOffset
        additionalYOffset = additionalYOffset + panelInfo.panelHeight + paddingBetweenPanels
        local prevAdditionalYOffset = panelInfo.additionalYOffset or 0
        panelInfo.additionalYOffset = prevAdditionalYOffset + (panelInfo.additionalYOffsetGoal - prevAdditionalYOffset) * math.min(dt * 8.0, 1.0)
    end


    for i,panelInfo in ipairs(currentTipTypeInfos) do
        if panelInfo.slidingOn then
            panelInfo.slideAnimationTimer = panelInfo.slideAnimationTimer + dt * 4.0
            local fraction = panelInfo.slideAnimationTimer
            fraction = math.pow(fraction, 0.1)
            if fraction < 1.0 then
                panelInfo.panelView.baseOffset = vec3(panelXOffset, slideAnimationOffset * (1.0 - fraction) + baseYOffset + panelInfo.additionalYOffset, panelBaseZOffset + 10.0 * (1.0 - math.pow(fraction, 8)))
            else
                panelInfo.panelView.baseOffset = vec3(panelXOffset, baseYOffset + panelInfo.additionalYOffset, panelBaseZOffset)
                panelInfo.slideAnimationTimer = 1.0
                panelInfo.slidingOn = nil
            end
        elseif panelInfo.slidingOff then
            panelInfo.slideAnimationTimer = panelInfo.slideAnimationTimer - dt * 4.0
            local fraction = panelInfo.slideAnimationTimer
            fraction = math.pow(fraction, 0.8)
            if fraction > 0.0 then
                panelInfo.panelView.baseOffset = vec3(panelXOffset, slideAnimationOffset * (1.0 - fraction) + baseYOffset + panelInfo.additionalYOffset, panelBaseZOffset + 10.0 * (1.0 - math.pow(fraction, 8)))
            else 
                queueNextTipDelayTimer = delayBetweenTips

                mainView:removeSubview(panelInfo.panelView)
                table.remove(currentTipTypeInfos, i)

                gameUI:updateUIHidden() -- why?

                break
                
               --[[ 
                hidden = true
                displayIsQueued = true]]
            end
        else
            
            panelInfo.panelView.baseOffset = vec3(panelXOffset, baseYOffset + panelInfo.additionalYOffset, panelBaseZOffset)

            local allComplete = true

            for j,checklistItemViewInfo in ipairs(panelInfo.checklistItemInfos) do
                local tipType = tutorialUI.types[panelInfo.tipTypeIndex]
                local checklistItem = tipType.checklist[j]
                if not checklistItemViewInfo.isComplete then
                    allComplete = false
                    if doInfrequentChecks then
                        local isComplete = checklistItem.isCompleteFunction()
                        if isComplete then
                            checklistItemViewInfo.isComplete = true
                            checklistItemViewInfo.itemTickView.hidden = false
                            queueNextTipDelayTimer = delayBetweenTips

                            audio:playUISound("audio/sounds/events/notification3.wav", 0.3, nil)
                            
                            local tickAnimationTimer = 0.0
                            checklistItemViewInfo.itemTickView.update = function(dt_)
                                tickAnimationTimer = tickAnimationTimer + dt_ * 0.5
                                if tickAnimationTimer >= 1.0 then
                                    checklistItemViewInfo.itemTickView.alpha = 1.0
                                    checklistItemViewInfo.itemTickView.update = nil
                                    checklistItemViewInfo.itemTickView.scale3D = vec3(itemTickHalfSize,itemTickHalfSize,itemTickHalfSize)
                                    checklistItemViewInfo.itemTickView.baseOffset = vec3(-1,1,2)
                                else
                                    checklistItemViewInfo.itemTickView.alpha = math.sin(tickAnimationTimer * math.pi * 0.83) * 2.0
                                    --local scale = 1.0 + (1.0 - tickAnimationTimer * tickAnimationTimer) * 4.0
                                    local scaleTimer = math.pow(1.0 - tickAnimationTimer, 5)
                                    local scale = 1.0 + scaleTimer * 10.0
                                    checklistItemViewInfo.itemTickView.scale3D = vec3(itemTickHalfSize,itemTickHalfSize,itemTickHalfSize) * scale
                                    checklistItemViewInfo.itemTickView.baseOffset = vec3(-1,1,8.0 - (tickAnimationTimer * 6.0))
                                end
                            end
                        end
                    end
                end
            end

            if allComplete then
                if panelInfo.hideDelayTimer then
                    panelInfo.hideDelayTimer = panelInfo.hideDelayTimer - dt
                    if panelInfo.hideDelayTimer <= 0.0 then
                        panelInfo.hideDelayTimer = nil
                        panelInfo.slidingOff = true
                        panelInfo.slideAnimationTimer = 1.0
                    end
                else
                    queueNextTipDelayTimer = delayBetweenTips
                    panelInfo.hideDelayTimer = hideDelayAfterCompletingTasks
                    local tickView = panelInfo.tickView
                    tickView.hidden = false
                    local tickAnimationTimer = 0.0
                    tickView.update = function(dt_)
                        tickAnimationTimer = tickAnimationTimer + dt_
                        if tickAnimationTimer >= 1.0 then
                            tickView.alpha = 1.0
                            tickView.update = nil
                            tickView.scale3D = vec3(tickHalfSize,tickHalfSize,tickHalfSize)
                        else
                            tickView.alpha = math.sin(tickAnimationTimer * math.pi * 0.83) * 2.0
                            local scale = 1.0 + (1.0 - tickAnimationTimer * tickAnimationTimer)
                            tickView.scale3D = vec3(tickHalfSize,tickHalfSize,tickHalfSize) * scale
                        end
                    end
                end
            end
        end
    end
end

function tutorialUI:show()
    if not showTutorial then
        return
    end

    queueNextTipDelayTimer = delayBeforeFirstTip
    
    if (not timerID) and currentTipOrderIndex then
        --mj:log("tutorialUI:show setting displayIsQueued")
        --displayIsQueued = true
        timerID = timer:addUpdateTimer(update)
    end
end

function tutorialUI:resetDelayTimer()
    queueNextTipDelayTimer = delayBetweenTips
end

local function checkDiscoveries()
    local serverClientState = world:getServerClientState()
    local discoveries = serverClientState.privateShared.discoveries

    for researchTypeIndex,researchCompletionKey in pairs(researchCompletionKeysByResearchTypeIndex) do
        local discoveryInfo = discoveries[researchTypeIndex]
        if discoveryInfo and discoveryInfo.complete then
            tutorialUI:researchCompleted(researchTypeIndex)
        end
    end
end

function tutorialUI:init(gameUI_, world_, localPlayer_, intro_, tutorialStoryPanel_, logicInterface_)
    gameUI = gameUI_
    world = world_
    localPlayer = localPlayer_
    intro = intro_
    tutorialStoryPanel = tutorialStoryPanel_
    logicInterface = logicInterface_

    

    mainView = View.new(gameUI.tipsView)
    mainView.size = gameUI.tipsView.size

    clientWorldSettingsDatabase = world:getClientWorldSettingsDatabase()

   -- resetTutorialState()
    --checkDiscoveries()
    --loadCompletionValues(world:getTutorialServerClientState())

    showTutorial = false
end

function tutorialUI:worldTribeIDReceived(tribeID)

    mj:log("tutorialUI:worldTribeIDReceived")

    local migrate = false

    local tutorialDisabledForThisWorld = clientWorldSettingsDatabase:dataForKey("tutorialSkipped" .. "_" .. tribeID)
    if not tutorialDisabledForThisWorld then
        tutorialDisabledForThisWorld = clientWorldSettingsDatabase:dataForKey("tutorialSkipped")
        if tutorialDisabledForThisWorld then
            clientWorldSettingsDatabase:removeDataForKey("tutorialSkipped")
            clientWorldSettingsDatabase:setDataForKey(tutorialDisabledForThisWorld, "tutorialSkipped" .. "_" .. tribeID)
        end
    end

    local currentTipTypeKey = clientWorldSettingsDatabase:dataForKey("tutorialTipKey" .. "_" .. tribeID)
    if not currentTipTypeKey then
        currentTipTypeKey = clientWorldSettingsDatabase:dataForKey("tutorialTipKey")
        if currentTipTypeKey then 
            migrate = true

            clientWorldSettingsDatabase:setDataForKey(currentTipTypeKey, "tutorialTipKey" .. "_" .. tribeID)

            clientWorldSettingsDatabase:removeDataForKey("tutorialTipKey") --this is the marker we use, lets not bother cleaning up
        end
    end
    

    if not currentTipTypeKey then
        currentTipOrderIndex = 1
    elseif currentTipTypeKey ~= "complete" then
        currentTipOrderIndex = 1
        for i, tipTypeIndex in ipairs(orderedTips) do
            if tutorialUI.types[tipTypeIndex].key == currentTipTypeKey then
                currentTipOrderIndex = i
                break
            end
        end
    end
    
    resetTutorialState()
    checkDiscoveries()
    loadCompletionValues(world:getTutorialServerClientState(), migrate)

    hasTribeID = true

    for i,info in ipairs(preLoadInfoQueue) do
        tutorialUI:netTutorialStateChanged(info)
    end
    preLoadInfoQueue = {}
    
    showTutorial = (not tutorialDisabledForThisWorld)
end

function tutorialUI:skipTutorialSettingChanged(newSkipTutorial)
    showTutorial = (not newSkipTutorial)
    if showTutorial then
        if gameUI:getWorldHasLoaded() then
            tutorialUI:show()
            mainView.hidden = false
        end
    else
        if timerID then
            timer:removeTimer(timerID)
            timerID = nil
        end
        mainView.hidden = true
    end
end

function tutorialUI:reset() --this isn't called anymore, the UI option to do this is gone, as it doesn't seem very useful
    logicInterface:callServerFunction("resetTutorial")
    clientWorldSettingsDatabase:removeDataForKey("tutorialTipKey")
    currentTipOrderIndex = 1
    for k,v in pairs(tutorialState) do
        clientWorldSettingsDatabase:removeDataForKey(k)
    end
    resetTutorialState()
    checkDiscoveries()
    
    queueNextTipDelayTimer = delayBetweenTips

    for i,panelInfo in ipairs(currentTipTypeInfos) do
        mainView:removeSubview(panelInfo.panelView)
    end
    currentTipTypeInfos = {}

    gameUI:updateUIHidden() -- why?
end

--function tutorialUI:hide()
    --slideOff()
--end

function tutorialUI:disable()
    disabled = true
    --slideOff()
end

function tutorialUI:enable()
    disabled = false
end

function tutorialUI:hidden()
    return #currentTipTypeInfos == 0
end

return tutorialUI