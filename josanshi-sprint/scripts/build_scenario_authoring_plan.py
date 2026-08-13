#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data" / "scenario-authoring-plan.json"

FAMILY_ARCS = {
    "pregnancy": [
        "妊婦の背景・妊娠週数・主訴を提示する",
        "母体・胎児の追加所見から助産診断とリスクを更新する",
        "継続支援・受診連携・緊急度を判断する",
    ],
    "labor": [
        "入院時または分娩進行中の母体・胎児情報を提示する",
        "分娩進行・胎児状態・産道・娩出力を再評価する",
        "安全な分娩介助・医師連携・緊急対応を判断する",
    ],
    "postpartum": [
        "産褥日数・分娩経過・母体の訴えと育児状況を提示する",
        "退行性/進行性変化、授乳、心理社会面から状態を更新する",
        "セルフケア・育児支援・異常時連携を判断する",
    ],
    "neonatal": [
        "在胎週数・出生経過・出生直後または日齢の情報を提示する",
        "呼吸循環・体温・哺乳・黄疸・発育等の所見を追加する",
        "新生児ケア・蘇生/搬送・家族支援の優先度を判断する",
    ],
}


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def build_payload() -> dict:
    plan = build_plan()
    questions_by_scenario: dict[str, list[dict]] = defaultdict(list)
    for question in plan["questions"]:
        if question["scenarioId"]:
            questions_by_scenario[question["scenarioId"]].append(question)

    cases = []
    for scenario in plan["scenarios"]:
        members = sorted(
            questions_by_scenario[scenario["scenarioId"]],
            key=lambda q: q["scenarioIndex"],
        )
        total = scenario["scenarioTotal"]
        roles = ["assessment", "judgment", "action"] if total == 3 else ["assessment", "action"]
        arc = FAMILY_ARCS[scenario["scenarioFamily"]]
        if total == 2:
            arc = [arc[0], arc[2]]
        cases.append({
            "scenarioId": scenario["scenarioId"],
            "mockRound": scenario["mockRound"],
            "session": members[0]["session"],
            "scenarioTotal": total,
            "scenarioFamily": scenario["scenarioFamily"],
            "topicIds": [q["topicId"] for q in members],
            "intentIds": [q["intentId"] for q in members],
            "questionIds": [q["id"] for q in members],
            "questionRoles": roles,
            "clinicalArc": arc,
            "authoringRules": [
                "全設問が同一人物・同一妊娠/出産/新生児エピソードを共有する",
                "後続設問では時間経過または新しい所見を追加し、症例本文を単なる再掲にしない",
                "各設問は割当済みintentを問う。前問の正答を知らなくても後続設問を解ける情報を症例内に保持する",
                "診断名や治療を助産師単独で確定する設計にせず、必要時は医師・周産期チームへの連携を含める",
                "公式問題本文・学会CQ/Answer・図表を転載せず、症例値・文章は独自作成する",
            ],
            "status": "planned",
        })

    return {
        "schemaVersion": "1.0",
        "qualification": "助産師国家試験",
        "policy": "36 linked clinical cases are authored as coherent timelines before situation-setting question text is approved.",
        "cases": cases,
    }


def validate(payload: dict, *, print_cases: bool = False) -> None:
    cases = payload["cases"]
    if len(cases) != 36:
        fail(f"expected 36 cases, found {len(cases)}")
    if len({c["scenarioId"] for c in cases}) != 36:
        fail("scenario IDs are not unique")

    total_questions = sum(c["scenarioTotal"] for c in cases)
    if total_questions != 105:
        fail(f"expected 105 linked situation questions, found {total_questions}")

    round_counts = Counter(c["mockRound"] for c in cases)
    if round_counts != Counter({1: 12, 2: 12, 3: 12}):
        fail(f"scenario round counts invalid: {round_counts}")

    family_counts = Counter(c["scenarioFamily"] for c in cases)
    expected_families = Counter({"pregnancy": 9, "labor": 9, "postpartum": 9, "neonatal": 9})
    if family_counts != expected_families:
        fail(f"scenario family balance invalid: {family_counts}")

    for round_no in (1, 2, 3):
        round_family = Counter(
            c["scenarioFamily"] for c in cases if c["mockRound"] == round_no
        )
        if round_family != Counter({"pregnancy": 3, "labor": 3, "postpartum": 3, "neonatal": 3}):
            fail(f"R{round_no}: family balance invalid {round_family}")

    all_intents = []
    all_questions = []
    for case in cases:
        total = case["scenarioTotal"]
        if len(case["intentIds"]) != total or len(case["questionIds"]) != total:
            fail(f"{case['scenarioId']}: membership count mismatch")
        if len(case["questionRoles"]) != total or len(case["clinicalArc"]) != total:
            fail(f"{case['scenarioId']}: clinical arc count mismatch")
        if total not in {2, 3}:
            fail(f"{case['scenarioId']}: unsupported case size {total}")
        if len(case["authoringRules"]) < 5:
            fail(f"{case['scenarioId']}: authoring safety rules missing")
        all_intents.extend(case["intentIds"])
        all_questions.extend(case["questionIds"])

    if len(all_intents) != len(set(all_intents)) or len(all_intents) != 105:
        fail("situation intent membership must be 105 unique intents")
    if len(all_questions) != len(set(all_questions)) or len(all_questions) != 105:
        fail("situation question membership must be 105 unique question IDs")

    two_question_cases = [c for c in cases if c["scenarioTotal"] == 2]
    if len(two_question_cases) != 3:
        fail(f"expected three 2-question cases across three mocks, found {len(two_question_cases)}")
    if Counter(c["mockRound"] for c in two_question_cases) != Counter({1: 1, 2: 1, 3: 1}):
        fail("2-question case must occur once per mock")

    print("PASS: #14 linked-scenario authoring plan")
    print("  36 coherent cases / 105 situation-setting questions")
    print("  12 cases per mock; 9 cases per clinical family")
    print("  case sizes: 33 x 3 questions + 3 x 2 questions")
    print("  clinical arc roles and anti-fragmentation rules: PASS")
    if print_cases:
        print("  deterministic case mapping:")
        for case in cases:
            intents = ",".join(case["intentIds"])
            questions = ",".join(case["questionIds"])
            print(
                f"    {case['scenarioId']} | R{case['mockRound']} {case['session']} | "
                f"{case['scenarioFamily']} | n={case['scenarioTotal']} | intents={intents} | questions={questions}"
            )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--print-cases", action="store_true")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    payload = build_payload()
    validate(payload, print_cases=args.print_cases)
    if not args.check:
        args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"WROTE: {args.output}")


if __name__ == "__main__":
    main()
