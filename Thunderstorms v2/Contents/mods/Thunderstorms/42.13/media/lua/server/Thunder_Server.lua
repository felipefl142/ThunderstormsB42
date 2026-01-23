if isClient() then return end

-- GLOBAL so it can be accessed from Lua console (singleplayer)
ThunderServer = {}

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
    -- Increased range to support far thunder delays
    local distance = forcedDist or ZombRand(50, 2500)
    
    local args = {
        dist = distance,
        azimuth = ZombRand(0, 360)
    }
    sendServerCommand("ThunderMod", "LightningStrike", args)
end

-- 3. LISTEN FOR CLIENT COMMANDS
local function OnClientCommand(module, command, player, args)
    if module ~= "ThunderMod" then return end

    if command == "ForceStrike" then
        local dist = args.dist or 1000
        print("[ThunderServer] ForceStrike requested, dist=" .. tostring(dist))
        ThunderServer.TriggerStrike(dist)

    elseif command == "SetFrequency" then
        local freq = tonumber(args.frequency)
        if freq then
            local oldFreq = ThunderServer.baseChance
            ThunderServer.baseChance = freq
            print("[ThunderServer] Frequency changed: " .. oldFreq .. " -> " .. freq)
        else
            print("[ThunderServer] ERROR: Invalid frequency value: " .. tostring(args.frequency))
        end
    else
        print("[ThunderServer] Unknown command: " .. command)
    end
end

Events.OnTick.Add(ThunderServer.OnTick)
Events.OnClientCommand.Add(OnClientCommand)

-- ============================================================
-- GLOBAL HELPER FUNCTION (for server-side Lua console in SP)
-- ============================================================

--- Directly trigger a strike from server (singleplayer only)
--- Usage: ServerForceThunder(200) or ServerForceThunder()
function ServerForceThunder(dist)
    dist = dist or ZombRand(50, 2500)
    print("[ThunderServer] ServerForceThunder called with dist=" .. tostring(dist))
    ThunderServer.TriggerStrike(dist)
    return true
end

print("[ThunderServer] Console command (SP): ServerForceThunder(dist)")