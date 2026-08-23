# L2-AW17 Export Prejournal Publication Guard Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. This wave closes the canonical `IOSAtomicM4AExporter` crash window between atomic export-batch publication and durable `Lane2ExportRegistrationJournal.prepare(...)` without changing `Shared/**`, `App/**`, or `PARITY_MATRIX.json`.

## Problem confirmed

Before AW17, `IOExportBatchTransaction.commit(...)` atomically renamed a complete batch into `Exports/Batches/<batch-id>/` and returned. `Lane2DurableLifecycleCoordinator.exportAndRecord(...)` only then called `Lane2ExportRegistrationJournal.prepare(...)`. Process death after the rename but before the journal write could therefore leave valid audio under `Exports/**` with neither lifecycle metadata nor an export-registration intent.

## Production change

### IO publication guard

`IOExportBatchTransaction.commit(...)` now creates and synchronizes `.lane2-registration-pending` inside the staging batch before the atomic directory rename. The marker contains a process-session UUID. Therefore every successfully published canonical batch crosses the rename with an explicit pre-registration recovery signal.

### Library adoption ordering

`Lane2ExportRegistrationJournal.prepare(...)` now keeps this ordering:

1. validate/normalize intended `Exports/**` paths;
2. atomically write the Library registration intent;
3. only after the intent write succeeds, remove the IO pre-registration marker;
4. return the prepared intent to the existing coordinator, which then records lifecycle export metadata.

If marker removal fails after the intent write, `prepare` fails but the journal remains. This intentionally prefers redundant recovery signals over a signal-free state.

### Relaunch recovery

`Lane2ExportRegistrationJournal.pending()` first checks finalized batch directories for the pre-registration marker.

- marker session == current process session: retain it, because a reentrant recovery call can race the short interval between IO publication and journal adoption;
- marker belongs to a previous process: atomically move the whole batch out of `Exports/**` into `.LibraryRecovery/PrejournalExport/<batch-id>/`;
- bytes are preserved, not deleted;
- normal registration-intent recovery then continues.

The canonical state sequence is now:

`staging only -> staging + marker -> published + marker -> published + journal -> published + journal + lifecycle metadata -> normal published export`

At every crash boundary there is either an unpublished staging batch, an IO marker, a Library journal, or durable lifecycle metadata.

## Negative / recovery cases validated

- every canonical committed batch has the marker and current process session;
- journal adoption clears marker only after intent persistence;
- current-process marker is not quarantined by a reentrant recovery call;
- previous-process marker is removed from published `Exports/**` and bytes are preserved in recovery quarantine;
- `pending()` performs previous-process marker recovery before intent enumeration;
- two-artifact atomic batch adoption clears one batch marker without touching audio files;
- non-Exports journal path remains fail-closed;
- existing unpublished `Staging/ExportBatches/**` recovery remains separate and unchanged.

## Portable execution

Environment: Swift 6.2.1 Linux.

PASS:

- modified `IOExportBatchTransaction.swift` + `Lane2ExportRegistrationJournal.swift` strict-concurrency/warnings-as-errors compile against contract-equivalent `IOFileStore` surface;
- `ExportPublicationGuardTests.swift` 5-case XCTest strict typecheck;
- exact committed self-check blob `b1fcb76751974e50b9b3ce446f06385f29b72c22` rerun: `L2_AW17_SELF_TEST_PASS scenarios=8 batches=200 elapsed_seconds=0.834158`;
- static production wiring audit verifies marker-before-rename, intent-before-marker-clear, process-session guard, previous-session quarantine, current-session retention, and pending-before-intent recovery ordering.

The 0.834158 s value is a Linux filesystem microbenchmark for 200 marker/journal handshakes with 1 KiB fixture files. It is not an iPhone/APFS export-performance measurement.

## Important boundaries

- This closes the pre-journal crash window for the canonical exporter path that publishes through `IOExportBatchTransaction`. An alternative `AudioExporting` implementation that bypasses this transaction does not automatically inherit the marker guarantee and must not replace the canonical production exporter without equivalent evidence.
- `.LibraryRecovery/PrejournalExport/**` is preservation quarantine. AW17 intentionally does not infer project ownership or automatically destroy quarantined bytes when the crash happened before the Library journal existed.
- Real AVFoundation M4A output, APFS durability, force-termination timing, share-sheet behavior, real storage pressure, and current-iPhone playback remain Apple/HQ gates.
- MOI-P019 remains `MISSING`; this portable recovery proof is not product PARITY.

## HQ integration requirements

1. Keep `IOSAtomicM4AExporter` / `IOExportBatchTransaction` as the canonical production export publication route.
2. Do not replace it with an exporter that bypasses `.lane2-registration-pending` without implementing an equivalent pre-registration durable guard.
3. On iPhone force-terminate at: before marker, after marker/before rename, after rename/before journal, after journal/before marker clear, after marker clear/before metadata, after metadata/before journal removal.
4. Verify previous-process marker batches move to `.LibraryRecovery/PrejournalExport/**` and remain byte-preserved.
5. Define App/HQ UX/retention policy for rare prejournal quarantine; Lane 2 does not guess ownership when no Library intent was ever durable.
6. Do not promote MOI-P019 from this evidence alone.
