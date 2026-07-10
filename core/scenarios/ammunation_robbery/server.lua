local lib                = lib
local Utils              = require("modules.utils.server")
local Inventory          = require("modules.inventory.server")
local GuardManagerServer = require("core.scenarios._shared.server.guards")

local config             = lib.load("config.scenarios.ammunation_robbery")

AmmunationRobberyServer  = {}

local scenarioKey        = "ammunation_robbery"

---@section PRIVATE FUNCTIONS

local function selectRandomContainers(totalCount, filledCount)
    -- Randomly select which containers are filled
    local containers = {}
    for i = 1, totalCount do
        containers[i] = false -- All empty by default
    end

    -- Randomly select filled containers
    local filled = {}
    while #filled < filledCount do
        local randomIndex = math.random(1, totalCount)
        if not containers[randomIndex] then
            containers[randomIndex] = true
            table.insert(filled, randomIndex)
        end
    end

    return containers
end

local function selectLocations()
    -- Select 1 real location and 3 fake locations
    local allLocations = {}
    for i = 1, #config.locations do
        table.insert(allLocations, i)
    end

    -- Shuffle and select
    local selected = {}

    -- Real location (first one)
    local realIndex = math.random(1, #allLocations)
    selected.realLocation = table.remove(allLocations, realIndex)

    -- Two fake locations
    selected.fakeLocations = {}
    for i = 1, 3 do
        if #allLocations > 0 then
            local fakeIndex = math.random(1, #allLocations)
            table.insert(selected.fakeLocations, table.remove(allLocations, fakeIndex))
        end
    end

    return selected
end

---@section PUBLIC FUNCTIONS

--- Cleanup scenario resources for a lobby
function AmmunationRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    local netIdsToDelete = {}

    if activeScenario.game then
        if activeScenario.game.guards then
            local guardNetIds = activeScenario.game.guards:getNetIdsForCleanup()
            for _, netId in pairs(guardNetIds) do
                table.insert(netIdsToDelete, netId)
            end
        end

        if activeScenario.game.containerObjects then
            for _, netId in pairs(activeScenario.game.containerObjects) do
                table.insert(netIdsToDelete, netId)
            end
        end

        if activeScenario.game.crateObjects then
            for _, crateData in pairs(activeScenario.game.crateObjects) do
                if crateData.crateNetId then
                    table.insert(netIdsToDelete, crateData.crateNetId)
                end
            end
        end
    end

    if #netIdsToDelete > 0 then
        Utils.deleteNetworkedObjects(netIdsToDelete)
    end
end

--- Initialize scenario for a lobby
function AmmunationRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = "invalid_lobby_or_scenario" }
    end

    -- Select locations (1 real, 2 fake)
    local selectedLocations = selectLocations()

    local filledContainers = selectRandomContainers(8, 2)

    -- Initialize game state
    lobby.activeScenario.game.realLocationIndex = selectedLocations.realLocation
    lobby.activeScenario.game.fakeLocationIndexes = selectedLocations.fakeLocations
    lobby.activeScenario.game.filledContainers = filledContainers
    lobby.activeScenario.game.openedContainers = {}
    lobby.activeScenario.game.openingContainers = {}
    lobby.activeScenario.game.crateObjects = {}

    lobby.activeScenario.game.guards = GuardManagerServer.new({
        lobbyId = lobbyId,
        guards = config.locations[selectedLocations.realLocation].guards,
    })

    return { success = true }
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("server:scenarios:ammunation_robbery:onGuardsSpawned"), function(params)
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
        TriggerClientEvent(_e("client:scenarios:ammunation_robbery:onGuardsSpawned"), member.source, {
            lobbyId = lobbyId,
            guardNetIds = guardNetIds,
        })
    end
end)

lib.callback.register(_e("server:scenarios:ammunation_robbery:isContainerOpened"), function(source, params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        lobby.activeScenario.game.openedContainers[containerIndex] or
        lobby.activeScenario.game.openingContainers[containerIndex]
    then
        return false
    end

    return lobby.activeScenario.game.openingContainers[containerIndex] == true
end)

RegisterNetEvent(_e("server:scenarios:ammunation_robbery:setContainerOpening"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        lobby.activeScenario.game.openingContainers[containerIndex]
    then
        return
    end

    lobby.activeScenario.game.openingContainers[containerIndex] = true
end)

RegisterNetEvent(_e("server:scenarios:ammunation_robbery:onContainerOpened"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        not lobby.activeScenario.game.openingContainers[containerIndex] or
        lobby.activeScenario.game.openedContainers[containerIndex]
    then
        return
    end

    lobby.activeScenario.game.openedContainers[containerIndex] = true
    lobby.activeScenario.game.openingContainers[containerIndex] = nil

    TriggerClientEvent(_e("client:scenarios:ammunation_robbery:onContainerOpened"), -1, {
        lobbyId = lobbyId,
        locationIndex = lobby.activeScenario.game.realLocationIndex,
        containerIndex = containerIndex,
        opened = true,
    })

    local containerNetId = lobby.activeScenario.game.containerObjects and
        lobby.activeScenario.game.containerObjects[containerIndex]
    if containerNetId then
        Utils.deleteNetworkedObjects({ containerNetId })
    end
end)

RegisterNetEvent(_e("server:scenarios:ammunation_robbery:onContainerObjectsSpawned"), function(params)
    local lobbyId = params.lobbyId
    local containerObjectNetIds = params.containerObjectNetIds
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey
    then
        return
    end

    lobby.activeScenario.game.containerObjects = containerObjectNetIds
end)

RegisterNetEvent(_e("server:scenarios:ammunation_robbery:onCrateSpawned"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local crateNetId = params.crateNetId
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        not lobby.activeScenario.game.crateObjects or
        lobby.activeScenario.game.crateObjects[containerIndex]
    then
        return
    end

    lobby.activeScenario.game.crateObjects[containerIndex] = { crateNetId = crateNetId, looted = false }
end)

RegisterNetEvent(_e("server:scenarios:ammunation_robbery:lootContainer"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game or
        not lobby.activeScenario.game.crateObjects or
        not lobby.activeScenario.game.crateObjects[containerIndex] or
        lobby.activeScenario.game.crateObjects[containerIndex].looted
    then
        return
    end

    local crateData = lobby.activeScenario.game.crateObjects[containerIndex]
    local hasLoot = lobby.activeScenario.game.filledContainers[containerIndex] or false

    if hasLoot then
        -- Give rewards to player
        local lootableRewards = config.lootableRewards or {}
        local selectedRewards = Utils.selectRandomRewards(lootableRewards)
        for _, reward in ipairs(selectedRewards) do
            Inventory.giveItem(playerId, reward.name, reward.count)
        end

        -- Mark as looted
        lobby.activeScenario.game.crateObjects[containerIndex].looted = true

        -- Delete the crate object
        if crateData.crateNetId then
            Utils.deleteNetworkedObjects({ crateData.crateNetId })
            crateData.crateNetId = nil
        end
        -- Check if all filled containers have been looted
        local allLooted = true
        for index, isFilled in pairs(lobby.activeScenario.game.filledContainers) do
            if isFilled then -- Bu konteyner dolu
                local crateObject = lobby.activeScenario.game.crateObjects[index]
                if not crateObject or not crateObject.looted then
                    allLooted = false
                    break
                end
            end
        end

        for _, member in pairs(lobby.members) do
            TriggerClientEvent(_e("client:scenarios:ammunation_robbery:onContainerLooted"), member.source, {
                lobbyId = lobbyId,
                containerIndex = containerIndex,
                success = true,
                allLooted = allLooted,
            })
        end
    else
        -- Notify client with failure (empty container)
        TriggerClientEvent(_e("client:scenarios:ammunation_robbery:onContainerLooted"), playerId, {
            lobbyId = lobbyId,
            containerIndex = containerIndex,
            success = false,
        })
    end
end)
