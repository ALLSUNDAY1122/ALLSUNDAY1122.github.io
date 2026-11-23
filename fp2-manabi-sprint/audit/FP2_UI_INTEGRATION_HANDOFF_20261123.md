# FP2 UI integration handoff | 2026-11-23

## Scope
- Branch: `feature/fp2-ui-master21-integration-20261123`; do not merge or write to the product branch as part of this UI task.
- Source bank: `questions/canonical/approved-questions-20261123.json` copied verbatim from `feature/fp2-release-scope-20261123` at blob `6d1a4a97b4874d9e27ca7206c0fc6264e0e4cedc`.
- The source bank has 65 content-review PASS questions, of which **0 are publishable**; `CONTENT_AUDIT_PASS_RELEASE_BLOCKED` is intentional. Never call these 65 release-approved without a separate Q0 rights/law gate.

## UI changes
- `fp2-approved-bank.js` loads only the canonical file, validates the stated count, unique IDs, answer_index, schema, and filters `approved_for_content_bank: true` plus `independent_audit_status: PASS`.
- All embedded 8 sample questions, legacy v1.3 descriptions and 600-fixed-language removed.
- `index.html` dynamically reads 65 preview questions. Source details after answer: source organization, source section, canonical source URL, modification status (unknown remains unknown), original and target law date, release gate. Dynamic 4-tab navigation (home/mock/history/settings).
- Added daily progress ring, goal 4/8/16, 35-day activity heatmap, optional exam-date countdown and per-day pace, JSON export/import with confirmation, day/seen metadata. Legacy localStorage not migrated automatically.

## Evidence and testing
- GitHub re-fetch confirms the bank is present, two JS sections pass V8 syntax validation.
- Executed the actual adapter with mocked fetch returning the canonical JSON: 65/65 passed, first answer index and source URL verified, and public release state false.
- Executed the actual HTML inline JS in a simulated DOM: 65 loaded, eight-question sprint started, one correct answer submitted, one daily count stored, a source hyperlink produced, 35 heatmap cells rendered, exam-day setting saved and countdown computed, export button handler present.
- **Browser/E2E on real Chromium/iPhone: NOT TESTED.** Browser connector unavailable in this session; simulated DOM cannot establish real browser behavior. JSON export/import browser downloads and iOS Files integration not validated.
- UI Master v2.1 visual fidelity/30 screenshot state audit: NOT TESTED.

## Coordinator integration / blockers
1. Content bank cannot be publicly shipped until 50 recovered `modified=null` records are checked against source PDFs and rights/2026 law gates cleared. Do not replace null with false.
2. Reconcile UI branch against product branch; keep canonical data single-source, avoid copying bank multiple times during merge.
3. Browser smoke: serve `fp2-manabi-sprint/` over HTTP, test network load 65, 8-question start, select correct/wrong/unknown, source URL and modification metadata, 4/8/16 controls, reload persistence, 35-cell heatmap, exam countdown, export/import and mobile layout.
4. Remaining UI Master v2.1: exact Golden Master visual fidelity, 82px ring screenshot verification, shuffle settings, mock exam full group by exam x subject, achievement donut, 3-week/5-week history breakdown, PWA service worker/offline, iOS 30-state acceptance, UI screenshot comparisons.
5. This work changes neither App Review nor TestFlight status.

## Gates
- Content review: PASS 65/65 (based on source evidence only)
- Final rights/law/release: BLOCKED
- Adapter synthetic integration: PASS
- Browser E2E: NOT TESTED
- UI Master v2.1 full compliance: FAIL / incomplete
- SUBMISSION_READY: NO
