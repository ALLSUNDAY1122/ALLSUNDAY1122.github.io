#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "ios" / "health-manager-1"
QUESTIONS = BASE / "Resources" / "questions.json"
HTML = BASE / "Resources" / "index.html"
STORE = BASE / "HealthManager1" / "StoreKitManager.swift"
WEBVIEW = BASE / "HealthManager1" / "WebView.swift"

errors: list[str] = []
notes: list[str] = []


def require(ok: bool, message: str) -> None:
    if not ok:
        errors.append(message)


def norm(text: str) -> str:
    return re.sub(r"[\s　、。,.!?！？・（）()「」『』\-ー]", "", text).lower()


questions = json.loads(QUESTIONS.read_text(encoding="utf-8"))
html = HTML.read_text(encoding="utf-8")
store = STORE.read_text(encoding="utf-8")
webview = WEBVIEW.read_text(encoding="utf-8")

# --- Content completeness / integrity ---
require(isinstance(questions, list), "questions.json must be a JSON array")
require(len(questions) == 264, f"question count must be 264, got {len(questions)}")

ids = [q.get("id") for q in questions]
require(all(isinstance(v, str) and v.strip() for v in ids), "every question must have a non-empty id")
require(len(ids) == len(set(ids)), "question ids must be unique")

round_counts = Counter(q.get("round") for q in questions)
require(len(round_counts) == 6, f"expected 6 exam/exercise sets, got {len(round_counts)}: {dict(round_counts)}")
require(all(v == 44 for v in round_counts.values()), f"every set must contain 44 questions: {dict(round_counts)}")

required_text = (
    "id", "round", "roundTitle", "label", "conceptKey", "stem", "short", "key", "detail",
    "sourceRef", "lawAsOf", "auditStatus", "auditSourceURL", "semanticIndependence", "independenceReason",
)
for i, q in enumerate(questions, 1):
    qid = q.get("id") or f"row-{i}"
    for field in required_text:
        value = q.get(field)
        require(isinstance(value, str) and value.strip(), f"{qid}: missing/empty {field}")
    choices = q.get("choices")
    require(isinstance(choices, list) and len(choices) == 5, f"{qid}: choices must contain exactly 5 items")
    if isinstance(choices, list):
        require(all(isinstance(x, str) and x.strip() for x in choices), f"{qid}: every choice must be non-empty text")
        require(len({norm(x) for x in choices if isinstance(x, str)}) == len(choices), f"{qid}: duplicate choices")
    ans = q.get("ans")
    require(isinstance(ans, int) and not isinstance(ans, bool) and 0 <= ans < 5, f"{qid}: ans must be integer 0..4")
    require(str(q.get("sourceRef", "")).startswith("https://"), f"{qid}: sourceRef must be https URL")
    require(str(q.get("auditSourceURL", "")).startswith("https://"), f"{qid}: auditSourceURL must be https URL")
    require(q.get("semanticIndependence") == "independent", f"{qid}: semanticIndependence must be independent")
    require(q.get("originalExpression") is True, f"{qid}: originalExpression must be true")

stem_groups: dict[str, list[str]] = {}
for q in questions:
    stem_groups.setdefault(norm(q.get("stem", "")), []).append(q.get("id", "?"))
exact_dupes = [members for key, members in stem_groups.items() if key and len(members) > 1]
require(not exact_dupes, f"exact-normalized duplicate stems detected: {exact_dupes[:5]}")

labels = {q.get("label") for q in questions}
for label in ("関係法令", "労働衛生", "労働生理"):
    require(label in labels, f"required subject label missing: {label}")
for round_name in round_counts:
    round_labels = {q.get("label") for q in questions if q.get("round") == round_name}
    for label in ("関係法令", "労働衛生", "労働生理"):
        require(label in round_labels, f"{round_name}: required subject missing: {label}")

# --- Learning Acceptance Contract ---
# These are product-facing behaviors rather than implementation-shape checks.
for marker, message in (
    ("間違えた問題をすぐ復習", "result -> wrong-answer review CTA is missing"),
    ('id="rReview"', "wrong-answer review action wiring is missing"),
    ('id="rAgain"', "retry action wiring is missing"),
    ("LAST.wrongIds", "result must retain wrong-answer ids for immediate review"),
    ("STATE.active=SESSION", "active session persistence is missing"),
    ("localStorage", "local learning-state persistence is missing"),
):
    require(marker in html, message)

# Daily sprint sizes must be represented in product UI/logic.
for n in (4, 8, 16):
    require(re.search(rf"(?:goal|daily|sprint|size|count)[^\n]{{0,120}}\b{n}\b|\b{n}\b[^\n]{{0,120}}(?:問|goal|daily|sprint)", html, re.I) is not None,
            f"daily sprint size {n} is not represented")

# --- StoreKit / entitlement Regression Gate ---
store_markers = (
    'monthlyProductID = "jp.allsunday1122.healthmanager1.monthly"',
    'lifetimeProductID = "jp.allsunday1122.healthmanager1.lifetime"',
    'monthlyJapanDisplayPrice = "¥200"',
    'lifetimeJapanDisplayPrice = "¥800"',
    "Transaction.updates",
    "Transaction.currentEntitlements",
    "transaction.revocationDate == nil",
    "subscription.isEligibleForIntroOffer",
    ".freeTrial",
    "product.purchase()",
    "case .pending:",
    "case .userCancelled:",
    "AppStore.sync()",
    "case .unverified:",
)
for marker in store_markers:
    require(marker in store, f"StoreKit regression marker missing: {marker}")

web_markers = (
    'controller.add(context.coordinator, name: "storekit")',
    'case "status":',
    'case "purchase":',
    'case "restore":',
    "window.__storekitUpdate",
    "loadFileURL",
    "didFailProvisionalNavigation",
    "教材画面を表示できません",
)
for marker in web_markers:
    require(marker in webview, f"WKWebView/StoreKit bridge regression marker missing: {marker}")

# Fail closed: bundled HTML must expose the receiver expected by native bridge.
require("__storekitUpdate" in html, "web product does not expose __storekitUpdate receiver")

if errors:
    print("FAIL: HM1 product preflight")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PASS: HM1 product preflight")
print(f"PASS: {len(questions)} questions / {len(round_counts)} sets / {dict(round_counts)}")
print("PASS: question ids, 5-choice answer ranges, required metadata, HTTPS sources, original-expression flags")
print("PASS: exact-normalized duplicate stems = 0")
print("PASS: start/persist -> answer/understand -> result -> wrong review -> retry learning loop represented")
print("PASS: StoreKit IDs, JPN display prices, entitlement updates, revocation, trial eligibility, purchase/pending/cancel/restore/verification")
print("PASS: WKWebView bridge and visible runtime-failure fallback represented")
