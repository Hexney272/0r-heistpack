--[[
    QBX Core Framework Bridge
    Provides QBX Core framework integration
]]

local QBX = nil

if lib.checkDependency("qbx_core", "1.18.0", true) then
    QBX = exports.qbx_core
end

-- Framework API table
local Framework = {}

---[[ Event Handlers ]]

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    ClientApplication:onPlayerLoad(true)
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    ClientApplication:onPlayerLoad(false)
end)

---[[ Required Framework API ]]

---Check if player is loaded
---@return boolean
function Framework.isPlayerLoaded()
    return LocalPlayer.state.isLoggedIn
end

---Check if player has specific job/gang using QBX native method
---@param filter string|table Filter can be string (job/gang name) or table (array of names or hash of name->grade)
---@return boolean
function Framework.hasPlayerGotGroup(filter)
    if QBX then
        return QBX:HasGroup(filter)
    end
    return false
end

function Framework.getPlayerData()
    local QBCORE = exports["qb-core"]:GetCoreObject()
    if QBCORE then
        return QBCORE.Functions.GetPlayerData()
    end
    
    return {}
end

return Framework
