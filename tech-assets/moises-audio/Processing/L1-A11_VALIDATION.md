# L1-A11 Validation — Reference Separation Profile Registry

Captured: 2026-08-23 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Represent current-iPhone separation choices as stable provider-neutral product profiles, validate profile-specific output completeness, and negotiate provider capabilities without leaking a vendor model name into the App/HQ-facing profile ID.

## Reference boundary used

`reference/MOI-REF-001-current-iphone-free-core.md` records direct current-iPhone evidence for:

- 2-track vocals / instrumental;
- 4-track vocals / drums / bass / other;
- a custom separation screen containing at least vocals / guitar / bass;
- a HI-FI toggle before confirming separation.

The same Reference explicitly says the complete current custom-instrument lock map is not finalized. A11 therefore encodes only the directly observed custom-role floor (`vocals`, `guitar`, `bass`) and fails closed for unverified custom roles. A12 owns later advanced-instrument expansion.

## Implementation

### `Separation/Profiles/reference_profiles.v1.json`

Stable provider-neutral profile IDs:

- `sep.basic.v1.vocals_instrumental`
- `sep.basic.v1.vocals_drums_bass_other`
- `sep.custom.v1.reference_floor`

The registry contains canonical roles, entitlement floor, allowed quality modes, exact-set output policy, Reference basis and explicit UNKNOWNs. It contains no provider model names.

Hi-Fi is represented only on the directly observed custom flow and requires the Pro tier. Hi-Fi is deliberately not inferred for the two basic profiles.

### `Separation/Server/reference_profiles.py`

Provides:

- strict registry validation and schema/version checks;
- stable profile resolution with Free/Premium/Pro entitlement checks;
- custom selection limited to current Reference-confirmed role floor;
- provider capability descriptor with canonical-role -> provider-model mapping;
- quality-mode negotiation;
- max-target and incompatible-role-set enforcement;
- provider model collision detection;
- exact profile output completeness validation;
- vendor-neutral public registry snapshot;
- current AudioShake core-adapter capability descriptor advertising only what the checked-in adapter actually supports: standard quality and core models, no custom/Hi-Fi claim.

## Fail-close semantics

A request is rejected when any of the following is true:

- unknown profile or account tier;
- fixed profile is manually overridden;
- custom selection is empty;
- custom role is outside the current Reference-confirmed floor;
- Premium attempts Hi-Fi;
- Hi-Fi is requested on a profile where current Reference support was not established;
- provider lacks custom selection, role, quality mode, target capacity, or compatible combination;
- two canonical roles collide onto one provider model;
- output set is missing, extra, or duplicate.

These failures do not mutate `PARITY_MATRIX.json` and do not imply provider quality.

## Verification

Local execution against the exact A11 files:

- `python -m py_compile Separation/Server/reference_profiles.py Separation/Tests/test_reference_profiles.py`: PASS
- `python -m unittest discover -s Separation/Tests -p 'test_reference_profiles.py' -v`: **24/24 PASS**

Machine-readable scenario ledger:

- `Processing/Tests/L1-A11_PROFILE_MATRIX.json`

## Remaining gaps

- Complete current-iPhone custom instrument list / lock map remains unverified.
- Advanced guitar/piano-keys/strings/winds role combinations and output normalization remain A12.
- Current AudioShake adapter advertises no custom selection or Hi-Fi capability; A11 correctly fails closed rather than inferring support.
- Provider/model quality, real-audio output quality, current-iPhone differential evidence and entitlement UX remain live/HQ gates.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

A11 closes the provider-neutral request/validation seam needed by P003/P004/P005, but does not move any PARITY row without live provider + real-audio + current-iPhone differential evidence.
