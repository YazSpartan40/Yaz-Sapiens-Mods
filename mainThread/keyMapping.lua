local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local locale = mjrequire "common/locale"

local keyMapping = {}

local keyCodes = {
	unknown            = 0,
	backspace          = 8,
	tab                = 9,
	key_return         = 13,
	escape             = 27,
	space              = 32,
	exclaim            = 33,
	quotedbl           = 34,
	hash               = 35,
	dollar             = 36,
	percent            = 37,
	ampersand          = 38,
	quote              = 39,
	leftparen          = 40,
	rightparen         = 41,
	asterisk           = 42,
	plus               = 43,
	comma              = 44,
	minus              = 45,
	period             = 46,
	slash              = 47,
	key_0              = 48,
	key_1              = 49,
	key_2              = 50,
	key_3              = 51,
	key_4              = 52,
	key_5              = 53,
	key_6              = 54,
	key_7              = 55,
	key_8              = 56,
	key_9              = 57,
	colon              = 58,
	semicolon          = 59,
	less               = 60,
	equals             = 61,
	greater            = 62,
	question           = 63,
	at                 = 64,
	leftbracket        = 91,
	backslash          = 92,
	rightbracket       = 93,
	caret              = 94,
	underscore         = 95,
	backquote          = 96,
	a                  = 97,
	b                  = 98,
	c                  = 99,
	d                  = 100,
	e                  = 101,
	f                  = 102,
	g                  = 103,
	h                  = 104,
	i                  = 105,
	j                  = 106,
	k                  = 107,
	l                  = 108,
	m                  = 109,
	n                  = 110,
	o                  = 111,
	p                  = 112,
	q                  = 113,
	r                  = 114,
	s                  = 115,
	t                  = 116,
	u                  = 117,
	v                  = 118,
	w                  = 119,
	x                  = 120,
	y                  = 121,
	z                  = 122,
	delete             = 127,
	capslock           = 1073741881,
	f1                 = 1073741882,
	f2                 = 1073741883,
	f3                 = 1073741884,
	f4                 = 1073741885,
	f5                 = 1073741886,
	f6                 = 1073741887,
	f7                 = 1073741888,
	f8                 = 1073741889,
	f9                 = 1073741890,
	f10                = 1073741891,
	f11                = 1073741892,
	f12                = 1073741893,
	printscreen        = 1073741894,
	scrolllock         = 1073741895,
	pause              = 1073741896,
	insert             = 1073741897,
	home               = 1073741898,
	pageup             = 1073741899,
	key_end            = 1073741901,
	pagedown           = 1073741902,
	right              = 1073741903,
	left               = 1073741904,
	down               = 1073741905,
	up                 = 1073741906,
	numlockclear       = 1073741907,
	kp_divide          = 1073741908,
	kp_multiply        = 1073741909,
	kp_minus           = 1073741910,
	kp_plus            = 1073741911,
	kp_enter           = 1073741912,
	kp_1               = 1073741913,
	kp_2               = 1073741914,
	kp_3               = 1073741915,
	kp_4               = 1073741916,
	kp_5               = 1073741917,
	kp_6               = 1073741918,
	kp_7               = 1073741919,
	kp_8               = 1073741920,
	kp_9               = 1073741921,
	kp_0               = 1073741922,
	kp_period          = 1073741923,
	application        = 1073741925,
	power              = 1073741926,
	kp_equals          = 1073741927,
	f13                = 1073741928,
	f14                = 1073741929,
	f15                = 1073741930,
	f16                = 1073741931,
	f17                = 1073741932,
	f18                = 1073741933,
	f19                = 1073741934,
	f20                = 1073741935,
	f21                = 1073741936,
	f22                = 1073741937,
	f23                = 1073741938,
	f24                = 1073741939,
	execute            = 1073741940,
	help               = 1073741941,
	menu               = 1073741942,
	select             = 1073741943,
	stop               = 1073741944,
	again              = 1073741945,
	undo               = 1073741946,
	cut                = 1073741947,
	copy               = 1073741948,
	paste              = 1073741949,
	find               = 1073741950,
	mute               = 1073741951,
	volumeup           = 1073741952,
	volumedown         = 1073741953,
	kp_comma           = 1073741957,
	kp_equalsas400     = 1073741958,
	alterase           = 1073741977,
	sysreq             = 1073741978,
	cancel             = 1073741979,
	clear              = 1073741980,
	prior              = 1073741981,
	return2            = 1073741982,
	separator          = 1073741983,
	out                = 1073741984,
	oper               = 1073741985,
	clearagain         = 1073741986,
	crsel              = 1073741987,
	exsel              = 1073741988,
	kp_00              = 1073742000,
	kp_000             = 1073742001,
	thousandsseparator = 1073742002,
	decimalseparator   = 1073742003,
	currencyunit       = 1073742004,
	currencysubunit    = 1073742005,
	kp_leftparen       = 1073742006,
	kp_rightparen      = 1073742007,
	kp_leftbrace       = 1073742008,
	kp_rightbrace      = 1073742009,
	kp_tab             = 1073742010,
	kp_backspace       = 1073742011,
	kp_a               = 1073742012,
	kp_b               = 1073742013,
	kp_c               = 1073742014,
	kp_d               = 1073742015,
	kp_e               = 1073742016,
	kp_f               = 1073742017,
	kp_xor             = 1073742018,
	kp_power           = 1073742019,
	kp_percent         = 1073742020,
	kp_less            = 1073742021,
	kp_greater         = 1073742022,
	kp_ampersand       = 1073742023,
	kp_dblampersand    = 1073742024,
	kp_verticalbar     = 1073742025,
	kp_dblverticalbar  = 1073742026,
	kp_colon           = 1073742027,
	kp_hash            = 1073742028,
	kp_space           = 1073742029,
	kp_at              = 1073742030,
	kp_exclam          = 1073742031,
	kp_memstore        = 1073742032,
	kp_memrecall       = 1073742033,
	kp_memclear        = 1073742034,
	kp_memadd          = 1073742035,
	kp_memsubtract     = 1073742036,
	kp_memmultiply     = 1073742037,
	kp_memdivide       = 1073742038,
	kp_plusminus       = 1073742039,
	kp_clear           = 1073742040,
	kp_clearentry      = 1073742041,
	kp_binary          = 1073742042,
	kp_octal           = 1073742043,
	kp_decimal         = 1073742044,
	kp_hexadecimal     = 1073742045,
	lctrl              = 1073742048,
	lshift             = 1073742049,
	lalt               = 1073742050,
	lgui               = 1073742051,
	rctrl              = 1073742052,
	rshift             = 1073742053,
	ralt               = 1073742054,
	rgui               = 1073742055,
	mode               = 1073742081,
	audionext          = 1073742082,
	audioprev          = 1073742083,
	audiostop          = 1073742084,
	audioplay          = 1073742085,
	audiomute          = 1073742086,
	mediaselect        = 1073742087,
	www                = 1073742088,
	mail               = 1073742089,
	calculator         = 1073742090,
	computer           = 1073742091,
	ac_search          = 1073742092,
	ac_home            = 1073742093,
	ac_back            = 1073742094,
	ac_forward         = 1073742095,
	ac_stop            = 1073742096,
	ac_refresh         = 1073742097,
	ac_bookmarks       = 1073742098,
	brightnessdown     = 1073742099,
	brightnessup       = 1073742100,
	displayswitch      = 1073742101,
	kbdillumtoggle     = 1073742102,
	kbdillumdown       = 1073742103,
	kbdillumup         = 1073742104,
	eject              = 1073742105,
	sleep              = 1073742106
}

local modifiers = {
    none = 0,
    shift = 1,
    ctrl = 2,
    alt = 3,
    cmd = 4,
}

local modifierKeyCodesByModifierCode = {
    [modifiers.none] = keyCodes.unknown,
    [modifiers.shift] = keyCodes.lshift,
    [modifiers.ctrl] = keyCodes.lctrl,
    [modifiers.alt] = keyCodes.lalt,
    [modifiers.cmd] = keyCodes.lgui,
}

local doubleMapping = {
    [keyCodes.kp_0] = keyCodes.key_0,
    [keyCodes.kp_1] = keyCodes.key_1,
    [keyCodes.kp_2] = keyCodes.key_2,
    [keyCodes.kp_3] = keyCodes.key_3,
    [keyCodes.kp_4] = keyCodes.key_4,
    [keyCodes.kp_5] = keyCodes.key_5,
    [keyCodes.kp_6] = keyCodes.key_6,
    [keyCodes.kp_7] = keyCodes.key_7,
    [keyCodes.kp_8] = keyCodes.key_8,
    [keyCodes.kp_9] = keyCodes.key_9,
    
    [keyCodes.kp_enter] = keyCodes.key_return,
    [keyCodes.kp_plus] = keyCodes.plus,
    [keyCodes.equals] = keyCodes.plus,
    [keyCodes.kp_minus] = keyCodes.minus,
    [keyCodes.kp_period] = keyCodes.period,

    [keyCodes.ralt] = keyCodes.lalt,
    [keyCodes.rshift] = keyCodes.lshift,
    [keyCodes.rctrl] = keyCodes.lctrl,
    [keyCodes.rgui] = keyCodes.lgui,
}


local keyCodeKeysByCode = {}
for key,keyCode in pairs(keyCodes) do
    keyCodeKeysByCode[keyCode] = key
end

local modifierKeysByKeyCode = {}
for key,keyCode in pairs(modifierKeyCodesByModifierCode) do
    modifierKeysByKeyCode[keyCode] = key
end

local indexCount = 0

local mappingGroups = {}
local conflictGroups = {}
local orderedGroupKeys = {}
local mappingsByInputKeyCodesAndMods = {}

local function getSettingsKey(groupKey, mapKey)
    return "key_" .. groupKey .. "_" .. mapKey
end

local function addGroup(groupKey)
    local group = {
        mappingsByKey = {},
        name = locale:get("keygroup_" .. groupKey),
        orderedMappingKeys = {},
    }
    mappingGroups[groupKey] = group
    table.insert(orderedGroupKeys, groupKey)
end

local function getModKey(mapping)
    local modToUse = mapping.mod or modifiers.none
	if mapping.mod2 and mapping.mod2 ~= modifiers.none then
		modToUse = string.format("%d_%d", modToUse, mapping.mod2)
	end
	return modToUse
end

local function setMappingByKeyCode(mapping)
    local mappingsByMod = mappingsByInputKeyCodesAndMods[mapping.keyCode]
    if not mappingsByMod then
        mappingsByMod = {}
        mappingsByInputKeyCodesAndMods[mapping.keyCode] = mappingsByMod
    end

    local modToUse = getModKey(mapping)
    local mappingsForMod = mappingsByMod[modToUse]
    if not mappingsForMod then
        mappingsForMod = {}
        mappingsByMod[modToUse] = mappingsForMod
    end

	local otherConflictGroups = conflictGroups[mapping.groupKey]
	if otherConflictGroups then
		for otherGroupKey,v in pairs(otherConflictGroups) do
			local otherGroup = mappingGroups[otherGroupKey]
            for i=#mappingsForMod,1,-1 do
				local otherMappingIndexToFind = mappingsForMod[i]
				for j,mappingKey in ipairs(otherGroup.orderedMappingKeys) do
					local otherMapping = otherGroup.mappingsByKey[mappingKey]
					if otherMapping.index == otherMappingIndexToFind then
						if otherMapping.defaultKeyCode ~= otherMapping.keyCode then
							if mapping.disableOnConflict then
								mj:warn("Skipping due to custom key binding conflict for existing mapping:", otherMapping, " when attempting to add mapping:", mapping)

								mapping.conflictBlockedByOtherIndexCount = (mapping.conflictBlockedByOtherIndexCount or 0) + 1

								if not otherMapping.conflictBlockingOtherMappings then
									otherMapping.conflictBlockingOtherMappings = {}
								end
								otherMapping.conflictBlockingOtherMappings[mapping.index] = mapping

								return
							--else
								--mj:log("key conflict found but no disableOnConflict for added key. existing:", otherMapping.groupKey, ".", otherMapping.mapKey, " adding:", mapping.groupKey, ".", mapping.mapKey)
							end
						else
							if otherMapping.disableOnConflict then
								mj:warn("Removing key binding due to key conflict. Removing existing mapping:", otherMapping, " and replacing with new mapping:", mapping)
								
								otherMapping.conflictBlockedByOtherIndexCount = (otherMapping.conflictBlockedByOtherIndexCount or 0) + 1

								if not mapping.conflictBlockingOtherMappings then
									mapping.conflictBlockingOtherMappings = {}
								end
								mapping.conflictBlockingOtherMappings[otherMapping.index] = otherMapping
								table.remove(mappingsForMod, i)
							--else
								--mj:log("key conflict found but no disableOnConflict for existing key. existing:", otherMapping.groupKey, ".", otherMapping.mapKey, " adding:", mapping.groupKey, ".", mapping.mapKey)
							end
						end
					end 
				end
                
			end
		end
	end
	
	--[[if mapping.defaultKeyCode ~= mapping.keyCode then --modified keys should maybe get first priority within the group? This might cause issues though. Leaving here for future reference
        table.insert(mappingsForMod, 1, mapping.index)
	else
		table.insert(mappingsForMod, mapping.index)
	end]]

	
	table.insert(mappingsForMod, mapping.index)
end

local function removeMappingByKeyCode(mapping)
    local mappingsByMod = mappingsByInputKeyCodesAndMods[mapping.keyCode]
    if mappingsByMod then
		local modToUse = getModKey(mapping)
        local mappingsForMod = mappingsByMod[modToUse]
        if mappingsForMod then
            for i=#mappingsForMod,1,-1 do
                if mappingsForMod[i] == mapping.index then
                    table.remove(mappingsForMod, i)
                end
            end
        end
    end

	if mapping.conflictBlockingOtherMappings then
		for otherMappingIndex,otherMapping in pairs(mapping.conflictBlockingOtherMappings) do
			otherMapping.conflictBlockedByOtherIndexCount = otherMapping.conflictBlockedByOtherIndexCount - 1
			if otherMapping.conflictBlockedByOtherIndexCount == 0 then
				otherMapping.conflictBlockedByOtherIndexCount = nil
				setMappingByKeyCode(otherMapping)
			end
		end
		mapping.conflictBlockingOtherMappings = nil
	end
end


local function addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2, disableOnConflict)

	--mj:log("addMapping:",groupKey,".", mapKey, ":", defaultKeyCode)
	
	if defaultMod and defaultMod2 then
		if defaultMod2 < defaultMod then
			local tmp = defaultMod
			defaultMod = defaultMod2
			defaultMod2 = tmp
		end
	end

    local group = mappingGroups[groupKey]
    if not group then
        addGroup(groupKey)
        group = mappingGroups[groupKey]
    end

    indexCount = indexCount + 1
    local thisIndex = indexCount
    local mapping = {
		groupKey = groupKey,
		mapKey = mapKey,
        name = locale:get("key_" .. groupKey .. "_" .. mapKey),
        index = thisIndex,
        defaultKeyCode = defaultKeyCode,
        defaultMod = defaultMod,
        defaultMod2 = defaultMod2,
        keyCode = defaultKeyCode,
        mod = defaultMod,
        mod2 = defaultMod2,
		disableOnConflict = disableOnConflict,
    }


    group.mappingsByKey[mapKey] = mapping
    table.insert(group.orderedMappingKeys, mapKey)
    setMappingByKeyCode(mapping)
end


-- the goal here is to default to the left/main keyboard, but allow players to also restrict to the numpad/right. so a right input will trigger a left assigned key, but a left input will not trigger a right asisgned key
function keyMapping:getMappingsForInput(inputKeyCode, inputMod, inputMod2)
	--mj:log("keyMapping:getMappingsForInput:", inputKeyCode)
    local function getResults(inputKeyCodeToUse)
        local thisResult = nil
        local mappingsByMod = mappingsByInputKeyCodesAndMods[inputKeyCodeToUse]
        if mappingsByMod then
			local modToUse = getModKey({
				mod = inputMod,
				mod2 = inputMod2
			})
            thisResult = mappingsByMod[modToUse]
            if (not thisResult) and (inputMod ~= nil) then --ignore the modifier if there are no mappings bound with it
                thisResult = mappingsByMod[modifiers.none]
            end
        end
        return thisResult
    end
    
    local baseResult = getResults(inputKeyCode)
    local doubleResult = nil
    local doubleRemap = doubleMapping[inputKeyCode]
    if doubleRemap then
        doubleResult = getResults(doubleRemap)
    end

    local completeResult = baseResult
    if doubleResult then
        completeResult = completeResult or {}
        for i, doubleAddition in ipairs(doubleResult) do
            local found = false
            for j,existing in ipairs(completeResult) do
                if existing == doubleAddition then
                    found = true
                    break
                end
            end

            if not found then
                table.insert(completeResult, doubleAddition)
            end
        end
    end

	--mj:log("completeResult:", completeResult)
    return completeResult
end

function keyMapping:getMappingIndex(groupKey, mappingKey)
    return mappingGroups[groupKey].mappingsByKey[mappingKey].index
end

function keyMapping:getLocalizedString(groupKey, mappingKey)

    local mappingInfo = mappingGroups[groupKey].mappingsByKey[mappingKey]
	if not mappingInfo then
		mj:error("no mapping info for groupKey:", groupKey, " mappingKey:", mappingKey)
		return nil
	end
    local boundKeyCodeKey = keyMapping.keyCodeKeysByCode[mappingInfo.keyCode]
    local keyName = locale:getKeyName(boundKeyCodeKey)

	if not keyName then
		return nil
	end


	local function getModKeyText(mod)
		if mod and mod ~= keyMapping.modifiers.none then
			local modifierKeyCode = keyMapping.modifierKeyCodesByModifierCode[mod]
			if modifierKeyCode then
				local modifierKeyCodeKey = keyMapping.keyCodeKeysByCode[modifierKeyCode]
				return locale:getKeyName(modifierKeyCodeKey)
			end
		end
		return nil
	end
	
	local bindingText = keyName
	local mod1Text = getModKeyText(mappingInfo.mod)
	local mod2Text = getModKeyText(mappingInfo.mod2)

	if mod1Text then
		if mod2Text then
			bindingText = mod1Text .. "+" .. mod2Text .. "+".. keyName
		else
			bindingText = mod1Text .. "+" .. keyName
		end
	end

    return bindingText
end

function keyMapping:isModifierKey(keyCode)
    return modifierKeysByKeyCode[keyCode] ~= nil or (doubleMapping[keyCode] and modifierKeysByKeyCode[doubleMapping[keyCode]] ~= nil)
end

function keyMapping:setBinding(groupKey, mappingKey, mainKeyCode, modKeyCode, mod2KeyCode)
	mj:log("keyMapping:setBinding:", groupKey, " mappingKey:", mappingKey, " mainKeyCode:", mainKeyCode, " modKeyCode:", modKeyCode, " mod2KeyCode:", mod2KeyCode)

	if modKeyCode and mod2KeyCode then
		if mod2KeyCode < modKeyCode then
			local tmp = modKeyCode
			modKeyCode = mod2KeyCode
			mod2KeyCode = tmp
		end
	end
	
    local mapping = mappingGroups[groupKey].mappingsByKey[mappingKey]
    if mapping then
        removeMappingByKeyCode(mapping)
        mapping.modified = true
        mapping.keyCode = mainKeyCode

		local function getModKeyForCode(modKeyCodeIncoming)
			if modKeyCodeIncoming then
				local result = modifierKeysByKeyCode[modKeyCodeIncoming]
				if not result then
					if doubleMapping[modKeyCodeIncoming] then
						result = modifierKeysByKeyCode[doubleMapping[modKeyCodeIncoming]]
					end
				end
				return result
			end
			return nil
		end

		mapping.mod = getModKeyForCode(modKeyCode)
		mapping.mod2 = getModKeyForCode(mod2KeyCode)

		--mj:log("mapping:", mapping)

        local settingsKey = getSettingsKey(groupKey, mappingKey)
        clientGameSettings:changeSetting(settingsKey, {
            keyCode = mapping.keyCode,
            mod = mapping.mod,
            mod2 = mapping.mod2,
        })
        setMappingByKeyCode(mapping)
    end
end

function keyMapping:resetBinding(groupKey, mappingKey)
    local mapping = mappingGroups[groupKey].mappingsByKey[mappingKey]
    if mapping then
        removeMappingByKeyCode(mapping)
        mapping.modified = nil
        mapping.keyCode = mapping.defaultKeyCode
        mapping.mod = mapping.defaultMod
        local settingsKey = getSettingsKey(groupKey, mappingKey)
        clientGameSettings:changeSetting(settingsKey, nil)
        setMappingByKeyCode(mapping)
    end
end

function keyMapping:loadSettings()
    for groupKey, group in pairs(mappingGroups) do
        for mappingKey, mapping in pairs(group.mappingsByKey) do
            local settingsKey = getSettingsKey(groupKey, mappingKey)
            local clientSetting = clientGameSettings.values[settingsKey]
            if clientSetting then
                mj:log("found clientSetting:", clientSetting)
                removeMappingByKeyCode(mapping)
                mapping.keyCode = clientSetting.keyCode
                mapping.mod = clientSetting.mod
                mapping.modified = true
                setMappingByKeyCode(mapping)
            end
        end
    end
end

local function setConflictGroupsPair(groupA, groupB)
	local setA = conflictGroups[groupA]
	if not setA then
		setA = {}
		conflictGroups[groupA] = setA
	end
	setA[groupB] = true
	local setB = conflictGroups[groupB]
	if not setB then
		setB = {}
		conflictGroups[groupB] = setB
	end
	setB[groupA] = true

end

function keyMapping:mjInit()
    
    addGroup("menu")
    addGroup("game")
    addGroup("movement")
    addGroup("building")
    addGroup("textEntry")
    addGroup("multiSelect")
    addGroup("debug")
    addGroup("cinematicCamera")

	setConflictGroupsPair("movement", "game")
	setConflictGroupsPair("movement", "building")
	
    addMapping("menu", "up", keyCodes.up, nil)
    addMapping("menu", "down", keyCodes.down, nil)
    addMapping("menu", "left", keyCodes.left, nil)
    addMapping("menu", "right", keyCodes.right, nil)
    addMapping("menu", "select", keyCodes.e, nil)
    addMapping("menu", "back", keyCodes.escape, nil)
    addMapping("menu", "selectAlt", keyCodes.key_return, nil)
    
    addMapping("game", "escape", keyCodes.escape, nil)
    addMapping("game", "chat", keyCodes.t, nil)
    addMapping("game", "luaPrompt", keyCodes.backquote, nil)
    addMapping("game", "toggleMap", keyCodes.m, nil)
    addMapping("game", "confirm", keyCodes.e, nil)
    addMapping("game", "confirmSpecial", keyCodes.e, modifiers.ctrl)
	
    --addMapping("game", "menu", keyCodes.e, nil)
    addMapping("game", "buildMenu", keyCodes.q, nil)
    addMapping("game", "buildMenu2", keyCodes.f1, nil)
    addMapping("game", "tribeMenu", keyCodes.f2, nil)
    --addMapping("game", "routesMenu", keyCodes.f3, nil)
    addMapping("game", "settingsMenu", keyCodes.f3, nil)
	
    addMapping("game", "zoomToNotification", keyCodes.key_return, nil)

    addMapping("game", "pause", keyCodes.space, nil)
    addMapping("game", "speedFast", keyCodes.tab, nil)
    addMapping("game", "speedSlowMotion", keyCodes.key_9, modifiers.ctrl)
	
    addMapping("game", "radialMenuShortcut1", keyCodes.key_1, nil)
    addMapping("game", "radialMenuShortcut2", keyCodes.key_2, nil)
    addMapping("game", "radialMenuShortcut3", keyCodes.key_3, nil)
    addMapping("game", "radialMenuShortcut4", keyCodes.key_4, nil)
    addMapping("game", "radialMenuShortcut5", keyCodes.key_5, nil)
    addMapping("game", "radialMenuShortcut6", keyCodes.key_6, nil)
    addMapping("game", "radialMenuDeconstruct", keyCodes.r, nil)
    addMapping("game", "radialMenuClone", keyCodes.b, nil)
    addMapping("game", "radialMenuInvestigate", keyCodes.i, nil)
    addMapping("game", "radialMenuChopReplant", keyCodes.c, nil)
    addMapping("game", "prioritize", keyCodes.p, nil)
	
    addMapping("game", "radialMenuAutomateModifier", keyCodes.lalt, nil)
    addMapping("game", "moveCommandAddWaitOrderModifier", keyCodes.lctrl, nil)
	
    addMapping("game", "zoomModifier", keyCodes.lctrl, nil)
    addMapping("game", "multiselectModifier", keyCodes.lshift, nil)

    addMapping("game", "togglePointAndClick", keyCodes.tab, modifiers.ctrl)
    
    addMapping("movement", "forward", keyCodes.w, nil)
    addMapping("movement", "back", keyCodes.s, nil)
    addMapping("movement", "left", keyCodes.a, nil)
    addMapping("movement", "right", keyCodes.d, nil)
    addMapping("movement", "slow", keyCodes.lctrl, nil)
    addMapping("movement", "fast", keyCodes.lshift, nil)
    addMapping("movement", "forwardAlt", keyCodes.up, nil)
    addMapping("movement", "backAlt", keyCodes.down, nil)
    addMapping("movement", "leftAlt", keyCodes.left, nil)
    addMapping("movement", "rightAlt", keyCodes.right, nil)
    addMapping("movement", "zoomIn", keyCodes.z)
    addMapping("movement", "zoomOut", keyCodes.x)
    addMapping("movement", "rotateLeft", keyCodes.comma)
    addMapping("movement", "rotateRight", keyCodes.period)
    addMapping("movement", "rotateForward", keyCodes.quote)
    addMapping("movement", "rotateBack", keyCodes.slash)
    
    addMapping("building", "cancel", keyCodes.escape, nil)
    addMapping("building", "confirm", keyCodes.e, nil)
	
    addMapping("building", "zAxisModifier", keyCodes.lshift, nil)
    addMapping("building", "adjustmentModifier", keyCodes.lctrl, nil)
    addMapping("building", "noBuildOrderModifier", keyCodes.lalt, nil)
    addMapping("building", "rotateX", keyCodes.x, nil)
    addMapping("building", "rotateY", keyCodes.y, nil)
    addMapping("building", "rotateZ", keyCodes.z, nil)



    
    addMapping("textEntry", "backspace", keyCodes.backspace, nil)
    addMapping("textEntry", "delete", keyCodes.delete, nil)
    addMapping("textEntry", "send", keyCodes.key_return, nil)
    addMapping("textEntry", "newline", keyCodes.key_return, modifiers.shift)
    addMapping("textEntry", "prevCommand", keyCodes.up, nil)
    addMapping("textEntry", "nextCommand", keyCodes.down, nil)
    addMapping("textEntry", "cursorLeft", keyCodes.left, nil)
    addMapping("textEntry", "cursorRight", keyCodes.right, nil)
    
    addMapping("multiSelect", "subtractModifier", keyCodes.lshift, nil)
    
    addMapping("debug", "reload", keyCodes.r, modifiers.ctrl)
    addMapping("debug", "lockCamera", keyCodes.p, modifiers.ctrl)
    addMapping("debug", "setDebugObject", keyCodes.backquote, modifiers.ctrl)
    addMapping("debug", "measureDistance", keyCodes.m, modifiers.ctrl)
	
    addMapping("cinematicCamera", "startRecord1", keyCodes.key_1, modifiers.ctrl, modifiers.shift)
    addMapping("cinematicCamera", "startRecord2", keyCodes.key_2, modifiers.ctrl, modifiers.shift)
    addMapping("cinematicCamera", "startRecord3", keyCodes.key_3, modifiers.ctrl, modifiers.shift)
    addMapping("cinematicCamera", "startRecord4", keyCodes.key_4, modifiers.ctrl, modifiers.shift)
    addMapping("cinematicCamera", "startRecord5", keyCodes.key_5, modifiers.ctrl, modifiers.shift)
    addMapping("cinematicCamera", "insertKeyframe", keyCodes.i, nil)
    addMapping("cinematicCamera", "saveKeyframe", keyCodes.key_return, nil)
    addMapping("cinematicCamera", "removeKeyframe", keyCodes.delete, nil)
    addMapping("cinematicCamera", "nextKeyframe", keyCodes.rightbracket, nil)
    addMapping("cinematicCamera", "prevKeyframe", keyCodes.leftbracket, nil)
    addMapping("cinematicCamera", "increaseKeyframeDuration", keyCodes.plus, nil)
    addMapping("cinematicCamera", "decreaseKeyframeDuration", keyCodes.minus, nil)

	
    addMapping("cinematicCamera", "play1", keyCodes.key_1, modifiers.ctrl)
    addMapping("cinematicCamera", "play2", keyCodes.key_2, modifiers.ctrl)
    addMapping("cinematicCamera", "play3", keyCodes.key_3, modifiers.ctrl)
    addMapping("cinematicCamera", "play4", keyCodes.key_4, modifiers.ctrl)
    addMapping("cinematicCamera", "play5", keyCodes.key_5, modifiers.ctrl)
end

keyMapping.orderedGroupKeys = orderedGroupKeys
keyMapping.mappingGroups = mappingGroups
keyMapping.keyCodeKeysByCode = keyCodeKeysByCode
keyMapping.modifiers = modifiers
keyMapping.modifierKeyCodesByModifierCode = modifierKeyCodesByModifierCode
keyMapping.modifierKeysByKeyCode = modifierKeysByKeyCode

--mod support

keyMapping.keyCodes = keyCodes
keyMapping.doubleMapping = doubleMapping
keyMapping.addGroup = addGroup
keyMapping.addMapping = addMapping

return keyMapping