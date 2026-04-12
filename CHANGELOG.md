# Changelog

All notable changes to Fallow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- macOS menu bar app with status indicator (green/red dot)
- KwaaiNet binary lifecycle management (start, stop, health check with 30s startup polling)
- ResourceGovernor v1: idle threshold, charging gate, Low Power Mode gate, thermal gate, quiet hours
- First-run onboarding with consent screen (gates governor and credit accrual)
- Local chat UI with SSE streaming, cancel support, auto-scroll during streaming
- Basic status view: running state, model loaded, credits balance, time contributed
- Local credit ledger (earn credits for contributing, spend on chat)
- Settings panel for governor configuration
- Xcode project targeting macOS 14.0+, Swift 6.0 strict concurrency
- Shared Xcode scheme for CI and contributor onboarding
- Package.swift for CLI build verification
- GitHub Actions CI: SPM build + Xcode build
- Release workflow with DMG creation (signing/notarisation ready when secrets configured)
- `scripts/build-dmg.sh` for local DMG builds (unsigned, signed, or notarised)
- 5 custom Claude Code agents: architect, product-critic, security-reviewer, swift-expert, ux-reviewer
- 6 custom Claude Code skills: quick-start, kwaainet-integration, architecture-review, release, debug-kwaainet, add-feature
- GitHub issue templates (bug report, feature request)
- LICENSE (MIT), CODE_OF_CONDUCT, CONTRIBUTING guide
- docs/ARCHITECTURE.md with layer diagram and design decisions
- docs/KWAAINET_INTEGRATION.md with CLI, API, and known gotchas
