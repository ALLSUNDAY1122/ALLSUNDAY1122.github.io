#!/usr/bin/env bash
# 固定コーパスを再生成する（合成データのみ）。
#   1. 合成明細のPDF/PNGを生成
#   2. PDFはまず pdf.js でテキスト抽出を試す
#   3. テキストが取れない画像PDF・画像はローカルOCR(Tesseract日本語)でトークン化
# 生成物: fixtures/cases/*.tokens.json （評価ハーネスはこれを読む）
set -euo pipefail
cd "$(dirname "$0")/.."

python3 tools/generate_fixtures.py

python3 - <<'PY'
import json, os, subprocess, sys
sys.path.insert(0, "tools")
from ocr_tokens import ocr_token_variants

manifest = json.load(open("fixtures/manifest.json", encoding="utf-8"))
MIN_PDF_TOKENS = 8  # これ未満なら「テキストを持たないPDF」と判定しOCRへフォールバック

for case in manifest["cases"]:
    cid = case["id"]
    out = f"fixtures/cases/{cid}.tokens.json"
    src = "fixtures/" + case["file"]
    payload = None
    probe = None

    if src.endswith(".pdf"):
        tmp = f"/tmp/{cid}.pdf.json"
        subprocess.run(["node", "tools/extract_pdf_tokens.mjs", src, tmp],
                       check=True, capture_output=True)
        probe = json.load(open(tmp, encoding="utf-8"))
        if len(probe["tokens"]) >= MIN_PDF_TOKENS:
            payload = {"source": "pdf_text", "route": "pdf_text",
                       "variants": [{"name": "pdf", "tokens": probe["tokens"]}],
                       "pageCount": probe["pageCount"]}
        os.remove(tmp)

    if payload is None:
        img = "fixtures/" + case.get("ocr_source", case["file"])
        variants = ocr_token_variants(img, case.get("scale", 1.0), psm=case.get("psm", 4))
        payload = {"source": "ocr", "engine": "tesseract-jpn(local)", "route": "ocr",
                   "variants": variants, "pageCount": 1}
        if probe is not None:
            payload["pdf_text_probe_tokens"] = len(probe["tokens"])

    payload["case"] = cid
    payload["kind"] = case["kind"]
    with open(out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    counts = "/".join(f"{v['name']}:{len(v['tokens'])}" for v in payload["variants"])
    extra = "" if probe is None or payload["route"] == "pdf_text" else \
        f"  (pdf text probe: {len(probe['tokens'])} tokens -> OCRへフォールバック)"
    print(f"{cid:8s} {payload['route']:9s} {counts:20s}{extra}")
PY
