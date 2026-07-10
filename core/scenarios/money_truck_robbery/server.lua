local lib               = lib
local Utils             = require("modules.utils.server")
local Inventory         = require("modules.inventory.server")

local config            = lib.load("config.scenarios.money_truck_robbery")

MoneyTruckRobberyServer = {}

local scenarioKey       = "money_truck_robbery"
local activeLocations   = {} -- Track which locations are currently in use

---@section PRIVATE FUNCTIONS

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

---@section PUBLIC FUNCTIONS

--- Cleanup scenario resources for a lobby
function MoneyTruckRobberyServer.clear(activeScenario, lobbyId)
    if not activeScenario then return end

    if activeScenario.game then
        -- Delete truck, escort, and money objects if exists
        local netIdsToDelete = {}

        if activeScenario.game.truckNetId then
            table.insert(netIdsToDelete, activeScenario.game.truckNetId)
        end

        if activeScenario.game.escortNetId then
            table.insert(netIdsToDelete, activeScenario.game.escortNetId)
        end

        if activeScenario.game.moneyNetId then
            table.insert(netIdsToDelete, activeScenario.game.moneyNetId)
        end

        if activeScenario.game.guardNetIds then
            for _, guardNetId in pairs(activeScenario.game.guardNetIds) do
                table.insert(netIdsToDelete, guardNetId)
            end
        end

        if #netIdsToDelete > 0 then
            Utils.deleteNetworkedObjects(netIdsToDelete)
        end

        -- Release the location
        if activeScenario.game.locationIndex then
            activeLocations[activeScenario.game.locationIndex] = nil
        end
    end
end

--- Initialize scenario for a lobby
function MoneyTruckRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = "invalid_lobby_or_scenario" }
    end

    -- Find an available location
    local locationIndex = findAvailableLocation()
    if not locationIndex then
        return { success = false, message = locale("no_available_location") }
    end

    lobby.activeScenario.game.locationIndex = locationIndex
    lobby.activeScenario.game.location = lib.table.deepclone(config.locations[locationIndex])

    -- Reset location data
    lobby.activeScenario.game.truckNetId = nil
    lobby.activeScenario.game.escortNetId = nil
    lobby.activeScenario.game.truckOpened = false
    lobby.activeScenario.game.moneyCollected = false
    lobby.activeScenario.game.guardNetIds = guardNetIds

    return { success = true }
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("server:scenarios:money_truck_robbery:onTruckSpawned"), function(params)
    local lobbyId = params.lobbyId
    local truckNetId = params.truckNetId
    local escortNetId = params.escortNetId
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

    lobby.activeScenario.game.truckNetId = truckNetId
    lobby.activeScenario.game.escortNetId = escortNetId
    lobby.activeScenario.game.guardNetIds = guardNetIds

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:money_truck_robbery:onTruckSpawned"), member.source, {
            lobbyId = lobbyId,
            truckNetId = truckNetId,
            escortNetId = escortNetId,
            locationIndex = locationIndex,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:money_truck_robbery:onTruckOpened"), function(params)
    local lobbyId = params.lobbyId
    local openedDoor = params.openedDoor
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.activeScenario.game.truckOpened
    then
        return
    end

    lobby.activeScenario.game.truckOpened = true
    lobby.activeScenario.game.openedDoor = openedDoor

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:money_truck_robbery:onTruckOpened"), member.source, {
            lobbyId = lobbyId,
            openedDoor = openedDoor,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:money_truck_robbery:onMoneysSpawned"), function(params)
    local lobbyId = params.lobbyId
    local moneyNetId = params.moneyNetId
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.owner ~= playerId
    then
        return
    end

    lobby.activeScenario.game.moneyNetId = moneyNetId

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:money_truck_robbery:onMoneysSpawned"), member.source, {
            lobbyId = lobbyId,
            moneyNetId = moneyNetId,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:money_truck_robbery:onMoneyCollected"), function(params)
    local lobbyId = params.lobbyId
    local playerId = source

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.truckOpened
    then
        return
    end

    if lobby.activeScenario.game.moneyCollected then
        return
    end

    lobby.activeScenario.game.moneyCollected = true

    -- Give rewards to player
    local selectedRewards = Utils.selectRandomRewards(config.lootableMoneyRewards)
    for _, reward in pairs(selectedRewards) do
        Inventory.giveItem(playerId, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:money_truck_robbery:onMoneyCollected"), member.source, {
            lobbyId = lobbyId,
        })
    end
end)
