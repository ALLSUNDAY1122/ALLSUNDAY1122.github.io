# MOI-DSP-R001｜DSP Licence / Asset / Distribution Audit

This task separates **code licence**, **runtime/binary distribution right**, and **model/sample asset rights**. No candidate in this task requires an ML model.

Status vocabulary:
- `BASELINE_OK`: no additional third-party procurement for the selected Apple-system path.
- `COMMERCIAL_LICENSE_REQUIRED`: technically viable but public proprietary distribution requires a paid/negotiated licence.
- `LEGAL_REVIEW_REQUIRED`: open-source path has obligations that must not be casually accepted for an App Store binary.
- `EVALUATION_ONLY`: current evaluation grant is not a public-release grant.

| Candidate | Code / SDK terms | Model rights | Audio/sample assets | Public proprietary iOS distribution | Project status |
|---|---|---|---|---|---|
| Apple AVFAudio / AVFoundation system DSP | Apple platform SDK/system framework terms | none | project-owned click sample | no bundled third-party DSP code; normal Apple platform/app terms apply | `BASELINE_OK` |
| Rubber Band Library 4.x open-source | GPL v2 or later | none | none required | vendor says GPL route is not suitable for iOS/macOS App Store; proprietary distribution requires commercial licence | `COMMERCIAL_LICENSE_REQUIRED` |
| Rubber Band Library 4.x commercial | vendor commercial licence | none | none required | explicit proprietary redistribution route; current licence page states no expiry/no royalties | `COMMERCIAL_LICENSE_REQUIRED` until purchase |
| Superpowered Audio SDK evaluation | proprietary SDK; evaluation key | none | bundled SDK assets subject to agreement | current docs say internal/private evaluation only; public launch not permitted | `EVALUATION_ONLY` |
| Superpowered White Label | proprietary SDK | none | subject to agreement | current docs describe public/private App Store launch; fixed annual fee/no royalty, price via sales | `COMMERCIAL_LICENSE_REQUIRED` |
| SoundTouch LGPL 2.1 | LGPL 2.1 | none | none required | author FAQ permits iPhone static-link use subject to licence terms; exact compliance obligations need deliberate legal review | `LEGAL_REVIEW_REQUIRED` |
| SoundTouch commercial | commercial non-LGPL licence from author | none | none required | commercial route available on request | `COMMERCIAL_LICENSE_REQUIRED` |

## Rubber Band current commercial terms captured 2026-08-22

Official vendor pages currently state:
- open-source distribution: GPL v2-or-later;
- proprietary commercial apps: commercial licence required;
- commercial licence has no expiry and no royalties;
- Standard Licence with prominent attribution: £590;
- Non-Attribution Licence for publishers <10 employees: £1490;
- Non-Attribution Licence for companies >=10 employees: £9320.

These prices are evidence for planning, not a purchase authorization. Recheck at procurement time.

Sources:
- https://breakfastquay.com/rubberband/license.html
- https://breakfastquay.com/technology/license.html

## Superpowered current grant boundary

Current official licensing docs say:
- Evaluation: private/internal experimentation and testing only.
- White Label: public/private App Store launch.
- Current pricing page: White Label uses a fixed annual fee, no royalty/no revenue share, price obtained through sales.
- License is per Application under the current master agreement.

A historical Superpowered page mentions older free public-app conditions, but the current licensing documentation explicitly says there is no free licence for public release. The current licensing page therefore controls this project decision.

Sources:
- https://docs.superpowered.com/getting-started/licensing/
- https://superpowered.com/licensing
- https://superpowered.com/pricing

## SoundTouch boundary

Official current site says SoundTouch is LGPL 2.1 and offers a commercial non-LGPL licence. The FAQ explicitly acknowledges iPhone static linkage and says an independent developer may use it if the remaining licence terms are followed, while also offering a commercial licence for teams wanting to avoid LGPL concerns.

Project decision:
- LGPL build is not automatically forbidden, but it is **not** the default proprietary-app route.
- If SoundTouch wins technically, first obtain the commercial licence or a written legal determination of the exact App Store compliance package.

Sources:
- https://www.surina.net/soundtouch/license.html
- https://surina.net/soundtouch/faq.html

## Click / count-in audio assets

No third-party click asset is required. Generate or record project-owned transient samples and retain provenance. Store both accented downbeat and regular beat samples under a future asset-specific task/write scope.

Do not use samples extracted from Moises or another music application.

## No-model statement

The selected DSP candidates are algorithmic audio processors; no pretrained ML model or training-data licence is required for time stretch/pitch shift. If a later candidate introduces an ML model, that candidate must undergo the same three-way code/weight/training-data audit used by Source Separation before it can replace the baseline.

## Release gate

Before a third-party DSP enters a release build, record:
1. exact library/SDK version;
2. exact licence agreement/version/date;
3. application/bundle ID covered by the licence if applicable;
4. attribution requirements;
5. permitted platforms and distribution channels;
6. binary/source redistribution obligations;
7. licence-key handling requirements;
8. third-party dependency licences;
9. asset/sample provenance;
10. upgrade/EOL terms that could invalidate release rights.

Missing any required item means `REVIEW_REQUIRED`, not implicit approval.
