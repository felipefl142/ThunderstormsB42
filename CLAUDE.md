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

#### Thunder Triggering (Server)
```lua
-- Requirements for automatic thunder:
- Cloud intensity > 0.2 (20%)
- No active cooldown
- Random chance per tick: baseChance (0.5) × cloudIntensity
- Cooldown after strike: 140 ticks + random(0 to intensityFactor × 1000)
```

#### Visual Flash (Client)
- Full-screen ISUIElement overlay
- Only added to UI manager during flash (prevents mouse blocking)
- Uses `render()` function (not `prerender` - Build 42.13 compatibility)
- Flash intensity: 0.1-0.5 alpha based on distance
- Multi-flash sequences (1-3 stuttered pulses)
- Decay rate: 0.10 per render tick

#### Audio System (Client)
- Three sound categories: `ThunderClose` (<200 tiles), `ThunderMedium` (<800 tiles), `ThunderFar` (≥800 tiles)
- Dynamic volume: 1.0 at 0 tiles → 0.1 at 3400 tiles (linear fallback)
- Max hearing distance: 3400 tiles
- 3D audio via `PlayWorldSound()` at player square (provides indoor muffling)
- Sound definitions in `Thunderstorms_sounds.txt` (is3D=true, category=Ambient)

## Testing Commands

All commands available in Lua console (backtick `` ` `` or `~` key):

```lua
-- Force thunder at specific distance
ForceThunder(200)       -- Close thunder
ForceThunder(1000)      -- Medium thunder
ForceThunder(3000)      -- Far thunder

-- Test thunder effect directly (client-side)
TestThunder(500)

-- Adjust automatic thunder frequency
SetThunderFrequency(0.5)   -- Default (less frequent)
SetThunderFrequency(2.0)   -- More frequent
SetThunderFrequency(0.25)  -- Very rare

-- Check current cloud intensity
print(getClimateManager():getCloudIntensity())
```

## Critical Build 42.13 Compatibility Issues

### Known Breaking Changes
1. **`ISPanel:setBackgroundColor()` removed** - Use direct field assignment: `panel.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.8}`
2. **`prerender()` deprecated** - Use `render()` with `ISUIElement.render(self)` call
3. **ISUIElement requires explicit require** - Add `require "ISUI/ISUIElement"` at top of client files
4. **Overlay mouse blocking** - Overlays added to UI manager permanently block input; must add/remove dynamically

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

Enable debug logging by checking console output with prefixes:
- `[ThunderServer]` - Server-side events
- `[ThunderClient]` - Client-side VFX/SFX
- `[ThunderUI]` - UI events (currently just "DISABLED" message)

Common issues:
- **No VFX/SFX on TestThunder():** Check that `ISUIElement` is required and `render()` function is used (not `prerender`)
- **Mouse/keyboard broken after thunder:** Overlay not removed from UI manager; check `isInUIManager` flag logic
- **No automatic thunder:** Cloud intensity likely <0.2; check with `getClimateManager():getCloudIntensity()`
- **Silent thunder:** Check distance <3400 tiles and volume calculation; verify 3D sounds defined in scripts

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
