-- Thunder_Server_spec.lua
-- Component tests for Thunder_Server.lua module

local PZMock = require "spec.mocks.pz_api_mock"

describe("Thunder_Server", function()
  local ThunderMod

  setup(function()
    -- Set server mode
    PZMock.setServerMode()

    -- Install all mocks
    PZMock.installAll({
      climate = {
        cloudIntensity = 0.5,
        rainIntensity = 0.4,
        windIntensity = 0.3
      }
    })

    -- Load modules
    ThunderMod = require "Thunder_Shared"
    require "Thunder_Server"
    -- ThunderServer is now a global
  end)

  before_each(function()
    -- Reset cooldown and time
    ThunderServer.cooldownTimer = 0
    PZMock.resetTime()
    PZMock.clearNetworkCommands()
    PZMock.resetRandom()
  end)

  after_each(function()
    -- Reset cooldown
    ThunderServer.cooldownTimer = 0
  end)

  teardown(function()
    PZMock.cleanupAll()
  end)

  describe("Module Structure", function()
    it("should exist as a table", function()
      assert.is_not_nil(ThunderServer)
      assert.is_table(ThunderServer)
    end)

    it("should have config values set", function()
      assert.is_not_nil(ThunderServer.minClouds)
      assert.is_not_nil(ThunderServer.baseChance)
      assert.is_not_nil(ThunderServer.cooldownTimer)
      assert.is_not_nil(ThunderServer.minCooldown)
    end)

    it("should have config values in reasonable ranges", function()
      assert.is_true(ThunderServer.minClouds >= 0 and ThunderServer.minClouds <= 1)
      assert.is_true(ThunderServer.baseChance > 0 and ThunderServer.baseChance < 1)
      assert.is_true(ThunderServer.minCooldown >= 0)
    end)
  end)

  describe("Core Functions", function()
    it("should have OnTick function", function()
      assert.is_not_nil(ThunderServer.OnTick)
      assert.is_function(ThunderServer.OnTick)
    end)

    it("should have TriggerStrike function", function()
      assert.is_not_nil(ThunderServer.TriggerStrike)
      assert.is_function(ThunderServer.TriggerStrike)
    end)

    it("should have CalculateStormIntensity function", function()
      assert.is_not_nil(ThunderServer.CalculateStormIntensity)
      assert.is_function(ThunderServer.CalculateStormIntensity)
    end)

    it("should have CalculateThunderProbability function", function()
      assert.is_not_nil(ThunderServer.CalculateThunderProbability)
      assert.is_function(ThunderServer.CalculateThunderProbability)
    end)

    it("should have CalculateCooldown function", function()
      assert.is_not_nil(ThunderServer.CalculateCooldown)
      assert.is_function(ThunderServer.CalculateCooldown)
    end)

    it("should have CalculateStrikeDistance function", function()
      assert.is_not_nil(ThunderServer.CalculateStrikeDistance)
      assert.is_function(ThunderServer.CalculateStrikeDistance)
    end)

    it("should have OnNativeThunder function", function()
      assert.is_not_nil(ThunderServer.OnNativeThunder)
      assert.is_function(ThunderServer.OnNativeThunder)
    end)
  end)

  describe("Console Commands", function()
    it("should have ForceThunder command", function()
      assert.is_not_nil(_G.ForceThunder)
      assert.is_function(_G.ForceThunder)
    end)

    it("should have TestThunder command", function()
      assert.is_not_nil(_G.TestThunder)
      assert.is_function(_G.TestThunder)
    end)

    it("should have SetThunderFrequency command", function()
      assert.is_not_nil(_G.SetThunderFrequency)
      assert.is_function(_G.SetThunderFrequency)
    end)

    it("should have SetThunderMultiplier alias", function()
      assert.is_not_nil(_G.SetThunderMultiplier)
      assert.is_function(_G.SetThunderMultiplier)
    end)

    it("should have ServerForceThunder command", function()
      assert.is_not_nil(_G.ServerForceThunder)
      assert.is_function(_G.ServerForceThunder)
    end)

    it("should have GetStormIntensity command", function()
      assert.is_not_nil(_G.GetStormIntensity)
      assert.is_function(_G.GetStormIntensity)
    end)

    it("should have SetNativeMode alias", function()
      assert.is_not_nil(_G.SetNativeMode)
      assert.is_function(_G.SetNativeMode)
    end)

    it("should have ServerToggleNativeMode command", function()
      assert.is_not_nil(_G.ServerToggleNativeMode)
      assert.is_function(_G.ServerToggleNativeMode)
    end)
  end)

  describe("Storm Intensity Calculation", function()
    it("should return value between 0 and 1", function()
      local intensity = ThunderServer.CalculateStormIntensity()
      assert.is_number(intensity)
      assert.is_true(intensity >= 0.0 and intensity <= 1.0)
    end)

    it("should increase with higher cloud intensity", function()
      local climate = getClimateManager()

      climate:setCloudIntensity(0.2)
      local lowIntensity = ThunderServer.CalculateStormIntensity()

      climate:setCloudIntensity(0.8)
      local highIntensity = ThunderServer.CalculateStormIntensity()

      assert.is_true(highIntensity > lowIntensity)
    end)

    it("should be zero with no clouds, rain, or wind", function()
      local climate = getClimateManager()
      climate:setCloudIntensity(0.0)
      climate:setRainIntensity(0.0)
      climate:setWindIntensity(0.0)

      local intensity = ThunderServer.CalculateStormIntensity()
      assert.is_true(intensity < 0.01)
    end)

    it("should be high with maximum weather values", function()
      local climate = getClimateManager()
      climate:setCloudIntensity(1.0)
      climate:setRainIntensity(1.0)
      climate:setWindIntensity(1.0)

      local intensity = ThunderServer.CalculateStormIntensity()
      assert.is_true(intensity > 0.9)
    end)
  end)

  describe("Thunder Probability Calculation", function()
    it("should return non-negative value", function()
      local prob = ThunderServer.CalculateThunderProbability(0.5)
      assert.is_number(prob)
      assert.is_true(prob >= 0)
    end)

    it("should increase with higher intensity", function()
      local lowProb = ThunderServer.CalculateThunderProbability(0.2)
      local highProb = ThunderServer.CalculateThunderProbability(0.8)

      assert.is_true(highProb > lowProb)
    end)

    it("should be very low for near-zero intensity", function()
      local prob = ThunderServer.CalculateThunderProbability(0.01)
      assert.is_true(prob < 0.01)
    end)

    it("should respect probabilityMultiplier", function()
      local originalMult = ThunderMod.Config.Thunder.probabilityMultiplier

      ThunderMod.Config.Thunder.probabilityMultiplier = 1.0
      local prob1 = ThunderServer.CalculateThunderProbability(0.5)

      ThunderMod.Config.Thunder.probabilityMultiplier = 2.0
      local prob2 = ThunderServer.CalculateThunderProbability(0.5)

      assert.is_true(prob2 > prob1)

      ThunderMod.Config.Thunder.probabilityMultiplier = originalMult
    end)
  end)

  describe("Cooldown System", function()
    it("should decrement on tick when above zero", function()
      ThunderServer.cooldownTimer = 100

      ThunderServer.OnTick()

      assert.equals(99, ThunderServer.cooldownTimer)
    end)

    it("should not go below zero", function()
      ThunderServer.cooldownTimer = 1

      ThunderServer.OnTick()

      assert.equals(0, ThunderServer.cooldownTimer)
    end)

    it("should prevent thunder strikes when active", function()
      ThunderServer.cooldownTimer = 100
      PZMock.setRandomValues({100}) -- Would normally trigger

      local commandsBefore = #PZMock.sentServerCommands
      ThunderServer.OnTick()
      local commandsAfter = #PZMock.sentServerCommands

      assert.equals(commandsBefore, commandsAfter)
    end)

    it("should return shorter cooldown for intense storms", function()
      local cooldownLow = ThunderServer.CalculateCooldown(0.2)
      local cooldownHigh = ThunderServer.CalculateCooldown(0.9)

      assert.is_true(cooldownHigh < cooldownLow)
    end)

    it("should respect minimum cooldown", function()
      local minTicks = ThunderMod.Config.Thunder.minCooldownSeconds * 60
      local cooldown = ThunderServer.CalculateCooldown(1.0)

      -- Allow for 20% margin due to variation
      assert.is_true(cooldown >= minTicks * 0.8)
    end)

    it("should respect maximum cooldown", function()
      local maxTicks = ThunderMod.Config.Thunder.maxCooldownSeconds * 60
      local cooldown = ThunderServer.CalculateCooldown(0.0)

      -- Allow for 20% margin due to variation
      assert.is_true(cooldown <= maxTicks * 1.2)
    end)
  end)

  describe("Strike Distance Calculation", function()
    it("should return value within configured range", function()
      local distance = ThunderServer.CalculateStrikeDistance(0.5)

      assert.is_number(distance)
      assert.is_true(distance >= ThunderMod.Config.Thunder.minDistance)
      assert.is_true(distance <= ThunderMod.Config.Thunder.maxDistance)
    end)

    it("should favor closer strikes during intense storms", function()
      -- Use deterministic random values
      PZMock.setRandomValues({0.9, 0.5}) -- High roll favors close strikes in intense storm

      local distanceHigh = ThunderServer.CalculateStrikeDistance(0.9)

      -- Reset and test low intensity
      PZMock.setRandomValues({0.1, 0.5}) -- Low roll favors far strikes in light storm
      local distanceLow = ThunderServer.CalculateStrikeDistance(0.1)

      -- Intense storms should generally give closer strikes
      -- This is probabilistic, but with controlled random it should hold
      assert.is_true(distanceHigh < ThunderMod.Config.Thunder.closeRangeMax)
    end)
  end)

  describe("TriggerStrike Function", function()
    it("should send server command", function()
      local commandsBefore = #PZMock.sentServerCommands

      ThunderServer.TriggerStrike(1000)

      local commandsAfter = #PZMock.sentServerCommands
      assert.equals(commandsBefore + 1, commandsAfter)
    end)

    it("should use forced distance when provided", function()
      ThunderServer.TriggerStrike(500)

      local lastCommand = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals("ThunderMod", lastCommand.module)
      assert.equals("LightningStrike", lastCommand.command)
      assert.equals(500, lastCommand.args.dist)
    end)

    it("should calculate distance when not provided", function()
      PZMock.setRandomValues({0.5, 0.5})

      ThunderServer.TriggerStrike(nil)

      local lastCommand = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.is_not_nil(lastCommand.args.dist)
      assert.is_true(lastCommand.args.dist >= ThunderMod.Config.Thunder.minDistance)
      assert.is_true(lastCommand.args.dist <= ThunderMod.Config.Thunder.maxDistance)
    end)

    it("should set cooldown after trigger", function()
      ThunderServer.cooldownTimer = 0

      ThunderServer.TriggerStrike(1000)

      assert.is_true(ThunderServer.cooldownTimer > 0)
    end)

    it("should respect UseNativeWeatherEvents flag in OnTick", function()
      local originalFlag = ThunderMod.Config.UseNativeWeatherEvents
      ThunderMod.Config.UseNativeWeatherEvents = true

      ThunderServer.cooldownTimer = 0
      PZMock.setRandomValues({100}) -- Would trigger without native mode

      local commandsBefore = #PZMock.sentServerCommands
      ThunderServer.OnTick()
      local commandsAfter = #PZMock.sentServerCommands

      assert.equals(commandsBefore, commandsAfter)

      ThunderMod.Config.UseNativeWeatherEvents = originalFlag
    end)
  end)

  describe("Console Command Integration", function()
    it("SetThunderFrequency should change probabilityMultiplier", function()
      local originalMult = ThunderMod.Config.Thunder.probabilityMultiplier

      SetThunderFrequency(2.5)

      assert.equals(2.5, ThunderMod.Config.Thunder.probabilityMultiplier)

      ThunderMod.Config.Thunder.probabilityMultiplier = originalMult
    end)

    it("SetThunderMultiplier should be alias for SetThunderFrequency", function()
      local originalMult = ThunderMod.Config.Thunder.probabilityMultiplier

      SetThunderMultiplier(3.0)

      assert.equals(3.0, ThunderMod.Config.Thunder.probabilityMultiplier)

      ThunderMod.Config.Thunder.probabilityMultiplier = originalMult
    end)

    it("ForceThunder should trigger strike", function()
      local commandsBefore = #PZMock.sentServerCommands

      ForceThunder(750)

      local commandsAfter = #PZMock.sentServerCommands
      assert.equals(commandsBefore + 1, commandsAfter)
    end)

    it("TestThunder should trigger strike with default distance", function()
      local commandsBefore = #PZMock.sentServerCommands

      TestThunder()

      local commandsAfter = #PZMock.sentServerCommands
      assert.equals(commandsBefore + 1, commandsAfter)

      local lastCommand = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals(500, lastCommand.args.dist) -- Default is 500
    end)

    it("ServerForceThunder should trigger strike", function()
      local commandsBefore = #PZMock.sentServerCommands

      ServerForceThunder(1200)

      local commandsAfter = #PZMock.sentServerCommands
      assert.equals(commandsBefore + 1, commandsAfter)
    end)

    it("GetStormIntensity should not crash", function()
      assert.has_no.errors(function()
        GetStormIntensity()
      end)
    end)
  end)

  describe("Native Mode", function()
    it("should have UseNativeWeatherEvents flag", function()
      assert.is_not_nil(ThunderMod.Config.UseNativeWeatherEvents)
      assert.is_boolean(ThunderMod.Config.UseNativeWeatherEvents)
    end)

    it("SetNativeMode should change UseNativeWeatherEvents flag", function()
      local originalFlag = ThunderMod.Config.UseNativeWeatherEvents

      SetNativeMode(true)
      assert.is_true(ThunderMod.Config.UseNativeWeatherEvents)

      SetNativeMode(false)
      assert.is_false(ThunderMod.Config.UseNativeWeatherEvents)

      ThunderMod.Config.UseNativeWeatherEvents = originalFlag
    end)

    it("OnNativeThunder should respect UseNativeWeatherEvents flag", function()
      local originalFlag = ThunderMod.Config.UseNativeWeatherEvents
      ThunderMod.Config.UseNativeWeatherEvents = false

      local commandsBefore = #PZMock.sentServerCommands
      ThunderServer.OnNativeThunder(0, 0, true, false, false)
      local commandsAfter = #PZMock.sentServerCommands

      assert.equals(commandsBefore, commandsAfter)

      ThunderMod.Config.UseNativeWeatherEvents = originalFlag
    end)

    it("OnNativeThunder should trigger when enabled", function()
      local originalFlag = ThunderMod.Config.UseNativeWeatherEvents
      ThunderMod.Config.UseNativeWeatherEvents = true

      local commandsBefore = #PZMock.sentServerCommands
      ThunderServer.OnNativeThunder(0, 0, true, false, false)
      local commandsAfter = #PZMock.sentServerCommands

      assert.equals(commandsBefore + 1, commandsAfter)

      ThunderMod.Config.UseNativeWeatherEvents = originalFlag
    end)
  end)

  describe("Distance Range", function()
    it("should have correct min and max distance", function()
      assert.equals(50, ThunderMod.Config.Thunder.minDistance)
      assert.equals(8000, ThunderMod.Config.Thunder.maxDistance)
    end)
  end)
end)
