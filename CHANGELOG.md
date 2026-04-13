# Changelog

All notable changes to Fallow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Chat backend switched from `kwaainet shard api` (HuggingFace SafeTensors, 5GB download) to `kwaainet serve <ollama-model>` (uses local Ollama models, GPU-accelerated). Eliminates download requirement.
- Daemon and chat API are now started independently. Daemon (~73MB) starts on Start Contributing; chat API (~2GB+) starts only when chat window opens, stops on close.
- Memory pressure now distinct governor reason (was incorrectly reported as thermal pressure).
- Menu bar icon shows transitioning state and critical memory warning (was static green/grey circle).

### Removed
- Auto-download flow (DownloadState, downloadModel, disk space settings) - no longer needed.
- Dead code: PortChecker.checkKwaaiNetPorts, identifyProcess, AppState.menuBarColour.

### Fixed
- stopChatApi blocking the main actor on waitUntilExit (now async via Task.detached).
- start() incorrectly checked API port; now only checks P2P port.
- Chat window auto-retried failed starts on every appear; now requires explicit Retry button.
- Release entitlements missing network.server and Ollama models read access.
- Stale serve stderr reads could deadlock pipe; now read after termination.

### Added
- macOS menu bar app with status indicator (green/red dot)
- KwaaiNet two-service management: P2P daemon (port 8080) and API server (port 11435)
- Binary code signature verification before launching kwaainet (SecStaticCode, Release builds)
- Port conflict detection (checks 8080 and 11435 before starting)
- Localhost API auth tokens (32-byte random token, passed as env var, included in HTTP headers)
- Automated first-run setup detection (checks for ~/.kwaainet/config.yaml, runs kwaainet setup)
- ResourceGovernor v1: idle threshold, charging gate, Low Power Mode gate, thermal gate, quiet hours
- First-run onboarding with consent screen (gates governor and credit accrual until consent)
- Local chat UI with SSE streaming, cancel support, auto-scroll during token streaming
- Basic status view: running state, model loaded, credits balance, time contributed
- Local credit ledger (earn credits for contributing, spend on chat)
- Settings panel for governor configuration
- App sandbox (Release builds only) with network.client and ~/.kwaainet/ read access
- App icon (10 sizes, generated programmatically via CoreGraphics)
- Unit test suite: ResourceGovernor, CreditLedger, PortChecker, AuthTokenManager, BinaryVerifier
- Testability protocols: SystemMonitoring, IdleDetecting (enable mock injection)
- Xcode project targeting macOS 14.0+, Swift 6.0 strict concurrency
- Shared Xcode scheme for CI and contributor onboarding
- Package.swift with FallowCore library + Fallow executable + FallowTests (apple/swift-testing)
- GitHub Actions CI: SPM build, Xcode build, tests
- Release workflow with DMG creation (signing/notarisation ready when secrets configured)
- `scripts/build-dmg.sh` for local DMG builds (unsigned, signed, or notarised)
- `scripts/generate-icon.swift` for programmatic icon generation
- 5 custom Claude Code agents: architect, product-critic, security-reviewer, swift-expert, ux-reviewer
- 6 custom Claude Code skills: quick-start, kwaainet-integration, architecture-review, release, debug-kwaainet, add-feature
- GitHub issue templates (bug report, feature request)
- LICENSE (MIT), CODE_OF_CONDUCT, CONTRIBUTING guide
- docs/ARCHITECTURE.md with layer diagram and design decisions
- docs/KWAAINET_INTEGRATION.md with CLI, API, auth tokens, and known gotchas
