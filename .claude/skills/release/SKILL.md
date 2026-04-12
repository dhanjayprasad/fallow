---
name: release
description: Guide for building, signing, and distributing a Fallow release. Use when preparing a new version for distribution.
---

# Release Skill

Build and distribute a new version of Fallow.

## Pre-release Checklist

Before building:
1. All tests pass (`swift build` succeeds with zero errors)
2. CHANGELOG.md is updated with the new version's changes
3. Version numbers are bumped in Info.plist (`CFBundleShortVersionString`) and project build settings (`MARKETING_VERSION`)
4. The KwaaiNet binary is bundled at `Fallow.app/Contents/Helpers/kwaainet` (and `p2pd`)
5. Run `/architecture-review` for a final quality check

## Build Steps

### Local unsigned DMG (for testing)

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
# Output: build/Fallow.dmg
```

### Signed and notarised DMG (for distribution)

Requires:
- Developer ID Application certificate in your Keychain
- App-specific password from appleid.apple.com

```bash
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_ID="your@email.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/build-dmg.sh --sign --notarise
```

### CI release (via GitHub Actions)

Push a version tag to trigger the release workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

This creates a draft GitHub Release. Attach the notarised DMG manually until CI signing secrets are configured.

## Post-release

1. Verify the DMG installs and runs on a clean Mac
2. Test: app appears in menu bar, start/stop works, chat works
3. Publish the draft GitHub Release
4. Update README status section if needed

## Versioning

Fallow uses semantic versioning:
- Bump patch (0.1.x) for bug fixes
- Bump minor (0.x.0) for new features
- Bump major (x.0.0) for breaking changes

Update in two places:
- `Fallow/Fallow/Info.plist` (CFBundleShortVersionString)
- `Fallow/Fallow.xcodeproj/project.pbxproj` (MARKETING_VERSION in both Debug and Release configs)
