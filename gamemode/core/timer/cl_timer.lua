-- Black Mesa Deathmatch - Client Timer
-- Displays round timer in green Arial font

print("[BM-DM] Loading client timer...")

if not CLIENT then 
    print("[BM-DM] Client timer skipped (not client)")
    return 
end

BLACKMESA_CORE.Timer.Client = BLACKMESA_CORE.Timer.Client or {}
local ClientTimer = BLACKMESA_CORE.Timer.Client

-- Timer state
ClientTimer.State = {
    TimeLeft = 0,
    IsIntermission = false,
    IsRoundActive = false,
    CurrentRound = 0,
    IsVisible = true
}

-- Create fonts
surface.CreateFont("BM_DM_Timer_Large", {
    font = "Arial",
    size = 48,
    weight = 800,
    antialias = true,
    extended = true
})

surface.CreateFont("BM_DM_Timer_Medium", {
    font = "Arial",
    size = 32,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("BM_DM_Timer_Small", {
    font = "Arial",
    size = 24,
    weight = 400,
    antialias = true,
    extended = true
})

-- Format time as MM:SS
function ClientTimer:FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- Format time as MM:SS (no milliseconds)
function ClientTimer:FormatTimeDetailed(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- Check if there are enough players to start a round
function ClientTimer:HasEnoughPlayers()
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

-- Get player counts for both teams
function ClientTimer:GetPlayerCounts()
    local lambdaPlayers = 0
    local hecuPlayers = 0
    
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Team() == TEAM_LAMBDA then
            lambdaPlayers = lambdaPlayers + 1
        elseif IsValid(ply) and ply:Team() == TEAM_HECU then
            hecuPlayers = hecuPlayers + 1
        end
    end
    
    return lambdaPlayers, hecuPlayers
end

-- Draw the timer
function ClientTimer:DrawTimer()
    if not self.State.IsVisible then return end
    
    local timeLeft = self.State.TimeLeft
    local isIntermission = self.State.IsIntermission
    
    -- Check if we have enough players
    local hasEnoughPlayers = self:HasEnoughPlayers()
    
    -- If not enough players, show "Not Enough Players" message
    if not hasEnoughPlayers then
        local message = "Not Enough Players"
        local font = "BM_DM_Timer_Large"
        local color = Color(255, 0, 0, 255) -- Red color
        
        -- Calculate position (top center of screen)
        local screenW, screenH = ScrW(), ScrH()
        local x = screenW / 2
        local y = 50 -- Top of screen
        
        -- Use fixed width for consistent centering (measure "Not Enough Players" width)
        surface.SetFont(font)
        local fixedWidth = surface.GetTextSize("Not Enough Players")
        
        -- Draw main message (centered with fixed width)
        surface.SetTextColor(color)
        surface.SetTextPos(x - fixedWidth/2, y)
        surface.DrawText(message)
        
        -- Draw player counts below (centered, moved down more)
        local lambdaCount, hecuCount = self:GetPlayerCounts()
        local countText = "Lambda: " .. lambdaCount .. " | HECU: " .. hecuCount
        
        surface.SetFont("BM_DM_Timer_Small")
        local countW, countH = surface.GetTextSize(countText)
        surface.SetTextColor(255, 255, 255, 200) -- White color
        surface.SetTextPos(x - countW/2, y + 60) -- Fixed position below main message
        surface.DrawText(countText)
        
        return
    end
    
    -- Don't show timer during initial 10:00 state
    if not isIntermission and timeLeft >= 600 then
        return
    end
    
    -- Format time string
    local timeString
    if isIntermission then
        timeString = self:FormatTimeDetailed(timeLeft)
    else
        timeString = self:FormatTime(timeLeft)
    end
    
    -- Determine font and color (same for both intermission and round)
    local font = "BM_DM_Timer_Large"
    local color = Color(0, 255, 0, 255) -- Bright green (same for both states)
    
    -- Calculate position (top center of screen)
    local screenW, screenH = ScrW(), ScrH()
    local x = screenW / 2
    local y = 50 -- Top of screen (same position for both states)
    
    -- Use fixed width to prevent movement (measure "10:00" width for consistency)
    surface.SetFont(font)
    local fixedWidth = surface.GetTextSize("10:00")
    
    -- Draw main text (no effects, just normal text)
    surface.SetTextColor(color)
    surface.SetTextPos(x - fixedWidth/2, y)
    surface.DrawText(timeString)
    
    -- Only display the green timer, no additional text
end

-- Network receivers
net.Receive("BM_DM_Timer_Update", function()
    local timeLeft = net.ReadFloat()
    local isIntermission = net.ReadBool()
    
    ClientTimer.State.TimeLeft = timeLeft
    ClientTimer.State.IsIntermission = isIntermission
end)

net.Receive("BM_DM_Timer_RoundStart", function()
    local roundNumber = net.ReadUInt(16)
    local roundEndTime = net.ReadFloat()
    
    ClientTimer.State.CurrentRound = roundNumber
    ClientTimer.State.IsIntermission = false
    ClientTimer.State.IsRoundActive = true
    
    -- Play round start sound
    surface.PlaySound("buttons/button14.wav")
    
    print("[BM-DM] Round " .. roundNumber .. " started")
end)

net.Receive("BM_DM_Timer_RoundEnd", function()
    local roundNumber = net.ReadUInt(16)
    
    ClientTimer.State.IsIntermission = true
    ClientTimer.State.IsRoundActive = false
    
    -- Play round end sound
    surface.PlaySound("buttons/button10.wav")
    
    print("[BM-DM] Round " .. roundNumber .. " ended")
end)

net.Receive("BM_DM_Timer_ShowMenu", function()
    -- Show main menu when forced by server
    if BLACKMESA and BLACKMESA.Interface and BLACKMESA.Interface.CreateMainMenu then
        BLACKMESA.Interface.CreateMainMenu()
    end
end)

net.Receive("BM_DM_Timer_StateResponse", function()
    local roundEndTime = net.ReadFloat()
    local intermissionStartTime = net.ReadFloat()
    local isIntermission = net.ReadBool()
    local isRoundActive = net.ReadBool()
    local currentRound = net.ReadUInt(16)
    
    ClientTimer.State.CurrentRound = currentRound
    ClientTimer.State.IsIntermission = isIntermission
    ClientTimer.State.IsRoundActive = isRoundActive
    
    -- Calculate time left based on current state
    if isIntermission then
        local timeLeft = 60 - (CurTime() - intermissionStartTime)
        ClientTimer.State.TimeLeft = math.max(0, timeLeft)
    elseif isRoundActive then
        local timeLeft = roundEndTime - CurTime()
        ClientTimer.State.TimeLeft = math.max(0, timeLeft)
    end
    
    print("[BM-DM] Received timer state: Round " .. currentRound .. ", Intermission: " .. tostring(isIntermission) .. ", RoundActive: " .. tostring(isRoundActive))
end)

-- Initialize client timer
function ClientTimer:Initialize()
    print("[BM-DM] Client timer initialized")
    
    -- Set a default timer state for testing
    self.State.TimeLeft = 600 -- 10 minutes
    self.State.CurrentRound = 1
    self.State.IsIntermission = false
    self.State.IsRoundActive = false
    self.State.IsVisible = true
    
    -- Add HUD hook to draw timer and score
    hook.Add("HUDPaint", "BM_DM_Timer_HUD", function()
        self:DrawTimer()
        
        -- Draw team score under the timer
        if BLACKMESA_CORE and BLACKMESA_CORE.TeamScore then
            BLACKMESA_CORE.TeamScore:DrawScore()
        end
    end)
    
    -- Request initial timer state from server
    if SERVER then return end
    
    -- Send request for timer state after a short delay
    timer.Simple(1, function()
        net.Start("BM_DM_Timer_RequestState")
        net.SendToServer()
        print("[BM-DM] Requested timer state from server")
    end)
end

-- Console commands for testing
concommand.Add("bm_dm_timer_toggle", function()
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Client then
        BLACKMESA_CORE.Timer.Client.State.IsVisible = not BLACKMESA_CORE.Timer.Client.State.IsVisible
        print("[BM-DM] Timer visibility: " .. (BLACKMESA_CORE.Timer.Client.State.IsVisible and "ON" or "OFF"))
    end
end, nil, "Toggle timer visibility")

concommand.Add("bm_dm_timer_test", function()
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Client then
        BLACKMESA_CORE.Timer.Client.State.TimeLeft = 300 -- 5 minutes
        BLACKMESA_CORE.Timer.Client.State.IsIntermission = false
        BLACKMESA_CORE.Timer.Client.State.CurrentRound = 1
        print("[BM-DM] Test timer set to 5 minutes")
    end
end, nil, "Set test timer (5 minutes)")

concommand.Add("bm_dm_timer_debug", function()
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Client then
        local timer = BLACKMESA_CORE.Timer.Client
        print("=== Timer Debug Info ===")
        print("Time Left: " .. timer.State.TimeLeft)
        print("Is Intermission: " .. tostring(timer.State.IsIntermission))
        print("Current Round: " .. timer.State.CurrentRound)
        print("Is Visible: " .. tostring(timer.State.IsVisible))
        print("=======================")
    else
        print("[BM-DM] Timer system not available")
    end
end, nil, "Debug timer information")
