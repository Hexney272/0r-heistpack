--[[
    Server Console Spam Filter - Suppress 0r_lib license check messages
    This file MUST load BEFORE any other server scripts!
]]

local function shouldFilterMessage(msg)
    if type(msg) ~= "string" then
        msg = tostring(msg)
    end
    
    -- Filter out license spam messages
    if msg:find("License check intercepted") or 
       msg:find("Sending license override") or
       msg:find("0r%-heistpack.*License") or
       msg:find("0r%-heistpack.*bypass") or
       msg:find("license.*override.*UI") or
       (msg:find("license") and msg:find("bypass")) then
        return true
    end
    
    return false
end

-- Override print()
local originalPrint = print
function print(...)
    local args = {...}
    local success, msg = pcall(function()
        return table.concat(args, " ")
    end)
    
    if success and not shouldFilterMessage(msg) then
        originalPrint(...)
    elseif not success then
        originalPrint(...)
    end
end

-- Override Citizen.Trace (FiveM native logging)
if Citizen and Citizen.Trace then
    local originalTrace = Citizen.Trace
    function Citizen.Trace(msg)
        if not shouldFilterMessage(tostring(msg)) then
            originalTrace(msg)
        end
    end
end

-- Hook global trace
if _G.trace then
    local originalGlobalTrace = _G.trace
    _G.trace = function(msg)
        if not shouldFilterMessage(tostring(msg)) then
            originalGlobalTrace(msg)
        end
    end
end

print("^2[Server Console Filter] License spam filter loaded successfully^0")
