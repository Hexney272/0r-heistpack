---@class DoorManagerServerOptions
---@field lobbyId string Lobby identifier
---@field doors table[] List of doors configuration
---@field onDoorUnlocked? fun(doorIndex: number, playerId: number) Callback when door unlocked

---@class DoorManagerServer
---@field lobbyId string
---@field doors table[]
---@field onDoorUnlocked? fun(doorIndex: number, playerId: number)
---@field doorStates table<number, {unlocked: boolean, method: any, deleted: boolean}>
local DoorManagerServer = {}
DoorManagerServer.__index = DoorManagerServer

---Create new server-side door manager instance
---@param options DoorManagerServerOptions
---@return DoorManagerServer
function DoorManagerServer.new(options)
    local self = setmetatable({}, DoorManagerServer)

    self.lobbyId = options.lobbyId
    self.doors = options.doors or {}
    self.onDoorUnlocked = options.onDoorUnlocked
    self.doorStates = {}

    -- Initialize door states
    for doorIndex, door in pairs(self.doors) do
        self.doorStates[doorIndex] = {
            unlocked = false,
            method = door.unlockMethod,
            deleted = door.meta and door.meta.delete or false,
        }
    end

    return self
end

---Check if door is unlocked
---@param doorIndex number
---@return boolean
function DoorManagerServer:isDoorUnlocked(doorIndex)
    local doorState = self.doorStates[doorIndex]
    return doorState and doorState.unlocked or false
end

---Check if door exists
---@param doorIndex number
---@return boolean
function DoorManagerServer:doorExists(doorIndex)
    return self.doors[doorIndex] ~= nil
end

---Unlock a door
---@param doorIndex number
---@param playerId number Player who unlocked
---@return boolean success
function DoorManagerServer:unlockDoor(doorIndex, playerId)
    if not self:doorExists(doorIndex) then
        return false
    end
    
    if self:isDoorUnlocked(doorIndex) then
        return false
    end
    
    self.doorStates[doorIndex].unlocked = true
    
    if self.onDoorUnlocked then
        self.onDoorUnlocked(doorIndex, playerId)
    end
    
    return true
end

---Get all door states
---@return table
function DoorManagerServer:getStates()
    return self.doorStates
end

---Get specific door state
---@param doorIndex number
---@return table|nil
function DoorManagerServer:getDoorState(doorIndex)
    return self.doorStates[doorIndex]
end

return DoorManagerServer
