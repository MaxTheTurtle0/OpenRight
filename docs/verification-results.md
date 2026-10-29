# Local verification, 2026-10-29

OpenRight 0.1.0, arm64, tested on macOS 27.0.1 with Swift 6.4 in Swift 5 language mode. The deployment target is macOS 13; earlier systems and Intel Macs have not been exercised locally.

Completed:

- `swift test -Xswiftc -warnings-as-errors`: 48 tests passed, no failures or compiler warnings.
- Release app build and ad-hoc signature verification passed.
- Settings and launcher rendered through native AppKit/SwiftUI. The resulting images were inspected for layout.
- Installed app opened successfully, displayed the permission setup and rcmd conflict, and opened its search field with typed input.
- Fresh install and replacement install were exercised in a temporary directory. One current `.app` and one `.app.backup` remained, with the expected executable bytes.
- Independent source review found and prompted fixes for consumed key repeats and disabled-key pinning. It rated the corrected implementation 8/10 for a local trial, with live global keyboard checks outstanding.
- App discovery found 106 installed apps on the test machine. The command-line diagnostic inherits its launching process's permissions; it does not establish that a LaunchServices-launched app has Accessibility permission.

The installed app and ZIP contain the same release executable. The ZIP has a SHA-256 sidecar file. The local build is not notarized.

Accessibility was re-enabled in System Settings for the final installed build after macOS authentication. The computer-control tool subsequently returned `cgWindowNotFound` when attaching to the menu-bar app, so global keyboard switching and pinned launch still require live acceptance. Startup at login, sleep recovery, and Spaces behavior also remain unchecked. See [the manual checklist](verification.md). Do not treat the automated event tests as proof that macOS has granted a running app permission.
