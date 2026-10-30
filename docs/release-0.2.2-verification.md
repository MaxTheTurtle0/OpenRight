# OpenRight 0.2.2 verification

Release: https://github.com/MaxTheTurtle0/OpenRight/releases/tag/v0.2.2

Source revision: `3467bd114c5ad8a34fb39fc3f5a207113ee4e0ef`. Version 0.2.2, build 4. Verified on macOS 27.0.1, Apple Silicon.

## Apps screen

Settings has General, Apps, and About. Apps replaces the separate Running apps and Pinned keys tabs. Each running or pinned app has one row. The row shows its running/hidden/closed state and assigned keys, with Open and key-management actions together.

Verified in a native test host compiled from the production AppModel, UpdateService, and Views sources. It used an isolated preferences file and did not change the user's pins or system permissions.

- The sidebar contains one Apps tab.
- A closed pinned Calculator appears alongside running apps.
- Filtering the list finds the closed app.
- Clicking its key opens its pin controls.
- Changing an existing pin's repeat behavior updates the view.
- Adding a second pin shows both keys on the same row.
- Removing the last pin from a closed app removes that app's row.
- Add pin searches installed apps and lets a closed Calculator be selected directly.
- Adding its pin brings one row back, marked Not running and Pinned.
- Entering a key assigned to Zen shows Replace pin and a warning before saving.
- Pin additions, removals, and repeat settings persist to the isolated preferences file.
- The native screen was visually inspected at the normal Settings window size. Offscreen render checks cover the merged list and an editor with multiple pins too.

## Automated checks

- 53 Swift tests passed with warnings treated as errors.
- Three Python release-pipeline tests passed.
- The new catalog test covers multiple pins without duplicate rows, closed installed apps, missing saved app paths, and current running-app metadata.
- The native packaged build and git diff whitespace check passed.

## Distribution and installed app

- The universal app contains Apple Silicon and Intel executable slices.
- Developer ID signature, stapled Apple notarization ticket, and Gatekeeper assessment pass. Gatekeeper reports `accepted`, `source=Notarized Developer ID`.
- The published appcast contains build 4, the immutable v0.2.2 ZIP URL, and its correct byte count. The release pipeline verified its Ed25519 signature.
- Public DMG and ZIP downloads match the verified local release artifacts by SHA-256.
- Sparkle updated the installed, notarized 0.2.1 app to 0.2.2/build 4 and relaunched it from `~/Applications/OpenRight.app`.
- All existing preferences and seven pins matched the pre-update JSON exactly.
- Accessibility approval and the active Right Command listener survived the update.
- The installed app's Apps tab was inspected with the real saved pins. The separate sidebar tabs are gone, and the keys are shown beside the app rows.
- The source revision's [main CI run](https://github.com/MaxTheTurtle0/OpenRight/actions/runs/41031546872) passed.

Intel hardware and older macOS versions were not available locally. The DMG is an unsigned container carrying the signed, notarized app, as in earlier releases.

Public artifact SHA-256 values:

```text
4d8c56f465b055f8ac9873083eccd3dd640e37764e1a27f317225e66ce9b32c6  OpenRight.dmg
a4fa8870448000530787cdec726b8d422b987ec6c002bedb586275e506e97c72  OpenRight-0.2.2-universal.zip
```
