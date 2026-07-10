--[[
    Scenario Configuration: Store Robbery
    Description: Configuration file for store robbery scenarios.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.short,

    -- Map variant support (standard or custom)
    hasCustomMap = false,

    robberyVehicles = {
        { model = "bison" },
    },

    cashierRobbery = {
        model = "prop_poly_bag_money",
        spawnOffset = vector3(0.5, 0.5, 0.0), -- Offset from the cashier position

        ---@type RewardItem[]
        rewards = {
            { itemName = "cash", chance = 1.0, quantity = { min = 1000, max = 1000 } },
        }
    },

    ---@type table<string, RewardItem[]>
    lootRewardItems = {
        liquor_shelf = {
            { itemName = "whiskey", chance = 0.7, quantity = { min = 1, max = 3 } },
            { itemName = "vodka",   chance = 0.5, quantity = { min = 1, max = 2 } },
            { itemName = "beer",    chance = 0.9, quantity = { min = 2, max = 6 } },
        },
        drinks_shelf = {
            { itemName = "soda_can",     chance = 0.8, quantity = { min = 1, max = 5 } },
            { itemName = "energy_drink", chance = 0.6, quantity = { min = 1, max = 3 } },
            { itemName = "water_bottle", chance = 0.9, quantity = { min = 1, max = 4 } },
        },
        cash_register = {
            { itemName = "cash", chance = 1.0, quantity = { min = 200, max = 800 } },
        },
    },

    animationOptions = {
        openMiniSafe = {
            dict = "amb@medic@standing@tendtodead@idle_a",
            name = "idle_a",
        },
        lootMiniSafe = {
            dict = "anim@heists@ornate_bank@grab_cash",
            name = "grab",
        },
        search = {
            dict = "missexile3",
            name = "ex03_dingy_search_case_base_michael",
            duration = 3000,
        },
        carry = {
            dict = "anim@scripted@heist@ig1_table_grab@cash@male@",
            name = "grab",
            duration = 2000,
        },
        carrying = {
            dict = "anim@heists@box_carry@",
            name = "idle",
        },
        throwCashRegister = {
            dict = "weapons@projectile@",
            name = "throw_l_fb_stand",
            duration = 1000,
        },
    },

    movablePropLootPrices = {
        prop_juice_dispenser = 1000, -- Juice Dispenser
        prop_gumball_01      = 1000, -- Gumball Machine
        prop_atm_01          = 3000, -- ATM
    },

    locations = {
        standart = {
            [1] = {
                cashier = {
                    model = "mp_m_shopkeep_01",
                    coords = vector4(2555.2209, 380.8832, 107.6161, 0.0),
                },

                lootableCashRegisters = {
                    {
                        prop = {
                            model = 303280717,
                            holdingModel = "prop_till_01_dam",
                            coords = vector3(2554.875, 381.386, 108.738),
                        },
                        zone = {
                            center = vector3(2554.875, 381.386, 108.738),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 0.0,
                        },
                        rewardKey = "cash_register",
                    },
                    {
                        prop = {
                            model = 303280717,
                            holdingModel = "prop_till_01_dam",
                            coords = vector3(2557.207, 381.293, 108.738)
                        },
                        zone = {
                            center = vector3(2557.207, 381.293, 108.738),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 0.0,
                        },
                        rewardKey = "cash_register"
                    },
                },

                loots = {
                    {
                        interaction = "search",
                        coords = vector3(2553.582, 380.466, 108.623),
                        rewardKey = "liquor_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(2552.490, 385.417, 108.623),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_juice_dispenser",
                            coords = vector3(2552.247, 382.737, 108.619),
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
                        markerCoords = vector3(2552.537, 382.719, 108.9),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_gumball_01",
                            coords = vector3(2554.375, 390.822, 107.623)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.2, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(2554.363, 390.469, 108.623),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = 7254050, coords = vector3(2548.414, 385.662, 108.682)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(0.25, -1.3, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(378.976, 333.716, 103.83),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = 810004487, coords = vector3(2548.480, 386.258, 108.498)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.5, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(379.551, 333.513, 103.802)
                    },
                },

                miniSafe = {
                    body = { model = "m23_2_prop_m32_arcade_safe_body", coords = vector4(2551.35, 387.74, 107.643, 270.0) },
                    door = {
                        model = "m23_2_prop_m32_arcade_safe_door",
                        coords = vector4(2551.35, 387.75, 107.643, 270.0),
                        openCoords = vector4(2551.35, 387.75, 107.643, 340.0),
                    },
                    inside = {
                        { model = "ex_office_swag_jewelwatch2", coords = vector4(2551.62, 387.97, 107.63, 0.0) }
                    },
                    zone = {
                        coords = vector3(2551.5962, 387.9576, 107.643),
                        size = vector3(0.8, 0.8, 1.5),
                        rotation = 270.0,
                    },
                    rewards = {
                        { itemName = "gold_bar", chance = 0.5, quantity = { min = 1, max = 3 } },
                        { itemName = "diamond",  chance = 0.3, quantity = { min = 1, max = 2 } },
                        { itemName = "cash",     chance = 1.0, quantity = { min = 500, max = 1500 } },
                    },
                },
            },
            [2] = {
                cashier = {
                    model = "mp_m_shopkeep_01",
                    coords = vector4(1165.2848, -323.9820, 68.2050, 94.6394),
                },

                lootableCashRegisters = {
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(1164.560, -324.895, 69.319),
                        },
                        zone = {
                            center = vector3(1164.560, -324.895, 69.319),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 100.0,
                        },
                        rewardKey = "cash_register",
                    },
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(1164.206, -322.890, 69.319)
                        },
                        zone = {
                            center = vector3(1164.206, -322.890, 69.319),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 100.0,
                        },
                        rewardKey = "cash_register"
                    },
                },

                loots = {
                    {
                        interaction = "search",
                        coords = vector3(1155.6525, -322.9354, 69.2050),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(1157.5043, -324.1329, 69.2050),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_juice_dispenser",
                            coords = vector3(1158.592, -319.172, 69.201),
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
                        markerCoords = vector3(1158.614, -319.463, 69.75),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_gumball_01",
                            coords = vector3(1165.083, -318.542, 68.205)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.2, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(1164.991, -318.553, 69.205),
                    },
                },

                miniSafe = {
                    body = {
                        model = "m23_2_prop_m32_arcade_safe_body",
                        coords = vector4(1161.90, -313.23, 68.21, 10.5),
                    },
                    door = {
                        model = "m23_2_prop_m32_arcade_safe_door",
                        coords = vector4(1161.90, -313.22, 68.21, 10.5),
                        openCoords = vector4(1161.90, -313.22, 68.21, 90.0),
                    },
                    inside = {
                        { model = "ex_office_swag_jewelwatch2", coords = vector4(1161.71, -312.95, 68.23, 85.0) },
                    },
                    zone = {
                        coords = vector3(1161.71, -312.95, 68.23),
                        size = vector3(1.0, 1.0, 1.5),
                        rotation = 10.5,
                    },
                    rewards = {
                        { itemName = "gold_bar", chance = 0.5, quantity = { min = 1, max = 3 } },
                        { itemName = "diamond",  chance = 0.3, quantity = { min = 1, max = 2 } },
                        { itemName = "cash",     chance = 1.0, quantity = { min = 500, max = 1500 } },
                    },
                },
            },
            [3] = {
                cashier = {
                    model = "mp_m_shopkeep_01",
                    coords = vector4(372.7446, 328.2007, 102.5663, 258.5963),
                },

                lootableCashRegisters = {
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(373.595, 328.589, 103.681)
                        },
                        zone = {
                            center = vector3(373.595, 328.589, 103.681),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 255.88,
                        },
                        rewardKey = "cash_register",
                    },
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(373.026, 326.326, 103.681)
                        },
                        zone = {
                            center = vector3(373.026, 326.326, 103.681),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 255.88,
                        },
                        rewardKey = "cash_register"
                    },
                },

                loots = {
                    {
                        interaction = "search",
                        coords = vector3(373.3131, 330.0178, 103.5663),
                        rewardKey = "liquor_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(378.0199, 329.8372, 103.5663),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_juice_dispenser",
                            coords = vector3(375.457, 330.885, 103.562),
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
                        markerCoords = vector3(375.368, 330.626, 104.0),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_gumball_01",
                            coords = vector3(382.934, 327.143, 102.566)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.2, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(382.640, 327.218, 103.566),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = 810004487,
                            coords = vector3(379.675, 333.849, 103.442)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.5, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(379.550, 333.498, 103.8),
                    },
                },

                miniSafe = {
                    body = {
                        model = "m23_2_prop_m32_arcade_safe_body",
                        coords = vector4(380.646, 331.842, 102.566, 270.0),
                    },
                    door = {
                        model = "m23_2_prop_m32_arcade_safe_door",
                        coords = vector4(380.648, 331.845, 102.566, 270.0),
                        openCoords = vector4(380.648, 331.845, 102.566, 0.0),
                    },
                    inside = {
                        { model = "ex_office_swag_jewelwatch2", coords = vector4(380.920, 332.074, 102.581, 0.0) },
                    },
                    zone = {
                        coords = vector3(380.646, 331.842, 102.566),
                        size = vector3(1.0, 1.0, 1.5),
                        rotation = 270.0,
                    },
                    rewards = {
                        { itemName = "gold_bar", chance = 0.5, quantity = { min = 1, max = 3 } },
                        { itemName = "diamond",  chance = 0.3, quantity = { min = 1, max = 2 } },
                        { itemName = "cash",     chance = 1.0, quantity = { min = 500, max = 1500 } },
                    },
                },
            },
            [4] = {
                cashier = {
                    model = "mp_m_shopkeep_01",
                    coords = vector4(-47.4538, -1759.1249, 28.4210, 44.7842),
                },

                lootableCashRegisters = {
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(-48.507, -1759.229, 29.535)
                        },
                        zone = {
                            center = vector3(-48.507, -1759.229, 29.535),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 50.0,
                        },
                        rewardKey = "cash_register",
                    },
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(-47.199, -1757.670, 29.535)
                        },
                        zone = {
                            center = vector3(-47.199, -1757.670, 29.535),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 50.0,
                        },
                        rewardKey = "cash_register"
                    },
                },

                loots = {
                    {
                        interaction = "search",
                        coords = vector3(-52.7514, -1751.0898, 29.4210),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(-52.2740, -1753.2534, 29.4210),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_juice_dispenser",
                            coords = vector3(-47.958, -1750.979, 29.417),
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
                        markerCoords = vector3(-48.159, -1751.189, 29.8),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_gumball_01",
                            coords = vector3(-43.304, -1755.548, 28.421)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.2, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(-43.516, -1755.350, 29.425),
                    },
                },

                miniSafe = {
                    body = {
                        model = "m23_2_prop_m32_arcade_safe_body",
                        coords = vector4(-41.719, -1749.518, 28.421, 270.0),
                    },
                    door = {
                        model = "m23_2_prop_m32_arcade_safe_door",
                        coords = vector4(-41.713, -1749.507, 28.421, 270.0),
                        openCoords = vector4(-41.713, -1749.507, 28.421, 0.0),
                    },
                    inside = {
                        { model = "ex_office_swag_jewelwatch2", coords = vector4(-41.420, -1749.243, 28.430, 6.37) },
                    },
                    zone = {
                        coords = vector3(-41.420, -1749.243, 28.430),
                        size = vector3(1.0, 1.0, 1.5),
                        rotation = 270.0,
                    },
                    rewards = {
                        { itemName = "gold_bar", chance = 0.5, quantity = { min = 1, max = 3 } },
                        { itemName = "diamond",  chance = 0.3, quantity = { min = 1, max = 2 } },
                        { itemName = "cash",     chance = 1.0, quantity = { min = 500, max = 1500 } },
                    },
                },
            },
            [5] = {
                cashier = {
                    model = "mp_m_shopkeep_01",
                    coords = vector4(1958.9783, 3741.4194, 31.3437, 298.6282),
                },

                lootableCashRegisters = {
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(1959.323, 3742.290, 32.458)
                        },
                        zone = {
                            center = vector3(1959.323, 3742.290, 32.458),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 300.0,
                        },
                        rewardKey = "cash_register",
                    },
                    {
                        prop = {
                            holdingModel = "prop_till_01_dam",
                            model = 303280717,
                            coords = vector3(1960.490, 3740.268, 32.458)
                        },
                        zone = {
                            center = vector3(1960.490, 3740.268, 32.458),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 300.0,
                        },
                        rewardKey = "cash_register"
                    },
                },

                loots = {
                    {
                        interaction = "search",
                        coords = vector3(1958.0201, 3743.1682, 32.3437),
                        rewardKey = "liquor_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(1961.7079, 3746.3169, 32.3437),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_juice_dispenser",
                            coords = vector3(1959.062, 3745.233, 32.339),
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
                        markerCoords = vector3(1959.179, 3745.002, 32.8),
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_gumball_01",
                            coords = vector3(-43.304, -1755.548, 28.421)
                        },
                        positions = {
                            onHolding = {
                                offset = vector3(0.0, -0.1, -0.1),
                                rotation = vector3(0.0, 0.0, 0.0),
                                boneId = 28422,
                            },
                            onVehicle = {
                                offset = vector3(-0.3, -1.2, 0.23),
                                rotation = vector3(0.0, 0.0, 270.0),
                            },
                        },
                        markerCoords = vector3(1966.856, 3747.640, 32.344),
                    },
                },

                miniSafe = {
                    body = {
                        model = "m23_2_prop_m32_arcade_safe_body",
                        coords = vector4(1962.332, 3749.172, 31.344, 270.0),
                    },
                    door = {
                        model = "m23_2_prop_m32_arcade_safe_door",
                        coords = vector4(1962.339, 3749.186, 31.344, 270.0),
                        openCoords = vector4(1962.339, 3749.186, 31.344, 0.0),
                    },
                    inside = {
                        { model = "ex_office_swag_jewelwatch2", coords = vector4(1962.622, 3749.401, 31.373, 0.0) },
                    },
                    zone = {
                        coords = vector3(1962.622, 3749.401, 31.373),
                        size = vector3(1.0, 1.0, 1.5),
                        rotation = 270.0,
                    },
                    rewards = {
                        { itemName = "gold_bar", chance = 0.5, quantity = { min = 1, max = 3 } },
                        { itemName = "diamond",  chance = 0.3, quantity = { min = 1, max = 2 } },
                        { itemName = "cash",     chance = 1.0, quantity = { min = 500, max = 1500 } },
                    },
                },
            },
        },
        custom = {
            [1] = {
                cashier = {
                    model = "mp_m_shopkeep_01",
                    coords = vector4(2556.1729, 381.0433, 107.6229, 2.6463),
                },

                lootableCashRegisters = {
                    {
                        prop = {
                            model = 303280717,
                            holdingModel = "prop_till_01_dam",
                            coords = vector3(2555.642, 381.846, 108.809),
                        },
                        zone = {
                            center = vector3(2555.642, 381.846, 108.809),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 0.0,
                        },
                        rewardKey = "cash_register",
                    },
                    {
                        prop = {
                            model = 303280717,
                            holdingModel = "prop_till_01_dam",
                            coords = vector3(2557.799, 381.787, 108.809)
                        },
                        zone = {
                            center = vector3(2557.799, 381.787, 108.809),
                            size = vector3(0.6, 0.6, 0.8),
                            rotation = 0.0,
                        },
                        rewardKey = "cash_register"
                    },
                },

                loots = {
                    {
                        interaction = "search",
                        coords = vector3(2555.232, 384.933, 108.560),
                        rewardKey = "liquor_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(2555.232, 384.933, 108.560),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "search",
                        coords = vector3(2553.153, 380.530, 108.685),
                        rewardKey = "drinks_shelf",
                    },
                    {
                        interaction = "carry",
                        prop = {
                            model = "prop_gumball_01",
                            coords = vector3(2558.572, 382.566, 107.623),
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
                        markerCoords = vector3(2558.575, 382.531, 108.539),
                    },
                },

                miniSafe = {
                    body = { model = "m23_2_prop_m32_arcade_safe_body", coords = vector4(2549.462, 387.521, 107.643, 0.0) },
                    door = {
                        model = "m23_2_prop_m32_arcade_safe_door",
                        coords = vector4(2549.457, 387.523, 107.643, 0.0),
                        openCoords = vector4(2549.457, 387.523, 107.643, 100.0),
                    },
                    inside = {
                        { model = "ex_office_swag_jewelwatch2", coords = vector4(2549.232, 387.819, 107.672, 90.0) }
                    },
                    zone = {
                        coords = vector3(2549.462, 387.521, 107.5),
                        size = vector3(0.8, 0.8, 1.5),
                        rotation = 0.0,
                    },
                    rewards = {
                        { itemName = "gold_bar", chance = 0.5, quantity = { min = 1, max = 3 } },
                        { itemName = "diamond",  chance = 0.3, quantity = { min = 1, max = 2 } },
                        { itemName = "cash",     chance = 1.0, quantity = { min = 500, max = 1500 } },
                    },
                },
            },
        },
    },
}
