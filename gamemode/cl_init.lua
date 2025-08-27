-- Black Mesa Deathmatch Gamemode
-- Client-side initialization

-- Include shared files
include("shared.lua")

-- Include core module
include("core/init.lua")

-- Load interface components (main menu)
include("interface/cl_mainmenu.lua")

-- Precache menu sound so it is available instantly
if BLACKMESA and BLACKMESA.UI and BLACKMESA.UI.music and BLACKMESA.UI.music.sound then
    sound.Add({
        name = "bm_dm_menu_music",
        channel = CHAN_STATIC,
        volume = BLACKMESA.UI.music.volume or 0.5,
        level = 0,
        pitch = {100, 100},
        sound = BLACKMESA.UI.music.sound
    })
end

-- Initialize client-side gamemode
function GM:Initialize()
    print("Black Mesa Deathmatch client initialized")
end

-- Called when the gamemode loads on client
function GM:InitPostEntity()
    print("Black Mesa Deathmatch client post-entity initialization complete")
    -- Build the custom main menu when we enter the game UI
    if BLACKMESA and BLACKMESA.Interface and BLACKMESA.Interface.CreateMainMenu then
        BLACKMESA.Interface.CreateMainMenu()
    end
end

-- Enable spawn menu on client
function GM:SpawnMenuOpen()
    return true
end

-- Block +zoom command on client side
hook.Add("PlayerBindPress", "BM_DM_BlockZoomClient", function(ply, bind, pressed)
    if bind:find("+zoom") and pressed then
        return true
    end
end)
