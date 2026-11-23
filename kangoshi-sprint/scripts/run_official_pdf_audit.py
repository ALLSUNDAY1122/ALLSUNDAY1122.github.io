#!/usr/bin/env python3
"""Fetch official nurse-exam PDFs, audit existing raw bank, emit reproducible evidence."""
import hashlib,json,pathlib,subprocess,sys,urllib.request,datetime
ROOT=pathlib.Path(__file__).resolve().parents[1]
SOURCES=ROOT/"audit/official-source-manifest-20261124.json"
OUT=ROOT/"audit/runs"
def get(url,path):
    req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 (nurse-official-audit/1.0)"})
    with urllib.request.urlopen(req,timeout=90) as f:data=f.read()
    if not data.startswith(b"%PDF-"):raise ValueError("not a PDF response")
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data)
    return {"size":len(data),"sha256":hashlib.sha256(data).hexdigest()}
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    index={"checkedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),"exams":{},"existingQuestionCount":720,"newQuestionsImported":0,"executedQuestions":0,"textPass":0,"hold":0,"unexecuted":0}
    for entry in json.loads(SOURCES.read_text())["sources"]:
        exam=entry["exam"]; e={"exam":exam,"pdfs":{},"sessions":{}}
        for session,label in [("AM","morningPdf"),("PM","afternoonPdf"),("KEY","answerPdf")]:
            name=f"{exam}-{session}.pdf";path=pathlib.Path("/tmp/kangoshi-official")/name
            try:
                meta=get(entry[label],path);e["pdfs"][session]={"url":entry[label],**meta,"status":"FETCHED"}
            except Exception as exc:
                e["pdfs"][session]={"url":entry[label],"status":"FETCH_FAILED","reason":str(exc)[:250]}
                continue
            if session=="KEY":continue
            raw=ROOT/f"product-content/raw/set{116-exam}-raw.json"
            if not raw.exists():
                e["sessions"][session]={"status":"NOT_IMPORTED","expected":120}
                continue
            report=OUT/f"exam{exam}-{session}-audit.json"
            p=subprocess.run([sys.executable,str(ROOT/"scripts/audit_official_pdf.py"),"--exam",str(exam),"--session",session,"--source-url",entry[label],"--questions",str(raw),"--pdf",str(path),"--report",str(report)],capture_output=True,text=True)
            if not report.exists():
                e["sessions"][session]={"status":"AUDIT_FAILED","reason":(p.stderr+p.stdout)[-500:]}
                continue
            o=json.loads(report.read_text())
            e["sessions"][session]={"status":"AUDIT_EXECUTED","counts":o["statusCounts"],"questionsChecked":o["questionsChecked"],"exitCode":p.returncode}
            index["executedQuestions"]+=o["questionsChecked"]
            index["textPass"]+=o["statusCounts"].get("PASS_TEXT_ONLY",0)
            index["hold"]+=o["questionsChecked"]-o["statusCounts"].get("PASS_TEXT_ONLY",0)
        index["exams"][str(exam)]=e
    index["unexecuted"]=720-index["executedQuestions"]
    (OUT/"run-summary.json").write_text(json.dumps(index,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"executed":index["executedQuestions"],"pass":index["textPass"],"hold":index["hold"],"unexecuted":index["unexecuted"]}))
    return 0
if __name__=="__main__":sys.exit(main())
