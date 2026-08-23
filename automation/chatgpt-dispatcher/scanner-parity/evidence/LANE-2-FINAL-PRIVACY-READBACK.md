# LANE-2 Final Privacy Read-back

- worker: `worker2`
- branch: `scanner-parity/worker2-privacy-finalgate`
- base: latest `scanner-parity/integration`
- final Privacy decision owner: HQ Release Gate

## Canonical product read-back

Latest integration includes the post-composition ProductFlow/AppShell lifecycle hardening (`52e7d4da999b78414786e2e183b4e57d262e9290`). The integrated implementation now satisfies the privacy lifecycle invariants previously raised by Worker2:

1. active imported media is app-managed and backup-excluded;
2. active processing workspace is backup-excluded and resumable;
3. terminal completion promotes only the final BookPackage to managed `Completed/<bookID>` staging;
4. terminal checkpoint schema v3 retains only final package URL, review metadata and page count;
5. raw managed input and full per-book processing workspace are explicitly purged after terminal completion is safely persisted;
6. managed Completed staging is removed when export/session retention ends;
7. unused camera authorization/API/UI was removed from the AppShell input flow.

The real iOS application target and app-level privacy resources were separately integrated by HQ release preparation. No Golden status is involved in this assessment.

## Worker2 final gate hardening

The lifecycle gate was already present on latest integration. This final Worker2 delta tightens it without changing product code:

- all `privacyRisk` findings, like egress findings, are non-bypassable by allowlist;
- processing-workspace safety requires an explicit named cleanup boundary (`purgeProcessingWorkspace` or equivalent), rather than accepting any incidental `removeItem` token;
- fixtures explicitly cover a camera-free product, camera-with-purpose-string, missing purpose string, missing backup exclusion, missing import purge, missing workspace purge, and a false-positive generic `removeItem` case.

## Expected final acceptance

The branch must pass the repository `Scanner Parity Apple Validation` workflow. In particular the same checked-out tree must show:

- privacy static fixtures PASS;
- lifecycle fixtures PASS;
- integrated `run-lane2-privacy-gate.sh` marker `LANE2_PRIVACY_GATE=PASS`;
- final product/iPhoneOS compile PASS;
- real iOS app bundle validation PASS when the release workflow includes it.

Only after that same-head read-back may HQ mark final Privacy PASS. Golden Dataset SHA or real-book Golden metrics remain a separate HQ Gate.
