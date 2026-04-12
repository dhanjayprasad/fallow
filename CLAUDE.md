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
  Fallow/                    -- Xcode project
    App/
      FallowApp.swift        -- Entry point, menu bar app
      Views/                 -- SwiftUI views
      ViewModels/            -- Observable state
    Core/
      ResourceGovernor.swift -- Policy engine
      KwaaiNetManager.swift  -- Binary lifecycle (start/stop/health)
      CreditLedger.swift     -- Local credit tracking
    Resources/               -- Assets, bundled kwaainet binary
  .claude/
    agents/                  -- Custom Claude Code agents
    skills/                  -- Custom Claude Code skills
  docs/
    ARCHITECTURE.md          -- Detailed architecture document
    KWAAINET_INTEGRATION.md  -- Integration notes and pinned version
  README.md
```

## Reference Files

- KwaaiNet repo: https://github.com/Kwaai-AI-Lab/KwaaiNet
- KwaaiNet architecture: see docs/KWAAINET_INTEGRATION.md when created
- Apple Human Interface Guidelines for menu bar apps
- macOS code signing and notarisation: Apple TN2206

## Agent and Skill Usage

This project uses custom Claude Code agents for architecture review and critique cycles. See .claude/agents/ for available specialist agents. Key agents:

- **architect** - Reviews architectural decisions, challenges assumptions, identifies risks
- **product-critic** - Evaluates from a user/product perspective, challenges scope, identifies UX gaps
- **security-reviewer** - Audits trust model, sandboxing, data handling, and macOS security patterns
- **swift-expert** - Reviews Swift/SwiftUI code for idiomatic patterns, performance, and Apple platform best practices

Use these agents for iterative review: write a plan or code, invoke the relevant agent to critique it, address the feedback, repeat.
