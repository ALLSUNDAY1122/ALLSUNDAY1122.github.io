# L1-A12 Validation — Advanced Instrument / Hi-Fi Capability Hardening

Captured: 2026-08-23 JST
Worker: `Moises-Worker-1`
Branch: `moises/wp1-separation-processing`
Result: `COMPLETE_NON_PARITY`

## Goal

Make advanced/custom instrument separation provider-neutral, capability-discovered and fail-closed without claiming current-iPhone Reference roles or Hi-Fi provider support that have not been verified.

## Reference boundary

Current checked-in Reference evidence establishes:

- Free basic 2-track vocals/instrumental.
- Free basic 4-track vocals/drums/bass/other.
- Current-iPhone custom separation visibly includes at least vocals/guitar/bass.
- A HI-FI toggle is visibly present in the current-iPhone custom flow and Pro public material confirms Hi-Fi as a Pro distinction.
- The complete current-iPhone custom instrument list and lock map remain unverified.

A12 therefore keeps `guitar` as directly current-iPhone confirmed while `piano_keys`, `strings`, `winds` and professional sub-stems remain ontology/provider capability only until newer Reference evidence activates them.

## Current provider facts used

AudioShake public developer documentation was re-read on 2026-08-23.

- Instrument models currently documented include vocals, vocals_lead, vocals_backing, instrumental, drums, bass, guitar, guitar_electric, guitar_acoustic, piano, keys, strings, wind, other and other-x-guitar.
- Multiple models may be combined in a single `/tasks` request.
- `GET /models` returns the models available to the authenticated account, including `access`, `creditsPerMinute`, input/output formats and optional limits.
- `access=enabled` is authoritative for account availability; `request_access` is not treated as usable.
- No Moises-equivalent Hi-Fi quality request flag is documented by the current public AudioShake API pages used for this Wave.

References:
- https://developer.audioshake.ai/models
- https://developer.audioshake.ai/list-models
- https://developer.audioshake.ai/separate-stems

Documentation presence alone is never promoted to account access or current-iPhone parity.

## Implementation

### `Separation/Profiles/advanced_role_catalog.v1.json`

Defines Lane 1 canonical advanced role ontology and evidence state separately from product activation.

Represented advanced families include:

- `guitar`
- `piano_keys`
- `strings`
- `winds`
- `lead_vocals`
- `backing_vocals`
- `electric_guitar`
- `acoustic_guitar`
- `acoustic_piano`
- `other_excluding_guitar`

Only already-confirmed A11 profiles may currently request their allowlisted roles. Presence in this ontology is not an entitlement or PARITY claim.

Semantic overlap guards reject aggregate/sub-stem combinations that would create ambiguous or duplicative results/cost, including aggregate vocals with lead/backing vocals, aggregate guitar with electric/acoustic guitar, aggregate keys with acoustic piano and `other` with `other_excluding_guitar`.

### `Separation/Server/advanced_capabilities.py`

Adds:

- strict parser for AudioShake `GET /models` response;
- account access gating (`enabled` only);
- WAV-output eligibility gating for Lane 1 stem artifacts;
- provider model -> canonical role mapping;
- provider capability construction compatible with the A11 `ProviderCapabilities` contract;
- optional max-target policy and semantic incompatible-role sets;
- exact provider-output-set normalization back to canonical roles;
- `AdvancedAudioShakeAdapter`, compatible with A06 provider orchestration;
- control-plane model discovery before source upload;
- disabled/gated model rejection before any billed `POST /tasks`;
- public NON-PARITY capability snapshot;
- AudioShake quality capability remains `standard` only; Hi-Fi is explicitly `UNVERIFIED_FAIL_CLOSED`.

This adapter deliberately bypasses the old core-only target allowlist only after live account model discovery proves the requested advanced models are enabled. The A06/A07 logical-job and duplicate-billing controls remain upstream and unchanged.

## Machine verification

Local reconstruction against the exact A12 files written to the Worker branch:

- Python compile/import path: PASS.
- `test_advanced_capabilities.py`: 28 tests, 0 failures.

Coverage includes:

1. required advanced role families;
2. direct-Reference vs unverified role distinction;
3. professional sub-stem ontology without Reference activation;
4. live model discovery parsing;
5. request-access exclusion;
6. WAV capability requirement;
7. duplicate/invalid model rejection;
8. canonical `keys -> piano_keys` and `wind -> winds` mapping;
9. provider role enablement;
10. no Hi-Fi inference;
11. no enabled instrument model fail-close;
12. max-target validation;
13. aggregate/sub-stem overlap rejection;
14. exact output model normalization;
15. missing/extra/duplicate provider output rejection;
16. discovery-before-upload ordering;
17. unenabled model never reaching task POST;
18. enabled guitar/keys advanced task creation;
19. discovery/network failure fail-close;
20. corrupt catalog fail-close.

Machine-readable scenario ledger:
`Processing/Tests/L1-A12_ADVANCED_CAPABILITY_MATRIX.json`.

## Remaining external/live evidence

A12 does not prove:

- production AudioShake credentials or commercial/privacy approval;
- which advanced models are actually enabled on the future production account until authenticated `GET /models` is executed;
- the complete current-iPhone Premium/Pro custom instrument/lock map;
- a provider request that is objectively equivalent to Moises Pro Hi-Fi;
- real-audio quality for guitar/keys/strings/winds/professional modules;
- P004 or P005 differential parity.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

P004/P005 remain `MISSING`. A12 closes the Lane 1 architecture/capability-discovery gap so newly verified current-iPhone roles or a future Hi-Fi-capable provider can be added inside Lane 1 without a Shared/App contract redesign, but live provider, real-audio and current-iPhone differential evidence remain mandatory.
