if isClient() then return end

print("[ThunderServer] ========== LOADING ==========")

local ThunderServer = {}
ThunderServer.DEBUG = true

-- CONFIG
ThunderServer.minClouds = 0.2
ThunderServer.baseChance = 1.0
ThunderServer.cooldownTimer = 0
ThunderServer.minCooldown = 60
ThunderServer.strikeCount = 0

local function DebugPrint(msg)
    if ThunderServer.DEBUG then
        print("[ThunderServer] " .. msg)
    end
end

-- 1. WEATHER MONITORING
function ThunderServer.OnTick()
    if ThunderServer.cooldownTimer > 0 then
        ThunderServer.cooldownTimer = ThunderServer.cooldownTimer - 1
        return
    end

    local clim = getClimateManager()
    if not clim then return end

    local clouds = clim:getCloudIntensity()

    if clouds > ThunderServer.minClouds then
        local currentChance = ThunderServer.baseChance * clouds
        local roll = ZombRandFloat(0, 100)

        if roll < currentChance then
            DebugPrint("Weather trigger! clouds=" .. string.format("%.2f", clouds) ..
                       " chance=" .. string.format("%.2f", currentChance) ..
                       " roll=" .. string.format("%.2f", roll))
            ThunderServer.TriggerStrike()
        end
    end
end

-- 2. TRIGGER LOGIC
function ThunderServer.TriggerStrike(forcedDist)
    ThunderServer.strikeCount = ThunderServer.strikeCount + 1

    -- Dynamic Cooldown based on intensity
    local clim = getClimateManager()
    local clouds = clim and clim:getCloudIntensity() or 0.5

    local intensityFactor = (1.1 - clouds)
    if intensityFactor < 0 then intensityFactor = 0 end

    local addedDelay = math.floor(1000 * intensityFactor)
    ThunderServer.cooldownTimer = ThunderServer.minCooldown + ZombRand(0, addedDelay)

    local distance = forcedDist or ZombRand(50, 2500)
    local azimuth = ZombRand(0, 360)

    local args = {
        dist = distance,
        azimuth = azimuth
    }

    DebugPrint("====== STRIKE #" .. ThunderServer.strikeCount .. " ======")
    DebugPrint("  Distance: " .. distance)
    DebugPrint("  Azimuth: " .. azimuth)
    DebugPrint("  Cooldown set to: " .. ThunderServer.cooldownTimer)
    DebugPrint("  Sending LightningStrike to all clients")

    sendServerCommand("ThunderMod", "LightningStrike", args)
end

-- 3. LISTEN FOR CLIENT COMMANDS
local function OnClientCommand(module, command, player, args)
    if module ~= "ThunderMod" then return end

    local playerName = player and player:getUsername() or "Unknown"
    DebugPrint("Received command '" .. command .. "' from player: " .. playerName)

    if command == "ForceStrike" then
        local dist = args.dist or 1000
        DebugPrint("  ForceStrike requested, dist=" .. tostring(dist))
        ThunderServer.TriggerStrike(dist)

    elseif command == "SetFrequency" then
        local freq = tonumber(args.frequency)
        if freq then
            local oldFreq = ThunderServer.baseChance
            ThunderServer.baseChance = freq
            DebugPrint("  Frequency changed: " .. oldFreq .. " -> " .. freq)
        else
            DebugPrint("  ERROR: Invalid frequency value: " .. tostring(args.frequency))
        end
    else
        DebugPrint("  Unknown command: " .. command)
    end
end

Events.OnTick.Add(ThunderServer.OnTick)
Events.OnClientCommand.Add(OnClientCommand)

print("[ThunderServer] ========== LOADED ==========")
print("[ThunderServer] Config: minClouds=" .. ThunderServer.minClouds ..
      " baseChance=" .. ThunderServer.baseChance ..
      " minCooldown=" .. ThunderServer.minCooldown)
