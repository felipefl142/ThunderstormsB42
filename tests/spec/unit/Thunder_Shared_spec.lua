-- Thunder_Shared_spec.lua
-- Unit tests for Thunder_Shared.lua module

describe("Thunder_Shared", function()
  local ThunderMod

  setup(function()
    -- Load the shared module
    ThunderMod = require "Thunder_Shared"
  end)

  describe("Module Structure", function()
    it("should exist as a table", function()
      assert.is_not_nil(ThunderMod)
      assert.is_table(ThunderMod)
    end)

    it("should have NetTag property", function()
      assert.is_not_nil(ThunderMod.NetTag)
      assert.equals("ThunderStrikeNet", ThunderMod.NetTag)
    end)

    it("should have Config table", function()
      assert.is_not_nil(ThunderMod.Config)
      assert.is_table(ThunderMod.Config)
    end)
  end)

  describe("Config - Gameplay Values", function()
    it("should have UseNativeWeatherEvents flag", function()
      assert.is_not_nil(ThunderMod.Config.UseNativeWeatherEvents)
      assert.is_boolean(ThunderMod.Config.UseNativeWeatherEvents)
    end)

    it("should have StrikeChance", function()
      assert.is_not_nil(ThunderMod.Config.StrikeChance)
      assert.is_number(ThunderMod.Config.StrikeChance)
      assert.is_true(ThunderMod.Config.StrikeChance > 0 and ThunderMod.Config.StrikeChance < 1)
    end)

    it("should have StrikeRadius", function()
      assert.is_not_nil(ThunderMod.Config.StrikeRadius)
      assert.is_number(ThunderMod.Config.StrikeRadius)
      assert.is_true(ThunderMod.Config.StrikeRadius > 0)
    end)

    it("should have FirePower", function()
      assert.is_not_nil(ThunderMod.Config.FirePower)
      assert.is_number(ThunderMod.Config.FirePower)
      assert.is_true(ThunderMod.Config.FirePower >= 0)
    end)

    it("should have ExplosionRadius", function()
      assert.is_not_nil(ThunderMod.Config.ExplosionRadius)
      assert.is_number(ThunderMod.Config.ExplosionRadius)
      assert.is_true(ThunderMod.Config.ExplosionRadius >= 0)
    end)
  end)

  describe("Config - Physics Values", function()
    it("should have SpeedOfSound set to 340", function()
      assert.is_not_nil(ThunderMod.Config.SpeedOfSound)
      assert.equals(340, ThunderMod.Config.SpeedOfSound)
    end)
  end)

  describe("Config - Thunder System", function()
    it("should have Thunder config table", function()
      assert.is_not_nil(ThunderMod.Config.Thunder)
      assert.is_table(ThunderMod.Config.Thunder)
    end)

    describe("Probability Parameters", function()
      it("should have probabilityMultiplier", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.probabilityMultiplier)
        assert.is_number(ThunderMod.Config.Thunder.probabilityMultiplier)
        assert.is_true(ThunderMod.Config.Thunder.probabilityMultiplier > 0)
      end)

      it("should have sigmoidSteepness in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.sigmoidSteepness)
        assert.is_number(ThunderMod.Config.Thunder.sigmoidSteepness)
        assert.is_true(ThunderMod.Config.Thunder.sigmoidSteepness >= 5.0 and
                       ThunderMod.Config.Thunder.sigmoidSteepness <= 15.0)
      end)

      it("should have sigmoidMidpoint in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.sigmoidMidpoint)
        assert.is_number(ThunderMod.Config.Thunder.sigmoidMidpoint)
        assert.is_true(ThunderMod.Config.Thunder.sigmoidMidpoint >= 0.2 and
                       ThunderMod.Config.Thunder.sigmoidMidpoint <= 0.5)
      end)
    end)

    describe("Intensity Weights", function()
      it("should have cloudWeight in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.cloudWeight)
        assert.is_number(ThunderMod.Config.Thunder.cloudWeight)
        assert.is_true(ThunderMod.Config.Thunder.cloudWeight >= 0.3 and
                       ThunderMod.Config.Thunder.cloudWeight <= 0.7)
      end)

      it("should have rainWeight in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.rainWeight)
        assert.is_number(ThunderMod.Config.Thunder.rainWeight)
        assert.is_true(ThunderMod.Config.Thunder.rainWeight >= 0.2 and
                       ThunderMod.Config.Thunder.rainWeight <= 0.5)
      end)

      it("should have windWeight in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.windWeight)
        assert.is_number(ThunderMod.Config.Thunder.windWeight)
        assert.is_true(ThunderMod.Config.Thunder.windWeight >= 0.0 and
                       ThunderMod.Config.Thunder.windWeight <= 0.2)
      end)

      it("should have synergyWeight", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.synergyWeight)
        assert.is_number(ThunderMod.Config.Thunder.synergyWeight)
        assert.is_true(ThunderMod.Config.Thunder.synergyWeight >= 0)
      end)
    end)

    describe("Exponents", function()
      it("should have cloudExponent", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.cloudExponent)
        assert.is_number(ThunderMod.Config.Thunder.cloudExponent)
        assert.is_true(ThunderMod.Config.Thunder.cloudExponent > 0)
      end)

      it("should have rainExponent", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.rainExponent)
        assert.is_number(ThunderMod.Config.Thunder.rainExponent)
        assert.is_true(ThunderMod.Config.Thunder.rainExponent > 0)
      end)

      it("should have windExponent", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.windExponent)
        assert.is_number(ThunderMod.Config.Thunder.windExponent)
        assert.is_true(ThunderMod.Config.Thunder.windExponent > 0)
      end)
    end)

    describe("Cooldown Parameters", function()
      it("should have minCooldownSeconds in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.minCooldownSeconds)
        assert.is_number(ThunderMod.Config.Thunder.minCooldownSeconds)
        assert.is_true(ThunderMod.Config.Thunder.minCooldownSeconds >= 3 and
                       ThunderMod.Config.Thunder.minCooldownSeconds <= 10)
      end)

      it("should have maxCooldownSeconds in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.maxCooldownSeconds)
        assert.is_number(ThunderMod.Config.Thunder.maxCooldownSeconds)
        assert.is_true(ThunderMod.Config.Thunder.maxCooldownSeconds >= 45 and
                       ThunderMod.Config.Thunder.maxCooldownSeconds <= 120)
      end)

      it("should have cooldownDecayRate", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.cooldownDecayRate)
        assert.is_number(ThunderMod.Config.Thunder.cooldownDecayRate)
        assert.is_true(ThunderMod.Config.Thunder.cooldownDecayRate > 0)
      end)

      it("should have cooldownVariation", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.cooldownVariation)
        assert.is_number(ThunderMod.Config.Thunder.cooldownVariation)
        assert.is_true(ThunderMod.Config.Thunder.cooldownVariation >= 0 and
                       ThunderMod.Config.Thunder.cooldownVariation <= 1)
      end)
    end)

    describe("Distance Parameters", function()
      it("should have minDistance", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.minDistance)
        assert.is_number(ThunderMod.Config.Thunder.minDistance)
        assert.is_true(ThunderMod.Config.Thunder.minDistance > 0)
      end)

      it("should have maxDistance", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.maxDistance)
        assert.is_number(ThunderMod.Config.Thunder.maxDistance)
        assert.is_true(ThunderMod.Config.Thunder.maxDistance > ThunderMod.Config.Thunder.minDistance)
      end)

      it("should have distanceBiasPower in valid range", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.distanceBiasPower)
        assert.is_number(ThunderMod.Config.Thunder.distanceBiasPower)
        assert.is_true(ThunderMod.Config.Thunder.distanceBiasPower >= 1.5 and
                       ThunderMod.Config.Thunder.distanceBiasPower <= 3.5)
      end)

      it("should have closeRangeMax", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.closeRangeMax)
        assert.is_number(ThunderMod.Config.Thunder.closeRangeMax)
        assert.is_true(ThunderMod.Config.Thunder.closeRangeMax > 0)
      end)

      it("should have mediumRangeMax", function()
        assert.is_not_nil(ThunderMod.Config.Thunder.mediumRangeMax)
        assert.is_number(ThunderMod.Config.Thunder.mediumRangeMax)
        assert.is_true(ThunderMod.Config.Thunder.mediumRangeMax > ThunderMod.Config.Thunder.closeRangeMax)
      end)
    end)
  end)
end)
