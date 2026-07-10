local lib              = lib
local Inventory        = require "modules.inventory.server"
local Utils            = require "modules.utils.server"
local Framework        = require "modules.framework.init"
local ScenarioRegistry = require "core.heist.scenario_registry"
local CooldownManager  = require "core.heist.cooldown_manager"
local Exports          = require "modules.exports.server"

local config           = lib.load("config.heist")

HeistServer            = {}

local activeScenarios  = {}

local function setScenarioActive(lobbyId, scenarioKey)
    if not activeScenarios[scenarioKey] then
        activeScenarios[scenarioKey] = {}
    end
    table.insert(activeScenarios[scenarioKey], lobbyId)
end

local function releaseScenario(scenarioKey, lobbyId)
    if activeScenarios[scenarioKey] then
        for i, id in ipairs(activeScenarios[scenarioKey]) do
            if id == lobbyId then
                table.remove(activeScenarios[scenarioKey], i)
                break
            end
        end
        if #activeScenarios[scenarioKey] == 0 then
            activeScenarios[scenarioKey] = nil
        end
    end
end

local function isScenarioBusy(scenarioKey)
    if not activeScenarios[scenarioKey] then
        return false
    end

    local scenarioConfig = HeistServer.getScenarioConfig(scenarioKey)
    if not scenarioConfig then
        return false
    end

    local maxSimultaneous = math.max(scenarioConfig.simultaneous or 1, 1)

    return #activeScenarios[scenarioKey] >= maxSimultaneous
end

local function initScenario(lobbyId, scenarioKey)
    return ScenarioRegistry.init(scenarioKey, "server", lobbyId)
end

function HeistServer.getScenarioConfig(scenarioKey)
    return config.heistScenarios[scenarioKey]
end

function HeistServer.getScenarioGameConfig(scenarioKey)
    return lib.load(("config.scenarios.%s"):format(scenarioKey))
end

function HeistServer.clearLobbyGameState(lobbyId)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end

    if lobby.activeScenario.game.vehicles then
        local scenarioVehicles = lobby.activeScenario.game.vehicles
        local netIds = {}
        for _, data in pairs(scenarioVehicles) do
            table.insert(netIds, data.vehicleNetId)
        end
        Utils.deleteNetworkedObjects(netIds)
    end

    ScenarioRegistry.clear(lobby.activeScenario.key, "server", lobby.activeScenario, lobbyId)

    lobby.activeScenario.game = {}
end

function HeistServer.clearAllLobbies()
    local lobbies = LobbyServer:getAll()
    for _, lobby in pairs(lobbies) do
        if lobby.activeScenario then
            local scenarioKey = lobby.activeScenario.key
            releaseScenario(scenarioKey, lobby.id)
            HeistServer.clearLobbyGameState(lobby.id)
            lobby.activeScenario = nil
        end
    end
end

lib.callback.register(_e("server:heist:startScenario"), function(source, data)
    local lobbyId = data.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        lobby = LobbyServer:create(source)
        lobbyId = lobby.id
        TriggerClientEvent(_e("client:lobby:setPlayerLobby"), source, lobby)
    end

    if lobby.owner ~= source then
        return { success = false, message = locale("lobby.you_are_not_leader") }
    end
    if lobby.activeScenario then
        return { success = false, message = locale("scenario.party_already_in_scenario") }
    end

    local scenarioKey = data.scenarioKey
    if not scenarioKey then
        return { success = false, message = locale("scenario.invalid_scenario_key") }
    end

    local scenarioConfig = HeistServer.getScenarioConfig(scenarioKey)
    if not scenarioConfig then
        return { success = false, message = locale("scenario.invalid_scenario_key") }
    end

    if isScenarioBusy(scenarioKey) then
        return { success = false, message = locale("scenario.already_active", scenarioKey) }
    end

    if CooldownManager.isScenarioInCooldown(scenarioKey) then
        return { success = false, message = locale("scenario.in_cooldown") }
    end

    if not Config.debug then
        if Config.policeOptions then
            local policeCount = Utils.getPoliceCount()
            if policeCount and policeCount < Config.policeOptions.requiredCops then
                return {
                    success = false,
                    message = locale("scenario.not_enough_police",
                        Config.policeOptions.requiredCops)
                }
            end
        end

        if scenarioConfig.requiredCops then
            local policeCount = Utils.getPoliceCount()
            if policeCount < scenarioConfig.requiredCops then
                return {
                    success = false,
                    message = locale("scenario.not_enough_police",
                        scenarioConfig.requiredCops)
                }
            end
        end

        if scenarioConfig.teamSize then
            if scenarioConfig.teamSize.min and #lobby.members < scenarioConfig.teamSize.min then
                return { success = false, message = locale("scenario.not_enough_players", scenarioConfig.teamSize.min) }
            end
            if scenarioConfig.teamSize.max and #lobby.members > scenarioConfig.teamSize.max then
                return { success = false, message = locale("scenario.too_many_players", scenarioConfig.teamSize.max) }
            end
        end

        if scenarioConfig.requiredItems then
            for _, item in pairs(scenarioConfig.requiredItems) do
                local itemLabel = item.label or item.name
                local itemCount = item.count or 1
                if not Inventory.hasItem(lobby.owner, item.itemName, itemCount) then
                    return {
                        success = false,
                        message = locale("lobby.missing_required_item", itemLabel, itemCount)
                    }
                end
            end
        end

        for _, member in pairs(lobby.members) do
            if member.level < scenarioConfig.level then
                return { success = false, message = locale("lobby.member_required_level", member.illegalNickname) }
            end
            if CooldownManager.isPlayerInCooldown(member.source) then
                return { success = false, message = locale("lobby.member_is_cooldown", member.name) }
            end
        end
    end

    local scenarioGameConfig = HeistServer.getScenarioGameConfig(scenarioKey)
    if not scenarioGameConfig then
        return { success = false, message = locale("scenario.invalid_scenario_key") }
    end

    local scenarioConfigClone = lib.table.deepclone(scenarioConfig)
    local scenarioGameConfigClone = lib.table.deepclone(scenarioGameConfig)

    lobby.activeScenario = {
        key = scenarioKey,
        scenario = scenarioConfigClone,
        game = scenarioGameConfigClone,
        infoTexts = scenarioConfigClone.infoTexts or {},
        duration = scenarioConfigClone.scenarioDuration and {
            maxDuration = scenarioConfigClone.scenarioDuration or 0,
            endTime = os.time() + (scenarioConfigClone.scenarioDuration * 60),
        } or nil,
    }

    local initResponse = initScenario(lobbyId, scenarioKey)
    if not initResponse then
        lobby.activeScenario = nil
        return { success = false, message = locale("scenario.error", "Initialization failed") }
    end

    if type(initResponse) == "table" and not initResponse.success then
        lobby.activeScenario = nil
        local message = type(initResponse) == "table" and initResponse.message or "Initialization failed"
        return { success = false, message = locale("scenario.error", message) }
    end

    setScenarioActive(lobbyId, scenarioKey)

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:heist:scenarioStarted"), member.source, {
            lobbyId = lobbyId,
            activeScenario = lobby.activeScenario,
        })
    end

    local success, err = pcall(Exports.onScenarioStarted, lobby, lobby.activeScenario)
    if not success then
        print(("^1[ERROR] Failed to trigger onScenarioStarted export: %s^0"):format(err))
    end

    return { success = true }
end)

lib.callback.register(_e("server:heist:stopScenario"), function(source, data)
    local lobbyId = data.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_in_lobby") }
    end

    if lobby.owner ~= source then
        return { success = false, message = locale("lobby.you_are_not_leader") }
    end
    if not lobby.activeScenario then
        return { success = false, message = locale("scenario.no_active_scenario") }
    end

    local scenarioKey = lobby.activeScenario.key
    local scenarioConfig = HeistServer.getScenarioConfig(scenarioKey)

    HeistServer.clearLobbyGameState(lobbyId)

    if scenarioConfig.scenarioCooldown and scenarioConfig.scenarioCooldown > 0 then
        CooldownManager.setScenarioCooldown(scenarioKey, scenarioConfig.scenarioCooldown)
    end

    for _, member in pairs(lobby.members) do
        if scenarioConfig.playerCooldown and scenarioConfig.playerCooldown > 0 then
            CooldownManager.setPlayerCooldown(member.source, scenarioConfig.playerCooldown)
        end
        TriggerClientEvent(_e("client:heist:scenarioStopped"), member.source, {
            lobbyId = lobbyId,
            scenarioKey = scenarioKey,
        })
    end

    local lastActiveScenario = lib.table.deepclone(lobby.activeScenario)

    lobby.activeScenario = nil
    releaseScenario(scenarioKey, lobbyId)

    local success, err = pcall(Exports.onScenarioStopped, lobby, lastActiveScenario, false)
    if not success then
        print(("^1[ERROR] Failed to trigger onScenarioStopped export: %s^0"):format(err))
    end

    return { success = true }
end)

lib.callback.register(_e("server:heist:completeScenario"), function(source, data)
    local lobbyId = data.lobbyId

    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then
        return { success = false, message = locale("lobby.not_in_lobby") }
    end

    if lobby.owner ~= source then
        return { success = false, message = locale("lobby.you_are_not_leader") }
    end

    if not lobby.activeScenario then
        return { success = false, message = locale("scenario.no_active_scenario") }
    end

    local scenarioKey = lobby.activeScenario.key

    local scenario = lobby.activeScenario.scenario
    local rewards = scenario.rewards

    -- Base reward amounts (calculated once)
    local baseMoneyAmount = rewards.money and rewards.money or 0
    local baseExpAmount = rewards.exp and rewards.exp or 0

    local teamSize = #lobby.members

    for rank, member in ipairs(lobby.members) do
        local memberSource = member.source

        -- Calculate final amounts with share multiplier
        local finalMoneyAmount = baseMoneyAmount * ((member.share or 0) / 100)
        local finalExpAmount = baseExpAmount

        -- money_reward
        if rewards.money and finalMoneyAmount > 0 then
            if Config.moneyOptions.isItem then
                Inventory.giveItem(memberSource, Config.moneyOptions.itemName, finalMoneyAmount)
            else
                Framework.playerAddMoney(memberSource, Config.moneyOptions.accountName, finalMoneyAmount)
            end
        end

        -- experience_reward
        if rewards.exp and finalExpAmount > 0 then
            ProfileServer:giveExp(memberSource, finalExpAmount)
            ProfileServer:update(memberSource)
        end

        -- item_rewards
        if rewards.items and #rewards.items > 0 then
            for _, item in pairs(rewards.items) do
                Inventory.giveItem(memberSource, item.name, item.count)
            end
        end

        if scenario.playerCooldown and scenario.playerCooldown > 0 then
            CooldownManager.setPlayerCooldown(memberSource, scenario.playerCooldown)
        end

        TriggerClientEvent(_e("client:heist:rewardReceived"), memberSource, {
            money = finalMoneyAmount,
            exp = finalExpAmount,
            items = rewards.items or {},
            rank = rank
        })
    end

    HeistServer.clearLobbyGameState(lobbyId)

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:heist:scenarioStopped"), member.source, {
            lobbyId = lobbyId,
            scenarioKey = scenarioKey,
            completed = true
        })
        LobbyServer:resetScore(lobbyId, member.source)
    end

    local lastActiveScenario = lib.table.deepclone(lobby.activeScenario)

    lobby.activeScenario = nil
    releaseScenario(scenarioKey, lobbyId)

    local scenarioConfig = HeistServer.getScenarioConfig(scenarioKey)
    if scenarioConfig.scenarioCooldown and scenarioConfig.scenarioCooldown > 0 then
        CooldownManager.setScenarioCooldown(scenarioKey, scenarioConfig.scenarioCooldown)
    end

    local success, err = pcall(Exports.onScenarioStopped, lobby, lastActiveScenario, true)
    if not success then
        print(("^1[ERROR] Failed to trigger onScenarioStopped export: %s^0"):format(err))
    end

    return { success = true, message = locale("scenario.completed_successfully") }
end)

lib.callback.register(_e("server:heist:onScenarioVehicleSpawned"), function(source, lobbyId, data)
    local lobby = LobbyServer:getLobbyById(lobbyId)
    if not lobby then return false end

    if not lobby.activeScenario then
        return false
    end

    if lobby.owner ~= source then
        return false
    end

    lobby.activeScenario.game.vehicles = lobby.activeScenario.game.vehicles or {}
    lobby.activeScenario.game.vehicles[data.vehicleIndex] = data

    local allVehiclesSpawned = false
    local spawnedVehicleCount = 0
    for _, vehicle in pairs(lobby.activeScenario.game.vehicles) do
        if vehicle and vehicle.spawned then
            spawnedVehicleCount = spawnedVehicleCount + 1
        end
    end

    if #lobby.activeScenario.game.vehicles == spawnedVehicleCount then
        allVehiclesSpawned = true
    end

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:heist:onScenarioVehicleSpawned"), member.source,
            lobbyId, data, allVehiclesSpawned, data.triggerInitAfterAllSpawned ~= false)
    end

    return true
end)

RegisterNetEvent(_e("server:heist:setHeistCompleted"), function(params)
    local source = source
    if not params.lobbyId then return end

    local lobby = LobbyServer:getLobbyById(params.lobbyId)
    if not lobby then return end
    if not lobby.activeScenario then return end

    if lobby.activeScenario.isCompleted then return end
    lobby.activeScenario.isCompleted = true

    for _, member in pairs(lobby.members) do
        TriggerClientEvent(_e("client:heist:scenarioCompleted"), member.source,
            { lobbyId = params.lobbyId })
    end
end)

lib.callback.register(_e("server:heist:getScenarioCooldowns"), function(source)
    return {
        cooldowns = CooldownManager.getAllScenarioCooldowns(),
        time = os.time()
    }
end)

-- Automatic scenario duration checker
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        local currentTime = os.time()
        local lobbies = LobbyServer:getAll()

        for _, lobby in pairs(lobbies) do
            if lobby.activeScenario and lobby.activeScenario.duration then
                local endTime = lobby.activeScenario.duration.endTime

                -- If time is up, automatically stop the scenario
                if endTime and currentTime >= endTime then
                    local scenarioKey = lobby.activeScenario.key
                    local scenarioConfig = HeistServer.getScenarioConfig(scenarioKey)

                    HeistServer.clearLobbyGameState(lobby.id)

                    if scenarioConfig.scenarioCooldown and scenarioConfig.scenarioCooldown > 0 then
                        CooldownManager.setScenarioCooldown(scenarioKey, scenarioConfig.scenarioCooldown)
                    end

                    for _, member in pairs(lobby.members) do
                        if scenarioConfig.playerCooldown and scenarioConfig.playerCooldown > 0 then
                            CooldownManager.setPlayerCooldown(member.source, scenarioConfig.playerCooldown)
                        end
                        TriggerClientEvent(_e("client:heist:scenarioStopped"), member.source, {
                            lobbyId = lobby.id,
                            scenarioKey = scenarioKey,
                            reason = "timeout"
                        })
                    end

                    lobby.activeScenario = nil
                    releaseScenario(scenarioKey, lobby.id)

                    if Config.debug then
                        print(("^3[Heist System] Scenario '%s' automatically stopped due to timeout^7")
                            :format(scenarioKey))
                    end
                end
            end
        end

        if Config.debug then
            print("^3[Heist System] Scenario duration checker executed.^7")
        end
    end
end)
