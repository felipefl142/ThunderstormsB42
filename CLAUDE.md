# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Better Thunder (B42)** is a Project Zomboid mod that adds immersive, physics-based lightning and thunder effects with multiplayer support. The mod simulates realistic sound delays based on distance (speed of sound ~340m/s) and provides dynamic visual flashes.

**Workshop ID:** 3651047804
**Mod ID:** BetterThunder42

## Repository Structure

This is a **dual-version mod** supporting both Build 42 and Build 42.13+:

```
Thunderstorms v2/
├── Contents/mods/Thunderstorms/
│   ├── 42/          # Build 42 (legacy)
│   └── 42.13/       # Build 42.13+ (active development)
│       └── media/
│           ├── lua/
│           │   ├── client/    # Client-side VFX/SFX
│           │   ├── server/    # Server-side thunder logic
│           │   └── shared/    # Shared config
│           ├── scripts/       # Sound definitions
│           └── sound/         # .ogg audio files
├── mod.info
└── workshop.txt
```

**Active development folder:** `Thunderstorms v2/Contents/mods/Thunderstorms/42.13/`

## Architecture

### Client-Server Split

The mod uses Project Zomboid's client-server architecture with networked events:

1. **Server (`Thunder_Server.lua`):**
   - Monitors weather conditions (cloud intensity)
   - Triggers thunder strikes based on chance and cooldown
   - Sends `LightningStrike` commands to all clients with distance data
   - Handles console commands: `ForceThunder(dist)`, `TestThunder(dist)`, `SetThunderFrequency(freq)`

2. **Client (`Thunder_Client.lua`):**
   - Receives `LightningStrike` commands from server
   - Creates visual flash overlay (ISUIElement fullscreen white flash)
   - Calculates physics-based sound delay (distance / 340 tiles per second)
   - Plays 3D positional audio at player location (omnidirectional with indoor muffling)
   - Manages flash intensity decay and overlay lifecycle

3. **Shared (`Thunder_Shared.lua`):**
   - Contains shared configuration (currently minimal)

4. **UI (`Thunder_UI.lua`):**
   - **CURRENTLY DISABLED** (early return at line 3)
   - UI was causing game-breaking bugs in Build 42.13
   - Console commands are the primary interface

### Key Systems

#### IsoRegions Integration (Client)
- **Indoor/Outdoor Detection:** Uses `IsoGridSquare:getRoom()` to detect if player is in an enclosed space
- **Sound Muffling:** Indoor thunder has reduced volume (30-50% reduction) to simulate wall absorption
- **Distance-Based Modifier:** Closer thunder is more muffled indoors (0.5-0.7 multiplier range)
- **Room Detection:** Compatible with both vanilla buildings and player-built structures
- **Debug Output:** Shows room name when player is indoors and debug mode is enabled

#### Lighting System Integration (Client)
- **Dynamic Light Sources:** Creates temporary lightning flashes using `IsoCell:addLamppost()`
- **Main Flash:** Single bright white/blue light source at player position (10-30 tile radius)
- **Multi-Point Illumination:** When indoors, creates 8 additional light sources in cardinal/diagonal directions
- **Window/Door Propagation:** Ambient lights simulate lightning entering through openings
- **Color Simulation:** RGB ~(0.9, 0.9, 1.0) for realistic blue-white lightning
- **Auto Cleanup:** Lights removed after 400ms using `IsoCell:removeLamppost()`
- **Build 42 Compatibility:** Uses new lighting propagation system that respects walls and openings

#### Thunder Triggering (Server)
```lua
-- Requirements for automatic thunder:
- Cloud intensity > 0.2 (20%)
- No active cooldown
- Random chance per tick: baseChance (0.02) × cloudIntensity
- Minimum cooldown: 10 seconds (600 ticks)
- Variable cooldown: minCooldown + random(0 to intensityFactor × 1000 ticks)
- Higher cloud intensity = shorter cooldown between strikes
```

#### Visual Flash (Client)
- Full-screen ISUIElement overlay
- Only added to UI manager during flash (prevents mouse blocking)
- Uses `render()` function (not `prerender` - Build 42.13 compatibility)
- Flash intensity: 0.1-0.5 alpha based on distance
- Multi-flash sequences: mostly single flashes, 30% chance of double flash (less strobe effect)
- Time-based decay: 2.5 alpha units per second (framerate-independent for smooth animation)
- Flash brightness scales with distance: max at 0 tiles, min at 4700+ tiles

#### Audio System (Client)
- Three sound categories: `ThunderClose` (<200 tiles), `ThunderMedium` (<800 tiles), `ThunderFar` (≥800 tiles)
- Dynamic volume: 1.0 at 0 tiles → 0.1 at 8000 tiles (linear fallback)
- Max hearing distance: 8000 tiles
- 3D audio via `PlayWorldSound()` at player square (provides indoor muffling)
- Sound definitions in `Thunderstorms_sounds.txt` (is3D=true, category=Ambient)

## Testing Commands

All commands available in Lua console (backtick `` ` `` or `~` key):

```lua
-- Force thunder at specific distance
ForceThunder(200)       -- Close thunder
ForceThunder(1000)      -- Medium thunder
ForceThunder(7000)      -- Far thunder (new max: 8000 tiles)

-- Test thunder effect directly (client-side)
TestThunder(500)

-- Adjust automatic thunder frequency
SetThunderFrequency(0.5)   -- Default (less frequent)
SetThunderFrequency(2.0)   -- More frequent
SetThunderFrequency(0.25)  -- Very rare

-- Toggle debug logging (shows detailed strike information)
ThunderToggleDebug()      -- Toggle on/off
ThunderToggleDebug(true)  -- Enable
ThunderToggleDebug(false) -- Disable

-- Toggle Native Mode (sync with game weather)
SetNativeMode(true)       -- Enable Native Mode
SetNativeMode(false)      -- Disable Native Mode (use custom generator)

-- Toggle dynamic lightning lighting effects
ThunderToggleLighting(true)   -- Enable lighting
ThunderToggleLighting(false)  -- Disable lighting
ThunderToggleLighting()       -- Toggle current state

-- Toggle indoor/outdoor sound detection
ThunderToggleIndoorDetection(true)   -- Enable indoor muffling
ThunderToggleIndoorDetection(false)  -- Disable indoor muffling
ThunderToggleIndoorDetection()       -- Toggle current state

-- Check current cloud intensity
print(getClimateManager():getCloudIntensity())
```

## Critical Build 42.13 Compatibility Issues

### Known Breaking Changes
1. **`ISPanel:setBackgroundColor()` removed** - Use direct field assignment: `panel.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.8}`
2. **`prerender()` deprecated** - Use `render()` with `ISUIElement.render(self)` call
3. **ISUIElement requires explicit require** - Add `require "ISUI/ISUIElement"` at top of client files
4. **Overlay mouse blocking** - Overlays added to UI manager permanently block input; must add/remove dynamically
5. **Guard clause loading issue** - Calling `isClient()` or `isServer()` in string concatenation during file load can cause silent failures; use guard clauses before any complex operations

### UI State
The Thunder UI (`Thunder_UI.lua`) is **completely disabled** via early return. Attempts to re-enable require:
- Fixing Build 42.13 API compatibility issues
- Preventing UI from breaking game mouse/keyboard input
- Testing thoroughly before uncommenting event handlers at end of file

## Sound File Conventions

Sound files in `media/sound/`:
- **Close:** Long crackling (2-5s), short snaps (1-2s)
- **Medium/Far:** Rolling rumbles (3-6s), short echoes (1-2s)
- **Format:** .ogg Vorbis, mono or stereo
- **Naming:** `{Distance}-{duration}.ogg` (e.g., `Close-long.ogg`)

Sound script (`Thunderstorms_sounds.txt`):
- Module: `MyThunder`
- is3D: `true` (enables indoor muffling)
- category: `Ambient`
- volume: `1.0` (dynamic volume applied in code)

## Debugging

Enable debug logging using `ThunderToggleDebug()` console command (renamed from `ThunderDebug` to avoid conflict with game's climate debugger).

Console output prefixes:
- `[ThunderServer]` - Server-side events
- `[ThunderClient]` - Client-side VFX/SFX
- `[ThunderUI]` - UI events (currently just "DISABLED" message)

Debug mode shows:
- File loading status and guard clause checks
- Thunder strike distance and timing
- Flash intensity and multi-flash sequences
- Sound selection and volume calculations
- Overlay lifecycle (add/remove from UI manager)

Common issues:
- **No VFX/SFX on TestThunder():** Check that `ISUIElement` is required and `render()` function is used (not `prerender`)
- **Mouse/keyboard broken after thunder:** Overlay not removed from UI manager; check `isInUIManager` flag logic
- **No automatic thunder:** Cloud intensity likely <0.2; check with `getClimateManager():getCloudIntensity()`
- **Silent thunder:** Check distance <8000 tiles and volume calculation; verify 3D sounds defined in scripts
- **No lightning lights appearing:** Verify `ThunderClient.useLighting` is true; check that `getCell()` returns valid IsoCell
- **Lights not disappearing:** Check `CleanupLights()` is called in `OnRenderTick()`; verify timestamp calculations
- **Indoor detection not working:** Ensure player is in a room with proper IsoRegion data; try rebuilding walls to refresh regions

## Publishing

To upload to Steam Workshop:
1. Update version in `workshop.txt`
2. Test both manual commands and automatic thunder in-game
3. Verify VFX (flash) and SFX (sound) work correctly
4. Check UI doesn't break game controls (currently disabled for safety)
5. Upload via Project Zomboid's built-in workshop tools or SteamCMD

## Development Notes

- **Primary development focus:** Build 42.13 (`42.13/` folder)
- **Build 42 folder:** Legacy support, not actively maintained
- **No azimuth/direction:** Thunder is omnidirectional (heard equally from all directions)
- **Physics accuracy:** Speed of sound is 340 tiles/second (meters/second equivalent)
- **Network optimization:** Only distance is transmitted; clients calculate flash/sound locally

## Recent Changes

### v1.6 (Jan 2026) - IsoRegions & Lighting Integration
- **Added IsoRegions indoor/outdoor detection:** Automatically detects when player is in an enclosed space using `IsoGridSquare:getRoom()`
- **Indoor sound muffling:** Thunder volume reduced by 30-50% when indoors, with distance-based modifier (closer = more muffled)
- **Dynamic lightning lighting:** Creates temporary light sources using `IsoCell:addLamppost()` with 400ms duration
- **Multi-point illumination:** When indoors, creates 8 ambient light sources in cardinal/diagonal directions to simulate light entering through windows/doors
- **Realistic light colors:** White/blue-white RGB values (~0.9, 0.9, 1.0) simulate actual lightning color temperature
- **Adaptive light radius:** Scales with flash intensity (10-30 tile radius) and distance from strike
- **New console commands:** `ThunderToggleLighting()` and `ThunderToggleIndoorDetection()` for feature control
- **Build 42 lighting integration:** Uses new lighting propagation system that respects walls, windows, and room boundaries
- **Performance optimized:** Automatic light cleanup, minimal memory overhead, efficient region queries
- **Reduced base spawn chance:** Further reduced from 0.05 to 0.02 for more realistic thunder frequency

### v1.5.1 (Jan 2026) - Native Mode Completion & Compatibility
- **Completed server-side Native Mode integration:** Added missing `OnNativeThunder` event handler to `Thunder_Server.lua` that maps game events to physics-based strikes
- **Defensive event registration:** Added nil checks for all event registrations to prevent crashes on older PZ versions
- **Improved version compatibility:** Graceful handling when `Events.OnThunder` is not available, with helpful warning messages
- **Command alias:** Added `SetNativeMode` as an alias for `ServerToggleNativeMode` for consistency with client commands
- **Bug fix:** Prevents mod from crashing on PZ versions that lack certain events

### v1.5 (Jan 2026) - Native Mode Support
- **Added Native Mode:** Optional configuration to sync thunder strikes with Project Zomboid's internal weather events.
- **`UseNativeWeatherEvents` flag:** Set to `true` in `Thunder_Shared.lua` to disable custom generation and listen to game's `OnThunder` event.
- **New Console Command:** `SetNativeMode(bool)` to toggle mode at runtime.
- **Benefit:** Perfect synchronization with foraging bonuses/penalties and moodles that rely on game-native thunder events.

### v1.4.1 (Jan 2026) - Console Command Hotfix
- **Fixed "attempt to call nil" errors** for console commands (`ForceThunder`, `TestThunder`) by removing restrictive `isClient()`/`isServer()` guard clauses at file start
- Ensures global functions are properly defined during initialization phases (including Single Player)

### v1.4 (Jan 2026) - Extended Range & Bug Fixes
- **Increased max hearing distance from 3400 to 8000 tiles** for more realistic long-distance thunder
- **Fixed silent loading failure** caused by calling `isClient()`/`isServer()` in string concatenation during file load
- **Renamed ThunderDebug() to ThunderToggleDebug()** to avoid conflict with game's climate debugger
- **Improved flash animation** with time-based decay (2.5 alpha units/second) for framerate-independent smoothness
- **Simplified flash patterns** to reduce strobe effect (mostly single flashes, 30% double flash chance)
- **Increased minimum cooldown** from 140 ticks to 10 seconds (600 ticks) for better pacing
- **Reduced base spawn chance** from 0.5 to 0.05 to balance with higher cloud intensity multiplier
- **Fixed PlayWorldSound radius** increased to 1000 for better audio coverage

### v1.3 (Jan 2026) - Build 42.13 Compatibility
- **Disabled Thunder_UI.lua** to resolve game-breaking syntax crash
- **Migrated to Build 42.13 API** using `render()` instead of deprecated `prerender()`
- **Added dynamic overlay management** to prevent mouse/keyboard blocking
- **Implemented ISUIElement explicit require** for B42.13 compatibility
