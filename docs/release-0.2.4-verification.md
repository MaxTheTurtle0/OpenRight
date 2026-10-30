# OpenRight 0.2.4 verification

Release: https://github.com/MaxTheTurtle0/OpenRight/releases/tag/v0.2.4

Source revision: `a1598547b6475f5f4e66484eb1a1b22b239d97ac`. Version 0.2.4, build 6. Verified on macOS 27.0.1, Apple M3.

## Performance and behavior

Six agents audited and reviewed the shortcut engine, search, catalog, SwiftUI work, background lifecycle, and regression risk. Independent source reviews scored the completed change 9/10 with no material remaining findings. The [performance report](performance-0.2.4.md) and [raw component measurements](../Benchmarks/results/0.2.4.json) describe the fixtures, improvements, and limitations.

- All 69 Swift tests passed with warnings treated as errors, plus three Python release-pipeline tests.
- The release pipeline repeated those checks against the clean committed source. Native and universal packaging passed.
- Native checks covered filtered result labels, repeated search reopening and focus, Up/Down selection, Escape dismissal, and Return launching Calculator. Calculator was closed afterward.
- A benchmark-only weak reference confirmed that dismissal releases the optimized search host while keeping the reusable panel. The baseline retained that host.
- The source revision's [main CI run](https://github.com/MaxTheTurtle0/OpenRight/actions/runs/41045544922) passed, including universal packaging and signature verification.

Fresh hardware Right Command latency was not measured. The existing keyboard-monitor and resolver tests passed. Computation benchmarks do not measure app launch, window activation, child layout, or drawing.

## Idle and memory follow-up

The installed update used about 0.15% of one CPU core over a 20-second closed-Settings sample. Its RSS was 114.4 to 113.6 MiB, versus 43.9 MiB in the earlier long-running baseline sample. Those process histories were different, so that RSS comparison was not treated as a regression or a memory improvement. `vmmap` reported 46.6 MiB physical footprint for the installed update.

A follow-up launched fresh isolated baseline and final native fixtures with the same preferences and rendered the same Apps screen. Over the same 20-second window, baseline RSS stayed at 115.7 MiB and final RSS was 112.9 to 112.8 MiB; physical footprints were 51.9 and 51.5 MiB respectively. Both used about 0.05% of one CPU core. This check found no material memory regression for that workload. These short samples do not establish long-session leak freedom or general energy savings. Both isolated fixtures were quit afterward.

## Distribution and installed app

- The universal app passed Developer ID signature verification, stapled Apple notarization-ticket validation, and Gatekeeper assessment: `accepted`, `source=Notarized Developer ID`.
- Signing team: `QFQ522WH9R`, Developer ID Application: Marian-Andrei Antonescu.
- The release pipeline verified the Ed25519 signature on the update ZIP. The public appcast contains build 6, version 0.2.4, the immutable v0.2.4 ZIP URL, and its expected length of 2,289,241 bytes.
- Public downloads of the DMG, ZIP, and appcast match the verified local artifacts by SHA-256.
- The installed 0.2.3 app discovered 0.2.4, downloaded it, installed it, and relaunched through Sparkle from `~/Applications/OpenRight.app`.
- The installed app reports version 0.2.4/build 6. Its signature, both CPU architectures, notarization ticket, and Gatekeeper assessment pass.
- All saved preferences and seven pin bindings match the pre-update JSON exactly. Accessibility approval and the active Right Command listener survived the update.
- General and the grouped Apps screen were inspected after installation.

The DMG remains an unsigned container carrying the signed, notarized app. Intel hardware and older macOS versions were not available locally.

Public artifact SHA-256 values:

```text
04748b2e0c2e9836f14055d63e4161462596e175f9e879fd7fca1f57831108b6  OpenRight.dmg
275fbcff1129c609ecef4c9897f6838fe98bf94623d72646e4e838e707a615f9  OpenRight-0.2.4-universal.zip
dec64879367dfeab4997ae6def35520fce24074dfbe98aaa2f7142ec05c6cad4  appcast.xml
```
