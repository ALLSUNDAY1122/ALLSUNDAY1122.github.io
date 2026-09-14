#!/usr/bin/env python3
"""Repair the legacy IT Passport value-validation UI to the current learning contract.

This script intentionally patches only the legacy `it-passport-swipe/index.html` product.
It refuses to run if expected legacy markers have drifted, and it never touches the
separate zero-base rebuild under `apps/it-passport-rebuild/`.
"""
from pathlib import Path

PATH = Path("it-passport-swipe/index.html")
html = PATH.read_text(encoding="utf-8")


def replace_once(old: str, new: str, label: str) -> None:
    global html
    count = html.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one legacy marker, found {count}")
    html = html.replace(old, new, 1)


replace_once(
    '.result{display:none;text-align:center;padding:40px 10px}.result.show{display:block}.result h2{font-size:32px}.big{font-size:50px;font-weight:1000}',
    '.result{display:none;text-align:center;padding:40px 10px}.result.show{display:block}.result h2{font-size:32px}.big{font-size:50px;font-weight:1000}'
    '.top-home{border:1px solid #344461;background:#17233a;border-radius:12px;padding:9px 12px;font-weight:800;min-width:54px;min-height:44px}'
    '.quiz-actions{display:grid;gap:9px;margin-top:12px}.next-btn{display:none;width:100%;border:0;background:#2563eb;padding:14px;border-radius:15px;font-weight:900;min-height:48px}'
    '.unknown-btn{width:100%;border:1px solid #52617d;background:#101a2d;padding:12px;border-radius:15px;font-weight:800;margin-top:10px;min-height:48px}',
    "action styles",
)

replace_once(
    '<div class="start" id="start"><div class="startbox"><div class="badge">Safari価値検証版 v0.3</div><h1>ITパスポート<br>クイズ</h1><p>表示された四つの選択肢から、正しいと思う答えをタップしてください。</p><button class="mode" data-count="12">12問スタート</button><button class="submode" data-count="60">チャレンジ60問（現在は12問を反復）</button><p style="font-size:12px">問題・正答：IPA 令和8年度公開問題。解説文は独自作成です。</p></div></div>',
    '<div class="start" id="start"><div class="startbox"><div class="badge">学びスプリント</div><h1>ITパスポート</h1><p>12問を短く解き、回答後に要点を確認してから次へ進みます。</p><button class="mode" data-count="12">12問スプリント</button><button class="submode" id="resume" style="display:none">続きから</button><button class="submode" data-count="60">100問チャレンジ（現収録範囲では反復）</button><p style="font-size:12px">問題・正答：IPA 令和8年度公開問題。解説文は独自作成です。</p></div></div>',
    "home screen",
)

replace_once(
    '<div class="app"><header><div class="brand">ITパスポート クイズ</div><div class="badge" id="comboBadge">COMBO 0</div></header>',
    '<div class="app"><header><button class="top-home" id="homeHeader" aria-label="ホームへ戻る">ホーム</button><div class="brand">ITパスポート</div><div class="badge" id="comboBadge">COMBO 0</div></header>',
    "header home control",
)

replace_once(
    '<div class="choices" id="choices"></div><div class="feedback" id="feedback"></div><div class="guide">選択肢ボタンをタップして回答</div>',
    '<div class="choices" id="choices"></div><button class="unknown-btn" id="unknown">わからない</button><div class="feedback" id="feedback"></div><div class="quiz-actions"><button class="next-btn" id="next">次の問題へ</button></div><div class="guide" id="guide">選択肢をタップして回答</div>',
    "question actions",
)

replace_once(
    '<button class="mode" id="again">もう一度</button></div></div>',
    '<button class="mode" id="again">もう12問</button><button class="submode" id="homeResult">ホームへ</button></div></div>',
    "result actions",
)

replace_once(
    'let session=[],index=0,correct=0,combo=0,best=Number(localStorage.getItem("itp_best")||0),locked=false,target=12;',
    'let session=[],index=0,correct=0,combo=0,best=Number(localStorage.getItem("itp_best")||0),locked=false,target=12;const PROGRESS_KEY="itp_learning_progress_v1";',
    "state declaration",
)

replace_once(
    'function begin(count){target=count;session=[];while(session.length<count)session.push(...shuffle(QUESTIONS));session=session.slice(0,count);index=correct=combo=0;locked=false;$("start").classList.add("hide");$("result").classList.remove("show");$("quiz").style.display="block";render()}',
    'function saveProgress(){if(!session.length||index>=session.length){localStorage.removeItem(PROGRESS_KEY);return}localStorage.setItem(PROGRESS_KEY,JSON.stringify({ids:session.map(q=>q.id),index,correct,combo,target}))}\n'
    'function refreshResume(){const b=$("resume");if(!b)return;const raw=localStorage.getItem(PROGRESS_KEY);if(!raw){b.style.display="none";return}try{const p=JSON.parse(raw);const left=(p.ids||[]).length-Number(p.index||0);if(left<=0)throw 0;b.textContent=`続きから（残り${left}問）`;b.style.display="block"}catch(_){localStorage.removeItem(PROGRESS_KEY);b.style.display="none"}}\n'
    'function loadProgress(){const raw=localStorage.getItem(PROGRESS_KEY);if(!raw)return false;try{const p=JSON.parse(raw),map=new Map(QUESTIONS.map(q=>[q.id,q]));const restored=(p.ids||[]).map(id=>map.get(id)).filter(Boolean);if(!restored.length||restored.length!==(p.ids||[]).length)return false;session=restored;index=Number(p.index||0);correct=Number(p.correct||0);combo=Number(p.combo||0);target=Number(p.target||restored.length);return index<session.length}catch(_){return false}}\n'
    'function showLearning(){$("start").classList.add("hide");$("result").classList.remove("show");$("quiz").style.display="block";render()}\n'
    'function goHome(){saveProgress();$("quiz").style.display="none";$("result").classList.remove("show");$("start").classList.remove("hide");refreshResume()}\n'
    'function begin(count){target=count;session=[];while(session.length<count)session.push(...shuffle(QUESTIONS));session=session.slice(0,count);index=correct=combo=0;locked=false;saveProgress();showLearning()}',
    "progress and home flow",
)

replace_once(
    '$("choices").innerHTML=q.choices.map((c,i)=>`<button class="choice" data-i="${i}"><strong>${letters[i]}</strong><span>${c}</span></button>`).join("");$("feedback").className="feedback";$("feedback").innerHTML="";$("source").textContent=',
    '$("choices").innerHTML=q.choices.map((c,i)=>`<button class="choice" data-i="${i}"><strong>${letters[i]}</strong><span>${c}</span></button>`).join("");$("feedback").className="feedback";$("feedback").innerHTML="";$("unknown").style.display="block";$("next").style.display="none";$("guide").textContent="選択肢をタップして回答";$("source").textContent=',
    "render action reset",
)

replace_once(
    'const f=$("feedback");f.className="feedback show "+(ok?"ok":"ng");f.innerHTML=`<b>${ok?"正解":"不正解"}　正解：${letters[q.answer]}</b>${q.explanation}`;setTimeout(()=>{index++;render()},2600)}',
    'const f=$("feedback");f.className="feedback show "+(ok?"ok":"ng");f.innerHTML=`<b>${ok?"正解":"不正解"}　正解：${letters[q.answer]}</b><strong>この問題で覚える一文</strong><br>${q.explanation}`;$("unknown").style.display="none";$("next").style.display="block";$("guide").textContent="要点を確認してから次へ進む";saveProgress()}',
    "manual next flow",
)

replace_once(
    'function finish(){$("quiz").style.display="none";$("bar").style.width="100%";$("result").classList.add("show");$("finalScore").textContent=`${correct} / ${session.length}`;$("finalText").textContent=`正答率 ${Math.round(correct/session.length*100)}%・最高コンボ ${best}`}',
    'function finish(){localStorage.removeItem(PROGRESS_KEY);$("quiz").style.display="none";$("bar").style.width="100%";$("result").classList.add("show");$("finalScore").textContent=`${correct} / ${session.length}`;$("finalText").textContent=`正答率 ${Math.round(correct/session.length*100)}%・最高コンボ ${best}。本試験のIRT評価点とは異なる学習記録です。`;refreshResume()}',
    "result contract",
)

replace_once(
    'document.querySelectorAll("[data-count]").forEach(b=>b.onclick=()=>begin(Number(b.dataset.count)));$("again").onclick=()=>begin(target);',
    'document.querySelectorAll("[data-count]").forEach(b=>b.onclick=()=>begin(Number(b.dataset.count)));$("unknown").onclick=()=>answer(-1);$("next").onclick=()=>{if(!locked)return;index++;saveProgress();render()};$("homeHeader").onclick=goHome;$("homeResult").onclick=goHome;$("again").onclick=()=>begin(12);$("resume").onclick=()=>{if(loadProgress())showLearning();else refreshResume()};refreshResume();',
    "event wiring",
)

# Fail closed: legacy auto-advance and absent contract markers must not survive.
required = [
    'id="homeHeader"', 'id="homeResult"', 'id="unknown"', 'id="next"',
    'この問題で覚える一文', 'PROGRESS_KEY="itp_learning_progress_v1"',
    '本試験のIRT評価点とは異なる学習記録です。', '続きから（残り${left}問）',
]
missing = [x for x in required if x not in html]
if missing:
    raise SystemExit(f"post-patch contract markers missing: {missing}")
if 'setTimeout(()=>{index++;render()},2600)' in html:
    raise SystemExit("legacy timed auto-advance still present")
if 'apps/it-passport-rebuild' in html:
    raise SystemExit("zero-base rebuild contamination detected")

PATH.write_text(html, encoding="utf-8")
print("PASS: legacy IT Passport learning UI repaired fail-closed")
