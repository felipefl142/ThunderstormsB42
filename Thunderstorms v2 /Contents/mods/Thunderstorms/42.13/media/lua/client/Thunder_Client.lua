if isServer() then return end

local ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.10 -- Slower decay for better visibility
ThunderClient.delayedSounds = {} 
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
    
    -- Closer = Brighter (Max 0.9 alpha to not blind player totally, Min 0.2)
    local brightness = 0.9 - (distance / 1500)
    if brightness < 0.2 then brightness = 0.2 end
    
    ThunderClient.flashIntensity = brightness

    -- AUDIO: (Same logic as before, just updated for new sound ranges)
    local soundName = "MyThunder/ThunderClose"
    local delayTicks = 0

    if distance < 200 then
        soundName = "MyThunder/ThunderClose"
        delayTicks = 0 
    elseif distance < 800 then
        soundName = "MyThunder/ThunderMedium"
        delayTicks = 15
    else
        soundName = "MyThunder/ThunderFar"
        delayTicks = 45 
    end

    if delayTicks <= 0 then
        getSoundManager():PlaySound(soundName, false, 0)
    else
        table.insert(ThunderClient.delayedSounds, {
            sound = soundName,
            timer = delayTicks
        })
    end
end

-- 3. UPDATER LOOPS
function ThunderClient.OnTick()
    -- Audio Delay Loop
    for i = #ThunderClient.delayedSounds, 1, -1 do
        local entry = ThunderClient.delayedSounds[i]
        entry.timer = entry.timer - 1
        
        if entry.timer <= 0 then
            getSoundManager():PlaySound(entry.sound, false, 0)
            table.remove(ThunderClient.delayedSounds, i)
        end
    end
end

function ThunderClient.OnRenderTick()
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