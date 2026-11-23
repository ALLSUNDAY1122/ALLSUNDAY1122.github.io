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
if dst.exists():
    shutil.rmtree(dst)
dst.mkdir(parents=True)
html = (web / "index.html").read_text(encoding="utf-8")
adapter = (web / "fp2-approved-bank.js").read_text(encoding="utf-8")
if '<script src="fp2-approved-bank.js"></script>' not in html:
    raise SystemExit("Adapter script marker changed")
data = json.dumps(bank, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
# The same exact canonical data is shipped as JSON and embedded for WKWebView file-origin use.
(dst / "questions/canonical").mkdir(parents=True)
(dst / "questions/canonical/approved-questions-20261123.json").write_bytes(bank_bytes)
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
manifest = {
    "app_id": "6797228406", "bundle_id": "com.allsunday1122.fp2manabisprint",
    "version": "1.0.0", "build": "1", "iap_product_ids": [],
    "canonical_path": str(source.relative_to(root)),
    "canonical_sha256": hashlib.sha256(bank_bytes).hexdigest(),
    "content_approved_questions": len(questions),
    "publication_release_clear": bank.get("publishable_questions", 0),
    "distribution_approval": "BLOCKED",
}
(dst / "bundle-evidence.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps(manifest, ensure_ascii=False))
