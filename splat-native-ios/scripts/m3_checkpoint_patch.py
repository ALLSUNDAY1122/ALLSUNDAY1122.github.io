#!/usr/bin/env python3
from pathlib import Path

path = Path("splat-native-ios/SplatNative/ScanModel.swift")
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected exactly one match, found {count}: {old[:120]!r}")
    text = text.replace(old, new, 1)


replace_once(
'''                let writeRunReport: (
                    String,
                    SplatReconstructionPhase,
                    SplatReconstructionStopReason?,
                    Int,
                    Int,
                    Int?,
                    String?
                ) -> Void = { outcome, phase, stopReason, finalIteration, finalSplatCount, checkpointIteration, errorMessage in
                    let report = passResourceGuard.makeReport(
                        startedAt: runStartedAt,
                        startUptime: runStartUptime,
                        passStartIteration: passStart,
                        targetIteration: effectiveTarget,
                        finalIteration: finalIteration,
                        finalSplatCount: finalSplatCount,
                        initialThermalState: initialThermalState,
                        finalThermalState: splatThermalStateName(ProcessInfo.processInfo.thermalState),
                        outcome: outcome,
                        context: runContext,
                        phase: phase,
                        stopReason: stopReason,
                        checkpointIteration: checkpointIteration,
                        resumeOutcome: resumeOutcome,
                        errorMessage: errorMessage
                    )
                    SplatReconstructionRunReport.write(report, projectURL: projectURL)
                }
''',
'''                let writeRunReport: (
                    String,
                    SplatReconstructionPhase,
                    SplatReconstructionStopReason?,
                    Int,
                    Int,
                    Int?,
                    String?
                ) -> Void = { outcome, phase, stopReason, finalIteration, finalSplatCount, checkpointIteration, errorMessage in
                    let report = passResourceGuard.makeReport(
                        startedAt: runStartedAt,
                        startUptime: runStartUptime,
                        passStartIteration: passStart,
                        targetIteration: effectiveTarget,
                        finalIteration: finalIteration,
                        finalSplatCount: finalSplatCount,
                        initialThermalState: initialThermalState,
                        finalThermalState: splatThermalStateName(ProcessInfo.processInfo.thermalState),
                        outcome: outcome,
                        context: runContext,
                        phase: phase,
                        stopReason: stopReason,
                        checkpointIteration: checkpointIteration,
                        resumeOutcome: resumeOutcome,
                        errorMessage: errorMessage
                    )
                    SplatReconstructionRunReport.write(report, projectURL: projectURL)
                }
                let checkpointSaveFailureMessage = "再開用チェックポイントを保存できなかったため、安全のため生成を停止しました。撮影データは保持しています。空き容量を確認してから生成をもう一度試してください"
                let failCheckpointSave: (String, Int, Int) -> Void = { outcome, iteration, count in
                    writeRunReport(
                        outcome,
                        .checkpointSave,
                        .trainerError,
                        iteration,
                        count,
                        nil,
                        checkpointSaveFailureMessage
                    )
                    Task { @MainActor [weak self] in
                        self?.failTraining(checkpointSaveFailureMessage)
                    }
                }
''')

replace_once(
'''                if let reason = initialResourceEvaluation.reason {
                    msplatSync()
                    _ = trainer.saveCheckpoint(to: checkpoint.path)
                    writeRunReport(
''',
'''                if let reason = initialResourceEvaluation.reason {
                    msplatSync()
                    guard trainer.saveCheckpoint(to: checkpoint.path) else {
                        failCheckpointSave(
                            "failed-checkpoint-save-resource-pause",
                            resumedIteration,
                            trainer.splatCount
                        )
                        return
                    }
                    writeRunReport(
''')

replace_once(
'''                        if Task.isCancelled {
                            msplatSync()
                            _ = trainer.saveCheckpoint(to: checkpoint.path)
                            let iteration = trainer.iteration
                            let message = "生成タスクがキャンセルされました"
                            writeRunReport(
                                "cancelled",
                                .trainingStep,
                                .cancellation,
                                iteration,
                                trainer.splatCount,
                                iteration,
                                message
                            )
''',
'''                        if Task.isCancelled {
                            msplatSync()
                            let iteration = trainer.iteration
                            let count = trainer.splatCount
                            guard trainer.saveCheckpoint(to: checkpoint.path) else {
                                failCheckpointSave(
                                    "cancelled-checkpoint-save-failed",
                                    iteration,
                                    count
                                )
                                return
                            }
                            let message = "生成タスクがキャンセルされました"
                            writeRunReport(
                                "cancelled",
                                .trainingStep,
                                .cancellation,
                                iteration,
                                count,
                                iteration,
                                message
                            )
''')

replace_once(
'''                        if checkpointDue || thermalPause || resourcePauseReason != nil {
                            msplatSync()
                            _ = trainer.saveCheckpoint(to: checkpoint.path)
                        }
''',
'''                        if checkpointDue || thermalPause || resourcePauseReason != nil {
                            msplatSync()
                            guard trainer.saveCheckpoint(to: checkpoint.path) else {
                                failCheckpointSave(
                                    "failed-checkpoint-save-training",
                                    iteration,
                                    stats.splatCount
                                )
                                return
                            }
                        }
''')

replace_once(
'''                msplatSync()
                _ = trainer.saveCheckpoint(to: checkpoint.path)
                let pendingOutput = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
''',
'''                msplatSync()
                let finalCheckpointIteration = trainer.iteration
                let finalCheckpointCount = trainer.splatCount
                guard trainer.saveCheckpoint(to: checkpoint.path) else {
                    failCheckpointSave(
                        "failed-checkpoint-save-final",
                        finalCheckpointIteration,
                        finalCheckpointCount
                    )
                    return
                }
                let pendingOutput = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
''')

path.write_text(text)
