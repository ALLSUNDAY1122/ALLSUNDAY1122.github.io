#!/usr/bin/env python3
"""画像をローカルOCRにかけ、位置付きトークンJSONを出力する。

本番iOSでは Apple Vision (VNRecognizeTextRequest, 端末内処理) を使う前提。
本PoCの検証環境ではmacOSが無いため、同じ「端末内OCR」の代替として
ローカル実行のTesseract(日本語)を使用する。いずれも外部APIへは送信しない。

使い方: python3 tools/ocr_tokens.py <image> <out.json> [--scale 2.4] [--psm 4]
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageFilter, ImageOps

# 端末内OCRの前処理。影・低コントラストで文字が潰れるのを防ぐ。
# Apple Vision は内部で同等の正規化を行うため、Tesseractを代替に使う本PoCでは明示的に実施する。
UPSCALE_TARGET_WIDTH = 1600


def _upscaled_original(image_path):
    img = Image.open(image_path).convert("L")
    if img.width < UPSCALE_TARGET_WIDTH:
        ratio = UPSCALE_TARGET_WIDTH / img.width
        img = img.resize((int(img.width * ratio), int(img.height * ratio)), Image.LANCZOS)
    else:
        ratio = 1.0
    return img, ratio


def preprocess(image_path):
    img, ratio = _upscaled_original(image_path)
    # フラットフィールド補正: 大きくぼかした背景を引いて照明ムラ・影を除去する
    background = img.filter(ImageFilter.BoxBlur(max(8, img.width // 25)))
    flat = ImageChops.subtract(img, background, scale=1, offset=200)
    flat = ImageOps.autocontrast(flat, cutoff=1)
    return flat, ratio


def _run_tesseract(image_path, psm, lang, extra=None):
    cmd = [
        "tesseract", image_path, "stdout",
        "-l", lang, "--psm", str(psm),
        "-c", "preserve_interword_spaces=1",
    ]
    if extra:
        cmd.extend(extra)
    cmd.append("tsv")
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout


def _ocr_image(image, scale, psm, lang):
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        image.save(tmp.name)
        path = tmp.name
    try:
        return _parse_tsv(_run_tesseract(path, psm, lang), scale)
    finally:
        os.unlink(path)


def ocr_token_variants(image_path, scale=1.0, psm=4, lang="jpn", refine_digits=True):
    """2通りの読み取り結果を返す。

    raw  … 拡大のみ（日本語の項目名に強い）
    flat … 影・低コントラストを平坦化（数字と暗い写真に強い）

    どちらが良いかは明細ごとに変わるため、選択は解析エンジン側の自己評価（検算が通るか）
    に任せる。実機では Vision を2条件で走らせることに相当する。
    """
    processed, flat_ratio = preprocess(image_path)
    original, raw_ratio = _upscaled_original(image_path)

    variants = []
    for name, image, ratio in (("raw", original, raw_ratio), ("flat", processed, flat_ratio)):
        tokens = _ocr_image(image, scale * ratio, psm, lang)
        if refine_digits:
            # 数字の再認識は常に平坦化画像で行う（影に強いため）
            tokens = refine_digit_tokens(processed, tokens, scale * flat_ratio)
        variants.append({"name": name, "tokens": tokens})
    return variants


def ocr_tokens(image_path, scale=1.0, psm=4, lang="jpn", refine_digits=True):
    """単一の読み取り結果（平坦化画像ベース）。"""
    variants = ocr_token_variants(image_path, scale, psm, lang, refine_digits)
    return variants[1]["tokens"]


def _parse_tsv(out, scale):
    tokens = []
    lines = out.splitlines()
    header = lines[0].split("\t")
    idx = {name: i for i, name in enumerate(header)}
    for row in lines[1:]:
        cols = row.split("\t")
        if len(cols) < len(header):
            continue
        if cols[idx["level"]] != "5":  # word level
            continue
        text = cols[idx["text"]].strip()
        if not text:
            continue
        conf = float(cols[idx["conf"]])
        if conf < 0:
            continue
        tokens.append({
            "text": text,
            "x": round(int(cols[idx["left"]]) / scale, 2),
            "y": round(int(cols[idx["top"]]) / scale, 2),
            "w": round(int(cols[idx["width"]]) / scale, 2),
            "h": round(int(cols[idx["height"]]) / scale, 2),
            "conf": conf / 100.0,
            "page": 1,
        })
    return tokens


DIGITISH = re.compile(r"^[\d,.\s¥￥()（）△▲Aa-]+$")


def refine_digit_tokens(processed, tokens, scale):
    """数字らしいトークンだけ、数字ホワイトリストで再認識して精度を上げる。

    本番では Vision の関心領域（ROI）再認識に相当する。切り出しは端末内で完結する。
    """
    refined = []
    for token in tokens:
        text = token["text"]
        if not DIGITISH.match(text) or not any(ch.isdigit() for ch in text):
            refined.append(token)
            continue
        pad = 4
        left = int(token["x"] * scale) - pad
        top = int(token["y"] * scale) - pad
        right = int((token["x"] + token["w"]) * scale) + pad
        bottom = int((token["y"] + token["h"]) * scale) + pad
        crop = processed.crop((max(0, left), max(0, top),
                               min(processed.width, right), min(processed.height, bottom)))
        if crop.width < 8 or crop.height < 8:
            refined.append(token)
            continue
        crop = crop.resize((crop.width * 3, crop.height * 3), Image.LANCZOS)
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            crop.save(tmp.name)
            crop_path = tmp.name
        try:
            out = _run_tesseract(
                crop_path, 7, "eng",
                extra=["-c", "tessedit_char_whitelist=0123456789,.-"],
            )
            parts = _parse_tsv(out, 1.0)
        finally:
            os.unlink(crop_path)
        if not parts:
            refined.append(token)
            continue
        merged_text = "".join(p["text"] for p in parts)
        conf = min(p["conf"] for p in parts)
        if not any(ch.isdigit() for ch in merged_text):
            refined.append(token)
            continue
        # 元の読みより自信がある場合だけ差し替える
        if conf > token["conf"]:
            token = {**token, "text": merged_text, "conf": conf, "refined": True}
        refined.append(token)
    return refined


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--psm", type=int, default=4)
    args = ap.parse_args()

    if not os.path.exists(args.image):
        print(f"not found: {args.image}", file=sys.stderr)
        return 1
    tokens = ocr_tokens(args.image, args.scale, args.psm)
    payload = {"source": "ocr", "engine": "tesseract-jpn(local)", "tokens": tokens, "pageCount": 1}
    text = json.dumps(payload, ensure_ascii=False, indent=1)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{args.image} -> {args.out} ({len(tokens)} tokens)")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
