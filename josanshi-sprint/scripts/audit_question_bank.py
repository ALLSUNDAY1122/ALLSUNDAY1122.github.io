#!/usr/bin/env python3
import argparse
import json
import re
from collections import Counter, defaultdict
from datetime import date
from difflib import SequenceMatcher
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"
REGISTRY = ROOT / "data" / "source-registry.json"
TOPIC_MAP = ROOT / "data" / "topic-source-map.json"

REQUIRED_QUESTION_FIELDS = [
    "id", "mockRound", "session", "slotNumber", "questionType",
    "subject", "topicId", "intentId", "intentFocus", "answerType",
    "prompt", "choices", "correctIndices", "explanation", "memoryPoint",
    "sourceIds", "sourceCheckedAt", "lawBaselineDate", "rightsBasis",
    "originType", "contentVersion", "auditStatus",
]
REQUIRED_SCENARIO_FIELDS = [
    "scenarioId", "mockRound", "session", "scenarioFamily", "scenarioText",
    "clinicalFrame", "questionIds", "sourceIds", "sourceCheckedAt",
    "rightsBasis", "auditStatus",
]
ALLOWED_AUDIT_STATUS = {"draft", "content-reviewed", "pass"}
ALLOWED_ANSWER_TYPES = {"singleChoice", "multiChoice"}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def normalize(text: str) -> str:
    value = str(text).lower()
    value = re.sub(r"\s+", "", value)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", value)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def missing(value) -> bool:
    return value is None or value == "" or value == [] or value == {}


def valid_date(value: str) -> bool:
    if not isinstance(value, str) or not DATE_RE.match(value):
        return False
    try:
        parsed = date.fromisoformat(value)
    except ValueError:
        return False
    return parsed <= date.today()


def audit(require_complete: bool) -> int:
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    topic_map = json.loads(TOPIC_MAP.read_text(encoding="utf-8"))
    plan = build_plan()

    questions = bank.get("questions")
    scenarios = bank.get("scenarios")
    if not isinstance(questions, list) or not isinstance(scenarios, list):
        print("FAIL: questions/scenarios must be arrays")
        return 1

    errors: list[str] = []
    warnings: list[str] = []
    plan_by_id = {q["id"]: q for q in plan["questions"]}
    scenario_plan = {s["scenarioId"]: s for s in plan["scenarios"]}
    source_by_id = {s["id"]: s for s in registry["sources"]}
    topic_sources = {t["topicId"]: set(t["sourceIds"]) for t in topic_map["topics"]}

    question_ids = [q.get("id") for q in questions]
    scenario_ids = [s.get("scenarioId") for s in scenarios]
    if len(question_ids) != len(set(question_ids)):
        fail(errors, "問題ID重複")
    if len(scenario_ids) != len(set(scenario_ids)):
        fail(errors, "scenarioId重複")

    scenario_by_id = {s.get("scenarioId"): s for s in scenarios if s.get("scenarioId")}
    normalized_questions: list[tuple[str, str, str]] = []
    used_intents: list[str] = []

    for index, question in enumerate(questions, start=1):
        label = question.get("id") or f"index:{index}"
        for field in REQUIRED_QUESTION_FIELDS:
            if missing(question.get(field)):
                fail(errors, f"{label}: 必須フィールド欠損 {field}")

        planned = plan_by_id.get(question.get("id"))
        if planned is None:
            fail(errors, f"{label}: generation planに存在しないID")
            continue

        exact_fields = [
            "mockRound", "session", "slotNumber", "questionType", "subject",
            "topicId", "intentId", "intentFocus",
        ]
        for field in exact_fields:
            if question.get(field) != planned.get(field):
                fail(errors, f"{label}: 計画不一致 {field}={question.get(field)!r} expected={planned.get(field)!r}")

        for field in ["scenarioId", "scenarioIndex", "scenarioTotal"]:
            if question.get(field) != planned.get(field):
                fail(errors, f"{label}: 症例連結不一致 {field}")

        answer_type = question.get("answerType")
        choices = question.get("choices")
        correct = question.get("correctIndices")
        if answer_type not in ALLOWED_ANSWER_TYPES:
            fail(errors, f"{label}: answerType不正 {answer_type}")
        if not isinstance(choices, list) or len(choices) not in {4, 5}:
            fail(errors, f"{label}: choicesは4または5件必要")
        elif len({normalize(choice) for choice in choices}) != len(choices):
            fail(errors, f"{label}: 選択肢重複")
        if answer_type == "singleChoice":
            if not isinstance(correct, list) or len(correct) != 1:
                fail(errors, f"{label}: singleChoiceは正答1件")
        elif answer_type == "multiChoice":
            if not isinstance(correct, list) or len(correct) < 2:
                fail(errors, f"{label}: multiChoiceは正答2件以上")
        if isinstance(correct, list) and isinstance(choices, list):
            if len(correct) != len(set(correct)):
                fail(errors, f"{label}: correctIndices重複")
            for value in correct:
                if not isinstance(value, int) or not (0 <= value < len(choices)):
                    fail(errors, f"{label}: correctIndices範囲外 {value}")

        if question.get("originType") != "original_from_primary_source":
            fail(errors, f"{label}: originTypeはoriginal_from_primary_sourceのみ許可")
        if question.get("contentVersion") != bank.get("contentVersion"):
            fail(errors, f"{label}: contentVersion不一致")
        if question.get("auditStatus") not in ALLOWED_AUDIT_STATUS:
            fail(errors, f"{label}: auditStatus不正")

        for field in ["sourceCheckedAt", "lawBaselineDate"]:
            if not valid_date(question.get(field)):
                fail(errors, f"{label}: {field}の日付不正/未来日")

        source_ids = question.get("sourceIds")
        if not isinstance(source_ids, list) or not source_ids:
            fail(errors, f"{label}: sourceIds欠損")
            source_ids = []
        unknown = [sid for sid in source_ids if sid not in source_by_id]
        if unknown:
            fail(errors, f"{label}: 未登録sourceIds {unknown}")
        planned_sources = topic_sources.get(question.get("topicId"), set())
        if source_ids and not (set(source_ids) & planned_sources):
            fail(errors, f"{label}: topic-source mapのアンカーを1件以上含める必要あり")

        rights = str(question.get("rightsBasis", "")).lower()
        if "original" not in rights or "no direct reproduction" not in rights:
            fail(errors, f"{label}: rightsBasisに独自表現・直接転載なしを明示すること")
        restricted_used = [
            sid for sid in source_ids
            if sid in source_by_id and str(source_by_id[sid].get("directReproduction", "")).lower().startswith("no")
        ]
        if restricted_used and "no direct reproduction" not in rights:
            fail(errors, f"{label}: 転載制限source使用時のrights guard欠損 {restricted_used}")

        prompt = question.get("prompt")
        explanation = question.get("explanation")
        memory = question.get("memoryPoint")
        if isinstance(prompt, str) and len(prompt.strip()) < 10:
            fail(errors, f"{label}: 問題本文が短すぎる")
        if isinstance(explanation, str) and len(explanation.strip()) < 20:
            fail(errors, f"{label}: 解説が短すぎる")
        if isinstance(memory, str) and len(memory.strip()) < 5:
            fail(errors, f"{label}: ここだけ覚えるが短すぎる")

        if isinstance(prompt, str) and prompt.strip():
            normalized_questions.append((label, question.get("topicId", ""), normalize(prompt)))
        if question.get("intentId"):
            used_intents.append(question["intentId"])

        if question.get("questionType") == "situation":
            scenario_id = question.get("scenarioId")
            if scenario_id not in scenario_by_id:
                fail(errors, f"{label}: 対応するscenario record欠損 {scenario_id}")
        else:
            if any(question.get(field) is not None for field in ["scenarioId", "scenarioIndex", "scenarioTotal"]):
                fail(errors, f"{label}: general問題にscenario fieldsがある")

    if len(used_intents) != len(set(used_intents)):
        fail(errors, "intentId重複: 同一問題意図を複数問題に使用")

    exact_map: defaultdict[str, list[str]] = defaultdict(list)
    for qid, _, text in normalized_questions:
        exact_map[text].append(qid)
    for labels in exact_map.values():
        if len(labels) > 1:
            fail(errors, f"問題本文完全一致: {labels}")

    for i in range(len(normalized_questions)):
        id_a, topic_a, text_a = normalized_questions[i]
        for j in range(i + 1, len(normalized_questions)):
            id_b, topic_b, text_b = normalized_questions[j]
            ratio = SequenceMatcher(None, text_a, text_b).ratio()
            if ratio >= 0.90:
                fail(errors, f"高類似問題 {ratio:.2f}: {id_a} <-> {id_b}")
            elif topic_a == topic_b and ratio >= 0.75:
                warnings.append(f"同一論点類似 要レビュー {ratio:.2f}: {id_a} <-> {id_b}")

    for index, scenario in enumerate(scenarios, start=1):
        label = scenario.get("scenarioId") or f"scenario-index:{index}"
        for field in REQUIRED_SCENARIO_FIELDS:
            if missing(scenario.get(field)):
                fail(errors, f"{label}: 必須フィールド欠損 {field}")
        planned = scenario_plan.get(scenario.get("scenarioId"))
        if planned is None:
            fail(errors, f"{label}: generation planにないscenario")
            continue
        for field in ["mockRound", "scenarioFamily"]:
            if scenario.get(field) != planned.get(field):
                fail(errors, f"{label}: 症例計画不一致 {field}")
        if scenario.get("auditStatus") not in ALLOWED_AUDIT_STATUS:
            fail(errors, f"{label}: auditStatus不正")
        if not valid_date(scenario.get("sourceCheckedAt")):
            fail(errors, f"{label}: sourceCheckedAt不正/未来日")
        if not isinstance(scenario.get("clinicalFrame"), dict) or len(scenario["clinicalFrame"]) < 3:
            fail(errors, f"{label}: clinicalFrameは3要素以上必要")
        if not isinstance(scenario.get("scenarioText"), str) or len(scenario["scenarioText"].strip()) < 30:
            fail(errors, f"{label}: scenarioTextが短すぎる")
        question_ids_in_scenario = scenario.get("questionIds") or []
        actual_members = [q for q in questions if q.get("scenarioId") == scenario.get("scenarioId")]
        actual_ids = [q.get("id") for q in sorted(actual_members, key=lambda q: q.get("scenarioIndex") or 0)]
        if question_ids_in_scenario != actual_ids:
            fail(errors, f"{label}: questionIdsと問題側scenarioIndexの順序が不一致")
        if actual_members and len(actual_members) != planned["scenarioTotal"]:
            fail(errors, f"{label}: 症例設問数 {len(actual_members)}/{planned['scenarioTotal']}")
        scenario_sources = scenario.get("sourceIds") or []
        if any(sid not in source_by_id for sid in scenario_sources):
            fail(errors, f"{label}: 未登録sourceId")
        rights = str(scenario.get("rightsBasis", "")).lower()
        if "original" not in rights or "no direct reproduction" not in rights:
            fail(errors, f"{label}: rightsBasis不足")

    # A scenario record cannot exist without its full linked set; this avoids
    # approving half-written clinical cases whose later questions change the patient timeline.
    for scenario_id in scenario_by_id:
        planned = scenario_plan.get(scenario_id)
        if planned:
            members = [q for q in questions if q.get("scenarioId") == scenario_id]
            if len(members) != planned["scenarioTotal"]:
                fail(errors, f"{scenario_id}: 症例は全設問を一括作成すること")

    if require_complete:
        expected_ids = set(plan_by_id)
        actual_ids = set(question_ids)
        if len(questions) != 330:
            fail(errors, f"Full bank: questions {len(questions)}/330")
        if Counter(q.get("questionType") for q in questions) != Counter({"general": 225, "situation": 105}):
            fail(errors, "Full bank: 225 general + 105 situationではない")
        if len(scenarios) != 36:
            fail(errors, f"Full bank: scenarios {len(scenarios)}/36")
        if actual_ids != expected_ids:
            fail(errors, f"Full bank: 計画ID差分 missing={len(expected_ids-actual_ids)} extra={len(actual_ids-expected_ids)}")
        if any(q.get("auditStatus") != "pass" for q in questions):
            fail(errors, "Full bank: auditStatus=passでない問題あり")
        if any(s.get("auditStatus") != "pass" for s in scenarios):
            fail(errors, "Full bank: auditStatus=passでない症例あり")

    print("=== #14 助産師国家試験 本番問題バンク監査 ===")
    print(f"questions: {len(questions)}/330")
    print(f"scenarios: {len(scenarios)}/36")
    print(f"general/situation: {Counter(q.get('questionType') for q in questions)}")
    print(f"unique intents: {len(set(used_intents))}/{len(used_intents)}")
    print(f"mode: {'FULL' if require_complete else 'PARTIAL'}")

    if warnings:
        print("\nWARNINGS")
        for message in warnings:
            print(f"- {message}")

    if errors:
        print("\nFAIL")
        for message in errors:
            print(f"- {message}")
        return 1

    print("\nPASS: question-bank structural / source / rights / duplication gates")
    if not require_complete:
        print("NOTE: partial PASS does not mean the 330-question content bank is complete.")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    raise SystemExit(audit(args.require_complete))


if __name__ == "__main__":
    main()
