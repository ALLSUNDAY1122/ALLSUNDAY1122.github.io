from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
guard = (ROOT / "SplatNative/SplatResourceGuard.swift").read_text(encoding="utf-8")
model = (ROOT / "SplatNative/ScanModel.swift").read_text(encoding="utf-8")
root_view = (ROOT / "SplatNative/RootScanView.swift").read_text(encoding="utf-8")
policy = (ROOT / "SplatNative/SplatReconstructionPolicy.swift").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


# Physical failure evidence must identify the exact resource guard that stopped the run.
require("func diagnosticText(" in guard, "diagnostic formatter missing")
for token in (
    "reason=\\(rawValue)",
    "iteration=\\(iteration)",
    "splats=\\(splatCount)",
    "resident=\\(mib(evaluation.residentMemoryBytes)) MiB",
    "budget=\\(mib(limits.residentMemoryBudgetBytes)) MiB",
    "available=\\(mib(evaluation.availableMemoryBytes)) MiB",
    "reserve=\\(mib(limits.minimumAvailableMemoryReserveBytes)) MiB",
):
    require(token in guard, f"diagnostic field missing: {token}")

for reason in ("memoryWarning", "availableMemoryReserve", "residentMemoryBudget"):
    require(f"case {reason}" in guard, f"resource reason missing: {reason}")

require(
    model.count("failTraining(reason.userMessage, diagnostic: diagnostic)") == 3,
    "all three resource-pause boundaries must forward diagnostic evidence",
)
require(
    "if let reason = resourcePauseReason, let resourceEvaluation" in model,
    "training resource evaluation must remain available to diagnostic formatter",
)
require(
    "@Published private(set) var reconstructionDiagnosticText: String?" in model,
    "diagnostic state missing from ScanModel",
)
require(
    "reconstructionDiagnosticText = nil" in model,
    "diagnostic state must clear before a new training attempt",
)
require(
    "if let diagnostic = model.reconstructionDiagnosticText, !diagnostic.isEmpty" in root_view,
    "failure UI does not expose diagnostic evidence",
)
require("Text(\"診断情報\")" in root_view, "diagnostic UI label missing")

# Protected quality/safety contracts. S11 is observability-only.
for token in (
    "static let standardIterations = 7_000",
    "static let datasetDownscale: Float = 4.0",
    "config.shDegree = 3",
):
    require(token in policy, f"protected reconstruction contract changed: {token}")
require(
    "jpegData(compressionQuality: 0.90)" in model,
    "capture JPEG quality changed",
)
for token in (
    "let minimumBudget = 700 * mib",
    "let maximumBudget = 1_536 * mib",
    "let proportional = physicalMemoryBytes / 100 * 28",
    "let minimumReserve = 256 * mib",
    "let maximumReserve = 512 * mib",
    "let proportionalReserve = physicalMemoryBytes / 100 * 6",
    "let splatBudget = min(900_000, max(300_000, rawCount))",
):
    require(token in guard, f"protected resource policy changed: {token}")

print("PASS: S11 physical diagnostics are reason-specific and quality-neutral")
