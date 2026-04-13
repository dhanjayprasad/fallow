# Fallow Architecture

## Overview

Fallow is a native macOS menu bar app that supervises a bundled [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) binary (tested against v0.4.1). Fallow owns the product layer (UX, governance, credits, consent). KwaaiNet owns the infrastructure layer (distributed inference, peer networking, model serving).

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
|  CreditLedger     ProcessRunner                |
|  PortChecker      AuthTokenManager             |
|  BinaryVerifier   Logging                      |
+-----------------------------------------------+
|  KwaaiNet (supervised processes)               |
|  kwaainet start --daemon (P2P, port 8080)      |
|  kwaainet serve <ollama-model> (chat API,      |
|    port 11435, started on demand)              |
+-----------------------------------------------+
```

## Source Layout

```
Fallow/
  Fallow.xcodeproj/       Xcode project (primary build system)
  Package.swift            SPM: FallowCore (lib) + Fallow (exe) + FallowTests
  Fallow/
    Entry/
      FallowApp.swift      @main entry point, MenuBarExtra + Window scenes
    Info.plist              LSUIElement = true (menu bar only)
    Fallow.entitlements     Debug entitlements (no sandbox)
    FallowRelease.entitlements  Release entitlements (sandboxed)
    Core/
      Logging.swift         OSLog subsystem and category definitions
      ProcessRunner.swift   Async subprocess execution via Task.detached
      KwaaiNetManager.swift Two-service lifecycle (daemon + API server)
      SystemMonitor.swift   Power source (IOKit), thermal, Low Power Mode
      IdleDetector.swift    HID idle time via IOKit registry
      ResourceGovernor.swift Policy engine (protocols: SystemMonitoring, IdleDetecting)
      CreditLedger.swift    Local credit tracking (injectable UserDefaults)
      PortChecker.swift     POSIX socket port conflict detection
      AuthTokenManager.swift Session auth token generation (SecRandomCopyBytes)
      BinaryVerifier.swift  Code signature verification (SecStaticCode)
    ViewModels/
      AppState.swift        Central state coordinator, governor loop
    Views/
      StatusMenuView.swift  Menu bar popover with status and controls
      OnboardingView.swift  First-run consent screen
      ChatView.swift        SSE streaming chat against localhost API
      SettingsView.swift    Governor configuration form
    Resources/
      Assets.xcassets/      App icon assets (10 programmatic PNGs)
  Tests/FallowTests/        Unit tests (apple/swift-testing framework)
```

## Key Design Decisions

**All observable classes are @MainActor.** This ensures thread safety under Swift 6 strict concurrency. ProcessRunner uses `Task.detached` to avoid blocking the main actor during subprocess execution.

**Two supervised processes, started independently.** The P2P daemon (`kwaainet start --daemon`) runs on Start Contributing and uses ~73MB of memory. The chat API (`kwaainet serve <ollama-model>`) starts only when the chat window opens and uses GPU-accelerated llama.cpp with a local Ollama model (~2GB for llama3.2:3b). Daemon health via `kwaainet status` CLI; API health via `GET /v1/models`. The chat window stops the API on close to free memory.

**ResourceGovernor is a pure policy engine.** It reads state from SystemMonitoring and IdleDetecting protocols (enabling mock injection for tests), evaluates a set of gates (idle, charging, thermal, quiet hours), and reports whether contribution should proceed. AppState's governor loop acts on its recommendations.

**Credit economy is app-local for v0.1.** CreditLedger tracks earned and spent credits in UserDefaults (injectable for test isolation). This is a local fiction to validate the UX; a real server-backed ledger is planned for v0.2.

**Package access for testability.** All Core and ViewModel types use `package` access, enabling the FallowTests target to import FallowCore with `@testable import`.

## Communication with KwaaiNet

| Purpose | Method | Details |
|---------|--------|---------|
| Start P2P daemon | CLI | `kwaainet start --daemon` (port 8080 via p2pd) |
| Stop P2P daemon | CLI | `kwaainet stop` |
| Daemon health | CLI | `kwaainet status` (parse for "Running") |
| Start chat API | Process | `kwaainet serve --port 11435 <ollama-model>` (lazy, on chat open) |
| Stop chat API | SIGTERM | Sent on chat window close |
| Model discovery | HTTP GET | `localhost:11435/v1/models` |
| Chat completions | HTTP POST (SSE) | `localhost:11435/v1/chat/completions` |
| First-run setup | CLI | `kwaainet setup` (if `~/.kwaainet/config.yaml` missing) |
| Local model detection | Filesystem | `~/.ollama/models/manifests/registry.ollama.ai/library/` |

See [KWAAINET_INTEGRATION.md](KWAAINET_INTEGRATION.md) for detailed integration notes.
