# OpenRight 0.2.3 verification

Release: https://github.com/MaxTheTurtle0/OpenRight/releases/tag/v0.2.3

Source revision: `3090ce069a336b48cf80a22cf946f040114b7756`. Version 0.2.3, build 5. Verified on macOS 27.0.1, Apple Silicon.

## Shared-key groups

ShortcutResolver.targets supplies the ordered app targets to both shortcut actions and the Apps groups. Pins lead their groups. Cycle pins include other naturally matching running apps, including apps with their own alternate pins. Hide pins, disabled keys, and closed pinned targets follow the existing resolver behavior.

The displayed keys come from pins and automatic keys for apps without enabled pins. Extra aliases that would only repeat the same pinned app are omitted. Apps can appear in multiple groups when those keys reach them. Apps without an available displayed key stay editable under No key.

Verified in a native host compiled from the production sources with an isolated preferences file:

- P contains Passwords and Preview.
- T contains Microsoft Teams, T3 Code, and Tailscale. T3 Code also appears under its explicit 3 pin.
- Typing P or T isolates that key group. Search by app name remains available.
- The pin icon opens the editor from a group row. A new Preview pin was added and removed successfully without losing its natural P membership.
- The compact Apps layout was visually inspected at 720 by 560 points. Key labels appear once per group, without repeated Open buttons or Running/Pinned labels. Closed Calculator remains marked Closed.
- The filter toolbar sits outside the list's scroll view.
- General has no large title, subtitle, branding, or redundant success banner. Its controls remain present.

The host used simulated permission/listener state for UI layout only. It did not grant system permissions, install a keyboard listener, or modify the user's preferences.

## Automated checks and layout

- 58 Swift tests passed with warnings treated as errors, including all existing action-resolution tests.
- Three Python release-pipeline tests passed.
- New tests cover shared target ordering, alternate pins, disabled keys, Hide pins, closed pins, omitted alias-only groups, and apps that still need assignment.
- Settings renders at 720 by 560 and the new 660 by 440 minimum. General content can scroll at the minimum height. The grouped Apps list and multi-pin editor also render.
- Native and universal packaged builds completed. The release script ran the checks again against the clean committed source.
- Git diff whitespace checks passed.

## Distribution and installed app

- The Developer ID-signed universal build passed code-signature verification, stapled Apple notarization-ticket validation, and Gatekeeper assessment. Gatekeeper reports `accepted`, `source=Notarized Developer ID`.
- The release pipeline verified the Ed25519-signed ZIP and appcast. The public feed contains build 5, the immutable v0.2.3 ZIP URL, and the expected byte count.
- Public downloads of the DMG and ZIP match the verified local artifacts by SHA-256.
- The installed notarized 0.2.2 app discovered 0.2.3 through Sparkle and updated to build 5. It relaunched from `~/Applications/OpenRight.app`.
- The resulting app's signature, notarization ticket, and Gatekeeper assessment pass.
- All preferences and seven pins match the pre-update JSON exactly. Accessibility approval and the active Right Command listener survived the update.
- The installed Apps screen was inspected with the actual saved pins. P contains Passwords and Preview; T contains Teams, T3 Code, and Tailscale. The current list fits in the smaller default window, without the previous title/description and repeated status blocks.
- The source revision's [main CI run](https://github.com/MaxTheTurtle0/OpenRight/actions/runs/41034441096) passed.

Intel hardware and older macOS versions were not available locally. Fresh hardware Right Command input was not part of these UI checks. Existing keyboard tests passed. The DMG remains an unsigned container carrying the signed, notarized app.

Public artifact SHA-256 values:

```text
2c18b5cc968812c95b428d40b6712ceb64dc6a06909384f3dda7d0aab2ef031e  OpenRight.dmg
0e8b64c07852114e34b2518fd42782ba693b8bc1bf38981640f578ebf9868ea2  OpenRight-0.2.3-universal.zip
```
