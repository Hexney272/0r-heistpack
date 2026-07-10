local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")

local config                = lib.load("config.scenarios.store_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

local SV_MAP_TYPE           = config.hasCustomMap and "custom" or "standart"

local state                 = {
    isBusy          = false,
    blips           = {},
    zones           = {},
    spawnedCashiers = {},
    points          = {}, --[[@type CPoint[] ]]
    moneyObjects    = {}, -- Para objeleri için
    miniSafeInside  = {},
    miniSafe        = { body = nil, door = nil },
    holding         = {},
}

StoreRobberyClient          = {}

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
    Utils.triggerPoliceAlert("store_robbery", locale("store_robbery.police_alert"), coords)
end

local function deletePlayerHoldingLoot()
    if not state.holding.object then return end
    DetachEntity(state.holding.object, true, true)
    DeleteEntity(state.holding.object)
    ClearPedTasks(cache.ped)
    state.holding.object = nil
end

local function removeBlipByKey(key)
    if not state.blips[key] then return end
    if DoesBlipExist(state.blips[key]) then
        RemoveBlip(state.blips[key])
    end
    state.blips[key] = nil
end

local function addBlip(target, options, route, longRange, key)
    local blip = Utils.addBlip(target, options, route)
    SetBlipAsShortRange(blip, not longRange)
    state.blips[key] = blip
end

local function setupMoneyObjectTarget(moneyObject, locationIndex)
    Target.addLocalEntity(moneyObject, { {
        label = locale("store_robbery.collect_money"),
        icon = "fa-solid fa-money-bill-1-wave",
        distance = 2.0,
        canInteract = function()
            return not state.isBusy and ClientApplication.state.activeScenario
        end,
        onSelect = function()
            Target.removeLocalEntity(moneyObject)

            local animation = {
                dict     = "amb@medic@standing@tendtodead@idle_a",
                name     = "idle_a",
                duration = 2000,
            }

            local moneyObjectCoords = GetEntityCoords(moneyObject)
            TaskTurnPedToFaceCoord(cache.ped, moneyObjectCoords.x, moneyObjectCoords.y, moneyObjectCoords.z, 4000)
            Citizen.Wait(500)

            lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, 8.0, animation.duration)
            Citizen.Wait(animation.duration)
            ClearPedTasks(cache.ped)

            DeleteEntity(moneyObject)
            state.moneyObjects[locationIndex] = nil

            local response = lib.callback.await(_e("server:scenarios:store_robbery:onCashierMoneyCollected"), false,
                { lobbyId = ClientApplication.state.lobby.id })
            if not response.success then
                Utils.notify(response.message or locale("store_robbery.collect_money_failed"), "error", 3000)
                if response.message then
                    Utils.notify(response.message, "error", 3000)
                end
                return
            end
        end
    } })
end

local function spawnMoneyObject(cashierPed, locationIndex)
    if not DoesEntityExist(cashierPed) then return end

    local cashierCoords = GetEntityCoords(cashierPed)
    local cashierHeading = GetEntityHeading(cashierPed)

    local forwardVector = GetEntityForwardVector(cashierPed)
    local spawnCoords = cashierCoords + (forwardVector * config.cashierRobbery.spawnOffset.x) +
        vector3(config.cashierRobbery.spawnOffset.y, 0.0, config.cashierRobbery.spawnOffset.z)

    local moneyObject = Utils.createObject({
        model = config.cashierRobbery.model,
        coords = spawnCoords,
        rotation = vector3(0.0, 0.0, cashierHeading + math.random(-45, 45)),
        freeze = false,
        isNetwork = false,
    })

    if moneyObject and DoesEntityExist(moneyObject) then
        SetEntityCoords(moneyObject, spawnCoords.x, spawnCoords.y, spawnCoords.z + 0.5, false, false, false, true)
        ApplyForceToEntity(moneyObject, 1,
            forwardVector.x * 5.0, forwardVector.y * 5.0,
            2.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        state.moneyObjects[locationIndex] = moneyObject
    end

    setupMoneyObjectTarget(moneyObject, locationIndex)
end

local function onCashierPedSpawned(locationIndex, cashierPed)
    local isRobbing = false

    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario and DoesEntityExist(cashierPed) do
            Citizen.Wait(1000)

            if ClientApplication.state.activeScenario.game.location and
                ClientApplication.state.activeScenario.game.location.cashier.robbed
            then
                return
            end

            local isAnyPlayerPointingWeapon = false
            local pointingPlayer = nil

            local players = GetActivePlayers()
            for _, player in pairs(players) do
                local playerPed = GetPlayerPed(player)
                if playerPed and playerPed ~= cache.ped then
                    local weaponHash = GetSelectedPedWeapon(playerPed)
                    if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
                        local isPointing, targetEntity = GetEntityPlayerIsFreeAimingAt(player)
                        if isPointing and targetEntity == cashierPed then
                            isAnyPlayerPointingWeapon = true
                            pointingPlayer = player
                            break
                        end
                    end
                end
            end

            if not isAnyPlayerPointingWeapon then
                local weaponHash = GetSelectedPedWeapon(cache.ped)
                if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
                    local isPointing, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
                    if isPointing and targetEntity == cashierPed then
                        isAnyPlayerPointingWeapon = true
                        pointingPlayer = PlayerId()
                    end
                end
            end

            if pointingPlayer then
                if not isRobbing then
                    isRobbing = true

                    lib.playAnim(cashierPed, "mp_am_hold_up", "handsup_base", 8.0, 8.0, -1, 2)

                    Citizen.CreateThread(function()
                        Citizen.Wait(math.random(500, 1500))
                        PlayPedAmbientSpeechNative(cashierPed, "SHOP_SCARED", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                    end)
                end

                if not ClientApplication.state.lobby or ClientApplication.state.lobby.owner ~= cache.serverId then
                    Utils.notify(locale("store_robbery.only_owner_can_start"), "error", 3000)
                else
                    Utils.progressBar({
                        duration = 10000,
                        label = locale("store_robbery.robbing_cashier"),
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            car = true,
                            move = true,
                            combat = false,
                            sprint = true,
                        },
                    })
                    TriggerServerEvent(_e("server:scenarios:store_robbery:onCashierRobbed"),
                        {
                            lobbyId = ClientApplication.state.lobby and ClientApplication.state.lobby.id or nil,
                            locationIndex =
                                locationIndex
                        })
                    break
                end
            elseif isRobbing then
                isRobbing = false
                ClearPedTasks(cashierPed)
                TaskStartScenarioInPlace(cashierPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
            end
        end
    end)
end

---@param locations {cashier: {model:string, coords: vector4} }[]
local function setupCashierSpawnPoints(locations)
    for locationIndex, location in pairs(locations) do
        local cashier = location.cashier
        if cashier then
            local blip = Utils.addBlip(cashier.coords, SHARED_CONFIG.blips.cashier, false, true)
            state.blips["cashier_" .. locationIndex] = blip

            local point = lib.points.new({
                coords = cashier.coords,
                distance = cashier.spawnDistance or 25.0,
                onEnter = function(self)
                    self:remove()

                    local cashierPed = Utils.createPed({
                        model = cashier.model,
                        coords = cashier.coords,
                        freeze = false,
                        invincible = false,
                        blockevents = true,
                        isNetwork = false,
                    })

                    state.spawnedCashiers[locationIndex] = cashierPed
                    onCashierPedSpawned(locationIndex, cashierPed)
                    HeistClient.updateActiveInfoIndex(2)
                end
            })
        end
    end
end

local function askLeaderToSetupVehicles()
    local input = lib.inputDialog(locale("store_robbery.input_heading_which_vehicle"), {
        {
            type = "select",
            label = locale("store_robbery.input_row_which_vehicle"),
            description = locale("store_robbery.input_row_which_vehicle_desc"),
            required = true,
            options = {
                { label = locale("store_robbery.input_row_option_my_vehicle"),       value = "my_vehicle", },
                { label = locale("store_robbery.input_row_option_scenario_vehicle"), value = "scenario_vehicle", },
            },
        },
    }, { allowCancel = false })
    if not input then return end

    local selectedVehicleType = input[1]
    if not selectedVehicleType then
        return askLeaderToSetupVehicles()
    end

    lib.callback.await(_e("server:store_robbery:onVehicleSelected"), false,
        { lobbyId = ClientApplication.state.lobby.id, selectedVehicleType = selectedVehicleType })
end

local function playRobbedCashierScenario(locationIndex)
    local cashierPed = state.spawnedCashiers[locationIndex]
    if cashierPed and DoesEntityExist(cashierPed) then
        ClearPedTasksImmediately(cashierPed)
        lib.playAnim(cashierPed, "mp_am_hold_up", "holdup_victim_20s", 8.0, 8.0, -1, 2)

        Citizen.CreateThread(function()
            Citizen.Wait(20500)
            if ClientApplication.state.activeScenario and DoesEntityExist(cashierPed) then
                spawnMoneyObject(cashierPed, locationIndex)
                HeistClient.updateActiveInfoIndex(3)
                ClearPedTasksImmediately(cashierPed)
                lib.playAnim(cashierPed, "mp_am_hold_up", "handsup_base", 8.0, 8.0, -1, 2)
            end
        end)
    end
end

local function setupMiniSafe(locationIndex)
    local location = config.locations[SV_MAP_TYPE][locationIndex]
    if not location or not location.miniSafe then return end

    local body = { model = location.miniSafe.body.model, coords = location.miniSafe.body.coords, netId = nil }
    local door = { model = location.miniSafe.door.model, coords = location.miniSafe.door.coords, netId = nil }

    for _, value in pairs({ body, door }) do
        local prop = Utils.createObject({
            model = value.model,
            coords = value.coords,
            rotation = value.coords.w or 0.0,
            freeze = true,
            isNetwork = true,
        })
        local propNetId = Utils.waitFor(function()
            if not NetworkGetEntityIsNetworked(prop) then
                NetworkRegisterEntityAsNetworked(prop)
            else
                local netId = ObjToNet(prop)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, 3000)
        value.netId = propNetId
    end

    TriggerServerEvent(_e("server:scenarios:store_robbery:onMiniSafeSetup"), {
        lobbyId = ClientApplication.state.lobby.id,
        bodyNetId = body.netId,
        doorNetId = door.netId,
    })
end

local function setupMiniSafeTargetZone(locationIndex)
    local location = ClientApplication.state.activeScenario.game.location
    if not location or not location.miniSafe then return end

    local zone = location.miniSafe.zone
    if not zone then return end

    local zoneName = "store_robbery_mini_safe_zone_" .. locationIndex
    state.zones["mini_safe"] = zoneName

    Target.addBoxZone(zoneName, {
        name = zoneName,
        coords = zone.coords,
        size = zone.size,
        rotation = zone.rotation,
        debug = zone.debug or Config.debug,
        options = {
            {
                label = locale("store_robbery.open_mini_safe"),
                icon = "fa-solid fa-circle-notch",
                distance = 2.0,
                canInteract = function()
                    return not state.isBusy and
                        not ClientApplication.state.activeScenario.game.location.miniSafe.opened
                end,
                onSelect = function()
                    state.isBusy = true
                    local animation = config.animationOptions.openMiniSafe
                    lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, 8.0, -1, 2)

                    local skillbarSuccess = Skillbar.show("safepad",
                        { pin = ClientApplication.state.activeScenario.game.miniSafePin })

                    if not skillbarSuccess then
                        Utils.notify(locale("skillbar_cancelled"), "error")
                        ClearPedTasks(cache.ped)
                        state.isBusy = false
                        return
                    end

                    Utils.progressBar({
                        duration = 10000,
                        label = locale("store_robbery.opening_mini_safe"),
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            car = true,
                            move = true,
                            combat = true,
                            sprint = true,
                        },
                    })

                    ClearPedTasks(cache.ped)
                    state.isBusy = false

                    RequestAmbientAudioBank("SAFE_CRACK", false)
                    PlaySoundFrontend(0, "SAFE_DOOR_OPEN", "SAFE_CRACK_SOUNDSET", true)

                    lib.callback.await(_e("server:store_robbery:onMiniSafeOpened"), false,
                        { lobbyId = ClientApplication.state.lobby.id })
                end,
            },
            {
                label = locale("store_robbery.loot_mini_safe"),
                icon = "fa-solid fa-circle-notch",
                distance = 2.0,
                canInteract = function()
                    return not state.isBusy and
                        ClientApplication.state.activeScenario.game.location.miniSafe.opened
                end,
                onSelect = function()
                    state.isBusy = true
                    local animation = config.animationOptions.lootMiniSafe
                    lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, 8.0, 3000)

                    Citizen.Wait(3000)
                    ClearPedTasks(cache.ped)
                    state.isBusy = false

                    local response = lib.callback.await(
                        _e("server:scenarios:store_robbery:lootMiniSafe"), false,
                        { lobbyId = ClientApplication.state.lobby.id })

                    if not response.success then
                        Utils.notify(locale("store_robbery.could_not_loot"), "error", 5000)
                        if response.message then
                            Utils.notify(response.message, "error", 5000)
                        end
                    else
                        Utils.notify(locale("store_robbery.looted_mini_safe"), "success", 5000)
                    end

                    Target.removeZone(state.zones["mini_safe"])
                    state.zones["mini_safe"] = nil

                    for _, inside in pairs(state.miniSafeInside) do
                        if inside and DoesEntityExist(inside) then
                            DeleteEntity(inside)
                        end
                    end
                end,
            },
        },
    })
end

local function setupMiniSafeInside(locationIndex)
    local location = config.locations[SV_MAP_TYPE][locationIndex]
    if not location or not location.miniSafe then return end
    local inside = location.miniSafe.inside
    if not inside then return end

    for _, item in pairs(inside) do
        local prop = Utils.createObject({
            model = item.model,
            coords = item.coords,
            rotation = item.coords.w or 0.0,
            freeze = true,
            isNetwork = false,
        })
        table.insert(state.miniSafeInside, prop)
    end
end

---@param loot table
---@param lootIndex number
local function canInteractWithLoot(loot, lootIndex)
    if state.isBusy then return false end
    if loot.busy or loot.looted then return false end

    local response = lib.callback.await(
        _e("server:scenarios:store_robbery:canLootPoint"),
        false,
        { lobbyId = ClientApplication.state.lobby.id, lootIndex = lootIndex }
    )

    return response
end

local function canInteractWithCashRegister(cashRegister, index)
    if state.isBusy then return false end
    if cashRegister.busy or cashRegister.looted then return false end

    local response = lib.callback.await(
        _e("server:scenarios:store_robbery:canLootCashRegister"),
        false,
        { lobbyId = ClientApplication.state.lobby.id, cashRegisterIndex = index }
    )

    return response
end

local function interactWithCashRegister(cashRegister, index)
    if not canInteractWithCashRegister(cashRegister, index) then
        Utils.notify(locale("store_robbery.cannot_loot"), "error", 5000)
        return
    end

    state.isBusy = true

    local animation = config.animationOptions.carry
    if animation then
        local animationDuration = animation.duration or 2000
        lib.playAnim(cache.ped, animation.dict, animation.name,
            false, false, animationDuration, 1)
        Citizen.Wait(animationDuration)
        ClearPedTasks(cache.ped)
    end

    local response = lib.callback.await(
        _e("server:scenarios:store_robbery:carryCashRegister"),
        false,
        { lobbyId = ClientApplication.state.lobby.id, cashRegisterIndex = index }
    )
    if response.success then
        Utils.notify(locale("store_robbery.carrying_loot"), "success")
    else
        state.isBusy = false
        Utils.notify(locale("store_robbery.carry_failed"), "error")
        if response.message then
            Utils.notify(response.message, "error", 5000)
        end
    end
end

local function setupLootableCashRegisters(locationIndex)
    local location = config.locations[SV_MAP_TYPE][locationIndex]
    if not location or not location.lootableCashRegisters then return end

    for index, cashRegister in pairs(location.lootableCashRegisters) do
        if cashRegister.zone then
            if ClientApplication.state.activeScenario.game.location.lootableCashRegisters[index] and
                not ClientApplication.state.activeScenario.game.location.lootableCashRegisters[index].busy and
                not ClientApplication.state.activeScenario.game.location.lootableCashRegisters[index].looted
            then
                local zoneName = ("scenario:store_robbery:cash_register_%s"):format(index)
                state.zones["cash_register_" .. index] = zoneName
                local targetLabel = locale("store_robbery.grab_cash_register")

                Target.addBoxZone(zoneName, {
                    name = zoneName,
                    coords = cashRegister.zone.center,
                    size = cashRegister.zone.size or vector3(0.5, 0.5, 0.5),
                    rotation = cashRegister.zone.rotation or 0.0,
                    debug = cashRegister.zone.debug or Config.debug,
                    options = { {
                        label = targetLabel,
                        icon = "fa-solid fa-circle-notch",
                        distance = 2.0,
                        canInteract = function()
                            return not state.isBusy and
                                not cashRegister.busy and not cashRegister.looted
                        end,
                        onSelect = function()
                            interactWithCashRegister(cashRegister, index)
                        end,
                    } },
                })
            end
        end
    end
end

local function onCashRegisterThrown(object)
    Target.addLocalEntity(object, { {
        label = locale("store_robbery.collect_money"),
        icon = "fa-solid fa-money-bill-1-wave",
        distance = 2.0,
        canInteract = function()
            return not state.isBusy and ClientApplication.state.activeScenario
        end,
        onSelect = function()
            Target.removeLocalEntity(object)

            local animation = {
                dict     = "amb@medic@standing@tendtodead@idle_a",
                name     = "idle_a",
                duration = 2000,
            }

            lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, 8.0, animation.duration)
            Citizen.Wait(animation.duration)
            ClearPedTasks(cache.ped)

            TriggerServerEvent(_e("server:scenarios:store_robbery:onCashRegisterThrown"),
                { lobbyId = ClientApplication.state.lobby.id, cashRegisterIndex = state.holding.lootIndex })

            Citizen.SetTimeout(3000, function()
                if DoesEntityExist(object) then
                    DeleteEntity(object)
                end
            end)
        end
    } })
end

local function createElectricLeakEffect(entity)
    local electricEffect = {
        dict = "core",
        name = "ent_amb_elec_crackle",
    }

    local ptfxAsset = electricEffect.dict
    lib.requestNamedPtfxAsset(ptfxAsset)
    UseParticleFxAssetNextCall(ptfxAsset)

    local effect = StartParticleFxLoopedOnEntity(
        electricEffect.name, entity,
        0.0, 0.0, 0.5,
        0.0, 0.0, 0.0,
        1.0, false, false, false
    )

    return effect
end

local function stopElectricLeakEffect(effect)
    if effect then
        StopParticleFxLooped(effect, false)
    end
end

local function onCashRegisterCarried()
    Utils.showTextUI(locale("store_robbery.break_cash_register"), "E")

    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario and state.holding.object do
            Citizen.Wait(1)

            if IsControlJustPressed(0, 38) then
                Utils.hideTextUI()
                ClearPedTasksImmediately(cache.ped)
                local forwardVector = GetEntityForwardVector(cache.ped)

                local animation = config.animationOptions.throwCashRegister
                lib.requestAnimDict(animation.dict)
                TaskPlayAnim(cache.ped, animation.dict, animation.name, 1.0, -1.0, -1, 0, 0, 0, 0, 0)
                RemoveAnimDict(animation.dict)
                Citizen.Wait(500)

                DetachEntity(state.holding.object)
                FreezeEntityPosition(state.holding.object, false)
                ActivatePhysics(state.holding.object)
                SetEntityDynamic(state.holding.object, true)

                local forwardVector = GetEntityForwardVector(cache.ped)
                ApplyForceToEntity(state.holding.object, 1,
                    forwardVector.x * 25.0, forwardVector.y * 25.0,
                    2.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)

                ClearPedTasks(cache.ped)

                state.isBusy = false

                local effect = createElectricLeakEffect(state.holding.object)
                Citizen.Wait(1000)
                stopElectricLeakEffect(effect)
                onCashRegisterThrown(state.holding.object)

                break
            end
        end
    end)
end

local function setupLoots(locationIndex)
    local location = config.locations[SV_MAP_TYPE][locationIndex]
    if not location or not location.loots then return end

    Citizen.CreateThread(function()
        local closestLoot = nil
        local textui = false

        local isVehicleTypeScenario = ClientApplication.state.activeScenario.game.vehicleType == "scenario_vehicle"

        while ClientApplication.state.activeScenario do
            local wait = 1000
            local playerCoords = GetEntityCoords(cache.ped)
            local closestDistance = 8.0
            local newClosestLoot = nil

            local storeLoots = ClientApplication.state.activeScenario.game.location.loots

            for index, loot in pairs(storeLoots) do
                local lootCoords = loot.prop and loot.prop.coords or loot.coords or vector3(0.0, 0.0, 0.0)
                if storeLoots[index] and
                    not storeLoots[index].looted and
                    (loot.interaction ~= "carry" or isVehicleTypeScenario)
                then
                    local distance = #(playerCoords - lootCoords)

                    if distance < 5.0 then
                        wait = 0

                        local markerCoords = loot.markerCoords or lootCoords
                        DrawMarker(
                            28,
                            markerCoords.x, markerCoords.y, markerCoords.z,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.04, 0.04, 0.04,
                            189, 219, 9, 255,
                            false, true, 2, false, nil, nil, false
                        )

                        if distance < closestDistance then
                            closestDistance = distance
                            newClosestLoot = { index = index, distance = distance, loot = loot, coords = lootCoords }
                        end
                    end
                end
            end

            if newClosestLoot and newClosestLoot.distance < 1.5 then
                closestLoot = newClosestLoot

                if not textui then
                    local text = newClosestLoot.loot.interaction == "search" and
                        locale("store_robbery.search_loot") or
                        locale("store_robbery.carry_loot")
                    Utils.showTextUI(text, "E")
                    textui = true
                end

                if IsControlJustPressed(0, 38) then
                    if not canInteractWithLoot(closestLoot.loot, closestLoot.index) then
                        Utils.notify(locale("store_robbery.cannot_loot"), "error", 5000)
                    else
                        Utils.hideTextUI()
                        textui = false
                        state.isBusy = true

                        local animation = config.animationOptions[closestLoot.loot.interaction]

                        TaskTurnPedToFaceCoord(cache.ped,
                            closestLoot.coords.x,
                            closestLoot.coords.y,
                            closestLoot.coords.z, 4000)

                        Citizen.Wait(500)

                        lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, 8.0, animation.duration)
                        Citizen.Wait(animation.duration)
                        ClearPedTasks(cache.ped)

                        local response = lib.callback.await(
                            _e("server:scenarios:store_robbery:lootPoint"), false,
                            { lobbyId = ClientApplication.state.lobby.id, lootIndex = closestLoot.index })

                        if not response.success then
                            Utils.notify(locale("store_robbery.could_not_loot"), "error", 5000)
                            if response.message then
                                Utils.notify(response.message, "error", 5000)
                            end
                            state.isBusy = false
                        else
                            if closestLoot.loot.interaction == "carry" then
                                Utils.notify(locale("store_robbery.carrying_loot"), "success", 5000)
                            else
                                Utils.notify(locale("store_robbery.looted_point"), "success", 5000)
                                state.isBusy = false
                            end
                        end
                    end
                    wait = 500
                end
            else
                if textui then
                    closestLoot = nil
                    Utils.hideTextUI()
                    textui = false
                end
            end

            Citizen.Wait(wait)
        end

        if textui then
            Utils.hideTextUI()
        end
    end)
end

local function onPropCarried(animation)
    Citizen.CreateThread(function()
        local scenarioVehicles = {}
        local activeScenario = ClientApplication.state.activeScenario
        if not activeScenario then return end

        if activeScenario.game.vehicles and #activeScenario.game.vehicles > 0 then
            for _, value in pairs(activeScenario.game.vehicles) do
                table.insert(scenarioVehicles, value.vehicleNetId)
            end
        end

        local textui = false

        while ClientApplication.state.activeScenario and state.holding.object do
            local wait = 1000

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)
            local vehicle = lib.getClosestVehicle(playerCoords, 5.0, false)
            if vehicle then
                if NetworkGetEntityIsNetworked(vehicle) then
                    local vehicleNetId = VehToNet(vehicle)
                    if lib.table.contains(scenarioVehicles, vehicleNetId) then
                        local backCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)
                        local distance = #(playerCoords - backCoords)
                        if distance < 1.5 then
                            wait = 0
                            if not textui then
                                Utils.showTextUI(locale("store_robbery.place_loot_in_vehicle"), "E")
                                textui = true
                            end
                            if IsControlJustPressed(0, 38) then
                                Utils.hideTextUI()
                                state.isBusy = false

                                TriggerServerEvent(
                                    _e("server:scenarios:store_robbery:placeLootInVehicle"), {
                                        lobbyId = ClientApplication.state.lobby.id,
                                        lootIndex = state.holding.lootIndex,
                                        vehicleNetId = vehicleNetId
                                    }
                                )

                                deletePlayerHoldingLoot()
                                break
                            end
                        elseif textui then
                            Utils.hideTextUI()
                            textui = false
                        end
                    end
                end
            end

            if wait == 1000 then
                if not IsEntityPlayingAnim(playerPed, animation.dict, animation.name, 3) then
                    lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, -8.0, -1, 50)
                end
            end

            Citizen.Wait(wait)
        end

        if textui then
            Utils.hideTextUI()
        end
    end)
end

local function distanceCheckingForFinishThread()
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    Citizen.CreateThread(function()
        local centerCoords = GetEntityCoords(cache.ped)
        local locationIndex = ClientApplication.state.activeScenario.game.locationIndex
        local locationCashier = config.locations[SV_MAP_TYPE][locationIndex].cashier
        if locationCashier then
            centerCoords = locationCashier.coords
        end
        local maxDistance = config.requiredDistanceForFinish or 100.0

        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(centerCoords))
            if distance > maxDistance then
                TriggerServerEvent(_e("server:heist:setHeistCompleted"),
                    { lobbyId = ClientApplication.state.lobby.id, reason = "moved_too_far" }
                )
                Utils.notify(locale("moved_too_far"), "info", 5000)
                HeistClient.updateActiveInfoIndex(5)
                return
            end
            Citizen.Wait(1000)
        end
    end)
end

local function drawNearPropOutlineThread()
    Citizen.CreateThread(function()
        local locationIndex = ClientApplication.state.activeScenario.game.locationIndex
        if not locationIndex then return end
        local clonedLocation = lib.table.deepclone(config.locations[SV_MAP_TYPE][locationIndex])
        if not clonedLocation then return end

        while ClientApplication.state.activeScenario do
            local wait = 500

            SetEntityDrawOutlineColor(189, 219, 9, 255)
            SetEntityDrawOutlineShader(1)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            if clonedLocation.lootableCashRegisters then
                for index, cashRegister in pairs(clonedLocation.lootableCashRegisters) do
                    local isLooted = ClientApplication.state.activeScenario.game.location.lootableCashRegisters[index]
                        .looted
                    if not isLooted and cashRegister.prop and cashRegister.prop.coords then
                        local cashRegisterObject = GetClosestObjectOfType(
                            cashRegister.prop.coords.x,
                            cashRegister.prop.coords.y,
                            cashRegister.prop.coords.z,
                            0.1,
                            cashRegister.prop.model,
                            false, false, false)
                        if DoesEntityExist(cashRegisterObject) then
                            local distance = #(playerCoords - vector3(cashRegister.prop.coords))
                            if distance < 3.0 and not cashRegister.drawed then
                                cashRegister.drawed = true
                                SetEntityDrawOutline(cashRegisterObject, true)
                            elseif distance >= 3.0 and cashRegister.drawed then
                                cashRegister.drawed = false
                                SetEntityDrawOutline(cashRegisterObject, false)
                            end
                        end
                    end
                end
            end

            if clonedLocation.miniSafe and
                clonedLocation.miniSafe.body and
                not ClientApplication.state.activeScenario.game.location.miniSafe.opened
            then
                local miniSafeObject = GetClosestObjectOfType(
                    clonedLocation.miniSafe.body.coords.x,
                    clonedLocation.miniSafe.body.coords.y,
                    clonedLocation.miniSafe.body.coords.z,
                    0.1,
                    clonedLocation.miniSafe.body.model,
                    false, false, false)
                if DoesEntityExist(miniSafeObject) then
                    local distance = #(playerCoords - vector3(clonedLocation.miniSafe.body.coords))
                    if distance < 3.0 and not clonedLocation.miniSafe.drawed then
                        clonedLocation.miniSafe.drawed = true
                        SetEntityDrawOutline(miniSafeObject, true)
                    elseif distance >= 3.0 and clonedLocation.miniSafe.drawed then
                        clonedLocation.miniSafe.drawed = false
                        SetEntityDrawOutline(miniSafeObject, false)
                    end
                end
            end

            if clonedLocation.loots then
                for index, loot in pairs(clonedLocation.loots) do
                    local isLooted = ClientApplication.state.activeScenario.game.location.loots[index].looted
                    if loot.prop and loot.prop.coords then
                        local lootObject = GetClosestObjectOfType(
                            loot.prop.coords.x,
                            loot.prop.coords.y,
                            loot.prop.coords.z,
                            0.1,
                            loot.prop.model,
                            false, false, false)
                        if DoesEntityExist(lootObject) then
                            local distance = #(playerCoords - vector3(loot.prop.coords))
                            if distance < 3.0 and not loot.drawed then
                                loot.drawed = true
                                SetEntityDrawOutline(lootObject, true)
                            elseif distance >= 3.0 and loot.drawed then
                                loot.drawed = false
                                SetEntityDrawOutline(lootObject, false)
                            end
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

function StoreRobberyClient.clear()
    for key, blip in pairs(state.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    for _, zone in pairs(state.zones) do
        if zone then
            Target.removeZone(zone)
        end
    end

    for key, point in pairs(state.points) do
        if point and point.marker then
            point:remove()
        end
    end

    for _, cashierPed in pairs(state.spawnedCashiers) do
        if cashierPed and DoesEntityExist(cashierPed) then
            DeleteEntity(cashierPed)
        end
    end

    for _, moneyObject in pairs(state.moneyObjects) do
        if moneyObject and DoesEntityExist(moneyObject) then
            DeleteEntity(moneyObject)
        end
    end

    for _, insideObject in pairs(state.miniSafeInside) do
        if insideObject and DoesEntityExist(insideObject) then
            DeleteEntity(insideObject)
        end
    end

    deletePlayerHoldingLoot()

    __init_state__()
end

function StoreRobberyClient.init()
    setupCashierSpawnPoints(config.locations[SV_MAP_TYPE])

    if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
        askLeaderToSetupVehicles()
    end

    Utils.notify(locale("store_robbery.go_to_any_store"), "info", 5000)
end

RegisterNetEvent(_e("client:store_robbery:onVehicleTypeSelected"), function(params)
    local lobbyId = params.lobbyId
    local owner = params.owner
    local selectedVehicleType = params.selectedVehicleType
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= lobbyId then
        return
    end
    if ClientApplication.state.lobby.owner ~= owner then return end

    ClientApplication.state.activeScenario.game.vehicleType = selectedVehicleType

    if selectedVehicleType == "my_vehicle" then
        Utils.notify(locale("store_robbery.you_can_use_your_vehicle"), "info", 5000)
    elseif selectedVehicleType == "scenario_vehicle" then
        Utils.notify(locale("store_robbery.you_can_use_scenario_vehicle"), "info", 5000)
        HeistClient.setupSpawnVehiclePoints(config.robberyVehicles, false)
    end
end)

RegisterNetEvent(_e("client:scenarios:store_robbery:onLocationSet"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end
    if not ClientApplication.state.activeScenario then return end

    ---@type number
    local locationIndex = params.locationIndex
    ClientApplication.state.activeScenario.game.location = lib.table.deepclone(config.locations[SV_MAP_TYPE]
        [locationIndex])
    ClientApplication.state.activeScenario.game.locationIndex = locationIndex

    if params.isCashierRobbed then
        ClientApplication.state.activeScenario.game.location.cashier.robbed = params.isCashierRobbed
        playRobbedCashierScenario(locationIndex)
    end

    if ClientApplication.state.lobby.owner == cache.serverId then
        setupMiniSafe(locationIndex)

        local location = config.locations[SV_MAP_TYPE][locationIndex]
        triggerAlert(location.cashier.coords)
    end

    setupLootableCashRegisters(locationIndex)
    setupLoots(locationIndex)
    drawNearPropOutlineThread()
    distanceCheckingForFinishThread()

    for key, cashier in pairs(state.spawnedCashiers) do
        if key ~= locationIndex then
            DeleteEntity(cashier)
            state.spawnedCashiers[key] = nil
        end
    end

    for key, blip in pairs(state.blips) do
        if string.match(key, "cashier_%d+") and
            key ~= ("cashier_%s"):format(locationIndex) and
            DoesBlipExist(blip)
        then
            RemoveBlip(blip)
            state.blips[key] = nil
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:store_robbery:onMiniSafeSetup"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end
    if not ClientApplication.state.activeScenario then return end

    local bodyNetId = params.bodyNetId
    local doorNetId = params.doorNetId

    ClientApplication.state.activeScenario.game.location.miniSafe.body.netId = bodyNetId
    ClientApplication.state.activeScenario.game.location.miniSafe.door.netId = doorNetId

    setupMiniSafeTargetZone(ClientApplication.state.activeScenario.game.locationIndex)
end)

RegisterNetEvent(_e("client:store_robbery:onMiniSafeOpened"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end
    if not ClientApplication.state.activeScenario then return end

    setupMiniSafeInside(ClientApplication.state.activeScenario.game.locationIndex)

    ClientApplication.state.activeScenario.game.location.miniSafe.opened = true
    Utils.notify(locale("store_robbery.mini_safe_opened"), "success", 3000)
end)

RegisterNetEvent(_e("client:scenarios:store_robbery:onLootPointUpdated"), function(params)
    local lootIndex = params.lootIndex
    local looted = params.looted
    if not ClientApplication.state.lobby or
        not ClientApplication.state.activeScenario or
        not ClientApplication.state.activeScenario.game or
        not ClientApplication.state.activeScenario.game.location or
        not ClientApplication.state.activeScenario.game.location.loots
    then
        return
    end

    ClientApplication.state.activeScenario.game.location.loots[lootIndex].looted = looted

    local loot = config.locations[SV_MAP_TYPE][ClientApplication.state.activeScenario.game.locationIndex].loots
        [lootIndex]

    if loot.interaction == "carry" then
        local closestObject = GetClosestObjectOfType(
            loot.prop.coords.x, loot.prop.coords.y, loot.prop.coords.z, 0.3,
            loot.prop.model,
            false, false, false
        )
        if DoesEntityExist(closestObject) then
            SetEntityAsMissionEntity(closestObject, true, true)
            DeleteEntity(closestObject)
        end

        if params.holdingBy == cache.serverId then
            local offset = loot.positions.onHolding.offset
            local rotation = loot.positions.onHolding.rotation
            local bone = loot.positions.onHolding.boneId or 28422

            local dumpedProp = Utils.createObject({
                model = loot.prop.model,
                coords = loot.prop.coords,
                rotation = loot.prop.coords.w,
                freeze = false,
                isNetwork = true,
            })

            state.holding.object = dumpedProp
            state.holding.lootIndex = lootIndex
            state.holding.objectNetId = lib.waitFor(function()
                if not NetworkGetEntityIsNetworked(dumpedProp) then
                    NetworkRegisterEntityAsNetworked(dumpedProp)
                else
                    local netId = ObjToNet(dumpedProp)
                    if NetworkDoesNetworkIdExist(netId) then
                        return netId
                    end
                end
            end, nil, false)

            AttachEntityToEntity(
                dumpedProp,
                cache.ped,
                GetPedBoneIndex(cache.ped, bone),
                offset.x, offset.y, offset.z,
                rotation.x, rotation.y, rotation.z,
                true, true, false, true, 1, true
            )

            local animation = config.animationOptions["carrying"]
            if animation then
                lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, -8.0, -1, 50)
            end

            onPropCarried(animation)
        end
    end
end)

RegisterNetEvent(_e("client:scenarios:store_robbery:onCarryCashRegister"), function(params)
    local cashRegisterIndex = params.cashRegisterIndex
    local holdingBy = params.holdingBy

    if not ClientApplication.state.activeScenario then return end

    local location = ClientApplication.state.activeScenario.game.location
    if not location or not location.lootableCashRegisters then return end

    local loot = location.lootableCashRegisters[cashRegisterIndex]
    if not loot then return end

    loot.busy = true

    local prop = GetClosestObjectOfType(
        loot.prop.coords.x, loot.prop.coords.y, loot.prop.coords.z, 0.3,
        loot.prop.model,
        false, false, false
    )
    if DoesEntityExist(prop) then
        SetEntityAsMissionEntity(prop, true, true)
        DeleteEntity(prop)
    end

    if holdingBy == cache.serverId then
        local offset = vector3(0.0, -0.1, -0.14)
        local rotation = vector3(0.0, 0.0, 0.0)
        local bone = 28422

        local dumpedProp = Utils.createObject({
            model = loot.prop.holdingModel,
            coords = loot.prop.coords,
            rotation = loot.prop.coords.w,
            freeze = false,
            isNetwork = true,
        })

        deletePlayerHoldingLoot()

        state.holding.object = dumpedProp
        state.holding.lootIndex = cashRegisterIndex

        AttachEntityToEntity(
            dumpedProp,
            cache.ped,
            GetPedBoneIndex(cache.ped, bone),
            offset.x, offset.y, offset.z,
            rotation.x, rotation.y, rotation.z,
            true, true, false, true, 1, true
        )

        local animation = config.animationOptions["carrying"]
        if animation then
            lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, -8.0, -1, 50)
        end

        onCashRegisterCarried()
    end
end)

RegisterNetEvent(_e("client:scenarios:store_robbery:onCashRegisterLooted"), function(params)
    if not ClientApplication.state.activeScenario then return end

    local cashRegisterIndex = params.cashRegisterIndex
    local looted = params.looted

    local location = ClientApplication.state.activeScenario.game.location
    if not location or not location.lootableCashRegisters then return end

    location.lootableCashRegisters[cashRegisterIndex].looted = true

    local zoneName = state.zones["cash_register_" .. cashRegisterIndex]
    Target.removeZone(zoneName)
    state.zones["cash_register_" .. cashRegisterIndex] = nil
end)

RegisterNetEvent(_e("client:scenarios:store_robbery:onLootPlacedInVehicle"), function(params)
    local lootIndex = params.lootIndex

    if not ClientApplication.state.activeScenario or
        not ClientApplication.state.activeScenario.game or
        not ClientApplication.state.activeScenario.game.location or
        not ClientApplication.state.activeScenario.game.location.loots or
        not ClientApplication.state.activeScenario.game.location.loots[lootIndex]
    then
        return
    end

    local loot = ClientApplication.state.activeScenario.game.location.loots[lootIndex]
    loot.busy = false
    loot.looted = true
end)

lib.callback.register(_e("client:scenarios:store_robbery:spawnLootInVehicle"), function(params)
    local locationIndex = params.locationIndex
    local lootIndex = params.lootIndex
    local vehicleNetId = params.vehicleNetId
    local vehicle = NetToVeh(vehicleNetId)

    local loot = config.locations[SV_MAP_TYPE][locationIndex].loots[lootIndex]
    if not loot or not loot.positions.onVehicle then
        return nil
    end

    if DoesEntityExist(vehicle) then
        local offset = loot.positions.onVehicle.offset
        local rotation = loot.positions.onVehicle.rotation
        local boneName = loot.positions.onVehicle.boneName or "chassis"
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        local bone = boneIndex ~= -1 and boneIndex or 0

        local prop = Utils.createObject({
            model = loot.prop.model,
            coords = GetEntityCoords(vehicle),
            rotation = 0.0,
            freeze = true,
            isNetwork = true,
        })

        local propNetId = lib.waitFor(function()
            if not NetworkGetEntityIsNetworked(prop) then
                NetworkRegisterEntityAsNetworked(prop)
            else
                local netId = ObjToNet(prop)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, nil, false)

        AttachEntityToEntity(
            prop,
            vehicle,
            boneIndex,
            offset.x, offset.y, offset.z,
            rotation.x, rotation.y, rotation.z,
            true, true, false, true, 1, true
        )

        return propNetId
    end

    return nil
end)
