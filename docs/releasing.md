# Releasing OpenRight

The friend-facing download is `https://github.com/MaxTheTurtle0/OpenRight/releases/latest/download/OpenRight.dmg`. It becomes available when the first release is published. Each release supports Apple Silicon and Intel Macs on macOS 13 or newer.

A public release needs two independent signatures. A Developer ID Application certificate signs the app and Sparkle helpers for macOS. A Sparkle Ed25519 key signs update archives. Apple notarization and stapled tickets let Gatekeeper validate the download. An Apple Development or iPhone Distribution certificate does not substitute for Developer ID Application.

## One-time setup

1. Sign in to your Apple Developer account in Xcode. For cloud-managed signing, use a team with cloud-managed Developer ID permission and a local Apple Development identity. Xcode creates the distribution signature without exporting its private key. Alternatively, install a local Developer ID Application certificate and private key. Do not put private keys into this repository.
2. For the local-certificate route only, store notarization credentials in Keychain with `xcrun notarytool store-credentials OpenRight`, following Apple's secure prompts. Set `OPENRIGHT_NOTARY_PROFILE=OpenRight` when releasing. App Store Connect API credentials are also supported through `OPENRIGHT_NOTARY_KEY_PATH`, `OPENRIGHT_NOTARY_KEY_ID`, and optional `OPENRIGHT_NOTARY_ISSUER`. The key file belongs outside the repository.
3. Run `swift package resolve` to fetch the pinned Sparkle package and tools.
4. Generate the update key once with `./scripts/sparkle-tools.sh generate_keys --account org.openright.sparkle`. The private key stays in login Keychain. Copy only the printed public key into `SUPublicEDKey` in `Resources/Info.plist`. Back up the private key securely outside the repository. Do not generate a replacement key for every release.
5. Ensure `SUFeedURL` is `https://github.com/MaxTheTurtle0/OpenRight/releases/latest/download/appcast.xml`, and `SUVerifyUpdateBeforeExtraction` is true.
6. Authenticate GitHub CLI and push the public repository. The release script verifies that the exact committed source exists on GitHub before uploading artifacts.

If the update key is stored under another Keychain account, set `OPENRIGHT_SPARKLE_ACCOUNT`. `OPENRIGHT_SPARKLE_TOOLS_DIR` can override the resolved tool directory. The scripts never need the private update key to be printed or passed on a command line.

## Prepare a release

Increase both `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`. The build version must increase for Sparkle to offer the new version. Commit the change and push that exact commit.

The cloud route uses the signed-in Xcode account for both Developer ID signing and notarization:

```sh
./scripts/release.sh --cloud --notes /path/to/release-notes.md
```

If there is more than one Apple Development identity, set `OPENRIGHT_DEVELOPMENT_IDENTITY` to its exact certificate SHA-1. `OPENRIGHT_TEAM_ID` can enforce the intended team; otherwise it is derived from that identity.

For a local Developer ID identity and notarytool credentials:

```sh
export OPENRIGHT_NOTARY_PROFILE=OpenRight
export OPENRIGHT_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./scripts/release.sh --notes /path/to/release-notes.md
```

The identity can also be a certificate SHA-1. If exactly one valid Developer ID Application identity exists, the script can select it without `OPENRIGHT_SIGN_IDENTITY`.

The script runs tests, builds arm64 and x86_64 executables, merges them, embeds Sparkle while preserving framework symlinks, and signs nested helper code before the framework and app. It enables Hardened Runtime and timestamps distribution signatures. It checks that no local build paths remain in dynamic-library references.

Both routes validate Developer ID signatures, universal architecture slices, the app's stapled notarization ticket, and Gatekeeper acceptance before packaging. They create a ZIP and DMG with an Applications shortcut, plus SHA-256 sidecars. The cloud route distributes the notarized app inside an unsigned DMG container. The local-certificate route also signs, notarizes, and staples the outer DMG. The resulting files are in `dist`:

- `OpenRight-VERSION-universal.zip` is the Sparkle update archive.
- `OpenRight-VERSION-universal.dmg` and `OpenRight.dmg` are the same friend-facing installer image.
- `appcast.xml` contains the signed update's exact version, URL, byte length, and Ed25519 signature.
- `notarization` stores Apple's submission results, without authentication secrets.

The script compares the new numeric build with the latest published appcast and rejects unchanged or older builds. Cloud archives record the source revision and build-input fingerprint. Resuming an archive from another revision is rejected, and source is rechecked immediately before GitHub writes.

The appcast is generated using Sparkle's own tool. The release script verifies the generated signature against the actual ZIP before uploading. It also verifies that the embedded public key matches the selected Keychain account.

By default, the result is a **draft GitHub release**. Review the release before making it public. Existing published versions are not overwritten; increment the version for a new release.

## Publish

Once the prepared release has passed review:

```sh
gh release edit vVERSION --repo MaxTheTurtle0/OpenRight --draft=false --latest
```

For a release that should publish immediately after all signing, notarization, and feed checks pass, add `--publish` to the chosen release command, for example `./scripts/release.sh --cloud --publish --notes /path/to/release-notes.md`.

Share the stable DMG link above. Existing installations fetch the stable latest-release appcast, whose enclosure points to the immutable version-specific ZIP. Do not alter or replace a published ZIP after generating its appcast. Keep the corresponding Git tag and source commit.

The old locally installed 0.1 builds have no updater. Install the updater-enabled release manually once; subsequent versions can be installed from **Check for Updates** or Sparkle's automatic checks.

## Local development

```sh
./scripts/build.sh
./scripts/package.sh --universal
```

Local builds use an ad-hoc signature unless `OPENRIGHT_SIGN_IDENTITY` is explicitly supplied. They do not use the release Hardened Runtime/notarization path. CI packages development artifacts only and labels them as not notarized. They are not the public friend download.

A development artifact is allowed to have no notarization credentials. Public distribution is not: `--release` rejects missing Developer ID signing, an invalid HTTPS feed, an invalid public key, missing universal slices, failed notarization, or signature verification failure.

## Notarization delays and failures

For cloud signing, preserve the generated archive in `dist/archives`. Keep the same source commit and resume retrieval without submitting another copy:

```sh
./scripts/release.sh --cloud --resume --notes /path/to/release-notes.md
```

`OPENRIGHT_XCODE_ARCHIVE` selects an archive at a different path. Do not modify source while its notarization is pending. The archive can only resume at the recorded clean revision.


`notarytool` waits up to 30 minutes by default, configurable with `OPENRIGHT_NOTARY_TIMEOUT`. If it times out, Apple may still be processing the existing submission. Read the submission ID from `dist/notarization/NAME.json` and resume it rather than submitting another copy:

```sh
./scripts/notarize.sh --resume SUBMISSION_ID dist/OpenRight.app
```

For a rejection, retrieve the notary log with the same Keychain profile, correct the signing problem, and create a fresh build. Never remove quarantine attributes or tell recipients to disable Gatekeeper to make a release pass.

## Acceptance before sharing

- Verify `codesign --verify --deep --strict dist/OpenRight.app` and `xcrun stapler validate dist/OpenRight.app`.
- Verify the ZIP/DMG checksum sidecars. For the local-certificate route also run `xcrun stapler validate dist/OpenRight.dmg`. For the cloud route, verify the notarized app inside the DMG; the outer image is unsigned.
- Download the published DMG in a browser on another Mac. Drag the app to Applications and launch it normally, without bypassing Gatekeeper.
- Grant Accessibility to the installed copy and exercise app switching and pinned launching.
- Run a genuine older updater-enabled release and check for the newer version. Confirm the signed update installs, relaunches, and retains pins. A failed signature must stop the update.
- Check both Apple Silicon and Intel hardware when available. A universal binary check does not replace hardware acceptance.

The pipeline follows the [Sparkle setup](https://sparkle-project.org/documentation/), [Sparkle code-signing guidance](https://sparkle-project.org/documentation/sandboxing/), and [Apple notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
