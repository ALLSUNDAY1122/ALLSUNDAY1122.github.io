#!/usr/bin/env python3
from pathlib import Path

coordinator = Path("splat-native-ios/SplatNative/MeshDurabilityCoordinator.swift").read_text()
recovery = Path("splat-native-ios/SplatNative/MeshDurabilityRecoveryStore.swift").read_text()
shell = Path("splat-native-ios/SplatNative/IntegratedScanLabShellView.swift").read_text()

snapshot = "summary = try archiveFinishedProject(sourceURL)"
verification_task = "verificationTask = Task"
detached = "Task.detached(priority: .utility)"

for needle in (snapshot, verification_task, detached):
    if needle not in coordinator:
        raise SystemExit(f"missing Mesh durability contract: {needle}")

snapshot_pos = coordinator.index(snapshot)
verification_task_pos = coordinator.index(verification_task)
detached_pos = coordinator.index(detached, verification_task_pos)
if not snapshot_pos < verification_task_pos < detached_pos:
    raise SystemExit(
        "Mesh durability regression: durable archive must finish before async integrity verification starts"
    )

for needle in (
    "try MeshDurabilityRecoveryStore().protect(resultURL: sourceURL)",
    "@Published private(set) var blockingMessage: String?",
    "failedSourceURL",
    "func retry(model: MeshScanModel)",
    "func recoverPendingProjects()",
    "preserveAfterFailure(sourceURL:",
    "self.cleanupProtectedResult(sourceURL)",
):
    if needle not in coordinator:
        raise SystemExit(f"missing fail-closed Mesh lifecycle contract: {needle}")

protect_start = recovery.index("func protect(resultURL: URL)")
protect_end = recovery.index("func cleanupProtectedResult", protect_start)
protect_block = recovery[protect_start:protect_end]
if "moveItem(at: sourceProjectURL, to: destinationURL)" not in protect_block:
    raise SystemExit("Mesh Recovery must use same-volume project rename before reset can delete the working URL")
if "copyItem" in protect_block:
    raise SystemExit("Mesh Recovery protection must not require a storage-consuming copy")

for needle in (
    "func recoverPendingArchives()",
    "MeshProjectIntegrity.verifyOrSeal(summary: summary)",
    "try fileManager.removeItem(at: projectURL)",
    'hasPrefix("mesh-reprocessed-")',
    "projectDirectories(in: appRootURL)",
):
    if needle not in recovery:
        raise SystemExit(f"missing Mesh recovery contract: {needle}")

verify_pos = recovery.index("MeshProjectIntegrity.verifyOrSeal(summary: summary)")
remove_pos = recovery.index("try fileManager.removeItem(at: projectURL)", verify_pos)
if not verify_pos < remove_pos:
    raise SystemExit("Recovery working project must only be deleted after archive integrity verification succeeds")

for needle in (
    "if let blocking = meshDurability.blockingMessage",
    "meshDurability.retry(model: meshModel)",
    "meshDurability.recoverPendingProjects()",
    'Label("保存を再試行"',
):
    if needle not in shell:
        raise SystemExit(f"production shell is missing fail-closed Mesh recovery UI: {needle}")

print("PASS: Mesh archive/verification failure preserves working data and exposes retry/relaunch recovery")
