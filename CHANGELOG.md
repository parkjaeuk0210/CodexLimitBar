# Changelog

## Unreleased

- Added scripts and documentation for Developer ID signed, notarized releases.
- Added a GitHub Actions workflow for notarized release uploads.
- Added helper scripts for CSR generation, p12 export, and release secrets setup.
- Added a release secrets readiness check.

## 0.1.1

- Added Homebrew Cask distribution metadata.
- Improved the public README with a clearer install flow and preview image.
- Updated the bundle identifier for public distribution.

## 0.1.0

- Initial public build.
- Shows Codex usage remaining in the macOS menu bar.
- Supports switching the displayed limit between the 5-hour and weekly windows.
- Uses the installed Codex or ChatGPT app icon when available.
- Uses a short-lived local Codex app-server process only while refreshing.
