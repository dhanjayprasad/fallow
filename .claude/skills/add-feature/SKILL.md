---
name: add-feature
description: Guide for adding a new feature to Fallow. Use when implementing a new capability, view, or integration point.
---

# Add Feature Skill

Step-by-step guide for contributing a new feature to Fallow.

## Before You Start

1. Check the scope in CLAUDE.md. Is this feature in v0.1 Must Ship, or is it deferred?
2. If deferred, discuss with maintainers before building.
3. Read `docs/ARCHITECTURE.md` to understand the layer diagram.

## Where to Put Code

### Core logic (no UI dependency)
Place in `Fallow/Fallow/Core/`. Examples: new monitors, API clients, data models.

```
Fallow/Fallow/Core/YourFeature.swift
```

Pattern: `@MainActor @Observable final class` if it holds state observed by UI. Plain `struct` or `enum` for utilities.

### State coordination
If your feature needs to be wired into the app lifecycle, add it to `AppState` in `Fallow/Fallow/ViewModels/AppState.swift`.

### New views
Place in `Fallow/Fallow/Views/`. If the view needs its own window, add a `Window` scene in `FallowApp.swift`.

### New settings
Add to `GovernorSettings` struct in `ResourceGovernor.swift` if it's a governor gate. Add UI in `SettingsView.swift`.

## Coding Conventions

- Swift 6.0 strict concurrency: all observable classes must be `@MainActor`
- NZ English spelling (organisation, behaviour, colour, licence)
- No em dashes or en dashes in any text
- File header: file name, purpose, "Part of Fallow. MIT licence."
- Use OSLog via the extensions in `Logging.swift`
- Prefer Foundation over third-party packages
- Use `async/await`, not completion handlers

## Steps

1. **Create a branch**: `git checkout -b feat/your-feature`
2. **Write the core logic** in `Core/`
3. **Wire into AppState** if needed
4. **Add the UI** in `Views/`
5. **Update the Xcode project**: add new .swift files to the PBXFileReference and PBXSourcesBuildPhase sections in `project.pbxproj`
6. **Build**: `cd Fallow && swift build`
7. **Run the review agents**: `/architecture-review`
8. **Update CHANGELOG.md** with your changes
9. **Commit**: use conventional commits (`feat:`, `fix:`, `refactor:`)
10. **Open a PR** against `main`

## Adding Files to the Xcode Project

When you create a new .swift file, you must also add it to `Fallow/Fallow.xcodeproj/project.pbxproj`:

1. Add a `PBXFileReference` entry with a unique 24-character hex ID
2. Add the file to the appropriate `PBXGroup` (Core, Views, or ViewModels)
3. Add a `PBXBuildFile` entry referencing the file
4. Add the build file to the `PBXSourcesBuildPhase`

Or just open the project in Xcode and add the file through the UI; Xcode updates the pbxproj automatically.

## Review Checklist

Before opening a PR, verify:
- [ ] `swift build` passes with zero errors
- [ ] No em dashes or en dashes in any file
- [ ] NZ English spelling
- [ ] File headers present
- [ ] OSLog used for logging (not print)
- [ ] No third-party dependencies added without discussion
- [ ] CHANGELOG.md updated
