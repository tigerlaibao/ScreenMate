# Testing

## Automated checks

Run `bash scripts/test.sh` on macOS. Tests cover display-setup identity, geometry, conservative window matching, JSON round trips, and translation consistency. `bash scripts/build-app.sh` additionally checks bundled resources and the ad-hoc signature. `bash scripts/package-release.sh` builds both supported CPU architectures.

CI runs the tests and builds an app on macOS. Tagged releases run the same tests and universal packaging before publishing assets. These checks do not imply successful real-display or Accessibility testing.

## Manual acceptance checklist

Use sample windows without private titles when capturing screenshots or reporting results.

| Scenario | Expected result |
| --- | --- |
| First launch without Accessibility access | Welcome window and authorization entry are visible; save/restore are disabled |
| English, Chinese, German, and Arabic | Menu and welcome text update immediately, remain readable, and persist after restart; Arabic onboarding is right-aligned |
| Two apps and two differently titled windows of one app | Saved position and size restore after deliberately rearranging them |
| Close an app after saving | Other windows restore; the app is not reopened; no failure dialog appears |
| Open an unrelated app after saving | Its windows are left alone |
| Replace a window in the same app | Unique identity/title is preferred; one-to-one fallback can move the replacement window |
| Several ambiguous windows with changed titles | They are skipped rather than arbitrarily assigned |
| Save laptop-only, then connect an external monitor | The external setup can be saved independently |
| Unplug external displays | Previously saved laptop-only layout restores after about three seconds |
| One external monitor versus two | Each combination selects its own saved layout |
| Same-model monitors with distinct system UUIDs | Each combination retains its own layout |
| Rearrange a screen to the left or above | Windows follow that display and remain in visible bounds |
| Change scaling/resolution | A new setup is selected and needs a saved layout |
| Repeated fast connect/disconnect | Pending automatic restore is canceled and only the latest setup is restored |
| Hide menu bar icon | Icon and its slot disappear immediately; Dock icon remains; background restoration continues |
| Click Dock icon after closing Settings | Settings reopens without restarting, and Open Controls exposes all actions |
| Show menu bar icon again | Menu bar icon returns immediately and Dock mode ends |
| Restart with icon hidden | Dock mode persists and layout restoration still runs |
| Display-change toast | Large terminal-style progress appears without focus changes or blocked clicks; result fades automatically after about one second |
| Disable display-change toast | Subsequent display changes restore layouts without an overlay |
| Rapid repeated display changes | The newest overlay replaces the previous one; old dismissal cannot remove the new overlay |
| Small screen or long translations | Settings can scroll and controls remain reachable |
| Disable automatic restoration | Later display changes do not move windows through ScreenMate |
| Sleep and wake | The saved current setup is restored after wake settles |
| Minimized and native full-screen windows | They are skipped |
| Enable auto-save | Only already saved setups update; no update occurs within the 12-second transition cooldown |
| Corrupt a backed-up test layout file | App reports read failure and refuses to overwrite it |
| Launch at login | macOS login item is enabled after any required system approval |
| Downloaded ZIP on a second Mac | App unzips, has its icon/localizations, and runs after any required macOS approval |

Record macOS version, CPU architecture, display/dock models, app names/versions, and the cases actually tested. Do not mark unperformed cases as passing.

## ToDesk compatibility regression

Save the regular ToDesk session window on both laptop-only and external-display setups. Move it, restore, and verify both its final position and size. Repeat while connecting/disconnecting displays. The count should only include windows whose geometry is confirmed; rejected or constrained sizes may still be skipped. Verify that a second display change or a manual save cancels pending retries. Do not close or disconnect a remote session as part of testing.
