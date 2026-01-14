local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
--local mat3Rotate = mjm.mat3Rotate

local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local action = {}

local function medicineCarryTransformFunction(placeholderIndex, gameObjectType, isBeingPickedUp)
    return {
        offset = vec3(0.0,0.05,0.0),
        rotation = mat3Identity,
    }
end

action.types = typeMaps:createMap( "action", {
    {
        key = "idle",
        name = locale:get("action_idle"),
        inProgress = locale:get("action_idle_inProgress"),
        restNeedModifier = -0.5,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "gather",
        name = locale:get("action_gather"),
        inProgress = locale:get("action_gather_inProgress"),
        restNeedModifier = 1.0,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "gatherBush",
        name = locale:get("action_gather"),
        inProgress = locale:get("action_gather_inProgress"),
        restNeedModifier = 1.0,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "chop",
        name = locale:get("action_chop"),
        inProgress = locale:get("action_chop_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "pullOut",
        name = locale:get("action_pullOut"),
        inProgress = locale:get("action_pullOut_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "dig",
        name = locale:get("action_dig"),
        inProgress = locale:get("action_dig_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "mine",
        name = locale:get("action_mine"),
        inProgress = locale:get("action_mine_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "clear",
        name = locale:get("action_clear"),
        inProgress = locale:get("action_clear_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "moveTo",
        name = locale:get("action_moveTo"),
        inProgress = locale:get("action_moveTo_inProgress"),
        restNeedModifier = 1.0,
        allowMoreFrequentMultitasks = true,
        isMovementAction = true,
    },
    {
        key = "pickup",
        name = locale:get("action_pickup"),
        inProgress = locale:get("action_pickup_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "pickupMultiCrouch",
        name = locale:get("action_pickup"),
        inProgress = locale:get("action_pickup_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "pickupMultiAddToHeld",
        name = locale:get("action_pickup"),
        inProgress = locale:get("action_pickup_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "place",
        name = locale:get("action_place"),
        inProgress = locale:get("action_place_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "placeMultiCrouch",
        name = locale:get("action_place"),
        inProgress = locale:get("action_place_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "placeMultiFromHeld",
        name = locale:get("action_place"),
        inProgress = locale:get("action_place_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "eat",
        name = locale:get("action_eat"),
        inProgress = locale:get("action_eat_inProgress"),
        restNeedModifier = 0.0,
        preventMultitask = true,
    },
    {
        key = "wave",
        name = locale:get("action_wave"),
        inProgress = locale:get("action_wave_inProgress"),
        restNeedModifier = 0.0,
        preventMultitask = true,
    },
    {
        key = "turn",
        name = locale:get("action_turn"),
        inProgress = locale:get("action_turn_inProgress"),
        restNeedModifier = 0.0,
        preventMultitask = true,
    },
    {
        key = "fall",
        name = locale:get("action_fall"),
        inProgress = locale:get("action_fall_inProgress"),
        restNeedModifier = 0.0,
        preventMultitask = true,
    },
    {
        key = "sleep",
        name = locale:get("action_sleep"),
        inProgress = locale:get("action_sleep_inProgress"),
        restNeedModifier = -1.0,
        preventMultitask = true,
    },
    {
        key = "buildMoveComponent",
        name = locale:get("action_build"),
        inProgress = locale:get("action_build_inProgress"),
        restNeedModifier = 1.5,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "light",
        name = locale:get("action_light"),
        inProgress = locale:get("action_light_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "extinguish",
        name = locale:get("action_extinguish"),
        inProgress = locale:get("action_extinguish_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "destroyContents",
        name = locale:get("action_destroyContents"),
        inProgress = locale:get("action_destroyContents_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "throwProjectile",
        name = locale:get("action_throwProjectile"),
        inProgress = locale:get("action_throwProjectile_inProgress"),
        restNeedModifier = 2.0,
        preventMultitask = true,
    },
    {
        key = "throwProjectileFollowThrough",
        name = locale:get("action_throwProjectile"),
        inProgress = locale:get("action_throwProjectile_inProgress"),
        restNeedModifier = 2.0,
        preventMultitask = true,
    },
    {
        key = "butcher",
        name = locale:get("action_butcher"),
        inProgress = locale:get("action_butcher_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "knap",
        name = locale:get("action_knap"),
        inProgress = locale:get("action_knap_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "knapCrude",
        name = locale:get("action_knap"),
        inProgress = locale:get("action_knap_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "grind",
        name = locale:get("action_grind"),
        inProgress = locale:get("action_grind_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "scrapeWood",
        name = locale:get("action_scrapeWood"),
        inProgress = locale:get("action_scrapeWood_inProgress"),
        restNeedModifier = 1.5,
    },
    {
        key = "fireStickCook",
        name = locale:get("action_fireStickCook"),
        inProgress = locale:get("action_fireStickCook_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "smeltMetal",
        name = locale:get("action_smeltMetal"),
        inProgress = locale:get("action_smeltMetal_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "recruit",
        name = locale:get("action_recruit"),
        inProgress = locale:get("action_recruit_inProgress"),
        restNeedModifier = 0.5,
        preventMultitask = true,
    },
    {
        key = "banish",
        name = locale:get("action_banish"),
        inProgress = locale:get("action_banish_inProgress"),
        restNeedModifier = 0.5,
        preventMultitask = true,
    },
    {
        key = "fight",
        name = locale:get("action_fight"),
        inProgress = locale:get("action_fight_inProgress"),
        restNeedModifier = 2.0,
        preventMultitask = true,
    },
    {
        key = "fightFollowThrough",
        name = locale:get("action_fight_inProgress"),
        inProgress = locale:get("action_fight_inProgress"),
        restNeedModifier = 2.0,
        preventMultitask = true,
    },
    {
        key = "defend",
        name = locale:get("action_defend"),
        inProgress = locale:get("action_defend_inProgress"),
        restNeedModifier = 0.0,
        preventMultitask = true,
    },
    {
        key = "sit",
        name = locale:get("action_sit"),
        inProgress = locale:get("action_sit_inProgress"),
        restNeedModifier = -1.0,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "inspect",
        name = locale:get("action_inspect"),
        inProgress = locale:get("action_inspect_inProgress"),
        restNeedModifier = -1.0,
    },
    {
        key = "patDown",
        name = locale:get("action_patDown"),
        inProgress = locale:get("action_patDown_inProgress"),
        restNeedModifier = -1.0,
    },
    {
        key = "potteryCraft",
        name = locale:get("action_potteryCraft"),
        inProgress = locale:get("action_potteryCraft_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "toolAssembly",
        name = locale:get("action_craft"),
        inProgress = locale:get("action_craft_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "spinCraft",
        name = locale:get("action_spinCraft"),
        inProgress = locale:get("action_spinCraft_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "thresh",
        name = locale:get("action_thresh"),
        inProgress = locale:get("action_thresh_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "takeOffTorsoClothing",
        name = locale:get("action_takeOffTorsoClothing"),
        inProgress = locale:get("action_takeOffTorsoClothing_inProgress"),
        restNeedModifier = 0.0,
    },
    {
        key = "putOnTorsoClothing",
        name = locale:get("action_putOnTorsoClothing"),
        inProgress = locale:get("action_putOnTorsoClothing_inProgress"),
        restNeedModifier = 0.0,
    },
    {
        key = "flee",
        name = locale:get("action_flee"),
        inProgress = locale:get("action_flee_inProgress"),
        restNeedModifier = 1.0,
        preventMultitask = true,
        isMovementAction = true,
    },
    {
        key = "playFlute",
        name = locale:get("action_playFlute"),
        inProgress = locale:get("action_playFlute_inProgress"),
        restNeedModifier = 0.0,
        preventMultitask = true,
    },
    {
        key = "playDrum",
        name = locale:get("action_playDrum"),
        inProgress = locale:get("action_playDrum_inProgress"),
        restNeedModifier = 0.0,
    },
    {
        key = "playBalafon",
        name = locale:get("action_playBalafon"),
        inProgress = locale:get("action_playBalafon_inProgress"),
        restNeedModifier = 0.0,
    },
    {
        key = "selfApplyOralMedicine",
        name = locale:get("action_selfApplyOralMedicine"),
        inProgress = locale:get("action_selfApplyOralMedicine_inProgress"),
        restNeedModifier = 0.0,
        heldObjectPlaceholderKeyOverride = "leftHandObject",
        carryTransformFunction = medicineCarryTransformFunction,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "selfApplyTopicalMedicine",
        name = locale:get("action_selfApplyTopicalMedicine"),
        inProgress = locale:get("action_selfApplyTopicalMedicine_inProgress"),
        restNeedModifier = 0.0,
        heldObjectPlaceholderKeyOverride = "leftHandObject",
        carryTransformFunction = medicineCarryTransformFunction,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "otherApplyOralMedicine",
        name = locale:get("action_giveMedicine"),
        inProgress = locale:get("action_giveMedicine_inProgress"),
        restNeedModifier = 0.0,
        heldObjectPlaceholderKeyOverride = "leftHandObject",
        carryTransformFunction = medicineCarryTransformFunction,
        allowMoreFrequentMultitasks = true,
    },
    {
        key = "otherApplyTopicalMedicine",
        name = locale:get("action_giveMedicine"),
        inProgress = locale:get("action_giveMedicine_inProgress"),
        restNeedModifier = 0.0,
        heldObjectPlaceholderKeyOverride = "leftHandObject",
        carryTransformFunction = medicineCarryTransformFunction,
        allowMoreFrequentMultitasks = true,
    },

    {
        key = "smithHammer",
        name = locale:get("action_smithHammer"),
        inProgress = locale:get("action_smithHammer_inProgress"),
        restNeedModifier = 1.0,
    },
    {
        key = "chiselStone",
        name = locale:get("action_chiselStone"),
        inProgress = locale:get("action_chiselStone_inProgress"),
        restNeedModifier = 2.0,
    },
    {
        key = "dragObject",
        name = locale:get("action_dragObject"),
        inProgress = locale:get("action_dragObject_inProgress"),
        restNeedModifier = 4.0,
        moveSpeedMultiplier = 0.9,
        isMovementAction = true,
    },
    {
        key = "greet",
        name = locale:get("action_greet"),
        inProgress = locale:get("action_greet_inProgress"),
        restNeedModifier = 0.5,
        preventMultitask = true,
    },
    {
        key = "row",
        name = locale:get("action_row"),
        inProgress = locale:get("action_row_inProgress"),
        restNeedModifier = 2.0,
        moveSpeedMultiplier = 1.0,
        isMovementAction = true,
    },
    
    
})


action.modifierTypes = typeMaps:createMap( "actionModifier", {
    {
        key = "sneak",
        name = locale:get("action_sneak"),
        inProgress = locale:get("action_sneak_inProgress"),
        moveSpeedMultiplier = 0.7,
        moveRestNeedMultiplier = 0.7,
    },
    {
        key = "jog",
        name = locale:get("action_jog"),
        inProgress = locale:get("action_jog_inProgress"),
        moveSpeedMultiplier = 1.4,
        moveRestNeedMultiplier = 1.4,
    },
    {
        key = "run",
        name = locale:get("action_run"),
        inProgress = locale:get("action_run_inProgress"),
        moveSpeedMultiplier = 2.0,
        moveRestNeedMultiplier = 2.0,
    },
    {
        key = "slowWalk",
        name = locale:get("action_slowWalk"),
        inProgress = locale:get("action_slowWalk_inProgress"),
        moveSpeedMultiplier = 0.5,
        moveRestNeedMultiplier = 0.5,
    },
    {
        key = "sadWalk",
        name = locale:get("action_sadWalk"),
        inProgress = locale:get("action_sadWalk_inProgress"),
        moveSpeedMultiplier = 0.5,
        headXRotationOffset = -1.0,
        moveRestNeedMultiplier = 0.5,
    },
    {
        key = "sit",
        name = locale:get("action_sit"),
        inProgress = locale:get("action_sit_inProgress"),
    },
    {
        key = "crouch",
        name = locale:get("action_crouch"),
        inProgress = locale:get("action_crouch_inProgress"),
    },
    --[[{
        key = "defend", --unimplemented run away covering your head, put your shield up in a fight
        name = locale:get("action_defend"),
        inProgress = locale:get("action_defend_inProgress"),
    },]]
    --[[{
        key = "dragObject",
        name = locale:get("action_dragObject"),
        inProgress = locale:get("action_dragObject_inProgress"),
        moveSpeedMultiplier = 0.5,
        moveRestNeedMultiplier = 2.0,
    }]]

    --WARNING these are modifiers, perhaps you want the action types up there ^^^^^^^
})

--local validModifierTypes = typeMaps:createValidTypesArray("actionModifier", action.modifierTypes)

function action:getModifierValue(actionModifierState, modifierValueName)
    if actionModifierState then
        for k,v in pairs(actionModifierState) do
            local modfiierValue = action.modifierTypes[k][modifierValueName]
            if modfiierValue then
                return modfiierValue
            end
        end
    end

    return nil
end

function action:hasModifier(actionModifierState, modifierTypeIndex)
    if actionModifierState then
        return actionModifierState[modifierTypeIndex] ~= nil
    end

    return nil
end

function action:modifierMoveSpeedMultiplier(actionModifierState)
    if actionModifierState then
        for k,v in pairs(actionModifierState) do
            if action.modifierTypes[k].moveSpeedMultiplier then
                return action.modifierTypes[k].moveSpeedMultiplier
            end
        end
    end

    return 1.0
end


function action:combinedMoveSpeedMultiplier(actionTypeIndex, actionModifierState)
    local baseValue = 1.0
    
    if actionTypeIndex then
        local actionMoveSpeedMultiplier = action.types[actionTypeIndex].moveSpeedMultiplier
        if actionMoveSpeedMultiplier then
            baseValue = actionMoveSpeedMultiplier
        end
    end

    return baseValue * action:modifierMoveSpeedMultiplier(actionModifierState)
end

return action