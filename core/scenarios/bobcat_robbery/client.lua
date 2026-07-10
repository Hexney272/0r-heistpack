local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")
local DoorManagerClient     = require("core.scenarios._shared.client.doors")
local TrolleyManagerClient  = require("core.scenarios._shared.client.trolleys")
local GuardManagerClient    = require("core.scenarios._shared.client.guards")

local config                = lib.load("config.scenarios.bobcat_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

BobcatRobberyClient         = {}

-- State management
local state                 = {
    isBusy = false,
    blips = {},
    temporaryObjects = {},
    zones = {},
    distanceForFinishWorking = false,
    redRoomVault = {
        initialized  = false,
        bombPlanted  = false,
        vaultOpened  = false,
        modelSwapped = false,
    },
}

-- Manager instances
local managers              = {
    doors = nil,
    trolleys = nil,
    guards = nil,
}

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
    Utils.triggerPoliceAlert("bobcat_robbery", locale("bobcat_robbery.police_alert"), coords)
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

    TriggerServerEvent(_e("server:scenarios:bobcat_robbery:onBombPlantOnDoor"), {
        lobbyId = ClientApplication.state.lobby.id,
        doorId = doorIndex,
        bombRot = plantAnimResponse.rotation
    })

    state.isBusy = false
end

local function openDoorWithSkillbar(doorIndex, skillbarType, meta)
    state.isBusy      = true

    local playerPedId = cache.ped
    local animDict    = "anim@heists@keypad@"
    local animName    = "idle_a"
    lib.requestAnimDict(animDict)
    TaskPlayAnim(playerPedId, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    local skillbarSuccess = Skillbar.show(skillbarType, meta)

    if skillbarSuccess then
        TriggerServerEvent(_e("server:scenarios:bobcat_robbery:onDoorUnlocked"), {
            lobbyId = ClientApplication.state.lobby.id,
            doorId = doorIndex,
            unlockType = skillbarType
        })
    end

    state.isBusy = false

    ClearPedTasks(playerPedId)
    RemoveAnimDict(animDict)
end

---@section GUARD FUNCTIONS

local function spawnGroupGuards()
    local guards = config.guards or {}
    if #guards == 0 then return end

    -- Initialize guard manager
    managers.guards = GuardManagerClient.new({
        guards = guards,
        onGuardsSpawned = function(guardNetIds)
            TriggerServerEvent(_e("server:scenarios:bobcat_robbery:onGuardsSpawned"), {
                lobbyId = ClientApplication.state.lobby.id,
                guardNetIds = guardNetIds,
            })
        end
    })

    -- Set target to current player (aggressive behavior)
    local playerPed = cache.ped
    managers.guards:setTargetPlayers({ playerPed })

    -- Spawn guards with heavy weapons
    managers.guards:spawnGuards("s_m_m_security_01", "WEAPON_CARBINERIFLE")
end

---@section RED ROOM VAULT FUNCTIONS

local function swapVaultModel()
    local vaultConfig = config.redRoomVault

    local object = GetClosestObjectOfType(
        vaultConfig.coords.x,
        vaultConfig.coords.y,
        vaultConfig.coords.z,
        1.0,
        GetHashKey(vaultConfig.startModel),
        false,
        false,
        false
    )
    if not DoesEntityExist(object) then return end

    CreateModelSwap(
        vaultConfig.coords.x,
        vaultConfig.coords.y,
        vaultConfig.coords.z,
        0.3,
        GetHashKey(vaultConfig.startModel),
        GetHashKey(vaultConfig.endModel),
        true
    )
    state.redRoomVault.modelSwapped = true

    Citizen.CreateThread(function()
        while state.redRoomVault.vaultOpened do
            local checkObj = GetClosestObjectOfType(
                vaultConfig.coords.x,
                vaultConfig.coords.y,
                vaultConfig.coords.z,
                1.0,
                GetHashKey(vaultConfig.startModel),
                false,
                false,
                false
            )

            if DoesEntityExist(checkObj) then
                if state.redRoomVault.modelSwapped then
                    RemoveModelSwap(
                        vaultConfig.coords.x,
                        vaultConfig.coords.y,
                        vaultConfig.coords.z,
                        0.3,
                        GetHashKey(vaultConfig.startModel),
                        GetHashKey(vaultConfig.endModel)
                    )
                    state.redRoomVault.modelSwapped = false
                end

                CreateModelSwap(
                    vaultConfig.coords.x,
                    vaultConfig.coords.y,
                    vaultConfig.coords.z,
                    0.3,
                    GetHashKey(vaultConfig.startModel),
                    GetHashKey(vaultConfig.endModel),
                    true
                )
                state.redRoomVault.modelSwapped = true
            end

            Citizen.Wait(500)
        end
    end)
end

local function plantBombOnRedRoomVault()
    if state.redRoomVault.bombPlanted then return end
    state.isBusy = true
    state.redRoomVault.bombPlanted = true

    local vaultConfig = config.redRoomVault

    -- Plant bomb animation
    local playerPed = cache.ped
    local animDict = SHARED_CONFIG.animations.plantBomb.dict
    local animName = SHARED_CONFIG.animations.plantBomb.name
    lib.requestAnimDict(animDict)

    local bombCoords = vaultConfig.bomb.coords
    local bombHeading = vaultConfig.bomb.heading

    SetEntityHeading(playerPed, bombHeading)
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, 5000, 0, 0, false,
        false, false)
    RemoveAnimDict(animDict)

    Citizen.Wait(5000)
    ClearPedTasks(playerPed)
    state.isBusy = false
    -- Create bomb prop
    local bombModel = "ch_prop_ch_explosive_01a"
    lib.requestModel(bombModel)

    local bombObj = CreateObject(bombModel,
        bombCoords.x, bombCoords.y, bombCoords.z,
        true, true, false)

    SetEntityRotation(bombObj, 0.0, -90.0, 90.0, 2, true)
    FreezeEntityPosition(bombObj, true)
    SetModelAsNoLongerNeeded(bombModel)
    table.insert(state.temporaryObjects, bombObj)

    for _ = 1, 5 do
        PlaySoundFromCoord(-1, "Beep_Red",
            bombCoords.x, bombCoords.y, bombCoords.z,
            "DLC_HEIST_HACKING_SNAKE_SOUNDS", 0, 0, 0)
        Citizen.Wait(1000)
    end

    -- Trigger explosion locally for planter
    AddExplosion(bombCoords.x, bombCoords.y, bombCoords.z, 2, 1.0, true, false, 1.0)

    -- Delete bomb object
    if DoesEntityExist(bombObj) then
        DeleteEntity(bombObj)
    end

    state.redRoomVault.vaultOpened = true

    -- Swap vault model for planter
    swapVaultModel()

    Utils.notify(locale("bobcat_robbery.vault_opened") or "Vault opened!", "success")

    -- Notify server after explosion
    TriggerServerEvent(_e("server:scenarios:bobcat_robbery:onRedRoomBombExploded"), {
        lobbyId = ClientApplication.state.lobby.id,
    })
end

---@section DISTANCE CHECK

local function distanceCheckingForFinishThread()
    if state.distanceForFinishWorking then return end
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    state.distanceForFinishWorking = true

    Citizen.CreateThread(function()
        local facilityCenterCoords = config.facilityCenterCoords
        local maxDistance = config.requiredDistanceForFinish
        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(facilityCenterCoords))
            if distance > maxDistance then
                HeistClient.completeScenario()
                return
            end
            Citizen.Wait(1000)
        end
    end)
end

local function initRedRoomVault()
    if state.redRoomVault.initialized then return end
    state.redRoomVault.initialized = true

    local vaultConfig = config.redRoomVault
    if not vaultConfig then return end

    -- TextUI thread for bomb plant
    Citizen.CreateThread(function()
        local bombCoords = vaultConfig.bomb.coords
        local textShown = false

        while ClientApplication.state.activeScenario and not state.redRoomVault.vaultOpened do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - bombCoords)

            if distance < 2.0 and not state.redRoomVault.bombPlanted then
                if not textShown then
                    Utils.showTextUI(locale("bobcat_robbery.plant_bomb"), "E")
                    textShown = true
                end

                if IsControlJustPressed(0, 38) and not state.isBusy then -- E key
                    Utils.hideTextUI()
                    textShown = false
                    plantBombOnRedRoomVault()
                end
            else
                if textShown then
                    Utils.hideTextUI()
                    textShown = false
                end
            end

            Citizen.Wait(0)
        end

        if textShown then
            Utils.hideTextUI()
        end
    end)
end

---@section PUBLIC FUNCTIONS

function BobcatRobberyClient.clear()
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

    if state.redRoomVault.vaultOpened then
        RemoveModelSwap(
            config.redRoomVault.coords.x,
            config.redRoomVault.coords.y,
            config.redRoomVault.coords.z,
            0.3,
            GetHashKey(config.redRoomVault.startModel),
            GetHashKey(config.redRoomVault.endModel)
        )
    end

    state.redRoomVault = {
        initialized = false,
        bombPlanted = false,
        vaultOpened = false,
    }

    __init_state__()
end

function BobcatRobberyClient.init()
    addBlip(config.facilityEntranceCoords, SHARED_CONFIG.blips.bank_entrance, true, true, "facility_entrance")

    Utils.notify(locale("bobcat_robbery.go_to_bobcat"), "info", 5000)

    -- Initialize door manager
    managers.doors = DoorManagerClient.new({
        doors = config.doors,
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
        trolleys = config.cashTrolleyGroups or {},
        onTrolleyCollected = function(trolleyIndex, trolleyType)
            state.isBusy = true

            TriggerServerEvent(_e("server:scenarios:bobcat_robbery:onTrolleyCollected"), {
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
            return lib.callback.await(_e("server:scenarios:bobcat_robbery:isTrolleyBusy"), false, {
                lobbyId = ClientApplication.state.lobby.id,
                trolleyIndex = trolleyIndex,
            })
        end,
        "bobcat_robbery.collect_from_trolley"
    )

    -- Spawn guards if lobby owner
    if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
        spawnGroupGuards()
    end

    -- Initialize red room vault
    initRedRoomVault()
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("client:scenarios:bobcat_robbery:onRedRoomVaultExploded"), function(params)
    local vaultConfig = config.redRoomVault
    local bombCoords = vaultConfig.bomb.coords

    -- Trigger explosion for all players
    AddExplosion(bombCoords.x, bombCoords.y, bombCoords.z, 2, 1.0, true, false, 1.0)

    state.redRoomVault.vaultOpened = true
    state.redRoomVault.bombPlanted = true

    -- Swap vault model for all players
    swapVaultModel()

    if ClientApplication.state.activeScenario then
        HeistClient.updateActiveInfoIndex(3)
    end
end)

RegisterNetEvent(_e("client:scenarios:bobcat_robbery:onDoorUnlockedWithBomb"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local bombRot = params.bombRot

    if not managers.doors then return end
    if managers.doors:isDoorUnlocked(doorId) then return end

    local door = config.doors[doorId]

    if ClientApplication.state.activeScenario and ClientApplication.state.lobby.id == lobbyId then
        managers.doors:plantLocalBombOnEntity(doorId, bombRot)
    end

    managers.doors:unlockDoor(doorId, door.meta and door.meta.delete or false)

    if ClientApplication.state.activeScenario and ClientApplication.state.lobby.id == lobbyId and ClientApplication.state.lobby.owner == cache.serverId then
        if door.meta and door.meta.entrance and not state.distanceForFinishWorking then
            distanceCheckingForFinishThread()
            triggerAlert(config.facilityCenterCoords)
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:bobcat_robbery:onDoorUnlocked"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType

    if not managers.doors then return end
    if managers.doors:isDoorUnlocked(doorId) then return end

    local door = config.doors[doorId]

    managers.doors:unlockDoor(doorId)

    -- Trigger distance check for entrance
    if ClientApplication.state.activeScenario then
        if door.meta and door.meta.entrance and not state.distanceForFinishWorking then
            HeistClient.updateActiveInfoIndex(2)
            if ClientApplication.state.lobby.id == lobbyId and
                ClientApplication.state.lobby.owner == cache.serverId
            then
                distanceCheckingForFinishThread()
                triggerAlert(config.facilityCenterCoords)
            end
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:bobcat_robbery:onTrolleyCollected"), function(params)
    local trolleyIndex = params.trolleyIndex

    if not managers.trolleys then return end
    if managers.trolleys:isTrolleyCollected(trolleyIndex) then return end

    managers.trolleys:markTrolleyCollected(trolleyIndex)
end)

RegisterNetEvent(_e("client:scenarios:bobcat_robbery:clearRedRoomVault"), function()
    state.redRoomVault.vaultOpened = false
    state.redRoomVault.bombPlanted = false
end)

RegisterNetEvent(_e("client:scenarios:bobcat_robbery:onGuardsSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if not managers.guards then
        managers.guards = GuardManagerClient.new({
            guards = config.guards or {},
        })
    end

    managers.guards:syncGuardsFromNetIds(params.guardNetIds)
end)
