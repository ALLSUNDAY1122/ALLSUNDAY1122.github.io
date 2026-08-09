#!/usr/bin/env python3
import json
from pathlib import Path

p = Path(__file__).with_name('r8-source-audit.json')
d = json.loads(p.read_text(encoding='utf-8'))
errors = []
expected = {"企業法":20,"管理会計論":18,"監査論":20,"財務会計論":35}
for r in d['rounds']:
    actual = {k:v['questions'] for k,v in r['subjects'].items()}
    if actual != expected:
        errors.append(f"{r['round']}: 科目別問題数不一致 {actual}")
    if sum(actual.values()) != 93:
        errors.append(f"{r['round']}: 合計問題数不一致")
    if sum(v['points'] for v in r['subjects'].values()) != 500:
        errors.append(f"{r['round']}: 満点不一致")
    if sum(v['minutes'] for v in r['subjects'].values()) != 325:
        errors.append(f"{r['round']}: 試験時間不一致")
    if not r.get('answer_key'):
        errors.append(f"{r['round']}: 正解表URL欠損")
    for subject, meta in r['subjects'].items():
        if not meta.get('source_pdf'):
            errors.append(f"{r['round']}/{subject}: PDF URL欠損")
if sum(r['question_total'] for r in d['rounds']) != 186:
    errors.append('公式2回分の総問題数が186ではない')
if errors:
    print('FAIL')
    for e in errors:
        print('-', e)
    raise SystemExit(1)
print('PASS: R8第I・II回の公式ソース構造 93問×2=186問、500点×2、325分×2、科目構成・ソースURLを確認')
