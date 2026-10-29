<img src="assets/icon.svg" width="64" height="64" alt="">

# OpenRight

OpenRight is a small, MIT-licensed macOS app switcher. Hold Right Command and press an app's first letter to focus it. The ordinary Left Command shortcuts keep working.

This is an independent implementation inspired by [rcmd](https://lowtechguys.com/rcmd/). It does not contain rcmd code, assets, or configuration.

## Try it locally

Requires macOS 13 or later. Building requires Xcode or the Xcode Command Line Tools with Swift 5.9 or later. The build uses the current Mac's architecture and has no third-party dependencies.

```sh
./scripts/build.sh
./scripts/install.sh
open ~/Applications/OpenRight.app
```

OpenRight lives in the menu bar. Open Settings there, then grant it Accessibility access in System Settings when you are ready to enable global shortcuts. macOS may also ask for Input Monitoring. Grant those permissions to the installed app, not to a temporary build path. After changing a permission, quit and reopen OpenRight if the listener does not start.

If rcmd is running, OpenRight suspends its Right Command shortcuts to avoid both apps acting on one keypress. Quit rcmd to try the default trigger, or select another trigger in OpenRight's settings.

The local app is ad-hoc signed. It is not notarized or signed with a Developer ID. Rebuilding or moving it can require granting Accessibility access again. Install it in a stable location before enabling launch at login.

If Settings still reports missing access while macOS shows its switch as enabled, remove the old OpenRight entry and add the installed copy again. macOS may require Touch ID or your password. Quit and reopen OpenRight afterwards.

For development, `./scripts/run.sh` builds when necessary and opens `dist/OpenRight.app`.

The installer preserves an existing app with an `.app.backup` suffix. Rename that backup to `.app` to restore it. This keeps old copies out of app pickers and Spotlight.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Right Command + letter | Focus a running app whose name starts with that letter |
| Same shortcut again | Cycle through matching apps, or hide the focused app, according to settings |
| Right Command + Option + letter or digit | Pin that key to the focused app |
| Right Command + pinned key | Focus the pinned app, or launch it if it is closed |
| Right Command + Space | Search installed apps |
| Hold Right Command for 1 second | Show app and key hints |
| Escape in search | Close the launcher |

Search also opens from the menu bar. Type part of an app's name, use the arrow keys to select a result, and press Return to focus or launch it.

Settings let you choose Right Command, Right Option, or Control + Option as the trigger. With Right Option or Control + Option, add Command to pin the focused app. You can also add and remove pins in Settings, choose each pin's repeat behavior, disable selected keys, hide hints, pause shortcuts, and enable launch at login.

OpenRight uses translated key characters, so letter assignments follow the current keyboard layout. Unmapped shortcuts pass through to the focused app. Secure Input can prevent a global keyboard listener from receiving events.

## Scope and privacy

OpenRight 0.1 focuses on app switching, pinned launch shortcuts, and app search. It does not implement rcmd's newer window switcher, window search, Spaces controls, Lenses, or saved workspaces. It uses public macOS APIs. Switching between Spaces follows macOS behavior and Mission Control settings.

The app makes no network requests, records no typed keys, and does not read window contents. Preferences stay in:

```text
~/Library/Application Support/OpenRight/preferences.json
```

The core shortcut resolver and fuzzy search are separate from AppKit, so their behavior can be tested without global keyboard permissions.

## Build and verify

```sh
swift test
./scripts/build.sh
./scripts/package.sh
```

`package.sh` creates a versioned ZIP and SHA-256 checksum in `dist`. The ZIP contains a build for the current architecture. CI runs the tests and builds the app on macOS. See [the manual verification checklist](docs/verification.md) for checks that require macOS permissions and a real keyboard.

Source layout:

- `Sources/OpenRightCore` contains deterministic shortcut resolution, preferences, and search.
- `Sources/OpenRight` contains the menu bar app, keyboard listener, and SwiftUI views.
- `Tests/OpenRightCoreTests` contains the core tests.
- `Tests/OpenRightTests` checks native event handling, preference persistence, and view rendering.
- `scripts` builds, installs, and packages the app.

To uninstall, disable launch at login in OpenRight, quit it, and move `~/Applications/OpenRight.app` to the Trash. Remove its Accessibility entry in System Settings if you no longer need it. Deleting the preferences file resets saved settings and pins.

## License

[MIT](LICENSE). Created in [T3 Code](https://t3.codes).
