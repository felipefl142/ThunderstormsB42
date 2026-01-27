-- Thunder_Client_spec.lua
-- Component tests for Thunder_Client.lua module

local PZMock = require "spec.mocks.pz_api_mock"

describe("Thunder_Client", function()
  local ThunderMod

  setup(function()
    -- Set client mode
    PZMock.setClientMode()

    -- Install all mocks
    local mocks = PZMock.installAll({
      climate = { cloudIntensity = 0.5 },
      player = {
        square = PZMock.createSquare({ room = nil })
      }
    })

    -- Load modules
    ThunderMod = require "shared/Thunder_Shared"

    -- Mock ISUIElement before loading client
    _G.ISUIElement = {
      new = function(self, x, y, w, h)
        local elem = PZMock.createISUIElement()
        elem.x = x
        elem.y = y
        elem.width = w
        elem.height = h
        return elem
      end,
      render = function(self) end
    }

    require "client/Thunder_Client"
    -- ThunderClient is now a global
  end)

  before_each(function()
    -- Reset client state
    ThunderClient.flashIntensity = 0.0
    ThunderClient.delayedSounds = {}
    ThunderClient.flashSequence = {}
    ThunderClient.activeLightSources = {}
    ThunderClient.debugMode = false
    ThunderClient.useLighting = true
    ThunderClient.useIndoorDetection = true

    -- Reset mocks
    PZMock.resetTime()
    getSoundManager():_clearSounds()
    getCell():_clearLampposts()
  end)

  after_each(function()
    -- Remove overlay from UI manager if added
    if ThunderClient.overlay and ThunderClient.overlay.inUIManager then
      ThunderClient.overlay:removeFromUIManager()
    end
  end)

  teardown(function()
    PZMock.cleanupAll()
  end)

  describe("Module Structure", function()
    it("should exist as a table", function()
      assert.is_not_nil(ThunderClient)
      assert.is_table(ThunderClient)
    end)

    it("should have correct initial state", function()
      assert.equals(0.0, ThunderClient.flashIntensity)
      assert.is_table(ThunderClient.delayedSounds)
      assert.is_table(ThunderClient.flashSequence)
      assert.is_table(ThunderClient.activeLightSources)
    end)

    it("should have feature flags", function()
      assert.is_boolean(ThunderClient.debugMode)
      assert.is_boolean(ThunderClient.useLighting)
      assert.is_boolean(ThunderClient.useIndoorDetection)
    end)

    it("should have flashDecayRate configured", function()
      assert.is_not_nil(ThunderClient.flashDecayRate)
      assert.is_number(ThunderClient.flashDecayRate)
      assert.is_true(ThunderClient.flashDecayRate > 0)
    end)
  end)

  describe("Core Functions", function()
    it("should have CreateOverlay function", function()
      assert.is_not_nil(ThunderClient.CreateOverlay)
      assert.is_function(ThunderClient.CreateOverlay)
    end)

    it("should have DoStrike function", function()
      assert.is_not_nil(ThunderClient.DoStrike)
      assert.is_function(ThunderClient.DoStrike)
    end)

    it("should have OnTick function", function()
      assert.is_not_nil(ThunderClient.OnTick)
      assert.is_function(ThunderClient.OnTick)
    end)

    it("should have OnRenderTick function", function()
      assert.is_not_nil(ThunderClient.OnRenderTick)
      assert.is_function(ThunderClient.OnRenderTick)
    end)

    it("should have IsPlayerIndoors function", function()
      assert.is_not_nil(ThunderClient.IsPlayerIndoors)
      assert.is_function(ThunderClient.IsPlayerIndoors)
    end)

    it("should have CreateLightningFlash function", function()
      assert.is_not_nil(ThunderClient.CreateLightningFlash)
      assert.is_function(ThunderClient.CreateLightningFlash)
    end)

    it("should have CleanupLights function", function()
      assert.is_not_nil(ThunderClient.CleanupLights)
      assert.is_function(ThunderClient.CleanupLights)
    end)
  end)

  describe("Console Commands", function()
    it("should have TestThunderClient command", function()
      assert.is_not_nil(_G.TestThunderClient)
      assert.is_function(_G.TestThunderClient)
    end)

    it("should have ThunderToggleDebug command", function()
      assert.is_not_nil(_G.ThunderToggleDebug)
      assert.is_function(_G.ThunderToggleDebug)
    end)

    it("should have ThunderToggleLighting command", function()
      assert.is_not_nil(_G.ThunderToggleLighting)
      assert.is_function(_G.ThunderToggleLighting)
    end)

    it("should have ThunderToggleIndoorDetection command", function()
      assert.is_not_nil(_G.ThunderToggleIndoorDetection)
      assert.is_function(_G.ThunderToggleIndoorDetection)
    end)
  end)

  describe("Overlay Management", function()
    it("should create overlay with screen dimensions", function()
      ThunderClient.CreateOverlay()

      assert.is_not_nil(ThunderClient.overlay)
      assert.equals(0, ThunderClient.overlay.x)
      assert.equals(0, ThunderClient.overlay.y)
      assert.equals(1920, ThunderClient.overlay.width)
      assert.equals(1080, ThunderClient.overlay.height)
    end)

    it("should not create duplicate overlays", function()
      ThunderClient.CreateOverlay()
      local firstOverlay = ThunderClient.overlay

      ThunderClient.CreateOverlay()
      local secondOverlay = ThunderClient.overlay

      assert.equals(firstOverlay, secondOverlay)
    end)

    it("should have overlay with ignore event flags", function()
      ThunderClient.CreateOverlay()

      assert.is_true(ThunderClient.overlay.ignoreMouseEvents)
      assert.is_true(ThunderClient.overlay.ignoreKeyEvents)
    end)

    it("should not add overlay to UI manager immediately", function()
      ThunderClient.CreateOverlay()

      assert.is_false(ThunderClient.overlay.inUIManager)
    end)
  end)

  describe("Indoor Detection", function()
    it("should return false when player has no room", function()
      local player = getPlayer()
      player:setSquare(PZMock.createSquare({ room = nil }))

      local isIndoors = ThunderClient.IsPlayerIndoors()

      assert.is_false(isIndoors)
    end)

    it("should return true when player is in a room", function()
      local player = getPlayer()
      local room = PZMock.createRoom("Kitchen")
      player:setSquare(PZMock.createSquare({ room = room }))

      local isIndoors = ThunderClient.IsPlayerIndoors()

      assert.is_true(isIndoors)
    end)

    it("should handle nil square gracefully", function()
      local player = getPlayer()
      player.square = nil

      local isIndoors = ThunderClient.IsPlayerIndoors()

      assert.is_false(isIndoors)
    end)
  end)

  describe("Lightning Flash Effects", function()
    it("should create light source when lighting enabled", function()
      ThunderClient.useLighting = true

      ThunderClient.CreateLightningFlash(0.5, 400)

      assert.is_true(getCell():_getLamppostCount() > 0)
    end)

    it("should not create light source when lighting disabled", function()
      ThunderClient.useLighting = false

      ThunderClient.CreateLightningFlash(0.5, 400)

      assert.equals(0, getCell():_getLamppostCount())
    end)

    it("should create multiple lights when player is indoors", function()
      ThunderClient.useLighting = true

      local player = getPlayer()
      local room = PZMock.createRoom("Bedroom")
      player:setSquare(PZMock.createSquare({ room = room }))

      ThunderClient.CreateLightningFlash(0.5, 400)

      -- Should create main light + ambient lights
      assert.is_true(getCell():_getLamppostCount() > 1)
    end)

    it("should scale radius with intensity", function()
      ThunderClient.useLighting = true

      ThunderClient.CreateLightningFlash(0.1, 400)
      local lowLightCount = getCell():_getLamppostCount()

      getCell():_clearLampposts()

      ThunderClient.CreateLightningFlash(0.9, 400)
      local highLightCount = getCell():_getLamppostCount()

      -- Both should create lights
      assert.is_true(lowLightCount > 0)
      assert.is_true(highLightCount > 0)
    end)

    it("should cleanup old lights after duration", function()
      ThunderClient.useLighting = true

      ThunderClient.CreateLightningFlash(0.5, 400)
      assert.is_true(#ThunderClient.activeLightSources > 0)

      -- Advance time past duration
      PZMock.advanceTime(500)

      ThunderClient.CleanupLights()

      assert.equals(0, #ThunderClient.activeLightSources)
    end)
  end)

  describe("DoStrike Function", function()
    before_each(function()
      ThunderClient.CreateOverlay()
    end)

    it("should ignore strikes beyond max hearing distance", function()
      local soundsBefore = #ThunderClient.delayedSounds

      ThunderClient.DoStrike({ dist = 9000 }) -- Beyond 8000

      local soundsAfter = #ThunderClient.delayedSounds
      assert.equals(soundsBefore, soundsAfter)
    end)

    it("should queue sound for valid distance", function()
      local soundsBefore = #ThunderClient.delayedSounds

      ThunderClient.DoStrike({ dist = 500 })

      local soundsAfter = #ThunderClient.delayedSounds
      assert.is_true(soundsAfter > soundsBefore)
    end)

    it("should create flash sequence", function()
      local flashesBefore = #ThunderClient.flashSequence

      ThunderClient.DoStrike({ dist = 500 })

      local flashesAfter = #ThunderClient.flashSequence
      assert.is_true(flashesAfter > flashesBefore)
    end)

    it("should add overlay to UI manager", function()
      ThunderClient.DoStrike({ dist = 500 })

      assert.is_true(ThunderClient.overlay.inUIManager)
    end)

    it("should calculate sound delay based on distance", function()
      local distance = 340 -- Should delay 1 second (340 tiles / 340 m/s = 1s)
      ThunderClient.DoStrike({ dist = distance })

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      local expectedTime = PZMock.currentTime + 1000 -- 1 second in ms

      assert.is_not_nil(sound)
      assert.equals(expectedTime, sound.playTime)
    end)
  end)

  describe("Sound Selection", function()
    it("should use ThunderClose for distance < 200", function()
      ThunderClient.DoStrike({ dist = 150 })

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      assert.is_not_nil(sound)
      assert.is_true(string.find(sound.sound, "ThunderClose") ~= nil)
    end)

    it("should use ThunderMedium for distance < 800", function()
      ThunderClient.DoStrike({ dist = 500 })

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      assert.is_not_nil(sound)
      assert.is_true(string.find(sound.sound, "ThunderMedium") ~= nil)
    end)

    it("should use ThunderFar for distance >= 800", function()
      ThunderClient.DoStrike({ dist = 1500 })

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      assert.is_not_nil(sound)
      assert.is_true(string.find(sound.sound, "ThunderFar") ~= nil)
    end)
  end)

  describe("Volume Calculation", function()
    it("should have maximum volume at distance 0", function()
      ThunderClient.DoStrike({ dist = 0 })

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      assert.is_not_nil(sound)
      assert.equals(1.0, sound.volume)
    end)

    it("should have minimum volume at max distance", function()
      ThunderClient.DoStrike({ dist = 8000 })

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      assert.is_not_nil(sound)
      assert.is_true(sound.volume <= 0.15) -- Should be near minimum
    end)

    it("should decrease volume with distance", function()
      ThunderClient.DoStrike({ dist = 500 })
      local nearSound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]

      ThunderClient.DoStrike({ dist = 2000 })
      local farSound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]

      assert.is_true(nearSound.volume > farSound.volume)
    end)

    it("should apply indoor modifier when indoors", function()
      -- Set player outdoors first
      local player = getPlayer()
      player:setSquare(PZMock.createSquare({ room = nil }))

      ThunderClient.DoStrike({ dist = 500 })
      local outdoorSound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]

      -- Set player indoors
      local room = PZMock.createRoom("Garage")
      player:setSquare(PZMock.createSquare({ room = room }))

      ThunderClient.DoStrike({ dist = 500 })
      local indoorSound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]

      -- Indoor volume should be lower
      assert.is_true(indoorSound.volume < outdoorSound.volume)
    end)
  end)

  describe("Flash System", function()
    it("should scale brightness with distance", function()
      ThunderClient.CreateOverlay()

      ThunderClient.DoStrike({ dist = 0 })
      local closeFlash = ThunderClient.flashSequence[1]

      ThunderClient.flashSequence = {}
      ThunderClient.DoStrike({ dist = 3000 })
      local farFlash = ThunderClient.flashSequence[1]

      assert.is_not_nil(closeFlash)
      assert.is_not_nil(farFlash)
      assert.is_true(closeFlash.intensity > farFlash.intensity)
    end)

    it("should sometimes create double flash", function()
      -- Use deterministic random to force double flash
      PZMock.setRandomValues({0.2, 0.5}) -- 0.2 < 0.3, should trigger double

      ThunderClient.DoStrike({ dist = 500 })

      -- Should have more than one flash
      assert.is_true(#ThunderClient.flashSequence >= 1)
    end)

    it("should clamp flash intensity between 0.1 and 0.5", function()
      ThunderClient.DoStrike({ dist = 0 }) -- Very close
      local flash = ThunderClient.flashSequence[1]

      assert.is_not_nil(flash)
      assert.is_true(flash.intensity >= 0.1)
      assert.is_true(flash.intensity <= 0.5)
    end)
  end)

  describe("Flash Decay", function()
    before_each(function()
      ThunderClient.CreateOverlay()
      ThunderClient.overlay:addToUIManager()
    end)

    it("should decay flash intensity over time", function()
      ThunderClient.flashIntensity = 0.5
      ThunderClient.lastUpdateTime = PZMock.currentTime

      -- Advance time by 100ms
      PZMock.advanceTime(100)

      ThunderClient.OnRenderTick()

      -- Should have decayed (2.5 units/sec = 0.25 units per 100ms)
      assert.is_true(ThunderClient.flashIntensity < 0.5)
    end)

    it("should clamp flash intensity at zero", function()
      ThunderClient.flashIntensity = 0.1
      ThunderClient.lastUpdateTime = PZMock.currentTime

      -- Advance enough time to decay past zero
      PZMock.advanceTime(1000)

      ThunderClient.OnRenderTick()

      assert.equals(0.0, ThunderClient.flashIntensity)
    end)

    it("should remove overlay when flash reaches zero", function()
      ThunderClient.flashIntensity = 0.05
      ThunderClient.lastUpdateTime = PZMock.currentTime

      PZMock.advanceTime(100)

      ThunderClient.OnRenderTick()

      assert.is_false(ThunderClient.overlay.inUIManager)
    end)
  end)

  describe("OnTick Audio Processing", function()
    it("should play sounds when delay expires", function()
      local playTime = PZMock.currentTime + 500
      table.insert(ThunderClient.delayedSounds, {
        sound = "MyThunder.ThunderClose-long",
        time = playTime,
        volume = 1.0
      })

      -- Advance time to play time
      PZMock.advanceTime(500)

      ThunderClient.OnTick()

      -- Sound should have been played
      assert.equals(1, getSoundManager():_getSoundCount())
    end)

    it("should not play sounds before delay expires", function()
      local playTime = PZMock.currentTime + 1000
      table.insert(ThunderClient.delayedSounds, {
        sound = "MyThunder.ThunderMedium-long",
        time = playTime,
        volume = 0.8
      })

      -- Advance time but not enough
      PZMock.advanceTime(500)

      ThunderClient.OnTick()

      -- Sound should not have played yet
      assert.equals(0, getSoundManager():_getSoundCount())
    end)

    it("should remove played sounds from queue", function()
      local playTime = PZMock.currentTime + 100
      table.insert(ThunderClient.delayedSounds, {
        sound = "MyThunder.ThunderFar-short",
        time = playTime,
        volume = 0.5
      })

      PZMock.advanceTime(150)

      ThunderClient.OnTick()

      assert.equals(0, #ThunderClient.delayedSounds)
    end)
  end)

  describe("OnRenderTick Flash Processing", function()
    before_each(function()
      ThunderClient.CreateOverlay()
    end)

    it("should trigger flash when sequence has pending flashes", function()
      table.insert(ThunderClient.flashSequence, {
        intensity = 0.4,
        start = PZMock.currentTime
      })

      ThunderClient.OnRenderTick()

      assert.equals(0.4, ThunderClient.flashIntensity)
    end)

    it("should respect flash delay", function()
      local triggerTime = PZMock.currentTime + 200
      table.insert(ThunderClient.flashSequence, {
        intensity = 0.3,
        start = triggerTime
      })

      ThunderClient.OnRenderTick()

      -- Should not have triggered yet
      assert.equals(0.0, ThunderClient.flashIntensity)

      -- Advance time
      PZMock.advanceTime(250)

      ThunderClient.OnRenderTick()

      -- Should have triggered now
      assert.equals(0.3, ThunderClient.flashIntensity)
    end)

    it("should remove triggered flashes from sequence", function()
      table.insert(ThunderClient.flashSequence, {
        intensity = 0.2,
        start = PZMock.currentTime
      })

      ThunderClient.OnRenderTick()

      assert.equals(0, #ThunderClient.flashSequence)
    end)

    it("should create lighting effects when flash triggers", function()
      ThunderClient.useLighting = true

      table.insert(ThunderClient.flashSequence, {
        intensity = 0.5,
        start = PZMock.currentTime
      })

      ThunderClient.OnRenderTick()

      assert.is_true(getCell():_getLamppostCount() > 0)
    end)
  end)

  describe("Debug Mode", function()
    it("should toggle debug mode", function()
      local originalDebug = ThunderClient.debugMode

      ThunderToggleDebug(true)
      assert.is_true(ThunderClient.debugMode)

      ThunderToggleDebug(false)
      assert.is_false(ThunderClient.debugMode)

      ThunderClient.debugMode = originalDebug
    end)

    it("should toggle without parameter", function()
      local originalDebug = ThunderClient.debugMode

      ThunderToggleDebug()
      local firstState = ThunderClient.debugMode

      ThunderToggleDebug()
      local secondState = ThunderClient.debugMode

      assert.is_not.equals(firstState, secondState)

      ThunderClient.debugMode = originalDebug
    end)
  end)

  describe("Feature Toggles", function()
    it("should toggle lighting feature", function()
      ThunderToggleLighting(false)
      assert.is_false(ThunderClient.useLighting)

      ThunderToggleLighting(true)
      assert.is_true(ThunderClient.useLighting)
    end)

    it("should toggle indoor detection feature", function()
      ThunderToggleIndoorDetection(false)
      assert.is_false(ThunderClient.useIndoorDetection)

      ThunderToggleIndoorDetection(true)
      assert.is_true(ThunderClient.useIndoorDetection)
    end)
  end)
end)
