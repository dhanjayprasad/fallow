---
name: weekend-prototype
description: Quick-start guide for understanding the Fallow codebase. Use when onboarding a new contributor or when you need to orient yourself in the project.
---

# Quick Start Guide

Fallow is a macOS menu bar app that supervises a KwaaiNet binary. The prototype is built. This skill helps you understand what exists and where to go next.

## Codebase Tour (read in this order)

### 1. Entry point
`Fallow/Fallow/FallowApp.swift` -- MenuBarExtra with .window style, plus Window scenes for Chat and Settings.

### 2. Central state
`Fallow/Fallow/ViewModels/AppState.swift` -- Owns all subsystems. Governor loop auto-starts/stops KwaaiNet based on system conditions. Read this to understand the coordination model.

### 3. KwaaiNet integration
`Fallow/Fallow/Core/KwaaiNetManager.swift` -- Start/stop daemon via CLI, health checks via HTTP, model discovery via `/v1/models`. This is the integration seam.

### 4. Policy engine
`Fallow/Fallow/Core/ResourceGovernor.swift` -- Evaluates gates: idle, charging, thermal, Low Power Mode, quiet hours. Pure logic, no side effects.

### 5. System monitoring
- `Fallow/Fallow/Core/SystemMonitor.swift` -- IOKit power source, ProcessInfo thermal state
- `Fallow/Fallow/Core/IdleDetector.swift` -- IOKit HID idle time

### 6. Views
- `StatusMenuView.swift` -- Main popover (status, controls, stats, navigation)
- `OnboardingView.swift` -- First-run consent
- `ChatView.swift` -- SSE streaming chat against KwaaiNet API
- `SettingsView.swift` -- Governor configuration

### 7. Reference docs
- `docs/ARCHITECTURE.md` -- Layer diagram and design decisions
- `docs/KWAAINET_INTEGRATION.md` -- CLI, API, and known gotchas

## Build and Run

```bash
# CLI build (no Xcode required)
cd Fallow && swift build

# Xcode build
open Fallow/Fallow.xcodeproj
# Cmd+B to build, Cmd+R to run
# App appears in menu bar (no Dock icon)
```

## Test with KwaaiNet

```bash
# Install KwaaiNet
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/Kwaai-AI-Lab/KwaaiNet/releases/latest/download/kwaainet-installer.sh | sh
kwaainet setup

# Verify it works
kwaainet start --daemon
curl http://localhost:8080/health
kwaainet stop

# Now run Fallow and click "Start Contributing"
```

If something breaks, run `/debug-kwaainet` for systematic troubleshooting.

## What to Work On Next

Check the GitHub issues and milestone v0.1.0. Key areas:

1. **Test with real KwaaiNet** (issue #1) -- validate the integration contract
2. **First-run setup flow** -- `kwaainet setup` is not yet automated
3. **Port conflict detection** -- ports 8080/8000 are hardcoded
4. **App sandbox** -- currently unsandboxed, needs entitlements work
5. **Code signing** -- configure Developer ID for DMG distribution

To add a feature, run `/add-feature` for a step-by-step guide.
