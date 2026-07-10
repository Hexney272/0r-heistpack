--[[
    MarketService - Server-Side Market & Delivery Management

    @author 0resmon
    @version 2.0.0
]]

local lib = lib

--[[ Dependencies ]]
local Inventory = require "modules.inventory.server"
local Framework = require "modules.framework.init"

--[[ Type Definitions ]]

---@class DeliveryItem
---@field itemName string
---@field count number
---@field price number

---@class PendingDelivery
---@field owner number Player source
---@field items DeliveryItem[]
---@field endTime number Delivery completion time (GetGameTimer)
---@field delivery_time number Delivery duration in seconds
---@field isDroneSpawned boolean Has drone been spawned

---@class MarketService
---@field private _pendingDeliveries table<number, PendingDelivery>
---@field private _config table
---@field private _deliveryThreadActive boolean
local MarketServerClass = {}
MarketServerClass.__index = MarketServerClass

--[[ Constants ]]

local DEFAULT_DELIVERY_TIME = 60
local MIN_DELIVERY_TIME = 10
local DELIVERY_CHECK_INTERVAL = 5000
local MAX_ITEM_COUNT = 100
local MIN_ITEM_COUNT = 1

--[[ Private Helper Functions ]]

---Give items to player
---@param source number
---@param items DeliveryItem[]
local function givePlayerItems(source, items)
    for _, item in pairs(items) do
        Inventory.giveItem(source, item.itemName, item.count)
    end
end

---Validate item count range
---@param count number
---@return number validCount
local function validateItemCount(count)
    return math.max(MIN_ITEM_COUNT, math.min(MAX_ITEM_COUNT, count or MIN_ITEM_COUNT))
end

--[[ Constructor ]]

---Create new MarketService instance
---@return MarketService
function MarketServerClass.new()
    local self = setmetatable({}, MarketServerClass)

    self._pendingDeliveries = {}
    self._config = lib.load("config.market")
    self._deliveryThreadActive = false

    return self
end

--[[ Delivery Management ]]

---Get player's pending delivery
---@param owner number
---@return PendingDelivery? delivery
function MarketServerClass:getPlayerDelivery(owner)
    return self._pendingDeliveries[owner]
end

---Check if player has pending delivery
---@param owner number
---@return boolean
function MarketServerClass:hasPlayerDelivery(owner)
    return self._pendingDeliveries[owner] ~= nil
end

---Add pending delivery
---@param data table
---@return PendingDelivery
function MarketServerClass:addPendingDelivery(data)
    local deliveryTime = math.max(
        MIN_DELIVERY_TIME,
        self._config.droneDeliveryOptions.time or DEFAULT_DELIVERY_TIME
    )

    ---@type PendingDelivery
    local delivery = {
        owner = data.owner,
        items = data.items,
        endTime = GetGameTimer() + deliveryTime * 1000,
        delivery_time = deliveryTime,
        isDroneSpawned = false
    }

    self._pendingDeliveries[data.owner] = delivery

    return delivery
end

---Remove player delivery
---@param owner number
function MarketServerClass:removeDelivery(owner)
    self._pendingDeliveries[owner] = nil
end

--[[ Item Management ]]

---Get item price by name
---@param itemName string
---@return number? price
function MarketServerClass:getItemPrice(itemName)
    for _, item in pairs(self._config.items) do
        if item.itemName == itemName then
            return item.price
        end
    end
    return nil
end

---Validate cart items and calculate total
---@param cartItems table[]
---@return boolean success
---@return table? filteredCart
---@return number? totalCount
---@return string? errorMessage
function MarketServerClass:validateCart(cartItems)
    local filteredCart = {}
    local totalCount = 0

    for _, item in pairs(cartItems) do
        -- Validate item exists in market
        local itemPrice = self:getItemPrice(item.itemName)
        if not itemPrice then
            return false, nil, nil, locale("market.invalid_item", item.label or item.itemName)
        end

        -- Validate and clamp item count
        local itemCount = validateItemCount(item.count)

        -- Calculate total
        totalCount = totalCount + (itemPrice * itemCount)

        -- Add to filtered cart
        table.insert(filteredCart, {
            itemName = item.itemName,
            count = itemCount,
            price = itemPrice
        })
    end

    return true, filteredCart, totalCount, nil
end

--[[ Payment Processing ]]

---Process cart payment
---@param source number
---@param paymentType string
---@param cartItems table[]
---@return table result
function MarketServerClass:processPayment(source, paymentType, cartItems)
    -- Check if market is enabled
    if not self._config.enabled then
        return { success = false, message = locale("market.disabled") }
    end

    -- Check if player already has pending delivery
    if self:hasPlayerDelivery(source) then
        return { success = false, message = locale("market.already_have_order") }
    end

    -- Validate cart
    local success, filteredCart, totalCount, errorMsg = self:validateCart(cartItems)
    if not success then
        return { success = false, message = errorMsg }
    end

    -- Check player balance
    local playerBalance = Framework.getPlayerBalance(source, paymentType)
    if playerBalance < totalCount then
        return {
            success = false,
            message = locale("dont_have_enough_money", totalCount)
        }
    end

    -- Remove money
    Framework.playerRemoveMoney(source, paymentType, totalCount)

    -- Create pending delivery
    local pendingDelivery = self:addPendingDelivery({
        owner = source,
        items = filteredCart
    })

    return {
        success = true,
        pendingDelivery = pendingDelivery
    }
end

---Collect delivery bag
---@param source number
---@return boolean success
function MarketServerClass:collectDelivery(source)
    local delivery = self:getPlayerDelivery(source)

    if not delivery then
        return false
    end

    if not delivery.isDroneSpawned then
        return false
    end

    -- Notify client
    TriggerClientEvent("heistpack:client:market:onCustomerReceivedOrder", source, delivery.items)

    -- Give items to player
    givePlayerItems(source, delivery.items)

    -- Remove delivery
    self:removeDelivery(source)

    return true
end

--[[ Delivery Thread ]]

---Start delivery monitoring thread
function MarketServerClass:startDeliveryThread()
    if self._deliveryThreadActive then
        return
    end

    self._deliveryThreadActive = true

    CreateThread(function()
        while self._deliveryThreadActive do
            local now = GetGameTimer()

            for owner, delivery in pairs(self._pendingDeliveries) do
                if delivery and not delivery.isDroneSpawned and delivery.endTime <= now then
                    -- Spawn delivery drone on client
                    TriggerClientEvent(_e("client:market:spawnDeliveryDrone"), owner, delivery)
                    delivery.isDroneSpawned = true
                end
            end

            Citizen.Wait(DELIVERY_CHECK_INTERVAL)
        end
    end)
end

---Stop delivery monitoring thread
function MarketServerClass:stopDeliveryThread()
    self._deliveryThreadActive = false
end

function MarketServerClass:onStop()
    -- Stop delivery thread
    self:stopDeliveryThread()
end

---Register callbacks
---@private
function MarketServerClass:_registerCallbacks()
    lib.callback.register(_e("server:market:payCart"), function(source, data)
        return self:processPayment(source, data.type, data.items)
    end)

    lib.callback.register(_e("server:market:collectLootableBag"), function(source)
        return self:collectDelivery(source)
    end)

    lib.callback.register(_e("server:market:getPlayerDelivery"), function(source)
        return self:getPlayerDelivery(source)
    end)
end

function MarketServerClass:initialize()
    self:_registerCallbacks()
    self:startDeliveryThread()
end

--[[ Initialize Global Instance ]]

MarketServer = MarketServerClass.new()
MarketServer:initialize()
