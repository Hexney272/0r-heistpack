local Utils               = require("modules.utils.client")
local Inventory           = require("modules.inventory.client")

---@class LootManagerClient
---@field private loots table[] List of loot configurations
---@field private onLootInteract? fun(lootIndex: number, interaction: string) Callback when loot is interacted
---@field private animations table Animation configurations for different interaction types
---@field private spawnedProps table<number, number> Spawned prop entities indexed by loot index
---@field private markerThread boolean|nil Marker rendering thread status
---@field private deleteThread boolean|nil Prop deletion thread status
---@field private targetZones table<string, string> Created target zones indexed by zone key
---@field private targetEntities table<number, boolean> Created target entities indexed by entity handle
--- Manages loot interactions (grab, search, carry) with prop spawning and highlighting
local LootManagerClient   = {}
LootManagerClient.__index = LootManagerClient

---@class LootManagerOptions
---@field loots table[] List of loot configurations
---@field onLootInteract? fun(lootIndex: number, interaction: string) Callback when loot is interacted
---@field animations? table Animation configurations for different interaction types
---@field Target? table Target system instance (ox_target or similar)

---Create new loot manager instance
---@param options LootManagerOptions
---@return LootManagerClient
function LootManagerClient.new(options)
    ---@type LootManagerClient
    local self = setmetatable({}, LootManagerClient)

    self.loots = options.loots or {}
    self.onLootInteract = options.onLootInteract
    self.animations = options.animations or {}
    self.Target = options.Target

    self.spawnedProps = {}
    self.markerThread = nil
    self.deleteThread = nil
    self.targetZones = {}
    self.targetEntities = {}

    return self
end

---Spawn loot props
function LootManagerClient:spawnLoots()
    for lootIndex, loot in pairs(self.loots) do
        if loot.prop and loot.prop.create then
            local prop = Utils.createObject({
                model = loot.prop.model,
                coords = loot.prop.coords,
                rotation = loot.prop.coords.w or 0.0,
                freeze = true,
                isNetwork = false,
            })
            if not prop then return end

            if DoesEntityExist(prop) then
                self.spawnedProps[lootIndex] = prop
            end
        end
    end
end

---Mark loot as busy (being looted)
---@param lootIndex number
function LootManagerClient:markLootBusy(lootIndex)
    local loot = self.loots[lootIndex]
    if loot then
        loot.busy = true
    end
end

---Mark loot as looted
---@param lootIndex number
---@param deleteProp? boolean Should the prop be deleted
function LootManagerClient:markLootLooted(lootIndex, deleteProp)
    local loot = self.loots[lootIndex]
    if not loot then return end

    loot.looted = true
    loot.busy = false

    local prop = self.spawnedProps[lootIndex]
    if prop and DoesEntityExist(prop) then
        if deleteProp then
            DeleteEntity(prop)
            self.spawnedProps[lootIndex] = nil
        else
            SetEntityDrawOutline(prop, false)
        end
    end
end

---Check if loot is looted
---@param lootIndex number
---@return boolean
function LootManagerClient:isLootLooted(lootIndex)
    local loot = self.loots[lootIndex]
    return loot and loot.looted or false
end

---Check if loot is busy
---@param lootIndex number
---@return boolean
function LootManagerClient:isLootBusy(lootIndex)
    local loot = self.loots[lootIndex]
    return loot and loot.busy or false
end

---Start marker thread to highlight nearby loots
---@param drawDistance? number Distance to show markers (default: 5.0)
---@param insideCheck? fun(): boolean Function to check if player is in valid area
function LootManagerClient:startMarkerThread(drawDistance, insideCheck)
    if self.markerThread then return end

    drawDistance = drawDistance or 5.0
    self.markerThread = true

    Citizen.CreateThread(function()
        while self.markerThread do
            local wait = 1000
            local playerCoords = GetEntityCoords(cache.ped)

            if not insideCheck or insideCheck() then
                wait = 500

                for lootIndex, loot in pairs(self.loots) do
                    if not loot.looted and not loot.busy then
                        local targetCoords = nil

                        if loot.prop and loot.prop.coords then
                            targetCoords = vector3(loot.prop.coords.x, loot.prop.coords.y, loot.prop.coords.z)
                        elseif loot.zone and loot.zone.center then
                            targetCoords = loot.zone.center
                        end

                        if targetCoords then
                            local distance = #(playerCoords - targetCoords)

                            if distance < drawDistance then
                                -- Draw marker
                                if loot.markerCoords then
                                    wait = 0
                                    DrawMarker(
                                        28,
                                        loot.markerCoords.x, loot.markerCoords.y, loot.markerCoords.z,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.04, 0.04, 0.04,
                                        189, 219, 9, 255,
                                        false, true, 2, false, nil, nil, false
                                    )
                                end

                                -- Draw outline
                                if not loot.outlined and loot.prop then
                                    loot.outlined = true
                                    local prop = GetClosestObjectOfType(
                                        targetCoords.x, targetCoords.y, targetCoords.z, 0.3,
                                        loot.prop.model,
                                        false, false, false
                                    )

                                    if DoesEntityExist(prop) then
                                        SetEntityAsMissionEntity(prop, true, true)
                                        SetEntityDrawOutline(prop, true)
                                        SetEntityDrawOutlineColor(189, 219, 9, 255)
                                        SetEntityDrawOutlineShader(1)
                                    end
                                end
                            elseif loot.outlined then
                                loot.outlined = false

                                if loot.prop then
                                    local prop = GetClosestObjectOfType(
                                        targetCoords.x, targetCoords.y, targetCoords.z, 0.3,
                                        loot.prop.model,
                                        false, false, false
                                    )

                                    if DoesEntityExist(prop) then
                                        SetEntityDrawOutline(prop, false)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

---Stop marker thread
function LootManagerClient:stopMarkerThread()
    self.markerThread = false
end

---Start thread to delete looted default props
---@param insideCheck? fun(): boolean Function to check if player is in valid area
---@param excludeObject? number Object entity to exclude from deletion
function LootManagerClient:startDeleteThread(insideCheck, excludeObject)
    if self.deleteThread then return end

    self.deleteThread = true

    Citizen.CreateThread(function()
        while self.deleteThread do
            local wait = 1000

            if not insideCheck or insideCheck() then
                for lootIndex, loot in pairs(self.loots) do
                    if (loot.looted or loot.busy) and loot.prop and not loot.prop.create then
                        local prop = GetClosestObjectOfType(
                            loot.prop.coords.x, loot.prop.coords.y, loot.prop.coords.z, 0.3,
                            loot.prop.model,
                            false, false, false
                        )

                        if DoesEntityExist(prop) and prop ~= excludeObject then
                            SetEntityAsMissionEntity(prop, true, true)
                            DeleteObject(prop)
                        end
                    end
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

---Stop delete thread
function LootManagerClient:stopDeleteThread()
    self.deleteThread = false
end

---Get spawned prop for loot
---@param lootIndex number
---@return number|nil prop Entity handle
function LootManagerClient:getSpawnedProp(lootIndex)
    return self.spawnedProps[lootIndex]
end

---Setup target interactions for all loots
---@param options table Options for target setup
---@param options.getLootLabel fun(loot: table, lootIndex: number): string Function to get target label
---@param options.canInteract fun(loot: table, lootIndex: number): boolean Function to check if can interact
---@param options.onSelect fun(loot: table, lootIndex: number) Function called when target is selected
---@param options.zonePrefix? string Prefix for target zone names (default: "loot_manager")
---@param options.debug? boolean Debug mode for target zones
function LootManagerClient:setupTargets(options)
    if not self.Target then
        error("Target system not provided to LootManagerClient")
        return
    end

    local zonePrefix = options.zonePrefix or "loot_manager"

    for lootIndex, loot in pairs(self.loots) do
        -- Setup target for spawned props
        if loot.prop and loot.prop.create then
            local prop = self:getSpawnedProp(lootIndex)
            if prop and not loot.zone then
                local targetLabel = options.getLootLabel(loot, lootIndex)

                self.Target.addLocalEntity(prop, { {
                    label = targetLabel,
                    icon = "fa-solid fa-circle-notch",
                    distance = 2.0,
                    canInteract = function()
                        return options.canInteract(loot, lootIndex)
                    end,
                    onSelect = function()
                        Inventory.disarm()
                        options.onSelect(loot, lootIndex)
                    end,
                } })

                self.targetEntities[prop] = true
            end
        end

        -- Setup target zones
        if loot.zone then
            local zoneName = ("%s:loot:%s"):format(zonePrefix, lootIndex)
            local targetLabel = options.getLootLabel(loot, lootIndex)

            self.targetZones["loot_" .. lootIndex] = zoneName

            self.Target.addBoxZone(zoneName, {
                name = zoneName,
                coords = loot.zone.center,
                size = loot.zone.size or vector3(0.5, 0.5, 0.5),
                rotation = loot.zone.rotation or 0.0,
                debug = loot.zone.debug or options.debug,
                options = { {
                    label = targetLabel,
                    icon = "fa-solid fa-circle-notch",
                    distance = 2.0,
                    canInteract = function()
                        return options.canInteract(loot, lootIndex)
                    end,
                    onSelect = function()
                        options.onSelect(loot, lootIndex)
                    end,
                } },
            })
        end
    end
end

---Clear target zones and entities
function LootManagerClient:clearTargets()
    if not self.Target then return end

    -- Remove target zones
    for _, zoneName in pairs(self.targetZones) do
        if zoneName then
            self.Target.removeZone(zoneName)
        end
    end

    -- Target entities are automatically cleaned when entities are deleted
    self.targetZones = {}
    self.targetEntities = {}
end

---Clear all loots
function LootManagerClient:clear()
    self:stopMarkerThread()
    self:stopDeleteThread()
    self:clearTargets()

    for _, prop in pairs(self.spawnedProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end

    self.spawnedProps = {}
    self.loots = {}
end

return LootManagerClient
