--[[
    Yacht Robbery Scenario Configuration
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.medium,

    -- Yacht location
    yachtCoords = vector4(-2043.2511, -1032.1445, 11.9806, 0.0),

    -- Guards configuration
    guards = {
        vector4(-2045.2971, -1026.7419, 11.9076, 303.2511),
        vector4(-2047.9131, -1035.5886, 11.9008, 283.1418),
        vector4(-2068.7258, -1024.5854, 11.9093, 241.8759),
        vector4(-2068.3169, -1021.8844, 11.9101, 274.1924),
        vector4(-2075.4827, -1021.3104, 11.9090, 251.8197),
        vector4(-2076.2288, -1024.5087, 11.9090, 185.5209),
    },

    -- Loot points configuration
    loots = {
        -- Drug packages
        {
            prop = {
                model = "hei_prop_heist_weed_block_01",
                coords = vector3(-2051.919, -1031.918, 11.867),
                create = true,
            },
            interaction = "grab",
            rewardKey = "drug_package",
        },
        {
            prop = {
                model = "hei_prop_heist_weed_block_01",
                coords = vector3(-2053.327, -1033.295, 11.867),
                create = true,
            },
            interaction = "grab",
            rewardKey = "drug_package",
        },
        {
            prop = {
                model = "bkr_prop_coke_cutblock_01",
                coords = vector3(-2058.581, -1029.302, 12.012),
                create = true,
            },
            interaction = "grab",
            rewardKey = "drug_package",
        },
        -- Money
        {
            prop = {
                model = "bkr_prop_money_wrapped_01",
                coords = vector3(-2072.643, -1019.721, 11.822),
                create = true,
            },
            interaction = "grab",
            rewardKey = "money",
        },
        {
            prop = {
                model = "bkr_prop_money_wrapped_01",
                coords = vector3(-2074.001, -1024.047, 11.822),
                create = true,
            },
            interaction = "grab",
            rewardKey = "money",
        },
        {
            prop = {
                model = "bkr_prop_money_wrapped_01",
                coords = vector3(-2074.204, -1024.742, 11.822),
                create = true,
            },
            interaction = "grab",
            rewardKey = "money",
        },
    },

    -- Loot reward items
    lootRewardItems = {
        drug_package = {
            { itemName = "weed_package", quantity = { min = 1, max = 3 }, chance = 0.5 },
            { itemName = "coke_package", quantity = { min = 1, max = 2 }, chance = 0.3 },
            { itemName = "meth_package", quantity = { min = 1, max = 2 }, chance = 0.2 },
        },
        bottles = {
            { itemName = "vodka_bottle",   quantity = { min = 1, max = 2 }, chance = 0.4 },
            { itemName = "whiskey_bottle", quantity = { min = 1, max = 2 }, chance = 0.35 },
            { itemName = "beer_bottle",    quantity = { min = 2, max = 4 }, chance = 0.25 },
        },
        money = {
            { itemName = "cash", quantity = { min = 500, max = 1000 }, chance = 1.0 },
        },
    },
}
