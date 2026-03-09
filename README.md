# i18n Agent for Xcode

A lightweight macOS menu bar app that integrates [i18n Agent](https://i18nagent.ai) with Xcode projects. Pull translations and push translation memory with one click.

## Features

- **Auto-detect** the active Xcode project via AppleScript
- **Pull translations** — select target languages, translate `.strings`/`.xcstrings`/`.stringsdict` files, and write results to the correct `.lproj` directories
- **Push translations** — upload all translated pairs back to your i18n Agent translation memory
- **macOS notifications** on completion
- **Settings panel** showing CLI path, config file location, and API key status

## Requirements

- macOS 14.0+
- Xcode 15+
- [i18n Agent CLI](https://i18nagent.ai) installed (`npm install -g i18nagent`)
- API key configured (`i18nagent login`)

## Build

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project.

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build from command line
xcodebuild -scheme i18nAgent -configuration Release build

# Or open in Xcode
open i18nAgent.xcodeproj
```

## Run

After building, the app appears as a globe icon in the menu bar. Click it to:

1. **Pull** — detects your active Xcode project, scans for localization files and known regions, lets you pick target languages, then translates
2. **Push** — detects your active Xcode project, finds all `.lproj` translation files, uploads them as translation memory pairs

## Configuration

The app reads your i18n Agent config from `~/.config/i18nagent/config.json`. Run `i18nagent login` in terminal to set up your API key.

## Tests

```bash
xcodebuild test -scheme i18nAgent -destination 'platform=macOS'
```

## License

MIT
