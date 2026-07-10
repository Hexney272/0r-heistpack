local lib                = lib
local Utils              = require("modules.utils.server")
local Inventory          = require("modules.inventory.server")
local GuardManagerServer = require("core.scenarios._shared.server.guards")

local config             = lib.load("config.scenarios.truck_robbery")

TruckRobberyServer       = {}

local scenarioKey        = "truck_robbery"
local activeLocations    = {}

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

function TruckRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    local netIds = {}

    if activeScenario.game then
        -- Delete vehicles, container, and guards if exists
        if activeScenario.game.vehicleNetIds then
            for _, vehicleNetId in pairs(activeScenario.game.vehicleNetIds) do
                table.insert(netIds, vehicleNetId)
            end
        end

        -- Çoklu konteyner desteği
        if activeScenario.game.containerNetIds then
            for _, containerNetId in pairs(activeScenario.game.containerNetIds) do
                table.insert(netIds, containerNetId)
            end
        end

        if activeScenario.game.guardNetIds then
            for _, guardNetId in pairs(activeScenario.game.guardNetIds) do
                table.insert(netIds, guardNetId)
            end
        end
    end

    Utils.deleteNetworkedObjects(netIds)
end

function TruckRobberyServer.init(lobbyId)
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
    game.containerNetIds = {}
    game.containersLoadedCount = 0
    game.currentContainerIndex = 1

    game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.locations[locationIndex].guards,
    })

    return { success = true }
end

lib.callback.register(_e("server:scenarios:truck_robbery:onTruckSpawned"), function(source, params)
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
            TriggerClientEvent(_e("client:scenarios:truck_robbery:onVehicleSpawned"), member.source, {
                lobbyId = lobbyId,
                vehicleType = vehicleType,
                vehicleNetId = vehicleNetIds[vehicleType],
            })
        end
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:truck_robbery:onForkliftSpawned"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or not lobby.activeScenario then
        return { success = false }
    end

    if not lobby.activeScenario.game.vehicleNetIds then
        lobby.activeScenario.game.vehicleNetIds = {}
    end

    lobby.activeScenario.game.vehicleNetIds.forklift = params.vehicleNetId

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:truck_robbery:onVehicleSpawned"), member.source, {
            lobbyId = lobbyId,
            vehicleType = "forklift",
            vehicleNetId = params.vehicleNetId,
        })
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:truck_robbery:onContainerSpawned"), function(source, params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex or 1
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or not lobby.activeScenario then
        return { success = false }
    end

    -- Çoklu konteyner desteği
    if not lobby.activeScenario.game.containerNetIds then
        lobby.activeScenario.game.containerNetIds = {}
    end

    lobby.activeScenario.game.containerNetIds[containerIndex] = params.containerNetId

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:truck_robbery:onContainerSpawned"), member.source, {
            lobbyId = lobbyId,
            containerNetId = params.containerNetId,
            containerIndex = containerIndex,
        })
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:truck_robbery:onAttachContainerToForklift"), function(params)
    local lobbyId = params.lobbyId
    local source = source
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        not lobby.activeScenario.game.vehicleNetIds or
        not lobby.activeScenario.game.vehicleNetIds.forklift
    then
        return
    end

    -- Mevcut konteyner indeksini al
    local currentIndex = lobby.activeScenario.game.currentContainerIndex or 1
    local currentContainerNetId = lobby.activeScenario.game.containerNetIds and
        lobby.activeScenario.game.containerNetIds[currentIndex]

    if not currentContainerNetId then
        return
    end

    local forkliftNetId = lobby.activeScenario.game.vehicleNetIds.forklift
    local containerEntity = NetworkGetEntityFromNetworkId(currentContainerNetId)
    local forkliftEntity = NetworkGetEntityFromNetworkId(forkliftNetId)

    if not DoesEntityExist(containerEntity) or not DoesEntityExist(forkliftEntity) then
        return
    end

    local forkliftOwner = NetworkGetEntityOwner(forkliftEntity)
    Utils.deleteNetworkedObjects({ currentContainerNetId })

    local newContainerNetId = lib.callback.await(_e("client:scenarios:truck_robbery:spawnContainerOnForklift"),
        forkliftOwner,
        { forkliftNetId = forkliftNetId })

    if newContainerNetId then
        -- Yeni konteyner NetID'sini güncelle
        lobby.activeScenario.game.containerNetIds[currentIndex] = newContainerNetId

        for _, member in pairs(lobby.members) do
            TriggerClientEvent(_e("client:scenarios:truck_robbery:onContainerSpawned"), member.source, {
                lobbyId = lobbyId,
                containerNetId = newContainerNetId,
                containerIndex = currentIndex,
            })
        end
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:truck_robbery:onContainerAttachedToForklift"), member.source,
            {
                lobbyId = lobbyId,
                containerIndex = currentIndex
            })
    end
end)

RegisterNetEvent(_e("server:scenarios:truck_robbery:onAttachContainerToTrailer"), function(params)
    local lobbyId = params.lobbyId
    local source = source
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        not lobby.activeScenario.game.vehicleNetIds or
        not lobby.activeScenario.game.vehicleNetIds.trailer
    then
        return
    end

    -- Mevcut konteyner indeksini al
    local currentIndex = lobby.activeScenario.game.currentContainerIndex or 1
    local currentContainerNetId = lobby.activeScenario.game.containerNetIds and
        lobby.activeScenario.game.containerNetIds[currentIndex]

    if not currentContainerNetId then
        return
    end

    local trailerNetId = lobby.activeScenario.game.vehicleNetIds.trailer
    local containerEntity = NetworkGetEntityFromNetworkId(currentContainerNetId)
    local trailerEntity = NetworkGetEntityFromNetworkId(trailerNetId)
    if not DoesEntityExist(containerEntity) or not DoesEntityExist(trailerEntity) then
        return
    end

    local trailerOwner = NetworkGetEntityOwner(trailerEntity)
    Utils.deleteNetworkedObjects({ currentContainerNetId })

    local newContainerNetId = lib.callback.await(_e("client:scenarios:truck_robbery:spawnContainerOnTrailer"),
        trailerOwner,
        { trailerNetId = trailerNetId })

    if newContainerNetId then
        -- Yeni konteyner NetID'sini güncelle
        lobby.activeScenario.game.containerNetIds[currentIndex] = newContainerNetId

        -- Yüklenen konteyner sayısını artır
        lobby.activeScenario.game.containersLoadedCount = (lobby.activeScenario.game.containersLoadedCount or 0) + 1

        -- Sonraki konteyner indeksine geç
        lobby.activeScenario.game.currentContainerIndex = currentIndex + 1
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:truck_robbery:onContainerAttachedToTrailer"), member.source,
            {
                lobbyId = lobbyId,
                containerIndex = currentIndex,
                containersLoadedCount = lobby.activeScenario.game.containersLoadedCount,
                currentContainerIndex = lobby.activeScenario.game.currentContainerIndex,
                allContainersLoaded =
                    lobby.activeScenario.game.containersLoadedCount >=
                    #config.attachContainerToTrailerOffset,
            })
    end
end)

RegisterNetEvent(_e("server:scenarios:truck_robbery:onGuardsSpawned"), function(params)
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
        TriggerClientEvent(_e("client:scenarios:truck_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)
