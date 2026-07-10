local lib                = lib
local Utils              = require("modules.utils.server")

local config             = require("config.scenarios.yacht_robbery")

local GuardManagerServer = require("core.scenarios._shared.server.guards")
local Inventory          = require "modules.inventory.server"

YachtRobberyServer       = {}

local scenarioKey        = "yacht_robbery"

function YachtRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = "invalid_lobby_or_scenario" }
    end

    lobby.activeScenario.game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.guards,
    })

    lobby.activeScenario.game.loots = lib.table.deepclone(config.loots)

    return { success = true }
end

function YachtRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    local netIdsToDelete = {}

    if activeScenario.game then
        if activeScenario.game.guards then
            local guardNetIds = activeScenario.game.guards:getNetIdsForCleanup()
            for _, netId in pairs(guardNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end
    end

    if #netIdsToDelete > 0 then
        Utils.deleteNetworkedObjects(netIdsToDelete)
    end
end

RegisterNetEvent(_e("server:scenarios:yacht_robbery:onGuardsSpawned"), function(params)
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
        TriggerClientEvent(_e("client:scenarios:yacht_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)

lib.callback.register(_e("server:scenarios:yacht_robbery:loot"), function(source, params)
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
            return { success = false, message = locale("yacht_robbery.no_reward_items_found", loot.rewardKey) }
        end

        local selectedRewards = Utils.selectRandomRewards(rewardItemsConfig)
        for _, item in pairs(selectedRewards) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    lobby.activeScenario.game.loots[lootIndex].looted = true
    lobby.activeScenario.game.loots[lootIndex].busy = false

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:yacht_robbery:onLootUpdated"), member.source, {
            lobbyId = lobbyId,
            lootIndex = lootIndex,
            looted = true,
        })
    end

    return { success = true }
end)
