# The Better Thunder Chronicles

**A Deep Dive into Building a Physics-Based Thunder Mod for Project Zomboid**

---

## Table of Contents

1. [What We Built](#what-we-built)
2. [The Big Picture: Architecture That Makes Sense](#the-big-picture-architecture-that-makes-sense)
3. [The Journey Through the Codebase](#the-journey-through-the-codebase)
4. [The Tech Stack (And Why It Matters)](#the-tech-stack-and-why-it-matters)
5. [Design Decisions: The Why Behind the What](#design-decisions-the-why-behind-the-what)
6. [War Stories: Bugs, Fixes, and Lessons Learned](#war-stories-bugs-fixes-and-lessons-learned)
7. [Engineering Wisdom: How Good Engineers Think](#engineering-wisdom-how-good-engineers-think)
8. [The Pitfall Field Guide](#the-pitfall-field-guide)
9. [If I Could Do It Again](#if-i-could-do-it-again)

---

## What We Built

Imagine you're standing in a post-apocalyptic Kentucky, rain pouring down, and suddenly the sky lights up. In vanilla Project Zomboid, thunder is... well, it's there. But that's about it. No physics, no distance calculations, no "wait for it..." moment before the boom reaches your ears.

**Better Thunder** changes that. We built a mod that simulates real-world lightning and thunder physics. When lightning strikes 2 kilometers away, you see the flash instantly (light travels fast), but the sound takes almost 6 seconds to reach you (sound travels at ~340 m/s). The flash is dimmer for distant strikes, the sound is quieter, and everything syncs perfectly in multiplayer.

It sounds simple. It wasn't.

---

## The Big Picture: Architecture That Makes Sense

### The Client-Server Split (Or: Don't Try to Do Everything Everywhere)

Project Zomboid uses a **client-server architecture**, even in single-player. Think of it like a restaurant:

- **The Server (Kitchen)**: Decides when things happen. "Thunder strike at 1,500 tiles away, NOW!"
- **The Clients (Diners)**: Receive the order and handle the presentation. Flash the screen, wait for sound, play audio.

This separation is crucial. Here's why:

**If we did everything client-side:**
- In multiplayer, everyone would see different thunder strikes at different times
- Chaos. Immersion destroyed.

**If we did everything server-side:**
- The server would need to track every player's screen state
- Performance nightmare
- The server can't even draw graphics or play sounds (it has no monitor or speakers!)

**Our approach:**
1. **Server monitors weather** → "Cloud intensity is 0.8, roll the dice... okay, thunder strike!"
2. **Server picks distance** → "This one's 1,500 tiles away"
3. **Server broadcasts to all clients** → "Everyone, lightning at 1,500 tiles!"
4. **Each client independently:**
   - Flashes their screen (brightness based on distance)
   - Calculates sound delay: 1,500 ÷ 340 = 4.4 seconds
   - Waits 4.4 seconds
   - Plays thunder sound (volume based on distance)

This is the **Single Source of Truth** principle. The server is the authority, clients are the interpreters.

### The Three Musketeers: Server, Client, Shared

Our codebase has three main files:

```
Thunder_Server.lua    → The decision maker (triggers thunder)
Thunder_Client.lua    → The showman (visuals & audio)
Thunder_Shared.lua    → The rulebook (shared config)
```

Think of them as three musicians in a band:
- **Server**: The conductor, decides when to play
- **Client**: The performer, creates the experience
- **Shared**: The sheet music, everyone reads the same notes

---

## The Journey Through the Codebase

Let me take you on a tour. Grab your virtual hard hat.

### 🏗️ The Folder Structure

```
Thunderstorms v2/
├── Contents/mods/Thunderstorms/
│   ├── 42/          ← Legacy code (Build 42 initial release)
│   └── 42.13/       ← Active development (Build 42.13+)
│       └── media/
│           ├── lua/
│           │   ├── client/     → Thunder_Client.lua (VFX/SFX)
│           │   ├── server/     → Thunder_Server.lua (logic)
│           │   └── shared/     → Thunder_Shared.lua (config)
│           ├── scripts/        → Thunderstorms_sounds.txt (audio definitions)
│           └── sound/          → .ogg files (actual thunder sounds)
├── mod.info         ← Mod metadata
└── workshop.txt     ← Steam Workshop info
```

**Why two versions (42 and 42.13)?**

Build 42 is in active development. The devs keep changing APIs. It's like trying to build a house while someone keeps moving the foundation. We maintain both versions so players on older builds don't get left behind.

### 🎮 Thunder_Server.lua: The Brain

**What it does:**
1. Checks weather every game tick (~1/60th of a second)
2. If clouds > 20% intensity, rolls dice for thunder
3. When thunder triggers, picks a random distance (50-8000 tiles)
4. Broadcasts "LightningStrike" command to all clients

**Key code snippet (simplified):**

```lua
function ThunderServer.OnTick()
    -- Don't interfere if Native Mode is on
    if ThunderMod.Config.UseNativeWeatherEvents then return end

    -- Cooldown check (prevent spam)
    if ThunderServer.cooldownTimer > 0 then
        ThunderServer.cooldownTimer = ThunderServer.cooldownTimer - 1
        return
    end

    local clouds = getClimateManager():getCloudIntensity()

    if clouds > 0.2 then
        -- Chance increases with cloud intensity
        local chance = 0.05 * clouds  -- 0.05% at 100% clouds

        if ZombRandFloat(0, 100) < chance then
            ThunderServer.TriggerStrike()  -- BOOM!
        end
    end
end
```

**The cooldown system** is crucial. Without it, you'd hear thunder every second during storms. We use **dynamic cooldown**:

- Heavy storm (clouds = 1.0) → Minimum 10 seconds between strikes
- Light storm (clouds = 0.2) → Up to ~24 seconds between strikes

This creates natural pacing. Heavy storms feel intense, light storms feel ominous.

### 🎨 Thunder_Client.lua: The Performer

This is where the magic happens. 386 lines of visual effects, audio timing, and careful state management.

**The Flash System:**

Think of the flash like a camera exposure:
1. **Instant spike** → Brightness jumps to 0.1-0.5 alpha (based on distance)
2. **Smooth decay** → Fades at 2.5 alpha units per second
3. **Dynamic overlay** → Only added to UI during flash (critical!)

**Why "only during flash"?**

Early versions kept the overlay permanently in the UI. It was invisible (alpha = 0) most of the time. Harmless, right?

**Wrong.**

Turns out, invisible UI elements still capture mouse events. Players couldn't click anything. The game was broken. We spent hours debugging before discovering this.

**The fix:**
```lua
-- When flash starts
if not ThunderClient.overlay.isInUIManager then
    ThunderClient.overlay:addToUIManager()
    ThunderClient.overlay.isInUIManager = true
end

-- When flash ends
if ThunderClient.flashIntensity <= 0 then
    if ThunderClient.overlay.isInUIManager then
        ThunderClient.overlay:removeFromUIManager()
        ThunderClient.overlay.isInUIManager = false
    end
end
```

We add the overlay only when visible, remove it immediately after. Like a stage actor who enters when needed and exits when done.

**The Sound Delay System:**

This is where physics meets code:

```lua
local speed = 340  -- tiles per second (speed of sound)
local delaySeconds = distance / speed
local triggerTime = getTimestampMs() + (delaySeconds * 1000)

-- Queue the sound for later
table.insert(ThunderClient.delayedSounds, {
    sound = soundName,
    time = triggerTime,
    volume = volume
})
```

Every tick, we check if any queued sounds are ready:

```lua
function ThunderClient.OnTick()
    local now = getTimestampMs()

    for i = #ThunderClient.delayedSounds, 1, -1 do
        local entry = ThunderClient.delayedSounds[i]

        if now >= entry.time then
            -- Time's up! Play it!
            getSoundManager():PlayWorldSound(entry.sound, ...)
            table.remove(ThunderClient.delayedSounds, i)
        end
    end
end
```

**Why iterate backwards?** (`for i = #table, 1, -1`)

When you remove items from a table while iterating forward, you skip elements. It's like trying to count people in a line while they're walking toward you—the count gets messed up.

Iterating backwards means removals don't affect indices we haven't reached yet. Classic arrays-and-loops gotcha.

### 🔀 Thunder_Shared.lua: The Rulebook

Small but mighty:

```lua
ThunderMod = {}
ThunderMod.Config = {
    UseNativeWeatherEvents = false  -- Toggle between custom & native
}
```

Both client and server import this. Shared state, shared truth. If the server flips Native Mode on, clients sync via network commands.

### 🎵 The Sound System: 3D Audio and Indoor Muffling

We use **3D positional audio**, which sounds fancy but is actually a clever hack:

```lua
PlayWorldSound(soundName, playerSquare, 0, volume, radius, false)
```

We play the sound **at the player's location**. Why? Because the game's audio engine:
- Automatically muffles sound when you're indoors
- Applies distance falloff (though we also calculate volume manually)
- Handles stereo panning

Thunder is omnidirectional (it comes from the sky, everywhere), so playing it at the player's position makes sense. The game handles indoor vs outdoor distinction for us.

**Sound categorization:**

- **ThunderClose** (< 200 tiles): Loud cracks, sharp snaps
- **ThunderMedium** (200-800 tiles): Rolling rumbles
- **ThunderFar** (≥ 800 tiles): Deep, distant echoes

Each category has multiple sound files. We pick randomly for variety.

---

## The Tech Stack (And Why It Matters)

### Lua: The Scripting Language

**Why Lua?** Because Project Zomboid's modding API is Lua-based. We don't choose our tools here; the game does.

**What's Lua like?**
- Dynamically typed (no `int` or `string` declarations)
- Garbage collected (no manual memory management)
- Tables are everything (arrays, objects, hashmaps—all tables)
- 1-indexed arrays (fight me)

**Lua gotchas we hit:**

1. **Global by default**: Forget `local` and your variable is global. We polluted the namespace once, caused conflicts with another mod.
2. **Nil is falsy**: `if value then` fails for `nil` AND `false`. Use `if value ~= nil then`.
3. **No ternary operator**: `local x = condition ? a : b` doesn't exist. Use `local x = condition and a or b`.

### Project Zomboid's Event System

The game uses an **event-driven architecture**. Instead of polling "has something happened?", you register callbacks:

```lua
Events.OnTick.Add(ThunderServer.OnTick)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnThunder.Add(ThunderServer.OnNativeThunder)
```

**The problem:** Not all events exist in all versions.

In Build 42.13, `Events.OnThunder` was added (the game's native thunder system). Older builds don't have it. If you call:

```lua
Events.OnThunder.Add(myFunction)
```

...and `OnThunder` is `nil`, the game crashes.

**The fix (defensive registration):**

```lua
if Events.OnThunder then
    Events.OnThunder.Add(ThunderClient.OnNativeThunder)
else
    print("[ThunderClient] WARNING: Events.OnThunder not available.")
end
```

Check before you leap. Assume nothing. This is **defensive programming** 101.

### ISUIElement: The UI Framework

To draw the flash, we create a fullscreen `ISUIElement`:

```lua
ThunderClient.overlay = ISUIElement:new(0, 0, screenWidth, screenHeight)

ThunderClient.overlay.render = function(self)
    ISUIElement.render(self)  -- Call parent render

    if ThunderClient.flashIntensity > 0 then
        -- Draw white rectangle with alpha
        self:drawRect(0, 0, self:getWidth(), self:getHeight(),
                     ThunderClient.flashIntensity, 1, 1, 1)
    end
end
```

**Build 42.13 broke `prerender()`**. We had to migrate to `render()`. APIs change. Code rots. Version management is half the battle.

---

## Design Decisions: The Why Behind the What

### Decision #1: Server-Side Thunder Triggering

**Why not let each client trigger thunder independently?**

Because multiplayer would desync. Player A sees thunder at 1,500 tiles. Player B sees it at 500 tiles. They're in the same location. Immersion shattered.

**The server is the single source of truth.** All clients react to the same event.

### Decision #2: Client-Side Distance Calculations

**Why not send the exact sound delay from the server?**

Network optimization. Instead of:

```
Server → Client: {distance: 1500, soundDelay: 4.4, volume: 0.72, brightness: 0.23}
```

We send:

```
Server → Client: {distance: 1500}
```

The client calculates everything else. Less bandwidth, same result. The speed of sound isn't going to change mid-game.

### Decision #3: Time-Based Flash Decay

**Original code:**

```lua
-- Frame-based decay (bad)
ThunderClient.flashIntensity = ThunderClient.flashIntensity - 0.05
```

**Problem:** On high-refresh monitors (144 Hz), flashes decayed faster. On low-end PCs (30 FPS), flashes lingered. Inconsistent experience.

**Solution:**

```lua
-- Time-based decay (good)
local deltaTime = (now - lastUpdateTime) / 1000.0  -- Seconds
ThunderClient.flashIntensity = flashIntensity - (2.5 * deltaTime)
```

Now the flash decays at 2.5 alpha units per second, **regardless of framerate**. This is the difference between amateur and professional game development.

### Decision #4: Native Mode Support

**Why support the game's built-in thunder?**

Project Zomboid has internal weather events that affect gameplay:
- Foraging success rates drop during storms
- Moodles (mood effects) trigger during thunder
- NPCs react to weather

If we **replace** the game's thunder entirely, these systems break. Players would wonder why foraging still gets penalties when there's no thunder.

**The solution: Native Mode**

```lua
ThunderMod.Config.UseNativeWeatherEvents = true  -- Sync with game
ThunderMod.Config.UseNativeWeatherEvents = false -- Use our system
```

When Native Mode is on:
- Our random generator **disables**
- We listen to `Events.OnThunder` (the game's event)
- When the game triggers thunder, we intercept and add our physics/visuals

Best of both worlds. The game's logic runs, we enhance the presentation.

### Decision #5: Dynamic Cooldown Based on Storm Intensity

**Naive approach:**

```lua
cooldownTimer = 10  -- Always 10 seconds
```

**Problem:** Light drizzle and heavy storm feel the same.

**Our approach:**

```lua
local intensityFactor = (1.1 - clouds)  -- Inverted
local addedDelay = math.floor(1000 * intensityFactor)
cooldownTimer = 600 + ZombRand(0, addedDelay)
```

- Heavy storm (clouds = 1.0) → `intensityFactor = 0.1` → Cooldown ~10-11 seconds
- Light storm (clouds = 0.2) → `intensityFactor = 0.9` → Cooldown ~10-24 seconds

The storm **feels different** based on intensity. This is **environmental storytelling** through code.

---

## War Stories: Bugs, Fixes, and Lessons Learned

### Bug #1: The Invisible UI Killer

**Symptom:** After thunder strikes, players can't click anything. Game is unplayable.

**Investigation:**
- Flash overlay is invisible (alpha = 0)
- But still in UI manager
- UI elements capture mouse events even when invisible
- Clicks go to the overlay, not the game

**Root cause:** We initialized the overlay once and left it in the UI permanently.

**Fix:** Add/remove overlay dynamically during flashes only.

**Lesson:** **State management is critical.** Just because something is invisible doesn't mean it's inactive. Clean up your resources.

### Bug #2: Silent Loading Failure

**Symptom:** Mod loads, no errors in console, but nothing happens. No thunder, no events.

**Investigation:**
- Added debug prints: file loads, events register, but functions never called
- Check if `isClient()` or `isServer()` is nil during load
- Found problematic code:

```lua
-- This crashes silently during load phase!
print("[Thunder] Loading on " .. (isClient() and "client" or "server"))
```

**Root cause:** During file load (before world initialization), `isClient()` and `isServer()` return `nil`. Lua can't concatenate `nil` into a string. Silent crash.

**Fix:**

```lua
-- Safe version
if isClient then
    if isClient() then
        print("[Thunder] Loading on client")
    end
end
```

Or just remove the check entirely during load:

```lua
print("[Thunder] File is being loaded...")
-- Guard clauses come AFTER basic initialization
```

**Lesson:** **Loading phases matter.** Not all APIs are available at all times. Test thoroughly, especially in single-player vs multiplayer vs dedicated server.

### Bug #3: The Console Command Catastrophe

**Symptom:** Players type `ForceThunder(200)` in console. Error: "attempt to call a nil value."

**Original code:**

```lua
-- At top of file
if not isClient() then return end  -- Only load on client

-- Later...
function ForceThunder(dist)
    -- This function is never defined on server!
end
```

**Root cause:** In single-player, both client AND server load files. The server-side file hit `if not isServer() then return end` and exited before defining console commands.

**Fix:** Remove restrictive guard clauses at file start. Let both files load, use runtime checks instead:

```lua
-- No early returns!

function ThunderServer.OnTick()
    -- Runtime check
    if not isServer() then return end
    -- Server logic...
end
```

**Lesson:** **Global functions need to be defined.** Guard clauses at file-level prevent definition. Use runtime guards inside functions instead.

### Bug #4: The Double-Flash Strobe

**Original code:**

```lua
-- Random 1-4 flashes per strike
local numFlashes = ZombRand(1, 5)  -- Too many!
```

**Problem:** Players reported feeling dizzy. Four rapid flashes is a strobe light, not lightning.

**Fix:**

```lua
-- Mostly single flash, occasional double
local numFlashes = 1
if ZombRand(100) < 30 then numFlashes = 2 end  -- 30% chance
```

**Lesson:** **Realism ≠ maximum intensity.** Sometimes less is more. Listen to user feedback.

### Bug #5: Events.OnThunder Doesn't Exist (version compatibility)

**Symptom:** Mod crashes on older Build 42 versions.

**Code:**

```lua
Events.OnThunder.Add(ThunderClient.OnNativeThunder)  -- Crashes if OnThunder is nil
```

**Fix:**

```lua
if Events.OnThunder then
    Events.OnThunder.Add(ThunderClient.OnNativeThunder)
else
    print("[ThunderClient] WARNING: Events.OnThunder not available.")
end
```

**Lesson:** **Never assume APIs exist.** Defensive programming prevents crashes across versions.

---

## Engineering Wisdom: How Good Engineers Think

### Principle #1: Separate Concerns

We didn't put all logic in one file. We split:
- **Decision-making** (server)
- **Presentation** (client)
- **Configuration** (shared)

This is **separation of concerns**. Each file has one job. Debugging is easier, testing is easier, collaboration is easier.

### Principle #2: Single Source of Truth

Thunder distance is decided **once**, on the server. Clients don't second-guess it. They trust the server.

**Anti-pattern:**

```lua
-- Server
local distance = ZombRand(50, 3400)
sendCommand("ThunderStrike")

-- Client (BAD!)
local distance = ZombRand(50, 3400)  -- Different random number!
```

This creates desync. The **server owns the data**, clients interpret it.

### Principle #3: Fail Gracefully

When `Events.OnThunder` doesn't exist, we don't crash. We log a warning and continue. The mod still works, just without Native Mode.

**Good code degrades gracefully.** It doesn't throw tantrums when things aren't perfect.

### Principle #4: Optimize for the Common Case

Most players won't tweak settings. Most thunder strikes are medium-distance. Most of the time, the overlay isn't visible.

We optimized:
- Overlay is created **once** (on first strike), not every frame
- Sounds are queued efficiently (array iteration is cheap)
- Flash decay is calculated once per frame, not per pixel

**Don't optimize prematurely**, but know where the bottlenecks are.

### Principle #5: Version Everything

We maintain two folders (42 and 42.13) because APIs change. We document versions in changelogs. We use git tags for releases.

**Code without version control is like a time traveler without a DeLorean.** You can't go back, you can't fork timelines, you can't fix the past.

### Principle #6: Document Decisions, Not Just Code

Comments like this are useless:

```lua
-- Set volume
volume = 0.5
```

Comments like this are gold:

```lua
-- Volume scales from 1.0 at 0 tiles to 0.1 at 8000 tiles.
-- Below 0.1, the sound is imperceptible, so we cap it.
local volume = 1.0 - (distance / 8000) * 0.9
if volume < 0.1 then volume = 0.1 end
```

Explain **why**, not what. The code already shows **what**.

### Principle #7: Listen to Your Users (And Your Gut)

Players reported dizziness from strobe flashes. We reduced flash frequency.

Players wanted consistency with game weather. We added Native Mode.

**Good engineers build for users, not for themselves.**

---

## The Pitfall Field Guide

### Pitfall #1: Assuming APIs Are Stable

**In active development games, APIs change.** `prerender()` worked, then it didn't. `OnThunder` didn't exist, then it did.

**Mitigation:**
- Version your code
- Use defensive checks (`if Events.OnThunder then`)
- Follow game development closely (patch notes, forums)

### Pitfall #2: Forgetting Multiplayer Exists

**Singleplayer code often breaks in multiplayer.** Random number generators desync. Client-side decisions don't propagate.

**Mitigation:**
- Always test in multiplayer (or at least dedicated server)
- Think: "What if there are 10 clients?"
- Server decides, clients react

### Pitfall #3: Global State Pollution

**Lua makes everything global by default.**

```lua
cooldown = 0  -- GLOBAL! Conflicts with other mods!
```

**Fix:**

```lua
ThunderServer.cooldown = 0  -- Namespaced
```

**Mitigation:**
- Always use `local` for local variables
- Namespace globals (table prefixes)
- Be paranoid about name collisions

### Pitfall #4: Frame-Dependent Animations

**Code that assumes 60 FPS breaks on 30 FPS or 144 FPS.**

**Mitigation:**
- Use time-based calculations (`deltaTime`)
- Test on different framerates
- Use `getTimestampMs()` for timing, not frame counts

### Pitfall #5: Silent Failures

**Lua errors during file load can be silent.** No error message, no stack trace, just nothing works.

**Mitigation:**
- Add debug prints at file start/end
- Test loading in all contexts (client, server, singleplayer)
- Use `pcall()` (protected call) for risky operations

### Pitfall #6: Invisible UI Blocking Input

**UI elements capture mouse events even when invisible.**

**Mitigation:**
- Only add UI to manager when visible
- Set `ignoreMouseEvents = true` if the element shouldn't capture input
- Clean up resources when done

### Pitfall #7: Off-by-One Errors in Loops

**Removing from tables while iterating forward skips elements.**

**Mitigation:**
- Iterate backwards when removing: `for i = #table, 1, -1 do`
- Use a separate "to remove" list, then remove after iteration
- Test with multiple removals in one iteration

---

## If I Could Do It Again

### Thing #1: Automated Testing

We tested manually every time. Type `ForceThunder(200)`, check flash, wait for sound. Repeat 50 times.

**Better approach:** Automated tests.

```lua
function TestSuite.TestSoundDelay()
    local distance = 1000
    local expectedDelay = 1000 / 340  -- ~2.94 seconds

    ThunderClient.DoStrike({dist = distance})

    -- Check that sound is queued for ~2.94 seconds from now
    assert(#ThunderClient.delayedSounds == 1)
    local actualDelay = (delayedSounds[1].time - getTimestampMs()) / 1000
    assert(math.abs(actualDelay - expectedDelay) < 0.1)  -- Within 0.1s
end
```

**Lesson:** Manual testing is necessary, but **automated tests catch regressions**.

### Thing #2: Earlier Version Management

We let 42 and 42.13 diverge too much before splitting them into separate folders. Merging fixes backward became painful.

**Better approach:** Branch early, merge often. Or accept that old versions are frozen (like we did).

### Thing #3: More Granular Commits

Some commits changed 5 things at once. Hard to review, hard to revert.

**Better approach:** One logical change per commit.

- ❌ "Fixed bugs and added features"
- ✅ "Fix silent loading failure caused by isClient() concatenation"

**Lesson:** Git is your time machine. Make the timeline easy to navigate.

### Thing #4: Sound Volume Curve

Our volume scaling is linear: `volume = 1.0 - (distance / 8000) * 0.9`.

But human hearing is logarithmic. A sound at half volume doesn't sound "half as loud" to us.

**Better approach:** Logarithmic volume curve.

```lua
-- Logarithmic falloff (more natural)
local volume = math.max(0.1, math.log(8000 / distance) / math.log(80))
```

**Lesson:** **Physics isn't always intuitive.** Model human perception, not just raw numbers.

### Thing #5: Configurable Settings (UI or File)

Right now, changing settings requires editing Lua code. Most players won't do that.

**Better approach:** Mod settings menu (if PZ supports it) or a config file.

```lua
-- ThunderConfig.txt
UseNativeMode=false
MaxDistance=8000
FlashDecayRate=2.5
MinCooldown=600
```

**Lesson:** **Accessibility matters.** Let users customize without coding.

---

## Final Thoughts

Building this mod taught me:

1. **Architecture is 80% of the battle.** Get the client-server split right, and the rest flows.
2. **APIs will betray you.** Defensive programming isn't paranoia, it's survival.
3. **Users notice details.** Flash decay rate, sound volume curves, cooldown pacing—small things matter.
4. **Bugs are lessons in disguise.** Every crash taught us something about how Project Zomboid works.
5. **Version management is non-negotiable.** Git saves lives (and mods).

If you're reading this to learn modding, game development, or just how to write better code:

- **Separate concerns** (client/server/shared)
- **Use time-based calculations** (not frame-based)
- **Test in all contexts** (singleplayer, multiplayer, different versions)
- **Document why, not just what**
- **Fail gracefully** (don't crash, degrade)
- **Listen to users** (they find bugs you'll never see)

And most importantly: **Ship it.** Done is better than perfect. We're on v1.5.1, and there's still room for improvement. But players are enjoying realistic thunder physics right now, and that's what matters.

Now go build something cool. And when you hit a bug, remember: you're not failing, you're learning.

---

**Written with thunder in my heart and caffeine in my veins.**
*— The Better Thunder Team*

---

## Appendix: Useful Resources

- **Project Zomboid Modding Lua Docs**: [pzwiki.net/wiki/Modding](https://pzwiki.net/wiki/Modding)
- **Lua 5.1 Reference**: [lua.org/manual/5.1](https://www.lua.org/manual/5.1/)
- **Git Best Practices**: [git-scm.com/book](https://git-scm.com/book/en/v2)
- **Game Programming Patterns**: [gameprogrammingpatterns.com](http://gameprogrammingpatterns.com/)
- **Better Thunder GitHub**: [github.com/felipefl142/ThunderstormsB42](https://github.com/felipefl142/ThunderstormsB42)

**Questions? Suggestions? Found a bug?**
Open an issue on GitHub or find me in the Project Zomboid modding community.

Happy modding! ⚡
