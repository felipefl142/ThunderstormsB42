if isServer() then return end -- Guard: Only run on Client

local ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.15 -- How fast the flash fades

-- LISTENER: Receive Packet from Server
local function OnServerCommand(module, command, args)
    if module == "ThunderMod" and command == "LightningStrike" then
        ThunderClient.DoStrike(args)
    end
end

function ThunderClient.DoStrike(args)
    local distance = args.dist
    
    -- 1. VISUAL EFFECT
    -- The closer the lightning, the brighter the initial flash
    local brightness = 1.0 - (distance / 1500)
    if brightness < 0.1 then brightness = 0.1 end
    
    -- Set our flash variable (processed in OnRenderTick)
    ThunderClient.flashIntensity = brightness

    -- 2. SOUND EFFECT
    -- PZ has built-in thunder sounds: "Thunder", "Thunder2", "Thunder3", etc.
    -- Or you can add custom sounds to sound.txt and reference them here.
    local soundName = "Thunder"
    
    -- If it's far away, maybe use a rumbling sound
    if distance > 800 then
        soundName = "ThunderStorm" -- Vanilla ambient rumble
    end

    -- Play the sound. 
    -- using getSoundManager():PlaySound() plays it "globally" (in your head).
    -- To make it 3D, we would need world coordinates, but "Global" is better for weather.
    local sound = getSoundManager():PlaySound(soundName, false, 0)
    
    -- Adjust volume based on distance
    if sound then
        -- Vanilla Java sound instance manipulation might vary by build,
        -- but usually we rely on the SoundManager's volume settings.
    end
end

-- RENDER LOOP: Handle the visual flash
function ThunderClient.OnRenderTick()
    if ThunderClient.flashIntensity > 0 then
        local clim = getClimateManager()
        
        -- We grab the current global light and boost it
        -- NOTE: In B42, lighting APIs may shift, but messing with Desaturation 
        -- or GlobalLight is the standard way.
        
        local targetColor = clim:getGlobalLightInternal() -- Read only usually
        
        -- Ideally, we apply a "Night Vision" style full-bright overlay for a frame
        -- But a safer Lua method is modifying the ambient color for a split second.
        
        -- Since we cannot easily inject into the Java render loop to change the FBO,
        -- we simulate the flash by forcing the "DayLightStrength" momentarily if allowed,
        -- or triggering the built-in lightning system if available.
        
        -- MODDING TRICK: 
        -- We can use the ClimateManager's "View" object if exposed.
        -- If not, we can assume the server handles the logic, but for pure visuals:
        
        -- Let's try to simulate flash by drawing a white rectangle over the screen with transparency
        -- This is the most compatible way across builds.
        local core = getCore()
        local w = core:getScreenWidth()
        local h = core:getScreenHeight()
        
        -- Draw a white overlay
        UIManager.DrawTexture(nil, 0, 0, w, h, ThunderClient.flashIntensity)
        
        -- Decay the flash
        ThunderClient.flashIntensity = ThunderClient.flashIntensity - ThunderClient.flashDecay
        
        if ThunderClient.flashIntensity < 0 then
            ThunderClient.flashIntensity = 0
        end
    end
end

Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
