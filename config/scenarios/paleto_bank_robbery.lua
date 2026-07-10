--[[
    Scenario: Paleto Bank Robbery
    Description: A scenario configuration for a bank robbery at Paleto Bank.

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
        plantBomb = SHARED_CONFIG.animations.plantBomb,
    },

    ---@section MODEL CONFIGURATION
    -- Model references (using shared models)
    models = {
        cashTrolley = SHARED_CONFIG.models.cashTrolley,
        ingotTrolley = SHARED_CONFIG.models.ingotTrolley,
        emptyTrolley = SHARED_CONFIG.models.emptyTrolley,
        bomb = SHARED_CONFIG.models.bomb,
        bag = SHARED_CONFIG.models.bag,
        cashPile = SHARED_CONFIG.models.cashPile,
    },

    ---@section SECURITY CONFIGURATION
    -- Electric box configuration for disabling security
    disableSecurityOptions = {
        model = "tr_prop_tr_elecbox_01a",
        coords = vector4(-100.90, 6478.69, 30.45, 135.0),
    },

    ---@section LOCATION CONFIGURATION
    -- Bank entrance coordinates (standard and custom variants)
    bankEntranceCoords = {
        standart = vector3(-115.3053, 6458.3203, 31.4684),
        custom = vector3(-115.3053, 6458.3203, 31.4684),
    },

    -- Bank center coordinates (for distance checking)
    bankCenterCoords = {
        standart = vector3(-105.8056, 6467.8882, 31.6219),
        custom = vector3(-105.8056, 6467.8882, 31.6219),
    },

    ---@section DOOR CONFIGURATION
    -- Door configurations (following doorStructure from _shared.lua)
    doors = {
        standart = {
            -- Entrance - Left door
            {
                model = -353187150,
                coords = vector3(-111.480, 6463.940, 31.985),
                yaw = 315.0,
                unlockMethod = "bomb",
                partner = 2,
                meta = {
                    centerOffset = vector3(0.75, -0.1, 0.0),
                    entrance = true
                },
            },
            -- Entrance - Right door
            {
                model = -1666470363,
                coords = vector3(-109.650, 6462.110, 31.985),
                yaw = 315.0,
                unlockMethod = "bomb",
                partner = 1,
                meta = {
                    centerOffset = vector3(-0.75, -0.1, 0.0),
                    entrance = true
                },
            },
            -- Inside - Big safe door
            {
                model = -1185205679,
                coords = vector3(-104.605, 6473.444, 31.795),
                yaw = 46.0,
                unlockMethod = "keypad",
                meta = {
                    padInteractCoords = vector3(-105.902, 6472.146, 31.866),
                    openedYaw = 150.0,
                }
            },
        },
        custom = {
            -- Entrance - Front door
            {
                model = 2063730765,
                coords = vector3(-110.642, 6462.013, 31.793),
                yaw = 135.0,
                unlockMethod = "bomb",
                meta = {
                    centerOffset = vector3(0.75, -0.1, 0.0),
                    entrance = true
                },
            },
            -- Entrance - Back door
            {
                model = 1248599813,
                coords = vector3(-96.709, 6474.057, 31.788),
                yaw = 134.90,
                unlockMethod = "keypad",
                meta = {
                    padInteractCoords = vector3(-95.512, 6473.063, 31.924),
                    noAnimation = true,
                },
            },
            -- Inside - Big safe door
            {
                model = -2050208642,
                coords = vector3(-100.242, 6464.549, 31.885),
                yaw = 225.0,
                unlockMethod = "keypad",
                meta = {
                    padInteractCoords = vector3(-101.919, 6462.926, 32.069),
                    noAnimation = true,
                }
            },
        }
    },

    ---@section TROLLEY CONFIGURATION
    -- Cash trolley configurations (following trolleyStructure from _shared.lua)
    cashTrolleyGroups = {
        standart = {
            {
                model = SHARED_CONFIG.models.cashTrolley,
                coords = vector3(-106.661, 6477.467, 31.100),
                rotation = vector3(0.0, 0.0, 270.0),
                swapModel = SHARED_CONFIG.models.emptyTrolley
            },
            {
                model = SHARED_CONFIG.models.cashTrolley,
                coords = vector3(-102.340, 6476.716, 31.100),
                rotation = vector3(0.0, 0.0, 90.0),
                swapModel = SHARED_CONFIG.models.emptyTrolley
            },
            {
                model = SHARED_CONFIG.models.ingotTrolley,
                coords = vector3(-104.744, 6479.259, 31.140),
                rotation = vector3(0.000, 0.000, 170.0),
                swapModel = SHARED_CONFIG.models.emptyTrolley,
                ingot = true,
            },
        },
        custom = {
            {
                model = SHARED_CONFIG.models.cashTrolley,
                coords = vector3(-98.046, 6463.834, 31.107),
                rotation = vector3(0.0, 0.0, 180.0),
                swapModel = SHARED_CONFIG.models.emptyTrolley
            },
            {
                model = SHARED_CONFIG.models.cashTrolley,
                coords = vector3(-96.982, 6460.183, 31.107),
                rotation = vector3(0.0, 0.0, 0.0),
                swapModel = SHARED_CONFIG.models.emptyTrolley
            },
            {
                model = SHARED_CONFIG.models.ingotTrolley,
                coords = vector3(-101.202, 6461.888, 31.107),
                rotation = vector3(0.000, 0.000, -90.0),
                swapModel = SHARED_CONFIG.models.emptyTrolley,
                ingot = true,
            },
        },
    },
}
