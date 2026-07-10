--[[
    Handles the skillbar UI interactions.
    Uses lib.skillCheck for the skillbar implementation.
]]

local Inventory = require "modules.inventory.client"

Skillbar = {}

---@type promise?
local skillbar

-- Show the skillbar with the specified theme.
---@param theme string
---@param meta table?
---@return boolean
function Skillbar.show(theme, meta)
    if skillbar then return false end
    skillbar = promise:new()

    Inventory.disarm()

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "ui:showSkillbar",
        data = { theme = theme, meta = meta or {} },
    })

    return Citizen.Await(skillbar)
end

-- Cancel the active skillbar.
function Skillbar.cancel()
    if not skillbar then
        error("No skillbar is active")
    end

    SendNUIMessage({ action = "ui:cancelSkillbar" })
end

-- Check if a skillbar is currently active.
---@return boolean
function Skillbar.isActive()
    return skillbar ~= nil
end

-- NUI callback for when the skillbar is completed or cancelled.
RegisterNUICallback("nui:skillbarOver", function(success, cb)
    cb(1)

    if skillbar then
        SetNuiFocus(false, false)

        skillbar:resolve(success)
        skillbar = nil
    end
end)
