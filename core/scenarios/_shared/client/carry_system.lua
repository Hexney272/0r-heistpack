local lib                 = lib
local Utils               = require("modules.utils.client")
local Inventory           = require("modules.inventory.client")

---@class CarrySystemOptions
---@field animationDict? string Animation dictionary
---@field animationName? string Animation name
---@field animationFlags? number Animation flags (default: 50)

---@class CarrySystemClient
---@field animationDict string Animation dictionary
---@field animationName string Animation name
---@field animationFlags number Animation flags
---@field holdingObject number|nil Currently held object entity
---@field holdingObjectNetId number|nil Network ID of held object
---@field holdingData table Additional data about held object
local CarrySystemClient   = {}
CarrySystemClient.__index = CarrySystemClient

---Create new carry system instance
---@param options? CarrySystemOptions
---@return CarrySystemClient
function CarrySystemClient.new(options)
    local self = setmetatable({}, CarrySystemClient)

    options = options or {}
    self.animationDict = options.animationDict or "anim@heists@box_carry@"
    self.animationName = options.animationName or "idle"
    self.animationFlags = options.animationFlags or 50

    self.holdingObject = nil
    self.holdingObjectNetId = nil
    self.holdingData = {}

    return self
end

---Attach object to player
---@param objectModel string|number Object model hash or name
---@param coords vector3 Spawn coordinates
---@param attachConfig table Attach configuration {offset, rotation, boneId}
---@return number|nil objectNetId Network ID of created object
function CarrySystemClient:attachObject(objectModel, coords, attachConfig)
    if self.holdingObject then
        self:detachObject()
    end

    Inventory.disarm()

    lib.requestModel(objectModel)

    local object = Utils.createObject({
        model = objectModel,
        coords = coords,
        rotation = 0.0,
        freeze = false,
        isNetwork = true,
    })
    if not object then
        return nil
    end

    if not DoesEntityExist(object) then
        return nil
    end

    -- Get network ID
    local objectNetId = lib.waitFor(function()
        if not NetworkGetEntityIsNetworked(object) then
            NetworkRegisterEntityAsNetworked(object)
        else
            local netId = ObjToNet(object)
            if NetworkDoesNetworkIdExist(netId) then
                return netId
            end
        end
    end, nil, false)

    -- Attach to player
    local offset = attachConfig.offset or vector3(0.0, 0.0, 0.0)
    local rotation = attachConfig.rotation or vector3(0.0, 0.0, 0.0)
    local boneId = attachConfig.boneId or 28422

    AttachEntityToEntity(
        object,
        cache.ped,
        GetPedBoneIndex(cache.ped, boneId),
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )

    -- Play animation
    if self.animationDict and self.animationName then
        lib.requestAnimDict(self.animationDict)
        lib.playAnim(cache.ped, self.animationDict, self.animationName, 8.0, -8.0, -1, self.animationFlags)
    end

    self.holdingObject = object
    self.holdingObjectNetId = objectNetId
    self.holdingData = attachConfig

    return objectNetId
end

---Detach and delete object
function CarrySystemClient:detachObject()
    if not self.holdingObject then return end

    if DoesEntityExist(self.holdingObject) then
        DetachEntity(self.holdingObject, true, true)
        DeleteEntity(self.holdingObject)
    end

    ClearPedTasks(cache.ped)

    self.holdingObject = nil
    self.holdingObjectNetId = nil
    self.holdingData = {}
end

---Check if player is holding an object
---@return boolean
function CarrySystemClient:isHolding()
    return self.holdingObject ~= nil and DoesEntityExist(self.holdingObject)
end

---Get holding object
---@return number|nil object Entity handle
function CarrySystemClient:getHoldingObject()
    return self.holdingObject
end

---Get holding object network ID
---@return number|nil objectNetId
function CarrySystemClient:getHoldingObjectNetId()
    return self.holdingObjectNetId
end

---Get holding data
---@return table data
function CarrySystemClient:getHoldingData()
    return self.holdingData
end

---Set holding data
---@param data table
function CarrySystemClient:setHoldingData(data)
    self.holdingData = data
end

---Replay carrying animation (useful after teleport)
function CarrySystemClient:replayAnimation()
    if not self:isHolding() then return end

    Citizen.Wait(500)

    if self.animationDict and self.animationName then
        lib.requestAnimDict(self.animationDict)
        lib.playAnim(cache.ped, self.animationDict, self.animationName, 8.0, -8.0, -1, self.animationFlags)
    end
end

---Clear carry system
function CarrySystemClient:clear()
    self:detachObject()
end

return CarrySystemClient
