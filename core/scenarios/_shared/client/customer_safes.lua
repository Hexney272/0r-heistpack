local lib                   = lib
local Utils                 = require("modules.utils.client")
local Inventory             = require("modules.inventory.client")

---@class CustomerSafeManager
---@field safes table[]
---@field onSafeDrilled function|nil
---@field safeStates table
---@field collectionThread boolean
---@field markerThread boolean
local CustomerSafeManager   = {}
CustomerSafeManager.__index = CustomerSafeManager

---@class CustomerSafeManagerOptions
---@field safes table[] List of customer safe configurations
---@field onSafeDrilled? fun(safeIndex: number) Callback when safe drilled

---Create new customer safe manager instance
---@param options CustomerSafeManagerOptions
---@return CustomerSafeManager
function CustomerSafeManager.new(options)
    local self = setmetatable({}, CustomerSafeManager)

    self.safes = options.safes or {}
    self.onSafeDrilled = options.onSafeDrilled
    self.safeStates = {}
    self.collectionThread = false
    self.markerThread = false

    -- Initialize safe states
    for safeIndex, _ in pairs(self.safes) do
        self.safeStates[safeIndex] = {
            drilled = false
        }
    end

    return self
end

---Check if safe is drilled
---@param safeIndex number
---@return boolean
function CustomerSafeManager:isSafeDrilled(safeIndex)
    local state = self.safeStates[safeIndex]
    return state and state.drilled or false
end

---Mark safe as drilled
---@param safeIndex number
function CustomerSafeManager:markSafeDrilled(safeIndex)
    local safeState = self.safeStates[safeIndex]
    if not safeState then return end

    safeState.drilled = true
end

---Drill customer safe
---@param safeIndex number
---@return boolean success
function CustomerSafeManager:drillSafe(safeIndex)
    if self:isSafeDrilled(safeIndex) then
        return false
    end

    local safe = self.safes[safeIndex]
    if not safe then return false end

    local playerPedId = cache.ped
    local safeCoords = vector3(safe.coords.x, safe.coords.y, safe.coords.z)
    local safeHeading = safe.coords.w or 0.0

    Inventory.disarm()

    -- Turn to face safe
    TaskTurnPedToFaceCoord(playerPedId, safeCoords.x, safeCoords.y, safeCoords.z, 1000)
    Citizen.Wait(1000)

    -- Give drill item to hand
    local drillModel = "hei_prop_heist_drill"
    lib.requestModel(drillModel)

    local drillObj = CreateObject(
        GetHashKey(drillModel),
        safeCoords.x, safeCoords.y, safeCoords.z,
        true, true, false
    )

    AttachEntityToEntity(
        drillObj, playerPedId,
        GetPedBoneIndex(playerPedId, 57005),
        0.14, 0.0, -0.01,
        90.0, -90.0, 180.0,
        true, true, false, true, 1, true
    )

    -- Play drill animation
    local animDict = "anim@heists@fleeca_bank@drilling"
    local animName = "drill_straight_idle"
    lib.requestAnimDict(animDict)

    TaskPlayAnim(playerPedId, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

    -- Request particle effect
    local particleDict = "core"
    local particleEffect = "ent_amb_elec_crackle"
    lib.requestNamedPtfxAsset(particleDict)

    UseParticleFxAssetNextCall(particleDict)
    local effect = StartParticleFxLoopedOnEntity(
        particleEffect,
        drillObj,
        0.0, -0.6, 0.0,
        0.0, 0.0, 0.0,
        0.3,
        false, false, false
    )
    -- Wait for drill duration
    local drillDuration = 10000
    Utils.progressBar({
        duration = drillDuration,
        label = locale("drilling_safe"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
        }
    })

    StopParticleFxLooped(effect, false)
    RemoveNamedPtfxAsset(particleDict)

    -- Clean up
    ClearPedTasks(playerPedId)
    DeleteObject(drillObj)
    SetModelAsNoLongerNeeded(drillModel)
    RemoveAnimDict(animDict)

    if self.onSafeDrilled then
        self.onSafeDrilled(safeIndex)
    end

    return true
end

---Start marker drawing thread
function CustomerSafeManager:startMarkerThread()
    if self.markerThread then return end

    self.markerThread = true

    Citizen.CreateThread(function()
        while self.markerThread do
            local wait = 1000
            local playerPedId = cache.ped
            local pedCoords = GetEntityCoords(playerPedId)

            local foundUncollected = false

            for safeIndex, safe in pairs(self.safes) do
                if not self:isSafeDrilled(safeIndex) then
                    foundUncollected = true
                    local safeCoords = vector3(safe.coords.x, safe.coords.y, safe.coords.z)
                    local dist = #(pedCoords - safeCoords)

                    if dist < 5.0 then
                        wait = 0
                        -- Draw marker type 28 (cylinder)
                        DrawMarker(
                            28,                                       -- Type
                            safeCoords.x, safeCoords.y, safeCoords.z, -- Position
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.04, 0.04, 0.04,
                            189, 219, 9, 255,
                            false, true, 2, false, nil, nil, false
                        )
                    end
                end
            end

            if not foundUncollected then
                break
            end

            Citizen.Wait(wait)
        end
    end)
end

---Start collection interaction thread
---@param isBusyCheck fun(): boolean Function to check if player is busy
---@param isBusyCallback fun(safeIndex: number): boolean Server callback to check if busy
---@param localeKey string Locale key for TextUI
function CustomerSafeManager:startCollectionThread(isBusyCheck, isBusyCallback, localeKey)
    if self.collectionThread then return end

    self.collectionThread = true

    Citizen.CreateThread(function()
        local textUI = false

        while self.collectionThread do
            local wait = 1000
            local playerPedId = cache.ped
            local pedCoords = GetEntityCoords(playerPedId)

            local closestDistance = 5.0
            local closestSafeId = nil
            local closestSafe = nil
            local foundUncollected = false

            for safeIndex, safe in pairs(self.safes) do
                if not self:isSafeDrilled(safeIndex) then
                    foundUncollected = true
                    local safeCoords = vector3(safe.coords.x, safe.coords.y, safe.coords.z)
                    local dist = #(pedCoords - safeCoords)
                    if dist < closestDistance then
                        closestDistance = dist
                        closestSafeId = safeIndex
                        closestSafe = safe
                    end
                end
            end

            if not foundUncollected then
                break
            end

            if not isBusyCheck() and closestSafeId and closestSafe then
                if closestDistance < 1.5 then
                    wait = 0
                    if not textUI or not Utils.isTextUIOpen() then
                        textUI = true
                        Utils.showTextUI(locale(localeKey), "E")
                    end

                    if IsControlJustPressed(0, 38) then
                        Utils.hideTextUI()
                        textUI = false

                        -- Check if server says it's busy
                        local isBusy = isBusyCallback(closestSafeId)
                        if not isBusy then
                            self:drillSafe(closestSafeId)
                        end
                    end
                elseif textUI then
                    textUI = false
                    Utils.hideTextUI()
                end
            elseif textUI then
                textUI = false
                Utils.hideTextUI()
            end

            Citizen.Wait(wait)
        end

        if textUI then
            Utils.hideTextUI()
        end
    end)
end

---Stop collection thread
function CustomerSafeManager:stopCollectionThread()
    self.collectionThread = false
end

---Stop marker thread
function CustomerSafeManager:stopMarkerThread()
    self.markerThread = false
end

---Clear all resources
function CustomerSafeManager:clear()
    self:stopCollectionThread()
    self:stopMarkerThread()
    self.safeStates = {}
end

return CustomerSafeManager
