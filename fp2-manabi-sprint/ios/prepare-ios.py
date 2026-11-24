#!/usr/bin/env python3
"""Prepare an offline iOS bundle from the canonical FP2 source; never silently downgrade to sample content."""
from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
web = root / "fp2-manabi-sprint"
dst = web / "ios" / "Web"
source = web / "questions/canonical/approved-questions-20261123.json"
bank_bytes = source.read_bytes()
bank = json.loads(bank_bytes)
questions = bank.get("questions")
if not isinstance(questions, list) or len(questions) != bank.get("content_approved_questions"):
    raise SystemExit("FP2 bank count mismatch")
if not questions or not all(q.get("approved_for_content_bank") is True and
                            q.get("independent_audit_status") == "PASS" for q in questions):
    raise SystemExit("FP2 bank has unapproved content")
if bank.get("publishable_questions", 0) != 0:
    raise SystemExit("Release authorization unexpectedly changed; manually re-audit the bundle")
# Ship only the fixed release selection. Audited reserves stay in GitHub canonical but
# are never copied into the native distributable payload.
selection = json.loads((web / "release/release-selection-300-20261123.json").read_text(encoding="utf-8"))
selected = [q for q in questions if q.get("release_selected") is True]
selected_ids = [q["id"] for q in selected]
scoped_ids = [item for group in selection["domains"] for item in group["selected_ids"]]
if (len(selected) != 298 or len(set(selected_ids)) != 298
        or len(scoped_ids) != 298 or set(selected_ids) != set(scoped_ids)
        or selection["selected_count"] != 298 or selection["reserve_count"] != 12
        or len(questions) != 310):
    raise SystemExit("FP2 native bundle: 310 content PASS, 298 selected, 12 original reserve, 2 legal FAIL quarantine contract violated")
payload = dict(bank)
payload.update({
    "status": "CONTENT_PASS_NATIVE_298_PAYLOAD_NOT_PUBLICATION_APPROVED",
    "content_approved_questions": 298,
    "release_candidate_questions": 298,
    "reserve_content_pass_questions": 0,
    "questions": selected,
})
payload_bytes = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
if dst.exists():
    shutil.rmtree(dst)
dst.mkdir(parents=True)
html = (web / "index.html").read_text(encoding="utf-8")
adapter = (web / "fp2-approved-bank.js").read_text(encoding="utf-8")
if '<script src="fp2-approved-bank.js"></script>' not in html:
    raise SystemExit("Adapter script marker changed")
data = payload_bytes.decode("utf-8").replace("</", "<\\/")
# The same exact canonical data is shipped as JSON and embedded for WKWebView file-origin use.
(dst / "questions/canonical").mkdir(parents=True)
(dst / "questions/canonical/approved-questions-20261123.json").write_bytes(payload_bytes)
shim = """<script type="application/json" id="fp2-offline-bank">""" + data + """</script>
<script>
(function(){
 const originalFetch=window.fetch.bind(window);
 window.fetch=function(input,options){
  const url=typeof input==='string'?input:(input && input.url)||'';
  if(url==='questions/canonical/approved-questions-20261123.json'){
   const data=document.getElementById('fp2-offline-bank').textContent;
   return Promise.resolve(new Response(data,{status:200,headers:{'Content-Type':'application/json'}}));
  }
  return Promise.reject(new Error('Offline FP2 build blocks network fetch: '+url));
 };
})();
</script>
<script>""" + adapter.replace("</script", "<\\/script") + """</script>"""
html = html.replace('<script src="fp2-approved-bank.js"></script>', shim, 1)
if 'id="fp2-offline-bank"' not in html or "FP2ApprovedBank" not in html:
    raise SystemExit("Embedded FP2 bank missing")
(dst / "index.html").write_text(html, encoding="utf-8")
shutil.copy2(web / "manifest.webmanifest", dst / "manifest.webmanifest")
manifest = {
    "app_id": "6797228406", "bundle_id": "com.allsunday1122.fp2manabisprint",
    "version": "1.0.0", "build": "8", "iap_product_ids": [],
    "canonical_path": str(source.relative_to(root)),
    "canonical_sha256": hashlib.sha256(bank_bytes).hexdigest(),
    "content_approved_questions": len(questions),
    "selected_release_questions": len(selected),
    "reserve_content_pass_not_bundled": len(questions) - len(selected),
    "release_payload_sha256": hashlib.sha256(payload_bytes).hexdigest(),
    "publication_release_clear": bank.get("publishable_questions", 0),
    "distribution_approval": "BLOCKED",
}
(dst / "bundle-evidence.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps(manifest, ensure_ascii=False))
