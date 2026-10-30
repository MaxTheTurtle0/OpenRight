# OpenRight 0.2.1 verification

Release: https://github.com/MaxTheTurtle0/OpenRight/releases/tag/v0.2.1

Source revision: `8b0510a65d03c8e7e0341af2d8164f2ca5ac3777`. Version 0.2.1, build 3. Verified on macOS 27.0.1, Apple Silicon.

## Activation regression

The previous build focused an existing process without sending an open/reopen request. The patch uses `NSWorkspace.openApplication` for both running and closed apps, prefers the running bundle's location, and explicitly reuses the existing process. The target app handles its normal reopen behavior.

A disposable native app recorded launch, close, and reopen callbacks to a local test file. After its only window closed, the installed 0.2.0 build's Running apps > Open action did not produce a reopen callback. The patched development build's same action produced `reopen=1 previouslyVisible=false`, with the same PID. Shortcuts and launcher results use this same activation method.

Zen's blank window was closed while its browser process remained alive. Window metadata confirmed zero normal-sized windows. The installed 0.2.0 build's Open action left that count at zero. The patched build's Open action created one visible window in the same Zen process. Repeated activation kept one window. Minimizing and then activating restored the window. Hiding and then activating restored the window and cleared the hidden state.

After the signed update, a Control + Option + Z shortcut also reopened Zen from zero windows using the existing process. The temporary trigger setting was restored to Right Command. Native automation's `Super_R+z` attempt did not activate the shortcut, so these checks do not claim a fresh hardware Right Command test. Right-side modifier handling is unchanged, and its automated tests passed.

Window diagnostics recorded only process identifiers, counts, visibility, and dimensions, without titles or content. No browser URLs were opened or submitted.

## Build and distribution

- 52 Swift tests passed with compiler warnings treated as errors.
- Three Python release-version tests passed.
- Native and universal builds completed. The release executable contains arm64 and x86_64 slices.
- `git diff --check` passed.
- The app and embedded Sparkle code have valid Developer ID signatures. The stapled Apple notarization ticket validates, and Gatekeeper reports `accepted`, `source=Notarized Developer ID`.
- The designated signing requirement matches 0.2.0.
- The published feed contains build 3, the immutable v0.2.1 ZIP URL, the correct byte length, and a verified Ed25519 signature.
- Public downloads of the DMG and ZIP match the verified local artifacts byte for byte by SHA-256. The downloaded DMG's checksum sidecar passes.
- The installed, notarized 0.2.0 app discovered 0.2.1 through Sparkle, installed it, and relaunched from `~/Applications/OpenRight.app`. The resulting version is 0.2.1/build 3. Its signature, stapled ticket, and Gatekeeper assessment pass.
- Accessibility approval survived the signed update. Settings reports an active shortcut listener.
- The source revision's [main CI run](https://github.com/MaxTheTurtle0/OpenRight/actions/runs/41009954621) passed.

Intel hardware and older macOS versions were not available locally. Window creation remains the target app's decision when it receives the normal macOS reopen request.

Public artifact SHA-256 values:

```text
cb9bfeb2f95279cca755cfab636a6a0ab9a90e157ad85a7bbb52bcfdc4d23c6a  OpenRight.dmg
64aa01ccc186c9ea11ccadb84f321c5e540e2758617887d5bc1e285df807633a  OpenRight-0.2.1-universal.zip
```
