# Notarized Release Flow

This is the release path for a public macOS build that feels normal to install:
Developer ID signed, notarized by Apple, and stapled for offline Gatekeeper
checks.

The current public build is still unsigned because this Mac only has an
`Apple Development` signing identity. A `Developer ID Application` certificate
and notary credentials are required before the final package can be produced.

## Requirements

- Apple Developer Program membership.
- A `Developer ID Application` certificate installed in Keychain Access.
- Notary credentials saved through `xcrun notarytool`.
- Xcode command line tools with `codesign`, `notarytool`, and `stapler`.

Check the local signing identities:

```sh
security find-identity -v -p codesigning
```

You should see an identity similar to:

```text
Developer ID Application: Your Name (TEAMID)
```

## Save Notary Credentials

Apple ID app-specific password mode:

```sh
APPLE_ID=you@example.com APPLE_TEAM_ID=TEAMID ./scripts/configure-notary.sh
```

The script prompts securely for the app-specific password if
`APPLE_APP_PASSWORD` is not set.

App Store Connect API key mode:

```sh
ASC_KEY_PATH=/path/AuthKey_ABC123.p8 \
ASC_KEY_ID=ABC123 \
ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000 \
./scripts/configure-notary.sh
```

Both modes save credentials into the keychain profile
`codexlimitbar-notary` by default. Override it with:

```sh
CODEX_LIMIT_BAR_NOTARY_PROFILE=my-profile ./scripts/configure-notary.sh
```

## Build A Notarized Package

```sh
./scripts/package-notarized.sh
```

The script:

- verifies that a `Developer ID Application` identity is available;
- builds the app;
- signs it with hardened runtime and timestamping;
- uploads a zip to Apple notarization;
- staples and validates the ticket;
- runs a Gatekeeper assessment;
- writes `dist/CodexLimitBar-<version>-notarized.zip`.

Useful overrides:

```sh
CODEX_LIMIT_BAR_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
CODEX_LIMIT_BAR_NOTARY_PROFILE=codexlimitbar-notary \
CODEX_LIMIT_BAR_NOTARY_TIMEOUT=45m \
./scripts/package-notarized.sh
```

## Publish

Upload the notarized zip and SHA file to the matching GitHub release, then
update the Homebrew tap cask URL and `sha256` to point at the notarized asset.

```sh
gh release upload vX.Y.Z dist/CodexLimitBar-X.Y.Z-notarized.zip \
  dist/CodexLimitBar-X.Y.Z-notarized.zip.sha256
```

After the tap is updated, verify the install path:

```sh
brew fetch --cask codexlimitbar --force
brew install --cask --dry-run codexlimitbar
```

## GitHub Actions Release

The repository includes `.github/workflows/release.yml`. Once the required
secrets are configured, pushing a `v*` tag or running the workflow manually
builds, signs, notarizes, staples, and uploads the notarized zip to the matching
GitHub release.

Required repository secrets:

```text
DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
KEYCHAIN_PASSWORD
ASC_API_KEY_BASE64
ASC_KEY_ID
ASC_ISSUER_ID
```

Create the certificate secret from an exported `.p12` file:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Create the App Store Connect API key secret from the `.p8` file:

```sh
base64 -i AuthKey_ABC123.p8 | pbcopy
```

After the workflow uploads `CodexLimitBar-<version>-notarized.zip`, update the
Homebrew tap to use that asset and checksum instead of the unsigned zip.
