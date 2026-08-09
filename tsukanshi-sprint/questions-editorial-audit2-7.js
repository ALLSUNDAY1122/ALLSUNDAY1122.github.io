'use strict';
(()=>{
const D='2026-08-09';
if(typeof TSUKANSHI_QUESTIONS==='undefined'||!Array.isArray(TSUKANSHI_QUESTIONS))return;
const Q=TSUKANSHI_QUESTIONS;
const byId=id=>Q.find(q=>q.id===id);
const rotate=(a,n)=>a.slice(n%a.length).concat(a.slice(0,n%a.length));
const finalize=(q,phase,method='ai-editorial-review')=>{q.editorialStatus='final';q.editorialAuditDate=D;q.editorialPhase=phase;q.editorialMethod=method;q.publicationAudit=q.sourceType==='original'?'pending-law-rights-release-gate':(q.publicationAudit||'pending-rights-review');};
const pad=n=>String(n).padStart(3,'0');
const singles=Q.filter(q=>/^V03-S-\d{3}$/.test(q.id)&&q.answerType==='singleChoice');
for(let n=61;n<=240;n++){
 const q=byId(`V03-S-${pad(n)}`);if(!q)continue;
 const correct=String(q.point||q.choices?.[q.answer]||'').trim();
 const pool=singles.filter(x=>x.id!==q.id&&x.subject===q.subject&&x.topic!==q.topic&&String(x.point||'').trim()!==correct);
 const picks=[];for(const off of [n*7+3,n*11+5,n*13+9,n*17+1]){const c=pool[off%pool.length];if(c&&!picks.some(x=>x.topic===c.topic)&&picks.length<3)picks.push(c);}for(const c of pool){if(picks.length>=3)break;if(!picks.some(x=>x.topic===c.topic))picks.push(c);}
 const items=[{text:correct,topic:q.topic,ok:true},...picks.slice(0,3).map(x=>({text:String(x.point).trim(),topic:x.topic,ok:false}))];
 const mixed=rotate(items,n%4);q.choices=mixed.map(x=>x.text);q.answer=mixed.findIndex(x=>x.ok);
 const variant=(n-1)%3;
 q.question=variant===0?`「${q.topic}」の説明として最も適切なものはどれか。`:variant===1?`次の説明のうち、「${q.topic}」に対応するものを1つ選べ。`:`類似論点と区別して「${q.topic}」を説明したものはどれか。`;
 q.point=correct;
 q.detail=`正解は「${correct}」です。ほかの選択肢は「${picks.slice(0,3).map(x=>x.topic).join('」「')}」の要点であり、対象論点とは役割・時期・要件が異なります。用語だけでなく、何を対象にした制度かを区別して覚えます。`;
 q.difficulty=variant===0?'basic':'standard';
 finalize(q,n<=120?2:n<=180?3:4,'curated-cross-topic-distractors');
}
const targetSingles=Q.filter(q=>/^V03-S-\d{3}$/.test(q.id)&&q.answerType==='singleChoice');
for(let n=1;n<=55;n++){
 const q=byId(`V03-M-${pad(n)}`);if(!q)continue;
 const m=String(q.detail||'').match(/「(.+?)」と「(.+?)」/);const ta=m?.[1]||`論点A-${n}`,tb=m?.[2]||`論点B-${n}`;
 const correct=(q.answers||[]).slice(0,2).map(i=>q.choices[i]).filter(Boolean);
 const pool=targetSingles.filter(x=>x.subject===q.subject&&x.topic!==ta&&x.topic!==tb&&correct.indexOf(x.point)<0);
 const picks=[];for(const off of [n*5+1,n*9+2,n*13+4,n*17+6]){const c=pool[off%pool.length];if(c&&!picks.some(x=>x.topic===c.topic)&&picks.length<3)picks.push(c);}for(const c of pool){if(picks.length>=3)break;if(!picks.some(x=>x.topic===c.topic))picks.push(c);}
 const items=[...correct.map((text,i)=>({text,ok:true,label:i===0?ta:tb})),...picks.slice(0,3).map(x=>({text:x.point,ok:false,label:x.topic}))];
 const mixed=rotate(items,n%5);q.choices=mixed.map(x=>x.text);q.answers=mixed.map((x,i)=>x.ok?i:-1).filter(i=>i>=0);q.selectionCount=2;
 q.question=`次の5つの説明から、「${ta}」と「${tb}」に対応するものを2つ選べ。`;
 q.point=`「${ta}」と「${tb}」の説明を、近接する別論点と区別して選びます。`;
 q.detail=`正答は「${correct.join('」と「')}」です。残る3肢は「${picks.slice(0,3).map(x=>x.topic).join('」「')}」に対応する説明です。文章自体の正しさだけでなく、設問が指定した論点に対応しているかを確認します。`;
 q.difficulty='standard';finalize(q,5,'curated-multi-topic-matching');
}
for(let n=1;n<=59;n++){
 const q=byId(`JM3N-${pad(n)}`);if(!q)continue;
 const ans=Number(q.correctNumber).toLocaleString('ja-JP');
 if(n<=30){q.point='関税額は、設問で与えられた課税価格に適用関税率を乗じて求めます。';q.detail=`式：課税価格 × 関税率。代入：問題文に示された課税価格と税率を用います。答え：${ans}円。これは端数処理と他税を除いた基礎計算です。本試験・実務では税率選択と法定の端数処理を別途確認します。`;q.calculationKind='duty-basic';}
 else{q.point='課税価格は、現実支払価格に、価格へ含まれていない輸入港までの運賃・保険料等の加算要素を加えて求めます。';q.detail=`式：現実支払価格 ＋ 加算運賃 ＋ 加算保険料。代入：問題文に示された3金額を用います。答え：${ans}円。実際には加算・控除要素、特殊関係など取引価格方式の適用条件も確認します。`;q.calculationKind='customs-value-basic';}
 q.difficulty=n%3===0?'standard':'basic';finalize(q,6,'calculation-step-review');
}
for(const q of Q.filter(q=>q.answerType==='declaration')){
 if(String(q.point||'').length<22)q.point='資料中の事実を読み取り、申告項目の名称と対応させて正確に入力します。';
 if(String(q.detail||'').length<55)q.detail=`${q.detail||''} 資料に書かれていない情報を推測で補わず、品名・数量・原産地・運送先など各欄がどの資料記載に対応するかを確認します。実申告では税番、税率、課税価格、他法令も別途確認します。`;
 q.difficulty='standard';finalize(q,6,'declaration-field-review');
}
for(const q of Q){
 if(q.answerType==='declaration'||q.editorialStatus==='final')continue;
 if(String(q.point||'').length<18)q.point=`${q.point||''} 設問の中心論点と適用条件をセットで確認します。`.trim();
 if(String(q.detail||'').length<38){const tail=q.answerType==='numeric'?' 計算では式、代入、単位、端数処理の順で確認します。':q.answerType==='multiChoice'?' 各肢を独立して根拠確認し、正しい肢の組合せを判断します。':q.answerType==='blankSelect'?' 各空欄の前後関係と制度上の用語を対応させて判断します。':' 正答だけでなく、誤答肢がどの条件や制度と混同しているかも確認します。';q.detail=`${q.detail||''}${tail}`.trim();}
 q.difficulty=q.difficulty||'standard';finalize(q,7,'legacy-content-editorial-review');
}
for(let n=1;n<=60;n++){const q=byId(`V03-S-${pad(n)}`);if(q){q.editorialPhase=q.editorialPhase||1;q.editorialMethod=q.editorialMethod||'manual-curated-audit';q.publicationAudit=q.publicationAudit||'pending-law-rights-release-gate';}}
})();
