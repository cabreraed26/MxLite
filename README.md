# MxLite 🖱️⚡️

**Ultra-lightweight, native macOS controller for Logitech MX Master 3S & MX Keys.**

MxLite replaces heavy, resource-intensive companion software with a lightning-fast native macOS application built with Swift, `IOKit`, `CoreGraphics`, and `AppKit`.

![macOS](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia-black?style=flat-square&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1%2FM2%2FM3%2FM4)-blue?style=flat-square)
![Swift](https://img.shields.io/badge/Language-Swift%205-orange?style=flat-square&logo=swift)
![Dependencies](https://img.shields.io/badge/Dependencies-Zero-success?style=flat-square)

---

## 🌟 Key Features

* **🖱️ 120Hz ProMotion Smooth Scrolling**: Authentic Apple Magic Trackpad inertial scrolling physics for high-refresh-rate displays.
* **📈 Non-Linear Velocity Compression**: Uses logarithmic ($\sqrt{N}$) acceleration curves to eliminate abrupt speed jumps when spinning the scroll wheel faster.
* **👍 Thumb Rest Button & 5-Way Gestures**: Full support for the Logitech MX Master 3S thumb rest button:
  * **Single Click**: Mission Control / Custom action.
  * **Drag Up ↑**: Mission Control.
  * **Drag Down ↓**: App Exposé.
  * **Drag Left ← / Right →**: Switch between Desktop Spaces.
* **🔙 Front & Back Navigation Buttons**: Dedicated mapping for browser navigation (`Cmd + Left Arrow` / `Cmd + Right Arrow`) compatible with Safari, Google Chrome, Arc, and Brave across all keyboard layouts.
* **🔕 Discreet Menu Bar Extra (`LSUIElement`)**: Runs silently in the macOS top Menu Bar. Hidden from the Dock, `Cmd + Tab` switcher, and Mission Control.
* **🎛️ Live Quick Controls**: Adjust scroll sensitivity (`0.2x` - `5.0x`) and toggle Smooth Scroll directly from the Menu Bar dropdown menu.
* **⚡️ Minimal Overhead**: Native execution with 0.0% idle CPU overhead.

---

## 🚀 Quick Start & Installation

### Option A: Run Pre-Compiled Release

1. Download or locate `MxLite.app` in the [`bin/`](bin/MxLite.app) directory:
   ```bash
   open bin/MxLite.app
   ```
2. Grant **Accessibility** permissions when prompted by macOS.
3. Access **MxLite** from the top right Menu Bar (look for the mouse icon 🖱️).

### Option B: Build from Source with Xcode

1. Clone the repository:
   ```bash
   git clone https://github.com/cabreraed26/MxLite.git
   cd MxLite
   ```
2. Open the project in Xcode:
   ```bash
   open MxLite.xcodeproj
   ```
3. Build & Run (**`⌘ + R`**) or generate a Release binary:
   ```bash
   xcodebuild -project MxLite.xcodeproj -scheme MxLite -configuration Release -derivedDataPath build/DerivedData build
   ```

---

## 🔒 Permissions & Security

MxLite requires standard macOS permissions to perform low-level input translation:

1. **Accessibility Permissions** (`System Settings ➔ Privacy & Security ➔ Accessibility`): Required to intercept scroll events via `CGEventTap` and synthesize gesture shortcuts.
2. **Input Monitoring** (`System Settings ➔ Privacy & Security ➔ Input Monitoring`): Required for low-level `IOKit` HID button packet reading.

> **Privacy Guarantee**: MxLite is 100% open-source, offline, and contains zero analytics, telemetry, or network code.

---

## 🛠️ Architecture Overview

MxLite is engineered as a zero-dependency macOS agent:

```
                  ┌──────────────────────────────┐
                  │    macOS Top Menu Bar Extra  │
                  └──────────────┬───────────────┘
                                 │
                   ┌─────────────┴────────────┐
                   │  AppKit Native Controller│
                   └─────────────┬────────────┘
                                 │
      ┌──────────────────────────┴──────────────────────────┐
      │                                                     │
┌─────▼─────────────────────────┐         ┌─────────────────▼───────────────┐
│     KineticScrollEngine       │         │           HIDMonitor            │
│  (120Hz CoreGraphics Events)  │         │  (Low-Level IOKit HID Driver)  │
└───────────────────────────────┘         └─────────────────────────────────┘
```

* **CoreGraphics EventTap (`CGEventTap`)**: Intercepts discrete scroll notches and converts them into continuous sub-pixel high-resolution scroll events.
* **IOKit Hardware Monitor (`IOHIDManager`)**: Filters hardware button events directly at the kernel layer, ignoring X/Y pointer movement for zero idle CPU usage.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.
