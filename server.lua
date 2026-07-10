--[[
    Server Application - Main Entry Point

    @author 0resmon
    @version 2.0.0
]]

local Framework = require "modules.framework.init"
local Inventory = require "modules.inventory.server"

--[[ Type Definitions ]]

---@class ServerApplication
---@field load boolean Server loaded state
local ServerApplicationClass = {}
ServerApplicationClass.__index = ServerApplicationClass

--[[ Constructor ]]

---Create new server application
---@return ServerApplication
function ServerApplicationClass.new()
    local self = setmetatable({}, ServerApplicationClass)

    self.load = false

    return self
end

--[[ Initialization ]]

---Initialize application
function ServerApplicationClass:initialize()
    self:_registerNativeEvents()
    self:_registerCallbacks()
    self:_registerCommands()
    self:_registerUseableItems()
end

--[[ License Validation - Removed for Open Source ]]

--[[ Player Management ]]

---Handle player dropped
---@param source number
function ServerApplicationClass:onPlayerDropped(source)
    local playerLobbyId = LobbyServer:findPlayerLobby(source)
    if playerLobbyId then
        -- # TODO: Handle player removal from lobby
        -- LobbyServer:setSelfRemove(playerLobbyId, source)
    end
end

--[[ Startup ]]

---Start application
function ServerApplicationClass:start()
    Citizen.Wait(1000)

    -- Initialize profile system
    ProfileServer:initialize()

    -- Register scenario items
    VangelicoRobberyServer.registerScenarioItems()
    CargoShipRobberyServer.registerScenarioItems()

    self.load = true

    -- Version check
    lib.versionCheck("alikocidev/docs_0resmon_heistpack")

    print("^2[SUCCESS] HeistPack server loaded successfully!^7")
end

---Stop application
function ServerApplicationClass:stop()
    HeistServer.clearAllLobbies()
    print("^3[INFO] HeistPack server stopped^7")
end

--[[ Native Events ]]

---Register native events
---@private
function ServerApplicationClass:_registerNativeEvents()
    AddEventHandler("onResourceStart", function(resource)
        if resource ~= shared.resource then return end
        self:start()
    end)

    AddEventHandler("onResourceStop", function(resource)
        if resource ~= shared.resource then return end
        self:stop()
    end)

    RegisterNetEvent(_e("server:onPlayerLogout"), function()
        local source = source
        self:onPlayerDropped(source)
    end)

    AddEventHandler("playerDropped", function()
        local source = source
        self:onPlayerDropped(source)
    end)
end

--[[ Callbacks ]]

---Register server callbacks
---@private
function ServerApplicationClass:_registerCallbacks()
    lib.callback.register(_e("server:hasItem"), function(source, itemName, amount)
        return Inventory.hasItem(source, itemName, amount or 1)
    end)

    lib.callback.register(_e("server:removeItem"), function(source, itemName, amount)
        return Inventory.removeItem(source, itemName, amount or 1)
    end)

    -- Open Source License Bypass - Always return true
    lib.callback.register("0r-heistpack:server:checkLicense", function(source)
        return true
    end)
end

--[[ Commands ]]

---Register commands
---@private
function ServerApplicationClass:_registerCommands()
    -- Open menu command
    if Config.heistMenu.openWithCommand and Config.heistMenu.openWithCommand.enabled then
        lib.addCommand(Config.heistMenu.openWithCommand.command, {
            help = "Open heist menu",
        }, function(source)
            TriggerClientEvent("0r-heistpack:client:openMenu", source)
        end)
    end
end

--[[ Useable Items ]]

---Register useable items
function ServerApplicationClass:_registerUseableItems()
    if Config.heistMenu.openWithItem and Config.heistMenu.openWithItem.enabled then
        Framework.createUseableItem(Config.heistMenu.openWithItem.itemName, function(source)
            TriggerClientEvent("0r-heistpack:client:openMenu", source, false, true)
        end)
    end
end

--[[ Initialize Application ]]

ServerApplication = ServerApplicationClass.new()
ServerApplication:initialize()
