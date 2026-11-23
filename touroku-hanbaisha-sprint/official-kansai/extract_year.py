#!/usr/bin/env python3
"""Extract 2026 Kansai official registered seller questions into an auditable STAGING JSON.
Never certify text equivalence without independent visual checks.
"""
import hashlib,json,re,sys,urllib.request,os
from pathlib import Path
try:
 import fitz
except ImportError:
 raise SystemExit("PyMuPDF is required: pip install pymupdf")
BASE=Path(__file__).resolve().parent
ROOT=BASE.parent
SOURCE=json.loads((BASE/"SOURCES_2022_2026.json").read_text())
YEAR=int(os.environ.get("EXAM_YEAR",sys.argv[1] if len(sys.argv)>1 else "2022"))
if YEAR not in (2022,2023,2024,2025):raise SystemExit("Only missing 4 years supported")
ITEM=next(x for x in SOURCE["years"] if x["year"]==YEAR)
ANS=json.loads((BASE/f"ANSWERS_{YEAR}_OFFICIAL.json").read_text())
assert len(ANS["questions"])==120
RANGE=[("first_half",ITEM["question_pdf_first_half"],1,60),("second_half",ITEM["question_pdf_second_half"],61,120)]
PDFDIR=BASE/"pdf"/str(YEAR);PDFDIR.mkdir(parents=True,exist_ok=True)
DIGITS=str.maketrans("０１２３４５６７８９","0123456789")
HEAD=re.compile(r"^\s*問\s*([０-９0-9]{1,3})\s*$",re.M)
def acquire(url,name):
 output=PDFDIR/(name+".pdf")
 if not output.exists():
  request=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 (compatible; official-exam-audit/1.0)"})
  with urllib.request.urlopen(request,timeout=60) as response:
   output.write_bytes(response.read())
 if output.read_bytes()[:4]!=b"%PDF":
  raise RuntimeError("invalid PDF: "+url)
 return output
questions=[];artifacts=[]
for half,url,start,end in RANGE:
 path=acquire(url,half)
 binary=path.read_bytes();sha=hashlib.sha256(binary).hexdigest()
 doc=fitz.open(path)
 if len(doc)<30:raise RuntimeError(f"{half}: unexpected {len(doc)} pages")
 chunks=[];current=None
 for pageno,page in enumerate(doc):
  # Reading order has to be independently visually checked for multi-column/furigana
  text=page.get_text("text",sort=True)
  for line in text.splitlines():
   head=HEAD.match(line)
   if head:
    num=int(head.group(1).translate(DIGITS))
    if start<=num<=end:
     if current:chunks.append(current)
     current={"number":num,"lines":[],"pages":[pageno+1]}
     continue
   if current:
    if pageno+1 not in current["pages"]:current["pages"].append(pageno+1)
    current["lines"].append(line)
 if current:chunks.append(current)
 nums=[c["number"] for c in chunks]
 expected=list(range(start,end+1))
 if nums!=expected:
  raise RuntimeError(f"{half}: expected 60 sequential questions but got {len(nums)}; missing={sorted(set(expected)-set(nums))}, duplicates={len(nums)-len(set(nums))}")
 for chunk in chunks:
  n=chunk["number"]
  cleaned=[line for line in chunk["lines"] if not re.fullmatch(r"\s*[♯＃#]{15,}\s*",line) and not re.fullmatch(r"\s*-\s*[0-9０-９]{1,3}\s*-\s*",line)]
  raw="\n".join(cleaned).strip()
  if len(raw)<35:raise RuntimeError(f"Q{n}: suspiciously short text")
  # Choices may be presented in a table or interrupted by ruby text.
  # Do NOT attempt to reflow into unreliable 5-choice UI before manual review.
  answer=ANS["questions"][n-1]
  assert answer["question_no"]==n and (answer["official_answer"] in range(1,6) or (YEAR==2023 and n==90 and answer["official_answer"] is None))
  chapter=("第1章" if n<=20 else "第3章" if n<=60 else "第2章" if n<=80 else "第4章" if n<=100 else "第5章")
  questions.append({
   "id":f"KSAI-{YEAR}-{n:03d}","year":YEAR,"questionNo":n,"chapter":chapter,
   "rawOriginalText":raw,"question":None,"choices":None,
   "answer":answer["official_answer"]-1 if answer["official_answer"] is not None else None,"answerNumberOfficial":answer["official_answer"],
   "officialStatus": "OFFICIALLY_INVALID_ALL_CANDIDATES_CORRECT" if YEAR==2023 and n==90 else "NORMAL",
   "excludeFromAccuracyDenominator": YEAR==2023 and n==90,
   "scoringPolicy":"ALL_CANDIDATES_CORRECT_NO_STANDARD_GRADING" if YEAR==2023 and n==90 else "SINGLE_ANSWER",
   "sourceIssuer":"関西広域連合","sourceTitle":f"令和{YEAR-2018}年度登録販売者試験",
   "sourceUrl":url,"answerSourceUrl":ANS["source_url"],"sourcePdfPages":chunk["pages"],
   "attributionDisplay":f"出典：関西広域連合「令和{YEAR-2018}年度登録販売者試験」問{n}",
   "modificationDisclosureDisplay":"PDFからテキスト抽出（改行・表の配置は原典と異なる場合があります）",
   "verbatimCertified":False,"needsVisualReview":True,"renderReady":False,
   "extractionMethod":"PyMuPDF page.get_text(sort=True), raw unedited"
  })
 artifacts.append({"half":half,"url":url,"sha256":sha,"bytes":len(binary),"pages":len(doc)})
if [x["questionNo"] for x in questions]!=list(range(1,121)):raise RuntimeError("invalid full sequence")
out={"issuer":"関西広域連合","year":YEAR,"releaseStatus":"STAGING_NOT_VERBATIM_CERTIFIED","questionCount":120,
 "answerIndexCount":120,"renderReadyCount":0,"verbatimCertifiedCount":0,
 "manualAuditRequired":"Each stem, all choices, tables, charts and special glyphs against PDF screenshot",
 "sourcePdfs":artifacts,"questions":questions}
target=BASE/f"QUESTIONS_{YEAR}_RAW_STAGING.json"
target.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
(BASE/f"PDF_SHA256_{YEAR}.json").write_text(json.dumps(artifacts,ensure_ascii=False,indent=2)+"\n")
print(f"wrote {target} questions={len(questions)}; PDF SHA count={len(artifacts)}")
