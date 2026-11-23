#!/usr/bin/env python3
"""Structural release gate for the original FP2 bank; not a semantic/legal audit."""
import argparse
from collections import Counter
from datetime import date
from difflib import SequenceMatcher
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


def audit(path: Path) -> dict:
    contract = json.loads((ROOT / 'content-expansion-contract.json').read_text(encoding='utf-8'))
    target = contract['product_target_questions']
    errors = []
    if not path.is_file():
        return {'status': 'FAIL', 'release_ready': False, 'approved_questions': 0,
                'target_questions': target, 'errors': ['PRODUCT_BANK_MISSING']}
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
        qs = data['questions']
        if not isinstance(qs, list) or not all(isinstance(q, dict) for q in qs):
            raise ValueError('questions must be an array of objects')
    except (ValueError, KeyError, TypeError) as exc:
        return {'status': 'FAIL', 'release_ready': False, 'approved_questions': 0,
                'target_questions': target, 'errors': ['INVALID_BANK_SCHEMA: ' + str(exc)]}
    approved = [q for q in qs if q.get('auditStatus') == 'approved']
    if len(qs) != target or len(approved) != target:
        errors.append(f'REQUIRED_APPROVED_COUNT: {len(approved)}/{target}; total={len(qs)}')
    ids = [q.get('id') for q in qs]
    if any(not isinstance(x, str) or not x.strip() for x in ids) or len(set(map(str, ids))) != len(ids):
        errors.append('INVALID_OR_DUPLICATE_IDS')
    domains = Counter(q.get('domain') for q in approved)
    if dict(domains) != contract['product_bank']['target_domain_counts']:
        errors.append('DOMAIN_COUNTS_MUST_BE_100_EACH')
    exam_types = Counter(q.get('examType') for q in approved)
    if dict(exam_types) != {'gakka': 480, 'jitsugi': 120}:
        errors.append('EXAM_TYPE_COUNTS_MUST_BE_GAKKA_480_JITSUGI_120')
    normalized = []
    for i, q in enumerate(qs):
        label = q.get('id') or f'row-{i + 1}'
        for field in ('question', 'topic', 'point', 'detail', 'contentVersion'):
            if not isinstance(q.get(field), str) or not q[field].strip():
                errors.append(f'{label}: MISSING_{field}')
        if q.get('originType') != 'original' or q.get('rightsBasis') != 'original_question_based_on_primary_public_source':
            errors.append(f'{label}: ORIGINAL_RIGHTS_BASIS_REQUIRED')
        refs = q.get('sourceRefs')
        if not isinstance(refs, list) or not refs or any(
            not isinstance(ref, str) or urlsplit(ref).scheme != 'https' or not urlsplit(ref).hostname for ref in (refs or [])
        ):
            errors.append(f'{label}: PRIMARY_SOURCE_URL_REQUIRED')
        try:
            baseline = date.fromisoformat(q['lawBaselineDate'])
            if baseline > date.today():
                raise ValueError('future baseline')
        except (ValueError, KeyError, TypeError):
            errors.append(f'{label}: INVALID_LEGAL_BASELINE')
        if q.get('answerType') == 'singleChoice':
            choices = q.get('choices')
            answer = q.get('answerIndex')
            if (not isinstance(choices, list) or len(choices) < 2
                    or any(not isinstance(c, str) or not c.strip() for c in choices)
                    or type(answer) is not int or not 0 <= answer < len(choices)):
                errors.append(f'{label}: INVALID_SINGLE_CHOICE')
        elif q.get('answerType') == 'numeric':
            if (type(q.get('numericAnswer')) not in (int, float)
                    or type(q.get('tolerance')) not in (int, float) or q['tolerance'] < 0
                    or not isinstance(q.get('unit'), str) or not q['unit'].strip()):
                errors.append(f'{label}: INVALID_NUMERIC_ANSWER')
        else:
            errors.append(f'{label}: INVALID_ANSWER_TYPE')
        normalized.append(re.sub(r'\s+', '', str(q.get('question', ''))))
    duplicates = []
    for i, text in enumerate(normalized):
        if not text:
            continue
        for j in range(i):
            other = normalized[j]
            if text == other or (min(len(text), len(other)) >= 20
                                and SequenceMatcher(None, text, other, autojunk=False).ratio() >= .9):
                duplicates.append([ids[j], ids[i]])
    if duplicates:
        errors.append('DUPLICATE_OR_NEAR_DUPLICATE_REVIEW_REQUIRED')
    return {'status': 'FAIL' if errors else 'PASS', 'release_ready': not errors,
            'approved_questions': len(approved), 'target_questions': target,
            'domain_counts': dict(domains), 'exam_type_counts': dict(exam_types),
            'duplicate_candidates': duplicates, 'errors': errors,
            'scope': 'Structure only; primary-source, answer, legal-date and originality review still required.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bank', type=Path, default=ROOT / 'question_bank.json')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = audit(args.bank)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0 if result['release_ready'] else 1)


if __name__ == '__main__':
    main()
