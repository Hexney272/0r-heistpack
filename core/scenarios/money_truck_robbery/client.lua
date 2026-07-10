local lib                   = lib
local Utils                 = require("modules.utils.client")

local config                = lib.load("config.scenarios.money_truck_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

MoneyTruckRobberyClient     = {}

-- State management
local state                 = {
    isBusy = false,
    blips = {},
    zones = {},
    truckNetId = nil,
    escortNetId = nil,
    guardNetIds = {},
    timeoutThread = false,
    backGuard = nil,
    doorProgress = 0,       -- Single progress for both doors
    openedDoor = nil,       -- Track which door was opened (left or right)
    drillProp = nil,        -- Drill prop in hand
    doorOpenedTime = 0,     -- Track when door was opened (to prevent accidental E press)
    particleActive = false, -- Track particle effect state
    textUI = false,         -- Track TextUI state
}

---@section INTERNAL FUNCTIONS

-- Helper function to draw 3D text
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = #(vec3(px, py, pz) - vec3(x, y, z))

    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

local function __init_state__()
    for k in pairs(state) do
        if type(state[k]) == "table" then
            state[k] = {}
        else
            state[k] = false
        end
    end
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("money_truck_robbery", locale("money_truck_robbery.police_alert"), coords)
end

local function removeBlipByKey(key)
    if not state.blips[key] then return end
    if DoesBlipExist(state.blips[key]) then
        RemoveBlip(state.blips[key])
    end
    state.blips[key] = nil
end

local function addBlip(target, options, route, longRange, key)
    removeBlipByKey(key)
    local blip = Utils.addBlip(target, options, route)
    SetBlipAsShortRange(blip, not longRange)
    state.blips[key] = blip
end

local function addRadiusBlip(coords, radius, key)
    local radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(radiusBlip, 1)
    SetBlipAlpha(radiusBlip, 128)
    state.blips[key] = radiusBlip
end

---@section DRILL & TEXTUI HELPER FUNCTIONS

-- Helper function to create drill prop with particle effects
local function createDrillProp(playerPed)
    local drillModel = GetHashKey("hei_prop_heist_drill")
    lib.requestModel(drillModel)

    -- Create drill prop
    local boneIndex = GetPedBoneIndex(playerPed, 57005) -- Right hand bone
    local drillProp = CreateObject(drillModel, 0, 0, 0, true, true, true)

    AttachEntityToEntity(
        drillProp,
        playerPed,
        boneIndex,
        0.14, 0.0, -0.01,
        90.0, -90.0, 180.0,
        true, true, false, true, 1, true
    )

    -- Request particle effect
    local particleDict = "core"
    local particleEffect = "ent_amb_elec_crackle"
    lib.requestNamedPtfxAsset(particleDict)

    UseParticleFxAssetNextCall(particleDict)
    local effect = StartParticleFxLoopedOnEntity(
        particleEffect,
        drillProp,
        0.0, -0.6, 0.0,
        0.0, 0.0, 0.0,
        0.3,
        false, false, false
    )

    -- Play drilling animation
    lib.requestAnimDict("anim@heists@fleeca_bank@drilling")
    TaskPlayAnim(playerPed, "anim@heists@fleeca_bank@drilling", "drill_straight_idle", 8.0,
        -8.0, -1, 1, 0, false, false, false)

    SetModelAsNoLongerNeeded(drillModel)

    return drillProp, effect, particleDict
end

-- Helper function to clean up drill prop and effects
local function cleanupDrillProp(playerPed, drillProp, effect, particleDict)
    if drillProp and DoesEntityExist(drillProp) then
        DeleteEntity(drillProp)
        ClearPedTasks(playerPed)
    end

    if effect then
        StopParticleFxLooped(effect, false)
    end

    if particleDict then
        RemoveNamedPtfxAsset(particleDict)
    end
end

-- Helper function to manage TextUI state
local function updateTextUI(show, message, key)
    if show and not state.textUI then
        state.textUI = true
        Utils.showTextUI(message, key)
    elseif not show and state.textUI then
        state.textUI = false
        Utils.hideTextUI()
    end
end

---@section GUARD HELPER FUNCTIONS

-- Helper function to get all lobby members as target players
local function getTargetPlayers()
    local targetPlayers = {}
    if ClientApplication.state.lobby then
        for _, member in pairs(ClientApplication.state.lobby.members) do
            local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
            if DoesEntityExist(memberPed) then
                table.insert(targetPlayers, memberPed)
            end
        end
    end
    return targetPlayers
end

-- Helper function to find nearest player to a position
local function findNearestPlayer(guardCoords, targetPlayers)
    local nearestPlayer = nil
    local nearestDistance = math.huge

    for _, playerPed in ipairs(targetPlayers) do
        if DoesEntityExist(playerPed) then
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(guardCoords - playerCoords)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = playerPed
            end
        end
    end

    return nearestPlayer
end

-- Helper function to configure guard properties
local function configureGuard(guard)
    SetPedArmour(guard, 100)
    SetPedMaxHealth(guard, 300)
    SetEntityHealth(guard, 300)
    GiveWeaponToPed(guard, GetHashKey("WEAPON_CARBINERIFLE"), 250, false, true)
    SetPedCombatAttributes(guard, 46, true)
    SetPedCombatAbility(guard, 100)
    SetPedCombatMovement(guard, 2)
    SetPedCombatRange(guard, 2)
    SetPedFleeAttributes(guard, 0, false)
    SetPedAsEnemy(guard, true)
    SetPedRelationshipGroupDefaultHash(guard, GetHashKey("COP"))
    SetPedRelationshipGroupHash(guard, GetHashKey("COP"))
    SetPedDropsWeaponsWhenDead(guard, false)
end

-- Helper function to create guard attack behavior
local function createGuardAttackBehavior(guard, vehicle, targetPlayers, blockEvents)
    SetBlockingOfNonTemporaryEvents(guard, blockEvents or false)

    if not blockEvents then
        Citizen.CreateThread(function()
            while ClientApplication.state.activeScenario and DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) do
                Citizen.Wait(1000)

                -- Check if vehicle is being attacked or guard is being shot at
                if HasEntityBeenDamagedByAnyPed(vehicle) or HasEntityBeenDamagedByAnyVehicle(vehicle) or IsPedBeingStunned(guard, 0) then
                    -- Make guard leave vehicle
                    TaskLeaveVehicle(guard, vehicle, 256)
                    Citizen.Wait(2000)

                    -- Target nearest player from team
                    if #targetPlayers > 0 then
                        local guardCoords = GetEntityCoords(guard)
                        local nearestPlayer = findNearestPlayer(guardCoords, targetPlayers)

                        if nearestPlayer then
                            TaskCombatPed(guard, nearestPlayer, 0, 16)
                        end
                    end
                    break
                end
            end
        end)
    end
end

-- Helper function to get network ID for entity
local function getEntityNetworkId(entity, entityType)
    return lib.waitFor(function()
        if not NetworkGetEntityIsNetworked(entity) then
            NetworkRegisterEntityAsNetworked(entity)
        else
            local netId = entityType == "ped" and PedToNet(entity) or
                entityType == "vehicle" and VehToNet(entity) or
                ObjToNet(entity)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, nil, false)
end

---@section TRUCK SPAWN & GUARD FUNCTIONS

local function spawnGuardsInTruck(truck)
    local guardModel = GetHashKey("s_m_m_armoured_01")
    lib.requestModel(guardModel)

    local targetPlayers = getTargetPlayers()

    -- Spawn driver and front passenger guards (seats -1 and 0)
    local frontSeats = { -1, 0 }
    for _, seat in ipairs(frontSeats) do
        local guard = CreatePedInsideVehicle(truck, 26, guardModel, seat, true, true)
        configureGuard(guard)
        createGuardAttackBehavior(guard, truck, targetPlayers, false)

        local guardNetId = getEntityNetworkId(guard, "ped")
        table.insert(state.guardNetIds, guardNetId)
    end

    -- Spawn back guard (seat 1) - stays inside until back door opens
    local backGuard = CreatePedInsideVehicle(truck, 26, guardModel, 1, true, true)
    configureGuard(backGuard)
    createGuardAttackBehavior(backGuard, truck, targetPlayers, true) -- Block events until door opens

    state.backGuard = backGuard

    local backGuardNetId = getEntityNetworkId(backGuard, "ped")
    table.insert(state.guardNetIds, backGuardNetId)

    SetModelAsNoLongerNeeded(guardModel)
end

local function makeTruckDriveWander(truck)
    if not DoesEntityExist(truck) then return end

    local driver = GetPedInVehicleSeat(truck, -1)
    if DoesEntityExist(driver) then
        TaskVehicleDriveWander(driver, truck, 80.0, 443)
    end
end

local function spawnEscortVehicle(truck)
    if not DoesEntityExist(truck) then return end

    -- Create escort vehicle
    local escortModel = GetHashKey(config.escortVehicleModel)
    lib.requestModel(escortModel)

    local truckCoords = GetEntityCoords(truck)
    local truckHeading = GetEntityHeading(truck)
    local behindOffset = GetOffsetFromEntityInWorldCoords(truck, 0.0, -10.0, 0.0)

    local escort = CreateVehicle(escortModel, behindOffset.x, behindOffset.y, behindOffset.z, truckHeading, true, true)

    while not DoesEntityExist(escort) do
        Citizen.Wait(100)
    end

    -- Configure escort vehicle
    SetVehicleEngineOn(escort, true, true, false)
    SetVehicleDirtLevel(escort, 0.0)
    SetVehicleDoorsLocked(escort, 2)

    -- Spawn escort guards
    local guardModel = GetHashKey("s_m_m_armoured_01")
    lib.requestModel(guardModel)

    local targetPlayers = getTargetPlayers()
    local escortSeats = { -1, 0 } -- Driver and passenger

    for _, seat in ipairs(escortSeats) do
        local guard = CreatePedInsideVehicle(escort, 26, guardModel, seat, true, true)
        configureGuard(guard)
        createGuardAttackBehavior(guard, escort, targetPlayers, false)

        local guardNetId = getEntityNetworkId(guard, "ped")
        table.insert(state.guardNetIds, guardNetId)
    end

    -- Make escort follow the truck
    local escortDriver = GetPedInVehicleSeat(escort, -1)
    if DoesEntityExist(escortDriver) then
        TaskVehicleEscort(escortDriver, escort, truck, -1, 80.0, 443, 5.0, -1, 50.0)
    end

    -- Add blip to escort
    addBlip(escort, SHARED_CONFIG.blips.escort, true, false, "escort")

    -- Cleanup models
    SetModelAsNoLongerNeeded(escortModel)
    SetModelAsNoLongerNeeded(guardModel)

    return getEntityNetworkId(escort, "vehicle")
end

local function spawnTruck(locationIndex)
    local location = config.locations[locationIndex]
    if not location then return end

    -- Add radius blip first
    addRadiusBlip(location.truckCoords, 120.0, "radiusBlip")
    SetNewWaypoint(location.truckCoords.x, location.truckCoords.y)

    -- Check distance thread
    Citizen.CreateThread(function()
        local truckSpawned = false
        local playerPed = cache.ped

        while ClientApplication.state.activeScenario and not truckSpawned do
            Citizen.Wait(1000)

            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - vec3(location.truckCoords.x, location.truckCoords.y, location.truckCoords.z))

            if distance < 190.0 then
                -- Remove radius blip
                removeBlipByKey("radiusBlip")

                -- Spawn the truck
                local vehicleModel = GetHashKey(config.vehicleModel)
                lib.requestModel(vehicleModel)

                local coords = location.truckCoords
                local truck = CreateVehicle(vehicleModel, coords.x, coords.y, coords.z, coords.w, true, true)

                while not DoesEntityExist(truck) do
                    Citizen.Wait(100)
                end

                SetVehicleEngineOn(truck, true, true, false)
                SetVehicleDirtLevel(truck, 0.0)
                SetVehicleDoorsLocked(truck, 2) -- Lock all doors initially

                -- Lock back doors permanently
                SetVehicleDoorsLockedForAllPlayers(truck, true)
                SetVehicleDoorShut(truck, 2, false) -- Back left closed
                SetVehicleDoorShut(truck, 3, false) -- Back right closed

                -- Spawn guards inside the truck
                spawnGuardsInTruck(truck)

                -- Make truck drive
                makeTruckDriveWander(truck)

                -- Add blip to truck
                addBlip(truck, SHARED_CONFIG.blips.truck, true, false, "truck")

                SetModelAsNoLongerNeeded(vehicleModel)

                -- Send truck spawn info to server
                local truckNetId = getEntityNetworkId(truck, "vehicle")

                -- Spawn escort vehicle
                local escortNetId = spawnEscortVehicle(truck)

                TriggerServerEvent(_e("server:scenarios:money_truck_robbery:onTruckSpawned"), {
                    lobbyId = ClientApplication.state.lobby.id,
                    truckNetId = truckNetId,
                    escortNetId = escortNetId,
                    guardNetIds = state.guardNetIds,
                })

                truckSpawned = true
            end
        end
    end)
end

local function startBlipMonitorThread()
    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario do
            Citizen.Wait(5000)
            if not ClientApplication.state.activeScenario then break end

            -- Monitor truck blip
            if ClientApplication.state.activeScenario.game.truckNetId then
                local truckNetId = ClientApplication.state.activeScenario.game.truckNetId

                -- Check if we can see the entity
                if NetworkDoesNetworkIdExist(truckNetId) then
                    local truck = NetToVeh(truckNetId)

                    if DoesEntityExist(truck) then
                        -- Entity exists, update blip
                        if not state.blips["truck"] or not DoesBlipExist(state.blips["truck"]) then
                            addBlip(truck, SHARED_CONFIG.blips.truck, true, false, "truck")
                        elseif DoesBlipExist(state.blips["truck"]) then
                            SetBlipCoords(state.blips["truck"], GetEntityCoords(truck))
                        end
                    end
                end
            end

            -- Monitor escort blip
            if ClientApplication.state.activeScenario.game.escortNetId then
                local escortNetId = ClientApplication.state.activeScenario.game.escortNetId

                if NetworkDoesNetworkIdExist(escortNetId) then
                    local escort = NetToVeh(escortNetId)

                    if DoesEntityExist(escort) then
                        if not state.blips["escort"] or not DoesBlipExist(state.blips["escort"]) then
                            addBlip(escort, SHARED_CONFIG.blips.escort, true, false, "escort")
                        else
                            SetBlipCoords(state.blips["escort"], GetEntityCoords(escort))
                        end
                    end
                end
            end
        end
    end)
end

local function setupTruckBackDoorsThread()
    Citizen.CreateThread(function()
        local drillEffect = nil
        local particleDict = nil

        while ClientApplication.state.activeScenario and not ClientApplication.state.activeScenario.game.truckOpened do
            local wait = 0
            local truckNetId = ClientApplication.state.activeScenario.game.truckNetId

            if NetworkDoesNetworkIdExist(truckNetId) then
                local truck = NetToVeh(truckNetId)

                if DoesEntityExist(truck) then
                    -- Keep back doors locked at all times
                    SetVehicleDoorsLockedForPlayer(truck, cache.playerId, 2) -- Back left
                    SetVehicleDoorsLockedForPlayer(truck, cache.playerId, 3) -- Back right

                    local playerPed = cache.ped
                    local playerCoords = GetEntityCoords(playerPed)
                    local backCenterCoords = GetOffsetFromEntityInWorldCoords(truck, 0.0, -3.5, 0.5)
                    local distance = #(playerCoords - backCenterCoords)
                    local currentProgress = state.doorProgress

                    if distance < 2.0 and not state.isBusy then
                        -- Handle TextUI display
                        if not state.drillProp then
                            updateTextUI(true, locale("money_truck_robbery.hold_e_progress", math.floor(currentProgress)),
                                "E")
                        else
                            updateTextUI(false)
                            -- Draw 3D text with progress when drilling
                            DrawText3D(
                                backCenterCoords.x, backCenterCoords.y, backCenterCoords.z,
                                locale("money_truck_robbery.progress", math.floor(currentProgress))
                            )
                        end

                        -- Handle E key press
                        if IsControlPressed(0, 38) then -- E key held down
                            -- Create drill prop if not exists
                            if not state.drillProp or not DoesEntityExist(state.drillProp) then
                                state.drillProp, drillEffect, particleDict = createDrillProp(playerPed)
                            end

                            if currentProgress < 100 then
                                -- Increment progress
                                state.doorProgress = math.min(100, currentProgress + 0.1)
                            else
                                -- Progress complete, trigger door opening
                                if not ClientApplication.state.activeScenario.game.truckOpened then
                                    state.isBusy = true

                                    -- Determine which door to open based on player position
                                    local truckToPlayer = playerCoords - GetEntityCoords(truck)
                                    local leftSide = GetOffsetFromEntityGivenWorldCoords(truck, truckToPlayer.x,
                                        truckToPlayer.y, truckToPlayer.z)
                                    state.openedDoor = leftSide.x < 0 and "left" or "right"

                                    -- Clean up drill
                                    cleanupDrillProp(playerPed, state.drillProp, drillEffect, particleDict)
                                    state.drillProp = nil
                                    drillEffect = nil
                                    particleDict = nil

                                    TriggerServerEvent(_e("server:scenarios:money_truck_robbery:onTruckOpened"), {
                                        lobbyId = ClientApplication.state.lobby.id,
                                        openedDoor = state.openedDoor,
                                    })

                                    state.isBusy = false
                                    break
                                end
                            end
                        else
                            -- E key released, clean up drill
                            if state.drillProp then
                                cleanupDrillProp(playerPed, state.drillProp, drillEffect, particleDict)
                                state.drillProp = nil
                                drillEffect = nil
                                particleDict = nil
                            end
                        end
                    else
                        -- Player moved away, clean up everything
                        if state.drillProp then
                            cleanupDrillProp(playerPed, state.drillProp, drillEffect, particleDict)
                            state.drillProp = nil
                            drillEffect = nil
                            particleDict = nil
                        end
                        updateTextUI(false)
                    end
                end
            end

            Citizen.Wait(wait)
        end

        -- Final cleanup when thread ends
        if state.drillProp then
            cleanupDrillProp(cache.ped, state.drillProp, drillEffect, particleDict)
            state.drillProp = nil
        end
        updateTextUI(false)
    end)
end

local function spawnLootableMoneys()
    local truckNetId = ClientApplication.state.activeScenario.game.truckNetId
    if not NetworkDoesNetworkIdExist(truckNetId) then return end

    local truck = NetToVeh(truckNetId)

    if not DoesEntityExist(truck) then return end

    -- Spawn single cash crate inside the truck
    local moneyModel = GetHashKey(SHARED_CONFIG.models.cashCrate)
    lib.requestModel(moneyModel)

    -- Spawn at the back center of the truck
    local spawnCoords = GetOffsetFromEntityInWorldCoords(truck, 0.0, -2.0, 0.2)
    local money = CreateObject(moneyModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, false)
    FreezeEntityPosition(money, true)
    SetEntityCollision(money, false, true)

    local truckHeading = GetEntityHeading(truck)
    SetEntityHeading(money, truckHeading)

    -- Make networked
    local moneyNetId = lib.waitFor(function()
        if not NetworkGetEntityIsNetworked(money) then
            NetworkRegisterEntityAsNetworked(money)
        else
            local netId = ObjToNet(money)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, nil, false)

    SetModelAsNoLongerNeeded(moneyModel)

    -- Send money spawn info to server
    TriggerServerEvent(_e("server:scenarios:money_truck_robbery:onMoneysSpawned"), {
        lobbyId = ClientApplication.state.lobby.id,
        moneyNetId = moneyNetId,
    })
end

---@section TIMEOUT THREAD

local function startTimeoutThread(locationIndex)
    if state.timeoutThread then return end

    local location = config.locations[locationIndex]
    if not location or not location.timeLimit then return end

    state.timeoutThread = true

    Citizen.CreateThread(function()
        local timeLimit = location.timeLimit
        local startTime = GetGameTimer()

        while ClientApplication.state.activeScenario and state.timeoutThread do
            local elapsedTime = (GetGameTimer() - startTime) / 1000

            if elapsedTime >= timeLimit then
                -- Time's up, fail the heist
                if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
                    TriggerServerEvent(_e("server:heist:stopScenario"), {
                        lobbyId = ClientApplication.state.lobby.id,
                    })
                    Utils.notify(locale("money_truck_robbery.time_up"), "error", 5000)
                end
                break
            end

            Citizen.Wait(1000)
        end

        state.timeoutThread = false
    end)
end

---@section PUBLIC FUNCTIONS

function MoneyTruckRobberyClient.clear()
    for key, _ in pairs(state.blips) do
        removeBlipByKey(key)
    end

    __init_state__()
end

function MoneyTruckRobberyClient.init()
    if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
        local locationIndex = ClientApplication.state.activeScenario.game.locationIndex
        spawnTruck(locationIndex)
        startTimeoutThread(locationIndex)
    end
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("client:scenarios:money_truck_robbery:onTruckSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    ClientApplication.state.activeScenario.game.truckNetId = params.truckNetId
    ClientApplication.state.activeScenario.game.escortNetId = params.escortNetId
    ClientApplication.state.activeScenario.game.locationIndex = params.locationIndex

    -- Start blip monitor thread for all clients
    startBlipMonitorThread()

    Citizen.CreateThread(function()
        local truck = lib.waitFor(function()
            if NetworkDoesNetworkIdExist(params.truckNetId) then
                local entity = NetToVeh(params.truckNetId)
                if DoesEntityExist(entity) then
                    return entity
                end
            end
        end, nil, false)
        if not truck then
            Utils.notify(locale("money_truck_robbery.truck_not_found"), "error", 5000)
            return
        end

        state.truckNetId = params.truckNetId
        state.escortNetId = params.escortNetId

        addBlip(truck, SHARED_CONFIG.blips.truck, true, false, "truck")

        -- Add escort blip
        if params.escortNetId then
            local escort = lib.waitFor(function()
                if NetworkDoesNetworkIdExist(params.escortNetId) then
                    local entity = NetToVeh(params.escortNetId)
                    if DoesEntityExist(entity) then
                        return entity
                    end
                end
            end, nil, false)

            if escort then
                addBlip(escort, SHARED_CONFIG.blips.escort, true, false, "escort")
            end
        end

        setupTruckBackDoorsThread()
        Utils.notify(locale("money_truck_robbery.truck_spawned"), "info", 5000)
    end)
end)

RegisterNetEvent(_e("client:scenarios:money_truck_robbery:onTruckOpened"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    ClientApplication.state.activeScenario.game.truckOpened = true
    local openedDoor = params.openedDoor -- Get which door was opened

    -- Record when door was opened (for cooldown)
    state.doorOpenedTime = GetGameTimer()

    -- Open and break BOTH back doors
    local truckNetId = ClientApplication.state.activeScenario.game.truckNetId
    if NetworkDoesNetworkIdExist(truckNetId) then
        local truck = NetToVeh(truckNetId)
        if DoesEntityExist(truck) then
            -- Open both back doors
            SetVehicleDoorOpen(truck, 2, false, true) -- Back left
            SetVehicleDoorOpen(truck, 3, false, true) -- Back right
            FreezeEntityPosition(truck, true)

            -- Wait a moment then break both doors off
            Citizen.SetTimeout(100, function()
                if DoesEntityExist(truck) then
                    SetVehicleDoorBroken(truck, 2, false) -- Break left door off
                    SetVehicleDoorBroken(truck, 3, false) -- Break right door off
                end
            end)
        end
    end

    -- Release back guard when doors open
    if state.backGuard and DoesEntityExist(state.backGuard) and not IsPedDeadOrDying(state.backGuard, true) then
        if NetworkDoesNetworkIdExist(truckNetId) then
            local truck = NetToVeh(truckNetId)
            if DoesEntityExist(truck) then
                SetBlockingOfNonTemporaryEvents(state.backGuard, false)

                -- Make back guard exit and engage players
                Citizen.CreateThread(function()
                    Citizen.Wait(1000) -- Wait a moment for doors to open
                    TaskLeaveVehicle(state.backGuard, truck, 256)
                    TaskEveryoneLeaveVehicle(truck)

                    -- Get all lobby members for targeting
                    local targetPlayers = {}
                    if ClientApplication.state.lobby then
                        for _, member in pairs(ClientApplication.state.lobby.members) do
                            local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
                            if DoesEntityExist(memberPed) then
                                table.insert(targetPlayers, memberPed)
                            end
                        end
                    end

                    if #targetPlayers > 0 then
                        local guardCoords = GetEntityCoords(state.backGuard)
                        local nearestPlayer = nil
                        local nearestDistance = 999999.0

                        for _, playerPed in ipairs(targetPlayers) do
                            if DoesEntityExist(playerPed) then
                                local playerCoords = GetEntityCoords(playerPed)
                                local distance = #(guardCoords - playerCoords)
                                if distance < nearestDistance then
                                    nearestDistance = distance
                                    nearestPlayer = playerPed
                                end
                            end
                        end

                        if nearestPlayer then
                            TaskCombatPed(state.backGuard, nearestPlayer, 0, 16)
                        end
                    end
                end)
            end
        end
    end

    -- Spawn lootable moneys (only owner)
    if ClientApplication.state.lobby.owner == cache.serverId then
        spawnLootableMoneys()
        triggerAlert(GetEntityCoords(NetToVeh(truckNetId)))
    end

    HeistClient.updateActiveInfoIndex(3)
    Utils.notify(locale("money_truck_robbery.truck_opened"), "success", 5000)
end)

RegisterNetEvent(_e("client:scenarios:money_truck_robbery:onMoneysSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if not params.moneyNetId then
        return
    end

    local money = nil

    -- Wait for money to load
    local timeout = GetGameTimer() + 30000
    while not NetworkDoesEntityExistWithNetworkId(params.moneyNetId) and GetGameTimer() < timeout do
        Citizen.Wait(100)
    end

    if not NetworkDoesEntityExistWithNetworkId(params.moneyNetId) then
        print("^1[0r-heistpack] Money entity not found^0")
        return
    end

    money = NetToObj(params.moneyNetId)

    -- Wait for entity to exist
    timeout = GetGameTimer() + 5000
    while not DoesEntityExist(money) and GetGameTimer() < timeout do
        Citizen.Wait(50)
    end

    if not DoesEntityExist(money) then
        print("^1[0r-heistpack] Money entity does not exist^0")
        return
    end

    -- Collect it
    local function collectMoney()
        if ClientApplication.state.activeScenario.game.moneyCollected then
            return
        end

        Utils.progressBar({
            duration = config.collectMoneyAnimation.duration,
            label = locale("money_truck_robbery.collecting_money"),
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
            anim = { dict = config.collectMoneyAnimation.dict, clip = config.collectMoneyAnimation.name },
        })

        TriggerServerEvent(_e("server:scenarios:money_truck_robbery:onMoneyCollected"), {
            lobbyId = ClientApplication.state.lobby.id,
        })
        ClientApplication.state.activeScenario.game.moneyCollected = true
        DeleteEntity(money)
        HeistClient.updateActiveInfoIndex(4)
    end

    -- Check distance to truck back door instead of money object
    CreateThread(function()
        local truckNetId = ClientApplication.state.activeScenario.game.truckNetId
        local collectProgress = 0
        local isCollecting = false
        local textui = false

        while ClientApplication.state.activeScenario and not ClientApplication.state.activeScenario.game.moneyCollected do
            local sleep = 100

            if NetworkDoesNetworkIdExist(truckNetId) and DoesEntityExist(money) then
                local truck = NetToVeh(truckNetId)

                if DoesEntityExist(truck) then
                    local playerCoords = GetEntityCoords(cache.ped)
                    -- Get back door position
                    local backDoorCoords = GetOffsetFromEntityInWorldCoords(truck, 0.0, -3.5, 0.5)
                    local distance = #(playerCoords - backDoorCoords)

                    -- Check if enough time has passed since door opened (1 second cooldown)
                    local timeSinceDoorOpened = GetGameTimer() - state.doorOpenedTime
                    local canCollect = timeSinceDoorOpened >= 1000

                    if distance < 2.0 and canCollect then
                        sleep = 0

                        if not textui then
                            textui = true
                            Utils.showTextUI(locale("money_truck_robbery.press_e_collect_money"), "E")
                        end

                        if IsControlJustPressed(0, 38) then -- E key
                            collectMoney()
                            break
                        end
                    else
                        -- Reset progress if moved away or cooldown not done
                        if isCollecting then
                            isCollecting = false
                            collectProgress = 0
                        end

                        if textui then
                            textui = false
                            Utils.hideTextUI()
                        end
                    end
                end
            end

            Citizen.Wait(sleep)
        end

        if textui then
            Utils.hideTextUI()
        end
    end)
end)

RegisterNetEvent(_e("client:scenarios:money_truck_robbery:onMoneyCollected"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    ClientApplication.state.activeScenario.game.moneyCollected = true

    -- Complete heist
    if ClientApplication.state.lobby.owner == cache.serverId then
        TriggerServerEvent(_e("server:heist:setHeistCompleted"), {
            lobbyId = ClientApplication.state.lobby.id,
            reason = "money_collected",
        })
    end

    HeistClient.updateActiveInfoIndex(3)
end)
