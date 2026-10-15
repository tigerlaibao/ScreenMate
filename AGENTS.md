# Agent instructions

## Project scope

ScreenMate is a small native macOS menu bar utility for saving and restoring ordinary window geometry per display setup. Keep the app offline, dependency-free, and understandable. Do not add app launching, private Spaces APIs, telemetry, or cloud sync without an explicit request.

## Language and licensing

- Write documentation, code identifiers, comments, commit messages, and release notes in English.
- Keep all user-facing UI strings in the Localization resource catalogs. English is the default; maintain key and format-placeholder parity across all 15 supported language catalogs.
- Preserve the MIT license. Do not add dependencies or assets with incompatible terms.

## Structure

- `Sources/LayoutCore`: Codable snapshots, display geometry, conservative window matching, and local persistence/migration; no UI or Accessibility calls.
- `Sources/Localization`: localization lookup, language selection, and `.lproj` catalogs.
- `Sources/ScreenMate`: AppKit lifecycle, menus, and public macOS Accessibility APIs.
- `Tests`: unit tests for geometry, matching, persistence round trips, and translations.
- `Packaging`, `assets`, `scripts`: app metadata, original branding, and repeatable build/release scripts.
- `docs`: architecture, source installation, releases, and manual verification.

## Implementation rules

- Use display UUIDs plus logical resolution for setup identity. Never identify a monitor solely by its name.
- Preserve the existing bundle identifier `local.screenmate.app`, hidden data directory `~/.screenmate`, and layout JSON format unless a migration is explicitly implemented and documented.
- Do not replace unreadable layout data, save empty captures over valid layouts, or turn automatic updates on by default.
- Do not restore minimized/full-screen windows, switch Spaces, raise apps, or launch missing apps.
- Keep display-change debounce, pending-restore cancellation, and auto-save cooldown intact.
- Match windows conservatively. Do not let a fallback match consume an exact match or match a live window twice.
- Clamp restored windows to the target display's visible bounds. Remember that Accessibility uses top-left global coordinates and AppKit uses bottom-left coordinates.
- Retain messaging timeouts for unresponsive Accessibility clients.
- Treat app titles and saved layouts as private local data. Never commit real user layouts, credentials, signing identities, or machine-specific paths.

## Validation

Run `bash scripts/test.sh` for logic and localization changes. Run `bash scripts/build-app.sh` for UI, metadata, localization-resource, icon, or packaging changes. The script verifies signing and executes a bundled-resource smoke check. Run `bash scripts/package-release.sh` before releases and check the universal architecture and checksum.

For behavior requiring Accessibility permissions or real displays, follow `docs/TESTING.md`. Do not claim hardware tests passed unless you performed them. Keep generated `.build/`, `dist/`, and developer-local settings out of Git.

## Releases

`VERSION` is the release version source. Keep it consistent with changelog headings, release tags, and release-note files. Publish the ZIP and checksum, never a source-only release advertised as an installer. Explicitly state that ad-hoc signatures are not Developer ID signatures or Apple notarization.
