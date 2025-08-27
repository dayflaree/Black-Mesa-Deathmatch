-- Shared configuration and variables

-- Gamemode information
GM.Name = "Black Mesa Deathmatch"
GM.Author = "Dayflare"
GM.Email = "elijah.j.staley@proton.me"
GM.Website = "https://project-ordinance.com/"

-- Include gamemode files
-- Derive from sandbox to get noclip/spawnmenu behavior
DeriveGamemode("sandbox")

-- Include core module
include("core/init.lua")

-- Include interface folder
-- Interface bootstrap
BLACKMESA = BLACKMESA or {}
BLACKMESA.Interface = BLACKMESA.Interface or {}

-- Shared variables and configuration
-- Gamemode settings
BLACKMESA.GamemodeName = "Black Mesa Deathmatch"
BLACKMESA.Version = "0.1.0"

-- Interface reference
-- Make legacy reference for older files
BLACKMESA_INTERFACE = BLACKMESA.Interface

-- Configurable map scene for the main menu background
-- These can be customized per-map or via server cfg
BLACKMESA.MainMenuScene = {
    enabled = true,
    map = nil,                -- nil means use current map
    position = Vector(1210.073486, -398.093628, 2239.953125),
    angles = Angle(15.848253, 131.540329, 0.000000),
    fov = 75,
    dof = false,
}

-- UI and audio configuration
BLACKMESA.UI = {
    music = {
        sound = "blackmesa_deathmatch/deathmatch_menu.wav",
        volume = 0.3,
        shouldLoop = true,
    },
    buttonWidth = 300,
    teamImageSize = 400,
    teamImageOffsetY = 0.10, -- fraction of panel height from top
    bottomBarHeight = 350,
    buttonListTopPadding = 40, -- px offset inside bottom bar
    buttonSpacing = 30, -- vertical spacing between stacked buttons (px)
    buttonHoverAlpha = 40, -- alpha for red hover fill on buttons
    bottomBarOverscan = 8, -- px to extend bottom bar beyond screen edges
    topBarHeight = 96, -- height of the top overlay bar
    topBarOverscan = 8, -- px to extend the top bar beyond edges (defaults to bottom if unset)
    headerLogoScale = 0.3, -- scale of 1744x205 header logo (0.5 was original)
    -- Team image hover fade configuration
    teamImageBaseAlpha = 128,   -- 50% transparency when idle
    teamImageHoverAlpha = 255,  -- fully opaque on hover
    teamImageFadeSpeed = 8,     -- higher = faster fade

    materials = {
        headerLogo = "ordinance/ordinance_title_alt.png",
        teamLambda = "blackmesa_deathmatch/team_lambda.png",
        teamHECU = "blackmesa_deathmatch/team_hecu.png",
        button = "vgui/blackmesa/button_placeholder",
    },
}

-- Team definitions (shared)
TEAM_LAMBDA = 1
TEAM_HECU = 2

team.SetUp(TEAM_LAMBDA, "Lambda", Color(255, 150, 0), false)
team.SetUp(TEAM_HECU, "HECU", Color(80, 255, 120), false)
