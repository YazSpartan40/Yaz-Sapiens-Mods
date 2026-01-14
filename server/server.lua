
local gameConstants = mjrequire "common/gameConstants"

local server = {
    connectedClientsSet = {}
}

local serverWorld = nil
local bridge = nil

server.namesByClientIDs = {}

function server:setServerWorld(serverWorld_)
    serverWorld = serverWorld_
end

-- called by engine

function server:setBridge(bridge_)
    --mj:log("server:setBridge")
    bridge = bridge_

    server:registerNetFunction("sendChatMessage", function(clientID, userData)
        if userData.text and type (userData.text) == "string" and string.len(userData.text) <= 200 then
            local outgoingInfo = {}
            outgoingInfo.text = userData.text
            outgoingInfo.clientID = clientID
            outgoingInfo.clientName = server.namesByClientIDs[clientID]

            if gameConstants.logChat then
                mj:log("chat: " .. (outgoingInfo.clientName or "no_name") .. ": " .. outgoingInfo.text)
            end

            server:callClientFunctionForAllClients("chatMessageReceived", outgoingInfo)
        end
        
    end)
end

function server:broadcast(message)
    local outgoingInfo = {
        text = message,
        clientName = "server",
        isServerBroadcast = true,
    }
    server:callClientFunctionForAllClients("chatMessageReceived", outgoingInfo)
end

function server:clientConnected(clientID, clientName)
    server.namesByClientIDs[clientID] = clientName
    server.connectedClientsSet[clientID] = true
    serverWorld:clientConnected(clientID)
    
	for otherClientID,v in pairs(server.connectedClientsSet) do
        server:callClientFunction("clientStateChange", otherClientID, {
            type = "connected",
            clientID = clientID,
            clientName = clientName,
            playerCount = serverWorld.connectedClientCount,
            isLocalPlayer = (otherClientID == clientID),
        })
	end
end

function server:clientDisconnected(clientID)
    server.connectedClientsSet[clientID] = nil
    mj:log("client disconnected: " .. mj:tostring(clientID) .. " : " .. mj:tostring(serverWorld:getPlayerNameForClient(clientID) or "no name"))

	for otherClientID,v in pairs(server.connectedClientsSet) do
        server:callClientFunction("clientStateChange", otherClientID, {
            type = "disconnected",
            clientID = clientID,
            clientName = serverWorld:getPlayerNameForClient(clientID),
            playerCount = serverWorld.connectedClientCount - 1,
            isLocalPlayer = (otherClientID == clientID),
        })
	end

    serverWorld:clientDisconnected(clientID)
end

function server:clientHibernated(clientID)
	for otherClientID,v in pairs(server.connectedClientsSet) do
        server:callClientFunction("clientStateChange", otherClientID, {
            type = "hibernated",
            clientID = clientID,
            clientName = serverWorld:getPlayerNameForClient(clientID),
            playerCount = serverWorld.connectedClientCount - 1,
            isLocalPlayer = (otherClientID == clientID),
        })
	end
end

function server:terrainFinishedLoadingForClient(clientID)
    if serverWorld then
        serverWorld:terrainFinishedLoadingForClient(clientID)
    end
end

function server:loadClientState(clientID, playerID, playerName)
    if serverWorld then
        return serverWorld:loadClientState(clientID, playerID, playerName)
    end
end

function server:getInitialWorldDataForClientConnection(clientID)
    if serverWorld then
        return serverWorld:getInitialWorldDataForClientConnection(clientID)
    end
end

function server:callClientFunction(functionName, clientID, userData, callback)
    if server.connectedClientsSet[clientID] then
        bridge:callClientFunction(functionName, clientID, userData, callback)
    end
end

function server:callClientFunctionForAllClients(functionName, userData, callback)
    bridge:callClientFunctionForAllClients(functionName, userData, callback)
end

function server:getSpawnPos()
    return bridge:getSpawnPos()
end

function server:updateClientData(clientID, playerPos, playerDirection, mapMode)
    bridge:updateClientData(clientID, playerPos, playerDirection, mapMode or 0)
end

function server:registerNetFunction(name, func)
    bridge:registerNetFunction(name, func)
end

function server:getSessionInfoForConnectingClient(clientID) --called by engine to get list of sessions(tribes) that the client can connect to. It calls this multiple times, incrementing the session id to create a new client id, until this function returns nil
    return serverWorld:getSessionInfoForConnectingClient(clientID)
end

local functionsByCommands = {
    stats = function(fullInput, argsString)
        local statsArray = serverWorld:getDebugStatsArray()
        for i,info in ipairs(statsArray) do
            mj:log(info.title .. ":" .. info.value)
        end
    end,
    help = function(fullInput, argsString)
        mj:log("\n\
Sapiens Dedicated Server Version:" .. bridge:getVersionString() .. "\n\
There are a few built-in commands, but anything else is run through the lua interpreter. The server and serverWorld modules are made available as locals. So for example you can send a chat message with:\n\
server:broadcast(\"your message here\")\n\
built-in commands:\
help                - this help\
stats               - print server stats\
stop | quit | exit  - exit the server")
    end,
}

function server:runLuaString(input) --passed through from the command line input when run as a dedicated server
    local initialCommand, argsString = input:match("(%w+)(.*)")
    if initialCommand then
        local builtInFunction = functionsByCommands[input]
        if builtInFunction then
            builtInFunction(input, argsString)
            return
        end
    end


    local fullString = 
[[
local server = mjrequire "server/server"
local serverWorld = mjrequire "server/serverWorld"
local serverGOM = mjrequire "server/serverGOM"
]] .. input
    local status, error = pcall(loadstring(fullString))
    if status == false then
        mj:log("ERROR: " .. mj:tostring(error))
    end
end

return server