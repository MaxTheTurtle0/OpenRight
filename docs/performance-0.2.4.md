# OpenRight 0.2.4 performance audit

Six agents reviewed shortcut/search costs, catalog notifications and scans, SwiftUI projections, runtime lifecycle, and regression risk. The baseline was `577ea053881b52e3d9d89437202070428b908428`, the source after release 0.2.3. Independent reviews found no material source correctness or reuse issues after the changes, scoring the patch 9/10.

## Changes

- Apps builds one shared groups/unassigned snapshot per body evaluation. Filtering and divider rendering reuse that snapshot.
- Search ranking folds each candidate name once and reuses its MRU rank during sorting. Launcher bodies and navigation handlers capture the result array once per call.
- Shortcut actions validate preferences and keys once before entering the shared target helper. Ordinary ASCII keys have a tested fast path; Unicode keeps the original Foundation fallback.
- Unchanged workspace snapshots no longer republish catalogs or sort the full installed list. MRU updates publish once, and duplicate startup refresh work is gone.
- Refresh cancellation reaches the actual detached scanner. Filesystem enumeration checks cancellation, and cancelled results cannot publish over the latest catalog.
- Equal preference saves skip duplicate encoding and atomic writes. Missing files are recreated, failed writes remain retryable, and saving does not depend on Settings being open.
- The app chooser constructs visible rows lazily. No persistent icon or presentation cache was added.
- Dismissed launcher content is detached because each new open already creates a fresh host. The queued field-focus callback checks that its field is still attached to the intended window.
- Native testing also exposed stale filtered result labels in the baseline. Launcher row and scroll identities now use app IDs consistently instead of mixing app IDs and indexes.

## Measured component costs

Apple M3, macOS 27.0.1, Swift 6.4. Baseline and optimized inputs used identical `-O -whole-module-optimization -swift-version 5 -target arm64-apple-macosx13.0` flags. Representative cases were repeated in reverse execution order. Values below are the confirmation medians of seven per-operation batch means.

| Synthetic workload | Before | After |
| --- | ---: | ---: |
| Resolve shortcut, 11 apps and 7 pins | 21.30 µs | 8.84 µs |
| Empty search, 500 installed apps | 10.947 ms | 0.476 ms |
| Apps parent body, 11 apps and 7 pins, key filter | 3.622 ms | 0.119 ms |
| Unchanged workspace refresh, 500-entry installed catalog | 1.598 ms | 0.147 ms |

The Apps parent workload invokes the actual body-construction path with synthetic data and benchmark-only query inputs/counters. It excludes child layout and drawing. Full group projections per filtered body fell from 21 to 1. With 100 running apps and 36 pins, that count fell from 75 to 1; measured parent construction fell from 361.7 ms to 2.74 ms. These are stress fixtures, not a claim about typical installed-app counts.

Across 70 unchanged workspace refreshes, the baseline published 70 running-app values, 70 installed-catalog values, and 70 conflict flags. The optimized model published zero of each. Changed metadata and conflict state still publish, as covered by regression tests.

Checksums matched in the Core and app-fixture comparisons. Existing ranking/target tests plus new Unicode, dirty-input, cancellation, publication, and persistence regressions verify behavior separately. Unicode normalization cost was near unchanged in confirmation, 0.549 versus 0.559 µs. Tiny ASCII normalization timings approach the optimizer/timer floor and are not used as a headline result.

These measurements are computation costs, not key-to-window latency, per-call p50/p95, startup time, or frame-time guarantees. Run-to-run variance was larger in baseline Apps construction, so the confirmation values are used rather than the larger first-run speedup. Prefix, fuzzy, and miss searches did not show a comparable large improvement.

The baseline closed-Settings sample used about 0.25% of one CPU core over 20 seconds and about 43.9 MiB RSS. Sample stacks were mostly waiting. This did not justify removing permission/recovery polling or changing Sparkle scheduling.

## Native checks and limits

Isolated native fixtures used production sources, separate bundle IDs and preference files, and no update-feed configuration. They did not obtain Accessibility access or modify the user's pins.

A benchmark-only weak reference confirmed that the baseline retained its search host after dismissal while the optimized host was released; the reusable panel remained alive. This proves host disposal, not a specific RSS reduction, since system caches and allocations can remain resident.

Native checks covered exact and multi-result labels, search-field focus, repeated reopening, Down/Up selection, Escape dismissal, and Return launching Calculator. Calculator was closed after the test. Result identity changes were checked after the baseline stale-label issue was reproduced. Automated desktop inspection sometimes lost floating-window handles; fixture window titles were made unique to make the checks reliable.

All 69 Swift tests passed with warnings treated as errors, along with three Python release-pipeline tests. Both native packaging and whitespace checks passed. Fresh hardware Right Command timing was not measured; the existing keyboard-monitor tests passed.

The committed [Core benchmark](../Benchmarks/CoreBenchmark.swift), [instructions](../Benchmarks/README.md), and [measurement data](../Benchmarks/results/0.2.4.json) preserve the reproducible workload and results. App body/catalog measurements used temporary instrumented copies of the actual source; counters and lifecycle diagnostics are not shipped in the app.
