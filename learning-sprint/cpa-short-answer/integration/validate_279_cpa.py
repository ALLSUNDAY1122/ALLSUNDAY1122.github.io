#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path

BASE = Path(__file__).resolve().parent
QUESTIONS = BASE / "questions-all-279.json"
REPORT = BASE / "audit-cpa-aware-279.json"
CANONICAL = BASE / "canonical-map-279.json"
EXPECTED = {"企業法":20,"管理会計論":18,"監査論":20,"財務会計論":35}


def norm(text: str) -> str:
    text = str(text).lower()
    text = re.sub(r"\s+", "", text)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", text)


def main():
    qs = json.loads(QUESTIONS.read_text(encoding="utf-8"))
    errors, warnings = [], []
    if len(qs) != 279:
        errors.append(f"総問題数 {len(qs)}/279")

    ids = [q.get("id") for q in qs]
    if len(ids) != len(set(ids)):
        errors.append("ID重複")

    counts = Counter((q.get("round"), q.get("subject")) for q in qs)
    points = Counter()
    required = ["id","round","subject","question","choices","correct_index","explanation","source_url","basis_date","origin_type","rights_basis"]
    for q in qs:
        points[q.get("round")] += q.get("points",0)
        for f in required:
            if q.get(f) in (None,"",[]):
                errors.append(f"{q.get('id')}: {f}欠損")
        if not isinstance(q.get("correct_index"),int) or not 0 <= q["correct_index"] < len(q.get("choices",[])):
            errors.append(f"{q.get('id')}: correct_index不正")
    for r in (1,2,3):
        for s,n in EXPECTED.items():
            if counts[(r,s)] != n:
                errors.append(f"第{r}回/{s} {counts[(r,s)]}/{n}")
        if points[r] != 500:
            errors.append(f"第{r}回配点 {points[r]}/500")

    normalized = [(q, norm(q.get("question",""))) for q in qs]
    exact_map = defaultdict(list)
    for q,t in normalized:
        if t:
            exact_map[t].append(q)

    exact_official_groups = []
    canonical_map = {}
    for group in exact_map.values():
        if len(group) < 2:
            continue
        if not all(q.get("origin_type") == "licensed_official" for q in group):
            errors.append("独自問題を含む本文完全一致: " + ", ".join(q["id"] for q in group))
            continue
        # 公式試験で実際に再出題された完全一致は模試史実として保持。
        # 通常学習では最古IDをcanonicalとして1問だけ数える。
        ids_group = sorted(q["id"] for q in group)
        canonical = ids_group[0]
        exact_official_groups.append(ids_group)
        for qid in ids_group:
            canonical_map[qid] = canonical

    official_similarities = []
    authored_similarities = []
    for i in range(len(normalized)):
        qa,ta = normalized[i]
        if not ta: continue
        for j in range(i+1,len(normalized)):
            qb,tb = normalized[j]
            if not tb: continue
            ratio = SequenceMatcher(None, ta, tb).ratio()
            if ratio < 0.90:
                continue
            pair = {"a":qa["id"],"b":qb["id"],"ratio":round(ratio,4)}
            if qa.get("origin_type") == "licensed_official" and qb.get("origin_type") == "licensed_official":
                # 公式同士の類似は、実試験の史実であり人工的な水増しではない。
                # 完全一致だけcanonical化し、類似問題は別問として保持してレビュー記録する。
                official_similarities.append(pair)
            else:
                authored_similarities.append(pair)
                errors.append(f"独自問題を含む高類似 {ratio:.2f}: {qa['id']} <-> {qb['id']}")

    # 独自R9だけに限定した厳格監査。人工的な水増しは1件も許容しない。
    r9 = [q for q in qs if q.get("round") == 3]
    r9_text = [(q,norm(q["question"])) for q in r9]
    r9_exact = 0
    r9_high = 0
    seen = defaultdict(list)
    for q,t in r9_text: seen[t].append(q["id"])
    r9_exact = sum(1 for v in seen.values() if len(v)>1)
    for i in range(len(r9_text)):
        for j in range(i+1,len(r9_text)):
            if SequenceMatcher(None,r9_text[i][1],r9_text[j][1]).ratio() >= 0.90:
                r9_high += 1
    if r9_exact or r9_high:
        errors.append(f"R9独自問題の水増し候補 exact={r9_exact} high={r9_high}")

    canonical_reductions = sum(len(g)-1 for g in exact_official_groups)
    unique_learning_total = len(qs) - canonical_reductions
    canonical_doc = {
        "policy":"full_mock_preserves_official_history; normal_learning_collapses_exact_official_repeats",
        "full_mock_slots":len(qs),
        "exact_official_repeat_groups":exact_official_groups,
        "canonical_map":canonical_map,
        "normal_learning_unique_count":unique_learning_total
    }
    CANONICAL.write_text(json.dumps(canonical_doc,ensure_ascii=False,indent=2),encoding="utf-8")

    result = {
        "audit":"CPA-aware 279-question anti-padding audit",
        "status":"PASS" if not errors else "FAIL",
        "total_exam_slots":len(qs),
        "round_counts":{str(r):sum(1 for q in qs if q.get('round')==r) for r in (1,2,3)},
        "round_points":{str(r):points[r] for r in (1,2,3)},
        "r9_authored_exact_duplicates":r9_exact,
        "r9_authored_high_similarity_ge_0_90":r9_high,
        "official_exact_repeat_groups":exact_official_groups,
        "official_similarity_pairs_ge_0_90":official_similarities,
        "normal_learning_unique_count":unique_learning_total,
        "policy":"公式問題同士の再出題・類似出題は模試では原文のまま保持する。完全一致の公式再出題のみ通常学習ではcanonical化する。独自作問が関与する完全一致・0.90以上の高類似はFAIL。",
        "errors":errors,
        "warnings":warnings
    }
    REPORT.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"status":result["status"],"exam_slots":len(qs),"normal_learning_unique":unique_learning_total,"official_exact_groups":len(exact_official_groups),"official_similarities":len(official_similarities),"r9_exact":r9_exact,"r9_high":r9_high,"errors":len(errors)},ensure_ascii=False))
    if errors:
        for e in errors: print("FAIL:",e)
        sys.exit(1)
    print("PASS: 公式史実を保持しつつ、独自作問の水増しゼロを確認")

if __name__ == "__main__":
    main()
