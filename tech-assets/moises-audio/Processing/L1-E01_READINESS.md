# L1-E01 Readiness — Commercial Route Approval / Credential

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`

Engineering readiness: `READY_PENDING_EXTERNAL_INPUT`  
Live gate: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Roadmap acceptance

The Lane 1 roadmap requires L1-E01 to receive:

- a production/evaluation credential for AudioShake or an equivalent provider;
- written terms allowing use in the intended consumer application;
- retention, deletion, confidentiality, output-use, pricing and region conditions.

Acceptance requires that the secret never enters GitHub or the iPhone client, and that exact provider/model/version/terms references are fixed in evidence.

Those external materials have not been supplied. L1-E01 is therefore not marked complete. This is a pending live-gate input condition, not `BLOCKED_HUMAN` and not a PARITY result.

## Implemented readiness gate

`Separation/Server/commercial_route_approval.py` converts a private approval package into sanitized evidence.

The private manifest must bind:

- provider ID and provider kind;
- production account tier and contracted region;
- a physical provider capability-snapshot document and SHA-256;
- every approved model name, exact model version, quality profile and canonical role set;
- server-side credential environment-variable names only;
- commercial-use approval;
- privacy/retention/deletion approval;
- confidentiality approval;
- output-use/export approval;
- pricing/billing approval;
- effective and expiry dates;
- operational retention/URL-TTL/delete semantics and pricing configuration.

The five terms documents and provider capability snapshot are read from a private documents root. Paths may not escape that root or traverse symlinks, and their bytes must match the declared SHA-256.

## Credential boundary

Credentials are accepted only through server-side environment variables.

The approval manifest cannot contain credential values. Unknown fields fail closed, so adding an `api_key`, token or secret field is not silently tolerated.

When a credential is present and `--repository-root` is supplied, the validator performs a streaming exact-byte scan across repository files (excluding `.git`). If the credential value is found anywhere in repository content, the gate fails with `L1E01_SECRET_FOUND_IN_REPOSITORY`.

The scan is chunked and tests include a credential spanning a 1 MiB chunk boundary.

No credential value, credential length or credential hash is written to sanitized evidence. Only environment-variable names and presence booleans are retained.

## Commercial/privacy fail-close rules

The route cannot become live-ready unless all of these are true:

- intended consumer-app commercial use is approved;
- provider input handling is confidential under the approved route;
- commercial use of provider outputs is approved;
- export of those outputs to the end user is approved;
- provider training on user content is disabled for the selected route.

Delete API availability and confirmation semantics must agree. Retention and output-link TTL values must be positive integers when contractually specified.

These controls are deliberately stricter than merely having a working API key. A credential without usable commercial/privacy terms does not pass E01.

## Pricing boundary

The private manifest requires an approved currency, billing unit, unit price and minimum charge so the A10 production budget guard can later be configured from authoritative values.

The sanitized evidence does **not** expose the numeric price. Instead it records:

- currency;
- billing unit;
- `pricing_config_sha256`;
- `operational_policy_sha256`;
- the SHA of the private pricing terms document.

A pricing mutation therefore changes the evidence identity without publishing confidential pricing numbers.

## Provider/model/version binding

The gate does not accept a provider name alone.

A private capability snapshot file is SHA-verified, and the sanitized result records the approved:

- provider ID/kind;
- account tier/region;
- capability snapshot SHA;
- exact model name;
- exact model version;
- quality profile;
- canonical role coverage.

Model ordering is canonicalized so ordering alone does not change approval identity, while any semantic model/version/quality change does.

## Sanitized evidence

The generated evidence intentionally omits:

- API keys, tokens and secrets;
- private contract document paths;
- raw contract text;
- raw approval record IDs;
- numeric unit-price/minimum-charge values;
- user audio or filenames;
- provider signed URLs.

Raw approval record IDs are domain-separated hashes; private document bytes are represented by SHA-256.

Schemas:

- `Separation/Evaluation/schemas/commercial-route-approval-private.schema.json`
- `Separation/Evaluation/schemas/commercial-route-evidence.schema.json`

Private manifest template:

- `Separation/Evaluation/examples/commercial-route-approval.private.template.json`

The template intentionally contains placeholders and cannot pass a real E01 gate until replaced with actual approved documents, hashes, dates, model/version data and pricing values.

## Machine verification

Lane-local final semantics:

- fault/privacy/identity cases: **30 / 30 PASS**;
- `py_compile` for implementation/test source: **PASS**;
- real credential used: **no**;
- real provider called: **no**;
- real contract documents used: **no**.

Coverage includes document/capability SHA mutation, missing/expired/future terms, commercial/output permission rejection, provider-training rejection, server-only credential rules, model-version identity, delete/retention consistency, pricing format, traversal/symlink defense, exact-secret repository leak detection, chunk-boundary leak detection, output redaction and deterministic identity.

Machine-readable matrix:

- `Processing/Tests/L1-E01_COMMERCIAL_ROUTE_MATRIX.json`

Checked-in regression suite:

- `Separation/Tests/test_commercial_route_approval.py`

## How HQ runs the live gate

Place the contract/capability documents outside the public repository, create a private manifest from the template, export the production credential only in the server execution environment, then run:

```text
python Separation/Server/commercial_route_approval.py \
  --manifest /private/e01-commercial-route.json \
  --documents-root /private/e01-documents \
  --repository-root /path/to/integrated-repository \
  --out /private/evidence/e01-commercial-route.sanitized.json
```

A live pass must produce `READY_FOR_LIVE_PROVIDER_GATE`. `PENDING_EXTERNAL_CREDENTIAL` or any stable error code is not approval.

## Remaining E01 live inputs

Still required:

1. production/evaluation credential;
2. written commercial approval for the intended consumer app;
3. privacy/retention/deletion terms;
4. confidentiality terms;
5. output-use/export terms;
6. approved pricing/billing conditions;
7. contracted region;
8. authenticated production capability snapshot proving the exact enabled model/version access.

Until those exist, Worker 1 remains `CHECKPOINT_READY` with `L1-E01` pending. A05-A20 Engineering Gate A remains complete.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

E01 readiness does not change `MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021` or `MOI-P024`. HQ must still collect the live provider, rights-cleared real audio, current-iPhone reference, blind-review and real-device evidence before modifying `PARITY_MATRIX.json`.
