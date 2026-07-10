--[[
    Scenario: Pacific Bank Robbery
    Description: A high-stakes heist scenario set in the iconic Pacific Bank.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.medium,

    -- Map variant support (standard or custom)
    hasCustomMap = false,

    bankEntranceCoords = {
        standart = vector3(228.1778, 213.8553, 105.5278),
        custom = vector3(228.1778, 213.8553, 105.5278),
    },

    bankCenterCoords = {
        standart = vector3(257.0595, 221.7618, 107.2758),
        custom = vector3(257.0595, 221.7618, 107.2758),
    },

    ---@type RewardItem[]
    atmRobberyRewards = {
        { itemName = "money", chance = 1.0, quantity = { min = 2500, max = 6000 } },
    },

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

    bombDropOptions = {
        dropPropModel = "w_ex_grenadefrag",
        locations = {
            center = vector3(696.6714, 128.8639, 80.7544),
            usage = vector3(740.0299, 134.3683, 80.5578),
            dropZones = {
                { coords = vector3(709.0709, 115.1277, 85.0), radius = 3.0 },
                { coords = vector3(683.0830, 115.2550, 85.0), radius = 3.0 },
                { coords = vector3(694.0254, 157.0771, 85.0), radius = 3.0 },
                { coords = vector3(674.9720, 157.8367, 85.0), radius = 3.0 },
            },
        },
    },

    doors = {
        standart = {
            --[entrance - left]
            {
                model = 110411286,
                coords = vector3(231.512, 216.518, 106.405),
                yaw = 294.72,
                unlockMethod = "bomb",
                partner = 2,
                meta = { centerOffset = vector3(0.75, -0.1, 0.0), entrance = true },
            },
            --[entrance - right]
            {
                model = 110411286,
                coords = vector3(232.605, 214.158, 106.405),
                yaw = 114.67,
                unlockMethod = "bomb",
                partner = 1,
                meta = { centerOffset = vector3(0.75, 0.1, 0.0), entrance = true },
            },
            --[entrance - side - left]
            {
                model = 110411286,
                coords = vector3(258.202, 204.101, 106.405),
                yaw = 340.0,
                unlockMethod = false,
                partner = 4,
                meta = { entrance = true },
            },
            --[entrance - side - right]
            {
                model = 110411286,
                coords = vector3(260.643, 203.205, 106.405),
                yaw = 160.0,
                unlockMethod = false,
                partner = 3,
                meta = { entrance = true },
            },
            --[inside - upper safe]
            {
                model = -222270721,
                coords = vector3(256.312, 220.658, 106.430),
                yaw = 340.0,
                unlockMethod = "bomb",
                meta = {
                    centerOffset = vector3(1.2, -0.01, 0.0),
                    delete = true,
                },
            },
            --[inside - lower stairs ]
            {
                model = 1956494919,
                coords = vector3(237.770, 227.870, 106.426),
                yaw = 340.0,
                unlockMethod = false,
            },
            --[inside - upper stairs ]
            {
                model = 1956494919,
                coords = vector3(236.549, 228.315, 110.433),
                yaw = 160.0,
                unlockMethod = false,
            },
            --[inside - upper stairs 2]
            {
                model = 1956494919,
                coords = vector3(266.362, 217.570, 110.433),
                yaw = 340.06,
                unlockMethod = false,
            },
            --[inside - safe stairs ]
            {
                model = 746855201,
                coords = vector3(262.198, 222.519, 106.430),
                yaw = 250.0,
                unlockMethod = "keypad",
                meta = { noAnimation = true }
            },
            --[inside - big safe]
            {
                model = 961976194,
                coords = vector3(255.228, 223.976, 102.393),
                yaw = 160.0,
                unlockMethod = "safepad",
                meta = {
                    padInteractCoords = vector3(252.909, 228.506, 101.943),
                    openedYaw = 80.0,
                }
            },
        },
        custom = {
            --[entrance - left]
            {
                model = 1577691629,
                coords = vector3(231.503, 216.513, 106.430),
                yaw = 114.60,
                unlockMethod = "bomb",
                partner = 2,
                meta = { centerOffset = vector3(-0.75, 0.1, 0.0), entrance = true },
            },
            --[entrance - right]
            {
                model = 726025323,
                coords = vector3(232.601, 214.156, 106.430),
                yaw = 295.0,
                unlockMethod = "bomb",
                partner = 1,
                meta = { centerOffset = vector3(-0.75, -0.1, 0.0), entrance = true },
            },
            --[etrance - roof - left]
            {
                model = 1577691629,
                coords = vector3(273.897, 234.586, 123.975),
                yaw = 340.0,
                partner = 4,
                meta = { centerOffset = vector3(-0.75, 0.1, 0.0), entrance = true },
                unlockMethod = nil,
            },
            --[etrance - roof - right]
            {
                model = 726025323,
                coords = vector3(271.453, 235.476, 123.975),
                yaw = 160.0,
                partner = 3,
                meta = { centerOffset = vector3(-0.75, -0.1, 0.0), entrance = true },
                unlockMethod = nil,
            },
            --[entrance - side - left]
            {
                model = 1577691629,
                coords = vector3(264.88, 201.64, 106.45),
                yaw = 160.0,
                unlockMethod = nil,
                partner = 6,
                meta = { entrance = true },
            },
            --[entrance - side - right]
            {
                model = 726025323,
                coords = vector3(267.32, 200.75, 106.45),
                yaw = 340.0,
                unlockMethod = nil,
                partner = 5,
                meta = { entrance = true },
            },
            --[inside - downstairs - 1 ]
            {
                model = 409280169,
                coords = vector3(272.642, 219.899, 97.318),
                yaw = 340.0,
                unlockMethod = "keypad",
                meta = {
                    padInteractCoords = vector3(270.627, 221.316, 97.406),
                    noAnimation = true,
                }
            },
            --[inside - downstairs - 2 ]
            {
                model = 409280169,
                coords = vector3(270.103, 212.923, 97.318),
                yaw = 340.0,
                unlockMethod = "keypad",
                meta = {
                    padInteractCoords = vector3(267.651, 213.221, 97.428),
                    noAnimation = true,
                }
            },
            --[inside - big safe]
            {
                model = 961976194,
                coords = vector3(234.986, 228.070, 97.722),
                yaw = 70.0,
                unlockMethod = "safepad",
                meta = {
                    padInteractCoords = vector3(236.425, 231.739, 97.452),
                    openedYaw = 350.0,
                }
            },
        }
    },

    robbableAtmGroups = {
        standart = {
            [1] = {
                markerCoords = vector3(237.3511, 217.8501, 106.2868),
                atmCoords = {
                    { model = -1126237515, coords = vector3(236.978, 219.876, 105.406) },
                    { model = -1126237515, coords = vector3(237.408, 218.954, 105.406) },
                    { model = -1126237515, coords = vector3(237.838, 218.031, 105.406) },
                    { model = -1126237515, coords = vector3(238.268, 217.109, 105.406) },
                    { model = -1126237515, coords = vector3(238.698, 216.187, 105.406) },
                },
            },
            [2] = {
                markerCoords = vector3(265.1004, 212.0983, 106.2831),
                atmCoords = {
                    { model = -1126237515, coords = vector3(266.261, 213.773, 105.406) },
                    { model = -1126237515, coords = vector3(265.913, 212.817, 105.406) },
                    { model = -1126237515, coords = vector3(265.565, 211.861, 105.406) },
                    { model = -1126237515, coords = vector3(265.217, 210.905, 105.406) },
                    { model = -1126237515, coords = vector3(264.869, 209.949, 105.406) },
                }
            },
        },
        custom = {
            [1] = {
                markerCoords = vector3(239.710, 214.171, 106.206),
                atmCoords = {
                    { model = -1126237515, coords = vector3(243.019, 222.523, 105.408) },
                    { model = -1126237515, coords = vector3(242.571, 221.292, 105.408) },
                    { model = -1126237515, coords = vector3(242.123, 220.059, 105.408) },
                    { model = -1126237515, coords = vector3(241.673, 218.824, 105.408) },
                    { model = -1126237515, coords = vector3(240.620, 215.931, 105.408) },
                    { model = -1126237515, coords = vector3(240.174, 214.704, 105.408) },
                    { model = -1126237515, coords = vector3(239.724, 213.467, 105.408) },
                    { model = -1126237515, coords = vector3(239.275, 212.235, 105.408) },
                },
            },
            [2] = {
                markerCoords = vector3(264.277, 205.614, 106.070),
                atmCoords = {
                    { model = -1126237515, coords = vector3(263.354, 203.850, 105.408) },
                    { model = -1126237515, coords = vector3(263.805, 205.088, 105.408) },
                    { model = -1126237515, coords = vector3(264.252, 206.316, 105.408) },
                    { model = -1126237515, coords = vector3(264.701, 207.550, 105.408) },
                },
            },
        },
    },

    --[[ Armed and armored guards at the bank ]]
    guards = {
        standart = {
            vector4(252.1264, 218.3816, 101.6834, 136.6680),
            vector4(259.4171, 215.8427, 101.6834, 65.4565),
            vector4(260.5080, 225.4263, 101.6781, 253.2292),
            vector4(263.1355, 221.8338, 106.2801, 95.5811),
            vector4(256.1812, 217.7748, 106.2862, 91.0561),
            vector4(249.9484, 208.3430, 106.2823, 70.4545),
            vector4(241.1392, 220.4074, 106.2818, 47.0659),
            vector4(262.7413, 212.5318, 106.2832, 114.9345),
            vector4(254.8791, 224.8817, 106.2825, 79.4563),
            vector4(267.2192, 222.9844, 110.2829, 97.2002),
        },
        custom = {
            vector4(240.3230, 230.2023, 106.2821, 150.7915),
            vector4(256.5599, 237.0384, 108.2211, 148.2065),
            vector4(247.9795, 210.7132, 108.2211, 346.3165),
            vector4(278.8795, 210.7197, 110.1730, 43.9375),
            vector4(278.5369, 224.6015, 117.9531, 272.7180),
            vector4(278.4764, 225.7529, 110.1735, 207.7416),
            vector4(267.6686, 203.7662, 106.2816, 258.4170),
            vector4(272.9001, 224.5176, 97.1160, 180.7518),
            vector4(244.2184, 214.6590, 97.1170, 347.8362),
            vector4(230.2590, 230.4934, 97.1157, 330.5714),
            vector4(275.3605, 203.6310, 100.1513, 37.8082),
            vector4(267.3974, 207.1828, 97.1173, 321.5717),
            vector4(239.6944, 220.1774, 106.2821, 153.7143),
            vector4(275.5367, 217.4790, 110.1730, 242.2139),
            vector4(269.9628, 216.0646, 110.1728, 85.5959),
            vector4(278.8823, 212.9812, 103.2367, 57.0198),
        },
    },

    cashTrolleyGroups = {
        standart = {
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(261.841, 213.085, 101.156), rotation = vector3(0.0, 0.0, 0.0),         swapModel = SHARED_CONFIG.models.emptyTrolley },
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(266.207, 215.286, 101.156), rotation = vector3(0.0, 0.0, 180.0),       swapModel = SHARED_CONFIG.models.emptyTrolley },
            { model = SHARED_CONFIG.models.ingotTrolley, coords = vector3(262.810, 216.518, 101.156), rotation = vector3(0.000, 0.000, 170.0),   swapModel = SHARED_CONFIG.models.emptyTrolley, ingot = true, },
            { model = SHARED_CONFIG.models.ingotTrolley, coords = vector3(265.014, 212.068, 101.156), rotation = vector3(0.000, 0.000, -25.000), swapModel = SHARED_CONFIG.models.emptyTrolley, ingot = true, },
        },
        custom = {
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(252.4738, 239.0632, 96.589), rotation = vector3(0.000, 0.000, 155.4479), swapModel = SHARED_CONFIG.models.emptyTrolley },
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(241.2498, 211.8110, 96.589), rotation = vector3(0.000, 0.000, 335.7936), swapModel = SHARED_CONFIG.models.emptyTrolley },
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(241.5441, 215.0127, 96.589), rotation = vector3(0.000, 0.000, 259.7923), swapModel = SHARED_CONFIG.models.emptyTrolley },
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(232.347, 233.376, 96.589),   rotation = vector3(0.000, 0.000, 80.000),   swapModel = SHARED_CONFIG.models.emptyTrolley, no = true },
            { model = SHARED_CONFIG.models.cashTrolley,  coords = vector3(227.869, 235.044, 96.589),   rotation = vector3(0.000, 0.000, 200.000),  swapModel = SHARED_CONFIG.models.emptyTrolley, no = true },

            { model = SHARED_CONFIG.models.ingotTrolley, coords = vector3(229.188, 224.986, 96.589),   rotation = vector3(0.000, 0.000, -10.000),  swapModel = SHARED_CONFIG.models.emptyTrolley, ingot = true, },
            { model = SHARED_CONFIG.models.ingotTrolley, coords = vector3(227.938, 225.423, 96.589),   rotation = vector3(0.000, 0.000, -25.000),  swapModel = SHARED_CONFIG.models.emptyTrolley, ingot = true, },
            { model = SHARED_CONFIG.models.ingotTrolley, coords = vector3(225.976, 226.139, 96.589),   rotation = vector3(0.000, 0.000, -20.000),  swapModel = SHARED_CONFIG.models.emptyTrolley, ingot = true, },
            { model = SHARED_CONFIG.models.ingotTrolley, coords = vector3(224.718, 226.617, 96.589),   rotation = vector3(0.000, 0.000, -30.000),  swapModel = SHARED_CONFIG.models.emptyTrolley, ingot = true, },
        },
    },
}
