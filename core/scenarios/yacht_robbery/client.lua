local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")

local config                = require("config.scenarios.yacht_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

local GuardManagerClient    = require("core.scenarios._shared.client.guards")
local LootManagerClient     = require("core.scenarios._shared.client.loot_manager")

YachtRobberyClient          = {}

-- State management
local state                 = {
    isBusy = false,
    blips = {},
}

-- Manager instances
local managers              = {
    guards = nil,
    loot = nil,
}

local function __init_state__()
    for k in pairs(state) do
        if type(state[k]) == "table" then
            state[k] = {}
        else
            state[k] = false
        end
    end

    managers.guards = nil
    managers.loot = nil
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("yacht_robbery", locale("yacht_robbery.police_alert"), coords)
end

local function removeBlipByKey(key)
    if not state.blips[key] then return end
    RemoveBlip(state.blips[key])
    state.blips[key] = nil
end

local function addBlip(target, options, route, longRange, key)
    local blip = Utils.addBlip(target, options, route)
    SetBlipAsShortRange(blip, not longRange)
    state.blips[key] = blip
end

local function addRadiusBlip(coords, radius, color, key)
    local blip = Utils.addRadiusBlip(coords, radius, color)
    state.blips[key] = blip
end

local function isTeamLeader()
    local lobby = ClientApplication.state.lobby
    return lobby and lobby.owner == cache.serverId
end

local function spawnGuards()
    if managers.guards and managers.guards:areGuardsSpawned() then return end

    -- Initialize guard manager
    managers.guards = GuardManagerClient.new({
        guards = config.guards,
        onGuardsSpawned = function(guardNetIds)
            TriggerServerEvent(_e("server:scenarios:yacht_robbery:onGuardsSpawned"), {
                lobbyId = ClientApplication.state.lobby.id,
                guardNetIds = guardNetIds,
            })
            triggerAlert(config.yachtCoords)
        end,
    })

    -- Update target players from lobby
    if ClientApplication.state.lobby then
        managers.guards:updateTargetPlayersFromLobby(ClientApplication.state.lobby)
    end

    -- Spawn guards
    managers.guards:spawnGuards("s_m_m_armoured_01", "WEAPON_PISTOL")
end

---@param loot LootPoint
---@param lootIndex number
local function interactionWithLoot(loot, lootIndex)
    state.isBusy = true

    local animationOption = SHARED_CONFIG.animations.grabCash
    if animationOption then
        local animationDuration = animationOption.duration or 2000
        lib.playAnim(cache.ped, animationOption.dict, animationOption.name,
            8.0, -8.0, animationDuration, 1)

        Utils.progressBar({
            duration = animationDuration,
            label = locale("yacht_robbery.looting"),
            useWhileDead = false,
            canCancel = false,
            disable = {
                car = true,
                move = true,
                combat = true,
                sprint = true,
            },
        })
    end

    local response = lib.callback.await(
        _e("server:scenarios:yacht_robbery:loot"),
        false,
        { lobbyId = ClientApplication.state.lobby.id, lootIndex = lootIndex }
    )

    if response.success then
        Utils.notify(locale("yacht_robbery.looted_items"), "success")
    else
        Utils.notify(locale("yacht_robbery.loot_failed"), "error")
        if response.message then
            Utils.notify(response.message, "error", 5000)
        end
    end

    state.isBusy = false
end

local function setupLootables()
    managers.loot = LootManagerClient.new({
        loots = config.loots,
        Target = Target,
    })

    managers.loot:spawnLoots()

    managers.loot:setupTargets({
        getLootLabel = function(loot, lootIndex)
            return locale("yacht_robbery.grab_loot")
        end,
        canInteract = function(loot, lootIndex)
            return not state.isBusy and not loot.busy and not loot.looted
        end,
        onSelect = function(loot, lootIndex)
            interactionWithLoot(loot, lootIndex)
        end,
        zonePrefix = "scenario:yacht_robbery:",
        debug = Config.debug,
    })

    -- Start marker and delete threads
    managers.loot:startMarkerThread(5.0)
end

local function checkDistance()
    Citizen.CreateThread(function()
        -- Önce gemiye yakın olmasını bekle
        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(
                config.yachtCoords.x,
                config.yachtCoords.y,
                config.yachtCoords.z))

            if distance < 100.0 then
                -- Gemiye yaklaşıldığında guardları spawn et
                if isTeamLeader() then
                    spawnGuards()
                end
                -- Setup lootables for all players
                setupLootables()
                break
            end

            Citizen.Wait(1000)
        end

        -- Şimdi uzaklaşma kontrolü yap
        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(
                config.yachtCoords.x,
                config.yachtCoords.y,
                config.yachtCoords.z))

            if distance > config.requiredDistanceForFinish then
                HeistClient.completeScenario()
                Utils.notify(locale("yacht_robbery.escaped_successfully"), "success")
                break
            end

            Citizen.Wait(1000)
        end
    end)
end

function YachtRobberyClient.init()
    -- Add yacht blip
    addRadiusBlip(config.yachtCoords, 50.0, 5, "yacht_area")
    addBlip(config.yachtCoords, SHARED_CONFIG.blips.yacht or SHARED_CONFIG.blips.house, true, true, "yacht")

    Utils.notify(locale("yacht_robbery.location_marked"), "info")
    HeistClient.updateActiveInfoIndex(1)

    -- Start distance checking (guards will spawn when close to yacht)
    checkDistance()
end

function YachtRobberyClient.clear()
    -- Remove all blips
    for key, _ in pairs(state.blips) do
        removeBlipByKey(key)
    end

    if managers.guards then
        managers.guards:clear()
    end
    if managers.loot then
        managers.loot:clear()
    end

    __init_state__()
end

RegisterNetEvent(_e("client:scenarios:yacht_robbery:onGuardsSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if not managers.guards then
        managers.guards = GuardManagerClient.new({ guards = config.guards })
    end

    HeistClient.updateActiveInfoIndex(2)
    managers.guards:syncGuardsFromNetIds(params.guardNetIds)
end)

RegisterNetEvent(_e("client:scenarios:yacht_robbery:onLootUpdated"), function(params)
    if not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= params.lobbyId
    then
        return
    end

    if managers.loot then
        managers.loot:markLootLooted(params.lootIndex, true)
    end
end)
