if isClient() then return end

local ThunderServer = {}

-- CONFIG
ThunderServer.minClouds = 0.1
ThunderServer.baseChance = 1.0 
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
    if module == "ThunderMod" then
        if command == "ForceStrike" then
            print("ThunderServer: Received ForceStrike command. Dist=" .. tostring(args.dist))
            ThunderServer.TriggerStrike(args.dist)
        elseif command == "SetFrequency" then
            local freq = tonumber(args.frequency)
            if freq then
                ThunderServer.baseChance = freq
                print("ThunderServer: Frequency set to " .. tostring(ThunderServer.baseChance))
            end
        end
    end
end

Events.OnTick.Add(ThunderServer.OnTick)
Events.OnClientCommand.Add(OnClientDebug)