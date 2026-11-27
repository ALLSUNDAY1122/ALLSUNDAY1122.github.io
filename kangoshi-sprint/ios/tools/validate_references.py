#!/usr/bin/env python3
"""Static gate for Guideline 1.4.1 source metadata (no network).

- Every URL in Sources/References.swift must appear in references-verified-20261128.json
  (URLs opened and checked by hand before use; no guessed URLs).
- Every exam in the generated question bundle must map to an official MHLW exam source.
- The Settings screen and the explanation screen must expose the references.
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
swift = (root / 'Sources' / 'References.swift').read_text(encoding='utf-8')
verified = json.loads((root / 'references-verified-20261128.json').read_text(encoding='utf-8'))
ok_urls = {row['url'] for row in verified['urls'] if row['status'] == 200}
urls = set(re.findall(r'"(https?://[^"]+)"', swift))
missing = sorted(urls - ok_urls)
if missing:
    sys.exit(f'unverified URLs in References.swift: {missing}')
if not urls:
    sys.exit('no URLs found')

exams = {int(m) for m in re.findall(r'ExamSource\(exam: (\d+),', swift)}
bundle = root / 'GeneratedResources' / 'questions.generated.json'
if bundle.exists():
    data = json.loads(bundle.read_text(encoding='utf-8'))
    need = {q['sourceExam'] for q in data['questions']}
    if not need <= exams:
        sys.exit(f'exam without official source: {sorted(need - exams)}')
    print(f"questions with exam source: {len(data['questions'])}/{data['totalQuestions']}")

main = (root / 'Sources' / 'MainViews.swift').read_text(encoding='utf-8')
quiz = (root / 'Sources' / 'QuizViews.swift').read_text(encoding='utf-8')
for needle, text, where in [
    ('ReferencesView()', main, 'Settings → ReferencesView'),
    ('DisclaimerView()', main, 'Settings → DisclaimerView'),
    ('QuestionSourceBadge(question: question)', quiz, 'question screen source badge'),
    ('ExplanationReferencesSection(question: question)', quiz, 'explanation references'),
    ('ReferencesSheet()', quiz, 'explanation → references sheet'),
]:
    if needle not in text:
        sys.exit(f'missing: {where}')
print(f'PASS: {len(urls)} verified URLs, exams {sorted(exams)}')
