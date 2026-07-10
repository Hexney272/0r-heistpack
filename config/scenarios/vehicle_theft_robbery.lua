local SHARED_CONFIG = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.long,
    
    vehicles = {
        truck = "packer", -- Truck
        trailer = "tr2",  -- Trailer to attach to packer
        one = "adder",
        two = "nero",
        three = "cyclone",
    },
    
    locations = {
        [1] = {

            truckCoords = vector4(914.41, 3590.26, 33.31, 270.82),
            trailerCoords = vector4(904.75, 3590.16, 33.35, 270.55),
            deliveryCoords = vector3(1736.8539, 3284.9548, 41.5),

            vehicles = {
                one = vector4(2141.99, 4782.83, 40.33, 48.50),
                two = vector4(2137.54, 4780.03, 40.33, 37.47),
                three = vector4(2135.17, 4775.70, 40.33, 7.20),
            },

            guards = {
                vector4(2131.41, 4785.00, 40.97, 13.43),
                vector4(2130.62, 4779.67, 40.97, 8.0),
                vector4(2138.62, 4784.83, 40.97, 50.0),
                vector4(2135.59, 4787.72, 40.97, 45.35),
                vector4(2129.40, 4787.81, 40.97, 6.22),
            },
        },
    },
}
