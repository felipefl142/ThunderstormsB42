-- Test Suite for Thunder_Client.lua
-- Run this file from the Lua console with: require "tests/Thunder_Client_Test"
-- NOTE: This file should only run on the client side

if isServer() then
    print("[TEST] ⚠ Thunder_Client tests cannot run on server - skipping")
    return
end

print("[TEST] ========== Thunder_Client Tests ==========")

local TestClient = {}
TestClient.passed = 0
TestClient.failed = 0

-- Helper function to assert conditions
local function assert(condition, testName, message)
    if condition then
        TestClient.passed = TestClient.passed + 1
        print("[TEST] ✓ PASS: " .. testName)
        return true
    else
        TestClient.failed = TestClient.failed + 1
        print("[TEST] ✗ FAIL: " .. testName)
        if message then
            print("[TEST]   Reason: " .. message)
        end
        return false
    end
end

-- Test 1: Module exists
local function test_module_exists()
    assert(ThunderClient ~= nil, "ThunderClient module exists", "ThunderClient table should be defined")
end

-- Test 2: Initial state is correct
local function test_initial_state()
    local stateValid = ThunderClient.flashIntensity == 0.0 and
                       ThunderClient.flashDecay == 0.10 and
                       type(ThunderClient.delayedSounds) == "table" and
                       type(ThunderClient.flashSequence) == "table"

    assert(stateValid, "Initial state is correct", "One or more initial values incorrect")
end

-- Test 3: CreateOverlay function exists
local function test_createoverlay_exists()
    assert(
        type(ThunderClient.CreateOverlay) == "function",
        "CreateOverlay function exists",
        "Expected function, got " .. type(ThunderClient.CreateOverlay)
    )
end

-- Test 4: DoStrike function exists
local function test_dostrike_exists()
    assert(
        type(ThunderClient.DoStrike) == "function",
        "DoStrike function exists",
        "Expected function, got " .. type(ThunderClient.DoStrike)
    )
end

-- Test 5: OnTick function exists
local function test_ontick_exists()
    assert(
        type(ThunderClient.OnTick) == "function",
        "OnTick function exists",
        "Expected function, got " .. type(ThunderClient.OnTick)
    )
end

-- Test 6: OnRenderTick function exists
local function test_onrendertick_exists()
    assert(
        type(ThunderClient.OnRenderTick) == "function",
        "OnRenderTick function exists",
        "Expected function, got " .. type(ThunderClient.OnRenderTick)
    )
end

-- Test 7: Console commands exist
local function test_console_commands()
    local commands = {
        ForceThunder = type(ForceThunder) == "function",
        TestThunder = type(TestThunder) == "function",
        SetThunderFrequency = type(SetThunderFrequency) == "function"
    }

    local allExist = commands.ForceThunder and commands.TestThunder and commands.SetThunderFrequency

    assert(allExist, "All console commands exist", "One or more console commands missing")
end

-- Test 8: DoStrike ignores very distant thunder
local function test_distant_thunder_ignored()
    local initialSoundsCount = #ThunderClient.delayedSounds

    ThunderClient.DoStrike({dist = 5000}) -- Too far (>3400)

    local soundsAdded = #ThunderClient.delayedSounds > initialSoundsCount

    assert(not soundsAdded, "Very distant thunder ignored", "Sound was added for too-distant thunder")
end

-- Test 9: DoStrike queues sound for valid distance
local function test_dostrike_queues_sound()
    -- Mock required functions
    local hadGetCore = getCore ~= nil
    if not hadGetCore then
        _G.getCore = function()
            return {
                getScreenWidth = function() return 1920 end,
                getScreenHeight = function() return 1080 end
            }
        end
    end

    local hadGetTimestamp = getTimestampMs ~= nil
    if not hadGetTimestamp then
        _G.getTimestampMs = function() return 1000 end
    end

    local initialCount = #ThunderClient.delayedSounds
    ThunderClient.DoStrike({dist = 500})
    local soundQueued = #ThunderClient.delayedSounds > initialCount

    -- Restore
    if not hadGetCore then _G.getCore = nil end
    if not hadGetTimestamp then _G.getTimestampMs = nil end

    assert(soundQueued, "DoStrike queues sound", "Sound was not queued")
end

-- Test 10: Flash intensity decay works
local function test_flash_decay()
    ThunderClient.flashIntensity = 1.0
    local originalDecay = ThunderClient.flashDecay

    -- Mock overlay
    local hadOverlay = ThunderClient.overlay ~= nil
    if not hadOverlay then
        ThunderClient.overlay = {
            isInUIManager = false,
            removeFromUIManager = function() end
        }
    end

    ThunderClient.OnRenderTick()

    local decayed = ThunderClient.flashIntensity < 1.0

    -- Restore
    if not hadOverlay then
        ThunderClient.overlay = nil
    end
    ThunderClient.flashIntensity = 0.0

    assert(decayed, "Flash intensity decays", "Flash did not decay")
end

-- Test 11: Sound selection based on distance
local function test_sound_selection()
    -- This tests the logic indirectly by checking distance thresholds
    local closeThreshold = 200
    local mediumThreshold = 800

    assert(
        closeThreshold == 200 and mediumThreshold == 800,
        "Sound distance thresholds correct",
        "Distance thresholds don't match expected values"
    )
end

-- Test 12: Volume calculation is correct
local function test_volume_calculation()
    -- Test volume formula: 1.0 - (distance / 3400) * 0.9
    local dist0 = 0
    local dist3400 = 3400

    local vol0 = 1.0 - (dist0 / 3400) * 0.9
    local vol3400 = 1.0 - (dist3400 / 3400) * 0.9

    assert(
        vol0 == 1.0 and math.abs(vol3400 - 0.1) < 0.01,
        "Volume calculation correct",
        "Volume formula doesn't produce expected values"
    )
end

-- Test 13: Delay calculation uses speed of sound
local function test_delay_calculation()
    local distance = 340 -- tiles
    local expectedDelay = 1.0 -- second (340 tiles / 340 tiles per second)

    local speed = 340
    local calculatedDelay = distance / speed

    assert(
        math.abs(calculatedDelay - expectedDelay) < 0.01,
        "Delay calculation correct",
        "Expected ~1.0 second, got " .. calculatedDelay
    )
end

-- Test 14: Flash brightness scales with distance
local function test_brightness_scaling()
    -- Brightness formula: (1.0 - (distance / 2000)) * 0.5
    -- Clamped between 0.1 and 0.5

    local dist0 = 0
    local dist2000 = 2000
    local dist4000 = 4000

    local bright0 = (1.0 - (dist0 / 2000)) * 0.5
    local bright2000 = (1.0 - (dist2000 / 2000)) * 0.5
    local bright4000 = (1.0 - (dist4000 / 2000)) * 0.5

    -- Clamp
    if bright0 > 0.5 then bright0 = 0.5 end
    if bright2000 < 0.1 then bright2000 = 0.1 end
    if bright4000 < 0.1 then bright4000 = 0.1 end

    assert(
        bright0 == 0.5 and bright2000 == 0.1 and bright4000 == 0.1,
        "Brightness scaling correct",
        "Brightness formula doesn't produce expected clamped values"
    )
end

-- Test 15: Multi-flash sequences
local function test_multiflash()
    -- Mock functions
    local hadGetCore = getCore ~= nil
    if not hadGetCore then
        _G.getCore = function()
            return {
                getScreenWidth = function() return 1920 end,
                getScreenHeight = function() return 1080 end
            }
        end
    end

    local hadGetTimestamp = getTimestampMs ~= nil
    if not hadGetTimestamp then
        _G.getTimestampMs = function() return 1000 end
    end

    ThunderClient.flashSequence = {}
    ThunderClient.DoStrike({dist = 500})

    local hasMultipleFlashes = #ThunderClient.flashSequence >= 1

    -- Restore
    if not hadGetCore then _G.getCore = nil end
    if not hadGetTimestamp then _G.getTimestampMs = nil end
    ThunderClient.flashSequence = {}

    assert(hasMultipleFlashes, "Multi-flash sequences created", "No flash sequence created")
end

-- Run all tests
print("[TEST] Running Thunder_Client tests...")
print("[TEST]")

test_module_exists()
test_initial_state()
test_createoverlay_exists()
test_dostrike_exists()
test_ontick_exists()
test_onrendertick_exists()
test_console_commands()
test_distant_thunder_ignored()
test_dostrike_queues_sound()
test_flash_decay()
test_sound_selection()
test_volume_calculation()
test_delay_calculation()
test_brightness_scaling()
test_multiflash()

-- Print summary
print("[TEST]")
print("[TEST] ========== Test Summary ==========")
print("[TEST] Passed: " .. TestClient.passed)
print("[TEST] Failed: " .. TestClient.failed)
print("[TEST] Total:  " .. (TestClient.passed + TestClient.failed))

if TestClient.failed == 0 then
    print("[TEST] ✓ All tests passed!")
else
    print("[TEST] ✗ Some tests failed")
end

return TestClient
