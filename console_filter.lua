--[[
    Console Spam Filter - Suppress 0r_lib license check messages
    This file MUST load BEFORE any other client scripts!
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
       (msg:find("license") and msg:find("bypass")) then
        return true
    end
    
    return false
end

-- Override print()
local originalPrint = print
function print(...)
    local args = {...}
    local msg = table.concat(args, " ")
    if not shouldFilterMessage(msg) then
        originalPrint(...)
    end
end

-- Override Citizen.Trace (FiveM native logging)
local originalTrace = Citizen.Trace
function Citizen.Trace(msg)
    if not shouldFilterMessage(msg) then
        originalTrace(msg)
    end
end

-- Override console logging (F8 console)
if Citizen.InvokeNative then
    local originalInvokeNative = Citizen.InvokeNative
    Citizen.InvokeNative = function(hash, ...)
        -- 0x8F18ADC93041A1E8 is the hash for console logging
        if hash == 0x8F18ADC93041A1E8 then
            local msg = ...
            if shouldFilterMessage(msg) then
                return -- Block the log
            end
        end
        return originalInvokeNative(hash, ...)
    end
end

-- Hook global trace
if _G.trace then
    local originalGlobalTrace = _G.trace
    _G.trace = function(msg)
        if not shouldFilterMessage(msg) then
            originalGlobalTrace(msg)
        end
    end
end

print("^2[Console Filter] License spam filter loaded successfully^0")
