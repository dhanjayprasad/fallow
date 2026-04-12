# Fallow Architecture

## Overview

Fallow is a native macOS menu bar app that supervises a bundled [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) binary. Fallow owns the product layer (UX, governance, credits, consent). KwaaiNet owns the infrastructure layer (distributed inference, peer networking, model serving).

## Layer Diagram

```
+-----------------------------------------------+
|  Views (SwiftUI)                               |
|  StatusMenuView, ChatView, OnboardingView,     |
|  SettingsView                                  |
+-----------------------------------------------+
|  ViewModel                                     |
|  AppState (coordinates all subsystems)         |
+-----------------------------------------------+
|  Core                                          |
|  KwaaiNetManager  ResourceGovernor             |
|  SystemMonitor    IdleDetector                 |
|  CreditLedger     ProcessRunner    Logging     |
+-----------------------------------------------+
|  KwaaiNet Binary (subprocess)                  |
|  kwaainet CLI + daemon + OpenAI-compatible API |
+-----------------------------------------------+
```

## Source Layout

```
Fallow/
  Fallow.xcodeproj/       Xcode project (primary build system)
  Package.swift            SPM manifest (CLI build verification)
  Fallow/
    FallowApp.swift        Entry point, MenuBarExtra + Window scenes
    Info.plist              LSUIElement = true (menu bar only)
    Fallow.entitlements     Minimal for v0.1
    Core/
      Logging.swift         OSLog subsystem and category definitions
      ProcessRunner.swift   Async subprocess execution via Task.detached
      KwaaiNetManager.swift Binary lifecycle (start/stop/health/model)
      SystemMonitor.swift   Power source (IOKit), thermal, Low Power Mode
      IdleDetector.swift    HID idle time via IOKit registry
      ResourceGovernor.swift Policy engine combining monitor + detector
      CreditLedger.swift    Local credit tracking with UserDefaults persistence
    ViewModels/
      AppState.swift        Central state coordinator, governor loop
    Views/
      StatusMenuView.swift  Menu bar popover with status and controls
      OnboardingView.swift  First-run consent screen
      ChatView.swift        SSE streaming chat against localhost API
      SettingsView.swift    Governor configuration form
    Resources/
      Assets.xcassets/      App icon assets
```

## Key Design Decisions

**All observable classes are @MainActor.** This ensures thread safety under Swift 6 strict concurrency. ProcessRunner uses `Task.detached` to avoid blocking the main actor during subprocess execution.

**KwaaiNet is supervised, not embedded.** Fallow communicates with KwaaiNet via its local HTTP API (ports 8080 and 8000) and CLI for lifecycle management. No FFI, no in-process linking. If KwaaiNet changes its API surface, only KwaaiNetManager needs updating.

**ResourceGovernor is a pure policy engine.** It reads state from SystemMonitor and IdleDetector, evaluates a set of gates (idle, charging, thermal, quiet hours), and reports whether contribution should proceed. It does not directly start or stop the daemon; AppState's governor loop acts on its recommendations.

**Credit economy is app-local for v0.1.** CreditLedger tracks earned and spent credits in UserDefaults. This is a local fiction to validate the UX; a real server-backed ledger is planned for v0.2.

## Communication with KwaaiNet

| Purpose | Protocol | Endpoint |
|---------|----------|----------|
| Node health | HTTP GET | `localhost:8080/health` |
| Model discovery | HTTP GET | `localhost:8000/v1/models` |
| Chat completions | HTTP POST (SSE) | `localhost:8000/v1/chat/completions` |
| Start daemon | CLI | `kwaainet start --daemon` |
| Stop daemon | CLI | `kwaainet stop` |

See [KWAAINET_INTEGRATION.md](KWAAINET_INTEGRATION.md) for detailed integration notes.
