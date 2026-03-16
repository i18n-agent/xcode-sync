# i18n Agent for Xcode

A macOS menu bar app that adds one-click localization to Xcode. Translate your `.strings`, `.xcstrings`, and `.stringsdict` files without leaving your workflow.

## Quick Start

Run this in Terminal — it installs everything you need:

```bash
curl -fsSL https://raw.githubusercontent.com/i18n-agent/xcode-sync/main/scripts/setup.sh | bash
```

This will:
1. Install the `i18nagent` CLI (via npm)
2. Prompt you to log in and get an API key
3. Download and install the menu bar app to `/Applications`

Then:
1. Open your Xcode project
2. Click the **globe icon** in the menu bar
3. Click **Pull Translations** — pick your languages and go

That's it.

---

## What It Does

| Action | What happens |
|--------|-------------|
| **Pull** | Detects your active Xcode project, scans for localization files, lets you pick target languages, translates, and writes files to the correct `.lproj` directories |
| **Push** | Finds all `.lproj` translation files in your project and uploads them as translation memory pairs for future use |

The app auto-detects your active Xcode project via AppleScript — no manual configuration needed.

## Manual Install

If you prefer to set things up yourself:

### 1. Install the CLI

```bash
npm install -g i18nagent
i18nagent login
```

### 2. Install the app

**Option A — Download the DMG:**

Download `i18n-Agent.dmg` from the [latest release](https://github.com/i18n-agent/xcode-sync/releases/latest), open it, and drag to Applications.

> If macOS says "can't be opened because it is from an unidentified developer", right-click the app → **Open** → click **Open**.

**Option B — Build from source:**

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/i18n-agent/xcode-sync.git
cd xcode-sync
xcodegen generate
xcodebuild -scheme i18nAgent -configuration Release build
```

Copy to Applications:
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/i18nAgent-*/Build/Products/Release/i18n\ Agent.app /Applications/
```

### 3. Launch

Open **i18n Agent** from Applications or Spotlight. A globe icon appears in your menu bar.

> The first time you click Pull or Push, macOS will ask permission to control Xcode — click **OK**.

## Settings

Open Settings from the menu bar dropdown (or `Cmd+,`) to see:
- **CLI path** — where `i18nagent` is installed
- **API key** — whether you're logged in
- **Config file** — `~/.config/i18nagent/config.json`

## Requirements

- macOS 14.0+
- Node.js (for the CLI)
- [i18n Agent](https://i18nagent.ai) account

## Release (maintainers)

### Manual build

```bash
# Unsigned (local testing)
./scripts/build-release.sh --dmg

# Signed + notarized (for distribution)
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export NOTARIZE_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/build-release.sh --notarize --dmg
```

### Automated release

Push a version tag to trigger the GitHub Actions workflow:

```bash
git tag v1.0.0
git push origin v1.0.0
```

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

## Example

A dummy Xcode project is included in the [`example/`](./example/) directory for testing the Pull Translations workflow. It contains a minimal `.xcodeproj` with localization files you can use to verify the menu bar app end-to-end.

See [`example/README.md`](./example/README.md) for full setup instructions.

## License

MIT License - see [LICENSE](LICENSE) file.

Built by [i18nagent.ai](https://i18nagent.ai)
