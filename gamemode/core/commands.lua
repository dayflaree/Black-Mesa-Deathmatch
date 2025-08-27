-- Black Mesa Deathmatch - Admin Commands
-- General admin commands for server management

if not SERVER then return end

-- Force all players to join teams command
concommand.Add("bm_dm_force_teams", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        print("[BM-DM] Admin only command")
        return
    end
    
    local players = player.GetAll()
    local lambdaCount = 0
    local hecuCount = 0
    
    -- First, count players already on teams
    for _, player in ipairs(players) do
        if IsValid(player) then
            if player:Team() == TEAM_LAMBDA then
                lambdaCount = lambdaCount + 1
            elseif player:Team() == TEAM_HECU then
                hecuCount = hecuCount + 1
            end
        end
    end
    
    print("[BM-DM] Current team distribution: Lambda=" .. lambdaCount .. ", HECU=" .. hecuCount)
    
    -- Now assign players who aren't on teams yet
    for _, player in ipairs(players) do
        if IsValid(player) and player:Team() ~= TEAM_LAMBDA and player:Team() ~= TEAM_HECU then
            -- Put player in the team with fewer players
            if lambdaCount <= hecuCount then
                player:SetTeam(TEAM_LAMBDA)
                lambdaCount = lambdaCount + 1
                print("[BM-DM] Forced " .. player:Nick() .. " to Lambda team (now Lambda=" .. lambdaCount .. ", HECU=" .. hecuCount .. ")")
            else
                player:SetTeam(TEAM_HECU)
                hecuCount = hecuCount + 1
                print("[BM-DM] Forced " .. player:Nick() .. " to HECU team (now Lambda=" .. lambdaCount .. ", HECU=" .. hecuCount .. ")")
            end
        end
    end
    
    print("[BM-DM] Team distribution: Lambda=" .. lambdaCount .. ", HECU=" .. hecuCount)
end, nil, "Force all players to join teams (Admin only)")
