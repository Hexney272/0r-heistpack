--[[
    Scenario: Bobcat Robbery
    Description: A high-security heist scenario targeting Bobcat Security facility.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

--[[ Coords set for GABZ Bobcat Map ]]

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.long,

    -- Bobcat facility coordinates
    facilityEntranceCoords = vector3(919.1844, -2121.6697, 30.4927),
    facilityCenterCoords = vector3(888.3011, -2123.5078, 31.2303),

    redRoomVault = {
        startModel = "des_vaultdoor001_start",
        endModel   = "des_vaultdoor001_end",
        coords     = vector4(888.121, -2129.869, 29.230, 85.0),
        bomb       = { coords = vector3(887.953, -2130.167, 31.577), heading = 12.552 },
    },

    ---@section REWARD CONFIGURATION
    -- Rewards from trolley collection
    trolleyRobberyRewards = {
        ---@type RewardItem[]
        money = {
            { itemName = "money", chance = 1.0, quantity = { min = 2000, max = 2500 } },
        },
        ---@type RewardItem[]
        ingot = {
            { itemName = "gold", chance = 1.0, quantity = { min = 1, max = 1 } },
        },
    },

    doors = {
        --[inside - entrance - 1]
        {
            model = -2023754432,
            coords = vector3(908.440, -2121.276, 31.381),
            yaw = 85.0,
            unlockMethod = "bomb",
            meta = {
                centerOffset = vector3(0.75, -0.1, 0.0),
                entrance = true,
                delete = true,
            },

        },
        --[outside - entrance - 2]
        {
            model = -1514454788,
            coords = vector3(889.914, -2107.781, 30.236),
            yaw = 175.0,
            unlockMethod = "keypad",
            meta = {
                noAnimation = true,
                padInteractCoords = vector3(892.294, -2107.850, 31.497),
                entrance = true,
            },
        },
    },

    --[[ Armed and armored guards at the facility ]]
    guards = {
        vector4(882.2521, -2111.5168, 31.2254, 294.4007),
        vector4(881.1685, -2117.3594, 31.2303, 168.3316),
        vector4(882.6818, -2132.6401, 31.2303, 256.5937),
        vector4(896.6878, -2133.2922, 31.2303, 292.6142),
        vector4(899.2945, -2120.5000, 31.2303, 266.4005),
        vector4(907.0139, -2115.9927, 31.2303, 243.9417),
    },

    cashTrolleyGroups = {
        {
            model = SHARED_CONFIG.models.cashTrolley,
            coords = vector3(888.883, -2121.917, 30.703),
            rotation = vector3(0.0, 0.0, 180.0),
            swapModel = SHARED_CONFIG.models.emptyTrolley
        },
        {
            model = SHARED_CONFIG.models.cashTrolley,
            coords = vector3(890.101, -2127.673, 30.703),
            rotation = vector3(0.0, 0.0, 90.0),
            swapModel = SHARED_CONFIG.models.emptyTrolley
        },
        {
            model = SHARED_CONFIG.models.cashTrolley,
            coords = vector3(886.304, -2127.651, 30.703),
            rotation = vector3(0.0, 0.0, 0.0),
            swapModel = SHARED_CONFIG.models.emptyTrolley
        },
    },
}
