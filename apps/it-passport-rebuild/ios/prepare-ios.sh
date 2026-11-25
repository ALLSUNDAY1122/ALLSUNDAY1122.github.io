#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
import hashlib, json, pathlib, os
source = pathlib.Path('../questions/official-verbatim.json')
generated = pathlib.Path('../generated/questions.json')
out = pathlib.Path('Resources/official-500.json')
def require(ok, message):
    if not ok:
        raise SystemExit(message)
raw = source.read_bytes()
data = json.loads(generated.read_bytes())
require(data.get('schema_version') == 1, 'Unsupported schema')
require(data.get('source') == 'questions/official-verbatim.json', 'Wrong source')
require(data.get('source_sha256') == hashlib.sha256(raw).hexdigest(), 'Generated data stale: regenerate from official bank first')
qs = data['questions']
expected = {f'itp-{y}-q{n:03d}' for y in range(2022, 2027) for n in range(1, 101)}
require(len(qs) == 500 and {q['id'] for q in qs} == expected, 'Expected 500 unique IDs')
for q in qs:
    require(q['id'] == f"itp-{q['year']}-q{q['question_number']:03d}", 'ID mismatch')
    require(isinstance(q['question'], str) and bool(q['question'].strip()), 'Empty question')
    require(len(q['choices']) == 4 and all(isinstance(c, str) and c.strip() for c in q['choices']), 'Invalid choices')
    require(type(q['correct_index']) is int and 0 <= q['correct_index'] < 4, 'Invalid answer')
    require(q['correct_label'] == 'アイウエ'[q['correct_index']], 'Answer label mismatch')
    require(bool(q['source_label']) and bool(q['source_url']), 'Missing attribution')
    require(all(type(q[k]) is bool for k in ('modified', 'representation_changed', 'publishable', 'release_eligible')), 'Invalid flags')
out.parent.mkdir(parents=True, exist_ok=True)
tmp = out.with_suffix('.tmp')
tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
require(json.loads(tmp.read_text(encoding='utf-8')) == data, 'Readback mismatch')
os.replace(tmp, out)
print('PASS: 500 unique questions, five years, source hash and readback verified')
PY
