local animationGroups = {}

animationGroups.loadFileNames = {
    "maleSapien",
    "femaleSapien",
    "girlSapien",
    "boySapien",
    "chicken",
    "alpaca",
    "mammoth",
    "catfish",
    "coelacanth",
    "flagellipinna",
    "polypterus",
    "redfish",
    "tropicalfish",
    "swordfish",
}

animationGroups.groups =  {}

function animationGroups:mjInit()
    for i,key in ipairs(animationGroups.loadFileNames) do
        local animationInfo = mjrequire("common/animations/" .. key)
        animationInfo.index = i
        animationInfo.key = key
        animationGroups.groups[i] = animationInfo
        animationGroups.groups[key] = animationInfo
    end
end


function animationGroups:initMainThread()
    local sapienCommon = mjrequire("common/animations/sapienCommon")
    sapienCommon:initMainThread()
    for i,animationInfo in ipairs(animationGroups.groups) do
        animationInfo:initMainThread()
    end
end

return animationGroups