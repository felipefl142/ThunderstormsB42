if isClient() then return end

print("[ThunderServer] ========== LOADING (Build 42.13) ==========")

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
    -- Increased range to support far thunder delays (max 3400 tiles for hearing)
    local distance = forcedDist or ZombRand(50, 3400)

    local args = {
        dist = distance
    }

    print("[ThunderServer] ⚡ LIGHTNING STRIKE ⚡ Distance: " .. distance .. " tiles")
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

--- Test thunder effect (console-accessible version)
--- Usage: TestThunder(200) or TestThunder() for default distance
function TestThunder(dist)
    dist = dist or 500
    print("[ThunderServer] TestThunder called with dist=" .. tostring(dist))
    ThunderServer.TriggerStrike(dist)
    return true
end

--- Set thunder frequency from console
--- Usage: SetThunderFrequency(3.0)
function SetThunderFrequency(freq)
    freq = freq or 1.0
    local oldFreq = ThunderServer.baseChance
    ThunderServer.baseChance = freq
    print("[ThunderServer] Frequency changed: " .. oldFreq .. " -> " .. freq)
    return true
end

--- Force thunder strike from console
--- Usage: ForceThunder(200) or ForceThunder() for random distance
function ForceThunder(dist)
    dist = dist or ZombRand(50, 2500)
    print("[ThunderServer] ForceThunder called with dist=" .. tostring(dist))
    ThunderServer.TriggerStrike(dist)
    return true
end

print("[ThunderServer] ========== LOADED (Build 42.13) ==========")
print("[ThunderServer] Console commands: ForceThunder(dist), TestThunder(dist), SetThunderFrequency(freq)")
print("[ThunderServer] Type any of these commands in the console to test thunder effects")