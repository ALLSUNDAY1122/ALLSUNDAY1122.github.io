#!/usr/bin/env python3
from pathlib import Path

model = Path("splat-native-ios/SplatNative/ScanModel.swift").read_text()
helper = Path("splat-native-ios/SplatNative/ScanWorldMapArchiveStore.swift").read_text()
tests = Path("splat-native-ios/SplatNativeTests/ScanColdResumePersistenceTests.swift").read_text()
store_tests = Path("splat-native-ios/SplatNativeTests/ScanWorldMapArchiveStoreTests.swift").read_text()

if "persistWorldMapIfPossible()" in model:
    raise SystemExit("WorldMap durability regression: fire-and-forget persistence returned")
for needle in (
    "isWorldMapPersistencePending",
    "persistWorldMapForTransition(",
    "schedulePeriodicWorldMapPersistence()",
    "ScanWorldMapArchiveStore.write(data, to: targetURL)",
    "acceptedFrames == 1 || self.acceptedFrames % 12 == 0",
    "invalidateWorldMapPersistence()",
):
    if needle not in model:
        raise SystemExit(f"missing WorldMap durability contract: {needle}")

pause_start = model.index("func pauseCapture()")
pause_end = model.index("func resumeCapture()", pause_start)
pause = model[pause_start:pause_end]
finish_start = model.index("func finishCapture()")
finish_end = model.index("func discardAndReset()", finish_start)
finish = model[finish_start:finish_end]
if pause.index("persistWorldMapForTransition") > pause.index("session?.pause()"):
    raise SystemExit("pauseCapture must settle WorldMap before pausing ARSession")
if finish.index("persistWorldMapForTransition") > finish.index("self.phase = .captured"):
    raise SystemExit("finishCapture must settle WorldMap before exposing captured UI")

for needle in (
    "candidateURL",
    "data.write(to: candidateURL, options: .atomic)",
    "values.fileSize == data.count",
    "persisted == data",
    "replaceItemAt(targetURL, withItemAt: candidateURL)",
    "moveItem(at: candidateURL, to: targetURL)",
):
    if needle not in helper:
        raise SystemExit(f"WorldMap archive store missing verified replacement contract: {needle}")

if "try data.write(to: targetURL, options: .atomic)" in helper:
    raise SystemExit("WorldMap archive store must not overwrite the last resumable map before candidate verification")
if "testWorldMapArchiveStoreRejectsEmptyArchiveWithoutReplacingExistingData" not in tests:
    raise SystemExit("missing WorldMap archive empty replacement regression")
if "testWriteReplacesExistingArchiveOnlyAfterCandidateValidation" not in store_tests:
    raise SystemExit("missing WorldMap verified replacement regression")
print("PASS: WorldMap pause/finish persistence is ordered, serialized, candidate-verified, and failure-aware")
