#!/usr/bin/env python3
"""Official release bank: reviewed visual PASS plus strict normalized official-PDF AUTO_PASS.
Never silently promote a known HOLD or a diff tied to stale Git blobs.
"""
import hashlib,json
from pathlib import Path
B=Path(__file__).resolve().parent
manual=json.loads((B/"MANUAL_VISUAL_AUDIT_20261123.json").read_text())
reviews={r["id"]:r for r in manual["reviewedQuestions"]}
frozen=manual.get("auditSourceFrozenGitBlobs",{})
def blob(path):
    contents=path.read_bytes()
    return hashlib.sha1(f"blob {len(contents)}\0".encode()+contents).hexdigest()
accepted={}
status_by_year={}
for year in range(2022,2027):
    candidate_path=B/f"QUESTIONS_{year}_APP_CANDIDATE.json"
    answer_path=B/f"ANSWERS_{year}_OFFICIAL.json"
    candidates=json.loads(candidate_path.read_text())["questions"]
    answers=json.loads(answer_path.read_text())["questions"]
    expected_candidate_sha=blob(candidate_path)
    expected_answers_sha=blob(answer_path)
    if len(candidates)!=120 or len(answers)!=120:raise RuntimeError("incorrect lengths")
    report_file=B/f"AUTO_DIFF_{year}.json"
    report=json.loads(report_file.read_text()) if report_file.exists() else None
    if report is not None:
        if report["year"]!=year or report["total"]!=120 or len(report["questions"])!=120:
            raise RuntimeError(f"invalid auto report for {year}")
        if report["candidateGitBlob"]!=expected_candidate_sha or report["answerIndexGitBlob"]!=expected_answers_sha:
            raise RuntimeError(f"stale auto diff for {year}")
        if len({r["id"] for r in report["questions"]})!=120:
            raise RuntimeError(f"duplicate IDs {year}")
        byid={r["id"]:r for r in report["questions"]}
    else:byid={}
    geom_file=B/f"GEOMETRY_AUDIT_{year}.json"
    geom=json.loads(geom_file.read_text()) if geom_file.exists() else None
    geom_byid={}
    cross_file=B/f"CROSSCHECK_{year}.json"
    cross=json.loads(cross_file.read_text()) if cross_file.exists() else None
    disputed=set()
    if cross:
        if cross["year"]!=year or cross["samples"]!=10:raise RuntimeError("invalid cross engine evidence")
        disputed={x["id"] for x in cross["results"] if x["status"]=="REVIEW_EXTRACTOR_DISAGREEMENT"}
    if geom:
        if geom["year"]!=year or geom["total"]!=120 or len(geom["questions"])!=120:
            raise RuntimeError("invalid geometry audit for "+str(year))
        if not report or geom["priorAuditCandidateGitBlob"]!=expected_candidate_sha:
            raise RuntimeError("stale geometry audit for "+str(year))
        geom_byid={item["id"]:item for item in geom["questions"]}
        if len(geom_byid)!=120:raise RuntimeError("missing geometry records")
    stats={"auto":0,"geometry":0,"visual":0,"crossEngineHold":0,"hold":0,"pending":0}
    for idx,q in enumerate(candidates):
        id=q["id"];n=idx+1
        if id!=f"KSAI-{year}-{n:03d}" or q["questionNo"]!=n:
            raise RuntimeError("candidate order")
        k=answers[idx]
        if k["question_no"]!=n or k["official_answer"]!=q["answerNumberOfficial"]:
            raise RuntimeError("official key mismatch")
        manual_result=reviews.get(id)
        auto_result=byid.get(id)
        geometry_result=geom_byid.get(id)
        if report and not auto_result:raise RuntimeError("missing diff")
        if auto_result and (auto_result["questionNo"]!=n or auto_result["officialAnswer"]!=k["official_answer"]):
            raise RuntimeError("diff key mismatch")
        if id in disputed:
            stats["hold"]+=1
            stats["crossEngineHold"]+=1
            continue
        if manual_result and manual_result["status"]=="HOLD":
            stats["hold"]+=1
            continue
        if manual_result and manual_result["status"]=="PASS":
            pin=frozen.get(str(year))
            if not pin or pin["candidate"]!=expected_candidate_sha or pin["officialAnswerIndex"]!=expected_answers_sha:
                raise RuntimeError("visual evidence source hash drift "+id)
            if manual_result["answer"]!=q["answerNumberOfficial"]:
                raise RuntimeError("manual answer mismatch")
            audit={"status":"PASS","method":"VISUAL","record":"MANUAL_VISUAL_AUDIT_20261123.json","pdfPage":manual_result["pdf_page"]}
            stats["visual"]+=1
        elif auto_result and auto_result["status"]=="AUTO_PASS" and not auto_result["reasons"]:
            if auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("invalid normalized evidence")
            audit={"status":"PASS","method":"AUTO_SHA_PINNED_PDF_NFC_WHITESPACE_DIFF","record":f"AUTO_DIFF_{year}.json",
                   "sourcePdfSha256":auto_result["officialPdfSha256"],
                   "normalizedTextSha256":auto_result["sourceNormalizedSha256"]}
            stats["auto"]+=1
        elif geometry_result and geometry_result["status"]=="GEOMETRY_PASS" and not geometry_result["reasons"]:
            if not auto_result or auto_result["status"]!="HOLD":
                raise RuntimeError("geometry promotion must resolve known auto HOLD "+id)
            if auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("unresolved raw mismatch "+id)
            if geometry_result.get("ruby") is not None:
                raise RuntimeError("ruby layout cannot be promoted without certified renderer "+id)
            if geometry_result.get("table",{}).get("status")!="PASS":
                raise RuntimeError("geometry evidence missing table coordinates "+id)
            if sorted(auto_result["reasons"])!=["ANSWER_TABLE_REVIEW"]:
                raise RuntimeError("unexpected geometry source reasons "+id)
            audit={"status":"PASS","method":"AUTO_SHA_PINNED_TABLE_XY_CELL_ALIGNMENT",
                "record":f"GEOMETRY_AUDIT_{year}.json",
                "sourcePdfSha256":auto_result["officialPdfSha256"],
                "normalizedTextSha256":auto_result["sourceNormalizedSha256"],
                "table":geometry_result["table"]}
            stats["geometry"]+=1
        else:
            stats["hold" if auto_result else "pending"]+=1
            continue
        if q["sourceIssuer"]!="関西広域連合" or not q.get("sourceUrl") or not q.get("answerSourceUrl") or not q.get("attributionDisplay"):
            raise RuntimeError("source attribution absent "+id)
        if not isinstance(q["choices"],list) or len(q["choices"]) not in (4,5) or not all(q["choices"]):
            raise RuntimeError("choice structural failure "+id)
        if year==2023 and n==90:
            # Official invalid must never get automatic approval.
            if audit["method"]!="VISUAL" or q["answer"] is not None or not q["excludeFromAccuracyDenominator"]:
                raise RuntimeError("invalid Q90 promotion")
        elif not isinstance(q["answer"],int) or not 0<=q["answer"]<len(q["choices"]) or q["excludeFromAccuracyDenominator"]:
            raise RuntimeError("invalid answer "+id)
        fields=("id","year","questionNo","chapter","question","choices","answer","answerNumberOfficial",
                "sourceIssuer","sourceTitle","sourceUrl","answerSourceUrl","sourcePdfPages",
                "attributionDisplay","officialStatus","excludeFromAccuracyDenominator")
        item={field:q[field] for field in fields}
        item.update({"modificationDisclosureDisplay":q.get("modificationDisclosureDisplay") or "PDFを表示用に加工",
                     "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,"audit":audit})
        accepted[id]=item
    status_by_year[str(year)]=stats
approved=sorted(accepted.values(),key=lambda q:(q["year"],q["questionNo"]))
out={"schema":"touroku-hanbaisha-official-approved-v2","issuer":"関西広域連合",
     "officialPastQuestionsOnly":True,"count":len(approved),"questionCountTarget":600,
     "approvedIds":[q["id"] for q in approved],"byYear":status_by_year,
     "status":"PARTIAL_APPROVED" if len(approved)<600 else "APPROVED_CONTENT",
     "releaseGate":"BLOCKED_PENDING_APP_TESTS_AND_REVIEW","questions":approved}
(B/"APPROVED_OFFICIAL_BANK.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"approved":len(approved),"byYear":status_by_year},ensure_ascii=False))
