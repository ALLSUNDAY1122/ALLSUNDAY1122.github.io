# MOI-HQ-ARCH-002 — Library contract extension validation

Captured: 2026-08-22 JST
Owner: Moises-HQ-1
Attempt: `task/MOI-HQ-ARCH-002/attempt-1`

## Purpose

LIB-R001 established that full library parity needs project read/list, versioned user edits, setlist CRUD/reorder, deterministic deletion, and processing recovery semantics that were not present in the original write-side `ProjectPersisting` contract.

## Non-breaking design

`ProjectPersisting` is left unchanged because `VerticalSliceCoordinator` and existing tests already consume it. `ProjectLibraryPersisting` inherits from it and adds the extended persistence surface. Existing conformers therefore remain valid unless they explicitly opt into the full library contract.

New shared values are implementation-neutral `Codable` / `Hashable` / `Sendable` domain values only. No Core Data, SwiftData, SQLite, AVFoundation, file-provider, UI, or engine implementation type leaks into Shared.

## Added semantics

- durable project list/load via `PersistedProjectSnapshot`;
- versioned practice/mixer edits via `ProjectUserEdits`;
- stable setlist and entry IDs plus atomic ordered replacement contract;
- project deletion contract whose implementation must use idempotent tombstone/file cleanup internally;
- `ProcessingRecoveryPlan` to distinguish resumable backend jobs from retry-required interrupted jobs.

The contract intentionally does not add cloud sync, collaboration, account state, or analysis persistence before Reference/product evidence requires them.

## Validation

The new contract surface was independently typechecked by HQ using Swift with representative stubs for the already-integrated domain types. Result: exit 0, no diagnostics.

This is contract-surface validation only. Full package compilation against the exact integrated `DomainContracts.swift` and regression of the 13 existing tests is delegated to a build-harness follow-up task before `MOI-LIB-001` may start.

## PARITY

No PARITY row changes. MOI-P017 / P018 / P020 remain MISSING until implementation and relaunch/interruption/device evidence exist.
