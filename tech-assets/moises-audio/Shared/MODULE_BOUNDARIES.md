# Moises同等化 Shared Module Boundaries

Status: HQ-fixed baseline boundary for integration epoch 1.
Owner: HQ (`shared-contract`).

## Purpose

Workerごとの実装速度を上げても、同じ責務を別モジュールへ重複実装しないための境界契約。MOI-ARCH-001で実行可能なSwift protocol/data modelへ落とすまでは、この文書を論理境界の正本とする。

## Global dependency rule

- `Shared` は全モジュールが参照可能な小さな値型・ID・protocol・共通errorだけを所有する。
- `App` はcomposition/navigation/global app stateだけを所有し、feature algorithmを持たない。
- Separation / Playback / Analysis / DSP / Library / IO は原則 `Shared` のみに依存する。
- feature同士の直接importを既定で禁止する。連携はShared契約を介してAppがcompositionする。
- AVFoundation / CoreML / model runtime / persistence implementation等の具象型をSharedへ漏らさない。
- Workerは他logical resourceの契約を勝手に再定義しない。必要変更はevidenceとしてHQへ上げる。

## Separation

Owns:
- source-separation model/runtime selection and inference
- mixtureからstem artifactを生成する処理
- separation progress / cancellation / deterministic failure semantics
- model-specific preprocessing/postprocessing

Must not own:
- playback transport/mixer UI
- BPM/key/chord analysis
- project persistence
- import picker/export share UI

Boundary output:
- stable stem artifact descriptors + processing metadata; downstream modules consume descriptors, not model runtime objects.

## Playback

Owns:
- synchronized multi-stem transport
- play/pause/seek/loop
- solo/mute/volume/remix state
- playback clock and observable transport state

Must not own:
- source separation inference
- persistent project storage
- musical analysis algorithms

Boundary input:
- audio/stem artifact descriptors supplied through Shared contracts.

## Analysis

Owns:
- BPM/beat-grid detection
- musical key detection
- timestamped chord detection
- song-part/section detection
- confidence/error metrics for analysis outputs

Must not own:
- audio playback engine
- tempo/pitch rendering
- library persistence

Boundary output:
- timestamped, serializable analysis results expressed in Shared domain values.

## DSP

Owns:
- tempo/speed transformation
- pitch/key shifting
- metronome/click generation
- count-in timing
- artifact/latency measurement related to those transforms

Must not own:
- BPM/key/chord inference
- transport ownership
- stem separation

Boundary input:
- beat/timing/key facts and transport clock are passed through Shared contracts. DSP does not redefine Analysis or Playback state.

## Library

Owns:
- project metadata persistence and resume
- setlists and ordering
- lifecycle-safe processing state references
- deletion semantics for locally owned project metadata/artifacts

Must not own:
- audio algorithms
- file picker/export encoder UI

Boundary rule:
- persist Shared serializable domain records; do not persist opaque feature-engine objects.

## IO

Owns:
- supported audio/video file import adapters
- sandbox/file-lifetime management at import/export boundary
- mix/stem export encoding and naming
- system share handoff

Must not own:
- project library semantics
- separation/playback/analysis algorithms

Boundary output:
- normalized local audio asset descriptors. Imported external URLs must not leak as long-lived assumptions into feature modules.

## App

Owns:
- root composition and dependency injection
- navigation and screen orchestration
- global entitlement/app lifecycle presentation state
- end-to-end flow wiring: import -> process -> mixer/practice -> save/export

Must not own:
- feature algorithms or duplicate domain state that belongs to feature engines.

## Integration invariants

1. No feature module may change another module's logical resource without a Queue task holding that resource lock.
2. Shared contract changes are HQ-only and require cross-feature compatibility review.
3. A compile/test success cannot raise PARITY by itself.
4. Synthetic fixtures cannot be the sole evidence for audio-quality PASS.
5. Unknown Moises behavior remains `UNKNOWN` in reference evidence; implementation must not encode guesses as parity requirements.
6. `AudioSeparationCore.swift` is treated as a pre-boundary prototype until MOI-ARCH-001 explicitly migrates/adopts its types.
