# CodexLimitBar

CodexLimitBar is a tiny macOS menu bar app for keeping an eye on your Codex
usage window without opening a browser.

It shows a compact Codex-style icon plus the remaining percent for the selected
limit window. You can switch the displayed limit between the 5-hour window and
the weekly window from the menu.

## Requirements

- macOS 13 or newer
- Codex CLI installed and available as `codex`
- A logged-in Codex CLI session (`codex login`)

The app can read usage with only the Codex CLI installed. If the Codex or
ChatGPT desktop app is installed, CodexLimitBar uses that local app icon in the
menu bar. Otherwise it falls back to a generic system icon.

## Install

Download `CodexLimitBar-0.1.0-unsigned.zip` from GitHub Releases, unzip it, and
move `CodexLimitBar.app` to `/Applications`.

This first build is unsigned and not notarized. macOS may block the first
launch. If that happens, Control-click the app, choose **Open**, then confirm.

## Build From Source

```sh
./scripts/build.sh
open .build/CodexLimitBar.app
```

## Package

```sh
./scripts/package.sh
```

The package script creates:

```text
dist/CodexLimitBar-<version>-unsigned.zip
dist/CodexLimitBar-<version>-unsigned.zip.sha256
```

## Check

```sh
./scripts/check.sh
```

## Runtime Flow

```text
Menu timer or Refresh Now
-> CodexRateLimitClient
-> short-lived `codex app-server --listen ws://127.0.0.1:<port>`
-> /readyz
-> WebSocket JSON-RPC initialize
-> account/rateLimits/read
-> cache JSON
-> NSStatusItem menu title
```

## Behavior

- Reads usage with `codex app-server` and `account/rateLimits/read`.
- Does not read `~/.codex/auth.json` directly.
- Caches the most recent snapshot in `~/Library/Application Support/CodexLimitBar`.
- Refreshes every 15 minutes on power adapter, 10 minutes on battery, and 30
  minutes in Low Power Mode.
- Starts a short-lived local Codex app-server only while refreshing.

## Source Layout

```text
Sources/CodexLimitBar/Models.swift                 Codable response models
Sources/CodexLimitBar/CodexRateLimitClient.swift   local Codex app-server RPC
Sources/CodexLimitBar/PowerState.swift             battery-aware refresh cadence
Sources/CodexLimitBar/MenuBarPreferences.swift     saved display settings
Sources/CodexLimitBar/MenuBarTitleFormatter.swift  menu bar label formatting
Sources/CodexLimitBar/AppDelegate.swift            macOS menu and app lifecycle
Sources/CodexLimitBar/main.swift                   app entrypoint
```

## Notes

The Codex app-server protocol is local and not a formally documented public
API. If it changes, the app will show an error in the menu instead of reading
private credential files directly.

CodexLimitBar is not affiliated with OpenAI. Codex and ChatGPT are trademarks
of OpenAI. The app uses installed local app icons when available and does not
bundle OpenAI logo assets.
