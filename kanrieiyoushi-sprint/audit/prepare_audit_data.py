#!/usr/bin/env python3
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
CONFIG = BASE / "learning-sprint-audit.json"


def load_config():
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def extract_json_array(js_text: str):
    start = js_text.find("[")
    end = js_text.rfind("]")
    if start < 0 or end < start:
        raise ValueError("JS内の問題配列を検出できません")
    return json.loads(js_text[start:end + 1])


def load_sources(config):
    rows = []
    for rel in config.get("source_files", []):
        path = (BASE / rel).resolve()
        rows.extend(extract_json_array(path.read_text(encoding="utf-8")))
    return rows


def canonicalize(rows, config):
    subjects = config["subjects"]
    rounds = int(config.get("rounds", 3))
    seen_per_subject = {name: 0 for name in subjects}
    output = []

    for q in rows:
        subject = q.get("subject") or q.get("c")
        if subject not in subjects:
            raise ValueError(f"未知の科目: {subject} / {q.get('id')}")

        ordinal = seen_per_subject[subject]
        per_round = int(subjects[subject])
        round_no = ordinal // per_round + 1
        if round_no > rounds:
            raise ValueError(f"{subject} が3回分の規定数を超えています: {q.get('id')}")
        seen_per_subject[subject] += 1

        source_url = q.get("source_url") or q.get("s")
        reference_date = q.get("reference_date") or q.get("y")
        origin_type = q.get("origin_type") or "original_from_primary_source"
        rights_basis = q.get("rights_basis") or "一次資料の事実・論点を基に独自作問。過去問本文・選択肢の単純転用なし。"

        output.append({
            "id": q.get("id"),
            "round": round_no,
            "subject": subject,
            "topic": q.get("topic") or q.get("t"),
            "question": q.get("question") or q.get("q"),
            "choices": q.get("choices") or q.get("a"),
            "correct_index": q.get("correct_index") if q.get("correct_index") is not None else q.get("x"),
            "explanation": q.get("explanation") or q.get("d") or q.get("r"),
            "memory_line": q.get("memory_line") or q.get("m"),
            "short_reason": q.get("short_reason") or q.get("r"),
            "source_url": source_url,
            "reference_date": reference_date,
            "origin_type": origin_type,
            "rights_basis": rights_basis,
            "audit_status": q.get("audit_status") or q.get("z") or "draft"
        })

    return output


def main():
    config = load_config()
    rows = load_sources(config)
    canonical = canonicalize(rows, config)
    out = BASE / config["questions_file"]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(canonical, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"canonicalized: {len(canonical)} questions -> {out}")


if __name__ == "__main__":
    main()
