#!/usr/bin/env python3
import json, re, subprocess, sys, tempfile, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCES = json.loads((ROOT / 'official-sources.json').read_text(encoding='utf-8'))
OUT = ROOT / 'raw'
OUT.mkdir(exist_ok=True)

PAGE_CODE = re.compile(r'^\s*[A-Z0-9-]+(?:前|後)[A-Z0-9-]*-?\d*\s*$')
Q_LINE = re.compile(r'^\s*(\d{1,3})\s+(.+?)\s*$')
Q_BARE = re.compile(r'^\s*(\d{1,3})\s*$')
OPT_LINE = re.compile(r'^\s*([1-5])\s*[．.]\s*(.*)$')
NUMERIC_PROMPT = re.compile(r'解答\s*[：:]')
JAPANESE = re.compile(r'[ぁ-んァ-ン一-龥]')
MEDIA_WORDS = ('図を示す', '図に示す', '写真を示す', '別冊', '画像を示す', 'グラフを示す', '表を示す')
SCENARIO_STARTS = tuple(range(91, 121, 3))
SCENARIO_MARKER = re.compile(r'次の文を読み\s*(\d{2,3})\s*[～〜－—―\-]\s*(\d{2,3})\s*の問いに答えよ')


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


def skip_print_line(line: str) -> bool:
    if not line or PAGE_CODE.match(line):
        return True
    if re.match(r'^\d+\s+[A-Z0-9-]+(?:前|後)', line):
        return True
    if ('.indd' in line or '.smd' in line) and re.search(r'\d{2,4}/\d{1,2}/\d{1,2}', line):
        return True
    if re.match(r'^Page\s+\d+', line, re.I):
        return True
    return False


def plausible_first_question(tail: str) -> bool:
    if len(tail) < 6:
        return False
    if not JAPANESE.search(tail):
        return False
    banned = ('試験問題の数', '解答方法', '答案用紙', '正解は', '注意事項')
    return not any(x in tail for x in banned)


def question_number(line: str):
    m = Q_LINE.match(line)
    if m:
        return int(m.group(1)), m.group(2)
    m = Q_BARE.match(line)
    if m:
        return int(m.group(1)), ''
    return None, None


def find_question_starts(lines):
    first = None
    for i, raw in enumerate(lines):
        line = clean_line(raw)
        n, tail = question_number(line)
        if n == 1 and tail and plausible_first_question(tail):
            first = i
            break
    if first is None:
        raise RuntimeError('question split failed: real question 1 not found')

    starts = {1:first}
    expected = 2
    for i in range(first + 1, len(lines)):
        line = clean_line(lines[i])
        n, _ = question_number(line)
        if n == expected:
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
        if skip_print_line(line):
            continue
        cleaned.append(line)
    if not cleaned:
        return {'stem':'', 'choices':[], 'numericPrompt':False}

    cleaned[0] = re.sub(r'^\s*'+str(n)+r'(?:\s+|$)', '', cleaned[0], count=1).strip()
    if cleaned and not cleaned[0]:
        cleaned = cleaned[1:]
    if not cleaned:
        return {'stem':'', 'choices':[], 'numericPrompt':False}

    numeric_prompt = any(NUMERIC_PROMPT.search(line) for line in cleaned)
    if numeric_prompt:
        cut = next((i for i,line in enumerate(cleaned) if NUMERIC_PROMPT.search(line)), len(cleaned))
        stem = ' '.join(cleaned[:cut]).strip()
        stem = re.sub(r'\s+[A-Z]{2,}-\d{2}[^ ]*$', '', stem).strip()
        return {'stem':stem, 'choices':[], 'numericPrompt':True}

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
    stem = re.sub(r'\s+[A-Z]{2,}-\d{2}[^ ]*$', '', stem).strip()
    return {'stem':stem, 'choices':choices, 'numericPrompt':False}


def extract_scenarios(lines, starts):
    markers = {}
    for i, raw in enumerate(lines):
        line = clean_line(raw)
        m = SCENARIO_MARKER.search(line)
        if not m:
            continue
        a, b = int(m.group(1)), int(m.group(2))
        if a in SCENARIO_STARTS and b == a + 2 and i < starts[a]:
            markers[a] = i

    scenarios = {}
    for start in SCENARIO_STARTS:
        marker = markers.get(start)
        if marker is None:
            # Some PDFs split the marker with extra spaces/line wraps. Search backward
            # inside the preceding question block for the group-start number and phrase.
            lower = starts[start-1] if start > 91 else starts[90]
            for i in range(starts[start]-1, lower, -1):
                line = clean_line(lines[i])
                squashed = re.sub(r'\s+', '', line)
                if '次の文を読み' in squashed and str(start) in squashed and str(start+2) in squashed and '問いに答えよ' in squashed:
                    marker = i
                    break
        if marker is None:
            raise RuntimeError(f'scenario marker not found for {start}-{start+2}')

        parts=[]
        for raw in lines[marker+1:starts[start]]:
            line=clean_line(raw)
            if skip_print_line(line):
                continue
            if SCENARIO_MARKER.search(line):
                continue
            if line:
                parts.append(line)
        scenario=' '.join(parts).strip()
        scenario=re.sub(r'\s+[A-Z]{2,}-\d{2}[^ ]*$', '', scenario).strip()
        if len(scenario) < 20 or not JAPANESE.search(scenario):
            raise RuntimeError(f'scenario text invalid for {start}-{start+2}: {scenario!r}')
        scenarios[start]=scenario
    return scenarios


def split_questions(text: str):
    lines = text.splitlines()
    starts = find_question_starts(lines)
    scenarios = extract_scenarios(lines, starts)
    out = {}
    for n in range(1,121):
        s = starts[n]
        e = starts[n+1] if n < 120 else len(lines)
        q=parse_question_block(lines[s:e], n)
        if n >= 91:
            group_start=91 + ((n-91)//3)*3
            q['scenarioGroupStart']=group_start
            q['scenario']=scenarios[group_start]
            q['scenarioIndex']=n-group_start
            q['scenarioTotal']=3
        out[n] = q
    return out


def parse_answers(text: str, prefix_morning: str, prefix_afternoon: str):
    answers = {'AM':{}, 'PM':{}}
    prefix_to_session = {prefix_morning:'AM', prefix_afternoon:'PM'}
    prefixes = sorted(prefix_to_session, key=len, reverse=True)
    code_re = re.compile(r'(?<![A-Z])(' + '|'.join(re.escape(x) for x in prefixes) + r')\s*0*(\d{1,3})(?!\d)')

    for raw in text.splitlines():
        line = clean_line(raw)
        matches = list(code_re.finditer(line))
        for i, m in enumerate(matches):
            prefix, n = m.group(1), int(m.group(2))
            if not (1 <= n <= 120):
                continue
            end = matches[i+1].start() if i+1 < len(matches) else len(line)
            segment = line[m.end():end]
            tokens = re.findall(r'(?<!\d)(\d{1,5})(?!\d)', segment)[:3]
            answers[prefix_to_session[prefix]][n] = tokens

    for session in ('AM','PM'):
        if len(answers[session]) != 120:
            missing = [n for n in range(1,121) if n not in answers[session]]
            raise RuntimeError(f'answer row parse failed {session}: {len(answers[session])}, missing={missing[:20]}')
    return answers


def decode_choice_token(token: str):
    if len(token) == 1 and token in '12345':
        return int(token) - 1
    if token and all(c in '12345' for c in token):
        return [int(c)-1 for c in token]
    raise RuntimeError(f'unexpected choice answer token: {token}')


def decode_answer(tokens, choices, numeric_prompt):
    if not tokens:
        return None, ('numeric' if numeric_prompt else 'singleChoice'), []
    if numeric_prompt:
        values = [int(t) for t in tokens]
        return values[0], 'numeric', values
    accepted = [decode_choice_token(t) for t in tokens]
    primary = accepted[0]
    answer_type = 'multiChoice' if isinstance(primary, list) else 'singleChoice'
    return primary, answer_type, accepted


def category(n: int):
    if n <= 25: return '必修'
    if n <= 90: return '一般'
    return '状況設定'


def scoring_exception(src, session, n):
    for row in src.get('scoringExceptions', []):
        if row.get('session') == session and int(row.get('questionNo', -1)) == n:
            return row
    return None


def build_set(src, am_q, pm_q, answers):
    items=[]
    for session, qmap, pdf_url in [('AM',am_q,src['morningPdf']),('PM',pm_q,src['afternoonPdf'])]:
        for n in range(1,121):
            q=qmap[n]
            tokens=answers[session][n]
            stem=q['stem']
            choices=q['choices']
            ans, answer_type, accepted = decode_answer(tokens, choices, q.get('numericPrompt', False))
            exception = scoring_exception(src, session, n)
            scoring_status = exception.get('mode') if exception else ('excluded' if not tokens else 'normal')
            requires_media = any(word in stem for word in MEDIA_WORDS)
            refs=[src['landingUrl'], pdf_url, src['answerPdf']]
            if src.get('resultUrl'): refs.append(src['resultUrl'])
            if exception and exception.get('noticeUrl'): refs.append(exception['noticeUrl'])
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
                'officialAcceptedAnswers':accepted,
                'officialScoringStatus':scoring_status,
                'scoringException':exception,
                'point':None,
                'detail':None,
                'requiresMedia':requires_media,
                'mediaAuditStatus':'pending' if requires_media else 'not_required',
                'rightsStatus':'mhlw-pdl1.0-text; media-pending' if requires_media else 'mhlw-pdl1.0-text',
                'reviewStatus':'official_import_pending_explanation_and_classification',
                'sourceRefs':refs,
                'sourceAttribution':f"出典：厚生労働省『第{src['exam']}回看護師国家試験』を学習用データとして加工",
                'sourceAnswerTokens':tokens
            }
            if n >= 91:
                g=q['scenarioGroupStart']
                item.update({
                    'scenarioId':f"K{src['exam']}-{session}-SC{((g-91)//3)+1:02d}",
                    'scenario':q['scenario'],
                    'scenarioIndex':q['scenarioIndex'],
                    'scenarioTotal':q['scenarioTotal']
                })
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
                'schemaVersion':4,
                'setId':src['id'],
                'sourceExam':src['exam'],
                'questionCount':len(items),
                'releaseStatus':'raw_import_only',
                'note':'公式本文・正答・状況設定症例の機械取込。解説、11科目分類、図版権利監査、専門監査が完了するまで本番解放禁止。採点除外・複数正答等はofficialScoringStatusに保持する。',
                'questions':items
            }
            (OUT/f"{src['id']}-raw.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
            summary.append({
                'set':src['id'],
                'exam':src['exam'],
                'count':len(items),
                'scenarioQuestions':sum(1 for x in items if x.get('scenarioId')),
                'scenarioGroups':len({x.get('scenarioId') for x in items if x.get('scenarioId')}),
                'mediaPending':sum(1 for x in items if x['requiresMedia']),
                'numeric':sum(1 for x in items if x['answerType']=='numeric'),
                'multiChoice':sum(1 for x in items if x['answerType']=='multiChoice'),
                'scoringExceptions':sum(1 for x in items if x['officialScoringStatus']!='normal')
            })
    (OUT/'import-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':
    main()
