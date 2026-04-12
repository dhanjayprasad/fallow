# Contributing to Fallow

Thank you for your interest in contributing to Fallow. This document explains how to get involved.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/fallow.git`
3. Create a branch: `git checkout -b feat/your-feature`
4. Make your changes
5. Push and open a Pull Request against `main`

## Development Setup

### Prerequisites

- macOS 14.2+
- Xcode 16+
- [KwaaiNet CLI](https://github.com/Kwaai-AI-Lab/KwaaiNet/releases/latest) (for integration testing)

### Building

```bash
cd Fallow
xcodebuild build -scheme Fallow -destination 'platform=macOS'
```

Or open `Fallow/Fallow.xcodeproj` in Xcode and press Cmd+B.

### Testing

```bash
xcodebuild test -scheme Fallow -destination 'platform=macOS'
```

### Running

Open `Fallow/Fallow.xcodeproj` in Xcode, select the Fallow scheme, and press Cmd+R. The app appears in the menu bar (no Dock icon).

## Code Style

- Swift 6.0+, targeting macOS 14.2+
- Use the Observation framework (`@Observable`), not Combine, for new code
- Use `async/await` and structured concurrency, not completion handlers
- NZ English spelling throughout (organisation, behaviour, colour, licence)
- No em dashes or en dashes anywhere (code, comments, documentation). Use commas, semicolons, colons, or rewrite.
- Every file must have a header comment with: file name, brief purpose, and "Part of Fallow. MIT licence."
- Prefer Foundation and system frameworks over third-party packages

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation changes
- `chore:` build, CI, tooling changes
- `refactor:` code restructuring without behaviour change
- `test:` adding or updating tests

## Pull Requests

- Keep PRs focused on a single change
- Write a clear description of what and why
- Reference related issues with `Fixes #123` or `Relates to #123`
- Ensure the build passes before requesting review

## Reporting Issues

Use the issue templates provided. Include your macOS version, Mac model, and Fallow version.

## Licence

By contributing, you agree that your contributions will be licensed under the MIT Licence.
