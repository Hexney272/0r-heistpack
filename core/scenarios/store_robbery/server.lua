local lib          = lib
local Utils        = require("modules.utils.server")
local Inventory    = require("modules.inventory.server")

local config       = lib.load("config.scenarios.store_robbery")

local SV_MAP_TYPE  = config.hasCustomMap and "custom" or "standart"

StoreRobberyServer = {}

local scenarioKey  = "store_robbery"

function StoreRobberyServer.clear(activeScenario, lobbyId)
    local netIds = {}
    if activeScenario.game.location then
        local miniSafe = activeScenario.game.location.miniSafe
        if miniSafe.body and miniSafe.body.netId then
            table.insert(netIds, miniSafe.body.netId)
        end
        if miniSafe.door and miniSafe.door.netId then
            table.insert(netIds, miniSafe.door.netId)
        end
        for lootIndex, loot in pairs(activeScenario.game.location.loots) do
            if loot.placedObjectNetId then
                table.insert(netIds, loot.placedObjectNetId)
            end
        end
    end

    Utils.deleteNetworkedObjects(netIds)
end

function StoreRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_found") }
    end

    lobby.activeScenario.game.vehicleType = nil
    lobby.activeScenario.game.location = nil
    lobby.activeScenario.game.locationIndex = nil

    lobby.activeScenario.game.miniSafePin = Utils.generateUniquePin(3)

    return { success = true }
end

---@param source number
---@param params {lobbyId: number, selectedVehicleType: string}
lib.callback.register(_e("server:store_robbery:onVehicleSelected"), function(source, params)
    local lobby = LobbyServer:getLobbyById(params.lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.activeScenario.game.vehicleType
    then
        return false
    end

    lobby.activeScenario.game.vehicleType = params.selectedVehicleType

    TriggerClientEvent(_e("client:store_robbery:onVehicleTypeSelected"), source, {
        lobbyId = params.lobbyId,
        owner = source,
        selectedVehicleType = params.selectedVehicleType,
    })

    return true
end)

RegisterNetEvent(_e("server:scenarios:store_robbery:onCashierRobbed"), function(params)
    local locationIndex = params.locationIndex --[[@type number]]
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not locationIndex or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.activeScenario.game.location or
        config.locations[SV_MAP_TYPE][locationIndex] == nil
    then
        return
    end

    local location = lib.table.deepclone(config.locations[SV_MAP_TYPE][locationIndex])
    lobby.activeScenario.game.location = location
    lobby.activeScenario.game.location.cashier.robbed = true
    lobby.activeScenario.game.locationIndex = locationIndex

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:store_robbery:onLocationSet"), member.source, {
            lobbyId = lobbyId,
            locationIndex = locationIndex,
            isCashierRobbed = true,
        })
    end
end)

lib.callback.register(_e("server:scenarios:store_robbery:onCashierMoneyCollected"), function(source, params)
    local lobby = LobbyServer:getLobbyById(params.lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.cashier.robbed
    then
        return { success = false }
    end

    local locationCashier = lobby.activeScenario.game.location.cashier

    locationCashier.collectors = locationCashier.collectors or {}

    if locationCashier.collectors[source] then
        return { success = false, message = locale("store_robbery.cashier_money_already_collected") }
    end

    locationCashier.collectors[source] = true

    local rewards = Utils.selectRandomRewards(config.cashierRobbery.rewards or {})
    for _, item in pairs(rewards) do
        Inventory.giveItem(source, item.name, item.count)
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:store_robbery:onMiniSafeSetup"), function(params)
    local owner = source
    local lobby = LobbyServer:getLobbyById(params.lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        lobby.owner ~= owner or
        not lobby.activeScenario.game.location
    then
        return
    end

    local locationMiniSafe = lobby.activeScenario.game.location.miniSafe

    locationMiniSafe.body.netId = params.bodyNetId
    locationMiniSafe.door.netId = params.doorNetId

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:store_robbery:onMiniSafeSetup"), member.source, {
            lobbyId = params.lobbyId,
            bodyNetId = params.bodyNetId,
            doorNetId = params.doorNetId,
        })
    end
end)

lib.callback.register(_e("server:store_robbery:onMiniSafeOpened"), function(source, params)
    local lobby = LobbyServer:getLobbyById(params.lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.miniSafe or
        lobby.activeScenario.game.location.miniSafe.opened
    then
        return false
    end

    local locationMiniSafe = lobby.activeScenario.game.location.miniSafe

    locationMiniSafe.opened = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:store_robbery:onMiniSafeOpened"), member.source, {
            lobbyId = params.lobbyId,
        })
    end

    local miniSafeDoor = locationMiniSafe.door
    if miniSafeDoor and miniSafeDoor.netId then
        local entity = NetworkGetEntityFromNetworkId(miniSafeDoor.netId)
        if DoesEntityExist(entity) then
            SetEntityCoords(entity, miniSafeDoor.openCoords.x, miniSafeDoor.openCoords.y, miniSafeDoor.openCoords.z,
                false, false, false, false)
            SetEntityHeading(entity, miniSafeDoor.openCoords.w or 0.0)
        end
    end

    return true
end)

lib.callback.register(_e("server:scenarios:store_robbery:lootMiniSafe"), function(source, params)
    local lobby = LobbyServer:getLobbyById(params.lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.miniSafe or
        not lobby.activeScenario.game.location.miniSafe.opened
    then
        return { success = false }
    end

    local locationMiniSafe = lobby.activeScenario.game.location.miniSafe

    locationMiniSafe.collectors = locationMiniSafe.collectors or {}

    if locationMiniSafe.collectors[source] then
        return { success = false, message = locale("store_robbery.mini_safe_already_looted") }
    end

    locationMiniSafe.collectors[source] = true

    local locationIndex = lobby.activeScenario.game.locationIndex --[[@type number]]
    local rewards = Utils.selectRandomRewards(config.locations[SV_MAP_TYPE][locationIndex].miniSafe.rewards or {})
    for _, item in pairs(rewards) do
        Inventory.giveItem(source, item.name, item.count)
    end

    return { success = true }
end)

lib.callback.register(_e("server:scenarios:store_robbery:canLootCashRegister"), function(source, params)
    local lobbyId = params.lobbyId
    local cashRegisterIndex = params.cashRegisterIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.lootableCashRegisters or
        not lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex]
    then
        return false
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return false end

    local locationCashRegister = lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex]
    if locationCashRegister.busy then
        return false
    end

    locationCashRegister.busy = true

    return true
end)

lib.callback.register(_e("server:scenarios:store_robbery:carryCashRegister"), function(source, params)
    local lobbyId = params.lobbyId
    local cashRegisterIndex = params.cashRegisterIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.lootableCashRegisters or
        not lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex]

    then
        return { success = false }
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return { success = false, message = locale("lobby.player_not_found") } end

    local locationCashRegister = lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex]
    if not locationCashRegister then return { success = false } end

    if locationCashRegister.looted then
        return { success = false, message = locale("loot_already_looted") }
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:store_robbery:onCarryCashRegister"), member.source, {
            cashRegisterIndex = cashRegisterIndex,
            holdingBy = source
        })
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:store_robbery:onCashRegisterThrown"), function(params)
    local lobbyId = params.lobbyId
    local cashRegisterIndex = params.cashRegisterIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.lootableCashRegisters or
        not lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex] or
        lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex].looted
    then
        return
    end

    local locationCashRegister = lobby.activeScenario.game.location.lootableCashRegisters[cashRegisterIndex]

    locationCashRegister.looted = true
    locationCashRegister.busy = false

    local rewards = config.lootRewardItems.cash_register
    if rewards then
        local rewardedItems = Utils.selectRandomRewards(rewards)
        for _, item in pairs(rewardedItems) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:store_robbery:onCashRegisterLooted"), member.source, {
            cashRegisterIndex = cashRegisterIndex,
        })
    end
end)

lib.callback.register(_e("server:scenarios:store_robbery:canLootPoint"), function(source, params)
    local lobbyId = params.lobbyId
    local lootIndex = params.lootIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.loots or
        not lobby.activeScenario.game.location.loots[lootIndex]
    then
        return false
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return false end

    local loot = lobby.activeScenario.game.location.loots[lootIndex]
    if loot.busy or
        loot.looted
    then
        return false
    end

    loot.busy = true

    return true
end)

lib.callback.register(_e("server:scenarios:store_robbery:lootPoint"), function(source, params)
    local lobbyId = params.lobbyId
    local lootIndex = params.lootIndex
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.loots or
        not lobby.activeScenario.game.location.loots[lootIndex]
    then
        return { success = false, message = locale("lobby.not_found") }
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return { success = false, message = locale("lobby.player_not_found") } end

    local lootablePoint = lobby.activeScenario.game.location.loots[lootIndex]
    if not lootablePoint then return { success = false } end

    if lootablePoint.looted then
        return { success = false, message = locale("store_robbery.point_already_looted") }
    end

    if lootablePoint.rewardKey then
        local rewardItemsConfig = config.lootRewardItems[lootablePoint.rewardKey]
        if not rewardItemsConfig then
            return { success = false, message = locale("store_robbery.no_reward_items_found", lootablePoint.rewardKey) }
        end

        local selectedRewards = Utils.selectRandomRewards(rewardItemsConfig)
        for _, item in pairs(selectedRewards) do
            Inventory.giveItem(source, item.name, item.count)
        end
    end

    lootablePoint.looted = true
    lootablePoint.busy = false

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:store_robbery:onLootPointUpdated"),
            member.source,
            { lootIndex = lootIndex, looted = true, holdingBy = lootablePoint.interaction == "carry" and source or nil })
    end

    return { success = true }
end)

RegisterNetEvent(_e("server:scenarios:store_robbery:placeLootInVehicle"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)

    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.location or
        not lobby.activeScenario.game.location.loots or
        not lobby.activeScenario.game.location.loots[params.lootIndex] or
        not lobby.activeScenario.game.location.loots[params.lootIndex].looted
    then
        return
    end

    local player = LobbyServer:isPlayerInLobby(lobbyId, source)
    if not player then return end

    local lootIndex = params.lootIndex

    local loots = lobby.activeScenario.game.location.loots
    local loot = loots[lootIndex]

    local lootPrice = 0
    if loot.prop and loot.prop.model then
        lootPrice = config.movablePropLootPrices[loot.prop.model] or 0
    end

    lobby.activeScenario.scenario.rewards = lobby.activeScenario.scenario.rewards or {}
    lobby.activeScenario.scenario.rewards.money = (lobby.activeScenario.scenario.rewards.money or 0) + lootPrice

    local vehicleNetId = params.vehicleNetId
    local vehicleEntity = NetworkGetEntityFromNetworkId(vehicleNetId)
    if DoesEntityExist(vehicleEntity) then
        local vehicleOwner = NetworkGetEntityOwner(vehicleEntity)
        local placedObjectNetId = lib.callback.await(
            _e("client:scenarios:store_robbery:spawnLootInVehicle"),
            vehicleOwner,
            {
                locationIndex = lobby.activeScenario.game.locationIndex,
                lootIndex = lootIndex,
                vehicleNetId = vehicleNetId
            }
        )

        lobby.activeScenario.game.location.loots[lootIndex].placedObjectNetId = placedObjectNetId
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:store_robbery:onLootPlacedInVehicle"), member.source, {
            lootIndex = lootIndex,
        })
    end
end)
