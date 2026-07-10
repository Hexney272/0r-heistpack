local lib              = lib
local Utils            = require("modules.utils.client")
local Inventory        = require("modules.inventory.client")

---@class TrolleyManager
---@field trolleys table[]
---@field onTrolleyCollected function|nil
---@field trolleyStates table
---@field collectionThread boolean
local TrolleyManager   = {}
TrolleyManager.__index = TrolleyManager

---@class TrolleyManagerOptions
---@field trolleys table[] List of trolley configurations
---@field onTrolleyCollected? fun(trolleyIndex: number, trolleyType: string) Callback when trolley collected

---Create new trolley manager instance
---@param options TrolleyManagerOptions
---@return TrolleyManager
function TrolleyManager.new(options)
    local self = setmetatable({}, TrolleyManager)

    self.trolleys = options.trolleys or {}
    self.onTrolleyCollected = options.onTrolleyCollected
    self.trolleyStates = {}
    self.collectionThread = false

    return self
end

---Setup trolley entities
function TrolleyManager:setupTrolleys()
    for trolleyIndex, trolley in pairs(self.trolleys) do
        local object = nil
        if not trolley.no then
            object = Utils.createObject({
                model = trolley.model,
                coords = trolley.coords,
                rotation = trolley.rotation,
                freeze = true,
                isNetwork = false,
            })
        end
        if object and DoesEntityExist(object) then
            self.trolleyStates[trolleyIndex] = {
                entity = object,
                swapped = false,
                collected = false,
            }
        end
    end
end

---Check if trolley is collected
---@param trolleyIndex number
---@return boolean
function TrolleyManager:isTrolleyCollected(trolleyIndex)
    local state = self.trolleyStates[trolleyIndex]
    return state and state.collected or false
end

---Mark trolley as collected
---@param trolleyIndex number
function TrolleyManager:markTrolleyCollected(trolleyIndex)
    local trolleyState = self.trolleyStates[trolleyIndex]
    if not trolleyState then return end

    trolleyState.collected = true

    -- Swap model
    if not trolleyState.swapped then
        local trolley = self.trolleys[trolleyIndex]
        if trolley and trolley.swapModel then
            CreateModelSwap(
                trolley.coords.x, trolley.coords.y, trolley.coords.z,
                0.3, trolley.model, trolley.swapModel, true
            )
            trolleyState.swapped = true
        end
    end
end

---Animate cash appearance during grab
---@param grabModel string|number
---@param trolleyType string
local function animateCashAppear(grabModel, trolleyType)
    local ped = cache.ped
    local pedCoords = GetEntityCoords(ped)

    lib.requestModel(grabModel)

    local grabobj = CreateObject(grabModel, pedCoords.x, pedCoords.y, pedCoords.z, true, false, false)

    FreezeEntityPosition(grabobj, true)
    SetEntityInvincible(grabobj, true)
    SetEntityNoCollisionEntity(grabobj, ped, false)
    SetEntityVisible(grabobj, false, false)
    AttachEntityToEntity(
        grabobj, ped,
        GetPedBoneIndex(ped, 60309),
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        false, false, false, false, 0, true
    )

    SetModelAsNoLongerNeeded(grabModel)

    local startedGrabbing = GetGameTimer()

    Citizen.CreateThread(function()
        while GetGameTimer() - startedGrabbing < 5000 do
            Citizen.Wait(1)
            DisableControlAction(0, 73, true)

            if HasAnimEventFired(ped, GetHashKey("CASH_APPEAR")) then
                if not IsEntityVisible(grabobj) then
                    SetEntityVisible(grabobj, true, false)
                end
            end

            if HasAnimEventFired(ped, GetHashKey("RELEASE_CASH_DESTROY")) then
                if IsEntityVisible(grabobj) then
                    SetEntityVisible(grabobj, false, false)
                end
            end
        end
        DeleteObject(grabobj)
    end)
end

---Collect cash from trolley
---@param trolleyIndex number
---@param isBusyCallback fun(trolleyIndex: number): boolean Server callback to check if busy
---@return boolean success
function TrolleyManager:collectFromTrolley(trolleyIndex, isBusyCallback)
    if self:isTrolleyCollected(trolleyIndex) then
        return false
    end

    -- Check if server says it's busy
    local isBusy = isBusyCallback(trolleyIndex)
    if isBusy then return false end

    local trolley = self.trolleys[trolleyIndex]
    if not trolley then return false end

    Inventory.disarm()

    local trolleyType = not trolley.ingot and "money" or "ingot"
    local playerPedId = cache.ped
    local playerCoords = GetEntityCoords(playerPedId)

    local bagModel = "hei_p_m_bag_var22_arm_s"
    local grabModel = not trolley.ingot and "hei_prop_heist_cash_pile" or "imp_prop_impexp_coke_pile"
    local animDict = "anim@heists@ornate_bank@grab_cash"

    lib.requestAnimDict(animDict)
    lib.requestModel(bagModel)

    local sceneObject = GetClosestObjectOfType(
        trolley.coords.x, trolley.coords.y, trolley.coords.z,
        0.3, trolley.model, false, false, false
    )

    local bagObject = CreateObject(bagModel,
        playerCoords.x, playerCoords.y, playerCoords.z,
        true, true, false)

    while not NetworkHasControlOfEntity(sceneObject) do
        Citizen.Wait(1)
        NetworkRequestControlOfEntity(sceneObject)
    end

    local animations = {
        { "intro", "bag_intro" },
        { "grab",  "bag_grab", "cart_cash_dissapear" },
        { "exit",  "bag_exit" }
    }

    local scenes = {}

    for i = 1, #animations do
        local sceneCoords = GetEntityCoords(sceneObject)
        scenes[i] = NetworkCreateSynchronisedScene(
            sceneCoords.x, sceneCoords.y, sceneCoords.z,
            trolley.rotation.x, trolley.rotation.y, trolley.rotation.z,
            2, true, false, 1065353216, 0, 1.3
        )

        NetworkAddPedToSynchronisedScene(
            playerPedId, scenes[i], animDict,
            animations[i][1], 1.5, -4.0, 1, 16, 1148846080, 0
        )

        NetworkAddEntityToSynchronisedScene(
            bagObject, scenes[i], animDict,
            animations[i][2], 4.0, -8.0, 1
        )

        if i == 2 then
            NetworkAddEntityToSynchronisedScene(
                sceneObject, scenes[i], animDict,
                "cart_cash_dissapear", 4.0, -8.0, 1
            )
        end
    end

    NetworkStartSynchronisedScene(scenes[1])
    Citizen.Wait(1750)
    animateCashAppear(grabModel, trolleyType)
    NetworkStartSynchronisedScene(scenes[2])
    Citizen.Wait(5000)
    NetworkStartSynchronisedScene(scenes[3])

    lib.progressBar({
        duration = 5000,
        label = locale("trolley_collecting"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            combat = true,
            car = true,
        },
    })

    if self.onTrolleyCollected then
        self.onTrolleyCollected(trolleyIndex, trolleyType)
    end

    DeleteObject(bagObject)
    ClearPedTasks(playerPedId)

    RemoveAnimDict(animDict)
    SetModelAsNoLongerNeeded(bagModel)

    return true
end

---Start collection interaction thread
---@param isBusyCheck fun(): boolean Function to check if player is busy
---@param isBusyCallback fun(trolleyIndex: number): boolean Server callback
---@param localeKey string Locale key for TextUI
function TrolleyManager:startCollectionThread(isBusyCheck, isBusyCallback, localeKey)
    if self.collectionThread then return end

    self.collectionThread = true

    Citizen.CreateThread(function()
        local textUI = false

        while self.collectionThread do
            local wait = 1000
            local playerPedId = cache.ped
            local pedCoords = GetEntityCoords(playerPedId)

            local closestDistance = 5.0
            local closestTrolleyId = nil
            local closestTrolley = nil
            local foundUncollected = false

            for trolleyIndex, trolley in pairs(self.trolleys) do
                if not self:isTrolleyCollected(trolleyIndex) then
                    foundUncollected = true
                    local dist = #(pedCoords - trolley.coords)
                    if dist < closestDistance then
                        closestDistance = dist
                        closestTrolleyId = trolleyIndex
                        closestTrolley = trolley
                    end
                end
            end

            if not foundUncollected then
                break
            end

            if not isBusyCheck() and closestTrolleyId and closestTrolley then
                local trolleyEntity = GetClosestObjectOfType(
                    closestTrolley.coords.x,
                    closestTrolley.coords.y,
                    closestTrolley.coords.z,
                    0.3, closestTrolley.model, false, false, false
                )

                if DoesEntityExist(trolleyEntity) and closestDistance < 1.5 then
                    wait = 0
                    if not textUI then
                        textUI = true
                        Utils.showTextUI(locale(localeKey), "E")
                    end

                    if IsControlJustPressed(0, 38) then
                        Utils.hideTextUI()
                        self:collectFromTrolley(closestTrolleyId, isBusyCallback)
                        Citizen.Wait(1000)
                    end
                elseif textUI then
                    textUI = false
                    Utils.hideTextUI()
                end
            end

            Citizen.Wait(wait)
        end

        if textUI then
            Utils.hideTextUI()
        end
    end)
end

---Stop collection thread
function TrolleyManager:stopCollectionThread()
    self.collectionThread = false
end

---Clear all resources
function TrolleyManager:clear()
    self:stopCollectionThread()

    for trolleyIndex, trolleyState in pairs(self.trolleyStates) do
        if trolleyState.swapped then
            local trolley = self.trolleys[trolleyIndex]
            if trolley and trolley.swapModel then
                RemoveModelSwap(
                    trolley.coords.x, trolley.coords.y, trolley.coords.z,
                    0.3, trolley.model, trolley.swapModel, false
                )
            end
        end

        if trolleyState.entity and DoesEntityExist(trolleyState.entity) then
            DeleteEntity(trolleyState.entity)
        end
    end

    self.trolleyStates = {}
end

return TrolleyManager
