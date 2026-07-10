--[[
    ProfileServer - Modern OOP-based Profile Management System

    @author 0resmon
    @version 2.0.0
]]

local lib = lib

--[[ Dependencies ]]
local db        = require "modules.mysql.server"
local Framework = require "modules.framework.init"

--[[ Private State ]]
local _playerProfiles = {} -- Internal cache

--[[ Type Definitions ]]
---@class ProfileData
---@field identifier string Player unique identifier
---@field name string Player character name
---@field illegalNickname string Player illegal nickname
---@field level number Current level
---@field exp number Current experience points
---@field nextLevelExp number Experience required for next level
---@field photo number Profile photo ID
---@field source number? Player server source (optional, set when online)

---@class ProfileServer
---@field private _initialized boolean
---@field private _config table
local ProfileServerClass = {}
ProfileServerClass.__index = ProfileServerClass

--[[ Private Helper Functions ]]

---Calculate level based on experience points
---@param userExp number
---@return number level
local function calculateLevel(userExp)
    if not userExp or userExp < 0 then return 1 end

    local lastLevel = 1
    for lvl, reqExp in pairs(Config.levels) do
        if userExp < reqExp then
            return math.max(1, lvl - 1)
        end
        lastLevel = math.max(lastLevel, lvl)
    end
    return lastLevel
end

---Get experience required for next level
---@param userExp number
---@return number nextLevelExp
local function calculateNextLevelExp(userExp)
    local nextExp
    local maxExp = 0

    for _, reqExp in pairs(Config.levels) do
        if userExp < reqExp and (not nextExp or reqExp < nextExp) then
            nextExp = reqExp
        end
        maxExp = math.max(maxExp, reqExp)
    end

    return nextExp or maxExp
end

---Validate identifier format
---@param identifier string
---@return boolean isValid
---@return string? errorMessage
local function validateIdentifier(identifier)
    if not identifier or type(identifier) ~= "string" or identifier == "" then
        return false, "Invalid identifier: must be a non-empty string"
    end
    return true, nil
end

---Validate experience value
---@param exp number
---@return boolean isValid
---@return string? errorMessage
local function validateExp(exp)
    if not exp or type(exp) ~= "number" or exp < 0 then
        return false, "Invalid experience: must be a positive number"
    end
    return true, nil
end

--[[ Constructor ]]

---Create new ProfileServer instance
---@param config table? Optional configuration
---@return ProfileServer
function ProfileServerClass.new(config)
    local self = setmetatable({}, ProfileServerClass)
    self._initialized = false
    self._config = config or {
        debugMode = Config.debug or false
    }
    return self
end

--[[ Public Methods ]]

---Initialize the profile service and load all profiles from database
---@return boolean success
---@return string? errorMessage
function ProfileServerClass:initialize()
    if self._initialized then
        return false, "ProfileServer already initialized"
    end

    self:_registerCallbacks()
    self:_registerNetEvents()

    local success, profiles = pcall(db.loadProfiles)
    if not success then
        return false, ("Failed to load profiles from database: %s"):format(profiles)
    end

    -- Process and cache all profiles
    for _, profile in pairs(profiles) do
        profile.level = calculateLevel(profile.exp)
        profile.nextLevelExp = calculateNextLevelExp(profile.exp)
        profile.illegalNickname = profile.illegal_nickname or profile.name
        _playerProfiles[profile.identifier] = profile
    end

    self._initialized = true

    if self._config.debugMode then
        lib.print.info(("ProfileServer initialized with %d profiles"):format(#profiles))
    end

    return true, nil
end

---Get profile by identifier
---@param identifier string
---@return ProfileData? profile
---@return string? errorMessage
function ProfileServerClass:getByIdentifier(identifier)
    local isValid, errMsg = validateIdentifier(identifier)
    if not isValid then
        return nil, errMsg
    end

    return _playerProfiles[identifier], nil
end

---Get profile by player source
---@param source number
---@return ProfileData? profile
---@return string? errorMessage
function ProfileServerClass:getBySource(source)
    if not source or type(source) ~= "number" or source <= 0 then
        return nil, "Invalid source: must be a positive number"
    end

    local identifier = Framework.getPlayerIdentifier(source)
    if not identifier then
        return nil, "Failed to get player identifier"
    end

    return self:getByIdentifier(identifier)
end

---Create a new profile for a player
---@param source number
---@return ProfileData? profile
---@return string? errorMessage
function ProfileServerClass:create(source)
    local identifier = Framework.getPlayerIdentifier(source)
    if not identifier then return nil, "Failed to get player identifier" end

    local isValid, errMsg = validateIdentifier(identifier)
    if not isValid then
        return nil, errMsg
    end

    -- Check if profile already exists
    if _playerProfiles[identifier] then
        return nil, ("Profile for %s already exists"):format(identifier)
    end

    local name = Framework.getPlayerCharacterName(source)
    if not name then
        return nil, "Failed to get player character name"
    end

    ---@type ProfileData
    local profile = {
        identifier = identifier,
        level = 1,
        exp = 0,
        nextLevelExp = calculateNextLevelExp(0),
        name = name,
        illegalNickname = name,
        source = source,
        photo = 1
    }

    -- Save to database
    local success, dbErr = pcall(db.createPlayer, identifier, name)
    if not success then
        return nil, ("Database error: %s"):format(dbErr)
    end

    -- Cache the profile
    _playerProfiles[identifier] = profile

    if self._config.debugMode then
        lib.print.info(("Profile created for %s (%s)"):format(name, identifier))
    end

    return profile, nil
end

---Give experience points to a player
---@param identifierOrSource string|number
---@param exp number
---@return number? newExp
---@return string? errorMessage
---@return boolean? leveledUp
function ProfileServerClass:giveExp(identifierOrSource, exp)
    -- Validate experience
    local isValid, errMsg = validateExp(exp)
    if not isValid then
        return nil, errMsg, false
    end

    -- Get profile
    local profile, getErr
    if type(identifierOrSource) == "number" then
        profile, getErr = self:getBySource(identifierOrSource)
    else
        profile, getErr = self:getByIdentifier(identifierOrSource)
    end

    if not profile then
        return nil, getErr or "Profile not found", false
    end

    -- Store old level for comparison
    local oldLevel = profile.level

    -- Update experience
    profile.exp = profile.exp + exp
    profile.level = calculateLevel(profile.exp)
    profile.nextLevelExp = calculateNextLevelExp(profile.exp)

    -- Check if player leveled up
    local leveledUp = profile.level > oldLevel

    -- Auto-save if enabled
    if profile.source then
        self:update(profile.source)
    end

    if self._config.debugMode then
        lib.print.info(("Gave %d exp to %s (Total: %d, Level: %d)"):format(
            exp, profile.name, profile.exp, profile.level
        ))
    end

    return profile.exp, nil, leveledUp
end

---Get player level
---@param identifierOrSource string|number
---@return number? level
---@return string? errorMessage
function ProfileServerClass:getLevel(identifierOrSource)
    local profile, err
    if type(identifierOrSource) == "number" then
        profile, err = self:getBySource(identifierOrSource)
    else
        profile, err = self:getByIdentifier(identifierOrSource)
    end

    if not profile then
        return nil, err or "Profile not found"
    end

    return profile.level, nil
end

---Update profile data and sync to database
---@param source number
---@return boolean success
---@return string? errorMessage
function ProfileServerClass:update(source)
    local identifier = Framework.getPlayerIdentifier(source)
    local profile = _playerProfiles[identifier]

    if not profile then
        return false, "Profile not found"
    end

    -- Update source
    profile.source = source

    -- Trigger client update
    TriggerClientEvent(_e("client:profile:onUpdate"), source, profile)

    -- Save to database
    local success, dbErr = pcall(db.updateProfile, identifier, profile)
    if not success then
        return false, ("Database error: %s"):format(dbErr)
    end

    return true, nil
end

---Update player's illegal nickname
---@param source number
---@param newNickname string
---@return boolean success
---@return ProfileData? profile
---@return string? errorMessage
function ProfileServerClass:updateIllegalNickname(source, newNickname)
    if not newNickname or type(newNickname) ~= "string" or newNickname == "" then
        return false, nil, "Invalid nickname: must be a non-empty string"
    end

    local identifier = Framework.getPlayerIdentifier(source)
    local profile = _playerProfiles[identifier]

    if not profile then
        return false, nil, "Profile not found"
    end

    profile.illegalNickname = newNickname

    -- Save to database
    local success, dbErr = pcall(db.updateProfileIllegalNickname, identifier, newNickname)
    if not success then
        return false, nil, ("Database error: %s"):format(dbErr)
    end

    return true, profile, nil
end

---Update player's profile photo
---@param source number
---@param newPhoto number
---@return boolean success
---@return ProfileData? profile
---@return string? errorMessage
function ProfileServerClass:updatePhoto(source, newPhoto)
    if not newPhoto or type(newPhoto) ~= "number" or newPhoto < 1 then
        return false, nil, "Invalid photo ID: must be a positive number"
    end

    local identifier = Framework.getPlayerIdentifier(source)
    local profile = _playerProfiles[identifier]

    if not profile then
        return false, nil, "Profile not found"
    end

    profile.photo = newPhoto

    -- Save to database
    local success, dbErr = pcall(db.updateProfilePhoto, identifier, newPhoto)
    if not success then
        return false, nil, ("Database error: %s"):format(dbErr)
    end

    return true, profile, nil
end

---Register callbacks
---@private
function ProfileServerClass:_registerCallbacks()
    lib.callback.register(_e("server:profile:get"), function(source)
        if not ServerApplication.load then
            while not ServerApplication.load do Citizen.Wait(500) end
        end

        local profile, err = self:getBySource(source)

        if not profile then
            profile, err = self:create(source)
            if err then
                lib.print.error(("Failed to create profile: %s"):format(err))
                return nil
            end
        else
            -- Update name and source
            profile.name = profile.name or Framework.getPlayerCharacterName(source)
            profile.source = source
        end

        return profile
    end)

    lib.callback.register(_e("server:profile:updateIllegalNickName"), function(source, newNick)
        local success, profile, err = self:updateIllegalNickname(source, newNick)

        if not success then
            lib.print.error(("Failed to update illegal nickname: %s"):format(err))
            return { success = false, error = err }
        end

        return { success = true, profile = profile }
    end)

    lib.callback.register(_e("server:profile:updatePhoto"), function(source, newPhoto)
        local success, profile, err = self:updatePhoto(source, newPhoto)

        if not success then
            lib.print.error(("Failed to update photo: %s"):format(err))
            return { success = false, error = err }
        end

        return { success = true, profile = profile }
    end)
end

---Register Net Events
---@private
function ProfileServerClass:_registerNetEvents()
    RegisterNetEvent(_e("server:profile:onProfilePhotoChanged"), function(lobbyId, newPhoto)
        local src = source
        local lobby = LobbyServer:getLobbyById(lobbyId)
        if not lobby then return end

        for _, member in pairs(lobby.members) do
            if member.source == src then
                member.photo = newPhoto
            end
        end

        LobbyServer:notifyMembers(lobbyId)
    end)

    RegisterNetEvent(_e("server:profile:onProfileIllegalNicknameChanged"), function(lobbyId, newNickName)
        local src = source
        local lobby = LobbyServer:getLobbyById(lobbyId)
        if not lobby then return end

        for _, member in pairs(lobby.members) do
            if member.source == src then
                member.illegalNickname = newNickName
            end
        end

        LobbyServer:notifyMembers(lobbyId)
    end)
end

--[[ Initialize Global Instance ]]

ProfileServer = ProfileServerClass.new()
