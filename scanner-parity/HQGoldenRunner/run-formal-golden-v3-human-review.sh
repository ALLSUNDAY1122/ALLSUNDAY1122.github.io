#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"

workspace=""
review_decisions=""

while (( $# > 0 )); do
  key="$1"
  shift
  if (( $# == 0 )); then
    echo "Missing value for $key" >&2
    exit 2
  fi
  value="$1"
  shift
  case "$key" in
    --workspace) workspace="$value" ;;
    --review-decisions) review_decisions="$value" ;;
    *)
      echo "Unsupported Golden v3 human-review argument: $key" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$workspace" ]]; then
  echo "Usage: $0 --workspace <thresholded Golden v3 workspace> [--review-decisions <completed-review.json>]" >&2
  exit 2
fi

report="$workspace/hq-golden-execution.json"
bundle="$workspace/06-golden-review"
base_index="$bundle/index.html"
template="$bundle/hq-golden-review-template.json"
portal="$bundle/review-and-finalize.html"
final="$workspace/hq-formal-golden-final.json"

for required in "$report" "$base_index"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required Golden human-review input: $required" >&2
    exit 3
  fi
done

python3 - "$report" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    report = json.load(f)
assert report.get("schemaVersion", 0) >= 4, "execution report schemaVersion must be >= 4"
assert report.get("formalGoldenVerdict") == "PENDING_HUMAN_VISUAL_OCR_REVIEW", "execution is not waiting for human visual/OCR review"
assessment = report.get("machineGateAssessment") or {}
assert assessment.get("verdict") == "MACHINE_GATES_PASS_HUMAN_VISUAL_OCR_REVIEW_PENDING", "machine gate has not passed"
assert not (assessment.get("blockingReasons") or []), "machine gate still has blockers"
assert report.get("videoSHAMatchesExpected") is True, "video SHA is not verified"
assert report.get("pdfSHAMatchesExpected") is True, "PDF SHA is not verified"
assert isinstance(report.get("outputPageCount"), int) and report["outputPageCount"] > 0, "invalid output page count"
print("GOLDEN_V3_HUMAN_REVIEW_PRECONDITION_PASS")
PY

if [[ -n "$review_decisions" ]]; then
  if [[ ! -f "$review_decisions" ]]; then
    echo "Completed review decision file does not exist: $review_decisions" >&2
    exit 3
  fi

  swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-finalizer \
    --execution-report "$report" \
    --review-decisions "$review_decisions" \
    --output "$final" >/dev/null

  python3 - "$final" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    final = json.load(f)
verdict = final.get("verdict")
if verdict != "FORMAL_GOLDEN_PASS":
    blockers = final.get("blockingReasons") or []
    pending = final.get("pendingPageSequences") or []
    failed = final.get("failedPageSequences") or []
    print(f"FINALIZER_NOT_PASS verdict={verdict}", file=sys.stderr)
    print("blocking_reasons=" + ",".join(map(str, blockers)), file=sys.stderr)
    print("pending_pages=" + ",".join(map(str, pending)), file=sys.stderr)
    print("failed_pages=" + ",".join(map(str, failed)), file=sys.stderr)
    sys.exit(4)
print("FORMAL_GOLDEN_FINALIZATION_CONFIRMED")
print(f"book_id={final.get('bookID')}")
print(f"page_count={final.get('pageCount')}")
print(f"reviewer={final.get('reviewer')}")
print(f"reviewed_at={final.get('reviewedAt')}")
PY
  printf '%s\n' "final_assessment=$final"
  exit 0
fi

swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-finalizer \
  --execution-report "$report" \
  --create-template "$template" >/dev/null

python3 - "$template" "$base_index" "$portal" <<'PY'
import json
import sys
from pathlib import Path

template_path, index_path, portal_path = map(Path, sys.argv[1:])
template = json.loads(template_path.read_text(encoding="utf-8"))
base = index_path.read_text(encoding="utf-8")
pages = template.get("pages") or []
assert pages, "review template contains no pages"
assert [p.get("sequence") for p in pages] == list(range(1, len(pages) + 1)), "review template page sequence is invalid"

embedded = json.dumps(template, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
addon = r'''
<style>
#hq-review-toolbar{position:sticky;top:0;z-index:9999;max-width:1500px;margin:0 auto 20px;background:#111;color:#fff;padding:12px 16px;border-radius:10px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;box-shadow:0 4px 20px rgba(0,0,0,.25)}
#hq-review-toolbar input[type=text]{min-width:220px;padding:8px}.hq-review-progress{font-family:ui-monospace,monospace}.hq-export{padding:9px 14px;font-weight:700;cursor:pointer}.hq-decision{margin-top:14px;padding:12px;border:2px solid #777;border-radius:10px;background:#fafafa}.hq-decision.pending{border-color:#b45309}.hq-decision.fail{border-color:#b91c1c;background:#fff1f2}.hq-decision label{display:inline-block;margin-right:14px}.hq-decision select,.hq-decision textarea{margin-left:6px;padding:6px}.hq-decision textarea{width:min(680px,95%);min-height:50px;vertical-align:top}
</style>
<div id="hq-review-toolbar">
  <strong>Formal Golden human review</strong>
  <label>Reviewer <input id="hq-reviewer" type="text" autocomplete="name" placeholder="reviewer name"></label>
  <label><input id="hq-review-complete" type="checkbox"> I reviewed every output page visually and for OCR semantics</label>
  <span class="hq-review-progress" id="hq-review-progress"></span>
  <button class="hq-export" id="hq-export" type="button">Export signed review JSON</button>
</div>
<script>
const HQ_TEMPLATE = __HQ_TEMPLATE__;
(function(){
  const cards=[...document.querySelectorAll('section.page')];
  if(cards.length!==HQ_TEMPLATE.pages.length){throw new Error('review card/template count mismatch');}
  const decisions=new Map();
  function option(value,text){const o=document.createElement('option');o.value=value;o.textContent=text;return o;}
  function selectDecision(kind,sequence){const s=document.createElement('select');s.dataset.kind=kind;s.dataset.sequence=String(sequence);s.append(option('PENDING','PENDING'));s.append(option('PASS','PASS'));s.append(option('FAIL','FAIL'));s.addEventListener('change',update);return s;}
  cards.forEach((card,i)=>{
    const sequence=HQ_TEMPLATE.pages[i].sequence;
    const box=document.createElement('div');box.className='hq-decision pending';box.dataset.sequence=String(sequence);
    const visual=selectDecision('visualCorrection',sequence);const ocr=selectDecision('ocrSemantic',sequence);const notes=document.createElement('textarea');notes.placeholder='Optional notes';notes.addEventListener('input',update);
    const lv=document.createElement('label');lv.textContent='Visual correction ';lv.append(visual);
    const lo=document.createElement('label');lo.textContent='OCR semantic ';lo.append(ocr);
    const ln=document.createElement('label');ln.textContent='Notes ';ln.append(notes);
    box.append(lv,lo,ln);card.append(box);decisions.set(sequence,{box,visual,ocr,notes});
  });
  function update(){
    let done=0,failed=0;
    decisions.forEach(d=>{const pending=d.visual.value==='PENDING'||d.ocr.value==='PENDING';const fail=d.visual.value==='FAIL'||d.ocr.value==='FAIL';d.box.classList.toggle('pending',pending);d.box.classList.toggle('fail',fail);if(!pending)done++;if(fail)failed++;});
    document.getElementById('hq-review-progress').textContent=`${done}/${decisions.size} decided${failed?` · ${failed} failed`:''}`;
  }
  document.getElementById('hq-export').addEventListener('click',()=>{
    const reviewer=document.getElementById('hq-reviewer').value.trim();const complete=document.getElementById('hq-review-complete').checked;
    const pages=[...decisions.entries()].sort((a,b)=>a[0]-b[0]).map(([sequence,d])=>({sequence,visualCorrection:d.visual.value,ocrSemantic:d.ocr.value,notes:d.notes.value.trim()||null}));
    const pending=pages.filter(p=>p.visualCorrection==='PENDING'||p.ocrSemantic==='PENDING');
    if(!reviewer){alert('Reviewer name is required.');return;}if(!complete){alert('Acknowledge that every page was reviewed.');return;}if(pending.length){alert(`Pending review pages: ${pending.map(p=>p.sequence).join(', ')}`);return;}
    const result={...HQ_TEMPLATE,reviewer,reviewedAt:new Date().toISOString(),reviewComplete:true,pages};
    const blob=new Blob([JSON.stringify(result,null,2)+'\n'],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='hq-golden-review-decisions.json';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
  });
  update();
})();
</script>
'''.replace('__HQ_TEMPLATE__', embedded)
if '</body>' not in base.lower():
    raise AssertionError('review bundle index.html has no body terminator')
idx = base.lower().rfind('</body>')
portal = base[:idx] + addon + base[idx:]
portal_path.write_text(portal, encoding='utf-8')
print('GOLDEN_V3_INTERACTIVE_HUMAN_REVIEW_READY')
print(f'page_count={len(pages)}')
PY

printf '%s\n' \
  "review_portal=$portal" \
  "review_template=$template" \
  "next=Open review_portal locally. Inspect every page/reference/OCR pair, choose PASS or FAIL for both dimensions, enter reviewer, acknowledge completion, and export hq-golden-review-decisions.json. Then rerun this same helper with --review-decisions <exported-json>."
