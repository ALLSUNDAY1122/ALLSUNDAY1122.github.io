"""Shared helper: apply verified official-PDF glyph repairs to a question dict whose
text still carries the broken PDF text layer (e.g. raw imports). Only exact `before` matches change."""
import copy, json
from pathlib import Path

REPAIRS = Path(__file__).resolve().parent / 'official-pdf-text-repairs-20261125.json'
_EDITS = {e['id']: e['edits'] for e in json.loads(REPAIRS.read_text(encoding='utf-8'))['questions']}

def apply_repairs(q):
    edits = _EDITS.get(q.get('id'))
    if not edits:
        return q
    q = copy.deepcopy(q)
    for ed in edits:
        f = ed['field']
        if f.startswith('choices['):
            i = int(f[8:-1]); ch = q.get('choices') or []
            if i < len(ch) and ch[i] == ed['before']:
                ch[i] = ed['after']
        elif q.get(f) == ed['before']:
            q[f] = ed['after']
    return q
