#!/usr/bin/env python3
"""Attach raw official answer-key tokens and authoritative scoring exceptions to 480 isolated drafts.
A key token does not clear text/media/layout quality gates; never release these candidates.
"""
import json,pathlib,collections
from official_answer_key_audit import parse
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs"
KEYED=OUT/"keyed-drafts";KEYED.mkdir(parents=True,exist_ok=True)
exceptions=json.loads((ROOT/"audit/official-scoring-exceptions-20261124.json").read_text(encoding="utf-8"))
exc={x["id"]:x for x in exceptions["exceptions"]}
summary={"total":0,"individualKeyRecords":0,"singleAnswerMapped":0,"keyValueAmbiguous":0,"excluded":0,"missingKeyRecord":0,"keysByExam":{},"releaseEligible":0}
for exam in (112,111):
    official,sha=parse(exam)
    summary["keysByExam"][str(exam)]={"officialKeyRows":len(official),"pdfSha256":sha}
    for session in ("AM","PM"):
        filename=f"exam{exam}-{session}-draft.json"
        f=OUT/filename
        data=json.loads(f.read_text(encoding="utf8"))
        if len(data["questions"])!=120:raise ValueError(f"{filename}: need 120 rows")
        for q in data["questions"]:
            summary["total"]+=1
            key=official.get(q["id"])
            case=exc.get(q["id"])
            q["officialKeyPdfSha256"]=sha
            q["officialScoringNotice"]=case["url"] if case else None
            q["officialScoringStatus"]=case["mode"] if case else "normal"
            q["sourceAnswerTokens"]=[key["rawValue"]] if key and key["rawValue"] else []
            q["officialKeyRaw"]=key["originalSpacing"] if key else None
            q["answer"]=None
            q["officialAcceptedAnswers"]=[]
            if case and case["mode"]=="excluded":
                q["answerKeyVerification"]="EXCLUDED_BY_OFFICIAL_NOTICE"
                summary["excluded"]+=1
            elif key is None:
                q["answerKeyVerification"]="HOLD_OFFICIAL_KEY_ROW_MISSING"
                summary["missingKeyRecord"]+=1
            else:
                summary["individualKeyRecords"]+=1
                value=key["rawValue"]
                if case and case["mode"]=="multiple_accepted":
                    q["answerKeyVerification"]="HOLD_MULTI_ACCEPTED_REQUIRES_CHOICE_MAPPING"
                    summary["keyValueAmbiguous"]+=1
                elif len(value)==1 and value in "12345" and len(q.get("choices",[]))>=int(value):
                    q["answer"]=int(value)-1
                    q["officialAcceptedAnswers"]=[int(value)-1]
                    q["answerKeyVerification"]="MATCH_SINGLE_DIGIT_KEY_NOT_VERBATIM_CERTIFIED"
                    summary["singleAnswerMapped"]+=1
                else:
                    q["answerKeyVerification"]="HOLD_NUMERIC_OR_MULTI_CHOICE_KEY_REQUIRES_INTERPRETATION"
                    summary["keyValueAmbiguous"]+=1
            q["reviewStatus"]="HOLD_OFFICIAL_TEXT_FIDELITY_LAYOUT_AND_MEDIA"
            q["publishable"]=False
        (KEYED/filename).write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
(KEYED/"keyed-summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
print(json.dumps(summary,ensure_ascii=False))
