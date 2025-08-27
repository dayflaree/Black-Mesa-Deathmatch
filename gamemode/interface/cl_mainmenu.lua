-- Black Mesa Deathmatch - Main Menu (Client)
-- Recreates a Black Mesa style team selection menu with background scene

if not CLIENT then return end
-- Debug spawnpoint client render
local debugSpheres = {}
net.Receive("BM_DM_DebugSpawns", function()
    debugSpheres = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        debugSpheres[i] = net.ReadVector()
    end
    -- Replace any existing debug draw hook
    hook.Remove("PostDrawTranslucentRenderables", "BM_DM_DrawDebugSpawns")
    hook.Add("PostDrawTranslucentRenderables", "BM_DM_DrawDebugSpawns", function()
        cam.Start3D()
        render.SetColorMaterial()
        for i = 1, #debugSpheres do
            local pos = debugSpheres[i]
            render.DrawSphere(pos, 16, 16, 16, Color(255, 0, 0, 130))
        end
        cam.End3D()
    end)
    -- If the server sent an empty payload, clear immediately
    if count == 0 then
        hook.Remove("PostDrawTranslucentRenderables", "BM_DM_DrawDebugSpawns")
        debugSpheres = {}
    end
end)


local interface = BLACKMESA and BLACKMESA.Interface or {}
BLACKMESA = BLACKMESA or {}
BLACKMESA.Interface = interface

-- Music handle
local menuMusic

local function startMenuMusic()
    if menuMusic and IsValid(menuMusic) then return end
    local cfg = BLACKMESA.UI and BLACKMESA.UI.music or nil
    if not cfg or not cfg.sound or cfg.sound == "" then return end

    sound.PlayFile("sound/" .. cfg.sound, "noblock", function(chan, errId, errStr)
        if IsValid(chan) then
            chan:SetVolume(cfg.volume or 0.5)
            chan:Play()
            if cfg.shouldLoop then
                chan:EnableLooping(true)
            end
            menuMusic = chan
        else
            print("[BM-DM] Failed to play menu music:", errId, errStr)
        end
    end)
end

local function stopMenuMusic()
    if menuMusic and IsValid(menuMusic) then
        menuMusic:EnableLooping(false)
        menuMusic:Stop()
        menuMusic = nil
    end
end

-- Background scene camera
local activeScene
local camEntity

local function createScene()
    if activeScene then return end
    local cfg = BLACKMESA.MainMenuScene or {}

    -- Build a camera entity for deterministic rendering
    camEntity = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if IsValid(camEntity) then
        camEntity:SetNoDraw(true)
        camEntity:SetPos(cfg.position or Vector(0,0,0))
        camEntity:SetAngles(cfg.angles or Angle(0,0,0))
    end

    hook.Add("CalcView", "BM_DM_MainMenu_CalcView", function(ply, origin, angles, fov)
        if not activeScene then return end
        local view = {}
        if IsValid(camEntity) then
            view.origin = camEntity:GetPos()
            view.angles = camEntity:GetAngles()
        else
            view.origin = (cfg.position or Vector(0,0,0))
            view.angles = (cfg.angles or Angle(0,0,0))
        end
        view.fov = cfg.fov or 75
        view.drawviewer = true
        return view
    end)

    hook.Add("ShouldDrawLocalPlayer", "BM_DM_MainMenu_ShouldDrawLocalPlayer", function()
        if activeScene then return true end
    end)

    activeScene = true
end

local function destroyScene()
    if not activeScene then return end
    hook.Remove("CalcView", "BM_DM_MainMenu_CalcView")
    hook.Remove("ShouldDrawLocalPlayer", "BM_DM_MainMenu_ShouldDrawLocalPlayer")
    if IsValid(camEntity) then camEntity:Remove() end
    camEntity = nil
    activeScene = false
end

-- UI construction
local function makeHeader(parent)
    local header = vgui.Create("DPanel", parent)
    header:Dock(TOP)
    header:SetTall(80)
    header.Paint = function(self, w, h)
        -- Draw header logo image (50% of 1744x205) and the game mode label on the right
        local matPath = BLACKMESA and BLACKMESA.UI and BLACKMESA.UI.materials and BLACKMESA.UI.materials.headerLogo
        if matPath then
            local m = Material(matPath, "smooth")
            surface.SetMaterial(m)
            surface.SetDrawColor(255, 255, 255)
            local scale = (BLACKMESA.UI and BLACKMESA.UI.headerLogoScale) or 0.5
            local iw, ih = 1744 * scale, 205 * scale
            local y = (h - ih) * 0.5
            surface.DrawTexturedRect(12, y, iw, ih)
        end
        draw.SimpleText("TEAM DEATHMATCH", "BM_DM_HeaderSmall", w - 24, h / 2, Color(255,180,0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    return header
end

local function makeTeamPanel(parent)
    local container = vgui.Create("DPanel", parent)
    container:Dock(FILL)
    container:DockMargin(0, 8, 0, 8)
    container.Paint = function(self, w, h) end

    local left = vgui.Create("DPanel", container)
    left:Dock(LEFT)
    left:SetWide(container:GetWide() * 0.5)
    left:DockMargin(64, 32, 16, 32)
    left.CurrentAlpha = (BLACKMESA.UI and BLACKMESA.UI.teamImageBaseAlpha) or 128
    left:SetMouseInputEnabled(true)
    left.Paint = function(self, w, h)
        local mat = BLACKMESA and BLACKMESA.UI and BLACKMESA.UI.materials and BLACKMESA.UI.materials.teamLambda
        if mat then
            local m = Material(mat, "smooth")
            surface.SetMaterial(m)
            local base = (BLACKMESA.UI and BLACKMESA.UI.teamImageBaseAlpha) or 128
            local target = self:IsHovered() and ((BLACKMESA.UI and BLACKMESA.UI.teamImageHoverAlpha) or 255) or base
            local speed = (BLACKMESA.UI and BLACKMESA.UI.teamImageFadeSpeed) or 8
            self.CurrentAlpha = Lerp(FrameTime() * speed, self.CurrentAlpha or base, target)
            surface.SetDrawColor(255, 255, 255, self.CurrentAlpha)
            local size = (BLACKMESA.UI and BLACKMESA.UI.teamImageSize) or 500
            local oy = (BLACKMESA.UI and BLACKMESA.UI.teamImageOffsetY) or 0.15
            surface.DrawTexturedRect(w * 0.5 - size * 0.5, h * oy, size, size)
            -- Players caption
            local textY = h * oy + size + 60
            local n = (team and TEAM_LAMBDA and team.NumPlayers and team.NumPlayers(TEAM_LAMBDA)) or 0
            local label = (n == 1) and "1 player" or (tostring(n) .. " players")
            draw.SimpleText(label, "BM_DM_TeamCount", w * 0.5, textY, Color(255,170,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("λ", "BM_DM_Giant", w * 0.32, h * 0.25, Color(255,140,0,240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    left.OnMouseReleased = function(self, code)
        if code == MOUSE_LEFT then
            RunConsoleCommand("bm_dm_join", "lambda")
            if IsValid(interface.Frame) then interface.Frame:Remove() end
        end
    end

    local right = vgui.Create("DPanel", container)
    right:Dock(RIGHT)
    right:SetWide(container:GetWide() * 0.5)
    right:DockMargin(16, 32, 64, 32)
    right.CurrentAlpha = (BLACKMESA.UI and BLACKMESA.UI.teamImageBaseAlpha) or 128
    right:SetMouseInputEnabled(true)
    right.Paint = function(self, w, h)
        local mat = BLACKMESA and BLACKMESA.UI and BLACKMESA.UI.materials and BLACKMESA.UI.materials.teamHECU
        if mat then
            local m = Material(mat, "smooth")
            surface.SetMaterial(m)
            local base = (BLACKMESA.UI and BLACKMESA.UI.teamImageBaseAlpha) or 128
            local target = self:IsHovered() and ((BLACKMESA.UI and BLACKMESA.UI.teamImageHoverAlpha) or 255) or base
            local speed = (BLACKMESA.UI and BLACKMESA.UI.teamImageFadeSpeed) or 8
            self.CurrentAlpha = Lerp(FrameTime() * speed, self.CurrentAlpha or base, target)
            surface.SetDrawColor(255, 255, 255, self.CurrentAlpha)
            local size = (BLACKMESA.UI and BLACKMESA.UI.teamImageSize) or 500
            local oy = (BLACKMESA.UI and BLACKMESA.UI.teamImageOffsetY) or 0.15
            surface.DrawTexturedRect(w * 0.5 - size * 0.5, h * oy, size, size)
            local textY = h * oy + size + 60
            local n = (team and TEAM_HECU and team.NumPlayers and team.NumPlayers(TEAM_HECU)) or 0
            local label = (n == 1) and "1 player" or (tostring(n) .. " players")
            draw.SimpleText(label, "BM_DM_TeamCount", w * 0.5, textY, Color(255,170,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("H.E.C.U.", "BM_DM_GiantRight", w * 0.60, h * 0.22, Color(0,255,120,230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(0, 255, 120, 220)
            surface.DrawOutlinedRect(w * 0.45, h * 0.25, w * 0.30, h * 0.50, 6)
            draw.SimpleText("HECU", "BM_DM_GiantRight", w * 0.60, h * 0.50, Color(0,255,120,230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    right.OnMouseReleased = function(self, code)
        if code == MOUSE_LEFT then
            RunConsoleCommand("bm_dm_join", "hecu")
            if IsValid(interface.Frame) then interface.Frame:Remove() end
        end
    end

    -- Keep halves equal on resize
    container.PerformLayout = function(self, w, h)
        left:SetWide(w * 0.5)
        right:SetWide(w * 0.5)
    end

    return container
end

local function makeButtonBar(parent)
    local bar = vgui.Create("DPanel", parent)
    bar:Dock(BOTTOM)
    bar:SetTall((BLACKMESA.UI and BLACKMESA.UI.bottomBarHeight) or 220)
    bar:DockMargin(0, 0, 0, 0)
    bar.Paint = function(self, w, h) end

    -- A centered stack container that controls the actual button width
    local stack = vgui.Create("DPanel", bar)
    stack:SetPaintBackground(false)
    stack:SetSize(420, bar:GetTall())
    stack:SetPos((bar:GetWide() - stack:GetWide()) * 0.5, (BLACKMESA.UI and BLACKMESA.UI.buttonListTopPadding) or 0)

    local function relayout()
        local desired = 0
        if BLACKMESA and BLACKMESA.UI and BLACKMESA.UI.buttonWidth then
            desired = BLACKMESA.UI.buttonWidth
        else
            desired = math.Round(math.Clamp(ScrW() * 0.22, 280, 520))
        end
        stack:SetSize(desired, bar:GetTall())
        local topPad = (BLACKMESA.UI and BLACKMESA.UI.buttonListTopPadding) or 0
        stack:SetPos((bar:GetWide() - desired) * 0.5, topPad)
    end
    bar.PerformLayout = function(self, w, h)
        relayout()
    end

    local function addMenuButton(text, onClick)
        local btn = vgui.Create("DButton", stack)
        btn:Dock(TOP)
        btn:SetTall(48)
        local spacing = (BLACKMESA.UI and BLACKMESA.UI.buttonSpacing) or 12
        btn:DockMargin(0, spacing, 0, 0)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local hovered = self:IsHovered()
            -- Fill: dark by default, red tint on hover
            if hovered then
                local ha = (BLACKMESA.UI and BLACKMESA.UI.buttonHoverAlpha) or 120
                surface.SetDrawColor(200, 40, 40, ha)
            else
                surface.SetDrawColor(0, 0, 0, 120)
            end
            surface.DrawRect(0, 0, w, h)
            -- Outline stays thin and orange
            surface.SetDrawColor(255, 160, 0)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(text, "BM_DM_Button", w/2, h/2, Color(255,170,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            surface.PlaySound("buttons/button14.wav")
            if onClick then onClick() end
        end
        return btn
    end

    addMenuButton("Auto Assign", function() 
        -- Get team player counts
        local lambdaCount = (team and TEAM_LAMBDA and team.NumPlayers and team.NumPlayers(TEAM_LAMBDA)) or 0
        local hecuCount = (team and TEAM_HECU and team.NumPlayers and team.NumPlayers(TEAM_HECU)) or 0
        
        -- Determine which team to assign to
        local targetTeam = "lambda" -- default
        if lambdaCount > hecuCount then
            targetTeam = "hecu"
        elseif hecuCount > lambdaCount then
            targetTeam = "lambda"
        else
            -- Equal counts or both zero - random assignment
            targetTeam = math.random() > 0.5 and "lambda" or "hecu"
        end
        
        RunConsoleCommand("bm_dm_join", targetTeam)
        if IsValid(interface.Frame) then interface.Frame:Remove() end
    end)
    addMenuButton("Spectate", function() RunConsoleCommand("bm_dm_spectate") end)
    addMenuButton("Disconnect", function()
        if IsValid(bar:GetParent()) then bar:GetParent():Remove() end
        gui.EnableScreenClicker(false)
        destroyScene()
        stopMenuMusic()
        RunConsoleCommand("disconnect")
    end)

    return bar
end

-- Fonts
surface.CreateFont("BM_DM_Header", {font = "Roboto", size = 36, weight = 600, extended = true})
surface.CreateFont("BM_DM_HeaderSmall", {font = "Roboto", size = 26, weight = 400, extended = true})
surface.CreateFont("BM_DM_Label", {font = "Roboto", size = 18, weight = 400, extended = true})
surface.CreateFont("BM_DM_Button", {font = "Roboto", size = 20, weight = 600, extended = true})
surface.CreateFont("BM_DM_Giant", {font = "Arial", size = 220, weight = 1000, extended = true})
surface.CreateFont("BM_DM_GiantRight", {font = "Arial", size = 120, weight = 1000, extended = true})
surface.CreateFont("BM_DM_TeamCount", {font = "Roboto", size = 22, weight = 600, extended = true})

function interface.CreateMainMenu()
    if IsValid(interface.Frame) then interface.Frame:Remove() end

    gui.EnableScreenClicker(true)

    -- Scene & music
    createScene()
    startMenuMusic()

    local f = vgui.Create("DFrame")
    interface.Frame = f
    f:SetTitle("")
    f:SetDraggable(false)
    f:ShowCloseButton(false)
    f:SetSize(ScrW(), ScrH())
    f:SetPos(0, 0)
    f:DockPadding(0, 0, 0, 0)
    f.Paint = function(self, w, h)
        -- Draw top and bottom bars at full screen width (with overscan)
        local bHeight = (BLACKMESA.UI and BLACKMESA.UI.bottomBarHeight) or 220
        local bOver = (BLACKMESA.UI and BLACKMESA.UI.bottomBarOverscan) or 0
        local tHeight = (BLACKMESA.UI and BLACKMESA.UI.topBarHeight) or 96
        local tOver = (BLACKMESA.UI and BLACKMESA.UI.topBarOverscan) or bOver

        -- Top bar (separator at bottom edge of the bar)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(-tOver, 0, w + tOver * 2, tHeight)
        surface.SetDrawColor(255, 160, 0, 230)
        surface.DrawRect(-tOver, tHeight - 3, w + tOver * 2, 3)

        -- Bottom bar (separator at top edge of the bar)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(-bOver, h - bHeight, w + bOver * 2, bHeight)
        surface.SetDrawColor(255, 160, 0, 230)
        surface.DrawRect(-bOver, h - bHeight, w + bOver * 2, 3)
    end

    local header = makeHeader(f)
    local teams = makeTeamPanel(f)
    local buttons = makeButtonBar(f)

    -- Cleanup hooks when frame is removed
    f.OnRemove = function()
        gui.EnableScreenClicker(false)
        destroyScene()
        stopMenuMusic()
    end
end

-- Optional console command to test the menu
concommand.Add("bm_dm_menu", function()
    if interface.CreateMainMenu then interface.CreateMainMenu() end
end)

-- Intercept ESC: hide default GMod menu and toggle our menu instead
hook.Add("OnGameUIVisible", "BM_DM_Escape_OpenMenu", function()
    -- Prevent default pause/menu from showing
    gui.HideGameUI()

    if IsValid(interface.Frame) then
        interface.Frame:Remove()
        return
    end

    if interface.CreateMainMenu then
        interface.CreateMainMenu()
    end
end)

-- Fallback for builds where OnGameUIVisible may not fire reliably
do
    local wasVisible = false
    hook.Add("PreRender", "BM_DM_Escape_OpenMenu_Fallback", function()
        local vis = gui.IsGameUIVisible()
        if vis and not wasVisible then
            gui.HideGameUI()
            if IsValid(interface.Frame) then
                interface.Frame:Remove()
            else
                if interface.CreateMainMenu then interface.CreateMainMenu() end
            end
        end
        wasVisible = vis
    end)
end

-- Hide the default GMod HUD while our main menu is open
hook.Add("HUDShouldDraw", "BM_DM_HideHUD_WhenMenuOpen", function(name)
    if IsValid(BLACKMESA and BLACKMESA.Interface and BLACKMESA.Interface.Frame) then
        return false
    end
end)
