local lib = lib

---@class CustomerSafeManagerServer
local CustomerSafeManagerServer = {}
CustomerSafeManagerServer.__index = CustomerSafeManagerServer

---@class CustomerSafeManagerServerOptions
---@field lobbyId string Lobby identifier
---@field safes table[] List of customer safe configurations
---@field onSafeDrilled? fun(safeIndex: number, playerId: number) Callback when drilled

---Create new server-side customer safe manager instance
---@param options CustomerSafeManagerServerOptions
---@return CustomerSafeManagerServer
function CustomerSafeManagerServer.new(options)
    local self = setmetatable({}, CustomerSafeManagerServer)
    
    self.lobbyId = options.lobbyId
    self.safes = options.safes or {}
    self.onSafeDrilled = options.onSafeDrilled
    self.safeStates = {}
    
    -- Initialize safe states
    for safeIndex, safe in pairs(self.safes) do
        self.safeStates[safeIndex] = {
            drilled = false,
            busy = false,
        }
    end
    
    return self
end

---Check if safe exists
---@param safeIndex number
---@return boolean
function CustomerSafeManagerServer:safeExists(safeIndex)
    return self.safes[safeIndex] ~= nil
end

---Check if safe is drilled
---@param safeIndex number
---@return boolean
function CustomerSafeManagerServer:isSafeDrilled(safeIndex)
    local safeState = self.safeStates[safeIndex]
    return safeState and safeState.drilled or false
end

---Check if safe is busy
---@param safeIndex number
---@return boolean
function CustomerSafeManagerServer:isSafeBusy(safeIndex)
    local safeState = self.safeStates[safeIndex]
    return safeState and safeState.busy or false
end

---Mark safe as busy and return success
---@param safeIndex number
---@return boolean success
function CustomerSafeManagerServer:markBusy(safeIndex)
    if not self:safeExists(safeIndex) then
        return false
    end
    
    if self:isSafeDrilled(safeIndex) then
        return false
    end
    
    if self:isSafeBusy(safeIndex) then
        return false
    end
    
    self.safeStates[safeIndex].busy = true
    return true
end

---Drill safe
---@param safeIndex number
---@param playerId number Player who drilled
---@return boolean success
function CustomerSafeManagerServer:drillSafe(safeIndex, playerId)
    if not self:safeExists(safeIndex) then
        return false
    end
    
    if self:isSafeDrilled(safeIndex) then
        return false
    end
    
    self.safeStates[safeIndex].drilled = true
    self.safeStates[safeIndex].busy = false
    
    if self.onSafeDrilled then
        self.onSafeDrilled(safeIndex, playerId)
    end
    
    return true
end

---Get all safe states
---@return table
function CustomerSafeManagerServer:getStates()
    return self.safeStates
end

---Get specific safe state
---@param safeIndex number
---@return table|nil
function CustomerSafeManagerServer:getSafeState(safeIndex)
    return self.safeStates[safeIndex]
end

return CustomerSafeManagerServer
