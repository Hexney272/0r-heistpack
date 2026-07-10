return {
    requiredItem = {
        name = "heistpack_drone",
        label = "Heistpack Drone"
    },                                      -- Item required to use the drone.
    maxUsageDistance = 250.0,               -- Maximum distance (in meters) the drone can be away from the player.

    propModel = "ch_prop_casino_drone_02a", -- Drone prop model.
    tabletModel = "hei_prop_dlc_tablet",    -- Tablet prop model.

    holding = {
        dict = "amb@world_human_clipboard@male@idle_a",
        name = "idle_a",
        bone = 60309,
        offset = vector3(0.0, 0.0, 0.02),
        rotation = vector3(0.0, 120.0, 0.0)
    }
}
