# L1-A09 Validation — Retention / Deletion / Privacy Enforcement

Captured: 2026-08-23 JST
Worker: `Moises-Worker-1`
Branch: `moises/wp1-separation-processing`
Result: `COMPLETE_NON_PARITY`

## Goal

Enforce a privacy-safe retention/deletion lifecycle for separation-controlled artifacts and diagnostics without claiming vendor erasure that cannot be proven.

## Current provider facts used

AudioShake public developer documentation was re-read on 2026-08-23.

- Upload File documents that uploaded Assets expire after 72 hours.
- Quickstart documents that completed Task output download links expire after one hour and should be copied to customer-controlled storage.
- The current public Developer Docs index lists Asset GET/LIST/UPLOAD and Task CREATE/GET/LIST/statistics/webhooks, but no public Asset/Task DELETE endpoint.
- AudioShake's public privacy policy describes retention in necessity/legal-purpose terms rather than promising immediate deletion of all API Task metadata.

References:
- https://developer.audioshake.ai/api-reference/assets/upload
- https://developer.audioshake.ai/quickstart
- https://developer.audioshake.ai/llms.txt
- https://www.audioshake.ai/privacy-policy

These facts are encoded conservatively: documented expiry is evidence of expiry only. It is not promoted to synchronous deletion or complete provider erasure.

## Implementation

### `Separation/Server/privacy_retention.py`

- atomic privacy registry with durable delete intent;
- provider asset/task identifiers are stored only as SHA-256 hashes;
- no source path, filename, vendor output URL, user metadata, or free-form content is required by the registry;
- default AudioShake retention profile records 72-hour Asset TTL and one-hour output-link TTL;
- local retention supports `until_project_delete`, `manual_delete`, or explicit expiry;
- local deletion is restricted to the exact logical-job directory beneath the configured separation artifact root;
- deletion is confirmed only after the job directory is absent;
- explicit-expiry sweeping cannot remove sibling job directories;
- provider deletion is optional-capability based (`delete_asset`, `delete_task`);
- `accepted` is not treated as `confirmed`;
- unsupported, missing identifier, invalid receipt, or provider error all remain visibly incomplete;
- repeated provider deletion is locally idempotent;
- overall deletion completion requires local confirmation plus authoritative provider asset/task deletion confirmation (or equivalent not-found result);
- documented Asset TTL can surface `expired`, but Task erasure remains unknown unless independently confirmed;
- diagnostic persistence is strict allowlist-only and rejects URLs, paths, filenames, arbitrary messages, metadata and content-bearing free text;
- outward privacy snapshot contains no raw provider IDs, paths, URLs or filenames and remains `NON_PARITY_EVIDENCE_ONLY`.

### Ownership boundary

Lane 1 deletes only artifacts beneath its configured separation artifact root. The original app/library source asset remains Lane 2 / HQ integration ownership and is never removed by this module.

## Machine verification

Local reconstruction against the exact implementation written to the branch:

- Python `py_compile privacy_retention.py test_privacy_retention.py`: PASS
- `test_privacy_retention.py`: 25 tests, 0 failures

Key cases include:

1. documented 72h/1h TTLs;
2. registry contains no raw provider IDs, source path or URL;
3. registration idempotency/conflict;
4. delete-intent-before-provider-contact ordering;
5. local directory absence required for confirmation;
6. confirmed-vs-accepted provider receipts;
7. provider delete capability absent;
8. provider delete error;
9. repeated delete idempotency;
10. provider identifier mismatch blocks destructive call;
11. asset expiry does not claim Task erasure;
12. output-link expiry visibility;
13. diagnostic allowlist;
14. URL/path/free-text diagnostic rejection;
15. explicit local-expiry sweep isolation;
16. until-project-delete retention;
17. registry relaunch recovery;
18. corrupt registry fail closed;
19. invalid retention-policy combinations;
20. invalid provider receipt;
21. sanitized public snapshot.

Scenario ledger: `Processing/Tests/L1-A09_PRIVACY_MATRIX.json`.

## Remaining external/live evidence

This Wave does not prove:

- commercial/privacy/DPA approval for the selected production provider;
- actual AudioShake production-account retention behavior beyond documented Asset/link expiry;
- provider Task-metadata erasure or deletion because no public current Tasks DELETE endpoint is documented;
- account-deletion semantics;
- live user-content deletion across the integrated iOS app, backups, analytics and support systems;
- real-device `MOI-P024` parity.

HQ must require production terms/DPA plus live deletion evidence before promoting P024.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

A09 materially closes the Lane 1 machine-enforcement gap for P024 but does not satisfy P024 without integrated privacy/account paths and authoritative vendor deletion/retention evidence.
