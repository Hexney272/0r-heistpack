--[[
    Scenario: Fleeca Bank Robbery
    Description: A scenario configuration for a bank robbery at Fleeca Bank.

    This configuration follows the standards defined in config/scenarios/_shared.lua
    See _shared.lua for common structures, animations, models, and naming conventions.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    ---@section GENERAL CONFIGURATION
    -- Distance check for heist completion
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.long,

    -- Map variant support (standard or custom)
    hasCustomMap = false,

    ---@section REWARD CONFIGURATION
    -- Rewards from lootable money objects
    ---@type RewardItem[]
    lootableMoneyRewards = {
        { itemName = "money", chance = 1.0, quantity = { min = 1500, max = 2000 } },
    },

    -- Rewards from customer safe drilling
    ---@type RewardItem[]
    drillCustomerSafeRewards = {
        { itemName = "money", chance = 1.0, quantity = { min = 800, max = 1200 } },
    },

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

    ---@section ANIMATIONS
    -- Scenario-specific animations (using shared animations)
    animations = {
        grabCash = SHARED_CONFIG.animations.grabCash,
        grabMoney = SHARED_CONFIG.animations.grabMoney,
    },

    ---@section MODEL CONFIGURATION
    -- Model references (using shared models)
    models = {
        cashTrolley = SHARED_CONFIG.models.cashTrolley,
        emptyTrolley = SHARED_CONFIG.models.emptyTrolley,
        cashPileSmall = SHARED_CONFIG.models.cashPileSmall,
    },

    ---@section LOCATION CONFIGURATION
    -- Bank locations with standard and cu stom map variants
    locations = {
        -- Location #1: Great Ocean Highway Fleeca Bank
        [1] = {
            standart = {
                -- Entry and center coordinates
                entranceCoords = vector3(-2972.0837, 482.5514, 15.4248),
                centerCoords = vector3(-2957.6653, 481.3287, 15.7068),

                -- Door configurations
                doors = {
                    -- Main safe door
                    {
                        model = -63539571,
                        coords = vector3(-2958.539, 482.271, 15.836),
                        yaw = 357.54,
                        unlockMethod = "safepad",
                        meta = {
                            padInteractCoords = vector3(-2956.521, 482.065, 15.817),
                            openedYaw = 280.0,
                            entrance = true,
                        }
                    },
                    -- Interior safe door
                    {
                        model = -1591004109,
                        coords = vector3(-2956.116, 485.421, 15.995),
                        yaw = 267.54,
                        unlockMethod = "type_breaker",
                        meta = {
                            padInteractCoords = vector3(-2956.581, 483.383, 15.763),
                            noAnimation = true,
                        }
                    },
                },

                -- Cash trolley configurations
                cashTrolleys = {
                    {
                        model = SHARED_CONFIG.models.cashTrolley,
                        coords = vector3(-2957.397, 485.781, 15.148),
                        rotation = vector3(0.0, 0.0, 180.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                    {
                        model = SHARED_CONFIG.models.cashTrolley,
                        coords = vector3(-2954.970, 486.311, 15.148),
                        rotation = vector3(0.0, 0.0, 180.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                    {
                        model = SHARED_CONFIG.models.ingotTrolley,
                        coords = vector3(-2952.795, 485.994, 15.148),
                        rotation = vector3(0.0, 0.0, 130.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                    {
                        model = SHARED_CONFIG.models.cashTrolley,
                        coords = vector3(-2953.341, 482.446, 15.148),
                        rotation = vector3(0.0, 0.0, 0.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                },

                -- Lootable money objects
                lootableMoneys = {
                    {
                        model = SHARED_CONFIG.models.cashPileSmall,
                        coords = vector3(-2954.154, 484.371, 15.525)
                    },
                },

                drillCustomerSafes = {
                    { coords = vector4(-2958.827, 484.095, 15.758, 60.0) },
                },
            },

            custom = {
                entranceCoords = vector3(-2972.0837, 482.5514, 15.4248),
                centerCoords = vector3(-2957.6653, 481.3287, 15.7068),
                -- Door configurations
                doors = {
                    -- Main safe door
                    {
                        model = 2121050683,
                        coords = vector3(-2958.539, 482.271, 15.836),
                        yaw = 357.54,
                        unlockMethod = "safepad",
                        meta = {
                            openedYaw = 280.0,
                            entrance = true,
                        }
                    },
                    -- Interior safe door
                    {
                        model = -1591004109,
                        coords = vector3(-2956.174, 485.423, 16.007),
                        yaw = 267.62,
                        unlockMethod = "type_breaker",
                        meta = {
                            padInteractCoords = vector3(-2956.529, 483.402, 15.971),
                            noAnimation = true,
                        }
                    },
                },
                -- Cash trolley configurations
                cashTrolleys = {
                    {
                        model = SHARED_CONFIG.models.cashTrolley,
                        coords = vector3(-2952.764, 484.284, 15.170),
                        rotation = vector3(0.0, 0.0, 90.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                    {
                        model = SHARED_CONFIG.models.cashTrolley,
                        coords = vector3(-2954.387, 482.525, 15.170),
                        rotation = vector3(0.0, 0.0, 0.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                    {
                        model = SHARED_CONFIG.models.cashTrolley,
                        coords = vector3(-2955.763, 483.067, 15.170),
                        rotation = vector3(0.0, 0.0, -90.0),
                        swapModel = SHARED_CONFIG.models.emptyTrolley
                    },
                },
                lootableMoneys = {},
                drillCustomerSafes = {
                    { coords = vector4(-2958.835, 484.752, 15.884, 60.0) },
                },
            },
        },
    },
}
