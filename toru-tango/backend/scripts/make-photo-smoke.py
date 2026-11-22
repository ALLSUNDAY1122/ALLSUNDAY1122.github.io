#!/usr/bin/env python3
"""Produce a realistic-resolution JPEG and a bounded, resized JPEG for live OCR smoke."""
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
from pathlib import Path
import base64
import json

out = Path('photo-smoke')
out.mkdir(exist_ok=True)
original = Image.effect_noise((4032, 3024), 35).convert('RGB')
draw = ImageDraw.Draw(original)
draw.rectangle((130, 210, 2900, 930), fill='#ffffff')
font_file = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
font = ImageFont.truetype(font_file, 225) if Path(font_file).exists() else ImageFont.load_default()
draw.text((220, 390), 'AI 2026', font=font, fill='#101010')
original.save(out / 'original-4032x3024.jpg', 'JPEG', quality=95)
resized = original.copy()
resized.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
buf = BytesIO()
resized.save(buf, format='JPEG', quality=70)
compressed = buf.getvalue()
encoded = base64.b64encode(compressed).decode('ascii')
payload = {'images': [{'data': encoded, 'mimeType': 'image/jpeg'}]}
request = json.dumps(payload, separators=(',', ':')).encode('utf-8')
assert original.size == (4032,3024)
assert max(resized.size) == 1600
assert len(encoded) <= 1_500_000, len(encoded)
assert len(request) <= 9_000_000, len(request)
(out / 'request.json').write_bytes(request)
print(json.dumps({'originalPixels': list(original.size),
                  'originalJpegBytes': (out / 'original-4032x3024.jpg').stat().st_size,
                  'compressedPixels': list(resized.size),
                  'compressedJpegBytes': len(compressed),
                  'base64Chars': len(encoded),
                  'requestBytes': len(request)}))
