local action = mjrequire "common/action"
local typeMaps = mjrequire "common/typeMaps"


local actionSequence = {}
    
actionSequence.types = typeMaps:createMap( "actionSequence", {
    {
        key = "idle",
        actions = {
            action.types.idle.index
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "moveTo",
        actions = {
            action.types.moveTo.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "chop",
        actions = {
            action.types.moveTo.index,
            action.types.chop.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "pullOut",
        actions = {
            action.types.moveTo.index,
            action.types.pullOut.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "gather",
        actions = {
            action.types.moveTo.index,
            action.types.gather.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "gatherBush",
        actions = {
            action.types.moveTo.index,
            action.types.gatherBush.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "dig",
        actions = {
            action.types.moveTo.index,
            action.types.dig.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "clear",
        actions = {
            action.types.moveTo.index,
            action.types.clear.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "pickupObject",
        actions = {
            action.types.moveTo.index,
            action.types.pickup.index,
        },
        assignedTriggerIndex = 2,
        --assignModifierTypeIndex = action.modifierTypes.crouch.index,
    },
    {
        key = "pickupMultiObject",
        actions = {
            action.types.moveTo.index,
            action.types.pickupMultiCrouch.index,
            action.types.pickupMultiAddToHeld.index,
        },
        assignedTriggerIndex = 2,
        --assignModifierTypeIndex = action.modifierTypes.crouch.index,
    },
    {
        key = "deliverObject",
        actions = {
            action.types.moveTo.index,
            action.types.place.index,
        },
        assignedTriggerIndex = 2,
        --assignModifierTypeIndex = action.modifierTypes.crouch.index,
    },
    {
        key = "deliverMultiObject",
        actions = {
            action.types.moveTo.index,
            action.types.placeMultiCrouch.index,
            action.types.placeMultiFromHeld.index,
        },
        assignedTriggerIndex = 2,
        --assignModifierTypeIndex = action.modifierTypes.crouch.index,
    },
    {
        key = "dropObject",
        actions = {
            action.types.place.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "eat",
        actions = {
            action.types.eat.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "playFlute",
        actions = {
            action.types.moveTo.index,
            action.types.playFlute.index,
        },
        assignedTriggerIndex = 2,
        countsAsPlayingMusicalInstrumentForTutorial = true,
    },
    {
        key = "playDrum",
        actions = {
            action.types.moveTo.index,
            action.types.playDrum.index,
        },
        assignedTriggerIndex = 2,
        countsAsPlayingMusicalInstrumentForTutorial = true,
    },
    {
        key = "playBalafon",
        actions = {
            action.types.moveTo.index,
            action.types.playBalafon.index,
        },
        assignedTriggerIndex = 2,
        countsAsPlayingMusicalInstrumentForTutorial = true,
    },
    {
        key = "wave",
        actions = {
            action.types.wave.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "turn",
        actions = {
            action.types.turn.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "fall",
        actions = {
            action.types.fall.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "sleep",
        actions = {
            action.types.moveTo.index,
            action.types.sleep.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "sit",
        actions = {
            action.types.moveTo.index,
            action.types.sit.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "buildMoveComponent",
        actions = {
            action.types.moveTo.index,
            action.types.buildMoveComponent.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "light",
        actions = {
            action.types.moveTo.index,
            action.types.light.index,
        },
        assignedTriggerIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "extinguish",
        actions = {
            action.types.moveTo.index,
            action.types.extinguish.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "destroyContents",
        actions = {
            action.types.moveTo.index,
            action.types.destroyContents.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "throwProjectile",
        actions = {
            action.types.moveTo.index,
            action.types.throwProjectile.index,
            action.types.throwProjectileFollowThrough.index,
        },
        assignedTriggerIndex = 2,
    },
    {
        key = "butcher",
        actions = {
            action.types.moveTo.index,
            action.types.butcher.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "knap",
        actions = {
            action.types.moveTo.index,
            action.types.knap.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "knapCrude",
        actions = {
            action.types.moveTo.index,
            action.types.knapCrude.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "grind",
        actions = {
            action.types.moveTo.index,
            action.types.grind.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "scrapeWood",
        actions = {
            action.types.moveTo.index,
            action.types.scrapeWood.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "fireStickCook",
        actions = {
            action.types.moveTo.index,
            action.types.fireStickCook.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "smeltMetal",
        actions = {
            action.types.moveTo.index,
            action.types.smeltMetal.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "recruit",
        actions = {
            action.types.moveTo.index,
            action.types.recruit.index,
        },
        assignedTriggerIndex = 2,
    },
    {
        key = "banish",
        actions = {
            action.types.moveTo.index,
            action.types.banish.index,
        },
        assignedTriggerIndex = 2,
    },
    {
        key = "fight",
        actions = {
            action.types.moveTo.index,
            action.types.fight.index,
            action.types.fightFollowThrough.index,
        },
        assignedTriggerIndex = 2,
    },
    {
        key = "defend",
        actions = {
            action.types.moveTo.index,
            action.types.defend.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "inspect",
        actions = {
            action.types.moveTo.index,
            action.types.inspect.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "patDown",
        actions = {
            action.types.moveTo.index,
            action.types.patDown.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "potteryCraft",
        actions = {
            action.types.moveTo.index,
            action.types.potteryCraft.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "toolAssembly",
        actions = {
            action.types.moveTo.index,
            action.types.toolAssembly.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "thresh",
        actions = {
            action.types.moveTo.index,
            action.types.thresh.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "spinCraft",
        actions = {
            action.types.moveTo.index,
            action.types.spinCraft.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "mine",
        actions = {
            action.types.moveTo.index,
            action.types.mine.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "takeOffTorsoClothing",
        actions = {
            action.types.takeOffTorsoClothing.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "putOnTorsoClothing",
        actions = {
            action.types.putOnTorsoClothing.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "flee",
        actions = {
            action.types.flee.index,
        },
        assignedTriggerIndex = 1,
        assignModifierTypeIndex = action.modifierTypes.run.index,
    },
    {
        key = "selfApplyOralMedicine",
        actions = {
            action.types.selfApplyOralMedicine.index,
        },
        assignedTriggerIndex = 1,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "selfApplyTopicalMedicine",
        actions = {
            action.types.selfApplyTopicalMedicine.index,
        },
        assignedTriggerIndex = 1,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "otherApplyOralMedicine",
        actions = {
            action.types.moveTo.index,
            action.types.otherApplyOralMedicine.index,
        },
        assignedTriggerIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "otherApplyTopicalMedicine",
        actions = {
            action.types.moveTo.index,
            action.types.otherApplyTopicalMedicine.index,
        },
        assignedTriggerIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "smithHammer",
        actions = {
            action.types.moveTo.index,
            action.types.smithHammer.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
        assignModifierTypeIndex = action.modifierTypes.sit.index,
    },
    {
        key = "chiselStone",
        actions = {
            action.types.moveTo.index,
            action.types.chiselStone.index,
        },
        assignedTriggerIndex = 2,
        snapToOrderObjectIndex = 2,
    },
    {
        key = "haulDragObject",
        actions = {
            action.types.dragObject.index,
        },
        assignedTriggerIndex = 1,
    },
    {
        key = "greet",
        actions = {
            action.types.moveTo.index,
            action.types.greet.index,
        },
        assignedTriggerIndex = 2,
    },
})

return actionSequence