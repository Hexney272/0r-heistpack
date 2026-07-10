local lib                 = lib
local Utils               = require("modules.utils.server")
local Inventory           = require("modules.inventory.server")
local GuardManagerServer = require("core.scenarios._shared.server.guards")

local config              = lib.load("config.scenarios.vehicle_theft_robbery")

VehicleTheftRobberyServer = {}

local scenarioKey         = "vehicle_theft_robbery"
local activeLocations     = {}

---@section Private Functions

local function findAvailableLocation()
    local availableLocations = {}
    for locationIndex in pairs(config.locations) do
        if not activeLocations[locationIndex] then
            table.insert(availableLocations, locationIndex)
        end
    end

    if #availableLocations == 0 then
        return nil
    end

    math.randomseed(os.time())

    local randomIndex = math.random(#availableLocations)
    local selectedLocationIndex = availableLocations[randomIndex]

    activeLocations[selectedLocationIndex] = true

    return selectedLocationIndex
end

---@section Public Functions

function VehicleTheftRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    local netIdsToDelete = {}

    if activeScenario.game then
        if activeScenario.game.vehicleNetIds then
            for _, vehicleNetId in pairs(activeScenario.game.vehicleNetIds) do
                table.insert(netIdsToDelete, vehicleNetId)
            end
        end

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

function VehicleTheftRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    local locationIndex = findAvailableLocation()
    if not locationIndex then
        return { success = false, message = locale("no_available_location") }
    end

    local game = lobby.activeScenario.game or {}

    game.locationIndex = locationIndex
    game.location = config.locations[locationIndex]

    game.vehicleNetIds = {}

    game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.locations[locationIndex].guards,
    })

    return { success = true }
end

lib.callback.register(_e("server:scenarios:vehicle_theft_robbery:onTruckSpawned"), function(source, params)
    local vehicleNetIds = params.vehicleNetIds
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or not lobby.activeScenario then
        return { success = false }
    end

    if not lobby.activeScenario.game.vehicleNetIds then
        lobby.activeScenario.game.vehicleNetIds = {}
    end

    lobby.activeScenario.game.vehicleNetIds.truck = vehicleNetIds.truck
    lobby.activeScenario.game.vehicleNetIds.trailer = vehicleNetIds.trailer

    for _, member in pairs(lobby.members) do
        for _, vehicleType in pairs({ "truck", "trailer" }) do
            TriggerClientEvent(_e("client:scenarios:vehicle_theft_robbery:onVehicleSpawned"), member.source, {
                lobbyId = lobbyId,
                vehicleType = vehicleType,
                vehicleNetId = vehicleNetIds[vehicleType],
            })
        end
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:vehicle_theft_robbery:onVehicleSpawned"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or not lobby.activeScenario then
        return { success = false }
    end

    if not lobby.activeScenario.game.vehicleNetIds then
        lobby.activeScenario.game.vehicleNetIds = {}
    end

    lobby.activeScenario.game.vehicleNetIds[params.vehicleType] = params.vehicleNetId

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vehicle_theft_robbery:onVehicleSpawned"), member.source, {
            lobbyId = lobbyId,
            vehicleType = params.vehicleType,
            vehicleNetId = params.vehicleNetId,
        })
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:vehicle_theft_robbery:onGuardsSpawned"), function(params)
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
        TriggerClientEvent(_e("client:scenarios:vehicle_theft_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:vehicle_theft_robbery:toggleTrailerDoor"), function(data)
    local trailerNetId = data.trailerNetId
    local doorIndex = data.doorIndex or 5
    if not trailerNetId then return end

    -- Entity owner'ı bul
    local owner = NetworkGetEntityOwner(NetworkGetEntityFromNetworkId(trailerNetId))
    if not owner then return end

    -- Kapı aç/kapat ve kilitle komutunu owner'a gönder
    TriggerClientEvent(_e("client:scenarios:vehicle_theft_robbery:toggleTrailerDoor"), owner, {
        trailerNetId = trailerNetId,
        doorIndex = doorIndex
    })
end)
