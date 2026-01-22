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

## 📝 Credits

*   Developed by [FelipeFRL]
*   Sound assets courtesy of https://pixabay.com/

---
*Created for the Project Zomboid community.*
