local lib                = lib
local Utils              = require("modules.utils.client")

local config             = lib.load("config.scenarios.truck_robbery")
local SHARED_CONFIG      = lib.load("config.scenarios._shared")

local GuardManagerClient = require("core.scenarios._shared.client.guards")

TruckRobberyClient       = {}

-- State management
local state              = {
    isBusy = false,
    blips = {},
    locationIndex = nil,
    distanceForFinishWorking = false,
    truckNetId = nil,
    trailerNetId = nil,
    forkliftNetId = nil,
    containerNetIds = {},      -- Çoklu konteyner desteği için tablo
    points = {},
    currentContainerIndex = 1, -- Şu anda yüklenen konteyner indeksi
    containersLoadedCount = 0, -- Yüklenen konteyner sayısı
    fakeContainer = nil,
}

local managers           = {
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
    Utils.triggerPoliceAlert("truck_robbery", locale("truck_robbery.police_alert"), coords)
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

local function attachContainerToForklift()
    TriggerServerEvent(_e("server:scenarios:truck_robbery:onAttachContainerToForklift"), {
        lobbyId = ClientApplication.state.lobby.id,
    })
end

local function attachContainerToTrailer()
    TriggerServerEvent(_e("server:scenarios:truck_robbery:onAttachContainerToTrailer"), {
        lobbyId = ClientApplication.state.lobby.id,
    })
end

local function createTemporaryOutlinedContainer()
    local trailerNetId = state.trailerNetId
    local trailerEntity = Utils.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(trailerNetId) then
            local entity = NetToVeh(trailerNetId)
            if DoesEntityExist(entity) then return entity end
        end
    end, 3000)
    if not trailerEntity then return end

    local fakeContainer = Utils.createObject({
        model = config.containerModel,
        coords = GetEntityCoords(trailerEntity),
        isNetwork = false,
        alpha = 100,
    })

    local offset = config.attachContainerToTrailerOffset[state.currentContainerIndex]
    local coords = offset.coords
    local rot = offset.rot

    AttachEntityToEntity(fakeContainer, trailerEntity, 0,
        coords.x, coords.y, coords.z,
        rot.x, rot.y, rot.z,
        false, false, false, false, 2, true)

    SetEntityDrawOutline(fakeContainer, true)
    SetEntityDrawOutlineColor(189, 219, 9, 255)
    SetEntityDrawOutlineShader(1)

    state.fakeContainer = fakeContainer
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
            TriggerServerEvent(_e("server:scenarios:truck_robbery:onGuardsSpawned"), {
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

    lib.callback.await(_e("server:scenarios:truck_robbery:onTruckSpawned"), false, {
        lobbyId = ClientApplication.state.lobby.id,
        vehicleNetIds = netIds,
    })
end

local function spawnForklift(location)
    local model = config.vehicles.forklift
    local coords = location.forkliftCoords

    lib.requestModel(model)
    local vehicleEntity = CreateVehicle(model,
        coords.x, coords.y, coords.z, coords.w or 0.0,
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

    SetEntityCoords(vehicleEntity, coords.x, coords.y, coords.z,
        false, false, false, false)
    SetEntityRotation(vehicleEntity, 0.0, 0.0, coords.w or 0.0, 2, false)
    SetModelAsNoLongerNeeded(model)

    lib.callback.await(_e("server:scenarios:truck_robbery:onForkliftSpawned"), false, {
        lobbyId = ClientApplication.state.lobby.id,
        vehicleNetId = vehicleNetId,
    })
end

local function spawnContainer(containerIndex, containerData)
    local model = containerData.model or config.containerModel
    local coords = containerData.coords

    lib.requestModel(model)
    local containerEntity = CreateObject(model,
        coords.x, coords.y, coords.z,
        true, true, true)
    while not DoesEntityExist(containerEntity) do Citizen.Wait(100) end

    local containerNetId = lib.waitFor(function()
        if not NetworkGetEntityIsNetworked(containerEntity) then
            NetworkRegisterEntityAsNetworked(containerEntity)
        else
            local netId = ObjToNet(containerEntity)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, nil, false)

    SetEntityCoords(containerEntity, coords.x, coords.y, coords.z,
        false, false, false, false)
    SetEntityRotation(containerEntity, 0.0, 0.0, coords.w or 0.0, 2, false)
    SetModelAsNoLongerNeeded(model)

    lib.callback.await(_e("server:scenarios:truck_robbery:onContainerSpawned"), false, {
        lobbyId = ClientApplication.state.lobby.id,
        containerNetId = containerNetId,
        containerIndex = containerIndex,
    })
end

local function spawnContainers()
    local location = config.locations[state.locationIndex]
    if not location.containers then return end

    for index, containerData in pairs(location.containers) do
        spawnContainer(index, containerData)
    end
end

local function setupSpawning()
    if ClientApplication.state.lobby.owner ~= cache.serverId then return end

    local location = config.locations[state.locationIndex]
    local containers = location.containers
    for index, containerData in pairs(containers) do
        addBlip(containerData.coords, SHARED_CONFIG.blips.container, true, true, "container_" .. index)
    end

    Citizen.CreateThread(function()
        local location = config.locations[state.locationIndex]
        local firstContainer = location.containers and location.containers[1]
        if not firstContainer then return end

        local containerCoords = firstContainer.coords

        while ClientApplication.state.activeScenario do
            Citizen.Wait(500)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            local distanceFromTarget = #(playerCoords - vector3(containerCoords.x, containerCoords.y, containerCoords.z))
            if distanceFromTarget < 190.0 then
                spawnForklift(location)
                spawnContainers()
                spawnGuards()
                break
            end
        end

        while ClientApplication.state.activeScenario do
            Citizen.Wait(500)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            local distanceFromTarget = #(playerCoords - vector3(containerCoords.x, containerCoords.y, containerCoords.z))
            if distanceFromTarget < 50.0 then
                triggerAlert(containerCoords)
                break
            end
        end
    end)
end

local function setupForkliftUsage()
    Citizen.CreateThread(function()
        local textui = false

        local location = config.locations[state.locationIndex]

        SetEntityDrawOutlineColor(189, 219, 9, 255)
        SetEntityDrawOutlineShader(1)

        while ClientApplication.state.activeScenario and
            ClientApplication.state.activeScenario.game and
            state.containersLoadedCount < #location.containers
        do
            local wait = 500

            -- Check entities exist
            if not state.forkliftNetId or
                not NetworkDoesNetworkIdExist(state.forkliftNetId) or
                not NetworkDoesEntityExistWithNetworkId(state.forkliftNetId) or
                not DoesEntityExist(NetToVeh(state.forkliftNetId)) or
                not state.trailerNetId or
                not NetworkDoesNetworkIdExist(state.trailerNetId) or
                not NetworkDoesEntityExistWithNetworkId(state.trailerNetId) or
                not DoesEntityExist(NetToVeh(state.trailerNetId))
            then
                Citizen.Wait(500)
                goto continue
            end

            -- Mevcut konteyner kontrolü
            local currentContainerNetId = state.containerNetIds[state.currentContainerIndex]
            if not currentContainerNetId or
                not NetworkDoesNetworkIdExist(currentContainerNetId) or
                not NetworkDoesEntityExistWithNetworkId(currentContainerNetId) or
                not DoesEntityExist(NetToObj(currentContainerNetId))
            then
                Citizen.Wait(500)
                goto continue
            end

            local forkliftEntity = NetToVeh(state.forkliftNetId)
            local containerEntity = NetToObj(currentContainerNetId)
            local trailerEntity = NetToVeh(state.trailerNetId)

            local playerVehicle = cache.vehicle
            local playerVehicleSeat = cache.seat
            local containerAttachedForklift = ClientApplication.state.activeScenario.game.containerAttachedForklift

            if playerVehicle == forkliftEntity and playerVehicleSeat == -1 then
                local frameBoneIndex = GetEntityBoneIndexByName(forkliftEntity, "frame_2")
                if frameBoneIndex == -1 then
                    Citizen.Wait(500)
                    goto continue
                end
                local frameCoords = GetWorldPositionOfEntityBone(forkliftEntity, frameBoneIndex)

                if not containerAttachedForklift then
                    SetEntityDrawOutline(containerEntity, true)

                    local containerCoords = GetEntityCoords(containerEntity)
                    local distance = #(frameCoords - containerCoords)
                    if distance < 5.0 then
                        wait = 5
                        if not textui then
                            textui = true
                            Utils.showTextUI(locale("truck_robbery.use_forklift_prompt"), "E")
                        end
                        if IsControlJustReleased(0, 38) then
                            Utils.hideTextUI()
                            textui = false

                            attachContainerToForklift()

                            Citizen.Wait(1000)
                        end
                    else
                        if textui then
                            textui = false
                            Utils.hideTextUI()
                        end
                    end
                else
                    local trailerCoords = GetEntityCoords(trailerEntity)
                    local frameCoords = GetWorldPositionOfEntityBone(forkliftEntity, frameBoneIndex)
                    local distance = #(frameCoords - trailerCoords)
                    if distance < 5.0 then
                        wait = 5
                        if not textui then
                            textui = true
                            Utils.showTextUI(locale("truck_robbery.attach_container_to_trailer_prompt"), "E")
                        end
                        if IsControlJustReleased(0, 38) then
                            Utils.hideTextUI()
                            textui = false

                            attachContainerToTrailer()
                            ClientApplication.state.activeScenario.game.containerAttachedForklift = false

                            Citizen.Wait(1000)
                        end
                    else
                        if textui then
                            textui = false
                            Utils.hideTextUI()
                        end
                    end
                end
            end

            Citizen.Wait(wait)
            ::continue::
        end

        if textui then
            Utils.hideTextUI()
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

---@section PUBLIC FUNCTIONS

function TruckRobberyClient.clear()
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

    Utils.showTextUI(false)

    __init_state__()
end

function TruckRobberyClient.init()
    state.locationIndex = ClientApplication.state.activeScenario.game.locationIndex

    local location = config.locations[state.locationIndex]
    if not location then return end

    addBlip(location.truckCoords, SHARED_CONFIG.blips.truck, true, true, "truck")

    setupTruckSpawning()
end

RegisterNetEvent(_e("client:scenarios:truck_robbery:onVehicleSpawned"), function(params)
    local lobbyId = params.lobbyId
    local vehicleNetId = params.vehicleNetId
    local vehicleType = params.vehicleType

    local giveVehicle = false

    if ClientApplication.state.lobby.id ~= lobbyId then return end

    ClientApplication.state.activeScenario.game.vehicleNetIds[vehicleType] = vehicleNetId

    if vehicleType == "truck" then
        state.truckNetId = vehicleNetId
        setupSpawning()
        setupForkliftUsage()
        removeBlipByKey("truck")
        giveVehicle = true
    elseif vehicleType == "trailer" then
        state.trailerNetId = vehicleNetId
        Citizen.CreateThread(function()
            if ClientApplication.state.lobby.owner ~= cache.serverId then return end

            while ClientApplication.state.activeScenario do
                Citizen.Wait(1000) -- Her saniye kontrol et
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
    elseif vehicleType == "forklift" then
        state.forkliftNetId = vehicleNetId
        HeistClient.updateActiveInfoIndex(2)
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

RegisterNetEvent(_e("client:scenarios:truck_robbery:onContainerSpawned"), function(params)
    local lobbyId = params.lobbyId
    local containerNetId = params.containerNetId
    local containerIndex = params.containerIndex or 1

    if ClientApplication.state.lobby.id ~= lobbyId then return end

    -- Çoklu konteyner desteği
    if not ClientApplication.state.activeScenario.game.containerNetIds then
        ClientApplication.state.activeScenario.game.containerNetIds = {}
    end

    ClientApplication.state.activeScenario.game.containerNetIds[containerIndex] = containerNetId
    state.containerNetIds[containerIndex] = containerNetId

    -- İlk konteyner için eski compatibilty
    if containerIndex == 1 then
        ClientApplication.state.activeScenario.game.containerNetId = containerNetId
        HeistClient.updateActiveInfoIndex(2)
    end
end)

lib.callback.register(_e("client:scenarios:truck_robbery:spawnContainerOnForklift"), function(params)
    local forkliftNetId = params.forkliftNetId
    local forkliftEntity = Utils.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(forkliftNetId) then
            local entity = NetToVeh(forkliftNetId)
            if DoesEntityExist(entity) then return entity end
        end
    end, 3000)

    if forkliftEntity then
        local forkliftCoords = GetEntityCoords(forkliftEntity)
        local forkliftForward = GetEntityForwardVector(forkliftEntity)
        local spawnCoords = forkliftCoords + (forkliftForward * 2.0)

        local model = config.containerModel
        local containerEntity = Utils.createObject({
            model = model,
            coords = vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z),
            freeze = true,
            isNetwork = true,
        })

        local containerNetId = lib.waitFor(function()
            if not NetworkGetEntityIsNetworked(containerEntity) then
                NetworkRegisterEntityAsNetworked(containerEntity)
            else
                local netId = ObjToNet(containerEntity)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, nil, false)

        local boneIndex = GetEntityBoneIndexByName(forkliftEntity, "frame_2")
        local attachOffset = config.attachContainerToForkliftOffset.coords
        local attachRot = config.attachContainerToForkliftOffset.rot

        AttachEntityToEntity(containerEntity, forkliftEntity, boneIndex,
            attachOffset.x, attachOffset.y, attachOffset.z,
            attachRot.x, attachRot.y, attachRot.z,
            false, false, false, false, 2, true)

        return containerNetId
    end

    return false
end)

RegisterNetEvent(_e("client:scenarios:truck_robbery:onContainerAttachedToForklift"), function(params)
    local lobbyId = params.lobbyId

    if ClientApplication.state.lobby.id ~= lobbyId then return end

    ClientApplication.state.activeScenario.game.containerAttachedForklift = true

    HeistClient.updateActiveInfoIndex(3)

    if ClientApplication.state.lobby.owner == cache.serverId then
        triggerAlert(config.locations[state.locationIndex].containers[1].coords)
    end

    createTemporaryOutlinedContainer()
end)

lib.callback.register(_e("client:scenarios:truck_robbery:spawnContainerOnTrailer"), function(params)
    local trailerNetId = params.trailerNetId
    local trailerEntity = Utils.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(trailerNetId) then
            local entity = NetToVeh(trailerNetId)
            if DoesEntityExist(entity) then return entity end
        end
    end, 3000)

    if trailerEntity then
        local trailerCoords = GetEntityCoords(trailerEntity)
        local trailerForward = GetEntityForwardVector(trailerEntity)
        local spawnCoords = trailerCoords + (trailerForward * -2.0)

        local model = config.containerModel
        local containerEntity = Utils.createObject({
            model = model,
            coords = vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z),
            freeze = true,
            isNetwork = true,
        })

        local containerNetId = lib.waitFor(function()
            if not NetworkGetEntityIsNetworked(containerEntity) then
                NetworkRegisterEntityAsNetworked(containerEntity)
            else
                local netId = ObjToNet(containerEntity)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, nil, false)

        local containerIndex = state.currentContainerIndex
        local attachContainerToTrailerOffset = config.attachContainerToTrailerOffset[containerIndex]
        local attachOffset = attachContainerToTrailerOffset.coords
        local attachRot = attachContainerToTrailerOffset.rot

        AttachEntityToEntity(containerEntity, trailerEntity, 0,
            attachOffset.x, attachOffset.y, attachOffset.z,
            attachRot.x, attachRot.y, attachRot.z,
            false, false, false, false, 2, true)

        return containerNetId
    end

    return false
end)

RegisterNetEvent(_e("client:scenarios:truck_robbery:onContainerAttachedToTrailer"), function(params)
    local lobbyId = params.lobbyId

    if ClientApplication.state.lobby.id ~= lobbyId then return end

    state.containersLoadedCount = params.containersLoadedCount
    state.currentContainerIndex = params.currentContainerIndex
    ClientApplication.state.activeScenario.game.containerAttachedForklift = false

    if state.fakeContainer and DoesEntityExist(state.fakeContainer) then
        DeleteEntity(state.fakeContainer)
        state.fakeContainer = nil
    end

    if not params.allContainersLoaded then return end

    HeistClient.updateActiveInfoIndex(4)

    removeBlipByKey("container")
    local deliveryCoords = config.locations[state.locationIndex].deliveryCoords
    addBlip(deliveryCoords, SHARED_CONFIG.blips.container, true, false, "delivery")

    local point = lib.points.new({
        coords = deliveryCoords,
        distance = 8.0,
        onEnter = function(self)
            if not cache.vehicle then return end
            if cache.seat ~= -1 then return end

            local vehicleNetId = VehToNet(cache.vehicle)
            if vehicleNetId ~= state.truckNetId then return end

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
end)

RegisterNetEvent(_e("client:scenarios:truck_robbery:onGuardsSpawned"), function(params)
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
