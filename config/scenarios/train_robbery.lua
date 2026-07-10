local SHARED_CONFIG = lib.load("config.scenarios._shared")

return {
    requiredDistanceForFinish = SHARED_CONFIG.gameplay.finishDistance.long,

    rewardMoney = { min = 8000, max = 15000 },

    locations = {
        [1] = {
            trainModel = "freight",
            trainCoords = vector4(2891.08, 4564.92, 47.8, 136.38),

            freightCars = {
                { model = "freightcar", coords = vector4(2916.98, 4592.43, 47.8, 316.55) },
                { model = "freightcar", coords = vector4(2903.76, 4578.44, 47.8, 316.55) },
            },

            containers = {
                { model = "tr_prop_tr_container_01a", coords = vector4(2918.479, 4594.036, 48.059, 316.55) },
                { model = "tr_prop_tr_container_01b", coords = vector4(2903.812, 4578.493, 48.059, 316.55) },
            },

            guards = {
                vector4(2904.0271, 4572.1885, 48.1954, 159.4978),
                vector4(2898.9077, 4566.8481, 48.1056, 137.0804),
                vector4(2887.7095, 4564.7168, 48.4612, 138.2525),
                vector4(2912.6797, 4583.5386, 48.3715, 204.0553),
                vector4(2904.0271, 4572.1885, 48.1954, 159.4978),
                vector4(2898.9077, 4566.8481, 48.1056, 137.0804),
                vector4(2887.7095, 4564.7168, 48.4612, 138.2525),
                vector4(2912.6797, 4583.5386, 48.3715, 204.0553),
            },
        },
    },
}
