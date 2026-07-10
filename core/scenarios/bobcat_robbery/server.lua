local lib                  = lib
local Utils                = require("modules.utils.server")
local Inventory            = require("modules.inventory.server")
local DoorManagerServer    = require("core.scenarios._shared.server.doors")
local TrolleyManagerServer = require("core.scenarios._shared.server.trolleys")
local GuardManagerServer   = require("core.scenarios._shared.server.guards")

local config               = lib.load("config.scenarios.bobcat_robbery")

BobcatRobberyServer        = {}

local scenarioKey          = "bobcat_robbery"

---@section PUBLIC FUNCTIONS

--- Cleanup scenario resources for a lobby
function BobcatRobberyServer.clear(activeScenario)
    if not activeScenario then return end

    TriggerClientEvent(_e("client:scenarios:bobcat_robbery:clearRedRoomVault"), -1)
end

--- Initialize scenario for a lobby
function BobcatRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, error = "invalid_lobby_or_scenario" }
    end

    -- Initialize doors state
    lobby.activeScenario.game.doors = DoorManagerServer.new({
        lobbyId = lobbyId,
        doors = config.doors,
    })

    -- Initialize trolley groups
    lobby.activeScenario.game.trolleys = TrolleyManagerServer.new({
        lobbyId = lobbyId,
        trolleys = config.cashTrolleyGroups or {},
    })

    -- Initialize red room vault state
    lobby.activeScenario.game.redRoomVault = {
        bombPlanted = false,
        vaultOpened = false,
    }

    -- Initialize guards manager
    lobby.activeScenario.game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.guards
    })

    return { success = true }
end

RegisterNetEvent(_e("server:scenarios:bobcat_robbery:onGuardsSpawned"), function(params)
    local lobbyId = params.lobbyId
    local guardNetIds = params.guardNetIds
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.owner ~= playerId
    then
        return
    end

    lobby.activeScenario.game.guards:registerSpawnedGuards(guardNetIds, playerId)

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:bobcat_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)

---@section EVENT HANDLERS - RED ROOM VAULT

RegisterNetEvent(_e("server:scenarios:bobcat_robbery:onRedRoomBombExploded"), function(params)
    local lobbyId = params.lobbyId
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.redRoomVault
    then
        return
    end

    -- Check if bomb already planted
    if lobby.activeScenario.game.redRoomVault.bombPlanted then
        return
    end

    -- Mark bomb as planted
    lobby.activeScenario.game.redRoomVault.bombPlanted = true
    lobby.activeScenario.game.redRoomVault.vaultOpened = true

    TriggerClientEvent(_e("client:scenarios:bobcat_robbery:onRedRoomVaultExploded"), -1)
end)

---@section EVENT HANDLERS - DOORS

RegisterNetEvent(_e("server:scenarios:bobcat_robbery:onBombPlantOnDoor"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local bombRot = params.bombRot
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.doors
    then
        return
    end

    local success = lobby.activeScenario.game.doors:unlockDoor(doorId, playerId)
    if not success then return end

    TriggerClientEvent(_e("client:scenarios:bobcat_robbery:onDoorUnlockedWithBomb"), -1, {
        lobbyId = lobbyId,
        doorId = doorId,
        bombRot = bombRot,
        unlocked = true
    })
end)

RegisterNetEvent(_e("server:scenarios:bobcat_robbery:onDoorUnlocked"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.doors
    then
        return
    end

    local success = lobby.activeScenario.game.doors:unlockDoor(doorId, playerId)
    if not success then return end

    TriggerClientEvent(_e("client:scenarios:bobcat_robbery:onDoorUnlocked"), -1, {
        lobbyId = lobbyId,
        doorId = doorId,
        unlockType = unlockType,
        unlocked = true
    })
end)

---@section EVENT HANDLERS - TROLLEYS

lib.callback.register(_e("server:scenarios:bobcat_robbery:isTrolleyBusy"), function(source, params)
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return true end

    if not lobby.activeScenario then return true end
    if lobby.activeScenario.key ~= scenarioKey then return true end
    if not lobby.activeScenario.game.trolleys then return true end

    return not lobby.activeScenario.game.trolleys:markBusy(trolleyIndex)
end)

RegisterNetEvent(_e("server:scenarios:bobcat_robbery:onTrolleyCollected"), function(params)
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end

    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.trolleys then return end

    local success, trolleyType = lobby.activeScenario.game.trolleys:collectTrolley(trolleyIndex, playerId)
    if not success then return end

    -- Give rewards to playerId
    local rewards = config.trolleyRobberyRewards[trolleyType] or {}
    local selectedRewards = Utils.selectRandomRewards(rewards)
    for _, reward in pairs(selectedRewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:bobcat_robbery:onTrolleyCollected"), member.source, {
            lobbyId = lobbyId,
            trolleyIndex = trolleyIndex,
            collected = true
        })
    end
end)
