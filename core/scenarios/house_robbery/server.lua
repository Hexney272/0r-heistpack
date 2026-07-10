local lib                   = lib
local Utils                 = require("modules.utils.server")
local Inventory             = require("modules.inventory.server")

local config                = lib.load("config.scenarios.house_robbery")

-- Shared modules
local InteriorManagerServer = require("core.scenarios._shared.server.interior_manager")

HouseRobberyServer          = {}

local scenarioKey           = "house_robbery"
local state                 = {
    activeInteriors = {},
}

-- Module instances (per lobby)
---@type table<string, InteriorManagerServer>
local interiorManagers      = {} -- [lobbyId] = InteriorManagerServer

local function findAvailableInterior()
    local availableInteriors = {}

    for interiorId, interior in pairs(config.interiors) do
        if not state.activeInteriors[interiorId] and interior.isActive ~= false then
            table.insert(availableInteriors, interiorId)
        end
    end

    if #availableInteriors == 0 then
        return nil
    end

    math.randomseed(os.time())

    local randomIndex = math.random(1, #availableInteriors)
    local selectedInteriorId = availableInteriors[randomIndex]

    state.activeInteriors[selectedInteriorId] = true
    return selectedInteriorId
end

function HouseRobberyServer.clear(activeScenario)
    local lobbyId = activeScenario.lobbyId
    local interiorId = activeScenario.game.interiorId or nil

    if interiorId then
        state.activeInteriors[interiorId] = nil
    end

    -- Clear interior manager
    if interiorManagers[lobbyId] then
        interiorManagers[lobbyId]:clear()
        interiorManagers[lobbyId] = nil
    end

    local networkedObjects = {}

    for lootIndex, lootInfo in pairs(activeScenario.game.interior.loots) do
        if lootInfo.placedObjectNetId then
            table.insert(networkedObjects, lootInfo.placedObjectNetId)
        end
    end

    Utils.deleteNetworkedObjects(networkedObjects)
end

function HouseRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    local availableInterior = findAvailableInterior()
    if not availableInterior then
        return { success = false, message = locale("house_robbery.no_available_interior") }
    end

    lobby.activeScenario.game.interiorId = availableInterior
    lobby.activeScenario.game.interior = lib.table.deepclone(config.interiors[availableInterior])

    -- Initialize interior manager for this lobby
    interiorManagers[lobbyId] = InteriorManagerServer.new({
        lobbyId = lobbyId,
        bucketFormat = config.bucketIdFormat,
        interiorId = availableInterior,
        locations = config.interiors[availableInterior].locations,
    })

    return { success = true }
end

---comment
---@param source any
---@param params {lobbyId: string, holdingObjectNetId?: number}
---@return table
lib.callback.register(_e("server:scenarios:house_robbery:setPlayerInside"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end
    if not lobby.activeScenario then
        return { success = false, message = locale("lobby.not_found") }
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then
        return { success = false, message = locale("lobby.player_not_found") }
    end

    local interiorId = lobby.activeScenario.game.interiorId
    local interior = config.interiors[interiorId]
    if not interior then
        return { success = false, message = locale("house_robbery.interior_not_found") }
    end

    local interiorManager = interiorManagers[lobbyId]
    if not interiorManager then
        return { success = false, message = locale("house_robbery.interior_manager_not_found") }
    end

    -- Teleport player inside using shared module
    interiorManager:teleportInside(source, params.holdingObjectNetId)

    TriggerClientEvent(_e("client:scenarios:house_robbery:onPlayerInsideInterior"), source)

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:house_robbery:setPlayerOutside"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end
    if not lobby.activeScenario then
        return { success = false, message = locale("lobby.not_found") }
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then
        return { success = false, message = locale("lobby.player_not_found") }
    end

    local interiorId = lobby.activeScenario.game.interiorId
    local interior = config.interiors[interiorId]
    if not interior then
        return { success = false, message = locale("house_robbery.interior_not_found") }
    end

    local interiorManager = interiorManagers[lobbyId]
    if not interiorManager then
        return { success = false, message = locale("house_robbery.interior_manager_not_found") }
    end

    -- Teleport player outside using shared module
    interiorManager:teleportOutside(source, interior.locations.entrance, params.holdingObjectNetId)

    TriggerClientEvent(_e("client:scenarios:house_robbery:onPlayerOutsideInterior"), source)

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:house_robbery:onHouseDoorUnlocked"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end

    lobby.activeScenario.game.interior.unlocked = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:house_robbery:onHouseDoorUnlocked"), member.source, source)
    end
end)

lib.callback.register(_e("server:scenarios:house_robbery:lootProp"), function(source, params)
    local lobbyId = params.lobbyId
    local lootIndex = params.lootIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby then return { success = false, message = locale("lobby.not_found") } end
    if not lobby.activeScenario then return { success = false, message = locale("lobby.not_found") } end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return { success = false, message = locale("lobby.player_not_found") } end

    if not lobby.activeScenario.game.interior then
        return {
            success = false,
            message = locale(
                "house_robbery.interior_not_found")
        }
    end
    if not lobby.activeScenario.game.interior.loots then
        return {
            success = false,
            message = locale(
                "house_robbery.interior_not_found")
        }
    end

    ---@type LootPoint
    local interiorLoot = lobby.activeScenario.game.interior.loots[lootIndex]
    if not interiorLoot then
        return {
            success = false,
            message = locale("house_robbery.interior_loot_not_found",
                lootIndex)
        }
    end

    if interiorLoot.looted then
        return { success = false, message = locale("loot_already_looted") }
    end

    -- Give rewards
    if interiorLoot.rewardKey then
        local rewardItemsConfig = config.lootRewardItems[interiorLoot.rewardKey]
        if not rewardItemsConfig then
            return { success = false, message = locale("house_robbery.no_reward_items_found", interiorLoot.rewardKey) }
        end

        local selectedRewards = Utils.selectRandomRewards(rewardItemsConfig)
        for _, item in pairs(selectedRewards) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    lobby.activeScenario.game.interior.loots[lootIndex].looted = true
    lobby.activeScenario.game.interior.loots[lootIndex].busy = false

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:house_robbery:onLootPropUpdated"), member.source, {
            lootIndex = lootIndex,
            looted = true,
            deleteProp = interiorLoot.interaction == "grab"
        })
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:house_robbery:carryLootProp"), function(source, params)
    local lobbyId = params.lobbyId
    local lootIndex = params.lootIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby then return { success = false, message = locale("lobby.not_found") } end
    if not lobby.activeScenario then return { success = false, message = locale("lobby.not_found") } end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return { success = false, message = locale("lobby.player_not_found") } end

    if not lobby.activeScenario.game.interior then
        return {
            success = false,
            message = locale(
                "house_robbery.interior_not_found")
        }
    end
    if not lobby.activeScenario.game.interior.loots then
        return {
            success = false,
            message = locale(
                "house_robbery.interior_not_found")
        }
    end

    ---@type LootPoint
    local interiorLoot = lobby.activeScenario.game.interior.loots[lootIndex]
    if not interiorLoot then
        return {
            success = false,
            message = locale("house_robbery.interior_loot_not_found",
                lootIndex)
        }
    end

    if interiorLoot.looted then
        return { success = false, message = locale("loot_already_looted") }
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:house_robbery:onCarryLootProp"), member.source, {
            lootIndex = lootIndex,
            holdingBy = source
        })
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:house_robbery:placeLootInVehicle"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby then return end
    if not lobby.activeScenario then return end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return end

    if not lobby.activeScenario.game.interior then return end
    if not lobby.activeScenario.game.interior.loots then return end

    local lootIndex = params.lootIndex
    local interiorLoot = lobby.activeScenario.game.interior.loots[lootIndex]

    if not interiorLoot then return end

    lobby.activeScenario.game.interior.loots[lootIndex].busy = false
    lobby.activeScenario.game.interior.loots[lootIndex].looted = true

    local lootPrice = 0
    if interiorLoot.prop and interiorLoot.prop.model then
        lootPrice = config.movablePropLootPrices[interiorLoot.prop.model] or 0
    end
    lobby.activeScenario.scenario.rewards = lobby.activeScenario.scenario.rewards or {}
    lobby.activeScenario.scenario.rewards.money = (lobby.activeScenario.scenario.rewards.money or 0) + lootPrice

    local vehicleNetId = params.vehicleNetId
    local vehicleEntity = NetworkGetEntityFromNetworkId(vehicleNetId)

    if DoesEntityExist(vehicleEntity) then
        local vehicleOwner = NetworkGetEntityOwner(vehicleEntity)
        local placedObjectNetId = lib.callback.await(
            _e("client:scenarios:house_robbery:spawnLootInVehicle"),
            vehicleOwner,
            {
                interiorId = lobby.activeScenario.game.interiorId,
                lootIndex = lootIndex,
                vehicleNetId = vehicleNetId
            }
        )

        lobby.activeScenario.game.interior.loots[lootIndex].placedObjectNetId = placedObjectNetId
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:house_robbery:onLootPlacedInVehicle"), member.source, {
            lootIndex = lootIndex,
        })
    end
end)
