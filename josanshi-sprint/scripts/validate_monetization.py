#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FEATURE = ROOT / "ios" / "JosanshiSprintFeature" / "Sources" / "JosanshiSprintFeature"
CONFIG = (FEATURE / "JosanshiExamConfiguration.swift").read_text(encoding="utf-8")
POLICY = (FEATURE / "JosanshiMonetization.swift").read_text(encoding="utf-8")
MODEL = (FEATURE / "JosanshiDashboardModel.swift").read_text(encoding="utf-8")
PAYWALL = (FEATURE / "JosanshiPremiumPaywallView.swift").read_text(encoding="utf-8")
ROOT_VIEW = (FEATURE / "JosanshiRootView.swift").read_text(encoding="utf-8")
QUESTIONS = json.loads((ROOT / "data" / "questions.json").read_text(encoding="utf-8"))

EXPECTED_BUNDLE = "jp.allsunday1122.josanshi"
EXPECTED_PROFILE = "josanshi_appstore"
EXPECTED_PRODUCT = "jp.allsunday1122.josanshi.premium"
SUBJECTS = ["基礎助産学", "助産診断・技術学", "地域母子保健", "助産管理"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


# Canonical identity: three approved values are exact; Apple-issued numeric ID must remain absent.
require(f'bundleID: "{EXPECTED_BUNDLE}"' in CONFIG, "canonical Bundle ID mismatch")
require(f'codemagicProfile: "{EXPECTED_PROFILE}"' in CONFIG, "canonical Codemagic profile mismatch")
require(f'productID: "{EXPECTED_PRODUCT}"' in CONFIG, "canonical IAP product ID mismatch")
require("appStoreConnectAppID: nil" in CONFIG, "numeric App Store Connect App ID must remain unset until Apple issues it")
require(not re.search(r'appStoreConnectAppID:\s*"\d+"', CONFIG), "guessed numeric App Store Connect App ID detected")

# Product model and declared boundary.
require('purchaseModel = "non_consumable"' in POLICY, "purchase model must be non-consumable")
require("freeQuestionCountPerSubject = 15" in POLICY, "free per-subject count must be 15")
require("freeQuestionTarget = freeQuestionCountPerSubject * JosanshiExamConfiguration.subjects.count" in POLICY, "free target must derive from subjects")

# Reproduce the Swift free-pool rule from the audited production bank.
rows = QUESTIONS["questions"] if isinstance(QUESTIONS, dict) else QUESTIONS
free_ids: set[str] = set()
free_by_subject: Counter[str] = Counter()
for subject in SUBJECTS:
    candidates = [q for q in rows if q["subject"] == subject and q["questionType"] == "general"]
    candidates.sort(key=lambda q: (q["mockRound"], q["session"], q["slotNumber"], q["id"]))
    selected = candidates[:15]
    require(len(selected) == 15, f"{subject} does not have 15 general questions for free pool")
    for q in selected:
        free_ids.add(q["id"])
        free_by_subject[subject] += 1

require(len(free_ids) == 60, f"free pool must be 60, got {len(free_ids)}")
require(len(rows) - len(free_ids) == 270, "premium pool must be 270")
require(all(free_by_subject[s] == 15 for s in SUBJECTS), f"free pool subject balance mismatch: {dict(free_by_subject)}")
require(all(q["questionType"] == "general" for q in rows if q["id"] in free_ids), "situation-setting question leaked into free pool")
require(not any(q["scenarioId"] for q in rows if q["id"] in free_ids), "linked scenario question leaked into free pool")

# Premium access and restore contract.
for needle in [
    "PurchaseController(productID: productID)",
    "startStandardSprint(isPremium: isPremium)",
    "guard requirePremium() else { return }",
    "purchasePremium() async",
    "restorePremium() async",
    "sessionContainsPremiumQuestion",
]:
    require(needle in MODEL, f"missing entitlement gate: {needle}")

for needle in [
    'Text("購入を復元")',
    'accessibilityIdentifier("purchase-premium")',
    'accessibilityIdentifier("restore-premium")',
    "await model.purchasePremium()",
    "await model.restorePremium()",
    "case .pending:",
    "case .cancelled:",
    "case .unavailable(let message), .failed(let message):",
]:
    require(needle in PAYWALL, f"missing purchase/restore UI state: {needle}")

# Locked routes must remain visible rather than disappearing, so users understand the upgrade.
for needle in [
    'title: "苦手をつぶす"',
    'title: "模擬試験"',
    'Text("分野から解く")',
    'title: "詳細な記録はPremium"',
    'Text("バックアップ・復元はPremium機能です。")',
]:
    require(needle in ROOT_VIEW, f"missing Premium boundary UI: {needle}")

print("PASS: #14 monetization contract")
print(f"  identity: {EXPECTED_BUNDLE} / {EXPECTED_PROFILE} / {EXPECTED_PRODUCT}")
print("  App Store Connect numeric ID: unset / Apple-issued only")
print(f"  free: {len(free_ids)} = 15 x 4 subjects, general-only")
print(f"  premium: {len(rows) - len(free_ids)}")
print("  StoreKit: non-consumable purchase + restore + pending/cancel/failure UI")
