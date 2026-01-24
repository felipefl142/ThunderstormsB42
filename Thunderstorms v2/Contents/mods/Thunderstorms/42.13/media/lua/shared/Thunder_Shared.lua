ThunderMod = {}
ThunderMod.NetTag = "ThunderStrikeNet"

ThunderMod.Config = {
    -- GAMEPLAY
    UseNativeWeatherEvents = false, -- If true, uses game's internal OnThunder event (syncs with foraging/moodles) instead of custom random generation
    StrikeChance = 0.002,
    StrikeRadius = 150,
    FirePower = 25,
    ExplosionRadius = 2,
    
    -- PHYSICS
    SpeedOfSound = 340, -- Tiles per second (Sound delay calculation)
}

return ThunderMod