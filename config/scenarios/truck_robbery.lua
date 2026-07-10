--[[
    Scenario Configuration: Truck Robbery
    Description: Configuration file for truck robbery scenarios.
    Similar to ammunation_robbery with handler vehicle and container loading system.
]]

local SHARED_CONFIG <const> = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.medium,

    vehicles = {
        truck = "packer",           -- Truck
        trailer = "freighttrailer", -- Trailer to attach to packer
        forklift = "handler",       -- Container loading vehicle
    },

    containerModel = "prop_container_03b",

    attachContainerToForkliftOffset = {
        coords = vector3(0.0, 1.775, -2.4),
        rot = vector3(0.0, 0.0, 90.0),
    },

    attachContainerToTrailerOffset = {
        [1] = {
            coords = vector3(0.0, 4.5, -1.25),
            rot = vector3(0.0, 0.0, 0.0),
        },
        [2] = {
            coords = vector3(0.0, -4.0, -1.25),
            rot = vector3(0.0, 0.0, 0.0),
        },
    },

    locations = {
        [1] = {
            truckCoords = vector4(988.51, -2532.91, 28.38, 356.68),
            trailerCoords = vector4(987.64, -2544.51, 30.24, 356.68),
            forkliftCoords = vector4(85.61, -2490.03, 6.20, 60.47),

            containers = {
                [1] = { coords = vector4(68.145, -2491.346, 7.831, 54.30) },
                [2] = { coords = vector4(68.100, -2491.38, 5.01, 54.30) },
            },

            deliveryCoords = vector3(-459.0836, -1714.8707, 18.6391),

            guards = {
                vector4(65.1537, -2483.7524, 6.0125, 47.8522),
                vector4(70.9276, -2474.4685, 6.0058, 97.5775),
                vector4(93.3749, -2487.9065, 6.0006, 70.2650),
                vector4(87.2867, -2497.1741, 6.0019, 45.9178),
                vector4(73.5000, -2480.0000, 6.0100, 60.0000),
                vector4(80.2000, -2478.5000, 6.0080, 85.0000),
                vector4(90.0000, -2485.0000, 6.0050, 75.0000),
            },
        },
    },
}
