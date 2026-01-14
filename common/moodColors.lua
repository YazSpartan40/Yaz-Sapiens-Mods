local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4

local moodColors = {
    severeNegative = vec4(1.0,0.0,0.0,1.0),
    --strongNegative = vec4(1.0,0.5,0.0,1.0),
    moderateNegative = vec4(1.0,0.5,0.0,1.0),
    mildNegative = vec4(1.0,0.75,0.0,1.0),
    --even = vec4(1.0,1.0,0.0,1.0),
    mildPositive = vec4(0.75,1.0,0.0,1.0),
    moderatePositive = vec4(0.5,1.0,0.0,1.0),
    --strongPositive = vec4(0.5,1.0,0.0,1.0),
    severePositive = vec4(0.0,1.0,0.0,1.0),
}

return moodColors