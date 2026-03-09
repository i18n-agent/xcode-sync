# i18n Agent for Xcode

A lightweight macOS menu bar app that integrates [i18n Agent](https://i18nagent.ai) with Xcode projects. Pull translations and push translation memory with one click.

## Install

### Download (recommended)

1. Download `i18n-Agent.dmg` from the [latest release](https://github.com/i18n-agent/xcode-sync/releases/latest)
2. Open the DMG and drag **i18n Agent** to Applications
3. Launch from Applications — the globe icon appears in your menu bar

### Build from source

```bash
# Install XcodeGen
brew install xcodegen

# Clone and build
git clone https://github.com/i18n-agent/xcode-sync.git
cd xcode-sync
xcodegen generate
xcodebuild -scheme i18nAgent -configuration Release build

# Or open in Xcode
open i18nAgent.xcodeproj
```

## Features

- **Auto-detect** the active Xcode project via AppleScript
- **Pull translations** — select target languages, translate `.strings`/`.xcstrings`/`.stringsdict` files, and write results to the correct `.lproj` directories
- **Push translations** — upload all translated pairs back to your i18n Agent translation memory
- **macOS notifications** on completion
- **Settings panel** showing CLI path, config file location, and API key status

## Requirements

- macOS 14.0+
- [i18n Agent CLI](https://i18nagent.ai) installed (`npm install -g i18nagent`)
- API key configured (`i18nagent login`)

## Usage

Click the globe icon in the menu bar:

1. **Pull** — detects your active Xcode project, scans for localization files and known regions, lets you pick target languages, then translates
2. **Push** — detects your active Xcode project, finds all `.lproj` translation files, uploads them as translation memory pairs

## Configuration

The app reads your i18n Agent config from `~/.config/i18nagent/config.json`. Run `i18nagent login` in terminal to set up your API key.

## Release (maintainers)

### Manual build

```bash
# Build only (no signing)
./scripts/build-release.sh

# Build + sign
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
./scripts/build-release.sh --sign --dmg

# Build + sign + notarize + create DMG
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export NOTARIZE_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/build-release.sh --notarize --dmg
```

### Automated release (GitHub Actions)

Push a version tag to trigger the release workflow:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This builds, signs, notarizes, creates a `.dmg`, and publishes a GitHub Release.

**Required GitHub secrets:**

| Secret | Description |
|--------|-------------|
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded `.p12` Developer ID certificate |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password for the `.p12` file |
| `DEVELOPER_ID_APPLICATION` | Signing identity, e.g., `Developer ID Application: Name (TEAM_ID)` |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `NOTARIZE_PASSWORD` | App-specific password for notarization |

## Tests

```bash
xcodegen generate
xcodebuild test -scheme i18nAgent -destination 'platform=macOS'
```

## License

MIT
