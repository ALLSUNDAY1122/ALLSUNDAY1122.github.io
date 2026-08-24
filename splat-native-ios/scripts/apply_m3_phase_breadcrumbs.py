#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "SplatNative" / "ScanModel.swift"
CONTRACT = ROOT / "scripts" / "test_reconstruction_contracts.py"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> None:
    replace_once(
        MODEL,
        "                    SplatReconstructionRunReport.write(report, projectURL: projectURL)\n                }\n\n                do {\n                    let plyURL = projectURL.appendingPathComponent(\"points3D.ply\")\n",
        "                    SplatReconstructionRunReport.write(report, projectURL: projectURL)\n                }\n\n                // Persist the phase before entering work that can terminate the process before Swift can report an error.\n                writeEarlyReport(\"running-preflight\", .preflight, nil, nil)\n\n                do {\n                    let plyURL = projectURL.appendingPathComponent(\"points3D.ply\")\n",
        "preflight breadcrumb",
    )

    replace_once(
        MODEL,
        "                    Task { @MainActor [weak self] in\n                        self?.failTraining(reason.userMessage)\n                    }\n                    return\n                }\n\n                let dataset = GaussianDataset(\n",
        "                    Task { @MainActor [weak self] in\n                        self?.failTraining(reason.userMessage)\n                    }\n                    return\n                }\n\n                writeEarlyReport(\"running-dataset-init\", .datasetInit, nil, nil)\n                let dataset = GaussianDataset(\n",
        "dataset breadcrumb",
    )

    replace_once(
        MODEL,
        "                let config = SplatReconstructionPolicy.makeConfig()\n                let trainer = GaussianTrainer(dataset: dataset, config: config)\n\n                let checkpointExists = FileManager.default.fileExists(atPath: checkpoint.path)\n",
        "                let config = SplatReconstructionPolicy.makeConfig()\n                writeEarlyReport(\"running-trainer-init\", .trainerInit, nil, nil)\n                let trainer = GaussianTrainer(dataset: dataset, config: config)\n\n                let checkpointExists = FileManager.default.fileExists(atPath: checkpoint.path)\n",
        "trainer breadcrumb",
    )

    replace_once(
        MODEL,
        "                if checkpointExists {\n                    loadedCheckpointIteration = trainer.loadCheckpoint(from: checkpoint.path)\n                } else {\n",
        "                if checkpointExists {\n                    writeEarlyReport(\"running-checkpoint-load\", .checkpointLoad, nil, nil)\n                    loadedCheckpointIteration = trainer.loadCheckpoint(from: checkpoint.path)\n                } else {\n",
        "checkpoint load breadcrumb",
    )

    replace_once(
        MODEL,
        "                if resumedIteration < effectiveTarget {\n                    for _ in resumedIteration..<effectiveTarget {\n",
        "                if resumedIteration < effectiveTarget {\n                    writeRunReport(\n                        \"running-training-step\",\n                        .trainingStep,\n                        nil,\n                        resumedIteration,\n                        trainer.splatCount,\n                        checkpointExists ? resumedIteration : nil,\n                        nil\n                    )\n                    for _ in resumedIteration..<effectiveTarget {\n",
        "training start breadcrumb",
    )

    replace_once(
        MODEL,
        "                        if thermalPause {\n                            let message = \"端末温度が高くなったため生成を安全に一時停止しました。端末が冷えてから「生成だけもう一度試す」で続きから再開できます\"\n                            writeRunReport(\n                                \"paused-thermal\",\n                                .trainingStep,\n                                .thermal,\n                                iteration,\n                                stats.splatCount,\n                                iteration,\n                                nil\n                            )\n                            Task { @MainActor [weak self] in\n                                self?.failTraining(message)\n                            }\n                            return\n                        }\n                    }\n                }\n\n                msplatSync()\n",
        "                        if thermalPause {\n                            let message = \"端末温度が高くなったため生成を安全に一時停止しました。端末が冷えてから「生成だけもう一度試す」で続きから再開できます\"\n                            writeRunReport(\n                                \"paused-thermal\",\n                                .trainingStep,\n                                .thermal,\n                                iteration,\n                                stats.splatCount,\n                                iteration,\n                                nil\n                            )\n                            Task { @MainActor [weak self] in\n                                self?.failTraining(message)\n                            }\n                            return\n                        }\n\n                        // Reuse the existing durable checkpoint cadence as a low-I/O progress heartbeat.\n                        if checkpointDue {\n                            writeRunReport(\n                                \"running-training-step\",\n                                .trainingStep,\n                                nil,\n                                iteration,\n                                stats.splatCount,\n                                iteration,\n                                nil\n                            )\n                        }\n                    }\n                }\n\n                msplatSync()\n",
        "training heartbeat",
    )

    replace_once(
        MODEL,
        "                let finalCheckpointIteration = trainer.iteration\n                let finalCheckpointCount = trainer.splatCount\n                guard trainer.saveCheckpoint(to: checkpoint.path) else {\n",
        "                let finalCheckpointIteration = trainer.iteration\n                let finalCheckpointCount = trainer.splatCount\n                writeRunReport(\n                    \"running-checkpoint-save\",\n                    .checkpointSave,\n                    nil,\n                    finalCheckpointIteration,\n                    finalCheckpointCount,\n                    nil,\n                    nil\n                )\n                guard trainer.saveCheckpoint(to: checkpoint.path) else {\n",
        "final checkpoint breadcrumb",
    )

    replace_once(
        MODEL,
        "                let pendingOutput = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)\n                trainer.exportSplat(to: pendingOutput.path)\n",
        "                let pendingOutput = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)\n                writeRunReport(\n                    \"running-export\",\n                    .export,\n                    nil,\n                    trainer.iteration,\n                    trainer.splatCount,\n                    finalCheckpointIteration,\n                    nil\n                )\n                trainer.exportSplat(to: pendingOutput.path)\n",
        "export breadcrumb",
    )

    replace_once(
        MODEL,
        "                let rendered = trainer.render(cameraIndex: 0)\n                let preview = Self.makeImage(from: rendered)\n",
        "                writeRunReport(\n                    \"running-preview\",\n                    .preview,\n                    nil,\n                    trainer.iteration,\n                    trainer.splatCount,\n                    finalCheckpointIteration,\n                    nil\n                )\n                let rendered = trainer.render(cameraIndex: 0)\n                let preview = Self.makeImage(from: rendered)\n",
        "preview breadcrumb",
    )

    marker = "# Expensive point-color projection and sky seeding must run after Task.detached begins, not while\n"
    contract_text = CONTRACT.read_text(encoding="utf-8")
    if contract_text.count(marker) != 1:
        raise RuntimeError("contract insertion marker missing or ambiguous")
    breadcrumb_contract = '''# Abrupt process termination cannot execute a Swift failure branch. Persist a phase breadcrumb\n# before expensive/uninterruptible reconstruction work, and refresh training progress only at the existing\n# checkpoint cadence so Build 5 evidence identifies the last durable phase without excessive I/O.\nfor outcome, phase in (\n    ("running-preflight", ".preflight"),\n    ("running-dataset-init", ".datasetInit"),\n    ("running-trainer-init", ".trainerInit"),\n    ("running-checkpoint-load", ".checkpointLoad"),\n    ("running-checkpoint-save", ".checkpointSave"),\n    ("running-export", ".export"),\n    ("running-preview", ".preview"),\n):\n    require(\n        rf'{re.escape(outcome)}"[\\s\\S]{{0,500}}{re.escape(phase)}',\n        MODEL,\n        f"missing durable reconstruction phase breadcrumb: {outcome} / {phase}",\n    )\nassert MODEL.count('"running-training-step"') >= 2, "training must persist start + checkpoint-cadence heartbeats"\nrequire(\n    r'if checkpointDue \\{[\\s\\S]{0,500}running-training-step',\n    MODEL,\n    "training heartbeat must reuse checkpoint cadence rather than per-step disk writes",\n)\n\n'''
    CONTRACT.write_text(contract_text.replace(marker, breadcrumb_contract + marker, 1), encoding="utf-8")

    print("PASS: applied M3 durable phase breadcrumb patch")


if __name__ == "__main__":
    main()
