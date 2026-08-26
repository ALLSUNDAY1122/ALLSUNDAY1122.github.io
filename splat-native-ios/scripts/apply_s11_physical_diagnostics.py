from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


guard_path = Path("splat-native-ios/SplatNative/SplatResourceGuard.swift")
guard = guard_path.read_text(encoding="utf-8")
marker = "\n}\n\nenum SplatReconstructionStopReason: String, Codable, Equatable, Sendable {"
if guard.count(marker) != 1:
    raise SystemExit(f"resource guard enum boundary: expected 1, found {guard.count(marker)}")
diagnostic_method = r'''

    func diagnosticText(
        evaluation: SplatResourceEvaluation,
        limits: SplatResourceLimits,
        iteration: Int,
        splatCount: Int
    ) -> String {
        func mib(_ bytes: UInt64) -> String {
            String(format: "%.0f", Double(bytes) / 1_048_576.0)
        }
        return "reason=\(rawValue) · iteration=\(iteration) · splats=\(splatCount) · resident=\(mib(evaluation.residentMemoryBytes)) MiB / budget=\(mib(limits.residentMemoryBudgetBytes)) MiB · available=\(mib(evaluation.availableMemoryBytes)) MiB / reserve=\(mib(limits.minimumAvailableMemoryReserveBytes)) MiB"
    }
'''
guard = guard.replace(marker, diagnostic_method + marker, 1)
guard_path.write_text(guard, encoding="utf-8")

model_path = Path("splat-native-ios/SplatNative/ScanModel.swift")
model = model_path.read_text(encoding="utf-8")
model = replace_once(
    model,
    "    @Published private(set) var isWorldMapPersistencePending = false\n",
    "    @Published private(set) var isWorldMapPersistencePending = false\n    @Published private(set) var reconstructionDiagnosticText: String?\n",
    "published diagnostic property",
)
model = replace_once(
    model,
    "        trainingIteration = 0\n        splatCount = 0\n        datasetReady = false\n",
    "        trainingIteration = 0\n        splatCount = 0\n        reconstructionDiagnosticText = nil\n        datasetReady = false\n",
    "discard diagnostic reset",
)
model = replace_once(
    model,
    "        phase = .training\n        trainingProgress = 0\n        splatCount = 0\n",
    "        phase = .training\n        trainingProgress = 0\n        splatCount = 0\n        reconstructionDiagnosticText = nil\n",
    "training diagnostic reset",
)

pause_call = "                        self?.failTraining(reason.userMessage)"
if model.count(pause_call) != 3:
    raise SystemExit(f"resource pause calls: expected 3, found {model.count(pause_call)}")
replacements = [
    '''                        let diagnostic = reason.diagnosticText(
                            evaluation: preflightEvaluation,
                            limits: passResourceGuard.limits,
                            iteration: 0,
                            splatCount: 0
                        )
                        self?.failTraining(reason.userMessage, diagnostic: diagnostic)''',
    '''                        let diagnostic = reason.diagnosticText(
                            evaluation: initialResourceEvaluation,
                            limits: passResourceGuard.limits,
                            iteration: resumedIteration,
                            splatCount: trainer.splatCount
                        )
                        self?.failTraining(reason.userMessage, diagnostic: diagnostic)''',
    '''                                let diagnostic = reason.diagnosticText(
                                    evaluation: resourceEvaluation,
                                    limits: passResourceGuard.limits,
                                    iteration: iteration,
                                    splatCount: stats.splatCount
                                )
                                self?.failTraining(reason.userMessage, diagnostic: diagnostic)''',
]
for replacement in replacements:
    model = model.replace(pause_call, replacement, 1)

model = replace_once(
    model,
    "                        if let reason = resourcePauseReason {\n",
    "                        if let reason = resourcePauseReason, let resourceEvaluation {\n",
    "resource evaluation unwrap",
)
model = replace_once(
    model,
    "    private func failTraining(_ message: String) {\n        if let projectURL {\n",
    "    private func failTraining(_ message: String, diagnostic: String? = nil) {\n        reconstructionDiagnosticText = diagnostic\n        if let projectURL {\n",
    "failTraining diagnostic storage",
)
model_path.write_text(model, encoding="utf-8")

root_path = Path("splat-native-ios/SplatNative/RootScanView.swift")
root = root_path.read_text(encoding="utf-8")
old = '''            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if model.canRetryGeneration {'''
new = '''            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let diagnostic = model.reconstructionDiagnosticText, !diagnostic.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("診断情報")
                        .font(.caption.bold())
                    Text(diagnostic)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            if model.canRetryGeneration {'''
root = replace_once(root, old, new, "failed view diagnostic block")
root_path.write_text(root, encoding="utf-8")
