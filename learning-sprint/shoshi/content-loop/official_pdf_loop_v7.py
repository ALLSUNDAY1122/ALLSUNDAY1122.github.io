#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys

import official_pdf_loop_v6 as v6


def repair_consumed_range_start(q: dict) -> list[dict]:
    pre = (q.get('section_preamble') or '').strip()
    if not pre:
        return []
    qn = int(q.get('source_question_no') or 0)
    repairs = []

    # The base PDF splitter consumed the first '第N問' when it appeared in a
    # section instruction such as '第4問から第23問まで'. Restore that exact
    # current question number before the remaining 'から第M問'.
    pattern = re.compile(r'((?:また|なお)[、,]\s*)\n?\s*から\s*第\s*(\d+)\s*問')
    def repl(m: re.Match) -> str:
        repairs.append({'id': q['id'], 'from': m.group(0), 'to_start': f'{m.group(1)}第{qn}問から第{m.group(2)}問'})
        return f'{m.group(1)}第 {qn} 問から第 {m.group(2)} 問'
    pre = pattern.sub(repl, pre)

    start_pattern = re.compile(r'^\s*から\s*第\s*(\d+)\s*問')
    m = start_pattern.search(pre)
    if m:
        repairs.append({'id': q['id'], 'from': m.group(0), 'to_start': f'第{qn}問から第{m.group(1)}問'})
        pre = start_pattern.sub(f'第 {qn} 問から第 {m.group(1)} 問', pre, count=1)

    q['section_preamble'] = pre
    return repairs


def main() -> int:
    rc = v6.main()
    report = json.loads(v6.v5.v4.v3.REPORT.read_text(encoding='utf-8'))
    questions = json.loads(v6.v5.v4.v3.QUESTIONS.read_text(encoding='utf-8'))

    repairs = []
    malformed = []
    for q in questions:
        repairs.extend(repair_consumed_range_start(q))
        pre = (q.get('section_preamble') or '').strip()
        if re.search(r'(?:^|\n)\s*から\s*第\s*\d+\s*問', pre):
            malformed.append(q['id'])
        if re.search(r'(?:また|なお)[、,]\s*\n?\s*から\s*第', pre):
            malformed.append(q['id'])

    errors = [e for e in report.get('errors', []) if not e.startswith('malformed section range')]
    if malformed:
        errors.append(f'malformed section range remains: {len(set(malformed))}')

    report['cycle'] = 13
    report['consumed_range_start_audit'] = {
        'repairs': repairs,
        'remaining_malformed_ids': sorted(set(malformed)),
    }
    report['errors'] = errors
    report['status'] = 'PASS' if rc == 0 and not errors else 'FAIL'

    v6.v5.v4.v3.QUESTIONS.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding='utf-8')
    audit = json.loads(v6.v5.v4.v3.CONFIG.read_text(encoding='utf-8'))
    by_id = {q['id']: q for q in questions}
    for aq in audit.get('questions', []):
        src = by_id.get(aq.get('id'))
        if not src:
            continue
        aq['question'] = src['question']
        if src.get('section_preamble'):
            aq['section_preamble'] = src['section_preamble']
        else:
            aq.pop('section_preamble', None)
    v6.v5.v4.v3.CONFIG.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding='utf-8')
    v6.v5.v4.v3.REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

    print(json.dumps({
        'cycle': 13,
        'status': report['status'],
        'range_start_repairs': len(repairs),
        'remaining_malformed': len(set(malformed)),
    }, ensure_ascii=False))
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
