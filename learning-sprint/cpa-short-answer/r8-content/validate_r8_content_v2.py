#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent
CFG = json.loads((BASE / "source-map.json").read_text(encoding="utf-8"))
QS = json.loads((BASE / "questions-r8-official.json").read_text(encoding="utf-8"))
EX = json.loads((BASE / "extraction-report.json").read_text(encoding="utf-8"))
OUT = BASE / "audit-result.json"


def norm(s):
    return re.sub(r"[\s　、。,.・:：;；（）()\[\]{}『』「」―ー～~!?！？]", "", str(s)).lower()


def main():
    errors, warnings = [], []
    expected = {(r["key"], s["name"], n): (r, s) for r in CFG["rounds"] for s in r["subjects"] for n in range(1, s["count"] + 1)}
    if len(expected) != 186:
        errors.append(f"設定枠 {len(expected)}/186")
    if EX.get("status") != "PASS" or EX.get("generated_total") != 186:
        errors.append("抽出工程がPASS/186問ではない")
    if len(QS) != 186:
        errors.append(f"JSON件数 {len(QS)}/186")

    ids = [q.get("id") for q in QS]
    if len(ids) != len(set(ids)):
        errors.append(f"ID重複 { [x for x,c in Counter(ids).items() if c>1] }")

    index = {(q.get("round_key"), q.get("subject"), q.get("question_no")): q for q in QS}
    round_points = defaultdict(int)
    round_counts = defaultdict(int)
    subject_counts = defaultdict(int)
    choice_counts = Counter()
    required = ["id","round","round_key","subject","question_no","question","choices","choice_count","correct_choice","correct_index","points","source_page_url","source_pdf_url","answer_pdf_url","source_pdf_sha256","source_segment_sha256","origin_type","edited","edit_notice","rights_review","rights_basis","source_integrity"]

    for key, (rnd, sub) in expected.items():
        q = index.get(key)
        if not q:
            errors.append(f"問題欠損 {key}")
            continue
        qno = key[2]
        for f in required:
            if f not in q or q[f] in (None, "", []):
                errors.append(f"{q.get('id',key)}: {f}欠損")
        cc = len(q.get("choices", []))
        choice_counts[cc] += 1
        if cc not in (5, 6) or q.get("choice_count") != cc:
            errors.append(f"{q['id']}: 回答肢数不正 {cc}")
        ans = sub["answers"][qno - 1]
        pts = sub["points"][qno - 1]
        if q.get("correct_choice") != ans or q.get("correct_index") != ans - 1 or ans > cc:
            errors.append(f"{q['id']}: 正解照合FAIL json={q.get('correct_choice')} official={ans} choices={cc}")
        if q.get("points") != pts:
            errors.append(f"{q['id']}: 配点照合FAIL json={q.get('points')} official={pts}")
        if not str(q.get("source_pdf_url","")).startswith("https://www.fsa.go.jp/cpaaob/"):
            errors.append(f"{q['id']}: 問題PDFが公式URLでない")
        if not str(q.get("answer_pdf_url","")).startswith("https://www.fsa.go.jp/cpaaob/"):
            errors.append(f"{q['id']}: 正解PDFが公式URLでない")
        if not re.fullmatch(r"[0-9a-f]{64}", str(q.get("source_pdf_sha256",""))) or not re.fullmatch(r"[0-9a-f]{64}", str(q.get("source_segment_sha256",""))):
            errors.append(f"{q['id']}: SHA-256不備")
        if q.get("origin_type") != "licensed_official" or q.get("edited") is not True:
            errors.append(f"{q['id']}: 由来/加工メタデータ不備")
        if not str(q.get("rights_review","")).startswith("PASS_") or not q.get("rights_basis"):
            errors.append(f"{q['id']}: rights_review不備")
        round_counts[rnd["key"]] += 1
        subject_counts[(rnd["key"],sub["name"])] += 1
        round_points[rnd["key"]] += pts

    for rnd in CFG["rounds"]:
        if round_counts[rnd["key"]] != 93:
            errors.append(f"{rnd['label']}: {round_counts[rnd['key']]}/93問")
        if round_points[rnd["key"]] != 500:
            errors.append(f"{rnd['label']}: {round_points[rnd['key']]}/500点")
        for sub in rnd["subjects"]:
            if subject_counts[(rnd["key"],sub["name"])] != sub["count"]:
                errors.append(f"{rnd['label']}/{sub['name']}: 件数FAIL")
            if len(sub["answers"]) != sub["count"] or len(sub["points"]) != sub["count"]:
                errors.append(f"{rnd['label']}/{sub['name']}: 正解/配点設定数FAIL")
            expected_points = 200 if sub["name"] == "財務会計論" else 100
            if sum(sub["points"]) != expected_points:
                errors.append(f"{rnd['label']}/{sub['name']}: 配点合計FAIL")

    # 公式回の再出題は「186出題枠」の欠損にはしないが、通常学習の水増し防止用にcanonical候補を出す。
    dup_map = defaultdict(list)
    for q in QS:
        signature = norm(q.get("question","") + "|" + "|".join(q.get("choices",[])))
        dup_map[signature].append(q["id"])
    exact_dups = [v for k,v in dup_map.items() if k and len(v)>1]
    if exact_dups:
        warnings.append(f"公式回間の完全一致 {len(exact_dups)}群。模試では保持、通常学習バンクではcanonical化必須。")

    result = {
        "audit":"公認会計士短答式 R8公式186問 問題単位監査 v2",
        "status":"PASS" if not errors else "FAIL",
        "actual_total":len(QS),
        "round_counts":dict(round_counts),
        "round_points":dict(round_points),
        "choice_counts":{str(k):v for k,v in sorted(choice_counts.items())},
        "rights_review_pass_count":sum(1 for q in QS if str(q.get("rights_review","")).startswith("PASS_")),
        "exact_historical_duplicate_groups":exact_dups,
        "checks":["93問×2=186問","4科目別件数","各回500点","5択/6択を原文どおり保持","公式正解番号照合","問題単位配点照合","公式問題/正解URL","PDF/問題SHA-256","186問rights_review・加工表示","ID重複","公式回間完全一致候補"],
        "fail_fix_pass":[
            {"initial":"FAIL","finding":"PDF制御文字・特殊空白で問題見出し抽出0件","fix":"0x07等の制御文字とfigure spaceを通常空白へ1文字置換してから分割","reaudit":"PASS" if not any("欠損" in e or "抽出" in e for e in errors) else "FAIL"},
            {"initial":"FAIL","finding":"全問6択と仮定したため管理会計論の5択計算問題を拒否","fix":"回答肢を原文から末尾連番群として抽出し5択/6択を保持","reaudit":"PASS" if not any("回答肢" in e for e in errors) else "FAIL"},
            {"initial":"FAIL","finding":"財務会計論の5点/6点問題番号が試験回で異なる","fix":"公式配点表を問題単位pointsとして固定","reaudit":"PASS" if not any("配点" in e for e in errors) else "FAIL"},
            {"initial":"FAIL","finding":"PDF単位の利用条件だけでは問題単位権利記録が不足","fix":"全186問にrights_review・rights_basis・出典・加工表示を付与","reaudit":"PASS" if sum(1 for q in QS if str(q.get("rights_review","")).startswith("PASS_"))==186 else "FAIL"}
        ],
        "warnings":warnings,
        "errors":errors
    }
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"status":result["status"],"questions":len(QS),"choice_counts":result["choice_counts"],"errors":len(errors),"warnings":len(warnings)},ensure_ascii=False))
    if errors:
        for e in errors: print("FAIL:",e)
        sys.exit(1)
    print("PASS: R8公式186問の問題単位・正解・配点・権利監査")

if __name__ == "__main__":
    main()
