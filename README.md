# Fallow

**Put your idle Mac to work.**

A native macOS menu bar app that contributes spare compute to a distributed LLM network and gives you AI access in return. Powered by [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet).

## What It Does

1. You install Fallow. A single DMG, nothing else to set up.
2. When your Mac is idle (configurable: charging only, thermal limits, quiet hours), Fallow contributes compute to a distributed AI network.
3. You earn Fallow credits for contributing.
4. You spend credits chatting with LLMs through Fallow's built-in interface.

You never notice it running. Your Mac works for you while you sleep.

## Status

**Pre-release.** Currently building the weekend prototype to validate the KwaaiNet integration.

## Architecture

Fallow is the product layer. KwaaiNet is the infrastructure layer.

- **Fallow** (Swift/SwiftUI): Menu bar app, ResourceGovernor, credit system, consent UX, chat interface
- **KwaaiNet** (Rust, bundled): Distributed inference, peer networking, model serving, OpenAI-compatible API

Fallow supervises the KwaaiNet binary as a subprocess. They communicate via KwaaiNet's local HTTP API. This is a clean integration boundary: if KwaaiNet changes, only the integration module needs updating.

## Development Setup

### Prerequisites

- macOS 14.0+
- Xcode 16+
- [KwaaiNet CLI](https://github.com/Kwaai-AI-Lab/KwaaiNet/releases/latest) installed for testing
- [Claude Code](https://docs.claude.com) (recommended for development)

### Claude Code Setup

This project includes custom agents and skills for Claude Code:

- `.claude/agents/architect.md` -- Challenges architectural decisions
- `.claude/agents/product-critic.md` -- Evaluates from user perspective
- `.claude/agents/security-reviewer.md` -- Audits trust and security
- `.claude/agents/swift-expert.md` -- Reviews Swift code quality
- `.claude/skills/weekend-prototype/` -- Guide for the initial prototype build
- `.claude/skills/kwaainet-integration/` -- KwaaiNet integration reference
- `.claude/skills/architecture-review/` -- Multi-agent review workflow

### Getting Started

```bash
# Clone the repo
git clone https://github.com/[your-username]/fallow.git
cd fallow

# Install KwaaiNet for local testing
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/Kwaai-AI-Lab/KwaaiNet/releases/latest/download/kwaainet-installer.sh | sh
kwaainet setup
kwaainet benchmark

# Open in Claude Code
claude

# Start with the weekend prototype
/weekend-prototype
```

## Contributing

This project is in early development. Contributions welcome after v0.1 ships.

## Licence

MIT

## Acknowledgements

Built on [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) by Kwaai-AI-Lab (MIT licensed).
