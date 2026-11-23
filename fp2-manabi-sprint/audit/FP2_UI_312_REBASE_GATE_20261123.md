# FP2 UI coordinator 312 synchronization — 2026-11-23 JST

## Integration
- UI target branch: `feature/fp2-ui-master21-integration-20261123`
- Coordinator base head at read time: `302eda0d37baed5e470bc2816e84ad9c6bee8e13`
- Coordinator canonical file: `fp2-manabi-sprint/questions/canonical/approved-questions-20261123.json`
- Coordinator canonical Git blob SHA: `03b449dbe8a848b192bd970801846b18c486b1b4`.
- Rebase strategy: squash-replay UI-specific files over coordinator head on staging branch, then force-with-lease update UI-only ref. Do not modify coordinator/base branch. The coordinator canonical file is inherited unchanged; the old 65-question JSON is not copied forward.
- Bank load contract: 312 canonical question objects; selection target 300 and reserve target 12 are displayed as planning counts, not release authorization. Runtime throws if bank length is not 312, invalid IDs, duplicate records, missing answer data or explicitly failing/holding audit statuses. This adapter does not claim 312 questions are legally publishable.

## Gate results / limitations
- UI Master residual 4-item static gate executed with **synthetic 312-question fixture**: pass=true / failures=0 / 23 reported checks.
- Actual UI JavaScript, data adapter and service worker syntax validation: PASS.
- Adapter run with synthetic 312-question fixture: 312 loaded, 300 selection target, 12 reserve target, publishable=false.
- GitHub connector confirms real coordinator canonical blob exists (SHA above), but it returns an empty body for this large file. Therefore **real 312-question JSON structure, answer content and counts could not be independently parsed in this session**. Actual-bank-integrated gate is NOT TESTED, not PASS.
- Actual browser test: NOT TESTED (connected browser reports `Browser access requires the originating browser context`; container cannot connect to github.com). No Chrome, Safari, iPhone or offline runtime PASS asserted.

## Next required before SUBMISSION_READY
1. Run `node fp2-manabi-sprint/scripts/verify-ui-master21-migration.cjs` with a full checkout and real canonical data. Fix any actual schema mismatches and check 312/300/12 selection flags.
2. Serve FP2 app locally over HTTP and use real browser to check 312 load, 4/8/16, answer/source attribution, donut, 35-day heatmap, manifest/service worker installation and offline reload.
3. Validate release selection: 300 selected, 12 reserve, no reserves in production sessions, legal/rights attribution approved.
4. Execute 30-state Golden Master/iOS verification. All untested gates remain NOT TESTED.

No App Review, TestFlight or production branch updates.
