# Contributing

Bug reports, focused pull requests, and translation corrections are welcome. ScreenMate intentionally focuses on remembering ordinary window layouts.

## Development

1. Install Xcode or Command Line Tools with Swift 5.9+ on macOS.
2. Run `bash scripts/test.sh`.
3. Run `bash scripts/build-app.sh` and open `dist/ScreenMate.app`.
4. Install in a stable path before granting Accessibility or enabling launch at login.

Read [AGENTS.md](AGENTS.md) and [the architecture](docs/ARCHITECTURE.md) before changing window matching, coordinate conversion, display identity, or persistence.

## Changes and validation

Keep changes small and include the reason, expected behavior, and actual validation in the pull request. Add meaningful tests for matching or geometry changes. For UI changes, check English, Chinese, a long-text language such as German, and right-to-left Arabic; avoid fixed heights that clip translated text. Run the [manual checklist](docs/TESTING.md) for display or Accessibility behavior.

Document limitations rather than claiming unsupported capabilities. Do not include private window titles, saved layouts, tokens, signing material, or personal machine paths in reports or fixtures.

## Translations

Edit `Sources/Localization/Resources/<language>.lproj/Localizable.strings`. Keep keys and `%d`/`%@` placeholders consistent with English. `LocalizationTests` checks catalog parity, lookup, and placeholder order. Adding a language also requires updating `L10n.languages`, `Packaging/Info.plist`, and the documentation.

## License

Contributions are provided under the project's MIT license. By submitting a contribution, you confirm you have the right to contribute it under those terms. No contributor license agreement is required.
