--[[
    QBCore Framework Bridge
    Provides QBCore framework integration
]]

local QBCore = exports["qb-core"]:GetCoreObject()
local groups = { "job", "gang" }
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

if LocalPlayer.state.isLoggedIn then
    setPlayerData(QBCore.Functions.GetPlayerData())
end

---[[ Event Handlers ]]

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    setPlayerData(QBCore.Functions.GetPlayerData())
    ClientApplication:onPlayerLoad(true)
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    ClientApplication:onPlayerLoad(false)
end)

RegisterNetEvent("QBCore:Player:SetPlayerData", function(playerData)
    setPlayerData(playerData)
end)

---[[ Required Framework API ]]

---Check if player is loaded
---@return boolean
function Framework.isPlayerLoaded()
    return LocalPlayer.state.isLoggedIn
end

---Check if player has specific job/gang with optional grade check
---@param filter string|table Filter can be string (job/gang name) or table (array of names or hash of name->grade)
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
                    if data.name == name and data.grade and data.grade.level >= grade then
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
    return QBCore.Functions.GetPlayerData()
end

return Framework
