# Better Thunder (B42) - Test Suite

Comprehensive test suite for the Better Thunder mod using the Busted testing framework.

## Overview

This test suite provides:
- **47+ tests** covering all mod components
- **Unit tests** for isolated functions and configuration
- **Component tests** for client/server modules
- **Integration tests** for client-server communication
- **Comprehensive mocks** for Project Zomboid API
- **CLI-optimized** for fast execution and clear output

## Running Tests

### Busted Tests (Recommended)

Quick start:

```bash
cd tests
./run_busted.sh
```

Run all tests:

```bash
cd tests
busted spec/
```

Run specific test suites:

```bash
# Unit tests only
busted spec/unit/

# Component tests only
busted spec/component/

# Integration tests only
busted spec/integration/

# Specific file
busted spec/component/Thunder_Client_spec.lua
```

### Legacy Tests (In-Game Console)

The original test files are preserved in the `legacy/` folder. To run these in-game, you must copy the `tests` directory into the mod's lua folder (`media/lua/tests`).

Then from Lua console in-game:

```lua
require "tests/legacy/RunAllTests"
```

Or individual suites:

```lua
require "tests/legacy/Thunder_Shared_Test"
require "tests/legacy/Thunder_Server_Test"
require "tests/legacy/Thunder_Client_Test"
require "tests/legacy/Thunder_UI_Test"
```

## Test Structure

```
tests/
├── .busted                        # Busted configuration
├── spec/
│   ├── spec_helper.lua           # Shared test utilities
│   ├── mocks/
│   │   └── pz_api_mock.lua       # Project Zomboid API mocks
│   ├── unit/                     # Unit tests (isolated functions)
│   │   └── Thunder_Shared_spec.lua
│   ├── component/                # Component tests (related functions)
│   │   ├── Thunder_Server_spec.lua
│   │   ├── Thunder_Client_spec.lua
│   │   └── Thunder_UI_spec.lua
│   └── integration/              # Integration tests (client-server)
│       └── network_spec.lua
├── legacy/                       # Backward compatibility
│   ├── Thunder_Shared_Test.lua
│   ├── Thunder_Server_Test.lua
│   ├── Thunder_Client_Test.lua
│   ├── Thunder_UI_Test.lua
│   └── RunAllTests.lua
├── run_busted.sh                 # CLI test runner script
└── README.md                     # This file
```

## Test Coverage

### Thunder_Shared (Unit Tests)
- Module structure validation
- Config values (gameplay, physics, thunder system)
- Parameter ranges (probability, weights, cooldown, distance)

### Thunder_Server (Component Tests)
- Module structure
- Storm intensity calculation (0-1.0 range, multi-factor)
- Thunder probability (sigmoid curve)
- Cooldown system (5-60s dynamic, decrement on tick)
- Strike distance (min/max bounds, intensity correlation)
- TriggerStrike (command sending, forced vs calculated distance)
- Console command integration
- Native mode (UseNativeWeatherEvents flag)

### Thunder_Client (Component Tests)
- Module structure (initial state, feature flags)
- Overlay management (creation, dimensions, ignore events, UI manager)
- Indoor detection (IsPlayerIndoors, room detection, nil handling)
- Lightning flash effects (light creation, multi-point indoors, radius scaling, cleanup)
- DoStrike (distance filtering, sound queue, overlay, flash sequence, delay)
- Sound selection (ThunderClose <200, ThunderMedium <800, ThunderFar ≥800)
- Volume calculation (distance-based, indoor modifier 0.75-0.9)
- Flash system (brightness 0.1-0.5, multi-flash 30%)
- Flash decay (time-based 2.5/s, clamp to 0, overlay removal)
- OnTick audio processing (delayed sounds queue)
- OnRenderTick flash processing (sequence triggering, overlay/lighting)
- Debug mode toggle
- Feature toggles (lighting, indoor detection)

### Thunder_UI (Component Tests)
- Disabled state validation
- Structural validation (for re-enabling)
- ISUI dependencies
- Button configuration
- Slider range
- Command structure
- Window dimensions

### Network (Integration Tests)
- Server triggers → client receives
- Command transmission validation
- Single-player mode (both client and server)
- Multi-client scenarios
- Network latency simulation
- Command args preservation

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
