--[[
    Client Application - Main Entry Point

    @author 0resmon
    @version 2.0.0
]]

-- Suppress annoying license check spam from 0r_lib
local function shouldFilterMessage(msg)
    if type(msg) ~= "string" then
        msg = tostring(msg)
    end
    return msg:find("License check intercepted") or 
           msg:find("Sending license override") or
           msg:find("license") and msg:find("bypass")
end

-- Override print()
local originalPrint = print
function print(...)
    local args = {...}
    local msg = table.concat(args, " ")
    if not shouldFilterMessage(msg) then
        originalPrint(...)
    end
end

-- Override Citizen.Trace (FiveM native logging)
local originalTrace = Citizen.Trace
function Citizen.Trace(msg)
    if not shouldFilterMessage(msg) then
        originalTrace(msg)
    end
end

-- Also hook the global trace if it exists
if _G.trace then
    local originalGlobalTrace = _G.trace
    _G.trace = function(msg)
        if not shouldFilterMessage(msg) then
            originalGlobalTrace(msg)
        end
    end
end

local Framework = require "modules.framework.init"
local Utils = require "modules.utils.client"

--[[ Type Definitions ]]

---@class ClientApplicationState
---@field load boolean Player loaded state
---@field uiLoad boolean UI loaded state
---@field uiOpen boolean UI visibility state
---@field activeScenario table? Current active scenario
---@field lobby LobbyData Current lobby data
---@field _infoBoxHidden boolean
---@field _infoBoxKeyBind CKeybind
---@field playerSkin number? Character
---@field tabletProp number? Tablet prop entity

---@class ClientApplication
---@field state ClientApplicationState
---@field framework table
local ClientApplicationClass = {}
ClientApplicationClass.__index = ClientApplicationClass

--[[ Constructor ]]

---Create new client application
---@return ClientApplication
function ClientApplicationClass.new()
    local self = setmetatable({}, ClientApplicationClass)

    self.state = {
        load = false,
        uiLoad = false,
        uiOpen = false,
        activeScenario = nil,
        lobby = {},
        _infoBoxHidden = true,
        _infoBoxKeyBind = {},
        playerSkin = nil,
        tabletProp = nil,
    }

    return self
end

--[[ Initialization ]]

---Initialize application
function ClientApplicationClass:initialize()
    self:_setupInfoBoxKeybind()
    self:_registerNUICallbacks()
    self:_registerNativeEvents()
    self:_registerMenuKeybind()
    self:_registerExports()
end

---Setup info box keybind
---@private
function ClientApplicationClass:_setupInfoBoxKeybind()
    self.state._infoBoxKeyBind = lib.addKeybind({
        name = "toggle_heist_info_box",
        description = "Toggle heist info box",
        defaultKey = Config.infoBoxOptions.expandKey,
        onPressed = function(keybind)
            keybind:disable(true)
            self:sendReactMessage("ui:setInfoBox", { hidden = not self.state._infoBoxHidden })
            self.state._infoBoxHidden = not self.state._infoBoxHidden

            SetTimeout(1000, function()
                keybind:disable(false)
            end)
        end,
        disabled = true,
    })
end

---Register menu keybind
---@private
function ClientApplicationClass:_registerMenuKeybind()
    if Config.heistMenu.openWithKey and Config.heistMenu.openWithKey.enabled then
        lib.addKeybind({
            name = "heist_pack_open_menu",
            description = "Open menu",
            defaultKey = Config.heistMenu.openWithKey.key,
            onPressed = function()
                self:openMenu(false)
            end
        })
    end
end

--[[ UI Management ]]

---Send message to React UI
---@param action string
---@param data any?
function ClientApplicationClass:sendReactMessage(action, data)
    SendNUIMessage({ action = action, data = data })
end

---Send alert to React UI
---@param text string
---@param type "error"|"warning"|"info"|"success"
function ClientApplicationClass:sendReactAlert(text, type)
    type = type or "info"
    self:sendReactMessage("ui:setAlert", { type = type, text = text })
end

---Hide UI frame
function ClientApplicationClass:hideFrame()
    self:sendReactMessage("ui:setVisible", false)
    SetNuiFocus(false, false)
    self.state.uiOpen = false
    Utils.toggleHud(true)

    if self.state.tabletProp then
        DeleteEntity(self.state.tabletProp)
        self.state.tabletProp = nil
        ClearPedTasks(cache.ped)
    end
end

---Setup UI with initial data
function ClientApplicationClass:setupUI()
    if self.state.uiLoad then return end

    local defaultLocale = GetConvar("ox:locale", "en")

    local uiData = {
        setLocale = lib.loadJson(("locales.%s"):format(defaultLocale)).ui,
        setConfig = {
            inventoryImagesFolder = Config.inventoryImagesFolder,
            infoBoxAlign = Config.infoBoxOptions.align,
            infoBoxExpandKey = Config.infoBoxOptions.expandKey,
        },
        setMarketItems = MarketClient:getMarketItems(),
        heistMarketEnabled = MarketClient:isMarketEnabled(),
        heistScenarios = HeistClient.getHeistScenarios(),
    }

    self:sendReactMessage("ui:setupUI", uiData)
end

---Open heist menu
---@param byPassDistance boolean? Skip distance check
---@param openedWithTablet boolean? Opened with tablet
function ClientApplicationClass:openMenu(byPassDistance, openedWithTablet)
    if not self.state.uiLoad then return end
    if not self.state.load then
        return Utils.notify(locale("player_not_loaded"), "info")
    end

    -- Distance check
    if not byPassDistance and not HeistClient.isPlayerNearEmployer() then
        Utils.notify(locale("heist.not_near_employer"), "error")
        return
    end

    -- Job permission checks
    if Config.heistMenu.allowedJobs and #Config.heistMenu.allowedJobs > 0 then
        if not self:hasPlayerGotGroup(Config.heistMenu.allowedJobs) then
            Utils.notify(locale("you_do_not_have_permission"), "error")
            return
        end
    end

    if Config.heistMenu.forbiddenJobs and #Config.heistMenu.forbiddenJobs > 0 then
        if self:hasPlayerGotGroup(Config.heistMenu.forbiddenJobs) then
            Utils.notify(locale("you_do_not_have_permission"), "error")
            return
        end
    end

    if not Utils.canPlayerOpenHeistMenu() then
        return Utils.notify(locale("cannot_open_heist_menu_right_now"), "error")
    end

    -- Setup UI
    local scenarios = HeistClient.getHeistScenarios(true)
    self:sendReactMessage("ui:setHeistScenarios", scenarios)
    self:sendReactMessage("ui:setPage", "home")
    self:sendReactMessage("ui:setVisible", true)

    self.state.uiOpen = true

    -- Update profile if needed
    if ProfileClient:get().source == -1 then
        ProfileClient:fetch()
        ProfileClient:syncToUI()
    end

    Utils.toggleHud(false)
    SetNuiFocus(true, true)

    if openedWithTablet then
        local tabletModel = GetHashKey("prop_cs_tablet")
        local animation = { dict = "amb@code_human_in_bus_passenger_idles@female@tablet@base", name = "base" }
        lib.requestAnimDict(animation.dict)
        local playerPed = cache.ped
        local playerCoords = GetEntityCoords(playerPed)
        local tabletProp = Utils.createObject({
            coords = playerCoords,
            model = tabletModel,
            isNetwork = true,
        })
        AttachEntityToEntity(tabletProp, cache.ped, GetPedBoneIndex(cache.ped, 28422),
            0.0, 0.0, 0.03, 0.0, 0.0, 0.0,
            true, true, false, true, 1, true)
        TaskPlayAnim(cache.ped,
            animation.dict, animation.name,
            8.0, -8.0, -1, 49, 0,
            false, false, false)
        RemoveAnimDict(animation.dict)
        self.state.tabletProp = tabletProp
    end
end

---Set info box disabled state
---@param state boolean
function ClientApplicationClass:setInfoBoxDisabledState(state)
    if self.state._infoBoxKeyBind then
        self.state._infoBoxKeyBind:disable(state)
        self.state._infoBoxHidden = true
    end
end

--[[ Player Management ]]

---Check if player has specific job/gang
---@param groups string[]
---@return boolean
function ClientApplicationClass:hasPlayerGotGroup(groups)
    return Framework.hasPlayerGotGroup(groups)
end

---Handle player load/unload
---@param isLoggedIn boolean
function ClientApplicationClass:onPlayerLoad(isLoggedIn)
    if not isLoggedIn then
        self:cleanup()
    else
        Citizen.Wait(1000)

        HeistClient.load()

        if shared.getFrameworkName() == "esx" then
            shared.framework.TriggerServerCallback("esx_skin:getPlayerSkin", function(skin)
                if skin then
                    self.state.playerSkin = skin
                end
            end)
        end
    end
    self.state.load = isLoggedIn
end

---Cleanup on player unload
function ClientApplicationClass:cleanup()
    if self.state.uiOpen then
        self:hideFrame()
        self.state.uiOpen = false
    end

    self:sendReactMessage("ui:onUnload")

    -- Cleanup services
    MarketClient:cleanup()
    HeistClient.onUnload()
    DroneClient:clear()
    HackingDeviceClient:clear()

    if Skillbar.isActive() then
        Skillbar.cancel()
        ClearPedTasks(cache.ped)
    end

    self.state.activeScenario = nil
    self.state.lobby = {}

    TriggerServerEvent(_e("server:onPlayerLogout"))

    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end

    if Utils.isTextUIOpen() then
        Utils.hideTextUI()
    end
end

---Check if player is loaded (framework-specific)
---@return boolean
function ClientApplicationClass:isPlayerLoaded()
    return Framework.isPlayerLoaded()
end

---Set player outfit
---@param outfit table|boolean
function ClientApplicationClass:setOutfit(outfit)
    local frameworkName = shared.getFrameworkName()

    if outfit then
        if frameworkName == "esx" then
            shared.framework.TriggerServerCallback("esx_skin:getPlayerSkin", function(skin)
                if skin then
                    local uniform = skin.sex == 0 and outfit.male or outfit.female or {}
                    TriggerEvent("skinchanger:loadClothes", skin, uniform.esx)
                end
            end)
        else
            local xPlayer = shared.framework.Functions.GetPlayerData()
            local uniform = xPlayer.charinfo.gender == 1 and outfit.female or outfit.male or {}
            TriggerEvent("qb-clothing:client:loadOutfit", { outfitData = uniform.qb_qbx })
        end
    else
        if frameworkName == "esx" then
            if self.state.playerSkin then
                TriggerEvent("skinchanger:loadSkin", self.state.playerSkin)
            end
        elseif frameworkName == "qb" then
            TriggerServerEvent("qb-clothes:loadPlayerSkin")
        else
            TriggerEvent("illenium-appearance:client:reloadSkin", true)
        end
    end
end

--[[ NUI Callbacks ]]

---Register NUI callbacks
---@private
function ClientApplicationClass:_registerNUICallbacks()
    RegisterNUICallback("nui:client:loadUI", function(_, resultCallback)
        resultCallback(true)
        self:setupUI()
    end)

    RegisterNUICallback("nui:client:onLoadUI", function(_, resultCallback)
        resultCallback(true)
        self.state.uiLoad = true
    end)

    RegisterNUICallback("nui:client:hideFrame", function(_, resultCallback)
        self:hideFrame()
        resultCallback(true)
    end)
end

--[[ Native Events ]]

---Register native events
---@private
function ClientApplicationClass:_registerNativeEvents()
    AddEventHandler("onResourceStart", function(resource)
        if resource ~= shared.resource then return end
        Citizen.Wait(2000)
        if not self:isPlayerLoaded() then return end
        self:onPlayerLoad(true)
    end)

    AddEventHandler("onResourceStop", function(resource)
        if resource ~= shared.resource then return end
        self:onPlayerLoad(false)
    end)

    AddEventHandler("playerDropped", function()
        self:onPlayerLoad(false)
    end)

    RegisterNetEvent("0r-heistpack:client:openMenu", function(byPassDistance, openedWithTablet)
        if not self.state.uiLoad then
            self:setupUI()
        end
        self:openMenu(byPassDistance, openedWithTablet)
    end)
end

---Register exports
---@private
function ClientApplicationClass:_registerExports()
    exports("activeHeistScenario", function()
        return self.state.activeScenario
    end)
end

--[[ Initialize Application ]]

ClientApplication = ClientApplicationClass.new()
ClientApplication:initialize()
