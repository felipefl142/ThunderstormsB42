if isServer() then return end

local ThunderClient = {}
ThunderClient.flashIntensity = 0.0
ThunderClient.flashDecay = 0.15

-- Table to track delayed sounds
ThunderClient.delayedSounds = {} 

local function OnServerCommand(module, command, args)
    if module == "ThunderMod" and command == "LightningStrike" then
        ThunderClient.DoStrike(args)
    end
end

function ThunderClient.DoStrike(args)
    local distance = args.dist -- 0 to 1000
    
    -- 1. VISUALS (Instant Flash)
    local brightness = 1.0 - (distance / 1200)
    if brightness < 0.1 then brightness = 0.1 end
    ThunderClient.flashIntensity = brightness

    -- 2. AUDIO SELECTION
    local soundName = "MyThunder/ThunderClose"
    local delayTicks = 0

    -- Logic: Calculate sound delay and category based on distance
    if distance < 200 then
        -- CLOSE: Instant, Loud
        soundName = "MyThunder/ThunderClose"
        delayTicks = 0 
    elseif distance < 600 then
        -- MEDIUM: Slight Delay
        soundName = "MyThunder/ThunderMedium"
        delayTicks = 15 -- ~0.5 seconds delay (30 ticks = 1 sec)
    else
        -- FAR: Longer Delay, Muffled
        soundName = "MyThunder/ThunderFar"
        delayTicks = 45 -- ~1.5 seconds delay
    end

    -- 3. SCHEDULE AUDIO
    if delayTicks <= 0 then
        getSoundManager():PlaySound(soundName, false, 0)
    else
        table.insert(ThunderClient.delayedSounds, {
            sound = soundName,
            timer = delayTicks
        })
    end
end

function ThunderClient.OnTick()
    -- Process delayed sounds (Sound travel simulation)
    for i = #ThunderClient.delayedSounds, 1, -1 do
        local entry = ThunderClient.delayedSounds[i]
        entry.timer = entry.timer - 1
        
        if entry.timer <= 0 then
            getSoundManager():PlaySound(entry.sound, false, 0)
            table.remove(ThunderClient.delayedSounds, i)
        end
    end
end

-- RENDER LOOP: Handle the visual flash
function ThunderClient.OnRenderTick()
    if ThunderClient.flashIntensity > 0 then
        local core = getCore()
        local w = core:getScreenWidth()
        local h = core:getScreenHeight()
        
        -- Draw white overlay
        UIManager.DrawTexture(nil, 0, 0, w, h, ThunderClient.flashIntensity)
        
        -- Decay
        ThunderClient.flashIntensity = ThunderClient.flashIntensity - ThunderClient.flashDecay
        if ThunderClient.flashIntensity < 0 then ThunderClient.flashIntensity = 0 end
    end
end

Events.OnServerCommand.Add(OnServerCommand)
Events.OnRenderTick.Add(ThunderClient.OnRenderTick)
Events.OnTick.Add(ThunderClient.OnTick) -- Added OnTick for sound delays