--[[
    Scenario: House Robbery
    Description: A scenario configuration for house robbery with multiple interior locations.

    This configuration follows the standards defined in config/scenarios/_shared.lua
    See _shared.lua for common structures, animations, models, and naming conventions.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    ---@section GENERAL CONFIGURATION
    -- Distance check for heist completion
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.short,

    ---@section VEHICLE CONFIGURATION
    vehicles = {
        { model = "bison" },
    },

    ---@section BUCKET CONFIGURATION
    bucketIdFormat = "1%d", -- Format for bucket IDs specific to this scenario <1interiorId>

    ---@section EQUIPMENT CONFIGURATION
    hackingDeviceOptions = {
        itemName = "weapon_hackingdevice",
    },

    ---@section PROP PRICING
    -- Movable prop loot prices
    movablePropLootPrices = {
        prop_tv_flat_03 = 800,       -- TV
        prop_console_01 = 1200,      -- Gaming Console
        prop_tv_03 = 300,            -- Old TV
        prop_vcr_01 = 450,           -- VCR
        prop_micro_01 = 600,         -- Microwave
        prop_coffee_mac_02 = 700,    -- Coffee Machine
        prop_toaster_01 = 400,       -- Toaster
        prop_tapeplayer_01 = 350,    -- Tape Player
        prop_mp3_dock = 500,         -- MP3 Dock
        prop_monitor_w_large = 1500, -- Large Monitor
        prop_laptop_01a = 2000,      -- Laptop
        prop_printer_01 = 1000,      -- Printer
        prop_keyboard_01b = 300,     -- Keyboard
    },

    ---@section REWARD CONFIGURATION
    -- Loot rewards configuration, defining possible items and their chances
    ---@type table<string, RewardItem[]>
    lootRewardItems = {
        livingroom = {
            { itemName = "gold_necklace", chance = 0.3, quantity = { min = 1, max = 1 } },
            { itemName = "silver_ring",   chance = 0.5, quantity = { min = 1, max = 2 } },
            { itemName = "money",         chance = 0.7, quantity = { min = 50, max = 200 } },
        },
        kitchen = {
            { itemName = "tosti",      chance = 0.6, quantity = { min = 1, max = 2 } },
            { itemName = "sandwich",   chance = 0.6, quantity = { min = 1, max = 2 } },
            { itemName = "gold_chain", chance = 0.2, quantity = { min = 1, max = 1 } },
        },
        methpack = {
            { itemName = "meth_pack", chance = 1.0, quantity = { min = 1, max = 1 } },
        },
        cabin = {
            { itemName = "plastic",      chance = 0.7, quantity = { min = 1, max = 4 } },
            { itemName = "steel",        chance = 0.5, quantity = { min = 1, max = 4 } },
            { itemName = "copper",       chance = 0.5, quantity = { min = 1, max = 4 } },
            { itemName = "electronics",  chance = 0.4, quantity = { min = 1, max = 2 } },
            { itemName = "cryptostick",  chance = 0.4, quantity = { min = 1, max = 1 } },
            { itemName = "gold_chain",   chance = 0.2, quantity = { min = 1, max = 1 } },
            { itemName = "diamond_ring", chance = 0.1, quantity = { min = 1, max = 1 } },
        },
        chest = {
            { itemName = "money",        chance = 0.8,  quantity = { min = 100, max = 300 } },
            { itemName = "gold_chain",   chance = 0.3,  quantity = { min = 1, max = 1 } },
            { itemName = "diamond_ring", chance = 0.15, quantity = { min = 1, max = 1 } },
        },
        watch_case = {
            { itemName = "luxury_watch", chance = 1.0, quantity = { min = 1, max = 1 } },
        },
        electronics = {
            { itemName = "tablet",      chance = 0.5, quantity = { min = 1, max = 1 } },
            { itemName = "smartphone",  chance = 0.7, quantity = { min = 1, max = 1 } },
            { itemName = "laptop",      chance = 0.3, quantity = { min = 1, max = 1 } },
            { itemName = "cryptostick", chance = 0.4, quantity = { min = 1, max = 1 } },
        },
        drugpack = {
            { itemName = "cocaine_bag", chance = 0.5, quantity = { min = 1, max = 2 } },
            { itemName = "weed_bag",    chance = 0.5, quantity = { min = 1, max = 2 } },
            { itemName = "meth_bag",    chance = 0.5, quantity = { min = 1, max = 2 } },
        },
        luxury_alcohol = {
            { itemName = "luxury_whiskey", chance = 1.0, quantity = { min = 1, max = 1 } },
        },
        money = {
            { itemName = "money", chance = 1.0, quantity = { min = 500, max = 1000 } },
        },
    },

    ---@section ANIMATIONS
    -- Animation configurations for different loot interactions
    animations = {
        search = SHARED_CONFIG.animations.search,
        grab = SHARED_CONFIG.animations.grabCash,
        carry = SHARED_CONFIG.animations.grabMoney,
        carrying = SHARED_CONFIG.animations.carryBox,
    },

    ---@section MODEL CONFIGURATION
    -- Model references (using shared models where applicable)
    models = {
        methBag = "tr_prop_meth_smallbag_01a",
        watchCase = "vw_prop_vw_watch_case_01b",
        electronics = "ex_office_swag_electronic2",
        drugBag = "ex_office_swag_drugbags",
        whiskey = "prop_whiskey_bottle",
        wine = "prop_wine_bot_01",
        whiskeySmall = "p_whiskey_bottle_s",
        cashStack = SHARED_CONFIG.models.cashStack,
    },

    ---@section CARRY POSITIONS
    -- Common carry positions for props
    carryPositions = {
        standard = SHARED_CONFIG.carryPositions.standard,
        microwave = SHARED_CONFIG.carryPositions.microwave,
        monitor = SHARED_CONFIG.carryPositions.monitor,
    },

    ---@section LOCATION CONFIGURATION
    -- Interior configurations for house robbery scenarios
    ---@type HouseRobberyInterior[]
    interiors = {
        -- Location #1: House Interior 1
        [1] = {
            locations = {
                entrance = vector4(-947.5399, -928.0118, 2.1453, 303.1632),
                inside = vector4(266.1870, -1007.2487, -102.0085, 8.8803),
                exit = vector4(265.9629, -1007.4608, -101.0085, 184.1298),
                outside = vector4(-947.4415, -927.9370, 2.1453, 304.3713),
            },
            loots = {
                {
                    interaction = "search",
                    zone = {
                        center = vector3(266.3200, -999.3959, -99.5),
                        size = vector3(1.0, 0.5, 1.5),
                        rotation = 270.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(265.9460, -999.4103, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(264.3655, -995.1135, -99.45),
                        size = vector3(1.0, 0.5, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "kitchen",
                    markerCoords = vector3(264.34, -995.41, -99.25),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(266.1663, -996.7256, -99.45),
                        size = vector3(0.5, 1.0, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "kitchen",
                    markerCoords = vector3(265.83, -996.76, -99.25),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(259.8440, -1004.3216, -99.0),
                        size = vector3(1.25, 0.5, 1.75),
                        rotation = 0.0,
                    },
                    rewardKey = "cabin",
                    markerCoords = vector3(259.72, -1004.04, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(261.3865, -1002.2057, -99.5),
                        size = vector3(1.25, 0.5, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(261.4, -1002.48, -99.01),
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(262.13, -1000.6, -99.3),
                        create = true,
                        model = "tr_prop_meth_smallbag_01a",
                    },
                    rewardKey = "methpack",
                },
                {
                    interaction = "carry",
                    prop = { coords = vector3(262.69, -1001.85, -99.29), model = "prop_tv_flat_03" },
                    zone = {
                        center = vector3(262.69, -1001.85, -99.3),
                        size = vector3(0.8, 0.2, 1.0),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.1),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.3, -1.2, 0.23),
                            rotation = vector3(0.0, 0.0, 270.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = { coords = vector3(263.29, -1001.85, -99.30), model = 1942724096 },
                    zone = {
                        center = vector3(263.29, -1001.85, -99.30),
                        size = vector3(0.4, 0.4, 0.15),
                        rotation = 355.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.14),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.6, -1.6, 0.4),
                            rotation = vector3(0.0, 90.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = { coords = vector3(256.73, -995.45, -98.86), model = -897601557 },
                    zone = {
                        center = vector3(256.73, -995.45, -98.86),
                        size = vector3(0.8, 0.4, 0.6),
                        rotation = 45.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.12, -0.32, 0.1),
                            rotation = vector3(0.0, 0.0, 90.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.1, -1.2, 0.24),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = { coords = vector3(256.67, -995.38, -99.31), model = 330240957 },
                    zone = {
                        center = vector3(256.67, -995.38, -99.31),
                        size = vector3(0.8, 0.5, 0.2),
                        rotation = 45.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.02, -0.2, -0.1),
                            rotation = vector3(0.0, 0.0, 90.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.5, -2.0, 0.24),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
            },
        },
        -- Location #2: House Interior 2
        [2] = {
            locations = {
                entrance = vector4(-1034.9171, -1227.6636, 6.3, 123.0),
                inside = vector4(346.5565, -1010.9794, -100.1963, 1.1811),
                exit = vector4(346.6235, -1013.4670, -99.1963, 273.2429),
                outside = vector4(-1036.7915, -1228.7068, 5.8039, 120.3698),
            },
            loots = {
                {
                    interaction = "search",
                    zone = {
                        center = vector3(351.2455, -993.1677, -99.23),
                        size = vector3(1.0, 0.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "cabin",
                    markerCoords = vector3(351.3, -993.51, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(350.0537, -993.1526, -99.23),
                        size = vector3(1.0, 0.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "cabin",
                    markerCoords = vector3(350.08, -993.49, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(348.7398, -994.8771, -99.5),
                        size = vector3(.8, 0.8, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(349.2, -994.79, -99.5),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(351.0486, -999.6164, -99.23),
                        size = vector3(1.0, 0.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(351.1237, -999.2170, -99.1963),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(352.5577, -998.7480, -100.0),
                        size = vector3(1.1, 1.1, 0.8),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(351.8733, -998.6984, -100.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(337.5140, -995.0616, -99.2),
                        size = vector3(0.8, 0.8, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(338.14, -994.98, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(343.8021, -1003.7859, -99.7),
                        size = vector3(1.0, 0.5, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "kitchen",
                    markerCoords = vector3(343.76, -1003.27, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(344.3734, -1001.3170, -99.2),
                        size = vector3(0.5, 1.0, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "kitchen",
                    markerCoords = vector3(344.03, -1001.25, -99.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(339.2138, -1003.8182, -99.7),
                        size = vector3(1.0, 1.0, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(339.25, -1003.43, -99.0),
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(344.7, -1002.03, -98.97),
                        model = "prop_micro_01",
                    },
                    zone = {
                        center = vector3(344.7, -1002.03, -98.97),
                        size = vector3(0.4, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.05, -0.1),
                            rotation = vector3(0.0, 0.0, 180.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.15, -1.0, 0.3),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(342.74, -1003.89, -98.99),
                        model = "prop_coffee_mac_02",
                    },
                    zone = {
                        center = vector3(342.74, -1003.89, -98.99),
                        size = vector3(0.4, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.08),
                            rotation = vector3(0.0, 90.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.25, -1.0, 0.3),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(341.78, -1003.87, -99.06),
                        model = "prop_toaster_01",
                    },
                    zone = {
                        center = vector3(341.78, -1003.87, -99.06),
                        size = vector3(0.4, 0.4, 0.4),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.05, -0.05),
                            rotation = vector3(0.0, 0.0, 180.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.25, -1.3, 0.3),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(341.61, -1001.1, -99.01),
                        model = "prop_tapeplayer_01",
                    },
                    zone = {
                        center = vector3(341.61, -1001.1, -99.01),
                        size = vector3(0.8, 0.3, 0.4),
                        rotation = 65.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.07, -0.1),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.6, -1.8, 0.3),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(341.19, -996.65, -99.657),
                        create = true,
                        model = "vw_prop_vw_watch_case_01b",
                    },
                    rewardKey = "watch_case",
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(352.567, -998.855, -99.65),
                        create = true,
                        model = "ex_office_swag_electronic2",
                    },
                    rewardKey = "electronics",
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(349.34, -996.82, -99.53),
                        create = true,
                        model = "tr_prop_meth_smallbag_01a",
                    },
                    rewardKey = "methpack",
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(338.59, -1001.75, -99.45),
                        create = true,
                        model = "ex_office_swag_drugbags",
                    },
                    rewardKey = "drugpack",
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector4(341.90, -1001.96, -99.28, 90.0),
                        create = true,
                        model = "prop_whiskey_bottle",
                    },
                    rewardKey = "luxury_alcohol",
                },
            }
        },
        -- Location #3: House Interior 3
        [3] = {
            locations = {
                entrance = vector4(965.0201, -541.5541, 59.72, 0.0),
                inside = vector4(-1289.9222, 448.1836, 96.9025, 185.8532),
                exit = vector4(-1289.7684, 450.1968, 97.8136, 267.5903),
                outside = vector4(965.7222, -542.5897, 59.3591, 218.0318),
            },
            loots = {
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1287.1047, 447.1712, 97.89),
                        size = vector3(1.0, 0.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "kitchen",
                    markerCoords = vector3(-1287.38, 446.78, 98.09),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1290.7418, 432.4422, 94.0),
                        size = vector3(0.5, 1.0, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(-1290.34, 432.27, 94.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1282.9490, 445.8801, 93.7),
                        size = vector3(1.0, 0.5, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "livingroom",
                    markerCoords = vector3(-1282.89, 445.53, 93.7),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1282.0482, 432.1285, 97.5),
                        size = vector3(0.5, 1.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(-1282.56, 432.52, 97.5),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1293.2720, 451.4981, 90.29),
                        size = vector3(0.5, 1.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(-1292.92, 451.46, 90.49),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1285.86, 456.99, 90.29),
                        size = vector3(1.0, 1.0, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(-1285.86, 456.99, 90.49),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1288.0121, 455.2150, 90.29),
                        size = vector3(1.0, 0.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(-1287.85, 455.53, 90.49),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1286.1796, 459.0415, 90.0),
                        size = vector3(0.5, 0.5, 1.0),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(-1286.51, 459.14, 90.0),
                },
                {
                    interaction = "search",
                    zone = {
                        center = vector3(-1285.7836, 439.2217, 94.09),
                        size = vector3(1.5, 1.5, 1.5),
                        rotation = 0.0,
                    },
                    rewardKey = "chest",
                    markerCoords = vector3(-1286.08, 438.44, 94.29),
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1282.16, 444.06, 98.07),
                        model = "prop_micro_02",
                    },
                    zone = {
                        center = vector3(-1282.16, 444.06, 98.07),
                        size = vector3(0.5, 0.5, 0.6),
                        rotation = 271.44,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.03),
                            rotation = vector3(0.0, 0.0, 180.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.15, -1.0, 0.27),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1282.96, 447.72, 98.01),
                        model = "prop_toaster_01",
                    },
                    zone = {
                        center = vector3(-1282.96, 447.72, 98.01),
                        size = vector3(0.4, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.2),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.2, -1.0, 0.27),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(-1287.37, 444.81, 98.08),
                        model = "prop_wine_bot_01",
                    },
                    zone = {
                        center = vector3(-1287.37, 444.81, 98.08),
                        size = vector3(0.4, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    rewardKey = "luxury_alcohol",
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1290.96, 434.4, 97.59),
                        model = "prop_mp3_dock",
                    },
                    zone = {
                        center = vector3(-1290.96, 434.4, 97.59),
                        size = vector3(0.8, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.2),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.2, -1.3, 0.27),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(-1290.86, 433.23, 97.62),
                        model = "p_whiskey_bottle_s",
                    },
                    zone = {
                        center = vector3(-1290.86, 433.23, 97.62),
                        size = vector3(0.4, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    rewardKey = "luxury_alcohol",
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1290.89, 433.54, 94.09),
                        model = "prop_mp3_dock",
                    },
                    zone = {
                        center = vector3(-1290.89, 433.54, 94.09),
                        size = vector3(0.4, 1.0, 1.0),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.1, -0.12),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.2, -1.3, 0.27),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1293.09, 458.21, 90.01),
                        model = "prop_monitor_w_large",
                    },
                    zone = {
                        center = vector3(-1293.09, 458.21, 90.4),
                        size = vector3(1.0, 0.2, 0.6),
                        rotation = 80.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.05, -0.3),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.6, -2.0, 0.27),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1293.12, 457.37, 90.01),
                        model = "prop_monitor_w_large",
                    },
                    zone = {
                        center = vector3(-1293.12, 457.37, 90.4),
                        size = vector3(1.0, 0.2, 0.6),
                        rotation = 95.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.05, -0.3),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.4, -2.0, 0.27),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1291.89, 460.16, 90.05),
                        model = "prop_laptop_01a",
                    },
                    zone = {
                        center = vector3(-1291.89, 460.16, 90.05),
                        size = vector3(0.8, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.02, -0.18),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.3, -1.55, 0.27),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1286.1, 459.97, 90.36),
                        model = "prop_printer_01",
                    },
                    zone = {
                        center = vector3(-1286.1, 459.97, 90.36),
                        size = vector3(0.8, 0.4, 0.6),
                        rotation = 0.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.05, -0.18),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(0.15, -1.58, 0.27),
                            rotation = vector3(0.0, 0.0, 0.0),
                        },
                    },
                },
                {
                    interaction = "carry",
                    prop = {
                        coords = vector3(-1292.71, 457.58, 90.01),
                        model = "prop_keyboard_01b",
                    },
                    zone = {
                        center = vector3(-1292.71, 457.58, 90.01),
                        size = vector3(0.8, 0.2, 0.2),
                        rotation = 95.0,
                    },
                    positions = {
                        onHolding = {
                            offset = vector3(0.0, -0.05, -0.18),
                            rotation = vector3(0.0, 0.0, 0.0),
                            boneId = 28422,
                        },
                        onVehicle = {
                            offset = vector3(-0.5, -1.65, 0.28),
                            rotation = vector3(0.0, 0.0, 90.0),
                        },
                    },
                },
                {
                    interaction = "grab",
                    prop = {
                        coords = vector3(-1284.249, 443.757, 97.856),
                        create = true,
                        model = "h4_prop_h4_cash_stack_01a",
                    },
                    zone = {
                        center = vector3(-1284.249, 443.757, 97.856),
                        size = vector3(0.6, 0.6, 0.6),
                        rotation = 0.0,
                    },
                    rewardKey = "money",
                },
            }
        },
    },
}
