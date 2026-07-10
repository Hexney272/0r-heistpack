--[[ Dependencies ]]

local Framework = require "modules.framework.init"

local Inventory = {}

---@param source number
---@param itemName string
---@param count number
---@return boolean
function Inventory.giveItem(source, itemName, count)
    local xPlayer = Framework.getPlayer(source)
    if not xPlayer then return false end

    if shared.getFrameworkName() == "esx" then
        return xPlayer.addInventoryItem(itemName, count)
    elseif shared.getFrameworkName() == "qb" then
        return xPlayer.Functions.AddItem(itemName, count)
    elseif shared.getFrameworkName() == "qbx" then
        return xPlayer.Functions.AddItem(itemName, count)
    end
    return false
end

---@param source number
---@param itemName string
---@param count number
---@return boolean
function Inventory.removeItem(source, itemName, count)
    local xPlayer = Framework.getPlayer(source)
    if not xPlayer then return false end

    if shared.getFrameworkName() == "esx" then
        return xPlayer.removeInventoryItem(itemName, count)
    elseif shared.getFrameworkName() == "qb" then
        return xPlayer.Functions.RemoveItem(itemName, count)
    elseif shared.getFrameworkName() == "qbx" then
        return xPlayer.Functions.RemoveItem(itemName, count)
    end
    return false
end

---@param source number
---@param itemName string
---@param requiredCount number
---@return boolean
function Inventory.hasItem(source, itemName, requiredCount)
    requiredCount = requiredCount or 1
    local xPlayer = Framework.getPlayer(source)
    if not xPlayer then return false end

    local itemCount = 0
    local item = nil

    if shared.getFrameworkName() == "esx" then
        item = xPlayer.hasItem(itemName)
    else --[[ QB or QBX ]]
        item = xPlayer.Functions.GetItemByName(itemName)
    end
    if item then
        itemCount = item.amount or item.count or 0
    end
    return itemCount >= requiredCount
end

return Inventory
