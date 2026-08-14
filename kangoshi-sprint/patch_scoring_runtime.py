#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parent
app=ROOT/'app-v03.js'
index=ROOT/'index.html'
text=app.read_text(encoding='utf-8')


def repl(old,new,label):
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'patch target missing: {label}')
    text=text.replace(old,new,1)

repl("const META=window.KANGOSHI_CONTENT_META||{};", "const META=window.KANGOSHI_CONTENT_META||{};const SCORING=window.KANGOSHI_SCORING||{};", 'scoring map')
repl("function mockPool(round,category){const p=Q.filter(q=>q.category===category);return p.filter((_,i)=>i%3===round)}", "function mockPool(round,category){const examNo=[115,114,113][round];return Q.filter(q=>q.category===category&&Number(q.sourceExam)===examNo)}", 'exam-specific mock pool')
repl("if(i<session.results.length)cls=session.results[i].correct?'ok':'ng';", "if(i<session.results.length){const r=session.results[i];cls=r.scored===false?'skip':r.correct?'ok':'ng'}", 'neutral unscored pip')
repl("function weakHint(q,last){const w=state.weak[q.id];", "function weakHint(q,last){if(last.scored===false)return'公式採点では得点・分母に含めません';const w=state.weak[q.id];", 'unscored hint')
repl("${last.correct?'ok':'ng'}\">${last.correct?'正解':'惜しい'}", "${last.scored===false?'skip':last.correct?'ok':'ng'}\">${last.scored===false?'採点対象外':last.correct?'正解':'惜しい'}", 'unscored feedback')
old_correct="function isCorrect(q,response,unknown){if(unknown)return false;if(q.answerType==='numeric'){const v=Number(response);return Number.isFinite(v)&&Math.abs(v-Number(q.answer))<=Number(q.tolerance||0)}const ans=(Array.isArray(q.answer)?[...q.answer]:[q.answer]).sort((a,b)=>a-b),got=[...response].sort((a,b)=>a-b);return ans.length===got.length&&ans.every((v,i)=>v===got[i])}"
new_correct="function scoringRule(q){return SCORING[q.id]||{mode:'normal'}}function isCorrect(q,response,unknown){if(unknown)return false;const rule=scoringRule(q);if(rule.mode==='excluded')return null;if(q.answerType==='numeric'){const v=Number(response);return Number.isFinite(v)&&Math.abs(v-Number(q.answer))<=Number(q.tolerance||0)}const raw=rule.mode==='multiple_accepted'&&Array.isArray(rule.acceptedAnswers)?rule.acceptedAnswers:q.answer;const ans=(Array.isArray(raw)?[...raw]:[raw]).sort((a,b)=>a-b),got=[...response].sort((a,b)=>a-b);if(rule.mode==='multiple_accepted'&&ans.length>1&&got.length===1)return ans.includes(got[0]);return ans.length===got.length&&ans.every((v,i)=>v===got[i])}"
repl(old_correct,new_correct,'scoring-aware correctness')
old_grade="function grade(response,unknown=false){const q=current();if(!q||session.answered)return;const wasWeak=!!state.weak[q.id],ok=isCorrect(q,response,unknown);session.answered=true;if(ok)session.correct++;if(wasWeak&&ok){state.weak[q.id].streak=(state.weak[q.id].streak||0)+1;if(state.weak[q.id].streak>=3){delete state.weak[q.id];showToast('苦手をひとつ卒業しました')}}else if(!ok){state.weak[q.id]={streak:0,misses:(state.weak[q.id]?.misses||0)+1,last:Date.now()}}if(!state.seen.includes(q.id))state.seen.push(q.id);state.totalAnswers=(state.totalAnswers||0)+1;if(ok)state.totalCorrect=(state.totalCorrect||0)+1;const dk=todayKey();state.daily[dk]??={a:0,c:0};state.daily[dk].a++;if(ok)state.daily[dk].c++;const major=majorOf(q);state.subjectStats[major]??={a:0,c:0};state.subjectStats[major].a++;if(ok)state.subjectStats[major].c++;session.results.push({id:q.id,correct:ok,unknown,category:q.category,subject:q.subject,major,response:q.answerType==='numeric'?response:[...response],wasWeak});persistResume();render()}"
new_grade="function grade(response,unknown=false){const q=current();if(!q||session.answered)return;const rule=scoringRule(q),wasWeak=!!state.weak[q.id],ok=isCorrect(q,response,unknown),scored=rule.mode==='excluded'?false:rule.mode==='include_if_correct_exclude_if_wrong'?ok===true:true;session.answered=true;if(ok===true&&scored)session.correct++;if(rule.mode!=='excluded'){if(wasWeak&&ok===true){state.weak[q.id].streak=(state.weak[q.id].streak||0)+1;if(state.weak[q.id].streak>=3){delete state.weak[q.id];showToast('苦手をひとつ卒業しました')}}else if(ok!==true){state.weak[q.id]={streak:0,misses:(state.weak[q.id]?.misses||0)+1,last:Date.now()}}}if(!state.seen.includes(q.id))state.seen.push(q.id);if(scored){state.totalAnswers=(state.totalAnswers||0)+1;if(ok===true)state.totalCorrect=(state.totalCorrect||0)+1}const dk=todayKey();state.daily[dk]??={a:0,c:0};if(scored){state.daily[dk].a++;if(ok===true)state.daily[dk].c++}const major=majorOf(q);state.subjectStats[major]??={a:0,c:0};if(scored){state.subjectStats[major].a++;if(ok===true)state.subjectStats[major].c++}session.results.push({id:q.id,correct:ok===true,unknown,scored,scoringMode:rule.mode,scoringNote:rule.note||'',category:q.category,subject:q.subject,major,response:q.answerType==='numeric'?response:[...response],wasWeak});persistResume();render()}"
repl(old_grade,new_grade,'scoring-aware grade')
old_finish="function finish(){if(!session)return;const elapsed=Math.max(1,Math.round((Date.now()-session.started)/1000)),r={title:session.title,correct:session.correct,total:session.ids.length,elapsed,at:Date.now(),results:session.results,ids:[...session.ids],kind:session.kind,mockKey:session.mockKey};state.history.unshift(r);state.history=state.history.slice(0,20);if(session.mockKey)state.mockResults[session.mockKey]={correct:r.correct,total:r.total,at:r.at};state.resume=null;save();session.final=r;page='result';render();window.scrollTo(0,0)}"
new_finish="function finish(){if(!session)return;const elapsed=Math.max(1,Math.round((Date.now()-session.started)/1000)),scoredTotal=session.results.filter(x=>x.scored!==false).length,r={title:session.title,correct:session.correct,total:scoredTotal,attempted:session.ids.length,elapsed,at:Date.now(),results:session.results,ids:[...session.ids],kind:session.kind,mockKey:session.mockKey};state.history.unshift(r);state.history=state.history.slice(0,20);if(session.mockKey)state.mockResults[session.mockKey]={correct:r.correct,total:r.total,attempted:r.attempted,at:r.at};state.resume=null;save();session.final=r;page='result';render();window.scrollTo(0,0)}"
repl(old_finish,new_finish,'official denominator')
repl("const rate=Math.round(r.correct/r.total*100)", "const rate=r.total?Math.round(r.correct/r.total*100):0", 'zero-safe result')
app.write_text(text,encoding='utf-8')

html=index.read_text(encoding='utf-8')
needle='<script src="exam-config.js"></script>\n<script src="app-v03.js"></script>'
replacement='<script src="exam-config.js"></script>\n<script src="scoring-overrides.js"></script>\n<script src="app-v03.js"></script>'
if replacement not in html:
    if needle not in html: raise SystemExit('index scoring script target missing')
    html=html.replace(needle,replacement,1)
index.write_text(html,encoding='utf-8')
print('scoring runtime patched')
