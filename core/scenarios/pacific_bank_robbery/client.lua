local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")
local DoorManagerClient     = require("core.scenarios._shared.client.doors")
local TrolleyManagerClient  = require("core.scenarios._shared.client.trolleys")
local GuardManagerClient    = require("core.scenarios._shared.client.guards")

local config                = lib.load("config.scenarios.pacific_bank_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

PacificBankRobberyClient    = {}

-- State management
local state                 = {
    isBusy = false,
    blips = {},
    temporaryObjects = {},
    cashPileProps = {},
    zones = {},
    distanceForFinishWorking = false,
}

-- Manager instances
local managers              = {
    doors = nil,
    trolleys = nil,
    guards = nil,
}

local SV_MAP_TYPE           = config.hasCustomMap and "custom" or "standart"

---@section INTERNAL FUNCTIONS

local function __init_state__()
    for k in pairs(state) do
        if type(state[k]) == "table" then
            state[k] = {}
        else
            state[k] = false
        end
    end

    managers.doors = nil
    managers.trolleys = nil
    managers.guards = nil
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("pacific_bank_robbery", locale("pacific_bank_robbery.police_alert"), coords)
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

---@section DRONE & BOMB DROP FUNCTIONS

local function dropBomb(zoneIndex, droneCoords, targetCoords)
    local dropPropModel = config.bombDropOptions.dropPropModel
    lib.requestModel(dropPropModel)

    local dropObject = Utils.createObject({
        model = dropPropModel,
        coords = vector3(droneCoords.x, droneCoords.y, droneCoords.z - 1.0),
        freeze = false,
        isNetwork = true,
    })

    SetEntityDynamic(dropObject, true)
    ActivatePhysics(dropObject)
    SetEntityDrawOutline(dropObject, true)

    Citizen.CreateThread(function()
        if targetCoords.z then
            while ClientApplication.state.activeScenario do
                Citizen.Wait(500)
                local dropCoords = GetEntityCoords(dropObject)
                if (dropCoords.z - 2.5) < targetCoords.z then
                    break
                end
            end
        end
        DeleteObject(dropObject)
        lib.callback.await(_e("server:scenarios:pacific_bank_robbery:onBombDropped"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            zoneIndex = zoneIndex,
            coords = targetCoords,
        })
    end)
end

local function nearDroneUsageAreaThread()
    local droneOptions = DroneClient:getOptions()
    local droneModel = droneOptions.propModel
    local droneCoords = config.bombDropOptions.locations.usage

    local temporaryObject = Utils.createObject({
        model = droneModel,
        coords = droneCoords,
        freeze = true,
        isNetwork = false,
    })
    state.temporaryObjects["bomb_drop_zone_usage"] = temporaryObject
    SetEntityAlpha(temporaryObject, 150, false)
    SetEntityDrawOutline(temporaryObject, true)
    SetEntityDrawOutlineColor(189, 219, 9, 255)
    SetEntityDrawOutlineShader(1)
    SetEntityInvincible(temporaryObject, true)
    SetEntityCollision(temporaryObject, false, true)

    Citizen.CreateThread(function()
        local isItFirstTime = true
        local textUI = false

        while ClientApplication.state.activeScenario and
            ClientApplication.state.activeScenario.game and
            not ClientApplication.state.activeScenario.game.bombDropOptions.allDropped
        do
            local wait = 1000

            if not DroneClient:isActive() then
                local playerPedId = cache.ped
                local pedCoords = GetEntityCoords(playerPedId)
                local distance = #(pedCoords - config.bombDropOptions.locations.usage)

                if distance < 1.5 then
                    wait = 0
                    if not textUI and not DroneClient:isActive() then
                        textUI = true
                        Utils.showTextUI(locale("pacific_bank_robbery.use_drone"), "E")
                    end

                    if IsControlJustPressed(0, 38) then
                        Utils.hideTextUI()
                        if isItFirstTime then
                            isItFirstTime = false

                            local dropZones = ClientApplication.state.activeScenario.game.bombDropOptions.locations
                                .dropZones
                            for index, zone in pairs(dropZones) do
                                addBlip(zone.coords, SHARED_CONFIG.blips.bomb_drop_zone, false, true,
                                    "bomb_drop_zone_" .. index)
                            end

                            HeistClient.updateActiveInfoIndex(2)
                            HeistClient.updateActiveInfoProgress(0, #dropZones)
                        end

                        DroneClient:create(droneOptions,
                            config.bombDropOptions.locations.usage,
                            config.bombDropOptions.locations.dropZones,
                            function(zoneIndex)
                                if not ClientApplication.state.activeScenario then return false end

                                local dropZone =
                                    ClientApplication.state.activeScenario.game.bombDropOptions.locations.dropZones
                                    [zoneIndex]
                                if not dropZone then return false end

                                return not dropZone.dropped
                            end,
                            function(zoneIndex, droneCoords, targetCoords)
                                dropBomb(zoneIndex, droneCoords, targetCoords)
                            end)

                        wait = 1000
                    end
                elseif textUI then
                    textUI = false
                    Utils.hideTextUI()
                end
            end

            Citizen.Wait(wait)
        end

        for _, value in pairs({ "drop_arena", "bomb_drop_zone_usage", "bomb_drop_zone_radius" }) do
            removeBlipByKey(value)
        end

        local temporaryObject = state.temporaryObjects["bomb_drop_zone_usage"]
        if DoesEntityExist(temporaryObject) then
            DeleteEntity(temporaryObject)
            state.temporaryObjects["bomb_drop_zone_usage"] = nil
        end
    end)
end

---@section DOOR UNLOCK FUNCTIONS

local function openDoorWithBomb(doorIndex)
    state.isBusy = true

    if not managers.doors then
        state.isBusy = false
        return
    end

    local plantAnimResponse = managers.doors:playPlantBombAnimation(doorIndex)
    if plantAnimResponse.error then
        state.isBusy = false
        if plantAnimResponse.message then
            Utils.notify(plantAnimResponse.message, "error")
        end
        return
    end

    TriggerServerEvent(_e("server:scenarios:pacific_bank_robbery:onBombPlantOnDoor"), {
        lobbyId = ClientApplication.state.lobby.id,
        doorId = doorIndex,
        bombRot = plantAnimResponse.rotation
    })

    state.isBusy = false
end

local function openDoorWithSkillbar(doorIndex, skillbarType, meta)
    state.isBusy = true

    local playerPedId = cache.ped
    local animDict    = "anim@heists@keypad@"
    local animName    = "idle_a"
    lib.requestAnimDict(animDict)
    TaskPlayAnim(playerPedId, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    local skillbarSuccess = Skillbar.show(skillbarType, meta)

    if skillbarSuccess then
        TriggerServerEvent(_e("server:scenarios:pacific_bank_robbery:onDoorUnlocked"), {
            lobbyId = ClientApplication.state.lobby.id,
            doorId = doorIndex,
            unlockType = skillbarType
        })
    end

    state.isBusy = false
    ClearPedTasks(playerPedId)
    RemoveAnimDict(animDict)
end

---@section ATM ROBBERY FUNCTIONS

local function robAtmWithHack(groupIndex)
    state.isBusy = true

    local response = HackingDeviceClient:show()
    if not response then
        state.isBusy = false
        return
    end

    TriggerServerEvent(_e("server:scenarios:pacific_bank_robbery:onAtmHacked"), {
        lobbyId = ClientApplication.state.lobby.id,
        groupIndex = groupIndex,
    })

    state.isBusy = false
end

local function targetableScatteredLootProp(atmModel, atmCoords, groupIndex, atmIndex)
    local closestAtmObject = GetClosestObjectOfType(atmCoords.x, atmCoords.y, atmCoords.z, 1.0,
        atmModel, false, false, false)
    if not DoesEntityExist(closestAtmObject) then return end

    local offset = GetOffsetFromEntityInWorldCoords(closestAtmObject, 0.0, -.5, 1.0)
    local rotation = GetEntityRotation(closestAtmObject, 2)
    local model = "bkr_prop_bkr_cashpile_05"

    local prop = Utils.createObject({
        model = model,
        coords = offset,
        rotation = rotation,
        freeze = true,
        isNetwork = false,
    })
    state.cashPileProps[groupIndex .. "_" .. atmIndex] = prop

    for i = 1, 10 do
        if PlaceObjectOnGroundProperly(prop) then break end
        Citizen.Wait(500)
    end

    local zoneName = "scenario:atm_robbery:scattered_loot_zone:" .. groupIndex .. "_" .. atmIndex
    state.zones["scattered_loot_" .. groupIndex .. "_" .. atmIndex] = zoneName

    Target.addBoxZone(zoneName, {
        name = zoneName,
        coords = GetEntityCoords(prop),
        size = vector3(1.75, 1.75, 1.75),
        debug = Config.debug,
        options = { {
            label = locale("atm_robbery.collect_scattered_loot"),
            icon = "fa-solid fa-money-bills",
            distance = 2.0,
            onSelect = function()
                if not ClientApplication.state.activeScenario then return end

                local playerPed = cache.ped
                Target.removeZone(zoneName)
                state.zones["scattered_loot_" .. groupIndex .. "_" .. atmIndex] = nil

                lib.playAnim(playerPed, "pickup_object", "pickup_low", 8.0, 1.0, -1, 16, 0, false, false, false)
                Citizen.Wait(1500)
                ClearPedTasks(playerPed)
                DeleteEntity(prop)
                state.cashPileProps[groupIndex .. "_" .. atmIndex] = nil

                local response = lib.callback.await(_e("server:scenarios:pacific_bank_robbery:onScatteredLootCollected"),
                    false,
                    {
                        lobbyId = ClientApplication.state.lobby.id,
                        groupIndex = groupIndex,
                        atmIndex = atmIndex,
                    }
                )
                if not response.success then
                    if response.message then
                        Utils.notify(response.message, "error")
                    end
                    return
                end
            end,
        } },
    })
end

local function setupScatteredLoot(model, coords, groupIndex, atmIndex)
    local function sprayEffect(entity)
        local closestAtmObject = entity
        local ptFxName = "scr_xs_celebration"
        local effectName = "scr_xs_money_rain"

        local coords = GetOffsetFromEntityInWorldCoords(closestAtmObject, 0.0, 0.0, 1.0)
        local rotation = GetEntityRotation(closestAtmObject, 2)

        local particles = {}
        for i = 1, 10 do
            lib.requestNamedPtfxAsset(ptFxName)
            UseParticleFxAssetNextCall(ptFxName)

            local particle = StartParticleFxLoopedAtCoord(
                effectName,
                coords.x, coords.y, coords.z,
                60.0, rotation.y, rotation.z,
                1.0, false, false, false, false
            )
            table.insert(particles, particle)
            RemoveNamedPtfxAsset(ptFxName)
        end

        Citizen.CreateThread(function()
            Citizen.Wait(10000)
            for _, particle in pairs(particles) do
                StopParticleFxLooped(particle, 0)
            end
        end)

        return true
    end

    local entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, model, false, false, false)
    if not DoesEntityExist(entity) then return end

    sprayEffect(entity)
    Citizen.Wait(8000)
    targetableScatteredLootProp(model, coords, groupIndex, atmIndex)
end

local function robNearByAtmThread()
    Citizen.CreateThread(function()
        local robbableAtmGroups = config.robbableAtmGroups[SV_MAP_TYPE] or {}

        local textui = false

        while ClientApplication.state.activeScenario do
            local wait = 1000

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            for groupIndex, group in pairs(robbableAtmGroups) do
                local isRobbed = ClientApplication.state.activeScenario.game.robbableAtmGroups and
                    ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE] and
                    ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex] and
                    ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex].robbed

                if not isRobbed then
                    local markerCoords = group.markerCoords
                    local distance = #(playerCoords - markerCoords)
                    if distance < 8.0 then
                        wait = 0
                        DrawMarker(
                            28,
                            markerCoords.x, markerCoords.y, markerCoords.z,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.04, 0.04, 0.04,
                            189, 219, 9, 255,
                            false, true, 2, false, nil, nil, false
                        )
                        if distance < 1.5 then
                            if not textui then
                                textui = true
                                Utils.showTextUI(locale("pacific_bank_robbery.rob_atm"), "E")
                            end

                            if IsControlJustPressed(0, 38) then
                                Utils.hideTextUI()
                                textui = false
                                robAtmWithHack(groupIndex)
                                Citizen.Wait(1000)
                            end
                        elseif textui then
                            textui = false
                            Utils.hideTextUI()
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end

        if textui then
            Utils.hideTextUI()
        end
    end)
end

---@section GUARD FUNCTIONS

local function spawnGroupGuards()
    local guards = config.guards[SV_MAP_TYPE] or {}
    if #guards == 0 then return end

    -- Initialize guard manager
    managers.guards = GuardManagerClient.new({
        guards = guards,
        onGuardsSpawned = function(guardNetIds)
            TriggerServerEvent(_e("server:scenarios:pacific_bank_robbery:onGuardsSpawned"), {
                lobbyId = ClientApplication.state.lobby.id,
                guardNetIds = guardNetIds,
            })
        end
    })
    -- Set target to current player (aggressive behavior)
    local playerPed = cache.ped
    managers.guards:setTargetPlayers({ playerPed })

    -- Spawn guards with different model and weapon
    managers.guards:spawnGuards("mp_m_securoguard_01", "WEAPON_PISTOL")
end

---@section DISTANCE CHECK

local function distanceCheckingForFinishThread()
    if state.distanceForFinishWorking then return end
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    state.distanceForFinishWorking = true

    Citizen.CreateThread(function()
        local bankCenterCoords = config.bankCenterCoords[SV_MAP_TYPE]
        local maxDistance = config.requiredDistanceForFinish
        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(bankCenterCoords))
            if distance > maxDistance then
                HeistClient.completeScenario()
                return
            end
            Citizen.Wait(1000)
        end
    end)
end

---@section PUBLIC FUNCTIONS

function PacificBankRobberyClient.clear()
    for _, blip in pairs(state.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    if state.temporaryObjects then
        for _, obj in pairs(state.temporaryObjects) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
    end

    if state.cashPileProps then
        for _, prop in pairs(state.cashPileProps) do
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end
    end

    if state.zones then
        for _, zoneName in pairs(state.zones) do
            Target.removeZone(zoneName)
        end
    end

    if managers.guards then
        managers.guards:clear()
    end

    if managers.doors then
        managers.doors:clear()
    end

    if managers.trolleys then
        managers.trolleys:clear()
    end

    __init_state__()
end

function PacificBankRobberyClient.init()
    addRadiusBlip(config.bombDropOptions.locations.center, 50.0, 5, "bomb_drop_zone_radius")
    addBlip(config.bombDropOptions.locations.usage, SHARED_CONFIG.blips.drone, true, true, "bomb_drop_zone_usage")

    Utils.notify(locale("pacific_bank_robbery.go_to_drone_arena"), "info", 5000)

    nearDroneUsageAreaThread()
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onBombDropped"), function(params)
    if not ClientApplication.state.activeScenario or
        not ClientApplication.state.activeScenario.game or
        not ClientApplication.state.activeScenario.game.bombDropOptions or
        not ClientApplication.state.activeScenario.game.bombDropOptions.locations or
        not ClientApplication.state.activeScenario.game.bombDropOptions.locations.dropZones or
        not ClientApplication.state.activeScenario.game.bombDropOptions.locations.dropZones[params.zoneIndex]
    then
        return
    end
    if not params.coords or
        not params.droppedCount or
        not params.totalDrops
    then
        return
    end

    ClientApplication.state.activeScenario.game.bombDropOptions.locations.dropZones[params.zoneIndex].dropped = true

    AddExplosion(params.coords.x, params.coords.y, params.coords.z,
        34, 5.0, true, false, 1.0, true)

    removeBlipByKey("bomb_drop_zone_" .. params.zoneIndex)
    HeistClient.updateActiveInfoProgress(params.droppedCount, params.totalDrops)

    Utils.notify(locale("pacific_bank_robbery.bomb_dropped"), "info", 5000)
end)

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onAllBombsDropped"), function(params)
    if ClientApplication.state.activeScenario and params.lobbyId == ClientApplication.state.lobby.id then
        if params.droneDriver == cache.serverId then
            DroneClient:clear()
        end

        ClientApplication.state.activeScenario.game.bombDropOptions.allDropped = true
        Utils.notify(locale("pacific_bank_robbery.all_bombs_dropped"), "success")

        HeistClient.updateActiveInfoIndex(3)

        addBlip(config.bankEntranceCoords[SV_MAP_TYPE], SHARED_CONFIG.blips.bank_entrance, true, true, "bank_entrance")
        Utils.notify(locale("pacific_bank_robbery.go_to_bank"), "info", 5000)

        -- Initialize door manager
        managers.doors = DoorManagerClient.new({
            doors = config.doors[SV_MAP_TYPE],
            onDoorUnlocked = function(doorIndex)
                Utils.notify(locale("door_unlocked"), "success")
            end,
        })

        managers.doors:startLockingThread()
        managers.doors:startInteractionThread({
            keypad = function(doorIndex, door)
                local meta = { pin = Utils.generateUniquePin(4) }
                openDoorWithSkillbar(doorIndex, "keypad", meta)
            end,
            safepad = function(doorIndex, door)
                local meta = { pin = Utils.generateUniquePin(3) }
                openDoorWithSkillbar(doorIndex, "safepad", meta)
            end,
            bomb = openDoorWithBomb,
        }, function() return state.isBusy end)

        -- Initialize trolley manager
        managers.trolleys = TrolleyManagerClient.new({
            trolleys = config.cashTrolleyGroups[SV_MAP_TYPE] or {},
            onTrolleyCollected = function(trolleyIndex, trolleyType)
                state.isBusy = true

                TriggerServerEvent(_e("server:scenarios:pacific_bank_robbery:onTrolleyCollected"), {
                    lobbyId = ClientApplication.state.lobby.id,
                    trolleyIndex = trolleyIndex,
                })

                Utils.notify(locale("trolley_collected"), "success")
                state.isBusy = false
            end
        })

        managers.trolleys:setupTrolleys()
        managers.trolleys:startCollectionThread(
            function() return state.isBusy end,
            function(trolleyIndex)
                return lib.callback.await(_e("server:scenarios:pacific_bank_robbery:isTrolleyBusy"), false, {
                    lobbyId = ClientApplication.state.lobby.id,
                    trolleyIndex = trolleyIndex,
                })
            end,
            "pacific_bank_robbery.collect_cash_from_trolley"
        )

        robNearByAtmThread()

        if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
            spawnGroupGuards()
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onDoorUnlockedWithBomb"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local bombRot = params.bombRot

    if not managers.doors then return end
    if managers.doors:isDoorUnlocked(doorId) then return end

    local door = config.doors[SV_MAP_TYPE][doorId]

    if ClientApplication.state.activeScenario and ClientApplication.state.lobby.id == lobbyId then
        managers.doors:plantLocalBombOnEntity(doorId, bombRot)
    end

    managers.doors:unlockDoor(doorId, door.meta and door.meta.delete or false)

    if ClientApplication.state.activeScenario and ClientApplication.state.lobby.id == lobbyId and ClientApplication.state.lobby.owner == cache.serverId then
        if door.meta and door.meta.entrance and not state.distanceForFinishWorking then
            distanceCheckingForFinishThread()
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onDoorUnlocked"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType

    if not managers.doors then return end
    if managers.doors:isDoorUnlocked(doorId) then return end

    local door = config.doors[SV_MAP_TYPE][doorId]

    managers.doors:unlockDoor(doorId)

    -- Only trigger distance check for safepad entrance doors
    if ClientApplication.state.lobby.id == lobbyId and ClientApplication.state.lobby.owner == cache.serverId and
        unlockType == "safepad" and ClientApplication.state.activeScenario then
        if door.meta and door.meta.entrance and not state.distanceForFinishWorking then
            distanceCheckingForFinishThread()
            triggerAlert(config.bankCenterCoords[SV_MAP_TYPE])
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onAtmHacked"), function(params)
    local lobbyId = params.lobbyId
    local groupIndex = params.groupIndex

    if not ClientApplication.state.activeScenario or
        not ClientApplication.state.activeScenario.game or
        not ClientApplication.state.activeScenario.game.robbableAtmGroups or
        not ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE] or
        not ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex] or
        lobbyId ~= ClientApplication.state.lobby.id
    then
        return
    end

    ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex].robbed = true

    for atmIndex, atm in pairs(ClientApplication.state.activeScenario.game.robbableAtmGroups[SV_MAP_TYPE][groupIndex].atmCoords) do
        Citizen.CreateThread(function()
            setupScatteredLoot(atm.model, atm.coords, groupIndex, atmIndex)
        end)
    end
end)

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onTrolleyCollected"), function(params)
    local trolleyIndex = params.trolleyIndex

    if not managers.trolleys then return end
    if managers.trolleys:isTrolleyCollected(trolleyIndex) then return end

    managers.trolleys:markTrolleyCollected(trolleyIndex)
end)

RegisterNetEvent(_e("client:scenarios:pacific_bank_robbery:onGuardsSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if not managers.guards then
        managers.guards = GuardManagerClient.new({ guards = config.guards[SV_MAP_TYPE] })
    end

    managers.guards:syncGuardsFromNetIds(params.guardNetIds)
end)
