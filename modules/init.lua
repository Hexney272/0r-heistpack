--[[ All helper functions and variables are defined here ]]

---@alias FrameworkType "esx"|"qb"|"qbx"

--Loads the ox_lib locale module
lib.locale(Config.locale)

shared = {
    resource = GetCurrentResourceName(),
    framework = nil,
}

--Checks if the given resource is started.
---@param resourceName string
---@return boolean
function shared.isResourceStart(resourceName)
    return GetResourceState(resourceName) == "started"
end

--Returns the name of the active framework ("qb", "esx", "qbx").
---@return FrameworkType|nil
function shared.getFrameworkName()
    if shared.isResourceStart("es_extended") then
        return "esx"
    elseif shared.isResourceStart("qbx_core") then
        return "qbx"
    elseif shared.isResourceStart("qb-core") then
        return "qb"
    end
    return nil
end

--Retrieves the core object of the active framework.
---@return table|nil
function shared.getFrameworkObject()
    local frameworkName = shared.getFrameworkName()
    if not frameworkName then return nil end
    if frameworkName == "esx" then
        return exports["es_extended"]:getSharedObject()
    elseif frameworkName == "qbx" then
        return exports["qb-core"]:GetCoreObject()
    elseif frameworkName == "qb" then
        return exports["qb-core"]:GetCoreObject()
    end
end

--Formats and returns a string combining the script name and event.
--Created for the convenience of the developer.
---@param event string
---@return string
function _e(event)
    return ("%s:%s"):format(shared.resource, event)
end

function shared.debug(title, ...)
    if not Config.debug then return end
    local date = IsDuplicityVersion() and os.date("%Y-%m-%d %H:%M:%S") or GetGameTimer()

    print(("[^2%s^7] [^3%s^7] ^5%s^7"):format(date, title, table.concat({ ... }, " ")))
    print(...)
end

shared.framework = shared.getFrameworkObject()
