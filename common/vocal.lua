
local typeMaps = mjrequire "common/typeMaps"
local rng = mjrequire "common/randomNumberGenerator"

local vocal = {}

local vocalsDirRelativePath = "audio/sounds/vocals"

vocal.voices = typeMaps:createMap("vocal_voices", {
    {
        key = "dave",
    },
    {
        key = "ethan",
    },
    {
        key = "emma",
    },
})

local randomOffset = rng:integerForSeed(2345, 200)

vocal.phrases = typeMaps:createMap("vocal_phrases", {
    {
        key = "toki",
    },
    {
        key = "toki_loud",
    },
    {
        key = "howAreYou",
    },
    {
        key = "imOK",
    },
    {
        key = "doYouUnderstand",
    },
    {
        key = "dontUnderstand",
    },
    {
        key = "understand",
    },
    {
        key = "andHowAreYou",
    },
    {
        key = "enjoyTheFood",
    },
    {
        key = "excuseMe",
    },
    {
        key = "fireLit",
    },
    {
        key = "goodDay",
    },
    {
        key = "goodDay_loud",
    },
    {
        key = "goodEvening",
    },
    {
        key = "goodNight",
    },
    {
        key = "pona",
    },
    {
        key = "sorry",
    },
    {
        key = "thanks",
    },
    {
        key = "beQuiet",
    },
    {
        key = "chuckle",
    },
    {
        key = "cough",
    },
    {
        key = "damn",
    },
    {
        key = "go",
    },
    {
        key = "goodbye",
    },
    {
        key = "haveFun",
    },
    {
        key = "iDontLikeThat",
    },
    {
        key = "iDontHaveFood",
    },
    {
        key = "iDontKnowWhy",
    },
    {
        key = "iJustWork",
    },
    {
        key = "iMissYou",
    },
    {
        key = "imLazy",
    },
    {
        key = "imOK",
    },
    {
        key = "iWantToEatChicken",
    },
    {
        key = "leaveMeAlone",
    },
    {
        key = "letsGo",
    },
    {
        key = "please",
    },
    {
        key = "thatsFunny",
    },
    {
        key = "yawn",
    },
})

function vocal:getPath(voiceTypeIndex, phraseTypeIndex)
    randomOffset = randomOffset + 1

    local voiceType = vocal.voices[voiceTypeIndex]
    local tracks = voiceType.tracks[phraseTypeIndex]

    if tracks then
        local randomValueToUse =  randomOffset % #tracks
        local trackName = tracks[randomValueToUse + 1]
        --mj:log("playing vocal track:", trackName)
        return trackName
    end

    --[[local tracks = vocal.phrases[phraseTypeIndex].tracks
    local randomValueToUse =  randomOffset % #tracks
    local trackName = vocal.voices[voiceTypeIndex].path .. tracks[randomValueToUse + 1]
    ]]

    --mj:warn("no track found for:", vocal.phrases[phraseTypeIndex].key, " using voice:", voiceType.key)

    return nil
end


function vocal:mjInit()

    
    vocal.validVoices = typeMaps:createValidTypesArray("vocal_voices", vocal.voices)
    

    for i,voiceType in ipairs(vocal.validVoices) do
        voiceType.tracks = {}
        local relativeVoicePath = vocalsDirRelativePath .. "/" .. voiceType.key
        local fullPath = fileUtils.getResourcePath(relativeVoicePath)
        local fileList = fileUtils.getDirectoryContents(fullPath)
        for j,fileName in ipairs(fileList) do
            local phraseKey = string.match(fileName, '([^%d]*)%d+%.wav')
            local phraseType = vocal.phrases[phraseKey]
            if phraseType then
                local phraseTypeIndex = phraseType.index
                if not voiceType.tracks[phraseTypeIndex] then
                    voiceType.tracks[phraseTypeIndex] = {}
                end
                local filePath = relativeVoicePath .. "/" .. fileName
                table.insert(voiceType.tracks[phraseTypeIndex], filePath)
            end
        end

        --mj:log("voiceType.tracks:", voiceType.tracks)
    end

end

return vocal