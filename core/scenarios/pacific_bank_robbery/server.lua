local lib                  = lib
local Utils                = require("modules.utils.server")
local Inventory            = require("modules.inventory.server")
local DoorManagerServer    = require("core.scenarios._shared.server.doors")
local TrolleyManagerServer = require("core.scenarios._shared.server.trolleys")
local GuardManagerServer   = require("core.scenarios._shared.server.guards")

local config               = lib.load("config.scenarios.pacific_bank_robbery")

PacificBankRobberyServer   = {}

local scenarioKey          = "pacific_bank_robbery"

local SV_MAP_TYPE          = config.hasCustomMap and "custom" or "standart"

---@section PUBLIC FUNCTIONS

--- Cleanup scenario resources for a lobby
function PacificBankRobberyServer.clear(activeScenario)
    if not activeScenario then return end
end

--- Initialize scenario for a lobby
function PacificBankRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, error = "invalid_lobby_or_scenario" }
    end

    -- Initialize bomb drop locations
    lobby.activeScenario.game.bombDropOptions = {
        allDropped = false,
        locations = {
            center = config.bombDropOptions.locations.center,
            usage = config.bombDropOptions.locations.usage,
            dropZones = {},
        }
    }

    -- Copy drop zones
    for i, zone in pairs(config.bombDropOptions.locations.dropZones) do
        lobby.activeScenario.game.bombDropOptions.locations.dropZones[i] = {
            coords = zone.coords,
            radius = zone.radius,
            dropped = false,
        }
    end

    -- Initialize doors state
    lobby.activeScenario.game.doors = {}
    lobby.activeScenario.game.doors[SV_MAP_TYPE] = {}
    for doorIndex, door in pairs(config.doors[SV_MAP_TYPE]) do
        lobby.activeScenario.game.doors[SV_MAP_TYPE][doorIndex] = {
            unlocked = false,
            method = door.unlockMethod,
        }
    end

    -- Initialize ATM groups
    lobby.activeScenario.game.robbableAtmGroups = {}
    lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE] = {}
    for groupIndex, group in pairs(config.robbableAtmGroups[SV_MAP_TYPE] or {}) do
        lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex] = {
            robbed = false,
            markerCoords = group.markerCoords,
            atmCoords = {},
        }
        for atmIndex, atm in pairs(group.atmCoords) do
            lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex].atmCoords[atmIndex] = {
                model = atm.model,
                coords = atm.coords,
                collectors = {},
            }
        end
    end

    -- Initialize trolley groups
    lobby.activeScenario.game.cashTrolleyGroups = {}
    lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE] = {}
    for trolleyIndex, trolley in pairs(config.cashTrolleyGroups[SV_MAP_TYPE] or {}) do
        lobby.activeScenario.game.cashTrolleyGroups[SV_MAP_TYPE][trolleyIndex] = {
            busy = false,
            collected = false,
            ingot = trolley.ingot or false,
        }
    end

    lobby.activeScenario.game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.guards[SV_MAP_TYPE],
    })

    return { success = true }
end

---@section EVENT HANDLERS - BOMB DROP

lib.callback.register(_e("server:scenarios:pacific_bank_robbery:onBombDropped"), function(source, params)
    local lobbyId = params.lobbyId
    local zoneIndex = params.zoneIndex
    local coords = params.coords

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end

    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end

    if not lobby.activeScenario.game.bombDropOptions then return false end
    if lobby.activeScenario.game.bombDropOptions.allDropped then return false end
    if not lobby.activeScenario.game.bombDropOptions.locations then return false end
    if not lobby.activeScenario.game.bombDropOptions.locations.dropZones then return false end
    if not lobby.activeScenario.game.bombDropOptions.locations.dropZones[zoneIndex] then return false end
    if lobby.activeScenario.game.bombDropOptions.locations.dropZones[zoneIndex].dropped then return false end

    lobby.activeScenario.game.bombDropOptions.locations.dropZones[zoneIndex].dropped = true

    local requiredDrops = #lobby.activeScenario.game.bombDropOptions.locations.dropZones
    local currentDrops = 0
    local allDropped = false
    for _, dropZone in pairs(lobby.activeScenario.game.bombDropOptions.locations.dropZones) do
        if dropZone.dropped then
            currentDrops = currentDrops + 1
        end
    end

    if currentDrops >= requiredDrops then
        allDropped = true
        lobby.activeScenario.game.bombDropOptions.allDropped = true
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onBombDropped"), member.source, {
            lobbyId = lobbyId,
            zoneIndex = zoneIndex,
            coords = coords,
            droppedCount = currentDrops,
            totalDrops = requiredDrops,
        })
    end

    if allDropped then
        lobby.activeScenario.game.doors = DoorManagerServer.new({
            lobbyId = lobbyId,
            doors = config.doors[SV_MAP_TYPE],
        })
        lobby.activeScenario.game.trolleys = TrolleyManagerServer.new({
            lobbyId = lobbyId,
            trolleys = config.cashTrolleyGroups[SV_MAP_TYPE] or {},
        })

        TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onAllBombsDropped"), -1, {
            lobbyId = lobbyId,
            droneDriver = source,
        })
    end

    return true
end)

---@section EVENT HANDLERS - DOORS

RegisterNetEvent(_e("server:scenarios:pacific_bank_robbery:onBombPlantOnDoor"), function(params)
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

    TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onDoorUnlockedWithBomb"), -1, {
        lobbyId = lobbyId,
        doorId = doorId,
        bombRot = bombRot,
        unlocked = true
    })
end)

RegisterNetEvent(_e("server:scenarios:pacific_bank_robbery:onDoorUnlocked"), function(params)
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

    TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onDoorUnlocked"), -1, {
        lobbyId = lobbyId,
        doorId = doorId,
        unlockType = unlockType,
        unlocked = true
    })
end)

---@section EVENT HANDLERS - ATM ROBBERY

RegisterNetEvent(_e("server:scenarios:pacific_bank_robbery:onAtmHacked"), function(params)
    local lobbyId = params.lobbyId
    local groupIndex = params.groupIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end

    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.robbableAtmGroups then return end
    if not lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE] then return end
    if not lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex] then return end
    if lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex].robbed then return end

    lobby.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex].robbed = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onAtmHacked"), member.source, {
            lobbyId = lobbyId,
            groupIndex = groupIndex,
            robbed = true
        })
    end
end)

lib.callback.register(_e("server:scenarios:pacific_bank_robbery:onScatteredLootCollected"), function(source, params)
    local lobbyId = params.lobbyId
    local groupIndex = params.groupIndex
    local atmIndex = params.atmIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return { success = false } end
    if not lobby.activeScenario then return { success = false } end
    if lobby.activeScenario.key ~= scenarioKey then return { success = false } end
    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return { success = false } end

    local robbableAtmGroups = lobby.activeScenario.game.robbableAtmGroups

    if not robbableAtmGroups then
        return { success = false }
    end
    if not robbableAtmGroups[SV_MAP_TYPE] then
        return { success = false }
    end
    if not robbableAtmGroups[SV_MAP_TYPE][groupIndex] then
        return { success = false }
    end

    local atmCoords = robbableAtmGroups[SV_MAP_TYPE][groupIndex].atmCoords

    if not atmCoords then
        return { success = false }
    end
    if not atmCoords[atmIndex] then
        return { success = false }
    end

    local selectedAtmCoords = atmCoords[atmIndex]
    selectedAtmCoords.collectors = selectedAtmCoords.collectors or {}

    if selectedAtmCoords.collectors[source] then
        return { success = false, message = locale("pacific_bank_robbery.loot_already_collected") }
    end

    selectedAtmCoords.collectors[source] = true

    local rewards = config.atmRobberyRewards
    if rewards then
        local reward = Utils.selectRandomRewards(rewards)
        for _, item in pairs(reward) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    return { success = true }
end)

---@section EVENT HANDLERS - TROLLEYS

lib.callback.register(_e("server:scenarios:pacific_bank_robbery:isTrolleyBusy"), function(source, params)
    local lobbyId = params.lobbyId
    local trolleyIndex = params.trolleyIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return true end

    if not lobby.activeScenario then return true end
    if lobby.activeScenario.key ~= scenarioKey then return true end
    if not lobby.activeScenario.game.trolleys then return true end

    return not lobby.activeScenario.game.trolleys:markBusy(trolleyIndex)
end)

RegisterNetEvent(_e("server:scenarios:pacific_bank_robbery:onTrolleyCollected"), function(params)
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

    -- Give rewards to the collector only
    local selectedRewards = Utils.selectRandomRewards(config.trolleyRobberyRewards[trolleyType] or {})
    for _, reward in pairs(selectedRewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onTrolleyCollected"), member.source, {
            lobbyId = lobbyId,
            trolleyIndex = trolleyIndex,
            collected = true
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:pacific_bank_robbery:onGuardsSpawned"), function(params)
    local lobbyId = params.lobbyId
    local guardNetIds = params.guardNetIds
    local ownerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end

    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end

    lobby.activeScenario.game.guards:registerSpawnedGuards(guardNetIds, ownerId)

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:pacific_bank_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)
