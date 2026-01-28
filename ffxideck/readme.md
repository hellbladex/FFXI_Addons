# FFXIDeck

**FFXIDeck** is a customizable, virtual macro interface for Final Fantasy XI. Inspired by physical stream decks, it allows you to trigger commands, macros, and scripts across multiple game instances via a TCP socket connection.

## 📁 Project Structure
* **App/**: The C# Avalonia desktop application (the visual grid controller).
* **Addon/**: The Windower4 Lua addon (the receiver that executes commands in-game).

---

## ✨ Features

### 🖥️ Desktop Application
* **Dynamic Grid Layout**: Support for up to 25 columns with a smart-reflow system.
* **Highly Customizable Buttons**:
    * **Visuals**: Custom labels, background colors, and text colors.
    * **Multi-Size**: Expand buttons from standard 1x1 up to 3x6 for high-priority actions.
    * **Typography**: Individual font sizes and bolding per button.
* **Toggle Mode**: Create "On/Off" buttons with separate commands for each state (perfect for follow or auto-target scripts).
* **Smart Management**:
    * **Profile System**: Save and load job-specific layouts (e.g., WHM-Heals, BRD-Songs).
    * **Drag & Drop**: Swap button positions easily using `Ctrl + Left Click`.
    * **Clipboard**: Copy and paste button styles and commands between slots.
* **Modern UI**: Built with Avalonia for a sleek look, featuring resolution auto-scaling and "Always on Top" support.

### 🎮 Windower Addon
* **Socket Listener**: Listens on a local port (default: 12345) for incoming instructions.
* **Targeted Execution**: Send commands to "All" characters or filter by specific character names for precision multi-boxing.
* **Zero Bloat**: Lightweight Lua implementation with minimal memory footprint.

---

## 🚀 Installation & Usage

### 1. The Addon
1. Download the `ffxideck` addon folder.
2. Place it into your `Windower4/addons` directory.
3. In-game, load it via the console:
   ```lua
   //lua load ffxideck
   
### 2. The App
1. Launch `FfxiDeck.exe`.
2. **Configure Buttons**:
    * Right-click any button to access the **Edit** menu.
    * **Label**: Display name for the button.
    * **Target**: Character name to run the command on (or "All").
    * **Command**: The FFXI command (e.g., `/ma "Cure IV" <t>` or `//input /ja "Provoke" <t>`).

---

## 🛠️ Advanced Controls
* **Swap Positions**: `Ctrl + Left Click` a button (it will dim), then click another button to swap them.
* **Profiles**: Type a name in the Save Profile overlay to create a new `.json` layout in the `/profiles` folder.
* **Auto-Save**: Changes to button colors, sizes, and commands are saved automatically to the active profile.

--- 
## 🤝 Contributing & Credits

**Note on Development**: This project was developed with the assistance of AI to help streamline UI layout, logic optimization, and documentation.

*FFXIDeck is a fan-made tool and is not affiliated with Square Enix.*