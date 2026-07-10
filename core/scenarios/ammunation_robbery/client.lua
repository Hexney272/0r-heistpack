local lib                      = lib
local Utils                    = require("modules.utils.client")
local GuardManagerClient       = require("core.scenarios._shared.client.guards")

local config                   = lib.load("config.scenarios.ammunation_robbery")
local SHARED_CONFIG <const>    = lib.load("config.scenarios._shared")

local OPEN_CONTAINER_ANIMATION = {
    dict = "anim@scripted@player@mission@tunf_train_ig1_container_p1@male@"
}

AmmunationRobberyClient        = {}

-- State management
local state                    = {
    isBusy = false,
    blips = {},
    realLocationIndex = nil,
    fakeLocationIndexes = {},
    filledContainers = {},
    openedContainers = {},
    containerSceneObjects = {},
    fakeContainers = {},
    distanceForFinishWorking = false,
}

-- Manager instances
local managers                 = {
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
    Utils.triggerPoliceAlert("ammunation_robbery", locale("ammunation_robbery.police_alert"), coords)
end

local function removeBlipByKey(key)
    if not state.blips[key] then return end
    if DoesBlipExist(state.blips[key]) then
        RemoveBlip(state.blips[key])
    end
    state.blips[key] = nil
end

local function addBlip(coords, options, route, longRange, key)
    removeBlipByKey(key)
    local blip = Utils.addBlip(coords, options, route)
    SetBlipAsShortRange(blip, not longRange)
    state.blips[key] = blip
end

local function addRadiusBlip(coords, radius, key)
    local radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(radiusBlip, 1)
    SetBlipAlpha(radiusBlip, 128)
    state.blips[key] = radiusBlip
end

---@section GUARD MANAGEMENT

local function spawnGuards()
    if managers.guards and managers.guards:areGuardsSpawned() then return end
    if not state.realLocationIndex then return end

    local location = config.locations[state.realLocationIndex]
    if not location or not location.guards then return end

    -- Initialize guard manager
    managers.guards = GuardManagerClient.new({
        guards = location.guards,
        onGuardsSpawned = function(guardNetIds)
            TriggerServerEvent(_e("server:scenarios:ammunation_robbery:onGuardsSpawned"), {
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

---@section LOCATION & BLIP SETUP

local function setupLocationBlips()
    if not state.realLocationIndex then return end

    local realLocation = config.locations[state.realLocationIndex]

    -- Add blip for real location
    addBlip(realLocation.centerCoords, SHARED_CONFIG.blips.container,
        false, true, "location_" .. state.realLocationIndex)
    addRadiusBlip(realLocation.centerCoords, 75.0, "real_radius")

    -- Add blips for fake locations
    for i, fakeIndex in ipairs(state.fakeLocationIndexes) do
        local fakeLocation = config.locations[fakeIndex]
        if fakeLocation then
            addBlip(fakeLocation.centerCoords, SHARED_CONFIG.blips.container,
                false, true, "location_" .. fakeIndex)
            addRadiusBlip(fakeLocation.centerCoords, 75.0, "fake_radius_" .. i)
        end
    end
end

---@section CRATE MANAGEMENT

local function spawnCrateInContainer(container, containerIndex)
    local crateObject = Utils.createObject({
        model = SHARED_CONFIG.models.cratesWeapon,
        coords = container.coords,
        freeze = false,
        isNetwork = true,
        rotation = (container.coords.w or 0.0) - 90.0,
    })
    PlaceObjectOnGroundProperly(crateObject)

    local crateNetId = Utils.waitFor(function()
        if not NetworkGetEntityIsNetworked(crateObject) then
            NetworkRegisterEntityAsNetworked(crateObject)
        else
            local netId = ObjToNet(crateObject)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, 3000)

    TriggerServerEvent(_e("server:scenarios:ammunation_robbery:onCrateSpawned"), {
        lobbyId = ClientApplication.state.lobby.id,
        containerIndex = containerIndex,
        crateNetId = crateNetId,
    })
end

---@section CONTAINER INTERACTION

local function openContainerAnimation(containerIndex)
    local isOpened = lib.callback.await(_e("server:scenarios:ammunation_robbery:isContainerOpened"), false, {
        lobbyId = ClientApplication.state.lobby.id,
        containerIndex = containerIndex,
    })
    if isOpened then
        Utils.notify(locale("ammunation_robbery.container_already_opened"), "error", 5000)
        return
    end

    local containerConfig = config.locations[state.realLocationIndex].containers[containerIndex]
    if not containerConfig then return end

    local requiredItem = config.requiredGrinderItem or {}
    local hasRequiredItem = lib.callback.await(_e("server:hasItem"), false, requiredItem.itemName, 1)
    if not hasRequiredItem then
        Utils.notify(locale("ammunation_robbery.item_required", requiredItem.label), "error", 3000)
        return
    end

    TriggerServerEvent(_e("server:scenarios:ammunation_robbery:setContainerOpening"), {
        lobbyId = ClientApplication.state.lobby.id,
        containerIndex = containerIndex,
    })

    if state.filledContainers[containerIndex] then
        spawnCrateInContainer(containerConfig, containerIndex)
    end

    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)

    local animDict = OPEN_CONTAINER_ANIMATION.dict
    local ptfxAsset = "scr_tn_tr"

    lib.requestAnimDict(animDict)
    lib.requestNamedPtfxAsset(ptfxAsset)

    local sceneObjects = { "tr_prop_tr_grinder_01a", "ch_p_m_bag_var02_arm_s" }
    local sceneNames = { "action", "action_container", "action_lock", "action_angle_grinder", "action_bag" }
    local particleEffectName = "scr_tn_tr_angle_grinder_sparks"

    for i = 1, #sceneObjects do
        local model = sceneObjects[i]
        lib.requestModel(model)
        local object = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
        table.insert(state.containerSceneObjects, object)
        SetModelAsNoLongerNeeded(model)
    end

    local sceneObject = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z,
        2.5, containerConfig.model, false, false, false)
    NetworkRegisterEntityAsNetworked(sceneObject)

    local sceneObjectCoords = GetEntityCoords(sceneObject)
    local sceneObjectRotation = GetEntityRotation(sceneObject)

    local scene = NetworkCreateSynchronisedScene(sceneObjectCoords.x, sceneObjectCoords.y, sceneObjectCoords.z,
        sceneObjectRotation.x, sceneObjectRotation.y, sceneObjectRotation.z,
        2, true, false, -1, 0, 1.0)

    NetworkAddPedToSynchronisedScene(playerPed, scene,
        animDict, sceneNames[1],
        1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(sceneObject, scene,
        animDict, sceneNames[2],
        1.5, -4.0, 1)
    NetworkAddEntityToSynchronisedScene(state.containerSceneObjects[1], scene,
        animDict, sceneNames[4],
        1.5, -4.0, 1)
    NetworkAddEntityToSynchronisedScene(state.containerSceneObjects[2], scene,
        animDict, sceneNames[5],
        1.5, -4.0, 1)

    SetEntityCoords(playerPed, sceneObjectCoords.x, sceneObjectCoords.y, sceneObjectCoords.z)
    NetworkStartSynchronisedScene(scene)

    Citizen.Wait(4000)

    UseParticleFxAssetNextCall(ptfxAsset)
    local sparks = StartParticleFxLoopedOnEntity(particleEffectName, state.containerSceneObjects[1],
        0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 1.0,
        false, false, false, 1065353216, 1065353216, 1065353216, 1)
    Citizen.Wait(1000)
    StopParticleFxLooped(sparks, 1)

    local duration = (GetAnimDuration(animDict, "action") * 1000 - 6000)
    Utils.progressBar({
        duration = duration,
        label = locale("ammunation_robbery.opening_container"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
        }
    })

    TriggerServerEvent(_e("server:scenarios:ammunation_robbery:onContainerOpened"), {
        lobbyId = ClientApplication.state.lobby.id,
        containerIndex = containerIndex,
    })

    ClearPedTasks(playerPed)
    RemoveAnimDict(animDict)
    RemoveNamedPtfxAsset(ptfxAsset)
    for _, v in pairs(state.containerSceneObjects) do DeleteEntity(v) end
    state.containerSceneObjects = {}
end

local function spawnContainerObjects(location)
    local containerObjectNetIds = {}

    for containerIndex, container in ipairs(location.containers) do
        local containerObject = Utils.createObject({
            model = container.model,
            coords = vec3(container.coords.x, container.coords.y, container.coords.z),
            freeze = true,
            isNetwork = true,
            rotation = container.coords.w or 0.0,
        })
        local netId = Utils.waitFor(function()
            if not NetworkGetEntityIsNetworked(containerObject) then
                NetworkRegisterEntityAsNetworked(containerObject)
            else
                local netId = ObjToNet(containerObject)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, 3000)
        table.insert(containerObjectNetIds, netId)
    end

    TriggerServerEvent(_e("server:scenarios:ammunation_robbery:onContainerObjectsSpawned"), {
        lobbyId = ClientApplication.state.lobby.id,
        containerObjectNetIds = containerObjectNetIds,
    })
end
local function setupContainerSpawn()
    if not state.realLocationIndex then return end
    if ClientApplication.state.lobby.owner ~= cache.serverId then return end

    local location = config.locations[state.realLocationIndex]

    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario do
            Citizen.Wait(500)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            -- Check distance to real location center
            local distanceFromCenter = #(playerCoords - location.centerCoords)

            if distanceFromCenter < 190.0 then
                triggerAlert(location.centerCoords)
                spawnGuards()
                spawnContainerObjects(location)
                break
            end
        end
    end)
end

local function lootContainerAnimation(containerIndex)
    local playerPed = cache.ped
    local animDict = SHARED_CONFIG.animations.grabCash.dict
    local animName = SHARED_CONFIG.animations.grabCash.name
    local duration = SHARED_CONFIG.animations.grabCash.duration

    lib.requestAnimDict(animDict)
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, duration, 0, 0, false, false, false)
    Utils.progressBar({
        duration = duration,
        label = locale("ammunation_robbery.looting_container"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
        }
    })

    TriggerServerEvent(_e("server:scenarios:ammunation_robbery:lootContainer"), {
        lobbyId = ClientApplication.state.lobby.id,
        containerIndex = containerIndex,
    })

    ClearPedTasks(playerPed)
    RemoveAnimDict(animDict)
end

local function setupContainerInteraction()
    if not state.realLocationIndex then return end

    local location = config.locations[state.realLocationIndex]

    Citizen.CreateThread(function()
        local textui = false
        local lastTextuiText = nil
        local currentClosestContainer = nil

        while ClientApplication.state.activeScenario do
            local wait = 500
            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            -- Find closest container
            local closestContainer = nil
            local closestDistance = math.huge
            local closestIndex = nil

            for containerIndex, container in ipairs(location.containers) do
                if not state.isBusy then
                    local containerObject = GetClosestObjectOfType(
                        container.coords.x, container.coords.y, container.coords.z,
                        2.5,
                        container.model,
                        false, false, false
                    )
                    if containerObject and DoesEntityExist(containerObject) then
                        local containerOffset = GetOffsetFromEntityInWorldCoords(
                            containerObject,
                            0.0, -1.5, 0.0
                        )
                        local distanceFromContainer = #(playerCoords - containerOffset)

                        if distanceFromContainer < 2.0 and distanceFromContainer < closestDistance then
                            closestDistance = distanceFromContainer
                            closestContainer = containerObject
                            closestIndex = containerIndex
                        end
                    end
                end
            end

            -- Handle closest container interaction
            if closestContainer and closestIndex then
                wait = 0
                currentClosestContainer = closestIndex

                local isOpened = state.openedContainers[closestIndex]
                local isFilled = state.filledContainers[closestIndex]

                local promptText = nil
                if not isOpened then
                    promptText = locale("ammunation_robbery.open_container")
                elseif isOpened and isFilled then
                    promptText = locale("ammunation_robbery.loot_container")
                end

                -- Show or update interaction prompt
                if promptText then
                    if not textui or lastTextuiText ~= promptText then
                        Utils.showTextUI(promptText, "E")
                        textui = true
                        lastTextuiText = promptText
                    end
                else
                    if textui then
                        Utils.hideTextUI()
                        textui = false
                        lastTextuiText = nil
                    end
                end

                if IsControlJustPressed(0, 38) then -- E key
                    state.isBusy = true
                    Utils.hideTextUI()
                    textui = false
                    lastTextuiText = nil
                    currentClosestContainer = nil

                    if not isOpened then
                        openContainerAnimation(closestIndex)
                    elseif isOpened and isFilled then
                        lootContainerAnimation(closestIndex)
                    end

                    state.isBusy = false
                end
            else
                -- No close container found, hide textui if it was shown
                if textui then
                    Utils.hideTextUI()
                    textui = false
                    lastTextuiText = nil
                    currentClosestContainer = nil
                end
            end

            Citizen.Wait(wait)
        end

        -- Cleanup textui when thread ends
        if textui then
            Utils.hideTextUI()
        end
    end)
end

---@section CONTAINER VISUAL MANAGEMENT

local function createOpenedContainerVisual(container, animation)
    lib.requestAnimDict(animation.dict)

    local containerObject = Utils.createObject({
        model = container.model,
        coords = vec3(container.coords.x, container.coords.y, container.coords.z),
        freeze = true,
        isNetwork = false,
        rotation = container.coords.w or 0.0,
    })
    SetEntityVisible(containerObject, false, false)

    -- Create and play synchronized animation scene
    local syncedScene = CreateSynchronizedScene(
        container.coords.x, container.coords.y, container.coords.z,
        0.0, 0.0, container.coords.w or 0.0, 2)

    PlaySynchronizedEntityAnim(containerObject, syncedScene,
        "action_container", animation.dict,
        1.0, -1.0, 0, 1148846080)

    ForceEntityAiAndAnimationUpdate(containerObject)
    SetSynchronizedScenePhase(syncedScene, 0.99)
    SetEntityCollision(containerObject, false, true)
    FreezeEntityPosition(containerObject, true)
    SetEntityVisible(containerObject, true)

    RemoveAnimDict(animation.dict)

    return containerObject
end

local function createFakeContainer(container)
    local fakeContainer = Utils.createObject({
        model = SHARED_CONFIG.models.fakeContainer,
        coords = vec3(container.coords.x, container.coords.y, container.coords.z + 1.0),
        freeze = true,
        isNetwork = false,
        rotation = container.coords.w or 0.0,
    })
    SetEntityVisible(fakeContainer, false, false)
    return fakeContainer
end

local function distanceCheckingForFinishThread()
    if state.distanceForFinishWorking then return end
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    state.distanceForFinishWorking = true

    Citizen.CreateThread(function()
        local location = config.locations[state.realLocationIndex]
        local finishRadius = 250.0

        while ClientApplication.state.activeScenario do
            Citizen.Wait(1000)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            local distanceFromCenter = #(playerCoords - location.centerCoords)

            if distanceFromCenter > finishRadius then
                HeistClient.completeScenario()
                return
            end
        end
    end)
end

---@section PUBLIC FUNCTIONS

function AmmunationRobberyClient.clear()
    for key, _ in pairs(state.blips) do
        removeBlipByKey(key)
    end

    if managers.guards then
        managers.guards:clear()
    end

    if state.containerSceneObjects then
        for _, obj in ipairs(state.containerSceneObjects) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
    end

    if state.fakeContainers then
        for _, containers in pairs(state.fakeContainers) do
            for _, containerPair in pairs(containers) do
                if containerPair.visible and DoesEntityExist(containerPair.visible) then
                    DeleteEntity(containerPair.visible)
                end
                if containerPair.hidden and DoesEntityExist(containerPair.hidden) then
                    DeleteEntity(containerPair.hidden)
                end
            end
        end
    end

    __init_state__()
end

function AmmunationRobberyClient.init()
    state.realLocationIndex = ClientApplication.state.activeScenario.game.realLocationIndex
    state.fakeLocationIndexes = ClientApplication.state.activeScenario.game.fakeLocationIndexes
    state.filledContainers = ClientApplication.state.activeScenario.game.filledContainers

    setupLocationBlips()
    setupContainerSpawn()
    setupContainerInteraction()

    Utils.notify(locale("ammunation_robbery.locations_marked"), "info", 5000)
end

---@section EVENT HANDLERS

RegisterNetEvent(_e("client:scenarios:ammunation_robbery:onGuardsSpawned"), function(params)
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

    HeistClient.updateActiveInfoIndex(2)
    managers.guards:syncGuardsFromNetIds(params.guardNetIds)
end)

RegisterNetEvent(_e("client:scenarios:ammunation_robbery:onContainerLooted"), function(params)
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    if params.success then
        Utils.notify(locale("ammunation_robbery.container_has_loot"), "success", 5000)
        if params.allLooted then
            HeistClient.updateActiveInfoIndex(3)
            distanceCheckingForFinishThread()
        end
    else
        Utils.notify(locale("ammunation_robbery.container_empty"), "error", 5000)
    end
end)

RegisterNetEvent(_e("client:scenarios:ammunation_robbery:onContainerOpened"), function(params)
    -- Update local state if this is our lobby
    if ClientApplication.state.lobby and ClientApplication.state.lobby.id == params.lobbyId then
        state.openedContainers[params.containerIndex] = params.opened
    end

    -- Get location and container data
    local location = config.locations[params.locationIndex]
    local container = location.containers[params.containerIndex]

    -- Load animation resources
    local animation = OPEN_CONTAINER_ANIMATION
    -- Create opened container visual
    local visibleContainer = createOpenedContainerVisual(container, animation)
    -- Create fake container (hidden)
    local hiddenContainer = createFakeContainer(container)

    if not state.fakeContainers[params.lobbyId] then
        state.fakeContainers[params.lobbyId] = {}
    end

    state.fakeContainers[params.lobbyId][params.containerIndex] = {
        visible = visibleContainer,
        hidden = hiddenContainer
    }
end)
