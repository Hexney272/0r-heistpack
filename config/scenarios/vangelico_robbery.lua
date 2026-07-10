--[[
    Scenario Configuration: Vangelico Robbery
    Description: This configuration file sets up the parameters for the Vangelico jewelry store robbery scenario in the game.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.long,

    storeCenterCoords = vector3(-622.30, -231.0, 38.0), -- Center coordinates of the store.

    vehicles = {
        -- { model = "cognoscenti" }
    },

    poisonousGasOptions = {
        droneUsageAreaCoords = vector3(-766.5456, -188.7057, 48.6208),
        dropZones = {
            { coords = vector3(-622.4477, -233.6265, 58.1),  radius = 3.0 },
            { coords = vector3(-626.9847, -216.5663, 58.49), radius = 3.0 },
            { coords = vector3(-598.5905, -265.3935, 56.42), radius = 3.0 },
        },
        dropPropModel = "w_ex_grenadesmoke",        -- Model name of the gas bomb object.
        particle = {
            coords = vector3(-622.0, -231.0, 38.0), -- Coordinates where the particle effect is centered.
            ptfxName = "scr_jewelheist",            -- Name of the particle effect asset.
            effectName = "scr_jewel_fog_volume",    -- Name of the specific particle effect to use.
        },
        radius = 10,                                -- Radius (in meters) of the gas cloud.
        maskItemName = "gasmask",                   -- Item name used for the gas mask.
        -- Gas mask component variations
        maskComponentVariations = {
            male = { on = { drawableId = 175 }, off = { drawableId = 0 } },
            female = { on = { drawableId = 175 }, off = { drawableId = 0 } },
        }
    },

    entranceDoorOptions = {
        doors = {
            [1] = { model = 1425919976, coords = vector3(-631.96, -236.33, 38.21), yaw = 306.00, },
            [2] = { model = 9467943, coords = vector3(-630.43, -238.44, 38.21), yaw = 306.00, },
        },
    },

    robbablePedOptions = {
        peds = {
            { model = "IG_MiguelMadrazo", coords = vector4(-624.4316, -232.5393, 37.25, 181.5963), },
            { model = "S_M_M_HighSec_01", coords = vector4(-629.8885, -233.8189, 37.25, 293.6930), },
            { model = "CS_Dale",          coords = vector4(-625.4672, -236.2989, 37.25, 310.0), },
        },

        -- Possible rewards from robbing the ped.
        ---@type RewardItem[]
        rewards = {
            { itemName = "cash",          quantity = { min = 200, max = 500 }, chance = 1.0 },
            { itemName = "gold_bracelet", quantity = { min = 1, max = 1 },     chance = 0.4 },
            { itemName = "gold_ring",     quantity = { min = 1, max = 2 },     chance = 0.25 },
            { itemName = "gold_watch",    quantity = { min = 1, max = 1 },     chance = 0.15 },
            { itemName = "diamond_ring",  quantity = { min = 1, max = 1 },     chance = 0.10 },
        },
    },

    lootableDisplayOptions = {
        -- Possible rewards from looting a display case.
        ---@type RewardItem[]
        rewards = {
            { itemName = "gold_necklace", quantity = { min = 1, max = 1 }, chance = 0.5 },
            { itemName = "gold_bracelet", quantity = { min = 1, max = 1 }, chance = 0.5 },
            { itemName = "gold_ring",     quantity = { min = 1, max = 2 }, chance = 0.7 },
            { itemName = "diamond_ring",  quantity = { min = 1, max = 1 }, chance = 0.3 },
            { itemName = "gold_watch",    quantity = { min = 1, max = 1 }, chance = 0.4 },
        },

        locations = {
            {
                objectCoords  = vector3(-624.49, -229.99, 37.94),
                originalModel = "prop_j_disptray_04",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-624.36, -229.15, 37.94),
                originalModel = "prop_j_disptray_05",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-622.88, -228.08, 37.94),
                originalModel = "prop_j_disptray_04",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-622.04, -228.21, 37.94),
                originalModel = "prop_j_disptray_05",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-619.64, -231.52, 37.94),
                originalModel = "prop_j_disptray_04",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-619.78, -232.35, 37.94),
                originalModel = "prop_j_disptray_05",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-621.26, -233.43, 37.94),
                originalModel = "prop_j_disptray_04",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-622.10, -233.30, 37.94),
                originalModel = "prop_j_disptray_05",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-628.253, -226.664, 38.269),
                originalModel = "prop_j_neck_disp_03",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-628.112, -225.071, 38.269),
                originalModel = "prop_j_neck_disp_01",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-627.105, -223.789, 38.269),
                originalModel = "prop_j_neck_disp_02",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-625.608, -223.252, 38.269),
                originalModel = "prop_j_neck_disp_03",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-624.039, -223.612, 38.269),
                originalModel = "prop_j_neck_disp_01",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-615.891, -234.847, 38.269),
                originalModel = "prop_j_neck_disp_01",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-616.020, -236.431, 38.269),
                originalModel = "prop_j_neck_disp_02",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-617.023, -237.714, 38.269),
                originalModel = "prop_j_neck_disp_03",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-618.520, -238.255, 38.269),
                originalModel = "prop_j_neck_disp_01",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
            {
                objectCoords  = vector3(-620.105, -237.898, 38.269),
                originalModel = "prop_j_neck_disp_02",
                newModel      = "h4_prop_h4_neck_disp_01a",
            },
        },
    },

    smashableCaseOptions = {
        -- Cases can only be smashable with these weapons
        smashableWeapons = {
            "WEAPON_ASSAULTRIFLE",
            "WEAPON_CARBINERIFLE",
            "WEAPON_ADVANCEDRIFLE",
            "WEAPON_BULLPUPRIFLE",
        },

        -- Possible rewards from smashing a case.
        ---@type RewardItem[]
        rewards = {
            { itemName = "gold_necklace", quantity = { min = 1, max = 1 }, chance = 0.5 },
            { itemName = "gold_bracelet", quantity = { min = 1, max = 1 }, chance = 0.5 },
            { itemName = "gold_ring",     quantity = { min = 1, max = 2 }, chance = 0.7 },
            { itemName = "diamond_ring",  quantity = { min = 1, max = 1 }, chance = 0.3 },
            { itemName = "gold_watch",    quantity = { min = 1, max = 1 }, chance = 0.4 },
        },

        locations = {
            {
                objectCoords  = vector3(-626.32, -239.05, 37.65),
                sceneCoords   = vector3(-626.894, -238.2, 37.0856),
                sceneHeading  = 211.0,
                originalModel = "des_jewel_cab2_start",
                newModel      = "des_jewel_cab2_end",
            },
            {
                objectCoords  = vector3(-625.28, -238.29, 37.65),
                sceneCoords   = vector3(-625.867, -237.458, 37.0946),
                sceneHeading  = 209.3480,
                originalModel = "des_jewel_cab3_start",
                newModel      = "des_jewel_cab3_end",
            },
            {
                objectCoords  = vector3(-619.85, -234.91, 37.65),
                sceneCoords   = vector3(-620.44, -234.084, 37.0946),
                sceneHeading  = 215.0096,
                originalModel = "des_jewel_cab_start",
                newModel      = "des_jewel_cab_end",
            },
            {
                objectCoords  = vector3(-618.8, -234.15, 37.65),
                sceneCoords   = vector3(-619.39, -233.32, 37.0946),
                sceneHeading  = 221.9832,
                originalModel = "des_jewel_cab3_start",
                newModel      = "des_jewel_cab3_end",
            },
            {
                objectCoords  = vector3(-617.09, -230.16, 37.65),
                sceneCoords   = vector3(-617.937, -230.731, 37.0856),
                sceneHeading  = 313.7113,
                originalModel = "des_jewel_cab2_start",
                newModel      = "des_jewel_cab2_end",
            },
            {
                objectCoords  = vector3(-617.85, -229.11, 37.65),
                sceneCoords   = vector3(-618.679, -229.704, 37.0946),
                sceneHeading  = 304.9840,
                originalModel = "des_jewel_cab3_start",
                newModel      = "des_jewel_cab3_end",
            },
            {
                objectCoords  = vector3(-619.20, -227.25, 37.65),
                sceneCoords   = vector3(-620.055, -227.817, 37.0856),
                sceneHeading  = 311.5028,
                originalModel = "des_jewel_cab2_start",
                newModel      = "des_jewel_cab2_end",
            },
            {
                objectCoords  = vector3(-619.97, -226.2, 37.65),
                sceneCoords   = vector3(-620.797, -226.79, 37.0946),
                sceneHeading  = 302.9922,
                originalModel = "des_jewel_cab_start",
                newModel      = "des_jewel_cab_end",
            },
            {
                objectCoords  = vector3(-624.28, -226.61, 37.65),
                sceneCoords   = vector3(-623.688, -227.437, 37.0946),
                sceneHeading  = 30.5208,
                originalModel = "des_jewel_cab4_start",
                newModel      = "des_jewel_cab4_end",
            },
            {
                objectCoords  = vector3(-625.33, -227.37, 37.65),
                sceneCoords   = vector3(-624.738, -228.2, 37.0946),
                sceneHeading  = 31.3550,
                originalModel = "des_jewel_cab3_start",
                newModel      = "des_jewel_cab3_end",
            },
            {
                objectCoords  = vector3(-626.54, -233.60, 37.65),
                sceneCoords   = vector3(-627.136, -232.775, 37.0946),
                sceneHeading  = 228.1929,
                originalModel = "des_jewel_cab_start",
                newModel      = "des_jewel_cab_end",
            },
            {
                objectCoords  = vector3(-627.59, -234.37, 37.65),
                sceneCoords   = vector3(-628.187, -233.538, 37.0946),
                sceneHeading  = 220.4451,
                originalModel = "des_jewel_cab_start",
                newModel      = "des_jewel_cab_end",
            },
            {
                objectCoords  = vector3(-627.21, -234.89, 37.65),
                sceneCoords   = vector3(-626.62, -235.725, 37.0946),
                sceneHeading  = 43.0834,
                originalModel = "des_jewel_cab3_start",
                newModel      = "des_jewel_cab3_end",
            },
            {
                objectCoords  = vector3(-626.16, -234.13, 37.65),
                sceneCoords   = vector3(-625.57, -234.962, 37.0946),
                sceneHeading  = 40.4197,
                originalModel = "des_jewel_cab4_start",
                newModel      = "des_jewel_cab4_end",
            },
            {
                objectCoords  = vector3(-622.62, -232.56, 37.65),
                sceneCoords   = vector3(-623.3596, -233.2296, 37.0946),
                sceneHeading  = 306.0685,
                originalModel = "des_jewel_cab_start",
                newModel      = "des_jewel_cab_end",
            },
            {
                objectCoords  = vector3(-620.52, -232.88, 37.65),
                sceneCoords   = vector3(-620.184, -233.729, 37.0946),
                sceneHeading  = 35.7533,
                originalModel = "des_jewel_cab4_start",
                newModel      = "des_jewel_cab4_end",
            },
            {
                objectCoords  = vector3(-620.18, -230.79, 37.65),
                sceneCoords   = vector3(-619.408, -230.1969, 37.0946),
                sceneHeading  = 122.5826,
                originalModel = "des_jewel_cab_start",
                newModel      = "des_jewel_cab_end",
            },
            {
                objectCoords  = vector3(-621.52, -228.95, 37.65),
                sceneCoords   = vector3(-620.864, -228.481, 37.0946),
                sceneHeading  = 126.6078,
                originalModel = "des_jewel_cab3_start",
                newModel      = "des_jewel_cab3_end",
            },
            {
                objectCoords  = vector3(-623.61, -228.62, 37.65),
                sceneCoords   = vector3(-624.293, -227.831, 37.0946),
                sceneHeading  = 244.6731,
                originalModel = "des_jewel_cab2_start",
                newModel      = "des_jewel_cab2_end",
            },
            {
                objectCoords  = vector3(-623.96, -230.73, 37.65),
                sceneCoords   = vector3(-624.939, -231.247, 37.0946),
                sceneHeading  = 306.6731,
                originalModel = "des_jewel_cab4_start",
                newModel      = "des_jewel_cab4_end",
            },
        },
    },

    smashableCashRegisterOptions = {
        -- Can only be smashable with these weapons
        smashableWeapons = {
            "WEAPON_ASSAULTRIFLE",
            "WEAPON_CARBINERIFLE",
            "WEAPON_ADVANCEDRIFLE",
            "WEAPON_BULLPUPRIFLE",
        },

        -- Possible rewards from smashing a cash register.
        ---@type RewardItem[]
        rewards = {
            { itemName = "cash", quantity = { min = 100, max = 300 }, chance = 1.0 },
        },

        locations = {
            {
                objectCoords   = vector4(-621.88, -229.57, 38.0, 306.0),
                sceneCoords    = vector3(-622.6949, -230.2122, 37.0570),
                sceneHeading   = 304.0,
                originalModel  = "prop_till_01",
                newModel       = "prop_till_01_dam",
                alreadySpawned = false,
            },
        },
    },

    paintingSmuggleOptions = {
        requiredWeapon = { name = "WEAPON_SWITCHBLADE", label = "Switchblade" },

        paintingModels = {
            "ch_prop_vault_painting_01a",
            "ch_prop_vault_painting_01b",
            "ch_prop_vault_painting_01c",
            "ch_prop_vault_painting_01d",
            "ch_prop_vault_painting_01e",
            "ch_prop_vault_painting_01f",
            "ch_prop_vault_painting_01g",
            "ch_prop_vault_painting_01h",
            "ch_prop_vault_painting_01i",
            "ch_prop_vault_painting_01j",
        },

        locations = {
            {
                objectCoords = vector4(-627.22, -228.32, 38.2, 90.75),
                sceneCoords = vector4(-626.78, -228.32, 38.06, 90.00),
                reward = { itemName = "heist_paint_1", count = 1 }
            },
            {
                objectCoords = vector4(-622.77, -225.12, 38.2, 340.5),
                sceneCoords = vector4(-622.97, -225.54, 38.06, -20.0),
                reward = { itemName = "heist_paint_2", count = 1 }
            },
            {
                objectCoords = vector4(-617.00, -233.22, 38.2, 269.53),
                sceneCoords = vector4(-617.42, -233.22, 38.06, -90.0),
                reward = { itemName = "heist_paint_3", count = 1 }
            },
            {
                objectCoords = vector4(-621.38, -236.34, 38.2, 161.22),
                sceneCoords = vector4(-621.265, -235.9, 38.06, 160.0),
                reward = { itemName = "heist_paint_4", count = 1 }
            },
        },
    },

    caseRoomOptions = {
        door = {
            model = 1335309163,
            coords = vector3(-629.13, -230.15, 38.21),
            yaw = 36.33,
            keypad = {
                coords = vector4(-629.411, -230.425, 38.55, 35.0),
                sceneCoords = vector4(-629.3823, -230.8419, 37.08, 28.5975),
            },
        },

        safe = {
            drill  = {
                itemName = "heistpack_drill", -- Item name used for the drill.
                animation = {
                    duration = 7500,
                    coords   = vector3(-630.60, -229.05, 37.0571),
                    rotation = vector3(0.0, 0.0, 48.7351),
                }
            },

            inside = {
                [1] = {
                    model = "bkr_prop_moneypack_03a",
                    coords = vector4(-631.01, -228.24, 37.15, 59.14),
                    ---@type RewardItem[]
                    rewards = {
                        { itemName = "money", quantity = { min = 2000, max = 5000 } },
                    },
                },
                [2] = {
                    model = "ex_office_swag_jewelwatch2",
                    coords = vector4(-631.05, -228.21, 37.91, 36.30),
                    ---@type RewardItem[]
                    rewards = {
                        { itemName = "rolex",     quantity = { min = 1, max = 1 } },
                        { itemName = "goldwatch", quantity = { min = 1, max = 1 } },
                        { itemName = "goldchain", quantity = { min = 1, max = 1 } },
                    },
                },
            },
            --[[ !!! REPLACEMENT IS NOT RECOMMENDED !!! ]]
            body   = {
                model  = "bkr_prop_biker_safebody_01a",
                coords = vector4(-630.56, -228.28, 37.81, 36.33),
            },
            --[[ !!! REPLACEMENT IS NOT RECOMMENDED !!! ]]
            door   = {
                model  = "bkr_prop_biker_safedoor_01a",
                coords = vector4(-630.56, -228.28, 37.81, 36.33),
            },
        }
    },

    -- Objects to be removed from the store at the start of the scenario.
    findAndRemoveObjects = {
        { coords = vector3(-631.37, -228.03, 38.39), model = -1516329901, },
        { coords = vector3(-631.36, -228.04, 37.75), model = 163066920, },
        { coords = vector3(-623.08, -229.36, 37.65), model = 1041076678 },
        { coords = vector3(-621.05, -232.15, 37.65), model = 1041076678 },
        { coords = vector3(-624.43, -230.43, 38.24), model = -1847044452 },
        { coords = vector3(-620.09, -231.68, 38.24), model = -1847044452 },
        { coords = vector3(-621.78, -229.57, 37.87), model = 759654580 },
    },
}
