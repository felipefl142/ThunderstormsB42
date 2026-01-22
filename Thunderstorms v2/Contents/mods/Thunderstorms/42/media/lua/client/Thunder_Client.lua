if isServer() then return end

-- Ensure we have the shared config
-- ThunderMod should be global from media/lua/shared/Thunder_Shared.lua
if not ThunderMod then 
    print("ThunderClient: ThunderMod global not found! Defaulting config.")
    ThunderMod = {}
    ThunderMod.Config = { SpeedOfSound = 340 }
end

local ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.05 -- Adjusted decay
ThunderClient.pendingSounds = {} -- Table to store queued sounds
ThunderClient.flashSequence = {} -- Queue for multi-flash effect
ThunderClient.overlay = nil

-- 1. VISUALS: OVERLAY
function ThunderClient.CreateOverlay()
    if ThunderClient.overlay then return end
    
    local w = getCore():getScreenWidth()
    local h = getCore():getScreenHeight()
    
    ThunderClient.overlay = ISUIElement:new(0, 0, w, h)
    ThunderClient.overlay:initialise()
    ThunderClient.overlay:setWantKeyEvents(false)
    ThunderClient.overlay:setMouseOver(false)
    
    ThunderClient.overlay.prerender = function(self)
        if ThunderClient.flashIntensity > 0 then
            -- White flash with variable alpha
            self:drawRect(0, 0, self:getWidth(), self:getHeight(), ThunderClient.flashIntensity, 1, 1, 1)
        end
    end
    
    ThunderClient.overlay:addToUIManager()
end

-- 2. AUDIO & LOGIC
function ThunderClient.DoStrike(args)
    local distance = args.dist or 100
    local azimuth = args.azimuth or 0
    
    -- A. VISUALS
    ThunderClient.CreateOverlay()
    
    -- Calculate brightness based on distance
    -- 0 distance = 1.0 brightness (max)
    -- 2000 distance = 0.0 brightness
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

    -- B. AUDIO DELAY CALCULATION
    local speed = ThunderMod.Config.SpeedOfSound or 340
    local delaySeconds = distance / speed
    local triggerTime = getTimestampMs() + (delaySeconds * 1000)

    -- C. POSITION CALCULATION (Polar to Cartesian relative to player)
    local player = getPlayer()
    if not player then return end
    
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local rad = math.rad(azimuth)
    
    local soundX = px + (math.cos(rad) * distance)
    local soundY = py + (math.sin(rad) * distance)
    
    -- D. SELECT SOUND CATEGORY
    local soundName = "MyThunder/ThunderFar"
    if distance < 800 then
        soundName = "MyThunder/ThunderClose"
    elseif distance < 1500 then
        soundName = "MyThunder/ThunderMedium"
    end

    -- E. QUEUE SOUND
    table.insert(ThunderClient.pendingSounds, {
        sound = soundName,
        x = soundX,
        y = soundY,
        z = pz,
        time = triggerTime
    })
end

-- 3. LOOPS
function ThunderClient.OnTick()
    -- Process Audio Queue (Time-based)
    local now = getTimestampMs()
    
    for i = #ThunderClient.pendingSounds, 1, -1 do
        local task = ThunderClient.pendingSounds[i]
        
        if now >= task.time then
            -- Play the sound at the specific world coordinates
            local emitter = getWorld():getFreeEmitter(task.x, task.y, task.z)
            if emitter then
                emitter:playSound(task.sound)
            end
            
            table.remove(ThunderClient.pendingSounds, i)
        end
    end
end

function ThunderClient.OnRenderTick()
    -- Process Flash Queue
    local now = getTimestampMs()
    for i = #ThunderClient.flashSequence, 1, -1 do
        local flash = ThunderClient.flashSequence[i]
        if now >= flash.start then
            ThunderClient.flashIntensity = flash.intensity
            if ThunderClient.flashIntensity > 1.0 then ThunderClient.flashIntensity = 1.0 end
            table.remove(ThunderClient.flashSequence, i)
        end
    end

    -- Process Visual Decay
    if ThunderClient.flashIntensity > 0 then
        ThunderClient.flashIntensity = ThunderClient.flashIntensity - ThunderClient.flashDecay
        if ThunderClient.flashIntensity < 0 then 
            ThunderClient.flashIntensity = 0 
        end
    end
end

-- 4. SERVER COMMAND HANDLER
local function OnServerCommand(module, command, args)
    if module == "ThunderMod" and command == "LightningStrike" then
        ThunderClient.DoStrike(args)
    end
end

-- 5. INITIALIZATION
Events.OnGameStart.Add(ThunderClient.CreateOverlay)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
Events.OnTick.Add(ThunderClient.OnTick)
