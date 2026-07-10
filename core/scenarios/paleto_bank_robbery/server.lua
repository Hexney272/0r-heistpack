local lib               = lib
local Utils             = require("modules.utils.server")
local Inventory         = require("modules.inventory.server")

local config            = lib.load("config.scenarios.paleto_bank_robbery")

PaletoBankRobberyServer = {}

local scenarioKey       = "paleto_bank_robbery"
local SV_MAP_TYPE       = config.hasCustomMap and "custom" or "standart"

---@section LIFECYCLE FUNCTIONS

function PaletoBankRobberyServer.clear(activeScenario)
    if not activeScenario then return end
end

function PaletoBankRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    -- Initialize game state
    lobby.activeScenario.game.doors = lib.table.deepclone(config.doors)
    lobby.activeScenario.game.cashTrolleyGroups = lib.table.deepclone(config.cashTrolleyGroups)
    lobby.activeScenario.game.securityDisabled = false

    return { success = true }
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("server:scenarios:paleto_bank_robbery:onBombPlantOnDoor"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local bombRot = params.bombRot

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.doors or
        not lobby.activeScenario.game.doors[SV_MAP_TYPE][doorId] or
        lobby.activeScenario.game.doors[SV_MAP_TYPE][doorId].unlocked
    then
        return
    end

    lobby.activeScenario.game.doors[SV_MAP_TYPE][doorId].unlocked = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:paleto_bank_robbery:onDoorUnlockedWithBomb"), member.source, {
            lobbyId = lobbyId,
            doorId = doorId,
            bombRot = bombRot,
            unlocked = true
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:paleto_bank_robbery:onDoorUnlocked"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.doors or
        not lobby.activeScenario.game.doors[SV_MAP_TYPE][doorId] or
        lobby.activeScenario.game.doors[SV_MAP_TYPE][doorId].unlocked
    then
        return
    end

    lobby.activeScenario.game.doors[SV_MAP_TYPE][doorId].unlocked = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:paleto_bank_robbery:onDoorUnlocked"), member.source, {
            lobbyId = lobbyId,
            doorId = doorId,
            unlockType = unlockType,
            unlocked = true
        })
    end
end)

---@section CALLBACK HANDLERS

lib.callback.register(_e("server:scenarios:paleto_bank_robbery:isTrolleyBusy"), function(source, params)
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return true end

    if not lobby.activeScenario then return true end
    if lobby.activeScenario.key ~= scenarioKey then return true end
    if not lobby.activeScenario.game.cashTrolleyGroups then return true end
    if not lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE] then return true end
    if not lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex] then return true end
    if lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].busy then return true end
    if lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].collected then return true end

    lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].busy = true

    return false
end)

RegisterNetEvent(_e("server:scenarios:paleto_bank_robbery:onTrolleyCollected"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end

    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.cashTrolleyGroups then return end
    if not lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE] then return end
    if not lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex] then return end
    if lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].collected then return end

    lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].collected = true
    lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].busy = false

    local trolleyType = config.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex].ingot and "ingot" or "money"

    local rewards = config.trolleyRobberyRewards[trolleyType] or {}
    local selectedRewards = Utils.selectRandomRewards(rewards)
    for _, reward in pairs(selectedRewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:paleto_bank_robbery:onTrolleyCollected"), member.source, {
            lobbyId = lobbyId,
            trolleyIndex = trolleyIndex,
            collected = true
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:paleto_bank_robbery:onSecurityDisabled"), function(params)
    local source = source
    local lobbyId = params.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.activeScenario.game.securityDisabled
    then
        return
    end

    lobby.activeScenario.game.securityDisabled = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:paleto_bank_robbery:onSecurityDisabled"), member.source, {
            lobbyId = lobbyId,
            securityDisabled = true
        })
    end
end)
