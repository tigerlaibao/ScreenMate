# Security and privacy

ScreenMate runs locally and uses Accessibility access to inspect and move other applications' windows. It does not request screen recording, transmit layouts, run a server, or collect telemetry.

Saved JSON contains window titles and application/display identifiers. Treat it as private data when sharing logs or filing issues. The app relies on the macOS user account's filesystem protection; layouts are not separately encrypted.

Do not post credentials, private document titles, or exploit details in a public issue. For a suspected vulnerability, use the repository's **Security → Report a vulnerability** feature if available. Otherwise, open an issue requesting a private reporting channel without including sensitive details.

Only the latest release receives fixes. Release binaries are ad-hoc signed and are not Apple-notarized. Source builds and published checksums are available for inspection and verification.
