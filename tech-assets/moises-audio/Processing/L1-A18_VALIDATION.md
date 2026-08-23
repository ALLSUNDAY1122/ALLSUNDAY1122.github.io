# L1-A18 Validation — Privacy-Safe Observability / Evidence Telemetry

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Keep enough production/PARITY diagnostics to reproduce separation failures and performance behavior without turning telemetry into a second copy of user media, provider secrets or signed delivery credentials.

A18 therefore uses a fixed allowlist evidence envelope rather than arbitrary events, dictionaries or free-text logs.

## Existing Lane 1 inputs reused

A18 composes prior evidence sources instead of duplicating them:

- A09: privacy/deletion lifecycle and restricted diagnostics.
- A10: estimated/actual cost accounting.
- A15: bounded transfer byte/time telemetry.
- A17: stable fault codes and recovery categories.
- A06/A14: committed output role/hash/byte identity.

## Implementation

### `Separation/Server/privacy_safe_observability.py`

The durable `PrivacySafeObservability` envelope records only bounded, typed fields:

- domain-separated SHA-256 job reference;
- profile ID and target count;
- provider kind, model and version identifiers;
- currency, estimated cost and optional actual cost;
- source byte count and duration in milliseconds;
- fixed processing phase aggregates;
- stable error code;
- artifact role, SHA-256 and byte count;
- terminal state.

The raw logical job ID itself is never serialized. `job_ref_hash` is derived as SHA-256 of a Lane-1-specific domain prefix plus logical job ID, avoiding a direct reusable identifier in the evidence file.

### Phase aggregation

Allowed phases are fixed:

`intent`, `storage_preflight`, `upload`, `provider_create`, `poll`, `output_download`, `artifact_validate`, `staging`, `promotion`, `ledger_commit`, `recover`, `delete`.

Each phase stores only:

- attempts;
- actual retry count;
- elapsed milliseconds;
- bytes transferred;
- failure count;
- last stable error code.

A17 `operation_retryable=true` does **not** increase retry count. A retry is counted only when the caller explicitly records an actual retry. This prevents telemetry from overstating production retries.

## Privacy boundary

The evidence schema intentionally cannot persist:

- API key, Authorization header, token or secret;
- raw audio or arbitrary bytes;
- user filename or filesystem path;
- signed output/download URL;
- provider asset/task operational ID;
- raw idempotency key;
- raw logical job ID;
- free-text exception message;
- arbitrary metadata dictionaries.

Defense-in-depth validation scans the fully serialized payload before write. Forbidden key patterns and URL/credential-like string values fail closed rather than being silently retained.

Corrupt or schema-injected evidence records also fail closed on reload.

## Explicit safe bridges

A18 never serializes existing subsystem objects wholesale.

- **A15 long-track bridge** copies only aggregate upload/download bytes, elapsed milliseconds and stable error code.
- **A10 cost bridge** consumes only actual cost from the existing privacy-safe evidence shape. Registration already carries estimate/currency/duration/target count.
- **A17 fault bridge** copies only the stable error code. Raw exception text and vendor diagnostic bodies are not accepted.
- **A06/A15 output bridge** consumes only output `model`, `sha256`, and `bytes`. Fields such as `relative_path`, project/asset IDs, provider IDs and request fingerprints are ignored.

This boundary matters because upstream records legitimately contain operational identifiers needed for processing but unnecessary for observability.

## Artifact evidence

Artifact telemetry stores canonical role/model label plus SHA-256 and byte count only. It does not store artifact paths or signed vendor URLs.

Conflicting evidence for the same role fails closed rather than overwriting an earlier artifact identity.

## Deletion lifecycle

A18 was audited against A09 deletion semantics.

- a completed/failed/unknown record may later transition to `deleted` when user/project/account deletion occurs;
- `deleted` is a non-resurrectable telemetry tombstone;
- a deleted record cannot transition back to ready/failed/active.

This avoids the original over-restrictive design where `ready -> deleted` would have been rejected.

Actual artifact/provider deletion confirmation remains A09/A14-owned; A18 records observability state only.

## Durable storage

The lane-local store uses:

- advisory process lock;
- temporary file write;
- `fsync`;
- atomic replace.

This is suitable as lane-local single-host evidence infrastructure. It is **not** a horizontally scaled/multi-host transactional telemetry guarantee. HQ must select an equivalent shared transactional sink if production runs multiple independent writers.

## Machine verification

Executed against the final A18 implementation:

- privacy-safe observability/redaction/evidence tests: **35 / 35 PASS**;
- `py_compile` for implementation and test: **PASS**.

Coverage includes:

- raw logical ID hashing/no serialization;
- idempotent registration and identity conflict rejection;
- phase timing/bytes/retry aggregation;
- actual retry vs retryable distinction;
- stable-code-only failures;
- artifact hash capture/conflict rejection;
- actual-cost idempotency/conflict behavior;
- ready -> deleted lifecycle and deleted tombstone no-resurrection;
- A15 aggregate bridge;
- A10 cost bridge with sensitive extra fields ignored;
- A17 stable fault bridge;
- forbidden API keys/secrets/tokens/authorization;
- URL/signed URL/file URL rejection;
- raw bytes rejection;
- corrupt store and injected-field rejection;
- A06 output bridge proving relative paths/provider IDs/private filenames are not persisted;
- currency/non-finite cost validation;
- machine-readable schema assertions.

Machine-readable specification/evidence:

`Processing/Tests/L1-A18_OBSERVABILITY_MATRIX.json`

## Production integration contract

At Late Integration, telemetry must be populated through these explicit safe APIs/bridges only. Do not pass arbitrary provider exception objects, provider response dictionaries or complete `JobRecord` objects into a generic logger.

The expected production processing chain remains:

`concrete provider -> A17 fault normalizer -> A15 long-track instrumentation -> A10 budget guard -> A06/A07 lifecycle -> A16 reconnect facade`

A18 observes that chain at explicit boundaries without changing retry/cancel/commit semantics.

## Remaining gaps

A18 does not prove P024 PARITY by itself. Still required:

- HQ selection of production telemetry backend, access controls and evidence retention period;
- deletion/account-flow coverage that includes the deployed telemetry sink;
- live provider payload aliases, Retry-After and actual cost reconciliation;
- integrated iPhone processing/relaunch diagnostics and privacy review;
- rights-cleared real-audio, real provider and current-iPhone differential evidence.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

`MOI-P024` remains `MISSING`. A18 provides the server-side telemetry privacy mechanism needed for that gate, but integrated storage/deletion/account behavior and final HQ evidence are still absent. `MOI-P020` and `MOI-P021` also remain `MISSING`; A18 improves their diagnostics but does not provide real-device evidence.
