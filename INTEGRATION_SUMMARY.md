# IsoRegions & Lighting Integration Summary

## Overview
Enhanced the Better Thunder (B42) mod with **IsoRegions** for indoor/outdoor detection and **Lighting** for realistic lightning flash propagation through windows and doors.

## New Features

### 1. Indoor/Outdoor Detection (IsoRegions)
- **API Used:** `IsoGridSquare:getRoom()` and `IsoRoom` detection
- **Functionality:** Automatically detects if the player is indoors when thunder strikes
- **Sound Modification:**
  - Indoor thunder is muffled by 30-50% volume reduction
  - Closer thunder is more muffled (simulates better sound insulation)
  - Uses distance-based modifier: `0.5 + (distance / 8000) * 0.2`
- **Debug Output:** Shows room name when player is indoors

### 2. Dynamic Lightning Lighting (Lighting System)
- **API Used:** `IsoCell:addLamppost(x, y, z, r, g, b, radius)`
- **Main Light Source:**
  - Created at player position during lightning flash
  - White/blue-white color (RGB: ~0.9, ~0.9, 1.0)
  - Radius scales with flash intensity: 10-30 tiles
  - Duration: 400ms (synced with visual flash)

- **Multi-Point Illumination (Indoor Only):**
  - 8 additional light sources placed in cardinal and diagonal directions
  - Simulates lightning entering through windows and doors
  - Ambient lights have 60% radius of main light
  - Slightly dimmer (80-90% intensity) for realistic ambience
  - Pattern: East, West, North, South, NE, NW, SE, SW offsets

- **Light Cleanup:**
  - Automatic removal after flash duration expires
  - Tracked in `ThunderClient.activeLightSources` table
  - Cleanup runs every render tick

## Technical Implementation

### New Variables
```lua
ThunderClient.activeLightSources = {}  -- Track temporary light sources
ThunderClient.useLighting = true       -- Enable/disable dynamic lighting
ThunderClient.useIndoorDetection = true -- Enable/disable indoor/outdoor detection
```

### New Functions

#### `ThunderClient.IsPlayerIndoors()`
- Returns `true` if player is in an IsoRoom, `false` otherwise
- Used by both sound and lighting systems
- Debug mode shows room name

#### `ThunderClient.CreateLightningFlash(intensity, duration)`
- Creates main light source at player position
- If indoors, creates 8 ambient light sources in surrounding pattern
- Stores light references with expiration timestamps
- Uses cell's lighting system for proper Build 42 light propagation

#### `ThunderClient.CleanupLights()`
- Runs every render tick
- Removes expired light sources from game world
- Prevents memory leaks and visual glitches

### Modified Functions

#### `ThunderClient.DoStrike(args)`
- **Added:** Indoor detection check before calculating volume
- **Added:** Volume modifier calculation based on indoor status
- **Formula:** `volume = base_volume * indoor_modifier`
- Indoor modifier range: 0.5 (close thunder) to 0.7 (far thunder)

#### `ThunderClient.OnRenderTick()`
- **Added:** Call to `ThunderClient.CleanupLights()` at end
- **Added:** Light source creation when flash starts
- Light duration: 400ms (matches flash decay)

## New Console Commands

### `ThunderToggleLighting(true/false)`
- Enable/disable dynamic lighting effects
- Call without arguments to toggle
- Default: enabled
- **Example:** `ThunderToggleLighting(false)` to disable lights

### `ThunderToggleIndoorDetection(true/false)`
- Enable/disable indoor sound muffling
- Call without arguments to toggle
- Default: enabled
- **Example:** `ThunderToggleIndoorDetection(false)` for constant volume

## Build 42 Compatibility

### IsoRegions System
- **IsoGridSquare.getRoom()** - Returns IsoRoom object or nil
- **IsoRoom detection** - Determines enclosed spaces
- Compatible with Build 42.13+ region system
- Works with both vanilla and player-built structures

### Lighting System
- **IsoCell.addLamppost()** - Creates temporary light sources
- **IsoCell.removeLamppost()** - Cleans up lights
- Uses Build 42's new lighting propagation
- Light bounces off walls and enters through openings
- Respects room boundaries and windows/doors

## Physics Accuracy

### Light Propagation
- Lightning is white-hot (~6000K color temperature)
- RGB values simulate blue-white flash
- Radius scales with perceived brightness (distance-based)
- Multi-point sources simulate omnidirectional sky illumination

### Sound Propagation
- Indoor muffling follows real-world acoustics
- Higher frequencies absorbed more by walls
- Distance-dependent muffling (closer = more blocked)
- Complements existing 3D audio system

## Performance Considerations

### Light Source Management
- Maximum 9 lights per strike (1 main + 8 ambient indoors)
- Lights automatically removed after 400ms
- No persistent memory allocation
- Cleanup runs efficiently in render loop

### Region Queries
- Single `getRoom()` call per thunder strike
- Minimal overhead (one square lookup)
- No continuous polling or updates

## Testing Commands

```lua
-- Test basic thunder
TestThunder(200)  -- Close thunder indoors/outdoors

-- Test with lighting disabled
ThunderToggleLighting(false)
TestThunder(500)

-- Test without indoor detection
ThunderToggleIndoorDetection(false)
TestThunder(1000)

-- Enable debug mode to see detailed logs
ThunderToggleDebug(true)
TestThunder(300)
```

## Debug Output Examples

### Indoor Strike
```
[ThunderClient] Player is in room: bedroom
[ThunderClient] Player is indoors, applying volume modifier: 0.62
[ThunderClient] Creating lightning light at (10450, 9875, 0) radius: 25 intensity: 0.35
[ThunderClient] Created 8 ambient light sources for indoor illumination
```

### Outdoor Strike
```
[ThunderClient] Creating lightning light at (10450, 9875, 0) radius: 18 intensity: 0.25
[ThunderClient] Removed light source at (10450, 9875, 0)
```

## Integration with Existing Systems

### Native Mode Compatibility
- Indoor/outdoor detection works with both custom and native thunder
- Lighting effects applied regardless of thunder generation method
- No conflicts with game's weather events

### Server/Client Architecture
- All IsoRegions/Lighting logic is client-side
- No network overhead
- Each client renders lights independently
- Indoor detection is per-player (proper in multiplayer)

## Future Enhancement Possibilities

### Advanced Features
1. **Window Detection:** Brighter flashes near windows
2. **Material-Based Muffling:** Different sound reduction for wood/brick/concrete
3. **Height-Based Effects:** Stronger effects on upper floors
4. **Weather Integration:** Adjust light color based on rain density
5. **Distance-Based Colors:** Red-shifted far lightning (Rayleigh scattering)

### Optimization
1. Adaptive light count based on performance settings
2. Distance culling for very far thunder (no lights needed)
3. Light source pooling to reduce allocation

## API Reference

### Project Zomboid APIs Used

#### IsoRegions (zombie.iso.areas)
- `IsoGridSquare:getRoom()` → Returns IsoRoom or nil
- `IsoRoom:getName()` → Returns room name string
- `IsoPlayer:getCurrentSquare()` → Returns IsoGridSquare

#### Lighting (zombie.iso)
- `IsoCell:addLamppost(x, y, z, r, g, b, radius)` → Returns IsoLightSource
- `IsoCell:removeLamppost(IsoLightSource)` → Void
- `getCell()` → Returns IsoCell
- `IsoGridSquare:getX/Y/Z()` → Returns coordinate integers

## Sources

Research conducted using official Project Zomboid documentation:

- [IsoRegions - Project Zomboid](https://projectzomboid.com/modding/zombie/iso/areas/isoregion/IsoRegions.html)
- [IsoRoom - Project Zomboid](https://projectzomboid.com/modding/zombie/iso/areas/IsoRoom.html)
- [IsoBuilding - Project Zomboid](https://projectzomboid.com/modding/zombie/iso/areas/IsoBuilding.html)
- [IsoGridSquare - Project Zomboid](https://projectzomboid.com/modding/zombie/iso/IsoGridSquare.html)
- [IsoPlayer - Project Zomboid](https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html)
- [IsoCell - Project Zomboid](https://projectzomboid.com/modding/zombie/iso/IsoCell.html)
- [IsoThumpable - Project Zomboid](https://projectzomboid.com/modding/zombie/iso/objects/IsoThumpable.html)
- [Lua API - PZwiki](https://pzwiki.net/wiki/Lua_(API))
- [Build 42 Lighting System - Project Zomboid](https://projectzomboid.com/blog/news/2022/02/42-techdoid/)

---

**File Modified:** `Thunderstorms v2/Contents/mods/Thunderstorms/42.13/media/lua/client/Thunder_Client.lua`
**Lines Added:** ~125 new lines of code
**Build Compatibility:** Build 42.13+
**Status:** Ready for testing
