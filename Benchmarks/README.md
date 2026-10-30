# Performance checks

Run from the repository root on macOS:

```sh
swiftc -O -whole-module-optimization -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -parse-as-library Sources/OpenRightCore/*.swift Benchmarks/CoreBenchmark.swift -o .build/core-benchmark
.build/core-benchmark
```

Use `--filter resolve-11` or `--filter search-500-empty` to select a workload. Inputs are synthetic. Nothing is posted to the keyboard or desktop, and no private preferences are read.

Each JSON record contains seven per-operation batch means and their median, plus an output checksum. These are optimized Core computation costs, not end-to-end shortcut latency or per-call p50/p95 measurements. Run on an otherwise quiet machine and repeat in reverse order when comparing revisions. Treat tiny normalization microbenchmarks near the timer/optimizer floor cautiously.

The performance report in `docs/performance-0.2.4.md` describes the separate Apps body/projection and unchanged-catalog workloads. Those used benchmark-only copies of the actual model/views with projection counters, plus the same optimized compiler flags. Their timings exclude child layout, drawing, app launch, and event delivery.
