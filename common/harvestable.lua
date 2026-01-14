
local typeMaps = mjrequire "common/typeMaps"

local harvestable = {}

harvestable.typeIndexMap = typeMaps.types.harvestable


    

function harvestable:addHarvestable(key, objectTypesArray, singleOutputCount, completionGroupCount)--, outputObjectUpOffsetDistanceOrNil)
    local additionInfo = {
        key = key,
        objectTypesArray = {},
        completionIndex = singleOutputCount + 1,
        --outputObjectUpOffsetDistance = outputObjectUpOffsetDistanceOrNil,
    }

    local outputArrayIndex = 1
    for i = 1,singleOutputCount+completionGroupCount do
        table.insert(additionInfo.objectTypesArray, objectTypesArray[outputArrayIndex])
        outputArrayIndex = outputArrayIndex + 1
        if outputArrayIndex > #objectTypesArray then
            outputArrayIndex = 1
        end
    end

    typeMaps:insert("harvestable", harvestable.types, additionInfo)
end

function harvestable:load(gameObject)


    harvestable.types = typeMaps:createMap("harvestable", {
        {
            key = "mammoth", --could be added using addHarvestable, but left here for reference
            objectTypesArray = {
                gameObject.typeIndexMap.mammothMeat,
                gameObject.typeIndexMap.mammothMeatTBone,
                gameObject.typeIndexMap.mammothWoolskin,
                gameObject.typeIndexMap.mammothMeat,
                gameObject.typeIndexMap.mammothMeatTBone,
                gameObject.typeIndexMap.mammothWoolskin,
                gameObject.typeIndexMap.mammothMeat,
                gameObject.typeIndexMap.mammothMeatTBone,
                gameObject.typeIndexMap.mammothWoolskin,
                gameObject.typeIndexMap.mammothMeat,
                gameObject.typeIndexMap.mammothMeatTBone,
                gameObject.typeIndexMap.mammothWoolskin,
                
                gameObject.typeIndexMap.mammothMeat,
                gameObject.typeIndexMap.mammothMeatTBone,
                gameObject.typeIndexMap.mammothWoolskin,
                gameObject.typeIndexMap.mammothMeat,
                gameObject.typeIndexMap.mammothMeatTBone,
                gameObject.typeIndexMap.mammothWoolskin,
            },
            completionIndex = 13,
            --outputObjectUpOffsetDistance = mj:mToP(3.0),
        },
    })

end

return harvestable