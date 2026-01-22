if isClient() then return end -- Guard: Only run on Server

local ThunderServer = {}

-- CONFIGURATION
ThunderServer.minClouds = 0.4 -- 0.0 to 1.0. Lower triggers "before" storm earlier.
ThunderServer.baseChance = 0.005 -- Chance per tick to strike.
ThunderServer.cooldownTimer = 0
ThunderServer.minCooldown = 200 -- Minimum ticks between strikes (prevent spam)

function ThunderServer.OnTick()
    -- Decrease cooldown
    if ThunderServer.cooldownTimer > 0 then
        ThunderServer.cooldownTimer = ThunderServer.cooldownTimer - 1
        return
    end

    local clim = getClimateManager()
    
    -- We use CloudIntensity to detect "Before" and "After" storm phases
    local clouds = clim:getCloudIntensity()
    local rain = clim:getRainIntensity()
    
    -- If clouds are heavy enough, we risk a lightning strike
    if clouds > ThunderServer.minClouds then
        
        -- Dynamic Probability: More clouds/rain = Higher chance
        local currentChance = ThunderServer.baseChance * (clouds * 2) + (rain * 0.5)
        
        if ZombRandFloat(0, 100) < currentChance then
            ThunderServer.TriggerStrike()
        end
    end
end

function ThunderServer.TriggerStrike()
    -- Reset cooldown
    ThunderServer.cooldownTimer = ZombRand(ThunderServer.minCooldown, ThunderServer.minCooldown * 2)

    -- Calculate a random position offset relative to players? 
    -- For simplicity in MP, we make it a "Global Event" packet, 
    -- and let the client decide how loud it is based on camera, 
    -- or we can send coordinates if we want localized strikes.
    
    -- Let's randomize the "Distance" to change sound/flash intensity
    local distance = ZombRand(0, 1000) -- 0 is on top of you, 1000 is far away
    
    local args = {
        dist = distance,
        azimuth = ZombRand(0, 360) -- Direction of sound
    }
    
    -- Send command to all connected clients
    sendServerCommand("ThunderMod", "LightningStrike", args)
end

Events.OnTick.Add(ThunderServer.OnTick)
