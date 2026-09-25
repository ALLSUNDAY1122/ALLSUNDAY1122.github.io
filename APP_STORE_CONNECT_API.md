# App Store Connect API common contract

This repository uses the same Apple Team API Key policy as APP FACTORY 100. The Apple account credential may be shared, but app-specific identifiers and release state must remain separated per app.

## API-first policy

When an official API, CLI, or CI path supports an operation non-interactively, use it instead of browser hand-entry by default. The standard execution pattern is:

1. Read the current remote state.
2. Resolve the target by its canonical App Store Connect App ID / Bundle ID / Version / Product ID.
3. Compare with the app's source-of-truth state.
4. Execute an allowlisted semantic operation.
5. Read the remote state back and verify the intended transition.
6. Persist only non-secret evidence and status.

Prefer API/CI for App Store Connect metadata and localizations, versions and build relationships, TestFlight groups/testers/builds, screenshots/app previews, review details, IAP/subscriptions, provisioning resources, customer reviews/responses, and available reports when the current Apple API and key role permit them.

Do not expose a generic arbitrary-write gateway. Write operations must be implemented as named/allowlisted release actions with target validation and idempotency. Final App Review submission, production release, destructive deletion, contracts/payment/tax/banking and identity verification remain human gates even when an API technically exists.

## Canonical release registry

`automation/app-release-registry.json` is the machine-readable registry for release operations. It binds each supported app to its canonical Bundle ID, Apple-issued App Store Connect App ID when available, APP2 task where applicable, and read-back eligibility.

Release tooling must not maintain a second hard-coded app list when the registry can be used instead. Before any build, upload, TestFlight assignment, metadata write, IAP write, or App Review submission:

1. Resolve the registry entry.
2. Cross-check Bundle ID and App Store Connect App ID against the authoritative Notion identification page and current App Store Connect state.
3. Refuse to guess a missing Apple App ID. An unresolved Apple ID remains `apple_id_pending` / `UNKNOWN` until Apple has actually issued it.
4. Abort on duplicate App IDs, duplicate Bundle IDs, or APP2 task collisions.

`scripts/app_release_registry_audit.py` validates these invariants. `.github/workflows/app-release-registry-audit.yml` enforces them when the registry or common release tooling changes.

## Verified release-state contract

Build, upload, TestFlight, and App Review are separate states. A successful CI job or a started submit script is not proof that Apple accepted the transition.

Use these normalized release states when reporting progress:

`BUILDING → BINARY_UPLOADED → APPLE_PROCESSING → BUILD_VALID → TESTFLIGHT_READY → SUBMISSION_READY → WAITING_FINAL_APPROVAL → SUBMITTING → WAITING_FOR_REVIEW → IN_REVIEW → APPROVED/REJECTED → RELEASED`

If a required remote read fails, report `UNKNOWN` and isolate the failing layer. Do not label an unknown state as "Apple processing" or "Apple waiting".

App Review submission is complete only after App Store Connect read-back confirms `WAITING_FOR_REVIEW` or a later review state. Production release is complete only after the release state itself is read back and, when required, the App Store listing is externally visible.

Temporary GitHub Actions or Codemagic artifact URLs must not be the only canonical source for screenshots, previews, or submission metadata. Those assets must be stored durably or reproducible deterministically.

## Secret contract

Provide credentials only through a secure secret store or a local environment. Never commit or paste the credential values into GitHub files, Notion, issues, pull requests, or chat logs.

Required variables:

- `ASC_ISSUER_ID`
- `ASC_KEY_ID`
- `ASC_PRIVATE_KEY` — full contents of the downloaded `.p8` private key

Local-only alternative:

- `ASC_PRIVATE_KEY_PATH` — path to the downloaded `.p8` file. When this is set, `ASC_PRIVATE_KEY` is not required.

## Connection and read gateway

```bash
python3 scripts/app_store_connect_api.py
```

The default request is `GET /v1/apps?limit=1`. The script creates a short-lived ES256 JWT and does not print the JWT or credential values.

`.github/workflows/app-store-connect-api-gateway.yml` provides the current bounded read gateway. It is intentionally read-only until each write capability is added as a semantic allowlisted action.

For cross-app release status, use `scripts/app_factory_release_readback.py`. It reads the canonical release registry, skips unresolved Apple IDs instead of guessing them, and persists read-only evidence for each registered app.

## Safety boundaries

- Keep `.p8`, Issuer ID, Key ID and JWT out of committed files and logs.
- Use the API for automation only after the target app is resolved by its own Bundle ID / App Store Connect App ID.
- Do not infer or reuse another app's identifiers.
- Final App Review submission, production release, destructive deletion, contracts, payment, tax/banking and identity verification remain human gates under the release procedure.
- Revoke and rotate the Team API Key if exposure is suspected.

## Codemagic

Codemagic REST API access is available through the GitHub Actions secret `CM_API_TOKEN`. The ChatGPT/GitHub build gateway may start and monitor allowlisted `codemagic.yaml` workflows through the Codemagic REST API. It must never use a workflow configured to submit directly to App Store review.

Existing `app_store_connect` integration names in `codemagic.yaml` are not changed merely because the API key exists. Repoint a production build only after the integration is validated and the app-specific workflow is rechecked.

## Expo / EAS

Expo/EAS automation uses `EXPO_TOKEN` from GitHub Actions secrets. For linked EAS projects, CI may run non-interactive EAS Build and EAS Submit/TestFlight flows. App Store listing metadata and Apple-side release state should still be read back from App Store Connect and reconciled with the app source of truth.
