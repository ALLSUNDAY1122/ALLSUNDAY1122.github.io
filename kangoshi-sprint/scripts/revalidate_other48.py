import json, pathlib, hashlib, subprocess, re, unicodedata, os, sys, collections
import fitz
from PIL import Image, ImageOps, ImageFilter, ImageDraw
import easyocr
reader=easyocr.Reader(['ja','en'],gpu=False,verbose=False)
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
assert len(active)+len(seen)==480 and not (set(active)&seen)
assert len(l["targetIds"])==len(set(l["targetIds"]))==48
out=A/"runs/other48-revalidation";out.mkdir(parents=True,exist_ok=True)
cases={x["id"]:x for x in l["cases"]}; results=[]; new=[]
keys={e:official_key(e) for e in (111,112)}
scope=l["targetIds"][29:]
assert len(scope)==19
for qid in scope:
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
  # Exclude page footer by its actual PDF word coordinates, never by truncating OCR text.
  footer=[w[1] for w in words if 'DKIX-' in w[4] and w[1]>ys[-1]]
  end=min([rect.y1]+[y-5 for y in footer])
  assert end>ys[-1]+10
  bounds=[rect.y0]+ys+[end]
  rec["footerBoundary"]={"originalEnd":rect.y1,"adjustedEnd":end,"footerY":footer}
  expected=[q["question"]]+q["choices"]
  for i,want in enumerate(expected):
   clip=fitz.Rect(rect.x0,bounds[i],rect.x1,bounds[i+1]); f=out/f"{qid}-field{i}.png"
   page.get_pixmap(matrix=fitz.Matrix(4,4),clip=clip,alpha=False).save(f)
   # Separate explicitly registered English gloss by unique exact PDF span geometry.
   glosses=[g for g in q.get("sourceEnglishGloss",[]) if isinstance(g,dict) and g.get("field")==("question" if i==0 else f"choice{i}")]
   masked=[]
   for gloss in glosses:
    candidates=[]
    for block in page.get_text("dict",clip=clip)["blocks"]:
     for line in block.get("lines",[]):
      for span in line["spans"]:
       if norm(span["text"])==norm(gloss["text"]):candidates.append(span)
    assert len(candidates)==1,"Gloss geometry not uniquely verified"
    b=fitz.Rect(candidates[0]["bbox"])
    # A gloss must be an independent smaller-font span, not inline body text.
    assert candidates[0]["size"]<10,"Gloss font not independently distinguishable"
    gf=out/f"{qid}-field{i}-gloss{len(masked)}.png"
    page.get_pixmap(matrix=fitz.Matrix(5,5),clip=b,alpha=False).save(gf)
    gt=" ".join(reader.readtext(str(gf),detail=0,paragraph=False))
    tt=subprocess.run(["tesseract",str(gf),"stdout","-l","eng","--psm","7"],capture_output=True,text=True,check=True,timeout=90).stdout
    assert norm(gt)==norm(gloss["text"]) or norm(tt)==norm(gloss["text"]),"Gloss OCR not confirmed"
    masked.append({"bbox":list(b),"text":gloss["text"],"easyocr":gt,"tesseract":tt,"sha256":sha(gf)})
   def mask_gloss(fn,region,scale):
    if not masked:return
    im=Image.open(fn).convert("RGB");draw=ImageDraw.Draw(im)
    for item in masked:
     b=item["bbox"];draw.rectangle(((b[0]-region.x0)*scale,(b[1]-region.y0)*scale,(b[2]-region.x0)*scale,(b[3]-region.y0)*scale),fill="white")
    im.save(fn)
   mask_gloss(f,clip,4)
   reads={}; matches=[]; variants=[]
   for mode in (3,6,7,11):
    t=subprocess.run(["tesseract",str(f),"stdout","-l","jpn+eng","--psm",str(mode)],capture_output=True,text=True,timeout=90,check=True).stdout
    reads[str(mode)]=t
    z=norm(t); label=str(num if i==0 else i)
    z=re.sub(r"^"+label+r"[.、)]?","",z,count=1)
    if z==norm(want):matches.append(mode)
   # Retry only on mismatch, preserving exact text comparison and source pixels.
   # A variant never substitutes expected characters into OCR output.
   if len(matches)<2:
    for scale in (5,7):
     for pad in (0,2):
      region=fitz.Rect(max(0,clip.x0-pad),max(rect.y0,clip.y0-pad),min(page.rect.width,clip.x1+pad),min(end,clip.y1+pad))
      raw=out/f"{qid}-field{i}-s{scale}-p{pad}.png"
      page.get_pixmap(matrix=fitz.Matrix(scale,scale),clip=region,alpha=False).save(raw)
      mask_gloss(raw,region,scale)
      gray=ImageOps.autocontrast(Image.open(raw).convert("L"))
      for threshold in (None,160,200):
       im=gray if threshold is None else gray.point(lambda v:255 if v>=threshold else 0)
       # Remove only blank margins; leave a white border for recognition.
       box=ImageOps.invert(im).getbbox()
       if box:im=ImageOps.expand(im.crop(box),border=32,fill=255)
       fn=out/f"{qid}-field{i}-s{scale}-p{pad}-t{threshold}.png";im.save(fn)
       for mode in ((6,11) if i==0 else (6,7,13)):
        t=subprocess.run(["tesseract",str(fn),"stdout","-l","jpn+eng","--psm",str(mode)],capture_output=True,text=True,timeout=90,check=True).stdout
        z=norm(t);z=re.sub(r"^"+label+r"[.、)]?","",z,count=1)
        ok=z==norm(want)
        variants.append({"scale":scale,"pad":pad,"threshold":threshold,"psm":mode,"ocr":t,"match":ok,"image":fn.name,"imageSha256":sha(fn)})
        if ok and mode not in matches:matches.append(mode)
       if len(matches)>=2:break
      if len(matches)>=2:break
     if len(matches)>=2:break
   # Independent recognition model: EasyOCR Japanese + English.
   easy=[]
   for fn in [f]+[out/t["image"] for t in variants if t["psm"]==6][:4]:
    t=" ".join(reader.readtext(str(fn),detail=0,paragraph=False))
    z=re.sub(r"^"+label+r"[.、)]?","",norm(t),count=1)
    easy.append({"image":fn.name,"sha256":sha(fn),"ocr":t,"match":z==norm(want)})
   rec["fields"].append({"index":i,"expected":want,"ocr":reads,"matchingModes":matches,"imageSha256":sha(f),"preprocessingTrials":variants,"easyocrTrials":easy,"glossEvidence":masked})
  official,keysha=keys[exam]; key=official[qid]
  assert key["status"]=="KEY_SINGLE" and key["rawValue"]==str(q["answer"]+1) and keysha==q["officialKeyPdfSha256"]
  assert q["officialScoringStatus"]=="normal"
  rec["officialKeyMatched"]=True
  if not all(len(f["matchingModes"])>=2 or (len(f["matchingModes"])>=1 and any(t["match"] for t in f["easyocrTrials"])) for f in rec["fields"]):
   rec["reason"]="STRICT_FIELD_OCR_NOT_MATCHED_IN_TWO_MODES_OR_ENGINES";continue
  if q.get("requiresLayoutReview"):
   rec["reason"]="INDEPENDENT_LAYOUT_REVIEW_REQUIRED";continue
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
l.setdefault("previousOcrRuns",[]).append({"runId":l.get("latestRunId"),"results":l.get("latestOcrResults",[])})
l.update(canonicalAfter=total,newPromoted=len(new),remaining=h["count"],latestRunId=os.environ["GITHUB_RUN_ID"],latestOcrResults=results)
for path,data in ((V,v),(H,h),(M,m),(P,p),(L,l)):save(path,data)
s=load(R/"release-status.json");s.update(recordedImported=total,newlyImported=v["count"],additionalRequired=h["count"],releaseStatus="PREFLIGHT_BLOCKED",submissionAllowed=False,contentGate=f"CANONICAL_SOURCE_{total}_OF_1200_EXISTING_RUNTIME_720_NEW{v['count']}_RELEASE_BLOCKED_{h['count']}_UNVERIFIED")
s["canonicalBank"].update(sourceVerifiedExtension=v["count"],verifiedTotal=total,unverifiedRemaining=h["count"],extensionRuntimeEligible=0,extensionPublished=0)
s["staging"].update(verifiedExtensionCount=v["count"],remainingNotCanonicalVerified=h["count"],publishableNew=0)
s["automation"]["bulkHoldCount"]=h["count"];s["textAudit"]["notImported"]=h["count"]
s["holdRemediation"].update(finalHold=h["count"],netReleasedFromHold=413-h["count"],reasonCountsNow=dict(collections.Counter(reason for row in h["hold"] for reason in row["reasons"])))
s["latestOther48VisualReview"].update(independentOcrBlocker="See current per-field preprocessing trials; no character substitution allowed",runId=os.environ["GITHUB_RUN_ID"],ocrAttempted=len(results),fullyRevalidated=sum(c["status"]=="PASS_SOURCE_ONLY" for c in cases.values()),newPromoted=len(new),remainingInScope=len(set(l["targetIds"])&{x["id"] for x in h["hold"]}),canonical=total,totalHeld=h["count"],status="SOURCE_ONLY_RELEASE_BLOCKED")
s["latestOther48VisualReview"].update(nextOcrStatus="ADDITIONAL_19_COMPLETED_RUNNER",pendingAdditionalRunScope=0)
save(R/"release-status.json",s)
with (R/"RELEASE_STATUS.md").open("a") as f:f.write(f"\n## OCRその他48問 独立OCR Run {os.environ['GITHUB_RUN_ID']}\n\n- OCR試行 {len(results)}問、昇格 {len(new)}問、正規 {total}/1200、保留 {h['count']}。目視未確認の候補は昇格禁止。公開・本審査禁止。\n")
save(out/"run-result.json",{"runId":os.environ["GITHUB_RUN_ID"],"results":results,"promotedCandidates":new,"canonicalTotal":total,"held":h["count"]})
print(json.dumps({"checked":len(results),"promoted":sorted(newids),"total":total,"held":h["count"]},ensure_ascii=False))
