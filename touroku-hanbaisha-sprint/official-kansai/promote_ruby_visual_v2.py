#!/usr/bin/env python3
"""Promote ONLY directly inspected ruby/rt screenshots with frozen official source evidence.

No implicit auto-approval of the other 92. Preserve all prior 440, crop provenance,
cross-extractor holds and 2023 Q90. No App Review action.
"""
import datetime,hashlib,json,re
from pathlib import Path
B=Path(__file__).resolve().parent
ROOT=B.parents[1]
IOS=ROOT/"touroku-hanbaisha-ios"
def load(path):return json.loads(path.read_text())
def gitblob(path):
    b=path.read_bytes()
    return hashlib.sha1(f"blob {len(b)}\0".encode()+b).hexdigest()
def parts_for_field(text,mappings):
    pat=lambda s:re.compile(r"(?m)^[ \t]*"+re.escape(s)+r"[ \t]*$")
    spans=[]
    for m in mappings:
        hits=list(pat(m["reading"]).finditer(text))
        if len(hits)!=1:return None
        spans.append((hits[0].start(),hits[0].end(),m))
    if len({a for a,_,m in spans})!=len(spans):return None
    cleaned=text
    for start,end,_ in sorted(spans,key=lambda z:z[0],reverse=True):
        cleaned=cleaned[:start]+cleaned[end:]
    anchors=[]
    for _,__,m in spans:
        if len(m["base"])!=1 or cleaned.count(m["base"])!=1:return None
        anchors.append((cleaned.index(m["base"]),m))
    anchors.sort(key=lambda z:z[0])
    out=[];cursor=0
    for offset,m in anchors:
        if offset<cursor:return None
        out.extend(({"text":cleaned[cursor:offset]},
          {"rubyBase":m["base"],"rubyText":m["reading"],"sourcePage":m["page"]}))
        cursor=offset+len(m["base"])
    out.append({"text":cleaned[cursor:]})
    if "".join(x.get("text",x.get("rubyBase","")) for x in out)!=cleaned:return None
    return out
visual=load(B/"RUBY_VISUAL_AUDIT_V2_120_20261124.json")
compfile=B/"RUBY_REBUILT_COMPARISON_120_20261124.json"
if visual["comparisonManifestBlob"]!=gitblob(compfile):raise RuntimeError("comparison screenshots manifest was altered")
compare=load(compfile)
old=load(B/"RUBY_FONT_CLUSTER_ALL_20261124.json")
bankfile=B/"APPROVED_OFFICIAL_BANK.json"
bank=load(bankfile)
# This promotion may already have been committed by a parallel release coordinator.
# Idempotence prevents a successful 468 bank from being treated as a failure.
if bank["count"]==468:
    visual_now=load(B/"RUBY_VISUAL_AUDIT_V2_120_20261124.json")
    passed=set(visual_now["approvedIds"])
    indexed={q["id"]:q for q in bank["questions"]}
    state_now=load(IOS/"release-status.json")
    if len(passed)!=28 or not passed.issubset(indexed):
        raise RuntimeError("468 count does not include all 28 visually approved IDs")
    if state_now["question_bank"]["production_official_bank_count"]!=468:
        raise RuntimeError("release state and already-promoted bank disagree")
    if "KSAI-2023-090" in indexed or state_now["release_gate"]!="BLOCKED":
        raise RuntimeError("published bank violates release gate")
    print(json.dumps({"approved":468,"added":0,"alreadyPromoted":28,
       "note":"Visual v2 28 promotions already persisted; no duplicate write"},ensure_ascii=False))
    raise SystemExit(0)
if bank["count"]!=440 or len(bank["questions"])!=440 or len(set(bank["approvedIds"]))!=440:
    raise RuntimeError("baseline release bank not exactly 440; stop and reconcile")
if visual["questionCount"]!=120 or visual["visualPass"]!=28 or len(visual["approvedIds"])!=28:
    raise RuntimeError("invalid direct visual review")
if len(visual["records"])!=120 or visual["visualReviewedImagePairs"]!=32:
    raise RuntimeError("incomplete visual audit record")
reviews={r["id"]:r for r in visual["records"]}
sourcegroups={r["id"]:r for r in old["records"]}
reports={r["id"]:r for r in compare["records"]}
if len(reviews)!=120 or len(reports)!=120 or len(sourcegroups)!=130:
    raise RuntimeError("wrong audit source dimensions")
eligible=set(visual["approvedIds"])
if {r["id"] for r in visual["records"] if r["status"]=="VISUAL_PASS"}!=eligible:
    raise RuntimeError("unreviewed candidate marked PASS")
existing=set(bank["approvedIds"])
if eligible & existing:raise RuntimeError("visual PASS already in bank; no double count")
for y in range(2022,2027):
    p=B/f"QUESTIONS_{y}_APP_CANDIDATE.json"
    a=B/f"ANSWERS_{y}_OFFICIAL.json"
    freeze=visual["frozenEvidence"][str(y)]
    if gitblob(p)!=freeze["candidateBlob"] or gitblob(a)!=freeze["answerBlob"]:
        raise RuntimeError(f"source/answer hash drift: {y}")
added=[]
peryear={}
for y in range(2022,2027):
    qa=load(B/f"QUESTIONS_{y}_APP_CANDIDATE.json")["questions"]
    answers=load(B/f"ANSWERS_{y}_OFFICIAL.json")["questions"]
    auto=load(B/f"AUTO_DIFF_{y}.json")["questions"]
    geo=load(B/f"GEOMETRY_AUDIT_{y}.json")["questions"]
    sample=load(B/f"CROSSCHECK_{y}.json")
    blocked={r["id"] for r in sample["results"] if r["status"]=="REVIEW_EXTRACTOR_DISAGREEMENT"}
    peryear[str(y)]=0
    for i,q in enumerate(qa):
        id=q["id"]
        if id not in eligible:continue
        if id in blocked or (y==2023 and i+1==90):raise RuntimeError("cross-check/official exception: "+id)
        rv=reviews[id];rc=reports[id];og=sourcegroups[id];dx=auto[i];gx=geo[i]
        if rv["status"]!="VISUAL_PASS" or not rv["directVisualReviewed"] or rv["issues"]:
            raise RuntimeError("no actual direct source screenshot approval for "+id)
        if rc["issues"] or rc["rubyDomCount"]<1 or not rc["imageRegenerated"]:
            raise RuntimeError("comparison rendered ruby count not clean: "+id)
        if len(rc["generatedMappings"])!=len(og["sourceRubyGroups"]) or len(rc["generatedMappings"])!=rc["rubyDomCount"]:
            raise RuntimeError("incomplete reading-to-glyph mapping: "+id)
        if q["questionNo"]!=i+1 or answers[i]["question_no"]!=i+1:
            raise RuntimeError("question/answer index mismatch "+id)
        if q["answerNumberOfficial"]!=answers[i]["official_answer"] or q["answer"]!=answers[i]["official_answer"]-1:
            raise RuntimeError("official answer mismatch "+id)
        if q["excludeFromAccuracyDenominator"] or q["officialStatus"]!="NORMAL":
            raise RuntimeError("invalid scoring status "+id)
        if dx["candidateNormalizedSha256"]!=dx["sourceNormalizedSha256"]:
            raise RuntimeError("original PDF raw text mismatch "+id)
        if set(dx["reasons"])-{"RUBY_POSITION_REVIEW","ANSWER_TABLE_REVIEW"}:
            raise RuntimeError("other unresolved diff reason "+id)
        if gx["reasons"]!=["RUBY_RENDER_NOT_CERTIFIED"]:
            raise RuntimeError("other geometry issue "+id)
        if "ANSWER_TABLE_REVIEW" in dx["reasons"] and (gx.get("table") or {}).get("status")!="PASS":
            raise RuntimeError("choice table XY not validated "+id)
        for k in ("officialSourceImage","repairedCandidateScreenshot","repairedCandidateHtml"):
            path=B/rc[k]
            if not path.exists() or path.stat().st_size<100:
                raise RuntimeError("visual evidence file missing "+id+" "+k)
        for k in ("officialSourceImage","repairedCandidateScreenshot"):
            if (B/rc[k]).read_bytes()[:8]!=b"\x89PNG\r\n\x1a\n":
                raise RuntimeError("visual evidence not PNG "+id)
        fields=[q["question"],*q["choices"]]
        rich=[]
        for ix,text in enumerate(fields):
            mapping=[m for m in rc["generatedMappings"] if m["fieldIndex"]==ix]
            result=parts_for_field(text,mapping) if mapping else [{"text":text}]
            if not result:raise RuntimeError("unable to reconstruct rich source "+id)
            rich.append(result)
        count=sum("rubyBase" in p for part in rich for p in part)
        if count!=rc["rubyDomCount"]:raise RuntimeError("DOM ruby and markup count differ "+id)
        names=("id","year","questionNo","chapter","answer","answerNumberOfficial","sourceIssuer",
          "sourceTitle","sourceUrl","answerSourceUrl","attributionDisplay","officialStatus",
          "excludeFromAccuracyDenominator","sourcePdfPages")
        item={k:q[k] for k in names}
        item.update({"questionParts":rich[0],"choicesParts":rich[1:],
          "question":"".join(v.get("text",v.get("rubyBase","")) for v in rich[0]),
          "choices":["".join(v.get("text",v.get("rubyBase","")) for v in part) for part in rich[1:]],
          "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,
          "modificationDisclosureDisplay":"原典PDFと照合したルビをHTML ruby/rt要素で再配置（加工）",
          "audit":{"status":"PASS","method":"DIRECT_VISUAL_SOURCE_AND_NOTO_RUBY_SCREENSHOT_V2",
           "record":"RUBY_VISUAL_AUDIT_V2_120_20261124.json",
           "officialSourceImage":rc["officialSourceImage"],
           "repairedCandidateScreenshot":rc["repairedCandidateScreenshot"],
           "rubyCount":count,"officialPdfNormalizedTextSha256":dx["sourceNormalizedSha256"]}})
        if item["sourceIssuer"]!="関西広域連合":raise RuntimeError("wrong issuer")
        if len(item["choices"]) not in (4,5):raise RuntimeError("choice count")
        bank["questions"].append(item)
        existing.add(id);added.append(id);peryear[str(y)]+=1
        stats=bank["byYear"][str(y)]
        stats["rubyVisualV2"]=stats.get("rubyVisualV2",0)+1
        stats["hold"]-=1
        if stats["hold"]<0:raise RuntimeError("negative hold after promotion")
if len(added)!=28 or set(added)!=eligible:raise RuntimeError("expected 28 exact promotions, got "+str(len(added)))
bank["questions"].sort(key=lambda q:(q["year"],q["questionNo"]))
bank["approvedIds"]=[x["id"] for x in bank["questions"]]
bank["count"]=len(bank["questions"])
assert bank["count"]==468==len(set(bank["approvedIds"]))
assert "KSAI-2023-090" not in bank["approvedIds"]
assert sum(x["audit"]["method"]=="OFFICIAL_PDF_IMAGE_CROP_SCOPE_RIGHTS_MOBILE" for x in bank["questions"])==44
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")
bankfile.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
state_path=IOS/"release-status.json"
state=load(state_path)
if state["question_bank"]["production_official_bank_count"]!=440:
    raise RuntimeError("status source count changed concurrently")
state["updated_at"]=now
state["question_bank"].update({
   "production_official_bank_count":468,
   "verified_official_imported":468,
   "official_question_text_imported":468,
   "ruby_visual_comparison_v2":{"sourceQuestions":120,"regeneratedScreenshots":120,
     "contactSheets":15,"font":"Noto Sans CJK JP","rubyRtRendered":62,
     "fullRubyMappingWithoutIssues":32,"directVisualPairsReviewed":32,
     "promoted":28,"promotedIds":added,"remainingHoldInThis120":92,
     "holdsUnresolvedGlyphs":88,"holdsIngredientTableLayout":4,
     "yearlyPromotions":peryear,"record":"touroku-hanbaisha-sprint/official-kansai/RUBY_VISUAL_AUDIT_V2_120_20261124.json"},
   "ruby_unconfirmed_visual_v2_remaining":92})
state["gates"].update({"ruby_visual_comparison_v2":"PASS_120_SCREENSHOTS_28_VISUAL_PASS_92_HOLD",
                       "official_source_import":"PARTIAL_APPROVED_468_OF_600",
                       "content_complete":"BLOCKED","release_readiness":"BLOCKED"})
state["release_gate"]="BLOCKED";state["app_review_submitted"]=False
for path in ("RUBY_REBUILT_COMPARISON_120_20261124.json","RUBY_VISUAL_AUDIT_V2_120_20261124.json"):
    e="touroku-hanbaisha-sprint/official-kansai/"+path
    if e not in state.setdefault("evidence",[]):state["evidence"].append(e)
state_path.write_text(json.dumps(state,ensure_ascii=False,indent=2)+"\n")
md=IOS/"RELEASE_STATUS.md"
summary=", ".join(f"{year}年{n}問" for year,n in peryear.items())
md.write_text(md.read_text()+f"""
## 2026-11-24｜日本語フォント・ruby/rt比較画像の修復と目視昇格（最新）
- 公式PDFと候補の左右比較：日本語Noto Sans CJK JPを導入し120問の375px新PNG、120比較ページ、15コンタクトシートを生成。HTMLでruby・rtを実生成したのは62問。
- ルビの読み・漢字・位置が自動で矛盾なく対応付く32問の原典画像とアプリ候補を直接目視確認。**28問が目視PASS**（{summary}）。公式問題・公式正答索引・PDF正規化diff・正誤表座標を独立して再照合し正式昇格。
- 4問は原典の成分表を候補HTMLが忠実な表形式で再現できないためHOLD（2024-040、2025-044、2025-052、2026-036）。残88問は複数候補・欠けた読み対応などでHOLD。**比較対象120問の残保留は92問。**
- **正式問題バンク：468/600問、未昇格132問。** 2023年度問90の公式不適切・採点除外は維持し昇格なし。既存44問の公式PDF画像方式の証拠も保持。
- 証跡：\`RUBY_REBUILT_COMPARISON_120_20261124.json\`, \`RUBY_VISUAL_AUDIT_V2_120_20261124.json\`, \`ruby-font-review/CONTACT_SHEET_V2_01.jpg\`〜\`15.jpg\`。**未認証の画像を勝手に合格扱いしない。**
- ブラウザ375px候補の比較は完了。iOS Safari実機／TestFlight／本審査ゲートは別途未完了。**本審査未提出、BLOCKED**。
""")
print(json.dumps({"approved":bank["count"],"added":len(added),"byYear":peryear,
  "holdIn120":92,"remainingAll":600-bank["count"]},ensure_ascii=False))
