local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")

local config                = require("config.scenarios.vangelico_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

VangelicoRobberyClient      = {}

local state                 = {
    isBusy                       = false,
    blips                        = {},
    gasBombParticles             = {},
    poisonousGasParticle         = nil,
    inCutscene                   = false,
    lastPlayerCoords             = nil,
    isPoisonousGasActive         = false,
    doorLockingThread            = nil,
    robbablePeds                 = {},
    swappedModels                = {},
    zones                        = {},
    smashableCashRegisterObjects = {},
    smuggleablePaintingModels    = {},
    temporaryObjects             = {},
    caseRoomObjects              = {},
}

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
    Utils.triggerPoliceAlert("vangelico_robbery", locale("vangelico_robbery.police_alert"), coords)
end

local function clearSwappedModels()
    for _, data in pairs(state.swappedModels) do
        if data.offsetZ then
            local object = GetClosestObjectOfType(data.coords.x, data.coords.y, data.coords.z,
                0.5, data.newModel, false, false, false)
            if DoesEntityExist(object) then
                SetEntityAsMissionEntity(object, true, true)
                SetEntityCoordsNoOffset(object, data.coords.x, data.coords.y, data.coords.z, false, false, true)
            end
        end
        RemoveModelSwap(data.coords.x, data.coords.y, data.coords.z,
            0.5, data.originalModel, data.newModel, false)
    end
    state.swappedModels = {}
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

local function dropGasBomb(zoneIndex, droneCoords, targetCoords)
    local smokeModel = config.poisonousGasOptions.dropPropModel
    lib.requestModel(smokeModel)

    local smokeGrenadeObject = Utils.createObject({
        model = smokeModel,
        coords = vector3(droneCoords.x, droneCoords.y, droneCoords.z - 1.0),
        freeze = false,
        isNetwork = true,
    })

    SetEntityDynamic(smokeGrenadeObject, true)
    ActivatePhysics(smokeGrenadeObject)
    SetEntityDrawOutline(smokeGrenadeObject, true)

    Utils.notify(locale("vangelico_robbery.gas_grenade_dropped"), "success")

    Citizen.CreateThread(function()
        local dropped = false
        local startTime = GetGameTimer()
        if targetCoords.z then
            while ClientApplication.state.activeScenario do
                Citizen.Wait(100)
                local smokeCoords = GetEntityCoords(smokeGrenadeObject)
                if (smokeCoords.z - 2.5) < targetCoords.z then
                    dropped = true
                    break
                end
                if GetGameTimer() - startTime > 2000 then
                    break
                end
            end
        end
        DeleteObject(smokeGrenadeObject)
        lib.callback.await(_e("server:scenarios:vangelico_robbery:onGasBombDropped"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            zoneIndex = zoneIndex,
            coords = targetCoords,
        })
    end)
end

local function onGasMaskUsed()
    local activeScenario = ClientApplication.state.activeScenario
    local isWearedGasMask = LocalPlayer.state.isWearedGasMask

    if not isWearedGasMask and not activeScenario then return end

    local playerPedId = cache.ped

    LocalPlayer.state.isWearedGasMask = not isWearedGasMask

    local animDict, animName = "mp_masks@standard_car@ds@", "put_on_mask"

    lib.requestAnimDict(animDict)
    TaskPlayAnim(playerPedId, animDict, animName, 8.0, 8.0, 800, 16, 0, false, false, false)
    RemoveAnimDict(animDict)

    local isWearedGasMask = LocalPlayer.state.isWearedGasMask
    local pedSex = Utils.getPlayerPedSexName()

    local maskComponentVariation = config
        .poisonousGasOptions
        .maskComponentVariations[pedSex]
    if not maskComponentVariation then return end

    local drawableId = maskComponentVariation[isWearedGasMask and "on" or "off"].drawableId

    SetPedComponentVariation(playerPedId, 1, drawableId, 0, 1)
end

local function nearDroneUsageAreaThread()
    local droneOptions = DroneClient:getOptions()
    local droneModel = droneOptions.propModel
    local droneCoords = config.poisonousGasOptions.droneUsageAreaCoords

    local temporaryObject = Utils.createObject({
        model = droneModel,
        coords = droneCoords,
        freeze = true,
        isNetwork = false,
    })
    state.temporaryObjects["drone_usage_area"] = temporaryObject
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
            not ClientApplication.state.activeScenario.game.poisonousGasOptions.allDropped
        do
            local wait = 1000

            if not DroneClient:isActive() then
                local playerPedId = cache.ped
                local pedCoords = GetEntityCoords(playerPedId)
                local distance = #(pedCoords - config.poisonousGasOptions.droneUsageAreaCoords)

                if distance < 1.5 then
                    wait = 0
                    if not textUI and not DroneClient:isActive() then
                        textUI = true
                        Utils.showTextUI(locale("vangelico_robbery.use_drone"), "E")
                    end

                    if IsControlJustPressed(0, 38) then
                        Utils.hideTextUI()
                        if isItFirstTime then
                            isItFirstTime = false

                            local dropZones = ClientApplication.state.activeScenario.game.poisonousGasOptions.dropZones
                            for index, zone in pairs(dropZones) do
                                addBlip(zone.coords, SHARED_CONFIG.blips.gas_drop_zone, false, true,
                                    "gas_drop_zone_" .. index)
                            end

                            HeistClient.updateActiveInfoIndex(3)
                            HeistClient.updateActiveInfoProgress(0, #dropZones)
                        end

                        DroneClient:create(droneOptions,
                            config.poisonousGasOptions.droneUsageAreaCoords,
                            config.poisonousGasOptions.dropZones,
                            function(zoneIndex)
                                if not ClientApplication.state.activeScenario then return false end

                                local dropZone = ClientApplication.state.activeScenario.game.poisonousGasOptions
                                    .dropZones[zoneIndex]
                                if not dropZone then return false end

                                return not dropZone.dropped
                            end,
                            function(zoneIndex, droneCoords, targetCoords)
                                dropGasBomb(zoneIndex, droneCoords, targetCoords)
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

        removeBlipByKey("drone_arena")

        local temporaryObject = state.temporaryObjects["drone_usage_area"]
        if DoesEntityExist(temporaryObject) then
            DeleteEntity(temporaryObject)
            state.temporaryObjects["drone_usage_area"] = nil
        end
    end)
end

local function createCutsceneEntities()
    local playerPedId = cache.ped
    local clones = {}

    for i = 1, 5, 1 do
        local playerDummy = ClonePedEx(playerPedId, 0.0, false, true, true)
        clones[#clones + 1] = playerDummy
    end

    SetBlockingOfNonTemporaryEvents(clones[1], true)
    SetEntityVisible(clones[1], false, false)
    SetEntityInvincible(clones[1], true)
    SetEntityCollision(clones[1], false, false)
    FreezeEntityPosition(clones[1], true)
    SetPedHelmet(clones[1], false)
    RemovePedHelmet(clones[1], true)

    SetCutsceneEntityStreamingFlags("MP_1", 0, 1)
    RegisterEntityForCutscene(playerPedId, "MP_1", 0, GetEntityModel(playerPedId), 64)

    for i = 2, 5, 1 do
        local model = GetEntityModel(clones[i])
        SetCutsceneEntityStreamingFlags(("MP_%i"):format(i), 0, 1)
        RegisterEntityForCutscene(clones[i], ("MP_%i"):format(i), 0, model, 64)
    end

    Citizen.Wait(10)
    StartCutscene(0)
    Citizen.Wait(10)
    ClonePedToTarget(clones[1], playerPedId)
    Citizen.Wait(10)

    for _, clone in pairs(clones) do
        DeleteEntity(clone)
    end
end

local function onCutsceneFinished()
    if not state.inCutscene then return end

    DoScreenFadeOut(0)
    StopCutsceneImmediately()
    RemoveCutscene()

    local playerPedId = cache.ped
    local newCoords = vector3(state.lastPlayerCoords.x, state.lastPlayerCoords.y, state.lastPlayerCoords.z - 0.5)

    SetEntityCoords(playerPedId, newCoords)
    SetBlockingOfNonTemporaryEvents(playerPedId, false)
    SetEntityVisible(playerPedId, true, true)
    SetEntityInvincible(playerPedId, false)
    SetEntityCollision(playerPedId, true, true)
    FreezeEntityPosition(playerPedId, false)

    state.inCutscene = false
    Citizen.Wait(500)
    DoScreenFadeIn(500)
    Utils.toggleHud(true)
end

local function playCutscene(scene, coords, duration)
    state.inCutscene = true
    state.lastPlayerCoords = GetEntityCoords(cache.ped)

    Utils.toggleHud(false)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Citizen.Wait(100) end

    while not HasThisCutsceneLoaded(scene) do
        RequestCutscene(scene, 8)
        Citizen.Wait(100)
    end

    local playerPedId = cache.ped

    SetEntityCoords(playerPedId, coords)
    SetBlockingOfNonTemporaryEvents(playerPedId, true)
    SetEntityVisible(playerPedId, false, false)
    SetEntityInvincible(playerPedId, true)
    SetEntityCollision(playerPedId, false, false)
    FreezeEntityPosition(playerPedId, true)

    createCutsceneEntities()
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Citizen.Wait(100) end
    Citizen.Wait(duration)

    onCutsceneFinished()
end

local function findObjectsAndDeleteThread()
    Citizen.CreateThread(function()
        local storeCenterCoords = config.storeCenterCoords
        local foundObjects = {}

        while ClientApplication.state.activeScenario do
            local playerPedId = cache.ped
            local pedCoords = GetEntityCoords(playerPedId)
            local dist = #(pedCoords - storeCenterCoords)

            if dist <= 20.0 then
                for _, value in pairs(config.findAndRemoveObjects) do
                    local object = GetClosestObjectOfType(
                        value.coords.x,
                        value.coords.y,
                        value.coords.z,
                        5.0, value.model,
                        false, false, false
                    )
                    if DoesEntityExist(object) then
                        SetEntityAsMissionEntity(object, true, true)
                        DeleteEntity(object)
                    end
                end
                for key, value in pairs(state.swappedModels) do
                    if value.offsetZ then
                        local object = GetClosestObjectOfType(value.coords.x, value.coords.y, value.coords.z,
                            0.5, value.newModel, false, false, false)
                        if DoesEntityExist(object) then
                            local newZ = value.coords.z + value.offsetZ
                            SetEntityAsMissionEntity(object, true, true)
                            SetEntityCoordsNoOffset(object, value.coords.x, value.coords.y, newZ, false, false, true)
                        end
                    end
                end
            end
            Citizen.Wait(5000)
        end
    end)
end

local function poisonousGasDamageThread()
    state.isPoisonousGasActive = true

    local particle = config.poisonousGasOptions.particle

    lib.requestNamedPtfxAsset(particle.ptfxName)
    UseParticleFxAsset(particle.ptfxName)
    state.poisonousGasParticle = StartParticleFxLoopedAtCoord(
        particle.effectName,
        particle.coords.x, particle.coords.y, particle.coords.z,
        0.0, 0.0, 0.0, 0.5, false, false, false, false
    )

    Citizen.CreateThread(function()
        local storeCenterCoords = config.storeCenterCoords

        while state.isPoisonousGasActive do
            local playerPedId = cache.ped
            local pedCoords = GetEntityCoords(playerPedId)
            local dist = #(pedCoords - storeCenterCoords)

            if dist <= config.poisonousGasOptions.radius then
                if not LocalPlayer.state.isWearedGasMask then
                    ApplyDamageToPed(playerPedId, SHARED_CONFIG.gameplay.damage.gasPerSecond, false)
                    Utils.notify(locale("vangelico_robbery.need_gas_mask"), "warning", 1000)
                    Citizen.Wait(1000)
                end
            end
            Citizen.Wait(500)
        end
    end)
end

local function freezeEntranceDoors(state)
    local doors = config.entranceDoorOptions.doors
    for _, door in ipairs(doors) do
        local closestDoorObject = GetClosestObjectOfType(
            door.coords.x, door.coords.y, door.coords.z,
            0.3, door.model,
            false, false, false)
        if DoesEntityExist(closestDoorObject) then
            SetEntityAsMissionEntity(closestDoorObject, true, true)
            FreezeEntityPosition(closestDoorObject, state)
            if state then
                SetEntityRotation(closestDoorObject, vector3(0.0, 0.0, door.yaw))
            end
        end
    end
end

local function plantBombOnDoor(params)
    local door = config.entranceDoorOptions.doors[params.doorIndex]
    if not door then return false end

    local propModel = SHARED_CONFIG.models.bomb
    lib.requestModel(propModel)

    local bombObject = Utils.createObject({
        model = propModel,
        coords = params.coords,
        rotation = params.rotation,
        freeze = true,
        isNetwork = false,
    })

    for i = 7, 1, -1 do
        PlaySoundFromCoord(-1, "Beep_Red",
            params.coords.x, params.coords.y, params.coords.z,
            "DLC_HEIST_HACKING_SNAKE_SOUNDS", 0, 0, 0
        )
        Citizen.Wait(1000)
    end

    freezeEntranceDoors(false)
    AddExplosion(params.coords.x, params.coords.y, params.coords.z, 2, 2.0, true, false, 1.0, false)
    PlaySoundFromCoord(-1,
        "Bomb_Disarmed",
        params.coords.x, params.coords.y, params.coords.z,
        "GTAO_Speed_Convoy_Soundset", 0, 0, 0
    )

    DeleteEntity(bombObject)
end

local function playPlantBombOnDoorAnimation(doorIndex)
    local door = config.entranceDoorOptions.doors[doorIndex]
    if not door then return false end

    local animDict = SHARED_CONFIG.animations.plantBomb.dict
    local animName = SHARED_CONFIG.animations.plantBomb.name
    local propModel = SHARED_CONFIG.models.bomb
    local playerPedId = cache.ped

    lib.requestAnimDict(animDict)

    local sceneCoords = door.coords
    local sceneRot = GetEntityRotation(playerPedId)

    local doorObject = GetClosestObjectOfType(
        door.coords.x, door.coords.y, door.coords.z,
        0.3, door.model,
        false, false, false)

    if DoesEntityExist(doorObject) then
        local doorOffsets = {
            [1] = vector3(0.75, 0.0, 0.0),
            [2] = vector3(-0.75, 0.0, 0.0),
        }

        sceneCoords = GetOffsetFromEntityInWorldCoords(doorObject,
            doorOffsets[doorIndex].x,
            doorOffsets[doorIndex].y,
            doorOffsets[doorIndex].z
        )
    end

    local plantScene = NetworkCreateSynchronisedScene(
        sceneCoords.x, sceneCoords.y, sceneCoords.z,
        sceneRot.x, sceneRot.y, sceneRot.z, 2,
        false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPedId,
        plantScene, animDict,
        animName,
        1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkStartSynchronisedScene(plantScene)
    Citizen.Wait(1500)

    lib.requestModel(propModel)
    local plantObject = Utils.createObject({
        model = propModel,
        coords = vector3(0.0, 0.0, 0.0),
        freeze = true,
        isNetwork = true,
    })

    SetEntityCollision(plantObject, false, true)
    AttachEntityToEntity(plantObject, playerPedId,
        GetPedBoneIndex(playerPedId, 28422),
        0.0, 0.0, 0.0, 0.0, 0.0, 200.0,
        true, true, false, true, 1, true)

    Citizen.Wait(3000)

    local plantedBombCoords = GetEntityCoords(plantObject)
    local plantedBombRot = GetEntityRotation(plantObject)

    local plantedBomb = {
        model = propModel,
        coords = plantedBombCoords,
        rotation = plantedBombRot,
        doorIndex = doorIndex,
    }

    ClearPedTasks(playerPedId)
    DeleteEntity(plantObject)
    RemoveAnimDict(animDict)

    return plantedBomb
end

local function frontDoorLockingThread()
    if state.doorLockingThread then return end

    state.doorLockingThread = true

    Citizen.CreateThread(function()
        while state.doorLockingThread do
            freezeEntranceDoors(true)
            Citizen.Wait(500)
        end
        freezeEntranceDoors(false)
    end)

    if not ClientApplication.state.activeScenario then return end

    Citizen.CreateThread(function()
        local doors = config.entranceDoorOptions.doors
        local textUI = false

        while state.doorLockingThread and
            not ClientApplication.state.activeScenario.game.entranceDoorOptions.bombPlanted
        do
            local wait = 1000

            local closestDoorDist = math.huge
            local closestDoorIndex = nil
            local playerCoords = GetEntityCoords(cache.ped)

            for i, door in ipairs(doors) do
                local doorCoords = vector3(door.coords.x, door.coords.y, door.coords.z)
                local dist = #(playerCoords - doorCoords)

                if dist < closestDoorDist then
                    closestDoorDist = dist
                    closestDoorIndex = i
                end
            end
            if closestDoorDist < 1.5 and closestDoorIndex then
                wait = 0
                if not textUI then
                    textUI = true
                    Utils.showTextUI(locale("vangelico_robbery.plant_bomb"), "E")
                end

                if IsControlJustPressed(0, 38) then
                    local requiredBombItem = { name = "weapon_stickybomb", label = "Sticky Bomb" }
                    local itemCheckResponse = lib.callback.await(_e("server:hasItem"), false, requiredBombItem.name, 1)
                    if itemCheckResponse then
                        lib.callback.await(_e("server:removeItem"), false, requiredBombItem.name, 1)

                        textUI = false
                        Utils.hideTextUI()
                        local plantedBomb = playPlantBombOnDoorAnimation(closestDoorIndex)
                        local response = lib.callback.await(
                            _e("server:scenarios:vangelico_robbery:plantBombAtFrontDoor"), false, {
                                lobbyId = ClientApplication.state.lobby.id,
                                plantedBomb = plantedBomb,
                            })

                        if response then break end
                    else
                        Utils.notify(locale("dont_have_required_item", requiredBombItem.label), "error")
                    end

                    wait = 1000
                end
            elseif textUI then
                textUI = false
                Utils.hideTextUI()
            end

            Citizen.Wait(wait)
        end
    end)
end

local function robPedItems(robbablePedIndex)
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    state.isBusy = true
    local animation = {
        dict     = "amb@medic@standing@tendtodead@idle_a",
        name     = "idle_a",
        duration = 3500,
    }

    lib.requestAnimDict(animation.dict)
    TaskPlayAnim(cache.ped, animation.dict, animation.name,
        8.0, -8.0, animation.duration, 0, 0, false, false, false)
    Citizen.Wait(animation.duration)
    ClearPedTasks(cache.ped)
    RemoveAnimDict(animation.dict)

    local response = lib.callback.await(
        _e("server:scenarios:vangelico_robbery:robPedItems"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            pedIndex = robbablePedIndex,
        })
    if not response then
        Utils.notify(locale("vangelico_robbery.could_not_rob"), "error")
    else
        Utils.notify(locale("vangelico_robbery.robbed_ped"), "success", 5000)
    end

    state.isBusy = false
end

local function setRobbablePedAnim(ped)
    local animDict = "dead"
    local animNames = { "dead_a", "dead_b", "dead_c", "dead_d" }
    lib.requestAnimDict(animDict)
    local animName = animNames[math.random(1, #animNames)]
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(animDict)
end

local function spawnRobbablePeds()
    local robbablePeds = config.robbablePedOptions.peds
    for index, ped in pairs(robbablePeds) do
        lib.requestModel(ped.model)
        local pedZ = ped.coords.z
        local success, groundZ = GetGroundZFor_3dCoord(ped.coords.x, ped.coords.y, ped.coords.z + 0.5, false)
        if success then
            pedZ = groundZ
        end

        local pedKey = "robbable_ped_" .. index
        local newRobbablePed = Utils.createPed({
            model = ped.model,
            coords = vector4(ped.coords.x, ped.coords.y, pedZ, ped.coords.w),
            freeze = true,
            invincible = true,
            blockevents = true,
        })

        state.robbablePeds[pedKey] = newRobbablePed
        PlaceObjectOnGroundProperly(newRobbablePed)
        setRobbablePedAnim(newRobbablePed)

        Target.addLocalEntity(newRobbablePed, { {
            icon = "fa-solid fa-hand",
            label = locale("vangelico_robbery.rob_ped"),
            canInteract = function()
                return not state.isBusy
            end,
            onSelect = function(self)
                robPedItems(index)
                Target.removeLocalEntity(newRobbablePed)
            end,
            distance = 1.5,
        } })
    end
end

local function lootDisplay(displayIndex, display)
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    state.isBusy = true
    Utils.toggleHud(false)

    local animation = {
        dict = "anim@heists@ornate_bank@grab_cash_heels",
        name = "grab",
        duration = 2000,
    }

    lib.requestAnimDict(animation.dict)
    TaskPlayAnim(cache.ped, animation.dict, animation.name,
        8.0, -8.0, animation.duration, 0, 0, false, false, false)
    Citizen.Wait(animation.duration)
    ClearPedTasks(cache.ped)
    RemoveAnimDict(animation.dict)

    local response = lib.callback.await(
        _e("server:scenarios:vangelico_robbery:lootDisplay"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            displayIndex = displayIndex,
        })
    if not response then
        Utils.notify(locale("vangelico_robbery.could_not_loot"), "error", 5000)
    else
        Utils.notify(locale("vangelico_robbery.looted_display"), "success", 5000)
    end

    Utils.toggleHud(true)
    state.isBusy = false
end

local function setupLootableDisplays()
    local locations = config.lootableDisplayOptions.locations
    for index, loc in pairs(locations) do
        local zoneName = "scenario:vangelico:display_zone_" .. index
        local coords = vector3(loc.objectCoords.x, loc.objectCoords.y, loc.objectCoords.z + .05)
        local size = vector3(.4, .4, .3)
        if index >= 9 then
            size = vector3(.25, .25, .3)
        end

        state.zones["lootable_display_" .. index] = zoneName
        Target.addBoxZone(zoneName, {
            name = zoneName,
            coords = coords,
            size = size,
            rotation = coords.w or 35.0,
            debug = Config.debug,
            options = { {
                icon = "fa-solid fa-hand-fist",
                label = locale("vangelico_robbery.loot_display"),
                distance = 1.5,
                canInteract = function()
                    local isLooted = ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.game.lootableDisplayOptions.locations[index] and
                        ClientApplication.state.activeScenario.game.lootableDisplayOptions.locations[index].looted

                    return not state.isBusy and not isLooted
                end,
                onSelect = function()
                    lootDisplay(index, loc)
                    Target.removeZone(zoneName)
                    state.zones["lootable_display_" .. index] = nil
                end
            } },
        })
    end
end

---@param caseIndex number
---@param case {objectCoords: vector3, sceneCoords: vector3, sceneHeading: number, originalModel: string, newModel: string}
---@param zoneName string
local function smashCase(caseIndex, case, zoneName)
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    local pedWeapon = GetSelectedPedWeapon(cache.ped)
    local smashableWeapons = config.smashableCaseOptions.smashableWeapons
    local canSmash = false
    for _, v in pairs(smashableWeapons) do
        local smashWeaponHash = type(v) ~= "number" and GetHashKey(v) or v
        if smashWeaponHash == pedWeapon then
            canSmash = true
            break
        end
    end
    if not canSmash then
        return Utils.notify(locale("vangelico_robbery.need_smash_weapon"), "error")
    end

    state.isBusy = true
    Utils.toggleHud(false)

    local smashAnimation = {
        dict = "missheist_jewel",
        names = { "smash_case_necklace", "smash_case_d", "smash_case_e", "smash_case_f", }
    }
    local randomAnimName = smashAnimation.names[math.random(1, #smashAnimation.names)]
    if caseIndex == 14 or caseIndex == 20 or caseIndex == 16 then
        randomAnimName = "smash_case_necklace_skull"
    end

    local playerPedId = cache.ped
    SetEntityCoords(playerPedId, case.sceneCoords.x, case.sceneCoords.y, case.sceneCoords.z)
    SetEntityHeading(playerPedId, case.sceneHeading)

    local smashCam = CreateCam("DEFAULT_ANIMATED_CAMERA", true)
    SetCamActive(smashCam, true)
    RenderScriptCams(true, false, 0, false, true)

    local smashScene = NetworkCreateSynchronisedScene(
        case.sceneCoords.x, case.sceneCoords.y, case.sceneCoords.z,
        0.0, 0.0, case.sceneHeading,
        2, true, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPedId, smashScene,
        smashAnimation.dict, randomAnimName, 2.0, 4.0, 1, 0, 1148846080, 0)
    NetworkStartSynchronisedScene(smashScene)

    PlayCamAnim(smashCam, "cam_" .. randomAnimName, smashAnimation.dict,
        case.sceneCoords.x, case.sceneCoords.y, case.sceneCoords.z,
        0.0, 0.0, case.sceneHeading, 0, 2)

    Citizen.Wait(300)

    lib.requestAnimDict(smashAnimation.dict)
    TaskPlayAnim(playerPedId, smashAnimation.dict, randomAnimName, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
    RemoveAnimDict(smashAnimation.dict)
    Citizen.Wait(300)

    Target.removeZone(zoneName)
    state.zones["smashable_case_" .. caseIndex] = nil

    local response = lib.callback.await(
        _e("server:scenarios:vangelico_robbery:smashCase"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            caseIndex = caseIndex,
        })
    if not response then
        Utils.notify(locale("vangelico_robbery.could_not_loot"), "error", 5000)
    else
        Utils.notify(locale("vangelico_robbery.looted_display"), "success", 5000)
    end

    local smashParticle = {
        asset = "scr_jewelheist",
        effect = "scr_jewel_cab_smash",
    }
    lib.requestNamedPtfxAsset(smashParticle.asset)
    UseParticleFxAsset(smashParticle.asset)
    StartNetworkedParticleFxNonLoopedAtCoord(smashParticle.effect,
        case.objectCoords.x, case.objectCoords.y, case.objectCoords.z,
        0.0, 0.0, 0.0, 2.0,
        false, false, false)
    RemoveNamedPtfxAsset(smashParticle.asset)
    Citizen.Wait(math.max(0, (GetAnimDuration(smashAnimation.dict, randomAnimName) * 1000 - 1000)))
    ClearPedTasks(playerPedId)
    DestroyCam(smashCam, false)
    ClearFocus()
    RenderScriptCams(false, false, 0, false, false)

    Utils.toggleHud(true)
    state.isBusy = false
end

local function setupSmashableCases()
    local otherSizes = {
        [5] = true,
        [6] = true,
        [7] = true,
        [8] = true,
        [15] = true,
        [17] = true,
        [18] = true,
        [20] = true,
    }

    local locations = config.smashableCaseOptions.locations
    for index, loc in pairs(locations) do
        local zoneName = "scenario:vangelico:smashable_case_zone_" .. index
        local coords = vector3(loc.objectCoords.x, loc.objectCoords.y, loc.objectCoords.z + .4)
        local size = vector3(1.0, .64, .4)
        if otherSizes[index] then
            size = vector3(.64, 1.0, .4)
        end

        state.zones["smashable_case_" .. index] = zoneName
        Target.addBoxZone(zoneName, {
            name = zoneName,
            coords = coords,
            size = size,
            rotation = coords.w or 35.0,
            debug = Config.debug,
            options = { {
                icon = "fa-solid fa-gem",
                label = locale("vangelico_robbery.smash_case"),
                distance = 1.5,
                canInteract = function()
                    local isSmashed = ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.game.smashableCaseOptions.locations[index] and
                        ClientApplication.state.activeScenario.game.smashableCaseOptions.locations[index].smashed

                    return not state.isBusy and not isSmashed
                end,
                onSelect = function()
                    smashCase(index, loc, zoneName)
                end
            } },
        })
    end
end

local function smashCashRegister(registerIndex, register, zoneName)
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    local pedWeapon = GetSelectedPedWeapon(cache.ped)
    local smashableWeapons = config.smashableCashRegisterOptions.smashableWeapons
    local canSmash = false
    for _, v in pairs(smashableWeapons) do
        local smashWeaponHash = type(v) ~= "number" and GetHashKey(v) or v
        if smashWeaponHash == pedWeapon then
            canSmash = true
            break
        end
    end
    if not canSmash then
        return Utils.notify(locale("vangelico_robbery.need_smash_weapon"), "error")
    end

    state.isBusy = true
    Utils.toggleHud(false)

    local smashAnimation = {
        dict = "missheist_jewel",
        names = { "smash_case_necklace" }
    }
    local randomAnimName = smashAnimation.names[math.random(1, #smashAnimation.names)]

    local playerPedId = cache.ped
    SetEntityCoords(playerPedId, register.sceneCoords.x, register.sceneCoords.y, register.sceneCoords.z)
    SetEntityHeading(playerPedId, register.sceneHeading)

    local smashScene = NetworkCreateSynchronisedScene(
        register.sceneCoords.x, register.sceneCoords.y, register.sceneCoords.z,
        0.0, 0.0, register.sceneHeading,
        2, true, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPedId, smashScene,
        smashAnimation.dict, randomAnimName, 2.0, 4.0, 1, 0, 1148846080, 0)
    NetworkStartSynchronisedScene(smashScene)

    Citizen.Wait(300)
    lib.requestAnimDict(smashAnimation.dict)
    TaskPlayAnim(playerPedId, smashAnimation.dict, randomAnimName, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
    RemoveAnimDict(smashAnimation.dict)
    Citizen.Wait(300)

    Target.removeZone(zoneName)
    state.zones["cash_register_" .. registerIndex] = nil

    local response = lib.callback.await(
        _e("server:scenarios:vangelico_robbery:smashCashRegister"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            registerIndex = registerIndex,
        })
    if not response then
        Utils.notify(locale("vangelico_robbery.could_not_loot"), "error", 5000)
    else
        Utils.notify(locale("vangelico_robbery.looted_display"), "success", 5000)
    end

    local smashParticle = {
        asset = "scr_jewelheist",
        effect = "scr_jewel_cab_smash",
    }
    lib.requestNamedPtfxAsset(smashParticle.asset)
    UseParticleFxAsset(smashParticle.asset)
    StartNetworkedParticleFxNonLoopedAtCoord(smashParticle.effect,
        register.objectCoords.x, register.objectCoords.y, register.objectCoords.z,
        0.0, 0.0, 0.0, 2.0,
        false, false, false)
    RemoveNamedPtfxAsset(smashParticle.asset)
    Citizen.Wait(math.max(0, (GetAnimDuration(smashAnimation.dict, randomAnimName) * 1000 - 1000)))

    ClearPedTasks(playerPedId)

    Utils.toggleHud(true)
    state.isBusy = false
end

local function setupSmashableCashRegisters()
    local locations = config.smashableCashRegisterOptions.locations
    for index, loc in pairs(locations) do
        if not loc.alreadySpawned then
            local propModel = loc.originalModel
            local cashRegisterObject = Utils.createObject({
                model = propModel,
                coords = loc.objectCoords,
                rotation = loc.objectCoords.w or loc.objectRotation or vector3(0.0, 0.0, 0.0),
                freeze = true,
                isNetwork = false,
            })
            state.smashableCashRegisterObjects["cash_register_" .. index] = cashRegisterObject
        end

        local zoneName = "scenario:vangelico:smashable_cash_register_zone_" .. index
        local coords = vector3(loc.objectCoords.x, loc.objectCoords.y, loc.objectCoords.z)
        local size = vector3(0.5, .5, .4)

        state.zones["cash_register_" .. index] = zoneName
        Target.addBoxZone(zoneName, {
            name = zoneName,
            coords = vector3(coords.x, coords.y, coords.z + .15),
            size = size,
            rotation = loc.objectCoords.w or 0.0,
            debug = Config.debug,
            options = { {
                icon = "fa-solid fa-cash-register",
                label = locale("vangelico_robbery.smash_register"),
                distance = 1.5,
                canInteract = function()
                    local isSmashed = ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.game.smashableCashRegisterOptions.locations[index] and
                        ClientApplication.state.activeScenario.game.smashableCashRegisterOptions.locations[index]
                        .smashed

                    return not state.isBusy and not isSmashed
                end,
                onSelect = function()
                    smashCashRegister(index, loc, zoneName)
                end
            } },
        })
    end
end

---@param paintingIndex number
---@param painting {objectCoords: vector3, sceneCoords: string}
local function smugglePainting(paintingIndex, painting, zoneName)
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    local playerPedId = cache.ped
    local playerWeapon = GetSelectedPedWeapon(playerPedId)
    local requiredWeapon = config.paintingSmuggleOptions.requiredWeapon

    if playerWeapon ~= GetHashKey(requiredWeapon.name) then
        return Utils.notify(locale("vangelico_robbery.required_weapon", requiredWeapon.label), "error")
    end

    local paintingModel = state.smuggleablePaintingModels[paintingIndex] and
        state.smuggleablePaintingModels[paintingIndex].model or nil
    if not paintingModel then
        return Utils.notify(locale("vangelico_robbery.could_not_loot"), "error")
    end

    Utils.toggleHud(false)
    state.isBusy         = true

    local playerCoords   = GetEntityCoords(playerPedId)
    local playerRot      = GetEntityRotation(playerPedId)

    local animDict       = "anim_heist@hs3f@ig11_steal_painting@male@"

    local sceneObject    = GetClosestObjectOfType(
        painting.objectCoords.x, painting.objectCoords.y, painting.objectCoords.z,
        0.3, paintingModel,
        false, false, false)

    local sceneCoords    = painting.sceneCoords
    local sceneRot       = vector3(0.0, 0.0, sceneCoords.w or playerRot.z)

    local sceneObjects   = {}
    local scenes         = {}

    local weaponModel    = "w_me_switchblade"
    local animationNames = {
        { "top_left_enter",               "top_left_enter_ch_prop_ch_sec_cabinet_02a",               "top_left_enter_ch_prop_vault_painting_01a",               "top_left_enter_hei_p_m_bag_var22_arm_s",               "top_left_enter_w_me_switchblade" },
        { "cutting_top_left_idle",        "cutting_top_left_idle_ch_prop_ch_sec_cabinet_02a",        "cutting_top_left_idle_ch_prop_vault_painting_01a",        "cutting_top_left_idle_hei_p_m_bag_var22_arm_s",        "cutting_top_left_idle_w_me_switchblade" },
        { "cutting_top_left_to_right",    "cutting_top_left_to_right_ch_prop_ch_sec_cabinet_02a",    "cutting_top_left_to_right_ch_prop_vault_painting_01a",    "cutting_top_left_to_right_hei_p_m_bag_var22_arm_s",    "cutting_top_left_to_right_w_me_switchblade" },
        { "cutting_top_right_idle",       "_cutting_top_right_idle_ch_prop_ch_sec_cabinet_02a",      "cutting_top_right_idle_ch_prop_vault_painting_01a",       "cutting_top_right_idle_hei_p_m_bag_var22_arm_s",       "cutting_top_right_idle_w_me_switchblade" },
        { "cutting_right_top_to_bottom",  "cutting_right_top_to_bottom_ch_prop_ch_sec_cabinet_02a",  "cutting_right_top_to_bottom_ch_prop_vault_painting_01a",  "cutting_right_top_to_bottom_hei_p_m_bag_var22_arm_s",  "cutting_right_top_to_bottom_w_me_switchblade" },
        { "cutting_bottom_right_idle",    "cutting_bottom_right_idle_ch_prop_ch_sec_cabinet_02a",    "cutting_bottom_right_idle_ch_prop_vault_painting_01a",    "cutting_bottom_right_idle_hei_p_m_bag_var22_arm_s",    "cutting_bottom_right_idle_w_me_switchblade" },
        { "cutting_bottom_right_to_left", "cutting_bottom_right_to_left_ch_prop_ch_sec_cabinet_02a", "cutting_bottom_right_to_left_ch_prop_vault_painting_01a", "cutting_bottom_right_to_left_hei_p_m_bag_var22_arm_s", "cutting_bottom_right_to_left_w_me_switchblade" },
        { "cutting_bottom_left_idle",     "cutting_bottom_left_idle_ch_prop_ch_sec_cabinet_02a",     "cutting_bottom_left_idle_ch_prop_vault_painting_01a",     "cutting_bottom_left_idle_hei_p_m_bag_var22_arm_s",     "cutting_bottom_left_idle_w_me_switchblade" },
        { "cutting_left_top_to_bottom",   "cutting_left_top_to_bottom_ch_prop_ch_sec_cabinet_02a",   "cutting_left_top_to_bottom_ch_prop_vault_painting_01a",   "cutting_left_top_to_bottom_hei_p_m_bag_var22_arm_s",   "cutting_left_top_to_bottom_w_me_switchblade" },
        { "with_painting_exit",           "with_painting_exit_ch_prop_ch_sec_cabinet_02a",           "with_painting_exit_ch_prop_vault_painting_01a",           "with_painting_exit_hei_p_m_bag_var22_arm_s",           "with_painting_exit_w_me_switchblade" },
    }

    local weaponObject   = Utils.createObject({
        model = weaponModel,
        coords = vector3(0.0, 0.0, 0.0),
        freeze = true,
        isNetwork = true,
    })
    table.insert(sceneObjects, weaponObject)

    lib.requestAnimDict(animDict)

    for i = 1, 10 do
        scenes[i] = NetworkCreateSynchronisedScene(
            sceneCoords.x, sceneCoords.y, sceneCoords.z - 1.0,
            sceneRot.x, sceneRot.y, sceneRot.z,
            2, true, false, 1065353216, 0, 1065353216
        )
        NetworkAddPedToSynchronisedScene(playerPedId, scenes[i], animDict,
            "ver_01_" .. animationNames[i][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
        NetworkAddEntityToSynchronisedScene(sceneObject, scenes[i], animDict,
            "ver_01_" .. animationNames[i][3], 1.0, -1.0, 1148846080)
        NetworkAddEntityToSynchronisedScene(sceneObjects[1], scenes[i], animDict,
            "ver_01_" .. animationNames[i][5], 1.0, -1.0, 1148846080)
    end

    local paintingCam = CreateCam("DEFAULT_ANIMATED_CAMERA", true)
    SetCamActive(paintingCam, true)
    RenderScriptCams(true, true, 1000, false, true)

    local function playScene(index, anim, waitTime)
        NetworkStartSynchronisedScene(scenes[index])
        PlayCamAnim(
            paintingCam,
            anim,
            animDict,
            sceneCoords.x, sceneCoords.y, sceneCoords.z - 1.0,
            sceneRot.x, sceneRot.y, sceneRot.z,
            false, 2
        )
        if waitTime then
            Citizen.Wait(waitTime)
        end
    end

    -- sahne sıralaması ve wait time:
    local sceneData = {
        { 1,  "ver_01_top_left_enter_cam_ble",           1500 },
        { 2,  "ver_01_cutting_top_left_idle_cam" },
        { 3,  "ver_01_cutting_top_left_to_right_cam",    2500 },
        { 4,  "ver_01_cutting_top_right_idle_cam" },
        { 5,  "ver_01_cutting_right_top_to_bottom_cam",  2500 },
        { 6,  "ver_01_cutting_bottom_right_idle_cam" },
        { 7,  "ver_01_cutting_bottom_right_to_left_cam", 2500 },
        { 9,  "ver_01_cutting_left_top_to_bottom_cam",   1500 },
        { 10, nil,                                       1500 },
    }
    for _, data in ipairs(sceneData) do
        local index, anim, waitTime = table.unpack(data)
        if anim then
            playScene(index, anim, waitTime)
        else
            NetworkStartSynchronisedScene(scenes[index])
            if waitTime then Citizen.Wait(waitTime) end
        end
    end

    DestroyCam(paintingCam, false)
    ClearFocus()
    RenderScriptCams(false, false, 0, false, false)
    Citizen.Wait(5000)

    ClearPedTasks(playerPedId)
    RemoveAnimDict(animDict)

    for k, v in pairs(sceneObjects) do
        DeleteObject(v)
    end

    -- fetch response and finishing

    local response = lib.callback.await(
        _e("server:scenarios:vangelico_robbery:smugglePainting"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            paintingIndex = paintingIndex,
        })
    if not response then
        Utils.notify(locale("vangelico_robbery.could_not_loot"), "error", 5000)
    else
        Utils.notify(locale("vangelico_robbery.looted_display"), "success", 5000)
    end

    Target.removeZone(zoneName)
    state.zones["painting_" .. paintingIndex] = nil

    Utils.toggleHud(true)
    state.isBusy = false
end

local function setupPaintings()
    local locations = config.paintingSmuggleOptions.locations
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId

    for index, loc in pairs(locations) do
        local coords = vector3(loc.objectCoords.x, loc.objectCoords.y, loc.objectCoords.z + .45)
        local zoneName = "scenario:vangelico:painting_zone_" .. index
        state.zones["painting_" .. index] = zoneName
        Target.addBoxZone(zoneName, {
            name = zoneName,
            coords = coords,
            size = vector3(0.8, .15, 1.0),
            rotation = loc.objectCoords.w or 0.0,
            debug = Config.debug,
            options = { {
                icon = "fa-solid fa-image",
                label = locale("vangelico_robbery.take_painting"),
                distance = 1.5,
                canInteract = function()
                    local isTaken = ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.game.paintingSmuggleOptions.locations[index] and
                        ClientApplication.state.activeScenario.game.paintingSmuggleOptions.locations[index].taken

                    return not state.isBusy and not isTaken
                end,
                onSelect = function()
                    smugglePainting(index, loc, zoneName)
                end
            } },
        })

        if isOwner then
            local propModel = config.paintingSmuggleOptions.paintingModels
                [math.random(1, #config.paintingSmuggleOptions.paintingModels)]
            local paintingObject = Utils.createObject({
                model = propModel,
                coords = loc.objectCoords,
                rotation = loc.objectCoords.w or loc.objectRotation or vector3(0.0, 0.0, 0.0),
                freeze = true,
                isNetwork = true,
            })

            local networkId = lib.waitFor(function()
                if not NetworkGetEntityIsNetworked(paintingObject) then
                    NetworkRegisterEntityAsNetworked(paintingObject)
                else
                    local netId = ObjToNet(paintingObject)
                    if NetworkDoesNetworkIdExist(netId) then
                        return netId
                    end
                end
            end, nil, false)

            TriggerServerEvent(_e("server:scenarios:vangelico_robbery:registerPaintingObject"), {
                lobbyId = ClientApplication.state.lobby.id,
                index = index,
                netId = networkId,
                model = propModel,
            })
        end
    end
end

local function distanceCheckingForFinishThread()
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    Citizen.CreateThread(function()
        local storeCenterCoords = config.storeCenterCoords
        local maxDistance = config.requiredDistanceForFinish
        while ClientApplication.state.activeScenario do
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vector3(storeCenterCoords))
            if distance > maxDistance then
                HeistClient.completeScenario()
                return
            end
            Citizen.Wait(1000)
        end
    end)
end

local function setCaseRoomDoorLocking(state)
    local door = config.caseRoomOptions.door
    local doorObject = GetClosestObjectOfType(
        door.coords.x, door.coords.y, door.coords.z,
        1.0, door.model,
        false, false, false)

    if DoesEntityExist(doorObject) then
        SetEntityAsMissionEntity(doorObject, true, true)
        FreezeEntityPosition(doorObject, state)
        if state then
            SetEntityHeading(doorObject, door.yaw or 0.0)
        end
    end
end

local function unlockCaseRoomDoorWithKeypad()
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    if ClientApplication.state.activeScenario and
        ClientApplication.state.activeScenario.game.caseRoomOptions and
        ClientApplication.state.activeScenario.game.caseRoomOptions.doorUnlocked
    then
        return setCaseRoomDoorLocking(false)
    end

    state.isBusy = true

    local playerPedId = cache.ped
    local animation = {
        dict = "anim@heists@keypad@",
        name = "idle_a",
    }
    local sceneCoords = config.caseRoomOptions.door.keypad.sceneCoords

    SetEntityCoords(playerPedId, sceneCoords)
    SetEntityRotation(playerPedId, vector3(0.0, 0.0, sceneCoords.w or 0.0))

    lib.requestAnimDict(animation.dict)
    TaskPlayAnim(playerPedId, animation.dict, animation.name,
        8.0, -8.0, -1, 49, 0, false, false, false)

    local success = Skillbar.show("keypad", {
        pin = ClientApplication.state.activeScenario.game.caseRoomOptions.door.pin,
    })
    ClearPedTasks(playerPedId)
    state.isBusy = false

    if success then
        setCaseRoomDoorLocking(false)
        TriggerServerEvent(_e("server:scenarios:vangelico_robbery:unlockCaseRoomDoor"), {
            lobbyId = ClientApplication.state.lobby.id,
        })
    end
end

local function setupCaseRoomDoor()
    setCaseRoomDoorLocking(true)
    local keypad = config.caseRoomOptions.door.keypad
    local zoneName = "scenario:vangelico:case_room_door_keypad"
    state.zones["case_room_door_keypad"] = zoneName
    Target.addBoxZone(zoneName, {
        name = zoneName,
        coords = keypad.coords,
        size = vector3(.5, .2, .5),
        rotation = keypad.coords.w or 0.0,
        debug = Config.debug,
        options = { {
            icon = "fa-solid fa-credit-card",
            label = locale("vangelico_robbery.use_keypad"),
            distance = 1.5,
            onSelect = function() unlockCaseRoomDoorWithKeypad() end
        }, },
    })

    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario and
            ClientApplication.state.activeScenario.game and
            ClientApplication.state.activeScenario.game.caseRoomOptions and
            not ClientApplication.state.activeScenario.game.caseRoomOptions.doorUnlocked
        do
            Citizen.Wait(1000)
            setCaseRoomDoorLocking(true)
        end
        setCaseRoomDoorLocking(false)
    end)
end

local function unlockCaseDoorWithDrill()
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    local hasPlayerDrill = lib.callback.await(
        _e("server:hasItem"), false, config.caseRoomOptions.safe.drill.itemName, 1
    )
    if not hasPlayerDrill then
        return Utils.notify(locale("vangelico_robbery.no_drill_item"), "error")
    end

    local isDrillAlreadyOnSurface = lib.callback.await(_e("server:heists:vangelico_robbery:isDrillOnSurface"), false, {
        lobbyId = ClientApplication.state.lobby.id,
    })
    if isDrillAlreadyOnSurface then
        return Utils.notify(locale("vangelico_robbery.drill_already_on_surface"), "error")
    end

    TriggerServerEvent(_e("server:heists:vangelico_robbery:placeDrillOnSurface"), {
        lobbyId = ClientApplication.state.lobby.id,
    })

    state.isBusy = true

    local playerPedId = cache.ped
    local drillAnimation = config.caseRoomOptions.safe.drill.animation
    local drillModel = "ch_prop_ch_heist_drill"

    local drillObject = Utils.createObject({
        model = drillModel,
        coords = GetEntityCoords(playerPedId),
        freeze = true,
        isNetwork = true,
    })
    AttachEntityToEntity(drillObject, playerPedId, GetPedBoneIndex(playerPedId, 57005),
        0.14, 0.0, -0.04, -90.0, 100.0, 0.0,
        true, true, false, true, 1, true)

    SetEntityCoords(playerPedId, drillAnimation.coords)
    SetEntityRotation(playerPedId, drillAnimation.rotation, 2, true)

    local animDict, animName = "anim@heists@fleeca_bank@drilling", "drill_straight_start"
    lib.playAnim(playerPedId, animDict, animName, nil, nil, -1, 1)

    while ClientApplication.state.activeScenario and
        ClientApplication.state.activeScenario.game and
        ClientApplication.state.activeScenario.game.caseRoomOptions and
        ClientApplication.state.activeScenario.game.caseRoomOptions.safe and
        not ClientApplication.state.activeScenario.game.caseRoomOptions.safe.opened
    do
        Citizen.Wait(1)
    end

    ClearPedTasks(playerPedId)
    DeleteEntity(drillObject)

    state.isBusy = false
end

local function lootCaseRoomSafe(insideIndex, inside)
    if state.isBusy then
        return Utils.notify(locale("can_not_do_when_busy"), "error")
    end

    state.isBusy = true

    local playerPedId = cache.ped

    local lootAnimation = {
        dict = "anim@heists@ornate_bank@grab_cash",
        name = "grab",
    }

    lib.playAnim(playerPedId, lootAnimation.dict, lootAnimation.name, nil, nil, 2000, 1)
    Citizen.Wait(2000)
    ClearPedTasks(playerPedId)

    local response = lib.callback.await(
        _e("server:scenarios:vangelico_robbery:lootCaseRoomSafe"), false, {
            lobbyId = ClientApplication.state.lobby.id,
            insideIndex = insideIndex,
        })

    if not response then
        Utils.notify(locale("vangelico_robbery.could_not_loot"), "error", 5000)
    else
        Utils.notify(locale("vangelico_robbery.looted_display"), "success", 5000)
    end

    state.isBusy = false
end

local function setupCaseRoomSafe()
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId

    local safe = config.caseRoomOptions.safe

    if isOwner then
        local objectNetIds = {}
        for _, key in pairs({ "body", "door" }) do
            local model = safe[key].model

            local object = Utils.createObject({
                model = model,
                coords = safe[key].coords,
                rotation = safe[key].coords.w or 0.0,
                freeze = true,
                isNetwork = true,
            })

            local networkId = lib.waitFor(function()
                if not NetworkGetEntityIsNetworked(object) then
                    NetworkRegisterEntityAsNetworked(object)
                else
                    local netId = ObjToNet(object)
                    if NetworkDoesNetworkIdExist(netId) then
                        return netId
                    end
                end
            end, nil, false)
            objectNetIds[key] = { netId = networkId, model = model }
        end

        for _, key in pairs({ 1, 2 }) do
            local model = safe.inside[key].model

            local object = Utils.createObject({
                model = model,
                coords = safe.inside[key].coords,
                rotation = safe.inside[key].coords.w or 0.0,
                freeze = true,
                isNetwork = true,
            })

            local networkId = lib.waitFor(function()
                if not NetworkGetEntityIsNetworked(object) then
                    NetworkRegisterEntityAsNetworked(object)
                else
                    local netId = ObjToNet(object)
                    if NetworkDoesNetworkIdExist(netId) then
                        return netId
                    end
                end
            end, nil, false)
            objectNetIds["inside_" .. key] = { netId = networkId, model = model }
        end

        TriggerServerEvent(_e("server:scenarios:vangelico_robbery:registerCaseRoomObjects"), {
            lobbyId = ClientApplication.state.lobby.id,
            objects = objectNetIds,
        })
    end

    local zoneNameCase = "scenario:vangelico:case_room_safe_zone_case"
    state.zones["case_room_safe_zone_case"] = zoneNameCase
    Target.addBoxZone(zoneNameCase, {
        name = zoneNameCase,
        coords = safe.door.coords,
        size = vector3(1.25, .15, 1.5),
        rotation = safe.door.coords.w or 0.0,
        debug = Config.debug,
        options = { {
            icon = "fa-solid fa-hand-fist",
            label = locale("vangelico_robbery.use_drill"),
            distance = 1.5,
            canInteract = function()
                return ClientApplication.state.activeScenario and
                    ClientApplication.state.activeScenario.game and
                    ClientApplication.state.activeScenario.game.caseRoomOptions and
                    ClientApplication.state.activeScenario.game.caseRoomOptions.safe and
                    not ClientApplication.state.activeScenario.game.caseRoomOptions.safe.opened
            end,
            onSelect = function()
                unlockCaseDoorWithDrill()
            end
        } },
    })

    for key, value in pairs({ 1, 2 }) do
        local zoneName = "scenario:vangelico:case_room_safe_zone_inside_" .. key
        state.zones["case_room_safe_zone_inside_" .. key] = zoneName
        local zoneCoords = vector3(
            safe.inside[key].coords.x,
            safe.inside[key].coords.y,
            safe.inside[key].coords.z + 0.1
        )
        Target.addBoxZone(zoneName, {
            name = zoneName,
            coords = zoneCoords,
            size = vector3(0.5, .5, 0.2),
            rotation = safe.inside[key].coords.w or 0.0,
            debug = Config.debug,
            options = { {
                icon = "fa-solid fa-sack-dollar",
                label = locale("vangelico_robbery.loot_safe"),
                distance = 1.5,
                canInteract = function()
                    return ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.game and
                        ClientApplication.state.activeScenario.game.caseRoomOptions and
                        ClientApplication.state.activeScenario.game.caseRoomOptions.safe and
                        ClientApplication.state.activeScenario.game.caseRoomOptions.safe.opened and
                        ClientApplication.state.activeScenario.game.caseRoomOptions.safe.inside[key] and
                        not ClientApplication.state.activeScenario.game.caseRoomOptions.safe.inside[key].looted
                end,
                onSelect = function()
                    lootCaseRoomSafe(key, safe.inside[key])
                end
            } },
        })
    end
end

local function drawNearPropOutlineThread()
    Citizen.CreateThread(function()
        local clonedConfig = lib.table.deepclone(config)

        while ClientApplication.state.activeScenario do
            local wait = 500

            SetEntityDrawOutlineColor(189, 219, 9, 255)
            SetEntityDrawOutlineShader(1)

            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)

            if clonedConfig.paintingSmuggleOptions then
                for index, painting in pairs(clonedConfig.paintingSmuggleOptions.locations) do
                    if not state.smuggleablePaintingModels[index] then
                        goto continue_painting_loop
                    end

                    local distance = #(playerCoords - vector3(painting.objectCoords))
                    if distance < 3.0 then
                        local paintingObject = GetClosestObjectOfType(
                            painting.objectCoords.x,
                            painting.objectCoords.y,
                            painting.objectCoords.z,
                            0.1,
                            state.smuggleablePaintingModels[index].model,
                            false, false, false)
                        if DoesEntityExist(paintingObject) then
                            if not ClientApplication.state.activeScenario.game.paintingSmuggleOptions.locations[index].taken then
                                if not painting.drawed then
                                    painting.drawed = true
                                    SetEntityDrawOutline(paintingObject, true)
                                end
                            elseif painting.drawed then
                                painting.drawed = false
                                SetEntityDrawOutline(paintingObject, false)
                            end
                        end
                    elseif painting.drawed then
                        painting.drawed = false
                        local paintingObject = GetClosestObjectOfType(
                            painting.objectCoords.x,
                            painting.objectCoords.y,
                            painting.objectCoords.z,
                            0.1,
                            state.smuggleablePaintingModels[index].model,
                            false, false, false)
                        if DoesEntityExist(paintingObject) then
                            SetEntityDrawOutline(paintingObject, false)
                        end
                    end

                    ::continue_painting_loop::
                end
            end

            if clonedConfig.lootableDisplayOptions then
                for index, display in pairs(clonedConfig.lootableDisplayOptions.locations) do
                    local isLooted = ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.game.lootableDisplayOptions.locations[index] and
                        ClientApplication.state.activeScenario.game.lootableDisplayOptions.locations[index].looted

                    local model = isLooted and display.newModel or display.originalModel
                    local distance = #(playerCoords - vector3(display.objectCoords))

                    if distance < 3.0 then
                        local displayObject = GetClosestObjectOfType(
                            display.objectCoords.x,
                            display.objectCoords.y,
                            display.objectCoords.z,
                            0.3,
                            model,
                            false, false, false)
                        if DoesEntityExist(displayObject) then
                            if not isLooted then
                                if not display.drawed then
                                    display.drawed = true
                                    SetEntityDrawOutline(displayObject, true)
                                end
                            elseif display.drawed then
                                display.drawed = false
                                SetEntityDrawOutline(displayObject, false)
                            end
                        end
                    elseif display.drawed then
                        display.drawed = false
                        local displayObject = GetClosestObjectOfType(
                            display.objectCoords.x,
                            display.objectCoords.y,
                            display.objectCoords.z,
                            0.3,
                            model,
                            false, false, false)
                        if DoesEntityExist(displayObject) then
                            SetEntityDrawOutline(displayObject, false)
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

function VangelicoRobberyClient.clear()
    for key, _ in pairs(state.blips) do
        if DoesBlipExist(state.blips[key]) then
            RemoveBlip(state.blips[key])
        end
    end
    for _, particle in pairs(state.gasBombParticles) do
        StopParticleFxLooped(particle, 0)
    end
    if state.poisonousGasParticle then
        StopParticleFxLooped(state.poisonousGasParticle, 0)
        state.poisonousGasParticle = nil
    end
    if state.inCutscene then
        onCutsceneFinished()
    end
    if state.robbablePeds then
        for _, ped in pairs(state.robbablePeds) do
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
    end
    if state.zones then
        for _, zone in pairs(state.zones) do
            if zone then
                Target.removeZone(zone)
            end
        end
    end
    if state.swappedModels then
        clearSwappedModels()
    end
    if state.smashableCashRegisterObjects then
        for _, obj in pairs(state.smashableCashRegisterObjects) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
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

function VangelicoRobberyClient.init()
    addBlip(config.storeCenterCoords, SHARED_CONFIG.blips.jewelry, false, true, "store_center")
    addRadiusBlip(config.storeCenterCoords, 50.0, 1, "store_radius")
    addBlip(config.poisonousGasOptions.droneUsageAreaCoords, SHARED_CONFIG.blips.point, true, true, "drone_arena")
    nearDroneUsageAreaThread()
    Utils.notify(locale("vangelico_robbery.go_to_drone_arena"), "info", 5000)
    HeistClient.updateActiveInfoIndex(2)
end

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onScenarioItemUsed"), function(params)
    if not params or not params.itemName then return end

    local canPlayerUse = function(itemName)
        return lib.callback.await(
            _e("server:scenarios:vangelico_robbery:canPlayerUseScenarioItem"), itemName)
    end

    if params.itemName == config.poisonousGasOptions.maskItemName then
        onGasMaskUsed()
    end
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onGasBombDropped"), function(params)
    if not params or not params.zoneIndex or not params.coords then return end
    ClientApplication.state.activeScenario.game.poisonousGasOptions.dropZones[params.zoneIndex].dropped = true

    local ptfxAsset = "core"
    local particleFx = "exp_grd_grenade_smoke"

    local coords = params.coords

    lib.requestNamedPtfxAsset(ptfxAsset)
    UseParticleFxAsset(ptfxAsset)
    local particle = StartParticleFxLoopedAtCoord(
        particleFx,
        coords.x,
        coords.y,
        coords.z + 0.5,
        0.0, 0.0, 0.0,
        1.0,
        false, false, false
    )
    RemoveNamedPtfxAsset(ptfxAsset)
    state.gasBombParticles[params.zoneIndex] = particle

    removeBlipByKey("gas_drop_zone_" .. params.zoneIndex)
    HeistClient.updateActiveInfoProgress(params.droppedCount, params.totalDrops)

    if not params.allDropped then
        Utils.notify(locale("vangelico_robbery.gas_grenade_dropped"), "info", 5000)
        return
    end

    ClientApplication.state.activeScenario.game.poisonousGasOptions.allDropped = true
    Utils.notify(locale("vangelico_robbery.all_gas_dropped"), "success")
    HeistClient.updateActiveInfoIndex(nil)

    if params.droneDriver == cache.serverId then
        DroneClient:clear()
    end

    Citizen.CreateThread(function()
        playCutscene("JH_2A_MCS_1", vector3(-637.9547, -242.1942, 38.1246), 17000)
        if ClientApplication.state.lobby and ClientApplication.state.lobby.id == params.lobbyId and
            ClientApplication.state.lobby.owner == cache.serverId
        then
            TriggerServerEvent(_e("server:scenarios:vangelico_robbery:setActivePoisonousGas"),
                { lobbyId = ClientApplication.state.lobby.id }
            )
        end
    end)
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onPoisonousGasActivated"), function(params)
    if state.poisonousGasParticle then return end

    local isInLobby = ClientApplication.state.lobby and ClientApplication.state.lobby.id == params.lobbyId

    poisonousGasDamageThread()
    frontDoorLockingThread()

    if not isInLobby then return end

    ClientApplication.state.activeScenario.game.poisonousGasOptions.isGasActive = true
    Utils.notify(locale("vangelico_robbery.gas_activated"), "warning", 5000)
    Utils.notify(locale("vangelico_robbery.front_doors_locked"), "warning", 5000)
    HeistClient.updateActiveInfoIndex(6)

    findObjectsAndDeleteThread()
    spawnRobbablePeds()
    setupLootableDisplays()
    setupSmashableCases()
    setupSmashableCashRegisters()
    setupPaintings()
    setupCaseRoomDoor()
    setupCaseRoomSafe()
    drawNearPropOutlineThread()
    distanceCheckingForFinishThread()
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onPoisonousGasDeactivated"), function()
    state.isPoisonousGasActive = false
    if state.poisonousGasParticle then
        StopParticleFxLooped(state.poisonousGasParticle, 0)
        state.poisonousGasParticle = nil
    end
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onBombPlantedAtFrontDoor"), function(params)
    local plantedBomb = params.plantedBomb

    if ClientApplication.state.activeScenario then
        ClientApplication.state.activeScenario.game.entranceDoorOptions.bombPlanted = true
    end

    plantBombOnDoor(plantedBomb)

    if params.planter == cache.serverId then
        TriggerServerEvent(_e("server:scenarios:vangelico_robbery:onPlantedDoorBombExploded"), params.lobbyId)
        triggerAlert(config.storeCenterCoords)
    end
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onPlantedFrontDoorBombExploded"), function(params)
    state.doorLockingThread = false
    freezeEntranceDoors(false)

    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.entranceDoorOptions.bombExploded = true
    Utils.notify(locale("vangelico_robbery.front_door_breached"), "success", 5000)

    HeistClient.updateActiveInfoIndex(7)

    Citizen.Wait(500)
    for key, value in pairs(state.robbablePeds) do
        setRobbablePedAnim(value)
    end
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:setFalseDoorLockingThread"), function()
    state.doorLockingThread = false
end)

---@param params { displayIndex: number }
RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onDisplayLooted"), function(params)
    if not params or not params.displayIndex then return end
    if not ClientApplication.state.activeScenario then return end
    ClientApplication.state.activeScenario.game.lootableDisplayOptions.locations[params.displayIndex].looted = true

    local lootableDisplay = config.lootableDisplayOptions.locations[params.displayIndex]
    if not lootableDisplay then return end

    local originalObject = GetClosestObjectOfType(
        lootableDisplay.objectCoords.x,
        lootableDisplay.objectCoords.y,
        lootableDisplay.objectCoords.z,
        0.3, lootableDisplay.originalModel,
        false, false, false
    )
    if not DoesEntityExist(originalObject) then return end
    if not lootableDisplay.newModel then
        SetEntityAsMissionEntity(originalObject, true, true)
        DeleteEntity(originalObject)
        return
    end

    SetEntityCoordsNoOffset(originalObject,
        lootableDisplay.objectCoords.x,
        lootableDisplay.objectCoords.y,
        lootableDisplay.objectCoords.z - 0.25,
        false, false, true
    )
    CreateModelSwap(lootableDisplay.objectCoords.x,
        lootableDisplay.objectCoords.y,
        lootableDisplay.objectCoords.z, 0.5,
        lootableDisplay.originalModel, lootableDisplay.newModel, true)

    state.swappedModels[params.displayIndex] = {
        coords = lootableDisplay.objectCoords,
        originalModel = lootableDisplay.originalModel,
        newModel = lootableDisplay.newModel,
        offsetZ = -0.25,
    }
end)

---@param params { caseIndex: number }
RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onCaseSmash"), function(params)
    if not params or not params.caseIndex then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.smashableCaseOptions.locations[params.caseIndex].smashed = true

    local smashableCase = config.smashableCaseOptions.locations[params.caseIndex]
    if not smashableCase then return end

    CreateModelSwap(smashableCase.objectCoords.x,
        smashableCase.objectCoords.y,
        smashableCase.objectCoords.z, 0.3,
        smashableCase.originalModel, smashableCase.newModel, true)

    state.swappedModels[params.caseIndex] = {
        coords = smashableCase.objectCoords,
        originalModel = smashableCase.originalModel,
        newModel = smashableCase.newModel,
    }

    for i = 1, 5 do
        PlaySoundFromCoord(-1, "GLASS_SMASH",
            smashableCase.objectCoords.x, smashableCase.objectCoords.y, smashableCase.objectCoords.z,
            nil, false, 0.0, false)
    end
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onCashRegisterSmash"), function(params)
    if not params or not params.registerIndex then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.smashableCashRegisterOptions.locations[params.registerIndex].smashed = true

    local cashRegister = config.smashableCashRegisterOptions.locations[params.registerIndex]
    if not cashRegister then return end

    if cashRegister.newModel then
        CreateModelSwap(cashRegister.objectCoords.x,
            cashRegister.objectCoords.y,
            cashRegister.objectCoords.z, 0.3,
            cashRegister.originalModel, cashRegister.newModel, true)

        state.swappedModels["cash_register_" .. params.registerIndex] = {
            coords = cashRegister.objectCoords,
            originalModel = cashRegister.originalModel,
            newModel = cashRegister.newModel,
        }
    end
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onPaintingSmuggled"), function(params)
    if not params or not params.paintingIndex then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.paintingSmuggleOptions.locations[params.paintingIndex].taken = true
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onPaintingObjectRegistered"), function(params)
    if not params or not params.index or not params.netId or not params.model then return end

    state.smuggleablePaintingModels[params.index] = {
        netId = params.netId,
        model = params.model,
    }
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onCaseRoomDoorUnlocked"), function(params)
    if not params or not params.lobbyId then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.caseRoomOptions.doorUnlocked = true
    Utils.notify(locale("vangelico_robbery.case_room_door_unlocked"), "success", 5000)

    setCaseRoomDoorLocking(false)

    Target.removeZone(state.zones["case_room_door_keypad"])
    state.zones["case_room_door_keypad"] = nil
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onCaseRoomObjectsRegistered"), function(params)
    state.caseRoomObjects = params.objects
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onCaseSafeOpened"), function(params)
    if not params or not params.lobbyId then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.caseRoomOptions.safe.opened = true
    Utils.notify(locale("vangelico_robbery.case_room_safe_opened"), "success", 5000)

    Target.removeZone(state.zones["case_room_safe_zone_case"])
    state.zones["case_room_safe_zone_case"] = nil

    RequestAmbientAudioBank("SAFE_CRACK", false)
    PlaySoundFrontend(0, "SAFE_DOOR_OPEN", "SAFE_CRACK_SOUNDSET", true)
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onCaseSafeLooted"), function(params)
    if not params or not params.insideIndex then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.caseRoomOptions.safe.inside[params.insideIndex].looted = true

    local zoneName = state.zones["case_room_safe_zone_inside_" .. params.insideIndex]
    Target.removeZone(zoneName)
    state.zones["case_room_safe_zone_inside_" .. params.insideIndex] = nil
end)

RegisterNetEvent(_e("client:scenarios:vangelico_robbery:onPedRobbed"), function(params)
    if not params or not params.pedIndex then return end
    if not ClientApplication.state.activeScenario then return end

    ClientApplication.state.activeScenario.game.robbablePedOptions.peds[params.pedIndex].robbed = true
end)
