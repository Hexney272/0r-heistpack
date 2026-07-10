--[[
    MarketClient - Client-Side Market & Delivery Management

    @author 0resmon
    @version 2.0.0
]]

local lib = lib
local Utils = require "modules.utils.client"
local Target = require "modules.target.client"

--[[ Type Definitions ]]

---@class MarketClient
---@field private _config table
---@field private _droneNetId number?
---@field private _bagNetId number?
local MarketClientClass = {}
MarketClientClass.__index = MarketClientClass

--[[ Constants ]]

local SPAWN_RADIUS = 50.0
local SPAWN_HEIGHT_OFFSET = 10.0
local DRONE_MOVE_SPEED = 3.5
local DRONE_TARGET_HEIGHT = 4.0
local ARRIVAL_DISTANCE = 5.0
local BAG_ATTACH_OFFSET = vector3(0.0, 0.0, -0.5)
local ANIM_DICT = "pickup_object"
local ANIM_NAME = "pickup_low"
local ANIM_DURATION = 1000

--[[ Private Helper Functions ]]

---Wait for entity to be networked
---@param entity number
---@return number? netId
local function waitForNetworkId(entity)
    return lib.waitFor(function()
        if not NetworkGetEntityIsNetworked(entity) then
            NetworkRegisterEntityAsNetworked(entity)
        else
            local netId = ObjToNet(entity)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, false, false)
end

---Get entity from network ID safely
---@param netId number?
---@return number? entity
local function getEntityFromNetId(netId)
    if not netId then return nil end

    local entity = NetToObj(netId)
    if entity and DoesEntityExist(entity) then
        return entity
    end

    return nil
end

---Calculate random spawn position around player
---@param playerCoords vector3
---@return vector3
local function calculateSpawnPosition(playerCoords)
    local spawnAngle = math.rad(math.random(0, 360))

    return vector3(
        playerCoords.x + math.cos(spawnAngle) * SPAWN_RADIUS,
        playerCoords.y + math.sin(spawnAngle) * SPAWN_RADIUS,
        playerCoords.z + SPAWN_HEIGHT_OFFSET
    )
end

--[[ Constructor ]]

---Create new MarketClient instance
---@return MarketClient
function MarketClientClass.new()
    local self = setmetatable({}, MarketClientClass)

    self._config = lib.load("config.market")
    self._droneNetId = nil
    self._bagNetId = nil

    return self
end

--[[ Entity Management ]]

---Delete drone object
---@private
function MarketClientClass:_deleteDrone()
    local drone = getEntityFromNetId(self._droneNetId)
    if drone then
        DeleteEntity(drone)
        SetEntityAsNoLongerNeeded(drone)
    end
    self._droneNetId = nil
end

---Delete bag object
---@private
function MarketClientClass:_deleteBag()
    local bag = getEntityFromNetId(self._bagNetId)
    if bag then
        DeleteEntity(bag)
        SetEntityAsNoLongerNeeded(bag)
    end
    self._bagNetId = nil
end

---Drop bag from drone
---@private
function MarketClientClass:_dropBag()
    local bag = getEntityFromNetId(self._bagNetId)
    if not bag then return end

    -- Make bag dynamic
    FreezeEntityPosition(bag, false)
    DetachEntity(bag, true, true)
    SetEntityDynamic(bag, true)
    ActivatePhysics(bag)

    -- Add collection target
    Target.addLocalEntity(bag, { {
        label = locale("market.collect"),
        icon = "fa-solid fa-briefcase",
        distance = 2.0,
        onSelect = function()
            -- Play animation
            lib.playAnim(cache.ped, ANIM_DICT, ANIM_NAME)

            -- Collect items
            lib.callback.await(_e("server:market:collectLootableBag"), false)

            Citizen.Wait(ANIM_DURATION)
            self:_deleteBag()
        end,
    } })
end

--[[ Drone Delivery ]]

---Spawn delivery drone
---@private
function MarketClientClass:_spawnDrone()
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local spawnPos = calculateSpawnPosition(playerCoords)

    -- Create drone
    local drone = Utils.createObject({
        model = self._config.droneDeliveryOptions.objectModel,
        coords = spawnPos,
        freeze = false,
        isNetwork = true,
    })
    if not drone then return end

    self._droneNetId = waitForNetworkId(drone)
    SetEntityAsMissionEntity(drone, true, true)

    -- Add blip
    Utils.addBlip(drone, self._config.droneDeliveryOptions.blip)

    -- Create bag
    local bag = Utils.createObject({
        model = self._config.droneDeliveryOptions.bagModel,
        coords = spawnPos,
        freeze = true,
        isNetwork = true,
    })
    if not bag then return end

    self._bagNetId = waitForNetworkId(bag)
    SetEntityAsMissionEntity(bag, true, true)

    -- Attach bag to drone
    AttachEntityToEntity(
        bag, drone, 0,
        BAG_ATTACH_OFFSET.x, BAG_ATTACH_OFFSET.y, BAG_ATTACH_OFFSET.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true
    )
end

---Move drone to player
---@private
function MarketClientClass:_moveDroneToPlayer()
    CreateThread(function()
        local reachedTarget = false

        while self._droneNetId and not reachedTarget do
            local drone = getEntityFromNetId(self._droneNetId)

            if not drone then
                Citizen.Wait(100)
                goto continue
            end

            local droneCoords = GetEntityCoords(drone)
            local playerCoords = GetEntityCoords(cache.ped)
            local distanceFromPlayer = #(playerCoords - droneCoords)

            -- Check if arrived
            if distanceFromPlayer < ARRIVAL_DISTANCE then
                reachedTarget = true
                break
            end

            -- Move towards player
            local targetPos = vector3(
                playerCoords.x,
                playerCoords.y,
                playerCoords.z + DRONE_TARGET_HEIGHT
            )
            local direction = targetPos - droneCoords
            local moveVector = direction / #direction * DRONE_MOVE_SPEED * 0.02

            local coords = droneCoords + moveVector

            SetEntityCoords(drone, coords.x, coords.y, coords.z,
                false, false, false, false)

            Citizen.Wait(1)
            ::continue::
        end

        -- Wait before dropping bag
        Citizen.Wait(3000)

        -- Drop bag
        self:_dropBag()

        -- Clear order info
        ClientApplication:sendReactMessage("ui:setOrderInfo", nil)

        -- Wait before deleting drone
        Citizen.Wait(1000)
        self:_deleteDrone()
    end)
end

--[[ Public Methods ]]

---Handle order placement
---@param data table Order data
---@return table result
function MarketClientClass:placeOrder(data)
    local response = lib.callback.await(_e("server:market:payCart"), false, data)

    if not response.success then
        ClientApplication:sendReactAlert(response.message, "error")
        return { success = false }
    end

    ClientApplication:sendReactAlert(locale("market.order_delivered"), "success")
    ClientApplication:hideFrame()

    return {
        success = true,
        pendingDelivery = response.pendingDelivery
    }
end

---Handle drone spawn event
function MarketClientClass:handleDroneSpawn()
    -- Verify delivery exists
    if not lib.callback.await(_e("server:market:getPlayerDelivery"), false) then
        return
    end

    -- Spawn drone and bag
    self:_spawnDrone()

    -- Move drone to player
    self:_moveDroneToPlayer()
end

---Get market items
---@return table items
function MarketClientClass:getMarketItems()
    return self._config.items or {}
end

---Cleanup on unload
function MarketClientClass:cleanup()
    self:_deleteBag()
    self:_deleteDrone()
end

---Is market enabled
---@return boolean
function MarketClientClass:isMarketEnabled()
    return self._config.enabled
end

---Register NUI Callbacks
---@private
function MarketClientClass:_registerNUICallbacks()
    --- Handle cart payment
    RegisterNUICallback("nui:market:payCart", function(data, resultCallback)
        local result = MarketClient:placeOrder(data)
        resultCallback(result.pendingDelivery or false)
    end)
end

---Register Net Events
---@private
function MarketClientClass:_registerNetEvents()
    RegisterNetEvent(_e("client:market:spawnDeliveryDrone"), function()
        self:handleDroneSpawn()
    end)
end

function MarketClientClass:initialize()
    self:_registerNetEvents()
    self:_registerNUICallbacks()
end

--[[ Initialize Global Instance ]]

MarketClient = MarketClientClass.new()
MarketClient:initialize()
