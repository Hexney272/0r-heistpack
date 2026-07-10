---@class ScenarioRegistry
--- Centralized registry for all heist scenarios
--- Eliminates repetitive if-else chains for scenario initialization and cleanup
local ScenarioRegistry = {}

--- Client-side scenario handlers
ScenarioRegistry.client = {
    vangelico_robbery = function() return VangelicoRobberyClient end,
    house_robbery = function() return HouseRobberyClient end,
    atm_robbery = function() return AtmRobberyClient end,
    store_robbery = function() return StoreRobberyClient end,
    pacific_bank_robbery = function() return PacificBankRobberyClient end,
    paleto_bank_robbery = function() return PaletoBankRobberyClient end,
    fleeca_bank_robbery = function() return FleecaBankRobberyClient end,
    money_truck_robbery = function() return MoneyTruckRobberyClient end,
    ammunation_robbery = function() return AmmunationRobberyClient end,
    cargo_ship_robbery = function() return CargoShipRobberyClient end,
    truck_robbery = function() return TruckRobberyClient end,
    bobcat_robbery = function() return BobcatRobberyClient end,
    train_robbery = function() return TrainRobberyClient end,
    vehicle_theft_robbery = function() return VehicleTheftRobberyClient end,
    yacht_robbery = function() return YachtRobberyClient end,
}

--- Server-side scenario handlers
ScenarioRegistry.server = {
    vangelico_robbery = function() return VangelicoRobberyServer end,
    house_robbery = function() return HouseRobberyServer end,
    atm_robbery = function() return AtmRobberyServer end,
    store_robbery = function() return StoreRobberyServer end,
    pacific_bank_robbery = function() return PacificBankRobberyServer end,
    paleto_bank_robbery = function() return PaletoBankRobberyServer end,
    fleeca_bank_robbery = function() return FleecaBankRobberyServer end,
    money_truck_robbery = function() return MoneyTruckRobberyServer end,
    ammunation_robbery = function() return AmmunationRobberyServer end,
    cargo_ship_robbery = function() return CargoShipRobberyServer end,
    truck_robbery = function() return TruckRobberyServer end,
    bobcat_robbery = function() return BobcatRobberyServer end,
    train_robbery = function() return TrainRobberyServer end,
    vehicle_theft_robbery = function() return VehicleTheftRobberyServer end,
    yacht_robbery = function() return YachtRobberyServer end,
}

--- Initialize a scenario
---@param scenarioKey string The scenario identifier
---@param side "client"|"server" Which side to initialize
---@param lobbyId? string Lobby ID (server-side only)
---@return table|nil response Initialization response
function ScenarioRegistry.init(scenarioKey, side, lobbyId)
    local registry = side == "client" and ScenarioRegistry.client or ScenarioRegistry.server
    local handler = registry[scenarioKey]

    if not handler then return nil end

    local module = handler()
    if not module or not module.init then return nil end

    if side == "server" then
        return module.init(lobbyId)
    else
        return module.init()
    end
end

--- Clear/stop a scenario
---@param scenarioKey string The scenario identifier
---@param side "client"|"server" Which side to clear
---@param ... any Additional arguments (activeScenario, lobbyId for server)
function ScenarioRegistry.clear(scenarioKey, side, ...)
    local registry = side == "client" and ScenarioRegistry.client or ScenarioRegistry.server
    local handler = registry[scenarioKey]

    if not handler then return end
    local module = handler()
    if not module or not module.clear then return end

    module.clear(...)
end

--- Clear all scenarios (typically on resource stop or player disconnect)
---@param side "client"|"server" Which side to clear
function ScenarioRegistry.clearAll(side)
    local registry = side == "client" and ScenarioRegistry.client or ScenarioRegistry.server

    for _, handler in pairs(registry) do
        local module = handler()
        if module and module.clear then
            module.clear()
        end
    end
end

--- Check if a scenario exists
---@param scenarioKey string The scenario identifier
---@param side "client"|"server" Which side to check
---@return boolean exists
function ScenarioRegistry.exists(scenarioKey, side)
    local registry = side == "client" and ScenarioRegistry.client or ScenarioRegistry.server
    return registry[scenarioKey] ~= nil
end

return ScenarioRegistry
