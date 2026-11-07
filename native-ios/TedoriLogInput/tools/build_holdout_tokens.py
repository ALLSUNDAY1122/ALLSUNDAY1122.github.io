#!/usr/bin/env python3
"""holdoutコーパスを位置つきトークンへ変換する。

- PDF: pdf.js でテキスト抽出。取れなければ画像OCRへフォールバック
- 画像: ローカルOCR（Tesseract日本語。実機のApple Visionの代替）
- 複数ページ: ページを縦に連結（y座標にページ高さを足す）

出力: Fixtures/holdout/<id>.tokens.json
実機Vision版の評価はSwift側テスト（Tests/TedoriLogVisionTests）で別途行う。
"""

import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(ROOT))
HOLDOUT = os.path.join(ROOT, "Fixtures", "holdout")
POC_TOOLS = os.path.join(REPO, "tedorilog-poc", "tools")
sys.path.insert(0, POC_TOOLS)
from ocr_tokens import ocr_token_variants  # noqa: E402

PAGE_HEIGHT = 842.0
MIN_PDF_TOKENS = 8


def offset_pages(tokens, page_height=PAGE_HEIGHT):
    """複数ページを縦に積む（ページ間で行がぶつからないようにする）。"""
    out = []
    for token in tokens:
        page = token.get("page", 1)
        shifted = dict(token)
        shifted["y"] = token["y"] + (page - 1) * page_height
        out.append(shifted)
    return out


def pdf_tokens(pdf_path):
    tmp = "/tmp/holdout_pdf.json"
    subprocess.run(
        ["node", os.path.join(REPO, "tedorilog-poc", "tools", "extract_pdf_tokens.mjs"), pdf_path, tmp],
        check=True, capture_output=True,
    )
    with open(tmp, encoding="utf-8") as f:
        payload = json.load(f)
    os.unlink(tmp)
    return payload


def main():
    manifest = json.load(open(os.path.join(HOLDOUT, "manifest.json"), encoding="utf-8"))
    for case in manifest["cases"]:
        cid = case["id"]
        path = os.path.join(HOLDOUT, case["file"])
        payload = None
        probe_count = None

        if path.endswith(".pdf"):
            probe = pdf_tokens(path)
            probe_count = len(probe["tokens"])
            if probe_count >= MIN_PDF_TOKENS:
                payload = {"source": "pdf_text", "route": "pdf_text",
                           "variants": [{"name": "pdf", "tokens": offset_pages(probe["tokens"])}]}

        if payload is None:
            pages = case.get("ocr_pages") or [case.get("ocr_source", case["file"])]
            merged = {}
            for index, page_file in enumerate(pages):
                variants = ocr_token_variants(os.path.join(HOLDOUT, page_file), case.get("scale", 1.0))
                for variant in variants:
                    tokens = [dict(t, page=index + 1) for t in variant["tokens"]]
                    merged.setdefault(variant["name"], []).extend(offset_pages(tokens))
            payload = {"source": "ocr", "engine": "tesseract-jpn(local)", "route": "ocr",
                       "variants": [{"name": name, "tokens": tokens} for name, tokens in merged.items()]}
            if probe_count is not None:
                payload["pdf_text_probe_tokens"] = probe_count

        payload.update(case=cid, media=case["media"], layout=case["layout"], split=case["split"])
        with open(os.path.join(HOLDOUT, f"{cid}.tokens.json"), "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=1)
        counts = "/".join(f"{v['name']}:{len(v['tokens'])}" for v in payload["variants"])
        print(f"{cid} {case['layout']:16s} {payload['route']:9s} {counts}")


if __name__ == "__main__":
    main()
