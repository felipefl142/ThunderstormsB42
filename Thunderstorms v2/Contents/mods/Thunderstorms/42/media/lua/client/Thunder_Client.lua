if isServer() then return end

print("[ThunderClient] ========== LOADING ==========")

-- Ensure we have the shared config
if not ThunderMod then
    print("[ThunderClient] WARNING: ThunderMod global not found! Creating default config.")
    ThunderMod = {}
    ThunderMod.Config = { SpeedOfSound = 340 }
else
    print("[ThunderClient] ThunderMod global found.")
end

local ThunderClient = {}
ThunderClient.DEBUG = true -- Set to false to disable debug messages
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.05
ThunderClient.pendingSounds = {}
ThunderClient.overlay = nil
ThunderClient.strikeCount = 0 -- Track total strikes received

local function DebugPrint(msg)
    if ThunderClient.DEBUG then
        print("[ThunderClient] " .. msg)
    end
end

-- 1. VISUALS: OVERLAY
function ThunderClient.CreateOverlay()
    if ThunderClient.overlay then
        DebugPrint("Overlay already exists")
        return
    end

    local w = getCore():getScreenWidth()
    local h = getCore():getScreenHeight()

    DebugPrint("Creating overlay: " .. w .. "x" .. h)

    ThunderClient.overlay = ISUIElement:new(0, 0, w, h)
    ThunderClient.overlay:initialise()
    ThunderClient.overlay:setWantKeyEvents(false)
    ThunderClient.overlay:setMouseOver(false)

    ThunderClient.overlay.prerender = function(self)
        if ThunderClient.flashIntensity > 0 then
            self:drawRect(0, 0, self:getWidth(), self:getHeight(), ThunderClient.flashIntensity, 1, 1, 1)
        end
    end

    ThunderClient.overlay:addToUIManager()
    DebugPrint("Overlay created and added to UI manager")
end

-- 2. AUDIO & LOGIC
function ThunderClient.DoStrike(args)
    ThunderClient.strikeCount = ThunderClient.strikeCount + 1

    local distance = args.dist or 100
    local azimuth = args.azimuth or 0

    DebugPrint("====== STRIKE #" .. ThunderClient.strikeCount .. " ======")
    DebugPrint("  Distance: " .. distance)
    DebugPrint("  Azimuth: " .. azimuth)

    -- A. VISUALS
    ThunderClient.CreateOverlay()

    -- Calculate brightness based on distance
    local brightness = 1.0 - (distance / 2000)
    brightness = math.max(0.1, math.min(1.0, brightness))

    ThunderClient.flashIntensity = brightness
    DebugPrint("  Flash brightness: " .. string.format("%.2f", brightness))

    -- B. AUDIO DELAY CALCULATION
    local speed = ThunderMod.Config.SpeedOfSound or 340
    local delaySeconds = distance / speed
    local triggerTime = getTimestampMs() + (delaySeconds * 1000)

    DebugPrint("  Sound delay: " .. string.format("%.2f", delaySeconds) .. "s")

    -- C. POSITION CALCULATION (Polar to Cartesian relative to player)
    local player = getPlayer()
    if not player then
        DebugPrint("  ERROR: No player found!")
        return
    end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local rad = math.rad(azimuth)

    local soundX = px + (math.cos(rad) * distance)
    local soundY = py + (math.sin(rad) * distance)

    DebugPrint("  Player pos: " .. string.format("%.1f, %.1f, %.1f", px, py, pz))
    DebugPrint("  Sound pos: " .. string.format("%.1f, %.1f", soundX, soundY))

    -- D. SELECT SOUND CATEGORY
    local soundName = "MyThunder/ThunderFar"
    if distance < 800 then
        soundName = "MyThunder/ThunderClose"
    elseif distance < 1500 then
        soundName = "MyThunder/ThunderMedium"
    end

    DebugPrint("  Sound: " .. soundName)

    -- E. QUEUE SOUND
    table.insert(ThunderClient.pendingSounds, {
        sound = soundName,
        x = soundX,
        y = soundY,
        z = pz,
        time = triggerTime,
        id = ThunderClient.strikeCount
    })

    DebugPrint("  Queued sound, pending count: " .. #ThunderClient.pendingSounds)
end

-- 3. LOOPS
function ThunderClient.OnTick()
    local now = getTimestampMs()

    for i = #ThunderClient.pendingSounds, 1, -1 do
        local task = ThunderClient.pendingSounds[i]

        if now >= task.time then
            DebugPrint("Playing sound #" .. (task.id or "?") .. ": " .. task.sound)

            local emitter = getWorld():getFreeEmitter(task.x, task.y, task.z)
            if emitter then
                emitter:playSound(task.sound)
                DebugPrint("  Sound played via emitter")
            else
                DebugPrint("  ERROR: Could not get emitter!")
            end

            table.remove(ThunderClient.pendingSounds, i)
        end
    end
end

function ThunderClient.OnRenderTick()
    if ThunderClient.flashIntensity > 0 then
        ThunderClient.flashIntensity = ThunderClient.flashIntensity - ThunderClient.flashDecay
        if ThunderClient.flashIntensity < 0 then
            ThunderClient.flashIntensity = 0
        end
    end
end

-- 4. SERVER COMMAND HANDLER
local function OnServerCommand(module, command, args)
    if module == "ThunderMod" then
        DebugPrint("Received server command: " .. command)

        if command == "LightningStrike" then
            DebugPrint("Processing LightningStrike with args: dist=" .. tostring(args.dist) .. ", azimuth=" .. tostring(args.azimuth))
            ThunderClient.DoStrike(args)
        else
            DebugPrint("Unknown command: " .. command)
        end
    end
end

-- 5. INITIALIZATION
local function OnGameStart()
    DebugPrint("Game started - initializing")
    ThunderClient.CreateOverlay()
    DebugPrint("Initialization complete. Total strikes so far: " .. ThunderClient.strikeCount)
end

Events.OnGameStart.Add(OnGameStart)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
Events.OnTick.Add(ThunderClient.OnTick)

print("[ThunderClient] ========== LOADED ==========")
print("[ThunderClient] Events registered: OnGameStart, OnServerCommand, OnRenderTick, OnTick")
