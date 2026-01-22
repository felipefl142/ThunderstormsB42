if isClient() then return end

local ThunderServer = {}

-- CONFIG
ThunderServer.minClouds = 0.4
ThunderServer.baseChance = 0.005
ThunderServer.cooldownTimer = 0
ThunderServer.minCooldown = 200

-- 1. WEATHER MONITORING
function ThunderServer.OnTick()
    if ThunderServer.cooldownTimer > 0 then
        ThunderServer.cooldownTimer = ThunderServer.cooldownTimer - 1
        return
    end

    local clim = getClimateManager()
    local clouds = clim:getCloudIntensity()
    local rain = clim:getRainIntensity()
    
    if clouds > ThunderServer.minClouds then
        local currentChance = ThunderServer.baseChance * (clouds * 2) + (rain * 0.5)
        if ZombRandFloat(0, 100) < currentChance then
            ThunderServer.TriggerStrike()
        end
    end
end

-- 2. TRIGGER LOGIC
function ThunderServer.TriggerStrike(forcedDist)
    ThunderServer.cooldownTimer = ZombRand(ThunderServer.minCooldown, ThunderServer.minCooldown * 2)

    -- If UI requested specific distance, use it. Otherwise random.
    -- Increased max distance to 3000 to utilize 'Far' sounds
    local distance = forcedDist or ZombRand(50, 2500)
    
    local args = {
        dist = distance,
        azimuth = ZombRand(0, 360)
    }
    sendServerCommand("ThunderMod", "LightningStrike", args)
end

-- 3. LISTEN FOR CLIENT DEBUG BUTTON
local function OnClientDebug(module, command, player, args)
    if module == "ThunderMod" and command == "ForceStrike" then
        print("ThunderServer: Received ForceStrike command. Dist=" .. tostring(args.dist))
        -- Only allow Admins to force storms
        -- Commented out for testing/debugging
        -- if isClient() and not (player:getAccessLevel() == "Admin" or player:getAccessLevel() == "Debug") then
        --     print("ThunderMod: Unauthorized debug attempt.")
        --     return
        -- end
        
        -- Trigger the strike with the requested distance
        ThunderServer.TriggerStrike(args.dist)
    end
end

Events.OnTick.Add(ThunderServer.OnTick)
Events.OnClientCommand.Add(OnClientDebug)