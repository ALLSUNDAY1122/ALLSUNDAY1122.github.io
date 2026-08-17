# App Store Connect API common contract

This repository uses the same Apple Team API Key policy as APP FACTORY 100. The Apple account credential may be shared, but app-specific identifiers and release state must remain separated per app.

## Secret contract

Provide credentials only through a secure secret store or a local environment. Never commit or paste the credential values into GitHub files, Notion, issues, pull requests, or chat logs.

Required variables:

- `ASC_ISSUER_ID`
- `ASC_KEY_ID`
- `ASC_PRIVATE_KEY` — full contents of the downloaded `.p8` private key

Local-only alternative:

- `ASC_PRIVATE_KEY_PATH` — path to the downloaded `.p8` file. When this is set, `ASC_PRIVATE_KEY` is not required.

## Read-only connection check

```bash
python3 scripts/app_store_connect_api.py
```

The default request is `GET /v1/apps?limit=1`. The script creates a short-lived ES256 JWT and does not print the JWT or credential values.

A manual GitHub Actions workflow is provided at `.github/workflows/app-store-connect-api-check.yml`. It runs only when explicitly dispatched, so repositories without secrets configured do not fail on normal pushes or pull requests.

## Safety boundaries

- Keep `.p8`, Issuer ID, Key ID and JWT out of committed files and logs.
- Use the API for automation only after the target app is resolved by its own Bundle ID / App Store Connect App ID.
- Do not infer or reuse another app's identifiers.
- Final App Review submission, contracts, payment, tax/banking and identity verification remain human gates under the release procedure.
- Revoke and rotate the Team API Key if exposure is suspected.

## Codemagic

Existing `app_store_connect` integration names in `codemagic.yaml` are intentionally not changed by this setup. Repointing a production build to a new Codemagic integration is allowed only after the same Team API Key has been registered in Codemagic's secure App Store Connect integration store and a read-only credential check has passed.
