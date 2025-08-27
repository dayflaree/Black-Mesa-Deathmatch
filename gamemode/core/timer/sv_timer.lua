-- Black Mesa Deathmatch - Server Timer
-- Handles round timing and round end events

if not SERVER then return end

BLACKMESA_CORE.Timer.Server = BLACKMESA_CORE.Timer.Server or {}
local ServerTimer = BLACKMESA_CORE.Timer.Server

-- Timer configuration
ServerTimer.Config = {
    RoundDuration = 600, -- 10 minutes in seconds
    IntermissionDuration = 60, -- 60 seconds between rounds
    RoundStartDelay = 5 -- 5 seconds to prepare for round start
}

-- Timer state
ServerTimer.State = {
    CurrentRound = 0,
    RoundStartTime = 0,
    RoundEndTime = 0,
    IntermissionStartTime = 0,
    IsIntermission = false,
    IsRoundActive = false
}

-- Network strings
util.AddNetworkString("BM_DM_Timer_Update")
util.AddNetworkString("BM_DM_Timer_RoundEnd")
util.AddNetworkString("BM_DM_Timer_RoundStart")
util.AddNetworkString("BM_DM_Timer_Intermission")
util.AddNetworkString("BM_DM_Timer_ShowMenu")
util.AddNetworkString("BM_DM_Timer_RequestState")
util.AddNetworkString("BM_DM_Timer_StateResponse")

-- Start a new round
function ServerTimer:StartRound()
    self.State.CurrentRound = self.State.CurrentRound + 1
    self.State.RoundStartTime = CurTime()
    self.State.RoundEndTime = CurTime() + self.Config.RoundDuration
    self.State.IsRoundActive = true
    self.State.IsIntermission = false
    
    -- Round started
    
    -- Notify all clients
    net.Start("BM_DM_Timer_RoundStart")
        net.WriteUInt(self.State.CurrentRound, 16)
        net.WriteFloat(self.State.RoundEndTime)
    net.Broadcast()
    
    -- Start the round timer
    self:StartRoundTimer()
    
    -- Call round start hook
    hook.Call("BM_DM_RoundStart")
    
    -- Give weapons to all players when round starts
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and (ply:Team() == TEAM_LAMBDA or ply:Team() == TEAM_HECU) then
            ply:Give("weapon_bmbshift_crowbar_alt")
            ply:Give("weapon_bmbshift_glock")
        end
    end
end

-- End the current round
function ServerTimer:EndRound()
    if not self.State.IsRoundActive then return end
    
    self.State.IsRoundActive = false
    self.State.IsIntermission = true
    self.State.IntermissionStartTime = CurTime()
    
    -- Round ended
    
    -- Force all players back to main menu
    self:ForcePlayersToMenu()
    
    -- Notify all clients
    net.Start("BM_DM_Timer_RoundEnd")
        net.WriteUInt(self.State.CurrentRound, 16)
    net.Broadcast()
    
    -- Start intermission timer
    self:StartIntermissionTimer()
    
    -- Respawn all players when intermission starts
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:Spawn()
        end
    end
    
    -- Call round end hook
    hook.Call("BM_DM_RoundEnd")
    
    -- Call intermission start hook
    hook.Call("BM_DM_IntermissionStart")
end

-- Force all players to the main menu
function ServerTimer:ForcePlayersToMenu()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            -- Just strip weapons and notify client
            ply:StripWeapons()
            
            -- Notify client to show main menu
            net.Start("BM_DM_Timer_ShowMenu")
            net.Send(ply)
        end
    end
    
    -- All players notified about main menu
end

-- Start the round timer
function ServerTimer:StartRoundTimer()
    -- Remove any existing round timer first
    timer.Remove("BM_DM_RoundTimer")
    
    local roundTime = self.Config.RoundDuration
    
    timer.Create("BM_DM_RoundTimer", 1, roundTime, function()
        if not self.State.IsRoundActive then return end
        
        local timeLeft = timer.RepsLeft("BM_DM_RoundTimer")
        
        if timeLeft <= 0 then
            self:EndRound()
            return
        end
        
        -- Send timer update to all clients
        net.Start("BM_DM_Timer_Update")
            net.WriteFloat(timeLeft)
            net.WriteBool(false) -- not intermission
        net.Broadcast()
    end)
end

-- Start the intermission timer
function ServerTimer:StartIntermissionTimer()
    -- Remove any existing intermission timer first
    timer.Remove("BM_DM_IntermissionTimer")
    
    local intermissionTime = self.Config.IntermissionDuration
    
    timer.Create("BM_DM_IntermissionTimer", 1, intermissionTime, function()
        if not self.State.IsIntermission then return end
        
        local timeLeft = timer.RepsLeft("BM_DM_IntermissionTimer")
        
        -- Send timer update to all clients first
        net.Start("BM_DM_Timer_Update")
            net.WriteFloat(timeLeft)
            net.WriteBool(true) -- is intermission
        net.Broadcast()
        
        if timeLeft <= 0 then
            -- Check if we still have enough players before starting round
            if self:HasEnoughPlayers() then
                self:StartRound()
            else
                -- Not enough players, stop intermission and wait
                self.State.IsIntermission = false
                timer.Remove("BM_DM_IntermissionTimer")
            end
            return
        end
    end)
end

-- Check if there are enough players to start a round
function ServerTimer:HasEnoughPlayers()
    local lambdaPlayers = 0
    local hecuPlayers = 0
    
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Team() == TEAM_LAMBDA then
            lambdaPlayers = lambdaPlayers + 1
        elseif IsValid(ply) and ply:Team() == TEAM_HECU then
            hecuPlayers = hecuPlayers + 1
        end
    end
    
    -- Need at least 1 player in each team
    return lambdaPlayers >= 1 and hecuPlayers >= 1
end

-- Initialize server timer
function ServerTimer:Initialize()
    -- Don't start timer until there are enough players
    self.State.IsIntermission = false
    self.State.IsRoundActive = false
    
    -- Check for players every 5 seconds
    timer.Create("BM_DM_PlayerCheck", 5, 0, function()
        if self:HasEnoughPlayers() and not self.State.IsIntermission and not self.State.IsRoundActive then
            -- Start intermission timer when we have enough players
            self.State.IsIntermission = true
            self.State.IntermissionStartTime = CurTime()
            self:StartIntermissionTimer()
            
            -- Respawn all players when intermission starts
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) then
                    ply:Spawn()
                end
            end
            
            -- Call intermission start hook
            hook.Call("BM_DM_IntermissionStart")
        elseif not self:HasEnoughPlayers() and (self.State.IsIntermission or self.State.IsRoundActive) then
            -- Stop timer if not enough players
            timer.Remove("BM_DM_RoundTimer")
            timer.Remove("BM_DM_IntermissionTimer")
            self.State.IsIntermission = false
            self.State.IsRoundActive = false
        end
    end)
end

-- Console commands
concommand.Add("bm_dm_timer_force_end", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        print("[BM-DM] Admin only command")
        return
    end
    
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        BLACKMESA_CORE.Timer.Server:EndRound()
    end
end, nil, "Force end current round (Admin only)")

concommand.Add("bm_dm_timer_force_start", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        print("[BM-DM] Admin only command")
        return
    end
    
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        timer.Remove("BM_DM_RoundTimer")
        timer.Remove("BM_DM_IntermissionTimer")
        BLACKMESA_CORE.Timer.Server:StartRound()
    end
end, nil, "Force start new round (Admin only)")



-- Network receiver for timer state request
net.Receive("BM_DM_Timer_RequestState", function(len, ply)
    if not IsValid(ply) then return end
    
    local timer = BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server
    if not timer then return end
    
    -- Send current timer state to client
    net.Start("BM_DM_Timer_StateResponse")
        net.WriteFloat(timer.State.RoundEndTime)
        net.WriteFloat(timer.State.IntermissionStartTime)
        net.WriteBool(timer.State.IsIntermission)
        net.WriteBool(timer.State.IsRoundActive)
        net.WriteUInt(timer.State.CurrentRound, 16)
    net.Send(ply)
    
    print("[BM-DM] Sent timer state to " .. ply:Nick())
end)

-- Hook into player spawn to ensure they're in spectator during intermission
hook.Add("PlayerSpawn", "BM_DM_Timer_SpawnCheck", function(ply)
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        local timer = BLACKMESA_CORE.Timer.Server
        if timer.State.IsIntermission then
            -- Just strip weapons during intermission, don't force spectator
            ply:StripWeapons()
        end
    end
end)
