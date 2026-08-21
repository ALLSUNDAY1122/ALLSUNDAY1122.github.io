#!/usr/bin/env python3
import json, re, statistics
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/'apps'/'sanitary-manager-2'
OUT=ROOT/'ios'/'health-manager-2'/'audit'/'DIFFICULTY_AUDIT.md'

ABSOLUTES=('必ず','一切','全て','すべて','どのような場合でも','例外なく','絶対に','のみでよい','必要はない','一律に','無条件')
EASY_NEG=('関係しない','含まれない','できない','不要である','義務はない')
SPECIAL=('法令上','選任','衛生管理者','産業医','健康診断','労働時間','休憩','年次有給休暇','衛生委員会','自律神経','血液','呼吸','代謝','体温','腎臓','肝臓','ストレス','BMI')

def load_questions():
    qs=[]
    for p in sorted(APP.glob('q*.js'), key=lambda x:int(re.search(r'(\d+)',x.stem).group(1))):
        txt=p.read_text(encoding='utf-8')
        m=re.search(r'push\(\.\.\.(\[.*\])\);?\s*$',txt,re.S)
        if not m:
            raise SystemExit(f'cannot parse {p}')
        arr=json.loads(m.group(1))
        for q in arr:
            q['_file']=p.name
            qs.append(q)
    return qs

def score(q):
    flags=[]; points=0
    ch=q.get('choices',[]); ans=int(q.get('answer',0))-1
    lens=[len(str(x)) for x in ch]
    if len(ch)!=5: flags.append('5肢でない'); points+=5
    abs_counts=[sum(w in c for w in ABSOLUTES) for c in ch]
    if sum(abs_counts)>=2 and ans>=0 and ans<len(ch) and abs_counts[ans]==0:
        flags.append('断定語が誤答肢に偏る'); points+=2
    neg_counts=[sum(w in c for w in EASY_NEG) for c in ch]
    if sum(neg_counts)>=3 and ans>=0 and ans<len(ch) and neg_counts[ans]==0:
        flags.append('否定・極端表現で消去しやすい'); points+=2
    if lens:
        med=statistics.median(lens)
        if 0<=ans<len(lens) and lens[ans] > med*1.65 and lens[ans]-min(lens)>=18:
            flags.append('正答肢だけ長い'); points+=2
        if max(lens)-min(lens)>=40:
            flags.append('選択肢長の差が大きい'); points+=1
    stem=q.get('question','')
    if len(stem)<24 and not any(c.isdigit() for c in stem) and sum(s in stem for s in SPECIAL)<=1:
        flags.append('問いが単純な一問一答型'); points+=1
    # 本試験型の加点要素がない場合を検出
    complexity=0
    if any(c.isdigit() for c in stem+' '.join(ch)): complexity+=1
    if any(w in stem for w in ('組合せ','誤っている','正しいもの','最も適切','事業場','労働者','場合')): complexity+=1
    if sum(any(s in c for s in SPECIAL) for c in ch)>=3: complexity+=1
    if complexity==0:
        flags.append('近接知識の比較要素が弱い'); points+=2
    # 誤答肢が極端な短文に集中
    if lens and sum(l < max(12, statistics.median(lens)*0.55) for l in lens)>=2:
        flags.append('短すぎる誤答肢あり'); points+=1
    return points,flags

def main():
    qs=load_questions()
    rows=[]; counts={}
    for q in qs:
        pts,flags=score(q)
        band='要差替' if pts>=4 else ('要精査' if pts>=2 else '維持候補')
        counts[band]=counts.get(band,0)+1
        rows.append((pts,band,q,flags))
    rows.sort(key=lambda x:(-x[0],x[2].get('id','')))
    OUT.parent.mkdir(parents=True,exist_ok=True)
    lines=[
        '# 第二種衛生管理者｜300問 難易度監査', '',
        '基準: 公益財団法人 安全衛生技術試験協会の公表試験問題に近い、5肢すべてがもっともらしく、制度・数値・例外・専門用語を区別しないと解けない水準。',
        '',f'- 総問題数: {len(qs)}',
        f"- 要差替: {counts.get('要差替',0)}",
        f"- 要精査: {counts.get('要精査',0)}",
        f"- 維持候補: {counts.get('維持候補',0)}",'',
        '## 判定ルール','- 断定語や否定語だけで消去できる問題を減点','- 正答肢だけ長い・詳しい問題を減点','- 単純な一問一答で近接知識比較がない問題を減点','- 数値条件、例外、類似制度、専門用語の比較を本試験型要素として評価','',
        '## 全問一覧','|score|判定|ID|科目|論点|監査理由|問題文|','|---:|---|---|---|---|---|---|'
    ]
    for pts,band,q,flags in rows:
        clean=lambda s:str(s).replace('|','／').replace('\n',' ')
        lines.append(f"|{pts}|{band}|{clean(q.get('id'))}|{clean(q.get('subject'))}|{clean(q.get('topic'))}|{clean('・'.join(flags) or 'なし')}|{clean(q.get('question'))}|")
    lines += ['', '## 要差替・要精査の選択肢詳細']
    for pts,band,q,flags in rows:
        if band=='維持候補': continue
        lines += ['',f"### {q.get('id')}｜{q.get('subject')}｜score {pts}｜{band}",f"**問題**: {q.get('question')}",f"**理由**: {'・'.join(flags)}"]
        ans=int(q.get('answer',0))
        for i,c in enumerate(q.get('choices',[]),1):
            lines.append(f"- {'✓' if i==ans else ' '} {i}. {c}")
    OUT.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({'total':len(qs),**counts},ensure_ascii=False))

if __name__=='__main__': main()
