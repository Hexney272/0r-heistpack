--[[
    LobbyClient - Client-Side Lobby Management

    @author 0resmon
    @version 2.0.0
]]

local lib = lib
local Utils = require "modules.utils.client"

---@class LobbyClient
---@field private _currentLobby LobbyData?
local LobbyClientClass = {}
LobbyClientClass.__index = LobbyClientClass

--[[ Constructor ]]

---Create new LobbyClient instance
---@return LobbyClient
function LobbyClientClass.new()
    local self = setmetatable({}, LobbyClientClass)
    self._currentLobby = nil
    return self
end

--[[ Lobby State Management ]]

---Check if player is in a lobby
---@return boolean
function LobbyClientClass:isInLobby()
    return self._currentLobby ~= nil and self._currentLobby.id ~= nil
end

---Get current lobby
---@return LobbyData?
function LobbyClientClass:getCurrentLobby()
    return self._currentLobby
end

---Get lobby ID
---@return string?
function LobbyClientClass:getLobbyId()
    return self._currentLobby and self._currentLobby.id
end

---Set lobby data
---@param lobbyData LobbyData
function LobbyClientClass:setLobby(lobbyData)
    if not lobbyData then
        self._currentLobby = nil
        ClientApplication.state.lobby = {}
    else
        self._currentLobby = lobbyData
        ClientApplication.state.lobby = lobbyData
    end

    -- Update UI
    ClientApplication:sendReactMessage("ui:setLobby", lobbyData)
end

---Update lobby members
---@param members table[]
function LobbyClientClass:updateMembers(members)
    if not self._currentLobby then return end

    self._currentLobby.members = members
    ClientApplication.state.lobby.members = members

    -- Update UI
    ClientApplication:sendReactMessage("ui:setLobbyMembers", members)
end

--[[ Team Member Management ]]

---Invite player to lobby
---@param targetSourceId number
---@return boolean success
function LobbyClientClass:invitePlayer(targetSourceId)
    local lobbyId = self:getLobbyId()
    local response = lib.callback.await(_e("server:lobby:invite"),
        false, lobbyId, targetSourceId)

    if not response.success then
        ClientApplication:sendReactAlert(response.message, "error")
        return false
    end

    ClientApplication:sendReactAlert(locale("lobby.invited_player"), "success")
    return true
end

---Fire/kick member from lobby
---@param targetSourceId number
---@return boolean success
function LobbyClientClass:kickMember(targetSourceId)
    local lobbyId = self:getLobbyId()
    if not lobbyId then
        return false
    end

    local response = lib.callback.await(_e("server:lobby:fireMember"), false, lobbyId, targetSourceId)

    if not response.success then
        ClientApplication:sendReactAlert(response.message, "error")
        return false
    end

    return true
end

--[[ Invitation Handling ]]

---Handle lobby invitation
---@param lobbyId string
---@param ownerName string
function LobbyClientClass:receiveInvitation(lobbyId, ownerName)
    -- Ignore if in active scenario
    if ClientApplication.state.activeScenario then
        return
    end

    -- Show invitation UI
    ClientApplication:sendReactMessage("ui:inviteReceived", {
        lobbyId = lobbyId,
        ownerName = ownerName
    })

    -- Open NUI if not already open
    if not ClientApplication.state.uiOpen then
        SetNuiFocus(true, true)
    end
end

---Accept lobby invitation
---@param lobbyId string
---@return boolean success
function LobbyClientClass:acceptInvitation(lobbyId)
    local response = lib.callback.await(_e("server:lobby:join"), false, lobbyId)

    if not response.success then
        if not ClientApplication.state.uiOpen then
            ClientApplication:hideFrame()
            Utils.notify(response.message, "error")
        else
            ClientApplication:sendReactAlert(response.message, "error")
        end
        return false
    end

    ClientApplication:sendReactAlert(locale("lobby.joined_lobby"), "success")

    if not ClientApplication.state.uiOpen then
        ClientApplication:hideFrame()
    end

    return true
end

---Close invitation modal
function LobbyClientClass:closeInvitationModal()
    if not ClientApplication.state.uiOpen then
        ClientApplication:hideFrame()
    end
end

--[[ Share Management ]]

---Update member shares
---@param members table[]
---@return boolean success
function LobbyClientClass:updateShares(members)
    local lobbyId = self:getLobbyId()
    if not lobbyId then
        return false
    end

    local response = lib.callback.await(_e("server:lobby:updateShares"), false, lobbyId, members)

    if not response.success then
        ClientApplication:sendReactAlert(response.message, "error")
        return false
    end

    return true
end

--[[ Notifications ]]

---Handle member self-removed notification
---@param params table
function LobbyClientClass:onMemberSelfRemoved(params)
    Utils.notify(locale("lobby.member_self_removed", params.playerName), "warning")
end

---Handle member returned notification
---@param params table
function LobbyClientClass:onMemberReturned(params)
    Utils.notify(locale("lobby.member_returned", params.playerName), "success")
end

--[[ Event Registration ]]

---Register all network events for lobby system
---@private
function LobbyClientClass:_registerEvents()
    -- Register network event listeners
    RegisterNetEvent(_e("client:lobby:setPlayerLobby"), function(newLobby)
        self:setLobby(newLobby)
    end)

    RegisterNetEvent(_e("client:lobby:receiveLobbyInvite"), function(lobbyId, ownerName)
        self:receiveInvitation(lobbyId, ownerName)
    end)

    RegisterNetEvent(_e("client:lobby:updateLobbyMembers"), function(newMembers)
        self:updateMembers(newMembers)
    end)

    RegisterNetEvent(_e("client:lobby:memberSelfRemoved"), function(params)
        self:onMemberSelfRemoved(params)
    end)

    RegisterNetEvent(_e("client:lobby:memberReturned"), function(params)
        self:onMemberReturned(params)
    end)
end

---Register all NUI callbacks for lobby system
---@private
function LobbyClientClass:_registerNUICallbacks()
    -- Register NUI callback handlers
    RegisterNUICallback("nui:lobby:hireTeamMember", function(targetSourceId, resultCallback)
        local success = self:invitePlayer(targetSourceId)
        resultCallback(success)
    end)

    RegisterNUICallback("nui:lobby:fireTeamMember", function(targetSourceId, resultCallback)
        local success = self:kickMember(targetSourceId)
        resultCallback(success)
    end)

    RegisterNUICallback("nui:lobby:acceptJoinInvite", function(lobbyId, resultCallback)
        local success = self:acceptInvitation(lobbyId)
        resultCallback(success)
    end)

    RegisterNUICallback("nui:lobby:onInviteModalClosed", function(_, resultCallback)
        self:closeInvitationModal()
        resultCallback(true)
    end)

    RegisterNUICallback("nui:lobby:updateShares", function(data, resultCallback)
        local success = self:updateShares(data.members)
        resultCallback(success)
    end)
end

---Initialize lobby client
function LobbyClientClass:initialize()
    self:_registerEvents()
    self:_registerNUICallbacks()
end

--[[ Initialize Global Instance ]]

LobbyClient = LobbyClientClass.new()
LobbyClient:initialize()
