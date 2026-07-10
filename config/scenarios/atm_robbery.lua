--[[
    Scenario Configuration: ATM Robbery
    Description: Configuration file for ATM robbery scenarios.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.short,

    -- ATM Models that can be targeted for robbery
    atmModels = {
        "prop_atm_01",
        "prop_atm_02",
        "prop_atm_03",
        "prop_fleeca_atm",
    },

    ropeOptions = {
        requiredItem = { itemName = "heavy_rope", label = "Heavy Rope" },

        animation = SHARED_CONFIG.animations.working,
        addSkillCheck = false,

        ---@type RewardItem[]
        rewards = {
            { itemName = "money", chance = 1.0, quantity = { min = 1000, max = 3000 } },
        }
    },

    hackingOptions = {
        ---@type RewardItem[]
        rewards = {
            { itemName = "money", chance = 1.0, quantity = { min = 2000, max = 5000 } },
        }
    },

    explodeOptions = {
        requiredItem = { itemName = "weapon_stickybomb", label = "Sticky Bomb" },

        animation = SHARED_CONFIG.animations.plantBomb,
        addSkillCheck = false,

        -- Offsets for placing the explosive on different ATM models
        modelPlantingOffsets = {
            ["prop_atm_01"] = vector3(0.0, -0.2, 1.0),
            ["prop_fleeca_atm"] = vector3(0.0, 0.0, 1.0),
        },

        ---@type RewardItem[]
        rewards = {
            { itemName = "money", chance = 1.0, quantity = { min = 3000, max = 7000 } },
        }
    },

    drillOptions = {
        requiredItem = { itemName = "heistpack_drill", label = "Heist Drill" },

        animation = SHARED_CONFIG.animations.useDrill,
        addSkillCheck = true,

        -- Offset for placing the drill on the ATM
        positionOffset = vector3(0.0, -0.5, 0.0), ---@type RewardItem[]

        rewards = {
            { itemName = "money", chance = 1.0, quantity = { min = 2500, max = 6000 } },
        }
    },

    -- Money collection settings
    collectMoneyOptions = {
        -- Animation for collecting scattered money
        animation = {
            dict = "pickup_object",
            name = "pickup_low",
        },

        -- Progress bar duration in milliseconds
        duration = 8000,
    },
}
