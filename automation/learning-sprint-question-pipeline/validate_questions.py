#!/usr/bin/env python3
import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path


def normalize(text: str) -> str:
    text = str(text).lower()
    text = re.sub(r"\s+", "", text)
    text = re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", text)
    return text


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def fail(errors, message):
    errors.append(message)


def validate_index(value, size):
    return isinstance(value, int) and 0 <= value < size


def validate_answer_v2(q, label, errors):
    answer_type = q.get("answer_type") or q.get("answerType")
    answer = q.get("answer")
    choices = q.get("choices")
    scoring_status = q.get("scoring_status") or q.get("officialScoringStatus") or "normal"
    accepted = q.get("accepted_answers")
    if accepted is None:
        accepted = q.get("officialAcceptedAnswers")

    allowed_status = {"normal", "excluded", "include_if_correct_exclude_if_wrong", "multiple_accepted"}
    if scoring_status not in allowed_status:
        fail(errors, f"{label}: scoring_status不正 {scoring_status}")

    if scoring_status == "excluded":
        if answer is not None:
            fail(errors, f"{label}: excluded問題にanswerが設定されている")
        return

    if answer_type == "numeric":
        if not isinstance(answer, (int, float)) or isinstance(answer, bool):
            fail(errors, f"{label}: numeric answer不正 {answer}")
    elif answer_type == "singleChoice":
        if not isinstance(choices, list):
            fail(errors, f"{label}: choices不正")
        elif choices:
            if not validate_index(answer, len(choices)):
                fail(errors, f"{label}: singleChoice answer不正 {answer}")
        elif not q.get("requires_media") and not q.get("requiresMedia"):
            fail(errors, f"{label}: singleChoiceで選択肢が空かつmedia指定なし")
    elif answer_type == "multiChoice":
        if not isinstance(choices, list) or len(choices) < 2:
            fail(errors, f"{label}: multiChoice choices不正")
        if not isinstance(answer, list) or len(answer) < 2 or len(set(answer)) != len(answer):
            fail(errors, f"{label}: multiChoice answer不正 {answer}")
        elif isinstance(choices, list):
            for idx in answer:
                if not validate_index(idx, len(choices)):
                    fail(errors, f"{label}: multiChoice index範囲外 {idx}")
    else:
        fail(errors, f"{label}: answer_type不正 {answer_type}")

    if scoring_status == "multiple_accepted":
        if not isinstance(accepted, list) or len(accepted) < 2:
            fail(errors, f"{label}: multiple_acceptedだがaccepted_answers不足")
    elif accepted is not None and not isinstance(accepted, list):
        fail(errors, f"{label}: accepted_answers形式不正")


def validate(config_path: Path) -> int:
    config = load_json(config_path)
    base = config_path.parent
    questions_path = (base / config["questions_file"]).resolve()
    questions = load_json(questions_path)

    if not isinstance(questions, list):
        print("FAIL: questions_file must contain a JSON array")
        return 1

    qualification = config.get("qualification", config_path.parent.name)
    rounds = int(config.get("rounds", 3))
    subjects = config.get("subjects", {})
    threshold = float(config.get("similarity_threshold", 0.90))
    required_fields = config.get("required_fields", [])

    errors = []
    warnings = []

    expected_total = rounds * sum(int(v) for v in subjects.values())
    if len(questions) != expected_total:
        fail(errors, f"総問題数: {len(questions)}/{expected_total}")

    ids = [q.get("id") for q in questions]
    dup_ids = [x for x, c in Counter(ids).items() if x and c > 1]
    if dup_ids:
        fail(errors, f"問題ID重複: {dup_ids}")

    counts = defaultdict(int)
    normalized_map = defaultdict(list)

    for idx, q in enumerate(questions, 1):
        label = q.get("id") or f"index:{idx}"
        for field in required_fields:
            value = q.get(field)
            if value is None or value == "" or value == []:
                fail(errors, f"{label}: 必須フィールド欠損 {field}")

        round_no = q.get("round")
        subject = q.get("subject")
        if not isinstance(round_no, int) or not (1 <= round_no <= rounds):
            fail(errors, f"{label}: round不正 {round_no}")
        if subject not in subjects:
            fail(errors, f"{label}: subject不正 {subject}")
        if isinstance(round_no, int) and subject in subjects:
            counts[(round_no, subject)] += 1

        # v1: legacy single-choice schema. v2: flexible answer schema used by
        # qualifications that contain multi-choice, numeric or scoring exclusions.
        if "answer_type" in q or "answerType" in q:
            validate_answer_v2(q, label, errors)
        else:
            choices = q.get("choices")
            correct_index = q.get("correct_index")
            if not isinstance(choices, list) or len(choices) < 2:
                fail(errors, f"{label}: 選択肢が2件未満")
            elif not isinstance(correct_index, int) or not (0 <= correct_index < len(choices)):
                fail(errors, f"{label}: correct_index不正 {correct_index}")

        question_text = q.get("question", "")
        if question_text:
            normalized_map[normalize(question_text)].append(label)

        if q.get("origin_type") not in {"original_from_primary_source", "licensed_official", "public_domain_or_law"}:
            warnings.append(f"{label}: origin_typeを要確認 {q.get('origin_type')}")

    for round_no in range(1, rounds + 1):
        for subject, expected in subjects.items():
            actual = counts[(round_no, subject)]
            if actual != int(expected):
                fail(errors, f"第{round_no}回/{subject}: {actual}/{expected}")

    exact_dups = {k: v for k, v in normalized_map.items() if k and len(v) > 1}
    for labels in exact_dups.values():
        fail(errors, f"問題本文完全一致: {labels}")

    normalized_questions = []
    for q in questions:
        text = normalize(q.get("question", ""))
        if text:
            normalized_questions.append((q.get("id", "?"), q.get("topic", ""), text))

    for i in range(len(normalized_questions)):
        id_a, topic_a, text_a = normalized_questions[i]
        for j in range(i + 1, len(normalized_questions)):
            id_b, topic_b, text_b = normalized_questions[j]
            ratio = SequenceMatcher(None, text_a, text_b).ratio()
            if ratio >= threshold:
                fail(errors, f"高類似問題 {ratio:.2f}: {id_a} <-> {id_b}")
            elif topic_a and topic_a == topic_b and ratio >= max(0.72, threshold - 0.15):
                warnings.append(f"同一論点の類似を要確認 {ratio:.2f}: {id_a} <-> {id_b}")

    print(f"=== 学びスプリント問題監査: {qualification} ===")
    print(f"問題数: {len(questions)}/{expected_total}")
    for round_no in range(1, rounds + 1):
        details = ", ".join(
            f"{subject}={counts[(round_no, subject)]}/{expected}"
            for subject, expected in subjects.items()
        )
        print(f"第{round_no}回: {details}")

    if warnings:
        print("\nWARNINGS")
        for message in warnings:
            print(f"- {message}")

    if errors:
        print("\nFAIL")
        for message in errors:
            print(f"- {message}")
        return 1

    print("\nPASS: 構造・件数・重複・高類似・必須項目の機械監査に合格")
    print("NOTE: 正答内容、法令適用、著作権・利用規約の法的判断は別監査が必要です。")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path, help="learning-sprint-audit.json のパス")
    args = parser.parse_args()
    sys.exit(validate(args.config.resolve()))


if __name__ == "__main__":
    main()
