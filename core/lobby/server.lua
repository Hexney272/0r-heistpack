--[[
    LobbyService - Modern Server-Side Lobby Management

    @author 0resmon
    @version 2.0.0
]]

local lib = lib

--[[ Dependencies ]]

local Framework = require "modules.framework.init"

--[[ Type Definitions ]]

---@class LobbyMember
---@field source number Player server ID
---@field level number Player level
---@field name string Player character name
---@field illegalNickname string Player illegal nickname
---@field photo number Profile photo ID
---@field share number Share percentage (0-100)
---@field score number Mission score

---@class LobbyData
---@field id string Unique lobby ID
---@field members LobbyMember[] List of lobby members
---@field owner number? Owner source (leader)
---@field activeScenario table? Current active scenario

---@class SelfRemovedPlayer
---@field lobbyId string Lobby they were removed from
---@field score number Their score when removed
---@field timestamp number Unix timestamp of removal

---@class LobbyService
---@field private _lobbies table<string, LobbyData>
---@field private _selfRemovedPlayers table<string, SelfRemovedPlayer>
---@field private _lastLobbyIndex string
local LobbyServerClass = {}
LobbyServerClass.__index = LobbyServerClass

--[[ Constants ]]

local MAX_LOBBY_MEMBERS = 16
local SELF_REMOVE_TIMEOUT = 300 -- 5 minutes
local CLEANUP_INTERVAL = 60000  -- 1 minute
local DEFAULT_SHARE = 100
local DEFAULT_SCORE = 0
local DEFAULT_PHOTO = 1

--[[ Private Helper Functions ]]

---Increment string number (e.g., "099" -> "100")
---@param str string
---@return string
local function incrementStringNumber(str)
    local carry = 1
    local result = ""

    for i = #str, 1, -1 do
        local digit = tonumber(str:sub(i, i))
        local newDigit = digit + carry

        if newDigit >= 10 then
            newDigit = 0
            carry = 1
        else
            carry = 0
        end

        result = tostring(newDigit) .. result
    end

    if carry == 1 then
        result = "1" .. result
    end

    return result
end

---Calculate equal share for all members
---@param memberCount number
---@return number share
local function calculateEqualShare(memberCount)
    if memberCount == 0 then return 0 end
    return math.floor((100 / memberCount) * 10) / 10
end

---Create member data from source
---@param source number
---@param score number?
---@return LobbyMember? member
local function createMemberFromSource(source, score)
    local profile = ProfileServer:getBySource(source)
    if not profile then
        profile = ProfileServer:create(source)
    end

    if not profile then
        return nil
    end

    return {
        source = source,
        level = profile.level,
        name = Framework.getPlayerCharacterName(source),
        illegalNickname = profile.illegalNickname,
        photo = profile.photo or DEFAULT_PHOTO,
        share = DEFAULT_SHARE,
        score = score or DEFAULT_SCORE,
    }
end

--[[ Constructor ]]

---Create new LobbyService instance
---@return LobbyService
function LobbyServerClass.new()
    local self = setmetatable({}, LobbyServerClass)

    self._lobbies = {}
    self._selfRemovedPlayers = {}
    self._lastLobbyIndex = "0"

    -- Start cleanup thread
    self:_startCleanupThread()

    return self
end

--[[ Cleanup Management ]]

---Start automatic cleanup thread
---@private
function LobbyServerClass:_startCleanupThread()
    CreateThread(function()
        while true do
            Citizen.Wait(CLEANUP_INTERVAL)
            self:_cleanupExpiredPlayers()
            self:_cleanupEmptyLobbies()
        end
    end)
end

---Clean up expired self-removed players
---@private
function LobbyServerClass:_cleanupExpiredPlayers()
    local currentTime = os.time()

    for playerCid, removeData in pairs(self._selfRemovedPlayers) do
        if currentTime - removeData.timestamp >= SELF_REMOVE_TIMEOUT then
            self._selfRemovedPlayers[playerCid] = nil
        end
    end
end

---Clean up empty lobbies
---@private
function LobbyServerClass:_cleanupEmptyLobbies()
    for lobbyId, lobby in pairs(self._lobbies) do
        if #lobby.members == 0 and lobby.activeScenario then
            -- Check if any self-removed player is waiting to rejoin
            local hasWaitingPlayer = false

            for _, removeData in pairs(self._selfRemovedPlayers) do
                if removeData.lobbyId == lobbyId then
                    hasWaitingPlayer = true
                    break
                end
            end

            -- Delete lobby if no one is waiting
            if not hasWaitingPlayer then
                HeistServer.clearLobbyGameState(lobbyId)
                self._lobbies[lobbyId] = nil
            end
        end
    end
end

--[[ Lobby CRUD Operations ]]

---Get lobby by ID
---@param lobbyId string
---@return LobbyData? lobby
function LobbyServerClass:getLobbyById(lobbyId)
    if not lobbyId then return nil end
    return self._lobbies[lobbyId]
end

---Create new lobby
---@param ownerSource number|LobbyMember
---@return LobbyData lobby
function LobbyServerClass:create(ownerSource)
    local owner

    if type(ownerSource) == "number" then
        owner = createMemberFromSource(ownerSource)
    else
        owner = ownerSource
    end

    if not owner then
        error("Failed to create lobby: invalid owner")
    end

    -- Generate unique lobby ID
    self._lastLobbyIndex = incrementStringNumber(self._lastLobbyIndex)

    ---@type LobbyData
    local lobby = {
        id = self._lastLobbyIndex,
        members = { owner },
        owner = owner.source,
    }

    self._lobbies[self._lastLobbyIndex] = lobby

    return lobby
end

---Delete lobby and notify members
---@param lobbyId string
---@return boolean success
---@return string? message
function LobbyServerClass:delete(lobbyId)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then
        return false, "Lobby not found"
    end

    -- Notify all members
    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:lobby:setPlayerLobby"), member.source, nil)
    end

    -- Clear game state
    HeistServer.clearLobbyGameState(lobbyId)

    -- Remove lobby
    self._lobbies[lobbyId] = nil

    return true, "deleted"
end

---Get all lobbies
---@return table<string, LobbyData>
function LobbyServerClass:getAll()
    return self._lobbies
end

--[[ Member Management ]]

---Check if player is in any lobby
---@param source number
---@return string? lobbyId
function LobbyServerClass:findPlayerLobby(source)
    for lobbyId, lobby in pairs(self._lobbies) do
        for _, member in pairs(lobby.members) do
            if member.source == source then
                return lobbyId
            end
        end
    end
    return nil
end

---Check if player is free (not in any lobby)
---@param source number
---@return boolean isFree
function LobbyServerClass:isPlayerFree(source)
    return self:findPlayerLobby(source) == nil
end

---Check if player is in specific lobby
---@param lobbyId string
---@param source number
---@return boolean inLobby
function LobbyServerClass:isPlayerInLobby(lobbyId, source)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return false end

    for _, member in pairs(lobby.members) do
        if member.source == source then
            return true
        end
    end

    return false
end

---Add member to lobby
---@param lobbyId string
---@param member LobbyMember
---@param bypassChecks boolean?
---@return table result
function LobbyServerClass:addMember(lobbyId, member, bypassChecks)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    -- Validation checks
    if not bypassChecks then
        if lobby.activeScenario then
            return { success = false, message = locale("lobby.on_mission") }
        end
    end

    if #lobby.members >= MAX_LOBBY_MEMBERS then
        return { success = false, message = locale("lobby.lobby_is_full") }
    end

    -- Remove from current lobby if needed
    if not self:isPlayerFree(member.source) then
        local currentLobbyId = self:findPlayerLobby(member.source)
        if currentLobbyId then
            self:_removeMemberInternal(currentLobbyId, member.source)
        end
    end

    -- Set owner if lobby is empty
    if #lobby.members == 0 then
        lobby.owner = member.source
    end

    -- Add member
    table.insert(lobby.members, member)

    -- Recalculate shares
    self:_recalculateShares(lobbyId)

    -- Notify
    TriggerClientEvent(_e("client:lobby:setPlayerLobby"), member.source, lobby)
    self:notifyMembers(lobbyId, member.source)

    return { success = true }
end

---Remove member from lobby (internal, no self-remove tracking)
---@private
---@param lobbyId string
---@param source number
---@return boolean success
function LobbyServerClass:_removeMemberInternal(lobbyId, source)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return false end

    for i, member in pairs(lobby.members) do
        if member.source == source then
            table.remove(lobby.members, i)

            -- Reset owner if they left
            if lobby.owner == source then
                lobby.owner = nil
            end

            self:_updateLobbyData(lobbyId)
            return true
        end
    end

    return false
end

---Remove member from lobby (public, clears self-remove)
---@param lobbyId string
---@param source number
---@return boolean success
function LobbyServerClass:removeMember(lobbyId, source)
    -- Clear self-removed state
    local playerCid = Framework.getPlayerIdentifier(source)
    if playerCid then
        self._selfRemovedPlayers[playerCid] = nil
    end

    return self:_removeMemberInternal(lobbyId, source)
end

---Kick/fire member from lobby
---@param lobbyId string
---@param kickerSource number
---@param targetSource number
---@return table result
function LobbyServerClass:kickMember(lobbyId, kickerSource, targetSource)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    local isSelfKick = kickerSource == targetSource
    local isLeader = lobby.owner == kickerSource

    if not isSelfKick and not isLeader then
        return { success = false, message = locale("lobby.you_are_not_leader") }
    end

    -- Remove member
    self:removeMember(lobbyId, targetSource)

    -- Notify
    if isSelfKick then
        TriggerClientEvent(_e("client:lobby:setPlayerLobby"), kickerSource, nil)
    else
        self:notifyMembers(lobbyId)
        TriggerClientEvent(_e("client:lobby:setPlayerLobby"), targetSource, nil)
    end

    return { success = true }
end

---Recalculate and distribute shares equally
---@private
---@param lobbyId string
function LobbyServerClass:_recalculateShares(lobbyId)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return end

    local share = calculateEqualShare(#lobby.members)

    for _, member in pairs(lobby.members) do
        member.share = share
    end
end

---Update custom shares (leader only)
---@param lobbyId string
---@param leaderSource number
---@param newShares table
---@return table result
function LobbyServerClass:updateShares(lobbyId, leaderSource, newShares)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    if lobby.owner ~= leaderSource then
        return { success = false, message = locale("only_leader_can_do") }
    end

    -- Update shares
    for _, newMember in pairs(newShares) do
        for _, member in pairs(lobby.members) do
            if member.source == newMember.source then
                member.share = newMember.share
                break
            end
        end
    end

    self:notifyMembers(lobbyId, leaderSource)

    return { success = true }
end

--[[ Score Management ]]

---Increment member score
---@param lobbyId string
---@param source number
---@param count number?
---@return boolean success
function LobbyServerClass:incrementScore(lobbyId, source, count)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return false end

    count = count or 1
    for _, member in pairs(lobby.members) do
        if member.source == source then
            member.score = member.score + count
            self:_updateLobbyData(lobbyId)
            return true
        end
    end

    return false
end

---Reset member score
---@param lobbyId string
---@param source number
---@return boolean success
function LobbyServerClass:resetScore(lobbyId, source)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return false end

    for _, member in pairs(lobby.members) do
        if member.source == source then
            member.score = 0
            self:_updateLobbyData(lobbyId)
            return true
        end
    end

    return false
end

--[[ Notification & Updates ]]

---Notify all members except one
---@param lobbyId string
---@param exceptSource number?
function LobbyServerClass:notifyMembers(lobbyId, exceptSource)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return end

    for _, member in pairs(lobby.members) do
        if member.source ~= exceptSource then
            TriggerClientEvent(_e("client:lobby:updateLobbyMembers"), member.source, lobby.members)
        end
    end
end

---Update lobby data and notify all members
---@private
---@param lobbyId string
---@return boolean success
function LobbyServerClass:_updateLobbyData(lobbyId)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return false end

    -- Delete if empty and no active scenario
    if #lobby.members == 0 then
        if not lobby.activeScenario then
            return self:delete(lobbyId)
        else
            return true
        end
    end

    -- Assign new owner if needed
    if not lobby.owner then
        lobby.owner = lobby.members[1].source
    end

    -- Notify all members
    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:lobby:setPlayerLobby"), member.source, lobby)
    end

    return true
end

--[[ Invitation System ]]

---Invite player to lobby
---@param lobbyId string
---@param ownerSource number
---@param targetSource number
---@return table result
function LobbyServerClass:invite(lobbyId, ownerSource, targetSource)
    -- Validation
    if ownerSource == targetSource then
        return { success = false, message = locale("lobby.player_not_available") }
    end

    -- Check target exists
    local targetPlayer = Framework.getPlayer(targetSource)
    if not targetPlayer then
        return { success = false, message = locale("lobby.player_not_available") }
    end

    -- Check distance between players (bypass if requiredMinDistance < 1.0)
    local requiredDistance = Config.heistMenu.requiredMinDistance
    if requiredDistance and requiredDistance >= 1.0 then
        local ownerPed = GetPlayerPed(ownerSource)
        local targetPed = GetPlayerPed(targetSource)
        if ownerPed and targetPed then
            local ownerCoords = GetEntityCoords(ownerPed)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(ownerCoords - targetCoords)

            if distance > requiredDistance then
                return { success = false, message = locale("lobby.player_too_far") }
            end
        end
    end

    -- Check players current lobby is same as owner
    local ownerLobbyId = self:findPlayerLobby(ownerSource)
    local targetPlayerLobbyId = self:findPlayerLobby(targetSource)
    if ownerLobbyId and targetPlayerLobbyId and ownerLobbyId == targetPlayerLobbyId then
        return { success = false, message = locale("lobby.player_not_available") }
    end

    -- Check if target is in active scenario
    local targetLobbyId = self:findPlayerLobby(targetSource)
    if targetLobbyId then
        local targetLobby = self:getLobbyById(targetLobbyId)
        if targetLobby and targetLobby.activeScenario then
            return { success = false, message = locale("lobby.on_mission") }
        end
    end

    -- Get or create lobby
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then
        local ownerMember = createMemberFromSource(ownerSource)
        if not ownerMember then
            return { success = false, message = "Failed to create lobby" }
        end

        lobby = self:create(ownerMember)
        TriggerClientEvent(_e("client:lobby:setPlayerLobby"), ownerSource, lobby)
    end

    -- Send invite
    local ownerName = Framework.getPlayerCharacterName(ownerSource)
    TriggerClientEvent(_e("client:lobby:receiveLobbyInvite"), targetSource, lobby.id, ownerName)

    return { success = true }
end

--[[ Self-Remove System ]]

---Mark player as self-removed (disconnect during mission)
---@param lobbyId string
---@param playerId number
---@return boolean success
function LobbyServerClass:setSelfRemove(lobbyId, playerId)
    local lobby = self:getLobbyById(lobbyId)
    if not lobby then return false end

    -- Save player state
    local playerCid = Framework.getPlayerIdentifier(playerId)
    if playerCid then
        local playerScore = 0

        -- Find player score
        for _, member in ipairs(lobby.members) do
            if member.source == playerId then
                playerScore = member.score
                break
            end
        end

        self._selfRemovedPlayers[playerCid] = {
            lobbyId = lobbyId,
            score = playerScore,
            timestamp = os.time()
        }
    end

    -- Notify other members
    local playerName = Framework.getPlayerCharacterName(playerId)
    for _, member in ipairs(lobby.members) do
        if member.source ~= playerId then
            TriggerClientEvent(_e("client:lobby:memberSelfRemoved"), member.source, {
                lobbyId = lobbyId,
                playerId = playerId,
                playerName = playerName
            })
        end
    end

    -- Remove from lobby
    self:_removeMemberInternal(lobbyId, playerId)

    return true
end

---Get player's active scenario (rejoin after disconnect)
---@param playerId number
---@return table? scenarioData
function LobbyServerClass:getPlayerActiveScenario(playerId)
    local playerCid = Framework.getPlayerIdentifier(playerId)
    if not playerCid then return nil end

    local removeData = self._selfRemovedPlayers[playerCid]
    if not removeData then return nil end

    local lobby = self:getLobbyById(removeData.lobbyId)

    -- Check if lobby still has active scenario
    if lobby and lobby.activeScenario then
        -- Clear self-removed state
        self._selfRemovedPlayers[playerCid] = nil

        -- Notify members of return
        local playerName = Framework.getPlayerCharacterName(playerId)
        for _, member in ipairs(lobby.members) do
            TriggerClientEvent(_e("client:lobby:memberReturned"), member.source, {
                lobbyId = removeData.lobbyId,
                playerId = playerId,
                playerName = playerName
            })
        end

        -- Rejoin lobby
        local member = createMemberFromSource(playerId, removeData.score)
        if member then
            self:addMember(removeData.lobbyId, member, true)
        end

        return {
            currentScenario = lobby.activeScenario,
            lobbyId = removeData.lobbyId,
            lobby = lobby
        }
    else
        -- Lobby no longer active, clear state
        self._selfRemovedPlayers[playerCid] = nil
        return nil
    end
end

--[[ Callback Registration ]]

---Register all lib callbacks for lobby system
---@private
function LobbyServerClass:_registerCallbacks()
    -- Register lib callback handlers
    lib.callback.register(_e("server:lobby:invite"), function(source, lobbyId, targetSourceId)
        return self:invite(lobbyId, source, targetSourceId)
    end)

    lib.callback.register(_e("server:lobby:fireMember"), function(source, lobbyId, targetSourceId)
        return self:kickMember(lobbyId, source, targetSourceId)
    end)

    lib.callback.register(_e("server:lobby:join"), function(source, lobbyId)
        local member = createMemberFromSource(source)
        if not member then
            return { success = false, message = "Failed to create member data" }
        end
        return self:addMember(lobbyId, member)
    end)

    lib.callback.register(_e("server:lobby:getPlayerActiveScenario"), function(source)
        return self:getPlayerActiveScenario(source)
    end)

    lib.callback.register(_e("server:lobby:updateShares"), function(source, lobbyId, newMembers)
        return self:updateShares(lobbyId, source, newMembers)
    end)
end

---Initialize
function LobbyServerClass:initialize()
    self:_registerCallbacks()
end

--[[ Initialize Global Instance ]]

LobbyServer = LobbyServerClass.new()
LobbyServer:initialize()
