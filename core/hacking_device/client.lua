--[[
    HackingDeviceClient - Modern Hacking Device Management

    @author 0resmon
    @version 2.0.0
]]

local lib = lib
local Utils = require("modules.utils.client")

--[[ Type Definitions ]]

---@class HackingDeviceState
---@field active boolean Is hacking device currently active
---@field isDuiActive boolean Is DUI texture active
---@field duiObject number? DUI object handle
---@field duiHandle string? DUI texture handle
---@field promiseResolver table? Promise resolver for async result

---@class HackingDeviceClient
---@field private _state HackingDeviceState
---@field private _duiConfig table
local HackingDeviceClientClass = {}
HackingDeviceClientClass.__index = HackingDeviceClientClass

--[[ Constants ]]

local DUI_WIDTH = 256
local DUI_HEIGHT = 256
local DUI_WAIT_TIMEOUT = 100
local DUI_LOAD_DELAY = 1500
local COORDS_CHECK_INTERVAL = 1000
local SOUND_RADIUS = 5.0
local CAMERA_VIEW_MODE = 4

-- Input control IDs
local CONTROL_ATTACK = 24
local CONTROL_CANCEL = 177
local CONTROL_LOOK_LR = 1
local CONTROL_LOOK_UD = 2

--[[ Private Helper Functions ]]

---Reset state to default values
---@param state HackingDeviceState
local function resetState(state)
    state.active = false
    state.isDuiActive = false
    state.duiObject = nil
    state.duiHandle = nil
    state.promiseResolver = nil
end

---Send message to DUI
---@param duiObject number
---@param action string
---@param data any
local function sendDuiMessage(duiObject, action, data)
    if not duiObject then return end

    local message = json.encode({
        action = action,
        data = data
    })

    SendDuiMessage(duiObject, message)
end

---Play interaction sound at player location
---@param soundName string
---@param soundSet string
---@param coords vector3
local function playInteractionSound(soundName, soundSet, coords)
    PlaySoundFromCoord(
        -1,
        soundName,
        coords.x, coords.y, coords.z,
        soundSet,
        true,
        SOUND_RADIUS,
        false
    )
end

--[[ Constructor ]]

---Create new HackingDeviceClient instance
---@return HackingDeviceClient
function HackingDeviceClientClass.new()
    local self = setmetatable({}, HackingDeviceClientClass)

    ---@type HackingDeviceState
    self._state = {
        active = false,
        isDuiActive = false,
        duiObject = nil,
        duiHandle = nil,
        promiseResolver = nil,
    }

    -- DUI configuration
    self._duiConfig = {
        url = string.format("nui://%s/ui/build/index.html", shared.resource),
        txdName = "0resmon_heistpack_dui_txd",
        textureName = "0resmon_heistpack_dui_tex",
        weaponModel = "w_am_hackdevice_m32",
        textureTarget = "script_rt_w_am_hackdevice_m32",
        requiredWeapon = "weapon_hackingdevice",
    }

    return self
end

--[[ DUI Management ]]

---Create and setup DUI texture
---@private
---@return boolean success
function HackingDeviceClientClass:_createDui()
    if self._state.isDuiActive then
        return false
    end

    -- Create DUI object
    self._state.duiObject = CreateDui(self._duiConfig.url, DUI_WIDTH, DUI_HEIGHT)
    self._state.duiHandle = GetDuiHandle(self._state.duiObject)

    -- Create runtime texture
    local txd = CreateRuntimeTxd(self._duiConfig.txdName)
    CreateRuntimeTextureFromDuiHandle(txd, self._duiConfig.textureName, self._state.duiHandle)

    -- Replace weapon texture with DUI
    AddReplaceTexture(
        self._duiConfig.weaponModel,
        self._duiConfig.textureTarget,
        self._duiConfig.txdName,
        self._duiConfig.textureName
    )

    -- Wait for DUI to be ready
    while not IsDuiAvailable(self._state.duiObject) do
        Citizen.Wait(DUI_WAIT_TIMEOUT)
    end

    self._state.isDuiActive = true
    return true
end

---Destroy DUI texture and cleanup
---@private
function HackingDeviceClientClass:_destroyDui()
    if not self._state.isDuiActive then return end

    -- Remove texture replacement
    RemoveReplaceTexture(
        self._duiConfig.weaponModel,
        self._duiConfig.textureTarget
    )

    -- Destroy DUI
    if self._state.duiObject then
        DestroyDui(self._state.duiObject)
    end

    self._state.duiObject = nil
    self._state.duiHandle = nil
    self._state.isDuiActive = false
end

---Send UI message to DUI
---@private
---@param action string
---@param data any
function HackingDeviceClientClass:_sendDuiMessage(action, data)
    sendDuiMessage(self._state.duiObject, action, data)
end

--[[ Input Handling ]]

---Handle hacking device controls
---@private
function HackingDeviceClientClass:_handleControls()
    CreateThread(function()
        local lastCoordsCheck = 0
        local currentCoords = GetEntityCoords(cache.ped)

        while self._state.active and self._state.isDuiActive do
            Citizen.Wait(1)

            -- Disable all controls except camera
            DisableAllControlActions(0)
            EnableControlAction(0, CONTROL_LOOK_LR, true)
            EnableControlAction(0, CONTROL_LOOK_UD, true)

            -- Update player coords periodically
            local currentTime = GetGameTimer()
            if currentTime - lastCoordsCheck > COORDS_CHECK_INTERVAL then
                currentCoords = GetEntityCoords(cache.ped)
                lastCoordsCheck = currentTime
            end

            -- Handle attack button (interact with minigame)
            if IsDisabledControlJustPressed(0, CONTROL_ATTACK) then
                playInteractionSound(
                    "IDLE_BEEP",
                    "EPSILONISM_04_SOUNDSET",
                    currentCoords
                )
                self:_sendDuiMessage("dui:updateMinigame", nil)
            end

            -- Handle cancel button
            if IsDisabledControlJustPressed(0, CONTROL_CANCEL) then
                self:_resolvePromise(false)
                self:clear()
                break
            end
        end
    end)
end

--[[ Promise Management ]]

---Create and return a new promise
---@private
---@return table promise
function HackingDeviceClientClass:_createPromise()
    self._state.promiseResolver = promise.new()
    return self._state.promiseResolver
end

---Resolve the active promise
---@private
---@param result boolean
function HackingDeviceClientClass:_resolvePromise(result)
    if self._state.promiseResolver then
        self._state.promiseResolver:resolve(result)
        self._state.promiseResolver = nil
    end
end

--[[ Validation ]]

---Check if player has required weapon equipped
---@private
---@return boolean hasWeapon
function HackingDeviceClientClass:_hasRequiredWeapon()
    local weaponHash = GetHashKey(self._duiConfig.requiredWeapon)
    local currentWeapon = GetSelectedPedWeapon(cache.ped)
    return currentWeapon == weaponHash
end

--[[ Public Methods ]]

---Check if hacking device is currently active
---@return boolean
function HackingDeviceClientClass:isActive()
    return self._state.active
end

---Show hacking device and start minigame
---@return boolean success Result of hacking attempt
function HackingDeviceClientClass:show()
    -- Check if already active
    if self._state.active then
        return false
    end

    -- Validate required weapon
    if not self:_hasRequiredWeapon() then
        Utils.notify(locale("hacking_device.weapon_required"), "error", 3000)
        return false
    end

    -- Set active state
    self._state.active = true
    Utils.toggleHud(false)

    -- Create DUI
    if not self:_createDui() then
        self:clear()
        return false
    end

    -- Wait for DUI to fully load
    Citizen.Wait(DUI_LOAD_DELAY)

    -- Setup UI
    self:_sendDuiMessage("ui:setPage", "hacking_device")
    self:_sendDuiMessage("ui:setVisible", true)

    -- Set camera view
    SetFollowPedCamViewMode(CAMERA_VIEW_MODE)

    -- Start input handling
    self:_handleControls()

    -- Create and await promise
    local resultPromise = self:_createPromise()
    return Citizen.Await(resultPromise)
end

---Clear and cleanup hacking device
function HackingDeviceClientClass:clear()
    if not self._state.active then return end

    -- Destroy DUI
    self:_destroyDui()

    -- Cleanup
    Utils.toggleHud(true)
    ClearPedTasks(cache.ped)

    -- Reset state
    resetState(self._state)
end

---Handle minigame completion (called from NUI callback)
---@param success boolean
function HackingDeviceClientClass:_onMinigameComplete(success)
    -- Resolve promise
    self:_resolvePromise(success)

    -- Cleanup
    self:clear()
end

---Register NUI callbacks
---@private
function HackingDeviceClientClass:_registerNuiCallbacks()
    ---Handle minigame completion from NUI
    RegisterNUICallback("nui:hackingdevice:over", function(result, cb)
        cb(1)
        self:_onMinigameComplete(result)
    end)
end

function HackingDeviceClientClass:initialize()
    self:_registerNuiCallbacks()
end

--[[ Initialize Global Instance ]]

HackingDeviceClient = HackingDeviceClientClass.new()
HackingDeviceClient:initialize()
