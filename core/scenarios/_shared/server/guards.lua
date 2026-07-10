---@class GuardManagerServerOptions
---@field lobbyId string Lobby identifier
---@field guards table[] List of guard spawn configurations
---@field onGuardsSpawned? fun(guardNetIds: table, ownerId: number) Callback when guards spawned

---@class GuardManagerServer
---@field lobbyId string
---@field guards table[]
---@field onGuardsSpawned? fun(guardNetIds: table, ownerId: number)
---@field guardNetIds table<number, number> Network IDs of spawned guards
---@field spawned boolean
local GuardManagerServer = {}
GuardManagerServer.__index = GuardManagerServer

---Create new server-side guard manager instance
---@param options GuardManagerServerOptions
---@return GuardManagerServer
function GuardManagerServer.new(options)
    local self = setmetatable({}, GuardManagerServer)

    self.lobbyId = options.lobbyId
    self.guards = options.guards or {}
    self.onGuardsSpawned = options.onGuardsSpawned
    self.guardNetIds = {}
    self.spawned = false

    return self
end

---Register spawned guards
---@param guardNetIds table List of network IDs
---@param ownerId number Source ID of the lobby owner who spawned
---@return boolean success
function GuardManagerServer:registerSpawnedGuards(guardNetIds, ownerId)
    if self.spawned then
        return false
    end

    self.guardNetIds = guardNetIds
    self.spawned = true

    if self.onGuardsSpawned then
        self.onGuardsSpawned(guardNetIds, ownerId)
    end

    return true
end

---Check if guards are spawned
---@return boolean
function GuardManagerServer:areGuardsSpawned()
    return self.spawned
end

---Get guard network IDs
---@return table
function GuardManagerServer:getGuardNetIds()
    return self.guardNetIds
end

---Get all networked entities to delete (for cleanup)
---@return table
function GuardManagerServer:getNetIdsForCleanup()
    local netIds = {}
    for _, netId in pairs(self.guardNetIds) do
        table.insert(netIds, netId)
    end
    return netIds
end

---Clear state
function GuardManagerServer:clear()
    self.guardNetIds = {}
    self.spawned = false
end

return GuardManagerServer
