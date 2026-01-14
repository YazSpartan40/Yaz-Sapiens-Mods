
local rng = mjrequire "common/randomNumberGenerator"

local nameLists = {}

local maleNames = {
    "Ale",
    "Akesi",
    "Anpa",
    "Ilo",
    "Kasi",
    "Ken",
    "Kipisi",
    "Kule",
    "Laso",
    "Linja",
    "Lipu",
    "Loje",
    "Lon",
    "Lukin",
    "Mije",
    "Moku",
    "Musi",
    "Nasin",
    "Nena",
    "Nimi",
    "Ona",
    "Pana",
    "Pata",
    "Pona",
    "Sike",
    "Sona",
    "Telo",
    "Walo",
    "Waso",
    "Wan",
}
    
local femaleNames = {
    "Alasa",
    "Awen",
    "Insa",
    "Jo",
    "Kala",
    "Kalama",
    "Kama",
    "Kiwen",
    "Kon",
    "Lawa",
    "Lete",
    "Lili",
    "Luka",
    "Ma",
    "Meli",
    "Mun",
    "Namako",
    "Oko",
    "Olin",
    "Pali",
    "Pilin",
    "Poka",
    "Seli",
    "Sewi",
    "Suli",
    "Suno",
    "Suwi",
    "Wawa",
}

local prefixVowelsMale = {
    "a",
    "o",
}

local prefixVowelsFemale = {
    "e",
    "u",
}

local primarySyllables = {
    "la",
    "le",
    "we",
    "jo",
    "ka",
    "ki",
    "ko",
    "ku",
    "la",
    "lu",
    "lo",
    "li",
    "ma",
    "me",
    "mu",
    "mi",
    "mo",
    "na",
    "ne",
    "ni",
    "pa",
    "pi",
    "po",
    "se",
    "si",
    "su",
    "te",
    "wa",
}

local postfixSyllablesMale = {
    "len",
    "ken",
    "ja",
    "je",
    "lo",
    "si",
    "so",
    "pa",
    "le",
    "na",
}

local postfixSyllablesFemale = {
    "la",
    "li",
    "ka",
    "ko",
    "sa",
    "wi",
    "lin",
    "wa",
    "ma",
    "te",
}


function nameLists:generateName(baseUniqueID, randomSeed, isFemale)
    --rng:integerForUniqueID(baseUniqueID, 35 + randomSeed, #nameList) + 1

    local plainType = rng:integerForUniqueID(baseUniqueID, 274 + randomSeed, 10) == 1
    if plainType then
        local nameListToUse = maleNames
        if isFemale then
            nameListToUse = femaleNames
        end
        local randomIndex = rng:integerForUniqueID(baseUniqueID, 7661 + randomSeed, #nameListToUse) + 1
        return nameListToUse[randomIndex]
    else

        local prefixVowel = false
        if rng:integerForUniqueID(baseUniqueID, 4192 + randomSeed, 10) == 1 then
            prefixVowel = true
        end
        

        local primaryCount = 1
        if rng:boolForUniqueID(baseUniqueID, 125 + randomSeed) then
            primaryCount = 2
        end

        local name = ""

        if prefixVowel then
            local prefixVowels = prefixVowelsMale
            if isFemale then
                prefixVowels = prefixVowelsFemale
            end
            local vowelIndex = rng:integerForUniqueID(baseUniqueID, 3998 + randomSeed, #prefixVowels) + 1
            name = name .. prefixVowels[vowelIndex]
        end

        for i = 1, primaryCount do
            local syllableIndex = rng:integerForUniqueID(baseUniqueID, 7328 + randomSeed + i, #primarySyllables) + 1
            name = name .. primarySyllables[syllableIndex]
        end

        local postfixList = postfixSyllablesMale
        if isFemale then
            postfixList = postfixSyllablesFemale
        end

        local syllableIndex = rng:integerForUniqueID(baseUniqueID, 3901 + randomSeed, #postfixList) + 1
        name = name .. postfixList[syllableIndex]
        return mj:capitalize(name)
    end
end


function nameLists:generateTribeName(baseUniqueID, randomSeed)
    
    local prefixVowels = prefixVowelsMale
    if rng:boolForUniqueID(baseUniqueID, 125 + randomSeed) then
        prefixVowels = prefixVowelsFemale
    end
    local vowelIndex = rng:integerForUniqueID(baseUniqueID, 3998 + randomSeed, #prefixVowels) + 1
    local name = prefixVowels[vowelIndex]

    local primaryCount = 2 + rng:integerForUniqueID(baseUniqueID, 93568 + randomSeed, 2)

    for i = 1, primaryCount do
        local syllableIndex = rng:integerForUniqueID(baseUniqueID, 7328 + randomSeed + i, #primarySyllables) + 1
        name = name .. primarySyllables[syllableIndex]
    end

    local postfixList = postfixSyllablesMale
    if rng:boolForUniqueID(baseUniqueID, 3653 + randomSeed) then
        postfixList = postfixSyllablesFemale
    end

    local syllableIndex = rng:integerForUniqueID(baseUniqueID, 3901 + randomSeed, #postfixList) + 1
    name = name .. postfixList[syllableIndex]
    return mj:capitalize(name)

end

return nameLists