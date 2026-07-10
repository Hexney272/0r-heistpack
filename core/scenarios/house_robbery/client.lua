local lib                   = lib
local Utils                 = require("modules.utils.client")
local Target                = require("modules.target.client")

local config                = lib.load("config.scenarios.house_robbery")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

-- Shared modules
local InteriorManagerClient = require("core.scenarios._shared.client.interior_manager")
local CarrySystemClient     = require("core.scenarios._shared.client.carry_system")
local LootManagerClient     = require("core.scenarios._shared.client.loot_manager")

local state                 = {
    isBusy = false,
    blips = {},
    zones = {},
}

local managers              = {
    interior = nil,
    carry = nil,
    loot = nil,
}

local function __init_state__()
    for k in pairs(state) do
        if type(state[k]) == "table" then
            state[k] = {}
        else
            state[k] = false
        end
    end

    managers.interior = nil
    managers.carry = nil
    managers.loot = nil
end

HouseRobberyClient = {}

local function setNoiseValue(value)
    ClientApplication:sendReactMessage("ui:setNoiseValue", value)
end

local function triggerAlert(coords)
    Utils.triggerPoliceAlert("house_robbery", locale("house_robbery.police_alert"), coords)
    setNoiseValue(100)
end

---@param index number
---@return HouseRobberyInterior|nil
local function getInteriorByIndex(index)
    if not index then return nil end
    return config.interiors[index]
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

local function deletePlayerHoldingLoot()
    if managers.carry then
        managers.carry:detachObject()
    end
end

---@param interior HouseRobberyInterior
local function hackLockedDoor(interior)
    state.isBusy = true

    local response = HackingDeviceClient:show()
    if not response then
        state.isBusy = false
        return
    end

    TriggerServerEvent(_e("server:scenarios:house_robbery:onHouseDoorUnlocked"),
        { lobbyId = ClientApplication.state.lobby.id })

    state.isBusy = false
end

---@param interior HouseRobberyInterior
local function setupEntranceHouseTarget(interior)
    local zoneName = "scenario:house_robbery:entrance_zone"
    state.zones["house_entrance"] = zoneName

    Target.addBoxZone(zoneName, {
        name = zoneName,
        coords = interior.locations.entrance,
        size = vector3(1.5, 1.5, 2.0),
        rotation = interior.locations.entrance.w or 0.0,
        debug = Config.debug,
        options = {
            {
                label = locale("house_robbery.enter_house"),
                icon = "fas fa-door-open",
                distance = 2.0,
                onSelect = function()
                    HouseRobberyClient.getInsideInterior(interior.locations.inside)
                end,
                canInteract = function()
                    return ClientApplication.state.activeScenario.game.interior.unlocked
                end,
            },
            {
                label = locale("house_robbery.hack_door"),
                icon = "fas fa-laptop-code",
                distance = 2.0,
                onSelect = function()
                    local hasHackingDevice = lib.callback.await(
                        _e("server:hasItem"), false, config.hackingDeviceOptions.itemName, 1)

                    if not hasHackingDevice then
                        return Utils.notify(locale("house_robbery.no_hacking_device"), "error")
                    end

                    hackLockedDoor(interior)
                end,
                canInteract = function()
                    return not state.isBusy and
                        not ClientApplication.state.activeScenario.game.interior.unlocked
                end,
            },
        },
    })
end

---@param interior HouseRobberyInterior
local function setupExitHouseTarget(interior)
    local zoneName = "scenario:house_robbery:exit_zone"
    state.zones["house_exit"] = zoneName

    Target.addBoxZone(zoneName, {
        name = zoneName,
        coords = interior.locations.exit,
        size = vector3(1.5, 1.5, 2.0),
        rotation = interior.locations.exit.w or 0.0,
        debug = Config.debug,
        options = { {
            label = locale("house_robbery.exit_house"),
            icon = "fas fa-door-open",
            distance = 2.0,
            onSelect = function()
                HouseRobberyClient.getOutsideInterior(interior.locations.entrance)
            end,
        } },
    })
end

---@param loot LootPoint
---@param lootIndex number
local function interactionWithLoot(loot, lootIndex)
    state.isBusy = true

    local animationOption = config.animations[loot.interaction]
    if animationOption then
        local animationDuration = animationOption.duration or 2000
        lib.playAnim(cache.ped, animationOption.dict, animationOption.name,
            8.0, -8.0, animationDuration, 1)

        Utils.progressBar({
            duration = animationDuration,
            label = locale("house_robbery.looting"),
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

    if loot.interaction == "carry" then
        local response = lib.callback.await(
            _e("server:scenarios:house_robbery:carryLootProp"),
            false,
            { lobbyId = ClientApplication.state.lobby.id, lootIndex = lootIndex }
        )
        if response.success then
            Utils.notify(locale("house_robbery.carrying_loot"), "success")
        else
            Utils.notify(locale("house_robbery.carry_failed"), "error")
            if response.message then
                Utils.notify(response.message, "error", 5000)
            end
        end
    else
        local response = lib.callback.await(
            _e("server:scenarios:house_robbery:lootProp"),
            false,
            { lobbyId = ClientApplication.state.lobby.id, lootIndex = lootIndex }
        )

        if response.success then
            Utils.notify(locale("house_robbery.looted_items"), "success")
        else
            Utils.notify(locale("house_robbery.loot_failed"), "error")
            if response.message then
                Utils.notify(response.message, "error", 5000)
            end
        end

        state.isBusy = false
    end
end

local function setupInteriorLoots()
    local interior = ClientApplication.state.activeScenario.game.interior
    if not interior or not interior.loots then return end

    -- Initialize loot manager with interior loots and Target system
    managers.loot = LootManagerClient.new({
        loots = interior.loots,
        Target = Target,
    })

    -- Spawn loot props
    managers.loot:spawnLoots()

    -- Setup target interactions
    managers.loot:setupTargets({
        getLootLabel = function(loot, lootIndex)
            return locale("house_robbery." .. (loot.interaction or (loot.zone and "search" or "grab")) .. "_loot")
        end,
        canInteract = function(loot, lootIndex)
            return not state.isBusy and not loot.busy and not loot.looted
        end,
        onSelect = function(loot, lootIndex)
            interactionWithLoot(loot, lootIndex)
        end,
        zonePrefix = "scenario:house_robbery",
        debug = Config.debug,
    })

    -- Start marker and delete threads
    managers.loot:startMarkerThread(5.0, function()
        return managers.interior and managers.interior:isPlayerInside() or Config.debug
    end)

    local excludedObject = managers.carry and managers.carry:getHoldingObject() or nil
    managers.loot:startDeleteThread(function()
        return managers.interior and managers.interior:isPlayerInside() or Config.debug
    end, excludedObject)
end

local function setupGlobalTargetsOnVehicle()
    local scenarioVehicles = {}

    local activeScenario = ClientApplication.state.activeScenario
    if not activeScenario then return end

    if activeScenario.game.vehicles and #activeScenario.game.vehicles > 0 then
        for _, value in pairs(activeScenario.game.vehicles) do
            table.insert(scenarioVehicles, value.vehicleNetId)
        end
    end

    if #scenarioVehicles > 0 then
        Target.addGlobalVehicle({
            {
                name = "scenario:house_robbery:place_loot",
                label = locale("house_robbery.place_loot_in_vehicle"),
                icon = "fas fa-box-open",
                onSelect = function(data)
                    if not ClientApplication.state.lobby then return false end
                    if not ClientApplication.state.activeScenario then return false end
                    if not managers.carry or not managers.carry:isHolding() then return false end

                    state.isBusy = false

                    local vehicleNetId = VehToNet(type(data) == "table"
                        and data.entity
                        or data)

                    TriggerServerEvent(
                        _e("server:scenarios:house_robbery:placeLootInVehicle"), {
                            lobbyId = ClientApplication.state.lobby.id,
                            lootIndex = managers.carry:getHoldingData().lootIndex,
                            vehicleNetId = vehicleNetId
                        }
                    )

                    deletePlayerHoldingLoot()
                end,
                canInteract = function(entity, distance)
                    if not managers.carry or not managers.carry:isHolding() then return false end

                    local isVehicle = IsEntityAVehicle(entity)
                    if not isVehicle then return false end
                    if not NetworkGetEntityIsNetworked(entity) then return false end
                    local vehicleNetId = VehToNet(entity)
                    return lib.table.contains(scenarioVehicles, vehicleNetId) and distance < 3.0
                end,
            },
        })
    end
end

local function distanceCheckingForFinishThread()
    local isOwner = ClientApplication.state.lobby and ClientApplication.state.lobby.owner == cache.serverId
    if not isOwner then return end

    Citizen.CreateThread(function()
        local interiorEntrance = ClientApplication.state.activeScenario.game.interior.locations.entrance
        local maxDistance = config.requiredDistanceForFinish
        while ClientApplication.state.activeScenario do
            if not (managers.interior and managers.interior:isPlayerInside()) then
                local playerCoords = GetEntityCoords(cache.ped)
                local distance = #(playerCoords - vector3(interiorEntrance))
                if distance > maxDistance then
                    TriggerServerEvent(_e("server:heist:setHeistCompleted"),
                        { lobbyId = ClientApplication.state.lobby.id, reason = "moved_too_far" }
                    )
                    Utils.notify(locale("moved_too_far"), "info", 5000)
                    HeistClient.updateActiveInfoIndex(5)
                    return
                end
            end
            Citizen.Wait(1000)
        end
    end)
end

local function threadNoiseCalc()
    local alertCounter = 0
    Citizen.CreateThread(function()
        local interiorId = ClientApplication.state.activeScenario.game.interiorId
        local interior = getInteriorByIndex(interiorId)
        if not interior then return end

        while managers.interior:isPlayerInside() do
            local playerPed = cache.ped
            local crouchAnim = GetHashKey("move_ped_crouched")
            local currentAnim = GetPedMovementClipset(playerPed)

            if (currentAnim == crouchAnim) then
                if IsPedJumping(playerPed) then
                    alertCounter = alertCounter + 2
                    setNoiseValue(40)
                elseif IsPedRunning(playerPed) then
                    alertCounter = alertCounter + 2
                    setNoiseValue(20)
                else
                    setNoiseValue(5)
                end

                if alertCounter >= 30 then
                    triggerAlert(interior.locations.entrance)
                    break
                end
            else
                if IsPedJumping(playerPed) then
                    alertCounter = alertCounter + 3
                    setNoiseValue(80)
                elseif IsPedRunning(playerPed) then
                    alertCounter = alertCounter + 2
                    setNoiseValue(60)
                elseif IsPedWalking(playerPed) then
                    alertCounter = alertCounter + 1
                    setNoiseValue(30)
                else
                    setNoiseValue(0)
                end

                if alertCounter >= 30 then
                    triggerAlert(interior.locations.entrance)
                    break
                end
            end

            Citizen.Wait(1000)
        end
    end)
end

function HouseRobberyClient.getInsideInterior(coords)
    if not managers.interior then return end

    local holdingObjectNetId = managers.carry and managers.carry:getHoldingObjectNetId() or nil

    managers.interior:enter(function(inside)
        return lib.callback.await(_e("server:scenarios:house_robbery:setPlayerInside"),
            false, { lobbyId = ClientApplication.state.lobby.id, holdingObjectNetId = holdingObjectNetId })
    end, {})
end

function HouseRobberyClient.getOutsideInterior(coords)
    if not managers.interior then return end

    local holdingObjectNetId = managers.carry and managers.carry:getHoldingObjectNetId() or nil

    managers.interior:exit(function(inside)
        return lib.callback.await(_e("server:scenarios:house_robbery:setPlayerOutside"),
            false, { lobbyId = ClientApplication.state.lobby.id, holdingObjectNetId = holdingObjectNetId })
    end, {})
end

function HouseRobberyClient.clear()
    setNoiseValue(-1)
    Target.removeGlobalVehicle("scenario:house_robbery:place_loot", locale("house_robbery.place_loot_in_vehicle"))

    for key, blip in pairs(state.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    -- Clear only non-loot target zones (entrance/exit zones)
    for zoneKey, zoneName in pairs(state.zones) do
        if zoneName and not string.match(zoneKey, "interior_loot_") then
            Target.removeZone(zoneName)
        end
    end

    -- Clear shared modules (managers.loot will handle its own target zones)
    if managers.loot then managers.loot:clear() end
    if managers.carry then managers.carry:clear() end
    if managers.interior then managers.interior:clear() end

    __init_state__()
end

function HouseRobberyClient.init()
    local interiorId = ClientApplication.state.activeScenario.game.interiorId
    local interior = getInteriorByIndex(interiorId)

    if not interior then
        return Utils.notify(locale("house_robbery.interior_not_found", interiorId), "error")
    end

    -- Initialize interior manager
    managers.interior = InteriorManagerClient.new({})

    -- Initialize carry system
    managers.carry = CarrySystemClient.new({
        animDict = config.animations.carrying.dict,
        animName = config.animations.carrying.name,
    })

    addBlip(interior.locations.entrance, SHARED_CONFIG.blips.house, true, true, "house_blip")
    Utils.notify(locale("house_robbery.go_to_entrance"), "info")
    HeistClient.updateActiveInfoIndex(2)

    setupEntranceHouseTarget(interior)
    setupExitHouseTarget(interior)

    setupInteriorLoots()
    setupGlobalTargetsOnVehicle()
end

RegisterNetEvent(_e("client:scenarios:house_robbery:onPlayerInsideInterior"), function()
    local houseBlip = state.blips["house_blip"]
    if DoesBlipExist(houseBlip) then
        SetBlipDisplay(houseBlip, 0)
    end

    DoScreenFadeIn(1000)
    while not IsScreenFadedIn() do Citizen.Wait(100) end

    Utils.notify(locale("house_robbery.inside_house"), "info")
    HeistClient.updateActiveInfoIndex(3)

    setNoiseValue(0)
    threadNoiseCalc()

    if managers.carry and managers.carry:isHolding() then
        managers.carry:replayAnimation()
    end
end)

RegisterNetEvent(_e("client:scenarios:house_robbery:onPlayerOutsideInterior"), function()
    local houseBlip = state.blips["house_blip"]
    if DoesBlipExist(houseBlip) then
        SetBlipDisplay(houseBlip, 2)
    end

    DoScreenFadeIn(1000)
    while not IsScreenFadedIn() do Citizen.Wait(100) end

    Utils.notify(locale("house_robbery.outside_house"), "info")
    HeistClient.updateActiveInfoIndex(4)
    setNoiseValue(-1)

    if managers.carry and managers.carry:isHolding() then
        managers.carry:replayAnimation()
    end
end)

RegisterNetEvent(_e("client:scenarios:house_robbery:onHouseDoorUnlocked"), function(playerId)
    Utils.notify(locale("house_robbery.door_unlocked"), "success")
    Utils.notify(locale("house_robbery.enter_house"), "success")

    ClientApplication.state.activeScenario.game.interior.unlocked = true

    distanceCheckingForFinishThread()
    HackingDeviceClient:clear()
end)

RegisterNetEvent(_e("client:scenarios:house_robbery:onLootPropUpdated"), function(params)
    local lootIndex = params.lootIndex
    local looted = params.looted

    if not ClientApplication.state.activeScenario then return end

    local interior = ClientApplication.state.activeScenario.game.interior
    if not interior or not interior.loots then return end

    local loot = interior.loots[lootIndex]
    if not loot then return end

    if params.looted then
        loot.looted = looted
    end

    managers.loot:markLootLooted(lootIndex, params.deleteProp)
end)

RegisterNetEvent(_e("client:scenarios:house_robbery:onCarryLootProp"), function(params)
    local lootIndex = params.lootIndex
    local holdingBy = params.holdingBy

    if not ClientApplication.state.activeScenario then return end

    local interior = ClientApplication.state.activeScenario.game.interior
    if not interior or not interior.loots then return end

    local loot = interior.loots[lootIndex]
    if not loot then return end

    loot.busy = true

    -- Delete spawned prop if created
    if loot.prop.create and managers.loot then
        local prop = managers.loot:getSpawnedProp(lootIndex)
        if prop and DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    else
        -- Delete default world prop
        local prop = GetClosestObjectOfType(
            loot.prop.coords.x, loot.prop.coords.y, loot.prop.coords.z, 0.3,
            loot.prop.model,
            false, false, false
        )
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)
            DeleteEntity(prop)
        end
    end

    -- Only current player carries the object
    if holdingBy == cache.serverId and managers.carry then
        local offset = loot.positions.onHolding.offset
        local rotationAttach = loot.positions.onHolding.rotation
        local bone = loot.positions.onHolding.boneId or 28422

        managers.carry:attachObject(
            loot.prop.model,
            loot.prop.coords,
            {
                offset = offset,
                rotation = rotationAttach,
                boneId = bone,
                lootIndex = lootIndex, -- Store lootIndex in attachConfig
            }
        )
    end
end)

lib.callback.register(_e("client:scenarios:house_robbery:spawnLootInVehicle"), function(params)
    local interiorId = params.interiorId
    local lootIndex = params.lootIndex
    local vehicleNetId = params.vehicleNetId
    local vehicle = NetToVeh(vehicleNetId)

    local lootInfo = config.interiors[interiorId].loots[lootIndex]
    if not lootInfo or not lootInfo.positions.onVehicle then
        return nil
    end

    if DoesEntityExist(vehicle) then
        local offset = lootInfo.positions.onVehicle.offset
        local rotation = lootInfo.positions.onVehicle.rotation
        local boneName = lootInfo.positions.onVehicle.boneName or "chassis"
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        local bone = boneIndex ~= -1 and boneIndex or 0

        local prop = Utils.createObject({
            model = lootInfo.prop.model,
            coords = GetEntityCoords(vehicle),
            rotation = 0.0,
            freeze = true,
            isNetwork = true,
        })

        if not prop or not DoesEntityExist(prop) then
            return nil
        end

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

RegisterNetEvent(_e("client:scenarios:house_robbery:onLootPlacedInVehicle"), function(params)
    local lootIndex = params.lootIndex

    if not ClientApplication.state.activeScenario then return end

    local interior = ClientApplication.state.activeScenario.game.interior
    if not interior or not interior.loots then return end

    local loot = interior.loots[lootIndex]
    if not loot then return end

    loot.busy = false
    loot.looted = true
end)
