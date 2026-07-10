local lib              = lib
local Utils            = require("modules.utils.server")
local Inventory        = require("modules.inventory.server")
local Framework        = require "modules.framework.init"

local config           = lib.load("config.scenarios.vangelico_robbery")

VangelicoRobberyServer = {}

local scenarioKey      = "vangelico_robbery"
local state            = {
    areItemsRegistered = false,
}

local function canPlayerUseScenarioItem(source, itemName)
    local playerLobbyId = LobbyServer:findPlayerLobby(source)
    if not playerLobbyId then return false end

    local lobby = LobbyServer:getLobbyById(playerLobbyId)
    if not lobby then return false end

    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end

    return true
end

local function onScenarioItemUsed(source, itemName)
    TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onScenarioItemUsed"), source, { itemName = itemName })
end

function VangelicoRobberyServer.clear(activeScenario)
    if not activeScenario then return end

    if activeScenario.game.poisonousGasOptions.isGasActive then
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onPoisonousGasDeactivated"), -1)
    end

    if activeScenario.game.entranceDoorOptions and
        activeScenario.game.entranceDoorOptions.bombPlanted and
        not activeScenario.game.entranceDoorOptions.bombExploded
    then
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:setFalseDoorLockingThread"), -1)
    end

    local networkIds = {}

    if activeScenario.game.paintingSmuggleOptions and activeScenario.game.paintingSmuggleOptions.locations then
        for _, loc in pairs(activeScenario.game.paintingSmuggleOptions.locations) do
            if loc.objectNetId then
                table.insert(networkIds, loc.objectNetId)
            end
        end
    end
    if activeScenario.game.caseRoomOptions and
        activeScenario.game.caseRoomOptions.safe and
        activeScenario.game.caseRoomOptions.safe.objects
    then
        for _, obj in pairs(activeScenario.game.caseRoomOptions.safe.objects) do
            if obj.netId then
                table.insert(networkIds, obj.netId)
            end
        end
    end

    Utils.deleteNetworkedObjects(networkIds)
end

function VangelicoRobberyServer.canPlayerUseScenarioItem(source, itemName)
    return canPlayerUseScenarioItem(source, itemName)
end

function VangelicoRobberyServer.registerScenarioItems()
    if state.areItemsRegistered then return end

    local gasMaskItemName = config.poisonousGasOptions.maskItemName

    if gasMaskItemName then
        Framework.createUseableItem(gasMaskItemName, function(source)
            onScenarioItemUsed(source, gasMaskItemName)
        end)
    end

    state.areItemsRegistered = true
end

function VangelicoRobberyServer.init(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return { success = false, error = "Lobby not found" } end

    if lobby.activeScenario.game.caseRoomOptions and
        lobby.activeScenario.game.caseRoomOptions.door and
        not lobby.activeScenario.game.caseRoomOptions.door.pin
    then
        lobby.activeScenario.game.caseRoomOptions.door.pin = {
            math.random(1, 9), math.random(1, 9),
            math.random(1, 9), math.random(1, 9)
        }
    end

    return { success = true }
end

lib.callback.register(_e("server:scenarios:vangelico_robbery:canPlayerUseScenarioItem"), function(source, itemName)
    return canPlayerUseScenarioItem(source, itemName)
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:onGasBombDropped"), function(source, params)
    local lobbyId = params.lobbyId
    local zoneIndex = params.zoneIndex
    local coords = params.coords

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end

    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end

    if not lobby.activeScenario.game.poisonousGasOptions then return false end
    if lobby.activeScenario.game.poisonousGasOptions.allDropped then return false end
    if not lobby.activeScenario.game.poisonousGasOptions.dropZones then return false end
    if not lobby.activeScenario.game.poisonousGasOptions.dropZones[zoneIndex] then return false end
    if lobby.activeScenario.game.poisonousGasOptions.dropZones[zoneIndex].dropped then return false end

    lobby.activeScenario.game.poisonousGasOptions.dropZones[zoneIndex].dropped = true

    local requiredDrops = #lobby.activeScenario.game.poisonousGasOptions.dropZones
    local currentDrops = 0
    local allDropped = false
    for _, dropZone in pairs(lobby.activeScenario.game.poisonousGasOptions.dropZones) do
        if dropZone.dropped then
            currentDrops = currentDrops + 1
        end
    end

    if currentDrops >= requiredDrops then
        allDropped = true
        lobby.activeScenario.game.poisonousGasOptions.allDropped = true
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onGasBombDropped"), member.source, {
            lobbyId = lobbyId,
            zoneIndex = zoneIndex,
            coords = coords,
            allDropped = allDropped,
            droppedCount = currentDrops,
            totalDrops = requiredDrops,
            droneDriver = source,
        })
    end

    return true
end)

RegisterNetEvent(_e("server:scenarios:vangelico_robbery:setActivePoisonousGas"), function(params)
    local source = source
    local lobbyId = params.lobbyId
    if not lobbyId then return end
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if lobby.owner ~= source then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.poisonousGasOptions then return end
    if not lobby.activeScenario.game.poisonousGasOptions.allDropped then return end
    if lobby.activeScenario.game.poisonousGasOptions.isGasActive then return end

    lobby.activeScenario.game.poisonousGasOptions.isGasActive = true

    TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onPoisonousGasActivated"), -1,
        { lobbyId = lobbyId }
    )
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:plantBombAtFrontDoor"), function(source, params)
    if not params.lobbyId or not params.plantedBomb then return false end

    local lobbyId = params.lobbyId
    local plantedBomb = params.plantedBomb

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if lobby.activeScenario.game.entranceDoorOptions and lobby.activeScenario.game.entranceDoorOptions.bombPlanted then return false end

    lobby.activeScenario.game.entranceDoorOptions.bombPlanted = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onBombPlantedAtFrontDoor"), member.source, {
            plantedBomb = plantedBomb,
            lobbyId = lobbyId,
            planter = source,
        })
    end

    return true
end)

RegisterNetEvent(_e("server:scenarios:vangelico_robbery:onPlantedDoorBombExploded"), function(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.entranceDoorOptions or not lobby.activeScenario.game.entranceDoorOptions.bombPlanted then return end
    if lobby.activeScenario.game.entranceDoorOptions.bombExploded then return end

    lobby.activeScenario.game.entranceDoorOptions.bombExploded = true

    TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onPlantedFrontDoorBombExploded"), -1, { lobbyId = lobbyId })
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:robPedItems"), function(source, params)
    if not params.lobbyId or not params.pedIndex then return false end

    local lobbyId = params.lobbyId
    local pedIndex = params.pedIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if not lobby.activeScenario.game.robbablePedOptions or not lobby.activeScenario.game.robbablePedOptions.peds then return false end
    if not lobby.activeScenario.game.robbablePedOptions.peds[pedIndex] then return false end
    if lobby.activeScenario.game.robbablePedOptions.peds[pedIndex].robbed then return false end

    lobby.activeScenario.game.robbablePedOptions.peds[pedIndex].robbed = true

    local rewards = Utils.selectRandomRewards(config.robbablePedOptions.rewards)

    if #rewards == 0 then return false end

    for _, reward in pairs(rewards) do
        Inventory.giveItem(source, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onPedRobbed"), member.source, {
            lobbyId = lobbyId,
            pedIndex = pedIndex,
        })
    end

    return true
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:lootDisplay"), function(source, params)
    if not params.lobbyId or not params.displayIndex then return false end

    local lobbyId = params.lobbyId
    local displayIndex = params.displayIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if not lobby.activeScenario.game.lootableDisplayOptions or not lobby.activeScenario.game.lootableDisplayOptions.locations then return false end
    if not lobby.activeScenario.game.lootableDisplayOptions.locations[displayIndex] then return false end
    if lobby.activeScenario.game.lootableDisplayOptions.locations[displayIndex].looted then return false end

    lobby.activeScenario.game.lootableDisplayOptions.locations[displayIndex].looted = true
    local rewards = Utils.selectRandomRewards(config.lootableDisplayOptions.rewards)

    for _, reward in pairs(rewards) do
        Inventory.giveItem(source, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onDisplayLooted"), member.source, {
            lobbyId = lobbyId,
            displayIndex = displayIndex,
        })
    end

    return true
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:smashCase"), function(source, params)
    if not params.lobbyId or not params.caseIndex then return false end

    local lobbyId = params.lobbyId
    local caseIndex = params.caseIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if not lobby.activeScenario.game.smashableCaseOptions or not lobby.activeScenario.game.smashableCaseOptions.locations then return false end
    if not lobby.activeScenario.game.smashableCaseOptions.locations[caseIndex] then return false end
    if lobby.activeScenario.game.smashableCaseOptions.locations[caseIndex].looted then return false end

    lobby.activeScenario.game.smashableCaseOptions.locations[caseIndex].looted = true

    local rewards = Utils.selectRandomRewards(config.smashableCaseOptions.rewards)

    for _, reward in pairs(rewards) do
        Inventory.giveItem(source, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onCaseSmash"), member.source, {
            lobbyId = lobbyId,
            caseIndex = caseIndex,
        })
    end

    return true
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:smashCashRegister"), function(source, params)
    if not params.lobbyId or not params.registerIndex then return false end

    local lobbyId = params.lobbyId
    local registerIndex = params.registerIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if not lobby.activeScenario.game.smashableCashRegisterOptions or not lobby.activeScenario.game.smashableCashRegisterOptions.locations then return false end
    if not lobby.activeScenario.game.smashableCashRegisterOptions.locations[registerIndex] then return false end
    if lobby.activeScenario.game.smashableCashRegisterOptions.locations[registerIndex].looted then return false end

    lobby.activeScenario.game.smashableCashRegisterOptions.locations[registerIndex].looted = true
    local rewards = Utils.selectRandomRewards(config.smashableCashRegisterOptions.rewards)
    for _, reward in pairs(rewards) do
        Inventory.giveItem(source, reward.name, reward.count)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onCashRegisterSmash"), member.source, {
            lobbyId = lobbyId,
            registerIndex = registerIndex,
        })
    end

    return true
end)

RegisterNetEvent(_e("server:scenarios:vangelico_robbery:registerPaintingObject"), function(params)
    if not params.lobbyId or not params.index or not params.netId or not params.model then return end
    local lobbyId = params.lobbyId
    local index = params.index
    local netId = params.netId
    local model = params.model
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.paintingSmuggleOptions or not lobby.activeScenario.game.paintingSmuggleOptions.locations then return end
    if not lobby.activeScenario.game.paintingSmuggleOptions.locations[index] then return end
    if lobby.activeScenario.game.paintingSmuggleOptions.locations[index].objectNetId then return end

    lobby.activeScenario.game.paintingSmuggleOptions.locations[index].objectNetId = netId
    lobby.activeScenario.game.paintingSmuggleOptions.locations[index].objectModel = model

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onPaintingObjectRegistered"), member.source, {
            lobbyId = lobbyId,
            index = index,
            netId = netId,
            model = model,
        })
    end
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:smugglePainting"), function(source, params)
    if not params.lobbyId or not params.paintingIndex then return false end

    local lobbyId = params.lobbyId
    local paintingIndex = params.paintingIndex

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if not lobby.activeScenario.game.paintingSmuggleOptions or not lobby.activeScenario.game.paintingSmuggleOptions.locations then return false end
    if not lobby.activeScenario.game.paintingSmuggleOptions.locations[paintingIndex] then return false end
    if lobby.activeScenario.game.paintingSmuggleOptions.locations[paintingIndex].taken then return false end

    lobby.activeScenario.game.paintingSmuggleOptions.locations[paintingIndex].taken = true

    local objectNetId = lobby.activeScenario.game.paintingSmuggleOptions.locations[paintingIndex].objectNetId
    if objectNetId then
        Utils.deleteNetworkedObjects(objectNetId)
        lobby.activeScenario.game.paintingSmuggleOptions.locations[paintingIndex].objectNetId = nil
    end

    local reward = config.paintingSmuggleOptions.locations[paintingIndex] and
        config.paintingSmuggleOptions.locations[paintingIndex].reward or nil

    if reward then
        Inventory.giveItem(source, reward.itemName, reward.count or 1)
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onPaintingSmuggled"), member.source, {
            lobbyId = lobbyId,
            paintingIndex = paintingIndex,
        })
    end

    return true
end)

RegisterNetEvent(_e("server:scenarios:vangelico_robbery:unlockCaseRoomDoor"), function(params)
    local source = source

    local lobbyId = params.lobbyId
    if not lobbyId then return end

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby or
        not lobby.activeScenario or
        lobby.activeScenario.key ~= scenarioKey or
        not lobby.activeScenario.game.caseRoomOptions or
        lobby.activeScenario.game.caseRoomOptions.doorUnlocked
    then
        return
    end

    if not lobby.activeScenario.game.caseRoomOptions then
        lobby.activeScenario.game.caseRoomOptions = {}
    end

    lobby.activeScenario.game.caseRoomOptions.doorUnlocked = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onCaseRoomDoorUnlocked"), member.source, {
            lobbyId = lobbyId,
        })
    end
end)

RegisterNetEvent(_e("server:scenarios:vangelico_robbery:registerCaseRoomObjects"), function(params)
    if not params.lobbyId or not params.objects then return end
    local lobbyId = params.lobbyId
    local objects = params.objects
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.caseRoomOptions then return end
    if not lobby.activeScenario.game.caseRoomOptions.safe then return end

    lobby.activeScenario.game.caseRoomOptions.safe.objects = objects

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onCaseRoomObjectsRegistered"), member.source, {
            lobbyId = lobbyId,
            objects = objects,
        })
    end
end)

lib.callback.register(_e("server:heists:vangelico_robbery:isDrillOnSurface"), function(source, params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.caseRoomOptions then return end
    if not lobby.activeScenario.game.caseRoomOptions.safe then return end

    return lobby.activeScenario.game.caseRoomOptions.safe.drillPlaced or false
end)

RegisterNetEvent(_e("server:heists:vangelico_robbery:placeDrillOnSurface"), function(params)
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end
    if lobby.activeScenario.key ~= scenarioKey then return end
    if not lobby.activeScenario.game.caseRoomOptions then return end
    if not lobby.activeScenario.game.caseRoomOptions.safe then return end
    if lobby.activeScenario.game.caseRoomOptions.safe.drillPlaced then return end

    lobby.activeScenario.game.caseRoomOptions.safe.drillPlaced = true

    Citizen.SetTimeout(config.caseRoomOptions.safe.drill.animation.duration, function()
        lobby.activeScenario.game.caseRoomOptions.safe.opened = true
        for _, member in pairs(lobby.members) do
            TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onCaseSafeOpened"), member.source, {
                lobbyId = lobbyId,
            })
        end

        local safeDoorObjectNetId = lobby.activeScenario.game.caseRoomOptions.safe.objects and
            lobby.activeScenario.game.caseRoomOptions.safe.objects.door and
            lobby.activeScenario.game.caseRoomOptions.safe.objects.door.netId or nil
        if not safeDoorObjectNetId then return end
        Utils.deleteNetworkedObjects(safeDoorObjectNetId)
    end)
end)

lib.callback.register(_e("server:scenarios:vangelico_robbery:lootCaseRoomSafe"), function(source, params)
    if not params.lobbyId then return end
    local lobbyId = params.lobbyId
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end
    if not lobby.activeScenario then return false end
    if lobby.activeScenario.key ~= scenarioKey then return false end
    if not lobby.activeScenario.game.caseRoomOptions then return false end
    if not lobby.activeScenario.game.caseRoomOptions.safe then return false end
    if not lobby.activeScenario.game.caseRoomOptions.safe.opened then return false end
    if not lobby.activeScenario.game.caseRoomOptions.safe.inside then return false end
    if not lobby.activeScenario.game.caseRoomOptions.safe.inside[params.insideIndex] then return false end
    if lobby.activeScenario.game.caseRoomOptions.safe.inside[params.insideIndex].looted then return false end

    lobby.activeScenario.game.caseRoomOptions.safe.inside[params.insideIndex].looted = true

    local selectedRewards = Utils.selectRandomRewards(config.caseRoomOptions.safe.inside[params.insideIndex].rewards or
    {})
    for _, reward in pairs(selectedRewards) do
        Inventory.giveItem(source, reward.name, reward.count)
    end

    local objectNetId = lobby.activeScenario.game.caseRoomOptions.safe.objects and
        lobby.activeScenario.game.caseRoomOptions.safe.objects["inside_" .. params.insideIndex] and
        lobby.activeScenario.game.caseRoomOptions.safe.objects["inside_" .. params.insideIndex].netId or nil
    if objectNetId then
        Utils.deleteNetworkedObjects(objectNetId)
        lobby.activeScenario.game.caseRoomOptions.safe.objects["inside_" .. params.insideIndex].netId = nil
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:scenarios:vangelico_robbery:onCaseSafeLooted"), member.source, {
            lobbyId = lobbyId,
            insideIndex = params.insideIndex,
        })
    end

    return true
end)
