#!/usr/bin/env python3
from pathlib import Path
import re

model = Path("splat-native-ios/SplatNative/ScanModel.swift").read_text()
helper = Path("splat-native-ios/SplatNative/ScanWorldMapArchiveStore.swift").read_text()
tests = Path("splat-native-ios/SplatNativeTests/ScanColdResumePersistenceTests.swift").read_text()

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
if "try data.write(to: targetURL, options: .atomic)" not in helper or "values.fileSize == data.count" not in helper:
    raise SystemExit("WorldMap archive store must atomically write and verify byte count")
if "testWorldMapArchiveStoreRejectsEmptyArchiveWithoutReplacingExistingData" not in tests:
    raise SystemExit("missing WorldMap archive replacement regression")
print("PASS: WorldMap pause/finish persistence is ordered, serialized, atomic, and failure-aware")
