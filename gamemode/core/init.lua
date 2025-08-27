-- Black Mesa Deathmatch - Core Module
-- Core functionality and utilities for the gamemode

-- Core namespace
BLACKMESA_CORE = BLACKMESA_CORE or {}

-- Include core modules (server-only)
if SERVER then
    AddCSLuaFile("entityspawner.lua")
    AddCSLuaFile("teamscore.lua")
    include("entityspawner.lua")
    include("entitycleaner.lua")
    include("spectator.lua")
    include("timer/init.lua")
    include("commands.lua")
    include("teamscore.lua")
end

-- Include team score for client
if CLIENT then
    include("teamscore.lua")
end

-- Include timer for client
if CLIENT then
    include("timer/init.lua")
end

-- Initialize core module
function BLACKMESA_CORE:Initialize()
    print("Black Mesa Deathmatch core module initialized")
    
    -- Initialize entity spawner
    if BLACKMESA_CORE.EntitySpawner then
        BLACKMESA_CORE.EntitySpawner:Initialize()
    end
    
    -- Initialize spectator system
    if BLACKMESA_CORE.Spectator then
        BLACKMESA_CORE.Spectator:Initialize()
    end
end

-- Call initialization
BLACKMESA_CORE:Initialize()
