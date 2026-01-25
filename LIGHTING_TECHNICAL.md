# Lightning Lighting System - Technical Details

## Light Source Placement Pattern

### Outdoor Strike (Single Point)
```
            [Player]
               ★
           (Main Light)
```
- **Single light source** at player position
- **Radius:** 10-30 tiles (based on intensity)
- **Purpose:** Simple omnidirectional flash for open areas

### Indoor Strike (Multi-Point)
```
        NW(-3,-3)    N(0,-5)    NE(3,-3)
              ●         ●         ●

        W(-5,0)    [Player]    E(5,0)
              ●        ★         ●
                   (Main)

        SW(-3,3)     S(0,5)     SE(3,3)
              ●         ●         ●
```
- **9 total light sources** (1 main + 8 ambient)
- **Main (★):** Full intensity at player position
- **Ambient (●):** 60% radius, 80-90% brightness
- **Purpose:** Simulate lightning entering through windows/doors from all angles

## Code Flow Diagram

```
Thunder Strike Event
    ↓
ThunderClient.DoStrike(args)
    ↓
Calculate Flash Intensity (0.1-0.5 based on distance)
    ↓
Queue Flash in flashSequence[]
    ↓
OnRenderTick() detects flash start time
    ↓
    ├─→ Set overlay alpha (visual flash)
    │
    └─→ ThunderClient.CreateLightningFlash(intensity, duration)
            ↓
        IsPlayerIndoors()?
            ├─→ NO: Create 1 main light at player pos
            │        └─→ Store in activeLightSources[]
            │
            └─→ YES: Create 1 main + 8 ambient lights
                     └─→ Store all in activeLightSources[]
    ↓
[Flash Duration: 400ms]
    ↓
OnRenderTick() → CleanupLights()
    ↓
Check each light's endTime
    ↓
If expired: cell:removeLamppost(light)
    ↓
Remove from activeLightSources[]
```

## Data Structure

### activeLightSources Entry
```lua
{
    light = IsoLightSource,  -- Reference to game object
    endTime = timestamp,     -- getTimestampMs() + 400
    x = integer,             -- Grid X coordinate
    y = integer,             -- Grid Y coordinate
    z = integer              -- Grid Z coordinate (floor level)
}
```

## Light Properties

### Main Lightning Light
```lua
-- Position
x, y, z = player:getCurrentSquare():getX/Y/Z()

-- Color (blue-white)
r = 0.9 + ZombRandFloat(0, 0.1)  -- 0.9-1.0
g = 0.9 + ZombRandFloat(0, 0.1)  -- 0.9-1.0
b = 1.0                          -- Pure blue channel

-- Radius (intensity-based)
radius = floor(10 + (intensity * 40))  -- 10-30 tiles
```

### Ambient Lights (Indoor)
```lua
-- Offset Positions (8 directions)
offsets = {
    {dx =  5, dy =  0},  -- East
    {dx = -5, dy =  0},  -- West
    {dx =  0, dy =  5},  -- South
    {dx =  0, dy = -5},  -- North
    {dx =  3, dy =  3},  -- Southeast
    {dx = -3, dy =  3},  -- Southwest
    {dx =  3, dy = -3},  -- Northeast
    {dx = -3, dy = -3}   -- Northwest
}

-- Color (slightly dimmer)
r = main_r * 0.8   -- 0.72-0.8
g = main_g * 0.8   -- 0.72-0.8
b = main_b * 0.9   -- 0.9

-- Radius (60% of main)
radius = floor(main_radius * 0.6)  -- 6-18 tiles
```

## Build 42 Lighting Integration

### How Build 42's Lighting Works
1. **Light Propagation:** Light bounces off walls and propagates through spaces
2. **Room Boundaries:** Walls block most light, windows/doors allow passage
3. **Distance Falloff:** Light intensity decreases with distance from source
4. **Color Mixing:** Multiple light sources blend naturally
5. **Dynamic Updates:** Lighting recalculates when sources are added/removed

### Our Integration
- **addLamppost()** creates temporary light sources that Build 42's system processes
- **Multi-point sources** create realistic ambient illumination indoors
- Lights positioned around player catch windows/doors from multiple angles
- Build 42 handles the actual propagation calculations (walls, openings, etc.)
- **removeLamppost()** cleanly removes lights without visual artifacts

## Indoor Detection Logic

```lua
function ThunderClient.IsPlayerIndoors()
    player = getPlayer()
    if not player then return false end

    square = player:getCurrentSquare()
    if not square then return false end

    room = square:getRoom()  -- IsoRoom or nil
    if room then
        -- Player is in a defined room (has walls/boundaries)
        return true
    end

    -- Player is outdoors or in undefined space
    return false
end
```

### IsoRoom Detection
- **Vanilla Buildings:** Pre-defined IsoRegion data
- **Player-Built:** Dynamically created when walls form enclosed space
- **Edge Cases:** Partial structures may not register as "room"
- **Multi-Level:** Each floor level has separate room data

## Sound Modification

### Volume Calculation
```lua
-- Base volume (distance-based)
base_volume = 1.0 - (distance / 8000) * 0.9  -- 1.0 to 0.1

-- Indoor modifier (if player is indoors)
if IsPlayerIndoors() then
    -- Closer thunder is MORE muffled (better insulation effect)
    indoor_modifier = 0.5 + (distance / 8000) * 0.2  -- 0.5 to 0.7
else
    indoor_modifier = 1.0  -- No change
end

-- Final volume
final_volume = base_volume * indoor_modifier
```

### Why Distance-Based Muffling?
- **Close Thunder (high frequency):** More affected by walls → 50% modifier
- **Far Thunder (low frequency):** Less affected by walls → 70% modifier
- **Physics:** Higher frequencies are absorbed more by building materials
- **Realism:** Simulates how bass rumble penetrates walls better than sharp cracks

## Performance Analysis

### Per Thunder Strike

**Outdoor:**
- 1 × `IsPlayerIndoors()` call → 3 object lookups (player, square, room)
- 1 × `addLamppost()` → Create 1 IsoLightSource
- 1 × light entry added to activeLightSources table

**Indoor:**
- 1 × `IsPlayerIndoors()` call → 3 object lookups
- 9 × `addLamppost()` → Create 9 IsoLightSource objects
- 8 × `getGridSquare()` → Validate offset positions
- 9 × light entries added to table

### Cleanup (Per Render Tick)
- Loop through activeLightSources (0-9 entries max per recent strike)
- Compare timestamps (integer comparison)
- Call `removeLamppost()` for expired lights
- Remove from table

### Memory Overhead
- **Light Object:** ~100 bytes (IsoLightSource reference)
- **Table Entry:** ~80 bytes (light + metadata)
- **Max Active:** ~1620 bytes (9 lights × 180 bytes)
- **Duration:** 400ms (0.4 seconds)
- **Typical:** 180-540 bytes (1-3 lights from overlapping strikes)

### CPU Impact
- **Negligible:** Light creation is one-time per flash
- **Build 42 Handles:** All propagation calculations done by game engine
- **No Continuous Updates:** Lights are static once created
- **Fast Cleanup:** Simple timestamp comparison loop

## Testing Scenarios

### Test Case 1: Outdoor Thunder
```lua
-- Go outside (no roof overhead)
TestThunder(300)

-- Expected:
-- ✓ Single light source at player
-- ✓ Full volume (no indoor modifier)
-- ✓ Flash visible from all angles
-- ✗ No ambient lights created
```

### Test Case 2: Indoor Thunder (Room with Windows)
```lua
-- Go inside a room with windows
ThunderToggleDebug(true)
TestThunder(500)

-- Expected:
-- ✓ "Player is in room: [name]" message
-- ✓ 9 total light sources created
-- ✓ Reduced volume (indoor modifier applied)
-- ✓ Light enters through windows
-- ✓ Ambient glow from multiple directions
```

### Test Case 3: Indoor Thunder (Windowless Room)
```lua
-- Go inside a windowless room (e.g., basement)
TestThunder(800)

-- Expected:
-- ✓ 9 lights created but less visible effect
-- ✓ Build 42 lighting blocks most light from propagating
-- ✓ Some ambient glow from main light at player
-- ✓ Volume muffled significantly
```

### Test Case 4: Feature Toggle
```lua
-- Disable lighting, keep indoor detection
ThunderToggleLighting(false)
ThunderToggleIndoorDetection(true)
TestThunder(200)

-- Expected:
-- ✓ Screen flash only (no 3D lights)
-- ✓ Sound still muffled if indoors
-- ✗ No light sources created

-- Disable indoor detection, keep lighting
ThunderToggleLighting(true)
ThunderToggleIndoorDetection(false)
TestThunder(200)

-- Expected:
-- ✓ Lights created normally
-- ✓ Full volume even if indoors
-- ✗ No indoor modifier applied to sound
```

### Test Case 5: Multiple Rapid Strikes
```lua
-- Trigger several strikes quickly
for i = 1, 5 do
    TestThunder(ZombRand(100, 1000))
end

-- Expected:
-- ✓ All lights created independently
-- ✓ Overlapping flashes (additive intensity)
-- ✓ All lights cleaned up after 400ms
-- ✗ No memory leaks or orphaned lights
```

## API Function Reference

### IsoGridSquare Methods
```lua
square:getRoom()     -- Returns IsoRoom or nil
square:getX()        -- Returns integer X coordinate
square:getY()        -- Returns integer Y coordinate
square:getZ()        -- Returns integer Z coordinate (floor level)
```

### IsoPlayer Methods
```lua
player:getCurrentSquare()  -- Returns IsoGridSquare
```

### IsoRoom Methods
```lua
room:getName()       -- Returns string (e.g., "bedroom", "kitchen")
room:isInside(x, y, z)  -- Returns boolean (not used in current impl)
```

### IsoCell Methods
```lua
cell:addLamppost(x, y, z, r, g, b, radius)  -- Returns IsoLightSource
cell:removeLamppost(lightSource)            -- Void
cell:getGridSquare(x, y, z)                 -- Returns IsoGridSquare or nil
```

### Global Functions
```lua
getPlayer()          -- Returns IsoPlayer
getCell()            -- Returns IsoCell
getTimestampMs()     -- Returns current time in milliseconds
ZombRandFloat(min, max)  -- Returns random float in range
```

## Future Enhancements

### Potential Improvements

1. **Window Proximity Detection**
   - Detect nearby windows using IsoWindow objects
   - Brighter lights near windows
   - Dimmer lights in interior rooms

2. **Material-Based Muffling**
   - Query wall materials (wood, brick, concrete)
   - Different sound reduction per material
   - Requires RoomDef or BuildingDef analysis

3. **Light Color Variation**
   - Distant lightning → more red-shifted (Rayleigh scattering)
   - Close lightning → pure white
   - Storm intensity → color temperature

4. **Adaptive Light Count**
   - Performance mode: 1-3 lights max
   - Quality mode: 5-9 lights
   - User setting in mod options

5. **Flash Direction**
   - Use actual lightning strike coordinates (if available)
   - Angle-based light placement (not omnidirectional)
   - Brighter on strike-facing side

### Code Structure Improvements

1. **Light Pooling**
   - Pre-allocate IsoLightSource objects
   - Reuse instead of create/destroy
   - Reduce GC pressure

2. **Spatial Hashing**
   - Track lights per grid chunk
   - Faster cleanup for large numbers
   - Currently not needed (max 9 lights)

3. **Configuration System**
   - Mod options menu integration
   - Persistent settings (sandbox vars)
   - Per-player preferences

## Conclusion

The IsoRegions and Lighting integration adds **realistic indoor/outdoor behavior** and **dynamic 3D lighting effects** to thunder strikes while maintaining **excellent performance** and **Build 42 compatibility**.

**Key Achievements:**
✓ Seamless integration with existing thunder system
✓ Zero network overhead (client-side only)
✓ Automatic cleanup prevents memory leaks
✓ Leverages Build 42's advanced lighting engine
✓ User-toggleable features for flexibility
✓ Debug mode for troubleshooting

**Performance Impact:**
- Negligible CPU overhead
- Minimal memory usage (< 2KB per strike)
- No persistent allocations
- Efficient cleanup every render tick

**Player Experience:**
- More immersive thunder indoors
- Realistic sound muffling
- Beautiful lightning illumination
- Light entering through windows/doors
- Configurable to player preference
