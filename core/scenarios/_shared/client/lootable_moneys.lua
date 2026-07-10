local lib                    = lib
local Utils                  = require("modules.utils.client")
local Inventory              = require("modules.inventory.client")

---@class LootableMoneyManager
---@field moneys table[]
---@field onMoneyCollected function|nil
---@field moneyStates table
---@field collectionThread boolean
local LootableMoneyManager   = {}
LootableMoneyManager.__index = LootableMoneyManager

---@class LootableMoneyManagerOptions
---@field moneys table[] List of lootable money configurations
---@field onMoneyCollected? fun(moneyIndex: number) Callback when money collected

---Create new lootable money manager instance
---@param options LootableMoneyManagerOptions
---@return LootableMoneyManager
function LootableMoneyManager.new(options)
    local self = setmetatable({}, LootableMoneyManager)

    self.moneys = options.moneys or {}
    self.onMoneyCollected = options.onMoneyCollected
    self.moneyStates = {}
    self.collectionThread = false

    return self
end

---Setup money entities
function LootableMoneyManager:setupMoneys()
    for moneyIndex, money in pairs(self.moneys) do
        local object = Utils.createObject({
            model = money.model,
            coords = money.coords,
            rotation = vector3(0.0, 0.0, 0.0),
            freeze = true,
            isNetwork = false,
        })

        if object and DoesEntityExist(object) then
            self.moneyStates[moneyIndex] = {
                entity = object,
                collected = false
            }
        end
    end
end

---Check if money is collected
---@param moneyIndex number
---@return boolean
function LootableMoneyManager:isMoneyCollected(moneyIndex)
    local state = self.moneyStates[moneyIndex]
    return state and state.collected or false
end

---Mark money as collected
---@param moneyIndex number
function LootableMoneyManager:markMoneyCollected(moneyIndex)
    local moneyState = self.moneyStates[moneyIndex]
    if not moneyState then return end

    moneyState.collected = true

    if moneyState.entity and DoesEntityExist(moneyState.entity) then
        DeleteEntity(moneyState.entity)
        moneyState.entity = nil
    end
end

---Collect money from table/location
---@param moneyIndex number
---@param animation table? Animation config { dict, name, duration }
---@return boolean success
function LootableMoneyManager:collectMoney(moneyIndex, animation)
    if self:isMoneyCollected(moneyIndex) then
        return false
    end

    local money = self.moneys[moneyIndex]
    if not money then return false end

    Inventory.disarm()

    animation = animation or {
        dict = "anim@heists@ornate_bank@grab_cash_heels",
        name = "grab",
        duration = 2000,
    }

    TaskTurnPedToFaceCoord(
        cache.ped,
        money.coords.x, money.coords.y, money.coords.z,
        4000
    )
    Citizen.Wait(500)

    lib.playAnim(cache.ped, animation.dict, animation.name, 8.0, 8.0, animation.duration)
    Citizen.Wait(animation.duration)
    ClearPedTasks(cache.ped)

    if self.onMoneyCollected then
        self.onMoneyCollected(moneyIndex)
    end

    return true
end

---Start collection interaction thread
---@param isBusyCheck fun(): boolean Function to check if player is busy
---@param localeKey string Locale key for TextUI
---@param animation? table Animation config
function LootableMoneyManager:startCollectionThread(isBusyCheck, localeKey, animation)
    if self.collectionThread then return end

    self.collectionThread = true

    Citizen.CreateThread(function()
        local textUI = false

        while self.collectionThread do
            local wait = 1000
            local playerPedId = cache.ped
            local pedCoords = GetEntityCoords(playerPedId)

            local closestDistance = 5.0
            local closestMoneyId = nil
            local closestMoney = nil
            local foundUncollected = false

            for moneyIndex, money in pairs(self.moneys) do
                if not self:isMoneyCollected(moneyIndex) then
                    foundUncollected = true
                    local dist = #(pedCoords - money.coords)
                    if dist < closestDistance then
                        closestDistance = dist
                        closestMoneyId = moneyIndex
                        closestMoney = money
                    end
                end
            end

            if not foundUncollected then
                break
            end

            if not isBusyCheck() and closestMoneyId and closestMoney then
                local moneyState = self.moneyStates[closestMoneyId]
                if moneyState and moneyState.entity then
                    local moneyEntity = GetClosestObjectOfType(
                        closestMoney.coords.x,
                        closestMoney.coords.y,
                        closestMoney.coords.z,
                        0.3, GetEntityModel(moneyState.entity), false, false, false
                    )

                    if DoesEntityExist(moneyEntity) and closestDistance < 1.0 then
                        wait = 0
                        if not textUI or not Utils.isTextUIOpen() then
                            textUI = true
                            Utils.showTextUI(locale(localeKey), "E")
                        end

                        if IsControlJustPressed(0, 38) then
                            Utils.hideTextUI()
                            textUI = false

                            self:collectMoney(closestMoneyId, animation)
                        end
                    elseif textUI then
                        textUI = false
                        Utils.hideTextUI()
                    end
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
function LootableMoneyManager:stopCollectionThread()
    self.collectionThread = false
end

---Clear all resources
function LootableMoneyManager:clear()
    self:stopCollectionThread()

    for _, moneyState in pairs(self.moneyStates) do
        if moneyState.entity and DoesEntityExist(moneyState.entity) then
            DeleteEntity(moneyState.entity)
        end
    end

    self.moneyStates = {}
end

return LootableMoneyManager
