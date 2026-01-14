local ffi = require("ffi")
--local ffiC = ffi.C

local spCommon = ffi.load('SPCommon')

local mjm = {}

--local ffiCast = ffi.cast

ffi.cdef([[

typedef struct SPVec2 {
    double x;
    double y;
} SPVec2;

typedef struct SPVec3 {
    double x;
    double y;
    double z;
} SPVec3;

typedef struct SPVec4 {
    double x;
    double y;
    double z;
    double w;
} SPVec4;

typedef struct SPMat3 {
	double m0;
	double m1;
	double m2;
	double m3;
	double m4;
	double m5;
	double m6;
	double m7;
	double m8;
} SPMat3;

typedef struct SPMat4 {
	double m0;
	double m1;
	double m2;
	double m3;
	double m4;
	double m5;
	double m6;
	double m7;
	double m8;
	double m9;
	double m10;
	double m11;
	double m12;
	double m13;
	double m14;
	double m15;
} SPMat4;

void spMat3RotatePtr(SPMat3* m, double angle, SPVec3* axisP, SPMat3* result);
void spMat3LookAtInversePtr(SPVec3* lookP, SPVec3* upP, SPMat3* result);
void spMat3SlerpPtr(SPMat3* a, SPMat3* b, double fraction, SPMat3* result);

void spMat4InversePtr(SPMat4* m, SPMat4* result);

]])

local vec2 = nil
local vec3 = nil
local vec4 = nil
local mat3 = nil
local mat4 = nil

local SPVec2MetaTable = {
    __add = function(a, b) return vec2(a.x + b.x, a.y + b.y) end,
    __sub = function(a, b) return vec2(a.x - b.x, a.y - b.y) end,
    __mul = function(a, b) return vec2(a.x * b,a.y * b) end,
    __div = function(a, b) return vec2(a.x / b,a.y / b) end,
    __unm = function(a) return vec2(-a.x,-a.y) end,
    __tostring = function(a) return "vec2("..a.x .. ", " .. a.y .. ")" end,
}

vec2 = ffi.metatype("SPVec2", SPVec2MetaTable)
mjm.vec2 = vec2
local p2vec2p = ffi.typeof("SPVec2*")
mjm.p2vec2 = function(obj)
    local result = p2vec2p(obj)
    return vec2(result.x,result.y)
end

local SPVec3MetaTable = {
    __add = function(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end,
    __sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end,
    __mul = function(a, b) return vec3(a.x * b,a.y * b, a.z * b) end,
    __div = function(a, b) return vec3(a.x / b,a.y / b, a.z / b) end,
    __unm = function(a) return vec3(-a.x,-a.y,-a.z) end,
    __tostring = function(a) return "vec3("..a.x .. ", " .. a.y .. ", " .. a.z .. ")" end,
}

vec3 = ffi.metatype("SPVec3",SPVec3MetaTable)
mjm.vec3 = vec3
local p2vec3p = ffi.typeof("SPVec3*")
mjm.p2vec3 = function(obj)
    local result = p2vec3p(obj)
    return vec3(result.x,result.y,result.z)
end

local SPVec4MetaTable = {
    __add = function(a, b) return vec4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w) end,
    __sub = function(a, b) return vec4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w) end,
    __mul = function(a, b) return vec4(a.x * b,a.y * b, a.z * b, a.w * b) end,
    __div = function(a, b) return vec4(a.x / b,a.y / b, a.z / b, a.w / b) end,
    __unm = function(a) return vec4(-a.x,-a.y,-a.z,-a.w) end,
    __tostring = function(a) return "vec4("..a.x .. ", " .. a.y .. ", " .. a.z .. ", " .. a.w .. ")" end,
}

vec4 = ffi.metatype("SPVec4",SPVec4MetaTable)
mjm.vec4 = vec4
local p2vec4p = ffi.typeof("SPVec4*")
mjm.p2vec4 = function(obj)
    local result = p2vec4p(obj)
    return vec4(result.x,result.y,result.z,result.w)
end

local SPMat3MetaTable = {
    __mul = function(a, b) 
        return mat3(
        a.m0 * b.m0 + a.m3 * b.m1 + a.m6 * b.m2,
        a.m1 * b.m0 + a.m4 * b.m1 + a.m7 * b.m2,
        a.m2 * b.m0 + a.m5 * b.m1 + a.m8 * b.m2,
        a.m0 * b.m3 + a.m3 * b.m4 + a.m6 * b.m5,
        a.m1 * b.m3 + a.m4 * b.m4 + a.m7 * b.m5,
        a.m2 * b.m3 + a.m5 * b.m4 + a.m8 * b.m5,
        a.m0 * b.m6 + a.m3 * b.m7 + a.m6 * b.m8,
        a.m1 * b.m6 + a.m4 * b.m7 + a.m7 * b.m8,
        a.m2 * b.m6 + a.m5 * b.m7 + a.m8 * b.m8
    )
    end,
    __tostring = function(a) return "mat3("..a.m0 .. ", " .. a.m1 .. ", " .. a.m2 .. ", "..a.m3 .. ", " .. a.m4 .. ", " .. a.m5 .. ", "..a.m6 .. ", " .. a.m7 .. ", " .. a.m8 ..")" end,
}


mat3 = ffi.metatype("SPMat3",SPMat3MetaTable)
mjm.mat3 = mat3
local p2mat3p = ffi.typeof("SPMat3*")
mjm.p2mat3 = function(obj)
    local result = p2mat3p(obj)
    return mat3(
        result.m0,result.m1,result.m2,
        result.m3,result.m4,result.m5,
        result.m6,result.m7,result.m8
    )
end

mjm.mat3Identity = mat3(1,0,0,0,1,0,0,0,1)


local SPMat4MetaTable = {
    __mul = function(a, b) 
        return mat4(
        a.m0 * b.m0 + a.m4 * b.m1 + a.m8 * b.m2,
        a.m1 * b.m0 + a.m5 * b.m1 + a.m9 * b.m2,
        a.m2 * b.m0 + a.m6 * b.m1 + a.m10 * b.m2,
        a.m3 * b.m0 + a.m7 * b.m1 + a.m11 * b.m2,

        a.m0 * b.m4 + a.m4 * b.m5 + a.m8 * b.m6,
        a.m1 * b.m4 + a.m5 * b.m5 + a.m9 * b.m6,
        a.m2 * b.m4 + a.m6 * b.m5 + a.m10 * b.m6,
        a.m3 * b.m4 + a.m7 * b.m5 + a.m11 * b.m6,

        a.m0 * b.m8 + a.m4 * b.m9 + a.m8 * b.m10,
        a.m1 * b.m8 + a.m5 * b.m9 + a.m9 * b.m10,
        a.m2 * b.m8 + a.m6 * b.m9 + a.m10 * b.m10,
        a.m3 * b.m8 + a.m7 * b.m9 + a.m11 * b.m10,

        a.m0 * b.m12 + a.m4 * b.m13 + a.m8 * b.m14,
        a.m1 * b.m12 + a.m5 * b.m13 + a.m9 * b.m14,
        a.m2 * b.m12 + a.m6 * b.m13 + a.m10 * b.m14,
        a.m3 * b.m12 + a.m7 * b.m13 + a.m11 * b.m14
    )
    end,
    __tostring = function(a) return "mat4("..a.m0 .. ", " .. a.m1 .. ", " .. a.m2 .. ", "..a.m3 .. ", " .. a.m4 .. ", " .. a.m5 .. ", "..a.m6 .. ", " .. a.m7 .. ", " .. a.m8 .. ", " .. a.m9 .. ", " .. a.m10 .. ", " .. a.m11 .. ", " .. a.m12 .. ", " .. a.m13 .. ", " .. a.m14 .. ", " .. a.m15 ..")" end,
}

mat4 = ffi.metatype("SPMat4",SPMat4MetaTable)
mjm.mat4 = mat4
local p2mat4p = ffi.typeof("SPMat4*")
mjm.p2mat4 = function(obj)
    local result = p2mat4p(obj)
    return mat4(
        result.m0,result.m1,result.m2,result.m3,
        result.m4,result.m5,result.m6,result.m7,
        result.m8,result.m9,result.m10,result.m11,
        result.m12,result.m13,result.m14,result.m15
    )
end

mjm.mat4Identity = mat4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)

function mjm.min(x, y)
    return (x < y and x or y)
end

function mjm.max(x, y)
    return (x > y and x or y)
end

function mjm.clamp(x, minVal, maxVal)
	return (x < minVal and minVal or (x > maxVal and maxVal or x))
end

function mjm.mix(x, y, a)
    return x + (y - x) * a
end

local clamp = mjm.clamp
function mjm.smoothStep(edge0, edge1, x)
	local tmp = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return tmp * tmp * (3.0 - 2.0 * tmp)
end

function mjm.toVec3(v)
    return vec3(v.x,v.y,v.z)
end

function mjm.normalize(v)
    return v / math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function mjm.normalize2D(v)
    return v / math.sqrt(v.x * v.x + v.y * v.y)
end

function mjm.dot(a,b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

function mjm.cross(a,b)
    return vec3(
        a.y * b.z - b.y * a.z,
        a.z * b.x - b.z * a.x,
        a.x * b.y - b.x * a.y
    )
end

function mjm.length(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function mjm.length2(v)
    return v.x * v.x + v.y * v.y + v.z * v.z
end

function mjm.length2D(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

function mjm.length2D2(v)
    return v.x * v.x + v.y * v.y
end

function mjm.vec3xMat3(v,m)
    return vec3(
		m.m0 * v.x + m.m1 * v.y + m.m2 * v.z,
		m.m3 * v.x + m.m4 * v.y + m.m5 * v.z,
		m.m6 * v.x + m.m7 * v.y + m.m8 * v.z
    )
end

function mjm.mat3GetRow(m, rowIndex)
    if rowIndex == 0 then
        return vec3(m.m0,m.m1,m.m2)
    elseif rowIndex == 1 then
        return vec3(m.m3,m.m4,m.m5)
    end
    return vec3(m.m6,m.m7,m.m8)
end

function mjm.mat3Rotate(mat, angle, axis)
    local result = mat3()
    spCommon.spMat3RotatePtr(mat, angle, axis, result)
    return result
end

function mjm.mat3LookAtInverse(look,up) --must be normalized
    local result = mat3()
    spCommon.spMat3LookAtInversePtr(look,up, result)
    return result
end

function mjm.mat3Inverse(m)
	local oneOverDeterminant = 1.0 / (
		  m.m0 * (m.m4 * m.m8 - m.m7 * m.m5)
		- m.m3 * (m.m1 * m.m8 - m.m7 * m.m2)
        + m.m6 * (m.m1 * m.m5 - m.m4 * m.m2))
        
	return mat3( 
        (m.m4 * m.m8 - m.m7 * m.m5) * oneOverDeterminant,
        -(m.m1 * m.m8 - m.m7 * m.m2) * oneOverDeterminant,
        (m.m1 * m.m5 - m.m4 * m.m2) * oneOverDeterminant,

       -(m.m3 * m.m8 - m.m6 * m.m5) * oneOverDeterminant,
       (m.m0 * m.m8 - m.m6 * m.m2) * oneOverDeterminant,
       -(m.m0 * m.m5 - m.m3 * m.m2) * oneOverDeterminant,

        (m.m3 * m.m7 - m.m6 * m.m4) * oneOverDeterminant,
       -(m.m0 * m.m7 - m.m6 * m.m1) * oneOverDeterminant,
        (m.m0 * m.m4 - m.m3 * m.m1) * oneOverDeterminant
   )
end
            
function mjm.mat4Inverse(m)
    local result = mat4()
    spCommon.spMat4InversePtr(m, result)
    return result
end

function mjm.createUpAlignedRotationMatrix(normalizedPos, lookDirection)
    local right = mjm.normalize(mjm.cross(normalizedPos, -lookDirection))
    local rotZ = mjm.normalize(mjm.cross(normalizedPos, -right))
    
    return mat3(
        -right.x, -right.y, -right.z,
        normalizedPos.x, normalizedPos.y, normalizedPos.z,
        -rotZ.x, -rotZ.y, -rotZ.z
    )
end

function mjm.mat4Ortho(left, right, bottom, top, zNear, zFar)
    return mat4(
        2.0 / (right - left), 0, 0, 0, 
        0, 2.0 / (top - bottom), 0, 0, 
        0, 0, -1.0 / (zFar - zNear), 0, 
        - (right + left) / (right - left),-  (top + bottom) / (top - bottom), -zNear / (zFar - zNear), 1
    )
end

function mjm.mat4LookAt(eye, center, up)
    local f = mjm.normalize(center - eye)
    local s = mjm.normalize(mjm.cross(f,up))
    local u = mjm.cross(s,f)

    return mat4(
        s.x, u.x, -f.x, 0, 
        s.y, u.y, -f.y, 0, 
        s.z, u.z, -f.z, 0, 
        -mjm.dot(s, eye), -mjm.dot(u, eye), mjm.dot(f, eye), 1
    )
end

function mjm.vec3xMat4(v,m)
    return vec3(
		m.m0 *  v.x + m.m1 * v.y + m.m2 * v.z + m.m3,
		m.m4 *  v.x + m.m5 * v.y + m.m6 * v.z + m.m7,
		m.m8 *  v.x + m.m9 * v.y + m.m10 * v.z + m.m11
    )
end

function mjm.vec4xMat4(v,m)
    return vec4(
		m.m0 *  v.x + m.m1 * v.y + m.m2 * v.z + m.m3 * v.w,
		m.m4 *  v.x + m.m5 * v.y + m.m6 * v.z + m.m7 * v.w,
		m.m8 *  v.x + m.m9 * v.y + m.m10 * v.z + m.m11 * v.w,
		m.m12 *  v.x + m.m13 * v.y + m.m14 * v.z + m.m15 * v.w
    )
end

function mjm.mat4xVec4(m,v)
    return vec4(
		m.m0 *  v.x + m.m4 * v.y + m.m8 * v.z + m.m12 * v.w,
		m.m1 *  v.x + m.m5 * v.y + m.m9 * v.z + m.m13 * v.w,
		m.m2 *  v.x + m.m6 * v.y + m.m10 * v.z + m.m14 * v.w,
		m.m3 *  v.x + m.m7 * v.y + m.m11 * v.z + m.m15 * v.w
    )
end

function mjm.pointIsLeftOfLine(p1, a, b)
	local faceNormal = vec3(
        a.y * b.z - b.y * a.z,
        a.z * b.x - b.z * a.x,
        a.x * b.y - b.x * a.y
    )
    local dp = faceNormal.x * p1.x + faceNormal.y * p1.y + faceNormal.z * p1.z
	return (dp >= 0)
end

local defaultEpsilon = 0.000000000000001

function mjm.approxEqual(a,b)
    return math.abs(a - b) < defaultEpsilon
end

function mjm.approxEqualEpsilon(a,b, epsilon)
    return math.abs(a - b) < epsilon
end

function mjm.vec3ApproxEqual(a,b)
    return math.abs(a.x - b.x) < defaultEpsilon and math.abs(a.y - b.y) < defaultEpsilon and math.abs(a.z - b.z) < defaultEpsilon
end

function mjm.mat3Slerp(a,b,f)
    local result = mat3()
    spCommon.spMat3SlerpPtr(a, b, f, result)
    return result
end

function mjm.rayPlaneIntersectionDistance(rayOrigin, rayDir, planeOrigin, planeNormal)
    local d = rayDir.x * planeNormal.x + rayDir.y * planeNormal.y + rayDir.z * planeNormal.z
    if d < -defaultEpsilon or d > defaultEpsilon then
        local originLocal = planeOrigin - rayOrigin
        local distance =  (originLocal.x * planeNormal.x + originLocal.y * planeNormal.y + originLocal.z * planeNormal.z) / d
        if distance > 0.0 then
            return distance
        end
    end
    return nil
end

function mjm.raySphereIntersectionDistance(rayOrigin, rayDir, sphereCenter, sphereRadiusSquared)
    local diff = sphereCenter - rayOrigin
    local t0 = diff.x * rayDir.x + diff.y * rayDir.y + diff.z * rayDir.z
    local dSquared = diff.x * diff.x + diff.y * diff.y + diff.z * diff.z - t0 * t0
    if dSquared > sphereRadiusSquared then
        return nil
    end
    local t1 = math.sqrt(sphereRadiusSquared - dSquared)
    local intersctionDistance = nil
    if t0 > t1 + defaultEpsilon then
        intersctionDistance = t0 - t1
    else
        intersctionDistance = t0 + t1
    end

    if intersctionDistance > defaultEpsilon then
        return intersctionDistance
    end

    return nil
end

function mjm.rayCircleIntersectionDistance(rayOrigin, rayDir, circleCenter, circleRadiusSquared)
    local diff = circleCenter - rayOrigin
    local t0 = diff.x * rayDir.x + diff.y * rayDir.y
    local dSquared = diff.x * diff.x + diff.y * diff.y - t0 * t0
    if dSquared > circleRadiusSquared then
        return nil
    end
    local t1 = math.sqrt(circleRadiusSquared - dSquared)
    local intersctionDistance = nil
    if t0 > t1 + defaultEpsilon then
        intersctionDistance = t0 - t1
    else
        intersctionDistance = t0 + t1
    end

    if intersctionDistance > defaultEpsilon then
        return intersctionDistance
    end

    return nil
end


function mjm.randomPointWithinTriangle(a, b, c, r1, r2)
    local ba = b - a
	local ca = c - a
	local p = a + ba * r1 + ca * r2
	if mjm.pointIsLeftOfLine(p, b, c) then
		local bcMidPoint = b + (c-b) * 0.5
		return bcMidPoint - (p - bcMidPoint)
    end
	return p
end

function mjm.closestPointOnLine2D(a, b, p)
    local lineVec = b - a
    local lineLength2 = lineVec.x * lineVec.x + lineVec.y * lineVec.y
    local pVec = p - a
    local dp = pVec.x * lineVec.x + pVec.y * lineVec.y

    local distanceAlongLine = mjm.clamp(dp / lineLength2, 0.0, 1.0)
    return a + lineVec * distanceAlongLine
end


function mjm.baryFractions(pointNormal, vN0, vN1, vN2)
    local fractions = vec3(0.0,0.0,0.0)
    
    local e1 = vN1 - vN0
    local p0 = pointNormal - vN0
    local a0 = mjm.cross(e1, p0)
    fractions.z = mjm.length(a0)
    
    local e4 = vN2 - vN1
    local p1 = pointNormal - vN1
    local a1 = mjm.cross(e4, p1)
    fractions.x = mjm.length(a1)
    
    local e5 = vN0 - vN2
    local p2 = pointNormal - vN2
    local a2 = mjm.cross(e5, p2)
    fractions.y = mjm.length(a2)
    
    fractions = fractions / (fractions.x + fractions.y + fractions.z);
    return {fractions.x, fractions.y, fractions.z}
end


function mjm.reverseLinearInterpolate(x, a, b)
    if(b == a) then
        return 0.0
    end
    
    return (x - a) / (b - a)
end

function mjm.cardinalSplineInterpolate(aa, a, b, bb, fraction, factor)
    factor = factor or 0.5
    
    local fSquared = fraction * fraction;
    local fCubed = fSquared * fraction;
    
    local h1 =  2.0 * fCubed - 3.0 * fSquared + 1.0
    local h2 = -2.0 * fCubed + 3.0 * fSquared
    local h3 =        fCubed - 2.0 * fSquared + fraction
    local h4 =        fCubed - fSquared
    
    local t1 = (b - aa) * factor
    local t2 = (bb - a) * factor
    
    return a*h1 + b*h2 + t1*h3 + t2*h4
end

-- my testing has shown the FFI variant to be just a touch slower than lua for mat3 inverse, it's right on the edge so I've left it exposed in the C API
--[[
function mjm.mat3Inverse(m)
    local result = mat3()
    spCommon.spMat3InversePtr(m, result)
    return result
end]] 

return mjm
