# Fallow - Project CLAUDE.md

## Project Overview

Fallow is a native macOS menu bar app that contributes idle compute to a distributed LLM inference network and gives users AI access in return. Powered by KwaaiNet (a Rust-native distributed AI inference node).

**Tagline:** "Put your idle Mac to work."

**Architecture:** Swift/SwiftUI menu bar app that supervises a bundled KwaaiNet binary. Fallow owns the product layer (UX, governance, credits, trust). KwaaiNet owns the infrastructure layer (distributed inference, DHT, peer networking, model serving).

## Key Decisions (Do Not Revisit)

These decisions survived three rounds of architectural review and two rounds of external critique. They are final unless new evidence emerges:

- **Build on KwaaiNet, not from scratch.** KwaaiNet (MIT licensed, Rust-native, v0.3.49) already ships distributed shard inference, Petals DHT compatibility, Metal GPU acceleration, OpenAI-compatible API, daemon mode, and cross-platform binaries. Rebuilding this would be months of duplicated effort.
- **Swift/SwiftUI for the macOS app shell.** Native, no Electron, no embedded Python.
- **KwaaiNet binary as a supervised subprocess.** Communicate via its local API and CLI, not deep FFI. Pin to a specific tested version. Disable its self-update inside the bundle.
- **Centralised coordination node for v0.1.** Honest framing: peer-to-peer data plane, centrally coordinated control plane. Decentralise later.
- **0.1.0 versioning.** Signals active development and invites contribution.
- **macOS-only for v0.1.** Desktop/laptop contribution only. No mobile contributor messaging.
- **Fallow-local credit system.** App-level reciprocity, not protocol-native. Called "Fallow credits" or "Fallow balance."

## v0.1 Scope (Locked)

### Must Ship
- Menu bar app with status indicator (running/stopped/contributing)
- First-run onboarding with consent screen explaining what contributing means
- KwaaiNet binary lifecycle management (start/stop/health check)
- ResourceGovernor v1: idle threshold, charging/battery gate, Low Power Mode gate, thermal state gate, quiet hours
- Local chat UI against KwaaiNet's OpenAI-compatible API
- Basic status view: running state, model loaded, tokens generated, time contributed
- Signed and notarised DMG distribution

### Defer to v0.2+
- Real credit economy with server-backed ledger
- Sophisticated telemetry backend
- Contribution leaderboard
- Reputation system
- Complex thermal policy
- Advanced dashboard analytics
- Model allowlist management UI
- Windows/Linux platform shells

### Killed
- Mobile contributor nodes
- Multi-backend adapter architecture
- Claims about decentralisation
- Strong claims about output correctness verification
- "Any and all devices" messaging

## Coding Conventions

- **Language:** Swift 6.0+, SwiftUI, targeting macOS 14+
- **No em dashes or en dashes** in any generated text, comments, or documentation. Use commas, semicolons, colons, or rewrite the sentence instead. This is a hard rule.
- **NZ English spelling** throughout (organisation, behaviour, colour, etc.)
- **Architecture:** Menu bar app (LSUIElement = true). Separate process for KwaaiNet binary, not in-process.
- **Communication with KwaaiNet:** Via its local HTTP API (default port 8080 for node health, port 8000 for OpenAI-compatible API) and CLI for lifecycle management.
- **Error handling:** Never crash silently. Log all errors via OSLog. Surface user-facing errors in the menu bar status.
- **Dependencies:** Minimise third-party Swift packages. Prefer Foundation, AppKit, SwiftUI, Network.framework, ServiceManagement, OSLog.

## File Structure

```
fallow/
  Fallow/                          -- Xcode project root
    Fallow.xcodeproj/              -- Xcode project file
    Package.swift                  -- SPM manifest (CLI build verification)
    Fallow/                        -- Source root
      FallowApp.swift              -- Entry point, MenuBarExtra + Window scenes
      Info.plist                   -- LSUIElement = true
      Fallow.entitlements          -- App entitlements
      Core/
        Logging.swift              -- OSLog subsystem definitions
        ProcessRunner.swift        -- Async subprocess execution
        KwaaiNetManager.swift      -- Binary lifecycle (start/stop/health)
        SystemMonitor.swift        -- Power, thermal, Low Power Mode (IOKit)
        IdleDetector.swift         -- HID idle time (IOKit)
        ResourceGovernor.swift     -- Policy engine
        CreditLedger.swift         -- Local credit tracking
      ViewModels/
        AppState.swift             -- Central state coordinator
      Views/
        StatusMenuView.swift       -- Menu bar popover
        OnboardingView.swift       -- First-run consent
        ChatView.swift             -- SSE streaming chat
        SettingsView.swift         -- Governor configuration
      Resources/
        Assets.xcassets/           -- App icon assets
  scripts/
    build-dmg.sh                   -- Build, sign, and notarise a DMG
  .claude/
    agents/                        -- Custom Claude Code agents (4)
    skills/                        -- Custom Claude Code skills (6)
  .github/
    workflows/build.yml            -- CI build (SPM + Xcode)
    workflows/release.yml          -- Release pipeline (WIP)
    ISSUE_TEMPLATE/                -- Bug report and feature request templates
  docs/
    ARCHITECTURE.md                -- Detailed architecture document
    KWAAINET_INTEGRATION.md        -- Integration notes and pinned version
    CLAUDE_CODE_WORKFLOW.md        -- Guide for using Claude Code with the project
  README.md
  LICENSE
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md
```

## Reference Files

- KwaaiNet repo: https://github.com/Kwaai-AI-Lab/KwaaiNet
- KwaaiNet integration: see docs/KWAAINET_INTEGRATION.md
- Architecture: see docs/ARCHITECTURE.md
- Apple Human Interface Guidelines for menu bar apps
- macOS code signing and notarisation: Apple TN2206

## Agent and Skill Usage

This project uses custom Claude Code agents for architecture review and critique cycles. See .claude/agents/ for available specialist agents. Key agents:

- **architect** - Reviews architectural decisions, challenges assumptions, identifies risks
- **product-critic** - Evaluates from a user/product perspective, challenges scope, identifies UX gaps
- **security-reviewer** - Audits trust model, sandboxing, data handling, and macOS security patterns
- **swift-expert** - Reviews Swift/SwiftUI code for idiomatic patterns, performance, and Apple platform best practices

Use these agents for iterative review: write a plan or code, invoke the relevant agent to critique it, address the feedback, repeat.

Key skills:

- **/weekend-prototype** - Quick-start codebase tour for new contributors
- **/kwaainet-integration** - KwaaiNet CLI, API, and gotchas reference
- **/architecture-review** - Multi-agent review cycle
- **/release** - Build, sign, and distribute a DMG
- **/debug-kwaainet** - Troubleshoot KwaaiNet integration issues
- **/add-feature** - Step-by-step guide for contributing a new feature
