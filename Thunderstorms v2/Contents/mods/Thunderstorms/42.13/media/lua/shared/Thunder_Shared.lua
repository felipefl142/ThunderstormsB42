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
    sigmoidSteepness = 8.0,
    sigmoidMidpoint = 0.30,

    -- INTENSITY WEIGHTS
    cloudWeight = 0.50,
    rainWeight = 0.35,
    windWeight = 0.10,
    synergyWeight = 0.05,

    -- EXPONENTS
    cloudExponent = 1.5,
    rainExponent = 2.0,
    windExponent = 1.2,

    -- COOLDOWN
    minCooldownSeconds = 5,
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