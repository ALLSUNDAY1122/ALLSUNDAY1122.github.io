#!/usr/bin/env python3
"""合成給与明細ファイル（PDF / PNG）を生成する。

実データは扱わない。slip_templates.py の定義から
  - text_pdf   : テキスト埋込PDF（reportlab）
  - screenshot : PNG（Pillow）
  - photo      : PNG＋傾き/ノイズ/影/ぼかし（Pillow）
  - image_pdf  : PNG を1ページPDFへ貼り付けたスキャン相当PDF
を出力する。

使い方: python3 tools/generate_fixtures.py
出力先: fixtures/rendered/<case_id>.<ext>, fixtures/cases/<case_id>.truth.json
"""

import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slip_templates import build_all  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER_DIR = os.path.join(ROOT, "fixtures", "rendered")
CASE_DIR = os.path.join(ROOT, "fixtures", "cases")

JP_FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
PAGE_W, PAGE_H = 595.0, 842.0


# ---------------------------------------------------------------------------
# PDF（テキスト埋込）
# ---------------------------------------------------------------------------

def render_text_pdf(case, path):
    pdfmetrics.registerFont(TTFont("IPAGothic", JP_FONT))
    c = canvas.Canvas(path, pagesize=(PAGE_W, PAGE_H))
    c.setTitle(case.title)
    for x0, y0, x1, y1 in case.lines:
        c.setLineWidth(0.6)
        c.line(x0, PAGE_H - y0, x1, PAGE_H - y1)
    for it in case.items:
        c.setFont("IPAGothic", it.size)
        y = PAGE_H - it.y
        if it.bold:
            c.setLineWidth(0.25)
            t = c.beginText()
            t.setTextRenderMode(2)  # fill + stroke = 疑似ボールド
            t.setFont("IPAGothic", it.size)
            if it.align == "r":
                t.setTextOrigin(it.x - c.stringWidth(it.text, "IPAGothic", it.size), y)
            else:
                t.setTextOrigin(it.x, y)
            t.textOut(it.text)
            c.drawText(t)
        elif it.align == "r":
            c.drawRightString(it.x, y, it.text)
        else:
            c.drawString(it.x, y, it.text)
    c.showPage()
    c.save()


# ---------------------------------------------------------------------------
# 画像（スクリーンショット / 写真）
# ---------------------------------------------------------------------------

def render_image(case):
    r = case.render
    scale = r.get("scale", 2.4)
    w = int(r.get("width", 595) * scale)
    h = int(r.get("height", 842) * scale)
    bg = r.get("bg", (255, 255, 255))
    fg = r.get("fg", (24, 24, 28))
    line_color = r.get("line_color", (160, 160, 168))

    img = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(img)
    for x0, y0, x1, y1 in case.lines:
        d.line((x0 * scale, y0 * scale, x1 * scale, y1 * scale), fill=line_color, width=max(1, int(scale * 0.5)))
    for it in case.items:
        size = max(8, int(it.size * scale))
        font = ImageFont.truetype(JP_FONT, size)
        x, y = it.x * scale, it.y * scale
        # PDF側 drawString と同じくベースライン基準で配置する
        anchor = "rs" if it.align == "r" else "ls"
        d.text((x, y), it.text, font=font, fill=fg, anchor=anchor,
               stroke_width=1 if it.bold else 0, stroke_fill=fg)

    if r.get("shadow"):
        strength = r["shadow"] if isinstance(r["shadow"], float) else 0.12
        grad = Image.linear_gradient("L").resize((w, h))
        grad = grad.point(lambda v: 255 - int(v * strength))
        img = ImageChops.multiply(img, Image.merge("RGB", (grad, grad, grad)))
    if r.get("rotate"):
        img = img.rotate(r["rotate"], resample=Image.BICUBIC, expand=False, fillcolor=bg)
    if r.get("blur"):
        img = img.filter(ImageFilter.GaussianBlur(r["blur"] * scale / 2.4))
    if r.get("noise"):
        # effect_noise は平均128のガウシアンノイズ。offset=-128 で明るさを保ったまま重畳する
        noise = Image.effect_noise((w, h), r["noise"]).convert("L")
        img = ImageChops.add(img, Image.merge("RGB", (noise, noise, noise)), scale=1.0, offset=-128)
    return img, scale


def apply_jpeg(img, quality=88):
    """写真・スキャンはJPEGで保存されるのが実態。圧縮ノイズも含めて再現する。"""
    import io
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=quality)
    buf.seek(0)
    return Image.open(buf).convert("RGB"), buf


def render_image_pdf(img, path):
    c = canvas.Canvas(path, pagesize=(PAGE_W, PAGE_H))
    ratio = min((PAGE_W - 40) / img.width, (PAGE_H - 40) / img.height)
    w, h = img.width * ratio, img.height * ratio
    c.drawImage(ImageReader(img), 20, PAGE_H - 20 - h, width=w, height=h)
    c.showPage()
    c.save()


# ---------------------------------------------------------------------------

def main():
    os.makedirs(RENDER_DIR, exist_ok=True)
    os.makedirs(CASE_DIR, exist_ok=True)
    manifest = []
    for case in build_all():
        entry = {
            "id": case.id,
            "title": case.title,
            "kind": case.kind,
            "note": case.note,
        }
        if case.kind == "text_pdf":
            path = os.path.join(RENDER_DIR, case.id + ".pdf")
            render_text_pdf(case, path)
            entry["file"] = "rendered/" + case.id + ".pdf"
            entry["scale"] = 1.0
        elif case.kind == "image_pdf":
            img, scale = render_image(case)
            img, _ = apply_jpeg(img)  # スキャンPDFの中身はJPEGであることが多い
            path = os.path.join(RENDER_DIR, case.id + ".pdf")
            render_image_pdf(img, path)
            side = os.path.join(RENDER_DIR, case.id + ".jpg")
            img.save(side, quality=88)
            entry["file"] = "rendered/" + case.id + ".pdf"
            entry["ocr_source"] = "rendered/" + case.id + ".jpg"
            entry["scale"] = scale
        else:
            img, scale = render_image(case)
            # 写真はJPEG（撮影実態に合わせる）、スクリーンショットはPNG
            ext = ".jpg" if case.kind == "photo" else ".png"
            path = os.path.join(RENDER_DIR, case.id + ext)
            if ext == ".jpg":
                img, _ = apply_jpeg(img)
                img.save(path, quality=88)
            else:
                img.save(path)
            entry["file"] = "rendered/" + case.id + ext
            entry["ocr_source"] = "rendered/" + case.id + ext
            entry["scale"] = scale
        with open(os.path.join(CASE_DIR, case.id + ".truth.json"), "w", encoding="utf-8") as f:
            json.dump({"id": case.id, "title": case.title, "kind": case.kind,
                       "truth": case.truth}, f, ensure_ascii=False, indent=2)
        manifest.append(entry)
        print(f"generated {case.id:8s} {case.kind:12s} -> {entry['file']}")

    with open(os.path.join(ROOT, "fixtures", "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"generated_by": "tools/generate_fixtures.py",
                   "note": "全て合成データ。実在の給与明細・個人情報は含まない。",
                   "cases": manifest}, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
