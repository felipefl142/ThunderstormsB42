if isClient() then return end

local ThunderServer = {}

-- CONFIG
ThunderServer.minClouds = 0.2
ThunderServer.baseChance = 1.0 
ThunderServer.cooldownTimer = 0
ThunderServer.minCooldown = 60

-- 1. WEATHER MONITORING
function ThunderServer.OnTick()
    if ThunderServer.cooldownTimer > 0 then
        ThunderServer.cooldownTimer = ThunderServer.cooldownTimer - 1
        return
    end

    local clim = getClimateManager()
    local clouds = clim:getCloudIntensity()
    
    if clouds > ThunderServer.minClouds then
        -- Simple chance per tick if cooldown is 0
        -- With baseChance=1.0 and clouds=0.2, chance is 0.2% per tick (roughly every 8 sec)
        -- With clouds=1.0, chance is 1% per tick (roughly every 1.5 sec)
        local currentChance = ThunderServer.baseChance * clouds
        
        if ZombRandFloat(0, 100) < currentChance then
            ThunderServer.TriggerStrike()
        end
    end
end

-- 2. TRIGGER LOGIC
function ThunderServer.TriggerStrike(forcedDist)
    -- Dynamic Cooldown based on intensity
    local clim = getClimateManager()
    local clouds = clim:getCloudIntensity()
    
    -- Invert clouds: 1.0 -> 0.0, 0.2 -> 0.8
    -- High intensity (1.0) -> Cooldown ~ 60 + rand(0) -> 60 ticks
    -- Low intensity (0.2) -> Cooldown ~ 60 + rand(800) -> up to 14s
    local intensityFactor = (1.1 - clouds)
    if intensityFactor < 0 then intensityFactor = 0 end
    
    local addedDelay = math.floor(1000 * intensityFactor)
    ThunderServer.cooldownTimer = ThunderServer.minCooldown + ZombRand(0, addedDelay)

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