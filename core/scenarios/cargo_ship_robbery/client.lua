local lib                    = lib
local Utils                  = require("modules.utils.client")
local Target                 = require("modules.target.client")

local config                 = require("config.scenarios.cargo_ship_robbery")
local SHARED_CONFIG <const>  = lib.load("config.scenarios._shared")
local SPAWN_DISTANCE <const> = 150.0

local GuardManagerClient     = require("core.scenarios._shared.client.guards")
local LootManagerClient      = require("core.scenarios._shared.client.loot_manager")

CargoShipRobberyClient       = {}

-- State management
local state                  = {
    isBusy                    = false,
    blips                     = {},
    helicopterNetId           = nil,
    helicopterKeyObjectId     = nil,
    helicopterKeyPickUpThread = false,
    helicopterUsingThread     = false,
    bigContainers             = {}, -- {netId, targetCoords, delivered}
    targetObjects             = {}, -- hedef konumlarındaki objeler
    currentContainerIndex     = 1,
    ladders                   = {},
}

-- Manager instances
local managers               = {
    guards = nil,
    loot   = nil,
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
    Utils.triggerPoliceAlert("cargo_ship_robbery", locale("cargo_ship_robbery.police_alert"), coords)
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
            TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:onGuardsSpawned"), {
                lobbyId = ClientApplication.state.lobby.id,
                guardNetIds = guardNetIds,
            })
            triggerAlert(config.shipCenterCoords)
        end,
    })

    -- Update target players from lobby
    if ClientApplication.state.lobby then
        managers.guards:updateTargetPlayersFromLobby(ClientApplication.state.lobby)
    end

    -- Spawn guards
    managers.guards:spawnGuards("s_m_m_armoured_01", "WEAPON_CARBINERIFLE")
end

local function spawnHelicopter()
    local helicopterModel = config.helicopterSpawn.model
    local helicopterCoords = config.helicopterSpawn.coords

    lib.requestModel(helicopterModel)
    local helicopterEntity = CreateVehicle(helicopterModel,
        helicopterCoords.x, helicopterCoords.y, helicopterCoords.z, helicopterCoords.w or 0.0,
        true, true)
    while not DoesEntityExist(helicopterEntity) do Citizen.Wait(100) end

    local helicopterNetId = Utils.waitFor(function()
        if not NetworkGetEntityIsNetworked(helicopterEntity) then
            NetworkRegisterEntityAsNetworked(helicopterEntity)
        else
            local netId = VehToNet(helicopterEntity)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, 3000)

    SetEntityCoords(helicopterEntity, helicopterCoords.x, helicopterCoords.y, helicopterCoords.z,
        false, false, false, false)
    SetEntityRotation(helicopterEntity, 0.0, 0.0, helicopterCoords.w or 0.0, 2, false)
    SetModelAsNoLongerNeeded(helicopterModel)

    TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:onHelicopterSpawned"), {
        lobbyId = ClientApplication.state.lobby.id,
        helicopterNetId = helicopterNetId,
    })
end

local function setupHeliKeyPickup()
    if state.helicopterKeyPickUpThread then return end

    local keyObject = Utils.createObject({
        model = config.captainCabinKey.propModel,
        coords = config.captainCabinKey.coords,
        freeze = true,
        isNetwork = false,
    })
    state.helicopterKeyObjectId = keyObject

    state.helicopterKeyPickUpThread = true
    Citizen.CreateThread(function()
        local textui = false
        local outlineDrawn = false

        while ClientApplication.state.activeScenario and
            not ClientApplication.state.activeScenario.game.isHeliKeyTaken
        do
            local wait = 1000
            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - config.captainCabinKey.coords)
            if distance < 7.0 then
                if not outlineDrawn then
                    outlineDrawn = true
                    SetEntityDrawOutline(state.helicopterKeyObjectId, true)
                end

                if distance < 1.0 then
                    wait = 0
                    if not textui then
                        textui = true
                        Utils.showTextUI(locale("cargo_ship_robbery.pickup_heli_key"), "E")
                    end
                    if IsControlJustPressed(0, 38) then
                        Utils.hideTextUI()
                        textui = false

                        TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:onHeliKeyPickedUp"), {
                            lobbyId = ClientApplication.state.lobby.id,
                        })

                        break
                    end
                else
                    if textui then
                        textui = false
                        Utils.hideTextUI()
                    end
                end
            else
                if outlineDrawn then
                    outlineDrawn = false
                    SetEntityDrawOutline(state.helicopterKeyObjectId, false)
                end
                if textui then
                    textui = false
                    Utils.hideTextUI()
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

---@param loot LootPoint
---@param lootIndex number
local function interactionWithLoot(loot, lootIndex)
    state.isBusy = true

    local animationOption = SHARED_CONFIG.animations.search
    if animationOption then
        local animationDuration = animationOption.duration or 2000
        lib.playAnim(cache.ped, animationOption.dict, animationOption.name,
            8.0, -8.0, animationDuration, 1)

        Utils.progressBar({
            duration = animationDuration,
            label = locale("cargo_ship_robbery.looting"),
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
        _e("server:scenarios:cargo_ship_robbery:loot"),
        false,
        { lobbyId = ClientApplication.state.lobby.id, lootIndex = lootIndex }
    )

    if response.success then
        Utils.notify(locale("cargo_ship_robbery.looted_items"), "success")
    else
        Utils.notify(locale("cargo_ship_robbery.loot_failed"), "error")
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
            return locale("cargo_ship_robbery.search_loot")
        end,
        canInteract = function(loot, lootIndex)
            return not state.isBusy and not loot.busy and not loot.looted
        end,
        onSelect = function(loot, lootIndex)
            interactionWithLoot(loot, lootIndex)
        end,
        zonePrefix = "scenario:cargo_ship_robbery:",
        debug = Config.debug,
    })

    -- Start marker and delete threads
    managers.loot:startMarkerThread(5.0)
end

local function spawnLadders()
    if not config.ladders then return end

    for i, ladderConfig in ipairs(config.ladders) do
        lib.requestModel(ladderConfig.model)
        local ladderEntity = Utils.createObject({
            model = ladderConfig.model,
            coords = vector3(ladderConfig.coords.x, ladderConfig.coords.y, ladderConfig.coords.z),
            freeze = true,
            isNetwork = false,
            rotation = ladderConfig.rotation or vector3(0.0, 0.0, 0.0),
        })

        state.ladders[i] = ladderEntity
        SetModelAsNoLongerNeeded(ladderConfig.model)
    end
end

local function spawnBigContainers()
    for i, containerConfig in ipairs(config.bigContainers) do
        local containerModel = containerConfig.model
        local containerCoords = containerConfig.coords

        lib.requestModel(containerModel)
        local containerEntity = Utils.createObject({
            model = containerModel,
            coords = vector3(containerCoords.x, containerCoords.y, containerCoords.z),
            freeze = true,
            isNetwork = true,
            rotation = containerCoords.w or 0.0,
        })

        local containerNetId = Utils.waitFor(function()
            if not NetworkGetEntityIsNetworked(containerEntity) then
                NetworkRegisterEntityAsNetworked(containerEntity)
            else
                local netId = ObjToNet(containerEntity)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, 3000)

        state.bigContainers[i] = {
            netId = containerNetId,
            targetCoords = containerConfig.targetCoords,
            delivered = false
        }

        TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:onBigContainerSpawned"), {
            lobbyId = ClientApplication.state.lobby.id,
            containerIndex = i,
            containerNetId = containerNetId,
            targetCoords = containerConfig.targetCoords,
        })
    end
end

local function spawnTargetObjects()
    for i, containerConfig in ipairs(config.bigContainers) do
        local targetCoords = containerConfig.targetCoords

        -- Hedef konumunda geçici obje oluştur
        lib.requestModel("prop_container_ld_d")
        local targetObject = Utils.createObject({
            model = "prop_container_ld_d",
            coords = vector3(targetCoords.x, targetCoords.y, targetCoords.z),
            freeze = true,
            isNetwork = false,
            rotation = targetCoords.w or 0.0,
        })

        SetEntityAlpha(targetObject, 150, false)
        SetEntityDrawOutline(targetObject, true)

        state.targetObjects[i] = targetObject
    end
end

local function spawnShipInside()
    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario do
            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - vector3(
                config.shipCenterCoords.x,
                config.shipCenterCoords.y,
                config.shipCenterCoords.z))
            if distance < SPAWN_DISTANCE then
                break
            end
            Citizen.Wait(1000)
        end

        if isTeamLeader() then
            spawnHelicopter()
            spawnGuards()
            spawnBigContainers()
        end

        -- Spawn ladders for all players
        spawnLadders()
        setupHeliKeyPickup()
        setupLootables()
        spawnTargetObjects()
    end)
end

local function spawnBoat()
    if not isTeamLeader() then return end

    local boatCoords = config.boatSpawn.coords

    addBlip(boatCoords, SHARED_CONFIG.blips.boat, true, false, "boat")

    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario do
            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - vector3(boatCoords.x, boatCoords.y, boatCoords.z))
            if distance < SPAWN_DISTANCE then
                break
            end
            Citizen.Wait(1000)
        end

        local spawnCount = ClientApplication.state.lobby and
            #ClientApplication.state.lobby.members > 4 and 2 or 1

        for _ = 1, spawnCount do
            local boatModel = config.boatSpawn.model
            local boatCoords = config.boatSpawn.coords

            lib.requestModel(boatModel)
            local boatEntity = CreateVehicle(boatModel,
                boatCoords.x, boatCoords.y, boatCoords.z, boatCoords.w or 0.0,
                true, true)
            while not DoesEntityExist(boatEntity) do Citizen.Wait(100) end

            local boatNetId = Utils.waitFor(function()
                if not NetworkGetEntityIsNetworked(boatEntity) then
                    NetworkRegisterEntityAsNetworked(boatEntity)
                else
                    local netId = VehToNet(boatEntity)
                    if NetworkDoesNetworkIdExist(netId) then
                        return netId
                    end
                end
            end, 3000)

            local offset = -5 * (_ - 1)

            SetEntityCoords(boatEntity,
                boatCoords.x + offset, boatCoords.y + offset, boatCoords.z,
                false, false, false, false)
            SetEntityRotation(boatEntity, 0.0, 0.0, boatCoords.w or 0.0, 2, false)
            SetModelAsNoLongerNeeded(boatModel)

            TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:onBoatSpawned"), {
                lobbyId = ClientApplication.state.lobby.id,
                boatNetId = boatNetId,
            })
            Citizen.Wait(500)
        end
    end)
end

local function attachContainerToHelicopter()
    TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:attachContainerToHelicopter"), {
        lobbyId = ClientApplication.state.lobby.id,
    })
end

local function detachContainerFromHelicopter()
    TriggerServerEvent(_e("server:scenarios:cargo_ship_robbery:detachContainerFromHelicopter"), {
        lobbyId = ClientApplication.state.lobby.id,
    })
end

local function usingHeliThread()
    if state.helicopterUsingThread then return end

    state.helicopterUsingThread = true

    Citizen.CreateThread(function()
        local outlineDrawn = {}
        local textui = false
        local attachedContainerIndex = nil

        while ClientApplication.state.activeScenario and
            state.helicopterUsingThread
        do
            local wait = 1000
            if ClientApplication.state.activeScenario.game.isHeliKeyTaken and
                state.helicopterNetId and
                cache.vehicle
            then
                local vehicle = cache.vehicle
                if NetworkDoesEntityExistWithNetworkId(state.helicopterNetId) then
                    local helicopterEntity = NetToVeh(state.helicopterNetId)
                    if DoesEntityExist(helicopterEntity) and vehicle == helicopterEntity then
                        local helicopterCoords = GetEntityCoords(helicopterEntity)

                        -- Şu anda bir container takılı mı kontrol et
                        local hasAttachedContainer = false
                        for i, containerData in pairs(state.bigContainers) do
                            if not containerData.delivered and NetworkDoesEntityExistWithNetworkId(containerData.netId) then
                                local containerEntity = NetToObj(containerData.netId)
                                if DoesEntityExist(containerEntity) and IsEntityAttached(containerEntity) then
                                    hasAttachedContainer = true
                                    attachedContainerIndex = i

                                    -- Hedef koordinata yakın mı kontrol et
                                    local targetCoords = containerData.targetCoords
                                    local distance = #(helicopterCoords - vector3(targetCoords.x, targetCoords.y, targetCoords.z))

                                    if distance < 100.0 then -- 100 birim yakınlık
                                        wait = 0
                                        if not textui then
                                            textui = true
                                            Utils.showTextUI(locale("cargo_ship_robbery.detach_container"), "E")
                                        end

                                        if IsControlJustPressed(0, 38) then
                                            Utils.hideTextUI()
                                            textui = false

                                            TriggerServerEvent(
                                                _e("server:scenarios:cargo_ship_robbery:detachBigContainer"), {
                                                    lobbyId = ClientApplication.state.lobby.id,
                                                    containerIndex = i,
                                                })

                                            attachedContainerIndex = nil
                                            Citizen.Wait(1000)
                                        end
                                    else
                                        if textui then
                                            textui = false
                                            Utils.hideTextUI()
                                        end
                                    end
                                    break
                                end
                            end
                        end

                        -- Eğer container takılı değilse, sıradaki container"ı bul
                        if not hasAttachedContainer then
                            local currentContainer = state.bigContainers[state.currentContainerIndex]
                            if currentContainer and not currentContainer.delivered and
                                NetworkDoesEntityExistWithNetworkId(currentContainer.netId) then
                                local containerEntity = NetToObj(currentContainer.netId)
                                if DoesEntityExist(containerEntity) then
                                    if not outlineDrawn[containerEntity] then
                                        outlineDrawn[containerEntity] = true
                                        SetEntityDrawOutline(containerEntity, true)
                                    end

                                    local distance = #(helicopterCoords - GetEntityCoords(containerEntity))
                                    if distance < 10.0 then
                                        wait = 0

                                        if not textui then
                                            textui = true
                                            Utils.showTextUI(locale("cargo_ship_robbery.attach_container"), "E")
                                        end

                                        if IsControlJustPressed(0, 38) then
                                            Utils.hideTextUI()
                                            textui = false

                                            SetEntityDrawOutline(containerEntity, false)
                                            outlineDrawn[containerEntity] = false

                                            TriggerServerEvent(
                                                _e("server:scenarios:cargo_ship_robbery:attachBigContainer"), {
                                                    lobbyId = ClientApplication.state.lobby.id,
                                                    containerIndex = state.currentContainerIndex,
                                                })

                                            Citizen.Wait(1000)
                                        end
                                    else
                                        if textui then
                                            textui = false
                                            Utils.hideTextUI()
                                        end
                                    end
                                end
                            else
                                -- Tüm containerlar teslim edildi, helikopterden in
                                local allDelivered = true
                                for _, containerData in pairs(state.bigContainers) do
                                    if not containerData.delivered then
                                        allDelivered = false
                                        break
                                    end
                                end

                                if allDelivered then
                                    wait = 0
                                    if not textui then
                                        textui = true
                                        Utils.showTextUI(locale("cargo_ship_robbery.exit_helicopter"), "F")
                                    end

                                    if IsControlJustPressed(0, 23) then -- F tuşu
                                        Utils.hideTextUI()
                                        textui = false
                                        TaskLeaveVehicle(cache.ped, helicopterEntity, 0)

                                        -- Görev tamamlandı
                                        if isTeamLeader() then
                                            HeistClient.completeScenario()
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

function CargoShipRobberyClient.init()
    -- Add ship blip
    addRadiusBlip(config.shipCenterCoords, 150.0, 5, "ship_area")
    addBlip(config.shipCenterCoords, SHARED_CONFIG.blips.ship, true, true, "ship")

    spawnBoat()
    spawnShipInside()
    usingHeliThread()

    Utils.notify(locale("cargo_ship_robbery.boat_location_marked"), "info")
end

function CargoShipRobberyClient.clear()
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

    if state.helicopterKeyObjectId and DoesEntityExist(state.helicopterKeyObjectId) then
        DeleteObject(state.helicopterKeyObjectId)
    end

    -- Clean up ladders
    for _, ladderEntity in pairs(state.ladders) do
        if DoesEntityExist(ladderEntity) then
            DeleteObject(ladderEntity)
        end
    end

    -- Clean up target objects
    for _, targetObject in pairs(state.targetObjects) do
        if DoesEntityExist(targetObject) then
            DeleteObject(targetObject)
        end
    end

    __init_state__()
end

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onBoatSpawned"), function(params)
    local boatNetId = params.boatNetId
    if not boatNetId then return end
    local lobbyId = params.lobbyId
    if not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= lobbyId
    then
        return
    end

    Citizen.CreateThread(function()
        local entity = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(boatNetId) then
                local entity = NetToVeh(boatNetId)
                if DoesEntityExist(entity) then return entity end
            end
        end, nil, false)

        HeistClient.giveVehicleKey(GetVehicleNumberPlateText(entity), entity)

        removeBlipByKey("boat")
    end)
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onGuardsSpawned"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if not managers.guards then
        managers.guards = GuardManagerClient.new({ guards = config.guards })
    end

    HeistClient.updateActiveInfoIndex(3)
    managers.guards:syncGuardsFromNetIds(params.guardNetIds)
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onHelicopterSpawned"), function(params)
    local lobbyId = params.lobbyId
    local helicopterNetId = params.helicopterNetId

    if not helicopterNetId or
        not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= lobbyId
    then
        return
    end

    state.helicopterNetId = helicopterNetId

    Citizen.CreateThread(function()
        local helicopterNetId = state.helicopterNetId
        while ClientApplication.state.activeScenario and
            not ClientApplication.state.activeScenario.game.isHeliKeyTaken
        do
            if NetworkDoesEntityExistWithNetworkId(helicopterNetId) then
                local entity = NetToVeh(helicopterNetId)
                if DoesEntityExist(entity) then
                    SetVehicleDoorsLocked(entity, 2)
                    SetVehicleDoorsLockedForAllPlayers(entity, true)
                end
            end

            Citizen.Wait(1000)
        end
        local helicopterNetId = state.helicopterNetId
        if NetworkDoesEntityExistWithNetworkId(helicopterNetId) then
            local entity = NetToVeh(helicopterNetId)
            if DoesEntityExist(entity) then
                SetVehicleDoorsLockedForAllPlayers(entity, false)
                SetVehicleDoorsLocked(entity, 1)
            end
        end
    end)
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onHeliKeyPickedUp"), function(params)
    local lobbyId = params.lobbyId

    if not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= lobbyId
    then
        return
    end

    state.helicopterKeyPickUpThread = false
    if state.helicopterKeyObjectId and DoesEntityExist(state.helicopterKeyObjectId) then
        DeleteObject(state.helicopterKeyObjectId)
        state.helicopterKeyObjectId = nil
    end
    ClientApplication.state.activeScenario.game.isHeliKeyTaken = true

    HeistClient.updateActiveInfoIndex(6)

    Citizen.CreateThread(function()
        local helicopterNetId = state.helicopterNetId
        while ClientApplication.state.activeScenario do
            local wait = 500
            if NetworkDoesEntityExistWithNetworkId(helicopterNetId) then
                local entity = NetToVeh(helicopterNetId)
                if DoesEntityExist(entity) then
                    SetVehicleDoorsLockedForAllPlayers(entity, false)
                    SetVehicleDoorsLocked(entity, 1)
                    HeistClient.giveVehicleKey(GetVehicleNumberPlateText(entity), entity)
                    break
                end
            end

            Citizen.Wait(wait)
        end
    end)
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onLootUpdated"), function(params)
    if not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= params.lobbyId
    then
        return
    end

    if managers.loot then
        managers.loot:markLootLooted(params.lootIndex, false)
    end
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onBigContainerSpawned"), function(params)
    if not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= params.lobbyId
    then
        return
    end

    local containerIndex = params.containerIndex
    local containerNetId = params.containerNetId
    local targetCoords = params.targetCoords

    if not state.bigContainers[containerIndex] then
        state.bigContainers[containerIndex] = {}
    end

    state.bigContainers[containerIndex].netId = containerNetId
    state.bigContainers[containerIndex].targetCoords = targetCoords
    state.bigContainers[containerIndex].delivered = false
end)

lib.callback.register(_e("client:scenarios:cargo_ship_robbery:attachBigContainerToHelicopter"), function(params)
    local helicopterNetId = params.helicopterNetId
    local containerIndex = params.containerIndex

    local helicopterEntity = Utils.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(helicopterNetId) then
            local entity = NetToVeh(helicopterNetId)
            if DoesEntityExist(entity) then return entity end
        end
    end, 3000)
    if not helicopterEntity then
        return nil
    end

    local containerConfig = config.bigContainers[containerIndex]
    if not containerConfig then return nil end

    local newContainer = Utils.createObject({
        model = containerConfig.model,
        coords = containerConfig.coords,
        freeze = false,
        isNetwork = true,
    })

    local newContainerNetId = Utils.waitFor(function()
        if not NetworkGetEntityIsNetworked(newContainer) then
            NetworkRegisterEntityAsNetworked(newContainer)
        else
            local netId = ObjToNet(newContainer)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, 3000)
    if not newContainerNetId then
        return nil
    end

    AttachEntityToEntity(newContainer, helicopterEntity,
        0, 0.0, -5.0, -2.5,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true)

    return newContainerNetId
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:detachBigContainerFromHelicopter"), function(params)
    local containerNetId = params.containerNetId
    local containerIndex = params.containerIndex
    if not containerNetId then
        return
    end

    local containerEntity = Utils.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(containerNetId) then
            local entity = NetToObj(containerNetId)
            if DoesEntityExist(entity) then return entity end
        end
    end, 3000)

    if not containerEntity then
        return
    end

    DetachEntity(containerEntity, true, true)
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onBigContainerAttached"), function(params)
    local containerIndex = params.containerIndex

    HeistClient.updateActiveInfoIndex(7)

    -- Mevcut container için hedef blip"i ekle
    local currentContainer = state.bigContainers[containerIndex]
    currentContainer.netId = params.containerNetId

    if currentContainer then
        addBlip(currentContainer.targetCoords, SHARED_CONFIG.blips.container, true, true, "container_" .. containerIndex)
    end
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onBigContainerDetached"), function(params)
    local lobbyId = params.lobbyId
    local containerIndex = params.containerIndex

    if not ClientApplication.state.lobby or
        ClientApplication.state.lobby.id ~= lobbyId
    then
        return
    end

    -- Bu container"ı teslim edilmiş olarak işaretle
    if state.bigContainers[containerIndex] then
        state.bigContainers[containerIndex].delivered = true
    end

    -- Container blip"ini kaldır
    removeBlipByKey("container_" .. containerIndex)

    -- Sıradaki container"a geç
    state.currentContainerIndex = state.currentContainerIndex + 1

    -- Tüm containerlar teslim edildi mi kontrol et
    local allDelivered = true
    for _, containerData in pairs(state.bigContainers) do
        if not containerData.delivered then
            allDelivered = false
            break
        end
    end

    if not allDelivered then
        HeistClient.updateActiveInfoIndex(6) -- Bir sonraki container için

        Utils.notify(locale("cargo_ship_robbery.go_to_next_container"), "success")

        -- Sıradaki container için blip ekle
        local nextContainer = state.bigContainers[state.currentContainerIndex]
        if nextContainer then
            SetNewWaypoint(
                config.bigContainers[state.currentContainerIndex].coords.x,
                config.bigContainers[state.currentContainerIndex].coords.y
            )
        end
    else
        HeistClient.updateActiveInfoIndex(8) -- Görev tamamlandı
    end

    local targetObject = state.targetObjects[containerIndex]
    if targetObject and DoesEntityExist(targetObject) then
        DeleteObject(targetObject)
        state.targetObjects[containerIndex] = nil
    end
end)

RegisterNetEvent(_e("client:scenarios:cargo_ship_robbery:onAnchorUsed"), function()
    local playerPed = cache.ped
    local coords = GetEntityCoords(playerPed)
    local vehicle = lib.getClosestVehicle(coords, 5.0, true)
    if not vehicle then return end
    local vehicleClass = GetVehicleClass(vehicle)
    if vehicleClass ~= 14 then return end

    local boatState = Entity(vehicle).state.anchored or false
    local newState = not boatState
    SetBoatAnchor(vehicle, newState)
    Entity(vehicle).state.anchored = newState

    Utils.notify(locale(newState and "cargo_ship_robbery.anchored" or "cargo_ship_robbery.unanchored"), "inform")
    lib.playAnim(playerPed, "pickup_object", "pickup_low")
end)
