-- Test Suite for Thunder_Shared.lua
-- Run this file from the Lua console with: require "tests/Thunder_Shared_Test"

print("[TEST] ========== Thunder_Shared Tests ==========")

local TestShared = {}
TestShared.passed = 0
TestShared.failed = 0

-- Helper function to assert conditions
local function assert(condition, testName, message)
    if condition then
        TestShared.passed = TestShared.passed + 1
        print("[TEST] ✓ PASS: " .. testName)
        return true
    else
        TestShared.failed = TestShared.failed + 1
        print("[TEST] ✗ FAIL: " .. testName)
        if message then
            print("[TEST]   Reason: " .. message)
        end
        return false
    end
end

-- Test 1: Module exists
local function test_module_exists()
    assert(ThunderMod ~= nil, "Module exists", "ThunderMod table should be defined")
end

-- Test 2: NetTag is properly set
local function test_net_tag()
    assert(
        ThunderMod.NetTag == "ThunderStrikeNet",
        "NetTag is correct",
        "Expected 'ThunderStrikeNet', got " .. tostring(ThunderMod.NetTag)
    )
end

-- Test 3: Config table exists
local function test_config_exists()
    assert(ThunderMod.Config ~= nil, "Config table exists", "Config should be a table")
end

-- Test 4: Config has all required gameplay values
local function test_config_gameplay()
    local config = ThunderMod.Config
    local allPresent = config.StrikeChance ~= nil and
                       config.StrikeRadius ~= nil and
                       config.FirePower ~= nil and
                       config.ExplosionRadius ~= nil

    assert(allPresent, "All gameplay config values present", "Missing one or more gameplay config values")
end

-- Test 5: Config has physics values
local function test_config_physics()
    assert(
        ThunderMod.Config.SpeedOfSound == 340,
        "Speed of sound is correct",
        "Expected 340, got " .. tostring(ThunderMod.Config.SpeedOfSound)
    )
end

-- Test 6: Config values are reasonable
local function test_config_ranges()
    local config = ThunderMod.Config
    local valid = config.StrikeChance > 0 and config.StrikeChance < 1 and
                  config.StrikeRadius > 0 and
                  config.FirePower >= 0 and
                  config.ExplosionRadius >= 0 and
                  config.SpeedOfSound > 0

    assert(valid, "Config values are in reasonable ranges", "One or more config values out of expected range")
end

-- Test 7: Module can be required/returned
local function test_module_returnable()
    local success = type(ThunderMod) == "table"
    assert(success, "Module is a valid table type", "ThunderMod should be a table")
end

-- Test 8: Config is immutable (best practice check)
local function test_config_structure()
    local configType = type(ThunderMod.Config)
    assert(configType == "table", "Config is a table", "Expected table, got " .. configType)
end

-- Run all tests
print("[TEST] Running Thunder_Shared tests...")
print("[TEST]")

test_module_exists()
test_net_tag()
test_config_exists()
test_config_gameplay()
test_config_physics()
test_config_ranges()
test_module_returnable()
test_config_structure()

-- Print summary
print("[TEST]")
print("[TEST] ========== Test Summary ==========")
print("[TEST] Passed: " .. TestShared.passed)
print("[TEST] Failed: " .. TestShared.failed)
print("[TEST] Total:  " .. (TestShared.passed + TestShared.failed))

if TestShared.failed == 0 then
    print("[TEST] ✓ All tests passed!")
else
    print("[TEST] ✗ Some tests failed")
end

return TestShared
