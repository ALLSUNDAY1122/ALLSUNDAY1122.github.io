# D2-011 Map query / Map表示 / publish asset位置表示 — Evidence

Date: 2026-08-18
Branch: `scaniverse/d2-w11-map`
Base: `scaniverse/d2-share-discover`
Synchronized base before final review: `74c357ed60c97e0a02d9988776d81bcfea9e4fab`

## Implemented

- Map camera end events query the public scan endpoint with the visible MapKit bounding box.
- Camera queries are debounced for 350 ms and superseded tasks are cancelled before dispatch.
- The Map toolbar can manually reload the current visible region.
- Only published records with finite, world-valid coordinates are rendered as annotations.
- Annotation selection opens the existing remote published-asset viewer.
- Empty/loading copy describes the visible region rather than the global feed.
- Bounds construction and coordinate validity are isolated in `ScanLabMapQuery.swift`.

## Regression gates

`SplatNativeTests/ScanLabMapQueryTests.swift` covers:

1. latitude/longitude world-limit clamping;
2. rejection of out-of-range coordinates;
3. rejection of NaN/infinite coordinates;
4. acceptance of a normal published location.

The direct-source `SplatNativeTests` target includes `SplatNative/ScanLabMapQuery.swift` in `project.yml`. The test intentionally does not use `@testable import SplatNative`, matching the existing direct-source test-target architecture.

## CI evidence

Synchronized worker commit `b96059c09da426ec45ef24a483cdc6f73060f160` passed `Splat Native iOS Build` run #1143. Successful steps included static checks, project generation/resource verification, SwiftPM resolution, the msplat smoke-test bundle for iOS Simulator, and unsigned iPhone compilation.

Earlier CI failures exposed two regression-gate wiring defects and were fixed rather than ignored:

- the new map policy source was initially absent from the direct-source test target;
- the new test initially used `@testable import SplatNative`, which is incompatible with that target layout.

## Adversarial review / cleanup

The first implementation also reformatted unrelated Discover, publish entry, and remote-viewer code in `ScanLabShellView.swift`. Although behavior was unchanged, this enlarged the PR and increased merge-conflict risk. Final review restores all non-Map sections from the latest base and retains only the D2-011 Map-specific changes.

The cleanup commit that contains this evidence must pass the same existing CI lane before D2-011 is considered complete. No duplicate workflow run is manually triggered.
