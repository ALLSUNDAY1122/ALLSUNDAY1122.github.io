# S7 Wave 1 HQ Combined Integration

Date: 2026-08-25 JST
Base: `feature/splat-native-ios-poc@42e34fb0a88be264a863666cce68081293cfc4cd`
Integration branch: `scaniverse/s7-wave1-hq-integration`

## Fresh worker inputs

- M1 `eb08cf00f0ef328a54fcd3dcf73f3c988806612c`
- M2 `103a743fb004d6233fc51c65df85e1fa098c9462`
- M3 `91aefabe45ce7b8ff2c2d07c9db7df4df684baf3`
- SH `6193c99c7c0e1fc18def6e6aef2654df51f1b54a`

All four exact heads passed Splat Native Privacy Preflight, Splat Smoke Diagnostic, and Splat Native iOS Build before HQ composition. Worker CI is input evidence only; it is not combined or physical parity evidence.

## Msplat composition

Pinned revision remains `d620d9c58d270e7de9e34a9d8a85dcf938a5070d`.

`materialize_msplat_s7_wave1.sh` is the only XcodeGen pre-generation entrypoint. It:

1. materializes the pin once through M1 and applies/tests M1;
2. applies M2 to the same tree using the non-destructive adapter;
3. requires exactly seven dirty paths: M1 marker + six owned source files;
4. reruns both M1 and M2 source contracts;
5. runs the HQ cross-lane quality/telemetry/SH3 contract.

Combined source ownership is exactly:

- M1: `input_data.hpp`, `input_data.cpp`, `msplat_api.mm`
- M2: `metal_tensor.hpp`, `model.hpp`, `model.cpp`

The standalone M2 `.generated/msplat-m2` project path is intentionally not used by HQ.

## M3 + SH semantic composition

M3 current `ScanModel.swift`, `SplatResourceGuard.swift`, telemetry tests, adaptive tests and reconstruction contracts are integrated without changing ResourceGuard thresholds. SH wraps the same `GaussianTrainer` surface and preserves `saveCheckpoint(to:) -> Bool` and `loadCheckpoint(from:) -> Int?`, while requiring a durable SH3 canonical PLY before a new reconstruction is accepted.

SH export prefers the canonical SH3 asset for PLY/SPZ and retains legacy `.splat` fallback only for older projects. The SH durability source is explicitly retained in the merged `project.yml` test target.

## Quality invariants

The HQ integration contract requires:

- `standardIterations = 7_000`
- `datasetDownscale = 4.0`
- `shDegree = 3`
- capture JPEG quality `0.90`
- original ResourceGuard memory/reserve/Gaussian threshold ranges

No frame subset, iteration reduction, SH reduction, Gaussian cap reduction, JPEG degradation, or ResourceGuard threshold increase is used to obtain memory headroom.

## Remaining gates

This commit is not Build 5 and does not claim parity. It must pass the combined Privacy / Smoke / Native iOS CI at the exact HQ integration head. Only then may a Build 5 candidate be produced for the real-iPhone reconstruction, telemetry, SH3 persistence, cold-reopen and Golden comparison gates. SPZ antialias semantics remain a separate HQ physical/Golden gate.
