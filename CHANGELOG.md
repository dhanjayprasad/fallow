# Changelog

All notable changes to Fallow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- macOS menu bar app with status indicator (green/red dot)
- KwaaiNet binary lifecycle management (start, stop, health check)
- ResourceGovernor v1: idle threshold, charging gate, Low Power Mode gate, thermal gate, quiet hours
- First-run onboarding with consent screen
- Local chat UI with SSE streaming against KwaaiNet OpenAI-compatible API
- Basic status view: running state, model loaded, credits balance, time contributed
- Local credit ledger (earn credits for contributing, spend on chat)
- Settings panel for governor configuration
- Xcode project targeting macOS 14+, Swift 6.0
- Package.swift for CLI build verification
- GitHub Actions CI workflow
