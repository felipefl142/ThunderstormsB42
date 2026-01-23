# Better Thunder (B42) - Test Suite

This directory contains comprehensive unit tests for all main modules of the Better Thunder mod.

## Test Files

- **Thunder_Shared_Test.lua** - Tests for shared configuration and constants
- **Thunder_Server_Test.lua** - Tests for server-side thunder triggering logic
- **Thunder_Client_Test.lua** - Tests for client-side VFX/SFX effects
- **Thunder_UI_Test.lua** - Tests for UI components (currently disabled)
- **RunAllTests.lua** - Master test runner that executes all test suites

## Running Tests

### Run All Tests

Open the Lua console in-game (backtick `` ` `` or `~` key) and type:

```lua
require "tests/RunAllTests"
```

### Run Individual Test Suites

```lua
-- Test shared config
require "tests/Thunder_Shared_Test"

-- Test server logic (server-side only)
require "tests/Thunder_Server_Test"

-- Test client effects (client-side only)
require "tests/Thunder_Client_Test"

-- Test UI structure
require "tests/Thunder_UI_Test"
```

## Test Coverage

### Thunder_Shared_Test.lua (8 tests)
- Module structure validation
- NetTag verification
- Config table completeness
- Gameplay value ranges
- Physics constants (speed of sound)
- Config immutability

### Thunder_Server_Test.lua (12 tests)
- Module initialization
- Config value validation
- OnTick function behavior
- TriggerStrike logic
- Cooldown timer mechanics
- Console command availability
- Dynamic cooldown based on cloud intensity
- Distance range validation
- Frequency adjustment

### Thunder_Client_Test.lua (15 tests)
- Module initialization
- Initial state validation
- Overlay creation and management
- DoStrike function logic
- Flash intensity and decay
- Sound queuing and delay calculation
- Volume scaling with distance
- Sound selection by distance thresholds
- Multi-flash sequences
- Physics-based delay (speed of sound)
- Brightness scaling with distance
- Event handler registration

### Thunder_UI_Test.lua (12 tests)
- UI disabled state verification
- Toggle function existence
- Class initialization check
- Event handler registration
- Console command fallback
- Window structure validation
- Button configuration
- Frequency slider range
- Command structure
- Debug mode flags
- Window dimensions
- Input safety (mouse blocking prevention)

## Test Output

Each test prints:
- `✓ PASS: [test name]` - Test succeeded
- `✗ FAIL: [test name]` - Test failed (with reason)

At the end of each suite:
```
========== Test Summary ==========
Passed: X
Failed: Y
Total:  Z
✓ All tests passed!
```

## Test Architecture

All tests use a simple assertion-based framework:

```lua
local function assert(condition, testName, message)
    if condition then
        TestModule.passed = TestModule.passed + 1
        print("[TEST] ✓ PASS: " .. testName)
    else
        TestModule.failed = TestModule.failed + 1
        print("[TEST] ✗ FAIL: " .. testName)
        print("[TEST]   Reason: " .. message)
    end
end
```

## Mocking

Some tests mock Project Zomboid API functions when running in isolated environments:
- `getClimateManager()` - For weather data
- `getCore()` - For screen dimensions
- `getTimestampMs()` - For timing
- `sendServerCommand()` / `sendClientCommand()` - For network messages

## Client/Server Separation

Tests automatically skip when run on the wrong side:
- `Thunder_Server_Test.lua` only runs on server (`if isClient() then return end`)
- `Thunder_Client_Test.lua` only runs on client (`if isServer() then return end`)
- `Thunder_Shared_Test.lua` runs on both sides

## Continuous Integration

While Project Zomboid doesn't have native CI support, you can run these tests:
1. Launch a dedicated server or singleplayer game
2. Open Lua console
3. Run `require "tests/RunAllTests"`
4. Check console output for failures

## Contributing

When adding new features to the mod:
1. Write tests for new functionality
2. Run all tests to ensure no regressions
3. Update this README with new test descriptions
4. Ensure tests pass on both client and server (where applicable)

## Known Limitations

- UI tests are structural only (UI is currently disabled)
- Some tests require mocking of PZ API functions
- Visual and audio effects cannot be fully validated programmatically
- Network message sending is mocked (actual server communication not tested)

## Future Improvements

- Add integration tests for client-server communication
- Add performance benchmarks (flash decay, sound queuing)
- Add randomization testing (ZombRand behavior)
- Add event handler lifecycle tests
- Add memory leak detection for overlay management
