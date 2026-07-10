local lib         = lib
local Utils       = require("modules.utils.server")
local Inventory   = require("modules.inventory.server")

local config      = lib.load("config.scenarios.atm_robbery")

AtmRobberyServer  = {}

local scenarioKey = "atm_robbery"

function AtmRobberyServer.clear(activeScenario, lobbyId)
    local fakeAtmObjectNetId = activeScenario.game.robbery.fakeAtmObjectNetId
    if fakeAtmObjectNetId then
        Utils.deleteNetworkedObjects(fakeAtmObjectNetId)
    end

    TriggerClientEvent(_e("client:scenarios:atm_robbery:deleteAllLobbyRopes"), -1, {
        lobbyId = lobbyId,
    })
end

function AtmRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return { success = false } end

    lobby.activeScenario.game.robbery = {
        busy = false,
        completed = false,
    }

    return { success = true }
end

lib.callback.register(_e("server:scenarios:atm_robbery:onAtmHacked"), function(source, params)
    local lobbyId = params.lobbyId
    local atm = params.atm

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source)
    then
        return { success = false }
    end

    if lobby.activeScenario.game.robbery.completed then
        return { success = false, message = locale("atm_robbery.already_hacked") }
    end

    lobby.activeScenario.game.robbery.completed = true
    lobby.activeScenario.game.robbery.atm = atm

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:atm_robbery:onAtmHacked"), member.source, {
            atm = atm,
            owner = source,
        })
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:atm_robbery:onScatteredLootCollected"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source) or
        not lobby.activeScenario.game.robbery or
        not lobby.activeScenario.game.robbery.atm
    then
        return { success = false }
    end

    if not lobby.activeScenario.game.robbery.completed then
        return { success = false, message = locale("atm_robbery.atm_not_robbed_yet") }
    end

    lobby.activeScenario.game.robbery.collectors = lobby.activeScenario.game.robbery.collectors or {}

    if lobby.activeScenario.game.robbery.collectors[source] then
        return { success = false, message = locale("atm_robbery.loot_already_collected") }
    end

    local interactionName = lobby.activeScenario.game.robbery.atm.interactionName

    lobby.activeScenario.game.robbery.collectors[source] = true

    local rewardKey = interactionName .. "Options"
    local rewards = config[rewardKey] and config[rewardKey].rewards
    if rewards then
        local reward = Utils.selectRandomRewards(rewards)
        for _, item in pairs(reward) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:atm_robbery:onScatteredLootCollected"), member.source, {
            collector = source,
            lobbyId = lobbyId,
            centerCoords = params.centerCoords,
        })
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:atm_robbery:isAtmAvailable"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source) or
        not lobby.activeScenario.game.robbery or
        lobby.activeScenario.game.robbery.completed or
        lobby.activeScenario.game.robbery.busy
    then
        return false
    end

    local robbery = lobby.activeScenario.game.robbery

    robbery.busy = true
    robbery.busyBy = source

    return true
end)

RegisterNetEvent(_e("server:scenarios:atm_robbery:onRopeFromAtm"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local playerPedNetId = params.playerPedNetId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source) or
        not lobby.activeScenario.game.robbery or
        lobby.activeScenario.game.robbery.completed or
        not lobby.activeScenario.game.robbery.busy or
        lobby.activeScenario.game.robbery.busyBy ~= source
    then
        return
    end

    local robbery = lobby.activeScenario.game.robbery

    robbery.fakeAtmObjectNetId = params.fakeAtmObjectNetId
    robbery.atm = params.atm

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:atm_robbery:onFakeAtmCreated"), member.source,
            { fakeAtmObjectNetId = params.fakeAtmObjectNetId }
        )
    end

    TriggerClientEvent(_e("client:scenarios:atm_robbery:attachRopeToPedHand"), -1, {
        playerPedNetId = playerPedNetId,
        fakeAtmObjectNetId = params.fakeAtmObjectNetId,
        owner = source,
        lobbyId = lobbyId,
    })
end)

RegisterNetEvent(_e("server:scenarios:atm_robbery:attachRopeToVehicle"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local playerPedNetId = params.playerPedNetId
    local vehicleNetId = params.vehicleNetId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source) or
        not lobby.activeScenario.game.robbery or
        lobby.activeScenario.game.robbery.completed or
        not lobby.activeScenario.game.robbery.busy or
        lobby.activeScenario.game.robbery.busyBy ~= source
    then
        return
    end

    local robbery = lobby.activeScenario.game.robbery

    TriggerClientEvent(_e("client:scenarios:atm_robbery:attachRopeToVehicle"), -1, {
        vehicleNetId = vehicleNetId,
        fakeAtmObjectNetId = robbery.fakeAtmObjectNetId,
        owner = source,
        lobbyId = lobbyId,
    })

    Citizen.SetTimeout(10000, function()
        robbery.busy = false
        robbery.busyBy = nil
        robbery.completed = true

        local fakeAtmObject = NetworkGetEntityFromNetworkId(robbery.fakeAtmObjectNetId)
        if DoesEntityExist(fakeAtmObject) then
            local entityOwner = NetworkGetEntityOwner(fakeAtmObject)
            TriggerClientEvent(_e("client:scenarios:atm_robbery:setVisibleFakeAtm"), entityOwner, {
                fakeAtmObjectNetId = robbery.fakeAtmObjectNetId,
            })
        end

        TriggerClientEvent(_e("client:scenarios:atm_robbery:onAtmRipped"), -1, {
            lobbyId = lobbyId,
            model = robbery.atm.model,
            coords = robbery.atm.coords,
        })
    end)
end)

RegisterNetEvent(_e("server:scenarios:atm_robbery:deleteLobbyRope"), function(params)
    local source = source
    local lobbyId = params.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source)
    then
        return
    end

    TriggerClientEvent(_e("client:scenarios:atm_robbery:deleteAllLobbyRopes"), -1, {
        lobbyId = lobbyId,
    })
end)

lib.callback.register(_e("server:scenarios:atm_robbery:onBombPlanted"), function(source, params)
    local lobbyId = params.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source) or
        not lobby.activeScenario.game.robbery or
        lobby.activeScenario.game.robbery.completed or
        not lobby.activeScenario.game.robbery.busy or
        lobby.activeScenario.game.robbery.busyBy ~= source
    then
        return { success = false }
    end

    local robbery = lobby.activeScenario.game.robbery

    robbery.busy = false
    robbery.busyBy = nil
    robbery.completed = true
    robbery.atm = params.atm

    TriggerClientEvent(_e("client:scenarios:atm_robbery:onBombPlanted"), -1, {
        lobbyId = lobbyId,
        bombCoords = params.bombCoords,
        bombRot = params.bombRot,
        owner = source,
        atm = params.atm,
    })

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:atm_robbery:onAtmDrilled"), function(source, params)
    local lobbyId = params.lobbyId
    local atm = params.atm

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not LobbyServer:isPlayerInLobby(lobbyId, source) or
        not lobby.activeScenario.game.robbery or
        lobby.activeScenario.game.robbery.completed or
        not lobby.activeScenario.game.robbery.busy or
        lobby.activeScenario.game.robbery.busyBy ~= source
    then
        return { success = false }
    end

    local robbery = lobby.activeScenario.game.robbery

    robbery.busy = false
    robbery.busyBy = nil
    robbery.completed = true
    robbery.atm = atm

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:atm_robbery:onAtmDrilled"), member.source, {
            atm = atm,
            owner = source,
        })
    end

    return { success = true }
end)
