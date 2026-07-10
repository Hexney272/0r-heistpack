local Inventory = {}

function Inventory.disarm()
    if shared.isResourceStart("ox_inventory") then
        TriggerEvent("ox_inventory:disarm", true)
    end
end

return Inventory
