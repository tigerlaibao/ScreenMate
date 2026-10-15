# Building and installing

## Requirements

- macOS 13 or later.
- Xcode or Apple's Command Line Tools with Swift 5.9 or later and a macOS SDK.
- Apple's command-line `sips`, `lipo`, `codesign`, `ditto`, and `shasum` tools, included with macOS/developer tools, plus Python 3 for wrapping rendered PNGs in an ICNS container.
- Git to clone the repository. No third-party packages or paid Apple account are needed.

Check the toolchain with `swift --version` and `xcode-select -p`. Install Apple's command-line tools with `xcode-select --install` if necessary.

## Native development build

```sh
git clone https://github.com/tigerlaibao/ScreenMate.git
cd ScreenMate
bash scripts/test.sh
bash scripts/build-app.sh
open dist/ScreenMate.app
```

The native build targets the host architecture. The output is `dist/ScreenMate.app`. The script processes localization resources, generates all icon sizes from `assets/AppIcon.png`, embeds the `.icns`, applies the version from `VERSION`, ad-hoc signs the app, verifies its signature, and runs the resource smoke check.

Run the packaged `.app` for actual use. Running a bare SwiftPM executable is intended for development and may use a different permission identity or lack packaged assets.

Scripts use a temporary module/package cache location to avoid requiring writes to a developer's global cache. `--disable-sandbox` disables SwiftPM's nested subprocess sandbox during compilation; it does not disable macOS security or Accessibility authorization. ScreenMate has no external package dependencies.

## Universal release build

```sh
bash scripts/package-release.sh
```

This compiles for both `arm64-apple-macosx13.0` and `x86_64-apple-macosx13.0`, combines the executable, and creates:

```text
dist/ScreenMate.app
dist/ScreenMate-0.1.0-macOS-universal.zip
dist/ScreenMate-0.1.0-macOS-universal.zip.sha256
```

File versions follow `VERSION`; the names above are examples for 0.1.0. To build just a universal app, use `bash scripts/build-app.sh --universal`.

## Verify the output

```sh
lipo -archs dist/ScreenMate.app/Contents/MacOS/ScreenMate
codesign --verify --deep --strict dist/ScreenMate.app
plutil -lint dist/ScreenMate.app/Contents/Info.plist
dist/ScreenMate.app/Contents/MacOS/ScreenMate --check-resources
cd dist
shasum -a 256 -c ScreenMate-0.1.0-macOS-universal.zip.sha256
```

A universal executable reports `arm64 x86_64` (the order may differ). A checksum verifies the downloaded bytes match the accompanying checksum file; it is not a Developer ID signature or notarization.

## Install and authorize

1. Unzip the archive if using a release download.
2. Quit an existing ScreenMate process using its menu bar menu.
3. Drag `ScreenMate.app` into `/Applications`, or your own `~/Applications` folder.
4. Launch from that stable location.
5. Enable ScreenMate under **System Settings → Privacy & Security → Accessibility** when prompted by the onboarding button. Screen recording permission is not required.
6. Save each display setup once, including the MacBook-only setup if you want to restore it after unplugging external displays.

These builds are ad-hoc signed, not Apple-notarized. For a release you trust, macOS may offer **Open Anyway** under Privacy & Security after blocking the first launch. Do not disable Gatekeeper globally.

Choose **Language → 简体中文** or **繁體中文** to switch the interface. Choose **Launch at Login** to enable startup; macOS may request approval in Login Items settings.

## Upgrade

Quit the app, replace it in the same installation location, and reopen it. Layout data is stored outside the application bundle, so replacing the bundle does not remove layouts. Changes to an ad-hoc signed binary can require removing and re-adding ScreenMate in Accessibility settings. If login registration is stale, toggle Launch at Login off and on after installing the new version.

## Data backup and recovery

Use **Open Layout Folder** to find `~/.screenmate/layouts.json`. Copy that file somewhere private for a backup. Older Application Support layouts migrate automatically when the hidden configuration is absent; the original file is retained as a backup. It can contain private document titles.

If the app reports an unreadable layout file, quit, move the existing file aside, and restart. The app intentionally does not overwrite a file it could not decode.

## Uninstall

Turn off **Launch at Login**, quit ScreenMate, and move the app to Trash. Optionally remove its Accessibility entry and the `~/.screenmate` directory. Preferences are stored under `local.screenmate.app`; removing the app alone preserves these preferences and layouts.
