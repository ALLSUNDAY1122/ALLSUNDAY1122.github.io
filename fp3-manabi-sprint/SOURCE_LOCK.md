# FP3級｜学びスプリント Source Lock

Updated: 2026-11-24 (local backup branch `fp3-300q-backup`; 2023 explanation audit fixes)

## Canonical product definition

- Product: FP3級｜学びスプリント
- Canonical UI/interaction reference: FP2級｜学びスプリント v1.3 common UI defined in Notion.
- Canonical question bank (this branch): 300 official past questions (2023-05, 2023-09, 2024-05, 2025-05, 2026-05).
- Normal learning pool: 295 questions (`active_core`).
- Legacy/old-regime isolated: 5 questions (`archived_law_changed`).
- Payload file: `question_bank_300.payload.json`
- Canonical validation SHA-256 for `question_bank_300.payload.json`: `deceb3943286559cc9e087af4cbc4c2845caa6fc09b00c477a5468146c9e1690`.
- Payload bytes: 409279.
- Manifest: `question_bank_300.json`.
- Previous 180-question payload is retained as `question_bank_180.payload.json` for rollback only. Do not ship it as the product bank on this branch.

## Prohibited source

Do not ship or use the legacy `fp3-12mon-knock` 600-question bank/UI as the product source. It is reference-only. The product must not silently fall back to the old 600-question dataset.

## Required bootstrap order

1. Materialize or verify the 300-question payload and confirm its locked SHA/data counts before integration.
2. Port the FP2 v1.3 common UI shell rather than extending the legacy FP3 UI.
3. Connect the FP3-specific question types, six domains, year filters, 12-question balanced sprint, 60-question mode, legal-change isolation and free/premium filtering.
4. Verify the learning loop: Home → 12 questions → immediate feedback → Result → weak review/retry.
5. Run AI Preflight, category Quality Pack and Acceptance Contract before any TestFlight build.

This file exists to prevent future runs from confusing the legacy 600-question prototype with the canonical product implementation.
