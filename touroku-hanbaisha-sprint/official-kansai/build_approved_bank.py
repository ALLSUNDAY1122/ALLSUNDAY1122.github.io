#!/usr/bin/env python3
"""Build release bank from explicitly signed off visual-audit records only."""
import json,hashlib
from pathlib import Path
BASE=Path(__file__).resolve().parent
AUDIT=json.loads((BASE/"MANUAL_VISUAL_AUDIT_20261123.json").read_text())
APPROVED=[]
seen=set()
def blob_sha(path):
    data=path.read_bytes()
    return hashlib.sha1(f'blob {len(data)}\\0'.encode()+data).hexdigest()
review_sources=AUDIT.get('auditSourceFrozenGitBlobs',{})
for record in AUDIT["reviewedQuestions"]:
    key=record["id"]
    if key in seen:raise ValueError("duplicate audit ID "+key)
    seen.add(key)
    if record["status"]!="PASS":continue
    # Only supported years with official per-year source/answer index
    _,year_string,qno_string=key.split("-")
    year=int(year_string);number=int(qno_string)
    frozen=review_sources.get(str(year))
    if not frozen:raise ValueError('unfrozen reviewed source year '+str(year))
    candidate_file=BASE/f'QUESTIONS_{year}_APP_CANDIDATE.json'
    answer_file=BASE/f'ANSWERS_{year}_OFFICIAL.json'
    if blob_sha(candidate_file)!=frozen['candidate'] or blob_sha(answer_file)!=frozen['officialAnswerIndex']:
        raise ValueError('audited candidate or answer source changed; re-review required for '+str(year))
    candidate=json.loads(candidate_file.read_text())
    official=json.loads(answer_file.read_text())
    q=next((x for x in candidate["questions"] if x["id"]==key),None)
    if not q or q["questionNo"]!=number:raise ValueError("missing candidate "+key)
    k=official["questions"][number-1]
    if k["question_no"]!=number or q["answerNumberOfficial"]!=k["official_answer"]:
        raise ValueError("answer index mismatch "+key)
    if q["sourceIssuer"]!="関西広域連合" or not q.get("attributionDisplay") or not q.get("sourceUrl"):
        raise ValueError("source mismatch "+key)
    if not isinstance(q["choices"],list) or len(q["choices"]) not in (4,5) or not all(q["choices"]):
        raise ValueError("options mismatch "+key)
    if q["officialStatus"]=="OFFICIALLY_INVALID_ALL_CANDIDATES_CORRECT":
        if q["answer"] is not None or not q["excludeFromAccuracyDenominator"]:
            raise ValueError("invalid scoring "+key)
    else:
        if not isinstance(q["answer"],int) or q["answer"]<0 or q["answer"]>=len(q["choices"]):
            raise ValueError("invalid answer "+key)
    if record["answer"]!=k["official_answer"]:raise ValueError("manual review answer mismatch "+key)
    fields=["id","year","questionNo","chapter","question","choices","answer","answerNumberOfficial","sourceIssuer","sourceTitle","sourceUrl","answerSourceUrl","sourcePdfPages","attributionDisplay","officialStatus","excludeFromAccuracyDenominator"]
    item={name:q[name] for name in fields}
    item.update({"modificationDisclosureDisplay":"PDFから抽出した表示用テキスト。原典PDFと改行・組版が異なります。",
                 "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,
                 "audit":{"status":"PASS","source": "MANUAL_VISUAL_AUDIT_20261123.json","pdf_page":record["pdf_page"],"reviewedAt":AUDIT["reviewed_at"]}})
    APPROVED.append(item)
APPROVED.sort(key=lambda q:(q["year"],q["questionNo"]))
expected={r["id"] for r in AUDIT["reviewedQuestions"] if r["status"]=="PASS"}
if {q["id"] for q in APPROVED}!=expected or not expected:
    raise ValueError("unexpected promotion set")
out={"schema":"touroku-hanbaisha-official-approved-v1","issuer":"関西広域連合",
     "officialPastQuestionsOnly":True,"officialYear":2022,"count":len(APPROVED),
     "approvedIds":[q["id"] for q in APPROVED],"questionCountTarget":600,
     "reviewScope":"2022 visual audit PASS subset only","status":"PARTIAL_APPROVED","questions":APPROVED}
file=BASE/"APPROVED_OFFICIAL_BANK.json"
file.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("PASS: approved",len(APPROVED),"HOLD",sum(r["status"]=="HOLD" for r in AUDIT["reviewedQuestions"]))
