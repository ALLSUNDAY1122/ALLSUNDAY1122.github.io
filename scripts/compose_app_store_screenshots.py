#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys

root = Path(sys.argv[1])
out = Path(sys.argv[2])
icon_path = Path(sys.argv[3])
custom_font_path = Path(sys.argv[4]) if len(sys.argv) > 4 else None
out.mkdir(parents=True, exist_ok=True)

W, H = 1290, 2796
HEADERS = [
    ('01_overview_raw.png', '長期作業の現在地を、ひと目で', '目的・進捗・次のアクションを一画面に'),
    ('02_ai_risk_raw.png', 'AIごとの役割とリスクを整理', '担当・制約・成果物をまとめて管理'),
    ('03_tasks_raw.png', 'タスクの担当と優先度を明確に', '未着手・進行中・完了を迷わず確認'),
    ('04_logs_raw.png', '指示の版と実行ログを蓄積', '決定事項と成果を次のセッションへ残す'),
    ('05_handoff_raw.png', '次のAIへ渡す文章を自動生成', 'コピーして、そのまま作業を再開'),
]

font_candidates = ([str(custom_font_path)] if custom_font_path and custom_font_path.exists() else []) + [
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc',
]
regular_candidates = ([str(custom_font_path)] if custom_font_path and custom_font_path.exists() else []) + [
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc',
]

def pick(candidates):
    for p in candidates:
        if Path(p).exists():
            return p
    raise SystemExit('Japanese font not found')

bold_path = pick(font_candidates)
regular_path = pick(regular_candidates)
font_title = ImageFont.truetype(bold_path, 70)
font_sub = ImageFont.truetype(regular_path, 33)
font_badge = ImageFont.truetype(bold_path, 28)

icon = Image.open(icon_path).convert('RGB').resize((88, 88), Image.Resampling.LANCZOS)
mask_icon = Image.new('L', icon.size, 0)
ImageDraw.Draw(mask_icon).rounded_rectangle((0, 0, 87, 87), radius=22, fill=255)

for index, (filename, title, subtitle) in enumerate(HEADERS, 1):
    raw = Image.open(root / filename).convert('RGB')
    if raw.size not in {(430, 932), (1290, 2796)}:
        raise SystemExit(f'raw screenshot size mismatch: {filename} {raw.size}')

    canvas = Image.new('RGB', (W, H), '#EEF3FF')
    px = canvas.load()
    top = (17, 43, 70)
    bottom = (49, 87, 213)
    for y in range(H):
        t = min(1.0, y / 720.0)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        if y > 720:
            fade = min(1.0, (y - 720) / 480.0)
            r = int(r * (1 - fade) + 238 * fade)
            g = int(g * (1 - fade) + 243 * fade)
            b = int(b * (1 - fade) + 255 * fade)
        for x in range(W):
            px[x, y] = (r, g, b)

    draw = ImageDraw.Draw(canvas)
    canvas.paste(icon, (70, 64), mask_icon)
    badge_box = (180, 78, 414, 138)
    draw.rounded_rectangle(badge_box, radius=30, fill=(255, 255, 255))
    draw.text((207, 87), 'AI引継ぎ帳', font=font_badge, fill=(17, 43, 70))

    draw.text((70, 178), title, font=font_title, fill='white')
    draw.text((73, 278), subtitle, font=font_sub, fill=(221, 232, 255))

    shot_w = 1090
    shot_h = round(H * shot_w / W)
    shot = raw.resize((shot_w, shot_h), Image.Resampling.LANCZOS)
    shot = shot.filter(ImageFilter.UnsharpMask(radius=1.0, percent=115, threshold=2))
    radius = 46
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot_w - 1, shot_h - 1), radius=radius, fill=255)

    shadow = Image.new('RGBA', (shot_w + 80, shot_h + 80), (0, 0, 0, 0))
    shadow_mask = Image.new('L', shadow.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle((40, 24, shot_w + 39, shot_h + 23), radius=radius, fill=150)
    shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(28)))
    x = (W - shot_w) // 2
    y = 385
    canvas.paste(shadow, (x - 40, y - 24), shadow)
    canvas.paste(shot, (x, y), mask)
    draw.rounded_rectangle((x, y, x + shot_w - 1, y + shot_h - 1), radius=radius, outline=(255, 255, 255), width=5)

    output = out / f'{index:02d}_AI引継ぎ帳_AppStore_1290x2796.png'
    canvas.save(output, format='PNG', optimize=True)
    check = Image.open(output)
    if check.size != (W, H) or check.mode != 'RGB':
        raise SystemExit(f'final image validation failed: {output} {check.size} {check.mode}')
    print(output)
