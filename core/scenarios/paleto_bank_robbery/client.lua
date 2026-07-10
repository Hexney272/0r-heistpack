local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")
local DoorManagerClient     = require("core.scenarios._shared.client.doors")
local TrolleyManagerClient  = require("core.scenarios._shared.client.trolleys")

local config                = lib.load("config.scenarios.paleto_bank_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

PaletoBankRobberyClient     = {}

-- State management
local state                 = {
    isBusy = false,
    blips = {},
    zones = {},
    temporaryObjects = {},
    distanceForFinishWorking = false,
}

-- Manager instances
local managers              = {
    doors = nil,
    trolleys = nil,
}

-- Map type selection
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
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("paleto_bank_robbery", locale("paleto_bank_robbery.police_alert"), coords)
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

local function openDoorWithSkillbar(doorIndex, skillbarType, meta)
    state.isBusy      = true

    local playerPedId = cache.ped
    local animDict    = "anim@heists@keypad@"
    local animName    = "idle_a"
    lib.requestAnimDict(animDict)
    TaskPlayAnim(playerPedId, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    local skillbarSuccess = Skillbar.show(skillbarType, meta)

    if skillbarSuccess then
        TriggerServerEvent(_e("server:scenarios:paleto_bank_robbery:onDoorUnlocked"),
            {
                lobbyId = ClientApplication.state.lobby.id,
                doorId = doorIndex,
                unlockType = skillbarType
            })
    end

    state.isBusy = false
    ClearPedTasks(playerPedId)
    RemoveAnimDict(animDict)
end

local function openDoorWithBomb(doorIndex)
    state.isBusy = true

    local door = config.doors[SV_MAP_TYPE][doorIndex]
    if not door then
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

    if plantAnimResponse then
        TriggerServerEvent(_e("server:scenarios:paleto_bank_robbery:onBombPlantOnDoor"),
            {
                lobbyId = ClientApplication.state.lobby.id,
                doorId = doorIndex,
                bombRot = plantAnimResponse.rotation
            })
    end

    state.isBusy = false
end

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

---@section SETUP FUNCTIONS

local function setupDisableSecurity(isOwner)
    local electricBox = config.disableSecurityOptions
    if not electricBox then return end

    if isOwner then
        local electricBoxObject = Utils.createObject({
            model = electricBox.model,
            coords = electricBox.coords,
            rotation = electricBox.rotation or electricBox.coords.w or 0.0,
            freeze = true,
            isNetwork = true,
        })
        state.temporaryObjects["electric_box"] = electricBoxObject
    end

    local zoneName = "paleto_bank_robbery_electric_box_zone"
    state.zones[zoneName] = zoneName

    Target.addBoxZone(zoneName, {
        name = zoneName,
        coords = vector3(electricBox.coords.x, electricBox.coords.y, electricBox.coords.z + 1.0),
        size = vector3(1.5, 1.5, 3.0),
        rotation = electricBox.rotation or electricBox.coords.w or 0.0,
        debug = Config.debug,
        options = { {
            label = locale("paleto_bank_robbery.disable_security"),
            icon = "fa-solid fa-briefcase",
            distance = 2.0,
            canInteract = function()
                return not state.isBusy
            end,
            onSelect = function()
                local prop = GetClosestObjectOfType(
                    electricBox.coords.x, electricBox.coords.y, electricBox.coords.z,
                    0.3, electricBox.model, false, false, false
                )
                if not DoesEntityExist(prop) then
                    Utils.notify(locale("paleto_bank_robbery.electric_box_not_found"), "error")
                    return
                end

                state.isBusy = true

                local ped = cache.ped
                local animDict = "anim@scripted@player@mission@tun_control_tower@male@"
                lib.requestAnimDict(animDict)

                local sceneCoords = electricBox.coords
                local sceneRot = vector3(0.0, 0.0, electricBox.rotation or electricBox.coords.w or 0.0)

                -- Enter animation
                local enterScene = NetworkCreateSynchronisedScene(
                    sceneCoords.x, sceneCoords.y, sceneCoords.z,
                    sceneRot.x, sceneRot.y, sceneRot.z, 2,
                    true, false, -1, 0, 1.0
                )
                NetworkAddPedToSynchronisedScene(
                    ped, enterScene, animDict, "enter",
                    1.5, -4.0, 1, 16, 1148846080, 0
                )
                NetworkAddEntityToSynchronisedScene(
                    prop, enterScene, animDict, "enter_electric_box",
                    1.0, 1.0, 1
                )
                NetworkStartSynchronisedScene(enterScene)
                Citizen.Wait(1566)

                local skillCheckState = Skillbar.show("sequence_matrix")

                if not skillCheckState then
                    Utils.notify(locale("paleto_bank_robbery.disable_security_failed"), "error")
                else
                    Target.removeLocalEntity(prop)
                    TriggerServerEvent(_e("server:scenarios:paleto_bank_robbery:onSecurityDisabled"),
                        { lobbyId = ClientApplication.state.lobby.id })
                end

                -- Exit animation
                local exitScene = NetworkCreateSynchronisedScene(
                    sceneCoords.x, sceneCoords.y, sceneCoords.z,
                    sceneRot.x, sceneRot.y, sceneRot.z, 2,
                    true, false, -1, 0, 1.0
                )
                NetworkAddPedToSynchronisedScene(
                    ped, exitScene, animDict, "exit",
                    1.5, -4.0, 1, 16, 1148846080, 0
                )
                NetworkAddEntityToSynchronisedScene(
                    prop, exitScene, animDict, "exit_electric_box",
                    1.0, 1.0, 1
                )
                NetworkStartSynchronisedScene(exitScene)
                Citizen.Wait(2099)

                ClearPedTasks(ped)
                RemoveAnimDict(animDict)

                state.isBusy = false
            end,
        } },
    })
end

---@section PUBLIC FUNCTIONS

function PaletoBankRobberyClient.clear()
    for key, _ in pairs(state.blips) do
        removeBlipByKey(key)
    end

    if managers.doors then
        managers.doors:clear()
    end

    if managers.trolleys then
        managers.trolleys:clear()
    end

    if state.zones then
        for _, zoneName in pairs(state.zones) do
            Target.removeZone(zoneName)
        end
    end

    if state.temporaryObjects then
        for _, obj in pairs(state.temporaryObjects) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
    end

    __init_state__()
end

function PaletoBankRobberyClient.init()
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId

    addBlip(config.disableSecurityOptions.coords, SHARED_CONFIG.blips.electric_box, true, true, "electric_box")
    Utils.notify(locale("paleto_bank_robbery.go_to_electric_box"), "info", 5000)

    setupDisableSecurity(isOwner)

    local doors = config.doors[SV_MAP_TYPE]

    -- Initialize door manager
    managers.doors = DoorManagerClient.new({
        doors = doors,
        onDoorUnlocked = function(doorIndex)
            Utils.notify(locale("door_unlocked"), "success")
        end
    })

    managers.doors:startLockingThread()
    managers.doors:startInteractionThread({
        keypad = function(doorIndex, door)
            local meta = { pin = Utils.generateUniquePin(4) }
            openDoorWithSkillbar(doorIndex, "keypad", meta)
        end,
        bomb = openDoorWithBomb,
    }, function() return state.isBusy end)
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("client:scenarios:paleto_bank_robbery:onDoorUnlockedWithBomb"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local bombRot = params.bombRot

    if not ClientApplication.state.activeScenario or
        not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= lobbyId then
        return
    end

    if managers.doors then
        managers.doors:plantLocalBombOnEntity(doorId, bombRot)
        managers.doors:unlockDoor(doorId)
    end

    local door = config.doors[SV_MAP_TYPE][doorId]
    if door and door.meta and door.meta.entrance and not state.distanceForFinishWorking then
        local isOwner = ClientApplication.state.lobby.owner == cache.serverId
        if isOwner then
            distanceCheckingForFinishThread()
            triggerAlert(config.bankCenterCoords[SV_MAP_TYPE])
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:paleto_bank_robbery:onDoorUnlocked"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType

    if not ClientApplication.state.activeScenario or
        not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= lobbyId then
        return
    end

    if managers.doors then
        managers.doors:unlockDoor(doorId)
    end
end)

RegisterNetEvent(_e("client:scenarios:paleto_bank_robbery:onTrolleyCollected"), function(params)
    local trolleyIndex = params.trolleyIndex

    if managers.trolleys then
        managers.trolleys:markTrolleyCollected(trolleyIndex)
    end
end)

RegisterNetEvent(_e("client:scenarios:paleto_bank_robbery:onSecurityDisabled"), function(params)
    if not ClientApplication.state.activeScenario or
        not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    Utils.notify(locale("paleto_bank_robbery.security_disabled"), "success")
    removeBlipByKey("electric_box")

    local zoneName = "paleto_bank_robbery_electric_box_zone"
    Target.removeZone(zoneName)
    state.zones[zoneName] = nil

    ClientApplication.state.activeScenario.game.securityDisabled = true

    Utils.notify(locale("paleto_bank_robbery.go_to_bank"), "info", 5000)
    addBlip(config.bankCenterCoords[SV_MAP_TYPE], SHARED_CONFIG.blips.bank_entrance, true, true, "bank_entrance")

    -- Initialize trolley manager
    local trolleys = config.cashTrolleyGroups[SV_MAP_TYPE]

    managers.trolleys = TrolleyManagerClient.new({
        trolleys = trolleys,
        onTrolleyCollected = function(trolleyIndex, trolleyType)
            state.isBusy = true

            TriggerServerEvent(_e("server:scenarios:paleto_bank_robbery:onTrolleyCollected"), {
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
            return lib.callback.await(_e("server:scenarios:paleto_bank_robbery:isTrolleyBusy"), false, {
                lobbyId = ClientApplication.state.lobby.id,
                trolleyIndex = trolleyIndex,
            })
        end,
        "paleto_bank_robbery.collect_cash_from_trolley"
    )
end)
