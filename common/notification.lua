local typeMaps = mjrequire "common/typeMaps"
local sapienConstants = mjrequire "common/sapienConstants"
local locale = mjrequire "common/locale"
local notificationSound = mjrequire "common/notificationSound"
local skill = mjrequire "common/skill"
local research = mjrequire "common/research"
local resource = mjrequire "common/resource"
local material = mjrequire "common/material"
local grievance = mjrequire "common/grievance"
--local action = mjrequire "common/action"
local constructable = mjrequire "common/constructable"

local gameObject = nil
local mob = nil
local orderStatus = nil

local notification = {}

notification.displayGroups = mj:indexed {
    {
        key = "standard",
        name = locale:get("notification_displayGroup_informative"),
        foregroundMaterial = material.types.ui_standard.index,
        backgroundMaterial = material.types.ui_background.index,
        icon = "icon_tribe2",
    },
    {
        key = "researchSkill",
        name = locale:get("notification_displayGroup_skillsAndResearch"),
        foregroundMaterial = material.types.ui_selected.index,
        backgroundMaterial = material.types.ui_background_blue.index,
        icon = "icon_idea",
    },
    {
        key = "bad",
        name = locale:get("notification_displayGroup_minorWarning"),
        foregroundMaterial = material.types.mood_mildNegative.index,
        backgroundMaterial = material.types.mood_uiBackground_mildNegative.index,
        icon = "icon_warning",
    },
    {
        key = "veryBad",
        name = locale:get("notification_displayGroup_majorWarning"),
        foregroundMaterial = material.types.mood_severeNegative.index,
        backgroundMaterial = material.types.mood_uiBackground_severeNegative.index,
        icon = "icon_warning",
    },
    {
        key = "favorLost",
        name = locale:get("notification_displayGroup_favorLost"),
        foregroundMaterial = material.types.ui_bronze_mildNegative.index,
        backgroundMaterial = material.types.ui_bronze.index,
        icon = "icon_down",
    },
    {
        key = "favorGained",
        name = locale:get("notification_displayGroup_favorGained"),
        foregroundMaterial = material.types.ui_bronze_mildPositive.index,
        backgroundMaterial = material.types.ui_bronze.index,
        icon = "icon_up",
    },
    {
        key = "conflict",
        name = locale:get("notification_displayGroup_conflict"),
        foregroundMaterial = material.types.ui_iron.index,
        backgroundMaterial = material.types.ui_iron.index,
        icon = "icon_spear",
    },
}

local grievanceTitleFunctionsByGrieveanceTypeIndex = {
    [grievance.types.resourcesTaken.index] = function(userData)
        local resourcePlural = userData.resourceTypeIndex and (resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural)
        resourcePlural = resourcePlural or gameObject.types[userData.objectTypeIndex].plural
        return locale:get("notification_tribeGrievance_resourcesTaken", {
            resourcePlural = resourcePlural,
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.bedsUsed.index] = function(userData)
        return locale:get("notification_tribeGrievance_bedsUsed", {
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.objectsDestroyed.index] = function(userData)
        return locale:get("notification_tribeGrievance_objectsDestroyed", {
            objectName = gameObject.types[userData.objectTypeIndex].name,
            objectPlural = gameObject.types[userData.objectTypeIndex].plural,
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.objectsBuilt.index] = function(userData)
        return locale:get("notification_tribeGrievance_objectsBuilt", {
            objectName = gameObject.types[userData.objectTypeIndex].name,
            objectPlural = gameObject.types[userData.objectTypeIndex].plural,
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.craftAreasUsed.index] = function(userData)
        return locale:get("notification_tribeGrievance_craftAreasUsed", {
            objectName = gameObject.types[userData.objectTypeIndex].name,
            objectPlural = gameObject.types[userData.objectTypeIndex].plural,
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.sapienRecruited.index] = function(userData)
        return locale:get("notification_tribeGrievance_sapienRecruited", {
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.sapienBanished.index] = function(userData)
        return locale:get("notification_tribeGrievance_sapienBanished", {
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.sapienAttacked.index] = function(userData)
        return locale:get("notification_tribeGrievance_sapienAttacked", {
            tribeName = userData.tribeName,
        })
    end,
    [grievance.types.nomadsMistreated.index] = function(userData)
        return locale:get("notification_tribeGrievance_nomadsMistreated", {
            tribeName = userData.tribeName,
        })
    end,
}


--NOTES:
-- notifications are used for both displayed alerts, and for some internal events like playing a sound effect when tools break
-- the existence of titleFunction is used to determine whether the notification should be saved and displayed. 

notification.types = typeMaps:createMap("notification", {
    {
        key = "social",
    },
    {
        key = "toolBroke",
    },
    {
        key = "updateUI",
    },
    {
        key = "fireLit",
    },
    {
        key = "reloadModel",
        requiresObjectModelReload = true,
    },
    {
        key = "tribeFirstMet",
        titleFunction = function(userData)
            return locale:get("notification_tribeFirstMet", {
                name = userData.name,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationPositive.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },

    {
        key = "becamePregnant",
        titleFunction = function(userData)
            return locale:get("notification_becamePregnant", {
                name = userData.name
            })
        end,
        soundTypeIndex = notificationSound.types.babyGrew.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
        requiresObjectModelReload = true,
    },
    {
        key = "babyBorn",
        titleFunction = function(userData)
            return locale:get("notification_babyBorn", {
                parentName = userData.name,
                babyIsFemale = userData.babyIsFemale,
            })
        end,
        soundTypeIndex = notificationSound.types.babyGrew.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
        requiresObjectModelReload = true,
    },
    {
        key = "babyGrew",
        titleFunction = function(userData)
            return locale:get("notification_babyGrew", {
                parentName = userData.name,
                childName = userData.childName,
            })
        end,
        soundTypeIndex = notificationSound.types.babyGrew.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
        requiresObjectModelReload = true,
    },
    {
        key = "agedUp",
        titleFunction = function(userData)
            local lifeStageName = sapienConstants.lifeStages[userData.lifeStageIndex].name
            return locale:get("notification_agedUp", {
                name = userData.name,
                lifeStageName = lifeStageName,
            })
        end,
        soundTypeIndex = notificationSound.types.babyGrew.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
        requiresObjectModelReload = true,
    },
    {
        key = "died",
        titleFunction = function(userData)
            return locale:get("notification_died", {
                name = userData.name,
                deathReason = locale:get(userData.deathReasonKey),
            })
        end,
        soundTypeIndex = notificationSound.types.sadEvent.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "left",
        titleFunction = function(userData)
            return locale:get("notification_left", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.sadWarning.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "banished",
        titleFunction = function(userData)
            return locale:get("notification_banished", {
                name = userData.name,
                tribeName = userData.tribeName, --this is the name of the other tribe that banished our sapien
            })
        end,
        soundTypeIndex = notificationSound.types.sadWarning.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "lowLoyalty",
        titleFunction = function(userData)
            return locale:get("notification_lowLoyalty", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "recruited",
        titleFunction = function(userData)
            return locale:get("notification_recruited", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationPositive.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "recruitedTakenByOtherTribe",
        titleFunction = function(userData)
            return locale:get("notification_recruitedTakenByOtherTribe", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.sadWarning.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "recruitFail",
        titleFunction = function(userData)
            return locale:get("notification_recruitFail", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "banishSuccess",
        titleFunction = function(userData)
            return locale:get("notification_banishSuccess", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationPositive.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "banishFail",
        titleFunction = function(userData)
            return locale:get("notification_banishFail", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "banishedByOtherTribe",
        titleFunction = function(userData)
            return locale:get("notification_banishedByOtherTribe", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.sadWarning.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "sapienUnderAttack",
        titleFunction = function(userData)
            return locale:get("notification_sapienUnderAttack", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.conflict.index,
        displayGroupTypeIndex = notification.displayGroups.conflict.index,
    },
    {
        key = "sapienFleeing", --our sapien is fleeing from something
        titleFunction = function(userData)
            return locale:get("notification_sapienFleeing", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.conflict.index,
        displayGroupTypeIndex = notification.displayGroups.conflict.index,
    },
    {
        key = "threatScared", --we scared away another sapien. name is our sapien's name
        titleFunction = function(userData)
            return locale:get("notification_threatScared", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.conflict.index,
        displayGroupTypeIndex = notification.displayGroups.conflict.index,
    },
    {
        key = "skillLearned",
        titleFunction = function(userData)
            return locale:get("notification_skillLearned", {
                name = userData.name,
                skillName = skill.types[userData.skillTypeIndex].name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.researchSkill.index,
    },
    {
        key = "recruitmentIncreasedDiscovery",
        titleFunction = function(userData)
            return locale:get("notification_recruitmentIncreasedDiscovery", {
                name = userData.name,
                skillName = skill.types[userData.skillTypeIndex].name,
                discoveryName = research.types[userData.researchTypeIndex].name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.researchSkill.index,
    },
    {
        key = "newTribeSeen",
        titleFunction = function(userData)
            return locale:get("notification_newTribeSeen", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.threatDiscovery.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "dangerousNewTribeSeen",
        titleFunction = function(userData)
            return locale:get("notification_dangerousNewTribeSeen", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.conflict.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "discovery",
        titleFunction = function(userData)
            return locale:get("notification_discovery", {
                skillName = research.types[userData.researchTypeIndex].name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index, --save the research sound for when the panel pops up
        displayGroupTypeIndex = notification.displayGroups.researchSkill.index,
    },
    {
        key = "craftableDiscovery",
        titleFunction = function(userData)
            return locale:get("notification_craftableDiscovery", {
                craftableName = constructable.types[userData.discoveryCraftableTypeIndex].name,
                craftablePlural = constructable.types[userData.discoveryCraftableTypeIndex].plural,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.researchSkill.index,
    },
    {
        key = "researchNearlyDone",
        titleFunction = function(userData)
            return locale:get("notification_researchNearlyDone", {
                sapienName = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.researchNearlyDone.index,
        displayGroupTypeIndex = notification.displayGroups.researchSkill.index,
    },
    {
        key = "mammothKill",
        titleFunction = function(userData)
            return locale:get("notification_mammothKill", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "minorInjury",
        titleFunction = function(userData)
            if userData.mobTypeIndex then
                return locale:get("notification_minorInjuryBy", {
                    name = userData.name,
                    objectName = mob.types[userData.mobTypeIndex].name,
                })
            end

            if userData.hitByFlyingObjectTypeIndex then
                return locale:get("notification_minorInjuryBy", {
                    name = userData.name,
                    objectName = locale:get("notification_addWindBlownAdjective", {objectName = gameObject.types[userData.hitByFlyingObjectTypeIndex].name}),
                })
            end
                
            if userData.hitBySapienTribeName then
                return locale:get("notification_minorInjuryByAttack", {
                    name = userData.name,
                    tribeName = userData.hitBySapienTribeName,
                })
            end

            local triggerAction = orderStatus:getStatusTextForNotification(userData)
            if not triggerAction then
                mj:error("no triggerAction for:", userData)
                triggerAction = ""
            end

            return locale:get("notification_minorInjury", {
                name = userData.name,
                triggerAction = triggerAction,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "majorInjury",
        titleFunction = function(userData)
            if userData then
                if userData.mobTypeIndex then
                    return locale:get("notification_majorInjuryBy", {
                        name = userData.name,
                        objectName = mob.types[userData.mobTypeIndex].name,
                    })
                end

                if userData.hitByFlyingObjectTypeIndex then
                    return locale:get("notification_majorInjuryBy", {
                        name = userData.name,
                        objectName = locale:get("notification_addWindBlownAdjective", {objectName = gameObject.types[userData.hitByFlyingObjectTypeIndex].name}),
                    })
                end
                
                if userData.hitBySapienTribeName then
                    return locale:get("notification_majorInjuryByAttack", {
                        name = userData.name,
                        tribeName = userData.hitBySapienTribeName,
                    })
                end

                local triggerAction = orderStatus:getStatusTextForNotification(userData)

                if triggerAction then
                    return locale:get("notification_majorInjury", {
                        name = userData.name,
                        triggerAction = triggerAction,
                    })
                end
            end
                
            return locale:get("notification_majorInjuryDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "criticalInjury",
        titleFunction = function(userData)
            if userData then
                if userData.mobTypeIndex then
                    return locale:get("notification_criticalInjuryBy", {
                        name = userData.name,
                        objectName = mob.types[userData.mobTypeIndex].name,
                    })
                end

                if userData.hitByFlyingObjectTypeIndex then
                    return locale:get("notification_criticalInjuryBy", {
                        name = userData.name,
                        objectName = locale:get("notification_addWindBlownAdjective", {objectName = gameObject.types[userData.hitByFlyingObjectTypeIndex].name}),
                    })
                end
                
                if userData.hitBySapienTribeName then
                    return locale:get("notification_criticalInjuryByAttack", {
                        name = userData.name,
                        tribeName = userData.hitBySapienTribeName,
                    })
                end

                local triggerAction = orderStatus:getStatusTextForNotification(userData)
                if triggerAction then
                    return locale:get("notification_criticalInjury", {
                        name = userData.name,
                        triggerAction = triggerAction,
                    })
                end
            end
            
            return locale:get("notification_criticalInjuryDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "minorInjuryHealed",
        titleFunction = function(userData)
            return locale:get("notification_minorInjuryHealed", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "majorInjuryBecameMinor",
        titleFunction = function(userData)
            return locale:get("notification_majorInjuryBecameMinor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "criticalInjuryBecameMajor",
        titleFunction = function(userData)
            return locale:get("notification_criticalInjuryBecameMajor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "minorBurn",
        titleFunction = function(userData)
            if userData and (userData.craftingConstructableTypeIndex or userData.researchingAtObjectTypeIndex or userData.deliveringToObjectTypeIndex) then
                local triggerAction = nil
                if userData.craftingConstructableTypeIndex then
                    local craftingConstructable = constructable.types[userData.craftingConstructableTypeIndex]
                    triggerAction = locale:get("notification_triggerActionCrafting", {
                        craftableName = craftingConstructable.name,
                        craftablePlural = craftingConstructable.plural,
                    })
                elseif userData.researchingAtObjectTypeIndex then
                    triggerAction = locale:get("notification_triggerActionResearching", {
                        objectName = gameObject.types[userData.researchingAtObjectTypeIndex].name,
                    })
                else
                    triggerAction = locale:get("notification_triggerActionDeliveringFuel", {
                        objectName = gameObject.types[userData.deliveringToObjectTypeIndex].name,
                    })
                end
                return locale:get("notification_minorBurn", {
                    name = userData.name,
                    triggerAction = triggerAction,
                })
            end
            return ""
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "majorBurn",
        titleFunction = function(userData)
            if userData and (userData.craftingConstructableTypeIndex or userData.researchingAtObjectTypeIndex or userData.deliveringToObjectTypeIndex) then
                local triggerAction = nil
                if userData.craftingConstructableTypeIndex then
                    local craftingConstructable = constructable.types[userData.craftingConstructableTypeIndex]
                    triggerAction = locale:get("notification_triggerActionCrafting", {
                        craftableName = craftingConstructable.name,
                        craftablePlural = craftingConstructable.plural,
                    })
                elseif userData.researchingAtObjectTypeIndex then
                    triggerAction = locale:get("notification_triggerActionResearching", {
                        objectName = gameObject.types[userData.researchingAtObjectTypeIndex].name,
                    })
                else
                    triggerAction = locale:get("notification_triggerActionDeliveringFuel", {
                        objectName = gameObject.types[userData.deliveringToObjectTypeIndex].name,
                    })
                end
                return locale:get("notification_majorBurn", {
                    name = userData.name,
                    triggerAction = triggerAction,
                })
            end
            return locale:get("notification_majorBurnDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "criticalBurn",
        titleFunction = function(userData)
            if userData and (userData.craftingConstructableTypeIndex or userData.researchingAtObjectTypeIndex or userData.deliveringToObjectTypeIndex) then
                local triggerAction = nil
                if userData.craftingConstructableTypeIndex then
                    local craftingConstructable = constructable.types[userData.craftingConstructableTypeIndex]
                    triggerAction = locale:get("notification_triggerActionCrafting", {
                        craftableName = craftingConstructable.name,
                        craftablePlural = craftingConstructable.plural,
                    })
                elseif userData.researchingAtObjectTypeIndex then
                    triggerAction = locale:get("notification_triggerActionResearching", {
                        objectName = gameObject.types[userData.researchingAtObjectTypeIndex].name,
                    })
                else
                    triggerAction = locale:get("notification_triggerActionDeliveringFuel", {
                        objectName = gameObject.types[userData.deliveringToObjectTypeIndex].name,
                    })
                end
                return locale:get("notification_criticalBurn", {
                    name = userData.name,
                    triggerAction = triggerAction,
                })
            end
            return locale:get("notification_criticalBurnDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "minorBurnHealed",
        titleFunction = function(userData)
            return locale:get("notification_minorBurnHealed", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "majorBurnBecameMinor",
        titleFunction = function(userData)
            return locale:get("notification_majorBurnBecameMinor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "criticalBurnBecameMajor",
        titleFunction = function(userData)
            return locale:get("notification_criticalBurnBecameMajor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "minorFoodPoisoning",
        titleFunction = function(userData)
            if userData.contaminationResourceTypeIndex then
                return locale:get("notification_minorFoodPoisoningFromContamination", {
                    name = userData.name,
                    resourceName = string.lower(resource.types[userData.eatenResourceTypeIndex].name),
                    contaminationResourceName = string.lower(resource.types[userData.contaminationResourceTypeIndex].name),
                })
            else
                return locale:get("notification_minorFoodPoisoning", {
                    name = userData.name,
                    resourceName = string.lower(resource.types[userData.eatenResourceTypeIndex].name),
                })
            end
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "majorFoodPoisoning",
        titleFunction = function(userData)
            return locale:get("notification_majorFoodPoisoningDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "criticalFoodPoisoning",
        titleFunction = function(userData)
            return locale:get("notification_criticalFoodPoisoningDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "minorFoodPoisoningHealed",
        titleFunction = function(userData)
            return locale:get("notification_minorFoodPoisoningHealed", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "majorFoodPoisoningBecameMinor",
        titleFunction = function(userData)
            return locale:get("notification_majorFoodPoisoningBecameMinor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "criticalFoodPoisoningBecameMajor",
        titleFunction = function(userData)
            return locale:get("notification_criticalFoodPoisoningBecameMajor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "minorVirus",
        titleFunction = function(userData)
            return locale:get("notification_minorVirus", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "majorVirus",
        titleFunction = function(userData)
            return locale:get("notification_majorVirusDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "criticalVirus",
        titleFunction = function(userData)
            return locale:get("notification_criticalVirusDeveloped", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "minorVirusHealed",
        titleFunction = function(userData)
            return locale:get("notification_minorVirusHealed", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "majorVirusBecameMinor",
        titleFunction = function(userData)
            return locale:get("notification_majorVirusBecameMinor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "criticalVirusBecameMajor",
        titleFunction = function(userData)
            return locale:get("notification_criticalVirusBecameMajor", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "starving",
        titleFunction = function(userData)
            return locale:get("notification_starving", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "starvingRemoved",
        titleFunction = function(userData)
            return locale:get("notification_starvingRemoved", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "veryHungry",
        titleFunction = function(userData)
            return locale:get("notification_veryHungry", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "veryHungryRemoved",
        titleFunction = function(userData)
            return locale:get("notification_veryHungryRemoved", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "hypothermia",
        titleFunction = function(userData)
            return locale:get("notification_hypothermia", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.veryBad.index,
    },
    {
        key = "hypothermiaRemoved",
        titleFunction = function(userData)
            return locale:get("notification_hypothermiaRemoved", {
                name = userData.name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.standard.index,
    },
    {
        key = "windDestruction",
        titleFunction = function(userData)
            return locale:get("notification_windDestruction", {
                name = userData.name or gameObject.types[userData.objectTypeIndex].name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "rainDestruction",
        titleFunction = function(userData)
            return locale:get("notification_rainDestruction", {
                name = userData.name or gameObject.types[userData.objectTypeIndex].name,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.bad.index,
    },
    {
        key = "autoRoleAssign",
        titleFunction = function(userData) --commented out to supress this notifcation. Too noisy, could be an option after settings for individual notifications are added
            return locale:get("notification_autoRoleAssign", {
                name = userData.name,
                skillName = skill.types[userData.skillTypeIndex].name,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.researchSkill.index,
        --supressedByDefault = true, --this flag works, will save to db, but won't be displayed in either the tribe panel or as pop up notifications
    },

    {
        key = "grievance",
        titleFunction = function(userData)
            local func = grievanceTitleFunctionsByGrieveanceTypeIndex[userData.grievanceTypeIndex]
            if func then
                return func(userData)
            end

            mj:error("no title function for grievance type:", userData.grievanceTypeIndex)
            return nil
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.favorLost.index,
    },

    {
        key = "tradeRequestFavorReward",
        titleFunction = function(userData)
            return locale:get("notification_tradeRequestFavorReward", {
                reward = userData.reward,
                deliveredCount = userData.deliveredCount,
                resourcePlural = resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationPositive.index,
        displayGroupTypeIndex = notification.displayGroups.favorGained.index,
    },

    {
        key = "tradeOfferFavorPaid",
        titleFunction = function(userData)
            local resourcePlural = userData.resourceTypeIndex and (resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural)
            resourcePlural = resourcePlural or gameObject.types[userData.objectTypeIndex].plural
            return locale:get("notification_tradeOfferFavorPaid", {
                cost = userData.cost,
                count = userData.count,
                resourcePlural = resourcePlural,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notification.index,
        displayGroupTypeIndex = notification.displayGroups.favorLost.index,
    },

    {
        key = "resourceQuestFavorReward",
        titleFunction = function(userData)
            return locale:get("notification_resourceQuestFavorReward", {
                reward = userData.reward,
                deliveredCount = userData.deliveredCount,
                resourcePlural = resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationPositive.index,
        displayGroupTypeIndex = notification.displayGroups.favorGained.index,
    },
    {
        key = "resourceQuestFailFavorPenalty",
        titleFunction = function(userData)
            return locale:get("notification_resourceQuestFailFavorPenalty", {
                penalty = userData.penalty,
                requiredCount = userData.requiredCount,
                resourcePlural = resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.favorLost.index,
    },
    {
        key = "resourceQuestFailNoReward",
        titleFunction = function(userData)
            return locale:get("notification_resourceQuestFailNoReward", {
                requiredCount = userData.requiredCount,
                deliveredCount = userData.deliveredCount,
                resourcePlural = resource.types[userData.resourceTypeIndex].pluralGeneric or resource.types[userData.resourceTypeIndex].plural,
                tribeName = userData.tribeName,
            })
        end,
        soundTypeIndex = notificationSound.types.notificationBad.index,
        displayGroupTypeIndex = notification.displayGroups.favorLost.index,
    },

    
--[[

    notification_resourceQuestFailReducedFavorPenalty = function(values) --0.5
        return "Quest failed. We have lost " .. values.penalty .. " favor with the " .. values.tribeName .. " tribe for only delivering " ..values.deliveredCount .. " of the " .. values.requiredCount .. " required " .. values.resourcePlural
    end,

    notification_resourceQuestFailNoReward = function(values) --0.5
        return "Quest failed. As we delivered " .. values.deliveredCount .. " of the " .. values.requiredCount .. " required " .. values.resourcePlural .. ", our favor remains unchanged."
    end,
]]
    
    
})

function notification:getObjectInfo(notificationInfo)
    local objectInfo = notificationInfo.objectSaveData
    if notificationInfo.notificationTypeIndex == notification.types.newTribeSeen.index then
        local userData = notificationInfo.userData
        objectInfo = {
            uniqueID = userData.otherSapienID,
            objectTypeIndex = gameObject.types.sapien.index,
            sharedState = userData.otherSapienSharedState,
            pos = userData.otherSapienPos,
        }
    end
    return objectInfo
end

--overrides will remove exisiting notifications and prevent incoming notifications of the given types (maybe not working anymore)

notification.overrides = {
   --[[ [notification.types.discovery.index] = {
        [notification.types.skillLearned.index] = true,
        [notification.types.researchNearlyDone.index] = true,
    },]]
}

function notification:load(gameObject_, mob_)
    gameObject = gameObject_
    mob = mob_
end

function notification:setOrderStatus(orderStatus_) --only called from main thread. titleFunction() calls must only be used from main thread
    orderStatus = orderStatus_
end

function notification:mjInit()
    notification.validTypes = typeMaps:createValidTypesArray("notification", notification.types)
end

return notification