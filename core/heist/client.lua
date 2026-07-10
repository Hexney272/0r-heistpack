local lib = lib
local Utils = require("modules.utils.client")
local Target = require("modules.target.client")
local ScenarioRegistry = require("core.heist.scenario_registry")
local Exports = require("modules.exports.client")

local config = lib.load("config.heist")

HeistClient = {}

local state = {
    employers = {},
    game = {},
    isOutfitChanging = false,
}

local function __init_state_game__()
    state.game = {
        scenarioPoints = {},
        scenarioBlips = {},
        givedVehicleKeys = {},
        completionTargetEmployer = nil,
    }
end

---@param self CPoint
local function onEnterSpawnScenarioVehiclePoint(self, triggerInitAfterAllSpawned)
    local meta = self.meta

    local entityModel = type(meta.model) == "string" and GetHashKey(meta.model) or meta.model
    if not IsModelValid(entityModel) then
        Utils.notify(("Invalid vehicle model: %s"):format(tostring(meta.model)), "error", 5000)
        self:remove()
        return
    end

    local employerIndex = meta.employerIndex
    if not employerIndex or not config.employers[employerIndex] then
        Utils.notify(("Invalid employer index for vehicle spawn point: %s")
            :format(tostring(employerIndex)), "error", 5000)
        self:remove()
        return
    end

    local vehicleSpawnPoints = config.employers[employerIndex].vehicleSpawnPoints
    if not vehicleSpawnPoints or #vehicleSpawnPoints == 0 then
        vehicleSpawnPoints = { self.coords }
    end

    -- Spawn noktalarını kontrol ederek boş bir nokta aranıyor
    local spawnPoint = nil
    for i = 1, #vehicleSpawnPoints do
        local testPoint = vehicleSpawnPoints[i]
        local vehicle, _ = lib.getClosestVehicle(vector3(testPoint), 3.0, false)

        if not vehicle then
            spawnPoint = testPoint
            break
        end
    end

    if not spawnPoint then
        spawnPoint = vehicleSpawnPoints[#vehicleSpawnPoints]
    end

    lib.requestModel(entityModel)
    local vehicleEntity = CreateVehicle(entityModel,
        spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w or 0.0,
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

    SetEntityCoords(vehicleEntity, spawnPoint.x, spawnPoint.y, spawnPoint.z,
        false, false, false, false)
    SetEntityRotation(vehicleEntity, 0.0, 0.0, spawnPoint.w or 0.0, 2, false)
    SetModelAsNoLongerNeeded(entityModel)

    Utils.setFuel(vehicleEntity, 100.0)

    self:remove()

    state.game.scenarioPoints["scenario_vehicle_spawn_" .. meta.vehicleIndex] = nil

    if state.game.scenarioBlips["scenario_vehicle_spawn_" .. meta.vehicleIndex] then
        RemoveBlip(state.game.scenarioBlips["scenario_vehicle_spawn_" .. meta.vehicleIndex])
    end

    lib.callback.await(_e("server:heist:onScenarioVehicleSpawned"),
        false,
        ClientApplication.state.lobby.id,
        {
            vehicleIndex = meta.vehicleIndex,
            vehicleNetId = vehicleNetId,
            model = meta.model,
            spawned = true,
            triggerInitAfterAllSpawned = triggerInitAfterAllSpawned
        }
    )
end

local function completeHeistScenario()
    local response = lib.callback.await(_e("server:heist:completeScenario"), false, {
        lobbyId = ClientApplication.state.lobby.id
    })

    if not response then
        Utils.notify(locale("scenario.completion_failed"), "error")
        return false
    end

    if not response.success then
        Utils.notify(response.message, "error")
        return false
    end

    Utils.notify(locale("scenario.completed_successfully"), "success")
    return true
end

local function setupEmployersTargets()
    for _, employer in ipairs(state.employers) do
        if not employer.ped then goto continue end
        if not DoesEntityExist(employer.ped) then goto continue end

        Target.addLocalEntity(employer.ped, {
            {
                label = locale("heist.open_heist_menu"),
                icon = "fa-solid fa-bars",
                distance = 2.5,
                onSelect = function()
                    ClientApplication:openMenu(true)
                end,
            },
            {
                label = locale("heist.change_outfit"),
                icon = "fa-solid fa-tshirt",
                distance = 2.5,
                canInteract = function(entity, distance)
                    return Config.jobClothingOptions and Config.jobClothingOptions.enabled
                end,
                onSelect = function()
                    local value = not HeistClient.isOutfitChanging
                    HeistClient.isOutfitChanging = value
                    ClientApplication:setOutfit(value and (Config.jobClothingOptions.outfit or {}) or false)
                end,
            }
        })

        ::continue::
    end
end

function HeistClient.isPlayerNearEmployer()
    if not Config.heistMenu.requiredMinDistance or Config.heistMenu.requiredMinDistance <= 0.1 then
        return true
    end

    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    for _, employer in ipairs(state.employers) do
        if employer.ped then
            local employerCoords = GetEntityCoords(employer.ped)
            if #(playerCoords - vector3(employerCoords.x, employerCoords.y, employerCoords.z)) <= Config.heistMenu.requiredMinDistance then
                return true
            end
        end
    end
    return false
end

function HeistClient.getNearestEmployer()
    local nearestEmployer = nil
    local nearestDistance = math.huge

    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    for _, employer in ipairs(state.employers) do
        if employer.ped then
            local employerCoords = employer.coords
            local distance = #(playerCoords - vector3(employerCoords))
            if distance < nearestDistance then
                nearestDistance = distance
                nearestEmployer = employer
            end
        end
    end

    return nearestEmployer, nearestDistance
end

function HeistClient.removeGivedVehicleKeys()
    for _, value in pairs(state.game.givedVehicleKeys) do
        Utils.removeVehicleKey(value.plate)
    end
    state.game.givedVehicleKeys = {}
end

function HeistClient.giveVehicleKey(plate, vehicle)
    if not plate or not vehicle then return end

    local keyData = {
        plate = plate,
        netId = VehToNet(vehicle),
    }

    table.insert(state.game.givedVehicleKeys, keyData)
    Utils.giveVehicleKey(plate, vehicle)
end

function HeistClient.setupSpawnVehiclePoints(vehicles, triggerInitAfterAllSpawned)
    for vehicleIndex, vehicleInfo in ipairs(vehicles) do
        if ClientApplication.state.lobby.owner == cache.serverId then
            local nearestEmployer = HeistClient.getNearestEmployer()
            if nearestEmployer then
                local vehicleSpawnPoints = config.employers[nearestEmployer.index].vehicleSpawnPoints
                local pointCoords = vehicleSpawnPoints[((vehicleIndex - 1) % #vehicleSpawnPoints) + 1]
                local point = lib.points.new({
                    coords = pointCoords,
                    distance = 50.0,
                    meta = {
                        model = vehicleInfo.model,
                        employerIndex = nearestEmployer.index,
                        vehicleIndex = vehicleIndex,
                    },
                    onEnter = function(self)
                        onEnterSpawnScenarioVehiclePoint(self, triggerInitAfterAllSpawned ~= false)
                    end,
                })
                state.game.scenarioPoints["scenario_vehicle_spawn_" .. vehicleIndex] = point
                state.game.scenarioBlips["scenario_vehicle_spawn_" .. vehicleIndex] =
                    Utils.addBlip(pointCoords, config.blips.vehicle, true)
            end
        end
    end
end

function HeistClient.clear()
    if state.game.scenarioPoints then
        for _, point in pairs(state.game.scenarioPoints) do
            if point and point.remove then
                point:remove()
            end
        end
        state.game.scenarioPoints = {}
    end

    if state.game.scenarioBlips then
        for _, blip in pairs(state.game.scenarioBlips) do
            if blip then
                RemoveBlip(blip)
            end
        end
        state.game.scenarioBlips = {}
    end

    if state.game.givedVehicleKeys then
        HeistClient.removeGivedVehicleKeys()
    end

    if state.game.completionTargetEmployer then
        Target.removeLocalEntity(state.game.completionTargetEmployer,
            "complete_heist_scenario", locale("heist.complete_heist_scenario"))
        state.game.completionTargetEmployer = nil
    end

    __init_state_game__()
end

function HeistClient.onUnload()
    if state.employers then
        for _, employer in ipairs(state.employers) do
            if employer.blip then
                RemoveBlip(employer.blip)
            end
            if employer.ped then
                DeletePed(employer.ped)
            end
        end
        state.employers = {}
    end

    HeistClient.clear()
    ScenarioRegistry.clearAll("client")
end

function HeistClient.load()
    HeistClient.spawnEmployers()

    -- # TODO : Load active scenario
end

function HeistClient.initActiveScenario(activeScenarioKey)
    if not activeScenarioKey then return end

    local activeScenarioKey = ClientApplication.state.activeScenario and ClientApplication.state.activeScenario.key

    if not activeScenarioKey then return end

    ScenarioRegistry.init(activeScenarioKey, "client")
end

function HeistClient.stopScenario(scenarioKey)
    if not scenarioKey then return end

    ScenarioRegistry.clear(scenarioKey, "client")
end

function HeistClient.onScenarioStarted()
    local activeScenario = ClientApplication.state.activeScenario
    if not activeScenario then return end

    if activeScenario.game.vehicles and #activeScenario.game.vehicles > 0 then
        HeistClient.setupSpawnVehiclePoints(activeScenario.game.vehicles)
    else
        HeistClient.initActiveScenario(activeScenario.key)
    end

    Utils.notify(locale("scenario.started"), "success")

    local success, err = pcall(Exports.onScenarioStarted, cache.serverId, activeScenario)
    if not success then
        print(("^1[ERROR] Failed to trigger onScenarioStarted export: %s^0"):format(err))
    end
end

function HeistClient.getHeistScenarios(fetchCooldown)
    local configScenarios = lib.table.deepclone(config.heistScenarios or {})
    local activeHeistScenarios = {}
    for scenarioKey, scenario in pairs(configScenarios) do
        if scenario.isActive ~= false then
            activeHeistScenarios[scenarioKey] = scenario
        end
    end

    if fetchCooldown then
        local response = lib.callback.await(_e("server:heist:getScenarioCooldowns"), false)
        local heistCooldowns = response.cooldowns or {}
        local currentTime = response.time

        for scenarioKey, scenario in pairs(activeHeistScenarios) do
            local cooldown = heistCooldowns[scenarioKey]
            if cooldown and cooldown > currentTime then
                scenario.cooldownEndTime = cooldown
            else
                scenario.cooldownEndTime = nil
            end
        end
        return activeHeistScenarios
    end

    return activeHeistScenarios
end

function HeistClient.spawnEmployers()
    for index, employer in ipairs(config.employers) do
        local ped, blip

        ped = Utils.createPed({
            model = employer.pedModel,
            coords = employer.coords,
            freeze = true,
            invincible = true,
            blockevents = true,
        })
        if ped then
            blip = Utils.addBlip(ped, config.blips.employer, false)
        end

        table.insert(state.employers, { index = index, ped = ped, blip = blip, coords = employer.coords })
    end

    setupEmployersTargets()
end

function HeistClient.updateActiveInfoIndex(index)
    if not ClientApplication.state.activeScenario then return end
    ClientApplication:sendReactMessage("ui:setInfoBox", { activeIndex = index })
    ClientApplication:sendReactMessage("ui:hideInfoBoxProgress", true)
end

function HeistClient.updateActiveInfoProgress(progress, total)
    if not ClientApplication.state.activeScenario then return end
    ClientApplication:sendReactMessage("ui:setInfoBox", { progress = { current = progress, total = total } })
end

function HeistClient.completeScenario()
    return completeHeistScenario()
end

RegisterNUICallback("nui:heist:startScenario", function(scenarioKey, resultCallback)
    if ClientApplication.state.activeScenario then
        ClientApplication:sendReactAlert(locale("scenario.party_already_in_scenario"), "error")
        return resultCallback(false)
    end

    if not HeistClient.getNearestEmployer() then
        ClientApplication:sendReactAlert(locale("heist.not_near_employer"), "error")
        return resultCallback(false)
    end

    local response = lib.callback.await(_e("server:heist:startScenario"), false,
        { lobbyId = ClientApplication.state.lobby.id, scenarioKey = scenarioKey })

    if not response then
        ClientApplication:sendReactAlert(locale("scenario.start_failed"), "error")
        resultCallback(false)
        return
    end

    if not response.success then
        ClientApplication:sendReactAlert(response.message, "error")
        resultCallback(false)
        return
    end

    ClientApplication:hideFrame()

    resultCallback(true)
end)

RegisterNUICallback("nui:heist:stopScenario", function(_, resultCallback)
    local response = lib.callback.await(_e("server:heist:stopScenario"), false, {
        lobbyId = ClientApplication.state.lobby.id
    })

    if not response then
        resultCallback(false)
        return
    end

    if not response.success then
        ClientApplication:sendReactAlert(response.message, "error")
        resultCallback(false)
        return
    end

    ClientApplication:hideFrame()

    resultCallback(true)
end)

RegisterNetEvent(_e("client:heist:scenarioStarted"), function(params)
    if not params then return end
    if not params.lobbyId or not params.activeScenario then return end

    __init_state_game__()

    ClientApplication.state.activeScenario = params.activeScenario

    HeistClient.onScenarioStarted()

    ClientApplication:setInfoBoxDisabledState(false)
    ClientApplication:sendReactMessage("ui:setActiveScenario", ClientApplication.state.activeScenario)
    ClientApplication:sendReactMessage("ui:setInfoBox", {
        hidden = true,
        texts = ClientApplication.state.activeScenario.infoTexts or {},
        duration = ClientApplication.state.activeScenario.duration or nil,
    })
end)

RegisterNetEvent(_e("client:heist:scenarioStopped"), function(params)
    if not params then return end
    if not params.lobbyId then return end
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    ClientApplication:setInfoBoxDisabledState(true)
    ClientApplication:sendReactMessage("ui:setInfoBox", nil)
    ClientApplication:sendReactMessage("ui:setActiveScenario", nil)

    HeistClient.clear()
    HeistClient.stopScenario(params.scenarioKey)

    local lastActiveScenario = lib.table.deepclone(ClientApplication.state.activeScenario)

    ClientApplication.state.activeScenario = nil

    if not params.completed then
        Utils.notify(locale("scenario.stopped", params.reason or "unknown"), "info", 4000)
    end

    local success, err = pcall(Exports.onScenarioStopped, cache.serverId, lastActiveScenario, params.completed)
    if not success then
        print(("^1[ERROR] Failed to trigger onScenarioStopped export: %s^0"):format(err))
    end
end)

RegisterNetEvent(_e("client:heist:onScenarioVehicleSpawned"),
    function(lobbyId, data, allVehiclesSpawned, triggerInitAfterAllSpawned)
        if not data then return end
        if not data.vehicleIndex then return end

        if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= lobbyId then
            return
        end

        ClientApplication.state.activeScenario.game.vehicles = ClientApplication.state.activeScenario.game.vehicles or {}
        ClientApplication.state.activeScenario.game.vehicles[data.vehicleIndex] = data

        Citizen.CreateThread(function()
            local entity = lib.waitFor(function()
                if NetworkDoesEntityExistWithNetworkId(data.vehicleNetId) then
                    local entity = NetToVeh(data.vehicleNetId)
                    if DoesEntityExist(entity) then return entity end
                end
            end, nil, false)

            HeistClient.giveVehicleKey(GetVehicleNumberPlateText(entity), entity)

            state.game.scenarioBlips["scenario_vehicle_spawn_" .. data.vehicleIndex] =
                Utils.addBlip(entity, config.blips.vehicle)
        end)

        if allVehiclesSpawned and triggerInitAfterAllSpawned then
            HeistClient.initActiveScenario(ClientApplication.state.activeScenario.key)
        end
    end)

RegisterNetEvent(_e("client:heist:scenarioCompleted"), function(params)
    if not params then return end
    if not params.lobbyId then return end
    if not ClientApplication.state.lobby or ClientApplication.state.lobby.id ~= params.lobbyId then
        return
    end

    ClientApplication.state.activeScenario.isCompleted = true

    ClientApplication:sendReactMessage("ui:setActiveScenario", ClientApplication.state.activeScenario)
    ClientApplication:sendReactMessage("ui:setInfoBox", {
        hidden = true,
        texts = ClientApplication.state.activeScenario.infoTexts or {},
        activeIndex = #ClientApplication.state.activeScenario.infoTexts
    })

    local nearestEmployer, nearestDistance = HeistClient.getNearestEmployer()
    if nearestEmployer then
        SetNewWaypoint(nearestEmployer.coords.x, nearestEmployer.coords.y)

        if nearestEmployer.ped and DoesEntityExist(nearestEmployer.ped) then
            state.game.completionTargetEmployer = nearestEmployer.ped
            Target.addLocalEntity(nearestEmployer.ped, { {
                name = "complete_heist_scenario",
                label = locale("heist.complete_heist_scenario"),
                icon = "fa-solid fa-clipboard-check",
                onSelect = function()
                    if ClientApplication.state.lobby.owner == cache.serverId then
                        completeHeistScenario()
                    else
                        Utils.notify(locale("scenario.only_leader_can_complete"), "error")
                    end
                end,
                canInteract = function(entity, distance)
                    return distance < 3.0 and
                        ClientApplication.state.activeScenario and
                        ClientApplication.state.activeScenario.isCompleted
                end,
            } })
        end
    end

    Utils.notify(locale("scenario.go_to_employer_finish"), "success", 6000)
end)

RegisterNetEvent(_e("client:heist:rewardReceived"), function(rewards)
    if not rewards then return end

    local rewardText = locale("scenario.reward_received") .. "\n"

    if rewards.money and rewards.money > 0 then
        rewardText = rewardText .. locale("scenario.money_reward", rewards.money) .. "\n"
    end

    if rewards.exp and rewards.exp > 0 then
        rewardText = rewardText .. locale("scenario.experience_reward", rewards.exp) .. "\n"
    end

    if rewards.items and #rewards.items > 0 then
        for _, item in pairs(rewards.items) do
            rewardText = rewardText .. locale("scenario.item_reward", item.count, item.name) .. "\n"
        end
    end

    Utils.notify(rewardText, "success", 8000)

    Utils.hideTextUI()
end)
