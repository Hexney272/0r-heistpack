local lib = lib

---@class CooldownManager
--- Manages player and scenario cooldowns with centralized logic
local CooldownManager = {}

--- Active cooldowns storage
---@type table<string, number> Scenario cooldowns (scenarioKey -> endTime)
local scenarioCooldowns = {}

---@type table<number, number> Player cooldowns (playerId -> endTime)
local playerCooldowns = {}

--- Set cooldown for a scenario
---@param scenarioKey string The scenario identifier
---@param durationMinutes number Cooldown duration in minutes
function CooldownManager.setScenarioCooldown(scenarioKey, durationMinutes)
    if not scenarioKey or durationMinutes <= 0 then return end
    scenarioCooldowns[scenarioKey] = os.time() + (durationMinutes * 60)
end

--- Set cooldown for a player
---@param playerId number The player server ID
---@param durationMinutes number Cooldown duration in minutes
function CooldownManager.setPlayerCooldown(playerId, durationMinutes)
    if not playerId or durationMinutes <= 0 then return end
    playerCooldowns[playerId] = os.time() + (durationMinutes * 60)
end

--- Check if scenario is in cooldown
---@param scenarioKey string The scenario identifier
---@return boolean inCooldown
---@return number|nil remainingSeconds
function CooldownManager.isScenarioInCooldown(scenarioKey)
    local endTime = scenarioCooldowns[scenarioKey]
    if not endTime then return false, nil end

    local currentTime = os.time()
    if currentTime < endTime then
        return true, endTime - currentTime
    else
        scenarioCooldowns[scenarioKey] = nil
        return false, nil
    end
end

--- Check if player is in cooldown
---@param playerId number The player server ID
---@return boolean inCooldown
---@return number|nil remainingSeconds
function CooldownManager.isPlayerInCooldown(playerId)
    local endTime = playerCooldowns[playerId]
    if not endTime then return false, nil end

    local currentTime = os.time()
    if currentTime < endTime then
        return true, endTime - currentTime
    else
        playerCooldowns[playerId] = nil
        return false, nil
    end
end

--- Remove cooldown for a scenario
---@param scenarioKey string The scenario identifier
function CooldownManager.clearScenarioCooldown(scenarioKey)
    scenarioCooldowns[scenarioKey] = nil
end

--- Remove cooldown for a player
---@param playerId number The player server ID
function CooldownManager.clearPlayerCooldown(playerId)
    playerCooldowns[playerId] = nil
end

--- Get all scenario cooldowns
---@return table<string, number> cooldowns Map of scenarioKey to endTime
function CooldownManager.getAllScenarioCooldowns()
    return scenarioCooldowns
end

--- Get all player cooldowns
---@return table<number, number> cooldowns Map of playerId to endTime
function CooldownManager.getAllPlayerCooldowns()
    return playerCooldowns
end

--- Clear all cooldowns
function CooldownManager.clearAll()
    scenarioCooldowns = {}
    playerCooldowns = {}
end

return CooldownManager
