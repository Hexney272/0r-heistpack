---@class InteriorManager
---@field private onEnter? fun() Callback when entering interior
---@field private onExit? fun() Callback when exiting interior
---@field private isInside boolean Current interior state
--- Manages interior teleportation with screen fade effects
--- Used for scenarios with indoor/outdoor transitions (house robbery, etc.)
local InteriorManager = {}
InteriorManager.__index = InteriorManager

---@class InteriorManagerOptions
---@field onEnter? fun() Callback when entering interior
---@field onExit? fun() Callback when exiting interior

---Create new interior manager instance
---@param options InteriorManagerOptions
---@return InteriorManager
function InteriorManager.new(options)
    ---@type InteriorManager
    local self = setmetatable({}, InteriorManager)

    self.onEnter = options.onEnter
    self.onExit = options.onExit
    self.isInside = false

    return self
end

---Enter interior with fade effect
---@param serverCallback fun(data: table): table Server callback that handles teleport
---@param data table Data to send to server
---@return boolean success
function InteriorManager:enter(serverCallback, data)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Citizen.Wait(100)
    end

    local response = serverCallback(data)

    if not response or not response.success then
        DoScreenFadeIn(500)
        return false
    end

    self.isInside = true

    if self.onEnter then
        self.onEnter()
    end

    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do
        Citizen.Wait(100)
    end

    return true
end

---Exit interior with fade effect
---@param serverCallback fun(data: table): table Server callback that handles teleport
---@param data table Data to send to server
---@return boolean success
function InteriorManager:exit(serverCallback, data)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Citizen.Wait(100)
    end

    local response = serverCallback(data)

    if not response or not response.success then
        DoScreenFadeIn(500)
        return false
    end

    self.isInside = false

    if self.onExit then
        self.onExit()
    end

    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do
        Citizen.Wait(100)
    end

    return true
end

---Check if player is inside interior
---@return boolean
function InteriorManager:isPlayerInside()
    return self.isInside
end

---Set inside state manually
---@param inside boolean
function InteriorManager:setInsideState(inside)
    self.isInside = inside
end

---Clear manager
function InteriorManager:clear()
    self.isInside = false
end

return InteriorManager
