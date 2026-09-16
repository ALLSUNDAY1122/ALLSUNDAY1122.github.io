# 司法書士 AppIcon recovery audit — 2026-09-16

Fresh main inspection found `ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png` present at 618,801 bytes, matching the canonical Drive asset byte size recorded in the release contract. The root `codemagic.yaml` also contains the fail-closed SHA-256 assertion for canonical hash `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506`.

This file intentionally triggers the existing `shoshi-ios-release-gate.yml` against current main. The icon is not considered recovered solely from size: Release Gate must recompute SHA-256 and PASS. No redraw, recompression, substitution, TestFlight upload, or App Store submission is authorized by this audit record.
