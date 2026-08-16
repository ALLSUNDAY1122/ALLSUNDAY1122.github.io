# D2-011 Map query / Map表示 / publish asset位置表示 — Evidence

Date: 2026-08-17
Branch: `scaniverse/d2-w11-map`
Base at branch creation: `scaniverse/d2-share-discover` (`c47329211f5ec9495f29d0c171dbfe95323f5bd9`)

## Implemented

- Map camera end events now query the public endpoint using the visible map bounding box.
- Camera queries are debounced (350 ms) and superseded queries are cancelled before dispatch.
- Manual visible-region refresh is available from the Map toolbar.
- Only published records with finite, world-valid coordinates are rendered as map annotations.
- Annotation selection opens the existing remote published-asset viewer.
- Empty/loading copy now describes the visible region rather than the global feed.
- Bounds construction and coordinate validity were extracted to `ScanLabMapQuery.swift`.

## Regression gates

`SplatNativeTests/ScanLabMapQueryTests.swift` covers:

1. latitude/longitude world-limit clamping;
2. rejection of out-of-range coordinates;
3. rejection of NaN/infinite coordinates;
4. acceptance of a normal published location.

`project.yml` uses directory source inclusion for `SplatNative` and `SplatNativeTests`, so the new source/test files are picked up by project generation without hand-editing an Xcode project.

## Review / fixes

Initial implementation duplicated bounds math in the SwiftUI view and accepted NaN because closed-range containment alone is insufficient. Review extracted a single policy and added explicit `isFinite` validation plus regression tests.

## Remaining environment gate

This connector session cannot execute Xcode/xcodebuild, so compile/runtime execution is not claimed here. The branch contains deterministic unit regression coverage intended for the existing macOS/iOS CI/build lane. No duplicate CI was manually triggered.
