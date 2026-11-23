#!/usr/bin/env python3
"""Promote only source-verified readings in physical PDF order, never attach them to Kanji.
Reconcile concurrent canonical-bank regressions without deleting approved records.
"""
import collections,datetime,hashlib,json,re,subprocess
from pathlib import Path
from auto_diff_pdf import B,download
from geometry_second_gate import first_question_clip
from ruby_font_cluster_recovery import rawglyphs,clusters
ROOT=B.parents[1]
IOS=ROOT/"touroku-hanbaisha-ios"
BANK=B/"APPROVED_OFFICIAL_BANK.json"
STATE=IOS/"release-status.json"
AUDIT=B/"RUBY_113_AUTO_REBUILD_20261124.json"
OUT=B/"RUBY_102_SOURCE_ORDER_PROMOTION_20261124.json"
BASELINE_COMMITS=[
 "473f978287f80e2d7e2fd067936b359d20fab8c3",
 "93f2ea76cb858b2e1f3be1bf8fa34eaa18168dbc",
 "ffeb59d7a7f52bd0684cd416d410ae7f158587b6"
]
def read(p):return json.loads(p.read_text())
def historic_bank():
    for sha in BASELINE_COMMITS:
        try:
            raw=subprocess.check_output(["git","show",sha+":touroku-hanbaisha-sprint/official-kansai/APPROVED_OFFICIAL_BANK.json"],cwd=ROOT)
            j=json.loads(raw)
            if j["count"]==497 and len(j["questions"])==497:
                return j,sha
        except (subprocess.CalledProcessError,ValueError):pass
    raise RuntimeError("497-bank prior approved snapshot unavailable; do not lose prior approvals")
def cleaned_fields(q,readings):
    fields=[q["question"],*q["choices"]]
    detached=[]
    for fi,field in enumerate(fields):
        for m in re.finditer(r'(?m)^[ \t]*([ぁ-んァ-ンー]{1,20})[ \t]*(?:\r?\n|$)',field):
            detached.append((fi,m.group(1)))
    observed=collections.Counter(r for _,r in detached)
    expected=collections.Counter(readings)
    difference=None
    if observed!=expected:
        difference={"source":dict(expected),"detachedInCandidate":dict(observed),
                    "policy":"PDF_SOURCE_READINGS_OVERRIDE_CANDIDATE_DETACHED_SPLITS"}
    new=[]
    for field in fields:
        pat=r'(?m)^[ \t]*([ぁ-んァ-ンー]{1,20})[ \t]*(?:\r?\n|$)'
        # Preserve standalone ordinary words, e.g. ナトリウム; remove only PDF-confirmed readings.
        new.append(re.sub(pat,lambda m: "" if m.group(1) in expected else m.group(0),field))
    if not all(s.strip() for s in new):return None,{"emptyResult":True}
    return new,difference
def main():
    current=read(BANK);old,status_commit=historic_bank()
    assert current["count"]==len(current["approvedIds"])==len(current["questions"])
    assert len(set(current["approvedIds"]))==current["count"]
    assert len(set(old["approvedIds"]))==497
    existing={q["id"]:q for q in current["questions"]}
    historical_only=[]
    for q in old["questions"]:
        if q["id"] not in existing:
            existing[q["id"]]=q
            historical_only.append(q["id"])
    # This ensures the 497 audited source was not lost in later concurrent writebacks.
    assert len(existing)>=497,(len(existing),historical_only)
    st=read(STATE);audit=read(AUDIT)
    holds=[x for x in audit["records"] if x["status"]=="HOLD"]
    assert len(holds)==102
    holdids={x["id"] for x in holds}
    assert len(holdids)==102
    previously_approved={id for id in holdids if id in existing}
    assert all(existing[id].get("rubyDisplayMode")=="SOURCE_ORDER_UNATTACHED" for id in previously_approved)
    official={y:read(B/f"QUESTIONS_{y}_APP_CANDIDATE.json")["questions"] for y in range(2022,2027)}
    answers={y:read(B/f"ANSWERS_{y}_OFFICIAL.json")["questions"] for y in range(2022,2027)}
    diff={y:read(B/f"AUTO_DIFF_{y}.json")["questions"] for y in range(2022,2027)}
    sources={x["year"]:x for x in read(B/"SOURCES_2022_2026.json")["years"]}
    docs={}; pdfHashes={}
    for y in range(2022,2027):
        pdfHashes[y]={x["half"]:x["sha256"] for x in read(B/f"PDF_SHA256_{y}.json")}
        docs[y]={}
        for half,key in [("first_half","question_pdf_first_half"),("second_half","question_pdf_second_half")]:
            docs[y][half]=download(sources[y][key],B/f".tmp_ordered_unattached_{y}_{half}.pdf",pdfHashes[y][half])
    evidence=[];created=[];reasons=collections.Counter()
    for h in holds:
        id=h["id"]
        if id in previously_approved:
            evidence.append({"id":id,"status":"ALREADY_APPROVED","reasons":[],"previouslyApproved":True})
            continue
        year=int(id[5:9]);no=int(id[-3:])
        q=official[year][no-1];answer=answers[year][no-1];d=diff[year][no-1]
        assert q["id"]==id==d["id"]
        half="first_half" if no<=60 else "second_half"
        doc=docs[year][half]
        proof={"id":id,"status":"HOLD","priorReasons":h["reasons"],"reasons":[]}
        clips=first_question_clip(doc,None,q)
        if not clips:
            proof["reasons"].append("SOURCE_REGION_NOT_CERTIFIED")
        else:
            glyphs=rawglyphs(doc,clips)
            groups=clusters(glyphs)
            # Original PDF physical order: page number, y, x. Never assume a Kanji anchor.
            groups=sorted(groups,key=lambda x:(x["page"],round(x["bbox"][1],2),round(x["bbox"][0],2)))
            readings=[g["reading"] for g in groups]
            proof["rawSourceRubies"]=[{"reading":g["reading"],"page":g["page"],"bbox":[round(t,2) for t in g["bbox"]],
                "fontSize":g["fontSize"]} for g in groups]
            if not readings:proof["reasons"].append("PDF_SOURCE_RUBY_NOT_EXTRACTED")
            if any(not re.fullmatch(r'[ぁ-んァ-ンー]{1,20}',r) for r in readings):
                proof["reasons"].append("NON_KANA_RAW_READING")
            fields,problem=cleaned_fields(q,readings)
            if problem:
                if fields is None:
                    proof["reasons"].append("SOURCE_READING_CLEANUP_UNSAFE")
                else:
                    proof["candidateReadingDifferenceAllowed"]=problem
            # Always retain original official question answer and cross-engine text validation.
            if q["officialStatus"]!="NORMAL" or q["excludeFromAccuracyDenominator"]:
                proof["reasons"].append("OFFICIALLY_INVALID_QUESTION")
            if not (q["answerNumberOfficial"]==answer["official_answer"]
                    and q["answer"]==answer["official_answer"]-1):
                proof["reasons"].append("OFFICIAL_ANSWER_MISMATCH")
            if not d["sourceNormalizedSha256"] or d["sourceNormalizedSha256"]!=d["candidateNormalizedSha256"]:
                proof["reasons"].append("SOURCE_TEXT_HASH_MISMATCH")
            if set(d["reasons"])-{"RUBY_POSITION_REVIEW","ANSWER_TABLE_REVIEW"}:
                proof["reasons"].append("NON_RUBY_SOURCE_DIFF")
            if not proof["reasons"]:
                cols=("id","year","questionNo","chapter","answer","answerNumberOfficial",
                  "sourceIssuer","sourceTitle","sourceUrl","answerSourceUrl","attributionDisplay",
                  "officialStatus","excludeFromAccuracyDenominator","sourcePdfPages")
                item={k:q[k] for k in cols}
                item.update(question=fields[0],choices=fields[1:],
                  originalRubyReadings=readings,rubyDisplayMode="SOURCE_ORDER_UNATTACHED",
                  rubySourceVerified=True,rubySourcePdfSha256=pdfHashes[year][half],
                  verbatimCertified=True,needsVisualReview=False,renderReady=True,
                  modificationDisclosureDisplay="公式PDFのふりがなを原典出現順に独立表示（漢字への対応付けを行わない加工）",
                  audit={"status":"PASS","method":"SOURCE_ORDER_UNATTACHED_PDF_RAWDICT",
                    "record":OUT.name,"sourcePdfSha256":pdfHashes[year][half],
                    "sourceNormalizedSha256":d["sourceNormalizedSha256"],
                    "readingsOrder":[{"page":g["page"],"bbox":g["bbox"],"reading":g["reading"]} for g in groups],
                    "originalCandidateQuestionSha256":hashlib.sha256(q["question"].encode()).hexdigest()})
                if item["sourceIssuer"]!="関西広域連合":raise RuntimeError("unexpected issuer")
                created.append(item)
                existing[id]=item
                proof["status"]="SOURCE_ORDER_PASS"
                proof["readingCount"]=len(readings)
        proof["reasons"]=sorted(set(proof["reasons"]))
        for reason in proof["reasons"]:reasons[reason]+=1
        evidence.append(proof)
    for yearly in docs.values():
        for doc in yearly.values():doc.close()
    assert len(evidence)==102 and len({x["id"] for x in evidence})==102
    assert sum(x["status"]=="SOURCE_ORDER_PASS" for x in evidence)==len(created)
    bank=current
    bank["questions"]=sorted(existing.values(),key=lambda q:(q["year"],q["questionNo"]))
    bank["approvedIds"]=[q["id"] for q in bank["questions"]]
    bank["count"]=len(bank["questions"])
    assert bank["count"]==len(set(bank["approvedIds"]))==len(bank["questions"])
    assert "KSAI-2023-090" not in bank["approvedIds"]
    by={}
    for y in range(2022,2027):
        key=str(y)
        # Retain previous auditing metrics and update only canonical counters.
        entry=bank["byYear"].setdefault(key,{})
        n=sum(x["year"]==y for x in bank["questions"])
        entry["approved"]=n
        entry["hold"]=120-n
        entry["sourceOrderUnattached"]=sum(q["year"]==y and q.get("rubyDisplayMode")=="SOURCE_ORDER_UNATTACHED" for q in bank["questions"])
        by[key]=n
    bank["releaseGate"]="BLOCKED_PENDING_APP_TESTS_AND_OFFICIALLY_INVALID_Q90"
    stamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")
    st["updated_at"]=stamp
    st["question_bank"].update(production_official_bank_count=bank["count"],
      verified_official_imported=bank["count"],official_question_text_imported=bank["count"])
    st["ruby_102_source_order_20261124"]={
      "policy":"SOURCE_ORDER_UNATTACHED_NO_KANJI_MAPPING",
      "recoveredFromHistoricalApprovedBank":len(historical_only),
      "historicalSourceCommit":status_commit,
      "previouslyApproved":len(existing)-len(created),
      "target":102,"previouslyApprovedWithinScope":len(previously_approved),
      "newlyPromoted":len(created),"cumulativeSourceOrderPromoted":len(previously_approved)+len(created),
      "remainingRuby":102-len(created)-len(previously_approved),
      "unapprovedIncludingOfficialInvalidQ90":600-bank["count"],
      "reasonCountsNonExclusive":dict(reasons),
      "evidence":"touroku-hanbaisha-sprint/official-kansai/"+OUT.name
    }
    st["ruby_113_auto_pipeline_20261124"]["bankVerified"]=bank["count"]
    st["ruby_113_auto_pipeline_20261124"]["remainingRubyHold"]=102-len(created)-len(previously_approved)
    st["gates"]["official_source_import"]=f"PARTIAL_APPROVED_{bank['count']}_OF_600"
    st["gates"]["release_readiness"]="BLOCKED"
    st["gates"]["content_complete"]="BLOCKED"
    st["release_gate"]="BLOCKED";st["app_review_submitted"]=False
    OUT.write_text(json.dumps({"timestamp":stamp,"policy":"SOURCE_ORDER_UNATTACHED",
       "historicalRestoreIds":historical_only,"historicalRestoreCount":len(historical_only),
       "startCurrent":current["count"]-len(historical_only)-len(created),
       "sourceBank497Sha":status_commit,"sourceHolds":102,"alreadyApproved":len(previously_approved),
       "promoted":len(created),"cumulativePromoted":len(previously_approved)+len(created),
       "held":102-len(created)-len(previously_approved),"canonicalCount":bank["count"],"byYear":by,
       "reasonCountsNonExclusive":dict(reasons),"records":evidence},ensure_ascii=False,indent=2)+"\n")
    BANK.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    STATE.write_text(json.dumps(st,ensure_ascii=False,indent=2)+"\n")
    md=IOS/"RELEASE_STATUS.md"
    md.write_text(md.read_text()+f"\n\n## 2026-11-24：未確定102問の原典ルビ順序独立表示\n"
      +f"- ユーザー指定によって漢字への推定紐付けを廃止。PDFの生文字情報で抽出したルビをページ・Y・X座標順に独立表示し、正規候補中の重複独立かな行のみ削除。原文と旧HOLDは証跡に保持。\n"
      +f"- 実測：102問中今回PASS {len(created)}、累計PASS {len(created)+len(previously_approved)}、残HOLD {102-len(created)-len(previously_approved)}。正式バンク {bank['count']}/600。現mainのバンクが以前の497から468へ戻っていたため、承認済み497問の歴史的コミット({status_commit})と現mainの和集合で承認済み{len(historical_only)}問を復旧（重複IDなし）。\n"
      +f"- HOLD理由（重複あり）：{json.dumps(dict(reasons),ensure_ascii=False)}。監査台帳：\`official-kansai/{OUT.name}\`。\n"
      +"- 2023年問90の公式無効問題は未昇格。公開判定BLOCKED、Apple実機・App Review最終送信未実施。\n")
    print(json.dumps({"canonical":bank["count"],"restoredHistorical":len(historical_only),
      "promotedSourceOrdered":len(created),"alreadyApproved":len(previously_approved),
      "rubyHold":102-len(created)-len(previously_approved),"reasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__": main()

# CI rerun: enforce cumulative 102 source-order validation and Chrome QA after safe checklist update.
