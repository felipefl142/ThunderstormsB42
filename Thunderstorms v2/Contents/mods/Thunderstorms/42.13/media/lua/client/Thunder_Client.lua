print("[ThunderClient] File is being loaded...")

require "ISUI/ISUIElement"
local ThunderMod = require "Thunder_Shared"

print("[ThunderClient] ========== LOADING (Build 42.13) ==========")

-- GLOBAL so it can be accessed from Lua console
ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecayRate = 2.5 -- Alpha units per second (time-based, not frame-based)
ThunderClient.lastUpdateTime = 0
ThunderClient.delayedSounds = {}
ThunderClient.flashSequence = {} -- Queue for multi-flash effect
ThunderClient.overlay = nil
ThunderClient.debugMode = false -- Set to true for detailed logging

-- 1. SETUP THE OVERLAY
-- We create a UI element that acts as our "Flash Screen"
function ThunderClient.CreateOverlay()
    if ThunderClient.overlay then
        return -- Overlay already exists
    end

    local w = getCore():getScreenWidth()
    local h = getCore():getScreenHeight()

    if ThunderClient.debugMode then
        print("[ThunderClient] Creating flash overlay " .. w .. "x" .. h)
    end

    -- Create a simple rectangle element
    ThunderClient.overlay = ISUIElement:new(0, 0, w, h)
    ThunderClient.overlay:initialise()
    ThunderClient.overlay:setAlwaysOnTop(true)
    ThunderClient.overlay.followGameWorld = false

    -- We want it to ignore mouse clicks and key events
    ThunderClient.overlay.ignoreMouseEvents = true
    ThunderClient.overlay.ignoreKeyEvents = true

    -- Override the render function to draw a white rectangle with variable alpha
    ThunderClient.overlay.render = function(self)
        ISUIElement.render(self)
        if ThunderClient.flashIntensity > 0 then
            -- drawRect(x, y, w, h, alpha, r, g, b)
            self:drawRect(0, 0, self:getWidth(), self:getHeight(), ThunderClient.flashIntensity, 1, 1, 1)
        end
    end

    -- Don't add to UI manager yet - we'll add/remove it dynamically
    ThunderClient.overlay.isInUIManager = false
end

-- 2. HANDLE SERVER COMMANDS
local function OnServerCommand(module, command, args)
    if module == "ThunderMod" and command == "LightningStrike" then
        if ThunderClient.debugMode then
            print("[ThunderClient] ⚡ Received LightningStrike from server (distance: " .. tostring(args.dist) .. " tiles)")
        end
        ThunderClient.DoStrike(args)
    end
end

-- 3. HANDLE NATIVE GAME EVENTS
function ThunderClient.OnNativeThunder(x, y, doStrike, doLight, doRumble)
    -- Only act if Native Mode is enabled in config
    if not ThunderMod.Config.UseNativeWeatherEvents then
        return
    end

    if ThunderClient.debugMode then
        print("[ThunderClient] Native Thunder Event: strike=" .. tostring(doStrike) .. ", light=" .. tostring(doLight) .. ", rumble=" .. tostring(doRumble))
    end

    local dist = 2000 -- Default to far

    if doStrike then
        -- Close thunder (Lightning Strike)
        dist = ZombRand(50, 600)
    elseif doRumble then
        -- Far thunder (Rumble)
        dist = ZombRand(1500, 5000)
    elseif doLight then
        -- Just light? Treat as medium-far
        dist = ZombRand(800, 2500)
    else
        -- Event fired but no flags?
        return
    end

    ThunderClient.DoStrike({dist = dist})
end

function ThunderClient.DoStrike(args)
    local distance = args.dist

    -- Maximum hearing distance is 8000 tiles
    if distance > 8000 then
        if ThunderClient.debugMode then
            print("[ThunderClient] Thunder too far away (>" .. distance .. " tiles)")
        end
        return
    end

    -- VISUALS: Ensure overlay exists
    ThunderClient.CreateOverlay()

    -- Closer = Brighter (Max 0.5 alpha, Min 0.1)
    local brightness = (1.0 - (distance / 4700)) * 0.5
    if brightness < 0.1 then brightness = 0.1 end
    if brightness > 0.5 then brightness = 0.5 end

    -- Queue multi-flash sequence
    -- Simplified pattern: Mostly single flashes, occasional double flash
    local numFlashes = 1
    if ZombRand(100) < 30 then numFlashes = 2 end -- 30% chance of double flash

    local now = getTimestampMs()
    local cumulativeDelay = 0

    for i = 1, numFlashes do
        if i > 1 then
            -- Longer gap between pulses for "double strike" feel (40-100ms)
            cumulativeDelay = cumulativeDelay + ZombRand(40, 101)
        end

        table.insert(ThunderClient.flashSequence, {
            start = now + cumulativeDelay,
            intensity = brightness * (ZombRandFloat(0.9, 1.1)) -- Slight intensity variation
        })
    end

    -- AUDIO: Physics-based delay (Speed of Sound ~340m/s)
    local speed = 340
    local delaySeconds = distance / speed
    local triggerTime = getTimestampMs() + (delaySeconds * 1000)

    -- Select Sound based on distance
    local soundName = "MyThunder/ThunderFar"
    if distance < 200 then
        soundName = "MyThunder/ThunderClose"
    elseif distance < 800 then
        soundName = "MyThunder/ThunderMedium"
    end

    -- Calculate dynamic volume based on distance
    -- Volume: 1.0 at 0 tiles, 0.1 at 8000 tiles
    local volume = 1.0 - (distance / 8000) * 0.9
    if volume < 0.1 then volume = 0.1 end
    if volume > 1.0 then volume = 1.0 end

    if ThunderClient.debugMode then
        print("[ThunderClient] ⚡ Thunder strike at " .. distance .. " tiles: " .. numFlashes .. " flash(es), sound in " .. string.format("%.1f", delaySeconds) .. "s")
    end

    -- Queue Sound with dynamic volume
    table.insert(ThunderClient.delayedSounds, {
        sound = soundName,
        time = triggerTime,
        volume = volume
    })
end

-- 3. UPDATER LOOPS
function ThunderClient.OnTick()
    -- Audio Delay Loop (Time-based)
    local now = getTimestampMs()
    for i = #ThunderClient.delayedSounds, 1, -1 do
        local entry = ThunderClient.delayedSounds[i]

        if now >= entry.time then
            print("[ThunderClient] 🔊 Playing thunder sound: " .. entry.sound .. " (volume: " .. string.format("%.2f", entry.volume) .. ")")

            -- Play 3D ambient sound
            local player = getPlayer()
            if player then
                -- For thunder, we want it heard from everywhere but still affected by environment
                -- PlayWorldSound(soundName, square, loopDelay, volume, radius, useBaricade)
                -- Use a very large radius for thunder (since it's heard from far away)
                local square = player:getSquare()
                if square then
                    getSoundManager():PlayWorldSound(entry.sound, square, 0, entry.volume, 1000, false)
                else
                    -- Fallback if no square
                    getSoundManager():PlaySound(entry.sound, false, entry.volume)
                end
            else
                -- Fallback to 2D sound if no player (shouldn't happen in-game)
                getSoundManager():PlaySound(entry.sound, false, entry.volume)
            end

            table.remove(ThunderClient.delayedSounds, i)
        end
    end
end

function ThunderClient.OnRenderTick()
    local now = getTimestampMs()

    -- Calculate delta time for consistent decay across different framerates
    if ThunderClient.lastUpdateTime == 0 then
        ThunderClient.lastUpdateTime = now
    end
    local deltaTime = (now - ThunderClient.lastUpdateTime) / 1000.0 -- Convert to seconds
    ThunderClient.lastUpdateTime = now

    -- Cap delta time to prevent huge jumps
    if deltaTime > 0.1 then deltaTime = 0.1 end

    -- Process Flash Queue
    for i = #ThunderClient.flashSequence, 1, -1 do
        local flash = ThunderClient.flashSequence[i]
        if now >= flash.start then
            if ThunderClient.debugMode then
                print("[ThunderClient] ⚡ FLASH! Intensity: " .. string.format("%.2f", flash.intensity))
            end

            -- Set new flash intensity (additive for overlapping flashes)
            ThunderClient.flashIntensity = math.min(ThunderClient.flashIntensity + flash.intensity, 1.0)

            -- Add overlay to UI when flash starts
            if ThunderClient.overlay and not ThunderClient.overlay.isInUIManager then
                if ThunderClient.debugMode then
                    print("[ThunderClient] Adding overlay to UI manager")
                end
                ThunderClient.overlay:addToUIManager()
                ThunderClient.overlay.isInUIManager = true
            end

            table.remove(ThunderClient.flashSequence, i)
        end
    end

    -- Time-based Flash Decay (smooth and consistent across all framerates)
    if ThunderClient.flashIntensity > 0 then
        ThunderClient.flashIntensity = ThunderClient.flashIntensity - (ThunderClient.flashDecayRate * deltaTime)

        if ThunderClient.flashIntensity <= 0 then
            ThunderClient.flashIntensity = 0

            -- Remove overlay from UI when flash ends
            if ThunderClient.overlay and ThunderClient.overlay.isInUIManager then
                if ThunderClient.debugMode then
                    print("[ThunderClient] Removing overlay from UI manager")
                end
                ThunderClient.overlay:removeFromUIManager()
                ThunderClient.overlay.isInUIManager = false
            end
        end
    end
end

-- 4. INITIALIZATION
local function OnGameStart()
    print("[ThunderClient] OnGameStart event fired - overlay will be created on first thunder strike")
    -- Don't create overlay yet, it will be created on demand in DoStrike
end

Events.OnGameStart.Add(OnGameStart)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
Events.OnTick.Add(ThunderClient.OnTick)
Events.OnThunder.Add(ThunderClient.OnNativeThunder)

print("[ThunderClient] ========== CLIENT INITIALIZED ==========")
print("[ThunderClient] Events registered: OnGameStart, OnServerCommand, OnRenderTick, OnTick, OnThunder")

-- ============================================================
-- GLOBAL HELPER FUNCTIONS (for Lua console)
-- ============================================================

--- Force a thunder strike via server (works in SP and MP)
--- Usage: ForceThunder(200) or ForceThunder() for random distance
function ForceThunder(dist)
    dist = dist or ZombRand(50, 2500)
    print("[ThunderClient] Forcing thunder strike at " .. tostring(dist) .. " tiles")

    local player = getPlayer()
    if not player then
        print("[ThunderClient] ERROR: No player found!")
        return false
    end

    sendClientCommand(player, "ThunderMod", "ForceStrike", {dist = dist})
    return true
end

--- Test thunder effect directly on client (bypasses server, for debugging)
--- Usage: TestThunder(200) or TestThunder() for default
function TestThunder(dist)
    dist = dist or 500
    print("[ThunderClient] Testing thunder effect at " .. tostring(dist) .. " tiles (client-side)")

    ThunderClient.DoStrike({dist = dist})
    return true
end

--- Set thunder frequency via server
--- Usage: SetThunderFrequency(3.0)
function SetThunderFrequency(freq)
    freq = freq or 1.0
    print("[ThunderClient] Setting thunder frequency to " .. tostring(freq))

    local player = getPlayer()
    if not player then
        print("[ThunderClient] ERROR: No player found!")
        return false
    end

    sendClientCommand(player, "ThunderMod", "SetFrequency", {frequency = freq})
    return true
end

--- Toggle debug logging
--- Usage: ThunderToggleDebug(true) or ThunderToggleDebug(false) or ThunderToggleDebug() to toggle
function ThunderToggleDebug(enable)
    if enable == nil then
        ThunderClient.debugMode = not ThunderClient.debugMode
    else
        ThunderClient.debugMode = enable
    end
    print("[ThunderClient] Debug mode: " .. (ThunderClient.debugMode and "ENABLED" or "DISABLED"))
    return ThunderClient.debugMode
end

print("[ThunderClient] Console commands:")
print("  ForceThunder(dist)     - Trigger thunder at distance (via server)")
print("  TestThunder(dist)      - Test thunder effect (client-side)")
print("  SetThunderFrequency(f) - Set frequency multiplier")
print("  ThunderToggleDebug(true/false) - Toggle debug logging")