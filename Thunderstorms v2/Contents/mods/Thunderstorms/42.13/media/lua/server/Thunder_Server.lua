print("[ThunderServer] File is being loaded...")

local ThunderMod = require "Thunder_Shared"

print("[ThunderServer] ========== LOADING (Build 42.13) ==========")

-- GLOBAL so it can be accessed from Lua console (singleplayer)
ThunderServer = {}

-- CONFIG
ThunderServer.minClouds = 0.2
ThunderServer.baseChance = 0.02  -- Adjusted chance (0.02% * intensity per tick)
ThunderServer.cooldownTimer = 0
ThunderServer.minCooldown = 600  -- Minimum 10 seconds between strikes to prevent spam

-- 0. CALCULATION HELPERS
function ThunderServer.CalculateStormIntensity()
    local clim = getClimateManager()
    local clouds = clim:getCloudIntensity() or 0
    local rain = clim:getRainIntensity() or 0
    local wind = clim:getWindIntensity() or 0
    local config = ThunderMod.Config.Thunder

    local cloudFactor = math.pow(clouds, config.cloudExponent) * config.cloudWeight
    local rainFactor = math.pow(rain, config.rainExponent) * config.rainWeight
    local windFactor = math.pow(wind, config.windExponent) * config.windWeight
    local synergy = (clouds * rain) * config.synergyWeight

    local intensity = cloudFactor + rainFactor + windFactor + synergy
    if intensity > 1.0 then intensity = 1.0 end
    return intensity
end

function ThunderServer.CalculateThunderProbability(intensity)
    local config = ThunderMod.Config.Thunder
    local exponent = -config.sigmoidSteepness * (intensity - config.sigmoidMidpoint)
    local sigmoid = 1.0 / (1.0 + math.exp(exponent))
    
    return sigmoid * 0.08 * intensity * config.probabilityMultiplier
end

function ThunderServer.CalculateCooldown(intensity)
    local config = ThunderMod.Config.Thunder
    local intensityFactor = math.exp(-config.cooldownDecayRate * intensity)
    
    local minTicks = config.minCooldownSeconds * 60
    local maxTicks = config.maxCooldownSeconds * 60
    local range = maxTicks - minTicks
    
    local baseCooldown = minTicks + (range * intensityFactor)
    local variation = baseCooldown * config.cooldownVariation
    local finalCooldown = baseCooldown + ZombRandFloat(-variation, variation)
    
    return math.max(minTicks, math.floor(finalCooldown))
end

function ThunderServer.CalculateStrikeDistance(intensity)
    local config = ThunderMod.Config.Thunder
    local intensityBias = math.pow(1.0 - intensity, config.distanceBiasPower)
    
    -- Weighted random selection
    local roll = ZombRandFloat(0, 1.0)
    
    if roll > intensityBias then
        -- Intense storm -> Prefer close strikes
        return ZombRand(config.minDistance, config.closeRangeMax)
    elseif roll > (intensityBias * 0.5) then
        -- Medium range
        return ZombRand(config.closeRangeMax, config.mediumRangeMax)
    else
        -- Far range
        return ZombRand(config.mediumRangeMax, config.maxDistance)
    end
end

-- 1. WEATHER MONITORING
function ThunderServer.OnTick()
    -- If Native Mode is enabled, disable custom random generation
    if ThunderMod.Config.UseNativeWeatherEvents then
        return
    end

    if ThunderServer.cooldownTimer > 0 then
        ThunderServer.cooldownTimer = ThunderServer.cooldownTimer - 1
        return
    end

    local stormIntensity = ThunderServer.CalculateStormIntensity()
    
    -- Early exit optimization for very clear weather
    if stormIntensity < 0.01 then return end
        
    local probability = ThunderServer.CalculateThunderProbability(stormIntensity)
    
    if ZombRandFloat(0, 100) < probability then
        ThunderServer.TriggerStrike(nil, stormIntensity)
    end
end

-- 2. TRIGGER LOGIC
function ThunderServer.TriggerStrike(forcedDist, intensity)
    local stormIntensity = intensity or ThunderServer.CalculateStormIntensity()
    
    ThunderServer.cooldownTimer = ThunderServer.CalculateCooldown(stormIntensity)
    
    -- If UI requested specific distance, use it. Otherwise calculate based on intensity.
    local distance = forcedDist or ThunderServer.CalculateStrikeDistance(stormIntensity)

    local args = {
        dist = distance
    }

    print("[ThunderServer] ⚡ LIGHTNING STRIKE ⚡ Distance: " .. distance .. " tiles | Intensity: " .. string.format("%.2f", stormIntensity))
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
            local oldFreq = ThunderMod.Config.Thunder.probabilityMultiplier
            ThunderMod.Config.Thunder.probabilityMultiplier = freq
            print("[ThunderServer] Frequency multiplier changed: " .. oldFreq .. " -> " .. freq)
        else
            print("[ThunderServer] ERROR: Invalid frequency value: " .. tostring(args.frequency))
        end

    elseif command == "SetNativeMode" then
        local enabled = args.enabled
        ThunderMod.Config.UseNativeWeatherEvents = enabled
        print("[ThunderServer] Native Mode set to: " .. tostring(enabled))
        -- Broadcast to all clients so they update their event listeners
        sendServerCommand("ThunderMod", "SetNativeMode", {enabled = enabled})

    else
        print("[ThunderServer] Unknown command: " .. command)
    end
end

function ThunderServer.OnNativeThunder(x, y, bStrike, bLight, bRumble)
    if not ThunderMod.Config.UseNativeWeatherEvents then return end
    
    print("[ThunderServer] Native Thunder caught: strike=" .. tostring(bStrike))
    
    -- Trigger our physics-based thunder based on the native event
    local dist = 1500 -- Default
    if bStrike then dist = ZombRand(50, 600)
    elseif bLight then dist = ZombRand(600, 1500)
    elseif bRumble then dist = ZombRand(1500, 4000) end
    
    ThunderServer.TriggerStrike(dist)
end

if Events.OnThunder then
    Events.OnThunder.Add(ThunderServer.OnNativeThunder)
    print("[ThunderServer] Events.OnThunder registered")
else
    print("[ThunderServer] Events.OnThunder not found (normal on some versions)")
end

Events.OnTick.Add(ThunderServer.OnTick)
Events.OnClientCommand.Add(OnClientCommand)

-- ============================================================
-- GLOBAL HELPER FUNCTION (for server-side Lua console in SP)
-- ============================================================

--- Toggle Native Mode from Server Console
--- Usage: ServerToggleNativeMode(true) or SetNativeMode(true)
function ServerToggleNativeMode(enabled)
    if enabled == nil then enabled = true end
    ThunderMod.Config.UseNativeWeatherEvents = enabled
    print("[ThunderServer] Native Mode set to: " .. tostring(enabled))
    sendServerCommand("ThunderMod", "SetNativeMode", {enabled = enabled})
    return true
end

-- Alias for consistency with client command
SetNativeMode = ServerToggleNativeMode

--- Directly trigger a strike from server (singleplayer only)
--- Usage: ServerForceThunder(200) or ServerForceThunder()
function ServerForceThunder(dist)
    dist = dist or ZombRand(50, 2500)
    print("[ThunderServer] ServerForceThunder called with dist=" .. tostring(dist))
    ThunderServer.TriggerStrike(dist)
    return true
end

--- Test thunder effect (server side)
--- Usage: ServerTestThunder(200)
function ServerTestThunder(dist)
    dist = dist or 500
    print("[ThunderServer] ServerTestThunder called with dist=" .. tostring(dist))
    ThunderServer.TriggerStrike(dist)
    return true
end

--- Set thunder frequency multiplier from console
--- Usage: SetThunderFrequency(2.0) - Double frequency
function SetThunderFrequency(freq)
    freq = freq or 1.0
    local oldFreq = ThunderMod.Config.Thunder.probabilityMultiplier
    ThunderMod.Config.Thunder.probabilityMultiplier = freq
    print("[ThunderServer] Frequency multiplier changed: " .. oldFreq .. " -> " .. freq)
    return true
end

-- Alias
SetThunderMultiplier = SetThunderFrequency

--- Analyze current storm intensity and probability
--- Usage: GetStormIntensity()
function GetStormIntensity()
    local intensity = ThunderServer.CalculateStormIntensity()
    local prob = ThunderServer.CalculateThunderProbability(intensity)
    local cooldown = ThunderServer.CalculateCooldown(intensity)
    local ticksPerStrike = (100 / prob) + cooldown
    local secondsPerStrike = ticksPerStrike / 60
    
    print("[ThunderServer] === STORM ANALYSIS ===")
    print("Intensity: " .. string.format("%.3f", intensity) .. " (0.0 - 1.0)")
    print("Probability/Tick: " .. string.format("%.4f", prob) .. "%")
    print("Est. Frequency: One strike every ~" .. string.format("%.1f", secondsPerStrike) .. " seconds")
    print("Current Cooldown Setting: " .. math.floor(cooldown/60) .. "s")
    print("================================")
end

--- Force thunder strike from console
--- Usage: ForceThunder(200) or ForceThunder() or ServerForceThunder(200)
function ServerForceThunder(dist)
    dist = dist or ThunderServer.CalculateStrikeDistance(ThunderServer.CalculateStormIntensity())
    print("[ThunderServer] ServerForceThunder called with dist=" .. tostring(dist))
    ThunderServer.TriggerStrike(dist)
    return true
end

-- Compatibility alias
ForceThunderServer = ServerForceThunder

-- Only define generic ForceThunder on Dedicated Server (where no client exists)
if isServer() and not isClient() then
    ForceThunder = ServerForceThunder
    TestThunder = function(dist) return ThunderServer.TriggerStrike(dist or 500) end
end

print("[ThunderServer] ========== LOADED (Build 42.13) ==========")
print("[ThunderServer] Server commands: ServerForceThunder(dist), SetThunderFrequency(mult), GetStormIntensity()")
print("[ThunderServer] Note: Use ForceThunder(dist) from client/player console")