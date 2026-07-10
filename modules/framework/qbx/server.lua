--[[
    QBX Core Framework Bridge - Server
    Provides QBX Core framework integration for server-side
]]

-- Framework API table
local Framework = {}

-- Get player by source
---@param source number
---@return table|nil Player
function Framework.getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

-- Retrieves the player's identifier
---@param source number
---@return string|nil PlayerIdentifier
function Framework.getPlayerIdentifier(source)
    local xPlayer = Framework.getPlayer(source)
    if xPlayer then
        return xPlayer.PlayerData.citizenid
    end
    return nil
end

-- Retrieves the player's name
---@param source number
---@return string|nil
function Framework.getPlayerCharacterName(source)
    local xPlayer = Framework.getPlayer(source)
    if xPlayer then
        return (xPlayer.PlayerData.charinfo.firstname or "")
            .. " " ..
            (xPlayer.PlayerData.charinfo.lastname or "")
    end
    return nil
end

-- Give money to player
---@param source number
---@param account string
---@param amount number
---@return boolean
function Framework.playerAddMoney(source, account, amount)
    local xPlayer = Framework.getPlayer(source)
    if xPlayer then
        return xPlayer.Functions.AddMoney(account, tonumber(amount))
    end
    return false
end

---Remove money from player
---@param source number
---@param account string
---@param amount number
---@return boolean
function Framework.playerRemoveMoney(source, account, amount)
    local xPlayer = Framework.getPlayer(source)
    if xPlayer then
        return xPlayer.Functions.RemoveMoney(account, tonumber(amount))
    end
    return false
end

---Get player balance
---@param source number
---@param account string
---@return number
function Framework.getPlayerBalance(source, account)
    local xPlayer = Framework.getPlayer(source)
    return xPlayer and xPlayer.PlayerData.money[account] or 0
end

---Get player job
---@param source number
---@return table|nil
function Framework.getPlayerJob(source)
    local xPlayer = Framework.getPlayer(source)
    local data = {}
    if xPlayer then
        data.name = xPlayer.PlayerData.job.name
        data.onDuty = xPlayer.PlayerData.job.onduty
    end

    return data
end

---Create useable item
---@param item string
---@param callback function
function Framework.createUseableItem(item, callback)
    exports.qbx_core:CreateUseableItem(item, callback)
end

return Framework
