local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local dot = mjm.dot
local normalize = mjm.normalize
local approxEqual = mjm.approxEqual

local model = mjrequire "common/model"
local material = mjrequire "common/material"
--local biome = mjrequire "common/biome"
local destination = mjrequire "common/destination"
--local locale = mjrequire "common/locale"
local rng = mjrequire "common/randomNumberGenerator"
--local mapModes = mjrequire "common/mapModes"

local eventManager = mjrequire "mainThread/eventManager"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local worldUIViewManager = mjrequire "mainThread/worldUIViewManager"
local tribeSelectionUI = mjrequire "mainThread/ui/tribeSelectionUI"

local tribeSelectionMarkersUI = {}

local localPlayer = nil
local world = nil

local disabled = false

local markerInfosByID = {}


local failMarkers = nil

local size = vec2(2.0,2.0)
local closeScale = 3.0
local selectedScale = 1.5
local maxTribeDistance = mj:mToP(300000.0)
local minTribeDistance = mj:mToP(40.0)
local scaleStartDistance = mj:mToP(50.0)

local clickableDistance = mj:mToP(10000.0)

local hoverMarker = nil
local clickedMarker = nil
local hidden = false

local playerPosNormal = nil

local function updateDrawOrder(markerInfo)
    if markerInfo.renderingSelectedState then
        markerInfo.worldView.drawOrder = 1000000
    else
        if (not markerInfo.availableForSelection) then
            markerInfo.worldView.drawOrder = -1000000 + rng:integerForUniqueID(markerInfo.uniqueID, 19444, 500)
        else
            markerInfo.worldView.drawOrder = -markerInfo.populationCount * 1000 + rng:integerForUniqueID(markerInfo.uniqueID, 19444, 500)
        end
    end
end

local function updateIconModel(markerInfo)
    local iconMaterial = nil
    if markerInfo.availableForSelection then
        iconMaterial = material.types[string.format("biomeDifficulty_%d", markerInfo.biomeDifficulty)].index
    else
        if markerInfo.detailInfo.ownedByLocalPlayer then
            iconMaterial = material.types.ui_selected.index
        elseif markerInfo.detailInfo.clientID then
            iconMaterial = material.types.ui_otherPlayer.index
        else
            iconMaterial = material.types.ui_bronze_lighter.index
        end
    end

    if markerInfo.isClose and markerInfo.availableForSelection then
        local disabledStarMaterial = material.types.ui_background_inset.index
        local starMaterials = {}
        for i=1,5 do
            if i <= markerInfo.biomeDifficulty then
                starMaterials[i] = iconMaterial
            else
                starMaterials[i] = disabledStarMaterial
            end
        end
    
        markerInfo.icon:setModel(model:modelIndexForName("icon_tribeSelection"), {
            [material.types.ui_standard.index] = iconMaterial,
            [material.types.star1.index] = starMaterials[1],
            [material.types.star2.index] = starMaterials[2],
            [material.types.star3.index] = starMaterials[3],
            [material.types.star4.index] = starMaterials[4],
            [material.types.star5.index] = starMaterials[5],
    
        })
    else
        markerInfo.icon:setModel(model:modelIndexForName("icon_tribeWithOutline"),{
            [material.types.ui_standard.index] = iconMaterial
        })
    end
end

local sapienCountTextYOffset = 0.03
--local difficultyTextYOffset = 0.65
local sapienCountTextScale = 0.01


local function updatePopulationText(markerInfo)
    if markerInfo.isClose and markerInfo.availableForSelection then
        if not markerInfo.populationTextView then
            local populationTextView = TextView.new(markerInfo.backgroundView)
            markerInfo.populationTextView = populationTextView
            populationTextView.color = vec4(0.0,0.0,0.0,1.0)
            populationTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            populationTextView.baseOffset = vec3(0,markerInfo.currentSize * sapienCountTextYOffset,0)
            populationTextView.font = Font(uiCommon.titleFontName, 32)
            populationTextView.fontGeometryScale = markerInfo.currentSize * sapienCountTextScale
        end

        markerInfo.populationTextView.text = string.format("%d", markerInfo.populationCount)
    else
        if markerInfo.populationTextView then
            markerInfo.backgroundView:removeSubview(markerInfo.populationTextView)
            markerInfo.populationTextView = nil
        end
    end
end

local playerNameTextYOffset = -1.0
local playerNameTextScale = 0.02

local function updatePlayerNameText(markerInfo)
    if markerInfo.detailInfo.playerName then
        if not markerInfo.playerNameTextView then
            local playerNameTextView = ModelTextView.new(markerInfo.backgroundView)
            markerInfo.playerNameTextView = playerNameTextView
            --playerNameTextView.color = vec4(1.0,1.0,1.0,1.0)
            playerNameTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
            playerNameTextView.baseOffset = vec3(0,markerInfo.currentSize * playerNameTextYOffset,0)
            playerNameTextView.font = Font(uiCommon.fontName, 32)
            playerNameTextView.fontGeometryScale = markerInfo.currentSize * playerNameTextScale
        end

        markerInfo.playerNameTextView:setText(markerInfo.detailInfo.playerName, material.types.ui_standard.index)
    else
        if markerInfo.playerNameTextView then
            markerInfo.backgroundView:removeSubview(markerInfo.playerNameTextView)
            markerInfo.playerNameTextView = nil
        end
    end
end


local function updateHoverDecorations(markerInfo)
    
    if ((hoverMarker and hoverMarker == markerInfo) or (clickedMarker and clickedMarker == markerInfo)) then
        if not markerInfo.renderingSelectedState then
            markerInfo.renderingSelectedState = true

            if markerInfo.isClose and markerInfo.availableForSelection then
                markerInfo.goalSize = markerInfo.baseSize * closeScale * selectedScale
            else
                markerInfo.goalSize = markerInfo.baseSize * selectedScale
            end
            updateDrawOrder(markerInfo)
        end
    else
        if markerInfo.renderingSelectedState then
            markerInfo.renderingSelectedState = nil
            
            updateDrawOrder(markerInfo)

            if markerInfo.isClose and markerInfo.availableForSelection then
                markerInfo.goalSize = markerInfo.baseSize * closeScale
            else
                markerInfo.goalSize = markerInfo.baseSize
            end
        end
    end
end

local function setHoverMarker(hoverMarker_)
    if hoverMarker ~= hoverMarker_ then
        local prevHoverMarker = hoverMarker
        hoverMarker = hoverMarker_
        
        if prevHoverMarker then
            updateHoverDecorations(prevHoverMarker)
        end
        if hoverMarker then
            updateHoverDecorations(hoverMarker)
        end
    end
end

local function setClickedMarker(clickedMarker_)
    if clickedMarker ~= clickedMarker_ then
        local prevClickedMarker = clickedMarker

        clickedMarker = clickedMarker_

        if prevClickedMarker then
            updateHoverDecorations(prevClickedMarker)
        end
        if clickedMarker then
            updateHoverDecorations(clickedMarker)
        end
    end
end

function tribeSelectionMarkersUI:clearSelection()
    setClickedMarker(nil)
end


function tribeSelectionMarkersUI:setHidden(newHidden)
    --mj:log("tribeSelectionMarkersUI:setHidden:", newHidden)
    if not disabled then
        if newHidden ~= hidden then
            hidden = newHidden
            --mj:log("tribeSelectionMarkersUI:setHidden b:", newHidden)
            for id,viewInfo in pairs(markerInfosByID) do
                viewInfo.view.hidden = newHidden
            end
        end
    end
end

--[[function tribeSelectionMarkersUI:update()
    if not (disabled or hidden) then
        local newPlayerPosNormal = normalize(localPlayer:getPos())
        if dot(newPlayerPosNormal, playerPosNormal) < 0.99 then
            playerPosNormal = newPlayerPosNormal

            for uniqueID,viewInfo in pairs(markerInfosByID) do
                local depthTestEnabled = dot(viewInfo.posNormal, playerPosNormal) < 0.0
                if depthTestEnabled ~= viewInfo.depthTestEnabled then
                    viewInfo.depthTestEnabled = depthTestEnabled
                    viewInfo.icon:setDepthTestEnabled(depthTestEnabled)
                end
            end
        end
    end
end]]

local function addFailMarker(failPos)
    local worldView = worldUIViewManager:addView(failPos, worldUIViewManager.groups.tribeSelectionMarker, {
        startScalingDistance = scaleStartDistance, 
        offsets = {{worldOffset = vec3(0,mj:mToP(100.0),0)}}, 
        minDistance = minTribeDistance, 
        maxDistance = nil, 
        renderXRay = true,
    })
    local viewID = worldView.uniqueID
    local view = worldView.view
    view.size = size
    view.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    
    local icon = ModelView.new(view)
    icon:setModel(model:modelIndexForName("icon_failedTribeWithOutline"),{
        [material.types.ui_standard.index] = material.types.ui_red.index
    })
    icon.masksEvents = false
    local failHalfSize = 0.7
    icon.scale3D = vec3(failHalfSize,failHalfSize,failHalfSize)

    failMarkers[viewID] = {}
end

local function clickMarker(uniqueID)
    local newClickedMarker = markerInfosByID[uniqueID]
    if clickedMarker ~= newClickedMarker then
        --mj:log("clickedMarker:", clickedMarker, " markerInfosByID[uniqueID]:", markerInfosByID[uniqueID], " world:hasSelectedTribeID():", world:hasSelectedTribeID())

        if not world:hasSelectedTribeID() then
            setClickedMarker(newClickedMarker)
            tribeSelectionUI:showTribe(newClickedMarker.detailInfo)
        end
    end
    
    if not world:hasSelectedTribeID() then
        localPlayer:zoomToTribeMarker(newClickedMarker.pos)
    end
end

local function addMarker(uniqueID, pos, detailInfo)
    if not markerInfosByID[uniqueID] then
        local populationCount = (detailInfo.population or detailInfo.spawnSapienCount) or 10
        local populationCountFraction = mjm.clamp((populationCount - 1) / 12, 0, 1.0)
        --mj:log("count:", sdetailInfo.population, " populationCountFraction:", populationCountFraction)
        local populationScale = 0.5 + 1.0 * populationCountFraction

        local maxDistance = maxTribeDistance
        local useHorizonMaxDistance = nil
        if detailInfo.clientID then
            maxDistance = nil
            useHorizonMaxDistance = true
            populationScale = 1.5
        end

        local worldView = worldUIViewManager:addView(pos, worldUIViewManager.groups.tribeSelectionMarker, {
            startScalingDistance = scaleStartDistance, 
            offsets = {{worldOffset = vec3(0,mj:mToP(20.0),0)}}, 
            minDistance = minTribeDistance, 
            maxDistance = maxDistance, 
            useHorizonMaxDistance = useHorizonMaxDistance,
            --renderXRay = true,
        })
        local viewID = worldView.uniqueID
        local view = worldView.view
        view.size = size * populationScale
        local baseSize = size.x * populationScale * 0.5
        view.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)

        local backgroundView = View.new(view)
        --[[backgroundView:setModel(model:modelIndexForName("ui_order"),{
            [material.types.ui_background.index] = material.types.ui_background_black.index,
        })]]
        backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        --backgroundView:setCircleHitRadius(baseSize)
        --backgroundView.masksEvents = true
        --backgroundView.alpha = 0.67
        --backgroundView:setUsesModelHitTest(true)

        --[[local backgroundModelView = ModelView.new(backgroundView)
        backgroundModelView.masksEvents = false
        backgroundModelView:setModel(model:modelIndexForName("ui_order"),{
            default = material.types.ui_background_black.index,
        })
        backgroundModelView:setDepthTestEnabled(false)]]
        
        
       -- local icon = ModelImageView.new(backgroundView)
       -- icon:setTextures("img/icons/tribe.png", "img/icons/tribe_normal.png")
        --icon.size = size * 0.7
    
        local icon = ModelView.new(backgroundView)
        local posNormal = normalize(pos)
        --local depthTestEnabled = dot(posNormal, playerPosNormal) < 0.0
        icon:setDepthTestEnabled(false)
        --icon.masksEvents = false
        icon.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)

        local markerInfo = {
            worldView = worldView,
            uniqueID = uniqueID,
            detailInfo = detailInfo,
            pos = pos,
            posNormal = posNormal,
           -- depthTestEnabled = depthTestEnabled,
            viewID = viewID,
            view = view,
            backgroundView = backgroundView,
            --backgroundModelView = backgroundModelView,
            icon = icon,
            hover = false,
            currentSize = baseSize * 0.8,
            goalSize = baseSize * closeScale,
            baseSize = baseSize,
            differenceVelocity = 0.0,
            populationCount = populationCount,
            backgroundAlpha = 0.0,
            isClose = true,
            availableForSelection = false
        }

        if not detailInfo.clientID then
            if (not detailInfo.loadState) or detailInfo.loadState == destination.loadStates.seed then
                markerInfo.biomeDifficulty = detailInfo.biomeDifficulty
                markerInfo.availableForSelection = true
            end
        end

        markerInfosByID[uniqueID] = markerInfo

        updateIconModel(markerInfo)
        updateDrawOrder(markerInfo)
        updatePopulationText(markerInfo)
        updatePlayerNameText(markerInfo)
        
        
        backgroundView.update = function(dt)
            local info = markerInfosByID[uniqueID]

            local goalBackgroundAlpha = 0.0
            if info.isClose then
                goalBackgroundAlpha = 1.0
            end

            if (not approxEqual(goalBackgroundAlpha, info.backgroundAlpha)) then
                info.backgroundAlpha = info.backgroundAlpha + (goalBackgroundAlpha - info.backgroundAlpha) * math.min(dt * 10.0, 1.0)
                --backgroundModelView.alpha = info.backgroundAlpha
            end

            if (not approxEqual(info.goalSize, info.currentSize)) or (not approxEqual(info.differenceVelocity, 0.0)) then
                local difference = info.goalSize - info.currentSize
                local clampedDT = mjm.clamp(dt * 40.0, 0.0, 1.0)
                info.differenceVelocity = info.differenceVelocity * math.max(1.0 - dt * 20.0, 0.0) + (difference * clampedDT)
                info.currentSize = info.currentSize + info.differenceVelocity * dt * 12.0

                --local scaleToUse = info.currentSize
                --info.backgroundModelView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
                --info.backgroundModelView.size = vec2(info.currentSize, info.currentSize) * 2.0
               -- info.backgroundModelView.baseOffset = vec3(0.0,-0.3 * info.currentSize,0.0)

                info.backgroundView.size = vec2(info.currentSize, info.currentSize) * 2.0
                --info.backgroundView:setCircleHitRadius(info.currentSize * 0.9)
                --info.backgroundView.baseOffset = vec3(0.0,-0.3 * info.currentSize,0.0)

                local logoHalfSize = info.currentSize * 0.6
                info.icon.scale3D = vec3(logoHalfSize,logoHalfSize,logoHalfSize)
                info.icon.size = vec2(logoHalfSize,logoHalfSize) * 2.0


                icon:setUsesModelHitTest(true)

                --markerInfo.isClose

                --backgroundModelView.alpha = mjm.mix(0.8, 1.0, mjm.clamp((info.currentSize - info.baseSize) / (selectedSize - info.baseSize), 0.0, 1.0))
                

                if info.populationTextView then
                    info.populationTextView.fontGeometryScale = info.currentSize * sapienCountTextScale
                    info.populationTextView.baseOffset = vec3(0,info.currentSize * sapienCountTextYOffset,0)
                end

                if info.playerNameTextView then
                    info.playerNameTextView.fontGeometryScale = info.currentSize * playerNameTextScale
                    info.playerNameTextView.baseOffset = vec3(0,info.currentSize * playerNameTextYOffset,0)
                end
                --[[if info.difficultyTextView then
                    info.difficultyTextView.fontGeometryScale = info.currentSize * sapienCountTextScale
                    info.difficultyTextView.baseOffset = vec3(0,info.currentSize * difficultyTextYOffset,0)
                end]]
            end
        end
        
        icon.hoverStart = function()
            --if markerInfosByID[uniqueID].isClose then
                setHoverMarker(markerInfosByID[uniqueID])
            --end
        end
        icon.hoverEnd = function()
            if (hoverMarker and hoverMarker.uniqueID == uniqueID) then
                setHoverMarker(nil)
            end
        end
        
        icon.click = function()
            --if markerInfosByID[uniqueID].isClose then
                clickMarker(uniqueID)
            --end
        end


        worldUIViewManager:addDistanceCallback(viewID, clickableDistance, function(newIsClose)
            local info = markerInfosByID[uniqueID]
            if info then
                if info.isClose ~= newIsClose then
                    info.isClose = newIsClose
                    
                    if newIsClose then
                        --backgroundView.masksEvents = true
                        if info.availableForSelection then
                            info.goalSize = info.baseSize * closeScale
                        else
                            info.goalSize = info.baseSize
                        end
                    else
                        --backgroundView.masksEvents = false
                        info.goalSize = info.baseSize
                        if (hoverMarker and hoverMarker.uniqueID == uniqueID) then
                            setHoverMarker(nil)
                        end
                    end

                    updateHoverDecorations(info)
                    updateIconModel(info)
                    updatePopulationText(info)
                    updatePlayerNameText(info)
                end
            end
        end)
    end
end

local function removeMarker(uniqueID)
    if markerInfosByID[uniqueID] then
        worldUIViewManager:removeView(markerInfosByID[uniqueID].viewID)
        markerInfosByID[uniqueID] = nil
    end
end

function tribeSelectionMarkersUI:updateDestination(tribeInfo)
    if disabled then 
        return 
    end
    local tribeID = tribeInfo.destinationID
    if markerInfosByID[tribeID] then -- this should be infrequent (when another player picks a tribe on-screen), and we don't mind an obvious snap, so let's just throw it all away and start again
        removeMarker(tribeID)
    end
    
    addMarker(tribeID, tribeInfo.pos, tribeInfo)
end


function tribeSelectionMarkersUI:addDestination(tribeInfo)
    if disabled then 
        return 
    end
    tribeSelectionMarkersUI:updateDestination(tribeInfo)
end

function tribeSelectionMarkersUI:removeDestination(tribeInfo)
    if disabled then 
        return 
    end
    removeMarker(tribeInfo.destinationID)
end

function tribeSelectionMarkersUI:init(world_, localPlayer_)
    world = world_
    localPlayer = localPlayer_
    playerPosNormal = normalize(localPlayer:getPos())
    
    eventManager:addControllerCallback(eventManager.controllerSetIndexInGame, true, "confirm", function(isDown)
        if hidden then 
            return 
        end
        if isDown and hoverMarker then
            clickMarker(hoverMarker.uniqueID)
        end
    end)
    tribeSelectionMarkersUI.initialized = true
end

function tribeSelectionMarkersUI:reset(localPlayer_)
    localPlayer = localPlayer_
    playerPosNormal = normalize(localPlayer:getPos())
    for uniqueID,viewInfo in pairs(markerInfosByID) do
        removeMarker(uniqueID)
    end

    if failMarkers then
        for viewID, info in pairs(failMarkers) do
            worldUIViewManager:removeView(viewID)
        end
    end
    failMarkers = nil
end

function tribeSelectionMarkersUI:setFailPositions(failPositions)
    if failMarkers then
        for viewID, info in pairs(failMarkers) do
            worldUIViewManager:removeView(viewID)
        end
    end
    failMarkers = nil
    if failPositions and failPositions[1] then
        failMarkers = {}
        for i, failPos in ipairs(failPositions) do
            addFailMarker(failPos)
        end
    end
end

function tribeSelectionMarkersUI:isHoveringOverActiveMarker()
    return hoverMarker and clickedMarker and hoverMarker.uniqueID == clickedMarker.uniqueID
end

function tribeSelectionMarkersUI:disable()
    disabled = true
    for uniqueID,viewInfo in pairs(markerInfosByID) do
        removeMarker(uniqueID)
    end
    if failMarkers then
        for viewID, info in pairs(failMarkers) do
            worldUIViewManager:removeView(viewID)
        end
    end
    failMarkers = nil
end

return tribeSelectionMarkersUI