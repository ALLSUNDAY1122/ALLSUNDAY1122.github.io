# MOI-ARCH-001 — Vertical Slice Contract Validation

Captured: 2026-08-22 JST
Owner: Moises-HQ-1
Attempt: `task/MOI-ARCH-001/attempt-1`

## Scope

This task converts the previously documented module boundaries into small Swift contracts plus an App-only composition coordinator. It does not implement feature algorithms and does not raise any PARITY row.

## Reference-driven decisions

- Import returns an app-owned durable asset descriptor; external picker/provider URLs do not become long-lived cross-module state.
- Separation processing state is distinct from player presentation state. The App may enter the Project route while stems are still preparing, matching the current iPhone recording rather than forcing a full-screen blocking model.
- Chord/analysis results are timestamped domain values; presentation may synchronize them to the Playback clock without Analysis owning transport.
- Export is reachable from Project composition but IO remains responsible only for encoding/file lifetime/share handoff.
- Waveform is not encoded as a required current-iPhone Reference contract because REF-001 attempt-2 did not establish current waveform availability. Timeline/seek and any future waveform view remain Playback/product requirements subject to later Reference verification.

## Shared contract invariants

`Shared/DomainContracts.swift` contains only IDs, serializable value types, stable error categories and protocols. It contains no AVFoundation, CoreML, persistence implementation, model runtime or UI type.

Feature ownership remains:

- IO: acquisition, durable local normalization, decode/export/share boundary.
- Separation: inference, progress/cancel/result semantics.
- Playback: transport/mixer clock and synchronized stems.
- Analysis: BPM/key/chord/section facts.
- DSP: tempo/pitch/click/count-in transforms driven by explicit timing facts.
- Library: durable project/setlist/resume records.
- App: composition/navigation/presentation coordination only.

## Vertical slice

`App/VerticalSliceCoordinator.swift` wires:

`import -> project create -> source playback preparation -> separation start -> project visible while stems prepare -> stem replacement when ready -> analysis -> export`

The coordinator does not store transport position, mixer levels, model internals, DSP render internals, or persistence implementation objects.

## Machine validation

HQ independently typechecked the new Swift files together using Swift 6.2.1 on Linux:

`swiftc -typecheck Shared/DomainContracts.swift App/VerticalSliceCoordinator.swift`

Result: exit 0, no diagnostics.

This proves contract-level Swift consistency only. It is not iOS build evidence, audio-quality evidence, end-to-end product evidence, or PARITY evidence.

## Remaining build integration

The current `Package.swift` still lists the pre-boundary prototype source explicitly. A follow-up build-harness task must add the new Shared/App sources and later feature targets without giving Worker tasks permission to redefine Shared contracts.

## Acceptance

- Vertical-slice contracts fixed without hiding missing features: satisfied.
- Modules communicate through small explicit contracts: satisfied.
- Worker write scopes can remain separated without semantic overlap: satisfied.
- PARITY change: none; `MOI-P022` remains MISSING until real end-to-end device evidence exists.
