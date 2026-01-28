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

ThunderMod.Config.Thunder = {
    -- PROBABILITY TUNING
    probabilityMultiplier = 1.0,
    sigmoidSteepness = 6.0,
    sigmoidMidpoint = 0.20,

    -- INTENSITY WEIGHTS
    cloudWeight = 0.50,
    rainWeight = 0.35,
    windWeight = 0.10,
    synergyWeight = 0.05,

    -- EXPONENTS
    cloudExponent = 1.2,
    rainExponent = 2.0,
    windExponent = 1.2,

    -- COOLDOWN
    minCooldownSeconds = 3,
    maxCooldownSeconds = 60,
    cooldownDecayRate = 2.5,
    cooldownVariation = 0.15,

    -- DISTANCE
    minDistance = 50,
    maxDistance = 8000,
    distanceBiasPower = 2.5,
    closeRangeMax = 1500,
    mediumRangeMax = 3500,
}

return ThunderMod