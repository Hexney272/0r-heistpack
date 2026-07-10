---@class PlayerInsideData
---@field inside boolean
---@field lastCoords vector4

---@class InteriorManagerServerOptions
---@field lobbyId string Lobby identifier
---@field bucketFormat string Format string for bucket ID (e.g., "5%d")
---@field locations table<string, vector4> Interior locations (entrance, inside, exit)

---@class InteriorManagerServer
---@field lobbyId string
---@field bucketFormat string
---@field interiorId number
---@field locations table<string, vector4>
---@field playersInside table<string, PlayerInsideData>
---@field bucketId number
local InteriorManagerServer = {}
InteriorManagerServer.__index = InteriorManagerServer

---Create new server-side interior manager instance
---@param options InteriorManagerServerOptions
---@return InteriorManagerServer
function InteriorManagerServer.new(options)
    local self = setmetatable({}, InteriorManagerServer)

    self.lobbyId = options.lobbyId
    self.bucketFormat = options.bucketFormat or "5%d"
    self.interiorId = options.interiorId
    self.locations = options.locations or {}
    self.playersInside = {}
    self.bucketId = self:generateBucketId(options.interiorId)

    return self
end

---Set interior locations
---@param locations table<string, vector4> Locations table with entrance, inside, exit coords
function InteriorManagerServer:setLocations(locations)
    self.locations = locations
end

---Generate bucket ID for this interior
---@param interiorId number Interior identifier
---@return number bucketId
function InteriorManagerServer:generateBucketId(interiorId)
    local bucketString = string.format(self.bucketFormat, interiorId)
    return self.bucketId
end

---Teleport player inside interior
---@param playerId string Player server ID
---@param holdingObjectNetId? number Optional: Network ID of object player is holding
---@return boolean success
function InteriorManagerServer:teleportInside(playerId, holdingObjectNetId)
    SetPlayerRoutingBucket(playerId, self.bucketId)

    -- Teleport player
    local insideCoords = self.locations.inside
    local playerPed = GetPlayerPed(playerId)
    SetEntityCoords(playerPed, insideCoords.x, insideCoords.y, insideCoords.z, false, false, false, false)
    SetEntityHeading(playerPed, insideCoords.w or 0.0)

    -- Move holding object to same bucket
    if holdingObjectNetId then
        local holdingObject = NetworkGetEntityFromNetworkId(holdingObjectNetId)
        if DoesEntityExist(holdingObject) then
            SetEntityRoutingBucket(holdingObject, self.bucketId)
        end
    end

    -- Track player
    self.playersInside[playerId] = {
        inside = true,
        lastCoords = self.locations.entrance
    }

    return true
end

---Teleport player outside interior
---@param playerId string Player server ID
---@param holdingObjectNetId? number Optional: Network ID of object player is holding
---@return boolean success
function InteriorManagerServer:teleportOutside(playerId, holdingObjectNetId)
    local playerPed = GetPlayerPed(playerId)
    if not DoesEntityExist(playerPed) then
        return false
    end

    -- Reset routing bucket
    SetPlayerRoutingBucket(playerId, 0)

    -- Teleport player
    local outsideCoords = self.locations.outside or self.locations.entrance
    SetEntityCoords(playerPed, outsideCoords.x, outsideCoords.y, outsideCoords.z, false, false, false, false)
    SetEntityHeading(playerPed, outsideCoords.w or 0.0)

    -- Move holding object to default bucket
    if holdingObjectNetId then
        local holdingObject = NetworkGetEntityFromNetworkId(holdingObjectNetId)
        if DoesEntityExist(holdingObject) then
            SetEntityRoutingBucket(holdingObject, 0)
        end
    end

    -- Remove player tracking
    self.playersInside[playerId] = nil

    return true
end

---Check if player is inside
---@param playerId number Player server ID
---@return boolean
function InteriorManagerServer:isPlayerInside(playerId)
    return self.playersInside[playerId] ~= nil
end

---Get all players inside
---@return table<string, PlayerInsideData> Players inside
function InteriorManagerServer:getPlayersInside()
    return self.playersInside
end

---Teleport all players outside (cleanup)
function InteriorManagerServer:teleportAllOutside()
    for playerId, _ in pairs(self.playersInside) do
        self:teleportOutside(playerId)
    end
    self.playersInside = {}
end

return InteriorManagerServer
