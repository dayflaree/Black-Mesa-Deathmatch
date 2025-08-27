-- Black Mesa Deathmatch - Simple Entity Spawner
-- Just spawns entities at the configured positions

BLACKMESA_CORE.EntitySpawner = BLACKMESA_CORE.EntitySpawner or {}
local EntitySpawner = BLACKMESA_CORE.EntitySpawner

if SERVER then
    util.AddNetworkString("BM_DM_DebugSpawns")
end

-- Configuration
EntitySpawner.Config = {
    SpawnInterval = 60,
    MaxWeapons = 8,
    MaxAmmo = 12,
    MaxHealthItems = 6,
    
    -- Spawn points
    SpawnPoints = {
        Vector(1155.083862, -719.664795, 1856.031250),
        Vector(450.201477, 1331.573730, 1856.031250),
        Vector(-875.042603, 933.362244, 1856.031250),
        Vector(263.992859, 543.205994, 2000.031250),
        Vector(-286.953247, -702.851013, 1144.031250),
        Vector(564.539612, 195.261322, 1104.031250),
        Vector(703.376831, -218.459091, 512.031250),
        Vector(-105.697838, 189.502151, 464.031250),
        Vector(303.552246, 193.100693, 464.031250),
        Vector(-618.830811, 1196.939575, 416.031250),
        Vector(-379.379272, 189.951172, 784.031250),
        Vector(-111.619827, 194.830414, 784.031250),
        Vector(311.324493, 192.425308, 784.031250),
        Vector(447.915009, 951.649719, 784.031250),
        Vector(122.356499, 189.308472, 2247.531250),
        Vector(446.035828, 465.038391, 2631.531250),
        Vector(106.722763, -730.352478, 304.031250),
        Vector(388.287445, -999.687012, 1856.031250),
        Vector(147.064468, -564.723022, 2112.031250),
        Vector(35.690186, -808.330078, 2240.031250),
        Vector(671.149658, 1673.867676, 1489.031250),
        Vector(664.395569, 523.469971, 1648.029419),
        Vector(-794.914429, -428.397675, 1856.031250),
        Vector(1154.260254, 481.010254, 1104.031250),
        Vector(519.330505, 640.887451, 2144.031250),
        Vector(64.100510, 956.813660, 1136.031250),
        Vector(796.768982, 1880.770386, 1104.031250)
    },
    
    -- Weapon types
    Weapons = {
        "weapon_bmbshift_357",
        "weapon_bmbshift_crossbow",
        "weapon_bmbshift_grenade",
        "weapon_bmbshift_mp5",
        "weapon_bmbshift_rpg",
        "weapon_bmbshift_satchel",
        "weapon_bmbshift_shotgun",
        "weapon_bmesa_gluon",
        "weapon_bmesa_hivehand",
        "weapon_bmesa_snark",
        "weapon_bmesa_tau",
        "weapon_bmesa_tripmine"
    },
    
    -- Ammo types
    AmmoTypes = {
        "item_bmesa_weaponbox"
    },
    
    -- Health items
    HealthItems = {
        "item_healthkit",
        "item_battery"
    }
}

-- Simple state
EntitySpawner.State = {
    LastSpawnTime = 0
}

-- Simple spawn function
function EntitySpawner:SpawnEntity(entityClass, pos)
    local ent = ents.Create(entityClass)
    if IsValid(ent) then
        -- Find the ground position
        local groundPos = self:FindGroundPosition(pos)
        ent:SetPos(groundPos)
        ent:SetAngles(Angle(0, math.random(0, 360), 0))
        ent:Spawn()
        return true
    end
    return false
end

-- Find the ground position for an entity
function EntitySpawner:FindGroundPosition(pos)
    -- Start from the specified position and trace down to find ground
    local trace = util.TraceLine({
        start = pos + Vector(0, 0, 50), -- Start 50 units above
        endpos = pos - Vector(0, 0, 200), -- Trace down 200 units
        mask = MASK_SOLID
    })
    
    if trace.Hit then
        -- Found ground, place entity slightly above it
        return trace.HitPos + Vector(0, 0, 5)
    else
        -- No ground found, use original position
        return pos
    end
end

-- Spawn all entities
function EntitySpawner:SpawnAllEntities()
    print("[BM-DM] Spawning entities...")
    
    local weaponsSpawned = 0
    local ammoSpawned = 0
    local healthSpawned = 0
    
    -- Shuffle spawn points
    local points = {}
    for i = 1, #self.Config.SpawnPoints do
        points[i] = self.Config.SpawnPoints[i]
    end
    
    for i = #points, 2, -1 do
        local j = math.random(i)
        points[i], points[j] = points[j], points[i]
    end
    
    print("[BM-DM] Using " .. #points .. " spawn points")
    
    -- Spawn weapons first
    for i = 1, math.min(self.Config.MaxWeapons, #points) do
        local weaponClass = self.Config.Weapons[math.random(1, #self.Config.Weapons)]
        if self:SpawnEntity(weaponClass, points[i]) then
            weaponsSpawned = weaponsSpawned + 1
            print("[BM-DM] Spawned weapon at position " .. i)
        end
    end
    
    -- Spawn exactly one entity at every remaining position (guaranteed full coverage)
    local weaponSlots = math.min(self.Config.MaxWeapons, #points)
    for i = weaponSlots + 1, #points do
        local entityPlaced = false
        local remainingPositions = (#points - i + 1)
        local ammoRemaining = self.Config.MaxAmmo - ammoSpawned
        local healthRemaining = self.Config.MaxHealthItems - healthSpawned

        -- Decide what to place so that we don't run out before covering all positions
        local pickAmmo = false
        if ammoRemaining + healthRemaining >= remainingPositions then
            -- We have enough capacity: favor the pool with more remaining
            if ammoRemaining >= healthRemaining and ammoRemaining > 0 then
                pickAmmo = true
            elseif healthRemaining > 0 then
                pickAmmo = false
            else
                pickAmmo = true
            end
        else
            -- Not enough capacity to cover all positions with caps: ignore caps to guarantee fill
            pickAmmo = (math.random(1, 2) == 1)
        end

        if pickAmmo and ammoRemaining > 0 then
            local ammoClass = self.Config.AmmoTypes[math.random(1, #self.Config.AmmoTypes)]
            if self:SpawnEntity(ammoClass, points[i]) then
                ammoSpawned = ammoSpawned + 1
                entityPlaced = true
                print("[BM-DM] Spawned ammo at position " .. i)
            end
        elseif (not pickAmmo) and healthRemaining > 0 then
            local healthClass = self.Config.HealthItems[math.random(1, #self.Config.HealthItems)]
            if self:SpawnEntity(healthClass, points[i]) then
                healthSpawned = healthSpawned + 1
                entityPlaced = true
                print("[BM-DM] Spawned health at position " .. i)
            end
        end

        -- If both caps are exhausted, place a fallback so the position is still used
        if not entityPlaced then
            local fallbackClass
            local isAmmo = false
            if #self.Config.AmmoTypes > 0 then
                fallbackClass = self.Config.AmmoTypes[math.random(1, #self.Config.AmmoTypes)]
                isAmmo = true
            else
                fallbackClass = self.Config.HealthItems[math.random(1, #self.Config.HealthItems)]
                isAmmo = false
            end
            if self:SpawnEntity(fallbackClass, points[i]) then
                if isAmmo then
                    ammoSpawned = ammoSpawned + 1
                else
                    healthSpawned = healthSpawned + 1
                end
                print("[BM-DM] Spawned fallback entity at position " .. i)
            end
        end
    end

    -- Optional second item at each remaining position (max 1 extra per position)
    for i = weaponSlots + 1, #points do
        local ammoRemaining = self.Config.MaxAmmo - ammoSpawned
        local healthRemaining = self.Config.MaxHealthItems - healthSpawned

        -- Stop if nothing remains under caps
        if ammoRemaining <= 0 and healthRemaining <= 0 then break end

        -- Choose what to place as the second item, allowing same-type duplicates
        local placeAmmo
        if ammoRemaining > 0 and healthRemaining > 0 then
            placeAmmo = (math.random(1, 2) == 1)
        else
            placeAmmo = ammoRemaining > 0
        end

        -- Offset the second item slightly so duplicates are visible and not perfectly overlapping
        local angle = math.rad(math.random(0, 359))
        local radius = 18
        local offset = Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)

        if placeAmmo and ammoRemaining > 0 then
            local ammoClass = self.Config.AmmoTypes[math.random(1, #self.Config.AmmoTypes)]
            if self:SpawnEntity(ammoClass, points[i] + offset) then
                ammoSpawned = ammoSpawned + 1
                print("[BM-DM] Spawned extra ammo at position " .. i)
            end
        elseif (not placeAmmo) and healthRemaining > 0 then
            local healthClass = self.Config.HealthItems[math.random(1, #self.Config.HealthItems)]
            if self:SpawnEntity(healthClass, points[i] + offset) then
                healthSpawned = healthSpawned + 1
                print("[BM-DM] Spawned extra health at position " .. i)
            end
        end
    end
    
    print("[BM-DM] Final result: " .. weaponsSpawned .. " weapons, " .. ammoSpawned .. " ammo, " .. healthSpawned .. " health")
    print("[BM-DM] Total entities spawned: " .. (weaponsSpawned + ammoSpawned + healthSpawned))
end

-- Clear all spawned entities (for 300s reset)
function EntitySpawner:ClearAll()
    print("[BM-DM] Clearing spawned entities for reset...")
    local entities = ents.GetAll()
    local removedCount = 0
    
    for _, ent in ipairs(entities) do
        if IsValid(ent) then
            local className = ent:GetClass()
            
            -- Only remove entities that are in our allowed list AND are not being held by players
            local shouldRemove = false
            local entityType = ""
            
            -- Check if it's one of our weapon types
            for _, allowedClass in ipairs(self.Config.Weapons) do
                if className == allowedClass then
                    shouldRemove = true
                    entityType = "weapon"
                    break
                end
            end
            
            -- Check if it's one of our ammo types
            if not shouldRemove then
                for _, allowedClass in ipairs(self.Config.AmmoTypes) do
                    if className == allowedClass then
                        shouldRemove = true
                        entityType = "ammo"
                        break
                    end
                end
            end
            
            -- Check if it's one of our health types
            if not shouldRemove then
                for _, allowedClass in ipairs(self.Config.HealthItems) do
                    if className == allowedClass then
                        shouldRemove = true
                        entityType = "health"
                        break
                    end
                end
            end
            
            -- Only remove if it's our entity AND not being held by a player
            if shouldRemove then
                local owner = ent:GetOwner()
                if not IsValid(owner) or not owner:IsPlayer() then
                    ent:Remove()
                    removedCount = removedCount + 1
                    print("[BM-DM] Removed " .. entityType .. ": " .. className)
                else
                    print("[BM-DM] Skipped " .. entityType .. " held by player: " .. className)
                end
            end
        end
    end
    
    print("[BM-DM] Cleared " .. removedCount .. " spawned entities")
end

-- Think function
function EntitySpawner:Think()
    -- Don't spawn entities during intermission
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        local timer = BLACKMESA_CORE.Timer.Server
        if timer.State.IsIntermission then
            -- During intermission, don't spawn anything and clear any existing entities
            print("[BM-DM] Intermission detected - clearing entities")
            self:ClearAll()
            return
        end
        
        -- Also check if we're in the initial waiting state (no round active)
        if not timer.State.IsRoundActive and not timer.State.IsIntermission then
            -- Waiting for enough players, don't spawn
            return
        end
    else
        print("[BM-DM] Timer system not available in entity spawner")
    end
    
    local currentTime = CurTime()
    if currentTime - self.State.LastSpawnTime >= self.Config.SpawnInterval then
        print("[BM-DM] Resetting entities...")
        self:ClearAll()
        self:SpawnAllEntities()
        self.State.LastSpawnTime = currentTime
    end
end

-- Initialize
function EntitySpawner:Initialize()
    print("[BM-DM] Initializing entity spawner...")
    self.State.LastSpawnTime = CurTime()
    print("[BM-DM] Entity spawner ready")
    
    -- Hook into timer system to clear entities on round start
    if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
        hook.Add("BM_DM_RoundStart", "BM_DM_EntitySpawner_RoundStart", function()
            print("[BM-DM] Clearing entities for new round...")
            -- Stop the intermission clearing timer
            timer.Remove("BM_DM_EntitySpawner_IntermissionClear")
            self:ClearAll()
            self:SpawnAllEntities()
            self.State.LastSpawnTime = CurTime()
        end)
        
        -- Hook into intermission start to clear entities
        hook.Add("BM_DM_IntermissionStart", "BM_DM_EntitySpawner_IntermissionStart", function()
            print("[BM-DM] Clearing entities for intermission...")
            self:ClearAll()
            -- Reset spawn timer to prevent immediate spawning when round starts
            self.State.LastSpawnTime = CurTime()
            
            -- Start a continuous clearing timer during intermission
            timer.Create("BM_DM_EntitySpawner_IntermissionClear", 2, 0, function()
                if BLACKMESA_CORE and BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server then
                    if BLACKMESA_CORE.Timer.Server.State.IsIntermission then
                        self:ClearAll()
                    else
                        -- Stop the clearing timer when intermission ends
                        timer.Remove("BM_DM_EntitySpawner_IntermissionClear")
                    end
                else
                    -- Stop the clearing timer if timer system is not available
                    timer.Remove("BM_DM_EntitySpawner_IntermissionClear")
                end
            end)
        end)
    end
end

-- Start/Stop
function EntitySpawner:Start()
    hook.Add("Think", "BM_DM_EntitySpawner", function() self:Think() end)
end

function EntitySpawner:Stop()
    hook.Remove("Think", "BM_DM_EntitySpawner")
end

-- Test command
concommand.Add("bm_dm_test_spawn", function()
    if BLACKMESA_CORE and BLACKMESA_CORE.EntitySpawner then
        BLACKMESA_CORE.EntitySpawner:ClearAll()
        BLACKMESA_CORE.EntitySpawner:SpawnAllEntities()
    end
end)

-- Debug command to check entity spawner state
concommand.Add("bm_dm_debug_spawner", function()
    if BLACKMESA_CORE and BLACKMESA_CORE.EntitySpawner then
        local spawner = BLACKMESA_CORE.EntitySpawner
        local timer = BLACKMESA_CORE.Timer and BLACKMESA_CORE.Timer.Server
        
        print("[BM-DM] Entity Spawner Debug Info:")
        print("  Last Spawn Time: " .. spawner.State.LastSpawnTime)
        print("  Current Time: " .. CurTime())
        print("  Time Since Last Spawn: " .. (CurTime() - spawner.State.LastSpawnTime))
        print("  Spawn Interval: " .. spawner.Config.SpawnInterval)
        
        if timer then
            print("  Timer State:")
            print("    Is Intermission: " .. tostring(timer.State.IsIntermission))
            print("    Is Round Active: " .. tostring(timer.State.IsRoundActive))
            print("    Current Round: " .. timer.State.CurrentRound)
        else
            print("  Timer not available")
        end
    else
        print("[BM-DM] Entity spawner not available")
    end
end, nil, "Debug entity spawner state")

-- Visual debug: draw all spawn points and their ground-adjusted positions
concommand.Add("bm_dm_debug_spawns", function(ply)
    if not (BLACKMESA_CORE and BLACKMESA_CORE.EntitySpawner) then
        print("[BM-DM] EntitySpawner not available for debug")
        return
    end
    local spawner = BLACKMESA_CORE.EntitySpawner
    local points = (spawner.Config and spawner.Config.SpawnPoints) or {}

    if SERVER and IsValid(ply) and ply:IsPlayer() then
        net.Start("BM_DM_DebugSpawns")
            net.WriteUInt(#points, 16)
            for i = 1, #points do
                net.WriteVector(points[i])
            end
        net.Send(ply)
        print(string.format("[BM-DM] Sent %d spawn points to %s", #points, ply:Nick()))

        -- Auto-clear the client debug spheres after 30 seconds by sending an empty payload
        local tname = "BM_DM_DebugSpawns_Clear_" .. (ply.SteamID64 and ply:SteamID64() or tostring(ply))
        timer.Remove(tname)
        timer.Create(tname, 10, 1, function()
            if not IsValid(ply) then return end
            net.Start("BM_DM_DebugSpawns")
                net.WriteUInt(0, 16)
            net.Send(ply)
        end)
    else
        print("[BM-DM] bm_dm_debug_spawns must be run by a player on the server")
    end
end, nil, "Visualize BM-DM spawnpoints on client. Usage: bm_dm_debug_spawns")
