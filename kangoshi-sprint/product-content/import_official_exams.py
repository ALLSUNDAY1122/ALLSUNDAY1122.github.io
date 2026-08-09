#!/usr/bin/env python3
import json, re, subprocess, sys, tempfile, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCES = json.loads((ROOT / 'official-sources.json').read_text(encoding='utf-8'))
OUT = ROOT / 'raw'
OUT.mkdir(exist_ok=True)

PAGE_CODE = re.compile(r'^\s*[A-Z0-9-]+(?:前|後)[A-Z0-9-]*-?\d*\s*$')
Q_LINE = re.compile(r'^\s*(\d{1,3})\s+(.+?)\s*$')
OPT_LINE = re.compile(r'^\s*([1-5])\s*[．.]\s*(.*)$')


def fetch_pdf(url: str, path: Path):
    req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=60) as r, path.open('wb') as f:
        f.write(r.read())


def pdftotext(pdf: Path) -> str:
    txt = pdf.with_suffix('.txt')
    subprocess.run(['pdftotext', '-layout', '-enc', 'UTF-8', str(pdf), str(txt)], check=True)
    return txt.read_text(encoding='utf-8', errors='replace')


def clean_line(line: str) -> str:
    line = line.replace('\u3000', ' ').replace('\ufeff', '')
    return re.sub(r'\s+', ' ', line).strip()


def find_question_starts(lines):
    starts = {}
    expected = 1
    for i, raw in enumerate(lines):
        line = clean_line(raw)
        m = Q_LINE.match(line)
        if not m:
            continue
        n = int(m.group(1))
        if n == expected and n <= 120:
            # Exclude instruction-list numbering such as "1 試験問題の数は...".
            tail = m.group(2)
            if expected == 1 and ('試験問題の数' in tail or '解答方法' in tail):
                continue
            starts[n] = i
            expected += 1
            if expected == 121:
                break
    if len(starts) != 120:
        missing = [n for n in range(1,121) if n not in starts]
        raise RuntimeError(f'question split failed: got {len(starts)}, missing={missing[:15]}')
    return starts


def parse_question_block(block, n):
    cleaned = []
    for raw in block:
        line = clean_line(raw)
        if not line or PAGE_CODE.match(line):
            continue
        if re.match(r'^\d+\s+[A-Z0-9-]+(?:前|後)', line):
            continue
        cleaned.append(line)
    if not cleaned:
        return {'stem':'', 'choices':[]}
    # Remove leading question number from first line.
    cleaned[0] = re.sub(r'^\s*'+str(n)+r'\s+', '', cleaned[0], count=1)
    stem_parts, choices, current = [], [], None
    for line in cleaned:
        m = OPT_LINE.match(line)
        if m:
            if current is not None:
                choices.append(current.strip())
            current = m.group(2).strip()
        elif current is None:
            stem_parts.append(line)
        else:
            current += ' ' + line
    if current is not None:
        choices.append(current.strip())
    stem = ' '.join(stem_parts).strip()
    # Remove common printer/page debris.
    stem = re.sub(r'\s+[A-Z]{2,}-\d{2}[^ ]*$', '', stem).strip()
    return {'stem': stem, 'choices': choices}


def split_questions(text: str):
    lines = text.splitlines()
    starts = find_question_starts(lines)
    out = {}
    for n in range(1,121):
        s = starts[n]
        e = starts[n+1] if n < 120 else len(lines)
        out[n] = parse_question_block(lines[s:e], n)
    return out


def parse_answers(text: str, prefix_morning: str, prefix_afternoon: str):
    compact = text.replace('\u3000',' ')
    answers = {'AM':{}, 'PM':{}}
    # Match all cells such as A001 2 / B031 1 / AM1 3 / PM80 2.
    prefixes = [(prefix_morning,'AM'), (prefix_afternoon,'PM')]
    for prefix, session in prefixes:
        pattern = re.compile(r'(?<![A-Z])'+re.escape(prefix)+r'\s*0*(\d{1,3})\s+([0-9]{1,5})(?!\d)')
        for m in pattern.finditer(compact):
            n = int(m.group(1))
            if 1 <= n <= 120:
                answers[session][n] = m.group(2)
    for session in ('AM','PM'):
        if len(answers[session]) != 120:
            missing=[n for n in range(1,121) if n not in answers[session]]
            raise RuntimeError(f'answer parse failed {session}: {len(answers[session])}, missing={missing[:20]}')
    return answers


def answer_value(token: str, stem: str):
    if '2つ選べ' in stem or '二つ選べ' in stem:
        return [int(c)-1 for c in token]
    if '解答：' in stem or '解答:' in stem:
        return int(token)
    if len(token) == 1:
        return int(token)-1
    # Some table cells concatenate two correct choice numbers.
    if all(c in '12345' for c in token):
        return [int(c)-1 for c in token]
    return token


def category(n: int):
    if n <= 25: return '必修'
    if n <= 90: return '一般'
    return '状況設定'


def build_set(src, am_q, pm_q, answers):
    items=[]
    for session, qmap, pdf_url in [('AM',am_q,src['morningPdf']),('PM',pm_q,src['afternoonPdf'])]:
        for n in range(1,121):
            q=qmap[n]
            token=answers[session][n]
            stem=q['stem']
            choices=q['choices']
            ans=answer_value(token,stem)
            requires_media=(len(choices)<4 or '図を示す' in stem or '写真を示す' in stem or '別冊' in stem)
            answer_type='multiChoice' if isinstance(ans,list) else ('numeric' if isinstance(ans,int) and not choices else 'singleChoice')
            item={
                'id':f"K{src['exam']}-{session}{n:03d}",
                'sourceExam':src['exam'],
                'session':session,
                'questionNo':n,
                'category':category(n),
                'majorSubject':None,
                'subject':None,
                'answerType':answer_type,
                'question':stem,
                'choices':choices,
                'answer':ans,
                'point':None,
                'detail':None,
                'requiresMedia':requires_media,
                'mediaAuditStatus':'pending' if requires_media else 'not_required',
                'rightsStatus':'mhlw-pdl1.0-text; media-pending' if requires_media else 'mhlw-pdl1.0-text',
                'reviewStatus':'official_import_pending_explanation_and_classification',
                'sourceRefs':[src['landingUrl'],pdf_url,src['answerPdf']],
                'sourceAttribution':f"出典：厚生労働省『第{src['exam']}回看護師国家試験』を学習用データとして加工",
                'sourceAnswerToken':token
            }
            items.append(item)
    return items


def main():
    selected = set(sys.argv[1:]) if len(sys.argv)>1 else {s['id'] for s in SOURCES['sets']}
    summary=[]
    for src in SOURCES['sets']:
        if src['id'] not in selected:
            continue
        with tempfile.TemporaryDirectory() as td:
            td=Path(td)
            files={}
            for key,url in [('am',src['morningPdf']),('pm',src['afternoonPdf']),('ans',src['answerPdf'])]:
                p=td/f'{key}.pdf'; fetch_pdf(url,p); files[key]=pdftotext(p)
            am=split_questions(files['am']); pm=split_questions(files['pm'])
            ans=parse_answers(files['ans'],src['answerPrefixMorning'],src['answerPrefixAfternoon'])
            items=build_set(src,am,pm,ans)
            out={
                'schemaVersion':1,
                'setId':src['id'],
                'sourceExam':src['exam'],
                'questionCount':len(items),
                'releaseStatus':'raw_import_only',
                'note':'公式本文・正答の機械取込。解説、11科目分類、図版権利監査、専門監査が完了するまで本番解放禁止。',
                'questions':items
            }
            (OUT/f"{src['id']}-raw.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
            summary.append({'set':src['id'],'exam':src['exam'],'count':len(items),'mediaPending':sum(1 for x in items if x['requiresMedia'])})
    (OUT/'import-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':
    main()
