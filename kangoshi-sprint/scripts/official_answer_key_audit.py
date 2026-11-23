#!/usr/bin/env python3
"""Audit 5 official Ministry answer PDFs. Preserve raw tokens and ambiguities.
No ambiguous key is assigned automatically to app questions.
"""
import re,json,pathlib,collections,hashlib
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs/answer-audit";OUT.mkdir(parents=True,exist_ok=True)
KEY_RE=re.compile(r"(?<!\w)(A\d{3}|B\d{3}|AM\d{1,3}|PM\d{1,3})\s+([\d ]*?)(?=\s+(?:A\d{3}|B\d{3}|AM\d{1,3}|PM\d{1,3})|\n|$)")
def parse(exam):
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-KEY.pdf"
    doc=fitz.open(pdf);text="\n".join(p.get_text("text",sort=True) for p in doc)
    found={}
    for code,token in KEY_RE.findall(text):
        sess="AM" if code.startswith(("AM","A")) else "PM"
        no=int(re.search(r"\d+",code).group())
        id=f"K{exam}-{sess}{no:03d}"
        raw="".join(token.split())
        if id in found: raise ValueError(f"duplicate answer key id: {id}")
        found[id]={"rawValue":raw,"originalSpacing":token,"status":"KEY_BLANK" if not raw else ("KEY_AMBIGUOUS_MULTI_OR_NUMBER" if len(raw)>1 else "KEY_SINGLE"),"sourceCode":code}
    return found,hashlib.sha256(pdf.read_bytes()).hexdigest()
def main():
    all_stats=collections.Counter();full={};flags=[]
    for exam in (115,114,113,112,111):
        found,sha=parse(exam)
        source=ROOT/f"product-content/raw/set{116-exam}-raw.json"
        if exam>=113:
            data=json.loads(source.read_text())
            questions=data["questions"]
        else:
            questions=[]
            for sess in ("AM","PM"):
                p=OUT.parent/f"exam{exam}-{sess}-draft.json"
                if not p.is_file(): raise FileNotFoundError(p)
                questions+=json.loads(p.read_text())["questions"]
        rows=[]
        for q in questions:
            id=q["id"];key=found.get(id)
            claimed=q.get("sourceAnswerTokens")
            accepted=q.get("officialAcceptedAnswers")
            scoring=q.get("officialScoringStatus")
            if key is None:
                status="HOLD_MISSING_KEY_ROW"
            elif key["status"]=="KEY_BLANK":
                status="HOLD_OFFICIAL_KEY_BLANK"
            elif exam<113:
                status="STAGING_KEY_EXTRACTED_NOT_APPLIED"
            elif claimed is not None:
                value="".join(str(x) for x in claimed)
                if value == key["rawValue"]:
                    status="MATCH_RAW_KEY_TOKEN"
                else:
                    status="HOLD_KEY_MISMATCH"
            else:status="HOLD_NO_RECORDED_KEY_TOKENS"
            row={"id":id,"status":status,"official":key,"existingSourceAnswerTokens":claimed,"existingAcceptedAnswers":accepted,"scoringStatusInBank":scoring}
            rows.append(row);all_stats[status]+=1
            if status.startswith("HOLD") or (key and key["status"]!="KEY_SINGLE") or (scoring and scoring!="normal"):
                flags.append(row)
        all_expected={f"K{exam}-{session}{n:03d}" for session in ("AM","PM") for n in range(1,121)}
        unmatched=sorted(all_expected-set(found))
        stats=dict(collections.Counter(x["status"] for x in rows))
        full[str(exam)]={"exam":exam,"pdfSha256":sha,"officialRowsParsed":len(found),"questionsChecked":len(rows),"statusCounts":stats,"missingKeyRows":unmatched,"rows":rows}
        (OUT/f"exam{exam}-answer-audit.json").write_text(json.dumps(full[str(exam)],ensure_ascii=False,indent=2)+"\n")
        print("EXAM",exam,"KEYROWS",len(found),"STATS",json.dumps(stats,ensure_ascii=False))
    summary={"totalQuestions":sum(x["questionsChecked"] for x in full.values()),"totalKeyRows":sum(x["officialRowsParsed"] for x in full.values()),"statusCounts":dict(all_stats),"byExam":{k:{"rows":v["officialRowsParsed"],"stats":v["statusCounts"],"missingKeyRows":v["missingKeyRows"]} for k,v in full.items()},"flaggedRecords":len(flags),"publishableDecision":"NOT_DETERMINED","policy":"KEY_MATCH_IS_RAW_TOKEN_ONLY. Multiple answers and numeric keys must be checked against question type and official scoring notice."}
    (OUT/"answer-summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    (OUT/"key-exceptions-to-review.json").write_text(json.dumps(flags,ensure_ascii=False,indent=2)+"\n")
    print("SUMMARY",json.dumps(summary["statusCounts"],ensure_ascii=False))
if __name__=="__main__":main()
