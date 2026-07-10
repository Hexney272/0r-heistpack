--[[
    Shared Scenario Configuration
    Description: Common configurations and structures used across multiple scenarios

    This file contains common structures used across all scenarios:
    - Animations
    - Reward types
    - Common variable names
    - Standard configurations
]]

return {
    ---@section COMMON BLIP CONFIGURATIONS
    -- Commonly used blip configurations
    blips = {
        atm            = { sprite = 207, scale = 0.8, color = 5, name = locale("blips.atm") },
        bank_entrance  = { sprite = 431, scale = 0.8, color = 5, name = locale("blips.bank_entrance") },
        house          = { sprite = 845, scale = 0.8, color = 5, name = locale("blips.house") },
        truck          = { sprite = 477, scale = 0.8, color = 5, name = locale("blips.money_truck") },
        escort         = { sprite = 225, scale = 0.7, color = 5, name = locale("blips.escort_vehicle") },
        bomb_drop_zone = { sprite = 486, scale = 0.8, color = 5, name = locale("blips.bomb_drop_zone") },
        drone          = { sprite = 627, scale = 0.8, color = 5, name = locale("blips.drone") },
        electric_box   = { sprite = 303, scale = 0.8, color = 5, name = locale("blips.electric_box") },
        cashier        = { sprite = 59, scale = 0.8, color = 5, name = locale("blips.cashier") },
        gas_drop_zone  = { sprite = 161, scale = 0.8, color = 5, name = locale("blips.gas_drop_zone") },
        jewelry        = { sprite = 617, scale = 0.8, color = 5, name = locale("blips.jewelry_store") },
        point          = { sprite = 270, scale = 0.8, color = 5, name = locale("blips.point") },
        container      = { sprite = 478, scale = 0.8, color = 5, name = locale("blips.container") },
        ship           = { sprite = 410, scale = 0.8, color = 5, name = locale("blips.cargo_ship") },
        boat           = { sprite = 427, scale = 0.8, color = 5, name = locale("blips.boat") },
        train          = { sprite = 795, scale = 0.8, color = 5, name = locale("blips.train") },
        theft_vehicle  = { sprite = 225, scale = 0.8, color = 5, name = locale("blips.theft_vehicle") },
        theft_delivery = { sprite = 289, scale = 0.8, color = 5, name = locale("blips.theft_delivery") },
        yacht          = { sprite = 455, scale = 0.8, color = 5, name = locale("blips.yacht") },
    },

    ---@section COMMON GAMEPLAY VALUES
    -- Common gameplay values
    gameplay = {
        -- Standard maximum scenario durations (minutes)
        maxDuration = {
            short = 30,
            medium = 60,
            long = 90,
        },
        -- Standard cooldown durations (minutes)
        cooldowns = {
            short = 10,  -- 10 minutes
            medium = 30, -- 30 minutes
            long = 60,   -- 60 minutes
        },

        -- Standard finish distance values
        finishDistance = {
            short = 150.0,  -- Small heists like ATM, Store
            medium = 200.0, -- Medium level heists
            long = 250.0,   -- Large bank robberies
        },

        -- Standard damage values
        damage = {
            gasPerSecond = 3,
        },
    },

    ---@section COMMON ANIMATIONS
    -- Commonly used animations
    animations = {
        -- Working animation (for ATM)
        working = {
            dict = "missmechanic",
            name = "work2_base",
            duration = 10000,
        },

        -- Bomb planting
        plantBomb = {
            dict = "anim@heists@ornate_bank@thermal_charge",
            name = "thermal_charge",
            duration = 10000,
        },

        -- Drill usage
        useDrill = {
            dict = "anim@heists@fleeca_bank@drilling",
            name = "drill_straight_start",
            duration = 10000,
        },

        -- Cash collecting animations
        grabCash = {
            dict = "anim@heists@ornate_bank@grab_cash_heels",
            name = "grab",
            duration = 10000,
        },
        grabMoney = {
            dict = "anim@scripted@heist@ig1_table_grab@cash@male@",
            name = "grab",
            duration = 10000,
        },

        -- Carry animations
        carryBox = {
            dict = "anim@heists@box_carry@",
            name = "idle",
        },

        -- Search animations
        search = {
            dict = "missexile3",
            name = "ex03_dingy_search_case_base_michael",
            duration = 10000,
        },
    },

    ---@section COMMON PROP MODELS
    -- Commonly used model names
    models = {
        cashPile = "hei_prop_heist_cash_pile",
        cashStack = "h4_prop_h4_cash_stack_01a",
        cashPileSmall = "bkr_prop_bkr_cashpile_01",
        cashPileScattered = "bkr_prop_bkr_cashpile_05",
        cashCrate = "vw_prop_vw_crate_02a",

        cashTrolley = "hei_prop_hei_cash_trolly_01",
        ingotTrolley = "imp_prop_impexp_coke_trolly",
        emptyTrolley = "hei_prop_hei_cash_trolly_03",

        bag = "hei_p_m_bag_var22_arm_s",

        drill = "ch_prop_ch_heist_drill",
        bomb = "prop_bomb_01",
        ropeHook = "prop_rope_hook_01",

        fakeContainer = "prop_ld_container",
        cratesWeapon = "xm_prop_crates_weapon_mix_01a",
        carrierCrate = "hei_prop_carrier_crate_01a_s",

        guard = "s_m_m_armoured_01",

        speedboat = "dinghy",
        vehicleKey = "p_car_keys_01",
        cargoHelicopter = "skylift",
        bigContainer = "prop_container_ld_d",
        ladder = "prop_byard_ramp",
    },

    ---@section COMMON CARRY POSITIONS
    -- Common carry positions (for props)
    carryPositions = {
        standard = {
            onHolding = {
                offset = vector3(0.0, -0.1, -0.1),
                rotation = vector3(0.0, 0.0, 0.0),
                boneId = 28422,
            },
            onVehicle = {
                offset = vector3(0.0, -1.2, 0.23),
                rotation = vector3(0.0, 0.0, 270.0),
            },
        },

        microwave = {
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

        monitor = {
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
}
