#!/usr/bin/env python3
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "audit"
IOS = ROOT / "ios"
OUT = IOS / "Resources" / "questions.native.json"
CANON = AUDIT / "data" / "questions.round1-2-3.canonical.json"
CONTENT_VERSION = "kanri-native-600-v1"
AUDIT_DATE = "2026-08-09"
SUBJECTS = ["社会・環境","人体・疾病","食べ物","基礎栄養","応用栄養","栄養教育","臨床栄養","公衆栄養","給食経営","応用力"]
EXPECTED = {"社会・環境":16,"人体・疾病":26,"食べ物":25,"基礎栄養":14,"応用栄養":16,"栄養教育":13,"臨床栄養":26,"公衆栄養":16,"給食経営":18,"応用力":30}

def iso_date(value):
    value = str(value or "")
    m = re.search(r"(20\d{2})-(\d{2})-(\d{2})", value)
    return m.group(0) if m else AUDIT_DATE

def main():
    subprocess.check_call([sys.executable, str(AUDIT / "build_round1_2_3_canonical.py")])
    data = json.loads(CANON.read_text(encoding="utf-8"))
    if len(data) != 600:
        raise SystemExit(f"canonical count mismatch {len(data)}/600")
    free_seen = Counter(); round_pos = Counter(); native = []; per_round = defaultdict(Counter)
    for q in data:
        round_no = int(q["round"]); subject = q["subject"]
        if round_no not in (1,2,3) or subject not in EXPECTED: raise SystemExit(f"invalid round/subject: {q.get('id')}")
        round_pos[round_no] += 1; per_round[round_no][subject] += 1
        is_free = round_no == 1 and free_seen[subject] < 6
        if is_free: free_seen[subject] += 1
        source_url = q.get("source_url") or None
        reference_date = iso_date(q.get("reference_date"))
        explanation = "\n\n".join(x for x in [q.get("short_reason", ""), q.get("explanation", "")] if x).strip()
        native.append({
            "id": q["id"], "subject": subject, "topic": q["topic"], "answerType": "singleChoice",
            "prompt": q["question"], "choices": q["choices"], "correctIndices": [int(q["correct_index"])],
            "correctNumber": None, "acceptedRange": None, "unit": None, "roundingRule": None,
            "blanks": [], "declarationFields": [], "sourceText": q.get("short_reason") or None,
            "memoryPoint": q.get("memory_line", ""), "explanation": explanation,
            "sourceTitle": "一次資料" if source_url else None, "sourceURL": source_url,
            "sourceRefs": [source_url] if source_url else [], "sourceCheckedAt": AUDIT_DATE,
            "lawBaselineDate": reference_date, "contentVersion": CONTENT_VERSION, "premium": not is_free,
            "examRound": f"第{round_no}回", "questionNumber": str(round_pos[round_no]),
            "rightsBasis": q.get("rights_basis") or q.get("origin_type") or "独自作問・内部権利監査済み"
        })
    for r in (1,2,3):
        if dict(per_round[r]) != EXPECTED: raise SystemExit(f"round {r} distribution mismatch: {dict(per_round[r])}")
    if sum(1 for q in native if not q["premium"]) != 60: raise SystemExit("free count mismatch")
    if dict(free_seen) != {s:6 for s in SUBJECTS}: raise SystemExit(f"free subject split mismatch: {dict(free_seen)}")
    payload = {"schemaVersion":1,"qualification":"管理栄養士国家試験","bundleID":"jp.allsunday1122.kanrieiyoushi","contentVersion":CONTENT_VERSION,"sourceAuditDate":AUDIT_DATE,"questions":native}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"PASS native questions: {len(native)} total, free=60, premium=540 -> {OUT}")

if __name__ == "__main__": main()
