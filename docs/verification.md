# Manual verification

Automated core tests cannot verify real keyboard events, Accessibility permission, app activation, or macOS Spaces behavior. Use this checklist with the packaged app. Check a box only after observing the result.

## Setup

- [ ] Build with `swift test` and `./scripts/build.sh`.
- [ ] Install the app with `./scripts/install.sh`, then open the installed copy.
- [ ] With Accessibility denied, Settings explains the missing permission and ordinary typing works.
- [ ] Grant Accessibility to the installed app. Confirm Settings reports an active listener after reopening if needed.
- [ ] When rcmd is running, Right Command interception is suspended and the conflict is explained.
- [ ] Quit rcmd. Confirm the default trigger becomes available.

## Shortcut behavior

- [ ] Hold Right Command for several seconds. No popup appears.
- [ ] Press Right Command + a running app's initial. The app gains focus.
- [ ] Close a running app's last window without quitting, then press its shortcut. The app handles the normal macOS reopen request and opens a window if supported, as Zen does.
- [ ] Minimize a running app's window, then press its shortcut. The window returns. Repeated activation of an app with an open window does not create extra windows.
- [ ] Try three running apps with the same initial. Repeated presses while holding the trigger reach all three.
- [ ] Choose Hide as the repeat behavior. A second press hides the focused app; another press brings it back.
- [ ] Use Right Command + Option + a letter to pin the focused app. Confirm the pin appears in Settings and survives restart.
- [ ] Quit a pinned app, then press its shortcut. It launches.
- [ ] Set a different repeat behavior on one pin. It overrides the global repeat setting.
- [ ] Remove a pin. The key returns to dynamic matching.
- [ ] Disable a key. Its shortcut passes through to the focused app.
- [ ] An unmapped key passes through. Auto-repeat does not cycle uncontrollably.
- [ ] Release the trigger before releasing a letter. No stray key-up causes an action in the newly focused app.
- [ ] Left Command + C, V, A, S, Tab, and Space retain their usual behavior.
- [ ] Right Command with unrelated extra modifiers does not intercept ordinary shortcuts.
- [ ] Select Right Option, then Control + Option. Each chosen trigger works, with Command added for pinning.
- [ ] Pause and resume from the menu. Pausing stops interception immediately.

## Search and app list

- [ ] Settings has a single Apps tab. Running apps and closed pinned apps appear once each.
- [ ] Filter the Apps list. Opening an app and managing its keys remain available on each matching row.
- [ ] Click an app's keys. Add and remove pins and change their repeat behavior. Changes survive reopening Settings.
- [ ] Use Add pin to choose a closed installed app. The app appears in the same list with its assigned key.
- [ ] Press the trigger + Space. Search opens and the field receives keyboard focus.
- [ ] Search by a prefix and by a subsequence. Running and installed apps appear without duplicate bundle IDs.
- [ ] Arrow keys change the selected result. Return focuses or launches that result.
- [ ] Clicking a result activates it. Escape dismisses search without activating a result.
- [ ] Open search from the menu. It works even when shortcuts are paused or permission is missing.
- [ ] Install, launch, quit, and hide apps. Refreshing shows the updated list.
- [ ] With a non-US keyboard layout, letter assignments follow translated characters.

## macOS integration

- [ ] Enable launch at login from the installed app. Confirm macOS reports its registration, then disable it again.
- [ ] Sleep and wake the Mac. The listener resumes.
- [ ] Lock and unlock the session. Shortcut behavior recovers.
- [ ] Enable Secure Input in an app that supports it. Ordinary typing remains available and shortcut behavior recovers after Secure Input ends.
- [ ] Activate an app on another Space. Behavior follows the current Mission Control setting for switching to an app's Space.
- [ ] Deny or revoke Accessibility while OpenRight is running. The app reports the listener state and does not claim the shortcut was performed.
- [ ] Quit OpenRight. Global shortcuts and the menu bar item disappear.

## Release notes to record

Record the macOS version, CPU architecture, build commit, permission state, and any unchecked items when sharing a build. A successful unit test run does not imply these manual checks passed.
