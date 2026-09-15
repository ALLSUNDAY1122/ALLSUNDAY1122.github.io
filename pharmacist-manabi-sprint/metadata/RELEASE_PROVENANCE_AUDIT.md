# RELEASE PROVENANCE AUDIT｜薬剤師国家試験｜学びスプリント

Updated: 2026-09-16 JST
Status: **PASS**

## Resolved platform provenance

Fresh connected platform readback resolves ASC Build `202609140032` to:

- TestFlight: `VALID`, `expired=false`, internal groups=1
- Codemagic workflow: `pharmacist-ios`
- Codemagic build index: 19
- source commit: `64a84197002bc3584d55483e8dc08c58dff67d4d`
- branch: `main`
- build start: 2026-09-14T00:31:25.165Z
- build finish: 2026-09-14T00:34:23.153Z

`64a84197002b..main` was compared after resolving the exact source commit. No post-build product-code/content change under `pharmacist-manabi-sprint/**` exists; the only later path entry is this provenance evidence file itself. Therefore Build `202609140032` contains the current accepted pharmacist product state and does not require a rebuild merely to refresh evidence.

## Remaining TestFlight #1 rule

Reuse this build only after the current no-IAP Static Gate / XCTest / iOS Preflight, Learning Acceptance, Visual Gate and Release Gate evidence remain PASS with P0=0, P1=0, unverified major journeys=0 and known display gaps=0. Human Test remains a Human Gate. Do not mutate IAP/ASC metadata or submit App Review automatically.
