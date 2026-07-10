local lib                = lib
local Utils              = require("modules.utils.server")

local config             = require("config.scenarios.cargo_ship_robbery")

local GuardManagerServer = require("core.scenarios._shared.server.guards")
local Inventory          = require "modules.inventory.server"
local Framework          = require "modules.framework.init"

CargoShipRobberyServer   = {}

local scenarioKey        = "cargo_ship_robbery"
local state              = {
    areItemsRegistered = false,
}

local function onScenarioItemUsed(source, itemName)
    if itemName == config.anchorItemName then
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onAnchorUsed"), source)
    end
end

function CargoShipRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = "invalid_lobby_or_scenario" }
    end

    lobby.activeScenario.game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.guards,
    })

    lobby.activeScenario.game.boatNetIds = {}
    lobby.activeScenario.game.helicopterNetId = nil
    lobby.activeScenario.game.isHeliKeyTaken = false
    lobby.activeScenario.game.bigContainers = {} -- {netId, delivered}

    return { success = true }
end

function CargoShipRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    local netIdsToDelete = {}

    if activeScenario.game then
        if activeScenario.game.boatNetIds then
            for _, netId in pairs(activeScenario.game.boatNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end
        if activeScenario.game.guards then
            local guardNetIds = activeScenario.game.guards:getNetIdsForCleanup()
            for _, netId in pairs(guardNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end
        if activeScenario.game.helicopterNetId then
            table.insert(netIdsToDelete, activeScenario.game.helicopterNetId)
        end
        if activeScenario.game.bigContainers then
            for _, containerData in pairs(activeScenario.game.bigContainers) do
                if containerData.netId then
                    table.insert(netIdsToDelete, containerData.netId)
                end
            end
        end
        -- Eski containerNetId support
        if activeScenario.game.containerNetId then
            table.insert(netIdsToDelete, activeScenario.game.containerNetId)
        end
    end

    if #netIdsToDelete > 0 then
        Utils.deleteNetworkedObjects(netIdsToDelete)
    end
end

function CargoShipRobberyServer.registerScenarioItems()
    if state.areItemsRegistered then
        return
    end

    local anchorItemName = config.anchorItemName

    Framework.createUseableItem(anchorItemName, function(source)
        onScenarioItemUsed(source, anchorItemName)
    end)

    state.areItemsRegistered = true
end

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:onBoatSpawned"), function(params)
    local lobbyId = params.lobbyId
    local boatNetId = params.boatNetId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not boatNetId
    then
        return
    end

    table.insert(lobby.activeScenario.game.boatNetIds, boatNetId)

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onBoatSpawned"), member.source, {
            lobbyId = lobbyId,
            boatNetId = boatNetId,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:onGuardsSpawned"), function(params)
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
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:onHelicopterSpawned"), function(params)
    local lobbyId = params.lobbyId
    local helicopterNetId = params.helicopterNetId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not helicopterNetId
    then
        return
    end

    lobby.activeScenario.game.helicopterNetId = helicopterNetId

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onHelicopterSpawned"), member.source, {
            lobbyId = lobbyId,
            helicopterNetId = helicopterNetId,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:onHeliKeyPickedUp"), function(params)
    local lobbyId = params.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.activeScenario.game.isHeliKeyTaken
    then
        return
    end

    lobby.activeScenario.game.isHeliKeyTaken = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onHeliKeyPickedUp"), member.source, {
            lobbyId = lobbyId,
        })
    end
end)

lib.callback.register(_e("server:scenarios:cargo_ship_robbery:loot"), function(source, params)
    local lobbyId = params.lobbyId
    local lootIndex = params.lootIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby then return { success = false, message = locale("lobby.not_found") } end
    if not lobby.activeScenario then return { success = false, message = locale("lobby.not_found") } end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return { success = false, message = locale("lobby.player_not_found") } end

    ---@type LootPoint
    local loot = lobby.activeScenario.game.loots[lootIndex]
    if not loot then return { success = false } end

    if loot.looted then
        return { success = false, message = locale("loot_already_looted") }
    end

    -- Give rewards
    if loot.rewardKey then
        local rewardItemsConfig = config.lootRewardItems[loot.rewardKey]
        if not rewardItemsConfig then
            return { success = false, message = locale("cargo_ship_robbery.no_reward_items_found", loot.rewardKey) }
        end

        local selectedRewards = Utils.selectRandomRewards(rewardItemsConfig)
        for _, item in pairs(selectedRewards) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    lobby.activeScenario.game.loots[lootIndex].looted = true
    lobby.activeScenario.game.loots[lootIndex].busy = false

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onLootUpdated"), member.source, {
            lobbyId = lobbyId,
            lootIndex = lootIndex,
            looted = true,
        })
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:onBigContainerSpawned"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local containerNetId = params.containerNetId
    local targetCoords = params.targetCoords

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not containerNetId or
        not containerIndex
    then
        return
    end

    lobby.activeScenario.game.bigContainers[containerIndex] = {
        netId = containerNetId,
        delivered = false
    }

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onBigContainerSpawned"), member.source, {
            lobbyId = lobbyId,
            containerIndex = containerIndex,
            containerNetId = containerNetId,
            targetCoords = targetCoords,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:attachBigContainer"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not containerIndex
    then
        return
    end

    local containerData = lobby.activeScenario.game.bigContainers[containerIndex]
    if not containerData then return end

    local containerNetId = containerData.netId
    Utils.deleteNetworkedObjects({ containerNetId })

    local helicopterNetId = lobby.activeScenario.game.helicopterNetId
    local helicopterOwner = NetworkGetEntityOwner(NetworkGetEntityFromNetworkId(helicopterNetId))

    local newContainerNetId = lib.callback.await(
        _e("client:scenarios:cargo_ship_robbery:attachBigContainerToHelicopter"),
        helicopterOwner, {
            lobbyId = lobbyId,
            helicopterNetId = helicopterNetId,
            containerIndex = containerIndex,
        })

    if newContainerNetId then
        lobby.activeScenario.game.bigContainers[containerIndex].netId = newContainerNetId
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onBigContainerAttached"), member.source, {
            lobbyId = lobbyId,
            containerIndex = containerIndex,
            containerNetId = newContainerNetId,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:cargo_ship_robbery:detachBigContainer"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not containerIndex
    then
        return
    end

    local containerData = lobby.activeScenario.game.bigContainers[containerIndex]
    if not containerData then return end

    local containerNetId = containerData.netId
    local containerOwner = NetworkGetEntityOwner(NetworkGetEntityFromNetworkId(containerNetId))

    TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:detachBigContainerFromHelicopter"), containerOwner, {
        lobbyId = lobbyId,
        containerIndex = containerIndex,
        containerNetId = containerNetId,
    })

    -- Container'ı teslim edilmiş olarak işaretle
    lobby.activeScenario.game.bigContainers[containerIndex].delivered = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:cargo_ship_robbery:onBigContainerDetached"), member.source, {
            lobbyId = lobbyId,
            containerIndex = containerIndex,
        })
    end
end)
