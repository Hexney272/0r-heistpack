--[[
    All script settings are found and edited in this file.
    Make sure to configure everything properly before running the script.
]]

Config = {}

-- Default locale for the script.
Config.locale = "hu"

--[[ The images folder path of your inventory script ]]
-- So that item names and images will match your inventory - images only PNG !
Config.inventoryImagesFolder = "ox_inventory/web/images/"

--[[ Menu Command ]]
Config.heistMenu = {
    -- Command to open the heist menu.
    openWithCommand = {
        enabled = true, -- Set to true to enable command-based menu opening.
        command = "heistmenu",
    },
    -- Keybind to open the heist menu.
    openWithKey = {
        enabled = true, -- Set to true to enable keybind-based menu opening.
        key = "F10",
    },
    -- Item to open the heist menu.
    -- This allows players to open the menu by using a specific item.
    openWithItem = {
        enabled = true,                -- Set to true to enable item-based menu opening.
        itemName = "heistpack_tablet", -- The name of the item that opens the menu.
    },
    -- Jobs allowed to open the heist menu.
    -- If table is empty, all jobs can access the menu.
    -- If you want to restrict access, add specific job names or gang names.
    allowedJobs = {
        -- "job-name", -- Replace "job-name" with the actual job names that can access the menu.
        -- "gang-name", -- Replace "gang-name" with the actual gang names that can access the menu.
    },
    -- Jobs forbidden to open the heist menu.
    -- If a player's job is in this list, they cannot access the menu, even if
    forbiddenJobs = {
        -- "job-name", -- Replace "job-name" with the actual job names that cannot access the menu.
    },

    -- Distance requirement to be near job-giving NPCs to open the menu. (optional) If 0, always accessible.
    requiredMinDistance = 25.0,
}

--[[ Police Settings ]]
Config.policeOptions = {
    requiredCops = 0,          -- Minimum number of police officers required online to start a any heist.
    requiredOnDuty = true,     -- If true, only counts police that are on duty.
    jobNames = {               -- List of job names considered as police roles.
        "police",
        "sheriff",
    },
}

--[[ Level experience ]]
-- Experience experience for each level. You can adjust or expand as needed.
Config.levels = { 0, 1000, 2000, 4000, 8000, 10000, 15000 }

--[[ Job Info Box Expansion Key ]]
Config.infoBoxOptions = {
    align = "left", -- Alignment of the job info box (left or right).
    expandKey = "B" -- Key used to expand additional job-related info (e.g., stats, details).
}

--[[ Money Options ]]
Config.moneyOptions = {
    isItem = true,        -- If set to true, money rewards are given as items. If false, money is added to the player's account.
    itemName = "cash",    -- The name of the money item (if isItem is true).
    accountName = "bank", -- The name of the money account.
}

Config.jobClothingOptions = {
    enabled = true, -- Enable or disable job-specific clothing.
    -- You need to set these values according to your server's clothing system.
    -- The above values are just examples and may not match your server's clothing options.
    outfit = {
        male = {
            qb_qbx = {
                -- QB/QBX
                ["t-shirt"] = { item = 2, texture = 0 },
                ["torso2"] = { item = 68, texture = 0 },
                ["arms"] = { item = 17, texture = 0 },
                ["pants"] = { item = 7, texture = 0 },
                ["shoes"] = { item = 15, texture = 0 },
                ["bag"] = { item = 82, texture = 0 },
            },
            -- ESX
            esx = {
                ["tshirt_1"] = 15,
                ["tshirt_2"] = 0,
                ["torso_1"] = 49,
                ["torso_2"] = 0,
                ["arms"] = 31,
                ["pants_1"] = 35,
                ["pants_2"] = 0,
                ["shoes_1"] = 25,
                ["shoes_2"] = 0,
                ["bags_1"] = 82,
            },
        },
        female = {
            -- QB/QBX
            qb_qbx = {
                ["t-shirt"] = { item = 14, texture = 0 },
                ["torso2"] = { item = 158, texture = 0 },
                ["arms"] = { item = 26, texture = 0 },
                ["pants"] = { item = 76, texture = 0 },
                ["shoes"] = { item = 51, texture = 0 },
                ["bag"] = { item = 82, texture = 0 },
            },
            -- ESX
            esx = {
                ["tshirt_1"] = 14,
                ["tshirt_2"] = 0,
                ["torso_1"] = 158,
                ["torso_2"] = 0,
                ["arms"] = 26,
                ["pants_1"] = 76,
                ["pants_2"] = 0,
                ["shoes_1"] = 51,
                ["shoes_2"] = 0,
                ["bags_1"] = 82,
            }
        }
    },
}

Config.modernTextUI = {
    enabled = true, -- Enable or disable modern or custom textui.
}

--[[ Debug Mode ]]
Config.debug = false -- Enable (true) or disable (false) debug mode for development/testing.
