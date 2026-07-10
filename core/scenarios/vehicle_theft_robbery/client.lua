local lib                 = lib
local Utils               = require("modules.utils.client")

local config              = lib.load("config.scenarios.vehicle_theft_robbery")
local SHARED_CONFIG       = lib.load("config.scenarios._shared")

local GuardManagerClient  = require("core.scenarios._shared.client.guards")

VehicleTheftRobberyClient = {}

-- State management
local state               = {
    isBusy = false,
    blips = {},
    locationIndex = nil,
    distanceForFinishWorking = false,
    truckNetId = nil,
    trailerNetId = nil,
    vehicleNetIds = {},
    points = {},
}

local managers            = {
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

    managers.guards = nil
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("vehicle_theft_robbery", locale("vehicle_theft_robbery.police_alert"), coords)
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

-- Trailer'a tüm araçlar yakın mı kontrolü
local function areAllVehiclesNearTrailer(distance)
    local trailerNetId = state.trailerNetId
    if not trailerNetId or not NetworkDoesEntityExistWithNetworkId(trailerNetId) then return false end
    local trailerEntity = NetToVeh(trailerNetId)
    if not DoesEntityExist(trailerEntity) then return false end

    local expectedCount = 0
    local actualCount = 0

    for vehicleType, _ in pairs(config.locations[state.locationIndex].vehicles or {}) do
        if vehicleType ~= "truck" and vehicleType ~= "trailer" then
            expectedCount = expectedCount + 1
        end
    end

    for vehicleType, vehicleNetId in pairs(state.vehicleNetIds) do
        if vehicleType ~= "truck" and vehicleType ~= "trailer" then
            if not vehicleNetId or not NetworkDoesEntityExistWithNetworkId(vehicleNetId) then return false end
            local veh = NetToVeh(vehicleNetId)
            if not DoesEntityExist(veh) then return false end
            local vehCoords = GetEntityCoords(veh)
            local trailerCoords = GetEntityCoords(trailerEntity)
            if #(vehCoords - trailerCoords) > (distance or 15.0) then
                return false
            end
            actualCount = actualCount + 1
        end
    end

    if actualCount == 0 or actualCount ~= expectedCount then
        return false
    end

    return true
end

local function spawnGuards()
    if managers.guards and managers.guards:areGuardsSpawned() then return end
    if not state.locationIndex then return end

    local location = config.locations[state.locationIndex]
    if not location or not location.guards then return end

    -- Initialize guard manager
    managers.guards = GuardManagerClient.new({
        guards = location.guards,
        onGuardsSpawned = function(guardNetIds)
            TriggerServerEvent(_e("server:scenarios:vehicle_theft_robbery:onGuardsSpawned"), {
                lobbyId = ClientApplication.state.lobby.id,
                guardNetIds = guardNetIds,
            })
        end,
    })

    -- Update target players from lobby
    if ClientApplication.state.lobby then
        managers.guards:updateTargetPlayersFromLobby(ClientApplication.state.lobby)
    end

    -- Spawn guards
    managers.guards:spawnGuards(SHARED_CONFIG.models.guard, config.guardWeapon)
end

local function spawnTruck(location)
    local truckModel = config.vehicles.truck
    local truckCoords = location.truckCoords

    local trailerModel = config.vehicles.trailer
    local trailerCoords = location.trailerCoords

    local vehicles = {
        ["truck"] = { model = truckModel, coords = truckCoords },
        ["trailer"] = { model = trailerModel, coords = trailerCoords },
    }

    local netIds = {}

    for key, vehicle in pairs(vehicles) do
        lib.requestModel(vehicle.model)
        local vehicleEntity = CreateVehicle(vehicle.model,
            vehicle.coords.x, vehicle.coords.y, vehicle.coords.z, vehicle.coords.w or 0.0,
            true, true)
        while not DoesEntityExist(vehicleEntity) do Citizen.Wait(100) end

        local vehicleNetId = lib.waitFor(function()
            if not NetworkGetEntityIsNetworked(vehicleEntity) then
                NetworkRegisterEntityAsNetworked(vehicleEntity)
            else
                local netId = VehToNet(vehicleEntity)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, nil, false)

        netIds[key] = vehicleNetId

        SetEntityCoords(vehicleEntity, vehicle.coords.x, vehicle.coords.y, vehicle.coords.z,
            false, false, false, false)
        SetEntityRotation(vehicleEntity, 0.0, 0.0, vehicle.coords.w or 0.0, 2, false)
        SetModelAsNoLongerNeeded(vehicle.model)
    end

    lib.callback.await(_e("server:scenarios:vehicle_theft_robbery:onTruckSpawned"), false, {
        lobbyId = ClientApplication.state.lobby.id,
        vehicleNetIds = netIds,
    })
end

local function spawnVehicles(location)
    local vehicles = location.vehicles
    if not vehicles then return end

    for index, vehicleCoords in pairs(vehicles) do
        local vehicleModel = config.vehicles[index]
        lib.requestModel(vehicleModel)
        local vehicleEntity = CreateVehicle(vehicleModel,
            vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, vehicleCoords.w or 0.0,
            true, true)
        while not DoesEntityExist(vehicleEntity) do Citizen.Wait(100) end

        local vehicleNetId = lib.waitFor(function()
            if not NetworkGetEntityIsNetworked(vehicleEntity) then
                NetworkRegisterEntityAsNetworked(vehicleEntity)
            else
                local netId = VehToNet(vehicleEntity)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, nil, false)

        lib.callback.await(_e("server:scenarios:vehicle_theft_robbery:onVehicleSpawned"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            vehicleNetId = vehicleNetId,
            vehicleType = index,
        })
    end
end

local function setupSpawning()
    if ClientApplication.state.lobby.owner ~= cache.serverId then return end

    local location = config.locations[state.locationIndex]
    local vehicles = location.vehicles
    if not vehicles then return end
    for _, coords in pairs(vehicles) do
        addBlip(coords, SHARED_CONFIG.blips.theft_vehicle, true, true, "vehicle_" .. _)
    end

    Citizen.CreateThread(function()
        local location = config.locations[state.locationIndex]
        local vehicleCoords = location.vehicles.one

        while ClientApplication.state.activeScenario do
            Citizen.Wait(500)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            local distanceFromTarget = #(playerCoords - vector3(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z))
            if distanceFromTarget < 190.0 then
                spawnVehicles(location)
                spawnGuards()
                break
            end
        end

        while ClientApplication.state.activeScenario do
            Citizen.Wait(500)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)
            local allBlipsRemoved = true

            for _, coords in pairs(vehicles) do
                local distanceFromTarget = #(playerCoords - vector3(coords.x, coords.y, coords.z))
                if distanceFromTarget < 25.0 then
                    removeBlipByKey("vehicle_" .. _)
                else
                    allBlipsRemoved = false
                end
            end

            if allBlipsRemoved then
                triggerAlert(playerCoords)
                break
            end
        end
    end)
end

local function setupTruckSpawning()
    if ClientApplication.state.lobby.owner ~= cache.serverId then return end

    Citizen.CreateThread(function()
        local location = config.locations[state.locationIndex]
        local truckCoords = location.truckCoords

        while ClientApplication.state.activeScenario do
            Citizen.Wait(500)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            local distanceFromTarget = #(playerCoords - vector3(truckCoords.x, truckCoords.y, truckCoords.z))
            if distanceFromTarget < 190.0 then
                spawnTruck(location)
                break
            end
        end
    end)
end

local function setupTrailerUsing()
    Citizen.CreateThread(function()
        local isTextShown = false
        while ClientApplication.state.activeScenario do
            local wait = 500
            local truckNetId = state.truckNetId
            local trailerNetId = state.trailerNetId
            if truckNetId and
                trailerNetId and
                NetworkDoesEntityExistWithNetworkId(truckNetId) and
                NetworkDoesEntityExistWithNetworkId(trailerNetId)
            then
                local truckEntity = NetToVeh(truckNetId)
                local trailerEntity = NetToVeh(trailerNetId)
                if DoesEntityExist(truckEntity) and
                    DoesEntityExist(trailerEntity) and
                    cache.vehicle == truckEntity and
                    cache.seat == -1
                then
                    wait = 0
                    if not isTextShown then
                        isTextShown = true
                        Utils.showTextUI(locale("vehicle_theft_robbery.truck_interact_prompt"), "E")
                    end
                    if IsControlJustPressed(0, 38) then -- E tuşu
                        -- Server'a istek at: trailer kapısı aç/kapat
                        TriggerServerEvent(_e("server:scenarios:vehicle_theft_robbery:toggleTrailerDoor"), {
                            trailerNetId = trailerNetId,
                            doorIndex = 5
                        })
                    end
                else
                    if isTextShown then
                        Utils.hideTextUI()
                        isTextShown = false
                    end
                end
            end
            Citizen.Wait(wait)
        end

        Utils.hideTextUI()
    end)
end

local function setupDeliveryPoint()
    local deliveryCoords = config.locations[state.locationIndex].deliveryCoords
    addBlip(deliveryCoords, SHARED_CONFIG.blips.theft_delivery, false, true, "delivery")

    local point = lib.points.new({
        coords = deliveryCoords,
        distance = 8.0,
        onEnter = function(self)
            if not cache.vehicle then return end
            if cache.seat ~= -1 then return end

            local vehicleNetId = VehToNet(cache.vehicle)
            if vehicleNetId ~= state.truckNetId then return end

            -- Araçlar trailer'a yakın mı kontrolü
            if not areAllVehiclesNearTrailer(25.0) then
                Utils.notify(locale("vehicle_theft_robbery.vehicles_not_near_trailer"), "error")
                return
            end

            HeistClient.completeScenario()
        end,
    })
    state.points["delivery"] = point

    Citizen.CreateThread(function()
        local markerCoords = deliveryCoords
        while ClientApplication.state.activeScenario do
            Citizen.Wait(0)
            DrawMarker(21,
                markerCoords.x, markerCoords.y, markerCoords.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                1.5, 1.5, 1.5,
                255, 215, 0, 200,
                false, true, 2, false, nil, nil, false)
        end
    end)
end

---@section PUBLIC FUNCTIONS

function VehicleTheftRobberyClient.clear()
    for key, blip in pairs(state.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    -- Çoklu fake konteyner temizleme
    if state.fakeContainer then
        if DoesEntityExist(state.fakeContainer) then
            DeleteEntity(state.fakeContainer)
        end
    end

    if state.points then
        for _, point in pairs(state.points) do
            point:remove()
        end
    end

    __init_state__()
end

function VehicleTheftRobberyClient.init()
    state.locationIndex = ClientApplication.state.activeScenario.game.locationIndex

    local location = config.locations[state.locationIndex]
    if not location then return end

    addBlip(location.truckCoords, SHARED_CONFIG.blips.truck, true, true, "truck")

    setupTruckSpawning()
end

RegisterNetEvent(_e("client:scenarios:vehicle_theft_robbery:onVehicleSpawned"), function(params)
    local lobbyId = params.lobbyId
    local vehicleNetId = params.vehicleNetId
    local vehicleType = params.vehicleType

    local giveVehicle = false

    if ClientApplication.state.lobby.id ~= lobbyId then return end

    ClientApplication.state.activeScenario.game.vehicleNetIds[vehicleType] = vehicleNetId

    if vehicleType == "truck" then
        state.truckNetId = vehicleNetId
        setupTrailerUsing()
        removeBlipByKey("truck")
        setupSpawning()
        giveVehicle = true
        setupDeliveryPoint()
    elseif vehicleType == "trailer" then
        state.trailerNetId = vehicleNetId

        Citizen.CreateThread(function()
            if ClientApplication.state.lobby.owner ~= cache.serverId then return end

            while ClientApplication.state.activeScenario do
                Citizen.Wait(1000)
                local truckNetId = state.truckNetId
                local trailerNetId = state.trailerNetId

                -- Network ID'lerin varlığını kontrol et
                if not truckNetId or not trailerNetId or
                    not NetworkDoesNetworkIdExist(truckNetId) or
                    not NetworkDoesNetworkIdExist(trailerNetId) or
                    not NetworkDoesEntityExistWithNetworkId(truckNetId) or
                    not NetworkDoesEntityExistWithNetworkId(trailerNetId)
                then
                    goto continue
                end

                local truckEntity = NetToVeh(truckNetId)
                local trailerEntity = NetToVeh(trailerNetId)

                if not DoesEntityExist(truckEntity) or not DoesEntityExist(trailerEntity) then
                    goto continue
                end

                if not IsVehicleAttachedToTrailer(truckEntity) then
                    local truckCoords = GetEntityCoords(truckEntity)
                    local trailerCoords = GetEntityCoords(trailerEntity)
                    local distance = #(truckCoords - trailerCoords)

                    if distance < 15.0 then
                        AttachVehicleToTrailer(truckEntity, trailerEntity, 2.0)
                        local attempts = 0
                        while not IsVehicleAttachedToTrailer(truckEntity) and attempts < 5 do
                            Citizen.Wait(100)
                            AttachVehicleToTrailer(truckEntity, trailerEntity, 2.0)
                            attempts = attempts + 1
                        end
                    end
                end

                ::continue::
            end
        end)
    else
        state.vehicleNetIds[vehicleType] = vehicleNetId
        giveVehicle = true
    end

    if not giveVehicle then return end

    Citizen.CreateThread(function()
        local entity = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(vehicleNetId) then
                local entity = NetToVeh(vehicleNetId)
                if DoesEntityExist(entity) then return entity end
            end
        end, nil, false)

        HeistClient.giveVehicleKey(GetVehicleNumberPlateText(entity), entity)
    end)
end)

RegisterNetEvent(_e("client:scenarios:vehicle_theft_robbery:onGuardsSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if not managers.guards then
        local location = config.locations[state.realLocationIndex]
        if not location or not location.guards then return end

        managers.guards = GuardManagerClient.new({
            guards = location.guards,
        })
    end

    managers.guards:syncGuardsFromNetIds(params.guardNetIds)
end)

RegisterNetEvent(_e("client:scenarios:vehicle_theft_robbery:toggleTrailerDoor"), function(data)
    local trailerNetId = data.trailerNetId
    local doorIndex = data.doorIndex or 5
    if not trailerNetId then return end
    if not NetworkDoesEntityExistWithNetworkId(trailerNetId) then return end
    local trailerEntity = NetToVeh(trailerNetId)
    if not DoesEntityExist(trailerEntity) then return end

    if GetVehicleDoorAngleRatio(trailerEntity, doorIndex) == 0.0 then
        SetVehicleDoorOpen(trailerEntity, doorIndex, false, false)
        -- Kapı açıldı, kilidi kaldır
        SetVehicleDoorsLocked(trailerEntity, 1) -- unlocked
    else
        SetVehicleDoorShut(trailerEntity, doorIndex, true)
        -- Kapı kapandı, kilitle
        SetVehicleDoorsLocked(trailerEntity, 2) -- locked
    end
end)
