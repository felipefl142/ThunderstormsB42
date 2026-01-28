# MOD_OPTIMIZATION.md

Comprehensive knowledge base for Project Zomboid mod optimization best practices and performance tips.

## Table of Contents

1. [Introduction](#introduction)
2. [Code Optimization](#code-optimization)
3. [Event Handling](#event-handling)
4. [Variable Scope](#variable-scope)
5. [Asset Optimization](#asset-optimization)
6. [Multiplayer & Networking](#multiplayer--networking)
7. [UI Optimization](#ui-optimization)
8. [Debugging & Profiling](#debugging--profiling)
9. [Common Pitfalls](#common-pitfalls)
10. [References](#references)

---

## Introduction

Mod optimization is a critical aspect of mod development that is often overlooked. When multiple mods are loaded in a save, performance issues from individual mods compound, potentially causing significant degradation. Simple optimization techniques can dramatically improve performance with minimal effort.

### Why Optimization Matters

- **Compounding Effects**: Multiple poorly optimized mods create exponential performance degradation
- **Server Performance**: Optimized mods are essential for multiplayer servers
- **Player Experience**: Smooth gameplay enhances immersion and enjoyment
- **Compatibility**: Well-optimized mods play better with other mods

---

## Code Optimization

### Function Call Overhead

**Problem**: Function calls in Kahlua (PZ's Lua implementation) are costly operations.

**Solution**: Sacrifice some code readability for performance by using bigger, more self-contained functions instead of many small function calls.

#### Bad Example
```lua
-- Multiple function calls per tick
function OnTick(tick)
    local zombies = getZombieList()
    local player = getPlayer()
    local distance = calculateDistance(player, zombies)
    processZombies(zombies, distance)
end
```

#### Better Example
```lua
-- Single function with inline logic
function OnTick(tick)
    local zombies = zombieListCache -- Cached reference
    local player = playerCache
    -- Inline distance calculation
    local dx = player:getX() - zombies:get(0):getX()
    local dy = player:getY() - zombies:get(0):getY()
    local distSq = dx*dx + dy*dy
    -- Process inline
    if distSq < 100 then
        -- Handle close zombies
    end
end
```

### Object Reference Caching

**Problem**: Repeatedly calling getter functions wastes CPU cycles.

**Solution**: Cache references to objects that persist throughout the game session.

#### Bad Example
```lua
function OnTick()
    local cell = getCell()
    local zombies = cell:getZombieList()
    -- Process zombies
end
```

#### Better Example
```lua
-- Cache on map load
local zombieListCache = nil

function OnGameStart()
    zombieListCache = getCell():getZombieList()
end

function OnTick()
    -- Reuse cached reference
    local zombies = zombieListCache
    -- Process zombies
end

Events.OnGameStart.Add(OnGameStart)
```

**Rationale**: The zombie list object reference remains constant within a save file, so there's no need to retrieve it every tick.

### Minimize String Operations

**Problem**: String concatenation and manipulation are expensive in Lua.

**Solution**:
- Cache string results when possible
- Use string formatting sparingly
- Avoid string operations in tight loops

#### Bad Example
```lua
function OnTick()
    for i=1,1000 do
        local msg = "Item " .. i .. " processed"
        -- Do something
    end
end
```

#### Better Example
```lua
-- Pre-allocate or avoid string operations in loops
function OnTick()
    for i=1,1000 do
        -- Process without string concatenation
        processItem(i)
    end
end
```

---

## Event Handling

### OnTick vs OnRenderTick

**OnTick**: Fires every game tick (variable rate, typically 60 ticks/second when not paused)
- Use for game logic that must be synchronized with game state
- Affected by game speed and pause state
- Preferred for most gameplay mechanics

**OnRenderTick**: Fires every rendering frame
- Use for visual effects and UI animations
- Runs even when game is paused
- Higher frequency than OnTick during normal gameplay

### Tick Event Optimization

**Key Principle**: Minimize work done in frequently-called events.

#### Techniques

1. **Throttling**: Don't run logic every tick
```lua
local tickCounter = 0
local CHECK_INTERVAL = 60 -- Check once per second (60 ticks)

function OnTick(tick)
    tickCounter = tickCounter + 1
    if tickCounter >= CHECK_INTERVAL then
        tickCounter = 0
        -- Expensive operation here
        checkWeatherConditions()
    end
end
```

2. **Early Returns**: Exit early if conditions aren't met
```lua
function OnTick(tick)
    if not isClient() then return end
    if not getPlayer() then return end
    -- Rest of logic
end
```

3. **Lazy Initialization**: Defer expensive setup until needed
```lua
local isInitialized = false

function OnTick(tick)
    if not isInitialized then
        initializeModData()
        isInitialized = true
    end
    -- Normal tick logic
end
```

### Event Listener Best Practices

1. **Remove Unused Listeners**: Unregister events when no longer needed
```lua
local function tempHandler()
    -- One-time logic
    Events.OnTick.Remove(tempHandler)
end
Events.OnTick.Add(tempHandler)
```

2. **Conditional Registration**: Only register events when relevant
```lua
if isClient() then
    Events.OnRenderTick.Add(RenderFlash)
end

if isServer() then
    Events.OnTick.Add(ServerThunderLogic)
end
```

---

## Variable Scope

### Local vs Global Variables

**Performance**: Accessing local variables is significantly faster than globals.

**Analogy**:
- **Global variables** = City-wide phone book (slow to search)
- **Local variables** = Personal phone book (fast to search)

**Safety**: Global variables risk accidental overwriting by other mods.

#### Bad Example
```lua
-- Global variables (slow, unsafe)
zombieList = getCell():getZombieList()
playerObj = getPlayer()

function OnTick()
    processZombies(zombieList, playerObj)
end
```

#### Better Example
```lua
-- Local variables (fast, safe)
local zombieList = getCell():getZombieList()
local playerObj = getPlayer()

local function OnTick()
    processZombies(zombieList, playerObj)
end
```

### Scope Best Practices

1. **Smallest Scope Possible**: Lua philosophy is to declare variables in the smallest scope
2. **File-Level Locals**: For module-wide sharing without global pollution
```lua
-- Top of file
local ModuleData = {}
ModuleData.config = {}
ModuleData.cache = {}

local function init()
    ModuleData.config.enabled = true
end
```

3. **Function Locals**: For variables only used within a function
```lua
function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1  -- Local to function
    local dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end
```

---

## Asset Optimization

### Texture Guidelines

**Size Recommendations**:
- **General Rule**: Keep textures below 256x256 pixels
- **Rationale**: Camera is zoomed far back; excessive detail causes visual confusion and performance issues

**Format**:
- Use PNG for transparency
- Use compressed formats when possible
- Avoid unnecessarily large image files

### Audio Optimization

**Format**: .ogg Vorbis (Zomboid standard)
- **Mono vs Stereo**: Use mono for 3D positional sounds (smaller file size, better 3D spatialization)
- **Stereo**: Only for ambient/music tracks where spatial positioning isn't needed
- **Bit Rate**: 96-128 kbps is usually sufficient for game audio
- **Sample Rate**: 44.1kHz standard

**Sound Script Optimization**:
```lua
sound ThunderClose
{
    category = Ambient,
    is3D = true,           // Enable 3D positioning
    master = Ambient,       // Volume master control
    range = 1200.0,        // Audible range in tiles
    volume = 2.0,          // Base volume multiplier
    clip
    {
        file = sound/thunder.ogg
    }
}
```

### Script File Optimization

- **Minimize Redundancy**: Don't duplicate sound definitions across multiple files
- **Use Clip Arrays**: Multiple clips in one sound definition allows random variation
- **Proper Paths**: Use relative paths from mod root (e.g., `sound/file.ogg` not `media/sound/file.ogg`)

---

## Multiplayer & Networking

### Client-Server Architecture

**Principle**: Minimize network traffic by processing locally when possible.

#### Server-Side Processing
```lua
-- Server calculates thunder strike
function TriggerThunder()
    if not isServer() then return end

    local distance = ZombRandFloat(0, 8000)

    -- Send only essential data to clients
    sendServerCommand("Thunder", "Strike", {dist = distance})
end
```

#### Client-Side Processing
```lua
-- Client receives distance and calculates everything else locally
function OnServerCommand(module, command, args)
    if module ~= "Thunder" or command ~= "Strike" then return end

    local distance = args.dist

    -- Calculate flash intensity locally (no network overhead)
    local flashIntensity = calculateFlashIntensity(distance)

    -- Calculate sound delay locally
    local delay = distance / 340  -- Speed of sound

    -- Process effects
    showFlash(flashIntensity)
    scheduleSound(delay, distance)
end
```

### Network Optimization Tips

1. **Batch Commands**: Send multiple updates in single network call when possible
2. **Delta Compression**: Only send changed values, not entire state
3. **Throttle Updates**: Don't send updates every tick; throttle to acceptable rate
4. **Use Appropriate Types**: Numbers are smaller than strings in network packets

---

## UI Optimization

### ISUIElement Best Practices

**Principle**: UI elements in the UI manager can block input and consume render cycles.

#### Dynamic Management
```lua
-- Bad: Always in UI manager
function createFlash()
    self.flashOverlay = ISUIElement:new(0, 0, width, height)
    UIManager.addUI(self.flashOverlay)  -- Permanently blocks input
end

-- Better: Add/remove dynamically
function showFlash()
    if not self.isInUIManager then
        UIManager.addUI(self.flashOverlay)
        self.isInUIManager = true
    end
end

function hideFlash()
    if self.isInUIManager then
        UIManager.removeUI(self.flashOverlay)
        self.isInUIManager = false
    end
end
```

### Rendering Optimization

1. **Use render(), Not prerender()**: Build 42.13+ deprecated `prerender()`
```lua
function ISFlashOverlay:render()
    ISUIElement.render(self)  -- Call parent first
    -- Custom rendering
end
```

2. **Minimize Draw Calls**: Batch rendering operations
3. **Cull Off-Screen Elements**: Don't render invisible UI
```lua
function render()
    if self.alpha <= 0 then return end  -- Don't render invisible
    -- Rendering logic
end
```

---

## Debugging & Profiling

### Print Statement Performance

**Critical Warning**: Excessive printing severely impacts performance.

**Guidelines**:
- Use debug flags to disable prints in production
- Limit print frequency in loops
- Consider using a debug mod option

```lua
local DEBUG_MODE = false  -- Toggle via mod options

function debugPrint(msg)
    if DEBUG_MODE then
        print("[MyMod] " .. msg)
    end
end
```

### Performance Profiling

**Manual Timing**:
```lua
local startTime = getTimestampMs()
-- Expensive operation
local endTime = getTimestampMs()
print("Operation took: " .. (endTime - startTime) .. "ms")
```

**Conditional Debugging**:
```lua
-- Enable via console command
function ToggleDebug(enabled)
    MyMod.DebugEnabled = enabled
    if enabled then
        print("[MyMod] Debug mode enabled")
    end
end
```

---

## Common Pitfalls

### 1. Excessive Event Listeners
**Problem**: Registering duplicate event listeners
```lua
-- Bad: Called multiple times, adds duplicate listeners
function init()
    Events.OnTick.Add(MyTickHandler)
end
```

**Solution**: Check before adding or remove first
```lua
function init()
    Events.OnTick.Remove(MyTickHandler)  -- Remove old
    Events.OnTick.Add(MyTickHandler)     -- Add new
end
```

### 2. Memory Leaks
**Problem**: Creating objects without cleanup
```lua
function OnTick()
    -- Creates new table every tick!
    local data = {x = 1, y = 2, z = 3}
end
```

**Solution**: Reuse objects or use proper scope
```lua
local dataCache = {x = 0, y = 0, z = 0}

function OnTick()
    dataCache.x = newX
    dataCache.y = newY
    -- Reuse existing table
end
```

### 3. Unnecessary File Overwrites
**Problem**: Replacing entire vanilla files for small changes

**Solution**: Hook functions or use events
```lua
-- Bad: Copy entire vanilla file and modify
-- Good: Hook specific function
local originalFunction = SomeClass.someMethod

function SomeClass.someMethod(self, arg1, arg2)
    -- Call original
    originalFunction(self, arg1, arg2)
    -- Add custom logic
    customLogic()
end
```

### 4. Synchronous File I/O
**Problem**: Reading files during tick events

**Solution**: Load files during initialization
```lua
-- Bad: Read file every tick
function OnTick()
    local data = readFile("config.txt")
end

-- Good: Read once on startup
local configData = nil

function OnGameStart()
    configData = readFile("config.txt")
end

function OnTick()
    -- Use cached data
    processConfig(configData)
end
```

### 5. Complex Math in Tight Loops
**Problem**: Expensive operations repeated unnecessarily
```lua
-- Bad: Square root every iteration
for i=1,1000 do
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 100 then
        -- Do something
    end
end
```

**Solution**: Use squared distances when possible
```lua
-- Better: Compare squared values (no sqrt)
local maxDistSq = 100 * 100  -- Precompute

for i=1,1000 do
    local distSq = dx*dx + dy*dy
    if distSq < maxDistSq then
        -- Do something
    end
end
```

---

## References

### Official Documentation
- [PZwiki - Mod Optimization](https://pzwiki.net/wiki/Mod_optimization)
- [PZwiki - Lua Events](https://pzwiki.net/wiki/Lua_event)
- [PZwiki - Lua API](https://pzwiki.net/wiki/Lua_(API))
- [Project Zomboid Lua Docs - Events](https://demiurgequantified.github.io/ProjectZomboidLuaDocs/md_Events.html)

### Community Resources
- [Zomboid Modding Guide (FWolfe)](https://github.com/FWolfe/Zomboid-Modding-Guide/blob/master/api/README.md)
- [PZ Event Documentation (demiurgeQuantified)](https://github.com/demiurgeQuantified/PZEventDoc/blob/develop/docs/Events.md)
- [PZ Event Stubs](https://github.com/demiurgeQuantified/PZEventStubs)
- [How to Mod Like a Boss (Konijima)](https://gist.github.com/Konijima/7e6bd1adb6f69444e7b620965a611b74)

### Performance Mods (Examples)
- [BetterFPS](https://steamcommunity.com/sharedfiles/filedetails/?id=3022543997) - Reduces render zone for 40-70% performance increase
- [Every Texture Optimized](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=texture+optimized) - Reduces texture resolution with minimal visual impact

### Build Notes
- **Build 41**: Somewhat unoptimized with questionable rendering pipeline
- **Build 42**: Delivers monumental improvements to rendering and overall performance

---

## Quick Reference Checklist

Use this checklist when reviewing mod code for optimization:

- [ ] All variables declared in smallest possible scope (prefer `local`)
- [ ] Object references cached when appropriate (e.g., zombie list, player)
- [ ] Event listeners removed when no longer needed
- [ ] OnTick/OnRenderTick logic minimized and throttled
- [ ] Early returns used to skip unnecessary processing
- [ ] Function calls minimized in tight loops
- [ ] String operations avoided in performance-critical code
- [ ] Math operations optimized (e.g., squared distance vs sqrt)
- [ ] UI elements added/removed dynamically, not permanently
- [ ] Network traffic minimized (send only essential data)
- [ ] Print statements controlled by debug flags
- [ ] Textures kept below 256x256 when possible
- [ ] Audio files use appropriate format (.ogg) and channels (mono for 3D)
- [ ] File I/O performed during initialization, not runtime
- [ ] No duplicate event listener registrations

---

**Last Updated**: January 2026
**Applicable Builds**: Project Zomboid Build 41, Build 42, Build 42.13+

---

## Sources

This knowledge base was compiled from the following sources:

- [Mod optimization - PZwiki](https://pzwiki.net/wiki/Mod_optimization)
- [Lua event - PZwiki](https://pzwiki.net/wiki/Lua_event)
- [Lua (API) - PZwiki](https://pzwiki.net/wiki/Lua_(API))
- [Lua (language) - PZwiki](https://pzwiki.net/wiki/Lua_(language))
- [Zomboid-Modding-Guide - FWolfe GitHub](https://github.com/FWolfe/Zomboid-Modding-Guide/blob/master/api/README.md)
- [PZEventDoc - demiurgeQuantified](https://github.com/demiurgeQuantified/PZEventDoc/blob/develop/docs/Events.md)
- [Project Zomboid Lua Docs - Events](https://demiurgequantified.github.io/ProjectZomboidLuaDocs/md_Events.html)
- [Steam Workshop - PZ Optimization Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3308943112)
- [Steam Workshop - BetterFPS](https://steamcommunity.com/sharedfiles/filedetails/?id=3022543997)
- [How to mod like a boss - Konijima Gist](https://gist.github.com/Konijima/7e6bd1adb6f69444e7b620965a611b74)
