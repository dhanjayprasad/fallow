---
name: quick-start
description: Quick-start guide for understanding the Fallow codebase. Use when onboarding a new contributor or when you need to orient yourself in the project.
---

# Quick Start Guide

Fallow is a macOS menu bar app that supervises a KwaaiNet binary (v0.4.1). This skill helps you understand what exists and where to go next.

## Codebase Tour (read in this order)

### 1. Entry point
`Fallow/Fallow/Entry/FallowApp.swift`: MenuBarExtra with .window style, plus Window scenes for Chat and Settings. Imports `FallowCore`.

### 2. Central state
`Fallow/Fallow/ViewModels/AppState.swift`: Owns all subsystems. Governor loop auto-starts/stops KwaaiNet based on system conditions. Read this to understand the coordination model.

### 3. KwaaiNet integration (two services)
`Fallow/Fallow/Core/KwaaiNetManager.swift`: Manages two processes:
- P2P daemon (`kwaainet start --daemon`, port 8080 via p2pd)
- API server (`kwaainet serve --port 11435`, local OpenAI API)

Daemon health via `kwaainet status` CLI. API health via `GET /v1/models`.

### 4. Security layer
- `BinaryVerifier.swift`: Code signature check before launching kwaainet
- `AuthTokenManager.swift`: Per-session auth token in `X-Fallow-Token` header
- `PortChecker.swift`: POSIX socket port conflict detection

### 5. Policy engine
`Fallow/Fallow/Core/ResourceGovernor.swift`: Evaluates gates: idle, charging, thermal, Low Power Mode, quiet hours. Uses `SystemMonitoring` and `IdleDetecting` protocols for testability.

### 6. System monitoring
- `SystemMonitor.swift`: IOKit power source, ProcessInfo thermal state
- `IdleDetector.swift`: IOKit HID idle time

### 7. Views
- `StatusMenuView.swift`: Main popover (status, controls, stats, setup progress)
- `OnboardingView.swift`: First-run consent
- `ChatView.swift`: SSE streaming chat against KwaaiNet API on port 11435
- `SettingsView.swift`: Governor configuration

### 8. Reference docs
- `docs/ARCHITECTURE.md`: Layer diagram and design decisions
- `docs/KWAAINET_INTEGRATION.md`: CLI, API, ports, and known gotchas

## Build and Run

```bash
# CLI build (no Xcode required)
cd Fallow && swift build

# Run tests
cd Fallow && swift test --enable-swift-testing

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

# Start daemon (P2P contribution)
kwaainet start --daemon
kwaainet status

# Start local API (for chat)
kwaainet serve --port 11435 llama3.1:8b
# Wait ~12s for model to load, then test:
curl http://localhost:11435/v1/models

# Stop everything
kwaainet stop
```

If something breaks, run `/debug-kwaainet` for systematic troubleshooting.

## Package Structure

```
Package.swift defines three targets:
  FallowCore (library): all code except Entry/
  Fallow (executable): Entry/FallowApp.swift, depends on FallowCore
  FallowTests: unit tests, depends on FallowCore
```

## What to Work On Next

Check the GitHub issues and milestone v0.1.0. Key areas:

1. **Test with real KwaaiNet** (issue #1): validate the full lifecycle
2. **Model download progress**: surface download state during first run
3. **Configurable ports**: allow users to change 11435/8080
4. **XPC helper tool**: true app sandbox (currently Release-only with exceptions)

To add a feature, run `/add-feature` for a step-by-step guide.
