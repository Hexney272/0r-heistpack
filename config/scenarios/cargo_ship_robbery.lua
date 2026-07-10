--[[
    Scenario Configuration: Cargo Ship Robbery
    Description: This configuration file sets up the parameters for the cargo ship robbery scenario in the game.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.long,

    -- Center coordinates of the cargo ship
    shipCenterCoords = vector3(-358.9236, -4082.6843, 9.3140),

    boatSpawn = {
        coords = vector4(-121.20, -2727.57, 0.2, 150.0),
        model = SHARED_CONFIG.models.speedboat,
    },

    -- Anchor item used to stop the boat
    anchorItemName = "heistpack_anchor",

    -- Captain cabin key configuration
    captainCabinKey = {
        coords = vector3(-402.274, -4117.350, 26.549),
        propModel = SHARED_CONFIG.models.vehicleKey,
        animation = SHARED_CONFIG.animations.search,
    },

    -- Helicopter spawn on ship helipad
    helicopterSpawn = {
        coords = vector4(-318.76, -4052.25, 10.5, 205.0), -- Helipad coordinates on ship
        model = SHARED_CONFIG.models.cargoHelicopter,
    },

    bigContainers = {
        {
            coords = vector4(-342.734, -4061.621, 16.805, 310.0),
            model = SHARED_CONFIG.models.bigContainer,
            targetCoords = vector4(1041.625, -3098.803, 16.153, 90.0),
        },
        {
            coords = vector4(-360.422, -4092.219, 16.805, 310.0),
            model = SHARED_CONFIG.models.bigContainer,
            targetCoords = vector4(1753.012, 3240.632, 40.876, 0.0),
        },
    },

    -- Ladders for climbing onto the ship
    ladders = {
        {
            coords = vector3(-391.28, -4133.34, 1.44),
            rotation = vector3(-2.075, -30.509, 44.283),
            model = SHARED_CONFIG.models.ladder,
        },
    },

    ---@type table<string, RewardItem[]>
    lootRewardItems = {
        ["weapon_case"] = {
            { itemName = "weapon_assaultrifle", chance = 0.3, quantity = { min = 1, max = 1 } },
            { itemName = "weapon_carbinerifle", chance = 0.3, quantity = { min = 1, max = 1 } },
            { itemName = "weapon_pumpshotgun",  chance = 0.4, quantity = { min = 1, max = 1 } },
            { itemName = "weapon_pistol",       chance = 0.5, quantity = { min = 1, max = 1 } },
            { itemName = "ammo-9",              chance = 0.8, quantity = { min = 25, max = 50 } },
            { itemName = "ammo-rifle",          chance = 0.7, quantity = { min = 25, max = 50 } },
            { itemName = "ammo-rifle2",         chance = 0.7, quantity = { min = 25, max = 50 } },
        },
    },

    -- Armed guards spawning around the ship
    guards = {
        vector4(-304.2239, -4041.5947, 14.2961, 122.3147),
        vector4(-307.9241, -4035.2573, 14.2958, 27.2462),
        vector4(-329.2472, -4060.9663, 9.3140, 156.6975),
        vector4(-339.4363, -4053.7544, 9.3186, 340.4660),
        vector4(-353.1396, -4065.2317, 9.3180, 219.1417),
        vector4(-365.5544, -4075.5623, 9.3140, 134.2748),
        vector4(-381.8132, -4089.4578, 9.3129, 134.0441),
        vector4(-408.0233, -4111.1221, 9.3104, 131.6210),
        vector4(-424.8442, -4126.9072, 9.3090, 140.0821),
        vector4(-416.0179, -4146.3511, 9.3126, 305.6294),
        vector4(-384.5861, -4123.3135, 9.3186, 312.2688),
        vector4(-365.6405, -4107.4204, 9.3034, 311.9807),
        vector4(-348.1629, -4092.3906, 9.3187, 331.9614),
        vector4(-332.9648, -4080.2214, 9.2340, 310.2287),
        vector4(-321.1259, -4069.2842, 9.3040, 312.5385),
        vector4(-399.6314, -4117.1147, 26.5436, 328.7760),
    },

    -- Lootable containers on the ship
    loots = {
        {
            interaction = "search",
            prop = {
                coords = vector4(-339.691, -4081.320, 8.319, 130.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-341.203, -4079.591, 8.319, 130.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-349.900, -4069.366, 8.319, 130.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-363.648, -4078.335, 8.319, 130.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-360.578, -4082.087, 8.319, 130.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-353.726, -4090.097, 8.319, 130.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-371.053, -4092.060, 8.319, 310.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-364.523, -4100.343, 8.319, 310.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-389.410, -4113.167, 8.319, 310.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-394.632, -4107.311, 8.319, 310.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-421.593, -4129.027, 8.320, 310.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
        {
            interaction = "search",
            prop = {
                coords = vector4(-409.274, -4140.384, 8.320, 40.0),
                create = true,
                model = SHARED_CONFIG.models.carrierCrate,
            },
            rewardKey = "weapon_case",
        },
    },
}
