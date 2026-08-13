#!/usr/bin/env python3
"""未知形式（holdout）コーパスを生成する。

PoCのfixtureとは別の生成規則（レイアウト原型×語彙プール×金額生成の組み合わせ）で、
30形式を作る。うち20形式を評価用、10形式を最終確認用として最後まで触らずに残す。

出力: Fixtures/holdout/<id>.{pdf,png,jpg} と <id>.truth.json、manifest.json

使い方: python3 tools/generate_holdout.py
"""

import json
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from holdout_templates import (  # noqa: E402
    ATTENDANCE, COMPANIES, DEDUCT_TOTAL, GROSS_TOTAL, NET,
    build_rows, make_amounts, money,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Fixtures", "holdout")
JP_FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
PAGE_W, PAGE_H = 595.0, 842.0

LAYOUTS = [
    "vertical_single",   # 縦1列、区分見出しあり
    "two_column",        # 左=支給 / 右=控除
    "attendance_block",  # 勤怠ブロック（日数・時間）つき
    "column_header",     # 横並び列ヘッダ、金額はラベルの下
    "monospace_plain",   # 罫線なし等幅
    "no_totals",         # 合計行が無い
    "multipage",         # 2ページ（支給／控除）
]
MEDIA = ["text_pdf", "screenshot", "photo", "image_pdf"]


class Draw:
    """描画コマンドの収集（PDF・画像の両レンダラで共有）。"""

    def __init__(self):
        self.items = []   # (page, text, x, y, size, align, bold)
        self.lines = []   # (page, x0, y0, x1, y1)
        self.pages = 1

    def text(self, text, x, y, size=9.5, align="l", bold=False, page=1):
        self.items.append((page, text, x, y, size, align, bold))
        self.pages = max(self.pages, page)

    def hline(self, x0, x1, y, page=1):
        self.lines.append((page, x0, y, x1, y))

    def box(self, x0, y0, x1, y1, page=1):
        self.lines.extend([
            (page, x0, y0, x1, y0), (page, x0, y1, x1, y1),
            (page, x0, y0, x0, y1), (page, x1, y0, x1, y1),
        ])


# ---------------------------------------------------------------------------
# レイアウト原型
# ---------------------------------------------------------------------------

def layout_vertical_single(d, spec, rnd, style, company, rows):
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text(company, 55, 55, 11, bold=True)
    d.text(f"2026年{rnd.randint(1, 12)}月分 給与明細", 55, 76, 12, bold=True)
    d.hline(50, 545, 88)
    y = 115
    d.text("＜支給＞", 55, y, 10, bold=True)
    y += 20
    for _, label, value in pay_rows:
        d.text(label, 65, y, 10)
        d.text(money(value, pay_style), 535, y, 10, align="r")
        y += 22
    d.text(rnd.choice(GROSS_TOTAL), 65, y, 10, bold=True)
    d.text(money(spec["gross"], pay_style), 535, y, 10, align="r", bold=True)
    y += 34
    d.text("＜控除＞", 55, y, 10, bold=True)
    y += 20
    for _, label, value in ded_rows:
        d.text(label, 65, y, 10)
        d.text(money(value, ded_style), 535, y, 10, align="r")
        y += 22
    d.text(rnd.choice(DEDUCT_TOTAL), 65, y, 10, bold=True)
    d.text(money(spec["deduct_total"], ded_style), 535, y, 10, align="r", bold=True)
    y += 32
    d.hline(50, 545, y - 14)
    d.text(rnd.choice(NET), 65, y, 11, bold=True)
    d.text(money(spec["truth"]["net_pay"], pay_style), 535, y, 12, align="r", bold=True)
    return dict(width=600, height=y + 40)


def layout_two_column(d, spec, rnd, style, company, rows):
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text("給与支給明細書", 210, 50, 14, bold=True)
    d.text(company, 55, 76, 9)
    d.text(f"支給日 2026-{rnd.randint(1, 12):02d}-25", 420, 76, 9)
    d.hline(50, 545, 92)
    d.text("支給", 60, 110, 10, bold=True)
    d.text("控除", 320, 110, 10, bold=True)
    y = 132
    n = max(len(pay_rows), len(ded_rows))
    for i in range(n):
        if i < len(pay_rows):
            d.text(pay_rows[i][1], 60, y, 9.5)
            d.text(money(pay_rows[i][2], pay_style), 290, y, 9.5, align="r")
        if i < len(ded_rows):
            d.text(ded_rows[i][1], 320, y, 9.5)
            d.text(money(ded_rows[i][2], ded_style), 540, y, 9.5, align="r")
        y += 21
    d.text(rnd.choice(GROSS_TOTAL), 60, y, 9.5, bold=True)
    d.text(money(spec["gross"], pay_style), 290, y, 9.5, align="r", bold=True)
    d.text(rnd.choice(DEDUCT_TOTAL), 320, y, 9.5, bold=True)
    d.text(money(spec["deduct_total"], ded_style), 540, y, 9.5, align="r", bold=True)
    y += 34
    d.hline(50, 545, y - 16)
    d.text(rnd.choice(NET), 320, y, 11, bold=True)
    d.text(money(spec["truth"]["net_pay"], pay_style), 540, y, 12, align="r", bold=True)
    return dict(width=600, height=y + 40)


def layout_attendance_block(d, spec, rnd, style, company, rows):
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text(company, 55, 50, 10)
    d.text("給 与 明 細 票", 230, 52, 13, bold=True)
    d.text("【勤怠】", 55, 90, 10, bold=True)
    x = 60
    for label, fmt in ATTENDANCE:
        value = fmt.format(d=rnd.randint(18, 22), p=rnd.randint(0, 3), h=rnd.randint(5, 40),
                           n=rnd.randint(0, 12), t=rnd.randint(4, 9))
        d.text(label, x, 110, 8.5)
        d.text(value, x, 128, 8.5)
        x += 82
    d.hline(50, 545, 140)
    d.text("【支給】", 55, 165, 10, bold=True)
    y = 185
    for _, label, value in pay_rows:
        d.text(label, 65, y, 9.5)
        d.text(money(value, pay_style), 300, y, 9.5, align="r")
        y += 20
    d.text(rnd.choice(GROSS_TOTAL), 65, y, 9.5, bold=True)
    d.text(money(spec["gross"], pay_style), 300, y, 9.5, align="r", bold=True)
    d.text("【控除】", 330, 165, 10, bold=True)
    y2 = 185
    for _, label, value in ded_rows:
        d.text(label, 340, y2, 9.5)
        d.text(money(value, ded_style), 545, y2, 9.5, align="r")
        y2 += 20
    d.text(rnd.choice(DEDUCT_TOTAL), 340, y2, 9.5, bold=True)
    d.text(money(spec["deduct_total"], ded_style), 545, y2, 9.5, align="r", bold=True)
    bottom = max(y, y2) + 34
    d.hline(50, 555, bottom - 16)
    d.text(rnd.choice(NET), 65, bottom, 11, bold=True)
    d.text(money(spec["truth"]["net_pay"], pay_style), 545, bottom, 12, align="r", bold=True)
    return dict(width=610, height=bottom + 40)


def layout_column_header(d, spec, rnd, style, company, rows):
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text(company, 50, 50, 10)
    d.text(f"2026/{rnd.randint(1, 12):02d} 給与明細", 400, 50, 10)
    y = 90
    for title, group, total_label, total_value, group_style in (
        ("支給", pay_rows, rnd.choice(GROSS_TOTAL), spec["gross"], pay_style),
        ("控除", ded_rows, rnd.choice(DEDUCT_TOTAL), spec["deduct_total"], ded_style),
    ):
        d.text(f"■{title}", 50, y, 10, bold=True)
        y += 18
        per_row = 4
        for start in range(0, len(group), per_row):
            chunk = group[start:start + per_row]
            x = 60
            d.box(50, y - 2, 50 + 125 * len(chunk), y + 42)
            for _, label, value in chunk:
                d.text(label, x, y + 12, 9)
                d.text(money(value, group_style), x + 100, y + 34, 9, align="r")
                x += 125
            y += 52
        d.text(total_label, 60, y + 8, 9.5, bold=True)
        d.text(money(total_value, group_style), 250, y + 8, 9.5, align="r", bold=True)
        y += 40
    d.hline(45, 560, y - 8)
    d.text(rnd.choice(NET), 60, y + 16, 11, bold=True)
    d.text(money(spec["truth"]["net_pay"], pay_style), 545, y + 16, 12, align="r", bold=True)
    return dict(width=610, height=y + 56)


def layout_monospace_plain(d, spec, rnd, style, company, rows):
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text(f"{company}  給与支払明細  2026-{rnd.randint(1, 12):02d}", 40, 45, 10)
    y = 80
    for _, label, value in pay_rows:
        d.text(f"{label:<10}{value:>10,}".replace(",", ""), 45, y, 10)
        y += 24
    d.text(f"{rnd.choice(GROSS_TOTAL):<10}{spec['gross']:>10}", 45, y, 10)
    y += 32
    for _, label, value in ded_rows:
        d.text(f"{label:<10}{value:>10}", 45, y, 10)
        y += 24
    d.text(f"{rnd.choice(DEDUCT_TOTAL):<10}{spec['deduct_total']:>10}", 45, y, 10)
    y += 32
    d.text(f"{rnd.choice(NET):<10}{spec['truth']['net_pay']:>10}", 45, y, 10)
    return dict(width=430, height=y + 40)


def layout_no_totals(d, spec, rnd, style, company, rows):
    """合計行が無い明細（検算の裏付けが取れない条件）。"""
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text(company, 50, 50, 10, bold=True)
    d.text("給与明細（明細のみ・合計欄なし）", 50, 72, 10)
    y = 105
    for group, label, value in pay_rows + ded_rows:
        d.text(label, 60, y, 10)
        d.text(money(value, pay_style if group == "pay" else ded_style), 420, y, 10, align="r")
        d.hline(50, 430, y + 8)
        y += 26
    d.text(rnd.choice(NET), 60, y + 12, 11, bold=True)
    d.text(money(spec["truth"]["net_pay"], pay_style), 420, y + 12, 11, align="r", bold=True)
    return dict(width=480, height=y + 50)


def layout_multipage(d, spec, rnd, style, company, rows):
    pay_style, ded_style = style
    pay_rows, ded_rows = rows
    d.text(company, 55, 55, 11, bold=True)
    d.text("給与明細（1/2 支給）", 55, 78, 12, bold=True)
    y = 115
    for _, label, value in pay_rows:
        d.text(label, 65, y, 10)
        d.text(money(value, pay_style), 520, y, 10, align="r")
        y += 24
    d.text(rnd.choice(GROSS_TOTAL), 65, y, 10, bold=True)
    d.text(money(spec["gross"], pay_style), 520, y, 10, align="r", bold=True)

    d.text(company, 55, 55, 11, bold=True, page=2)
    d.text("給与明細（2/2 控除・支給額）", 55, 78, 12, bold=True, page=2)
    y = 115
    for _, label, value in ded_rows:
        d.text(label, 65, y, 10, page=2)
        d.text(money(value, ded_style), 520, y, 10, align="r", page=2)
        y += 24
    d.text(rnd.choice(DEDUCT_TOTAL), 65, y, 10, bold=True, page=2)
    d.text(money(spec["deduct_total"], ded_style), 520, y, 10, align="r", bold=True, page=2)
    y += 40
    d.hline(50, 530, y - 18, page=2)
    d.text(rnd.choice(NET), 65, y, 11, bold=True, page=2)
    d.text(money(spec["truth"]["net_pay"], pay_style), 520, y, 12, align="r", bold=True, page=2)
    return dict(width=595, height=842)


LAYOUT_FUNCS = {
    "vertical_single": layout_vertical_single,
    "two_column": layout_two_column,
    "attendance_block": layout_attendance_block,
    "column_header": layout_column_header,
    "monospace_plain": layout_monospace_plain,
    "no_totals": layout_no_totals,
    "multipage": layout_multipage,
}


# ---------------------------------------------------------------------------
# レンダラ
# ---------------------------------------------------------------------------

def render_pdf(d, path, size):
    pdfmetrics.registerFont(TTFont("IPAGothic", JP_FONT))
    c = canvas.Canvas(path, pagesize=(PAGE_W, PAGE_H))
    for page in range(1, d.pages + 1):
        for p, x0, y0, x1, y1 in d.lines:
            if p != page:
                continue
            c.setLineWidth(0.6)
            c.line(x0, PAGE_H - y0, x1, PAGE_H - y1)
        for p, text, x, y, fsize, align, bold in d.items:
            if p != page:
                continue
            c.setFont("IPAGothic", fsize)
            if bold:
                t = c.beginText()
                t.setTextRenderMode(2)
                t.setFont("IPAGothic", fsize)
                width = c.stringWidth(text, "IPAGothic", fsize)
                t.setTextOrigin(x - width if align == "r" else x, PAGE_H - y)
                t.textOut(text)
                c.drawText(t)
            elif align == "r":
                c.drawRightString(x, PAGE_H - y, text)
            else:
                c.drawString(x, PAGE_H - y, text)
        c.showPage()
    c.save()


def render_page_image(d, size, scale, page=1, bg=(255, 255, 255), fg=(20, 20, 24)):
    w = int(size["width"] * scale)
    h = int(size["height"] * scale)
    img = Image.new("RGB", (w, h), bg)
    draw = ImageDraw.Draw(img)
    for p, x0, y0, x1, y1 in d.lines:
        if p != page:
            continue
        draw.line((x0 * scale, y0 * scale, x1 * scale, y1 * scale),
                  fill=(150, 150, 158), width=max(1, int(scale * 0.45)))
    for p, text, x, y, fsize, align, bold in d.items:
        if p != page:
            continue
        font = ImageFont.truetype(JP_FONT, max(8, int(fsize * scale)))
        draw.text((x * scale, y * scale), text, font=font, fill=fg,
                  anchor="rs" if align == "r" else "ls",
                  stroke_width=1 if bold else 0, stroke_fill=fg)
    return img


def perspective(img, strength, rnd):
    """撮影時のあおりを再現する透視変換。"""
    w, h = img.size
    dx = w * strength
    dy = h * strength * 0.5
    src = [(0, 0), (w, 0), (w, h), (0, h)]
    dst = [
        (rnd.uniform(0, dx), rnd.uniform(0, dy)),
        (w - rnd.uniform(0, dx), rnd.uniform(0, dy)),
        (w - rnd.uniform(0, dx * 0.4), h - rnd.uniform(0, dy * 0.4)),
        (rnd.uniform(0, dx * 0.4), h - rnd.uniform(0, dy * 0.4)),
    ]
    # 透視変換係数を最小二乗で解く（numpy無し）
    matrix = []
    for (sx, sy), (dx_, dy_) in zip(dst, src):
        matrix.append([sx, sy, 1, 0, 0, 0, -dx_ * sx, -dx_ * sy])
        matrix.append([0, 0, 0, sx, sy, 1, -dy_ * sx, -dy_ * sy])
    b = []
    for (_, _), (dx_, dy_) in zip(dst, src):
        b.extend([dx_, dy_])
    coeffs = solve(matrix, b)
    return img.transform((w, h), Image.PERSPECTIVE, coeffs, Image.BICUBIC, fillcolor=(255, 255, 255))


def solve(a, b):
    """8x8 のガウス消去（透視変換係数用）。"""
    n = len(a)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        m[col], m[pivot] = m[pivot], m[col]
        if abs(m[col][col]) < 1e-12:
            continue
        for r in range(n):
            if r == col:
                continue
            factor = m[r][col] / m[col][col]
            for c in range(col, n + 1):
                m[r][c] -= factor * m[col][c]
    return [m[i][n] / m[i][i] if abs(m[i][i]) > 1e-12 else 0.0 for i in range(n)]


def motion_blur(img, radius, angle):
    size = radius * 2 + 1
    kernel = [0.0] * (size * size)
    for i in range(size):
        x = int(round((i - radius) * math.cos(math.radians(angle)))) + radius
        y = int(round((i - radius) * math.sin(math.radians(angle)))) + radius
        if 0 <= x < size and 0 <= y < size:
            kernel[y * size + x] = 1.0
    total = sum(kernel) or 1.0
    return img.filter(ImageFilter.Kernel((size, size), [k / total for k in kernel], scale=1.0))


def vignette(img, strength):
    w, h = img.size
    mask = Image.new("L", (w, h), 255)
    draw = ImageDraw.Draw(mask)
    steps = 24
    for i in range(steps):
        f = i / steps
        value = int(255 - 255 * strength * f * f)
        inset_x = int(w * 0.5 * f)
        inset_y = int(h * 0.5 * f)
        draw.rectangle([inset_x, inset_y, w - inset_x, h - inset_y], outline=None, fill=None)
        draw.rectangle([w - inset_x - 1, 0, w, h], fill=value)
        draw.rectangle([0, 0, inset_x, h], fill=value)
        draw.rectangle([0, h - inset_y - 1, w, h], fill=value)
        draw.rectangle([0, 0, w, inset_y], fill=value)
    mask = mask.filter(ImageFilter.GaussianBlur(w * 0.03))
    return ImageChops.multiply(img, Image.merge("RGB", (mask, mask, mask)))


def degrade_photo(img, rnd, level):
    """写真らしい劣化: 透視 → 明るさ → ブレ → ノイズ → ビネット。"""
    img = perspective(img, 0.012 + 0.02 * level, rnd)
    if level > 0.3:
        img = img.point(lambda v: int(v * (1 - 0.18 * level)))
    if rnd.random() < 0.6:
        img = motion_blur(img, 1 if level < 0.6 else 2, rnd.choice([0, 15, 90, 160]))
    else:
        img = img.filter(ImageFilter.GaussianBlur(0.3 + 0.5 * level))
    sigma = int(3 + 6 * level)
    noise = Image.effect_noise(img.size, sigma).convert("L")
    img = ImageChops.add(img, Image.merge("RGB", (noise, noise, noise)), scale=1.0, offset=-128)
    img = vignette(img, 0.15 + 0.25 * level)
    return img


def save_jpeg(img, path, quality):
    img.save(path, format="JPEG", quality=quality)


def render_image_pdf(jpeg_paths, path):
    """JPEGファイルのまま埋め込む（再圧縮せず、PDFサイズも小さくなる）。"""
    c = canvas.Canvas(path, pagesize=(PAGE_W, PAGE_H))
    for jpeg_path in jpeg_paths:
        with Image.open(jpeg_path) as img:
            iw, ih = img.size
        ratio = min((PAGE_W - 30) / iw, (PAGE_H - 30) / ih)
        w, h = iw * ratio, ih * ratio
        c.drawImage(jpeg_path, 15, PAGE_H - 15 - h, width=w, height=h)
        c.showPage()
    c.save()


# ---------------------------------------------------------------------------

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rnd = random.Random(20260813)
    cases = []
    combos = []
    for i in range(30):
        layout = LAYOUTS[i % len(LAYOUTS)]
        media = MEDIA[(i // 2) % len(MEDIA)] if layout != "multipage" else ("text_pdf" if i % 2 == 0 else "image_pdf")
        combos.append((layout, media))
    rnd.shuffle(combos)

    for index, (layout, media) in enumerate(combos, start=1):
        cid = f"hold{index:02d}"
        spec = make_amounts(rnd)
        # 支給側にマイナス表記は使わない（実際の明細に無いため）
        pay_style = rnd.choice(["plain", "plain", "yen", "suffix", "comma_none"])
        ded_style = rnd.choice(["plain", "plain", "yen", "suffix", "comma_none", "paren_minus", "triangle"])
        style = (pay_style, ded_style)
        company = COMPANIES[(index - 1) % len(COMPANIES)]
        rows = build_rows(spec, rnd, style)
        d = Draw()
        size = LAYOUT_FUNCS[layout](d, spec, rnd, style, company, rows)

        entry = {
            "id": cid,
            "layout": layout,
            "media": media,
            "money_style": {"pay": pay_style, "deduction": ded_style},
            "company": company,
            "pages": d.pages,
            "split": "eval" if index <= 20 else "final",
        }

        if media == "text_pdf":
            path = os.path.join(OUT_DIR, f"{cid}.pdf")
            render_pdf(d, path, size)
            entry["file"] = f"{cid}.pdf"
            entry["scale"] = 1.0
        elif media == "screenshot":
            scale = rnd.choice([2.0, 2.4, 3.0])
            img = render_page_image(d, size, scale)
            if rnd.random() < 0.35:  # ダーク系配色のスクショ
                img = ImageChops.invert(img).point(lambda v: min(255, int(v * 0.9)))
            path = os.path.join(OUT_DIR, f"{cid}.png")
            img.save(path)
            entry["file"] = f"{cid}.png"
            entry["scale"] = scale
        elif media == "photo":
            scale = rnd.choice([2.2, 2.6, 3.0])
            level = rnd.uniform(0.2, 1.0)
            img = degrade_photo(render_page_image(d, size, scale), rnd, level)
            path = os.path.join(OUT_DIR, f"{cid}.jpg")
            save_jpeg(img, path, rnd.choice([55, 65, 75, 85]))
            entry["file"] = f"{cid}.jpg"
            entry["scale"] = scale
            entry["degrade_level"] = round(level, 2)
        else:  # image_pdf（スキャン）
            scale = 2.4
            jpeg_paths = []
            for page in range(1, d.pages + 1):
                img = render_page_image(d, size, scale, page=page)
                img = degrade_photo(img, rnd, rnd.uniform(0.1, 0.4))
                suffix = "" if page == 1 else f"_p{page}"
                jpeg_path = os.path.join(OUT_DIR, f"{cid}{suffix}.jpg")
                save_jpeg(img, jpeg_path, 80)
                jpeg_paths.append(jpeg_path)
            path = os.path.join(OUT_DIR, f"{cid}.pdf")
            render_image_pdf(jpeg_paths, path)
            entry["file"] = f"{cid}.pdf"
            entry["ocr_source"] = f"{cid}.jpg"
            entry["ocr_pages"] = [f"{cid}.jpg" if p == 1 else f"{cid}_p{p}.jpg" for p in range(1, d.pages + 1)]
            entry["scale"] = scale

        with open(os.path.join(OUT_DIR, f"{cid}.truth.json"), "w", encoding="utf-8") as f:
            json.dump({"id": cid, "layout": layout, "media": media, "truth": spec["truth"],
                       "gross_total": spec["gross"], "deduction_total": spec["deduct_total"]},
                      f, ensure_ascii=False, indent=2)
        cases.append(entry)
        print(f"{cid} {layout:16s} {media:12s} {pay_style}/{ded_style} p{d.pages} -> {entry['file']}")

    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({
            "generated_by": "tools/generate_holdout.py",
            "note": "全て合成データ。実在の給与明細・個人情報は含まない。PoC fixtureとは別の生成規則。",
            "split_policy": "eval=調整に使う20形式 / final=最後の1回だけ使う10形式",
            "cases": cases,
        }, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
