
local mapModes = mj:enum { --these have ended up being hard coded in the engine too. You can modify the heights a little, but shouldn't add or remove modes without engine modifications.
    "global",
    "continental",
    "national",
    "regional",
    "localized",
    "close",
    "closest"
}

return mapModes