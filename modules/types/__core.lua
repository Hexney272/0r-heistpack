---@class RewardItem
---@field itemName string
---@field chance number
---@field quantity { min: number, max: number }

---@class HouseRobberyInterior
---@field locations { entrance: vector3, exit: vector3,inside: vector4 }
---@field loots LootPoint[]
---@field isActive boolean?

---@alias LootPointInteraction "grab" | "search" | "carry"

---@class LootPointZone
---@field center vector3
---@field size vector3
---@field rotation number
---@field debug boolean

---@class LootPointPositions
---@field onHolding {offset: vector3, rotation: vector3, boneId: number}
---@field onVehicle {offset: vector3, rotation: vector3, boneName: number}

---@class LootPoint
---@field interaction LootPointInteraction
---@field prop { create: boolean, model: string|number, coords: vector4|vector3|vector2 } | nil
---@field zone LootPointZone | nil
---@field positions LootPointPositions |nil
---@field rewardKey string
---@field looted boolean
---@field busy boolean
---@field markerCoords vector3 | nil
---@field placedObjectNetId number | nil
