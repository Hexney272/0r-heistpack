--[[ Type Definitions ]]
---@class Profile
---@field identifier string
---@field illegalNickname string|nil
---@field photo integer
---@field exp integer
---@field created_at string
---@field updated_at string

-- Optimized Query table with constants and prepared statements
local Query = {
    SELECT_PROFILES = "SELECT * FROM `0resmon_heist_profiles`",
    UPDATE_PROFILE = "UPDATE `0resmon_heist_profiles` SET exp = ?, illegal_nickname = ? WHERE identifier = ?",
    INSERT_PROFILE = "INSERT IGNORE INTO `0resmon_heist_profiles` (identifier, illegal_nickname) VALUES (?, ?)",
    UPDATE_PROFILE_ILLEGAL_NICKNAME = "UPDATE `0resmon_heist_profiles` SET illegal_nickname = ? WHERE identifier = ?",
    UPDATE_PROFILE_PHOTO = "UPDATE `0resmon_heist_profiles` SET photo = ? WHERE identifier = ?",
}

-- Checking the existence of the database table, if it does not exist, it is created
Citizen.CreateThreadNow(function()
    Citizen.Wait(1)

    local success, result = pcall(MySQL.scalar.await, "SELECT 1 FROM 0resmon_heist_profiles")

    if not success then
        MySQL.query([[CREATE TABLE `0resmon_heist_profiles` (
			`id` INT AUTO_INCREMENT PRIMARY KEY,
			`identifier` varchar(255) NOT NULL UNIQUE,
            `illegal_nickname` VARCHAR(255) DEFAULT NULL,
            `photo` INT DEFAULT 1,
            `exp` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		)]])
        lib.print.info("Database Table `0resmon_heist_profiles` created !")
    end
end)

-- Database module
local db = {}

function db.loadProfiles()
    return MySQL.query.await(Query.SELECT_PROFILES)
end

---@param identifier string
---@param data Profile
function db.updateProfile(identifier, data)
    return MySQL.prepare(Query.UPDATE_PROFILE, { data.exp, data.illegalNickname, identifier })
end

---@param identifier string
---@param illegalNickname string
function db.updateProfileIllegalNickname(identifier, illegalNickname)
    return MySQL.prepare(Query.UPDATE_PROFILE_ILLEGAL_NICKNAME, { illegalNickname, identifier })
end

---@param identifier string
---@param photo integer
function db.updateProfilePhoto(identifier, photo)
    return MySQL.prepare(Query.UPDATE_PROFILE_PHOTO, { photo, identifier })
end

---@param identifier string
---@param illegalNickname string
function db.createPlayer(identifier, illegalNickname)
    return MySQL.insert(Query.INSERT_PROFILE, { identifier, illegalNickname })
end

return db
