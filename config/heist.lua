--[[
    Heist Pack - Config File
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {

    blips = {
        employer = { hidden = false, sprite = 429, scale = 0.8, color = 5, name = locale("blips.employer") },
        vehicle  = { sprite = 853, scale = 0.8, color = 5, name = locale("blips.vehicle") },
    },

    employers = {
        {
            coords = vector4(736.0713, -1332.7180, 25.3363, 237.2058),
            pedModel = "s_m_m_movprem_01",
            vehicleSpawnPoints = {
                vector4(742.42, -1354.21, 25.68, 0.0),
            },
        },
    },

    heistScenarios = {
        ["vangelico_robbery"] = {
            isActive = true,    -- Set to false to deactivate this scenario.
            level = 1,          -- Minimum player level required to start the scenario.
            requiredCops = 1,   -- Minimum number of police officers required online to start a heist.
            maxMemberCount = 6, -- Maximum number of players allowed in the scenario.
            -- Required items: Items that players must have to start the scenario.
            requiredItems = {
                { itemName = "heistpack_drone", count = 1, label = "Heistpack Drone", },
            },

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.medium, -- Duration (in minutes) of the entire scenario.
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,    -- Duration (in minutes) a player must wait before starting another scenario.

            rewards = { exp = 300 },                                    -- Rewards given to players upon successful completion of the scenario.

            label = locale("vangelico_robbery.label"),                  -- Localized label for the scenario.
            description = locale("vangelico_robbery.description"),      -- Localized description for the scenario.
            information = locale("vangelico_robbery.information"),      -- Localized additional information for the scenario.

            image = "images/scenarios/vangelico_robbery.png",           -- Image path representing the scenario.

            -- Detailed step-by-step instructions for players participating in the scenario.
            infoTexts = {
                "If you are missing items, visit the market to procure them. (heistpack_drone, gasmask)",
                "Go to the marked area on the map, go to the roof and use the drone.",
                "Use your drone to drop gas bombs on the targeted areas.",
                "Do not forget to wear your mask inside the gas cloud, or your health will be damaged.",
                "When the gas cloud incapacitates those inside the store, the security system will activate and the outer doors will lock.",
                "Blow open the doors with c4 explosives and enter the store.",
                "You can smash display cases, rob people, and collect jewelry inside the store.",
                "And try to complete all the remaining activities.",
                "Get far enough away to finish scenario",
            },
        },
        ["house_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 4,
            simultaneous = 1,

            scenarioCooldown = 0,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 500 },

            label = locale("house_robbery.label"),
            description = locale("house_robbery.description"),
            information = locale("house_robbery.information"),

            image = "images/scenarios/house_robbery.png",

            infoTexts = {
                "If you are missing items, visit the market to procure them. (hacking_device)",
                "Go to the marked area on the map and use your hacking_device to break into the house.",
                "Search the rooms for valuables such as cash, jewelry, and electronics.",
                "Collect as many valuables as you can.",
                "Get far enough away to finish scenario and return to the employer",
            },
        },
        ["atm_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 2,
            simultaneous = 2,

            scenarioCooldown = 0,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 200 },

            label = locale("atm_robbery.label"),
            description = locale("atm_robbery.description"),
            information = locale("atm_robbery.information"),

            image = "images/scenarios/atm_robbery.png",

            infoTexts = {
                "Go to an ATM and interact with target.",
                "Complete the required actions to successfully rob the ATM.",
                "Collect the scattered money on the ground.",
                "Get far enough away to finish scenario.",
            },
        },
        ["store_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 3,
            simultaneous = 2,

            scenarioDuration = SHARED_CONFIG.gameplay.maxDuration.short,
            scenarioCooldown = 0,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 150 },

            label = locale("store_robbery.label"),
            description = locale("store_robbery.description"),
            information = locale("store_robbery.information"),

            image = "images/scenarios/store_robbery.png",

            infoTexts = {
                "Go to any marked store on the map.",
                "Use the weapon to threaten the cashier inside the store.",
                "Take the money from the cashier and continue the robbery.",
                "You can also rob the items and shelves in the store.",
                "Get far enough away to finish scenario and return to the employer",
            },
        },
        ["pacific_bank_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 8,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.long,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 150 },

            label = locale("pacific_bank_robbery.label"),
            description = locale("pacific_bank_robbery.description"),
            information = locale("pacific_bank_robbery.information"),

            image = "images/scenarios/pacific_bank_robbery.png",

            infoTexts = {
                "Go to the marked area and sabotage it with the drone.",
                "Use a drone and explosives to disable security systems.",
                "Target bank marked, open the doors using explosives.",
                "Blow up the security door to access the lower floors.",
                "Open security doors with a doorpad (electronic access).",
                "Disable and open the safe door using a SafePad/Safepad.",
                "Collect all the money from the big safe.",
                "Get far enough away to end the scenario."
            }
        },
        ["paleto_bank_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 6,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.medium,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 150 },

            label = locale("paleto_bank_robbery.label"),
            description = locale("paleto_bank_robbery.description"),
            information = locale("paleto_bank_robbery.information"),

            image = "images/scenarios/paleto_bank_robbery.png",

            infoTexts = {
                "Go to the marked bank and sabotage the electricity at the back.",
                "Target bank marked, open the doors using explosives.",
                "Open the safe door with a doorpad (electronic access).",
                "Collect all the money from the big safe.",
                "Get far enough away to end the scenario."
            }
        },
        ["fleeca_bank_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 4,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.medium,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 150 },

            label = locale("fleeca_bank_robbery.label"),
            description = locale("fleeca_bank_robbery.description"),
            information = locale("fleeca_bank_robbery.information"),

            image = "images/scenarios/fleeca_bank_robbery.png",

            infoTexts = {
                "Go to any marked bank and get inside.",
                "Open the safe door with a safepad (electronic access).",
                "Collect all the money from the big safe.",
                "Get far enough away to end the scenario."
            }
        },
        ["money_truck_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 4,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.short,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 150 },

            label = locale("money_truck_robbery.label"),
            description = locale("money_truck_robbery.description"),
            information = locale("money_truck_robbery.information"),

            image = "images/scenarios/money_truck_robbery.png",

            infoTexts = {
                "Go to the marked money truck location.",
                "Disable the security and access the money.",
                "Get far enough away to end the scenario and return to the employer."
            }
        },
        ["ammunation_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 8,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.long,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 200 },

            label = locale("ammunation_robbery.label"),
            description = locale("ammunation_robbery.description"),
            information = locale("ammunation_robbery.information"),

            image = "images/scenarios/ammunation_robbery.png",

            infoTexts = {
                "Only one of the marks is correct. Go to the correct location !",
                "Steal weapons and ammo from the store.",
                "Get far enough away to end the scenario and return to the employer."
            }
        },
        ["cargo_ship_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 8,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.long,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 300 },

            label = locale("cargo_ship_robbery.label"),
            description = locale("cargo_ship_robbery.description"),
            information = locale("cargo_ship_robbery.information"),

            image = "images/scenarios/cargo_ship_robbery.png",

            infoTexts = {
                "Team leader needs to go near the boat spawn point to get the boat.",
                "Go to the marked cargo ship location on the map.",
                "Find the captain's key in the captain's cabin on the upper deck.",
                "The key will unlock the helicopter on the ship's helipad.",
                "Search the loots scattered around the ship for valuable items.",
                "Use the helicopter to load big cargo containers.",
                "Go to the marked area to drop the container.",
                "Get out of the helicopter for finishing the scenario."
            }
        },
        ["bobcat_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 8,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.long,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 400 },

            label = locale("bobcat_robbery.label"),
            description = locale("bobcat_robbery.description"),
            information = locale("bobcat_robbery.information"),

            image = "images/scenarios/bobcat_robbery.png",

            infoTexts = {
                "Go to the marked Bobcat location.",
                "Break into the vault.",
                "Collect cash from the vault and trolleys.",
                "Get far enough away to finish scenario."
            }
        },
        ["truck_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 8,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.medium,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 250, money = 5000 },

            label = locale("truck_robbery.label"),
            description = locale("truck_robbery.description"),
            information = locale("truck_robbery.information"),

            image = "images/scenarios/truck_robbery.png",

            infoTexts = {
                "Go to the marked container location.",
                "Use the forklift to load the container onto the truck.",
                "Attach the container securely to the truck.",
                "Drive the truck to the marked drop-off location.",
            }
        },
        ["train_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 8,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.medium,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 250, money = 5000 },

            label = locale("train_robbery.label"),
            description = locale("train_robbery.description"),
            information = locale("train_robbery.information"),

            image = "images/scenarios/train_robbery.png",

            infoTexts = {
                "Go to the marked train location.",
                "Fight with the guards and take control of the money-filled wagon.",
                "Open the container and collect the money inside.",
                "Get far enough away to finish scenario."
            }
        },
        ["vehicle_theft_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 4,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.short,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 200, money = 3000 },

            label = locale("vehicle_theft_robbery.label"),
            description = locale("vehicle_theft_robbery.description"),
            information = locale("vehicle_theft_robbery.information"),

            image = "images/scenarios/vehicle_theft_robbery.png",

            infoTexts = {
                "Go to the marked location to get the truck.",
                "Go to the marked vehicles and neutralize the guards.",
                "Steal the vehicle and drive it to the drop-off point.",
            }
        },
        ["yacht_robbery"] = {
            level = 1,
            requiredCops = 1,
            maxMemberCount = 6,

            scenarioCooldown = SHARED_CONFIG.gameplay.cooldowns.medium,
            playerCooldown = SHARED_CONFIG.gameplay.cooldowns.short,

            rewards = { exp = 300, money = 1000 },

            label = locale("yacht_robbery.label"),
            description = locale("yacht_robbery.description"),
            information = locale("yacht_robbery.information"),

            image = "images/scenarios/yacht_robbery.png",

            infoTexts = {
                "Go to the marked yacht location.",
                "Board the yacht and locate the valuables.",
                "Collect cash, jewelry, and other valuables from the yacht.",
                "Get far enough away to finish scenario."
            }
        },
    }
}
