local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")
local DoorManagerClient     = require("core.scenarios._shared.client.doors")
local TrolleyManagerClient  = require("core.scenarios._shared.client.trolleys")
local LootableMoneyManager  = require("core.scenarios._shared.client.lootable_moneys")
local CustomerSafeManager   = require("core.scenarios._shared.client.customer_safes")

local config                = lib.load("config.scenarios.fleeca_bank_robbery")

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

FleecaBankRobberyClient     = {}

-- State management
local state                 = {
    isBusy = false,
    blips = {},
    zones = {},
    distanceForFinishWorking = false,
    points = {},
}

-- Manager instances
local managers              = {
    doors = nil,
    trolleys = nil,
    lootableMoneys = nil,
    customerSafes = nil,
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
    managers.lootableMoneys = nil
    managers.customerSafes = nil
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("fleeca_bank_robbery", locale("fleeca_bank_robbery.police_alert"), coords)
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
    state.isBusy = true

    local playerPedId = cache.ped
    local animDict    = "anim@heists@keypad@"
    local animName    = "idle_a"
    lib.requestAnimDict(animDict)
    TaskPlayAnim(playerPedId, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    local skillbarSuccess = Skillbar.show(skillbarType, meta)

    if skillbarSuccess then
        TriggerServerEvent(_e("server:scenarios:fleeca_bank_robbery:onDoorUnlocked"),
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

local function distanceCheckingForFinishThread()
    if state.distanceForFinishWorking then return end
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    state.distanceForFinishWorking = true

    Citizen.CreateThread(function()
        local locationIndex = ClientApplication.state.activeScenario.game.locationIndex
        local bankCenterCoords = config.locations[locationIndex][SV_MAP_TYPE].centerCoords
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

function FleecaBankRobberyClient.clear()
    for key, _ in pairs(state.blips) do
        removeBlipByKey(key)
    end

    if managers.doors then
        managers.doors:clear()
    end

    if managers.trolleys then
        managers.trolleys:clear()
    end

    if managers.lootableMoneys then
        managers.lootableMoneys:clear()
    end

    if managers.customerSafes then
        managers.customerSafes:clear()
    end

    if state.zones then
        for _, zoneName in pairs(state.zones) do
            Target.removeZone(zoneName)
        end
    end

    if state.points then
        for _, point in pairs(state.points) do
            point:remove()
        end
    end

    __init_state__()
end

function FleecaBankRobberyClient.init()
    local locations = config.locations
    for i = 1, #locations do
        local location = locations[i][SV_MAP_TYPE]
        addBlip(location.entranceCoords, SHARED_CONFIG.blips.bank_entrance, false, true, "bank_entrance_" .. i)
        if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
            lib.points.new({
                coords = location.centerCoords,
                distance = 7.0,
                onEnter = function(self)
                    self:remove()
                    TriggerServerEvent(_e("server:scenarios:fleeca_bank_robbery:setLocation"), {
                        lobbyId = ClientApplication.state.lobby.id,
                        locationIndex = i,
                    })
                end,
            })
        end
    end
end

RegisterNetEvent(_e("client:scenarios:fleeca_bank_robbery:onLocationSet"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end
    if not ClientApplication.state.activeScenario then return end

    for _, blip in pairs(state.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    local location = config.locations[params.locationIndex][SV_MAP_TYPE]
    if not location then return end

    Utils.notify(locale("fleeca_bank_robbery.location_set"), "success")

    if ClientApplication.state.lobby.owner == cache.serverId then
        triggerAlert(location.centerCoords)
    end

    ClientApplication.state.activeScenario.game.locationIndex = params.locationIndex

    addBlip(location.entranceCoords, SHARED_CONFIG.blips.bank_entrance, true, true, "bank_entrance")

    -- Initialize door manager
    managers.doors = DoorManagerClient.new({
        doors = location.doors,
        onDoorUnlocked = function(doorIndex)
            Utils.notify(locale("door_unlocked"), "success")
        end,
    })

    managers.doors:startLockingThread()
    managers.doors:startInteractionThread({
        type_breaker = function(doorIndex, door)
            local meta = { pin = Utils.generateUniquePin(4) }
            openDoorWithSkillbar(doorIndex, "type_breaker", meta)
        end,
        safepad = function(doorIndex, door)
            local meta = { pin = Utils.generateUniquePin(3) }
            openDoorWithSkillbar(doorIndex, "safepad", meta)
        end,
    }, function() return state.isBusy end)

    -- Initialize trolley manager
    managers.trolleys = TrolleyManagerClient.new({
        trolleys = location.cashTrolleys or {},
        onTrolleyCollected = function(trolleyIndex, trolleyType)
            state.isBusy = true

            TriggerServerEvent(_e("server:scenarios:fleeca_bank_robbery:onTrolleyCollected"), {
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
            return lib.callback.await(_e("server:scenarios:fleeca_bank_robbery:isTrolleyBusy"), false, {
                lobbyId = ClientApplication.state.lobby.id,
                trolleyIndex = trolleyIndex,
            })
        end,
        "fleeca_bank_robbery.collect_cash_from_trolley"
    )

    -- Initialize lootable money manager
    managers.lootableMoneys = LootableMoneyManager.new({
        moneys = location.lootableMoneys or {},
        onMoneyCollected = function(moneyIndex)
            state.isBusy = true

            TriggerServerEvent(_e("server:scenarios:fleeca_bank_robbery:onMoneyCollected"), {
                lobbyId = ClientApplication.state.lobby.id,
                moneyIndex = moneyIndex,
            })

            state.isBusy = false
        end
    })

    managers.lootableMoneys:setupMoneys()
    managers.lootableMoneys:startCollectionThread(
        function() return state.isBusy end,
        "fleeca_bank_robbery.collect_cash_from_table",
        config.animations.grabCash
    )

    -- Initialize customer safe manager
    managers.customerSafes = CustomerSafeManager.new({
        safes = location.drillCustomerSafes or {},
        onSafeDrilled = function(safeIndex)
            state.isBusy = true

            TriggerServerEvent(_e("server:scenarios:fleeca_bank_robbery:onCustomerSafeDrilled"), {
                lobbyId = ClientApplication.state.lobby.id,
                safeIndex = safeIndex,
            })

            state.isBusy = false
        end
    })

    managers.customerSafes:startMarkerThread()
    managers.customerSafes:startCollectionThread(
        function() return state.isBusy end,
        function(safeIndex)
            return lib.callback.await(_e("server:scenarios:fleeca_bank_robbery:isCustomerSafeBusy"), false, {
                lobbyId = ClientApplication.state.lobby.id,
                safeIndex = safeIndex,
            })
        end,
        "fleeca_bank_robbery.drill_customer_safe"
    )

    distanceCheckingForFinishThread()
    HeistClient.updateActiveInfoIndex(2)
end)

RegisterNetEvent(_e("client:scenarios:fleeca_bank_robbery:onDoorUnlocked"), function(params)
    local lobbyId = params.lobbyId
    local doorId = params.doorId
    local unlockType = params.unlockType

    if not managers.doors then return end
    if managers.doors:isDoorUnlocked(doorId) then return end

    local locationIndex = ClientApplication.state.activeScenario.game.locationIndex
    local door = config.locations[locationIndex][SV_MAP_TYPE].doors[doorId]

    managers.doors:unlockDoor(doorId)

    -- Only trigger distance check for safepad entrance doors
    if unlockType == "safepad" and ClientApplication.state.activeScenario and ClientApplication.state.lobby.id == lobbyId and ClientApplication.state.lobby.owner == cache.serverId then
        if door.meta and door.meta.entrance and not state.distanceForFinishWorking then
            HeistClient.updateActiveInfoIndex(3)
            distanceCheckingForFinishThread()
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:fleeca_bank_robbery:onTrolleyCollected"), function(params)
    local trolleyIndex = params.trolleyIndex

    if not managers.trolleys then return end
    if managers.trolleys:isTrolleyCollected(trolleyIndex) then return end

    managers.trolleys:markTrolleyCollected(trolleyIndex)
end)

RegisterNetEvent(_e("client:scenarios:fleeca_bank_robbery:onMoneyCollected"), function(params)
    local moneyIndex = params.moneyIndex

    if not managers.lootableMoneys then return end
    if managers.lootableMoneys:isMoneyCollected(moneyIndex) then return end

    managers.lootableMoneys:markMoneyCollected(moneyIndex)
end)

RegisterNetEvent(_e("client:scenarios:fleeca_bank_robbery:onCustomerSafeDrilled"), function(params)
    local safeIndex = params.safeIndex

    if not managers.customerSafes then return end
    if managers.customerSafes:isSafeDrilled(safeIndex) then return end

    managers.customerSafes:markSafeDrilled(safeIndex)
end)
