-- Black Mesa Deathmatch - Timer System
-- Round timer with 10-minute rounds and 60-second intermissions

BLACKMESA_CORE.Timer = BLACKMESA_CORE.Timer or {}
local Timer = BLACKMESA_CORE.Timer

-- Include timer modules
if SERVER then
    AddCSLuaFile("timer/init.lua")
    AddCSLuaFile("timer/cl_timer.lua")
    include("sv_timer.lua")
end

-- Always include client timer (will be ignored on server due to CLIENT check)
include("cl_timer.lua")

-- Initialize timer system
function Timer:Initialize()
    if SERVER then
        -- Initialize server-side timer
        if Timer.Server then
            Timer.Server:Initialize()
        end
    end
    
    if CLIENT then
        -- Initialize client-side timer
        if Timer.Client then
            Timer.Client:Initialize()
        end
    end
end

-- Call initialization
Timer:Initialize()
