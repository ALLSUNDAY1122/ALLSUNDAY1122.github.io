#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent
CONFIG = BASE / "source-map.json"
QUESTIONS = BASE / "questions-r8-official.json"
EXTRACTION = BASE / "extraction-report.json"
AUDIT = BASE / "audit-result.json"


def norm(s: str) -> str:
    return re.sub(r"[\s　、。,.・:：;；（）()\[\]{}『』「」―ー～~!?！？]", "", str(s)).lower()


def main():
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    qs = json.loads(QUESTIONS.read_text(encoding="utf-8"))
    extraction = json.loads(EXTRACTION.read_text(encoding="utf-8"))
    errors = []
    warnings = []

    expected_total = sum(s["count"] for r in config["rounds"] for s in r["subjects"])
    if expected_total != 186:
        errors.append(f"設定総数が186でない: {expected_total}")
    if len(qs) != expected_total:
        errors.append(f"生成総数 {len(qs)}/{expected_total}")
    if extraction.get("status") != "PASS" or extraction.get("errors"):
        errors.append("抽出レポートがPASSでない")

    ids = [q.get("id") for q in qs]
    dup_ids = [x for x, c in Counter(ids).items() if c > 1]
    if dup_ids:
        errors.append(f"ID重複: {dup_ids}")

    by_key = {(q["round_key"], q["subject"], q["question_no"]): q for q in qs}
    round_counts = defaultdict(int)
    subject_counts = defaultdict(int)
    round_points = defaultdict(int)
    subject_points = defaultdict(int)
    required = [
        "id","round","round_key","subject","question_no","question","choices",
        "correct_choice","correct_index","points","source_page_url","source_pdf_url",
        "answer_pdf_url","source_pdf_sha256","source_segment_sha256","origin_type",
        "edited","edit_notice","rights_review","rights_basis","source_integrity"
    ]

    for rnd in config["rounds"]:
        for sub in rnd["subjects"]:
            if len(sub["answers"]) != sub["count"]:
                errors.append(f"{rnd['label']}/{sub['name']}: 正解設定数不一致")
            if len(sub["points"]) != sub["count"]:
                errors.append(f"{rnd['label']}/{sub['name']}: 配点設定数不一致")
            if sum(sub["points"]) != (200 if sub["name"] == "財務会計論" else 100):
                errors.append(f"{rnd['label']}/{sub['name']}: 設定配点合計不一致 {sum(sub['points'])}")
            for qno in range(1, sub["count"] + 1):
                key = (rnd["key"], sub["name"], qno)
                q = by_key.get(key)
                if q is None:
                    errors.append(f"欠損: {key}")
                    continue
                for f in required:
                    if f not in q or q[f] is None or q[f] == "" or q[f] == []:
                        errors.append(f"{q.get('id', key)}: 必須項目欠損 {f}")
                if len(q.get("choices", [])) != 6:
                    errors.append(f"{q['id']}: 選択肢数 {len(q.get('choices', []))}/6")
                expected_answer = sub["answers"][qno - 1]
                expected_points = sub["points"][qno - 1]
                if q.get("correct_choice") != expected_answer or q.get("correct_index") != expected_answer - 1:
                    errors.append(f"{q['id']}: 正解不一致")
                if q.get("points") != expected_points:
                    errors.append(f"{q['id']}: 配点不一致 {q.get('points')}/{expected_points}")
                if not str(q.get("source_pdf_url", "")).startswith("https://www.fsa.go.jp/cpaaob/"):
                    errors.append(f"{q['id']}: 非公式source_pdf_url")
                if not str(q.get("answer_pdf_url", "")).startswith("https://www.fsa.go.jp/cpaaob/"):
                    errors.append(f"{q['id']}: 非公式answer_pdf_url")
                if q.get("origin_type") != "licensed_official":
                    errors.append(f"{q['id']}: origin_type不正")
                if q.get("edited") is not True or not q.get("edit_notice"):
                    errors.append(f"{q['id']}: 加工表示メタデータ不備")
                if not str(q.get("rights_review", "")).startswith("PASS_"):
                    errors.append(f"{q['id']}: rights_review未PASS")
                if q.get("source_integrity") != "generated_directly_from_official_pdf_text_layer":
                    errors.append(f"{q['id']}: source_integrity不正")
                for h in (q.get("source_pdf_sha256", ""), q.get("source_segment_sha256", "")):
                    if not re.fullmatch(r"[0-9a-f]{64}", str(h)):
                        errors.append(f"{q['id']}: SHA-256形式不正")
                round_counts[rnd["key"]] += 1
                subject_counts[(rnd["key"], sub["name"])] += 1
                round_points[rnd["key"]] += q.get("points", 0)
                subject_points[(rnd["key"], sub["name"])] += q.get("points", 0)

    for rnd in config["rounds"]:
        if round_counts[rnd["key"]] != 93:
            errors.append(f"{rnd['label']}: 93問でない {round_counts[rnd['key']]}")
        if round_points[rnd["key"]] != 500:
            errors.append(f"{rnd['label']}: 500点でない {round_points[rnd['key']]}")
        for sub in rnd["subjects"]:
            if subject_counts[(rnd["key"], sub["name"])] != sub["count"]:
                errors.append(f"{rnd['label']}/{sub['name']}: 件数不一致")

    # 公式回間の再出題・実質同一は、模試の史実として保持する。一方、通常学習で水増ししないため候補を記録する。
    text_map = defaultdict(list)
    for q in qs:
        key = norm(q["question"] + "|" + "|".join(q["choices"]))
        if key:
            text_map[key].append(q["id"])
    exact_duplicate_groups = [v for v in text_map.values() if len(v) > 1]
    if exact_duplicate_groups:
        warnings.append(f"公式回間の完全一致候補 {len(exact_duplicate_groups)}群。模試では保持、通常学習ではcanonical化対象。")

    pdf_hashes = defaultdict(set)
    for q in qs:
        pdf_hashes[(q["round_key"], q["subject"])].add(q["source_pdf_sha256"])
    for key, hashes in pdf_hashes.items():
        if len(hashes) != 1:
            errors.append(f"{key}: 同一科目内PDF SHAが複数 {len(hashes)}")

    result = {
        "audit": "公認会計士短答式 R8公式186問 問題単位監査",
        "status": "PASS" if not errors else "FAIL",
        "expected_total": expected_total,
        "actual_total": len(qs),
        "round_counts": dict(round_counts),
        "round_points": dict(round_points),
        "exact_historical_duplicate_groups": exact_duplicate_groups,
        "rights": {
            "question_unit_review_pass_count": sum(1 for q in qs if str(q.get("rights_review", "")).startswith("PASS_")),
            "policy": config["rights_policy"]
        },
        "checks": [
            "93問×2=186問",
            "試験回×科目の規定数",
            "各回500点・問題単位配点",
            "公式正解表とのcorrect_choice照合",
            "6選択肢分割",
            "公式PDF/正解PDF URL",
            "PDF・問題セグメントSHA-256",
            "出典・加工表示・rights_review",
            "ID重複",
            "公式回間完全一致候補の抽出"
        ],
        "warnings": warnings,
        "errors": errors,
        "fail_fix_pass": [
            {
                "initial": "FAIL",
                "finding": "財務会計論は試験回ごとに5点/6点問題の番号が異なる",
                "fix": "問題単位pointsを公式正解・配点表から固定",
                "reaudit": "PASS" if not any("配点" in e for e in errors) else "FAIL"
            },
            {
                "initial": "FAIL",
                "finding": "PDF全体の利用条件だけでは問題単位の権利監査記録が不足",
                "fix": "186問すべてにrights_review・rights_basis・出典・加工表示を付与",
                "reaudit": "PASS" if sum(1 for q in qs if str(q.get("rights_review", "")).startswith("PASS_")) == 186 else "FAIL"
            }
        ]
    }
    AUDIT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "actual_total": len(qs), "errors": len(errors), "warnings": len(warnings)}, ensure_ascii=False))
    if errors:
        for e in errors:
            print("FAIL:", e)
        sys.exit(1)
    print("PASS: 公式186問の問題単位JSON・正解・配点・権利メタデータ監査")


if __name__ == "__main__":
    main()
