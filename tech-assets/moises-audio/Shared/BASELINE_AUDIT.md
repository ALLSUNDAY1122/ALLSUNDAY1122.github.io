# MOI-HQ-001 Baseline Audit

Audit date: 2026-08-22 JST
Integration branch: `tech/moises-separation`
Recorded code baseline: `0b161104c9d905c85e65983b5d20ec98b5163b1e`

## Result

Baseline state: `BLOCKED_STRUCTURE` (explicit baseline blocker; not a parity failure).

The recorded code baseline is still valid for implementation work. At audit time the integration branch is one commit ahead of the recorded baseline, and that commit only adds `automation/chatgpt-dispatcher/moises-equivalence/queue.json`; it does not change `tech-assets/moises-audio` implementation code.

## Existing implementation inventory

At the start of MOI-HQ-001, `tech-assets/moises-audio` contains only:

- `AudioSeparationCore.swift`
- `PARITY_MATRIX.json`

There is no Swift Package manifest, Xcode project/workspace, iOS application target, automated test target, or project-level CI entry for this code yet.

## Structural verification

`AudioSeparationCore.swift` was independently type-checked with Swift 6.2.1 on Linux using `swiftc -typecheck` and passed with exit code 0.

This verifies syntax/type consistency of the current standalone core file only. It does **not** prove iOS integration, AVFoundation behavior, real separation inference, UI behavior, performance, or any PARITY row.

## Explicit baseline blockers

1. No package/project manifest means the repository cannot yet run a canonical project build from `tech-assets/moises-audio`.
2. No test target means SI-SDR/reconstruction helpers and future module contracts have no repository-owned regression harness.
3. No iOS app target means device behavior, entitlements, file import/export, audio-session behavior, thermal/memory behavior, and accessibility cannot yet be validated.
4. Feature module directories/contracts were not fixed before this task; `MODULE_BOUNDARIES.md` created by MOI-HQ-001 is the authoritative boundary until MOI-ARCH-001 refines executable contracts.

## Baseline policy

- Do not call this baseline green.
- Do not mark any PARITY row above `MISSING` from compile/typecheck evidence.
- Worker research/benchmark tasks may proceed because the implementation baseline itself has not drifted.
- Executable architecture and an iOS build/test harness are follow-up work; they must be established before implementation tasks can claim build/test parity.
