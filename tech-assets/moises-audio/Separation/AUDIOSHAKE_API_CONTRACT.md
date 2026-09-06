# MOI-SEP-002｜AudioShake evaluation contract

Captured: 2026-08-22 JST
Scope: Worker-1 Separation only. This is an evaluation/unblock contract, not a commercial approval or PARITY claim.

## Current official developer surface verified

Official AudioShake developer documentation currently establishes:

- API base: `https://api.audioshake.ai`.
- Authentication: `x-api-key`; key is created in the AudioShake Dashboard and must remain server-side in this project architecture.
- New self-service accounts advertise 10 starter credits.
- Local media is uploaded with `POST /assets` multipart upload; current documented maximum asset size is 2 GB.
- Uploaded Assets expire after 72 hours.
- Separation is asynchronous via `POST /tasks` followed by `GET /tasks/{id}`.
- A Task accepts up to 20 model targets.
- Current core instrument models include `vocals`, `drums`, `bass`, `other`, and `instrumental`; WAV output is supported.
- Current model table prices the core stem targets at 1 credit per audio minute per target. A four-target vocals/drums/bass/other run therefore consumes 4 credits per input minute under the currently published model pricing.
- Completed target output links expire after one hour, so the project backend must promptly copy results to project-controlled storage rather than persisting vendor URLs.
- Current public Task API documentation exposes create/get/status behavior. No authoritative Task cancellation endpoint was found in the current public reference captured for this task; product cancellation must not pretend upstream compute was cancelled unless a superseding API/contract confirms it.

Official sources captured:

- https://developer.audioshake.ai/api-reference/authentication
- https://developer.audioshake.ai/quickstart
- https://developer.audioshake.ai/api-reference/assets/upload
- https://developer.audioshake.ai/api-reference/tasks/create
- https://developer.audioshake.ai/api-reference/tasks/get
- https://developer.audioshake.ai/separate-stems
- https://developer.audioshake.ai/models

## Implemented project-side adapter

`Separation/Server/audioshake_api.py` provides a server-only adapter that:

- rejects non-HTTPS API endpoints;
- rejects malformed/API-key header injection;
- streams multipart asset upload instead of reading a long track fully into RAM;
- enforces the documented 2 GB asset boundary before network transfer;
- creates exact WAV targets for vocals/drums/bass/other or the approved core subset;
- limits metadata to the documented 4096-byte Task metadata boundary;
- maps `processing / completed / error` target states into stable project-side state;
- refuses completed targets without HTTPS WAV output;
- does not expose the vendor API key to the iPhone client.

`Separation/Tests/test_audioshake_api.py` covers the fail-closed contract.

Local reconstructed-readback verification on Python 3:

- `py_compile`: PASS.
- AudioShake adapter contract tests: 10 executed, 0 failures.
- This verification uses no live credentials and therefore proves no separation quality, latency, cost, retention behavior, or production entitlement.

## iOS Local Inference SDK path

Current official AudioShake SDK documentation also confirms:

- native iOS ARM64 support;
- Metal / Neural Engine backend support on iOS;
- encrypted model files supplied by AudioShake;
- Client ID + Client Secret required;
- `SourceSeparationTask` file-to-file wrapper with progress callback / `getProgress()`;
- lower-level `AudioShakeSeparator` buffer processing;
- current product material describes joint 4-stem / 6-stem and additional instrument targets.

This makes a staged path technically credible:

1. evaluate cloud API quality quickly;
2. if quality and commercial/privacy terms pass, compare production server API vs licensed Local Inference SDK on target iPhone;
3. do not change the SEP-001 server baseline without HQ review and measured evidence.

Official SDK sources:

- https://developer.audioshake.ai/sdk/overview
- https://developer.audioshake.ai/sdk/api-reference
- https://www.audioshake.ai/products/sdk

## Remaining Human / external gates

Before live AudioShake evidence can count toward MOI-SEP-002:

1. Create/authorize an AudioShake developer account and obtain an API key outside the public repository.
2. Confirm current commercial terms for embedding the service in the intended consumer product, including user-audio handling, retention/deletion, confidentiality, outputs, production pricing/limits and geographic/privacy requirements.
3. Provide rights-cleared G1/G2 real-audio fixtures under the Golden QA contract.
4. Execute actual four-stem runs and persist the expiring outputs under project-controlled storage.
5. Measure quality/listening, latency, failure/retry and actual cost.
6. Determine whether logical cancellation (stop polling/discard output) is sufficient or whether an upstream compute-cancel mechanism is contractually/API available. Do not claim upstream cancellation without evidence.

## PARITY impact

None. MOI-P003 / MOI-P004 remain MISSING until real multi-genre inference and differential quality evidence exist.
