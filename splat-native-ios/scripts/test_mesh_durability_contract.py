#!/usr/bin/env python3
from pathlib import Path

source = Path("splat-native-ios/SplatNative/MeshDurabilityCoordinator.swift").read_text()

snapshot = "summary = try archiveFinishedProject(sourceURL)"
verification_task = "verificationTask = Task"
detached = "Task.detached(priority: .utility)"

for needle in (snapshot, verification_task, detached):
    if needle not in source:
        raise SystemExit(f"missing Mesh durability contract: {needle}")

snapshot_pos = source.index(snapshot)
verification_task_pos = source.index(verification_task)
detached_pos = source.index(detached)

if not snapshot_pos < verification_task_pos < detached_pos:
    raise SystemExit(
        "Mesh durability regression: durable archive must finish before async integrity verification starts"
    )

if "let summary: MeshProjectSummary" not in source:
    raise SystemExit("Mesh durability regression: archive summary must cross the async verification boundary")

if "The snapshot itself already exists durably" not in source:
    raise SystemExit("Mesh durability failure semantics no longer document the durable snapshot boundary")

print("PASS: finished Mesh is durably snapshotted before async verification/reset can race")
