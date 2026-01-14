
local typeMaps = mjrequire "common/typeMaps"

local craftAreaGroup = {}

craftAreaGroup.types = typeMaps:createMap("craftAreaGroup", {
    {
        key = "campfire",
    },
    {
        key = "kiln",
    },
    {
        key = "standard",
    },
})

return craftAreaGroup