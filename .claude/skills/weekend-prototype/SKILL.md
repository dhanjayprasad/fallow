---
name: weekend-prototype
description: Guide for building the minimal Fallow prototype in a single weekend. Use when starting the initial build or when scope creep threatens to delay the first working version.
---

# Weekend Prototype Skill

Build the thinnest possible working Fallow prototype. This is the "proof of concept before committing" build.

## Goal

A macOS menu bar app that:
1. Shows a status icon (green dot = KwaaiNet running, red dot = stopped)
2. Has a "Start Contributing" / "Stop Contributing" toggle
3. Launches `kwaainet start --daemon` as a supervised subprocess
4. Stops it gracefully with `kwaainet stop`
5. Shows basic status from `kwaainet status` output

That is ALL. No credits, no chat UI, no governor, no onboarding. Just prove the integration works.

## Steps

### Step 1: Get KwaaiNet Running Manually

```bash
# Download the macOS binary
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/Kwaai-AI-Lab/KwaaiNet/releases/latest/download/kwaainet-installer.sh | sh

# Run setup
kwaainet setup

# Run benchmark
kwaainet benchmark

# Start daemon
kwaainet start --daemon

# Verify it is running
kwaainet status

# Verify local API responds
curl http://localhost:8080/health

# Stop it
kwaainet stop
```

Document: what worked, what broke, how long model download took, what the status output format looks like. This is your integration contract.

### Step 2: Create Minimal Xcode Project

- macOS App, SwiftUI lifecycle
- Set LSUIElement = true in Info.plist (menu bar only, no dock icon)
- Use MenuBarExtra for the menu bar presence
- Target macOS 14.0+

### Step 3: Implement KwaaiNetManager

A single class that wraps Process/subprocess management:
- `start()`: runs `kwaainet start --daemon`
- `stop()`: runs `kwaainet stop`
- `status()`: runs `kwaainet status`, parses output
- `isRunning`: published boolean

### Step 4: Wire Up the Menu Bar

- Green/red SF Symbol based on `isRunning`
- Toggle button: Start/Stop
- Status text showing model name and connection count
- Quit button

### Step 5: Test

- Launch the app
- Click Start, verify kwaainet daemon starts
- Verify green dot appears
- Click Stop, verify clean shutdown
- Quit the app, verify kwaainet is also stopped
- Launch the app with kwaainet already running, verify it detects existing daemon

## What You Learn

- Whether kwaainet behaves well as a supervised process
- How long cold start takes (model download)
- What the API surface actually looks like in practice
- Whether the integration seam is clean enough to build on
- Whether this is fun to work on (important for a side project)

## What You Do NOT Build

- ResourceGovernor (no idle detection yet)
- Credit system
- Chat UI
- Onboarding/consent screens
- Telemetry
- Code signing/notarisation
- Anything involving networking configuration
