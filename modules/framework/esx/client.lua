--[[
    ESX Framework Bridge
    Provides ESX framework integration
]]

local ESX = exports.es_extended:getSharedObject()
local groups = { "job", "job2" }
local playerGroups = {}

-- Framework API table
local Framework = {}

---[[ Internal Functions ]]

local function setPlayerData(playerData)
    table.wipe(playerGroups)

    for i = 1, #groups do
        local group = groups[i]
        local data = playerData[group]

        if data then
            playerGroups[group] = data
        end
    end
end

if ESX.PlayerLoaded then
    setPlayerData(ESX.PlayerData)
end

---[[ Event Handlers ]]

RegisterNetEvent("esx:playerLoaded", function(xPlayer)
    if source == "" then return end
    setPlayerData(xPlayer)

    ClientApplication:onPlayerLoad(true)
end)

RegisterNetEvent("esx:onPlayerLogout", function()
    if source == "" then return end
    ClientApplication:onPlayerLoad(false)
end)

RegisterNetEvent("esx:setJob", function(job)
    if source == "" then return end
    playerGroups.job = job
end)

RegisterNetEvent("esx:setJob2", function(job)
    if source == "" then return end
    playerGroups.job2 = job
end)

---[[ Required Framework API ]]

---Check if player is loaded
---@return boolean
function Framework.isPlayerLoaded()
    return ESX.IsPlayerLoaded()
end

---Check if player has specific job/gang with optional grade check
---@param filter string|table Filter can be string (job name) or table (array of names or hash of name->grade)
---@return boolean
function Framework.hasPlayerGotGroup(filter)
    local filterType = type(filter)

    for i = 1, #groups do
        local group = groups[i]
        local data = playerGroups[group]

        if not data then goto continue end

        if filterType == "string" then
            if filter == data.name then
                return true
            end
        elseif filterType == "table" then
            local tableType = table.type(filter)

            if tableType == "hash" then
                for name, grade in pairs(filter) do
                    if data.name == name and data.grade >= grade then
                        return true
                    end
                end
            elseif tableType == "array" then
                for j = 1, #filter do
                    if data.name == filter[j] then
                        return true
                    end
                end
            end
        end

        ::continue::
    end

    return false
end

function Framework.getPlayerData()
    return ESX.PlayerData
end

return Framework
