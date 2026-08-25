from pathlib import Path
import sys

index = Path(sys.argv[1])
text = index.read_text(encoding='utf-8')

premium_cta = '<button class="action mock" id="premiumGo"><span class="ico">¥</span><span class="body"><b>プレミアム</b><small>7日無料 · ¥200/月　または　¥800買い切り</small></span><span class="pill">全264問</span></button>'
if 'id="premiumGo"' not in text:
    marker = '<button class="action" id="weakStart">'
    if marker not in text:
        raise SystemExit('premium home insertion marker missing')
    text = text.replace(marker, premium_cta + marker, 1)

if "app.querySelector('#premiumGo').onclick" not in text:
    marker = "app.querySelector('#weakStart').onclick="
    if marker not in text:
        raise SystemExit('premium click insertion marker missing')
    text = text.replace(marker, "app.querySelector('#premiumGo').onclick=()=>{PAYWALL=true;render()};" + marker, 1)

full_old = 'data-full="${r.id}">44問を通しで解く</button>'
full_new = 'data-full="${r.id}">${locked?\'🔒 プレミアム｜\':\'\'}44問を通しで解く</button>'
if full_old in text:
    text = text.replace(full_old, full_new, 1)

state_old = '<em class="state ${s.cls}">${s.text}</em>'
state_new = '<em class="state ${s.cls}">${locked?\'🔒 プレミアム\':s.text}</em>'
if state_old in text:
    text = text.replace(state_old, state_new, 1)

required = [
    'id="premiumGo"',
    '7日無料 · ¥200/月',
    "app.querySelector('#premiumGo').onclick",
    '🔒 プレミアム',
    '全264問',
]
for value in required:
    if value not in text:
        raise SystemExit(f'missing premium visibility marker: {value}')

index.write_text(text, encoding='utf-8')
print('PASS: visible HM1 premium CTA and locked-set labels installed')
