#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path

IOS = Path(__file__).resolve().parent
ROOT = IOS.parent
REPORT = IOS / "native-source-audit-report.json"


def require(cond: bool, message: str) -> None:
    if not cond:
        raise AssertionError(message)


def main() -> int:
    swift_files = list(IOS.glob("*.swift"))
    swift = "\n".join(p.read_text(encoding="utf-8") for p in swift_files)
    models = (IOS / "Models.swift").read_text(encoding="utf-8")
    app_model = (IOS / "AppModel.swift").read_text(encoding="utf-8")
    project = (IOS / "project.yml").read_text(encoding="utf-8")
    privacy = (IOS / "PrivacyInfo.xcprivacy").read_text(encoding="utf-8")
    prepare = (IOS / "prepare-ios.sh").read_text(encoding="utf-8")
    tests = (IOS / "Tests" / "ShoshiSprintTests.swift").read_text(encoding="utf-8")
    questions = json.loads((ROOT / "content-loop" / "questions.generated.json").read_text(encoding="utf-8"))

    forbidden = ["import WebKit", "WKWebView", "UIViewRepresentable", "loadFileURL"]
    for token in forbidden:
        require(token not in swift, f"forbidden WebView token remains in Swift source: {token}")
    require("path: Web" not in project, "Xcode project still includes Web bundle")
    require("path: Resources" in project, "native Resources bundle missing")
    require("ShoshiSprintTests" in project, "unit-test target missing")

    for label in ["ホーム", "模試", "記録", "設定"]:
        require(label in swift, f"4-tab label missing: {label}")
    for goal in ["Text(\"4問\").tag(4)", "Text(\"8問\").tag(8)", "Text(\"16問\").tag(16)"]:
        require(goal in swift, f"daily-goal UI missing: {goal}")
    require("correctStreak >= 3" in swift, "weak-item three-correct release rule missing")
    require("state.resume" in swift and "answeredChoice" in swift and "answeredCorrect" in swift, "mid-session resume contract missing")
    require("fileExporter" in swift and "fileImporter" in swift, "JSON backup UI missing")
    require("UserDefaults.standard" in swift, "native local persistence missing")
    require("trialCompleted" not in models and "trialConsumed" not in models, "trial entitlement must not be part of exported LearningState")
    require("trialConsumedKey" in app_model and "UserDefaults.standard.set(true, forKey: Self.trialConsumedKey)" in app_model,
            "trial consumption must use separate device persistence")
    require('json.contains("trialConsumed")' in tests, "backup test must verify trial state is excluded")
    require("Product.products(for:" in swift, "StoreKit 2 product loading missing")
    require("Transaction.currentEntitlements" in swift, "StoreKit entitlement audit missing")
    require("Transaction.updates" in swift, "StoreKit transaction update observer missing")
    require("AppStore.sync()" in swift, "StoreKit restore missing")
    require("jp.allsunday1122.shoshi.premium" in swift, "IAP product ID missing")
    require("displayPrice" in swift, "localized App Store price missing")
    require("￥" not in swift and "¥" not in swift, "hard-coded yen price forbidden")

    require("NSPrivacyAccessedAPICategoryUserDefaults" in privacy, "Privacy Manifest UserDefaults category missing")
    require("CA92.1" in privacy, "Privacy Manifest UserDefaults reason CA92.1 missing")
    require("NSPrivacyTracking</key>\n  <false/>" in privacy, "tracking must be false")
    require("NSPrivacyCollectedDataTypes</key>\n  <array/>" in privacy, "collected-data list must be empty")

    require("c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506" in prepare, "canonical icon hash missing")
    require("WebKit/WKWebView" in prepare, "prepare script must explicitly audit WebKit absence")
    require("questions.generated.json" in prepare, "question bundle preparation missing")

    require(isinstance(questions, list) and len(questions) == 210, "question count must remain 210")
    require(len({q["id"] for q in questions}) == 210, "question IDs must remain unique")
    special = next((q for q in questions if q["id"] == "SHOSHI-R7-PM-33"), None)
    require(special is not None and special.get("scoring_status") == "all_correct" and special.get("official_answer_no") is None,
            "R7 PM33 all_correct contract broken")

    report = {
        "status": "PASS",
        "implementation": "SwiftUI native",
        "webview_tokens": 0,
        "tabs": 4,
        "daily_goals": [4, 8, 16],
        "default_daily_goal": 8,
        "weak_release_correct_streak": 3,
        "mid_session_resume": True,
        "json_backup": True,
        "trial_state_excluded_from_backup": True,
        "offline_bundle": True,
        "storekit2": True,
        "questions": 210,
        "r7pm33": "all_correct",
        "privacy_userdefaults_reason": "CA92.1",
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        REPORT.write_text(json.dumps({"status": "FAIL", "error": str(exc)}, ensure_ascii=False, indent=2), encoding="utf-8")
        raise
