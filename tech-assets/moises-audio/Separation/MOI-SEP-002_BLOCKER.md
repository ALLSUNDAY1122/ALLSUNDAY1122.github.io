# MOI-SEP-002 — fenced attempt blocker

Captured: 2026-08-22 13:55 JST
Worker: Moises-Worker-1
Attempt: `task/MOI-SEP-002/attempt-1`

## Why implementation cannot lawfully start yet

`MOI-SEP-002` acceptance requires all of the following in the same attempt:

- real multi-genre audio produces actual separated stems;
- quality evidence is captured against the Golden QA rubric;
- processing exposes progress, cancel, retry and deterministic failure state.

The current canonical prerequisites do not permit those gates to be executed yet.

### 1. Queue dependency gate is not fully finalized

Current Queue still records:

- `MOI-SEP-001 = INTEGRATION_READY`, not `VERIFIED`;
- `MOI-BLD-002 = INTEGRATION_READY`, not `VERIFIED`;
- `MOI-ARCH-001 = VERIFIED`;
- `MOI-QA-001 = VERIFIED`.

The project roadmap states that only the next wave whose dependencies are established is raised to READY. The Worker contract also requires dependency validation before execution. Therefore the two non-finalized dependencies cannot be treated as canonical implementation contracts yet.

### 2. The selected lawful separator weights do not exist yet

`Separation/benchmarks/MOI-SEP-001_DECISION.json` explicitly records:

- production weight policy = project-owned from-scratch weights or an explicit written commercial grant;
- selected model family = Demucs/HTDemucs-class permissively licensed code;
- selected weights = project-owned weights trained from rights-cleared real multitracks;
- known unknown = **project-owned trained separator weights do not exist yet**;
- official Demucs/HTDemucs weights, uncleared Spleeter weights and uncleared/noncommercial Open-Unmix weights are excluded from production use.

Repository search for checkpoint / `.pt` / `.pth` / `.ckpt` / HTDemucs separator weight assets returned no usable project-owned trained checkpoint.

Without a lawful trained checkpoint, no real multi-genre source-separation inference can be executed. A mock, identity split, synthetic-only split or prebaked output would violate the task acceptance and the project PARITY rules.

### 3. Real-audio quality evidence cannot be fabricated

`PARITY_MATRIX.json` keeps MOI-P003 and MOI-P004 at `MISSING` and requires real multi-genre audio, audible-quality evidence and no fake/prebaked result. The QA contract also forbids synthetic-only PASS.

This attempt therefore does not create a fake Swift separator merely to compile, and it does not promote any PARITY row.

## Exhausted safe alternatives

1. Use official Demucs/HTDemucs pretrained weights — rejected by verified licensing audit.
2. Use Spleeter pretrained weights — rejected until authoritative commercial use/conversion/redistribution rights are resolved.
3. Use noncommercial/uncleared Open-Unmix weights — rejected by licensing policy.
4. Create synthetic/mock stems — rejected by QA/PARITY contract.
5. Implement only an interface or fake runtime — would not satisfy actual-stem acceptance and would misrepresent progress.
6. Search repository for a project-owned trained checkpoint — none found.

## Required unblock conditions

Before a new attempt is made, canonical state should provide all of the following:

1. `MOI-SEP-001` finalized by HQ as `VERIFIED` (or superseded by an explicitly approved replacement decision).
2. `MOI-BLD-002` finalized by HQ as `VERIFIED` so the implementation/test seam is canonical.
3. At least one **lawful executable separator checkpoint**:
   - project-owned weights trained on rights-cleared real multitracks, or
   - an explicit written commercial licence for the exact weights and intended server/on-device topology.
4. Rights-cleared real multi-genre evaluation fixtures meeting the Golden QA provenance rules.
5. Executable inference environment details sufficient to run the selected baseline and capture latency/failure evidence.

## Attempt result

- No product separator implementation was created because it could not meet acceptance truthfully.
- No Shared/App/PARITY file was changed.
- MOI-P003 / MOI-P004 remain `MISSING`.
- Recommended Queue state: `BLOCKED_DEPENDENCY` and release `source-separation-model` lock until the unblock conditions above are canonical.
