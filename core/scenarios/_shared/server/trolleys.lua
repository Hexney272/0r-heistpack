local lib = lib

---@class TrolleyManagerServer
local TrolleyManagerServer = {}
TrolleyManagerServer.__index = TrolleyManagerServer

---@class TrolleyManagerServerOptions
---@field lobbyId string Lobby identifier
---@field trolleys table[] List of trolley configurations
---@field onTrolleyCollected? fun(trolleyIndex: number, playerId: number, trolleyType: string) Callback when collected

---Create new server-side trolley manager instance
---@param options TrolleyManagerServerOptions
---@return TrolleyManagerServer
function TrolleyManagerServer.new(options)
    local self = setmetatable({}, TrolleyManagerServer)
    
    self.lobbyId = options.lobbyId
    self.trolleys = options.trolleys or {}
    self.onTrolleyCollected = options.onTrolleyCollected
    self.trolleyStates = {}
    
    -- Initialize trolley states
    for trolleyIndex, trolley in pairs(self.trolleys) do
        self.trolleyStates[trolleyIndex] = {
            busy = false,
            collected = false,
            type = trolley.ingot and "ingot" or "money",
        }
    end
    
    return self
end

---Check if trolley is busy
---@param trolleyIndex number
---@return boolean
function TrolleyManagerServer:isTrolleyBusy(trolleyIndex)
    if not self:trolleyExists(trolleyIndex) then
        return true
    end
    
    local trolleyState = self.trolleyStates[trolleyIndex]
    return trolleyState.busy or trolleyState.collected
end

---Check if trolley exists
---@param trolleyIndex number
---@return boolean
function TrolleyManagerServer:trolleyExists(trolleyIndex)
    return self.trolleys[trolleyIndex] ~= nil
end

---Check if trolley is collected
---@param trolleyIndex number
---@return boolean
function TrolleyManagerServer:isTrolleyCollected(trolleyIndex)
    local trolleyState = self.trolleyStates[trolleyIndex]
    return trolleyState and trolleyState.collected or false
end

---Mark trolley as busy (being collected)
---@param trolleyIndex number
---@return boolean success
function TrolleyManagerServer:markBusy(trolleyIndex)
    if not self:trolleyExists(trolleyIndex) then
        return false
    end
    
    if self:isTrolleyBusy(trolleyIndex) then
        return false
    end
    
    self.trolleyStates[trolleyIndex].busy = true
    return true
end

---Collect trolley
---@param trolleyIndex number
---@param playerId number Player who collected
---@return boolean success
---@return string|nil trolleyType
function TrolleyManagerServer:collectTrolley(trolleyIndex, playerId)
    if not self:trolleyExists(trolleyIndex) then
        return false, nil
    end
    
    local trolleyState = self.trolleyStates[trolleyIndex]
    if trolleyState.collected then
        return false, nil
    end
    
    trolleyState.collected = true
    trolleyState.busy = false
    
    local trolleyType = trolleyState.type
    
    if self.onTrolleyCollected then
        self.onTrolleyCollected(trolleyIndex, playerId, trolleyType)
    end
    
    return true, trolleyType
end

---Get all trolley states
---@return table
function TrolleyManagerServer:getStates()
    return self.trolleyStates
end

---Get specific trolley state
---@param trolleyIndex number
---@return table|nil
function TrolleyManagerServer:getTrolleyState(trolleyIndex)
    return self.trolleyStates[trolleyIndex]
end

return TrolleyManagerServer
