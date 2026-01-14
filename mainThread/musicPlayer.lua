local audio = mjrequire "mainThread/audio"
local timer = mjrequire "common/timer"

--local controller = nil

local musicPlayer = {}

local mainMenuTrack = "Sapiens_Main_Theme.ogg"

local musicTracks = {
    "Flowing_Like_the_River.ogg",
    "Early_Morning_Rise.ogg",
    "In_the_Company_of_Trees.ogg",
    "Ripples_on_the_Lake.ogg",
    "Welcoming_the_Dusk.ogg",
    "Like_Wind_Through_Tall_Grass.ogg",
    "Settling_on_River_Banks.ogg",
    "One_Stone_at_a_Time.ogg",
    "Around_the_Campfire.ogg",
    "Foundations.ogg",
}

local snowTrack = "Blessings_from_the_Sky.ogg"
local snowTrackPlayedThisCycle = false
local snowing = false

math.randomseed(os.time())

for i = #musicTracks, 2, -1 do
    local j = math.random(i)
    musicTracks[i], musicTracks[j] = musicTracks[j], musicTracks[i]
end

local currentTrack = nil
local playDelayTimerID = nil
local playingWorldTracks = false
local playNextGameTrackAfterDelay = nil

local timeBetweenTracks = 120.0


local gameTrackPlaybackIndex = 1

local function playNextGameTrack()
    --mj:log("playNextGameTrack")
    if not currentTrack then
        if snowing and not snowTrackPlayedThisCycle then
            snowTrackPlayedThisCycle = true
            currentTrack = snowTrack
        else
            currentTrack = musicTracks[gameTrackPlaybackIndex]
            gameTrackPlaybackIndex = gameTrackPlaybackIndex + 1
            if gameTrackPlaybackIndex > #musicTracks then
                gameTrackPlaybackIndex = 1
                snowTrackPlayedThisCycle = false
            end
        end
        playDelayTimerID = nil
        audio:playSong("audio/songs/" .. currentTrack, 0.4, function()
            currentTrack = nil
            playNextGameTrackAfterDelay(timeBetweenTracks)
        end)
    end
end


playNextGameTrackAfterDelay = function(delay)
   -- local gameState = controller:getGameState()
   -- if gameState == GameStateLoadedRunning then
        if not playDelayTimerID then
            --mj:log("adding playNextGameTrack after delay:", delay)
            playDelayTimerID = timer:addCallbackTimer(delay, function(timerID)
                if timerID == playDelayTimerID then
                    playNextGameTrack()
                end
            end)
        end
   -- end
end

function musicPlayer:fadeOutGameMusic() --called when sapiens start playing instruments
    if playingWorldTracks then
        local playingSong = audio:getQueuedOrPlayingSong()
        if playingSong and playingSong ~= mainMenuTrack then
            audio:fadeOutAnyCurrentSong()
        end
        currentTrack = nil
        if playDelayTimerID then
            timer:removeTimer(playDelayTimerID)
            playDelayTimerID = nil
        end
        playNextGameTrackAfterDelay(30.0)
    end
end

function musicPlayer:setSnowing(snowing_)
    snowing = snowing_
end

function musicPlayer:init(controller_, newGameState)
    --mj:log("musicPlayer:init:", newGameState)
    --controller = controller_

    if newGameState == GameStateMainMenu then
        --[[currentTrack = nil
        if not playingWorldTracks then
            playingWorldTracks = true
            playNextGameTrack()
        end]]

        currentTrack = mainMenuTrack
        audio:playSong("audio/songs/" .. mainMenuTrack, nil, function()
            --mj:log("main menu finished")
            currentTrack = nil
            if not playingWorldTracks then
                playingWorldTracks = true
                playNextGameTrack()
            end
        end)
    else
        
        local playingSong = audio:getQueuedOrPlayingSong()
        --mj:log("in world loaded running. playingSong:", playingSong)
        if playingSong and playingSong ~= mainMenuTrack then
            gameTrackPlaybackIndex = 1 

            if "audio/songs/" .. snowTrack == playingSong then
                currentTrack = snowTrack
            else
                for i, trackName in ipairs(musicTracks) do
                    if "audio/songs/" .. trackName == playingSong then
                        gameTrackPlaybackIndex = i + 1
                        currentTrack = trackName
                        --mj:log("found song in playlist")
                        break
                    end
                end
                if gameTrackPlaybackIndex > #musicTracks then
                    gameTrackPlaybackIndex = 1
                end
            end

            if currentTrack then
                playingWorldTracks = true
            
                audio:playSong(playingSong, 0.4, function() --we need to assign the callback. Because the song is already playing, it won't be interrupted
                    currentTrack = nil
                    playNextGameTrackAfterDelay(timeBetweenTracks)
                end)
            end
            
        end
    end
    
    
end

function musicPlayer:worldLoaded()
    --mj:log("musicPlayer:worldLoaded:", playingWorldTracks)
    if not playingWorldTracks then
        playingWorldTracks = true
        currentTrack = nil
        --mj:log("play next world track in 10s from worldLoaded")
        playNextGameTrackAfterDelay(10.0)
    end
end


return musicPlayer