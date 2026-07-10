local Framework = require "modules.framework.init"

--[[ Contains client-side helper functions. ]]

local Utils = {}

-- Notification function
---@param title string
---@param type "info"|"error"|"success"|"warning"
---@param duration? number
---@param description? string
function Utils.notify(title, type, duration, description)
    lib.notify({
        title = title,
        type = type or "info",
        duration = duration or 3000,
        description = description,
        position = "top-right",
    })
end

-- TextUI function
---@param show boolean
---@param text? string
---@param options? TextUIOptions
function Utils.showTextUI(text, keyboardKey, options)
    if Config.modernTextUI.enabled then
        TextUI.show(text, keyboardKey)
    else
        if keyboardKey then
            text = string.format("[%s] %s", keyboardKey, text or "")
        end
        lib.showTextUI(text, options)
    end
end

function Utils.hideTextUI()
    if Config.modernTextUI.enabled then
        TextUI.hide()
    else
        lib.hideTextUI()
    end
end

function Utils.isTextUIOpen()
    if Config.modernTextUI.enabled then
        return TextUI.isOpen()
    else
        return lib.isTextUIOpen()
    end
end

--Change HUD visibility
---@param state boolean
function Utils.toggleHud(state)
    if shared.isResourceStart("0r-hud-v3") then
        exports["0r-hud-v3"]:ToggleVisible(state)
    else
        -- ? Your hud script export
    end
end

-- Give vehicle key to player
---@param plate string
---@param entity number
function Utils.giveVehicleKey(plate, entity)
    TriggerServerEvent("qb-vehiclekeys:server:AcquireVehicleKeys", plate)
    -- ? You can also use your vehicle key script export
end

-- Remove vehicle key from player
function Utils.removeVehicleKey(plate)
    -- ? You can use your vehicle key script export
end

-- Set vehicle fuel level
---@param entity number
---@param level number
function Utils.setFuel(entity, level)
    if not level then level = 100.0 end
    if shared.isResourceStart("LegacyFuel") then
        exports["LegacyFuel"]:SetFuel(entity, level)
    elseif shared.isResourceStart("x-fuel") then
        exports["x-fuel"]:SetFuel(entity, level)
    elseif shared.isResourceStart("ps-fuel") then
        exports["ps-fuel"]:SetFuel(entity, level)
    elseif shared.isResourceStart("ox_fuel") then
        Entity(entity).state.fuel = level
    else
        SetVehicleFuelLevel(entity, level)
        if DecorExistOn(entity, "_FUEL_LEVEL") then
            DecorSetFloat(entity, "_FUEL_LEVEL", level)
        end
    end
end

---@param key string
---@param message string
---@param coords vector3
function Utils.triggerPoliceAlert(key, message, coords)
    -- origen_police dispatch integration
    if shared.isResourceStart("origen_police") then
        exports["origen_police"]:SendAlert({
            coords = coords,
            title = message,
            type = "robbery", -- Type of alert (robbery, theft, etc.)
            blip = {
                sprite = 161,  -- Blip sprite for robbery
                color = 1,     -- Blip color (red)
                scale = 1.0,
                time = 5       -- Blip duration in minutes
            },
            jobs = { "police", "sheriff" }, -- Jobs that receive the alert
            message = message,
            duration = 300000 -- Alert duration in milliseconds (5 minutes)
        })
    end
    
    -- Alternative dispatch systems (uncomment if needed):
    
    -- ps-dispatch
    -- if shared.isResourceStart("ps-dispatch") then
    --     exports["ps-dispatch"]:CustomAlert({
    --         coords = coords,
    --         message = message,
    --         dispatchCode = "10-90", -- Robbery in progress
    --         description = key,
    --         radius = 0,
    --         sprite = 161,
    --         color = 1,
    --         scale = 1.0,
    --         length = 3,
    --     })
    -- end
    
    -- cd_dispatch
    -- if shared.isResourceStart("cd_dispatch") then
    --     TriggerServerEvent('cd_dispatch:AddNotification', {
    --         job_table = {'police', 'sheriff'},
    --         coords = coords,
    --         title = '10-90 - ' .. message,
    --         message = key,
    --         flash = 0,
    --         unique_id = key .. '_' .. os.time(),
    --         blip = {
    --             sprite = 161,
    --             scale = 1.0,
    --             colour = 1,
    --             flashes = false,
    --             text = message,
    --             time = (5 * 60 * 1000),
    --             sound = 1,
    --         }
    --     })
    -- end
end

function Utils.canPlayerOpenHeistMenu()
    local playerSource = cache.serverId
    local playerPed = cache.ped
    local playerData = Framework.getPlayerData()

    -- ? You can add your own conditions here, for example checking for alive status, handcuffed, etc.

    return true
end

--[[!!! It is not recommended to change the functions from here on if you are not familiar with them !!!]]

---@class CreateObjectOptions
---@field model string|number Model hash of the object to create
---@field coords vector3 Coords where to spawn the object
---@field rotation vector3|number|nil Rotation of the object (can be a vector3 or just a heading number)
---@field freeze boolean|nil Whether to freeze the object position (default: true)
---@field isNetwork boolean|nil Whether the object is networked (default: false)
---@field doorFlag boolean|nil Whether to set the door flag (default: false)
---@field alpha number|nil Alpha value of the object (0-255)

-- Create an object with specified options
---@param options CreateObjectOptions
---@return integer?
function Utils.createObject(options)
    options = options or {}

    local model = options.model
    local coords = options.coords or vector3(0.0, 0.0, 0.0)
    local rotation = options.rotation or vector3(0.0, 0.0, 0.0)
    local freeze = options.freeze
    local isNetwork = options.isNetwork
    local doorFlag = options.doorFlag
    local alpha = options.alpha

    if not model then return nil end

    if freeze == nil then freeze = true end
    if isNetwork == nil then isNetwork = false end
    if doorFlag == nil then doorFlag = false end

    lib.requestModel(model)
    local object = CreateObject(model, coords.x, coords.y, coords.z, isNetwork, isNetwork, doorFlag)
    SetEntityCoords(object, coords.x, coords.y, coords.z, false, false, false, true)
    if rotation then
        if type(rotation) == "number" then
            rotation = vector3(0.0, 0.0, rotation)
        end
        SetEntityRotation(object, rotation.x, rotation.y, rotation.z, 2, false)
    end
    FreezeEntityPosition(object, freeze)
    if alpha then
        SetEntityAlpha(object, alpha, false)
    end
    SetModelAsNoLongerNeeded(model)
    return object
end

---@class CreatePedOptions
---@field model string|number Model hash of the ped to create
---@field coords vector4 Coords where to spawn the ped
---@field freeze boolean|nil Whether to freeze the ped position (default: true)
---@field isNetwork boolean|nil Whether the ped is networked (default: false)
---@field invincible boolean|nil Whether the ped is invincible (default: true)
---@field blockevents boolean|nil Whether to block ped events (default: true)

-- Create a ped with specified options
---@param options CreatePedOptions
---@return integer?
function Utils.createPed(options)
    options = options or {}

    local model = options.model
    local coords = options.coords or vector4(0.0, 0.0, 0.0, 0.0)
    local freeze = options.freeze
    local isNetwork = options.isNetwork
    local invincible = options.invincible
    local blockevents = options.blockevents

    if freeze == nil then freeze = true end
    if isNetwork == nil then isNetwork = false end
    if invincible == nil then invincible = true end
    if blockevents == nil then blockevents = true end

    if not model then return nil end

    lib.requestModel(model)
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w or 0.0, isNetwork, isNetwork)
    while not DoesEntityExist(ped) do Citizen.Wait(1) end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, freeze)
    SetEntityInvincible(ped, invincible)
    SetPedDiesWhenInjured(ped, invincible == false and true or false)
    TaskSetBlockingOfNonTemporaryEvents(ped, blockevents)
    SetBlockingOfNonTemporaryEvents(ped, blockevents)
    SetModelAsNoLongerNeeded(model)

    return ped
end

-- Add a blip to the map
---@param target number|vector3
---@param options table
---@param route? boolean
---@return number
function Utils.addBlip(target, options, route, longRange)
    if not options then options = {} end
    if options.hidden then return nil end
    if options.scale == 0.0 then return nil end

    local blip = type(target) == "number" and
        AddBlipForEntity(target) or
        AddBlipForCoord(target.x, target.y, target.z)

    SetBlipDisplay(blip, 4)
    SetBlipSprite(blip, options.sprite or 469)
    SetBlipColour(blip, options.color or 0)
    SetBlipScale(blip, options.scale or 0.85)
    SetBlipAsShortRange(blip, not longRange)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(options.name or "Undefined")
    EndTextCommandSetBlipName(blip)

    if route then
        local coords = type(target) == "number" and GetEntityCoords(target) or target
        SetNewWaypoint(coords.x, coords.y)
    end

    return blip
end

function Utils.addRadiusBlip(center, radius, color)
    local blip = AddBlipForRadius(center.x, center.y, center.z, radius)
    SetBlipHighDetail(blip, true)
    SetBlipColour(blip, color or 5)
    SetBlipAlpha(blip, 75)
    SetBlipAsShortRange(blip, true)
    return blip
end

-- Progress bar function
function Utils.progressBar(data)
    lib.progressBar(data)
    return true
end

-- Skill check function
function Utils.skillCheck(difficulty, inputs)
    return lib.skillCheck(difficulty, inputs)
end

---@generic T
---@param cb fun(): T?
---@param timeout? number | false
---@return T
---@async
function Utils.waitFor(cb, timeout)
    local value = cb()
    if value ~= nil then return value end

    if timeout or timeout == nil then
        if type(timeout) ~= "number" then timeout = 3000 end
    end

    local start = timeout and GetGameTimer()
    while value == nil do
        Citizen.Wait(1)
        local elapsed = timeout and GetGameTimer() - start
        if elapsed and elapsed > timeout then return false end
        value = cb()
    end

    return value
end

function Utils.generateUniquePin(digitCount)
    digitCount = math.max(1, math.min(digitCount or 3, 9))

    local digits = {}
    while #digits < digitCount do
        local digit = math.random(1, 9)
        if not lib.table.contains(digits, digit) then
            table.insert(digits, digit)
        end
    end

    return digits
end

---@param ped number
---@return "male"|"female"
function Utils.getPlayerPedSexName()
    local frameworkName = shared.getFrameworkName()

    if frameworkName == "esx" then
        shared.framework.TriggerServerCallback("esx_skin:getPlayerSkin", function(skin)
            if skin then
                return skin.sex == 0 and "male" or "female"
            else
                return "male"
            end
        end)
    else
        local playerData = Framework.getPlayerData()
        local gender = playerData?.charinfo?.gender
        return gender == 1 and "female" or "male"
    end

    return "male"         -- Default return if any issue occurs
end

return Utils
