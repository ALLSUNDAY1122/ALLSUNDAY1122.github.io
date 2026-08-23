import json
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
forbidden_root = str(Path(sys.argv[2]).resolve())
report = json.loads(report_path.read_text(encoding="utf-8"))
raw = report_path.read_text(encoding="utf-8")

assert report["schemaVersion"] == 1
assert report["reportKind"] == "pipeline_failure"
assert report["formalGoldenVerdict"] == "FORMAL_GOLDEN_FAIL_PIPELINE_EXECUTION"
assert report["runnerExitCode"] == 17
assert report["videoSHAMatchesExpected"] is True
assert report["pdfSHAMatchesExpected"] is True
assert report["completedStageMarkers"] == ["01-frame-extraction/candidates.json"]
assert report["integrityReportRelativePaths"] == ["05-book-package/demo/integrity-report.json"]
assert "runner_nonzero_exit" == report["executionFailure"]["errorType"]
assert "<REDACTED_PATH>" in report["executionFailure"]["message"] or "<HOME>" in report["executionFailure"]["message"]
assert forbidden_root not in raw, "failure evidence must not persist local absolute paths"
assert "FORMAL_GOLDEN_PASS" not in raw

print("HQ_GOLDEN_FAILURE_REPORT_FIXTURE_PASS")
