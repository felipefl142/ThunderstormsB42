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
ThunderClient.activeLightSources = {} -- Track temporary light sources
ThunderClient.useLighting = true -- Enable/disable dynamic lighting
ThunderClient.useIndoorDetection = true -- Enable/disable indoor/outdoor sound modification

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

-- Helper function to check if player is indoors
function ThunderClient.IsPlayerIndoors()
    local player = getPlayer()
    if not player then return false end

    local square = player:getCurrentSquare()
    if not square then return false end

    -- Check if player is in a room
    local room = square:getRoom()
    if room then
        if ThunderClient.debugMode then
            print("[ThunderClient] Player is in room: " .. tostring(room:getName()))
        end
        return true
    end

    return false
end

-- Create temporary light sources for lightning flash
function ThunderClient.CreateLightningFlash(intensity, duration)
    if not ThunderClient.useLighting then return end

    local player = getPlayer()
    if not player then return end

    local square = player:getCurrentSquare()
    if not square then return end

    local cell = getCell()
    if not cell then return end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    -- Lightning is white/blue-white
    local r = 0.9 + (ZombRandFloat(0, 0.1))
    local g = 0.9 + (ZombRandFloat(0, 0.1))
    local b = 1.0

    -- Radius based on intensity (brighter = larger area)
    local radius = math.floor(10 + (intensity * 40)) -- 10-30 tile radius

    if ThunderClient.debugMode then
        print("[ThunderClient] Creating lightning light at (" .. x .. ", " .. y .. ", " .. z .. ") radius: " .. radius .. " intensity: " .. string.format("%.2f", intensity))
    end

    -- Create main light source at player position
    local lightSource = cell:addLamppost(x, y, z, r, g, b, radius)
    if lightSource then
        table.insert(ThunderClient.activeLightSources, {
            light = lightSource,
            endTime = getTimestampMs() + (duration * 1000),
            x = x,
            y = y,
            z = z
        })
    end

    -- Create additional light sources in a pattern to simulate light entering through windows/doors
    -- Only if player is indoors - light should come from multiple angles
    if ThunderClient.IsPlayerIndoors() then
        local offsets = {
            {dx = 5, dy = 0},   -- East
            {dx = -5, dy = 0},  -- West
            {dx = 0, dy = 5},   -- South
            {dx = 0, dy = -5},  -- North
            {dx = 3, dy = 3},   -- SE
            {dx = -3, dy = 3},  -- SW
            {dx = 3, dy = -3},  -- NE
            {dx = -3, dy = -3}  -- NW
        }

        for _, offset in ipairs(offsets) do
            local offsetX = x + offset.dx
            local offsetY = y + offset.dy
            local offsetSquare = cell:getGridSquare(offsetX, offsetY, z)

            if offsetSquare then
                -- Smaller radius for ambient light sources
                local ambientRadius = math.floor(radius * 0.6)
                local ambientLight = cell:addLamppost(offsetX, offsetY, z, r * 0.8, g * 0.8, b * 0.9, ambientRadius)
                if ambientLight then
                    table.insert(ThunderClient.activeLightSources, {
                        light = ambientLight,
                        endTime = getTimestampMs() + (duration * 1000),
                        x = offsetX,
                        y = offsetY,
                        z = z
                    })
                end
            end
        end

        if ThunderClient.debugMode then
            print("[ThunderClient] Created " .. #offsets .. " ambient light sources for indoor illumination")
        end
    end
end

-- Clean up expired light sources
function ThunderClient.CleanupLights()
    local now = getTimestampMs()
    local cell = getCell()
    if not cell then return end

    for i = #ThunderClient.activeLightSources, 1, -1 do
        local entry = ThunderClient.activeLightSources[i]
        if now >= entry.endTime then
            -- Remove the light source
            if entry.light then
                cell:removeLamppost(entry.light)
                if ThunderClient.debugMode then
                    print("[ThunderClient] Removed light source at (" .. entry.x .. ", " .. entry.y .. ", " .. entry.z .. ")")
                end
            end
            table.remove(ThunderClient.activeLightSources, i)
        end
    end
end

-- 2. HANDLE SERVER COMMANDS
local function OnServerCommand(module, command, args)
    -- Debug: log ALL server commands when debug mode is on
    if ThunderClient.debugMode then
        print("[ThunderClient] OnServerCommand called: module=" .. tostring(module) .. ", command=" .. tostring(command))
    end

    if module == "ThunderMod" then
        if command == "LightningStrike" then
            if ThunderClient.debugMode then
                print("[ThunderClient] ⚡ Received LightningStrike from server (distance: " .. tostring(args.dist) .. " tiles)")
            end
            ThunderClient.DoStrike(args)

        elseif command == "SetNativeMode" then
            local enabled = args.enabled
            ThunderMod.Config.UseNativeWeatherEvents = enabled
            print("[ThunderClient] Native Mode synced: " .. tostring(enabled))
        else
            if ThunderClient.debugMode then
                print("[ThunderClient] Unknown ThunderMod command: " .. tostring(command))
            end
        end
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
    -- Flash pattern: 25% single, 50% double, 25% triple flash
    local numFlashes = 1
    local roll = ZombRand(100)

    if roll < 25 then
        numFlashes = 1  -- 25% chance: single flash
    elseif roll < 75 then
        numFlashes = 2  -- 50% chance: double flash
    else
        numFlashes = 3  -- 25% chance: triple flash
    end

    local now = getTimestampMs()
    local cumulativeDelay = 0

    for i = 1, numFlashes do
        if i > 1 then
            -- Fast, equally spaced flashes (40-100ms)
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

    -- Check if player is indoors and reduce volume accordingly
    local indoorModifier = 1.0
    if ThunderClient.useIndoorDetection and ThunderClient.IsPlayerIndoors() then
        -- Indoor sound is muffled (reduce volume by 10-25% depending on distance)
        -- Closer thunder is more muffled indoors
        indoorModifier = 0.75 + (distance / 8000) * 0.15 -- 0.75 to 0.9 range
        if ThunderClient.debugMode then
            print("[ThunderClient] Player is indoors, applying volume modifier: " .. string.format("%.2f", indoorModifier))
        end
    end

    volume = volume * indoorModifier

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

            -- Create lightning light sources
            ThunderClient.CreateLightningFlash(flash.intensity, 0.4) -- 400ms duration

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

    -- Clean up expired light sources
    ThunderClient.CleanupLights()
end

-- 4. INITIALIZATION
local function OnGameStart()
    print("[ThunderClient] OnGameStart event fired - overlay will be created on first thunder strike")
    -- Don't create overlay yet, it will be created on demand in DoStrike
end

if Events.OnGameStart then
    Events.OnGameStart.Add(OnGameStart)
    print("[ThunderClient] Registered OnGameStart")
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(OnServerCommand)
    print("[ThunderClient] Registered OnServerCommand")
else
    print("[ThunderClient] WARNING: Events.OnServerCommand is not available!")
end

if Events.OnRenderTick then
    Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
    print("[ThunderClient] Registered OnRenderTick")
end

if Events.OnTick then
    Events.OnTick.Add(ThunderClient.OnTick)
    print("[ThunderClient] Registered OnTick")
end

if Events.OnThunder then
    Events.OnThunder.Add(ThunderClient.OnNativeThunder)
    print("[ThunderClient] Registered OnThunder (Native Mode support)")
else
    print("[ThunderClient] WARNING: Events.OnThunder is not available in this version of Project Zomboid.")
end

print("[ThunderClient] ========== CLIENT INITIALIZED ==========")
print("[ThunderClient] Events registered successfully (where available)")

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
--- Usage: TestThunderClient(200) or TestThunderClient() for default
--- This function is client-only and avoids server/client naming conflicts
function TestThunderClient(dist)
    dist = dist or 500
    print("[ThunderClient] Testing thunder effect at " .. tostring(dist) .. " tiles (client-side, direct)")

    ThunderClient.DoStrike({dist = dist})
    return true
end

--- Test thunder effect directly on client (bypasses server, for debugging)
--- Usage: TestThunder(200) or TestThunder() for default
--- NOTE: In single player, this may conflict with server's TestThunder. Use TestThunderClient() instead.
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

--- Enable/Disable Native Mode (Sync with game weather)
--- Usage: SetNativeMode(true) or SetNativeMode(false)
function SetNativeMode(enabled)
    if enabled == nil then enabled = true end
    print("[ThunderClient] Requesting Native Mode: " .. tostring(enabled))

    local player = getPlayer()
    if player then
        sendClientCommand(player, "ThunderMod", "SetNativeMode", {enabled = enabled})
    else
        print("[ThunderClient] Error: No player found")
    end
    return enabled
end

--- Toggle dynamic lighting effects
--- Usage: ThunderToggleLighting(true/false) or ThunderToggleLighting() to toggle
function ThunderToggleLighting(enable)
    if enable == nil then
        ThunderClient.useLighting = not ThunderClient.useLighting
    else
        ThunderClient.useLighting = enable
    end
    print("[ThunderClient] Dynamic lighting: " .. (ThunderClient.useLighting and "ENABLED" or "DISABLED"))
    return ThunderClient.useLighting
end

--- Toggle indoor/outdoor detection
--- Usage: ThunderToggleIndoorDetection(true/false) or ThunderToggleIndoorDetection() to toggle
function ThunderToggleIndoorDetection(enable)
    if enable == nil then
        ThunderClient.useIndoorDetection = not ThunderClient.useIndoorDetection
    else
        ThunderClient.useIndoorDetection = enable
    end
    print("[ThunderClient] Indoor detection: " .. (ThunderClient.useIndoorDetection and "ENABLED" or "DISABLED"))
    return ThunderClient.useIndoorDetection
end

print("[ThunderClient] Console commands:")
print("  ForceThunder(dist)        - Trigger thunder at distance (via server)")
print("  TestThunder(dist)         - Test thunder effect (may call server in SP)")
print("  TestThunderClient(dist)   - Test thunder effect (client-only, guaranteed)")
print("  SetThunderFrequency(f)    - Set frequency multiplier")
print("  SetNativeMode(bool)       - Toggle Native Mode (sync with game weather)")
print("  ThunderToggleDebug(true/false) - Toggle debug logging")
print("  ThunderToggleLighting(true/false) - Toggle dynamic lighting effects")
print("  ThunderToggleIndoorDetection(true/false) - Toggle indoor sound muffling")