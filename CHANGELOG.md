# Changelog

## 0.2.1 — 2026-10-15

- Reduce the display-change result toast hold time to one second.
- Verify actual window geometry across two observations instead of treating accepted Accessibility writes as restoration success.
- Retry ignored or reverted window moves up to three times and resolve stale Accessibility window handles again.
- Cancel pending retries when the display configuration changes or the user starts a new layout action.
- Add regression coverage for asynchronous, reverted, ignored, missing, and canceled window restoration.

## 0.2.0 — 2026-10-15

- Optional menu bar icon with an immediate switch to Dock mode when hidden.
- Settings and all controls remain accessible through the Dock without restarting.
- Large terminal-style display-change toast with progress, restore results, automatic fade-out, and an independent visibility preference.
- Localized visibility and transition messages in all 15 supported languages.
- Scrollable settings content for smaller screens and longer translations.

## 0.1.0 — 2026-10-15

First public release.

- Native macOS menu bar app for per-display-setup window layouts.
- Manual save/restore and automatic restore after display changes and wake.
- Conservative window matching and visible-area clamping.
- Local JSON storage in `~/.screenmate`, with atomic writes, legacy migration, and corrupt-file protection.
- Optional launch at login and automatic saved-layout updates.
- 15 interface languages with immediate switching and right-aligned Arabic onboarding.
- Original app icon, MIT license, engineering documentation, tests, and CI.
- Universal macOS release packaging for Apple Silicon and Intel.

Known limits: no Spaces/full-screen management or automatic app launching; Accessibility compatibility and real hot-plug behavior vary with apps, displays, and docks. Release binaries are not Apple-notarized.
