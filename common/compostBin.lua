
local mjm = mjrequire "common/mjm"
local clamp = mjm.clamp

local gameConstants = mjrequire "common/gameConstants"
local resource = mjrequire "common/resource"
local locale = mjrequire "common/locale"

local gameObject = nil
local dayLength = nil
local worldTimeFunc = nil

local compostBin = {}

function compostBin:getCompostUIInfoText(object)

    local function getNextCompostText()
        local inventory = object.sharedState.inventory
        if inventory then
            if inventory.objects then
                local containedSum = 0
                local nextOutputAddTime = nil
    
                for i,objectInfo in ipairs(inventory.objects) do
                    local compostValue = resource.types[gameObject.types[objectInfo.objectTypeIndex].resourceTypeIndex].compostValue
                    containedSum = containedSum + compostValue
                    if containedSum >= gameConstants.compostBinValueSumRequiredForOutput then
                        nextOutputAddTime = objectInfo.addTime
                        break
                    end
                end
    
                if nextOutputAddTime then
                    local worldTime = worldTimeFunc()
            
                    local durationSeconds = nextOutputAddTime + gameConstants.compostTimeUntilCompostGeneratedDays * dayLength - worldTime
                    local durationHours = (durationSeconds / dayLength * 24)
            
                    if durationHours < 1.0 then
                        return locale:get("misc_compostNextInLessThanAnHour")
                    end
            
                    local durationInt = clamp(math.floor(durationHours + 0.5), 2, 24)
            
                    return locale:get("misc_compostNextInXHours", {hours = durationInt} )
            
                end
            end
        end
        return locale:get("misc_compostNotEnoughMaterialStored")
    end
    
    local function getPrevCompostText()
        local previousOutputTime = object.sharedState.previousOutputTime
        if previousOutputTime then
            local worldTime = worldTimeFunc()
            local durationSeconds = worldTime - previousOutputTime
            local durationHours = (durationSeconds / dayLength * 24)
    
            if durationHours < 1.0 then
                return locale:get("misc_compostPreviousWasLessThanAnHour")
            end
    
            local durationInt = clamp(math.floor(durationHours + 0.5), 2, 24)
    
            return locale:get("misc_compostPreviousWasXHours", {hours = durationInt} )
        end
    end

    local prevCompostText = getPrevCompostText()
    local nextCompostText = getNextCompostText()

    if prevCompostText then
        return prevCompostText .. ". " .. nextCompostText
    end

    return nextCompostText
end


function compostBin:load(gameObject_)
    gameObject = gameObject_
end

function compostBin:setDayLength(dayLength_, worldTimeFunc_) --only called from main thread
    dayLength = dayLength_
    worldTimeFunc = worldTimeFunc_
end

return compostBin