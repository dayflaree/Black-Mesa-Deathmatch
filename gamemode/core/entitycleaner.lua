-- Black Mesa Deathmatch - Entity Cleaner
-- Removes ALL entities on map initialization

BLACKMESA_CORE.EntityCleaner = BLACKMESA_CORE.EntityCleaner or {}
local EntityCleaner = BLACKMESA_CORE.EntityCleaner

-- Remove ALL entities on map initialization
function EntityCleaner:CleanMap()
    print("[BM-DM] Starting complete map cleanup...")
    
    local removedCount = 0
    local allEntities = ents.GetAll()
    
    for _, ent in ipairs(allEntities) do
        if IsValid(ent) then
            local className = ent:GetClass()
            
            -- Remove all weapons, ammo, and health entities
            if className:find("weapon_") or className:find("item_ammo_") or className:find("item_bm") or className:find("item_health") or className:find("item_battery") then
                print("[BM-DM] Removing entity: " .. className)
                ent:Remove()
                removedCount = removedCount + 1
            end
        end
    end
    
    print("[BM-DM] Complete map cleanup finished. Removed " .. removedCount .. " entities.")
    return removedCount
end

-- Initialize the entity cleaner
function EntityCleaner:Initialize()
    print("[BM-DM] Entity cleaner initialized")
end

-- Console command to manually trigger cleanup
concommand.Add("bm_dm_clean_map", function(ply, cmd, args)
    if BLACKMESA_CORE and BLACKMESA_CORE.EntityCleaner then
        local removed = BLACKMESA_CORE.EntityCleaner:CleanMap()
        print("[BM-DM] Manual cleanup removed " .. removed .. " entities")
    else
        print("[BM-DM] Entity cleaner not available")
    end
end)

-- Initialize when loaded
EntityCleaner:Initialize()
