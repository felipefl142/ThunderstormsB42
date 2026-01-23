if isServer() then return end

print("[ThunderClient] ========== LOADING (Build 42.13) ==========")

-- GLOBAL so it can be accessed from Lua console
ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.10 -- Slower decay for better visibility
ThunderClient.delayedSounds = {}
ThunderClient.flashSequence = {} -- Queue for multi-flash effect
ThunderClient.overlay = nil

-- 1. SETUP THE OVERLAY
-- We create a UI element that acts as our "Flash Screen"
function ThunderClient.CreateOverlay()
    if ThunderClient.overlay then
        print("[ThunderClient] Overlay already exists")
        return
    end

    local w = getCore():getScreenWidth()
    local h = getCore():getScreenHeight()
    print("[ThunderClient] Creating overlay " .. w .. "x" .. h)

    -- Create a simple rectangle element
    ThunderClient.overlay = ISUIElement:new(0, 0, w, h)
    ThunderClient.overlay:initialise()
    -- We want it to ignore mouse clicks
    ThunderClient.overlay:setWantKeyEvents(false)
    ThunderClient.overlay.ignoreMouseEvents = true

    -- Override the render function to draw a white rectangle with variable alpha
    ThunderClient.overlay.prerender = function(self)
        if ThunderClient.flashIntensity > 0 then
            -- drawRect(x, y, w, h, alpha, r, g, b)
            self:drawRect(0, 0, self:getWidth(), self:getHeight(), ThunderClient.flashIntensity, 1, 1, 1)
        end
    end

    -- Add to the global UI manager so it draws on top of the game world
    ThunderClient.overlay:addToUIManager()
    print("[ThunderClient] ✓ Overlay created and added to UI manager")
end

-- 2. HANDLE SERVER COMMANDS
local function OnServerCommand(module, command, args)
    if module == "ThunderMod" and command == "LightningStrike" then
        print("[ThunderClient] ⚡ Received LightningStrike command from server!")
        print("[ThunderClient]   Distance: " .. tostring(args.dist) .. " tiles")
        ThunderClient.DoStrike(args)
    end
end

function ThunderClient.DoStrike(args)
    local distance = args.dist
    print("[ThunderClient] DoStrike executing - dist=" .. tostring(distance))

    -- VISUALS: Set the intensity
    -- Ensure overlay exists
    print("[ThunderClient] Creating overlay...")
    ThunderClient.CreateOverlay()
    print("[ThunderClient] Overlay created/verified")
    
    -- Closer = Brighter (Max 0.5 alpha, Min 0.1)
    local brightness = (1.0 - (distance / 2000)) * 0.5
    if brightness < 0.1 then brightness = 0.1 end
    if brightness > 0.5 then brightness = 0.5 end
    
    -- Queue multi-flash sequence
    ThunderClient.flashSequence = {}
    local numFlashes = ZombRand(1, 4) -- 1, 2, or 3 flashes
    local now = getTimestampMs()
    local cumulativeDelay = 0
    
    for i = 1, numFlashes do
        if i > 1 then
            -- Stuttering timing: 20ms to 70ms between pulses
            cumulativeDelay = cumulativeDelay + ZombRand(20, 71)
        end
        
        table.insert(ThunderClient.flashSequence, {
            start = now + cumulativeDelay,
            intensity = brightness * (ZombRandFloat(0.75, 1.25)) -- Variation +/- 25%
        })
    end

    -- AUDIO: Physics-based delay (Speed of Sound ~340m/s)
    local speed = 340
    local delaySeconds = distance / speed
    local triggerTime = getTimestampMs() + (delaySeconds * 1000)

    -- Select Sound
    local soundName = "MyThunder/ThunderFar"
    if distance < 200 then
        soundName = "MyThunder/ThunderClose"
    elseif distance < 800 then
        soundName = "MyThunder/ThunderMedium"
    end

    -- Queue Sound
    print("[ThunderClient] Queueing sound: " .. soundName .. " in " .. string.format("%.1f", delaySeconds) .. "s")
    print("[ThunderClient] Queuing " .. numFlashes .. " flash(es) with brightness " .. string.format("%.2f", brightness))
    table.insert(ThunderClient.delayedSounds, {
        sound = soundName,
        time = triggerTime
    })
end

-- 3. UPDATER LOOPS
function ThunderClient.OnTick()
    -- Audio Delay Loop (Time-based)
    local now = getTimestampMs()
    for i = #ThunderClient.delayedSounds, 1, -1 do
        local entry = ThunderClient.delayedSounds[i]

        if now >= entry.time then
            print("[ThunderClient] 🔊 Playing sound: " .. entry.sound)
            getSoundManager():PlaySound(entry.sound, false, 1.0)
            table.remove(ThunderClient.delayedSounds, i)
        end
    end
end

function ThunderClient.OnRenderTick()
    -- Process Flash Queue
    local now = getTimestampMs()
    for i = #ThunderClient.flashSequence, 1, -1 do
        local flash = ThunderClient.flashSequence[i]
        if now >= flash.start then
            print("[ThunderClient] ⚡ FLASH! Intensity: " .. string.format("%.2f", flash.intensity))
            ThunderClient.flashIntensity = flash.intensity
            if ThunderClient.flashIntensity > 1.0 then ThunderClient.flashIntensity = 1.0 end
            table.remove(ThunderClient.flashSequence, i)
        end
    end

    -- Flash Decay Loop
    if ThunderClient.flashIntensity > 0 then
        ThunderClient.flashIntensity = ThunderClient.flashIntensity - ThunderClient.flashDecay
        if ThunderClient.flashIntensity < 0 then
            ThunderClient.flashIntensity = 0
        end
    end
end

-- 4. INITIALIZATION
local function OnGameStart()
    print("[ThunderClient] OnGameStart event fired - creating overlay")
    ThunderClient.CreateOverlay()
end

Events.OnGameStart.Add(OnGameStart)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
Events.OnTick.Add(ThunderClient.OnTick)

print("[ThunderClient] ========== CLIENT INITIALIZED ==========")
print("[ThunderClient] Events registered: OnGameStart, OnServerCommand, OnRenderTick, OnTick")

-- ============================================================
-- GLOBAL HELPER FUNCTIONS (for Lua console)
-- ============================================================

--- Force a thunder strike via server (works in SP and MP)
--- Usage: ForceThunder(200) or ForceThunder() for random distance
function ForceThunder(dist)
    dist = dist or ZombRand(50, 2500)
    print("[ThunderClient] ForceThunder called with dist=" .. tostring(dist))

    local player = getPlayer()
    if not player then
        print("[ThunderClient] ERROR: No player found!")
        return false
    end

    print("[ThunderClient] Sending ForceStrike command to server...")
    sendClientCommand(player, "ThunderMod", "ForceStrike", {dist = dist})
    return true
end

--- Test thunder effect directly on client (bypasses server, for debugging)
--- Usage: TestThunder(200) or TestThunder() for default
function TestThunder(dist, azimuth)
    dist = dist or 500
    azimuth = azimuth or ZombRand(0, 360)
    print("[ThunderClient] TestThunder called - DIRECT CLIENT TEST")
    print("[ThunderClient]   dist=" .. tostring(dist) .. ", azimuth=" .. tostring(azimuth))

    ThunderClient.DoStrike({dist = dist, azimuth = azimuth})
    return true
end

--- Set thunder frequency via server
--- Usage: SetThunderFrequency(3.0)
function SetThunderFrequency(freq)
    freq = freq or 1.0
    print("[ThunderClient] SetThunderFrequency called with freq=" .. tostring(freq))

    local player = getPlayer()
    if not player then
        print("[ThunderClient] ERROR: No player found!")
        return false
    end

    sendClientCommand(player, "ThunderMod", "SetFrequency", {frequency = freq})
    return true
end

print("[ThunderClient] Console commands available: ForceThunder(dist), TestThunder(dist), SetThunderFrequency(freq)")
print("[ThunderClient] NOTE: Console runs server-side in singleplayer - use ForceThunder() to test")