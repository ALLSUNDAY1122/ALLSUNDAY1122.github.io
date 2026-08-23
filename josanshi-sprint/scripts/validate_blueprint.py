#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT = ROOT / "data" / "question-blueprint.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


data = json.loads(BLUEPRINT.read_text(encoding="utf-8"))
exam = data["latestConfirmedExam"]
bank = data["productionBank"]
topics = data["topics"]

if exam["total"] != 110:
    fail("latest exam total must be 110")
if exam["morning"]["total"] != 55 or exam["afternoon"]["total"] != 55:
    fail("morning/afternoon totals must both be 55")
if exam["morning"]["general"] + exam["morning"]["situation"] != 55:
    fail("morning general+situation must equal 55")
if exam["afternoon"]["general"] + exam["afternoon"]["situation"] != 55:
    fail("afternoon general+situation must equal 55")
if exam["fullDay"]["general"] != 75 or exam["fullDay"]["situation"] != 35:
    fail("full-day structure must be 75 general + 35 situation")
if sum(exam["morning"]["scenarioGroups"]) != 17:
    fail("morning scenario groups must total 17")
if sum(exam["afternoon"]["scenarioGroups"]) != 18:
    fail("afternoon scenario groups must total 18")
if len(exam["morning"]["scenarioGroups"]) + len(exam["afternoon"]["scenarioGroups"]) != 12:
    fail("latest structure must contain 12 scenario cases")

if bank["mockSetCount"] != 3 or bank["questionsPerMock"] != 110 or bank["totalTarget"] != 330:
    fail("production target must be 3 x 110 = 330")
if len(topics) != 66:
    fail(f"R5 large-item catalog must contain 66 topics, found {len(topics)}")
if len({topic["topicId"] for topic in topics}) != 66:
    fail("topic IDs must be unique")
if any(topic["bankTarget"] != 5 for topic in topics):
    fail("each R5 large item must have a five-question bank target")
if sum(topic["bankTarget"] for topic in topics) != 330:
    fail("topic bank targets must total 330")

per_mock = [0, 0, 0]
for topic in topics:
    distribution = topic["mockDistribution"]
    if len(distribution) != 3 or sum(distribution) != 5:
        fail(f"{topic['topicId']}: mock distribution must contain 3 values totaling 5")
    if sorted(distribution) != [1, 2, 2]:
        fail(f"{topic['topicId']}: expected a 1/2/2 distribution to prevent uncovered mocks")
    for index, count in enumerate(distribution):
        per_mock[index] += count
    if topic["officialFixedQuestionQuota"] is not False:
        fail(f"{topic['topicId']}: design quota must not be represented as an official fixed quota")

if per_mock != [110, 110, 110]:
    fail(f"topic allocation must total 110 per mock, got {per_mock}")

subjects = {}
for topic in topics:
    subjects.setdefault(topic["subject"], 0)
    subjects[topic["subject"]] += topic["bankTarget"]
expected_subject_totals = {
    "基礎助産学": 100,
    "助産診断・技術学": 185,
    "地域母子保健": 20,
    "助産管理": 25,
}
if subjects != expected_subject_totals:
    fail(f"unexpected design subject totals: {subjects}")

required = {
    "id", "mockRound", "session", "slotNumber", "questionType", "subject", "topicId",
    "stem", "choices", "correct", "explanation", "memoryPoint", "sourceURL",
    "sourceCheckedAt", "lawBaselineDate", "contentVersion", "origin", "rightsBasis",
    "scenarioId", "scenarioIndex", "scenarioTotal",
}
actual = set(bank["requiredQuestionMetadata"])
if required != actual:
    fail(f"question metadata mismatch: missing={sorted(required - actual)}, extra={sorted(actual - required)}")

print("PASS: #14 question blueprint")
print("  latest exam: 110 = 75 general + 35 situation, 12 scenario cases")
print("  production: 3 x 110 = 330")
print("  R5 large items: 66 x 5 = 330")
print(f"  per mock topic allocations: {per_mock}")
print(f"  design subject totals: {subjects}")
