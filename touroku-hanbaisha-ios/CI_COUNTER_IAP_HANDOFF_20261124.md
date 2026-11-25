# Counter and IAP CI repair
- Reapply d035d2b5 to current main on dedicated branch; no direct main writes.
- Offline regression: explicitly test free 50, 10/chapter, score, resume, simulated entitlement grant/revoke, then all 599. Mock entitlement is not StoreKit purchase evidence.
- Preflight: checkout triggering SHA; read-only permissions; remove all git commit/rebase/push and obsolete status overwrites; upload run artifact; retain enforcement of blocked gates.
- ASC IDs verified; metadata/price/trial and actual purchases pending.
- 2022 explanation commit 7c0312ff: release validation success; visual cancelled; unrelated workflows failed. Independent review pending.
- No explanation authoring, no review submission. CI pending; merge only after relevant checks.
