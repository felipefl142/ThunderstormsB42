if isServer() then return end

local ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.10 -- Slower decay for better visibility
ThunderClient.delayedSounds = {} 
ThunderClient.flashSequence = {} -- Queue for multi-flash effect
ThunderClient.overlay = nil

-- 1. SETUP THE OVERLAY
-- We create a UI element that acts as our "Flash Screen"
function ThunderClient.CreateOverlay()
    if ThunderClient.overlay then return end
    
    local w = getCore():getScreenWidth()
    local h = getCore():getScreenHeight()
    
    -- Create a simple rectangle element
    ThunderClient.overlay = ISUIElement:new(0, 0, w, h)
    ThunderClient.overlay:initialise()
    -- We want it to ignore mouse clicks
    ThunderClient.overlay:setWantKeyEvents(false)
    ThunderClient.overlay:setMouseOver(false)
    
    -- Override the render function to draw a white rectangle with variable alpha
    ThunderClient.overlay.prerender = function(self)
        if ThunderClient.flashIntensity > 0 then
            -- drawRect(x, y, w, h, alpha, r, g, b)
            self:drawRect(0, 0, self:getWidth(), self:getHeight(), ThunderClient.flashIntensity, 1, 1, 1)
        end
    end
    
    -- Add to the global UI manager so it draws on top of the game world
    ThunderClient.overlay:addToUIManager()
end

-- 2. HANDLE SERVER COMMANDS
local function OnServerCommand(module, command, args)
    if module == "ThunderMod" and command == "LightningStrike" then
        ThunderClient.DoStrike(args)
    end
end

function ThunderClient.DoStrike(args)
    local distance = args.dist
    
    -- VISUALS: Set the intensity
    -- Ensure overlay exists
    ThunderClient.CreateOverlay()
    
    -- Closer = Brighter (Max 0.7 alpha to not blind player totally, Min 0.15)
    local brightness = (0.9 - (distance / 1500)) * 0.8
    if brightness < 0.15 then brightness = 0.15 end
    
    -- Queue multi-flash sequence
    ThunderClient.flashSequence = {}
    local numFlashes = ZombRand(2, 4) -- 2 or 3 flashes
    local now = getTimestampMs()
    
    for i = 1, numFlashes do
        local delay = 0
        if i > 1 then
            -- Tighter flicker: 20ms to 100ms
            delay = ZombRand(20, 100) + ((i-1) * 30)
        end
        
        table.insert(ThunderClient.flashSequence, {
            start = now + delay,
            intensity = brightness * (ZombRandFloat(0.8, 1.2))
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
            getSoundManager():PlaySound(entry.sound, false, 0)
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
Events.OnGameStart.Add(ThunderClient.CreateOverlay) -- Ensure overlay is created on load
Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
Events.OnTick.Add(ThunderClient.OnTick)