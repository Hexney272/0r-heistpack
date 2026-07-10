--[[
    Scenario: Money Truck Robbery
    Description: This scenario involves robbing a money truck in a high-stakes heist.
]]
return {
    vehicleModel = "stockade",
    escortVehicleModel = "police", -- Escort vehicle model (police transporter or any SUV)

    collectMoneyAnimation = {
        dict = "anim@heists@ornate_bank@grab_cash_heels",
        name = "grab",
        duration = 15000, -- Duration of the money collection animation in milliseconds
    },

    ---@type RewardItem[]
    lootableMoneyRewards = {
        { itemName = "money", chance = 1.0, quantity = { min = 3000, max = 5000 } },
    },

    locations = {
        [1] = {
            truckCoords = vector4(1585.11, -994.62, 60.0, 300.0),
            timeLimit = 300, -- The vehicle must be robbed within the specified time. In seconds.
        },
        [2] = {
            truckCoords = vector4(1332.35, 600.98, 80.0, 312.80),
            timeLimit = 300,
        },
    },
}
