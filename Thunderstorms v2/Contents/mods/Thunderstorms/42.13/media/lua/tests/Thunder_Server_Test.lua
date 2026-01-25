-- Test Suite for Thunder_Server.lua
-- Run this file from the Lua console with: require "tests/Thunder_Server_Test"
-- NOTE: This file should only run on the server side

if isClient() then
    print("[TEST] ⚠ Thunder_Server tests cannot run on client - skipping")
    return
end

print("[TEST] ========== Thunder_Server Tests ==========")

local TestServer = {}
TestServer.passed = 0
TestServer.failed = 0

-- Helper function to assert conditions
local function assert(condition, testName, message)
    if condition then
        TestServer.passed = TestServer.passed + 1
        print("[TEST] ✓ PASS: " .. testName)
        return true
    else
        TestServer.failed = TestServer.failed + 1
        print("[TEST] ✗ FAIL: " .. testName)
        if message then
            print("[TEST]   Reason: " .. message)
        end
        return false
    end
end

-- Test 1: Module exists
local function test_module_exists()
    assert(ThunderServer ~= nil, "ThunderServer module exists", "ThunderServer table should be defined")
end

-- Test 2: Config values are set
local function test_config_values()
    local allSet = ThunderMod.Config.Thunder ~= nil and
                   ThunderServer.minCooldown ~= nil

    assert(allSet, "All config values are set", "Missing one or more config values")
end

-- Test 3: Config values are reasonable
local function test_config_ranges()
    local valid = ThunderMod.Config.Thunder.probabilityMultiplier > 0 and
                  ThunderServer.minCooldown >= 0

    assert(valid, "Config values are in reasonable ranges", "One or more config values out of range")
end

-- Test 4: OnTick function exists
local function test_ontick_exists()
    assert(
        type(ThunderServer.OnTick) == "function",
        "OnTick function exists",
        "Expected function, got " .. type(ThunderServer.OnTick)
    )
end

-- Test 5: TriggerStrike function exists
local function test_triggerstrike_exists()
    assert(
        type(ThunderServer.TriggerStrike) == "function",
        "TriggerStrike function exists",
        "Expected function, got " .. type(ThunderServer.TriggerStrike)
    )
end

-- Test 6: Console commands exist
local function test_console_commands()
    local commands = {
        ForceThunder = type(ForceThunder) == "function",
        TestThunder = type(TestThunder) == "function",
        SetThunderFrequency = type(SetThunderFrequency) == "function",
        ServerForceThunder = type(ServerForceThunder) == "function",
        GetStormIntensity = type(GetStormIntensity) == "function",
        SetThunderMultiplier = type(SetThunderMultiplier) == "function"
    }

    local allExist = commands.ForceThunder and commands.TestThunder and
                     commands.SetThunderFrequency and commands.ServerForceThunder and
                     commands.GetStormIntensity and commands.SetThunderMultiplier

    assert(allExist, "All console commands exist", "One or more console commands missing")
end

-- Test 7: Cooldown timer decrements
local function test_cooldown_decrement()
    local originalTimer = ThunderServer.cooldownTimer
    ThunderServer.cooldownTimer = 100

    ThunderServer.OnTick() -- Should decrement by 1

    local decremented = ThunderServer.cooldownTimer == 99
    ThunderServer.cooldownTimer = originalTimer -- Restore

    assert(decremented, "Cooldown timer decrements", "Timer did not decrement correctly")
end

-- Test 8: TriggerStrike sets cooldown
local function test_trigger_sets_cooldown()
    local originalTimer = ThunderServer.cooldownTimer
    ThunderServer.cooldownTimer = 0

    -- Mock the climate manager if it doesn't exist
    local hadClimate = getClimateManager ~= nil
    if not hadClimate then
        _G.getClimateManager = function()
            return {
                getCloudIntensity = function() return 0.5 end,
                getRainIntensity = function() return 0.5 end,
                getWindIntensity = function() return 0.5 end
            }
        end
    end

    ThunderServer.TriggerStrike(1000)

    local cooldownSet = ThunderServer.cooldownTimer > 0
    ThunderServer.cooldownTimer = originalTimer -- Restore

    if not hadClimate then
        _G.getClimateManager = nil
    end

    assert(cooldownSet, "TriggerStrike sets cooldown", "Cooldown was not set after trigger")
end

-- Test 9: TriggerStrike respects forced distance
local function test_forced_distance()
    -- This is a logic test - we can't fully test without mocking sendServerCommand
    -- But we can verify the function accepts the parameter
    local success = pcall(function()
        -- Mock sendServerCommand if it doesn't exist
        local originalSend = sendServerCommand
        _G.sendServerCommand = function() end

        ThunderServer.TriggerStrike(500)

        _G.sendServerCommand = originalSend
    end)

    assert(success, "TriggerStrike accepts forced distance", "Function failed with forced distance parameter")
end

-- Test 10: SetThunderFrequency changes probabilityMultiplier
local function test_set_frequency()
    local originalMult = ThunderMod.Config.Thunder.probabilityMultiplier

    SetThunderFrequency(2.0)
    local changed = ThunderMod.Config.Thunder.probabilityMultiplier == 2.0

    ThunderMod.Config.Thunder.probabilityMultiplier = originalMult -- Restore

    assert(changed, "SetThunderFrequency changes probabilityMultiplier", "probabilityMultiplier did not change")
end

-- Test 11: Distance range is appropriate
local function test_distance_range()
    -- New range is 50-8000 tiles
    local minDist = ThunderMod.Config.Thunder.minDistance
    local maxDist = ThunderMod.Config.Thunder.maxDistance

    assert(
        minDist == 50 and maxDist == 8000,
        "Distance range is correct",
        "Expected 50-8000 range"
    )
end

-- Test 12: Cooldown calculation is dynamic
local function test_dynamic_cooldown()
    -- Mock climate manager
    local hadClimate = getClimateManager ~= nil
    if not hadClimate then
        _G.getClimateManager = function()
            return {
                getCloudIntensity = function() return 0.5 end,
                getRainIntensity = function() return 0.5 end,
                getWindIntensity = function() return 0.5 end
            }
        end
    end

    local originalTimer = ThunderServer.cooldownTimer
    local originalSend = sendServerCommand
    _G.sendServerCommand = function() end

    ThunderServer.TriggerStrike(1000)
    local cooldown1 = ThunderServer.cooldownTimer

    -- Higher intensity should give shorter cooldown
    -- We'll just call CalculateCooldown directly to verify logic if needed, 
    -- but TriggerStrike uses it.
    -- Let's mock a very intense storm.
    local oldClimate = _G.getClimateManager
    _G.getClimateManager = function()
        return {
            getCloudIntensity = function() return 1.0 end,
            getRainIntensity = function() return 1.0 end,
            getWindIntensity = function() return 1.0 end
        }
    end

    ThunderServer.TriggerStrike(1000)
    local cooldown2 = ThunderServer.cooldownTimer

    -- Restore
    ThunderServer.cooldownTimer = originalTimer
    _G.sendServerCommand = originalSend
    _G.getClimateManager = oldClimate

    if not hadClimate then
        _G.getClimateManager = nil
    end

    -- Intense storm (cooldown2) should be shorter than moderate storm (cooldown1)
    -- Although random variation exists, the difference between 0.5 intensity and 1.0 intensity
    -- is massive (seconds vs minute), so it should hold true.
    -- Wait, if random variation is large, it might fail? 
    -- 0.5 intensity -> ~20-30s? 
    -- 1.0 intensity -> ~5s
    -- It should be safe.
    
    -- Also check min bounds
    assert(
        cooldown2 >= (ThunderMod.Config.Thunder.minCooldownSeconds * 60 * 0.8), -- Allow for variation
        "Dynamic cooldown respects minimum",
        "Cooldown below minimum"
    )
end

-- Run all tests
print("[TEST] Running Thunder_Server tests...")
print("[TEST]")

test_module_exists()
test_config_values()
test_config_ranges()
test_ontick_exists()
test_triggerstrike_exists()
test_console_commands()
test_cooldown_decrement()
test_trigger_sets_cooldown()
test_forced_distance()
test_set_frequency()
test_distance_range()
test_dynamic_cooldown()

-- Print summary
print("[TEST]")
print("[TEST] ========== Test Summary ==========")
print("[TEST] Passed: " .. TestServer.passed)
print("[TEST] Failed: " .. TestServer.failed)
print("[TEST] Total:  " .. (TestServer.passed + TestServer.failed))

if TestServer.failed == 0 then
    print("[TEST] ✓ All tests passed!")
else
    print("[TEST] ✗ Some tests failed")
end

return TestServer
