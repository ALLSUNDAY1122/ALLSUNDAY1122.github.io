#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "NativePackage" / "Sources" / "HokenshiSprintFeature"
RESOURCE = SOURCES / "Resources" / "questions.json"


def all_swift() -> str:
    return "\n".join(p.read_text(encoding="utf-8") for p in sorted(SOURCES.glob("*.swift")))


def main() -> int:
    text = all_swift()
    errors: list[str] = []
    required = {
        "4 tabs": ["ホーム", "模試", "記録", "設定"],
        "sprint counts": ["[4, 8, 16]", "dailyTarget"],
        "unknown": ["わからない", "AnswerPayload.unknown"],
        "weak review": ["startWeak", "3連続"],
        "resume": ["途中から再開", "currentIndex", "commitAdvance"],
        "mock segments": ["午前55", "午後55", "通し110"],
        "history": ["LearningSprintHeatmap", "subjectAccuracy"],
        "backup": ["fileExporter", "fileImporter", "exportBackup", "importBackup"],
        "exam date": ["目標試験日", "setExamDate"],
        "memory point": ["LearningSprintMemoryBlock"],
        "progress ring": ["LearningSprintProgressRing"],
        "situational context": ["状況設定", "sourceText"],
        "primary evidence link": ["Link(destination:", "一次根拠"],
        "accessibility selection": ["選択中", "未選択"],
        "release loader": ["HokenshiReleaseContentStore.load", "requireReleaseReady: true"],
    }
    for label, tokens in required.items():
        missing = [token for token in tokens if token not in text]
        if missing:
            errors.append(f"{label}: missing {missing}")

    forbidden = ["WKWebView", "import WebKit", "UIViewRepresentable"]
    for token in forbidden:
        if token in text:
            errors.append(f"forbidden WebView implementation: {token}")

    if not RESOURCE.exists():
        errors.append("bundled questions.json missing")
    else:
        rows = json.loads(RESOURCE.read_text(encoding="utf-8"))
        if len(rows) != 330:
            errors.append(f"bundled questions must be 330, got {len(rows)}")
        if any(row.get("audit_status") != "release_ready" for row in rows):
            errors.append("bundled resource contains non-release_ready rows")
        situationals = [r for r in rows if r.get("question_type") == "situational"]
        if len(situationals) != 105:
            errors.append(f"situational total must be 105, got {len(situationals)}")
        if any(not r.get("scenario_id") or not r.get("scenario_index") for r in situationals):
            errors.append("situational scenario metadata missing")

    print("=== Hokenshi Native Product Shell Audit ===")
    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PASS: native product flow / accessibility / offline state / evidence / bundled release bank")
    return 0


if __name__ == "__main__":
    sys.exit(main())
