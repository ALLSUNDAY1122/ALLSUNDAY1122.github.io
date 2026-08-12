#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
ios = root / "ios" / "KanteishiShortAnswer"
files = {
    "theme": (ios / "AppTheme.swift").read_text(encoding="utf-8"),
    "home": (ios / "ContentView.swift").read_text(encoding="utf-8"),
    "quiz": (ios / "QuizResultViews.swift").read_text(encoding="utf-8"),
    "history": (ios / "HistorySettingsViews.swift").read_text(encoding="utf-8"),
    "core": (ios / "AppCore.swift").read_text(encoding="utf-8"),
    "purchase": (ios / "PremiumPurchaseStore.swift").read_text(encoding="utf-8"),
}

checks = [
    ("paper color", "0xF7F3EA", files["theme"]),
    ("28px grid", "let step: CGFloat = 28", files["theme"]),
    ("82px ring", "var size: CGFloat = 82", files["theme"]),
    ("four tabs", "case home, mock, history, settings", files["core"]),
    ("max width 520", ".frame(maxWidth: 520)", files["home"]),
    ("outer padding 18", ".padding(.horizontal, 18)", files["home"]),
    ("home qualification", "不動産鑑定士試験・短答式", files["home"]),
    ("resume", "続きから再開", files["home"]),
    ("standard sprint", "今日のスプリント", files["home"]),
    ("weak review", "苦手をつぶす", files["home"]),
    ("mock", "模擬試験", files["home"]),
    ("unknown", "わからない", files["quiz"]),
    ("mark overlay", "response.correct ? \"○\" : \"×\"", files["quiz"]),
    ("memory block", "ここだけ覚える", files["quiz"]),
    ("history heatmap", "store.heatmap()", files["history"]),
    ("weak 3 streak", "3連続正解で解除", files["history"]),
    ("daily goals", "ForEach([4,8,16]", files["history"].replace(" ", "")),
    ("font sizes", "FontSizePreference.allCases", files["history"]),
    ("JSON backup", "JSONバックアップ", files["history"]),
    ("StoreKit2", "import StoreKit", files["purchase"]),
    ("Application Support", ".applicationSupportDirectory", files["core"]),
    ("backup sanitize", "private static func sanitize", files["core"]),
]

errors = []
for name, needle, text in checks:
    if needle not in text:
        errors.append(f"missing: {name}")

all_swift = "\n".join(files.values())
for prohibited in ["WKWebView", "UIWebView"]:
    if prohibited in all_swift:
        errors.append(f"prohibited: {prohibited}")

if errors:
    print("FAIL v2.1 native UI static audit")
    for error in errors:
        print("-", error)
    sys.exit(1)

print("PASS v2.1 native UI static audit")
print("- paper/grid/tokens")
print("- 4 tabs and 520/18 layout")
print("- home/resume/sprint/weak/mock")
print("- quiz unknown + shu mark + memory block")
print("- history heatmap + weak 3-streak")
print("- goals/font/backup/StoreKit2")
print("- Application Support persistence + backup sanitization")
