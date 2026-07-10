--[[
    Framework Bridge Loader
    Loads the appropriate framework bridge based on shared.framework
]]

-- Bridge returns the Framework table populated with methods
---@class Bridge
---@field getPlayer fun(source:number):table|nil
---@field getPlayerIdentifier fun(source:number):string|nil
---@field getPlayerCharacterName fun(source:number):string|nil
---@field playerAddMoney fun(source:number, account:string, amount:number):boolean
---@field playerRemoveMoney fun(source:number, account:string, amount:number):boolean
---@field getPlayerBalance fun(source:number, account:string):number|nil
---@field getPlayerJob fun(source:number):table|nil
---@field createUseableItem fun(itemName:string, callback:function)
---@field isPlayerLoaded fun():boolean -- Client only
---@field hasPlayerGotGroup fun(groupName:string|string[]):boolean -- Client only
---@field getPlayerData fun():table -- Client only

local Framework = {}

local version = IsDuplicityVersion() and "server" or "client"
local frameworkPath = ("modules.framework.%s.%s"):format(shared.getFrameworkName(), version)

---@type boolean, Bridge
local success, bridge = pcall(require, frameworkPath)

if not success then
    lib.print.error(("Failed to load framework bridge: %s"):format(bridge))
    return Framework
end

return bridge
