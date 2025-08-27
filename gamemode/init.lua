-- Server-side initialization

-- Include shared files
include("shared.lua")

-- Include core module
include("core/init.lua")

-- Ensure client receives required files
if SERVER then
    AddCSLuaFile("shared.lua")
    AddCSLuaFile("cl_init.lua")
    AddCSLuaFile("core/init.lua")
    AddCSLuaFile("interface/cl_mainmenu.lua")
    AddCSLuaFile("core/timer/init.lua")
    AddCSLuaFile("core/timer/cl_timer.lua")
    AddCSLuaFile("core/timer/sv_timer.lua")
end

-- Forcefully enable realistic fall damage and friendly fire
if SERVER then
    -- Set the existing sandbox fall damage ConVar to enabled
    RunConsoleCommand("mp_falldamage", "1")
    print("[BM-DM] Realistic fall damage forcefully enabled")
    
    -- Enable friendly fire so players can damage each other
    RunConsoleCommand("mp_friendlyfire", "1")
    print("[BM-DM] Friendly fire enabled")
    
    -- Enable team damage (players can damage teammates too)
    RunConsoleCommand("mp_teammates_are_enemies", "1")
    print("[BM-DM] Team damage enabled")
    
    -- Disable godmode
    RunConsoleCommand("sv_cheats", "0")
    print("[BM-DM] Cheats disabled")

    -- Flashlight enablement is handled via PlayerSwitchFlashlight hook
end

-- Console commands to join teams
local function bm_dm_join_team(ply, cmd, args)
    local teamName = args[1]
    if not teamName then return end
    local targetTeam = nil
    if teamName == "lambda" then
        targetTeam = TEAM_LAMBDA
    elseif teamName == "hecu" then
        targetTeam = TEAM_HECU
    end
    if not targetTeam then return end

    ply:SetTeam(targetTeam)
    -- Force respawn to apply team changes
    ply:Spawn()
end

concommand.Add("bm_dm_join", bm_dm_join_team, nil, "Join a Black Mesa DM team: lambda|hecu")

-- Auto-assign team command
local function bm_dm_autoassign(ply, cmd, args)
    -- Get team player counts
    local lambdaCount = team.NumPlayers(TEAM_LAMBDA) or 0
    local hecuCount = team.NumPlayers(TEAM_HECU) or 0
    
    -- Determine which team to assign to
    local targetTeam = TEAM_LAMBDA -- default
    if lambdaCount > hecuCount then
        targetTeam = TEAM_HECU
    elseif hecuCount > lambdaCount then
        targetTeam = TEAM_LAMBDA
    else
        -- Equal counts or both zero - random assignment
        targetTeam = math.random() > 0.5 and TEAM_LAMBDA or TEAM_HECU
    end
    
    ply:SetTeam(targetTeam)
    ply:Spawn()
end

concommand.Add("bm_dm_autoassign", bm_dm_autoassign, nil, "Auto-assign to a team")

-- Spectate command
local function bm_dm_spectate(ply, cmd, args)
    ply:SetTeam(TEAM_SPECTATOR or 1001)
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SetMoveType(MOVETYPE_NOCLIP)
end

concommand.Add("bm_dm_spectate", bm_dm_spectate, nil, "Join spectator mode")

-- Basic spawn handling
function GM:PlayerInitialSpawn(ply)
    -- Default to spectator until they pick a team
    ply:SetTeam(TEAM_SPECTATOR or 1001)
    -- Don't spawn the player initially - they need to pick a team first
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SetMoveType(MOVETYPE_NOCLIP)
end

function GM:PlayerSpawn(ply)
    -- Check if player is dead and in spectator mode
    if BLACKMESA_CORE and BLACKMESA_CORE.Spectator and BLACKMESA_CORE.Spectator:IsPlayerDead(ply) then
        -- Player is dead, keep them in spectator mode
        ply:SetTeam(TEAM_SPECTATOR or 1001)
        ply:SetNoDraw(true)
        ply:SetRenderMode(RENDERMODE_TRANSALPHA)
        ply:SetColor(Color(255, 255, 255, 0))
        ply:SetMoveType(MOVETYPE_NOCLIP)
        ply:Spectate(OBS_MODE_ROAMING)
        ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        return
    end
    
    -- Only allow spawning if player is on a valid team
    if ply:Team() ~= TEAM_LAMBDA and ply:Team() ~= TEAM_HECU then
        -- Keep player in spectator mode until they pick a team
        ply:Spectate(OBS_MODE_ROAMING)
        ply:SetMoveType(MOVETYPE_NOCLIP)
        return
    end
    
    -- Player has a valid team, allow normal spawning
    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_WALK)
    
    -- Strip weapons but don't give any (players will find weapons in the map)
    ply:StripWeapons()
    
    -- Only give basic weapons if a round is active
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        local timer = BLACKMESA_CORE.Timer.Server
        if timer.State.IsRoundActive and not timer.State.IsIntermission then
            -- Give all players basic weapons only during active rounds
            ply:Give("weapon_bmbshift_crowbar_alt")
            ply:Give("weapon_bmbshift_glock")
        end
    end
    
    -- Set team-specific models
    if ply:Team() == TEAM_LAMBDA then
        ply:SetModel("models/motorhead/hevscientist.mdl")
    elseif ply:Team() == TEAM_HECU then
        ply:SetModel("models/player/bms_marine.mdl")
        
        -- Randomize HECU model skin and bodygroups
        local skinCount = ply:SkinCount()
        if skinCount > 0 then
            ply:SetSkin(math.random(0, skinCount - 1))
        end
        
        -- Randomize bodygroups based on the image showing available options
        -- Note: Bodygroup names may vary by model, so we'll use numeric IDs
        -- Exclude the last bodygroup (longjump) from randomization
        local bodygroupCount = ply:GetNumBodyGroups()
        if bodygroupCount > 1 then
            for i = 0, bodygroupCount - 2 do
                local submodelCount = ply:GetBodygroupCount(i)
                if submodelCount > 0 then
                    -- Randomly enable/disable bodygroup (0 = disabled, 1+ = enabled variants)
                    local randomValue = math.random(0, submodelCount)
                    ply:SetBodygroup(i, randomValue)
                end
            end
        end
    end
end

-- Initialize gamemode
function GM:Initialize()
    print("Black Mesa Deathmatch initialized")
end

-- Allow noclip per-player (default true for sandbox derived)
function GM:PlayerNoClip(ply, desiredState)
    return true
end

-- Allow spawn menu
function GM:PlayerSpawnProp(ply, model)
    return true
end

function GM:PlayerGiveSWEP(ply, class, swep)
    if ply:Team() ~= TEAM_LAMBDA and ply:Team() ~= TEAM_HECU then
        return false
    end
    return true
end

-- Called when the gamemode loads
function GM:InitPostEntity()
    print("Black Mesa Deathmatch post-entity initialization complete")
    
    -- Clean the map first
    if BLACKMESA_CORE and BLACKMESA_CORE.EntityCleaner then
        print("[BM-DM] Cleaning map on initialization...")
        BLACKMESA_CORE.EntityCleaner:CleanMap()
    end
    
    -- Start the entity spawner
    if BLACKMESA_CORE and BLACKMESA_CORE.EntitySpawner then
        BLACKMESA_CORE.EntitySpawner:Start()
        -- Spawn initial entities after a delay to avoid conflicts
        timer.Simple(3, function()
            if BLACKMESA_CORE and BLACKMESA_CORE.EntitySpawner then
                BLACKMESA_CORE.EntitySpawner:SpawnAllEntities()
            end
        end)
    end
end

-- Prevent spawning through spawn menu until team is selected
function GM:PlayerSpawnObject(ply, model, skin)
    if ply:Team() ~= TEAM_LAMBDA and ply:Team() ~= TEAM_HECU then
        return false
    end
    return true
end

-- Prevent weapon spawning until team is selected
function GM:PlayerSpawnSWEP(ply, class, swep)
    if ply:Team() ~= TEAM_LAMBDA and ply:Team() ~= TEAM_HECU then
        return false
    end
    return true
end

-- Prevent entity spawning until team is selected
function GM:PlayerSpawnSENT(ply, class)
    if ply:Team() ~= TEAM_LAMBDA and ply:Team() ~= TEAM_HECU then
        return false
    end
    return true
end

-- Block console kill command
hook.Add("PlayerCommand", "BlockKillConsoleCommand", function(ply, command)
    if IsValid(ply) and string.lower(command) == "kill" then
        return true
    end
end)

-- Universal suicide prevention
hook.Add("CanPlayerSuicide", "BlockSuicide", function()
    return false
end)

-- Allow respawn for dead players when timer expires
hook.Add("CanPlayerSuicide", "AllowSpectatorRespawn", function(ply)
    if BLACKMESA_CORE and BLACKMESA_CORE.Spectator and BLACKMESA_CORE.Spectator:IsPlayerDead(ply) then
        -- Allow the spectator system to handle respawn
        return false
    end
end)

-- Ensure realistic fall damage and friendly fire are always enabled
hook.Add("Think", "BM_DM_ForceFallDamage", function()
    if SERVER then
        -- Ensure the sandbox fall damage ConVar stays enabled
        if GetConVar("mp_falldamage"):GetInt() ~= 1 then
            RunConsoleCommand("mp_falldamage", "1")
        end
        
        -- Ensure friendly fire stays enabled
        if GetConVar("mp_friendlyfire"):GetInt() ~= 1 then
            RunConsoleCommand("mp_friendlyfire", "1")
        end
        
        -- Ensure team damage stays enabled
        if GetConVar("mp_teammates_are_enemies"):GetInt() ~= 1 then
            RunConsoleCommand("mp_teammates_are_enemies", "1")
        end
    end
end)

-- Allow/deny flashlight per-player
hook.Add("PlayerSwitchFlashlight", "BM_DM_Flashlight", function(ply, enabled)
    -- Block spectators (dead or not on a valid team) from using flashlight
    if BLACKMESA_CORE and BLACKMESA_CORE.Spectator and BLACKMESA_CORE.Spectator:IsPlayerDead(ply) then
        return false
    end
    if ply:Team() ~= TEAM_LAMBDA and ply:Team() ~= TEAM_HECU then
        return false
    end
    -- Allow for active players
    return true
end)
