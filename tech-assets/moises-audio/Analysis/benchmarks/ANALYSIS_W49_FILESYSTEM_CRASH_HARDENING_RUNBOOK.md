# W50｜W49 consumption ledger filesystem / crash hardening runbook

Status: **NON_PARITY**. This runbook hardens custody only.

## Production API

Use `AnalysisPhysicalRealAudioBridgeConsumptionSecureStore` instead of the legacy W49 store for new appends, reopen, recovery and consumed-root inventory. Use `AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager` for checkpoint creation/verification.

The secure store keeps the W49 on-disk record/head formats and roots unchanged, so W49 history remains compatible. The difference is the filesystem trust boundary: root, bridge directory, ledger directory and `records/` must be real directories, not symlinks; head/pending/record artifacts must be regular files, not symlinks; resolved paths must remain under the selected root; reads are byte-bounded before JSON decode; unexpected ledger-root entries fail closed.

## Required sequence

1. Preserve the latest externally retained W49 checkpoint/handoff root before touching the mutable ledger.
2. Call secure `recoverIfNeeded` before relying on a ledger after interruption.
3. Append one validated W48 certificate with HQ custody metadata through secure `append`.
4. Obtain future W48 consumed-package inventory only through secure `expectationUsingDurableConsumedInventory`.
5. Create/verify checkpoints through `AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager`.
6. Persist the new checkpoint/handoff outside the mutable ledger directory.

## Recovery contract

- Pending marker only: candidate was not committed; remove marker and retain prior head.
- Pending + exact candidate record, old head: roll forward exactly that candidate and rebuild head.
- Pending + exact candidate record + matching new head: remove only the pending marker.
- Corrupt/truncated pending marker: fail closed; do not guess.
- Candidate-path collision with different bytes: fail closed; do not overwrite.
- Injected read-back failure after pending removal: reopen the committed head; do not append the same certificate again.

## Filesystem rejection contract

Reject symlinked ledger/control/record paths even if the target is inside the nominal root. Reject directories/FIFOs/devices in place of control/record files. Reject path escapes after both lexical normalization and symlink resolution. Reject oversized head/pending/record files before decode. Reject unexpected files beside `records/`, head and pending marker.

## Limits

W50 does not establish APFS power-loss durability, fsync guarantees, Apple attestation, signatures or trusted timestamps. Physical-iPhone crash/power interruption remains an HQ/integration gate. W50 does not replace rights-cleared real audio, current-iPhone Moises Reference evidence, W46 differential evidence, or HQ PARITY judgment.
