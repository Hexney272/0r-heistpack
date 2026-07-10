--[[
    DroneClient - Modern Drone Management System

    @author 0resmon
    @version 2.0.0
]]

local lib       = lib
local Utils     = require("modules.utils.client")
local Inventory = require("modules.inventory.client")
local config    = lib.load("config.drone")

--[[ Type Definitions ]]

---@class DroneState
---@field active boolean Is drone currently active
---@field entityId number? Drone entity ID
---@field camId number? Camera ID
---@field tabletEntityId number? Tablet object ID
---@field lastCoords vector3? Last known drone coordinates
---@field dropZones table? Available drop zones
---@field sleeping boolean Is drone in cooldown

---@class DroneOptions
---@field itemName string Required item to use drone
---@field itemLabel string Label of the required item
---@field maxUsageDistance number Maximum distance from player
---@field propModel string Drone prop model
---@field tabletModel string Tablet prop model

---@class DroneClient
---@field private _state DroneState
---@field private _config DroneOptions
local DroneClientClass = {}
DroneClientClass.__index = DroneClientClass

--[[ Constants ]]

local MOVEMENT_SPEED_NORMAL = 0.35
local MOVEMENT_SPEED_FAST = 0.75
local MIN_ALTITUDE = 30.0
local CAMERA_PITCH = -90.0
local SPAWN_ANIMATION_DURATION = 2000
local SPAWN_HEIGHT_STEPS = 250
local DROP_ZONE_MARKER_HEIGHT = 3.0
local DROP_ZONE_MARKER_COLOR = { r = 237, g = 197, b = 66, a = 255 }

--[[ Private Helper Functions ]]

---Reset state to default values
---@param state DroneState
local function resetState(state)
    state.active = false
    state.entityId = nil
    state.camId = nil
    state.tabletEntityId = nil
    state.dropZones = nil
    state.sleeping = false
    -- Keep lastCoords for respawn
end

---Check if entity exists and is valid
---@param entityId number?
---@return boolean
local function isEntityValid(entityId)
    return entityId ~= nil and DoesEntityExist(entityId)
end

---Calculate forward and right vectors from yaw and pitch
---@param yaw number
---@param pitch number
---@return vector3 forward, vector3 right
local function calculateMovementVectors(yaw, pitch)
    local radYaw = math.rad(yaw)
    local radPitch = math.rad(pitch)

    local forward = vector3(
        -math.sin(radYaw) * math.cos(radPitch),
        math.cos(radYaw) * math.cos(radPitch),
        math.sin(radPitch)
    )

    local right = vector3(
        math.cos(radYaw),
        math.sin(radYaw),
        0.0
    )

    return forward, right
end

---Find closest drop zone to drone position
---@param droneCoords vector3
---@param dropZones table
---@param canDropCallback function
---@return vector3? coords, number? distance, number? zoneIndex
local function findClosestDropZone(droneCoords, dropZones, canDropCallback)
    local closestCoords, closestDistance, closestZoneIndex = nil, math.huge, nil

    for zoneIndex, dropZone in ipairs(dropZones) do
        if canDropCallback(zoneIndex) then
            local zoneCoords = dropZone.coords
            local distance = #(vector2(zoneCoords.x, zoneCoords.y) - vector2(droneCoords.x, droneCoords.y))

            -- Only show zones within range and below drone
            if distance < 100.0 and droneCoords.z > zoneCoords.z then
                -- Draw marker
                DrawMarker(
                    1, -- Cylinder marker
                    zoneCoords.x, zoneCoords.y, zoneCoords.z,
                    0, 0, 0, 0, 0, 0,
                    dropZone.radius, dropZone.radius, DROP_ZONE_MARKER_HEIGHT,
                    DROP_ZONE_MARKER_COLOR.r, DROP_ZONE_MARKER_COLOR.g, DROP_ZONE_MARKER_COLOR.b,
                    DROP_ZONE_MARKER_COLOR.a,
                    false, false, 2, false, nil, nil, false
                )

                if distance < closestDistance then
                    closestCoords = zoneCoords
                    closestDistance = distance
                    closestZoneIndex = zoneIndex
                end
            end
        end
    end

    return closestCoords, closestDistance, closestZoneIndex
end

--[[ Constructor ]]

---Create new DroneClient instance
---@return DroneClient
function DroneClientClass.new()
    local self = setmetatable({}, DroneClientClass)

    ---@type DroneState
    self._state = {
        active = false,
        entityId = nil,
        camId = nil,
        tabletEntityId = nil,
        lastCoords = nil,
        dropZones = nil,
        sleeping = false,
    }

    ---@type DroneOptions
    self._config = {
        itemName = config.requiredItem.name,
        itemLabel = config.requiredItem.label,
        maxUsageDistance = config.maxUsageDistance,
        propModel = config.propModel,
        tabletModel = config.tabletModel,
    }

    return self
end

--[[ Tablet Management ]]

---Give tablet to player
---@private
function DroneClientClass:_attachTablet()
    self:_removeTablet()

    local playerPed = cache.ped
    local tabletObject = Utils.createObject({
        model = self._config.tabletModel,
        coords = GetEntityCoords(playerPed),
        freeze = true,
        isNetwork = true,
    })
    if not tabletObject then return end

    self._state.tabletEntityId = tabletObject

    -- Attach to player hand
    AttachEntityToEntity(
        tabletObject, playerPed,
        GetPedBoneIndex(playerPed, config.holding.bone),
        config.holding.offset.x, config.holding.offset.y, config.holding.offset.z,
        config.holding.rotation.x, config.holding.rotation.y, config.holding.rotation.z,
        true, true, false, false, 2, true
    )

    -- Play holding animation
    lib.requestAnimDict(config.holding.dict)
    TaskPlayAnim(
        playerPed, config.holding.dict, config.holding.name,
        8.0, -8.0, -1, 49, 0, false, false, false
    )
    RemoveAnimDict(config.holding.dict)
end

---Remove tablet from player
---@private
function DroneClientClass:_removeTablet()
    if isEntityValid(self._state.tabletEntityId) then
        SetEntityAsMissionEntity(self._state.tabletEntityId, true, true)
        DeleteObject(self._state.tabletEntityId)
    end
    self._state.tabletEntityId = nil
    ClearPedTasks(cache.ped)
end

--[[ Camera Management ]]

---Setup drone camera
---@private
function DroneClientClass:_setupCamera()
    local droneCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamRot(droneCam, CAMERA_PITCH, 0.0, 0.0, 2)
    AttachCamToEntity(droneCam, self._state.entityId, 0.0, 0.0, -0.2, true)
    SetCamActive(droneCam, true)
    RenderScriptCams(true, false, 0, false, true)

    -- Apply scanline effect
    SetTimecycleModifier("scanline_cam_cheap")
    SetTimecycleModifierStrength(2.0)

    self._state.camId = droneCam
end

---Destroy drone camera
---@private
function DroneClientClass:_destroyCamera()
    if self._state.camId then
        DestroyCam(self._state.camId, false)
        ClearFocus()
        RenderScriptCams(false, false, 0, true, true)
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        self._state.camId = nil
    end
end

--[[ Drone Movement ]]

---Handle drone movement controls
---@private
---@param canDropCallback function
---@param onDropCallback function
function DroneClientClass:_handleMovement(canDropCallback, onDropCallback)
    CreateThread(function()
        local textUIVisible = false

        while self._state.entityId do
            DisableAllControlActions(0)

            local playerCoords = GetEntityCoords(cache.ped)
            local droneCoords = GetEntityCoords(self._state.entityId)

            -- Handle exit controls
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 194) then
                self:clear()
                break
            end

            -- Get movement input
            local forward = IsDisabledControlPressed(0, 32) and 1.0 or (IsDisabledControlPressed(0, 33) and -1.0 or 0.0)
            local right = IsDisabledControlPressed(0, 34) and -1.0 or (IsDisabledControlPressed(0, 35) and 1.0 or 0.0)
            local up = IsDisabledControlPressed(0, 44) and 1.0 or (IsDisabledControlPressed(0, 38) and -1.0 or 0.0)

            -- Calculate speed (sprint for faster movement)
            local speed = IsDisabledControlPressed(0, 21) and MOVEMENT_SPEED_FAST or MOVEMENT_SPEED_NORMAL

            -- Calculate movement vectors
            local forwardVector, rightVector = calculateMovementVectors(0.0, -45.0)

            -- Apply movement
            droneCoords = vector3(
                droneCoords.x + forwardVector.x * forward * speed + rightVector.x * right * speed,
                droneCoords.y + forwardVector.y * forward * speed + rightVector.y * right * speed,
                droneCoords.z + up * speed
            )

            -- Enforce minimum altitude
            droneCoords = vector3(
                droneCoords.x,
                droneCoords.y,
                math.max(droneCoords.z, playerCoords.z + MIN_ALTITUDE)
            )

            SetEntityCoords(self._state.entityId, droneCoords.x, droneCoords.y, droneCoords.z, false, false, false, true)

            -- Check max distance from player
            local distanceFromPlayer = #(droneCoords - playerCoords)
            if distanceFromPlayer > self._config.maxUsageDistance then
                local direction = (droneCoords - playerCoords) / distanceFromPlayer
                droneCoords = playerCoords + direction * (self._config.maxUsageDistance - 2.0)
                SetEntityCoords(self._state.entityId, droneCoords.x, droneCoords.y, droneCoords.z,
                    false, false, false, false)
                Utils.notify(locale("drone.too_far"), "error", 1000)
                Citizen.Wait(500)
            end

            -- Handle drop zones
            if not self._state.sleeping then
                local closestCoords, closestDistance, closestZoneIndex = findClosestDropZone(
                    droneCoords,
                    self._state.dropZones,
                    canDropCallback
                )

                if closestCoords then
                    if closestDistance <= 1.5 then
                        -- Show drop prompt
                        if not textUIVisible then
                            textUIVisible = true
                            Utils.showTextUI(locale("drone.drop_from_here"), "E")
                        end

                        -- Handle drop action
                        if IsDisabledControlJustPressed(0, 38) then
                            self._state.sleeping = true
                            Utils.hideTextUI()
                            onDropCallback(closestZoneIndex, droneCoords, closestCoords)
                            self._state.sleeping = false
                            Citizen.Wait(500)
                        end
                    elseif textUIVisible then
                        Utils.hideTextUI()
                        textUIVisible = false
                    end
                end
            end

            Citizen.Wait(1)
        end

        -- Cleanup
        if textUIVisible then
            Utils.hideTextUI()
        end

        Utils.toggleHud(true)
        self:_removeTablet()
    end)
end

--[[ Drone Spawning ]]

---Spawn drone entity at coordinates
---@private
---@param coords vector3
---@param isFirstSpawn boolean
---@return number entityId
function DroneClientClass:_spawnDrone(coords, isFirstSpawn)
    local droneModel = self._config.propModel
    lib.requestModel(droneModel)

    local droneObject = CreateObjectNoOffset(
        droneModel,
        coords.x, coords.y, coords.z,
        true, false, false
    )

    FreezeEntityPosition(droneObject, true)
    SetEntityCollision(droneObject, false, false)
    SetModelAsNoLongerNeeded(droneModel)

    -- Animate spawn (fly up effect)
    if isFirstSpawn then
        for i = 1, SPAWN_HEIGHT_STEPS do
            local currentCoords = GetEntityCoords(droneObject)
            SetEntityCoords(droneObject, currentCoords.x, currentCoords.y, currentCoords.z + 0.01,
                false, false, false, false)
            Citizen.Wait(10)
        end
    end

    return droneObject
end

---Play drone placement animation
---@private
function DroneClientClass:_playPlacementAnimation()
    local playerPed = cache.ped
    local animDict = "anim@mp_fireworks"
    local animName = "place_firework_3_box"

    lib.requestAnimDict(animDict)
    lib.playAnim(playerPed, animDict, animName, nil, nil, SPAWN_ANIMATION_DURATION, 49)

    Citizen.Wait(SPAWN_ANIMATION_DURATION)
    ClearPedTasks(playerPed)
end

--[[ Public Methods ]]

---Check if drone is currently active
---@return boolean
function DroneClientClass:isActive()
    return self._state.active
end

---Get drone configuration options
---@return DroneOptions
function DroneClientClass:getOptions()
    return self._config
end

---Create and activate drone
---@param droneOptions DroneOptions?
---@param startCoords vector3?
---@param dropZones table
---@param canDropCallback function
---@param onDropCallback function
---@return boolean success
function DroneClientClass:create(droneOptions, startCoords, dropZones, canDropCallback, onDropCallback)
    -- Check if already active
    if self._state.active then
        Utils.notify(locale("drone.already_active"), "error")
        return false
    end

    -- Check if player has required item
    local hasDroneItem = lib.callback.await(_e("server:hasItem"), false, self._config.itemName, 1)
    if not hasDroneItem then
        Utils.notify(locale("drone.no_item", self._config.itemLabel), "error")
        return false
    end

    Inventory.disarm()

    -- Update config if provided
    if droneOptions then
        for key, value in pairs(droneOptions) do
            if self._config[key] ~= nil then
                self._config[key] = value
            end
        end
    end

    -- Set state
    self._state.active = true
    self._state.dropZones = dropZones or {}

    -- Determine spawn coordinates
    local playerPed = cache.ped
    local spawnCoords = self._state.lastCoords or startCoords or GetEntityCoords(playerPed)
    local isFirstSpawn = self._state.lastCoords == nil

    -- Play placement animation if first spawn
    if isFirstSpawn then
        self:_playPlacementAnimation()
    end

    -- Spawn drone
    self._state.entityId = self:_spawnDrone(spawnCoords, isFirstSpawn)

    -- Setup UI
    ClientApplication:sendReactMessage("ui:setPage", "drone")
    ClientApplication:sendReactMessage("ui:setVisible", true)

    -- Setup camera
    self:_setupCamera()

    -- Hide HUD
    Utils.toggleHud(false)

    -- Give tablet to player
    self:_attachTablet()

    -- Start movement handling
    self:_handleMovement(canDropCallback, onDropCallback)

    return true
end

---Clear and cleanup drone
function DroneClientClass:clear()
    if not self._state.active then return end

    -- Save last coordinates for respawn
    if isEntityValid(self._state.entityId) then
        self._state.lastCoords = GetEntityCoords(self._state.entityId)
        DeleteEntity(self._state.entityId)
    end

    -- Cleanup camera
    self:_destroyCamera()

    -- Cleanup tablet
    self:_removeTablet()

    -- Reset UI
    ClientApplication:sendReactMessage("ui:setVisible", false)
    ClientApplication:sendReactMessage("ui:setPage", "home")
    Utils.toggleHud(true)

    -- Reset state
    resetState(self._state)
end

--[[ Initialize Global Instance ]]

DroneClient = DroneClientClass.new()
