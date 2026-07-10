local lib = lib

local CUSTOM_GROUP = "HEIST_GUARDS"
AddRelationshipGroup(CUSTOM_GROUP)
SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey(CUSTOM_GROUP))
SetRelationshipBetweenGroups(5, GetHashKey(CUSTOM_GROUP), GetHashKey("PLAYER"))

---@class GuardManager
---@field guards table[] List of guard configurations
---@field onGuardsSpawned function|nil Callback when guards spawned
---@field guardEntities table<number, number> Guard entity handles
---@field spawnedGuards boolean
---@field combatThreads table<number, boolean> Active combat threads
local GuardManager = {}
GuardManager.__index = GuardManager

---@class GuardManagerOptions
---@field guards table[] List of guard spawn configurations
---@field onGuardsSpawned? fun(guardNetIds: table) Callback when guards are spawned
---@field targetPlayers? table[] List of target player peds (optional, can be set later)

---Create new guard manager instance
---@param options GuardManagerOptions
---@return GuardManager
function GuardManager.new(options)
    local self = setmetatable({}, GuardManager)

    self.guards = options.guards or {}
    self.onGuardsSpawned = options.onGuardsSpawned
    self.targetPlayers = options.targetPlayers or {}
    self.guardEntities = {}
    self.spawnedGuards = false
    self.combatThreads = {}

    return self
end

---Set target players for guards to attack
---@param targetPlayers table[] List of player ped handles
function GuardManager:setTargetPlayers(targetPlayers)
    self.targetPlayers = targetPlayers
end

---Update target players from lobby members
---@param lobby table Lobby object with members
function GuardManager:updateTargetPlayersFromLobby(lobby)
    local targetPlayers = {}
    if lobby and lobby.members then
        for _, member in pairs(lobby.members) do
            local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
            if DoesEntityExist(memberPed) then
                table.insert(targetPlayers, memberPed)
            end
        end
    end
    self.targetPlayers = targetPlayers
end

---Check if guards are spawned
---@return boolean
function GuardManager:areGuardsSpawned()
    return self.spawnedGuards
end

---Spawn all guards
---@param guardModel? string|number Guard ped model (default: "s_m_m_armoured_01")
---@param weapon? string Weapon hash (default: "WEAPON_CARBINERIFLE")
---@return boolean success
function GuardManager:spawnGuards(guardModel, weapon)
    if self.spawnedGuards then
        return false
    end

    guardModel = guardModel or "s_m_m_armoured_01"
    weapon = weapon or "WEAPON_CARBINERIFLE"

    local modelHash = type(guardModel) == "string" and GetHashKey(guardModel) or guardModel
    lib.requestModel(modelHash)

    local guardNetIds = {}

    for guardIndex, guardCoord in ipairs(self.guards) do
        local guard = CreatePed(4, modelHash, guardCoord.x, guardCoord.y, guardCoord.z, guardCoord.w or 0.0, true, true)

        -- Set guard properties
        SetPedArmour(guard, 100)
        SetPedMaxHealth(guard, 300)
        SetEntityHealth(guard, 300)
        GiveWeaponToPed(guard, GetHashKey(weapon), 250, false, true)
        SetPedCombatAttributes(guard, 46, true)
        SetPedCombatAbility(guard, 100)
        SetPedCombatMovement(guard, 2)
        SetPedCombatRange(guard, 2)
        SetPedFleeAttributes(guard, 0, false)
        SetPedAsEnemy(guard, true)
        SetPedRelationshipGroupDefaultHash(guard, GetHashKey(CUSTOM_GROUP))
        SetPedRelationshipGroupHash(guard, GetHashKey(CUSTOM_GROUP))
        SetBlockingOfNonTemporaryEvents(guard, false)
        SetPedDropsWeaponsWhenDead(guard, false)
        AddRelationshipGroup(AGGRESSIVE_GROUP)

        TaskCombatPed(guard, cache.ped, 0, 16)

        SetPedKeepTask(guard, true)
        SetPedHasAiBlip(guard, true)
        SetPedAiBlipHasCone(guard, false)

        -- Store guard entity
        self.guardEntities[guardIndex] = guard

        -- Start guard combat behavior thread
        self:startGuardCombatThread(guardIndex, guard)

        -- Network the guard
        local guardNetId = lib.waitFor(function()
            if not NetworkGetEntityIsNetworked(guard) then
                NetworkRegisterEntityAsNetworked(guard)
            else
                local netId = PedToNet(guard)
                if NetworkDoesNetworkIdExist(netId) then
                    return netId
                end
            end
        end, nil, false)

        if guardNetId then
            table.insert(guardNetIds, guardNetId)
        end
    end

    SetModelAsNoLongerNeeded(modelHash)
    self.spawnedGuards = true

    if self.onGuardsSpawned then
        self.onGuardsSpawned(guardNetIds)
    end

    return true
end

---Start combat behavior thread for a guard
---@param guardIndex number
---@param guard number Guard entity handle
function GuardManager:startGuardCombatThread(guardIndex, guard)
    if self.combatThreads[guardIndex] then
        return
    end

    self.combatThreads[guardIndex] = true

    Citizen.CreateThread(function()
        while ClientApplication.state.activeScenario and DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) do
            Citizen.Wait(1000)

            -- Check if guard is being attacked or sees player
            if HasEntityBeenDamagedByAnyPed(guard) or IsPedBeingStunned(guard, 0) then
                -- Target nearest player
                if #self.targetPlayers > 0 then
                    local guardCoords = GetEntityCoords(guard)
                    local nearestPlayer = nil
                    local nearestDistance = math.huge

                    for _, playerPed in ipairs(self.targetPlayers) do
                        if DoesEntityExist(playerPed) then
                            local playerCoords = GetEntityCoords(playerPed)
                            local distance = #(guardCoords - playerCoords)
                            if distance < nearestDistance then
                                nearestDistance = distance
                                nearestPlayer = playerPed
                            end
                        end
                    end

                    if nearestPlayer then
                        TaskCombatPed(guard, nearestPlayer, 0, 16)
                    end
                end
                break
            end
        end

        self.combatThreads[guardIndex] = false
    end)
end

---Spawn guards from network IDs (for non-owner clients)
---@param guardNetIds table List of network IDs
function GuardManager:syncGuardsFromNetIds(guardNetIds)
    if self.spawnedGuards then
        return
    end

    for guardIndex, netId in ipairs(guardNetIds) do
        local guard = NetToPed(netId)
        if DoesEntityExist(guard) then
            self.guardEntities[guardIndex] = guard
        end
    end

    self.spawnedGuards = true
end

---Get all guard entities
---@return table<number, number>
function GuardManager:getGuardEntities()
    return self.guardEntities
end

---Get guard entity by index
---@param guardIndex number
---@return number|nil
function GuardManager:getGuardEntity(guardIndex)
    return self.guardEntities[guardIndex]
end

---Check if guard is alive
---@param guardIndex number
---@return boolean
function GuardManager:isGuardAlive(guardIndex)
    local guard = self.guardEntities[guardIndex]
    return guard and DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true)
end

---Count alive guards
---@return number
function GuardManager:countAliveGuards()
    local count = 0
    for guardIndex, _ in pairs(self.guardEntities) do
        if self:isGuardAlive(guardIndex) then
            count = count + 1
        end
    end
    return count
end

---Clear all resources
function GuardManager:clear()
    -- Stop combat threads
    for guardIndex, _ in pairs(self.combatThreads) do
        self.combatThreads[guardIndex] = false
    end

    -- Delete guard entities
    for _, guard in pairs(self.guardEntities) do
        if DoesEntityExist(guard) then
            SetEntityAsMissionEntity(guard, true, true)
            DeleteEntity(guard)
        end
    end

    self.guardEntities = {}
    self.combatThreads = {}
    self.spawnedGuards = false
    self.targetPlayers = {}
end

return GuardManager
