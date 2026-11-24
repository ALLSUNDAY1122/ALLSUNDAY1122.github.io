import json, pathlib, hashlib, subprocess, re, unicodedata, os, sys, collections
import fitz
R=pathlib.Path("kangoshi-sprint"); A=R/"audit"; B=R/"product-content"
sys.path.insert(0,str(R/"scripts"))
from official_answer_key_audit import parse as official_key
def load(p): return json.loads(p.read_text())
def save(p,x): p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+"\n")
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(s): return re.sub(r"\s+","",unicodedata.normalize("NFKC",s))
L=A/"ocr-other48-visual-review-20261124.json"; H=A/"dual-engine-hold-20261124.json"; V=B/"verified-additions-20261124.json"; M=B/"manifest.json"; P=A/"dual-engine-promotion-ledger-20261124.json"
l,h,v,m,p=map(load,(L,H,V,M,P))
idx={x["id"]:x for x in load(A/"residual-geometric-source-index-20261124.json")["items"]}
active={x["id"]:x for x in h["hold"]}; seen={x["id"] for x in v["questions"]}
assert len(active)+len(seen)==480 and not active&seen
assert len(l["targetIds"])==len(set(l["targetIds"]))==48
out=A/"runs/other48-revalidation";out.mkdir(parents=True,exist_ok=True)
cases={x["id"]:x for x in l["cases"]}; results=[]; new=[]
keys={e:official_key(e) for e in (111,112)}
for qid in l["targetIds"]:
 if qid not in active: continue
 g=idx[qid]; row=active[qid]; exam=row["exam"]; sess=row["session"]; num=row["number"]
 rec={"id":qid,"status":"HOLD","fields":[]}
 results.append(rec)
 try:
  pdf=pathlib.Path(f"/tmp/kangoshi-official/{exam}-{sess}.pdf")
  assert sha(pdf)==g["sourcePdfSha256"],"PDF hash mismatch"
  doc=fitz.open(pdf); page=doc[g["renderedPage"]-1]; rect=fitz.Rect(*g["clip"])
  png=out/f"{qid}-region.png";page.get_pixmap(matrix=fitz.Matrix(3,3),clip=rect,alpha=False).save(png)
  rec.update(sourcePdfSha256=sha(pdf),sourcePage=g["renderedPage"],imageSha256=sha(png),clip=g["clip"])
  assert g["anchorMatchesInWindow"]==1
  # Read full original region in independent OCR segmentation modes. No majority-based correction.
  readings={}
  for mode in (3,6,11):
   t=subprocess.run(["tesseract",str(png),"stdout","-l","jpn+eng","--psm",str(mode)],capture_output=True,text=True,timeout=90,check=True).stdout
   readings[str(mode)]=t
  rec["regionOcr"]=readings
  if qid not in cases:
   rec["reason"]="ORIGINAL_IMAGE_AND_OCR_READY_FOR_INDEPENDENT_VISUAL_REVIEW";continue
  c=cases[qid]; q=c["after"]; assert c["sourceImageVisualReviewed"] and c["sourcePdfPage"]==g["renderedPage"]
  assert c["sourcePdfSha256"]==sha(pdf) and c["sourceImageSha256"]==g["imageSha256"]
  n=len(q["choices"]); assert n in (4,5)
  words=page.get_text("words",sort=True); anchors={}
  for x0,y0,x1,y1,t,*_ in words:
   if not (rect.y0+11<=y0<rect.y1-7 and rect.x0+5<=x0<rect.x0+150):continue
   # Source has numeric labels with or without adjacent punctuation.
   match=re.match(r"^([1-5])(?:[.．、)）]|\s|$)",unicodedata.normalize("NFKC",t).strip())
   if match: anchors.setdefault(int(match.group(1)),[]).append(y0)
  assert all(len(anchors.get(i,[]))==1 for i in range(1,n+1)),f"option anchors {anchors}"
  ys=[anchors[i][0]-4 for i in range(1,n+1)]
  assert ys==sorted(ys) and len(set(ys))==n
  bounds=[rect.y0]+ys+[rect.y1]
  expected=[q["question"]]+q["choices"]
  for i,want in enumerate(expected):
   clip=fitz.Rect(rect.x0,bounds[i],rect.x1,bounds[i+1]); f=out/f"{qid}-field{i}.png"
   page.get_pixmap(matrix=fitz.Matrix(4,4),clip=clip,alpha=False).save(f)
   reads={}; matches=[]
   for mode in (3,6,7,11):
    t=subprocess.run(["tesseract",str(f),"stdout","-l","jpn+eng","--psm",str(mode)],capture_output=True,text=True,timeout=90,check=True).stdout
    reads[str(mode)]=t
    z=norm(t); label=str(num if i==0 else i)
    z=re.sub(r"^"+label+r"[.、)]?","",z,count=1)
    if z==norm(want):matches.append(mode)
   rec["fields"].append({"index":i,"expected":want,"ocr":reads,"matchingModes":matches,"imageSha256":sha(f)})
  official,keysha=keys[exam]; key=official[qid]
  assert key["status"]=="KEY_SINGLE" and key["rawValue"]==str(q["answer"]+1) and keysha==q["officialKeyPdfSha256"]
  assert q["officialScoringStatus"]=="normal"
  rec["officialKeyMatched"]=True
  if not all(len(f["matchingModes"])>=2 for f in rec["fields"]):
   rec["reason"]="STRICT_FIELD_OCR_NOT_MATCHED_IN_TWO_MODES";continue
  q=dict(q);q.update(publishable=False,releaseEligible=False,requiresMedia=False,mediaAuditStatus="not_required",rightsStatus="mhlw-pdl1.0-text",canonicalStatus="source_verified_extension",reviewStatus="VISUAL_AND_INDEPENDENT_OCR_SOURCE_ONLY_EXPLANATION_PENDING",textFidelity="VERIFIED_SOURCE_ONLY",answerSourceChecked=True,printedOptionCount=n,answerType="singleChoice",category="必修" if num<=25 else "一般",majorSubject=None,point=None,detail=None)
  q["audit"]={"sourcePageVisualReviewed":True,"allPrintedChoicesVisualReviewed":True,"officialKeyMatched":True,"independentOcrFieldMatch":True,"explanationIndependentlyReviewed":False,"runtimeIntegrationChecked":False}
  q["evidence"]={"sourcePdfPage":g["renderedPage"],"sourcePdfSha256":sha(pdf),"sourceImageSha256":g["imageSha256"],"auditLedger":str(L)}
  new.append(q);rec["status"]="PASS_SOURCE_ONLY";c["status"]="PASS_SOURCE_ONLY"
 except Exception as e:rec["reason"]=str(e)
newids={q["id"] for q in new};assert len(newids)==len(new) and not newids&seen
v["questions"].extend(new);v["questions"].sort(key=lambda q:(-q["sourceExam"],q["session"],q["questionNo"]));v["count"]=len(v["questions"])
h["hold"]=[x for x in h["hold"] if x["id"] not in newids];h["count"]=len(h["hold"]);total=720+v["count"]
assert v["count"]+h["count"]==480 and all(q["publishable"] is False and q["releaseEligible"] is False for q in v["questions"])
m["verifiedExtension"].update(canonicalSourceVerifiedCount=v["count"],canonicalSourceVerifiedTotal=total,remainingNotVerified=h["count"],runtimeAdditionalCount=0,releaseEligibleAdditionalCount=0)
p.update(newPromoted=len(new),newIds=sorted(newids),canonicalVerified=v["count"])
l.update(canonicalAfter=total,newPromoted=len(new),remaining=h["count"],latestRunId=os.environ["GITHUB_RUN_ID"],latestOcrResults=results)
for path,data in ((V,v),(H,h),(M,m),(P,p),(L,l)):save(path,data)
s=load(R/"release-status.json");s.update(recordedImported=total,newlyImported=v["count"],additionalRequired=h["count"],releaseStatus="PREFLIGHT_BLOCKED",submissionAllowed=False,contentGate=f"CANONICAL_SOURCE_{total}_OF_1200_EXISTING_RUNTIME_720_NEW{v['count']}_RELEASE_BLOCKED_{h['count']}_UNVERIFIED")
s["canonicalBank"].update(sourceVerifiedExtension=v["count"],verifiedTotal=total,unverifiedRemaining=h["count"],extensionRuntimeEligible=0,extensionPublished=0)
s["staging"].update(verifiedExtensionCount=v["count"],remainingNotCanonicalVerified=h["count"],publishableNew=0)
s["automation"]["bulkHoldCount"]=h["count"];s["textAudit"]["notImported"]=h["count"]
s["holdRemediation"].update(finalHold=h["count"],netReleasedFromHold=413-h["count"],reasonCountsNow=dict(collections.Counter(reason for row in h["hold"] for reason in row["reasons"])))
s["latestOther48VisualReview"].update(runId=os.environ["GITHUB_RUN_ID"],ocrAttempted=len(results),fullyRevalidated=sum(c["status"]=="PASS_SOURCE_ONLY" for c in cases.values()),newPromoted=len(new),remainingInScope=len(set(l["targetIds"])&{x["id"] for x in h["hold"]}),canonical=total,totalHeld=h["count"],status="SOURCE_ONLY_RELEASE_BLOCKED")
save(R/"release-status.json",s)
with (R/"RELEASE_STATUS.md").open("a") as f:f.write(f"\n## OCRその他48問 独立OCR Run {os.environ['GITHUB_RUN_ID']}\n\n- OCR試行 {len(results)}問、昇格 {len(new)}問、正規 {total}/1200、保留 {h['count']}。目視未確認の候補は昇格禁止。公開・本審査禁止。\n")
print(json.dumps({"checked":len(results),"promoted":sorted(newids),"total":total,"held":h["count"]},ensure_ascii=False))
