# Control

A native macOS smart home controller and menu bar application with a headless Terminal CLI (`control`).

Supports local network and cloud control for:
- **WiZ Smart Lights** (Local UDP socket protocol `38899`)
- **Atomberg Smart Fans** (Cloud API & Local discovery)
- **Homemate / Tuya Multi-Socket Power Strips & Plugs** (Cloud Bridge & Telemetry)
- **Carrier / Midea Air Conditioners** (Local 8370 protocol)

---

## Security & Privacy Architecture

- **Zero Hardcoded Secrets**: No API keys, credentials, IP addresses, or device IDs are stored in the repository.
- **Local User Storage**: Device configs, paired IDs, and cloud API tokens are saved exclusively on the user's local machine in standard macOS sandbox directories:
  - Devices & Scenes: `~/Library/Application Support/Control/devices.json`
  - Cloud Credentials: macOS `UserDefaults` (`com.harikrish.control`)

---

## Directory Structure

```
Control/
├── .gitignore             # Git ignore rules for SPM .build, app bundles, and local data
├── LICENSE                # MIT License
├── README.md              # Project documentation and CLI usage guide
├── Package.swift          # Swift Package Manager manifest
├── bundle_app.sh          # Shell script to build and package Control.app
├── tuya_helper.py         # Tuya Cloud Bridge helper (invoked by GUI & CLI)
├── bin/
│   └── control            # Standalone terminal CLI executable
├── Control/               # Native macOS SwiftUI application
│   ├── Assets/            # AppIcon.icns, app-logo.png, splash assets
│   ├── Adapters/          # Hardware communication adapters (WiZ, Atomberg, Tuya, Midea)
│   ├── Core/              # Device models, commands, persistence, network scanner
│   ├── ViewModels/        # Device and scene state management
│   ├── Views/             # SwiftUI menu bar UI, dashboard, device sheets
│   └── ControlApp.swift   # macOS App entry point
├── scripts/
│   └── create_dmg.sh      # Automated macOS .dmg release packager
└── ControlTests/          # Unit and integration test suite
```

---

## Terminal CLI (`control`)

The `control` command allows you to control appliances, trigger scenes, and pair new devices directly from your terminal.

### Quick Commands

```bash
# List devices with real-time status
control list

# List all device call names and aliases
control names

# Quick Scenes
control scenes
control scene "Good Night"
control scene "Movie Mode"
control scene "All Off"
```

### Controlling Devices by Name

```bash
# Fan named 'Flow'
control Flow on / off
control Flow speed 4
control Flow boost on
control Flow status

# Light named 'WiZ Light' (or alias 'wiz')
control "WiZ Light" on / off
control wiz 80                      # Set brightness to 80%
control wiz temp 2700               # 2700K Warm White
control wiz scene cozy              # Set WiZ scene

# 4-Socket Power Strip named 'Homemate'
control homemate 1 on               # Socket 1 ON
control homemate 2 off              # Socket 2 OFF
control homemate all on             # All sockets ON
control homemate status             # Power telemetry (watts, volts, amps)
```

### Connecting New Devices from Terminal

```bash
# Auto-scan local Wi-Fi and accounts
control scan

# Connect a WiZ Light by IP
control add light 192.168.1.50 "Desk Light"

# Connect Atomberg Fans from cloud account
control add fan "Bedroom Fan"

# Connect a Homemate / Tuya Plug or Strip
control add plug <device_id> "Studio Strip" 4

# Interactive pairing wizard
control add

# Remove / disconnect a device
control remove "Desk Light"
```

---

## Building the macOS App Bundle & DMG

### 1. Build Control.app
```bash
./bundle_app.sh
open Control.app
```

### 2. Build Release .dmg (for sharing / other Macs)
```bash
./scripts/create_dmg.sh
```
The resulting `Control.dmg` can be copied or AirDropped to another MacBook.

---

## Disclaimer

This is an independent, community-driven open-source project. All product names, logos, brands, and registered trademarks (including WiZ, Atomberg, Tuya, Homemate, Carrier, and Midea) are property of their respective owners. Their use in this project is strictly for identification and hardware interoperability purposes only and does not imply any affiliation, sponsorship, or endorsement.

---

## License

This project is licensed under the [MIT License](LICENSE).
