--[[
    ESX Framework Bridge - Server
    Provides ESX framework integration for server-side
]]

local ESX = exports.es_extended:getSharedObject()

-- Framework API table
local Framework = {}

-- Get player by source
---@param source number
---@return table|nil xPlayer
function Framework.getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

-- Retrieves the player's identifier
---@param source number
---@return string|nil PlayerIdentifier
function Framework.getPlayerIdentifier(source)
    local xPlayer = Framework.getPlayer(source)
    if xPlayer then
        return xPlayer.getIdentifier()
    end
    return nil
end

-- Retrieves the player's name
---@param source number
---@return string|nil
function Framework.getPlayerCharacterName(source)
    local xPlayer = Framework.getPlayer(source)
    if xPlayer then
        return xPlayer.getName()
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
        account = (account == "cash") and "money" or account
        return xPlayer.addAccountMoney(account, tonumber(amount))
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
        return xPlayer.removeAccountMoney(account, tonumber(amount))
    end
    return false
end

---Get player balance
---@param source number
---@param account string
---@return number
function Framework.getPlayerBalance(source, account)
    account = (account == "cash") and "money" or account
    local xPlayer = Framework.getPlayer(source)
    return xPlayer and tonumber(xPlayer.getAccount(account).money) or 0
end

---Get player job
---@param source number
---@return table|nil
function Framework.getPlayerJob(source)
    local xPlayer = Framework.getPlayer(source)
    local data = {}
    if xPlayer then
        local xPlayerJob = xPlayer.getJob()
        data.name = xPlayerJob.name
        data.onDuty = xPlayerJob.onDuty
    end

    return data
end

---Create useable item
---@param item string
---@param callback function
function Framework.createUseableItem(item, callback)
    ESX.RegisterUsableItem(item, callback)
end

return Framework
