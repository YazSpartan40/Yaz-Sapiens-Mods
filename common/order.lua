
--local resource = mjrequire "common/resource"

local typeMaps = mjrequire "common/typeMaps"
local locale = mjrequire "common/locale"

local order = {}


order.multitaskTypes = typeMaps:createMap( "order_multitask", {
    {
        key = "social",
        name = locale:get("order_multitask_social"),
        inProgressName = locale:get("order_multitask_social_inProgress"),
    },
    {
        key = "lookAt",
        name = locale:get("order_multitask_lookAt"),
        inProgressName = locale:get("order_multitask_lookAt_inProgress"),
    },
})



order.moveToMotivationTypes = typeMaps:createMap( "order_moveToMotivation", {
    {
        key = "warmth",
        statusText = locale:get("order_moveToMotivation_warmth"),
    },
    {
        key = "light",
        statusText = locale:get("order_moveToMotivation_light"),
    },
    {
        key = "bed",
        statusText = locale:get("order_moveToMotivation_bed"),
    },
    {
        key = "avoidThreat",
        statusText = locale:get("order_moveToMotivation_avoidThreat"),
    },
})

order.types = typeMaps:createMap( "order", {
    {
        key = "gather",
        name = locale:get("order_gather"),
        inProgressName = locale:get("order_gather_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_hand",
    },
    {
        key = "chop",
        name = locale:get("order_chop"),
        inProgressName = locale:get("order_chop_inProgress"),
        disallowsLimitedAbilitySapiens = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_axe",
    },
    {
        key = "storeObject",
        name = locale:get("order_storeObject"),
        inProgressName = locale:get("order_storeObject_inProgress"),
        icon = "icon_store",
    },
    {
        key = "transferObject",
        name = locale:get("order_transferObject"),
        inProgressName = locale:get("order_transferObject_inProgress"),
        icon = "icon_logistics",
    },
    {
        key = "pullOut",
        name = locale:get("order_pullOut"),
        inProgressName = locale:get("order_pullOut_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_dig",
    },
    {
        key = "moveTo",
        name = locale:get("order_moveTo"),
        inProgressName = locale:get("order_moveTo_inProgress"),
        icon = "icon_feet",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "moveToLogistics",
        name = locale:get("order_moveToLogistics"),
        inProgressName = locale:get("order_moveToLogistics_inProgress"),
        icon = "icon_logistics",
    },
    {
        key = "flee",
        name = locale:get("order_flee"),
        inProgressName = locale:get("order_flee_inProgress"),
        icon = "icon_feet",
        shouldRunWherePossible = true,
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "sneakTo", --don't think this is used
        name = locale:get("order_sneakTo"),
        inProgressName = locale:get("order_sneakTo_inProgress"),
        icon = "icon_feet",
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "pickupObject",
        name = locale:get("order_pickupObject"),
        inProgressName = locale:get("order_pickupObject_inProgress"),
        icon = "icon_hand",
        --allowToFinishEvenWhenThreatNearBy = true, --hmm
    },
    {
        key = "deliverObjectToConstructionObject",
        name = locale:get("order_deliver"),
        inProgressName = locale:get("order_deliver_inProgress"),
        icon = "icon_hammer",
    },
    {
        key = "pickupPlanObjectForCraftingOrResearchElsewhere",
        name = locale:get("order_deliver"),
        inProgressName = locale:get("order_deliver_inProgress"),
        icon = "icon_hammer",
    },
    {
        key = "deliverPlanObjectForCraftingOrResearchElsewhere",
        name = locale:get("order_deliver"),
        inProgressName = locale:get("order_deliver_inProgress"),
        icon = "icon_hammer",
    },
    {
        key = "deliverFuel",
        name = locale:get("order_deliver"),
        inProgressName = locale:get("order_deliver_inProgress"),
        icon = "icon_fire",
    },
    {
        key = "deliverObjectToStorage",
        name = locale:get("order_deliver"),
        inProgressName = locale:get("order_deliver_inProgress"),
        icon = "icon_store",
    },
    {
        key = "deliverObjectTransfer",
        name = locale:get("order_deliver"),
        inProgressName = locale:get("order_deliver_inProgress"),
        icon = "icon_logistics",
    },
    {
        key = "removeObject",
        name = locale:get("order_removeObject"),
        inProgressName = locale:get("order_removeObject_inProgress"),
        icon = "icon_hand",
    },
    {
        key = "buildMoveComponent",
        name = locale:get("order_buildMoveComponent"),
        inProgressName = locale:get("order_buildMoveComponent_inProgress"),
        icon = "icon_hammer",
    },
    {
        key = "buildActionSequence",
        name = locale:get("order_buildActionSequence"),
        inProgressName = locale:get("order_buildActionSequence_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 1,
        icon = "icon_hammer",
    },
    {
        key = "eat",
        name = locale:get("order_eat"),
        inProgressName = locale:get("order_eat_inProgress"),
        icon = "icon_food",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "dig",
        name = locale:get("order_dig"),
        inProgressName = locale:get("order_dig_inProgress"),
        disallowsLimitedAbilitySapiens = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_dig",
    },
    {
        key = "mine",
        name = locale:get("order_mine"),
        inProgressName = locale:get("order_mine_inProgress"),
        disallowsLimitedAbilitySapiens = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_mine",
    },
    {
        key = "clear",
        name = locale:get("order_clear"),
        inProgressName = locale:get("order_clear_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_clear",
    },
    {
        key = "follow", --not used
        name = locale:get("order_follow"),
        inProgressName = locale:get("order_follow_inProgress"),
        standingOrder = true,
        icon = "icon_feet",
    },
    {
        key = "social",
        name = locale:get("order_social"),
        inProgressName = locale:get("order_social_inProgress"),
        canDoWhileSitting = true,
        allowCancellationDueToNewIncomingLookedAtOrder = true,
        icon = "icon_feet",
    },
    {
        key = "turn",
        name = locale:get("order_turn"),
        inProgressName = locale:get("order_turn_inProgress"),
        allowCancellationDueToNewIncomingLookedAtOrder = true,
        icon = "icon_feet",
    },
    {
        key = "disposeOfObject",
        name = locale:get("order_dropObject"),
        inProgressName = locale:get("order_dropObject_inProgress"),
        icon = "icon_hand",
    },
    {
        key = "dropObject",
        name = locale:get("order_dropObject"),
        inProgressName = locale:get("order_dropObject_inProgress"),
        icon = "icon_hand",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "sleep",
        name = locale:get("order_sleep"),
        inProgressName = locale:get("order_sleep_inProgress"),
        icon = "icon_bed",
        allowToFinishEvenWhenVeryTired = true,
    },
    {
        key = "light",
        name = locale:get("order_light"),
        inProgressName = locale:get("order_light_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_fire",
    },
    {
        key = "extinguish",
        name = locale:get("order_extinguish"),
        inProgressName = locale:get("order_extinguish_inProgress"),
        icon = "icon_extinguish",
    },
    {
        key = "throwProjectile",
        name = locale:get("order_throwProjectile"),
        inProgressName = locale:get("order_throwProjectile_inProgress"),
        --allowsSimultaneousOrdersForSingleObject = true,
        disallowsLimitedAbilitySapiens = true,
        icon = "icon_axe",
        shouldRunWherePossible = true,
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "recruit",
        name = locale:get("order_recruit"),
        inProgressName = locale:get("order_recruit_inProgress"),
        icon = "icon_tribe2",
        shouldRunWherePossible = true,
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "banish",
        name = locale:get("order_banish"),
        inProgressName = locale:get("order_banish_inProgress"),
        icon = "icon_banish",
        shouldRunWherePossible = true,
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "fight", --hand to hand combat
        name = locale:get("order_fight"),
        inProgressName = locale:get("order_fight_inProgress"),
        icon = "icon_fist",
        shouldRunWherePossible = true,
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
        --autoExtend = true,
    },
    {
        key = "defend",
        name = locale:get("order_defend"),
        inProgressName = locale:get("order_defend_inProgress"),
        icon = "icon_shield",
        shouldRunWherePossible = true,
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 3, --This should mean a sapien is assigned for 30 seconds, then will check other plans and needs every 10 seconds
    },
    {
        key = "sit",
        name = locale:get("order_sit"),
        inProgressName = locale:get("order_sit_inProgress"),
        autoExtend = true,
        allowCancellationDueToNewIncomingLookedAtOrder = true,
        autoExtendCheckDelayCount = 16,
        icon = "icon_sit",
    },
    {
        key = "fall",
        name = locale:get("order_fall"),
        inProgressName = locale:get("order_fall_inProgress"),
        icon = "icon_feet",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "butcher",
        name = locale:get("order_butcher"),
        inProgressName = locale:get("order_butcher_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_food",
    },
    {
        key = "putOnClothing",
        name = locale:get("order_putOnClothing"),
        inProgressName = locale:get("order_putOnClothing_inProgress"),
        icon = "icon_hand",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "takeOffClothing",
        name = locale:get("order_takeOffClothing"),
        inProgressName = locale:get("order_takeOffClothing_inProgress"),
        icon = "icon_hand",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
    },
    {
        key = "playInstrument",
        name = locale:get("order_playInstrument"),
        inProgressName = locale:get("order_playInstrument_inProgress"),
        autoExtend = true,
        allowCancellationDueToNewIncomingLookedAtOrder = true,
        autoExtendCheckDelayCount = 64,
        icon = "icon_music",
    },
    {
        key = "destroyContents",
        name = locale:get("order_destroyContents"),
        inProgressName = locale:get("order_destroyContents_inProgress"),
        icon = "icon_cancel",
    },
    {
        key = "giveMedicineToSelf",
        name = locale:get("order_giveMedicineToSelf"),
        inProgressName = locale:get("order_giveMedicineToSelf_inProgress"),
        icon = "icon_injury",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
    },
    {
        key = "giveMedicineToOtherSapien",
        name = locale:get("order_giveMedicineToOtherSapien"),
        inProgressName = locale:get("order_giveMedicineToOtherSapien_inProgress"),
        icon = "icon_injury",
        allowToFinishEvenWhenVeryTired = true,
        allowToFinishEvenWhenThreatNearBy = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
    },
    {
        key = "fertilize",
        name = locale:get("order_fertilize"),
        inProgressName = locale:get("order_fertilize_inProgress"),
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_mulch",
    },
    {
        key = "deliverToCompost",
        name = locale:get("order_deliverToCompost"),
        inProgressName = locale:get("order_deliverToCompost_inProgress"),
        icon = "icon_logistics",
    },
    {
        key = "chiselStone",
        name = locale:get("order_chiselStone"),
        inProgressName = locale:get("order_chiselStone_inProgress"),
        disallowsLimitedAbilitySapiens = true,
        autoExtend = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_chisel",
    },
    {
        key = "haulMoveToObject",
        name = locale:get("order_haul"),
        inProgressName = locale:get("order_haul_inProgress"),
        disallowsLimitedAbilityAndElderSapiens = true,
        autoExtendReplaceOrder = true,
        autoExtendCheckDelayCount = 0,
        icon = "icon_transfer",
    },
    {
        key = "haulDragObject",
        name = locale:get("order_haul"),
        inProgressName = locale:get("order_haul_inProgress"),
        disallowsLimitedAbilityAndElderSapiens = true,
        icon = "icon_transfer",
    },
    {
        key = "haulRideObject",
        name = locale:get("order_haul"),
        inProgressName = locale:get("order_haul_inProgress"),
        icon = "icon_transfer",
    },
    {
        key = "greet",
        name = locale:get("order_greet"),
        inProgressName = locale:get("order_greet_inProgress"),
        icon = "icon_tribeRelations",
        allowToFinishEvenWhenThreatNearBy = true,
    },
})


function order:createOrderPathInfo(goalObjectIDOrNil, proximityType, proximityDistanceOrNil, goalPosOrNil, optionsOrNil, initialObjectPos) --initialObjectPos Only required for objects that move, to decide when a path needs to be recalculated
    --mj:log("createOrderPathInfo goalObjectIDOrNil:", goalObjectIDOrNil, " traceback:", debug.traceback())
    return {
        goalObjectIDOrNil = goalObjectIDOrNil,
        initialObjectPos = initialObjectPos, --WARNING! added in 0.7, so not available in queued orders in older game saves. 
        proximityType = proximityType,
        proximityDistance = proximityDistanceOrNil,
        goalPosOrNil = goalPosOrNil,
        options = optionsOrNil,
    }
end

function order:createOrder(orderTypeIndex, sapien, pathInfo, object, context)
    local objectID = nil
    local pos = nil
    if object then
        objectID = object.uniqueID
        pos = object.pos
    end
	local orderState = {
		orderTypeIndex = orderTypeIndex,
		objectID = objectID,
        pos = pos,
        sapienID = sapien.uniqueID,
        context = context,
        pathInfo = pathInfo,
    }
    
    return orderState
end

return order
