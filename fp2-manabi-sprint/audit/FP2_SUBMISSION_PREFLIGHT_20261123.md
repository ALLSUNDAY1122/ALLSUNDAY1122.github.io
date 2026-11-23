# FP2 submission preflight — 2026-11-23 17:32 JST

## Scope and rules
Independent branch: audit/fp2-submission-preflight-20261123 (based on feature/fp2-release-scope-20261123; PR #5717 unchanged).
Deadline: 2026-11-24 08:00 JST.
Notion standard v2.8: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
Notion submission procedure: https://app.notion.com/p/3b009c10697d81eba325f86d8af55481
No App Store submission; no App Store Connect login.

## Release Registry evidence
- App ID: 6797228406 (historical ASC readback, September 2026; user-specified).
- Bundle ID: com.allsunday1122.fp2manabisprint (historical ASC readback).
- Version / current build: UNKNOWN, requires current binary and Apple readback.
- IAP: UNKNOWN, requires source inspection and ASC product readback.
- automation/app-release-registry.json on product branch contains no fp2 entry; do not silently claim Registry resolved.
- September 5 historical ASC record lists builds 6 and 2, both EXPIRED; not evidence of current availability.

## Classification
| Check | Class | Finding / next step |
|---|---|---|
| Registry FP2 entry | AUTO-FIX | Add only after version/build/IAP evidence is resolved; avoid fabricated values |
| iOS CI/build | BUILD-REQUIRED (conditional) | User reports CI checked, but commit/build/upload/Apple VALID readback not independently established in this audit |
| Content bank and UI | BUILD-REQUIRED | PR #5717 describes scope-only, Q0–Q3 incomplete and merge prohibited; product status shows sample UI, not accepted production bank |
| App Privacy | AUTO-FIX / HUMAN-REQUIRED | Source-to-disclosure mapping and current ASC readback required |
| Store listing and review details | AUTO-FIX | Compare Japanese localization, age rating, review notes, export compliance with ASC |
| Support and privacy pages | AUTO-FIX | Confirm actual URLs and HTTP reachability; no assumptions |
| Screenshots | AUTO-FIX / HUMAN-REQUIRED | Verify durable canonical images, actual build correspondence and required device sizes |
| Internal TestFlight | HUMAN-REQUIRED | Apple VALID/group assignment readback and iPhone acceptance |
| Final approval | FINAL-APPROVAL | Exact App ID/version/build approval required only after submission preflight PASS |

## Decision
PREFLIGHT_BLOCKED / NOT SUBMISSION_READY. This audit has not independently established current Apple readback, approved production question bank, or device acceptance. No build/upload/submit was triggered. Do not infer current Apple status from September evidence.
