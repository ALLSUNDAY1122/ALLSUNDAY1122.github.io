# Native Architecture — #14 助産師国家試験

## Why the first native unit is a Swift package

Production Bundle ID / App Store Connect App ID / IAP Product ID are not present in the current canonical identifier document. To avoid inventing production values, Phase 1 is implemented as an iOS-capable SwiftUI feature package. This allows source compilation and unit tests without creating a fake release identity. Once the canonical Bundle ID is confirmed, this feature becomes the root content of the iOS application target.

## Proposed final tree

```text
josanshi-sprint/
├── README.md
├── data/
│   ├── exam-config.json
│   ├── question-blueprint.json          # next phase
│   └── questions.production.json        # only after 330-question audit PASS
├── docs/
│   ├── RESEARCH_2026-08-12.md
│   ├── ARCHITECTURE.md
│   ├── RELEASE_STATUS.md
│   └── CONTENT_AUDIT.md                 # next phase
└── ios/
    ├── JosanshiSprintFeature/
    │   ├── Package.swift
    │   ├── Sources/JosanshiSprintFeature/
    │   │   ├── JosanshiExamConfiguration.swift
    │   │   ├── JosanshiDashboardModel.swift
    │   │   └── JosanshiRootView.swift
    │   └── Tests/JosanshiSprintFeatureTests/
    │       └── JosanshiSprintFeatureTests.swift
    └── JosanshiSprintApp/               # create after Bundle ID confirmation
        ├── project.yml
        ├── Info.plist
        ├── PrivacyInfo.xcprivacy
        ├── Assets.xcassets/
        ├── App.swift
        ├── Tests/
        └── UITests/
```

## UI mapping to Golden Master v2.1

- Home / Mock / History / Settings: four fixed bottom tabs.
- Paper background, indigo primary, vermilion accent, green/gold semantics: use `LearningSprintTheme`.
- 82pt progress ring: use `LearningSprintProgressRing`.
- 「ここだけ覚える」 block: use `LearningSprintMemoryBlock`.
- 5-week history: use `LearningSprintHeatmap`.
- Standard sprint: 8 questions; selectable 4 / 8 / 16 daily targets.
- Question/result typography: Mincho; operation controls: sans-serif.
- 44pt minimum controls, Dynamic Type, VoiceOver labels, portrait, no horizontal scrolling.

## Shared learning logic to wire after content audit

Use `LearningSprintCore` for:

- single/multiple/numeric answer evaluation where applicable;
- formal `わからない` answer;
- wrong/unknown → weak registration;
- 3 consecutive correct → weak removal;
- interrupted session snapshot/resume;
- attempts and 35-day aggregation;
- JSON backup/restore and qualification mismatch protection;
- StoreKit 2 verified, non-revoked entitlement only;
- `Product.displayPrice` as the only price source.

## Medical-content boundary

The SwiftUI feature intentionally does not ship a provisional question bank. Creating a handful of visually plausible questions and calling them a bank would violate the problem-generation loop and create padding risk. Production content is enabled only after the 3 × 110 original-question bank passes count, similarity, answer, explanation, primary-source, baseline-date and rights audits.

## StoreKit boundary

StoreKit plumbing exists in `LearningSprintCore`, but #14 must not instantiate a production `PurchaseController` until an exact Product ID is confirmed. The UI may show entitlement architecture during development, but no hard-coded guessed Product ID is permitted.
