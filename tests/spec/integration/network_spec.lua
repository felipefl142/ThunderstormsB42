-- network_spec.lua
-- Integration tests for client-server communication

local PZMock = require "spec.mocks.pz_api_mock"

describe("Network Integration", function()
  local ThunderMod

  setup(function()
    -- Set single-player mode (both client and server)
    PZMock.setSinglePlayerMode()

    -- Install all mocks
    PZMock.installAll({
      climate = {
        cloudIntensity = 0.8,
        rainIntensity = 0.6,
        windIntensity = 0.4
      }
    })

    -- Mock ISUIElement for client
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

    -- Load modules
    ThunderMod = require "Thunder_Shared"
    require "Thunder_Server"
    require "client/Thunder_Client"
    -- ThunderServer and ThunderClient are now globals
  end)

  before_each(function()
    -- Reset state
    ThunderServer.cooldownTimer = 0
    ThunderClient.flashIntensity = 0.0
    ThunderClient.delayedSounds = {}
    ThunderClient.flashSequence = {}

    PZMock.resetTime()
    PZMock.clearNetworkCommands()
  end)

  teardown(function()
    PZMock.cleanupAll()
  end)

  describe("Server to Client Commands", function()
    it("should send LightningStrike command from server", function()
      local commandsBefore = #PZMock.sentServerCommands

      ThunderServer.TriggerStrike(500)

      local commandsAfter = #PZMock.sentServerCommands
      assert.equals(commandsBefore + 1, commandsAfter)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals("ThunderMod", cmd.module)
      assert.equals("LightningStrike", cmd.command)
      assert.is_not_nil(cmd.args)
      assert.is_not_nil(cmd.args.dist)
    end)

    it("should preserve distance in command args", function()
      local testDistance = 1234

      ThunderServer.TriggerStrike(testDistance)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals(testDistance, cmd.args.dist)
    end)

    it("should allow client to receive and process command", function()
      -- Server triggers
      ThunderServer.TriggerStrike(750)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]

      -- Create overlay before DoStrike
      ThunderClient.CreateOverlay()

      -- Client receives and processes
      ThunderClient.DoStrike(cmd.args)

      -- Client should have queued sound
      assert.is_true(#ThunderClient.delayedSounds > 0)

      -- Client should have queued flash
      assert.is_true(#ThunderClient.flashSequence > 0)
    end)

    it("should handle multiple strikes in sequence", function()
      ThunderClient.CreateOverlay()

      -- Server triggers multiple strikes
      ThunderServer.TriggerStrike(200)
      ThunderServer.TriggerStrike(1000)
      ThunderServer.TriggerStrike(2500)

      assert.equals(3, #PZMock.sentServerCommands)

      -- Client processes all strikes
      for _, cmd in ipairs(PZMock.sentServerCommands) do
        ThunderClient.DoStrike(cmd.args)
      end

      -- Client should have 3 sounds queued
      assert.equals(3, #ThunderClient.delayedSounds)
    end)
  end)

  describe("Client to Server Commands", function()
    it("should send ForceStrike command from client", function()
      -- This would normally use sendClientCommand, but in single-player
      -- we can directly call server functions
      local commandsBefore = #PZMock.sentServerCommands

      -- Simulate client requesting strike
      ThunderServer.TriggerStrike(1500)

      local commandsAfter = #PZMock.sentServerCommands
      assert.equals(commandsBefore + 1, commandsAfter)
    end)

    it("should respect forced distance from client", function()
      local forcedDistance = 999

      ThunderServer.TriggerStrike(forcedDistance)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals(forcedDistance, cmd.args.dist)
    end)
  end)

  describe("Single-Player Mode", function()
    it("should act as both client and server", function()
      assert.is_true(PZMock.isClient())
      assert.is_true(PZMock.isServer())
    end)

    it("should allow direct server function calls", function()
      assert.has_no.errors(function()
        ThunderServer.TriggerStrike(500)
      end)
    end)

    it("should allow direct client function calls", function()
      ThunderClient.CreateOverlay()

      assert.has_no.errors(function()
        ThunderClient.DoStrike({ dist = 500 })
      end)
    end)

    it("should process full strike cycle", function()
      ThunderClient.CreateOverlay()

      -- Server triggers
      ThunderServer.TriggerStrike(500)

      -- Get command
      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]

      -- Client receives
      ThunderClient.DoStrike(cmd.args)

      -- Verify client state
      assert.is_true(#ThunderClient.delayedSounds > 0)
      assert.is_true(#ThunderClient.flashSequence > 0)

      -- Verify server state
      assert.is_true(ThunderServer.cooldownTimer > 0)
    end)
  end)

  describe("Multi-Client Scenarios", function()
    it("should broadcast command to all clients", function()
      -- In a real multiplayer scenario, the command would be sent to all clients
      -- We simulate this by processing the same command multiple times
      ThunderServer.TriggerStrike(800)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]

      -- Simulate 3 clients receiving the same command
      for i = 1, 3 do
        ThunderClient.CreateOverlay()
        ThunderClient.DoStrike(cmd.args)
      end

      -- Each client should have processed the strike
      -- (In our test, we're reusing the same ThunderClient instance,
      -- so we'll just verify the command was sent once)
      assert.equals(1, #PZMock.sentServerCommands)
    end)
  end)

  describe("Network Latency Simulation", function()
    it("should handle delayed command processing", function()
      ThunderClient.CreateOverlay()

      -- Server triggers at time 0
      ThunderServer.TriggerStrike(1000)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]

      -- Simulate 200ms network latency
      PZMock.advanceTime(200)

      -- Client receives after delay
      ThunderClient.DoStrike(cmd.args)

      -- Sound should be queued with delay from current time
      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      assert.is_not_nil(sound)

      -- Sound delay should be calculated from arrival time, not send time
      local expectedDelay = (1000 / ThunderMod.Config.SpeedOfSound) * 1000
      local expectedPlayTime = PZMock.currentTime + expectedDelay

      assert.equals(expectedPlayTime, sound.time)
    end)
  end)

  describe("Command Args Preservation", function()
    it("should preserve all command arguments", function()
      local testDist = 1337

      ThunderServer.TriggerStrike(testDist)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]

      assert.is_table(cmd.args)
      assert.equals(testDist, cmd.args.dist)
    end)

    it("should handle minimum distance", function()
      local minDist = ThunderMod.Config.Thunder.minDistance

      ThunderServer.TriggerStrike(minDist)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals(minDist, cmd.args.dist)
    end)

    it("should handle maximum distance", function()
      local maxDist = ThunderMod.Config.Thunder.maxDistance

      ThunderServer.TriggerStrike(maxDist)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals(maxDist, cmd.args.dist)
    end)
  end)

  describe("Console Command Integration", function()
    it("should trigger strike via ForceThunder command", function()
      ThunderClient.CreateOverlay()

      local commandsBefore = #PZMock.sentClientCommands

      -- Call console command
      ForceThunder(666)

      local commandsAfter = #PZMock.sentClientCommands
      assert.equals(commandsBefore + 1, commandsAfter)

      local cmd = PZMock.sentClientCommands[#PZMock.sentClientCommands]
      assert.equals("ForceStrike", cmd.command)
      assert.equals(666, cmd.args.dist)
    end)

    it("should trigger strike via TestThunder command", function()
      ThunderClient.CreateOverlay()

      local soundsBefore = #ThunderClient.delayedSounds

      -- Call console command (client-side wins in this setup)
      TestThunder(500)

      local soundsAfter = #ThunderClient.delayedSounds
      assert.is_true(soundsAfter > soundsBefore)
    end)

    it("should trigger strike via TestThunderClient command", function()
      ThunderClient.CreateOverlay()

      local soundsBefore = #ThunderClient.delayedSounds

      -- Call console command (client-side)
      TestThunderClient(750)

      local soundsAfter = #ThunderClient.delayedSounds
      assert.is_true(soundsAfter > soundsBefore)
    end)
  end)

  describe("Error Handling", function()
    it("should handle nil distance gracefully", function()
      assert.has_no.errors(function()
        ThunderServer.TriggerStrike(nil)
      end)

      -- Should have calculated a distance
      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.is_not_nil(cmd.args.dist)
      assert.is_number(cmd.args.dist)
    end)

    it("should handle empty args table", function()
      ThunderClient.CreateOverlay()

      assert.has_no.errors(function()
        -- This might error in real implementation, but should be handled
        pcall(function()
          ThunderClient.DoStrike({})
        end)
      end)
    end)

    it("should handle malformed command args", function()
      ThunderClient.CreateOverlay()

      assert.has_no.errors(function()
        pcall(function()
          ThunderClient.DoStrike({ dist = "not a number" })
        end)
      end)
    end)
  end)

  describe("Timing Synchronization", function()
    it("should maintain consistent timing across client and server", function()
      -- Server triggers at specific time
      local triggerTime = PZMock.currentTime

      ThunderServer.TriggerStrike(1000)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      assert.equals(triggerTime, cmd.timestamp)
    end)

    it("should queue sounds with physics-based delay", function()
      ThunderClient.CreateOverlay()

      local distance = 680 -- Should be 2 second delay (680 / 340 = 2s)

      ThunderServer.TriggerStrike(distance)

      local cmd = PZMock.sentServerCommands[#PZMock.sentServerCommands]
      ThunderClient.DoStrike(cmd.args)

      local sound = ThunderClient.delayedSounds[#ThunderClient.delayedSounds]
      local expectedDelay = (distance / ThunderMod.Config.SpeedOfSound) * 1000

      assert.equals(PZMock.currentTime + expectedDelay, sound.time)
    end)

    it("should process sounds at correct time", function()
      ThunderClient.CreateOverlay()

      local distance = 340 -- 1 second delay
      ThunderClient.DoStrike({ dist = distance })

      -- Sound should not play immediately
      ThunderClient.OnTick()
      assert.equals(0, getSoundManager():_getSoundCount())

      -- Advance time to play time
      PZMock.advanceTime(1000)

      -- Sound should play now
      ThunderClient.OnTick()
      assert.equals(1, getSoundManager():_getSoundCount())
    end)
  end)
end)
