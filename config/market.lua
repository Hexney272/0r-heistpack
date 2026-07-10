--[[
    All accepted values are specified in `shared/types/__market.lua`.
--]]

return {
    enabled = true, -- Enable or disable the market system.

    -- Drone delivery settings
    droneDeliveryOptions = {
        time = 10,                                                        -- Time (in seconds) before the drone arrives. Minimum recommended: 60 sec for realism.
        objectModel = "ch_prop_casino_drone_02a",                         -- Object model hash for the drone entity.
        bagModel = "xm_prop_x17_bag_01a",                                 -- Bag object model.
        blip = { sprite = 627, color = 60, name = locale("blips.drone") } -- Blip icon and color shown on the map during delivery.
    },

    -- Items available for purchase in the market
    items = {
        { itemName = "heistpack_drone",      price = 5000,  label = "Heist Drone",    scenario = "Vangelico Robbery" },
        { itemName = "gasmask",              price = 1500,  label = "Gas Mask",       scenario = "Vangelico Robbery" },
        { itemName = "heistpack_drill",      price = 10000, label = "Heist Drill",    scenario = "Vangelico Robbery" },
        { itemName = "lockpick",             price = 500,   label = "Lockpick",       scenario = "General Heists" },
        { itemName = "weapon_hackingdevice", price = 2000,  label = "Hacking Device", scenario = "House Robbery,ATM Robbery" },
        { itemName = "heavy_rope",           price = 800,   label = "Heavy Rope",     scenario = "ATM Robbery" },
        { itemName = "weapon_stickybomb",    price = 12000, label = "Sticky Bomb",    scenario = "Bank Heist" },
        { itemName = "heistpack_anchor",     price = 3000,  label = "Anchor",         scenario = "Cargo Ship Robbery" },
        { itemName = "heistpack_grinder",    price = 5000,  label = "Angle Grinder",  scenario = "Ammunation Robbery" }
    }
}
