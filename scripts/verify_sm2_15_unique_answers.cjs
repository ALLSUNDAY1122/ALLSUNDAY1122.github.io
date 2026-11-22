#!/usr/bin/env node
'use strict';
// Historical 15 multiple-answer regressions. Some items were subsequently
// redesigned as situational questions, so do not assume every correct option
// remains in "topic ― clue" format. Pin the actual reviewed keyed answers.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'];
const pinned={
  "sm2-5y-r06-hyg-06": {
    "answer": 1,
    "correct": "心の健康づくり計画 ― 衛生委員会等で調査審議し、職場のメンタルヘルス対策を計画的に進める。"
  },
  "sm2-5y-r06-hyg-07": {
    "answer": 3,
    "correct": "健康情報の保護 ― メンタルヘルス対策では労働者の健康情報やプライバシーを適切に保護する。"
  },
  "sm2-5y-r06-hyg-08": {
    "answer": 5,
    "correct": "職場復帰支援 ― 休業者の復職では主治医・産業保健スタッフ等の情報を踏まえ、段階的な支援を検討する。"
  },
  "sm2-5y-r09-hyg-08": {
    "answer": 5,
    "correct": "脊椎損傷の疑い ― 頭頸部や脊椎の損傷が疑われる場合は、不要な体動を避ける。"
  },
  "sm2-5y-r09-hyg-09": {
    "answer": 2,
    "correct": "医師意見を勘案し本人の実情を考慮して、必要性に応じて就業場所の変更や労働時間短縮等の措置を事業者が講ずる。"
  },
  "sm2-5y-r09-hyg-10": {
    "answer": 4,
    "correct": "保健指導 ― 健康診断結果に応じ、生活習慣改善等の保健指導へつなげることが健康保持に役立つ。"
  },
  "sm2-5y-r06-phy-03": {
    "answer": 5,
    "correct": "肺活量 ― 最大吸息後にできるだけ吐き出せる空気量をいう。"
  },
  "sm2-5y-r06-phy-04": {
    "answer": 2,
    "correct": "呼吸中枢 ― 延髄などにあり、呼吸運動のリズム調節に関与する。"
  },
  "sm2-5y-r06-phy-05": {
    "answer": 3,
    "correct": "二酸化炭素が血液脳関門を通過して脳脊髄液中の水素イオン濃度を増やし、そのpH低下が中枢化学受容器を刺激する。"
  },
  "sm2-5y-r08-phy-03": {
    "answer": 1,
    "correct": "大脳皮質 ― 感覚・随意運動・言語・思考など高次機能に関与する。"
  },
  "sm2-5y-r08-phy-04": {
    "answer": 4,
    "correct": "瞳孔 ― 虹彩によって大きさが調節され、眼に入る光量を調整する。"
  },
  "sm2-5y-r08-phy-05": {
    "answer": 3,
    "correct": "水晶体の硬化・弾性低下などにより調節力が弱まり、近点が遠ざかる。"
  },
  "sm2-5y-r08-phy-07": {
    "answer": 3,
    "correct": "明るい背景に適応し、光の強さの差を識別しやすくなる明順応。"
  },
  "sm2-5y-r08-phy-08": {
    "answer": 5,
    "correct": "中心窩は錐体が高密度で杆体を欠き、中心窩から離れた網膜には微弱光に高感度な杆体が分布するためである。"
  },
  "sm2-5y-r08-phy-09": {
    "answer": 2,
    "correct": "蝸牛では基底膜の振動に伴う有毛細胞の機械電気変換により聴覚信号が生じ、蝸牛神経を介して伝わる。"
  }
};
const fields=['id','question','choices','answer','quick','explanation','topic','sourceUrl','baselineDate'];
const results={};
const normalize=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
function load(files){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(web,file),'utf8'),ctx,{filename:file});
 return ctx.window.Q_PARTS;
}
for(const [mode,files] of [
 ['browser',[...base,'difficulty-patch-v5.js',...overlays]],
 ['release-export',[...base,...overlays]]
]){
 const qs=load(files),byId=new Map(qs.map(q=>[q.id,q]));
 assert.equal(qs.length,300,mode+' count');
 assert.equal(byId.size,300,mode+' IDs');
 assert.equal(new Set(qs.map(q=>normalize(q.question))).size,300,mode+' duplicate stems');
 const groups=new Map();
 for(const q of qs){
   assert.ok(Array.isArray(q.choices)&&q.choices.length===5,q.id+' choice count');
   assert.equal(new Set(q.choices).size,5,q.id+' choice duplicates');
   assert.ok(Number.isInteger(q.answer)&&q.answer>=1&&q.answer<=5,q.id+' keyed index');
   const key=q.examSet+'|'+q.subject;
   if(!groups.has(key))groups.set(key,[]);
   groups.get(key).push(q);
 }
 assert.equal(groups.size,30,mode+' groups');
 for(const [key,group] of groups){
   assert.equal(group.length,10,key+' question count');
   const counts=[0,0,0,0,0];for(const q of group)counts[q.answer-1]++;
   assert.deepEqual(counts,[2,2,2,2,2],key+' answer distribution');
 }
 const stems=new Set();
 for(const [id,expected] of Object.entries(pinned)){
   const q=byId.get(id);assert.ok(q,mode+' missing '+id);
   assert.equal(q.singleAnswerAudit,'2026-11-10-15-items',id+' audit marker');
   assert.equal(q.answer,expected.answer,id+' answer position changed');
   assert.equal(q.choices[q.answer-1],expected.correct,id+' keyed content changed');
   assert.ok(q.explanation&&q.explanation.length>=60,id+' explanation incomplete');
   assert.ok(q.sourceUrl&&q.sourceUrl.startsWith('https://'),id+' source missing');
   assert.ok(!stems.has(normalize(q.question)),id+' duplicate targeted stem');
   stems.add(normalize(q.question));
 }
 assert.equal(stems.size,15,mode+' target count');
 results[mode]=byId;
 console.log('PASS',mode,'300 questions, 30 balanced groups, 15 pinned keyed answers');
}
const browser=results.browser,release=results['release-export'];
for(const [id,q] of browser){
 const other=release.get(id);assert.ok(other,'release missing '+id);
 for(const key of fields)
   assert.equal(JSON.stringify(q[key]),JSON.stringify(other[key]),id+' cross-order drift '+key);
}
console.log('PASS browser/release-export parity: 300 IDs, '+fields.length+' fields; no content or answer drift');
