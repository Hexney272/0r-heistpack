local lib                        = lib
local Utils                      = require("modules.utils.server")
local Inventory                  = require("modules.inventory.server")
local DoorManagerServer          = require("core.scenarios._shared.server.doors")
local TrolleyManagerServer       = require("core.scenarios._shared.server.trolleys")
local LootableMoneyManagerServer = require("core.scenarios._shared.server.lootable_moneys")
local CustomerSafeManagerServer  = require("core.scenarios._shared.server.customer_safes")

local config                     = lib.load("config.scenarios.fleeca_bank_robbery")

FleecaBankRobberyServer          = {}

local scenarioKey                = "fleeca_bank_robbery"

local SV_MAP_TYPE                = config.hasCustomMap and "custom" or "standart"

---@section PUBLIC FUNCTIONS

--- Cleanup scenario resources for a lobby
function FleecaBankRobberyServer.clear(activeScenario)
    if not activeScenario then return end
end

--- Initialize scenario for a lobby
--- Initialize scenario for a lobby
function FleecaBankRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, error = "invalid_lobby_or_scenario" }
    end

    -- Reset location data
    lobby.activeScenario.game.location = nil
    lobby.activeScenario.game.locationIndex = nil

    return { success = true }
end

---@section EVENT HANDLERS

--- Handle location selection
RegisterNetEvent(_e("server:scenarios:fleeca_bank_robbery:setLocation"), function(params)
    local lobbyId = params.lobbyId
    local locationIndex = params.locationIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not config.locations[locationIndex][SV_MAP_TYPE] or
        lobby.activeScenario.game.locationIndex
    then
        return
    end

    lobby.activeScenario.game.locationIndex = locationIndex
    lobby.activeScenario.game.location = lib.table.deepclone(config.locations[locationIndex][SV_MAP_TYPE])
    lobby.activeScenario.game.doors = DoorManagerServer.new({
        lobbyId = lobbyId,
        doors = lobby.activeScenario.game.location.doors,
    })
    lobby.activeScenario.game.trolleys = TrolleyManagerServer.new({
        lobbyId = lobbyId,
        trolleys = lobby.activeScenario.game.location.cashTrolleys or {},
    })
    lobby.activeScenario.game.lootableMoneys = LootableMoneyManagerServer.new({
        lobbyId = lobbyId,
        moneys = lobby.activeScenario.game.location.lootableMoneys or {},
    })
    lobby.activeScenario.game.customerSafes = CustomerSafeManagerServer.new({
        lobbyId = lobbyId,
        safes = lobby.activeScenario.game.location.drillCustomerSafes or {},
    })

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:fleeca_bank_robbery:onLocationSet"), member.source, {
            lobbyId = lobbyId,
            locationIndex = locationIndex,
            location = lobby.activeScenario.game.location,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:fleeca_bank_robbery:onDoorUnlocked"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey
    then
        return
    end

    local success = lobby.activeScenario.game.doors:unlockDoor(doorId, playerId)
    if not success then return end

    TriggerClientEvent(_e("client:scenarios:fleeca_bank_robbery:onDoorUnlocked"), -1, {
        lobbyId = lobbyId,
        doorId = doorId,
        unlockType = unlockType,
        unlocked = true
    })
end)

lib.callback.register(_e("server:scenarios:fleeca_bank_robbery:isTrolleyBusy"), function(source, params)
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey
    then
        return true
    end

    return not lobby.activeScenario.game.trolleys:markBusy(trolleyIndex)
end)

RegisterNetEvent(_e("server:scenarios:fleeca_bank_robbery:onTrolleyCollected"), function(params)
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.trolleys
    then
        return
    end

    local success, trolleyType = lobby.activeScenario.game.trolleys:collectTrolley(trolleyIndex, playerId)
    if not success then return end

    -- Give rewards to playerId
    local rewards = config.trolleyRobberyRewards[trolleyType]
    local selectedRewards = Utils.selectRandomRewards(rewards)
    for _, reward in pairs(selectedRewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:fleeca_bank_robbery:onTrolleyCollected"), member.source, {
            lobbyId = lobbyId,
            trolleyIndex = trolleyIndex,
            collected = true
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:fleeca_bank_robbery:onMoneyCollected"), function(params)
    local lobbyId = params.lobbyId
    local moneyIndex = params.moneyIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.lootableMoneys
    then
        return
    end

    local success = lobby.activeScenario.game.lootableMoneys:collectMoney(moneyIndex, playerId)
    if not success then return end

    local rewards = Utils.selectRandomRewards(config.lootableMoneyRewards)
    for _, reward in pairs(rewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:fleeca_bank_robbery:onMoneyCollected"), member.source, {
            lobbyId = lobbyId,
            moneyIndex = moneyIndex,
            collected = true
        })
    end
end)

lib.callback.register(_e("server:scenarios:fleeca_bank_robbery:isCustomerSafeBusy"), function(source, params)
    local lobbyId = params.lobbyId
    local safeIndex = params.safeIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.customerSafes
    then
        return true
    end

    return not lobby.activeScenario.game.customerSafes:markBusy(safeIndex)
end)

RegisterNetEvent(_e("server:scenarios:fleeca_bank_robbery:onCustomerSafeDrilled"), function(params)
    local lobbyId = params.lobbyId
    local safeIndex = params.safeIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.customerSafes
    then
        return
    end

    local success = lobby.activeScenario.game.customerSafes:drillSafe(safeIndex, playerId)
    if not success then return end

    local rewards = Utils.selectRandomRewards(config.drillCustomerSafeRewards)
    for _, reward in pairs(rewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:fleeca_bank_robbery:onCustomerSafeDrilled"), member.source, {
            lobbyId = lobbyId,
            safeIndex = safeIndex,
            drilled = true
        })
    end
end)
