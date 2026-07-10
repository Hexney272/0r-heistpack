local lib                = lib
local Utils              = require("modules.utils.server")
local Inventory          = require("modules.inventory.server")
local GuardManagerServer = require("core.scenarios._shared.server.guards")

local Framework          = require "modules.framework.init"

local config             = lib.load("config.scenarios.train_robbery")

TrainRobberyServer       = {}

local scenarioKey        = "train_robbery"

function TrainRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    local netIdsToDelete = {}

    if activeScenario.game then
        if activeScenario.game.guards then
            local guardNetIds = activeScenario.game.guards:getNetIdsForCleanup()
            for _, netId in pairs(guardNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end

        if activeScenario.game.trainNetId then
            table.insert(netIdsToDelete, activeScenario.game.trainNetId)
        end

        if activeScenario.game.freightCarNetIds then
            for _, netId in pairs(activeScenario.game.freightCarNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end

        if activeScenario.game.containerNetIds then
            for _, netId in pairs(activeScenario.game.containerNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end

        if activeScenario.game.crateNetIds then
            for _, crateNetId in pairs(activeScenario.game.crateNetIds) do
                if crateNetId then
                    table.insert(netIdsToDelete, crateNetId)
                end
            end
        end
    end

    if #netIdsToDelete > 0 then
        Utils.deleteNetworkedObjects(netIdsToDelete)
    end
end

function TrainRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    local randomLocationIndex = math.random(1, #config.locations)

    local location = lib.table.deepclone(config.locations[randomLocationIndex])

    lobby.activeScenario.game.locationIndex = randomLocationIndex
    lobby.activeScenario.game.location = location
    lobby.activeScenario.game.trainNetId = nil
    lobby.activeScenario.game.freightCarNetIds = {}
    lobby.activeScenario.game.containerNetIds = {}
    lobby.activeScenario.game.crateNetIds = {}

    lobby.activeScenario.game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = location.guards,
    })

    return { success = true }
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("server:scenarios:train_robbery:onGuardsSpawned"), function(params)
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
        TriggerClientEvent(_e("client:scenarios:train_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:onTrainSpawned"), function(params)
    local lobbyId = params.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey
    then
        return
    end

    lobby.activeScenario.game.trainNetId = params.trainNetId
    lobby.activeScenario.game.freightCarNetIds = params.freightCarNetIds

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:train_robbery:onTrainSpawned"), member.source, {
            lobbyId = lobbyId,
            trainNetId = params.trainNetId,
            freightCarNetIds = params.freightCarNetIds,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:onContainersSpawned"), function(params)
    local lobbyId = params.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey
    then
        return
    end

    lobby.activeScenario.game.containerNetIds = params.containerObjectNetIds
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:onCrateSpawned"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local crateNetId = params.crateNetId
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey
    then
        return
    end

    lobby.activeScenario.game.crateNetIds[containerIndex] = crateNetId
end)

lib.callback.register(_e("server:scenarios:train_robbery:isContainerOpened"), function(source, params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location.containers[containerIndex] or
        lobby.activeScenario.game.location.containers[containerIndex].opened or
        lobby.activeScenario.game.location.containers[containerIndex].opening
    then
        return true
    end

    return false
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:setContainerOpening"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location.containers[containerIndex] or
        lobby.activeScenario.game.location.containers[containerIndex].opened or
        lobby.activeScenario.game.location.containers[containerIndex].opening
    then
        return
    end

    lobby.activeScenario.game.location.containers[containerIndex].opening = true
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:onContainerOpened"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location.containers[containerIndex] or
        lobby.activeScenario.game.location.containers[containerIndex].opened or
        not lobby.activeScenario.game.location.containers[containerIndex].opening
    then
        return
    end

    lobby.activeScenario.game.location.containers[containerIndex].opened = true
    lobby.activeScenario.game.location.containers[containerIndex].opening = nil

    TriggerClientEvent(_e("client:scenarios:train_robbery:onContainerOpened"), -1, {
        lobbyId = lobbyId,
        locationIndex = lobby.activeScenario.game.locationIndex,
        containerIndex = containerIndex,
        opened = true,
    })

    local containerNetId = lobby.activeScenario.game.containerNetIds[containerIndex]
    Utils.deleteNetworkedObjects({ containerNetId })
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:onCrateSpawned"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local crateNetId = params.crateNetId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location.containers[containerIndex] or
        not lobby.activeScenario.game.location.containers[containerIndex].opened
    then
        return
    end

    lobby.activeScenario.game.crateNetIds[containerIndex] = crateNetId
end)

RegisterNetEvent(_e("server:scenarios:train_robbery:lootContainer"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location.containers[containerIndex] or
        not lobby.activeScenario.game.location.containers[containerIndex].opened or
        lobby.activeScenario.game.location.containers[containerIndex].looted
    then
        return
    end

    lobby.activeScenario.game.location.containers[containerIndex].looted = true

    local crateNetId = lobby.activeScenario.game.crateNetIds[containerIndex]
    Utils.deleteNetworkedObjects({ crateNetId })

    local reward = config.rewardMoney
    local rewardAmount = math.random(reward.min, reward.max)

    if Config.moneyOptions.isItem then
        Inventory.giveItem(playerId, Config.moneyOptions.itemName, rewardAmount)
    else
        Framework.playerAddMoney(playerId, Config.moneyOptions.accountName, rewardAmount)
    end

    local allLooted = true
    for _, container in pairs(lobby.activeScenario.game.location.containers) do
        if not container.looted then
            allLooted = false
            break
        end
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:train_robbery:onContainerLooted"), member.source, {
            lobbyId = lobbyId,
            containerIndex = containerIndex,
            success = true,
            allLooted = allLooted,
        })
    end
end)
