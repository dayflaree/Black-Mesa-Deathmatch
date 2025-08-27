-- Black Mesa Deathmatch - Team Score System
-- Tracks team kills and displays score under timer

BLACKMESA_CORE.TeamScore = BLACKMESA_CORE.TeamScore or {}
local TeamScore = BLACKMESA_CORE.TeamScore

-- Score configuration
TeamScore.Config = {
    MaxScore = 100, -- Maximum score a team can reach
    ScoreDisplayFormat = "TIED | %d - %d" -- Format for tied scores
}

-- Score state
TeamScore.State = {
    LambdaScore = 0,
    HECUScore = 0,
    LastKiller = nil,
    LastVictim = nil
}

-- Network strings
if SERVER then
    util.AddNetworkString("BM_DM_Score_Update")
    util.AddNetworkString("BM_DM_Score_Reset")
end

-- Get the current score display text
function TeamScore:GetScoreText()
    local lambdaScore = self.State.LambdaScore
    local hecuScore = self.State.HECUScore
    
    if lambdaScore == hecuScore then
        return string.format(self.Config.ScoreDisplayFormat, lambdaScore, hecuScore)
    elseif lambdaScore > hecuScore then
        return string.format("LAMBDA | %d - %d", lambdaScore, hecuScore)
    else
        return string.format("HECU | %d - %d", lambdaScore, hecuScore)
    end
end

-- Check if a team has won
function TeamScore:CheckWinCondition()
    if self.State.LambdaScore >= self.Config.MaxScore then
        return TEAM_LAMBDA
    elseif self.State.HECUScore >= self.Config.MaxScore then
        return TEAM_HECU
    end
    return nil
end

-- Award a kill to a team
function TeamScore:AwardKill(team)
    if team == TEAM_LAMBDA then
        self.State.LambdaScore = math.min(self.State.LambdaScore + 1, self.Config.MaxScore)
    elseif team == TEAM_HECU then
        self.State.HECUScore = math.min(self.State.HECUScore + 1, self.Config.MaxScore)
    end
    
    -- Send score update to all clients
    if SERVER then
        net.Start("BM_DM_Score_Update")
            net.WriteUInt(self.State.LambdaScore, 8)
            net.WriteUInt(self.State.HECUScore, 8)
        net.Broadcast()
    end
    
    -- Check for win condition
    local winningTeam = self:CheckWinCondition()
    if winningTeam then
        self:HandleTeamWin(winningTeam)
    end
end

-- Handle team win
function TeamScore:HandleTeamWin(winningTeam)
    local teamName = winningTeam == TEAM_LAMBDA and "Lambda" or "HECU"
    print("[BM-DM] " .. teamName .. " team wins with score " .. self.State.LambdaScore .. " - " .. self.State.HECUScore)
    
    -- Force end the round
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        BLACKMESA_CORE.Timer.Server:EndRound()
    end
end

-- Reset scores
function TeamScore:ResetScores()
    self.State.LambdaScore = 0
    self.State.HECUScore = 0
    self.State.LastKiller = nil
    self.State.LastVictim = nil
    
    if SERVER then
        net.Start("BM_DM_Score_Reset")
        net.Broadcast()
    end
    
    print("[BM-DM] Team scores reset")
end

-- Initialize score system
function TeamScore:Initialize()
    print("[BM-DM] Initializing team score system...")
    self:ResetScores()
    
    if SERVER then
        -- Hook into player death to track kills
        hook.Add("PlayerDeath", "BM_DM_TeamScore_PlayerDeath", function(victim, inflictor, attacker)
            if not IsValid(victim) or not victim:IsPlayer() then return end
            if not IsValid(attacker) or not attacker:IsPlayer() then return end
            
            -- Don't count suicide
            if victim == attacker then return end
            
            -- Don't count team kills
            if victim:Team() == attacker:Team() then return end
            
            -- Don't count kills during intermission
            if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
                if BLACKMESA_CORE.Timer.Server.State.IsIntermission then
                    return
                end
            end
            
            -- Award kill to attacker's team
            self:AwardKill(attacker:Team())
            
            -- Store for potential use
            self.State.LastKiller = attacker
            self.State.LastVictim = victim
            
            print("[BM-DM] " .. attacker:Nick() .. " killed " .. victim:Nick() .. " (Team: " .. (attacker:Team() == TEAM_LAMBDA and "Lambda" or "HECU") .. ")")
        end)
        
        -- Hook into round start to reset scores
        hook.Add("BM_DM_RoundStart", "BM_DM_TeamScore_RoundStart", function()
            self:ResetScores()
        end)
    end
    
    print("[BM-DM] Team score system ready")
end

-- Console commands
if SERVER then
    concommand.Add("bm_dm_score_reset", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsAdmin() then
            print("[BM-DM] Admin only command")
            return
        end
        
        if BLACKMESA_CORE and BLACKMESA_CORE.TeamScore then
            BLACKMESA_CORE.TeamScore:ResetScores()
        end
    end, nil, "Reset team scores (Admin only)")
    
    concommand.Add("bm_dm_score_add", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsAdmin() then
            print("[BM-DM] Admin only command")
            return
        end
        
        if #args < 2 then
            print("[BM-DM] Usage: bm_dm_score_add <team> <amount>")
            return
        end
        
        local teamName = string.lower(args[1])
        local amount = tonumber(args[2]) or 1
        local targetTeam = nil
        
        if teamName == "lambda" then
            targetTeam = TEAM_LAMBDA
        elseif teamName == "hecu" then
            targetTeam = TEAM_HECU
        else
            print("[BM-DM] Invalid team. Use 'lambda' or 'hecu'")
            return
        end
        
        if BLACKMESA_CORE and BLACKMESA_CORE.TeamScore then
            for i = 1, amount do
                BLACKMESA_CORE.TeamScore:AwardKill(targetTeam)
            end
        end
    end, nil, "Add points to team score (Admin only): bm_dm_score_add <team> <amount>")
end

-- Client-side score display
if CLIENT then
    -- Score state for client
    TeamScore.ClientState = {
        LambdaScore = 0,
        HECUScore = 0,
        IsVisible = true
    }
    
    -- Create font for score display
    surface.CreateFont("BM_DM_Score", {
        font = "Arial",
        size = 32,
        weight = 600,
        antialias = true,
        extended = true
    })
    
    -- Network receiver for score updates
    net.Receive("BM_DM_Score_Update", function()
        TeamScore.ClientState.LambdaScore = net.ReadUInt(8)
        TeamScore.ClientState.HECUScore = net.ReadUInt(8)
    end)
    
    -- Network receiver for score reset
    net.Receive("BM_DM_Score_Reset", function()
        TeamScore.ClientState.LambdaScore = 0
        TeamScore.ClientState.HECUScore = 0
    end)
    
    -- Get client score text
    function TeamScore:GetClientScoreText()
        local lambdaScore = self.ClientState.LambdaScore
        local hecuScore = self.ClientState.HECUScore
        
        if lambdaScore == hecuScore then
            return string.format(self.Config.ScoreDisplayFormat, lambdaScore, hecuScore)
        elseif lambdaScore > hecuScore then
            return string.format("LAMBDA | %d - %d", lambdaScore, hecuScore)
        else
            return string.format("HECU | %d - %d", lambdaScore, hecuScore)
        end
    end
    
    -- Draw score display
    function TeamScore:DrawScore()
        -- Only show score during active rounds, not during intermission
        if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Client then
            local timer = BLACKMESA_CORE.Timer.Client
            
            -- Don't show score during intermission
            if timer.State.IsIntermission then
                return
            end
            
            -- Don't show score when round is not active
            if not timer.State.IsRoundActive then
                return
            end
        end
        
        local scoreText = self:GetClientScoreText()
        local textColor = Color(255, 0, 0, 255) -- Red color like in the reference image
        
        -- Position the score under the timer (assuming timer is at top center)
        local x = ScrW() / 2
        local y = 120 -- Position under timer
        
        -- Draw the score text
        draw.SimpleText(scoreText, "BM_DM_Score", x, y, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    -- Toggle score visibility
    concommand.Add("bm_dm_score_toggle", function()
        if BLACKMESA_CORE and BLACKMESA_CORE.TeamScore then
            BLACKMESA_CORE.TeamScore.ClientState.IsVisible = not BLACKMESA_CORE.TeamScore.ClientState.IsVisible
            print("[BM-DM] Score display " .. (BLACKMESA_CORE.TeamScore.ClientState.IsVisible and "enabled" or "disabled"))
        end
    end, nil, "Toggle score display visibility")
    
    -- Request current score from server
    concommand.Add("bm_dm_score_request", function()
        if BLACKMESA_CORE and BLACKMESA_CORE.TeamScore then
            print("[BM-DM] Current score: " .. BLACKMESA_CORE.TeamScore:GetClientScoreText())
        end
    end, nil, "Request current score from server")
    
    -- Debug team score state
    concommand.Add("bm_dm_score_debug", function()
        if BLACKMESA_CORE and BLACKMESA_CORE.TeamScore then
            local score = BLACKMESA_CORE.TeamScore
            print("=== Team Score Debug ===")
            print("Client State:")
            print("  Lambda Score: " .. score.ClientState.LambdaScore)
            print("  HECU Score: " .. score.ClientState.HECUScore)
            print("  Is Visible: " .. tostring(score.ClientState.IsVisible))
            print("  Score Text: " .. score:GetClientScoreText())
            
            if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Client then
                local timer = BLACKMESA_CORE.Timer.Client
                print("Timer State:")
                print("  Is Intermission: " .. tostring(timer.State.IsIntermission))
                print("  Is Round Active: " .. tostring(timer.State.IsRoundActive))
                print("  Has Enough Players: " .. tostring(timer:HasEnoughPlayers()))
            end
            print("======================")
        else
            print("[BM-DM] Team score system not available")
        end
    end, nil, "Debug team score state")
end

-- Initialize when loaded
TeamScore:Initialize()
