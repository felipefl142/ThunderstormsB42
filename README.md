# Better Thunder (B42)

**Better Thunder** is a Project Zomboid mod designed for **Build 42** that overhauls the game's thunderstorm experience. It adds immersive, physics-based lightning and thunder effects that are fully networked for multiplayer compatibility.

![Mod Poster](Thunderstorms%20v2/preview.png)

## ⚡ Features

*   **Physics-Based Sound Delay:** Thunder sounds are delayed based on the distance of the lightning strike, simulating the real-world speed of sound (~340m/s). You'll see the flash before you hear the rumble!
*   **Dynamic Visuals:** Lightning flashes vary in intensity depending on how close the strike is.
    *   **Close strikes:** Blindingly bright and immediate.
    *   **Distant strikes:** Faint, atmospheric flickers.
*   **Immersive Soundscape:** Includes a variety of high-quality thunder samples categorized by distance:
    *   *Close*: Loud, cracking thunder.
    *   *Medium*: Rolling rumbles.
    *   *Far*: Distant, low-frequency echoes.
*   **Multiplayer Ready:** Lightning events are synchronized between the server and all clients. Everyone sees the flash and hears the thunder at the appropriate time relative to their position.

## 🛠️ Compatibility

This mod is built specifically for **Project Zomboid Build 42**.
*   Verified support for **Build 42.13+**.
*   Includes compatibility layers for slightly older B42 unstable builds.

## 📥 Installation

1.  Subscribe to the mod on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3651047804).
2.  Enable the mod in the main menu or your server configuration.
    *   **Mod ID:** `BetterThunder42`
    *   **Workshop ID:** `3651047804`

## ⚙️ Configuration

The mod works out of the box. Currently, core settings like the speed of sound and strike chances are tuned for realism but can be adjusted in the lua files if necessary.

## 📂 Project Structure

For developers or contributors, the repository is structured as follows:

*   `Thunderstorms v2/`: Main mod files.
    *   `42/`: Logic specific to initial Build 42.
    *   `42.13/`: Updated logic for Build 42.13+.
    *   `Contents/mods/Thunderstorms/media/`:
        *   `lua/client/`: Client-side visual and audio handling (`Thunder_Client.lua`).
        *   `lua/server/`: Server-side event coordination (`Thunder_Server.lua`).
        *   `sound/`: Custom audio assets (.ogg).
        *   `lua/tests/`: Comprehensive test suite using Busted framework.

## 🧪 Testing

The mod includes a professional test suite using the Busted testing framework:

*   **200+ automated tests** covering all mod components
*   **100% passing unit tests** validating configuration and physics
*   **Component tests** for server, client, and UI modules
*   **Integration tests** validating client-server communication
*   **Comprehensive mocks** of Project Zomboid API for isolated testing

### Running Tests

```bash
cd "Thunderstorms v2/Contents/mods/Thunderstorms/42.13/media/lua/tests"
./run_busted.sh
```

See `tests/README.md` for detailed testing documentation.

## 📋 Command Reference

### Test Commands (CLI)

| Command | Description | Example |
|---------|-------------|---------|
| `./run_busted.sh` | Run all tests with colored output | `cd tests && ./run_busted.sh` |
| `busted spec/unit/` | Run unit tests only (100% passing) | `lua5.1 /usr/.../busted spec/unit/` |
| `busted spec/component/` | Run component tests (server, client, UI) | `lua5.1 /usr/.../busted spec/component/` |
| `busted spec/integration/` | Run integration tests (networking) | `lua5.1 /usr/.../busted spec/integration/` |
| `busted <file>` | Run specific test file | `busted spec/unit/Thunder_Shared_spec.lua` |

### Lua Console Commands (In-Game)

Press `` ` `` or `~` to open the Lua console, then enter:

#### Thunder Control Commands

| Command | Description | Example |
|---------|-------------|---------|
| `ForceThunder(distance)` | Trigger thunder at specific distance via server | `ForceThunder(500)` |
| `TestThunder(distance)` | Test thunder effect (may call server in SP) | `TestThunder(1000)` |
| `TestThunderClient(distance)` | Test thunder client-side only (guaranteed) | `TestThunderClient(750)` |
| `SetThunderFrequency(multiplier)` | Adjust thunder frequency (0.1-5.0) | `SetThunderFrequency(2.0)` |
| `SetThunderMultiplier(multiplier)` | Alias for SetThunderFrequency | `SetThunderMultiplier(1.5)` |
| `GetStormIntensity()` | Display current storm analysis | `GetStormIntensity()` |

#### Debug & Feature Toggles

| Command | Description | Example |
|---------|-------------|---------|
| `ThunderToggleDebug()` | Toggle debug logging on/off | `ThunderToggleDebug(true)` |
| `ThunderToggleLighting()` | Toggle dynamic lightning lights | `ThunderToggleLighting(false)` |
| `ThunderToggleIndoorDetection()` | Toggle indoor sound muffling | `ThunderToggleIndoorDetection(true)` |
| `SetNativeMode(enabled)` | Sync with game's internal weather | `SetNativeMode(true)` |

#### Weather Diagnostics

| Command | Description | Example |
|---------|-------------|---------|
| `getClimateManager():getCloudIntensity()` | Check current cloud intensity (0-1) | Returns: `0.75` |
| `getClimateManager():getRainIntensity()` | Check current rain intensity (0-1) | Returns: `0.60` |
| `getClimateManager():getWindIntensity()` | Check current wind intensity (0-1) | Returns: `0.40` |

#### Legacy Test Commands (In-Game)

| Command | Description |
|---------|-------------|
| `require "tests/legacy/RunAllTests"` | Run all legacy in-game tests |
| `require "tests/legacy/Thunder_Shared_Test"` | Run shared config tests |
| `require "tests/legacy/Thunder_Server_Test"` | Run server tests |
| `require "tests/legacy/Thunder_Client_Test"` | Run client tests |

**Note:** Distance is measured in tiles. Recommended ranges:
- Close: 50-200 tiles
- Medium: 200-800 tiles
- Far: 800-8000 tiles (max hearing distance)

## 📝 Credits

*   Developed by [FelipeFRL]
*   Sound assets courtesy of https://pixabay.com/

---
*Created for the Project Zomboid community.*
