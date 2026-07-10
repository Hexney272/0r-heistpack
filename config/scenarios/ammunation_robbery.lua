--[[
    Scenario: Ammunation Robbery
    Description: This scenario involves robbing weapon containers guarded by security.
]]
return {

    guardWeapon = "WEAPON_CARBINERIFLE",

    requiredGrinderItem = { itemName = "heistpack_grinder", label = "Grinder" },

    ---@type RewardItem[]
    lootableRewards = {
        { itemName = "money",         chance = 1.0, quantity = { min = 3000, max = 5000 } },
        { itemName = "weapon_pistol", chance = 0.6, quantity = { min = 1, max = 2 } },
        { itemName = "weapon_smg",    chance = 0.4, quantity = { min = 1, max = 1 } },
        { itemName = "weapon_ammo",   chance = 0.9, quantity = { min = 100, max = 200 } },
    },

    locations = {
        [1] = {
            centerCoords = vector3(1139.2340, -3193.1665, 5.9008),

            -- 8 container coordinates
            containers = {
                { model = "tr_prop_tr_container_01a", coords = vector4(1132.873, -3181.619, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1136.239, -3181.571, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01c", coords = vector4(1140.260, -3181.627, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01d", coords = vector4(1144.235, -3181.610, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01e", coords = vector4(1132.154, -3190.396, 4.901, 180.0) },
                { model = "tr_prop_tr_container_01f", coords = vector4(1136.204, -3190.360, 4.901, 180.0) },
                { model = "tr_prop_tr_container_01g", coords = vector4(1140.264, -3190.552, 4.901, 180.0) },
                { model = "tr_prop_tr_container_01h", coords = vector4(1144.295, -3190.430, 4.901, 180.0) },
            },

            -- Guard spawn positions
            guards = {
                vector4(1144.1525, -3194.8657, 5.9008, 186.9639),
                vector4(1131.1377, -3193.2769, 5.9008, 190.3578),
                vector4(1131.5502, -3178.8857, 5.8978, 352.5563),
                vector4(1146.0671, -3178.7830, 5.9008, 315.3257),
            },
        },
        [2] = {
            centerCoords = vector3(1108.2590, -3080.9531, 5.8521),

            containers = {
                { model = "tr_prop_tr_container_01a", coords = vector4(1092.305, -3089.684, 4.890, 90.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1092.393, -3086.037, 4.889, 90.0) },
                { model = "tr_prop_tr_container_01c", coords = vector4(1092.362, -3082.694, 4.889, 90.0) },
                { model = "tr_prop_tr_container_01d", coords = vector4(1092.435, -3079.118, 4.888, 90.0) },
                { model = "tr_prop_tr_container_01e", coords = vector4(1099.923, -3078.022, 4.877, 270.0) },
                { model = "tr_prop_tr_container_01f", coords = vector4(1099.975, -3081.758, 4.872, 270.0) },
                { model = "tr_prop_tr_container_01g", coords = vector4(1099.965, -3085.479, 4.873, 270.0) },
                { model = "tr_prop_tr_container_01h", coords = vector4(1100.096, -3089.360, 4.874, 270.0) },
            },

            guards = {
                vector4(1103.3414, -3076.2439, 5.8807, 248.4538),
                vector4(1103.0618, -3090.1233, 5.8688, 327.2201),
                vector4(1087.9653, -3091.6318, 5.8984, 87.4428),
                vector4(1088.0776, -3078.1702, 5.8994, 151.8113),
            },
        },
        [3] = {
            centerCoords = vector3(1280.7283, -3304.1526, 5.9016),

            containers = {
                { model = "tr_prop_tr_container_01b", coords = vector4(1283.748, -3306.488, 4.918, 270.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1283.816, -3309.939, 4.918, 270.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1283.905, -3313.388, 4.903, 270.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1283.979, -3316.864, 4.903, 270.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1275.467, -3317.947, 4.902, 90.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1275.323, -3314.343, 4.902, 90.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1275.298, -3310.718, 4.902, 90.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(1275.216, -3306.551, 4.902, 90.0) },
            },

            guards = {
                vector4(1284.1030, -3295.2612, 5.9028, 39.6853),
                vector4(1283.0093, -3295.5869, 5.9024, 103.6959),
                vector4(1279.4268, -3296.2083, 5.9016, 98.9039),
                vector4(1281.0098, -3293.9138, 5.9016, 295.2392),
            },
        },
        [4] = {
            centerCoords = vector3(847.4496, -3137.8308, 5.9007),

            containers = {
                { model = "tr_prop_tr_container_01b", coords = vector4(851.277, -3129.968, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(846.507, -3130.134, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(842.801, -3130.106, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(838.674, -3129.948, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(834.592, -3130.084, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(830.361, -3130.236, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(826.216, -3130.463, 4.901, 0.0) },
                { model = "tr_prop_tr_container_01b", coords = vector4(822.279, -3130.353, 4.901, 0.0) },
            },

            guards = {
                vector4(823.1535, -3134.1458, 5.9008, 171.5896),
                vector4(832.5996, -3133.7227, 5.9008, 197.2730),
                vector4(843.7590, -3133.9629, 5.9008, 176.9784),
                vector4(851.8945, -3134.1477, 5.9008, 202.0529),
            },
        }
    },
}
