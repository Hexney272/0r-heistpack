local lib           = lib
local Utils         = require("modules.utils.client")
local Target        = require("modules.target.client")

local config        = lib.load("config.scenarios.atm_robbery")
local SHARED_CONFIG = lib.load("config.scenarios._shared")

local state         = {
    isBusy             = false,
    zones              = {},
    cashPileProp       = nil,
    attachedHook       = nil,
    hookThread         = nil,
    fakeAtmObjectNetId = nil,
}

local lobbyRopes    = {}

local function __init_state__()
    for k in pairs(state) do
        if type(state[k]) == "table" then
            state[k] = {}
        else
            state[k] = false
        end
    end
end

AtmRobberyClient = {}

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("atm_robbery", locale("atm_robbery.police_alert"), coords)
end

local function distanceCheckingForFinishThread(centerCoords)
    Citizen.CreateThread(function()
        local centerCoords = centerCoords or GetEntityCoords(cache.ped)
        local maxDistance = config.requiredDistanceForFinish or 100.0

        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(centerCoords))
            if distance > maxDistance then
                HeistClient.completeScenario()
                return
            end
            Citizen.Wait(1000)
        end
    end)
end

local function setupAtmInteractions()
    local options = {}
    for _, interactionName in pairs({ "hacking", "rope", "explode", "drill" }) do
        local icon = "fa-solid fa-money-bills"
        if interactionName == "rope" then
            icon = "fa-solid fa-gg"
        elseif interactionName == "explode" then
            icon = "fa-solid fa-bomb"
        elseif interactionName == "drill" then
            icon = "fa-solid fa-bore-hole"
        end

        local option = {
            label = locale("atm_robbery.interact_with_atm", locale("atm_robbery.interaction_key." .. interactionName)),
            icon = icon,
            distance = 2.0,
            canInteract = function()
                return not state.isBusy and
                    ClientApplication.state.activeScenario and
                    (ClientApplication.state.activeScenario.game.robbery and
                        not ClientApplication.state.activeScenario.game.robbery.completed)
            end,
            onSelect = function(data)
                local entity = type(data) == "table" and data.entity or data
                local model = GetEntityModel(entity)

                if interactionName == "hacking" then
                    AtmRobberyClient.startHackingAtm(model, entity)
                elseif interactionName == "rope" then
                    AtmRobberyClient.startRopeAtm(model, entity)
                elseif interactionName == "explode" then
                    AtmRobberyClient.startExplodeAtm(model, entity)
                elseif interactionName == "drill" then
                    AtmRobberyClient.startDrillAtm(model, entity)
                end
            end,
        }
        table.insert(options, option)
    end
    Target.addModel(config.atmModels, options)
end

local function targetableScatteredLootProp(atmModel, atmCoords)
    local closestAtmObject = GetClosestObjectOfType(atmCoords.x, atmCoords.y, atmCoords.z, 1.0,
        atmModel, false, false, false)
    if not DoesEntityExist(closestAtmObject) then return end

    local offset = GetOffsetFromEntityInWorldCoords(closestAtmObject, 0.0, -.5, 1.0)
    local rotation = GetEntityRotation(closestAtmObject, 2)
    local model = SHARED_CONFIG.models.cashPileScattered

    local prop = Utils.createObject({
        model = model,
        coords = offset,
        rotation = rotation,
        freeze = true,
        isNetwork = false,
    })
    if not prop then return end

    state.cashPileProp = prop

    for i = 1, 10 do
        if PlaceObjectOnGroundProperly(prop) then break end
        Citizen.Wait(500)
    end

    local zoneName = "scenario:atm_robbery:scattered_loot_zone"
    state.zones["scattered_loot"] = zoneName

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
                local collectOptions = config.collectMoneyOptions

                Target.removeZone(zoneName)
                state.zones["scattered_loot"] = nil

                lib.playAnim(playerPed, collectOptions.animation.dict, collectOptions.animation.name, 8.0, 1.0, -1, 16, 0)

                Utils.progressBar({
                    duration = collectOptions.duration,
                    label = locale("atm_robbery.collecting_money"),
                    useWhileDead = false,
                    canCancel = false,
                    disable = {
                        car = true,
                        move = true,
                        combat = true,
                        sprint = true,
                    },
                })

                ClearPedTasks(playerPed)
                DeleteEntity(prop)
                state.cashPileProp = nil

                local response = lib.callback.await(_e("server:scenarios:atm_robbery:onScatteredLootCollected"),
                    false,
                    {
                        lobbyId = ClientApplication.state.lobby.id,
                        centerCoords = GetEntityCoords(cache.ped)
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

local function setupScatteredLoot(model, coords)
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
                StopParticleFxLooped(particle, false)
            end
        end)

        return true
    end

    local entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, model, false, false, false)
    if not DoesEntityExist(entity) then return end

    sprayEffect(entity)
    Citizen.Wait(8000)
    targetableScatteredLootProp(model, coords)
end

local function cleanup_rope_textures()
    if #GetAllRopes() == 0 then RopeUnloadTextures() end
end

local function deleteAttachedHook()
    if not state.attachedHook then return end

    SetEntityAsMissionEntity(state.attachedHook, true, true)
    DeleteEntity(state.attachedHook)
    state.attachedHook = nil
end

local function attachHookToPedHand()
    deleteAttachedHook()

    local playerPed = cache.ped
    local hookModel = SHARED_CONFIG.models.ropeHook

    local hookObject = Utils.createObject({
        model = hookModel,
        coords = GetEntityCoords(playerPed),
        rotation = vector3(0.0, 0.0, 0.0),
        freeze = false,
        isNetwork = true,
    })
    if not hookObject then return end

    local boneIndex = GetPedBoneIndex(playerPed, 57005)

    AttachEntityToEntity(hookObject, playerPed, boneIndex,
        0.15, 0.0, -0.05,
        120.0, 0.0, 15.0,
        true, false, false, true, 2, true
    )

    state.attachedHook = hookObject
end

local function DoesLobbyPlayerRopeExist(lobbyId, playerId, key)
    if not lobbyRopes[lobbyId] then return false end

    local playerRope = lobbyRopes[lobbyId][playerId] or nil
    if not playerRope then return false end

    if not DoesRopeExist(playerRope.id) then return false end

    if key and playerRope.key ~= key then return false end

    return true
end

local function deleteLobbyRopes(lobbyId)
    if not lobbyRopes[lobbyId] then return end

    for _, rope in pairs(lobbyRopes[lobbyId]) do
        if DoesRopeExist(rope.id) then DeleteRope(rope.id) end
    end

    cleanup_rope_textures()
end

local function addRopeToEntity(lobbyId, owner, key)
    while not RopeAreTexturesLoaded() do
        RopeLoadTextures()
        Citizen.Wait(1)
    end

    local coords = GetEntityCoords(cache.ped)

    local rope = AddRope(
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        1.0,
        4, 7.0, 1.0, 0,
        false, false, false, 0, false
    )

    if not DoesRopeExist(rope) then
        cleanup_rope_textures()
        return false
    end

    lobbyRopes[lobbyId] = lobbyRopes[lobbyId] or {}
    lobbyRopes[lobbyId][owner] = { id = rope, key = key }

    return rope
end

local function nearVehicleBackWithHookThread()
    Citizen.CreateThread(function()
        state.hookThread = true

        local attachedVehicle = nil
        local textUI = false

        while state.hookThread do
            local wait = 500
            if state.fakeAtmObjectNetId then
                local fakeAtmObject = NetToObj(state.fakeAtmObjectNetId)
                if DoesEntityExist(fakeAtmObject) then
                    local playerPed = cache.ped
                    local playerCoords = GetEntityCoords(playerPed)
                    local vehicle = lib.getClosestVehicle(playerCoords, 5.0, false)
                    if vehicle then
                        local backCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)
                        local distance = #(playerCoords - backCoords)
                        if distance < 1.5 then
                            wait = 0
                            if not textUI then
                                Utils.showTextUI(locale("atm_robbery.attach_rope_to_vehicle"), "E")
                                textUI = true
                            end
                            if IsControlJustPressed(0, 38) then
                                Utils.hideTextUI()
                                textUI = false
                                attachedVehicle = vehicle
                                break
                            end
                        elseif textUI then
                            Utils.hideTextUI()
                            textUI = false
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end

        state.hookThread = nil
        state.isBusy = false

        deleteAttachedHook()

        if not attachedVehicle then return end

        TriggerServerEvent(_e("server:scenarios:atm_robbery:attachRopeToVehicle"), {
            lobbyId = ClientApplication.state.lobby.id,
            vehicleNetId = VehToNet(attachedVehicle),
            playerPedNetId = PedToNet(cache.ped),
        })
    end)

    Citizen.CreateThread(function()
        while state.hookThread do
            Citizen.Wait(1)
            local playerPed = cache.ped
            local vehicle = GetVehiclePedIsTryingToEnter(playerPed)

            if vehicle ~= 0 then
                ClearPedTasksImmediately(playerPed)
            end
        end
    end)
end

local function addRobTargetToFakeAtm(fakeAtmObject)
    if not fakeAtmObject then return end
    if not DoesEntityExist(fakeAtmObject) then return end

    Target.addLocalEntity(fakeAtmObject, { {
        label = locale("atm_robbery.collect_scattered_loot"),
        icon = "fa-solid fa-money-bill-1-wave",
        distance = 2.0,
        canInteract = function()
            return not state.isBusy and
                ClientApplication.state.activeScenario and
                ClientApplication.state.activeScenario.game.robbery and
                ClientApplication.state.activeScenario.game.robbery.completed
        end,
        onSelect = function()
            Target.removeLocalEntity(fakeAtmObject)

            local playerPed = cache.ped
            local collectOptions = config.collectMoneyOptions

            lib.playAnim(playerPed, collectOptions.animation.dict, collectOptions.animation.name, 8.0, 1.0, -1, 1, 0)

            Utils.progressBar({
                duration = collectOptions.duration,
                label = locale("atm_robbery.collecting_money"),
                useWhileDead = false,
                canCancel = false,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                    sprint = true,
                },
            })

            ClearPedTasks(playerPed)

            TriggerServerEvent(_e("server:scenarios:atm_robbery:deleteLobbyRope"),
                { lobbyId = ClientApplication.state.lobby.id })

            local response = lib.callback.await(_e("server:scenarios:atm_robbery:onScatteredLootCollected"), false,
                { lobbyId = ClientApplication.state.lobby.id }
            )
            if not response.success then
                if response.message then
                    Utils.notify(response.message, "error")
                end
                return
            end

            if ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId then
                TriggerServerEvent(_e("server:heist:setHeistCompleted"),
                    { lobbyId = ClientApplication.state.lobby.id, reason = "completed" }
                )
            end
            HeistClient.updateActiveInfoIndex(5)
        end
    } })
end

function AtmRobberyClient.startExplodeAtm(model, entity)
    local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(entity))
    if distance > 2.0 then
        Utils.notify(locale("atm_robbery.too_far_from_atm"), "error", 3000)
        return
    end

    local requiredItem = config.explodeOptions.requiredItem or {}
    local hasRequiredItem = lib.callback.await(_e("server:hasItem"), false, requiredItem.itemName, 1)
    if not hasRequiredItem then
        Utils.notify(locale("atm_robbery.item_required", requiredItem.label), "error", 3000)
        return
    end

    Citizen.Wait(1000)
    if config.explodeOptions.addSkillCheck then
        if not Utils.skillCheck({ "easy", "easy", "medium" }) then
            return
        end
    end

    local isAtmAvailable = lib.callback.await(_e("server:scenarios:atm_robbery:isAtmAvailable"), false,
        { lobbyId = ClientApplication.state.lobby.id }
    )
    if not isAtmAvailable then
        Utils.notify(locale("atm_robbery.atm_not_available"), "error", 3000)
        return
    end

    state.isBusy = true

    local modelPlantingOffset = config.explodeOptions.modelPlantingOffsets[model] or vector3(0.0, 0.0, 1.0)
    local animation = config.explodeOptions.animation
    local atmCoords = GetEntityCoords(entity)
    local atmRot = GetEntityRotation(entity)

    triggerAlert(atmCoords)

    TaskTurnPedToFaceCoord(cache.ped, atmCoords.x, atmCoords.y, atmCoords.z, 4000)
    Citizen.Wait(500)

    lib.requestAnimDict(animation.dict)

    local sceneCoord = GetOffsetFromEntityInWorldCoords(entity,
        modelPlantingOffset.x, modelPlantingOffset.y, modelPlantingOffset.z)
    local sceneRot = atmRot
    local playerPedId = cache.ped

    local plantScene = NetworkCreateSynchronisedScene(sceneCoord.x, sceneCoord.y, sceneCoord.z,
        sceneRot.x, sceneRot.y, sceneRot.z, 2,
        false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPedId,
        plantScene, animation.dict,
        animation.name,
        1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkStartSynchronisedScene(plantScene)

    Citizen.Wait(1500)

    local plantedBombProp = Utils.createObject({
        model = "prop_bomb_01",
        coords = sceneCoord,
        rotation = sceneRot,
        freeze = true,
        isNetwork = true,
    })
    if plantedBombProp then
        SetEntityCollision(plantedBombProp, false, true)
        AttachEntityToEntity(plantedBombProp, playerPedId,
            GetPedBoneIndex(playerPedId, 28422),
            0.0, 0.0, 0.0, 0.0, 0.0, 200.0,
            true, true, false, true, 1, true)
        Citizen.Wait(2500)
    end

    local bombCoords, bombRot = nil, nil
    if plantedBombProp then
        bombCoords = GetEntityCoords(plantedBombProp)
        bombRot    = GetEntityRotation(plantedBombProp)
        DeleteEntity(plantedBombProp)
        ClearPedTasks(cache.ped)
        RemoveAnimDict(animation.dict)
    end

    lib.callback.await(_e("server:removeItem"), false, requiredItem.itemName, 1)

    local response = lib.callback.await(_e("server:scenarios:atm_robbery:onBombPlanted"), false,
        {
            lobbyId = ClientApplication.state.lobby.id,
            bombCoords = bombCoords,
            bombRot = bombRot,
            atm = {
                model = model,
                coords = atmCoords,
                rotation = atmRot,
                interactionName = "explode",
            }
        }
    )

    if not response.success then
        Utils.notify(locale("atm_robbery.bomb_planting_failed"), "error")
        if response.message then
            Utils.notify(response.message, "error")
        end
        state.isBusy = false
        return
    end

    state.isBusy = false
end

function AtmRobberyClient.startRopeAtm(model, entity)
    local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(entity))
    if distance > 2.0 then
        Utils.notify(locale("atm_robbery.too_far_from_atm"), "error", 3000)
        return
    end

    local requiredItem = config.ropeOptions.requiredItem or {}
    local hasRequiredItem = lib.callback.await(_e("server:hasItem"), false, requiredItem.itemName, 1)
    if not hasRequiredItem then
        Utils.notify(locale("atm_robbery.item_required", requiredItem.label), "error", 3000)
        return
    end

    Citizen.Wait(1000)
    if config.ropeOptions.addSkillCheck then
        if not Utils.skillCheck({ "easy", "easy", "medium" }) then
            return
        end
    end

    local isAtmAvailable = lib.callback.await(_e("server:scenarios:atm_robbery:isAtmAvailable"), false,
        { lobbyId = ClientApplication.state.lobby.id }
    )
    if not isAtmAvailable then
        Utils.notify(locale("atm_robbery.atm_not_available"), "error", 3000)
        return
    end

    local atmCoords = GetEntityCoords(entity)
    local atmRot = GetEntityRotation(entity)

    state.isBusy = true

    triggerAlert(atmCoords)

    TaskTurnPedToFaceCoord(cache.ped, atmCoords.x, atmCoords.y, atmCoords.z, 4000)
    Citizen.Wait(500)

    lib.playAnim(cache.ped, config.ropeOptions.animation.dict, config.ropeOptions.animation.name,
        8.0, 1.0, -1, 1, 0)

    Utils.progressBar({
        duration = config.ropeOptions.animation.duration or 5000,
        label = locale("atm_robbery.attaching_rope"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true,
            sprint = true,
        },
    })

    attachHookToPedHand()

    local fakeAtmObject = Utils.createObject({
        model = model,
        coords = atmCoords,
        rotation = atmRot,
        freeze = true,
        isNetwork = true,
    })
    if not fakeAtmObject then
        state.isBusy = false
        deleteAttachedHook()
        return
    end

    local fakeAtmObjectNetId = lib.waitFor(function()
        if not NetworkGetEntityIsNetworked(fakeAtmObject) then
            NetworkRegisterEntityAsNetworked(fakeAtmObject)
        else
            local netId = ObjToNet(fakeAtmObject)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, nil, false)

    SetEntityVisible(fakeAtmObject, false, false)

    local params = {
        lobbyId = ClientApplication.state.lobby.id,
        fakeAtmObjectNetId = fakeAtmObjectNetId,
        playerPedNetId = PedToNet(cache.ped),
        atm = {
            model = model,
            coords = atmCoords,
            rotation = atmRot,
            interactionName = "rope",
        }
    }

    TriggerServerEvent(_e("server:scenarios:atm_robbery:onRopeFromAtm"), params)

    nearVehicleBackWithHookThread()
end

function AtmRobberyClient.startHackingAtm(model, entity)
    state.isBusy = true

    local response = HackingDeviceClient:show()
    if not response then
        state.isBusy = false
        return
    end

    local response = lib.callback.await(_e("server:scenarios:atm_robbery:onAtmHacked"), false,
        {
            lobbyId = ClientApplication.state.lobby.id,
            atm = {
                model = model,
                coords = GetEntityCoords(entity),
                rotation = GetEntityRotation(entity),
                interactionName = "hacking",
            }
        }
    )

    if not response.success then
        Utils.notify(locale("atm_robbery.hacking_failed"), "error")
        if response.message then
            Utils.notify(response.message, "error")
        end
        state.isBusy = false
        return
    end

    state.isBusy = false
    triggerAlert(GetEntityCoords(entity))
end

function AtmRobberyClient.startDrillAtm(model, entity)
    local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(entity))
    if distance > 2.0 then
        Utils.notify(locale("atm_robbery.too_far_from_atm"), "error", 3000)
        return
    end

    local requiredItem = config.drillOptions.requiredItem
    local hasRequiredItem = lib.callback.await(_e("server:hasItem"), false, requiredItem.itemName, 1)
    if not hasRequiredItem then
        Utils.notify(locale("atm_robbery.item_required", requiredItem.label), "error", 3000)
        return
    end

    Citizen.Wait(1000)
    if config.drillOptions.addSkillCheck then
        if not Utils.skillCheck({ "easy", "easy", "medium" }) then
            return
        end
    end

    local isAtmAvailable = lib.callback.await(_e("server:scenarios:atm_robbery:isAtmAvailable"), false,
        { lobbyId = ClientApplication.state.lobby.id }
    )
    if not isAtmAvailable then
        Utils.notify(locale("atm_robbery.atm_not_available"), "error", 3000)
        return
    end

    state.isBusy = true

    local atmCoords = GetEntityCoords(entity)
    local atmRot = GetEntityRotation(entity)

    triggerAlert(atmCoords)

    TaskTurnPedToFaceCoord(cache.ped, atmCoords.x, atmCoords.y, atmCoords.z, 4000)

    Citizen.Wait(500)
    local playerPed = cache.ped
    local drillAnimation = config.drillOptions.animation
    local drillModel = SHARED_CONFIG.models.drill

    local drillObject = Utils.createObject({
        model = drillModel,
        coords = GetEntityCoords(playerPed),
        freeze = true,
        isNetwork = true,
    })
    if not drillObject then
        state.isBusy = false
        return
    end

    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    AttachEntityToEntity(drillObject, playerPed, boneIndex,
        0.14, 0.0, -0.04, -90.0, 100.0, 0.0,
        true, true, false, true, 1, true
    )

    local modelDrillingOffset = config.drillOptions.positionOffset or vector3(0.0, -0.5, 0.5)
    local drillingCoords = GetOffsetFromEntityInWorldCoords(entity,
        modelDrillingOffset.x, modelDrillingOffset.y, modelDrillingOffset.z)

    SetEntityCoords(playerPed, drillingCoords.x, drillingCoords.y, drillingCoords.z,
        false, false, false, false)
    local rotation = drillAnimation.rotation or vector3(0.0, 0.0, atmRot.z)
    SetEntityRotation(playerPed, rotation.x, rotation.y, rotation.z, 2, true)

    lib.playAnim(playerPed, drillAnimation.dict, drillAnimation.name, nil, nil, -1, 1)
    Utils.progressBar({
        duration = drillAnimation.duration or 5000,
        label = locale("atm_robbery.drilling_atm"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true,
            sprint = true,
        },
    })

    ClearPedTasks(playerPed)
    DeleteEntity(drillObject)
    RemoveAnimDict(drillAnimation.dict)

    local response = lib.callback.await(_e("server:scenarios:atm_robbery:onAtmDrilled"), false,
        {
            lobbyId = ClientApplication.state.lobby.id,
            atm = {
                model = model,
                coords = atmCoords,
                rotation = atmRot,
                interactionName = "drill",
            }
        }
    )

    if not response.success then
        Utils.notify(locale("atm_robbery.drilling_failed"), "error")
        if response.message then
            Utils.notify(response.message, "error")
        end
        state.isBusy = false
        return
    end

    state.isBusy = false
end

function AtmRobberyClient.clear()
    for _, zone in pairs(state.zones) do
        if zone then
            Target.removeZone(zone)
        end
    end

    if state.cashPileProp and DoesEntityExist(state.cashPileProp) then
        DeleteEntity(state.cashPileProp)
    end

    deleteAttachedHook()

    Target.removeModel(config.atmModels)

    __init_state__()
end

function AtmRobberyClient.init()
    setupAtmInteractions()
end

RegisterNetEvent(_e("client:scenarios:atm_robbery:onAtmHacked"), function(params)
    if not ClientApplication.state.activeScenario then return end

    local atm = params.atm

    ClientApplication.state.activeScenario.game.robbery.completed = true
    ClientApplication.state.activeScenario.game.robbery.atm = atm

    Utils.notify(locale("atm_robbery.hacking_successful"), "success")

    HeistClient.updateActiveInfoIndex(4)

    setupScatteredLoot(atm.model, atm.coords)

    Target.removeModel(config.atmModels)
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:attachRopeToPedHand"), function(params)
    for _, netId in pairs({ params.playerPedNetId, params.fakeAtmObjectNetId }) do
        local ok = Utils.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return true
            end
        end, 3000)
        if not ok then return end
    end

    local targetPed = NetToPed(params.playerPedNetId)
    local fakeAtmObject = NetToObj(params.fakeAtmObjectNetId)

    if not DoesEntityExist(targetPed) then return end
    if not DoesEntityExist(fakeAtmObject) then return end

    if params.owner == cache.serverId then
        ClearPedTasksImmediately(cache.ped)
        Citizen.Wait(100)
    end

    local rope = addRopeToEntity(params.lobbyId, params.owner, "ped")
    if not rope then return end

    local targetAtmOffset = GetOffsetFromEntityInWorldCoords(fakeAtmObject, 0.0, 0.0, 1.0)
    local pedBoneCoords = GetPedBoneCoords(targetPed, 6286, 0.0, 0.0, 0.0)

    AttachEntitiesToRope(rope, fakeAtmObject, targetPed,
        targetAtmOffset.x, targetAtmOffset.y, targetAtmOffset.z,
        pedBoneCoords.x, pedBoneCoords.y, pedBoneCoords.z,
        10.0, false, false, "rope_attach_a", "rope_attach_b")

    Citizen.CreateThread(function()
        while DoesLobbyPlayerRopeExist(ClientApplication.state.lobby?.id, params.owner, "ped") and
            DoesEntityExist(fakeAtmObject) and DoesEntityExist(targetPed) do
            local targetAtmOffset = GetOffsetFromEntityInWorldCoords(fakeAtmObject, 0.0, 0.0, 1.0)
            local pedBoneCoords = GetPedBoneCoords(targetPed, 6286, 0.0, 0.0, 0.0)
            DetachEntity(fakeAtmObject, true, true)
            DetachEntity(targetPed, true, true)

            AttachEntitiesToRope(rope, fakeAtmObject, targetPed,
                targetAtmOffset.x, targetAtmOffset.y, targetAtmOffset.z,
                pedBoneCoords.x, pedBoneCoords.y, pedBoneCoords.z,
                10.0, false, false, "rope_attach_a", "rope_attach_b")

            Citizen.Wait(64)
        end
    end)
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:deleteAllLobbyRopes"), function(params)
    local lobbyId = params.lobbyId

    deleteLobbyRopes(lobbyId)
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:onFakeAtmCreated"), function(params)
    state.fakeAtmObjectNetId = params.fakeAtmObjectNetId
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:attachRopeToVehicle"), function(params)
    deleteLobbyRopes(params.lobbyId)

    for _, netId in pairs({ params.vehicleNetId, params.fakeAtmObjectNetId }) do
        local ok = Utils.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return true
            end
        end, 3000)
        if not ok then return end
    end

    local targetVehicle = NetToVeh(params.vehicleNetId)
    local fakeAtmObject = NetToObj(params.fakeAtmObjectNetId)

    if not DoesEntityExist(targetVehicle) then return end
    if not DoesEntityExist(fakeAtmObject) then return end

    local rope = addRopeToEntity(params.lobbyId, params.owner, "vehicle")
    if not rope then return end

    local targetAtmOffset = GetOffsetFromEntityInWorldCoords(fakeAtmObject, 0.0, 0.0, 1.0)
    local vehicleCoords = GetOffsetFromEntityInWorldCoords(targetVehicle, 0, -2.1, -0.2)

    AttachEntitiesToRope(rope, fakeAtmObject, targetVehicle,
        targetAtmOffset.x, targetAtmOffset.y, targetAtmOffset.z,
        vehicleCoords.x, vehicleCoords.y, vehicleCoords.z,
        10.0, false, false, "rope_attach_a", "rope_attach_b")
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:onAtmRipped"), function(params)
    local lobbyId = params.lobbyId
    local model = params.model
    local coords = params.coords

    local nearByObjects = lib.getNearbyObjects(vector3(coords), 0.3)
    for _, v in ipairs(nearByObjects) do
        if GetEntityModel(v.object) == model then
            local nearObjectNetId = NetworkGetEntityIsNetworked(v.object) and ObjToNet(v.object) or nil
            if state.fakeAtmObjectNetId ~= nearObjectNetId then
                SetEntityAsMissionEntity(v.object, true, true)
                DeleteEntity(v.object)
            end
        end
    end

    if ClientApplication.state.lobby and ClientApplication.state.lobby.id == lobbyId then
        ClientApplication.state.activeScenario.game.robbery.completed = true
        HeistClient.updateActiveInfoIndex(3)

        local fakeAtmObject = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(state.fakeAtmObjectNetId) then
                local entity = NetToEnt(state.fakeAtmObjectNetId)
                if DoesEntityExist(entity) then return entity end
            end
        end, nil, false)

        addRobTargetToFakeAtm(fakeAtmObject)
    end
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:setVisibleFakeAtm"), function(params)
    for _, netId in pairs({ params.fakeAtmObjectNetId }) do
        local ok = Utils.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return true
            end
        end, 3000)
        if not ok then return end
    end

    local fakeAtmObject = NetToObj(params.fakeAtmObjectNetId)
    if not DoesEntityExist(fakeAtmObject) then return end

    SetEntityVisible(fakeAtmObject, true, false)
    FreezeEntityPosition(fakeAtmObject, false)
    SetObjectPhysicsParams(fakeAtmObject, 5.0, -1.0, 30.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0)
    local forceDirection = vector3(2.0, 2.0, 2.0)
    ApplyForceToEntity(fakeAtmObject, 1,
        forceDirection.x, forceDirection.y, forceDirection.z,
        0, 0, 0, 1.0, true, true, true, false, true)
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:onBombPlanted"), function(params)
    if ClientApplication.state.lobby and ClientApplication.state.lobby.id == params.lobbyId then
        ClientApplication.state.activeScenario.game.robbery.completed = true
        HeistClient.updateActiveInfoIndex(3)
    end

    local bombCoords = params.bombCoords
    local bombRot    = params.bombRot

    local atmModel   = params.atm.model
    local atmCoords  = params.atm.coords
    local atmRot     = params.atm.rotation

    local bombObject = Utils.createObject({
        model = "prop_bomb_01",
        coords = bombCoords,
        rotation = bombRot,
        freeze = true,
        isNetwork = true,
    })
    if not bombObject then return end

    for _ = 5, 1, -1 do
        PlaySoundFromCoord(-1, "Beep_Red",
            bombCoords.x, bombCoords.y, bombCoords.z,
            "DLC_HEIST_HACKING_SNAKE_SOUNDS", false, 10.0, false)
        Citizen.Wait(1000)
    end

    AddExplosion(bombCoords.x, bombCoords.y, bombCoords.z, 2, 2.0, true, false, 1.0)
    PlaySoundFromCoord(-1, "Bomb_Disarmed",
        bombCoords.x, bombCoords.y, bombCoords.z,
        "GTAO_Speed_Convoy_Soundset", false, 0, false)

    DeleteEntity(bombObject)

    local nearByObjects = lib.getNearbyObjects(vector3(atmCoords), 0.3)
    for _, v in ipairs(nearByObjects) do
        if GetEntityModel(v.object) == atmModel then
            SetEntityAsMissionEntity(v.object, true, true)
            DeleteEntity(v.object)
        end
    end

    if params.owner == cache.serverId then
        local ownedAtm = Utils.createObject({
            model = atmModel,
            coords = atmCoords,
            rotation = atmRot,
            freeze = false,
            isNetwork = true,
        })
        if not ownedAtm then return end

        ActivatePhysics(ownedAtm)
        SetEntityDynamic(ownedAtm, true)

        local forceDirection = vector3(1.0, 1.0, 1.0)
        ApplyForceToEntity(ownedAtm, 1,
            forceDirection.x, forceDirection.y, forceDirection.z,
            0, 0, 0, 1.0, true, true, true, false, true)

        Citizen.SetTimeout(5000, function()
            SetEntityAsNoLongerNeeded(ownedAtm)
        end)
    end

    if ClientApplication.state.lobby and ClientApplication.state.lobby.id == params.lobbyId then
        targetableScatteredLootProp(atmModel, atmCoords)
    end
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:onAtmDrilled"), function(params)
    if not ClientApplication.state.activeScenario then return end

    local atm = params.atm

    ClientApplication.state.activeScenario.game.robbery.completed = true
    ClientApplication.state.activeScenario.game.robbery.atm = atm

    Utils.notify(locale("atm_robbery.drilling_successful"), "success")

    HeistClient.updateActiveInfoIndex(4)

    setupScatteredLoot(atm.model, atm.coords)

    Target.removeModel(config.atmModels)
end)

RegisterNetEvent(_e("client:scenarios:atm_robbery:onScatteredLootCollected"), function(params)
    local lobbyId = params.lobbyId

    if ClientApplication.state.lobby and
        ClientApplication.state.lobby.id == lobbyId and
        ClientApplication.state.lobby.owner == cache.serverId
    then
        distanceCheckingForFinishThread(params.centerCoords)
    end
    HeistClient.updateActiveInfoIndex(4)
end)
