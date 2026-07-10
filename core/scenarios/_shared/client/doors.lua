local Utils                 = require("modules.utils.client")
local Inventory             = require("modules.inventory.client")
local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

---@class DoorManager
---@field doors table
---@field onDoorUnlocked function|nil
---@field doorLocks table
---@field lockingThread boolean
---@field interactionThread boolean
---@field temporaryObjects table
local DoorManager           = {}
DoorManager.__index         = DoorManager

---Create new door manager instance
---@param options {doors: table?, onDoorUnlocked: function?}
---@return DoorManager
function DoorManager.new(options)
    local self = setmetatable({}, DoorManager)

    self.doors = options.doors or {}
    self.onDoorUnlocked = options.onDoorUnlocked
    self.doorLocks = {}
    self.lockingThread = false
    self.interactionThread = false
    self.temporaryObjects = {}

    return self
end

---Start door locking thread
function DoorManager:startLockingThread()
    if self.lockingThread then return end

    self.lockingThread = true

    Citizen.CreateThread(function()
        while self.lockingThread do
            for index, door in pairs(self.doors) do
                local doorObject = GetClosestObjectOfType(
                    door.coords.x, door.coords.y, door.coords.z,
                    0.3, door.model, false, false, false
                )

                if DoesEntityExist(doorObject) then
                    local doorState = self.doorLocks[index] or {}

                    if doorState.deleted then
                        SetEntityAsMissionEntity(doorObject, true, true)
                        DeleteEntity(doorObject)
                    else
                        FreezeEntityPosition(doorObject, not doorState.unlocked)

                        if not doorState.unlocked then
                            SetEntityRotation(doorObject, 0.0, 0.0, door.yaw, 2, true)
                        else
                            if door.meta and door.meta.openedYaw then
                                local objectRot = GetEntityRotation(doorObject)
                                if not doorState.animationOpening and not doorState.openedWithAnimation then
                                    doorState.animationOpening = true
                                    Citizen.CreateThread(function()
                                        local currentYaw = objectRot.z % 360
                                        local targetYaw = door.meta.openedYaw % 360

                                        local startedAt = GetGameTimer()

                                        local timeout = 1500
                                        while ClientApplication.state.activeScenario do
                                            Citizen.Wait(1)
                                            local angleDiff = ((targetYaw - currentYaw + 180) % 360) - 180
                                            local step = (angleDiff > 0) and 1.0 or -1.0

                                            currentYaw = (currentYaw + step) % 360
                                            SetEntityAsMissionEntity(doorObject, true, true)
                                            SetEntityRotation(doorObject, 0.0, 0.0, currentYaw, 2, true)

                                            if GetGameTimer() - startedAt > timeout then
                                                break
                                            end

                                            if math.abs(currentYaw - targetYaw) <= 1.0 then
                                                break
                                            end
                                        end
                                        doorState.animationOpening = false
                                        doorState.openedWithAnimation = true
                                        SetEntityRotation(doorObject, 0.0, 0.0, door.meta.openedYaw, 2, true)
                                    end)
                                else
                                    SetEntityRotation(doorObject, 0.0, 0.0, door.meta.openedYaw, 2, true)
                                end
                            end
                        end
                    end
                end
            end
            Citizen.Wait(500)
        end
    end)
end

---Stop door locking thread
function DoorManager:stopLockingThread()
    self.lockingThread = false
end

---Unlock a door
---@param doorIndex number
---@param deleted? boolean Should door be deleted
function DoorManager:unlockDoor(doorIndex, deleted)
    local door = self.doors[doorIndex]
    if not door then return end

    self.doorLocks[doorIndex] = {
        unlocked = true,
        deleted = deleted or (door.meta and door.meta.delete) or false,
    }

    if self.onDoorUnlocked then
        self.onDoorUnlocked(doorIndex)
    end

    if not door.meta or (not door.meta.openedYaw and not door.meta.noAnimation) then
        self:animateDoorOpening(doorIndex, false)
    end

    if door.partner then
        local partnerDoor = self.doors[door.partner]
        if not partnerDoor then return end

        self.doorLocks[door.partner] = {
            unlocked = true,
            deleted = deleted or (partnerDoor.meta and partnerDoor.meta.delete) or false,
        }
        if not partnerDoor.meta or not partnerDoor.meta.openedYaw then
            self:animateDoorOpening(door.partner, true)
        end
    end
end

---Check if door is unlocked
---@param doorIndex number
---@return boolean
function DoorManager:isDoorUnlocked(doorIndex)
    local doorState = self.doorLocks[doorIndex]
    return doorState and doorState.unlocked or false
end

---Animate door opening (for bomb/explosion scenarios)
---@param doorIndex number
---@param isPartner boolean
function DoorManager:animateDoorOpening(doorIndex, isPartner)
    Citizen.CreateThread(function()
        local door = self.doors[doorIndex]
        if not door then return end

        -- Clone door if needed
        if door.meta and door.meta.clone then
            local originalDoorObject = GetClosestObjectOfType(
                door.coords.x, door.coords.y, door.coords.z,
                0.3, door.model, false, false, false
            )
            while DoesEntityExist(originalDoorObject) do Citizen.Wait(1) end

            local cloneObject = Utils.createObject({
                model = door.meta.clone.model or door.model,
                coords = door.meta.clone.coords,
                rotation = door.meta.clone.rot,
                freeze = false,
                isNetwork = false,
            })
            if not cloneObject then return end

            if DoesEntityExist(cloneObject) then
                self.temporaryObjects["door_clone_" .. doorIndex] = cloneObject
            end
        end

        -- Skip animation if door should be deleted
        if door.meta and door.meta.delete then
            return
        end

        -- Animate door rotation
        local doorObject = GetClosestObjectOfType(
            door.coords.x, door.coords.y, door.coords.z,
            0.3, door.model, false, false, false
        )

        if DoesEntityExist(doorObject) then
            local originalYaw = door.yaw
            local yawTargets = {}

            if not isPartner then
                yawTargets = {
                    (originalYaw + 35.0) % 360,
                    (originalYaw - 25.0) % 360,
                    (originalYaw + 15.0) % 360,
                    originalYaw % 360
                }
            else
                yawTargets = {
                    (originalYaw - 35.0) % 360,
                    (originalYaw + 25.0) % 360,
                    (originalYaw - 15.0) % 360,
                    originalYaw % 360
                }
            end

            local startTime = GetGameTimer()
            for k = 1, #yawTargets do
                local targetYaw = yawTargets[k]
                local currentYaw = GetEntityRotation(doorObject).z % 360

                while math.abs(currentYaw - targetYaw) > 0.1 do
                    local angleDiff = ((targetYaw - currentYaw + 180) % 360) - 180
                    local step = (angleDiff > 0) and 1.0 or -1.0

                    currentYaw = (currentYaw + step) % 360
                    SetEntityRotation(doorObject, 0.0, 0.0, currentYaw, 2, true)

                    Citizen.Wait(1)
                    if GetGameTimer() - startTime > 2000 then
                        break
                    end
                end
            end
        end
    end)
end

---Start interaction thread for keypad/safepad doors
---@param callbacks table<string, fun(doorIndex: number)> { keypad = fn, safepad = fn }
---@param isBusyCheck fun(): boolean Function to check if player is busy
function DoorManager:startInteractionThread(callbacks, isBusyCheck)
    if self.interactionThread then return end

    self.interactionThread = true

    Citizen.CreateThread(function()
        local textUI = false

        while self.interactionThread do
            local wait = 1000

            local playerCoords = GetEntityCoords(cache.ped)
            local closestDoorMethod = nil
            local closestDistance = math.huge
            local closestDoorId = nil
            local foundLocked = false

            for index, door in pairs(self.doors) do
                if door.unlockMethod then
                    local doorState = self.doorLocks[index] or {}
                    if not doorState.unlocked then
                        foundLocked = true
                        local doorCoords = door.coords
                        if door.meta and door.meta.padInteractCoords then
                            doorCoords = door.meta.padInteractCoords
                        end
                        local dist = #(playerCoords - doorCoords)
                        if dist < closestDistance then
                            local doorObject = GetClosestObjectOfType(
                                door.coords.x, door.coords.y, door.coords.z,
                                0.3, door.model, false, false, false
                            )
                            if DoesEntityExist(doorObject) then
                                closestDistance = dist
                                closestDoorId = index
                                closestDoorMethod = door.unlockMethod
                            end
                        end
                    end
                end
            end

            if not foundLocked then break end

            if not isBusyCheck() and closestDoorId and closestDistance < 1.5 then
                wait = 0
                if not textUI then
                    textUI = true
                    local localeKey = "open_door_with_" .. (closestDoorMethod or "unknown_method")
                    Utils.showTextUI(locale(localeKey), "E")
                end

                if IsControlJustPressed(0, 38) then
                    if textUI then
                        Utils.hideTextUI()
                        textUI = false
                    end

                    if callbacks[closestDoorMethod] then
                        callbacks[closestDoorMethod](closestDoorId)
                    end
                    Citizen.Wait(1000)
                end
            elseif textUI then
                Utils.hideTextUI()
                textUI = false
            end

            Citizen.Wait(wait)
        end

        if textUI then
            Utils.hideTextUI()
        end
    end)
end

---Stop interaction thread
function DoorManager:stopInteractionThread()
    self.interactionThread = false
end

---@param doorIndex number
function DoorManager:playPlantBombAnimation(doorIndex)
    local requiredBombItem = { name = "weapon_stickybomb", label = "Sticky Bomb" }
    local itemCheckResponse = lib.callback.await(_e("server:hasItem"), false, requiredBombItem.name, 1)
    if not itemCheckResponse then
        return { error = true, message = locale("dont_have_required_item", requiredBombItem.label) }
    end
    lib.callback.await(_e("server:removeItem"), false, requiredBombItem.name, 1)

    Inventory.disarm()

    local playerPedId = cache.ped

    local animDict = SHARED_CONFIG.animations.plantBomb.dict
    local animName = SHARED_CONFIG.animations.plantBomb.name
    local plantModel = SHARED_CONFIG.models.bomb

    lib.requestAnimDict(animDict)

    local door = self.doors[doorIndex]
    local doorCoords = door.coords
    local doorModel = door.model
    local doorOffset = door.meta and door.meta.centerOffset

    local sceneCoord = doorCoords
    local sceneRot = GetEntityRotation(cache.ped)
    if doorOffset then
        local targetObject = GetClosestObjectOfType(
            doorCoords.x, doorCoords.y, doorCoords.z,
            0.3, doorModel, false, false, false
        )

        if DoesEntityExist(targetObject) then
            sceneCoord = GetOffsetFromEntityInWorldCoords(targetObject, doorOffset.x, doorOffset.y, doorOffset.z)
        end
    end

    local plantScene = NetworkCreateSynchronisedScene(
        sceneCoord.x, sceneCoord.y, sceneCoord.z,
        sceneRot.x, sceneRot.y, sceneRot.z, 2,
        false, false, 1065353216, 0, 1.3
    )
    NetworkAddPedToSynchronisedScene(
        playerPedId,
        plantScene, animDict,
        animName,
        1.5, -4.0, 1, 16, 1148846080, 0
    )
    NetworkStartSynchronisedScene(plantScene)

    Citizen.Wait(1500)

    local playerCoords = GetEntityCoords(playerPedId)
    local plantObject = Utils.createObject({
        model = plantModel,
        coords = vector3(playerCoords.x, playerCoords.y, playerCoords.z + 0.2),
        rotation = nil,
        freeze = false,
        isNetwork = true,
    })
    SetEntityCollision(plantObject, false, true)
    AttachEntityToEntity(plantObject, playerPedId,
        GetPedBoneIndex(playerPedId, 28422),
        0.0, 0.0, 0.0, 0.0, 0.0, 200.0,
        true, true, false, true, 1, true)

    Citizen.Wait(3000)

    local bombRotation = GetEntityRotation(plantObject)

    ClearPedTasks(playerPedId)
    DeleteEntity(plantObject)
    RemoveAnimDict(animDict)

    return { rotation = bombRotation }
end

function DoorManager:plantLocalBombOnEntity(doorIndex, bombRotation)
    local door = self.doors[doorIndex]
    if not door then return end

    local doorCoords = door.coords
    local doorModel = door.model
    local doorOffset = door.meta and door.meta.centerOffset
    local doorDelete = door.meta and door.meta.delete or false

    local targetEntityCoords = doorCoords
    local bombModel = "prop_bomb_01"

    local bombObject = Utils.createObject({
        model = bombModel,
        coords = targetEntityCoords,
        rotation = bombRotation,
        freeze = true,
        isNetwork = false,
    })
    if not bombObject then return end

    local targetObject = nil

    if doorModel then
        targetObject = GetClosestObjectOfType(
            targetEntityCoords.x, targetEntityCoords.y, targetEntityCoords.z,
            0.3, doorModel, false, false, false
        )

        if DoesEntityExist(targetObject) then
            local offset = doorOffset or vector3(0.0, 0.0, 0.0)
            targetEntityCoords = GetOffsetFromEntityInWorldCoords(targetObject, offset.x, offset.y, offset.z)
            SetEntityCoords(bombObject, targetEntityCoords.x, targetEntityCoords.y, targetEntityCoords.z)
            SetEntityRotation(bombObject, bombRotation.x, bombRotation.y, bombRotation.z, 2)
        end
    end

    for _ = 1, 5 do
        PlaySoundFromCoord(-1, "Beep_Red",
            targetEntityCoords.x, targetEntityCoords.y, targetEntityCoords.z,
            "DLC_HEIST_HACKING_SNAKE_SOUNDS", 0, 0, 0)
        Citizen.Wait(1000)
    end

    AddExplosion(targetEntityCoords.x, targetEntityCoords.y, targetEntityCoords.z, 2, 2.0, true, false, 1.0, false)
    PlaySoundFromCoord(-1, "Bomb_Disarmed",
        targetEntityCoords.x, targetEntityCoords.y, targetEntityCoords.z,
        "GTAO_Speed_Convoy_Soundset", 0, 0, 0)

    if DoesEntityExist(bombObject) then
        DeleteEntity(bombObject)
    end

    if doorDelete and targetObject and DoesEntityExist(targetObject) then
        SetEntityAsMissionEntity(targetObject, true, true)
        DeleteEntity(targetObject)
    end
end

---Clear all resources
function DoorManager:clear()
    self:stopLockingThread()
    self:stopInteractionThread()

    for _, obj in pairs(self.temporaryObjects) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end

    self.temporaryObjects = {}
    self.doorLocks = {}
end

return DoorManager
