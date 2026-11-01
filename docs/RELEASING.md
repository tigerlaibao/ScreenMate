# Release process

## Prepare

1. Update `VERSION`, `CHANGELOG.md`, and user-facing examples/download names when changing versions.
2. Add `docs/releases/v<version>.md` with features, install steps, supported architectures/macOS version, and limitations.
3. Run `bash scripts/test.sh` and `bash scripts/package-release.sh`.
4. Follow `docs/TESTING.md` for checks you can actually perform. Record any remaining hardware validation limits.
5. Verify `lipo -archs`, the signature, packaged resource smoke check, ZIP contents, and SHA-256 checksum. Inspect the exact files being published for private data.

## Publication

For a local source directory without a `.git` checkout, use:

```sh
bash scripts/publish-release.sh
```

Run it in your own authenticated terminal. It tests and packages the app, clones the public repository into a temporary directory, commits the explicit project source/documentation paths, pushes main, and publishes the ZIP and checksum against that exact commit. It refuses to replace an existing release. Credentials stay with your normal GitHub CLI setup; the script does not export or store a token file.

An authenticated maintainer can instead publish locally built artifacts:

```sh
bash scripts/package-release.sh
gh release create v0.2.2 \
  dist/ScreenMate-0.2.2-macOS-universal.zip \
  dist/ScreenMate-0.2.2-macOS-universal.zip.sha256 \
  --verify-tag \
  --title "ScreenMate 0.2.2" \
  --notes-file docs/releases/v0.2.2.md
```

Use one publishing path for a given release, not both concurrently. A public repository must already exist and the tag must be pushed before using `--verify-tag`.

## Signing policy

The current scripts use `codesign --sign -` for ad-hoc signing. This verifies bundle integrity locally but does not identify a registered Apple developer or provide notarization. Clearly disclose this in README and release notes.

A future notarized release requires a Developer ID Application certificate and Apple notarization credentials. Keep those in a secure release environment or local keychain, never in the repository. Document any future signing change and its impact on Accessibility approvals.
