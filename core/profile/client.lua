--[[
    ProfileClient - Modern Client-Side Profile Management

    @author 0resmon
    @version 2.0.0
]]

local lib = lib

--[[ Type Definitions ]]
---@class ClientProfile
---@field level number Current player level
---@field exp number Current experience points
---@field nextLevelExp number Experience required for next level
---@field name string Player character name
---@field illegalNickname string Player illegal nickname
---@field source number Player server source
---@field photo number Profile photo ID

---@class ProfileClient
---@field private _profile ClientProfile
local ProfileClientClass = {}
ProfileClientClass.__index = ProfileClientClass

--[[ Constants ]]

local MIN_NICKNAME_LENGTH = 3
local MAX_NICKNAME_LENGTH = 24

--[[ Private Helper Functions ]]

---Validate nickname length and format
---@param nickname string
---@return boolean isValid
---@return string? errorMessage
local function validateNickname(nickname)
    if not nickname or type(nickname) ~= "string" then
        return false, "Nickname must be a string"
    end

    local length = #nickname
    if length < MIN_NICKNAME_LENGTH then
        return false, locale("illegal_nickname_invalid")
    end

    if length > MAX_NICKNAME_LENGTH then
        return false, locale("illegal_nickname_invalid")
    end

    return true, nil
end

---Validate photo ID
---@param photoId number
---@return boolean isValid
local function validatePhotoId(photoId)
    return type(photoId) == "number" and photoId > 0
end

--[[ Constructor ]]

---Create new ProfileClientClass instance
---@return ProfileClient
function ProfileClientClass.new()
    local self = setmetatable({}, ProfileClientClass)

    ---@type ClientProfile
    self._profile = {
        level = 0,
        exp = 0,
        nextLevelExp = 0,
        name = nil,
        illegalNickname = nil,
        source = -1,
        photo = 1,
    }

    return self
end

--[[ Public Methods ]]

---Get current profile data
---@return ClientProfile
function ProfileClientClass:get()
    return self._profile
end

---Fetch profile from server
---@return ClientProfile? profile
---@return boolean success
function ProfileClientClass:fetch()
    local response = lib.callback.await(_e("server:profile:get"), false)

    if not response then
        return nil, false
    end

    self._profile = response
    return self._profile, true
end

---Update profile data locally
---@param newData table Partial profile data to update
function ProfileClientClass:update(newData)
    if not newData then return end

    -- Update only provided fields
    for key, value in pairs(newData) do
        if self._profile[key] ~= nil then
            self._profile[key] = value
        end
    end

    -- Sync to UI
    self:syncToUI()
end

---Send profile data to UI
function ProfileClientClass:syncToUI()
    ClientApplication:sendReactMessage("ui:setUserProfile", self._profile)
end

---Update illegal nickname
---@param newNickname string
---@return boolean success
---@return string? errorMessage
function ProfileClientClass:updateIllegalNickname(newNickname)
    -- Validate nickname
    local isValid, errMsg = validateNickname(newNickname)
    if not isValid then
        ClientApplication:sendReactAlert(errMsg, "error")
        return false, errMsg
    end

    -- Send to server
    local response = lib.callback.await(_e("server:profile:updateIllegalNickName"), false, newNickname)

    if not response or not response.success then
        local errorMsg = response and response.error or "Failed to update nickname"
        ClientApplication:sendReactAlert(errorMsg, "error")
        return false, errorMsg
    end

    -- Update local profile
    self._profile.illegalNickname = newNickname

    -- Sync to UI
    if response.profile then
        self._profile = response.profile
        self:syncToUI()
    end

    -- Notify lobby if in one
    if ClientApplication.state.lobby and ClientApplication.state.lobby.id then
        TriggerServerEvent(_e("server:profile:onProfileIllegalNicknameChanged"), ClientApplication.state.lobby.id,
            newNickname)
    end

    return true, nil
end

---Update profile photo
---@param newPhotoId number
---@return boolean success
---@return string? errorMessage
function ProfileClientClass:updatePhoto(newPhotoId)
    -- Validate photo ID
    if not validatePhotoId(newPhotoId) then
        local errorMsg = "Invalid photo ID"
        ClientApplication:sendReactAlert(errorMsg, "error")
        return false, errorMsg
    end

    -- Send to server
    local response = lib.callback.await(_e("server:profile:updatePhoto"), false, newPhotoId)

    if not response or not response.success then
        local errorMsg = response and response.error or "Failed to update photo"
        ClientApplication:sendReactAlert(errorMsg, "error")
        return false, errorMsg
    end

    -- Update local profile
    self._profile.photo = newPhotoId

    -- Sync to UI
    if response.profile then
        self._profile = response.profile
        self:syncToUI()
    end

    -- Notify lobby if in one
    if ClientApplication.state.lobby and ClientApplication.state.lobby.id then
        TriggerServerEvent(_e("server:profile:onProfilePhotoChanged"), ClientApplication.state.lobby.id, newPhotoId)
    end

    return true, nil
end

---Reset profile to default values (for cleanup)
function ProfileClientClass:reset()
    self._profile = {
        level = 0,
        exp = 0,
        nextLevelExp = 0,
        name = nil,
        illegalNickname = nil,
        source = -1,
        photo = 1,
    }
end

---Register NUI Callbacks
---@private
function ProfileClientClass:_registerNUICallbacks()
    -- Handle nickname update from UI
    RegisterNUICallback("nui:profile:updateIllegalNickName", function(newNickname, resultCallback)
        local newNickname = tostring(newNickname)
        local success = self:updateIllegalNickname(newNickname)
        resultCallback(success)
    end)
    -- Handle photo update from UI
    RegisterNUICallback("nui:profile:updatePhoto", function(newPhotoId, resultCallback)
        local success = self:updatePhoto(newPhotoId)
        resultCallback(success)
    end)
end

---Register Net Events
---@private
function ProfileClientClass:_registerNetEvents()
    -- Handle profile updates from server
    RegisterNetEvent(_e("client:profile:onUpdate"), function(newProfile)
        if not newProfile then return end

        -- Update specific fields
        self:update({
            exp = newProfile.exp,
            level = newProfile.level,
            nextLevelExp = newProfile.nextLevelExp
        })
    end)
end

function ProfileClientClass:initialize()
    self:_registerNetEvents()
    self:_registerNUICallbacks()
end

--[[ Initialize Global Instance ]]

ProfileClient = ProfileClientClass.new()
ProfileClient:initialize()