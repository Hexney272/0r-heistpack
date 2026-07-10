local lib = lib

---@class LootableMoneyManagerServer
local LootableMoneyManagerServer = {}
LootableMoneyManagerServer.__index = LootableMoneyManagerServer

---@class LootableMoneyManagerServerOptions
---@field lobbyId string Lobby identifier
---@field moneys table[] List of lootable money configurations
---@field onMoneyCollected? fun(moneyIndex: number, playerId: number) Callback when collected

---Create new server-side lootable money manager instance
---@param options LootableMoneyManagerServerOptions
---@return LootableMoneyManagerServer
function LootableMoneyManagerServer.new(options)
    local self = setmetatable({}, LootableMoneyManagerServer)
    
    self.lobbyId = options.lobbyId
    self.moneys = options.moneys or {}
    self.onMoneyCollected = options.onMoneyCollected
    self.moneyStates = {}
    
    -- Initialize money states
    for moneyIndex, money in pairs(self.moneys) do
        self.moneyStates[moneyIndex] = {
            collected = false,
        }
    end
    
    return self
end

---Check if money exists
---@param moneyIndex number
---@return boolean
function LootableMoneyManagerServer:moneyExists(moneyIndex)
    return self.moneys[moneyIndex] ~= nil
end

---Check if money is collected
---@param moneyIndex number
---@return boolean
function LootableMoneyManagerServer:isMoneyCollected(moneyIndex)
    local moneyState = self.moneyStates[moneyIndex]
    return moneyState and moneyState.collected or false
end

---Collect money
---@param moneyIndex number
---@param playerId number Player who collected
---@return boolean success
function LootableMoneyManagerServer:collectMoney(moneyIndex, playerId)
    if not self:moneyExists(moneyIndex) then
        return false
    end
    
    if self:isMoneyCollected(moneyIndex) then
        return false
    end
    
    self.moneyStates[moneyIndex].collected = true
    
    if self.onMoneyCollected then
        self.onMoneyCollected(moneyIndex, playerId)
    end
    
    return true
end

---Get all money states
---@return table
function LootableMoneyManagerServer:getStates()
    return self.moneyStates
end

---Get specific money state
---@param moneyIndex number
---@return table|nil
function LootableMoneyManagerServer:getMoneyState(moneyIndex)
    return self.moneyStates[moneyIndex]
end

return LootableMoneyManagerServer
