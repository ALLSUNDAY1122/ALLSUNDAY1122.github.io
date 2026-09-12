# FP3級｜学びスプリント Source Lock

Updated: 2026-09-12

## Canonical product definition

- Product: FP3級｜学びスプリント
- Canonical UI/interaction reference: FP2級｜学びスプリント v1.3 common UI defined in Notion.
- Canonical question bank: audited FP3 v1.1.0, 180 official past questions (2024/2025/2026, 60 each).
- Normal learning pool: 178 questions.
- Legacy/old-regime isolated: 2 questions.
- Canonical validation SHA-256 for `question_bank_180.json`: `cd8d74902d5194ebfe471fd5f4618192e9af33cf9312944aff13877ec85b1ec9`.
- Google Drive canonical integrated reference: `FP3_KAKOMON_COACH_v1.1.0.html`, file id `1iqk3OO4uVDNPe_orfpyksoYwNSAXwnkk`, observed size 263111 bytes on 2026-09-12 fresh read.

## Prohibited source

Do not ship or use the legacy `fp3-12mon-knock` 600-question bank/UI as the product source. It is reference-only. The product must not silently fall back to the old 600-question dataset.

## Required bootstrap order

1. Materialize the audited v1.1.0 180-question source and verify its locked SHA/data counts before integration.
2. Port the FP2 v1.3 common UI shell rather than extending the legacy FP3 UI.
3. Connect the FP3-specific question types, six domains, year filters, 12-question balanced sprint, 60-question mode, legal-change isolation and free/premium filtering.
4. Verify the learning loop: Home → 12 questions → immediate feedback → Result → weak review/retry.
5. Run AI Preflight, category Quality Pack and Acceptance Contract before any TestFlight build.

This file exists to prevent future runs from confusing the legacy 600-question prototype with the canonical product implementation.