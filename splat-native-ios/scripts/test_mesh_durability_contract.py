#!/usr/bin/env python3
from pathlib import Path

coordinator = Path("splat-native-ios/SplatNative/MeshDurabilityCoordinator.swift").read_text()
recovery = Path("splat-native-ios/SplatNative/MeshDurabilityRecoveryStore.swift").read_text()
model = Path("splat-native-ios/SplatNative/MeshScanModel.swift").read_text()
mesh_view = Path("splat-native-ios/SplatNative/MeshScanView.swift").read_text()
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
    "model.blockDestructiveReset(failClosedReason)",
    "model.allowDestructiveReset()",
):
    if needle not in coordinator:
        raise SystemExit(f"missing fail-closed Mesh lifecycle contract: {needle}")

for needle in (
    "@Published private(set) var destructiveResetBlockedReason: String?",
    "func blockDestructiveReset(_ reason: String)",
    "func allowDestructiveReset()",
    "@discardableResult\n    func reset() -> Bool",
    "if let reason = destructiveResetBlockedReason",
    "return false",
):
    if needle not in model:
        raise SystemExit(f"MeshScanModel reset is not fail-closed: {needle}")

reset_start = model.index("@discardableResult\n    func reset() -> Bool")
reset_end = model.index("nonisolated func session", reset_start)
reset_block = model[reset_start:reset_end]
guard_pos = reset_block.index("if let reason = destructiveResetBlockedReason")
delete_pos = reset_block.index("FileManager.default.removeItem")
if not guard_pos < delete_pos:
    raise SystemExit("Mesh reset guard must execute before deleting the working .meshproject")

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
    "if model.destructiveResetBlockedReason == nil",
    'Button("閉じて保存を再試行")',
    "if let resetBlockedReason = model.destructiveResetBlockedReason",
    ".disabled(model.destructiveResetBlockedReason != nil)",
    "MeshExportOptionsView(sourceURL: url)",
):
    if needle not in mesh_view:
        raise SystemExit(f"full-screen Mesh UI is missing fail-closed feedback/export contract: {needle}")
if "このS4段階ではライブラリ管理はS5担当です" in mesh_view:
    raise SystemExit("stale pre-integration Mesh lifecycle warning returned")

for needle in (
    "if let blocking = meshDurability.blockingMessage",
    "meshDurability.retry(model: meshModel)",
    "meshDurability.recoverPendingProjects()",
    'Label("保存を再試行"',
):
    if needle not in shell:
        raise SystemExit(f"production shell is missing fail-closed Mesh recovery UI: {needle}")

print("PASS: Mesh durability is fail-closed at model/UI boundaries with retry/relaunch recovery")
